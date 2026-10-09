-- Central runtime tunables for tracking, sync cadence, and guard windows.
NMRuntimeConfig = NMRuntimeConfig or {}

local function getNewMusicSandbox()
    local root = SandboxVars
    if type(root) ~= "table" then
        return nil
    end
    local page = root.NewMusic
    if type(page) ~= "table" then
        return nil
    end
    return page
end

local function resolveSandboxNumber(key)
    local page = getNewMusicSandbox()
    if not page then
        return nil
    end
    return tonumber(page[key])
end

local function resolveSandboxBoolean(key)
    local page = getNewMusicSandbox()
    if not page then
        return nil
    end
    local value = page[key]
    if value == nil then
        return nil
    end
    if value == true or value == false then
        return value
    end
    local asNumber = tonumber(value)
    if asNumber ~= nil then
        return asNumber ~= 0
    end
    local text = tostring(value):lower()
    if text == "true" or text == "yes" or text == "on" then
        return true
    end
    if text == "false" or text == "no" or text == "off" then
        return false
    end
    return nil
end

local function clampNumber(value, minValue, maxValue)
    local n = tonumber(value)
    if n == nil then
        return nil
    end
    if n < minValue then
        return minValue
    end
    if n > maxValue then
        return maxValue
    end
    return n
end

local values = {
    buildContentToken = "2026.08.23.1",
    worldTrackingCap = 1500,
    registryStaleTicks = 7200,
    registryHeartbeatIntervalTicks = 120,
    registryResyncIntervalTicks = 600,
    registryResyncMoveDistance = 48,
    registryRequestTimeoutTicks = 180,
    registryResyncCooldownMs = 3000,
    netRegistryLogThrottleTicks = 600,
    attachmentDiagnosticsThrottleTicks = 900,
    carryTruthHoldTicks = 45,
    maxActiveWorldSourcesPerClient = 10,
    serverZombiePlayerGateMultiplier = 1.5,
    authorityScope = "all_world_devices",
    attachedAuthorityGraceTicks = 180,
    serverDormancyMinutes = 5,
    serverUnresolvedGraceSeconds = 6,
    serverUnseenExpiryEnabled = false,
    serverUnseenExpiryMinutes = 30,
    emitterMissingGraceTicks = 60,
    trackEndPendingWindowMs = 1200,
    trackEndPendingFalseChecks = 3,
    trackEndPendingWindowMsByDeviceType = {},
    trackEndPendingFalseChecksByDeviceType = {},
    zombieLiveVisualStrategySP = "sp_runtime_attach",
    zombieLiveVisualStrategyMP = "mp_assignment_flow",
    debugSubsystems = {
        core = false,
        intent = false,
        state = false,
        runtime = false,
        memory = false,
        playback_progression = false,
        playback_transition = false,
        vehicle = false,
        zombie_assignment = false,
        zombie_corpse = false,
        zombie_visual = false,
        zombie_attraction = false,
        network = false,
        registry = false,
        loot = false,
        loot_probe = false,
        ui_render = false,
        ui_refresh = false,
        ui_auto_close = false,
        ui_lifecycle = false,
        slot = false,
        runtime_apply = false,
        runtime_route = false,
        vehicle_identity = false,
        vehicle_route = false,
        vehicle_trace = false
    },
    enableVehicleEmitterDiagnostics = true,
    vehicleEmitterJumpWarnDistance = 12,
    vehicleEmitterJumpRebindHintDistance = 48,
    allowNoHeadphonesPlaybackMutedPersonal = true,
    vehicleHybridPersonalForOccupants = true,
    vehicleOutputFlipDebounceMs = 750,
    vehicleDualEmittersEnabled = true,
    vehicleGhostWorldChannelGraceMs = 1500,
    vehicleRebindTraceUUID = "",
    serverVehicleTrackDurationMs = 210000,
    serverVehicleTrackHintMinAgeMs = 5000,
    noListenerFreezeDebounceMs = 3000,
    noListenerResumeDebounceMs = 1000,
    dualGainMinLogMs = 1000,
    batteryDrainSecondsPortable = 900,
    batteryDrainSecondsVehicleEngineOff = 300,
    vehicleCustomDrainEnabled = false,
    stickySqlBindingTtlMs = 45000,
    mpResetPlaybackOnServerStart = true,
    fancyUIEnabled = true,
    spatialAudioEnabled = true,
    muteGameSoundtrackDuringPlayback = true,
    memoryProbeSampleIntervalMs = 5000,
    memoryProbeHeapDeltaKb = 512,
    memoryProbeTickHotMs = 8,
    memoryProbeSyncHotMs = 4
}
NMRuntimeConfig._values = values

