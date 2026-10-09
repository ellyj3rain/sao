-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local UiLifecycleItemWindows = require "ui/shared/host/NMUiLifecycleItemWindows"
require "ui/shared/NMReadoutTextResolver"

local function isFancyUIEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyUIEnabled then
        return NMRuntimeConfig.getFancyUIEnabled() == true
    end
    return true
end

local function getWindowScreenRect(window, rect)
    if not (window and rect) then return nil end
    local ax = window.getAbsoluteX and window:getAbsoluteX() or nil
    local ay = window.getAbsoluteY and window:getAbsoluteY() or nil
    if ax == nil or ay == nil then return nil end
    return { x = ax + (tonumber(rect.x) or 0), y = ay + (tonumber(rect.y) or 0), w = tonumber(rect.w) or 0, h = tonumber(rect.h) or 0 }
end

local function isWindowVisible(window)
    if not (window and window.javaObject) then return false end
    if window.getIsVisible then return window:getIsVisible() == true end
    if window.isVisible then return window:isVisible() == true end
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

local function resolveLabelText(state)
    if NMReadoutTextResolver and NMReadoutTextResolver.resolveReadoutText then
        return tostring(NMReadoutTextResolver.resolveReadoutText(state) or "")
    end
    return ""
end

local function buildWindowInspectionSnapshot(win)
    if not (win and win.target and win.target.kind == "item") then
        return nil
    end
    local resolved = win.resolveContextCached and win:resolveContextCached() or nil
    local state = resolved and resolved.state or nil
    local localState = resolved and resolved.localState or state
    return {
        playerNum = tonumber(win.playerNum) or 0,
        itemId = tostring(win.target.itemId or ""),
        uuid = tostring(win.target.uuid or ""),
        hasItemRef = win.target.itemRef ~= nil,
        mediaTimedAction = tostring(win._nmMediaSlotTimedProgress and win._nmMediaSlotTimedProgress.action or ""),
        pendingMediaFullType = tostring(win._nmPendingMediaSlotFullType or ""),
        awaitingMediaInsert = win.isAwaitingAuthoritativeMediaInsert and win:isAwaitingAuthoritativeMediaInsert() == true or false,
        awaitingMediaEject = win.isAwaitingAuthoritativeMediaEject and win:isAwaitingAuthoritativeMediaEject() == true or false,
        uiFamily = "boombox",
        displayTrackIndex = tonumber(state and state.trackIndex) or 0,
        displayLabelText = resolveLabelText(state),
        resolvedTrackIndex = tonumber(state and state.trackIndex) or 0,
        resolvedLabelText = resolveLabelText(state),
        localTrackIndex = tonumber(localState and localState.trackIndex) or 0,
        localLabelText = resolveLabelText(localState),
        playbackEpoch = tonumber(state and state.playbackEpoch) or 0,
        contextRevision = tonumber(win._nmContextRevision) or 0,
        renderRevision = tonumber(win._nmRenderRevision) or 0,
        contextCacheReused = win._nmContextCache ~= nil
    }
end

local function getOrCreateWindow(playerNum)
    refreshBoomboxLayoutMetrics()
    local screenW, screenH = getScreenSize()
    local x = math.max(0, screenW - PANEL_W - DEFAULT_RIGHT_MARGIN)
    local y = math.max(0, screenH - PANEL_H - EXPANDED_BOTTOM_MARGIN)
    local win = BoomboxWindow:new(x, y, PANEL_W, PANEL_H)
    win.playerNum = tonumber(playerNum) or 0
    win:initialise()
    attachBoomboxSlots(win)
    win:applyCurrentScaleLayout()
    win:addToUIManager()
    return win
end

