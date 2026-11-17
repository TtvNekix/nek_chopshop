local PED = {}
local SELL_PED = {}

-- Inicialización
CreateThread(function()
    while not Bridge.GetIdentifier() do Wait(10) end

    TriggerServerEvent('chopshop:server:playerReady')

    if Config.Ped then
        if Config.Ped.Blip and Config.Ped.Blip.Enable then
            local blip = AddBlipForCoord(Config.Ped.Coords.x, Config.Ped.Coords.y, Config.Ped.Coords.z)
            SetBlipSprite(blip, Config.Ped.Blip.Sprite)
            SetBlipColour(blip, Config.Ped.Blip.Color)
            SetBlipScale(blip, Config.Ped.Blip.Scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Ped.Blip.Label)
            EndTextCommandSetBlipName(blip)
        end
        local pedPoint = lib.points.new({
            coords = vec3(Config.Ped.Coords.x, Config.Ped.Coords.y, Config.Ped.Coords.z),
            distance = 15
        })

        function pedPoint:onEnter()
            ObtainPedProperties()
            pedPoint:remove()
        end
    end

    if Config.SellPed and Config.SellPed.Enable then
        if Config.SellPed.Blip and Config.SellPed.Blip.Enable then
            local blip = AddBlipForCoord(Config.SellPed.Coords.x, Config.SellPed.Coords.y, Config.SellPed.Coords.z)
            SetBlipSprite(blip, Config.SellPed.Blip.Sprite)
            SetBlipColour(blip, Config.SellPed.Blip.Color)
            SetBlipScale(blip, Config.SellPed.Blip.Scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(_L('blip_sell'))
            EndTextCommandSetBlipName(blip)
        end
        local sellPedPoint = lib.points.new({
            coords = vec3(Config.SellPed.Coords.x, Config.SellPed.Coords.y, Config.SellPed.Coords.z),
            distance = 15
        })

        function sellPedPoint:onEnter()
            ObtainSellPedProperties()
            sellPedPoint:remove()
        end
    end
end)


function ObtainPedProperties(data)
    local pedData = data or lib.callback.await('chopshop:server:addPedProperties', false)
    if not pedData then return end
    PED = pedData

    local pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)

    local tries = 0
    while not DoesEntityExist(pedEntity) and tries < 20 do
        pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)
        Wait(100)
        tries = tries + 1
    end

    if DoesEntityExist(pedEntity) then
        FreezeEntityPosition(pedEntity, true)
        SetEntityInvincible(pedEntity, true)
        SetBlockingOfNonTemporaryEvents(pedEntity, true)

        if pedData.scenario then
            TaskStartScenarioInPlace(pedEntity, pedData.scenario, 0, true)
        end

        exports.ox_target:removeLocalEntity(pedEntity, 'request_chop_job')
        exports.ox_target:addLocalEntity(pedEntity, {
            {
                name = 'request_chop_job',
                icon = Config.Ped.Target.options[1].icon,
                label = _L('request_job'),
                distance = 2.0,
                onSelect = function()
                    if ClientUtils.IsOnCooldown() then return end

                    local status, netId, scrapLocation, spawnPoint = lib.callback.await('chopshop:server:requestJob',
                        false)

                    if status == 'success' then
                        ClientUtils.SetBlips({ spawnPoint = spawnPoint, scrapLocation = scrapLocation }, netId)
                    elseif status == 'already_working' then
                        Editable.Client.Notify({ type = 'error', description = _L('already_working') })
                    elseif status == 'cooldown' then
                        Editable.Client.Notify({ type = 'error', description = _L('cooldown_msg', 0) })
                    elseif status == 'no_scrap' then
                        Editable.Client.Notify({ type = 'error', description = _L('no_scrap_available') })
                    else
                        Editable.Client.Notify({ type = 'error', description = _L('error_starting') })
                    end
                end
            }
        })
    end
end

