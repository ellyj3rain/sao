-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "runtime/NMClientPlacedWorldCandidate"

-- Client-side mode candidate reconcile for attached/placed/stowed transitions.
NMClientModeReconcile = NMClientModeReconcile or {}
NMClientModeReconcile.authority = NMClientModeReconcile.authority or {}

local function getSlot(uuid)
    local key = tostring(uuid or "")
    if key == "" then
        return nil
    end
    local slot = NMClientModeReconcile.authority[key]
    if not slot then
        slot = {
            mode = "off",
            sourceGeneration = 0,
            noCarryStreak = 0,
            lastTick = 0,
            noSquareSinceMs = 0,
            placedCandidateSig = "",
            placedCandidateLastLogMs = 0
        }
        NMClientModeReconcile.authority[key] = slot
    end
    return slot
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
    return 0
end

local function logStowedCandidateProbe(slot, uuid, item, candidate, chosenMode, elapsedMs)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local itemWorld = item and item.getWorldItem and item:getWorldItem() or nil
    local itemSquare = itemWorld and itemWorld.getSquare and itemWorld:getSquare() or nil
    local candidateSquare = candidate and candidate.square or nil
    local matchKind = tostring(candidate and candidate.matchKind or "none")
    local signature = table.concat({
        matchKind,
        tostring(chosenMode or "off"),
        tostring(NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.quantizeCoord and NMRuntimeProbeAdapter.quantizeCoord(candidateSquare and candidateSquare:getX() or nil, 2.0) or (candidateSquare and candidateSquare:getX() or "nil")),
        tostring(NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.quantizeCoord and NMRuntimeProbeAdapter.quantizeCoord(candidateSquare and candidateSquare:getY() or nil, 2.0) or (candidateSquare and candidateSquare:getY() or "nil")),
        tostring(NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.quantizeCoord and NMRuntimeProbeAdapter.quantizeCoord(candidateSquare and candidateSquare:getZ() or nil, 1.0) or (candidateSquare and candidateSquare:getZ() or "nil"))
    }, "|")
    local currentMs = nowMs()
    local changed = tostring(slot.placedCandidateSig or "") ~= signature
    local withinTransitionWindow = math.max(0, tonumber(elapsedMs) or 0) <= 5000
    local heartbeatMs = withinTransitionWindow and 4000 or (NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.longHeartbeatMs and NMRuntimeProbeAdapter.longHeartbeatMs() or 60000)
    local heartbeat = (currentMs - (tonumber(slot.placedCandidateLastLogMs) or 0)) >= heartbeatMs
    if not (changed or heartbeat) then
        return
    end
    slot.placedCandidateSig = signature
    slot.placedCandidateLastLogMs = currentMs
    NMCore.logChannel(
        "runtime",
        "stowed_candidate_probe",
        string.format(
            "uuid=%s directWorldItem=%s directSquare=%s candidate=%s match=%s chosenMode=%s elapsedMs=%s candidatePos=%s,%s,%s",
            tostring(uuid or ""),
            tostring(itemWorld ~= nil),
            tostring(itemSquare ~= nil),
            tostring(candidate ~= nil),
            tostring(matchKind),
            tostring(chosenMode or "off"),
            tostring(math.max(0, tonumber(elapsedMs) or 0)),
            tostring(candidateSquare and candidateSquare:getX() or "nil"),
            tostring(candidateSquare and candidateSquare:getY() or "nil"),
            tostring(candidateSquare and candidateSquare:getZ() or "nil")
        )
    )
end

local function logAttachedPlacedOverrideProbe(uuid, item, candidate, chosenMode)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local itemWorld = item and item.getWorldItem and item:getWorldItem() or nil
    local itemSquare = itemWorld and itemWorld.getSquare and itemWorld:getSquare() or nil
    local candidateSquare = candidate and candidate.square or nil
    NMCore.logChannel(
        "runtime",
        "attached_placed_override_probe",
        string.format(
            "uuid=%s attachedProof=%s directWorldItem=%s directSquare=%s candidate=%s match=%s chosenMode=%s candidatePos=%s,%s,%s",
            tostring(uuid or ""),
            tostring(true),
            tostring(itemWorld ~= nil),
            tostring(itemSquare ~= nil),
            tostring(candidate ~= nil),
            tostring(candidate and candidate.matchKind or "none"),
            tostring(chosenMode or "attached"),
            tostring(candidateSquare and candidateSquare:getX() or "nil"),
            tostring(candidateSquare and candidateSquare:getY() or "nil"),
            tostring(candidateSquare and candidateSquare:getZ() or "nil")
        )
    )
end

