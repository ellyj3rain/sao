-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "ui/shared/host/NMFancyWindowTooltipHost"

local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

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

local function getScaleTextureKey()
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey then
        return NMFancyDeviceUiScale.getTextureScaleKey()
    end
    return "1x"
end

local function getLoopIconTextureForPath(cacheName, path)
    local cacheKey = tostring(cacheName or "") .. "|" .. getScaleTextureKey()
    UI_TEXTURES[cacheKey] = UI_TEXTURES[cacheKey] or nil
    if UI_TEXTURES[cacheKey] == nil then
        UI_TEXTURES[cacheKey] = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTexture
            and NMFancyDeviceUiScale.getTexture(path)
            or getTexture and getTexture(path)
            or false
    end
    if UI_TEXTURES[cacheKey] == false then
        return nil
    end
    return UI_TEXTURES[cacheKey]
end

function WalkmanWindow:getLoopIconTexture(resolved)
    local ctx = resolved or self:resolveContextCached()
    local policy = getLoopPolicy(ctx and ctx.state or nil)
    if policy == "loop_song" then
        return getLoopIconTextureForPath("loopIconSong", LOOP_ICON_SONG_TEXTURE_PATH)
    end
    if policy == "loop_album" then
        return getLoopIconTextureForPath("loopIconAlbum", LOOP_ICON_ALBUM_TEXTURE_PATH)
    end
    return getLoopIconTextureForPath("loopIconNone", LOOP_ICON_NONE_TEXTURE_PATH)
end

function WalkmanWindow:getLoopIconRect(texture)
    local loopRect = self:getLoopButtonRect()
    local tex = texture or self:getLoopIconTexture()
    local texW = tex and tex.getWidthOrig and tex:getWidthOrig() or 39
    local texH = tex and tex.getHeightOrig and tex:getHeightOrig() or 29
    local pad = math.max(1, math.floor((2 * getFancyDeviceUiScale()) + 0.5))
    local maxW = math.max(1, SIDE_W - (pad * 2))
    local maxH = math.max(1, loopRect.h - (pad * 2))
    local fit = math.min(maxW / math.max(1, texW), maxH / math.max(1, texH))
    local w = math.floor((texW * fit) + 0.5)
    local h = math.floor((texH * fit) + 0.5)
    local y = loopRect.y + math.floor(((loopRect.h - h) * 0.5) + 0.5)
    return {
        x = LOOP_ICON_X,
        y = y,
        w = w,
        h = h
    }
end

function WalkmanWindow:getLoopModeTooltip()
    local resolved = self:resolveContextCached()
    local policy = getLoopPolicy(resolved and resolved.state or nil)
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

function WalkmanWindow:getPlayButtonTooltip(transport)
    local transportState = getTransportState(self, transport)
    if NMDeviceUiHost and NMDeviceUiHost.hasCombinedPlayPower and NMDeviceUiHost.hasCombinedPlayPower(self) ~= true then
        if transportState and transportState.isPlaying == true then
            return NMTranslations.ui("StopSong", "Stop Song")
        end
        return NMTranslations.ui("PlaySong", "Play Song")
    end
    if transportState and transportState.isPlaying == true then
        return NMTranslations.ui("WalkmanStopPowerOff", "Stop / Power Off")
    end
    return NMTranslations.ui("WalkmanPlayPowerOn", "Play / Power ON")
end

function WalkmanWindow:getHoverTooltipAt(x, y)
    if pointInRect(x, y, self:getSettingsRect()) then
        return FancySettingsWindow.getSettingsTooltipText()
    end
    if pointInRect(x, y, self:getLoopButtonRect()) then
        return self:getLoopModeTooltip()
    end
    if pointInRect(x, y, self:getPlayButtonHitRect()) then
        return self:getPlayButtonTooltip()
    end
    if pointInRect(x, y, self:getPrevButtonHitRect()) then
        return NMTranslations.ui("PreviousTrack")
    end
    if pointInRect(x, y, self:getNextButtonHitRect()) then
        return NMTranslations.ui("NextTrack")
    end
    return nil
end

function WalkmanWindow:updateHoverTooltip()
    return NMFancyWindowTooltipHost.updateHoverTooltip(self)
end

function WalkmanWindow:getTooltipUiOptions(text)
    local maxLineWidth = 300
    if string.contains and string.contains(tostring(text or ""), "\n") then
        maxLineWidth = 1000
    end
    return {
        maxLineWidth = maxLineWidth,
        offsetY = 24,
        cacheText = true,
    }
end

function WalkmanWindow:updateTooltipUI()
    return NMFancyWindowTooltipHost.updateTooltipUi(self)
end

function WalkmanWindow:startPlayButtonAnimation(down)
    local targetY = self:getPlayButtonY(down)
    local currentY = tonumber(self.playButtonCurrentY) or self:getPlayButtonY(self.isPlayButtonDown)
    self.isPlayButtonDown = (down == true)
    if currentY == targetY then
        self.isPlayButtonAnimating = false
        self.playButtonCurrentY = targetY
        return
    end
    self.isPlayButtonAnimating = true
    self.playButtonAnimStartY = currentY
    self.playButtonAnimTargetY = targetY
    self.playButtonAnimStartTime = getNowMs()
end

function WalkmanWindow:canUseTransportButtons()
    return self:hasInsertedCassette() == true
end

local function hasUsablePower(resolved)
    local ctx = resolved
    local state = ctx and ctx.state or nil
    if not state then
        return false
    end
    if state.batteryPresent == nil then
        return true
    end
    return state.batteryPresent == true and (tonumber(state.batteryCharge) or 0) > 0
