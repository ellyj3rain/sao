require "intents/vehicle/NMServerVehicleIntentLogging"

NMServerVehicleIntentTargeting = NMServerVehicleIntentTargeting or {}

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function exportStateOnce(ctx, state)
    if type(ctx) == "table" then
        local cachedState = ctx._exportedStateSource
        if cachedState == state and type(ctx._exportedStateSnapshot) == "table" then
            return ctx._exportedStateSnapshot
        end
    end

    local snapshot = NMDeviceState.export(state)
    if type(ctx) == "table" then
        ctx._exportedStateSource = state
        ctx._exportedStateSnapshot = snapshot
    end
    return snapshot
end

local function invalidateExportState(ctx, state)
    if type(ctx) ~= "table" then
        return
    end
    if state == nil or ctx._exportedStateSource == state then
        ctx._exportedStateSource = nil
        ctx._exportedStateSnapshot = nil
    end
end

local function resolveVehicleIdentityFields(ctx)
    if type(ctx) ~= "table" then
        return nil
    end
    local identity = ctx._vehicleIdentity or {}
    local vehicle = ctx.vehicle
    local part = ctx.part
    if identity.vehicleRuntimeId == nil then
        identity.vehicleRuntimeId = vehicle and vehicle.getId and tostring(vehicle:getId() or "") or tostring(ctx.args and ctx.args.vehicleId or "")
    end
    if identity.partId == nil then
        identity.partId = part and part.getId and tostring(part:getId() or "") or tostring(ctx.args and ctx.args.partId or "Radio")
    end
    if identity.vehicleSqlId == nil then
        identity.vehicleSqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or ""
    end
    ctx._vehicleIdentity = identity
    return identity
end

local function buildRequestSummary(ctx)
    if type(ctx) ~= "table" then
        return nil
    end
    local player = ctx.player
    local vehicle = ctx.vehicle
    local part = ctx.part
    local state = ctx.state
    local args = ctx.args or {}
    local identity = resolveVehicleIdentityFields(ctx)
    local summary = ctx._requestSummary or {}
    summary.playerOnlineId = player and player.getOnlineID and tostring(player:getOnlineID() or "") or ""
    summary.playerName = player and player.getUsername and tostring(player:getUsername() or "") or ""
    summary.vehicleId = identity and tostring(identity.vehicleRuntimeId or "") or (vehicle and vehicle.getId and tostring(vehicle:getId() or "") or tostring(args.vehicleId or ""))
    summary.partId = identity and tostring(identity.partId or "") or (part and part.getId and tostring(part:getId() or "") or tostring(args.partId or "Radio"))
    summary.vehicleSqlId = identity and tostring(identity.vehicleSqlId or "") or ""
    summary.deviceUUID = state and tostring(state.deviceUUID or "") or ""
    ctx.playerOnlineId = summary.playerOnlineId
    ctx.playerName = summary.playerName
    ctx.vehicleId = summary.vehicleId
    ctx.partId = summary.partId
    ctx.vehicleSqlId = summary.vehicleSqlId
    ctx.deviceUUID = summary.deviceUUID
    ctx._requestSummary = summary
    return summary
end

local function resolveCanonicalVehicleSourceGeneration(state, existingEntry)
    return math.max(
        0,
        tonumber(state and state.sourceGeneration) or 0,
        tonumber(existingEntry and existingEntry.sourceEpoch) or 0,
        tonumber(existingEntry and existingEntry.sourceGeneration) or 0
    )
end

