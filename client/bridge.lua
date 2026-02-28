Bridge = {}

if Config.Framework == 'esx' then
    ESX = exports.es_extended:getSharedObject()

    function Bridge.GetPlayerData()
        return ESX.GetPlayerData()
    end

    function Bridge.GetIdentifier()
        local data = ESX.GetPlayerData()
        return data and data.identifier or nil
    end

    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        TriggerEvent('chopshop:client:playerLoaded', xPlayer)
    end)
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()

    function Bridge.GetPlayerData()
        return QBCore.Functions.GetPlayerData()
    end

    function Bridge.GetIdentifier()
        local data = QBCore.Functions.GetPlayerData()
        return data and data.citizenid or nil
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        TriggerEvent('chopshop:client:playerLoaded', QBCore.Functions.GetPlayerData())
    end)
else
    print('ChopShop: Framework not supported: ' .. Config.Framework)
end


function Bridge.Notify(data)
    Editable.Client.Notify(data)
end

function Bridge.GetName(playerId)
    return GetPlayerName(playerId)
end
