local store = require 'client.modules.store'
local config = require 'client.modules.config'
local nui = require 'client.modules.nui'

store.keyboardStyle = config.keyboardStyle
store.gamepadStyle = config.gamepadStyle
store.scale = config.scale
store.coloredButtons = config.coloredButtons
store.usingKeyboard = IsUsingKeyboard(0)

local savedMode = GetResourceKvpString('sleepless_prompts:mode')
prompts.setMode((savedMode and savedMode ~= '' and savedMode) or config.mode or 'auto')

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
                    { id = 'demo', keybind = 'sleepless_prompts_demo', label = 'Interact' },
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
                        label = 'Engine',
                        control = 23,
                        holdTime = 1500,
                    },
                    {
                        id = 'cancel',
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
                { id = 'enter', label = 'Enter', control = 38 },
                { id = 'lock', label = 'Lock', control = 182 },
                { id = 'horn', label = 'Horn', control = 86 },
                { id = 'engine', label = 'Engine', control = 23, holdTime = 1500 },
            },
        })
    end, false)
end
