-- Inventory adapters ----------------------------------------------------------------
-- One adapter per inventory system, all with the same interface. The rest of the resource only
-- talks to `Inventory` (InventorySystem is resolved in shared/inventory.lua).
--
-- Interface (src = player server id):
--   Inventory.AddItem(src, item, count, metadata)    -> boolean
--       metadata: a table in this inventory's shape (Inventory.MakeMetadata, or a stack.metadata
--       read back from Inventory.GetStacks for a rollback), or nil.
--   Inventory.RemoveStack(src, item, count, stack)   -> boolean
--       Removes `count` from that exact stack (a GetStacks entry).
--   Inventory.GetCount(src, item)                    -> number
--   Inventory.GetStacks(src, item)                   -> { { slot, count, metadata, quality }, ... }
--       metadata is the raw item metadata (ox `metadata`, QB-family `info`), quality is our tier
--       quality read from it (string or nil). Sorted by slot.
--   Inventory.CanCarry(src, grants)                  -> boolean
--       grants = { { item, count, metadata }, ... }: true when everything fits at once.
--   Inventory.CanCarryItem(src, item, count)         -> boolean
--   Inventory.ItemExists(item)                       -> true | false | nil (nil = unknown, skip)
--   Inventory.MakeMetadata(quality, description)     -> table in this inventory's shape
--   Inventory.ExactStacks                            -> boolean
--       true when RemoveStack removes from the exact stack it is given (slot based) AND stacks of
--       the same item with different metadata never merge. When false, server/main.lua prices every
--       stack of an item at its lowest quality (see sellItem).
--   Inventory.ReliableAdd                            -> boolean
--       true when AddItem returning false really means nothing was given (verified from source).
--       When false a false result may hide a successful add, so removePart never re-opens a part
--       after it (re-opening could hand out the part twice).
--   Inventory.ItemResources                          -> resources whose (re)start re-runs the item check
--
-- removePart (server/main.lua) relies on CanCarry and the following AddItem calls not yielding.
-- ox_inventory, qb-inventory and ps-inventory exports are synchronous (verified from source).
-- qs-inventory, core_inventory and custom adapters depend on the vendor/owner code not yielding.

Inventory = {}

-- Our tier quality key. ox_inventory uses `quality` (unchanged, existing items keep working).
-- Every other inventory uses `chopQuality`: ps-inventory and qs-inventory use `info.quality` as a
-- NUMBER for durability, so a string `quality` there would collide.
-- Reassigned by setupInventory() when the inventory is (re)detected later.
local QUALITY_KEY = InventorySystem == 'ox_inventory' and 'quality' or 'chopQuality'

-- Reads our quality from item metadata: `chopQuality` first, then `quality` when it is a string
-- (ox items, or items created before switching inventory). Numeric durability is ignored.
local function readQuality(metadata)
    if type(metadata) ~= 'table' then return nil end
    if type(metadata.chopQuality) == 'string' then return metadata.chopQuality end
    if type(metadata.quality) == 'string' then return metadata.quality end
    return nil
end

local function defaultMakeMetadata(quality, description)
    if not quality then return nil end
    return { [QUALITY_KEY] = quality, description = description }
end

local function sortStacks(stacks)
    table.sort(stacks, function(a, b) return a.slot < b.slot end)
    return stacks
end

local warnedOnce = {}
local function warnOnce(key, message)
    if warnedOnce[key] then return end
    warnedOnce[key] = true
    print(('^3[nek_chopshop] %s^7'):format(message))
end

-- Runs `call` and checks the change with `getCount` before/after. Used where the export's return
-- value is UNVERIFIED: a success reported as nil would otherwise skip a payment or dupe items.
-- Falls back to the return value when the count cannot be read.
-- atLeast: accept a change of at least `expectedDelta` (adds: another script may add items to the
-- same player between the two reads, which must not turn a real success into a failure).
local function verifiedChange(getCount, expectedDelta, call, atLeast)
    local before = tonumber(getCount())
    local ret = call()
    local after = tonumber(getCount())
    if before and after then
        if atLeast then return after >= before + expectedDelta end
        return after - before == expectedDelta
    end
    return ret == true
