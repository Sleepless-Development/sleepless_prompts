local config = {}

-- enable /prompts test command
config.debug = false

-- default slot when show() omits position
-- top-left | top-center | top-right
-- middle-left | center | middle-right
-- bottom-left | bottom-center | bottom-right
-- aliases: top, bottom, left, right, center-left, center-right, center-top, center-bottom
config.defaultPosition = 'bottom-center'

-- row | column | auto (column on left/right middle, row everywhere else)
config.defaultLayout = 'auto'

-- slash | line | dot | none
config.separator = 'slash'

-- auto | keyboard | xbox | playstation
-- auto follows the last input device and detects Xbox vs DualSense / DualShock
config.mode = 'auto'

config.modeCommand = 'promptmode'

-- keyboard: white | dark | alt | retro | vintage
config.keyboardStyle = 'white'

-- xbox / playstation: default | light | alt | alt2 | retro
config.gamepadStyle = 'light'

-- face buttons use colored variants when the pack has them (A green, Cross, etc)
config.coloredButtons = false

-- overall HUD scale (1.0 = default)
config.scale = 1.0

config.iconSize = 2.4

config.versionCheckEnabled = true

-- Built-in: modern | minimal | light | retro | cyber | vice | noir | industrial | fantasy
-- Drop web/themes/<id>.css with [data-theme="<id>"] selectors to add another look.
config.theme = 'modern'

config.themeColors = {
    modern = { 49, 164, 252, 255 },
    minimal = { 168, 186, 204, 255 },
    light = { 37, 99, 235, 255 },
    retro = { 255, 176, 32, 255 },
    cyber = { 0, 229, 255, 255 },
    vice = { 255, 64, 180, 255 },
    noir = { 240, 240, 236, 255 },
    industrial = { 212, 168, 48, 255 },
    fantasy = { 212, 175, 110, 255 },
}

-- Optional override for every theme. Set to { r, g, b, a } to force one accent.
-- Leave nil to use the theme's own color above.
config.themeColor = nil

function config.getThemeColor()
    if config.themeColor then
        return config.themeColor
    end
    local colors = config.themeColors
    return (colors and colors[config.theme]) or { 49, 164, 252, 255 }
end

return config
