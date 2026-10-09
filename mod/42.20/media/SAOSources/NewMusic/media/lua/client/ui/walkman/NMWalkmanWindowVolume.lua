local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

function WalkmanWindow:syncVolumeWheelFromState(force)
    local resolved = self:resolveContextCached()
    local liveVolume = resolved and resolved.state and resolved.state.volume or nil
    if liveVolume == nil then
        if force == true and self._nmWheelStableVolume == nil then
            self._nmWheelStableVolume = 1.0
        end
        return
    end
    liveVolume = clamp01(liveVolume)
    self._nmWheelStableVolume = liveVolume
    if force == true or self._nmWheelDragging ~= true then
        self._nmWheelPreviewVolume = liveVolume
    end
    syncWalkmanVolumeClickPercent(self, volumeToPercent(self._nmWheelPreviewVolume or liveVolume), false)
end

function WalkmanWindow:updateVolumeLabelVisibility()
    self._nmWheelLabelVisibleUntil = getNowMs() + VOLUME_LABEL_HIDE_DELAY_MS
end

function WalkmanWindow:updateLoopIconVisibility()
    self._nmLoopIconVisibleUntil = getNowMs() + VOLUME_LABEL_HIDE_DELAY_MS
end

function WalkmanWindow:adjustVolumeWheelByStep(stepPct)
    local currentVolume = tonumber(self._nmWheelPreviewVolume)
        or tonumber(self._nmWheelStableVolume)
        or 1.0
    local currentPct = volumeToPercent(currentVolume)
    local nextPct = math.max(0, math.min(100, currentPct + math.floor(tonumber(stepPct) or 0)))
    local nextVolume = clamp01(nextPct / 100.0)
    self._nmWheelPreviewVolume = nextVolume
    self._nmWheelStableVolume = nextVolume
    self._nmWheelPendingDispatchVolume = nextVolume
    syncWalkmanVolumeClickPercent(self, nextPct, true)
    self:updateVolumeLabelVisibility()
    self:flushVolumeWheelDispatch(true)
end

function WalkmanWindow:shouldShowVolumeLabel()
    if self._nmWheelDragging == true then
        return true
    end
    return (tonumber(self._nmWheelLabelVisibleUntil) or 0) > getNowMs()
end

function WalkmanWindow:shouldShowLoopIcon()
    return (tonumber(self._nmLoopIconVisibleUntil) or 0) > getNowMs()
end

function WalkmanWindow:setVolumePreviewFromMouseY(mouseY)
    local localY = (tonumber(mouseY) or 0) - (tonumber(self._nmWheelDragStartMouseY) or 0)
    local startVolume = tonumber(self._nmWheelDragStartVolume) or tonumber(self._nmWheelStableVolume) or 1.0
    local normalizedDelta = (-localY) / math.max(1, VOLUME_WHEEL_DRAG_SPAN_PX)
    local nextVolume = clamp01(startVolume + normalizedDelta)
    self._nmWheelPreviewVolume = nextVolume
    self._nmWheelPendingDispatchVolume = nextVolume
    syncWalkmanVolumeClickPercent(self, volumeToPercent(nextVolume), true)
    self:updateVolumeLabelVisibility()
end

function WalkmanWindow:updateCassetteSpoolAngles(nowMs)
    local resolved = self.resolveContextCached and self:resolveContextCached() or nil
    local transport = NMDeviceUiHost.resolveTransportState(self, {
        resolved = resolved,
    })
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

function WalkmanWindow:flushVolumeWheelDispatch(force)
    local pending = tonumber(self._nmWheelPendingDispatchVolume)
    if pending == nil then
        return
    end
    local now = getNowMs()
    local last = tonumber(self._nmWheelLastDispatchMs) or 0
    if force ~= true and (now - last) < VOLUME_DRAG_DISPATCH_MIN_MS then
        return
    end
    local normalized = clamp01(pending)
    local ok = self:executeUiControl("set_volume", { volume = normalized })
    if ok == true then
        self._nmWheelLastDispatchMs = now
        self._nmWheelLastDispatchedVolume = normalized
        self._nmWheelStableVolume = normalized
        self._nmWheelPendingDispatchVolume = nil
    end
end

