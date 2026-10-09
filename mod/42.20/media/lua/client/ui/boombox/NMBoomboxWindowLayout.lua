-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local MAIN_BUTTON_ORDER = { "play", "stop", "prev", "next", "eject" }
local TOP_BUTTON_ORDER = { "play", "stop", "prev", "next" }

local function buildTopCollapsedButtonRect(kind, y, h)
    local idx = math.max(1, 1)
    for i = 1, #TOP_BUTTON_ORDER do
        if TOP_BUTTON_ORDER[i] == kind then
            idx = i
            break
        end
    end
    return {
        x = TOP_BUTTON_X + ((idx - 1) * (TOP_BUTTON_W + TOP_BUTTON_GAP_X)),
        y = tonumber(y) or 0,
        w = TOP_BUTTON_W,
        h = tonumber(h) or TOP_BUTTON_H,
    }
end

local function getCollapsedTopButtonInsetY()
    local desiredPeek = tonumber(TOP_BUTTON_PEEK_EXPOSE) or 0
    local shellTopY = tonumber(BASE_Y) or 0
    return math.max(0, desiredPeek - shellTopY)
end

local function getCollapsedCanvasOffsetY(window, forceCollapsed)
    if forceCollapsed == true or (window and window.isCollapsed == true) then
        return getCollapsedTopButtonInsetY()
    end
    return 0
end

function BoomboxWindow:getCanvasOffsetY(forceCollapsed)
    return getCollapsedCanvasOffsetY(self, forceCollapsed)
end

function BoomboxWindow:getHeaderRect(forceCollapsed)
    local offsetY = getCollapsedCanvasOffsetY(self, forceCollapsed)
    return { x = HEADER_X, y = HEADER_Y + offsetY, w = HEADER_W, h = HEADER_H }
end

function BoomboxWindow:getHeaderLeftStripRect(forceCollapsed)
    local offsetY = getCollapsedCanvasOffsetY(self, forceCollapsed)
    return {
        x = BASE_X,
        y = HEADER_Y + offsetY,
        w = HEADER_SIDE_STRIP_W,
        h = math.max(0, ((BASE_Y + BASE_H) + offsetY) - (HEADER_Y + offsetY))
    }
end

function BoomboxWindow:getHeaderRightStripRect(forceCollapsed)
    local offsetY = getCollapsedCanvasOffsetY(self, forceCollapsed)
    return {
        x = (BASE_X + BASE_W) - HEADER_SIDE_STRIP_W,
        y = HEADER_Y + offsetY,
        w = HEADER_SIDE_STRIP_W,
        h = math.max(0, ((BASE_Y + BASE_H) + offsetY) - (HEADER_Y + offsetY))
    }
end

function BoomboxWindow:getCloseRect(forceCollapsed)
    local offsetY = getCollapsedCanvasOffsetY(self, forceCollapsed)
    return { x = CLOSE_X, y = CLOSE_Y + offsetY, w = CLOSE_W, h = CLOSE_H }
end

function BoomboxWindow:getSettingsRect(forceCollapsed)
    local closeRect = self:getCloseRect(forceCollapsed)
    return {
        x = closeRect.x,
        y = closeRect.y + closeRect.h + SETTINGS_GAP_Y,
        w = closeRect.w,
        h = closeRect.h
    }
end

function BoomboxWindow:getPowerSwitchBgRect(forceCollapsed)
    local offsetY = getCollapsedCanvasOffsetY(self, forceCollapsed)
    return { x = POWER_BG_X, y = POWER_BG_Y + offsetY, w = POWER_BG_W, h = POWER_BG_H }
end

function BoomboxWindow:getPowerSwitchSlideRect(isOn, forceCollapsed)
    local offsetY = getCollapsedCanvasOffsetY(self, forceCollapsed)
    local slideY = POWER_BG_Y + offsetY + POWER_SLIDE_OFFSET_Y - ((isOn == true) and POWER_SLIDE_TRAVEL_Y or 0)
    return {
        x = POWER_BG_X + POWER_SLIDE_OFFSET_X,
        y = slideY,
        w = POWER_SLIDE_W,
        h = POWER_SLIDE_H,
    }
end

function BoomboxWindow:getCollapsedVisibleHeight()
    local baseVisibleHeight = 30
    local closeRect = self:getCloseRect(true)
    local settingsRect = self:getSettingsRect(true)
    local chromeBottom = math.max(
        closeRect.y + closeRect.h,
        settingsRect.y + settingsRect.h
    )
    return math.max(baseVisibleHeight, chromeBottom)
