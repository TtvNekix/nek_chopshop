Editable = Editable or {}
Editable.Server = {}

-- Webhook Configuration (Moved here for security/editability)
Editable.Webhook =
""

-- Discord Log
function Editable.Server.SendDiscordLog(title, description, color)
    local webhook = Editable.Webhook
    if not webhook or webhook == "" then
        return
    end

    local embed = { {
        title = title,
        description = description,
        type = "rich",
        color = color or (Config.Discord.Color and Config.Discord.Color.warn or 16761858),
        footer = { text = os.date("%Y-%m-%d %H:%M:%S") }
    } }

    local payload = {
        username = Config.Discord.Username or "ChopShop Logs",
        avatar_url = (Config.Discord.AvatarUrl ~= "" and Config.Discord.AvatarUrl) or nil,
        embeds = embed
    }

    PerformHttpRequest(webhook, function(err)
        if err ~= 204 and err ~= 200 then
            print(("[ChopShop] Error webhook: %s"):format(tostring(err)))
        end
    end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
end

-- Custom police alert (only used when Config.Police.Dispatch.System = 'custom').
-- Called on the server, at most once per job, when the job owner lockpicked the vehicle.
-- Everything in `data` comes from the server job state, not from the client:
-- data = {
--     coords  = vector3, -- job vehicle position
--     plate   = string,  -- job vehicle plate
--     model   = string,  -- spawn name, e.g. 'sultanrs'
--     code    = string,  -- Config.Police.Dispatch.Code
--     title   = string,  -- localized Config.Police.Dispatch.Title (server language)
--     message = string,  -- localized Config.Police.Dispatch.Message (server language)
--     jobs    = table,   -- Config.Police.Jobs
--     jobType = string?, -- Config.Police.JobType
-- }
-- source = server id of the thief.
-- Editable.Client.DispatchAlert (editable/client.lua) is also called on the thief's client.
function Editable.Server.DispatchAlert(data, source)
    -- Example: server export of your dispatch script
    -- exports['my_dispatch']:CreateAlert({
    --     coords = data.coords,
    --     title = data.title,
    --     description = data.message,
    --     code = data.code,
    --     jobs = data.jobs,
    -- })

    -- Example: message every on-duty officer (Qbox)
    -- local _, officers = exports.qbx_core:GetDutyCountType(data.jobType or 'leo')
    -- for _, officer in ipairs(officers) do
    --     TriggerClientEvent('ox_lib:notify', officer, { title = data.title, description = data.message, type = 'error' })
    -- end
end

-- Custom vehicle keys (only used when Config.VehicleKeys.System = 'custom') -------------------
-- Called on the server. Everything comes from the server job state, not from the client:
--   src     = server id of the job owner (partners never get keys)
--   vehicle = server entity handle of the job vehicle (nil in Remove when the vehicle no longer exists)
--   plate   = job vehicle plate
--   model   = spawn name, e.g. 'sultanrs'
-- GiveVehicleKeys runs once per job, after the owner's lockpick was validated (owner, pickup stage,
-- next to the vehicle, lockpick item held). RemoveVehicleKeys runs when the job ends (if
-- Config.VehicleKeys.RemoveOnEnd), before the vehicle is deleted. Errors are caught and logged once.
function Editable.Server.GiveVehicleKeys(src, vehicle, plate, model)
    -- Example: plate-based server export
    -- exports['my_keys']:GiveKeys(src, plate)

    -- Example: key script that only has a client event (sent to the owner only)
    -- TriggerClientEvent('my_keys:client:addKey', src, plate)
end

function Editable.Server.RemoveVehicleKeys(src, vehicle, plate, model)
    -- Example: plate-based server export
    -- exports['my_keys']:RemoveKeys(src, plate)

    -- Example: entity-based export (skip when the vehicle is already gone)
    -- if vehicle then exports['my_keys']:RemoveKeysFromVehicle(src, vehicle) end
end

-- Custom Reward Logic (Called when finishing job)
-- Can be used to give experience, crypto, items etc.
function Editable.Server.CustomReward(source)
    -- Example:
    -- local xPlayer = ESX.GetPlayerFromId(source)
    -- xPlayer.addAccountMoney('crypto', 10)
end

-- Custom inventory (only used when Config.Inventory = 'custom') ------------------------------
-- For inventories without a built-in adapter (codem-inventory, tgiann-inventory, origen_inventory,
-- ...). Fill the functions below with your inventory's server exports. Every function runs on the
-- server; src is the player's server id. Missing functions fail closed (nothing given, removed or
-- sold) and print a one-time console warning.
-- Keep them free of Wait()/await: the server checks space and gives the items with no yield in
-- between, and the sell ped reads and removes stacks with no yield in between.
Editable.Inventory = {
    -- true only when RemoveStack removes from the exact stack it receives (by slot). When false,
    -- the sell ped prices every stack of an item at its lowest quality (safe default).
    ExactStacks = false,

    -- Resources whose (re)start re-runs the item check (only used when ItemExists is defined).
    ItemResources = {},

    -- Gives `count` of `item` with `metadata` (a table from MakeMetadata below, or nil). Return true on success.
    -- AddItem = function(src, item, count, metadata)
    --     return exports['my_inventory']:AddItem(src, item, count, metadata) == true
    -- end,

    -- Removes `count` from `stack` (one entry returned by GetStacks: { slot, count, metadata }).
    -- Return true only when exactly `count` was removed.
    -- RemoveStack = function(src, item, count, stack)
    --     return exports['my_inventory']:RemoveItem(src, item, count, stack.slot) == true
    -- end,

    -- Total amount of `item` the player holds.
    -- GetCount = function(src, item)
    --     return exports['my_inventory']:GetItemCount(src, item) or 0
    -- end,

    -- Every stack of `item`: { { slot = number, count = number, metadata = table|nil }, ... }
    -- The tier quality is read from metadata.chopQuality (or metadata.quality when it is a string).
    -- GetStacks = function(src, item)
    --     local stacks = {}
    --     for _, data in pairs(exports['my_inventory']:GetItemsByName(src, item) or {}) do
    --         stacks[#stacks + 1] = { slot = data.slot, count = data.amount, metadata = data.info }
    --     end
    --     return stacks
    -- end,

    -- True when the player can receive every grant at once (weight and slots).
    -- grants = { { item = string, count = number, metadata = table|nil }, ... }
    -- CanCarry = function(src, grants)
    --     for _, grant in ipairs(grants) do
    --         if not exports['my_inventory']:CanCarryItem(src, grant.item, grant.count) then return false end
    --     end
    --     return true
    -- end,

    -- Optional: true/false when the item is registered, nil when unknown (the check is skipped).
    -- ItemExists = function(item)
    --     return exports['my_inventory']:GetItemData(item) ~= nil
    -- end,

    -- Optional: the metadata given to part items of a tier. Default { chopQuality = quality, description = description }.
    -- MakeMetadata = function(quality, description)
    --     return { chopQuality = quality, description = description }
    -- end,
}
