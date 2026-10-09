local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

function CDPlayerWindow:getShellRect()
    return {
        x = 0,
        y = 0,
        w = self.width,
        h = self.height
    }
end

function CDPlayerWindow:getBackgroundRect()
    return {
        x = BG_X,
        y = BG_Y,
        w = BG_W,
        h = BG_H
    }
end

function CDPlayerWindow:getFrontRect()
    return {
        x = FRONT_X,
        y = FRONT_Y,
        w = FRONT_W,
        h = FRONT_H
    }
end

function CDPlayerWindow:getDisplayRect()
    return {
        x = DISPLAY_X,
        y = DISPLAY_Y,
        w = DISPLAY_W,
        h = DISPLAY_H
    }
end

function CDPlayerWindow:getDisplayViewportRect()
    local displayRect = self:getDisplayRect()
    return {
        x = displayRect.x + DISPLAY_VIEWPORT_INSET_X,
        y = displayRect.y + DISPLAY_VIEWPORT_INSET_Y,
        w = DISPLAY_VIEWPORT_W,
        h = DISPLAY_VIEWPORT_H
    }
end

function CDPlayerWindow:getWorldCDRect()
    return {
        x = WORLD_CD_X,
        y = WORLD_CD_Y,
        w = WORLD_CD_W,
        h = WORLD_CD_H
    }
end

function CDPlayerWindow:getHeadphoneSlotRect()
    return {
        x = HEADPHONE_SLOT_X,
        y = HEADPHONE_SLOT_Y,
        w = SLOT_SIZE,
        h = SLOT_SIZE
    }
end

function CDPlayerWindow:getMediaSlotRect()
    return {
        x = MEDIA_SLOT_X,
        y = MEDIA_SLOT_Y,
        w = SLOT_SIZE,
        h = SLOT_SIZE
    }
end

function CDPlayerWindow:getBatterySlotRect()
    return {
        x = BATTERY_SLOT_X,
        y = BATTERY_SLOT_Y,
        w = SLOT_SIZE,
        h = SLOT_SIZE
    }
end

function CDPlayerWindow:getBatteryMeterRect()
    return {
        x = BATTERY_METER_X,
        y = BATTERY_METER_Y,
        w = BATTERY_METER_W,
        h = BATTERY_METER_H
    }
end

function CDPlayerWindow:getSlotRect(slot)
    if slot == 1 or slot == "headphones" then
        return self:getHeadphoneSlotRect()
    end
    if slot == 2 or slot == "media" then
        return self:getMediaSlotRect()
    end
    if slot == 3 or slot == "battery" then
        return self:getBatterySlotRect()
    end
    return nil
end

function CDPlayerWindow:shouldShowClosedLidSlots()
    return self.isLidAnimating ~= true and self.isLidOpen ~= true
end

function CDPlayerWindow:getCloseRect()
    return {
        x = CLOSE_X,
        y = CLOSE_Y,
        w = CLOSE_W,
        h = CLOSE_H
    }
end

function CDPlayerWindow:getSettingsRect()
    return {
        x = OPEN_BUTTON_X + math.floor(((OPEN_BUTTON_W - CLOSE_W) * 0.5) + 0.5),
        y = OPEN_BUTTON_Y + OPEN_BUTTON_H + SETTINGS_GAP_Y,
        w = CLOSE_W,
        h = CLOSE_H
    }
end

function CDPlayerWindow:getButtonClusterRect()
    return {
        x = BUTTON_CLUSTER_X,
        y = BUTTON_CLUSTER_Y,
        w = BUTTON_CLUSTER_W,
        h = BUTTON_CLUSTER_H
    }
end

function CDPlayerWindow:getSideButtonBgRect(kind)
    if kind == "mode" then
        return {
            x = MODE_BUTTON_X,
            y = MODE_BUTTON_Y,
            w = SIDE_BUTTON_W,
            h = SIDE_BUTTON_H
        }
    end
    if kind == "power" then
        return {
            x = POWER_BUTTON_X,
            y = POWER_BUTTON_Y,
            w = SIDE_BUTTON_W,
            h = SIDE_BUTTON_H
        }
    end
    return nil
end