local function logVehicleSqlAnchorProof(entry, vehicle, part, state, transitionReason)
    local nowStamp = nowRealMs()
    local liveVehicleSqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or ""
    local liveRuntimeId = tostring(vehicle and vehicle.getId and vehicle:getId() or "")
    local md = part and part.getModData and part:getModData() or nil
    local node = md and md[NMCore.StateKey] or nil
    local currentPartUuid = tostring(node and node.deviceUUID or "")
    local stateDeviceUuid = tostring(state and state.deviceUUID or "")
    local sqlConsistency = (tostring(entry.vehicleSqlId or "") == tostring(liveVehicleSqlId or "")) and "match" or "mismatch"
    local uuidKey = tostring(entry.uuid or "")
    local proofSig = table.concat({
        tostring(entry.vehicleSqlId or ""),
        tostring(liveVehicleSqlId or ""),
        tostring(entry.vehicleId or ""),
        tostring(liveRuntimeId or ""),
        tostring(entry.partId or "Radio"),
        tostring(currentPartUuid or ""),
        tostring(stateDeviceUuid or ""),
        tostring(sqlConsistency),
        tostring(transitionReason or "upsert")
    }, "|")
    local lastProofSig = tostring(NMServerRegistryState.vehicleTruthSqlProofSigByUuid[uuidKey] or "")
    local lastProofMs = tonumber(NMServerRegistryState.vehicleTruthSqlProofMsByUuid[uuidKey]) or 0
    if proofSig ~= lastProofSig or (nowStamp - lastProofMs) >= 20000 then
        NMServerRegistryState.vehicleTruthSqlProofSigByUuid[uuidKey] = proofSig
        NMServerRegistryState.vehicleTruthSqlProofMsByUuid[uuidKey] = nowStamp
        local traceToken = table.concat({
            tostring(entry.uuid or ""),
            tostring(entry.sourceGeneration or 0),
            tostring(tonumber(state and state.revision) or 0),
            tostring(tonumber(state and state.playbackEpoch) or 0)
        }, "|")
        NMCore.logChannel(
            "vehicle",
            "vehicle_truth_sql_anchor_proof",
            string.format(
                "traceToken=%s uuid=%s reasonContext=%s sqlConsistency=%s authoritativeSql=%s liveVehicleSql=%s authoritativeRuntimeHint=%s liveRuntimeId=%s partId=%s partUuid=%s stateDeviceUuid=%s",
                tostring(traceToken),
                tostring(entry.uuid or ""),
                tostring(transitionReason or "upsert"),
                tostring(sqlConsistency),
                tostring(entry.vehicleSqlId or ""),
                tostring(liveVehicleSqlId or ""),
                tostring(entry.vehicleId or ""),
                tostring(liveRuntimeId or ""),
                tostring(entry.partId or "Radio"),
                tostring(currentPartUuid),
                tostring(stateDeviceUuid)
            )
        )
    end
    return currentPartUuid
end

local function logVehiclePartUuidStability(entry, state, transitionReason, currentPartUuid)
    local identityKey = table.concat({
        tostring(entry.uuid or ""),
        tostring(entry.vehicleSqlId or ""),
        tostring(entry.partId or "Radio")
    }, "|")
    local prevPartUuid = tostring(NMServerRegistryState.vehiclePartUuidByIdentity[identityKey] or "")
    if prevPartUuid ~= "" and currentPartUuid ~= "" and prevPartUuid ~= currentPartUuid then
        local traceToken = table.concat({
            tostring(entry.uuid or ""),
            tostring(entry.sourceGeneration or 0),
            tostring(tonumber(state and state.revision) or 0),
            tostring(tonumber(state and state.playbackEpoch) or 0)
        }, "|")
        NMCore.logChannel(
            "vehicle",
            "vehicle_truth_part_uuid_stability",
            string.format(
                "traceToken=%s uuid=%s vehicleSqlId=%s partId=%s previousPartUuid=%s currentPartUuid=%s reasonContext=%s",
                tostring(traceToken),
                tostring(entry.uuid or ""),
                tostring(entry.vehicleSqlId or ""),
                tostring(entry.partId or "Radio"),
                tostring(prevPartUuid),
                tostring(currentPartUuid),
                tostring(transitionReason or "upsert")
            )
        )
    end
    if currentPartUuid ~= "" then
        NMServerRegistryState.vehiclePartUuidByIdentity[identityKey] = currentPartUuid
    end
end

function NMServerVehicleIntentTargeting.refreshRequestContext(ctx)
    return buildRequestSummary(ctx)
end

function NMServerVehicleIntentTargeting.exportStateForContext(ctx, state)
    return exportStateOnce(ctx, state)
end

function NMServerVehicleIntentTargeting.invalidateExportState(ctx, state)
    return invalidateExportState(ctx, state)
end

function NMServerVehicleIntentTargeting.resolveVehicleAndPart(args)
    local vehicleId = tonumber(args and args.vehicleId)
    if vehicleId == nil or not getVehicleById then
        return nil, nil
    end
    local vehicle = getVehicleById(vehicleId)
    if not vehicle then
        return nil, nil
    end
    local partId = tostring(args and args.partId or "Radio")
    local part = vehicle.getPartById and vehicle:getPartById(partId) or nil
    return vehicle, part
