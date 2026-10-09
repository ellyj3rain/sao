require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieMediaPayloadRuntime"
require "zombies/NMServerZombieAssignmentShared"

NMServerZombieAssignmentApplyShared = NMServerZombieAssignmentApplyShared or {}

local function syncCompanionCaseRegistration(zombie, payload, state, opts)
    local runtimeLabel = tostring(opts and opts.companionCaseRuntimeLabel or "")
    if runtimeLabel == "" then
        return nil
    end
    local source = tostring(opts and opts.companionCaseSource or opts and opts.strategyName or "")
    local result = NMZombieAudioVisualSupport.registerManagedCompanionCase(zombie, payload, state, source, runtimeLabel)
    if result and result.ok then
        return result
    end
    NMZombieAudioVisualSupport.recordCompanionCaseRegistrationFailure(
        zombie,
        payload,
        state,
        source,
        runtimeLabel,
        result and result.reason or "unknown"
    )
    return result
end

local function buildRealizationContract(zombie, status, selection, spec, payload, details)
    return NMServerZombieAssignmentShared.buildRealizationContract(zombie, status, selection, spec, payload, details)
end

local function attachRealizationContract(result, zombie, status, selection, spec, payload, details)
    result.realization = buildRealizationContract(zombie, status, selection, spec, payload, details)
    return result
end

local function buildAttachedOutcome(zombie, previousPayload, selection, spec, payload, item, state, opts, attachMeta)
    -- Invariant: payload finalization is part of the authoritative assignment seam and must happen before returning.
    NMServerZombieAssignmentShared.finalizePayloadSync(zombie, payload, previousPayload)
    local companionCaseResult = syncCompanionCaseRegistration(zombie, payload, state, opts)
    local result = {
        ok = true,
        status = "attached",
        reason = nil,
        selection = selection,
        spec = spec,
        payload = payload,
        item = item,
        state = state,
        companionCaseResult = companionCaseResult,
        usedInventoryFallback = attachMeta and attachMeta.usedInventoryFallback == true
    }
    local proofState = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
    return attachRealizationContract(result, zombie, "attached", selection, spec, payload, {
        proofItemStatus = attachMeta and attachMeta.usedInventoryFallback == true and "recovered_inventory"
            or attachMeta and attachMeta.createdItem == true and "created_inventory"
            or "attached",
        proofDeviceUUID = tostring(proofState and proofState.deviceUUID or ""),
        attachmentStatus = "attached",
        companionCaseStatus = companionCaseResult and companionCaseResult.ok and (companionCaseResult.registered and "registered" or "pruned") or "failed",
        companionCaseReason = companionCaseResult and companionCaseResult.reason or "",
        usedInventoryFallback = attachMeta and attachMeta.usedInventoryFallback == true,
        needsVisualRefresh = true
    })
end

