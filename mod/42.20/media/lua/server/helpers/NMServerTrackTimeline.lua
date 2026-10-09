-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMServerTrackTimeline = NMServerTrackTimeline or {}

local function ensureTrackProgressionContract()
    if not NMTrackProgressionContract then
        pcall(require, "playback_progression/NMTrackProgressionContract")
    end
    return NMTrackProgressionContract
end

local function normalizeContextKind(contextKind)
    local kind = tostring(contextKind or "world")
    if kind == "" then
        kind = "world"
    end
    return kind
end

local function resolveFallbackMs()
    return tonumber(
        NMRuntimeConfig and NMRuntimeConfig.getServerVehicleTrackDurationMs and NMRuntimeConfig.getServerVehicleTrackDurationMs()
        or NMRuntimeConfig and NMRuntimeConfig.get and NMRuntimeConfig.get("serverVehicleTrackDurationMs", 210000)
        or 210000
    ) or 210000
end

local function buildArmToken(state)
    local epoch = tonumber(state and state.playbackEpoch) or 0
    local track = tonumber(state and state.trackIndex) or 0
    return tostring(epoch) .. ":" .. tostring(track)
end

local function readArmToken(entry, state)
    local token = tostring(state and state._serverTrackArmToken or "")
    if token ~= "" then
        return token
    end
    return tostring(entry and entry._serverTrackArmToken or "")
end

local function writeArmToken(entry, state, token)
    local normalized = tostring(token or "")
    if type(state) == "table" then
        state._serverTrackArmToken = normalized ~= "" and normalized or nil
    end
    if type(entry) == "table" then
        entry._serverTrackArmToken = normalized ~= "" and normalized or nil
    end
end

function NMServerTrackTimeline.resolveProgressionInfo(state, contextKind)
    local contract = ensureTrackProgressionContract()
    if not contract then
        return {
            durationMs = resolveFallbackMs(),
            authoredDurationMs = nil,
            observedDurationMs = nil,
            knownDuration = false,
            timingMode = "unknown_open",
            source = "fallback",
            trackIndex = tonumber(state and state.trackIndex) or 1,
            row = nil,
            hintEligible = false,
            context = normalizeContextKind(contextKind),
            worldAuthoritative = true,
            token = {
                uuid = tostring(state and state.deviceUUID or ""),
                revision = tonumber(state and state.revision) or 0,
                playbackEpoch = tonumber(state and state.playbackEpoch) or 0,
                trackIndex = tonumber(state and state.trackIndex) or 0
            }
        }
    end
    return contract.resolve(state, {
        fallbackMs = resolveFallbackMs(),
        context = normalizeContextKind(contextKind),
        worldAuthoritative = true
    })
end

function NMServerTrackTimeline.clear(entry, state)
    if type(state) == "table" then
        state.serverTrackStartedAtMs = nil
        state.serverTrackDurationMs = nil
        state.serverTrackDueAtMs = nil
        state._serverTrackTimingMode = nil
        state._serverTrackArmToken = nil
    end
    if type(entry) == "table" then
        entry.serverTrackStartedAtMs = nil
        entry.serverTrackDurationMs = nil
        entry.serverTrackDueAtMs = nil
        entry._serverTrackStartedAtMs = nil
        entry._serverTrackDurationMs = nil
        entry._serverTrackNextTransitionAtMs = nil
        entry._serverTrackTimingMode = nil
        entry._serverTrackArmToken = nil
    end
end

