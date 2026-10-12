-- Personal conceptual expectations. This small ordinary-life prior vocabulary
-- is an explicit foundation, not an acquired curriculum or assessed education.
-- Perception owns exact places/objects; these relations never supply coordinates.
SAO = SAO or {}
SAO.ConceptKnowledge = SAO.ConceptKnowledge or {}
local K = SAO.ConceptKnowledge
local MAX_RELATIONS, MAX_DEPTH, MAX_WORK = 64, 5, 128
local MAX_WITNESSES = 16
local RELATIONS = { ["typically-contains"]=true, ["may-contain"]=true, contains=true, affords=true,
    supports=true, ["is-a"]=true, enables=true, ["may-cause"]=true }
local PRIORS = {
    {"room", "may-contain", "bed"},
    {"room", "may-contain", "food"},
    {"room", "may-contain", "water"},
    {"house", "typically-contains", "bedroom"},
    {"house", "typically-contains", "kitchen"},
    {"residence", "typically-contains", "bedroom"},
    {"residence", "typically-contains", "kitchen"},
    {"bedroom", "typically-contains", "bed"},
    {"bed", "affords", "sleep"},
    {"sleeping-furniture", "affords", "sleep"},
    {"sleep", "supports", "relief-from-tiredness"},
    {"seat", "affords", "rest"},
    {"rest", "supports", "relief-from-exertion"},
    {"kitchen", "typically-contains", "food"},
    {"kitchen", "typically-contains", "water"},
    {"container", "typically-contains", "contents"},
    {"container", "may-contain", "food"},
    {"container", "may-contain", "water"},
    {"sink", "may-contain", "water"},
    {"food", "affords", "eating"},
    {"eating", "supports", "relief-from-hunger"},
    {"water", "affords", "drinking"},
    {"drinking", "supports", "relief-from-thirst"},
    {"book", "affords", "reading"},
    {"assault", "may-cause", "bodily-harm"},
    {"separation", "supports", "break-contact"},
    {"obstruction", "may-cause", "blocks-movement"},
    {"defense", "supports", "create-space"},
    {"force", "supports", "stop-threat"},
    {"communication", "supports", "possible-agreement"},
    {"cooperation", "supports", "mutual-support"},
    {"coercion", "supports", "imposed-compliance"},
    {"concession", "supports", "possible-agreement"},
    {"reading", "supports", "understanding"},
    {"reading", "supports", "recreation"},
    {"music", "supports", "recreation"},
    {"art", "supports", "recreation"},
    {"games", "supports", "recreation"},
    {"exercise", "supports", "physical-practice"},
    {"exercise", "may-cause", "relief-from-stress"},
    {"exploration", "supports", "discovery"},
}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1000000000 end
local function word(s) return type(s)=="string" and #s>0 and #s<=96 and s:match("^[%w_:%-%.]+$")~=nil end
local function copy(v)
    if type(v)~="table" then return v end
    local out={} for key,value in pairs(v) do out[key]=copy(value) end return out
end
local function record(id)
    return type(id)=="string" and SAO.Identity and SAO.Identity.get(id) or nil
end
local function state(id, create)
    local rec=record(id)
    if not rec or rec.dead then return nil end
    if not rec.conceptKnowledge and create then
        rec.conceptKnowledge={schema=1,sequence=0,relations={},order={},omitted=0}
    end
    local s=rec.conceptKnowledge
    return type(s)=="table" and s.schema==1 and type(s.relations)=="table"
        and type(s.order)=="table" and finite(s.sequence) and s or nil
end
local function valid(edge)
    return type(edge)=="table" and word(edge.from) and word(edge.into)
        and RELATIONS[edge.relation] and (edge.contextId==nil or word(edge.contextId))
        and (edge.affirmed==nil or type(edge.affirmed)=="boolean")
end
local function key(edge)
    return table.concat({edge.from,edge.relation,edge.into,edge.contextId or "*"},"|")
