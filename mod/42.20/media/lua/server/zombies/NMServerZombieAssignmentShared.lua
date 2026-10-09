-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadResolver"
require "zombies/NMZombieMediaPayloadRuntime"

NMServerZombieAssignmentShared = NMServerZombieAssignmentShared or {}

local KNOWN_SPECS = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getAllRealizationSpecs and NMZombieDeviceVariantCatalog.getAllRealizationSpecs() or {}

local function resolveGetModData(deps)
    return deps and deps.getModData or NMZombieAudioVisualSupport and NMZombieAudioVisualSupport.getProofModData or nil
end

function NMServerZombieAssignmentShared.getModData(zombie, deps)
    local fn = resolveGetModData(deps)
    return fn and fn(zombie) or nil
end

function NMServerZombieAssignmentShared.getZombieRuntimeId(zombie)
    local onlineId = zombie and zombie.getOnlineID and zombie:getOnlineID() or nil
    if tonumber(onlineId) and tonumber(onlineId) >= 0 then
        return tostring(onlineId)
    end
    local objectId = zombie and zombie.getObjectID and zombie:getObjectID() or nil
    if tonumber(objectId) and tonumber(objectId) >= 0 then
        return tostring(objectId)
    end
    return tostring(zombie or "")
end

function NMServerZombieAssignmentShared.getSpecForVariantId(variantId)
    return NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getSpec and NMZombieDeviceVariantCatalog.getSpec(variantId) or nil
end

function NMServerZombieAssignmentShared.getStampedVariantSpec(zombie, deps)
    local md = NMServerZombieAssignmentShared.getModData(zombie, deps)
    return NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.resolveStoredSpec and NMZombieDeviceVariantCatalog.resolveStoredSpec(md) or nil
end

function NMServerZombieAssignmentShared.resolveSelectionContext(zombie, selection)
    if not (NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.isMusicSelection and NMZombieDeviceVariantCatalog.isMusicSelection(selection) == true) then
        return nil, nil, "ledger_selected_false"
    end
    local zombieId = NMZombieVisualTargetContract and NMZombieVisualTargetContract.getZombieId and NMZombieVisualTargetContract.getZombieId(zombie)
        or NMServerZombieAssignmentShared.getZombieRuntimeId(zombie)
    local baseSpec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.resolveRealization and NMZombieDeviceVariantCatalog.resolveRealization(selection, zombieId) or nil
    if not baseSpec then
        return nil, nil, "unknown_variant"
    end
    local shouldRealize = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.shouldRealizeSelection and NMZombieDeviceVariantCatalog.shouldRealizeSelection(selection)
    local spec = shouldRealize == true and baseSpec or nil
    local payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.resolveZombiePayload and NMZombieMediaPayloadResolver.resolveZombiePayload(selection, zombieId, spec) or nil
    return spec, payload, shouldRealize == true and nil or "device_disabled"
end

function NMServerZombieAssignmentShared.summarizePayload(payload)
    return {
        mediaMode = tostring(payload and payload.mediaMode or ""),
        mediaCategory = tostring(payload and payload.mediaCategory or ""),
        deviceEnabled = payload and payload.deviceEnabled == true or false,
        mediaEnabled = payload and payload.mediaEnabled == true or false,
        insertedMediaFullType = tostring(payload and payload.insertedMediaFullType or ""),
        caseFullType = tostring(payload and payload.caseFullType or ""),
        caseEmptyType = tostring(payload and payload.caseEmptyType or ""),
        headphoneItemFullType = tostring(payload and payload.headphoneItemFullType or "")
    }
end

function NMServerZombieAssignmentShared.buildRealizationContract(zombie, status, selection, spec, payload, details)
    local contract = type(details) == "table" and details or {}
    return {
        zombieId = NMServerZombieAssignmentShared.getZombieRuntimeId(zombie),
        selectionStatus = tostring(status or ""),
        selected = selection and selection.selected == true or false,
        selectionEpoch = tonumber(selection and selection.selectionEpoch) or 0,
        selectionSource = tostring(selection and selection.selectionSource or ""),
        variantId = tostring(spec and spec.variantId or selection and selection.variantId or ""),
        fullType = tostring(spec and spec.fullType or ""),
        attachmentLocation = tostring(spec and spec.attachmentLocation or ""),
        modelAttachmentName = tostring(spec and spec.modelAttachmentName or ""),
        payload = NMServerZombieAssignmentShared.summarizePayload(payload),
        proofItemStatus = tostring(contract.proofItemStatus or ""),
        proofDeviceUUID = tostring(contract.proofDeviceUUID or ""),
        attachmentStatus = tostring(contract.attachmentStatus or ""),
        companionCaseStatus = tostring(contract.companionCaseStatus or ""),
        companionCaseReason = tostring(contract.companionCaseReason or ""),
        removedCount = tonumber(contract.removedCount) or 0,
        usedInventoryFallback = contract.usedInventoryFallback == true,
        needsVisualRefresh = contract.needsVisualRefresh == true
    }
end

