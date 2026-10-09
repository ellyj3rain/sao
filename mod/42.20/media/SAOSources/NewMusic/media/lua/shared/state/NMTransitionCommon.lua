-- Shared transition guard helpers used by NMDeviceTransitions.
NMTransitionCommon = NMTransitionCommon or {}

function NMTransitionCommon.canPlay(profile, state, hasTrack, payload)
    payload = payload or {}
    if not state.isOn then return false, "device_off" end
    if not state.mediaFullType then return false, "no_media" end
    local missingHeadphones = not state.headphoneItemFullType
    if NMDeviceProfiles.requiresHeadphonesForPlayback(profile)
        and missingHeadphones
        and not NMDeviceProfiles.allowNoHeadphonesMutedPlayback(profile) then
        return false, "no_headphones"
    end
    if profile.requiresBattery then
        if not state.batteryPresent then return false, "no_battery" end
        if (tonumber(state.batteryCharge) or 0) <= 0 then return false, "empty_battery" end
    end
    if NMDeviceProfiles.requiresExternalPower(profile) and payload.externalPowerAvailable ~= true then
        return false, "no_external_power"
    end
    if not hasTrack then return false, "no_track" end
    return true, nil
end

function NMTransitionCommon.setStopped(state, reason)
    state.isPlaying = false
    state.desiredIsPlaying = false
    state.lastStopReason = reason
end

function NMTransitionCommon.enforcePlayableState(profile, state, payload)
    if not state.isPlaying then
        return false
    end
    local ok, reason = NMTransitionCommon.canPlay(profile, state, payload.hasTrack == true, payload)
    if ok then
        return false
    end
    NMTransitionCommon.setStopped(state, reason)
    return true
end



