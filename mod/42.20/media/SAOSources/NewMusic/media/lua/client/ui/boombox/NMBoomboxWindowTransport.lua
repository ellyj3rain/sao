require "ui/shared/host/NMFancyWindowTooltipHost"

local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

local MODE_BY_INDEX = { "loop_song", "loop_album", "shuffle" }

local function getTransportState(window, resolved)
    return NMDeviceUiHost.resolveTransportState(window, { resolved = resolved, renderModel = window and window._nmRenderModel or nil })
end

local function getControlTransportState(window, resolved)
    return NMDeviceUiHost.resolveControlTransportState(window, { resolved = resolved })
end

local function getVolumeAngleRange()
    local startAngle = tonumber(VOLUME_MIN_ANGLE) or 42
    local endAngle = tonumber(VOLUME_MAX_ANGLE) or 336
    if endAngle <= startAngle then
        endAngle = endAngle + 360
    end
    return startAngle, endAngle
end

local function clampVolumeAngle(angle, anchorAngle)
    local startAngle, endAngle = getVolumeAngleRange()
    local resolved = tonumber(angle)
    if resolved == nil then
        return startAngle
    end
    if resolved >= startAngle and resolved <= endAngle then
        return resolved
    end
    local hysteresis = math.max(0, tonumber(VOLUME_GAP_HYSTERESIS_DEGREES) or 18)
    local anchor = tonumber(anchorAngle)
    if anchor ~= nil then
        if math.abs(anchor - startAngle) <= hysteresis then
            return startAngle
        end
        if math.abs(anchor - endAngle) <= hysteresis then
            return endAngle
        end
        return math.abs(anchor - startAngle) <= math.abs(anchor - endAngle) and startAngle or endAngle
    end
    return math.abs(resolved - startAngle) <= math.abs(resolved - endAngle) and startAngle or endAngle
end

local function angleToVolume(angle)
    local startAngle, endAngle = getVolumeAngleRange()
    local clampedAngle = clampVolumeAngle(angle, nil)
    return clamp01((clampedAngle - startAngle) / math.max(1, endAngle - startAngle))
end

local function resolveDragAngleFromMouse(window, mouseX, mouseY)
    if not window then
        return nil
    end
    local rect = window:getVolumeBgRect()
    local ax = window.getAbsoluteX and window:getAbsoluteX() or 0
    local ay = window.getAbsoluteY and window:getAbsoluteY() or 0
    local centerX = ax + rect.x + (rect.w / 2)
    local centerY = ay + rect.y + (rect.h / 2)
    local dx = (tonumber(mouseX) or centerX) - centerX
    local dy = (tonumber(mouseY) or centerY) - centerY
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then
        return nil
    end
    local angle = math.deg(math.atan2(-dx, dy))
    if angle < 0 then
        angle = angle + 360
    end
    local anchorAngle = tonumber(window and window._nmKnobDragLastAngle)
    local startAngle, _ = getVolumeAngleRange()
    local candidates = { angle, angle + 360, angle - 360 }
    local chosen = candidates[1]
    if anchorAngle ~= nil then
        local bestDistance = math.abs(chosen - anchorAngle)
        for i = 2, #candidates do
            local candidate = candidates[i]
            local distance = math.abs(candidate - anchorAngle)
            if distance < bestDistance then
                chosen = candidate
                bestDistance = distance
            end
        end
    elseif chosen < startAngle then
        chosen = chosen + 360
    end
    return clampVolumeAngle(chosen, anchorAngle)
end

function BoomboxWindow:buildTransportState(resolved)
    local ctx = resolved or self:resolveContextCached()
    local state = ctx and ctx.state or nil
    local hasUsablePower = true
    if state and state.batteryPresent ~= nil then
        hasUsablePower = state.batteryPresent == true and (tonumber(state.batteryCharge) or 0) > 0
    end
    return {
        isPlaying = state and state.isPlaying == true,
        isOn = state and state.isOn == true,
        trackCount = resolveTrackCount(state),
        playbackPolicy = tostring(state and state.playbackPolicy or "autoplay"),
        volume = clamp01(state and state.volume or 1.0),
        hasMedia = self:hasInsertedCassette() == true,
        hasUsablePower = hasUsablePower == true,
    }
end

local function canStartRealPlayback(transport)
    return transport
        and transport.hasUsablePower == true
        and (tonumber(transport.trackCount) or 0) > 0
end

local function canPowerOnFromTransport(transport)
    return transport and transport.hasUsablePower == true
end

