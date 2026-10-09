NMPortableUiSoundContract = NMPortableUiSoundContract or {}

local DEFAULT_VOLUME = 0.8

local EVENT_SOUND_NAMES = {
    ui_activate = "NM_ButtonClick",
    ui_activate_alt = "NM_ButtonClick2",
    slot_battery_insert_success = "NM_BatteryIn",
    slot_battery_eject_success = "NM_BatteryOut",
    slot_headphone_insert_success = "NM_ButtonClick",
    slot_headphone_eject_success = "NM_ButtonClick",
    transport_press = "NM_ButtonClick",
    power_on_press = "NM_ButtonClick",
    power_off_press = "NM_ButtonClick2",
    cd_manual_play = "NM_CD_Play",
    boombox_button_in = "NM_Boombox_Button_In",
    boombox_button_out = "NM_Boombox_Button_Out",
    boombox_button_pop = "NM_Boombox_Button_Pop",
    boombox_mode_press = "NM_Boombox_Button_Mode",
    boombox_manual_play = "NM_Boombox_Play",
}

local function resolveWindowFamily(window)
    if window and window.target and tostring(window.target.kind or "") == "vehicle" then
        return "vehicle"
    end
    if window and window.getFrontVariant then
        return "cdplayer"
    end
    if window and window.getBoomboxVariant then
        return "boombox"
    end
    if window and window.getLidRect and window.syncLidFromMedia then
        return "walkman"
    end
    return window and tostring(window.slotHostFamily or "generic") or "generic"
end

local function resolvePlayer(window)
    if not window then
        return nil
    end
    local resolved = window.resolveContextCached and window:resolveContextCached()
        or (window.resolveContext and window:resolveContext() or nil)
    return resolved and resolved.player or nil
end

local function isOddboltBoombox(window)
    if not (window and window.getBoomboxVariant) then
        return false
    end
    local ok, variant = pcall(window.getBoomboxVariant, window)
    return ok and tostring(variant or "") == "Oddbolt"
end

local function playUISound(soundName)
    local sm = getSoundManager and getSoundManager() or nil
    if not (sm and sm.playUISound) then
        return false
    end
    local ok = pcall(sm.playUISound, sm, soundName)
    return ok == true
end

local function playLocalFallback(window, soundName)
    local playerObj = resolvePlayer(window)
    if not (playerObj and playerObj.playSoundLocal) then
        return false
    end
    local ok = pcall(playerObj.playSoundLocal, playerObj, soundName)
    return ok == true
end

function NMPortableUiSoundContract.resolveEventSoundName(window, eventName)
    local eventKey = tostring(eventName or "")
    if eventKey == "slot_media_insert_success" then
        local family = resolveWindowFamily(window)
        if family == "cdplayer" then
            return "NM_CD_In"
        end
        if family == "boombox" then
            return "NM_Boombox_Button_In"
        end
        return "NM_ButtonClick"
    end
    if eventKey == "slot_media_eject_success" then
        local family = resolveWindowFamily(window)
        if family == "cdplayer" then
            return "NM_CD_Out"
        end
        if family == "boombox" then
            return "NM_Boombox_Button_Out"
        end
        return "NM_ButtonClick2"
    end
    if eventKey == "lid_open" then
        local family = resolveWindowFamily(window)
        if family == "walkman" then
            return "NM_Walkman_Lid_Open"
        end
        if family == "boombox" then
            return "NM_Walkman_Lid_Open"
        end
        if family == "cdplayer" then
            return "NM_CD_Lid_Open"
        end
        return nil
    end
    if eventKey == "lid_close" then
        local family = resolveWindowFamily(window)
        if family == "walkman" then
            return "NM_Walkman_Lid_Close"
        end
        if family == "boombox" then
            return "NM_Walkman_Lid_Close"
        end
        if family == "cdplayer" then
            return "NM_CD_Lid_Close"
        end
        return nil
    end
    return EVENT_SOUND_NAMES[eventKey]
end

function NMPortableUiSoundContract.playNamedSound(window, soundName, options)
    local name = tostring(soundName or "")
    if name == "" then
        return false
    end
    local opts = options or {}
    if playUISound(name) then
        return true
    end
    if opts.allowLocalFallback == true and playLocalFallback(window, name) then
        return true
    end
    return false
end

function NMPortableUiSoundContract.playEvent(window, eventName, options)
    local soundName = NMPortableUiSoundContract.resolveEventSoundName(window, eventName)
    if not soundName then
        return false
    end
    local played = NMPortableUiSoundContract.playNamedSound(window, soundName, options)
    if tostring(eventName or "") == "boombox_manual_play" and isOddboltBoombox(window) then
        NMPortableUiSoundContract.playNamedSound(window, "NM_Boombox_Oddbolt", options)
    end
    return played
end

function NMPortableUiSoundContract.playUiActivate(window)
    return NMPortableUiSoundContract.playEvent(window, "ui_activate")
end

function NMPortableUiSoundContract.playUiActivateAlt(window)
    return NMPortableUiSoundContract.playEvent(window, "ui_activate_alt")
end

function NMPortableUiSoundContract.playTransportPress(window)
    return NMPortableUiSoundContract.playEvent(window, "transport_press")
end

function NMPortableUiSoundContract.playPowerPress(window, isTurningOn)
    local eventName = isTurningOn == true and "power_on_press" or "power_off_press"
    return NMPortableUiSoundContract.playEvent(window, eventName)
end

function NMPortableUiSoundContract.playSlotSuccess(window, slotType, actionName)
    local slotKey = tostring(slotType or "")
    local actionKey = tostring(actionName or "")
    if slotKey == "" or actionKey == "" then
        return false
    end
    return NMPortableUiSoundContract.playEvent(window, "slot_" .. slotKey .. "_" .. actionKey .. "_success")
end

function NMPortableUiSoundContract.playLid(window, isOpening)
    return NMPortableUiSoundContract.playEvent(window, isOpening == true and "lid_open" or "lid_close")
end

function NMPortableUiSoundContract.playCDManualPlay(window)
    return NMPortableUiSoundContract.playEvent(window, "cd_manual_play")
end

function NMPortableUiSoundContract.getDefaultVolume()
    return DEFAULT_VOLUME
end

return NMPortableUiSoundContract
