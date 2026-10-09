-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "runtime/NMServerPlayerLookupSnapshot"
require "runtime/NMServerVehicleSqlIndexCache"

-- Server authoritative source refresh pass for moving world-active registry entries.
NMServerSourceRefreshTick = NMServerSourceRefreshTick or {}
local SourceRefreshDiagnostics = NMServerSourceRefreshDiagnostics
local VEHICLE_UNRESOLVED_RETIRE_GRACE_MS = 750
local SOURCE_REFRESH_MEMORY_LOG_INTERVAL_MS = 5000
local VEHICLE_UNRESOLVED_RETIRE_REASONS = {
    vehicle_unresolved_sql_anchor_runtime_unavailable = true,
    vehicle_unresolved_sql_anchor_part_missing = true
}
NMServerSourceRefreshTick._memoryDiag = NMServerSourceRefreshTick._memoryDiag or {
    lastLogMs = 0,
    counters = {}
}

local function asNumber(value)
    local n = tonumber(value)
    if n == nil then
        return nil
    end
    return n
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

local function refreshVehicleSqlIndex()
    NMServerVehicleSqlIndexCache.refresh()
end

local function memoryDiagEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true
end

local function countSourceRefreshDiag(name, delta)
    if memoryDiagEnabled() ~= true then
        return
    end
    local key = tostring(name or "unknown")
    local diag = NMServerSourceRefreshTick._memoryDiag
    diag.counters[key] = (tonumber(diag.counters[key]) or 0) + (tonumber(delta) or 1)
end

local function flushSourceRefreshDiag()
    if memoryDiagEnabled() ~= true or not (NMCore and NMCore.logChannel) then
        return
    end
    local diag = NMServerSourceRefreshTick._memoryDiag
    local nowMsValue = nowRealMs()
    if nowMsValue - (tonumber(diag.lastLogMs) or 0) < SOURCE_REFRESH_MEMORY_LOG_INTERVAL_MS then
        return
    end
    diag.lastLogMs = nowMsValue
    local parts = {}
    for name, count in pairs(diag.counters or {}) do
        parts[#parts + 1] = tostring(name) .. "=" .. tostring(count)
    end
    diag.counters = {}
    if #parts > 0 then
        table.sort(parts)
        NMCore.logChannel("memory", "server_source_refresh_diag", table.concat(parts, " | "))
    end
end

local function countWorldSourceInterest(entry, state)
    if memoryDiagEnabled() ~= true then
        return
    end
    local authorityMode = tostring(state and state.authoritativeMode or "unknown")
    local playbackMode = tostring(state and state.playbackMode or "unknown")
    local profileType = tostring(entry and entry.profileType or "unknown")
    countSourceRefreshDiag("world_source_interest")
    countSourceRefreshDiag("world_source_interest_authority_" .. authorityMode)
    countSourceRefreshDiag("world_source_interest_playback_" .. playbackMode)
    countSourceRefreshDiag("world_source_interest_profile_" .. profileType)
    if NMDeviceProfiles and NMDeviceProfiles.getForFullType then
        local profile = NMDeviceProfiles.getForFullType(profileType)
        local deviceType = tostring(profile and profile.deviceType or "unknown")
        countSourceRefreshDiag("world_source_interest_device_" .. deviceType)
        if NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile) == true then
            countSourceRefreshDiag("world_source_interest_portable")
        end
    end
end

local function hasRegistryEntries()
    local worldRegistry = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(worldRegistry) ~= "table" then
        return false
    end
    for _, entry in pairs(worldRegistry) do
        local state = entry and entry.stateSnapshot or nil
        if NMRegistryPolicy
            and NMRegistryPolicy.shouldKeepWorldSourceState
            and NMRegistryPolicy.shouldKeepWorldSourceState(state) == true then
            countWorldSourceInterest(entry, state)
            return true
        end
    end
    return false
end

function NMServerSourceRefreshTick.hasWorldSources()
    return hasRegistryEntries()
end

local function normalizeSourceMode(entry, profile, state)
    local authorityMode = tostring(state and state.authoritativeMode or "off")
    if authorityMode == "vehicle" then
        return "vehicle"
    end
    if authorityMode == "attached" then
        return "attached"
    end
    if authorityMode == "placed" then
        return "placed"
    end
    if authorityMode == "stowed" then
        return "stowed"
    end
    return "off"
end

local function buildPlayerMaps()
    return NMServerPlayerLookupSnapshot.build()
end

local function resolvePlayerFromOwner(entry, state, playersById, playersByName)
    local owner = tostring(state and state.sourceOwner or entry and entry.ownerId or entry and entry.ownerOnlineId or entry and entry.ownerUsername or "")
    if owner == "" then
        return nil, owner
    end
    local byId = playersById and playersById[owner] or nil
    if byId then
        return byId, owner
    end
    local byName = playersByName and playersByName[string.lower(owner)] or nil
    if byName then
        return byName, owner
    end
    return nil, owner
end

