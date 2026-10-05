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
        parentId=provenance.parentId,modal=provenance.basis~="observed-relation"}
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
            and (edge.basis=="personal-association" or edge.basis=="taught-association")
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
