-- Diagnostics helpers for vehicle emitter jump telemetry.
NMPlaybackRuntimeDiagnostics = NMPlaybackRuntimeDiagnostics or {}

function NMPlaybackRuntimeDiagnostics.ensure(runtimeTable)
    runtimeTable.Diagnostics = runtimeTable.Diagnostics or {
        vehicleJumps = {},
        vehicleRebindHints = 0,
        vehicleJumpWarnings = 0,
        memoryProbe = {
            startedAtMs = 0,
            lastFlushMs = 0,
            lastHeapKb = nil,
            lastSnapshot = nil,
            announcedReady = false,
            lastPlaybackActive = false,
            peaks = {},
            counters = {},
            durations = {}
        }
    }
    runtimeTable._lifecycleProbeSig = runtimeTable._lifecycleProbeSig or {}
    runtimeTable._lifecycleProbeMs = runtimeTable._lifecycleProbeMs or {}
    local probe = runtimeTable.Diagnostics.memoryProbe
    if type(probe) == "table" and (tonumber(probe.startedAtMs) or 0) <= 0 then
        probe.startedAtMs = (getTimestampMs and tonumber(getTimestampMs()))
            or (getTimestamp and (tonumber(getTimestamp()) or 0) * 1000)
            or 0
    end
end

local function nowMs()
    if getTimestampMs then
        return tonumber(getTimestampMs()) or 0
    end
    if getTimestamp then
        return (tonumber(getTimestamp()) or 0) * 1000
    end
    return 0
end

local function countTableEntries(tbl)
    local count = 0
    if type(tbl) ~= "table" then
        return 0
    end
    for _, _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function countActiveEmitters(activeTable)
    local count = 0
    if type(activeTable) ~= "table" then
        return 0
    end
    for _, active in pairs(activeTable) do
        if type(active) == "table" then
            if active.mode == "dual" then
                if active.world and active.world.alive ~= false then
                    count = count + 1
                end
                if active.personal and active.personal.alive ~= false then
                    count = count + 1
                end
            else
                count = count + 1
            end
        end
    end
    return count
end

local function ensureCounterStore(probe)
    probe.counters = probe.counters or {}
    return probe.counters
end

local function ensureDurationStore(probe)
    probe.durations = probe.durations or {}
    return probe.durations
end

local function ensureDurationMetric(probe, key)
    local durations = ensureDurationStore(probe)
    durations[key] = durations[key] or { count = 0, sumMs = 0.0, maxMs = 0.0 }
    return durations[key]
end

local function getCounter(probe, key)
    local counters = ensureCounterStore(probe)
    return tonumber(counters[key]) or 0
end

local function getDurationSnapshot(probe, key)
    local slot = ensureDurationStore(probe)[key] or { count = 0, sumMs = 0.0, maxMs = 0.0 }
    local count = tonumber(slot.count) or 0
    local sumMs = tonumber(slot.sumMs) or 0.0
    return {
        count = count,
        avgMs = count > 0 and (sumMs / count) or 0.0,
        maxMs = tonumber(slot.maxMs) or 0.0
    }
end

local function resetWindow(probe)
    probe.counters = {}
    probe.durations = {}
end

local function memoryProbeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true
end

local function updatePeak(peaks, key, value)
    local current = tonumber(peaks[key]) or 0
    local nextValue = tonumber(value) or 0
    if nextValue > current then
        peaks[key] = nextValue
    end
    return current, tonumber(peaks[key]) or current
end

function NMPlaybackRuntimeDiagnostics.countEvent(runtimeTable, key, delta)
    if not memoryProbeEnabled() then
        return
    end
    local probe = runtimeTable and runtimeTable.Diagnostics and runtimeTable.Diagnostics.memoryProbe or nil
    if type(probe) ~= "table" then
        return
    end
    local counters = ensureCounterStore(probe)
    local token = tostring(key or "unknown")
    counters[token] = (tonumber(counters[token]) or 0) + (tonumber(delta) or 1)
end

