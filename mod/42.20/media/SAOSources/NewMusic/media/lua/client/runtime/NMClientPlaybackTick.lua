require "runtime/NMClientDetachedPlaybackPass"
require "runtime/NMClientDetachedOrchestration"
require "runtime/NMClientOwnershipConflictPolicy"
require "runtime/NMClientPlaybackInventoryCollector"
require "runtime/NMClientVehicleContinuity"

-- Client playback tick orchestration for inventory devices and detached cached sources.
NMClientPlaybackTick = NMClientPlaybackTick or {}
NMClientPlaybackTick.tick = NMClientPlaybackTick.tick or 0
NMClientPlaybackTick.lastInventoryByUuid = NMClientPlaybackTick.lastInventoryByUuid or {}
NMClientPlaybackTick.vehiclePowerTickMs = NMClientPlaybackTick.vehiclePowerTickMs or {}
NMClientPlaybackTick.zombieAttractionPulseState = NMClientPlaybackTick.zombieAttractionPulseState or {}
NMClientPlaybackTick.ownershipConflictState = NMClientPlaybackTick.ownershipConflictState or {}
NMClientPlaybackTick.detachedRemoveLogMs = NMClientPlaybackTick.detachedRemoveLogMs or {}
NMClientPlaybackTick.detachedSyncSigSeen = NMClientPlaybackTick.detachedSyncSigSeen or {}
NMClientPlaybackTick.detachedSyncHeartbeatMs = NMClientPlaybackTick.detachedSyncHeartbeatMs or {}
NMClientPlaybackTick.modeResolutionSigSeen = NMClientPlaybackTick.modeResolutionSigSeen or {}
NMClientPlaybackTick.modeResolutionHeartbeatMs = NMClientPlaybackTick.modeResolutionHeartbeatMs or {}
NMClientPlaybackTick.modeResolutionBootstrapMs = NMClientPlaybackTick.modeResolutionBootstrapMs or {}
NMClientPlaybackTick.stableOffInventorySigSeen = NMClientPlaybackTick.stableOffInventorySigSeen or {}
NMClientPlaybackTick.managedInventoryTruthSigSeen = NMClientPlaybackTick.managedInventoryTruthSigSeen or {}
NMClientPlaybackTick.corpseInventoryReboundSeen = NMClientPlaybackTick.corpseInventoryReboundSeen or {}
NMClientPlaybackTick.idleFullCadenceTicks = NMClientPlaybackTick.idleFullCadenceTicks or 10
NMClientPlaybackTick.activeFullCadenceTicks = NMClientPlaybackTick.activeFullCadenceTicks or 10
NMClientPlaybackTick.personalTrackMonitorCadenceTicks = NMClientPlaybackTick.personalTrackMonitorCadenceTicks or 30
NMClientPlaybackTick.personalTrackMonitorCadenceMs = NMClientPlaybackTick.personalTrackMonitorCadenceMs or 500
NMClientPlaybackTick.managedInventoryIdleFullCadenceTicks = NMClientPlaybackTick.managedInventoryIdleFullCadenceTicks or 120
NMClientPlaybackTick.fastPositionCadenceTicks = NMClientPlaybackTick.fastPositionCadenceTicks or 3
NMClientPlaybackTick.movingFollowFastPositionCadenceTicks = NMClientPlaybackTick.movingFollowFastPositionCadenceTicks or 6
NMClientPlaybackTick.stationaryFastPositionCadenceTicks = NMClientPlaybackTick.stationaryFastPositionCadenceTicks or 15
NMClientPlaybackTick.settledFastPositionCadenceTicks = NMClientPlaybackTick.settledFastPositionCadenceTicks or 60
NMClientPlaybackTick.settledFastPositionStreak = NMClientPlaybackTick.settledFastPositionStreak or 3
NMClientPlaybackTick.schedulerTick = NMClientPlaybackTick.schedulerTick or 0
NMClientPlaybackTick._playbackDirty = NMClientPlaybackTick._playbackDirty ~= false
NMClientPlaybackTick._hasManagedInventoryDevices = NMClientPlaybackTick._hasManagedInventoryDevices or false
NMClientPlaybackTick._startupBootstrapUntilTick = NMClientPlaybackTick._startupBootstrapUntilTick or 0
NMClientPlaybackTick._lastFullTick = NMClientPlaybackTick._lastFullTick or 0
NMClientPlaybackTick._lastFullSchedulerTick = NMClientPlaybackTick._lastFullSchedulerTick or 0
NMClientPlaybackTick._forceFullPass = NMClientPlaybackTick._forceFullPass or false
NMClientPlaybackTick._lastPassKind = NMClientPlaybackTick._lastPassKind or "none"
NMClientPlaybackTick._lastManagedInventorySkipDiagTick = NMClientPlaybackTick._lastManagedInventorySkipDiagTick or -1
NMClientPlaybackTick._lastInventoryRefreshFullRequestMs = tonumber(NMClientPlaybackTick._lastInventoryRefreshFullRequestMs) or 0
NMClientPlaybackTick._fastSources = NMClientPlaybackTick._fastSources or {}
NMClientPlaybackTick._trackMonitorContexts = NMClientPlaybackTick._trackMonitorContexts or {}
NMClientPlaybackTick._lastFastPositionSchedulerTick = tonumber(NMClientPlaybackTick._lastFastPositionSchedulerTick) or 0
NMClientPlaybackTick._playbackWorkStatusCache = NMClientPlaybackTick._playbackWorkStatusCache or {
    schedulerTick = nil,
    playerKey = nil,
    status = nil,
    diagTick = nil,
    diagPlayerKey = nil
}
NMClientPlaybackTick._playbackLossProbe = NMClientPlaybackTick._playbackLossProbe or {
    lastSigByUuid = {},
    lastLogMsByUuid = {},
    lastSourceByUuid = {},
    lastTickByUuid = {},
    lastReasonByUuid = {}
}
NMClientPlaybackTick._interestDiag = NMClientPlaybackTick._interestDiag or {
    lastLogMs = 0,
    lastTick = -1,
    counters = {}
}
NMClientPlaybackTick._lastFollowPlayerPos = NMClientPlaybackTick._lastFollowPlayerPos or nil
NMClientPlaybackTick._scratch = NMClientPlaybackTick._scratch or {
    valid = {},
    inventoryOwners = {},
    currentInventoryByUuid = {},
    spPulseCandidates = {},
    inventory = {},
    detached = {},
    pendingPlayback = {}
}
NMClientPlaybackTick._schedulerRate = NMClientPlaybackTick._schedulerRate or {
    lastMs = 0,
    lastTick = 0,
    ticksPerSecond = 60
}
NMClientPlaybackTick._vehicleSeatProbe = NMClientPlaybackTick._vehicleSeatProbe or {
    lastSignature = nil,
    pending = false,
    pendingReason = nil,
    pendingEvent = nil,
    pendingAtMs = 0,
    pendingSchedulerTick = 0
}

local getActiveRouteClass
local consumeAndDispatchTrackFinished
local formatVehicleTransitionSnapshot

local function clearMap(tbl)
    for key, _ in pairs(tbl) do
        tbl[key] = nil
    end
    return tbl
end

local function clearArray(tbl)
    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
    return tbl
end

local function logTransitionProbe(msg, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_transition") then
        NMCore.logChannel("playback_transition", msg, detail)
    end
end

local function runtimeProbeEnabled()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") == true
end

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

local function isMPClientRuntime()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

local function getObservedSchedulerTicksPerSecond()
    local rate = NMClientPlaybackTick._schedulerRate or {}
    local tps = tonumber(rate.ticksPerSecond) or 60
    if tps < 1 then
        return 60
    end
    if tps > 1000 then
        return 1000
    end
    return tps
end

local function roundProbeCoord(value)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    return string.format("%.2f", n)
end

local function quantizeProbeCoord(value, step)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    local bucket = tonumber(step) or 1.0
    if bucket <= 0 then
        bucket = 1.0
    end
    return string.format("%.1f", math.floor((n / bucket) + 0.5) * bucket)
end

local function isSteadyStatePlaybackProbeReason(reason)
    local normalizedReason = tostring(reason or "unknown")
    return normalizedReason == "inventory_sync"
        or normalizedReason == "detached_world_sync"
        or normalizedReason == "pending_world_sync"
        or normalizedReason == "full_pass_valid"
end

local function shouldEmitPlaybackLossProbe(uuid, signature, minIntervalMs)
    if runtimeProbeEnabled() ~= true then
        return false
    end
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    local probe = NMClientPlaybackTick._playbackLossProbe
    local nowMs = nowRealMs()
    local lastSig = tostring(probe.lastSigByUuid[key] or "")
    local lastMs = tonumber(probe.lastLogMsByUuid[key]) or 0
    local intervalMs = math.max(250, tonumber(minIntervalMs) or 1000)
    if lastSig ~= tostring(signature or "") or (nowMs - lastMs) >= intervalMs then
        probe.lastSigByUuid[key] = tostring(signature or "")
        probe.lastLogMsByUuid[key] = nowMs
        return true
    end
    return false
end

local function shouldSkipSteadyStatePlaybackProbe(uuid, reason)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    if isSteadyStatePlaybackProbeReason(reason) ~= true then
        return false
    end
    local probe = NMClientPlaybackTick._playbackLossProbe
    local currentTick = tonumber(NMClientPlaybackTick.tick) or 0
    local lastTick = tonumber(probe.lastTickByUuid[key]) or -1
    local lastReason = tostring(probe.lastReasonByUuid[key] or "")
    return lastTick == currentTick and isSteadyStatePlaybackProbeReason(lastReason) == true
end

local function rememberPlaybackLossSource(uuid, state, source, extras)
    local key = tostring(uuid or state and state.deviceUUID or "")
    if key == "" then
        return
    end
    local probe = NMClientPlaybackTick._playbackLossProbe
    local payload = type(extras) == "table" and extras or {}
    local activeSnapshot = NMPlaybackRuntime
        and NMPlaybackRuntime.getActiveRouteProbeSnapshot
        and NMPlaybackRuntime.getActiveRouteProbeSnapshot(key)
        or nil
    if activeSnapshot and activeSnapshot.localVehiclePersonalOverride == true then
        probe.lastSourceByUuid[key] = {
            source = activeSnapshot.source,
            playbackMode = tostring(activeSnapshot.playbackMode or "personal"),
            mode = tostring(activeSnapshot.mode or activeSnapshot.context or "vehicle"),
            resolvedOutput = tostring(activeSnapshot.resolvedOutput or "personal"),
            isOn = activeSnapshot.isOn == true,
            isPlaying = activeSnapshot.isPlaying == true,
            media = tostring(activeSnapshot.media or state and state.mediaFullType or "nil"),
            sharedSource = source and {
                mode = source.mode,
                context = source.context,
                x = tonumber(source.x),
                y = tonumber(source.y),
                z = tonumber(source.z)
            } or nil,
            sharedPlaybackMode = tostring(state and state.playbackMode or payload.playbackMode or ""),
            sharedMode = tostring(payload.mode or ""),
            sharedResolvedOutput = tostring(payload.resolvedOutput or ""),
            sharedIsOn = state and state.isOn == true or false,
            sharedIsPlaying = state and state.isPlaying == true or false,
            sharedMedia = tostring(state and state.mediaFullType or "nil")
        }
        return
    end
    probe.lastSourceByUuid[key] = {
        source = source and {
            mode = source.mode,
            context = source.context,
            x = tonumber(source.x),
            y = tonumber(source.y),
            z = tonumber(source.z)
        } or nil,
        playbackMode = tostring(state and state.playbackMode or payload.playbackMode or ""),
        mode = tostring(payload.mode or ""),
        resolvedOutput = tostring(payload.resolvedOutput or ""),
        isOn = state and state.isOn == true or false,
        isPlaying = state and state.isPlaying == true or false,
        media = tostring(state and state.mediaFullType or "nil")
    }
end

local function emitPlaybackLossProbe(player, uuid, valid, reason, extras)
    if runtimeProbeEnabled() ~= true then
        return
    end
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    local probe = NMClientPlaybackTick._playbackLossProbe
    local cached = probe.lastSourceByUuid[key] or {}
    local payload = type(extras) == "table" and extras or {}
    local activeSnapshot = NMPlaybackRuntime
        and NMPlaybackRuntime.getActiveRouteProbeSnapshot
        and NMPlaybackRuntime.getActiveRouteProbeSnapshot(key)
        or nil
    if activeSnapshot and activeSnapshot.localVehiclePersonalOverride == true then
        if payload.source == nil then
            payload.source = activeSnapshot.source
        end
        if payload.context == nil then
            payload.context = activeSnapshot.context
        end
        payload.playbackMode = tostring(activeSnapshot.playbackMode or payload.playbackMode or "personal")
        payload.mode = tostring(activeSnapshot.mode or payload.mode or activeSnapshot.context or "vehicle")
        payload.resolvedOutput = tostring(activeSnapshot.resolvedOutput or payload.resolvedOutput or "personal")
        if payload.isOn == nil then
            payload.isOn = activeSnapshot.isOn == true
        end
        if payload.isPlaying == nil then
            payload.isPlaying = activeSnapshot.isPlaying == true
        end
        if payload.media == nil then
            payload.media = activeSnapshot.media
        end
    end
    local source = payload.source or cached.source or nil
    if shouldSkipSteadyStatePlaybackProbe(key, reason) == true then
        return
    end
    local isPlaying = payload.isPlaying
    if isPlaying == nil then
        isPlaying = cached.isPlaying == true
    end
    local isOn = payload.isOn
    if isOn == nil then
        isOn = cached.isOn == true
    end
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[key] or nil
    if isPlaying ~= true and valid == true and active == nil then
        return
    end
    local playerX = tonumber(player and player.getX and player:getX()) or nil
    local playerY = tonumber(player and player.getY and player:getY()) or nil
    local playerZ = tonumber(player and player.getZ and player:getZ()) or nil
    local context = tostring(payload.context or source and source.context or source and source.mode or cached.mode or "nil")
    local playbackMode = tostring(payload.playbackMode or cached.playbackMode or "nil")
    local mode = tostring(payload.mode or cached.mode or "nil")
    local resolvedOutput = tostring(payload.resolvedOutput or cached.resolvedOutput or "nil")
    local missingTick = tonumber(NMPlaybackRuntime and NMPlaybackRuntime.MissingSinceTick and NMPlaybackRuntime.MissingSinceTick[key]) or -1
    local missingMs = tonumber(NMPlaybackRuntime and NMPlaybackRuntime.MissingSinceMs and NMPlaybackRuntime.MissingSinceMs[key]) or -1
    local normalizedReason = tostring(reason or "unknown")
    local steadyStateReason = valid == true
        and missingTick < 0
        and isSteadyStatePlaybackProbeReason(normalizedReason) == true
    local occupantLocalActive = activeSnapshot and activeSnapshot.localVehiclePersonalOverride == true
    if steadyStateReason and occupantLocalActive
        and not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace")) then
        return
    end
    local isHealthyVehicleDetachedSync = steadyStateReason
        and context == "vehicle"
        and mode == "vehicle"
        and valid == true
        and active ~= nil
        and missingTick < 0
        and missingMs < 0
        and isPlaying == true
        and isOn == true
    if isHealthyVehicleDetachedSync
        and not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace")) then
        return
    end
    local sharedSource = occupantLocalActive and (payload.sharedSource or cached.sharedSource) or nil
    local sharedContext = tostring(payload.sharedContext or sharedSource and sharedSource.context or sharedSource and sharedSource.mode or cached.sharedMode or "nil")
    local sharedPlaybackMode = tostring(payload.sharedPlaybackMode or cached.sharedPlaybackMode or "nil")
    local sharedMode = tostring(payload.sharedMode or cached.sharedMode or "nil")
    local sharedResolvedOutput = tostring(payload.sharedResolvedOutput or cached.sharedResolvedOutput or "nil")
    local signatureReason = steadyStateReason and "steady_state_valid" or normalizedReason
    local sourceCoordStep = steadyStateReason and (occupantLocalActive and 4.0 or 1.0) or 0.1
    local sourceX = source and source.x
    local sourceY = source and source.y
    local sourceZ = source and source.z
    if steadyStateReason and occupantLocalActive then
        sourceX = nil
        sourceY = nil
        sourceZ = source and source.z
        if payload.minIntervalMs == nil then
            payload.minIntervalMs = NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.shortHeartbeatMs and NMRuntimeProbeAdapter.shortHeartbeatMs() or 15000
        end
    end
    local signature = table.concat({
        signatureReason,
        tostring(valid == true),
        tostring(context),
        tostring(playbackMode),
        tostring(mode),
        tostring(resolvedOutput),
        tostring(quantizeProbeCoord(sourceX, sourceCoordStep)),
        tostring(quantizeProbeCoord(sourceY, sourceCoordStep)),
        tostring(quantizeProbeCoord(sourceZ, sourceCoordStep)),
        tostring(roundProbeCoord(playerZ)),
        tostring(missingTick),
        tostring(active ~= nil)
    }, "|")
    if shouldEmitPlaybackLossProbe(key, signature, payload.minIntervalMs) ~= true then
        return
    end
    NMCore.logChannel(
        "runtime",
        "playback_loss_probe",
        string.format(
            "uuid=%s reason=%s pass=%s valid=%s active=%s player=%s,%s,%s source=%s,%s,%s ctx=%s mode=%s playbackMode=%s output=%s effectiveLocal=%s sharedCtx=%s sharedMode=%s sharedPlaybackMode=%s sharedOutput=%s missingTick=%s missingMs=%s isOn=%s isPlaying=%s media=%s",
            tostring(key),
            tostring(reason or "unknown"),
            tostring(NMClientPlaybackTick._lastPassKind or "none"),
            tostring(valid == true),
            tostring(active ~= nil),
            roundProbeCoord(playerX),
            roundProbeCoord(playerY),
            roundProbeCoord(playerZ),
            roundProbeCoord(source and source.x),
            roundProbeCoord(source and source.y),
            roundProbeCoord(source and source.z),
            tostring(context),
            tostring(mode),
            tostring(playbackMode),
            tostring(resolvedOutput),
            tostring(occupantLocalActive == true),
            tostring(occupantLocalActive and sharedContext or "nil"),
            tostring(occupantLocalActive and sharedMode or "nil"),
            tostring(occupantLocalActive and sharedPlaybackMode or "nil"),
            tostring(occupantLocalActive and sharedResolvedOutput or "nil"),
            tostring(missingTick >= 0 and missingTick or "nil"),
            tostring(missingMs >= 0 and missingMs or "nil"),
            tostring(payload.isOn ~= nil and payload.isOn == true or cached.isOn == true),
            tostring(isPlaying == true),
            tostring(payload.media or cached.media or "nil")
        )
    )
    probe.lastTickByUuid[key] = tonumber(NMClientPlaybackTick.tick) or 0
    probe.lastReasonByUuid[key] = tostring(reason or "unknown")
end

local function observeMemoryDuration(key, elapsedMs)
    if NMPlaybackRuntimeDiagnostics and NMPlaybackRuntimeDiagnostics.observeDuration then
        NMPlaybackRuntimeDiagnostics.observeDuration(NMPlaybackRuntime, key, elapsedMs)
    end
end

local function countMemoryEvent(key, delta)
    if NMPlaybackRuntimeDiagnostics and NMPlaybackRuntimeDiagnostics.countEvent then
        NMPlaybackRuntimeDiagnostics.countEvent(NMPlaybackRuntime, key, delta)
    end
end

local notePlaybackDiagCounter

local function playerCacheKey(player)
    if not player then
        return "nil"
    end
    if player.getOnlineID then
        local onlineId = player:getOnlineID()
        if onlineId ~= nil then
            return "online:" .. tostring(onlineId)
        end
    end
    if player.getUsername then
        local username = player:getUsername()
        if username and tostring(username) ~= "" then
            return "user:" .. tostring(username)
        end
    end
    return tostring(player)
end

local function clearPlaybackWorkStatusCache()
    local cache = NMClientPlaybackTick._playbackWorkStatusCache
    cache.schedulerTick = nil
    cache.playerKey = nil
    cache.status = nil
end

local function hasActivePlaybackRuntime()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return false
    end
    for activeUuid in pairs(active) do
        return true
    end
    return false
end

local function countActivePlaybackRuntimeEntries()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(active) do
        count = count + 1
    end
    return count
end

local function countPlaybackDiag(key, delta)
    local amount = tonumber(delta) or 1
    countMemoryEvent(key, amount)
    notePlaybackDiagCounter(key, amount)
end

local function vehicleProbeLog(channel, tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled) then
        return
    end
    local resolvedChannel = tostring(channel or "vehicle_route")
    if NMCore.isSubsystemDebugEnabled(resolvedChannel) ~= true then
        return
    end
    NMCore.logChannel(resolvedChannel, tostring(tag or "vehicle_probe"), tostring(detail or ""))
end

local function vehicleTraceProbeLog(tag, detail)
    vehicleProbeLog("vehicle_trace", tag, detail)
end

local function getPlayerVehicleSeatSignature(player)
    if not player then
        return "player=nil", {
            seat = "nil",
            vehicleId = "",
            vehicleSqlId = ""
        }
    end
    local vehicle = player.getVehicle and player:getVehicle() or nil
    if not vehicle then
        return "out||", {
            seat = "out",
            vehicleId = "",
            vehicleSqlId = ""
        }
    end
    local seat = vehicle.getSeat and tonumber(vehicle:getSeat(player)) or nil
    local runtimeId = NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and tostring(NMVehicleHelpers.getVehicleIdString(vehicle) or "") or ""
    local sqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and tostring(NMVehicleHelpers.getVehicleSqlIdString(vehicle) or "") or ""
    return table.concat({ tostring(seat or "unknown"), runtimeId, sqlId }, "|"), {
        seat = tostring(seat or "unknown"),
        vehicleId = runtimeId,
        vehicleSqlId = sqlId
    }
end

local function getActiveEmitterClass(active)
    if type(active) ~= "table" then
        return "none"
    end
    if active.mode == "dual" or active._lastRenderMode == "dual" or active._lastEmitterClass == "dual" then
        return "dual"
    end
    if active._centeredWorldOutput == true or active._lastEmitterClass == "world_centered" then
        return "world_centered"
    end
    if active.isWorldEmitter == true or active._lastEmitterClass == "world" then
        return "world"
    end
    return "personal"
end

local function findVehicleProbeActive()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return nil, nil, 0, 0
    end
    local fallbackUuid = nil
    local fallbackActive = nil
    local activeCount = 0
    local vehicleActiveCount = 0
    for uuid, entry in pairs(active) do
        activeCount = activeCount + 1
        if not fallbackActive then
            fallbackUuid = tostring(uuid or "")
            fallbackActive = entry
        end
        if type(entry) == "table" and tostring(entry.context or entry._lastContext or "") == "vehicle" then
            vehicleActiveCount = vehicleActiveCount + 1
            return tostring(uuid or ""), entry, activeCount, vehicleActiveCount
        end
    end
    return fallbackUuid, fallbackActive, activeCount, vehicleActiveCount
end

local function hasVehiclePlaybackProbeInterest()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) == "table" then
        for _, entry in pairs(active) do
            if type(entry) == "table" and tostring(entry.context or entry._lastContext or "") == "vehicle" then
                return true
            end
        end
    end
    for _, context in pairs(NMClientPlaybackTick._trackMonitorContexts or {}) do
        if type(context) == "table" and tostring(context.sourceKind or "") == "vehicle" then
            return true
        end
    end
    for _, cached in pairs(NMClientPlaybackTick._fastSources or {}) do
        if type(cached) == "table" and cached.isVehicleSource == true then
            return true
        end
    end
    return false