local function setVehicleIdentityState(entry, uuid, nextState, reason)
    if not entry then
        return
    end
    local currentState = tostring(entry._vehicleIdentityState or "")
    local targetState = tostring(nextState or "")
    if currentState == targetState or targetState == "" then
        entry._vehicleIdentityState = targetState ~= "" and targetState or entry._vehicleIdentityState
        return
    end
    entry._vehicleIdentityState = targetState
    NMRuntimeProbeAdapter.emit(
        "runtime",
        "runtime",
        "vehicle_identity_state_transition",
        string.format("uuid=%s from=%s to=%s reason=%s", tostring(uuid), tostring(currentState ~= "" and currentState or "nil"), tostring(targetState), tostring(reason or "none"))
    )
end

local function refreshFromAttached(entry, state, playersById, playersByName)
    local playerObj = nil
    local ownerKey = ""
    playerObj, ownerKey = resolvePlayerFromOwner(entry, state, playersById, playersByName)
    if not playerObj then
        return false, "attached_unresolved", ownerKey
    end
    local sq = playerObj.getSquare and playerObj:getSquare() or nil
    if not sq then
        return false, "attached_unresolved_square", ownerKey
    end
    entry.x = playerObj.getX and tonumber(playerObj:getX()) or sq:getX()
    entry.y = playerObj.getY and tonumber(playerObj:getY()) or sq:getY()
    entry.z = playerObj.getZ and tonumber(playerObj:getZ()) or sq:getZ()
    entry.ownerOnlineId = playerObj.getOnlineID and tostring(playerObj:getOnlineID() or "") or tostring(entry.ownerOnlineId or "")
    entry.ownerUsername = playerObj.getUsername and tostring(playerObj:getUsername() or "") or tostring(entry.ownerUsername or "")
    return true, "attached_player", ownerKey
end

local function readVehiclePartUuid(vehicle, partId)
    if not vehicle then
        return "", "vehicle_missing"
    end
    local desiredPartId = tostring(partId or "Radio")
    local part = vehicle.getPartById and vehicle:getPartById(desiredPartId) or nil
    if not part then
        return "", "part_missing"
    end
    local md = part.getModData and part:getModData() or nil
    local node = md and md[NMCore.StateKey] or nil
    local partUuid = tostring(node and node.deviceUUID or "")
    if partUuid == "" then
        return "", "part_uuid_missing"
    end
    return partUuid, "ok"
end

local function resolveVehicleIdentity(entry, state, playersById, playersByName)
    local currentUuid = tostring(state and state.deviceUUID or entry and entry.uuid or "")
    local partId = tostring(entry and entry.partId or "Radio")
    local sqlHint = tostring(entry and (entry.vehicleSqlId or entry.vehicleSqlIdHint) or "")
    local vehicleIdHint = tonumber(entry and (entry.vehicleIdHint or entry.vehicleId))
    local cachedVehicle = nil
    if vehicleIdHint and getVehicleById then
        cachedVehicle = getVehicleById(vehicleIdHint)
    end
    local ownerPlayer, ownerKey = resolvePlayerFromOwner(entry, state, playersById, playersByName)
    local ownerVehicle = ownerPlayer and ownerPlayer.getVehicle and ownerPlayer:getVehicle() or nil
    local ownerVehicleId = ownerVehicle and ownerVehicle.getId and tostring(ownerVehicle:getId() or "") or ""
    local ownerVehicleSqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(ownerVehicle) or ""

    local result = {
        resolved = false,
        vehicle = nil,
        vehicleId = "",
        vehicleSqlId = "",
        partId = partId,
        matchReason = "vehicle_unresolved",
        resolvedBy = "none",
        sourceGenerationSeen = tonumber(state and state.sourceGeneration) or tonumber(entry and entry.sourceEpoch) or 0,
        ownerKey = tostring(ownerKey or ""),
        ownerVehicleId = ownerVehicleId ~= "" and ownerVehicleId or "nil",
        ownerVehicleSqlId = ownerVehicleSqlId ~= "" and ownerVehicleSqlId or "nil",
        ownerVehicleSeen = ownerVehicle ~= nil,
        preScanReason = "sql_index",
        reasonStage = "sql_anchor_missing",
        sourceMatrixSummary = "",
        sqlHint = tostring(sqlHint ~= "" and sqlHint or "nil"),
        poolSource = "sql_index",
        totalReported = 0,
        nonNilVehicles = 0,
        indexBaseUsed = "none",
        indexBaseTried = "none",
        iteratedSlots = 0,
        nilSlots = 0,
        getErrors = 0
    }

    if sqlHint == "" then
        result.matchReason = "sql_anchor_missing"
        result.reasonStage = "sql_anchor_missing"
        return result
    end

    local indexMap = NMServerRegistryState and NMServerRegistryState.vehicleRuntimeIdBySqlId or nil
    local runtimeId = tostring(indexMap and indexMap[tostring(sqlHint)] or "")
    if runtimeId == "" then
        result.matchReason = "sql_anchor_runtime_unavailable"
        result.reasonStage = "sql_anchor_runtime_unavailable"
        result.anchorEvidence = "sql=" .. tostring(sqlHint) .. " runtimeId=nil"
        return result
    end

    local resolvedVehicle = nil
    if getVehicleById then
        resolvedVehicle = getVehicleById(tonumber(runtimeId))
    end
    if not resolvedVehicle then
        result.matchReason = "sql_anchor_runtime_unavailable"
        result.reasonStage = "sql_anchor_runtime_unavailable"
        result.anchorEvidence = "sql=" .. tostring(sqlHint) .. " runtimeId=" .. tostring(runtimeId) .. " vehicle=nil"
        return result
    end

    local observedSql = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(resolvedVehicle) or ""
    if tostring(observedSql) ~= tostring(sqlHint) then
        result.matchReason = "sql_anchor_runtime_unavailable"
        result.reasonStage = "sql_anchor_runtime_unavailable"
        result.anchorEvidence = "sql=" .. tostring(sqlHint) .. " runtimeId=" .. tostring(runtimeId) .. " observedSql=" .. tostring(observedSql ~= "" and observedSql or "nil")
        return result
    end

    local part = resolvedVehicle.getPartById and resolvedVehicle:getPartById(partId) or nil
    if not part then
        result.matchReason = "sql_anchor_part_missing"
        result.reasonStage = "sql_anchor_part_missing"
        result.anchorEvidence = "sql=" .. tostring(sqlHint) .. " partId=" .. tostring(partId)
        return result
    end

    local partUuid, partUuidState = readVehiclePartUuid(resolvedVehicle, partId)
    if partUuidState ~= "ok" or partUuid ~= currentUuid then
        result.matchReason = "sql_anchor_uuid_mismatch"
        result.reasonStage = "sql_anchor_uuid_mismatch"
        result.anchorEvidence = "sql=" .. tostring(sqlHint) .. " observedUuid=" .. tostring(partUuid ~= "" and partUuid or "nil")
        result.part = part
        return result
    end

    result.resolved = true
    result.vehicle = resolvedVehicle
    result.part = part
    result.vehicleId = tostring(resolvedVehicle:getId() or "")
    result.vehicleSqlId = tostring(observedSql or "")
    result.resolvedBy = "sql_anchor"
    result.matchReason = "resolved_sql_anchor"
    result.reasonStage = "sql_anchor_resolved"
    result.anchorEvidence = "sql=" .. tostring(sqlHint) .. " runtimeId=" .. tostring(runtimeId)
    return result
