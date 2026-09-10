local store = require 'client.modules.store'
local config = require 'client.modules.config'
local utils = require 'client.modules.utils'
local nui = require 'client.modules.nui'
local icons = require 'client.modules.icons'
local keybind = require 'client.modules.keybind'

local function kickRuntime()
    require('client.modules.runtime').start()
end

local function emit(name, id, group)
    TriggerEvent(('sleepless_prompts:%s'):format(name), id, group)
    local list = store.hooks[name]
    if not list then return end
    for i = 1, #list do
        list[i](id, group)
    end
end

---@param entry table
---@param index number
---@return table
local function normalizePrompt(entry, index)
    local entryType = type(entry)
    if entryType ~= 'table' then
        utils.typeError('prompt', 'table', entryType)
    end

    assert(entry.label, 'prompt.label is required')
    assert(
        type(entry.control) == 'number' or entry.keybind or entry.key or entry.keyboard or entry.gamepad or entry.icon,
        'prompt needs control, keybind, key, keyboard, gamepad, or icon'
    )

    local id = entry.id or entry.name
    if not id then
        if type(entry.control) == 'number' then
            id = ('control_%s'):format(entry.control)
        elseif entry.keybind then
            id = type(entry.keybind) == 'table' and entry.keybind.name or entry.keybind
        else
            local source = entry.key or entry.keyboard or entry.gamepad or entry.label
            if type(source) == 'table' then source = source[1] end
            id = source and tostring(source):lower() or ('prompt_%s'):format(index)
        end
    end

    local prompt = {
        id = tostring(id),
        label = entry.label,
        key = entry.key,
        keyboard = entry.keyboard,
        gamepad = entry.gamepad,
        icon = entry.icon,
        control = entry.control,
        disableControl = entry.disableControl,
        holdTime = entry.holdTime,
        cooldown = entry.cooldown,
        disabled = entry.disabled and true or false,
        hidden = entry.hidden and true or false,
        progress = entry.progress or 0,
        active = false,
        onPressed = entry.onPressed,
        onReleased = entry.onReleased,
        onHold = entry.onHold,
        onSelect = entry.onSelect,
        export = entry.export,
        event = entry.event,
        serverEvent = entry.serverEvent,
        command = entry.command,
        groups = entry.groups,
        items = entry.items,
        anyItem = entry.anyItem and true or false,
        canInteract = entry.canInteract,
        allowInVehicle = entry.allowInVehicle and true or false,
        entity = entry.entity,
        coords = entry.coords,
        distance = entry.distance,
        name = entry.name or tostring(id),
    }

    if entry.keybind then
        local name, hash = keybind.parse(entry.keybind)
        prompt.keybind = name
        prompt._keybindHash = hash
        keybind.watch(name)
    end

    keybind.capture(prompt)

    return prompt
end

---@param data table
---@return table
local function normalizePrompts(data)
    local list = utils.ensureArray(data)
    local prompts = {}
    for i = 1, #list do
        prompts[i] = normalizePrompt(list[i], i)
    end
    return prompts
end

---@param id string
---@return table
local function requireGroup(id)
    local group = store.groups[id]
    assert(group, ("prompt group '%s' does not exist"):format(id))
    return group
end

---@param idOrData string | table
---@param data? table
---@return string
function prompts.show(idOrData, data)
    local groupData
    if type(idOrData) == 'table' then
        groupData = idOrData
    else
        if type(idOrData) ~= 'string' then
            utils.typeError('id', 'string', type(idOrData))
        end
        groupData = data or {}
        groupData.id = idOrData
    end

    assert(groupData.id, 'group id is required')
    local id = tostring(groupData.id)
    local existed = store.groups[id] ~= nil

    local group = {
        id = id,
        resource = utils.owner(groupData.resource),
        position = utils.resolvePosition(groupData.position or config.defaultPosition),
        offset = groupData.offset or { x = 0, y = 0 },
        layout = groupData.layout or config.defaultLayout,
        separator = groupData.separator or config.separator,
        order = groupData.order or 0,
        persistOnPause = groupData.persistOnPause and true or false,
        entity = groupData.entity,
        coords = groupData.coords,
        prompts = normalizePrompts(groupData.prompts),
    }

    store.groups[id] = group
    nui.upsertGroup(group)
    emit(existed and 'updated' or 'shown', id, group)
    kickRuntime()
    return id
end