end

local function beginVehicleSeatReconcile(reason, eventName, player)
    local probe = NMClientPlaybackTick._vehicleSeatProbe
    local signature = getPlayerVehicleSeatSignature(player)
    probe.lastSignature = signature
    probe.pending = true
    probe.pendingReason = tostring(reason or "vehicle_seat_change")
    probe.pendingEvent = tostring(eventName or "")
    probe.pendingAtMs = nowRealMs()
    probe.pendingSchedulerTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
end

local function getVehicleSeatPendingElapsedMs()
    local probe = NMClientPlaybackTick._vehicleSeatProbe or {}
    if probe.pending ~= true then
        return nil
    end
    local pendingAtMs = tonumber(probe.pendingAtMs) or 0
    if pendingAtMs <= 0 then
        return nil
    end
    return math.max(0, nowRealMs() - pendingAtMs)
end

local function countPlaybackFullDiag(key, delta)
    countPlaybackDiag(key, delta)
end

local function getPersonalTrackMonitorCadenceTicks()
    local cadenceMs = math.max(50, tonumber(NMClientPlaybackTick.personalTrackMonitorCadenceMs) or 500)
    local tps = getObservedSchedulerTicksPerSecond()
    local ticks = math.max(1, math.floor(((cadenceMs * tps) / 1000) + 0.5))
    countPlaybackDiag("playback_track_monitor_personal_ms_cadence", 1)
    countPlaybackDiag("playback_track_monitor_personal_rate_tps", 1)
    countPlaybackDiag("playback_track_monitor_personal_tick_cadence", 1)
    countPlaybackDiag("playback_track_monitor_personal_ms_cadence." .. tostring(math.floor(cadenceMs + 0.5)), 1)
    countPlaybackDiag("playback_track_monitor_personal_rate_tps." .. tostring(math.floor(tps + 0.5)), 1)
    countPlaybackDiag("playback_track_monitor_personal_tick_cadence." .. tostring(ticks), 1)
    return ticks
end

local function roundedCoord(value)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    return string.format("%.2f", n)
end

local function boolText(value)
    return value == true and "true" or "false"
end

local function activeChannelSignature(channel)
    if type(channel) ~= "table" then
        return "nil"
    end
    return table.concat({
        boolText(channel.alive == true),
        boolText(channel.isWorldEmitter == true),
        tostring(channel.sound or channel.soundId or "nil")
    }, ":")
end

local function activeRuntimeEntrySignature(active)
    if type(active) ~= "table" then
        return nil
    end
    return {
        state = table.concat({
            tostring(active.mediaFullType or ""),
            tostring(tonumber(active.epoch) or 0),
            tostring(tonumber(active.trackIndex) or 0),
            tostring(tonumber(active.trackCount) or 0),
            tostring(tonumber(active.sourceGeneration) or 0)
        }, "|"),
        source = table.concat({
            tostring(active.context or ""),
            roundedCoord(active.lastX),
            roundedCoord(active.lastY),
            roundedCoord(active.lastZ)
        }, "|"),
        route = table.concat({
            tostring(active.mode or ""),
            boolText(active.isWorldEmitter == true),
            activeChannelSignature(active.world),
            activeChannelSignature(active.personal),
            boolText(active._vehicleDualRoutePreserved == true),
            tostring(active._vehicleRestartRenderShape or "")
        }, "|")
    }
end

local function snapshotActiveRuntimeSignatures()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    local snapshot = { count = 0, byUuid = {} }
    if type(active) ~= "table" then
        return snapshot
    end
    for uuid, entry in pairs(active) do
        local key = tostring(uuid or "")
        if key ~= "" then
            snapshot.count = snapshot.count + 1
            snapshot.byUuid[key] = activeRuntimeEntrySignature(entry)
        end
    end
    return snapshot
end

local function countActiveRuntimeSignatureChanges(beforeSnapshot, afterSnapshot)
    local before = beforeSnapshot and beforeSnapshot.byUuid or {}
    local after = afterSnapshot and afterSnapshot.byUuid or {}
    local stateChanged = 0
    local sourceChanged = 0
    local routeChanged = 0
    for uuid, afterSig in pairs(after) do
        local beforeSig = before[uuid]
        if not beforeSig or tostring(beforeSig.state or "") ~= tostring(afterSig and afterSig.state or "") then
            stateChanged = stateChanged + 1
        end
        if not beforeSig or tostring(beforeSig.source or "") ~= tostring(afterSig and afterSig.source or "") then
            sourceChanged = sourceChanged + 1
        end
        if not beforeSig or tostring(beforeSig.route or "") ~= tostring(afterSig and afterSig.route or "") then
            routeChanged = routeChanged + 1
        end
    end
    for uuid, beforeSig in pairs(before) do
        if after[uuid] == nil then
            stateChanged = stateChanged + 1
            sourceChanged = sourceChanged + 1
            routeChanged = routeChanged + 1
        end
    end
    return stateChanged, sourceChanged, routeChanged
end

local function isBootstrapActive()
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    return currentTick <= (tonumber(NMClientPlaybackTick._startupBootstrapUntilTick) or 0)
end

local function hasForcedFullPassPending()
    return NMClientPlaybackTick._forceFullPass == true
end

local function hasFastSchedulingHint(targetHint)
    for _, cached in pairs(NMClientPlaybackTick._fastSources or {}) do
        if type(cached) == "table" and tostring(cached.schedulingHint or "") == tostring(targetHint or "") then
            return true
        end
    end
    return false
end

function NMClientPlaybackTick.requestPlayerMoveWakeIfSettled()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return false
    end
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local woke = false
    local sawPlayerFollowSource = false
    for uuid, _ in pairs(active) do
        local cached = NMClientPlaybackTick._fastSources and NMClientPlaybackTick._fastSources[tostring(uuid)] or nil
        local source = type(cached) == "table" and cached.source or nil
        if type(source) == "table"
            and source._nmFastFollowPlayer == true
            and tostring(cached.schedulingHint or "") ~= "" then
            sawPlayerFollowSource = true
            if (tonumber(cached.stationaryStreak) or 0) > 0
                and (tonumber(cached.nextFastCheckTick) or currentTick) > currentTick then
                cached.stationaryStreak = 0
                cached.nextFastCheckTick = currentTick
                countMemoryEvent("playback_player_move_settled_reset", 1)
                woke = true
            end
        end
    end
    if woke == true then
        clearPlaybackWorkStatusCache()
        return true, "settled_wake"
    end
    return false, sawPlayerFollowSource and "active" or "no_world_follow"
end

local function readSourcePosition(source)
    if type(source) ~= "table" then
        return nil
    end
    local x = tonumber(source.x)
    local y = tonumber(source.y)
    local z = tonumber(source.z)
    if x == nil or y == nil or z == nil then
        return nil
    end
    return { x = x, y = y, z = z }
end

local function isVehicleSource(source)
    if type(source) ~= "table" then
        return false
    end
    return tostring(source.context or "") == "vehicle"
        or tostring(source.mode or "") == "vehicle"
        or source._vehicleResolved ~= nil
end

local function isResolvedVehicleSource(source)
    if isVehicleSource(source) ~= true then
        return false
    end
    return source._vehicleResolved == true
        and readSourcePosition(source) ~= nil
end

local function didPositionChange(current, last)
    if not current or not last then
        return true
    end
    return math.abs(current.x - (tonumber(last.x) or 0)) > 0.001
        or math.abs(current.y - (tonumber(last.y) or 0)) > 0.001
        or math.abs(current.z - (tonumber(last.z) or 0)) > 0.001
end

local function fastSourceCadenceTicks(cached)
    local stationaryStreak = type(cached) == "table" and (tonumber(cached.stationaryStreak) or 0) or 0
    local source = type(cached) == "table" and cached.source or nil
    if type(source) == "table" and source._nmFastFollowPlayer == true and stationaryStreak <= 0 then
        return math.max(
            math.max(1, tonumber(NMClientPlaybackTick.fastPositionCadenceTicks) or 3),
            tonumber(NMClientPlaybackTick.movingFollowFastPositionCadenceTicks) or 6
        )
    end
    if stationaryStreak >= math.max(1, tonumber(NMClientPlaybackTick.settledFastPositionStreak) or 3) then
        return math.max(
            math.max(1, tonumber(NMClientPlaybackTick.stationaryFastPositionCadenceTicks) or 15),
            tonumber(NMClientPlaybackTick.settledFastPositionCadenceTicks) or 60
        )
    end
    if stationaryStreak > 0 then
        return math.max(
            math.max(1, tonumber(NMClientPlaybackTick.fastPositionCadenceTicks) or 3),
            tonumber(NMClientPlaybackTick.stationaryFastPositionCadenceTicks) or 15
        )
    end
    return math.max(1, tonumber(NMClientPlaybackTick.fastPositionCadenceTicks) or 3)
