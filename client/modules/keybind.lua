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
---@return string
function keybind.raw(hash)
    local raw = GetControlInstructionalButton(0, hash, true)
    if not raw or raw == '' then
        raw = GetControlInstructionalButton(2, hash, true)
    end
    return raw or ''
end

---@param raw string
---@return string?
function keybind.human(raw)
    if raw == '' then return end

    if raw:sub(1, 2) == 't_' then
        return raw:sub(3):lower()
    end

    local mapped = SPECIAL[raw]
    if mapped then
        return mapped
    end

    if raw:sub(1, 2) == 'b_' then
        return raw:sub(3)
    end

    return raw
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
    if not entry._keybindHash then return false end

    local raw = keybind.raw(entry._keybindHash)
    if raw == entry._keybindRaw then return false end

    entry._keybindRaw = raw
    local human = keybind.human(raw)
    if human then
        entry.keyboard = human
    end
    return true
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
            if prompts[i].keybind then
                return true
            end
        end
    end
    return false
end

return keybind
