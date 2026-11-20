-- Vehicle keys bridge: gives the job owner the keys of the job vehicle after a server-validated
-- lockpick (chopshop:server:vehicleLockpicked in server/main.lua) and takes them back when the job ends.
-- Key scripts such as qbx_vehiclekeys block the engine of a vehicle the player has no keys for.
-- Every adapter runs on the server; the client never chooses which vehicle gets keys.

VehicleKeys = {}

local KeysCfg = Config.VehicleKeys or {}

-- Auto-detection order (first started resource wins). qbx_vehiclekeys first: it `provide`s
-- 'qb-vehiclekeys', and several paid scripts also ship qb-vehiclekeys compatibility layers.
VehicleKeys.Systems = {
    'qbx_vehiclekeys',
    'qs-vehiclekeys',
    'wasabi_carlock',
    'MrNewbVehicleKeys',
    'ak47_vehiclekeys',
    'vehicles_keys',
    'qb-vehiclekeys',
}

-- Adapters: Give(src, vehicle, plate, model) / Remove(src, vehicle, plate, model).
-- `vehicle` is the server entity handle (nil when the vehicle no longer exists), `plate` the job
-- plate set by the server, `model` the spawn name.
local ADAPTERS = {}

-- Verified against the installed qbx_vehiclekeys (server/keys.lua, server/main.lua).
-- Keys are bound to Entity(vehicle).state.sessionId, so they need the entity.
ADAPTERS['qbx_vehiclekeys'] = {
    Give = function(src, vehicle)
        if not vehicle then return end
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true)
        -- Keep qbx's lock state bag in line with the lockpick: with no state bag yet, qbx locks the
        -- vehicle again (random spawnLocked chance) on the next enter attempt.
        exports.qbx_vehiclekeys:SetLockState(vehicle, 'unlock')
    end,
    Remove = function(src, vehicle)
        if not vehicle then return end
        if exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true) then return end
        -- RemoveKeys needs the player loaded in qbx_core; on playerDropped it may already be gone.
        -- Drop the key from the player's keysList state bag directly so it is not restored on relog.
        local sessionId = Entity(vehicle).state.sessionId
        local state = Player(src).state
        local keys = state and state.keysList
        if sessionId and keys and keys[sessionId] then
            keys[sessionId] = nil
            state:set('keysList', keys, true)
        end
    end,
}

-- qbcore-framework/qb-vehiclekeys server.lua: exports GiveKeys(id, plate) / RemoveKeys(id, plate)
ADAPTERS['qb-vehiclekeys'] = {
    Give = function(src, _, plate) exports['qb-vehiclekeys']:GiveKeys(src, plate) end,
    Remove = function(src, _, plate) exports['qb-vehiclekeys']:RemoveKeys(src, plate) end,
}

-- Quasar docs: GiveServerKeys(source, plate, model, bypassKeyCheck) / RemoveServerKeys(source, plate, model)
ADAPTERS['qs-vehiclekeys'] = {
    Give = function(src, _, plate, model) exports['qs-vehiclekeys']:GiveServerKeys(src, plate, model) end,
    Remove = function(src, _, plate, model) exports['qs-vehiclekeys']:RemoveServerKeys(src, plate, model) end,
}

-- Wasabi docs (V3): GiveKeys(playerId, plate, model?) / RemoveKeys(playerId, plate)
ADAPTERS['wasabi_carlock'] = {
    Give = function(src, _, plate, model) exports.wasabi_carlock:GiveKeys(src, plate, model) end,
    Remove = function(src, _, plate) exports.wasabi_carlock:RemoveKeys(src, plate) end,
}

-- MrNewb docs (Qbox integration snippets): GiveKeys(src, netId) / RemoveKeysByPlate(source, plate)
ADAPTERS['MrNewbVehicleKeys'] = {
    Give = function(src, vehicle)
        if not vehicle then return end
        exports.MrNewbVehicleKeys:GiveKeys(src, NetworkGetNetworkIdFromEntity(vehicle))
    end,
    Remove = function(src, _, plate) exports.MrNewbVehicleKeys:RemoveKeysByPlate(src, plate) end,
}

-- MenanAk47 docs: GiveVirtualKey(source, plate) / RemoveVirtualKey(source, plate)
ADAPTERS['ak47_vehiclekeys'] = {
    Give = function(src, _, plate) exports['ak47_vehiclekeys']:GiveVirtualKey(src, plate) end,
    Remove = function(src, _, plate) exports['ak47_vehiclekeys']:RemoveVirtualKey(src, plate) end,
}

-- jaksam docs: giveVehicleKeysToPlayerId(playerId, plate, type) / removeKeysFromPlayerId(playerId, plate)
ADAPTERS['vehicles_keys'] = {
    Give = function(src, _, plate) exports['vehicles_keys']:giveVehicleKeysToPlayerId(src, plate, 'temporary') end,
    Remove = function(src, _, plate) exports['vehicles_keys']:removeKeysFromPlayerId(src, plate) end,
}

-- 'custom': your own functions in editable/server.lua
ADAPTERS['custom'] = {
    Give = function(src, vehicle, plate, model)
        local fn = Editable and Editable.Server and Editable.Server.GiveVehicleKeys
        if fn then fn(src, vehicle, plate, model) end
    end,
    Remove = function(src, vehicle, plate, model)
        local fn = Editable and Editable.Server and Editable.Server.RemoveVehicleKeys
        if fn then fn(src, vehicle, plate, model) end
    end,
}

local warned = {} -- [message] = true, so each kind of failure is printed once

local function warnOnce(message)
    if warned[message] then return end
    warned[message] = true
    print(('^3[nek_chopshop] %s^7'):format(message))
end

---Resolves Config.VehicleKeys.System.
---@return string|nil system 'custom', a supported resource name, or nil (disabled / nothing started)
function VehicleKeys.Resolve()
    local system = KeysCfg.System
    if system == nil then system = 'auto' end
    if not system then return nil end
    if system == 'custom' then return 'custom' end

    if system ~= 'auto' then
        if not ADAPTERS[system] then
            warnOnce(('Unknown Config.VehicleKeys.System "%s"; no keys are given.'):format(tostring(system)))
            return nil
        end
        if GetResourceState(system) ~= 'started' then
            warnOnce(('Config.VehicleKeys.System is "%s" but it is not started; no keys are given.'):format(system))
            return nil
        end
        return system
    end

    for _, candidate in ipairs(VehicleKeys.Systems) do
        if GetResourceState(candidate) == 'started' then return candidate end
    end
    return nil
end

local function run(action, src, vehicle, plate, model)
    local system = VehicleKeys.Resolve()
    if not system then return nil end

    local ok, err = pcall(ADAPTERS[system][action], src, vehicle, plate, model)
    if not ok then
        warnOnce(('Vehicle keys (%s) %s failed: %s'):format(system, action, tostring(err)))
        return nil
    end
    return system
end

---Gives `src` the keys of the job vehicle (adapters only call exports, failures are caught).
---@return string|nil system the key system used, nil when disabled, none detected or the call failed
function VehicleKeys.Give(src, vehicle, plate, model)
    return run('Give', src, vehicle, plate, model)
end

---Takes the keys of the job vehicle back from `src`. Call it before the vehicle entity is deleted.
---@return string|nil system the key system used, nil when disabled, none detected or the call failed
function VehicleKeys.Remove(src, vehicle, plate, model)
    return run('Remove', src, vehicle, plate, model)
end
