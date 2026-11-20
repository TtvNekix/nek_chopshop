local PED = {}
local SELL_PED = {}

-- Inicialización
CreateThread(function()
    while not Bridge.GetIdentifier() do Wait(10) end

    TriggerServerEvent('chopshop:server:playerReady')

    if Config.Ped then
        if Config.Ped.Blip and Config.Ped.Blip.Enable then
            local blip = AddBlipForCoord(Config.Ped.Coords.x, Config.Ped.Coords.y, Config.Ped.Coords.z)
            SetBlipSprite(blip, Config.Ped.Blip.Sprite)
            SetBlipColour(blip, Config.Ped.Blip.Color)
            SetBlipScale(blip, Config.Ped.Blip.Scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(_L(Config.Ped.Blip.Label))
            EndTextCommandSetBlipName(blip)
        end
        local pedPoint = lib.points.new({
            coords = vec3(Config.Ped.Coords.x, Config.Ped.Coords.y, Config.Ped.Coords.z),
            distance = 15
        })

        -- Runs on every approach: the ped is re-created (new handle) each time it streams back in
        function pedPoint:onEnter()
            ObtainPedProperties()
        end
    end

    if Config.SellPed and Config.SellPed.Enable then
        if Config.SellPed.Blip and Config.SellPed.Blip.Enable then
            local blip = AddBlipForCoord(Config.SellPed.Coords.x, Config.SellPed.Coords.y, Config.SellPed.Coords.z)
            SetBlipSprite(blip, Config.SellPed.Blip.Sprite)
            SetBlipColour(blip, Config.SellPed.Blip.Color)
            SetBlipScale(blip, Config.SellPed.Blip.Scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(_L(Config.SellPed.Blip.Label))
            EndTextCommandSetBlipName(blip)
        end
        local sellPedPoint = lib.points.new({
            coords = vec3(Config.SellPed.Coords.x, Config.SellPed.Coords.y, Config.SellPed.Coords.z),
            distance = 15
        })

        function sellPedPoint:onEnter()
            ObtainSellPedProperties()
        end
    end
end)


-- NUI ----------------------------------------------------------------------------

-- Real earnings per sellable item, priced by the server per stack quality:
-- { [item] = { owned = n, total = money } }. Empty table when the server does not answer.
local function sellQuote()
    return lib.callback.await('chopshop:server:getSellQuote', false) or {}
end

-- ox_lib flow of the job ped (no NUI, or the NUI page is not ready): asks for a job directly.
local function requestJobDirect()
    if ClientUtils.IsOnCooldown() then return end

    local status = ClientUtils.RequestJob()

    if status == 'success' then
        -- blips and tracker are set up by ClientUtils.RequestJob
    elseif status == 'already_working' then
        ClientInteract.Feedback('error', 'already_working')
    elseif status == 'cooldown' then
        ClientInteract.Feedback('error', 'cooldown_msg', 0)
    elseif status == 'no_scrap' then
        ClientInteract.Feedback('error', 'no_scrap_available')
    elseif status == 'no_police' then
        ClientInteract.Feedback('error', 'no_police')
    else
        ClientInteract.Feedback('error', 'error_starting')
    end
end

-- ox_lib sell menu of the sell ped (no NUI, or the NUI page is not ready).
local function openSellMenu()
    local quote = sellQuote()
    local options = {}
    for _, itemData in ipairs(Config.SellPed.Items) do
        local entry = quote[itemData.item]
        table.insert(options, {
            title = _L(itemData.label) .. " - $" .. itemData.price,
            description = (entry and entry.owned > 0)
                and _L('sell_item_quote', entry.owned, entry.total)
                or _L('sell_item_desc', _L(itemData.label)),
            icon = 'dollar',
            onSelect = function()
                local success, count, total = lib.callback.await('chopshop:server:sellItem', false,
                    itemData.item)
                if success then
                    ClientInteract.Feedback('success', 'sold_item', count, _L(itemData.label), total)
                else
                    ClientInteract.Feedback('error', 'no_item')
                end
            end
        })
    end
    lib.registerContext({
        id = 'sell_chop_menu',
        title = _L('sell_menu_title'),
        options = options
    })
    lib.showContext('sell_chop_menu')
end

-- Opens the job board with the current cooldown / bay / busy state (epoch seconds -> ms).
-- Returns false when the board could not be opened (the caller falls back to the ox_lib flow).
function OpenJobBoard()
    local info = lib.callback.await('chopshop:server:getBoardStatus', false)
    -- nil: not next to the ped (or no character); nothing to show, and nothing to fall back to
    if not info then return true end

    local status = { kind = 'available' }
    if info.busy then
        status = { kind = 'busy' }
    elseif (info.cooldownUntil or 0) > 0 then
        status = { kind = 'cooldown', ['until'] = info.cooldownUntil * 1000 }
    elseif info.policeOk == false then
        status = { kind = 'no_police' }
    elseif not info.scrapAvailable then
        status = { kind = 'no_scrap' }
    end

    local payout = nil
    if Config.Payment and Config.Payment.Enable then
        payout = { min = Config.Payment.Min or 250, max = Config.Payment.Max or 400 }
    end

    -- reputation: { level, xp, xpMax, nextUnlock? } built by the server, nil when disabled
    return Nui.open('job-board', { status = status, payout = payout, reputation = info.reputation })
end

-- Returns false when the buyer could not be opened (the caller falls back to the ox_lib menu).
function OpenPartsBuyer()
    local quote = sellQuote()
    local items = {}
    for _, itemData in ipairs(Config.SellPed.Items) do
        local entry = quote[itemData.item]
        items[#items + 1] = {
            item = itemData.item,
            label = _L(itemData.label),
            price = itemData.price,
            owned = entry and entry.owned or 0,
            total = entry and entry.total or nil,
        }
    end
    return Nui.open('parts-buyer', { items = items })
end

-- Errors are returned as codes: the board writes them on the open sheet (errors.<code>), no notification.
Nui.on('requestJob', function()
    if not Nui.isOpen('job-board') then return false, 'error' end

    local status, plate = ClientUtils.RequestJob()
    if status == 'success' then
        Nui.close('job-board')
        return true, { plate = plate }
    end

    if status == 'already_working' or status == 'cooldown' or status == 'no_scrap' or status == 'no_police' then
        return false, status
    end
    return false, 'error'
end)

Nui.on('sellItem', function(data)
    if not Nui.isOpen('parts-buyer') or type(data.item) ~= 'string' then return false, 'no_item' end

    local itemData
    for _, entry in ipairs(Config.SellPed.Items) do
        if entry.item == data.item then itemData = entry break end
    end
    if not itemData then return false, 'no_item' end

    local success, count, total = lib.callback.await('chopshop:server:sellItem', false, itemData.item)
    if not success then return false, 'no_item' end

    local remaining = sellQuote()[itemData.item]
    return true, {
        item = itemData.item,
        label = _L(itemData.label),
        count = count,
        total = total,
        owned = remaining and remaining.owned or 0,
        remainingTotal = remaining and remaining.total or nil,
    }
end)

if Config.UseNUI then
    Nui.setLocale(ClientUtils.NuiLocale())
end

-- The player changed language from the ox_lib settings: reload our files and refresh the NUI.
AddEventHandler('ox_lib:setLocale', function(key)
    LoadChopLocale(key)
    if Config.UseNUI then
        Nui.setLocale(ClientUtils.NuiLocale())
    end
end)

function ObtainPedProperties(data)
    local pedData = data or lib.callback.await('chopshop:server:addPedProperties', false)
    if not pedData then return end
    PED = pedData

    local pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)

    local tries = 0
    while not DoesEntityExist(pedEntity) and tries < 20 do
        pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)
        Wait(100)
        tries = tries + 1
    end

    if DoesEntityExist(pedEntity) then
        FreezeEntityPosition(pedEntity, true)
        SetEntityInvincible(pedEntity, true)
        SetBlockingOfNonTemporaryEvents(pedEntity, true)

        if pedData.scenario then
            TaskStartScenarioInPlace(pedEntity, pedData.scenario, 0, true)
        end

        -- By network id: ox_target re-attaches it whenever the ped streams back in
        exports.ox_target:removeEntity(pedData.nwid, 'request_chop_job')
        exports.ox_target:addEntity(pedData.nwid, {
            {
                name = 'request_chop_job',
                icon = Config.Ped.Target.options[1].icon,
                label = _L(Config.Ped.Target.options[1].label),
                distance = 2.0,
                onSelect = function()
                    -- The NUI board needs the page ready; otherwise use the ox_lib flow
                    if Config.UseNUI and Nui.waitReady(2000) and OpenJobBoard() then return end
                    requestJobDirect()
                end
            }
        })
    end
