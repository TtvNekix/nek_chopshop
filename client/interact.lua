ClientInteract = {}

-- Current job as seen by this client: { netId, plate, vehicle, owner, parts = { [bone] = { removed } } }
-- The server owns the real state; this is only a mirror for targets and UI.
local ActiveJob = nil

local PART_DEFS = {}
for _, def in ipairs(Config.ChopParts or {}) do PART_DEFS[def.bone] = def end

-- NUI job tracker ---------------------------------------------------------------
-- Everything here is a no-op when Config.UseNUI is false. Server deadlines are epoch seconds,
-- the NUI expects epoch milliseconds.

local trackerGen = 0 -- bumped on every tracker open/update so a pending auto-close can tell it is stale

-- Player feedback ---------------------------------------------------------------
-- ClientInteract.Feedback is the single entry point for in-job messages:
--   NUI on, tracker open   -> a handwritten line in the tracker's notes (newest last, LOG_SIZE kept)
--   NUI on, tracker closed -> a loose note on the right edge, closed by Lua after NOTE_MS
--   NUI off or page not ready -> Editable.Client.Notify, as before

local LOG_SIZE = 5
local NOTE_MS = 5000
local INVITE_MS = 30000

local trackerLog = {} -- entries { id, at = epoch ms, tone, text }, replaced (never mutated) on every change
local logSeq = 0
local noteGen = 0 -- bumped on every note so a pending auto-close can tell it is stale

