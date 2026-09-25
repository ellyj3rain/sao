-- SAO_Provisioning - native results into private experience and material records.
--
-- SourceUse proves one actor performed one exact native action. This module is
-- the sole downstream consumer of that result ledger. Captured native moves
-- reach durable private minds even if later action reconciliation conflicts.
-- Completed actions also reconcile the exact source's latest isolated inventory
-- into partial material state before acknowledgement. Reservations and queue
-- acceptance carry no result.

SAO = SAO or {}
SAO.Provisioning = SAO.Provisioning or {}
local Provisioning = SAO.Provisioning

local CONSUMER = "provisioning"
local DELIVERY_STORE = "SurvivorAwareness_Provisioning"
local DEFAULT_LIMIT = 32
local MAX_LIMIT = 128

local function deliveryState()
    local ok, value = pcall(function()
        return ModData.getOrCreate(DELIVERY_STORE)
    end)
    if not ok or type(value) ~= "table" then return nil end
    local schema = tonumber(value.schema) or 0
    if schema > 1 then return nil end
    value.schema = 1
    return value
end

local function insideClaim(claim, source, receipt)
    if type(claim) ~= "table" then return false end
    local x = tonumber(source and source.x) or tonumber(receipt and receipt.sourceX)
    local y = tonumber(source and source.y) or tonumber(receipt and receipt.sourceY)
    return x ~= nil and y ~= nil
        and x >= claim.minX and x <= claim.maxX
        and y >= claim.minY and y <= claim.maxY
end

local function acknowledge(receipt, reason)
    local accepted = SAO.WorldSources.acknowledgeResult(
        receipt.reservationId, CONSUMER, reason)
    return accepted == true
end

local function insideReceiptPlace(receipt, source)
    if type(receipt) ~= "table" or type(source) ~= "table" then return false end
    if receipt.placeId ~= nil and source.buildingId ~= nil
        and tostring(source.buildingId) == tostring(receipt.placeId) then
        return true
    end
    local x, y = tonumber(source.x), tonumber(source.y)
    local minX, minY = tonumber(receipt.placeMinX), tonumber(receipt.placeMinY)
    local maxX, maxY = tonumber(receipt.placeMaxX), tonumber(receipt.placeMaxY)
    return x ~= nil and y ~= nil and minX ~= nil and minY ~= nil
        and maxX ~= nil and maxY ~= nil
        and x >= minX and x < maxX and y >= minY and y < maxY
end

local function derivationEvidence(receipt, generation, evidenceAt)
    return {
        reservationId = receipt.reservationId,
        actorId = receipt.actorId,
        sourceId = receipt.sourceId,
        placeId = receipt.placeId,
        postRevision = receipt.postRevision,
        status = receipt.status,
        at = tonumber(evidenceAt) or tonumber(receipt.at) or 0,
        resultAt = receipt.at,
        order = receipt.order,
        materialProjectionEnabled = receipt.materialProjectionEnabled,
        materialGeneration = tonumber(generation) or 0,
        completeCoverage = true,
    }
end

local function standingFrom(store, groupId, evidence)
    -- One used source is exact material evidence, but it is not a complete
    -- inventory of the held place. Aggregate larder/water claims remain owned
    -- by a complete Material reconciliation that proves claim-wide coverage.
    if type(store) ~= "table" or type(store.coverage) ~= "table"
        or store.coverage.complete ~= true then
        return true
    end
    if not (SAO.Standing and SAO.Standing.provisioningMembers
        and SAO.Standing.setLarder and SAO.Standing.setWaterStore) then
        return false
    end
    local members = SAO.Standing.provisioningMembers(groupId)
    if type(members) ~= "table" then return false end
    local count = #members
    if count == 0 then return true end
    local categories = store.categories or {}
    local food = tonumber(categories.food) or 0
    local water = tonumber(categories.water) or 0
    local foodWord = food <= 0 and "lean"
        or food >= count and "full" or "fair"
    local waterWord = water <= 0 and "dry"
        or water >= count and "full" or "fair"
    local larder = SAO.Standing.setLarder(groupId, foodWord, food,
        "completed-native-source-results", evidence)
    local waterStore = SAO.Standing.setWaterStore(groupId, waterWord, water,
        "completed-native-source-results", evidence)
    return larder == true and waterStore == true
end

