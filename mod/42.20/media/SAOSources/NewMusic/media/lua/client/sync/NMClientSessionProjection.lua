-- MP server-session token tracking and local restart-state projection.
NMClientSessionProjection = NMClientSessionProjection or {}
NMClientSessionProjection.state = NMClientSessionProjection.state or {
    currentServerSessionToken = nil,
    lastProjectedSessionToken = nil,
    projectionEligibleToken = nil,
    authoritativeSeenUUIDs = {}
}

local function normalizeToken(value)
    local token = tostring(value or "")
    token = token:gsub("^%s+", "")
    token = token:gsub("%s+$", "")
    if token == "" then
        return nil
    end
    return token
end

local function logRuntime(tag, detail)
    NMRuntimeProbeAdapter.emit("runtime", "runtime", tag, detail or "")
end

local function purgePortableOwnerDetachedGhosts(reason)
    local entries = NMClientWorldSourceCache and NMClientWorldSourceCache.entries or nil
    if type(entries) ~= "table" then
        return 0
    end

    local removed = 0
    for uuid, entry in pairs(entries) do
        local profile = NMDeviceProfiles
            and NMDeviceProfiles.getForFullType
            and NMDeviceProfiles.getForFullType(entry and (entry.profileType or entry.itemFullType) or nil)
            or nil
        local context = tostring(entry and entry.source and entry.source.context or "")
        if profile
            and NMDeviceProfiles.isPortableTrackedProfile
            and NMDeviceProfiles.isPortableTrackedProfile(profile)
            and (context == "attached" or context == "stowed") then
            NMClientWorldSourceCache.remove(uuid)
            removed = removed + 1
        end
    end

    if removed > 0 then
        logRuntime(
            "client_portable_detached_purge",
            string.format("reason=%s removed=%d", tostring(reason or "unknown"), tonumber(removed) or 0)
        )
    end
    return removed
end

local function applyProjectionToState(state, token)
    if type(state) ~= "table" then
        return false
    end
    if tostring(state._tmClientSessionProjectionToken or "") == tostring(token or "") then
        return false
    end
    state.isOn = false
    state.desiredIsOn = false
    state.isPlaying = false
    state.desiredIsPlaying = false
    state.lastStopReason = "server_restart_reset"
    state._tmClientSessionProjectionToken = tostring(token or "")
    return true
end

function NMClientSessionProjection.markAuthoritativeStateSeen(state, token, uuid)
    local sessionToken = normalizeToken(token) or normalizeToken(NMClientSessionProjection.state.currentServerSessionToken)
    if not sessionToken or type(state) ~= "table" then
        return
    end
    state._tmClientSessionProjectionToken = sessionToken
    local deviceUuid = tostring(uuid or state.deviceUUID or "")
    if deviceUuid ~= "" then
        local seen = NMClientSessionProjection.state.authoritativeSeenUUIDs or {}
        seen[deviceUuid] = sessionToken
        NMClientSessionProjection.state.authoritativeSeenUUIDs = seen
    end
end

function NMClientSessionProjection.projectStateIfSessionChanged(state, meta)
    if not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return false
    end
    local token = normalizeToken(NMClientSessionProjection.state.currentServerSessionToken)
    if not token then
        return false
    end
    if normalizeToken(NMClientSessionProjection.state.projectionEligibleToken) ~= token then
        return false
    end
    local uuid = tostring(meta and meta.uuid or state and state.deviceUUID or "")
    if uuid ~= "" then
        local seen = NMClientSessionProjection.state.authoritativeSeenUUIDs or {}
        if normalizeToken(seen[uuid]) == token then
            return false
        end
    end
    local changed = applyProjectionToState(state, token)
    if changed then
        local kind = meta and tostring(meta.kind or "unknown") or "unknown"
        local id = meta and tostring(meta.id or meta.uuid or "unknown") or "unknown"
        logRuntime(
            "client_state_projected_on_access",
            string.format("kind=%s id=%s session=%s", tostring(kind), tostring(id), tostring(token))
        )
    end
    return changed
end

function NMClientSessionProjection.projectCacheSnapshotsForToken(token)
    local sessionToken = normalizeToken(token)
    if not sessionToken then
        return 0
    end
    local count = 0
    local entries = NMClientWorldSourceCache and NMClientWorldSourceCache.entries or nil
    if type(entries) ~= "table" then
        return 0
    end
    for _, entry in pairs(entries) do
        if type(entry) == "table" and type(entry.stateSnapshot) == "table" then
            if applyProjectionToState(entry.stateSnapshot, sessionToken) then
                count = count + 1
            end
        end
    end
    return count
end

function NMClientSessionProjection.observeServerSessionToken(token, source)
    if not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return false
    end
    local sessionToken = normalizeToken(token)
    if not sessionToken then
        return false
    end

    local state = NMClientSessionProjection.state
    local previous = normalizeToken(state.currentServerSessionToken)
    if previous == sessionToken then
        return false
    end

    state.currentServerSessionToken = sessionToken
    state.projectionEligibleToken = sessionToken
    state.authoritativeSeenUUIDs = {}
    logRuntime(
        "client_session_token_seen",
        string.format("old=%s new=%s source=%s", tostring(previous or "nil"), tostring(sessionToken), tostring(source or "unknown"))
    )

    if normalizeToken(state.lastProjectedSessionToken) ~= sessionToken then
        local projected = NMClientSessionProjection.projectCacheSnapshotsForToken(sessionToken)
        purgePortableOwnerDetachedGhosts("session_token_change")
        state.lastProjectedSessionToken = sessionToken
        logRuntime(
            "client_session_projection_applied",
            string.format("session=%s cacheCount=%d", tostring(sessionToken), tonumber(projected) or 0)
        )
    end
    return true
end

function NMClientSessionProjection.onGameStart()
    NMClientSessionProjection.state.projectionEligibleToken = nil
    NMClientSessionProjection.state.authoritativeSeenUUIDs = {}
    purgePortableOwnerDetachedGhosts("game_start")
end

