local function resolveNowMs()
    local nowMs = (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
    if nowMs <= 0 and getTimestamp then
        nowMs = (tonumber(getTimestamp()) or 0) * 1000
    end
    return nowMs
end

local function resolveTargetCacheKey(target)
    if not target then
        return ""
    end
    if tostring(target.kind or "") == "vehicle" then
        return table.concat({
            "vehicle",
            tostring(target.vehicleId or ""),
            tostring(target.partId or "")
        }, "|")
    end
    return table.concat({
        tostring(target.kind or "item"),
        tostring(target.itemId or ""),
        tostring(target.uuid or "")
    }, "|")
end

local function resolveDraggedItemsSnapshotNow()
    if resolveDraggedInventoryItemsSnapshot then
        return resolveDraggedInventoryItemsSnapshot()
    end
    if NMSlotActionCommon and NMSlotActionCommon.getDraggedInventoryItems then
        return NMSlotActionCommon.getDraggedInventoryItems()
    end
    return {}, true
end

local function sanitizeCounterPart(value)
    local text = tostring(value or "")
    text = string.gsub(text, "[^%w_%-%.]", "_")
    if text == "" then
        return "unknown"
    end
    return text
end

local function countUiRender(window, key, delta)
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, tostring(key or "unknown"), tonumber(delta) or 1)
    end
end

local function countRevisionBump(window, revisionKey)
    countUiRender(window, "revision_bump." .. sanitizeCounterPart(revisionKey), 1)
end

