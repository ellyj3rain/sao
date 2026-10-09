NMSlotRenderCommon = NMSlotRenderCommon or {}

function NMSlotRenderCommon.resolveTextureByFullType(fullType, cache)
    local ft = tostring(fullType or "")
    if ft == "" or not getTexture then
        return nil
    end
    cache = cache or {}
    if cache[ft] ~= nil then
        return cache[ft] or nil
    end
    local scriptItem = ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem
        and ScriptManager.instance:FindItem(ft) or nil
    if scriptItem and scriptItem.getIcon then
        local iconName = tostring(scriptItem:getIcon() or "")
        if iconName ~= "" then
            local tex = getTexture("Item_" .. iconName) or getTexture("media/textures/Item_" .. iconName .. ".png")
            cache[ft] = tex or false
            return tex
        end
    end
    local itemType = ft
    local dotPos = string.find(itemType, "%.")
    if dotPos then
        itemType = string.sub(itemType, dotPos + 1)
    end
    local tex = getTexture("Item_" .. itemType) or getTexture("media/textures/Item_" .. itemType .. ".png")
    cache[ft] = tex or false
    return tex
end

return NMSlotRenderCommon
