-- Server registry payload builder and broadcast delivery helpers.
NMServerRegistryBroadcast = NMServerRegistryBroadcast or {}
NMServerRegistryBroadcast.SendSignatureCache = NMServerRegistryBroadcast.SendSignatureCache or {}
NMServerRegistryBroadcast.VehicleCapabilitySeen = NMServerRegistryBroadcast.VehicleCapabilitySeen or {}
NMServerRegistryBroadcast.VehicleTruthLogSeen = NMServerRegistryBroadcast.VehicleTruthLogSeen or {}

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

local function formatCoord(value)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    return string.format("%.2f", n)
end

local function calculateDistance(oldX, oldY, oldZ, newX, newY, newZ)
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

local function countRecipients()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return 0
    end
    return players:size()
end

local function isAttachedRegistryTimelinePayload(payload)
    local mode = tostring(payload and payload.sourceMode or "")
    return mode == "attached" or mode == "stowed"
end

local function logAttachedRegistryTimeline(payload, op, sessionToken, signature, sentCount, diagnosticContext)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("registry")) then
        return
    end
    if not payload or not isAttachedRegistryTimelinePayload(payload) then
        return
    end
    NMServerRegistryBroadcast.AttachedTimelineSeen = NMServerRegistryBroadcast.AttachedTimelineSeen or {}
    local uuid = tostring(payload.uuid or "")
    local previous = NMServerRegistryBroadcast.AttachedTimelineSeen[uuid] or {}
    local previousX = previous.x
    local previousY = previous.y
    local previousZ = previous.z
    local delta = calculateDistance(previousX, previousY, previousZ, payload.x, payload.y, payload.z)
    local totalRecipients = countRecipients()
    local heartbeatTick = diagnosticContext and diagnosticContext.heartbeatTick or 0
    local trigger = tostring(diagnosticContext and diagnosticContext.trigger or "heartbeat")
    NMCore.logChannel(
        "registry",
        "attached_registry_broadcast",
        string.format(
            "uuid=%s mode=%s op=%s trigger=%s heartbeatTick=%s sourceGen=%s pos=%s,%s,%s lastPos=%s,%s,%s delta=%.2f sent=%s recipients=%s signature=%s sessionToken=%s rebindReason=%s",
            tostring(uuid),
            tostring(payload.sourceMode or "nil"),
            tostring(op or "upsert"),
            tostring(trigger),
            tostring(heartbeatTick),
            tostring(payload.sourceGeneration or payload.sourceEpoch or 0),
            formatCoord(payload.x),
            formatCoord(payload.y),
            formatCoord(payload.z),
            formatCoord(previousX),
            formatCoord(previousY),
            formatCoord(previousZ),
            tonumber(delta) or 0,
            tostring(sentCount or 0),
            tostring(totalRecipients),
            tostring(signature or ""),
            tostring(sessionToken or "nil"),
            tostring(payload.rebindReason or "none")
        )
    )
    NMServerRegistryBroadcast.AttachedTimelineSeen[uuid] = {
        x = tonumber(payload.x),
        y = tonumber(payload.y),
        z = tonumber(payload.z),
        signature = signature,
        sentCount = sentCount,
        heartbeatTick = heartbeatTick,
        trigger = trigger
    }
end

local function shouldEmitVehicleTruthLog(tag, payload, op, cooldownMs)
    local state = payload and payload.state or {}
    local key = table.concat({
        tostring(tag or ""),
        tostring(payload and payload.uuid or ""),
        tostring(op or "upsert")
    }, "|")
    local sig = table.concat({
        tostring(payload and payload.sourceGeneration or 0),
        tostring(tonumber(state and state.revision) or 0),
        tostring(tonumber(state and state.playbackEpoch) or 0),
        tostring(tonumber(state and state.trackIndex) or 0),
        tostring(state and state.isOn == true),
        tostring(state and state.isPlaying == true),
        tostring(payload and payload.vehicleIdHint or payload and payload.vehicleId or ""),
        tostring(payload and payload.vehicleSqlId or ""),
        tostring(payload and payload.partId or "Radio"),
        tostring(payload and payload.x or 0),
        tostring(payload and payload.y or 0),
        tostring(payload and payload.z or 0)
    }, "|")
    local nowMs = nowRealMs()
    local seen = NMServerRegistryBroadcast.VehicleTruthLogSeen
    local lastSig = tostring(seen[key .. ".sig"] or "")
    local lastMs = tonumber(seen[key .. ".ms"]) or 0
    local ttl = tonumber(cooldownMs) or 20000
    if lastSig == sig and (nowMs - lastMs) < ttl then
        return false
    end
    seen[key .. ".sig"] = sig
    seen[key .. ".ms"] = nowMs
    return true
