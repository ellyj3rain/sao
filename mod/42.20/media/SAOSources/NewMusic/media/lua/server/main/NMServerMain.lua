require "zombies/NMZombieLiveStrategy"
require "zombies/NMZombieAttachedDefinitions"
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieVisualTargetContract"
require "zombies/NMZombieVisualTargetLedger"
require "zombies/NMZombieAttraction"
require "death/NMServerZombieCorpseCarry"
require "NMServerSandboxLootController"
require "zombies/NMServerMPZombieAssignmentFlow"
require "zombies/NMServerZombieVisualTargetPublisher"
require "zombies/NMServerSPZombieAssignmentFlow"
require "runtime/NMServerTickGate"
require "runtime/NMServerMainRuntime"

-- Thin server bootstrap that wires engine events to modular handlers.
NMDevicesServer = NMDevicesServer or {}

local function logServerDebugBootstrap(stage)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("core")) then
        return
    end
    local subsystems = NMRuntimeConfig and NMRuntimeConfig.getSubsystemDebugSnapshot and NMRuntimeConfig.getSubsystemDebugSnapshot() or {}
    local subsystemSummary = NMRuntimeConfig and NMRuntimeConfig.formatSubsystemDebugSummary and NMRuntimeConfig.formatSubsystemDebugSummary(subsystems) or ""
    print(string.format(
        "[NewMusic] [DebugBootstrap] side=server stage=%s subsystems=%s",
        tostring(stage or "unknown"),
        tostring(subsystemSummary)
    ))
end

if NMCore and NMCore.logChannel then
    if NMCore.logBuildVersionLine then
        NMCore.logBuildVersionLine("server")
    end
    logServerDebugBootstrap("bootstrap")
    NMCore.logChannel(
        "zombie_assignment",
        "server_boot",
        string.format(
            "authority=%s canMutate=%s liveStrategy=%s",
            tostring(NMCore.getRuntimeAuthorityMode and NMCore.getRuntimeAuthorityMode() or "unknown"),
            tostring(NMServerMainRuntime.canRunAuthoritativeWorldMutation()),
            tostring(NMZombieLiveStrategy and NMZombieLiveStrategy.getLiveVisualStrategy and NMZombieLiveStrategy.getLiveVisualStrategy() or "unknown")
        )
    )
    if NMServerBootReset and NMServerBootReset.initSession then
        NMServerBootReset.initSession()
    end
    if NMServerSandboxLootController and NMServerSandboxLootController.registerEventHooks then
        NMServerSandboxLootController.registerEventHooks()
    end
end

if Events then
    if Events.OnClientCommand and Events.OnClientCommand.Add then
        Events.OnClientCommand.Add(NMServerMainRuntime.onClientCommand)
    end
    if Events.EveryOneMinute and Events.EveryOneMinute.Add then
        Events.EveryOneMinute.Add(NMServerMainRuntime.onEveryOneMinute)
    end
    if Events.OnZombieDead and Events.OnZombieDead.Add and NMServerMainRuntime.canRunAuthoritativeWorldMutation() then
        if NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.onZombieDead then
            Events.OnZombieDead.Add(NMServerMainRuntime.onZombieDead)
            if NMCore and NMCore.logChannel and NMServerMainRuntime.shouldLogCorpseVerbose() then
                NMCore.logChannel("zombie_corpse", "hook_on_zombie_dead_registered", "handler=NMServerMainRuntime.onZombieDead")
            end
        end
    end
    if Events.OnDeadBodySpawn and Events.OnDeadBodySpawn.Add and NMServerMainRuntime.canRunAuthoritativeWorldMutation() then
        if NMServerZombieCorpseCarry and NMServerZombieCorpseCarry.onDeadBodySpawn then
            Events.OnDeadBodySpawn.Add(NMServerMainRuntime.onDeadBodySpawn)
            if NMCore and NMCore.logChannel and NMServerMainRuntime.shouldLogCorpseVerbose() then
                NMCore.logChannel("zombie_corpse", "hook_on_dead_body_spawn_registered", "handler=NMServerMainRuntime.onDeadBodySpawn")
            end
        end
    end
    if Events.OnZombieUpdate and Events.OnZombieUpdate.Add and NMServerMainRuntime.canRunAuthoritativeWorldMutation() then
        local registeredAny = false
        local activeZombieExecutor = NMServerMainRuntime.getActiveZombieExecutor()
        local shouldRegister, reason = NMServerMainRuntime.shouldRegisterZombieUpdateHook(activeZombieExecutor)
        if shouldRegister == true then
            Events.OnZombieUpdate.Add(activeZombieExecutor.onZombieUpdate)
            registeredAny = true
        end
        if registeredAny then
            if NMCore and NMCore.logChannel then
                NMCore.logChannel(
                    "zombie_assignment",
                    "hook_registered",
                    "event=OnZombieUpdate strategy=" .. tostring(NMZombieLiveStrategy and NMZombieLiveStrategy.getLiveVisualStrategy and NMZombieLiveStrategy.getLiveVisualStrategy() or "unknown")
                )
            end
        elseif NMCore and NMCore.logChannel then
            if reason == "sp_scan_only" then
                NMCore.logChannel(
                    "zombie_assignment",
                    "hook_skipped",
                    "event=OnZombieUpdate strategy=sp_runtime_attach mode=scan_only"
                )
            elseif NMServerMainRuntime.shouldLogProofVerbose() then
                NMCore.logChannel("zombie_assignment", "hook_missing", "event=OnZombieUpdate")
            end
        end
    elseif NMServerMainRuntime.canRunAuthoritativeWorldMutation() then
        if NMCore and NMCore.logChannel and NMServerMainRuntime.shouldLogProofVerbose() then
            NMCore.logChannel("zombie_assignment", "hook_missing", "event=OnZombieUpdate")
        end
    end
end

NMServerMainRuntime.registerTickGate()
