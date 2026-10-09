require "PZAPI/ModOptions"

NMClientModOptions = NMClientModOptions or {}

local MOD_OPTIONS_ID = "newmusic"
local OPTION_ID_MASTER_VOLUME = "masterVolume"
local OPTION_DEFAULT_MASTER_VOLUME = 1.0
local OPTION_ID_SPATIAL_AUDIO = "spatialAudio"
local OPTION_DEFAULT_SPATIAL_AUDIO = true
local OPTION_ID_SHOW_TRACK_NUMBER_PREFIX = "showTrackNumberPrefix"
local OPTION_DEFAULT_SHOW_TRACK_NUMBER_PREFIX = true
local OPTION_ID_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK = "muteGameSoundtrackDuringPlayback"
local OPTION_DEFAULT_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK = true
local OPTION_ID_FANCY_UI = "fancyUI"
local OPTION_DEFAULT_FANCY_UI = true
local OPTION_ID_LEGACY_FANCY_DEVICE_UI_SCALE = "fancyDeviceUiScale"
local OPTION_ID_LEGACY_FANCY_DEVICE_UI_SCALE_V2 = "fancyDeviceUiScaleV2"
local OPTION_ID_FANCY_DEVICE_UI_SCALE = "fancyDeviceUiScaleV3"
local OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE = 1.0
local UI_SCALE_CHOICES = { 1.0, 1.5, 2.0 }
local UI_SCALE_LABEL_KEY_BY_VALUE = {
    [1.0] = "UI_optionscreen_ActionProgressBarSize1",
    [1.5] = "UI_NM_FancyDeviceUiScale150",
    [2.0] = "UI_optionscreen_ActionProgressBarSize2",
}

local options = nil
local masterVolumeOption = nil
local spatialAudioOption = nil
local showTrackNumberPrefixOption = nil
local muteGameSoundtrackDuringPlaybackOption = nil
local fancyUIOption = nil
local fancyDeviceUiScaleOption = nil

local UI_TEXT_FALLBACKS = {
    WorldPlaybackMaxVolume = "UI_NM_WorldPlaybackMaxVolume",
    NewMusicMasterVolumeTooltip = "UI_NM_NewMusicMasterVolumeTooltip",
    SpatialAudio = "UI_NM_SpatialAudio",
    SpatialAudioTooltip = "UI_NM_SpatialAudioTooltip",
    MuteGameSoundtrackDuringPlayback = "UI_NM_MuteGameSoundtrackDuringPlayback",
    MuteGameSoundtrackDuringPlaybackTooltip = "UI_NM_MuteGameSoundtrackDuringPlaybackTooltip",
}

local function invalidateWindow(win)
    if not win then
        return
    end
    if win.applyCurrentScaleLayout then
        win:applyCurrentScaleLayout()
    end
    if win.invalidateContextCache then
        win:invalidateContextCache()
    end
    if win.invalidateSlotFrameModel then
        win:invalidateSlotFrameModel()
    end
    if win.invalidateRenderModel then
        win:invalidateRenderModel()
    end
end

local function invalidateWindowMap(windowsByPlayer)
    if type(windowsByPlayer) ~= "table" then
        return
    end
    for _, win in pairs(windowsByPlayer) do
        invalidateWindow(win)
    end
end

function NMClientModOptions.invalidateOpenWindows()
    local genericEnv = rawget(_G, "NMDeviceWindowEnv")
    local walkmanEnv = rawget(_G, "NMWalkmanWindowEnv")
    local cdPlayerEnv = rawget(_G, "NMCDPlayerWindowEnv")
    local boomboxEnv = rawget(_G, "NMBoomboxWindowEnv")

    invalidateWindowMap(genericEnv and genericEnv.windowsByPlayer or nil)
    invalidateWindowMap(walkmanEnv and walkmanEnv.windowsByPlayer or nil)
    invalidateWindowMap(cdPlayerEnv and cdPlayerEnv.windowsByPlayer or nil)
    invalidateWindowMap(boomboxEnv and boomboxEnv.windowsByPlayer or nil)
end

function NMClientModOptions.getShowTrackNumberPrefix()
    if showTrackNumberPrefixOption and showTrackNumberPrefixOption.getValue then
        return showTrackNumberPrefixOption:getValue() ~= false
    end
    return OPTION_DEFAULT_SHOW_TRACK_NUMBER_PREFIX
