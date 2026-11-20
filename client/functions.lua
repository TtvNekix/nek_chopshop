ClientUtils = {}

-- Thin wrapper over ox_lib's locale(). Unknown keys are returned as they are, so a
-- literal text from the config (e.g. a custom label) is shown unchanged.
function _L(key, ...)
    return locale(key, ...)
end

-- Returns true when the player is on cooldown (and notifies them).
-- Purely cosmetic: the server enforces the cooldown again in requestJob.
function ClientUtils.IsOnCooldown()
    local cooldown = lib.callback.await('chopshop:server:getCooldown', false)
    if cooldown and cooldown > 0 then
        ClientInteract.Feedback('error', 'cooldown_msg', math.ceil(cooldown / 60))
        return true
    end
    return false
end

-- Dictionary sent to the NUI: the `nui.*` keys of the active locale, with the prefix removed.
function ClientUtils.NuiLocale()
    local strings = {}
    for key, value in pairs(lib.getLocales()) do
        if key:sub(1, 4) == 'nui.' then strings[key:sub(5)] = value end
    end
    return { lang = ChopLocale.lang, currency = '$', strings = strings }
end

-- Asks the server for a job. On success it also sets up blips and the tracker.
-- Returns the server status string ('success', 'already_working', 'cooldown', 'no_police', 'no_scrap', 'error', ...)
-- and, on success, the plate.
function ClientUtils.RequestJob()
    local status, netId, scrapLocation, spawnPoint, expiresAt, plate, model, tier =
        lib.callback.await('chopshop:server:requestJob', false)

    if status == 'success' then
        ClientUtils.SetBlips({
            spawnPoint = spawnPoint,
            scrapLocation = scrapLocation,
            expiresAt = expiresAt,
            plate = plate,
            model = model,
            tier = tier,
        }, netId)
    end
    return status, plate
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

    local vehicleEntity = nil
    local vehiclePoint = lib.points.new({
        coords = vec3(data.spawnPoint.x, data.spawnPoint.y, data.spawnPoint.z),
        distance = 30.0
    })

    -- Track the job from the start so a server cancellation can clean blips and the point
    ClientInteract.BeginJob(vehicleSpawnedNWID, { pickupBlip, dropoffBlip }, vehiclePoint)
    ClientInteract.TrackerStart(data)

    -- data.tier is the tier label (locale key or literal text) chosen by the server.
    -- After TrackerStart, so with the NUI it is the first line of the slip's notes.
    if type(data.tier) == 'string' then
        ClientInteract.Feedback('success', 'job_started_tier', _L(data.tier))
    else
        ClientInteract.Feedback('success', 'job_started')
    end

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
