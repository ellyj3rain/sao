NMClientTickGate = NMClientTickGate or {}

local LOG_INTERVAL_MS = 5000

NMClientTickGate._diag = NMClientTickGate._diag or {
    lastLogMs = 0,
    counters = {},
    stages = {}
}
NMClientTickGate._pendingTicks = tonumber(NMClientTickGate._pendingTicks) or 0
NMClientTickGate._nextWakeTick = tonumber(NMClientTickGate._nextWakeTick) or nil

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function memoryDiagEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true
end

local function countDiag(name)
    if memoryDiagEnabled() ~= true then
        return
    end
    local key = tostring(name or "unknown")
    local diag = NMClientTickGate._diag
    diag.counters[key] = (tonumber(diag.counters[key]) or 0) + 1
end

local function beginStage()
    if memoryDiagEnabled() ~= true then
        return 0
    end
    return nowRealMs()
end

local function recordStage(name, startedMs)
    if memoryDiagEnabled() ~= true then
        return
    end
    local key = tostring(name or "unknown")
    local diag = NMClientTickGate._diag
    diag.stages = diag.stages or {}
    local stage = diag.stages[key]
    if not stage then
        stage = { count = 0, sumMs = 0, maxMs = 0 }
        diag.stages[key] = stage
    end
    local elapsedMs = math.max(0, nowRealMs() - (tonumber(startedMs) or 0))
    stage.count = (tonumber(stage.count) or 0) + 1
    stage.sumMs = (tonumber(stage.sumMs) or 0) + elapsedMs
    stage.maxMs = math.max(tonumber(stage.maxMs) or 0, elapsedMs)
end