local function appendLog(tone, text)
    logSeq = logSeq + 1
    local entries = {}
    for i = math.max(1, #trackerLog - LOG_SIZE + 2), #trackerLog do
        entries[#entries + 1] = trackerLog[i]
    end
    entries[#entries + 1] = { id = logSeq, at = GetCloudTimeAsInt() * 1000, tone = tone, text = text }
    trackerLog = entries
    Nui.update('job-tracker', { log = trackerLog })
end

local function showNote(tone, text)
    noteGen = noteGen + 1
    local gen = noteGen
    Nui.open('note', { tone = tone, text = text })
    SetTimeout(NOTE_MS, function()
        if gen == noteGen then Nui.close('note') end
    end)
end

---Shows an in-job message to this player.
---@param kind 'success' | 'inform' | 'error'
---@param key string locale key, formatted with the extra arguments
function ClientInteract.Feedback(kind, key, ...)
    local text = _L(key, ...)
    if Config.UseNUI and Nui.isReady() then
        if Nui.isOpen('job-tracker') then
            appendLog(kind, text)
        else
            showNote(kind, text)
        end
        return
    end
    Editable.Client.Notify({ type = kind, description = text })
end

local function vehicleLabel(modelHash, fallback)
    local label = modelHash and GetLabelText(GetDisplayNameFromVehicleModel(modelHash)) or nil
    if not label or label == 'NULL' then return fallback or '' end
    return label
end

-- Parts in Config.ChopParts order, shaped as the tracker expects.
local function partsList(parts)
    local list = {}
    for _, def in ipairs(Config.ChopParts or {}) do
        local state = parts[def.bone]
        if state then
            list[#list + 1] = { id = def.bone, label = _L(def.label), removed = state.removed == true }
        end
    end
    return list
end

-- data: { model, plate, expiresAt } as returned by requestJob
function ClientInteract.TrackerStart(data)
    if not Config.UseNUI then return end
    trackerGen = trackerGen + 1
    trackerLog = {}
    Nui.open('job-tracker', {
        vehicle = {
            label = vehicleLabel(data.model and joaat(data.model), data.model),
            plate = data.plate or '',
        },
        stage = 'pickup',
        status = 'active',
        expiresAt = data.expiresAt and data.expiresAt * 1000 or nil,
    })
end

function ClientInteract.TrackerStage(stage)
    if not Config.UseNUI or not Nui.isOpen('job-tracker') then return end
    trackerGen = trackerGen + 1
    Nui.update('job-tracker', { stage = stage })
end

-- Scrapping started for this client (owner, or partner who accepted an invite).
function ClientInteract.TrackerScrap(vehicleEntity, plate, parts, expiresAt, partnerName)
    if not Config.UseNUI then return end
    trackerGen = trackerGen + 1
    local payload = {
        vehicle = {
            label = vehicleLabel(GetEntityModel(vehicleEntity)),
            plate = plate or '',
        },
        stage = 'scrap',
        status = 'active',
        parts = partsList(parts),
        expiresAt = expiresAt and expiresAt * 1000 or nil,
        partner = partnerName,
    }
    if Nui.isOpen('job-tracker') then
        Nui.update('job-tracker', payload)
    else
        trackerLog = {}
        Nui.open('job-tracker', payload)
    end
end

-- reason: 'finished' | 'expired' | 'vehicle_lost' | 'cancelled'
function ClientInteract.TrackerFinish(reason)
    if not Config.UseNUI or not Nui.isOpen('job-tracker') then return end
    local status = 'expired'
    if reason == 'finished' then
        status = 'completed'
    elseif reason == 'cancelled' then
        status = 'cancelled'
    end

    trackerGen = trackerGen + 1
    local gen = trackerGen
    Nui.update('job-tracker', { status = status })
    SetTimeout(4000, function()
        if gen == trackerGen then Nui.close('job-tracker') end
    end)
end

function ClientInteract.GanzuarVehiculo()
    local success = lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'e' })
    return success
end

-- Called right after the server accepted the job.
function ClientInteract.BeginJob(netId, blips, point)
    ActiveJob = { netId = netId, owner = true, blips = blips, point = point }
end

function ClientInteract.SetupVehicleLockpick(vehicleEntity, pickupBlip, dropoffBlip, scrapLocation)
    if ActiveJob then ActiveJob.vehicle = vehicleEntity end

    exports.ox_target:addLocalEntity(vehicleEntity, {
        {
            name = 'lockpick_chop_vehicle',
            icon = "fa-solid fa-key",
            label = _L('lockpick_vehicle'),
            distance = 2.0,
            onSelect = function()
                if not Bridge.HasLockpick() then
                    ClientInteract.Feedback('error', 'need_lockpick')
                    return
                end

                if Editable.Client.MiniGame() then
                    -- Server-validated: vehicle keys for the owner (key scripts) and the police alert
                    ClientDispatch.VehicleLockpicked(vehicleEntity)
                    NetworkRequestControlOfEntity(vehicleEntity)
                    SetVehicleDoorsLocked(vehicleEntity, 1)
                    SetVehicleDoorsLockedForAllPlayers(vehicleEntity, false)
                    SetVehicleNeedsToBeHotwired(vehicleEntity, false)

                    ClientInteract.Feedback('success', 'vehicle_unlocked')

                    while not IsPedInVehicle(PlayerPedId(), vehicleEntity, true) do
                        if not DoesEntityExist(vehicleEntity) then return end
                        Wait(250)
                    end

                    if DoesBlipExist(pickupBlip) then RemoveBlip(pickupBlip) end

                    ClientInteract.TrackerStage('deliver')
                    ClientInteract.Feedback('success', 'goto_scrapyard')
                    exports.ox_target:removeLocalEntity(vehicleEntity, { 'lockpick_chop_vehicle' })

                    -- Listen for arrival
                    ClientInteract.WaitForArrival(vehicleEntity, dropoffBlip, scrapLocation)
                else
                    ClientInteract.Feedback('error', 'failed_lockpick')
                end
            end
        }
    })
end

function ClientInteract.WaitForArrival(vehicleEntity, dropoffBlip, scrapLocation)
    CreateThread(function()
        while DoesEntityExist(vehicleEntity) do
            Wait(500)
            local scrapPos = vec3(scrapLocation.coords.x, scrapLocation.coords.y, scrapLocation.coords.z)
            local dist = #(GetEntityCoords(vehicleEntity) - scrapPos)

            if dist < 5.0 then
                TaskLeaveAnyVehicle(PlayerPedId(), 0, 0)
                Wait(1500)
                SetVehicleDoorsLocked(vehicleEntity, 2)
                FreezeEntityPosition(vehicleEntity, true)
                ClientInteract.BeforeScrap(vehicleEntity, dropoffBlip)
                break
            end
        end
    end)
end

local function openPartnerMenu(vehicleEntity)
    local options = {}
    for _, p in pairs(lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), 20.0, false)) do
        local serverId = GetPlayerServerId(p.id)
        options[#options + 1] = {
            title = Bridge.GetName(p.id) .. ' [' .. serverId .. ']',
            onSelect = function()
                local ok = lib.callback.await('chopshop:server:sendVehicleToScrap', false,
                    ActiveJob and ActiveJob.plate, serverId)
                ClientInteract.Feedback(ok and 'success' or 'error', ok and 'partner_invited' or 'error_assigning')
            end
        }
    end

    lib.registerContext({ id = 'share_with', title = _L('select_partner'), options = options })
    lib.showContext('share_with')
end

