local env = _G.NMBatterySlotEnv
setfenv(1, env)

local function logBatteryExtractEvent(eventName, window, drag, extra)
    if NMSlotActionCommon and NMSlotActionCommon.logSlotExtractEvent then
        local context = extra or {}
        context.window = window
        context.drag = drag
        context.slotType = "battery"
        NMSlotActionCommon.logSlotExtractEvent(eventName, context)
    end
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

local function resolveDraggedItems(window)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.resolveDraggedItemsSnapshot then
        return NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
    end
    return getDraggedInventoryItems()
end

function beginBatteryExtractDrag(window, fullType)
    local resolved = resolveWindowContext(window)
    local playerObj = resolved and resolved.player or nil
    local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
    local invPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
    if invPage and invPage.pin == false and invPage.setPinned then
        invPage:setPinned()
        window._nmBatteryDragPinnedInventory = true
    end

    if not BATTERY_TEXTURE then
        BATTERY_TEXTURE = getTexture and (getTexture("Item_Battery") or getTexture("media/textures/Item_Battery.png")) or nil
    end
    local tex = BATTERY_TEXTURE
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    window._nmBatteryExtractDrag = {
        slotType = "battery",
        fullType = tostring(fullType or BATTERY_FULL_TYPE),
        iconTex = tex,
        iconTint = resolveBatteryTint(fullType),
        startX = mx,
        startY = my,
        moved = false,
    }
    NMBatterySlot._ghostDragWindow = window
    logBatteryExtractEvent("slot_extract_begin", window, window._nmBatteryExtractDrag, {
        sourceZone = "slot",
        ghostAfter = "pending"
    })
end

function stepBatteryExtractDrag(window)
    local drag = window and window._nmBatteryExtractDrag or nil
    if not drag then return end
    local mx = getMouseX and getMouseX() or drag.startX
    local my = getMouseY and getMouseY() or drag.startY
    if (not drag.moved) and (math.abs(mx - (drag.startX or mx)) > DRAG_THRESHOLD or math.abs(my - (drag.startY or my)) > DRAG_THRESHOLD) then
        drag.moved = true
        window._nmBatteryExtractDrag = drag
        logBatteryExtractEvent("slot_extract_moved", window, drag, {
            sourceZone = "slot",
            mouse = tostring(mx) .. "," .. tostring(my)
        })
    end
end

function collapsePinnedInventory(window, resolvedPlayer)
    if window and window._nmBatteryDragPinnedInventory then
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
        window._nmBatteryDragPinnedInventory = nil
    end
end

function cancelBatteryExtractDrag(window)
    local drag = window and window._nmBatteryExtractDrag or nil
    local ghostBefore = NMSlotActionCommon and NMSlotActionCommon.resolveSlotHostFamily and "pending" or nil
    if window then
        window._nmBatteryExtractDrag = nil
        if window._nmSlotRemoveInFlightByType then
            window._nmSlotRemoveInFlightByType.battery = nil
        end
        collapsePinnedInventory(window, nil)
    end
    NMBatterySlot._ghostDragWindow = nil
    logBatteryExtractEvent("slot_extract_cleanup_result", window, drag, {
        sourceZone = drag and "slot" or "",
        detail = "cancel",
        ghostBefore = ghostBefore
    })
end

function completeBatteryExtractDrag(window, slotButton)
    local drag = window and window._nmBatteryExtractDrag or nil
    if not drag then return false end
    local releaseOverSourceSlot = isMouseOverButton(slotButton)
    window._nmBatteryExtractDrag = nil
    collapsePinnedInventory(window, nil)
    NMBatterySlot._ghostDragWindow = nil
    if drag.moved ~= true then return false end
    if releaseOverSourceSlot then return false end
    window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
    if isDuplicateBatteryEjectBlocked and isDuplicateBatteryEjectBlocked(window, drag.fullType) then
        return false
    end
    window._nmSlotRemoveInFlightByType.battery = true
    window._nmPendingBatterySlotFullType = tostring(drag.fullType or BATTERY_FULL_TYPE)
    if queueBatterySlotAction(window, "eject_battery", {}) ~= true then
        window._nmPendingBatterySlotFullType = nil
        window._nmSlotRemoveInFlightByType.battery = nil
        logBatteryExtractEvent("slot_extract_finalize_result", window, drag, {
            sourceZone = "slot",
            returnValue = "false",
            detail = "queue_failed"
        })
        return false
    end
    logBatteryExtractEvent("slot_extract_finalize_result", window, drag, {
        sourceZone = "slot",
        returnValue = "true",
        detail = "queue_success"
    })
    return true
end

function NMBatterySlot.finalizeExtractDrag(window)
    local slotButton = window and window.batterySlot and window.batterySlot.button or nil
    return completeBatteryExtractDrag(window, slotButton)
end

function NMBatterySlot.cancelExtractDrag(window)
    cancelBatteryExtractDrag(window)
end

