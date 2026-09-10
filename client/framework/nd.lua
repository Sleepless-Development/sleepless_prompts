local NDCore = exports['ND_Core']
local playerGroups = NDCore:getPlayer()?.groups or {}
local utils = require 'client.modules.utils'

RegisterNetEvent('ND:characterLoaded', function(data)
    playerGroups = data.groups
end)

RegisterNetEvent('ND:updateCharacter', function(data)
    if source == '' then return end
    playerGroups = data.groups or {}
end)

---@diagnostic disable-next-line: duplicate-set-field
function utils.hasPlayerGotGroup(filter)
    local filterType = type(filter)

    if filterType == 'string' then
        return playerGroups[filter] ~= nil
    elseif filterType == 'table' then
        local tabletype = table.type(filter)
        if tabletype == 'hash' then
            for name, grade in pairs(filter) do
                local playerGrade = playerGroups[name]?.rank
                if playerGrade and grade <= playerGrade then
                    return true
                end
            end
        elseif tabletype == 'array' then
            for i = 1, #filter do
                if playerGroups[filter[i]] then
                    return true
                end
            end
        end
    end
end
