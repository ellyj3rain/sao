-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMZombieAudioVisualSupport = NMZombieAudioVisualSupport or {}
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadResolver"
require "zombies/NMZombieMediaPayloadRuntime"

NMZombieAudioVisualSupport.ModDataKey = "nmZombieWalkmanProof"
NMZombieAudioVisualSupport.DefaultSpec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getDefaultSpec and NMZombieDeviceVariantCatalog.getDefaultSpec() or {
    variantId = "walkman",
    fullType = "NewMusic.WalkmanBlue",
    attachmentLocation = "Walkie Belt Left",
    modelAttachmentName = "walkie_belt_left",
    stopReason = "zombie_walkman_proof"
}
NMZombieAudioVisualSupport.DefaultWalkmanSpec = NMZombieAudioVisualSupport.DefaultSpec

local function resolveSpec(spec)
    local incoming = type(spec) == "table" and spec or {}
    local fallback = NMZombieAudioVisualSupport.DefaultSpec
    return {
        variantId = tostring(incoming.variantId or fallback.variantId),
        fullType = tostring(incoming.fullType or fallback.fullType),
        attachmentLocation = tostring(incoming.attachmentLocation or fallback.attachmentLocation),
        modelAttachmentName = tostring(incoming.modelAttachmentName or fallback.modelAttachmentName),
        stopReason = tostring(incoming.stopReason or fallback.stopReason),
        ensureItem = incoming.ensureItem ~= nil and tostring(incoming.ensureItem) or fallback.ensureItem
    }
end

local function getProofModData(holder)
    local root = holder and holder.getModData and holder:getModData() or nil
    if not root then
        return nil
    end
    root[NMZombieAudioVisualSupport.ModDataKey] = root[NMZombieAudioVisualSupport.ModDataKey] or {}
    return root[NMZombieAudioVisualSupport.ModDataKey]
end

local function getRootModData(holder)
    return holder and holder.getModData and holder:getModData() or nil
end

local function transmitIfPossible(holder)
    if holder and holder.transmitModData then
        pcall(holder.transmitModData, holder)
    end
end

local function shouldLogZombieProof()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true
end

function NMZombieAudioVisualSupport.getProofModData(holder)
    return getProofModData(holder)
end

function NMZombieAudioVisualSupport.pushZombieVisualReplication(zombie, wornItem)
    if wornItem and wornItem.synchWithVisual then
        pcall(wornItem.synchWithVisual, wornItem)
    end
    if zombie and zombie.resetEquippedHandsModels then
        pcall(zombie.resetEquippedHandsModels, zombie)
    end
    if zombie and zombie.resetModelNextFrame then
        pcall(zombie.resetModelNextFrame, zombie)
    end
    if zombie and zombie.resetModel then
        pcall(zombie.resetModel, zombie)
    end
    if zombie and zombie.doInventorySync then
        pcall(zombie.doInventorySync, zombie)
    end
end

function NMZombieAudioVisualSupport.buildCompanionCaseContract(payload, state)
    payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
        and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
        or payload
    local mediaMode = tostring(payload and payload.mediaMode or "")
    local caseEmptyType = tostring(payload and payload.caseEmptyType or "")
    local caseFullType = tostring(payload and payload.caseFullType or "")
    local deviceUUID = tostring(state and state.deviceUUID or "")
    if mediaMode == "device_with_media" and caseEmptyType ~= "" and deviceUUID ~= "" then
        return {
            mode = "device_with_media",
            fullType = caseEmptyType,
            deviceUUID = deviceUUID
        }
    end
    if mediaMode == "media_only" and caseFullType ~= "" then
        return {
            mode = "media_only",
            fullType = caseFullType,
            deviceUUID = ""
        }
    end
    return nil
end

function NMZombieAudioVisualSupport.findAttachedProofItem(zombie, spec)
    local resolved = resolveSpec(spec)
    local attached = zombie and zombie.getAttachedItems and zombie:getAttachedItems() or nil
    if not (attached and attached.size) then
        return nil
    end
    for i = 0, attached:size() - 1 do
        local entry = attached:get(i)
        local location = entry and entry.getLocation and tostring(entry:getLocation() or "") or ""
        local item = entry and entry.getItem and entry:getItem() or nil
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if location == resolved.attachmentLocation and fullType == resolved.fullType then
            return item
        end
    end
    return nil