local function getModeTooltipByIndex(index)
    local policy = MODE_BY_INDEX[tonumber(index) or 0]
    if policy == "loop_song" then
        return NMTranslations.modeTooltip("LoopSong")
    end
    if policy == "loop_album" then
        return NMTranslations.modeTooltip("LoopAlbum")
    end
    if policy == "shuffle" then
        return NMTranslations.modeTooltip("Shuffle")
    end
    return nil
end

local function resolveObservedPowerState(window, resolved)
    local ctx = resolved or (window and window.resolveContextCached and window:resolveContextCached()) or nil
    local state = ctx and ctx.state or nil
    return state and state.isOn == true
end

function BoomboxWindow:resolvePassiveTransportState(resolved)
    return NMDeviceUiHost.resolvePassiveTransportState(self, resolved)
end

function BoomboxWindow:markPassiveTransportSyncedForNextPrerender(transportKey)
    return NMDeviceUiHost.markPassiveTransportSyncedForNextPrerender(self, transportKey)
end

function BoomboxWindow:hasPassiveTransportSyncForCurrentFrame()
    return NMDeviceUiHost.hasPassiveTransportSyncForCurrentFrame(self)
end

function BoomboxWindow:setPendingPowerSwitchState(targetOn)
    self._nmHasObservedPowerState = true
    self._nmPowerSwitchOn = targetOn == true
    self._nmPowerSwitchPendingOn = targetOn == true
    self._nmPowerSwitchPendingUntilMs = getNowMs() + POWER_SWITCH_PENDING_MS
end

function BoomboxWindow:syncPowerSwitchFromTransport(resolved, snap, transport)
    local shouldBeOn = type(transport) == "table" and transport.isOn == true or resolveObservedPowerState(self, resolved)
    local previous = self._nmPowerSwitchOn == true
    local nowMs = getNowMs()
    local pendingUntil = tonumber(self._nmPowerSwitchPendingUntilMs) or 0
    local pendingActive = pendingUntil > nowMs
    local pendingOn = self._nmPowerSwitchPendingOn == true
    local suppressTransitionSound = false
    if pendingActive == true and shouldBeOn ~= pendingOn then
        shouldBeOn = pendingOn
    else
        suppressTransitionSound = self._nmPowerSwitchPendingOn ~= nil and shouldBeOn ~= pendingOn
        self._nmPowerSwitchPendingOn = nil
        self._nmPowerSwitchPendingUntilMs = 0
    end
    if snap == true or self._nmHasObservedPowerState ~= true then
        self._nmHasObservedPowerState = true
        self._nmPowerSwitchOn = shouldBeOn
        return shouldBeOn
    end
    self._nmHasObservedPowerState = true
    if previous ~= shouldBeOn then
        self._nmPowerSwitchOn = shouldBeOn
        if suppressTransitionSound ~= true then
            playBoomboxSoundEvent(self, "boombox_button_pop")
        end
    end
    return shouldBeOn
end

function BoomboxWindow:updateHoverTooltip()
    return NMFancyWindowTooltipHost.updateHoverTooltip(self)
end

function BoomboxWindow:updateTooltipUI()
    return NMFancyWindowTooltipHost.updateTooltipUi(self)
end

function BoomboxWindow:getTooltipUiOptions(text)
    return { maxLineWidth = 300, offsetY = 24, cacheText = true }
end

function BoomboxWindow:getPowerTooltip(transport)
    local transportState = transport or self:buildTransportState()
    if transportState and transportState.isOn == true and transportState.hasUsablePower == true then
        return NMTranslations.ui("PowerOn")
    end
    if transportState and transportState.isOn == true then
        return NMTranslations.ui("PowerOnNoPower")
    end
    return NMTranslations.ui("PowerOff")
end

function BoomboxWindow:getHoverTooltipAt(x, y)
    if pointInRect(x, y, self:getCloseRect()) then
        return nil
    end
    if pointInRect(x, y, self:getSettingsRect()) then
        return FancySettingsWindow.getSettingsTooltipText()
    end
    if pointInRect(x, y, self:getPowerSwitchBgRect()) then
        return self:getPowerTooltip()
    end
    if pointInRect(x, y, self:getVolumeBgRect()) then
        return self:getVolumeLabelText()
    end
    local buttons = {
        { "play", NMTranslations.ui("PlaySong") },
        { "stop", NMTranslations.ui("StopSong") },
        { "prev", NMTranslations.ui("PreviousTrack") },
        { "next", NMTranslations.ui("NextTrack") },
        { "eject", NMTranslations.ui("EjectMedia") },
    }
    for i = 1, #buttons do
        local entry = buttons[i]
        if pointInRect(x, y, self:getMainButtonRect(entry[1])) then
            return entry[2]
        end
    end
    if self.isCollapsed == true then
        for i = 1, 4 do
            local kind = ({ "play", "stop", "prev", "next" })[i]
            if pointInRect(x, y, self:getTopCollapsedButtonHitRect(kind)) then
                return ({
                    play = NMTranslations.ui("PlaySong"),
                    stop = NMTranslations.ui("StopSong"),
                    prev = NMTranslations.ui("PreviousTrack"),
                    next = NMTranslations.ui("NextTrack"),
                })[kind]
            end
        end
    end
    for i = 1, 3 do
        if pointInRect(x, y, self:getModeButtonRect(i)) then
            return getModeTooltipByIndex(i)
        end
    end
    return nil
