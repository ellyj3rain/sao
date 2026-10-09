NMPortableMediaInteraction = NMPortableMediaInteraction or {}
require "ui/shared/slots/NMPortableSlotHoverResolver"

local interaction = NMPortableMediaInteraction

local function probeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui") == true
end

local function logProbe(tag, detail)
    if not (probeEnabled() and NMCore and NMCore.logChannel) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function getMousePoint()
    return getMouseX and getMouseX() or 0, getMouseY and getMouseY() or 0
end

local function resolveWindowFamily(window)
    if NMSlotActionCommon and NMSlotActionCommon.resolveSlotHostFamily then
        return NMSlotActionCommon.resolveSlotHostFamily(window)
    end
    return "generic"
end

local function logMediaExtractEvent(eventName, window, drag, extra)
    if NMSlotActionCommon and NMSlotActionCommon.logSlotExtractEvent then
        local context = extra or {}
        context.window = window
        context.drag = drag
        context.slotType = "media"
        NMSlotActionCommon.logSlotExtractEvent(eventName, context)
    end
end

local function resolvePlayerNum(window)
    local resolved = window and window.resolveContext and window:resolveContext() or nil
    local player = resolved and resolved.player or nil
    return player and player.getPlayerNum and player:getPlayerNum() or window and window.playerNum or 0
end

local function resolveZoneDescriptor(window, zoneKind, dragItems)
    return {
        uiFamily = resolveWindowFamily(window),
        zoneKind = tostring(zoneKind or "slot"),
        itemId = window and window.target and window.target.itemId or nil,
        uuid = window and window.target and window.target.uuid or nil,
        dragItems = dragItems
    }
end

local function resolveLocalMediaFullType(window)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local resolveMediaSlotFullTypeFn = mediaEnv and mediaEnv.resolveMediaSlotFullType or nil
    if not resolveMediaSlotFullTypeFn then
        return ""
    end
    local resolved = window and window.resolveContext and window:resolveContext() or nil
    local state = resolved and resolved.state or nil
    return tostring(resolveMediaSlotFullTypeFn(window, state) or "")
end

local function beginLocalExtract(window, zoneKind)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local beginMediaExtractDragFn = mediaEnv and mediaEnv.beginMediaExtractDrag or nil
    if not (window and beginMediaExtractDragFn) then
        return false
    end
    local fullType = resolveLocalMediaFullType(window)
    if fullType == "" then
        return false
    end
    beginMediaExtractDragFn(window, fullType, tostring(zoneKind or "slot"))
    return true
end

local function handleLocalRightClick(window, zoneKind, btn, xArg, yArg)
    local kind = tostring(zoneKind or "slot")
    if not window then
        return false
    end
    if kind == "aux" then
        if window.ejectOpenLidMediaViaAux then
            return window:ejectOpenLidMediaViaAux("local_aux") == true
        end
        if window.ejectMediaViaLid then
            return window:ejectMediaViaLid() == true
        end
    end
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
    local showMediaInsertContextMenuFn = mediaEnv and mediaEnv.showMediaInsertContextMenu or nil
    local fullType = resolveLocalMediaFullType(window)
    if fullType ~= "" and queueMediaSlotEjectFn then
        return queueMediaSlotEjectFn(window, "local_fallback", kind) == true
    end
    if showMediaInsertContextMenuFn then
        return showMediaInsertContextMenuFn(window, btn, xArg, yArg) == true
    end
    return false
end

local function winnerSummary(zone)
    if not zone then
        return "none"
    end
    return string.format(
        "%s:%s:item=%s:uuid=%s",
        tostring(zone.uiFamily or "unknown"),
        tostring(zone.zoneKind or "slot"),
        tostring(zone.itemId or ""),
        tostring(zone.uuid or "")
    )
end

