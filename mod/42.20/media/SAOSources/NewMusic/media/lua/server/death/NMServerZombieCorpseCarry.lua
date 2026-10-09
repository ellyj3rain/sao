NMServerZombieCorpseCarry = NMServerZombieCorpseCarry or {}
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadResolver"
require "zombies/NMZombieMediaPayloadRuntime"
require "death/NMServerZombieCorpseTransferRecord"
require "death/NMServerZombieCorpseMutationSupport"

local KNOWN_SPECS = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getAllRealizationSpecs and NMZombieDeviceVariantCatalog.getAllRealizationSpecs() or {}

NMServerZombieCorpseCarry._diag = NMServerZombieCorpseCarry._diag or {
    corpseCaptureSkip = 0,
    corpseCaptureQueued = 0,
    corpseCaptureRejected = 0,
    corpseCaptureInventoryFallback = 0,
    corpseSpawnSkip = 0,
    corpseAlreadyPresent = 0,
    corpsePruned = 0,
    corpseCarrySuccess = 0,
    corpseCarryFailed = 0,
    corpseCaptureSPRuntime = 0,
    corpseCaptureMPRuntimeSupport = 0,
    corpseCaptureMPAssignment = 0,
    corpseTickReconciled = 0
}

local TICK_RECONCILE_INTERVAL = 30

local function canRunAuthoritativeMutation()
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true then
        return false
    end
    if NMAuthorityContract and NMAuthorityContract.canMutateDurableStateAtRuntime then
        return NMAuthorityContract.canMutateDurableStateAtRuntime() == true
    end
    return true
end

local function shouldLogProofVerbose()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_corpse") == true
end

local function logProof(tag, detail, force)
    if not force and not shouldLogProofVerbose() then
        return
    end
    print("[NewMusic] [ZombieProof] " .. tostring(tag or "") .. " " .. tostring(detail or ""))
end