function NMBoomboxWindow.openForItemResolved(playerNum, item, resolvedContext)
    if not isFancyUIEnabled() then
        return nil
    end
    local player = getPlayer(playerNum)
    if not (player and item) then
        return nil
    end
    local resolved = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemLifecycleContext(item)
    local profile = resolved and resolved.profile or (NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil)
    if not profile or tostring(profile.deviceType or "") ~= "boombox" then
        return nil
    end
    local identity = resolved and resolved.itemId and resolved or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local itemUuid = identity.itemUuid ~= "" and identity.itemUuid or nil
    local win = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
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
    win.target = { kind = "item", itemId = NMCore and NMCore.itemId and NMCore.itemId(item) or nil, uuid = itemUuid, itemRef = item }
    win:invalidateContextCache()
    win:invalidateSlotFrameModel()
    win._nmPendingMediaSlotFullType = nil
    win._nmPendingHeadphoneSlotFullType = nil
    win._nmPendingBatterySlotFullType = nil
    win._nmSlotRemoveInFlightByType = {}
    win._nmAwaitingAuthoritativeMediaEject = nil
    win._nmAwaitingAuthoritativeMediaInsert = nil
    win.isLidManuallyOpen = true
    win._nmHasObservedPlayState = false
    win._nmAuthoritativePlayDown = false
    win._nmLocalPlayPresentationLatched = false
    win._nmMainButtonDownByKind.play = false
    win._nmTopButtonDownByKind.play = false
    win._nmHasObservedPowerState = false
    win._nmPowerSwitchOn = false
    win._nmPowerSwitchPendingOn = nil
    win._nmPowerSwitchPendingUntilMs = 0
    win:syncVolumeKnobFromState(true)
    win:syncPlayButtonFromTransport(nil, true)
    win:syncPowerSwitchFromTransport(nil, true)
    win:syncLidFromMedia(true)
    win:setVisible(true)
    win:bringToTop()
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(win, "boombox")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(win, "boombox")
    end
    registerWindow(win)
    persistWindowState(win, true)
    return win
end

function NMBoomboxWindow.openForItem(playerNum, item)
    return NMBoomboxWindow.openForItemResolved(playerNum, item, nil)
end

function NMBoomboxWindow.findOpenForItemResolved(playerNum, item, resolvedContext)
    local identity = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    return UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
end

function NMBoomboxWindow.findOpenForItem(playerNum, item)
    return NMBoomboxWindow.findOpenForItemResolved(playerNum, item, nil)
end

