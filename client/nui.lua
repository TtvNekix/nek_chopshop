--[[
    Nui: Lua side of the NUI contract (see web/CONTRACT.md, version 1).

    Lua -> NUI  (SendNUIMessage, all wrapped in { v = 1, clock = <epoch ms>, ... })
        Nui.setLocale(locale)            -> { type = 'init',   locale = locale }
        Nui.open(view, payload, opts)    -> { type = 'open',   view, payload }
        Nui.update(view, patch)          -> { type = 'update', view, payload = patch }
        Nui.close(view?)                 -> { type = 'close',  view? }

    NUI -> Lua  (RegisterNUICallback, every reply is { ok, data?, error? })
        Nui.on(action, handler)          handler(data) returns ok, dataOrErrorCode
        'ready' and 'close' are handled here and reserved.

    Focus: views that take focus (menus) call SetNuiFocus while open; the
    tracker and the loose note never do. Messages sent before the page reports 'ready' are
    queued and flushed in order, after the current locale.
]]

Nui = Nui or {}

local CONTRACT_VERSION = 1
local MAX_QUEUE = 64

-- focus: default for opts.focus. allowFocus = false means the view can never take focus.
local VIEWS = {
    ['job-board']   = { focus = true,  allowFocus = true },
    ['job-tracker'] = { focus = false, allowFocus = false },
    ['parts-buyer'] = { focus = true,  allowFocus = true },
    ['note']           = { focus = false, allowFocus = false },
    ['partner-invite'] = { focus = true,  allowFocus = true },
}

local RESERVED_ACTIONS = { ready = true, close = true }

local isReady = false
local queue = {}
local currentLocale = nil
local openViews = {} -- [view] = { focus = boolean, onClose = function|nil }
local hasFocus = false

local function debug(...)
    if Config and Config.Debug then
        print('[nek_chopshop:nui]', ...)
    end
end

local function clockMs()
    -- Epoch seconds shared with the server clock; NUI uses it to correct its own skew.
    return GetCloudTimeAsInt() * 1000
end

local function deliver(message)
    message.v = CONTRACT_VERSION
    message.clock = clockMs()
    SendNUIMessage(message)
end

