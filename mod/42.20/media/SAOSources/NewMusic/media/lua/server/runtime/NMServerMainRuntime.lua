NMServerMainRuntime = NMServerMainRuntime or {}

local SERVER_ACTIVE_LANE_INTERVAL_TICKS = 10
local SERVER_SLOW_LANE_INTERVAL_TICKS = 30
local SERVER_MAINTENANCE_LANE_INTERVAL_TICKS = 120
local SERVER_SCHEDULER_LOG_INTERVAL_MS = 5000
local SERVER_WRAPPER_LOG_INTERVAL_MS = 5000

local serverSchedulerState = NMServerMainRuntime._serverSchedulerState or {
    tick = 0,
    lastLogMs = 0,
    counters = {}
}
local serverWrapperDiag = NMServerMainRuntime._serverWrapperDiag or {
    lastLogMs = 0,
    counters = {},
    stages = {}
}
local serverExecutorInterestState = NMServerMainRuntime._serverExecutorInterestState or {
    executor = nil,
    activeColdUntilTick = 0
}

NMServerMainRuntime._serverSchedulerState = serverSchedulerState
NMServerMainRuntime._serverWrapperDiag = serverWrapperDiag
NMServerMainRuntime._serverExecutorInterestState = serverExecutorInterestState
NMServerMainRuntime._tickHookInstalled = NMServerMainRuntime._tickHookInstalled == true

local function canRunAuthoritativeWorldMutation()
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true then
        return false
    end
    if NMAuthorityContract and NMAuthorityContract.canMutateDurableStateAtRuntime then
        return NMAuthorityContract.canMutateDurableStateAtRuntime() == true
    end
    return true
end

local function isMultiplayerRuntime()
    return NMCore and NMCore.isMultiplayerMode and NMCore.isMultiplayerMode() == true
end

local function isMPServerAuthority()
    return NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority() == true
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

local function getSchedulerTick()
    return tonumber(serverSchedulerState.tick) or 0
end

function NMServerMainRuntime.getSchedulerTick()
    return getSchedulerTick()
end

local function shouldRunCadence(interval)
    local tick = getSchedulerTick()
    return interval > 0 and (tick % interval) == 0
end

local function shouldWakeForCadence(interval)
    local tick = tonumber(serverSchedulerState.tick) or 0
    local cadence = tonumber(interval) or 0
    if cadence <= 0 then
        return false
    end
    local remainder = tick % cadence
    return remainder == 0 or remainder == (cadence - 1)
end

local function nextWakeForCadenceTick(interval)
    local tick = getSchedulerTick()
    return NMServerMainRuntime.getNextWakeForCadenceTick(tick, interval)
end

function NMServerMainRuntime.getNextWakeForCadenceTick(tick, interval)
    local currentTick = tonumber(tick) or 0
    local cadence = tonumber(interval) or 0
    if cadence <= 0 then
        return currentTick
    end
    local remainder = currentTick % cadence
    if remainder == 0 or remainder == (cadence - 1) then
        return currentTick
    end
    if remainder < (cadence - 1) then
        return currentTick + ((cadence - 1) - remainder)
    end
    return currentTick + 1
end

local function nextFutureWakeForCadenceTick(interval)
    return NMServerMainRuntime.getNextWakeForCadenceTick(getSchedulerTick() + 1, interval)
end

local function countScheduler(name)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    serverSchedulerState.counters[key] = (tonumber(serverSchedulerState.counters[key]) or 0) + 1
end

local function countWrapper(name)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    serverWrapperDiag.counters[key] = (tonumber(serverWrapperDiag.counters[key]) or 0) + 1
end

local function supportsExecutorActiveDeadlines(executor)
    return executor ~= nil and executor.getNextActiveWorkCheckTick ~= nil
end

local function getExecutorInterestState(executor)
    if serverExecutorInterestState.executor ~= executor then
        serverExecutorInterestState.executor = executor
        serverExecutorInterestState.activeColdUntilTick = 0
    end
    return serverExecutorInterestState
end

local function shouldSkipExecutorActiveCheck(executor, currentTick)
    if supportsExecutorActiveDeadlines(executor) ~= true then
        return false
    end
    local state = getExecutorInterestState(executor)
    local coldUntilTick = tonumber(state.activeColdUntilTick) or 0
    if coldUntilTick > currentTick then
        countWrapper("has_any_executor_active_skip_cold")
        return true
    end
    if coldUntilTick > 0 then
        countWrapper("executor_active_cold_expired")
        state.activeColdUntilTick = 0
    end
    return false