function NMPlaybackRuntimeDiagnostics.observeDuration(runtimeTable, key, elapsedMs)
    if not memoryProbeEnabled() then
        return
    end
    local probe = runtimeTable and runtimeTable.Diagnostics and runtimeTable.Diagnostics.memoryProbe or nil
    if type(probe) ~= "table" then
        return
    end
    local metric = ensureDurationMetric(probe, tostring(key or "unknown"))
    local elapsed = math.max(0, tonumber(elapsedMs) or 0)
    metric.count = metric.count + 1
    metric.sumMs = metric.sumMs + elapsed
    if elapsed > metric.maxMs then
        metric.maxMs = elapsed
    end
end

function NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return "memory_probe_snapshot unavailable=true"
    end
    return string.format(
        "lua_mb=%.2f heap_delta_kb=%d tick_ms_avg=%.2f tick_ms_max=%.2f sync_ms_avg=%.2f sync_ms_max=%.2f inventory_devices=%d detached_sources=%d active_emitters=%d active_entries=%d track_end_pending=%d track_end_awaiting=%d missing_tick=%d missing_ms=%d emitter_starts=%d emitter_stops=%d world_emitter_acquires=%d sound_start_failures=%d resolve_tracks_calls=%d inventory_sync_count=%d detached_sync_count=%d stable_off_skip=%d stable_off_sync=%d stop_missing_removals=%d",
        tonumber(snapshot.luaMb) or 0,
        math.floor(tonumber(snapshot.heapDeltaKb) or 0),
        tonumber(snapshot.tickMsAvg) or 0,
        tonumber(snapshot.tickMsMax) or 0,
        tonumber(snapshot.syncMsAvg) or 0,
        tonumber(snapshot.syncMsMax) or 0,
        tonumber(snapshot.inventoryDevices) or 0,
        tonumber(snapshot.detachedSources) or 0,
        tonumber(snapshot.activeEmitters) or 0,
        tonumber(snapshot.activeEntries) or 0,
        tonumber(snapshot.trackEndPending) or 0,
        tonumber(snapshot.trackEndAwaiting) or 0,
        tonumber(snapshot.missingTickCount) or 0,
        tonumber(snapshot.missingMsCount) or 0,
        tonumber(snapshot.emitterStarts) or 0,
        tonumber(snapshot.emitterStops) or 0,
        tonumber(snapshot.worldEmitterAcquires) or 0,
        tonumber(snapshot.soundStartFailures) or 0,
        tonumber(snapshot.resolveTracksCalls) or 0,
        tonumber(snapshot.inventorySyncCount) or 0,
        tonumber(snapshot.detachedSyncCount) or 0,
        tonumber(snapshot.stableOffInventorySkipCount) or 0,
        tonumber(snapshot.stableOffInventorySyncCount) or 0,
        tonumber(snapshot.stopMissingRemovals) or 0
    )
end