function CDPlayerWindow:getSideButtonRect(kind)
    local baseRect = self:getSideButtonBgRect(kind)
    if not baseRect then
        return nil
    end
    if self:isButtonVisuallyPressed(kind) ~= true then
        return baseRect
    end
    local inset = math.max(0, math.floor((tonumber(SIDE_BUTTON_PRESSED_INSET_PX) or 0) + 0.5))
    return {
        x = baseRect.x + inset,
        y = baseRect.y + inset,
        w = math.max(1, baseRect.w - (inset * 2)),
        h = math.max(1, baseRect.h - (inset * 2))
    }
end

function CDPlayerWindow:getSideButtonHitRect(kind)
    return self:getSideButtonBgRect(kind)
end

function CDPlayerWindow:getHoldButtonRect()
    return {
        x = HOLD_BUTTON_X,
        y = HOLD_BUTTON_Y,
        w = HOLD_BUTTON_W,
        h = HOLD_BUTTON_H
    }
end

function CDPlayerWindow:getOpenButtonRect()
    local rect = {
        x = OPEN_BUTTON_X,
        y = OPEN_BUTTON_Y,
        w = OPEN_BUTTON_W,
        h = OPEN_BUTTON_H
    }
    if self:isButtonVisuallyPressed("open") == true then
        rect.x = rect.x + OPEN_BUTTON_PRESS_OFFSET_X
    end
    return rect
end

function CDPlayerWindow:getOpenButtonHitRect()
    return {
        x = OPEN_BUTTON_X,
        y = OPEN_BUTTON_Y,
        w = OPEN_BUTTON_W,
        h = OPEN_BUTTON_H
    }
end

function CDPlayerWindow:getLidRect()
    return {
        x = LID_CLOSED_X,
        y = LID_CLOSED_Y,
        w = LID_W,
        h = LID_CLOSED_H
    }
end

function CDPlayerWindow:getLidStateRect(open)
    if open == true then
        return {
            x = LID_CLOSED_X,
            y = LID_OPEN_Y,
            w = LID_W,
            h = LID_OPEN_H
        }
    end
    return self:getLidRect()
end

function CDPlayerWindow:getClosedLidOpenZoneRect()
    return {
        x = LID_CLOSED_X,
        y = LID_CLOSED_Y,
        w = LID_W,
        h = LID_OPEN_ZONE_H
    }
end

function CDPlayerWindow:getOpenLidAuxZoneRect()
    return self:getClosedLidOpenZoneRect()
end

function CDPlayerWindow:getOpenLidCloseZoneRect()
    return {
        x = LID_CLOSED_X,
        y = LID_OPEN_Y,
        w = LID_W,
        h = LID_OPEN_H
    }
end

local function pointInTopHalfEllipse(x, y, rect)
    if not pointInRect(x, y, rect) then
        return false
    end
    local rx = rect.w / 2
    local ry = rect.h
    if rx <= 0 or ry <= 0 then
        return false
    end
    local cx = rect.x + rx
    local cy = rect.y + ry
    local dx = (tonumber(x) or 0) - cx
    local dy = (tonumber(y) or 0) - cy
    if dy > 0 then
        return false
    end
    local nx = (dx * dx) / (rx * rx)
    local ny = (dy * dy) / (ry * ry)
    return (nx + ny) <= 1.0
end

function CDPlayerWindow:isClosedLidOpenZoneHit(x, y)
    return pointInTopHalfEllipse(x, y, self:getClosedLidOpenZoneRect())
end

function CDPlayerWindow:isOpenLidAuxZoneHit(x, y)
    return pointInTopHalfEllipse(x, y, self:getOpenLidAuxZoneRect())
end

function CDPlayerWindow:isOpenLidCloseZoneHit(x, y)
    return pointInRect(x, y, self:getOpenLidCloseZoneRect())
end

function CDPlayerWindow:getLidRenderState()
    local currentY = tonumber(self.lidCurrentY) or (self.isLidOpen == true and LID_OPEN_Y or LID_CLOSED_Y)
    local currentH = tonumber(self.lidCurrentH) or (self.isLidOpen == true and LID_OPEN_H or LID_CLOSED_H)
    return {
        x = LID_CLOSED_X,
        y = currentY,
        w = LID_W,
        h = currentH,
        isOpen = self.isLidOpen == true
    }
end

