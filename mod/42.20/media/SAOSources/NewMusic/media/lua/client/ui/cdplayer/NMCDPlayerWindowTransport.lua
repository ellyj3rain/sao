require "ui/shared/host/NMFancyWindowTooltipHost"

local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

local BUTTON_KINDS = {
    "prev",
    "vol_up",
    "next",
    "vol_down",
    "play_stop",
}

local function getTransportState(window, transport, resolved)
    return NMDeviceUiHost.resolveTransportState(window, {
        transport = transport,
        resolved = resolved,
        renderModel = window and window._nmRenderModel or nil,
    })
end

local function getControlTransportState(window, transport, resolved)
    return NMDeviceUiHost.resolveControlTransportState(window, {
        transport = transport,
        resolved = resolved,
    })
end

function CDPlayerWindow:getButtonKindAt(x, y)
    for i = 1, #BUTTON_KINDS do
        local kind = BUTTON_KINDS[i]
        if pointInRect(x, y, self:getButtonHitRect(kind)) then
            return kind
        end
    end
    if pointInRect(x, y, self:getSideButtonHitRect("mode")) then
        return "mode"
    end
    if pointInRect(x, y, self:getSideButtonHitRect("power")) then
        return "power"
    end
    if pointInRect(x, y, self:getHoldButtonRect()) then
        return "hold"
    end
    if pointInRect(x, y, self:getOpenButtonHitRect()) then
        return "open"
    end
    return nil
end

function CDPlayerWindow:getInteractiveButtonHitRect(kind)
    local key = tostring(kind or "")
    if key == "mode" or key == "power" then
        return self:getSideButtonHitRect(key)
    end
    if key == "hold" then
        return self:getHoldButtonRect()
    end
    if key == "open" then
        return self:getOpenButtonHitRect()
    end
    return self:getButtonHitRect(key)
end

function CDPlayerWindow:startButtonPulse(kind)
    self._nmButtonPulseUntilByKind = self._nmButtonPulseUntilByKind or {}
    self._nmButtonPulseUntilByKind[kind] = getNowMs() + BUTTON_PRESS_LINGER_MS
end

function CDPlayerWindow:isButtonVisuallyPressed(kind)
    local pressedKind = tostring(self._nmPressedButtonKind or "")
    if pressedKind == tostring(kind or "") then
        return true
    end
    local pulses = self._nmButtonPulseUntilByKind
    local untilMs = pulses and tonumber(pulses[kind]) or 0
    return untilMs > getNowMs()
end

function CDPlayerWindow:getSideButtonScale(kind)
    if self:isButtonVisuallyPressed(kind) then
        return SIDE_BUTTON_SCALE_PRESSED
    end
    return 1.0
end

function CDPlayerWindow:buildTransportState(resolved)
    local ctx = resolved or self:resolveContextCached()
    local state = ctx and ctx.state or nil
    local profile = ctx and ctx.profile or nil
    local hasUsablePower = false
    if profile and profile.supportsBattery == true then
        hasUsablePower = state and state.batteryPresent == true and (tonumber(state.batteryCharge) or 0) > 0
    else
        hasUsablePower = state and state.isOn == true or false
    end
    return {
        isPlaying = state and state.isPlaying == true,
        isOn = state and state.isOn == true,
        hasMedia = tostring(state and state.mediaFullType or "") ~= "",
        trackCount = resolveTrackCount(state),
        volume = clamp01(state and state.volume or 1.0),
        playbackPolicy = getLoopPolicy(state),
        hasUsablePower = hasUsablePower == true,
        isHold = state and state.isHold == true or false,
        isStandby = state and state.isHold == true or false,
    }
end

function CDPlayerWindow:getHoldTooltip(transport)
    if NMDeviceUiHost and NMDeviceUiHost.hasHoldControl and NMDeviceUiHost.hasHoldControl(self) ~= true then
        return ""
    end
    local transportState = getTransportState(self, transport)
    if transportState and transportState.isHold == true then
        return NMTranslations.ui("HoldOn")
    end
    return NMTranslations.ui("HoldOff")
end

