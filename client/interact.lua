ClientInteract = {}

local quantity = 0
local CurrentPartner = nil

function ClientInteract.GanzuarVehiculo()
    local success = lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'e' })
    return success
end

function ClientInteract.SetupVehicleLockpick(vehicleEntity, pickupBlip, dropoffBlip, scrapLocation)
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
                lib.registerContext({
                    id = 'share_menu',
                    title = _L('share_menu_title'),
                    options = {
                        {
                            title = _L('init_scrap'),
                            description = _L('init_scrap_desc'),
                            icon = 'circle',
                            onSelect = function()
                                if DoesBlipExist(dropoffBlip) then RemoveBlip(dropoffBlip) end
                                FreezeEntityPosition(vehicleEntity, false)
                                ClientInteract.StartVehicleScrap(vehicleEntity, true)
                            end,
                        },
                        {
                            title = _L('designate_partner'),
                            description = _L('designate_partner_desc'),
                            icon = 'user',
                            onSelect = function()
                                local playersNear = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), 20.0, false)
                                local options = {}
                                for _, p in pairs(playersNear) do
                                    table.insert(options, {
                                        title = Bridge.GetName(p.id) .. ' [' .. GetPlayerServerId(p.id) .. ']',
                                        onSelect = function()
                                            lib.callback('chopshop:server:sendVehicleToScrap', false, function(ok)
                                                if ok then
                                                    CurrentPartner = GetPlayerServerId(p.id)
                                                    Editable.Client.Notify({ type = 'success', description = _L(
                                                    'partner_assigned') })
                                                    if DoesBlipExist(dropoffBlip) then RemoveBlip(dropoffBlip) end
                                                    FreezeEntityPosition(vehicleEntity, false)
                                                    ClientInteract.StartVehicleScrap(vehicleEntity, true)
                                                else
                                                    Editable.Client.Notify({ type = 'error', description = _L(
                                                    'error_assigning') })
                                                end
                                            end, GetVehicleNumberPlateText(vehicleEntity), GetPlayerServerId(p.id))
                                        end
                                    })
                                end
                                lib.registerContext({
                                    id = 'share_with',
                                    title = _L('select_partner'),
                                    options = options
                                })
                                lib.showContext('share_with')
                            end
                        }
                    }
                })
                lib.showContext('share_menu')
            end
        }
    })

    TriggerEvent('chopshop:client:syncFinish') -- Re-init ped target if needed
end

