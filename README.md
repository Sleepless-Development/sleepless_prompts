# sleepless_prompts

A FiveM HUD library for on-screen input prompts. Keyboard and gamepad icons, live remapping, and named screen slots.

![](https://img.shields.io/github/downloads/Sleepless-Development/sleepless_prompts/total?logo=github)
![](https://img.shields.io/github/downloads/Sleepless-Development/sleepless_prompts/latest/total?logo=github)
![](https://img.shields.io/github/contributors/Sleepless-Development/sleepless_prompts?logo=github)
![](https://img.shields.io/github/v/release/Sleepless-Development/sleepless_prompts?logo=github)

## Dependencies

- [ox_lib](https://github.com/communityox/ox_lib)

## Installation

1. Download and place `sleepless_prompts` in your resources folder.
2. Add `ensure sleepless_prompts` to `server.cfg` after `ox_lib`.

## 📃 Documentation

- [docs](https://sleeplessdevelopment.dev/docs/prompts)

## 💾 Download

[sleepless_prompts.zip](https://github.com/Sleepless-Development/sleepless_prompts/releases/latest/download/sleepless_prompts.zip)

## Usage

Other resources can call exports, or import the global:

```lua
client_script '@sleepless_prompts/init.lua'
```

```lua
prompts.show('vehicle', {
    position = 'bottom-center',
    prompts = {
        { id = 'enter', label = 'Enter', control = 38 },
        { id = 'lock', label = 'Lock', control = 182 },
        { id = 'horn', label = 'Horn', control = 86 },
        { id = 'engine', label = 'Engine', control = 23, holdTime = 1500 },
    },
})

prompts.updatePrompt('vehicle', 'lock', { label = 'Unlock' })
prompts.setPosition('vehicle', 'top-right')
prompts.hide('vehicle')
```

Set `control` or `keybind`. Icons are resolved from the live mapping. `key` / `keyboard` / `gamepad` are optional overrides, or for prompts that are not a GTA control or FiveM keybind.

### Live remapping

Icons update when the player remaps input. This applies to both:

- **GTA controls** (`control`): keyboard and gamepad glyphs come from `GetControlInstructionalButton`. Remap INPUT_PICKUP from E to G, or move it to another pad button, and the prompt follows.
- **FiveM / ox_lib keybinds** (`keybind`): the keyboard icon comes from the live `RegisterKeyMapping` bind. Remap it under Settings > Key Bindings > FiveM and the prompt follows.

The HUD also swaps keyboard vs gamepad icons when the last input device changes (`auto` mode).

### GTA controls

```lua
{ id = 'enter', label = 'Enter', control = 38, disableControl = true }
```

`disableControl` adds that control to `lib.disableControls` while the prompt is shown.

### ox_lib keybinds

Pass the keybind `name` from `lib.addKeybind`, or the table it returns.

```lua
lib.addKeybind({
    name = 'vehicle_enter',
    description = 'Enter vehicle',
    defaultKey = 'E',
    onPressed = function() end,
})

prompts.show('vehicle', {
    prompts = {
        { keybind = 'vehicle_enter', label = 'Enter' },
    },
})
```

`prompts.getKeybindKey('vehicle_enter')` returns the current keyboard key.

Icons follow the current input device. Gamepad names use Xbox layout (A south, B east, X west, Y north). PlayStation (DualSense) faces remap from that.

### Icon styles

Keyboard: `white`, `dark`, `alt`, `retro`, `vintage`.

Gamepad: `default`, `light`, `alt`, `alt2`, `retro`.

```lua
prompts.setStyle('dark')                 -- keyboard only
prompts.setStyle('light')                -- gamepad only
prompts.setStyle('retro')                -- both
prompts.setStyle('white', 'alt2')
prompts.setStyle({ keyboard = 'vintage', gamepad = 'default' })
prompts.setMode('keyboard')
prompts.setGamepad('playstation')
prompts.openModeMenu()
```

Players can run `/promptmode` (configurable) to pick Auto, Keyboard, Xbox, or PlayStation. The choice is saved per client.

`auto` follows the last input device and detects Xbox vs DualSense / DualShock. Steam Input or DS4Windows wrapping a DualSense as Xbox is treated as Xbox.

### Themes

Looks match Interact. Set `config.theme` to `modern`, `minimal`, `light`, `retro`, `cyber`, `vice`, `noir`, `industrial`, or `fantasy`. Drop `web/themes/<id>.css` to add another.

```lua
prompts.setTheme('cyber')
prompts.setTheme('modern', { 255, 64, 180, 255 })
prompts.setColor({ 232, 96, 48, 255 })
```

### Positions

`top-left`, `top-center`, `top-right`, `middle-left`, `center`, `middle-right`, `bottom-left`, `bottom-center`, `bottom-right`.

Aliases: `top`, `bottom`, `left`, `right`, `center-left`, `center-right`, `center-top`, `center-bottom`.

Custom:

```lua
prompts.setPosition('vehicle', { x = 82, y = 18, origin = 'top-right' })
```

### Live updates

```lua
prompts.update('vehicle', { position = 'middle-left', layout = 'column' })
prompts.updatePrompt('vehicle', 'lock', { disabled = true })
prompts.addPrompt('vehicle', { label = 'Horn', control = 86 })
prompts.removePrompt('vehicle', 'horn')
```

### Hooks

Events: `sleepless_prompts:shown`, `hidden`, `updated`, `deviceChanged`, `pressed`, `released`, `held`.

```lua
prompts.on('pressed', function(groupId, promptId, entry)
    if groupId == 'vehicle' and promptId == 'enter' then
        -- handle enter
    end
end)
```

Hold prompts fill while the control is held, then fire `held` / `onHold`.

### Actions

Same trigger options as interact. One of these runs on press, or when `holdTime` completes:

```lua
{ label = 'Lock', control = 182, event = 'myresource:lockVehicle' }
{ label = 'Engine', control = 23, holdTime = 1500, serverEvent = 'myresource:toggleEngine' }
{ label = 'Wave', key = 'G', command = 'e wave' }
{ label = 'Open', control = 38, onSelect = function(data) end }
{ label = 'Use', keybind = 'my_use', export = 'useItem' }
```

Priority: `onSelect`, `export`, `event`, `serverEvent`, `command`.

### Config

Edit `client/modules/config.lua` for default slot, mode, icon styles, scale, and theme.

Hold prompts prefix the `hold` string from `locales/en.json` (ox_lib locales). Copy that file to add another language.

Prompts can use the same `groups`, `items`, `anyItem`, `canInteract`, and `allowInVehicle` filters as Interact. Restricted prompts hide until the check passes.

`/promptmode` opens the icon mode dialog.

With `debug = true`, use:

- `/prompts` vehicle example
- `/prompts positions` one prompt in every slot
- `/prompts hold` hold-to-complete demo
- `/prompts gamepad playstation`
- `/prompts style dark`
- `/prompts style white retro`
- `/prompts keybind` remap `sleepless_prompts_demo` under Settings > Key Bindings > FiveM and watch the icon change
- `/prompts hide`

## License

GPL-3.0