function CDPlayerWindow:getModeTooltip(transport)
    local transportState = getTransportState(self, transport)
    local policy = transportState and transportState.playbackPolicy or "autoplay"
    if policy == "loop_song" then
        return NMTranslations.modeTooltip("LoopSong")
    end
    if policy == "loop_album" then
        return NMTranslations.modeTooltip("LoopAlbum")
    end
    if policy == "shuffle" then
        return NMTranslations.modeTooltip("Shuffle")
    end
    return NMTranslations.modeTooltip("AutoOff")
end

function CDPlayerWindow:getPowerTooltip(transport)
    local transportState = getTransportState(self, transport)
    if transportState and transportState.isOn == true and transportState.hasUsablePower == true then
        return NMTranslations.ui("PowerOn", "Power: ON")
    end
    if transportState and transportState.isOn == true then
        return NMTranslations.ui("PowerOnNoPower", "Power: ON (No Power)")
    end
    return NMTranslations.ui("PowerOff", "Power: OFF")
end

function CDPlayerWindow:getOpenTooltip()
    return NMTranslations.ui("Open", "Open")
end

function CDPlayerWindow:getPowerIndicatorState(transport)
    local transportState = getTransportState(self, transport)
    if transportState and transportState.isStandby == true and transportState.isOn == true and transportState.hasUsablePower == true then
        return "standby"
    end
    if transportState and transportState.isOn == true and transportState.hasUsablePower == true then
        return "on"
    end
    return "off"
end

function CDPlayerWindow:isDisplayPoweredOn(transport)
    local transportState = getTransportState(self, transport)
    return transportState and transportState.isOn == true and transportState.hasUsablePower == true or false
end

function CDPlayerWindow:shouldPlayPoweredButtonSound(transport)
    local state = transport or self:buildTransportState()
    return state.isOn == true and state.hasUsablePower == true
end

function CDPlayerWindow:getInsertedMediaFullType()
    local renderState = self:getSlotRenderState("media")
    return tostring(renderState and renderState.fullType or "")
end

function CDPlayerWindow:hasInsertedMedia()
    return self:getInsertedMediaFullType() ~= ""
end

function CDPlayerWindow:getInsertedCDWorldTexture()
    local fullType = self:getInsertedMediaFullType()
    if fullType == "" or not NMMediaWorldTextureResolver or not NMMediaWorldTextureResolver.resolveTexture then
        return nil, nil
    end
    return NMMediaWorldTextureResolver.resolveTexture(fullType)
end

function CDPlayerWindow:getTimedCDAnimationState()
    local timed = self._nmMediaSlotTimedProgress
    local actionName = timed and tostring(timed.action or "") or ""
    local isInsert = actionName == "insert_media"
    local isEject = actionName == "eject_media"
    if not (timed and timed.active == true and (isInsert == true or isEject == true)) then
        return {
            visible = false,
            action = "",
            fullType = "",
            texture = nil,
            texturePath = nil,
            x = WORLD_CD_X,
            y = WORLD_CD_Y,
            w = WORLD_CD_W,
            h = WORLD_CD_H,
            alpha = 0.0,
            progress = 0.0,
        }
    end

    local fullType = tostring(self._nmPendingMediaSlotFullType or "")
    if fullType == "" then
        return {
            visible = false,
            action = actionName,
            fullType = "",
            texture = nil,
            texturePath = nil,
            x = WORLD_CD_X,
            y = WORLD_CD_Y,
            w = WORLD_CD_W,
            h = WORLD_CD_H,
            alpha = 0.0,
            progress = 0.0,
        }
    end

    local texture, texturePath = nil, nil
    if NMMediaWorldTextureResolver and NMMediaWorldTextureResolver.resolveTexture then
        texture, texturePath = NMMediaWorldTextureResolver.resolveTexture(fullType)
    end
    if not texture then
        return {
            visible = false,
            action = actionName,
            fullType = fullType,
            texture = nil,
            texturePath = texturePath,
            x = WORLD_CD_X,
            y = WORLD_CD_Y,
            w = WORLD_CD_W,
            h = WORLD_CD_H,
            alpha = 0.0,
            progress = 0.0,
        }
    end

    local finalRect = self:getWorldCDRect()
    local progress = clamp01(tonumber(timed.delta) or 0.0)
    local startY = finalRect.y
    local endY = finalRect.y
    local alpha = 1.0
    if isInsert == true then
        startY = finalRect.y - 220
        endY = finalRect.y
        alpha = progress
    else
        startY = finalRect.y
        endY = finalRect.y - 220
        alpha = 1.0 - progress
    end
    local currentY = startY + ((endY - startY) * progress)
    return {
        visible = true,
        action = actionName,
        fullType = fullType,
        texture = texture,
        texturePath = texturePath,
        x = finalRect.x,
        y = math.floor(currentY + 0.5),
        w = finalRect.w,
        h = finalRect.h,
        alpha = alpha,
        progress = progress,
    }
