local NMClientRegistrySyncState = require "sync/registry_sync/NMClientRegistrySyncState"
local NMClientRegistrySyncTiming = require "sync/registry_sync/NMClientRegistrySyncTiming"
local NMClientRegistrySyncRequests = require "sync/registry_sync/NMClientRegistrySyncRequests"
local NMClientRegistrySyncLifecycle = require "sync/registry_sync/NMClientRegistrySyncLifecycle"
local NMClientRegistrySyncMovement = require "sync/registry_sync/NMClientRegistrySyncMovement"

local NMClientRegistrySyncScheduler = {}
local MOVEMENT_CHECK_CADENCE_SHORT_TICKS = 10
local MOVEMENT_CHECK_CADENCE_SETTLED_TICKS = 30
local MOVEMENT_CHECK_CADENCE_IDLE_TICKS = 120

local function scheduleMovementCheck(state, currentTick, cadenceTicks)
    local cadence = math.max(1, tonumber(cadenceTicks) or MOVEMENT_CHECK_CADENCE_SHORT_TICKS)
    NMClientRegistrySyncState.setMovementCheckCadenceNormalized(state, cadence)
    NMClientRegistrySyncState.setResyncCheckNextTickNormalized(
        state,
        (tonumber(currentTick) or 0) + cadence
    )
end

local function wakeShortMovementCheck(state, currentTick)
    NMClientRegistrySyncState.wakeMovementCheckNormalized(state, currentTick, MOVEMENT_CHECK_CADENCE_SHORT_TICKS)
end

local function nextBackoffCadence(currentCadence)
    local cadence = math.max(1, tonumber(currentCadence) or MOVEMENT_CHECK_CADENCE_SHORT_TICKS)
    if cadence < MOVEMENT_CHECK_CADENCE_SETTLED_TICKS then
        return MOVEMENT_CHECK_CADENCE_SETTLED_TICKS
    end
    if cadence < MOVEMENT_CHECK_CADENCE_IDLE_TICKS then
        return MOVEMENT_CHECK_CADENCE_IDLE_TICKS
    end
    return MOVEMENT_CHECK_CADENCE_IDLE_TICKS
end

local function runInitialSync(snapshot, player, timing)
    local state = snapshot.state
    if state.syncPending ~= true then
        return false
    end
    if state.initialSyncInFlight == true then
        if not NMClientRegistrySyncLifecycle.resolveInitialSyncTimeout(state, snapshot.tick, timing.timeoutTicks) then
            return true
        end
    end
    if snapshot.syncAttempts >= 5 then
        state.syncPending = false
        return false
    end
    if not NMClientRegistrySyncTiming.isDueNow(snapshot.tick, snapshot.syncNextTick) then
        return false
    end
    if NMClientRegistrySyncTiming.isCooldownReady(snapshot.resyncLastRequestMs, timing.nowMs, timing.cooldownMs) then
        if NMClientRegistrySyncRequests.sendSyncRequest(player) then
            NMClientRegistrySyncState.markInitialSyncRequestNormalized(
                state,
                snapshot.tick,
                timing.nowMs,
                snapshot.syncAttempts + 1
            )
        end
    else
        state.syncNextTick = snapshot.tick + 30
    end
    return false
end

local function runInventorySync(snapshot, player, timing)
    local state = snapshot.state
    if state.inventorySyncPending ~= true or state.inventorySyncSent == true then
        return
    end
    if not NMClientRegistrySyncTiming.isCooldownReady(snapshot.resyncLastRequestMs, timing.nowMs, timing.cooldownMs) then
        return
    end
    if NMClientRegistrySyncRequests.sendInventorySyncRequest(player) then
        NMClientRegistrySyncState.markInventorySyncSentNormalized(state, timing.nowMs)
    end
end

local function runMovementResync(snapshot, player, timing)
    local state = snapshot.state
    if not NMClientRegistrySyncTiming.isDueNow(snapshot.tick, snapshot.resyncNextTick) then
        NMClientRegistrySyncState.setResyncCheckNextTickNormalized(state, snapshot.resyncNextTick)
        return
    end
    local sample = NMClientRegistrySyncMovement.samplePlayerPosition(player)
    if not sample then
        scheduleMovementCheck(state, snapshot.tick, snapshot.movementCheckCadenceTicks)
        return
    end
    local moved = NMClientRegistrySyncMovement.hasMoved(snapshot, sample, timing.moveDist2)
    local cooldownReady = NMClientRegistrySyncTiming.isCooldownReady(snapshot.resyncLastRequestMs, timing.nowMs, timing.cooldownMs)
    if moved and state.resyncInFlight ~= true and cooldownReady then
        if NMClientRegistrySyncRequests.sendSyncRequest(player) then
            NMClientRegistrySyncState.markResyncRequestNormalized(state, snapshot.tick, timing.nowMs)
            NMClientRegistrySyncState.setResyncNextTickNormalized(state, snapshot.tick + timing.intervalTicks)
            NMClientRegistrySyncMovement.updatePositionCache(state, sample)
            wakeShortMovementCheck(state, snapshot.tick + timing.intervalTicks)
            return
        end
    end
    if moved and state.resyncInFlight ~= true then
        scheduleMovementCheck(state, snapshot.tick, MOVEMENT_CHECK_CADENCE_SHORT_TICKS)
        return
    end
    scheduleMovementCheck(state, snapshot.tick, nextBackoffCadence(snapshot.movementCheckCadenceTicks))
