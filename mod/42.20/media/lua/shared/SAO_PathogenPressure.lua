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

local function retainedKnowledge(id,form)
    local rec=SAO.Identity and SAO.Identity.get(id)
    local knowledge=rec and type(rec.mutationKnowledge)=="table" and rec.mutationKnowledge[form]
    if type(knowledge)~="table" then knowledge=nil end
    local weight=tonumber(knowledge and knowledge.weight) or 0
    if weight~=weight or math.abs(weight)==math.huge then weight=0 end
    weight=math.max(0,math.min(1,weight))
    local source=knowledge and knowledge.source
    if source~="lived" and source~="witnessed" and source~="told" then source="unfamiliar" end
    local lastDay=knowledge and knowledge.lastDay
    if type(lastDay)~="number" or lastDay~=lastDay or lastDay<0 or lastDay>1000000000 then lastDay=nil end
    return weight,source,lastDay
end

function Pathogen.multiplier(threat, actorId)
    local form = Pathogen.formOf(threat)
    local performance = Pathogen.performanceOf(threat)
    if not form or form == "none" then return 1.0 end
    local id = actorId or (threat and threat.id or nil)
    local adaptation = math.max(.5,1-retainedKnowledge(id,form)*.5)
    return (1.0 + performance * 0.5
        + Pathogen.attributePressure(threat)) * adaptation
end

function Pathogen.fleeDistance(id, threat)
    if not SAO.Disposition or not threat then return 8.0 end
    local form = Pathogen.formOf(threat)
    return SAO.Disposition.fleeDistance(id)
        * Pathogen.multiplier(threat, id)
end

-- Pure appraisal of this person's recognized form. Reconsidering a contact
-- does not acquire another encounter or consult anyone else's experience.
function Pathogen.appraise(id, threat)
    local rec=SAO.Identity and SAO.Identity.get(id)
    if not rec or rec.dead or not threat or not threat.form or threat.form=="none" then return nil end
    local weight,source,lastDay=retainedKnowledge(id,threat.form)
    local performance=tonumber(threat.formPerformance) or 0
    local attributes=Pathogen.attributePressure(threat)
    local multiplier=(1+performance*.5+attributes)*math.max(.5,1-weight*.5)
    local ordinary=SAO.Disposition.fleeDistance(id)
    return {actorId=id,contactKey=threat.key,source=threat.source,form=threat.form,performance=performance,
        attributePressure=attributes,adaptationWeight=weight,multiplier=multiplier,
        elevated=multiplier>1,withinConcern=threat.distance~=nil and threat.distance<=ordinary*multiplier,
        provenance={owner="SAO.PathogenPressure",observationSource=threat.source,
            ordinaryConcernDistance=ordinary,adjustedConcernDistance=ordinary*multiplier,
            knowledgeOwner=id,knowledgeSource=source,knowledgeLastDay=lastDay}}
end

return Pathogen
