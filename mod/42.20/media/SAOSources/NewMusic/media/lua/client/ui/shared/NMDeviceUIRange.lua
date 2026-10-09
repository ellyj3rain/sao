NMDeviceUIRange = NMDeviceUIRange or {}

local WORLD_INTERACTION_RANGE_TILES = 2.8
local WORLD_INTERACTION_RANGE_SQ = WORLD_INTERACTION_RANGE_TILES * WORLD_INTERACTION_RANGE_TILES

local function resolveDetachedPlacedTargetPosition(target)
    if not (target and target.kind == "item") then
        return nil, nil
    end
    local uuid = tostring(target.uuid or "")
    if uuid == "" then
        return nil, nil
    end
    local cache = type(NMClientWorldSourceCache) == "table" and NMClientWorldSourceCache.entries or nil
    local entry = cache and cache[uuid] or nil
    local source = entry and entry.source or nil
    local context = tostring((source and source.context) or (entry and entry.sourceMode) or "")
    if context ~= "placed" then
        return nil, nil
    end
    if source and source.x ~= nil and source.y ~= nil then
        return tonumber(source.x) or 0, tonumber(source.y) or 0
    end
    return nil, nil
end

function NMDeviceUIRange.getWorldInteractionRangeTiles()
    return WORLD_INTERACTION_RANGE_TILES
end

function NMDeviceUIRange.getWorldInteractionRangeSq()
    return WORLD_INTERACTION_RANGE_SQ
end

function NMDeviceUIRange.isPlayerWithinSquare(player, square)
    if not player then
        return false
    end
    if not square then
        return true
    end
    if not player.DistToSquared then
        return true
    end
    local distSq = tonumber(player:DistToSquared(square:getX() + 0.5, square:getY() + 0.5)) or 999999
    return distSq <= WORLD_INTERACTION_RANGE_SQ
end

function NMDeviceUIRange.resolvePortableTargetLocation(target, item)
    local detachedX, detachedY = resolveDetachedPlacedTargetPosition(target)
    if detachedX ~= nil and detachedY ~= nil then
        return {
            mode = "detached_placed",
            x = detachedX,
            y = detachedY,
            requiresDistanceCheck = true
        }
    end

    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    if square then
        return {
            mode = "placed_world",
            square = square,
            x = square:getX() + 0.5,
            y = square:getY() + 0.5,
            requiresDistanceCheck = true
        }
    end

    local container = item and item.getContainer and item:getContainer() or nil
    if container then
        return {
            mode = "inventory",
            container = container,
            requiresDistanceCheck = false
        }
    end

    return {
        mode = "unresolved",
        requiresDistanceCheck = false
    }
end