end

local function recordExecutorActiveCheckResult(executor, currentTick, isActive, maintenanceWakeDue)
    if supportsExecutorActiveDeadlines(executor) ~= true then
        return
    end
    local state = getExecutorInterestState(executor)
    if isActive == true then
        state.activeColdUntilTick = 0
        return
    end
    local nextCheckTick = tonumber(executor.getNextActiveWorkCheckTick())
    if nextCheckTick and nextCheckTick <= currentTick and maintenanceWakeDue ~= true then
        nextCheckTick = nextWakeForCadenceTick(SERVER_MAINTENANCE_LANE_INTERVAL_TICKS)
    end
    if nextCheckTick and nextCheckTick > currentTick and nextCheckTick < math.huge then
        state.activeColdUntilTick = nextCheckTick
        countWrapper("executor_active_cold_until_set")
    else
        state.activeColdUntilTick = 0
    end
end

local function resolveExecutorActiveInterest(executor, currentTick, maintenanceWakeDue)
    if not (executor and executor.hasActiveWork) then
        return false
    end
    if shouldSkipExecutorActiveCheck(executor, currentTick) == true then
        return false
    end
    countWrapper("has_any_executor_active_check")
    local activeInterest = executor.hasActiveWork() == true
    recordExecutorActiveCheckResult(executor, currentTick, activeInterest, maintenanceWakeDue)
    return activeInterest
end

local function isExecutorActiveCheckDue(executor, currentTick)
    if supportsExecutorActiveDeadlines(executor) ~= true then
        return false
    end
    local nextCheckTick = tonumber(executor.getNextActiveWorkCheckTick())
    return nextCheckTick ~= nil and nextCheckTick <= (tonumber(currentTick) or 0)
end

local function resolveExecutorMaintenanceInterest(executor, maintenanceWakeDue, executorWakeDue)
    if not (executor and executor.hasMaintenanceWork) then
        return false
    end
    if maintenanceWakeDue ~= true and executorWakeDue ~= true then
        countWrapper("has_any_executor_maintenance_skip_not_due")
        return false
    end
    countWrapper("has_any_executor_maintenance_check_due")
    return executor.hasMaintenanceWork() == true
end

local function beginWrapperStage()
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return 0
    end
    return nowRealMs()
end

local function recordWrapperStage(name, startedMs)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    local stage = serverWrapperDiag.stages[key]
    if not stage then
        stage = { count = 0, sumMs = 0, maxMs = 0 }
        serverWrapperDiag.stages[key] = stage
    end
    local elapsedMs = math.max(0, nowRealMs() - (tonumber(startedMs) or 0))
    stage.count = (tonumber(stage.count) or 0) + 1
    stage.sumMs = (tonumber(stage.sumMs) or 0) + elapsedMs
    stage.maxMs = math.max(tonumber(stage.maxMs) or 0, elapsedMs)
end

local function flushScheduler()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(serverSchedulerState.lastLogMs) or 0)) < SERVER_SCHEDULER_LOG_INTERVAL_MS then
        return
    end
    serverSchedulerState.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(serverSchedulerState.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        serverSchedulerState.counters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "server_tick_scheduler", table.concat(parts, " | "))
    end
end

