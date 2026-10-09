local NMClientRegistrySyncState = {}

function NMClientRegistrySyncState.defaults()
    return {
        syncPending = false,
        syncAttempts = 0,
        syncNextTick = 0,
        inventorySyncPending = false,
        inventorySyncSent = false,
        initialSyncInFlight = false,
        initialSyncRequestTick = 0,
        resyncInFlight = false,
        resyncRequestTick = 0,
        resyncNextTick = 0,
        resyncCheckNextTick = 0,
        movementCheckCadenceTicks = 10,
        resyncLastRequestMs = 0,
        lastX = nil,
        lastY = nil,
        lastZ = nil,
        tick = 0
    }
end

function NMClientRegistrySyncState.ensure(state)
    local target = type(state) == "table" and state or {}
    local defaults = NMClientRegistrySyncState.defaults()
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function NMClientRegistrySyncState.resetInitialSync(state, pending)
    local target = NMClientRegistrySyncState.ensure(state)
    local enabled = pending == true
    target.syncPending = enabled
    target.syncAttempts = 0
    target.syncNextTick = 0
    target.inventorySyncPending = enabled
    target.inventorySyncSent = false
    target.initialSyncInFlight = false
    target.initialSyncRequestTick = 0
    target.resyncInFlight = false
    target.resyncRequestTick = 0
    target.resyncNextTick = 0
    target.resyncCheckNextTick = 0
    target.movementCheckCadenceTicks = 10
    target.resyncLastRequestMs = 0
    target.lastX = nil
    target.lastY = nil
    target.lastZ = nil
    return target
end

function NMClientRegistrySyncState.clearInitialSyncFlight(state)
    local target = NMClientRegistrySyncState.ensure(state)
    target.initialSyncInFlight = false
    target.initialSyncRequestTick = 0
    return target
end

function NMClientRegistrySyncState.clearResyncFlight(state)
    local target = NMClientRegistrySyncState.ensure(state)
    target.resyncInFlight = false
    target.resyncRequestTick = 0
    return target
end

function NMClientRegistrySyncState.clearAllFlights(state)
    local target = NMClientRegistrySyncState.clearInitialSyncFlight(state)
    NMClientRegistrySyncState.clearResyncFlight(target)
    return target
end

function NMClientRegistrySyncState.snapshot(state)
    local target = NMClientRegistrySyncState.ensure(state)
    return {
        state = target,
        tick = tonumber(target.tick) or 0,
        syncAttempts = tonumber(target.syncAttempts) or 0,
        syncNextTick = tonumber(target.syncNextTick) or 0,
        resyncNextTick = tonumber(target.resyncNextTick) or 0,
        resyncCheckNextTick = tonumber(target.resyncCheckNextTick) or 0,
        movementCheckCadenceTicks = tonumber(target.movementCheckCadenceTicks) or 10,
        resyncLastRequestMs = tonumber(target.resyncLastRequestMs) or 0,
        lastX = target.lastX ~= nil and (tonumber(target.lastX) or 0) or nil,
        lastY = target.lastY ~= nil and (tonumber(target.lastY) or 0) or nil,
        lastZ = target.lastZ ~= nil and (tonumber(target.lastZ) or 0) or nil
    }
end

function NMClientRegistrySyncState.observeSchedulerTick(state, tickStep)
    local target = NMClientRegistrySyncState.ensure(state)
    target.tick = (tonumber(target.tick) or 0) + math.max(1, tonumber(tickStep) or 1)
    return target
end

function NMClientRegistrySyncState.markResyncRequestNormalized(state, tick, nowMs)
    local target = NMClientRegistrySyncState.ensure(state)
    target.resyncInFlight = true
    target.resyncRequestTick = tick
    target.resyncCheckNextTick = tick
    target.movementCheckCadenceTicks = 10
    target.resyncLastRequestMs = nowMs
    return target
end

function NMClientRegistrySyncState.markInitialSyncRequestNormalized(state, tick, nowMs, syncAttempts)
    local target = NMClientRegistrySyncState.ensure(state)
    target.syncAttempts = syncAttempts
    target.syncNextTick = tick + 120
    target.initialSyncInFlight = true
    target.initialSyncRequestTick = tick
    target.resyncLastRequestMs = nowMs
    return target
end

function NMClientRegistrySyncState.markInventorySyncSentNormalized(state, nowMs)
    local target = NMClientRegistrySyncState.ensure(state)
    target.inventorySyncSent = true
    target.inventorySyncPending = false
    target.resyncLastRequestMs = nowMs
    return target
end

function NMClientRegistrySyncState.setResyncNextTickNormalized(state, nextTick)
    local target = NMClientRegistrySyncState.ensure(state)
    target.resyncNextTick = nextTick
    return target
end

function NMClientRegistrySyncState.setResyncCheckNextTickNormalized(state, nextTick)
    local target = NMClientRegistrySyncState.ensure(state)
    target.resyncCheckNextTick = nextTick
    return target
end

function NMClientRegistrySyncState.setMovementCheckCadenceNormalized(state, cadenceTicks)
    local target = NMClientRegistrySyncState.ensure(state)
    target.movementCheckCadenceTicks = math.max(1, tonumber(cadenceTicks) or 10)
    return target
end

function NMClientRegistrySyncState.wakeMovementCheckNormalized(state, currentTick, cadenceTicks)
    local target = NMClientRegistrySyncState.setMovementCheckCadenceNormalized(state, cadenceTicks)
    local wakeTick = tonumber(currentTick) or tonumber(target.tick) or 0
    target.resyncNextTick = wakeTick
    target.resyncCheckNextTick = wakeTick
    return target
end

return NMClientRegistrySyncState