function NMBoomboxWindow.collectOpenMediaIngressZones(playerNum, dragItems)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local resolveMediaSlotFullTypeFn = mediaEnv and mediaEnv.resolveMediaSlotFullType or nil
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local mediaRect = getWindowScreenRect(win, win:getSlotRect(1))
            if mediaRect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local mediaFullType = resolveMediaSlotFullTypeFn and tostring(resolveMediaSlotFullTypeFn(win, state) or "") or tostring((state and state.mediaFullType) or "")
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "boombox",
                    zoneKind = "media",
                    rect = mediaRect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table" and #items > 0 and isCompatibleBoomboxMediaDrag(win, items)
                            and mediaFullType == ""
                    end,
                    canEjectMedia = function()
                        return mediaFullType ~= ""
                    end,
                    canStartExtractDrag = function()
                        return mediaFullType ~= ""
                    end
                })
                if zone then zones[#zones + 1] = zone end
            end
            local auxRect = win.isLidTargetOpen and win:isLidTargetOpen() == true and getWindowScreenRect(win, win:getLidIngressZoneRect()) or nil
            if auxRect then
                zones[#zones + 1] = {
                    uiFamily = "boombox",
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
                        return win.canAcceptDraggedMediaViaLid and win:canAcceptDraggedMediaViaLid() == true and type(items) == "table" and #items > 0
                    end
                }
            end
        end
    end
    return zones
end

function NMBoomboxWindow.collectOpenBatteryIngressZones(playerNum, dragItems)
    local batteryEnv = rawget(_G, "NMBatterySlotEnv") or nil
    local resolveBatterySlotFullTypeFn = batteryEnv and batteryEnv.resolveBatterySlotFullType or nil
    local isCompatibleBatteryDragFn = batteryEnv and batteryEnv.isCompatibleBatteryDrag or nil
    if not (resolveBatterySlotFullTypeFn and isCompatibleBatteryDragFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local rect = getWindowScreenRect(win, win:getSlotRect(2))
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "boombox",
                    zoneKind = "battery",
                    rect = rect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table" and #items > 0 and isCompatibleBatteryDragFn(items) and resolveBatterySlotFullTypeFn(win, state) == ""
                    end,
                    canEjectMedia = function()
                        return resolveBatterySlotFullTypeFn(win, state) ~= ""
                    end,
                    canStartExtractDrag = function()
                        return resolveBatterySlotFullTypeFn(win, state) ~= ""
                    end
                })
                if zone then zones[#zones + 1] = zone end
            end
        end
    end
    return zones
end

function NMBoomboxWindow.collectOpenHeadphoneIngressZones(playerNum, dragItems)
    local headphoneEnv = rawget(_G, "NMHeadphoneSlotEnv") or nil
    local resolveHeadphoneSlotFullTypeFn = headphoneEnv and headphoneEnv.resolveHeadphoneSlotFullType or nil
    local isCompatibleHeadphoneDragFn = headphoneEnv and headphoneEnv.isCompatibleHeadphoneDrag or nil
    if not (resolveHeadphoneSlotFullTypeFn and isCompatibleHeadphoneDragFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and win.target and win.target.kind == "item" then
            local rect = getWindowScreenRect(win, win:getSlotRect(3))
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "boombox",
                    zoneKind = "headphones",
                    rect = rect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table" and #items > 0 and isCompatibleHeadphoneDragFn(win, items, resolved, state) and resolveHeadphoneSlotFullTypeFn(win, state) == ""
                    end,
                    canEjectMedia = function()
                        return resolveHeadphoneSlotFullTypeFn(win, state) ~= ""
                    end,
                    canStartExtractDrag = function()
                        return resolveHeadphoneSlotFullTypeFn(win, state) ~= ""
                    end
                })
                if zone then zones[#zones + 1] = zone end
            end
        end
    end
    return zones
end

function NMBoomboxWindow.invalidateOpenItemWindow(itemId, uuid)
    return UiLifecycleItemWindows.applyOpenItemWindowChange(env, itemId, uuid, {
        mode = "invalidate",
        resolveWindowUuid = function(win)
            local resolved = win.resolveContextFresh and win:resolveContextFresh() or (win.resolveContext and win:resolveContext()) or nil
            local state = resolved and resolved.state or nil
            return tostring(state and state.deviceUUID or "")
        end,
        deferInvalidate = function(win)
            return NMSlotHostLifecycle.deferUiRefreshUntilDragEnd and NMSlotHostLifecycle.deferUiRefreshUntilDragEnd(win, { cause = "boombox_open_item_window_invalidate_deferred" }) == true
        end,
        invalidateWindow = function(win)
            win:invalidateContextCache()
            win:invalidateSlotFrameModel()
            if win.invalidateRenderModel then
                win:invalidateRenderModel()
            end
        end
    })
end

function NMBoomboxWindow.rebindOpenPortableItemWindow(itemId, uuid)
    return UiLifecycleItemWindows.applyOpenItemWindowChange(env, itemId, uuid, {
        mode = "rebind",
        deferInvalidate = function(win)
            return NMSlotHostLifecycle.deferUiRefreshUntilDragEnd and NMSlotHostLifecycle.deferUiRefreshUntilDragEnd(win, { cause = "boombox_open_item_window_rebind_deferred" }) == true
        end,
        invalidateWindow = function(win)
            win:invalidateContextCache()
            win:invalidateSlotFrameModel()
            if win.invalidateRenderModel then
                win:invalidateRenderModel()
            end
        end
    })
end

function NMBoomboxWindow.inspectOpenItemWindowTarget(playerNum)
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local snap = buildWindowInspectionSnapshot(wins[i])
        if snap then
            return snap
        end
    end
    return UiLifecycleItemWindows.inspectOpenItemWindowTarget(env, playerNum)
end

function NMBoomboxWindow.closeOpenForItemTarget(playerNum, itemId, uuid)
    return UiLifecycleItemWindows.closeOpenForItemTarget(env, playerNum, itemId, uuid, {
        closeWindow = function(win)
            NMSlotHostLifecycle.cancelSharedSlotDrags(win)
            persistWindowState(win, false)
            if win.setVisible then win:setVisible(false) end
            if win.removeFromUIManager then win:removeFromUIManager() end
            unregisterWindow(win)
        end
    })
end

function BoomboxWindow:close()
    NMSlotHostLifecycle.cancelSharedSlotDrags(self)
    persistWindowState(self, false)
    if self.tooltipUI then
        self.tooltipUI:setVisible(false)
        if self.tooltipUI.removeFromUIManager then
            self.tooltipUI:removeFromUIManager()
        end
    end
    if self.setVisible then self:setVisible(false) end
    if self.removeFromUIManager then self:removeFromUIManager() end
    if NMGamepadWindowTracker and NMGamepadWindowTracker.unregisterWindow then
        NMGamepadWindowTracker.unregisterWindow(self)
    end
    unregisterWindow(self)
end

function BoomboxWindow:resolveSettingsGearTint(model)
    local variant = tostring(model and model.variant or "")
    if variant == "Oddbolt" or variant == "Black" then
        return 1.0, 1.0, 1.0, 1.0
    end
    return 1.0, CLOSE_TINT.r, CLOSE_TINT.g, CLOSE_TINT.b
end

function BoomboxWindow:new(x, y, width, height)
    refreshBoomboxLayoutMetrics()
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
    o._nmUiPerfKind = "boombox"
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
    o._nmFrameEpoch = 0
    o._nmFrameNowMs = 0
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
    o._nmAwaitingAuthoritativeMediaEject = nil
    o._nmAwaitingAuthoritativeMediaInsert = nil
    o._nmSlotsAttached = false
    o._nmClosePressed = false
    o._nmSettingsPressed = false
    o._nmPressedMainButtonKind = nil
    o._nmPressedTopButtonKind = nil
    o._nmPressedModeIndex = nil
    o._nmLidArrowPressed = false
    o._nmMainButtonDownByKind = { play = false }
    o._nmMainButtonPulseByKind = {}
    o._nmTopButtonDownByKind = { play = false }
    o._nmLocalPlayPresentationLatched = false
    o._nmTopButtonCurrentOffsetByKind = { play = TOP_BUTTON_RETRACT_Y, stop = TOP_BUTTON_RETRACT_Y, prev = TOP_BUTTON_RETRACT_Y, next = TOP_BUTTON_RETRACT_Y }
    o._nmTopButtonPressOffsetByKind = { play = 0, stop = 0, prev = 0, next = 0 }
    o._nmTopButtonReleaseSoundOnReturnByKind = { play = false, stop = true, prev = true, next = true }
    o._nmTopButtonsVisible = false
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
    o._nmKnobDragging = false
    o._nmKnobStableVolume = 1.0
    o._nmKnobPreviewVolume = 1.0
    o._nmKnobPendingDispatchVolume = nil
    o._nmKnobLastDispatchMs = 0
    o._nmKnobLastClickPercent = nil
    o._nmKnobLastClickSoundMs = 0
    o._nmKnobLabelVisibleUntil = 0
    o._nmKnobDragStartMouseX = nil
    o._nmKnobDragStartMouseY = nil
    o._nmKnobDragStartVolume = nil
    o._nmHasObservedPowerState = false
    o._nmPowerSwitchOn = false
    o._nmPowerSwitchPendingOn = nil
    o._nmPowerSwitchPendingUntilMs = 0
    o._nmAppliedFancyScale = getFancyDeviceUiScale()
    if NMDeviceUiHost and NMDeviceUiHost.initWindow then
        NMDeviceUiHost.initWindow(o, "boombox")
    end
    return o
end

return NMBoomboxWindow