end

local function observeFastSourcePosition(cached, source)
    if type(cached) ~= "table" or type(source) ~= "table" then
        return
    end
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local current = readSourcePosition(source)
    if not current then
        cached.lastPosition = nil
        cached.stationaryStreak = 0
        cached.nextFastCheckTick = currentTick + fastSourceCadenceTicks(cached)
        countMemoryEvent("playback_fast_position_stationary_reset", 1)
        notePlaybackDiagCounter("playback_fast_position_stationary_reset", 1)
        return
    end
    if didPositionChange(current, cached.lastPosition) == true then
        if cached.lastPosition ~= nil and (tonumber(cached.stationaryStreak) or 0) > 0 then
            countMemoryEvent("playback_fast_position_stationary_reset", 1)
            notePlaybackDiagCounter("playback_fast_position_stationary_reset", 1)
        end
        cached.lastPosition = current
        cached.stationaryStreak = 0
        cached.nextFastCheckTick = currentTick + fastSourceCadenceTicks(cached)
        countMemoryEvent("playback_fast_position_moved", 1)
        notePlaybackDiagCounter("playback_fast_position_moved", 1)
        if type(cached.source) == "table" and cached.source._nmFastFollowPlayer == true then
            countMemoryEvent("playback_follow_moving_cadence_reset", 1)
            notePlaybackDiagCounter("playback_follow_moving_cadence_reset", 1)
        end
        return
    end
    cached.lastPosition = current
    cached.stationaryStreak = (tonumber(cached.stationaryStreak) or 0) + 1
    cached.nextFastCheckTick = currentTick + fastSourceCadenceTicks(cached)
    countMemoryEvent("playback_fast_position_stationary", 1)
    notePlaybackDiagCounter("playback_fast_position_stationary", 1)
end

local function isFastSourceDue(cached)
    if type(cached) ~= "table" then
        return false
    end
    local nextTick = tonumber(cached.nextFastCheckTick)
    if nextTick == nil then
        return true
    end
    return nextTick <= (tonumber(NMClientPlaybackTick.schedulerTick) or 0)
end

local function readPlayerFollowPosition(player)
    if not player then
        return nil
    end
    local x = tonumber(player.getX and player:getX()) or 0
    local y = tonumber(player.getY and player:getY()) or 0
    local z = tonumber(player.getZ and player:getZ()) or 0
    return { x = x, y = y, z = z }
end

local function hasPlayerFollowMoved(player, updateLast)
    local current = readPlayerFollowPosition(player)
    if not current then
        return false
    end
    local last = NMClientPlaybackTick._lastFollowPlayerPos
    if updateLast == true then
        NMClientPlaybackTick._lastFollowPlayerPos = current
    end
    if not last then
        return true
    end
    return math.abs(current.x - (tonumber(last.x) or 0)) > 0.001
        or math.abs(current.y - (tonumber(last.y) or 0)) > 0.001
        or math.abs(current.z - (tonumber(last.z) or 0)) > 0.001
end

local function isPlayerFollowMovementActive(player)
    return hasPlayerFollowMoved(player, true)
end

local function hasPlayerFollowMovementPending(player)
    return hasPlayerFollowMoved(player, false)
end

local function clearFastLaneSource(uuid, reason)
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    if NMClientPlaybackTick._fastSources[key] ~= nil then
        NMClientPlaybackTick._fastSources[key] = nil
        countMemoryEvent("playback_fast_lane_source_cleared", 1)
        notePlaybackDiagCounter("playback_fast_lane_source_cleared", 1)
        local detail = tostring(reason or "")
        if detail ~= "" then
            notePlaybackDiagCounter("playback_fast_lane_source_cleared_" .. detail, 1)
        end
    end
end

local function clearFastLaneSources(reason)
    local count = 0
    for key, _ in pairs(NMClientPlaybackTick._fastSources or {}) do
        NMClientPlaybackTick._fastSources[key] = nil
        count = count + 1
    end
    if count > 0 then
        countMemoryEvent("playback_fast_lane_source_cleared", count)
        notePlaybackDiagCounter("playback_fast_lane_source_cleared", count)
        local detail = tostring(reason or "")
        if detail ~= "" then
            notePlaybackDiagCounter("playback_fast_lane_source_cleared_" .. detail, count)
        end
    end
end

local function clearTrackMonitorContexts(reason)
    local count = 0
    for key, _ in pairs(NMClientPlaybackTick._trackMonitorContexts or {}) do
        NMClientPlaybackTick._trackMonitorContexts[key] = nil
        count = count + 1
    end
    if count > 0 then
        countMemoryEvent("playback_track_monitor_cache_invalidated", count)
        notePlaybackDiagCounter("playback_track_monitor_cache_invalidated", count)
        local detail = tostring(reason or "")
        if detail ~= "" then
            notePlaybackDiagCounter("playback_track_monitor_cache_invalidated_" .. detail, count)
        end
    end
end

local function rememberTrackMonitorContext(uuid, profile, state, source, sourceKind, item, entry)
    local key = tostring(uuid or state and state.deviceUUID or "")
    if key == "" or type(state) ~= "table" or type(profile) ~= "table" or type(source) ~= "table" then
        return
    end
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[key] or nil
    if type(active) ~= "table" then
        return
    end
    NMClientPlaybackTick._trackMonitorContexts[key] = {
        profile = profile,
        state = state,
        source = source,
        sourceKind = tostring(sourceKind or source.context or source.mode or "detached_item"),
        item = item,
        entry = entry,
        routeClass = getActiveRouteClass and getActiveRouteClass(key) or nil
    }
end

local function anchorFastLaneAfterFullPass(currentTick)
    NMClientPlaybackTick._lastFastPositionSchedulerTick = tonumber(currentTick)
        or tonumber(NMClientPlaybackTick.schedulerTick)
        or tonumber(NMClientPlaybackTick.tick)
        or 0
    countMemoryEvent("playback_fast_lane_anchor_full", 1)
    notePlaybackDiagCounter("playback_fast_lane_anchor_full", 1)
end

function NMClientPlaybackTick.isFastLaneSettledForMonitor(player)
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        countPlaybackDiag("playback_fast_lane_monitor_safe", 1)
        return true
    end
    for uuid, _ in pairs(active) do
        local key = tostring(uuid or "")
        local cached = NMClientPlaybackTick._fastSources and NMClientPlaybackTick._fastSources[key] or nil
        local monitorContext = NMClientPlaybackTick._trackMonitorContexts and NMClientPlaybackTick._trackMonitorContexts[key] or nil
        local routeClass = getActiveRouteClass(key)
            or (type(cached) == "table" and cached.routeClass)
            or (type(monitorContext) == "table" and monitorContext.routeClass)
        if isMPClientRuntime() == true and (routeClass == "world" or routeClass == "dual") then
            countPlaybackDiag("playback_fast_lane_monitor_blocked_mp_world", 1)
            return false
        end
        if routeClass == "world" or routeClass == "dual" then
            if type(cached) ~= "table" or type(cached.source) ~= "table" or readSourcePosition(cached.source) == nil then
                if type(monitorContext) == "table" and monitorContext.sourceKind == "vehicle" then
                    countPlaybackDiag("playback_vehicle_monitor_blocked_unresolved", 1)
                else
                    countPlaybackDiag("playback_fast_lane_monitor_blocked_uncertain", 1)
                end
                return false
            end
            if cached.isVehicleSource == true and cached.vehicleResolved ~= true then
                countPlaybackDiag("playback_vehicle_monitor_blocked_unresolved", 1)
                return false
            end
            if isFastSourceDue(cached) == true then
                if cached.isVehicleSource == true then
                    countPlaybackDiag("playback_vehicle_monitor_blocked_due", 1)
                else
                    countPlaybackDiag("playback_fast_lane_monitor_blocked_due", 1)
                end
                return false
            end
            if cached.source._nmFastFollowPlayer == true and hasPlayerFollowMovementPending(player) == true then
                countPlaybackDiag("playback_fast_lane_monitor_allowed_moving_between_deadlines", 1)
            end
            if cached.isVehicleSource == true then
                countPlaybackDiag("playback_vehicle_monitor_safe", 1)
            end
        elseif routeClass == nil then
            if type(monitorContext) == "table" and monitorContext.sourceKind == "vehicle" then
                countPlaybackDiag("playback_vehicle_monitor_blocked_unresolved", 1)
            else
                countPlaybackDiag("playback_fast_lane_monitor_blocked_uncertain", 1)
            end
            return false
        end
    end
    countPlaybackDiag("playback_fast_lane_monitor_safe", 1)
    return true
end

local function hasTrackMonitorContextsForActivePlayback()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return false
    end
    local sawActive = false
    for uuid, _ in pairs(active) do
        sawActive = true
        local key = tostring(uuid or "")
        if type(NMClientPlaybackTick._trackMonitorContexts[key]) ~= "table" then
            countMemoryEvent("playback_track_monitor_cache_miss_full", 1)
            notePlaybackDiagCounter("playback_track_monitor_cache_miss_full", 1)
            return false
        end
    end
    return sawActive
end

local function isPersonalPortableTrackMonitorCadenceEligible()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return false
    end
    if hasFastSchedulingHint("fast_lane") == true then
        return false
    end
    local sawActive = false
    for uuid, _ in pairs(active) do
        sawActive = true
        local key = tostring(uuid or "")
        local context = NMClientPlaybackTick._trackMonitorContexts and NMClientPlaybackTick._trackMonitorContexts[key] or nil
        if type(context) ~= "table" then
            return false
        end
        local profile = context.profile
        if not (NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile) == true) then
            return false
        end
        local routeClass = getActiveRouteClass(key) or context.routeClass
        if routeClass ~= "personal" then
            return false
        end
        local sourceKind = tostring(context.sourceKind or "")
        if sourceKind == "vehicle" then
            return false
        end
    end
    return sawActive
end

local function getTrackEndUrgencyForActivePlayback()
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" or not NMPlaybackRuntime then
        return false, nil
    end
    local pendingMap = NMPlaybackRuntime.TrackEndPending
    local endedMap = NMPlaybackRuntime.TrackEnded
    local awaitingMap = NMPlaybackRuntime.TrackEndAwaitingAdvance
    if type(pendingMap) ~= "table" and type(endedMap) ~= "table" and type(awaitingMap) ~= "table" then
        return false, nil
    end
    for uuid, _ in pairs(active) do
        local key = tostring(uuid or "")
        if type(endedMap) == "table" and endedMap[key] ~= nil then
            return true, "ended"
        end
        if type(awaitingMap) == "table" and awaitingMap[key] ~= nil then
            return true, "awaiting"
        end
        if type(pendingMap) == "table" and pendingMap[key] ~= nil then
            return true, "pending"
        end
    end
    return false, nil
end

local function canReplaceFullWithTrackMonitor(player)
    countMemoryEvent("playback_track_monitor_due", 1)
    notePlaybackDiagCounter("playback_track_monitor_due", 1)
    local seatProbe = NMClientPlaybackTick._vehicleSeatProbe or nil
    if seatProbe and seatProbe.pending == true then
        countMemoryEvent("playback_track_monitor_blocked_vehicle_seat_pending", 1)
        notePlaybackDiagCounter("playback_track_monitor_blocked_vehicle_seat_pending", 1)
        vehicleProbeLog(
            "vehicle_route",
            "vehicle_seat_track_monitor_blocked",
            formatVehicleTransitionSnapshot("track_monitor_blocked", NMClientPlaybackTick.getVehicleTransitionSnapshot(player))
        )
        return false
    end
    if hasForcedFullPassPending() == true
        or NMClientPlaybackTick._playbackDirty == true
        or isBootstrapActive() == true then
        countMemoryEvent("playback_track_monitor_cache_miss_full", 1)
        notePlaybackDiagCounter("playback_track_monitor_cache_miss_full", 1)
        return false
    end
    if hasTrackMonitorContextsForActivePlayback() ~= true then
        return false
    end
    if NMClientPlaybackTick.isFastLaneSettledForMonitor(player) ~= true then
        countMemoryEvent("playback_track_monitor_blocked_fast_lane", 1)
        notePlaybackDiagCounter("playback_track_monitor_blocked_fast_lane", 1)
        return false
    end
    return true
end

local function isFullPlaybackPassDue()
    local tick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    if hasForcedFullPassPending() then
        return true
    end
    local hasActive = hasActivePlaybackRuntime()
    local cadence
    if hasActive then
        if isPersonalPortableTrackMonitorCadenceEligible() == true then
            cadence = getPersonalTrackMonitorCadenceTicks()
        else
            cadence = math.max(1, tonumber(NMClientPlaybackTick.activeFullCadenceTicks) or 10)
        end
    elseif NMClientPlaybackTick._hasManagedInventoryDevices == true
        and NMClientPlaybackTick._playbackDirty ~= true
        and isBootstrapActive() ~= true
        and isMPClientRuntime() ~= true then
        cadence = math.max(1, tonumber(NMClientPlaybackTick.managedInventoryIdleFullCadenceTicks) or 120)
    else
        cadence = math.max(1, tonumber(NMClientPlaybackTick.idleFullCadenceTicks) or 10)
    end
    local lastFullTick = math.max(
        tonumber(NMClientPlaybackTick._lastFullSchedulerTick) or 0,
        tonumber(NMClientPlaybackTick._lastFullTick) or 0
    )
    return lastFullTick <= 0 or (tick - lastFullTick) >= cadence
end

local function consumeForcedFullPass()
    if hasForcedFullPassPending() ~= true then
        return false
    end
    NMClientPlaybackTick._forceFullPass = false
    return true
end

local function isStableOffInventoryMode(mode)
    local normalized = tostring(mode or "")
    return normalized ~= "attached"
        and normalized ~= "stowed"
        and normalized ~= "drop_pending"
        and normalized ~= "pickup_pending"
        and normalized ~= "placed"
        and normalized ~= "vehicle"
end

local function buildStableOffInventorySignature(item, profile, state, mode, resolvedOutput)
    if not (item and profile and state and state.deviceUUID) then
        return nil
    end
    if state.isOn == true or state.isPlaying == true then
        return nil
    end
    if isStableOffInventoryMode(mode) ~= true then
        return nil
    end
    if NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(state) then
        return nil
    end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    if worldItem ~= nil then
        return nil
    end
    return table.concat({
        tostring(item.getFullType and item:getFullType() or ""),
        tostring(NMCore and NMCore.itemId and NMCore.itemId(item) or ""),
        tostring(profile and profile.id or profile and profile.type or ""),
        tostring(mode or ""),
        tostring(resolvedOutput or ""),
        tostring(state.mediaFullType or "nil"),
        tostring(tonumber(state.trackIndex) or 0),
        tostring(tonumber(state.playbackEpoch) or 0),
        tostring(tonumber(state.sourceGeneration) or 0),
        tostring(tonumber(state.revision) or 0),
        tostring(state.headphoneItemFullType or "nil"),
        tostring(state.batteryPresent == true),
        string.format("%.3f", tonumber(state.batteryCharge) or 0),
        tostring(state.isMuted == true),
        string.format("%.3f", tonumber(state.volume) or 0),
        tostring(state.playbackMode or ""),
        tostring(state.authoritativeMode or ""),
        tostring(state.sourceKind or "")
    }, "|")
end

local function pruneStableOffInventorySignatures(valid)
    for uuid, _ in pairs(NMClientPlaybackTick.stableOffInventorySigSeen or {}) do
        if not (valid and valid[uuid] == true) then
            NMClientPlaybackTick.stableOffInventorySigSeen[uuid] = nil
        end
    end
end