function NMRuntimeConfig.get(key, defaultValue)
    local v = values[key]
    if v == nil then
        return defaultValue
    end
    return v
end

function NMRuntimeConfig.getBuildContentToken()
    return tostring(values.buildContentToken or "")
end

function NMRuntimeConfig.getFancyUIEnabled()
    if NMClientModOptions and NMClientModOptions.getFancyUIEnabled then
        return NMClientModOptions.getFancyUIEnabled() ~= false
    end
    return values.fancyUIEnabled ~= false
end

function NMRuntimeConfig.setFancyUIEnabled(enabled)
    values.fancyUIEnabled = enabled ~= false
end

function NMRuntimeConfig.setSpatialAudioEnabled(enabled)
    values.spatialAudioEnabled = enabled ~= false
end

function NMRuntimeConfig.setShowTrackNumberPrefix(enabled)
    values.showTrackNumberPrefix = enabled ~= false
end

function NMRuntimeConfig.setMuteGameSoundtrackDuringPlayback(enabled)
    values.muteGameSoundtrackDuringPlayback = enabled ~= false
end

function NMRuntimeConfig.setFancyDeviceUiScaleMultiplier(multiplier)
    local numeric = tonumber(multiplier)
    if numeric == nil then
        numeric = 1.0
    end
    values.fancyDeviceUiScaleMultiplier = NMCore and NMCore.clamp and NMCore.clamp(numeric, 0.5, 2.0) or math.max(0.5, math.min(2.0, numeric))
end

function NMRuntimeConfig.setNewMusicMasterVolume(volume)
    local numeric = tonumber(volume)
    if numeric == nil then
        numeric = 1.0
    end
    values.newMusicMasterVolume = NMCore and NMCore.clamp and NMCore.clamp(numeric, 0.0, 1.0) or math.max(0.0, math.min(1.0, numeric))
end

function NMRuntimeConfig.getNewMusicMasterVolume()
    if NMClientModOptions and NMClientModOptions.getMasterVolume then
        local value = tonumber(NMClientModOptions.getMasterVolume())
        if value ~= nil then
            return NMCore and NMCore.clamp and NMCore.clamp(value, 0.0, 1.0) or math.max(0.0, math.min(1.0, value))
        end
    end
    local fallback = tonumber(values.newMusicMasterVolume)
    if fallback ~= nil then
        return NMCore and NMCore.clamp and NMCore.clamp(fallback, 0.0, 1.0) or math.max(0.0, math.min(1.0, fallback))
    end
    return 1.0
end

function NMRuntimeConfig.getShowTrackNumberPrefix()
    if NMClientModOptions and NMClientModOptions.getShowTrackNumberPrefix then
        return NMClientModOptions.getShowTrackNumberPrefix() ~= false
    end
    return values.showTrackNumberPrefix ~= false
end

function NMRuntimeConfig.getSpatialAudioEnabled()
    if NMClientModOptions and NMClientModOptions.getSpatialAudioEnabled then
        return NMClientModOptions.getSpatialAudioEnabled() ~= false
    end
    return values.spatialAudioEnabled ~= false
end

function NMRuntimeConfig.getMuteGameSoundtrackDuringPlayback()
    if NMClientModOptions and NMClientModOptions.getMuteGameSoundtrackDuringPlayback then
        return NMClientModOptions.getMuteGameSoundtrackDuringPlayback() ~= false
    end
    return values.muteGameSoundtrackDuringPlayback ~= false