local function performMediaDragInsert(targetWindow, items, sourceTag)
    if not (targetWindow and type(items) == "table" and #items > 0) then
        return false
    end
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local queueDraggedMediaInsertFn = mediaEnv and mediaEnv.queueDraggedMediaInsert or nil
    if not queueDraggedMediaInsertFn then
        return false
    end
    return queueDraggedMediaInsertFn(targetWindow, items, sourceTag) == true
end

local function slotReleaseOutcomes()
    if NMSlotActionCommon and NMSlotActionCommon.slotReleaseOutcomes then
        return NMSlotActionCommon.slotReleaseOutcomes()
    end
    return nil
end

local function slotReleaseNotOurs()
    local outcomes = slotReleaseOutcomes()
    return outcomes and outcomes.notOurs or "not_ours"
end

local function cancelPendingMediaExtract(window)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local cancelFn = mediaEnv and mediaEnv.cancelMediaExtractDrag or nil
    if cancelFn and window then
        cancelFn(window)
    end
    if NMSlotActionCommon and NMSlotActionCommon.clearMouseDragState then
        NMSlotActionCommon.clearMouseDragState()
    end
    if NMMediaSlot and NMMediaSlot.ensureGhostOverlay then
        NMMediaSlot.ensureGhostOverlay()
    end
end

local function finalizePendingExtractForSource(sourceWindow)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local completeFn = mediaEnv and mediaEnv.completeMediaExtractDrag or nil
    local cancelFn = mediaEnv and mediaEnv.cancelMediaExtractDrag or nil
    local cleanupFn = mediaEnv and mediaEnv.finalizeMediaExtractCleanup or nil
    local releaseOverSourceFn = mediaEnv and mediaEnv.isMediaReleaseOverSourceZone or nil
    local slotRelease = slotReleaseOutcomes()
    local resolveOutcomeWithCleanup = NMSlotActionCommon and NMSlotActionCommon.resolveExtractReleaseOutcomeWithCleanup or nil
    if not (sourceWindow and completeFn and slotRelease and resolveOutcomeWithCleanup) then
        return slotReleaseNotOurs()
    end
    local outcome = resolveOutcomeWithCleanup(
        sourceWindow._nmMediaExtractDrag,
        function(drag)
            return releaseOverSourceFn and releaseOverSourceFn(sourceWindow, drag) == true
        end,
        function()
            if cancelFn then
                cancelFn(sourceWindow)
            end
        end,
        function()
            return completeFn(sourceWindow) == true
        end,
        function(finalOutcome)
            if cleanupFn then
                cleanupFn(sourceWindow)
            end
        end,
        nil
    )
    return outcome
end

function interaction.finalizePendingExtractForWindow(window)
    local sourceWindow = NMMediaSlot and NMMediaSlot._ghostDragWindow or nil
    if sourceWindow ~= window then
        return slotReleaseNotOurs()
    end
    return finalizePendingExtractForSource(sourceWindow)
end

function interaction.finalizePendingExtract()
    local sourceWindow = NMMediaSlot and NMMediaSlot._ghostDragWindow or nil
    return finalizePendingExtractForSource(sourceWindow)
end

function interaction.handleMediaSlotMouseDown(window, zoneKind)
    if not window then
        return true
    end
    local items = nil
    local ok = false
    if NMSlotActionCommon and NMSlotActionCommon.getDraggedInventoryItems then
        items, ok = NMSlotActionCommon.getDraggedInventoryItems()
    end
    if type(items) == "table" and #items > 0 then
        return true
    end
    local descriptor = resolveZoneDescriptor(window, zoneKind, nil)
    local mx, my = getMousePoint()
    local executed = beginLocalExtract(window, descriptor.zoneKind) == true
    logProbe(
        "portable_media_interaction",
        string.format(
            "kind=begin_extract triggerUi=%s zone=%s winner=%s executed=%s mouse=%s,%s",
            tostring(descriptor.uiFamily),
            tostring(descriptor.zoneKind),
            winnerSummary(executed and { uiFamily = descriptor.uiFamily, zoneKind = descriptor.zoneKind, itemId = descriptor.itemId, uuid = descriptor.uuid } or nil),
            tostring(executed),
            tostring(mx),
            tostring(my)
        )
    )
    return true
end

function interaction.handleMediaSlotMouseUp(window, zoneKind)
    logMediaExtractEvent("slot_extract_mouseup_slot", window, window and window._nmMediaExtractDrag or nil, {
        sourceZone = tostring(zoneKind or "slot"),
        entrypoint = "portable_media_mouseup"
    })
    local extractOutcome = interaction.finalizePendingExtract()
    if extractOutcome ~= slotReleaseNotOurs() then
        logMediaExtractEvent("slot_extract_finalize_result", window, window and window._nmMediaExtractDrag or nil, {
            sourceZone = tostring(zoneKind or "slot"),
            returnValue = tostring(extractOutcome or ""),
            entrypoint = "portable_media_mouseup"
        })
        local consume = NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome
            and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome(extractOutcome)
            or false
        logMediaExtractEvent(consume and "slot_extract_release_consumed" or "slot_extract_release_passed_through", window, window and window._nmMediaExtractDrag or nil, {
            sourceZone = tostring(zoneKind or "slot"),
            returnValue = tostring(extractOutcome or ""),
            consumeDecision = tostring(consume),
            entrypoint = "portable_media_mouseup"
        })
        return consume
    end
    local items = nil
    local ok = false
    if NMSlotActionCommon and NMSlotActionCommon.getDraggedInventoryItems then
        items, ok = NMSlotActionCommon.getDraggedInventoryItems()
    end
    if ok ~= true or type(items) ~= "table" or #items <= 0 then
        return false
    end
    local descriptor = resolveZoneDescriptor(window, zoneKind, items)
    local mx, my = getMousePoint()
    local playerNum = resolvePlayerNum(window)
    local winner = NMPortableSlotHoverResolver and NMPortableSlotHoverResolver.resolveHoveredMediaSlotWindow
        and NMPortableSlotHoverResolver.resolveHoveredMediaSlotWindow(playerNum, items, mx, my)
        or nil
    local targetWindow = winner and winner.window or nil
    local executed = performMediaDragInsert(targetWindow, items, descriptor.uiFamily) == true
    logProbe(
        "portable_media_interaction",
        string.format(
            "kind=insert_drag triggerUi=%s zone=%s winner=%s executed=%s mouse=%s,%s",
            tostring(descriptor.uiFamily),
            tostring(descriptor.zoneKind),
            winnerSummary(winner),
            tostring(executed),
            tostring(mx),
            tostring(my)
        )
    )
    if executed == true and NMSlotActionCommon and NMSlotActionCommon.clearMouseDragState then
        NMSlotActionCommon.clearMouseDragState()
    end
    return executed == true
end

function interaction.handleMediaSlotRightClick(window, zoneKind, btn, xArg, yArg)
    if not window then
        return true
    end
    cancelPendingMediaExtract(window)
    local descriptor = resolveZoneDescriptor(window, zoneKind, nil)
    local mx, my = getMousePoint()
    local executed = handleLocalRightClick(window, descriptor.zoneKind, btn, xArg, yArg) == true
    logProbe(
        "portable_media_interaction",
        string.format(
            "kind=right_click triggerUi=%s zone=%s winner=%s executed=%s mouse=%s,%s",
            tostring(descriptor.uiFamily),
            tostring(descriptor.zoneKind),
            winnerSummary(executed and { uiFamily = descriptor.uiFamily, zoneKind = descriptor.zoneKind, itemId = descriptor.itemId, uuid = descriptor.uuid } or nil),
            tostring(executed),
            tostring(mx),
            tostring(my)
        )
    )
    return true
end

return interaction