function NMServerTrackTimeline.arm(entry, state, nowMs, contextKind)
    if type(state) ~= "table" then
        return nil
    end
    if state.isOn ~= true or state.isPlaying ~= true then
        NMServerTrackTimeline.clear(entry, state)
        return nil
    end
    local startedAtMs = math.max(0, math.floor(tonumber(nowMs) or 0))
    local progression = NMServerTrackTimeline.resolveProgressionInfo(state, contextKind)
    local timingMode = tostring(progression and progression.timingMode or ((progression and progression.knownDuration == true) and "known_due" or "unknown_open"))
    local durationMs = math.max(1000, math.floor(tonumber(progression and progression.durationMs) or 0))
    local contract = ensureTrackProgressionContract()
    local dueAtMs = contract and contract.resolveAdvisoryDueAt(durationMs, startedAtMs, timingMode == "known_due") or 0
    local armToken = buildArmToken(state)

    state.serverTrackStartedAtMs = startedAtMs
    state.serverTrackDurationMs = timingMode == "known_due" and durationMs or nil
    state.serverTrackDueAtMs = timingMode == "known_due" and dueAtMs or nil
    state._serverTrackTimingMode = timingMode
    if type(entry) == "table" then
        entry.serverTrackStartedAtMs = startedAtMs
        entry.serverTrackDurationMs = timingMode == "known_due" and durationMs or nil
        entry.serverTrackDueAtMs = timingMode == "known_due" and dueAtMs or nil
        entry._serverTrackStartedAtMs = startedAtMs
        entry._serverTrackDurationMs = timingMode == "known_due" and durationMs or nil
        entry._serverTrackNextTransitionAtMs = timingMode == "known_due" and dueAtMs or nil
        entry._serverTrackTimingMode = timingMode
    end
    writeArmToken(entry, state, armToken)

    return {
        startedAtMs = startedAtMs,
        durationMs = durationMs,
        dueAtMs = dueAtMs,
        armToken = armToken,
        timingMode = timingMode,
        progression = progression,
        cause = timingMode == "known_due" and "metadata_due" or "unknown_open"
    }
end

function NMServerTrackTimeline.read(entry, state)
    local startedAtMs = tonumber(state and state.serverTrackStartedAtMs) or tonumber(entry and (entry.serverTrackStartedAtMs or entry._serverTrackStartedAtMs)) or 0
    local durationMs = tonumber(state and state.serverTrackDurationMs) or tonumber(entry and (entry.serverTrackDurationMs or entry._serverTrackDurationMs)) or 0
    local dueAtMs = tonumber(state and state.serverTrackDueAtMs) or tonumber(entry and (entry.serverTrackDueAtMs or entry._serverTrackNextTransitionAtMs)) or 0
    return {
        startedAtMs = startedAtMs,
        durationMs = durationMs,
        dueAtMs = dueAtMs,
        timingMode = tostring(state and state._serverTrackTimingMode or entry and entry._serverTrackTimingMode or "")
    }
end

function NMServerTrackTimeline.isValid(entry, state)
    local t = NMServerTrackTimeline.read(entry, state)
    if t.timingMode == "unknown_open" then
        return t.startedAtMs > 0, t
    end
    if t.timingMode == "" and t.startedAtMs > 0 and t.durationMs <= 0 and t.dueAtMs <= 0 then
        return true, t
    end
    if t.startedAtMs <= 0 or t.durationMs <= 0 or t.dueAtMs <= 0 then
        return false, t
    end
    if t.dueAtMs <= t.startedAtMs then
        return false, t
    end
    return true, t
end

function NMServerTrackTimeline.armForReason(entry, state, nowMs, contextKind, reason)
    if type(state) ~= "table" then
        return nil
    end
    local armReason = tostring(reason or "")
    if state.isOn ~= true or state.isPlaying ~= true then
        NMServerTrackTimeline.clear(entry, state)
        return { status = "cleared" }
    end

    local token = buildArmToken(state)
    local previousToken = readArmToken(entry, state)
    local valid, timeline = NMServerTrackTimeline.isValid(entry, state)
    if armReason == "play" and valid and previousToken ~= "" and previousToken == token then
        return {
            status = "skipped_duplicate",
            dueAtMs = tonumber(timeline and timeline.dueAtMs) or 0,
            startedAtMs = tonumber(timeline and timeline.startedAtMs) or 0,
            durationMs = tonumber(timeline and timeline.durationMs) or 0,
            timingMode = tostring(timeline and timeline.timingMode or ""),
            armToken = token
        }
    end

    local armed = NMServerTrackTimeline.arm(entry, state, nowMs, contextKind)
    if not armed then
        return nil
    end
    return {
        status = "applied",
        dueAtMs = tonumber(armed.dueAtMs) or 0,
        startedAtMs = tonumber(armed.startedAtMs) or 0,
        durationMs = tonumber(armed.durationMs) or 0,
        timingMode = tostring(armed.timingMode or ""),
        armToken = tostring(armed.armToken or token),
        progression = armed.progression,
        cause = armed.cause
    }
end

return NMServerTrackTimeline

