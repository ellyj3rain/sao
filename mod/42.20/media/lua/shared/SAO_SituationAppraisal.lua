-- Shared person-private questions about changed circumstances. Acquired reports
-- and anonymous audible pulses remain different evidence. Appraisal supplies
-- a reason to look, never a world diagnosis, competence, or actuator authority.
SAO=SAO or {}
SAO.SituationAppraisal=SAO.SituationAppraisal or {}
local S=SAO.SituationAppraisal
local planner
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1000000000 end
local function unit(v) return finite(v) and v>=0 and v<=1 end
local function array(v,maximum)
    if type(v)~="table" or #v>maximum then return false end
    local count=0
    for k in pairs(v)do
        if not finite(k) or k%1~=0 or k<1 or k>#v then return false end
        count=count+1
    end
    return count==#v
end
local function copy(v,depth,seen)
    if type(v)~="table" then return v end
    depth,seen=depth or 0,seen or {}
    if depth>12 or seen[v] then return nil end
    seen[v]=true
    local out={} for k,x in pairs(v) do out[k]=copy(x,depth+1,seen) end
    seen[v]=nil;return out
end
local function owned(id,body)
    local rec=SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or rec.id~=id or rec.dead or not body or not SAO.Body then return nil end
    -- A Week One proxy is the same SAO person with a source-owned body. The
    -- exact live crosswalk is a read-only custody proof, not body transfer.
    if rec.weekOne and rec.weekOne.source=="BanditsWeekOne"
        and rec.weekOne.status=="external" and not rec.weekOne.pending
        and SAO.Claims and SAO.Claims.heldBy(rec)=="BanditsWeekOne"
        and SAO.WeekOneContinuity and SAO.WeekOneContinuity.sourceBodyFor then
        local ok,sourceBody=pcall(SAO.WeekOneContinuity.sourceBodyFor,id)
        if ok and sourceBody==body then return rec end
    end
    local ok,data=pcall(function()return body:getModData()end)
    if not ok or type(data)~="table" or data.SAOPersonId~=id or data.SAOExternalToken~=rec.bodyOwnerToken then return nil end
    if rec.bodyOwner==nil then
        if SAO.Body.active[id]~=body or SAO.Body.foreign[id]~=nil or data.SAOExternalOwner~=nil or data.ZAOOwned==true then return nil end
    elseif rec.bodyOwner=="ZAO" then
        if SAO.Body.foreign[id]~=body or SAO.Body.active[id]~=nil or data.SAOExternalOwner~="ZAO"
            or data.ZAOOwned~=true or not ZAO or not ZAO.Controller or ZAO.Controller.controlled[id]~=body then return nil end
    else return nil end
    return rec
end
local function ledger(rec,now)
    local s=rec.situationAppraisal
    if s==nil then return nil,true end
    if type(s)~="table" or s.schema~=1 or s.actorId~=rec.id or type(s.questions)~="table"
        or not array(s.order,8) then return nil,false end
    local keys={}
    for _,key in ipairs(s.order) do
        local q=s.questions[key]
        if type(key)~="string" or type(q)~="table" or q.actorId~=rec.id or q.key~=key
            or keys[key] or not finite(q.atHours) or q.atHours<0 or q.atHours>now or not array(q.revisions,16) then return nil,false end
        keys[key]=true
        for _,r in ipairs(q.revisions) do
            if type(r)~="table" or r.actorId~=rec.id or not finite(r.atHours) or r.atHours<0 or r.atHours>q.atHours
                or not array(r.evidence,32) or not array(r.observations,32) then return nil,false end
            for _,e in ipairs(r.evidence) do
                if type(e)~="table" or type(e.id)~="string" or type(e.sourceId)~="string"
                    or not finite(e.receivedAtHours) or e.receivedAtHours<0 or e.receivedAtHours>r.atHours then return nil,false end
            end
            for _,o in ipairs(r.observations) do
                if type(o)~="table" or o.actorId~=rec.id then return nil,false end
            end
        end
    end
    for key in pairs(s.questions)do if not keys[key] then return nil,false end end
    return s,true