function CDPlayerWindow:startLidAnimation(open)
    local targetRect = self:getLidStateRect(open)
    local currentY = tonumber(self.lidCurrentY) or (self.isLidOpen == true and LID_OPEN_Y or LID_CLOSED_Y)
    local currentH = tonumber(self.lidCurrentH) or (self.isLidOpen == true and LID_OPEN_H or LID_CLOSED_H)
    self.isLidOpen = (open == true)
    if currentY == targetRect.y and currentH == targetRect.h then
        self.isLidAnimating = false
        self.lidCurrentY = targetRect.y
        self.lidCurrentH = targetRect.h
        return
    end
    if open == true then
        self._nmPlayDeferredLidCloseSoundOnAnimationComplete = nil
        if self._nmSuppressNextLidOpenSound == true then
            self._nmSuppressNextLidOpenSound = nil
        else
            playCDPlayerLidSound(self, true)
        end
    elseif self._nmSuppressNextLidCloseSound == true then
        self._nmSuppressNextLidCloseSound = nil
        self._nmPlayDeferredLidCloseSoundOnAnimationComplete = nil
    else
        self._nmPlayDeferredLidCloseSoundOnAnimationComplete = true
    end
    self.isLidAnimating = true
    self.lidAnimStartY = currentY
    self.lidAnimStartH = currentH
    self.lidAnimTargetY = targetRect.y
    self.lidAnimTargetH = targetRect.h
    self.lidAnimStartTime = getNowMs()
    NMSlotHostLifecycle.refreshSlotVisibility(self)
end

function CDPlayerWindow:syncLidFromMedia(snap)
    local timed = self._nmMediaSlotTimedProgress
    local timedAction = timed and timed.active == true and tostring(timed.action or "") or ""
    local insertActive = timedAction == "insert_media"
    local ejectActive = timedAction == "eject_media"
    local hasMedia = self:hasInsertedMedia()
    local removeInFlight = self._nmSlotRemoveInFlightByType or nil
    local ejectQueued = removeInFlight and removeInFlight.media == true or false
    local shouldBeOpen = insertActive == true
        or ejectActive == true
        or ejectQueued == true
        or self.isLidManuallyOpen == true
    local targetRect = self:getLidStateRect(shouldBeOpen)
    if snap == true then
        self.isLidOpen = shouldBeOpen
        self.isLidAnimating = false
        self.lidAnimStartY = nil
        self.lidAnimStartH = nil
        self.lidAnimTargetY = nil
        self.lidAnimTargetH = nil
        self.lidAnimStartTime = nil
        self.lidCurrentY = targetRect.y
        self.lidCurrentH = targetRect.h
        NMSlotHostLifecycle.refreshSlotVisibility(self)
        return
    end
    if self.isLidOpen ~= shouldBeOpen then
        self:startLidAnimation(shouldBeOpen)
        return
    end
    if self.isLidAnimating ~= true then
        self.lidCurrentY = targetRect.y
        self.lidCurrentH = targetRect.h
    end
    NMSlotHostLifecycle.refreshSlotVisibility(self)
end

function CDPlayerWindow:getModeLabelRect()
    return {
        x = MODE_LABEL_X,
        y = MODE_LABEL_Y,
        w = MODE_LABEL_W,
        h = MODE_LABEL_H
    }
end

function CDPlayerWindow:getHoldLabelRect()
    return {
        x = HOLD_LABEL_X,
        y = HOLD_LABEL_Y,
        w = HOLD_LABEL_W,
        h = HOLD_LABEL_H
    }
end

function CDPlayerWindow:getPowerLabelRect()
    return {
        x = POWER_LABEL_X,
        y = POWER_LABEL_Y,
        w = POWER_LABEL_W,
        h = POWER_LABEL_H
    }
end

function CDPlayerWindow:getPowerIndicatorRect()
    return {
        x = POWER_INDICATOR_X,
        y = POWER_INDICATOR_Y,
        w = POWER_INDICATOR_W,
        h = POWER_INDICATOR_H
    }
end

function CDPlayerWindow:getButtonPressOffset(kind)
    local dx = 0
    local dy = 0
    if kind == "prev" then
        dx = BUTTON_PRESS_OFFSET_PX
    elseif kind == "next" then
        dx = -BUTTON_PRESS_OFFSET_PX
    elseif kind == "vol_up" then
        dy = BUTTON_PRESS_OFFSET_PX
    elseif kind == "vol_down" then
        dy = -BUTTON_PRESS_OFFSET_PX
    elseif kind == "play_stop" then
        dy = BUTTON_PRESS_OFFSET_PX
    end

    local nowMs = getNowMs()
    local pressedKind = tostring(self._nmPressedButtonKind or "")
    if pressedKind == tostring(kind or "") then
        return dx, dy
    end

    local pulses = self._nmButtonPulseUntilByKind
    local untilMs = pulses and tonumber(pulses[kind]) or 0
    if untilMs > nowMs then
        return dx, dy
    end

    return 0, 0