end

local function logVehicleResolveAttempt(uuid, entry, result)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    if not result then
        return
    end
    local signature = table.concat({
        tostring(result.resolved == true),
        tostring(result.resolvedBy or ""),
        tostring(result.vehicleId or ""),
        tostring(result.reasonStage or "")
    }, "|")
    if entry and entry._vehicleResolveAttemptSignature == signature then
        return
    end
    if entry then
        entry._vehicleResolveAttemptSignature = signature
    end
    NMCore.logChannel(
        "vehicle",
        "server_vehicle_resolve_attempt",
        string.format(
            "uuid=%s resolved=%s path=%s reason=%s reasonStage=%s preScan=%s cachedVehicleId=%s resolvedVehicleId=%s owner=%s ownerVehicleId=%s cachedVehicleSqlId=%s resolvedVehicleSqlId=%s ownerVehicleSqlId=%s authorityVehicleSqlId=%s cachedPartUuid=%s ownerPartUuid=%s poolSource=%s totalReported=%s nonNilVehicles=%s indexBaseUsed=%s indexBaseTried=%s iteratedSlots=%s nilSlots=%s getErrors=%s matrix=%s anchor=%s",
            tostring(uuid),
            tostring(result.resolved == true),
            tostring(result.resolvedBy or "none"),
            tostring(result.matchReason or "unknown"),
            tostring(result.reasonStage or "none"),
            tostring(result.preScanReason or "none"),
            tostring(entry and entry.vehicleId or ""),
            tostring(result.vehicleId or ""),
            tostring(result.ownerKey or ""),
            tostring(result.ownerVehicleId or "nil"),
            tostring(result.cachedVehicleSqlId or entry and entry.vehicleSqlId or ""),
            tostring(result.vehicleSqlId or ""),
            tostring(result.ownerVehicleSqlId or "nil"),
            tostring(result.authorityVehicleSqlId or ""),
            tostring(result.cachedPartUuid or ""),
            tostring(result.ownerPartUuid or ""),
            tostring(result.poolSource or "none"),
            tostring(result.totalReported or 0),
            tostring(result.nonNilVehicles or 0),
            tostring(result.indexBaseUsed or "none"),
            tostring(result.indexBaseTried or "none"),
            tostring(result.iteratedSlots or 0),
            tostring(result.nilSlots or 0),
            tostring(result.getErrors or 0),
            tostring(result.sourceMatrixSummary or ""),
            tostring(result.anchorEvidence or "anchor=none")
        )
    )
end

local function formatCoord(value)
    local n = tonumber(value)
    if not n then
        return "nil"
    end
    return string.format("%.2f", n)
end

