local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

local UiLifecycleItemWindows = require "ui/shared/host/NMUiLifecycleItemWindows"

local function isFancyUIEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyUIEnabled then
        return NMRuntimeConfig.getFancyUIEnabled() == true
    end
    return true
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

local function ensureDisplaySongLabelPanel(window)
    if not window then
        return
    end
    local existing = window.displaySongLabelPanel
    if existing and existing.javaObject then
        return
    end

    local viewport = window.getDisplayViewportRect and window:getDisplayViewportRect() or nil
    if not viewport then
        return
    end

    local panel = ISPanel:new(viewport.x, viewport.y, viewport.w, viewport.h)
    panel:initialise()
    panel:instantiate()
    panel:noBackground()
    panel.backgroundColor = { a = 0.0, r = 0.0, g = 0.0, b = 0.0 }
    panel.borderColor = { a = 0.0, r = 0.0, g = 0.0, b = 0.0 }
    panel.ownerWindow = window

    panel.render = function(self)
        local owner = self.ownerWindow
        if not owner then
            return
        end
        local liveState = owner.getCDLiveRenderState and owner:getCDLiveRenderState() or nil
        local renderState = liveState and liveState.displaySongLabelState or nil
        if not renderState then
            return
        end
        local viewportRect = owner.getDisplayViewportRect and owner:getDisplayViewportRect() or nil
        local originX = viewportRect and tonumber(viewportRect.x) or 0
        local originY = viewportRect and tonumber(viewportRect.y) or 0
        local color = renderState.color or DISPLAY_TEXT_COLOR
        self:drawText(
            tostring(renderState.text or ""),
            (tonumber(renderState.x) or 0) - originX,
            (tonumber(renderState.y) or 0) - originY,
            color.r,
            color.g,
            color.b,
            color.a,
            UIFont.Small
        )
    end

    window:addChild(panel)
    window.displaySongLabelPanel = panel
end

local function ensureDisplayClockPanel(window)
    if not window then
        return
    end
    local existing = window.displayClockPanel
    if existing and existing.javaObject then
        return
    end

    local viewport = window.getDisplayViewportRect and window:getDisplayViewportRect() or nil
    if not viewport then
        return
    end

    local panel = ISPanel:new(viewport.x, viewport.y, viewport.w, viewport.h)
    panel:initialise()
    panel:instantiate()
    panel:noBackground()
    panel.backgroundColor = { a = 0.0, r = 0.0, g = 0.0, b = 0.0 }
    panel.borderColor = { a = 0.0, r = 0.0, g = 0.0, b = 0.0 }
    panel.ownerWindow = window

    panel.render = function(self)
        local owner = self.ownerWindow
        if not owner then
            return
        end
        local liveState = owner.getCDLiveRenderState and owner:getCDLiveRenderState() or nil
        local renderState = liveState and liveState.displayClockState or nil
        if not renderState then
            return
        end

        local viewportRect = owner.getDisplayViewportRect and owner:getDisplayViewportRect() or nil
        local originX = viewportRect and tonumber(viewportRect.x) or 0
        local originY = viewportRect and tonumber(viewportRect.y) or 0
        local color = renderState.color or DISPLAY_TEXT_COLOR
        self:drawText(
            tostring(renderState.text or ""),
            (tonumber(renderState.x) or 0) - originX,
            (tonumber(renderState.y) or 0) - originY,
            color.r,
            color.g,
            color.b,
            color.a,
            UIFont.Small
        )
    end

    window:addChild(panel)
    window.displayClockPanel = panel
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

local function collectPlayerWindows(playerNum)
    return WindowRegistry and WindowRegistry.collectWindows and WindowRegistry.collectWindows(env, playerNum) or {}
end

local function registerWindow(window)
    if WindowRegistry and WindowRegistry.registerWindow then
        WindowRegistry.registerWindow(env, window)
    end
end

local function logOpenTrace(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle")) then
        return
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "cdplayer_open"), tostring(detail or ""))
end

