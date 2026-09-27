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
    if SAO.Cognition and SAO.Cognition.preparationOutcome then
        return SAO.Cognition.preparationOutcome(id, receipt)
    end
    return false
end
