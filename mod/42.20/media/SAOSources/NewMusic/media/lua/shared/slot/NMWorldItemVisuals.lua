NMWorldItemVisuals = NMWorldItemVisuals or {}

local RELEVANT_FULL_TYPES = {
    ["Base.Earbuds"] = true,
    ["Base.Headphones"] = true
}

local scriptItemCache = {}

local function resolveScriptItem(fullType)
    local key = tostring(fullType or "")
    if key == "" then
        return nil
    end
    if scriptItemCache[key] ~= nil then
        return scriptItemCache[key] or nil
    end
    local item = nil
    if ScriptManager and ScriptManager.instance then
        if ScriptManager.instance.FindItem then
            local ok, found = pcall(ScriptManager.instance.FindItem, ScriptManager.instance, key)
            if ok and found then
                item = found
            end
        end
        if not item and ScriptManager.instance.getItem then
            local ok, found = pcall(ScriptManager.instance.getItem, ScriptManager.instance, key)
            if ok and found then
                item = found
            end
        end
    end
    scriptItemCache[key] = item or false
    return item
end

function NMWorldItemVisuals.isRelevantFullType(fullType)
    return RELEVANT_FULL_TYPES[tostring(fullType or "")] == true
end

function NMWorldItemVisuals.expectsItemVisual(fullType)
    local item = resolveScriptItem(fullType)
    if not item or not item.getClothingItem then
        return false
    end
    local ok, clothingItem = pcall(item.getClothingItem, item)
    return ok and tostring(clothingItem or "") ~= ""
end

function NMWorldItemVisuals.ensureVisual(item)
    if not item then
        return false, "missing_item"
    end

    local fullType = item.getFullType and tostring(item:getFullType() or "") or ""
    local expectsVisual = NMWorldItemVisuals.expectsItemVisual(fullType)
    local visual = nil

    if item.getVisual then
        local ok, found = pcall(item.getVisual, item)
        if ok then
            visual = found
        end
    end

    if item.synchWithVisual then
        pcall(item.synchWithVisual, item)
        if item.getVisual then
            local ok, found = pcall(item.getVisual, item)
            if ok then
                visual = found
            end
        end
    end

    if expectsVisual and visual == nil then
        return false, "missing_item_visual"
    end
    return true, expectsVisual and "visual_ready" or "visual_not_required"
end

function NMWorldItemVisuals.addItemWithVisual(container, fullType)
    if not (container and container.AddItem) then
        return nil, "missing_inventory_add"
    end
    local resolvedType = tostring(fullType or "")
    if resolvedType == "" then
        return nil, "missing_item_type"
    end

    local item = container:AddItem(resolvedType)
    if not item then
        return nil, "add_item_failed"
    end

    local ok, reason = NMWorldItemVisuals.ensureVisual(item)
    return item, ok and nil or reason
end

return NMWorldItemVisuals