end

function BoomboxWindow:shouldShowVolumeLabel()
    if self._nmKnobDragging == true then
        return true
    end
    return (tonumber(self._nmKnobLabelVisibleUntil) or 0) > getNowMs()
end

function BoomboxWindow:updateVolumeLabelVisibility()
    self._nmKnobLabelVisibleUntil = getNowMs() + VOLUME_LABEL_HIDE_DELAY_MS
end

function BoomboxWindow:syncVolumeKnobFromState(force)
    local resolved = self:resolveContextCached()
    local liveVolume = resolved and resolved.state and resolved.state.volume or nil
    if liveVolume == nil then
        if force == true and self._nmKnobStableVolume == nil then
            self._nmKnobStableVolume = 1.0
        end
        return
    end
    liveVolume = clamp01(liveVolume)
    self._nmKnobStableVolume = liveVolume
    if force == true or self._nmKnobDragging ~= true then
        self._nmKnobPreviewVolume = liveVolume
    end
    syncVolumeClickPercent(self, volumeToPercent(self._nmKnobPreviewVolume or liveVolume), false)
end

function BoomboxWindow:setVolumePreviewFromMouse(mouseX, mouseY)
    local nextAngle = resolveDragAngleFromMouse(self, mouseX, mouseY)
    if nextAngle == nil then
        return
    end
    local nextVolume = angleToVolume(nextAngle)
    self._nmKnobPreviewVolume = nextVolume
    self._nmKnobPendingDispatchVolume = nextVolume
    self._nmKnobDragLastAngle = nextAngle
    syncVolumeClickPercent(self, volumeToPercent(nextVolume), true)
    self:updateVolumeLabelVisibility()
end

function BoomboxWindow:adjustVolumeByStep(stepPct)
    local currentVolume = tonumber(self._nmKnobPreviewVolume) or tonumber(self._nmKnobStableVolume) or 1.0
    local currentPct = volumeToPercent(currentVolume)
    local nextPct = math.max(0, math.min(100, currentPct + math.floor(tonumber(stepPct) or 0)))
    local nextVolume = clamp01(nextPct / 100.0)
    self._nmKnobPreviewVolume = nextVolume
    self._nmKnobStableVolume = nextVolume
    self._nmKnobPendingDispatchVolume = nextVolume
    syncVolumeClickPercent(self, nextPct, true)
    self:updateVolumeLabelVisibility()
    self:flushVolumeDispatch(true)
end

function BoomboxWindow:flushVolumeDispatch(force)
    local pending = tonumber(self._nmKnobPendingDispatchVolume)
    if pending == nil then
        return
    end
    local now = getNowMs()
    local last = tonumber(self._nmKnobLastDispatchMs) or 0
    if force ~= true and (now - last) < VOLUME_DRAG_DISPATCH_MIN_MS then
        return
    end
    local normalized = clamp01(pending)
    local ok = self:executeUiControl("set_volume", { volume = normalized })
    if ok == true then
        self._nmKnobLastDispatchMs = now
        self._nmKnobStableVolume = normalized
        self._nmKnobPendingDispatchVolume = nil
    end
end

function BoomboxWindow:updateCassetteSpoolAngles(nowMs)
    local transport = getTransportState(self)
    local now = tonumber(nowMs) or getNowMs()
    local last = tonumber(self._nmSpoolLastUpdateMs)
    if last == nil then
        self._nmSpoolLastUpdateMs = now
        return
    end
    local elapsedMs = math.max(0, now - last)
    self._nmSpoolLastUpdateMs = now
    if transport.isPlaying ~= true or elapsedMs <= 0 then
        return
    end
    local delta = (elapsedMs / 1000.0) * CASSETTE_SPOOL_DEGREES_PER_SECOND
    self._nmLeftSpoolAngle = ((tonumber(self._nmLeftSpoolAngle) or 0.0) + delta) % 360
    self._nmRightSpoolAngle = ((tonumber(self._nmRightSpoolAngle) or 0.0) + delta) % 360
