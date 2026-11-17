local PED = {}
local SELL_PED = {}

-- Server-authoritative job state.
-- Jobs[identifier] = {
--     owner = source, ownerCid = identifier, state = 'spawning' | 'pickup' | 'scrapping',
--     scrap = scrapLocation, spawn = vector4, model = string,
--     vehicle = netId, entity = handle, plate = string,
--     parts = { [bone] = { removed = bool } }, total = n, removedCount = n,
--     partner = source | nil, pendingPartner = source | nil,
--     startedAt = os.time(), scrapStartedAt = os.time() | nil,
--     session = { items = { [item] = count }, money = n },
-- }
local Jobs = {}
local JobsByPlate = {}    -- [plate] = identifier
local ScrapsOccupied = {} -- [scrap name] = identifier
local ModelParts = {}     -- [model] = { [bone] = true } first bone report per model, reused afterwards
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

local spawned = false

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
        ServerUtils.SendDiscordLog("Desguace - Petición sospechosa",
            ("**Jugador:** %s (ID:%s, Identifier:`%s`)\n**Motivo:** %s"):format(
                Bridge.GetName(source) or 'unknown', tostring(source), tostring(Bridge.GetIdentifier(source)), reason),
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
local function getJobVehicle(job)
    if not job.entity or not DoesEntityExist(job.entity) then return nil end
    if NetworkGetEntityFromNetworkId(job.vehicle) ~= job.entity then return nil end
    if trim(GetVehicleNumberPlateText(job.entity)) ~= job.plate then return nil end
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

-- True if the player owns a job, is a partner of one, or has a pending invite.
local function isBusy(source)
    local cid = Bridge.GetIdentifier(source)
    if cid and Jobs[cid] then return true end
    for _, job in pairs(Jobs) do
        if job.partner == source or job.pendingPartner == source then return true end
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

local function pickSpawnPoint()
    local spawns = Config.Coords.Spawns
    for _ = 1, 10 do
        local point = spawns[math.random(1, #spawns)]
        if isSpawnClear(point) then return point end
    end
    return nil
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

local function GiveJobItem(source, job, item, count)
    count = count or 1
    local success = Bridge.AddItem(source, item, count)
    if not success then
        warnExploit(source, ('could not receive %s x%d (inventory full?)'):format(item, count))
        return false
    end

    TrackItem(job, item, count)

    if Config.Logs and Config.Logs.EnableItem then
        local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n**Item:** %s x%d")
            :format(Bridge.GetName(source), source, tostring(Bridge.GetIdentifier(source)), item, count)
        ServerUtils.SendDiscordLog("Desguace - Item obtenido", desc, Config.Discord.Color.item)
    end
    return true
end

local function PayChopShop(source, job, amount, reason)
    amount = math.floor(amount or 0)
    reason = reason or "Pago por desguace"

    if Bridge.AddMoney(source, amount, reason) then
        job.session.money = job.session.money + amount

        if Config.Logs and Config.Logs.EnablePay then
            local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n**Cantidad:** $%d\n**Motivo:** %s")
                :format(Bridge.GetName(source), source, tostring(Bridge.GetIdentifier(source)), amount, reason)
            ServerUtils.SendDiscordLog("Desguace - Pago realizado", desc, Config.Discord.Color.pay)
        end
    end
end

-- Job lifecycle ---------------------------------------------------------------

-- Releases every resource held by a job. Does not reward anything.
local function ReleaseJob(cid, deleteVehicle)
    local job = Jobs[cid]
    if not job then return end

    if deleteVehicle ~= false then
        local vehicle = getJobVehicle(job)
        if vehicle then DeleteEntity(vehicle) end
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
    notifyParticipants(job, reason)
    ReleaseJob(cid, true)
end

local function FinishJob(cid)
    local job = Jobs[cid]
    if not job then return end
    local source = job.owner

    if Config.FinishReward then
        GiveJobItem(source, job, Config.FinishReward, 1)
    end

    if Config.Payment and Config.Payment.Enable then
        local min = Config.Payment.Min or 250
        local max = Config.Payment.Max or 400
        PayChopShop(source, job, math.random(min, max), "Pago final por desguace")
    end

    if Editable and Editable.Server and Editable.Server.CustomReward then
        Editable.Server.CustomReward(source)
    end

    if Config.Logs and Config.Logs.EnableFinish then
        local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n\n**Items:** %s\n**Dinero total:** $%d")
            :format(Bridge.GetName(source), source, cid,
                ServerUtils.FormatItemsList(job.session.items), job.session.money)
        ServerUtils.SendDiscordLog("Desguace - Resumen final", desc, Config.Discord.Color.finished)
    end

    notifyParticipants(job, 'finished')

    -- Let clients fade the vehicle out before it is removed
    local vehicle = getJobVehicle(job)
    ReleaseJob(cid, false)
    SetTimeout(2500, function()
        if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end)
end

-- Expires stuck or abandoned jobs so they cannot hold scrap points forever.
CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        local pickupLimit = (TimeLimit.Pickup or 20) * 60
        local scrapLimit = (TimeLimit.Scrap or 10) * 60

        for cid, job in pairs(Jobs) do
            if job.state ~= 'spawning' then
                if not getJobVehicle(job) then
                    CancelJob(cid, 'vehicle_lost')
                elseif job.state == 'pickup' and now - job.startedAt > pickupLimit then
                    CancelJob(cid, 'expired')
                elseif job.state == 'scrapping' and now - job.scrapStartedAt > scrapLimit then
                    CancelJob(cid, 'expired')
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

    local scrap = pickFreeScrap()
    if not scrap then return 'no_scrap' end

    local spawnPoint = pickSpawnPoint()
    local plate = generatePlate()
    if not spawnPoint or not plate then return 'error' end

    local model = Config.Vehicles[math.random(1, #Config.Vehicles)]
    local now = os.time()

    local job = {
        owner = source,
        ownerCid = cid,
        state = 'spawning',
        scrap = scrap,
        spawn = spawnPoint,
        model = model,
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
    setCooldown(source, cid, now + (Config.Cooldown or 3600))

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

    job.entity = vehicle
    job.vehicle = NetworkGetNetworkIdFromEntity(vehicle)
    job.startedAt = os.time()
    job.state = 'pickup'

    return 'success', job.vehicle, scrap, spawnPoint
end)

-- Owner arrived at the scrap point. The client reports which configured bones the
-- vehicle actually has; the server only accepts bones from Config.ChopParts and,
-- after the first report of a model, never more than that model was first seen with.
lib.callback.register('chopshop:server:startScrap', function(source, bones)
    local cid = Bridge.GetIdentifier(source)
    local job = cid and Jobs[cid]
    if not job or job.owner ~= source then return false end
    if job.state == 'scrapping' then return job.parts, job.plate end
    if job.state ~= 'pickup' or type(bones) ~= 'table' then return false end

    local vehicle = getJobVehicle(job)
    if not vehicle then return false end

    local scrapDistance = Security.ScrapDistance or 15.0
    local scrapCoords = vec3(job.scrap.coords.x, job.scrap.coords.y, job.scrap.coords.z)
    if #(GetEntityCoords(vehicle) - scrapCoords) > scrapDistance or not isPlayerNear(source, scrapCoords, scrapDistance) then
        return false
    end

    -- A delivery faster than a plausible drive means the vehicle was teleported
    local travel = #(vec3(job.spawn.x, job.spawn.y, job.spawn.z) - scrapCoords)
    local minSeconds = travel / (Security.MaxAverageSpeed or 60.0)
    if os.time() - job.startedAt < minSeconds then
        warnExploit(source, ('startScrap after %ds for a %dm trip'):format(os.time() - job.startedAt, math.floor(travel)))
        return false
    end

    if not hasLockpick(source) then
        warnExploit(source, 'startScrap without a lockpick item')
        return false
    end

    local known = ModelParts[job.model]
    local reported = {}
    for _, bone in ipairs(bones) do
        if type(bone) == 'string' and PARTS_BY_BONE[bone] and (not known or known[bone]) then
            reported[bone] = true
        end
    end
    if not known then ModelParts[job.model] = reported end

    local parts, total = {}, 0
    for bone in pairs(reported) do
        parts[bone] = { removed = false }
        total = total + 1
    end
    if total == 0 then return false end

    job.parts = parts
    job.total = total
    job.state = 'scrapping'
    job.scrapStartedAt = os.time()

    return parts, job.plate
end)

lib.callback.register('chopshop:server:getParts', function(source, plate)
    local job = getJobByPlate(plate)
    if not job or job.state ~= 'scrapping' or not isParticipant(job, source) then return false end
    return job.parts, job.plate
end)

-- Owner invites a nearby player. The invited player has to accept explicitly.
lib.callback.register('chopshop:server:sendVehicleToScrap', function(source, plate, coworker)
    local job = getJobByPlate(plate)
    if not job or job.owner ~= source or job.state ~= 'scrapping' or job.partner then return false end

    coworker = toPlayerId(coworker)
    if not coworker or coworker == source or not Bridge.GetIdentifier(coworker) then return false end
    if isBusy(coworker) then return false end

    local ownerCoords = getPlayerCoords(source)
    if not ownerCoords or not isPlayerNear(coworker, ownerCoords, Security.PartnerDistance or 20.0) then
        return false
    end

    job.pendingPartner = coworker
    TriggerClientEvent('chopshop:client:partnerInvite', coworker, {
        vehicle = job.vehicle,
        plate = job.plate,
        from = Bridge.GetName(source),
    })
    return true
end)

lib.callback.register('chopshop:server:answerInvite', function(source, plate, accepted)
    local job = getJobByPlate(plate)
    if not job or job.pendingPartner ~= source then return false end

    job.pendingPartner = nil
    if accepted ~= true or job.state ~= 'scrapping' or job.partner then return false end

    local vehicle = getJobVehicle(job)
    if not vehicle or not isPlayerNear(source, GetEntityCoords(vehicle), Security.PartnerDistance or 20.0) then
        return false
    end

    job.partner = source
    return true
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

    if not Bridge.CanCarryItem(source, def.item, 1) then return false, 'no_space' end
    for _, bonus in ipairs(def.bonus or {}) do
        if not Bridge.CanCarryItem(source, bonus, 1) then return false, 'no_space' end
    end

    -- Mark before giving anything: there is no yield between the check above and this write
    LastPartRemoval[source] = now
    partState.removed = true

    if not GiveJobItem(source, job, def.item, 1) then
        partState.removed = false
        return false, 'no_space'
    end
    for _, bonus in ipairs(def.bonus or {}) do
        GiveJobItem(source, job, bonus, 1)
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

    return true
end)

lib.callback.register('chopshop:server:sellItem', function(source, itemName)
    local itemConfig = SELLABLE[itemName]
    if not itemConfig or not (Config.SellPed and Config.SellPed.Enable) then return false end

    if not isPlayerNear(source, Config.SellPed.Coords, Security.SellDistance or 10.0) then
        warnExploit(source, 'sellItem far from the sell ped')
        return false
    end

    local count = Bridge.GetItemCount(source, itemName)
    if not count or count <= 0 then return false end

    if not Bridge.RemoveItem(source, itemName, count) then return false end

    local total = count * itemConfig.price
    if not Bridge.AddMoney(source, total, 'Venta de piezas de desguace') then
        Bridge.AddItem(source, itemName, count) -- give the parts back if the payment failed
        return false
    end

    if Config.Logs and Config.Logs.EnablePay then
        local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n**Venta:** %s x%d\n**Total:** $%d")
            :format(Bridge.GetName(source), source, tostring(Bridge.GetIdentifier(source)), itemName, count, total)
        ServerUtils.SendDiscordLog("Desguace - Venta Item", desc, Config.Discord.Color.pay)
    end

    return true, count, total
end)

-- Cleanup -------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    LastPartRemoval[source] = nil
    LastWarn[source] = nil

    for cid, job in pairs(Jobs) do
        if job.owner == source then
            -- Abandoned job: free the scrap point and remove the vehicle (cooldown is kept)
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
