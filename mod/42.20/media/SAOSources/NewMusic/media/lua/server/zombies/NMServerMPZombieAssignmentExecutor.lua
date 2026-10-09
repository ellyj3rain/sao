require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadResolver"
require "zombies/NMZombieMediaPayloadRuntime"
require "zombies/NMServerZombieScanHelpers"
require "zombies/NMServerZombieAssignmentShared"
require "zombies/NMServerZombieAssignmentApplyShared"
require "zombies/NMServerZombieAssignmentOutcomeShared"

NMServerMPZombieAssignmentExecutor = NMServerMPZombieAssignmentExecutor or {}

local function getModData(deps, holder)
    local fn = deps and deps.getModData or nil
    return fn and fn(holder) or nil
end

local function getSpecForVariantId(variantId)
    return NMServerZombieAssignmentShared.getSpecForVariantId(variantId)
end

local function getStampedVariantSpec(deps, zombie)
    return NMServerZombieAssignmentShared.getStampedVariantSpec(zombie, deps)
end

local function findAttachedProofItem(deps, zombie, spec)
    return NMServerZombieAssignmentShared.findAttachedProofItem(zombie, spec, { deps = deps })
end

local function inventoryHasProofUuid(deps, zombie, wantedUuid, spec)
    local resolved = type(spec) == "table" and spec or getStampedVariantSpec(deps, zombie)
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    local items = inventory and inventory.getItems and inventory:getItems() or nil
    if not (items and items.size and resolved) then
        return false, nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if fullType == tostring(resolved.fullType or "") then
            local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
            local uuid = tostring(state and state.deviceUUID or "")
            if wantedUuid == "" or uuid == wantedUuid then
                return true, item
            end
        end
    end
    return false, nil
end

local function shouldLogAssignment()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true
end

local function getZombieDebugId(zombie)
    return tostring(zombie and zombie.getOnlineID and zombie:getOnlineID()
        or zombie and zombie.getObjectID and zombie:getObjectID()
        or "unknown")
end

local function logMPAssignmentOutcome(deps, zombie, source, outcome)
    if not shouldLogAssignment() then
        return
    end
    local realization = outcome and outcome.realization or nil
    local spec = outcome and outcome.spec or getStampedVariantSpec(deps, zombie)
    local md = getModData(deps, zombie)
    local deviceUUID = tostring(outcome and outcome.state and outcome.state.deviceUUID
        or md and md.deviceUUID
        or "")
    local attachedVisible = spec and findAttachedProofItem(deps, zombie, spec) ~= nil or false
    local inventoryVisible = inventoryHasProofUuid(deps, zombie, deviceUUID, spec)
    NMCore.logChannel(
        "zombie_assignment",
        "mp_assignment_outcome",
        string.format(
            "zombie=%s source=%s ok=%s status=%s reason=%s variant=%s fullType=%s deviceUUID=%s mediaMode=%s proof=%s attachment=%s companion=%s refresh=%s usedInventoryFallback=%s attachedVisible=%s inventoryProof=%s contractMode=%s contractFullType=%s",
            getZombieDebugId(zombie),
            tostring(source or ""),
            tostring(outcome and outcome.ok == true),
            tostring(outcome and outcome.status or ""),
            tostring(outcome and outcome.reason or ""),
            tostring(realization and realization.variantId or spec and spec.variantId or md and md.variantId or ""),
            tostring(realization and realization.fullType or spec and spec.fullType or md and md.fullType or ""),
            deviceUUID,
            tostring(realization and realization.payload and realization.payload.mediaMode or md and md.mediaMode or ""),
            tostring(realization and realization.proofItemStatus or ""),
            tostring(realization and realization.attachmentStatus or ""),
            tostring(realization and realization.companionCaseStatus or ""),
            tostring(realization and realization.needsVisualRefresh == true or false),
            tostring(outcome and outcome.usedInventoryFallback == true or false),
            tostring(attachedVisible),
            tostring(inventoryVisible),
            tostring(md and md.corpseCompanionMode or ""),
            tostring(md and md.corpseCompanionFullType or "")
        )
    )
    if outcome and outcome.ok == true and attachedVisible ~= true and inventoryVisible == true then
        NMCore.logChannel(
            "zombie_assignment",
            "mp_assignment_attached_not_visible",
            string.format(
                "zombie=%s source=%s variant=%s fullType=%s deviceUUID=%s proof=%s attachment=%s",
                getZombieDebugId(zombie),
                tostring(source or ""),
                tostring(spec and spec.variantId or ""),
                tostring(spec and spec.fullType or ""),
                deviceUUID,
                tostring(realization and realization.proofItemStatus or ""),
                tostring(realization and realization.attachmentStatus or "")
            )
        )
    end
end