end

function CDPlayerWindow:getButtonRenderRect(kind)
    local rect = nil
    if kind == "prev" then
        rect = {
            x = BUTTON_CLUSTER_X + BUTTON_LEFT_RENDER_X,
            y = BUTTON_CLUSTER_Y + BUTTON_LEFT_RENDER_Y,
            w = BUTTON_LEFT_RENDER_W,
            h = BUTTON_LEFT_RENDER_H
        }
    elseif kind == "next" then
        rect = {
            x = BUTTON_CLUSTER_X + BUTTON_RIGHT_RENDER_X,
            y = BUTTON_CLUSTER_Y + BUTTON_RIGHT_RENDER_Y,
            w = BUTTON_RIGHT_RENDER_W,
            h = BUTTON_RIGHT_RENDER_H
        }
    elseif kind == "vol_up" then
        rect = {
            x = BUTTON_CLUSTER_X + BUTTON_TOP_RENDER_X,
            y = BUTTON_CLUSTER_Y + BUTTON_TOP_RENDER_Y,
            w = BUTTON_TOP_RENDER_W,
            h = BUTTON_TOP_RENDER_H
        }
    elseif kind == "vol_down" then
        rect = {
            x = BUTTON_CLUSTER_X + BUTTON_BOTTOM_RENDER_X,
            y = BUTTON_CLUSTER_Y + BUTTON_BOTTOM_RENDER_Y,
            w = BUTTON_BOTTOM_RENDER_W,
            h = BUTTON_BOTTOM_RENDER_H
        }
    elseif kind == "play_stop" then
        rect = {
            x = BUTTON_CLUSTER_X + BUTTON_CENTER_RENDER_X,
            y = BUTTON_CLUSTER_Y + BUTTON_CENTER_RENDER_Y,
            w = BUTTON_CENTER_RENDER_W,
            h = BUTTON_CENTER_RENDER_H
        }
    end
    if not rect then
        return nil
    end
    local dx, dy = self:getButtonPressOffset(kind)
    rect.x = rect.x + dx
    rect.y = rect.y + dy
    return rect
end

function CDPlayerWindow:getButtonHitRect(kind)
    if kind == "prev" then
        return {
            x = BUTTON_CLUSTER_X + BUTTON_LEFT_RENDER_X + BUTTON_SIDE_HIT_INSET_AXIS,
            y = BUTTON_CLUSTER_Y + BUTTON_LEFT_RENDER_Y + math.floor((BUTTON_LEFT_RENDER_H - BUTTON_SIDE_HIT_H) * 0.5 + 0.5),
            w = BUTTON_SIDE_HIT_W,
            h = BUTTON_SIDE_HIT_H
        }
    end
    if kind == "next" then
        return {
            x = BUTTON_CLUSTER_X + BUTTON_RIGHT_RENDER_X + BUTTON_RIGHT_RENDER_W - BUTTON_SIDE_HIT_W - BUTTON_SIDE_HIT_INSET_AXIS,
            y = BUTTON_CLUSTER_Y + BUTTON_RIGHT_RENDER_Y + math.floor((BUTTON_RIGHT_RENDER_H - BUTTON_SIDE_HIT_H) * 0.5 + 0.5),
            w = BUTTON_SIDE_HIT_W,
            h = BUTTON_SIDE_HIT_H
        }
    end
    if kind == "vol_up" then
        return {
            x = BUTTON_CLUSTER_X + BUTTON_TOP_RENDER_X + math.floor((BUTTON_TOP_RENDER_W - BUTTON_VERT_HIT_W) * 0.5 + 0.5),
            y = BUTTON_CLUSTER_Y + BUTTON_TOP_RENDER_Y + BUTTON_VERT_HIT_INSET_AXIS,
            w = BUTTON_VERT_HIT_W,
            h = BUTTON_VERT_HIT_H
        }
    end
    if kind == "vol_down" then
        return {
            x = BUTTON_CLUSTER_X + BUTTON_BOTTOM_RENDER_X + math.floor((BUTTON_BOTTOM_RENDER_W - BUTTON_VERT_HIT_W) * 0.5 + 0.5),
            y = BUTTON_CLUSTER_Y + BUTTON_BOTTOM_RENDER_Y + BUTTON_BOTTOM_RENDER_H - BUTTON_VERT_HIT_H - BUTTON_VERT_HIT_INSET_AXIS,
            w = BUTTON_VERT_HIT_W,
            h = BUTTON_VERT_HIT_H
        }
    end
    if kind == "play_stop" then
        return {
            x = BUTTON_CLUSTER_X + BUTTON_CENTER_RENDER_X + BUTTON_CENTER_HIT_INSET_X,
            y = BUTTON_CLUSTER_Y + BUTTON_CENTER_RENDER_Y + BUTTON_CENTER_HIT_INSET_Y,
            w = BUTTON_CENTER_HIT_W,
            h = BUTTON_CENTER_HIT_H
        }
    end
    return nil