local function deriveAndAcknowledge(receipt, affected, outcome)
    if not (SAO.Material and SAO.Material.finishReconciliation
        and SAO.Material.derivationComplete
        and SAO.Material.markDerivationComplete) then
        return false, "material-finish-unavailable"
    end
    for _, projection in ipairs(affected or {}) do
        local groupId = projection.groupId
        local evidence = derivationEvidence(receipt, projection.generation,
            projection.evidenceAt)
        if not SAO.Material.derivationComplete(receipt.reservationId,
            groupId, "standing") then
            local standingOk, standingReady = pcall(standingFrom,
                projection.store, groupId, evidence)
            if not standingOk or not standingReady then
                return false, "standing-unavailable"
            end
            if not SAO.Material.markDerivationComplete(receipt.reservationId,
                groupId, "standing") then
                return false, "material-derivation-unavailable"
            end
        end
        if not SAO.Material.derivationComplete(receipt.reservationId,
            groupId, "recognition") then
            local complete = type(projection.store) == "table"
                and type(projection.store.coverage) == "table"
                and projection.store.coverage.complete == true
            if complete then
                if not (SAO.Settlement
                    and type(SAO.Settlement.bases) == "table") then
                    return false, "settlement-unavailable"
                end
                local settlementExists = SAO.Settlement.bases[groupId] ~= nil
                if settlementExists then
                    if not (SAO.Recognition and SAO.Recognition.onProvisioned) then
                        return false, "recognition-unavailable"
                    end
                    local ok, accepted = pcall(SAO.Recognition.onProvisioned,
                        groupId, {
                            receipt = evidence,
                            material = projection.store,
                        })
                    if not ok then return false, "recognition-fault" end
                    if accepted ~= true then
                        return false, "recognition-refused"
                    end
                end
            end
            if not SAO.Material.markDerivationComplete(receipt.reservationId,
                groupId, "recognition") then
                return false, "material-derivation-unavailable"
            end
        end
    end
    if not acknowledge(receipt, outcome or "reconciled") then
        return false, "ack-refused"
    end
    -- Acknowledgement is the durable terminal fact. Retire the replay decision
    -- afterwards; consumeCompleted also cleans it if execution stops here.
    SAO.Material.finishReconciliation(receipt.reservationId)
    return true, outcome or "reconciled"
end

-- Drain native changes for sources already copied into a house projection.
-- These observations never create an owner and never carry action credit; they
-- only keep the exact prior projection synchronized with current engine truth.
function Provisioning.refreshProjectedSources(limit)
    if not (SAO.WorldSources and SAO.WorldSources.pendingProjectionChanges
        and SAO.WorldSources.acknowledgeProjectionChange and SAO.Material
        and SAO.Material.refreshProjectedSource
        and SAO.WorldSources.sourceProjection) then
        return 0, 0
    end
    limit = math.floor(tonumber(limit) or DEFAULT_LIMIT)
    if limit < 1 then limit = 1 end
    if limit > MAX_LIMIT then limit = MAX_LIMIT end
    local changes = SAO.WorldSources.pendingProjectionChanges(limit)
    if type(changes) ~= "table" then return 0, 0 end
    local refreshed, pending = 0, 0
    for _, change in ipairs(changes) do
        local source, state = SAO.WorldSources.sourceProjection(change.sourceId)
        if state == "store-unavailable" then
            pending = pending + 1
        else
            local ok, accepted = pcall(SAO.Material.refreshProjectedSource,
                change, source, state)
            if ok and accepted == true
                and SAO.WorldSources.acknowledgeProjectionChange(
                    change.sourceId, change.order) then
                refreshed = refreshed + 1
            else
                pending = pending + 1
            end
        end
    end
    return refreshed, pending
end

