-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Client cache of detached world sources populated from server registry updates.
NMClientWorldSourceCache = NMClientWorldSourceCache or {}
NMClientWorldSourceCache.entries = NMClientWorldSourceCache.entries or {}
local payloadLineageSeen = payloadLineageSeen or {}
local vehicleTruthSeen = vehicleTruthSeen or {}
local vehicleTruthMsSeen = vehicleTruthMsSeen or {}
local capabilityMatrixSeen = capabilityMatrixSeen or {}
local collectCandidateScratch = {}

local function clearArray(tbl)
    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
    return tbl
end

local function nowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    if os and os.time then
        return (tonumber(os.time()) or 0) * 1000
    end
    return 0
end

local function formatCoord(value)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    return string.format("%.2f", n)
end

local function quantizeCoord(value, step)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    local s = math.max(0.001, tonumber(step) or 1.0)
    return string.format("%.2f", math.floor((n / s) + 0.5) * s)
end

local function preserveAuthorityVehicleSql(entry)
    if type(entry) ~= "table" then
        return
    end
    local authoritySql = tostring(entry._authorityVehicleSqlIdHint or "")
    if authoritySql == "" then
        return
    end
    entry.vehicleSqlId = authoritySql
    entry.vehicleSqlIdHint = authoritySql
    entry.source = entry.source or {}
    entry.source.vehicleSqlId = authoritySql
    entry.source.vehicleSqlIdHint = authoritySql
end

local function shouldLogAttachedPayloadApply(mode)
    local sourceMode = tostring(mode or "")
    return sourceMode == "attached" or sourceMode == "stowed"
end

local function shouldLogPlaybackLossWorldSource(entry, key, signature, minIntervalMs)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.isEnabled and NMRuntimeProbeAdapter.isEnabled("runtime", "world_source_payload_apply")) then
        return false
    end
    local sigKey = tostring(key or "world_source_probe")
    entry._playbackLossProbeSig = entry._playbackLossProbeSig or {}
    entry._playbackLossProbeMs = entry._playbackLossProbeMs or {}
    local nowStamp = nowMs()
    local lastSig = tostring(entry._playbackLossProbeSig[sigKey] or "")
    local lastMs = tonumber(entry._playbackLossProbeMs[sigKey]) or 0
    local intervalMs = math.max(250, tonumber(minIntervalMs) or 1000)
    if lastSig ~= tostring(signature or "") or (nowStamp - lastMs) >= intervalMs then
        entry._playbackLossProbeSig[sigKey] = tostring(signature or "")
        entry._playbackLossProbeMs[sigKey] = nowStamp
        return true
    end
    return false
end

local function logWorldSourcePayloadApply(uuid, entry, previousSource, payload, applyTimestampMs)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.isEnabled and NMRuntimeProbeAdapter.isEnabled("runtime", "world_source_payload_apply")) then
        return
    end
    local currentSource = entry and entry.source or nil
    if not currentSource then
        return
    end
    local currentContext = tostring(currentSource.context or payload and payload.sourceMode or "unknown")
    local dx = (tonumber(currentSource.x) or 0) - (tonumber(previousSource and previousSource.x) or 0)
    local dy = (tonumber(currentSource.y) or 0) - (tonumber(previousSource and previousSource.y) or 0)
    local dz = (tonumber(currentSource.z) or 0) - (tonumber(previousSource and previousSource.z) or 0)
    local movedDist = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    local state = entry and entry.stateSnapshot or nil
    local signature = table.concat({
        tostring(currentContext),
        tostring(entry and entry.sourceGeneration or 0),
        tostring(string.format("%.2f", movedDist)),
        tostring(string.format("%.2f", tonumber(currentSource.z) or 0)),
        tostring(state and state.isPlaying == true)
    }, "|")
    if shouldLogPlaybackLossWorldSource(entry, "payload_apply." .. tostring(uuid or ""), signature, NMRuntimeProbeAdapter.longHeartbeatMs()) ~= true then
        return
    end
    NMCore.logChannel(
        "runtime",
        "world_source_payload_apply",
        string.format(
            "uuid=%s ctx=%s prev=%s,%s,%s next=%s,%s,%s moved=%.2f applyMs=%s sourceGen=%s isOn=%s isPlaying=%s media=%s",
            tostring(uuid or ""),
            tostring(currentContext),
            formatCoord(previousSource and previousSource.x),
            formatCoord(previousSource and previousSource.y),
            formatCoord(previousSource and previousSource.z),
            formatCoord(currentSource.x),
            formatCoord(currentSource.y),
            formatCoord(currentSource.z),
            tonumber(movedDist) or 0,
            tostring(applyTimestampMs or 0),
            tostring(entry and entry.sourceGeneration or 0),
            tostring(state and state.isOn == true),
            tostring(state and state.isPlaying == true),
            tostring(state and state.mediaFullType or "nil")
        )
    )
end

local function classifyPayloadApply(payload, previousSource, previousAcceptedGen)
    if payload and payload.rebindReason ~= nil and tostring(payload.rebindReason or "") ~= "" then
        return "transition_upsert"
    end
    local sourceMode = tostring(payload and payload.sourceMode or "")
    local incomingGen = tonumber(payload and (payload.sourceGeneration or payload.sourceEpoch)) or 0
    local prevX = tonumber(previousSource and previousSource.x)
    local prevY = tonumber(previousSource and previousSource.y)
    local prevZ = tonumber(previousSource and previousSource.z)
    local nextX = tonumber(payload and payload.x)
    local nextY = tonumber(payload and payload.y)
    local nextZ = tonumber(payload and payload.z)
    if sourceMode == "attached"
        and prevX ~= nil and prevY ~= nil and prevZ ~= nil
        and nextX ~= nil and nextY ~= nil and nextZ ~= nil then
        local dx = nextX - prevX
        local dy = nextY - prevY
        local dz = nextZ - prevZ
        local moved = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        if moved > 0 and incomingGen > (tonumber(previousAcceptedGen) or 0) then
            return "movement_upsert"
        end
    end
    return "heartbeat_upsert"
end

