local store = require 'client.modules.store'
local config = require 'client.modules.config'
local nui = require 'client.modules.nui'
local input = require 'client.modules.input'
local keybind = require 'client.modules.keybind'
local device = require 'client.modules.device'
local restrictions = require 'client.modules.restrictions'

store.keyboardStyle = config.keyboardStyle
store.gamepadStyle = config.gamepadStyle
store.scale = config.scale
store.coloredButtons = config.coloredButtons
store.usingKeyboard = IsUsingKeyboard(0)

local savedMode = GetResourceKvpString('sleepless_prompts:mode')
prompts.setMode((savedMode and savedMode ~= '' and savedMode) or config.mode or 'auto')

CreateThread(function()
    while true do
        if store.mode ~= 'auto' then
            Wait(500)
        else
            local usingKeyboard = IsUsingKeyboard(0)
            if usingKeyboard ~= store.usingKeyboard then
                store.usingKeyboard = usingKeyboard
                keybind.syncAll()
                if not usingKeyboard then
                    device.refresh()
                end
                nui.setDevice(usingKeyboard, store.gamepad)
                nui.refreshAll()
                TriggerEvent('sleepless_prompts:deviceChanged', usingKeyboard and 'keyboard' or 'gamepad', store.gamepad)
                local list = store.hooks.deviceChanged
                for i = 1, #list do
                    list[i](usingKeyboard and 'keyboard' or 'gamepad', store.gamepad)
                end
            elseif not usingKeyboard then
                device.refresh()
            end
            Wait(usingKeyboard and 150 or 750)
        end
    end
end)

CreateThread(function()
    local paused = false
    while true do
        local isPaused = IsPauseMenuActive()
        if isPaused ~= paused then
            store.paused = isPaused
            nui.setPaused(isPaused)
            if not isPaused then
                local dirty = keybind.syncAll()
                for i = 1, #dirty do
                    nui.upsertGroup(dirty[i])
                end
            end
        end
        paused = isPaused

        if keybind.hasBindings() then
            local dirty = keybind.syncAll()
            for i = 1, #dirty do
                nui.upsertGroup(dirty[i])
            end
            Wait(200)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if input.hasControls() then
            input.tick()
            Wait(0)
        else
            Wait(200)
        end
    end
end)

CreateThread(function()
    while true do
        if next(store.groups) then
            local dirty = false
            for _, group in pairs(store.groups) do
                local changed = false
                for i = 1, #group.prompts do
                    local entry = group.prompts[i]
                    local blocked = restrictions.blocked(entry, group)
                    if entry._blocked ~= blocked then
                        entry._blocked = blocked
                        changed = true
                    end
                end
                if changed then
                    dirty = true
                    nui.upsertGroup(group)
                end
            end
            Wait(dirty and 150 or 400)
        else
            Wait(500)
        end
    end
end)

RegisterCommand(config.modeCommand or 'promptmode', function()
    prompts.openModeMenu()
end, false)

AddEventHandler('onClientResourceStop', function(resource)
    local removed = {}
    for id, group in pairs(store.groups) do
        if group.resource == resource then
            removed[#removed + 1] = id
        end
    end
    for i = 1, #removed do
        local id = removed[i]
        store.groups[id] = nil
        nui.removeGroup(id)
    end
end)

if config.debug then
    lib.addKeybind({
        name = 'sleepless_prompts_demo',
        description = 'sleepless_prompts demo',
        defaultKey = 'E',
    })

    RegisterCommand('prompts', function(_, args)
        local sub = args[1]

        if sub == 'hide' then
            prompts.hideAll()
            return
        end

        if sub == 'gamepad' then
            if args[2] then
                prompts.setGamepad(args[2])
            else
                print(('sleepless_prompts: %s (auto=%s)'):format(store.gamepad, store.gamepadAuto and 'yes' or 'no'))
            end
            return
        end

        if sub == 'style' then
            prompts.setStyle(args[2] or 'white', args[3])
            return
        end

        if sub == 'theme' then
            if args[2] then
                prompts.setTheme(args[2])
            else
                print(('sleepless_prompts: theme %s'):format(config.theme))
            end
            return
        end

        if sub == 'positions' then
            local slots = {
                'top-left', 'top-center', 'top-right',
                'middle-left', 'center', 'middle-right',
                'bottom-left', 'bottom-center', 'bottom-right',
            }
            for i = 1, #slots do
                prompts.show(('pos_%s'):format(slots[i]), {
                    position = slots[i],
                    prompts = {
                        { key = 'E', gamepad = 'A', label = slots[i] },
                    },
                })
            end
            return
        end

        if sub == 'keybind' then
            prompts.show('keybind_demo', {
                persistOnPause = true,
                position = 'bottom-center',
                prompts = {
                    { id = 'demo', keybind = 'sleepless_prompts_demo', gamepad = 'A', label = 'Interact' },
                },
            })
            return
        end

        if sub == 'hold' then
            prompts.show('hold_demo', {
                position = 'bottom-center',
                prompts = {
                    {
                        id = 'engine',
                        key = 'F',
                        gamepad = 'Y',
                        label = 'Engine',
                        control = 23,
                        holdTime = 1500,
                    },
                    {
                        id = 'cancel',
                        key = 'X',
                        gamepad = 'B',
                        label = 'Cancel',
                        control = 73,
                    },
                },
            })
            return
        end

        prompts.show('vehicle', {
            position = 'bottom-center',
            prompts = {
                { id = 'enter', key = 'E', gamepad = 'A', label = 'Enter', control = 38 },
                { id = 'lock', key = 'L', gamepad = 'X', label = 'Lock' },
                { id = 'trunk', key = 'G', gamepad = 'B', label = 'Trunk' },
                { id = 'engine', key = 'F', gamepad = 'Y', label = 'Engine', control = 23, holdTime = 1500 },
            },
        })
    end, false)
end