end

function NMRuntimeConfig.getFancyDeviceUiScaleMultiplier()
    if NMClientModOptions and NMClientModOptions.getFancyDeviceUiScaleMultiplier then
        local value = tonumber(NMClientModOptions.getFancyDeviceUiScaleMultiplier())
        if value ~= nil then
            return NMCore and NMCore.clamp and NMCore.clamp(value, 0.5, 2.0) or math.max(0.5, math.min(2.0, value))
        end
    end
    local fallback = tonumber(values.fancyDeviceUiScaleMultiplier)
    if fallback ~= nil then
        return NMCore and NMCore.clamp and NMCore.clamp(fallback, 0.5, 2.0) or math.max(0.5, math.min(2.0, fallback))
    end
    return 1.0
end

function NMRuntimeConfig.set(key, value)
    if key == nil then
        return false
    end
    values[tostring(key)] = value
    return true
end

function NMRuntimeConfig.getWorldTrackingCap()
    local fromSandbox = resolveSandboxNumber("MaxTrackingRange")
    if fromSandbox ~= nil then
        if fromSandbox <= 0 then
            return 0
        end
        return math.max(1, math.min(36000, math.floor(fromSandbox + 0.5)))
    end
    local value = tonumber(values.worldTrackingCap) or 1500
    if value <= 0 then
        return 0
    end
    return math.max(1, math.floor(value + 0.5))
end

function NMRuntimeConfig.getRegistryHeartbeatIntervalTicks()
    return tonumber(values.registryHeartbeatIntervalTicks) or 120
end

function NMRuntimeConfig.getRegistryResyncIntervalTicks()
    return tonumber(values.registryResyncIntervalTicks) or 600
end

function NMRuntimeConfig.getRegistryResyncMoveDistance()
    return tonumber(values.registryResyncMoveDistance) or 48
end

function NMRuntimeConfig.getRegistryRequestTimeoutTicks()
    return tonumber(values.registryRequestTimeoutTicks) or 180
end

function NMRuntimeConfig.getRegistryResyncCooldownMs()
    return tonumber(values.registryResyncCooldownMs) or 3000
end

function NMRuntimeConfig.getMaxActiveWorldSourcesPerClient()
    local fromSandbox = resolveSandboxNumber("ActiveDeviceLimit")
    if fromSandbox ~= nil then
        return math.max(4, math.min(50, math.floor(fromSandbox + 0.5)))
    end
    local value = tonumber(values.maxActiveWorldSourcesPerClient) or 10
    return math.max(4, math.min(50, math.floor(value + 0.5)))
end

function NMRuntimeConfig.getServerDormancyMinutes()
    return tonumber(values.serverDormancyMinutes) or 5
end

function NMRuntimeConfig.getServerUnresolvedGraceSeconds()
    return tonumber(values.serverUnresolvedGraceSeconds) or 6
end

function NMRuntimeConfig.getServerZombiePlayerGateMultiplier()
    return tonumber(values.serverZombiePlayerGateMultiplier) or 1.5
end

function NMRuntimeConfig.getAuthorityScope()
    return tostring(values.authorityScope or "all_world_devices")
end

function NMRuntimeConfig.getServerUnseenExpiryEnabled()
    return values.serverUnseenExpiryEnabled == true
end

function NMRuntimeConfig.getServerUnseenExpiryMinutes()
    return tonumber(values.serverUnseenExpiryMinutes) or 30
end

function NMRuntimeConfig.getTrackEndPendingWindowMs()
    return tonumber(values.trackEndPendingWindowMs) or 1200
end

function NMRuntimeConfig.getTrackEndPendingFalseChecks()
    return tonumber(values.trackEndPendingFalseChecks) or 3
end

function NMRuntimeConfig.getTrackEndPendingWindowMsForDeviceType(deviceType)
    local dt = tostring(deviceType or "")
    local map = values.trackEndPendingWindowMsByDeviceType
    if dt ~= "" and type(map) == "table" then
        local override = tonumber(map[dt])
        if override and override > 0 then
            return math.max(250, math.floor(override + 0.5))
        end
    end
    return NMRuntimeConfig.getTrackEndPendingWindowMs()
