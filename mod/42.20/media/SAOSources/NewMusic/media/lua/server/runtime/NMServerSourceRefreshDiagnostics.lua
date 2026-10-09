NMServerSourceRefreshDiagnostics = NMServerSourceRefreshDiagnostics or {}

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

local function safeCall(fn)
    if type(pcall) ~= "function" then
        return false, nil
    end
    return pcall(fn)
end

local function formatCoord(value)
    local n = tonumber(value)
    if not n then
        return "nil"
    end
    return string.format("%.2f", n)
end

local function isSubsystemEnabled(name)
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled(name)
end

local function isAttachedRefreshDebugEnabled(mode)
    if tostring(mode or "") == "attached" or tostring(mode or "") == "stowed" then
        return isSubsystemEnabled("runtime") or isSubsystemEnabled("registry")
    end
    return isSubsystemEnabled("vehicle")
end

local function calculateMovedDistance(oldX, oldY, oldZ, newX, newY, newZ)
    local ox = tonumber(oldX)
    local oy = tonumber(oldY)
    local oz = tonumber(oldZ)
    local nx = tonumber(newX)
    local ny = tonumber(newY)
    local nz = tonumber(newZ)
    if ox == nil or oy == nil or oz == nil or nx == nil or ny == nil or nz == nil then
        return 0
    end
    local dx = nx - ox
    local dy = ny - oy
    local dz = nz - oz
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
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

local function parseRefreshSignature(signature)
    local mode, resolved, xq, yq, zq = string.match(tostring(signature or ""), "([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    return mode, resolved, tonumber(xq), tonumber(yq), tonumber(zq)
end

local function shouldLogRefreshChange(uuid, signature, mode, movedDist)
    local nowMs = nowRealMs()
    local isAttachedMode = tostring(mode or "") == "attached" or tostring(mode or "") == "stowed"
    local heartbeatMs = isAttachedMode and 30000 or 45000
    NMServerRegistryState.sourceRefreshSignature = NMServerRegistryState.sourceRefreshSignature or {}
    NMServerRegistryState.sourceRefreshLastLogMs = NMServerRegistryState.sourceRefreshLastLogMs or {}

    local prev = NMServerRegistryState.sourceRefreshSignature[uuid]
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
    return NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
        NMServerRegistryState.sourceRefreshSignature,
        NMServerRegistryState.sourceRefreshLastLogMs,
        uuid,
        signature,
        heartbeatMs
    ) == true
end

function NMServerSourceRefreshDiagnostics.logVehicleResolveAttempt(uuid, entry, result)
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

function NMServerSourceRefreshDiagnostics.logVehicleIdentitySnapshot(entry, uuid, stage, result)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.isEnabled and NMRuntimeProbeAdapter.isEnabled("vehicle", "vehicle_identity_snapshot")) then
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
    local heartbeatMs = 120000
    if signature == previousSig and (now - previousMs) < heartbeatMs then
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

function NMServerSourceRefreshDiagnostics.logRefresh(uuid, mode, oldX, oldY, oldZ, newX, newY, newZ, resolvedKind, entry, options)
    if not (NMCore and NMCore.logChannel and isAttachedRefreshDebugEnabled(mode)) then
        return
    end
    local movedDist = calculateMovedDistance(oldX, oldY, oldZ, newX, newY, newZ)
    local signature = table.concat({
        tostring(mode or ""),
        tostring(resolvedKind or ""),
        quantizeCoord(newX, 8.0),
        quantizeCoord(newY, 8.0),
        quantizeCoord(newZ, 1.0)
    }, "|")
    if not shouldLogRefreshChange(uuid, signature, mode, movedDist) then
        return
    end
    local sourceGen = tonumber(entry and (entry.sourceGeneration or entry.sourceEpoch)) or 0
    local ownerId = tostring(entry and (entry.ownerOnlineId or entry.ownerId) or "")
    local ownerName = tostring(entry and entry.ownerUsername or "")
    local emittedChannel = (tostring(mode or "") == "attached" or tostring(mode or "") == "stowed") and ((isSubsystemEnabled("registry") and "registry") or "runtime") or "vehicle"
    local immediateBroadcast = options and options.immediateBroadcast == true
    NMCore.logChannel(
        emittedChannel,
        "server_source_refresh",
        string.format(
            "uuid=%s mode=%s resolved=%s ownerId=%s ownerName=%s old=%.2f,%.2f,%.2f new=%.2f,%.2f,%.2f moved=%.2f sourceGen=%s immediateBroadcast=%s",
            tostring(uuid),
            tostring(mode),
            tostring(resolvedKind),
            tostring(ownerId ~= "" and ownerId or "nil"),
            tostring(ownerName ~= "" and ownerName or "nil"),
            tonumber(oldX) or 0,
            tonumber(oldY) or 0,
            tonumber(oldZ) or 0,
            tonumber(newX) or 0,
            tonumber(newY) or 0,
            tonumber(newZ) or 0,
            tonumber(movedDist) or 0,
            tostring(sourceGen),
            tostring(immediateBroadcast)
        )
    )
end

function NMServerSourceRefreshDiagnostics.logUnresolved(uuid, mode, reason, key)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    if NMCore.shouldLogEvery and not NMCore.shouldLogEvery("vehicleDiagnostics.source_refresh_unresolved." .. tostring(uuid), nowRealMs(), NMRuntimeProbeAdapter.shortHeartbeatMs()) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "server_source_refresh_unresolved",
        string.format("uuid=%s mode=%s reason=%s key=%s", tostring(uuid), tostring(mode), tostring(reason), tostring(key or ""))
    )
end

function NMServerSourceRefreshDiagnostics.logInvalidCoordinates(uuid, mode)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "server_source_refresh_invalid",
        string.format("uuid=%s mode=%s reason=world_active_invalid_coordinates", tostring(uuid), tostring(mode))
    )
end

function NMServerSourceRefreshDiagnostics.logVehicleRebindBroadcast(uuid, reason, entry)
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

return NMServerSourceRefreshDiagnostics