end

function ObtainSellPedProperties(data)
    local pedData = data or lib.callback.await('chopshop:server:getSellPed', false)
    if not pedData then return end
    SELL_PED = pedData

    local pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)

    local tries = 0
    while not DoesEntityExist(pedEntity) and tries < 20 do
        pedEntity = NetworkGetEntityFromNetworkId(pedData.nwid)
        Wait(100)
        tries = tries + 1
    end

    if DoesEntityExist(pedEntity) then
        FreezeEntityPosition(pedEntity, true)
        SetEntityInvincible(pedEntity, true)
        SetBlockingOfNonTemporaryEvents(pedEntity, true)

        if pedData.scenario then
            TaskStartScenarioInPlace(pedEntity, pedData.scenario, 0, true)
        end

        exports.ox_target:removeEntity(pedData.nwid, 'sell_chop_items')
        exports.ox_target:addEntity(pedData.nwid, {
            {
                name = 'sell_chop_items',
                icon = 'fas fa-dollar-sign',
                label = _L('sell_parts'),
                distance = 2.0,
                onSelect = function()
                    -- The NUI buyer needs the page ready; otherwise use the ox_lib menu
                    if Config.UseNUI and Nui.waitReady(2000) and OpenPartsBuyer() then return end
                    openSellMenu()
                end
            }
        })
    end
