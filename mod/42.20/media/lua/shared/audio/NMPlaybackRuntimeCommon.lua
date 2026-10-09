-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Internal helper functions for NMPlaybackRuntime.
NMPlaybackRuntimeCommon = NMPlaybackRuntimeCommon or {}

local function logTrackEndProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    NMCore.logChannel("playback_progression", tostring(tag or "track_end_probe"), tostring(detail or ""))
end

local function isSPPortableFollowContext(profile, context, source)
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true then
        return false
    end
    if not (NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        return false
    end
    local normalizedContext = tostring(context or "")
    if normalizedContext == "attached" or normalizedContext == "pickup_pending" then
        return true
    end
    return source and source._nmFastFollowPlayer == true or false
end

local function resolveTrackEndPendingPolicy(profile, context, source)
    local deviceType = profile and profile.deviceType or nil
    local windowMs = math.max(250, tonumber(NMRuntimeConfig.getTrackEndPendingWindowMsForDeviceType and NMRuntimeConfig.getTrackEndPendingWindowMsForDeviceType(deviceType) or 1200) or 1200)
    local falseChecks = math.max(1, tonumber(NMRuntimeConfig.getTrackEndPendingFalseChecksForDeviceType and NMRuntimeConfig.getTrackEndPendingFalseChecksForDeviceType(deviceType) or 3) or 3)
    local policy = "default"
    if isSPPortableFollowContext(profile, context, source) then
        windowMs = math.min(windowMs, 350)
        falseChecks = math.min(falseChecks, 2)
        policy = "sp_portable_follow"
    end
    return {
        windowMs = windowMs,
        falseChecks = falseChecks,
        policy = policy
    }
end

local function buildTrackEndProbeDetail(tag, uuid, state, profile, context, source, active, policy, extra)
    local payload = type(extra) == "table" and extra or {}
    local deviceType = tostring(profile and profile.deviceType or state and state.deviceType or "unknown")
    local normalizedContext = tostring(context or source and source.context or source and source.mode or "unknown")
    local startedAtMs = tonumber(active and active.startedAtMs) or 0
    local nowMs = tonumber(payload.nowMs) or NMPlaybackRuntimeCommon.getNowRealMs()
    local observedDurationMs = startedAtMs > 0 and math.max(0, nowMs - startedAtMs) or 0
    return string.format(
        "tag=%s uuid=%s type=%s context=%s epoch=%s track=%s playing=%s startedAtMs=%s observedDurationMs=%s pendingElapsedMs=%s falseCount=%s windowMs=%s falseChecks=%s policy=%s media=%s confirmedAtMs=%s",
        tostring(tag or "track_end_probe"),
        tostring(uuid),
        deviceType,
        normalizedContext,
        tostring(state and state.playbackEpoch or -1),
        tostring(state and state.trackIndex or -1),
        tostring(payload.playing),
        tostring(startedAtMs),
        tostring(observedDurationMs),
        tostring(payload.pendingElapsedMs or 0),
        tostring(payload.falseCount or 0),
        tostring(policy and policy.windowMs or 0),
        tostring(policy and policy.falseChecks or 0),
        tostring(policy and policy.policy or "default"),
        tostring(state and state.mediaFullType or "nil"),
        tostring(payload.confirmedAtMs or "nil")
    )
end

function NMPlaybackRuntimeCommon.getNowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    if os and os.time then
        return (tonumber(os.time()) or 0) * 1000
    end
    return 0
end

function NMPlaybackRuntimeCommon.applyPowerDrain(powerTickMap, profile, state, tickCount)
    if not profile or not state or not state.deviceUUID then return end
    if not profile.requiresBattery then return end

    local key = tostring(state.deviceUUID)
    local nowMs = NMPlaybackRuntimeCommon.getNowRealMs()
    local lastMs = tonumber(powerTickMap[key])

    if not state.isOn then
        powerTickMap[key] = nowMs
        return
    end
    if not state.batteryPresent then
        -- Keep power-on intent/state so UI can show On(NoPower); only playback is blocked.
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "battery_missing"
        powerTickMap[key] = nowMs
        return
    end

    local charge = NMCore.clamp(tonumber(state.batteryCharge) or 0.0, 0.0, 1.0)
    if charge <= 0 then
        state.batteryCharge = 0.0
        -- Keep power-on intent/state so UI can show On(NoPower); only playback is blocked.
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "battery_empty"
        powerTickMap[key] = nowMs
        return
    end

    if lastMs == nil then
        powerTickMap[key] = nowMs
        return
    end

    local deltaSeconds = math.max(0, (nowMs - lastMs) / 1000.0)
    if deltaSeconds <= 0 then return end
    local drainSeconds = tonumber(NMRuntimeConfig.getBatteryDrainSecondsPortableFromSandbox and NMRuntimeConfig.getBatteryDrainSecondsPortableFromSandbox() or 86400) or 86400
    if drainSeconds <= 0 then
        powerTickMap[key] = nowMs
        return
    end

    state.batteryCharge = NMCore.clamp(charge - (deltaSeconds / drainSeconds), 0.0, 1.0)
    powerTickMap[key] = nowMs
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
        local logKey = "runtimeProbe.batteryDrain.portable." .. tostring(key)
        if NMCore.shouldLogEvery(logKey, nowMs, 5000) then
            NMCore.logChannel(
                "runtime",
                "battery_drain_tick",
                string.format(
                    "uuid=%s type=portable deltaMs=%d old=%.3f new=%.3f targetSeconds=%.0f",
                    tostring(key),
                    math.floor(math.max(0, nowMs - lastMs)),
                    charge,
                    tonumber(state.batteryCharge) or 0,
                    drainSeconds
                )
            )
        end
    end
    if state.batteryCharge <= 0 then
        state.batteryCharge = 0.0
        -- Keep power-on intent/state so UI can show On(NoPower); only playback is blocked.
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "battery_empty"
    end
end

function NMPlaybackRuntimeCommon.updateTrackEndState(trackEndPendingMap, trackEndedMap, awaitingMap, uuid, state, active, profile, context, source)
    local emitter = active and active.emitter or nil
    local pending = trackEndPendingMap[uuid]
    if not emitter or not active.soundId or not emitter.isPlaying then
        return false
    end
    local playing = emitter:isPlaying(active.soundId)
    local policy = resolveTrackEndPendingPolicy(profile, context, source)
    if playing ~= false then
        if pending then
            logTrackEndProbe(
                "track_end_false_cleared",
                buildTrackEndProbeDetail("false_cleared", uuid, state, profile, context, source, active, policy, {
                    playing = playing,
                    falseCount = pending and pending.falseCount or 0,
                    pendingElapsedMs = math.max(0, NMPlaybackRuntimeCommon.getNowRealMs() - (tonumber(pending and pending.firstFalseMs) or 0))
                })
            )
        end
        trackEndPendingMap[uuid] = nil
        return false
    end

    local nowMs = NMPlaybackRuntimeCommon.getNowRealMs()
    local windowMs = tonumber(policy and policy.windowMs) or 1200
    local falseChecks = tonumber(policy and policy.falseChecks) or 3

    if not pending then
        trackEndPendingMap[uuid] = { firstFalseMs = nowMs, falseCount = 1 }
        logTrackEndProbe(
            "track_end_false_start",
            buildTrackEndProbeDetail("false_start", uuid, state, profile, context, source, active, policy, {
                nowMs = nowMs,
                playing = playing,
                falseCount = 1,
                pendingElapsedMs = 0
            })
        )
        return false
    end

    pending.falseCount = (tonumber(pending.falseCount) or 0) + 1
    local elapsed = nowMs - (tonumber(pending.firstFalseMs) or nowMs)
    local shouldLogProgress = false
    if NMCore and NMCore.shouldLogEvery then
        local logKey = string.format(
            "progressionProbe.track_end_false_progress.%s.%s.%s",
            tostring(uuid or ""),
            tostring(state and state.playbackEpoch or -1),
            tostring(state and state.trackIndex or -1)
        )
        shouldLogProgress = NMCore.shouldLogEvery(logKey, nowMs, 1000)
            or elapsed >= windowMs
            or (tonumber(pending.falseCount) or 0) == falseChecks
            or elapsed >= math.max(1000, windowMs * 2)
    end
    if shouldLogProgress then
        logTrackEndProbe(
            "track_end_false_progress",
            buildTrackEndProbeDetail("false_progress", uuid, state, profile, context, source, active, policy, {
                nowMs = nowMs,
                playing = playing,
                falseCount = pending.falseCount,
                pendingElapsedMs = elapsed
            })
        )
    end
    if elapsed >= windowMs and (tonumber(pending.falseCount) or 0) >= falseChecks then
        trackEndPendingMap[uuid] = nil
        trackEndedMap[uuid] = {
            uuid = uuid,
            playbackEpoch = tonumber(state and state.playbackEpoch) or -1,
            trackIndex = tonumber(state and state.trackIndex) or -1,
            sourceGeneration = tonumber(state and state.sourceGeneration) or -1,
            token = tostring(uuid) .. ":" .. tostring(tonumber(state and state.playbackEpoch) or -1) .. ":" .. tostring(tonumber(state and state.trackIndex) or -1),
            observedDurationMs = math.max(0, nowMs - (tonumber(active and active.startedAtMs) or nowMs)),
            firstFalseMs = tonumber(pending.firstFalseMs) or nowMs,
            confirmedAtMs = nowMs,
            pendingElapsedMs = elapsed,
            falseCount = tonumber(pending.falseCount) or 0,
            windowMs = windowMs,
            falseChecks = falseChecks,
            context = tostring(context or source and source.context or source and source.mode or "unknown"),
            policy = tostring(policy and policy.policy or "default")
        }
        awaitingMap[uuid] = {
            playbackEpoch = tonumber(state and state.playbackEpoch) or -1,
            trackIndex = tonumber(state and state.trackIndex) or -1,
            sourceGeneration = tonumber(state and state.sourceGeneration) or -1,
            setAtMs = nowMs,
            firstFalseMs = tonumber(pending.firstFalseMs) or nowMs,
            pendingElapsedMs = elapsed,
            falseCount = tonumber(pending.falseCount) or 0,
            windowMs = windowMs,
            falseChecks = falseChecks,
            context = tostring(context or source and source.context or source and source.mode or "unknown"),
            policy = tostring(policy and policy.policy or "default")
        }
        logTrackEndProbe(
            "track_end_confirmed",
            buildTrackEndProbeDetail("confirmed", uuid, state, profile, context, source, active, policy, {
                nowMs = nowMs,
                playing = playing,
                falseCount = pending.falseCount,
                pendingElapsedMs = elapsed,
                confirmedAtMs = nowMs
            })
        )
        return true
    end

    trackEndPendingMap[uuid] = pending
    return false
end

