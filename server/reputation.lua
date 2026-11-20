-- Chop shop reputation (Config.Reputation).
--
-- Persistence: table nek_chopshop_reputation (created on start), one row per character identifier.
-- Reads that sit on the job flow (GetPlayerLevel, Reputation.GetPerks) only look at the in-memory
-- cache and never yield: requestJob calls them between its checks and its reservations.
-- The cache is warmed by chopshop:server:playerReady and by the job board (both may yield).
-- Every XP change comes from server code (job finish/cancel/abandon in server/main.lua, or the
-- AddReputation export): no client event or callback can change XP.
--
-- Weekly decay (Config.Reputation.Decay, off by default) is applied lazily when the XP is read:
-- the stored xp is the value before decay, the decay is computed from last_job. A finished job
-- folds the decay into the stored xp and restarts the clock, so a week is never applied twice.
-- No thread or timer is involved.

Reputation = {}

local RepConfig = Config.Reputation or {}
local XPConfig = RepConfig.XP or {}
local DecayConfig = RepConfig.Decay or {}
local WEEK = 7 * 24 * 60 * 60
local MAX_EXPORT_AMOUNT = 1000000

local NEUTRAL_PERKS = { sellMultiplier = 1.0, cooldownMultiplier = 1.0, extraPartChance = 0 }

local Cache = {}   -- [identifier] = { xp = stored xp (before decay), jobs = n, lastJob = epoch seconds | nil }
local Loading = {} -- [identifier] = promise of the cache entry while the row is being read
local Saving = {}  -- [identifier] = true while a write is in flight, 'dirty' when it must run again
local TableReady = promise.new()

local function isEnabled()
    return RepConfig.Enabled == true
end

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

-- Levels ------------------------------------------------------------------------
-- LEVELS[i] = { xp, perks }; the level number shown to players and used by Config.Tiers minLevel is i - 1.
local LEVELS = {}

do
    for _, def in ipairs(type(RepConfig.Levels) == 'table' and RepConfig.Levels or {}) do
        local perks = type(def.perks) == 'table' and def.perks or {}
        LEVELS[#LEVELS + 1] = {
            xp = math.max(math.floor(tonumber(def.xp) or 0), 0),
            perks = {
                sellMultiplier = math.max(tonumber(perks.sellMultiplier) or 1.0, 0),
                cooldownMultiplier = clamp(tonumber(perks.cooldownMultiplier) or 1.0, 0, 1),
                extraPartChance = clamp(tonumber(perks.extraPartChance) or 0, 0, 100),
            },
        }
    end
    table.sort(LEVELS, function(a, b) return a.xp < b.xp end)
    if not LEVELS[1] or LEVELS[1].xp ~= 0 then
        table.insert(LEVELS, 1, { xp = 0, perks = NEUTRAL_PERKS })
    end
end

-- Index in LEVELS for an amount of XP.
local function levelIndex(xp)
    local index = 1
    for i, level in ipairs(LEVELS) do
        if xp >= level.xp then index = i else break end
    end
    return index
end

local function decayOf(entry)
    if DecayConfig.Enabled ~= true or not entry.lastJob then return 0 end
    local weeks = math.floor((os.time() - entry.lastJob) / WEEK)
    if weeks < 1 then return 0 end
    return weeks * math.max(math.floor(tonumber(DecayConfig.PerWeek) or 0), 0)
end

-- XP after the lazy weekly decay.
local function effectiveXp(entry)
    return math.max(entry.xp - decayOf(entry), 0)
end

-- Storage -----------------------------------------------------------------------

-- With Config.Reputation.Enabled = false no SQL runs at all (no table, no reads, no writes):
-- every entry point below returns early when the reputation is disabled.
MySQL.ready(function()
    if not isEnabled() then return end
    local ok, err = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS nek_chopshop_reputation (
            identifier VARCHAR(64) PRIMARY KEY,
            xp INT NOT NULL DEFAULT 0,
            jobs INT NOT NULL DEFAULT 0,
            last_job TIMESTAMP NULL
        )
    ]])
    if not ok then
        print(('^1[nek_chopshop] Could not create the reputation table: %s^7'):format(tostring(err)))
    end
    TableReady:resolve(true)
end)

-- Changes that could not be applied because the row could not be read: [identifier] = { { amount, opts }, ... }.
-- They get one retry: applied right after the next successful load of that identifier, or dropped
-- (with a console message) when that next load fails too. No timer is involved.
local Pending = {}
local applyChange -- defined below (Changes)

