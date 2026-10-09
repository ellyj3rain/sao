NMTrackFinishedAuthority = NMTrackFinishedAuthority or {}

local function ensureTrackProgressionContract()
    if not NMTrackProgressionContract then
        pcall(require, "playback_progression/NMTrackProgressionContract")
    end
    return NMTrackProgressionContract
end

local function resolveNowMs()
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

function NMTrackFinishedAuthority.acceptHint(options)
    local contract = ensureTrackProgressionContract()
    if not contract then
        return false, "missing_track_progression_contract", nil
    end
    local opts = type(options) == "table" and options or {}
    local state = opts.state
    local args = opts.args or {}
    local nowMs = tonumber(opts.nowMs) or resolveNowMs()

    local expectedOk, expectedReason, token = contract.validateExpectedToken(state, args, opts.tokenOptions)
    if not expectedOk then
        local bypass = expectedReason == "stale_revision"
            and opts.allowStaleRevisionBypass == true
            and type(opts.canBypassStaleRevision) == "function"
            and opts.canBypassStaleRevision(state, args) == true
        if not bypass then
            return false, expectedReason or "stale_state", {
                token = token,
                nowMs = nowMs
            }
        end
    end

    local minHintAgeMs = tonumber(opts.minHintAgeMs)
    if minHintAgeMs == nil then
        minHintAgeMs = contract.resolveMinHintAgeMs()
    end
    minHintAgeMs = math.max(0, math.floor((tonumber(minHintAgeMs) or 0) + 0.5))

    local startedAtMs = tonumber(opts.startedAtMs) or 0
    local startedSource = tostring(opts.startedSource or "missing")
    local ageMs = startedAtMs > 0 and math.max(0, nowMs - startedAtMs) or minHintAgeMs
    local missingStartedAt = startedAtMs <= 0
    if not missingStartedAt and ageMs < minHintAgeMs then
        return false, "too_early", {
            token = token,
            nowMs = nowMs,
            startedAtMs = startedAtMs,
            startedSource = startedSource,
            ageMs = ageMs,
            minHintAgeMs = minHintAgeMs,
            missingStartedAt = false
        }
    end

    local acceptedTokenStore = opts.acceptedTokenStore
    local dedupeToken = contract.buildAcceptedHintKey(opts.sourceKey, state, opts.tokenOptions)
    if type(acceptedTokenStore) == "table" and tostring(acceptedTokenStore[dedupeToken] or "") ~= "" then
        return false, "duplicate", {
            token = token,
            nowMs = nowMs,
            dedupeToken = dedupeToken,
            startedAtMs = startedAtMs,
            startedSource = startedSource,
            ageMs = ageMs,
            minHintAgeMs = minHintAgeMs,
            missingStartedAt = missingStartedAt
        }
    end

    if type(acceptedTokenStore) == "table" then
        acceptedTokenStore[dedupeToken] = "accepted"
    end

    local observedDurationMs = contract.coerceObservedDurationMs(args and args.observedDurationMs)
    local observedApplied = false
    if type(opts.applyObservedDuration) == "function" then
        observedApplied, observedDurationMs = opts.applyObservedDuration(observedDurationMs, args)
    end

    return true, "accepted", {
        token = token,
        nowMs = nowMs,
        dedupeToken = dedupeToken,
        startedAtMs = startedAtMs,
        startedSource = startedSource,
        ageMs = ageMs,
        minHintAgeMs = minHintAgeMs,
        missingStartedAt = missingStartedAt,
        observedDurationMs = observedDurationMs,
        observedApplied = observedApplied,
        revisionBypassed = expectedOk ~= true
    }
end

return NMTrackFinishedAuthority