function NMBatterySlot.ensureGhostOverlay()
    local active = false
    local src = NMBatterySlot._ghostDragWindow
    if src and src._nmBatteryExtractDrag and src._nmBatteryExtractDrag.moved and src._nmBatteryExtractDrag.iconTex then
        active = true
    end
    if not active and NMMediaSlot and NMMediaSlot._ghostDragWindow then
        local mediaSrc = NMMediaSlot._ghostDragWindow
        local mediaDrag = mediaSrc and mediaSrc._nmMediaExtractDrag or nil
        if mediaDrag and mediaDrag.moved and mediaDrag.iconTex then
            active = true
        end
    end
    if not active and NMHeadphoneSlot and NMHeadphoneSlot._ghostDragWindow then
        local hpSrc = NMHeadphoneSlot._ghostDragWindow
        local hpDrag = hpSrc and hpSrc._nmHeadphoneExtractDrag or nil
        if hpDrag and hpDrag.moved and hpDrag.iconTex then
            active = true
        end
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

local function resolveBatterySlotReleaseOutcome(window, slotButton)
    if not (window and SLOT_RELEASE and NMSlotActionCommon and NMSlotActionCommon.resolveExtractReleaseOutcome) then
        return SLOT_RELEASE and SLOT_RELEASE.notOurs or "not_ours"
    end
    return NMSlotActionCommon.resolveExtractReleaseOutcome(
        window._nmBatteryExtractDrag,
        function()
            return isMouseOverButton(slotButton)
        end,
        function()
            cancelBatteryExtractDrag(window)
        end,
        function()
            return completeBatteryExtractDrag(window, slotButton) == true
        end
    )
end

local function consumeBatteryRelease(window, drag, releaseOutcome, entrypoint)
    local consume = NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome
        and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome(releaseOutcome)
        or false
    logBatteryExtractEvent(consume and "slot_extract_release_consumed" or "slot_extract_release_passed_through", window, drag, {
        sourceZone = "slot",
        returnValue = tostring(releaseOutcome or ""),
        consumeDecision = tostring(consume),
        entrypoint = entrypoint
    })
    return consume
end

