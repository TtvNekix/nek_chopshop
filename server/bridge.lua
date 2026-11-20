Bridge = {}

-- Framework-specific player functions
if Framework == 'esx' then
    ESX = exports.es_extended:getSharedObject()

    function Bridge.GetPlayer(source)
        return ESX.GetPlayerFromId(source)
    end

    function Bridge.GetIdentifier(source)
        local xPlayer = Bridge.GetPlayer(source)
        return xPlayer and xPlayer.identifier or nil
    end

    function Bridge.GetName(source)
        if not source then return "Unknown" end
        return GetPlayerName(source)
    end

    function Bridge.AddMoney(source, amount, reason)
        local xPlayer = Bridge.GetPlayer(source)
        if xPlayer then
            xPlayer.addMoney(amount, reason)
            return true
        end
        return false
    end
elseif Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()

    function Bridge.GetPlayer(source)
        return QBCore.Functions.GetPlayer(source)
    end

    function Bridge.GetIdentifier(source)
        local Player = Bridge.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end

    function Bridge.GetName(source)
        local Player = Bridge.GetPlayer(source)
        if Player then
            return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        end
        return GetPlayerName(source)
    end

    function Bridge.AddMoney(source, amount, reason)
        local Player = Bridge.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney('cash', amount, reason)
            return true
        end
        return false
    end
elseif Framework == 'qbox' then
    function Bridge.GetPlayer(source)
        return exports.qbx_core:GetPlayer(source)
    end

    function Bridge.GetIdentifier(source)
        local player = Bridge.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end

    function Bridge.GetName(source)
        local player = Bridge.GetPlayer(source)
        if player then
            local charinfo = player.PlayerData.charinfo
            return charinfo.firstname .. ' ' .. charinfo.lastname
        end
        return GetPlayerName(source)
    end

    function Bridge.AddMoney(source, amount, reason)
        return exports.qbx_core:AddMoney(source, 'cash', amount, reason) == true
    end
else
    print('ChopShop: Framework not supported: ' .. tostring(Config.Framework))
end

-- Police on duty --------------------------------------------------------------
-- QBCore/Qbox count by Config.Police.JobType (or by Config.Police.Jobs when JobType is false);
-- ESX counts players of Config.Police.Jobs whose job.onDuty is not false (nil = on duty, old ESX).

local function policeJobNames()
    local names = {}
    for _, name in ipairs((Config.Police and Config.Police.Jobs) or {}) do names[name] = true end
    return names
end

function Bridge.GetPoliceCount()
    local police = Config.Police or {}
    local jobType = police.JobType
    local count = 0

    if Framework == 'qbox' then
        if jobType then
            return exports.qbx_core:GetDutyCountType(jobType) or 0
        end
        for _, name in ipairs(police.Jobs or {}) do
            count = count + (exports.qbx_core:GetDutyCountJob(name) or 0)
        end
    elseif Framework == 'qbcore' then
        local names = policeJobNames()
        for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
            local job = player.PlayerData.job
            local matches = jobType and job.type == jobType or (not jobType and names[job.name])
            if matches and job.onduty then count = count + 1 end
        end
    elseif Framework == 'esx' then
        for _, name in ipairs(police.Jobs or {}) do
            for _, xPlayer in pairs(ESX.GetExtendedPlayers('job', name)) do
                if xPlayer.job.onDuty ~= false then count = count + 1 end
            end
        end
    end

    return count
end

-- Inventory functions: thin wrappers over the adapter of the detected inventory (server/inventory.lua).
-- metadata: optional table in the inventory's shape (Inventory.MakeMetadata); items with different
-- metadata never stack.
function Bridge.AddItem(source, item, count, metadata)
    return Inventory.AddItem(source, item, count, metadata)
end

function Bridge.CanCarryItem(source, item, count)
    return Inventory.CanCarryItem(source, item, count)
end

function Bridge.GetItemCount(source, item)
    return Inventory.GetCount(source, item)
end

-- Removes `count` from that exact stack (an entry of Bridge.GetItemStacks).
function Bridge.RemoveStack(source, item, count, stack)
    return Inventory.RemoveStack(source, item, count, stack)
end

-- True when the player can receive every grant at once.
-- grants = { { item = string, count = number, metadata = table|nil }, ... }
-- removePart relies on no yield between this check and the grant (see server/inventory.lua).
function Bridge.CanCarryItems(source, grants)
    return Inventory.CanCarry(source, grants)
end

-- Every stack of an item in the player's inventory: { { slot, count, metadata, quality }, ... }
function Bridge.GetItemStacks(source, item)
    return Inventory.GetStacks(source, item)
end