local function quantizeCoord(value, step)
    local n = tonumber(value)
    if not n then
        return "nil"
    end
    local bucket = tonumber(step) or 1.0
    if bucket <= 0 then
        bucket = 1.0
    end
    return string.format("%.1f", math.floor((n / bucket) + 0.5) * bucket)
end

local function resolveVehicleSnapshotFields(vehicle)
    local vehicleId = NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and NMVehicleHelpers.getVehicleIdString(vehicle) or ""
    local vehicleSqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or ""
    local scriptName = NMVehicleHelpers and NMVehicleHelpers.getVehicleScriptName and NMVehicleHelpers.getVehicleScriptName(vehicle) or ""
    local x = tonumber(vehicle and vehicle.getX and vehicle:getX() or nil)
    local y = tonumber(vehicle and vehicle.getY and vehicle:getY() or nil)
    local z = tonumber(vehicle and vehicle.getZ and vehicle:getZ() or nil)
    return vehicleId, vehicleSqlId, scriptName, x, y, z
end

local function logVehicleIdentitySnapshot(entry, uuid, stage, result)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    if not entry then
        return
    end
    local now = nowRealMs()
    local resolvedVehicle = result and result.vehicle or nil
    local resolvedVehicleId, resolvedVehicleSqlId, resolvedScript, resolvedX, resolvedY, resolvedZ = resolveVehicleSnapshotFields(resolvedVehicle)

    local cachedVehicle = nil
    local cachedIdHint = tonumber(entry and (entry.vehicleIdHint or entry.vehicleId) or nil)
    if cachedIdHint and getVehicleById then
        cachedVehicle = getVehicleById(cachedIdHint)
    end
    local cachedVehicleId, cachedVehicleSqlId, cachedScript, cachedX, cachedY, cachedZ = resolveVehicleSnapshotFields(cachedVehicle)

    local sourceGen = tonumber(result and result.sourceGenerationSeen) or tonumber(entry.sourceGeneration) or tonumber(entry.sourceEpoch) or 0
    local signature = table.concat({
        tostring(result and result.resolved == true),
        tostring(result and result.reasonStage or result and result.matchReason or "none"),
        tostring(resolvedVehicleId or ""),
        tostring(resolvedVehicleSqlId or ""),
        tostring(resolvedScript or ""),
        tostring(quantizeCoord(resolvedX, 1.0)),
        tostring(quantizeCoord(resolvedY, 1.0)),
        tostring(quantizeCoord(resolvedZ, 1.0)),
        tostring(cachedVehicleId or ""),
        tostring(cachedVehicleSqlId or ""),
        tostring(cachedScript or ""),
        tostring(quantizeCoord(cachedX, 1.0)),
        tostring(quantizeCoord(cachedY, 1.0)),
        tostring(quantizeCoord(cachedZ, 1.0)),
        tostring(result and result.matchReason or "none")
    }, "|")

    local previousSig = tostring(entry._vehicleIdentitySnapshotSig or "")
    local previousMs = tonumber(entry._vehicleIdentitySnapshotMs) or 0
    if signature == previousSig and (now - previousMs) < 30000 then
        return
    end
    entry._vehicleIdentitySnapshotSig = signature
    entry._vehicleIdentitySnapshotMs = now

    NMCore.logChannel(
        "vehicle",
        "vehicle_identity_snapshot",
        string.format(
            "uuid=%s stage=%s resolved=%s reasonStage=%s reason=%s resolvedVehicleId=%s resolvedVehicleSqlId=%s resolvedScript=%s resolvedX=%s resolvedY=%s resolvedZ=%s cachedVehicleId=%s cachedVehicleSqlId=%s cachedScript=%s cachedX=%s cachedY=%s cachedZ=%s sourceGen=%s",
            tostring(uuid or ""),
            tostring(stage or ""),
            tostring(result and result.resolved == true),
            tostring(result and result.reasonStage or "none"),
            tostring(result and result.matchReason or "none"),
            tostring(resolvedVehicleId ~= "" and resolvedVehicleId or "nil"),
            tostring(resolvedVehicleSqlId ~= "" and resolvedVehicleSqlId or "nil"),
            tostring(resolvedScript ~= "" and resolvedScript or "nil"),
            formatCoord(resolvedX),
            formatCoord(resolvedY),
            formatCoord(resolvedZ),
            tostring(cachedVehicleId ~= "" and cachedVehicleId or "nil"),
            tostring(cachedVehicleSqlId ~= "" and cachedVehicleSqlId or "nil"),
            tostring(cachedScript ~= "" and cachedScript or "nil"),
            formatCoord(cachedX),
            formatCoord(cachedY),
            formatCoord(cachedZ),
            tostring(sourceGen)
        )
    )
end

