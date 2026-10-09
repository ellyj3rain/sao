-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Shared progression contract for duration classification and track-finished token semantics.
NMTrackProgressionContract = NMTrackProgressionContract or {}

local function resolveFallbackMs(fallbackMs)
    local value = tonumber(fallbackMs) or 210000
    return math.max(1000, math.floor(value + 0.5))
end

local function coerceAuthoredDurationMsFromRow(row)
    if type(row) ~= "table" then
        return nil
    end
    local durationMs = tonumber(row.authoredDurationMs)
    if durationMs and durationMs > 0 then
        return math.max(1000, math.floor(durationMs + 0.5))
    end
    local authoredSeconds = tonumber(row.authoredDurationSeconds) or tonumber(row.authoredLengthSeconds) or tonumber(row.authoredDuration)
    if authoredSeconds and authoredSeconds > 0 then
        return math.max(1000, math.floor((authoredSeconds * 1000) + 0.5))
    end
    durationMs = tonumber(row.durationMs)
    if durationMs and durationMs > 0 then
        return math.max(1000, math.floor(durationMs + 0.5))
    end
    local durationSeconds = tonumber(row.durationSeconds) or tonumber(row.lengthSeconds) or tonumber(row.duration)
    if durationSeconds and durationSeconds > 0 then
        return math.max(1000, math.floor((durationSeconds * 1000) + 0.5))
    end
    return nil
end

local function resolveFieldNumber(state, fieldName, fallback)
    return tonumber(state and fieldName and state[fieldName]) or tonumber(fallback) or 0
end

function NMTrackProgressionContract.resolveMinHintAgeMs()
    local minAge = tonumber(
        NMRuntimeConfig and NMRuntimeConfig.get and NMRuntimeConfig.get("serverVehicleTrackHintMinAgeMs", 5000)
        or 5000
    ) or 5000
    return math.max(0, math.floor(minAge + 0.5))
end

function NMTrackProgressionContract.coerceObservedDurationMs(value)
    local observed = tonumber(value) or 0
    if observed <= 0 then
        return nil
    end
    return math.max(1000, math.floor(observed + 0.5))
end

function NMTrackProgressionContract.buildHintToken(state, options)
    local opts = type(options) == "table" and options or {}
    local revisionField = tostring(opts.revisionField or "revision")
    local epochField = tostring(opts.epochField or "playbackEpoch")
    local trackField = tostring(opts.trackField or "trackIndex")
    local uuidField = tostring(opts.uuidField or "deviceUUID")
    return {
        uuid = tostring(state and state[uuidField] or opts.uuid or ""),
        revision = resolveFieldNumber(state, revisionField, opts.revision),
        playbackEpoch = resolveFieldNumber(state, epochField, opts.playbackEpoch),
        trackIndex = resolveFieldNumber(state, trackField, opts.trackIndex)
    }
end

function NMTrackProgressionContract.buildTrackFinishedArgs(state, observedDurationMs, options)
    local token = NMTrackProgressionContract.buildHintToken(state, options)
    return {
        expectedRevision = tonumber(token.revision) or 0,
        expectedPlaybackEpoch = tonumber(token.playbackEpoch) or 0,
        expectedTrackIndex = tonumber(token.trackIndex) or 0,
        observedDurationMs = NMTrackProgressionContract.coerceObservedDurationMs(observedDurationMs)
    }
end

function NMTrackProgressionContract.validateExpectedToken(state, args, options)
    local token = NMTrackProgressionContract.buildHintToken(state, options)
    local expectedRevision = tonumber(args and args.expectedRevision)
    if expectedRevision ~= nil and expectedRevision >= 0 and token.revision ~= expectedRevision then
        return false, "stale_revision", token
    end
    local expectedEpoch = tonumber(args and args.expectedPlaybackEpoch)
    if expectedEpoch ~= nil and expectedEpoch >= 0 and token.playbackEpoch ~= expectedEpoch then
        return false, "stale_epoch", token
    end
    local expectedTrack = tonumber(args and args.expectedTrackIndex)
    if expectedTrack ~= nil and expectedTrack >= 0 and token.trackIndex ~= expectedTrack then
        return false, "stale_track", token
    end
    return true, nil, token
