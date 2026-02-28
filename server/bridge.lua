Bridge = {}

if Config.Framework == 'esx' then
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

    function Bridge.AddItem(source, item, count)
        return exports.ox_inventory:AddItem(source, item, count)
    end

    function Bridge.CanCarryItem(source, item, count)
        return exports.ox_inventory:CanCarryItem(source, item, count)
    end

    function Bridge.GetItemCount(source, item)
        return exports.ox_inventory:GetItemCount(source, item)
    end

    function Bridge.RemoveItem(source, item, count)
        return exports.ox_inventory:RemoveItem(source, item, count)
    end
elseif Config.Framework == 'qbcore' then
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

    function Bridge.AddItem(source, item, count)
        return exports.ox_inventory:AddItem(source, item, count)
    end

    function Bridge.CanCarryItem(source, item, count)
        return exports.ox_inventory:CanCarryItem(source, item, count)
    end

    function Bridge.GetItemCount(source, item)
        return exports.ox_inventory:GetItemCount(source, item)
    end

    function Bridge.RemoveItem(source, item, count)
        return exports.ox_inventory:RemoveItem(source, item, count)
    end
end