end

local function getRegistryPlayerKey(playerObj)
    if not playerObj then
        return "nil"
    end
    local onlineId = playerObj.getOnlineID and tostring(playerObj:getOnlineID() or "") or ""
    local username = playerObj.getUsername and tostring(playerObj:getUsername() or "") or ""
    if onlineId ~= "" then
        return onlineId
    end
    return username
end

function NMServerRegistryBroadcast.buildPayload(entry, state)
    if not entry then
        return nil
    end
    local canonicalSourceGen = math.max(
        tonumber(entry.sourceEpoch) or 0,
        tonumber(entry.sourceGeneration) or 0,
        tonumber(state and state.sourceGeneration) or 0
    )
    local canonicalPlaybackEpoch = tonumber(state and state.playbackEpoch)
        or tonumber(entry.playbackEpoch)
        or 0
    local canonicalTrackIndex = tonumber(state and state.trackIndex)
        or tonumber(entry.trackIndex)
        or 1
    local canonicalTrackCount = tonumber(state and state.trackCount)
        or tonumber(entry.trackCount)
        or 0
    local payload = {
        kind = tostring(entry.kind or "item"),
        uuid = tostring(entry.uuid or ""),
        x = tonumber(entry.x) or 0,
        y = tonumber(entry.y) or 0,
        z = tonumber(entry.z) or 0,
        sourceMode = tostring(entry.sourceMode or "placed"),
        sourceEpoch = canonicalSourceGen,
        sourceGeneration = canonicalSourceGen,
        sourceRebind = entry.sourceRebind == true,
        rebindReason = entry.rebindReason ~= nil and tostring(entry.rebindReason) or nil,
        profileType = entry.profileType,
        state = state and NMDeviceState.export(state) or entry.stateSnapshot,
        playbackEpoch = canonicalPlaybackEpoch,
        trackIndex = canonicalTrackIndex,
        trackCount = canonicalTrackCount
    }
    if payload.kind == "vehicle" then
        local vehicleSqlId = tostring(entry.vehicleSqlId or "")
        if vehicleSqlId == "" then
            return nil
        end
        payload.vehicleId = tostring(entry.vehicleId or "")
        payload.vehicleIdHint = tostring(entry.vehicleIdHint or entry.vehicleId or "")
        payload.vehicleSqlId = vehicleSqlId
        payload.vehicleSqlIdHint = tostring(entry.vehicleSqlIdHint or vehicleSqlId or "")
        payload.ownerId = tostring(entry.ownerId or entry.ownerOnlineId or entry.ownerUsername or "")
        payload.partId = tostring(entry.partId or "Radio")
        payload.windowsOpen = entry.windowsOpen == true
        payload.playbackPolicy = tostring(entry.playbackPolicy or state and state.playbackPolicy or "autoplay")
        payload.transitionReason = entry.transitionReason ~= nil and tostring(entry.transitionReason) or nil
    else
        payload.itemId = tostring(entry.itemId or "")
        payload.itemFullType = tostring(entry.itemFullType or "")
        payload.ownerId = tostring(entry.ownerId or entry.ownerOnlineId or entry.ownerUsername or "")
        payload.ownerUsername = tostring(entry.ownerUsername or "")
        payload.ownerOnlineId = tostring(entry.ownerOnlineId or "")
    end
    return payload
end

function NMServerRegistryBroadcast.buildSignature(op, payload)
    if not payload then
        return ""
    end
    local state = payload.state or {}
    return tostring(op or "")
        .. ":" .. tostring(payload.kind or "")
        .. ":" .. tostring(payload.uuid or "")
        .. ":" .. tostring(payload.sourceMode or "")
        .. ":" .. tostring(payload.sourceEpoch or 0)
        .. ":" .. tostring(payload.sourceGeneration or 0)
        .. ":" .. tostring(payload.x or 0)
        .. ":" .. tostring(payload.y or 0)
        .. ":" .. tostring(payload.z or 0)
        .. ":" .. tostring(tonumber(state.revision) or 0)
        .. ":" .. tostring(tonumber(state.playbackEpoch) or 0)
        .. ":" .. tostring(state.isOn == true)
        .. ":" .. tostring(state.isPlaying == true)
        .. ":" .. tostring(tonumber(state.trackIndex) or 1)
        .. ":" .. tostring(state.mediaFullType or "")
        .. ":" .. tostring(state.mediaDisplayName or "")
        .. ":" .. tostring(tonumber(state.volume) or 1)
        .. ":" .. tostring(state.isMuted == true)
        .. ":" .. tostring(payload.sourceRebind == true)
        .. ":" .. tostring(payload.rebindReason or "")
        .. ":" .. tostring(payload.vehicleId or "")
        .. ":" .. tostring(payload.vehicleIdHint or "")
        .. ":" .. tostring(payload.vehicleSqlId or "")
        .. ":" .. tostring(payload.vehicleSqlIdHint or "")
        .. ":" .. tostring(payload.ownerId or "")
        .. ":" .. tostring(payload.partId or "")
        .. ":" .. tostring(payload.windowsOpen == true)