local function refreshFromVehicle(entry, state, playersById, playersByName)
    local result = resolveVehicleIdentity(entry, state, playersById, playersByName)
    SourceRefreshDiagnostics.logVehicleIdentitySnapshot(entry, tostring(entry and entry.uuid or state and state.deviceUUID or ""), "refresh_attempt", result)
    local vehicle = result and result.vehicle or nil
    if not vehicle then
        local unresolvedReason = tostring(result and result.reasonStage or result and result.matchReason or "vehicle_unresolved")
        return false, "vehicle_unresolved_" .. unresolvedReason, tostring(entry and entry.vehicleId or ""), result
    end

    local oldVehicleId = tostring(entry and (entry.vehicleIdHint or entry.vehicleId) or "")
    local newVehicleId = tostring(vehicle:getId() or "")
    local newVehicleSqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or ""
    local rebind = oldVehicleId ~= "" and newVehicleId ~= "" and oldVehicleId ~= newVehicleId
    entry.sourceRebind = rebind == true
    if newVehicleId ~= "" then
        -- Only mutate identity on strict UUID+part resolution success.
        entry.vehicleId = newVehicleId
        entry.vehicleIdHint = newVehicleId
        entry.vehicleSqlId = tostring(newVehicleSqlId or entry.vehicleSqlId or "")
        entry.vehicleSqlIdHint = tostring(newVehicleSqlId or entry.vehicleSqlIdHint or entry.vehicleSqlId or "")
    end
    entry.x = tonumber(vehicle:getX()) or entry.x
    entry.y = tonumber(vehicle:getY()) or entry.y
    entry.z = tonumber(vehicle:getZ()) or entry.z
    entry.windowsOpen = NMVehicleHelpers.vehicleWindowsOpen(vehicle)
    SourceRefreshDiagnostics.logVehicleIdentitySnapshot(entry, tostring(entry and entry.uuid or state and state.deviceUUID or ""), "refresh_resolved", result)
    if rebind then
        return true, "vehicle_rebind", tostring(newVehicleId), result
    end
    return true, "vehicle_live", tostring(newVehicleId), result
end

local function broadcastEntryUpdate(entry, op, rebindReason)
    if not (entry and NMServerRegistryBroadcast and NMServerRegistryBroadcast.broadcastEntry) then
        return 0
    end
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
    local previousReason = entry.rebindReason
    if rebindReason ~= nil then
        entry.rebindReason = tostring(rebindReason)
    end
    local sent = NMServerRegistryBroadcast.broadcastEntry(
        NMServerRegistryState.worldRegistry,
        tostring(entry.uuid or ""),
        nil,
        entry.stateSnapshot,
        tostring(op or "upsert"),
        recipients,
        {
            trigger = tostring(rebindReason or "manual")
        }
    )
    entry.rebindReason = previousReason
    return tonumber(sent) or 0
end

local function shouldBroadcastAttachedMovement(entry, state, sourceMode, oldX, oldY, oldZ, newX, newY, newZ, nowMsValue)
    if tostring(sourceMode or "") ~= "attached" then
        return false
    end
    if not entry or not state then
        return false
    end
    if state.isOn ~= true or state.isPlaying ~= true then
        return false
    end
    local dx = (tonumber(newX) or 0) - (tonumber(oldX) or 0)
    local dy = (tonumber(newY) or 0) - (tonumber(oldY) or 0)
    local dz = (tonumber(newZ) or 0) - (tonumber(oldZ) or 0)
    local movedThisTick = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    if movedThisTick <= 0 then
        return false
    end

    local lastX = tonumber(entry._attachedImmediateLastSendX)
    local lastY = tonumber(entry._attachedImmediateLastSendY)
    local lastZ = tonumber(entry._attachedImmediateLastSendZ)
    local movedSinceLastSend = movedThisTick
    if lastX ~= nil and lastY ~= nil and lastZ ~= nil then
        local ddx = (tonumber(newX) or 0) - lastX
        local ddy = (tonumber(newY) or 0) - lastY
        local ddz = (tonumber(newZ) or 0) - lastZ
        movedSinceLastSend = math.sqrt((ddx * ddx) + (ddy * ddy) + (ddz * ddz))
    end

    local lastSendMs = tonumber(entry._attachedImmediateLastSendMs) or 0
    local elapsedMs = math.max(0, (tonumber(nowMsValue) or 0) - lastSendMs)
    if movedSinceLastSend >= 0.5 then
        return true
    end
    if movedSinceLastSend >= 0.1 and elapsedMs >= 125 then
        return true
    end
    return false
end