function NMServerZombieAssignmentShared.findAttachedProofItem(zombie, spec, opts)
    opts = opts or {}
    local resolved = type(spec) == "table" and spec or NMServerZombieAssignmentShared.getStampedVariantSpec(zombie, opts.deps)
    if not resolved then
        return nil, { usedInventoryFallback = false }
    end
    local attachedItem = NMZombieAudioVisualSupport.findAttachedProofItem(zombie, resolved)
    if attachedItem then
        return attachedItem, { usedInventoryFallback = false }
    end
    if opts.allowInventoryFallback ~= true then
        return nil, { usedInventoryFallback = false }
    end

    local md = NMServerZombieAssignmentShared.getModData(zombie, opts.deps)
    local status = tostring(md and md.status or "")
    local wantedUuid = tostring(opts.wantedUuid or md and md.deviceUUID or "")
    if status == "attached" then
        local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
        local items = inventory and inventory.getItems and inventory:getItems() or nil
        if items and items.size then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
                if fullType == tostring(resolved.fullType or "") then
                    if wantedUuid == "" then
                        return item, { usedInventoryFallback = false }
                    end
                    local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
                    local uuid = tostring(state and state.deviceUUID or "")
                    if uuid == wantedUuid then
                        return item, { usedInventoryFallback = true }
                    end
                end
            end
        end
    end

    return nil, { usedInventoryFallback = false }
end

function NMServerZombieAssignmentShared.zombieSupportsProofLocation(zombie, spec)
    local wantedLocation = tostring(spec and spec.attachmentLocation or "")
    if wantedLocation == "" then
        return false
    end
    local attachedItems = zombie and zombie.getAttachedItems and zombie:getAttachedItems() or nil
    local group = attachedItems and attachedItems.getGroup and attachedItems:getGroup() or nil
    if not (group and group.size and group.getLocationByIndex) then
        return false
    end
    for i = 0, group:size() - 1 do
        local entry = group:getLocationByIndex(i)
        local locationId = entry and entry.getId and tostring(entry:getId() or "") or ""
        if locationId == wantedLocation then
            return true
        end
    end
    return false
end

function NMServerZombieAssignmentShared.findInventoryProofItem(zombie, spec, opts)
    opts = opts or {}
    local wantedUuid = tostring(opts.wantedUuid or "")
    return NMZombieAudioVisualSupport.findInventoryProofItem(zombie, spec, wantedUuid)
end

function NMServerZombieAssignmentShared.addInventoryProofItem(zombie, spec)
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    if not (inventory and inventory.AddItem) then
        return nil, "missing_inventory"
    end
    local item = NMZombieAudioVisualSupport.addInventoryItem(inventory, spec)
    if not item then
        return nil, "item_add_failed"
    end
    return item, nil
end

function NMServerZombieAssignmentShared.removeInventoryItem(zombie, item)
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    NMZombieAudioVisualSupport.removeInventoryItem(inventory, item)
end

function NMServerZombieAssignmentShared.clearKnownProofStates(zombie, keepVariantId)
    local removed = 0
    for i = 1, #KNOWN_SPECS do
        local spec = KNOWN_SPECS[i]
        if tostring(spec.variantId or "") ~= tostring(keepVariantId or "") then
            removed = removed + NMZombieAudioVisualSupport.scrubZombieProofState(zombie, spec, "")
        end
    end
    return removed
end

function NMServerZombieAssignmentShared.getStoredPayload(zombie, deps)
    local md = NMServerZombieAssignmentShared.getModData(zombie, deps)
    return NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.resolveStoredPayload and NMZombieMediaPayloadResolver.resolveStoredPayload(md) or nil
end

function NMServerZombieAssignmentShared.applyAttachedAuthority(zombie, item, state)
    local authority = NMAuthorityV4 or NMAuthorityV3
    if not (authority and authority.applyIntent and state) then
        return
    end
    local square = zombie and zombie.getCurrentSquare and zombie:getCurrentSquare() or nil
    authority.applyIntent(state, "request_attached", {
        sourceX = square and (square:getX() + 0.5) or zombie and zombie.getX and zombie:getX() or 0,
        sourceY = square and (square:getY() + 0.5) or zombie and zombie.getY and zombie:getY() or 0,
        sourceZ = square and square:getZ() or zombie and zombie.getZ and zombie:getZ() or 0,
        sourceOwner = tostring(zombie and zombie.getOnlineID and zombie:getOnlineID() or zombie and zombie.getObjectID and zombie:getObjectID() or ""),
        sourceMode = "attached"
    })
end

function NMServerZombieAssignmentShared.initializeProofState(zombie, item, spec, strategyName)
    local _, state, reason = NMZombieAudioVisualSupport.initializeProofState(
        zombie,
        item,
        spec,
        tostring(strategyName or ""),
        NMServerZombieAssignmentShared.applyAttachedAuthority
    )
    return state, reason
end

function NMServerZombieAssignmentShared.applyPayloadToProofState(zombie, item, spec, payload, strategyName)
    local state, reason = NMServerZombieAssignmentShared.initializeProofState(zombie, item, spec, strategyName)
    if reason then
        return nil, reason
    end
    NMZombieMediaPayloadRuntime.applyPayloadToState(state, payload)
    if spec and spec.variantId == "boombox" then
        state.playbackMode = "world"
    elseif spec and (spec.variantId == "walkman" or spec.variantId == "cd_player") then
        state.playbackMode = "personal"
    end
    if NMDeviceState and NMDeviceState.bumpRevision then
        NMDeviceState.bumpRevision(state)
    end
    return state, nil
end

function NMServerZombieAssignmentShared.finalizePayloadSync(zombie, payload, previousPayload)
    NMZombieMediaPayloadRuntime.syncInventoryPayload(zombie, payload, previousPayload)
    NMZombieAudioVisualSupport.stampCorpseCaseIntent(zombie, payload)
end

return NMServerZombieAssignmentShared
