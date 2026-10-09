NMClientTrackProgressionDispatch = NMClientTrackProgressionDispatch or {}

local function ensureTrackProgressionContract()
    if not NMTrackProgressionContract then
        pcall(require, "playback_progression/NMTrackProgressionContract")
    end
    return NMTrackProgressionContract
end

local function ensureTrackFinishedAuthority()
    if not NMTrackFinishedAuthority then
        pcall(require, "playback_progression/NMTrackFinishedAuthority")
    end
    return NMTrackFinishedAuthority
end

function NMClientTrackProgressionDispatch.resolveTrackCountFromMedia(state)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return 0
    end
    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" then
        return 0
    end
    return #resolved.tracks
end

function NMClientTrackProgressionDispatch.buildTrackFinishedArgs(state, playbackMode, observedDurationMs, options)
    local contract = ensureTrackProgressionContract()
    if not contract then
        return {
            playbackMode = tostring(playbackMode or state and state.playbackMode or "world"),
            trackCount = NMClientTrackProgressionDispatch.resolveTrackCountFromMedia(state),
            hasTrack = NMClientTrackProgressionDispatch.resolveTrackCountFromMedia(state) > 0,
            expectedRevision = tonumber(state and state.revision) or 0,
            expectedPlaybackEpoch = tonumber(state and state.playbackEpoch) or 0,
            expectedTrackIndex = tonumber(state and state.trackIndex) or 0,
            observedDurationMs = tonumber(observedDurationMs) or 0
        }
    end
    local mode = tostring(playbackMode or state and state.playbackMode or "world")
    local trackCount = NMClientTrackProgressionDispatch.resolveTrackCountFromMedia(state)
    local args = contract.buildTrackFinishedArgs(state, observedDurationMs, options)
    args.playbackMode = mode
    args.trackCount = trackCount
    args.hasTrack = trackCount > 0
    return args
end

function NMClientTrackProgressionDispatch.applyLocalTrackFinishedHint(options)
    local authority = ensureTrackFinishedAuthority()
    if not authority then
        return false, "missing_track_finished_authority", nil
    end
    local opts = type(options) == "table" and options or {}
    local state = opts.state
    if type(state) ~= "table" then
        return false, "missing_state", nil
    end

    local ok, reason, info = authority.acceptHint({
        state = state,
        args = opts.args or {},
        tokenOptions = opts.tokenOptions,
        acceptedTokenStore = opts.acceptedTokenStore,
        sourceKey = opts.sourceKey,
        startedAtMs = opts.startedAtMs,
        startedSource = opts.startedSource,
        nowMs = opts.nowMs,
        minHintAgeMs = opts.minHintAgeMs,
        allowStaleRevisionBypass = opts.allowStaleRevisionBypass == true,
        canBypassStaleRevision = opts.canBypassStaleRevision,
        applyObservedDuration = opts.applyObservedDuration
    })
    if not ok then
        return false, reason, info
    end

    if type(opts.advanceState) == "function" then
        opts.advanceState(info)
    end
    return true, reason, info
end

return NMClientTrackProgressionDispatch
