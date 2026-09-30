-- Native result owners publish; each cognitive model interprets the same
-- admitted private evidence independently. Inspectors retain the richer receipts.
require "SAO_Pharmacology"
require "SAO_Cooking"
require "SAO_ResourceProduction"
require "SAO_Cognition"

SAO.Pharmacology.onNativeOutcome = function(id, receipt)
    if SAO.Cognition and SAO.Cognition.medicationUse then
        return SAO.Cognition.medicationUse(id, receipt)
    end
    return false
end

SAO.Pharmacology.onNativeChange = function(id, receipt)
    if SAO.Cognition and SAO.Cognition.physicalChange then
        return SAO.Cognition.physicalChange(id, receipt)
    end
    return false
end

SAO.Cooking.onOutcome = function(id, receipt)
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.reconcileCooking then
        pcall(SAO.ProceduralPlanning.reconcileCooking, id)
    end
    if receipt and receipt.commitmentId and SAO.Organization
        and SAO.Organization.consumeProcedureResult then
        pcall(SAO.Organization.consumeProcedureResult, {
            id = receipt.id, actorId = id,
            commitmentId = receipt.commitmentId,
            stepId = receipt.stepId,
            token = receipt.token or "cooking:prepared",
            owner = "Cooking", status = receipt.status == "completed"
                and "completed" or receipt.status == "interrupted"
                and "interrupted" or "failed",
            reason = receipt.detail, at = receipt.atHours,
            evidence = { itemId = receipt.itemId,
                itemType = receipt.itemType,
                nativeCredit = receipt.nativeCredit,
                retrieved = receipt.retrieved == true,
                heatObserved = receipt.heatObserved == true },
        })
    end
    if SAO.Cognition and SAO.Cognition.preparationOutcome then
        return SAO.Cognition.preparationOutcome(id, receipt)
    end
    return false
end

-- A native fill acquires fluid into a held vessel. It is neither ingestion
-- nor evidence of bodily relief. The result owner retains its richer proof.
local function finiteAmount(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
SAO.ResourceProduction.onOutcome = function(id, receipt)
    local canonical = receipt and SAO.ResourceProduction.outcome(id, receipt.id)
    if not canonical or canonical.actorId ~= id or canonical.kind ~= "refill-water"
        or canonical.token ~= "resource:filled" then return false end
    if canonical.experienceDelivered then return true end
    if canonical.status ~= "completed" and canonical.status ~= "interrupted"
        and canonical.status ~= "failed" then return false end
    if not canonical.cognitiveToken then return true end
    local completed = canonical.status == "completed"
    if completed and (canonical.nativeCredit ~= canonical.id or canonical.held ~= true
        or canonical.clean ~= true or not finiteAmount(canonical.nativeGain)
        or canonical.nativeGain <= 0 or not finiteAmount(canonical.beforeAmount)
        or not finiteAmount(canonical.afterAmount) or canonical.beforeAmount < 0
        or canonical.afterAmount <= canonical.beforeAmount) then return false end
    if not SAO.Cognition or not SAO.Cognition.publish then return false end
    return SAO.Cognition.publish(id, canonical.cognitiveToken, {
        kind = "acquire", category = "water", sourceId = canonical.sourceId,
        itemType = canonical.itemType,
        status = completed and "completed" or canonical.status == "interrupted" and "interrupted" or "unavailable",
        detail = completed and "native-vessel-water-fill" or canonical.detail,
    })
end
