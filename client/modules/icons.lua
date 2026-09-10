local utils = require 'client.modules.utils'
local store = require 'client.modules.store'
local keybind = require 'client.modules.keybind'

local icons = {}

local KEYBOARD_STYLES = {
    white = true,
    dark = true,
    alt = true,
    retro = true,
    vintage = true,
}

local GAMEPAD_STYLES = {
    default = true,
    light = true,
    alt = true,
    alt2 = true,
    retro = true,
}

local KEYBOARD_SUFFIX = {
    white = '_White',
    dark = '_Dark',
    alt = '_Alt',
    retro = '_Retro',
    vintage = '_Vintage',
}

local XBOX_SUFFIX = {
    default = '',
    light = '_Light',
    alt = '_Alt',
    alt2 = '_Alt_2',
    retro = '_Retro',
}

local PLAYSTATION_SUFFIX = {
    default = '',
    light = '_Light',
    alt = '_Alt',
    alt2 = 'Alt_2',
    retro = '_Retro',
}

local KEYBOARD_STEMS = {
    alt = 'T_Alt_Key',
    lalt = 'T_Alt_Key',
    ralt = 'T_Alt_Key',
    altleft = 'T_Alt_Key',
    altright = 'T_Alt_Key',
    lmenu = 'T_Alt_Key',
    rmenu = 'T_Alt_Key',
    ctrl = 'T_Crtl_Key',
    control = 'T_Crtl_Key',
    lctrl = 'T_Crtl_Key',
    rctrl = 'T_Crtl_Key',
    lcontrol = 'T_Crtl_Key',
    rcontrol = 'T_Crtl_Key',
    controlleft = 'T_Crtl_Key',
    controlright = 'T_Crtl_Key',
    shift = 'T_Shift_Key',
    lshift = 'T_Shift_Key',
    rshift = 'T_Shift_Key',
    shiftleft = 'T_Shift_Key',
    shiftright = 'T_Shift_Key',
    leftshift = 'T_Shift_Key',
    rightshift = 'T_Shift_Key',
    leftctrl = 'T_Crtl_Key',
    rightctrl = 'T_Crtl_Key',
    leftcontrol = 'T_Crtl_Key',
    rightcontrol = 'T_Crtl_Key',
    tab = 'T_Tab_Key',
    caps = 'T_CapsLock_Key',
    capslock = 'T_CapsLock_Key',
    enter = 'T_Enter_Key',
    ['return'] = 'T_Enter_Key',
    esc = 'T_Esc_Key',
    escape = 'T_Esc_Key',
    space = 'T_Space_Key',
    spacebar = 'T_Space_Key',
    backspace = 'T_BackSpace_Key',
    bksp = 'T_BackSpace_Key',
    delete = 'T_Del_Key',
    del = 'T_Del_Key',
    insert = 'T_Ins_Key',
    ins = 'T_Ins_Key',
    home = 'T_Home_Key',
    ['end'] = 'T_End_Key',
    pageup = 'T_PageUp_Key',
    pgup = 'T_PageUp_Key',
    pagedown = 'T_PageDown_Key',
    pgdn = 'T_PageDown_Key',
    up = 'T_Up_Key',
    down = 'T_Down_Key',
    left = 'T_Left_Key',
    right = 'T_Right_Key',
    arrowup = 'T_Up_Key',
    arrowdown = 'T_Down_Key',
    arrowleft = 'T_Left_Key',
    arrowright = 'T_Right_Key',
    minus = 'T_Minus_Key',
    hyphen = 'T_Minus_Key',
    plus = 'T_Plus_Key',
    equals = 'T_Plus_Key',
    numpadadd = 'T_Plus_Key',
    numpadsubstract = 'T_Minus_Key',
    numpadsubtract = 'T_Minus_Key',
    numpad0 = 'T_0_Key',
    numpad1 = 'T_1_Key',
    numpad2 = 'T_2_Key',
    numpad3 = 'T_3_Key',
    numpad4 = 'T_4_Key',
    numpad5 = 'T_5_Key',
    numpad6 = 'T_6_Key',
    numpad7 = 'T_7_Key',
    numpad8 = 'T_8_Key',
    numpad9 = 'T_9_Key',
    slash = 'T_Slash_Key',
    tilde = 'T_Tilde_Key',
    grave = 'T_Tilde_Key',
    semicolon = 'T_Semicolon_Key',
    quote = 'T_Quotation_Key',
    apostrophe = 'T_Quotation_Key',
    lbracket = 'T_Brackets_L_Key',
    rbracket = 'T_Brackets_R_Key',
    leftbracket = 'T_Brackets_L_Key',
    rightbracket = 'T_Brackets_R_Key',
    asterisk = 'T_Asterisk_Key',
    star = 'T_Asterisk_Key',
    question = 'T_Question_Mark_Key',
    numlock = 'T_NumLock_Key',
    printscreen = 'T_PrtScrn_Key',
    prtscn = 'T_PrtScrn_Key',
    mouseleft = 'T_Mouse_Left_Key',
    lmb = 'T_Mouse_Left_Key',
    mouse1 = 'T_Mouse_Left_Key',
    leftclick = 'T_Mouse_Left_Key',
    leftmousebutton = 'T_Mouse_Left_Key',
    mouseright = 'T_Mouse_Right_Key',
    rmb = 'T_Mouse_Right_Key',
    mouse2 = 'T_Mouse_Right_Key',
    rightclick = 'T_Mouse_Right_Key',
    rightmousebutton = 'T_Mouse_Right_Key',
    mousemiddle = 'T_Mouse_Middle_Key',
    mmb = 'T_Mouse_Middle_Key',
    mouse3 = 'T_Mouse_Middle_Key',
    mouse = 'T_Mouse_Simple_Key',
    mousex = 'T_Mouse_X_Key',
    mousey = 'T_Mouse_Y_Key',
    mousexy = 'T_Mouse_XY_Key',
}

