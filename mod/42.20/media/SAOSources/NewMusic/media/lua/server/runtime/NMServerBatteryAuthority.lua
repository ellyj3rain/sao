-- Shared server-side battery authority helpers for item and vehicle ticks.
NMServerBatteryAuthority = NMServerBatteryAuthority or {}

function NMServerBatteryAuthority.computeNextCharge(currentCharge, deltaSeconds, drainSeconds)
    local current = NMCore.clamp(tonumber(currentCharge) or 0.0, 0.0, 1.0)
    local delta = math.max(0, tonumber(deltaSeconds) or 0)
    local target = math.max(1, tonumber(drainSeconds) or 300)
    return NMCore.clamp(current - (delta / target), 0.0, 1.0), current
end

function NMServerBatteryAuthority.forceStateOff(state, reason)
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
    state.lastStopReason = tostring(reason or "battery_empty")
    NMDeviceState.bumpPlaybackEpoch(state)
    NMDeviceState.bumpRevision(state)
    return true
end

function NMServerBatteryAuthority.logBatteryTick(kind, key, nowMsValue, prevMs, oldCharge, nextCharge, drainSeconds, extra)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery) then
        return
    end
    local logKey = "runtimeProbe.serverBattery." .. tostring(kind or "unknown") .. "." .. tostring(key or "")
    if not NMCore.shouldLogEvery(logKey, tonumber(nowMsValue) or 0, 5000) then
        return
    end
    NMCore.logChannel(
        "runtime",
        "server_battery_tick",
        string.format(
            "uuid=%s kind=%s deltaMs=%d old=%.3f new=%.3f targetSeconds=%.0f %s",
            tostring(key or ""),
            tostring(kind or "unknown"),
            math.floor(math.max(0, (tonumber(nowMsValue) or 0) - (tonumber(prevMs) or 0))),
            tonumber(oldCharge) or 0.0,
            tonumber(nextCharge) or 0.0,
            tonumber(drainSeconds) or 300,
            tostring(extra or "")
        )
    )
end

function NMServerBatteryAuthority.logEmptyStop(kind, key, reason, token)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    NMCore.logChannel(
        "runtime",
        "server_battery_empty_stop_applied",
        string.format(
            "uuid=%s kind=%s reason=%s token=%s",
            tostring(key or ""),
            tostring(kind or "unknown"),
            tostring(reason or "battery_empty"),
            tostring(token or "none")
        )
    )
end