end

function CDPlayerWindow:shouldShowAuxIngressHighlight()
    if self.isLidOpen ~= true or self.isLidAnimating == true or self:hasInsertedMedia() == true then
        return false
    end
    if self:canAcceptDraggedMediaViaLid() ~= true then
        return false
    end
    local absX = self.getAbsoluteX and self:getAbsoluteX() or 0
    local absY = self.getAbsoluteY and self:getAbsoluteY() or 0
    local localX = (getMouseX and getMouseX() or 0) - absX
    local localY = (getMouseY and getMouseY() or 0) - absY
    return self:isOpenLidAuxZoneHit(localX, localY)
end

function CDPlayerWindow:onMediaExtractDragThresholdCrossed(drag)
    if not (drag and tostring(drag.slotType or "") == "media") then
        return
    end
end

function CDPlayerWindow:beginClosedSlotMediaExtract()
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local beginMediaExtractDragFn = mediaEnv and mediaEnv.beginMediaExtractDrag or nil
    if not beginMediaExtractDragFn then
        return false
    end
    local fullType = self:getInsertedMediaFullType()
    if fullType == "" then
        return false
    end
    beginMediaExtractDragFn(self, fullType, "slot")
    return true
end

function CDPlayerWindow:ejectClosedSlotMedia(sourceTag)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
    if not queueMediaSlotEjectFn then
        return false
    end
    local fullType = self:getInsertedMediaFullType()
    if fullType == "" then
        return false
    end
    return queueMediaSlotEjectFn(self, sourceTag or "cdplayer_slot", "slot") == true
end

function CDPlayerWindow:ejectOpenLidMediaViaAux(sourceTag)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
    if not queueMediaSlotEjectFn then
        return false
    end
    local fullType = self:getInsertedMediaFullType()
    if fullType == "" then
        return false
    end
    return queueMediaSlotEjectFn(self, sourceTag or "cdplayer_aux", "aux") == true
end

function CDPlayerWindow:getPlayStopTooltip(transport)
    local transportState = getTransportState(self, transport)
    if transportState and transportState.isPlaying == true then
        return NMTranslations.ui("StopSong", "Stop Song")
    end
    return NMTranslations.ui("PlaySong", "Play Song")
end

function CDPlayerWindow:getHoverTooltipAt(x, y)
    if pointInRect(x, y, self:getSettingsRect()) then
        return FancySettingsWindow.getSettingsTooltipText()
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("prev")) then
        return NMTranslations.ui("PreviousTrack")
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("next")) then
        return NMTranslations.ui("NextTrack")
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("vol_up")) then
        return NMTranslations.ui("VolumeUp", "Volume Up")
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("vol_down")) then
        return NMTranslations.ui("VolumeDown", "Volume Down")
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("play_stop")) then
        return self:getPlayStopTooltip()
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("mode")) then
        return self:getModeTooltip()
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("power")) then
        return self:getPowerTooltip()
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("hold")) then
        return self:getHoldTooltip()
    end
    if pointInRect(x, y, self:getInteractiveButtonHitRect("open")) then
        return self:getOpenTooltip()
    end
    return nil
end

function CDPlayerWindow:isUiControlLockedByHold(kind)
    local key = tostring(kind or "")
    if key == "" or key == "hold" or key == "open" then
        return false
    end
    local transport = getControlTransportState(self)
    return transport and transport.isHold == true or false
end

function CDPlayerWindow:canAcceptDraggedMediaViaLid()
    if self.isLidOpen ~= true or self.isLidAnimating == true then
        return false
    end
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local isCompatibleMediaDragFn = mediaEnv and mediaEnv.isCompatibleMediaDrag or nil
    local resolveMediaSlotFullTypeFn = mediaEnv and mediaEnv.resolveMediaSlotFullType or nil
    if not (isCompatibleMediaDragFn and resolveMediaSlotFullTypeFn) then
        return false
    end
    local dragItems = nil
    local ok = false
    if NMSlotActionCommon and NMSlotActionCommon.getDraggedInventoryItems then
        dragItems, ok = NMSlotActionCommon.getDraggedInventoryItems()
    end
    if ok ~= true or type(dragItems) ~= "table" or #dragItems <= 0 then
        return false
    end
    local resolved = self:resolveContextCached()
    local state = resolved and resolved.state or nil
    return isCompatibleMediaDragFn(self, dragItems) and resolveMediaSlotFullTypeFn(self, state) == ""
