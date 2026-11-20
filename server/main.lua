local PED = {}
local SELL_PED = {}

-- Server-authoritative job state.
-- Jobs[identifier] = {
--     owner = source, ownerCid = identifier, state = 'spawning' | 'pickup' | 'scrapping',
--     scrap = scrapLocation, spawn = vector4, model = string, tier = Config.Tiers key,
--     vehicle = netId, entity = handle, plate = string,
--     parts = { [bone] = { removed = bool } }, total = n, removedCount = n,
--     partner = source | nil, pendingPartner = source | nil, invitedAt = os.time() | nil,
--     startedAt = os.time(), scrapStartedAt = os.time() | nil,
--     alerted = true | nil (police alert already sent for this job),
--     keysGiven = true | nil (owner received the vehicle keys after the lockpick, server/keys.lua),
--     session = { items = { [item] = count }, money = n },
-- }
local Jobs = {}
local JobsByPlate = {}    -- [plate] = identifier
local ScrapsOccupied = {} -- [scrap name] = identifier
local LastPartRemoval = {} -- [source] = GetGameTimer()
local LastWarn = {}       -- [source] = os.time()

local Security = Config.Security or {}
local TimeLimit = Config.TimeLimit or {}
local PARTS_BY_BONE = {}
local SELLABLE = {}
local CARRY_CHECKABLE = {}

for _, def in ipairs(Config.ChopParts or {}) do
    PARTS_BY_BONE[def.bone] = def
    CARRY_CHECKABLE[def.item] = true
    for _, bonus in ipairs(def.bonus or {}) do CARRY_CHECKABLE[bonus] = true end
end
if Config.FinishReward then CARRY_CHECKABLE[Config.FinishReward] = true end
for _, v in ipairs((Config.SellPed and Config.SellPed.Items) or {}) do
    SELLABLE[v.item] = v
end

-- Vehicle tiers ----------------------------------------------------------------
-- Built once from Config.Tiers (or the legacy flat Config.Vehicles list as a single 'low' tier).
local TIERS = {}     -- [key] = { key, label, weight, minLevel, minPolice, payout, quality, models, loot }
local TIER_KEYS = {} -- sorted keys, so iteration (and the weighted pick) is deterministic
local TIERS_NEED_POLICE = false
local MAX_LOOT_COUNT = 10 -- same upper bound canAddItem accepts

local function sanitizeLoot(list)
    local out = {}
    for _, entry in ipairs(type(list) == 'table' and list or {}) do
        local chance = tonumber(entry.chance) or 0
        local min = math.floor(tonumber(entry.min) or 1)
        local max = math.floor(tonumber(entry.max) or min)
        if type(entry.item) == 'string' and chance > 0 and min >= 1 then
            max = math.min(math.max(max, min), MAX_LOOT_COUNT)
            min = math.min(min, max)

            local parts
            if type(entry.parts) == 'table' then
                parts = {}
                for _, bone in ipairs(entry.parts) do parts[bone] = true end
            end

            out[#out + 1] = {
                item = entry.item,
                chance = math.min(chance, 100),
                min = min,
                max = max,
                parts = parts,
                quality = entry.quality == true,
            }
            CARRY_CHECKABLE[entry.item] = true
        end
    end
    return out
end

