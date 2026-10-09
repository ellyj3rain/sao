require "loot/NMLootDebugHelpers"

NMLootDistributionUtils = NMLootDistributionUtils or {}

local utils = NMLootDistributionUtils

local LOOT_RESULT_KEYS = NMLootDebugHelpers and NMLootDebugHelpers.getResultKeys and NMLootDebugHelpers.getResultKeys() or {
    inserted = "inserted",
    increased = "increased",
    alreadyPresent = "already_present",
    replaced = "replaced",
    skipped = "skipped",
    rejected = "rejected"
}

local function toLower(value)
    return string.lower(tostring(value or ""))
end

function utils.listHasItem(items, fullType)
    if type(items) ~= "table" then
        return false
    end
    for i = 1, #items, 2 do
        if tostring(items[i]) == fullType then
            return true
        end
    end
    return false
end

function utils.addItemIfMissing(items, fullType, weight)
    if type(items) ~= "table" then
        return false
    end
    if utils.listHasItem(items, fullType) then
        return false
    end
    table.insert(items, fullType)
    table.insert(items, weight)
    return true
end

function utils.ensureListMembershipIndex(indexCache, items)
    if type(items) ~= "table" or type(indexCache) ~= "table" then
        return nil
    end
    local index = indexCache[items]
    if type(index) == "table" then
        return index
    end
    index = {}
    for i = 1, #items, 2 do
        local fullType = tostring(items[i] or "")
        if fullType ~= "" then
            index[fullType] = true
        end
    end
    indexCache[items] = index
    return index
end

function utils.addItemIfMissingCached(items, fullType, weight, indexCache)
    if type(items) ~= "table" then
        return false
    end
    local index = utils.ensureListMembershipIndex(indexCache, items)
    if index and index[fullType] then
        return false
    end
    table.insert(items, fullType)
    table.insert(items, weight)
    if index then
        index[fullType] = true
    end
    return true
end

function utils.addItemIfMissingCachedWithResult(items, fullType, weight, indexCache)
    if type(items) ~= "table" then
        return LOOT_RESULT_KEYS.skipped
    end
    local index = utils.ensureListMembershipIndex(indexCache, items)
    if index and index[fullType] then
        return LOOT_RESULT_KEYS.alreadyPresent
    end
    table.insert(items, fullType)
    table.insert(items, weight)
    if index then
        index[fullType] = true
    end
    return LOOT_RESULT_KEYS.inserted
end

function utils.addOrIncreaseItemWeight(items, fullType, weight, indexCache)
    if type(items) ~= "table" then
        return false
    end
    local numericWeight = tonumber(weight) or 0
    if numericWeight <= 0 then
        return false
    end
    for i = 1, #items, 2 do
        if tostring(items[i] or "") == fullType then
            items[i + 1] = (tonumber(items[i + 1]) or 0) + numericWeight
            return true
        end
    end
    table.insert(items, fullType)
    table.insert(items, numericWeight)
    local index = utils.ensureListMembershipIndex(indexCache, items)
    if index then
        index[fullType] = true
    end
    return true
end

function utils.addOrIncreaseItemWeightWithResult(items, fullType, weight, indexCache)
    if type(items) ~= "table" then
        return LOOT_RESULT_KEYS.skipped
    end
    local numericWeight = tonumber(weight) or 0
    if numericWeight <= 0 then
        return LOOT_RESULT_KEYS.rejected
    end
    for i = 1, #items, 2 do
        if tostring(items[i] or "") == fullType then
            items[i + 1] = (tonumber(items[i + 1]) or 0) + numericWeight
            return LOOT_RESULT_KEYS.increased
        end
    end
    table.insert(items, fullType)
    table.insert(items, numericWeight)
    local index = utils.ensureListMembershipIndex(indexCache, items)
    if index then
        index[fullType] = true
    end
    return LOOT_RESULT_KEYS.inserted
end

