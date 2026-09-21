-- SAO_Settlement.lua - group territory, occupancy, and material use.

SAO = SAO or {}
SAO.Settlement = SAO.Settlement or {}
local Settlement = SAO.Settlement

Settlement.bases = Settlement.bases or {}

local function completedGrounding(evidence)
    if type(evidence) ~= "table"
        or evidence.producer ~= "place-development"
        or evidence.status ~= "completed"
        or type(evidence.resultId) ~= "string"
        or evidence.resultId == "" then
        return nil
    end
    return {
        producer = "place-development",
        resultId = evidence.resultId,
        at = tonumber(evidence.at) or 0,
    }
end

function Settlement.isGrounded(base)
    if type(base) ~= "table" or type(base.grounding) ~= "table" then
        return false
    end
    return base.grounding.producer == "place-development"
        and type(base.grounding.resultId) == "string"
        and base.grounding.resultId ~= ""
end

function Settlement.scoreBuilding(building)
    if type(building) ~= "table" then return 0 end
    local rooms = tonumber(building.rooms) or 0
    local area = tonumber(building.area) or 0
    local water = building.water and 1 or 0
    local food = building.food and 1 or 0
    local tools = building.tools and 1 or 0
    return rooms * 2 + area * 0.1 + water * 3 + food * 2 + tools
end

-- Only a completed place/development result may ground a settlement. The
-- caller owns that performed result; this projection neither founds an
-- organization nor infers a settlement from provisioning or group existence.
function Settlement.claim(organizationId, building, evidence)
    local grounding = completedGrounding(evidence)
    if type(organizationId) ~= "string" or organizationId == ""
        or type(building) ~= "table" or not grounding then
        return nil
    end
    local base = {
        organization = organizationId,
        building = building,
        score = Settlement.scoreBuilding(building),
        members = {},
        storage = {},
        claimedAt = 0,
        grounding = grounding,
    }
    Settlement.bases[organizationId] = base
    return base
end

function Settlement.occupy(organizationId, personId)
    local base = Settlement.bases[organizationId]
    if not base then return false end
    base.members[personId] = true
    return true
end

function Settlement.leave(organizationId, personId)
    local base = Settlement.bases[organizationId]
    if not base then return false end
    base.members[personId] = nil
    local count = 0
    for _ in pairs(base.members) do count = count + 1 end
    if count == 0 then
        Settlement.bases[organizationId] = nil
    end
    return true
end

function Settlement.store(organizationId, item, amount)
    local base = Settlement.bases[organizationId]
    if not base then return false end
    if base.storageProjection == "native-sources" then return false end
    base.storage[item] = (base.storage[item] or 0) + amount
    return true
end

-- A settlement may expose an already-grounded house store, but provisioning
-- does not create the settlement or its building. Reconciliation replaces the
-- storage projection from Material and is therefore idempotent on redelivery.
function Settlement.reconcileStorage(organizationId, materialStore, receipt)
    local base = Settlement.bases[organizationId]
    if not Settlement.isGrounded(base) or type(materialStore) ~= "table"
        or materialStore.projection ~= "native-sources"
        or type(materialStore.coverage) ~= "table"
        or materialStore.coverage.complete ~= true
        or type(receipt) ~= "table" or receipt.status ~= "completed" then
        return false
    end
    local prior = base.storageEvidence
    local priorGeneration = tonumber(prior and prior.materialGeneration)
    local incomingGeneration = tonumber(receipt.materialGeneration)
    local priorAt, incomingAt = tonumber(prior and prior.at),
        tonumber(receipt.at)
    local priorOrder, incomingOrder = tonumber(prior and prior.order),
        tonumber(receipt.order)
    local generationSuperseded = priorGeneration and incomingGeneration
        and priorGeneration > incomingGeneration
    local sameGeneration = not (priorGeneration and incomingGeneration)
        or priorGeneration == incomingGeneration
    if generationSuperseded or (sameGeneration and priorAt and incomingAt
        and (priorAt > incomingAt or (priorAt == incomingAt
            and priorOrder and incomingOrder and priorOrder > incomingOrder))) then
        return true
    end
    local storage = {}
    for item, amount in pairs(materialStore.items or {}) do
        if type(item) == "string" and type(amount) == "number" and amount > 0 then
            storage[item] = amount
        end
    end
    base.storage = storage
    base.storageProjection = "native-sources"
    base.storageEvidence = {
        reservationId = receipt.reservationId,
        actorId = receipt.actorId,
        sourceId = receipt.sourceId,
        placeId = receipt.placeId,
        postRevision = receipt.postRevision,
        at = receipt.at,
        resultAt = receipt.resultAt,
        order = receipt.order,
        materialGeneration = receipt.materialGeneration,
    }
    return true
end

-- A house that releases or moves its held ground no longer has access to the
-- native sources projected from that place. Keep the independently grounded
-- settlement record, but clear its group-owned storage view immediately.
function Settlement.clearStorageProjection(organizationId)
    local base = Settlement.bases[tostring(organizationId or "")]
    if not base then return true end
    base.storage = {}
    base.storageProjection = nil
    base.storageEvidence = nil
    return true
end

function Settlement.take(organizationId, item, amount)
    local base = Settlement.bases[organizationId]
    if not base then return 0 end
    if base.storageProjection == "native-sources" then return 0 end
    local available = base.storage[item] or 0
    if available < amount then return 0 end
    base.storage[item] = available - amount
    if base.storage[item] <= 0 then base.storage[item] = nil end
    return amount
end

function Settlement.bestBase()
    local best, bestScore
    for _, base in pairs(Settlement.bases) do
        if not bestScore or base.score > bestScore then
            best, bestScore = base, base.score
        end
    end
    return best
end

return Settlement