end

function NMServerVehicleIntentTargeting.findRegistryEntryByVehiclePart(vehicleId, partId)
    local vid = tostring(vehicleId or "")
    local pid = tostring(partId or "Radio")
    if vid == "" then
        return nil
    end
    local world = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(world) ~= "table" then
        return nil
    end
    for _, entry in pairs(world) do
        if type(entry) == "table"
            and tostring(entry.kind or "") == "vehicle"
            and tostring(entry.vehicleId or "") == vid
            and tostring(entry.partId or "Radio") == pid then
            return entry
        end
    end
    return nil
end

function NMServerVehicleIntentTargeting.buildVehicleAuthorityContext(player, vehicle)
    return {
        sourceX = vehicle and tonumber(vehicle:getX()) or nil,
        sourceY = vehicle and tonumber(vehicle:getY()) or nil,
        sourceZ = vehicle and tonumber(vehicle:getZ()) or nil,
        sourceOwner = NMIntentAuthority.resolveSourceOwnerIdentity(player)
    }
end

function NMServerVehicleIntentTargeting.shouldRefreshVehicleTimeline(changed, state, entry, action)
    return changed
        and entry
        and state
        and state.isOn == true
        and state.isPlaying == true
        and (
            action == "play"
            or action == "next_track"
            or action == "prev_track"
            or action == "track_finished"
        )
end

function NMServerVehicleIntentTargeting.sendStateForContext(ctx, player, vehicle, part, state, canonicalSourceGen, transitionReason, slotTraceId)
    if not player or not vehicle or not part or not state or not sendServerCommand then
        return
    end
    local canonicalGen = math.max(0, tonumber(canonicalSourceGen) or tonumber(state.sourceGeneration) or 0)
    state.sourceGeneration = math.max(tonumber(state.sourceGeneration) or 0, canonicalGen)
    if vehicle.transmitPartModData then
        vehicle:transmitPartModData(part)
        vehicle:updateParts()
    end
    sendServerCommand(player, NMCore.NetModule, "state", {
        vehicleId = tostring(ctx and ctx.vehicleId or vehicle:getId()),
        vehicleSqlId = tostring(ctx and ctx.vehicleSqlId or ""),
        partId = tostring(ctx and ctx.partId or part:getId()),
        state = exportStateOnce(ctx, state),
        sourceGeneration = canonicalGen,
        slotTraceId = slotTraceId ~= nil and tostring(slotTraceId) or nil,
        transitionReason = transitionReason ~= nil and tostring(transitionReason) or nil,
        serverSessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    })
end

function NMServerVehicleIntentTargeting.broadcastRegistryEntryForContext(ctx, entry, state, op)
    local function recipients(applyFn)
        local players = getOnlinePlayers and getOnlinePlayers() or nil
        if not players then
            return
        end
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                applyFn(p)
            end
        end
    end
    NMServerRegistryBroadcast.broadcastEntry(
        NMServerRegistryState.worldRegistry,
        tostring(entry.uuid or ""),
        nil,
        entry.stateSnapshot or exportStateOnce(ctx, state),
        op,
        recipients
    )
    if NMServerVehicleIntentLogging.isSlotEnabled() then
        NMServerVehicleIntentLogging.logVehicleSlotTrace(
            "vehicle_slot_registry_broadcast",
            string.format(
                "trace=%s host=vehicle ui=vehicle action=%s stage=registry_broadcast result=ok uuid=%s vehicleId=%s partId=%s op=%s media=%s",
                tostring(ctx and ctx.args and ctx.args.slotTraceId or ""),
                tostring(ctx and ctx.action or ""),
                tostring(entry and entry.uuid or ""),
                tostring(entry and entry.vehicleId or ""),
                tostring(entry and entry.partId or ""),
                tostring(op),
                tostring(ctx and ctx.state and ctx.state.mediaFullType or "")
            )
        )
    end
end

function NMServerVehicleIntentTargeting.removeRegistryEntry(entry)
    NMServerRegistryState.worldRegistry[tostring(entry.uuid)] = nil
end

