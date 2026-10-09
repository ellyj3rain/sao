_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

require "ui/shared/slots/NMDeviceUiSlotContract"

NMHeadphoneSlotRenderState = NMHeadphoneSlotRenderState or {}

function NMHeadphoneSlotRenderState.isMouseOverButton(button)
    if not button then
        return false
    end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local ax = button.getAbsoluteX and button:getAbsoluteX() or 0
    local ay = button.getAbsoluteY and button:getAbsoluteY() or 0
    local bw = tonumber(button.width) or 0
    local bh = tonumber(button.height) or 0
    if bw <= 0 or bh <= 0 then
        return false
    end
    return mx >= ax and mx < (ax + bw) and my >= ay and my < (ay + bh)
end

function NMHeadphoneSlotRenderState.resolveSlotStyle(window, button, resolved)
    local profile = resolved and resolved.profile or nil
    if not (profile and NMDeviceProfiles.supportsHeadphones(profile)) then
        return "slot"
    end
    local mouseOver = NMHeadphoneSlotRenderState.isMouseOverButton(button)
    if mouseOver then
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot.drag_check", 1)
        end
        local items, ok = NMHeadphoneSlotContext.resolveDraggedItems(window)
        local state = resolved and resolved.state or nil
        if ok and type(items) == "table" and #items > 0
            and NMHeadphoneSlotItems.isCompatibleHeadphoneDrag(window, items, resolved, state) then
            return "slot_drag"
        end
    end
    local state = resolved and resolved.state or nil
    local fullType = NMHeadphoneSlotWearSync.resolveHeadphoneSlotFullType(window, state)
    if fullType ~= "" then
        return "slot_filled"
    end
    if mouseOver then
        return "slot_hover"
    end
    return "slot"
end

function NMHeadphoneSlotRenderState.buildContentState(window, frame)
    local resolved = frame and frame.resolved or NMHeadphoneSlotContext.resolveWindowContext(window)
    local state = resolved and resolved.state or nil
    local profile = resolved and resolved.profile or nil
    local fullType = NMHeadphoneSlotWearSync.resolveHeadphoneSlotFullType(window, state)
    local supported = profile and NMDeviceProfiles.supportsHeadphones(profile) or false
    local timed = window and window._nmHeadphoneSlotTimedProgress or nil
    local fillPct = nil
    if timed and timed.active == true and timed.delta then
        fillPct = NMCore.clamp(tonumber(timed.delta) or 0.0, 0.0, 1.0)
    end

    local tooltip = nil
    local texture = nil
    if supported then
        if fullType ~= "" then
            texture = NMHeadphoneSlotTextures.resolveItemTextureForFullType(fullType)
            tooltip = NMHeadphoneSlotTextures.resolveInsertedHeadphoneTooltip(fullType)
        else
            tooltip = NMTranslations.ui("InsertHeadphones", "Insert Headphones")
        end
    end

    return NMDeviceUiSlotContract.buildContentState("headphones", {
        fullType = fullType,
        fillPct = fillPct,
        supported = supported == true,
        tooltip = tooltip,
        texture = texture,
        acceptedFullTypes = HEADPHONE_TYPES,
        insertAction = "insert_headphones",
        ejectAction = "eject_headphones",
    })
end

function NMHeadphoneSlotRenderState.buildInteractionState(window, frame, contentState)
    local resolved = frame and frame.resolved or NMHeadphoneSlotContext.resolveWindowContext(window)
    local state = resolved and resolved.state or nil
    local button = window and window.headphoneSlot and window.headphoneSlot.button or nil
    local mouseOver = NMHeadphoneSlotRenderState.isMouseOverButton(button)
    local supported = contentState and contentState.supported == true or false
    local styleKey = tostring(contentState and contentState.styleKey or "slot")
    local canAcceptDrag = false
    if supported then
        canAcceptDrag = mouseOver and frame and frame.dragOk and type(frame.dragItems) == "table" and #frame.dragItems > 0
            and NMHeadphoneSlotItems.isCompatibleHeadphoneDrag(window, frame.dragItems, resolved, state) or false
        if canAcceptDrag then
            styleKey = "slot_drag"
        elseif mouseOver and tostring(contentState and contentState.fullType or "") == "" then
            styleKey = "slot_hover"
        end
    end
    return NMDeviceUiSlotContract.buildInteractionState("headphones", {
        styleKey = styleKey,
        mouseOver = mouseOver == true,
        dragActive = canAcceptDrag,
        canAcceptDrag = canAcceptDrag,
    })
end

function NMHeadphoneSlotRenderState.buildRenderState(window, frame)
    local contentState = NMHeadphoneSlotRenderState.buildContentState(window, frame)
    local interactionState = NMHeadphoneSlotRenderState.buildInteractionState(window, frame, contentState)
    local out = {}
    for key, value in pairs(contentState or {}) do
        out[key] = value
    end
    for key, value in pairs(interactionState or {}) do
        out[key] = value
    end
    return out
end

return NMHeadphoneSlotRenderState