end

function CDPlayerWindow:getCollapsedVisibleHeight()
    local visibleHeight = self.height - COLLAPSED_HIDDEN_FROM_BOTTOM
    return math.max(0, math.floor((tonumber(visibleHeight) or 0) + 0.5))
end

function CDPlayerWindow:getDefaultExpandedY()
    local _, screenH = getScreenSize()
    return math.max(0, screenH - self.height + EXPANDED_BOTTOM_OVERSHOOT - EXPANDED_BOTTOM_MARGIN)
end

function CDPlayerWindow:getHeaderRowSpan(y)
    local row = math.floor((tonumber(y) or -1) + 0.5)
    return HEADER_ROW_SPANS[row]
end

function CDPlayerWindow:isHeaderHit(x, y)
    if pointInRect(x, y, self:getButtonClusterRect()) then
        return false
    end
    if pointInRect(x, y, self:getSideButtonHitRect("mode")) or pointInRect(x, y, self:getSideButtonHitRect("power")) then
        return false
    end
    if pointInRect(x, y, self:getHoldButtonRect()) then
        return false
    end
    if pointInRect(x, y, self:getOpenButtonHitRect()) then
        return false
    end
    local row = self:getHeaderRowSpan(y)
    if not row then
        return false
    end
    local px = math.floor((tonumber(x) or -1) + 0.5)
    if px >= row.left1 and px < row.right1 then
        return true
    end
    return row.left2 ~= nil and px >= row.left2 and px < row.right2
end

function CDPlayerWindow:clampWindowY(value)
    local _, screenH = getScreenSize()
    local maxY = math.max(0, screenH - self.height + EXPANDED_BOTTOM_OVERSHOOT - EXPANDED_BOTTOM_MARGIN)
    return math.max(0, math.min(math.floor((tonumber(value) or 0) + 0.5), maxY))
end

function CDPlayerWindow:getExpandedY()
    local stored = tonumber(self._nmExpandedY)
    if stored == nil then
        stored = self:getDefaultExpandedY()
    end
    return self:clampWindowY(stored)
end

function CDPlayerWindow:getCollapsedY()
    local _, screenH = getScreenSize()
    return math.max(0, screenH - self:getCollapsedVisibleHeight())
end

function CDPlayerWindow:getStateY(collapsed)
    if collapsed == true then
        return self:getCollapsedY()
    end
    return self:getExpandedY()
end

function CDPlayerWindow:clampWindowX(value)
    local screenW = getScreenSize()
    local maxX = math.max(0, screenW - self.width)
    return math.max(0, math.min(math.floor((tonumber(value) or 0) + 0.5), maxX))
end

function CDPlayerWindow:snapToState(collapsed)
    NMFancyWindowChrome.snapToState(self, collapsed, persistWindowState)
end

function CDPlayerWindow:startCollapseAnimation(collapsed)
    NMFancyWindowChrome.startCollapseAnimation(self, collapsed, persistWindowState)
end

function CDPlayerWindow:toggleCollapsed()
    NMFancyWindowChrome.toggleCollapsed(self, persistWindowState)
end

function CDPlayerWindow:finishHeaderInteraction()
    NMFancyWindowChrome.finishHeaderInteraction(self)
end

function CDPlayerWindow:updateHeaderDrag()
    return NMFancyWindowChrome.updateHeaderDrag(self, DRAG_THRESHOLD_X, persistWindowState)
end