local function cleanupAcknowledgedReconciliations()
    if not (SAO.Material and SAO.Material.reconciliations
        and SAO.Material.finishReconciliation and SAO.WorldSources
        and SAO.WorldSources.resultAcknowledged) then return 0 end
    local finished = {}
    for reservationId in pairs(SAO.Material.reconciliations) do
        if SAO.WorldSources.resultAcknowledged(reservationId, CONSUMER) then
            finished[#finished + 1] = reservationId
        end
    end
    for _, reservationId in ipairs(finished) do
        SAO.Material.finishReconciliation(reservationId)
    end
    return #finished
end

function Provisioning.processReceipt(receipt)
    local coordinated = type(receipt) == "table"
        and receipt.commitmentId ~= nil
        and tostring(receipt.commitmentId) ~= ""
    if type(receipt) ~= "table"
        or (receipt.status ~= "completed" and receipt.transferObservation == nil
            and not coordinated)
        or type(receipt.reservationId) ~= "string" then
        return false, "invalid-result"
    end
    if not (SAO.WorldSources and SAO.WorldSources.acknowledgeResult) then
        return false, "world-sources-unavailable"
    end
    -- Private experience is independent of the optional material projection.
    -- The ledger remains unacknowledged until the captured witnesses can be
    -- delivered to their durable minds. No current roster supplies recipients.
    if receipt.transferObservation ~= nil then
        if not (SAO.Perception and SAO.Perception.receiveTransferResult
            and SAO.Perception.bindPersistentStore
            and SAO.Perception.bindPersistentStore() == true) then
            return false, "perception-unavailable"
        end
        local accepted, why = SAO.Perception.receiveTransferResult(receipt)
        if accepted ~= true then return false, why or "perception-refused" end
    end
    -- Organization consumes the same native receipt before the sole ledger
    -- acknowledgement. Its own receipt idempotency makes reload retry safe;
    -- queue admission alone never advances shared work to completion.
    if receipt.commitmentId ~= nil then
        if not (SAO.GraphPersistence and SAO.GraphPersistence.bind
            and SAO.Organization and SAO.Organization.consumeSourceResult) then
            return false, "organization-unavailable"
        end
        local bound, bindWhy = SAO.GraphPersistence.bind()
        if bound ~= true then return false, bindWhy or "graph-unavailable" end
        local consumed, consumeWhy = SAO.Organization.consumeSourceResult(receipt)
        if consumed ~= true then
            return false, consumeWhy or "organization-result-refused"
        end
    end
    -- A proved native move remains an experience when later conservation or
    -- holder checks conflict. Deliver that experience without crediting a
    -- completed action or projecting any material or social result.
    if receipt.status ~= "completed" then
        local reason = receipt.transferObservation ~= nil
            and "native-observation-delivered"
            or "coordination-result-delivered"
        if not SAO.WorldSources.acknowledgeResult(receipt.reservationId,
            CONSUMER, reason) then return false, "ack-refused" end
        return true, reason
    end
    if not (SAO.GraphPersistence and SAO.GraphPersistence.bind) then
        return false, "graph-unavailable"
    end
    local graphBound, graphWhy = SAO.GraphPersistence.bind()
    if graphBound ~= true then
        return false, graphWhy == "future-schema"
            and "graph-future-schema" or "graph-unavailable"
    end
    local context = tostring(receipt.provisioningContext or "")
    local legacy = context == "legacy-unattributed"
    local groupId = receipt.provisioningGroup
    if groupId ~= nil and tostring(groupId) ~= "" then
        groupId = tostring(groupId)
    else
        groupId = nil
    end
    if not legacy and ((context == "held-group" and not groupId)
        or (context == "personal" and groupId)
        or (context ~= "held-group" and context ~= "personal")) then
        return false, "invalid-provisioning-context"
    end
    if not legacy and (type(receipt.sourceId) ~= "string"
        or receipt.sourceId == ""
        or type(receipt.sourceFingerprint) ~= "string"
        or receipt.sourceFingerprint == "") then
        return false, "invalid-result"
    end
    if not legacy and type(receipt.materialProjectionEnabled) ~= "boolean" then
        return false, "invalid-result"
    end
    local claimIncarnation = tonumber(receipt.provisioningClaimIncarnation)
    if context == "held-group"
        and (not claimIncarnation or claimIncarnation <= 0) then
        return false, "invalid-provisioning-context"
    end
    -- Material is an optional record surface. Turning it off preserves the
    -- performed native action but publishes no house, standing or settlement
    -- projection, matching the sandbox contract instead of retrying forever.
    local inFlight = SAO.Material and SAO.Material.reconciliations
        and SAO.Material.reconciliations[receipt.reservationId] ~= nil
    if receipt.materialProjectionEnabled == false and not inFlight then
        if not acknowledge(receipt, "material-disabled") then
            return false, "ack-refused"
        end
        return true, "material-disabled"
    end
    if not (SAO.WorldSources.sourceProjection and SAO.Material
        and SAO.Material.reconcileSource) then
        return false, "projection-unavailable"
    end

    if SAO.Material.resumeReconciliation then
        local resumed, affected, outcome =
            SAO.Material.resumeReconciliation(receipt.reservationId)
        if resumed then
            return deriveAndAcknowledge(receipt, affected, outcome)
        end
    end

    -- C62 receipts already durable when C63 arrives have no captured
    -- attribution or fingerprint. Later membership cannot reconstruct the
    -- action-time fact, so retire them explicitly without granting ownership.
    if legacy and (type(receipt.sourceFingerprint) ~= "string"
        or receipt.sourceFingerprint == "") then
        if not acknowledge(receipt, "legacy-unattributed") then
            return false, "ack-refused"
        end
        return true, "legacy-unattributed"
    end

    local effectiveContext = context
    local resolution = nil
    local currentClaim = nil
    if legacy then
        groupId = nil
        effectiveContext = "personal"
        resolution = "unattributed-use"
    elseif context == "held-group" then
        if not (SAO.Standing and SAO.Standing.provisioningClaimOf) then
            return false, "standing-unavailable"
        end
        local okClaim, ready, claim = pcall(
            SAO.Standing.provisioningClaimOf, groupId)
        if not okClaim or ready ~= true then
            return false, "standing-unavailable"
        end
        if not claim or tonumber(claim.claimIncarnation) ~= claimIncarnation then
            groupId = nil
            effectiveContext = "retired-group"
            resolution = "held-ground-retired"
        else
            currentClaim = claim
        end
    end

    local source, sourceState = nil, "source-absent"
    if effectiveContext ~= "retired-group" then
        source, sourceState = SAO.WorldSources.sourceProjection(receipt.sourceId)
        if sourceState == "store-unavailable"
            or sourceState == "source-conflict" then
            return false, sourceState
        end
    end
    if sourceState == "source-absent" and receipt.sourceKind ~= "ground"
        and not inFlight and effectiveContext ~= "retired-group" then
        -- Chunk compaction can make an old observation unavailable. Only the
        -- completing ground-item action proves that absence is its physical
        -- postcondition. Personal/unattributed use with no prior projection
        -- has no ownership state to refresh and can retire as an exact no-op.
        local owner = SAO.Material.projectedOwner
            and SAO.Material.projectedOwner(receipt.sourceId,
                receipt.sourceFingerprint) or nil
        if (context == "personal" or legacy) and not owner then
            if not acknowledge(receipt, legacy
                and "unattributed-no-projection" or "personal-no-projection") then
                return false, "ack-refused"
            end
            return true, legacy and "unattributed-use" or "personal-use"
        end
        return false, "source-unobserved"
    end
    receipt.materialEvidenceAt = tonumber(source and source.observedAt)
        or tonumber(receipt.at) or 0
    if source and (type(receipt.sourceFingerprint) ~= "string"
        or receipt.sourceFingerprint == ""
        or tostring(source.fingerprint) ~= receipt.sourceFingerprint) then
        -- A resolved replacement proves the old physical source is gone. Do
        -- not project the replacement through the old action; remove only the
        -- old fingerprint from any house that still carries it.
        source = nil
        resolution = "source-replaced"
    end
    if source and not insideReceiptPlace(receipt, source) then
        -- A vehicle or ground source that subsequently left this place no
        -- longer contributes to its material projection.
        source = nil
    end

    if effectiveContext == "held-group" then
        if not insideClaim(currentClaim, source, receipt) then
            -- The action happened while this ground was held, but delayed
            -- delivery may outlive abandonment, relocation or dissolution.
            -- Remove stale ownership if present and never resurrect the house.
            groupId = nil
            effectiveContext = "retired-group"
            resolution = resolution or "held-ground-retired"
        end
    end

    local outcome = resolution
    if not outcome then
        if groupId then
            outcome = source and "reconciled" or "source-absent"
        else
            outcome = source and "personal-refresh" or "personal-use"
        end
    end
    local reconciled, store, affected = SAO.Material.reconcileSource(groupId,
        receipt, source, effectiveContext, outcome)
    if not reconciled then return false, "material-refused" end
    local projections = affected or {
        { groupId = groupId, store = store },
    }
    return deriveAndAcknowledge(receipt, projections, outcome)
end

function Provisioning.consumeCompleted(limit)
    if not (SAO.WorldSources and SAO.WorldSources.completedResults) then
        return 0, 0
    end
    limit = math.floor(tonumber(limit) or DEFAULT_LIMIT)
    if limit < 1 then limit = 1 end
    if limit > MAX_LIMIT then limit = MAX_LIMIT end
    local delivery = deliveryState()
    if not delivery then return 0, 0 end
    Provisioning.refreshProjectedSources(limit)
    cleanupAcknowledgedReconciliations()
    local consumed, pending = 0, 0
    local results = SAO.WorldSources.completedResults(CONSUMER, true)
    if #results == 0 then
        delivery.cursor = nil
        return 0, 0
    end
    local start = 1
    if delivery.cursor then
        for index, receipt in ipairs(results) do
            if receipt.reservationId == delivery.cursor then
                start = (index % #results) + 1
                break
            end
        end
    end
    local considered = math.min(limit, #results)
    for offset = 0, considered - 1 do
        local index = ((start + offset - 1) % #results) + 1
        local receipt = results[index]
        delivery.cursor = receipt.reservationId
        local ok = Provisioning.processReceipt(receipt)
        if ok then consumed = consumed + 1 else pending = pending + 1 end
    end
    return consumed, pending
end

return Provisioning
