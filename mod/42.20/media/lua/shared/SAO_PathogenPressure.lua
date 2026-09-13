-- SAO_PathogenPressure.lua - ZAO's pathogen state as living pressure.

SAO = SAO or {}
SAO.PathogenPressure = SAO.PathogenPressure or {}
local Pathogen = SAO.PathogenPressure

function Pathogen.formOf(threat)
    if type(threat) ~= "table" then return nil end
    return threat.form
end

function Pathogen.performanceOf(threat)
    if type(threat) ~= "table" then return 0 end
    return tonumber(threat.formPerformance) or 0
end

function Pathogen.attributePressure(threat)
    if type(threat) ~= "table" then return 0.0 end
    local total = 0.0
    local attributes = type(threat.attributeMutations) == "table"
        and threat.attributeMutations or {}
    for _, performance in pairs(attributes) do
        total = total + (tonumber(performance) or 0.0) * 0.10
    end
    return math.min(0.40, total)
end

function Pathogen.multiplier(threat)
    local form = Pathogen.formOf(threat)
    local performance = Pathogen.performanceOf(threat)
    if not form or form == "none" then return 1.0 end
    local id = threat and threat.id or nil
    local adaptation = SAO.Adaptation
        and SAO.Adaptation.riskMultiplier(id, form) or 1.0
    return (1.0 + performance * 0.5
        + Pathogen.attributePressure(threat)) * adaptation
end

function Pathogen.fleeDistance(id, threat)
    if not SAO.Disposition or not threat then return 8.0 end
    local form = Pathogen.formOf(threat)
    local adaptation = SAO.Adaptation
        and SAO.Adaptation.fleeAdjustment(id, form) or 1.0
    return SAO.Disposition.fleeDistance(id)
        * Pathogen.multiplier(threat)
end

return Pathogen
