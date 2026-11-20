Editable = Editable or {}
Editable.Client = {}

-- Minigame to open the vehicle
function Editable.Client.MiniGame()
    -- You can change the difficulty or type of minigame here

    return lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'e' })
end

-- Custom police alert (only used when Config.Police.Dispatch.System = 'custom').
-- Called on the thief's client right after the job vehicle is lockpicked, at most once per job.
-- The server validated the request and filled the data from its own job state:
-- data = {
--     coords     = vector3,  -- job vehicle position
--     plate      = string,   -- job vehicle plate
--     model      = string,   -- spawn name, e.g. 'sultanrs'
--     modelLabel = string,   -- display name, e.g. 'Sultan RS'
--     code       = string,   -- Config.Police.Dispatch.Code
--     title      = string,   -- localized Config.Police.Dispatch.Title
--     message    = string,   -- localized Config.Police.Dispatch.Message
--     jobs       = table,    -- Config.Police.Jobs
--     jobType    = string?,  -- Config.Police.JobType
--     vehicle    = number,   -- job vehicle entity (this client)
-- }
-- Editable.Server.DispatchAlert (editable/server.lua) receives the same data on the server.
function Editable.Client.DispatchAlert(data)
    -- Example: an export of your dispatch script
    -- exports['my_dispatch']:SendAlert({
    --     coords = data.coords,
    --     title = data.title,
    --     message = data.message,
    --     code = data.code,
    --     jobs = data.jobs,
    -- })

    -- Example: a server event of your dispatch script
    -- TriggerServerEvent('my_dispatch:server:alert', { coords = data.coords, text = data.message })
end

-- Custom Notifications (Optional, if you want to change the style)
function Editable.Client.Notify(data)
    lib.notify(data)
end