local function logAttachedPayloadApply(uuid, entry, previousSource, payload, applyTimestampMs, sessionToken, previousAcceptedGen)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.isEnabled and NMRuntimeProbeAdapter.isEnabled("runtime", "attached_payload_apply")) then
        return
    end
    local sourceMode = tostring(payload and payload.sourceMode or entry and entry.sourceMode or "")
    if not shouldLogAttachedPayloadApply(sourceMode) then
        return
    end
    local currentSource = entry and entry.source or {}
    NMCore.logChannel(
        "runtime",
        "attached_payload_apply",
        string.format(
            "uuid=%s mode=%s classification=%s prevPos=%s,%s,%s payloadPos=%s,%s,%s applyMs=%s sourceGen=%s sessionToken=%s",
            tostring(uuid or ""),
            tostring(sourceMode ~= "" and sourceMode or "nil"),
            tostring(classifyPayloadApply(payload, previousSource, previousAcceptedGen)),
            formatCoord(previousSource and previousSource.x),
            formatCoord(previousSource and previousSource.y),
            formatCoord(previousSource and previousSource.z),
            formatCoord(currentSource and currentSource.x),
            formatCoord(currentSource and currentSource.y),
            formatCoord(currentSource and currentSource.z),
            tostring(applyTimestampMs or 0),
            tostring(entry and entry.sourceGeneration or payload and (payload.sourceGeneration or payload.sourceEpoch) or 0),
            tostring(sessionToken or "nil")
        )
    )
end

local function clonePayload(payload)
    local out = {}
    for k, v in pairs(payload or {}) do
        out[k] = v
    end
    return out
end

local function buildDisplayTupleSig(sourceGeneration, stateSnapshot)
    return table.concat({
        tostring(tonumber(sourceGeneration) or 0),
        tostring(tonumber(stateSnapshot and stateSnapshot.revision) or 0),
        tostring(tonumber(stateSnapshot and stateSnapshot.playbackEpoch) or 0),
        tostring(tonumber(stateSnapshot and stateSnapshot.trackIndex) or 0),
        tostring(stateSnapshot and stateSnapshot.mediaFullType or "")
    }, "|")
end

local function invalidateVehicleWindowForDisplayChange(previousSourceGeneration, previousStateSnapshot, entry, playerNum)
    if not (entry and tostring(entry.kind or "") == "vehicle" and NMDeviceUI and NMDeviceUI.invalidateOpenVehicleWindow) then
        return false
    end
    local currentStateSnapshot = entry.stateSnapshot or nil
    local previousSig = buildDisplayTupleSig(previousSourceGeneration, previousStateSnapshot)
    local currentSig = buildDisplayTupleSig(entry.sourceGeneration, currentStateSnapshot)
    if previousSig == currentSig then
        return false
    end
    local vehicleId = tostring(entry.vehicleId or entry.vehicleIdHint or entry.source and (entry.source.vehicleId or entry.source.vehicleIdHint) or "")
    local partId = tostring(entry.partId or entry.source and entry.source.partId or "Radio")
    if vehicleId == "" then
        return false
    end
    return NMDeviceUI.invalidateOpenVehicleWindow(vehicleId, partId, tonumber(playerNum) or 0) == true
end