local function isAttached(player, item, uuid)
    local itemId = NMInventoryHelpers.getItemIdString(item)
    if itemId == "" then return false end

    -- Held devices should be treated as carried/attached, not stowed.
    local primary = player and player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    if NMAttachmentHelpers.itemMatchesTarget(primary, itemId, item, uuid) then
        return true
    end
    local secondary = player and player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if NMAttachmentHelpers.itemMatchesTarget(secondary, itemId, item, uuid) then
        return true
    end

    local attachedItems = player and player.getAttachedItems and player:getAttachedItems() or nil
    if attachedItems then
        for i = 0, attachedItems:size() - 1 do
            local entry = attachedItems:get(i)
            local attachedItem = entry and entry.getItem and entry:getItem() or nil
            if NMAttachmentHelpers.itemMatchesTarget(attachedItem, itemId, item, uuid) then
                return true
            end
        end
    end

    if NMAttachmentHelpers.isItemWornOnBack(player, itemId, item, uuid) then
        return true
    end
    return false
end

function NMClientModeReconcile.resolveModeForItem(player, item, profile, state)
    if not player or not item or not profile or not state then
        return "off"
    end
    if NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(state) then
        return "off"
    end

    local uuid = tostring(state.deviceUUID or "")
    local attached = isAttached(player, item, uuid)
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil

    local slot = getSlot(uuid)
    if attached then
        slot.noCarryStreak = 0
    else
        slot.noCarryStreak = (tonumber(slot.noCarryStreak) or 0) + 1
    end
    if attached or square then
        slot.noSquareSinceMs = 0
        slot.placedCandidateSig = ""
    end

    if attached
        and (not square)
        and NMCore
        and NMCore.isMPClientRuntime
        and NMCore.isMPClientRuntime() ~= true
        and NMDeviceProfiles.isPortableTrackedProfile(profile) then
        local attachedCandidate = NMClientPlacedWorldCandidate and NMClientPlacedWorldCandidate.resolve
            and NMClientPlacedWorldCandidate.resolve(player, item, uuid)
            or nil
        if attachedCandidate
            and attachedCandidate.hasSquare == true
            and tostring(attachedCandidate.matchKind or "") == "uuid_world_match" then
            logAttachedPlacedOverrideProbe(uuid, item, attachedCandidate, "placed")
            return "placed"
        end
    end

    if attached and (NMDeviceProfiles.canAnyWorldPlayback(profile) or NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        return "attached"
    end
    if square and (NMDeviceProfiles.canPlacedWorldPlayback(profile) or NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        return "placed"
    end
    if (not attached)
        and (not square)
        and NMClientPortableDropHandoff
        and NMClientPortableDropHandoff.hasPending
        and NMClientPortableDropHandoff.hasPending(uuid)
        and NMDeviceProfiles.isPortableTrackedProfile(profile) then
        return "drop_pending"
    end
    if (not attached) and (not square) and (NMDeviceProfiles.canAnyWorldPlayback(profile) or NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        if NMDeviceProfiles.isPortableTrackedProfile(profile) then
            local pickupBridge = NMClientPortableDropHandoff
                and NMClientPortableDropHandoff.resolvePickupBridge
                and NMClientPortableDropHandoff.resolvePickupBridge(player, item, profile, state, attached, square)
                or nil
            if pickupBridge then
                return "pickup_pending"
            end
            local observedSinceMs = tonumber(slot.noSquareSinceMs) or 0
            if observedSinceMs <= 0 then
                observedSinceMs = nowMs()
                slot.noSquareSinceMs = observedSinceMs
            end
            local candidate = NMClientPlacedWorldCandidate and NMClientPlacedWorldCandidate.resolve
                and NMClientPlacedWorldCandidate.resolve(player, item, uuid)
                or nil
            local chosenMode = candidate and "placed" or "stowed"
            logStowedCandidateProbe(slot, uuid, item, candidate, chosenMode, nowMs() - observedSinceMs)
            if candidate and candidate.hasSquare == true then
                return "placed"
            end
        end
        return "stowed"
    end
    return "off"
end

function NMClientModeReconcile.applyResolvedMode(uuid, state, mode)
    local slot = getSlot(uuid)
    if not slot or not state then
        return false
    end
    local nextMode = tostring(mode or "off")
    local prevMode = tostring(slot.mode or "off")
    if prevMode == nextMode then
        slot.lastTick = (tonumber(slot.lastTick) or 0) + 1
        return false
    end
    slot.mode = nextMode
    slot.sourceGeneration = math.max(tonumber(slot.sourceGeneration) or 0, tonumber(state.sourceGeneration) or 0)
    slot.lastTick = (tonumber(slot.lastTick) or 0) + 1
    return true
end

function NMClientModeReconcile.forEachAuthority(fn)
    if type(fn) ~= "function" then
        return
    end
    for uuid, slot in pairs(NMClientModeReconcile.authority) do
        fn(uuid, slot)
    end
end

function NMClientModeReconcile.pruneAuthority(validMap)
    for uuid, _ in pairs(NMClientModeReconcile.authority) do
        if not (validMap and validMap[uuid]) then
            NMClientModeReconcile.authority[uuid] = nil
        end
    end
end

