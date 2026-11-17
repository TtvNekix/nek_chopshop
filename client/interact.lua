ClientInteract = {}

-- Current job as seen by this client: { netId, plate, vehicle, owner, parts = { [bone] = { removed } } }
-- The server owns the real state; this is only a mirror for targets and UI.
local ActiveJob = nil

local PART_DEFS = {}
for _, def in ipairs(Config.ChopParts or {}) do PART_DEFS[def.bone] = def end

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
                    Editable.Client.Notify({ description = _L('need_lockpick'), type = 'error' })
                    return
                end

                if Editable.Client.MiniGame() then
                    Editable.Client.DispatchAlert(vehicleEntity)
                    NetworkRequestControlOfEntity(vehicleEntity)
                    SetVehicleDoorsLocked(vehicleEntity, 1)
                    SetVehicleDoorsLockedForAllPlayers(vehicleEntity, false)
                    SetVehicleNeedsToBeHotwired(vehicleEntity, false)

                    Editable.Client.Notify({ description = _L('vehicle_unlocked'), type = 'success' })

                    while not IsPedInVehicle(PlayerPedId(), vehicleEntity, true) do
                        if not DoesEntityExist(vehicleEntity) then return end
                        Wait(250)
                    end

                    if DoesBlipExist(pickupBlip) then RemoveBlip(pickupBlip) end

                    Editable.Client.Notify({ description = _L('goto_scrapyard'), type = 'success' })
                    exports.ox_target:removeLocalEntity(vehicleEntity, { 'lockpick_chop_vehicle' })

                    -- Listen for arrival
                    ClientInteract.WaitForArrival(vehicleEntity, dropoffBlip, scrapLocation)
                else
                    Editable.Client.Notify({ description = _L('failed_lockpick'), type = 'error' })
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
                Editable.Client.Notify({
                    type = ok and 'success' or 'error',
                    description = _L(ok and 'partner_invited' or 'error_assigning')
                })
            end
        }
    end

    lib.registerContext({ id = 'share_with', title = _L('select_partner'), options = options })
    lib.showContext('share_with')
end

function ClientInteract.BeforeScrap(vehicleEntity, dropoffBlip)
    Editable.Client.Notify({ description = _L('parked_scrap'), type = 'success' })

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
        }
    })
end

local function playRemoveAnim(vehicleEntity, def)
    local ped = PlayerPedId()
    if def.bone == 'bonnet' then
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
function ClientInteract.StartVehicleScrap(vehicleEntity, owner, knownPlate)
    local parts, plate

    if owner then
        -- Report which configured bones this model has; the server filters them again
        local bones = {}
        for bone in pairs(PART_DEFS) do
            if GetEntityBoneIndexByName(vehicleEntity, bone) ~= -1 then bones[#bones + 1] = bone end
        end
        parts, plate = lib.callback.await('chopshop:server:startScrap', false, bones)
    else
        parts, plate = lib.callback.await('chopshop:server:getParts', false, knownPlate)
    end

    if not parts then
        -- Keep the start target so the owner can retry (e.g. after re-parking the vehicle)
        Editable.Client.Notify({ type = 'error', description = _L('scrap_rejected') })
        return false
    end

    exports.ox_target:removeLocalEntity(vehicleEntity, { 'start_scrap' })

    ActiveJob = {
        netId = NetworkGetNetworkIdFromEntity(vehicleEntity),
        plate = plate,
        vehicle = vehicleEntity,
        owner = owner,
        parts = parts,
        blips = ActiveJob and ActiveJob.blips,
        point = ActiveJob and ActiveJob.point,
    }

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
                        and not ActiveJob.parts[bone].removed
                end,
                onSelect = function()
                    local canAddItem = lib.callback.await('chopshop:server:canAddItem', false, def.item, 1)
                    if not canAddItem then
                        Editable.Client.Notify({ type = 'error', description = _L('no_space') })
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
                        Editable.Client.Notify({ type = 'success', description = _L('disassembled') })
                    elseif reason == 'no_space' then
                        Editable.Client.Notify({ type = 'error', description = _L('no_space') })
                    end
                end
            })
        end
    end

    if owner then
        params[#params + 1] = {
            name = 'invite_chop_partner',
            icon = 'fas fa-user-plus',
            label = _L('invite_partner'),
            distance = 2.0,
            canInteract = function()
                return ActiveJob ~= nil and ActiveJob.owner == true
            end,
            onSelect = function() openPartnerMenu(vehicleEntity) end,
        }
    end

    exports.ox_target:addLocalEntity(vehicleEntity, params)
    return true
end

function ClientInteract.MarkPartRemoved(netId, bone)
    if ActiveJob and ActiveJob.netId == netId and ActiveJob.parts and ActiveJob.parts[bone] then
        ActiveJob.parts[bone].removed = true
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

    if vehicle and DoesEntityExist(vehicle) then
        exports.ox_target:removeLocalEntity(vehicle)
        if reason == 'finished' then NetworkFadeOutEntity(vehicle, true, false) end
    end

    if reason == 'finished' then
        if isOwner then Editable.Client.Notify({ type = 'success', description = _L('finished') }) end
    else
        Editable.Client.Notify({ type = 'error', description = _L('job_expired') })
    end
end

-- Another player invited us to help scrap their vehicle.
function ClientInteract.OnPartnerInvite(data)
    if ActiveJob then
        lib.callback.await('chopshop:server:answerInvite', false, data.plate, false)
        return
    end

    local answer = lib.alertDialog({
        header = _L('partner_invite_title'),
        content = _L('partner_invite_desc', data.from or '?'),
        centered = true,
        cancel = true,
    })

    local ok = lib.callback.await('chopshop:server:answerInvite', false, data.plate, answer == 'confirm')
    if not ok then return end

    local vehicleEntity = NetworkGetEntityFromNetworkId(data.vehicle)
    if not vehicleEntity or vehicleEntity == 0 or not DoesEntityExist(vehicleEntity) then return end

    ClientInteract.StartVehicleScrap(vehicleEntity, false, data.plate)
end

function ClientInteract.HasActiveJob()
    return ActiveJob ~= nil
end