function ObtainSellPedProperties(data)
    local pedData = data or lib.callback.await('chopshop:server:getSellPed', false)
    if not pedData then return end
    SELL_PED = pedData

    local pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)

    local tries = 0
    while not DoesEntityExist(pedEntity) and tries < 20 do
        pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)
        Wait(100)
        tries = tries + 1
    end

    if DoesEntityExist(pedEntity) then
        FreezeEntityPosition(pedEntity, true)
        SetEntityInvincible(pedEntity, true)
        SetBlockingOfNonTemporaryEvents(pedEntity, true)

        if pedData.scenario then
            TaskStartScenarioInPlace(pedEntity, pedData.scenario, 0, true)
        end

        exports.ox_target:removeLocalEntity(pedEntity, 'sell_chop_items')
        exports.ox_target:addLocalEntity(pedEntity, {
            {
                name = 'sell_chop_items',
                icon = 'fas fa-dollar-sign',
                label = _L('sell_parts'),
                distance = 2.0,
                onSelect = function()
                    local options = {}
                    for _, itemData in ipairs(Config.SellPed.Items) do
                        table.insert(options, {
                            title = itemData.label .. " - $" .. itemData.price,
                            description = _L('sell_item_desc', itemData.label),
                            icon = 'dollar',
                            onSelect = function()
                                local success, count, total = lib.callback.await('chopshop:server:sellItem', false,
                                    itemData.item)
                                if success then
                                    Editable.Client.Notify({
                                        type = 'success',
                                        description = _L('sold_item', count, itemData.label, total)
                                    })
                                else
                                    Editable.Client.Notify({ type = 'error', description = _L('no_item') })
                                end
                            end
                        })
                    end
                    lib.registerContext({
                        id = 'sell_chop_menu',
                        title = _L('sell_menu_title'),
                        options = options
                    })
                    lib.showContext('sell_chop_menu')
                end
            }
        })
    end
end

RegisterNetEvent('chopshop:client:setupPed', function(data)
    CreateThread(function()
        ObtainPedProperties(data)
    end)
end)

RegisterNetEvent('chopshop:client:setupSellPed', function(data)
    CreateThread(function()
        ObtainSellPedProperties(data)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if PED['nwid'] then
            local entity = NetworkGetEntityFromNetworkId(PED['nwid'])
            if DoesEntityExist(entity) then
                exports.ox_target:removeLocalEntity(entity)
            end
        end
        if SELL_PED['nwid'] then
            local entity = NetworkGetEntityFromNetworkId(SELL_PED['nwid'])
            if DoesEntityExist(entity) then
                exports.ox_target:removeLocalEntity(entity)
            end
        end
    end
end)

RegisterNetEvent('chopshop:client:brokePart', function(netid, part)
    local vehicleEntity = NetworkGetEntityFromNetworkId(netid)
    local timeout = 0
    while not DoesEntityExist(vehicleEntity) and timeout < 10 do
        vehicleEntity = NetworkGetEntityFromNetworkId(netid)
        Wait(100)
        timeout = timeout + 1
    end

    if not DoesEntityExist(vehicleEntity) then return end

    if part.isDoor then
        SetVehicleDoorBroken(vehicleEntity, part.part, true)
    elseif part.isWheel then
        BreakOffVehicleWheel(vehicleEntity, part.part, true, false, true, false)
    end

    ClientInteract.MarkPartRemoved(netid, part.bone)
end)

RegisterNetEvent('chopshop:client:partnerInvite', function(data)
    ClientInteract.OnPartnerInvite(data)
end)

RegisterNetEvent('chopshop:client:jobFinished', function(netId, isOwner, reason)
    ClientInteract.OnJobFinished(netId, isOwner, reason)
end)

RegisterNetEvent('chopshop:client:playerLoaded', function()
    -- Re-init logic if needed
end)

exports('GetJobStatus', function()
    return {
        active = ClientInteract.HasActiveJob(),
        pedCoords = Config.Ped.Coords
    }
end)
