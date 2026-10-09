-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMGamepadRadial = NMGamepadRadial or {}
require "ui/shared/slots/NMPortableUiSoundContract"
NMGamepadRadial.hookInstalled = NMGamepadRadial.hookInstalled or false
NMGamepadRadial.baseOnDisplayDown = NMGamepadRadial.baseOnDisplayDown or nil
NMGamepadRadial.wrapperFn = NMGamepadRadial.wrapperFn or nil
NMGamepadRadial.nextHookAttemptMs = NMGamepadRadial.nextHookAttemptMs or 0

local function playWindowSound(ownerName, helperName, window, argument)
    local owner = rawget(_G, ownerName)
    local helper = type(owner) == "table" and rawget(owner, helperName) or nil
    if type(helper) == "function" then helper(window, argument) end
end

local GAMEPAD_TEXTURE_ROOT = "media/textures/UI/Gamepad/"
local VOLUME_STEP_PCT = 5
local NM_RADIAL_ACTION = {
    volume_up = "volume_up",
    play_stop = "play_stop",
    next = "next",
    insert = "insert",
    eject = "eject",
    volume_down = "volume_down",
    mode = "mode",
    prev = "prev",
    close = "close"
}

local function nowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function getMenuForPlayer(playerNum)
    return getPlayerRadialMenu and getPlayerRadialMenu(playerNum) or nil
end

local function getTextureSafe(path)
    if not (path and getTexture) then
        return nil
    end
    return getTexture(path)
end

local function radialTexture(fileName)
    return getTextureSafe(GAMEPAD_TEXTURE_ROOT .. tostring(fileName or ""))
end

local function radialLabel(uiKey, fallback)
    if NMTranslations and NMTranslations.ui then
        return NMTranslations.ui(uiKey, fallback)
    end
    return tostring(fallback or "")
end

local function isWindowVisible(window)
    if not (window and window.javaObject) then
        return false
    end
    if window.getIsVisible then
        return window:getIsVisible() == true
    end
    if window.isVisible then
        return window:isVisible() == true
    end
    return true
end

local function getActiveEntry(playerNum)
    if not NMGamepadWindowTracker or not NMGamepadWindowTracker.getActiveEntry then
        return nil
    end
    local entry = NMGamepadWindowTracker.getActiveEntry(playerNum)
    if not (entry and isWindowVisible(entry.window)) then
        return nil
    end
    return entry
end

local function centerMenu(menu, playerNum)
    if not menu then
        return
    end
    menu:setX(getPlayerScreenLeft(playerNum) + getPlayerScreenWidth(playerNum) / 2 - menu:getWidth() / 2)
    menu:setY(getPlayerScreenTop(playerNum) + getPlayerScreenHeight(playerNum) / 2 - menu:getHeight() / 2)
end

local function getResolvedContext(window)
    if not window then
        return nil
    end
    if window.resolveContextCached then
        return window:resolveContextCached()
    end
    return window.resolveContext and window:resolveContext() or nil
end

local function getFreshResolvedContext(window)
    if not window then
        return nil
    end
    if window.resolveContextFresh then
        return window:resolveContextFresh()
    end
    return getResolvedContext(window)
end

local function resolveTrackCount(state)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return 0
    end
    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" then
        return 0
    end
    return #resolved.tracks
end

local function playGenericButtonClick(window)
    if NMTransportButtonRow and NMTransportButtonRow.playButtonClick then
        NMTransportButtonRow.playButtonClick(window)
        return
    end
    NMPortableUiSoundContract.playTransportPress(window)
end

local function playGenericPowerClick(window, isTurningOn)
    if NMPowerButton and NMPowerButton.playPowerClick then
        NMPowerButton.playPowerClick(window, isTurningOn == true)
        return
    end
    NMPortableUiSoundContract.playPowerPress(window, isTurningOn == true)
end