end

function NMClientModOptions.getMuteGameSoundtrackDuringPlayback()
    if muteGameSoundtrackDuringPlaybackOption and muteGameSoundtrackDuringPlaybackOption.getValue then
        return muteGameSoundtrackDuringPlaybackOption:getValue() ~= false
    end
    return OPTION_DEFAULT_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK
end

function NMClientModOptions.getFancyUIEnabled()
    if fancyUIOption and fancyUIOption.getValue then
        return fancyUIOption:getValue() ~= false
    end
    return OPTION_DEFAULT_FANCY_UI
end

function NMClientModOptions.getMasterVolume()
    if masterVolumeOption and masterVolumeOption.getValue then
        local value = tonumber(masterVolumeOption:getValue())
        if value ~= nil then
            return NMCore and NMCore.clamp and NMCore.clamp(value, 0, 1) or math.max(0, math.min(1, value))
        end
    end
    return OPTION_DEFAULT_MASTER_VOLUME
end

local function resolveLegacyFancyUIDefault()
    local page = SandboxVars and SandboxVars.NewMusic or nil
    local value = page and page.FancyUI or nil
    if value == nil then
        return OPTION_DEFAULT_FANCY_UI
    end
    if value == true or value == false then
        return value
    end
    local numeric = tonumber(value)
    if numeric ~= nil then
        return numeric ~= 0
    end
    local text = tostring(value or ""):lower()
    if text == "true" or text == "yes" or text == "on" then
        return true
    end
    if text == "false" or text == "no" or text == "off" then
        return false
    end
    return OPTION_DEFAULT_FANCY_UI
end

local function getUiScaleChoiceIndexForValue(value)
    local target = tonumber(value) or OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE
    for i = 1, #UI_SCALE_CHOICES do
        if math.abs(UI_SCALE_CHOICES[i] - target) < 0.0001 then
            return i
        end
    end
    return 1
end

local function getUiScaleChoiceIndexForPersistedSelection(value)
    local selected = tonumber(value)
    if selected ~= nil and UI_SCALE_CHOICES[selected] ~= nil then
        return selected
    end
    return getUiScaleChoiceIndexForValue(OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE)
end