---@param id string
---@param data table
function prompts.update(id, data)
    if type(id) ~= 'string' then utils.typeError('id', 'string', type(id)) end
    if type(data) ~= 'table' then utils.typeError('data', 'table', type(data)) end

    local group = requireGroup(id)

    if data.position then
        group.position = utils.resolvePosition(data.position)
    end
    if data.offset then group.offset = data.offset end
    if data.layout then group.layout = data.layout end
    if data.separator then group.separator = data.separator end
    if data.order then group.order = data.order end
    if data.persistOnPause ~= nil then group.persistOnPause = data.persistOnPause and true or false end
    if data.entity ~= nil then group.entity = data.entity end
    if data.coords ~= nil then group.coords = data.coords end
    if data.prompts then group.prompts = normalizePrompts(data.prompts) end

    nui.upsertGroup(group)
    emit('updated', id, group)
    kickRuntime()
end

---@param groupId string
---@param promptId string
---@param patch table
function prompts.updatePrompt(groupId, promptId, patch)
    local group = requireGroup(groupId)
    if type(patch) ~= 'table' then utils.typeError('patch', 'table', type(patch)) end

    for i = 1, #group.prompts do
        local entry = group.prompts[i]
        if entry.id == promptId then
            for key, value in pairs(patch) do
                if key ~= 'id' and key ~= 'keybind' then
                    entry[key] = value
                end
            end
            if patch.keybind then
                local name, hash = keybind.parse(patch.keybind)
                entry.keybind = name
                entry._keybindHash = hash
                keybind.watch(name)
            end
            if patch.keybind or patch.control ~= nil then
                keybind.capture(entry)
            end
            nui.upsertGroup(group)
            emit('updated', groupId, group)
            kickRuntime()
            return
        end
    end

    error(("prompt '%s' not found in group '%s'"):format(promptId, groupId))
end

