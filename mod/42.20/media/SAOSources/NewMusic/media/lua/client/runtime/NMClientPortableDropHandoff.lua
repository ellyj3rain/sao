require "runtime/NMClientPlacedWorldCandidate"

NMClientPortableDropHandoff = NMClientPortableDropHandoff or {}
NMClientPortableDropHandoff.pending = NMClientPortableDropHandoff.pending or {}
NMClientPortableDropHandoff.pickup = NMClientPortableDropHandoff.pickup or {}
NMClientPortableDropHandoff._pickupProbe = NMClientPortableDropHandoff._pickupProbe or {}

local PICKUP_BRIDGE_TIMEOUT_MS = 2000

local function nowMs()
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

local function logRuntime(tag, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel("runtime", tag, detail)
    end
end

local function requestImmediatePlaybackRefresh(reason)
    local why = tostring(reason or "portable_drop_handoff")
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("portable_drop_" .. why)
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("portable_drop_" .. why)
    elseif NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
        NMClientPlaybackTick.markDirty("portable_drop_" .. why)
    end
    if NMClientMainRuntime and NMClientMainRuntime.requestVisualRefresh then
        NMClientMainRuntime.requestVisualRefresh("portable_drop_" .. why)
    end
end

local function requestImmediatePickupRefresh(reason)
    requestImmediatePlaybackRefresh("pickup_" .. tostring(reason or "bridge"))
end

local function resolveSquare(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    return worldItem and worldItem.getSquare and worldItem:getSquare() or nil
end

local function resolveDetachedContext(uuid)
    local entry = uuid ~= ""
        and NMClientWorldSourceCache
        and NMClientWorldSourceCache.get
        and NMClientWorldSourceCache.get(uuid)
        or nil
    local source = entry and entry.source or nil
    return tostring(source and source.context or "")
end

local function exportState(state)
    if NMDeviceState and NMDeviceState.export then
        return NMDeviceState.export(state)
    end
    return state
end

local function playerCoords(player)
    return {
        x = player and player.getX and (tonumber(player:getX()) or 0) or 0,
        y = player and player.getY and (tonumber(player:getY()) or 0) or 0,
        z = player and player.getZ and (tonumber(player:getZ()) or 0) or 0
    }
end

local function boolString(value)
    return tostring(value == true)
end

local function itemIdString(item)
    return item and item.getID and tostring(item:getID() or "") or ""
end

local function itemUuidString(item)
    return NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and tostring(NMInventoryHelpers.getItemStateUuid(item) or "") or ""
end

local function itemFullTypeString(item)
    return item and item.getFullType and tostring(item:getFullType() or "") or ""
end

local function itemContainerLabel(item)
    local container = item and item.getContainer and item:getContainer() or nil
    if not container then
        return "nil"
    end
    if container.getType then
        local ok, value = pcall(function()
            return tostring(container:getType() or "unknown")
        end)
        if ok and value and value ~= "" then
            return value
        end
    end
    return tostring(container)
end

local function inspectItemIdentity(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    return {
        item = item,
        itemId = itemIdString(item),
        uuid = itemUuidString(item),
        fullType = itemFullTypeString(item),
        container = itemContainerLabel(item),
        hasWorldItem = worldItem ~= nil,
        hasSquare = square ~= nil,
        squareX = square and square.getX and square:getX() or nil,
        squareY = square and square.getY and square:getY() or nil,
        squareZ = square and square.getZ and square:getZ() or nil
    }
end

local function formatIdentity(prefix, identity)
    local id = identity or {}
    return string.format(
        "%s.itemId=%s %s.uuid=%s %s.fullType=%s %s.container=%s %s.worldItem=%s %s.square=%s %s.squarePos=%s,%s,%s",
        tostring(prefix),
        tostring(id.itemId or ""),
        tostring(prefix),
        tostring(id.uuid or ""),
        tostring(prefix),
        tostring(id.fullType or ""),
        tostring(prefix),
        tostring(id.container or "nil"),
        tostring(prefix),
        boolString(id.hasWorldItem),
        tostring(prefix),
        boolString(id.hasSquare),
        tostring(prefix),
        tostring(id.squareX or "nil"),
        tostring(id.squareY or "nil"),
        tostring(id.squareZ or "nil")
    )
end

local function clearPickupBridge(uuid, reason, suppressWake)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    local bridge = NMClientPortableDropHandoff.pickup[key]
    if not bridge then
        return false
    end
    NMClientPortableDropHandoff.pickup[key] = nil
    if reason ~= nil then
        logRuntime("pickup_pending_exit", string.format("uuid=%s reason=%s", key, tostring(reason or "cleared")))
    end
    if suppressWake ~= true then
        requestImmediatePickupRefresh("exit_" .. tostring(reason or "cleared"))
    end
    return true
end

local function logPickupBridgeProbe(uuid, bridge, detail)
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    local slot = NMClientPortableDropHandoff._pickupProbe[key] or { signature = "", lastMs = 0 }
    local currentMs = nowMs()
    local signature = tostring(detail or "")
    local changed = tostring(slot.signature or "") ~= signature
    local heartbeat = (currentMs - (tonumber(slot.lastMs) or 0)) >= 1000
    if not (changed or heartbeat) then
        return
    end
    slot.signature = signature
    slot.lastMs = currentMs
    NMClientPortableDropHandoff._pickupProbe[key] = slot
    logRuntime("pickup_pending_probe", detail)
end

local function buildPickupBridgeDetail(uuid, bridge, attachedProof, chosenMode, resolvedState)
    local elapsedMs = 0
    if bridge then
        elapsedMs = math.max(0, nowMs() - (tonumber(bridge.returnedAtMs) or nowMs()))
    end
    return string.format(
        "uuid=%s detachedCtx=%s inventoryOwner=true attachedProof=%s chosenMode=%s elapsedMs=%s resolution=%s",
        tostring(uuid or ""),
        tostring(bridge and bridge.detachedContext or "none"),
        tostring(attachedProof == true),
        tostring(chosenMode or "off"),
        tostring(elapsedMs),
        tostring(resolvedState or chosenMode or "off")
    )
end

local function startPickupBridge(uuid, item, profileType, detachedContext, reason)
    local key = tostring(uuid or "")
    if key == "" or not item then
        return nil
    end
    local existing = NMClientPortableDropHandoff.pickup[key]
    local currentMs = nowMs()
    local bridge = existing or {
        item = item,
        profileType = profileType,
        returnedAtMs = currentMs,
        detachedContext = tostring(detachedContext or "placed"),
        reason = tostring(reason or "inventory_returned")
    }
    bridge.item = item
    bridge.profileType = profileType or bridge.profileType
    bridge.detachedContext = tostring(detachedContext or bridge.detachedContext or "placed")
    bridge.reason = tostring(reason or bridge.reason or "inventory_returned")
    if not existing then
        bridge.returnedAtMs = currentMs
        NMClientPortableDropHandoff.pickup[key] = bridge
        logRuntime(
            "pickup_pending_enter",
            string.format(
                "uuid=%s detachedCtx=%s reason=%s",
                key,
                tostring(bridge.detachedContext or "placed"),
                tostring(bridge.reason or "inventory_returned")
            )
        )
        requestImmediatePickupRefresh("enter")
    else
        NMClientPortableDropHandoff.pickup[key] = bridge
    end
    return bridge
end

local function resolvePlacedCandidate(player, pending, fallbackUuid)
    local item = pending and pending.item or nil
    local candidate = NMClientPlacedWorldCandidate and NMClientPlacedWorldCandidate.resolve
        and NMClientPlacedWorldCandidate.resolve(player, item, fallbackUuid)
        or nil
    if not candidate then
        return nil
    end
    local identity = inspectItemIdentity(candidate.item)
    identity.matchKind = candidate.matchKind
    return identity
end

local function logDropIdentity(player, tag, uuid, item, extra)
    local identity = inspectItemIdentity(item)
    local parts = {
        "uuid=" .. tostring(uuid or ""),
        formatIdentity("origin", identity)
    }
    if type(extra) == "table" then
        for i = 1, #extra do
            parts[#parts + 1] = tostring(extra[i])
        end
    end
    logRuntime(tostring(tag), table.concat(parts, " "))
end

local function detachGroundPersonalHeadphones(state)
    local current = tostring(state and state.headphoneItemFullType or "")
    if not (state and NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.shouldDetachOnGround(current)) then
        return false
    end
    state.headphoneItemFullType = nil
    return true
end

local function upsertPlaced(item, state, profileType, key)
    if not (item and state and NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload) then
        return false
    end
    local square = resolveSquare(item)
    if not square then
        return false
    end
    state.playbackMode = "world"
    NMClientWorldSourceCache.upsertFromPayload({
        uuid = key,
        kind = "item",
        profileType = profileType,
        state = exportState(state),
        sourceMode = "placed",
        x = square:getX() + 0.5,
        y = square:getY() + 0.5,
        z = square:getZ(),
        itemId = NMCore.itemId and NMCore.itemId(item) or nil,
        itemFullType = item and item.getFullType and item:getFullType() or nil,
        sourceEpoch = tonumber(state.sourceGeneration) or 0,
        sourceGeneration = tonumber(state.sourceGeneration) or 0,
        ownerId = tostring(state.sourceOwner or "")
    })
    return true
end

function NMClientPortableDropHandoff.tryEmitPlaced(player, item, state, profileType, key, reason, winner)
    if not (player and item and state and NMClientModeSync and NMClientModeSync.emitExplicit) then
        return false
    end
    detachGroundPersonalHeadphones(state)
    if not upsertPlaced(item, state, profileType, key) then
        return false
    end
    NMClientModeSync.emitExplicit(player, item, state, "sync_portable_placed", "placed")
    requestImmediatePlaybackRefresh("placed_emit")
    logDropIdentity(player, "portable_drop_handoff_promoted", key, item, {
        "winner=" .. tostring(winner or "original_ref"),
        "reason=" .. tostring(reason or "unknown")
    })
    return true
end

function NMClientPortableDropHandoff.beginPending(player, item, state, profileType, key)
    local uuid = tostring(key or "")
    if uuid == "" or not item or not state then
        return false
    end
    detachGroundPersonalHeadphones(state)
    local coords = playerCoords(player)
    NMClientPortableDropHandoff.pending[uuid] = {
        item = item,
        profileType = profileType,
        startedAtMs = nowMs(),
        lastSeenAtMs = nowMs(),
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
    logDropIdentity(player, "portable_drop_source_identity", uuid, item, {
        "state.isOn=" .. boolString(state and state.isOn == true),
        "state.isPlaying=" .. boolString(state and state.isPlaying == true),
        "sourceOwner=" .. tostring(state and state.sourceOwner or "")
    })
    logRuntime("drop_pending_enter", string.format("uuid=%s reason=no_square_yet", uuid))
    requestImmediatePlaybackRefresh("pending_enter")
    return true
end

function NMClientPortableDropHandoff.clear(uuid, reason)
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    if NMClientPortableDropHandoff.pending[key] then
        local why = tostring(reason or "cleared")
        local pendingSlot = NMClientPortableDropHandoff.pending[key]
        NMClientPortableDropHandoff.pending[key] = nil
        logRuntime("drop_pending_exit", string.format("uuid=%s reason=%s", key, why))
        requestImmediatePlaybackRefresh("pending_exit_" .. why)
        if why == "inventory_returned" then
            NMClientPortableDropHandoff._pickupRebind = NMClientPortableDropHandoff._pickupRebind or {}
            NMClientPortableDropHandoff._pickupRebind[key] = true
            local pendingItem = pendingSlot and pendingSlot.item or nil
            local pendingProfileType = pendingSlot and pendingSlot.profileType or nil
            if pendingItem then
                startPickupBridge(key, pendingItem, pendingProfileType, "placed", "inventory_returned")
            end
        end
    end
end

function NMClientPortableDropHandoff.hasPending(uuid)
    local key = tostring(uuid or "")
    return key ~= "" and NMClientPortableDropHandoff.pending[key] ~= nil
end

function NMClientPortableDropHandoff.consumePickupRebind(uuid)
    local key = tostring(uuid or "")
    local slot = NMClientPortableDropHandoff._pickupRebind or nil
    if key == "" or type(slot) ~= "table" or slot[key] ~= true then
        return false
    end
    slot[key] = nil
    return true
end

function NMClientPortableDropHandoff.resolvePickupBridge(player, item, profile, state, attached, square)
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() then
        return nil
    end
    if not (item and profile and state and NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        return nil
    end
    local key = tostring(state.deviceUUID or "")
    if key == "" then
        return nil
    end
    if attached == true then
        local existing = NMClientPortableDropHandoff.pickup[key]
        if existing then
            logPickupBridgeProbe(key, existing, buildPickupBridgeDetail(key, existing, true, "attached", "attached"))
        end
        clearPickupBridge(key, "attached", true)
        return nil
    end
    if square then
        clearPickupBridge(key, "world_square_visible", true)
        return nil
    end
    if state.isOn ~= true or state.isPlaying ~= true then
        clearPickupBridge(key, "playback_stopped", true)
        return nil
    end

    local bridge = NMClientPortableDropHandoff.pickup[key]
    if not bridge then
        local detachedContext = resolveDetachedContext(key)
        if detachedContext == "placed" then
            bridge = startPickupBridge(
                key,
                item,
                item.getFullType and item:getFullType() or nil,
                detachedContext,
                "placed_inventory_return"
            )
        end
    end
    if not bridge then
        return nil
    end

    bridge.item = item
    if (nowMs() - (tonumber(bridge.returnedAtMs) or 0)) > PICKUP_BRIDGE_TIMEOUT_MS then
        logPickupBridgeProbe(key, bridge, buildPickupBridgeDetail(key, bridge, false, "stowed", "timeout"))
        clearPickupBridge(key, "timed_out", true)
        return nil
    end

    logPickupBridgeProbe(key, bridge, buildPickupBridgeDetail(key, bridge, false, "pickup_pending", "pickup_pending"))
    return bridge
end

function NMClientPortableDropHandoff.buildPendingSource(player, uuid)
    local key = tostring(uuid or "")
    local pending = key ~= "" and NMClientPortableDropHandoff.pending[key] or nil
    if not pending then
        return nil
    end
    local candidate = resolvePlacedCandidate(player, pending, key)
    local square = candidate and candidate.hasSquare == true and {
        x = candidate.squareX,
        y = candidate.squareY,
        z = candidate.squareZ
    } or nil
    if square then
        return {
            mode = "world",
            context = "placed",
            x = (tonumber(square.x) or 0) + 0.5,
            y = (tonumber(square.y) or 0) + 0.5,
            z = tonumber(square.z) or 0
        }
    end
    local fallback = playerCoords(player)
    return {
        mode = "world",
        context = "drop_pending",
        x = tonumber(pending.x) or fallback.x,
        y = tonumber(pending.y) or fallback.y,
        z = tonumber(pending.z) or fallback.z
    }
end

function NMClientPortableDropHandoff.buildPickupSource(player, uuid)
    local key = tostring(uuid or "")
    local bridge = key ~= "" and NMClientPortableDropHandoff.pickup[key] or nil
    if not bridge then
        return nil
    end
    local fallback = playerCoords(player)
    return {
        mode = "world",
        context = "pickup_pending",
        x = fallback.x,
        y = fallback.y,
        z = fallback.z,
        _nmFastFollowPlayer = true
    }
end

function NMClientPortableDropHandoff.collectPendingPlayback(player, currentInventoryByUuid, out)
    local collected = out or {}
    local current = currentInventoryByUuid or {}
    local now = nowMs()
    for uuid, pending in pairs(NMClientPortableDropHandoff.pending) do
        if not current[uuid] then
            local item = pending and pending.item or nil
            local profile = item and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
            local state = item and profile and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
            if item and profile and state and state.isOn == true and state.isPlaying == true then
                pending.lastSeenAtMs = now
                collected[#collected + 1] = {
                    uuid = uuid,
                    item = item,
                    profile = profile,
                    state = state,
                    source = NMClientPortableDropHandoff.buildPendingSource(player, uuid)
                }
            end
        end
    end
    return collected
end

function NMClientPortableDropHandoff.reconcilePending(player, currentInventoryByUuid)
    local timeoutMs = 3000
    local current = currentInventoryByUuid or {}
    for uuid, pending in pairs(NMClientPortableDropHandoff.pending) do
        if current[uuid] then
            NMClientPortableDropHandoff.clear(uuid, "inventory_returned")
        else
            local item = pending and pending.item or nil
            local profile = item and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
            local state = item and profile and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
            local ageMs = nowMs() - (tonumber(pending and pending.startedAtMs) or nowMs())
            if not (item and profile and state) then
                NMClientPortableDropHandoff.clear(uuid, "state_missing")
            elseif state.isOn ~= true or state.isPlaying ~= true then
                NMClientPortableDropHandoff.clear(uuid, "playback_stopped")
            elseif ageMs > timeoutMs then
                logRuntime("drop_pending_timeout", string.format("uuid=%s ageMs=%d", tostring(uuid), math.max(0, ageMs)))
                NMClientPortableDropHandoff.clear(uuid, "timed_out")
            else
                local candidate = resolvePlacedCandidate(player, pending, uuid)
                if candidate and candidate.item and NMClientPortableDropHandoff.tryEmitPlaced(
                    player,
                    candidate.item,
                    state,
                    pending.profileType or (candidate.item.getFullType and candidate.item:getFullType() or nil),
                    uuid,
                    "deferred_square_ready",
                    candidate.matchKind
                ) then
                    NMClientPortableDropHandoff.clear(uuid, "placed_emitted")
                end
            end
        end
    end
end

return NMClientPortableDropHandoff
