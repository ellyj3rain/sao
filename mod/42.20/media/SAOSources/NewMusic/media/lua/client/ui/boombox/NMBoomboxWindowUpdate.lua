local NMUiAutoClose = require "ui/shared/host/NMUiAutoClose"
local RenderProbe = require "ui/shared/host/NMFancyUiRenderProbe"

local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local function animatePulse(window, kind, nowMs)
    local pulse = window._nmMainButtonPulseByKind[kind]
    if not pulse then
        return
    end
    local elapsed = math.max(0, nowMs - (tonumber(pulse.startedAt) or 0))
    if elapsed < DEFAULT_BUTTON_ANIM_MS then
        return
    end
    if pulse.phase == "down" then
        window:releaseMainButtonFlick(kind)
        return
    end
    window._nmMainButtonPulseByKind[kind] = nil
end

function BoomboxWindow:update()
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local function finishUpdate()
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(self, "device.update", perfStart)
        end
    end
    ISPanel.update(self)
    if math.abs((tonumber(self._nmAppliedFancyScale) or 0.0) - getFancyDeviceUiScale()) >= 0.0001 then
        self:applyCurrentScaleLayout()
    end
    local nowMs = NMUiAutoClose.getNowMs()
    local closed = NMUiAutoClose.tickWindowAutoClose(self, {
        nowMs = nowMs,
        pollMs = 250,
        reasonTag = "boombox",
    })
    if closed then
        finishUpdate()
        return
    end

    self:updateHoverTooltip()
    self:updateTooltipUI()
    self:updateCassetteSpoolAngles(nowMs)
    self:setX(self:clampWindowX(self:getX()))
    self._nmExpandedY = self:getExpandedY()
    if self._nmKnobDragging ~= true then
        self:syncVolumeKnobFromState(false)
    end
    local resolved = self:resolveContextCached()
    local passiveTransport, passiveTransportKey = self:resolvePassiveTransportState(resolved)
    local phaseStart = RenderProbe.begin(self)
    self:syncPlayButtonFromTransport(resolved, false, passiveTransport)
    self:syncPowerSwitchFromTransport(resolved, false, passiveTransport)
    RenderProbe.finish(self, "transport.passive_sync", phaseStart)
    self:markPassiveTransportSyncedForNextPrerender(passiveTransportKey)
    self:syncLidFromMedia(false)

    if self.isLidAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.lidAnimStartTime) or 0))
        local t = math.min(1.0, elapsed / LID_ANIMATION_DURATION_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startY = tonumber(self.lidAnimStartY) or (self.isLidOpen == true and LID_Y or LID_OPEN_Y)
        local targetY = tonumber(self.lidAnimTargetY) or (self.isLidOpen == true and LID_OPEN_Y or LID_Y)
        local startH = tonumber(self.lidAnimStartH) or (self.isLidOpen == true and LID_H or LID_OPEN_H)
        local targetH = tonumber(self.lidAnimTargetH) or (self.isLidOpen == true and LID_OPEN_H or LID_H)
        self.lidCurrentY = math.floor(startY + ((targetY - startY) * eased) + 0.5)
        self.lidCurrentH = math.floor(startH + ((targetH - startH) * eased) + 0.5)
        if t >= 1.0 then
            self.isLidAnimating = false
            self.lidCurrentY = targetY
            self.lidCurrentH = targetH
        end
    end

    animatePulse(self, "stop", nowMs)
    animatePulse(self, "prev", nowMs)
    animatePulse(self, "next", nowMs)
    animatePulse(self, "eject", nowMs)
    animatePulse(self, "play", nowMs)

    local collapsed = self.isCollapsed == true
    local targetTopOffset = collapsed and TOP_BUTTON_POP_Y or TOP_BUTTON_RETRACT_Y
    local shouldPopSound = collapsed and self._nmTopButtonsVisible ~= true
    if shouldPopSound then
        playBoomboxSoundEvent(self, "boombox_button_pop")
    end
    self._nmTopButtonsVisible = collapsed
    for i = 1, 4 do
        local kind = ({ "play", "stop", "prev", "next" })[i]
        local current = tonumber(self._nmTopButtonCurrentOffsetByKind[kind]) or TOP_BUTTON_RETRACT_Y
        self._nmTopButtonCurrentOffsetByKind[kind] = current + ((targetTopOffset - current) * 0.35)
        if math.abs(self._nmTopButtonCurrentOffsetByKind[kind] - targetTopOffset) < 1 then
            self._nmTopButtonCurrentOffsetByKind[kind] = targetTopOffset
        end
        local press = tonumber(self._nmTopButtonPressOffsetByKind[kind]) or 0
        local holdDown = kind == "play" and self._nmTopButtonDownByKind and self._nmTopButtonDownByKind.play == true
        if holdDown == true then
            local pressStep = math.max(1, math.floor((3 * getFancyDeviceUiScale()) + 0.5))
            self._nmTopButtonPressOffsetByKind[kind] = math.min(TOP_BUTTON_PRESS_OFFSET, press + pressStep)
        elseif press > 0 then
            local returnStep = math.max(1, math.floor((3 * getFancyDeviceUiScale()) + 0.5))
            press = math.max(0, press - returnStep)
            self._nmTopButtonPressOffsetByKind[kind] = press
            if press == 0 then
                local shouldPlayRelease = self._nmTopButtonReleaseSoundOnReturnByKind == nil
                    or self._nmTopButtonReleaseSoundOnReturnByKind[kind] ~= false
                if shouldPlayRelease then
                    playBoomboxSoundEvent(self, "boombox_button_out")
                end
                if self._nmTopButtonReleaseSoundOnReturnByKind then
                    self._nmTopButtonReleaseSoundOnReturnByKind[kind] = true
                end
            end
        end
    end

    if self._nmKnobDragging == true then
        self:flushVolumeDispatch(false)
    end

    if self.draggingHeader == true then
        if self.headerDragMode == "collapsed" then
            self:setY(self:getCollapsedY())
        else
            self:setY(self:getExpandedY())
        end
        finishUpdate()
        return
    end

    if self.isAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.animStartTime) or 0))
        local t = math.min(1.0, elapsed / ANIMATION_DURATION_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startY = tonumber(self.animStartY) or self:getY()
        local targetY = tonumber(self.animTargetY) or self:getStateY(self.isCollapsed)
        self:setY(math.floor(startY + ((targetY - startY) * eased) + 0.5))
        if t >= 1.0 then
            self.isAnimating = false
            self:setY(targetY)
        end
        finishUpdate()
        return
    end

    self:setY(self:getStateY(self.isCollapsed))
    finishUpdate()
end
