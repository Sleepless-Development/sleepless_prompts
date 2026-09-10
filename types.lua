---@meta

---@alias PromptPosition
---| 'top-left' | 'top-center' | 'top-right'
---| 'middle-left' | 'center' | 'middle-right'
---| 'bottom-left' | 'bottom-center' | 'bottom-right'
---| 'top' | 'bottom' | 'left' | 'right'
---| 'center-left' | 'center-right' | 'center-top' | 'center-bottom'

---@alias PromptLayout 'row' | 'column' | 'auto'
---@alias PromptSeparator 'slash' | 'line' | 'dot' | 'none'
---@alias PromptMode 'auto' | 'keyboard' | 'xbox' | 'playstation'
---@alias PromptGamepad 'auto' | 'xbox' | 'playstation'
---@alias PromptKeyboardStyle 'white' | 'dark' | 'alt' | 'retro' | 'vintage'
---@alias PromptGamepadStyle 'default' | 'light' | 'alt' | 'alt2' | 'retro'
---@alias PromptDevice 'keyboard' | 'gamepad'
---@alias PromptHook 'shown' | 'hidden' | 'updated' | 'deviceChanged' | 'pressed' | 'released' | 'held'

---@class PromptCustomPosition
---@field x number Percent or CSS length
---@field y number Percent or CSS length
---@field origin? PromptPosition Transform origin, default 'center'

---@class PromptOffset
---@field x number Offset in rem
---@field y number Offset in rem

---@class PromptEntry
---@field id? string Unique id within the group. Defaults to the key name.
---@field name? string Alias for id
---@field label string Visible label
---@field key? string | string[] Keyboard and/or shared input name (E, LMB, LT, ...)
---@field keyboard? string | string[] Keyboard-only override
---@field gamepad? string | string[] Gamepad-only override (Xbox layout: A south, B east, X west, Y north)
---@field keybind? string | table ox_lib keybind name, or the CKeybind table from lib.addKeybind. Keyboard icon follows the live mapping.
---@field icon? string | string[] Raw image path, skips icon lookup
---@field control? number GTA control index. When set, presses are tracked and hooks fire.
---@field disableControl? boolean Disable the GTA control while this prompt is shown
---@field holdTime? number Hold duration in ms. Prefixes the localized Hold word, fills a progress bar, and fires onHold / held.
---@field cooldown? number Ignore further presses for this many ms after press or hold
---@field disabled? boolean Dimmed, non-interactive
---@field hidden? boolean Omitted from the HUD
---@field progress? number 0-1 hold fill
---@field onPressed? fun(entry: PromptEntry)
---@field onReleased? fun(entry: PromptEntry)
---@field onHold? fun(entry: PromptEntry)
---@field onSelect? fun(data: PromptResponse) Action when the prompt is pressed, or when holdTime completes.
---@field export? string Export on the registering resource. Called as exports[resource][export](nil, data).
---@field event? string Client event to trigger
---@field serverEvent? string Server event to trigger
---@field command? string Command to execute
---@field groups? string | string[] | table<string, number> Job / gang / group filter. Same shape as sleepless_interact.
---@field items? string | string[] | table<string, number> Required items. Hash values are minimum counts.
---@field anyItem? boolean If true, any listed item is enough. Default requires all.
---@field canInteract? fun(entity: number, distance: number, coords: vector3, name: string): boolean? Same signature as Interact. Return false to hide.
---@field allowInVehicle? boolean If true, the prompt stays available while in a vehicle. Default hides it.
---@field entity? number Entity used for canInteract / distance
---@field coords? vector3 World coords used for canInteract / distance
---@field distance? number Hide when farther than this from entity/coords

---@class PromptResponse
---@field id string
---@field name string
---@field label string
---@field groupId string
---@field resource string

---@class PromptGroupData
---@field id string
---@field position? PromptPosition | PromptCustomPosition
---@field offset? PromptOffset
---@field layout? PromptLayout
---@field separator? PromptSeparator
---@field order? number CSS order when multiple groups share a slot
---@field persistOnPause? boolean Keep this group visible while the pause menu is open
---@field entity? number Default entity for prompt canInteract / distance
---@field coords? vector3 Default world coords for prompt canInteract / distance
---@field prompts PromptEntry | PromptEntry[]

---@alias PromptThemeId
---| 'modern' | 'minimal' | 'light' | 'retro'
---| 'cyber' | 'vice' | 'noir' | 'industrial' | 'fantasy'
---| string

exports.sleepless_prompts = {}

--- Show or replace a prompt group. Returns the group id.
---@param id string | PromptGroupData
---@param data? PromptGroupData
---@return string id
function exports.sleepless_prompts:show(id, data) end

--- Patch an existing group. Omitted fields stay as they are.
---@param id string
---@param data table
function exports.sleepless_prompts:update(id, data) end

--- Patch a single prompt inside a group.
---@param groupId string
---@param promptId string
---@param patch table
function exports.sleepless_prompts:updatePrompt(groupId, promptId, patch) end

--- Append a prompt to an open group.
---@param groupId string
---@param entry PromptEntry
---@return string promptId
function exports.sleepless_prompts:addPrompt(groupId, entry) end

--- Remove a prompt from an open group.
---@param groupId string
---@param promptId string
function exports.sleepless_prompts:removePrompt(groupId, promptId) end

--- Move an open group.
---@param id string
---@param position PromptPosition | PromptCustomPosition
---@param offset? PromptOffset
function exports.sleepless_prompts:setPosition(id, position, offset) end

--- Hide a group. Omit id to hide every group owned by the calling resource.
---@param id? string
function exports.sleepless_prompts:hide(id) end

function exports.sleepless_prompts:hideAll() end

--- True if the named group is open, or if any group is open when id is omitted.
---@param id? string
---@return boolean
function exports.sleepless_prompts:isActive(id) end

---@param id string
---@return table?
function exports.sleepless_prompts:get(id) end

---@return table
function exports.sleepless_prompts:getAll() end

---@param mode PromptMode
function exports.sleepless_prompts:setMode(mode) end

---@return PromptMode
function exports.sleepless_prompts:getMode() end

function exports.sleepless_prompts:openModeMenu() end

---@param gamepad PromptGamepad
function exports.sleepless_prompts:setGamepad(gamepad) end

--- Resolved family after auto-detect. Never returns 'auto'.
---@return 'xbox' | 'playstation'
function exports.sleepless_prompts:getGamepad() end

--- Set icon art style. One string applies to the device that owns it (alt/retro apply to both). Two strings or a table set each device.
---@param keyboardStyle PromptKeyboardStyle | { keyboard?: PromptKeyboardStyle, gamepad?: PromptGamepadStyle }
---@param gamepadStyle? PromptGamepadStyle
function exports.sleepless_prompts:setStyle(keyboardStyle, gamepadStyle) end

---@return PromptKeyboardStyle, PromptGamepadStyle
function exports.sleepless_prompts:getStyle() end

---@return PromptDevice
function exports.sleepless_prompts:getDevice() end

--- Current keyboard key for an ox_lib keybind name or CKeybind table.
---@param name string | table
---@return string?
function exports.sleepless_prompts:getKeybindKey(name) end

---@param scale number
function exports.sleepless_prompts:setScale(scale) end

---@param theme PromptThemeId
---@param color? number[]
function exports.sleepless_prompts:setTheme(theme, color) end

---@param color? number[]
function exports.sleepless_prompts:setColor(color) end

--- Subscribe to a prompt hook. Returns an unsubscribe function.
---@param event PromptHook
---@param cb function
---@return fun()
function exports.sleepless_prompts:on(event, cb) end