local KEYBOARD_EXCEPTIONS = {
    scroll = {
        white = 'T_Mouse_Scroll_Key_Dark_Key_White.webp',
        dark = 'T_Mouse_Scroll_Key_Dark_Key_Dark.webp',
        alt = 'T_Mouse_Scroll_Key_Dark_Key_Alt.webp',
        retro = 'T_Mouse_Scroll_Key_Key_Retro.webp',
        vintage = 'T_Mouse_Scroll_Key_Vintage.webp',
    },
    mousescroll = nil,
    scrollup = {
        white = 'T_Mouse_Scroll_Up_Key_Dark_Key_White.webp',
        dark = 'T_Mouse_Scroll_Up_Key_Dark_Key_Dark.webp',
        alt = 'T_Mouse_Scroll_Up_Key_Dark_Key_Alt.webp',
        retro = 'T_Mouse_Scroll_Up_Key_Retro.webp',
        vintage = 'T_Mouse_Scroll_Up_Key_Vintage.webp',
    },
    scrolldown = {
        white = 'T_Mouse_Scroll_Down_Key_Dark_Key_White.webp',
        dark = 'T_Mouse_Scroll_Down_Key_Dark_Key_Dark.webp',
        alt = 'T_Mouse_Scroll_Down_Key_Dark_Key_Alt.webp',
        retro = 'T_Mouse_Scroll_Down_Key_Retro.webp',
        vintage = 'T_Mouse_Scroll_Down_Key_Vintage.webp',
    },
}

KEYBOARD_EXCEPTIONS.mousescroll = KEYBOARD_EXCEPTIONS.scroll
KEYBOARD_EXCEPTIONS.scrollwheelup = KEYBOARD_EXCEPTIONS.scrollup
KEYBOARD_EXCEPTIONS.scrollwheeldown = KEYBOARD_EXCEPTIONS.scrolldown

local GAMEPAD_ALIASES = {
    cross = 'a',
    pscross = 'a',
    circle = 'b',
    pscircle = 'b',
    square = 'x',
    pssquare = 'x',
    triangle = 'y',
    pstriangle = 'y',
    l2 = 'lt',
    lefttrigger = 'lt',
    r2 = 'rt',
    righttrigger = 'rt',
    l1 = 'lb',
    leftbumper = 'lb',
    r1 = 'rb',
    rightbumper = 'rb',
    leftstick = 'ls',
    rightstick = 'rs',
    l3 = 'lsclick',
    r3 = 'rsclick',
    lsclick = 'lsclick',
    rsclick = 'rsclick',
    leftstickclick = 'lsclick',
    rightstickclick = 'rsclick',
    options = 'start',
    menu = 'start',
    share = 'back',
    select = 'back',
    view = 'back',
    padup = 'dpadup',
    paddown = 'dpaddown',
    padleft = 'dpadleft',
    padright = 'dpadright',
    dpadu = 'dpadup',
    dpadd = 'dpaddown',
    dpadl = 'dpadleft',
    dpadr = 'dpadright',
    touch = 'touchpad',
    touchpad = 'touchpad',
}