local function recordTruthObservation(diag, zombie, uuid, deps)
    local spec = getStampedVariantSpec(deps, zombie)
    local attachedVisible = spec and findAttachedProofItem(deps, zombie, spec) ~= nil or false
    local inventoryVisible = inventoryHasProofUuid(deps, zombie, uuid, spec)
    if attachedVisible then
        diag.attachedListVisible = (diag.attachedListVisible or 0) + 1
    else
        diag.attachedListMissing = (diag.attachedListMissing or 0) + 1
    end
    if inventoryVisible then
        diag.inventoryStillHasProof = (diag.inventoryStillHasProof or 0) + 1
    end
end

local function tryCallNoArgMethod(target, methodName)
    local fn = target and target[methodName] or nil
    if type(fn) ~= "function" then
        return false, "missing"
    end
    local ok, err = pcall(fn, target)
    if not ok then
        return false, tostring(err or "error")
    end
    return true, nil
end

local function probeRefreshPaths(diag, zombie, uuid, deps)
    if type(zombie and zombie.resetModelNextFrame) == "function" then
        tryCallNoArgMethod(zombie, "resetModelNextFrame")
        recordTruthObservation(diag, zombie, uuid, deps)
    end
    if type(zombie and zombie.resetModel) == "function" then
        tryCallNoArgMethod(zombie, "resetModel")
        recordTruthObservation(diag, zombie, uuid, deps)
    end
end

local function sampleAttachmentLifecycle(diag, zombie, uuid, deps)
    if (diag.sampleBudget or 0) <= 0 then
        return
    end
    diag.sampleBudget = (diag.sampleBudget or 0) - 1
    recordTruthObservation(diag, zombie, uuid, deps)
    probeRefreshPaths(diag, zombie, uuid, deps)
    diag.pendingSamples = diag.pendingSamples or {}
    diag.pendingSamples[#diag.pendingSamples + 1] = {
        zombie = zombie,
        uuid = tostring(uuid or ""),
        recheckTick = (diag.ticks or 0) + (deps.constants and deps.constants.SAMPLE_RECHECK_DELAY_TICKS or 0)
    }
end