-- Returns the cache entry of an identifier, reading its row if needed. Yields.
-- nil when the row could not be read (nothing is cached then, so no write can clobber the row).
local function ensureLoaded(identifier)
    if Cache[identifier] then return Cache[identifier] end
    if Loading[identifier] then return Citizen.Await(Loading[identifier]) end

    local pending = promise.new()
    Loading[identifier] = pending
    Citizen.Await(TableReady)

    local ok, row = pcall(MySQL.single.await,
        'SELECT xp, jobs, UNIX_TIMESTAMP(last_job) AS last_job FROM nek_chopshop_reputation WHERE identifier = ?',
        { identifier })

    local entry
    if ok then
        entry = Cache[identifier] or {
            xp = row and math.max(math.floor(tonumber(row.xp) or 0), 0) or 0,
            jobs = row and math.max(math.floor(tonumber(row.jobs) or 0), 0) or 0,
            lastJob = row and tonumber(row.last_job) or nil,
        }
        Cache[identifier] = entry
    else
        print(('^1[nek_chopshop] Could not read the reputation of %s: %s^7'):format(identifier, tostring(row)))
    end

    -- Retry of the changes queued by an earlier failed load (one retry each)
    local queued = Pending[identifier]
    Pending[identifier] = nil
    if queued then
        if entry then
            for _, change in ipairs(queued) do applyChange(identifier, entry, change.amount, change.opts) end
        else
            print(('^1[nek_chopshop] Dropped %d queued reputation change(s) of %s: the row could not be read again^7')
                :format(#queued, identifier))
        end
    end

    Loading[identifier] = nil
    pending:resolve(entry)
    return entry
end

-- Queues a change whose load failed, for one retry on the next successful load.
local function queueChange(identifier, amount, opts)
    local queued = Pending[identifier] or {}
    queued[#queued + 1] = { amount = amount, opts = opts }
    Pending[identifier] = queued
    print(('^3[nek_chopshop] Reputation change of %s (%+d XP) queued until its row can be read^7')
        :format(identifier, amount))
end

-- Writes the cached values of an identifier. Writes of one identifier never overlap, so an older
-- write can never land after a newer one; a change made during a write triggers one more write.
local function flush(identifier)
    if Saving[identifier] then
        Saving[identifier] = 'dirty'
        return
    end
    Saving[identifier] = true

    CreateThread(function()
        repeat
            Saving[identifier] = true
            local entry = Cache[identifier]
            local query, params
            if entry.lastJob then
                query = [[INSERT INTO nek_chopshop_reputation (identifier, xp, jobs, last_job)
                    VALUES (?, ?, ?, FROM_UNIXTIME(?))
                    ON DUPLICATE KEY UPDATE xp = VALUES(xp), jobs = VALUES(jobs), last_job = VALUES(last_job)]]
                params = { identifier, entry.xp, entry.jobs, entry.lastJob }
            else
                query = [[INSERT INTO nek_chopshop_reputation (identifier, xp, jobs, last_job)
                    VALUES (?, ?, ?, NULL)
                    ON DUPLICATE KEY UPDATE xp = VALUES(xp), jobs = VALUES(jobs)]]
                params = { identifier, entry.xp, entry.jobs }
            end
            local ok, err = pcall(MySQL.update.await, query, params)
            if not ok then
                print(('^1[nek_chopshop] Could not save the reputation of %s: %s^7'):format(identifier, tostring(err)))
            end
        until Saving[identifier] ~= 'dirty'
        Saving[identifier] = nil
    end)
end

-- Changes ------------------------------------------------------------------------

local function sendLog(titleKey, bodyKey, ...)
    if not (Config.Logs and Config.Logs.EnableReputation) then return end
    ServerUtils.SendDiscordLog(locale(titleKey), locale(bodyKey, ...),
        Config.Discord.Color.rep or Config.Discord.Color.finished)
end

-- Applies a change to a loaded cache entry and saves it. Never yields (the write runs in its own thread).
function applyChange(identifier, entry, amount, opts)
    local before = effectiveXp(entry)
    if opts.activity then
        entry.xp = before
        entry.lastJob = os.time()
    end
    if opts.finished then entry.jobs = entry.jobs + 1 end
    entry.xp = math.max(entry.xp + amount, 0)
    flush(identifier)

    local after = effectiveXp(entry)
    local oldLevel, newLevel = levelIndex(before) - 1, levelIndex(after) - 1
    if Config.Debug then
        print(('[nek_chopshop] Reputation %s: %d -> %d XP (%s)'):format(identifier, before, after,
            tostring(opts.reason)))
    end
    if opts.log then
        sendLog('logs.rep_change_title', 'logs.rep_change_body', identifier, amount, tostring(opts.reason), after)
    end
    if newLevel > oldLevel then
        sendLog('logs.rep_levelup_title', 'logs.rep_levelup_body', identifier, newLevel, after)
        if opts.source and GetPlayerName(opts.source) then
            TriggerClientEvent('ox_lib:notify', opts.source, {
                type = 'success',
                description = locale('rep_level_up', newLevel),
            })
        end
    end
end

local function normalizeChange(identifier, amount, opts)
    if not isEnabled() or type(identifier) ~= 'string' or identifier == '' then return nil end
    return math.floor(tonumber(amount) or 0), opts or {}
end

---Changes the XP of an identifier. Never yields: the work runs in its own thread.
---When the row cannot be read, the change is queued for one retry on the next successful load.
---@param identifier string character identifier
---@param amount integer XP to add (negative subtracts; XP never goes below 0)
---@param opts? { source?: number, activity?: boolean, finished?: boolean, reason?: string, log?: boolean }
---  activity: a job was done (folds the decay and sets last_job); finished: counts a completed job;
---  source: online player to notify on level up; log: send the change to Discord
---@return boolean accepted false when the reputation is disabled or the identifier is invalid
function Reputation.Change(identifier, amount, opts)
    amount, opts = normalizeChange(identifier, amount, opts)
    if not amount then return false end

    CreateThread(function()
        local entry = ensureLoaded(identifier)
        if not entry then
            queueChange(identifier, amount, opts)
            return
        end
        applyChange(identifier, entry, amount, opts)
    end)
    return true
end

---Same as Reputation.Change, but waits for the row. Yields the first time an identifier is used.
---@return boolean applied false when the change could not be applied now (it is then queued for one retry)
function Reputation.ChangeNow(identifier, amount, opts)
    amount, opts = normalizeChange(identifier, amount, opts)
    if not amount then return false end

    local entry = ensureLoaded(identifier)
    if not entry then
        queueChange(identifier, amount, opts)
        return false
    end
    applyChange(identifier, entry, amount, opts)
    return true
end

---Rewards a finished job: the owner gets Base + PerPart * parts + the time bonus, the partner a share.
---@param ownerCid string
---@param ownerSource number
---@param partnerCid? string
---@param partnerSource? number
---@param removedCount integer parts removed
---@param timeLeft number fraction (0-1) of the scrap time limit that was left
function Reputation.OnJobFinished(ownerCid, ownerSource, partnerCid, partnerSource, removedCount, timeLeft)
    if not isEnabled() then return end
    local gain = math.floor((tonumber(XPConfig.Base) or 0)
        + (tonumber(XPConfig.PerPart) or 0) * (tonumber(removedCount) or 0)
        + (tonumber(XPConfig.TimeBonusMax) or 0) * clamp(tonumber(timeLeft) or 0, 0, 1))
    gain = math.max(gain, 0)

    Reputation.Change(ownerCid, gain, { source = ownerSource, activity = true, finished = true, reason = 'job_finished' })

    if partnerCid and partnerCid ~= ownerCid then
        local share = math.floor(gain * clamp(tonumber(XPConfig.PartnerShare) or 0, 0, 1))
        Reputation.Change(partnerCid, share, { source = partnerSource, activity = true, reason = 'partner' })
    end
end

---Penalty for a job the owner did not finish: 'expired' (time limit) or 'abandoned' (left the server).
---@param ownerCid string
---@param reason 'expired' | 'abandoned'
function Reputation.OnJobFailed(ownerCid, reason)
    if not isEnabled() then return end
    local penalty = reason == 'abandoned' and XPConfig.PenaltyAbandoned or XPConfig.PenaltyExpired
    penalty = math.max(math.floor(tonumber(penalty) or 0), 0)
    if penalty > 0 then Reputation.Change(ownerCid, -penalty, { reason = reason }) end
end

-- Reads ---------------------------------------------------------------------------

---Perks of a player's current level, from the cache only (never yields).
---Neutral perks when the reputation is disabled or the player is not cached yet.
---@param source number
---@return { sellMultiplier: number, cooldownMultiplier: number, extraPartChance: number }
function Reputation.GetPerks(source)
    if not isEnabled() then return NEUTRAL_PERKS end
    local cid = Bridge.GetIdentifier(source)
    local entry = cid and Cache[cid]
    if not entry then return LEVELS[1].perks end
    return LEVELS[levelIndex(effectiveXp(entry))].perks
end

---Loads a player's reputation into the cache in the background (never yields).
---@param source number
function Reputation.Warm(source)
    if not isEnabled() then return end
    local cid = Bridge.GetIdentifier(source)
    if cid and not Cache[cid] then CreateThread(function() ensureLoaded(cid) end) end
end

-- Readable list of what the level after `index` adds over it (tiers and better perks).
local function nextUnlockText(index)
    local current, nextLevel = LEVELS[index], LEVELS[index + 1]
    if not nextLevel then return nil end
    local levelNumber = index -- level number of LEVELS[index + 1]

    local unlocks = {}
    local tierKeys = {}
    for key in pairs(Config.Tiers or {}) do tierKeys[#tierKeys + 1] = key end
    table.sort(tierKeys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(tierKeys) do
        local tier = Config.Tiers[key]
        if (tonumber(tier.minLevel) or 0) == levelNumber then
            unlocks[#unlocks + 1] = locale(tier.label or tostring(key))
        end
    end

    local cur, nxt = current.perks, nextLevel.perks
    if nxt.sellMultiplier > cur.sellMultiplier then
        unlocks[#unlocks + 1] = locale('rep_perk_sell', math.floor((nxt.sellMultiplier - 1) * 100 + 0.5))
    end
    if nxt.cooldownMultiplier < cur.cooldownMultiplier then
        unlocks[#unlocks + 1] = locale('rep_perk_cooldown', math.floor((1 - nxt.cooldownMultiplier) * 100 + 0.5))
    end
    if nxt.extraPartChance > cur.extraPartChance then
        unlocks[#unlocks + 1] = locale('rep_perk_extra', math.floor(nxt.extraPartChance + 0.5))
    end

    return #unlocks > 0 and table.concat(unlocks, ', ') or nil
end

---Reputation block of the NUI job board (web/components/job-board.js). Yields (loads the row).
---nil when the reputation is disabled or could not be read.
---@param source number
---@return { level: integer, xp: integer, xpMax: integer, nextUnlock?: string } | nil
function Reputation.GetBoardBlock(source)
    if not isEnabled() then return nil end
    local cid = Bridge.GetIdentifier(source)
    local entry = cid and ensureLoaded(cid)
    if not entry then return nil end

    local xp = effectiveXp(entry)
    local index = levelIndex(xp)
    local current, nextLevel = LEVELS[index], LEVELS[index + 1]
    if not nextLevel then
        return { level = index - 1, xp = 1, xpMax = 1 } -- max level: full bar, nothing left to unlock
    end
    return {
        level = index - 1,
        xp = xp - current.xp,
        xpMax = nextLevel.xp - current.xp,
        nextUnlock = nextUnlockText(index),
    }
end

---Returns the chop shop reputation level of a player, from the cache only (never yields).
---requestJob calls this between its checks and its reservations.
---Level 0 while the player is not cached; with the reputation disabled every tier is available.
---@param source number player server id
---@return number level
function GetPlayerLevel(source)
    if not isEnabled() then return math.huge end
    local cid = Bridge.GetIdentifier(source)
    local entry = cid and Cache[cid]
    if not entry then return 0 end
    return levelIndex(effectiveXp(entry)) - 1
end

-- Exports ---------------------------------------------------------------------------

---exports.nek_chopshop:GetReputation(identifier) -> { xp, level, jobs } | nil
---May yield the first time an identifier is asked for (reads its row); call it from a thread.
exports('GetReputation', function(identifier)
    if not isEnabled() or type(identifier) ~= 'string' or identifier == '' then return nil end
    local entry = ensureLoaded(identifier)
    if not entry then return nil end
    local xp = effectiveXp(entry)
    return { xp = xp, level = levelIndex(xp) - 1, jobs = entry.jobs }
end)

---exports.nek_chopshop:AddReputation(identifier, amount, reason) -> boolean
---amount: integer, positive adds and negative subtracts (XP never goes below 0). Saved asynchronously.
---May yield the first time an identifier is used (reads its row); call it from a thread.
---Returns false when the change could not be applied (the row could not be read): the change is
---then queued and applied once, on the next successful read of that identifier.
exports('AddReputation', function(identifier, amount, reason)
    if not isEnabled() or type(identifier) ~= 'string' or identifier == '' or #identifier > 64 then return false end
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == 0 or math.abs(amount) > MAX_EXPORT_AMOUNT then return false end
    amount = amount > 0 and math.floor(amount) or math.ceil(amount)
    if amount == 0 then return false end

    reason = type(reason) == 'string' and reason:sub(1, 100) or 'export'
    local invoker = GetInvokingResource() or GetCurrentResourceName()
    print(('[nek_chopshop] AddReputation %s %+d XP by %s (%s)'):format(identifier, amount, invoker, reason))

    return Reputation.ChangeNow(identifier, amount, { reason = ('%s: %s'):format(invoker, reason), log = true })
end)