end

function BoomboxWindow:getSelectedModeIndex()
    local policy = self:getModePolicy()
    for i = 1, 3 do
        if MODE_BY_INDEX[i] == policy then
            return i
        end
    end
    return nil
end

function BoomboxWindow:syncPlayButtonFromTransport(resolved, snap, transport)
    local transportState = type(transport) == "table" and transport or getControlTransportState(self, resolved)
    local authoritativeDown = transportState and transportState.isPlaying == true
    if authoritativeDown == true then
        self:clearLocalPlayPresentation(false)
    end
    local shouldBeDown = authoritativeDown or self._nmLocalPlayPresentationLatched == true
    local previousAuthoritative = self._nmAuthoritativePlayDown == true
    local visualMainDown = self._nmMainButtonDownByKind.play == true
    local visualTopDown = self._nmTopButtonDownByKind and self._nmTopButtonDownByKind.play == true or false
    self._nmAuthoritativePlayDown = authoritativeDown
    if snap == true or self._nmHasObservedPlayState ~= true then
        self._nmHasObservedPlayState = true
        self._nmMainButtonDownByKind.play = shouldBeDown
        self:setTopPlayButtonDown(shouldBeDown)
        return transportState
    end
    self._nmHasObservedPlayState = true
    if previousAuthoritative ~= authoritativeDown or visualMainDown ~= shouldBeDown or visualTopDown ~= shouldBeDown then
        self._nmMainButtonDownByKind.play = shouldBeDown
        self:setTopPlayButtonDown(shouldBeDown)
    end
    return transportState
end

function BoomboxWindow:startMainButtonFlick(kind)
    self._nmMainButtonPulseByKind[kind] = { phase = "down", startedAt = getNowMs() }
    playBoomboxSoundEvent(self, "boombox_button_in")
end

function BoomboxWindow:releaseMainButtonFlick(kind)
    self._nmMainButtonPulseByKind[kind] = { phase = "up", startedAt = getNowMs() }
    playBoomboxSoundEvent(self, "boombox_button_out")
end

function BoomboxWindow:setPlayButtonDown(down, playSound)
    local current = self._nmMainButtonDownByKind.play == true
    local nextDown = down == true
    if current == nextDown then
        return
    end
    self._nmMainButtonDownByKind.play = nextDown
    if playSound == true then
        playBoomboxSoundEvent(self, nextDown and "boombox_button_in" or "boombox_button_out")
    end
end

function BoomboxWindow:setTopPlayButtonDown(down)
    self._nmTopButtonDownByKind = self._nmTopButtonDownByKind or { play = false }
    self._nmTopButtonDownByKind.play = down == true
    if down ~= true then
        self._nmTopButtonPressOffsetByKind.play = 0
    end
end

function BoomboxWindow:clearLocalPlayPresentation(syncVisuals)
    self._nmLocalPlayPresentationLatched = false
    if syncVisuals == true and self._nmAuthoritativePlayDown ~= true then
        self:setPlayButtonDown(false, false)
        self:setTopPlayButtonDown(false)
    end
end

function BoomboxWindow:latchLocalPlayPresentation(fromCollapsed)
    self._nmLocalPlayPresentationLatched = true
    self._nmMainButtonPulseByKind.play = nil
    self:setPlayButtonDown(true, true)
    self:setTopPlayButtonDown(true)
    if fromCollapsed == true then
        self._nmTopButtonPressOffsetByKind.play = TOP_BUTTON_PRESS_OFFSET
    end
    return true
end

function BoomboxWindow:handlePowerSwitchTrigger()
    local resolved = self:resolveContextCached()
    local transport = getControlTransportState(self, resolved)
    local currentOn = resolveObservedPowerState(self, resolved)
    local targetOn = currentOn ~= true
    if targetOn and canPowerOnFromTransport(transport) ~= true then
        return false
    end
    local action = targetOn and "power_on" or "power_off"
    local ok = self:executeUiControl(action, {})
    if ok == true then
        if targetOn then
            self:setPendingPowerSwitchState(true)
        else
            self:setPendingPowerSwitchState(false)
        end
        playBoomboxSoundEvent(self, "boombox_button_pop")
    end
    return ok == true
end

