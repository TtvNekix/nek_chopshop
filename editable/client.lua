Editable = Editable or {}
Editable.Client = {}

-- Minigame to open the vehicle
function Editable.Client.MiniGame()
    -- You can change the difficulty or type of minigame here

    return lib.skillCheck({ 'easy', 'easy', 'medium' }, { 'e' })
end

-- Police Alert System
function Editable.Client.DispatchAlert(vehicle)
    if not vehicle or vehicle == 0 then return end

    -- Example with ps-dispatch
    -- exports['ps-dispatch']:VehicleTheft(vehicle)

    -- Simple notify example
    -- lib.notify({title = 'Dispatch', description = 'Alert: Vehicle Theft', type = 'error'})
end

-- Custom Notifications (Optional, if you want to change the style)
function Editable.Client.Notify(data)
    lib.notify(data)
end