local function getWalkmanModeIcon(policy)
    local current = tostring(policy or "autoplay")
    if current == "loop_song" then
        return radialTexture("UI_NM_Mode_LoopSong.png")
    end
    if current == "loop_album" then
        return radialTexture("UI_NM_Mode_LoopAlbum.png")
    end
    return radialTexture("UI_NM_Mode_AutoOff.png")
end

local function getModeIcon(policy, allowShuffle)
    local current = tostring(policy or "autoplay")
    if current == "loop_song" then
        return radialTexture("UI_NM_Mode_LoopSong.png")
    end
    if current == "loop_album" then
        return radialTexture("UI_NM_Mode_LoopAlbum.png")
    end
    if allowShuffle == true and current == "shuffle" then
        return radialTexture("UI_NM_Mode_Shuffle.png")
    end
    return radialTexture("UI_NM_Mode_AutoOff.png")
end

local function getModeLabel(policy, allowShuffle)
    local current = tostring(policy or "autoplay")
    if NMTranslations and NMTranslations.modeTooltip then
        if current == "loop_song" then
            return NMTranslations.modeTooltip("LoopSong")
        end
        if current == "loop_album" then
            return NMTranslations.modeTooltip("LoopAlbum")
        end
        if allowShuffle == true and current == "shuffle" then
            return NMTranslations.modeTooltip("Shuffle")
        end
        return NMTranslations.modeTooltip("AutoOff")
    end
    if current == "loop_song" then
        return radialLabel("ModeLoopSong")
    end
    if current == "loop_album" then
        return radialLabel("ModeLoopAlbum")
    end
    if allowShuffle == true and current == "shuffle" then
        return radialLabel("ModeShuffle")
    end
    return radialLabel("ModeAutoOff")
end

local function getGenericControlState(window)
    local resolved = getFreshResolvedContext(window)
    return resolved and resolved.state or nil, resolved
end

local function getControlTransportState(window)
    if not window then
        return nil
    end
    local resolved = getFreshResolvedContext(window)
    return NMDeviceUiHost and NMDeviceUiHost.resolveControlTransportState and NMDeviceUiHost.resolveControlTransportState(window, {
        resolved = resolved,
    }) or (window.buildTransportState and window:buildTransportState(resolved) or nil)
end

local function getMediaSlotButton(window)
    return window and window.mediaSlot and window.mediaSlot.button or nil
end

local function activeWindowHasMedia(entry)
    local family = tostring(entry and entry.family or "")
    local window = entry and entry.window or nil
    if not window then
        return false
    end
    if family == "walkman" then
        return window.hasInsertedCassette and window:hasInsertedCassette() == true or false
    end
    if family == "cdplayer" then
        return window.hasInsertedMedia and window:hasInsertedMedia() == true or false
    end
    if family == "boombox" then
        return window.hasInsertedCassette and window:hasInsertedCassette() == true or false
    end
    local state = getGenericControlState(window)
    return tostring(state and (state.mediaEjectFullType or state.mediaFullType) or "") ~= ""
end

local function showInsertMenu(window)
    local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
    local showInsertContextFn = mediaEnv and mediaEnv.showMediaInsertContextMenu or nil
    local slotButton = getMediaSlotButton(window)
    if not (showInsertContextFn and slotButton) then
        return false
    end
    return showInsertContextFn(window, slotButton, 0, 0, { autoOpenSubMenuForJoypad = true }) == true
end

local function isPlaybackActive(entry)
    local family = tostring(entry and entry.family or "")
    local window = entry and entry.window or nil
    if not window then
        return false
    end
    if family == "walkman" or family == "cdplayer" or family == "boombox" then
        local transport = getControlTransportState(window)
        return transport and transport.isPlaying == true or false
    end
    local state = getGenericControlState(window)
    return state and state.isPlaying == true or false
end

local function getPlayStopSliceText(entry)
    if isPlaybackActive(entry) == true then
        return radialLabel("StopSong", "Stop Song")
    end
    return radialLabel("PlaySong", "Play Song")
