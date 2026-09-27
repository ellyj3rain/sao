-- Independent computational contestants. Neither reads or judges the other.
-- This initial model is not trained awareness. Its associations describe
-- possibilities; no function grants recipes, skills, access or native effects.
SAO = SAO or {}
SAO.CognitiveModels = SAO.CognitiveModels or {}
local M = SAO.CognitiveModels
local VERSION = {ordinary="sao-ordinary/1",associative="sao-associative/1"}
local MAX_BELIEFS, MAX_HYPOTHESES, MAX_EVENTS = 32, 32, 256
local CONFIDENCE_HALF_LIFE_HOURS = 24
local ACTIONS = { "food", "water", "inspect", "continue" }
local FRAME_KEYS = { id=true, actorId=true, worldHours=true, hunger=true,
    thirst=true, fatigue=true, eatAt=true, drinkAt=true, foodAllowed=true,
    waterAllowed=true, inspectionAllowed=true, knownFood=true, knownWater=true,
    knownPlaces=true, capabilities=true, priorIntent=true }
local EVENT_KEYS = { id=true, actorId=true, observerId=true, worldHours=true,
    kind=true, category=true, sourceId=true, itemType=true, perspective=true,
    status=true, foodPresent=true, waterPresent=true, hungerDelta=true,
    thirstDelta=true, detail=true, capabilities=true }
local CAPABILITIES = { cook="manufacturing", forage="agriculture", treat="medicine" }
-- A relational grammar, not an unlock sequence. Rules state possible
-- analogies and their missing mechanisms, never that an operation exists.
local RULES = {
    { from="contain", into="retain", branch="logistics-preservation",
      missing="Retention duration, loss and spoilage are unmeasured." },
    { from="convey", into="transfer", branch="logistics-preservation",
      missing="A usable transfer interface and its losses are unknown." },
    { from="operate", into="regulate", branch="manufacturing",
      missing="A controllable input and its effect have not been demonstrated." },
    { from="retain", into="regulate", branch="manufacturing",
      missing="Whether thermal or other control preserves this property is unknown." },
    { from="regulate", into="transfer", branch="electrical-systems",
      missing="A usable energy source and conversion mechanism are unknown." },
    { from="transfer", into="separate", branch="metallurgy-materials",
      missing="Selective separation and compatible material properties are unknown." },
}

local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function unit(n) return finite(n) and n>=0 and n<=1 end
local function text(s, limit) return type(s)=="string" and #s>0 and #s<=limit end
local function clamp(n) return math.max(0, math.min(1, n)) end
local function plainKeys(value, keys)
    if type(value)~="table" then return false end
    for key in pairs(value) do if not keys[key] then return false end end
    return true
end
local function capabilities(value)
    if type(value)~="table" then return false end
    for key, enabled in pairs(value) do
        if not CAPABILITIES[key] or type(enabled)~="boolean" then return false end
    end
    return true
end
local function model(id) return id=="ordinary" or id=="associative" end
local function action(id)
    for _, candidate in ipairs(ACTIONS) do if candidate==id then return true end end
    return false
end
local function validFrame(f)
    if not plainKeys(f, FRAME_KEYS) or not text(f.id,128)
        or not text(f.actorId,128) or not finite(f.worldHours) or f.worldHours<0
        or not capabilities(f.capabilities) then return false end
    for _, key in ipairs({"hunger","thirst","fatigue","eatAt","drinkAt"}) do
        if not unit(f[key]) then return false end
    end
    for _, key in ipairs({"foodAllowed","waterAllowed","inspectionAllowed"}) do
        if type(f[key])~="boolean" then return false end
    end
    for _, key in ipairs({"knownFood","knownWater","knownPlaces"}) do
        if not finite(f[key]) or f[key]<0 or f[key]>100000 or f[key]~=math.floor(f[key]) then return false end
    end
    return f.priorIntent==nil or action(f.priorIntent)
