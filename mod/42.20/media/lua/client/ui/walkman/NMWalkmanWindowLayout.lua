-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

function WalkmanWindow:getHeaderRect()
    return {
        x = HEADER_X,
        y = HEADER_Y,
        w = HEADER_W,
        h = HEADER_H
    }
end

function WalkmanWindow:getShellRect()
    return {
        x = 0,
        y = 0,
        w = self.width,
        h = self.height
    }
end

function WalkmanWindow:getBackgroundRect()
    return {
        x = BG_X,
        y = BG_Y,
        w = BG_W,
        h = BG_H
    }
end

function WalkmanWindow:getCloseRect()
    local headerRect = self:getHeaderRect()
    return {
        x = headerRect.x + CLOSE_INSET_X,
        y = headerRect.y + CLOSE_INSET_Y,
        w = CLOSE_W,
        h = CLOSE_H
    }
end

function WalkmanWindow:getSettingsRect()
    local closeRect = self:getCloseRect()
    return {
        x = closeRect.x,
        y = closeRect.y + closeRect.h + SETTINGS_GAP_Y - 3,
        w = closeRect.w,
        h = closeRect.h
    }
end

function WalkmanWindow:getPlayButtonY(down)
    if down == true then
        return PLAY_BUTTON_DOWN_Y
    end
    return PLAY_BUTTON_UP_Y
end

function WalkmanWindow:getPlayButtonRect()
    return {
        x = PLAY_BUTTON_X,
        y = tonumber(self.playButtonCurrentY) or self:getPlayButtonY(self.isPlayButtonDown),
        w = PLAY_BUTTON_W,
        h = PLAY_BUTTON_H
    }
end

function WalkmanWindow:getPlayButtonHitRect()
    return {
        x = PLAY_BUTTON_HIT_X,
        y = PLAY_BUTTON_HIT_Y,
        w = PLAY_BUTTON_HIT_W,
        h = PLAY_BUTTON_HIT_H
    }
end

function WalkmanWindow:getPrevButtonY(down)
    if down == true then
        return PREV_BUTTON_DOWN_Y
    end
    return PREV_BUTTON_UP_Y
end

function WalkmanWindow:getPrevButtonRect()
    return {
        x = PREV_BUTTON_X,
        y = tonumber(self.prevButtonCurrentY) or self:getPrevButtonY(false),
        w = PREV_BUTTON_W,
        h = PREV_BUTTON_H
    }
end

function WalkmanWindow:getPrevButtonHitRect()
    return {
        x = PREV_BUTTON_HIT_X,
        y = PREV_BUTTON_HIT_Y,
        w = PREV_BUTTON_HIT_W,
        h = PREV_BUTTON_HIT_H
    }
end

function WalkmanWindow:getNextButtonY(down)
    if down == true then
        return NEXT_BUTTON_DOWN_Y
    end
    return NEXT_BUTTON_UP_Y
end

function WalkmanWindow:getNextButtonRect()
    return {
        x = NEXT_BUTTON_X,
        y = tonumber(self.nextButtonCurrentY) or self:getNextButtonY(false),
        w = NEXT_BUTTON_W,
        h = NEXT_BUTTON_H
    }
end

function WalkmanWindow:getNextButtonHitRect()
    return {
        x = NEXT_BUTTON_HIT_X,
        y = NEXT_BUTTON_HIT_Y,
        w = NEXT_BUTTON_HIT_W,
        h = NEXT_BUTTON_HIT_H
    }
end

function WalkmanWindow:getStopButtonRect()
    return {
        x = STOP_BUTTON_X,
        y = STOP_BUTTON_Y,
        w = STOP_BUTTON_W,
        h = STOP_BUTTON_H
    }
end

function WalkmanWindow:getVolumeWheelRect()
    return {
        x = VOLUME_WHEEL_X,
        y = VOLUME_WHEEL_Y,
        w = VOLUME_WHEEL_W,
        h = VOLUME_WHEEL_H
    }
end

function WalkmanWindow:getVolumeWheelHitRect()
    return {
        x = VOLUME_WHEEL_HIT_X,
        y = VOLUME_WHEEL_Y,
        w = VOLUME_WHEEL_HIT_W,
        h = VOLUME_WHEEL_HIT_H
    }
end

function WalkmanWindow:getVolumeWheelAngle(volume)
    local pct = clamp01(volume)
    return VOLUME_WHEEL_MIN_ANGLE + ((VOLUME_WHEEL_MAX_ANGLE - VOLUME_WHEEL_MIN_ANGLE) * pct)
end

function WalkmanWindow:getVolumeLabelText()
    local volume = self._nmWheelDragging == true and self._nmWheelPreviewVolume or self._nmWheelStableVolume
    local text = string.format("%d%%", volumeToPercent(volume))
    if not self._nmVolumeLabelCache or tostring(self._nmVolumeLabelCache.text or "") ~= text then
        self._nmVolumeLabelCache = {
            text = text
        }
    end
    return self._nmVolumeLabelCache.text
end

