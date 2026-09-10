local utils = {}

local POSITION_ALIASES = {
    top = 'top-center',
    bottom = 'bottom-center',
    left = 'middle-left',
    right = 'middle-right',
    middle = 'center',
    ['center-left'] = 'middle-left',
    ['center-right'] = 'middle-right',
    ['center-top'] = 'top-center',
    ['center-bottom'] = 'bottom-center',
    ['middle-center'] = 'center',
}

local POSITIONS = {
    ['top-left'] = true,
    ['top-center'] = true,
    ['top-right'] = true,
    ['middle-left'] = true,
    center = true,
    ['middle-right'] = true,
    ['bottom-left'] = true,
    ['bottom-center'] = true,
    ['bottom-right'] = true,
}

---@param variable string
---@param expected string
---@param received string
function utils.typeError(variable, expected, received)
    error(("expected %s to have type '%s' (received %s)"):format(variable, expected, received), 3)
end

---@param name string
---@return string
function utils.normalize(name)
    return name:lower():gsub('[^%w]', '')
end

---@param position string | table
---@return string | table
function utils.resolvePosition(position)
    local positionType = type(position)
    if positionType == 'table' then
        assert(position.x ~= nil and position.y ~= nil, 'custom position requires x and y')
        return {
            x = position.x,
            y = position.y,
            origin = position.origin or 'center',
        }
    end

    if positionType ~= 'string' then
        utils.typeError('position', 'string or table', positionType)
    end

    local resolved = POSITION_ALIASES[position] or position
    assert(POSITIONS[resolved], ("unknown position '%s'"):format(position))
    return resolved
end

---@param position string | table
---@param layout string
---@return string
function utils.resolveLayout(position, layout)
    if layout and layout ~= 'auto' then
        return layout
    end

    if type(position) == 'string' and (position == 'middle-left' or position == 'middle-right') then
        return 'column'
    end

    return 'row'
end

---@param resource string | nil
---@return string
function utils.owner(resource)
    return resource or GetInvokingResource() or cache.resource
end

---@param value any
---@return any[]
function utils.ensureArray(value)
    if value == nil then
        return {}
    end
    if type(value) == 'table' and table.type(value) == 'array' then
        return value
    end
    return { value }
end

---@param rgb number[]
---@return string
function utils.rgb(rgb)
    return ('%s, %s, %s'):format(rgb[1] or 0, rgb[2] or 0, rgb[3] or 0)
end

local playerItems = {}

function utils.getItems()
    return playerItems
end

---@param export string
---@return boolean
function utils.hasExport(export)
    local resource, exportName = string.strsplit('.', export)
    return pcall(function()
        return exports[resource][exportName]
    end)
end

---@param filter string | string[] | table<string, number>
---@return boolean
function utils.hasPlayerGotGroup(filter)
    return true
end

---@param filter string | string[] | table<string, number>
---@param hasAny boolean?
---@return boolean
function utils.hasPlayerGotItems(filter, hasAny)
    if not playerItems then return true end

    local filterType = type(filter)
    if filterType == 'string' then
        return (playerItems[filter] or 0) > 0
    end

    if filterType ~= 'table' then
        return not hasAny
    end

    local tabletype = table.type(filter)
    if tabletype == 'hash' then
        for name, amount in pairs(filter) do
            local hasItem = (playerItems[name] or 0) >= amount
            if hasAny then
                if hasItem then return true end
            elseif not hasItem then
                return false
            end
        end
    elseif tabletype == 'array' then
        for i = 1, #filter do
            local hasItem = (playerItems[filter[i]] or 0) > 0
            if hasAny then
                if hasItem then return true end
            elseif not hasItem then
                return false
            end
        end
    end

    return not hasAny
end

SetTimeout(0, function()
    if GetResourceState('ox_inventory'):find('start') then
        setmetatable(playerItems, {
            __index = function(self, index)
                self[index] = exports.ox_inventory:Search('count', index) or 0
                return self[index]
            end
        })

        AddEventHandler('ox_inventory:itemCount', function(name, count)
            playerItems[name] = count
        end)
    end

    if GetResourceState('ox_core'):find('start') then
        require 'client.framework.ox'
    elseif GetResourceState('es_extended'):find('start') then
        require 'client.framework.esx'
    elseif GetResourceState('qbx_core'):find('start') then
        require 'client.framework.qbx'
    elseif GetResourceState('ND_Core'):find('start') then
        require 'client.framework.nd'
    elseif GetResourceState('qb-core'):find('start') then
        require 'client.framework.qb'
    end
end)

return utils