local XBOX = {
    a = { white = 'T_X_A_White', color = 'T_X_A_Color' },
    b = { white = 'T_X_B_White', color = 'T_X_B_Color' },
    x = { white = 'T_X_X_White', color = 'T_X_X_Color', plain = 'T_X_X' },
    y = { white = 'T_X_Y_White', color = 'T_X_Y_Color' },
    lt = 'T_X_LT',
    rt = 'T_X_RT',
    lb = 'T_X_LB',
    rb = 'T_X_RB',
    ls = 'T_X_L',
    rs = 'T_X_R',
    lsclick = 'T_X_Left_Stick_Click',
    rsclick = 'T_X_Right_Stick_Click',
    lsup = 'T_X_L_UP',
    lsdown = 'T_X_L_Down',
    lsleft = 'T_X_L_Left',
    lsright = 'T_X_L_Right',
    rsup = 'T_X_R_UP',
    rsdown = 'T_X_R_Down',
    rsleft = 'T_X_R_Left',
    rsright = 'T_X_R_Right',
    dpad = 'T_X_Dpad',
    dpadup = 'T_X_Dpad_Up',
    dpaddown = 'T_X_Dpad_Down',
    dpadleft = 'T_X_Dpad_Left',
    dpadright = 'T_X_Dpad_Right',
    start = 'T_X_Share',
    back = 'T_X_Share',
}

local PLAYSTATION = {
    a = { plain = 'T_P5_Cross', color = 'T_P5_Cross_Color' },
    b = { plain = 'T_P5_Circle', color = 'T_P5_Circle_Color' },
    x = { plain = 'T_P5_Square', color = 'T_P5_Square_Color' },
    y = { plain = 'T_P5_Triangle', color = 'T_P5_Triangle_Color' },
    lt = 'T_P5_L2',
    rt = 'T_P5_R2',
    lb = 'T_P5_L1',
    rb = 'T_P5_R1',
    ls = 'T_P5_L',
    rs = 'T_P5_R',
    lsclick = 'T_P5_L3',
    rsclick = 'T_P5_R3',
    lsup = 'T_P5_L_UP',
    lsdown = 'T_P5_L_Down',
    lsleft = 'T_P5_L_Left',
    lsright = 'T_P5_L_Right',
    rsup = 'T_P5_R_UP',
    rsdown = 'T_P5_R_Down',
    rsleft = 'T_P5_R_Left',
    rsright = 'T_P5_R_Right',
    dpad = 'T_P5_Dpad',
    dpadup = 'T_P5_Dpad_UP',
    dpaddown = 'T_P5_Dpad_Down',
    dpadleft = 'T_P5_Dpad_Left',
    dpadright = 'T_P5_Dpad_Right',
    start = 'T_P5_Options',
    back = 'T_P5_Share',
    touchpad = 'T_P5_Touch_Pad',
}

---@param style string
---@return string
function icons.normalizeKeyboardStyle(style)
    local key = utils.normalize(tostring(style))
    if key == 'default' or key == 'light' then return 'white' end
    if key == 'alt2' then return 'alt' end
    assert(KEYBOARD_STYLES[key], ("unknown keyboard style '%s'"):format(style))
    return key
end

---@param style string
---@return string
function icons.normalizeGamepadStyle(style)
    local key = utils.normalize(tostring(style))
    if key == 'white' then return 'light' end
    if key == 'dark' or key == 'vintage' then return 'default' end
    assert(GAMEPAD_STYLES[key], ("unknown gamepad style '%s'"):format(style))
    return key
end

