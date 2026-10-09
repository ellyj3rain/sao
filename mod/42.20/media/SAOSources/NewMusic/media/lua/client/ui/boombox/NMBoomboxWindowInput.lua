local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

local function localMouse(window)
    return (getMouseX and getMouseX() or 0) - (window.getAbsoluteX and window:getAbsoluteX() or 0),
        (getMouseY and getMouseY() or 0) - (window.getAbsoluteY and window:getAbsoluteY() or 0)
end

function BoomboxWindow:onMouseDown(x, y)
    local canInteractWithLid = self.isCollapsed ~= true
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(self, "boombox")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(self, "boombox")
    end
    if pointInRect(x, y, self:getCloseRect()) then
        self._nmClosePressed = true
        return true
    end
    if pointInRect(x, y, self:getSettingsRect()) then
        self._nmSettingsPressed = true
        return true
    end
    if pointInRect(x, y, self:getPowerSwitchBgRect()) then
        return self:handlePowerSwitchTrigger()
    end
    local mainKinds = { "play", "stop", "prev", "next", "eject" }
    for i = 1, #mainKinds do
        local kind = mainKinds[i]
        if pointInRect(x, y, self:getMainButtonRect(kind)) then
            self._nmPressedMainButtonKind = kind
            return true
        end
    end
    if self.isCollapsed == true then
        local topKinds = { "play", "stop", "prev", "next" }
        for i = 1, #topKinds do
            local kind = topKinds[i]
            if pointInRect(x, y, self:getTopCollapsedButtonHitRect(kind)) then
                self._nmPressedTopButtonKind = kind
                return true
            end
        end
    end
    if pointInRect(x, y, self:getVolumeBgRect()) then
        self._nmKnobDragging = true
        self._nmKnobDragStartMouseX = getMouseX and getMouseX() or x
        self._nmKnobDragStartMouseY = getMouseY and getMouseY() or y
        self:syncVolumeKnobFromState(true)
        self._nmKnobDragStartVolume = tonumber(self._nmKnobPreviewVolume) or tonumber(self._nmKnobStableVolume) or 1.0
        self._nmKnobDragLastAngle = self:getVolumeKnobAngle(self._nmKnobDragStartVolume)
        self._nmKnobPendingDispatchVolume = nil
        self:setVolumePreviewFromMouse(self._nmKnobDragStartMouseX, self._nmKnobDragStartMouseY)
        self:flushVolumeDispatch(false)
        return true
    end
    for i = 1, 3 do
        if pointInRect(x, y, self:getModeButtonRect(i)) then
            self._nmPressedModeIndex = i
            return true
        end
    end
    if canInteractWithLid and pointInRect(x, y, self:getLidArrowRect()) then
        self._nmLidArrowPressed = true
        return true
    end
    if self:isHeaderHit(x, y) then
        NMFancyWindowChrome.beginHeaderPress(self)
        return true
    end
    return false
end

function BoomboxWindow:onMouseUp(x, y)
    local canInteractWithLid = self.isCollapsed ~= true
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "boombox.onMouseUp")
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
    local mainKind = tostring(self._nmPressedMainButtonKind or "")
    self._nmPressedMainButtonKind = nil
    if mainKind ~= "" and pointInRect(x, y, self:getMainButtonRect(mainKind)) then
        if mainKind == "play" then return self:handleManualPlayTrigger(false) end
        if mainKind == "stop" then return self:handleStopTrigger(false) end
        if mainKind == "prev" then return self:handlePrevTrigger(false) end
        if mainKind == "next" then return self:handleNextTrigger(false) end
        if mainKind == "eject" then return self:handleEjectTrigger() end
    end

    local topKind = tostring(self._nmPressedTopButtonKind or "")
    self._nmPressedTopButtonKind = nil
    if topKind ~= "" and self.isCollapsed == true and pointInRect(x, y, self:getTopCollapsedButtonHitRect(topKind)) then
        if topKind == "play" then return self:handleManualPlayTrigger(true) end
        if topKind == "stop" then return self:handleStopTrigger(true) end
        if topKind == "prev" then return self:handlePrevTrigger(true) end
        if topKind == "next" then return self:handleNextTrigger(true) end
    end

    if self._nmKnobDragging == true then
        self._nmKnobDragging = false
        self._nmKnobDragLastAngle = nil
        self:flushVolumeDispatch(true)
        self:updateVolumeLabelVisibility()
        return true
    end

    local pressedMode = tonumber(self._nmPressedModeIndex)
    self._nmPressedModeIndex = nil
    if pressedMode and pointInRect(x, y, self:getModeButtonRect(pressedMode)) then
        return self:handleModeTrigger(pressedMode)
    end

    local shouldPressLid = canInteractWithLid and self._nmLidArrowPressed == true and pointInRect(x, y, self:getLidArrowRect())
    self._nmLidArrowPressed = false
    if shouldPressLid then
        if self.isLidManuallyOpen == true then
            self:executeUiControl("close_lid", {})
            return true
        end
        if self:hasInsertedCassette() == true then
            return self:ejectMediaViaControl() == true
        end
        self:executeUiControl("open_lid", {})
        return true
    end

    if canInteractWithLid and pointInRect(x, y, self:getLidIngressZoneRect()) and self:shouldShowLidIngressZone() then
        if self:insertDraggedMediaViaLid() == true then
            return true
        end
    end

    if NMFancyWindowChrome.releaseHeaderInteraction(self, x, y) == true then
        return true
    end
    return false
end

function BoomboxWindow:onMouseUpOutside(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "boombox.onMouseUpOutside")
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    self._nmClosePressed = false
    self._nmSettingsPressed = false
    self._nmPressedMainButtonKind = nil
    self._nmPressedTopButtonKind = nil
    self._nmPressedModeIndex = nil
    self._nmLidArrowPressed = false
    if self._nmKnobDragging == true then
        self._nmKnobDragging = false
        self._nmKnobDragLastAngle = nil
        self:flushVolumeDispatch(true)
        self:updateVolumeLabelVisibility()
        return true
    end
    return NMFancyWindowChrome.cancelHeaderInteraction(self)
end

function BoomboxWindow:onMouseMove(dx, dy)
    if self._nmKnobDragging == true then
        self:setVolumePreviewFromMouse(getMouseX and getMouseX() or 0, getMouseY and getMouseY() or 0)
        return true
    end
    self:updateHoverTooltip()
    return self:updateHeaderDrag() == true
end

function BoomboxWindow:onMouseMoveOutside(dx, dy)
    if self._nmKnobDragging == true then
        self:setVolumePreviewFromMouse(getMouseX and getMouseX() or 0, getMouseY and getMouseY() or 0)
        return true
    end
    self.tooltip = nil
    return self:updateHeaderDrag() == true
end

function BoomboxWindow:onMouseWheel(del)
    local x, y = localMouse(self)
    if not pointInRect(x, y, self:getVolumeBgRect()) then
        return false
    end
    local wheelDelta = math.floor(tonumber(del) or 0)
    if wheelDelta == 0 then
        return true
    end
    self:syncVolumeKnobFromState(true)
    self:adjustVolumeByStep(-wheelDelta)
    return true
end
