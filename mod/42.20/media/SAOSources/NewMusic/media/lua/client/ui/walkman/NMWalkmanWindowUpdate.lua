local NMUiAutoClose = require "ui/shared/host/NMUiAutoClose"

local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local function autoCloseProbeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_auto_close") == true
end

local function autoCloseWindowKey(window)
    local target = window and window.target or nil
    if not target then
        return "none"
    end
    return table.concat({
        tostring(target.kind or "item"),
        tostring(target.itemId or ""),
        tostring(target.uuid or "")
    }, "|")
end

local function autoCloseProbe(window, tag, detail, throttleMs)
    if not autoCloseProbeEnabled() then
        return
    end
    if not (NMCore and NMCore.logChannel and NMCore.shouldLogEvery) then
        return
    end
    local nowMs = getNowMs and getNowMs() or 0
    local key = "uiAutoCloseProbe.walkman." .. tostring(tag or "unknown") .. "." .. autoCloseWindowKey(window)
    if not NMCore.shouldLogEvery(key, nowMs, throttleMs or 1000) then
        return
    end
    NMCore.logChannel("ui_auto_close", tostring(tag or "autoclose"), tostring(detail or ""))
end

local function logAutoCloseResult(window, result)
    local event = NMUiAutoClose.buildProbeEvent("walkman", window and window.target or nil, result)
    autoCloseProbe(window, event.tag, event.detail, event.throttleMs)
end

