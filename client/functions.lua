ClientUtils = {}

function _L(key, ...)
    local str = Config.Locales[key]
    if not str then return key end
    if ... then return string.format(str, ...) end
    return str
end

-- Returns true when the player is on cooldown (and notifies them).
-- Purely cosmetic: the server enforces the cooldown again in requestJob.
function ClientUtils.IsOnCooldown()
    local cooldown = lib.callback.await('chopshop:server:getCooldown', false)
    if cooldown and cooldown > 0 then
        Editable.Client.Notify({
            title = 'Chop Shop',
            description = _L('cooldown_msg', math.ceil(cooldown / 60)),
            type = 'error'
        })
        return true
    end
    return false
end

function ClientUtils.SetBlips(data, vehicleSpawnedNWID)
    -- Pickup Blip
    local pickupBlip = AddBlipForCoord(data.spawnPoint.x, data.spawnPoint.y, data.spawnPoint.z)
    SetBlipSprite(pickupBlip, 225)
    SetBlipColour(pickupBlip, 5)
    SetBlipScale(pickupBlip, 0.8)
    SetBlipAsShortRange(pickupBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(_L('pickup_point'))
    EndTextCommandSetBlipName(pickupBlip)

    -- Dropoff Blip
    local dropoffBlip = AddBlipForCoord(data.scrapLocation.coords.x, data.scrapLocation.coords.y,
        data.scrapLocation.coords.z)
    SetBlipSprite(dropoffBlip, 521)
    SetBlipColour(dropoffBlip, 1)
    SetBlipScale(dropoffBlip, 0.8)
    SetBlipAsShortRange(dropoffBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(_L('scrap_point', data.scrapLocation.name))
    EndTextCommandSetBlipName(dropoffBlip)

    Editable.Client.Notify({ description = _L('job_started'), type = 'success' })

    local vehicleEntity = nil
    local vehiclePoint = lib.points.new({
        coords = vec3(data.spawnPoint.x, data.spawnPoint.y, data.spawnPoint.z),
        distance = 30.0
    })

    -- Track the job from the start so a server cancellation can clean blips and the point
    ClientInteract.BeginJob(vehicleSpawnedNWID, { pickupBlip, dropoffBlip }, vehiclePoint)

    function vehiclePoint:onEnter()
        SetNetworkIdExistsOnAllMachines(vehicleSpawnedNWID, true)
        SetNetworkIdCanMigrate(vehicleSpawnedNWID, true)

        local timeout = 0
        repeat
            vehicleEntity = NetworkGetEntityFromNetworkId(vehicleSpawnedNWID)
            Wait(100)
            timeout = timeout + 1
        until (DoesEntityExist(vehicleEntity)) or timeout >= 50

        if not DoesEntityExist(vehicleEntity) then
            return
        end

        vehiclePoint:remove()
        SetVehicleFuelLevel(vehicleEntity, 100.0)
        SetVehicleDoorsLocked(vehicleEntity, 2)

        -- Marker loop
        CreateThread(function()
            while DoesEntityExist(vehicleEntity) do
                local far = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicleEntity)) > 3.0
                if not far then break end
                local coords = GetEntityCoords(vehicleEntity)
                DrawMarker(2, coords.x, coords.y, coords.z + 2.0,
                    0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                    1.0, 1.0, 1.0, 0, 255, 0, 100,
                    true, true, 2, false, false, false, false, false, false, false)
                Wait(0)
            end
        end)

        -- Start Interaction logic for vehicle
        ClientInteract.SetupVehicleLockpick(vehicleEntity, pickupBlip, dropoffBlip, data.scrapLocation)
    end
end
