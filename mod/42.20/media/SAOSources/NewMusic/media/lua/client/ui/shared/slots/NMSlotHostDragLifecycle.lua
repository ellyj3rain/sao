local function logHostExtractEvent(eventName, window, drag, extra)
    if NMSlotActionCommon and NMSlotActionCommon.logSlotExtractEvent then
        local context = extra or {}
        context.window = window
        context.drag = drag
        context.slotType = context.slotType or (drag and drag.slotType) or ""
        NMSlotActionCommon.logSlotExtractEvent(eventName, context)
    end
end

local function resolveSlotHandler(slotType)
    local kind = tostring(slotType or "")
    if kind == "media" then
        return NMMediaSlot
    end
    if kind == "battery" then
        return NMBatterySlot
    end
    if kind == "headphones" then
        return NMHeadphoneSlot
    end
    return nil
end

local function finalizeSlotExtractDrag(slotType, window)
    local handler = resolveSlotHandler(slotType)
    return handler and handler.finalizeExtractDrag and handler.finalizeExtractDrag(window) == true or false
end

local function cancelSlotExtractDrag(slotType, window)
    local handler = resolveSlotHandler(slotType)
    return handler and handler.cancelExtractDrag and (handler.cancelExtractDrag(window) or true) or false
end

local function ensureSlotGhostOverlay(slotType)
    local handler = resolveSlotHandler(slotType)
    if handler and handler.ensureGhostOverlay then
        handler.ensureGhostOverlay()
    end
end

local function resetGlobalReleaseGuard(window)
    if window then
        window._nmGlobalReleaseGuardUpCount = 0
    end
end

local function shouldFinalizeFromGlobalReleaseGuard(window)
    if not window then
        return false
    end
    if tostring(window._nmPendingSlotHostMouseUpTag or "") ~= "" then
        resetGlobalReleaseGuard(window)
        return true
    end
    local upCount = (tonumber(window._nmGlobalReleaseGuardUpCount) or 0) + 1
    window._nmGlobalReleaseGuardUpCount = upCount
    return upCount >= 2
end

local function releaseDeferredUiRefresh(window, fallbackCause)
    if not window then
        return false
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.queueDeferredUiRefreshFlush then
        return NMSlotHostLifecycle.queueDeferredUiRefreshFlush(window, fallbackCause) == true
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.flushDeferredUiRefresh then
        return NMSlotHostLifecycle.flushDeferredUiRefresh(window, fallbackCause) == true
    end
    return false
end