local function buildManagedInventoryTruthSignature(item, profile, state, mode, resolvedOutput)
    local uuid = tostring(state and state.deviceUUID or "")
    if uuid == "" then
        return nil, nil
    end
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    local parts = {
        item = table.concat({
            tostring(item and item.getFullType and item:getFullType() or ""),
            tostring(NMCore and NMCore.itemId and item and NMCore.itemId(item) or ""),
            tostring(profile and (profile.id or profile.type) or "")
        }, ":"),
        route = table.concat({
            tostring(mode or ""),
            tostring(resolvedOutput or ""),
            tostring(state and state.playbackMode or ""),
            tostring(state and state.authoritativeMode or ""),
            tostring(state and state.sourceKind or "")
        }, ":"),
        playback = table.concat({
            tostring(state and state.isOn == true),
            tostring(state and state.isPlaying == true),
            tostring(state and state.isMuted == true),
            string.format("%.3f", tonumber(state and state.volume) or 0),
            tostring(tonumber(state and state.trackIndex) or 0),
            tostring(tonumber(state and state.playbackEpoch) or 0),
            tostring(tonumber(state and state.sourceGeneration) or 0),
            tostring(tonumber(state and state.revision) or 0)
        }, ":"),
        media = tostring(state and state.mediaFullType or "nil"),
        accessory = table.concat({
            tostring(state and state.headphoneItemFullType or "nil"),
            tostring(state and state.batteryPresent == true),
            string.format("%.3f", tonumber(state and state.batteryCharge) or 0)
        }, ":"),
        world = table.concat({
            tostring(worldItem ~= nil),
            tostring(square and square.getX and square:getX() or "nil"),
            tostring(square and square.getY and square:getY() or "nil"),
            tostring(square and square.getZ and square:getZ() or "nil")
        }, ":")
    }
    return table.concat({
        parts.item,
        parts.route,
        parts.playback,
        parts.media,
        parts.accessory,
        parts.world
    }, "|"), parts
end

local function countManagedInventoryTruthChange(previous, parts)
    if not (previous and previous.parts and parts) then
        return
    end
    local prevParts = previous.parts
    if tostring(prevParts.item or "") ~= tostring(parts.item or "") then
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_item", 1)
    end
    if tostring(prevParts.route or "") ~= tostring(parts.route or "") then
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_route", 1)
    end
    if tostring(prevParts.playback or "") ~= tostring(parts.playback or "") then
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_playback", 1)
    end
    if tostring(prevParts.media or "") ~= tostring(parts.media or "") then
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_media", 1)
    end
    if tostring(prevParts.accessory or "") ~= tostring(parts.accessory or "") then
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_accessory", 1)
    end
    if tostring(prevParts.world or "") ~= tostring(parts.world or "") then
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_world", 1)
    end
end

local function observeManagedInventoryTruthSignature(uuid, signature, parts, activeRuntimeEntry)
    local key = tostring(uuid or "")
    if key == "" or signature == nil then
        countPlaybackFullDiag("playback_managed_inventory_probe_unavailable", 1)
        countPlaybackFullDiag("playback_managed_inventory_probe_would_full_sync", 1)
        return { unavailable = true, fullRequired = true }
    end

    local seen = NMClientPlaybackTick.managedInventoryTruthSigSeen
    local previous = seen[key]
    local result = {
        firstSeen = false,
        sameSignature = false,
        changedSignature = false,
        activeRuntimePresent = activeRuntimeEntry ~= nil,
        fullRequired = true,
    }
    if previous == nil then
        result.firstSeen = true
        countPlaybackFullDiag("playback_managed_inventory_probe_first_seen", 1)
        countPlaybackFullDiag("playback_managed_inventory_probe_would_full_sync", 1)
    elseif tostring(previous.signature or "") == tostring(signature or "") then
        result.sameSignature = true
        countPlaybackFullDiag("playback_managed_inventory_probe_same_signature", 1)
        if activeRuntimeEntry == nil then
            result.fullRequired = false
            countPlaybackFullDiag("playback_managed_inventory_probe_would_fast_skip", 1)
        else
            countPlaybackFullDiag("playback_managed_inventory_probe_active_runtime_present", 1)
            countPlaybackFullDiag("playback_managed_inventory_probe_would_full_sync", 1)
        end
    else
        result.changedSignature = true
        countPlaybackFullDiag("playback_managed_inventory_probe_changed_signature", 1)
        countManagedInventoryTruthChange(previous, parts)
        countPlaybackFullDiag("playback_managed_inventory_probe_would_full_sync", 1)
    end
    seen[key] = {
        signature = tostring(signature or ""),
        parts = parts,
    }
    return result
end

local function isManagedInventoryFastPathMode(mode)
    local normalized = tostring(mode or "")
    return normalized ~= "drop_pending"
        and normalized ~= "pickup_pending"
        and normalized ~= "placed"
        and normalized ~= "vehicle"
end

local function shouldFastSkipManagedInventorySync(truthResult, mode, state, passState)
    local pass = type(passState) == "table" and passState or {}
    local normalizedMode = tostring(mode or "")
    local resolvedOutput = tostring(pass.resolvedOutput or "")
    if not (truthResult and truthResult.sameSignature == true and truthResult.fullRequired ~= true) then
        countPlaybackFullDiag("playback_managed_inventory_fast_full_required", 1)
        if truthResult and truthResult.changedSignature == true then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_signature_changed", 1)
        end
        return false
    end
    if pass.forceFullConsumed == true or pass.forcedBeforePass == true or pass.dirtyBeforePass == true or pass.bootstrapBeforePass == true then
        countPlaybackFullDiag("playback_managed_inventory_fast_full_required", 1)
        countPlaybackFullDiag("playback_managed_inventory_fast_blocked_forced_dirty", 1)
        return false
    end
    if pass.mpClient == true or pass.activeBeforePass == true then
        countPlaybackFullDiag("playback_managed_inventory_fast_full_required", 1)
        return false
    end
    if truthResult.activeRuntimePresent == true then
        countPlaybackFullDiag("playback_managed_inventory_fast_full_required", 1)
        countPlaybackFullDiag("playback_managed_inventory_fast_blocked_active_runtime", 1)
        return false
    end
    if state and (state.isOn == true or state.isPlaying == true) then
        countPlaybackFullDiag("playback_managed_inventory_fast_full_required", 1)
        countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_active", 1)
        if state.isPlaying == true then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_playing", 1)
        elseif state.isOn == true then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_on_not_playing", 1)
        end
        if truthResult.activeRuntimePresent ~= true then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_runtime_absent", 1)
        end
        if resolvedOutput == "world" then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_output_world", 1)
        elseif resolvedOutput == "inventory" then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_output_inventory", 1)
        elseif resolvedOutput == "silent" then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_output_silent", 1)
        else
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_output_other", 1)
        end
        if normalizedMode == "attached" then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_mode_attached", 1)
        elseif normalizedMode == "stowed" then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_state_mode_stowed", 1)
        end
        return false
    end
    if isManagedInventoryFastPathMode(mode) ~= true then
        countPlaybackFullDiag("playback_managed_inventory_fast_full_required", 1)
        if normalizedMode == "drop_pending" or normalizedMode == "pickup_pending" then
            countPlaybackFullDiag("playback_managed_inventory_fast_blocked_transition_mode", 1)
        end
        countPlaybackFullDiag("playback_managed_inventory_fast_blocked_mode", 1)
        return false
    end
    if normalizedMode == "attached" then
        countPlaybackFullDiag("playback_managed_inventory_fast_attached_skip", 1)
    end
    countPlaybackFullDiag("playback_managed_inventory_fast_skip", 1)
    return true
end

local function pruneManagedInventoryTruthSignatures(valid)
    for uuid, _ in pairs(NMClientPlaybackTick.managedInventoryTruthSigSeen or {}) do
        if not (valid and valid[uuid] == true) then
            NMClientPlaybackTick.managedInventoryTruthSigSeen[uuid] = nil
        end
    end
end

local function noteInterestReason(reason)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local diag = NMClientPlaybackTick._interestDiag
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    if tonumber(diag.lastTick) == currentTick then
        return
    end
    diag.lastTick = currentTick
    local key = tostring(reason or "unknown")
    diag.counters[key] = (tonumber(diag.counters[key]) or 0) + 1
end

notePlaybackDiagCounter = function(key, delta)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local diag = NMClientPlaybackTick._interestDiag
    local token = tostring(key or "")
    if token == "" then
        return
    end
    diag.counters[token] = (tonumber(diag.counters[token]) or 0) + (tonumber(delta) or 1)
end

local function noteManagedInventorySkipClean()
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    if tonumber(NMClientPlaybackTick._lastManagedInventorySkipDiagTick) == currentTick then
        return
    end
    NMClientPlaybackTick._lastManagedInventorySkipDiagTick = currentTick
    local diag = NMClientPlaybackTick._interestDiag
    diag.counters["playback_managed_inventory_skip_clean"] = (tonumber(diag.counters["playback_managed_inventory_skip_clean"]) or 0) + 1
    countMemoryEvent("playback_managed_inventory_skip_clean", 1)
end

local function flushInterestDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local diag = NMClientPlaybackTick._interestDiag
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(diag.lastLogMs) or 0)) < 5000 then
        return
    end
    diag.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(diag.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        diag.counters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "playback_interest_diag", table.concat(parts, " | "))
    end
end

local function resolveInterestReason()
    if hasForcedFullPassPending() then
        return true, "forced_full"
    end
    if NMClientPlaybackTick._playbackDirty == true then
        return true, "dirty"
    end
    if isBootstrapActive() then
        return true, "bootstrap"
    end
    if hasActivePlaybackRuntime() then
        return true, "active_runtime"
    end
    if NMClientPlaybackTick._hasManagedInventoryDevices == true and isMPClientRuntime() ~= true then
        if isFullPlaybackPassDue() == true then
            return true, "playback_managed_inventory_full_due"
        end
        return false, "playback_managed_inventory_cold"
    end
    return false, "idle"
end

function NMClientPlaybackTick.observeSchedulerTick(tickStep)
    local step = math.max(1, tonumber(tickStep) or 1)
    local previousTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    NMClientPlaybackTick.schedulerTick = previousTick + step
    local rate = NMClientPlaybackTick._schedulerRate
    local nowMsValue = nowRealMs()
    if type(rate) == "table" and nowMsValue > 0 then
        local lastMs = tonumber(rate.lastMs) or 0
        local lastTick = tonumber(rate.lastTick) or previousTick
        if lastMs > 0 and nowMsValue > lastMs then
            local elapsedMs = nowMsValue - lastMs
            local elapsedTicks = math.max(0, (tonumber(NMClientPlaybackTick.schedulerTick) or 0) - lastTick)
            if elapsedTicks > 0 then
                local instantTps = (elapsedTicks * 1000) / elapsedMs
                if instantTps >= 1 and instantTps <= 1000 then
                    local previousTps = tonumber(rate.ticksPerSecond) or instantTps
                    rate.ticksPerSecond = (previousTps * 0.85) + (instantTps * 0.15)
                end
            end
        end
        rate.lastMs = nowMsValue
        rate.lastTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    end
    flushInterestDiag()
end

function NMClientPlaybackTick.markDirty(_reason)
    NMClientPlaybackTick._playbackDirty = true
    clearPlaybackWorkStatusCache()
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("playback_dirty")
    end
end

function NMClientPlaybackTick.beginStartupBootstrap(tickBudget)
    local nowTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    NMClientPlaybackTick._startupBootstrapUntilTick = math.max(
        tonumber(NMClientPlaybackTick._startupBootstrapUntilTick) or 0,
        nowTick + math.max(1, tonumber(tickBudget) or 120)
    )
    NMClientPlaybackTick._playbackDirty = true
    clearPlaybackWorkStatusCache()
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("playback_startup_bootstrap")
    end
end

function NMClientPlaybackTick.hasInterest()
    local interested, reason = resolveInterestReason()
    noteInterestReason(reason)
    if reason == "playback_managed_inventory_cold" then
        noteManagedInventorySkipClean()
    end
    return interested
end

function NMClientPlaybackTick.hasColdManagedInventoryDeadline()
    return NMClientPlaybackTick._hasManagedInventoryDevices == true
        and isMPClientRuntime() ~= true
        and hasForcedFullPassPending() ~= true
        and NMClientPlaybackTick._playbackDirty ~= true
        and isBootstrapActive() ~= true
        and hasActivePlaybackRuntime() ~= true
        and isFullPlaybackPassDue() ~= true
end

function NMClientPlaybackTick.getNextManagedInventoryCheckTick()
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    if isMPClientRuntime() == true then
        return math.huge
    end
    if hasForcedFullPassPending() == true
        or NMClientPlaybackTick._playbackDirty == true
        or isBootstrapActive() == true
        or hasActivePlaybackRuntime() == true then
        return currentTick
    end
    if NMClientPlaybackTick._hasManagedInventoryDevices ~= true then
        return math.huge
    end
    local lastFullTick = math.max(
        tonumber(NMClientPlaybackTick._lastFullSchedulerTick) or 0,
        tonumber(NMClientPlaybackTick._lastFullTick) or 0
    )
    if lastFullTick <= 0 then
        return currentTick
    end
    local cadence = math.max(1, tonumber(NMClientPlaybackTick.managedInventoryIdleFullCadenceTicks) or 120)
    return math.max(currentTick, lastFullTick + cadence)
end

local function getNextFullPlaybackPassTick()
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local hasActive = hasActivePlaybackRuntime()
    local cadence
    if hasActive then
        if isPersonalPortableTrackMonitorCadenceEligible() == true then
            cadence = getPersonalTrackMonitorCadenceTicks()
        else
            cadence = math.max(1, tonumber(NMClientPlaybackTick.activeFullCadenceTicks) or 10)
        end
    elseif NMClientPlaybackTick._hasManagedInventoryDevices == true
        and NMClientPlaybackTick._playbackDirty ~= true
        and isBootstrapActive() ~= true
        and isMPClientRuntime() ~= true then
        cadence = math.max(1, tonumber(NMClientPlaybackTick.managedInventoryIdleFullCadenceTicks) or 120)
    else
        cadence = math.max(1, tonumber(NMClientPlaybackTick.idleFullCadenceTicks) or 10)
    end
    local lastFullTick = math.max(
        tonumber(NMClientPlaybackTick._lastFullSchedulerTick) or 0,
        tonumber(NMClientPlaybackTick._lastFullTick) or 0
    )
    if lastFullTick <= 0 then
        return currentTick
    end
    local nextDueTick = math.max(currentTick, lastFullTick + cadence)
    local remainder = nextDueTick % cadence
    if remainder ~= 0 then
        nextDueTick = nextDueTick + (cadence - remainder)
    end
    return nextDueTick
end

local function getNextFastPositionTick(player)
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local cadence = math.max(1, tonumber(NMClientPlaybackTick.fastPositionCadenceTicks) or 3)
    local lastFastTick = tonumber(NMClientPlaybackTick._lastFastPositionSchedulerTick) or 0
    local fallbackTick = currentTick
    if lastFastTick > 0 then
        fallbackTick = math.max(currentTick, lastFastTick + cadence)
        local remainder = fallbackTick % cadence
        if remainder ~= 0 then
            fallbackTick = fallbackTick + (cadence - remainder)
        end
    end

    local nextDueTick = math.huge
    local hasSource = false
    local stationaryDue = false
    local stationaryDeferred = false
    for _, cached in pairs(NMClientPlaybackTick._fastSources or {}) do
        if type(cached) == "table" then
            hasSource = true
            local hint = tostring(cached.schedulingHint or "")
            local sourceTick = tonumber(cached.nextFastCheckTick) or fallbackTick
            if type(cached.source) == "table" and cached.source._nmFastFollowPlayer == true and hasPlayerFollowMovementPending(player) == true then
                if sourceTick <= currentTick then
                    countMemoryEvent("playback_follow_moving_cadence_due", 1)
                    notePlaybackDiagCounter("playback_follow_moving_cadence_due", 1)
                else
                    countMemoryEvent("playback_follow_moving_cadence_skip", 1)
                    notePlaybackDiagCounter("playback_follow_moving_cadence_skip", 1)
                end
            end
            if sourceTick <= currentTick and (tonumber(cached.stationaryStreak) or 0) > 0 then
                stationaryDue = true
            elseif sourceTick > currentTick and (tonumber(cached.stationaryStreak) or 0) > 0 then
                stationaryDeferred = true
            end
            nextDueTick = math.min(nextDueTick, sourceTick)
        end
    end
    if hasSource ~= true then
        nextDueTick = fallbackTick
    end
    return math.max(currentTick, nextDueTick), stationaryDue, stationaryDeferred