function ClientInteract.BeforeScrap(vehicleEntity, dropoffBlip)
    ClientInteract.Feedback('success', 'parked_scrap')

    exports.ox_target:removeLocalEntity(vehicleEntity)

    exports.ox_target:addLocalEntity(vehicleEntity, {
        {
            name = 'start_scrap',
            icon = "fa-solid fa-skull",
            label = _L('start_scrap'),
            distance = 2.0,
            onSelect = function()
                if ActiveJob and ActiveJob.parts then return end -- already started
                FreezeEntityPosition(vehicleEntity, false)
                if ClientInteract.StartVehicleScrap(vehicleEntity, true) then
                    if DoesBlipExist(dropoffBlip) then RemoveBlip(dropoffBlip) end
                end
            end
        },
        {
            -- The partner is chosen before the scrap starts; once it starts the option is removed
            name = 'invite_chop_partner',
            icon = 'fas fa-user-plus',
            label = _L('invite_partner'),
            distance = 2.0,
            canInteract = function()
                return ActiveJob ~= nil and ActiveJob.owner == true and ActiveJob.parts == nil
            end,
            onSelect = function() openPartnerMenu(vehicleEntity) end,
        }
    })
end

-- True when the part has no pending requirement (mirror of the server check, only used to hide targets).
local function requirementMet(def)
    local required = def.requires and ActiveJob and ActiveJob.parts and ActiveJob.parts[def.requires]
    return not required or required.removed == true
end