end

function NMZombieAudioVisualSupport.findInventoryProofItems(zombie, spec, wantedUuid)
    local resolved = resolveSpec(spec)
    local out = {}
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    local items = inventory and inventory.getItems and inventory:getItems() or nil
    if not (items and items.size) then
        return out
    end
    local wanted = tostring(wantedUuid or "")
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if fullType == resolved.fullType then
            if wanted == "" then
                out[#out + 1] = item
            else
                local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
                local uuid = tostring(state and state.deviceUUID or "")
                if uuid == wanted then
                    out[#out + 1] = item
                end
            end
        end
    end
    return out
end

function NMZombieAudioVisualSupport.findInventoryProofItem(zombie, spec, wantedUuid)
    local matches = NMZombieAudioVisualSupport.findInventoryProofItems(zombie, spec, wantedUuid)
    return matches[1]
end

function NMZombieAudioVisualSupport.addInventoryItem(inventory, spec)
    local resolved = resolveSpec(spec)
    if not (inventory and inventory.AddItem) then
        return nil
    end
    local item = NMWorldItemVisuals and NMWorldItemVisuals.addItemWithVisual and select(1, NMWorldItemVisuals.addItemWithVisual(inventory, resolved.fullType)) or inventory:AddItem(resolved.fullType)
    return item
end

function NMZombieAudioVisualSupport.removeInventoryItem(inventory, item)
    if not (inventory and item) then
        return false
    end
    if inventory.DoRemoveItem then
        inventory:DoRemoveItem(item)
        return true
    end
    if inventory.Remove then
        inventory:Remove(item)
        return true
    end
    return false
end

local function getCompanionCaseItemModData(item)
    return item and item.getModData and item:getModData() or nil
end

local function clearCorpseLooseLootFallback(zombie)
    local root = getRootModData(zombie)
    if root and root.nmZombieLoot then
        root.nmZombieLoot.corpseLooseLootFullTypes = {}
    end
end

local function clearSpawnAtDeathCompanionRegistration(holder)
    local md = getProofModData(holder)
    if not md then
        return nil
    end
    md.spawnAtDeathCompanionCaseFullType = nil
    md.spawnAtDeathCompanionCaseDeviceUUID = nil
    md.spawnAtDeathCompanionRegistered = nil
    md.spawnAtDeathCompanionCreateRoute = nil
    md.spawnAtDeathCompanionLastSource = nil
    return md
end

local function clearCompanionCaseRegistrationFailure(holder)
    local md = getProofModData(holder)
    if not md then
        return nil
    end
    md.lastCompanionCaseRegistrationFailure = nil
    md.lastCompanionCaseRegistrationFailureSig = nil
    return md
end

function NMZombieAudioVisualSupport.markManagedCompanionCaseItem(item, fullType, deviceUUID)
    local md = getCompanionCaseItemModData(item)
    if not md then
        return false
    end
    md.nmZombieManagedCompanionCase = true
    md.nmZombieManagedCompanionCaseFullType = tostring(fullType or item and item.getFullType and item:getFullType() or "")
    md.nmZombieManagedCompanionCaseDeviceUUID = tostring(deviceUUID or "")
    return true
end

function NMZombieAudioVisualSupport.createManagedCompanionCaseItem(fullType, deviceUUID)
    local wantedType = tostring(fullType or "")
    local wantedUuid = tostring(deviceUUID or "")
    if wantedType == "" or wantedUuid == "" then
        return nil, "missing_companion_case_contract", nil
    end
    if instanceItem then
        local okInstanceGlobal, createdGlobal = pcall(instanceItem, wantedType)
        if okInstanceGlobal and createdGlobal then
            NMZombieAudioVisualSupport.markManagedCompanionCaseItem(createdGlobal, wantedType, wantedUuid)
            return createdGlobal, nil, "global_instance_item"
        end
    end
    local sm = getScriptManager and getScriptManager() or nil
    if not sm then
        return nil, "missing_script_manager", nil
    end
    local scriptItem = nil
    if sm.getItem then
        local okGet, resolved = pcall(sm.getItem, sm, wantedType)
        if okGet and resolved then
            scriptItem = resolved
        end
    end
    if not scriptItem and sm.FindItem then
        local okFind, resolved = pcall(sm.FindItem, sm, wantedType)
        if okFind and resolved then
            scriptItem = resolved
        end
    end
    if not scriptItem then
        return nil, "missing_script_item", nil
    end
    local route = nil
    local item = nil
    if scriptItem.InstanceItem then
        local okInstance, created = pcall(scriptItem.InstanceItem, scriptItem)
        if okInstance and created then
            item = created
            route = "script_instance_noarg"
        end
    end
    if not item and scriptItem.InstanceItem then
        local okInstanceNil, created = pcall(scriptItem.InstanceItem, scriptItem, nil)
        if okInstanceNil and created then
            item = created
            route = "script_instance_nil"
        end
    end
    if not item then
        return nil, "case_item_instance_failed", nil
    end
    NMZombieAudioVisualSupport.markManagedCompanionCaseItem(item, wantedType, wantedUuid)
    return item, nil, route
end

function NMZombieAudioVisualSupport.pruneManagedCompanionCaseItems(zombie, keepFullType, keepDeviceUUID)
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    local items = inventory and inventory.getItems and inventory:getItems() or nil
    if not (inventory and items and items.size) then
        return 0
    end
    local wantedType = tostring(keepFullType or "")
    local wantedUuid = tostring(keepDeviceUUID or "")
    local removals = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local md = getCompanionCaseItemModData(item)
        if md and md.nmZombieManagedCompanionCase == true then
            local itemType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            local itemUuid = tostring(md.nmZombieManagedCompanionCaseDeviceUUID or "")
            local keep = wantedType ~= "" and itemType == wantedType and (wantedUuid == "" or itemUuid == wantedUuid or itemUuid == "")
            if not keep then
                removals[#removals + 1] = item
            end
        end
    end
    for i = 1, #removals do
        NMZombieAudioVisualSupport.removeInventoryItem(inventory, removals[i])
    end
    if #removals > 0 and zombie and zombie.doInventorySync then
        pcall(zombie.doInventorySync, zombie)
    end
    return #removals
end

function NMZombieAudioVisualSupport.getCompanionCaseRegistrationState(holder)
    local md = getProofModData(holder)
    if not md then
        return nil
    end
    return {
        fullType = tostring(md.spawnAtDeathCompanionCaseFullType or ""),
        deviceUUID = tostring(md.spawnAtDeathCompanionCaseDeviceUUID or ""),
        registered = md.spawnAtDeathCompanionRegistered == true,
        createRoute = tostring(md.spawnAtDeathCompanionCreateRoute or ""),
        source = tostring(md.spawnAtDeathCompanionLastSource or ""),
        failure = tostring(md.lastCompanionCaseRegistrationFailure or ""),
        failureSig = tostring(md.lastCompanionCaseRegistrationFailureSig or "")
    }
end

function NMZombieAudioVisualSupport.stampCorpseCaseIntent(zombie, payload)
    if not zombie then
        return
    end
    payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
        and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
        or payload
    if payload and tostring(payload.mediaMode or "") == "media_only" then
        NMZombieMediaPayloadRuntime.stampCorpseLooseLoot(zombie, payload)
        return
    end
    clearCorpseLooseLootFallback(zombie)
end

function NMZombieAudioVisualSupport.registerManagedCompanionCase(zombie, payload, state, source, runtimeLabel)
    payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
        and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
        or payload
    local md = getProofModData(zombie)
    local mediaMode = tostring(payload and payload.mediaMode or "")
    local sourceLabel = tostring(source or "")
    local runtime = tostring(runtimeLabel or "")
    if mediaMode ~= "device_with_media" then
        NMZombieAudioVisualSupport.pruneManagedCompanionCaseItems(zombie, "", "")
        clearSpawnAtDeathCompanionRegistration(zombie)
        clearCompanionCaseRegistrationFailure(zombie)
        return {
            ok = true,
            reason = nil,
            registered = false,
            createRoute = "",
            source = sourceLabel,
            runtimeLabel = runtime
        }
    end

    local fullType = tostring(payload and payload.caseEmptyType or "")
    local deviceUUID = tostring(state and state.deviceUUID or "")
    if fullType == "" or deviceUUID == "" then
        return {
            ok = false,
            reason = "missing_companion_case_contract",
            registered = false,
            createRoute = "",
            source = sourceLabel,
            runtimeLabel = runtime
        }
    end

    NMZombieAudioVisualSupport.pruneManagedCompanionCaseItems(zombie, "", "")
    local existing = NMZombieAudioVisualSupport.getCompanionCaseRegistrationState(zombie)
    if existing
        and existing.fullType == fullType
        and existing.deviceUUID == deviceUUID
        and existing.registered == true then
        return {
            ok = true,
            reason = nil,
            registered = true,
            createRoute = tostring(existing.createRoute or ""),
            source = sourceLabel,
            runtimeLabel = runtime
        }
    end

    local item, reason, createRoute = NMZombieAudioVisualSupport.createManagedCompanionCaseItem(fullType, deviceUUID)
    if not item then
        return {
            ok = false,
            reason = tostring(reason or "companion_case_create_failed"),
            registered = false,
            createRoute = "",
            source = sourceLabel,
            runtimeLabel = runtime
        }
    end

    if not (zombie and zombie.addItemToSpawnAtDeath) then
        return {
            ok = false,
            reason = "missing_addItemToSpawnAtDeath",
            registered = false,
            createRoute = tostring(createRoute or ""),
            source = sourceLabel,
            runtimeLabel = runtime
        }
    end

    local okAdd, addErr = pcall(zombie.addItemToSpawnAtDeath, zombie, item)
    if not okAdd then
        return {
            ok = false,
            reason = tostring(addErr or "addItemToSpawnAtDeath_failed"),
            registered = false,
            createRoute = tostring(createRoute or ""),
            source = sourceLabel,
            runtimeLabel = runtime
        }
    end

    if md then
        md.spawnAtDeathCompanionCaseFullType = fullType
        md.spawnAtDeathCompanionCaseDeviceUUID = deviceUUID
        md.spawnAtDeathCompanionRegistered = true
        md.spawnAtDeathCompanionCreateRoute = tostring(createRoute or "")
        md.spawnAtDeathCompanionLastSource = sourceLabel
        clearCompanionCaseRegistrationFailure(zombie)
    end

    return {
        ok = true,
        reason = nil,
        registered = true,
        createRoute = tostring(createRoute or ""),
        source = sourceLabel,
        runtimeLabel = runtime
    }
end

function NMZombieAudioVisualSupport.recordCompanionCaseRegistrationFailure(zombie, payload, state, source, runtimeLabel, reason)
    payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
        and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
        or payload
    local md = getProofModData(zombie)
    if not md then
        return false
    end
    local sourceLabel = tostring(source or "")
    local runtime = tostring(runtimeLabel or "")
    local failure = tostring(reason or "unknown")
    local failureSig = table.concat({
        runtime,
        sourceLabel,
        failure,
        tostring(state and state.deviceUUID or ""),
        tostring(payload and payload.caseEmptyType or "")
    }, "|")
    if tostring(md.lastCompanionCaseRegistrationFailureSig or "") ~= failureSig then
        md.lastCompanionCaseRegistrationFailureSig = failureSig
        if shouldLogZombieProof() then
            print(
                string.format(
                    "[NewMusic] [ZombieProof] %s_case_spawn_at_death_skipped zombie=%s source=%s reason=%s",
                    runtime,
                    tostring(zombie and zombie.getObjectID and zombie:getObjectID() or "unknown"),
                    sourceLabel,
                    failure
                )
            )
        end
    end
    clearSpawnAtDeathCompanionRegistration(zombie)
    md.lastCompanionCaseRegistrationFailure = failure
    return false
end

function NMZombieAudioVisualSupport.attachProofItem(zombie, item, spec)
    local resolved = resolveSpec(spec)
    if item and item.setAttachedToModel then
        pcall(item.setAttachedToModel, item, resolved.modelAttachmentName)
    end
    if not (zombie and zombie.setAttachedItem) then
        return false, "missing_setAttachedItem"
    end
    local ok, err = pcall(zombie.setAttachedItem, zombie, resolved.attachmentLocation, item)
    if not ok then
        return false, tostring(err or "setAttachedItem_failed")
    end
    NMZombieAudioVisualSupport.pushZombieVisualReplication(zombie)
    return true, nil
end

function NMZombieAudioVisualSupport.clearAttachedProofItem(zombie, spec)
    local resolved = resolveSpec(spec)
    local attachedItem = NMZombieAudioVisualSupport.findAttachedProofItem(zombie, resolved)
    if not attachedItem then
        return false
    end
    if zombie and zombie.setAttachedItem then
        pcall(zombie.setAttachedItem, zombie, resolved.attachmentLocation, nil)
    end
    NMZombieAudioVisualSupport.pushZombieVisualReplication(zombie)
    return true
end

function NMZombieAudioVisualSupport.scrubZombieProofState(zombie, spec, wantedUuid)
    local removed = 0
    local inventory = zombie and zombie.getInventory and zombie:getInventory() or nil
    if NMZombieAudioVisualSupport.clearAttachedProofItem(zombie, spec) then
        removed = removed + 1
    end
    local proofItems = NMZombieAudioVisualSupport.findInventoryProofItems(zombie, spec, wantedUuid)
    for i = 1, #proofItems do
        if NMZombieAudioVisualSupport.removeInventoryItem(inventory, proofItems[i]) then
            removed = removed + 1
        end
    end
    if removed > 0 and zombie and zombie.doInventorySync then
        pcall(zombie.doInventorySync, zombie)
    end
    return removed
end

function NMZombieAudioVisualSupport.initializeProofState(zombie, item, spec, strategyName, applyAttachedAuthorityFn)
    local resolved = resolveSpec(spec)
    local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    local state = profile and NMDeviceState and NMDeviceState.ensureInitialized and NMDeviceState.ensureInitialized(item, profile, "explicit_init") or nil
    if not (profile and state) then
        return nil, nil, "device_state_init_failed"
    end
    state.mediaFullType = nil
    state.mediaEjectFullType = nil
    state.mediaRecordedMediaIndex = nil
    state.mediaDisplayName = nil
    state.isOn = false
    state.desiredIsOn = false
    state.isPlaying = false
    state.desiredIsPlaying = false
    state.lastStopReason = resolved.stopReason
    if profile.supportsBattery == true then
        state.batteryPresent = true
        state.batteryCharge = 1.0
    end
    if NMDeviceState and NMDeviceState.setZombieDormant then
        NMDeviceState.setZombieDormant(state, true, resolved.stopReason, tostring(strategyName or ""))
    end
    if type(applyAttachedAuthorityFn) == "function" then
        applyAttachedAuthorityFn(zombie, item, state)
    end
    if NMDeviceState and NMDeviceState.bumpRevision then
        NMDeviceState.bumpRevision(state)
    end
    return profile, state, nil
end

function NMZombieAudioVisualSupport.applySelectionFields(modData, selection, strategyName)
    if type(modData) ~= "table" then
        return
    end
    if selection then
        modData.selected = selection.selected == true
        modData.musicSelected = selection.musicSelected == true
        modData.variantId = tostring(selection.variantId or "none")
        modData.selectionSource = tostring(selection.selectionSource or "server_ledger")
        modData.selectionEpoch = tonumber(selection.selectionEpoch) or 0
        modData.selectionZombieId = tostring(selection.zombieId or "")
    end
    if tostring(strategyName or "") ~= "" then
        modData.strategy = tostring(strategyName)
        modData.liveVisualStrategy = tostring(strategyName)
    end
end

function NMZombieAudioVisualSupport.resolveCompanionCaseContract(data)
    if type(data) ~= "table" then
        return nil
    end
    local mode = tostring(data.corpseCompanionMode or "")
    local fullType = tostring(data.corpseCompanionFullType or "")
    local deviceUUID = tostring(data.corpseCompanionDeviceUUID or "")
    if mode == "" or fullType == "" then
        return nil
    end
    return {
        mode = mode,
        fullType = fullType,
        deviceUUID = deviceUUID
    }
end

function NMZombieAudioVisualSupport.stampZombieStatus(zombie, spec, params)
    local md = getProofModData(zombie)
    local resolved = resolveSpec(spec)
    local options = type(params) == "table" and params or {}
    if not md then
        return nil
    end
    local item = options.item
    local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
    local payload = options.payload or NMZombieMediaPayloadResolver.resolveStoredPayload(options)
    payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
        and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
        or payload
    md.status = tostring(options.status or "")
    md.variantId = tostring(resolved.variantId or md.variantId or "none")
    md.fullType = item and item.getFullType and tostring(item:getFullType() or "") or resolved.fullType
    md.attachmentLocation = resolved.attachmentLocation
    md.modelAttachmentName = resolved.modelAttachmentName
    md.deviceUUID = tostring(state and state.deviceUUID or options.deviceUUID or "")
    md.reason = options.reason ~= nil and tostring(options.reason) or nil
    md.lastAttemptTick = tonumber(options.lastAttemptTick) or 0
    if options.processed ~= nil then
        md.processed = options.processed == true
    end
    if options.outcome ~= nil then
        md.outcome = tostring(options.outcome)
    end
    if options.assignmentSource ~= nil then
        md.assignmentSource = tostring(options.assignmentSource)
    end
    if options.failedTick ~= nil then
        md.failedTick = tonumber(options.failedTick) or 0
    else
        md.failedTick = nil
    end
    md.mediaCategory = tostring(payload and payload.mediaCategory or "")
    md.deviceEnabled = payload and payload.deviceEnabled == true or false
    md.mediaEnabled = payload and payload.mediaEnabled == true or false
    md.mediaMode = tostring(payload and payload.mediaMode or "none")
    md.mediaFullType = tostring(payload and payload.insertedMediaFullType or state and state.mediaFullType or "") ~= ""
        and tostring(payload and payload.insertedMediaFullType or state and state.mediaFullType or "")
        or nil
    md.mediaEjectFullType = tostring(payload and payload.mediaEjectFullType or state and state.mediaEjectFullType or "") ~= ""
        and tostring(payload and payload.mediaEjectFullType or state and state.mediaEjectFullType or "")
        or nil
    md.mediaRecordedMediaIndex = payload and payload.mediaRecordedMediaIndex or state and state.mediaRecordedMediaIndex or nil
    md.caseFullType = tostring(payload and payload.caseFullType or "") ~= "" and tostring(payload.caseFullType) or nil
    md.caseEmptyType = tostring(payload and payload.caseEmptyType or "") ~= "" and tostring(payload.caseEmptyType) or nil
    md.headphoneItemFullType = tostring(payload and payload.headphoneItemFullType or state and state.headphoneItemFullType or "") ~= ""
        and tostring(payload and payload.headphoneItemFullType or state and state.headphoneItemFullType or "")
        or nil
    if payload and payload.batteryPresent ~= nil then
        md.batteryPresent = payload.batteryPresent == true
        md.batteryCharge = tonumber(payload.batteryCharge) or 0.0
    elseif state then
        md.batteryPresent = state.batteryPresent == true
        md.batteryCharge = tonumber(state.batteryCharge) or 0.0
    end
    md.corpseCompanionMode = nil
    md.corpseCompanionFullType = nil
    md.corpseCompanionDeviceUUID = nil
    local companionCaseContract = NMZombieAudioVisualSupport.buildCompanionCaseContract(payload, {
        deviceUUID = md.deviceUUID
    })
    if companionCaseContract then
        md.corpseCompanionMode = tostring(companionCaseContract.mode or "")
        md.corpseCompanionFullType = tostring(companionCaseContract.fullType or "")
        md.corpseCompanionDeviceUUID = tostring(companionCaseContract.deviceUUID or "")
    end
    NMZombieAudioVisualSupport.applySelectionFields(md, options.selection, options.strategyName)
    transmitIfPossible(zombie)
    return md
end

return NMZombieAudioVisualSupport