end

function NMClientPlaybackTick.getVehicleTransitionSnapshot(player)
    local signature, vehicle = getPlayerVehicleSeatSignature(player)
    local uuid, active, activeCount, vehicleActiveCount = findVehicleProbeActive()
    local nextFastTick = math.huge
    local stationaryDue = false
    if hasFastSchedulingHint("fast_lane") == true then
        nextFastTick, stationaryDue = getNextFastPositionTick(player)
    end
    local probe = NMClientPlaybackTick._vehicleSeatProbe or {}
    return {
        signature = signature,
        schedulerTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0,
        seat = vehicle.seat,
        vehicleId = vehicle.vehicleId,
        vehicleSqlId = vehicle.vehicleSqlId,
        activeUuid = tostring(uuid or ""),
        activeCount = tonumber(activeCount) or 0,
        vehicleActiveCount = tonumber(vehicleActiveCount) or 0,
        activeMode = tostring(active and active.mode or "none"),
        activeRouteClass = uuid and getActiveRouteClass and getActiveRouteClass(uuid) or nil,
        activeEmitterClass = getActiveEmitterClass(active),
        localVehicleOverride = active and active._localVehiclePersonalOverride == true or false,
        lastPassKind = tostring(NMClientPlaybackTick._lastPassKind or "none"),
        forcedFull = NMClientPlaybackTick._forceFullPass == true,
        forceFullReason = tostring(NMClientPlaybackTick._forceFullReason or ""),
        dirty = NMClientPlaybackTick._playbackDirty == true,
        nextFullTick = getNextFullPlaybackPassTick(),
        nextFastTick = nextFastTick,
        stationaryFastDue = stationaryDue == true,
        pending = probe.pending == true,
        pendingReason = tostring(probe.pendingReason or ""),
        pendingEvent = tostring(probe.pendingEvent or ""),
        pendingElapsedMs = getVehicleSeatPendingElapsedMs()
    }
end

formatVehicleTransitionSnapshot = function(eventName, snapshot)
    return string.format(
        "event=%s tick=%s sig=%s seat=%s vehicleId=%s vehicleSqlId=%s activeUuid=%s activeCount=%d vehicleActive=%d activeMode=%s route=%s emitter=%s occupantLocal=%s lastPass=%s forced=%s forceReason=%s dirty=%s nextFull=%s nextFast=%s stationaryFastDue=%s pending=%s pendingReason=%s pendingEvent=%s pendingElapsedMs=%s",
        tostring(eventName or ""),
        tostring(snapshot and snapshot.schedulerTick or "nil"),
        tostring(snapshot and snapshot.signature or ""),
        tostring(snapshot and snapshot.seat or ""),
        tostring(snapshot and snapshot.vehicleId or ""),
        tostring(snapshot and snapshot.vehicleSqlId or ""),
        tostring(snapshot and snapshot.activeUuid or ""),
        tonumber(snapshot and snapshot.activeCount) or 0,
        tonumber(snapshot and snapshot.vehicleActiveCount) or 0,
        tostring(snapshot and snapshot.activeMode or ""),
        tostring(snapshot and snapshot.activeRouteClass or "nil"),
        tostring(snapshot and snapshot.activeEmitterClass or ""),
        tostring(snapshot and snapshot.localVehicleOverride == true),
        tostring(snapshot and snapshot.lastPassKind or ""),
        tostring(snapshot and snapshot.forcedFull == true),
        tostring(snapshot and snapshot.forceFullReason or ""),
        tostring(snapshot and snapshot.dirty == true),
        tostring(snapshot and snapshot.nextFullTick or "nil"),
        tostring(snapshot and snapshot.nextFastTick or "nil"),
        tostring(snapshot and snapshot.stationaryFastDue == true),
        tostring(snapshot and snapshot.pending == true),
        tostring(snapshot and snapshot.pendingReason or ""),
        tostring(snapshot and snapshot.pendingEvent or ""),
        tostring(snapshot and snapshot.pendingElapsedMs or "nil")
    )
end

local function requestVehicleSeatFullPass(reason, eventName, player)
    beginVehicleSeatReconcile(reason, eventName, player)
    NMClientPlaybackTick._forceFullPass = true
    NMClientPlaybackTick._forceFullReason = tostring(reason or "vehicle_seat_change")
    NMClientPlaybackTick._playbackDirty = true
    clearPlaybackWorkStatusCache()
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("vehicle_seat_reconcile")
    end
end

function NMClientPlaybackTick.observeVehicleSeatEvent(eventName, player)
    local reason = "vehicle_seat_event_" .. tostring(eventName or "unknown")
    requestVehicleSeatFullPass(reason, eventName, player)
    local snapshot = NMClientPlaybackTick.getVehicleTransitionSnapshot(player)
    vehicleTraceProbeLog("vehicle_seat_event", formatVehicleTransitionSnapshot(eventName, snapshot))
end

function NMClientPlaybackTick.getPendingVehicleSeatTransition()
    local probe = NMClientPlaybackTick._vehicleSeatProbe or nil
    if not (probe and probe.pending == true) then
        return nil
    end
    return {
        reason = tostring(probe.pendingReason or ""),
        event = tostring(probe.pendingEvent or ""),
        elapsedMs = getVehicleSeatPendingElapsedMs(),
        schedulerTick = tonumber(probe.pendingSchedulerTick) or 0,
        signature = tostring(probe.lastSignature or "")
    }
end

local function observeVehicleSeatSignatureForActive(player)
    if hasVehiclePlaybackProbeInterest() ~= true then
        return false
    end
    local signature = getPlayerVehicleSeatSignature(player)
    local probe = NMClientPlaybackTick._vehicleSeatProbe
    if probe.lastSignature == nil then
        probe.lastSignature = signature
        return false
    end
    if tostring(probe.lastSignature or "") == tostring(signature or "") then
        return false
    end
    local snapshotBefore = NMClientPlaybackTick.getVehicleTransitionSnapshot(player)
    if probe.pending == true then
        probe.lastSignature = signature
        vehicleTraceProbeLog("vehicle_seat_pending_signature_update", formatVehicleTransitionSnapshot("poll_pending", snapshotBefore))
        return false
    end
    requestVehicleSeatFullPass("vehicle_seat_poll_mismatch", "poll_mismatch", player)
    local snapshotAfter = NMClientPlaybackTick.getVehicleTransitionSnapshot(player)
    vehicleProbeLog("vehicle_route", "vehicle_seat_poll_mismatch", formatVehicleTransitionSnapshot("poll_mismatch", snapshotAfter))
    vehicleProbeLog("playback_transition", "vehicle_seat_poll_mismatch", formatVehicleTransitionSnapshot("poll_mismatch", snapshotAfter))
    return true
end

local function computePlaybackWorkStatus(player)
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local interested, reason = resolveInterestReason()
    if interested ~= true then
        if reason == "playback_managed_inventory_cold" then
            local nextManagedTick = NMClientPlaybackTick.getNextManagedInventoryCheckTick()
            return {
                due = false,
                reason = "playback_managed_inventory_cold",
                nextTick = nextManagedTick,
                interestReason = reason,
                managedInventoryCold = true
            }
        end
        return { due = false, reason = tostring(reason or "idle"), nextTick = math.huge, interestReason = reason }
    end
    if hasForcedFullPassPending() == true then
        return {
            due = true,
            reason = "forced_full",
            nextTick = currentTick,
            interestReason = reason,
            forcedFull = true,
            fullDue = true
        }
    end
    if NMClientPlaybackTick._playbackDirty == true then
        return {
            due = true,
            reason = "dirty",
            nextTick = currentTick,
            interestReason = reason,
            fullDue = true
        }
    end
    if isBootstrapActive() == true then
        return {
            due = true,
            reason = "bootstrap",
            nextTick = currentTick,
            interestReason = reason,
            fullDue = true
        }
    end
    if hasActivePlaybackRuntime() ~= true then
        if isFullPlaybackPassDue() == true then
            return {
                due = true,
                reason = tostring(reason or "playback_due"),
                nextTick = currentTick,
                interestReason = reason,
                fullDue = true
            }
        end
        return {
            due = false,
            reason = tostring(reason or "playback_cold"),
            nextTick = NMClientPlaybackTick.getNextManagedInventoryCheckTick(),
            interestReason = reason
        }
    end

    if observeVehicleSeatSignatureForActive(player) == true then
        return {
            due = true,
            reason = "vehicle_seat_poll_mismatch",
            nextTick = currentTick,
            interestReason = reason,
            forcedFull = true,
            fullDue = true
        }
    end

    if hasTrackMonitorContextsForActivePlayback() ~= true then
        countPlaybackDiag("playback_track_monitor_full_safety_fallback", 1)
        return {
            due = true,
            reason = "playback_active_due",
            nextTick = currentTick,
            interestReason = reason,
            playbackDiag = "playback_active_due",
            fullDue = true
        }
    end

    local trackEndUrgent, trackEndUrgentReason = getTrackEndUrgencyForActivePlayback()
    if trackEndUrgent == true then
        countPlaybackDiag("playback_track_end_urgent_due", 1)
        if trackEndUrgentReason == "pending" then
            countPlaybackDiag("playback_track_end_pending_fast_monitor", 1)
        end
        if canReplaceFullWithTrackMonitor(player) == true then
            return {
                due = true,
                reason = "playback_track_monitor_due",
                nextTick = currentTick,
                interestReason = reason,
                playbackDiag = "playback_track_end_urgent_due",
                trackMonitorDue = true
            }
        end
        countPlaybackDiag("playback_track_monitor_full_safety_fallback", 1)
        return {
            due = true,
            reason = "playback_active_due",
            nextTick = currentTick,
            interestReason = reason,
            playbackDiag = "playback_active_due",
            fullDue = true
        }
    end

    local nextFullTick = getNextFullPlaybackPassTick()
    if nextFullTick <= currentTick then
        if isPersonalPortableTrackMonitorCadenceEligible() == true then
            countPlaybackDiag("playback_track_monitor_personal_cadence", 1)
        end
        if canReplaceFullWithTrackMonitor(player) == true then
            return {
                due = true,
                reason = "playback_track_monitor_due",
                nextTick = currentTick,
                interestReason = reason,
                playbackDiag = "playback_track_monitor_due",
                trackMonitorDue = true
            }
        end
        countPlaybackDiag("playback_track_monitor_full_safety_fallback", 1)
        return {
            due = true,
            reason = "playback_active_due",
            nextTick = currentTick,
            interestReason = reason,
            playbackDiag = "playback_active_due",
            fullDue = true
        }
    end
    if isPersonalPortableTrackMonitorCadenceEligible() == true then
        countPlaybackDiag("playback_track_monitor_cold_until", 1)
    end
    if hasFastSchedulingHint("fast_lane") == true then
        local nextFastTick, stationaryDue, stationaryDeferred = getNextFastPositionTick(player)
        if nextFastTick <= currentTick then
            return {
                due = true,
                reason = "playback_active_fast_lane_due",
                nextTick = currentTick,
                interestReason = reason,
                playbackDiag = "playback_active_fast_lane_due",
                fastLanePositionDue = true,
                stationaryFastDeadlineDue = stationaryDue == true
            }
        end
        return {
            due = false,
            reason = "playback_active_cold_until",
            nextTick = math.min(nextFullTick, nextFastTick),
            interestReason = reason,
            playbackDiag = "playback_active_deadline_skip",
            playbackNextWakeSet = true,
            stationaryFastDeadlineSkip = stationaryDeferred == true
        }
    end
    return {
        due = false,
        reason = "playback_active_cold_until",
        nextTick = nextFullTick,
        interestReason = reason,
        playbackDiag = "playback_active_deadline_skip",
        playbackNextWakeSet = true
    }
end

local function recordPlaybackWorkStatusDiagnostics(status, playerKey)
    local cache = NMClientPlaybackTick._playbackWorkStatusCache
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local key = tostring(playerKey or "nil")
    if cache.diagTick == currentTick and cache.diagPlayerKey == key then
        countMemoryEvent("playback_status_diag_suppressed_duplicate", 1)
        return
    end
    cache.diagTick = currentTick
    cache.diagPlayerKey = key
    countMemoryEvent("playback_status_diag_once", 1)
    local reason = tostring(status and status.interestReason or status and status.reason or "idle")
    noteInterestReason(reason)
    if status and status.managedInventoryCold == true then
        noteManagedInventorySkipClean()
    end
    local playbackDiag = tostring(status and status.playbackDiag or "")
    if playbackDiag ~= "" then
        countMemoryEvent(playbackDiag, 1)
        notePlaybackDiagCounter(playbackDiag, 1)
    end
    if status and status.playbackNextWakeSet == true then
        countMemoryEvent("playback_active_next_wake_set", 1)
    end
    if status and status.stationaryFastDeadlineSkip == true then
        countMemoryEvent("playback_fast_position_stationary_deadline_skip", 1)
        notePlaybackDiagCounter("playback_fast_position_stationary_deadline_skip", 1)
    end
    if status and status.stationaryFastDeadlineDue == true then
        countMemoryEvent("playback_fast_position_stationary_deadline_due", 1)
        notePlaybackDiagCounter("playback_fast_position_stationary_deadline_due", 1)
    end
end

function NMClientPlaybackTick.getPlaybackWorkStatus(player, recordDiagnostics)
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local key = playerCacheKey(player)
    local cache = NMClientPlaybackTick._playbackWorkStatusCache
    local status
    if cache.schedulerTick == currentTick and cache.playerKey == key and type(cache.status) == "table" then
        status = cache.status
        countMemoryEvent("playback_status_cache_hit", 1)
    else
        status = computePlaybackWorkStatus(player)
        cache.schedulerTick = currentTick
        cache.playerKey = key
        cache.status = status
        countMemoryEvent("playback_status_cache_miss", 1)
    end
    if recordDiagnostics == true then
        recordPlaybackWorkStatusDiagnostics(status, key)
    end
    return status
end

function NMClientPlaybackTick.isPlaybackWorkDue(player, recordDiagnostics)
    local status = NMClientPlaybackTick.getPlaybackWorkStatus(player, recordDiagnostics)
    return status and status.due == true, status and status.reason or "idle", status
end

function NMClientPlaybackTick.getNextPlaybackWorkTick(player)
    local status = NMClientPlaybackTick.getPlaybackWorkStatus(player, false)
    if status and status.nextTick ~= nil then
        return tonumber(status.nextTick) or math.huge
    end
    return math.huge
end

function NMClientPlaybackTick.getSchedulingDecision(player, playbackStatus)
    local status = playbackStatus
    if type(status) ~= "table" then
        status = NMClientPlaybackTick.getPlaybackWorkStatus(player or (getPlayer and getPlayer() or nil), false)
    end
    if not status or status.due ~= true then
        return {
            class = "idle",
            hasActive = false,
            forcedFull = false,
            fullDue = false,
            runTrackMonitor = false,
            runFastLanePosition = false,
            runStableActive = false
        }
    end
    local hasActive = hasActivePlaybackRuntime()
    local forcedFull = status.forcedFull == true or hasForcedFullPassPending()
    local fullDue = status.fullDue == true
    local trackMonitorDue = status.trackMonitorDue == true
    local fastLanePositionDue = status.fastLanePositionDue == true

    if forcedFull == true then
        return {
            class = "full_reconcile_due",
            hasActive = hasActive,
            forcedFull = true,
            fullDue = true,
            runTrackMonitor = false,
            runFastLanePosition = false,
            runStableActive = false
        }
    end
    if fullDue == true then
        return {
            class = "full_reconcile_due",
            hasActive = hasActive,
            forcedFull = false,
            fullDue = true,
            runTrackMonitor = false,
            runFastLanePosition = false,
            runStableActive = hasActive
        }
    end
    if trackMonitorDue == true then
        return {
            class = "track_monitor_due",
            hasActive = hasActive,
            forcedFull = false,
            fullDue = false,
            runTrackMonitor = true,
            runFastLanePosition = false,
            runStableActive = hasActive
        }
    end
    if fastLanePositionDue == true then
        return {
            class = "position_only_due",
            hasActive = hasActive,
            forcedFull = false,
            fullDue = false,
            runTrackMonitor = false,
            runFastLanePosition = true,
            runStableActive = false
        }
    end
    if hasActive == true then
        return {
            class = "stable_active",
            hasActive = true,
            forcedFull = false,
            fullDue = false,
            runTrackMonitor = false,
            runFastLanePosition = false,
            runStableActive = true
        }
    end
    return {
        class = "idle",
        hasActive = false,
        forcedFull = false,
        fullDue = false,
        runTrackMonitor = false,
        runFastLanePosition = false,
        runStableActive = false
    }