local function broadcastAttachedMovementIfNeeded(uuid, entry, state, sourceMode, oldX, oldY, oldZ, worldActive, nowMsValue)
    if not worldActive then
        return false
    end
    if not shouldBroadcastAttachedMovement(entry, state, sourceMode, oldX, oldY, oldZ, entry.x, entry.y, entry.z, nowMsValue) then
        return false
    end

    local previousGen = math.max(
        tonumber(state and state.sourceGeneration) or 0,
        tonumber(entry and entry.sourceGeneration) or 0,
        tonumber(entry and entry.sourceEpoch) or 0
    )
    state.sourceGeneration = previousGen + 1
    state.sourceKind = "player"
    state.sourceX = tonumber(entry.x) or state.sourceX
    state.sourceY = tonumber(entry.y) or state.sourceY
    state.sourceZ = tonumber(entry.z) or state.sourceZ
    entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
    entry.sourceGeneration = entry.sourceEpoch
    entry.stateSnapshot = NMDeviceState.export(state)

    local sent = 0
    if NMServerRegistryBroadcast and NMServerRegistryBroadcast.broadcastEntry then
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
        sent = tonumber(NMServerRegistryBroadcast.broadcastEntry(
            NMServerRegistryState.worldRegistry,
            tostring(uuid or ""),
            nil,
            entry.stateSnapshot,
            "upsert",
            recipients,
            {
                trigger = "attached_movement",
                heartbeatTick = 0
            }
        )) or 0
    end

    if sent > 0 then
        entry._attachedImmediateLastSendMs = tonumber(nowMsValue) or 0
        entry._attachedImmediateLastSendX = tonumber(entry.x) or 0
        entry._attachedImmediateLastSendY = tonumber(entry.y) or 0
        entry._attachedImmediateLastSendZ = tonumber(entry.z) or 0
        entry._attachedImmediateLastSendSourceGen = tonumber(entry.sourceGeneration) or 0
        return true
    end

    return false
end

local function refreshFromStateSnapshot(entry, state)
    local sx = asNumber(state and state.sourceX)
    local sy = asNumber(state and state.sourceY)
    local sz = asNumber(state and state.sourceZ)
    if sx == nil or sy == nil or sz == nil then
        return false, "snapshot_missing", ""
    end
    entry.x = sx
    entry.y = sy
    entry.z = sz
    return true, "snapshot", ""
end

local function parseRefreshSignature(signature)
    local mode, resolved, xq, yq, zq = string.match(tostring(signature or ""), "([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    return mode, resolved, tonumber(xq), tonumber(yq), tonumber(zq)
end

local function shouldLogRefreshChange(uuid, signature)
    local nowMs = nowRealMs()
    local minChangeLogMs = 15000
    local heartbeatMs = 30000
    NMServerRegistryState.sourceRefreshSignature = NMServerRegistryState.sourceRefreshSignature or {}
    NMServerRegistryState.sourceRefreshLastLogMs = NMServerRegistryState.sourceRefreshLastLogMs or {}

    local prev = NMServerRegistryState.sourceRefreshSignature[uuid]
    local prevMs = tonumber(NMServerRegistryState.sourceRefreshLastLogMs[uuid]) or 0
    if prev == nil then
        NMServerRegistryState.sourceRefreshSignature[uuid] = signature
        NMServerRegistryState.sourceRefreshLastLogMs[uuid] = nowMs
        return true
    end
    local modePrev, resolvedPrev = parseRefreshSignature(prev)
    local modeNext, resolvedNext = parseRefreshSignature(signature)
    local modeChanged = tostring(modePrev) ~= tostring(modeNext) or tostring(resolvedPrev) ~= tostring(resolvedNext)
    if modeChanged then
        NMServerRegistryState.sourceRefreshSignature[uuid] = signature
        NMServerRegistryState.sourceRefreshLastLogMs[uuid] = nowMs
        return true
    end
    local changed = prev ~= signature
    local elapsed = nowMs - prevMs
    if changed and elapsed >= minChangeLogMs then
        NMServerRegistryState.sourceRefreshSignature[uuid] = signature
        NMServerRegistryState.sourceRefreshLastLogMs[uuid] = nowMs
        return true
    end
    if elapsed >= heartbeatMs then
        NMServerRegistryState.sourceRefreshSignature[uuid] = signature
        NMServerRegistryState.sourceRefreshLastLogMs[uuid] = nowMs
        return true
    end
    if changed then
        NMServerRegistryState.sourceRefreshSignature[uuid] = signature
    end
    return false
end

local function logRefresh(uuid, mode, oldX, oldY, oldZ, newX, newY, newZ, resolvedKind)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    local signature = table.concat({
        tostring(mode or ""),
        tostring(resolvedKind or ""),
        quantizeCoord(newX, 1.0),
        quantizeCoord(newY, 1.0),
        quantizeCoord(newZ, 1.0)
    }, "|")
    if not shouldLogRefreshChange(uuid, signature) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "server_source_refresh",
        string.format(
            "uuid=%s mode=%s resolved=%s old=%.2f,%.2f,%.2f new=%.2f,%.2f,%.2f",
            tostring(uuid),
            tostring(mode),
            tostring(resolvedKind),
            tonumber(oldX) or 0,
            tonumber(oldY) or 0,
            tonumber(oldZ) or 0,
            tonumber(newX) or 0,
            tonumber(newY) or 0,
            tonumber(newZ) or 0
        )
    )
end

local function logUnresolved(uuid, mode, reason, key)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    if NMCore.shouldLogEvery and not NMCore.shouldLogEvery("vehicleDiagnostics.source_refresh_unresolved." .. tostring(uuid), nowRealMs(), 15000) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "server_source_refresh_unresolved",
        string.format("uuid=%s mode=%s reason=%s key=%s", tostring(uuid), tostring(mode), tostring(reason), tostring(key or ""))
    )
end

