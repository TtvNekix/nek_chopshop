-- Resolves Config.Inventory into a concrete inventory system name (InventorySystem, both sides).
-- Supported values: 'ox_inventory', 'qs-inventory', 'core_inventory', 'ps-inventory', 'qb-inventory',
-- 'custom' (your own functions in editable/server.lua, Editable.Inventory) or 'auto'.
-- 'auto' checks the resources in that order and uses the first one that is started.

local SUPPORTED = {
    ['ox_inventory'] = true,
    ['qs-inventory'] = true,
    ['core_inventory'] = true,
    ['ps-inventory'] = true,
    ['qb-inventory'] = true,
    ['custom'] = true,
}

local DETECTION_ORDER = { 'ox_inventory', 'qs-inventory', 'core_inventory', 'ps-inventory', 'qb-inventory' }

local function isStarted(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function resolveInventory()
    local configured = tostring(Config.Inventory or 'auto'):lower()

    if configured ~= 'auto' then
        if not SUPPORTED[configured] then
            print(('^3[nek_chopshop] Unsupported Config.Inventory "%s". Falling back to auto-detection.^7'):format(configured))
        elseif configured == 'custom' then
            -- No resource to check: the owner wires Editable.Inventory in editable/server.lua
            return configured
        elseif not isStarted(configured) then
            -- A forced inventory that is not running would crash the adapter on the first export call
            print(('^3[nek_chopshop] Config.Inventory is "%s" but it is not started. Falling back to auto-detection.^7')
                :format(configured))
        else
            return configured
        end
    end

    for _, resource in ipairs(DETECTION_ORDER) do
        if isStarted(resource) then
            return resource
        end
    end

    return nil
end

InventorySystem = resolveInventory()

if not InventorySystem then
    print('^1[nek_chopshop] No supported inventory detected (ox_inventory, qs-inventory, core_inventory, ps-inventory or qb-inventory). Waiting for one to start; set Config.Inventory = \'custom\' and fill Editable.Inventory to use another one.^7')
elseif Config.Debug then
    print(('[nek_chopshop] Using inventory: %s'):format(InventorySystem))
end

-- Server only: when nothing was detected at start (the inventory starts after this resource),
-- detect again each time one of the detection-order resources starts. Stops after the first hit.
if IsDuplicityVersion() and not InventorySystem then
    local watched = {}
    for _, resource in ipairs(DETECTION_ORDER) do watched[resource] = true end

    AddEventHandler('onResourceStart', function(resource)
        if InventorySystem or not watched[resource] then return end

        local picked = resolveInventory()
        if not picked then return end

        InventorySystem = picked
        print(('^2[nek_chopshop] Inventory detected after start: %s^7'):format(picked))
        if OnInventoryResolved then OnInventoryResolved() end
    end)
end