end
function S.query(id,body,tick)
    local rec=owned(id,body)
    local ok,now=pcall(function()return SAO.History.countyHours()end)
    local function unavailable(reason)return {schema="sao-situation-appraisal/1",actorId=id,status="unavailable",reason=reason,questions={}}end
    if not rec or not ok or not finite(now) or now<0 or not finite(tick) or tick<0 then return unavailable("person-or-clock") end
    if SAO.History.ticks then
        local tickOk,current=pcall(SAO.History.ticks)
        if not tickOk or current~=tick then return unavailable("current-observation-clock") end
    end
    local held,valid=ledger(rec,now)
    if not valid then return unavailable("retained-question-binding") end
    local good,values=pcall(function()return SAO.Disposition.traitEvidence(id)end)
    local neuro,clarity,volatility=pcall(function()return SAO.Neuro.clarityOf(rec),SAO.Neuro.affectiveVolatility(rec)end)
    local fearOk,fear=pcall(function()return SAO.Disposition.fear(id)end)
    if not good or not neuro or not fearOk or not unit(clarity) or not unit(volatility) or not unit(fear)
        or type(values)~="table" then return unavailable("personal-appraisal-owner") end
    for _,axis in ipairs({"initiative","nerve","selfPreservation","discipline"}) do
        if type(values[axis])~="table" or not unit(values[axis].effective) then return unavailable("personal-values") end
    end
    local temper=SAO.Needs and SAO.Needs.temper and SAO.Needs.temper(body) or nil
    local stress=type(temper)=="table" and unit(temper.stress) and temper.stress or 0
    local awarenessOk,awareness=pcall(function()return SAO.PersonalAwareness.query(id)end)
    if not awarenessOk or not awareness or awareness.actorId~=id or awareness.status=="unavailable" then return unavailable("awareness-custody") end
    local contextOk,context=pcall(function()return SAO.Perception.conceptContext(id,tick,body)end)
    local cuesOk,cues=pcall(function()return SAO.Perception.soundCues(id,body,tick)end)
    if not contextOk or type(context)~="table" or not cuesOk or type(cues)~="table" then return unavailable("private-observation-owner") end
    local out={schema="sao-situation-appraisal/1",actorId=id,atHours=now,status="unresolved",questions={},clarity=clarity,
        psychology={values=copy(values),fear=fear,volatility=volatility,temper=copy(temper),
            temperStatus=temper and "native" or "unavailable"},context=copy(context),
        retainedQuestionCount=held and #held.order or 0}
    local knowledgeOk,harm,movement=pcall(function()
        return SAO.ConceptKnowledge.infer(id,"assault","bodily-harm",context.buildingId),
            SAO.ConceptKnowledge.infer(id,"obstruction","blocks-movement",context.buildingId)
    end)
    if not knowledgeOk or type(harm)~="table" or type(movement)~="table" then return unavailable("personal-concept-owner") end
    out.knowledge={conditionalHarm=copy(harm),conditionalObstruction=copy(movement)}
    local groups={}
    for _,e in ipairs(awareness.evidence or {}) do
        if #out.questions<8 and type(e.id)=="string" and type(e.sourceId)=="string" and finite(e.receivedAtHours)
            and e.receivedAtHours<=now and (e.kind=="outbreak" or e.kind=="turned") then
            local q=groups[e.kind]
            if not q then q={key="reported:"..e.kind,subject=e.kind,evidence={},uncertainty=1,
                interpretation=awareness.propositions and awareness.propositions[e.kind] or "unknown"}
                groups[e.kind]=q;out.questions[#out.questions+1]=q end
            if #q.evidence<32 then q.evidence[#q.evidence+1]=copy(e)
            else q.omittedEvidence=(q.omittedEvidence or 0)+1 end
        end
    end
    if #cues>0 then
        local q={key="unclassified-sound",subject="unclassified-sound",interpretation="unknown-cause",
            uncertainty=1,evidence={}}
        for i,cue in ipairs(cues) do
            if i>16 then break end
            if cue.source=="heard" and finite(cue.heardAt) and cue.heardAt<=tick then
                q.evidence[#q.evidence+1]={id=cue.cueId,sourceId="native-audible-pulse:"..cue.cueId,
                    basis="heard",heardAt=cue.heardAt,receivedAtHours=now,x=cue.x,y=cue.y,
                    certainty="unclassified"}
            end
        end
        if #q.evidence>0 then out.questions[#out.questions+1]=q end
    end
    -- A selected, unresolved inquiry remains this person's question after
    -- the native pulse expires. Its saved hearing is historical evidence;
    -- the planner must still find a currently visible means before moving.
    local retained=held and held.questions["unclassified-sound"]
    if retained and #out.questions<8 then
        local present=false
        for _,q in ipairs(out.questions) do
            if q.key=="unclassified-sound" then present=true;break end
        end
        if not present then
            local last=retained.revisions[#retained.revisions]
            local evidence={}
            if last and last.localCauseConfirmed==false then
                for _,e in ipairs(last.evidence) do
                    if #evidence>=16 then break end
                    if type(e.id)=="string" and #e.id<=56
                        and e.sourceId=="native-audible-pulse:"..e.id
                        and e.basis=="heard" and finite(e.heardAt)
                        and e.heardAt>=0 and e.heardAt<=tick
                        and finite(e.x) and finite(e.y) then
                        evidence[#evidence+1]=copy(e)
                    end
                end
            end
            if #evidence>0 then
                out.questions[#out.questions+1]={key="unclassified-sound",
                    subject="unclassified-sound",interpretation="unknown-cause",
                    uncertainty=1,evidence=evidence,retained=true,
                    lastReviewedAtHours=last.atHours}
            end
        end
    end
    for _,q in ipairs(out.questions) do
        -- These are explicit, uncalibrated preference coefficients. They
        -- compare personal information value with continuing an activity;
        -- neither a reported event nor fear certifies a nearby danger.
        local challenge=q.interpretation=="challenged" and 1 or q.interpretation=="denied" and .35 or 1
        local anticipatedHarm=type(harm.paths)=="table" and #harm.paths>0
        q.utility=clarity*challenge*(values.initiative.effective*.45+values.selfPreservation.effective*(anticipatedHarm and .25 or .125)
            +values.nerve.effective*.1+fear*.1+volatility*.05-values.discipline.effective*.15)*(1-stress*.25)
        q.actorId,q.atHours=id,now
        q.anticipated={{kind="learning",qualifier="possible",description="Checking a personally observed lead may reduce uncertainty."},
            {kind="exposure",qualifier="unknown",description="The cause and consequences beyond that lead remain unobserved."}}
        if anticipatedHarm then q.anticipated[#q.anticipated+1]={kind="harm",qualifier="conditional",
            description="If this involves assault, I associate assault with possible bodily harm; I have not established that explanation.",
            paths=copy(harm.paths)} end
        q.conceptualEvidence=copy(out.knowledge)
        local prior=held and held.questions[q.key]
        q.revisions=prior and copy(prior.revisions) or {}
        q.reason=q.subject=="unclassified-sound" and "I heard something whose cause I cannot identify. I can look from a known approach."
            or "I have an attributed account about "..q.subject.."; its present local consequences are unconfirmed. I can check known surroundings."
    end
    table.sort(out.questions,function(a,b)return a.utility==b.utility and a.key<b.key or a.utility>b.utility end)
    if #out.questions>0 then out.status=clarity>0 and "questions" or "inaccessible" end
    return out
end
-- Only the planner keeps this closure. It reacquires owned evidence rather
-- than accepting a caller's proposed facts. A route result is a revision of
-- the attempt, not proof that the question's explanation is true.
function S.bindPlanner(owner)
    if planner or owner~=SAO.ProceduralPlanning then return nil end
    planner=owner
    return function(id,body,tick,key,outcome)
        if planner~=SAO.ProceduralPlanning then return false end
        local view=S.query(id,body,tick)
        if view.status=="unavailable" then return false end
        local question
        for _,q in ipairs(view.questions) do if q.key==key then question=q;break end end
        local rec=owned(id,body)
        local s=rec.situationAppraisal
        -- A pulse may have ended while this genuine attempt was underway.
        -- Its retained attribution survives, but cannot become fresh hearing.
        if not question then
            local prior=s and s.questions[key]
            local revision=prior and prior.revisions[#prior.revisions]
            if not revision or outcome~="observed-after-route" then return false end
            question={interpretation=revision.interpretation,evidence=copy(revision.evidence)}
        end
        if not s then s={schema=1,actorId=id,questions={},order={}};rec.situationAppraisal=s end
        local q=s.questions[key]
        if not q then
            if #s.order>=8 then s.questions[table.remove(s.order,1)]=nil end
            q={actorId=id,key=key,revisions={}};s.questions[key]=q;s.order[#s.order+1]=key
        end
        q.atHours=view.atHours
        local observations={}
        for i,o in ipairs(view.context.observations or {}) do if i>32 then break end;observations[#observations+1]=copy(o) end
        q.revisions[#q.revisions+1]={actorId=id,atHours=view.atHours,interpretation=question.interpretation,
            evidence=copy(question.evidence),observations=observations,
            outcome=outcome,localCauseConfirmed=false}
        while #q.revisions>16 do table.remove(q.revisions,1) end
        return true
    end
end
return S
