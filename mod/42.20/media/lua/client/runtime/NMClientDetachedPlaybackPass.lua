-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Detached playback pass for pending drops and cached world sources.
NMClientDetachedPlaybackPass = NMClientDetachedPlaybackPass or {}

local function syncAndObserve(player, profile, state, source, tickCount, options)
    local nowRealMs = options.nowRealMs
    local observeMemoryDuration = options.observeMemoryDuration
    local startedMs = nowRealMs()
    NMPlaybackRuntime.syncDevice(player, profile, state, source, tickCount * 60)
    if NMClientVanillaMusicSuppressor and NMClientVanillaMusicSuppressor.observeAudibility then
        NMClientVanillaMusicSuppressor.observeAudibility(player, profile, state, source)
    end
    observeMemoryDuration("sync_device_ms", math.max(0, nowRealMs() - startedMs))
end

function NMClientDetachedPlaybackPass.run(player, options)
    local valid = options.valid
    local inventoryOwners = options.inventoryOwners
    local currentInventoryByUuid = options.currentInventoryByUuid
    local spPulseCandidates = options.spPulseCandidates
    local tickCount = options.tickCount
    local nowRealMs = options.nowRealMs
    local observeMemoryDuration = options.observeMemoryDuration
    local consumeAndDispatchTrackFinished = options.consumeAndDispatchTrackFinished
    local shouldLogDetachedSync = options.shouldLogDetachedSync
    local applySPLocalVehiclePowerGuard = options.applySPLocalVehiclePowerGuard
    local resolveVehicleCanonicalGeneration = options.resolveVehicleCanonicalGeneration
    local persistVehicleCanonicalGeneration = options.persistVehicleCanonicalGeneration
    local setVehicleIdentityState = options.setVehicleIdentityState
    local detachedOrchestration = options.detachedOrchestration
    local continuity = options.continuity
    local ownershipConflictState = options.ownershipConflictState
    local detachedRemoveLogMs = options.detachedRemoveLogMs
    local logTransitionProbe = options.logTransitionProbe
    local logRuntime = options.logRuntime
    local logVehicleRuntime = options.logVehicleRuntime
    local rememberFastSource = options.rememberFastSource
    local rememberTrackMonitorContext = options.rememberTrackMonitorContext
    local rememberPlaybackLossSource = options.rememberPlaybackLossSource
    local emitPlaybackLossProbe = options.emitPlaybackLossProbe
    local pendingPlayback = options.pendingPlaybackOut or {}
    local detached = options.detachedOut or {}

    local detachedSyncCount = 0

    if NMClientPortableDropHandoff and NMClientPortableDropHandoff.collectPendingPlayback then
        NMClientPortableDropHandoff.collectPendingPlayback(player, currentInventoryByUuid, pendingPlayback)
        for i = 1, #pendingPlayback do
            local p = pendingPlayback[i]
            if p and p.uuid and p.profile and p.state and p.source then
                p.state.playbackMode = "world"
                syncAndObserve(player, p.profile, p.state, p.source, tickCount, {
                    nowRealMs = nowRealMs,
                    observeMemoryDuration = observeMemoryDuration
                })
                detachedSyncCount = detachedSyncCount + 1
                if rememberFastSource then
                    rememberFastSource(p.uuid, p.profile, p.state, p.source, player)
                end
                if rememberTrackMonitorContext then
                    rememberTrackMonitorContext(p.uuid, p.profile, p.state, p.source, "drop_pending", p.item, nil)
                end
                if rememberPlaybackLossSource then
                    rememberPlaybackLossSource(p.uuid, p.state, p.source, {
                        mode = tostring(p.source and p.source.context or "drop_pending"),
                        resolvedOutput = "world"
                    })
                end
                if emitPlaybackLossProbe then
                    emitPlaybackLossProbe(player, p.uuid, true, "pending_world_sync", {
                        source = p.source,
                        mode = tostring(p.source and p.source.context or "drop_pending"),
                        playbackMode = p.state and p.state.playbackMode or "world",
                        resolvedOutput = "world",
                        isOn = p.state and p.state.isOn == true,
                        isPlaying = p.state and p.state.isPlaying == true,
                        media = p.state and p.state.mediaFullType
                    })
                end
                consumeAndDispatchTrackFinished(player, p.profile, p.state, nil, p.item, "drop_pending", p.uuid)
                valid[p.uuid] = true
                if tostring(p.source.context or "") == "placed"
                    and not spPulseCandidates[p.uuid]
                    and p.source.x and p.source.y and p.source.z then
                    spPulseCandidates[p.uuid] = {
                        profile = p.profile,
                        state = p.state,
                        source = p.source
                    }
                end
            end
        end
    end

    local detachedCollectStartedMs = nowRealMs()
    NMClientWorldSourceCache.collectInRange(player, detached)
    observeMemoryDuration("detached_collect_ms", math.max(0, nowRealMs() - detachedCollectStartedMs))

    for i = 1, #detached do
        local d = detached[i]
        local entry = d.entry
        local state = entry and entry.stateSnapshot or nil
        local profile = d.profile
        if state and profile and state.deviceUUID then
            local uuid = tostring(state.deviceUUID)
            local liveEntry = NMClientWorldSourceCache.get and NMClientWorldSourceCache.get(uuid) or nil
            local src = entry and entry.source or nil
            local detachedContext = tostring(src and src.context or "unknown")
            local ownershipResult = NMClientOwnershipConflictPolicy.applyInventoryOwnership({
                uuid = uuid,
                detachedContext = detachedContext,
                hasInventoryOwner = inventoryOwners[uuid] == true,
                ownershipConflictState = ownershipConflictState,
                detachedRemoveLogMs = detachedRemoveLogMs,
                detachedOrchestration = detachedOrchestration,
                nowMs = nowRealMs(),
                profile = profile,
                removeDetached = function(key)
                    NMClientWorldSourceCache.remove(key)
                end,
                logTransitionProbe = logTransitionProbe,
                logRuntime = logRuntime
            })

            if ownershipResult.allowDetachedSync == true then
                detachedContext = tostring(ownershipResult.detachedContext or detachedContext)
                if detachedContext == "vehicle" then
                    local continuityResult = continuity.applyDetachedVehicleContinuity
                        and continuity.applyDetachedVehicleContinuity({
                            uuid = uuid,
                            entry = entry,
                            liveEntry = liveEntry,
                            state = state,
                            src = src,
                            detachedContext = detachedContext,
                            nowMs = nowRealMs(),
                            resolveVehicleCanonicalGeneration = resolveVehicleCanonicalGeneration,
                            persistVehicleCanonicalGeneration = persistVehicleCanonicalGeneration,
                            setVehicleIdentityState = setVehicleIdentityState
                        })
                        or nil
                    if continuityResult then
                        entry = continuityResult.entry or entry
                        liveEntry = continuityResult.liveEntry or liveEntry
                        state = continuityResult.state or state
                        src = continuityResult.src or src
                        detachedContext = tostring(continuityResult.detachedContext or detachedContext)
                    end
                end

                if detachedContext == "vehicle" then
                    applySPLocalVehiclePowerGuard(profile, state, src, uuid)
                end

                if shouldLogDetachedSync(state.deviceUUID, state, src) and (logRuntime or logVehicleRuntime) then
                    local emitSyncLog = detachedContext == "vehicle" and logVehicleRuntime or logRuntime
                    if emitSyncLog then
                        emitSyncLog(
                        "detached_sync",
                        detachedOrchestration and detachedOrchestration.buildDetachedSyncDetail
                            and detachedOrchestration.buildDetachedSyncDetail(player, entry, state, src)
                            or string.format(
                                "uuid=%s ctx=%s sourceX=%.2f sourceY=%.2f sourceZ=%.2f lastPayloadApplyMs=%s isOn=%s isPlaying=%s media=%s",
                                tostring(state.deviceUUID),
                                tostring(src and src.context or "nil"),
                                tonumber(src and src.x or 0) or 0,
                                tonumber(src and src.y or 0) or 0,
                                tonumber(src and src.z or 0) or 0,
                                tostring(entry and entry._lastPayloadApplyMs or 0),
                                tostring(state.isOn == true),
                                tostring(state.isPlaying == true),
                                tostring(state.mediaFullType or "nil")
                            )
                        )
                    end
                end

                syncAndObserve(player, profile, state, entry.source, tickCount, {
                    nowRealMs = nowRealMs,
                    observeMemoryDuration = observeMemoryDuration
                })
                detachedSyncCount = detachedSyncCount + 1
                if rememberFastSource then
                    rememberFastSource(uuid, profile, state, entry and entry.source, player)
                end
                local sourceKind = detachedContext == "vehicle" and "vehicle" or "detached_item"
                if rememberTrackMonitorContext then
                    rememberTrackMonitorContext(uuid, profile, state, entry and entry.source, sourceKind, nil, entry)
                end
                if rememberPlaybackLossSource then
                    rememberPlaybackLossSource(uuid, state, entry and entry.source, {
                        mode = detachedContext,
                        resolvedOutput = "world"
                    })
                end
                if emitPlaybackLossProbe then
                    emitPlaybackLossProbe(player, uuid, true, "detached_world_sync", {
                        source = entry and entry.source,
                        mode = detachedContext,
                        playbackMode = state and state.playbackMode or "world",
                        resolvedOutput = "world",
                        isOn = state and state.isOn == true,
                        isPlaying = state and state.isPlaying == true,
                        media = state and state.mediaFullType
                    })
                end
                consumeAndDispatchTrackFinished(player, profile, state, entry, nil, sourceKind, uuid)
                valid[tostring(state.deviceUUID)] = true
                if not spPulseCandidates[uuid] then
                    local detachedSource = entry and entry.source or nil
                    if detachedSource and detachedSource.x and detachedSource.y and detachedSource.z then
                        spPulseCandidates[uuid] = {
                            profile = profile,
                            state = state,
                            source = detachedSource
                        }
                    end
                end
            end
        end
    end

    return {
        detached = detached,
        detachedSyncCount = detachedSyncCount
    }
end

return NMClientDetachedPlaybackPass
