-- MP server-session-aware playback reset for fresh-boot normalization.
NMServerBootReset = NMServerBootReset or {}
NMServerBootReset._sessionToken = NMServerBootReset._sessionToken or nil
NMServerBootReset._logSeen = NMServerBootReset._logSeen or {}
NMServerBootReset._normalizedByUuid = NMServerBootReset._normalizedByUuid or {}

local function nowToken()
    local now = 0
    if getTimestampMs then
        now = tonumber(getTimestampMs()) or 0
    elseif getTimestamp then
        now = (tonumber(getTimestamp()) or 0) * 1000
    end
    local rand = 0
    if ZombRand then
        rand = tonumber(ZombRand(0x7fffffff)) or 0
    end
    return tostring(now) .. "-" .. string.format("%08x", rand)
end

local function shouldLog()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")
end

local function markSeen(kind, uuid)
    local key = tostring(kind or "") .. ":" .. tostring(uuid or "")
    if NMServerBootReset._logSeen[key] == true then
        return false
    end
    NMServerBootReset._logSeen[key] = true
    return true
end

local function isActive(state)
    if not state then
        return false
    end
    -- Only reset transport-active states on server boot.
    -- Power-on alone should not be treated as a playback session that needs restart reset.
    return state.isPlaying == true
        or state.desiredIsPlaying == true
end

function NMServerBootReset.initSession()
    NMServerBootReset._sessionToken = nowToken()
    NMServerBootReset._logSeen = {}
    NMServerBootReset._normalizedByUuid = {}
end

function NMServerBootReset.getSessionToken()
    if tostring(NMServerBootReset._sessionToken or "") == "" then
        NMServerBootReset.initSession()
    end
    return tostring(NMServerBootReset._sessionToken or "")
end

function NMServerBootReset.normalizeState(state, kind, identifier)
    if not (NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority()) then
        return false, "not_mp_server"
    end
    if NMRuntimeConfig.getMPResetPlaybackOnServerStart and not NMRuntimeConfig.getMPResetPlaybackOnServerStart() then
        return false, "disabled"
    end
    if not state then
        return false, "missing_state"
    end

    local sessionToken = NMServerBootReset.getSessionToken()
    local uuid = tostring(state.deviceUUID or identifier or "")
    local marker = tostring(state._tmServerSessionMarker or "")
    local seenForSession = tostring(NMServerBootReset._normalizedByUuid[uuid] or "")
    if marker == sessionToken or (uuid ~= "" and seenForSession == sessionToken) then
        if marker ~= sessionToken then
            state._tmServerSessionMarker = sessionToken
        end
        if shouldLog() and markSeen("skipped", uuid) then
            NMCore.logChannel(
                "runtime",
                "server_boot_reset_skipped",
                string.format("uuid=%s kind=%s reason=already_marked", tostring(uuid), tostring(kind or "unknown"))
            )
        end
        return false, "already_marked"
    end

    state._tmServerSessionMarker = sessionToken
    if uuid ~= "" then
        NMServerBootReset._normalizedByUuid[uuid] = sessionToken
    end
    if not isActive(state) then
        return false, "inactive_marked"
    end

    state.isPlaying = false
    state.desiredIsPlaying = false
    state.isOn = false
    state.desiredIsOn = false
    state.lastStopReason = "server_restart_reset"
    -- Force first post-restart transport start to arm a fresh timeline.
    state._tmBootResetRestartPending = true
    if NMDeviceState and NMDeviceState.bumpPlaybackEpoch then
        NMDeviceState.bumpPlaybackEpoch(state)
    end
    if NMDeviceState and NMDeviceState.bumpRevision then
        NMDeviceState.bumpRevision(state)
    end

    if shouldLog() and markSeen("applied", uuid) then
        NMCore.logChannel(
            "runtime",
            "server_boot_reset_applied",
            string.format(
                "uuid=%s kind=%s reason=server_restart_reset",
                tostring(uuid),
                tostring(kind or "unknown")
            )
        )
    end
    return true, "reset_applied"
end