end

-- Lazily resolved QBCore object (qb-inventory / ps-inventory item list and player data)
local function getQBCore()
    if QBCore then return QBCore end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and core then QBCore = core end
    return QBCore
end

local function qbItemDef(item)
    local core = getQBCore()
    local items = core and core.Shared and core.Shared.Items
    if type(items) ~= 'table' then return nil end
    return items[item]
end

-- Normalizes a QB-family/qs/core item entry into { slot, count, metadata, quality }.
-- Field names differ between vendors (amount/count, info/metadata): both are read.
-- item: the requested item name; an entry whose own `name` is present and differs is skipped.
-- requireSlot: skip entries without an explicit `slot` instead of using the list index (the index
-- is not a real slot in every inventory, and RemoveStack removes by slot).
local function normalizeEntry(data, index, item, requireSlot)
    if type(data) ~= 'table' then return nil end
    if data.name ~= nil and data.name ~= item then return nil end
    local count = tonumber(data.amount) or tonumber(data.count) or 0
    if count <= 0 then return nil end
    local explicitSlot = tonumber(data.slot)
    if requireSlot and not explicitSlot then return nil end
    local metadata = data.info or data.metadata
    return {
        slot = explicitSlot or index,
        count = count,
        metadata = metadata,
        quality = readQuality(metadata),
    }
end

-- Counts the new slots a list of grants needs. Conservative: every distinct stackable
-- (item, metadata) grant counts one new slot even if a matching stack already exists.
local function countNewSlots(grants, isUnique)
    local newSlots, seen = 0, {}
    for _, grant in ipairs(grants) do
        if isUnique(grant.item) then
            newSlots = newSlots + grant.count
        else
            local key = grant.item .. '\0' .. tostring(readQuality(grant.metadata))
            if not seen[key] then
                newSlots = newSlots + 1
                seen[key] = true
            end
        end
    end
    return newSlots
end

local adapters = {}

-- ox_inventory (verified from source, v2.48.1) ---------------------------------------
adapters['ox_inventory'] = function()
    local ox = exports.ox_inventory
    local A = { ExactStacks = true, ReliableAdd = true, ItemResources = { 'ox_inventory' } }

    function A.AddItem(src, item, count, metadata)
        return ox:AddItem(src, item, count, metadata)
    end

    -- Removes only from that slot (count must not exceed the slot count).
    function A.RemoveStack(src, item, count, stack)
        return ox:RemoveItem(src, item, count, nil, stack.slot)
    end

    function A.GetCount(src, item)
        return tonumber(ox:GetItemCount(src, item)) or 0
    end

    function A.GetStacks(src, item)
        local stacks = {}
        local slots = ox:Search(src, 'slots', item)
        if type(slots) ~= 'table' then return stacks end

        for _, data in pairs(slots) do
            local count = type(data) == 'table' and tonumber(data.count) or 0
            if count > 0 and data.slot then
                stacks[#stacks + 1] = {
                    slot = data.slot, count = count, metadata = data.metadata, quality = readQuality(data.metadata),
                }
            end
        end
        return sortStacks(stacks)
    end

    function A.CanCarryItem(src, item, count, metadata)
        return ox:CanCarryItem(src, item, count, metadata)
    end

    -- Each item has to fit (slots / stacking), the combined weight has to fit the free capacity and
    -- the new slots the whole list needs have to fit the empty slots. New slots: a non-stackable
    -- grant takes `count` slots; a stackable grant takes one slot unless the player already holds a
    -- stack with the same metadata, and grants of the same item with the same metadata table share
    -- that slot. Never yields.
    function A.CanCarry(src, grants)
        local weight, newSlots, emptySlots = 0, 0, nil
        local sharedStacks = {} -- [item .. metadata table] = true once a new stack slot was counted
        for _, grant in ipairs(grants) do
            if not ox:CanCarryItem(src, grant.item, grant.count, grant.metadata) then
                return false
            end
            local def = ox:Items(grant.item)
            if not def then return false end
            weight = weight + (tonumber(def.weight) or 0) * grant.count

            -- Strict metadata match, like AddItem's stacking (nil metadata is stored as an empty table)
            local slots, _, empty = ox:GetItemSlots(src, grant.item, grant.metadata or {}, true)
            if type(slots) ~= 'table' or not empty then return false end
            emptySlots = empty

            if def.stack == false then
                newSlots = newSlots + grant.count
            else
                local key = grant.item .. '\0' .. tostring(grant.metadata)
                if not next(slots) and not sharedStacks[key] then
                    newSlots = newSlots + 1
                end
                sharedStacks[key] = true
            end
        end
        if emptySlots and newSlots > emptySlots then return false end
        return ox:CanCarryWeight(src, weight) == true
    end

    function A.ItemExists(item)
        local ok, def = pcall(function() return ox:Items(item) end)
        return ok and def ~= nil
    end

    return A
