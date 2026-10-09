-- Shared attachment truth helpers for hand/back/attached list matching.
NMAttachmentHelpers = NMAttachmentHelpers or {}
local HEADPHONES_FULL_TYPE = "Base.Headphones"

local function ensureWornItemVisual(item)
    if not item then
        return false, "missing_item"
    end
    if NMWorldItemVisuals and NMWorldItemVisuals.ensureVisual then
        return NMWorldItemVisuals.ensureVisual(item)
    end

    local visual = nil
    if item.getVisual then
        local ok, found = pcall(item.getVisual, item)
        if ok then
            visual = found
        end
    end
    if visual == nil and item.synchWithVisual then
        pcall(item.synchWithVisual, item)
        if item.getVisual then
            local ok, found = pcall(item.getVisual, item)
            if ok then
                visual = found
            end
        end
    end
    if visual == nil then
        return false, "missing_item_visual"
    end
    return true, "visual_ready"
end

local function notifyClothingChanged(player, item, location)
    if sendClothing then
        pcall(sendClothing, player, location, item)
    end
    if sendEquip then
        pcall(sendEquip, player)
    end
    if triggerEvent then
        pcall(triggerEvent, "OnClothingUpdated", player)
    end
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    if playerNum ~= nil and getPlayerInventory then
        local invPage = getPlayerInventory(playerNum)
        if invPage and invPage.refreshBackpacks then
            pcall(invPage.refreshBackpacks, invPage)
        end
    end
    if ISInventoryPage then
        ISInventoryPage.renderDirty = true
    end
end

function NMAttachmentHelpers.itemMatchesTarget(candidate, targetId, targetItem, targetUuid)
    if not candidate then return false end
    if targetItem and candidate == targetItem then return true end

    local wantedUuid = tostring(targetUuid or "")
    if wantedUuid ~= "" then
        local candidateUuid = NMInventoryHelpers.getItemUuidString(candidate)
        if candidateUuid ~= "" and candidateUuid == wantedUuid then
            return true
        end
    end

    local candidateId = NMInventoryHelpers.getItemIdString(candidate)
    if candidateId == "" or tostring(targetId or "") == "" then
        return false
    end
    return candidateId == tostring(targetId)
end

function NMAttachmentHelpers.isItemWornOnBack(player, itemId, item, targetUuid)
    if not player or tostring(itemId or "") == "" then
        return false
    end
    local wornItems = player.getWornItems and player:getWornItems() or nil
    if not wornItems then
        return false
    end

    local size = -1
    if wornItems.size then
        size = tonumber(wornItems:size()) or -1
    elseif wornItems.getSize then
        size = tonumber(wornItems:getSize()) or -1
    end
    if size <= 0 then
        return false
    end

    for i = 0, size - 1 do
        local entry = nil
        if wornItems.get then
            entry = wornItems:get(i)
        elseif wornItems.getItemByIndex then
            entry = wornItems:getItemByIndex(i)
        end
        if entry then
            local wornItem = nil
            if entry.getItem then
                wornItem = entry:getItem()
            elseif entry.getInventoryItem then
                wornItem = entry:getInventoryItem()
            elseif entry.getID then
                wornItem = entry
            end
            if NMAttachmentHelpers.itemMatchesTarget(wornItem, itemId, item, targetUuid) then
                local location = ""
                if entry.getLocation then
                    location = tostring(entry:getLocation() or "")
                elseif entry.getBodyLocation then
                    location = tostring(entry:getBodyLocation() or "")
                end
                local normalizedLocation = string.lower(location or "")
                if normalizedLocation == "" or string.find(normalizedLocation, "back", 1, true) ~= nil then
                    return true
                end
            end
        end
    end

    return false
end

function NMAttachmentHelpers.isHeadphonesFullType(fullType)
    return tostring(fullType or "") == HEADPHONES_FULL_TYPE
end

function NMAttachmentHelpers.findWornHeadphones(player)
    if not player then
        return nil, nil
    end
    local wornItems = player.getWornItems and player:getWornItems() or nil
    if not wornItems then
        return nil, nil
    end

    local size = -1
    if wornItems.size then
        size = tonumber(wornItems:size()) or -1
    elseif wornItems.getSize then
        size = tonumber(wornItems:getSize()) or -1
    end
    if size <= 0 then
        return nil, nil
    end

    for i = 0, size - 1 do
        local entry = nil
        if wornItems.get then
            entry = wornItems:get(i)
        elseif wornItems.getItemByIndex then
            entry = wornItems:getItemByIndex(i)
        end
        if entry then
            local wornItem = nil
            if entry.getItem then
                wornItem = entry:getItem()
            elseif entry.getInventoryItem then
                wornItem = entry:getInventoryItem()
            elseif entry.getID then
                wornItem = entry
            end
            local fullType = wornItem and wornItem.getFullType and tostring(wornItem:getFullType() or "") or ""
            if NMAttachmentHelpers.isHeadphonesFullType(fullType) then
                local location = nil
                if entry.getLocation then
                    location = entry:getLocation()
                elseif entry.getBodyLocation then
                    location = entry:getBodyLocation()
                end
                return wornItem, location
            end
        end
    end
    return nil, nil
end

function NMAttachmentHelpers.equipHeadphonesByItemId(player, itemId)
    local id = tostring(itemId or "")
    if not player or id == "" then
        return false, "invalid_equip_args", nil
    end
    local inv = player.getInventory and player:getInventory() or nil
    if not inv then
        return false, "missing_inventory", nil
    end
    local item = NMInventoryHelpers.findDirectItemById and NMInventoryHelpers.findDirectItemById(inv, id) or nil
    if not item then
        if NMInventoryHelpers.findItemById and NMInventoryHelpers.findItemById(inv, id) then
            return false, "source_item_not_in_main_inventory", nil
        end
        return false, "source_item_not_found", nil
    end
    local fullType = item.getFullType and tostring(item:getFullType() or "") or ""
    if not NMAttachmentHelpers.isHeadphonesFullType(fullType) then
        return false, "not_headphones_item", nil
    end

    local location = nil
    if item.canBeEquipped then
        location = item:canBeEquipped()
    end
    if (location == nil or tostring(location) == "") and item.getBodyLocation then
        location = item:getBodyLocation()
    end
    if location == nil or tostring(location) == "" then
        return false, "missing_wear_location", nil
    end

    local visualOk, visualReason = ensureWornItemVisual(item)
    if not visualOk then
        return false, tostring(visualReason or "missing_item_visual"), nil
    end

    player:setWornItem(location, item)
    notifyClothingChanged(player, item, location)
    return true, nil, item
end

function NMAttachmentHelpers.unequipWornHeadphones(player)
    if not player then
        return false, "invalid_unequip_args", nil
    end
    local wornItem, location = NMAttachmentHelpers.findWornHeadphones(player)
    if not wornItem then
        return true, nil, nil
    end

    local ok = pcall(player.removeWornItem, player, wornItem, false)
    if not ok then
        ok = pcall(player.removeWornItem, player, wornItem)
    end
    if not ok then
        return false, "remove_worn_failed", nil
    end
    notifyClothingChanged(player, nil, location)
    return true, nil, wornItem
end

