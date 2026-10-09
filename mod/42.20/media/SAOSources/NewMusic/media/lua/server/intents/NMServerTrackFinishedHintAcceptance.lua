NMServerTrackFinishedHintAcceptance = NMServerTrackFinishedHintAcceptance or {}

local function ensureTrackFinishedAuthority()
    if not NMTrackFinishedAuthority then
        pcall(require, "playback_progression/NMTrackFinishedAuthority")
    end
    return NMTrackFinishedAuthority
end

function NMServerTrackFinishedHintAcceptance.accept(options)
    local authority = ensureTrackFinishedAuthority()
    if not authority then
        return {
            accepted = false,
            reason = "missing_track_finished_authority",
            acceptInfo = nil,
            startedAtMs = 0,
            startedSource = "missing"
        }
    end
    local opts = type(options) == "table" and options or {}
    local state = opts.state
    local args = opts.args
    local resolveStartedAt = opts.resolveStartedAt

    local startedAtMs, startedSource = 0, "missing"
    if type(resolveStartedAt) == "function" then
        startedAtMs, startedSource = resolveStartedAt()
    end

    local accepted, reason, acceptInfo = authority.acceptHint({
        state = state,
        args = args,
        acceptedTokenStore = opts.acceptedTokenStore,
        sourceKey = tostring(opts.sourceKey or state and state.deviceUUID or ""),
        startedAtMs = startedAtMs,
        startedSource = startedSource,
        minHintAgeMs = tonumber(opts.minHintAgeMs) or 0,
        allowStaleRevisionBypass = opts.allowStaleRevisionBypass == true,
        canBypassStaleRevision = opts.canBypassStaleRevision,
        applyObservedDuration = opts.applyObservedDuration
    })

    return {
        accepted = accepted == true,
        reason = reason,
        acceptInfo = acceptInfo,
        startedAtMs = startedAtMs,
        startedSource = startedSource
    }
end

return NMServerTrackFinishedHintAcceptance
