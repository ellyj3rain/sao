NMLootDebugHelpers = NMLootDebugHelpers or {}

local helpers = NMLootDebugHelpers

local throttles = {
    skippedContainers = {},
    channelEvents = {}
}

local ROUTES = {
    standard = "standard",
    topUp = "topUp"
}

local RESULTS = {
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

local function shouldLogLoot()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("loot") == true
end

function helpers.getRouteKeys()
    return ROUTES
end

function helpers.getResultKeys()
    return RESULTS
end

function helpers.isKnownNonMutableContainerShape(container)
    local text = tostring(container or "")
    if text == "" then
        return false
    end
    return string.find(text, "ItemPickerJava$ItemPickerContainer@", 1, true) ~= nil
end

function helpers.safeCallMethod(target, methodName, ...)
    if target == nil then
        return nil
    end
    local args = { ... }
    local ok, result = pcall(function()
        local method = target[methodName]
        if type(method) ~= "function" then
            return nil
        end
        return method(target, unpack(args))
    end)
    if ok then
        return result
    end
    return nil
end

function helpers.logLoot(tag, detail)
    if shouldLogLoot() then
        NMCore.logChannel("loot", tostring(tag or "loot"), tostring(detail or ""))
    end
end

function helpers.logLootThrottled(bucketName, bucketKey, tag, detail)
    if not shouldLogLoot() then
        return false
    end
    local bucket = throttles.channelEvents[tostring(bucketName or "default")]
    if type(bucket) ~= "table" then
        bucket = {}
        throttles.channelEvents[tostring(bucketName or "default")] = bucket
    end
    local key = tostring(bucketKey or "")
    if bucket[key] == true then
        return false
    end
    bucket[key] = true
    NMCore.logChannel("loot", tostring(tag or "loot"), tostring(detail or ""))
    return true
end

function helpers.logSkippedContainer(container, reason, tag)
    if not shouldLogLoot() then
        return false
    end
    local shape = tostring(container or "nil")
    local key = tostring(reason or "unknown") .. "|" .. shape
    if throttles.skippedContainers[key] == true then
        return false
    end
    throttles.skippedContainers[key] = true
    NMCore.logChannel(
        "loot",
        tostring(tag or "loot.skip_container"),
        string.format("reason=%s shape=%s", tostring(reason or "unknown"), shape)
    )
    return true
end

function helpers.resolveMutableContainer(container, skipTag)
    if helpers.isKnownNonMutableContainerShape(container) then
        helpers.logSkippedContainer(container, "item_picker_container", skipTag)
        return nil, nil
    end

    local items = helpers.safeCallMethod(container, "getItems")
    if items and items.size and items.get then
        return container, items
    end

    local unwrapMethods = {
        "getActualContainer",
        "getContainer",
        "getInventory",
        "getItemContainer",
        "getActual"
    }
    for i = 1, #unwrapMethods do
        local resolved = helpers.safeCallMethod(container, unwrapMethods[i])
        if resolved ~= nil and resolved ~= container then
            if helpers.isKnownNonMutableContainerShape(resolved) then
                helpers.logSkippedContainer(resolved, "item_picker_container_unwrapped", skipTag)
            else
                items = helpers.safeCallMethod(resolved, "getItems")
                if items and items.size and items.get then
                    return resolved, items
                end
            end
        end
    end

    return nil, nil
end

function helpers.resolveContainerItems(container, skipTag)
    local _, items = helpers.resolveMutableContainer(container, skipTag)
    return items
end

function helpers.classifyRouteContext(roomName, containerType, classKey)
    local className = tostring(classKey or "")
    if className ~= "" then
        return className
    end
    local roomLower = toLower(roomName)
    local typeLower = toLower(containerType)
    if string.find(roomLower, "music", 1, true) or string.find(typeLower, "music", 1, true) then
        return "music_store"
    end
    if string.find(roomLower, "elect", 1, true) or string.find(typeLower, "elect", 1, true) then
        return "electronics"
    end
    if string.find(roomLower, "mail", 1, true) or string.find(typeLower, "mail", 1, true) then
        return "mail"
    end
    return "other"
end

function helpers.describeMinimalContainerContext(roomName, containerType, classKey)
    local resolvedRoom = tostring(roomName or "")
    local resolvedType = tostring(containerType or "")
    local routeClass = helpers.classifyRouteContext(resolvedRoom, resolvedType, classKey)
    return {
        roomName = resolvedRoom,
        containerType = resolvedType,
        routeClass = routeClass
    }
end

function helpers.describeFullContainerContext(roomName, containerType, container, classKey)
    local context = helpers.describeMinimalContainerContext(roomName, containerType, classKey)
    local parent = container and container.getParent and container:getParent() or nil
    local square = parent and parent.getSquare and parent:getSquare() or nil
    local x = square and square.getX and square:getX() or nil
    local y = square and square.getY and square:getY() or nil
    local z = square and square.getZ and square:getZ() or nil
    local parentType = parent and parent.getObjectName and tostring(parent:getObjectName() or "") or tostring(parent or "")
    context.parentType = parentType
    context.x = x
    context.y = y
    context.z = z
    context.shape = tostring(container or "nil")
    return context
end

function helpers.describeContainerContext(roomName, containerType, container, classKey)
    return helpers.describeFullContainerContext(roomName, containerType, container, classKey)
end

function helpers.formatContainerContext(context)
    local data = type(context) == "table" and context or {}
    local x = data.x ~= nil and tostring(data.x) or "?"
    local y = data.y ~= nil and tostring(data.y) or "?"
    local z = data.z ~= nil and tostring(data.z) or "?"
    return string.format(
        "room=%s type=%s class=%s parent=%s pos=%s,%s,%s shape=%s",
        tostring(data.roomName or ""),
        tostring(data.containerType or ""),
        tostring(data.routeClass or ""),
        tostring(data.parentType or ""),
        x,
        y,
        z,
        tostring(data.shape or "nil")
    )
end

return NMLootDebugHelpers