function NMPlaybackRuntimeDiagnostics.sampleMemoryProbe(runtimeTable, sample)
    if not memoryProbeEnabled() then
        return nil
    end
    local probe = runtimeTable and runtimeTable.Diagnostics and runtimeTable.Diagnostics.memoryProbe or nil
    if type(probe) ~= "table" then
        return nil
    end

    local currentNowMs = tonumber(sample and sample.nowMs) or nowMs()
    local heapKb = collectgarbage and tonumber(collectgarbage("count")) or 0
    local previousHeapKb = tonumber(probe.lastHeapKb)
    local heapDeltaKb = previousHeapKb and (heapKb - previousHeapKb) or 0
    local peaks = probe.peaks or {}
    probe.peaks = peaks

    local activeEntries = countTableEntries(runtimeTable and runtimeTable.Active or nil)
    local activeEmitters = countActiveEmitters(runtimeTable and runtimeTable.Active or nil)
    local trackEndPending = countTableEntries(runtimeTable and runtimeTable.TrackEndPending or nil)
    local trackEndAwaiting = countTableEntries(runtimeTable and runtimeTable.TrackEndAwaitingAdvance or nil)
    local missingTickCount = countTableEntries(runtimeTable and runtimeTable.MissingSinceTick or nil)
    local missingMsCount = countTableEntries(runtimeTable and runtimeTable.MissingSinceMs or nil)
    local trackedTotal = activeEntries + trackEndPending + trackEndAwaiting + missingTickCount + missingMsCount

    local prevPendingPeak, nextPendingPeak = updatePeak(peaks, "trackEndPending", trackEndPending)
    local prevAwaitingPeak, nextAwaitingPeak = updatePeak(peaks, "trackEndAwaiting", trackEndAwaiting)
    local _, nextHeapPeak = updatePeak(peaks, "luaHeapKb", heapKb)
    local _, nextEmitterPeak = updatePeak(peaks, "activeEmitters", activeEmitters)
    local _, nextTrackedPeak = updatePeak(peaks, "trackedTotal", trackedTotal)

    local tickMetric = getDurationSnapshot(probe, "tick_ms")
    local syncMetric = getDurationSnapshot(probe, "sync_device_ms")
    local inventoryMetric = getDurationSnapshot(probe, "inventory_collect_ms")
    local detachedMetric = getDurationSnapshot(probe, "detached_collect_ms")
    local stopMissingMetric = getDurationSnapshot(probe, "stop_missing_ms")

    local snapshot = {
        nowMs = currentNowMs,
        luaKb = heapKb,
        luaMb = heapKb / 1024.0,
        heapDeltaKb = heapDeltaKb,
        inventoryDevices = tonumber(sample and sample.inventoryDevices) or 0,
        detachedSources = tonumber(sample and sample.detachedSources) or 0,
        activeEntries = activeEntries,
        activeEmitters = activeEmitters,
        trackEndPending = trackEndPending,
        trackEndAwaiting = trackEndAwaiting,
        missingTickCount = missingTickCount,
        missingMsCount = missingMsCount,
        tickMsAvg = tickMetric.avgMs,
        tickMsMax = tickMetric.maxMs,
        syncMsAvg = syncMetric.avgMs,
        syncMsMax = syncMetric.maxMs,
        inventoryCollectMsAvg = inventoryMetric.avgMs,
        inventoryCollectMsMax = inventoryMetric.maxMs,
        detachedCollectMsAvg = detachedMetric.avgMs,
        detachedCollectMsMax = detachedMetric.maxMs,
        stopMissingMsAvg = stopMissingMetric.avgMs,
        stopMissingMsMax = stopMissingMetric.maxMs,
        emitterStarts = getCounter(probe, "emitter_starts"),
        emitterStops = getCounter(probe, "emitter_stops"),
        worldEmitterAcquires = getCounter(probe, "world_emitter_acquires"),
        soundStartAttempts = getCounter(probe, "sound_start_attempts"),
        soundStartFailures = getCounter(probe, "sound_start_failures"),
        resolveTracksCalls = getCounter(probe, "resolve_tracks_calls"),
        inventorySyncCount = getCounter(probe, "inventory_sync_count"),
        detachedSyncCount = getCounter(probe, "detached_sync_count"),
        stableOffInventorySkipCount = getCounter(probe, "playback_inventory_stable_off_skip"),
        stableOffInventorySyncCount = getCounter(probe, "playback_inventory_stable_off_sync"),
        stopMissingRemovals = getCounter(probe, "stop_missing_removals"),
        peaks = {
            luaHeapKb = nextHeapPeak,
            activeEmitters = nextEmitterPeak,
            trackedTotal = nextTrackedPeak,
            trackEndPending = nextPendingPeak,
            trackEndAwaiting = nextAwaitingPeak
        }
    }

    local heartbeatEveryMs = NMRuntimeConfig and NMRuntimeConfig.getMemoryProbeSampleIntervalMs and NMRuntimeConfig.getMemoryProbeSampleIntervalMs() or 5000
    local heapJumpKb = NMRuntimeConfig and NMRuntimeConfig.getMemoryProbeHeapDeltaKb and NMRuntimeConfig.getMemoryProbeHeapDeltaKb() or 512
    local tickHotMs = NMRuntimeConfig and NMRuntimeConfig.getMemoryProbeTickHotMs and NMRuntimeConfig.getMemoryProbeTickHotMs() or 8
    local syncHotMs = NMRuntimeConfig and NMRuntimeConfig.getMemoryProbeSyncHotMs and NMRuntimeConfig.getMemoryProbeSyncHotMs() or 4
    local playbackActive = sample and sample.playbackActive == true or false
    local shouldHeartbeat = (activeEmitters > 0 or trackEndPending > 0 or trackEndAwaiting > 0 or snapshot.inventorySyncCount > 0 or snapshot.detachedSyncCount > 0 or snapshot.stableOffInventorySkipCount > 0)
        and ((currentNowMs - (tonumber(probe.lastFlushMs) or 0)) >= heartbeatEveryMs)
    local shouldLogPlaybackStart = playbackActive == true and probe.lastPlaybackActive ~= true

    if probe.announcedReady ~= true then
        NMCore.logChannel("memory", "memory_probe_ready", string.format(
            "sample_interval_ms=%d heap_jump_kb=%d tick_hot_ms=%d sync_hot_ms=%d",
            tonumber(heartbeatEveryMs) or 0,
            tonumber(heapJumpKb) or 0,
            tonumber(tickHotMs) or 0,
            tonumber(syncHotMs) or 0
        ))
        probe.announcedReady = true
    end

    if heapDeltaKb >= heapJumpKb and NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, "memory_probe_anomaly", "global", "heap_jump:" .. tostring(math.floor(heapDeltaKb + 0.5)), 1500) then
        NMCore.logChannel("memory", "memory_probe_anomaly", "reason=heap_jump " .. NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
    end
    if snapshot.tickMsMax >= tickHotMs and NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, "memory_probe_anomaly", "global", "tick_hot:" .. tostring(math.floor(snapshot.tickMsMax + 0.5)), 1500) then
        NMCore.logChannel("memory", "memory_probe_anomaly", "reason=tick_hot " .. NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
    end
    if snapshot.syncMsMax >= syncHotMs and NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, "memory_probe_anomaly", "global", "sync_hot:" .. tostring(math.floor(snapshot.syncMsMax + 0.5)), 1500) then
        NMCore.logChannel("memory", "memory_probe_anomaly", "reason=sync_hot " .. NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
    end
    if trackEndPending > prevPendingPeak and trackEndPending > 0
        and NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, "memory_probe_anomaly", "global", "pending_peak:" .. tostring(trackEndPending), 2500) then
        NMCore.logChannel("memory", "memory_probe_anomaly", "reason=track_end_pending_peak " .. NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
    end
    if trackEndAwaiting > prevAwaitingPeak and trackEndAwaiting > 0
        and NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, "memory_probe_anomaly", "global", "awaiting_peak:" .. tostring(trackEndAwaiting), 2500) then
        NMCore.logChannel("memory", "memory_probe_anomaly", "reason=track_end_awaiting_peak " .. NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
    end

    if shouldLogPlaybackStart then
        NMCore.logChannel("memory", "memory_probe_playback_start", NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
        probe.lastFlushMs = currentNowMs
        resetWindow(probe)
        probe.lastHeapKb = heapKb
    elseif shouldHeartbeat then
        NMCore.logChannel("memory", "memory_probe_heartbeat", NMPlaybackRuntimeDiagnostics.formatMemoryProbeSnapshot(snapshot))
        probe.lastFlushMs = currentNowMs
        resetWindow(probe)
        probe.lastHeapKb = heapKb
    elseif probe.lastHeapKb == nil then
        probe.lastHeapKb = heapKb
    end

    probe.lastPlaybackActive = playbackActive == true
    probe.lastSnapshot = snapshot
    return snapshot
end

function NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, tag, uuid, signature, minIntervalMs)
    local key = tostring(tag or "") .. ":" .. tostring(uuid or "")
    local nowMs = 0
    if getTimestampMs then
        nowMs = tonumber(getTimestampMs()) or 0
    elseif getTimestamp then
        nowMs = (tonumber(getTimestamp()) or 0) * 1000
    end
    local lastSig = tostring(runtimeTable._lifecycleProbeSig[key] or "")
    local lastMs = tonumber(runtimeTable._lifecycleProbeMs[key]) or 0
    local interval = math.max(500, tonumber(minIntervalMs) or 3000)
    if lastSig == tostring(signature or "") and (nowMs - lastMs) < interval then
        return false
    end
    runtimeTable._lifecycleProbeSig[key] = tostring(signature or "")
    runtimeTable._lifecycleProbeMs[key] = nowMs
    return true
end

function NMPlaybackRuntimeDiagnostics.logEmitterTeardown(runtimeTable, uuid, reason, active)
    if not (active and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local detail = string.format(
        "uuid=%s reason=%s mode=%s context=%s token=%s:%s sourceGen=%s worldAlive=%s personalAlive=%s",
        tostring(uuid or ""),
        tostring(reason or "unknown"),
        tostring(active.mode or "single"),
        tostring(active.context or "unknown"),
        tostring(active.epoch or 0),
        tostring(active.trackIndex or 0),
        tostring(active.sourceGeneration or 0),
        tostring(active.world and active.world.alive == true),
        tostring(active.personal and active.personal.alive == true)
    )
    if NMPlaybackRuntimeDiagnostics.shouldLogLifecycleProbe(runtimeTable, "emitter_teardown", uuid, detail, 3000) then
        NMCore.logChannel("runtime", "emitter_teardown", detail)
    end
end

function NMPlaybackRuntimeDiagnostics.updateVehicleEmitter(runtimeTable, uuid, active, source, context)
    if context ~= "vehicle" or not source then
        return
    end
    if NMRuntimeConfig.isSubsystemDebugEnabled and NMRuntimeConfig.isSubsystemDebugEnabled("vehicle") ~= true then
        return
    end
    local x = tonumber(source.x)
    local y = tonumber(source.y)
    local z = tonumber(source.z)
    if not x or not y or not z then
        return
    end
    local prevX = tonumber(active.lastX)
    local prevY = tonumber(active.lastY)
    local prevZ = tonumber(active.lastZ)
    active.lastX, active.lastY, active.lastZ = x, y, z
    if not prevX or not prevY or not prevZ then
        return
    end

    local dx = x - prevX
    local dy = y - prevY
    local dz = z - prevZ
    local jumpDist = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    local warnDist = tonumber(NMRuntimeConfig.getVehicleEmitterJumpWarnDistance and NMRuntimeConfig.getVehicleEmitterJumpWarnDistance() or 12) or 12
    local rebindHintDist = tonumber(NMRuntimeConfig.getVehicleEmitterJumpRebindHintDistance and NMRuntimeConfig.getVehicleEmitterJumpRebindHintDistance() or 48) or 48

    if jumpDist >= warnDist then
        runtimeTable.Diagnostics.vehicleJumpWarnings = (tonumber(runtimeTable.Diagnostics.vehicleJumpWarnings) or 0) + 1
        runtimeTable.Diagnostics.vehicleJumps[tostring(uuid)] = {
            distance = jumpDist,
            x = x,
            y = y,
            z = z,
            dx = dx,
            dy = dy,
            dz = dz,
            sourceGeneration = tonumber(active.sourceGeneration) or 0
        }
        if NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("emitter") and NMCore.logChannel then
            NMCore.logChannel("emitter", "vehicle emitter jump", string.format("uuid=%s dist=%.2f", tostring(uuid), jumpDist))
        end
    end
    if jumpDist >= rebindHintDist then
        active.rebindHint = true
        runtimeTable.Diagnostics.vehicleRebindHints = (tonumber(runtimeTable.Diagnostics.vehicleRebindHints) or 0) + 1
    end
end

function NMPlaybackRuntimeDiagnostics.snapshot(runtimeTable)
    local out = {
        vehicleRebindHints = tonumber(runtimeTable.Diagnostics and runtimeTable.Diagnostics.vehicleRebindHints) or 0,
        vehicleJumpWarnings = tonumber(runtimeTable.Diagnostics and runtimeTable.Diagnostics.vehicleJumpWarnings) or 0,
        vehicleJumps = {},
        memoryProbe = runtimeTable.Diagnostics and runtimeTable.Diagnostics.memoryProbe and runtimeTable.Diagnostics.memoryProbe.lastSnapshot or nil
    }
    local rows = runtimeTable.Diagnostics and runtimeTable.Diagnostics.vehicleJumps or {}
    for uuid, row in pairs(rows) do
        out.vehicleJumps[uuid] = row
    end
    return out
end