function WalkmanWindow:getVolumeLabelRect()
    local wheelRect = self:getVolumeWheelRect()
    local text = self:getVolumeLabelText()
    local cache = self._nmVolumeLabelCache or {}
    local textW = tonumber(cache.width) or nil
    local textH = tonumber(cache.height) or nil
    if not textW or not textH or tostring(cache.text or "") ~= text then
        local tm = getTextManager and getTextManager() or nil
        textW = tm and tm.MeasureStringX and tm:MeasureStringX(UIFont.Small, text) or (#text * 6)
        textH = tm and tm.MeasureStringY and tm:MeasureStringY(UIFont.Small, "Ag") or 10
        cache.text = text
        cache.width = textW
        cache.height = textH
        self._nmVolumeLabelCache = cache
    end
    local rightX = wheelRect.x - VOLUME_LABEL_GAP_X
    local y = wheelRect.y + math.floor(((wheelRect.h - textH) * 0.5) + 0.5)
    return {
        x = rightX - textW,
        y = y,
        w = textW,
        h = textH
    }
end

function WalkmanWindow:getSlotRect(index)
    local idx = math.max(1, math.floor(tonumber(index) or 1))
    local y = SLOT_STACK_Y + ((idx - 1) * (SLOT_SIZE + SLOT_STACK_GAP_Y))
    return {
        x = SLOT_STACK_X,
        y = y,
        w = SLOT_SIZE,
        h = SLOT_SIZE
    }
end

function WalkmanWindow:getBatteryMeterRect()
    local batteryRect = self:getSlotRect(3)
    return {
        x = BATTERY_METER_X,
        y = batteryRect.y,
        w = BATTERY_METER_W,
        h = BATTERY_METER_H
    }
end

function WalkmanWindow:getLoopButtonX(down)
    if down == true then
        return LOOP_BUTTON_DOWN_X
    end
    return LOOP_BUTTON_UP_X
end

function WalkmanWindow:getLoopButtonRect()
    return {
        x = tonumber(self.loopButtonCurrentX) or self:getLoopButtonX(false),
        y = LOOP_BUTTON_Y,
        w = LOOP_BUTTON_W,
        h = LOOP_BUTTON_H
    }
end

function WalkmanWindow:getCassetteDisplayRect()
    return {
        x = CASSETTE_DISPLAY_X,
        y = CASSETTE_DISPLAY_Y,
        w = CASSETTE_DISPLAY_W,
        h = CASSETTE_DISPLAY_H
    }
end

function WalkmanWindow:getWalkmanSideRect()
    return {
        x = SIDE_X,
        y = SIDE_Y,
        w = SIDE_W,
        h = SIDE_H
    }
end
function WalkmanWindow:getCollapsedVisibleHeight()
    local headerRect = self:getHeaderRect()
    local closeRect = self:getCloseRect()
    local headerBottom = headerRect.y + headerRect.h
    local closeBottom = closeRect.y + closeRect.h
    return math.max(headerBottom, closeBottom)
end

function WalkmanWindow:getDefaultExpandedY()
    local _, screenH = getScreenSize()
    return math.max(0, screenH - EXPANDED_BOTTOM_MARGIN - self.height)
end

function WalkmanWindow:isHeaderHit(x, y)
    return pointInRect(x, y, self:getHeaderRect())
end

function WalkmanWindow:clampWindowY(value)
    local _, screenH = getScreenSize()
    local maxY = math.max(0, screenH - self.height)
    return math.max(0, math.min(math.floor((tonumber(value) or 0) + 0.5), maxY))
end

function WalkmanWindow:getExpandedY()
    local stored = tonumber(self._nmExpandedY)
    if stored == nil then
        stored = self:getDefaultExpandedY()
    end
    return self:clampWindowY(stored)
end

function WalkmanWindow:getCollapsedY()
    local _, screenH = getScreenSize()
    return math.max(0, screenH - self:getCollapsedVisibleHeight())
end

function WalkmanWindow:getStateY(collapsed)
    if collapsed == true then
        return self:getCollapsedY()
    end
    return self:getExpandedY()
end

function WalkmanWindow:clampWindowX(value)
    local screenW = getScreenSize()
    local maxX = math.max(0, screenW - self.width)
    return math.max(0, math.min(math.floor((tonumber(value) or 0) + 0.5), maxX))
end

function WalkmanWindow:snapToState(collapsed)
    NMFancyWindowChrome.snapToState(self, collapsed, persistWindowState)
end

function WalkmanWindow:startCollapseAnimation(collapsed)
    NMFancyWindowChrome.startCollapseAnimation(self, collapsed, persistWindowState)
end

function WalkmanWindow:toggleCollapsed()
    NMFancyWindowChrome.toggleCollapsed(self, persistWindowState)
end

function WalkmanWindow:finishHeaderInteraction()
    NMFancyWindowChrome.finishHeaderInteraction(self)
end

function WalkmanWindow:updateHeaderDrag()
    return NMFancyWindowChrome.updateHeaderDrag(self, DRAG_THRESHOLD_X, persistWindowState)
end

