_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

NMHeadphoneSlotItems = NMHeadphoneSlotItems or {}

function NMHeadphoneSlotItems.isAllowedHeadphoneType(fullType)
    return HEADPHONE_TYPES[tostring(fullType or "")] == true
end

function NMHeadphoneSlotItems.isGroundInsertionBlocked(fullType)
    return NMInsertedHeadphonePolicy
        and NMInsertedHeadphonePolicy.shouldDetachOnGround(fullType)
        or false
end

function NMHeadphoneSlotItems.isAllowedHeadphoneTypeForContext(fullType, groundContext)
    if not NMHeadphoneSlotItems.isAllowedHeadphoneType(fullType) then
        return false
    end
    if groundContext and NMHeadphoneSlotItems.isGroundInsertionBlocked(fullType) then
        return false
    end
    return true
end

function NMHeadphoneSlotItems.collectEligibleHeadphoneItems(window, resolved, state)
    local ctx = resolved
    if not ctx then
        ctx = NMHeadphoneSlotContext.resolveWindowContext(window)
    end
    local groundContext = NMHeadphoneSlotContext.resolveGroundContext(window, state or (ctx and ctx.state or nil), ctx)
    local profile = ctx and ctx.profile or nil
    local player = ctx and ctx.player or nil
    if not (profile and NMDeviceProfiles.supportsHeadphones(profile)) then
        return {}
    end
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then
        return {}
    end

    local all = {}
    NMInventoryHelpers.collectItemsRecursive(inv, all)
    local out = {}
    local seenById = {}
    for i = 1, #all do
        local item = all[i]
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        local itemId = item and item.getID and tostring(item:getID() or "") or ""
        if NMHeadphoneSlotItems.isAllowedHeadphoneTypeForContext(fullType, groundContext)
            and itemId ~= ""
            and not seenById[itemId] then
            seenById[itemId] = true
            out[#out + 1] = item
        end
    end
    return out
end

function NMHeadphoneSlotItems.isCompatibleHeadphoneItem(item)
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    return NMHeadphoneSlotItems.isAllowedHeadphoneType(fullType)
end

function NMHeadphoneSlotItems.isCompatibleHeadphoneDrag(window, items, resolved, state)
    if type(items) ~= "table" or #items <= 0 then
        return false
    end
    local groundContext = NMHeadphoneSlotContext.resolveGroundContext(window, state, resolved)
    for i = 1, #items do
        local item = items[i]
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if NMHeadphoneSlotItems.isCompatibleHeadphoneItem(item)
            and NMHeadphoneSlotItems.isAllowedHeadphoneTypeForContext(fullType, groundContext) then
            return true
        end
    end
    return false
end

function NMHeadphoneSlotItems.pickFirstCompatibleHeadphone(window, items, resolved, state)
    if type(items) ~= "table" then
        return nil
    end
    local groundContext = NMHeadphoneSlotContext.resolveGroundContext(window, state, resolved)
    for i = 1, #items do
        local item = items[i]
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if NMHeadphoneSlotItems.isCompatibleHeadphoneItem(item)
            and NMHeadphoneSlotItems.isAllowedHeadphoneTypeForContext(fullType, groundContext) then
            return item
        end
    end
    return nil
end

function NMHeadphoneSlotItems.normalizeHeadphoneIngressItem(window, item)
    local resolved = NMHeadphoneSlotContext.resolveWindowContext(window)
    local player = resolved and resolved.player or nil
    local itemId = item and NMCore and NMCore.itemId and NMCore.itemId(item) or nil
    local uuid = item and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or nil
    if not (player and itemId and NMInventoryHelpers and NMInventoryHelpers.normalizeItemToMainInventory) then
        return nil, "normalize_helper_missing"
    end
    return NMInventoryHelpers.normalizeItemToMainInventory(player, itemId, uuid)
end

return NMHeadphoneSlotItems
