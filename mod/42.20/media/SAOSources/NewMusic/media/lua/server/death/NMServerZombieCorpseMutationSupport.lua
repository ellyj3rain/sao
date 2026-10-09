require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadRuntime"

NMServerZombieCorpseMutationSupport = NMServerZombieCorpseMutationSupport or {}

function NMServerZombieCorpseMutationSupport.new(deps)
    deps = deps or {}

    local function logProof(tag, detail, force)
        local fn = deps.logProof
        if fn then
            fn(tag, detail, force)
        end
    end

    local function logCorpseRuntimeIdentity(stage, item, profile, state, record)
        local fn = deps.logCorpseRuntimeIdentity
        if fn then
            fn(stage, item, profile, state, record)
        end
    end

    local function getModData(holder)
        local fn = deps.getModData
        return fn and fn(holder) or nil
    end

    local function getRootModData(holder)
        local fn = deps.getRootModData
        return fn and fn(holder) or nil
    end

    local function isIsoDeadBody(obj)
        local fn = deps.isIsoDeadBody
        return fn and fn(obj) or false
    end

    local function addItemToContainer(container, fullType)
        if not (container and container.AddItem) then
            return nil
        end
        local item = container:AddItem(fullType)
        logProof("corpse_add_item", "fullType=" .. tostring(fullType or ""), true)
        if item and sendAddItemToContainer then
            pcall(sendAddItemToContainer, container, item)
        end
        return item
    end

    local function removeItemFromContainer(container, item)
        local owner = container and container.getParent and container:getParent() or nil
        local removed = NMZombieAudioVisualSupport.removeInventoryItem(container, item)
        if removed and isIsoDeadBody(owner) and sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, container, item)
        end
        return removed
    end

    local function countItemsByFullType(container, fullType)
        local wanted = tostring(fullType or "")
        if wanted == "" then
            return 0
        end
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return 0
        end
        local count = 0
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local itemFullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if itemFullType == wanted then
                count = count + 1
            end
        end
        return count
    end

    local function collectItemsByFullType(container, fullType, limit)
        local wanted = tostring(fullType or "")
        local out = {}
        if wanted == "" then
            return out
        end
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return out
        end
        local maxCount = math.max(0, math.floor(tonumber(limit) or 0))
        for i = 0, items:size() - 1 do
            if #out >= maxCount then
                break
            end
            local item = items:get(i)
            local itemFullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if itemFullType == wanted then
                out[#out + 1] = item
            end
        end
        return out
    end

    local function containerHasManagedCompanionCase(container, fullType, deviceUUID)
        local wantedType = tostring(fullType or "")
        local wantedUuid = tostring(deviceUUID or "")
        if wantedType == "" then
            return false
        end
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return false
        end
        local sawFullType = false
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local itemFullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if itemFullType == wantedType then
                sawFullType = true
                local md = item and item.getModData and item:getModData() or nil
                local marked = md and md.nmZombieManagedCompanionCase == true
                local markedUuid = tostring(md and md.nmZombieManagedCompanionCaseDeviceUUID or "")
                if marked and (wantedUuid == "" or markedUuid == wantedUuid) then
                    return true
                end
            end
        end
        return sawFullType
    end

    local function containerHasMatchingRecord(container, record)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return false
        end
        local wantedUuid = tostring(record and record.deviceUUID or "")
        local wantedType = tostring(record and record.fullType or "")
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
            local uuid = tostring(state and state.deviceUUID or "")
            if wantedUuid ~= "" and uuid == wantedUuid then
                return true
            end
            if wantedUuid == "" and fullType == wantedType then
                return true
            end
        end
        return false
    end

    local function collectCanonicalCorpsePayloadCandidates(explicitLooseLoot)
        local candidates = {}

        local function addCandidate(fullType)
            local key = tostring(fullType or "")
            if key ~= "" then
                candidates[key] = true
            end
        end

        for i = 1, #explicitLooseLoot do
            addCandidate(explicitLooseLoot[i])
        end
        return candidates
    end

    local function collectCompatibilityCorpsePayloadCandidates(candidates, companionContract)
        if companionContract and companionContract.mode == "media_only" and tostring(companionContract.fullType or "") ~= "" then
            candidates[tostring(companionContract.fullType)] = true
        end
        return candidates
    end

    local function collectCorpsePayloadCandidates(explicitLooseLoot, companionContract)
        -- Canonical explicit companion case contract and explicit loose-loot contract.
        local candidates = collectCanonicalCorpsePayloadCandidates(explicitLooseLoot)
        -- Compatibility path for validated media-only contract realization.
        candidates = collectCompatibilityCorpsePayloadCandidates(candidates, companionContract)
        return candidates
    end

    local function resolveCanonicalWantedCorpsePayloadCount(fullType, explicitLooseLoot)
        local wantedCount = 0
        for i = 1, #explicitLooseLoot do
            if fullType == tostring(explicitLooseLoot[i] or "") then
                wantedCount = wantedCount + 1
            end
        end
        return wantedCount
    end

    local function resolveCompatibilityWantedCorpsePayloadCount(fullType, wantedCount, companionContract)
        if wantedCount == 0 and companionContract and companionContract.mode == "media_only" and fullType == tostring(companionContract.fullType or "") then
            wantedCount = 1
        end
        return wantedCount
    end

    local function resolveWantedCorpsePayloadCount(fullType, explicitLooseLoot, companionContract)
        local wantedCount = resolveCanonicalWantedCorpsePayloadCount(fullType, explicitLooseLoot)
        wantedCount = resolveCompatibilityWantedCorpsePayloadCount(fullType, wantedCount, companionContract)
        return wantedCount
    end

    local function buildSanitizedCorpseLooseLoot(record)
        local sanitizedPayload = type(record) == "table"
            and record.payload
            and NMZombieMediaPayloadResolver
            and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
            and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(record.payload)
            or nil
        if sanitizedPayload and NMZombieMediaPayloadRuntime and NMZombieMediaPayloadRuntime.buildCorpseLooseLootFullTypes then
            return NMZombieMediaPayloadRuntime.buildCorpseLooseLootFullTypes(sanitizedPayload)
        end
        return type(record and record.corpseLooseLootFullTypes) == "table" and record.corpseLooseLootFullTypes or {}
    end

    local function resolveSanitizedCompanionContract(record)
        local sanitizedPayload = type(record) == "table"
            and record.payload
            and NMZombieMediaPayloadResolver
            and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
            and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(record.payload)
            or nil
        if sanitizedPayload and NMZombieAudioVisualSupport and NMZombieAudioVisualSupport.buildCompanionCaseContract then
            return NMZombieAudioVisualSupport.buildCompanionCaseContract(sanitizedPayload, {
                deviceUUID = tostring(record and record.deviceUUID or "")
            })
        end
        return type(record and record.companionCaseContract) == "table" and record.companionCaseContract or nil
    end

    local function syncCorpsePayload(container, record)
        if not (container and record) then
            return
        end
        local explicitLooseLoot = buildSanitizedCorpseLooseLoot(record)
        local companionContract = resolveSanitizedCompanionContract(record)
        local candidates = collectCorpsePayloadCandidates(explicitLooseLoot, companionContract)

        for fullType in pairs(candidates) do
            local wantedCount = resolveWantedCorpsePayloadCount(fullType, explicitLooseLoot, companionContract)
            local currentCount = countItemsByFullType(container, fullType)
            if currentCount > wantedCount then
                local removals = collectItemsByFullType(container, fullType, currentCount - wantedCount)
                for i = 1, #removals do
                    removeItemFromContainer(container, removals[i])
                end
            elseif currentCount < wantedCount then
                for _ = currentCount + 1, wantedCount do
                    addItemToContainer(container, fullType)
                end
            end
        end
    end

    local function logCompanionCaseOutcome(record, outcome)
        local contract = resolveSanitizedCompanionContract(record)
        local expectedUuid = tostring(contract and contract.deviceUUID or "")
        local expectedCase = tostring(contract and contract.fullType or "")
        logProof(
            "corpse_case_spawn_at_death_outcome",
            "uuid=" .. expectedUuid .. " caseFullType=" .. expectedCase .. " outcome=" .. tostring(outcome or "neither") .. " registered=" .. tostring(record and record.spawnAtDeathCompanionRegistered == true) .. " route=" .. tostring(record and record.spawnAtDeathCompanionRoute or ""),
            true
        )
    end

    local function validateInheritedCompanionLoot(container, record)
        -- Canonical explicit companion case contract validation.
        local companionContract = resolveSanitizedCompanionContract(record)
        if not companionContract then
            return true
        end
        local expectedUuid = tostring(companionContract.deviceUUID or "")
        local expectedCase = tostring(companionContract.fullType or "")
        local hasDevice = expectedUuid ~= "" and containerHasMatchingRecord(container, record) or false
        local hasCase = expectedCase ~= "" and containerHasManagedCompanionCase(container, expectedCase, expectedUuid) or false
        local outcome = "neither"
        if hasDevice and hasCase then
            outcome = "both"
        elseif hasCase then
            outcome = "inventory_only"
        elseif hasDevice and tostring(record.spawnAtDeathCompanionAttempted or "") ~= "" then
            outcome = "visual_only"
        end
        logCompanionCaseOutcome(record, outcome)
        if expectedUuid ~= "" and not hasDevice then
            logProof("corpse_companion_failed", "reason=missing_expected_device uuid=" .. expectedUuid, true)
            return false
        end
        if expectedCase ~= "" and not hasCase then
            logProof("corpse_companion_failed", "reason=missing_inherited_case fullType=" .. expectedCase .. " uuid=" .. expectedUuid, true)
            return false
        end
        logProof(
            "corpse_companion_realized",
            "device=" .. tostring(record.fullType or "") .. " case=" .. expectedCase .. " mode=inherited",
            true
        )
        return true
    end

    local function syncCanonicalInheritedCompanionCase(container, record, companionContract)
        if not (container and record) then
            return false
        end
        local wantedCase = tostring(companionContract and companionContract.fullType or "")
        if wantedCase == "" then
            return false
        end
        local currentCount = countItemsByFullType(container, wantedCase)
        if currentCount > 1 then
            local removals = collectItemsByFullType(container, wantedCase, currentCount - 1)
            for i = 1, #removals do
                removeItemFromContainer(container, removals[i])
            end
            return true
        end
        if currentCount < 1 then
            addItemToContainer(container, wantedCase)
            return true
        end
        return false
    end

    local function syncCompatibilityInheritedCompanionCase(container, record, companionContract)
        if not (container and record) or companionContract ~= nil then
            return false
        end
        local wantedCase = tostring(record and record.payload and record.payload.caseEmptyType or "")
        if wantedCase == "" then
            return false
        end
        local currentCount = countItemsByFullType(container, wantedCase)
        if currentCount > 1 then
            local removals = collectItemsByFullType(container, wantedCase, currentCount - 1)
            for i = 1, #removals do
                removeItemFromContainer(container, removals[i])
            end
            return true
        end
        if currentCount < 1 then
            addItemToContainer(container, wantedCase)
            return true
        end
        return false
    end

    local function ensureImmediateCompanionLoot(container, record)
        if not (container and record) then
            return true
        end
        -- Phase ordering:
        -- reconcile corpse payload first, then realize/validate companion-case behavior.
        syncCorpsePayload(container, record)
        local companionContract = resolveSanitizedCompanionContract(record)
        if companionContract and companionContract.mode == "device_with_media" then
            syncCanonicalInheritedCompanionCase(container, record, companionContract)
            return validateInheritedCompanionLoot(container, record)
        end
        syncCompatibilityInheritedCompanionCase(container, record, companionContract)
        logProof(
            "corpse_companion_realized",
            "device=" .. tostring(record.fullType or "") .. " case=" .. tostring(companionContract and companionContract.fullType or ""),
            true
        )
        return true
    end

    local function removeMatchingRecordItems(container, record)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size and record) then
            return 0
        end
        local wantedUuid = tostring(record.deviceUUID or "")
        local wantedType = tostring(record.fullType or "")
        local removals = {}
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
            local uuid = tostring(state and state.deviceUUID or "")
            if (wantedUuid ~= "" and uuid == wantedUuid) or (wantedUuid == "" and fullType == wantedType) then
                removals[#removals + 1] = item
            end
        end
        for i = 1, #removals do
            removeItemFromContainer(container, removals[i])
        end
        return #removals
    end

    local function applyStateToCorpseItem(item, record)
        local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
        local state = profile and NMDeviceState and NMDeviceState.ensureInitialized and NMDeviceState.ensureInitialized(item, profile, "explicit_init") or nil
        local itemMd = item and item.getModData and item:getModData() or nil
        if not (profile and state) then
            return false, "device_state_init_failed"
        end
        if NMDeviceState and NMDeviceState.import then
            NMDeviceState.import(state, record.state or {})
        end
        if record and record.payload and NMZombieMediaPayloadRuntime and NMZombieMediaPayloadRuntime.applyPayloadToState then
            NMZombieMediaPayloadRuntime.applyPayloadToState(state, record.payload)
        end
        if NMDeviceState and NMDeviceState.setZombieDormant then
            NMDeviceState.setZombieDormant(state, false, nil, nil)
        end
        local portableTracked = NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile) == true
        state.authoritativeMode = "off"
        state.sourceKind = "inventory"
        state.sourceOwner = nil
        state.sourceX = nil
        state.sourceY = nil
        state.sourceZ = nil
        if portableTracked then
            state.sourceGeneration = 0
            state.playbackMode = tostring(profile.defaultPlaybackMode or "inventory")
        end
        state._nmCorpseRecovered = true
        if itemMd then
            itemMd.nmCorpseRecovered = true
            itemMd.nmCorpseRecoveredFullType = tostring(item and item.getFullType and item:getFullType() or record and record.fullType or "")
            itemMd.nmCorpseRecoveredDeviceUUID = tostring(state.deviceUUID or "")
        end
        state.isOn = false
        state.desiredIsOn = false
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "corpse_reconcile"
        if NMDeviceState and NMDeviceState.bumpRevision then
            NMDeviceState.bumpRevision(state)
        end
        logCorpseRuntimeIdentity("rehydrated", item, profile, state, record)
        return true, tostring(state.deviceUUID or "")
    end

    local function findSingleProofItemByType(container, fullType)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return nil
        end
        local found = nil
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local itemType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if itemType == tostring(fullType or "") then
                if found then
                    return nil
                end
                found = item
            end
        end
        return found
    end

    local function findMatchingRecordItem(container, record)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return nil
        end
        local wantedUuid = tostring(record and record.deviceUUID or "")
        local wantedType = tostring(record and record.fullType or "")
        local typeMatch = nil
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
            local uuid = tostring(state and state.deviceUUID or "")
            if wantedUuid ~= "" and uuid == wantedUuid then
                return item
            end
            if not typeMatch and wantedType ~= "" and fullType == wantedType then
                typeMatch = item
            end
        end
        if wantedUuid ~= "" then
            return nil
        end
        return typeMatch
    end

    local function pruneExtraProofItems(container, keepItem)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return 0
        end
        local removals = {}
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item ~= keepItem then
                local fullType = item.getFullType and tostring(item:getFullType() or "") or ""
                if NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.findSpecByFullType and NMZombieDeviceVariantCatalog.findSpecByFullType(fullType) then
                    removals[#removals + 1] = item
                end
            end
        end
        for i = 1, #removals do
            removeItemFromContainer(container, removals[i])
        end
        return #removals
    end

    local function enforceSingleCorpseProofItem(container, record, preferredItem)
        local keeper = preferredItem
        local wantedUuid = tostring(record and record.deviceUUID or "")
        if not keeper then
            keeper = findMatchingRecordItem(container, record)
        end
        if not keeper and wantedUuid == "" and record and tostring(record.fullType or "") ~= "" then
            keeper = findSingleProofItemByType(container, record.fullType)
        end
        if not keeper then
            return 0, nil
        end
        return pruneExtraProofItems(container, keeper), keeper
    end

    local function applyCorpseRecord(container, record)
        if tostring(record and record.fullType or "") == "" then
            syncCorpsePayload(container, record)
            return true, ""
        end
        local wantedUuid = tostring(record and record.deviceUUID or "")
        local existing = findMatchingRecordItem(container, record)
        if not existing and wantedUuid == "" then
            existing = findSingleProofItemByType(container, record.fullType)
        end
        if existing then
            local ok, detail = applyStateToCorpseItem(existing, record)
            if ok then
                pruneExtraProofItems(container, existing)
                syncCorpsePayload(container, record)
            end
            return ok, detail
        end
        local item = addItemToContainer(container, record.fullType)
        if not item then
            return false, "item_add_failed"
        end
        local ok, detail = applyStateToCorpseItem(item, record)
        if ok then
            pruneExtraProofItems(container, item)
            syncCorpsePayload(container, record)
            return true, detail
        end
        removeItemFromContainer(container, item)
        return false, detail
    end

    local function copyCorpseLooseLootToRoot(body, record)
        local root = getRootModData(body)
        if not root then
            return
        end
        root.nmZombieLoot = root.nmZombieLoot or {}
        root.nmZombieLoot.corpseLooseLootFullTypes = {}
        local looseLoot = buildSanitizedCorpseLooseLoot(record)
        for i = 1, #looseLoot do
            root.nmZombieLoot.corpseLooseLootFullTypes[#root.nmZombieLoot.corpseLooseLootFullTypes + 1] = looseLoot[i]
        end
    end

    local function resolveSettledCorpseStatus(record, carried)
        local settledStatus = carried == true and "attached" or "excluded"
        if record and record.payload and tostring(record.payload.mediaMode or "") == "media_only" and carried == true then
            return "media_only"
        end
        return settledStatus
    end

    local function applyCorpsePayloadMetadata(md, payload)
        if type(md) ~= "table" then
            return
        end
        payload = NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox
            and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
            or payload
        if type(payload) ~= "table" then
            md.mediaCategory = nil
            md.deviceEnabled = nil
            md.mediaEnabled = nil
            md.mediaMode = nil
            md.mediaFullType = nil
            md.mediaEjectFullType = nil
            md.mediaRecordedMediaIndex = nil
            md.caseFullType = nil
            md.caseEmptyType = nil
            md.headphoneItemFullType = nil
            md.batteryPresent = nil
            md.batteryCharge = nil
            return
        end
        md.mediaCategory = tostring(payload.mediaCategory or "")
        md.deviceEnabled = payload.deviceEnabled == true
        md.mediaEnabled = payload.mediaEnabled == true
        md.mediaMode = tostring(payload.mediaMode or "none")
        md.mediaFullType = tostring(payload.insertedMediaFullType or "") ~= "" and tostring(payload.insertedMediaFullType) or nil
        md.mediaEjectFullType = tostring(payload.mediaEjectFullType or "") ~= "" and tostring(payload.mediaEjectFullType) or nil
        md.mediaRecordedMediaIndex = tonumber(payload.mediaRecordedMediaIndex) or nil
        md.caseFullType = tostring(payload.caseFullType or "") ~= "" and tostring(payload.caseFullType) or nil
        md.caseEmptyType = tostring(payload.caseEmptyType or "") ~= "" and tostring(payload.caseEmptyType) or nil
        md.headphoneItemFullType = tostring(payload.headphoneItemFullType or "") ~= "" and tostring(payload.headphoneItemFullType) or nil
        md.batteryPresent = payload.batteryPresent == true
        md.batteryCharge = tonumber(payload.batteryCharge) or 0.0
    end

    local function applyCorpseCompanionMetadata(md, companionContract)
        if type(md) ~= "table" then
            return
        end
        md.corpseCompanionMode = companionContract and tostring(companionContract.mode or "") or nil
        md.corpseCompanionFullType = companionContract and tostring(companionContract.fullType or "") or nil
        md.corpseCompanionDeviceUUID = companionContract and tostring(companionContract.deviceUUID or "") or nil
    end

    local function applyCorpseSettlementMetadata(md, record, deviceUUID, carried)
        if type(md) ~= "table" then
            return
        end
        if type(record) == "table" and NMZombieMediaPayloadResolver and NMZombieMediaPayloadResolver.sanitizePayloadForSandbox then
            record.payload = NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(record.payload)
        end
        -- Corpse settlement stamping is the last explicit corpse transfer phase.
        md.corpseSettled = true
        md.corpseHadProof = carried == true
        md.fullType = tostring(record and record.fullType or "")
        md.attachmentLocation = tostring(record and record.attachmentLocation or "")
        md.modelAttachmentName = tostring(record and record.modelAttachmentName or "")
        md.deviceUUID = tostring(deviceUUID or record and record.deviceUUID or "")
        md.strategy = tostring(record and record.strategy or "")
        md.status = resolveSettledCorpseStatus(record, carried)
        applyCorpsePayloadMetadata(md, record and record.payload or nil)
        -- Canonical explicit companion case contract metadata is stamped separately from payload-derived metadata.
        local companionContract = resolveSanitizedCompanionContract(record)
        applyCorpseCompanionMetadata(md, companionContract)
    end

    local function markCorpseSettled(body, record, deviceUUID, carried)
        local md = getModData(body)
        if not md then
            return
        end
        copyCorpseLooseLootToRoot(body, record)
        applyCorpseSettlementMetadata(md, record, deviceUUID, carried)
        if NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.stampCorpseSelection then
            local ledgerRecord = record and record.selection or nil
            if ledgerRecord then
                NMZombieVisualTargetLedger.stampCorpseSelection(body, ledgerRecord, carried == true)
                md = getModData(body) or md
                applyCorpseSettlementMetadata(md, record, deviceUUID, carried)
                return
            end
        end
        if body and body.transmitModData then
            pcall(body.transmitModData, body)
        end
    end

    local function containerHasAnyProof(container)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return false
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.findSpecByFullType and NMZombieDeviceVariantCatalog.findSpecByFullType(fullType) then
                return true
            end
        end
        return false
    end

    local function removeProofItemsByType(container)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return 0
        end
        local removals = {}
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            if NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.findSpecByFullType and NMZombieDeviceVariantCatalog.findSpecByFullType(fullType) then
                removals[#removals + 1] = item
            end
        end
        for i = 1, #removals do
            removeItemFromContainer(container, removals[i])
        end
        return #removals
    end

    return {
        containerHasAnyProof = containerHasAnyProof,
        containerHasMatchingRecord = containerHasMatchingRecord,
        removeMatchingRecordItems = removeMatchingRecordItems,
        applyStateToCorpseItem = applyStateToCorpseItem,
        findMatchingRecordItem = findMatchingRecordItem,
        enforceSingleCorpseProofItem = enforceSingleCorpseProofItem,
        applyCorpseRecord = applyCorpseRecord,
        ensureImmediateCompanionLoot = ensureImmediateCompanionLoot,
        markCorpseSettled = markCorpseSettled,
        removeProofItemsByType = removeProofItemsByType
    }
end

return NMServerZombieCorpseMutationSupport