end

function NMClientRegistrySyncScheduler.shouldRunThisTick(state)
    if not NMCore.isMPClientRuntime() then
        return false, "sp_runtime"
    end
    local snapshot = NMClientRegistrySyncState.snapshot(state)
    local timeoutTicks = NMRuntimeConfig.getRegistryRequestTimeoutTicks and NMRuntimeConfig.getRegistryRequestTimeoutTicks() or 180
    if snapshot.state.syncPending == true then
        if snapshot.state.initialSyncInFlight == true then
            if NMClientRegistrySyncTiming.isTimeoutReached(snapshot.tick, snapshot.state.initialSyncRequestTick, timeoutTicks) then
                return true, "initial_sync_timeout"
            end
            return false, "initial_sync_in_flight"
        end
        if NMClientRegistrySyncTiming.isDueNow(snapshot.tick, snapshot.syncNextTick) then
            return true, "initial_sync_due"
        end
        return false, "initial_sync_wait"
    end
    if snapshot.state.inventorySyncPending == true and snapshot.state.inventorySyncSent ~= true then
        return true, "inventory_sync_pending"
    end
    if snapshot.state.resyncInFlight == true then
        if NMClientRegistrySyncTiming.isTimeoutReached(snapshot.tick, snapshot.state.resyncRequestTick, timeoutTicks) then
            return true, "resync_timeout"
        end
        return false, "resync_in_flight"
    end
    if not NMClientRegistrySyncTiming.isDueNow(snapshot.tick, snapshot.resyncNextTick) then
        return false, "movement_interval_wait"
    end
    if NMClientRegistrySyncTiming.isDueNow(snapshot.tick, snapshot.resyncCheckNextTick) then
        return true, "movement_check_due"
    end
    return false, "movement_check_wait"
end

function NMClientRegistrySyncScheduler.getNextRunTick(state)
    if not NMCore.isMPClientRuntime() then
        return math.huge
    end
    local snapshot = NMClientRegistrySyncState.snapshot(state)
    local timeoutTicks = NMRuntimeConfig.getRegistryRequestTimeoutTicks and NMRuntimeConfig.getRegistryRequestTimeoutTicks() or 180
    if snapshot.state.syncPending == true then
        if snapshot.state.initialSyncInFlight == true then
            return (tonumber(snapshot.state.initialSyncRequestTick) or snapshot.tick) + math.max(30, tonumber(timeoutTicks) or 180)
        end
        return tonumber(snapshot.syncNextTick) or snapshot.tick
    end
    if snapshot.state.inventorySyncPending == true and snapshot.state.inventorySyncSent ~= true then
        return snapshot.tick
    end
    if snapshot.state.resyncInFlight == true then
        return (tonumber(snapshot.state.resyncRequestTick) or snapshot.tick) + math.max(30, tonumber(timeoutTicks) or 180)
    end
    return math.max(
        tonumber(snapshot.resyncNextTick) or snapshot.tick,
        tonumber(snapshot.resyncCheckNextTick) or snapshot.tick
    )
end

function NMClientRegistrySyncScheduler.onTick(state, player)
    if not NMCore.isMPClientRuntime() then
        return false
    end
    local shouldRun, _reason = NMClientRegistrySyncScheduler.shouldRunThisTick(state)
    if shouldRun ~= true then
        return false
    end
    local snapshot = NMClientRegistrySyncState.snapshot(state)
    local timing = NMClientRegistrySyncTiming.resolveTickWindow()
    local initialSyncBlocked = runInitialSync(snapshot, player, timing)
    if initialSyncBlocked == true then
        return true
    end
    runInventorySync(snapshot, player, timing)
    NMClientRegistrySyncLifecycle.resolveResyncTimeout(snapshot.state, snapshot.tick, timing.timeoutTicks)
    runMovementResync(snapshot, player, timing)
    return true
end

return NMClientRegistrySyncScheduler
