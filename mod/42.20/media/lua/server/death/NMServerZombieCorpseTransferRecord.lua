-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadResolver"

NMServerZombieCorpseTransferRecord = NMServerZombieCorpseTransferRecord or {}

function NMServerZombieCorpseTransferRecord.new(deps)
    deps = deps or {}
    local knownSpecs = deps.knownSpecs or {}

    local function getModData(holder)
        local fn = deps.getModData
        return fn and fn(holder) or nil
    end

    local function getRootModData(holder)
        local fn = deps.getRootModData
        return fn and fn(holder) or nil
    end

    local function logProof(tag, detail)
        local fn = deps.logProof
        if fn then
            fn(tag, detail, false)
        end
    end

    local function entityDebugId(entity)
        return tostring(entity and entity.getOnlineID and entity:getOnlineID()
            or entity and entity.getObjectID and entity:getObjectID()
            or "unknown")
    end

    local function getTransferDiagDetail(zombie, spec, md, payload, registration, reason)
        return string.format(
            "zombie=%s reason=%s status=%s selected=%s musicSelected=%s strategy=%s variant=%s fullType=%s deviceUUID=%s mediaMode=%s caseEmpty=%s caseFull=%s contractMode=%s contractFullType=%s spawnAttempted=%s spawnRegistered=%s spawnRoute=%s",
            entityDebugId(zombie),
            tostring(reason or ""),
            tostring(md and md.status or ""),
            tostring(md and md.selected == true),
            tostring(md and md.musicSelected == true),
            tostring(md and (md.strategy or md.liveVisualStrategy) or ""),
            tostring(spec and spec.variantId or md and md.variantId or ""),
            tostring(spec and spec.fullType or md and md.fullType or ""),
            tostring(md and md.deviceUUID or ""),
            tostring(payload and payload.mediaMode or ""),
            tostring(payload and payload.caseEmptyType or md and md.caseEmptyType or ""),
            tostring(payload and payload.caseFullType or md and md.caseFullType or ""),
            tostring(md and md.corpseCompanionMode or ""),
            tostring(md and md.corpseCompanionFullType or ""),
            tostring(registration and tostring(registration.deviceUUID or "") ~= "" or false),
            tostring(registration and registration.registered == true or false),
            tostring(registration and registration.createRoute or "")
        )
    end

    local function getCorpseLooseLootFullTypes(holder)
        -- Canonical explicit companion case contract:
        -- a finalized contract owns corpse-side case realization when present.
        local contract = NMZombieAudioVisualSupport.resolveCompanionCaseContract
            and NMZombieAudioVisualSupport.resolveCompanionCaseContract(getModData(holder))
            or nil
        if contract and contract.mode == "media_only" and tostring(contract.fullType or "") ~= "" then
            return { tostring(contract.fullType) }
        end
        -- Compatibility path:
        -- preserved payload/loot export for validated bodies that still rely on stored loose-loot lists.
        local root = getRootModData(holder)
        local zombieLoot = root and root.nmZombieLoot or nil
        local fullTypes = zombieLoot and zombieLoot.corpseLooseLootFullTypes or nil
        if type(fullTypes) ~= "table" then
            return {}
        end
        local out = {}
        for i = 1, #fullTypes do
            local fullType = tostring(fullTypes[i] or "")
            if fullType ~= "" then
                out[#out + 1] = fullType
            end
        end
        return out
    end

    local function getCompanionCaseContract(holder)
        return NMZombieAudioVisualSupport.resolveCompanionCaseContract
            and NMZombieAudioVisualSupport.resolveCompanionCaseContract(getModData(holder))
            or nil
    end

    local function getSpawnAtDeathRegistrationState(holder)
        return NMZombieAudioVisualSupport.getCompanionCaseRegistrationState
            and NMZombieAudioVisualSupport.getCompanionCaseRegistrationState(holder)
            or nil
    end

    local function findAnyKnownProofItem(container)
        local items = container and container.getItems and container:getItems() or nil
        if not (items and items.size) then
            return nil, nil
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
            local spec = NMZombieDeviceVariantCatalog
                and NMZombieDeviceVariantCatalog.findSpecByFullType
                and NMZombieDeviceVariantCatalog.findSpecByFullType(fullType)
                or nil
            if spec then
                return item, spec
            end
        end
        return nil, nil
    end

    local function exportCorpseTransferRecord(spec, exportedState, md, payload, registration, extra)
        extra = extra or {}
        return {
            fullType = tostring(extra.fullType or spec and spec.fullType or ""),
            attachmentLocation = tostring(extra.attachmentLocation or spec and spec.attachmentLocation or ""),
            modelAttachmentName = tostring(extra.modelAttachmentName or spec and spec.modelAttachmentName or ""),
            deviceUUID = tostring(extra.deviceUUID or exportedState and exportedState.deviceUUID or ""),
            strategy = tostring(extra.strategy or md and (md.strategy or md.liveVisualStrategy) or ""),
            variantId = tostring(extra.variantId or spec and spec.variantId or md and md.variantId or ""),
            state = exportedState,
            payload = payload,
            companionCaseContract = getCompanionCaseContract(extra.contractHolder or extra.sourceHolder),
            spawnAtDeathCompanionAttempted = tostring(registration and registration.deviceUUID or ""),
            spawnAtDeathCompanionRegistered = registration and registration.registered == true or false,
            spawnAtDeathCompanionRoute = tostring(registration and registration.createRoute or ""),
            corpseLooseLootFullTypes = getCorpseLooseLootFullTypes(extra.lootHolder or extra.sourceHolder)
        }
    end

    local function exportStoppedDeviceState(item)
        local state = item and NMDeviceState and NMDeviceState.peek and NMDeviceState.peek(item) or nil
        local exported = state and NMDeviceState and NMDeviceState.export and NMDeviceState.export(state) or nil
        if exported then
            exported.isOn = false
            exported.desiredIsOn = false
            exported.isPlaying = false
            exported.desiredIsPlaying = false
            exported.lastStopReason = "corpse_reconcile"
        end
        return exported
    end

    local function resolveZombieStoredSpec(zombie, md)
        local spec = NMZombieDeviceVariantCatalog
            and NMZombieDeviceVariantCatalog.resolveStoredSpec
            and NMZombieDeviceVariantCatalog.resolveStoredSpec(md)
            or nil
        if spec then
            return spec
        end
        for i = 1, #knownSpecs do
            local candidate = knownSpecs[i]
            if NMZombieAudioVisualSupport.findAttachedProofItem(zombie, candidate) then
                return candidate
            end
        end
        return nil
    end

    local function buildCanonicalAttachedTransferRecord(zombie, spec, md, payload, registration)
        -- Canonical capture:
        -- export from the attached proof item when the finalized assignment is already realized on the zombie.
        local attachedItem = NMZombieAudioVisualSupport.findAttachedProofItem(zombie, spec)
        if not attachedItem then
            logProof("canonical_attached_missing", getTransferDiagDetail(zombie, spec, md, payload, registration, "attached_proof_absent"))
            return nil
        end
        local exported = exportStoppedDeviceState(attachedItem)
        return exportCorpseTransferRecord(spec, exported, md, payload, registration, {
            sourceHolder = zombie
        })
    end

    local function buildFallbackInventoryTransferRecord(zombie, spec, md, payload, registration, diag)
        -- Fallback path:
        -- retained only as a recovery bridge when attached proof realization has not materialized yet.
        local wantedUuid = tostring(md and md.deviceUUID or "")
        local status = tostring(md and md.status or "")
        if status ~= "attached" or wantedUuid == "" then
            logProof("inventory_fallback_missing", getTransferDiagDetail(zombie, spec, md, payload, registration, "status_or_uuid_not_eligible"))
            return nil
        end
        local item = NMZombieAudioVisualSupport.findInventoryProofItem(zombie, spec, wantedUuid)
        if not item then
            logProof("inventory_fallback_missing", getTransferDiagDetail(zombie, spec, md, payload, registration, "inventory_proof_absent"))
            return nil
        end
        local exported = exportStoppedDeviceState(item)
        if not exported then
            logProof("inventory_fallback_state_missing", getTransferDiagDetail(zombie, spec, md, payload, registration, "state_export_absent"))
            return nil
        end
        if diag then
            diag.corpseCaptureInventoryFallback = (diag.corpseCaptureInventoryFallback or 0) + 1
        end
        return exportCorpseTransferRecord(spec, exported, md, payload, registration, {
            sourceHolder = zombie
        })
    end

    local function buildCompatibilityMediaOnlyTransferRecord(zombie, md, payload, registration)
        -- Compatibility path:
        -- validated media-only families may still carry a corpse record without a proof device.
        if not (payload and tostring(payload.mediaMode or "") == "media_only" and tostring(payload.caseFullType or "") ~= "") then
            return nil
        end
        logProof("media_only_compat_used", getTransferDiagDetail(zombie, nil, md, payload, registration, "media_only_payload"))
        return exportCorpseTransferRecord(nil, nil, md, payload, registration, {
            sourceHolder = zombie
        })
    end

    local function buildCorpseTransferRecord(zombie, diag)
        local md = getModData(zombie)
        local registration = getSpawnAtDeathRegistrationState(zombie)
        local payload = NMZombieMediaPayloadResolver
            and NMZombieMediaPayloadResolver.resolveStoredPayload
            and NMZombieMediaPayloadResolver.resolveStoredPayload(md)
            or nil
        local spec = resolveZombieStoredSpec(zombie, md)
        if not spec then
            return buildCompatibilityMediaOnlyTransferRecord(zombie, md, payload, registration)
        end

        local attachedTransferRecord = buildCanonicalAttachedTransferRecord(zombie, spec, md, payload, registration)
        if attachedTransferRecord then
            return attachedTransferRecord
        end

        local inventoryFallbackTransferRecord = buildFallbackInventoryTransferRecord(zombie, spec, md, payload, registration, diag)
        if inventoryFallbackTransferRecord then
            return inventoryFallbackTransferRecord
        end

        return buildCompatibilityMediaOnlyTransferRecord(zombie, md, payload, registration)
    end

    local function buildExistingBodyTransferRecord(body, bodySelection, proofSpec)
        local md = getModData(body)
        local registration = getSpawnAtDeathRegistrationState(body)
        local bodySpec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getSpec
            and NMZombieDeviceVariantCatalog.getSpec(bodySelection and bodySelection.variantId or "")
            or nil
        local resolvedSpec = proofSpec or bodySpec
        local payload = NMZombieMediaPayloadResolver
            and NMZombieMediaPayloadResolver.resolveStoredPayload
            and NMZombieMediaPayloadResolver.resolveStoredPayload(md)
            or nil
        return exportCorpseTransferRecord(resolvedSpec, nil, md, payload, registration, {
            sourceHolder = body,
            fullType = tostring(resolvedSpec and resolvedSpec.fullType or ""),
            attachmentLocation = tostring(resolvedSpec and resolvedSpec.attachmentLocation or ""),
            modelAttachmentName = tostring(resolvedSpec and resolvedSpec.modelAttachmentName or ""),
            strategy = tostring(bodySelection and bodySelection.strategy or ""),
            selection = bodySelection
        })
    end

    return {
        getCorpseLooseLootFullTypes = getCorpseLooseLootFullTypes,
        findAnyKnownProofItem = findAnyKnownProofItem,
        buildCorpseTransferRecord = buildCorpseTransferRecord,
        buildExistingBodyTransferRecord = buildExistingBodyTransferRecord
    }
end

return NMServerZombieCorpseTransferRecord