end
local function reusable(row,id,identity,at)
    local prefix="concept/"..id.."/"
    return valid(row) and row.actorId==id and key(row)==identity
        and type(row.id)=="string" and #row.id<=160 and row.id:sub(1,#prefix)==prefix
        and row.id:sub(#prefix+1):match("^%d+$")~=nil
        and type(row.sourceId)=="string" and #row.sourceId>0 and #row.sourceId<=512
        and finite(row.acquiredAt) and finite(at) and row.acquiredAt<=at
end
-- Supporting observations belong to the private person record. A second
-- object can support the same proposition without replacing its acquisition
-- or becoming a new proposition to tell. These rows are never exported as
-- part of the association offered to another person.
local function witness(s,row,provenance)
    local at=provenance.acquiredAt
    if not finite(at) or not finite(row.acquiredAt) or row.acquiredAt>at then return end
    if type(s.witnesses)~="table" then s.witnesses={} end
    local retained={}
    for index=1,math.min(#s.order,MAX_RELATIONS) do
        local identity=s.order[index]
        local held=s.relations[identity]
        if reusable(held,row.actorId,identity,at) then retained[held.id]=s.witnesses[held.id] end
    end
    s.witnesses=retained
    local saved=s.witnesses[row.id]
    local old=type(saved)=="table" and type(saved.rows)=="table" and saved.rows or {}
    local support={rows={{sourceId=row.sourceId,basis=row.basis,
        acquiredAt=row.acquiredAt,lastObservedAt=row.acquiredAt,
        speakerId=row.speakerId,channel=row.channel,parentId=row.parentId}},
        truncated=type(saved)=="table" and saved.truncated==true or #old>MAX_WITNESSES or nil}
    -- Reloaded supporting metadata is not fresh observation authority. Admit
    -- only bounded, dated provenance of this revision; a bad row cannot make
    -- a later authentic observation throw or backfill future evidence.
    for index=1,math.min(#old,MAX_WITNESSES) do
        local candidate=old[index]
        if type(candidate)=="table" and type(candidate.sourceId)=="string" and #candidate.sourceId>0 and #candidate.sourceId<=512
            and candidate.basis==row.basis and finite(candidate.acquiredAt)
            and candidate.acquiredAt>=row.acquiredAt and finite(candidate.lastObservedAt)
            and candidate.lastObservedAt>=candidate.acquiredAt and candidate.lastObservedAt<=at then
            local existing
            for _,prior in ipairs(support.rows) do
                if prior.sourceId==candidate.sourceId then existing=prior;break end
            end
            if existing then
                existing.lastObservedAt=math.max(existing.lastObservedAt,candidate.lastObservedAt)
            elseif #support.rows<MAX_WITNESSES then
                support.rows[#support.rows+1]={sourceId=candidate.sourceId,basis=candidate.basis,
                    acquiredAt=candidate.acquiredAt,lastObservedAt=candidate.lastObservedAt,
                    speakerId=type(candidate.speakerId)=="string" and #candidate.speakerId<=160 and candidate.speakerId or nil,
                    channel=type(candidate.channel)=="string" and #candidate.channel<=64 and candidate.channel or nil,
                    parentId=type(candidate.parentId)=="string" and #candidate.parentId<=160 and candidate.parentId or nil}
            else support.truncated=true end
        end
    end
    s.witnesses[row.id]=support
    for _,prior in ipairs(support.rows) do
        if prior.sourceId==provenance.sourceId and prior.basis==provenance.basis then
            prior.lastObservedAt=math.max(prior.lastObservedAt,provenance.acquiredAt)
            return
        end
    end
    if #support.rows>=MAX_WITNESSES then support.truncated=true;return end
    support.rows[#support.rows+1]={sourceId=provenance.sourceId,basis=provenance.basis,
        acquiredAt=provenance.acquiredAt,lastObservedAt=provenance.acquiredAt,
        speakerId=provenance.speakerId,channel=provenance.channel,parentId=provenance.parentId}
end
local function retain(id, edge, provenance)
    if not valid(edge) then return false,"invalid-relation" end
    local s=state(id,true)
    if not s then return false,"person-unavailable" end
    local identity=key(edge)
    local prior=s.relations[identity]
    if reusable(prior,id,identity,provenance.acquiredAt) and prior.affirmed==(edge.affirmed~=false)
        and provenance.literature==nil
        and prior.basis==provenance.basis then
        witness(s,prior,provenance)
        return true,copy(prior)
    end
    if prior==nil then
        if #s.order>=MAX_RELATIONS then
            local oldest=table.remove(s.order,1)
            s.relations[oldest]=nil;s.omitted=s.omitted+1
        end
        s.order[#s.order+1]=identity
    end
    s.sequence=s.sequence+1
    local row={id="concept/"..id.."/"..s.sequence,actorId=id,from=edge.from,into=edge.into,
        relation=edge.relation,contextId=edge.contextId,affirmed=edge.affirmed~=false,
        basis=provenance.basis,sourceId=provenance.sourceId,speakerId=provenance.speakerId,
        acquiredAt=provenance.acquiredAt,channel=provenance.channel,
        parentId=provenance.parentId,modal=provenance.basis~="observed-relation",
        literature=provenance.literature and copy(provenance.literature) or nil,
        policy=provenance.policy and copy(provenance.policy) or nil,
        lastUsedAt=provenance.literature and provenance.acquiredAt or nil,
        usageCount=provenance.literature and 0 or nil}
    s.relations[identity]=row
    witness(s,row,provenance)
    return true,copy(row)
end
-- Only Perception's canonical same-room observation can supply this relation.
function K.observeRelation(id, roomKey, objectKey)
    local perception=SAO.Perception
    local a=perception and perception.conceptObservation and perception.conceptObservation(id,roomKey)
    local b=perception and perception.conceptObservation and perception.conceptObservation(id,objectKey)
    if not a or not b or a.kind~="room" or b.kind~="object" or a.roomId~=b.roomId
        or a.buildingId~=b.buildingId or a.at~=b.at then return false,"observation-not-shared" end
    local accepted,receipt=retain(id,{from=a.concept,relation="contains",into=b.concept,contextId=a.buildingId},
        {basis="observed-relation",sourceId=a.key..":"..b.key,acquiredAt=SAO.History.countyHours()})
    if accepted then
        -- A remembered pairing may suggest another instance; it is not an
        -- observation of that other room and carries the original evidence.
        retain(id,{from=a.concept,relation="typically-contains",into=b.concept},
            {basis="personal-association",sourceId=receipt.id,acquiredAt=SAO.History.countyHours()})
    end
    return accepted,receipt
end
-- Owned assessment remains in the person's existing conceptual store. Saved
-- answers carry their exact exposure and source; queries only project decay.
local LEARNING_LIMIT=32
local function learningRows(id,create)
    local s=state(id,create)
    if not s then return nil end
    if create and not s.readingAssessments then s.readingAssessments={sequence=0,rows={},readThrough=0,useReceipts={}} end
    local l=s.readingAssessments
    return type(l)=="table" and finite(l.sequence) and type(l.rows)=="table" and #l.rows<=LEARNING_LIMIT
        and finite(l.readThrough) and type(l.useReceipts)=="table" and l or nil
end
local function learningSource() return SAO.Study and SAO.Study.sources end
local function exposure(id,sequence)
    local study=SAO.Study
    local row=study and study.sourceExposure and study.sourceExposure(id,sequence)
    return type(row)=="table" and row.actorId==id and finite(row.atHours) and row.atHours<=SAO.History.countyHours()
        and row.status=="completed" and row or nil
end
local function validAssessment(id,row,at)
    local source=learningSource()
    if type(row)~="table" or row.actorId~=id or not finite(row.sequence) or row.sequence%1~=0 or row.sequence<1
        or row.sequence>(record(id).studyAssessmentSequence or 0)
        or row.id~="assessment/"..id.."/"..row.sequence or not finite(row.atHours) or row.atHours>at
        or not finite(row.startedAt) or row.startedAt>row.atHours or not finite(row.beganAt) or row.beganAt>row.startedAt
        or not source or not source.matches(row.sourceId,row.revision,row.textHash,row.pages)
        or source.relevance(row.sourceId).status~="fictional-edition-available"
        or type(row.task)~="table" or type(row.response)~="table" or not finite(row.exposureSequence)
        or row.exposureSequence%1~=0 or type(row.itemId)~="string" or type(row.itemType)~="string"
        or row.exposureWorkId==nil or row.owner~="SAO.Study" or row.token~="learning:response-assessed"
        or row.responseActorId~=id or row.nativeOwner~="SAOStudyResponseAction/ISBaseTimedAction"
        or row.nativeStarted~=true or row.nativeCompleted~=true or not finite(row.progress) or row.progress<=0
        or row.status~="completed" or type(row.policy)~="table" or row.policy.id~="sao-reading-retention/1"
        or not finite(row.policy.halfLifeHours) or row.policy.halfLifeHours<12 or row.policy.halfLifeHours>720
        or not finite(row.policy.threshold) or row.policy.threshold~=.35
        or not finite(row.lastUsedAt) or row.lastUsedAt<row.atHours or row.lastUsedAt>at
        or not finite(row.usageCount) or row.usageCount<0 or row.usageCount%1~=0 or row.usageCount>64
        then return nil end
    local grade=source.grade(row.sourceId,row.task,row.response)
    if grade.status~=row.verdict then return nil end
    return grade
end
local function retention(row,at)
    local age=math.max(0,at-row.lastUsedAt)
    local halfLife=row.policy.halfLifeHours*(1+math.min(row.usageCount,8)*.1)
    return math.exp(-math.log(2)*age/halfLife)
end
function K.learningCondition(id,body)
    if not record(id) then return nil end
    local out={actorId=id,atHours=SAO.History.countyHours(),status="body-unavailable",ageCurve="not-established"}
    local ok,age=pcall(function() return SAO.History.ageOf(id) end)
    if ok and finite(age) and age>=0 and age<=130 then out.age=age end
    local okTraits,traits=pcall(function() return SAO.Disposition.traits(id) end)
    if okTraits and type(traits)=="table" and finite(traits.discipline) then out.discipline=traits.discipline end
    if body and SAO.Needs and SAO.Needs.ownsRecoveryBody(id,body) then
        local okRead,needs=pcall(SAO.Needs.read,body)
        local okTemper,temper=pcall(SAO.Needs.temper,body)
        local okRange,painMaximum,drunkMaximum=pcall(function()
            return CharacterStat.PAIN:getMaximumValue(),CharacterStat.INTOXICATION:getMaximumValue()
        end)
        if okRead and type(needs)=="table" and finite(needs.fatigue) and needs.fatigue>=0 and needs.fatigue<=1
            and okRange and finite(painMaximum) and painMaximum>0 and finite(drunkMaximum) and drunkMaximum>0
            and okTemper and type(temper)=="table" and finite(temper.pain) and temper.pain>=0 and temper.pain<=painMaximum
            and finite(temper.drunk) and temper.drunk>=0 and temper.drunk<=drunkMaximum and out.discipline then
            out.fatigue,out.pain,out.drunk=needs.fatigue,temper.pain/painMaximum,temper.drunk/drunkMaximum
            out.healthScale="native-CharacterStat-maximum"
            out.status="acquired-current-body"
            out.bodyToken=body:getModData().SAOExternalToken
        end
    end
    return out
end
local function retrievalCondition(id,row)
    local body=SAO.Body and SAO.Body.get(id)
    local current=K.learningCondition(id,body)
    local formation=row.maintenanceCondition or row.policy.formationCondition
    local ageChanged=current and formation and current.age~=nil and formation.age~=nil and current.age~=formation.age
    local multiplier=1
    if current and current.status=="acquired-current-body" then
        -- Temporary body state changes recall availability rather than
        -- rewriting elapsed memory age or the person's acquired chronology.
        multiplier=math.max(.1,1-.5*current.fatigue-.3*current.pain-.3*current.drunk)
    end
    return multiplier,ageChanged,current
end

function K.assessmentInterest(id,topic)
    local person=record(id)
    local s=person and person.proceduralPlanning
    local interest=.2
    for _,identity in ipairs(s and s.order or {}) do
        local p=s.purposes[identity]
        if p and p.status~="completed" and p.status~="abandoned" then
            if topic=="civilian" and (p.domain=="social" or p.domain=="shelter" or p.leisure)
                or topic=="engineering" and (p.domain=="construction" or p.materialWork or p.shelterConstruction or p.generatorPower)
                or topic=="military" and (p.domain=="conflict" or p.domain=="resources" or p.resourceCategory) then interest=.85 end
        end
    end
    return interest
end
function K.assessmentPolicy(id,sourceId)
    local source=learningSource();local d=source and source.source(sourceId)
    if not d then return nil end
    -- Age means age of this remembered response. This declared model makes
    -- current purpose and actual recorded uses influence retention, not skill.
    local interest=K.assessmentInterest(id,d.topic)
    local condition=K.learningCondition(id,SAO.Body and SAO.Body.get(id))
    local discipline=condition and condition.discipline or .5
    return {id="sao-reading-retention/1",formationCondition=condition,halfLifeHours=(24+96*interest)*(.75+.5*discipline),threshold=.35,interestAtAssessment=interest,
        meaning="modeled bounded response retention; not observed general mastery"}
end
function K.consumeAssessment(id,sequence)
    local study=SAO.Study
    local row=study and study.assessmentOutcome and study.assessmentOutcome(id,sequence)
    local at=SAO.History.countyHours()
    if not row or row.sequence~=sequence or not validAssessment(id,row,at) then return false,"assessment-owner-unavailable" end
    local e=exposure(id,row.exposureSequence)
    if not e or e.workId~=row.exposureWorkId or e.itemId~=row.itemId or e.itemType~=row.itemType
        or e.sourceId~=row.sourceId or e.revision~=row.revision or e.textHash~=row.textHash
        or e.atHours>row.beganAt then return false,"exact-exposure-unavailable" end
    local l=learningRows(id,true)
    if not l then return false,"learning-store-unavailable" end
    if sequence<=l.readThrough then
        for _,held in ipairs(l.rows) do if held.id==row.id then return true,"already-consumed" end end
        return false,"retired-assessment"
    end
    if #l.rows>=LEARNING_LIMIT then table.remove(l.rows,1) end
    l.rows[#l.rows+1]=copy(row);l.sequence=l.sequence+1;l.readThrough=sequence
    return true,"consumed"
end
function K.assessedRelations(id)
    local l=learningRows(id,false);local at=SAO.History.countyHours()
    local latest,order={},{}
    for _,row in ipairs(l and l.rows or {}) do
        local grade=validAssessment(id,row,at)
        if grade then
            if latest[row.sourceId]==nil then order[#order+1]=row.sourceId end
            latest[row.sourceId]={row=row,grade=grade}
        end
    end
    local out={}
    for _,sourceId in ipairs(order) do
        local held=latest[sourceId];local row,grade=held.row,held.grade
        local recallFactor=retrievalCondition(id,row)
        local strength=retention(row,at)*recallFactor
        if grade.status=="passed" and strength>=row.policy.threshold then
            for index,edge in ipairs(grade.relations) do
                local e=copy(edge)
                e.id=row.id..":"..index;e.actorId=id;e.sourceId=sourceId;e.sourceRevision=row.revision
                e.textHash=row.textHash;e.exposureWorkId=row.exposureWorkId;e.exposureSequence=row.exposureSequence
                e.assessmentId=row.id;e.acquiredAt=row.atHours;e.basis="assessed-reading-association"
                e.modal=true;e.affirmed=true;e.retention="assessed-modeled";e.strength=strength
                e.assessmentMeaning=grade.meaning
                out[#out+1]=e
            end
        end
    end
    return out
end
function K.assessmentMemory(id,sourceId)
    local l=learningRows(id,false);local at=SAO.History.countyHours()
    local latest
    for _,row in ipairs(l and l.rows or {}) do
        if row.sourceId==sourceId and validAssessment(id,row,at) then latest=row end
    end
    if not latest then return nil end
    local recallFactor,ageChanged,condition=retrievalCondition(id,latest)
    local strength=retention(latest,at)*recallFactor
    return {actorId=id,sourceId=sourceId,assessmentId=latest.id,verdict=latest.verdict,
        strength=strength,ageChanged=ageChanged,currentCondition=condition,retained=latest.verdict=="passed" and strength>=latest.policy.threshold,
        response=latest.verdict=="passed" and strength>=latest.policy.threshold and copy(latest.response) or nil,
        lastUsedAt=latest.lastUsedAt,usageCount=latest.usageCount,mode=latest.task.mode,atHours=at,
        meaning="bounded explicitly assessed response; general policy unproved"}
end
function K.assessmentReceipts(id)
    local l=learningRows(id,false);local at=SAO.History.countyHours();local out={}
    for _,row in ipairs(l and l.rows or {}) do if validAssessment(id,row,at) then out[#out+1]=copy(row) end end
    return out
end
local function receivedValid(id,row,at)
    local l=type(row)=="table" and row.literature
    local source=learningSource()
    return valid(row) and row.actorId==id and row.basis=="received-literature-association"
        and type(row.id)=="string" and row.id:sub(1,#("concept/"..id.."/"))=="concept/"..id.."/"
        and type(row.sourceId)=="string" and type(row.speakerId)=="string" and row.speakerId~=id
        and finite(row.acquiredAt) and row.acquiredAt<=at and type(l)=="table" and source
        and source.hasRelation(l.sourceId,l.revision,l.textHash,row)
        and source.relevance(l.sourceId).status=="fictional-edition-available"
        and type(l.assessmentActorId)=="string" and type(l.assessmentId)=="string"
        and l.assessmentId:sub(1,#("assessment/"..l.assessmentActorId.."/"))=="assessment/"..l.assessmentActorId.."/"
        and l.assessmentVerdict=="passed" and l.recipientAssessment=="unassessed"
        and type(row.policy)=="table" and row.policy.id=="sao-reading-retention/1"
        and finite(row.policy.halfLifeHours) and row.policy.halfLifeHours>=12 and row.policy.halfLifeHours<=720
        and row.policy.threshold==.35 and finite(row.lastUsedAt) and row.lastUsedAt>=row.acquiredAt and row.lastUsedAt<=at
        and finite(row.usageCount) and row.usageCount>=0 and row.usageCount<=64 and row.usageCount%1==0
end
function K.receivedLiteratureMemory(id,edgeId)
    local s=state(id,false);local at=SAO.History.countyHours()
    for _,identity in ipairs(s and s.order or {}) do
        local row=s.relations[identity]
        if row and row.id==edgeId and receivedValid(id,row,at) then
            local factor,ageChanged,condition=retrievalCondition(id,row)
            local strength=retention(row,at)*factor
            local retained=strength>=row.policy.threshold
            return {actorId=id,edgeId=edgeId,sourceId=row.literature.sourceId,sourceRevision=row.literature.revision,
                textHash=row.literature.textHash,receivedAt=row.acquiredAt,lastUsedAt=row.lastUsedAt,usageCount=row.usageCount,
                strength=strength,retained=retained,maintenanceDue=ageChanged,currentCondition=condition,
                originalAssessment=copy(row.literature),recipientAssessment="unassessed",
                response=retained and {from=row.from,relation=row.relation,into=row.into} or nil,
                meaning="recipient recall of received conditional association; comprehension unassessed"}
        end
    end
end
function K.receivedLiteratureRelations(id)
    local s=state(id,false);local at=SAO.History.countyHours();local out={}
    for _,identity in ipairs(s and s.order or {}) do
        local row=s.relations[identity]
        if receivedValid(id,row,at) then
            local memory=K.receivedLiteratureMemory(id,row.id)
            if memory and memory.retained then
                local edge=copy(row)
                edge.receptionId=row.sourceId;edge.sourceId=row.literature.sourceId
                edge.sourceRevision=row.literature.revision;edge.textHash=row.literature.textHash
                edge.retention="recipient-modeled-reception";edge.strength=memory.strength
                edge.sourceAssessmentActorId=row.literature.assessmentActorId
                edge.sourceAssessmentId=row.literature.assessmentId;edge.recipientAssessment="unassessed"
                out[#out+1]=edge
            end
        end
    end
    return out
end

-- A current maintained inquiry is the owner of this cognitive use. Generic
-- caller-authored relation tables cannot refresh a source's remembered answer.
function K.consumeInquiryUse(id,purposeId)
    local person=record(id);local s=person and person.proceduralPlanning
    local p=s and s.purposes[purposeId]
    local inquiry=p and p.inquiry
    local at=SAO.History.countyHours()
    if not p or p.origin~="personal-expectation" or p.status~="maintained" or not inquiry or not inquiry.path
        or type(inquiry.path.roots)~="table" then return false end
    local l=learningRows(id,false)
    local conceptState=state(id,false)
    if not conceptState then return false end
    local receipt=purposeId.."|"..inquiry.path.id
    for _,ledger in ipairs({l and l.useReceipts or {},conceptState.receivedUseReceipts or {}}) do
        for _,old in ipairs(ledger) do if old==receipt then return true end end
    end
    local active={} for _,edge in ipairs(K.assessedRelations(id)) do active[edge.assessmentId]=true end
    local heard={} for _,edge in ipairs(K.receivedLiteratureRelations(id)) do heard[edge.id]=true end
    local used,touched=false,{}
    for _,edge in ipairs(inquiry.path.roots) do
        if edge.actorId==id and active[edge.assessmentId] and not touched[edge.assessmentId] then
            touched[edge.assessmentId]=true
            for _,row in ipairs(l.rows) do if row.id==edge.assessmentId and row.lastUsedAt<=at then
                row.lastUsedAt=at;row.usageCount=math.min(64,row.usageCount+1);used=true
            end end
        end
    end
    for _,edge in ipairs(inquiry.path.roots) do
        if edge.actorId==id and heard[edge.id] and not touched[edge.id] then
            local row=conceptState.relations[key(edge)]
            if row and row.id==edge.id then
                touched[edge.id]=true;row.lastUsedAt=at;row.usageCount=math.min(64,row.usageCount+1)
                row.maintenanceCondition=K.learningCondition(id,SAO.Body and SAO.Body.get(id))
                row.maintenanceReceipts=row.maintenanceReceipts or {}
                if #row.maintenanceReceipts>=8 then table.remove(row.maintenanceReceipts,1) end
                row.maintenanceReceipts[#row.maintenanceReceipts+1]={actorId=id,owner="SAO.ProceduralPlanning",purposeId=purposeId,
                    pathId=inquiry.path.id,atHours=at,condition=copy(row.maintenanceCondition),meaning="actual-source-dependent-plan-use"}
                used=true
            end
        end
    end
    if used then
        local receipts
        if l then receipts=l.useReceipts else conceptState.receivedUseReceipts=conceptState.receivedUseReceipts or {};receipts=conceptState.receivedUseReceipts end
        if #receipts>=LEARNING_LIMIT then table.remove(receipts,1) end
        receipts[#receipts+1]=receipt
    end
    return used
end

local function available(id,contextId,background)
    local edges,denied,recalledContrary={},{},{}
    local sourceOmitted,sourceTruncated=0,false
    local s=state(id,false)
    local at=SAO.History and SAO.History.countyHours()
    local function personal(edge)
        return valid(edge) and edge.actorId==id and type(edge.id)=="string" and #edge.id<=160 and type(edge.sourceId)=="string"
            and (edge.basis=="observed-relation" or edge.basis=="personal-association"
                or edge.basis=="taught-association")
            and finite(edge.acquiredAt) and finite(at) and edge.acquiredAt<=at
    end
    for index,identity in ipairs(s and s.order or {}) do
        if index>MAX_RELATIONS then break end
        local edge=s.relations[identity]
        if personal(edge) and (edge.contextId==nil or edge.contextId==contextId) and edge.affirmed==false then
            denied[edge.from.."|"..edge.into]=edge
        end
    end
    for index,seed in ipairs(PRIORS) do
        edges[#edges+1]={id="ordinary-life-prior/"..index,actorId=id,from=seed[1],relation=seed[2],into=seed[3],
            basis="declared-ordinary-life-prior",modal=true,affirmed=true,
            origin="bounded-foundation-v1; not curriculum mastery"}
    end
    for index,identity in ipairs(s and s.order or {}) do
        if index>MAX_RELATIONS then break end
        local edge=s.relations[identity]
        if personal(edge) and edge.affirmed and (edge.contextId==nil or edge.contextId==contextId) then edges[#edges+1]=copy(edge) end
    end
    for _,edge in ipairs(K.assessedRelations(id)) do edges[#edges+1]=copy(edge) end
    for _,edge in ipairs(K.receivedLiteratureRelations(id)) do edges[#edges+1]=copy(edge) end
    local education=SAO.Education
    if education and type(education.backgroundRelations)=="function" then
        local ok,roots=pcall(education.backgroundRelations,id)
        for index,edge in ipairs(ok and type(roots)=="table" and roots or {}) do
            if index>32 then break end
            local authored=(edge.basis=="authored-work-training-exposure"
                or edge.basis=="authored-community-literary-exposure")
                and edge.assent=="not-established"
                and (edge.contentRole=="descriptive-possibility" or edge.contentRole=="reported-norm")
            if edge.actorId==id and valid(edge) and (edge.basis=="generated-schooling-exposure" or authored)
                and edge.modal==true and edge.retention=="unassessed" then edges[#edges+1]=copy(edge) end
        end
    end
    local memory=SAO.PersonalMemory
    if memory and type(memory.relations)=="function" then
        local ok,roots,rootStatus,rootOmitted=pcall(memory.relations,id)
        if ok and rootStatus=="truncated" then
            sourceTruncated=true
            if finite(rootOmitted) and rootOmitted>=0 and rootOmitted%1==0 then sourceOmitted=rootOmitted end
        end
        for index,edge in ipairs(ok and type(roots)=="table" and roots or {}) do
            if index>64 then break end
            if edge.actorId==id and valid(edge) and edge.basis=="autobiographical-association"
                and edge.modal==true and edge.retention=="modeled" and edge.mastery=="unassessed"
                and edge.assent=="not-established" and finite(edge.confidence) and edge.confidence>0
                and finite(edge.acquiredAt) and finite(at) and edge.acquiredAt<=at then
                if edge.affirmed==false then
                    recalledContrary[#recalledContrary+1]=copy(edge)
                else edges[#edges+1]=copy(edge) end
            end
        end
    end
    for _,edge in ipairs(background or {}) do edges[#edges+1]=copy(edge) end
    return edges,denied,(s and ((s.omitted or 0)+math.max(0,#s.order-MAX_RELATIONS)) or 0)+sourceOmitted,recalledContrary,sourceTruncated
end
-- Only a privately acquired general association is offered. Shared ordinary
-- priors need no retransmission; exact local observations retain Perception.
function K.teachingOffer(fromId,toId)
    local from,to=record(fromId),record(toId)
    if fromId==toId or not from or from.dead or not to or to.dead then return nil end
    local s=state(fromId,false)
    local spoken={}
    local at=SAO.History.countyHours()
    for index,receipt in ipairs(s and type(s.spokenAssociations)=="table" and s.spokenAssociations or {}) do
        if index>MAX_RELATIONS then break end
        if type(receipt)=="table" and receipt.to==toId and type(receipt.edgeId)=="string"
            and finite(receipt.at) and receipt.at<=at then spoken[receipt.edgeId]=true end
    end
    local ours=available(fromId,nil)
    for _,edge in ipairs(ours) do
        if edge.contextId==nil and edge.affirmed and edge.modal
            and (edge.basis=="personal-association" or edge.basis=="taught-association" or edge.basis=="assessed-reading-association" or edge.basis=="received-literature-association")
            and not spoken[edge.id] then return copy(edge) end
    end
    return nil
end
-- Communication supplies a receipt only while its exact admitted transport
-- consumes this message. Generic send/deliver cannot mint an association.
function K.receiveAssociation(id,message)
    local communication=SAO.Communication
    local receipt=communication and communication.conceptReception
        and communication.conceptReception(message)
    if type(receipt)~="table" or receipt.to~=id or receipt.from==id
        or not finite(receipt.at) or receipt.at>SAO.History.countyHours()
        or not valid(receipt.edge) or receipt.edge.contextId~=nil
        or receipt.edge.affirmed==false then return false,"reception-unavailable" end
    local theirs,denied=available(id,nil)
    if denied[receipt.edge.from.."|"..receipt.edge.into] then return false,"own-contrary-evidence" end
    for _,edge in ipairs(theirs) do
        if key(edge)==key(receipt.edge) then return false,"already-known" end
    end
    local edge=receipt.edge
    if edge.basis=="assessed-reading-association" or edge.basis=="received-literature-association" then
        local source=learningSource()
        local origin=edge.literature or {sourceId=edge.sourceId,revision=edge.sourceRevision,textHash=edge.textHash,
            assessmentActorId=edge.actorId,assessmentId=edge.assessmentId,assessmentVerdict="passed"}
        if not source or not source.hasRelation(origin.sourceId,origin.revision,origin.textHash,edge)
            or type(origin.assessmentActorId)~="string" or type(origin.assessmentId)~="string"
            or origin.assessmentVerdict~="passed" then return false,"received-literature-source-unavailable" end
        origin=copy(origin);origin.recipientAssessment="unassessed"
        return retain(id,edge,{basis="received-literature-association",sourceId=receipt.id,
            speakerId=receipt.from,parentId=edge.id,channel=receipt.channel,acquiredAt=receipt.at,
            literature=origin,policy=K.assessmentPolicy(id,origin.sourceId)})
    end
    return retain(id,receipt.edge,{basis="taught-association",
        sourceId=receipt.id,speakerId=receipt.from,parentId=receipt.edge.id,
        channel=receipt.channel,acquiredAt=receipt.at})
end
-- The teller remembers an actual admitted utterance, not the listener's
-- private knowledge or response. It can then offer another acquired edge.
function K.rememberSpokenAssociation(id,message)
    local receipt=SAO.Communication and SAO.Communication.conceptReception(message)
    if not receipt or receipt.from~=id or not finite(receipt.at)
        or receipt.at>SAO.History.countyHours() then return false end
    local s=state(id,true)
    if not s then return false end
    local priorRows=type(s.spokenAssociations)=="table" and s.spokenAssociations or {}
    local retained,seen,duplicate={},{},false
    for index=1,math.min(#priorRows,MAX_RELATIONS) do
        local prior=priorRows[index]
        if type(prior)=="table" and type(prior.to)=="string" and type(prior.edgeId)=="string"
            and finite(prior.at) and prior.at<=SAO.History.countyHours() then
            local identity=prior.to.."|"..prior.edgeId
            if not seen[identity] then
                seen[identity]=true;retained[#retained+1]=copy(prior)
                if prior.to==receipt.to and prior.edgeId==receipt.edge.id then duplicate=true end
            end
        end
    end
    s.spokenAssociations=retained
    if duplicate then return true end
    if #s.spokenAssociations>=MAX_RELATIONS then table.remove(s.spokenAssociations,1) end
    s.spokenAssociations[#s.spokenAssociations+1]={to=receipt.to,edgeId=receipt.edge.id,
        at=receipt.at,sourceId=receipt.id,channel=receipt.channel}
    return true
end
local function infer(id,from,sought,contextId,background)
    local rec=record(id)
    if not rec or rec.dead or not word(from) or not word(sought) or contextId~=nil and not word(contextId) then return nil end
    local edges,denied,omitted,recalledContrary,sourceTruncated=available(id,contextId,background)
    local out={actorId=id,from=from,into=sought,contextId=contextId,status="unresolved",paths={},
        contradictions={},omittedRelations=omitted,limitReached=sourceTruncated,omittedDerivations=0,
        missing={"Exact location, current presence and permission require personal observation."}}
    local pending={{at=from,edges={},seen={[from]=true}}}
    local cursor,work,noted=1,0,{}
    while cursor<=#pending do
        local branch=pending[cursor];cursor=cursor+1
        -- A prior-life counterexample is evidence of uncertainty. It cannot
        -- establish absence or cancel a fresh personally observed means.
        for _,edge in ipairs(recalledContrary or {}) do
            if edge.from==branch.at and not noted[edge.id] then
                noted[edge.id]=true
                out.contradictions[#out.contradictions+1]={id=edge.id,from=edge.from,into=edge.into,
                    basis=edge.basis,episodeId=edge.episodeId,sourceId=edge.sourceId,
                    confidence=edge.confidence,status="recalled-counterexample",modal=true}
            end
        end
        for _,edge in ipairs(edges) do
            if edge.from==branch.at and not branch.seen[edge.into] then
                work=work+1
                if work>MAX_WORK then out.limitReached=true;out.omittedDerivations=out.omittedDerivations+1;break end
                local objection=denied[edge.from.."|"..edge.into]
                if objection then
                    out.contradictions[#out.contradictions+1]={id=objection.id,from=edge.from,into=edge.into,
                        contextId=objection.contextId,basis=objection.basis,speakerId=objection.speakerId}
                else
                    local path=copy(branch.edges);path[#path+1]=copy(edge)
                    if edge.into==sought then
                        local ids={} for _,part in ipairs(path) do ids[#ids+1]=part.id end
                        out.paths[#out.paths+1]={id="inference:"..table.concat(ids,">"),relation="compose",from=from,into=sought,
                            depth=#path,status="expectation",modal=true,parentIds=ids,evidenceIds=copy(ids),roots=path,
                            missing=copy(out.missing),basis="personal-relational-inference"}
                        if #out.paths>=8 then out.limitReached=true;out.omittedDerivations=out.omittedDerivations+1;break end
                    elseif #path<MAX_DEPTH then
                        local seen=copy(branch.seen);seen[edge.into]=true
                        pending[#pending+1]={at=edge.into,edges=path,seen=seen}
                    else out.limitReached=true;out.omittedDerivations=out.omittedDerivations+1 end
                end
            end
        end
        if work>MAX_WORK or #out.paths>=8 then break end
    end
    if #out.paths>0 then out.status="expectation"
    elseif #out.contradictions>0 then out.status="challenged" end
    return out
end
-- Native recognition is a usable personal background premise, not a learned
-- outcome or a grant of success. Unknown recipes/education/culture labels do
-- not supply content here; the existing education source owner retains those.
local function foodRoots(id,view)
    local roots={}
    if not view or view.actorId~=id or view.atHours~=SAO.History.countyHours() then return roots end
    for _,row in ipairs(view.foods) do
        if row.recognizedPoison then
            roots[#roots+1]={id="native-food/"..id.."/"..row.itemId.."/"..row.basis,actorId=id,
                from="carried-food:"..row.itemId,relation="may-cause",into="bodily-harm",contextId="carried-food",
                basis="native-personal-recognition",sourceId=row.basis,sourceOwner=view.sourceOwner,
                acquisitionTime=view.acquisitionTime,observedAt=view.atHours,itemType=row.itemType,
                affirmed=true,modal=true}
        end
    end
    return roots
end
function K.infer(id,from,sought,contextId)
    local background
    if contextId=="carried-food" and SAO.Perception and SAO.Perception.personalFoodKnowledge then
        local body=SAO.Body and SAO.Body.get(id)
        background=foodRoots(id,SAO.Perception.personalFoodKnowledge(id,body))
    end
    return infer(id,from,sought,contextId,background)
end
function K.chooseCarriedFood(id,body)
    local view=SAO.Perception and SAO.Perception.personalFoodKnowledge
        and SAO.Perception.personalFoodKnowledge(id,body)
    if not view or #view.foods==0 or not SAO.Cognition or not SAO.Cognition.interpretPlans then return nil end
    local roots,candidates,byId=foodRoots(id,view),{},{}
    for _,row in ipairs(view.foods) do
        local identity="eat:"..row.itemId
        local inference=infer(id,"carried-food:"..row.itemId,"bodily-harm","carried-food",roots)
        local path=inference and inference.paths[1]
        local appraisal={actorId=id,danger={ordinal=path and 1 or 0,
            status=path and "personally-recognized-poison" or "poison-not-established",basis=path},
            travel={outwardCost=0,returnCost=0},requestValue=0,social={requests={},responsibilities={}}}
        candidates[#candidates+1]={id=identity,utility=row.relief,evidence=1,continuity=0,
            novelty=0,informationGain=0,blockers=0,appraisal=appraisal}
        byId[identity]=row
    end
    -- Rank all admitted private candidates before the shared comparison bound.
    -- Otherwise an early run of harmful foods could hide a later usable meal.
    local frame={atHours=view.atHours}
    for _,candidate in ipairs(candidates) do
        candidate.rank=SAO.Cognition.scorePlan(id,candidate,frame)
        if not finite(candidate.rank) then return nil end
    end
    table.sort(candidates,function(a,b)
        return a.rank>b.rank or a.rank==b.rank and a.id<b.id
    end)
    local omitted=math.max(0,#candidates-15)
    while #candidates>15 do table.remove(candidates) end
    candidates[#candidates+1]={id="defer-food",utility=0,evidence=1,continuity=0,
        novelty=0,informationGain=0,blockers=0}
    local reasoning=SAO.Cognition.interpretPlans(id,candidates,{atHours=view.atHours})
    local selected=reasoning and byId[reasoning.selected]
    if not reasoning then return nil end
    reasoning.omittedFoods=view.omitted
    reasoning.omittedAlternatives=omitted
    reasoning.uncertainty="Unrecognized poison remains unknown; eating is an interruptible native attempt."
    return selected and copy(selected) or nil,reasoning
end
function K.explain(path)
    if not path or type(path.roots)~="table" then return "I have not established a connection." end
    local parts={}
    for _,edge in ipairs(path.roots) do
        parts[#parts+1]=edge.from:gsub("%-"," ").." "..edge.relation:gsub("%-"," ").." "..edge.into:gsub("%-"," ")
    end
    return table.concat(parts,"; ")..". I still need to look and check whether it is available here."
end
return K