end

function NMRuntimeConfig.getTrackEndPendingFalseChecksForDeviceType(deviceType)
    local dt = tostring(deviceType or "")
    local map = values.trackEndPendingFalseChecksByDeviceType
    if dt ~= "" and type(map) == "table" then
        local override = tonumber(map[dt])
        if override and override > 0 then
            return math.max(1, math.floor(override + 0.5))
        end
    end
    return NMRuntimeConfig.getTrackEndPendingFalseChecks()
end

function NMRuntimeConfig.enableVehicleEmitterDiagnostics()
    if NMRuntimeConfig.isSubsystemDebugEnabled then
        return NMRuntimeConfig.isSubsystemDebugEnabled("vehicle") == true
    end
    return values.enableVehicleEmitterDiagnostics == true
end

function NMRuntimeConfig.getVehicleEmitterJumpWarnDistance()
    return tonumber(values.vehicleEmitterJumpWarnDistance) or 12
end

function NMRuntimeConfig.getVehicleEmitterJumpRebindHintDistance()
    return tonumber(values.vehicleEmitterJumpRebindHintDistance) or 48
end

function NMRuntimeConfig.getAllowNoHeadphonesPlaybackMutedPersonal()
    return values.allowNoHeadphonesPlaybackMutedPersonal == true
end

function NMRuntimeConfig.getVehicleHybridPersonalForOccupants()
    return values.vehicleHybridPersonalForOccupants == true
end

function NMRuntimeConfig.getVehicleOutputFlipDebounceMs()
    return tonumber(values.vehicleOutputFlipDebounceMs) or 750
end

function NMRuntimeConfig.getVehicleDualEmittersEnabled()
    return values.vehicleDualEmittersEnabled == true
end

function NMRuntimeConfig.getServerVehicleTrackDurationMs()
    local value = tonumber(values.serverVehicleTrackDurationMs) or 210000
    return math.max(1000, math.floor(value + 0.5))
end

function NMRuntimeConfig.getBatteryDrainSecondsPortable()
    local value = tonumber(values.batteryDrainSecondsPortable) or 600
    return math.max(1, value)
end

function NMRuntimeConfig.getBatteryDrainRateHours()
    local fromSandbox = clampNumber(resolveSandboxNumber("BatteryDrainRate"), 0.02, 1000.0)
    if fromSandbox ~= nil then
        return fromSandbox
    end
    return 24.0
end

function NMRuntimeConfig.getAudioMaxRadius()
    local fromSandbox = clampNumber(resolveSandboxNumber("AudioMaxRadius"), 9, 500)
    if fromSandbox ~= nil then
        return math.max(9, math.min(500, math.floor(fromSandbox + 0.5)))
    end
    return 35
end

function NMRuntimeConfig.getZombieAttractionRadius()
    local fromSandbox = clampNumber(resolveSandboxNumber("ZombieAttractionRadius"), 9, 200)
    if fromSandbox ~= nil then
        return math.max(9, math.min(200, math.floor(fromSandbox + 0.5)))
    end
    return 105
end

function NMRuntimeConfig.getDisassemblyEnabled()
    local value = resolveSandboxBoolean("Disassembly")
    if value ~= nil then
        return value
    end
    return true
end

function NMRuntimeConfig.getZomboidOSTEnabled()
    local value = resolveSandboxBoolean("ZomboidOST")
    if value ~= nil then
        return value
    end
    return true
end

function NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled()
    local value = resolveSandboxBoolean("ConvertVanillaCDsAndCDPlayers")
    if value ~= nil then
        return value
    end
    return false
end

function NMRuntimeConfig.getMediaSpawnsWithCasesEnabled()
    local value = resolveSandboxBoolean("MediaSpawnsWithCases")
    if value ~= nil then
        return value
    end
    return true
end