end

local function getPlayStopSliceTexture(entry)
    if isPlaybackActive(entry) == true then
        return radialTexture("UI_NM_Stop.png")
    end
    return radialTexture("UI_NM_Play.png")
end

local function markWindowInteraction(window, family)
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(window, family)
    end
end

local function handleWalkmanMode(window)
    local resolved = window and window.resolveContextCached and window:resolveContextCached() or nil
    local state = resolved and resolved.state or nil
    local current = tostring((state and state.playbackPolicy) or "autoplay")
    local nextPolicy = "autoplay"
    if current == "autoplay" then
        nextPolicy = "loop_song"
    elseif current == "loop_song" then
        nextPolicy = "loop_album"
    else
        nextPolicy = "autoplay"
    end
    local ok = window:executeUiControl("cycle_mode", { playbackPolicy = nextPolicy })
    if ok == true then
        if type(rawget(_G, "NMWalkmanWindowEnv")) == "table" then
            playWindowSound("NMWalkmanWindowEnv", "playWalkmanTransportSound", window, false)
        end
        if window.startLoopButtonPress then
            window:startLoopButtonPress()
        end
        if window.updateLoopIconVisibility then
            window:updateLoopIconVisibility()
        end
    end
    return ok == true
end

local function handleWalkmanAction(window, action)
    if action == NM_RADIAL_ACTION.volume_up then
        window:adjustVolumeWheelByStep(VOLUME_STEP_PCT)
        return true
    end
    if action == NM_RADIAL_ACTION.volume_down then
        window:adjustVolumeWheelByStep(-VOLUME_STEP_PCT)
        return true
    end
    if action == NM_RADIAL_ACTION.play_stop then
        return window:handlePlayButtonActivate() == true
    end
    if action == NM_RADIAL_ACTION.next then
        return window:handleNextButtonActivate() == true
    end
    if action == NM_RADIAL_ACTION.prev then
        return window:handlePrevButtonActivate() == true
    end
    if action == NM_RADIAL_ACTION.mode then
        return handleWalkmanMode(window)
    end
    if action == NM_RADIAL_ACTION.eject then
        if window.hasInsertedCassette and window:hasInsertedCassette() == true and window.ejectMediaViaLid then
            return window:ejectMediaViaLid() == true
        end
        return false
    end
    if action == NM_RADIAL_ACTION.insert then
        return showInsertMenu(window)
    end
    if action == NM_RADIAL_ACTION.close then
        if window.close then
            window:close()
            return true
        end
        return false
    end
    return false
end

local function handleCDPlayerPlayStop(window)
    local transport = getControlTransportState(window)
    local trackCount = tonumber(transport.trackCount) or 0
    if transport.isPlaying == true then
        local stopped = window:executeUiControl("stop", { trackCount = trackCount })
        if stopped == true and type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then
            playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerTransportSound", window, true)
        end
        if transport.isOn == true then
            local poweredOff = window:executeUiControl("power_off", {})
            if poweredOff == true and type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then
                playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerRandomBeep", window)
            end
        end
        return stopped == true
    end
    if transport.isOn ~= true then
        local poweredOn = window:executeUiControl("power_on", {})
        if poweredOn == true and type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then
            playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerRandomBeep", window)
        end
    end
    local started = window:executeUiControl("play", { trackCount = trackCount })
    if started == true and type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then
        playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerManualPlaySound", window)
    end
    return started == true
end

local function handleCDPlayerMode(window)
    if window.startButtonPulse then
        window:startButtonPulse("mode")
    end
    return window:handleClusterButtonActivate("mode") == true
end

