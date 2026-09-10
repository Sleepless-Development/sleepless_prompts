local store = require 'client.modules.store'
local nui = require 'client.modules.nui'
local input = require 'client.modules.input'
local keybind = require 'client.modules.keybind'
local device = require 'client.modules.device'
local restrictions = require 'client.modules.restrictions'

local runtime = {}
local hudRunning = false
local inputRunning = false

local function tickRestrictions()
    for _, group in pairs(store.groups) do
        local changed = false
        local prompts = group.prompts
        for i = 1, #prompts do
            local entry = prompts[i]
            local blocked = restrictions.blocked(entry, group)
            if entry._blocked ~= blocked then
                entry._blocked = blocked
                changed = true
            end
        end
        if changed then
            nui.upsertGroup(group)
        end
    end
end

local function startHud()
    if hudRunning then return end
    if not next(store.groups) then return end

    hudRunning = true
    CreateThread(function()
        local paused = IsPauseMenuActive()
        store.paused = paused
        nui.setPaused(paused)
        local bindElapsed = 0

        while next(store.groups) do
            local isPaused = IsPauseMenuActive()
            if isPaused ~= paused then
                store.paused = isPaused
                nui.setPaused(isPaused)
                if not isPaused then
                    keybind.syncAll()
                    nui.refreshAll()
                end
                paused = isPaused
            end

            tickRestrictions()
            device.poll()

            if keybind.hasBindings() then
                bindElapsed += 150
                if bindElapsed >= 200 then
                    bindElapsed = 0
                    local dirty = keybind.syncAll()
                    for i = 1, #dirty do
                        nui.upsertGroup(dirty[i])
                    end
                end
            else
                bindElapsed = 0
            end

            Wait(150)
        end

        if store.paused then
            store.paused = false
            nui.setPaused(false)
        end
        hudRunning = false
    end)
end

local function startInput()
    if inputRunning then return end
    if not input.hasControls() then return end

    inputRunning = true
    CreateThread(function()
        while input.hasControls() do
            input.tick()
            local ok0, changed0 = pcall(HaveControlsChanged, 0)
            local ok2, changed2 = pcall(HaveControlsChanged, 2)
            if (ok0 and changed0) or (ok2 and changed2) then
                keybind.syncAll()
                nui.refreshAll()
            end
            Wait(0)
        end
        input.flushDisables()
        inputRunning = false
    end)
end

function runtime.start()
    device.poll()
    startHud()
    startInput()
end

return runtime
