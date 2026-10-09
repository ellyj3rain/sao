local env = _G.NMHeadphoneSlotEnv
setfenv(1, env)

local function logHeadphoneExtractEvent(eventName, window, drag, extra)
    if NMSlotActionCommon and NMSlotActionCommon.logSlotExtractEvent then
        local context = extra or {}
        context.window = window
        context.drag = drag
        context.slotType = "headphones"
        NMSlotActionCommon.logSlotExtractEvent(eventName, context)
    end
end

local function resolveWindowContext(window)
    if NMHeadphoneSlotContext and NMHeadphoneSlotContext.resolveWindowContext then
        return NMHeadphoneSlotContext.resolveWindowContext(window)
    end
    if not window then
        return nil
    end
    if window.resolveContextCached then
        return window:resolveContextCached()
    end
    return window.resolveContext and window:resolveContext() or nil
end

local function resolveDraggedItems(window)
    if NMHeadphoneSlotContext and NMHeadphoneSlotContext.resolveDraggedItems then
        return NMHeadphoneSlotContext.resolveDraggedItems(window)
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.resolveDraggedItemsSnapshot then
        return NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
    end
    return getDraggedInventoryItems()
end

local function clearHeadphoneTransientState(window)
    if NMHeadphoneSlotAuthority and NMHeadphoneSlotAuthority.clearHeadphoneTransientState then
        NMHeadphoneSlotAuthority.clearHeadphoneTransientState(window, nil, true)
        return
    end
    if not window then
        return
    end
    window._nmHeadphoneWearSyncInFlight = false
    window._nmPendingHeadphoneSlotFullType = nil
    window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
    window._nmSlotRemoveInFlightByType.headphones = nil
end

function beginHeadphoneExtractDrag(window, fullType)
    local resolved = resolveWindowContext(window)
    local playerObj = resolved and resolved.player or nil
    local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
    local invPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
    if invPage and invPage.pin == false and invPage.setPinned then
        invPage:setPinned()
        window._nmHeadphoneDragPinnedInventory = true
    end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    window._nmHeadphoneExtractDrag = {
        slotType = "headphones",
        fullType = tostring(fullType or ""),
        iconTex = resolveItemTextureForFullType(fullType),
        iconTint = { r = 1.0, g = 1.0, b = 1.0 },
        startX = mx,
        startY = my,
        moved = false
    }
    NMHeadphoneSlot._ghostDragWindow = window
    logHeadphoneExtractEvent("slot_extract_begin", window, window._nmHeadphoneExtractDrag, {
        sourceZone = "slot",
        ghostAfter = "pending"
    })
end

function stepHeadphoneExtractDrag(window)
    local drag = window and window._nmHeadphoneExtractDrag or nil
    if not drag then return end
    local mx = getMouseX and getMouseX() or drag.startX
    local my = getMouseY and getMouseY() or drag.startY
    if (not drag.moved) and (math.abs(mx - (drag.startX or mx)) > DRAG_THRESHOLD or math.abs(my - (drag.startY or my)) > DRAG_THRESHOLD) then
        drag.moved = true
        window._nmHeadphoneExtractDrag = drag
        logHeadphoneExtractEvent("slot_extract_moved", window, drag, {
            sourceZone = "slot",
            mouse = tostring(mx) .. "," .. tostring(my)
        })
    end
end

function collapsePinnedInventory(window, resolvedPlayer)
    if window and window._nmHeadphoneDragPinnedInventory then
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
        window._nmHeadphoneDragPinnedInventory = nil
    end
end

function cancelHeadphoneExtractDrag(window)
    local drag = window and window._nmHeadphoneExtractDrag or nil
    if window then
        window._nmHeadphoneExtractDrag = nil
        if window._nmSlotRemoveInFlightByType then
            window._nmSlotRemoveInFlightByType.headphones = nil
        end
        collapsePinnedInventory(window, nil)
    end
    NMHeadphoneSlot._ghostDragWindow = nil
    logHeadphoneExtractEvent("slot_extract_cleanup_result", window, drag, {
        sourceZone = drag and "slot" or "",
        detail = "cancel",
        ghostBefore = "pending"
    })
end