---@param gamepad string
---@return string
function icons.normalizeGamepad(gamepad)
    local key = utils.normalize(tostring(gamepad))
    if key == 'playstation5' or key == 'ps5' or key == 'ps' or key == 'dualsense' then
        return 'playstation'
    end
    if key == 'xb' or key == 'xboxone' or key == 'xboxseries' then
        return 'xbox'
    end
    assert(key == 'xbox' or key == 'playstation', ("unknown gamepad '%s'"):format(gamepad))
    return key
end

---@param style string
---@return boolean, boolean
function icons.styleTargets(style)
    local key = utils.normalize(tostring(style))
    local keyboard = KEYBOARD_STYLES[key] == true
    local gamepad = GAMEPAD_STYLES[key] == true
    if key == 'white' or key == 'dark' or key == 'vintage' then
        return true, false
    end
    if key == 'default' or key == 'light' or key == 'alt2' then
        return false, true
    end
    return keyboard, gamepad
end

---@param stem string
---@param suffix string
---@return string
local function fileName(stem, suffix)
    return ('%s%s.webp'):format(stem, suffix)
end

---@param name string
---@param style string
---@return string?
local function keyboardFile(name, style)
    local exceptions = KEYBOARD_EXCEPTIONS[name]
    if exceptions then
        return exceptions[style]
    end

    local stem = KEYBOARD_STEMS[name]
    if not stem then
        if name:match('^f%d%d?$') then
            stem = ('T_%s_Key'):format(name:upper())
        elseif name:match('^%a$') or name:match('^%d$') then
            stem = ('T_%s_Key'):format(name:upper())
        end
    end

    if not stem then return end
    return fileName(stem, KEYBOARD_SUFFIX[style] or '_White')
end

---@param entry string | table
---@param style string
---@param colored boolean
---@param suffix string
---@return string?
local function stemFile(entry, style, colored, suffix)
    if type(entry) == 'string' then
        return fileName(entry, suffix)
    end

    local stem
    if colored and entry.color then
        stem = entry.color
    else
        stem = entry.white or entry.plain
    end

    return stem and fileName(stem, suffix) or nil
end

---@param name string
---@param gamepad string
---@param style string
---@param colored boolean
---@return string?
local function gamepadFile(name, gamepad, style, colored)
    local canonical = GAMEPAD_ALIASES[name] or name
    if gamepad == 'playstation' then
        local entry = PLAYSTATION[canonical]
        if not entry then return end
        return stemFile(entry, style, colored, PLAYSTATION_SUFFIX[style] or '')
    end

    local entry = XBOX[canonical]
    if not entry then return end
    return stemFile(entry, style, colored, XBOX_SUFFIX[style] or '')
end

---@param name string
---@return string?, string
function icons.path(name)
    local key = utils.normalize(tostring(name))
    if key == '' then return nil, name end

    local keyboardStyle = store.keyboardStyle or 'white'
    local gamepadStyle = store.gamepadStyle or 'light'
    local gamepad = store.gamepad or 'xbox'
    local colored = store.coloredButtons and true or false

    if store.usingKeyboard then
        local file = keyboardFile(key, keyboardStyle)
        if file then
            return ('./icons/keyboard/%s/%s'):format(keyboardStyle, file), name
        end
        local padFile = gamepadFile(key, gamepad, gamepadStyle, colored)
        if padFile then
            return ('./icons/%s/%s/%s'):format(gamepad, gamepadStyle, padFile), name
        end
        return nil, name
    end

    local padFile = gamepadFile(key, gamepad, gamepadStyle, colored)
    if padFile then
        return ('./icons/%s/%s/%s'):format(gamepad, gamepadStyle, padFile), name
    end

    local kbFile = keyboardFile(key, keyboardStyle)
    if kbFile then
        return ('./icons/keyboard/%s/%s'):format(keyboardStyle, kbFile), name
    end

    return nil, name
end

---@param names string | string[]
---@return string[], string[]
local function resolveNames(names)
    names = utils.ensureArray(names)
    local srcs = {}
    local fallbacks = {}
    local count = 0

    for i = 1, #names do
        local src, fallback = icons.path(names[i])
        count += 1
        srcs[count] = src or ''
        fallbacks[count] = fallback
    end

    return srcs, fallbacks
end

---@param entry table
---@return string[], string[]
function icons.resolve(entry)
    if entry.icon then
        return utils.ensureArray(entry.icon), {}
    end

    return resolveNames(keybind.namesForEntry(entry))
end

return icons