function NMServerZombieAssignmentApplyShared.applyAssignment(zombie, opts)
    opts = opts or {}
    local strategyName = tostring(opts.strategyName or "")
    local selection = opts.selection
        or NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getOrAssignZombieSelection
        and NMZombieVisualTargetLedger.getOrAssignZombieSelection(zombie, strategyName)
        or nil
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    if not inventory then
        return attachRealizationContract({
            ok = false,
            status = "failed",
            reason = "missing_inventory",
            selection = selection
        }, zombie, "failed", selection, nil, nil, {
            proofItemStatus = "missing_inventory",
            attachmentStatus = "not_attempted",
            companionCaseStatus = "not_attempted",
            companionCaseReason = "missing_inventory"
        })
    end

    local spec, payload, selectionReason = NMServerZombieAssignmentShared.resolveSelectionContext(zombie, selection)
    local previousPayload = NMServerZombieAssignmentShared.getStoredPayload(zombie, opts.deps)
    if not spec then
        local removed = NMServerZombieAssignmentShared.clearKnownProofStates(zombie)
        if opts.pruneManagedCompanionCase == true then
            NMZombieAudioVisualSupport.pruneManagedCompanionCaseItems(zombie, "", "")
        end
        NMServerZombieAssignmentShared.finalizePayloadSync(zombie, payload, previousPayload)
        local baseReason = selectionReason == "device_disabled" and "device_disabled" or "ledger_selected_false"
        local status = payload and payload.mediaMode == "media_only" and "media_only" or (selectionReason == "device_disabled" and "suppressed" or "excluded")
        return attachRealizationContract({
            ok = false,
            status = status,
            reason = removed > 0 and (baseReason .. "_scrubbed") or baseReason,
            selection = selection,
            spec = NMServerZombieAssignmentShared.getSpecForVariantId(selection and selection.variantId or ""),
            payload = payload,
            removedCount = removed
        }, zombie, status, selection, NMServerZombieAssignmentShared.getSpecForVariantId(selection and selection.variantId or ""), payload, {
            proofItemStatus = removed > 0 and "scrubbed" or "excluded",
            attachmentStatus = removed > 0 and "scrubbed" or "excluded",
            companionCaseStatus = status == "media_only" and "media_only" or "pruned",
            companionCaseReason = baseReason,
            removedCount = removed,
            needsVisualRefresh = removed > 0
        })
    end

    local removed = NMServerZombieAssignmentShared.clearKnownProofStates(zombie, spec.variantId)
    if not NMServerZombieAssignmentShared.zombieSupportsProofLocation(zombie, spec) then
        return attachRealizationContract({
            ok = false,
            status = "failed",
            reason = "missing_proof_location",
            selection = selection,
            spec = spec,
            payload = payload,
            removedCount = removed
        }, zombie, "failed", selection, spec, payload, {
            proofItemStatus = "missing_proof_location",
            attachmentStatus = "missing_proof_location",
            companionCaseStatus = "not_attempted",
            companionCaseReason = "missing_proof_location",
            removedCount = removed
        })
    end

    local attachedItem, attachMeta = NMServerZombieAssignmentShared.findAttachedProofItem(zombie, spec, {
        deps = opts.deps,
        allowInventoryFallback = opts.allowAttachedInventoryFallback == true,
        wantedUuid = opts.wantedUuid
    })
    if attachedItem then
        local state, stateReason = NMServerZombieAssignmentShared.applyPayloadToProofState(zombie, attachedItem, spec, payload, strategyName)
        if stateReason then
            return attachRealizationContract({
                ok = false,
                status = "failed",
                reason = stateReason,
                selection = selection,
                spec = spec,
                payload = payload,
                item = attachedItem,
                usedInventoryFallback = attachMeta and attachMeta.usedInventoryFallback == true
            }, zombie, "failed", selection, spec, payload, {
                proofItemStatus = attachMeta and attachMeta.usedInventoryFallback == true and "recovered_inventory" or "attached_existing",
                proofDeviceUUID = tostring(state and state.deviceUUID or ""),
                attachmentStatus = "state_apply_failed",
                companionCaseStatus = "not_attempted",
                companionCaseReason = stateReason,
                usedInventoryFallback = attachMeta and attachMeta.usedInventoryFallback == true
            })
        end
        return buildAttachedOutcome(zombie, previousPayload, selection, spec, payload, attachedItem, state, opts, attachMeta)
    end

    local item = NMServerZombieAssignmentShared.findInventoryProofItem(zombie, spec, {
        deps = opts.deps,
        wantedUuid = opts.wantedUuid
    })
    local createdItem = false
    if not item then
        local addReason = nil
        item, addReason = NMServerZombieAssignmentShared.addInventoryProofItem(zombie, spec)
        if not item then
            return attachRealizationContract({
                ok = false,
                status = "failed",
                reason = addReason or "item_add_failed",
                selection = selection,
                spec = spec,
                payload = payload
            }, zombie, "failed", selection, spec, payload, {
                proofItemStatus = "item_add_failed",
                attachmentStatus = "not_attempted",
                companionCaseStatus = "not_attempted",
                companionCaseReason = addReason or "item_add_failed"
            })
        end
        createdItem = true
    end

    local state, stateReason = NMServerZombieAssignmentShared.applyPayloadToProofState(zombie, item, spec, payload, strategyName)
    if stateReason then
        return attachRealizationContract({
            ok = false,
            status = "failed",
            reason = stateReason,
            selection = selection,
            spec = spec,
            payload = payload,
            item = item,
            state = state
        }, zombie, "failed", selection, spec, payload, {
            proofItemStatus = createdItem and "created_inventory" or "reused_inventory",
            proofDeviceUUID = tostring(state and state.deviceUUID or ""),
            attachmentStatus = "state_apply_failed",
            companionCaseStatus = "not_attempted",
            companionCaseReason = stateReason
        })
    end

    local ok, attachReason = NMZombieAudioVisualSupport.attachProofItem(zombie, item, spec)
    if not ok then
        if createdItem then
            NMServerZombieAssignmentShared.removeInventoryItem(zombie, item)
        end
        return attachRealizationContract({
            ok = false,
            status = "failed",
            reason = attachReason,
            selection = selection,
            spec = spec,
            payload = payload,
            item = item,
            state = state
        }, zombie, "failed", selection, spec, payload, {
            proofItemStatus = createdItem and "created_inventory" or "reused_inventory",
            proofDeviceUUID = tostring(state and state.deviceUUID or ""),
            attachmentStatus = "attach_failed",
            companionCaseStatus = "not_attempted",
            companionCaseReason = attachReason
        })
    end

    return buildAttachedOutcome(zombie, previousPayload, selection, spec, payload, item, state, opts, {
        usedInventoryFallback = false,
        createdItem = createdItem
    })
end

return NMServerZombieAssignmentApplyShared