local function handleCDPlayerAction(window, action)
    if action == NM_RADIAL_ACTION.volume_up then
        if window.startButtonPulse then
            window:startButtonPulse("vol_up")
        end
        return window:adjustVolumeByStep(VOLUME_STEP_PCT) == true
    end
    if action == NM_RADIAL_ACTION.volume_down then
        if window.startButtonPulse then
            window:startButtonPulse("vol_down")
        end
        return window:adjustVolumeByStep(-VOLUME_STEP_PCT) == true
    end
    if action == NM_RADIAL_ACTION.play_stop then
        if window.startButtonPulse then
            window:startButtonPulse("play_stop")
            window:startButtonPulse("power")
        end
        return handleCDPlayerPlayStop(window)
    end
    if action == NM_RADIAL_ACTION.next then
        if window.startButtonPulse then
            window:startButtonPulse("next")
        end
        return window:handleNextButtonActivate() == true
    end
    if action == NM_RADIAL_ACTION.prev then
        if window.startButtonPulse then
            window:startButtonPulse("prev")
        end
        return window:handlePrevButtonActivate() == true
    end
    if action == NM_RADIAL_ACTION.mode then
        return handleCDPlayerMode(window)
    end
    if action == NM_RADIAL_ACTION.eject then
        if window.startButtonPulse then
            window:startButtonPulse("open")
        end
        if window.hasInsertedMedia and window:hasInsertedMedia() == true then
            if window.isLidOpen == true and window.ejectOpenLidMediaViaAux then
                return window:ejectOpenLidMediaViaAux("gamepad_radial") == true
            end
            if window.ejectClosedSlotMedia then
                return window:ejectClosedSlotMedia("gamepad_radial") == true
            end
        end
        return window:handleOpenButtonActivate() == true
    end
    if action == NM_RADIAL_ACTION.insert then
        if window.startButtonPulse then
            window:startButtonPulse("open")
        end
        return showInsertMenu(window)
    end
    if action == NM_RADIAL_ACTION.close then
        if window.close then
            window:close()
            return true
        end
        return false
    end
    return false
end

local function handleBoomboxAction(window, action)
    if action == NM_RADIAL_ACTION.volume_up then
        return window.adjustVolumeByStep and window:adjustVolumeByStep(VOLUME_STEP_PCT) == true or false
    end
    if action == NM_RADIAL_ACTION.volume_down then
        return window.adjustVolumeByStep and window:adjustVolumeByStep(-VOLUME_STEP_PCT) == true or false
    end
    if action == NM_RADIAL_ACTION.play_stop then
        local transport = getControlTransportState(window)
        if transport and transport.isPlaying == true then
            return window.handleStopTrigger and window:handleStopTrigger(false) == true or false
        end
        return window.handleManualPlayTrigger and window:handleManualPlayTrigger(false) == true or false
    end
    if action == NM_RADIAL_ACTION.next then
        return window.handleNextTrigger and window:handleNextTrigger(false) == true or false
    end
    if action == NM_RADIAL_ACTION.prev then
        return window.handlePrevTrigger and window:handlePrevTrigger(false) == true or false
    end
    if action == NM_RADIAL_ACTION.mode then
        local selected = window.getSelectedModeIndex and window:getSelectedModeIndex() or nil
        local nextIndex = (tonumber(selected) or 0) + 1
        if nextIndex > 3 then
            nextIndex = 1
        end
        return window.handleModeTrigger and window:handleModeTrigger(nextIndex) == true or false
    end
    if action == NM_RADIAL_ACTION.eject then
        return window.handleEjectTrigger and window:handleEjectTrigger() == true or false
    end
    if action == NM_RADIAL_ACTION.insert then
        return showInsertMenu(window)
    end
    if action == NM_RADIAL_ACTION.close then
        if window.close then
            window:close()
            return true
        end
        return false
    end
    return false
end

local function flickGenericButton(window, index)
    local buttons = window and window.transportRow and window.transportRow.buttons or nil
    local btn = buttons and buttons[index] or nil
    if btn then
        btn._nmFlickUntil = nowMs() + 250
    end
end

