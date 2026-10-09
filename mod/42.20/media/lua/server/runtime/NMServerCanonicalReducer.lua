-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
if not NMServerTrackTimeline then
    pcall(require, "server/helpers/NMServerTrackTimeline")
end

-- Canonical server reducer entrypoint for authoritative item/vehicle mutations.
NMServerCanonicalReducer = NMServerCanonicalReducer or {}

NMServerCanonicalReducer.Event = {
    INTENT_START = "INTENT_START",
    INTENT_STOP = "INTENT_STOP",
    INTENT_NEXT = "INTENT_NEXT",
    INTENT_PREV = "INTENT_PREV",
    TICK_PROGRESS = "TICK_PROGRESS",
    TICK_BATTERY = "TICK_BATTERY",
    NO_LISTENER_FREEZE = "NO_LISTENER_FREEZE",
    NO_LISTENER_RESUME_RESTART = "NO_LISTENER_RESUME_RESTART",
    OWNER_OFFLINE_PAUSE = "OWNER_OFFLINE_PAUSE",
    OWNER_ONLINE_RESUME = "OWNER_ONLINE_RESUME",
    REHYDRATE_REBIND = "REHYDRATE_REBIND",
    HINT_TRACK_FINISHED = "HINT_TRACK_FINISHED"
}

local function mapEventToAction(eventType)
    if eventType == NMServerCanonicalReducer.Event.INTENT_STOP then
        return "stop"
    end
    if eventType == NMServerCanonicalReducer.Event.INTENT_START then
        return "play"
    end
    if eventType == NMServerCanonicalReducer.Event.INTENT_NEXT then
        return "next_track"
    end
    if eventType == NMServerCanonicalReducer.Event.INTENT_PREV then
        return "prev_track"
    end
    if eventType == NMServerCanonicalReducer.Event.HINT_TRACK_FINISHED then
        return "track_finished"
    end
    return nil
end

local function nowRealMs()
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

local function rearmTrackTimeline(state, startedAtMs)
    if type(state) ~= "table" then
        return false
    end
    local rearmAtMs = math.max(0, math.floor(tonumber(startedAtMs) or 0))
    if NMServerTrackTimeline and NMServerTrackTimeline.arm then
        return NMServerTrackTimeline.arm(nil, state, rearmAtMs, "world") ~= nil
    end
    state.serverTrackStartedAtMs = rearmAtMs
    state.serverTrackDurationMs = nil
    state.serverTrackDueAtMs = nil
    state._serverTrackTimingMode = "unknown_open"
    return true
end

local function ensureTimelineOnTransportStart(state, action)
    local name = tostring(action or "")
    if name ~= "play" then
        return false
    end
    if not state or state.isOn ~= true or state.isPlaying ~= true then
        return false
    end
    local forceRearm = state._tmBootResetRestartPending == true
    local due = tonumber(state.serverTrackDueAtMs) or 0
    local started = tonumber(state.serverTrackStartedAtMs) or 0
    local duration = tonumber(state.serverTrackDurationMs) or 0
    if (not forceRearm) and due > 0 and started > 0 and duration > 0 then
        return false
    end
    local startedAtMs = nowRealMs()
    rearmTrackTimeline(state, startedAtMs)
    state._tmBootResetRestartPending = nil
    return true
end

local function applyTransportEvent(payload)
    local eventType = tostring(payload.eventType or "")
    local profile = payload.profile
    local state = payload.state
    local transitionPayload = payload.intentPayload
    if not (profile and state) then
        return false, "missing_profile_or_state", nil
    end
    local action = mapEventToAction(eventType)
    if not action then
        return false, "unsupported_event", nil
    end
    local changed, reason, ops = NMDeviceTransitions.apply(profile, state, action, transitionPayload)
    if changed then
        ensureTimelineOnTransportStart(state, action)
    end
    return changed, reason, ops
end

local function applyOwnerPresenceEvent(payload)
    local state = payload.state
    local eventType = tostring(payload.eventType or "")
    if type(state) ~= "table" then
        return false, "missing_state", nil
    end

    if eventType == NMServerCanonicalReducer.Event.OWNER_OFFLINE_PAUSE then
        if state.isPlaying ~= true then
            return false, "already_paused", nil
        end
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "owner_offline_pause"
        return true, "owner_offline_pause_applied", nil
    end

    if eventType == NMServerCanonicalReducer.Event.OWNER_ONLINE_RESUME then
        local hasBattery = state.batteryPresent ~= true or (tonumber(state.batteryCharge) or 0) > 0
        if state.isOn ~= true or not hasBattery or state.isPlaying == true then
            return false, "resume_not_eligible", nil
        end
        local nowMs = math.max(0, tonumber(payload.nowMs) or 0)
        local newStartedAtMs = nowMs
        state.isPlaying = true
        state.desiredIsPlaying = true
        state.lastStopReason = nil
        rearmTrackTimeline(state, newStartedAtMs)
        return true, "owner_online_resume_applied", nil
    end
    return false, "unsupported_owner_event", nil