end

local function logSqlAnchorLineage(payload, path, reason)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local state = payload and payload.state or nil
    NMCore.logChannel(
        "runtime",
        "sql_anchor_lineage",
        string.format(
            "uuid=%s sourceGen=%s revision=%s playbackEpoch=%s vehicleSqlId=%s vehicleSqlIdHint=%s runtimeVehicleIdHint=%s path=%s reason=%s",
            tostring(payload and payload.uuid or ""),
            tostring(payload and payload.sourceGeneration or 0),
            tostring(state and state.revision or 0),
            tostring(state and state.playbackEpoch or 0),
            tostring(payload and payload.vehicleSqlId or ""),
            tostring(payload and payload.vehicleSqlIdHint or ""),
            tostring(payload and payload.vehicleIdHint or ""),
            tostring(path or "server_registry_broadcast"),
            tostring(reason or "none")
        )
    )
end

local function logVehicleTruthAuthorityCheckpoint(payload, op, sessionToken)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    if not payload or tostring(payload.kind or "") ~= "vehicle" then
        return
    end
    local state = payload.state or {}
    local traceToken = table.concat({
        tostring(payload.uuid or ""),
        tostring(payload.sourceGeneration or 0),
        tostring(tonumber(state.revision) or 0),
        tostring(tonumber(state.playbackEpoch) or 0)
    }, "|")
    NMCore.logChannel(
        "vehicle",
        "vehicle_truth_authority_checkpoint",
        string.format(
            "traceToken=%s sessionToken=%s reasonContext=%s uuid=%s vehicleSqlId=%s runtimeVehicleIdHint=%s partId=%s sourceGen=%s revision=%s playbackEpoch=%s trackIndex=%s isOn=%s isPlaying=%s",
            tostring(traceToken),
            tostring(sessionToken or "nil"),
            tostring(op or "upsert"),
            tostring(payload.uuid or ""),
            tostring(payload.vehicleSqlId or ""),
            tostring(payload.vehicleIdHint or payload.vehicleId or ""),
            tostring(payload.partId or ""),
            tostring(payload.sourceGeneration or 0),
            tostring(tonumber(state.revision) or 0),
            tostring(tonumber(state.playbackEpoch) or 0),
            tostring(tonumber(state.trackIndex) or 0),
            tostring(state.isOn == true),
            tostring(state.isPlaying == true)
        )
    )
end