local function flushWrapperDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(serverWrapperDiag.lastLogMs) or 0)) < SERVER_WRAPPER_LOG_INTERVAL_MS then
        return
    end
    serverWrapperDiag.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(serverWrapperDiag.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        serverWrapperDiag.counters[name] = nil
    end
    for name, stage in pairs(serverWrapperDiag.stages) do
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
        serverWrapperDiag.stages[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "server_tick_wrapper", table.concat(parts, " | "))
    end
end

function NMServerMainRuntime.getActiveZombieExecutor()
    local strategy = NMZombieLiveStrategy and NMZombieLiveStrategy.getLiveVisualStrategy and NMZombieLiveStrategy.getLiveVisualStrategy() or ""
    if strategy == "sp_runtime_attach" then
        return NMServerSPZombieAssignmentFlow
    end
    if strategy == "mp_assignment_flow" then
        return NMServerMPZombieAssignmentFlow
    end
    return nil
end

function NMServerMainRuntime.shouldRegisterZombieUpdateHook(activeZombieExecutor)
    local executor = activeZombieExecutor or NMServerMainRuntime.getActiveZombieExecutor()
    if executor == NMServerSPZombieAssignmentFlow then
        return false, "sp_scan_only"
    end
    if not (executor and executor.onZombieUpdate) then
        return false, "missing_handler"
    end
    return true, "direct_executor"
end

local function shouldRunTargetPublisher()
    return canRunAuthoritativeWorldMutation()
        and isMultiplayerRuntime()
        and NMServerZombieVisualTargetPublisher
        and NMServerZombieVisualTargetPublisher.onTick
end

local function hasLegacyServerTickHandler()
    return type(NMDevicesServer) == "table" and NMDevicesServer.onTick ~= nil
end

local function hasLegacyServerTickPending(mpAuthority)
    if hasLegacyServerTickHandler() ~= true then
        return false
    end
    if mpAuthority == true then
        return true
    end
    return type(NMDevicesServer) == "table"
        and NMDevicesServer.hasPendingWork
        and NMDevicesServer.hasPendingWork() == true
end

local function hasWorldSourceRefreshWork(mpAuthority)
    return mpAuthority == true
        and NMServerSourceRefreshTick
        and NMServerSourceRefreshTick.hasWorldSources
        and NMServerSourceRefreshTick.hasWorldSources() == true
        and shouldWakeForCadence(SERVER_ACTIVE_LANE_INTERVAL_TICKS) == true
end

local function getNextWorldSourceRefreshWakeTick(mpAuthority)
    if mpAuthority == true
        and NMServerSourceRefreshTick
        and NMServerSourceRefreshTick.hasWorldSources
        and NMServerSourceRefreshTick.hasWorldSources() == true then
        return nextFutureWakeForCadenceTick(SERVER_ACTIVE_LANE_INTERVAL_TICKS)
    end
    return math.huge
end

local function hasVehicleTrackWork(mpAuthority)
    return mpAuthority == true
        and NMServerVehicleTrackSchedulerTick
        and NMServerVehicleTrackSchedulerTick.hasImmediateWork
        and NMServerVehicleTrackSchedulerTick.hasImmediateWork(getSchedulerTick()) == true
end

local function getNextVehicleTrackWakeTick(mpAuthority, currentTick)
    if mpAuthority ~= true
        or not (NMServerVehicleTrackSchedulerTick and NMServerVehicleTrackSchedulerTick.getNextActiveWorkCheckTick) then
        return math.huge
    end
    local nextTick = tonumber(NMServerVehicleTrackSchedulerTick.getNextActiveWorkCheckTick(currentTick))
    if nextTick and nextTick > (tonumber(currentTick) or 0) and nextTick < math.huge then
        return nextTick
    end
    return math.huge
end

function NMServerMainRuntime.advanceSchedulerTick(tickStep)
    local step = math.max(1, tonumber(tickStep) or 1)
    serverSchedulerState.tick = (tonumber(serverSchedulerState.tick) or 0) + step
    local activeZombieExecutor = NMServerMainRuntime.getActiveZombieExecutor()
    if activeZombieExecutor and activeZombieExecutor.observeSchedulerTick and canRunAuthoritativeWorldMutation() then
        activeZombieExecutor.observeSchedulerTick(step)
    end
end

function NMServerMainRuntime.getNextTickGateWakeTick()
    local currentTick = getSchedulerTick()
    if canRunAuthoritativeWorldMutation() ~= true then
        return currentTick + 1
    end
    local mpAuthority = isMPServerAuthority() == true
    if hasVehicleTrackWork(mpAuthority) == true or hasWorldSourceRefreshWork(mpAuthority) == true then
        return currentTick + 1
    end
    if NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.hasPendingWork and NMServerZombieCorpseCarry.hasPendingWork() == true then
        return currentTick + 1
    end
    if hasLegacyServerTickHandler() == true then
        if not (type(NMDevicesServer) == "table" and NMDevicesServer.hasPendingWork) then
            return currentTick + 1
        end
        if NMDevicesServer.hasPendingWork() == true then
            return currentTick + 1
        end
    end

    local nextWakeTick = nextFutureWakeForCadenceTick(SERVER_MAINTENANCE_LANE_INTERVAL_TICKS)
    if mpAuthority == true then
        nextWakeTick = math.min(nextWakeTick, getNextVehicleTrackWakeTick(mpAuthority, currentTick))
        nextWakeTick = math.min(nextWakeTick, getNextWorldSourceRefreshWakeTick(mpAuthority))
        if NMServerModeReconcile and NMServerModeReconcile.onTick then
            nextWakeTick = math.min(nextWakeTick, nextFutureWakeForCadenceTick(SERVER_SLOW_LANE_INTERVAL_TICKS))
        end
        if NMServerZombiePulseTick and NMServerZombiePulseTick.hasActiveWork and NMServerZombiePulseTick.hasActiveWork() == true then
            nextWakeTick = math.min(nextWakeTick, nextFutureWakeForCadenceTick(SERVER_ACTIVE_LANE_INTERVAL_TICKS))
        end
        if shouldRunTargetPublisher() and NMServerZombieVisualTargetPublisher.hasPublishWork then
            nextWakeTick = math.min(nextWakeTick, nextFutureWakeForCadenceTick(SERVER_ACTIVE_LANE_INTERVAL_TICKS))
        end
        if hasLegacyServerTickHandler() == true then
            nextWakeTick = math.min(nextWakeTick, nextFutureWakeForCadenceTick(SERVER_SLOW_LANE_INTERVAL_TICKS))
        end
    end
    local activeZombieExecutor = NMServerMainRuntime.getActiveZombieExecutor()
    if supportsExecutorActiveDeadlines(activeZombieExecutor) == true then
        local executorWakeTick = tonumber(activeZombieExecutor.getNextActiveWorkCheckTick())
        if executorWakeTick and executorWakeTick > currentTick and executorWakeTick < math.huge then
            nextWakeTick = math.min(nextWakeTick, executorWakeTick)
        end
    end
    return nextWakeTick
end

function NMServerMainRuntime.hasAnyTickWork()
    local canMutate = canRunAuthoritativeWorldMutation()
    local mpAuthority = isMPServerAuthority()
    local currentTick = getSchedulerTick()
    local activeWakeDue = shouldWakeForCadence(SERVER_ACTIVE_LANE_INTERVAL_TICKS)
    local slowWakeDue = shouldWakeForCadence(SERVER_SLOW_LANE_INTERVAL_TICKS)
    local maintenanceWakeDue = shouldWakeForCadence(SERVER_MAINTENANCE_LANE_INTERVAL_TICKS)
    if canMutate and NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.hasPendingWork and NMServerZombieCorpseCarry.hasPendingWork() == true then
        return true, "corpse_carry_pending"
    end
    if hasVehicleTrackWork(mpAuthority) == true then
        return true, "vehicle_track_world_sources"
    end
    if hasWorldSourceRefreshWork(mpAuthority) == true then
        return true, "source_refresh_world_sources"
    end
    if mpAuthority and slowWakeDue and NMServerModeReconcile and NMServerModeReconcile.onTick then
        return true, "mode_reconcile_due"
    end
    if mpAuthority and activeWakeDue and NMServerZombiePulseTick and NMServerZombiePulseTick.hasActiveWork and NMServerZombiePulseTick.hasActiveWork() == true then
        return true, "zombie_pulse_active"
    end
    local activeZombieExecutor = NMServerMainRuntime.getActiveZombieExecutor()
    local hasZombieExecutor = activeZombieExecutor ~= nil and activeZombieExecutor.onTick ~= nil and canMutate
    if hasZombieExecutor then
        local executorWakeDue = isExecutorActiveCheckDue(activeZombieExecutor, currentTick)
        local executorActiveInterest = resolveExecutorActiveInterest(activeZombieExecutor, currentTick, maintenanceWakeDue)
        if executorActiveInterest then
            return true, "executor_active_interest"
        end
        local executorMaintenanceInterest = resolveExecutorMaintenanceInterest(activeZombieExecutor, maintenanceWakeDue, executorWakeDue)
        if executorMaintenanceInterest == true then
            return true, "executor_maintenance_interest"
        end
    end
    if mpAuthority
        and shouldRunTargetPublisher()
        and activeWakeDue
        and NMServerZombieVisualTargetPublisher.hasPublishWork
        and (NMServerZombieVisualTargetPublisher.hasPublishWork(currentTick) == true
            or NMServerZombieVisualTargetPublisher.hasPublishWork(currentTick + 1) == true) then
        return true, "target_publisher_due"
    end
    if mpAuthority and maintenanceWakeDue and NMServerRegistryTick and NMServerRegistryTick.hasWorldSources and NMServerRegistryTick.hasWorldSources() == true then
        return true, "registry_tick_due"
    end
    if slowWakeDue and hasLegacyServerTickPending(mpAuthority) == true then
        return true, "legacy_tick_pending"
    end
    return false, "idle"
end

function NMServerMainRuntime.isTickHookInstalled()
    return NMServerMainRuntime._tickHookInstalled == true
end

function NMServerMainRuntime.installTickHook()
    if NMServerMainRuntime._tickHookInstalled == true then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(NMServerMainRuntime.onTick)
        NMServerMainRuntime._tickHookInstalled = true
    end
end

function NMServerMainRuntime.removeTickHook()
    if NMServerMainRuntime._tickHookInstalled ~= true then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(NMServerMainRuntime.onTick)
        NMServerMainRuntime._tickHookInstalled = false
    end
end

function NMServerMainRuntime.shouldKeepServerTickGateRegistered()
    if NMServerMainRuntime.isTickHookInstalled and NMServerMainRuntime.isTickHookInstalled() == true then
        return true
    end
    local mpAuthority = isMPServerAuthority() == true
    if hasVehicleTrackWork(mpAuthority) == true or hasWorldSourceRefreshWork(mpAuthority) == true then
        return true
    end
    local nextVehicleTrackWakeTick = getNextVehicleTrackWakeTick(mpAuthority, getSchedulerTick())
    if nextVehicleTrackWakeTick < math.huge then
        return true
    end
    local nextWorldSourceRefreshWakeTick = getNextWorldSourceRefreshWakeTick(mpAuthority)
    if nextWorldSourceRefreshWakeTick < math.huge then
        return true
    end
    if NMServerZombieCorpseCarry
        and NMServerZombieCorpseCarry.hasPendingWork
        and NMServerZombieCorpseCarry.hasPendingWork() == true then
        return true
    end
    if hasLegacyServerTickHandler() == true
        and type(NMDevicesServer) == "table"
        and NMDevicesServer.hasPendingWork
        and NMDevicesServer.hasPendingWork() == true then
        return true
    end
    return false
end

function NMServerMainRuntime.onClientCommand(module, command, player, args)
    if NMServerTickGate and NMServerTickGate.wake then
        NMServerTickGate.wake("client_command")
    end
    if NMServerIntentRouter and NMServerIntentRouter.onClientCommand then
        NMServerIntentRouter.onClientCommand(module, command, player, args)
    end
    if type(NMDevicesServer) == "table" and NMDevicesServer.onClientCommand then
        NMDevicesServer.onClientCommand(module, command, player, args)
    end
end

function NMServerMainRuntime.onZombieDead(zombie)
    if NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.onZombieDead then
        NMServerZombieCorpseCarry.onZombieDead(zombie)
    end
    if NMServerZombieCorpseCarry
        and NMServerZombieCorpseCarry.hasPendingWork
        and NMServerZombieCorpseCarry.hasPendingWork() == true
        and NMServerTickGate
        and NMServerTickGate.wake then
        NMServerTickGate.wake("zombie_dead")
    end
end

function NMServerMainRuntime.onDeadBodySpawn(body)
    if NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.onDeadBodySpawn then
        NMServerZombieCorpseCarry.onDeadBodySpawn(body)
    end
    if NMServerZombieCorpseCarry
        and NMServerZombieCorpseCarry.hasPendingWork
        and NMServerZombieCorpseCarry.hasPendingWork() == true
        and NMServerTickGate
        and NMServerTickGate.wake then
        NMServerTickGate.wake("dead_body_spawn")
    end
end

function NMServerMainRuntime.onTick()
    local wrapperPreStartedMs = beginWrapperStage()
    countWrapper("wrapper_tick")
    local activeLaneDue = shouldRunCadence(SERVER_ACTIVE_LANE_INTERVAL_TICKS)
    local slowLaneDue = shouldRunCadence(SERVER_SLOW_LANE_INTERVAL_TICKS)
    local maintenanceLaneDue = shouldRunCadence(SERVER_MAINTENANCE_LANE_INTERVAL_TICKS)
    local mpAuthority = isMPServerAuthority()
    local canMutate = canRunAuthoritativeWorldMutation()
    local hasZombieExecutor = false
    local executorActiveInterest = false
    local executorShouldRunActiveLane = false
    local executorShouldRunMaintenanceLane = false
    local executorMaintenanceInterest = false
    local activeZombieExecutor = nil
    local corpseCarryPending = false
    local hasLegacyServerTick = hasLegacyServerTickHandler()
    local legacyServerTickPending = hasLegacyServerTickPending(mpAuthority)
    local targetPublisherHasWork = false

    local executorLookupStartedMs = beginWrapperStage()
    activeZombieExecutor = NMServerMainRuntime.getActiveZombieExecutor()
    recordWrapperStage("server_wrapper_executor_lookup", executorLookupStartedMs)
    hasZombieExecutor = activeZombieExecutor ~= nil and activeZombieExecutor.onTick ~= nil and canMutate
    corpseCarryPending = canMutate
        and NMServerZombieCorpseCarry
        and NMServerZombieCorpseCarry.hasPendingWork
        and NMServerZombieCorpseCarry.hasPendingWork() == true
    targetPublisherHasWork = mpAuthority
        and shouldRunTargetPublisher()
        and activeLaneDue
        and NMServerZombieVisualTargetPublisher.hasPublishWork
        and NMServerZombieVisualTargetPublisher.hasPublishWork(serverSchedulerState.tick) == true
    countWrapper(activeLaneDue and "active_lane_due" or "active_lane_not_due")
    countWrapper(slowLaneDue and "slow_lane_due" or "slow_lane_not_due")
    countWrapper(maintenanceLaneDue and "maintenance_lane_due" or "maintenance_lane_not_due")
    countWrapper(mpAuthority and "mp_authority" or "sp_authority_or_client")
    countWrapper(canMutate and "can_mutate" or "cannot_mutate")
    countWrapper(hasZombieExecutor and "has_zombie_executor" or "no_zombie_executor")
    countWrapper(corpseCarryPending and "corpse_carry_pending" or "corpse_carry_idle")
    countWrapper(hasLegacyServerTick and "legacy_server_tick_present" or "legacy_server_tick_absent")
    countWrapper(legacyServerTickPending and "legacy_server_tick_pending" or "legacy_server_tick_idle")
    countWrapper(hasZombieExecutor and "executor_observe_scheduler_tick" or "executor_observe_scheduler_tick_skip")
    recordWrapperStage("server_wrapper_pre", wrapperPreStartedMs)

    local mpBranchStartedMs = beginWrapperStage()
    if mpAuthority and NMServerVehicleTrackSchedulerTick and NMServerVehicleTrackSchedulerTick.onTick and NMServerVehicleTrackSchedulerTick.hasImmediateWork and NMServerVehicleTrackSchedulerTick.hasImmediateWork(getSchedulerTick()) then
        countScheduler("vehicle_track_run")
        NMServerVehicleTrackSchedulerTick.onTick()
    else
        countScheduler("vehicle_track_skip")
    end
    if mpAuthority and activeLaneDue and NMServerSourceRefreshTick and NMServerSourceRefreshTick.onTick and NMServerSourceRefreshTick.hasWorldSources and NMServerSourceRefreshTick.hasWorldSources() then
        countScheduler("source_refresh_run")
        NMServerSourceRefreshTick.onTick()
    else
        countScheduler("source_refresh_skip")
    end
    if mpAuthority and slowLaneDue and NMServerModeReconcile and NMServerModeReconcile.onTick then
        countScheduler("mode_reconcile_run")
        NMServerModeReconcile.onTick()
    else
        countScheduler("mode_reconcile_skip")
    end
    if mpAuthority and activeLaneDue and NMServerZombiePulseTick and NMServerZombiePulseTick.onTick and NMServerZombiePulseTick.hasActiveWork and NMServerZombiePulseTick.hasActiveWork() then
        countScheduler("zombie_pulse_run")
        NMServerZombiePulseTick.onTick()
    else
        countScheduler("zombie_pulse_skip")
    end
    recordWrapperStage("server_wrapper_mp_branches", mpBranchStartedMs)

    if corpseCarryPending and NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.onTick then
        countWrapper("corpse_carry_tick")
        NMServerZombieCorpseCarry.onTick()
    else
        countWrapper(corpseCarryPending and "corpse_carry_no_handler" or "corpse_carry_noop_exit")
    end

    local executorRoutingStartedMs = beginWrapperStage()
    if hasZombieExecutor then
        local executorWakeDue = isExecutorActiveCheckDue(activeZombieExecutor, getSchedulerTick())
        local executorInterestStartedMs = beginWrapperStage()
        executorActiveInterest = resolveExecutorActiveInterest(activeZombieExecutor, getSchedulerTick(), maintenanceLaneDue)
        executorMaintenanceInterest = resolveExecutorMaintenanceInterest(activeZombieExecutor, maintenanceLaneDue, executorWakeDue)
        recordWrapperStage("server_wrapper_executor_interest", executorInterestStartedMs)
        executorShouldRunActiveLane = executorActiveInterest and activeLaneDue
        executorShouldRunMaintenanceLane = executorActiveInterest ~= true and executorMaintenanceInterest == true and (maintenanceLaneDue or executorWakeDue)
        countWrapper(executorActiveInterest and "executor_active_interest" or "executor_idle_interest")
        countWrapper(executorMaintenanceInterest and "executor_maintenance_interest" or "executor_maintenance_idle")
        countWrapper(executorShouldRunActiveLane and "executor_active_lane_due" or "executor_active_lane_not_due")
        countWrapper(executorShouldRunMaintenanceLane and "executor_maintenance_due" or "executor_maintenance_not_due")
        if executorShouldRunActiveLane or executorShouldRunMaintenanceLane then
            countScheduler("active_zombie_executor_run")
            local executorTickStep = executorShouldRunActiveLane
                and SERVER_ACTIVE_LANE_INTERVAL_TICKS
                or (maintenanceLaneDue and SERVER_MAINTENANCE_LANE_INTERVAL_TICKS or SERVER_ACTIVE_LANE_INTERVAL_TICKS)
            activeZombieExecutor.onTick(executorTickStep)
        else
            countScheduler("active_zombie_executor_skip")
            countWrapper("executor_noop_exit")
        end
    else
        countScheduler("active_zombie_executor_skip")
        countWrapper("executor_missing_noop_exit")
    end
    recordWrapperStage("server_wrapper_executor_routing", executorRoutingStartedMs)

    if targetPublisherHasWork then
        countScheduler("target_publisher_run")
        NMServerZombieVisualTargetPublisher.onTick(SERVER_ACTIVE_LANE_INTERVAL_TICKS, serverSchedulerState.tick)
    else
        countScheduler("target_publisher_skip")
    end
    if mpAuthority and maintenanceLaneDue and NMServerRegistryTick and NMServerRegistryTick.onTick and NMServerRegistryTick.hasWorldSources and NMServerRegistryTick.hasWorldSources() then
        countScheduler("registry_tick_run")
        NMServerRegistryTick.onTick()
    else
        countScheduler("registry_tick_skip")
    end
    if legacyServerTickPending and slowLaneDue then
        countScheduler("legacy_server_tick_run")
        NMDevicesServer.onTick()
    else
        countScheduler("legacy_server_tick_skip")
        countWrapper(hasLegacyServerTick and "legacy_server_tick_noop_exit" or "legacy_server_tick_missing")
    end
    flushScheduler()
    flushWrapperDiag()
end

function NMServerMainRuntime.onEveryOneMinute()
    if NMServerVehiclePowerTick and NMServerVehiclePowerTick.onEveryOneMinute then
        NMServerVehiclePowerTick.onEveryOneMinute()
    end
    if NMServerItemPowerTick and NMServerItemPowerTick.onEveryOneMinute then
        NMServerItemPowerTick.onEveryOneMinute()
    end
    if type(NMDevicesServer) == "table" and NMDevicesServer.onEveryOneMinute then
        NMDevicesServer.onEveryOneMinute()
    end
end

function NMServerMainRuntime.canRunAuthoritativeWorldMutation()
    return canRunAuthoritativeWorldMutation()
end

function NMServerMainRuntime.shouldLogProofVerbose()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true
end

function NMServerMainRuntime.shouldLogCorpseVerbose()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_corpse") == true
end

function NMServerMainRuntime.registerTickGate()
    NMServerTickGate.register({
        advanceTick = NMServerMainRuntime.advanceSchedulerTick,
        hasAnyTickWork = NMServerMainRuntime.hasAnyTickWork,
        getCurrentTick = NMServerMainRuntime.getSchedulerTick,
        getNextWakeTick = NMServerMainRuntime.getNextTickGateWakeTick,
        isHookInstalled = NMServerMainRuntime.isTickHookInstalled,
        installHook = NMServerMainRuntime.installTickHook,
        removeHook = NMServerMainRuntime.removeTickHook,
        shouldKeepGateRegistered = NMServerMainRuntime.shouldKeepServerTickGateRegistered
    })
end

return NMServerMainRuntime