function NMServerMPZombieAssignmentExecutor.processPendingSamples(diag, deps)
    local pending = diag.pendingSamples or {}
    local keep = {}
    for i = 1, #pending do
        local entry = pending[i]
        if entry and entry.zombie and NMServerZombieScanHelpers.isAliveZombie(entry.zombie) then
            if (diag.ticks or 0) >= (tonumber(entry.recheckTick) or 0) then
                recordTruthObservation(diag, entry.zombie, entry.uuid, deps)
            else
                keep[#keep + 1] = entry
            end
        end
    end
    diag.pendingSamples = keep
end

local function markResolved(deps, zombie, spec, item, source, reason, payload)
    local resolvedStatus = "attached"
    NMServerZombieAssignmentOutcomeShared.stampAttachedState(zombie, spec, {
        item = item,
        reason = reason,
        assignmentSource = source,
        strategyName = deps.constants and deps.constants.STRATEGY_NAME or "",
        payload = payload,
        lastAttemptTick = tonumber(deps.diag and deps.diag.ticks or 0) or 0
    })
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true then
        local md = getModData(deps, zombie)
        if md and tostring(md.corpseCompanionMode or "") == "device_with_media" and tostring(md.lastCompanionCaseRegistrationFailure or "") == "" then
            return
        end
        local contractSig = table.concat({
            resolvedStatus,
            tostring(md and md.mediaMode or ""),
            tostring(md and md.caseEmptyType or ""),
            tostring(md and md.caseFullType or ""),
            tostring(md and md.deviceUUID or ""),
            tostring(md and md.corpseCompanionMode or ""),
            tostring(md and md.corpseCompanionFullType or ""),
            tostring(md and md.corpseCompanionDeviceUUID or "")
        }, "|")
        if md and md.nmLastResolvedCaseContractSig ~= contractSig then
            md.nmLastResolvedCaseContractSig = contractSig
            NMCore.logChannel(
                "zombie_assignment",
                "mp_case_contract_after_resolve",
                string.format(
                    "zombie=%s mode=%s mediaMode=%s caseEmpty=%s caseFull=%s deviceUUID=%s contractMode=%s contractFullType=%s contractDeviceUUID=%s",
                    tostring(zombie and zombie.getObjectID and zombie:getObjectID() or "unknown"),
                    resolvedStatus,
                    tostring(md and md.mediaMode or ""),
                    tostring(md and md.caseEmptyType or ""),
                    tostring(md and md.caseFullType or ""),
                    tostring(md and md.deviceUUID or ""),
                    tostring(md and md.corpseCompanionMode or ""),
                    tostring(md and md.corpseCompanionFullType or ""),
                    tostring(md and md.corpseCompanionDeviceUUID or "")
                )
            )
        end
    end
end

local function noteRealization(deps, zombie, outcome)
    local realization = outcome and outcome.realization or nil
    if NMServerZombieVisualTargetPublisher and NMServerZombieVisualTargetPublisher.noteRealizationChanged then
        NMServerZombieVisualTargetPublisher.noteRealizationChanged(zombie, realization)
    end
    if realization and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true then
        NMCore.logChannel(
            "zombie_assignment",
            "mp_realization_contract",
            string.format(
                "zombie=%s status=%s variant=%s mediaMode=%s proof=%s attachment=%s companion=%s refresh=%s",
                tostring(realization.zombieId or ""),
                tostring(realization.selectionStatus or ""),
                tostring(realization.variantId or ""),
                tostring(realization.payload and realization.payload.mediaMode or ""),
                tostring(realization.proofItemStatus or ""),
                tostring(realization.attachmentStatus or ""),
                tostring(realization.companionCaseStatus or ""),
                tostring(realization.needsVisualRefresh == true)
            )
        )
    end
end

local function markSelectionState(deps, zombie, spec, source, selection, status, reason, payload)
    NMServerZombieAssignmentOutcomeShared.stampSelectionState(zombie, spec, {
        status = tostring(status or "excluded"),
        reason = tostring(reason or "selection_state"),
        assignmentSource = source,
        strategyName = deps.constants and deps.constants.STRATEGY_NAME or "",
        selection = selection,
        payload = payload,
        lastAttemptTick = tonumber(deps.diag and deps.diag.ticks or 0) or 0
    })
end

local function markFailed(deps, zombie, spec, reason, source, payload)
    local diag = deps.diag or {}
    NMServerZombieAssignmentOutcomeShared.stampFailedState(zombie, spec or getStampedVariantSpec(deps, zombie), {
        reason = tostring(reason or "unknown"),
        assignmentSource = source,
        strategyName = deps.constants and deps.constants.STRATEGY_NAME or "",
        payload = payload,
        failedTick = tonumber(diag.ticks or 0) or 0,
        lastAttemptTick = tonumber(diag.ticks or 0) or 0
    })
end

function NMServerMPZombieAssignmentExecutor.applyAssignmentOutcome(zombie, source, deps)
    local diag = deps.diag
    diag.attachAttempts = (diag.attachAttempts or 0) + 1
    local zombieMd = getModData(deps, zombie)
    local wantedUuid = tostring(zombieMd and zombieMd.deviceUUID or "")
    local outcome = NMServerZombieAssignmentApplyShared.applyAssignment(zombie, {
        deps = deps,
        strategyName = deps.constants and deps.constants.STRATEGY_NAME or "",
        wantedUuid = wantedUuid,
        pruneManagedCompanionCase = true,
        companionCaseSource = source,
        companionCaseRuntimeLabel = "mp"
    })
    if outcome.status == "suppressed" then
        diag.attachSuppressed = (diag.attachSuppressed or 0) + 1
        markSelectionState(deps, zombie, getSpecForVariantId(outcome.selection and outcome.selection.variantId or ""), source, outcome.selection, outcome.status, outcome.reason, outcome.payload)
        noteRealization(deps, zombie, outcome)
        logMPAssignmentOutcome(deps, zombie, source, outcome)
        return false
    end
    if outcome.status == "excluded" or outcome.status == "media_only" then
        diag.attachExcluded = (diag.attachExcluded or 0) + 1
        diag.attachExcludedScrubbed = (diag.attachExcludedScrubbed or 0) + (tonumber(outcome.removedCount) or 0)
        markSelectionState(deps, zombie, getSpecForVariantId(outcome.selection and outcome.selection.variantId or ""), source, outcome.selection, outcome.status, outcome.reason, outcome.payload)
        noteRealization(deps, zombie, outcome)
        logMPAssignmentOutcome(deps, zombie, source, outcome)
        return false
    end
    if not outcome.ok then
        markFailed(deps, zombie, outcome.spec, outcome.reason, source, outcome.payload)
        diag.attachFailure = (diag.attachFailure or 0) + 1
        noteRealization(deps, zombie, outcome)
        logMPAssignmentOutcome(deps, zombie, source, outcome)
        return false
    end
    diag.attachSuccess = (diag.attachSuccess or 0) + 1
    diag.strategyAssignments = (diag.strategyAssignments or 0) + 1
    markResolved(deps, zombie, outcome.spec, outcome.item, source, nil, outcome.payload)
    noteRealization(deps, zombie, outcome)
    logMPAssignmentOutcome(deps, zombie, source, outcome)
    sampleAttachmentLifecycle(
        diag,
        zombie,
        tostring(outcome.item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(outcome.item) and NMDeviceState.peek(outcome.item).deviceUUID or ""),
        deps
    )
    return true
end

return NMServerMPZombieAssignmentExecutor