local function logVehicleIdCapabilityMatrix(payload, sessionToken)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    if not payload or tostring(payload.kind or "") ~= "vehicle" then
        return
    end
    local state = payload.state or {}
    local stateDeviceUuid = tostring(state and state.deviceUUID or payload.uuid or "")
    local partUuid = stateDeviceUuid
    local traceToken = table.concat({
        tostring(payload.uuid or ""),
        tostring(payload.sourceGeneration or 0),
        tostring(tonumber(state.revision) or 0),
        tostring(tonumber(state.playbackEpoch) or 0)
    }, "|")
    local sig = table.concat({
        traceToken,
        tostring(payload.vehicleId or ""),
        tostring(payload.vehicleSqlId or ""),
        tostring(payload.partId or "Radio"),
        tostring(partUuid),
        tostring(payload.x or 0),
        tostring(payload.y or 0),
        tostring(payload.z or 0)
    }, "|")
    local key = tostring(payload.uuid or "")
    local now = getTimestampMs and tonumber(getTimestampMs()) or (getTimestamp and tonumber(getTimestamp()) and tonumber(getTimestamp()) * 1000) or 0
    local lastSig = tostring(NMServerRegistryBroadcast.VehicleCapabilitySeen[key .. ".sig"] or "")
    local lastMs = tonumber(NMServerRegistryBroadcast.VehicleCapabilitySeen[key .. ".ms"]) or 0
    if sig == lastSig and (now - lastMs) < 20000 then
        return
    end
    NMServerRegistryBroadcast.VehicleCapabilitySeen[key .. ".sig"] = sig
    NMServerRegistryBroadcast.VehicleCapabilitySeen[key .. ".ms"] = now
    NMCore.logChannel(
        "vehicle",
        "vehicle_id_capability_matrix",
        string.format(
            "traceToken=%s sessionToken=%s uuid=%s sourceGen=%s revision=%s playbackEpoch=%s runtimeVehicleId=%s vehicleSqlId=%s partId=%s partUuid=%s stateDeviceUuid=%s x=%.2f y=%.2f z=%.2f",
            tostring(traceToken),
            tostring(sessionToken or "nil"),
            tostring(payload.uuid or ""),
            tostring(payload.sourceGeneration or 0),
            tostring(tonumber(state.revision) or 0),
            tostring(tonumber(state.playbackEpoch) or 0),
            tostring(payload.vehicleId or payload.vehicleIdHint or ""),
            tostring(payload.vehicleSqlId or payload.vehicleSqlIdHint or ""),
            tostring(payload.partId or "Radio"),
            tostring(partUuid),
            tostring(stateDeviceUuid),
            tonumber(payload.x) or 0,
            tonumber(payload.y) or 0,
            tonumber(payload.z) or 0
        )
    )
end

function NMServerRegistryBroadcast.shouldSendSignature(playerObj, uuid, signature)
    local pkey = getRegistryPlayerKey(playerObj)
    local key = tostring(uuid or "") .. "::" .. tostring(pkey)
    local prev = NMServerRegistryBroadcast.SendSignatureCache[key]
    if prev ~= nil and tostring(prev) == tostring(signature) then
        return false
    end
    NMServerRegistryBroadcast.SendSignatureCache[key] = tostring(signature)
    return true
end

function NMServerRegistryBroadcast.cleanupSignatureCache(activeUuids)
    activeUuids = activeUuids or {}
    for key, _ in pairs(NMServerRegistryBroadcast.SendSignatureCache) do
        local uuid = tostring(key):match("^(.-)::") or ""
        if uuid ~= "" and not activeUuids[uuid] then
            NMServerRegistryBroadcast.SendSignatureCache[key] = nil
        end
    end
end

function NMServerRegistryBroadcast.sendRegistryUpdate(playerObj, op, payload)
    if not playerObj or not payload or not sendServerCommand then
        return false
    end
    local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    sendServerCommand(playerObj, NMCore.NetModule, "registry_update", {
        op = tostring(op or "upsert"),
        payload = payload,
        serverSessionToken = sessionToken
    })
    return true
end

function NMServerRegistryBroadcast.broadcastEntry(worldRegistry, uuid, profile, state, op, recipientFn, diagnosticContext)
    local entry = worldRegistry and worldRegistry[uuid] or nil
    if not entry then
        return 0
    end
    local payload = NMServerRegistryBroadcast.buildPayload(entry, state)
    if not payload then
        return 0
    end
    if payload and tostring(payload.kind or "") == "vehicle" then
        local reason = tostring(op or "upsert")
        if shouldEmitVehicleTruthLog("sql_anchor_lineage", payload, reason, 20000) then
            logSqlAnchorLineage(payload, "server_registry_broadcast", reason)
        end
        if shouldEmitVehicleTruthLog("vehicle_truth_authority_checkpoint", payload, reason, 20000) then
            local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
            logVehicleTruthAuthorityCheckpoint(payload, reason, sessionToken)
        end
        if shouldEmitVehicleTruthLog("vehicle_id_capability_matrix", payload, reason, 20000) then
            local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
            logVehicleIdCapabilityMatrix(payload, sessionToken)
        end
    end

    local sent = 0
    local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    local signature = NMServerRegistryBroadcast.buildSignature(op, payload)
    if type(recipientFn) == "function" then
        recipientFn(function(playerObj)
            local force = tostring(op or "") == "remove"
            if force or NMServerRegistryBroadcast.shouldSendSignature(playerObj, uuid, signature) then
                if NMServerRegistryBroadcast.sendRegistryUpdate(playerObj, op, payload) then
                    sent = sent + 1
                end
            end
        end)
    end
    logAttachedRegistryTimeline(payload, op, sessionToken, signature, sent, diagnosticContext)
    return sent
end