function completeHeadphoneExtractDrag(window, slotButton)
    local drag = window and window._nmHeadphoneExtractDrag or nil
    if not drag then return false end
    local releaseOverSourceSlot = isMouseOverButton(slotButton)
    window._nmHeadphoneExtractDrag = nil
    collapsePinnedInventory(window, nil)
    NMHeadphoneSlot._ghostDragWindow = nil
    if drag.moved ~= true then return false end
    if releaseOverSourceSlot then return false end
    window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
    if isDuplicateHeadphoneEjectBlocked and isDuplicateHeadphoneEjectBlocked(window, drag.fullType) then
        return false
    end
    window._nmSlotRemoveInFlightByType.headphones = true
    window._nmPendingHeadphoneSlotFullType = tostring(drag.fullType or "")
    if queueHeadphoneSlotAction(window, "eject_headphones", {}) ~= true then
        window._nmPendingHeadphoneSlotFullType = nil
        window._nmSlotRemoveInFlightByType.headphones = nil
        logHeadphoneExtractEvent("slot_extract_finalize_result", window, drag, {
            sourceZone = "slot",
            returnValue = "false",
            detail = "queue_failed"
        })
        return false
    end
    logHeadphoneExtractEvent("slot_extract_finalize_result", window, drag, {
        sourceZone = "slot",
        returnValue = "true",
        detail = "queue_success"
    })
    return true
end

function NMHeadphoneSlot.finalizeExtractDrag(window)
    local slotButton = window and window.headphoneSlot and window.headphoneSlot.button or nil
    return completeHeadphoneExtractDrag(window, slotButton)
end

function NMHeadphoneSlot.cancelExtractDrag(window)
    cancelHeadphoneExtractDrag(window)
end

function NMHeadphoneSlot.ensureGhostOverlay()
    local active = false
    local batterySrc = NMBatterySlot and NMBatterySlot._ghostDragWindow or nil
    local batteryDrag = batterySrc and batterySrc._nmBatteryExtractDrag or nil
    if batteryDrag and batteryDrag.moved and batteryDrag.iconTex then
        active = true
    end
    local mediaSrc = NMMediaSlot and NMMediaSlot._ghostDragWindow or nil
    local mediaDrag = mediaSrc and mediaSrc._nmMediaExtractDrag or nil
    if mediaDrag and mediaDrag.moved and mediaDrag.iconTex then
        active = true
    end
    local hpSrc = NMHeadphoneSlot._ghostDragWindow
    local hpDrag = hpSrc and hpSrc._nmHeadphoneExtractDrag or nil
    if hpDrag and hpDrag.moved and hpDrag.iconTex then
        active = true
    end
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

local SLOT_RELEASE = NMSlotActionCommon and NMSlotActionCommon.slotReleaseOutcomes and NMSlotActionCommon.slotReleaseOutcomes() or nil
local SLOT_RELEASE_NOT_OURS = SLOT_RELEASE and SLOT_RELEASE.notOurs or "not_ours"

local function resolveHeadphoneSlotReleaseOutcome(window, slotButton)
    if not (window and SLOT_RELEASE and NMSlotActionCommon and NMSlotActionCommon.resolveExtractReleaseOutcome) then
        return SLOT_RELEASE and SLOT_RELEASE.notOurs or "not_ours"
    end
    return NMSlotActionCommon.resolveExtractReleaseOutcome(
        window._nmHeadphoneExtractDrag,
        function()
            return isMouseOverButton(slotButton)
        end,
        function()
            cancelHeadphoneExtractDrag(window)
        end,
        function()
            return completeHeadphoneExtractDrag(window, slotButton) == true
        end
    )
end

local function consumeHeadphoneRelease(window, drag, releaseOutcome, entrypoint)
    local consume = NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome
        and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome(releaseOutcome)
        or false
    logHeadphoneExtractEvent(consume and "slot_extract_release_consumed" or "slot_extract_release_passed_through", window, drag, {
        sourceZone = "slot",
        returnValue = tostring(releaseOutcome or ""),
        consumeDecision = tostring(consume),
        entrypoint = entrypoint
    })
    return consume
end