function NMRuntimeConfig.getBatteryDrainSecondsPortableFromSandbox()
    return math.max(1.0, NMRuntimeConfig.getBatteryDrainRateHours() * 3600.0)
end

function NMRuntimeConfig.getNoListenerFreezeDebounceMs()
    local value = tonumber(values.noListenerFreezeDebounceMs) or 3000
    return math.max(0, math.floor(value + 0.5))
end

function NMRuntimeConfig.getNoListenerResumeDebounceMs()
    local value = tonumber(values.noListenerResumeDebounceMs) or 1000
    return math.max(0, math.floor(value + 0.5))
end

function NMRuntimeConfig.getStickySqlBindingTtlMs()
    return tonumber(values.stickySqlBindingTtlMs) or 45000
end

function NMRuntimeConfig.getBatteryDrainSecondsVehicleEngineOff()
    local value = tonumber(values.batteryDrainSecondsVehicleEngineOff) or 300
    return math.max(1, value)
end

function NMRuntimeConfig.getVehicleCustomDrainEnabled()
    return values.vehicleCustomDrainEnabled == true
end

function NMRuntimeConfig.getMPResetPlaybackOnServerStart()
    return values.mpResetPlaybackOnServerStart == true
end

function NMRuntimeConfig.getMemoryProbeSampleIntervalMs()
    local value = tonumber(values.memoryProbeSampleIntervalMs) or 5000
    return math.max(1000, math.floor(value + 0.5))
end

function NMRuntimeConfig.getMemoryProbeHeapDeltaKb()
    local value = tonumber(values.memoryProbeHeapDeltaKb) or 512
    return math.max(64, math.floor(value + 0.5))
end

function NMRuntimeConfig.getMemoryProbeTickHotMs()
    local value = tonumber(values.memoryProbeTickHotMs) or 8
    return math.max(1, math.floor(value + 0.5))
end

function NMRuntimeConfig.getMemoryProbeSyncHotMs()
    local value = tonumber(values.memoryProbeSyncHotMs) or 4
    return math.max(1, math.floor(value + 0.5))
end

function NMRuntimeConfig.getLootRate(optionKey, defaultValue)
    local fallback = tonumber(defaultValue) or 0.6
    local fromSandbox = clampNumber(resolveSandboxNumber(optionKey), 0.0, 4.0)
    if fromSandbox ~= nil then
        return fromSandbox
    end
    return fallback
end

function NMRuntimeConfig.getCassettesSpawnRate()
    return NMRuntimeConfig.getLootRate("CassettesSpawnRate", 0.6)
end

function NMRuntimeConfig.getVinylRecordsSpawnRate()
    return NMRuntimeConfig.getLootRate("VinylRecordsSpawnRate", 0.3)
end

function NMRuntimeConfig.getCDsSpawnRate()
    return NMRuntimeConfig.getLootRate("CDsSpawnRate", 0.6)
end

function NMRuntimeConfig.getWalkmanSpawnRate()
    return NMRuntimeConfig.getLootRate("WalkmanSpawnRate", 0.6)
end

function NMRuntimeConfig.getBoomboxSpawnRate()
    return NMRuntimeConfig.getLootRate("BoomboxSpawnRate", 0.6)
end

function NMRuntimeConfig.getCDPlayerSpawnRate()
    return NMRuntimeConfig.getLootRate("CDPlayerSpawnRate", 0.6)
end

function NMRuntimeConfig.getRecordPlayerSpawnRate()
    return NMRuntimeConfig.getLootRate("RecordPlayerSpawnRate", 0.6)
end

function NMRuntimeConfig.getMusicalZombiesSpawnRate()
    return NMRuntimeConfig.getLootRate("MusicalZombiesSpawnRate", 0.6)
end

function NMRuntimeConfig.snapshot()
    local out = {}
    for k, v in pairs(values) do
        if type(v) == "table" then
            local copy = {}
            for tk, tv in pairs(v) do
                copy[tk] = tv
            end
            out[k] = copy
        else
            out[k] = v
        end
    end
    return out
end

return NMRuntimeConfig

