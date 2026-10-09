-- Policy for reconciling detached world entries that conflict with owned inventory devices.
NMClientOwnershipConflictPolicy = NMClientOwnershipConflictPolicy or {}

function NMClientOwnershipConflictPolicy.applyInventoryOwnership(args)
    local uuid = tostring(args and args.uuid or "")
    if uuid == "" then
        return {
            allowDetachedSync = true,
            detachedContext = tostring(args and args.detachedContext or "unknown")
        }
    end

    local detachedContext = tostring(args and args.detachedContext or "unknown")
    local hasInventoryOwner = args and args.hasInventoryOwner == true
    local ownershipConflictState = args and args.ownershipConflictState or {}
    local detachedRemoveLogMs = args and args.detachedRemoveLogMs or {}
    local detachedOrchestration = args and args.detachedOrchestration or nil
    local previousConflictState = ownershipConflictState[uuid]
    local nowMs = tonumber(args and args.nowMs) or 0
    local detachedLogKey = tostring(uuid) .. "|inventory_owner"
    local lastDetachedRemoveMs = tonumber(detachedRemoveLogMs[detachedLogKey]) or 0
    local ownershipGate = detachedOrchestration and detachedOrchestration.applyInventoryOwnershipGate
        and detachedOrchestration.applyInventoryOwnershipGate({
            hasInventoryOwner = hasInventoryOwner,
            detachedContext = detachedContext,
            previousConflictState = previousConflictState,
            nowMsValue = nowMs,
            lastDetachedRemoveMs = lastDetachedRemoveMs,
            detachedRemoveIntervalMs = 5000
        })
        or nil
    local conflictStateKey = ownershipGate and ownershipGate.conflictStateKey
        or (tostring(hasInventoryOwner == true) .. ":" .. tostring(detachedContext))
    local conflictChanged = ownershipGate and ownershipGate.conflictChanged == true
        or (previousConflictState ~= conflictStateKey)

    ownershipConflictState[uuid] = conflictStateKey

    if not hasInventoryOwner then
        return {
            allowDetachedSync = true,
            detachedContext = detachedContext,
            conflictChanged = conflictChanged,
            conflictStateKey = conflictStateKey
        }
    end

    local profile = args and args.profile or nil
    local portableOwnedDetached = NMDeviceProfiles
        and NMDeviceProfiles.isPortableTrackedProfile
        and NMDeviceProfiles.isPortableTrackedProfile(profile) == true
    local logTransitionProbe = args and args.logTransitionProbe or nil

    local shouldPrune = portableOwnedDetached or (ownershipGate and ownershipGate.shouldPrune == true
        or (detachedOrchestration and detachedOrchestration.shouldPruneDetachedForInventoryOwner
            and detachedOrchestration.shouldPruneDetachedForInventoryOwner(hasInventoryOwner, detachedContext))
        or (hasInventoryOwner == true and tostring(detachedContext) ~= "vehicle"))

    if not shouldPrune then
        if conflictChanged and logTransitionProbe then
            logTransitionProbe(
                "ownership_conflict_resolved",
                string.format("uuid=%s winner=vehicle detachedCtx=%s", uuid, detachedContext)
            )
        end
        return {
            allowDetachedSync = true,
            detachedContext = detachedContext,
            conflictChanged = conflictChanged,
            conflictStateKey = conflictStateKey
        }
    end

    if conflictChanged and logTransitionProbe then
        logTransitionProbe(
            "ownership_conflict_inventory_prune",
            string.format(
                "uuid=%s winner=inventory detachedCtx=%s portable=%s action=remove_detached",
                uuid,
                detachedContext,
                tostring(portableOwnedDetached == true)
            )
        )
    end

    local removeDetached = args and args.removeDetached or nil
    if removeDetached then
        removeDetached(uuid)
    end

    local logRuntime = args and args.logRuntime or nil
    if conflictChanged and logRuntime then
        local shouldEmitDetachedRemove = ownershipGate and ownershipGate.shouldEmitDetachedRemove == true
            or (detachedOrchestration and detachedOrchestration.shouldEmitDetachedRemove
                and detachedOrchestration.shouldEmitDetachedRemove(nowMs, lastDetachedRemoveMs, 5000))
            or ((nowMs - lastDetachedRemoveMs) >= 5000)
        if shouldEmitDetachedRemove then
            detachedRemoveLogMs[detachedLogKey] = nowMs
            logRuntime("detached_track_remove", string.format("uuid=%s reason=inventory_owner", uuid))
        end
    end

    return {
        allowDetachedSync = false,
        detachedContext = detachedContext,
        conflictChanged = conflictChanged,
        conflictStateKey = conflictStateKey,
        portableOwnedDetached = portableOwnedDetached == true
    }
end

return NMClientOwnershipConflictPolicy