local function shouldLogCorpseRuntimeIdentity()
    return (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") == true)
        or shouldLogProofVerbose()
end

local function logCorpseRuntimeIdentity(stage, item, profile, state, record)
    if not shouldLogCorpseRuntimeIdentity() then
        return
    end
    local payload = type(record) == "table" and type(record.payload) == "table" and record.payload or nil
    local detail = string.format(
        "stage=%s fullType=%s deviceUUID=%s media=%s mediaMode=%s payloadMedia=%s mediaIndex=%s headphones=%s batteryPresent=%s batteryCharge=%.3f authoritativeMode=%s sourceKind=%s sourceOwner=%s sourceGeneration=%s playbackMode=%s zombieDormant=%s",
        tostring(stage or "unknown"),
        tostring(item and item.getFullType and item:getFullType() or record and record.fullType or ""),
        tostring(state and state.deviceUUID or ""),
        tostring(state and state.mediaFullType or "nil"),
        tostring(payload and payload.mediaMode or "nil"),
        tostring(payload and payload.insertedMediaFullType or "nil"),
        tostring(state and state.mediaRecordedMediaIndex or "nil"),
        tostring(state and state.headphoneItemFullType or "nil"),
        tostring(state and state.batteryPresent == true),
        tonumber(state and state.batteryCharge) or 0.0,
        tostring(state and state.authoritativeMode or ""),
        tostring(state and state.sourceKind or ""),
        tostring(state and state.sourceOwner or ""),
        tostring(state and state.sourceGeneration or 0),
        tostring(state and state.playbackMode or ""),
        tostring(state and state.zombieDormant == true)
    )
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") == true then
        NMCore.logChannel("runtime", "corpse_item_identity", detail)
    end
    if shouldLogProofVerbose() then
        logProof("corpse_item_identity", detail, true)
    end
end

local function logCorpseSummary(tag)
    if not shouldLogProofVerbose() then
        return
    end
    local d = NMServerZombieCorpseCarry._diag or {}
    logProof(
        tag or "corpse_summary",
        string.format(
            "captureSkip=%s queued=%s rejected=%s inventoryFallback=%s spawnSkip=%s alreadyPresent=%s pruned=%s carrySuccess=%s carryFailed=%s spRuntime=%s mpRuntimeSupport=%s mpAssignment=%s",
            tostring(d.corpseCaptureSkip or 0),
            tostring(d.corpseCaptureQueued or 0),
            tostring(d.corpseCaptureRejected or 0),
            tostring(d.corpseCaptureInventoryFallback or 0),
            tostring(d.corpseSpawnSkip or 0),
            tostring(d.corpseAlreadyPresent or 0),
            tostring(d.corpsePruned or 0),
            tostring(d.corpseCarrySuccess or 0),
            tostring(d.corpseCarryFailed or 0),
            tostring(d.corpseCaptureSPRuntime or 0),
            tostring(d.corpseCaptureMPRuntimeSupport or 0),
            tostring(d.corpseCaptureMPAssignment or 0)
        )
    )
end

local function entityDebugId(entity)
    return tostring(entity and entity.getOnlineID and entity:getOnlineID() or entity and entity.getObjectID and entity:getObjectID() or "unknown")
end

local function isIsoZombie(obj)
    return obj and instanceof and instanceof(obj, "IsoZombie")
end

local function isIsoDeadBody(obj)
    return obj and instanceof and instanceof(obj, "IsoDeadBody")
end

local function getModData(holder)
    return NMZombieAudioVisualSupport.getProofModData(holder)
end

local function getRootModData(holder)
    return holder and holder.getModData and holder:getModData() or nil
end

local function getSquareKey(x, y, z)
    return table.concat({ tostring(x or 0), tostring(y or 0), tostring(z or 0) }, ":")
end

local function parseSquareKey(key)
    local x, y, z = tostring(key or ""):match("^([^:]+):([^:]+):([^:]+)$")
    return tonumber(x), tonumber(y), tonumber(z)
end

local function getEntitySquare(entity)
    return entity and entity.getCurrentSquare and entity:getCurrentSquare()
        or entity and entity.getSquare and entity:getSquare()
        or nil
end

local function getSpecForVariantId(variantId)
    return NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getSpec and NMZombieDeviceVariantCatalog.getSpec(variantId) or nil
end

local transferRecordSupport = NMServerZombieCorpseTransferRecord.new({
    knownSpecs = KNOWN_SPECS,
    getModData = getModData,
    getRootModData = getRootModData,
    logProof = logProof
})

local mutationSupport = NMServerZombieCorpseMutationSupport.new({
    logProof = logProof,
    logCorpseRuntimeIdentity = logCorpseRuntimeIdentity,
    getModData = getModData,
    getRootModData = getRootModData,
    isIsoDeadBody = isIsoDeadBody
})

-- Corpse flow source of truth:
-- 1. transfer record capture
-- 2. corpse pending queue
-- 3. body match/reconcile
-- 4. corpse settlement stamping

local function shouldCarryCorpseProof(zombie, record, selection)
    if type(selection) == "table" then
        return selection.selected == true or selection.musicSelected == true
    end
    local stamped = NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getStampedSelection and NMZombieVisualTargetLedger.getStampedSelection(zombie) or nil
    if stamped then
        return stamped.selected == true or stamped.musicSelected == true
    end
    return false
end

local function verifyWornItem(character, fullType)
    local wanted = tostring(fullType or "")
    if wanted == "" then
        return nil
    end
    local wornItems = character and character.getWornItems and character:getWornItems() or nil
    if not wornItems then
        return nil
    end
    local size = wornItems.size and tonumber(wornItems:size()) or wornItems.getSize and tonumber(wornItems:getSize()) or -1
    if size <= 0 then
        return nil
    end
    for i = 0, size - 1 do
        local entry = wornItems.get and wornItems:get(i) or wornItems.getItemByIndex and wornItems:getItemByIndex(i) or nil
        local item = entry and entry.getItem and entry:getItem() or entry and entry.getInventoryItem and entry:getInventoryItem() or entry
        local itemFullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if itemFullType == wanted then
            return item
        end
    end
    return nil
end

local function logLiveCaptureProbe(zombie, record)
    if not shouldLogProofVerbose() then
        return
    end
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    local items = inventory and inventory.getItems and inventory:getItems() or nil
    local wantedUuid = tostring(record and record.deviceUUID or "")
    local inventoryHasProof = false
    if items and items.size then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if fullType == tostring(record and record.fullType or "") then
                local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
                local uuid = tostring(state and state.deviceUUID or "")
                if wantedUuid == "" or uuid == wantedUuid then
                    inventoryHasProof = true
                    break
                end
            end
        end
    end
    local supportWorn = verifyWornItem(zombie, "Base.Belt2") ~= nil
    local square = getEntitySquare(zombie)
    local selection = type(record) == "table" and record.selection
        or NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getOrAssignZombieSelection and NMZombieVisualTargetLedger.getOrAssignZombieSelection(zombie, tostring(record and record.strategy or ""))
        or nil
    logProof(
        "live_capture_probe",
        string.format(
            "zombie=%s square=%s:%s:%s strategy=%s selected=%s proofUuid=%s attachedRecord=%s inventoryHasProof=%s supportWorn=%s",
            tostring(entityDebugId(zombie)),
            tostring(square and square:getX() or "nil"),
            tostring(square and square:getY() or "nil"),
            tostring(square and square:getZ() or "nil"),
            tostring(record and record.strategy or ""),
            tostring(selection and (selection.selected == true or selection.musicSelected == true)),
            tostring(record and record.deviceUUID or ""),
            tostring(record ~= nil),
            tostring(inventoryHasProof),
            tostring(supportWorn)
        )
    )
end

local function logCorpseLooseLoot(tag, entity, record)
    if not shouldLogProofVerbose() then
        return
    end
    local looseLoot = type(record and record.corpseLooseLootFullTypes) == "table" and record.corpseLooseLootFullTypes or {}
    local joined = (#looseLoot > 0) and table.concat(looseLoot, ",") or "(none)"
    local payload = record and record.payload or nil
    local contract = type(record and record.companionCaseContract) == "table" and record.companionCaseContract or nil
    local spawnAttempted = tostring(record and record.spawnAtDeathCompanionAttempted or "")
    local spawnRegistered = record and record.spawnAtDeathCompanionRegistered == true or false
    local spawnRoute = tostring(record and record.spawnAtDeathCompanionRoute or "")
    logProof(
        tag,
        string.format(
            "id=%s variant=%s mediaMode=%s looseLoot=%s contractMode=%s contractFullType=%s contractDeviceUUID=%s spawnAttempted=%s spawnRegistered=%s spawnRoute=%s fullType=%s",
            tostring(entityDebugId(entity)),
            tostring(record and record.variantId or ""),
            tostring(payload and payload.mediaMode or ""),
            tostring(joined),
            tostring(contract and contract.mode or ""),
            tostring(contract and contract.fullType or ""),
            tostring(contract and contract.deviceUUID or ""),
            tostring(spawnAttempted ~= ""),
            tostring(spawnRegistered),
            tostring(spawnRoute),
            tostring(record and record.fullType or "")
        ),
        true
    )
end

local function logCorpseSpawnPath(tag, body, detail)
    if not shouldLogProofVerbose() then
        return
    end
    local square = getEntitySquare(body)
    logProof(
        tag,
        string.format(
            "id=%s square=%s:%s:%s detail=%s",
            tostring(entityDebugId(body)),
            tostring(square and square:getX() or "nil"),
            tostring(square and square:getY() or "nil"),
            tostring(square and square:getZ() or "nil"),
            tostring(detail or "")
        ),
        true
    )
end

local function findLiveProofPresence(zombie, spec, wantedUuid)
    local attachedProof = false
    local inventoryProof = false
    local resolvedSpec = type(spec) == "table" and spec or nil
    if resolvedSpec then
        attachedProof = NMZombieAudioVisualSupport.findAttachedProofItem(zombie, resolvedSpec) ~= nil
        inventoryProof = NMZombieAudioVisualSupport.findInventoryProofItem(zombie, resolvedSpec, wantedUuid) ~= nil
    else
        for i = 1, #KNOWN_SPECS do
            local candidate = KNOWN_SPECS[i]
            if not attachedProof and NMZombieAudioVisualSupport.findAttachedProofItem(zombie, candidate) then
                attachedProof = true
            end
            if not inventoryProof and NMZombieAudioVisualSupport.findInventoryProofItem(zombie, candidate, wantedUuid) then
                inventoryProof = true
            end
            if attachedProof and inventoryProof then
                break
            end
        end
    end
    return attachedProof, inventoryProof
end

local function logCorpseCaptureSkip(zombie, square, reason)
    if not shouldLogProofVerbose() then
        return
    end
    local md = getModData(zombie)
    local payload = NMZombieMediaPayloadResolver
        and NMZombieMediaPayloadResolver.resolveStoredPayload
        and NMZombieMediaPayloadResolver.resolveStoredPayload(md)
        or nil
    local selection = NMZombieVisualTargetLedger
        and NMZombieVisualTargetLedger.getStampedSelection
        and NMZombieVisualTargetLedger.getStampedSelection(zombie)
        or nil
    local spec = NMZombieDeviceVariantCatalog
        and NMZombieDeviceVariantCatalog.resolveStoredSpec
        and NMZombieDeviceVariantCatalog.resolveStoredSpec(md)
        or nil
    local wantedUuid = tostring(md and md.deviceUUID or "")
    local attachedProof, inventoryProof = findLiveProofPresence(zombie, spec, wantedUuid)
    logProof(
        "corpse_capture_skip",
        string.format(
            "zombie=%s reason=%s squarePresent=%s square=%s:%s:%s status=%s selected=%s musicSelected=%s stampedSelected=%s stampedMusicSelected=%s strategy=%s variant=%s fullType=%s deviceUUID=%s mediaMode=%s caseEmpty=%s caseFull=%s contractMode=%s contractFullType=%s contractDeviceUUID=%s attachedProof=%s inventoryProof=%s",
            tostring(entityDebugId(zombie)),
            tostring(reason or ""),
            tostring(square ~= nil),
            tostring(square and square:getX() or "nil"),
            tostring(square and square:getY() or "nil"),
            tostring(square and square:getZ() or "nil"),
            tostring(md and md.status or ""),
            tostring(md and md.selected == true),
            tostring(md and md.musicSelected == true),
            tostring(selection and selection.selected == true or false),
            tostring(selection and selection.musicSelected == true or false),
            tostring(md and (md.strategy or md.liveVisualStrategy) or ""),
            tostring(spec and spec.variantId or md and md.variantId or ""),
            tostring(spec and spec.fullType or md and md.fullType or ""),
            wantedUuid,
            tostring(payload and payload.mediaMode or md and md.mediaMode or ""),
            tostring(payload and payload.caseEmptyType or md and md.caseEmptyType or ""),
            tostring(payload and payload.caseFullType or md and md.caseFullType or ""),
            tostring(md and md.corpseCompanionMode or ""),
            tostring(md and md.corpseCompanionFullType or ""),
            tostring(md and md.corpseCompanionDeviceUUID or ""),
            tostring(attachedProof),
            tostring(inventoryProof)
        )
    )
end

local function getSelectionZombieId(selection)
    if type(selection) ~= "table" then
        return ""
    end
    return tostring(selection.zombieId or "")
end

local function resolveBodyPendingIdentity(body)
    local selection = NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getStampedSelection
        and NMZombieVisualTargetLedger.getStampedSelection(body)
        or nil
    local bodyZombieId = getSelectionZombieId(selection)
    local md = getModData(body)
    return {
        zombieId = bodyZombieId,
        deviceUUID = tostring(md and md.deviceUUID or "")
    }
end

local function pendingTransferMatchesBodyIdentity(pendingTransfer, identity)
    if type(pendingTransfer) ~= "table" or type(identity) ~= "table" then
        return false
    end
    local bodyZombieId = tostring(identity.zombieId or "")
    if bodyZombieId ~= "" then
        return getSelectionZombieId(pendingTransfer.selection or pendingTransfer.record and pendingTransfer.record.selection) == bodyZombieId
    end
    local bodyDeviceUUID = tostring(identity.deviceUUID or "")
    local pendingDeviceUUID = tostring(pendingTransfer.record and pendingTransfer.record.deviceUUID or "")
    return bodyDeviceUUID ~= "" and pendingDeviceUUID ~= "" and pendingDeviceUUID == bodyDeviceUUID
end

local function findBestPendingTransferForBody(body)
    -- Body match phase:
    -- prefer exact finalized identity, then nearest corpse pending queue transfer record.
    local square = getEntitySquare(body)
    if not square then
        return nil, nil
    end
    local bodyX = body and body.getX and tonumber(body:getX()) or square:getX() + 0.5
    local bodyY = body and body.getY and tonumber(body:getY()) or square:getY() + 0.5
    local squareX = square:getX()
    local squareY = square:getY()
    local squareZ = square:getZ()
    local identity = resolveBodyPendingIdentity(body)
    local bestKey = nil
    local bestIndex = nil
    local bestDistance = nil
    local exactKey = nil
    local exactIndex = nil
    local exactDistance = nil

    for dx = -1, 1 do
        for dy = -1, 1 do
            local key = getSquareKey(squareX + dx, squareY + dy, squareZ)
            local queue = NMServerZombieCorpseCarry._pendingBySquare and NMServerZombieCorpseCarry._pendingBySquare[key] or nil
            if type(queue) == "table" then
                for i = 1, #queue do
                    local pendingTransfer = queue[i]
                    if pendingTransfer then
                        local ddx = (tonumber(pendingTransfer.sourceX) or 0) - bodyX
                        local ddy = (tonumber(pendingTransfer.sourceY) or 0) - bodyY
                        local distance = (ddx * ddx) + (ddy * ddy)
                        if pendingTransferMatchesBodyIdentity(pendingTransfer, identity) then
                            if exactDistance == nil or distance < exactDistance then
                                exactKey = key
                                exactIndex = i
                                exactDistance = distance
                            end
                        elseif bestDistance == nil or distance < bestDistance then
                            bestKey = key
                            bestIndex = i
                            bestDistance = distance
                        end
                    end
                end
            end
        end
    end

    if exactKey and exactIndex then
        local exactQueue = NMServerZombieCorpseCarry._pendingBySquare[exactKey]
        return exactQueue and exactQueue[exactIndex] or nil, { key = exactKey, index = exactIndex }
    end

    if not bestKey or not bestIndex then
        return nil, nil
    end
    local queue = NMServerZombieCorpseCarry._pendingBySquare[bestKey]
    return queue and queue[bestIndex] or nil, { key = bestKey, index = bestIndex }
end

local function removePendingTransfer(handle)
    if not handle then
        return
    end
    local queue = NMServerZombieCorpseCarry._pendingBySquare and NMServerZombieCorpseCarry._pendingBySquare[handle.key] or nil
    if type(queue) ~= "table" then
        return
    end
    table.remove(queue, handle.index)
    if #queue == 0 then
        NMServerZombieCorpseCarry._pendingBySquare[handle.key] = nil
    end
    NMServerZombieCorpseCarry._pendingCount = math.max(0, (NMServerZombieCorpseCarry._pendingCount or 0) - 1)
    if (NMServerZombieCorpseCarry._pendingCount or 0) == 0 then
        NMServerZombieCorpseCarry._pendingBySquare = {}
    end
end

local function buildExcludedBodySettlementTransferRecord(bodySelection)
    local bodySpec = getSpecForVariantId(bodySelection and bodySelection.variantId)
    return {
        fullType = tostring(bodySpec and bodySpec.fullType or ""),
        attachmentLocation = tostring(bodySpec and bodySpec.attachmentLocation or ""),
        modelAttachmentName = tostring(bodySpec and bodySpec.modelAttachmentName or ""),
        deviceUUID = "",
        strategy = tostring(bodySelection and bodySelection.strategy or ""),
        selection = bodySelection
    }
end

local function reconcileCompatibilityBodyWithoutPending(body, container)
    -- Compatibility and fallback reconcile only:
    -- canonical corpse carry should arrive through a queued transfer record.
    logCorpseSpawnPath("corpse_spawn_no_pending", body, "no_pending_match")
    local bodySelection = NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getStampedSelection and NMZombieVisualTargetLedger.getStampedSelection(body) or nil
    local hasAnyProof = mutationSupport.containerHasAnyProof(container)
    local _, bodyProofSpec = transferRecordSupport.findAnyKnownProofItem(container)
    -- Compatibility path:
    -- an already-correct body can still be settled without a queued transfer record.
    if bodySelection and (bodySelection.selected == true or bodySelection.musicSelected == true) and hasAnyProof then
        local bodyTransferRecord = transferRecordSupport.buildExistingBodyTransferRecord(body, bodySelection, bodyProofSpec)
        bodyTransferRecord.selection = bodySelection
        logCorpseLooseLoot("corpse_spawn_existing", body, bodyTransferRecord)
        mutationSupport.ensureImmediateCompanionLoot(container, bodyTransferRecord)
        mutationSupport.markCorpseSettled(body, bodyTransferRecord, nil, true)
        NMServerZombieCorpseCarry._diag.corpseAlreadyPresent = (NMServerZombieCorpseCarry._diag.corpseAlreadyPresent or 0) + 1
        return true
    end
    -- Fallback path:
    -- prune contradictory proof items only when the body selection is explicitly not selected.
    if bodySelection and bodySelection.selected ~= true and bodySelection.musicSelected ~= true and hasAnyProof then
        logCorpseSpawnPath("corpse_spawn_prune", body, "selection_not_selected_but_has_proof")
        local pruned = mutationSupport.removeProofItemsByType(container)
        if pruned > 0 then
            NMServerZombieCorpseCarry._diag.corpsePruned = (NMServerZombieCorpseCarry._diag.corpsePruned or 0) + pruned
        end
        mutationSupport.markCorpseSettled(body, buildExcludedBodySettlementTransferRecord(bodySelection), nil, false)
        return true
    end
    logCorpseSpawnPath("corpse_spawn_skip", body, "no_pending_no_existing_path")
    NMServerZombieCorpseCarry._diag.corpseSpawnSkip = (NMServerZombieCorpseCarry._diag.corpseSpawnSkip or 0) + 1
    return false
end

local function reconcilePendingTransferRecord(body, container, pendingTransfer, handle)
    -- Canonical reconcile entry for queued corpse transfer records.
    logCorpseSpawnPath("corpse_spawn_match", body, "pending_match")
    if pendingTransfer.shouldCarry ~= true then
        logCorpseSpawnPath("corpse_spawn_reject", body, "pending_shouldCarry_false")
        local pruned = mutationSupport.removeMatchingRecordItems(container, pendingTransfer.record)
        if pruned > 0 then
            NMServerZombieCorpseCarry._diag.corpsePruned = (NMServerZombieCorpseCarry._diag.corpsePruned or 0) + pruned
        end
        mutationSupport.markCorpseSettled(body, pendingTransfer.record, nil, false)
        removePendingTransfer(handle)
        return true
    end

    logCorpseLooseLoot("corpse_spawn_pending", body, pendingTransfer.record)
    local hadMatchingRecord = mutationSupport.containerHasMatchingRecord(container, pendingTransfer.record)
    local ok, detail = mutationSupport.applyCorpseRecord(container, pendingTransfer.record)
    if ok then
        local keeper = mutationSupport.findMatchingRecordItem(container, pendingTransfer.record)
        local pruned = mutationSupport.enforceSingleCorpseProofItem(container, pendingTransfer.record, keeper)
        if tonumber(pruned) and pruned > 0 then
            NMServerZombieCorpseCarry._diag.corpsePruned = (NMServerZombieCorpseCarry._diag.corpsePruned or 0) + pruned
        end
        mutationSupport.ensureImmediateCompanionLoot(container, pendingTransfer.record)
        logCorpseSpawnPath(hadMatchingRecord and "corpse_spawn_match_existing" or "corpse_spawn_apply_ok", body, tostring(detail or "ok"))
        mutationSupport.markCorpseSettled(body, pendingTransfer.record, detail, true)
        if hadMatchingRecord then
            NMServerZombieCorpseCarry._diag.corpseAlreadyPresent = (NMServerZombieCorpseCarry._diag.corpseAlreadyPresent or 0) + 1
        else
            NMServerZombieCorpseCarry._diag.corpseCarrySuccess = (NMServerZombieCorpseCarry._diag.corpseCarrySuccess or 0) + 1
        end
        removePendingTransfer(handle)
        return true
    end

    logCorpseSpawnPath("corpse_spawn_apply_failed", body, tostring(detail or "unknown"))
    NMServerZombieCorpseCarry._diag.corpseCarryFailed = (NMServerZombieCorpseCarry._diag.corpseCarryFailed or 0) + 1
    logProof("corpse_carry_failed", "reason=" .. tostring(detail or "unknown"), true)
    return false
end

local function reconcileCorpseBody(body)
    if not canRunAuthoritativeMutation() then
        return false
    end
    if not isIsoDeadBody(body) then
        return false
    end
    -- Reconcile phase:
    -- corpse carry mutates only from explicit transfer records plus fenced compatibility paths.
    logCorpseSpawnPath("corpse_spawn_enter", body, "enter")
    local container = body.getContainer and body:getContainer() or nil
    if not container then
        logCorpseSpawnPath("corpse_spawn_skip", body, "missing_container")
        NMServerZombieCorpseCarry._diag.corpseSpawnSkip = (NMServerZombieCorpseCarry._diag.corpseSpawnSkip or 0) + 1
        return false
    end

    local md = getModData(body)
    if md and md.corpseSettled == true then
        logCorpseSpawnPath("corpse_spawn_skip", body, "already_settled")
        NMServerZombieCorpseCarry._diag.corpseSpawnSkip = (NMServerZombieCorpseCarry._diag.corpseSpawnSkip or 0) + 1
        return false
    end

    local pendingTransfer, handle = findBestPendingTransferForBody(body)
    if not pendingTransfer then
        return reconcileCompatibilityBodyWithoutPending(body, container)
    end

    return reconcilePendingTransferRecord(body, container, pendingTransfer, handle)
end

local function noteCorpseCaptureStrategy(record)
    if tostring(record and record.strategy or "") == "sp_runtime_attach" then
        NMServerZombieCorpseCarry._diag.corpseCaptureSPRuntime = (NMServerZombieCorpseCarry._diag.corpseCaptureSPRuntime or 0) + 1
    elseif tostring(record and record.strategy or "") == "mp_runtime_attach_with_support" then
        NMServerZombieCorpseCarry._diag.corpseCaptureMPRuntimeSupport = (NMServerZombieCorpseCarry._diag.corpseCaptureMPRuntimeSupport or 0) + 1
    elseif tostring(record and record.strategy or "") == "mp_assignment_flow" then
        NMServerZombieCorpseCarry._diag.corpseCaptureMPAssignment = (NMServerZombieCorpseCarry._diag.corpseCaptureMPAssignment or 0) + 1
    end
end

local function enqueueCorpsePendingTransferRecord(square, zombie, transferRecord)
    -- Pending enqueue phase:
    -- queue the captured zombie-to-corpse transfer record until a body can be reconciled.
    local key = getSquareKey(square:getX(), square:getY(), square:getZ())
    NMServerZombieCorpseCarry._pendingBySquare = NMServerZombieCorpseCarry._pendingBySquare or {}
    local queue = NMServerZombieCorpseCarry._pendingBySquare[key]
    if type(queue) ~= "table" then
        queue = {}
        NMServerZombieCorpseCarry._pendingBySquare[key] = queue
    end
    local pendingTransfer = {
        record = transferRecord,
        selection = transferRecord.selection,
        sourceX = zombie and zombie.getX and tonumber(zombie:getX()) or square:getX() + 0.5,
        sourceY = zombie and zombie.getY and tonumber(zombie:getY()) or square:getY() + 0.5,
        sourceZ = zombie and zombie.getZ and tonumber(zombie:getZ()) or square:getZ()
    }
    pendingTransfer.shouldCarry = shouldCarryCorpseProof(zombie, transferRecord, pendingTransfer.selection) == true
    queue[#queue + 1] = pendingTransfer
    NMServerZombieCorpseCarry._pendingCount = (NMServerZombieCorpseCarry._pendingCount or 0) + 1
    NMServerZombieCorpseCarry._diag.corpseCaptureQueued = (NMServerZombieCorpseCarry._diag.corpseCaptureQueued or 0) + 1
    if pendingTransfer.shouldCarry ~= true then
        NMServerZombieCorpseCarry._diag.corpseCaptureRejected = (NMServerZombieCorpseCarry._diag.corpseCaptureRejected or 0) + 1
    end
    noteCorpseCaptureStrategy(transferRecord)
    if ((NMServerZombieCorpseCarry._diag.corpseCaptureQueued or 0) % 10) == 0 then
        logCorpseSummary("corpse_capture_summary")
    end
end

function NMServerZombieCorpseCarry.onZombieDead(zombie)
    if not canRunAuthoritativeMutation() then
        return
    end
    if not isIsoZombie(zombie) then
        return
    end
    local square = getEntitySquare(zombie)
    -- Capture phase:
    -- export the zombie-to-corpse transfer record exactly once at death time.
    local transferRecord = transferRecordSupport.buildCorpseTransferRecord(zombie, NMServerZombieCorpseCarry._diag)
    if not (square and transferRecord) then
        NMServerZombieCorpseCarry._diag.corpseCaptureSkip = (NMServerZombieCorpseCarry._diag.corpseCaptureSkip or 0) + 1
        logCorpseCaptureSkip(zombie, square, square and "missing_transfer_record" or "missing_square")
        return
    end
    transferRecord.selection = NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getOrAssignZombieSelection and NMZombieVisualTargetLedger.getOrAssignZombieSelection(zombie, tostring(transferRecord.strategy or "")) or nil
    logLiveCaptureProbe(zombie, transferRecord)
    logCorpseLooseLoot("corpse_capture", zombie, transferRecord)
    enqueueCorpsePendingTransferRecord(square, zombie, transferRecord)
end

function NMServerZombieCorpseCarry.onDeadBodySpawn(body)
    reconcileCorpseBody(body)
end

local function reconcilePendingCorpseSquares()
    if (NMServerZombieCorpseCarry._pendingCount or 0) <= 0 then
        return 0
    end
    local pendingBySquare = NMServerZombieCorpseCarry._pendingBySquare or nil
    if type(pendingBySquare) ~= "table" then
        return 0
    end
    local cell = getCell and getCell() or nil
    if not cell then
        return 0
    end
    local reconciled = 0
    for key, queue in pairs(pendingBySquare) do
        if type(queue) == "table" and #queue > 0 then
            local x, y, z = parseSquareKey(key)
            if x and y and z then
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local square = cell:getGridSquare(x + dx, y + dy, z)
                        local bodies = square and square.getStaticMovingObjects and square:getStaticMovingObjects() or nil
                        if bodies and bodies.size then
                            for i = 0, bodies:size() - 1 do
                                local body = bodies:get(i)
                                if isIsoDeadBody(body) and reconcileCorpseBody(body) then
                                    reconciled = reconciled + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return reconciled
end

function NMServerZombieCorpseCarry.hasPendingWork()
    return (tonumber(NMServerZombieCorpseCarry._pendingCount) or 0) > 0
end

function NMServerZombieCorpseCarry.onTick()
    if not NMServerZombieCorpseCarry.hasPendingWork() then
        return
    end
    NMServerZombieCorpseCarry._tickCounter = (tonumber(NMServerZombieCorpseCarry._tickCounter) or 0) + 1
    if (NMServerZombieCorpseCarry._tickCounter % TICK_RECONCILE_INTERVAL) ~= 0 then
        return
    end
    local reconciled = reconcilePendingCorpseSquares()
    if reconciled > 0 then
        NMServerZombieCorpseCarry._diag.corpseTickReconciled = (NMServerZombieCorpseCarry._diag.corpseTickReconciled or 0) + reconciled
        logProof("corpse_tick_reconcile", "reconciled=" .. tostring(reconciled), true)
    end
end

return NMServerZombieCorpseCarry
