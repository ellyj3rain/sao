NMClientTrackFinishedDispatch = NMClientTrackFinishedDispatch or {}

local function buildTrackFinishedArgs(state, playbackMode, endedToken)
    local observedDurationMs = tonumber(endedToken and endedToken.observedDurationMs) or 0
    return NMClientTrackProgressionDispatch.buildTrackFinishedArgs(state, playbackMode, observedDurationMs)
end

local function logTrackFinishedDispatch(kind, uuid, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") then
        NMCore.logChannel(
            "playback_progression",
            "track_finished_dispatch",
            string.format("kind=%s uuid=%s %s", tostring(kind), tostring(uuid), tostring(detail or ""))
        )
    end
end

local function shouldLogTrackFinishedConsume(consumed)
    return consumed == true
end

local function nowRealMs()
    if NMPlaybackRuntimeCommon and NMPlaybackRuntimeCommon.getNowRealMs then
        return tonumber(NMPlaybackRuntimeCommon.getNowRealMs()) or 0
    end
    if getTimestampMs then
        return tonumber(getTimestampMs()) or 0
    end
    if getTimestamp then
        return (tonumber(getTimestamp()) or 0) * 1000
    end
    return 0
end

local function logTrackFinishedArgs(kind, uuid, state, args)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    NMCore.logChannel(
        "playback_progression",
        "track_finished_args",
        string.format(
            "kind=%s uuid=%s media=%s mode=%s stateTrack=%s payloadTrackCount=%s observedDurationMs=%s expectedEpoch=%s expectedTrack=%s",
            tostring(kind or "unknown"),
            tostring(uuid or ""),
            tostring(state and state.mediaFullType or "nil"),
            tostring(args and args.playbackMode or state and state.playbackMode or "nil"),
            tostring(state and state.trackIndex or -1),
            tostring(args and args.trackCount or 0),
            tostring(args and args.observedDurationMs or 0),
            tostring(args and args.expectedPlaybackEpoch or 0),
            tostring(args and args.expectedTrackIndex or 0)
        )
    )
end

local function persistDetachedSPSnapshot(uuid, entry, state)
    local source = entry and entry.source or nil
    if not source then
        return
    end
    NMWorldRegistrySnapshot.upsertSP({
        kind = "item",
        uuid = tostring(uuid),
        profileType = entry and (entry.profileType or entry.itemFullType) or nil,
        sourceMode = tostring(source.context or source.mode or "placed"),
        sourceEpoch = tonumber(state and state.sourceGeneration) or 0,
        x = tonumber(source.x) or 0,
        y = tonumber(source.y) or 0,
        z = tonumber(source.z) or 0,
        itemId = entry and entry.itemId or nil,
        itemFullType = entry and entry.itemFullType or nil,
        state = NMDeviceState.export(state),
        revision = tonumber(state and state.revision) or 0,
        playbackEpoch = tonumber(state and state.playbackEpoch) or 0
    })
end

local function requestImmediateDetachedSPRefresh(reason)
    local why = tostring(reason or "track_finished")
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("detached_sp_" .. why)
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("detached_sp_" .. why)
    elseif NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
        NMClientPlaybackTick.markDirty("detached_sp_" .. why)
    end
end

local function applyDetachedTrackFinishedLocalSP(uuid, profile, state, entry)
    local payload = buildTrackFinishedArgs(state, "world")
    local changed, reason = NMDeviceTransitions.apply(profile, state, "track_finished", payload)
    if not changed then
        logTrackFinishedDispatch("detached_sp", uuid, "applied=false reason=" .. tostring(reason or "none"))
        return
    end

    NMDeviceState.bumpPlaybackEpoch(state)
    NMDeviceState.bumpRevision(state)

    local keep = NMRegistryPolicy.shouldKeepWorldSourceState(state)
    if not keep then
        local src = entry and entry.source or nil
        local sourceContext = tostring(src and src.context or src and src.mode or "")
        local worldContext = (
            sourceContext == "placed"
            or sourceContext == "vehicle"
            or sourceContext == "attached"
            or sourceContext == "stowed"
            or sourceContext == "world"
        )
        if worldContext and (state.isOn == true or state.isPlaying == true or state.desiredIsOn == true or state.desiredIsPlaying == true) then
            state.playbackMode = "world"
            keep = true
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") then
                NMCore.logChannel(
                    "playback_progression",
                    "detached_sp_keep_override",
                    string.format(
                        "uuid=%s reason=world_context_active ctx=%s isOn=%s isPlaying=%s",
                        tostring(uuid),
                        tostring(sourceContext),
                        tostring(state.isOn == true),
                        tostring(state.isPlaying == true)
                    )
                )
            end
        end
    end
    if keep then
        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then
            local source = entry and entry.source or nil
            NMClientWorldSourceCache.upsertFromPayload({
                kind = "item",
                uuid = tostring(uuid),
                profileType = entry and (entry.profileType or entry.itemFullType) or nil,
                sourceMode = tostring(source and (source.context or source.mode) or "placed"),
                x = tonumber(source and source.x) or 0,
                y = tonumber(source and source.y) or 0,
                z = tonumber(source and source.z) or 0,
                itemId = entry and entry.itemId or nil,
                itemFullType = entry and entry.itemFullType or nil,
                sourceEpoch = tonumber(state.sourceGeneration) or 0,
                state = state
            })
        end
        persistDetachedSPSnapshot(uuid, entry, state)
        if NMClientDetachedProgressionUiRefresh and NMClientDetachedProgressionUiRefresh.invalidateDetachedPortableWindow then
            NMClientDetachedProgressionUiRefresh.invalidateDetachedPortableWindow(
                uuid,
                entry and entry.itemId or nil,
                state,
                source and (source.context or source.mode) or "placed"
            )
        end
        if NMClientDetachedProgressionUiRefresh and NMClientDetachedProgressionUiRefresh.requestRuntimeRefresh then
            NMClientDetachedProgressionUiRefresh.requestRuntimeRefresh(uuid, state, "keep")
        else
            requestImmediateDetachedSPRefresh("keep")
        end
        logTrackFinishedDispatch("detached_sp", uuid, "applied=true keep=true")
    else
        NMClientWorldSourceCache.remove(uuid)
        NMWorldRegistrySnapshot.removeSP(uuid)
        logTrackFinishedDispatch("detached_sp", uuid, "applied=true keep=false")
    end
end

local function dispatchTrackFinishedForInventory(player, item, state, uuid, endedToken)
    if not player or not item or not state then
        return
    end
    local mode = tostring(state.playbackMode or "inventory")
    local worldAuthoritative = mode == "world"
    local action = worldAuthoritative and "track_finished_world" or "track_finished"
    local kind = worldAuthoritative and "world_item" or "inventory"
    local args = buildTrackFinishedArgs(state, mode, endedToken)
    logTrackFinishedArgs(kind, uuid, state, args)
    local ok, reason = NMClientIntentDispatch.performIntent(player, item, action, args)
    logTrackFinishedDispatch(
        kind,
        uuid,
        "ok=" .. tostring(ok == true)
            .. " reason=" .. tostring(reason or "none")
            .. " token=" .. tostring(args.expectedPlaybackEpoch or 0) .. ":" .. tostring(args.expectedTrackIndex or 0)
    )
end

local function dispatchTrackFinishedForVehicle(player, profile, state, entry, uuid, endedToken)
    local source = entry and entry.source or nil
    local vehicle = source and source.vehicle or nil
    if (not vehicle) and source and source.vehicleId and getVehicleById then
        vehicle = getVehicleById(tonumber(source.vehicleId))
    end
    if not vehicle then
        logTrackFinishedDispatch("vehicle", uuid, "ok=false reason=vehicle_missing")
        return
    end
    local partId = tostring(entry and entry.partId or "Radio")
    local part = vehicle.getPartById and vehicle:getPartById(partId) or nil
    if not part then
        part = vehicle.getPartById and vehicle:getPartById("Radio") or nil
    end
    if not part then
        logTrackFinishedDispatch("vehicle", uuid, "ok=false reason=part_missing")
        return
    end

    local args = buildTrackFinishedArgs(state, "world", endedToken)
    logTrackFinishedArgs("vehicle", uuid, state, args)
    local ok, reason = NMClientIntentDispatch.performVehicleIntent(player, vehicle, part, "track_finished", args)
    logTrackFinishedDispatch(
        "vehicle",
        uuid,
        "ok=" .. tostring(ok == true)
            .. " reason=" .. tostring(reason or "none")
            .. " token=" .. tostring(args.expectedPlaybackEpoch or 0) .. ":" .. tostring(args.expectedTrackIndex or 0)
    )
end

local function dispatchTrackFinishedForDetachedItem(player, profile, state, entry, uuid, endedToken)
    if not NMCore.isMPClientRuntime() then
        applyDetachedTrackFinishedLocalSP(uuid, profile, state, entry)
        return
    end

    local itemId = tostring(entry and entry.itemId or "")
    if itemId == "" then
        logTrackFinishedDispatch("detached_mp", uuid, "ok=false reason=item_id_missing")
        return
    end
    local floors = NMDeviceProfiles.getWorldTrackingFloors(profile)
    local item = NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, 8, floors)
    if not item then
        logTrackFinishedDispatch("detached_mp", uuid, "ok=false reason=item_not_found itemId=" .. tostring(itemId))
        return
    end
    local args = buildTrackFinishedArgs(state, "world", endedToken)
    logTrackFinishedArgs("detached_mp", uuid, state, args)
    local ok, reason = NMClientIntentDispatch.performIntent(player, item, "track_finished", args)
    logTrackFinishedDispatch(
        "detached_mp",
        uuid,
        "ok=" .. tostring(ok == true)
            .. " reason=" .. tostring(reason or "none")
            .. " token=" .. tostring(args.expectedPlaybackEpoch or 0) .. ":" .. tostring(args.expectedTrackIndex or 0)
    )
