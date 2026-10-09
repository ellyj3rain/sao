local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

function WalkmanWindow:onMouseDown(x, y)
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(self, "walkman")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(self, "walkman")
    end
    if pointInRect(x, y, self:getCloseRect()) then
        self._nmClosePressed = true
        return true
    end

    if pointInRect(x, y, self:getSettingsRect()) then
        self._nmSettingsPressed = true
        return true
    end

    if pointInRect(x, y, self:getPlayButtonHitRect()) then
        self._nmPlayButtonPressed = true
        return true
    end

    if pointInRect(x, y, self:getPrevButtonHitRect()) then
        self._nmPrevButtonPressed = true
        return true
    end

    if pointInRect(x, y, self:getNextButtonHitRect()) then
        self._nmNextButtonPressed = true
        return true
    end

    if pointInRect(x, y, self:getVolumeWheelHitRect()) then
        self._nmWheelDragging = true
        self._nmWheelDragStartMouseY = getMouseY and getMouseY() or y
        self:syncVolumeWheelFromState(true)
        self._nmWheelDragStartVolume = tonumber(self._nmWheelPreviewVolume) or tonumber(self._nmWheelStableVolume) or 1.0
        syncWalkmanVolumeClickPercent(self, volumeToPercent(self._nmWheelDragStartVolume), false)
        self._nmWheelPendingDispatchVolume = nil
        self:setVolumePreviewFromMouseY(getMouseY and getMouseY() or y)
        self:flushVolumeWheelDispatch(false)
        return true
    end

    if pointInRect(x, y, self:getLoopButtonRect()) then
        self._nmLoopButtonPressed = true
        return true
    end

    if pointInRect(x, y, self:getLidArrowRect()) then
        self._nmLidArrowPressed = true
        return true
    end

    if self:isHeaderHit(x, y) then
        NMFancyWindowChrome.beginHeaderPress(self)
        return true
    end

    return false
end

function WalkmanWindow:onMouseUp(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "walkman.onMouseUp")
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    local shouldClose = self._nmClosePressed == true and pointInRect(x, y, self:getCloseRect())
    self._nmClosePressed = false
    if shouldClose then
        self:close()
        return true
    end

    local shouldOpenSettings = self._nmSettingsPressed == true and pointInRect(x, y, self:getSettingsRect())
    self._nmSettingsPressed = false
    if shouldOpenSettings then
        FancySettingsWindow.openForSourceWindow(self)
        return true
    end

    local shouldTogglePlay = self._nmPlayButtonPressed == true and pointInRect(x, y, self:getPlayButtonHitRect())
    self._nmPlayButtonPressed = false
    if shouldTogglePlay then
        return self:handlePlayButtonActivate()
    end

    local shouldPressPrev = self._nmPrevButtonPressed == true and pointInRect(x, y, self:getPrevButtonHitRect())
    self._nmPrevButtonPressed = false
    if shouldPressPrev then
        return self:handlePrevButtonActivate()
    end

    local shouldPressNext = self._nmNextButtonPressed == true and pointInRect(x, y, self:getNextButtonHitRect())
    self._nmNextButtonPressed = false
    if shouldPressNext then
        return self:handleNextButtonActivate()
    end

    if self._nmWheelDragging == true then
        self._nmWheelDragging = false
        self:flushVolumeWheelDispatch(true)
        self:updateVolumeLabelVisibility()
        return true
    end

    local shouldPressLoop = self._nmLoopButtonPressed == true and pointInRect(x, y, self:getLoopButtonRect())
    self._nmLoopButtonPressed = false
    if shouldPressLoop then
        local ok = self:executeUiControl("cycle_mode", {})
        if ok == true then
            playWalkmanTransportSound(self, false)
            self:startLoopButtonPress()
            self:updateLoopIconVisibility()
        end
        return true
    end

    local shouldPressLidArrow = self._nmLidArrowPressed == true and pointInRect(x, y, self:getLidArrowRect())
    self._nmLidArrowPressed = false
    if shouldPressLidArrow then
        if self.isLidManuallyOpen == true then
            self:executeUiControl("close_lid", {})
            return true
        end
        if self:hasInsertedCassette() == true then
            return self:ejectMediaViaLid() == true
        end
        self:executeUiControl("open_lid", {})
        return true
    end

    if pointInRect(x, y, self:getLidIngressZoneRect()) and self:shouldShowLidIngressZone() then
        if self:insertDraggedMediaViaLid() == true then
            return true
        end
    end

    if NMFancyWindowChrome.releaseHeaderInteraction(self, x, y) == true then
        return true
    end
    return false
end

function WalkmanWindow:onMouseUpOutside(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "walkman.onMouseUpOutside")
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    self._nmClosePressed = false
    self._nmSettingsPressed = false
    self._nmPlayButtonPressed = false
    self._nmPrevButtonPressed = false
    self._nmNextButtonPressed = false
    self._nmLoopButtonPressed = false
    self._nmLidArrowPressed = false
    if self._nmWheelDragging == true then
        self._nmWheelDragging = false
        self:flushVolumeWheelDispatch(true)
        self:updateVolumeLabelVisibility()
        return true
    end
    return NMFancyWindowChrome.cancelHeaderInteraction(self)
end

function WalkmanWindow:onMouseMove(dx, dy)
    if self._nmWheelDragging == true then
        self:setVolumePreviewFromMouseY(getMouseY and getMouseY() or 0)
        return true
    end
    self:updateHoverTooltip()
    return self:updateHeaderDrag() == true
end

function WalkmanWindow:onMouseMoveOutside(dx, dy)
    if self._nmWheelDragging == true then
        self:setVolumePreviewFromMouseY(getMouseY and getMouseY() or 0)
        return true
    end
    self.tooltip = nil
    return self:updateHeaderDrag() == true
end

function WalkmanWindow:onMouseWheel(del)
    local localX = (getMouseX and getMouseX() or 0) - (self.getAbsoluteX and self:getAbsoluteX() or 0)
    local localY = (getMouseY and getMouseY() or 0) - (self.getAbsoluteY and self:getAbsoluteY() or 0)
    if not pointInRect(localX, localY, self:getVolumeWheelHitRect()) then
        return false
    end
    local wheelDelta = math.floor(tonumber(del) or 0)
    if wheelDelta == 0 then
        return true
    end
    self:syncVolumeWheelFromState(true)
    self:adjustVolumeWheelByStep(-wheelDelta)
    return true
end
