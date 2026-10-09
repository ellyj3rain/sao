require "ui/shared/slots/NMSlotPlaceholderRender"

_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

NMHeadphoneSlotTextures = NMHeadphoneSlotTextures or {}

function NMHeadphoneSlotTextures.resolveTextureByFullType(fullType)
    local ft = tostring(fullType or "")
    if ft == "" or not getTexture then
        return nil
    end
    local scriptItem = ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem
        and ScriptManager.instance:FindItem(ft) or nil
    if scriptItem and scriptItem.getIcon then
        local iconName = tostring(scriptItem:getIcon() or "")
        if iconName ~= "" then
            local tex = getTexture("Item_" .. iconName) or getTexture("media/textures/Item_" .. iconName .. ".png")
            if tex then
                return tex
            end
        end
    end
    local itemType = ft
    local dotPos = string.find(itemType, "%.")
    if dotPos then
        itemType = string.sub(itemType, dotPos + 1)
    end
    return getTexture("Item_" .. itemType) or getTexture("media/textures/Item_" .. itemType .. ".png")
end

function NMHeadphoneSlotTextures.resolveItemTextureForFullType(fullType)
    local key = tostring(fullType or "")
    if key == "" then
        return nil
    end
    if HEADPHONE_TEXTURE_CACHE[key] == nil then
        HEADPHONE_TEXTURE_CACHE[key] = NMHeadphoneSlotTextures.resolveTextureByFullType(key) or false
    end
    local tex = HEADPHONE_TEXTURE_CACHE[key]
    return tex ~= false and tex or nil
end

function NMHeadphoneSlotTextures.resolveInsertedHeadphoneTooltip(fullType)
    local resolvedType = tostring(fullType or "")
    if resolvedType == "" then
        return NMTranslations.ui("InsertHeadphones", "Insert Headphones")
    end
    if resolvedType == "Base.Earbuds" then
        local item = ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem
            and ScriptManager.instance:FindItem(resolvedType) or nil
        if item and item.getDisplayName then
            local ok, displayName = pcall(item.getDisplayName, item)
            if ok and tostring(displayName or "") ~= "" then
                return tostring(displayName)
            end
        end
        return "Earbuds"
    end
    return NMTranslations.ui("HeadphonesInserted", "Headphones Inserted")
end

function NMHeadphoneSlotTextures.drawEmptyPlaceholder(self)
    local scaleKey = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey and NMFancyDeviceUiScale.getTextureScaleKey() or "1x"
    if EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE_SCALE_KEY ~= scaleKey then
        EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTexture
            and NMFancyDeviceUiScale.getTexture("media/textures/UI/UI_NM_SlotEmpty_Headphones.png")
            or getTexture and (
                getTexture("media/textures/UI/UI_NM_SlotEmpty_Headphones.png")
                or getTexture("UI/UI_NM_SlotEmpty_Headphones")
                or getTexture("UI_NM_SlotEmpty_Headphones")
            ) or nil
        EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE_SCALE_KEY = scaleKey
    end
    if EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE then
        return NMSlotPlaceholderRender and NMSlotPlaceholderRender.drawTexture and NMSlotPlaceholderRender.drawTexture(self, EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE)
    end
end

return NMHeadphoneSlotTextures
