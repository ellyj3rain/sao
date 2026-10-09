
local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local UiLifecycleItemWindows = require "ui/shared/host/NMUiLifecycleItemWindows"

local function getButtonScreenRect(button)
    if not button then
        return nil
    end
    local x = button.getAbsoluteX and button:getAbsoluteX() or nil
    local y = button.getAbsoluteY and button:getAbsoluteY() or nil
    local w = tonumber(button.width) or 0
    local h = tonumber(button.height) or 0
    if x == nil or y == nil or w <= 0 or h <= 0 then
        return nil
    end
    return { x = x, y = y, w = w, h = h }
end

local function getWindowScreenRect(window, rect)
    if not (window and rect) then
        return nil
    end
    local ax = window.getAbsoluteX and window:getAbsoluteX() or nil
    local ay = window.getAbsoluteY and window:getAbsoluteY() or nil
    local w = tonumber(rect.w) or 0
    local h = tonumber(rect.h) or 0
    if ax == nil or ay == nil or w <= 0 or h <= 0 then
        return nil
    end
    return {
        x = ax + (tonumber(rect.x) or 0),
        y = ay + (tonumber(rect.y) or 0),
        w = w,
        h = h
    }
end

local function isWindowVisible(window)
    if not (window and window.javaObject) then
        return false
    end
    if window.getIsVisible then
        return window:getIsVisible() == true
    end
    if window.isVisible then
        return window:isVisible() == true
    end
    return true
end

local function getMediaSlotEnv()
    return rawget(_G, "NMMediaSlotEnv") or nil
end

local function isFancyUIEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyUIEnabled then
        return NMRuntimeConfig.getFancyUIEnabled() == true
    end
    return true
end

local function collectPlayerWindows(playerNum)
    return WindowRegistry and WindowRegistry.collectWindows and WindowRegistry.collectWindows(env, playerNum) or {}
end

local function registerWindow(window)
    if WindowRegistry and WindowRegistry.registerWindow then
        WindowRegistry.registerWindow(env, window)
    end
end

local function unregisterWindow(window)
    if WindowRegistry and WindowRegistry.unregisterWindow then
        WindowRegistry.unregisterWindow(env, window)
    end
end

local function logOpenTrace(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle")) then
        return
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "walkman_open"), tostring(detail or ""))
end

-- Safety net for pre-registry or stale-key windows during UI/session transitions.
function getOrCreateWindow(playerNum)
    refreshWalkmanLayoutMetrics()
    local screenW, screenH = getScreenSize()
    local x = math.max(0, screenW - PANEL_W - DEFAULT_RIGHT_MARGIN)
    local y = math.max(0, screenH - PANEL_H - EXPANDED_BOTTOM_MARGIN)
    local win = WalkmanWindow:new(x, y, PANEL_W, PANEL_H)
    win.playerNum = tonumber(playerNum) or 0
    win:initialise()
    attachWalkmanSlots(win)
    win:applyCurrentScaleLayout()
    win:addToUIManager()
    return win