local function logInvalidCoordinates(uuid, mode)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "server_source_refresh_invalid",
        string.format("uuid=%s mode=%s reason=world_active_invalid_coordinates", tostring(uuid), tostring(mode))
    )
end

local function logVehicleRebindBroadcast(uuid, reason, entry)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "server_vehicle_rebind_broadcast",
        string.format(
            "uuid=%s reason=%s vehicleId=%s partId=%s sourceMode=%s sourceEpoch=%s",
            tostring(uuid),
            tostring(reason),
            tostring(entry and entry.vehicleId or ""),
            tostring(entry and entry.partId or "Radio"),
            tostring(entry and entry.sourceMode or "vehicle"),
            tostring(entry and entry.sourceEpoch or 0)
        )
    )
end

local function shouldRetireUnresolvedVehicle(reason)
    local key = tostring(reason or "")
    return VEHICLE_UNRESOLVED_RETIRE_REASONS[key] == true
end

local function broadcastRecipients(applyFn)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players or type(applyFn) ~= "function" then
        return
    end
    for i = 0, players:size() - 1 do
        local playerObj = players:get(i)
        if playerObj then
            applyFn(playerObj)
        end
    end
end

local function clearRemovedEntryState(uuid, entry)
    NMServerRegistryState.dormancySinceMinutes[uuid] = nil
    NMServerRegistryState.unresolvedNearSinceMinutes[uuid] = nil
    NMServerRegistryState.dormancyTombstones[uuid] = nil
    if NMServerRegistryState.sourceRefreshSignature then
        NMServerRegistryState.sourceRefreshSignature[uuid] = nil
    end
    if NMServerRegistryState.sourceRefreshLastLogMs then
        NMServerRegistryState.sourceRefreshLastLogMs[uuid] = nil
    end
    if NMServerRegistryState.vehicleTruthSqlProofSigByUuid then
        NMServerRegistryState.vehicleTruthSqlProofSigByUuid[uuid] = nil
    end
    if NMServerRegistryState.vehicleTruthSqlProofMsByUuid then
        NMServerRegistryState.vehicleTruthSqlProofMsByUuid[uuid] = nil
    end
    if NMServerRegistryState.vehiclePartUuidByIdentity and type(entry) == "table" then
        local identityKey = table.concat({
            tostring(uuid or ""),
            tostring(entry.vehicleSqlId or ""),
            tostring(entry.partId or "Radio")
        }, "|")
        NMServerRegistryState.vehiclePartUuidByIdentity[identityKey] = nil
    end
end

local function retireVehicleEntry(uuid, entry, reason)
    if tostring(uuid or "") == "" or type(entry) ~= "table" then
        return false
    end
    if NMServerRegistryBroadcast and NMServerRegistryBroadcast.broadcastEntry then
        NMServerRegistryBroadcast.broadcastEntry(
            NMServerRegistryState.worldRegistry,
            tostring(uuid),
            nil,
            entry.stateSnapshot,
            "remove",
            broadcastRecipients
        )
    end
    NMServerRegistryState.worldRegistry[tostring(uuid)] = nil
    clearRemovedEntryState(tostring(uuid), entry)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "server_vehicle_registry_retired",
            string.format(
                "uuid=%s vehicleId=%s vehicleSqlId=%s reason=%s",
                tostring(uuid),
                tostring(entry.vehicleId or ""),
                tostring(entry.vehicleSqlId or ""),
                tostring(reason or "unknown")
            )
        )
    end
    return true
end

