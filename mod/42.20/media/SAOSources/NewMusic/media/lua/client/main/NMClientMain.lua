require "runtime/NMClientInventoryItemVisualSanitizer"
require "runtime/NMClientDetachedProgressionUiRefresh"
require "runtime/NMClientModOptions"
require "runtime/NMClientPortableUiDragBlockProbe"
require "runtime/NMClientVehicleLootRefresh"
require "runtime/NMClientVanillaMusicSuppressor"
require "runtime/NMClientVanillaDiscVisibleProbe"
require "runtime/NMClientWorldItemVisualSanitizer"
require "runtime/NMClientTickGate"
require "runtime/NMClientZombieVisualTargetCache"
require "runtime/NMClientZombieVisualProbe"
require "runtime/NMClientMainRuntime"
require "ui/shared/host/NMGamepadWindowTracker"
require "ui/boombox/NMBoomboxWindowBootstrap"
require "ui/cdplayer/NMCDPlayerWindowBootstrap"
require "ui/NMGamepadRadial"
require "ui/walkman/NMWalkmanWindowBootstrap"
require "zombies/NMZombieVisualTargetContract"
require "zombies/NMZombieAttachedDefinitions"
require "zombies/NMZombieLiveStrategy"

-- Client bootstrap that wires engine events to modular handlers.
NMDevicesClient = NMDevicesClient or {}
NMDevicesClient._uiLagProbeAutoEnable = false
NMDevicesClient._uiAutoCloseProbeAutoEnable = false

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    NMContextMenus.onFillInventoryObjectContextMenu(playerNum, context, items)
end

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    NMContextMenus.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
end

local function logClientDebugBootstrap(stage)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("core")) then
        return
    end
    local subsystems = NMRuntimeConfig and NMRuntimeConfig.getSubsystemDebugSnapshot and NMRuntimeConfig.getSubsystemDebugSnapshot() or {}
    local subsystemSummary = NMRuntimeConfig and NMRuntimeConfig.formatSubsystemDebugSummary and NMRuntimeConfig.formatSubsystemDebugSummary(subsystems) or ""
    print(string.format(
        "[NewMusic] [DebugBootstrap] side=client stage=%s subsystems=%s",
        tostring(stage or "unknown"),
        tostring(subsystemSummary)
    ))
end

local function sendDebugSet(subsystem, enabled)
    if sendClientCommand and NMCore and NMCore.NetModule then
        sendClientCommand(NMCore.NetModule, "debug_set", { subsystem = tostring(subsystem or ""), enabled = enabled == true })
    end
end

local function setLocalDebug(subsystem, enabled)
    if NMCore and NMCore.setSubsystemDebugEnabled then
        NMCore.setSubsystemDebugEnabled(tostring(subsystem or ""), enabled == true)
    end
end

function NMDevicesClient.enableMemoryProbe()
    setLocalDebug("core", true)
    setLocalDebug("memory", true)
    sendDebugSet("core", true)
    sendDebugSet("memory", true)
end

function NMDevicesClient.disableMemoryProbe()
    setLocalDebug("memory", false)
    sendDebugSet("memory", false)
end

function NMDevicesClient.dumpMemoryProbeSnapshot()
    local snapshot = NMPlaybackRuntime and NMPlaybackRuntime.snapshot and NMPlaybackRuntime.snapshot() or nil
    local memorySnapshot = snapshot and snapshot.memoryProbe or nil
    local formatter = NMPlaybackRuntimeDiagnostics and NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot or nil
    local line = formatter and formatter(memorySnapshot) or "memory_probe_snapshot unavailable=true"
    print("[NewMusic] [MemoryProbe] dump " .. tostring(line))
    return snapshot
end

function NMDevicesClient.enableUiLagProbe()
    NMDevicesClient._uiLagProbeAutoEnable = true
    setLocalDebug("core", true)
    setLocalDebug("runtime", true)
    setLocalDebug("ui_render", true)
    sendDebugSet("core", true)
    sendDebugSet("runtime", true)
    sendDebugSet("ui_render", true)
end

function NMDevicesClient.disableUiLagProbe()
    NMDevicesClient._uiLagProbeAutoEnable = false
    setLocalDebug("ui_render", false)
    sendDebugSet("ui_render", false)
end

function NMDevicesClient.enableVehiclePersonalPlaybackProbe()
    setLocalDebug("core", true)
    setLocalDebug("runtime", true)
    setLocalDebug("playback_transition", true)
    setLocalDebug("vehicle", true)
    sendDebugSet("core", true)
    sendDebugSet("runtime", true)
    sendDebugSet("playback_transition", true)
    sendDebugSet("vehicle", true)
    logClientDebugBootstrap("vehicle_personal_playback_probe")
end

function NMDevicesClient.enableUiAutoCloseProbe()
    setLocalDebug("core", true)
    setLocalDebug("ui_auto_close", true)
end

function NMDevicesClient.disableUiAutoCloseProbe()
    setLocalDebug("ui_auto_close", false)
end

function NMDevicesClient.enableLootProbe()
    setLocalDebug("loot_probe", true)
    sendDebugSet("loot_probe", true)
end

function NMDevicesClient.disableLootProbe()
    setLocalDebug("loot_probe", false)
    sendDebugSet("loot_probe", false)
end

local function onGameStart()
    if NMCore and NMCore.logBuildVersionLine then
        NMCore.logBuildVersionLine("client")
    end
    logClientDebugBootstrap("onGameStart")
    if NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "core",
            "client_boot",
            string.format(
                "authority=%s isClient=%s isServer=%s liveStrategy=%s",
                tostring(NMCore.getRuntimeAuthorityMode and NMCore.getRuntimeAuthorityMode() or "unknown"),
                tostring(isClient and isClient() or false),
                tostring(isServer and isServer() or false),
                tostring(NMZombieLiveStrategy and NMZombieLiveStrategy.getLiveVisualStrategy and NMZombieLiveStrategy.getLiveVisualStrategy() or "unknown")
            )
        )
    end
    if NMDevicesClient._uiLagProbeAutoEnable == true then
        NMDevicesClient.enableUiLagProbe()
    end
    if NMDevicesClient._uiAutoCloseProbeAutoEnable == true then
        NMDevicesClient.enableUiAutoCloseProbe()
    end
    NMClientMainRuntime.onGameStart()
end

if Events then
    if Events.OnFillInventoryObjectContextMenu then
        Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
    end
    if Events.OnFillWorldObjectContextMenu then
        Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(NMClientMainRuntime.onServerCommand)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(onGameStart)
    end
    if Events.OnObjectAdded then
        Events.OnObjectAdded.Add(NMClientMainRuntime.onObjectAdded)
    end
    if Events.OnRefreshInventoryWindowContainers then
        Events.OnRefreshInventoryWindowContainers.Add(NMClientMainRuntime.onRefreshInventoryWindowContainers)
    end
    if Events.OnClothingUpdated then
        Events.OnClothingUpdated.Add(NMClientMainRuntime.onClothingUpdated)
    end
end

NMClientMainRuntime.registerTickGate()