function WalkmanWindow:update()
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
        reasonTag = "walkman",
        probeFn = function(window, tick)
            autoCloseProbe(
                window,
                "autoclose_tick",
                string.format(
                    "ui=walkman polled=%s nowMs=%s lastMs=%s delta=%s",
                    tostring(tick.due == true),
                    tostring(tick.nowMs),
                    tostring(tick.lastCheckMs),
                    tostring(tick.deltaMs)
                ),
                tick.due == true and 750 or 2000
            )
        end,
        resultFn = function(window, result)
            logAutoCloseResult(window, result)
        end,
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
    local resolved = self:resolveContextCached()
    if self._nmWheelDragging ~= true then
        self:syncVolumeWheelFromState(false)
    end
    self:syncPlayButtonFromTransport(resolved, nil, false, false)
    self:syncLidFromMedia(false)

    if self.isLidAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.lidAnimStartTime) or 0))
        local t = math.min(1.0, elapsed / LID_ANIMATION_DURATION_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startY = tonumber(self.lidAnimStartY) or (self.isLidOpen == true and LID_Y or LID_OPEN_Y)
        local targetY = tonumber(self.lidAnimTargetY) or (self.isLidOpen == true and LID_OPEN_Y or LID_Y)
        local startH = tonumber(self.lidAnimStartH) or (self.isLidOpen == true and LID_H or LID_OPEN_H)
        local targetH = tonumber(self.lidAnimTargetH) or (self.isLidOpen == true and LID_OPEN_H or LID_H)
        local nextY = startY + ((targetY - startY) * eased)
        local nextH = startH + ((targetH - startH) * eased)
        self.lidCurrentY = math.floor(nextY + 0.5)
        self.lidCurrentH = math.floor(nextH + 0.5)
        if t >= 1.0 then
            self.isLidAnimating = false
            self.lidCurrentY = targetY
            self.lidCurrentH = targetH
        end
    end

    if self.isPlayButtonAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.playButtonAnimStartTime) or 0))
        local t = math.min(1.0, elapsed / PLAY_BUTTON_ANIMATION_DURATION_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startY = tonumber(self.playButtonAnimStartY) or self:getPlayButtonY(not self.isPlayButtonDown)
        local targetY = tonumber(self.playButtonAnimTargetY) or self:getPlayButtonY(self.isPlayButtonDown)
        local y = startY + ((targetY - startY) * eased)
        self.playButtonCurrentY = math.floor(y + 0.5)
        if t >= 1.0 then
            if self.playButtonPhase == "down" then
                self.playButtonPhase = "up"
                self.playButtonAnimStartY = targetY
                self.playButtonAnimTargetY = self:getPlayButtonY(false)
                self.playButtonAnimStartTime = getNowMs()
            else
                self.isPlayButtonAnimating = false
                self.playButtonPhase = nil
                self.playButtonCurrentY = self:getPlayButtonY(self.isPlayButtonDown == true)
                self.playButtonAnimStartY = nil
                self.playButtonAnimTargetY = nil
                self.playButtonAnimStartTime = nil
            end
        end
    end

    if self.isPrevButtonAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.prevButtonAnimStartTime) or 0))
        local t = math.min(1.0, elapsed / PREV_BUTTON_ANIMATION_PHASE_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startY = tonumber(self.prevButtonAnimStartY) or self:getPrevButtonY(false)
        local targetY = tonumber(self.prevButtonAnimTargetY) or self:getPrevButtonY(false)
        local y = startY + ((targetY - startY) * eased)
        self.prevButtonCurrentY = math.floor(y + 0.5)
        if t >= 1.0 then
            if self.prevButtonPhase == "down" then
                self.prevButtonPhase = "up"
                self.prevButtonAnimStartY = targetY
                self.prevButtonAnimTargetY = self:getPrevButtonY(false)
                self.prevButtonAnimStartTime = getNowMs()
            else
                self.isPrevButtonAnimating = false
                self.prevButtonPhase = nil
                self.prevButtonCurrentY = self:getPrevButtonY(false)
                self.prevButtonAnimStartY = nil
                self.prevButtonAnimTargetY = nil
                self.prevButtonAnimStartTime = nil
            end
        end
    end

    if self.isNextButtonAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.nextButtonAnimStartTime) or 0))
        local t = math.min(1.0, elapsed / PREV_BUTTON_ANIMATION_PHASE_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startY = tonumber(self.nextButtonAnimStartY) or self:getNextButtonY(false)
        local targetY = tonumber(self.nextButtonAnimTargetY) or self:getNextButtonY(false)
        local y = startY + ((targetY - startY) * eased)
        self.nextButtonCurrentY = math.floor(y + 0.5)
        if t >= 1.0 then
            if self.nextButtonPhase == "down" then
                self.nextButtonPhase = "up"
                self.nextButtonAnimStartY = targetY
                self.nextButtonAnimTargetY = self:getNextButtonY(false)
                self.nextButtonAnimStartTime = getNowMs()
            else
                self.isNextButtonAnimating = false
                self.nextButtonPhase = nil
                self.nextButtonCurrentY = self:getNextButtonY(false)
                self.nextButtonAnimStartY = nil
                self.nextButtonAnimTargetY = nil
                self.nextButtonAnimStartTime = nil
            end
        end
    end

    if self.isLoopButtonAnimating == true then
        local elapsed = math.max(0, nowMs - (tonumber(self.loopButtonAnimStartTime) or 0))
        local t = math.min(1.0, elapsed / LOOP_BUTTON_ANIMATION_PHASE_MS)
        local eased = 1.0 - ((1.0 - t) * (1.0 - t))
        local startX = tonumber(self.loopButtonAnimStartX) or self:getLoopButtonX(false)
        local targetX = tonumber(self.loopButtonAnimTargetX) or self:getLoopButtonX(false)
        local x = startX + ((targetX - startX) * eased)
        self.loopButtonCurrentX = math.floor(x + 0.5)
        if t >= 1.0 then
            if self.loopButtonPhase == "down" then
                self.loopButtonPhase = "up"
                self.loopButtonAnimStartX = targetX
                self.loopButtonAnimTargetX = self:getLoopButtonX(false)
                self.loopButtonAnimStartTime = getNowMs()
            else
                self.isLoopButtonAnimating = false
                self.loopButtonPhase = nil
                self.loopButtonCurrentX = self:getLoopButtonX(false)
                self.loopButtonAnimStartX = nil
                self.loopButtonAnimTargetX = nil
                self.loopButtonAnimStartTime = nil
            end
        end
    end

    if self._nmWheelDragging == true then
        self:flushVolumeWheelDispatch(false)
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
        local y = startY + ((targetY - startY) * eased)
        self:setY(math.floor(y + 0.5))
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

