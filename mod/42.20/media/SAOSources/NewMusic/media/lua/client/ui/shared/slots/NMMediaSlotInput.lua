local env = _G.NMMediaSlotEnv
setfenv(1, env)

local function resolvePortableMediaInteraction()
    return rawget(_G, "NMPortableMediaInteraction") or nil
end

local function dispatchPortableMediaSlotMouseDown(window, zoneKind)
    local interaction = resolvePortableMediaInteraction()
    if interaction and interaction.handleMediaSlotMouseDown then
        return interaction.handleMediaSlotMouseDown(window, zoneKind)
    end
    return true
end

local function dispatchPortableMediaSlotMouseUp(window, zoneKind)
    local interaction = resolvePortableMediaInteraction()
    if interaction and interaction.handleMediaSlotMouseUp then
        return interaction.handleMediaSlotMouseUp(window, zoneKind)
    end
    return true
end

local function dispatchPortableMediaSlotRightClick(window, zoneKind, btn, xArg, yArg)
    local interaction = resolvePortableMediaInteraction()
    if interaction and interaction.handleMediaSlotRightClick then
        return interaction.handleMediaSlotRightClick(window, zoneKind, btn, xArg, yArg)
    end
    return true
end

local function logPortableUiProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function logVehicleSlotTrace(stage, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot")) then
        return
    end
    NMCore.logChannel("slot", tostring(stage or "vehicle_slot_trace"), tostring(detail or ""))
end

local function resolveWindowContext(window)
    if not window then
        return nil
    end
    if window.resolveContextCached then
        return window:resolveContextCached()
    end
    return window.resolveContext and window:resolveContext() or nil
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

local function isDuplicateEjectBlocked(window, fullType)
    local ejectFullType = tostring(fullType or "")
    if ejectFullType == "" then
        return false
    end
    if window and window.isAwaitingAuthoritativeMediaEject and window:isAwaitingAuthoritativeMediaEject(ejectFullType) == true then
        return true
    end
    if window and window._nmSlotRemoveInFlightByType and window._nmSlotRemoveInFlightByType.media then
        return true
    end
    if window and tostring(window._nmPendingMediaSlotFullType or "") == ejectFullType then
        return true
    end
    return false
end

local function logEjectQueueBlocked(window, fullType, sourceTag, zoneKind)
    logPortableUiProbe(
        "slot_eject_queue_blocked",
        string.format(
            "ui=%s targetItemId=%s targetUuid=%s mediaFullType=%s source=%s zone=%s reason=awaiting_authority",
            tostring(resolveWindowFamily(window)),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(fullType or ""),
            tostring(sourceTag or "direct"),
            tostring(zoneKind or "slot")
        )
    )
end

local function resolveMediaIngressPlayer(window)
    local resolved = resolveWindowContext(window)
    return resolved and resolved.player or nil
end

local function primePendingMediaInsert(window, pendingFullType)
    if not window then
        return
    end
    window._nmPendingMediaSlotFullType = tostring(pendingFullType or "")
    if window and window.getFrontVariant then
        window.isLidManuallyOpen = false
    else
        window.isLidManuallyOpen = true
    end
    if window.syncLidFromMedia then
        window:syncLidFromMedia(false)
    end
end

local function buildMediaInsertArgs(liveItem, payload)
    return {
        mediaItemId = NMCore.itemId(liveItem),
        mediaItemUuid = liveItem and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(liveItem) or "",
        mediaFullType = payload.mediaFullType,
        mediaCarrier = payload.mediaCarrier,
        mediaEjectFullType = payload.mediaEjectFullType,
        mediaCanonicalFullType = payload.mediaCanonicalFullType,
        mediaRecordedMediaIndex = payload.mediaRecordedMediaIndex,
        mediaDisplayName = payload.mediaDisplayName
    }
end

local function attachVehicleMediaSourceDescriptor(window, player, liveItem, args)
    if tostring(window and window.target and window.target.kind or "") ~= "vehicle" then
        return true
    end
    if not (
        NMInventoryHelpers
        and NMInventoryHelpers.describeAccessibleItemSource
        and NMInventoryHelpers.writeSourceDescriptorToArgs
    ) then
        return true
    end
    local descriptor = NMInventoryHelpers.describeAccessibleItemSource(player, liveItem, {
        host = "vehicle",
        slotTraceId = tostring(args and args.slotTraceId or "")
    })
    if not descriptor then
        return true
    end
    NMInventoryHelpers.writeSourceDescriptorToArgs(args, "mediaSource", descriptor)
    if tostring(descriptor.kind or "") ~= "vehicle_part_container" then
        return true
    end
    if not NMClientVehicleLootRefresh or not NMClientVehicleLootRefresh.isVehicleLootStaleReject or not NMClientVehicleLootRefresh.isVehicleLootStaleReject(descriptor) then
        return true
    end
    logVehicleSlotTrace(
        "vehicle_loot_stale_row_block",
        string.format(
            "trace=%s vehicleId=%s partId=%s sourcePartId=%s mediaItemId=%s mediaItemUuid=%s containerType=%s result=reject reason=source_item_missing",
            tostring(args and args.slotTraceId or ""),
            tostring(window and window.target and window.target.vehicleId or ""),
            tostring(window and window.target and window.target.partId or ""),
            tostring(descriptor.partId or ""),
            tostring(args and args.mediaItemId or ""),
            tostring(args and args.mediaItemUuid or ""),
            tostring(descriptor.containerType or "")
        )
    )
    if NMClientVehicleLootRefresh and NMClientVehicleLootRefresh.refreshOpenVehicleLootPages then
        NMClientVehicleLootRefresh.refreshOpenVehicleLootPages(player, descriptor.vehicleId, {
            slotTraceId = tostring(args and args.slotTraceId or ""),
            partId = tostring(window and window.target and window.target.partId or ""),
            sourcePartId = tostring(descriptor.partId or "")
        })
    end
    return false
end

local function validateMediaInsertSource(window, player, liveItem, args)
    return attachVehicleMediaSourceDescriptor(window, player, liveItem, args)
end

local function queueResolvedMediaInsert(window, liveItem, payload, args, sourceTag, logTag)
    if not (window and payload and args) then
        return false
    end
    local player = resolveMediaIngressPlayer(window)
    if not validateMediaInsertSource(window, player, liveItem, args) then
        window._nmPendingMediaSlotFullType = nil
        return false
    end
    if logTag then
        logPortableUiProbe(
            logTag,
            string.format(
                "ui=%s targetItemId=%s targetUuid=%s mediaItemId=%s mediaUuid=%s mediaFullType=%s slotTraceId=%s source=%s",
                tostring(resolveWindowFamily(window)),
                tostring(window and window.target and window.target.itemId or ""),
                tostring(window and window.target and window.target.uuid or ""),
                tostring(args.mediaItemId or ""),
                tostring(liveItem and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(liveItem) or ""),
                tostring(args.mediaEjectFullType or args.mediaFullType or ""),
                tostring(args.slotTraceId or ""),
                tostring(sourceTag or "direct")
            )
        )
    end
    if queueMediaSlotAction(window, "insert_media", args) ~= true then
        window._nmPendingMediaSlotFullType = nil
        return false
    end
    return true
end

function queueDraggedMediaInsert(window, items, sourceTag)
    if not (window and type(items) == "table" and #items > 0) then
        return false
    end
    if not isCompatibleMediaDrag(window, items) then
        return false
    end
    local mediaItem = pickFirstCompatibleMedia(window, items)
    if not mediaItem then
        return false
    end
    local liveItem = normalizeMediaIngressItem(window, mediaItem)
    if not liveItem then
        window._nmPendingMediaSlotFullType = nil
        clearMouseDragState()
        return false
    end
    local payload = NMMediaHelpers.resolveMediaInsertPayload(liveItem)
    if not payload then
        return false
    end
    primePendingMediaInsert(window, payload.mediaEjectFullType or payload.mediaFullType or "")
    local args = buildMediaInsertArgs(liveItem, payload)
    if queueResolvedMediaInsert(window, liveItem, payload, args, sourceTag, "slot_insert_drag_queue") ~= true then
        clearMouseDragState()
        return false
    end
    clearMouseDragState()
    return true
end

function queueMediaSlotEject(window, sourceTag, zoneKind)
    if not window then
        return false
    end
    local resolved = resolveWindowContext(window)
    local state = resolved and resolved.state or nil
    local renderState = window and window.getSlotRenderState and window:getSlotRenderState("media") or nil
    local fullType = tostring(renderState and renderState.fullType or "")
    if fullType == "" then
        fullType = resolveMediaSlotFullType(window, state)
    end
    if fullType == "" then
        return false
    end
    if isDuplicateEjectBlocked(window, fullType) then
        logEjectQueueBlocked(window, fullType, sourceTag, zoneKind)
        return false
    end
    window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
    window._nmSlotRemoveInFlightByType.media = true
    window._nmPendingMediaSlotFullType = tostring(fullType or "")
    local args = {
        slotTraceId = nextSlotTraceId(),
        slotSourceTag = tostring(sourceTag or "direct"),
        slotZoneKind = tostring(zoneKind or "slot"),
        slotDeviceFamily = tostring(resolveWindowFamily(window))
    }
    logPortableUiProbe(
        "slot_eject_click_queue",
        string.format(
            "ui=%s targetItemId=%s targetUuid=%s mediaFullType=%s source=%s zone=%s slotTraceId=%s",
            tostring(resolveWindowFamily(window)),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(fullType or ""),
            tostring(sourceTag or "direct"),
            tostring(zoneKind or "slot"),
            tostring(args.slotTraceId or "")
        )
    )
    if queueMediaSlotAction(window, "eject_media", args) ~= true then
        window._nmPendingMediaSlotFullType = nil
        window._nmSlotRemoveInFlightByType.media = nil
        return false
    end
    return true
end

function showMediaInsertContextMenu(window, btn, xArg, yArg, options)
    if not window then
        return false
    end
    local resolvedCtx = resolveWindowContext(window)
    local player = resolvedCtx and resolvedCtx.player or nil
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or 0
    local cx, cy = getContextMenuPoint(btn, xArg, yArg)
    local context = ISContextMenu and ISContextMenu.get and ISContextMenu.get(playerNum or 0, cx, cy) or nil
    if not context then
        return false
    end
    local actionOption = context:addOption(NMTranslations.ui("InsertMedia", "Insert Media"), nil, nil)
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, "slot.candidate_scan", 1)
    end
    local items = collectEligibleMediaItems(window)
    if #items <= 0 then
        actionOption.notAvailable = true
        return true
    end
    local sub = context:getNew(context)
    context:addSubMenu(actionOption, sub)
    for i = 1, #items do
        local item = items[i]
        local label = item.getDisplayName and item:getDisplayName() or NMTranslations.ui("Media", "Media")
        local option = sub:addOption(label, window, function(targetWin, targetItem)
            local liveItem = normalizeMediaIngressItem(targetWin, targetItem)
            if not liveItem then
                targetWin._nmPendingMediaSlotFullType = nil
                return
            end
            local payload = NMMediaHelpers.resolveMediaInsertPayload(liveItem)
            if not payload then return end
            primePendingMediaInsert(targetWin, payload.mediaEjectFullType or payload.mediaFullType or "")
            local args = buildMediaInsertArgs(liveItem, payload)
            if targetWin.queueContextMediaInsert then
                local handled = targetWin:queueContextMediaInsert(liveItem, payload, args)
                if handled ~= true then
                    targetWin._nmPendingMediaSlotFullType = nil
                end
                return
            end
            queueResolvedMediaInsert(targetWin, liveItem, payload, args, "context", "slot_insert_context_queue")
        end, item)
        option.itemForTexture = item
    end
    if options and options.autoOpenSubMenuForJoypad == true and actionOption and actionOption.subOption then
        local subMenu = context:getSubMenu(actionOption.subOption)
        if subMenu then
            context.mouseOver = 1
            subMenu.mouseOver = 1
            context:displaySubMenu(subMenu, actionOption)
        end
    end
    return true
end

function beginMediaExtractDrag(window, fullType, sourceZoneKind)
    local resolved = resolveWindowContext(window)
    local playerObj = resolved and resolved.player or nil
    local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
    local invPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
    if invPage and invPage.pin == false and invPage.setPinned then
        invPage:setPinned()
        window._nmMediaDragPinnedInventory = true
    end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local tex = resolveTextureByFullType(fullType)
    window._nmMediaExtractDrag = {
        slotType = "media",
        fullType = tostring(fullType or ""),
        sourceZoneKind = tostring(sourceZoneKind or "slot"),
        iconTex = tex,
        iconTint = { r = 1.0, g = 1.0, b = 1.0 },
        startX = mx,
        startY = my,
        moved = false
    }
    NMMediaSlot._ghostDragWindow = window
    logMediaExtractEvent("slot_extract_begin", window, window._nmMediaExtractDrag, {
        sourceZone = tostring(sourceZoneKind or "slot"),
        ghostAfter = "pending"
    })
    logPortableUiProbe(
        "slot_extract_drag_begin",
        string.format(
            "slot=media ui=%s targetItemId=%s targetUuid=%s mediaFullType=%s zone=%s",
            tostring(resolveWindowFamily(window)),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(fullType or ""),
            tostring(sourceZoneKind or "slot")
        )
    )
end

function stepMediaExtractDrag(window)
    local drag = window and window._nmMediaExtractDrag or nil
    if not drag then return end
    local mx = getMouseX and getMouseX() or drag.startX
    local my = getMouseY and getMouseY() or drag.startY
    if (not drag.moved) and (math.abs(mx - (drag.startX or mx)) > DRAG_THRESHOLD or math.abs(my - (drag.startY or my)) > DRAG_THRESHOLD) then
        drag.moved = true
        window._nmMediaExtractDrag = drag
        logMediaExtractEvent("slot_extract_moved", window, drag, {
            sourceZone = tostring(drag.sourceZoneKind or "slot"),
            mouse = tostring(mx) .. "," .. tostring(my)
        })
        logPortableUiProbe(
            "slot_extract_drag_moved",
            string.format(
                "slot=media ui=%s targetItemId=%s targetUuid=%s mediaFullType=%s zone=%s mouse=%s,%s",
                tostring(resolveWindowFamily(window)),
                tostring(window and window.target and window.target.itemId or ""),
                tostring(window and window.target and window.target.uuid or ""),
                tostring(drag.fullType or ""),
                tostring(drag.sourceZoneKind or "slot"),
                tostring(mx),
                tostring(my)
            )
        )
        if window and window.onMediaExtractDragThresholdCrossed then
            pcall(window.onMediaExtractDragThresholdCrossed, window, drag)
        end
    end
end

function collapsePinnedInventory(window, resolvedPlayer)
    if window and window._nmMediaDragPinnedInventory then
        local playerObj = resolvedPlayer
        if not playerObj then
            local resolved = resolveWindowContext(window)
            playerObj = resolved and resolved.player or nil
        end
        local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
        local invPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
        if invPage and invPage.collapse then
            invPage:collapse()
        end
        window._nmMediaDragPinnedInventory = nil
    end
end

local function clearMediaExtractTerminalState(window, clearInFlight)
    if window then
        window._nmMediaExtractDrag = nil
        if clearInFlight and window._nmSlotRemoveInFlightByType then
            window._nmSlotRemoveInFlightByType.media = nil
        end
        collapsePinnedInventory(window, nil)
    end
    NMMediaSlot._ghostDragWindow = nil
end

function finalizeMediaExtractCleanup(window)
    local drag = window and window._nmMediaExtractDrag or nil
    clearMediaExtractTerminalState(window, false)
    if clearMouseDragState then
        clearMouseDragState()
    end
    if NMMediaSlot and NMMediaSlot.ensureGhostOverlay then
        NMMediaSlot.ensureGhostOverlay()
    end
    logMediaExtractEvent("slot_extract_cleanup_result", window, drag, {
        sourceZone = drag and tostring(drag.sourceZoneKind or "slot") or "",
        detail = "finalize_cleanup",
        ghostBefore = "pending"
    })
end

function cancelMediaExtractDrag(window)
    local drag = window and window._nmMediaExtractDrag or nil
    clearMediaExtractTerminalState(window, true)
    logMediaExtractEvent("slot_extract_cleanup_result", window, drag, {
        sourceZone = drag and tostring(drag.sourceZoneKind or "slot") or "",
        detail = "cancel",
        ghostBefore = "pending"
    })
end

function isMediaReleaseOverSourceZone(window, drag)
    local zoneKind = tostring(drag and drag.sourceZoneKind or "slot")
    if zoneKind == "slot" then
        local slotButton = window and window.mediaSlot and window.mediaSlot.button or nil
        return isMouseOverButton(slotButton)
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.resolveOwningZone then
        local resolved = resolveWindowContext(window)
        local player = resolved and resolved.player or nil
        local playerNum = player and player.getPlayerNum and player:getPlayerNum() or window and window.playerNum or 0
        local winner = NMPortableMediaDropArbiter.resolveOwningZone(playerNum, zoneKind)
        return winner ~= nil
            and winner.window == window
            and tostring(winner.zoneKind or "") == zoneKind
            and tostring(winner.itemId or "") == tostring(window and window.target and window.target.itemId or "")
            and tostring(winner.uuid or "") == tostring(window and window.target and window.target.uuid or "")
    end
    return false
end

function completeMediaExtractDrag(window)
    local drag = window and window._nmMediaExtractDrag or nil
    if not drag then return false end
    local releaseOverSourceSlot = isMediaReleaseOverSourceZone(window, drag)
    clearMediaExtractTerminalState(window, false)
    if drag.moved ~= true then return false end
    if releaseOverSourceSlot then
        logMediaExtractEvent("slot_extract_finalize_result", window, drag, {
            sourceZone = tostring(drag.sourceZoneKind or "slot"),
            returnValue = "false",
            detail = "released_back_over_source"
        })
        return false
    end
    if isDuplicateEjectBlocked(window, drag.fullType) then
        logEjectQueueBlocked(window, drag.fullType, "extract_drag", drag.sourceZoneKind)
        logMediaExtractEvent("slot_extract_finalize_result", window, drag, {
            sourceZone = tostring(drag.sourceZoneKind or "slot"),
            returnValue = "false",
            detail = "duplicate_eject_blocked"
        })
        return false
    end
    window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
    window._nmSlotRemoveInFlightByType.media = true
    window._nmPendingMediaSlotFullType = tostring(drag.fullType or "")
    local args = {
        slotTraceId = nextSlotTraceId(),
        slotSourceTag = "extract_drag",
        slotZoneKind = tostring(drag.sourceZoneKind or "slot"),
        slotDeviceFamily = tostring(resolveWindowFamily(window))
    }
    logPortableUiProbe(
        "slot_eject_drag_queue",
        string.format(
            "ui=%s targetItemId=%s targetUuid=%s mediaFullType=%s source=%s zone=%s slotTraceId=%s",
            tostring(resolveWindowFamily(window)),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(drag.fullType or ""),
            "extract_drag",
            tostring(drag.sourceZoneKind or "slot"),
            tostring(args.slotTraceId or "")
        )
    )
    if queueMediaSlotAction(window, "eject_media", args) ~= true then
        window._nmPendingMediaSlotFullType = nil
        window._nmSlotRemoveInFlightByType.media = nil
        logMediaExtractEvent("slot_extract_finalize_result", window, drag, {
            sourceZone = tostring(drag.sourceZoneKind or "slot"),
            returnValue = "false",
            traceId = tostring(args.slotTraceId or ""),
            detail = "released_outside_source queue_failed"
        })
        return false
    end
    logMediaExtractEvent("slot_extract_finalize_result", window, drag, {
        sourceZone = tostring(drag.sourceZoneKind or "slot"),
        returnValue = "true",
        traceId = tostring(args.slotTraceId or ""),
        detail = "released_outside_source queue_success"
    })
    logPortableUiProbe(
        "slot_extract_drag_queue_success",
        string.format(
            "slot=media ui=%s targetItemId=%s targetUuid=%s mediaFullType=%s zone=%s slotTraceId=%s",
            tostring(resolveWindowFamily(window)),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(drag.fullType or ""),
            tostring(drag.sourceZoneKind or "slot"),
            tostring(args.slotTraceId or "")
        )
    )
    return true
end

function NMMediaSlot.cancelExtractDrag(window)
    cancelMediaExtractDrag(window)
end

function NMMediaSlot.beginMediaExtractDrag(window, fullType, sourceZoneKind)
    beginMediaExtractDrag(window, fullType, sourceZoneKind)
end

function NMMediaSlot.finalizeExtractDrag(window)
    return completeMediaExtractDrag(window)
end

function NMMediaSlot.ensureGhostOverlay()
    local batteryActive = false
    local batterySrc = NMBatterySlot and NMBatterySlot._ghostDragWindow or nil
    local batteryDrag = batterySrc and batterySrc._nmBatteryExtractDrag or nil
    if batteryDrag and batteryDrag.moved and batteryDrag.iconTex then
        batteryActive = true
    end
    local mediaActive = false
    local mediaSrc = NMMediaSlot._ghostDragWindow
    local mediaDrag = mediaSrc and mediaSrc._nmMediaExtractDrag or nil
    if mediaDrag and mediaDrag.moved and mediaDrag.iconTex then
        mediaActive = true
    end
    local headphoneActive = false
    local headphoneSrc = NMHeadphoneSlot and NMHeadphoneSlot._ghostDragWindow or nil
    local headphoneDrag = headphoneSrc and headphoneSrc._nmHeadphoneExtractDrag or nil
    if headphoneDrag and headphoneDrag.moved and headphoneDrag.iconTex then
        headphoneActive = true
    end
    local active = batteryActive or mediaActive or headphoneActive

    if (not active) and NMSlotGhostOverlay and NMSlotGhostOverlay.instance then
        local overlay = NMSlotGhostOverlay.instance
        if overlay.setVisible then overlay:setVisible(false) end
        if overlay.removeFromUIManager then overlay:removeFromUIManager() end
        NMSlotGhostOverlay.instance = nil
        return
    end

    if not active then return end
    if not NMSlotGhostOverlay then return end
    if not NMSlotGhostOverlay.instance then
        local ui = NMSlotGhostOverlay:new()
        ui:initialise()
        ui:instantiate()
        ui:addToUIManager()
        NMSlotGhostOverlay.instance = ui
    else
        local ui = NMSlotGhostOverlay.instance
        if ui.setVisible then ui:setVisible(true) end
        if ui.bringToTop then ui:bringToTop() end
    end
end

function NMMediaSlot.attach(window, x, y, size)
    local slotBtn = ISButton:new(x, y, size, size, "", window, function() end)
    slotBtn:initialise()
    slotBtn:instantiate()
    slotBtn.ownerWindow = window
    slotBtn.slotType = "media"
    slotBtn.zoneKind = "slot"
    window:addChild(slotBtn)

    local function swallowMediaSlotDoubleClick()
        cancelMediaExtractDrag(window)
        if clearMouseDragState then
            clearMouseDragState()
        end
        return true
    end

    local function onMediaSlotMouseDown()
        dispatchPortableMediaSlotMouseDown(window, "slot")
        return true
    end

    local function onMediaSlot()
        return dispatchPortableMediaSlotMouseUp(window, "slot")
    end

    local function onMediaSlotRightClick(btn, xArg, yArg)
        return dispatchPortableMediaSlotRightClick(window, "slot", btn, xArg, yArg)
    end

    slotBtn.onMouseDown = function(btn, xArg, yArg)
        return onMediaSlotMouseDown()
    end
    slotBtn.onMouseUp = function(btn, xArg, yArg)
        return onMediaSlot()
    end
    slotBtn.onMouseUpOutside = function(btn, xArg, yArg)
        return dispatchPortableMediaSlotMouseUp(window, "slot")
    end
    slotBtn.onMouseDoubleClick = function()
        return swallowMediaSlotDoubleClick()
    end
    slotBtn.onRightMouseDown = function(btn, xArg, yArg)
        cancelMediaExtractDrag(window)
        if clearMouseDragState then
            clearMouseDragState()
        end
        NMMediaSlot.ensureGhostOverlay()
        return true
    end
    slotBtn.onRightMouseUp = function(btn, xArg, yArg)
        return onMediaSlotRightClick(btn, xArg, yArg)
    end
    slotBtn.onRightMouseDoubleClick = function()
        return swallowMediaSlotDoubleClick()
    end
    slotBtn.onMouseMove = function(btn, dx, dy)
        stepMediaExtractDrag(window)
        NMMediaSlot.ensureGhostOverlay()
    end
    slotBtn.onMouseMoveOutside = function(btn, dx, dy)
        stepMediaExtractDrag(window)
        NMMediaSlot.ensureGhostOverlay()
    end

    local baseRender = slotBtn.render
    slotBtn.render = function(self)
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        self:setTitle("")
        local renderState = window.getSlotRenderState and window:getSlotRenderState("media") or nil
        local styleKey = renderState and renderState.styleKey or "slot"
        NMSlotButtonStyles.apply(self, styleKey)

        local fullType = renderState and renderState.fullType or ""
        local fillPct = renderState and renderState.fillPct or nil
        if fillPct ~= nil then
            local fillH = math.floor((self.height * fillPct) + 0.5)
            if fillH > 0 then
                self:drawRect(0, self.height - fillH, self.width, fillH, SLOT_PROGRESS_FILL.a, SLOT_PROGRESS_FILL.r, SLOT_PROGRESS_FILL.g, SLOT_PROGRESS_FILL.b)
            end
        end

        baseRender(self)

        if fullType ~= "" then
            drawMediaTexture(self, fullType)
            self.tooltip = renderState and renderState.tooltip or tostring(fullType)
        else
            local placeholderKey = renderState and renderState.placeholderKey or resolvePlaceholderKey(window)
            drawEmptyMediaTexture(self, placeholderKey)
            self.tooltip = renderState and renderState.tooltip or resolveEmptyInsertTooltip(window)
        end
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.media.render", perfStart)
        end
    end

    return {
        button = slotBtn,
        cancelDrag = function() cancelMediaExtractDrag(window) end,
    }
end
