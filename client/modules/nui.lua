local store = require 'client.modules.store'
local config = require 'client.modules.config'
local utils = require 'client.modules.utils'
local icons = require 'client.modules.icons'
local restrictions = require 'client.modules.restrictions'

local nui = {}
local queue = {}

local function send(action, data)
    local message = { action = action, data = data }
    if not store.nuiReady then
        queue[#queue + 1] = message
        return
    end
    SendNUIMessage(message)
end

nui.send = send

---@param group table
---@return table
function nui.buildPayload(group)
    local prompts = {}
    local count = 0

    for i = 1, #group.prompts do
        local entry = group.prompts[i]
        if not entry.hidden and not restrictions.blocked(entry, group) then
            local srcs, fallbacks = icons.resolve(entry)
            count += 1
            prompts[count] = {
                id = entry.id,
                label = entry.label,
                icons = srcs,
                fallbacks = fallbacks,
                disabled = entry.disabled and true or false,
                progress = entry.progress or 0,
                active = entry.active and true or false,
                hold = entry.holdTime ~= nil,
                holdPrefix = entry.holdTime and locale('hold') or nil,
            }
        end
    end

    local position = group.position
    local custom = type(position) == 'table' and position or nil
    local align = 'center'
    if type(position) == 'string' then
        if position:find('left', 1, true) then
            align = 'start'
        elseif position:find('right', 1, true) then
            align = 'end'
        end
    end

    return {
        id = group.id,
        position = custom and 'custom' or position,
        custom = custom,
        offset = group.offset or { x = 0, y = 0 },
        layout = utils.resolveLayout(position, group.layout or config.defaultLayout),
        align = align,
        separator = group.separator or config.separator,
        order = group.order or 0,
        persistOnPause = group.persistOnPause and true or false,
        prompts = prompts,
    }
end

function nui.upsertGroup(group)
    local payload = nui.buildPayload(group)
    if #payload.prompts == 0 then
        send('removeGroup', group.id)
        return
    end
    send('upsertGroup', payload)
end

function nui.removeGroup(id)
    send('removeGroup', id)
end

function nui.patchPrompt(groupId, promptId, patch)
    send('patchPrompt', {
        groupId = groupId,
        promptId = promptId,
        patch = patch,
    })
end

function nui.refreshAll()
    local payload = {}
    local count = 0
    for _, group in pairs(store.groups) do
        local built = nui.buildPayload(group)
        if #built.prompts > 0 then
            count += 1
            payload[count] = built
        end
    end
    send('setGroups', payload)
end

function nui.setColor(color)
    send('setColor', color)
end

function nui.setTheme(theme)
    local id = theme or config.theme or 'modern'
    if type(id) ~= 'string' then
        id = config.theme or 'modern'
    end
    send('setTheme', id)
    send('setColor', config.getThemeColor())
    send('setIconSize', config.iconSize)
end

function nui.setScale(scale)
    send('setScale', scale)
end

function nui.setDevice(usingKeyboard, gamepad)
    send('setDevice', {
        device = usingKeyboard and 'keyboard' or 'gamepad',
        gamepad = gamepad,
    })
end

function nui.setPaused(paused)
    send('setPaused', paused and true or false)
end

RegisterNUICallback('ready', function(_, cb)
    store.nuiReady = true
    cb(1)
    nui.setTheme(config.theme)
    nui.setScale(store.scale)
    nui.setDevice(store.usingKeyboard, store.gamepad)
    nui.setPaused(store.paused)
    for i = 1, #queue do
        SendNUIMessage(queue[i])
    end
    queue = {}
    nui.refreshAll()
end)

return nui