end

-- qb-inventory (verified from source, v2.2.3; QBCore only) ---------------------------
-- Stacks by item name and probably ignores `info`, so quality tiers can merge: not ExactStacks
-- (selling prices every stack at the lowest quality held). AddItem returns a verified boolean.
adapters['qb-inventory'] = function()
    local A = { ExactStacks = false, ReliableAdd = true, ItemResources = { 'qb-inventory', 'qb-core' } }
    local function inv() return exports['qb-inventory'] end

    function A.AddItem(src, item, count, metadata)
        return inv():AddItem(src, item, count, false, metadata, 'nek_chopshop') == true
    end

    -- Without a slot qb-inventory only checks the first stack: always remove by slot.
    function A.RemoveStack(src, item, count, stack)
        return inv():RemoveItem(src, item, count, stack.slot, 'nek_chopshop') == true
    end

    function A.GetCount(src, item)
        return tonumber(inv():GetItemCount(src, item)) or 0
    end

    function A.GetStacks(src, item)
        local stacks = {}
        local items = inv():GetItemsByName(src, item)
        for index, data in pairs(type(items) == 'table' and items or {}) do
            local stack = normalizeEntry(data, index, item)
            if stack then stacks[#stacks + 1] = stack end
        end
        return sortStacks(stacks)
    end

    function A.CanCarryItem(src, item, count)
        return inv():CanAddItem(src, item, count) == true
    end

    -- CanAddItem per grant, then the combined weight (GetFreeWeight) and the new slots (GetSlots).
    function A.CanCarry(src, grants)
        local weight = 0
        for _, grant in ipairs(grants) do
            if inv():CanAddItem(src, grant.item, grant.count) ~= true then return false end
            local def = qbItemDef(grant.item)
            if not def then return false end
            weight = weight + (tonumber(def.weight) or 0) * grant.count
        end

        local freeWeight = tonumber(inv():GetFreeWeight(src))
        if not freeWeight or weight > freeWeight then return false end

        local _, freeSlots = inv():GetSlots(src)
        freeSlots = tonumber(freeSlots)
        if not freeSlots then return false end
        local newSlots = countNewSlots(grants, function(item)
            local def = qbItemDef(item)
            return def and def.unique == true
        end)
        return newSlots <= freeSlots
    end

    function A.ItemExists(item)
        local core = getQBCore()
        if not (core and core.Shared and type(core.Shared.Items) == 'table') then return nil end
        return core.Shared.Items[item] ~= nil
    end

    return A
end

-- ps-inventory (verified from source, archived; QBCore only) -------------------------
-- Like qb-inventory it probably stacks by item name ignoring `info`: not ExactStacks.
adapters['ps-inventory'] = function()
    local A = { ExactStacks = false, ReliableAdd = true, ItemResources = { 'ps-inventory', 'qb-core' } }
    local function inv() return exports['ps-inventory'] end

    -- ps forces info.quality = 100 (durability) when absent; our key is chopQuality, no collision.
    function A.AddItem(src, item, count, metadata)
        return inv():AddItem(src, item, count, nil, metadata, 'nek_chopshop') == true
    end

    -- Single stack only: always remove by slot.
    function A.RemoveStack(src, item, count, stack)
        return inv():RemoveItem(src, item, count, stack.slot) == true
    end

    function A.GetStacks(src, item)
        local stacks = {}
        local items = inv():GetItemsByName(src, item)
        for index, data in pairs(type(items) == 'table' and items or {}) do
            local stack = normalizeEntry(data, index, item)
            if stack then stacks[#stacks + 1] = stack end
        end
        return sortStacks(stacks)
    end

    -- No GetItemCount export: sum of the stacks.
    function A.GetCount(src, item)
        local total = 0
        for _, stack in ipairs(A.GetStacks(src, item)) do total = total + stack.count end
        return total
    end

    -- No CanAddItem export: best effort from the player's items and the QBCore player limits.
    -- UNVERIFIED: ps-inventory may use its own Config.MaxInventoryWeight / MaxInventorySlots instead
    -- of QBCore.Config.Player.*. When a value is missing this allows the grant (AddItem itself still
    -- refuses items that do not fit) and prints a one-time console note.
    -- ps-inventory may stack an add onto an existing stack by item name, so how many slots an add
    -- needs is unknown: every grant conservatively counts as new slot(s).
    function A.CanCarry(src, grants)
        local core = getQBCore()
        local player = core and core.Functions and core.Functions.GetPlayer(src)
        local limits = core and core.Config and core.Config.Player
        local maxWeight = limits and tonumber(limits.MaxWeight)
        local maxSlots = limits and tonumber(limits.MaxInvSlots)
        if not player or not maxWeight or not maxSlots then
            warnOnce('ps_cancarry', 'ps-inventory: could not read the player weight/slot limits; inventory space is only checked by AddItem.')
            return true
        end

        local usedWeight, usedSlots = 0, 0
        for _, data in pairs(player.PlayerData.items or {}) do
            if type(data) == 'table' then
                usedSlots = usedSlots + 1
                usedWeight = usedWeight + (tonumber(data.weight) or 0) * (tonumber(data.amount) or 0)
            end
        end

        local weight, newSlots = 0, 0
        for _, grant in ipairs(grants) do
            local def = qbItemDef(grant.item)
            if not def then return false end
            weight = weight + (tonumber(def.weight) or 0) * grant.count
            newSlots = newSlots + (def.unique and grant.count or 1)
        end
        return usedWeight + weight <= maxWeight and usedSlots + newSlots <= maxSlots
    end

    function A.CanCarryItem(src, item, count)
        return A.CanCarry(src, { { item = item, count = count } })
    end

    function A.ItemExists(item)
        local core = getQBCore()
        if not (core and core.Shared and type(core.Shared.Items) == 'table') then return nil end
        return core.Shared.Items[item] ~= nil
    end

    return A
end

-- qs-inventory (from the vendor docs only; return values/fields partly UNVERIFIED) -----
-- Not ExactStacks: stacking by metadata is unverified, so quality tiers may merge.
-- Not ReliableAdd: a refusal and a missing return value look the same.
adapters['qs-inventory'] = function()
    local A = { ExactStacks = false, ReliableAdd = false, ItemResources = { 'qs-inventory' } }
    local function inv() return exports['qs-inventory'] end

    function A.GetCount(src, item)
        return tonumber(inv():GetItemTotalAmount(src, item)) or 0
    end

    -- A refusal returns nothing, so only an explicit true is a success.
    function A.AddItem(src, item, count, metadata)
        return inv():AddItem(src, item, count, nil, metadata) == true
    end

    -- UNVERIFIED return value: the result is checked by the item count before/after instead.
    function A.RemoveStack(src, item, count, stack)
        return verifiedChange(function() return A.GetCount(src, item) end, -count, function()
            return inv():RemoveItem(src, item, count, stack.slot)
        end)
    end

    -- UNVERIFIED field names: amount/count and info/metadata are both read. Entries without an
    -- explicit slot are skipped: RemoveStack removes by slot and a list index is not a slot.
    function A.GetStacks(src, item)
        local stacks = {}
        local items = inv():GetItemsByName(src, item)
        for index, data in pairs(type(items) == 'table' and items or {}) do
            local stack = normalizeEntry(data, index, item, true)
            if stack then stacks[#stacks + 1] = stack end
        end
        return sortStacks(stacks)
    end

    -- CanCarryItems checks the whole list at once (weight and slots); metadata is not considered.
    function A.CanCarry(src, grants)
        local list = {}
        for _, grant in ipairs(grants) do
            list[#list + 1] = { name = grant.item, amount = grant.count }
        end
        local fits = inv():CanCarryItems(src, list)
        return fits == true
    end

    function A.CanCarryItem(src, item, count)
        return A.CanCarry(src, { { item = item, count = count } })
    end

    -- UNVERIFIED shape of GetItemList: keyed by name, or a list of { name = ... }.
    function A.ItemExists(item)
        local ok, list = pcall(function() return inv():GetItemList() end)
        if not ok or type(list) ~= 'table' then return nil end
        if list[item] ~= nil then return true end
        for _, def in pairs(list) do
            if type(def) == 'table' and def.name == item then return true end
        end
        return false
    end

    return A
end

-- core_inventory (from the vendor docs only; partly UNVERIFIED) ----------------------
-- removeItem has no slot/metadata parameter and takes from the first matching slot, so this
-- adapter is not ExactStacks: selling prices every stack of an item at its lowest quality.
adapters['core_inventory'] = function()
    local A = { ExactStacks = false, ReliableAdd = false, ItemResources = { 'core_inventory' } }
    local function inv() return exports.core_inventory end

    function A.GetCount(src, item)
        return tonumber(inv():getItemCount(src, item)) or 0
    end

    -- UNVERIFIED return value: checked by the item count before/after.
    function A.AddItem(src, item, count, metadata)
        return verifiedChange(function() return A.GetCount(src, item) end, count, function()
            return inv():addItem(src, item, count, metadata)
        end, true)
    end

    -- Removes `count` of the item by name (first matching slot); the stack is only used for the count
    -- and to give back a partial removal (UNVERIFIED whether removeItem can remove less than asked).
    function A.RemoveStack(src, item, count, stack)
        local before = A.GetCount(src, item)
        inv():removeItem(src, item, count)
        local removed = before - A.GetCount(src, item)
        if removed == count then return true end
        if removed > 0 and removed < count then
            inv():addItem(src, item, removed, stack and stack.metadata)
        end
        return false -- fail closed: nothing is paid
    end

    -- UNVERIFIED field names of getItems: amount/count and metadata/info are both read.
    function A.GetStacks(src, item)
        local stacks = {}
        local items = inv():getItems(src, item)
        for index, data in pairs(type(items) == 'table' and items or {}) do
            local stack = normalizeEntry(data, index, item)
            if stack then stacks[#stacks + 1] = stack end
        end
        return sortStacks(stacks)
    end

    -- canCarry only checks one item at a time: grants of the same item are added up, but the
    -- combined weight of different items is not checked (AddItem still refuses what does not fit).
    function A.CanCarry(src, grants)
        local totals, order = {}, {}
        for _, grant in ipairs(grants) do
            if not totals[grant.item] then
                order[#order + 1] = grant.item
                totals[grant.item] = { count = 0, metadata = grant.metadata }
            end
            totals[grant.item].count = totals[grant.item].count + grant.count
        end
        for _, item in ipairs(order) do
            if inv():canCarry(src, item, totals[item].count, totals[item].metadata) ~= true then return false end
        end
        return true
    end

    function A.CanCarryItem(src, item, count)
        return A.CanCarry(src, { { item = item, count = count } })
    end

    -- No documented item list export: unknown, the item check is skipped.
    function A.ItemExists()
        return nil
    end

    return A
end

-- custom (Editable.Inventory in editable/server.lua) ----------------------------------
adapters['custom'] = function()
    local E = Editable.Inventory or {}
    local A = {
        ExactStacks = E.ExactStacks == true,
        ReliableAdd = false, -- the owner's AddItem is not verified: a false result never re-opens a part
        ItemResources = type(E.ItemResources) == 'table' and E.ItemResources or {},
    }

    local function missing(name)
        warnOnce('custom_' .. name, ('Config.Inventory = \'custom\' but Editable.Inventory.%s is not defined (editable/server.lua).'):format(name))
    end

    function A.AddItem(src, item, count, metadata)
        if not E.AddItem then missing('AddItem') return false end
        -- Any truthy return counts as success (owners return true, a count, a slot table, ...)
        return E.AddItem(src, item, count, metadata) and true or false
    end

    function A.RemoveStack(src, item, count, stack)
        if not E.RemoveStack then missing('RemoveStack') return false end
        return E.RemoveStack(src, item, count, stack) == true
    end

    function A.GetCount(src, item)
        if not E.GetCount then missing('GetCount') return 0 end
        return tonumber(E.GetCount(src, item)) or 0
    end

    function A.GetStacks(src, item)
        if not E.GetStacks then missing('GetStacks') return {} end
        local stacks = {}
        for index, data in pairs(E.GetStacks(src, item) or {}) do
            if type(data) == 'table' then
                local count = tonumber(data.count) or 0
                if count > 0 then
                    stacks[#stacks + 1] = {
                        slot = tonumber(data.slot) or index,
                        count = count,
                        metadata = data.metadata,
                        quality = readQuality(data.metadata),
                    }
                end
            end
        end
        return sortStacks(stacks)
    end

    function A.CanCarry(src, grants)
        if not E.CanCarry then missing('CanCarry') return false end
        return E.CanCarry(src, grants) == true
    end

    function A.CanCarryItem(src, item, count)
        return A.CanCarry(src, { { item = item, count = count } })
    end

    function A.ItemExists(item)
        if not E.ItemExists then return nil end
        return E.ItemExists(item)
    end

    function A.MakeMetadata(quality, description)
        if not quality then return nil end
        if E.MakeMetadata then return E.MakeMetadata(quality, description) end
        return { chopQuality = quality, description = description }
    end

    return A
end

-- Setup -------------------------------------------------------------------------------

-- Fills the shared `Inventory` table for the current InventorySystem. Runs at load time and again
-- when shared/inventory.lua detects an inventory that started after this resource (the table is
-- cleared and refilled in place, so every reference to `Inventory` stays valid).
local function setupInventory()
    for key in pairs(Inventory) do Inventory[key] = nil end
    QUALITY_KEY = InventorySystem == 'ox_inventory' and 'quality' or 'chopQuality'

    local factory = InventorySystem and adapters[InventorySystem]
    if factory then
        for key, value in pairs(factory()) do Inventory[key] = value end
        Inventory.MakeMetadata = Inventory.MakeMetadata or defaultMakeMetadata
        return
    end

    -- No inventory: every call fails closed (nothing given, nothing sold, nothing removed)
    Inventory.ExactStacks = true
    Inventory.ReliableAdd = false
    Inventory.ItemResources = {}
    function Inventory.AddItem() return false end
    function Inventory.RemoveStack() return false end
    function Inventory.GetCount() return 0 end
    function Inventory.GetStacks() return {} end
    function Inventory.CanCarry() return false end
    function Inventory.CanCarryItem() return false end
    function Inventory.ItemExists() return nil end
    Inventory.MakeMetadata = defaultMakeMetadata
end

setupInventory()

-- Called by shared/inventory.lua once a late-started inventory was detected.
function OnInventoryResolved()
    setupInventory()
    TriggerEvent('nek_chopshop:inventoryResolved')
end