function NMServerVehicleIntentTargeting.suppressVanillaVehicleRadio(part)
    local data = part and part.getDeviceData and part:getDeviceData() or nil
    if data and data.getIsTurnedOn and data.setIsTurnedOn and data:getIsTurnedOn() then
        data:setIsTurnedOn(false)
    end
end

function NMServerVehicleIntentTargeting.resolveVehicleRegistryIdentityForContext(ctx, vehicle, part, state)
    local identity = resolveVehicleIdentityFields(ctx)
    local vehicleSqlId = identity and tostring(identity.vehicleSqlId or "") or ""
    if vehicleSqlId == "" then
        return nil
    end

    return {
        uuid = tostring(ctx and ctx.deviceUUID or state and state.deviceUUID or ""),
        vehicleId = tostring(ctx and ctx.vehicleId or identity and identity.vehicleRuntimeId or ""),
        vehicleSqlId = vehicleSqlId,
        ownerId = tostring(state and state.sourceOwner or ""),
        partId = tostring(ctx and ctx.partId or identity and identity.partId or "Radio"),
        x = tonumber(vehicle and vehicle.getX and vehicle:getX() or 0) or 0,
        y = tonumber(vehicle and vehicle.getY and vehicle:getY() or 0) or 0,
        z = tonumber(vehicle and vehicle.getZ and vehicle:getZ() or 0) or 0
    }
end

function NMServerVehicleIntentTargeting.buildVehicleRegistrySnapshot(ctx, vehicle, part, state, existing, identity, canonicalGen, transitionReason)
    local entry = existing or {}
    entry.kind = "vehicle"
    entry.uuid = identity.uuid
    entry.vehicleId = identity.vehicleId
    entry.vehicleIdHint = identity.vehicleId
    entry.vehicleSqlId = identity.vehicleSqlId
    entry.vehicleSqlIdHint = tostring(identity.vehicleSqlId or "")
    entry.ownerId = identity.ownerId
    entry.partId = identity.partId
    entry.profileType = "vehicle_radio"
    entry.x = identity.x
    entry.y = identity.y
    entry.z = identity.z
    entry.sourceMode = "vehicle"
    entry.sourceEpoch = canonicalGen
    entry.sourceGeneration = canonicalGen
    entry.sourceRebind = false
    entry.windowsOpen = NMVehicleHelpers and NMVehicleHelpers.vehicleWindowsOpen and NMVehicleHelpers.vehicleWindowsOpen(vehicle) or false
    entry.stateSnapshot = exportStateOnce(ctx, state)
    entry.playbackEpoch = tonumber(state.playbackEpoch) or 0
    entry.trackIndex = tonumber(state.trackIndex) or 1
    entry.trackCount = math.max(
        0,
        math.floor(
            tonumber(state.trackCount)
                or tonumber(existing and existing.trackCount)
                or (NMTrackCountResolver and NMTrackCountResolver.resolveFromState and NMTrackCountResolver.resolveFromState(state))
                or 0
        )
    )
    entry.playbackPolicy = tostring(state.playbackPolicy or "autoplay")
    entry.transitionReason = transitionReason ~= nil and tostring(transitionReason) or nil
    if entry._vehicleResolved == nil then
        entry._vehicleResolved = true
    end
    if tostring(entry._vehicleContinuityMode or "") == "" then
        entry._vehicleContinuityMode = "LIVE_RESOLVED"
    end
    if NMServerRegistryBroadcast and NMServerRegistryBroadcast.touchEntry then
        NMServerRegistryBroadcast.touchEntry(entry, state)
    end
    return entry
end