local function unregisterWindow(window)
    if WindowRegistry and WindowRegistry.unregisterWindow then
        WindowRegistry.unregisterWindow(env, window)
    end
end

-- Safety net for pre-registry or stale-key windows during UI/session transitions.
function getOrCreateWindow(playerNum)
    refreshCDPlayerLayoutMetrics()
    local screenW, screenH = getScreenSize()
    local x = math.max(0, screenW - PANEL_W - DEFAULT_RIGHT_MARGIN)
    local y = math.max(0, screenH - PANEL_H + EXPANDED_BOTTOM_OVERSHOOT - EXPANDED_BOTTOM_MARGIN)
    local win = CDPlayerWindow:new(x, y, PANEL_W, PANEL_H)
    win.playerNum = tonumber(playerNum) or 0
    win:initialise()
    ensureDisplaySongLabelPanel(win)
    ensureDisplayClockPanel(win)
    attachCDPlayerSlots(win)
    win:applyCurrentScaleLayout()
    win:addToUIManager()
    return win
end

function NMCDPlayerWindow.openForItemResolved(playerNum, item, resolvedContext)
    if not isFancyUIEnabled() then
        return nil
    end
    local player = getPlayer(playerNum)
    if not (player and item) then
        return nil
    end
    local resolved = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemLifecycleContext(item)
    local profile = resolved and resolved.profile or (NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil)
    if not profile or tostring(profile.deviceType or "") ~= "cdplayer" then
        return nil
    end
    local identity = resolved and resolved.itemId and resolved or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local itemUuid = identity.itemUuid ~= "" and identity.itemUuid or nil
    local targetKey = tostring(identity.targetKey or "")
    local win, lookup = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
    logOpenTrace(
        "cdplayer_open_lookup",
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
            "cdplayer_open_fallback",
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
    local screenW, screenH = getScreenSize()
    if currentX == nil then
        currentX = math.max(0, screenW - PANEL_W - DEFAULT_RIGHT_MARGIN)
    end
    if currentY == nil then
        currentY = math.max(0, screenH - PANEL_H + EXPANDED_BOTTOM_OVERSHOOT - EXPANDED_BOTTOM_MARGIN)
    end
    win:setX(win:clampWindowX(currentX))
    win._nmExpandedY = win:clampWindowY(currentY)
    win:snapToState(false)
    win.isLidOpen = false
    win.isLidAnimating = false
    win.lidAnimStartY = nil
    win.lidAnimStartH = nil
    win.lidAnimTargetY = nil
    win.lidAnimTargetH = nil
    win.lidAnimStartTime = nil
    win.lidCurrentY = LID_CLOSED_Y
    win.lidCurrentH = LID_CLOSED_H
    win:syncLidFromMedia(true)
    NMSlotHostLifecycle.refreshSlotVisibility(win)
    win.target = {
        kind = "item",
        itemId = NMCore and NMCore.itemId and NMCore.itemId(item) or nil,
        uuid = itemUuid,
        itemRef = item
    }
    win:invalidateContextCache()
    NMSlotHostLifecycle.refreshSlotVisibility(win)
    win:setVisible(true)
    win:bringToTop()
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(win, "cdplayer")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(win, "cdplayer")
    end
    registerWindow(win)
    logOpenTrace(
        "cdplayer_open_result",
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

function NMCDPlayerWindow.openForItem(playerNum, item)
    return NMCDPlayerWindow.openForItemResolved(playerNum, item, nil)
end

function NMCDPlayerWindow.findOpenForItemResolved(playerNum, item, resolvedContext)
    local identity = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local exact = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
    return exact
end

function NMCDPlayerWindow.findOpenForItem(playerNum, item)
    return NMCDPlayerWindow.findOpenForItemResolved(playerNum, item, nil)
end

function NMCDPlayerWindow.collectOpenMediaIngressZones(playerNum, dragItems)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local isCompatibleMediaDragFn = mediaEnv and mediaEnv.isCompatibleMediaDrag or nil
    local resolveMediaSlotFullTypeFn = mediaEnv and mediaEnv.resolveMediaSlotFullType or nil
    local queueDraggedMediaInsertFn = mediaEnv and mediaEnv.queueDraggedMediaInsert or nil
    local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
    if not (isCompatibleMediaDragFn and resolveMediaSlotFullTypeFn and queueDraggedMediaInsertFn and queueMediaSlotEjectFn) then
        return {}
    end

    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local resolved = win.resolveContextCached and win:resolveContextCached() or nil
            local state = resolved and resolved.state or nil
            local mediaSlotRect = win:shouldShowClosedLidSlots() == true and getWindowScreenRect(win, win:getMediaSlotRect()) or nil
            local mediaFullType = resolveMediaSlotFullTypeFn(win, state)
            if mediaSlotRect then
                local zone = NMSlotHostLifecycle.buildSharedMediaSlotZone({
            window = win,
            uiFamily = "cdplayer",
            zoneKind = "slot",
            rect = mediaSlotRect,
            priority = 10,
            zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
            dragItems = dragItems,
            canAcceptDraggedMedia = function(items)
                return win:shouldShowClosedLidSlots() == true
                    and type(items) == "table"
                    and #items > 0
                    and isCompatibleMediaDragFn(win, items)
                    and resolveMediaSlotFullTypeFn(win, state) == ""
            end,
            canEjectMedia = function()
                return mediaFullType ~= ""
            end,
            canStartExtractDrag = function()
                return mediaFullType ~= ""
            end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end

            if win.isLidOpen == true and win.isLidAnimating ~= true then
                local auxRect = getWindowScreenRect(win, win:getOpenLidAuxZoneRect())
                if auxRect then
                    local canAccept = type(dragItems) == "table"
                        and #dragItems > 0
                        and isCompatibleMediaDragFn(win, dragItems)
                        and mediaFullType == ""
                    zones[#zones + 1] = {
                        uiFamily = "cdplayer",
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
                        canAccept = canAccept == true,
                        containsPoint = function(mx, my)
                            local ax = win.getAbsoluteX and win:getAbsoluteX() or 0
                            local ay = win.getAbsoluteY and win:getAbsoluteY() or 0
                            return win:isOpenLidAuxZoneHit((tonumber(mx) or 0) - ax, (tonumber(my) or 0) - ay)
                        end,
                        canAcceptDraggedMedia = function(items)
                            return win.isLidOpen == true
                                and win.isLidAnimating ~= true
                                and type(items) == "table"
                                and #items > 0
                                and isCompatibleMediaDragFn(win, items)
                                and resolveMediaSlotFullTypeFn(win, state) == ""
                        end
                    }
                end
            end
        end
    end
    return zones
end

function NMCDPlayerWindow.collectOpenBatteryIngressZones(playerNum, dragItems)
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
            local rect = getWindowScreenRect(win, win:getBatterySlotRect())
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "cdplayer",
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

function NMCDPlayerWindow.collectOpenHeadphoneIngressZones(playerNum, dragItems)
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
            local rect = getWindowScreenRect(win, win:getHeadphoneSlotRect())
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "cdplayer",
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

function NMCDPlayerWindow.invalidateOpenItemWindow(itemId, uuid)
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
                    cause = "cdplayer_open_item_window_invalidate_deferred",
                }) == true
        end,
        invalidateWindow = function(win)
            win:invalidateContextCache()
        end,
    })
