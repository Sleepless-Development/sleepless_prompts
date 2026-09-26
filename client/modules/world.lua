local store = require 'client.modules.store'
local config = require 'client.modules.config'
local utils = require 'client.modules.utils'
local restrictions = require 'client.modules.restrictions'

local world = {}

local SCAN_INTERVAL = 150
local COORD_PREFIX = 'world:coord:'
local ENTITY_PREFIX = 'world:entity:'

local reg = {
    coords = {},
    coordIds = {},
    localEntities = {},
    entities = {},
    models = {},
    peds = {},
    vehicles = {},
    objects = {},
    players = {},
    poolDistance = 0,
}

local running = false
local scanning = false
local nextAutoName = 0
local commit

local function hasAny()
    return next(reg.coords) ~= nil
        or next(reg.localEntities) ~= nil
        or next(reg.entities) ~= nil
        or next(reg.models) ~= nil
        or #reg.peds > 0
        or #reg.vehicles > 0
        or #reg.objects > 0
        or #reg.players > 0
end

local function bump(distance, maxDistance)
    if distance and distance > maxDistance then
        return distance
    end
    return maxDistance
end

local function listMax(list, maxDistance, intoPool)
    if not intoPool then return maxDistance end
    for i = 1, #list do
        maxDistance = bump(list[i].distance, maxDistance)
    end
    return maxDistance
end

local function recomputePoolDistance()
    local maxDistance = 0
    for _, options in pairs(reg.localEntities) do
        maxDistance = listMax(options, maxDistance, true)
    end
    for _, options in pairs(reg.entities) do
        maxDistance = listMax(options, maxDistance, true)
    end
    for _, options in pairs(reg.models) do
        maxDistance = listMax(options, maxDistance, true)
    end
    maxDistance = listMax(reg.peds, maxDistance, true)
    maxDistance = listMax(reg.vehicles, maxDistance, true)
    maxDistance = listMax(reg.objects, maxDistance, true)
    maxDistance = listMax(reg.players, maxDistance, true)
    reg.poolDistance = maxDistance
end

---@param coords vector3
---@return string
local function makeCoordId(coords)
    local x = math.floor(coords.x * 1000)
    local y = math.floor(coords.y * 1000)
    local z = math.floor(coords.z * 1000)
    return ('%s_%s_%s'):format(x, y, z)
end

---@param value any
---@return vector3?
local function asVector(value)
    local valueType = type(value)
    if valueType == 'vector3' then return value end
    if valueType == 'vector4' then return vec3(value.x, value.y, value.z) end
    if valueType ~= 'table' then return end
    if value.x and value.y and value.z then
        return vec3(value.x, value.y, value.z)
    end
end

---@param coords vector3 | vector4 | vector3[] | table
---@return vector3[]
local function coordList(coords)
    local coordsType = type(coords)
    if coordsType == 'vector3' or coordsType == 'vector4' then
        return { asVector(coords) }
    end
    if coordsType ~= 'table' then
        utils.typeError('coords', 'vector3 or vector3[]', coordsType)
    end

    if table.type(coords) == 'array' then
        local first = coords[1]
        if type(first) == 'number' and #coords == 3 then
            return { vec3(coords[1], coords[2], coords[3]) }
        end

        local list = {}
        for i = 1, #coords do
            local point = asVector(coords[i])
            if not point then
                utils.typeError('coords', 'vector3', type(coords[i]))
            end
            list[i] = point
        end
        return list
    end

    local point = asVector(coords)
    if not point then
        utils.typeError('coords', 'vector3', coordsType)
    end
    return { point }
end

---@param value any
---@return table[]
local function checkOptions(value)
    local valueType = type(value)
    if valueType ~= 'table' then
        utils.typeError('options', 'table', valueType)
    end

    local tableType = table.type(value)
    if tableType == 'hash' and value.label then
        return { value }
    end
    if tableType ~= 'array' then
        utils.typeError('options', 'array', ('%s table'):format(tableType))
    end
    return value
end

---@param settings? table
---@return table?
local function normalizeSettings(settings)
    if settings == nil then return end
    if type(settings) ~= 'table' then
        utils.typeError('settings', 'table', type(settings))
    end

    return {
        position = settings.position and utils.resolvePosition(settings.position) or nil,
        layout = settings.layout,
        separator = settings.separator,
        offset = settings.offset,
        order = settings.order,
        distance = settings.distance,
    }
end