do
    local defs = Config.Tiers
    if type(defs) ~= 'table' or next(defs) == nil then
        defs = {}
        if type(Config.Vehicles) == 'table' then
            defs.low = { label = 'tier_low', weight = 1, minLevel = 0, payout = 1.0, quality = 'standard', models = Config.Vehicles }
        end
    end

    for key, def in pairs(defs) do
        local models = {}
        for _, model in ipairs(type(def.models) == 'table' and def.models or {}) do
            if type(model) == 'string' and model ~= '' then models[#models + 1] = model end
        end

        local weight = tonumber(def.weight) or 0
        if #models > 0 and weight > 0 then
            local tier = {
                key = key,
                label = def.label or tostring(key),
                weight = weight,
                minLevel = tonumber(def.minLevel) or 0,
                minPolice = tonumber(def.minPolice) or 0,
                payout = math.max(tonumber(def.payout) or 1.0, 0),
                quality = type(def.quality) == 'string' and def.quality or nil,
                models = models,
                loot = sanitizeLoot(def.loot),
            }
            TIERS[key] = tier
            TIER_KEYS[#TIER_KEYS + 1] = key
            if tier.minPolice > 0 then TIERS_NEED_POLICE = true end
        else
            print(('^3[nek_chopshop] Tier %s ignored: it needs models and a weight above 0^7'):format(tostring(key)))
        end
    end
    table.sort(TIER_KEYS, function(a, b) return tostring(a) < tostring(b) end)
    if #TIER_KEYS == 0 then print('^1[nek_chopshop] No usable vehicle tier: check Config.Tiers^7') end
end

-- Item validation ------------------------------------------------------------------
-- Every configured item must exist in the inventory. Unknown loot entries are dropped (a roll could
-- never be granted); unknown part, bonus and finish reward items are only reported.
-- Runs when the inventory is already started at load time, and again whenever one of its item
-- resources (Inventory.ItemResources) (re)starts. An inventory that cannot tell whether an item
-- exists (Inventory.ItemExists returns nil) skips the check.

local function itemExists(name)
    local ok, exists = pcall(Inventory.ItemExists, name)
    if not ok then return true end -- unknown: never drop loot on a failed lookup
    return exists ~= false
end

local function validateItems()
    local function warn(kind, name)
        print(('^3[nek_chopshop] %s item "%s" is not registered in %s^7'):format(kind, tostring(name),
            tostring(InventorySystem)))
    end

    for _, def in ipairs(Config.ChopParts or {}) do
        if not itemExists(def.item) then warn('Part', def.item) end
        for _, bonus in ipairs(def.bonus or {}) do
            if not itemExists(bonus) then warn('Bonus', bonus) end
        end
    end
    if Config.FinishReward and not itemExists(Config.FinishReward) then warn('FinishReward', Config.FinishReward) end

    for _, key in ipairs(TIER_KEYS) do
        local tier = TIERS[key]
        local kept = {}
        for _, entry in ipairs(tier.loot) do
            if itemExists(entry.item) then
                kept[#kept + 1] = entry
            else
                print(('^3[nek_chopshop] Loot item "%s" of tier %s is not registered in %s: entry dropped^7')
                    :format(entry.item, tostring(key), tostring(InventorySystem)))
            end
        end
        tier.loot = kept
    end
end

local ITEM_RESOURCES = {}
for _, name in ipairs(Inventory.ItemResources or {}) do ITEM_RESOURCES[name] = true end

AddEventHandler('onResourceStart', function(resource)
    if ITEM_RESOURCES[resource] then validateItems() end
end)

-- The inventory was detected after this resource started (shared/inventory.lua): refresh the item
-- resources of the new adapter and validate the configured items against it.
AddEventHandler('nek_chopshop:inventoryResolved', function()
    for name in pairs(ITEM_RESOURCES) do ITEM_RESOURCES[name] = nil end
    for _, name in ipairs(Inventory.ItemResources or {}) do ITEM_RESOURCES[name] = true end
    if InventorySystem then validateItems() end
end)
do
    -- Validate now when every item resource is already running (custom with none: validate once)
    local ready = true
    for name in pairs(ITEM_RESOURCES) do
        if GetResourceState(name) ~= 'started' then ready = false end
    end
    if InventorySystem and ready then validateItems() end
end

local QUALITY_MULT = (Config.SellPed and Config.SellPed.QualityMultiplier) or {}

local spawned = false

-- Thin wrapper over ox_lib's locale(); texts come from locales/<lang>.json (server language: ox:locale).
local function _L(key, ...)
    return locale(key, ...)
end

-- Inventory metadata for the part items of a job: the tier quality plus a readable description,
-- in the detected inventory's shape (ox `quality`, `chopQuality` elsewhere; see server/inventory.lua).
-- nil when the tier has no quality (items are then plain, and sold as 'standard').
local function jobItemMetadata(job)
    local tier = job.tier and TIERS[job.tier]
    local quality = tier and tier.quality
    if not quality then return nil end
    return Inventory.MakeMetadata(quality, _L('item_quality', _L(('quality_%s'):format(quality))))
end

-- Sell price multiplier for a stack quality (Inventory.GetStacks); no or unknown quality = 'standard'.
local function qualityMultiplier(quality)
    local mult = quality and tonumber(QUALITY_MULT[quality]) or nil
    mult = mult or tonumber(QUALITY_MULT.standard) or 1.0
    return mult > 0 and mult or 0
end

-- repMultiplier: the seller's reputation sell multiplier (Reputation.GetPerks), 1.0 when omitted.
local function stackValue(itemConfig, stack, repMultiplier)
    return math.floor(stack.count * itemConfig.price * qualityMultiplier(stack.quality) * (repMultiplier or 1.0))
end

-- Stacks of an item as they are priced and sold. With an inventory that cannot remove from an exact
-- stack (Inventory.ExactStacks = false, e.g. core_inventory) the removed copy may not be the priced
-- one, so every stack is priced at the lowest quality held and a rollback gives back that lowest
-- quality: the player can never gain from the mismatch.
local function sellStacks(source, item)
    local stacks = Bridge.GetItemStacks(source, item)
    if Inventory.ExactStacks or #stacks < 2 then return stacks end

    local lowest
    for _, stack in ipairs(stacks) do
        if not lowest or qualityMultiplier(stack.quality) < qualityMultiplier(lowest.quality) then lowest = stack end
    end
    for _, stack in ipairs(stacks) do
        stack.quality = lowest.quality
        stack.metadata = lowest.metadata
    end
    return stacks
end

-- Helpers -------------------------------------------------------------------

local function debugPrint(...)
    if Config.Debug then print('[nek_chopshop]', ...) end
end

local function trim(text)
    if type(text) ~= 'string' then return nil end
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Accepts only a positive integer that belongs to a connected player.
local function toPlayerId(value)
    local n = tonumber(value)
    if not n or n ~= n or n < 1 or n > 65535 or n % 1 ~= 0 then return nil end
    n = math.floor(n)
    if not GetPlayerName(n) then return nil end
    return n
end

local function warnExploit(source, reason)
    local now = os.time()
    if LastWarn[source] and now - LastWarn[source] < (Security.WarnThrottle or 30) then return end
    LastWarn[source] = now

    print(('^3[nek_chopshop] Suspicious request from %s (%s): %s^7'):format(
        GetPlayerName(source) or 'unknown', tostring(source), reason))

    if Config.Logs and Config.Logs.EnableWarn ~= false then
        ServerUtils.SendDiscordLog(_L('logs.warn_title'),
            _L('logs.warn_body', tostring(Bridge.GetName(source) or 'unknown'), tostring(source),
                tostring(Bridge.GetIdentifier(source)), reason),
            Config.Discord.Color.warn)
    end
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function isPlayerNear(source, coords, maxDistance)
    local playerCoords = getPlayerCoords(source)
    if not playerCoords or not coords then return false end
    return #(playerCoords - vec3(coords.x, coords.y, coords.z)) <= maxDistance
end

-- Returns the job vehicle only if it is still the exact entity we spawned
-- (guards against network ids being reused by an unrelated vehicle).
-- Identity is a server-set state bag: server-set plates only sync once a client owns the entity.
local function getJobVehicle(job)
    if not job.entity or not DoesEntityExist(job.entity) then return nil end
    if NetworkGetEntityFromNetworkId(job.vehicle) ~= job.entity then return nil end
    if Entity(job.entity).state.chopJob ~= job.ownerCid then return nil end
    return job.entity
end

local function isParticipant(job, source)
    return job.owner == source or job.partner == source
end

local function getJobByPlate(plate)
    plate = trim(plate)
    local cid = plate and JobsByPlate[plate]
    return cid and Jobs[cid] or nil
end

local INVITE_TTL = 30 -- seconds an invite stays valid (it only blocks the invitee while open)

local function hasOpenInvite(job, source)
    return job.pendingPartner == source and job.invitedAt and os.time() - job.invitedAt <= INVITE_TTL
end

-- True if the player owns a job, is a partner of one, or has an open invite.
local function isBusy(source)
    local cid = Bridge.GetIdentifier(source)
    if cid and Jobs[cid] then return true end
    for _, job in pairs(Jobs) do
        if job.partner == source or hasOpenInvite(job, source) then return true end
    end
    return false
end

local function generatePlate()
    for _ = 1, 50 do
        local plate = ('DES%05d'):format(math.random(0, 99999))
        if not JobsByPlate[plate] then return plate end
    end
    return nil
end

local function pickFreeScrap()
    local free = {}
    for _, scrap in ipairs(Config.Coords.Scrap) do
        if not ScrapsOccupied[scrap.name] then free[#free + 1] = scrap end
    end
    if #free == 0 then return nil end
    return free[math.random(1, #free)]
end

local function isSpawnClear(point)
    local radius = Security.SpawnClearRadius or 3.0
    local pos = vec3(point.x, point.y, point.z)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(vehicle) - pos) <= radius then return false end
    end
    return true
end

-- Read-only check used by the job board; does not reserve anything.
local function hasFreeScrap()
    for _, scrap in ipairs(Config.Coords.Scrap) do
        if not ScrapsOccupied[scrap.name] then return true end
    end
    return false
end

local function pickSpawnPoint()
    local spawns = Config.Coords.Spawns
    for _ = 1, 10 do
        local point = spawns[math.random(1, #spawns)]
        if isSpawnClear(point) then return point end
    end
    return nil
end

-- True when the police requirement is disabled or enough officers are on duty.
local function hasEnoughPolice()
    local min = (Config.Police and Config.Police.MinOnDuty) or 0
    if min <= 0 then return true end
    return Bridge.GetPoliceCount() >= min
end

-- Tiers the player qualifies for (reputation level and police on duty), their total weight and
-- whether at least one tier of the player's level was left out only for lack of police. Never yields.
local function eligibleTiers(source)
    local level = tonumber(GetPlayerLevel and GetPlayerLevel(source)) or 0
    local police = TIERS_NEED_POLICE and Bridge.GetPoliceCount() or 0

    local eligible, totalWeight, blockedByPolice = {}, 0, false
    for _, key in ipairs(TIER_KEYS) do
        local tier = TIERS[key]
        if level >= tier.minLevel then
            if police >= tier.minPolice then
                eligible[#eligible + 1] = tier
                totalWeight = totalWeight + tier.weight
            else
                blockedByPolice = true
            end
        end
    end
    return eligible, totalWeight, blockedByPolice
end

-- Weighted pick among the tiers the player qualifies for (reputation level and police on duty).
-- A tier's minPolice is checked on top of Config.Police.MinOnDuty (checked before by hasEnoughPolice).
-- Returns the tier, or nil and the requestJob status to answer with.
local function pickTier(source)
    local eligible, totalWeight, blockedByPolice = eligibleTiers(source)
    if #eligible == 0 then return nil, blockedByPolice and 'no_police' or 'error' end

    local roll = math.random() * totalWeight
    for _, tier in ipairs(eligible) do
        roll = roll - tier.weight
        if roll < 0 then return tier end
    end
    return eligible[#eligible]
end

local function hasLockpick(source)
    for _, item in ipairs(Config.LockpickItems or { 'lockpick' }) do
        local count = Bridge.GetItemCount(source, item)
        if count and count > 0 then return true end
    end
    return false
end

-- Cooldowns ------------------------------------------------------------------
-- Stored in resource KVP so they survive restarts. Saved per character and per
-- license, so switching character does not reset the cooldown.

local function cooldownKeys(source, cid)
    local keys = { 'cooldown:cid:' .. cid }
    local license = GetPlayerIdentifierByType(source, 'license')
    if license then keys[#keys + 1] = 'cooldown:license:' .. license end
    return keys
end

local function getCooldownExpiry(source, cid)
    local expiry = 0
    for _, key in ipairs(cooldownKeys(source, cid)) do
        expiry = math.max(expiry, tonumber(GetResourceKvpString(key)) or 0)
    end
    return expiry
end

local function setCooldown(source, cid, expiry)
    for _, key in ipairs(cooldownKeys(source, cid)) do
        if expiry then
            SetResourceKvp(key, tostring(expiry))
        else
            DeleteResourceKvp(key)
        end
    end
end

-- Rewards ---------------------------------------------------------------------

local function TrackItem(job, item, count)
    job.session.items[item] = (job.session.items[item] or 0) + count
end

local function GiveJobItem(source, job, item, count, metadata)
    count = count or 1
    local success = Bridge.AddItem(source, item, count, metadata)
    if not success then
        warnExploit(source, ('could not receive %s x%d (inventory full?)'):format(item, count))
        return false
    end

    TrackItem(job, item, count)

    if Config.Logs and Config.Logs.EnableItem then
        local desc = _L('logs.item_body', tostring(Bridge.GetName(source)), source,
            tostring(Bridge.GetIdentifier(source)), item, count)
        ServerUtils.SendDiscordLog(_L('logs.item_title'), desc, Config.Discord.Color.item)
    end
    return true
end

local function PayChopShop(source, job, amount, reason)
    amount = math.floor(amount or 0)
    reason = reason or _L('logs.reason_payment')

    if Bridge.AddMoney(source, amount, reason) then
        job.session.money = job.session.money + amount

        if Config.Logs and Config.Logs.EnablePay then
            local desc = _L('logs.pay_body', tostring(Bridge.GetName(source)), source,
                tostring(Bridge.GetIdentifier(source)), amount, reason)
            ServerUtils.SendDiscordLog(_L('logs.pay_title'), desc, Config.Discord.Color.pay)
        end
    end
end

-- Job lifecycle ---------------------------------------------------------------

-- Takes back the vehicle keys the owner received after the lockpick (partners never get keys).
-- Runs before the vehicle is deleted: some key scripts (qbx_vehiclekeys) bind keys to the entity.
local function removeJobKeys(job, vehicle)
    if not job.keysGiven then return end
    job.keysGiven = nil
    if Config.VehicleKeys and Config.VehicleKeys.RemoveOnEnd == false then return end
    VehicleKeys.Remove(job.owner, vehicle, job.plate, job.model)
end

-- Releases every resource held by a job. Does not reward anything.
local function ReleaseJob(cid, deleteVehicle)
    local job = Jobs[cid]
    if not job then return end

    -- Cleanup uses the spawned entity itself whenever it still exists: getJobVehicle() is a strict
    -- identity check meant for client requests and can fail on a car that is still in the world,
    -- which would otherwise leave the keys and the vehicle behind.
    local vehicle = (job.entity and DoesEntityExist(job.entity)) and job.entity or getJobVehicle(job)
    removeJobKeys(job, vehicle)
    if deleteVehicle ~= false and vehicle then
        DeleteEntity(vehicle)
    end

    if job.scrap and ScrapsOccupied[job.scrap.name] == cid then
        ScrapsOccupied[job.scrap.name] = nil
    end
    if job.plate and JobsByPlate[job.plate] == cid then JobsByPlate[job.plate] = nil end
    Jobs[cid] = nil
end

local function notifyParticipants(job, reason)
    TriggerClientEvent('chopshop:client:jobFinished', job.owner, job.vehicle, true, reason)
    if job.partner then
        TriggerClientEvent('chopshop:client:jobFinished', job.partner, job.vehicle, false, reason)
    end
end

-- Cancels a job without rewards (time limit, vehicle lost, owner left). Cooldown is kept.
local function CancelJob(cid, reason)
    local job = Jobs[cid]
    if not job then return end
    debugPrint('Cancelling job of', cid, reason)
    -- A lost vehicle (destroyed, deleted, despawned) is penalised like a missed time limit
    if reason == 'expired' or reason == 'vehicle_lost' then Reputation.OnJobFailed(cid, 'expired') end
    notifyParticipants(job, reason)
    ReleaseJob(cid, true)
end

local function FinishJob(cid)
    local job = Jobs[cid]
    if not job then return end
    local source = job.owner

    if Config.FinishReward then
        GiveJobItem(source, job, Config.FinishReward, 1, jobItemMetadata(job))
    end

    if Config.Payment and Config.Payment.Enable then
        local min = Config.Payment.Min or 250
        local max = Config.Payment.Max or 400
        local tier = job.tier and TIERS[job.tier]
        local multiplier = tier and tier.payout or 1.0
        PayChopShop(source, job, math.random(min, max) * multiplier, _L('logs.reason_final_payment'))
    end

    if Editable and Editable.Server and Editable.Server.CustomReward then
        Editable.Server.CustomReward(source)
    end

    -- Reputation: the time bonus scales with the fraction of the scrap time limit that was left
    local scrapLimit = (TimeLimit.Scrap or 10) * 60
    local timeLeft = job.scrapStartedAt and scrapLimit > 0
        and (scrapLimit - (os.time() - job.scrapStartedAt)) / scrapLimit or 0
    local partnerCid = job.partner and Bridge.GetIdentifier(job.partner) or nil
    Reputation.OnJobFinished(cid, source, partnerCid, job.partner, job.removedCount, timeLeft)

    if Config.Logs and Config.Logs.EnableFinish then
        local desc = _L('logs.finish_body', tostring(Bridge.GetName(source)), source, tostring(cid),
            ServerUtils.FormatItemsList(job.session.items), job.session.money)
        ServerUtils.SendDiscordLog(_L('logs.finish_title'), desc, Config.Discord.Color.finished)
    end

    notifyParticipants(job, 'finished')

    -- Let clients fade the vehicle out before it is removed
    local vehicle = getJobVehicle(job)
    ReleaseJob(cid, false)
    SetTimeout(2500, function()
        if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end)
end

-- Police alert ------------------------------------------------------------------
-- At most one alert per job. Location, plate and model always come from the server job.
-- Server-side adapters (and the server custom hook) run here; the caller hands the returned system
-- and data to the owner's client for client-side adapters (and the client custom hook).

local function buildAlert(job, vehicle)
    if job.alerted then return nil end
    job.alerted = true

    local vehicleCoords = GetEntityCoords(vehicle)
    local dispatch = (Config.Police and Config.Police.Dispatch) or {}
    local data = {
        coords = vec3(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z),
        plate = job.plate,
        model = job.model,
        code = dispatch.Code or '10-35',
        title = _L(dispatch.Title or 'dispatch_title'),
        message = _L(dispatch.Message or 'dispatch_message', job.model, job.plate),
        jobs = (Config.Police and Config.Police.Jobs) or { 'police' },
        jobType = Config.Police and Config.Police.JobType or nil,
    }

    local system = ServerDispatch.Send(job.owner, data)
    if not system then return nil end
    return system, data
end

-- Sends the alert from a transition the server observed itself (owner in the vehicle, or delivery):
-- a modified client cannot skip it by never asking for it.
local function alertFromServer(job, vehicle)
    local system, data = buildAlert(job, vehicle)
    if system then
        TriggerClientEvent('chopshop:client:dispatchAlert', job.owner, system, data, job.vehicle)
    end
end

-- Expires stuck or abandoned jobs so they cannot hold scrap points forever.
-- The same sweep sends the police alert once the owner is seen driving the job vehicle.
CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        local pickupLimit = (TimeLimit.Pickup or 20) * 60
        local scrapLimit = (TimeLimit.Scrap or 10) * 60

        for cid, job in pairs(Jobs) do
            if job.state ~= 'spawning' then
                local vehicle = getJobVehicle(job)
                if not vehicle then
                    CancelJob(cid, 'vehicle_lost')
                elseif job.state == 'pickup' and now - job.startedAt > pickupLimit then
                    CancelJob(cid, 'expired')
                elseif job.state == 'scrapping' and now - job.scrapStartedAt > scrapLimit then
                    CancelJob(cid, 'expired')
                elseif job.state == 'pickup' and not job.alerted
                    and GetVehiclePedIsIn(GetPlayerPed(job.owner), false) == vehicle then
                    alertFromServer(job, vehicle)
                end
            end
        end
    end
end)

-- Ped spawning --------------------------------------------------------------

function SpawnPed(data)
    local ped = CreatePed(4, data.Model, data.Coords.x, data.Coords.y, data.Coords.z, data.Coords.w, true, true)

    PED['id'] = ped
    PED['nwid'] = NetworkGetNetworkIdFromEntity(ped)
    PED['coords'] = data.Coords
    PED['target'] = data.Target
    PED['scenario'] = data.Scenario

    TriggerClientEvent('chopshop:client:setupPed', -1, PED)
end

function SpawnSellPed(data)
    local ped = CreatePed(4, data.Model, data.Coords.x, data.Coords.y, data.Coords.z, data.Coords.w, true, true)

    SELL_PED['id'] = ped
    SELL_PED['nwid'] = NetworkGetNetworkIdFromEntity(ped)
    SELL_PED['coords'] = data.Coords
    SELL_PED['scenario'] = data.Scenario
    SELL_PED['items'] = data.Items

    TriggerClientEvent('chopshop:client:setupSellPed', -1, SELL_PED)
end

-- Framework-agnostic: the client fires this once its character is loaded
-- (covers ESX, QBCore and Qbox, plus resource restarts with players online)
RegisterNetEvent('chopshop:server:playerReady', function()
    local source = source
    Reputation.Warm(source) -- background load, so GetPlayerLevel can answer from the cache
    if not spawned then
        SpawnPed(Config.Ped)
        if Config.SellPed and Config.SellPed.Enable then
            SpawnSellPed(Config.SellPed)
        end
        spawned = true
    else
        TriggerClientEvent('chopshop:client:setupPed', source, PED)
        if Config.SellPed and Config.SellPed.Enable then
            TriggerClientEvent('chopshop:client:setupSellPed', source, SELL_PED)
        end
    end
end)

-- Callbacks -----------------------------------------------------------------

lib.callback.register('chopshop:server:addPedProperties', function()
    return PED
end)

lib.callback.register('chopshop:server:getSellPed', function()
    return SELL_PED
end)

lib.callback.register('chopshop:server:getCooldown', function(source)
    local cid = Bridge.GetIdentifier(source)
    if not cid then return nil end

    local remaining = getCooldownExpiry(source, cid) - os.time()
    return remaining > 0 and remaining or 0
end)

-- Snapshot for the NUI job board: cooldown end (epoch seconds, 0 = none), whether a bay is free,
-- whether police presence allows a job, whether the player already has a job and the reputation block
-- (nil when Config.Reputation is disabled). Purely informational; requestJob validates again.
-- Only answered next to the job ped, so police presence cannot be polled from anywhere on the map.
lib.callback.register('chopshop:server:getBoardStatus', function(source)
    local cid = Bridge.GetIdentifier(source)
    if not cid then return nil end
    if not isPlayerNear(source, Config.Ped.Coords, Security.PedDistance or 10.0) then return nil end

    -- May yield (first read of the row); it also warms the cache GetPlayerLevel reads
    local reputation = Reputation.GetBoardBlock(source)

    -- Same eligibility as requestJob: false only when police is what keeps every tier of the
    -- player's level out (a level-only block is reported by requestJob itself)
    local policeOk = hasEnoughPolice()
    if policeOk then
        local eligible, _, blockedByPolice = eligibleTiers(source)
        policeOk = #eligible > 0 or not blockedByPolice
    end

    local expiry = getCooldownExpiry(source, cid)
    return {
        cooldownUntil = expiry > os.time() and expiry or 0,
        scrapAvailable = hasFreeScrap(),
        policeOk = policeOk,
        busy = isBusy(source),
        reputation = reputation,
    }
end)

-- Everything about the job (vehicle model, spawn point, scrap location) is chosen here.
-- Every reservation is written before the first Wait() so concurrent calls cannot race.
lib.callback.register('chopshop:server:requestJob', function(source)
    local cid = Bridge.GetIdentifier(source)
    if not cid then return 'error' end

    if isBusy(source) then return 'already_working' end

    if getCooldownExpiry(source, cid) > os.time() then
        return 'cooldown'
    end

    if not isPlayerNear(source, Config.Ped.Coords, Security.PedDistance or 10.0) then
        warnExploit(source, 'requestJob far from the job ped')
        return 'error'
    end

    if not hasEnoughPolice() then return 'no_police' end

    -- GetPlayerLevel must not yield (see server/reputation.lua): the reservations below rely on it
    local tier, tierStatus = pickTier(source)
    if not tier then return tierStatus end

    local scrap = pickFreeScrap()
    if not scrap then return 'no_scrap' end

    local spawnPoint = pickSpawnPoint()
    local plate = generatePlate()
    if not spawnPoint or not plate then return 'error' end

    local model = tier.models[math.random(1, #tier.models)]
    local now = os.time()

    local job = {
        owner = source,
        ownerCid = cid,
        state = 'spawning',
        scrap = scrap,
        spawn = spawnPoint,
        model = model,
        tier = tier.key,
        plate = plate,
        parts = {},
        total = 0,
        removedCount = 0,
        startedAt = now,
        session = { items = {}, money = 0 },
    }
    Jobs[cid] = job
    JobsByPlate[plate] = cid
    ScrapsOccupied[scrap.name] = cid
    -- Reputation perk: shorter wait (cache read, no yield before the reservations above are complete)
    local cooldownMult = Reputation.GetPerks(source).cooldownMultiplier
    setCooldown(source, cid, now + math.floor((Config.Cooldown or 3600) * cooldownMult))

    local vehicle = CreateVehicleServerSetter(joaat(model), 'automobile', spawnPoint.x, spawnPoint.y, spawnPoint.z,
        spawnPoint.w)

    local timeout = GetGameTimer() + 5000
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or Jobs[cid] ~= job then
        debugPrint('Vehicle spawn failed for model', model)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        if Jobs[cid] == job then
            ReleaseJob(cid, false)
            setCooldown(source, cid, nil) -- the player got nothing, let them retry
        end
        return 'error'
    end

    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDoorsLocked(vehicle, 2)
    Entity(vehicle).state:set('chopJob', cid, false)

    job.entity = vehicle
    job.vehicle = NetworkGetNetworkIdFromEntity(vehicle)
    job.startedAt = os.time()
    job.state = 'pickup'

    -- Appended values: deadline of the pickup phase (epoch seconds), plate and model for the NUI tracker,
    -- and the tier label (locale key) for the job start notification
    return 'success', job.vehicle, scrap, spawnPoint, job.startedAt + (TimeLimit.Pickup or 20) * 60, job.plate, job.model,
        tier.label
end)

-- The owner's client reports a successful lockpick of the job vehicle. Only the owner, during pickup,
-- close to the job vehicle (Config.Security.DispatchDistance). Nothing here is chosen by the client:
-- the vehicle, plate and model are the server job's.
-- 1. Vehicle keys (server/keys.lua): once per job, only when the owner holds a lockpick item
--    server-side, and only for this job's vehicle. A client that never calls this gets no keys.
-- 2. Early police alert: at most one per job (no-op once the server sweep or startScrap sent it).
-- Returns the alert system the client must run (client-side adapter or 'custom') and the alert data.
lib.callback.register('chopshop:server:vehicleLockpicked', function(source)
    local cid = Bridge.GetIdentifier(source)
    local job = cid and Jobs[cid]
    if not job or job.owner ~= source or job.state ~= 'pickup' then return nil end

    local vehicle = getJobVehicle(job)
    if not vehicle then return nil end

    if not isPlayerNear(source, GetEntityCoords(vehicle), Security.DispatchDistance or 10.0) then return nil end

    if not job.keysGiven then
        -- Some inventories may yield on the item read: check the job again afterwards
        local lockpick = hasLockpick(source)
        if Jobs[cid] ~= job or job.state ~= 'pickup' or getJobVehicle(job) ~= vehicle then return nil end
        if lockpick and not job.keysGiven then
            -- Flag first: removal at the end of the job is attempted even if the key script failed half-way
            job.keysGiven = true
            VehicleKeys.Give(source, vehicle, job.plate, job.model)
        end
    end

    return buildAlert(job, vehicle)
end)

-- Owner arrived at the scrap point. The client reports which configured bones the
-- vehicle actually has; the server only accepts bones from Config.ChopParts and,
-- after the first report of a model, never more than that model was first seen with.
lib.callback.register('chopshop:server:startScrap', function(source, bones)
    local cid = Bridge.GetIdentifier(source)
    local job = cid and Jobs[cid]
    if not job or job.owner ~= source then return false end
    if job.state == 'scrapping' then return job.parts, job.plate, job.scrapStartedAt + (TimeLimit.Scrap or 10) * 60 end
    if job.state ~= 'pickup' or type(bones) ~= 'table' then return false end

    local vehicle = getJobVehicle(job)
    if not vehicle then return false end

    local scrapDistance = Security.ScrapDistance or 15.0
    local scrapCoords = vec3(job.scrap.coords.x, job.scrap.coords.y, job.scrap.coords.z)
    -- Rejections return a reason code as second value so the client can tell the player why
    if #(GetEntityCoords(vehicle) - scrapCoords) > scrapDistance or not isPlayerNear(source, scrapCoords, scrapDistance) then
        return false, 'too_far'
    end

    -- A delivery faster than a plausible drive means the vehicle was teleported.
    -- Admins (Config.AdminAce) skip this check so they can test with teleports.
    local travel = #(vec3(job.spawn.x, job.spawn.y, job.spawn.z) - scrapCoords)
    local minSeconds = travel / (Security.MaxAverageSpeed or 60.0)
    local elapsed = os.time() - job.startedAt
    if elapsed < minSeconds and not IsPlayerAceAllowed(source, Config.AdminAce or 'admin') then
        warnExploit(source, ('startScrap after %ds for a %dm trip'):format(elapsed, math.floor(travel)))
        return false, 'too_fast', math.ceil(minSeconds - elapsed)
    end

    if not hasLockpick(source) then
        warnExploit(source, 'startScrap without a lockpick item')
        return false, 'no_lockpick'
    end

    local reported = {}
    for _, bone in ipairs(bones) do
        if type(bone) == 'string' then reported[bone] = true end
    end

    local parts, total = {}, 0
    for bone, def in pairs(PARTS_BY_BONE) do
        -- Optional parts (everything but the wheels) are only included when the model has the bone;
        -- the wheels are always part of the job, whatever the client claims.
        if not def.optional or reported[bone] then
            parts[bone] = { removed = false }
            total = total + 1
        end
    end
    if total == 0 then return false end

    -- Fallback: the vehicle was delivered before the sweep saw the owner driving it
    if not job.alerted then alertFromServer(job, vehicle) end

    -- The client froze the vehicle on arrival; only the network owner's unfreeze syncs, so release it
    -- from the server too, or broken-off wheels leave the body floating
    FreezeEntityPosition(vehicle, false)

    job.parts = parts
    job.total = total
    job.state = 'scrapping'
    job.scrapStartedAt = os.time()

    -- A partner who accepted the invite before the start joins now
    if job.partner then TriggerClientEvent('chopshop:client:scrapStarted', job.partner, job.vehicle) end

    return parts, job.plate, job.scrapStartedAt + (TimeLimit.Scrap or 10) * 60
end)

lib.callback.register('chopshop:server:getParts', function(source, plate)
    local job = getJobByPlate(plate)
    if not job or job.state ~= 'scrapping' or not isParticipant(job, source) then return false end
    return job.parts, job.plate, job.scrapStartedAt + (TimeLimit.Scrap or 10) * 60
end)

-- Owner invites a nearby player once the vehicle is parked at the scrap and before the scrap starts.
-- The invited player has to accept explicitly. The job is looked up by the owner, not by the plate.
lib.callback.register('chopshop:server:sendVehicleToScrap', function(source, _, coworker)
    local cid = Bridge.GetIdentifier(source)
    local job = cid and Jobs[cid]
    if not job or job.owner ~= source or job.state ~= 'pickup' or job.partner then return false end
    if job.pendingPartner and hasOpenInvite(job, job.pendingPartner) then return false end

    local vehicle = getJobVehicle(job)
    local scrapCoords = vec3(job.scrap.coords.x, job.scrap.coords.y, job.scrap.coords.z)
    if not vehicle or #(GetEntityCoords(vehicle) - scrapCoords) > (Security.ScrapDistance or 15.0) then
        return false
    end

    coworker = toPlayerId(coworker)
    if not coworker or coworker == source or not Bridge.GetIdentifier(coworker) then return false end
    if isBusy(coworker) then return false end

    local ownerCoords = getPlayerCoords(source)
    if not ownerCoords or not isPlayerNear(coworker, ownerCoords, Security.PartnerDistance or 20.0) then
        return false
    end

    job.pendingPartner = coworker
    job.invitedAt = os.time()
    TriggerClientEvent('chopshop:client:partnerInvite', coworker, {
        vehicle = job.vehicle,
        plate = job.plate,
        from = Bridge.GetName(source),
    })
    return true
end)

lib.callback.register('chopshop:server:answerInvite', function(source, plate, accepted)
    local job = getJobByPlate(plate)
    if not job or not hasOpenInvite(job, source) then return false end

    job.pendingPartner = nil
    job.invitedAt = nil
    if accepted ~= true or job.state ~= 'pickup' or job.partner then return false end

    local vehicle = getJobVehicle(job)
    if not vehicle or not isPlayerNear(source, GetEntityCoords(vehicle), Security.PartnerDistance or 20.0) then
        return false
    end

    job.partner = source
    return true
end)

-- UI only: whether the player holds one of Config.LockpickItems. startScrap checks it again.
lib.callback.register('chopshop:server:hasLockpick', function(source)
    return hasLockpick(source)
end)

lib.callback.register('chopshop:server:canAddItem', function(source, item, count)
    if not CARRY_CHECKABLE[item] then return false end
    count = tonumber(count)
    if not count or count ~= count or count < 1 or count > 10 then return false end
    return Bridge.CanCarryItem(source, item, math.floor(count))
end)

-- Removing a part is the only way to get part items.
lib.callback.register('chopshop:server:removePart', function(source, plate, bone)
    local job = getJobByPlate(plate)
    if not job or job.state ~= 'scrapping' or not isParticipant(job, source) then return false end

    local partState = type(bone) == 'string' and job.parts[bone]
    local def = partState and PARTS_BY_BONE[bone]
    if not def or partState.removed then return false end

    -- A part can require another one to be removed first; a requirement that is not part of
    -- this job (the model lacks that bone) counts as satisfied.
    local required = def.requires and job.parts[def.requires]
    if required and not required.removed then return false, 'requires' end

    local vehicle = getJobVehicle(job)
    if not vehicle then return false end

    local playerCoords = getPlayerCoords(source)
    if not playerCoords or #(playerCoords - GetEntityCoords(vehicle)) > (Security.PartDistance or 6.0) then
        warnExploit(source, ('removePart %s too far from the vehicle'):format(bone))
        return false
    end

    local now = GetGameTimer()
    if LastPartRemoval[source] and now - LastPartRemoval[source] < (Security.PartInterval or 2000) then
        warnExploit(source, 'removePart rate limit exceeded')
        return false
    end

    -- Everything this removal gives: the part (with the tier quality), its bonus items and the tier
    -- loot rolls that apply to this bone. Rolled here, server-side only.
    local metadata = jobItemMetadata(job)
    local grants = { { item = def.item, count = 1, metadata = metadata } }
    for _, bonus in ipairs(def.bonus or {}) do
        grants[#grants + 1] = { item = bonus, count = 1, metadata = metadata }
    end
    local tier = job.tier and TIERS[job.tier]
    for _, entry in ipairs(tier and tier.loot or {}) do
        if (not entry.parts or entry.parts[bone]) and math.random() * 100 < entry.chance then
            grants[#grants + 1] = {
                item = entry.item,
                count = math.random(entry.min, entry.max),
                metadata = entry.quality and metadata or nil,
            }
        end
    end
    -- Reputation perk: chance of one extra copy of the part (checked with the rest below)
    local extraChance = Reputation.GetPerks(source).extraPartChance
    if extraChance > 0 and math.random() * 100 < extraChance then
        grants[#grants + 1] = { item = def.item, count = 1, metadata = metadata }
    end

    if not Bridge.CanCarryItems(source, grants) then return false, 'no_space' end

    -- Mark before giving anything: there is no yield between the check above and this write
    -- (ox/qb/ps adapters; with qs, core or custom it depends on their exports not yielding)
    LastPartRemoval[source] = now
    partState.removed = true

    local given = GiveJobItem(source, job, def.item, 1, metadata)
    if not given then
        if Inventory.ReliableAdd then
            partState.removed = false
            return false, 'no_space'
        end
        -- This inventory's add result is not reliable: the part may really have been given, so it
        -- stays removed (re-opening it could hand it out twice). It still counts towards finishing the
        -- job, so the player is not left with a job that can only expire. Extra grants are skipped.
        print(('^1[nek_chopshop] %s: adding %s reported a failure but %s cannot confirm it; the part %s stays removed.^7')
            :format(GetPlayerName(source) or tostring(source), def.item, tostring(InventorySystem), bone))
    else
        for i = 2, #grants do
            GiveJobItem(source, job, grants[i].item, grants[i].count, grants[i].metadata)
        end
    end

    job.removedCount = job.removedCount + 1

    TriggerClientEvent('chopshop:client:brokePart', -1, job.vehicle, {
        bone = bone, part = def.part, isDoor = def.isDoor, isWheel = def.isWheel,
    })

    if job.removedCount >= job.total then
        local cid = job.ownerCid
        SetTimeout(1500, function()
            if Jobs[cid] == job then FinishJob(cid) end
        end)
    end

    if not given then return false, 'no_space' end
    return true
end)

lib.callback.register('chopshop:server:sellItem', function(source, itemName)
    local itemConfig = SELLABLE[itemName]
    if not itemConfig or not (Config.SellPed and Config.SellPed.Enable) then return false end

    if not isPlayerNear(source, Config.SellPed.Coords, Security.SellDistance or 10.0) then
        warnExploit(source, 'sellItem far from the sell ped')
        return false
    end

    -- Each stack is priced by its own quality metadata and sold on its own: removed from its exact
    -- slot, then paid. If a payment fails that stack is given back as it was and the sale stops.
    -- No yield happens between reading the stacks and removing them (ox/qb/ps; qs, core and custom
    -- depend on the vendor/owner exports not yielding). See sellStacks for inventories that cannot
    -- remove from an exact slot.
    local count, total = 0, 0
    local repMultiplier = Reputation.GetPerks(source).sellMultiplier
    for _, stack in ipairs(sellStacks(source, itemName)) do
        local value = stackValue(itemConfig, stack, repMultiplier)
        if Bridge.RemoveStack(source, itemName, stack.count, stack) then
            if Bridge.AddMoney(source, value, _L('logs.reason_sale')) then
                count = count + stack.count
                total = total + value
            else
                Bridge.AddItem(source, itemName, stack.count, stack.metadata)
                break
            end
        end
    end
    if count <= 0 then return false end

    if Config.Logs and Config.Logs.EnablePay then
        local desc = _L('logs.sale_body', tostring(Bridge.GetName(source)), source,
            tostring(Bridge.GetIdentifier(source)), itemName, count, total)
        ServerUtils.SendDiscordLog(_L('logs.sale_title'), desc, Config.Discord.Color.pay)
    end

    return true, count, total
end)

-- Read-only price quote for the sell ped: { [item] = { owned = n, total = money } } for every
-- sellable item, priced per stack by its quality. sellItem computes the price again.
lib.callback.register('chopshop:server:getSellQuote', function(source)
    if not (Config.SellPed and Config.SellPed.Enable) then return nil end

    local quote = {}
    local repMultiplier = Reputation.GetPerks(source).sellMultiplier
    for item, itemConfig in pairs(SELLABLE) do
        local owned, total = 0, 0
        for _, stack in ipairs(sellStacks(source, item)) do
            owned = owned + stack.count
            total = total + stackValue(itemConfig, stack, repMultiplier)
        end
        quote[item] = { owned = owned, total = total }
    end
    return quote
end)

-- Cleanup -------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    LastPartRemoval[source] = nil
    LastWarn[source] = nil

    for cid, job in pairs(Jobs) do
        if job.owner == source then
            -- Abandoned job: free the scrap point and remove the vehicle (cooldown is kept)
            Reputation.OnJobFailed(cid, 'abandoned')
            if job.partner then
                TriggerClientEvent('chopshop:client:jobFinished', job.partner, job.vehicle, false, 'cancelled')
            end
            ReleaseJob(cid, true)
        else
            if job.partner == source then job.partner = nil end
            if job.pendingPartner == source then job.pendingPartner = nil end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if PED['id'] then DeleteEntity(PED['id']) end
    if SELL_PED['id'] then DeleteEntity(SELL_PED['id']) end

    for cid in pairs(Jobs) do
        ReleaseJob(cid, true)
    end
end)