local function handleGenericPlayStop(window)
    local state = getGenericControlState(window)
    local trackCount = resolveTrackCount(state)
    local isPlaying = state and state.isPlaying == true
    local isOn = state and state.isOn == true
    if isPlaying == true then
        local stopped = window:executeUiControl("stop", { trackCount = trackCount })
        if stopped == true then
            playGenericButtonClick(window)
            if isOn == true then
                local poweredOff = window:executeUiControl("power_off", {})
                if poweredOff == true then
                    playGenericPowerClick(window, false)
                end
            end
        end
        return stopped == true
    end
    if isOn ~= true then
        local poweredOn = window:executeUiControl("power_on", {})
        if poweredOn == true then
            playGenericPowerClick(window, true)
        end
    end
    local started = window:executeUiControl("play", { trackCount = trackCount })
    if started == true then
        playGenericButtonClick(window)
    end
    return started == true
end

local function handleGenericMode(window)
    local state = getGenericControlState(window)
    local current = tostring(state and state.playbackPolicy or "autoplay")
    local nextPolicy = "autoplay"
    if current == "autoplay" then
        nextPolicy = "loop_song"
    elseif current == "loop_song" then
        nextPolicy = "loop_album"
    elseif current == "loop_album" then
        nextPolicy = "shuffle"
    else
        nextPolicy = "autoplay"
    end
    local ok = window:executeUiControl("cycle_mode", { playbackPolicy = nextPolicy })
    if ok == true then
        playGenericButtonClick(window)
        flickGenericButton(window, 1)
    end
    return ok == true
end

local function handleGenericVolume(window, stepPct)
    local state = getGenericControlState(window)
    local currentPct = math.floor(((tonumber(state and state.volume) or 1.0) * 100) + 0.5)
    local nextPct = math.max(0, math.min(100, currentPct + math.floor(tonumber(stepPct) or 0)))
    local nextVolume = math.max(0.0, math.min(1.0, nextPct / 100.0))
    local ok = window:executeUiControl("set_volume", { volume = nextVolume })
    if ok == true then
        playGenericButtonClick(window)
    end
    return ok == true
end

local function handleGenericAction(window, action)
    if action == NM_RADIAL_ACTION.volume_up then
        return handleGenericVolume(window, VOLUME_STEP_PCT)
    end
    if action == NM_RADIAL_ACTION.volume_down then
        return handleGenericVolume(window, -VOLUME_STEP_PCT)
    end
    if action == NM_RADIAL_ACTION.play_stop then
        return handleGenericPlayStop(window)
    end
    if action == NM_RADIAL_ACTION.next then
        local state = getGenericControlState(window)
        local ok = window:executeUiControl("next_track", { trackCount = resolveTrackCount(state) })
        if ok == true then
            playGenericButtonClick(window)
            flickGenericButton(window, 5)
        end
        return ok == true
    end
    if action == NM_RADIAL_ACTION.prev then
        local state = getGenericControlState(window)
        local ok = window:executeUiControl("prev_track", { trackCount = resolveTrackCount(state) })
        if ok == true then
            playGenericButtonClick(window)
            flickGenericButton(window, 4)
        end
        return ok == true
    end
    if action == NM_RADIAL_ACTION.mode then
        return handleGenericMode(window)
    end
    if action == NM_RADIAL_ACTION.eject then
        local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
        local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
        if not queueMediaSlotEjectFn then
            return false
        end
        local ok = queueMediaSlotEjectFn(window, "gamepad_radial") == true
        if ok == true then
            playGenericButtonClick(window)
        end
        return ok
    end
    if action == NM_RADIAL_ACTION.insert then
        return showInsertMenu(window)
    end
    if action == NM_RADIAL_ACTION.close then
        if window.close then
            window:close()
            return true
        end
        return false
    end
    return false
end