function BoomboxWindow:handleManualPlayTrigger(fromCollapsed)
    local transport = getControlTransportState(self)
    -- The boombox "play" controls can present a local latch without changing
    -- the authoritative power switch or transport state when playback is impossible.
    if self:hasInsertedCassette() ~= true or canStartRealPlayback(transport) ~= true then
        self:latchLocalPlayPresentation(fromCollapsed)
        return true
    end
    local ok = self:executeUiControl("play", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true then
        self:clearLocalPlayPresentation(false)
        self:setPlayButtonDown(true, true)
        self:setTopPlayButtonDown(true)
        self:setPendingPowerSwitchState(true)
        playBoomboxSoundEvent(self, "boombox_manual_play")
        if fromCollapsed == true then
            self._nmTopButtonPressOffsetByKind.play = TOP_BUTTON_PRESS_OFFSET
        end
    end
    return true
end

function BoomboxWindow:handleStopTrigger(fromCollapsed)
    if self._nmLocalPlayPresentationLatched == true and self._nmAuthoritativePlayDown ~= true then
        self:clearLocalPlayPresentation(true)
        if fromCollapsed == true then
            self:pressTopButton("stop", false, true)
        else
            self:startMainButtonFlick("stop")
        end
        return true
    end
    if self:hasInsertedCassette() ~= true then
        if fromCollapsed == true then
            self:pressTopButton("stop", false, true)
        else
            self:startMainButtonFlick("stop")
        end
        return true
    end
    local ok = self:executeUiControl("stop", {})
    if ok == true then
        self:clearLocalPlayPresentation(false)
        self:executeUiControl("power_off", {})
        self:setPlayButtonDown(false, fromCollapsed ~= true)
        self:setTopPlayButtonDown(false)
        self:setPendingPowerSwitchState(false)
        if fromCollapsed == true then
            self:pressTopButton("stop", false, true)
        else
            self:startMainButtonFlick("stop")
        end
    end
    return true
end

function BoomboxWindow:handlePrevTrigger(fromCollapsed)
    if self:hasInsertedCassette() ~= true then
        if fromCollapsed == true then
            self:pressTopButton("prev", false, true)
        else
            self:startMainButtonFlick("prev")
        end
        return true
    end
    local transport = getControlTransportState(self)
    local ok = self:executeUiControl("prev_track", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true then
        if fromCollapsed == true then
            self:pressTopButton("prev", false, true)
        else
            self:startMainButtonFlick("prev")
        end
    end
    return true
end

function BoomboxWindow:handleNextTrigger(fromCollapsed)
    if self:hasInsertedCassette() ~= true then
        if fromCollapsed == true then
            self:pressTopButton("next", false, true)
        else
            self:startMainButtonFlick("next")
        end
        return true
    end
    local transport = getControlTransportState(self)
    local ok = self:executeUiControl("next_track", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true then
        if fromCollapsed == true then
            self:pressTopButton("next", false, true)
        else
            self:startMainButtonFlick("next")
        end
    end
    return true
end

function BoomboxWindow:handleEjectTrigger()
    if self:hasInsertedCassette() ~= true then
        self:startMainButtonFlick("eject")
        return true
    end
    local ok = self:executeUiControl("eject_media", {})
    if ok == true then
        self:startMainButtonFlick("eject")
        playBoomboxSoundEvent(self, "boombox_button_out")
    end
    return true
end

function BoomboxWindow:handleModeTrigger(index)
    local mode = MODE_BY_INDEX[index]
    if not mode then
        return false
    end
    local selected = self:getSelectedModeIndex()
    local targetPolicy = selected == index and "autoplay" or mode
    local ok = self:executeUiControl("set_playback_policy", { playbackPolicy = targetPolicy })
    if ok == true then
        playBoomboxSoundEvent(self, "boombox_mode_press")
    end
    return ok == true
end

function BoomboxWindow:pressTopButton(kind, playPressSound, playReleaseSoundOnPress)
    self._nmTopButtonPressOffsetByKind[kind] = TOP_BUTTON_PRESS_OFFSET
    self._nmTopButtonReleaseSoundOnReturnByKind = self._nmTopButtonReleaseSoundOnReturnByKind or { play = false, stop = true, prev = true, next = true }
    if playReleaseSoundOnPress == true then
        self._nmTopButtonReleaseSoundOnReturnByKind[kind] = false
        playBoomboxSoundEvent(self, "boombox_button_out")
    else
        self._nmTopButtonReleaseSoundOnReturnByKind[kind] = true
    end
    if playPressSound ~= false then
        playBoomboxSoundEvent(self, "boombox_button_in")
    end
end