end

local function applyNoListenerEvent(payload)
    local state = payload.state
    local eventType = tostring(payload.eventType or "")
    if type(state) ~= "table" then
        return false, "missing_state", nil
    end

    if eventType == NMServerCanonicalReducer.Event.NO_LISTENER_FREEZE then
        if state.isPlaying ~= true then
            return false, "already_frozen", nil
        end
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "no_listener_freeze"
        return true, "no_listener_freeze_applied", nil
    end

    if eventType == NMServerCanonicalReducer.Event.NO_LISTENER_RESUME_RESTART then
        local hasBattery = state.batteryPresent ~= true or (tonumber(state.batteryCharge) or 0) > 0
        if state.isOn ~= true or not hasBattery or state.isPlaying == true then
            return false, "resume_not_eligible", nil
        end
        local nowMs = math.max(0, tonumber(payload.nowMs) or 0)
        state.isPlaying = true
        state.desiredIsPlaying = true
        state.lastStopReason = nil
        rearmTrackTimeline(state, nowMs)
        return true, "no_listener_resume_restart_applied", nil
    end
    return false, "unsupported_no_listener_event", nil
end

function NMServerCanonicalReducer.dispatch(input)
    local payload = type(input) == "table" and input or {}
    local eventType = tostring(payload.eventType or "")
    if eventType == NMServerCanonicalReducer.Event.OWNER_OFFLINE_PAUSE
        or eventType == NMServerCanonicalReducer.Event.OWNER_ONLINE_RESUME then
        return applyOwnerPresenceEvent(payload)
    end
    if eventType == NMServerCanonicalReducer.Event.NO_LISTENER_FREEZE
        or eventType == NMServerCanonicalReducer.Event.NO_LISTENER_RESUME_RESTART then
        return applyNoListenerEvent(payload)
    end
    return applyTransportEvent(payload)
end

function NMServerCanonicalReducer.applyBatteryDelta(input)
    local payload = type(input) == "table" and input or {}
    local state = payload.state
    local kind = tostring(payload.kind or "item_world")
    local key = tostring(payload.key or "")
    local deltaSeconds = math.max(0, tonumber(payload.deltaSeconds) or 0)
    local drainSeconds = math.max(1, tonumber(payload.drainSeconds) or 300)
    local oldCharge = math.max(0, math.min(1, tonumber(payload.oldCharge) or 0))
    local markMutation = payload.markMutation
    if type(markMutation) ~= "function" then
        markMutation = function() end
    end

    if not state then
        return false, false, oldCharge
    end
    if state.isOn ~= true then
        return false, false, oldCharge
    end
    if state.batteryPresent ~= true then
        local changed = NMServerBatteryAuthority.forceStateOff(state, "battery_missing")
        if changed then
            markMutation(state)
        end
        return changed, changed, oldCharge
    end
    if oldCharge <= 0 then
        state.batteryCharge = 0.0
        local changed = NMServerBatteryAuthority.forceStateOff(state, "battery_empty")
        if changed then
            markMutation(state)
            local token = string.format("%s:%s", tostring(tonumber(state.playbackEpoch) or -1), tostring(tonumber(state.trackIndex) or -1))
            NMServerBatteryAuthority.logEmptyStop(kind, key, "battery_empty", token)
        end
        return true, changed, 0.0
    end
    if deltaSeconds <= 0 then
        return false, false, oldCharge
    end

    local nextCharge = NMServerBatteryAuthority.computeNextCharge(oldCharge, deltaSeconds, drainSeconds)
    state.batteryCharge = nextCharge
    local mutated = (nextCharge ~= oldCharge)
    if mutated then
        markMutation(state)
    end
    if nextCharge <= 0 then
        state.batteryCharge = 0.0
        local changed = NMServerBatteryAuthority.forceStateOff(state, "battery_empty")
        if changed and not mutated then
            markMutation(state)
        end
        if changed then
            local token = string.format("%s:%s", tostring(tonumber(state.playbackEpoch) or -1), tostring(tonumber(state.trackIndex) or -1))
            NMServerBatteryAuthority.logEmptyStop(kind, key, "battery_empty", token)
        end
        return true, changed, 0.0
    end
    return mutated, false, nextCharge
end

