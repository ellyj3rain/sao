NMClientPlacedWorldCandidate = NMClientPlacedWorldCandidate or {}

local SEARCH_RADIUS = 8

local function itemIdString(item)
    return item and item.getID and tostring(item:getID() or "") or ""
end

local function itemUuidString(item)
    return NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and tostring(NMInventoryHelpers.getItemStateUuid(item) or "") or ""
end

local function inspectItem(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    return {
        item = item,
        itemId = itemIdString(item),
        uuid = itemUuidString(item),
        hasWorldItem = worldItem ~= nil,
        hasSquare = square ~= nil,
        square = square,
        squareX = square and square.getX and square:getX() or nil,
        squareY = square and square.getY and square:getY() or nil,
        squareZ = square and square.getZ and square:getZ() or nil
    }
end

local function findNearbyCandidate(player, itemId, uuid, matchKind)
    local item = nil
    if matchKind == "uuid_world_match" then
        item = NMInventoryHelpers and NMInventoryHelpers.findWorldItemByUuidNearPlayer
            and NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, SEARCH_RADIUS)
            or nil
    elseif matchKind == "itemid_world_match" then
        item = NMInventoryHelpers and NMInventoryHelpers.findWorldItemByIdNearPlayer
            and NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, SEARCH_RADIUS)
            or nil
    end
    if not item then
        return nil
    end
    local result = inspectItem(item)
    result.matchKind = matchKind
    return result
end

function NMClientPlacedWorldCandidate.resolve(player, item, fallbackUuid)
    local origin = inspectItem(item)
    if origin.hasSquare == true and origin.item then
        origin.matchKind = "original_ref"
        return origin
    end

    local originUuid = tostring(origin.uuid or fallbackUuid or "")
    local originItemId = tostring(origin.itemId or "")
    local uuidCandidate = findNearbyCandidate(player, originItemId, originUuid, "uuid_world_match")
    if uuidCandidate and uuidCandidate.hasSquare == true and uuidCandidate.item then
        return uuidCandidate
    end

    local itemIdCandidate = findNearbyCandidate(player, originItemId, originUuid, "itemid_world_match")
    if itemIdCandidate and itemIdCandidate.hasSquare == true and itemIdCandidate.item then
        return itemIdCandidate
    end

    return nil
end

return NMClientPlacedWorldCandidate
