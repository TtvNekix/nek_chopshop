local PED = {}
local SELL_PED = {}

local ScrapsOccupied = {}
local Workers = {}
local SharedVehicles = {}
local Cooldowns = {}
local Sessions = {} -- [identifier] = { items = { [item]=cant }, money = total }

local spawned = false

RegisterNetEvent("esx:onPlayerSpawn", function()
    if not spawned then
        SpawnPed(Config.Ped)
        if Config.SellPed and Config.SellPed.Enable then
            SpawnSellPed(Config.SellPed)
        end
        spawned = true
    else
        TriggerClientEvent('chopshop:client:setupPed', source, PED)
        if Config.SellPed and Config.SellPed.Enable then
            TriggerClientEvent('chopshop:client:setupSellPed', source, SELL_PED)
        end
    end
end)

function SpawnPed(data)
    local ped = CreatePed(4, data.Model, data.Coords.x, data.Coords.y, data.Coords.z, data.Coords.w, true, true)

    PED['id'] = ped
    PED['nwid'] = NetworkGetNetworkIdFromEntity(ped)
    PED['coords'] = data.Coords
    PED['target'] = data.Target
    PED['scenario'] = data.Scenario

    TriggerClientEvent('chopshop:client:setupPed', -1, PED)
end

function SpawnSellPed(data)
    local ped = CreatePed(4, data.Model, data.Coords.x, data.Coords.y, data.Coords.z, data.Coords.w, true, true)

    SELL_PED['id'] = ped
    SELL_PED['nwid'] = NetworkGetNetworkIdFromEntity(ped)
    SELL_PED['coords'] = data.Coords
    SELL_PED['scenario'] = data.Scenario
    SELL_PED['items'] = data.Items

    TriggerClientEvent('chopshop:client:setupSellPed', -1, SELL_PED)
end

local function TrackItem(src, item, count)
    local cid = Bridge.GetIdentifier(src); if not cid then return end
    Sessions[cid] = Sessions[cid] or { items = {}, money = 0 }
    Sessions[cid].items[item] = (Sessions[cid].items[item] or 0) + (count or 1)
end

local function TrackMoney(src, amount)
    local cid = Bridge.GetIdentifier(src); if not cid then return end
    Sessions[cid] = Sessions[cid] or { items = {}, money = 0 }
    Sessions[cid].money = (Sessions[cid].money or 0) + (amount or 0)
end

local function PayChopShop(source, amount, reason)
    local L = Config.Logs or {}

    amount = math.floor(amount or 0)
    reason = reason or "Pago por desguace"

    if Bridge.AddMoney(source, amount, reason) then
        TrackMoney(source, amount)

        if L.EnablePay then
            local name = Bridge.GetName(source)
            local cid = Bridge.GetIdentifier(source)
            local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n**Cantidad:** $%d\n**Motivo:** %s")
                :format(name, source, cid, amount, reason)
            ServerUtils.SendDiscordLog("Desguace - Pago realizado", desc, Config.Discord.Color.pay)
        end
    end
end

-- Callbacks
lib.callback.register('chopshop:server:addPedProperties', function()
    return PED
end)

lib.callback.register('chopshop:server:getSellPed', function()
    return SELL_PED
end)

lib.callback.register('chopshop:server:sellItem', function(source, itemName)
    local itemConfig = nil
    for _, v in pairs(Config.SellPed.Items) do
        if v.item == itemName then
            itemConfig = v
            break
        end
    end

    if not itemConfig then return false end

    local count = Bridge.GetItemCount(source, itemName)
    if count and count > 0 then
        if Bridge.RemoveItem(source, itemName, count) then
            local total = count * itemConfig.price
            Bridge.AddMoney(source, total)

            -- Log
            if Config.Logs and Config.Logs.EnablePay then
                local name = Bridge.GetName(source)
                local cid = Bridge.GetIdentifier(source)
                local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n**Venta:** %s x%d\n**Total:** $%d")
                    :format(name, source, cid, itemName, count, total)
                ServerUtils.SendDiscordLog("Desguace - Venta Item", desc, Config.Discord.Color.pay)
            end

            return true, count, total
        end
    end

    return false
end)

lib.callback.register('chopshop:server:getScrapsOccupied', function()
    return ScrapsOccupied
end)

lib.callback.register('chopshop:server:getWorkers', function()
    return Workers
end)

lib.callback.register('chopshop:server:giveItem', function(source, item, count)
    local L = Config.Logs or {}
    count = count or 1

    local success, response = Bridge.AddItem(source, item, count)

    if success then
        TrackItem(source, item, count)

        if L.EnableItem then
            local name = Bridge.GetName(source)
            local cid = Bridge.GetIdentifier(source)
            local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n**Item:** %s x%d")
                :format(name, source, cid, item, count)
            ServerUtils.SendDiscordLog("Desguace - Item obtenido", desc, Config.Discord.Color.item)
        end
        return true
    end
    return false
end)