---@param option table
---@param resource string
---@param view? table
---@return table
local function prepareOption(option, resource, view)
    local copy = table.clone(option)
    copy.resource = resource
    copy.distance = copy.distance or (view and view.distance) or config.defaultPromptDistance

    if not copy.name and not copy.id then
        nextAutoName += 1
        copy.name = ('prompt_%s'):format(nextAutoName)
    end

    if view and (view.position or view.layout or view.separator or view.offset or view.order) then
        copy._view = view
    end

    assert(copy.label, 'prompt.label is required')
    assert(
        type(copy.control) == 'number' or copy.keybind or copy.key or copy.keyboard or copy.gamepad or copy.icon,
        'prompt needs control, keybind, key, keyboard, gamepad, or icon'
    )

    return copy
end

---@param remove? string | string[]
---@return string[]?
local function nameList(remove)
    if remove == nil then return end
    if type(remove) ~= 'table' then return { remove } end
    return remove
end

---@param list table
---@param resource string
---@param names? string[]
local function removeFromList(list, resource, names)
    if not list then return end

    local nameSet
    if names then
        nameSet = {}
        for i = 1, #names do
            nameSet[names[i]] = true
        end
    end

    for i = #list, 1, -1 do
        local option = list[i]
        if option.resource == resource and (not nameSet or nameSet[option.name]) then
            table.remove(list, i)
        end
    end
end

