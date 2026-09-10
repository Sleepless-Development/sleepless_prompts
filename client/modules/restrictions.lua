local utils = require 'client.modules.utils'

local restrictions = {}

---@param entry table
---@param group table
---@return number entity
---@return number distance
---@return vector3 coords
---@return string name
function restrictions.context(entry, group)
    local entity = entry.entity or group.entity or 0
    if entity ~= 0 and not DoesEntityExist(entity) then
        entity = 0
    end

    local coords = entry.coords or group.coords
    if not coords and entity ~= 0 then
        coords = GetEntityCoords(entity)
    end
    coords = coords or GetEntityCoords(cache.ped)

    local distance = #(GetEntityCoords(cache.ped) - coords)
    return entity, distance, coords, entry.name or entry.id
end

---@param entry table
---@param group table
---@return boolean
function restrictions.blocked(entry, group)
    if not entry.allowInVehicle and cache.vehicle then
        return true
    end

    local entity, distance, coords, name = restrictions.context(entry, group)

    if entry.distance and distance > entry.distance then
        return true
    end

    if entry.groups and not utils.hasPlayerGotGroup(entry.groups) then
        return true
    end

    if entry.items and not utils.hasPlayerGotItems(entry.items, entry.anyItem) then
        return true
    end

    if entry.canInteract then
        local success, result = pcall(entry.canInteract, entity, distance, coords, name)
        if not success or not result then
            return true
        end
    end

    return false
end

return restrictions
