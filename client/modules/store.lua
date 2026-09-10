local store = {
    groups = {},
    usingKeyboard = true,
    gamepad = 'xbox',
    gamepadAuto = true,
    mode = 'auto',
    keyboardStyle = 'white',
    gamepadStyle = 'light',
    scale = 1.0,
    coloredButtons = false,
    nuiReady = false,
    paused = false,
    hooks = {
        shown = {},
        hidden = {},
        updated = {},
        deviceChanged = {},
        pressed = {},
        released = {},
        held = {},
    },
}

return store
