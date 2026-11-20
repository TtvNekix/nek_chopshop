-- Admin tools.
-- /chopshop_resetcd <all | server id>
--   Clears the job cooldown (stored in this resource's KVP, per character and per license).
--   Allowed from the server console, or for players with the ACE in Config.AdminAce (default 'admin').

local COMMAND = 'chopshop_resetcd'
local PREFIX = 'cooldown:'

local function isAllowed(source)
    if source == 0 then return true end
    return IsPlayerAceAllowed(source, Config.AdminAce or 'admin')
        or IsPlayerAceAllowed(source, 'command.' .. COMMAND)
end

local function reply(source, key, ...)
    local text = locale(key, ...)
    if source == 0 then
        print(('[nek_chopshop] %s'):format(text))
    else
        TriggerClientEvent('ox_lib:notify', source, { title = 'Chop Shop', description = text, type = 'inform' })
    end
end

-- Deletes every cooldown entry and returns how many were removed.
local function resetAll()
    local keys = {}
    local handle = StartFindKvp(PREFIX)
    if handle ~= -1 then
        local key = FindKvp(handle)
        while key do
            keys[#keys + 1] = key
            key = FindKvp(handle)
        end
        EndFindKvp(handle)
    end

    for _, key in ipairs(keys) do
        DeleteResourceKvp(key)
    end
    return #keys
end

-- Deletes the cooldown of one connected player (current character and license).
local function resetPlayer(target)
    local removed = 0
    local cid = Bridge.GetIdentifier(target)
    if cid then
        DeleteResourceKvp(PREFIX .. 'cid:' .. cid)
        removed = removed + 1
    end
    local license = GetPlayerIdentifierByType(target, 'license')
    if license then
        DeleteResourceKvp(PREFIX .. 'license:' .. license)
        removed = removed + 1
    end
    return removed
end

RegisterCommand(COMMAND, function(source, args)
    if not isAllowed(source) then
        reply(source, 'admin_no_permission')
        return
    end

    local target = args[1]
    if target == 'all' then
        local count = resetAll()
        reply(source, 'admin_cd_reset_all', count)
        print(('[nek_chopshop] Cooldowns reset for everyone by %s (%d entries).'):format(
            source == 0 and 'console' or (GetPlayerName(source) or tostring(source)), count))
        return
    end

    local id = tonumber(target)
    if not id or not GetPlayerName(id) then
        reply(source, 'admin_cd_usage', COMMAND)
        return
    end

    resetPlayer(id)
    reply(source, 'admin_cd_reset_player', GetPlayerName(id) or tostring(id))
    print(('[nek_chopshop] Cooldown reset for %s (%d) by %s.'):format(GetPlayerName(id) or '?', id,
        source == 0 and 'console' or (GetPlayerName(source) or tostring(source))))
end, false)