lib.callback.register('chopshop:server:removeWorker', function(source, citizenid, plate)
    local L = Config.Logs or {}
    local currentCid = Bridge.GetIdentifier(source) or citizenid

    if Workers[currentCid] then
        local vehicleNet = Workers[currentCid].vehicle
        local plateToClean = plate or Workers[currentCid].plate

        local vehicle = NetworkGetEntityFromNetworkId(vehicleNet)
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end

        if Workers[currentCid].scrap and Workers[currentCid].scrap.name then
            ScrapsOccupied[Workers[currentCid].scrap.name] = false
        end
        Workers[currentCid] = nil
        if plateToClean and SharedVehicles[plateToClean] then
            SharedVehicles[plateToClean] = nil
        end

        -- Payment
        if Config.Payment and Config.Payment.Enable then
            local min = Config.Payment.Min or 250
            local max = Config.Payment.Max or 400
            local reward = math.random(min, max)
            PayChopShop(source, reward, "Pago final por desguace")
        end

        -- Custom Reward
        if Editable and Editable.Server and Editable.Server.CustomReward then
            Editable.Server.CustomReward(source)
        end

        -- Summary Log
        if L.EnableFinish then
            local cid = Bridge.GetIdentifier(source)
            local name = Bridge.GetName(source)
            local itemsList = ServerUtils.FormatItemsList(Sessions[cid] and Sessions[cid].items)
            local moneyTotal = (Sessions[cid] and Sessions[cid].money) or 0

            local desc = ("**Jugador:** %s (ID:%d, Identifier:`%s`)\n\n**Items:** %s\n**Dinero total:** $%d")
                :format(name, source, cid, itemsList, moneyTotal)

            ServerUtils.SendDiscordLog("Desguace - Resumen final", desc, Config.Discord.Color.finished)
            Sessions[cid] = nil
        end

        return true
    else
        return false
    end
end)

lib.callback.register('chopshop:server:requestJob', function(source, scrapLocation, spawnPoint, vehicle)
    local cid = Bridge.GetIdentifier(source)
    local plate
    if Workers[cid] then
        return 'already_working'
    end

    local currentTime = os.time()
    if Cooldowns[cid] and Cooldowns[cid] > currentTime then
        return 'cooldown'
    end

    local vehicleSpawned = CreateVehicleServerSetter(vehicle, "automobile", spawnPoint.x, spawnPoint.y, spawnPoint.z,
        spawnPoint.w)
    if vehicleSpawned then
        plate = "DES  " .. tostring(math.random(100, 999))
        SetVehicleNumberPlateText(vehicleSpawned, plate)
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicleSpawned)
    ScrapsOccupied[scrapLocation.name] = true
    Workers[cid] = {
        scrap = scrapLocation,
        spawn = spawnPoint,
        vehicle = netId,
        plate = plate
    }
    SharedVehicles[plate] = {
        owner = cid,
        vehicle = netId,
        partsToRemove = {}
    }

    Cooldowns[cid] = os.time() + (Config.Cooldown or 3600)

    return 'success', netId
end)

lib.callback.register('chopshop:server:canAddItem', function(source, item, cant)
    return Bridge.CanCarryItem(source, item, cant)
end)

lib.callback.register('chopshop:server:updatePartsToRemove', function(source, plate, parts)
    if SharedVehicles[plate] then
        SharedVehicles[plate].partsToRemove = parts
        return SharedVehicles[plate].partsToRemove
    else
        return false
    end
end)

lib.callback.register('chopshop:server:sendVehicleToScrap', function(source, plate, coworker)
    if SharedVehicles[plate] then
        return true, TriggerClientEvent('chopshop:client:sendVehicleToScrap', coworker, SharedVehicles[plate])
    else
        return false
    end
end)

lib.callback.register('chopshop:server:getCooldown', function(source)
    local cid = Bridge.GetIdentifier(source)
    if not cid then return nil end

    local currentTime = os.time()
    local cooldownTime = Cooldowns[cid] or 0

    if currentTime < cooldownTime then
        return cooldownTime - currentTime
    end

    return 0
end)

RegisterNetEvent('chopshop:server:brokePart', function(netid, part)
    TriggerClientEvent('chopshop:client:brokePart', -1, netid, part)
end)

RegisterNetEvent('chopshop:server:syncFinish', function(targetSrc)
    if targetSrc then
        TriggerClientEvent('chopshop:client:syncFinish', targetSrc)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if PED['id'] then
            DeleteEntity(PED['id'])
        end
        if SELL_PED['id'] then
            DeleteEntity(SELL_PED['id'])
        end
    end
end)