local function onRadialAction(action, playerNum, family, window)
    if not (window and isWindowVisible(window)) then
        return
    end
    markWindowInteraction(window, family)
    if family == "walkman" then
        handleWalkmanAction(window, action)
        return
    end
    if family == "cdplayer" then
        handleCDPlayerAction(window, action)
        return
    end
    if family == "boombox" then
        handleBoomboxAction(window, action)
        return
    end
    if family == "generic" then
        handleGenericAction(window, action)
    end
end

local function buildModeSlice(menu, entry)
    local family = tostring(entry and entry.family or "")
    local window = entry and entry.window or nil
    if not window then
        return
    end
    if family == "walkman" then
        local transport = getControlTransportState(window)
        local policy = transport and transport.playbackPolicy or "autoplay"
        local icon = getWalkmanModeIcon(transport and transport.playbackPolicy or "autoplay")
        menu:addSlice(getModeLabel(policy, false), icon, onRadialAction, NM_RADIAL_ACTION.mode, window.playerNum, family, window)
        return
    end
    if family == "cdplayer" then
        local transport = getControlTransportState(window)
        local policy = transport and transport.playbackPolicy or "autoplay"
        local icon = getModeIcon(policy, true)
        menu:addSlice(getModeLabel(policy, true), icon, onRadialAction, NM_RADIAL_ACTION.mode, window.playerNum, family, window)
        return
    end
    if family == "boombox" then
        local transport = getControlTransportState(window)
        local policy = transport and transport.playbackPolicy or "autoplay"
        local icon = getModeIcon(policy, true)
        menu:addSlice(getModeLabel(policy, true), icon, onRadialAction, NM_RADIAL_ACTION.mode, window.playerNum, family, window)
        return
    end
    local state = getGenericControlState(window)
    local policy = state and state.playbackPolicy or "autoplay"
    local icon = getModeIcon(policy, true)
    menu:addSlice(getModeLabel(policy, true), icon, onRadialAction, NM_RADIAL_ACTION.mode, window.playerNum, family, window)
end

local function installTapCollapseHandler(menu, entry)
    if not menu then
        return
    end
    local baseFn = menu._nmTapCollapseBaseOnJoypadButtonReleased or menu.onJoypadButtonReleased
    menu._nmTapCollapseBaseOnJoypadButtonReleased = baseFn
    menu._nmTapCollapseEntry = entry
    menu._nmTapCollapseEnabled = true
    menu.onJoypadButtonReleased = function(self, button, joypadData)
        if self._nmTapCollapseEnabled == true
            and self.hideWhenButtonReleased == Joypad.DPadDown
            and button == Joypad.DPadDown then
            self._nmTapCollapseEnabled = false
            self:undisplay()
            local joyfocus = self.joyfocus
            local joypadId = joyfocus and joyfocus.id or nil
            local sliceIndex = self.javaObject and joypadId and self.javaObject:getSliceIndexFromJoypad(joypadId) or -1
            local command = self:getSliceCommand((tonumber(sliceIndex) or -1) + 1)
            if command and command[1] then
                command[1](command[2], command[3], command[4], command[5], command[6], command[7])
                return
            end
            local collapseEntry = self._nmTapCollapseEntry
            local family = tostring(collapseEntry and collapseEntry.family or "")
            local window = collapseEntry and collapseEntry.window or nil
            if (family == "walkman" or family == "cdplayer" or family == "boombox")
                and window
                and isWindowVisible(window)
                and window.toggleCollapsed then
                markWindowInteraction(window, family)
                window:toggleCollapsed()
            end
            return
        end
        if type(baseFn) == "function" then
            return baseFn(self, button, joypadData)
        end
    end
end

