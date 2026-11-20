-- Police dispatch: picks the dispatch script and runs the server-side adapters.
-- Client-side adapters live in client/dispatch.lua; the server only tells the client which one to use.

ServerDispatch = {}

local Police = Config.Police or {}
local DispatchCfg = Police.Dispatch or {}

-- Auto-detection order (first started resource wins) and where each adapter runs.
ServerDispatch.Systems = {
    { name = 'ps-dispatch',        side = 'client' },
    { name = 'cd_dispatch',        side = 'client' },
    { name = 'qs-dispatch',        side = 'client' },
    { name = 'rcore_dispatch',     side = 'client' },
    { name = 'core_dispatch',      side = 'server' },
    { name = 'tk_dispatch',        side = 'client' },
    { name = 'origen_police',      side = 'client' },
    { name = 'lb-tablet',          side = 'server' },
    { name = 'linden_outlawalert', side = 'client' },
}

local SIDE = {}
for _, system in ipairs(ServerDispatch.Systems) do SIDE[system.name] = system.side end

-- Server-side adapters. `data` = { coords, plate, model, code, title, message, jobs, jobType }
local ADAPTERS = {}

ADAPTERS['core_dispatch'] = function(data)
    local blip = DispatchCfg.Blip or {}
    exports['core_dispatch']:sendAlert({
        code = data.code,
        message = data.message,
        coords = data.coords,
        priority = true,
        job = data.jobs,
        time = ((blip.Time or 120) * 1000),
        blip = blip.Sprite,
        color = blip.Color,
        extraInfo = { { icon = 'fa-car', info = data.plate } },
    })
end

ADAPTERS['lb-tablet'] = function(data)
    for _, job in ipairs(data.jobs) do
        exports['lb-tablet']:AddDispatch({
            job = job,
            priority = 'high',
            code = data.code,
            title = data.title,
            description = data.message,
            location = { label = data.title, coords = vec2(data.coords.x, data.coords.y) },
            time = (DispatchCfg.Blip and DispatchCfg.Blip.Time) or 120,
        })
    end
end

---Resolves Config.Police.Dispatch.System.
---@return string|nil system 'custom', a supported resource name, or nil (disabled / nothing started)
function ServerDispatch.Resolve()
    local system = DispatchCfg.System
    if not system then return nil end
    if system == 'custom' then return 'custom' end

    if system ~= 'auto' then
        if not SIDE[system] then
            print(('^3[nek_chopshop] Unknown Config.Police.Dispatch.System "%s"; no alert sent.^7'):format(tostring(system)))
            return nil
        end
        return system
    end

    for _, candidate in ipairs(ServerDispatch.Systems) do
        if GetResourceState(candidate.name) == 'started' then return candidate.name end
    end
    return nil
end

---Sends the alert. Server-side and custom adapters run here; for client-side
---systems the caller hands the system name and data back to the client.
---@return string|nil clientSystem system the client must run ('custom' included), nil when nothing is left to do
function ServerDispatch.Send(source, data)
    local system = ServerDispatch.Resolve()
    if not system then return nil end

    if system == 'custom' then
        if Editable and Editable.Server and Editable.Server.DispatchAlert then
            local ok, err = pcall(Editable.Server.DispatchAlert, data, source)
            if not ok then print(('^1[nek_chopshop] Editable.Server.DispatchAlert failed: %s^7'):format(err)) end
        end
        return 'custom'
    end

    if SIDE[system] == 'server' then
        local ok, err = pcall(ADAPTERS[system], data)
        if not ok then print(('^1[nek_chopshop] Dispatch (%s) failed: %s^7'):format(system, err)) end
        return nil
    end

    return system
end