end

function CDPlayerWindow:insertDraggedMediaViaLid()
    local interaction = rawget(_G, "NMPortableMediaInteraction") or nil
    if interaction and interaction.handleMediaSlotMouseUp then
        return interaction.handleMediaSlotMouseUp(self, "aux") == true
    end
    return false
end

function CDPlayerWindow:queueContextMediaInsert(liveItem, payload, args)
    if not (liveItem and payload and args) then
        return false
    end
    self._nmDeferAutoInsertLidCloseSound = true
    if self.isLidOpen ~= true then
        self._nmSuppressNextLidOpenSound = true
    end
    self._nmPendingContextMediaInsert = {
        args = args
    }
    self._nmCloseLidAfterContextInsert = false
    self._nmPendingMediaSlotFullType = tostring(payload.mediaEjectFullType or payload.mediaFullType or "")
    self.isLidManuallyOpen = true
    self:syncLidFromMedia(false)
    return true
end

function CDPlayerWindow:handleOpenButtonActivate()
    local action = self.isLidOpen == true and "close_lid" or "open_lid"
    self:executeUiControl(action, {})
    return true
end

function CDPlayerWindow:handleLidZoneActivate(zoneKind)
    local kind = tostring(zoneKind or "")
    if kind == "open_close" then
        self.isLidManuallyOpen = false
        self:syncLidFromMedia(false)
        return true
    end
    if kind == "open_aux" then
        if self._nmMediaExtractDrag then
            return true
        end
        if self:hasInsertedMedia() == true then
            self:ejectOpenLidMediaViaAux("open_aux")
            return true
        end
        if self:insertDraggedMediaViaLid() == true then
            return true
        end
        return true
    end
    return false
end

function CDPlayerWindow:updateHoverTooltip()
    return NMFancyWindowTooltipHost.updateHoverTooltip(self)
end

function CDPlayerWindow:getTooltipUiOptions()
    return {
        maxLineWidth = 300,
        offsetY = 24,
        cacheText = true,
    }
end

function CDPlayerWindow:updateTooltipUI()
    return NMFancyWindowTooltipHost.updateTooltipUi(self)
end

function CDPlayerWindow:canUseTransportButtons()
    local transport = getControlTransportState(self)
    return transport and transport.hasMedia == true or false
end

function CDPlayerWindow:playTransportNoMediaFeedback()
    if self:shouldPlayPoweredButtonSound() then
        playCDPlayerTransportSound(self, false)
    end
end

function CDPlayerWindow:handlePlayStopActivate()
    if self:canUseTransportButtons() ~= true then
        self:playTransportNoMediaFeedback()
        return true
    end
    local transport = getControlTransportState(self)
    if not (transport and transport.isOn == true) then
        return true
    end
    if transport.isPlaying == true then
        self:executeUiControl("stop", { trackCount = tonumber(transport.trackCount) or 0 })
        playCDPlayerTransportSound(self, true)
    else
        self:executeUiControl("play", { trackCount = tonumber(transport.trackCount) or 0 })
        playCDPlayerManualPlaySound(self)
    end
    return true
end