end

function NMClientPlaybackTick.requestFullPass(reason)
    NMClientPlaybackTick._forceFullPass = true
    NMClientPlaybackTick._forceFullReason = tostring(reason or "requested")
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("playback_full_pass")
    end
    NMClientPlaybackTick.markDirty(reason)
end

function NMClientPlaybackTick.requestInventoryRefreshPass(reason)
    local nowMs = nowRealMs()
    local debounceMs = 750
    local previousMs = tonumber(NMClientPlaybackTick._lastInventoryRefreshFullRequestMs) or 0
    if previousMs <= 0 or (nowMs - previousMs) >= debounceMs then
        NMClientPlaybackTick._lastInventoryRefreshFullRequestMs = nowMs
        countMemoryEvent("playback_inventory_refresh_full_requested", 1)
        NMClientPlaybackTick.requestFullPass(reason or "inventory_refresh")
        return true, "full_requested"
    end
    countMemoryEvent("playback_inventory_refresh_full_collapsed", 1)
    countMemoryEvent("playback_inventory_refresh_wake_only", 1)
    clearPlaybackWorkStatusCache()
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("inventory_refresh_collapsed")
    end
    return false, "collapsed"
end

local function shouldLogModeResolution(uuid, signature, changed)
    if changed == true then
        return true
    end
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    local nowMs = nowRealMs()
    local previousSig = tostring(NMClientPlaybackTick.modeResolutionSigSeen[key] or "")
    local previousMs = tonumber(NMClientPlaybackTick.modeResolutionHeartbeatMs[key]) or 0
    local currentSig = tostring(signature or "")
    local bootstrapMs = tonumber(NMClientPlaybackTick.modeResolutionBootstrapMs[key]) or 0
    if bootstrapMs <= 0 then
        bootstrapMs = nowMs
        NMClientPlaybackTick.modeResolutionBootstrapMs[key] = bootstrapMs
    end
    if previousSig == "" then
        NMClientPlaybackTick.modeResolutionSigSeen[key] = currentSig
        NMClientPlaybackTick.modeResolutionHeartbeatMs[key] = nowMs
        return false
    end
    local heartbeatMs = (nowMs - bootstrapMs) < 5000 and 60000
        or (NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.longHeartbeatMs and NMRuntimeProbeAdapter.longHeartbeatMs() or 60000)
    if previousSig ~= currentSig or (nowMs - previousMs) >= heartbeatMs then
        NMClientPlaybackTick.modeResolutionSigSeen[key] = currentSig
        NMClientPlaybackTick.modeResolutionHeartbeatMs[key] = nowMs
        return previousSig ~= currentSig or (nowMs - bootstrapMs) >= 5000
    end
    return false
end

local function shouldLogDetachedSync(uuid, state, src)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    local detachedContext = tostring(src and src.context or "")
    local heartbeatMs = NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.shortHeartbeatMs
        and NMRuntimeProbeAdapter.shortHeartbeatMs()
        or 15000
    local coordStep = 1.0
    if detachedContext == "vehicle" then
        heartbeatMs = math.max(heartbeatMs, 60000)
        if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace")) then
            return NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat
                and NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
                    NMClientPlaybackTick.detachedSyncSigSeen,
                    NMClientPlaybackTick.detachedSyncHeartbeatMs,
                    key,
                    table.concat({
                        tostring(detachedContext),
                        tostring(state and state.isOn == true),
                        tostring(state and state.isPlaying == true),
                        tostring(state and state.mediaFullType or "nil")
                    }, "|"),
                    heartbeatMs
                ) == true
        end
        coordStep = 8.0
    elseif detachedContext == "attached" or detachedContext == "stowed" then
        heartbeatMs = math.max(heartbeatMs, 30000)
        coordStep = 4.0
    end
    return NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.shouldEmitBucketedTransitionOrHeartbeat
        and NMRuntimeProbeAdapter.shouldEmitBucketedTransitionOrHeartbeat(
            NMClientPlaybackTick.detachedSyncSigSeen,
            NMClientPlaybackTick.detachedSyncHeartbeatMs,
            key,
            {
                parts = {
                    tostring(detachedContext ~= "" and detachedContext or "nil"),
                    tostring(state and state.isOn == true),
                    tostring(state and state.isPlaying == true),
                    tostring(state and state.mediaFullType or "nil")
                },
                x = src and src.x or nil,
                y = src and src.y or nil,
                z = src and src.z or nil,
                coordStep = coordStep,
                zStep = 1.0,
                intervalMs = heartbeatMs
            }
        ) == true
end

local continuity = NMClientVehicleContinuity
local detachedOrchestration = NMClientDetachedOrchestration

local setVehicleIdentityState = continuity.setVehicleIdentityState
local resolveVehicleCanonicalGeneration = continuity.resolveVehicleCanonicalGeneration
local persistVehicleCanonicalGeneration = continuity.persistVehicleCanonicalGeneration
consumeAndDispatchTrackFinished = function(player, profile, state, entry, item, sourceKind, uuid)
    NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(player, profile, state, entry, item, sourceKind, uuid)
end

local function applySPLocalVehiclePowerGuard(profile, state, source, uuid)
    NMClientSPLocalRuntime.applyVehiclePowerGuard(profile, state, source, uuid, {
        vehiclePowerTickMs = NMClientPlaybackTick.vehiclePowerTickMs,
        nowMs = nowRealMs
    })
end

local function reconcileDroppedInventoryToPlacedSP(player, currentInventoryByUuid)
    NMClientSPDropReconcile.reconcile({
        player = player,
        currentInventoryByUuid = currentInventoryByUuid,
        previousInventoryByUuid = NMClientPlaybackTick.lastInventoryByUuid,
        logTransitionProbe = logTransitionProbe
    })

    local snapshot = NMClientPlaybackTick.lastInventoryByUuid or {}
    clearMap(snapshot)
    for uuid, item in pairs(currentInventoryByUuid or {}) do
        snapshot[uuid] = item
    end
    NMClientPlaybackTick.lastInventoryByUuid = snapshot
end

local function clearPlaybackLossProbeState(uuid)
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    local probe = NMClientPlaybackTick._playbackLossProbe or nil
    if type(probe) ~= "table" then
        return
    end
    if type(probe.lastSigByUuid) == "table" then
        probe.lastSigByUuid[key] = nil
    end
    if type(probe.lastLogMsByUuid) == "table" then
        probe.lastLogMsByUuid[key] = nil
    end
    if type(probe.lastSourceByUuid) == "table" then
        probe.lastSourceByUuid[key] = nil
    end
    if type(probe.lastTickByUuid) == "table" then
        probe.lastTickByUuid[key] = nil
    end
    if type(probe.lastReasonByUuid) == "table" then
        probe.lastReasonByUuid[key] = nil
    end
end

local function clearCorpseRecoveredClientState(uuid)
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    if NMPlaybackRuntime and NMPlaybackRuntime.clearRecoveredPortableRuntime then
        NMPlaybackRuntime.clearRecoveredPortableRuntime(key, "corpse_recovered_inventory_rebind")
    elseif NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
        NMPlaybackRuntime.forceStop(nil, key, "corpse_recovered_inventory_rebind")
    end
    clearFastLaneSource(key, "corpse_recovered")
    NMClientPlaybackTick.vehiclePowerTickMs[key] = nil
    NMClientPlaybackTick.ownershipConflictState[key] = nil
    NMClientPlaybackTick.detachedRemoveLogMs[key] = nil
    NMClientPlaybackTick.detachedSyncSigSeen[key] = nil
    NMClientPlaybackTick.detachedSyncHeartbeatMs[key] = nil
    NMClientPlaybackTick.modeResolutionSigSeen[key] = nil
    NMClientPlaybackTick.modeResolutionHeartbeatMs[key] = nil
    NMClientPlaybackTick.modeResolutionBootstrapMs[key] = nil
    NMClientPlaybackTick.corpseInventoryReboundSeen[key] = nil
    NMClientPlaybackTick.lastInventoryByUuid[key] = nil
    clearPlaybackLossProbeState(key)
    if NMClientWorldSourceCache and NMClientWorldSourceCache.remove then
        NMClientWorldSourceCache.remove(key)
    end
    if NMClientPortableDropHandoff and NMClientPortableDropHandoff.clear then
        NMClientPortableDropHandoff.clear(key, "corpse_recovered_inventory_rebind")
    end
    if NMClientPortableDropHandoff and NMClientPortableDropHandoff.consumePickupRebind then
        NMClientPortableDropHandoff.consumePickupRebind(key)
    end
end

local function isFastPositionCandidate(state, source)
    if not (state and source and source.mode == "world" and source.x and source.y and source.z) then
        return false
    end
    return state.isOn == true and state.isPlaying == true and state.mediaFullType ~= nil
end

getActiveRouteClass = function(uuid)
    local key = tostring(uuid or "")
    if key == "" then
        return nil
    end
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[key] or nil
    if type(active) ~= "table" then
        return nil
    end
    if active.mode == "dual" or active._lastRenderMode == "dual" or active._lastEmitterClass == "dual" then
        return "dual"
    end
    if active._centeredWorldOutput == true or active._lastEmitterClass == "world_centered" then
        return "world"
    end
    if active.isWorldEmitter == true or active._lastUseWorldOutput == true or active._lastEmitterClass == "world" then
        return "world"
    end
    if active._lastEmitterClass == "personal" or active.isWorldEmitter == false then
        return "personal"
    end
    return nil
end

local function countActiveRouteDiag(routeClass)
    local route = tostring(routeClass or "")
    if route == "personal" then
        countMemoryEvent("playback_active_route_personal", 1)
        notePlaybackDiagCounter("playback_active_route_personal", 1)
    elseif route == "world" then
        countMemoryEvent("playback_active_route_world", 1)
        notePlaybackDiagCounter("playback_active_route_world", 1)
    elseif route == "dual" then
        countMemoryEvent("playback_active_route_dual", 1)
        notePlaybackDiagCounter("playback_active_route_dual", 1)
    end
end

