Bridge = {}

if Framework == 'esx' then
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
elseif Framework == 'qbcore' then
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
elseif Framework == 'qbox' then
    function Bridge.GetPlayerData()
        return exports.qbx_core:GetPlayerData()
    end

    function Bridge.GetIdentifier()
        local data = exports.qbx_core:GetPlayerData()
        return data and data.citizenid or nil
    end

    -- qbx_core keeps firing the QBCore compatibility event on character load
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        TriggerEvent('chopshop:client:playerLoaded', exports.qbx_core:GetPlayerData())
    end)
else
    print('ChopShop: Framework not supported: ' .. tostring(Config.Framework))
end

function Bridge.Notify(data)
    Editable.Client.Notify(data)
end

function Bridge.GetName(playerId)
    return GetPlayerName(playerId)
end

-- Asked to the server, so the client works with every inventory. UI only: the server checks the
-- lockpick again when the scrap starts. Yields (call it from a thread / ox_target onSelect).
function Bridge.HasLockpick()
    return lib.callback.await('chopshop:server:hasLockpick', false) == true
end