end

function BoomboxWindow:getDefaultExpandedY()
    local _, screenH = getScreenSize()
    return math.max(0, screenH - EXPANDED_BOTTOM_MARGIN - self.height)
end

function BoomboxWindow:isHeaderHit(x, y)
    return pointInRect(x, y, self:getHeaderRect())
        or pointInRect(x, y, self:getHeaderLeftStripRect())
        or pointInRect(x, y, self:getHeaderRightStripRect())
end

function BoomboxWindow:clampWindowY(value)
    local _, screenH = getScreenSize()
    local maxY = math.max(0, screenH - self.height)
    return math.max(0, math.min(math.floor((tonumber(value) or 0) + 0.5), maxY))
end

function BoomboxWindow:getExpandedY()
    local stored = tonumber(self._nmExpandedY)
    if stored == nil then
        stored = self:getDefaultExpandedY()
    end
    return self:clampWindowY(stored)
end

function BoomboxWindow:getCollapsedY()
    local _, screenH = getScreenSize()
    return math.max(0, screenH - self:getCollapsedVisibleHeight())
end

function BoomboxWindow:getStateY(collapsed)
    return collapsed == true and self:getCollapsedY() or self:getExpandedY()
end

function BoomboxWindow:clampWindowX(value)
    local screenW = getScreenSize()
    local maxX = math.max(0, screenW - self.width)
    return math.max(0, math.min(math.floor((tonumber(value) or 0) + 0.5), maxX))
end

function BoomboxWindow:snapToState(collapsed)
    NMFancyWindowChrome.snapToState(self, collapsed, persistWindowState)
end

function BoomboxWindow:startCollapseAnimation(collapsed)
    NMFancyWindowChrome.startCollapseAnimation(self, collapsed, persistWindowState)
end

function BoomboxWindow:toggleCollapsed()
    NMFancyWindowChrome.toggleCollapsed(self, persistWindowState)
end

function BoomboxWindow:finishHeaderInteraction()
    NMFancyWindowChrome.finishHeaderInteraction(self)
end

function BoomboxWindow:updateHeaderDrag()
    return NMFancyWindowChrome.updateHeaderDrag(self, DRAG_THRESHOLD_X, persistWindowState)
end

function BoomboxWindow:getSlotRect(index)
    local idx = math.max(1, math.floor(tonumber(index) or 1))
    return { x = SLOT_X + ((idx - 1) * (SLOT_SIZE + SLOT_GAP_X)), y = SLOT_Y, w = SLOT_SIZE, h = SLOT_SIZE }
end

function BoomboxWindow:getVolumeBgRect()
    return { x = VOLUME_BG_X, y = VOLUME_BG_Y, w = VOLUME_BG_W, h = VOLUME_BG_H }
end

function BoomboxWindow:getVolumeKnobRect()
    return { x = VOLUME_KNOB_X, y = VOLUME_KNOB_Y, w = VOLUME_KNOB_W, h = VOLUME_KNOB_H }
end

function BoomboxWindow:getVolumeLabelText()
    local volume = self._nmKnobDragging == true and self._nmKnobPreviewVolume or self._nmKnobStableVolume
    return string.format("%d%%", volumeToPercent(volume or 1.0))
end