local function countPortableTransportDiag(profile, mode, resolvedOutput, playbackMode, routeClass)
    if not (NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        return
    end
    local output = tostring(resolvedOutput or "")
    local context = tostring(mode or "")
    local playback = tostring(playbackMode or "")
    local route = tostring(routeClass or "")
    if output == "personal" then
        countMemoryEvent("playback_portable_transport_personal", 1)
        notePlaybackDiagCounter("playback_portable_transport_personal", 1)
    elseif output == "silent" then
        countMemoryEvent("playback_portable_transport_silent", 1)
        notePlaybackDiagCounter("playback_portable_transport_silent", 1)
    elseif output == "world" then
        countMemoryEvent("playback_portable_transport_world", 1)
        notePlaybackDiagCounter("playback_portable_transport_world", 1)
    end
    if playback == "world" and route ~= "personal" then
        countMemoryEvent("playback_portable_transport_world_trackable", 1)
        notePlaybackDiagCounter("playback_portable_transport_world_trackable", 1)
    elseif playback ~= "world" or route == "personal" then
        countMemoryEvent("playback_portable_transport_no_world_fast_lane", 1)
        notePlaybackDiagCounter("playback_portable_transport_no_world_fast_lane", 1)
    end
    if context == "placed" or context == "drop_pending" then
        countMemoryEvent("playback_portable_transport_placed_or_drop", 1)
        notePlaybackDiagCounter("playback_portable_transport_placed_or_drop", 1)
    elseif context == "attached" or context == "stowed" or context == "inventory" then
        countMemoryEvent("playback_portable_transport_carried", 1)
        notePlaybackDiagCounter("playback_portable_transport_carried", 1)
    end
end

local function resolveFastSourceSchedulingHint(source, player)
    if type(source) ~= "table" then
        return nil
    end
    if source._nmFastFollowPlayer == true then
        if isPlayerFollowMovementActive(player) == true then
            countMemoryEvent("playback_follow_moving_cadence_active", 1)
            notePlaybackDiagCounter("playback_follow_moving_cadence_active", 1)
        end
        return "fast_lane"
    end
    local context = tostring(source.context or source.mode or "")
    if context == "placed" or context == "vehicle" or context == "attached" or context == "stowed" or context == "drop_pending" then
        return "fast_lane"
    end
    if source._nmFastWorldItem then
        return "fast_lane"
    end
    return "fast_lane"
end

local function rememberFastSource(uuid, profile, state, source, player, routeClass, resolvedOutput)
    local key = tostring(uuid or state and state.deviceUUID or "")
    if key == "" or isFastPositionCandidate(state, source) ~= true then
        return
    end
    if tostring(resolvedOutput or "") == "personal" then
        clearFastLaneSource(key, "personal_output")
        countMemoryEvent("playback_fast_source_personal_skipped", 1)
        notePlaybackDiagCounter("playback_fast_source_personal_skipped", 1)
        return
    end
    local route = tostring(routeClass or getActiveRouteClass(key) or "")
    local vehicleSource = isVehicleSource(source) == true
    local vehicleResolved = vehicleSource == true and isResolvedVehicleSource(source) == true or false
    if route == "personal" then
        clearFastLaneSource(key, "personal_route")
        countMemoryEvent("playback_fast_source_personal_skipped", 1)
        notePlaybackDiagCounter("playback_fast_source_personal_skipped", 1)
        return
    elseif route == "dual" then
        countMemoryEvent("playback_fast_source_dual_tracked", 1)
    elseif route == "world" then
        countMemoryEvent("playback_fast_source_world_tracked", 1)
    end
    local previous = NMClientPlaybackTick._fastSources[key]
    local currentPosition = readSourcePosition(source)
    local previousPosition = type(previous) == "table" and previous.lastPosition or nil
    local sourceMoved = didPositionChange(currentPosition, previousPosition) == true
    local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or 0
    local fastCadence = math.max(1, tonumber(NMClientPlaybackTick.fastPositionCadenceTicks) or 3)
    local movingFollowCadence = math.max(fastCadence, tonumber(NMClientPlaybackTick.movingFollowFastPositionCadenceTicks) or 6)
    local sourceMovedCadence = type(source) == "table" and source._nmFastFollowPlayer == true and movingFollowCadence or fastCadence
    if type(previous) == "table" and previousPosition ~= nil and sourceMoved == true then
        countMemoryEvent("playback_fast_position_stationary_reset", 1)
    end
    NMClientPlaybackTick._fastSources[key] = {
        profile = profile,
        state = state,
        source = source,
        routeClass = route ~= "" and route or nil,
        isVehicleSource = vehicleSource,
        vehicleResolved = vehicleResolved,
        vehicleSourceGeneration = vehicleSource == true and (tonumber(source.sourceGeneration) or tonumber(state and state.sourceGeneration) or 0) or nil,
        schedulingHint = resolveFastSourceSchedulingHint(source, player),
        lastPosition = sourceMoved == true and currentPosition or previousPosition or currentPosition,
        stationaryStreak = sourceMoved == true and 0 or (type(previous) == "table" and (tonumber(previous.stationaryStreak) or 0) or 0),
        nextFastCheckTick = sourceMoved == true
            and (currentTick + sourceMovedCadence)
            or (type(previous) == "table"
            and tonumber(previous.nextFastCheckTick)
            or (currentTick + fastCadence))
    }
    countMemoryEvent("playback_fast_lane_source_remembered", 1)
    notePlaybackDiagCounter("playback_fast_lane_source_remembered", 1)
    if vehicleSource == true then
        countPlaybackDiag("playback_vehicle_fast_source_remembered", 1)
        if vehicleResolved ~= true then
            countPlaybackDiag("playback_vehicle_monitor_blocked_unresolved", 1)
        end
    end
end

local function addFastPositionZombiePulseCandidate(pulseCandidates, key, cached, source)
    if not (source and source.mode == "world" and source.x and source.y and source.z) then
        return pulseCandidates, 0
    end
    local candidates = pulseCandidates or {}
    candidates[key] = {
        profile = cached.profile,
        state = cached.state,
        source = source
    }
    countMemoryEvent("playback_fast_position_zombie_pulse_candidate", 1)
    notePlaybackDiagCounter("playback_fast_position_zombie_pulse_candidate", 1)
    return candidates, 1
end

local function emitFastPositionZombiePulses(player, pulseCandidates, pulseCandidateCount)
    if (tonumber(pulseCandidateCount) or 0) <= 0 then
        return
    end
    if not (NMClientSPLocalRuntime and NMClientSPLocalRuntime.emitZombiePulses) then
        return
    end
    countMemoryEvent("playback_fast_position_zombie_pulse_pass", 1)
    notePlaybackDiagCounter("playback_fast_position_zombie_pulse_pass", 1)
    NMClientSPLocalRuntime.emitZombiePulses(player, pulseCandidates, {
        zombieAttractionPulseState = NMClientPlaybackTick.zombieAttractionPulseState,
        nowMs = nowRealMs,
        memoryDiagPrefix = "zombie_attraction_fast_position",
        countMemoryEvent = countMemoryEvent,
        noteDiagCounter = notePlaybackDiagCounter
    })
end

local function refreshFastSource(player, cached)
    if not cached then
        return nil
    end
    local state = cached.state
    local source = cached.source
    if not isFastPositionCandidate(state, source) then
        return nil
    end

    if source._nmFastFollowPlayer == true and player then
        source.x = player.getX and player:getX() or source.x
        source.y = player.getY and player:getY() or source.y
        source.z = player.getZ and player:getZ() or source.z
        cached.schedulingHint = resolveFastSourceSchedulingHint(source, player)
        return source
    end

    local uuid = tostring(state and state.deviceUUID or "")
    local liveEntry = uuid ~= "" and NMClientWorldSourceCache and NMClientWorldSourceCache.get and NMClientWorldSourceCache.get(uuid) or nil
    if liveEntry and liveEntry.source and liveEntry.source.x and liveEntry.source.y and liveEntry.source.z then
        cached.state = liveEntry.stateSnapshot or state
        cached.source = liveEntry.source
        cached.isVehicleSource = isVehicleSource(cached.source) == true
        cached.vehicleResolved = cached.isVehicleSource == true and isResolvedVehicleSource(cached.source) == true or false
        cached.vehicleSourceGeneration = cached.isVehicleSource == true and (tonumber(liveEntry.sourceGeneration) or tonumber(cached.source.sourceGeneration) or tonumber(cached.state and cached.state.sourceGeneration) or 0) or nil
        return cached.source
    elseif source._nmFastWorldItem and source._nmFastWorldItem.getWorldItem then
        local w = source._nmFastWorldItem:getWorldItem()
        local s = w and w.getSquare and w:getSquare() or nil
        if s then
            source.x = s:getX() + 0.5
            source.y = s:getY() + 0.5
            source.z = s:getZ()
        end
    end
    return source
end

local function runFastPositionPass(player, laneMode)
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return { updated = 0, pulseCandidates = nil, pulseCandidateCount = 0 }
    end

    local updated = 0
    local pulseCandidates = nil
    local pulseCandidateCount = 0
    for uuid, _ in pairs(active) do
        local key = tostring(uuid)
        local cached = NMClientPlaybackTick._fastSources[key]
        local hint = tostring(cached and cached.schedulingHint or "")
        local shouldRunCached = (laneMode == "fast_lane" and hint == "fast_lane")
            or (laneMode == nil and hint ~= "")
        if shouldRunCached ~= true or isFastSourceDue(cached) ~= true then
            cached = nil
        end
        local source = refreshFastSource(player, cached)
        if cached and source == nil then
            clearFastLaneSource(key, "source_invalid")
        end
        if cached and source and NMPlaybackRuntime.updateActiveEmitterPositionOnly then
            observeFastSourcePosition(cached, source)
            if NMPlaybackRuntime.updateActiveEmitterPositionOnly(player, uuid, cached.state, source) == true then
                updated = updated + 1
                if cached.isVehicleSource == true then
                    countPlaybackDiag("playback_vehicle_fast_position_updated", 1)
                end
                local added
                pulseCandidates, added = addFastPositionZombiePulseCandidate(pulseCandidates, key, cached, source)
                pulseCandidateCount = pulseCandidateCount + added
            else
                if cached.isVehicleSource == true then
                    countPlaybackDiag("playback_vehicle_fast_position_failed", 1)
                end
                clearFastLaneSource(key, "position_update_failed")
            end
        end
    end
    return {
        updated = updated,
        pulseCandidates = pulseCandidates,
        pulseCandidateCount = pulseCandidateCount
    }
end

local function runActiveTrackMonitorPass(player)
    if canReplaceFullWithTrackMonitor(player) ~= true then
        return false, "cache_miss_full"
    end
    local active = NMPlaybackRuntime and NMPlaybackRuntime.Active or nil
    if type(active) ~= "table" then
        return false, "cache_miss_full"
    end
    local ran = false
    local tokenConfirmed = false
    for uuid, activeEntry in pairs(active) do
        local key = tostring(uuid or "")
        local context = NMClientPlaybackTick._trackMonitorContexts[key]
        if type(context) ~= "table" then
            countMemoryEvent("playback_track_monitor_cache_miss_full", 1)
            notePlaybackDiagCounter("playback_track_monitor_cache_miss_full", 1)
            return false, "cache_miss_full"
        end
        local profile = context.profile
        local state = context.state
        local source = context.source
        local sourceContext = tostring(source and (source.context or source.mode) or context.sourceKind or "unknown")
        if not (NMPlaybackRuntimeCommon and NMPlaybackRuntimeCommon.updateTrackEndState)
            or not (NMPlaybackRuntime and NMPlaybackRuntime.TrackEndPending and NMPlaybackRuntime.TrackEnded and NMPlaybackRuntime.TrackEndAwaitingAdvance) then
            countMemoryEvent("playback_track_monitor_cache_miss_full", 1)
            notePlaybackDiagCounter("playback_track_monitor_cache_miss_full", 1)
            return false, "cache_miss_full"
        end
        ran = true
        if NMPlaybackRuntime.TrackEnded[key] ~= nil then
            tokenConfirmed = true
            countMemoryEvent("playback_track_end_existing_token_dispatch", 1)
            notePlaybackDiagCounter("playback_track_end_existing_token_dispatch", 1)
            if NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
                NMPlaybackRuntime.forceStop(player, key, "track_end_existing_token")
            end
            if consumeAndDispatchTrackFinished then
                consumeAndDispatchTrackFinished(
                    player,
                    profile,
                    state,
                    context.entry,
                    context.item,
                    context.sourceKind,
                    key
                )
            end
            break
        end
        if NMPlaybackRuntimeCommon.updateTrackEndState(
            NMPlaybackRuntime.TrackEndPending,
            NMPlaybackRuntime.TrackEnded,
            NMPlaybackRuntime.TrackEndAwaitingAdvance,
            key,
            state,
            activeEntry,
            profile,
            sourceContext,
            source) == true then
            tokenConfirmed = true
            countMemoryEvent("playback_track_monitor_token_confirmed", 1)
            notePlaybackDiagCounter("playback_track_monitor_token_confirmed", 1)
            if NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
                NMPlaybackRuntime.forceStop(player, key, "track_end")
            end
            if consumeAndDispatchTrackFinished then
                consumeAndDispatchTrackFinished(
                    player,
                    profile,
                    state,
                    context.entry,
                    context.item,
                    context.sourceKind,
                    key
                )
            end
            break
        end
    end
    if ran == true then
        local currentTick = tonumber(NMClientPlaybackTick.schedulerTick) or tonumber(NMClientPlaybackTick.tick) or 0
        NMClientPlaybackTick._lastFullTick = tonumber(NMClientPlaybackTick.tick) or 0
        NMClientPlaybackTick._lastFullSchedulerTick = currentTick
        countMemoryEvent("playback_track_monitor_run", 1)
        countMemoryEvent("playback_full_replaced_by_track_monitor", 1)
        notePlaybackDiagCounter("playback_track_monitor_run", 1)
        notePlaybackDiagCounter("playback_full_replaced_by_track_monitor", 1)
        for uuid, context in pairs(NMClientPlaybackTick._trackMonitorContexts or {}) do
            if type(context) == "table" and context.sourceKind == "vehicle" then
                countPlaybackDiag("playback_vehicle_full_replaced_by_monitor", 1)
                break
            end
        end
        if tokenConfirmed == true then
            NMClientPlaybackTick.requestFullPass("track_monitor_token_confirmed")
        end
        clearPlaybackWorkStatusCache()
        return true, tokenConfirmed and "token_confirmed" or "monitored"
    end
    countMemoryEvent("playback_track_monitor_cache_miss_full", 1)
    notePlaybackDiagCounter("playback_track_monitor_cache_miss_full", 1)
    return false, "cache_miss_full"
end

function NMClientPlaybackTick.onTick(player, tickStep, passMode)
    NMClientPlaybackTick._lastPassKind = "none"
    if not player or not player.getInventory then
        return
    end

    NMClientPlaybackTick.tick = (tonumber(NMClientPlaybackTick.tick) or 0) + math.max(1, tonumber(tickStep) or 1)
    countMemoryEvent("playback_active_runtime_entries", countActivePlaybackRuntimeEntries())
    local tickStartedMs = nowRealMs()
    local mode = tostring(passMode or "auto")
    local forcedBeforePass = hasForcedFullPassPending() == true
    local forcedReasonBeforePass = tostring(NMClientPlaybackTick._forceFullReason or "")
    local dirtyBeforePass = NMClientPlaybackTick._playbackDirty == true
    local bootstrapBeforePass = isBootstrapActive() == true
    local activeBeforePass = hasActivePlaybackRuntime() == true
    local activeSnapshotBeforePass = snapshotActiveRuntimeSignatures()
    local forceFullConsumed = false
    local shouldRunFullPass = false
    local fastLaneMode = nil
    if mode == "full" then
        forceFullConsumed = consumeForcedFullPass()
        shouldRunFullPass = true
    elseif mode == "track_monitor" then
        local monitored = runActiveTrackMonitorPass(player)
        if monitored == true then
            NMClientPlaybackTick._lastPassKind = "track_monitor"
            observeMemoryDuration("playback_track_monitor_tick_ms", math.max(0, nowRealMs() - tickStartedMs))
            return
        end
        forceFullConsumed = consumeForcedFullPass()
        shouldRunFullPass = true
    elseif mode == "position_fast_lane" then
        fastLaneMode = "fast_lane"
    elseif isFullPlaybackPassDue() == true then
        forceFullConsumed = consumeForcedFullPass()
        shouldRunFullPass = true
    end
    if shouldRunFullPass ~= true then
        NMClientPlaybackTick._lastPassKind = "fast_position"
        local fastResult = runFastPositionPass(player, fastLaneMode)
        local updated = tonumber(fastResult and fastResult.updated) or 0
        emitFastPositionZombiePulses(player, fastResult and fastResult.pulseCandidates, fastResult and fastResult.pulseCandidateCount)
        NMClientPlaybackTick._lastFastPositionSchedulerTick = tonumber(NMClientPlaybackTick.schedulerTick) or tonumber(NMClientPlaybackTick.tick) or 0
        countMemoryEvent("playback_fast_position_count", 1)
        countMemoryEvent("playback_fast_position_updates", updated)
        observeMemoryDuration("playback_fast_position_tick_ms", math.max(0, nowRealMs() - tickStartedMs))
        clearPlaybackWorkStatusCache()
        return
    end

    NMClientPlaybackTick._lastPassKind = "full"
    countPlaybackFullDiag("playback_full_active_entries_before", activeSnapshotBeforePass.count)
    if bootstrapBeforePass == true then
        countPlaybackFullDiag("playback_full_reason_bootstrap", 1)
    end
    if forcedBeforePass == true or dirtyBeforePass == true then
        countPlaybackFullDiag("playback_full_reason_forced_dirty", 1)
    end
    if activeBeforePass == true and forcedBeforePass ~= true and dirtyBeforePass ~= true and bootstrapBeforePass ~= true then
        countPlaybackFullDiag("playback_full_reason_active_cadence", 1)
        countPlaybackFullDiag("playback_full_reason_track_watch", 1)
    end
    if forcedBeforePass == true and string.find(forcedReasonBeforePass, "inventory", 1, true) then
        countPlaybackFullDiag("playback_full_reason_managed_inventory", 1)
    end
    if activeBeforePass ~= true
        and forcedBeforePass ~= true
        and dirtyBeforePass ~= true
        and bootstrapBeforePass ~= true
        and NMClientPlaybackTick._hasManagedInventoryDevices ~= true then
        countPlaybackFullDiag("playback_full_reason_source_route_state_uncertain", 1)
    end
    NMClientPlaybackTick._lastFullTick = tonumber(NMClientPlaybackTick.tick) or 0
    NMClientPlaybackTick._lastFullSchedulerTick = tonumber(NMClientPlaybackTick.schedulerTick) or tonumber(NMClientPlaybackTick.tick) or 0
    anchorFastLaneAfterFullPass(NMClientPlaybackTick._lastFullSchedulerTick)
    clearPlaybackWorkStatusCache()
    if forceFullConsumed == true then
        NMClientPlaybackTick._forceFullReason = nil
    end
    clearFastLaneSources("full_rebuild")
    clearTrackMonitorContexts("full_rebuild")

    if NMClientVanillaMusicSuppressor and NMClientVanillaMusicSuppressor.beginTick then
        NMClientVanillaMusicSuppressor.beginTick()
    end

    local tickCount = getGameTime and getGameTime():getWorldAgeHours() or 0
    local scratch = NMClientPlaybackTick._scratch
    local valid = clearMap(scratch.valid)
    local inventoryOwners = clearMap(scratch.inventoryOwners)
    local currentInventoryByUuid = clearMap(scratch.currentInventoryByUuid)
    local spPulseCandidates = clearMap(scratch.spPulseCandidates)

    local inventory = clearArray(scratch.inventory)
    local inventoryCollectStartedMs = nowRealMs()
    NMClientPlaybackInventoryCollector.collectManaged(player, inventory)
    NMClientPlaybackTick._hasManagedInventoryDevices = #inventory > 0
    if activeBeforePass ~= true and #inventory > 0 then
        countPlaybackFullDiag("playback_full_reason_managed_inventory", 1)
    end
    local inventoryCollectElapsedMs = math.max(0, nowRealMs() - inventoryCollectStartedMs)
    observeMemoryDuration("inventory_collect_ms", inventoryCollectElapsedMs)
    local inventorySyncCount = 0
    local detachedSyncCount = 0
    local stableOffInventorySkipCount = 0
    local stableOffInventorySyncCount = 0
    local stableOffActiveCleanupSyncCount = 0

    for i = 1, #inventory do
        local e = inventory[i]
        NMClientPlaybackInventoryCollector.normalizeCorpseRecoveredInventoryState(e.item, e.profile, e.state, e.uuid, {
            corpseInventoryReboundSeen = NMClientPlaybackTick.corpseInventoryReboundSeen,
            cleanupRuntime = clearCorpseRecoveredClientState,
            logRuntime = function(tag, detail)
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                    NMCore.logChannel("runtime", tag, detail)
                end
            end
        })
        local mode = NMClientModeReconcile.resolveModeForItem(player, e.item, e.profile, e.state)
        local resolvedOutputForMode = NMDeviceProfiles.resolveOutputMode(e.profile, e.state, mode, false)
        local modeChanged = NMClientModeReconcile.applyResolvedMode(e.uuid, e.state, mode)
        if modeChanged == true
            and mode == "attached"
            and NMDeviceProfiles.isPortableTrackedProfile
            and NMDeviceProfiles.isPortableTrackedProfile(e.profile) == true
            and NMDeviceUI
            and NMDeviceUI.canAutoOpenForAttachedTransition
            and NMDeviceUI.canAutoOpenForAttachedTransition(player:getPlayerNum(), e.item) == true
            and NMDeviceUI.openForItemIfNeeded then
            local openedWindow = NMDeviceUI.openForItemIfNeeded(player:getPlayerNum(), e.item) ~= nil
            logTransitionProbe(
                "portable_ui_auto_open",
                string.format(
                    "uuid=%s mode=%s opened=%s item=%s",
                    tostring(e.uuid),
                    tostring(mode),
                    tostring(openedWindow),
                    tostring(e.item and e.item.getFullType and e.item:getFullType() or "unknown")
                )
            )
        end
        local modeSignature = table.concat({
            tostring(mode),
            tostring(modeChanged == true),
            tostring(e.state and e.state.isOn == true),
            tostring(e.state and e.state.isPlaying == true),
            tostring(e.state and e.state.mediaFullType or "nil")
        }, "|")
        local shouldLogMode = shouldLogModeResolution(e.uuid, modeSignature, modeChanged == true)
        if shouldLogMode then
            local worldItem = e.item and e.item.getWorldItem and e.item:getWorldItem() or nil
            local stateActive = e.state and (e.state.isOn == true or e.state.isPlaying == true)
            local interestingMode = mode == "attached" or mode == "placed" or mode == "drop_pending" or mode == "pickup_pending" or mode == "vehicle"
            if not (interestingMode or stateActive or worldItem ~= nil) then
                shouldLogMode = false
            end
        end
        if shouldLogMode then
            local worldItem = e.item and e.item.getWorldItem and e.item:getWorldItem() or nil
            logTransitionProbe(
                "mode_resolution",
                string.format(
                    "uuid=%s mode=%s changed=%s worldItem=%s isOn=%s isPlaying=%s media=%s",
                    tostring(e.uuid),
                    tostring(mode),
                    tostring(modeChanged == true),
                    tostring(worldItem ~= nil),
                    tostring(e.state and e.state.isOn == true),
                    tostring(e.state and e.state.isPlaying == true),
                    tostring(e.state and e.state.mediaFullType or "nil")
                )
            )
        end

        if NMClientModeSync and NMClientModeSync.emit then
            NMClientModeSync.emit(player, e.item, e.profile, e.state, mode)
        end

        valid[e.uuid] = true
        inventoryOwners[e.uuid] = true
        currentInventoryByUuid[e.uuid] = e.item

        local stableOffSig = buildStableOffInventorySignature(e.item, e.profile, e.state, mode, resolvedOutputForMode)
        local activeRuntimeEntry = NMPlaybackRuntime
            and NMPlaybackRuntime.Active
            and NMPlaybackRuntime.Active[tostring(e.uuid or "")]
            or nil
        local truthSignature, truthParts = buildManagedInventoryTruthSignature(e.item, e.profile, e.state, mode, resolvedOutputForMode)
        local truthResult = observeManagedInventoryTruthSignature(e.uuid, truthSignature, truthParts, activeRuntimeEntry)
        local fastSkip = shouldFastSkipManagedInventorySync(truthResult, mode, e.state, {
            activeBeforePass = activeBeforePass,
            bootstrapBeforePass = bootstrapBeforePass,
            dirtyBeforePass = dirtyBeforePass,
            forcedBeforePass = forcedBeforePass,
            forceFullConsumed = forceFullConsumed,
            mpClient = isMPClientRuntime() == true,
            resolvedOutput = resolvedOutputForMode,
        })
        if fastSkip == true then
            if stableOffSig ~= nil then
                NMClientPlaybackTick.stableOffInventorySigSeen[e.uuid] = stableOffSig
            end
        elseif stableOffSig ~= nil
            and tostring(NMClientPlaybackTick.stableOffInventorySigSeen[e.uuid] or "") == stableOffSig
            and activeRuntimeEntry == nil then
            stableOffInventorySkipCount = stableOffInventorySkipCount + 1
            countMemoryEvent("playback_stable_off_skip_active_absent", 1)
        else
            if stableOffSig == nil then
                NMClientPlaybackTick.stableOffInventorySigSeen[e.uuid] = nil
            else
                stableOffInventorySyncCount = stableOffInventorySyncCount + 1
                if activeRuntimeEntry ~= nil then
                    stableOffActiveCleanupSyncCount = stableOffActiveCleanupSyncCount + 1
                    countMemoryEvent("playback_stable_off_cleanup_sync_active_present", 1)
                end
            end

            local source = nil
            local trackedPortable = NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(e.profile)
            if mode == "attached" or mode == "stowed" or mode == "drop_pending" or mode == "pickup_pending" then
                if mode == "pickup_pending"
                    and NMClientPortableDropHandoff
                    and NMClientPortableDropHandoff.buildPickupSource then
                    source = NMClientPortableDropHandoff.buildPickupSource(player, e.uuid)
                end
                if not source then
                    source = {
                        mode = "world",
                        context = mode,
                        x = player.getX and player:getX() or 0,
                        y = player.getY and player:getY() or 0,
                        z = player.getZ and player:getZ() or 0,
                        _nmFastFollowPlayer = true
                    }
                end
                e.state.playbackMode = ((resolvedOutputForMode == "world" or resolvedOutputForMode == "silent")
                    or (trackedPortable and resolvedOutputForMode ~= "personal")) and "world" or "inventory"
            elseif mode == "placed" then
                local w = e.item.getWorldItem and e.item:getWorldItem() or nil
                local s = w and w.getSquare and w:getSquare() or nil
                if s then
                    source = {
                        mode = "world",
                        context = "placed",
                        x = s:getX() + 0.5,
                        y = s:getY() + 0.5,
                        z = s:getZ(),
                        _nmFastWorldItem = e.item
                    }
                    e.state.playbackMode = ((resolvedOutputForMode == "world" or resolvedOutputForMode == "silent")
                        or (trackedPortable and resolvedOutputForMode ~= "personal")) and "world" or "inventory"
                end
            else
                source = { mode = "inventory", context = "inventory" }
                e.state.playbackMode = "inventory"
            end

            rememberPlaybackLossSource(e.uuid, e.state, source, {
                mode = mode,
                resolvedOutput = resolvedOutputForMode
            })
            emitPlaybackLossProbe(player, e.uuid, true, "inventory_sync", {
                source = source,
                mode = mode,
                playbackMode = e.state.playbackMode,
                resolvedOutput = resolvedOutputForMode,
                isOn = e.state.isOn == true,
                isPlaying = e.state.isPlaying == true,
                media = e.state.mediaFullType
            })

            local syncStartedMs = nowRealMs()
            NMPlaybackRuntime.syncDevice(player, e.profile, e.state, source, tickCount * 60)
            local routeClass = getActiveRouteClass(e.uuid)
            countActiveRouteDiag(routeClass)
            countPortableTransportDiag(e.profile, mode, resolvedOutputForMode, e.state and e.state.playbackMode, routeClass)
            if NMClientVanillaMusicSuppressor and NMClientVanillaMusicSuppressor.observeAudibility then
                NMClientVanillaMusicSuppressor.observeAudibility(player, e.profile, e.state, source)
            end
            observeMemoryDuration("sync_device_ms", math.max(0, nowRealMs() - syncStartedMs))
            inventorySyncCount = inventorySyncCount + 1
            if stableOffSig ~= nil then
                NMClientPlaybackTick.stableOffInventorySigSeen[e.uuid] = stableOffSig
            end
            rememberFastSource(e.uuid, e.profile, e.state, source, player, routeClass, resolvedOutputForMode)
            if activeBeforePass == true then
                if routeClass == "personal" then
                    countMemoryEvent("playback_full_active_personal", 1)
                elseif routeClass == "world" or routeClass == "dual" then
                    countMemoryEvent("playback_full_active_world", 1)
                end
            end
            local sourceKind = isVehicleSource(source) == true
                and "vehicle"
                or ((source and source.mode == "world") and "world_item" or "inventory")
            rememberTrackMonitorContext(e.uuid, e.profile, e.state, source, sourceKind, e.item, nil)
            consumeAndDispatchTrackFinished(player, e.profile, e.state, nil, e.item, sourceKind, e.uuid)
            if source and source.mode == "world" and source.x and source.y and source.z then
                spPulseCandidates[e.uuid] = {
                    profile = e.profile,
                    state = e.state,
                    source = source
                }
            end
        end
    end

    reconcileDroppedInventoryToPlacedSP(player, currentInventoryByUuid)
    if NMDeviceUI and NMDeviceUI.endSessionStartAutoOpenSuppression then
        NMDeviceUI.endSessionStartAutoOpenSuppression(player:getPlayerNum(), "first_inventory_reconciliation_complete")
    end

    local detachedResult = NMClientDetachedPlaybackPass.run(player, {
        valid = valid,
        inventoryOwners = inventoryOwners,
        currentInventoryByUuid = currentInventoryByUuid,
        spPulseCandidates = spPulseCandidates,
        tickCount = tickCount,
        nowRealMs = nowRealMs,
        observeMemoryDuration = observeMemoryDuration,
        consumeAndDispatchTrackFinished = consumeAndDispatchTrackFinished,
        shouldLogDetachedSync = shouldLogDetachedSync,
        applySPLocalVehiclePowerGuard = applySPLocalVehiclePowerGuard,
        resolveVehicleCanonicalGeneration = resolveVehicleCanonicalGeneration,
        persistVehicleCanonicalGeneration = persistVehicleCanonicalGeneration,
        setVehicleIdentityState = setVehicleIdentityState,
        detachedOrchestration = detachedOrchestration,
        continuity = continuity,
        ownershipConflictState = NMClientPlaybackTick.ownershipConflictState,
        detachedRemoveLogMs = NMClientPlaybackTick.detachedRemoveLogMs,
        rememberFastSource = rememberFastSource,
        rememberTrackMonitorContext = rememberTrackMonitorContext,
        rememberPlaybackLossSource = rememberPlaybackLossSource,
        emitPlaybackLossProbe = emitPlaybackLossProbe,
        detachedOut = clearArray(scratch.detached),
        pendingPlaybackOut = clearArray(scratch.pendingPlayback),
        logTransitionProbe = logTransitionProbe,
        logRuntime = function(tag, detail)
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                NMCore.logChannel("runtime", tag, detail)
            end
        end,
        logVehicleRuntime = function(tag, detail)
            local channel = nil
            if NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace") then
                channel = "vehicle_trace"
            elseif NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle") then
                channel = "vehicle"
            end
            if channel and NMCore and NMCore.logChannel then
                NMCore.logChannel(channel, tag, detail)
            end
        end
    })
    if NMClientPlaybackTick._vehicleSeatProbe and NMClientPlaybackTick._vehicleSeatProbe.pending == true then
        local snapshot = NMClientPlaybackTick.getVehicleTransitionSnapshot(player)
        vehicleTraceProbeLog("vehicle_seat_reconciled", formatVehicleTransitionSnapshot("full_pass_reconciled", snapshot))
        NMClientPlaybackTick._vehicleSeatProbe.pending = false
        NMClientPlaybackTick._vehicleSeatProbe.pendingReason = nil
        NMClientPlaybackTick._vehicleSeatProbe.pendingEvent = nil
        NMClientPlaybackTick._vehicleSeatProbe.pendingAtMs = 0
        NMClientPlaybackTick._vehicleSeatProbe.pendingSchedulerTick = 0
        NMClientPlaybackTick._vehicleSeatProbe.lastSignature = snapshot and snapshot.signature or NMClientPlaybackTick._vehicleSeatProbe.lastSignature
    end
    NMClientPlaybackTick._playbackDirty = false
    if NMClientPlaybackTick._hasManagedInventoryDevices ~= true
        and not hasActivePlaybackRuntime()
        and not (detachedResult and tonumber(detachedResult.detachedSyncCount) or 0 > 0) then
        NMClientPlaybackTick._startupBootstrapUntilTick = math.min(
            tonumber(NMClientPlaybackTick._startupBootstrapUntilTick) or 0,
            tonumber(NMClientPlaybackTick.schedulerTick) or 0
        )
    end
    local detached = detachedResult.detached or {}
    detachedSyncCount = detachedSyncCount + (tonumber(detachedResult.detachedSyncCount) or 0)

    NMClientSPLocalRuntime.emitZombiePulses(player, spPulseCandidates, {
        zombieAttractionPulseState = NMClientPlaybackTick.zombieAttractionPulseState,
        nowMs = nowRealMs
    })

    if NMClientModeSync and NMClientModeSync.prune then
        NMClientModeSync.prune(valid)
    end
    for ownedUuid, _ in pairs(NMClientPlaybackTick.ownershipConflictState or {}) do
        if not valid[ownedUuid] then
            NMClientPlaybackTick.ownershipConflictState[ownedUuid] = nil
        end
    end
    pruneStableOffInventorySignatures(valid)
    pruneManagedInventoryTruthSignatures(valid)
    NMClientModeReconcile.pruneAuthority(valid)
    if NMPlaybackRuntime and type(NMPlaybackRuntime.Active) == "table" then
        for activeUuid, _ in pairs(NMPlaybackRuntime.Active) do
            emitPlaybackLossProbe(player, activeUuid, valid[activeUuid] == true, valid[activeUuid] == true and "full_pass_valid" or "full_pass_missing_candidate")
        end
    end
    local stopMissingStartedMs = nowRealMs()
    NMPlaybackRuntime.stopMissing(player, valid, NMClientPlaybackTick.tick)
    local stopMissingElapsedMs = math.max(0, nowRealMs() - stopMissingStartedMs)
    observeMemoryDuration("stop_missing_ms", stopMissingElapsedMs)

    countMemoryEvent("inventory_sync_count", inventorySyncCount)
    countMemoryEvent("detached_sync_count", detachedSyncCount)
    countPlaybackFullDiag("playback_full_synced_devices", inventorySyncCount + detachedSyncCount)
    countMemoryEvent("playback_inventory_stable_off_skip", stableOffInventorySkipCount)
    countMemoryEvent("playback_inventory_stable_off_sync", stableOffInventorySyncCount)
    if stableOffActiveCleanupSyncCount > 0 then
        countPlaybackFullDiag("playback_full_reason_runtime_cleanup", stableOffActiveCleanupSyncCount)
        countPlaybackFullDiag("playback_full_runtime_cleanup", stableOffActiveCleanupSyncCount)
    end
    local activeSnapshotAfterPass = snapshotActiveRuntimeSignatures()
    local stateChanged, sourceChanged, routeChanged = countActiveRuntimeSignatureChanges(activeSnapshotBeforePass, activeSnapshotAfterPass)
    countPlaybackFullDiag("playback_full_active_entries_after", activeSnapshotAfterPass.count)
    if activeSnapshotAfterPass.count < activeSnapshotBeforePass.count then
        countPlaybackFullDiag("playback_full_runtime_cleanup", activeSnapshotBeforePass.count - activeSnapshotAfterPass.count)
    end
    if stateChanged > 0 then
        countPlaybackFullDiag("playback_full_changed_state", stateChanged)
    end
    if sourceChanged > 0 then
        countPlaybackFullDiag("playback_full_changed_source", sourceChanged)
    end
    if routeChanged > 0 then
        countPlaybackFullDiag("playback_full_changed_route", routeChanged)
    end
    if activeBeforePass == true
        and activeSnapshotBeforePass.count == activeSnapshotAfterPass.count
        and stateChanged <= 0
        and sourceChanged <= 0
        and routeChanged <= 0
        and stableOffActiveCleanupSyncCount <= 0 then
        countPlaybackFullDiag("playback_full_no_change", 1)
    end
    if NMClientVanillaMusicSuppressor and NMClientVanillaMusicSuppressor.endTick then
        NMClientVanillaMusicSuppressor.endTick(NMClientPlaybackTick.tick)
    end
    observeMemoryDuration("tick_ms", math.max(0, nowRealMs() - tickStartedMs))
    if NMPlaybackRuntimeDiagnostics and NMPlaybackRuntimeDiagnostics.sampleMemoryProbe then
        NMPlaybackRuntimeDiagnostics.sampleMemoryProbe(NMPlaybackRuntime, {
            nowMs = nowRealMs(),
            inventoryDevices = #inventory,
            detachedSources = #detached,
            playbackActive = (inventorySyncCount + detachedSyncCount) > 0
        })
    end
end