---@param groupId string
---@param entry table
---@return string
function prompts.addPrompt(groupId, entry)
    local group = requireGroup(groupId)
    local normalized = normalizePrompt(entry, #group.prompts + 1)
    group.prompts[#group.prompts + 1] = normalized
    nui.upsertGroup(group)
    emit('updated', groupId, group)
    kickRuntime()
    return normalized.id
end

---@param groupId string
---@param promptId string
function prompts.removePrompt(groupId, promptId)
    local group = requireGroup(groupId)
    for i = #group.prompts, 1, -1 do
        if group.prompts[i].id == promptId then
            table.remove(group.prompts, i)
            nui.upsertGroup(group)
            emit('updated', groupId, group)
            return
        end
    end
end

---@param id string
---@param position string | table
---@param offset? table
function prompts.setPosition(id, position, offset)
    local group = requireGroup(id)
    group.position = utils.resolvePosition(position)
    if offset then group.offset = offset end
    nui.upsertGroup(group)
    emit('updated', id, group)
end

---@param id? string
function prompts.hide(id)
    if not id then
        local resource = utils.owner()
        local removed = {}
        for groupId, group in pairs(store.groups) do
            if group.resource == resource then
                removed[#removed + 1] = groupId
            end
        end
        for i = 1, #removed do
            prompts.hide(removed[i])
        end
        return
    end

    if not store.groups[id] then return end
    store.groups[id] = nil
    nui.removeGroup(id)
    emit('hidden', id)
end

function prompts.hideAll()
    store.groups = {}
    nui.send('setGroups', {})
    emit('hidden')
end

---@param id? string
---@return boolean
function prompts.isActive(id)
    if id then
        return store.groups[id] ~= nil
    end
    return next(store.groups) ~= nil
end

---@param id string
---@return table?
function prompts.get(id)
    return store.groups[id]
end

---@return table
function prompts.getAll()
    return store.groups
end

local MODE = {
    auto = true,
    keyboard = true,
    xbox = true,
    playstation = true,
}

---@param mode 'auto' | 'keyboard' | 'xbox' | 'playstation'
function prompts.setMode(mode)
    local key = type(mode) == 'string' and mode:lower() or mode
    assert(MODE[key], ("unknown mode '%s'"):format(tostring(mode)))

    store.mode = key
    SetResourceKvp('sleepless_prompts:mode', key)

    if key == 'auto' then
        store.gamepadAuto = true
        store.usingKeyboard = IsUsingKeyboard(0)
        require('client.modules.device').refresh()
    elseif key == 'keyboard' then
        store.gamepadAuto = false
        store.usingKeyboard = true
    elseif key == 'xbox' then
        store.gamepadAuto = false
        store.usingKeyboard = false
        store.gamepad = 'xbox'
    else
        store.gamepadAuto = false
        store.usingKeyboard = false
        store.gamepad = 'playstation'
    end

    nui.setDevice(store.usingKeyboard, store.gamepad)
    nui.refreshAll()
    emit('deviceChanged', store.usingKeyboard and 'keyboard' or 'gamepad', store.gamepad)
    kickRuntime()
end

---@return 'auto' | 'keyboard' | 'xbox' | 'playstation'
function prompts.getMode()
    return store.mode
end

---@param gamepad 'auto' | 'xbox' | 'playstation'
function prompts.setGamepad(gamepad)
    prompts.setMode(gamepad)
end

---@return 'xbox' | 'playstation'
function prompts.getGamepad()
    return store.gamepad
end

function prompts.openModeMenu()
    local selected = lib.inputDialog('Prompt icons', {
        {
            type = 'select',
            label = 'Mode',
            description = 'Which button icons to show',
            options = {
                { value = 'auto', label = 'Auto' },
                { value = 'keyboard', label = 'Keyboard' },
                { value = 'xbox', label = 'Xbox' },
                { value = 'playstation', label = 'PlayStation' },
            },
            default = store.mode or 'auto',
            required = true,
        },
    })

    if not selected or not selected[1] then return end

    prompts.setMode(selected[1])

    local labels = {
        auto = 'Auto',
        keyboard = 'Keyboard',
        xbox = 'Xbox',
        playstation = 'PlayStation',
    }

    lib.notify({
        title = 'Prompts',
        description = ('Using %s icons'):format(labels[selected[1]] or selected[1]),
        type = 'success',
    })
end

---@param keyboardStyle string | table
---@param gamepadStyle? string
function prompts.setStyle(keyboardStyle, gamepadStyle)
    if type(keyboardStyle) == 'table' then
        local data = keyboardStyle
        if data.keyboard then
            store.keyboardStyle = icons.normalizeKeyboardStyle(data.keyboard)
        end
        if data.gamepad then
            store.gamepadStyle = icons.normalizeGamepadStyle(data.gamepad)
        end
        nui.refreshAll()
        return
    end

    if type(keyboardStyle) ~= 'string' then
        utils.typeError('style', 'string or table', type(keyboardStyle))
    end

    if gamepadStyle and gamepadStyle ~= '' then
        store.keyboardStyle = icons.normalizeKeyboardStyle(keyboardStyle)
        store.gamepadStyle = icons.normalizeGamepadStyle(gamepadStyle)
        nui.refreshAll()
        return
    end

    local setKeyboard, setGamepad = icons.styleTargets(keyboardStyle)
    assert(setKeyboard or setGamepad, ("unknown style '%s'"):format(keyboardStyle))
    if setKeyboard then
        store.keyboardStyle = icons.normalizeKeyboardStyle(keyboardStyle)
    end
    if setGamepad then
        store.gamepadStyle = icons.normalizeGamepadStyle(keyboardStyle)
    end
    nui.refreshAll()
end

---@return string, string
function prompts.getStyle()
    return store.keyboardStyle, store.gamepadStyle
end

---@return 'keyboard' | 'gamepad'
function prompts.getDevice()
    return store.usingKeyboard and 'keyboard' or 'gamepad'
end

---@param name string | table
---@return string?
function prompts.getKeybindKey(name)
    return keybind.resolve(name)
end

---@param scale number
function prompts.setScale(scale)
    store.scale = scale
    nui.setScale(scale)
end

---@param theme string
---@param color? number[]
function prompts.setTheme(theme, color)
    if type(theme) ~= 'string' then
        utils.typeError('theme', 'string', type(theme))
    end

    config.theme = theme:lower()
    if color ~= nil then
        config.themeColor = color
    end
    nui.setTheme(config.theme)
end

---@param color? number[]
function prompts.setColor(color)
    config.themeColor = color
    nui.setColor(config.getThemeColor())
end

---@param event string
---@param cb function
---@return function unsubscribe
function prompts.on(event, cb)
    local list = store.hooks[event]
    assert(list, ("unknown hook '%s'"):format(event))
    assert(type(cb) == 'function', 'callback must be a function')
    list[#list + 1] = cb
    return function()
        for i = #list, 1, -1 do
            if list[i] == cb then
                table.remove(list, i)
                break
            end
        end
    end
end