function BoomboxWindow:getVolumeLabelRect()
    local knobRect = self:getVolumeBgRect()
    local text = self:getVolumeLabelText()
    local tm = getTextManager and getTextManager() or nil
    local textW = tm and tm.MeasureStringX and tm:MeasureStringX(UIFont.Small, text) or (#text * 6)
    local textH = tm and tm.MeasureStringY and tm:MeasureStringY(UIFont.Small, "Ag") or 10
    return {
        x = knobRect.x + math.floor(((knobRect.w - textW) * 0.5) + 0.5),
        y = knobRect.y - textH - VOLUME_LABEL_GAP_Y,
        w = textW,
        h = textH
    }
end

function BoomboxWindow:getVolumeKnobAngle(volume)
    local pct = clamp01(volume or 0.0)
    local startAngle = tonumber(VOLUME_MIN_ANGLE) or 76
    local endAngle = tonumber(VOLUME_MAX_ANGLE) or 10
    if endAngle <= startAngle then
        endAngle = endAngle + 360
    end
    local angle = startAngle + ((endAngle - startAngle) * pct)
    if angle >= 360 then
        angle = angle - 360
    end
    return angle
end

function BoomboxWindow:getMainButtonIndex(kind)
    for i = 1, #MAIN_BUTTON_ORDER do
        if MAIN_BUTTON_ORDER[i] == kind then
            return i
        end
    end
    return 1
end

function BoomboxWindow:getTopButtonIndex(kind)
    for i = 1, #TOP_BUTTON_ORDER do
        if TOP_BUTTON_ORDER[i] == kind then
            return i
        end
    end
    return 1
end

function BoomboxWindow:getTopCollapsedButtonAnchorY()
    local desiredPeek = tonumber(TOP_BUTTON_PEEK_EXPOSE) or 0
    local popOffset = tonumber(TOP_BUTTON_POP_Y) or 0
    return (tonumber(BASE_Y) or 0) - desiredPeek - popOffset
end

function BoomboxWindow:getTopCollapsedButtonVisualOffset(kind)
    local currentOffset = tonumber(self._nmTopButtonCurrentOffsetByKind and self._nmTopButtonCurrentOffsetByKind[kind]) or TOP_BUTTON_RETRACT_Y
    local pressOffset = tonumber(self._nmTopButtonPressOffsetByKind and self._nmTopButtonPressOffsetByKind[kind]) or 0
    return currentOffset + pressOffset
end

function BoomboxWindow:getMainButtonRect(kind)
    local idx = self:getMainButtonIndex(kind)
    return {
        x = MAIN_BUTTON_X + ((idx - 1) * (MAIN_BUTTON_W + MAIN_BUTTON_GAP_X)),
        y = MAIN_BUTTON_Y,
        w = MAIN_BUTTON_W,
        h = MAIN_BUTTON_H
    }
end

function BoomboxWindow:getTopCollapsedButtonVisualRect(kind)
    local anchorY = self:getTopCollapsedButtonAnchorY()
    local visualOffset = self:getTopCollapsedButtonVisualOffset(kind)
    return buildTopCollapsedButtonRect(kind, anchorY + visualOffset + getCollapsedCanvasOffsetY(self), TOP_BUTTON_H)
end

function BoomboxWindow:getTopCollapsedButtonHitRect(kind)
    local visualRect = self:getTopCollapsedButtonVisualRect(kind)
    local hitTopY = math.max(0, math.floor((tonumber(visualRect.y) or 0) + 0.5))
    local hitBottomY = math.ceil((tonumber(visualRect.y) or 0) + (tonumber(visualRect.h) or 0))
    local minHitHeight = tonumber(TOP_BUTTON_MIN_HIT_H) or 0
    hitBottomY = math.max(hitBottomY, hitTopY + minHitHeight)
    hitBottomY = math.min(math.floor(tonumber(self.height) or 0), hitBottomY)
    local hitHeight = math.max(1, hitBottomY - hitTopY)
    return buildTopCollapsedButtonRect(kind, hitTopY, hitHeight)
end

function BoomboxWindow:getTopCollapsedButtonRect(kind)
    return self:getTopCollapsedButtonVisualRect(kind)
end

function BoomboxWindow:getModeButtonRect(index)
    local idx = math.max(1, math.min(3, math.floor(tonumber(index) or 1)))
    return { x = MODE_X, y = MODE_Y + ((idx - 1) * (MODE_H + MODE_GAP_Y)), w = MODE_W, h = MODE_H }
end

function BoomboxWindow:getCassetteDisplayRect()
    return { x = CASSETTE_X, y = CASSETTE_Y, w = CASSETTE_W, h = CASSETTE_H }
end

function BoomboxWindow:getCassetteLabelRect()
    return { x = CASSETTE_LABEL_X, y = CASSETTE_LABEL_Y, w = CASSETTE_LABEL_W, h = CASSETTE_LABEL_H }
end

function BoomboxWindow:getCassetteSpoolRect(index, timedState)
    local state = timedState or self:getTimedCassetteAnimationState()
    local cassetteX = tonumber(state and state.x) or CASSETTE_X
    local cassetteY = tonumber(state and state.y) or CASSETTE_Y
    if math.floor(tonumber(index) or 1) == 2 then
        return { x = cassetteX + (CASSETTE_SPOOL_B_X - CASSETTE_X), y = cassetteY + (CASSETTE_SPOOL_B_Y - CASSETTE_Y), w = CASSETTE_SPOOL_W, h = CASSETTE_SPOOL_H }
    end
    return { x = cassetteX + (CASSETTE_SPOOL_A_X - CASSETTE_X), y = cassetteY + (CASSETTE_SPOOL_A_Y - CASSETTE_Y), w = CASSETTE_SPOOL_W, h = CASSETTE_SPOOL_H }
end