local function performBatteryDragInsert(targetWindow, items)
    if not (targetWindow and type(items) == "table" and #items > 0) then
        return false
    end
    if not isCompatibleBatteryDrag(items) then return false end
    local batteryItem = pickFirstBattery(items)
    if not batteryItem then return false end
    local liveItem = normalizeBatteryIngressItem(targetWindow, batteryItem)
    if not liveItem then
        targetWindow._nmPendingBatterySlotFullType = nil
        return false
    end
    targetWindow._nmPendingBatterySlotFullType = BATTERY_FULL_TYPE
    if queueBatterySlotAction(targetWindow, "insert_battery", { batteryItemId = NMCore.itemId(liveItem) }) ~= true then
        targetWindow._nmPendingBatterySlotFullType = nil
        return false
    end
    return true
end

function NMBatterySlot.attach(window, x, y, size)
    local slotBtn = ISButton:new(x, y, size, size, "", window, function() end)
    slotBtn:initialise()
    slotBtn:instantiate()
    slotBtn.ownerWindow = window
    slotBtn.slotType = "battery"
    window:addChild(slotBtn)

    local function swallowBatterySlotDoubleClick()
        cancelBatteryExtractDrag(window)
        if clearMouseDragState then
            clearMouseDragState()
        end
        return true
    end

    local barPanel = ISPanel:new(x, y + size + BAR_PAD_TOP, size, BAR_H)
    barPanel:initialise()
    barPanel:instantiate()
    barPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    barPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    barPanel.render = function(selfPanel)
        local renderState = window and window.getSlotRenderState and window:getSlotRenderState("battery") or nil
        local fullType = renderState and renderState.fullType or ""
        if fullType == "" then
            return
        end
        local w = tonumber(selfPanel.width) or 0
        local h = tonumber(selfPanel.height) or 0
        selfPanel:drawRect(0, 0, w, h, BAR_BG.a, BAR_BG.r, BAR_BG.g, BAR_BG.b)
        local pct = NMCore.clamp(tonumber(renderState and renderState.batteryPct or 0.0) or 0.0, 0.0, 1.0)
        if pct <= 0.0001 then
            -- Dead battery inserted: draw explicit red full-lane indicator.
            selfPanel:drawRect(0, 0, w, h, BAR_EMPTY_FILL.a, BAR_EMPTY_FILL.r, BAR_EMPTY_FILL.g, BAR_EMPTY_FILL.b)
        else
            local fw = math.floor((w * pct) + 0.5)
            if fw > 0 then
                selfPanel:drawRect(0, 0, fw, h, BAR_FILL.a, BAR_FILL.r, BAR_FILL.g, BAR_FILL.b)
            end
        end
    end
    window:addChild(barPanel)

    local function onBatterySlotMouseDown()
        local resolved = resolveWindowContext(window)
        local state = resolved and resolved.state or nil
        local items, ok = resolveDraggedItems(window)
        if ok ~= true then return true end
        if type(items) == "table" and #items > 0 then return true end
        local fullType = resolveBatterySlotFullType(window, state)
        if fullType ~= "" then
            beginBatteryExtractDrag(window, fullType)
        end
        return true
    end

    local function onBatterySlot()
        logBatteryExtractEvent("slot_extract_mouseup_slot", window, window and window._nmBatteryExtractDrag or nil, {
            sourceZone = "slot",
            entrypoint = "slot.onMouseUp"
        })
        local releaseOutcome = resolveBatterySlotReleaseOutcome(window, slotBtn)
        if NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome then
            if releaseOutcome ~= SLOT_RELEASE_NOT_OURS then
                return consumeBatteryRelease(window, window and window._nmBatteryExtractDrag or nil, releaseOutcome, "slot.onMouseUp")
            end
        end

        local resolved = resolveWindowContext(window)
        local state = resolved and resolved.state or nil
        local fullType = resolveBatterySlotFullType(window, state)
        if fullType ~= "" then
            return false
        end

        local items, ok = resolveDraggedItems(window)
        if ok ~= true or type(items) ~= "table" or #items <= 0 then return false end
        if NMPortableSlotHoverResolver and NMPortableSlotHoverResolver.resolveHoveredBatterySlotWindow then
            local resolvedPlayer = resolved and resolved.player or nil
            local playerNum = resolvedPlayer and resolvedPlayer.getPlayerNum and resolvedPlayer:getPlayerNum() or (window and window.playerNum) or 0
            local winner = NMPortableSlotHoverResolver.resolveHoveredBatterySlotWindow(playerNum, items)
            local targetWindow = winner and winner.window or nil
            if performBatteryDragInsert(targetWindow, items) == true then
                clearMouseDragState()
                return true
            end
        end
        return false
    end

    local function onBatterySlotRightClick(btn, xArg, yArg)
        local resolved = resolveWindowContext(window)
        local state = resolved and resolved.state or nil
        local fullType = resolveBatterySlotFullType(window, state)
        if fullType ~= "" then
            window._nmSlotRemoveInFlightByType = window._nmSlotRemoveInFlightByType or {}
            if isDuplicateBatteryEjectBlocked and isDuplicateBatteryEjectBlocked(window, fullType) then
                return true
            end
            window._nmSlotRemoveInFlightByType.battery = true
            window._nmPendingBatterySlotFullType = tostring(fullType or BATTERY_FULL_TYPE)
            if queueBatterySlotAction(window, "eject_battery", {}) ~= true then
                window._nmPendingBatterySlotFullType = nil
                window._nmSlotRemoveInFlightByType.battery = nil
            end
            return true
        end
        if isBatteryInsertPending(window, state) then
            return true
        end
        openEmptySlotContextMenu(window, btn, xArg, yArg)
        return true
    end

    slotBtn.onMouseDown = function(btn, xArg, yArg)
        return onBatterySlotMouseDown()
    end
    slotBtn.onMouseUp = function(btn, xArg, yArg)
        return onBatterySlot()
    end
    slotBtn.onMouseUpOutside = function(btn, xArg, yArg)
        logBatteryExtractEvent("slot_extract_mouseup_slot", window, window and window._nmBatteryExtractDrag or nil, {
            sourceZone = "slot",
            entrypoint = "slot.onMouseUpOutside"
        })
        local releaseOutcome = resolveBatterySlotReleaseOutcome(window, slotBtn)
        if NMSlotActionCommon and NMSlotActionCommon.shouldConsumeSlotReleaseOutcome then
            return consumeBatteryRelease(window, window and window._nmBatteryExtractDrag or nil, releaseOutcome, "slot.onMouseUpOutside")
        end
        return false
    end
    slotBtn.onMouseDoubleClick = function()
        return swallowBatterySlotDoubleClick()
    end
    slotBtn.onRightMouseDown = function(btn, xArg, yArg)
        return true
    end
    slotBtn.onRightMouseUp = function(btn, xArg, yArg)
        return onBatterySlotRightClick(btn, xArg, yArg)
    end
    slotBtn.onRightMouseDoubleClick = function()
        return swallowBatterySlotDoubleClick()
    end
    slotBtn.onMouseMove = function(btn, dx, dy)
        stepBatteryExtractDrag(window)
        NMBatterySlot.ensureGhostOverlay()
    end
    slotBtn.onMouseMoveOutside = function(btn, dx, dy)
        stepBatteryExtractDrag(window)
        NMBatterySlot.ensureGhostOverlay()
    end

    local baseRender = slotBtn.render
    slotBtn.render = function(self)
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        self:setTitle("")
        local renderState = window.getSlotRenderState and window:getSlotRenderState("battery") or nil
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
            drawBatteryTexture(self)
            self.tooltip = renderState and renderState.tooltip or NMTranslations.ui("InsertBattery", "Insert Battery")
        else
            drawEmptyBatteryTexture(self)
            self.tooltip = renderState and renderState.tooltip or NMTranslations.ui("InsertBattery", "Insert Battery")
        end
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.battery.render", perfStart)
        end
    end

    return {
        button = slotBtn,
        bar = barPanel,
        cancelDrag = function() cancelBatteryExtractDrag(window) end,
    }
end