end

function NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished(player, profile, state, entry, item, sourceKind, uuid)
    local endedToken = NMPlaybackRuntime.consumeTrackEndedToken(uuid)
    if not endedToken then
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")
            and shouldLogTrackFinishedConsume(false) then
            NMCore.logChannel(
                "playback_progression",
                "track_finished_consume",
                string.format(
                    "uuid=%s sourceKind=%s consumed=false media=%s epoch=%s track=%s",
                    tostring(uuid),
                    tostring(sourceKind or "unknown"),
                    tostring(state and state.mediaFullType or "nil"),
                    tostring(state and state.playbackEpoch or -1),
                    tostring(state and state.trackIndex or -1)
                )
            )
        end
        return
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")
        and shouldLogTrackFinishedConsume(true) then
        local consumeAtMs = nowRealMs()
        local confirmedAtMs = tonumber(endedToken and endedToken.confirmedAtMs) or 0
        NMCore.logChannel(
            "playback_progression",
            "track_finished_consume",
            string.format(
                "uuid=%s sourceKind=%s consumed=true observedDurationMs=%s media=%s epoch=%s track=%s confirmedAtMs=%s consumeAtMs=%s consumeDelayMs=%s firstFalseMs=%s pendingElapsedMs=%s falseCount=%s windowMs=%s falseChecks=%s policy=%s context=%s",
                tostring(uuid),
                tostring(sourceKind or "unknown"),
                tostring(endedToken and endedToken.observedDurationMs or 0),
                tostring(state and state.mediaFullType or "nil"),
                tostring(state and state.playbackEpoch or -1),
                tostring(state and state.trackIndex or -1),
                tostring(endedToken and endedToken.confirmedAtMs or "nil"),
                tostring(consumeAtMs),
                tostring(confirmedAtMs > 0 and math.max(0, consumeAtMs - confirmedAtMs) or "nil"),
                tostring(endedToken and endedToken.firstFalseMs or "nil"),
                tostring(endedToken and endedToken.pendingElapsedMs or "nil"),
                tostring(endedToken and endedToken.falseCount or "nil"),
                tostring(endedToken and endedToken.windowMs or "nil"),
                tostring(endedToken and endedToken.falseChecks or "nil"),
                tostring(endedToken and endedToken.policy or "default"),
                tostring(endedToken and endedToken.context or "unknown")
            )
        )
    end
    if sourceKind == "inventory" or sourceKind == "world_item" then
        dispatchTrackFinishedForInventory(player, item, state, uuid, endedToken)
        return
    end
    if sourceKind == "vehicle" then
        dispatchTrackFinishedForVehicle(player, profile, state, entry, uuid, endedToken)
        return
    end
    dispatchTrackFinishedForDetachedItem(player, profile, state, entry, uuid, endedToken)
end

return NMClientTrackFinishedDispatch

