local NMClientRegistrySyncState = require "sync/registry_sync/NMClientRegistrySyncState"
local NMClientRegistrySyncRequests = require "sync/registry_sync/NMClientRegistrySyncRequests"
local NMClientRegistrySyncLifecycle = require "sync/registry_sync/NMClientRegistrySyncLifecycle"
local NMClientRegistrySyncScheduler = require "sync/registry_sync/NMClientRegistrySyncScheduler"

-- Client-side registry snapshot sync cadence, retries, and ACK handling.
NMClientRegistrySync = NMClientRegistrySync or {}
NMClientRegistrySync.state = NMClientRegistrySyncState.ensure(NMClientRegistrySync.state)

function NMClientRegistrySync.requestInitialSync()
    NMClientRegistrySyncState.resetInitialSync(NMClientRegistrySync.state, NMCore.isMPClientRuntime())
    if NMCore.isMPClientRuntime() and NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("registry_initial_sync")
    end
end

function NMClientRegistrySync.observeSchedulerTick(tickStep)
    NMClientRegistrySyncState.observeSchedulerTick(NMClientRegistrySync.state, tickStep)
end

function NMClientRegistrySync.shouldRunThisTick()
    return NMClientRegistrySyncScheduler.shouldRunThisTick(NMClientRegistrySync.state)
end

function NMClientRegistrySync.getNextRunTick()
    return NMClientRegistrySyncScheduler.getNextRunTick(NMClientRegistrySync.state)
end

function NMClientRegistrySync.requestNow(player, reason)
    local requested = NMClientRegistrySyncRequests.requestNow(NMClientRegistrySync.state, player, reason)
    if requested == true and NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("registry_request_now")
    end
    return requested
end

function NMClientRegistrySync.onServerCommand(command, args)
    NMClientRegistrySyncLifecycle.onServerCommand(NMClientRegistrySync.state, command)
    if NMCore.isMPClientRuntime() and NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("registry_server_command")
    end
end

function NMClientRegistrySync.onTick(player)
    return NMClientRegistrySyncScheduler.onTick(NMClientRegistrySync.state, player)
end