end

function WalkmanWindow:canUsePlayPowerButton(resolved)
    if self:hasInsertedCassette() ~= true then
        return false
    end
    return hasUsablePower(resolved or self:resolveContextCached()) == true
end

function WalkmanWindow:playTransportNoMediaFeedback()
    playWalkmanTransportSound(self, false)
end

function WalkmanWindow:startPlayButtonTap()
    if self.isPlayButtonAnimating == true then
        return
    end
    self.isPlayButtonAnimating = true
    self.playButtonPhase = "down"
    self.playButtonAnimStartY = tonumber(self.playButtonCurrentY) or self:getPlayButtonY(false)
    self.playButtonAnimTargetY = self:getPlayButtonY(true)
    self.playButtonAnimStartTime = getNowMs()
end

function WalkmanWindow:handlePlayButtonActivate()
    local resolved = self:resolveContextCached()
    if self:canUsePlayPowerButton(resolved) ~= true then
        self:playTransportNoMediaFeedback()
        self:startPlayButtonTap()
        return true
    end
    local transport = getControlTransportState(self, nil, resolved)
    local action = transport and transport.isPlaying == true and "stop" or "play"
    local ok = self:executeUiControl(action, {
        trackCount = tonumber(transport and transport.trackCount) or 0
    })
    if ok == true then
        self:syncPlayButtonFromTransport(nil, true, false)
    end
    return true
end

function WalkmanWindow:handlePrevButtonActivate()
    if self:canUseTransportButtons() ~= true then
        self:playTransportNoMediaFeedback()
        self:startPrevButtonPress()
        return true
    end
    local transport = getControlTransportState(self)
    local ok = self:executeUiControl("prev_track", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true then
        playWalkmanTransportSound(self, false)
        self:startPrevButtonPress()
    end
    return true
end

function WalkmanWindow:handleNextButtonActivate()
    if self:canUseTransportButtons() ~= true then
        self:playTransportNoMediaFeedback()
        self:startNextButtonPress()
        return true
    end
    local transport = getControlTransportState(self)
    local ok = self:executeUiControl("next_track", { trackCount = tonumber(transport and transport.trackCount) or 0 })
    if ok == true then
        playWalkmanTransportSound(self, false)
        self:startNextButtonPress()
    end
    return true
end

function WalkmanWindow:buildTransportState(resolved)
    local ctx = resolved or self:resolveContextCached()
    local state = ctx and ctx.state or nil
    return {
        isPlaying = state and state.isPlaying == true,
        isOn = state and state.isOn == true,
        trackCount = resolveTrackCount(state),
        playbackPolicy = getLoopPolicy(state),
        volume = clamp01(state and state.volume or 1.0),
    }
end

function WalkmanWindow:syncPlayButtonFromTransport(resolved, transportOrPlaySound, playSoundOrSnap, snap)
    local explicitTransport = nil
    local playSound = playSoundOrSnap
    if type(transportOrPlaySound) == "table" then
        explicitTransport = transportOrPlaySound
    else
        playSound = transportOrPlaySound
        snap = playSoundOrSnap
    end
    local transportState = getControlTransportState(self, explicitTransport, resolved)
    local shouldBeDown = transportState and transportState.isPlaying == true
    local hasObserved = self._nmHasObservedPlayState == true
    local previous = self._nmAuthoritativePlayDown == true

    self._nmAuthoritativePlayDown = shouldBeDown
    self._nmHasObservedPlayState = true

    if (not hasObserved) or snap == true then
        self.isPlayButtonDown = shouldBeDown
        self.isPlayButtonAnimating = false
        self.playButtonAnimStartY = nil
        self.playButtonAnimTargetY = nil
        self.playButtonAnimStartTime = nil
        self.playButtonCurrentY = self:getPlayButtonY(shouldBeDown)
        return transportState
    end

    if previous ~= shouldBeDown then
        self:startPlayButtonAnimation(shouldBeDown)
        if playSound ~= false then
            playWalkmanTransportSound(self, not shouldBeDown)
        end
    elseif self.isPlayButtonAnimating ~= true then
        self.isPlayButtonDown = shouldBeDown
        self.playButtonCurrentY = self:getPlayButtonY(shouldBeDown)
    end

    return transportState
end

function WalkmanWindow:startPrevButtonPress()
    if self.isPrevButtonAnimating == true then
        return
    end
    self.isPrevButtonAnimating = true
    self.prevButtonPhase = "down"
    self.prevButtonAnimStartY = tonumber(self.prevButtonCurrentY) or self:getPrevButtonY(false)
    self.prevButtonAnimTargetY = self:getPrevButtonY(true)
    self.prevButtonAnimStartTime = getNowMs()
end

function WalkmanWindow:startNextButtonPress()
    if self.isNextButtonAnimating == true then
        return
    end
    self.isNextButtonAnimating = true
    self.nextButtonPhase = "down"
    self.nextButtonAnimStartY = tonumber(self.nextButtonCurrentY) or self:getNextButtonY(false)
    self.nextButtonAnimTargetY = self:getNextButtonY(true)
    self.nextButtonAnimStartTime = getNowMs()
end

function WalkmanWindow:startLoopButtonPress()
    if self.isLoopButtonAnimating == true then
        return
    end
    self.isLoopButtonAnimating = true
    self.loopButtonPhase = "down"
    self.loopButtonAnimStartX = tonumber(self.loopButtonCurrentX) or self:getLoopButtonX(false)
    self.loopButtonAnimTargetX = self:getLoopButtonX(true)
    self.loopButtonAnimStartTime = getNowMs()
end