end
function NMWalkmanWindow.openForItemResolved(playerNum, item, resolvedContext)
    if not isFancyUIEnabled() then
        return nil
    end
    local player = getPlayer(playerNum)
    if not (player and item) then
        return nil
    end
    local resolved = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemLifecycleContext(item)
    local profile = resolved and resolved.profile or (NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil)
    if not profile or tostring(profile.deviceType or "") ~= "walkman" then
        return nil
    end
    local identity = resolved and resolved.itemId and resolved or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local itemUuid = identity.itemUuid ~= "" and identity.itemUuid or nil
    local targetKey = tostring(identity.targetKey or "")
    local win, lookup = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
    logOpenTrace(
        "walkman_open_lookup",
        string.format(
            "player=%s targetKey=%s registryHit=%s itemId=%s uuid=%s",
            tostring(playerNum or 0),
            tostring(targetKey or ""),
            tostring(lookup and lookup.registryHit == true),
            tostring(NMCore and NMCore.itemId and NMCore.itemId(item) or ""),
            tostring(itemUuid or "")
        )
    )
    if lookup and lookup.registryHit ~= true then
        logOpenTrace(
            "walkman_open_fallback",
            string.format(
                "player=%s targetKey=%s fallbackHit=%s itemId=%s uuid=%s",
                tostring(playerNum or 0),
                tostring(targetKey or ""),
                tostring(lookup and lookup.fallbackHit == true),
                tostring(NMCore and NMCore.itemId and NMCore.itemId(item) or ""),
                tostring(itemUuid or "")
            )
        )
    end
    local reusedExisting = win ~= nil
    if not win then
        win = getOrCreateWindow(playerNum)
    end
    win:applyCurrentScaleLayout()
    local currentX = tonumber(win:getX())
    local currentY = tonumber(win._nmExpandedY)
    if not currentX then
        local screenW = getScreenSize()
        currentX = math.max(0, screenW - PANEL_W - DEFAULT_RIGHT_MARGIN)
    end
    if currentY == nil then
        currentY = win:getDefaultExpandedY()
    end
    win:setX(win:clampWindowX(currentX))
    win._nmExpandedY = win:clampWindowY(currentY)
    win:snapToState(false)
    win._nmHasObservedPlayState = false
    win._nmAuthoritativePlayDown = false
    win.isPlayButtonAnimating = false
    win.playButtonAnimStartY = nil
    win.playButtonAnimTargetY = nil
    win.playButtonAnimStartTime = nil
    win.playButtonCurrentY = win:getPlayButtonY(false)
    win.isPrevButtonAnimating = false
    win.prevButtonPhase = nil
    win.prevButtonCurrentY = win:getPrevButtonY(false)
    win.prevButtonAnimStartY = nil
    win.prevButtonAnimTargetY = nil
    win.prevButtonAnimStartTime = nil
    win.isNextButtonAnimating = false
    win.nextButtonPhase = nil
    win.nextButtonCurrentY = win:getNextButtonY(false)
    win.nextButtonAnimStartY = nil
    win.nextButtonAnimTargetY = nil
    win.nextButtonAnimStartTime = nil
    win._nmWheelDragging = false
    win._nmWheelStableVolume = nil
    win._nmWheelPreviewVolume = nil
    win._nmWheelPendingDispatchVolume = nil
    win._nmWheelLastDispatchMs = 0
    win._nmWheelLastDispatchedVolume = nil
    win._nmWheelLastClickPercent = nil
    win._nmWheelLastClickSoundMs = 0
    win._nmWheelLabelVisibleUntil = 0
    win._nmLoopIconVisibleUntil = 0
    win._nmWheelDragStartMouseY = nil
    win._nmWheelDragStartVolume = nil
    win._nmLoopButtonPressed = false
    win.isLoopButtonAnimating = false
    win.loopButtonPhase = nil
    win.loopButtonCurrentX = win:getLoopButtonX(false)
    win.loopButtonAnimStartX = nil
    win.loopButtonAnimTargetX = nil
    win.loopButtonAnimStartTime = nil
    win._nmLeftSpoolAngle = 0.0
    win._nmRightSpoolAngle = 0.0
    win._nmSpoolLastUpdateMs = getNowMs()
    win.isLidAnimating = false
    win.lidAnimStartY = nil
    win.lidAnimStartH = nil
    win.lidAnimTargetY = nil
    win.lidAnimTargetH = nil
    win.lidAnimStartTime = nil
    win.lidCurrentY = LID_OPEN_Y
    win.lidCurrentH = LID_OPEN_H
    win.isLidOpen = true
    win.target = {
        kind = "item",
        itemId = NMCore and NMCore.itemId and NMCore.itemId(item) or nil,
        uuid = itemUuid,
        itemRef = item
    }
    win:invalidateContextCache()
    win:invalidateSlotFrameModel()
    win._nmPendingMediaSlotFullType = nil
    win._nmPendingHeadphoneSlotFullType = nil
    win._nmPendingBatterySlotFullType = nil
    win._nmSlotRemoveInFlightByType = {}
    win._nmLidHadMedia = false
    win._nmMediaEjectInterrupted = nil
    win._nmAwaitingAuthoritativeMediaEject = nil
    win._nmAwaitingAuthoritativeMediaInsert = nil
    win.isLidManuallyOpen = true
    win:syncVolumeWheelFromState(true)
    win:syncPlayButtonFromTransport(nil, false, true)
    win:syncLidFromMedia(true)
    win:setVisible(true)
    win:bringToTop()
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(win, "walkman")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(win, "walkman")
    end
    registerWindow(win)
    logOpenTrace(
        "walkman_open_result",
        string.format(
            "player=%s reused=%s targetKey=%s window=%s targetItemId=%s targetUuid=%s",
            tostring(playerNum or 0),
            tostring(reusedExisting),
            tostring(targetKey or ""),
            tostring(win),
            tostring(win.target and win.target.itemId or ""),
            tostring(win.target and win.target.uuid or "")
        )
    )
    persistWindowState(win, true)
    return win
