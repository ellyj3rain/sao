-- Registry retention and cleanup decisions for world sources.
NMRegistryPolicy = NMRegistryPolicy or {}

function NMRegistryPolicy.isWorldSyncStateActive(state)
    if not state then
        return false
    end
    return state.isOn == true
        or state.desiredIsOn == true
        or state.isPlaying == true
        or state.desiredIsPlaying == true
end

function NMRegistryPolicy.shouldKeepWorldSourceState(state)
    if not state then
        return false
    end
    local mode = tostring(state.authoritativeMode or "")
    local playbackMode = tostring(state.playbackMode or "")
    -- Personal/inventory authority is never a world-source retention candidate.
    if playbackMode == "personal" or playbackMode == "none" then
        return false
    end
    if (mode == "attached" or mode == "stowed") and playbackMode ~= "world" then
        return false
    end
    -- Keep world-capable authority modes registry-resident even through transient
    -- transport off states to prevent remove/upsert churn around boundaries.
    if mode == "attached" or mode == "stowed" or mode == "placed" or mode == "vehicle" then
        return true
    end
    local authority = NMAuthorityV4 or NMAuthorityV3
    if authority and type(authority.isWorldActive) == "function" then
        local stateVersion = tonumber(state.stateVersion) or 0
        if stateVersion >= 4 or stateVersion == 3 or mode ~= "" then
            return authority.isWorldActive(state) == true
        end
    end
    if tostring(state.playbackMode or "") ~= "world" then
        return false
    end
    return NMRegistryPolicy.isWorldSyncStateActive(state)
end

function NMRegistryPolicy.getDormancyMinutes()
    return tonumber(NMRuntimeConfig.getServerDormancyMinutes and NMRuntimeConfig.getServerDormancyMinutes() or 5) or 5
end

function NMRegistryPolicy.getUnresolvedGraceMinutes()
    local seconds = tonumber(NMRuntimeConfig.getServerUnresolvedGraceSeconds and NMRuntimeConfig.getServerUnresolvedGraceSeconds() or 6) or 6
    if seconds < 1 then
        seconds = 1
    end
    return seconds / 60.0
end

function NMRegistryPolicy.isUnseenExpiryEnabled()
    return NMRuntimeConfig.getServerUnseenExpiryEnabled and NMRuntimeConfig.getServerUnseenExpiryEnabled() == true
end

function NMRegistryPolicy.getUnseenExpiryMinutes()
    local minutes = tonumber(NMRuntimeConfig.getServerUnseenExpiryMinutes and NMRuntimeConfig.getServerUnseenExpiryMinutes() or 30) or 30
    if minutes < 1 then
        minutes = 1
    end
    return minutes
end

function NMRegistryPolicy.shouldKillDormant(startedAtRealMinutes, nowRealMinutes)
    local timeoutMin = NMRegistryPolicy.getDormancyMinutes()
    if timeoutMin <= 0 then
        return false
    end
    if startedAtRealMinutes == nil then
        return false
    end
    return (tonumber(nowRealMinutes) or 0) - (tonumber(startedAtRealMinutes) or 0) >= timeoutMin
end

function NMRegistryPolicy.shouldKillUnresolvedNear(startedAtRealMinutes, nowRealMinutes)
    local grace = NMRegistryPolicy.getUnresolvedGraceMinutes()
    if startedAtRealMinutes == nil then
        return false
    end
    return (tonumber(nowRealMinutes) or 0) - (tonumber(startedAtRealMinutes) or 0) >= grace
end

function NMRegistryPolicy.shouldKillUnseen(lastSeenAtRealMinutes, nowRealMinutes)
    if not NMRegistryPolicy.isUnseenExpiryEnabled() then
        return false
    end
    if lastSeenAtRealMinutes == nil then
        return false
    end
    local timeoutMin = NMRegistryPolicy.getUnseenExpiryMinutes()
    return (tonumber(nowRealMinutes) or 0) - (tonumber(lastSeenAtRealMinutes) or 0) >= timeoutMin
end

function NMRegistryPolicy.markTombstone(state, profile)
    if not state then
        return false
    end
    local wasOn = state.isOn or state.desiredIsOn or state.isPlaying or state.desiredIsPlaying
    if not wasOn then
        return false
    end
    state.isOn = false
    state.desiredIsOn = false
    state.isPlaying = false
    state.desiredIsPlaying = false
    state.lastStopReason = "dormancy_timeout"
    if NMDeviceState then
        if NMDeviceState.bumpPlaybackEpoch then
            NMDeviceState.bumpPlaybackEpoch(state)
        end
        if NMDeviceState.bumpRevision then
            NMDeviceState.bumpRevision(state)
        end
    end
    return true
end

