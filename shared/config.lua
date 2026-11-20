Config = {}

Config.Version = '2.0.0'

-- Framework configuration
-- type: string
-- options: 'esx', 'qbcore', 'qbox' or 'auto' (detects qbx_core > es_extended > qb-core)
Config.Framework = 'auto'

-- Inventory system
-- type: string
-- options: 'auto', 'ox_inventory', 'qs-inventory', 'core_inventory', 'ps-inventory', 'qb-inventory' or
-- 'custom' (fill Editable.Inventory in editable/server.lua).
-- 'auto' detects ox_inventory > qs-inventory > core_inventory > ps-inventory > qb-inventory.
-- A forced inventory that is not started falls back to auto-detection.
Config.Inventory = 'auto'

-- Items that allow lockpicking the job vehicle (any one of them is enough)
-- type: table
-- ESX usually uses 'advanced_lockpick', QBCore/Qbox use 'advancedlockpick'
Config.LockpickItems = { 'lockpick', 'advancedlockpick', 'advanced_lockpick' }

-- Enable/Disable debug mode for print statements
-- type: boolean
Config.Debug = false

-- NPC Ped Configuration
-- type: table
Config.Ped = {
    -- Model name of the ped
    -- type: string
    Model = 's_m_y_dealer_01',

    -- Coordinates for the ped spawn
    -- type: vector4
    Coords = vector4(2339.8943, 3146.3787, 48.2045, 86.2756),

    -- Animation scenario for the ped
    -- type: string
    Scenario = 'WORLD_HUMAN_STAND_IMPATIENT',

    -- Interaction options (ox_target)
    -- type: table
    Target = {
        options = {
            {
                icon = 'fas fa-car',
                label = 'request_job', -- locale key (locales/*.json); a literal text also works
            },
        },
        distance = 2.0,
    },

    -- Blip Configuration
    -- type: table
    Blip = {
        Enable = true,
        Sprite = 227,
        Color = 5,
        Scale = 0.8,
        Label = 'blip_chopshop', -- locale key; a literal text also works
    }
}

-- Sell NPC Configuration
-- type: table
Config.SellPed = {
    Enable = true,
    Model = 'g_m_m_armboss_01',
    Coords = vector4(-267.0674, -1920.6383, 27.7734, 100.0090), -- Example coords, adjust as needed or use existing nearby
    Scenario = 'WORLD_HUMAN_SMOKING',

    -- label: locale key (locales/*.json) or a literal text
    Items = {
        { item = 'vehicle_door',   price = 45, label = 'item_vehicle_door' },
        { item = 'vehicle_hood',   price = 55, label = 'item_vehicle_hood' },
        { item = 'veh_wheels',     price = 30, label = 'item_veh_wheels' },
        { item = 'car-battery',    price = 60, label = 'item_car_battery' },
        { item = 'veh_suspension', price = 70, label = 'item_veh_suspension' },
        { item = 'vehicle_trunk',  price = 65, label = 'item_vehicle_trunk' },
        { item = 'vehicle_engine', price = 120, label = 'item_vehicle_engine' },
        { item = 'vehicle_seat',   price = 40, label = 'item_vehicle_seat' },
        -- Loot-only items (Config.Tiers[].loot)
        { item = 'scrap_metal',    price = 10, label = 'item_scrap_metal' },
        { item = 'sport_wheel',    price = 90, label = 'item_sport_wheel' },
        { item = 'turbo_kit',      price = 250, label = 'item_turbo_kit' },
    },

    -- Price multiplier by the item's `quality` metadata (set by the vehicle tier, see Config.Tiers).
    -- Items without quality metadata, or with an unknown one, are paid as 'standard'.
    QualityMultiplier = {
        standard = 1.0,
        premium  = 1.5,
        exotic   = 2.5,
    },

    Blip = {
        Enable = false,
        Sprite = 500,
        Color = 46,
        Scale = 0.6,
        Label = 'blip_sell', -- locale key; a literal text also works
    }
}



-- Discord Webhook Configuration
-- type: table
Config.Discord = {
    -- Webhook moved to editable/server.lua

    -- Username for the webhook bot
    -- type: string
    Username  = "Nekix ChopShop",

    -- Avatar URL for the webhook bot
    -- type: string
    AvatarUrl = "",

    -- Embed colors for different log types (Decimal color codes)
    -- type: table
    Color     = {
        item     = 65280,    -- Green
        pay      = 15105570, -- Orange
        finished = 3447003,  -- Blue
        warn     = 16761858, -- Red
        rep      = 10181046, -- Purple
    }
}

-- Logging Configuration
-- type: table
Config.Logs = {
    EnableItem   = true,  -- Log when an item is received
    EnablePay    = true,  -- Log when payment is made
    EnableFinish = true,  -- Log when job is finished
    EnableWarn   = true,  -- Log suspicious (possibly exploited) requests
    EnableReputation = true, -- Log reputation level ups and AddReputation export calls
    Compact      = false, -- Use compact logging format
}

-- Payment Configuration
-- type: table
Config.Payment = {
    Enable = false, -- Enable monetary rewards
    Min = 100,      -- Minimum amount per job
    Max = 200       -- Maximum amount per job
}

-- Job Cooldown
-- type: number (seconds)
-- Default: 1 hour
Config.Cooldown = 60 * 60

-- Use the custom NUI (job board, job tracker, parts buyer).
-- false falls back to the ox_lib menus/notifications only.
-- type: boolean
Config.UseNUI = true

-- Language
-- Texts live in locales/<lang>.json and are loaded with ox_lib's locale module.
-- The language is the ox_lib one: add `setr ox:locale "es"` to server.cfg.
-- Missing keys fall back to English. See the "Languages" section of the README.
-- Do not edit this block; to translate, copy locales/en.json to locales/<code>.json.
ChopLocale = { lang = 'en' }

---Loads the locale files of this resource. Falls back to 'en' when there is no file for the language.
---@param requested? string language code, defaults to the ox_lib language
---@return string lang the language that was actually loaded
function LoadChopLocale(requested)
    local lang = requested or lib.getLocaleKey() or 'en'
    if not LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang)) then
        lang = 'en'
    end
    lib.locale(lang)
    ChopLocale.lang = lang
    return lang
end

LoadChopLocale()

Config.Coords = {
    Spawns = {
        vector4(-706.47, -131.07, 37.26, 118.67),
        vector4(-1082.87, -1670.45, 4.29, 124.47),
        vector4(-1090.35, -1633.11, 4.29, 307.13),
        vector4(-1124.22, -1613.0, 3.98, 125.63),
        vector4(-1106.61, -1601.65, 4.25, 305.71),
        vector4(-1202.99, -1488.59, 3.94, 304.28),
        vector4(-1812.35, -636.32, 10.52, 140.66),
        vector4(-1872.06, -584.69, 11.39, 139.56),
        vector4(-2077.61, -312.65, 12.71, 263.52),
        vector4(-1603.78, -363.77, 45.21, 51.14),
        vector4(-1614.72, 18.08, 61.76, 152.05),
        vector4(-1550.2, 132.71, 56.36, 224.51),
        vector4(-1547.53, 105.76, 56.36, 47.23),
        vector4(-1532.31, 82.31, 56.33, 317.17),
        vector4(-1404.92, 67.2, 52.6, 55.78),
        vector4(-1360.33, -144.2, 48.24, 77.37),
        vector4(-1324.7, -236.32, 42.27, 125.7),
        vector4(-1304.75, -222.14, 51.13, 124.09),
        vector4(-1219.37, -196.26, 38.76, 333.91),
        vector4(-339.21, -2183.61, 9.68, 91.34),
        vector4(-307.49, -2221.7, 8.12, 139.67),
        vector4(-231.05, -2080.22, 27.2, 36.68),
        vector4(-691.64, -2146.98, 5.57, 2.23),
        vector4(-755.13, -2291.12, 12.44, 46.22),
        vector4(-917.12, -2295.1, 6.29, 239.17),
        vector4(-888.84, -2102.83, 8.44, 136.98),
        vector4(-1022.53, -2201.99, 8.56, 223.01),
        vector4(-1077.56, -2178.01, 12.86, 224.27),
        vector4(-1035.82, -1339.41, 5.05, 253.87),
        vector4(-1011.21, -1469.25, 4.58, 213.76),
        vector4(1158.32, -1314.84, 34.32, 176.94),
        vector4(1500.61, -1886.03, 71.52, 118.25),
        vector4(1594.13, -1700.89, 87.7, 298.82),
        vector4(1632.71, -1880.96, 105.81, 337.65),
        vector4(1517.62, -2099.7, 76.41, 93.02),
        vector4(1563.15, -2169.39, 77.1, 159.93),
        vector4(1482.33, -1918.14, 70.97, 29.42),
        vector4(2535.67, -286.52, 92.57, 161.19),
        vector4(2434.37, -371.34, 92.57, 89.28),
        vector4(2507.08, -451.5, 92.57, 226.32),
        vector4(2552.11, -361.94, 92.57, 15.05),
        vector4(2567.55, 327.94, 108.03, 177.95),
        vector4(2588.15, 443.59, 108.04, 270.38),
        vector4(2480.57, 1571.31, 32.3, 178.47),
        vector4(2469.41, 1599.22, 32.3, 178.04),
        vector4(2659.74, 1667.49, 24.07, 89.03),
        vector4(2673.19, 1700.75, 24.07, 269.93),
        vector4(2725.24, 1346.81, 24.1, 177.78),
        vector4(2541.53, 2610.5, 37.24, 200.44),
        vector4(2540.84, 2589.43, 37.24, 269.23),
        vector4(2757.73, 2807.77, 32.8, 298.72),
        vector4(2952.91, 2735.99, 43.72, 104.83),
        vector4(2559.73, 2736.77, 42.5, 138.67),
        vector4(2591.51, 3159.72, 50.11, 318.46),
        vector4(2659.38, 3262.35, 54.54, 331.25),
        vector4(2633.09, 3301.05, 54.58, 329.36),
        vector4(2677.16, 3511.78, 52.01, 337.19),
        vector4(2711.77, 4129.6, 43.21, 350.66),
        vector4(2636.29, 4246.26, 44.1, 135.45),
        vector4(2506.11, 4214.01, 39.22, 148.16),
        vector4(2475.23, 3731.42, 41.68, 59.2),
        vector4(1776.57, 3641.7, 33.8, 121.91),
        vector4(899.77, 3653.07, 32.06, 270.63),
        vector4(12.17, 3683.04, 38.98, 113.12),
        vector4(758.18, 4179.39, 39.95, 188.1),
        vector4(1366.12, 4385.86, 43.64, 1.87),
        vector4(1354.47, 4353.7, 43.12, 171.9),
        vector4(1302.63, 4321.89, 37.55, 30.67),
        vector4(1733.83, 4634.99, 42.61, 296.78),
        vector4(1682.99, 4681.58, 42.35, 84.37),
        vector4(-2221.22, 3483.31, 29.47, 359.06),
        vector4(-2011.53, 3383.67, 30.55, 217.12),
        vector4(-441.7, 6341.64, 12.02, 218.33),
        vector4(-480.55, 6259.73, 12.4, 247.54),
        vector4(-695.33, 5814.08, 16.63, 245.39),
        vector4(-697.13, 5780.92, 16.92, 334.93),
        vector4(-771.45, 5572.5, 33.08, 268.54),
        vector4(-755.89, 5548.43, 33.07, 357.57),
        vector4(-804.78, 5391.31, 34.11, 182.59),
        vector4(-570.61, 5243.36, 70.06, 286.7),
        vector4(-266.62, 6354.37, 32.05, 225.48),
        vector4(-406.37, 6227.41, 30.81, 359.08),
        vector4(-411.95, 6172.73, 31.04, 353.84),
        vector4(1.07, 6525.88, 30.85, 315.1),
        vector4(-3233.87, 959.58, 12.47, 187.61),
        vector4(-3054.76, 605.55, 6.54, 109.15),
        vector4(-3054.65, 445.78, 5.66, 65.47),
        vector4(-2964.33, 58.07, 10.9, 332.23),
        vector4(-1562.41, -245.93, 47.58, 53.7),
        vector4(-1543.11, -419.49, 41.29, 229.57),
        vector4(-1535.19, -434.87, 34.74, 229.42),
        vector4(-1448.26, -675.07, 25.76, 32.99),
        vector4(-1231.49, -1027.32, 7.56, 23.66),
        vector4(-1157.43, -1176.19, 4.92, 286.6),
        vector4(-962.38, -1101.85, 1.45, 211.81),
        vector4(-702.62, -1139.05, 9.91, 216.02),
        vector4(-797.71, -1293.01, 4.3, 349.57),
        vector4(-619.52, -1604.56, 26.05, 175.22),
        vector4(1095.92, -2239.8, 29.61, 85.4),
        vector4(1003.37, -2308.6, 29.81, 268.48),
        vector4(1368.82, -2082.78, 51.29, 219.02),
        vector4(1442.17, -1686.58, 65.02, 33.91),
        vector4(1250.68, -1751.99, 46.19, 120.16),
        vector4(1166.58, -1559.95, 33.99, 88.31),
        vector4(1189.04, -1554.63, 38.7, 359.84),
        vector4(217.49, -36.47, 68.92, 159.7),
        vector4(60.58, 17.66, 68.54, 160.27),
        vector4(55.53, -45.43, 68.69, 338.26),
        vector4(0.73, -56.13, 62.58, 69.02),
        vector4(-355.81, 32.82, 47.1, 258.97),
        vector4(-467.39, 74.27, 57.96, 319.1),
        vector4(-1133.33, 2696.56, 18.1, 310.02),
        vector4(-594.89, 2120.72, 127.55, 146.82),
        vector4(-261.74, 1820.88, 197.9, 292.86),
        vector4(-417.51, 1215.44, 324.94, 50.6),
        vector4(-426.38, 1587.72, 355.77, 331.06),
        vector4(-2787.2, 1430.65, 100.22, 235.64),
        vector4(466.56, 2615.48, 42.49, 102.58),
        vector4(569.07, 2588.41, 42.11, 284.11),
        vector4(524.12, 3094.45, 39.76, 65.57),
        vector4(313.95, 2823.19, 42.73, 26.02)
    },
    Scrap = {
        {
            name = 'Plane Cemetery',
            coords = vec4(2349.5747, 3133.9958, 48.2086, 256.8773),
        },
        {
            name = 'Plane Cemetery 2',
            coords = vec4(2350.6243, 3130.4763, 48.2088, 258.5771)
        }
    }
}

-- Vehicle tiers. The server picks a tier by weight among the tiers the player qualifies for,
-- then a random model inside it (GetVehicleClass is client-only, so tiers are defined here).
-- label     : locale key (locales/*.json) or a literal text, shown when the job starts
-- weight    : relative chance of the tier among the eligible ones
-- minLevel  : chop shop reputation level needed (Config.Reputation.Levels; ignored when the reputation is disabled)
-- minPolice : optional, officers on duty needed for this tier; Config.Police.MinOnDuty still applies
--             to every job, so the effective requirement is the higher of the two
-- payout    : multiplier for the final payment (Config.Payment)
-- quality   : ox_inventory metadata `quality` given to the part items of this tier; the sell ped pays
--             Config.SellPed.QualityMultiplier[quality] times the base price
-- loot      : extra server-side rolls for every removed part:
--             { item, chance (0-100), min, max, parts = optional list of bones it applies to,
--               quality = true to give it with the tier quality metadata }
-- A server config that still defines the old flat `Config.Vehicles` list (and no Config.Tiers) keeps
-- working: it is treated as a single 'low' tier.
local WHEELS = { 'wheel_lf', 'wheel_lr', 'wheel_rr', 'wheel_rf' }

Config.Tiers = {
    low = {
        label = 'tier_low',
        weight = 60,
        minLevel = 0,
        payout = 1.0,
        quality = 'standard',
        models = {
            'emperor', 'manana', 'tornado', 'primo2', 'stanier', 'washington', 'glendale2', 'asterope',
            'stratum', 'futo', 'moonbeam', 'phoenix', 'tulip', 'vigero', 'dukes', 'hustler', 'weevil',
            'yosemite', 'winky', 'kalahari', 'landstalker', 'seminole2', 'granger', 'sandking', 'patriot',
        },
        loot = {
            { item = 'scrap_metal', chance = 50, min = 1, max = 3 },
        },
    },
    mid = {
        label = 'tier_mid',
        weight = 30,
        minLevel = 2,
        payout = 1.5,
        quality = 'premium',
        models = {
            'sultanrs', 'buffalo2', 'schafter3', 'felon', 'cogcabrio', 'f620', 'windsor', 'stafford',
            'deviant', 'dominator3', 'ellie', 'nightshade', 'sabregt', 'tailgater', 'penumbra', 'sugoi',
            'everon', 'caracara2', 'dubsta3', 'lurcher', 'pigalle', 'zion3', 'previon', 'sentinel',
        },
        loot = {
            { item = 'scrap_metal', chance = 40, min = 1, max = 2 },
            { item = 'sport_wheel', chance = 25, min = 1, max = 1, parts = WHEELS, quality = true },
        },
    },
    high = {
        label = 'tier_high',
        weight = 10,
        minLevel = 4,
        minPolice = 3,
        payout = 2.5,
        quality = 'exotic',
        models = {
            'banshee', 'seven70', 'bestiagts', 'carbonizzare', 'coquette2', 'rapidgt', 'ninef',
            'jester', 'comet4', 'feltzer2', 'superd', 'mamba', 'casco', 'vstr',
        },
        loot = {
            { item = 'scrap_metal', chance = 30, min = 1, max = 2 },
            { item = 'sport_wheel', chance = 50, min = 1, max = 1, parts = WHEELS, quality = true },
            { item = 'turbo_kit',   chance = 35, min = 1, max = 1, parts = { 'engine' }, quality = true },
        },
    },
}

-- Chop shop reputation, saved per character in the oxmysql table `nek_chopshop_reputation`
-- (created automatically on start). XP is only given or taken by the server when a job ends.
-- type: table
Config.Reputation = {
    -- false: no XP is earned, no perks apply, the job board hides the reputation block and
    -- every tier is available regardless of its minLevel.
    -- type: boolean
    Enabled = true,

    -- XP earned and lost. type: table (integers)
    XP = {
        Base             = 20,  -- owner, for every finished job
        PerPart          = 5,   -- owner, for every part removed in the finished job
        TimeBonusMax     = 15,  -- owner, scaled by the fraction of the scrap time limit left (all of it = full bonus)
        PartnerShare     = 0.5, -- the partner gets this share (0-1) of the owner's XP for the job
        PenaltyExpired   = 10,  -- owner loses this when the job runs out of time (Config.TimeLimit)
        PenaltyAbandoned = 15,  -- owner loses this when they leave the server with an active job
    },

    -- Levels, from level 0 upward: the level number is the position in this list minus one
    -- (first entry = level 0, which must start at xp = 0). Config.Tiers[].minLevel refers to these numbers.
    -- xp    : total XP needed to reach the level
    -- perks : what the level gives (not cumulative: each level lists its own values)
    --   sellMultiplier     : multiplies the sell ped price (on top of the quality multiplier), 1.0 = no bonus
    --   cooldownMultiplier : multiplies Config.Cooldown after taking a job (0-1), 1.0 = full wait
    --   extraPartChance    : chance (0-100) of one extra copy of each removed part
    -- Vehicle tiers unlock through Config.Tiers[].minLevel (low 0, mid 2, high 4).
    -- type: table
    Levels = {
        { xp = 0,    perks = { sellMultiplier = 1.00, cooldownMultiplier = 1.00, extraPartChance = 0 } },  -- level 0
        { xp = 100,  perks = { sellMultiplier = 1.05, cooldownMultiplier = 1.00, extraPartChance = 0 } },  -- level 1
        { xp = 300,  perks = { sellMultiplier = 1.05, cooldownMultiplier = 0.90, extraPartChance = 5 } },  -- level 2: mid tier
        { xp = 600,  perks = { sellMultiplier = 1.10, cooldownMultiplier = 0.85, extraPartChance = 5 } },  -- level 3
        { xp = 1000, perks = { sellMultiplier = 1.15, cooldownMultiplier = 0.80, extraPartChance = 10 } }, -- level 4: high tier
        { xp = 1600, perks = { sellMultiplier = 1.20, cooldownMultiplier = 0.75, extraPartChance = 15 } }, -- level 5
    },

    -- Weekly loss of XP without finished jobs. Applied when the reputation is read (no timer):
    -- every full week since the last finished job removes PerWeek XP. Off by default.
    -- type: table
    Decay = {
        Enabled = false, -- type: boolean
        PerWeek = 50,    -- type: integer, XP lost per full week without activity
    },
}

-- Parts that can be removed from the job vehicle.
-- The server only rewards parts listed here, so this table is the reward whitelist.
-- label: key in locales/*.json | part: door index / wheel index | bonus: extra items given with the part
-- optional: the part is only part of the job if the vehicle model has that bone (the client reports the bones,
--           the server only accepts bones listed here). Only the 4 wheels are mandatory (every automobile has
--           them); everything else is optional so a model lacking a bone can never leave the job unfinishable.
--           Trade-off: a cheater can at most claim the configured optional parts once per job, which is
--           bounded by the job cooldown (Config.Cooldown).
-- requires: bone of another part that has to be removed first (e.g. the seats need their door removed).
--           Enforced on the server; the client only hides the target. If the required part is not part of
--           this job (the model lacks that bone) the requirement counts as satisfied.
-- anim: 'repair' plays the under-hood repair animation, otherwise the mechanic animation is used.
-- No door/wheel flag (engine, seats): nothing is removed visually, the player only gets the item.
Config.ChopParts = {
    { bone = 'door_dside_f',  part = 0, item = 'vehicle_door',   label = 'door_lf',  isDoor = true, optional = true },
    { bone = 'door_dside_r',  part = 2, item = 'vehicle_door',   label = 'door_lr',  isDoor = true, optional = true },
    { bone = 'door_pside_r',  part = 3, item = 'vehicle_door',   label = 'door_rr',  isDoor = true, optional = true },
    { bone = 'door_pside_f',  part = 1, item = 'vehicle_door',   label = 'door_rf',  isDoor = true, optional = true },
    { bone = 'bonnet',        part = 4, item = 'vehicle_hood',   label = 'hood',     isDoor = true, optional = true, anim = 'repair', bonus = { 'car-battery' } },
    { bone = 'boot',          part = 5, item = 'vehicle_trunk',  label = 'trunk',    isDoor = true, optional = true },
    { bone = 'engine',                  item = 'vehicle_engine', label = 'engine',   optional = true, requires = 'bonnet', anim = 'repair' },
    { bone = 'seat_dside_f',            item = 'vehicle_seat',   label = 'seat_lf',  optional = true, requires = 'door_dside_f' },
    { bone = 'seat_pside_f',            item = 'vehicle_seat',   label = 'seat_rf',  optional = true, requires = 'door_pside_f' },
    { bone = 'wheel_lf',      part = 0, item = 'veh_wheels',     label = 'wheel_lf', isWheel = true },
    { bone = 'wheel_lr',      part = 2, item = 'veh_wheels',     label = 'wheel_lr', isWheel = true },
    { bone = 'wheel_rr',      part = 3, item = 'veh_wheels',     label = 'wheel_rr', isWheel = true },
    { bone = 'wheel_rf',      part = 1, item = 'veh_wheels',     label = 'wheel_rf', isWheel = true },
}

-- Item given to the job owner once every part has been removed
-- type: string | false
Config.FinishReward = 'veh_suspension'

-- Server-side anti-exploit thresholds (distances in meters, times in milliseconds)
-- type: table
Config.Security = {
    PedDistance      = 10.0, -- max distance to the job ped to request a job
    SellDistance     = 10.0, -- max distance to the sell ped to sell parts
    ScrapDistance    = 15.0, -- max distance from the vehicle to the scrap point to start scrapping
    PartDistance     = 6.0,  -- max distance from the player to the vehicle to remove a part
    PartnerDistance  = 20.0, -- max distance between owner and partner when assigning
    PartInterval     = 2000, -- min time between two part removals by the same player
    SpawnClearRadius = 3.0,  -- spawn point is skipped if a vehicle is within this radius
    MaxAverageSpeed  = 60.0, -- m/s (~216 km/h); faster spawn->scrap deliveries are treated as teleports
    WarnThrottle     = 30,   -- seconds between suspicious-request logs for the same player
    DispatchDistance = 10.0, -- max distance from the player to the job vehicle when the police alert is sent
}

-- Police requirement and dispatch alert
-- type: table
Config.Police = {
    -- Minimum police officers on duty to hand out a job. 0 disables the requirement.
    -- type: number
    MinOnDuty = 0,

    -- QBCore/Qbox: job type counted as police (players whose job.type matches and are on duty).
    -- Set to false to count by the job names in `Jobs` instead.
    -- type: string | false
    JobType = 'leo',

    -- Police job names. Used by ESX to count officers (job.onDuty ~= false) and by the dispatch
    -- scripts that address alerts by job name.
    -- type: table
    Jobs = { 'police', 'sheriff' },

    -- Alert sent once per job, when the vehicle is lockpicked
    -- type: table
    Dispatch = {
        -- 'auto'   : first started script of the supported list (see README, "Police & dispatch")
        -- name     : force one: 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'rcore_dispatch', 'core_dispatch',
        --            'tk_dispatch', 'origen_police', 'lb-tablet', 'linden_outlawalert'
        -- 'custom' : calls Editable.Client.DispatchAlert(data) and Editable.Server.DispatchAlert(data)
        -- false    : no alert
        -- type: string | false
        System = 'auto',

        -- Radio code shown by the dispatch script
        -- type: string
        Code = '10-35',

        -- ps-dispatch alert name (codeName)
        -- type: string
        CodeName = 'vehicletheft',

        -- Locale keys (locales/*.json) for the alert title and message; a literal text also works.
        -- The message receives the vehicle model and the plate (%s, %s).
        -- type: string
        Title = 'dispatch_title',
        Message = 'dispatch_message',

        -- Map blip of the alert, for the scripts that accept one
        -- type: table
        Blip = {
            Sprite = 225, -- blip sprite id
            Color = 1,    -- blip colour id
            Scale = 1.0,  -- blip scale
            Time = 120,   -- seconds the blip stays (converted to each script's unit, minutes are rounded up)
        },
    },
}

-- ACE allowed to use the admin commands (/chopshop_resetcd). The server console can always use them.
-- Players with this ACE also skip the anti-teleport delivery check, so they can test with teleports.
-- type: string
Config.AdminAce = 'admin'

-- Vehicle keys. Key scripts (qbx_vehiclekeys, qb-vehiclekeys, ...) block the engine of a vehicle the
-- player has no keys for; after a successful lockpick the server gives the job owner the keys of the
-- job vehicle (once per job, only with a lockpick item, never to the partner).
-- type: table
Config.VehicleKeys = {
    -- 'auto'   : first started script of the supported list (see README, "Vehicle keys")
    -- name     : force one: 'qbx_vehiclekeys', 'qs-vehiclekeys', 'wasabi_carlock', 'MrNewbVehicleKeys',
    --            'ak47_vehiclekeys', 'vehicles_keys', 'qb-vehiclekeys'
    -- 'custom' : calls Editable.Server.GiveVehicleKeys / RemoveVehicleKeys (editable/server.lua)
    -- false    : no keys are given (ESX without a key script, for example)
    -- type: string | false
    System = 'auto',

    -- Take the keys back from the owner when the job ends (finished, cancelled, expired, owner left
    -- or resource stop), before the vehicle is deleted.
    -- type: boolean
    RemoveOnEnd = true,
}

-- Job time limits in minutes. A job that exceeds them is cancelled and its scrap point released.
-- type: table
Config.TimeLimit = {
    Pickup = 20, -- from accepting the job until scrapping starts
    Scrap  = 10, -- from starting to scrap until every part is removed
}