function NMServerVehicleIntentTargeting.upsertRegistryForContext(ctx, vehicle, part, profile, state, transitionReason)
    if not vehicle or not part or not profile or not state or not state.deviceUUID then
        return nil, tonumber(state and state.sourceGeneration) or 0
    end

    local identity = NMServerVehicleIntentTargeting.resolveVehicleRegistryIdentityForContext(ctx, vehicle, part, state)
    if not identity then
        NMServerVehicleIntentLogging.logRuntime(
            "server_vehicle_registry_missing_sql",
            string.format(
                "uuid=%s vehicleId=%s partId=%s",
                tostring(state and state.deviceUUID or ""),
                tostring(vehicle and vehicle.getId and vehicle:getId() or "nil"),
                tostring(part and part.getId and part:getId() or "Radio")
            )
        )
        return nil, tonumber(state and state.sourceGeneration) or 0
    end

    local existing = ctx and ctx._registryEntryByUuid or NMServerRegistryState.worldRegistry[identity.uuid]
    local canonicalGen = resolveCanonicalVehicleSourceGeneration(state, existing)
    state.sourceGeneration = canonicalGen
    local entry = NMServerVehicleIntentTargeting.buildVehicleRegistrySnapshot(
        ctx,
        vehicle,
        part,
        state,
        existing,
        identity,
        canonicalGen,
        transitionReason
    )

    NMServerRegistryState.worldRegistry[entry.uuid] = entry
    if type(ctx) == "table" then
        ctx._registryEntryByUuid = entry
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle") then
        local currentPartUuid = logVehicleSqlAnchorProof(entry, vehicle, part, state, transitionReason)
        logVehiclePartUuidStability(entry, state, transitionReason, currentPartUuid)
    end
    return entry, canonicalGen
end

function NMServerVehicleIntentTargeting.resolveTarget(player, args)
    local vehicle, part = NMServerVehicleIntentTargeting.resolveVehicleAndPart(args)
    if not vehicle or not part then
        return nil, "vehicle_or_part_missing"
    end
    local profile = NMDeviceProfiles.getVehicleProfile(part)
    if not profile then
        return nil, "vehicle_profile_missing"
    end
    local existingRegistryEntry = NMServerVehicleIntentTargeting.findRegistryEntryByVehiclePart(
        vehicle and vehicle.getId and vehicle:getId() or nil,
        part and part.getId and part:getId() or "Radio"
    )
    local state = nil
    if existingRegistryEntry then
        state = NMDeviceState.peek and NMDeviceState.peek(part) or nil
        if not state then
            NMServerVehicleIntentLogging.logRuntime(
                "identity_state_probe",
                string.format(
                    "uuid=%s hasState=false hasUuid=false source=server_vehicle_intent_existing",
                    tostring(existingRegistryEntry.uuid or "")
                )
            )
            return nil, "identity_missing_readonly"
        end
        local existingUuid = tostring(state.deviceUUID or "")
        NMServerVehicleIntentLogging.logRuntime(
            "identity_state_probe",
            string.format(
                "uuid=%s hasState=true hasUuid=%s source=server_vehicle_intent_existing",
                tostring(existingUuid ~= "" and existingUuid or existingRegistryEntry.uuid or ""),
                tostring(existingUuid ~= "")
            )
        )
        if existingUuid == "" then
            return nil, "identity_uuid_missing_readonly"
        end
        local expectedUuid = tostring(existingRegistryEntry.uuid or "")
        if expectedUuid ~= "" and expectedUuid ~= existingUuid then
            NMServerVehicleIntentLogging.logRuntime(
                "identity_conflict",
                string.format(
                    "uuid=%s observed=%s expected=%s stage=server_vehicle_intent_existing",
                    tostring(expectedUuid),
                    tostring(existingUuid),
                    tostring(expectedUuid)
                )
            )
            NMServerVehicleIntentLogging.logRuntime(
                "identity_uuid_conflict_drop",
                string.format(
                    "kind=vehicle vehicleId=%s partId=%s",
                    tostring(vehicle and vehicle.getId and vehicle:getId() or "nil"),
                    tostring(part and part.getId and part:getId() or "Radio")
                )
            )
            return nil, "identity_uuid_conflict_drop"
        end
    else
        state = NMDeviceState.ensureInitialized and NMDeviceState.ensureInitialized(part, profile, "explicit_init") or NMDeviceState.ensure(part, profile)
    end
    if not state then
        return nil, "identity_init_forbidden"
    end

    local ctx = {
        player = player,
        args = args or {},
        vehicle = vehicle,
        part = part,
        profile = profile,
        state = state,
        inventory = player and player.getInventory and player:getInventory() or nil,
        existingRegistryEntry = existingRegistryEntry
    }
    ctx._registryEntryByUuid = existingRegistryEntry and NMServerRegistryState.worldRegistry[tostring(existingRegistryEntry.uuid or "")] or nil
    resolveVehicleIdentityFields(ctx)
    buildRequestSummary(ctx)
    return ctx, nil
end

return NMServerVehicleIntentTargeting