local function getLegacyFancyDeviceUiScaleSelection()
    local other = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.OtherOptions or nil
    if type(other) ~= "table" then
        return nil
    end
    local marker = "combobox|" .. MOD_OPTIONS_ID .. "|" .. OPTION_ID_LEGACY_FANCY_DEVICE_UI_SCALE .. "|"
    for i = 1, #other do
        local line = tostring(other[i] or "")
        if string.sub(line, 1, #marker) == marker then
            return tonumber(string.sub(line, #marker + 1))
        end
    end
    return nil
end

local function getPersistedFancyDeviceUiScaleSelection(optionId)
    if not getFileReader then
        return nil
    end
    local marker = "combobox|" .. MOD_OPTIONS_ID .. "|" .. tostring(optionId or "") .. "|"
    local ok, file = pcall(getFileReader, "ModOptions.ini", true)
    if not (ok and file) then
        return nil
    end
    while true do
        local line = file:readLine()
        if line == nil then
            file:close()
            return nil
        end
        if string.sub(tostring(line or ""), 1, #marker) == marker then
            file:close()
            return tonumber(string.sub(line, #marker + 1))
        end
    end
end

local function applyLegacyFancyDeviceUiScaleSelectionIfNeeded()
    if not (fancyDeviceUiScaleOption and fancyDeviceUiScaleOption.setValue) then
        return
    end
    if getPersistedFancyDeviceUiScaleSelection(OPTION_ID_FANCY_DEVICE_UI_SCALE) ~= nil then
        return
    end
    if tonumber(fancyDeviceUiScaleOption:getValue()) ~= getUiScaleChoiceIndexForValue(OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE) then
        return
    end
    local persistedV2Selection = getPersistedFancyDeviceUiScaleSelection(OPTION_ID_LEGACY_FANCY_DEVICE_UI_SCALE_V2)
    if persistedV2Selection == 1 then
        fancyDeviceUiScaleOption:setValue(getUiScaleChoiceIndexForValue(1.0))
        return
    end
    if persistedV2Selection == 2 then
        fancyDeviceUiScaleOption:setValue(getUiScaleChoiceIndexForValue(2.0))
        return
    end
    if getLegacyFancyDeviceUiScaleSelection() == 7 then
        fancyDeviceUiScaleOption:setValue(getUiScaleChoiceIndexForValue(2.0))
    end
end

function NMClientModOptions.getFancyDeviceUiScaleMultiplier()
    if fancyDeviceUiScaleOption and fancyDeviceUiScaleOption.getValue then
        local selected = getUiScaleChoiceIndexForPersistedSelection(fancyDeviceUiScaleOption:getValue())
        local resolved = UI_SCALE_CHOICES[selected]
        if resolved ~= nil then
            return resolved
        end
    end
    return OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE
end

local function getUiScaleLabelKey(value)
    return UI_SCALE_LABEL_KEY_BY_VALUE[value] or UI_SCALE_LABEL_KEY_BY_VALUE[OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE]
end

local function clampMasterVolume(value)
    local numeric = tonumber(value)
    if numeric == nil then
        numeric = OPTION_DEFAULT_MASTER_VOLUME
    end
    if NMCore and NMCore.clamp then
        return NMCore.clamp(numeric, 0, 1)
    end
    return math.max(0, math.min(1, numeric))
end

local function resolveUiText(key, fallback)
    if NMTranslations and NMTranslations.ui then
        return NMTranslations.ui(key, fallback or UI_TEXT_FALLBACKS[tostring(key or "")])
    end
    return fallback or UI_TEXT_FALLBACKS[tostring(key or "")]
end

function NMClientModOptions.getSpatialAudioEnabled()
    if spatialAudioOption and spatialAudioOption.getValue then
        return spatialAudioOption:getValue() ~= false
    end
    return OPTION_DEFAULT_SPATIAL_AUDIO
end

local function applyMasterVolume(value)
    local volume = clampMasterVolume(value)
    if NMRuntimeConfig and NMRuntimeConfig.setNewMusicMasterVolume then
        NMRuntimeConfig.setNewMusicMasterVolume(volume)
    end
end

local function applySpatialAudioEnabled(value)
    local enabled = value ~= false
    if NMRuntimeConfig and NMRuntimeConfig.setSpatialAudioEnabled then
        NMRuntimeConfig.setSpatialAudioEnabled(enabled)
    end
end

local function applyShowTrackNumberPrefix(value)
    local enabled = value ~= false
    if NMRuntimeConfig and NMRuntimeConfig.setShowTrackNumberPrefix then
        NMRuntimeConfig.setShowTrackNumberPrefix(enabled)
    end
    NMClientModOptions.invalidateOpenWindows()
end

local function applyMuteGameSoundtrackDuringPlayback(value)
    local enabled = value ~= false
    if NMRuntimeConfig and NMRuntimeConfig.setMuteGameSoundtrackDuringPlayback then
        NMRuntimeConfig.setMuteGameSoundtrackDuringPlayback(enabled)
    end
end

local function closeLocalDeviceWindows(reason)
    if not (NMDeviceUI and NMDeviceUI.closeAllForPlayer) then
        return
    end
    local closedAny = false
    if getSpecificPlayer then
        for playerNum = 0, 3 do
            if getSpecificPlayer(playerNum) then
                NMDeviceUI.closeAllForPlayer(playerNum, reason or "mod_option_fancy_ui")
                closedAny = true
            end
        end
    end
    if closedAny ~= true then
        NMDeviceUI.closeAllForPlayer(0, reason or "mod_option_fancy_ui")
    end
end

local function applyFancyUIEnabled(value)
    local enabled = value ~= false
    local previous = NMRuntimeConfig and NMRuntimeConfig.get and NMRuntimeConfig.get("fancyUIEnabled", OPTION_DEFAULT_FANCY_UI) or OPTION_DEFAULT_FANCY_UI
    if NMRuntimeConfig and NMRuntimeConfig.setFancyUIEnabled then
        NMRuntimeConfig.setFancyUIEnabled(enabled)
    end
    if previous ~= enabled then
        closeLocalDeviceWindows("mod_option_fancy_ui_toggle")
    end
end

local function applyFancyDeviceUiScale(value)
    local selected = getUiScaleChoiceIndexForPersistedSelection(value)
    local resolved = UI_SCALE_CHOICES[selected] or OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE
    if fancyDeviceUiScaleOption and fancyDeviceUiScaleOption.setValue and tonumber(value) ~= selected then
        fancyDeviceUiScaleOption:setValue(selected)
    end
    if NMRuntimeConfig and NMRuntimeConfig.setFancyDeviceUiScaleMultiplier then
        NMRuntimeConfig.setFancyDeviceUiScaleMultiplier(resolved)
    end
    NMClientModOptions.invalidateOpenWindows()
end

local function setOptionValue(optionId, value)
    if optionId == OPTION_ID_MASTER_VOLUME then
        local resolved = clampMasterVolume(value)
        if masterVolumeOption and masterVolumeOption.setValue then
            masterVolumeOption:setValue(resolved)
        end
        return resolved
    end
    if optionId == OPTION_ID_SPATIAL_AUDIO then
        local resolved = value ~= false
        if spatialAudioOption and spatialAudioOption.setValue then
            spatialAudioOption:setValue(resolved)
        end
        return resolved
    end
    if optionId == OPTION_ID_SHOW_TRACK_NUMBER_PREFIX then
        local resolved = value ~= false
        if showTrackNumberPrefixOption and showTrackNumberPrefixOption.setValue then
            showTrackNumberPrefixOption:setValue(resolved)
        end
        return resolved
    end
    if optionId == OPTION_ID_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK then
        local resolved = value ~= false
        if muteGameSoundtrackDuringPlaybackOption and muteGameSoundtrackDuringPlaybackOption.setValue then
            muteGameSoundtrackDuringPlaybackOption:setValue(resolved)
        end
        return resolved
    end
    if optionId == OPTION_ID_FANCY_UI then
        local resolved = value ~= false
        if fancyUIOption and fancyUIOption.setValue then
            fancyUIOption:setValue(resolved)
        end
        return resolved
    end
    if optionId == OPTION_ID_FANCY_DEVICE_UI_SCALE then
        local selected = getUiScaleChoiceIndexForValue(value)
        if fancyDeviceUiScaleOption and fancyDeviceUiScaleOption.setValue then
            fancyDeviceUiScaleOption:setValue(selected)
        end
        return UI_SCALE_CHOICES[selected] or OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE
    end
    return value
end

local function saveModOptions()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
        PZAPI.ModOptions:save()
    end
end

local function bindMuteGameSoundtrackDuringPlaybackOption()
    if not muteGameSoundtrackDuringPlaybackOption then
        return
    end
    function muteGameSoundtrackDuringPlaybackOption:onChangeApply(value)
        applyMuteGameSoundtrackDuringPlayback(value)
    end
end

local function bindSpatialAudioOption()
    if not spatialAudioOption then
        return
    end
    function spatialAudioOption:onChangeApply(value)
        applySpatialAudioEnabled(value)
    end
end

local function addMuteGameSoundtrackDuringPlaybackOption()
    if not (options and options.addTickBox) then
        return nil
    end
    local option = options:addTickBox(
        OPTION_ID_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK,
        resolveUiText("MuteGameSoundtrackDuringPlayback"),
        OPTION_DEFAULT_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK,
        resolveUiText("MuteGameSoundtrackDuringPlaybackTooltip")
    )
    return option
end

local function moveOptionAfter(targetId, anchorId)
    if not (options and type(options.data) == "table") then
        return
    end
    local targetIndex = nil
    local target = nil
    for i = 1, #options.data do
        local option = options.data[i]
        if option and tostring(option.id or "") == tostring(targetId or "") then
            targetIndex = i
            target = option
            break
        end
    end
    if not targetIndex then
        return
    end
    table.remove(options.data, targetIndex)
    local anchorIndex = 0
    for i = 1, #options.data do
        local option = options.data[i]
        if option and tostring(option.id or "") == tostring(anchorId or "") then
            anchorIndex = i
            break
        end
    end
    table.insert(options.data, anchorIndex + 1, target)
end

function NMClientModOptions.getQuickAccessValues()
    return {
        masterVolume = NMClientModOptions.getMasterVolume(),
        spatialAudio = NMClientModOptions.getSpatialAudioEnabled(),
        showTrackNumberPrefix = NMClientModOptions.getShowTrackNumberPrefix(),
        muteGameSoundtrackDuringPlayback = NMClientModOptions.getMuteGameSoundtrackDuringPlayback(),
        fancyUI = NMClientModOptions.getFancyUIEnabled(),
        fancyDeviceUiScale = NMClientModOptions.getFancyDeviceUiScaleMultiplier(),
    }
end

function NMClientModOptions.getQuickAccessOptionSpecs(values)
    local current = type(values) == "table" and values or NMClientModOptions.getQuickAccessValues()
    return {
        {
            id = OPTION_ID_MASTER_VOLUME,
            key = "masterVolume",
            type = "slider",
            label = resolveUiText("WorldPlaybackMaxVolume"),
            tooltip = resolveUiText("NewMusicMasterVolumeTooltip"),
            min = 0.0,
            max = 1.0,
            step = 0.05,
            default = OPTION_DEFAULT_MASTER_VOLUME,
            value = tonumber(current.masterVolume) or OPTION_DEFAULT_MASTER_VOLUME,
        },
        {
            id = OPTION_ID_SPATIAL_AUDIO,
            key = "spatialAudio",
            type = "tickbox",
            label = resolveUiText("SpatialAudio", "3D Audio"),
            tooltip = resolveUiText("SpatialAudioTooltip", "When enabled, world audio uses Project Zomboid's 3D positioning."),
            default = OPTION_DEFAULT_SPATIAL_AUDIO,
            value = current.spatialAudio ~= false,
        },
        {
            id = OPTION_ID_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK,
            key = "muteGameSoundtrackDuringPlayback",
            type = "tickbox",
            label = resolveUiText("MuteGameSoundtrackDuringPlayback"),
            tooltip = resolveUiText("MuteGameSoundtrackDuringPlaybackTooltip"),
            default = OPTION_DEFAULT_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK,
            value = current.muteGameSoundtrackDuringPlayback ~= false,
        },
        {
            id = OPTION_ID_SHOW_TRACK_NUMBER_PREFIX,
            key = "showTrackNumberPrefix",
            type = "tickbox",
            label = resolveUiText("ShowTrackNumberPrefix", "Show Track Number Prefix"),
            tooltip = resolveUiText("ShowTrackNumberPrefixTooltip", "When enabled, song labels in device UIs begin with their track number."),
            default = OPTION_DEFAULT_SHOW_TRACK_NUMBER_PREFIX,
            value = current.showTrackNumberPrefix ~= false,
        },
        {
            id = OPTION_ID_FANCY_UI,
            key = "fancyUI",
            type = "tickbox",
            label = resolveUiText("FancyUI", "Fancy UI"),
            tooltip = resolveUiText("FancyUITooltip", "Enable experimental UI for supported devices."),
            default = OPTION_DEFAULT_FANCY_UI,
            value = current.fancyUI ~= false,
        },
        {
            id = OPTION_ID_FANCY_DEVICE_UI_SCALE,
            key = "fancyDeviceUiScale",
            type = "combobox",
            label = resolveUiText("FancyDeviceUiScale", "UI Scale"),
            tooltip = resolveUiText("FancyDeviceUiScaleTooltip", "Scales New Music fancy device windows."),
            default = OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE,
            value = tonumber(current.fancyDeviceUiScale) or OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE,
            choices = {
                { value = 1.0, label = getText(getUiScaleLabelKey(1.0)) },
                { value = 1.5, label = getText(getUiScaleLabelKey(1.5)) },
                { value = 2.0, label = getText(getUiScaleLabelKey(2.0)) },
            },
        },
    }
end

function NMClientModOptions.applyQuickAccessValues(values)
    local draft = type(values) == "table" and values or {}
    local current = NMClientModOptions.getQuickAccessValues()
    local masterVolume = draft.masterVolume
    if masterVolume == nil then
        masterVolume = current.masterVolume
    end
    local showTrackNumberPrefix = draft.showTrackNumberPrefix
    if showTrackNumberPrefix == nil then
        showTrackNumberPrefix = current.showTrackNumberPrefix
    end
    local spatialAudio = draft.spatialAudio
    if spatialAudio == nil then
        spatialAudio = current.spatialAudio
    end
    local muteGameSoundtrackDuringPlayback = draft.muteGameSoundtrackDuringPlayback
    if muteGameSoundtrackDuringPlayback == nil then
        muteGameSoundtrackDuringPlayback = current.muteGameSoundtrackDuringPlayback
    end
    local fancyUI = draft.fancyUI
    if fancyUI == nil then
        fancyUI = current.fancyUI
    end
    local fancyDeviceUiScale = draft.fancyDeviceUiScale
    if fancyDeviceUiScale == nil then
        fancyDeviceUiScale = current.fancyDeviceUiScale
    end
    setOptionValue(OPTION_ID_MASTER_VOLUME, masterVolume)
    setOptionValue(OPTION_ID_SPATIAL_AUDIO, spatialAudio)
    setOptionValue(OPTION_ID_SHOW_TRACK_NUMBER_PREFIX, showTrackNumberPrefix)
    setOptionValue(OPTION_ID_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK, muteGameSoundtrackDuringPlayback)
    setOptionValue(OPTION_ID_FANCY_UI, fancyUI)
    setOptionValue(OPTION_ID_FANCY_DEVICE_UI_SCALE, fancyDeviceUiScale)
    saveModOptions()
    if options and options.apply then
        options:apply()
    else
        applyMasterVolume(NMClientModOptions.getMasterVolume())
        applySpatialAudioEnabled(NMClientModOptions.getSpatialAudioEnabled())
        applyShowTrackNumberPrefix(NMClientModOptions.getShowTrackNumberPrefix())
        applyMuteGameSoundtrackDuringPlayback(NMClientModOptions.getMuteGameSoundtrackDuringPlayback())
        applyFancyUIEnabled(NMClientModOptions.getFancyUIEnabled())
        applyFancyDeviceUiScale(fancyDeviceUiScaleOption and fancyDeviceUiScaleOption:getValue() or nil)
    end
    return NMClientModOptions.getQuickAccessValues()
end

local function registerOptions()
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then
        return
    end
    options = PZAPI.ModOptions:getOptions(MOD_OPTIONS_ID)
    if options then
        masterVolumeOption = options:getOption(OPTION_ID_MASTER_VOLUME)
        spatialAudioOption = options:getOption(OPTION_ID_SPATIAL_AUDIO)
        showTrackNumberPrefixOption = options:getOption(OPTION_ID_SHOW_TRACK_NUMBER_PREFIX)
        muteGameSoundtrackDuringPlaybackOption = options:getOption(OPTION_ID_MUTE_GAME_SOUNDTRACK_DURING_PLAYBACK)
        if not muteGameSoundtrackDuringPlaybackOption then
            muteGameSoundtrackDuringPlaybackOption = addMuteGameSoundtrackDuringPlaybackOption()
        end
        if not spatialAudioOption then
            spatialAudioOption = options:addTickBox(
                OPTION_ID_SPATIAL_AUDIO,
                resolveUiText("SpatialAudio", "3D Audio"),
                OPTION_DEFAULT_SPATIAL_AUDIO,
                resolveUiText("SpatialAudioTooltip", "When enabled, world audio uses Project Zomboid's 3D positioning.")
            )
        end
        moveOptionAfter(OPTION_ID_SPATIAL_AUDIO, OPTION_ID_MASTER_VOLUME)
        bindSpatialAudioOption()
        bindMuteGameSoundtrackDuringPlaybackOption()
        fancyUIOption = options:getOption(OPTION_ID_FANCY_UI)
        fancyDeviceUiScaleOption = options:getOption(OPTION_ID_FANCY_DEVICE_UI_SCALE)
        applyLegacyFancyDeviceUiScaleSelectionIfNeeded()
        applyMasterVolume(NMClientModOptions.getMasterVolume())
        applySpatialAudioEnabled(NMClientModOptions.getSpatialAudioEnabled())
        applyShowTrackNumberPrefix(NMClientModOptions.getShowTrackNumberPrefix())
        applyMuteGameSoundtrackDuringPlayback(NMClientModOptions.getMuteGameSoundtrackDuringPlayback())
        applyFancyUIEnabled(NMClientModOptions.getFancyUIEnabled())
        applyFancyDeviceUiScale(fancyDeviceUiScaleOption and fancyDeviceUiScaleOption:getValue() or nil)
        return
    end

    options = PZAPI.ModOptions:create(MOD_OPTIONS_ID, "New Music")
    masterVolumeOption = options:addSlider(
        OPTION_ID_MASTER_VOLUME,
        resolveUiText("WorldPlaybackMaxVolume"),
        0.0,
        1.0,
        0.05,
        OPTION_DEFAULT_MASTER_VOLUME,
        resolveUiText("NewMusicMasterVolumeTooltip")
    )
    spatialAudioOption = options:addTickBox(
        OPTION_ID_SPATIAL_AUDIO,
        resolveUiText("SpatialAudio", "3D Audio"),
        OPTION_DEFAULT_SPATIAL_AUDIO,
        resolveUiText("SpatialAudioTooltip", "When enabled, world audio uses Project Zomboid's 3D positioning.")
    )
    moveOptionAfter(OPTION_ID_SPATIAL_AUDIO, OPTION_ID_MASTER_VOLUME)
    showTrackNumberPrefixOption = options:addTickBox(
        OPTION_ID_SHOW_TRACK_NUMBER_PREFIX,
        resolveUiText("ShowTrackNumberPrefix", "Show Track Number Prefix"),
        OPTION_DEFAULT_SHOW_TRACK_NUMBER_PREFIX,
        resolveUiText("ShowTrackNumberPrefixTooltip", "When enabled, song labels in device UIs begin with their track number.")
    )
    muteGameSoundtrackDuringPlaybackOption = addMuteGameSoundtrackDuringPlaybackOption()
    fancyUIOption = options:addTickBox(
        OPTION_ID_FANCY_UI,
        resolveUiText("FancyUI", "Fancy UI"),
        resolveLegacyFancyUIDefault(),
        resolveUiText("FancyUITooltip", "Enable experimental UI for supported devices.")
    )
    fancyDeviceUiScaleOption = options:addComboBox(
        OPTION_ID_FANCY_DEVICE_UI_SCALE,
        resolveUiText("FancyDeviceUiScale", "UI Scale"),
        resolveUiText("FancyDeviceUiScaleTooltip", "Scales New Music fancy device windows.")
    )
    for i = 1, #UI_SCALE_CHOICES do
        fancyDeviceUiScaleOption:addItem(
            getUiScaleLabelKey(UI_SCALE_CHOICES[i]),
            UI_SCALE_CHOICES[i] == OPTION_DEFAULT_FANCY_DEVICE_UI_SCALE
        )
    end

    function masterVolumeOption:onChange(value)
        applyMasterVolume(value)
    end

    function masterVolumeOption:onChangeApply(value)
        applyMasterVolume(value)
    end

    bindSpatialAudioOption()

    function showTrackNumberPrefixOption:onChangeApply(value)
        applyShowTrackNumberPrefix(value)
    end

    bindMuteGameSoundtrackDuringPlaybackOption()

    function fancyUIOption:onChangeApply(value)
        applyFancyUIEnabled(value)
    end

    function fancyDeviceUiScaleOption:onChangeApply(value)
        applyFancyDeviceUiScale(value)
    end

    function options:apply()
        applyMasterVolume(NMClientModOptions.getMasterVolume())
        applySpatialAudioEnabled(NMClientModOptions.getSpatialAudioEnabled())
        applyShowTrackNumberPrefix(NMClientModOptions.getShowTrackNumberPrefix())
        applyMuteGameSoundtrackDuringPlayback(NMClientModOptions.getMuteGameSoundtrackDuringPlayback())
        applyFancyUIEnabled(NMClientModOptions.getFancyUIEnabled())
        applyFancyDeviceUiScale(fancyDeviceUiScaleOption and fancyDeviceUiScaleOption:getValue() or nil)
    end

    if PZAPI.ModOptions.load then
        PZAPI.ModOptions:load()
    end
    applyLegacyFancyDeviceUiScaleSelectionIfNeeded()
    applyMasterVolume(NMClientModOptions.getMasterVolume())
    applySpatialAudioEnabled(NMClientModOptions.getSpatialAudioEnabled())
    applyShowTrackNumberPrefix(NMClientModOptions.getShowTrackNumberPrefix())
    applyMuteGameSoundtrackDuringPlayback(NMClientModOptions.getMuteGameSoundtrackDuringPlayback())
    applyFancyUIEnabled(NMClientModOptions.getFancyUIEnabled())
    applyFancyDeviceUiScale(fancyDeviceUiScaleOption and fancyDeviceUiScaleOption:getValue() or nil)
end

registerOptions()

return NMClientModOptions