end

function NMTrackProgressionContract.buildAcceptedHintKey(sourceKey, state, options)
    local token = NMTrackProgressionContract.buildHintToken(state, options)
    return table.concat({
        tostring(sourceKey or token.uuid or ""),
        tostring(token.playbackEpoch or 0),
        tostring(token.trackIndex or 0)
    }, "|")
end

function NMTrackProgressionContract.resolveAdvisoryDueAt(durationMs, startedAtMs, knownDuration)
    local startedAt = tonumber(startedAtMs) or 0
    local duration = tonumber(durationMs) or 0
    if knownDuration ~= true or startedAt <= 0 or duration <= 0 then
        return 0
    end
    return startedAt + math.max(1000, math.floor(duration + 0.5))
end

function NMTrackProgressionContract.resolveAdvisoryDueAtForState(state, startedAtMs, options)
    local opts = type(options) == "table" and options or {}
    local progression = NMTrackProgressionContract.resolve(state, opts)
    return NMTrackProgressionContract.resolveAdvisoryDueAt(
        tonumber(progression and progression.durationMs) or 0,
        startedAtMs,
        progression and progression.knownDuration == true
    ), progression
end

function NMTrackProgressionContract.resolveAdvisoryDueAtForRow(row, startedAtMs)
    local startedAt = tonumber(startedAtMs) or 0
    if startedAt <= 0 or type(row) ~= "table" then
        return 0
    end
    return NMTrackProgressionContract.resolveAdvisoryDueAt(coerceAuthoredDurationMsFromRow(row), startedAt, true)
end

function NMTrackProgressionContract.applyObservedDurationHint(state, observedDurationMs, options)
    if type(state) ~= "table" then
        return false, nil
    end
    local opts = type(options) == "table" and options or {}
    local clamped = NMTrackProgressionContract.coerceObservedDurationMs(observedDurationMs)
    if not clamped then
        return false, nil
    end

    local trackField = tostring(opts.trackField or "trackIndex")
    local hintField = tostring(opts.hintField or "observedTrackDurationHints")
    local trackIndex = math.max(1, math.floor(resolveFieldNumber(state, trackField, 1)))
    state[hintField] = state[hintField] or {}
    state[hintField][trackIndex] = clamped

    local row = opts.row
    if type(row) == "table" then
        row.observedDurationMs = clamped
    end
    return true, clamped
end

function NMTrackProgressionContract.resolve(state, options)
    local opts = type(options) == "table" and options or {}
    local fallbackMs = resolveFallbackMs(opts.fallbackMs)
    local context = tostring(opts.context or "")
    local worldAuthoritative = opts.worldAuthoritative == true
    local resolved = NMTrackDurationResolver.resolveForState(state, fallbackMs)
    local token = NMTrackProgressionContract.buildHintToken(state, {
        uuid = opts.uuid,
        revisionField = opts.revisionField or "revision",
        epochField = opts.epochField or "playbackEpoch",
        trackField = opts.trackField or "trackIndex",
        uuidField = opts.uuidField or "deviceUUID"
    })
    local knownDuration = resolved and resolved.knownDuration == true
    local timingMode = knownDuration and "known_due" or "unknown_open"
    return {
        durationMs = tonumber(resolved and resolved.durationMs) or fallbackMs,
        authoredDurationMs = tonumber(resolved and resolved.authoredDurationMs) or nil,
        observedDurationMs = tonumber(resolved and resolved.observedDurationMs) or nil,
        knownDuration = knownDuration,
        timingMode = timingMode,
        source = tostring(resolved and resolved.source or "fallback"),
        trackIndex = tonumber(resolved and resolved.trackIndex) or token.trackIndex,
        row = resolved and resolved.row or nil,
        hintEligible = worldAuthoritative and not knownDuration,
        context = context,
        worldAuthoritative = worldAuthoritative,
        token = token
    }
end

return NMTrackProgressionContract