function ClientInteract.StartVehicleScrap(vehicleEntity, owner)
    exports.ox_target:removeLocalEntity(vehicleEntity, { 'start_scrap' })

    local chopParts = {
        { removed = false, part = 0, bone = 'door_dside_f', item = 'vehicle_door', text = _L('door_lf'),  isDoor = true },
        { removed = false, part = 2, bone = 'door_dside_r', item = 'vehicle_door', text = _L('door_lr'),  isDoor = true },
        { removed = false, part = 3, bone = 'door_pside_r', item = 'vehicle_door', text = _L('door_rr'),  isDoor = true },
        { removed = false, part = 1, bone = 'door_pside_f', item = 'vehicle_door', text = _L('door_rf'),  isDoor = true },
        { removed = false, part = 4, bone = 'bonnet',       item = 'vehicle_hood', text = _L('hood'),     isDoor = true },
        { removed = false, part = 0, bone = 'wheel_lf',     item = 'veh_wheels',   text = _L('wheel_lf'), isWheel = true },
        { removed = false, part = 2, bone = 'wheel_lr',     item = 'veh_wheels',   text = _L('wheel_lr'), isWheel = true },
        { removed = false, part = 3, bone = 'wheel_rr',     item = 'veh_wheels',   text = _L('wheel_rr'), isWheel = true },
        { removed = false, part = 1, bone = 'wheel_rf',     item = 'veh_wheels',   text = _L('wheel_rf'), isWheel = true },
    }

    local partsRemoved = {}

    local function syncParts()
        local serverParts = lib.callback.await('chopshop:server:updatePartsToRemove', false,
            GetVehicleNumberPlateText(vehicleEntity), partsRemoved)
        if serverParts then partsRemoved = serverParts end
    end

    for i = 1, #chopParts do
        local p = chopParts[i]
        if GetEntityBoneIndexByName(vehicleEntity, p.bone) ~= -1 then
            table.insert(partsRemoved, p)
        end
    end
    syncParts()

    local function isRemoved(bone)
        for _, p in ipairs(partsRemoved) do
            if p.bone == bone then return p.removed end
        end
        return true
    end

    local function getPart(bone)
        for _, p in ipairs(partsRemoved) do
            if p.bone == bone then return p end
        end
        return nil
    end

    local params = {}
    for _, p in ipairs(partsRemoved) do
        table.insert(params, {
            name = 'scrap_' .. p.bone,
            icon = 'fas fa-tools',
            label = _L('remove_part', p.text),
            bones = { p.bone },
            distance = 1.5,
            canInteract = function(entity, distance, coords, name, bone)
                return not isRemoved(p.bone)
            end,
            onSelect = function(data)
                local part = getPart(p.bone)
                if not part then return end

                local canAddItem = lib.callback.await('chopshop:server:canAddItem', false, part.item, 1)
                if not canAddItem then
                    Editable.Client.Notify({ type = 'error', description = _L('no_space') })
                    return
                end

                if part.item == 'vehicle_hood' then
                    lib.playAnim(PlayerPedId(), 'mini@repair', 'fixing_a_ped', 8.0, 8.0, -1, 1, 0, false, false, false)
                else
                    local ped = PlayerPedId()
                    local pos = GetEntityCoords(ped)
                    local vehiclePos = GetEntityCoords(vehicleEntity)
                    local lookAt = vec3(vehiclePos.x, vehiclePos.y, pos.z)
                    TaskTurnPedToFaceCoord(ped, lookAt.x, lookAt.y, lookAt.z, 0)
                    Wait(1000)
                    local currentHeading = GetEntityHeading(ped)
                    SetEntityHeading(ped, (currentHeading + 180.0) % 360.0)

                    lib.playAnim(ped, 'amb@world_human_vehicle_mechanic@male@base', 'base', 8.0, 8.0, -1, 1, 0,
                        false, false, false)
                end

                if lib.progressCircle({
                        duration = 2500,
                        label = _L('disassembling', part.text),
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true }
                    }) then
                    ClearPedTasks(PlayerPedId())
                    part.removed = true

                    TriggerServerEvent('chopshop:server:brokePart', NetworkGetNetworkIdFromEntity(vehicleEntity), part)

                    if part.item == 'vehicle_hood' then
                        lib.callback.await('chopshop:server:giveItem', false, 'car-battery')
                        lib.callback.await('chopshop:server:giveItem', false, part.item)
                    else
                        lib.callback.await('chopshop:server:giveItem', false, part.item)
                    end

                    Editable.Client.Notify({ type = 'success', description = _L('disassembled') })
                    syncParts()
                else
                    ClearPedTasks(PlayerPedId())
                end
            end
        })
    end

    exports.ox_target:addLocalEntity(vehicleEntity, params)

    CreateThread(function()
        local maxParts = #partsRemoved
        while quantity < maxParts and DoesEntityExist(vehicleEntity) do
            Wait(1000)
        end

        Wait(2000)
        Wait(2000)
        if owner and DoesEntityExist(vehicleEntity) then
            if CurrentPartner then
                TriggerServerEvent('chopshop:server:syncFinish', CurrentPartner)
                CurrentPartner = nil
            end
            lib.callback.await('chopshop:server:giveItem', false, 'veh_suspension')
            Editable.Client.Notify({ type = 'success', description = _L('finished') })
            lib.callback.await('chopshop:server:removeWorker', false, Bridge.GetIdentifier(),
                GetVehicleNumberPlateText(vehicleEntity))

            NetworkFadeOutEntity(vehicleEntity, true, false)
            Wait(2000)
            DeleteEntity(vehicleEntity)
        end
        TriggerEvent('chopshop:client:syncFinish')
        quantity = 0
    end)
end

function ClientInteract.IncreaseQuantity()
    quantity = quantity + 1
end
