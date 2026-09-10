local store = require 'client.modules.store'

local keybind = {}
local states = {}

local SPECIAL = {
    b_100 = 'MouseLeft',
    b_101 = 'MouseRight',
    b_102 = 'MouseMiddle',
    b_108 = 'MouseLeft',
    b_109 = 'MouseRight',
    b_110 = 'MouseMiddle',
    b_115 = 'MouseLeft',
    b_116 = 'MouseRight',
    b_117 = 'MouseMiddle',
    b_130 = 'Minus',
    b_131 = 'Plus',
    b_134 = '0',
    b_135 = '1',
    b_136 = '2',
    b_137 = '3',
    b_140 = '4',
    b_141 = '5',
    b_142 = '6',
    b_143 = '7',
    b_144 = '8',
    b_145 = '9',
    b_170 = 'F1',
    b_171 = 'F2',
    b_172 = 'F3',
    b_173 = 'F4',
    b_174 = 'F5',
    b_175 = 'F6',
    b_176 = 'F7',
    b_177 = 'F8',
    b_178 = 'F9',
    b_179 = 'F10',
    b_180 = 'F11',
    b_181 = 'F12',
    b_194 = 'ArrowUp',
    b_195 = 'ArrowDown',
    b_196 = 'ArrowLeft',
    b_197 = 'ArrowRight',
    b_198 = 'Delete',
    b_199 = 'Escape',
    b_200 = 'Insert',
    b_210 = 'Delete',
    b_211 = 'Insert',
    b_212 = 'End',
    b_1000 = 'ShiftLeft',
    b_1002 = 'Tab',
    b_1003 = 'Enter',
    b_1004 = 'Backspace',
    b_1008 = 'Home',
    b_1009 = 'PageUp',
    b_1010 = 'PageDown',
    b_1012 = 'CapsLock',
    b_1013 = 'ControlLeft',
    b_1014 = 'ControlRight',
    b_1015 = 'AltLeft',
    b_1055 = 'Home',
    b_1056 = 'PageUp',
    b_2000 = 'Space',
}

---@param name string
---@return number
function keybind.hash(name)
    return joaat('+' .. name) | 0x80000000
end

---@param value string | table
---@return string, number
function keybind.parse(value)
    if type(value) == 'table' then
        local name = value.name
        assert(name, 'keybind table needs a name')
        return name, value.hash or keybind.hash(name)
    end

    if type(value) ~= 'string' then
        error(("expected keybind to have type 'string' (received %s)"):format(type(value)), 3)
    end

    return value, keybind.hash(value)
end

---@param hash number
---@param preferFrontend? boolean
---@return string
function keybind.raw(hash, preferFrontend)
    local first = preferFrontend and 2 or 0
    local second = preferFrontend and 0 or 2
    local raw = GetControlInstructionalButton(first, hash, true)
    if not raw or raw == '' then
        raw = GetControlInstructionalButton(second, hash, true)
    end
    return raw or ''
end

---@param raw string
---@return string?
function keybind.human(raw)
    if not raw or raw == '' then return end

    local prefix = raw:sub(1, 2):lower()
    if prefix == 't_' or prefix == 'w_' then
        return raw:sub(3):lower()
    end

    local mapped = SPECIAL[raw] or SPECIAL[raw:lower()]
    if mapped then
        return mapped
    end

    if prefix == 'b_' then
        return raw:sub(3)
    end

    return raw
end

---@param raw string
---@return string[]?
function keybind.humans(raw)
    if not raw or raw == '' then return end

    local names = {}
    local count = 0
    local start = 1
    local len = #raw

    while start <= len do
        local sep = raw:find('%', start, true)
        local token = sep and raw:sub(start, sep - 1) or raw:sub(start)
        local human = keybind.human(token)
        if human and human ~= '' then
            count += 1
            names[count] = human
        end
        if not sep then break end
        start = sep + 1
    end

    if count == 0 then return end
    return names
end