end

RegisterNetEvent('chopshop:client:setupPed', function(data)
    CreateThread(function()
        ObtainPedProperties(data)
    end)
end)

RegisterNetEvent('chopshop:client:setupSellPed', function(data)
    CreateThread(function()
        ObtainSellPedProperties(data)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if PED['nwid'] then exports.ox_target:removeEntity(PED['nwid'], 'request_chop_job') end
        if SELL_PED['nwid'] then exports.ox_target:removeEntity(SELL_PED['nwid'], 'sell_chop_items') end
    end
end)

RegisterNetEvent('chopshop:client:brokePart', function(netid, part)
    local vehicleEntity = NetworkGetEntityFromNetworkId(netid)
    local timeout = 0
    while not DoesEntityExist(vehicleEntity) and timeout < 10 do
        vehicleEntity = NetworkGetEntityFromNetworkId(netid)
        Wait(100)
        timeout = timeout + 1
    end

    if not DoesEntityExist(vehicleEntity) then return end

    -- Engine and seats have no visual removal: only doors (bonnet, boot) and wheels are broken off
    if part.isDoor then
        SetVehicleDoorBroken(vehicleEntity, part.part, true)
    elseif part.isWheel then
        BreakOffVehicleWheel(vehicleEntity, part.part, true, false, true, false)
        -- Only the network owner simulates the vehicle: make sure it is not frozen and wake its
        -- physics, otherwise a parked (sleeping) body keeps floating where the wheel was
        if NetworkGetEntityOwner(vehicleEntity) == PlayerId() then
            FreezeEntityPosition(vehicleEntity, false)
            ActivatePhysics(vehicleEntity)
        end
    end

    ClientInteract.MarkPartRemoved(netid, part.bone)
end)

RegisterNetEvent('chopshop:client:partnerInvite', function(data)
    ClientInteract.OnPartnerInvite(data)
end)

RegisterNetEvent('chopshop:client:scrapStarted', function(netId)
    ClientInteract.OnScrapStarted(netId)
end)

RegisterNetEvent('chopshop:client:jobFinished', function(netId, isOwner, reason)
    ClientInteract.OnJobFinished(netId, isOwner, reason)
end)

RegisterNetEvent('chopshop:client:playerLoaded', function()
    -- Re-init logic if needed
end)

exports('GetJobStatus', function()
    return {
        active = ClientInteract.HasActiveJob(),
        pedCoords = Config.Ped.Coords
    }
end)