local function playRemoveAnim(vehicleEntity, def)
    local ped = PlayerPedId()
    if def.anim == 'repair' then
        lib.playAnim(ped, 'mini@repair', 'fixing_a_ped', 8.0, 8.0, -1, 1, 0, false, false, false)
        return
    end

    local vehiclePos = GetEntityCoords(vehicleEntity)
    TaskTurnPedToFaceCoord(ped, vehiclePos.x, vehiclePos.y, GetEntityCoords(ped).z, 0)
    Wait(1000)
    SetEntityHeading(ped, (GetEntityHeading(ped) + 180.0) % 360.0)
    lib.playAnim(ped, 'amb@world_human_vehicle_mechanic@male@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
end

-- Returns true when scrapping started for this client.
-- `knownPlate` is the server plate (partners receive it with the invite).
function ClientInteract.StartVehicleScrap(vehicleEntity, owner, knownPlate, partnerName)
    local parts, plate, expiresAt

    if owner then
        -- Report which configured bones this model has; the server filters them again
        local bones = {}
        for bone in pairs(PART_DEFS) do
            if GetEntityBoneIndexByName(vehicleEntity, bone) ~= -1 then bones[#bones + 1] = bone end
        end
        parts, plate, expiresAt = lib.callback.await('chopshop:server:startScrap', false, bones)
    else
        parts, plate, expiresAt = lib.callback.await('chopshop:server:getParts', false, knownPlate)
    end

    if not parts then
        -- Keep the start target so the owner can retry (e.g. after re-parking the vehicle).
        -- On rejection startScrap returns false, reasonCode, extra (in the plate/expiresAt slots).
        local reason, extra = plate, expiresAt
        if reason == 'too_fast' then
            ClientInteract.Feedback('error', 'scrap_too_fast', tonumber(extra) or 0)
        elseif reason == 'no_lockpick' then
            ClientInteract.Feedback('error', 'need_lockpick')
        else
            ClientInteract.Feedback('error', 'scrap_rejected')
        end
        return false
    end

    exports.ox_target:removeLocalEntity(vehicleEntity, { 'start_scrap', 'invite_chop_partner' })

    ActiveJob = {
        netId = NetworkGetNetworkIdFromEntity(vehicleEntity),
        plate = plate,
        vehicle = vehicleEntity,
        owner = owner,
        parts = parts,
        blips = ActiveJob and ActiveJob.blips,
        point = ActiveJob and ActiveJob.point,
    }

    ClientInteract.TrackerScrap(vehicleEntity, plate, parts, expiresAt, partnerName)

    local params = {}
    for bone in pairs(parts) do
        local def = PART_DEFS[bone]
        if def then
            local text = _L(def.label)
            table.insert(params, {
                name = 'scrap_' .. bone,
                icon = 'fas fa-tools',
                label = _L('remove_part', text),
                bones = { bone },
                distance = 1.5,
                canInteract = function()
                    return ActiveJob ~= nil and ActiveJob.parts ~= nil and ActiveJob.parts[bone] ~= nil
                        and not ActiveJob.parts[bone].removed and requirementMet(def)
                end,
                onSelect = function()
                    local canAddItem = lib.callback.await('chopshop:server:canAddItem', false, def.item, 1)
                    if not canAddItem then
                        ClientInteract.Feedback('error', 'no_space')
                        return
                    end

                    playRemoveAnim(vehicleEntity, def)

                    local completed = lib.progressCircle({
                        duration = 2500,
                        label = _L('disassembling', text),
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true }
                    })
                    ClearPedTasks(PlayerPedId())
                    if not completed then return end

                    local ok, reason = lib.callback.await('chopshop:server:removePart', false, plate, bone)
                    if ok then
                        -- No notification on success: the part breaking off is the feedback
                    elseif reason == 'no_space' then
                        ClientInteract.Feedback('error', 'no_space')
                    elseif reason == 'requires' then
                        ClientInteract.Feedback('error', 'part_requires')
                    end
                end
            })
        end
    end

    exports.ox_target:addLocalEntity(vehicleEntity, params)
    return true
end

function ClientInteract.MarkPartRemoved(netId, bone)
    if ActiveJob and ActiveJob.netId == netId and ActiveJob.parts and ActiveJob.parts[bone] then
        ActiveJob.parts[bone].removed = true
        if Config.UseNUI and Nui.isOpen('job-tracker') then
            Nui.update('job-tracker', { parts = partsList(ActiveJob.parts) })
        end
    end
end

-- reason: 'finished' | 'expired' | 'vehicle_lost' | 'cancelled'
function ClientInteract.OnJobFinished(netId, isOwner, reason)
    if not ActiveJob or ActiveJob.netId ~= netId then return end

    local vehicle = ActiveJob.vehicle
    for _, blip in ipairs(ActiveJob.blips or {}) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    if ActiveJob.point then ActiveJob.point:remove() end
    ActiveJob = nil
    ClientInteract.TrackerFinish(reason)

    if vehicle and DoesEntityExist(vehicle) then
        exports.ox_target:removeLocalEntity(vehicle)
        if reason == 'finished' then NetworkFadeOutEntity(vehicle, true, false) end
    end

    if reason == 'finished' then
        if isOwner then ClientInteract.Feedback('success', 'finished') end
    else
        ClientInteract.Feedback('error', 'job_expired')
    end
end

-- Settles the invite sheet that is waiting for an answer (nil when none is open).
local settleInvite = nil

-- Shows the invite as a NUI sheet and yields until it is answered. Escape, a Lua close or
-- INVITE_MS without an answer count as a decline. Returns nil when the sheet cannot be shown.
local function askInviteNui(data)
    if not Config.UseNUI or not Nui.waitReady(2000) then return nil end
    if settleInvite then settleInvite(false) end -- never leave an older invite hanging

    local answer = promise.new()
    local settled = false
    local function settle(accepted)
        if settled then return end
        settled = true
        if settleInvite == settle then settleInvite = nil end
        answer:resolve(accepted == true)
    end

    local opened = Nui.open('partner-invite', {
        from = data.from,
        text = _L('partner_invite_desc', data.from or '?'),
        ticketNo = data.plate,
    }, { onClose = function() settle(false) end })
    if not opened then return nil end

    settleInvite = settle
    SetTimeout(INVITE_MS, function()
        if not settled then Nui.close('partner-invite', 'timeout') end
    end)
    return Citizen.Await(answer)
end

Nui.on('answerInvite', function(data)
    local settle = settleInvite
    if not settle or not Nui.isOpen('partner-invite') then return false, 'expired' end
    settle(data.accept == true)
    Nui.close('partner-invite')
    return true
end)

-- Another player invited us to help scrap their vehicle.
function ClientInteract.OnPartnerInvite(data)
    if ActiveJob then
        lib.callback.await('chopshop:server:answerInvite', false, data.plate, false)
        return
    end

    local accepted = askInviteNui(data)
    if accepted == nil then
        accepted = lib.alertDialog({
            header = _L('partner_invite_title'),
            content = _L('partner_invite_desc', data.from or '?'),
            centered = true,
            cancel = true,
        }) == 'confirm'
    end

    local ok = lib.callback.await('chopshop:server:answerInvite', false, data.plate, accepted)
    if not ok then return end

    -- Joined before the scrap starts: wait for the owner (chopshop:client:scrapStarted)
    ActiveJob = { netId = data.vehicle, plate = data.plate, owner = false, waiting = true, from = data.from }
    ClientInteract.Feedback('inform', 'partner_waiting', data.from or '?')
end

-- The owner started the scrap of the job we joined as a partner.
function ClientInteract.OnScrapStarted(netId)
    if not ActiveJob or not ActiveJob.waiting or ActiveJob.netId ~= netId then return end

    local vehicleEntity = NetworkGetEntityFromNetworkId(netId)
    if not vehicleEntity or vehicleEntity == 0 or not DoesEntityExist(vehicleEntity) then return end

    ClientInteract.StartVehicleScrap(vehicleEntity, false, ActiveJob.plate, ActiveJob.from)
end

function ClientInteract.HasActiveJob()
    return ActiveJob ~= nil
end