---@param list table
---@param options table
---@param resource string
---@param view? table
local function addOptions(list, options, resource, view)
    options = checkOptions(options)
    local prepared = {}
    local names = {}
    local nameCount = 0

    for i = 1, #options do
        local option = prepareOption(options[i], resource, view)
        prepared[i] = option
        if option.name then
            nameCount += 1
            names[nameCount] = option.name
        end
    end

    if nameCount > 0 then
        removeFromList(list, resource, names)
    end

    for i = 1, #prepared do
        list[#list + 1] = prepared[i]
    end
end

local function resourceOwner()
    return GetInvokingResource() or cache.resource
end

---@param id string
---@param resource string
---@param names? string[]
local function removeCoordId(id, resource, names)
    if not reg.coords[id] then
        warn(('attempted to remove a coord that does not exist (id: %s)'):format(id))
        return
    end

    removeFromList(reg.coords[id], resource, names)
    if #reg.coords[id] == 0 then
        reg.coords[id] = nil
        reg.coordIds[id] = nil
    end
end

---@param id string | string[]
---@param remove? string | string[]
function world.removeCoords(id, remove)
    local resource = resourceOwner()
    local names = nameList(remove)

    if type(id) == 'table' then
        for i = 1, #id do
            removeCoordId(id[i], resource, names)
        end
    else
        removeCoordId(id, resource, names)
    end

    commit()
end

---@param coords vector3 | vector3[]
---@param options table
---@param settings? table
---@return string | string[]
function world.addCoords(coords, options, settings)
    local points = coordList(coords)
    local resource = resourceOwner()
    local view = normalizeSettings(settings)
    local ids = {}

    for i = 1, #points do
        local point = points[i]
        local id = makeCoordId(point)
        reg.coords[id] = reg.coords[id] or {}
        reg.coordIds[id] = point
        addOptions(reg.coords[id], table.clone(options), resource, view)
        ids[i] = id
    end

    commit()
    return (#ids == 1 and ids[1]) or ids
end

---@param ids number | number[]
---@param remove? string | string[]
---@param bucket table
local function removeEntities(ids, remove, bucket)
    if type(ids) ~= 'table' then ids = { ids } end
    local resource = resourceOwner()
    local names = nameList(remove)

    for i = 1, #ids do
        local id = ids[i]
        removeFromList(bucket[id], resource, names)
        if bucket[id] and #bucket[id] == 0 then
            bucket[id] = nil
        end
    end
    commit()
end

---@param ids number | number[]
---@param options table
---@param settings? table
---@param bucket table
---@param exists fun(id: number): boolean
---@param missing string
local function addEntities(ids, options, settings, bucket, exists, missing)
    if type(ids) ~= 'table' then ids = { ids } end
    local resource = resourceOwner()
    local view = normalizeSettings(settings)

    for i = 1, #ids do
        local id = ids[i]
        if exists(id) then
            bucket[id] = bucket[id] or {}
            addOptions(bucket[id], table.clone(options), resource, view)
        else
            lib.print.warn(missing:format(id))
        end
    end
    commit()
end

---@param netIds number | number[]
---@param options table
---@param settings? table
function world.addEntity(netIds, options, settings)
    if type(netIds) ~= 'table' then netIds = { netIds } end
    local resource = resourceOwner()
    local view = normalizeSettings(settings)

    for i = 1, #netIds do
        local netId = netIds[i]
        if netId then
            reg.entities[netId] = reg.entities[netId] or {}
            addOptions(reg.entities[netId], table.clone(options), resource, view)
        end
    end
    commit()
end

---@param netIds number | number[]
---@param remove? string | string[]
function world.removeEntity(netIds, remove)
    removeEntities(netIds, remove, reg.entities)
end

---@param entityIds number | number[]
---@param options table
---@param settings? table
function world.addLocalEntity(entityIds, options, settings)
    addEntities(entityIds, options, settings, reg.localEntities, function(entityId)
        return entityId and DoesEntityExist(entityId)
    end, 'No entity with id "%s" exists.')
end

---@param entityIds number | number[]
---@param remove? string | string[]
function world.removeLocalEntity(entityIds, remove)
    removeEntities(entityIds, remove, reg.localEntities)
end

---@param models number | string | (number | string)[]
---@return number[]
local function modelList(models)
    if type(models) ~= 'table' then models = { models } end
    local list = {}
    for i = 1, #models do
        local model = models[i]
        list[i] = tonumber(model) or joaat(model)
    end
    return list
end

---@param models number | string | (number | string)[]
---@param options table
---@param settings? table
function world.addModel(models, options, settings)
    local hashes = modelList(models)
    local resource = resourceOwner()
    local view = normalizeSettings(settings)

    for i = 1, #hashes do
        local model = hashes[i]
        reg.models[model] = reg.models[model] or {}
        addOptions(reg.models[model], table.clone(options), resource, view)
    end
    commit()
end

---@param models number | string | (number | string)[]
---@param remove? string | string[]
function world.removeModel(models, remove)
    local hashes = modelList(models)
    local resource = resourceOwner()
    local names = nameList(remove)

    for i = 1, #hashes do
        local model = hashes[i]
        removeFromList(reg.models[model], resource, names)
        if reg.models[model] and #reg.models[model] == 0 then
            reg.models[model] = nil
        end
    end
    commit()
end

---@param bucketName string
---@param options table
---@param settings? table
local function addGlobal(bucketName, options, settings)
    addOptions(reg[bucketName], options, resourceOwner(), normalizeSettings(settings))
    commit()
end

---@param bucketName string
---@param remove? string | string[]
local function removeGlobal(bucketName, remove)
    removeFromList(reg[bucketName], resourceOwner(), nameList(remove))
    commit()
end

function world.addGlobalPed(options, settings)
    addGlobal('peds', options, settings)
end

function world.removeGlobalPed(remove)
    removeGlobal('peds', remove)
end

function world.addGlobalVehicle(options, settings)
    addGlobal('vehicles', options, settings)
end

function world.removeGlobalVehicle(remove)
    removeGlobal('vehicles', remove)
end

function world.addGlobalObject(options, settings)
    addGlobal('objects', options, settings)
end

function world.removeGlobalObject(remove)
    removeGlobal('objects', remove)
end

function world.addGlobalPlayer(options, settings)
    addGlobal('players', options, settings)
end

function world.removeGlobalPlayer(remove)
    removeGlobal('players', remove)
end

---@param resource string
local function removeResource(resource)
    for id, options in pairs(reg.coords) do
        removeFromList(options, resource)
        if #options == 0 then
            reg.coords[id] = nil
            reg.coordIds[id] = nil
        end
    end

    for entityId, options in pairs(reg.localEntities) do
        removeFromList(options, resource)
        if #options == 0 then
            reg.localEntities[entityId] = nil
        end
    end

    for netId, options in pairs(reg.entities) do
        removeFromList(options, resource)
        if #options == 0 then
            reg.entities[netId] = nil
        end
    end

    for model, options in pairs(reg.models) do
        removeFromList(options, resource)
        if #options == 0 then
            reg.models[model] = nil
        end
    end

    removeFromList(reg.peds, resource)
    removeFromList(reg.vehicles, resource)
    removeFromList(reg.objects, resource)
    removeFromList(reg.players, resource)
end

---@param options table
---@param entity number
---@param coords vector3
---@param distSq number
---@return table?
local function filterOptions(options, entity, coords, distSq)
    local valid
    local count = 0
    local probe = { entity = entity, coords = coords }

    for i = 1, #options do
        local option = options[i]
        local limit = option.distance
        if limit and distSq <= limit * limit and not restrictions.blocked(option, probe) then
            count += 1
            valid = valid or {}
            valid[count] = option
        end
    end

    return valid
end

---@param dest table?
---@param options table?
---@param entity number
---@param coords vector3
---@param distSq number
---@return table?
local function appendFiltered(dest, options, entity, coords, distSq)
    if not options or #options == 0 then return dest end
    local valid = filterOptions(options, entity, coords, distSq)
    if not valid then return dest end

    dest = dest or {}
    for i = 1, #valid do
        dest[#dest + 1] = valid[i]
    end
    return dest
end

---@param options table
local function assignIds(options)
    local seen = {}
    for i = 1, #options do
        local option = options[i]
        local id = option.id or option.name or ('prompt_%s'):format(i)
        if seen[id] then
            id = ('%s:%s'):format(id, option.resource or i)
        end
        option.id = id
        seen[id] = true
    end
end

---@param options table
---@return table?
local function viewOf(options)
    for i = 1, #options do
        local view = options[i]._view
        if view then return view end
    end
end

---@param a table?
---@param b table?
---@return boolean
local function sameRefs(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

---@param groupId string
---@param entity? number
---@param coords vector3
---@param coordId? string
---@param options table
---@param distance number
local function present(groupId, entity, coords, coordId, options, distance)
    assignIds(options)
    local existing = store.groups[groupId]
    if existing and existing._nearby and sameRefs(existing._optionRefs, options) then
        existing.entity = entity
        existing.coords = coords
        existing.coordId = coordId
        existing.distance = distance
        return
    end

    local view = viewOf(options)
    prompts.show(groupId, {
        resource = cache.resource,
        position = (view and view.position) or config.defaultPosition,
        offset = view and view.offset or nil,
        layout = view and view.layout or nil,
        separator = view and view.separator or nil,
        order = view and view.order or nil,
        entity = entity,
        coords = coords,
        prompts = options,
    })

    local group = store.groups[groupId]
    group._nearby = true
    group._optionRefs = options
    group.coordId = coordId
    group.distance = distance
end

local function hideStale(active)
    local remove = {}
    local count = 0
    for id, group in pairs(store.groups) do
        if group._nearby and not active[id] then
            count += 1
            remove[count] = id
        end
    end
    for i = 1, count do
        prompts.hide(remove[i])
    end
end

---@param candidates table
---@param seen table
---@param entity number
---@param coords vector3
---@param globalType string
local function consider(candidates, seen, entity, coords, globalType)
    if not entity or entity == 0 or seen[entity] then return end
    if not DoesEntityExist(entity) then return end
    seen[entity] = true

    local model = GetEntityModel(entity)
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or nil
    local dx = coords.x
    local dy = coords.y
    local dz = coords.z

    candidates[#candidates + 1] = {
        entity = entity,
        coords = coords,
        model = model,
        netId = netId,
        globalType = globalType,
        _x = dx,
        _y = dy,
        _z = dz,
    }
end

local function entityTypeName(entity)
    if IsPedAPlayer(entity) then return 'players' end
    local entityType = GetEntityType(entity)
    if entityType == 1 then return 'peds' end
    if entityType == 2 then return 'vehicles' end
    if entityType == 3 then return 'objects' end
end

local function scan()
    local active = {}
    local ped = cache.ped
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        hideStale(active)
        return
    end

    local playerCoords = GetEntityCoords(ped)
    local poolDistance = reg.poolDistance

    for id, coords in pairs(reg.coordIds) do
        local options = reg.coords[id]
        if options and #options > 0 then
            local dx = playerCoords.x - coords.x
            local dy = playerCoords.y - coords.y
            local dz = playerCoords.z - coords.z
            local distSq = dx * dx + dy * dy + dz * dz
            local valid = filterOptions(options, 0, coords, distSq)
            if valid then
                local groupId = COORD_PREFIX .. id
                active[groupId] = true
                present(groupId, nil, coords, id, valid, math.sqrt(distSq))
            end
        end
    end

    local candidates = {}
    local seen = {}

    if poolDistance > 0 then
        local hasModels = next(reg.models) ~= nil

        if hasModels or #reg.objects > 0 then
            local nearby = lib.getNearbyObjects(playerCoords, poolDistance)
            for i = 1, #nearby do
                local item = nearby[i]
                consider(candidates, seen, item.object, item.coords, 'objects')
            end
        end

        if hasModels or #reg.vehicles > 0 then
            local nearby = lib.getNearbyVehicles(playerCoords, poolDistance, true)
            for i = 1, #nearby do
                local item = nearby[i]
                consider(candidates, seen, item.vehicle, item.coords, 'vehicles')
            end
        end

        if hasModels or #reg.peds > 0 then
            local nearby = lib.getNearbyPeds(playerCoords, poolDistance)
            for i = 1, #nearby do
                local item = nearby[i]
                consider(candidates, seen, item.ped, item.coords, 'peds')
            end
        end

        if hasModels or #reg.players > 0 then
            local nearby = lib.getNearbyPlayers(playerCoords, poolDistance, false)
            for i = 1, #nearby do
                local item = nearby[i]
                consider(candidates, seen, item.ped, item.coords, 'players')
            end
        end
    end

    for entityId in pairs(reg.localEntities) do
        if DoesEntityExist(entityId) and not seen[entityId] then
            local globalType = entityTypeName(entityId)
            if globalType then
                consider(candidates, seen, entityId, GetEntityCoords(entityId), globalType)
            end
        end
    end

    for netId in pairs(reg.entities) do
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            local globalType = entity and entityTypeName(entity)
            if globalType and not seen[entity] then
                consider(candidates, seen, entity, GetEntityCoords(entity), globalType)
            end
        end
    end

    local closestType = {}
    local closestModel = {}
    local playerX, playerY, playerZ = playerCoords.x, playerCoords.y, playerCoords.z

    for i = 1, #candidates do
        local candidate = candidates[i]
        local dx = playerX - candidate._x
        local dy = playerY - candidate._y
        local dz = playerZ - candidate._z
        candidate.distSq = dx * dx + dy * dy + dz * dz

        if candidate.entity ~= cache.ped then
            local typeBest = closestType[candidate.globalType]
            if not typeBest or candidate.distSq < typeBest.distSq then
                closestType[candidate.globalType] = candidate
            end

            local modelBest = closestModel[candidate.model]
            if not modelBest or candidate.distSq < modelBest.distSq then
                closestModel[candidate.model] = candidate
            end
        end
    end

    for i = 1, #candidates do
        local candidate = candidates[i]
        local merged

        merged = appendFiltered(merged, reg.localEntities[candidate.entity], candidate.entity, candidate.coords, candidate.distSq)

        if candidate.netId then
            merged = appendFiltered(merged, reg.entities[candidate.netId], candidate.entity, candidate.coords, candidate.distSq)
        end

        if closestModel[candidate.model] == candidate then
            merged = appendFiltered(merged, reg.models[candidate.model], candidate.entity, candidate.coords, candidate.distSq)
        end

        if closestType[candidate.globalType] == candidate then
            merged = appendFiltered(merged, reg[candidate.globalType], candidate.entity, candidate.coords, candidate.distSq)
        end

        if merged then
            local groupId = ENTITY_PREFIX .. candidate.entity
            active[groupId] = true
            present(groupId, candidate.entity, candidate.coords, nil, merged, math.sqrt(candidate.distSq))
        end
    end

    hideStale(active)
end

local function hideWorldGroups()
    local remove = {}
    local count = 0
    for id, group in pairs(store.groups) do
        if group._nearby then
            count += 1
            remove[count] = id
        end
    end
    for i = 1, count do
        prompts.hide(remove[i])
    end
end

function world.refresh()
    recomputePoolDistance()
    if not hasAny() then
        hideWorldGroups()
        return
    end
    if scanning then return end
    scanning = true
    local ok, err = pcall(scan)
    scanning = false
    if not ok then
        lib.print.error(err)
    end
end

local function kick()
    if running then
        world.refresh()
        return
    end
    if not hasAny() then
        hideWorldGroups()
        return
    end

    running = true
    world.refresh()
    CreateThread(function()
        while hasAny() do
            Wait(SCAN_INTERVAL)
            if not hasAny() then break end
            world.refresh()
        end
        running = false
        if hasAny() then
            kick()
            return
        end
        hideWorldGroups()
    end)
end

function commit()
    kick()
end

CreateThread(function()
    while true do
        Wait(60000)
        for entityId in pairs(reg.localEntities) do
            if not DoesEntityExist(entityId) then
                reg.localEntities[entityId] = nil
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == cache.resource then return end
    removeResource(resource)
    if running then
        world.refresh()
    end
end)

return world
