-- Resolves Config.Framework into a concrete framework name.
-- Supported values: 'esx', 'qbcore', 'qbox' or 'auto'.
-- 'auto' checks qbx_core first because Qbox also provides 'qb-core'.

local SUPPORTED = { esx = true, qbcore = true, qbox = true }

local RESOURCES = { qbox = 'qbx_core', esx = 'es_extended', qbcore = 'qb-core' }

local DETECTION_ORDER = {
    { name = 'qbox',   resource = 'qbx_core' },
    { name = 'esx',    resource = 'es_extended' },
    { name = 'qbcore', resource = 'qb-core' },
}

local function isStarted(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function resolveFramework()
    local configured = (Config.Framework or 'auto'):lower()

    if configured ~= 'auto' then
        if not SUPPORTED[configured] then
            print(('^3[nek_chopshop] Unsupported Config.Framework "%s". Falling back to auto-detection.^7'):format(configured))
        elseif not isStarted(RESOURCES[configured]) then
            -- A forced framework whose core is not running would crash the bridges on the first export call
            print(('^3[nek_chopshop] Config.Framework is "%s" but %s is not started. Falling back to auto-detection.^7')
                :format(configured, RESOURCES[configured]))
        else
            return configured
        end
    end

    for _, candidate in ipairs(DETECTION_ORDER) do
        if isStarted(candidate.resource) then
            return candidate.name
        end
    end

    return nil
end

Framework = resolveFramework()

if not Framework then
    print('^1[nek_chopshop] No supported framework detected (qbx_core, es_extended or qb-core).^7')
elseif Config.Debug then
    print(('[nek_chopshop] Using framework: %s'):format(Framework))
end
