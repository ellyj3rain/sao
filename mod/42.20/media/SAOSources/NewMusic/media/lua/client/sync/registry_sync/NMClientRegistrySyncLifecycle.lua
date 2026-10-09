local NMClientRegistrySyncState = require "sync/registry_sync/NMClientRegistrySyncState"
local NMClientRegistrySyncTiming = require "sync/registry_sync/NMClientRegistrySyncTiming"

local NMClientRegistrySyncLifecycle = {}
local MOVEMENT_CHECK_CADENCE_SHORT_TICKS = 10

local function wakeShortMovementCheck(state)
    local target = NMClientRegistrySyncState.ensure(state)
    NMClientRegistrySyncState.wakeMovementCheckNormalized(target, target.tick, MOVEMENT_CHECK_CADENCE_SHORT_TICKS)
end

function NMClientRegistrySyncLifecycle.onRegistrySyncAck(state)
    local target = NMClientRegistrySyncState.ensure(state)
    target.syncPending = false
    target.syncAttempts = 0
    NMClientRegistrySyncState.clearAllFlights(target)
    wakeShortMovementCheck(target)
end

function NMClientRegistrySyncLifecycle.onRegistryUpdate(state)
    local target = NMClientRegistrySyncState.ensure(state)
    -- A registry_update indicates the server is actively streaming snapshot/update data.
    target.syncPending = false
    NMClientRegistrySyncState.clearAllFlights(target)
    wakeShortMovementCheck(target)
end

function NMClientRegistrySyncLifecycle.onServerCommand(state, command)
    if command == "registry_sync_ack" then
        NMClientRegistrySyncLifecycle.onRegistrySyncAck(state)
    elseif command == "registry_update" then
        NMClientRegistrySyncLifecycle.onRegistryUpdate(state)
    elseif command == "registry_snapshot_chunk" or command == "state" then
        wakeShortMovementCheck(state)
    end
end

function NMClientRegistrySyncLifecycle.resolveInitialSyncTimeout(state, currentTick, timeoutTicks)
    local target = NMClientRegistrySyncState.ensure(state)
    if target.initialSyncInFlight ~= true then
        return false
    end
    if not NMClientRegistrySyncTiming.isTimeoutReached(currentTick, target.initialSyncRequestTick, timeoutTicks) then
        return false
    end
    NMClientRegistrySyncState.clearInitialSyncFlight(target)
    return true
end

function NMClientRegistrySyncLifecycle.resolveResyncTimeout(state, currentTick, timeoutTicks)
    local target = NMClientRegistrySyncState.ensure(state)
    if target.resyncInFlight ~= true then
        return false
    end
    if not NMClientRegistrySyncTiming.isTimeoutReached(currentTick, target.resyncRequestTick, timeoutTicks) then
        return false
    end
    NMClientRegistrySyncState.clearResyncFlight(target)
    local nextTick = tonumber(target.resyncNextTick) or 0
    if (tonumber(currentTick) or 0) > nextTick then
        target.resyncNextTick = tonumber(currentTick) or 0
    end
    wakeShortMovementCheck(target)
    return true
end

return NMClientRegistrySyncLifecycle