function NMServerSourceRefreshTick.onTick()
    if not NMCore.isMPServerAuthority() then
        return
    end

    refreshVehicleSqlIndex()
    local playersById, playersByName = buildPlayerMaps()
    for uuid, entry in pairs(NMServerRegistryState.worldRegistry) do
        local state = entry and entry.stateSnapshot or nil
        local profileType = entry and entry.profileType or nil
        local profile = NMDeviceProfiles and profileType and NMDeviceProfiles.getForFullType(profileType) or nil
        if state and profile then
            local nowMsValue = nowRealMs()
            local oldX = tonumber(entry.x) or 0
            local oldY = tonumber(entry.y) or 0
            local oldZ = tonumber(entry.z) or 0
            local prevVehicleResolved = entry._vehicleResolved == true

            local sourceMode = normalizeSourceMode(entry, profile, state)
            countSourceRefreshDiag("refresh_source_mode_" .. tostring(sourceMode or "unknown"))
            entry.sourceMode = sourceMode
            entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
            entry.sourceGeneration = entry.sourceEpoch
            entry.ownerId = tostring(state and state.sourceOwner or entry.ownerId or "")
            entry.vehicleIdHint = tostring(entry.vehicleIdHint or entry.vehicleId or "")

            local resolved = false
            local resolvedKind = "cached"
            local key = ""
            local resolvedMeta = nil
            local shouldRetireEntry = false

            if sourceMode == "attached" then
                resolved, resolvedKind, key = refreshFromAttached(entry, state, playersById, playersByName)
            elseif sourceMode == "vehicle" then
                resolved, resolvedKind, key, resolvedMeta = refreshFromVehicle(entry, state, playersById, playersByName)
                SourceRefreshDiagnostics.logVehicleResolveAttempt(uuid, entry, resolvedMeta)
            elseif sourceMode == "stowed" then
                resolved, resolvedKind, key = refreshFromStateSnapshot(entry, state)
            end

            if not resolved and (sourceMode == "attached" or sourceMode == "vehicle") then
                entry._vehicleResolved = false
                if sourceMode == "vehicle" then
                    entry.sourceRebind = false
                    setVehicleIdentityState(entry, uuid, "DETACHED_CONTINUITY", resolvedKind)
                    entry._vehicleContinuityMode = "DETACHED_CONTINUITY"
                end
                SourceRefreshDiagnostics.logUnresolved(uuid, sourceMode, resolvedKind, key)
                if sourceMode == "vehicle" then
                    local enteringUnresolved = entry._vehicleUnresolvedSinceMs == nil
                    local unresolvedSinceMs = tonumber(entry._vehicleUnresolvedSinceMs) or nowRealMs()
                    entry._vehicleUnresolvedSinceMs = unresolvedSinceMs
                    if enteringUnresolved and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel(
                            "runtime",
                            "server_vehicle_unresolved_enter",
                            string.format("uuid=%s vehicleId=%s", tostring(uuid), tostring(entry and entry.vehicleId or ""))
                        )
                    end
                    if shouldRetireUnresolvedVehicle(resolvedKind) then
                        local unresolvedForMs = math.max(0, nowRealMs() - unresolvedSinceMs)
                        if unresolvedForMs >= VEHICLE_UNRESOLVED_RETIRE_GRACE_MS then
                            shouldRetireEntry = true
                        end
                    end
                end
            else
                local hadUnresolved = entry._vehicleUnresolvedSinceMs ~= nil
                entry._vehicleUnresolvedSinceMs = nil
                if sourceMode == "vehicle" then
                    entry._vehicleResolved = true
                    setVehicleIdentityState(entry, uuid, "LIVE_RESOLVED", resolvedKind)
                    if entry._vehicleContinuityMode ~= "LIVE_RESOLVED" and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel("runtime", "vehicle_continuity_mode_exit", string.format("uuid=%s mode=%s reason=resolved", tostring(uuid), tostring(entry._vehicleContinuityMode or "DETACHED_CONTINUITY")))
                    end
                    entry._vehicleContinuityMode = "LIVE_RESOLVED"
                    local rebindTransition = (resolvedKind == "vehicle_rebind")
                    local recoveredTransition = hadUnresolved and (prevVehicleResolved == false)
                    if hadUnresolved and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel(
                            "runtime",
                            "server_vehicle_unresolved_recovered",
                            string.format("uuid=%s vehicleId=%s", tostring(uuid), tostring(entry and entry.vehicleId or ""))
                        )
                    end
                    entry._vehicleLastResolvedMs = nowRealMs()
                    if rebindTransition or recoveredTransition then
                        -- Promote vehicle identity recovery/rebind as a strictly newer authority update.
                        local previousGen = math.max(0, tonumber(state.sourceGeneration) or 0)
                        state.sourceGeneration = previousGen + 1
                        state.sourceKind = "vehicle"
                        state.sourceX = tonumber(entry.x) or state.sourceX
                        state.sourceY = tonumber(entry.y) or state.sourceY
                        state.sourceZ = tonumber(entry.z) or state.sourceZ
                        entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
                        entry.sourceGeneration = entry.sourceEpoch
                        entry.stateSnapshot = NMDeviceState.export(state)
                        local transitionReason = rebindTransition and "vehicle_rebind" or "unresolved_recovered"
                        broadcastEntryUpdate(entry, "upsert", transitionReason)
                        SourceRefreshDiagnostics.logVehicleRebindBroadcast(
                            uuid,
                            transitionReason,
                            entry
                        )
                    end
                end
            end

            if shouldRetireEntry then
                retireVehicleEntry(uuid, entry, resolvedKind)
            else
                local worldActive = NMRegistryPolicy.shouldKeepWorldSourceState(state)
                local immediateBroadcast = false
                if worldActive and sourceMode ~= "off" then
                    local x = asNumber(entry.x)
                    local y = asNumber(entry.y)
                    local z = asNumber(entry.z)
                    if x == nil or y == nil or z == nil then
                        SourceRefreshDiagnostics.logInvalidCoordinates(uuid, sourceMode)
                    end
                end

                if worldActive then
                    immediateBroadcast = broadcastAttachedMovementIfNeeded(
                        uuid,
                        entry,
                        state,
                        sourceMode,
                        oldX,
                        oldY,
                        oldZ,
                        worldActive,
                        nowMsValue
                    )
                end

                SourceRefreshDiagnostics.logRefresh(uuid, sourceMode, oldX, oldY, oldZ, entry.x, entry.y, entry.z, resolvedKind, entry, {
                    immediateBroadcast = immediateBroadcast
                })
                NMServerRegistryState.worldRegistry[uuid] = entry
            end
        end
    end
    flushSourceRefreshDiag()
end

