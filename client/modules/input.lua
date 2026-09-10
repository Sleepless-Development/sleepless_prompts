local store = require 'client.modules.store'
local nui = require 'client.modules.nui'
local keybind = require 'client.modules.keybind'
local restrictions = require 'client.modules.restrictions'

local function isControlIndex(control)
    return type(control) == 'number' and control >= 0 and control < 400
end

local input = {}

local function emit(name, groupId, promptId, entry)
    TriggerEvent(('sleepless_prompts:%s'):format(name), groupId, promptId, entry)
    local list = store.hooks[name]
    if not list then return end
    for i = 1, #list do
        list[i](groupId, promptId, entry)
    end
end

---@param entry table
---@param groupId string
---@param group table
---@return table
local function getResponse(entry, groupId, group)
    return {
        id = entry.id,
        name = entry.id,
        label = entry.label,
        groupId = groupId,
        resource = group.resource,
    }
end

---@param entry table
---@param groupId string
---@param group table
local function trigger(entry, groupId, group)
    if entry.onSelect then
        entry.onSelect(getResponse(entry, groupId, group))
        return
    end

    if entry.export then
        exports[group.resource][entry.export](nil, getResponse(entry, groupId, group))
        return
    end

    if entry.event then
        TriggerEvent(entry.event, getResponse(entry, groupId, group))
        return
    end

    if entry.serverEvent then
        TriggerServerEvent(entry.serverEvent, getResponse(entry, groupId, group))
        return
    end

    if entry.command then
        ExecuteCommand(entry.command)
    end
end

function input.hasControls()
    for _, group in pairs(store.groups) do
        local prompts = group.prompts
        for i = 1, #prompts do
            local entry = prompts[i]
            if entry.keybind or isControlIndex(entry.control) then
                return true
            end
        end
    end
    return false
end

function input.tick()
    local now = GetGameTimer()

    for groupId, group in pairs(store.groups) do
        if store.paused and not group.persistOnPause then goto continue end

        local prompts = group.prompts
        for i = 1, #prompts do
            local entry = prompts[i]
            local control = isControlIndex(entry.control) and entry.control or nil
            if (control or entry.keybind) and not entry.disabled and not entry.hidden and not restrictions.blocked(entry, group) then
                if control and entry.disableControl then
                    DisableControlAction(0, control, true)
                end

                local cooldownUntil = entry._cooldownUntil or 0
                if now >= cooldownUntil then
                    local pressed, held, released
                    if entry.keybind then
                        pressed, held, released = keybind.poll(entry.keybind)
                    else
                        local disabled = entry.disableControl
                        pressed = disabled and IsDisabledControlJustPressed(0, control) or IsControlJustPressed(0, control)
                        held = disabled and IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
                        released = disabled and IsDisabledControlJustReleased(0, control) or IsControlJustReleased(0, control)
                    end

                    if pressed then
                        entry.active = true
                        entry._holdStart = now
                        nui.patchPrompt(groupId, entry.id, { active = true, progress = 0 })
                        if entry.onPressed then entry.onPressed(entry) end
                        emit('pressed', groupId, entry.id, entry)
                        if not entry.holdTime then
                            trigger(entry, groupId, group)
                        end
                    end

                    if entry.holdTime and held and entry._holdStart then
                        local progress = math.min(1, (now - entry._holdStart) / entry.holdTime)
                        local lastSent = entry._lastProgressSent or 0
                        if progress ~= entry.progress and (now - lastSent >= 50 or progress >= 1) then
                            entry.progress = progress
                            entry._lastProgressSent = now
                            nui.patchPrompt(groupId, entry.id, { progress = progress })
                        end
                        if progress >= 1 and not entry._heldFired then
                            entry._heldFired = true
                            if entry.onHold then entry.onHold(entry) end
                            emit('held', groupId, entry.id, entry)
                            trigger(entry, groupId, group)
                            if entry.cooldown then
                                entry._cooldownUntil = now + entry.cooldown
                            end
                        end
                    end

                    if released then
                        entry.active = false
                        entry.progress = 0
                        entry._holdStart = nil
                        entry._heldFired = false
                        nui.patchPrompt(groupId, entry.id, { active = false, progress = 0 })
                        if entry.onReleased then entry.onReleased(entry) end
                        emit('released', groupId, entry.id, entry)
                        if entry.cooldown and not entry.holdTime then
                            entry._cooldownUntil = now + entry.cooldown
                        end
                    end
                end
            end
        end
        ::continue::
    end

    keybind.endTick()
end

return input
