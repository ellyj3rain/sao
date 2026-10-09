local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

function CDPlayerWindow:onMouseDown(x, y)
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(self, "cdplayer")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(self, "cdplayer")
    end
    if pointInRect(x, y, self:getSettingsRect()) then
        self._nmSettingsPressed = true
        return true
    end
    local buttonKind = self:getButtonKindAt(x, y)
    if buttonKind then
        if self:isUiControlLockedByHold(buttonKind) then
            return true
        end
        self._nmPressedButtonKind = buttonKind
        return true
    end
    if pointInRect(x, y, self:getCloseRect()) then
        self._nmClosePressed = true
        return true
    end
    if self.isLidAnimating ~= true and self.isLidOpen == true then
        if self:isOpenLidCloseZoneHit(x, y) then
            self._nmLidZonePressed = "open_close"
            return true
        end
        if self:isOpenLidAuxZoneHit(x, y) then
            self._nmLidZonePressed = "open_aux"
            return true
        end
    end

    if self:isHeaderHit(x, y) then
        NMFancyWindowChrome.beginHeaderPress(self)
        return true
    end

    return true
end

function CDPlayerWindow:onMouseUp(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "cdplayer.onMouseUp")
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    local lidZone = tostring(self._nmLidZonePressed or "")
    if lidZone ~= "" then
        local shouldActivate = false
        if lidZone == "closed_open" then
            shouldActivate = self:isClosedLidOpenZoneHit(x, y)
        elseif lidZone == "open_close" then
            shouldActivate = self:isOpenLidCloseZoneHit(x, y)
        elseif lidZone == "open_aux" then
            shouldActivate = self:isOpenLidAuxZoneHit(x, y)
        end
        self._nmLidZonePressed = nil
        if shouldActivate then
            return self:handleLidZoneActivate(lidZone)
        end
        return true
    end

    local buttonKind = tostring(self._nmPressedButtonKind or "")
    if buttonKind ~= "" then
        local shouldActivate = pointInRect(x, y, self:getInteractiveButtonHitRect(buttonKind))
        self._nmPressedButtonKind = nil
        if shouldActivate then
            self:startButtonPulse(buttonKind)
            return self:handleClusterButtonActivate(buttonKind)
        end
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

    NMFancyWindowChrome.releaseHeaderInteraction(self, x, y)
    return true
end

function CDPlayerWindow:onMouseUpOutside(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "cdplayer.onMouseUpOutside")
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    self._nmLidZonePressed = nil
    self._nmPressedButtonKind = nil
    self._nmClosePressed = false
    self._nmSettingsPressed = false
    NMFancyWindowChrome.cancelHeaderInteraction(self)
    return true
end

function CDPlayerWindow:onMouseMove(dx, dy)
    self:updateHeaderDrag()
    return true
end

function CDPlayerWindow:onMouseMoveOutside(dx, dy)
    self._nmLidZonePressed = nil
    self._nmPressedButtonKind = nil
    self:updateHeaderDrag()
    return true
end
