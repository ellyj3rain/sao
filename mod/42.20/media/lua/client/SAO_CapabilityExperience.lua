-- Native result owners publish; each cognitive model interprets the same
-- admitted private evidence independently. Inspectors retain the richer receipts.
require "SAO_Pharmacology"
require "SAO_Cooking"
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