---@param a string | string[] | nil
---@param b string | string[] | nil
---@return boolean
local function sameNames(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

---@param names string[]
---@return string | string[]
local function storeNames(names)
    if #names == 1 then return names[1] end
    return names
end

---@param entry table
---@return boolean
function keybind.capture(entry)
    local raw
    local field
    if entry._keybindHash then
        raw = keybind.raw(entry._keybindHash)
        field = '_keybindRaw'
    elseif type(entry.control) == 'number' then
        raw = keybind.raw(entry.control, true)
        field = '_controlRaw'
    else
        return false
    end

    local changed = raw ~= entry[field]
    entry[field] = raw

    local names = keybind.humans(raw)
    if names then
        local liveField = IsUsingKeyboard(0) and '_liveKeyboard' or '_liveGamepad'
        local stored = storeNames(names)
        if not sameNames(entry[liveField], stored) then
            entry[liveField] = stored
            changed = true
        end
    end

    return changed
end

local PAD_DEFAULTS = {
    [0] = 'back',
    [21] = 'a',
    [22] = 'x',
    [23] = 'y',
    [24] = 'rt',
    [25] = 'lt',
    [26] = 'rsclick',
    [29] = 'rsclick',
    [36] = 'lsclick',
    [37] = 'lb',
    [38] = 'lb',
    [44] = 'rb',
    [45] = 'b',
    [46] = 'dpadright',
    [47] = 'dpadleft',
    [51] = 'dpadright',
    [52] = 'dpadleft',
    [73] = 'a',
    [74] = 'dpadright',
    [75] = 'y',
    [76] = 'rb',
    [86] = 'lsclick',
    [140] = 'b',
    [141] = 'a',
    [142] = 'rt',
    [143] = 'x',
    [177] = 'b',
    [182] = 'rt',
    [191] = 'a',
    [194] = 'b',
    [201] = 'a',
    [202] = 'b',
    [203] = 'x',
    [204] = 'y',
    [205] = 'lb',
    [206] = 'rb',
    [207] = 'lt',
    [208] = 'rt',
    [257] = 'rt',
}

---@param control number
---@return string?
function keybind.gamepadDefault(control)
    return PAD_DEFAULTS[control]
end

---@param entry table
---@return string | string[] | nil
function keybind.namesForEntry(entry)
    keybind.capture(entry)
    if store.usingKeyboard then
        return entry._liveKeyboard or entry.keyboard or entry.key
    end
    return entry._liveGamepad or entry.gamepad or keybind.gamepadDefault(entry.control)
end

---@param control number
---@return string[]?
function keybind.namesForControl(control)
    if type(control) ~= 'number' then return end
    return keybind.humans(keybind.raw(control, true))
end

---@param value string | table | number
---@return string?
function keybind.resolve(value)
    local hash = value
    if type(value) ~= 'number' then
        local _, parsed = keybind.parse(value)
        hash = parsed
    end
    return keybind.human(keybind.raw(hash))
end

---@param entry table
---@return boolean
function keybind.syncEntry(entry)
    return keybind.capture(entry)
end

---@return table[]
function keybind.syncAll()
    local dirty = {}
    local count = 0

    for _, group in pairs(store.groups) do
        local changed = false
        local prompts = group.prompts
        for i = 1, #prompts do
            if keybind.syncEntry(prompts[i]) then
                changed = true
            end
        end
        if changed then
            count += 1
            dirty[count] = group
        end
    end

    return dirty
end

---@param name string
function keybind.watch(name)
    if states[name] then return end

    local state = { down = false, pressed = false, released = false }
    states[name] = state

    RegisterCommand('+' .. name, function()
        if IsPauseMenuActive() then return end
        state.pressed = true
        state.down = true
    end, false)

    RegisterCommand('-' .. name, function()
        state.released = true
        state.down = false
    end, false)
end

---@param name string
---@return boolean, boolean, boolean
function keybind.poll(name)
    local state = states[name]
    if not state then return false, false, false end
    return state.pressed, state.down, state.released
end

function keybind.endTick()
    for _, state in pairs(states) do
        state.pressed = false
        state.released = false
    end
end

---@return boolean
function keybind.hasBindings()
    for _, group in pairs(store.groups) do
        local prompts = group.prompts
        for i = 1, #prompts do
            local entry = prompts[i]
            if entry.keybind or type(entry.control) == 'number' then
                return true
            end
        end
    end
    return false
end

return keybind