local function openRadialForEntry(playerNum, entry)
    local playerObj = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    if not (playerObj and entry and entry.window and isWindowVisible(entry.window)) then
        return false
    end
    local menu = getMenuForPlayer(playerNum)
    if not menu then
        return false
    end
    local family = tostring(entry.family or "")
    local window = entry.window
    local hasMedia = activeWindowHasMedia(entry)
    menu:clear()
    menu:addSlice(radialLabel("VolumeUp", "Volume Up"), radialTexture("UI_NM_Volume_Up.png"), onRadialAction, NM_RADIAL_ACTION.volume_up, playerNum, family, window)
    menu:addSlice(getPlayStopSliceText(entry), getPlayStopSliceTexture(entry), onRadialAction, NM_RADIAL_ACTION.play_stop, playerNum, family, window)
    menu:addSlice(radialLabel("NextTrack", "Next Track"), radialTexture("UI_NM_Next.png"), onRadialAction, NM_RADIAL_ACTION.next, playerNum, family, window)
    if hasMedia == true then
        menu:addSlice(radialLabel("EjectMedia", "Eject Media"), radialTexture("UI_NM_Eject.png"), onRadialAction, NM_RADIAL_ACTION.eject, playerNum, family, window)
    else
        menu:addSlice(radialLabel("InsertMedia", "Insert Media"), radialTexture("UI_NM_Insert.png"), onRadialAction, NM_RADIAL_ACTION.insert, playerNum, family, window)
    end
    menu:addSlice(radialLabel("VolumeDown", "Volume Down"), radialTexture("UI_NM_Volume_Down.png"), onRadialAction, NM_RADIAL_ACTION.volume_down, playerNum, family, window)
    buildModeSlice(menu, entry)
    menu:addSlice(radialLabel("PreviousTrack", "Previous Track"), radialTexture("UI_NM_Prev.png"), onRadialAction, NM_RADIAL_ACTION.prev, playerNum, family, window)
    menu:addSlice(NMTranslations.text("UI_Close", "Close"), radialTexture("UI_NM_Close.png"), onRadialAction, NM_RADIAL_ACTION.close, playerNum, family, window)
    if menu:isEmpty() then
        return false
    end
    installTapCollapseHandler(menu, entry)
    centerMenu(menu, playerNum)
    menu:addToUIManager()
    menu:setHideWhenButtonReleased(Joypad.DPadDown)
    setJoypadFocus(playerNum, menu)
    playerObj:setJoypadIgnoreAimUntilCentered(true)
    return true
end

local function ensureWrapperFunction()
    if NMGamepadRadial.wrapperFn then
        return NMGamepadRadial.wrapperFn
    end
    NMGamepadRadial.wrapperFn = function(joypadData)
        local playerNum = joypadData and joypadData.player or nil
        local entry = playerNum ~= nil and getActiveEntry(playerNum) or nil
        if entry and openRadialForEntry(playerNum, entry) == true then
            return
        end
        local baseFn = NMGamepadRadial.baseOnDisplayDown
        if type(baseFn) == "function" then
            baseFn(joypadData)
        end
    end
    return NMGamepadRadial.wrapperFn
end

function NMGamepadRadial.installHook()
    if NMGamepadRadial.hookInstalled == true then
        return true
    end
    local currentMs = nowMs()
    local nextAttemptMs = tonumber(NMGamepadRadial.nextHookAttemptMs) or 0
    if currentMs > 0 and currentMs < nextAttemptMs then
        return false
    end
    NMGamepadRadial.nextHookAttemptMs = currentMs + 2000
    if not ISDPadWheels or type(ISDPadWheels.onDisplayDown) ~= "function" then
        return false
    end
    local wrapper = ensureWrapperFunction()
    local current = ISDPadWheels.onDisplayDown
    if current == wrapper then
        NMGamepadRadial.hookInstalled = true
        return true
    end
    if NMGamepadRadial.baseOnDisplayDown then
        return false
    end
    NMGamepadRadial.baseOnDisplayDown = current
    ISDPadWheels.onDisplayDown = wrapper
    NMGamepadRadial.hookInstalled = ISDPadWheels.onDisplayDown == wrapper
    return NMGamepadRadial.hookInstalled
end