return function(NMSlotHostLifecycle)
    function NMSlotHostLifecycle.initHostState(window)
        if not window then
            return nil
        end
        window._nmFrameEpoch = tonumber(window._nmFrameEpoch) or 0
        window._nmFrameNowMs = tonumber(window._nmFrameNowMs) or 0
        window._nmFrameResolvedContext = window._nmFrameResolvedContext or nil
        window._nmFrameResolvedRevisionKey = window._nmFrameResolvedRevisionKey or nil
        window._nmFrameResolvedTargetKey = window._nmFrameResolvedTargetKey or nil
        window._nmFrameDraggedItems = window._nmFrameDraggedItems or nil
        window._nmFrameDraggedItemsOk = window._nmFrameDraggedItemsOk or nil
        window._nmFrameDraggedItemsRevisionKey = window._nmFrameDraggedItemsRevisionKey or nil
        window._nmContextCache = window._nmContextCache or nil
        window._nmContextCacheEpoch = window._nmContextCacheEpoch or nil
        window._nmContextCacheTargetKey = window._nmContextCacheTargetKey or nil
        window._nmSlotHostFrame = window._nmSlotHostFrame or nil
        window._nmSlotHostFrameEpoch = window._nmSlotHostFrameEpoch or nil
        window._nmSlotHostFrameRevisionKey = window._nmSlotHostFrameRevisionKey or nil
        window._nmSlotInteractionFrame = window._nmSlotInteractionFrame or nil
        window._nmSlotInteractionFrameRevisionKey = window._nmSlotInteractionFrameRevisionKey or nil
        window._nmSlotContentModel = window._nmSlotContentModel or nil
        window._nmSlotContentModelRevisionKey = window._nmSlotContentModelRevisionKey or nil
        window._nmSlotFrameModel = window._nmSlotFrameModel or nil
        window._nmSlotFrameModelEpoch = window._nmSlotFrameModelEpoch or nil
        window._nmSlotFrameModelRevisionKey = window._nmSlotFrameModelRevisionKey or nil
        window._nmContextRevision = tonumber(window._nmContextRevision) or 0
        window._nmSlotRevision = tonumber(window._nmSlotRevision) or 0
        window._nmSlotContentRevision = tonumber(window._nmSlotContentRevision) or window._nmSlotRevision or 0
        window._nmRenderRevision = tonumber(window._nmRenderRevision) or 0
        window._nmAnimationRevision = tonumber(window._nmAnimationRevision) or 0
        window._nmContextCacheRevisionKey = window._nmContextCacheRevisionKey or nil
        window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
        window._nmQueuedDeferredUiRefreshOptions = window._nmQueuedDeferredUiRefreshOptions or nil
        return window
    end

    function NMSlotHostLifecycle.invalidateContextCache(window)
        if not window then
            return
        end
        countUiRender(window, "invalidate.context_cache", 1)
        window._nmContextCache = nil
        window._nmContextCacheEpoch = nil
        window._nmContextCacheTargetKey = nil
        window._nmContextCacheRevisionKey = nil
        window._nmFrameResolvedContext = nil
        window._nmFrameResolvedRevisionKey = nil
        window._nmFrameResolvedTargetKey = nil
        window._nmSlotHostFrame = nil
        window._nmSlotHostFrameEpoch = nil
        window._nmSlotHostFrameRevisionKey = nil
        window._nmSlotInteractionFrame = nil
        window._nmSlotInteractionFrameRevisionKey = nil
        window._nmSlotContentModel = nil
        window._nmSlotContentModelRevisionKey = nil
        window._nmSlotFrameModel = nil
        window._nmSlotFrameModelEpoch = nil
        window._nmSlotFrameModelRevisionKey = nil
        window._nmContextRevision = (tonumber(window._nmContextRevision) or 0) + 1
        window._nmSlotRevision = (tonumber(window._nmSlotRevision) or 0) + 1
        window._nmSlotContentRevision = (tonumber(window._nmSlotContentRevision) or 0) + 1
        window._nmRenderRevision = (tonumber(window._nmRenderRevision) or 0) + 1
        countRevisionBump(window, "context")
        countRevisionBump(window, "slot_interaction")
        countRevisionBump(window, "slot_content")
        countRevisionBump(window, "render")
        if window.onInvalidateSlotHostContextCache then
            window:onInvalidateSlotHostContextCache()
        end
    end

    function NMSlotHostLifecycle.invalidateSlotFrameModel(window)
        if not window then
            return
        end
        countUiRender(window, "invalidate.slot_frame_model", 1)
        window._nmSlotHostFrame = nil
        window._nmSlotHostFrameEpoch = nil
        window._nmSlotHostFrameRevisionKey = nil
        window._nmSlotInteractionFrame = nil
        window._nmSlotInteractionFrameRevisionKey = nil
        window._nmSlotContentModel = nil
        window._nmSlotContentModelRevisionKey = nil
        window._nmSlotFrameModel = nil
        window._nmSlotFrameModelEpoch = nil
        window._nmSlotFrameModelRevisionKey = nil
        window._nmSlotRevision = (tonumber(window._nmSlotRevision) or 0) + 1
        window._nmSlotContentRevision = (tonumber(window._nmSlotContentRevision) or 0) + 1
        window._nmRenderRevision = (tonumber(window._nmRenderRevision) or 0) + 1
        countRevisionBump(window, "slot_interaction")
        countRevisionBump(window, "slot_content")
        countRevisionBump(window, "render")
    end

    function NMSlotHostLifecycle.beginFrameEpoch(window, reason)
        if not window then
            return 0
        end
        NMSlotHostLifecycle.initHostState(window)
        if NMSlotHostLifecycle.flushQueuedDeferredUiRefresh then
            NMSlotHostLifecycle.flushQueuedDeferredUiRefresh(window)
        end
        window._nmFrameEpoch = (tonumber(window._nmFrameEpoch) or 0) + 1
        window._nmFrameReason = tostring(reason or "frame")
        window._nmFrameNowMs = resolveNowMs()
        window._nmFrameResolvedContext = nil
        window._nmFrameResolvedRevisionKey = nil
        window._nmFrameResolvedTargetKey = nil
        window._nmFrameDraggedItems = nil
        window._nmFrameDraggedItemsOk = nil
        window._nmFrameDraggedItemsRevisionKey = nil
        if window._nmFrameResolveCount ~= nil then
            window._nmFrameResolveCount = 0
        end
        if window._nmFrameFallbackCount ~= nil then
            window._nmFrameFallbackCount = 0
        end
        if window.onBeginSlotHostFrameEpoch then
            window:onBeginSlotHostFrameEpoch(window._nmFrameReason)
        end
        return window._nmFrameEpoch
    end

    function NMSlotHostLifecycle.resolveContext(window)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.initHostState(window)
        local key = resolveTargetCacheKey(window.target)
        local revisionKey = nil
        if NMDeviceUiHost and NMDeviceUiHost.getContextRevisionKey then
            revisionKey = NMDeviceUiHost.getContextRevisionKey(window)
        else
            revisionKey = string.format("%s|%s", tostring(window._nmContextRevision or 0), key)
        end
        if window._nmContextCache
            and window._nmContextCacheRevisionKey == revisionKey
            and window._nmContextCacheTargetKey == key then
            if NMUIRenderProbe and NMUIRenderProbe.count then
                NMUIRenderProbe.count(window, "context.cache_hit", 1)
            end
            return window._nmContextCache
        end
        if not window.resolveContextFreshUncached then
            return nil
        end
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "context.cache_miss", 1)
        end
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        local resolved = window:resolveContextFreshUncached()
        window._nmContextCache = resolved
        window._nmContextCacheEpoch = tonumber(window._nmFrameEpoch) or 0
        window._nmContextCacheTargetKey = key
        window._nmContextCacheRevisionKey = revisionKey
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "device.resolveContext", perfStart)
        end
        return resolved
    end

    function NMSlotHostLifecycle.resolveFrameContext(window)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.initHostState(window)
        local key = resolveTargetCacheKey(window.target)
        local revisionKey = nil
        if NMDeviceUiHost and NMDeviceUiHost.getContextRevisionKey then
            revisionKey = NMDeviceUiHost.getContextRevisionKey(window)
        else
            revisionKey = string.format("%s|%s", tostring(window._nmContextRevision or 0), key)
        end
        if window._nmFrameResolvedContext
            and window._nmFrameResolvedRevisionKey == revisionKey
            and window._nmFrameResolvedTargetKey == key then
            return window._nmFrameResolvedContext
        end
        local resolved = NMSlotHostLifecycle.resolveContext(window)
        window._nmFrameResolvedContext = resolved
        window._nmFrameResolvedRevisionKey = revisionKey
        window._nmFrameResolvedTargetKey = key
        return resolved
    end

    function NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
        if not window then
            return {}, true
        end
        NMSlotHostLifecycle.initHostState(window)
        local revisionKey = string.format(
            "%s|%s",
            tostring(window._nmFrameEpoch or 0),
            tostring(window._nmAnimationRevision or 0)
        )
        if window._nmFrameDraggedItemsRevisionKey == revisionKey then
            return window._nmFrameDraggedItems or {}, window._nmFrameDraggedItemsOk == true
        end
        local dragItems, dragOk = resolveDraggedItemsSnapshotNow()
        window._nmFrameDraggedItems = dragItems
        window._nmFrameDraggedItemsOk = dragOk == true
        window._nmFrameDraggedItemsRevisionKey = revisionKey
        return dragItems, dragOk == true
    end

    function NMSlotHostLifecycle.resolveContextFresh(window)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.invalidateContextCache(window)
        if not window.resolveContextFreshUncached then
            return nil
        end
        local resolved = window:resolveContextFreshUncached()
        local key = resolveTargetCacheKey(window.target)
        window._nmContextCache = resolved
        window._nmContextCacheEpoch = tonumber(window._nmFrameEpoch) or 0
        window._nmContextCacheTargetKey = key
        window._nmFrameResolvedContext = resolved
        window._nmFrameResolvedTargetKey = key
        if NMDeviceUiHost and NMDeviceUiHost.getContextRevisionKey then
            window._nmContextCacheRevisionKey = NMDeviceUiHost.getContextRevisionKey(window)
        else
            window._nmContextCacheRevisionKey = string.format("%s|%s", tostring(window._nmContextRevision or 0), key)
        end
        window._nmFrameResolvedRevisionKey = window._nmContextCacheRevisionKey
        return resolved
    end

    function NMSlotHostLifecycle.refreshSlotVisibility(window)
        if window and window.refreshSlotVisibility then
            return window:refreshSlotVisibility()
        end
        return nil
    end

    function NMSlotHostLifecycle.markUiRefreshPending(window, cause, ttlMs)
        if not window then
            return
        end
        local nowMs = resolveNowMs()
        window._nmUiRefreshPendingCause = tostring(cause or "")
        window._nmUiRefreshPendingAtMs = nowMs
        window._nmUiRefreshPendingUntilMs = nowMs + math.max(1, tonumber(ttlMs) or 1000)
    end

    function NMSlotHostLifecycle.hasOwnedSlotDrag(window)
        if not window then
            return false
        end
        return window._nmMediaExtractDrag ~= nil
            or window._nmBatteryExtractDrag ~= nil
            or window._nmHeadphoneExtractDrag ~= nil
    end

    function NMSlotHostLifecycle.isUiRefreshPending(window, nowMs)
        if not window then
            return false
        end
        local compareMs = tonumber(nowMs) or resolveNowMs()
        local untilMs = tonumber(window._nmUiRefreshPendingUntilMs) or 0
        return untilMs > 0 and compareMs <= untilMs
    end

    function NMSlotHostLifecycle.clearUiRefreshPending(window)
        if not window then
            return
        end
        window._nmUiRefreshPendingCause = nil
        window._nmUiRefreshPendingAtMs = nil
        window._nmUiRefreshPendingUntilMs = nil
        window._nmDeferredUiRefreshOptions = nil
        window._nmQueuedDeferredUiRefreshOptions = nil
    end

    function NMSlotHostLifecycle.deferUiRefreshUntilDragEnd(window, options)
        if not window then
            return false
        end
        local opts = options or {}
        if NMSlotHostLifecycle.hasOwnedSlotDrag(window) ~= true then
            return false
        end
        window._nmDeferredUiRefreshOptions = {
            cause = tostring(opts.cause or "ui_change_deferred"),
            pendingMs = tonumber(opts.pendingMs),
            context = opts.context,
            slotFrame = opts.slotFrame,
            render = opts.render,
            visibility = opts.visibility,
        }
        NMSlotHostLifecycle.markUiRefreshPending(window, window._nmDeferredUiRefreshOptions.cause, opts.pendingMs)
        return true
    end

    function NMSlotHostLifecycle.flushDeferredUiRefresh(window, fallbackCause)
        if not window then
            return false
        end
        local opts = window._nmDeferredUiRefreshOptions
        if type(opts) ~= "table" then
            return false
        end
        if NMSlotHostLifecycle.hasOwnedSlotDrag(window) == true then
            return false
        end
        window._nmDeferredUiRefreshOptions = nil
        NMSlotHostLifecycle.invalidateForUiChange(window, {
            cause = tostring(opts.cause or fallbackCause or "ui_change_deferred"),
            pendingMs = opts.pendingMs,
            context = opts.context,
            slotFrame = opts.slotFrame,
            render = opts.render,
            visibility = opts.visibility,
        })
        return true
    end

    function NMSlotHostLifecycle.queueDeferredUiRefreshFlush(window, fallbackCause)
        if not window then
            return false
        end
        local opts = window._nmDeferredUiRefreshOptions
        if type(opts) ~= "table" then
            return false
        end
        if NMSlotHostLifecycle.hasOwnedSlotDrag(window) == true then
            return false
        end
        window._nmDeferredUiRefreshOptions = nil
        window._nmQueuedDeferredUiRefreshOptions = {
            cause = tostring(opts.cause or fallbackCause or "ui_change_deferred"),
            pendingMs = opts.pendingMs,
            context = opts.context,
            slotFrame = opts.slotFrame,
            render = opts.render,
            visibility = opts.visibility,
        }
        return true
    end

    function NMSlotHostLifecycle.flushQueuedDeferredUiRefresh(window)
        if not window then
            return false
        end
        local opts = window._nmQueuedDeferredUiRefreshOptions
        if type(opts) ~= "table" then
            return false
        end
        if NMSlotHostLifecycle.hasOwnedSlotDrag(window) == true then
            return false
        end
        window._nmQueuedDeferredUiRefreshOptions = nil
        NMSlotHostLifecycle.invalidateForUiChange(window, {
            cause = tostring(opts.cause or "ui_change_deferred"),
            pendingMs = opts.pendingMs,
            context = opts.context,
            slotFrame = opts.slotFrame,
            render = opts.render,
            visibility = opts.visibility,
        })
        return true
    end

    function NMSlotHostLifecycle.invalidateForUiChange(window, options)
        if not window then
            return
        end
        local opts = options or {}
        local cause = sanitizeCounterPart(opts.cause or "ui_change")
        countUiRender(window, "invalidate.ui_change", 1)
        countUiRender(window, "invalidate.ui_change." .. cause, 1)
        NMSlotHostLifecycle.markUiRefreshPending(window, opts.cause or "ui_change", opts.pendingMs)
        if opts.context ~= false and window.invalidateContextCache then
            window:invalidateContextCache()
        end
        if opts.slotFrame ~= false and window.invalidateSlotFrameModel then
            window:invalidateSlotFrameModel()
        end
        if opts.render ~= false and window.invalidateRenderModel then
            window:invalidateRenderModel()
        end
        if opts.visibility ~= false then
            NMSlotHostLifecycle.refreshSlotVisibility(window)
        end
    end

    function NMSlotHostLifecycle.invalidateForTimedAction(window, options)
        NMSlotHostLifecycle.invalidateForUiChange(window, options)
    end
end