local function performHeadphoneDragInsert(targetWindow, items)
    if not (targetWindow and type(items) == "table" and #items > 0) then
        return false
    end
    local resolved = resolveWindowContext(targetWindow)
    local state = resolved and resolved.state or nil
    if not isCompatibleHeadphoneDrag(targetWindow, items, resolved, state) then return false end
    local hpItem = pickFirstCompatibleHeadphone(targetWindow, items, resolved, state)
    if not hpItem then return false end
    local liveItem = normalizeHeadphoneIngressItem(targetWindow, hpItem)
    if not liveItem then
        clearHeadphoneTransientState(targetWindow)
        return false
    end
    targetWindow._nmPendingHeadphoneSlotFullType = tostring(liveItem:getFullType() or "")
    if queueHeadphoneSlotAction(targetWindow, "insert_headphones", { headphoneItemId = NMCore.itemId(liveItem) }) ~= true then
        clearHeadphoneTransientState(targetWindow)
        return false
    end
    return true
end

function NMHeadphoneSlot.attach(window, x, y, size)
    local slotBtn = ISButton:new(x, y, size, size, "", window, function() end)
    slotBtn:initialise()
    slotBtn:instantiate()
    slotBtn.ownerWindow = window
    slotBtn.slotType = "headphones"
    window:addChild(slotBtn)

    local function swallowHeadphoneSlotDoubleClick()
        cancelHeadphoneExtractDrag(window)
        if clearMouseDragState then
            clearMouseDragState()
        end
        return true
    end

    local function onHeadphoneSlotMouseDown()
        local resolved = resolveWindowContext(window)
        local profile = resolved and resolved.profile or nil
        if not (profile and NMDeviceProfiles.supportsHeadphones(profile)) then
            return true
        end
        local state = resolved and resolved.state or nil
        local items, ok = resolveDraggedItems(window)
        if ok ~= true then return true end
        if type(items) == "table" and #items > 0 then return true end
        local fullType = resolveHeadphoneSlotFullType(window, state)
        if fullType ~= "" then
            beginHeadphoneExtractDrag(window, fullType)
        end
        return true
    end

    local function onHeadphoneSlot()
        logHeadphoneExtractEvent("slot_extract_mouseup_slot", window, window and window._nmHeadphoneExtractDrag or nil, {
            sourceZone = "slot",
            entrypoint = "slot.onMouseUp"
        })
        local releaseOutcome = resolveHeadphoneSlotReleaseOutcome(window, slotBtn)
        if NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome then
            if releaseOutcome ~= SLOT_RELEASE_NOT_OURS then
                return consumeHeadphoneRelease(window, window and window._nmHeadphoneExtractDrag or nil, releaseOutcome, "slot.onMouseUp")
            end
        end
        local resolved = resolveWindowContext(window)
        local profile = resolved and resolved.profile or nil
        if not (profile and NMDeviceProfiles.supportsHeadphones(profile)) then
            return false
        end
        local state = resolved and resolved.state or nil
        local fullType = resolveHeadphoneSlotFullType(window, state)
        if fullType ~= "" then
            return false
        end
        local items, ok = resolveDraggedItems(window)
        if ok ~= true or type(items) ~= "table" or #items <= 0 then return false end
        if NMPortableSlotHoverResolver and NMPortableSlotHoverResolver.resolveHoveredHeadphoneSlotWindow then
            local player = resolved and resolved.player or nil
            local playerNum = player and player.getPlayerNum and player:getPlayerNum() or (window and window.playerNum) or 0
            local winner = NMPortableSlotHoverResolver.resolveHoveredHeadphoneSlotWindow(playerNum, items)
            local targetWindow = winner and winner.window or nil
            if performHeadphoneDragInsert(targetWindow, items) == true then
                clearMouseDragState()
                return true
            end
        end
        return false
    end

    local function onHeadphoneSlotRightClick(btn, xArg, yArg)
        local resolved = resolveWindowContext(window)
        local profile = resolved and resolved.profile or nil
        if not (profile and NMDeviceProfiles.supportsHeadphones(profile)) then
            return true
        end
        local state = resolved and resolved.state or nil
        local fullType = resolveHeadphoneSlotFullType(window, state)
        if fullType ~= "" then
            window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
            if isDuplicateHeadphoneEjectBlocked and isDuplicateHeadphoneEjectBlocked(window, fullType) then
                return true
            end
            window._nmSlotRemoveInFlightByType.headphones = true
            window._nmPendingHeadphoneSlotFullType = tostring(fullType or "")
            if queueHeadphoneSlotAction(window, "eject_headphones", {}) ~= true then
                clearHeadphoneTransientState(window)
            end
            return true
        end
        local player = resolved and resolved.player or nil
        local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or 0
        local cx, cy = getContextMenuPoint(btn, xArg, yArg)
        local context = ISContextMenu and ISContextMenu.get and ISContextMenu.get(playerNum or 0, cx, cy) or nil
        if not context then return true end
        local actionOption = context:addOption(NMTranslations.ui("InsertHeadphones", "Insert Headphones"), nil, nil)
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot.candidate_scan", 1)
        end
        local items = collectEligibleHeadphoneItems(window, resolved, state)
        if #items <= 0 then
            actionOption.notAvailable = true
            return true
        end
        local sub = context:getNew(context)
        context:addSubMenu(actionOption, sub)
        for i = 1, #items do
            local item = items[i]
            local label = item.getDisplayName and item:getDisplayName() or NMTranslations.ui("InsertHeadphones", "Insert Headphones")
            local option = sub:addOption(label, window, function(targetWin, targetItem)
                local liveItem = normalizeHeadphoneIngressItem(targetWin, targetItem)
                if not liveItem then
                    clearHeadphoneTransientState(targetWin)
                    return
                end
                targetWin._nmPendingHeadphoneSlotFullType = tostring(liveItem and liveItem.getFullType and liveItem:getFullType() or "")
                if queueHeadphoneSlotAction(targetWin, "insert_headphones", { headphoneItemId = NMCore.itemId(liveItem) }) ~= true then
                    clearHeadphoneTransientState(targetWin)
                end
            end, item)
            option.itemForTexture = item
        end
        return true
    end

    slotBtn.onMouseDown = function()
        return onHeadphoneSlotMouseDown()
    end
    slotBtn.onMouseUp = function()
        return onHeadphoneSlot()
    end
    slotBtn.onMouseUpOutside = function()
        logHeadphoneExtractEvent("slot_extract_mouseup_slot", window, window and window._nmHeadphoneExtractDrag or nil, {
            sourceZone = "slot",
            entrypoint = "slot.onMouseUpOutside"
        })
        local releaseOutcome = resolveHeadphoneSlotReleaseOutcome(window, slotBtn)
        if NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome then
            return consumeHeadphoneRelease(window, window and window._nmHeadphoneExtractDrag or nil, releaseOutcome, "slot.onMouseUpOutside")
        end
        return false
    end
    slotBtn.onMouseDoubleClick = function()
        return swallowHeadphoneSlotDoubleClick()
    end
    slotBtn.onRightMouseDown = function()
        return true
    end
    slotBtn.onRightMouseUp = function(btn, xArg, yArg)
        return onHeadphoneSlotRightClick(btn, xArg, yArg)
    end
    slotBtn.onRightMouseDoubleClick = function()
        return swallowHeadphoneSlotDoubleClick()
    end
    slotBtn.onMouseMove = function()
        stepHeadphoneExtractDrag(window)
        NMHeadphoneSlot.ensureGhostOverlay()
    end
    slotBtn.onMouseMoveOutside = function()
        stepHeadphoneExtractDrag(window)
        NMHeadphoneSlot.ensureGhostOverlay()
    end

    local baseRender = slotBtn.render
    slotBtn.render = function(self)
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        self:setTitle("")
        local renderState = window.getSlotRenderState and window:getSlotRenderState("headphones") or nil
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

        local perfBaseRenderStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        baseRender(self)
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.headphone.render.base", perfBaseRenderStart)
        end

        if not (renderState and renderState.supported) then
            self.tooltip = nil
            if NMUIRenderProbe and NMUIRenderProbe.endWindow then
                NMUIRenderProbe.endWindow(window, "slot.headphone.render", perfStart)
            end
            return
        end

        if fullType ~= "" then
            local tex = renderState and renderState.texture or nil
            if tex then
                local perfDrawTexStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
                local texW = tex.getWidthOrig and tex:getWidthOrig() or 32
                local texH = tex.getHeightOrig and tex:getHeightOrig() or 32
                local maxW = self.width - 8
                local maxH = self.height - 8
                local scale = math.min(maxW / texW, maxH / texH)
                local drawW = texW * scale
                local drawH = texH * scale
                local dx = (self.width - drawW) / 2
                local dy = (self.height - drawH) / 2
                self:drawTextureScaled(tex, dx, dy, drawW, drawH, 1.0, 1.0, 1.0, 1.0)
                if NMUIRenderProbe and NMUIRenderProbe.endWindow then
                    NMUIRenderProbe.endWindow(window, "slot.headphone.render.draw_tex", perfDrawTexStart)
                end
            end
            if renderState and renderState.tooltip then
                self.tooltip = renderState.tooltip
            else
                self.tooltip = resolveInsertedHeadphoneTooltip(fullType)
            end
        else
            local perfPlaceholderStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
            drawEmptyPlaceholder(self)
            if NMUIRenderProbe and NMUIRenderProbe.endWindow then
                NMUIRenderProbe.endWindow(window, "slot.headphone.render.placeholder", perfPlaceholderStart)
            end
            self.tooltip = renderState and renderState.tooltip or NMTranslations.ui("InsertHeadphones", "Insert Headphones")
        end
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.headphone.render", perfStart)
        end
    end

    return {
        button = slotBtn,
        cancelDrag = function() cancelHeadphoneExtractDrag(window) end
    }
end