end
local function validEvent(e)
    if not plainKeys(e, EVENT_KEYS) or not text(e.id,128)
        or not text(e.actorId,128) or not text(e.observerId,128)
        or not finite(e.worldHours) or e.worldHours<0
        or (e.kind~="inspection" and e.kind~="acquire" and e.kind~="store" and e.kind~="consume")
        or (e.category~="food" and e.category~="water" and e.category~="container")
        or (e.status~="completed" and e.status~="no-effect"
            and e.status~="interrupted" and e.status~="unavailable")
        or (e.perspective~="performed" and e.perspective~="observed") then return false end
    if e.capabilities~=nil and not capabilities(e.capabilities) then return false end
    for _, key in ipairs({"sourceId","itemType"}) do
        if e[key]~=nil and not text(e[key],160) then return false end
    end
    if e.detail~=nil and (type(e.detail)~="string" or #e.detail>512) then return false end
    for _, key in ipairs({"foodPresent","waterPresent"}) do
        if e[key]~=nil and type(e[key])~="boolean" then return false end
    end
    for _, key in ipairs({"hungerDelta","thirstDelta"}) do
        if e[key]~=nil and (not finite(e[key]) or math.abs(e[key])>1) then return false end
    end
    if e.kind=="inspection" and e.category~="container" then return false end
    if e.kind~="inspection" and (e.foodPresent~=nil or e.waterPresent~=nil) then return false end
    if e.kind~="consume" and (e.hungerDelta~=nil or e.thirstDelta~=nil) then return false end
    if e.kind=="consume" and e.category=="container" then return false end
    if e.perspective=="performed" then
        if e.actorId~=e.observerId then return false end
    elseif e.hungerDelta~=nil or e.thirstDelta~=nil
        or e.foodPresent~=nil or e.waterPresent~=nil
        or (e.kind~="acquire" and e.kind~="store") then return false end
    return true
end
local function validState(id, state)
    return model(id) and type(state)=="table" and state.modelId==id
        and state.version==VERSION[id] and type(state.beliefs)=="table"
        and type(state.beliefOrder)=="table" and type(state.hypotheses)=="table"
        and type(state.seen)=="table" and type(state.eventOrder)=="table"
        and #state.beliefOrder<=MAX_BELIEFS and #state.hypotheses<=MAX_HYPOTHESES
        and #state.eventOrder<=MAX_EVENTS
end
local function copyList(values, limit)
    local out={} for i=1,math.min(#(values or {}),limit) do out[i]=values[i] end return out
end
local function appendUnique(values, value, limit)
    for _, v in ipairs(values) do if v==value then return end end
    values[#values+1]=value
    if #values>limit then table.remove(values,1) end
end
local function posterior(b, hours)
    if not b then return 0.5 end
    hours=hours or b.lastHours or 0
    local support,against=0,0
    for _, sample in ipairs(b.samples) do
        -- Receipt facts stay intact. Only their present epistemic weight ages;
        -- reading at a later hour cannot acquire or strengthen knowledge.
        local weight=0.5^(math.max(0,hours-sample.hours)/CONFIDENCE_HALF_LIFE_HOURS)
        if sample.yes then support=support+weight else against=against+weight end
    end
    return (1+support)/(2+support+against)
end
local function status(b)
    if b.against>0 then return b.support>0 and "refined" or "falsified" end
    return b.support>0 and "supported" or "hypothesis"
end

function M.newState(modelId)
    if not model(modelId) then return nil,"unknown-model" end
    return { modelId=modelId, version=VERSION[modelId], revision=0, nextBelief=0,
        nextHypothesis=0, beliefs={}, beliefOrder={}, hypotheses={},
        seen={}, eventOrder={}, evictedThroughHours=-1,
        omittedBeliefs=0, omittedHypotheses=0, omittedEvents=0 }
end

local function remember(state, key, label, yes, e, relation, from, into)
    local b=state.beliefs[key]
    if not b then
        if #state.beliefOrder>=MAX_BELIEFS then
            local drop=1
            for i,k in ipairs(state.beliefOrder) do
                if string.sub(k,1,5)~="goal:" then drop=i break end
            end
            state.beliefs[table.remove(state.beliefOrder,drop)]=nil
            state.omittedBeliefs=state.omittedBeliefs+1
        end
        state.nextBelief=state.nextBelief+1
        b={ id=state.modelId.."/belief/"..tostring(state.nextBelief), key=key,
            label=string.sub(label,1,256), support=0, against=0, evidenceIds={},samples={},omittedSamples=0,
            relation=relation, from=from, into=into, branch="logistics-preservation" }
        state.beliefs[key]=b state.beliefOrder[#state.beliefOrder+1]=key
    end
    if yes then b.support=b.support+1 else b.against=b.against+1 end
    b.samples[#b.samples+1]={id=e.id,hours=e.worldHours,yes=yes}
    if #b.samples>8 then table.remove(b.samples,1) b.omittedSamples=b.omittedSamples+1 end
    b.lastHours=math.max(b.lastHours or e.worldHours,e.worldHours)
    b.confidence=posterior(b) b.status=status(b)
    appendUnique(b.evidenceIds,e.id,8)
    return b
end
local function relation(state, verb, from, into, yes, e)
    return remember(state,"relation:"..verb..":"..from..":"..into,
        verb.."("..from..", "..into..") observed association",yes,e,verb,from,into)
end
local function mergeEvidence(roots)
    local out={}
    for _, root in ipairs(roots) do
        for _, id in ipairs(root.evidenceIds) do appendUnique(out,id,8) end
    end
    return out
end

local function rebuildHypotheses(state, maxDepth, contexts)
    local prior={}
    for _, h in ipairs(state.hypotheses) do prior[h.key]=h end
    local output, keys, roots={}, {}, {}
    local omitted=0
    for _, key in ipairs(state.beliefOrder) do
        local b=state.beliefs[key]
        if b.relation then roots[#roots+1]=b end
    end
    local function add(key, verb, from, into, branch, depth, bases, parents, missing, active)
        if keys[key] then return nil end
        if #output>=MAX_HYPOTHESES then omitted=omitted+1 return nil end
        active=active~=false
        local confidence, disposition=1,"hypothesis"
        for _, base in ipairs(bases) do
            confidence=math.min(confidence,posterior(base,state.lastHours))
            if base.status=="falsified" then disposition="falsified"
            elseif base.status=="refined" and disposition~="falsified" then disposition="refined" end
        end
        -- Derived paths never count their own predictions as observations.
        confidence=confidence*(0.55^(depth-1))
        if depth==1 then disposition=status(bases[1]) end
        local previous=prior[key]
        local id=previous and previous.id
        if not id then
            state.nextHypothesis=state.nextHypothesis+1
            id="associative/hypothesis/"..tostring(state.nextHypothesis)
        end
        local h={id=id,key=key,label=string.sub((depth==1 and "Observed association " or "Analogy ")..verb.."("..from..", "..into..")",1,256),
            relation=verb,from=from,into=into,branch=branch,depth=depth,
            confidence=confidence,status=disposition,evidenceIds=mergeEvidence(bases),
            parentIds=copyList(parents,4),missing=copyList(missing,8),roots=bases,active=active,
            revisions={},omittedRevisions=previous and (previous.omittedRevisions or 0) or 0}
        for _, revision in ipairs(previous and previous.revisions or {}) do
            h.revisions[#h.revisions+1]={worldHours=revision.worldHours,status=revision.status,
                active=revision.active,evidenceIds=copyList(revision.evidenceIds,8)}
        end
        if not previous or previous.status~=disposition or (previous.active~=false)~=active then
            h.revisions[#h.revisions+1]={worldHours=state.lastHours,status=disposition,
                active=active,evidenceIds=copyList(h.evidenceIds,8)}
            if #h.revisions>8 then
                table.remove(h.revisions,1) h.omittedRevisions=h.omittedRevisions+1
            end
        end
        output[#output+1]=h keys[key]=h
        return h
    end
    local seeds={}
    for _, b in ipairs(roots) do
        local h=add("seed:"..b.id,b.relation,b.from,b.into,b.branch,1,{b},{},
            {"Association does not establish an operating method or recipe."})
        if h then seeds[#seeds+1]=h end
    end
    -- Compose observed links by a common semantic endpoint. Inputs remain
    -- distinct evidence roots even when a later path reuses the same relation.
    if maxDepth>=2 then
        local work=0
        for _, a in ipairs(roots) do
            for _, b in ipairs(roots) do
                work=work+1
                if work<=128 and a.id~=b.id and a.into==b.from
                    and posterior(a,state.lastHours)>0.5 and posterior(b,state.lastHours)>0.5
                    and keys["seed:"..a.id] and keys["seed:"..b.id] then
                    add("compose:"..a.id..":"..b.id,"compose",a.from,b.into,
                        "logistics-preservation",2,{a,b},
                        {keys["seed:"..a.id].id,keys["seed:"..b.id].id},
                        {"The composed operation has not been performed.",
                         "Interfaces, timing and losses remain unmeasured."})
                end
            end
        end
    end
    local function sharesMaterial(a,b)
        for _, left in ipairs({a.from,a.into}) do
            if left~="container" and left~="source" then
                if left==b.from or left==b.into then return true end
            end
        end
        return false
    end
    local function connectedEvidence(seed)
        local bases={seed} local used={[seed.relation]=true}
        local evidence={} for _,id in ipairs(seed.evidenceIds) do evidence[id]=true end
        for pass=1,3 do
            for _,candidate in ipairs(roots) do
                local distinct,connected=false,false
                for _,id in ipairs(candidate.evidenceIds) do if not evidence[id] then distinct=true end end
                for _,base in ipairs(bases) do if sharesMaterial(base,candidate) then connected=true end end
                if #bases<4 and not used[candidate.relation] and distinct and connected
                    and posterior(candidate,state.lastHours)>0.5 then
                    bases[#bases+1]=candidate used[candidate.relation]=true
                    for _,id in ipairs(candidate.evidenceIds) do evidence[id]=true end
                end
            end
        end
        return bases
    end
    local frontier={}
    for _,h in ipairs(seeds) do
        if h.status~="falsified" and h.confidence>0.5 then
            local bases=connectedEvidence(h.roots[1])
            local relevantContext=(contexts.cook and (h.from=="food" or h.into=="food"))
                or (contexts.forage and (h.from=="food" or h.into=="food"))
                or (contexts.treat and (h.into=="hunger-relief" or h.into=="thirst-relief"))
            frontier[#frontier+1]={hypothesis=h,bases=bases,
                limit=math.min(maxDepth,#bases+((#bases>=3 and relevantContext) and 1 or 0))}
        end
    end
    for depth=2,maxDepth do
        local nextFrontier={}
        for _, path in ipairs(frontier) do
            local h=path.hypothesis
            for _, rule in ipairs(RULES) do
                if rule.from==h.relation and depth<=path.limit then
                    local child=add(h.key.."/"..rule.into,h.relation=="operate" and "regulate" or rule.into,
                        h.from,h.into,rule.branch,depth,path.bases,{h.id},
                        {rule.missing,"Connected containment, conveyance or use is an analogy basis, not the proposed mechanism.",
                         "No demonstrated recipe, apparatus or operating method."})
                    if child then nextFrontier[#nextFrontier+1]={hypothesis=child,bases=path.bases,limit=path.limit} end
                end
            end
        end
        frontier=nextFrontier
    end
    -- Existing personal capabilities are analogy contexts, not outcomes.
    -- They never certify a new branch or strengthen the observed relation.
    if maxDepth>=2 then
        for _, h in ipairs(seeds) do
            for _, cap in ipairs({"cook","forage","treat"}) do
                if contexts[cap]==true then
                    add(h.key.."/context:"..cap,"operate",h.into,cap,
                        CAPABILITIES[cap],2,h.roots,{h.id},
                        {"Transfer from this association to "..cap.." has not been tested.",
                         "The required materials and operating method remain unknown."})
                end
            end
        end
    end
    -- A contradicted path remains a revisable record. It cannot be used as
    -- current support, but renewed evidence must not turn it into a new idea
    -- with no refutation history. Retention shares the hypothesis cap.
    for _, previous in ipairs(state.hypotheses) do
        if not keys[previous.key] and previous.depth>1 then
            local bases, counterevidence={},false
            for _, oldRoot in ipairs(previous.roots) do
                local current=state.beliefs[oldRoot.key]
                local root=(current and current.id==oldRoot.id) and current or oldRoot
                bases[#bases+1]=root
                if root.against>0 then counterevidence=true end
            end
            if counterevidence then
                local missing=copyList(previous.missing,7)
                appendUnique(missing,"Supporting evidence was challenged; this path is held until its premises qualify again.",8)
                add(previous.key,previous.relation,previous.from,previous.into,previous.branch,
                    previous.depth,bases,previous.parentIds,missing,false)
            end
        end
    end
    state.hypotheses=output
    state.omittedHypotheses=omitted
end

local function measurable(e)
    if e.status=="interrupted" or e.status=="unavailable" then return nil,"censored-access-or-interruption" end
    if e.kind=="inspection" then
        if e.perspective~="performed" or e.status~="completed"
            or (e.foodPresent==nil and e.waterPresent==nil) then return nil,"contents-unmeasured" end
        return "inspect",true
    end
    if e.kind=="consume" then
        local delta=e.category=="food" and e.hungerDelta or e.category=="water" and e.thirstDelta or nil
        if delta==nil then return nil,"relief-unmeasured" end
        return e.category,delta>0
    end
    if e.category=="container" then return nil,"resource-category-unavailable" end
    return e.category,e.status=="completed"
end

function M.observe(modelId, state, experience, maxDepth)
    if not validState(modelId,state) then return "rejected:model-state" end
    if not validEvent(experience) then return "rejected:experience" end
    if not finite(maxDepth) or maxDepth<1 or maxDepth>4 or maxDepth~=math.floor(maxDepth) then
        return "rejected:depth"
    end
    local e=experience
    if state.actorId and state.actorId~=e.observerId then return "rejected:foreign-observer" end
    if state.seen[e.id] then return "ignored:duplicate" end
    if e.worldHours<=state.evictedThroughHours then return "ignored:evicted-evidence-frontier" end
    local goal, yes=measurable(e)
    if not goal then return "ignored:"..yes end
    state.actorId=e.observerId
    state.seen[e.id]=true
    state.eventOrder[#state.eventOrder+1]={id=e.id,hours=e.worldHours}
    if #state.eventOrder>MAX_EVENTS then
        local old=table.remove(state.eventOrder,1)
        state.seen[old.id]=nil
        state.evictedThroughHours=math.max(state.evictedThroughHours,old.hours)
        state.omittedEvents=state.omittedEvents+1
    end
    state.revision=state.revision+1
    state.lastHours=math.max(state.lastHours or e.worldHours,e.worldHours)
    -- Store is evidence of placement, not a new food/water-goal completion.
    if e.kind~="store" then
        remember(state,"goal:"..goal,"Qualified "..goal.." outcomes",yes,e)
    end
    if modelId=="ordinary" then
        remember(state,"direct:"..e.kind..":"..e.category..":"..tostring(e.sourceId or e.itemType or "unspecified"),
            e.perspective.." "..e.kind.." "..e.category.." at "..tostring(e.sourceId or "unlocated source"),yes,e)
    else
        if e.kind=="inspection" then
            if e.foodPresent~=nil then relation(state,"contain","container","food",e.foodPresent,e) end
            if e.waterPresent~=nil then relation(state,"contain","container","water",e.waterPresent,e) end
        elseif e.kind=="consume" then
            relation(state,"operate",e.category,e.category=="food" and "hunger-relief" or "thirst-relief",yes,e)
        elseif e.kind=="acquire" then
            relation(state,"convey","source",e.category,yes,e)
        else
            relation(state,"contain","container",e.category,yes,e)
        end
        local contexts=state.capabilities or {}
        if e.capabilities and (not state.capabilityHours or e.worldHours>=state.capabilityHours) then
            contexts={cook=e.capabilities.cook==true,forage=e.capabilities.forage==true,treat=e.capabilities.treat==true}
            state.capabilityHours=e.worldHours
        end
        state.capabilities=contexts
        rebuildHypotheses(state,maxDepth,contexts)
    end
    return "revised:"..modelId..":"..tostring(state.revision)..":"..(yes and "observed-effect" or "counterexample")
end

local function probability(state, goal, associative, hours)
    local direct=state.beliefs["goal:"..goal]
    if direct then return posterior(direct,hours) end
    if associative and (goal=="food" or goal=="water") then
        local b=state.beliefs["relation:contain:container:"..goal]
        if b then return 0.5+(posterior(b,hours)-0.5)*0.6 end
    end
    return 0.5
end
local function predictions(state, associative, hours)
    return {
        food={probability=probability(state,"food",associative,hours),
            claim="The next qualified food acquisition succeeds or measured own consumption relieves hunger."},
        water={probability=probability(state,"water",associative,hours),
            claim="The next qualified water acquisition succeeds or measured own consumption relieves thirst."},
        inspect={probability=probability(state,"inspect",associative,hours),
            claim="A performed inspection returns definite contents evidence, including an empty result."},
        continue={probability=0.5,
            claim="No new goal is initiated; its outcome remains unobserved without a matching action receipt."},
    }
end
local function associativeChoice(state, f, p)
    local food=f.hunger/math.max(0.05,f.eatAt)
    local water=f.thirst/math.max(0.05,f.drinkAt)
    local pressure=math.max(food,water)
    if pressure<0.55 then return "continue","Current pressure leaves room to retain the ongoing intent." end
    local scores={food=-1,water=-1,inspect=-1,continue=0.16}
    -- A reserve margin anticipates need before the ordinary threshold.
    -- It is a policy horizon, not a claim about unmeasured physiological rates.
    if f.foodAllowed and food>=0.72 then
        scores.food=food*p.food.probability*(f.knownFood>0 and 1 or 0.4)
    end
    if f.waterAllowed and water>=0.72 then
        scores.water=water*p.water.probability*(f.knownWater>0 and 1 or 0.4)
    end
    if f.inspectionAllowed and f.knownPlaces>0 then
        local uncertainFood=4*p.food.probability*(1-p.food.probability)
        local uncertainWater=4*p.water.probability*(1-p.water.probability)
        local unknown=(f.knownFood==0 and food or 0)+(f.knownWater==0 and water or 0)
        scores.inspect=unknown*(0.18+0.18*(uncertainFood+uncertainWater)/2)*p.inspect.probability
        local contain=state.beliefs["relation:contain:container:food"]
        local waterContain=state.beliefs["relation:contain:container:water"]
        if contain or waterContain then
            scores.inspect=scores.inspect+0.12*pressure*math.max(posterior(contain,f.worldHours),posterior(waterContain,f.worldHours))
        end
    end
    if f.priorIntent and scores[f.priorIntent] and scores[f.priorIntent]>=0 then
        scores[f.priorIntent]=scores[f.priorIntent]+0.025
    end
    local selected="continue"
    for _, name in ipairs({"water","food","inspect"}) do
        if scores[name]>scores[selected] then selected=name end
    end
    return selected,"Anticipated pressure, independently learned outcomes and information value favor "..selected.."."
end

function M.propose(modelId, state, frame)
    if not validState(modelId,state) then return nil,"model-state" end
    if not validFrame(frame) then return nil,"private-frame" end
    if state.actorId and state.actorId~=frame.actorId then return nil,"foreign-actor" end
    if state.lastHours and frame.worldHours<state.lastHours then return nil,"future-evidence" end
    local p=predictions(state,modelId=="associative",frame.worldHours)
    local selected, interpretation="continue","No admissible ordinary need threshold is reached."
    if modelId=="ordinary" then
        if frame.waterAllowed and frame.thirst>=frame.drinkAt then
            selected,interpretation="water","Thirst reaches the existing personal drinking threshold."
        elseif frame.foodAllowed and frame.hunger>=frame.eatAt then
            selected,interpretation="food","Hunger reaches the existing personal eating threshold."
        end
    else selected,interpretation=associativeChoice(state,frame,p) end
    local proposal={modelId=modelId,version=VERSION[modelId],actionId=selected,
        interpretation=interpretation,confidence=p[selected].probability,predictions=p}
    if modelId=="associative" then
        for _, h in ipairs(state.hypotheses) do
            if h.active~=false and h.status~="falsified" and (h.into==selected or h.from==selected) then
                proposal.hypothesisId=h.id break
            end
        end
    end
    return proposal
end

function M.summary(modelId, state, hours)
    if not validState(modelId,state) or not finite(hours) then return nil,"model-state" end
    if state.lastHours and hours<state.lastHours then return nil,"future-evidence" end
    local out={beliefs={},hypotheses={}}
    for _, key in ipairs(state.beliefOrder) do
        local b=state.beliefs[key]
        out.beliefs[#out.beliefs+1]={id=b.id,label=b.label,confidence=posterior(b,hours),status=status(b)}
    end
    for _, h in ipairs(state.hypotheses) do
        local confidence=1
        for _,root in ipairs(h.roots) do confidence=math.min(confidence,posterior(root,hours)) end
        confidence=confidence*(0.55^(h.depth-1))
        out.hypotheses[#out.hypotheses+1]={id=h.id,label=h.label,branch=h.branch,
            depth=h.depth,confidence=confidence,status=h.status,
            evidenceIds=copyList(h.evidenceIds,8),parentIds=copyList(h.parentIds,4),missing=copyList(h.missing,8)}
    end
    return out
end

return M