function CDPlayerWindow:handlePrevButtonActivate()
    if self:canUseTransportButtons() ~= true then
        self:playTransportNoMediaFeedback()
        return true
    end
    local transport = getControlTransportState(self)
    local ok = self:executeUiControl("prev_track", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true and self:shouldPlayPoweredButtonSound(transport) then
        playCDPlayerTransportSound(self, false)
    end
    return true
end

function CDPlayerWindow:handleNextButtonActivate()
    if self:canUseTransportButtons() ~= true then
        self:playTransportNoMediaFeedback()
        return true
    end
    local transport = getControlTransportState(self)
    local ok = self:executeUiControl("next_track", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true and self:shouldPlayPoweredButtonSound(transport) then
        playCDPlayerTransportSound(self, false)
    end
    return true
end

function CDPlayerWindow:adjustVolumeByStep(stepPct)
    local transport = getControlTransportState(self)
    local currentPct = volumeToPercent(transport and transport.volume or 1.0)
    local nextPct = math.max(0, math.min(100, currentPct + math.floor(tonumber(stepPct) or 0)))
    local shouldPlaySound = self:shouldPlayPoweredButtonSound(transport)
    if nextPct == currentPct then
        if shouldPlaySound then
            playCDPlayerVolumeClick(self)
        end
        return true
    end
    local nextVolume = clamp01(nextPct / 100.0)
    local ok = self:executeUiControl("set_volume", { volume = nextVolume })
    if ok == true and shouldPlaySound then
        playCDPlayerVolumeClick(self)
    end
    return true
end

function CDPlayerWindow:handleClusterButtonActivate(kind)
    if self:isUiControlLockedByHold(kind) then
        return true
    end
    if kind == "prev" then
        return self:handlePrevButtonActivate()
    end
    if kind == "next" then
        return self:handleNextButtonActivate()
    end
    if kind == "vol_up" then
        return self:adjustVolumeByStep(BUTTON_VOLUME_STEP_PCT)
    end
    if kind == "vol_down" then
        return self:adjustVolumeByStep(-BUTTON_VOLUME_STEP_PCT)
    end
    if kind == "play_stop" then
        return self:handlePlayStopActivate()
    end
    if kind == "mode" then
        local transport = getControlTransportState(self)
        local ok = self:executeUiControl("cycle_mode", {})
        if ok == true and self:shouldPlayPoweredButtonSound(transport) then
            playCDPlayerRandomBeep(self)
        end
        return true
    end
    if kind == "power" then
        local transport = getControlTransportState(self)
        local action = transport and transport.isOn == true and "power_off" or "power_on"
        local ok = self:executeUiControl(action, {})
        local shouldPlaySound = self:shouldPlayPoweredButtonSound(transport)
            or (action == "power_on" and transport and transport.hasUsablePower == true)
        if ok == true and shouldPlaySound then
            playCDPlayerRandomBeep(self)
        end
        return true
    end
    if kind == "hold" then
        local transport = getControlTransportState(self)
        local currentlyHeld = transport and transport.isHold == true
        local action = currentlyHeld and "hold_off" or "hold_on"
        local ok = self:executeUiControl(action, {})
        if ok == true then
            self:syncHoldButtonAnimation(false)
            playCDPlayerGenericClick(self, currentlyHeld == true)
        end
        return true
    end
    if kind == "open" then
        return self:handleOpenButtonActivate()
    end
    return true
end

function CDPlayerWindow:getHoldRotationTargetAngle(transport)
    local transportState = transport or getControlTransportState(self)
    if transportState and transportState.isHold == true then
        return HOLD_BUTTON_ANGLE_HELD
    end
    return HOLD_BUTTON_ANGLE_UPRIGHT
end

function CDPlayerWindow:syncHoldButtonAnimation(forceSnap, transport)
    local targetAngle = self:getHoldRotationTargetAngle(transport)
    local currentAngle = tonumber(self._nmHoldButtonAngle)
    if currentAngle == nil then
        currentAngle = targetAngle
    end

    if forceSnap == true then
        self._nmHoldButtonAngle = targetAngle
        self._nmHoldButtonTargetAngle = targetAngle
        self._nmHoldButtonAnimStartAngle = targetAngle
        self._nmHoldButtonAnimStartTime = nil
        self._nmHoldButtonAnimating = false
        return
    end

    local currentTarget = tonumber(self._nmHoldButtonTargetAngle)
    if currentTarget == nil then
        self._nmHoldButtonAngle = currentAngle
        self._nmHoldButtonTargetAngle = targetAngle
        self._nmHoldButtonAnimStartAngle = currentAngle
        self._nmHoldButtonAnimStartTime = nil
        self._nmHoldButtonAnimating = false
        return
    end

    if math.abs(currentTarget - targetAngle) <= 0.001 then
        return
    end

    self._nmHoldButtonAngle = currentAngle
    self._nmHoldButtonTargetAngle = targetAngle
    self._nmHoldButtonAnimStartAngle = currentAngle
    self._nmHoldButtonAnimStartTime = getNowMs()
    self._nmHoldButtonAnimating = true
end