return function(NMSlotHostLifecycle)
    function NMSlotHostLifecycle.finalizeSharedSlotDrags(window)
        local portableInteraction = rawget(_G, "NMPortableMediaInteraction") or nil
        if portableInteraction and portableInteraction.finalizePendingExtract then
            portableInteraction.finalizePendingExtract()
        end
        if NMBatterySlot and NMBatterySlot.finalizeExtractDrag then
            NMBatterySlot.finalizeExtractDrag(window)
        end
        if NMHeadphoneSlot and NMHeadphoneSlot.finalizeExtractDrag then
            NMHeadphoneSlot.finalizeExtractDrag(window)
        end
        releaseDeferredUiRefresh(window, "slot_drag_finalize_shared")
    end

    function NMSlotHostLifecycle.finalizeOwnedSlotDrag(window)
        if not window then
            return false
        end
        local activeSource = nil
        local activeDrag = nil
        if NMSlotGhostManager and NMSlotGhostManager.getActiveDrag then
            activeSource, activeDrag = NMSlotGhostManager.getActiveDrag()
        end

        local slotType = nil
        if activeSource == window and activeDrag then
            slotType = tostring(activeDrag.slotType or "")
        elseif window._nmMediaExtractDrag then
            slotType = "media"
        elseif window._nmBatteryExtractDrag then
            slotType = "battery"
        elseif window._nmHeadphoneExtractDrag then
            slotType = "headphones"
        end

        if slotType ~= "" then
            logHostExtractEvent("slot_extract_mouseup_host", window, activeDrag, {
                slotType = slotType,
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host"),
                detail = "host_finalize_enter"
            })
        end

        if slotType == "media" then
            local handled = finalizeSlotExtractDrag(slotType, window)
            local outcome = handled and "handled_extract" or "not_ours"
            local consume = handled
            logHostExtractEvent("slot_extract_finalize_result", window, activeDrag, {
                slotType = "media",
                returnValue = tostring(outcome or ""),
                consumeDecision = tostring(consume),
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host")
            })
            logHostExtractEvent(consume and "slot_extract_release_consumed" or "slot_extract_release_passed_through", window, activeDrag, {
                slotType = "media",
                returnValue = tostring(outcome or ""),
                consumeDecision = tostring(consume),
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host")
            })
            window._nmPendingSlotHostMouseUpTag = nil
            releaseDeferredUiRefresh(window, "slot_drag_finalize_media")
            return consume
        end
        if slotType == "battery" then
            local handled = finalizeSlotExtractDrag(slotType, window)
            logHostExtractEvent("slot_extract_finalize_result", window, activeDrag, {
                slotType = "battery",
                returnValue = tostring(handled),
                consumeDecision = tostring(handled),
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host")
            })
            logHostExtractEvent(handled and "slot_extract_release_consumed" or "slot_extract_release_passed_through", window, activeDrag, {
                slotType = "battery",
                returnValue = tostring(handled),
                consumeDecision = tostring(handled),
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host")
            })
            window._nmPendingSlotHostMouseUpTag = nil
            releaseDeferredUiRefresh(window, "slot_drag_finalize_battery")
            return handled
        end
        if slotType == "headphones" then
            local handled = finalizeSlotExtractDrag(slotType, window)
            logHostExtractEvent("slot_extract_finalize_result", window, activeDrag, {
                slotType = "headphones",
                returnValue = tostring(handled),
                consumeDecision = tostring(handled),
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host")
            })
            logHostExtractEvent(handled and "slot_extract_release_consumed" or "slot_extract_release_passed_through", window, activeDrag, {
                slotType = "headphones",
                returnValue = tostring(handled),
                consumeDecision = tostring(handled),
                entrypoint = tostring(window._nmPendingSlotHostMouseUpTag or "host")
            })
            window._nmPendingSlotHostMouseUpTag = nil
            releaseDeferredUiRefresh(window, "slot_drag_finalize_headphones")
            return handled
        end
        window._nmPendingSlotHostMouseUpTag = nil
        releaseDeferredUiRefresh(window, "slot_drag_finalize_none")
        return false
    end

    function NMSlotHostLifecycle.cancelOwnedSlotDrag(window, slotType)
        if not window then
            return false
        end
        local canceled = cancelSlotExtractDrag(slotType, window)
        releaseDeferredUiRefresh(window, "slot_drag_cancel")
        return canceled
    end

    function NMSlotHostLifecycle.finishActiveDragAfterMouseRelease()
        if not isMouseButtonDown or isMouseButtonDown(0) == true then
            local activeSource = nil
            local activeDrag = nil
            if NMSlotGhostManager and NMSlotGhostManager.getActiveDrag then
                activeSource, activeDrag = NMSlotGhostManager.getActiveDrag()
            end
            if activeSource and activeDrag then
                resetGlobalReleaseGuard(activeSource)
            end
            return false
        end
        local activeSource = nil
        local activeDrag = nil
        if NMSlotGhostManager and NMSlotGhostManager.getActiveDrag then
            activeSource, activeDrag = NMSlotGhostManager.getActiveDrag()
        end
        if not (activeSource and activeDrag) then
            return false
        end
        if not shouldFinalizeFromGlobalReleaseGuard(activeSource) then
            return false
        end

        logHostExtractEvent("slot_extract_mouseup_global_guard", activeSource, activeDrag, {
            slotType = tostring(activeDrag.slotType or ""),
            entrypoint = "global_release_guard",
            detail = "guard_enter"
        })

        NMSlotHostLifecycle.finalizeOwnedSlotDrag(activeSource)

        local remainingSource = nil
        local remainingDrag = nil
        if NMSlotGhostManager and NMSlotGhostManager.getActiveDrag then
            remainingSource, remainingDrag = NMSlotGhostManager.getActiveDrag()
        end
        if remainingSource == activeSource and remainingDrag == activeDrag then
            logHostExtractEvent("slot_extract_mouseup_global_guard", activeSource, activeDrag, {
                slotType = tostring(activeDrag.slotType or ""),
                entrypoint = "global_release_guard",
                detail = "guard_cancel_remaining"
            })
            NMSlotHostLifecycle.cancelOwnedSlotDrag(activeSource, activeDrag.slotType)
        end

        ensureSlotGhostOverlay("battery")
        ensureSlotGhostOverlay("media")
        ensureSlotGhostOverlay("headphones")
        logHostExtractEvent("slot_extract_cleanup_result", activeSource, activeDrag, {
            slotType = tostring(activeDrag.slotType or ""),
            entrypoint = "global_release_guard",
            detail = "guard_exit"
        })
        return true
    end

    function NMSlotHostLifecycle.noteHostMouseUp(window, entrypoint)
        if not window then
            return
        end
        window._nmPendingSlotHostMouseUpTag = tostring(entrypoint or "host")
    end

    function NMSlotHostLifecycle.cancelSharedSlotDrags(window)
        if NMBatterySlot and NMBatterySlot.cancelExtractDrag then
            NMBatterySlot.cancelExtractDrag(window)
        end
        if NMMediaSlot and NMMediaSlot.cancelExtractDrag then
            NMMediaSlot.cancelExtractDrag(window)
        end
        if NMHeadphoneSlot and NMHeadphoneSlot.cancelExtractDrag then
            NMHeadphoneSlot.cancelExtractDrag(window)
        end
        releaseDeferredUiRefresh(window, "slot_drag_cancel_shared")
    end

    function NMSlotHostLifecycle.buildSharedPortableSlotZone(spec)
        local window = spec and spec.window or nil
        local rect = spec and spec.rect or nil
        if not (window and rect) then
            return nil
        end
        local zoneKind = tostring(spec.zoneKind or "slot")
        local canAcceptDraggedMedia = spec.canAcceptDraggedMedia
        local canEjectMedia = spec.canEjectMedia
        local canStartExtractDrag = spec.canStartExtractDrag
        local dragItems = spec.dragItems
        local canAccept = false
        if canAcceptDraggedMedia then
            canAccept = canAcceptDraggedMedia(dragItems) == true
        end
        return {
            uiFamily = tostring(spec.uiFamily or window.slotHostFamily or "generic"),
            zoneKind = zoneKind,
            priority = tonumber(spec.priority) or 10,
            zOrder = tonumber(spec.zOrder) or 0,
            playerNum = tonumber(window.playerNum) or 0,
            itemId = spec.itemId or window.target and window.target.itemId or nil,
            uuid = spec.uuid or window.target and window.target.uuid or nil,
            window = window,
            rect = rect,
            visible = spec.visible ~= false,
            enabled = spec.enabled ~= false,
            interactive = spec.interactive ~= false,
            canAccept = canAccept,
            canAcceptDraggedMedia = function(items)
                return canAcceptDraggedMedia and canAcceptDraggedMedia(items) == true or false
            end,
            canEjectMedia = function()
                return canEjectMedia and canEjectMedia() == true or false
            end,
            canStartExtractDrag = function()
                return canStartExtractDrag and canStartExtractDrag() == true or false
            end
        }
    end

    function NMSlotHostLifecycle.buildSharedMediaSlotZone(spec)
        return NMSlotHostLifecycle.buildSharedPortableSlotZone(spec)
    end
end