end

function NMCDPlayerWindow.rebindOpenPortableItemWindow(itemId, uuid)
    return UiLifecycleItemWindows.applyOpenItemWindowChange(env, itemId, uuid, {
        mode = "rebind",
        deferInvalidate = function(win)
            return NMSlotHostLifecycle.deferUiRefreshUntilDragEnd
                and NMSlotHostLifecycle.deferUiRefreshUntilDragEnd(win, {
                    cause = "cdplayer_open_item_window_rebind_deferred",
                }) == true
        end,
        invalidateWindow = function(win)
            win:invalidateContextCache()
        end,
    })
end

function NMCDPlayerWindow.inspectOpenItemWindowTarget(playerNum)
    return UiLifecycleItemWindows.inspectOpenItemWindowTarget(env, playerNum)
end

function NMCDPlayerWindow.closeOpenForItemTarget(playerNum, itemId, uuid)
    return UiLifecycleItemWindows.closeOpenForItemTarget(env, playerNum, itemId, uuid, {
        closeWindow = function(win)
            NMSlotHostLifecycle.cancelSharedSlotDrags(win)
            persistWindowState(win, false)
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

function CDPlayerWindow:close()
    NMSlotHostLifecycle.cancelSharedSlotDrags(self)
    persistWindowState(self, false)
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

function CDPlayerWindow:resolveSettingsGearTint(model)
    local variant = tostring(model and model.frontVariant or FRONT_TEXTURE_FALLBACK_VARIANT or "Cyan")
    if variant == "Cow" or variant == "Black" then
        return 1.0, 1.0, 1.0, 1.0
    end
    return CLOSE_TEXTURE_ALPHA, CLOSE_TEXTURE_TINT_R, CLOSE_TEXTURE_TINT_G, CLOSE_TEXTURE_TINT_B
end

function CDPlayerWindow:new(x, y, width, height)
    refreshCDPlayerLayoutMetrics()
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
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
    o._nmPressedButtonKind = nil
    o._nmButtonPulseUntilByKind = {}
    o._nmLastCDPlayerBeepSound = nil
    o._nmHoldButtonAngle = nil
    o._nmHoldButtonTargetAngle = nil
    o._nmHoldButtonAnimStartAngle = nil
    o._nmHoldButtonAnimStartTime = nil
    o._nmHoldButtonAnimating = false
    o._nmLidZonePressed = nil
    o.tooltip = nil
    o.tooltipUI = nil
    o._nmLastHeadphoneWearSyncMs = 0
    o._nmHeadphoneWearSyncActive = false
    o._nmFrameEpoch = 0
    o._nmFrameNowMs = 0
    o._nmUiPerfKind = "cdplayer"
    o.isCollapsed = false
    o.isAnimating = false
    o.animStartY = nil
    o.animTargetY = nil
    o.animStartTime = nil
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
    o._nmLastDistanceCheckMs = 0
    o._nmContextCache = nil
    o._nmContextCacheTargetKey = nil
    o._nmSlotFrameModel = nil
    o._nmSlotFrameModelEpoch = nil
    o._nmRenderModel = nil
    o._nmRenderModelEpoch = nil
    o._nmPendingMediaSlotFullType = nil
    o._nmPendingContextMediaInsert = nil
    o._nmCloseLidAfterContextInsert = false
    o._nmPendingHeadphoneSlotFullType = nil
    o._nmPendingBatterySlotFullType = nil
    o._nmSlotRemoveInFlightByType = {}
    o._nmAwaitingAuthoritativeMediaEject = nil
    o._nmAwaitingAuthoritativeMediaInsert = nil
    o._nmSlotsAttached = false
    o._nmSlotsVisible = false
    o.mediaSlot = nil
    o.headphoneSlot = nil
    o.batterySlot = nil
    o.cdplayerBatteryMeter = nil
    o.isLidAnimating = false
    o.lidAnimStartY = nil
    o.lidAnimStartH = nil
    o.lidAnimTargetY = nil
    o.lidAnimTargetH = nil
    o.lidAnimStartTime = nil
    o.lidCurrentY = LID_CLOSED_Y
    o.lidCurrentH = LID_CLOSED_H
    o.isLidOpen = false
    o._nmAppliedFancyScale = getFancyDeviceUiScale()
    if NMDeviceUiHost and NMDeviceUiHost.initWindow then
        NMDeviceUiHost.initWindow(o, "cdplayer")
    end
    return o
end

return NMCDPlayerWindow