local function logSqlAnchorLineage(uuid, entry, path, reason)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.isEnabled and NMRuntimeProbeAdapter.isEnabled("runtime", "sql_anchor_lineage")) then
        return
    end
    local nowStamp = nowMs()
    local state = entry and entry.stateSnapshot or nil
    local isPayloadPath = tostring(path or "") == "client_upsert_payload" and tostring(reason or "") == "payload"
    local isVehicleRefreshPath = tostring(path or "") == "client_vehicle_source_refresh"
    if isPayloadPath then
        local payloadKey = table.concat({
            tostring(uuid or ""),
            tostring(entry and entry.sourceGeneration or 0),
            tostring(state and state.revision or 0),
            tostring(state and state.playbackEpoch or 0)
        }, "|")
        local payloadLastMs = tonumber(payloadLineageSeen[payloadKey]) or 0
        if payloadLastMs > 0 and (nowStamp - payloadLastMs) < 120000 then
            return
        end
        payloadLineageSeen[payloadKey] = nowStamp
    end
    local sigParts = {
        tostring(path or "unknown"),
        tostring(reason or "none"),
        tostring(entry and entry.sourceGeneration or 0),
        tostring(entry and entry.vehicleSqlId or ""),
        tostring(entry and entry.vehicleSqlIdHint or ""),
        tostring(entry and entry.vehicleIdHint or "")
    }
    if not isVehicleRefreshPath then
        sigParts[#sigParts + 1] = tostring(state and state.revision or 0)
        sigParts[#sigParts + 1] = tostring(state and state.playbackEpoch or 0)
    end
    local sig = table.concat(sigParts, "|")
    local key = tostring(path or "unknown")
    entry._lineageSigByPath = entry._lineageSigByPath or {}
    entry._lineageMsByPath = entry._lineageMsByPath or {}
    local lastSig = tostring(entry._lineageSigByPath[key] or "")
    local lastMs = tonumber(entry._lineageMsByPath[key]) or 0
    local cooldownMs = isPayloadPath and 120000 or (isVehicleRefreshPath and 60000 or 20000)
    if lastSig == sig and (nowStamp - lastMs) < cooldownMs then
        return
    end
    if isPayloadPath and lastMs > 0 and (nowStamp - lastMs) < cooldownMs then
        return
    end
    entry._lineageSigByPath[key] = sig
    entry._lineageMsByPath[key] = nowStamp
    NMRuntimeProbeAdapter.emit(
        "runtime",
        "runtime",
        "sql_anchor_lineage",
        string.format(
            "uuid=%s sourceGen=%s revision=%s playbackEpoch=%s vehicleSqlId=%s vehicleSqlIdHint=%s runtimeVehicleIdHint=%s path=%s reason=%s",
            tostring(uuid or ""),
            tostring(entry and entry.sourceGeneration or 0),
            tostring(state and state.revision or 0),
            tostring(state and state.playbackEpoch or 0),
            tostring(entry and entry.vehicleSqlId or ""),
            tostring(entry and entry.vehicleSqlIdHint or ""),
            tostring(entry and entry.vehicleIdHint or ""),
            tostring(path or "unknown"),
            tostring(reason or "none")
        )
    )
end

local function encodeCandidatePool(candidates)
    local parts = {}
    local cap = math.min(#(candidates or {}), 12)
    for i = 1, cap do
        local c = candidates[i] or {}
        local distance = tonumber(c.distance)
        if distance == nil and tonumber(c.distSq) ~= nil then
            distance = math.sqrt(math.max(0, tonumber(c.distSq) or 0))
        end
        parts[#parts + 1] = string.format(
            "{runtimeId=%s,sqlId=%s,scriptName=%s,source=%s,distance=%s}",
            tostring(c.runtimeId or ""),
            tostring(c.sqlId or ""),
            tostring(c.scriptName or ""),
            tostring(c.source or ""),
            tostring(distance ~= nil and string.format("%.2f", distance) or "nil")
        )
    end
    return table.concat(parts, ";")
end

local function candidateHash(candidates)
    local parts = {}
    local cap = math.min(#(candidates or {}), 12)
    for i = 1, cap do
        local c = candidates[i] or {}
        parts[#parts + 1] = table.concat({
            tostring(c.runtimeId or ""),
            tostring(c.sqlId or ""),
            tostring(c.scriptName or "")
        }, "|")
    end
    return table.concat(parts, ";")
end

local function encodeIdList(list)
    return table.concat(list or {}, ",")
end

local function truthToken(entry)
    local s = entry and entry.stateSnapshot or nil
    return table.concat({
        tostring(entry and entry.uuid or ""),
        tostring(entry and entry.sourceGeneration or 0),
        tostring(s and s.revision or 0),
        tostring(s and s.playbackEpoch or 0)
    }, "|")
end

local function logVehicleTruth(probeName, entry, reason, detail, extraSig, ttlMs)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    local token = truthToken(entry)
    local sig = table.concat({
        tostring(probeName or ""),
        tostring(entry and entry.uuid or ""),
        tostring(token),
        tostring(reason or ""),
        tostring(extraSig or "")
    }, "|")
    local now = nowMs()
    local ttl = tonumber(ttlMs) or 20000
    NMVehicleTruthProbeAdapter.emit(
        vehicleTruthSeen,
        vehicleTruthMsSeen,
        tostring(entry and entry.uuid or "") .. ":" .. tostring(probeName or "vehicle_truth"),
        sig,
        ttl,
        function()
            NMCore.logChannel(
                "vehicle",
                tostring(probeName or "vehicle_truth"),
                string.format(
                    "traceToken=%s sessionToken=%s reason=%s %s",
                    tostring(token),
                    tostring(entry and entry._lastSessionToken or "nil"),
                    tostring(reason or "none"),
                    tostring(detail or "")
                )
            )
        end
    )
end

local function logVehicleCapabilityMatrix(entry, update)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    local state = entry and entry.stateSnapshot or {}
    local source = entry and entry.source or {}
    local candidateRuntimeIds = encodeIdList(update and update.candidateRuntimeIds or {})
    local candidateSqlIds = encodeIdList(update and update.candidateSqlIds or {})
    local attachStatus = tostring(update and update.attachStatus or "unknown")
    local sig = table.concat({
        tostring(entry and entry.uuid or ""),
        tostring(entry and entry.sourceGeneration or 0),
        tostring(state and state.revision or 0),
        tostring(state and state.playbackEpoch or 0),
        tostring(entry and entry._authorityVehicleIdHint or entry and entry.vehicleIdHint or ""),
        tostring(update and update.attachedRuntimeId or ""),
        tostring(candidateRuntimeIds),
        tostring(candidateSqlIds),
        tostring(attachStatus)
    }, "|")
    local key = tostring(entry and entry.uuid or "")
    local now = nowMs()
    local lastSig = tostring(capabilityMatrixSeen[key .. ".sig"] or "")
    local lastMs = tonumber(capabilityMatrixSeen[key .. ".ms"]) or 0
    if sig == lastSig and (now - lastMs) < 20000 then
        return
    end
    capabilityMatrixSeen[key .. ".sig"] = sig
    capabilityMatrixSeen[key .. ".ms"] = now
    NMCore.logChannel(
        "vehicle",
        "vehicle_id_capability_matrix",
        string.format(
            "traceToken=%s sessionToken=%s uuid=%s sourceGen=%s revision=%s playbackEpoch=%s runtimeVehicleIdHint=%s attachedRuntimeId=%s partId=%s sourceX=%.2f sourceY=%.2f sourceZ=%.2f candidateRuntimeIds=%s candidateSqlIds=%s attachStatus=%s",
            tostring(truthToken(entry)),
            tostring(entry and entry._lastSessionToken or "nil"),
            tostring(entry and entry.uuid or ""),
            tostring(entry and entry.sourceGeneration or 0),
            tostring(state and state.revision or 0),
            tostring(state and state.playbackEpoch or 0),
            tostring(entry and entry._authorityVehicleIdHint or entry and entry.vehicleIdHint or ""),
            tostring(update and update.attachedRuntimeId or ""),
            tostring(entry and entry.partId or "Radio"),
            tonumber(source and source.x) or 0,
            tonumber(source and source.y) or 0,
            tonumber(source and source.z) or 0,
            tostring(candidateRuntimeIds),
            tostring(candidateSqlIds),
            tostring(attachStatus)
        )
    )
end

function NMClientWorldSourceCache.get(uuid)
    return NMClientWorldSourceCache.entries[tostring(uuid or "")]
end

function NMClientWorldSourceCache.remove(uuid)
    local key = tostring(uuid or "")
    if key == "" then return end
    NMClientWorldSourceCache.entries[key] = nil
end

function NMClientWorldSourceCache.upsertFromPayload(payload, serverSessionToken)
    if not payload then return nil end
    local uuid = tostring(payload.uuid or "")
    if uuid == "" then return nil end

    local entry = NMClientWorldSourceCache.entries[uuid] or {}
    local previousSource = entry.source and clonePayload(entry.source) or nil
    local previousStateSnapshot = entry.stateSnapshot and clonePayload(entry.stateSnapshot) or nil
    local previousSourceGeneration = tonumber(entry.sourceGeneration) or tonumber(entry.stateSnapshot and entry.stateSnapshot.sourceGeneration) or 0
    local previousAcceptedGen = math.max(
        tonumber(entry._acceptedSourceGeneration) or 0,
        tonumber(entry.sourceEpoch) or 0,
        tonumber(entry.stateSnapshot and entry.stateSnapshot.sourceGeneration) or 0
    )
    local incomingSourceEpoch = tonumber(payload.sourceEpoch) or tonumber(payload.sourceGeneration) or 0
    local incomingSourceGeneration = tonumber(payload.sourceGeneration) or incomingSourceEpoch
    local incomingVehicleId = tostring(payload.vehicleId or "")
    local incomingVehicleIdHint = tostring(payload.vehicleIdHint or incomingVehicleId or "")
    local incomingVehicleSqlId = tostring(payload.vehicleSqlId or "")
    local incomingVehicleSqlIdHint = tostring(payload.vehicleSqlIdHint or incomingVehicleSqlId or "")
    local hasIncomingSqlAnchor = incomingVehicleSqlId ~= "" or incomingVehicleSqlIdHint ~= ""
    local incomingOwnerOnlineId = tostring(payload.ownerOnlineId or "")
    local incomingOwnerUsername = tostring(payload.ownerUsername or "")
    local incomingOwnerId = tostring(payload.ownerId or incomingOwnerOnlineId or incomingOwnerUsername or "")
    local incomingPartId = tostring(payload.partId or entry.partId or "Radio")
    local incomingSourceMode = tostring(payload.sourceMode or (entry.kind == "vehicle" and "vehicle" or "placed"))
    local incomingRebindReason = payload.rebindReason ~= nil and tostring(payload.rebindReason or "") or ""
    local hasRebindTransition = incomingRebindReason ~= ""
    entry.uuid = uuid
    entry.kind = tostring(payload.kind or "item")
    entry.profileType = payload.profileType
    entry.stateSnapshot = payload.state
    local canReplaceIdentityAnchor = incomingSourceEpoch > previousAcceptedGen or hasRebindTransition
    local priorVehicleSqlId = tostring(entry.vehicleSqlId or "")
    local priorVehicleSqlIdHint = tostring(entry.vehicleSqlIdHint or "")
    entry.vehicleIdHint = incomingVehicleIdHint ~= "" and incomingVehicleIdHint or tostring(entry.vehicleIdHint or "")
    if incomingVehicleSqlIdHint ~= "" then
        if canReplaceIdentityAnchor or priorVehicleSqlIdHint == "" then
            entry.vehicleSqlIdHint = incomingVehicleSqlIdHint
        else
            entry.vehicleSqlIdHint = priorVehicleSqlIdHint
        end
    else
        entry.vehicleSqlIdHint = priorVehicleSqlIdHint
    end
    entry.ownerId = incomingOwnerId ~= "" and incomingOwnerId or tostring(entry.ownerId or entry.ownerOnlineId or entry.ownerUsername or "")
    entry.ownerOnlineId = incomingOwnerOnlineId ~= "" and incomingOwnerOnlineId or tostring(entry.ownerOnlineId or "")
    entry.ownerUsername = incomingOwnerUsername ~= "" and incomingOwnerUsername or tostring(entry.ownerUsername or "")
    entry.sourceGeneration = math.max(tonumber(entry.sourceGeneration) or 0, incomingSourceGeneration)
    local mergedVehicleId = tostring(entry.vehicleId or "")
    if mergedVehicleId == "" and hasIncomingSqlAnchor then
        mergedVehicleId = incomingVehicleId
    elseif incomingVehicleId ~= "" then
        if hasIncomingSqlAnchor and (incomingSourceEpoch > previousAcceptedGen or hasRebindTransition) then
            mergedVehicleId = incomingVehicleId
        end
    end
    local incomingResolvedFlag = payload.vehicleResolved == true
    local sourceVehicleSqlId = incomingVehicleSqlId ~= "" and incomingVehicleSqlId or priorVehicleSqlId
    local sourceVehicleSqlIdHint = incomingVehicleSqlIdHint ~= "" and incomingVehicleSqlIdHint or priorVehicleSqlIdHint
    if not canReplaceIdentityAnchor and priorVehicleSqlId ~= "" then
        sourceVehicleSqlId = priorVehicleSqlId
        sourceVehicleSqlIdHint = priorVehicleSqlIdHint ~= "" and priorVehicleSqlIdHint or priorVehicleSqlId
    end
    entry.source = {
        mode = "world",
        context = incomingSourceMode,
        x = tonumber(payload.x) or 0,
        y = tonumber(payload.y) or 0,
        z = tonumber(payload.z) or 0,
        vehicleId = mergedVehicleId ~= "" and mergedVehicleId or (hasIncomingSqlAnchor and incomingVehicleId or ""),
        vehicleIdHint = incomingVehicleIdHint ~= "" and incomingVehicleIdHint or tostring(entry.vehicleIdHint or ""),
        vehicleSqlId = sourceVehicleSqlId,
        vehicleSqlIdHint = sourceVehicleSqlIdHint,
        ownerId = incomingOwnerId ~= "" and incomingOwnerId or tostring(entry.ownerId or ""),
        ownerOnlineId = incomingOwnerOnlineId ~= "" and incomingOwnerOnlineId or tostring(entry.ownerOnlineId or ""),
        ownerUsername = incomingOwnerUsername ~= "" and incomingOwnerUsername or tostring(entry.ownerUsername or ""),
        windowsOpen = payload.windowsOpen == true,
        _vehicleResolved = incomingResolvedFlag
    }
    entry.itemId = payload.itemId
    entry.itemFullType = payload.itemFullType
    entry.vehicleId = mergedVehicleId ~= "" and mergedVehicleId or (hasIncomingSqlAnchor and incomingVehicleId or "")
    if incomingVehicleSqlId ~= "" then
        if canReplaceIdentityAnchor or priorVehicleSqlId == "" then
            entry.vehicleSqlId = incomingVehicleSqlId
        else
            entry.vehicleSqlId = priorVehicleSqlId
        end
    else
        entry.vehicleSqlId = priorVehicleSqlId
    end
    entry.partId = incomingPartId
    entry.sourceEpoch = incomingSourceEpoch
    entry.sourceGeneration = math.max(tonumber(entry.sourceGeneration) or 0, incomingSourceGeneration, incomingSourceEpoch)
    entry.sourceMode = incomingSourceMode
    entry.rebindReason = hasRebindTransition and incomingRebindReason or nil
    entry._authorityVehicleIdHint = incomingVehicleIdHint ~= "" and incomingVehicleIdHint or entry._authorityVehicleIdHint
    entry._authorityVehicleSqlIdHint = incomingVehicleSqlIdHint ~= "" and incomingVehicleSqlIdHint or entry._authorityVehicleSqlIdHint
    entry._authorityPartIdHint = incomingPartId ~= "" and incomingPartId or entry._authorityPartIdHint
    entry._authorityOwnerIdHint = incomingOwnerId ~= "" and incomingOwnerId or entry._authorityOwnerIdHint
    entry._authorityRebindReason = hasRebindTransition and incomingRebindReason or nil
    entry._authorityRebindEpoch = hasRebindTransition and incomingSourceGeneration or tonumber(entry._authorityRebindEpoch) or 0
    local resolvedSessionToken = tostring(serverSessionToken or payload and payload.serverSessionToken or entry._lastSessionToken or "")
    entry._lastSessionToken = resolvedSessionToken
    local stickySql = tostring(entry._stickyLastResolvedVehicleSqlId or "")
    local incomingSql = tostring(entry.vehicleSqlId or "")
    if stickySql ~= "" and incomingSql ~= "" and stickySql ~= incomingSql then
        entry._stickySqlBindingActive = false
        entry._stickyLastResolvedVehicleId = nil
        entry._stickyLastResolvedVehicleSqlId = ""
        entry._stickyLastResolvedPartId = ""
        entry._stickyLastResolvedAtMs = 0
        entry._stickySqlBindingAtMs = 0
    end
    if tostring(entry.kind or "") == "vehicle" then
        local continuityState = tostring(entry._vehicleIdentityState or "")
        if continuityState == "" then
            continuityState = (entry.source and entry.source._vehicleResolved == false) and "DETACHED_CONTINUITY" or "LIVE_RESOLVED"
        end
        entry._vehicleIdentityState = continuityState
        preserveAuthorityVehicleSql(entry)
    end
    entry._acceptedSourceGeneration = math.max(
        tonumber(entry._acceptedSourceGeneration) or 0,
        tonumber(entry.sourceGeneration) or 0,
        tonumber(entry.sourceEpoch) or 0,
        tonumber(entry.stateSnapshot and entry.stateSnapshot.sourceGeneration) or 0
    )
    local appliedAtMs = nowMs()
    entry.lastSeenRealMs = appliedAtMs
    entry._lastPayloadApplyMs = appliedAtMs
    NMClientWorldSourceCache.entries[uuid] = entry
    if tostring(entry.kind or "") == "vehicle"
        and NMClientVehicleSqlSnapshotResolver
        and NMClientVehicleSqlSnapshotResolver.markDirty then
        NMClientVehicleSqlSnapshotResolver.markDirty("vehicle_authority_upsert")
    end
    logSqlAnchorLineage(uuid, entry, "client_upsert_payload", tostring(payload and payload.rebindReason or "payload"))
    logAttachedPayloadApply(uuid, entry, previousSource, payload, appliedAtMs, resolvedSessionToken, previousAcceptedGen)
    logWorldSourcePayloadApply(uuid, entry, previousSource, payload, appliedAtMs)
    invalidateVehicleWindowForDisplayChange(previousSourceGeneration, previousStateSnapshot, entry, 0)
    return entry
end

function NMClientWorldSourceCache.refreshVehicleSource(uuid)
    local key = tostring(uuid or "")
    if key == "" then return nil end
    local entry = NMClientWorldSourceCache.entries[key]
    if not entry or tostring(entry.kind or "") ~= "vehicle" then
        return entry
    end

    local update = NMClientVehicleSourceUpdater and NMClientVehicleSourceUpdater.update and NMClientVehicleSourceUpdater.update(entry) or nil
    if not update then
        return entry
    end
    entry = update.entry or entry
    local source = update.source or entry.source or {}
    local result = update.result or {}
    local resolved = update.resolved == true
    local resolutionMode = tostring(update.resolutionMode or "stream_authority_unresolved")
    local resolutionReason = tostring(update.resolutionReason or (result and (result.reason or result.stage or result.matchReason)) or "stream_authority_unresolved")
    local prevX = tonumber(update.prevX) or 0
    local prevY = tonumber(update.prevY) or 0
    local prevZ = tonumber(update.prevZ) or 0
    local nx = tonumber(update.nx) or prevX
    local ny = tonumber(update.ny) or prevY
    local nz = tonumber(update.nz) or prevZ
    local movedDist = tonumber(update.movedDist) or 0
    local degraded = update.degraded == true
    local attachStatus = tostring(update.attachStatus or (resolved and "attached" or "degraded"))
    local snapshotMeta = update.snapshotMeta or nil
    local lastResolved = entry._lastRefreshResolved
    local resolvedChanged = (lastResolved == nil) or (lastResolved ~= resolved)
    entry._lastRefreshResolved = resolved
    entry._vehicleSourceResolved = resolved == true
    entry._vehicleResolutionMode = resolutionMode
    preserveAuthorityVehicleSql(entry)
    if tostring(entry.kind or "") == "vehicle" then
        local nextState = source and source._vehicleResolved == true and "LIVE_RESOLVED" or "DETACHED_CONTINUITY"
        local prevState = tostring(entry._vehicleIdentityState or "")
        if prevState ~= nextState then
            entry._vehicleIdentityState = nextState
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                NMCore.logChannel(
                    "runtime",
                    "vehicle_identity_state_transition",
                    string.format(
                        "uuid=%s from=%s to=%s reason=%s",
                        tostring(key),
                        tostring(prevState ~= "" and prevState or "nil"),
                        tostring(nextState),
                        tostring(resolutionMode)
                    )
                )
            end
        end
    end
    if resolvedChanged then
        entry._vehicleResolutionEpoch = (tonumber(entry._vehicleResolutionEpoch) or 0) + 1
        if resolved then
            entry._vehicleLastResolvedMs = nowMs()
        else
            entry._vehicleLastUnresolvedMs = nowMs()
        end
        logVehicleTruth(
            "vehicle_truth_resolve_decision",
            entry,
            tostring(resolutionReason),
            string.format("decision=%s mode=%s", tostring(resolved and "resolved_attachment" or "unresolved_degraded"), tostring(resolutionMode)),
            tostring(resolved) .. "|" .. tostring(resolutionMode),
            0
        )
    end

    local vehicleResolveDebugEnabled = NMCore
        and NMCore.logChannel
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled("vehicle")
    local vehicleResolveTraceEnabled = NMCore
        and NMCore.logChannel
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled("vehicle_trace")
    if vehicleResolveDebugEnabled or vehicleResolveTraceEnabled then
        local resolvedVehicleId = tostring(update and update.attachedRuntimeId or source.vehicleId or entry.vehicleId or "nil")
        local attemptSig = string.format(
            "%s|%s|%s|%s",
            tostring(resolved),
            tostring(resolutionMode),
            tostring(resolvedVehicleId),
            tostring(attachStatus)
        )
        if tostring(entry._vehicleResolveAttemptSig or "") ~= attemptSig then
            entry._vehicleResolveAttemptSig = attemptSig
            NMCore.logChannel(
                vehicleResolveDebugEnabled and "vehicle" or "vehicle_trace",
                "vehicle_resolve_attempt",
                string.format(
                    "uuid=%s resolved=%s mode=%s reason=%s vehicleId=%s vehicleSqlId=%s sourceGen=%s degraded=%s attachStatus=%s candidateSource=%s partMatch=%s partUuid=%s",
                    tostring(key),
                    tostring(resolved),
                    tostring(resolutionMode),
                    tostring(resolutionReason),
                    tostring(resolvedVehicleId),
                    tostring(entry.vehicleSqlId or "nil"),
                    tostring(entry.sourceGeneration or 0),
                    tostring(degraded),
                    tostring(attachStatus),
                    tostring(result and result.candidateSource or ""),
                    tostring(result and result.partMatches == true),
                    tostring(result and result.partUuid or "")
                )
            )
        end
    end

    local vehicleDebugEnabled = NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")
    local vehicleTraceEnabled = NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace")
    if vehicleDebugEnabled or vehicleTraceEnabled then
        entry._vehicleSourceRefreshSig = entry._vehicleSourceRefreshSig or {}
        entry._vehicleSourceRefreshMs = entry._vehicleSourceRefreshMs or {}
        local statusSig = table.concat({ tostring(resolved), tostring(resolutionMode), tostring(resolutionReason) }, "|")
        local previousStatusSig = tostring(entry._vehicleSourceRefreshStatusSig or "")
        local statusChanged = previousStatusSig ~= statusSig
        local traceMovement = vehicleTraceEnabled == true
            and NMRuntimeProbeAdapter
            and NMRuntimeProbeAdapter.shouldEmitBucketedTransitionOrHeartbeat
            and NMRuntimeProbeAdapter.shouldEmitBucketedTransitionOrHeartbeat(
                entry._vehicleSourceRefreshSig,
                entry._vehicleSourceRefreshMs,
                tostring(key),
                {
                    parts = {
                        tostring(resolved),
                        tostring(resolutionMode),
                        tostring(source.vehicleId or entry.vehicleId or "nil"),
                        tostring(degraded)
                    },
                    x = nx,
                    y = ny,
                    z = nz,
                    coordStep = 8.0,
                    zStep = 1.0,
                    intervalMs = NMRuntimeProbeAdapter.longHeartbeatMs()
                }
            )
        entry._vehicleSourceRefreshStatusSig = statusSig
        local shouldLog = degraded
            or resolved ~= true
            or statusChanged
            or traceMovement
        if shouldLog then
            NMCore.logChannel(
                    vehicleTraceEnabled and "vehicle_trace" or "vehicle",
                    "vehicle_source_refresh",
                    string.format(
                    "uuid=%s resolved=%s mode=%s old=%.2f,%.2f,%.2f new=%.2f,%.2f,%.2f vehicleId=%s degraded=%s",
                    key,
                    tostring(resolved),
                    tostring(resolutionMode),
                    prevX, prevY, prevZ,
                    nx, ny, nz,
                    tostring(source.vehicleId or entry.vehicleId or "nil"),
                    tostring(degraded)
                )
            )
        end
        entry._probeSigStoreStatus = entry._probeSigStoreStatus or {}
        entry._probeMsStoreStatus = entry._probeMsStoreStatus or {}
        local statusKey = "vehicleSourceResolutionStatus." .. tostring(key)
        if vehicleDebugEnabled and NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
            entry._probeSigStoreStatus,
            entry._probeMsStoreStatus,
            statusKey,
            statusSig,
            60000
        ) then
            NMCore.logChannel(
                "vehicle",
                "vehicle_source_resolution_status",
                string.format(
                    "uuid=%s status=%s mode=%s used_for_routing=false reason=%s",
                    tostring(key),
                    tostring(resolved and "resolved" or "unresolved"),
                    tostring(resolutionMode),
                    tostring(resolutionReason)
                )
            )
            if not resolved then
                local candidates = result and result.candidates or {}
                local traceState = entry and entry.stateSnapshot or nil
                logVehicleTruth(
                    "vehicle_truth_unresolved_evidence",
                    entry,
                    tostring(resolutionReason),
                    string.format(
                        "uuid=%s wantedSql=%s sourceGen=%s revision=%s playbackEpoch=%s partId=%s attachStatus=%s observedCandidates=%s",
                        tostring(key),
                        tostring(entry.vehicleSqlId or entry.vehicleSqlIdHint or ""),
                        tostring(entry and entry.sourceGeneration or 0),
                        tostring(traceState and traceState.revision or 0),
                        tostring(traceState and traceState.playbackEpoch or 0),
                        tostring(entry and entry.partId or ""),
                        tostring(attachStatus),
                        tostring(encodeCandidatePool(candidates))
                    ),
                    candidateHash(candidates),
                    20000
                )
                entry._probeSigStoreSnapshot = entry._probeSigStoreSnapshot or {}
                entry._probeMsStoreSnapshot = entry._probeMsStoreSnapshot or {}
                local snapshotSig = table.concat({ tostring(entry.sourceGeneration or 0), tostring(resolutionReason), tostring(attachStatus) }, "|")
                local snapshotKey = "sqlAnchorSnapshot." .. tostring(key)
                local shouldSnapshot = NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
                    entry._probeSigStoreSnapshot,
                    entry._probeMsStoreSnapshot,
                    snapshotKey,
                    snapshotSig,
                    20000
                )
                if shouldSnapshot then
                    NMCore.logChannel(
                        "runtime",
                        "sql_anchor_candidate_pool_snapshot",
                        string.format(
                            "uuid=%s sourceGen=%s playbackEpoch=%s wantedSql=%s reason=%s attachStatus=%s candidateCount=%d sourceSqlCell=%s sourceSqlWorldCell=%s sourceSqlSquare=%s sourceSqlFinal=%s candidates=%s",
                            tostring(key),
                            tostring(entry.sourceGeneration or 0),
                            tostring(entry.stateSnapshot and entry.stateSnapshot.playbackEpoch or 0),
                            tostring(entry.vehicleSqlId or entry.vehicleSqlIdHint or ""),
                            tostring(resolutionReason),
                            tostring(attachStatus),
                            tonumber(#candidates) or 0,
                            tostring(snapshotMeta and snapshotMeta.sourceSqlCell or ""),
                            tostring(snapshotMeta and snapshotMeta.sourceSqlWorldCell or ""),
                            tostring(snapshotMeta and snapshotMeta.sourceSqlSquare or ""),
                            tostring(snapshotMeta and snapshotMeta.sourceSqlFinal or ""),
                            tostring(encodeCandidatePool(candidates))
                        )
                    )
                end
            end
            local hasSnapshotBuild = snapshotMeta and tonumber(snapshotMeta.builtAtMs) and tonumber(snapshotMeta.builtAtMs) > 0
            if hasSnapshotBuild and NMCore and NMCore.logChannel then
                local snapshotSig = table.concat({
                    tostring(snapshotMeta.builtAtMs or 0),
                    tostring(snapshotMeta.entryCount or 0),
                    tostring(snapshotMeta.poolSource or "none"),
                    tostring(snapshotMeta.cellCount or 0),
                    tostring(snapshotMeta.worldCellCount or 0),
                    tostring(snapshotMeta.squareScanCount or 0),
                    tostring(snapshotMeta.finalCount or 0),
                    tostring(snapshotMeta.sourceSqlCell or ""),
                    tostring(snapshotMeta.sourceSqlWorldCell or ""),
                    tostring(snapshotMeta.sourceSqlSquare or ""),
                    tostring(snapshotMeta.sourceSqlFinal or "")
                }, "|")
                entry._probeSigStoreResolver = entry._probeSigStoreResolver or {}
                entry._probeMsStoreResolver = entry._probeMsStoreResolver or {}
                local snapshotStateKey = "resolverSnapshotState." .. tostring(key)
                if NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
                    entry._probeSigStoreResolver,
                    entry._probeMsStoreResolver,
                    snapshotStateKey,
                    snapshotSig,
                    60000
                ) then
                    NMCore.logChannel(
                        "runtime",
                        "resolver_snapshot_state",
                        string.format(
                            "uuid=%s builtAtMs=%s ageMs=%s entryCount=%s poolSource=%s cellCount=%s worldCellCount=%s squareScanCount=%s finalCount=%s sourceSqlCell=%s sourceSqlWorldCell=%s sourceSqlSquare=%s sourceSqlFinal=%s",
                            tostring(key),
                            tostring(snapshotMeta.builtAtMs or 0),
                            tostring(snapshotMeta.ageMs or 0),
                            tostring(snapshotMeta.entryCount or 0),
                            tostring(snapshotMeta.poolSource or "none"),
                            tostring(snapshotMeta.cellCount or 0),
                            tostring(snapshotMeta.worldCellCount or 0),
                            tostring(snapshotMeta.squareScanCount or 0),
                            tostring(snapshotMeta.finalCount or 0),
                            tostring(snapshotMeta.sourceSqlCell or ""),
                            tostring(snapshotMeta.sourceSqlWorldCell or ""),
                            tostring(snapshotMeta.sourceSqlSquare or ""),
                            tostring(snapshotMeta.sourceSqlFinal or "")
                        )
                    )
                end
                logVehicleTruth(
                    "vehicle_truth_snapshot_build",
                    entry,
                    "snapshot_state",
                    string.format(
                        "builtAtMs=%s ageMs=%s cellCount=%s worldCellCount=%s squareScanCount=%s finalCount=%s poolSource=%s",
                        tostring(snapshotMeta.builtAtMs or 0),
                        tostring(snapshotMeta.ageMs or 0),
                        tostring(snapshotMeta.cellCount or 0),
                        tostring(snapshotMeta.worldCellCount or 0),
                        tostring(snapshotMeta.squareScanCount or 0),
                        tostring(snapshotMeta.finalCount or 0),
                        tostring(snapshotMeta.poolSource or "none")
                    ),
                    table.concat({
                        tostring(snapshotMeta.cellCount or 0),
                        tostring(snapshotMeta.worldCellCount or 0),
                        tostring(snapshotMeta.squareScanCount or 0),
                        tostring(snapshotMeta.finalCount or 0),
                        tostring(snapshotMeta.poolSource or "none")
                    }, "|"),
                    20000
                )
            end
        end
    end

    logVehicleCapabilityMatrix(entry, update)
    logSqlAnchorLineage(key, entry, "client_vehicle_source_refresh", resolutionReason)
    NMClientWorldSourceCache.entries[key] = entry
    return entry
end

function NMClientWorldSourceCache.onRegistryUpdate(op, payload, serverSessionToken)
    local opName = tostring(op or "")
    if opName == "remove" then
        NMClientWorldSourceCache.remove(payload and payload.uuid)
        return nil
    end
    if opName == "upsert" then
        return NMClientWorldSourceCache.upsertFromPayload(payload, serverSessionToken)
    end
    return nil
end

function NMClientWorldSourceCache.collectInRange(player, out)
    if not player then return end
    out = out or {}

    local playerX = player.getX and tonumber(player:getX()) or 0
    local playerY = player.getY and tonumber(player:getY()) or 0
    local playerZ = player.getZ and tonumber(player:getZ()) or 0
    local worldCandidates = clearArray(collectCandidateScratch)

    for uuid, entry in pairs(NMClientWorldSourceCache.entries) do
        if tostring(entry and entry.kind or "") == "vehicle" then
            entry = NMClientWorldSourceCache.refreshVehicleSource(uuid) or entry
        end
        local source = entry and entry.source or nil
        if source then
            local profile = NMDeviceProfiles.getForFullType(entry.profileType or entry.itemFullType)
            local inRange = true
            local inFloors = true
            local range = 0
            local floors = 0
            local dz = 0
            if profile then
                range = NMDeviceProfiles.getWorldTrackingRange(profile)
                if range > 0 and player.getX and player.getY then
                    local dx = playerX - (tonumber(source.x) or 0)
                    local dy = playerY - (tonumber(source.y) or 0)
                    inRange = ((dx * dx) + (dy * dy)) <= (range * range)
                end
                floors = NMDeviceProfiles.getWorldTrackingFloors(profile)
                if floors > 0 and player.getZ then
                    dz = math.abs(playerZ - (tonumber(source.z) or 0))
                    inFloors = dz <= floors
                end
            end
            local state = entry and entry.stateSnapshot or nil
            if state and state.isPlaying == true and (inRange ~= true or inFloors ~= true) then
                local gateSig = table.concat({
                    tostring(inRange),
                    tostring(inFloors),
                    tostring(string.format("%.2f", dz)),
                    tostring(string.format("%.2f", tonumber(source.z) or 0)),
                    tostring(string.format("%.2f", playerZ))
                }, "|")
                if shouldLogPlaybackLossWorldSource(entry, "collect_gate." .. tostring(uuid), gateSig, 1000) then
                    NMCore.logChannel(
                        "runtime",
                        "world_source_tracking_gate",
                        string.format(
                            "uuid=%s ctx=%s inRange=%s inFloors=%s range=%s floors=%s playerZ=%s sourceZ=%s dz=%.2f sourceX=%s sourceY=%s lastPayloadApplyMs=%s media=%s",
                            tostring(uuid),
                            tostring(source.context or source.mode or "nil"),
                            tostring(inRange),
                            tostring(inFloors),
                            tostring(range),
                            tostring(floors),
                            formatCoord(playerZ),
                            formatCoord(source.z),
                            tonumber(dz) or 0,
                            formatCoord(source.x),
                            formatCoord(source.y),
                            tostring(entry and entry._lastPayloadApplyMs or 0),
                            tostring(state and state.mediaFullType or "nil")
                        )
                    )
                end
            end
            if tostring(entry and entry.kind or "") == "vehicle"
                and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled
                and NMCore.shouldLogEvery then
                local vehicleDebugEnabled = NMCore.isSubsystemDebugEnabled("vehicle")
                local vehicleTraceEnabled = NMCore.isSubsystemDebugEnabled("vehicle_trace")
                local now = nowMs()
                local gateKey = "vehicleProbe.vehicleGate." .. tostring(uuid)
                local gateState = tostring(inRange) .. ":" .. tostring(inFloors)
                local gateChanged = entry._lastVehicleGateState ~= gateState
                entry._lastVehicleGateState = gateState
                local traceHeartbeat = vehicleTraceEnabled and NMCore.shouldLogEvery(gateKey, now, 60000)
                local shouldLogGate = (gateChanged and vehicleDebugEnabled) or traceHeartbeat
                if shouldLogGate and (vehicleDebugEnabled or vehicleTraceEnabled) then
                    NMCore.logChannel(
                        gateChanged and vehicleDebugEnabled and "vehicle" or "vehicle_trace",
                        "vehicle_tracking_gate",
                        string.format(
                            "uuid=%s inRange=%s inFloors=%s x=%.2f y=%.2f z=%.2f",
                            tostring(uuid),
                            tostring(inRange),
                            tostring(inFloors),
                            tonumber(source.x) or 0,
                            tonumber(source.y) or 0,
                            tonumber(source.z) or 0
                        )
                    )
                end
            end
            if inRange and inFloors then
                local dx = playerX - (tonumber(source.x) or 0)
                local dy = playerY - (tonumber(source.y) or 0)
                worldCandidates[#worldCandidates + 1] = {
                    uuid = tostring(uuid),
                    entry = entry,
                    profile = profile,
                    distSq = (dx * dx) + (dy * dy)
                }
            end
        end
    end

    local function sortCandidates(candidates)
        table.sort(candidates, function(a, b)
            local da = tonumber(a and a.distSq) or 0
            local db = tonumber(b and b.distSq) or 0
            if da == db then
                return tostring(a and a.uuid or "") < tostring(b and b.uuid or "")
            end
            return da < db
        end)
    end

    sortCandidates(worldCandidates)
    local maxWorld = math.max(0, tonumber(NMRuntimeConfig.getMaxActiveWorldSourcesPerClient and NMRuntimeConfig.getMaxActiveWorldSourcesPerClient() or 10) or 10)

    local keptWorld = 0
    for i = 1, #worldCandidates do
        if keptWorld >= maxWorld then
            break
        end
        local candidate = worldCandidates[i]
        out[#out + 1] = {
            uuid = candidate.uuid,
            entry = clonePayload(candidate.entry),
            profile = candidate.profile,
            distSq = candidate.distSq
        }
        keptWorld = keptWorld + 1
    end

    local droppedWorld = #worldCandidates - keptWorld
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
        local now = nowMs()
        if droppedWorld > 0 and NMCore.shouldLogEvery("runtimeProbe.detachedCapDrop", now, 5000) then
            NMCore.logChannel(
                "runtime",
                "detached_cap_drop",
                string.format("kept=%d dropped=%d cap=%d", keptWorld, droppedWorld, maxWorld)
            )
        end
    end
end

function NMClientWorldSourceCache.forEach(fn)
    if type(fn) ~= "function" then return end
    for uuid, entry in pairs(NMClientWorldSourceCache.entries) do
        fn(uuid, entry)
    end
end