local function send(message)
    if isReady then
        deliver(message)
        return
    end
    if #queue >= MAX_QUEUE then
        table.remove(queue, 1)
    end
    queue[#queue + 1] = message
end

local function refreshFocus()
    local wantsFocus = false
    for _, entry in pairs(openViews) do
        if entry.focus then
            wantsFocus = true
            break
        end
    end
    if wantsFocus ~= hasFocus then
        hasFocus = wantsFocus
        SetNuiFocus(wantsFocus, wantsFocus)
        SetNuiFocusKeepInput(false)
    end
end

local function assertView(view)
    if type(view) ~= 'string' or not VIEWS[view] then
        print(('[nek_chopshop:nui] unknown view %q'):format(tostring(view)))
        return false
    end
    return true
end

local function runOnClose(view, entry, reason)
    if entry and entry.onClose then
        local ok, err = pcall(entry.onClose, view, reason)
        if not ok then
            print(('[nek_chopshop:nui] onClose for %s failed: %s'):format(view, tostring(err)))
        end
    end
end

---Sends the locale dictionary. Accepts { lang, currency, strings } or a bare strings table.
---Strings may be flat ('board.title') or nested ({ board = { title = ... } }).
---@param locale table
function Nui.setLocale(locale)
    if type(locale) ~= 'table' then return false end
    if type(locale.strings) ~= 'table' then
        locale = { strings = locale }
    end
    currentLocale = locale
    send({ type = 'init', locale = locale })
    return true
end

---Opens a view.
---@param view string 'job-board' | 'job-tracker' | 'parts-buyer' | 'note' | 'partner-invite'
---@param payload table|nil view data, see web/CONTRACT.md
---@param opts table|nil { focus?: boolean, onClose?: fun(view: string, reason: string) }
function Nui.open(view, payload, opts)
    if not assertView(view) then return false end
    opts = type(opts) == 'table' and opts or {}

    local spec = VIEWS[view]
    local focus = spec.focus
    if opts.focus ~= nil then focus = opts.focus == true end
    if not spec.allowFocus then focus = false end

    -- Never take focus before the page can show the view and release it again (Escape / close):
    -- callers wait with Nui.waitReady and fall back to the ox_lib menus when this returns false.
    if focus and not isReady then
        debug('refused to open', view, 'with focus: page not ready')
        return false
    end

    openViews[view] = { focus = focus, onClose = opts.onClose }
    send({ type = 'open', view = view, payload = type(payload) == 'table' and payload or {} })
    refreshFocus()
    return true
end

---Shallow-merges patch into the open view's payload. Arrays are replaced, not merged.
---@param view string
---@param patch table
function Nui.update(view, patch)
    if not assertView(view) or not openViews[view] or type(patch) ~= 'table' then return false end
    send({ type = 'update', view = view, payload = patch })
    return true
end

---Closes one view, or every view when view is nil.
---@param view string|nil
---@param reason string|nil passed to onClose (default 'lua')
function Nui.close(view, reason)
    reason = reason or 'lua'
    if view ~= nil then
        if not assertView(view) then return false end
        local entry = openViews[view]
        openViews[view] = nil
        send({ type = 'close', view = view })
        refreshFocus()
        if entry then runOnClose(view, entry, reason) end
        return true
    end

    local closed = openViews
    openViews = {}
    send({ type = 'close' })
    refreshFocus()
    for name, entry in pairs(closed) do
        runOnClose(name, entry, reason)
    end
    return true
end

---@param view string
---@return boolean
function Nui.isOpen(view)
    return openViews[view] ~= nil
end

---True once the page reported 'ready'.
---@return boolean
function Nui.isReady()
    return isReady
end

---Waits (yields) up to timeoutMs (default 2000) for the page to report 'ready'.
---@param timeoutMs number|nil
---@return boolean ready
function Nui.waitReady(timeoutMs)
    local deadline = GetGameTimer() + (tonumber(timeoutMs) or 2000)
    while not isReady and GetGameTimer() < deadline do
        Wait(50)
    end
    return isReady
end

---Closes every view and releases the NUI focus unconditionally (recovery when the page misbehaves).
function Nui.reset()
    Nui.close(nil, 'reset')
    hasFocus = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

---Registers a NUI -> Lua action.
---The handler receives the request table and returns `ok, dataOrErrorCode`:
---    return true, { plate = 'ABC' }      -> { ok = true,  data = { plate = 'ABC' } }
---    return false, 'no_item'             -> { ok = false, error = 'no_item' }
---Errors thrown inside the handler reply { ok = false, error = 'internal' }.
---The handler runs in a thread, so lib.callback.await is allowed.
---@param action string
---@param handler fun(data: table): boolean, any
function Nui.on(action, handler)
    if type(action) ~= 'string' or type(handler) ~= 'function' then
        error('Nui.on(action: string, handler: function) expected', 2)
    end
    if RESERVED_ACTIONS[action] then
        error(('Nui.on: %q is reserved by the NUI module'):format(action), 2)
    end

    RegisterNUICallback(action, function(data, cb)
        if type(data) ~= 'table' then
            cb({ ok = false, error = 'bad_payload' })
            return
        end

        local success, ok, result = pcall(handler, data)
        if not success then
            print(('[nek_chopshop:nui] handler %s failed: %s'):format(action, tostring(ok)))
            cb({ ok = false, error = 'internal' })
            return
        end

        if ok then
            cb({ ok = true, data = result })
        else
            cb({ ok = false, error = type(result) == 'string' and result or 'failed' })
        end
    end)
end

-- Built-in callbacks ----------------------------------------------------------

RegisterNUICallback('ready', function(_, cb)
    isReady = true
    debug('page ready, flushing', #queue, 'messages')
    if currentLocale then
        deliver({ type = 'init', locale = currentLocale })
    end
    local pending = queue
    queue = {}
    for i = 1, #pending do
        if pending[i].type ~= 'init' then
            deliver(pending[i])
        end
    end
    cb({ ok = true, data = { v = CONTRACT_VERSION } })
end)

-- A close from the page always ends with the focus released, even when the payload is broken:
-- an unknown or missing view closes every view.
RegisterNUICallback('close', function(data, cb)
    local view = type(data) == 'table' and data.view or nil
    if type(view) == 'string' and VIEWS[view] then
        if openViews[view] then
            Nui.close(view, 'nui')
        end
        refreshFocus()
        cb({ ok = true })
        return
    end
    Nui.reset()
    cb({ ok = false, error = 'bad_payload' })
end)

-- Manual recovery if the focus ever gets stuck (page error, broken view): /chopshopui
RegisterCommand('chopshopui', function()
    Nui.reset()
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if hasFocus then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)