local function flushDiag()
    if memoryDiagEnabled() ~= true or not (NMCore and NMCore.logChannel) then
        return
    end
    local diag = NMClientTickGate._diag
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(diag.lastLogMs) or 0)) < LOG_INTERVAL_MS then
        return
    end
    diag.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(diag.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        diag.counters[name] = nil
    end
    for name, stage in pairs(diag.stages or {}) do
        local count = tonumber(stage.count) or 0
        if count > 0 then
            parts[#parts + 1] = string.format(
                "%s=count:%d avgMs:%.3f maxMs:%.3f",
                tostring(name),
                count,
                (tonumber(stage.sumMs) or 0) / count,
                tonumber(stage.maxMs) or 0
            )
        end
        diag.stages[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "client_tick_gate", table.concat(parts, " | "))
    end
end

local function normalizeReason(reason)
    local value = tostring(reason or "unknown")
    if value == "" then
        return "unknown"
    end
    return value
end

local function addTickListener()
    if NMClientTickGate._registered == true then
        return false
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(NMClientTickGate.onTick)
        NMClientTickGate._registered = true
        return true
    end
    return false
end

local function removeTickListener()
    if NMClientTickGate._registered ~= true then
        return false
    end
    if Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(NMClientTickGate.onTick)
        NMClientTickGate._registered = false
        return true
    end
    return false
end

function NMClientTickGate.wake(_reason)
    NMClientTickGate._nextWakeTick = nil
    countDiag("client_tick_gate_wake")
    countDiag("client_tick_gate_wake_reason_" .. normalizeReason(_reason))
    addTickListener()
end

local function getCurrentTickWithPending()
    local currentTick = 0
    if NMClientTickGate._getCurrentTick then
        currentTick = tonumber(NMClientTickGate._getCurrentTick()) or 0
    end
    return currentTick + (tonumber(NMClientTickGate._pendingTicks) or 0)
end

local function setNextWakeTick(hasWork)
    if hasWork == true or not NMClientTickGate._getNextWakeTick then
        NMClientTickGate._nextWakeTick = nil
        countDiag("client_tick_gate_next_wake_immediate")
        return
    end
    local nextWakeTick = tonumber(NMClientTickGate._getNextWakeTick())
    if nextWakeTick and nextWakeTick > getCurrentTickWithPending() and nextWakeTick < math.huge then
        NMClientTickGate._nextWakeTick = nextWakeTick
        countDiag("client_tick_gate_next_wake_set")
    else
        NMClientTickGate._nextWakeTick = nil
        countDiag("client_tick_gate_next_wake_immediate")
    end
end

local function shouldSkipForDeadline(isHookInstalled)
    if isHookInstalled == true then
        return false
    end
    local nextWakeTick = tonumber(NMClientTickGate._nextWakeTick)
    if not nextWakeTick then
        return false
    end
    return nextWakeTick > getCurrentTickWithPending()
end

function NMClientTickGate.onTick()
    NMClientTickGate._pendingTicks = (tonumber(NMClientTickGate._pendingTicks) or 0) + 1
    local isHookInstalled = NMClientTickGate._isHookInstalled and NMClientTickGate._isHookInstalled() == true or false
    if shouldSkipForDeadline(isHookInstalled) == true then
        countDiag("client_tick_gate_deadline_skip")
        countDiag(isHookInstalled and "runtime_hook_installed" or "runtime_hook_removed")
        flushDiag()
        return
    end
    countDiag("client_tick_gate_deadline_poll")

    local pendingTicks = math.max(1, tonumber(NMClientTickGate._pendingTicks) or 1)
    NMClientTickGate._pendingTicks = 0
    local advanceTick = NMClientTickGate._advanceTick
    if advanceTick then
        local advanceStartedMs = beginStage()
        advanceTick(pendingTicks)
        recordStage("client_tick_gate_advance", advanceStartedMs)
        countDiag("client_tick_gate_pending_ticks_advanced")
        countDiag("client_tick_gate_pending_ticks_advanced." .. tostring(pendingTicks))
    end

    local hasAnyTickWork = NMClientTickGate._hasAnyTickWork
    local hasWork = false
    local reason = "idle"
    if hasAnyTickWork then
        local hasWorkStartedMs = beginStage()
        hasWork, reason = hasAnyTickWork()
        recordStage("client_tick_gate_has_work", hasWorkStartedMs)
    end
    countDiag(hasWork == true and "has_work_true" or "has_work_false")
    countDiag("has_work_reason_" .. normalizeReason(reason))

    countDiag(isHookInstalled and "runtime_hook_installed" or "runtime_hook_removed")
    if hasWork == true then
        if isHookInstalled ~= true then
            if NMClientTickGate._installHook then
                NMClientTickGate._installHook()
            end
            countDiag("tick_hook_add")
            countDiag("tick_hook_wake_reason_" .. normalizeReason(reason))
        end
    elseif isHookInstalled == true then
        if NMClientTickGate._removeHook then
            NMClientTickGate._removeHook()
        end
        countDiag("tick_hook_remove")
        countDiag("tick_hook_idle_exit")
    end
    setNextWakeTick(hasWork == true)

    local keepGateRegistered = NMClientTickGate._shouldKeepGateRegistered
        and NMClientTickGate._shouldKeepGateRegistered() == true
        or false
    if hasWork ~= true and isHookInstalled ~= true and keepGateRegistered ~= true then
        removeTickListener()
    end
    flushDiag()
end

function NMClientTickGate.register(config)
    if type(config) ~= "table" then
        return
    end
    NMClientTickGate._advanceTick = config.advanceTick
    NMClientTickGate._hasAnyTickWork = config.hasAnyTickWork
    NMClientTickGate._getCurrentTick = config.getCurrentTick
    NMClientTickGate._getNextWakeTick = config.getNextWakeTick
    NMClientTickGate._isHookInstalled = config.isHookInstalled
    NMClientTickGate._installHook = config.installHook
    NMClientTickGate._removeHook = config.removeHook
    NMClientTickGate._shouldKeepGateRegistered = config.shouldKeepGateRegistered
    NMClientTickGate.wake("register")
end

return NMClientTickGate