end

function NMWalkmanWindow.openForItem(playerNum, item)
    return NMWalkmanWindow.openForItemResolved(playerNum, item, nil)
end

function NMWalkmanWindow.findOpenForItemResolved(playerNum, item, resolvedContext)
    local identity = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local exact = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
    return exact
end

function NMWalkmanWindow.findOpenForItem(playerNum, item)
    return NMWalkmanWindow.findOpenForItemResolved(playerNum, item, nil)
end

function NMWalkmanWindow.invalidateOpenItemWindow(itemId, uuid)
    return UiLifecycleItemWindows.applyOpenItemWindowChange(env, itemId, uuid, {
        mode = "invalidate",
        resolveWindowUuid = function(win)
            local resolved = win.resolveContextFresh and win:resolveContextFresh() or (win.resolveContext and win:resolveContext()) or nil
            local state = resolved and resolved.state or nil
            return tostring(state and state.deviceUUID or "")
        end,
        deferInvalidate = function(win)
            return NMSlotHostLifecycle.deferUiRefreshUntilDragEnd
                and NMSlotHostLifecycle.deferUiRefreshUntilDragEnd(win, {
                    cause = "walkman_open_item_window_invalidate_deferred",
                    visibility = false,
                }) == true
        end,
        invalidateWindow = function(win)
            win:invalidateContextCache()
            win:invalidateSlotFrameModel()
            if win.invalidateRenderModel then
                win:invalidateRenderModel()
            end
        end,
    })
end

function NMWalkmanWindow.rebindOpenPortableItemWindow(itemId, uuid)
    return UiLifecycleItemWindows.applyOpenItemWindowChange(env, itemId, uuid, {
        mode = "rebind",
        deferInvalidate = function(win)
            return NMSlotHostLifecycle.deferUiRefreshUntilDragEnd
                and NMSlotHostLifecycle.deferUiRefreshUntilDragEnd(win, {
                    cause = "walkman_open_item_window_rebind_deferred",
                    visibility = false,
                }) == true
        end,
        invalidateWindow = function(win)
            win:invalidateContextCache()
            win:invalidateSlotFrameModel()
            if win.invalidateRenderModel then
                win:invalidateRenderModel()
            end
        end,
    })
end

function NMWalkmanWindow.inspectOpenItemWindowTarget(playerNum)
    return UiLifecycleItemWindows.inspectOpenItemWindowTarget(env, playerNum)
end

function NMWalkmanWindow.closeOpenForItemTarget(playerNum, itemId, uuid)
    return UiLifecycleItemWindows.closeOpenForItemTarget(env, playerNum, itemId, uuid, {
        closeWindow = function(win)
            NMSlotHostLifecycle.cancelSharedSlotDrags(win)
            if win.setVisible then
                win:setVisible(false)
            end
            if win.removeFromUIManager then
                win:removeFromUIManager()
            end
            unregisterWindow(win)
        end,
    })
end