function utils.ensureListWeightPositionIndex(indexCache, items)
    if type(items) ~= "table" or type(indexCache) ~= "table" then
        return nil
    end
    local index = indexCache[items]
    if type(index) == "table" then
        return index
    end
    index = {}
    for i = 1, #items, 2 do
        local fullType = tostring(items[i] or "")
        if fullType ~= "" then
            index[fullType] = index[fullType] or {}
            index[fullType][#index[fullType] + 1] = i + 1
        end
    end
    indexCache[items] = index
    return index
end

function utils.applyIndexedItemMultiplierInList(items, fullType, multiplier, indexCache)
    if type(items) ~= "table" then
        return 0
    end
    local index = utils.ensureListWeightPositionIndex(indexCache, items)
    local positions = index and index[fullType] or nil
    if type(positions) ~= "table" then
        return 0
    end
    local touched = 0
    for i = 1, #positions do
        local weightIndex = positions[i]
        if type(items[weightIndex]) == "number" then
            items[weightIndex] = math.max(0, items[weightIndex] * multiplier)
            touched = touched + 1
        end
    end
    return touched
end

function utils.removeItemFromListByType(items, fullType)
    if type(items) ~= "table" then
        return nil
    end
    for i = #items - 1, 1, -2 do
        if tostring(items[i]) == fullType and type(items[i + 1]) == "number" then
            local weight = items[i + 1]
            table.remove(items, i + 1)
            table.remove(items, i)
            return tonumber(weight) or 0
        end
    end
    return nil
end

function utils.replaceItemInList(items, oldFullType, newFullType)
    if type(items) ~= "table" then
        return 0
    end
    if tostring(oldFullType or "") == "" or tostring(newFullType or "") == "" then
        return 0
    end
    local touched = 0
    while true do
        local weight = utils.removeItemFromListByType(items, oldFullType)
        if weight == nil then
            break
        end
        local replaced = false
        for i = 1, #items, 2 do
            if tostring(items[i]) == newFullType and type(items[i + 1]) == "number" then
                items[i + 1] = math.max(0, items[i + 1] + weight)
                replaced = true
                break
            end
        end
        if not replaced then
            table.insert(items, newFullType)
            table.insert(items, math.max(0, weight))
        end
        touched = touched + 1
    end
    return touched
end

function utils.resolveVehicleContainerRole(key)
    local lower = toLower(key)
    if lower == "glovebox" then
        return "glovebox"
    end
    if lower == "seatrear" or lower == "seatrearleft" or lower == "seatrearright" or lower == "seatrearcenter" then
        return "seatrear"
    end
    if lower == "trunk" or lower == "trailertrunk" or lower == "truckbed" or lower == "truckbedopen" or lower == "truckbed2" then
        return "cargo"
    end
    return nil
end

function utils.visitVehicleDistributionTables(callback)
    if not VehicleDistributions then
        return
    end

    local visited = {}
    local function visit(node)
        if type(node) ~= "table" or visited[node] then
            return
        end
        visited[node] = true

        if type(node.items) == "table" then
            callback(node.items)
        end

        for key, value in pairs(node) do
            if key ~= "items" and key ~= "junk" and key ~= "rolls" and type(value) == "table" then
                visit(value)
            end
        end
    end

    visit(VehicleDistributions)
end

function utils.collectAllowedVehicleTargets()
    local targets = {}
    if not VehicleDistributions then
        return targets
    end

    local visited = {}
    local seenItems = {}

    local function addTarget(role, items)
        if not role or type(items) ~= "table" then
            return
        end
        seenItems[role] = seenItems[role] or {}
        if seenItems[role][items] then
            return
        end
        seenItems[role][items] = true
        targets[#targets + 1] = { role = role, items = items }
    end

    local function visit(node, activeRole)
        if type(node) ~= "table" then
            return
        end

        local visitKey = tostring(activeRole or "__none")
        visited[node] = visited[node] or {}
        if visited[node][visitKey] then
            return
        end
        visited[node][visitKey] = true

        if activeRole and type(node.items) == "table" then
            addTarget(activeRole, node.items)
        end

        for key, value in pairs(node) do
            if key ~= "items" and key ~= "junk" and key ~= "rolls" and type(value) == "table" then
                local nextRole = activeRole or utils.resolveVehicleContainerRole(key)
                visit(value, nextRole)
            end
        end
    end

    visit(VehicleDistributions, nil)
    return targets
end

function utils.visitDistributionTables(callback)
    if type(callback) ~= "function" then
        return
    end
    if ProceduralDistributions and ProceduralDistributions.list then
        for _, dist in pairs(ProceduralDistributions.list) do
            if type(dist) == "table" and type(dist.items) == "table" then
                callback(dist.items)
            end
            if type(dist) == "table" and type(dist.junk) == "table" and type(dist.junk.items) == "table" then
                callback(dist.junk.items)
            end
        end
    end
    if SuburbsDistributions then
        for _, location in pairs(SuburbsDistributions) do
            if type(location) == "table" then
                for _, room in pairs(location) do
                    if type(room) == "table" then
                        if type(room.items) == "table" then callback(room.items) end
                        if type(room.counter) == "table" and type(room.counter.items) == "table" then callback(room.counter.items) end
                        if type(room.metal_shelves) == "table" and type(room.metal_shelves.items) == "table" then callback(room.metal_shelves.items) end
                        if type(room.shelves) == "table" and type(room.shelves.items) == "table" then callback(room.shelves.items) end
                        if type(room.crate) == "table" and type(room.crate.items) == "table" then callback(room.crate.items) end
                    end
                end
            end
        end
    end
    utils.visitVehicleDistributionTables(callback)
end

function utils.markListItems(indexMap, items)
    if type(items) ~= "table" then
        return
    end
    for i = 1, #items, 2 do
        indexMap[tostring(items[i])] = true
    end
end

function utils.buildDistributionPresenceIndex(vehicleTargets)
    local index = {
        procedural = {},
        suburbs = {},
        vehicle = {}
    }

    if ProceduralDistributions and ProceduralDistributions.list then
        for _, dist in pairs(ProceduralDistributions.list) do
            if type(dist) == "table" and type(dist.items) == "table" then
                utils.markListItems(index.procedural, dist.items)
            end
            if type(dist) == "table" and type(dist.junk) == "table" and type(dist.junk.items) == "table" then
                utils.markListItems(index.procedural, dist.junk.items)
            end
        end
    end

    if SuburbsDistributions then
        for _, location in pairs(SuburbsDistributions) do
            if type(location) == "table" then
                for _, room in pairs(location) do
                    if type(room) == "table" then
                        utils.markListItems(index.suburbs, room.items)
                        if type(room.counter) == "table" then utils.markListItems(index.suburbs, room.counter.items) end
                        if type(room.metal_shelves) == "table" then utils.markListItems(index.suburbs, room.metal_shelves.items) end
                        if type(room.shelves) == "table" then utils.markListItems(index.suburbs, room.shelves.items) end
                        if type(room.crate) == "table" then utils.markListItems(index.suburbs, room.crate.items) end
                    end
                end
            end
        end
    end

    for i = 1, #(vehicleTargets or {}) do
        utils.markListItems(index.vehicle, vehicleTargets[i].items)
    end

    return index
end

function utils.collectUniqueDistributionTables(vehicleTargets)
    local targets = {}
    local seen = {}

    local function add(items)
        if type(items) ~= "table" or seen[items] then
            return
        end
        seen[items] = true
        targets[#targets + 1] = items
    end

    if ProceduralDistributions and ProceduralDistributions.list then
        for _, dist in pairs(ProceduralDistributions.list) do
            if type(dist) == "table" and type(dist.items) == "table" then
                add(dist.items)
            end
            if type(dist) == "table" and type(dist.junk) == "table" and type(dist.junk.items) == "table" then
                add(dist.junk.items)
            end
        end
    end

    if SuburbsDistributions then
        for _, location in pairs(SuburbsDistributions) do
            if type(location) == "table" then
                for _, room in pairs(location) do
                    if type(room) == "table" then
                        add(room.items)
                        if type(room.counter) == "table" then add(room.counter.items) end
                        if type(room.metal_shelves) == "table" then add(room.metal_shelves.items) end
                        if type(room.shelves) == "table" then add(room.shelves.items) end
                        if type(room.crate) == "table" then add(room.crate.items) end
                    end
                end
            end
        end
    end

    for i = 1, #(vehicleTargets or {}) do
        add(vehicleTargets[i].items)
    end

    return targets
end

function utils.hasAnyPresence(presence)
    return (presence and (presence.procedural or presence.suburbs or presence.vehicle)) == true
end

function utils.analyzeItemPresence(itemSet, presenceIndex)
    local presence = { procedural = false, suburbs = false, vehicle = false }
    local present = {}
    local missing = {}

    for fullType, category in pairs(itemSet or {}) do
        local inProcedural = presenceIndex.procedural[fullType] == true
        local inSuburbs = presenceIndex.suburbs[fullType] == true
        local inVehicle = presenceIndex.vehicle[fullType] == true
        if inProcedural then
            presence.procedural = true
        end
        if inSuburbs then
            presence.suburbs = true
        end
        if inVehicle then
            presence.vehicle = true
        end
        if inProcedural or inSuburbs or inVehicle then
            present[fullType] = category
        else
            missing[fullType] = category
        end
    end

    return presence, present, missing
end

function utils.applyMultipliersForItems(itemSet, distributionTables, multiplierIndexCache, resolveCategoryMultiplier)
    local touched = 0
    local multiplierByItem = {}
    for fullType, category in pairs(itemSet or {}) do
        local multiplier = resolveCategoryMultiplier(category)
        if tonumber(multiplier) and tonumber(multiplier) ~= 1 then
            multiplierByItem[fullType] = tonumber(multiplier)
        end
    end
    for i = 1, #(distributionTables or {}) do
        local items = distributionTables[i]
        if type(items) == "table" then
            for j = 1, #items, 2 do
                local multiplier = multiplierByItem[tostring(items[j] or "")]
                if multiplier and type(items[j + 1]) == "number" then
                    items[j + 1] = math.max(0, items[j + 1] * multiplier)
                    touched = touched + 1
                end
            end
        end
    end
    return touched
end

function utils.injectIntoProcedural(listName, fullType, weight, indexCache)
    if not (ProceduralDistributions and ProceduralDistributions.list) then
        return false
    end
    local list = ProceduralDistributions.list[listName]
    if not (type(list) == "table" and type(list.items) == "table") then
        return false
    end
    return utils.addItemIfMissingCached(list.items, fullType, weight, indexCache)
end

function utils.injectIntoProceduralAdditive(listName, fullType, weight, indexCache)
    if not (ProceduralDistributions and ProceduralDistributions.list) then
        return false
    end
    local list = ProceduralDistributions.list[listName]
    if not (type(list) == "table" and type(list.items) == "table") then
        return false
    end
    return utils.addOrIncreaseItemWeight(list.items, fullType, weight, indexCache)
end

function utils.injectIntoSuburbsTopLevel(listName, fullType, weight, indexCache)
    if not SuburbsDistributions then
        return false
    end
    local list = SuburbsDistributions[listName]
    if not (type(list) == "table" and type(list.items) == "table") then
        return false
    end
    return utils.addItemIfMissingCached(list.items, fullType, weight, indexCache)
end

function utils.injectIntoSuburbsTopLevelAdditive(listName, fullType, weight, indexCache)
    if not SuburbsDistributions then
        return false
    end
    local list = SuburbsDistributions[listName]
    if not (type(list) == "table" and type(list.items) == "table") then
        return false
    end
    return utils.addOrIncreaseItemWeight(list.items, fullType, weight, indexCache)
end

function utils.rewriteBoundMediaSpawnsToContainers(mediaToContainer)
    local touched = 0
    utils.visitDistributionTables(function(items)
        for mediaFullType, containerFullType in pairs(mediaToContainer or {}) do
            touched = touched + utils.replaceItemInList(items, mediaFullType, containerFullType)
        end
    end)
    return touched
end

return utils
