local store = require 'client.modules.store'
local nui = require 'client.modules.nui'

local device = {}

local function fromInstructional()
    local samples = {
        GetControlInstructionalButton(2, 24, true),
        GetControlInstructionalButton(2, 25, true),
        GetControlInstructionalButton(2, 22, true),
        GetControlInstructionalButton(0, 24, true),
        GetControlInstructionalButton(0, 22, true),
        GetControlInstructionalButton(2, 201, true),
    }

    local blob = ''
    for i = 1, #samples do
        blob = blob .. ' ' .. string.upper(samples[i] or '')
    end

    if blob:find('CROSS', 1, true) or blob:find('CIRCLE', 1, true) or blob:find('SQUARE', 1, true)
        or blob:find('TRIANGLE', 1, true) or blob:find('T_R2', 1, true) or blob:find('T_L2', 1, true)
        or blob:find('T_R1', 1, true) or blob:find('T_L1', 1, true) then
        return 'playstation'
    end

    if blob:find('T_RT', 1, true) or blob:find('T_LT', 1, true) or blob:find('T_RB', 1, true)
        or blob:find('T_LB', 1, true) or blob:find('T_A', 1, true) then
        return 'xbox'
    end
end

function device.apply(gamepad)
    if not gamepad then return false end
    if gamepad ~= 'xbox' and gamepad ~= 'playstation' then return false end
    if store.gamepad == gamepad then return false end

    store.gamepad = gamepad
    nui.setDevice(store.usingKeyboard, store.gamepad)
    nui.refreshAll()
    TriggerEvent('sleepless_prompts:deviceChanged', store.usingKeyboard and 'keyboard' or 'gamepad', store.gamepad)
    local list = store.hooks.deviceChanged
    for i = 1, #list do
        list[i](store.usingKeyboard and 'keyboard' or 'gamepad', store.gamepad)
    end
    return true
end

function device.refresh()
    if not store.gamepadAuto then return end
    nui.send('detectGamepad')

    local detected = fromInstructional()
    if detected then
        device.apply(detected)
    end
end

RegisterNUICallback('gamepadDetected', function(data, cb)
    cb(1)
    if not store.gamepadAuto then return end
    local gamepad = type(data) == 'table' and data.gamepad or nil
    if gamepad then
        device.apply(gamepad)
    end
end)

return device