function NMWalkmanWindow.collectOpenMediaIngressZones(playerNum, dragItems)
    local mediaEnv = getMediaSlotEnv()
    local resolveMediaSlotFullTypeFn = mediaEnv and mediaEnv.resolveMediaSlotFullType or nil
    local queueDraggedMediaInsertFn = mediaEnv and mediaEnv.queueDraggedMediaInsert or nil
    local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
    if not (resolveMediaSlotFullTypeFn and queueDraggedMediaInsertFn and queueMediaSlotEjectFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local slotRect = getButtonScreenRect(win.mediaSlot and win.mediaSlot.button or nil)
            if slotRect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedMediaSlotZone({
            window = win,
            uiFamily = "walkman",
            zoneKind = "slot",
            rect = slotRect,
            priority = 10,
            zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
            dragItems = dragItems,
            canAcceptDraggedMedia = function(items)
                return type(items) == "table"
                    and #items > 0
                    and isCompatibleWalkmanMediaDrag(win, items)
                    and resolveMediaSlotFullTypeFn(win, state) == ""
                    and not (win.isAwaitingAuthoritativeMediaEject and win:isAwaitingAuthoritativeMediaEject() == true)
            end,
            canEjectMedia = function()
                return resolveMediaSlotFullTypeFn(win, state) ~= ""
            end,
            canStartExtractDrag = function()
                return resolveMediaSlotFullTypeFn(win, state) ~= ""
            end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end
            local auxRect = win.getLidIngressZoneRect and getWindowScreenRect(win, win:getLidIngressZoneRect()) or nil
            if auxRect then
                zones[#zones + 1] = {
                    uiFamily = "walkman",
                    zoneKind = "aux",
                    priority = 20,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    playerNum = tonumber(win.playerNum) or 0,
                    itemId = win.target.itemId,
                    uuid = win.target.uuid,
                    window = win,
                    rect = auxRect,
                    visible = true,
                    enabled = true,
                    interactive = true,
                    canAccept = win.canAcceptDraggedMediaViaLid and win:canAcceptDraggedMediaViaLid() == true,
                    canAcceptDraggedMedia = function(items)
                        return win.canAcceptDraggedMediaViaLid and win:canAcceptDraggedMediaViaLid() == true
                            and type(items) == "table"
                            and #items > 0
                    end
                }
            end
        end
    end
    return zones
end

function NMWalkmanWindow.collectOpenBatteryIngressZones(playerNum, dragItems)
    local batteryEnv = rawget(_G, "NMBatterySlotEnv") or nil
    local resolveBatterySlotFullTypeFn = batteryEnv and batteryEnv.resolveBatterySlotFullType or nil
    local isCompatibleBatteryDragFn = batteryEnv and batteryEnv.isCompatibleBatteryDrag or nil
    local pickFirstBatteryFn = batteryEnv and batteryEnv.pickFirstBattery or nil
    local normalizeBatteryIngressItemFn = batteryEnv and batteryEnv.normalizeBatteryIngressItem or nil
    local queueBatterySlotActionFn = batteryEnv and batteryEnv.queueBatterySlotAction or nil
    local beginBatteryExtractDragFn = batteryEnv and batteryEnv.beginBatteryExtractDrag or nil
    if not (resolveBatterySlotFullTypeFn and isCompatibleBatteryDragFn and pickFirstBatteryFn and normalizeBatteryIngressItemFn and queueBatterySlotActionFn and beginBatteryExtractDragFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local rect = getButtonScreenRect(win.batterySlot and win.batterySlot.button or nil)
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "walkman",
                    zoneKind = "battery",
                    rect = rect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table"
                            and #items > 0
                            and isCompatibleBatteryDragFn(items)
                            and resolveBatterySlotFullTypeFn(win, state) == ""
                    end,
                    canEjectMedia = function()
                        return resolveBatterySlotFullTypeFn(win, state) ~= ""
                    end,
                    canStartExtractDrag = function()
                        return resolveBatterySlotFullTypeFn(win, state) ~= ""
                    end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end
        end
    end
    return zones
end

function NMWalkmanWindow.collectOpenHeadphoneIngressZones(playerNum, dragItems)
    local headphoneEnv = rawget(_G, "NMHeadphoneSlotEnv") or nil
    local resolveHeadphoneSlotFullTypeFn = headphoneEnv and headphoneEnv.resolveHeadphoneSlotFullType or nil
    local isCompatibleHeadphoneDragFn = headphoneEnv and headphoneEnv.isCompatibleHeadphoneDrag or nil
    local pickFirstCompatibleHeadphoneFn = headphoneEnv and headphoneEnv.pickFirstCompatibleHeadphone or nil
    local normalizeHeadphoneIngressItemFn = headphoneEnv and headphoneEnv.normalizeHeadphoneIngressItem or nil
    local queueHeadphoneSlotActionFn = headphoneEnv and headphoneEnv.queueHeadphoneSlotAction or nil
    local beginHeadphoneExtractDragFn = headphoneEnv and headphoneEnv.beginHeadphoneExtractDrag or nil
    if not (resolveHeadphoneSlotFullTypeFn and isCompatibleHeadphoneDragFn and pickFirstCompatibleHeadphoneFn and normalizeHeadphoneIngressItemFn and queueHeadphoneSlotActionFn and beginHeadphoneExtractDragFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local rect = getButtonScreenRect(win.headphoneSlot and win.headphoneSlot.button or nil)
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "walkman",
                    zoneKind = "headphones",
                    rect = rect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table"
                            and #items > 0
                            and isCompatibleHeadphoneDragFn(win, items, resolved, state)
                            and resolveHeadphoneSlotFullTypeFn(win, state) == ""
                    end,
                    canEjectMedia = function()
                        return resolveHeadphoneSlotFullTypeFn(win, state) ~= ""
                    end,
                    canStartExtractDrag = function()
                        return resolveHeadphoneSlotFullTypeFn(win, state) ~= ""
                    end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end
        end
    end
    return zones
end

function WalkmanWindow:close()
    NMSlotHostLifecycle.cancelSharedSlotDrags(self)
    if self.tooltipUI then
        self.tooltipUI:setVisible(false)
        if self.tooltipUI.removeFromUIManager then
            self.tooltipUI:removeFromUIManager()
        end
    end
    if self.setVisible then
        self:setVisible(false)
    end
    if self.removeFromUIManager then
        self:removeFromUIManager()
    end
    if NMGamepadWindowTracker and NMGamepadWindowTracker.unregisterWindow then
        NMGamepadWindowTracker.unregisterWindow(self)
    end
    unregisterWindow(self)
end

function WalkmanWindow:resolveSettingsGearTint(model)
    local tint = model and type(model.closeTint) == "table" and model.closeTint or nil
    if tint then
        return 1.0, tint[1], tint[2], tint[3]
    end
    return 1.0, 0.78, 0.78, 0.78
end

function WalkmanWindow:new(x, y, width, height)
    refreshWalkmanLayoutMetrics()
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    if o.setConsumeMouseEvents then
        o:setConsumeMouseEvents(false)
    end
    o.keepOnScreen = false
    o.anchorRight = false
    o.anchorBottom = false
    o.moveWithMouse = false
    o.backgroundColor = { a = 0.0, r = 0.0, g = 0.0, b = 0.0 }
    o.borderColor = { a = 0.0, r = 0.0, g = 0.0, b = 0.0 }
    o.playerNum = 0
    o.target = nil
    o._nmClosePressed = false
    o._nmSettingsPressed = false
    o._nmPlayButtonPressed = false
    o._nmPrevButtonPressed = false
    o._nmNextButtonPressed = false
    o._nmLoopButtonPressed = false
    o._nmLidArrowPressed = false
    o.isCollapsed = false
    o.isAnimating = false
    o.animStartY = nil
    o.animTargetY = nil
    o.animStartTime = nil
    o.isPlayButtonDown = false
    o._nmHasObservedPlayState = false
    o._nmAuthoritativePlayDown = false
    o.isPlayButtonAnimating = false
    o.playButtonCurrentY = PLAY_BUTTON_UP_Y
    o.playButtonAnimStartY = nil
    o.playButtonAnimTargetY = nil
    o.playButtonAnimStartTime = nil
    o.isPrevButtonAnimating = false
    o.prevButtonPhase = nil
    o.prevButtonCurrentY = PREV_BUTTON_UP_Y
    o.prevButtonAnimStartY = nil
    o.prevButtonAnimTargetY = nil
    o.prevButtonAnimStartTime = nil
    o.isNextButtonAnimating = false
    o.nextButtonPhase = nil
    o.nextButtonCurrentY = NEXT_BUTTON_UP_Y
    o.nextButtonAnimStartY = nil
    o.nextButtonAnimTargetY = nil
    o.nextButtonAnimStartTime = nil
    o.isLoopButtonAnimating = false
    o.loopButtonPhase = nil
    o.loopButtonCurrentX = LOOP_BUTTON_UP_X
    o.loopButtonAnimStartX = nil
    o.loopButtonAnimTargetX = nil
    o.loopButtonAnimStartTime = nil
    o._nmLeftSpoolAngle = 0.0
    o._nmRightSpoolAngle = 0.0
    o._nmSpoolLastUpdateMs = nil
    o.isLidAnimating = false
    o.lidAnimStartY = nil
    o.lidAnimStartH = nil
    o.lidAnimTargetY = nil
    o.lidAnimTargetH = nil
    o.lidAnimStartTime = nil
    o.lidCurrentY = LID_OPEN_Y
    o.lidCurrentH = LID_OPEN_H
    o.isLidOpen = true
    o.isLidManuallyOpen = true
    o._nmLidHadMedia = false
    o._nmWheelDragging = false
    o._nmWheelStableVolume = 1.0
    o._nmWheelPreviewVolume = 1.0
    o._nmWheelPendingDispatchVolume = nil
    o._nmWheelLastDispatchMs = 0
    o._nmWheelLastDispatchedVolume = nil
    o._nmWheelLastClickPercent = nil
    o._nmWheelLastClickSoundMs = 0
    o._nmWheelLabelVisibleUntil = 0
    o._nmLoopIconVisibleUntil = 0
    o._nmWheelDragStartMouseY = nil
    o._nmWheelDragStartVolume = nil
    o._nmLastDistanceCheckMs = 0
    o.headerPressed = false
    o.headerPressStartedCollapsed = nil
    o.headerDragMode = nil
    o.draggingHeader = false
    o.headerPressX = nil
    o.headerPressY = nil
    o.dragStartWindowX = nil
    o.dragStartWindowY = nil
    o.interactionSuppressedToggle = false
    o._nmExpandedY = nil
    o._nmLastHeadphoneWearSyncMs = 0
    o._nmHeadphoneWearSyncActive = false
    o._nmFrameEpoch = 0
    o._nmFrameNowMs = 0
    o._nmUiPerfKind = "walkman"
    o._nmContextCache = nil
    o._nmContextCacheTargetKey = nil
    o._nmSlotFrameModel = nil
    o._nmSlotFrameModelEpoch = nil
    o._nmRenderModel = nil
    o._nmRenderModelEpoch = nil
    o._nmPendingMediaSlotFullType = nil
    o._nmPendingHeadphoneSlotFullType = nil
    o._nmPendingBatterySlotFullType = nil
    o._nmSlotRemoveInFlightByType = {}
    o._nmMediaEjectInterrupted = nil
    o._nmAwaitingAuthoritativeMediaEject = nil
    o._nmAwaitingAuthoritativeMediaInsert = nil
    o._nmSlotsAttached = false
    o._nmAppliedFancyScale = getFancyDeviceUiScale()
    if NMDeviceUiHost and NMDeviceUiHost.initWindow then
        NMDeviceUiHost.initWindow(o, "walkman")
    end
    return o
end

return NMWalkmanWindow
