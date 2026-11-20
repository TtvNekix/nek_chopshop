-- Police dispatch, client side. The server validates the request, picks the dispatch
-- script (see server/dispatch.lua) and returns the alert data; this file runs the
-- adapters of the scripts that expect the alert from the thief's client.

ClientDispatch = {}

local DispatchCfg = (Config.Police and Config.Police.Dispatch) or {}

local function blip()
    return DispatchCfg.Blip or {}
end

-- Blip duration in minutes (most dispatch scripts use minutes)
local function blipMinutes()
    return math.max(1, math.ceil((blip().Time or 120) / 60))
end

-- ps-dispatch matches job.type or job.name, so send both the type and the names
local function psJobs(data)
    local jobs = {}
    if data.jobType then jobs[#jobs + 1] = data.jobType end
    for _, name in ipairs(data.jobs or {}) do jobs[#jobs + 1] = name end
    if #jobs == 0 then jobs[1] = 'police' end
    return jobs
end

-- data = { coords, plate, model, modelLabel, code, title, message, jobs, jobType, vehicle }
local ADAPTERS = {}

ADAPTERS['ps-dispatch'] = function(data)
    local b = blip()
    exports['ps-dispatch']:CustomAlert({
        coords = data.coords,
        message = data.message,
        codeName = DispatchCfg.CodeName or 'vehicletheft',
        code = data.code,
        icon = 'fas fa-car',
        priority = 2,
        plate = data.plate,
        jobs = psJobs(data),
        alert = {
            radius = 0,
            sprite = b.Sprite,
            color = b.Color,
            scale = b.Scale,
            length = blipMinutes(),
            sound = 'Lose_1st',
            sound2 = 'GTAO_FM_Events_Soundset',
            flash = false,
        },
    })
end

ADAPTERS['cd_dispatch'] = function(data)
    local b = blip()
    local info = exports['cd_dispatch']:GetPlayerInfo()
    TriggerServerEvent('cd_dispatch:AddNotification', {
        job_table = data.jobs,
        coords = data.coords,
        title = ('%s - %s'):format(data.code, data.title),
        message = data.message,
        flash = 0,
        unique_id = info and info.unique_id or tostring(math.random(0000000, 9999999)),
        sound = 1,
        blip = {
            sprite = b.Sprite,
            scale = b.Scale,
            colour = b.Color,
            flashes = false,
            text = data.title,
            time = blipMinutes(),
            radius = 0,
        },
    })
end

ADAPTERS['qs-dispatch'] = function(data)
    local b = blip()
    TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', {
        job = data.jobs,
        callLocation = data.coords,
        callCode = { code = data.code, snippet = data.title },
        message = data.message,
        flashes = false,
        image = nil,
        blip = {
            sprite = b.Sprite,
            scale = b.Scale,
            colour = b.Color,
            flashes = false,
            text = data.title,
            time = blipMinutes() * 60 * 1000,
        },
        otherData = { { text = data.plate, icon = 'fas fa-car' } },
    })
end

ADAPTERS['rcore_dispatch'] = function(data)
    local b = blip()
    TriggerServerEvent('rcore_dispatch:server:sendAlert', {
        code = data.code,
        default_priority = 'medium',
        coords = data.coords,
        job = data.jobs,
        text = data.message,
        type = 'car_robbery',
        blip_time = blipMinutes(),
        blip = {
            sprite = b.Sprite,
            colour = b.Color,
            scale = b.Scale,
            text = data.title,
            flashes = false,
            radius = 0,
        },
    })
end

ADAPTERS['tk_dispatch'] = function(data)
    local b = blip()
    exports.tk_dispatch:addCall({
        title = data.title,
        code = data.code,
        priority = 'Priority 2',
        jobs = data.jobs,
        coords = data.coords,
        message = data.message,
        showLocation = true,
        showGender = true,
        showVehicle = true,
        playSound = true,
        blip = {
            sprite = b.Sprite,
            scale = b.Scale,
            color = b.Color,
            flash = false,
            display = 4,
            shortRange = false,
            radius = 0,
        },
    })
end

-- Verified against origen_police/custom/client (SendAlert:police with coords/title/message/metadata).
-- `job` is omitted so origen_police uses its default police category.
ADAPTERS['origen_police'] = function(data)
    TriggerServerEvent('SendAlert:police', {
        coords = data.coords,
        title = data.title,
        message = data.message,
        metadata = { model = data.modelLabel, plate = data.plate },
    })
end

ADAPTERS['linden_outlawalert'] = function(data)
    TriggerServerEvent('wf-alerts:svNotify', {
        dispatchData = {
            displayCode = data.code,
            description = data.title,
            isImportant = 0,
            recipientList = data.jobs,
            length = 10000,
            infoM = 'fa-car',
            info = data.message,
        },
        caller = 'Anonymous',
        coords = data.coords,
    })
end

local function modelLabel(model)
    if not model then return '' end
    local label = GetLabelText(GetDisplayNameFromVehicleModel(joaat(model)))
    if not label or label == 'NULL' then return model end
    return label
end

-- Runs the client-side adapter (or the client custom hook) with the alert data built by the server.
local function runAlert(system, data, vehicleEntity)
    if type(system) ~= 'string' or type(data) ~= 'table' then return end

    data.vehicle = vehicleEntity
    data.modelLabel = modelLabel(data.model)
    data.message = _L(DispatchCfg.Message or 'dispatch_message', data.modelLabel, data.plate)

    if system == 'custom' then
        if Editable.Client.DispatchAlert then
            local ok, err = pcall(Editable.Client.DispatchAlert, data)
            if not ok then print(('^1[nek_chopshop] Editable.Client.DispatchAlert failed: %s^7'):format(err)) end
        end
        return
    end

    local adapter = ADAPTERS[system]
    if not adapter then return end
    local ok, err = pcall(adapter, data)
    if not ok then print(('^1[nek_chopshop] Dispatch (%s) failed: %s^7'):format(system, err)) end
end

---Reports the successful lockpick of the current job vehicle. The server validates it, gives the
---vehicle keys (Config.VehicleKeys, server/keys.lua) and returns the police alert to run, if any.
---Runs in its own thread so the lockpick flow is not delayed. The server allows one alert per job,
---and sends it by itself (chopshop:client:dispatchAlert) when this request never comes.
---@param vehicleEntity number job vehicle, passed to the custom hook as data.vehicle
function ClientDispatch.VehicleLockpicked(vehicleEntity)
    CreateThread(function()
        local system, data = lib.callback.await('chopshop:server:vehicleLockpicked', false)
        runAlert(system, data, vehicleEntity)
    end)
end

-- Alert started by the server (owner seen driving the job vehicle, or delivery). Location, plate
-- and model are the server's; this client only runs the adapter that needs the thief's client.
RegisterNetEvent('chopshop:client:dispatchAlert', function(system, data, netId)
    local vehicleEntity = nil
    if netId and NetworkDoesNetworkIdExist(netId) then
        vehicleEntity = NetworkGetEntityFromNetworkId(netId)
    end
    runAlert(system, data, vehicleEntity)
end)
