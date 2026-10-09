-- Runs the candidate module itself in installed Kahlua. These are model-level
-- observations, not claims about a loaded world's acquisition authenticity.
local M=SAO.CognitiveModels
local cases=0
local function check(ok, reason) if not ok then error(reason) end end
local function copy(v)
    if type(v)~="table" then return v end
    local out={} for k,x in pairs(v) do out[k]=copy(x) end return out
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function case(name,fn)
    local ok,why=pcall(fn)
    if not ok then error(name..": "..tostring(why)) end
    cases=cases+1
end
local function frame(overrides)
    local f={id="frame:1",actorId="p1",worldHours=10,hunger=0.1,thirst=0.1,
        fatigue=0.1,eatAt=0.5,drinkAt=0.5,foodAllowed=true,waterAllowed=true,
        inspectionAllowed=false,knownFood=1,knownWater=1,knownPlaces=1,
        capabilities={cook=false,forage=false,treat=false}}
    for k,v in pairs(overrides or {}) do f[k]=v end return f
end
local function event(id, overrides)
    local e={id=id,actorId="p1",observerId="p1",worldHours=10,kind="consume",
        category="food",sourceId="source:1",itemType="Base.Food",perspective="performed",
        status="completed",hungerDelta=0.2}
    for k,v in pairs(overrides or {}) do e[k]=v end return e
end
local function inspection(id,food,water)
    return {id=id,actorId="p1",observerId="p1",worldHours=10,kind="inspection",
        category="container",sourceId="holder:1",perspective="performed",
        status="completed",foodPresent=food,waterPresent=water}
end
local function transfer(id,source)
    return {id=id,actorId="p1",observerId="p1",worldHours=10,kind="acquire",
        category="food",sourceId=source or "holder:1",itemType="Base.Food",
        perspective="performed",status="completed"}
end
local function learn(id,state,e,depth)
    local result=M.observe(id,state,e,depth or 4)
    check(string.sub(result,1,8)=="revised:","authentic evidence refused: "..result)
end
local function findHyp(state,accept)
    for _,h in ipairs(M.summary("associative",state,10).hypotheses) do if accept(h) then return h end end
end
local function probability(id,state,goal)
    return M.propose(id,state,frame()).predictions[goal].probability
end
local function plan(id, kind, category, source, item)
    return {id=id,evidence=0.5,continuity=0.2,novelty=0.1,informationGain=0.2,blockers=0,
        utility=0,consequences={{kind=kind or "acquire",category=category or "food",
            sourceId=source,itemType=item,value=1}}}
end
local function context(hours)
    return {actorId="p1",atHours=hours or 10,pressure=0.6,
        capabilities={cook=false,forage=false,treat=false},needs={hunger=0.6,fatigue=0.2,endurance=0.7}}
end
local function preparation(sequence, source, item)
    return {id="cooking/p1/"..sequence,actorId="p1",observerId="p1",worldHours=10,
        occurredAtHours=10,kind="preparation",category="food",sourceId=source or "stove:1",
        itemType=item or "Base.Food",itemId=100+sequence,perspective="performed",
        status="completed",heatObserved=true,beforeCookingTime=1,afterCookingTime=2}
end
local function entry(sequence, source, success, condition)
    return {id="entry/p1/"..sequence,actorId="p1",observerId="p1",worldHours=10,
        occurredAtHours=10,kind="entry-outcome",category="body",sourceId=source,
        perspective="performed",status="completed",actionKind="door",
        apertureState=condition or "closed",succeeded=success}
end

function cognitiveModelCases()
case("ordinary thresholds",function()
    local s=M.newState("ordinary")
    check(M.propose("ordinary",s,frame({hunger=0.8,thirst=0.5})).actionId=="water",
        "ordinary drinking equality or priority changed")
    check(M.propose("ordinary",s,frame({hunger=0.5,thirst=0.8,waterAllowed=false})).actionId=="food",
        "ordinary food equality or admission changed")
    check(M.propose("ordinary",s,frame({hunger=0.49,thirst=0.49,inspectionAllowed=true})).actionId=="continue",
        "ordinary below-threshold policy changed")
end)
case("shared feasibility",function()
    for _,id in ipairs({"ordinary","associative"}) do
        check(M.propose(id,M.newState(id),frame({hunger=1,thirst=1,foodAllowed=false,
            waterAllowed=false,inspectionAllowed=false})).actionId=="continue",
            "inadmissible goal selected")
    end
end)
case("anticipation",function()
    local f=frame({hunger=0.41,thirst=0.01})
    check(M.propose("ordinary",M.newState("ordinary"),f).actionId=="continue",
        "ordinary anticipation fixture changed")
    check(M.propose("associative",M.newState("associative"),f).actionId=="food",
        "associative anticipation missing")
end)
case("private frame boundary",function()
    local s=M.newState("associative") local before=copy(s)
    local f=frame() f.otherProposal={actionId="food"}
    check(M.propose("associative",s,f)==nil,"foreign model output admitted")
    f=frame() f.hiddenStock=10
    check(M.propose("associative",s,f)==nil,"objective stock admitted")
    f=frame() f.capabilities.secretRecipe=true
    check(M.propose("associative",s,f)==nil,"unknown capability admitted")
    check(equal(s,before),"invalid frame mutated state")
end)
case("independent owners",function()
    local ordinary=M.newState("ordinary") local associative=M.newState("associative")
    local other=M.newState("ordinary") local before=copy(associative)
    learn("ordinary",ordinary,event("owner:1"))
    check(equal(before,associative) and #other.beliefOrder==0,
        "model states share evidence storage")
    check(M.propose("ordinary",associative,frame())==nil,"foreign model state admitted")
    check(M.observe("ordinary",associative,event("owner:2"),3)=="rejected:model-state",
        "foreign model observed into sibling state")
    local inconsistent=M.newState("ordinary") inconsistent.modelId="associative"
    check(M.propose("ordinary",inconsistent,frame())==nil,"foreign model state admitted")
    inconsistent=M.newState("ordinary") inconsistent.version="sao-associative/1"
    check(M.propose("ordinary",inconsistent,frame())==nil,"foreign model version admitted")
end)
case("actor boundary",function()
    local s=M.newState("associative") learn("associative",s,event("actor:1"))
    local before=copy(s)
    check(M.propose("associative",s,frame({actorId="p2"}))==nil,"foreign actor proposal admitted")
    local e=event("actor:2",{actorId="p2",observerId="p2"})
    check(M.observe("associative",s,e,3)=="rejected:foreign-observer","foreign observer admitted")
    check(equal(s,before),"foreign actor changed state")
end)
case("pre-outcome predictions",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) local p=M.propose(id,s,frame()) local n=0
        check(p.version==(id=="ordinary" and "sao-ordinary/3" or "sao-associative/3")
            and p.modelId==id,"version or model identity absent")
        for _,goal in ipairs({"food","water","inspect","continue"}) do
            local prediction=p.predictions[goal]
            check(prediction and prediction.probability>=0 and prediction.probability<=1
                and #prediction.claim>0 and #prediction.claim<=512,"pre-outcome prediction missing")
        end
        for _ in pairs(p.predictions) do n=n+1 end
        check(n==4,"prediction set changed")
        p.predictions.food.probability=0.123
        check(M.propose(id,s,frame()).predictions.food.probability==0.5,"proposal aliases model state")
    end
end)
case("queries cannot teach",function()
    local s=M.newState("associative") learn("associative",s,inspection("query:1",true,false))
    local before=copy(s)
    for i=1,150 do
        M.propose("associative",s,frame({id="future:"..i,worldHours=10+i,capabilities={cook=true}}))
        M.summary("associative",s,100+i)
    end
    check(equal(s,before),"query or elapsed time strengthened beliefs")
end)
case("exact repeated evidence",function()
    local s=M.newState("associative") local e=inspection("repeat:1",true,false)
    learn("associative",s,e) local before=copy(s) e.worldHours=200
    check(M.observe("associative",s,e,4)=="ignored:duplicate","duplicate outcome was not recognized")
    check(equal(s,before),"repeated evidence strengthened association")
end)
case("censored access",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) learn(id,s,event("censor:base")) local before=copy(s)
        for _,kind in ipairs({"interrupted","unavailable"}) do
            M.observe(id,s,event("censor:"..kind,{status=kind,detail="door locked"}),4)
        end
        local e=event("censor:unmeasured") e.hungerDelta=nil
        M.observe(id,s,e,4)
        check(equal(s,before),"censored access or absent measure became counterevidence")
    end
end)
case("private observation boundary",function()
    local s=M.newState("associative") local before=copy(s)
    local e=event("privacy:1",{actorId="p2",perspective="observed"})
    check(M.observe("associative",s,e,4)=="rejected:experience","other person's private relief leaked")
    e=inspection("privacy:2",true,false) e.actorId="p2" e.perspective="observed"
    check(M.observe("associative",s,e,4)=="rejected:experience","private inspected contents leaked")
    check(equal(s,before),"private observation mutated state")
    e=transfer("privacy:3") e.actorId="p2" e.perspective="observed"
    learn("associative",s,e)
    check(s.actorId=="p1" and probability("associative",s,"food")>0.5,
        "authenticated witnessed transfer was discarded")
end)
case("measured counterexample",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id)
        learn(id,s,event("zero:1",{hungerDelta=0,status="no-effect"}))
        check(probability(id,s,"food")<0.5,"zero native relief became success")
        local before=probability(id,s,"food")
        learn(id,s,event("zero:2",{hungerDelta=-0.1}))
        check(probability(id,s,"food")<before,"contradictory actual effect did not revise belief")
    end
end)
case("independent plan revision",function()
    local o=M.newState("ordinary") local a=M.newState("associative")
    local f=frame({hunger=0.8,thirst=0.8})
    check(M.propose("associative",a,f).actionId=="water","plan revision fixture changed")
    for i=1,5 do
        local e=event("plan:water:"..i,{category="water",thirstDelta=0,status="no-effect"}) e.hungerDelta=nil
        learn("ordinary",o,e) learn("associative",a,e)
    end
    for i=1,3 do learn("ordinary",o,event("plan:food:"..i)) learn("associative",a,event("plan:food:"..i)) end
    check(M.propose("associative",a,f).actionId=="food","real outcomes did not change associative plan")
    check(M.propose("ordinary",o,f).actionId=="water","ordinary ceased preserving current need priority")
    check(M.propose("ordinary",o,f).predictions.water.probability<0.5,
        "ordinary direct evidence memory failed to revise")
end)
case("empty inspection",function()
    local s=M.newState("associative") learn("associative",s,inspection("empty:1",false,false))
    check(probability("associative",s,"inspect")>0.5,"empty inspection mislabeled as failed observation")
    check(probability("associative",s,"food")<0.5,"empty contents did not challenge contents association")
    local h=findHyp(s,function(x) return x.depth==1 and string.find(x.label,"food",1,true) end)
    check(h and h.status=="falsified","unsupported contents expectation was not falsified")
end)
case("semantic transfer",function()
    local s=M.newState("associative")
    local f=frame({hunger=0.47,thirst=0.02,knownFood=0,knownWater=1,inspectionAllowed=true})
    check(M.propose("associative",s,f).actionId=="food","semantic transfer fixture changed")
    learn("associative",s,inspection("analogy:known-holder",true,false))
    check(M.propose("associative",s,f).actionId=="inspect","container experience did not transfer information value")
    check(M.propose("ordinary",M.newState("ordinary"),f).actionId=="continue",
        "ordinary became associative supervisor")
end)
case("compositional paths",function()
    local s=M.newState("associative")
    learn("associative",s,inspection("path:contents",true,nil))
    learn("associative",s,transfer("path:convey"))
    learn("associative",s,event("path:use",{capabilities={cook=true,forage=false,treat=false}}))
    local chain=findHyp(s,function(h) return string.find(h.label,"compose(container, hunger-relief)",1,true) end)
    check(chain and chain.depth==2 and #chain.parentIds==2 and #chain.evidenceIds==2,
        "distinct observed links did not compose")
    local deep=findHyp(s,function(h) return h.depth==4 and h.branch=="electrical-systems" end)
    local shallow=findHyp(s,function(h) return h.depth==1 end)
    check(deep and deep.confidence<shallow.confidence and #deep.missing>=1,
        "cross-domain conjecture missing or overconfident")
    local context=findHyp(s,function(h) return string.find(h.label,", cook)",1,true) end)
    check(context and context.status=="hypothesis" and #context.missing==2,
        "capability context became demonstrated technology")
    for _,h in ipairs(M.summary("associative",s,10).hypotheses) do
        check(#h.evidenceIds>0 and #h.evidenceIds<=8 and h.depth<=4 and h.confidence<=1,
            "hypothesis lacks bounded source evidence")
    end
end)
case("depth bound",function()
    local s=M.newState("associative")
    learn("associative",s,inspection("depth:1",true,false),1)
    learn("associative",s,transfer("depth:convey"),1)
    learn("associative",s,event("depth:use",{capabilities={cook=true}}),1)
    for _,h in ipairs(M.summary("associative",s,1000).hypotheses) do
        check(h.depth==1,"configured depth bound bypassed")
    end
    local before=copy(s)
    check(M.observe("associative",s,inspection("depth:2",true,false),5)=="rejected:depth"
        and equal(before,s),"invalid depth mutated model")
end)
case("counterexample refinement",function()
    local s=M.newState("associative") learn("associative",s,inspection("refine:1",true,nil))
    local before=findHyp(s,function(h) return h.depth==1 end)
    learn("associative",s,inspection("refine:2",false,nil))
    local after=findHyp(s,function(h) return h.id==before.id end)
    check(after and after.status=="refined" and after.confidence<before.confidence
        and #after.evidenceIds==2,"counterexample erased provenance or failed to refine")
end)
case("detached summaries",function()
    local s=M.newState("associative") learn("associative",s,inspection("detach:1",true,false))
    local before=copy(s) local summary=M.summary("associative",s,10)
    summary.beliefs[1].confidence=1 summary.hypotheses[1].evidenceIds[1]="invented"
    summary.hypotheses[1].missing[1]="known now"
    check(equal(s,before),"summary aliases evidence or hypothesis state")
end)
case("bounds and old replay",function()
    local s=M.newState("ordinary")
    for i=1,280 do
        local e=transfer("bounded:"..i,"holder:"..i) e.worldHours=i
        learn("ordinary",s,e)
    end
    local summary=M.summary("ordinary",s,1000)
    check(#summary.beliefs+#summary.hypotheses<=64 and #summary.beliefs<=32
        and #s.eventOrder==256 and s.omittedEvents==24 and s.omittedBeliefs>0,
        "state or receipt history unbounded")
    local before=copy(s) local e=transfer("bounded:1","holder:1") e.worldHours=1
    check(M.observe("ordinary",s,e,4)=="ignored:evicted-evidence-frontier" and equal(s,before),
        "evicted evidence relearned as new")
end)
case("data reload",function()
    local s=M.newState("associative") learn("associative",s,inspection("reload:1",true,false))
    local restored=copy(s)
    check(equal(M.propose("associative",s,frame()),M.propose("associative",restored,frame())),
        "data-only reload changed proposal")
    learn("associative",restored,event("reload:2"))
    check(s.revision==1 and restored.revision==2,"restored state aliases prior owner")
end)
case("invalid inputs",function()
    local s=M.newState("associative") local before=copy(s)
    local f=frame({thirst=0/0}) check(M.propose("associative",s,f)==nil,"nonfinite frame admitted")
    local e=event(string.rep("x",129))
    check(M.observe("associative",s,e,4)=="rejected:experience","overlong evidence identity admitted")
    e=event("invalid:1") e.otherBeliefs={}
    check(M.observe("associative",s,e,4)=="rejected:experience","foreign beliefs entered evidence")
    check(equal(before,s),"rejected input changed state")
end)
case("evidence diversity controls depth",function()
    local s=M.newState("associative")
    for i=1,12 do learn("associative",s,inspection("diversity:same:"..i,true,nil)) end
    for _,h in ipairs(M.summary("associative",s,10).hypotheses) do
        check(h.depth==1,"repeated single action unlocked a fixed hypothesis ladder")
    end
    local unrelated=transfer("diversity:water") unrelated.category="water" unrelated.itemType="Base.Water"
    learn("associative",s,unrelated)
    for _,h in ipairs(M.summary("associative",s,10).hypotheses) do
        check(h.depth==1,"unrelated object outcome escalated another association")
    end
    learn("associative",s,transfer("diversity:food"))
    check(findHyp(s,function(h) return h.depth==2 end)~=nil,"new connected action did not change association paths")
    check(findHyp(s,function(h) return h.depth>=3 end)==nil,"two primitive relations claimed deeper evidence")
end)
case("counterexamples prune analogy",function()
    local s=M.newState("associative")
    learn("associative",s,inspection("prune:contains",true,nil))
    learn("associative",s,transfer("prune:convey"))
    learn("associative",s,event("prune:operate",{capabilities={cook=true}}))
    check(findHyp(s,function(h) return h.depth==4 end)~=nil,"pruning fixture lacks deep analogy")
    learn("associative",s,inspection("prune:counterexample",false,nil))
    for _,h in ipairs(s.hypotheses) do
        check(h.active==false or h.depth<3,
            "counterexample failed to prune independently generated path")
    end
end)
case("confidence aging retains provenance",function()
    local s=M.newState("associative") local a=event("aging:old",{worldHours=1})
    learn("associative",s,a)
    local before=copy(s)
    local fresh=M.propose("associative",s,frame({worldHours=1})).predictions.food.probability
    local older=M.propose("associative",s,frame({worldHours=49})).predictions.food.probability
    check(older>0.5 and older<fresh and equal(before,s),"aging altered receipts or failed to reduce certainty")
    learn("associative",s,event("aging:new-counter",{worldHours=25,hungerDelta=0}))
    local b=s.beliefs["goal:food"]
    check(b.support==1 and b.against==1 and #b.evidenceIds==2
        and M.propose("associative",s,frame({worldHours=25})).predictions.food.probability<0.5,
        "new observation refreshed old counterbalancing evidence")
    check(M.propose("associative",s,frame({worldHours=2}))==nil
        and M.summary("associative",s,2)==nil,"future evidence entered past prediction")
end)
case("public transport limits",function()
    local s=M.newState("associative") local before=copy(s)
    check(M.propose("associative",s,frame({id=string.rep("x",129)}))==nil,
        "overlong frame identity admitted")
    check(M.propose("associative",s,frame({knownFood=100001}))==nil,
        "unbounded known count admitted")
    check(M.observe("associative",s,event("limit:source",{sourceId=string.rep("x",161)}),4)=="rejected:experience",
        "overlong source identity admitted")
    check(equal(before,s),"transport refusal mutated state")
end)
case("late evidence preserves current capability context",function()
    local s=M.newState("associative")
    local first=inspection("cap:contents",true,nil) first.worldHours=1
    learn("associative",s,first)
    local second=transfer("cap:convey") second.worldHours=2
    learn("associative",s,second)
    learn("associative",s,event("cap:new-context",{worldHours=10,capabilities={cook=false}}))
    learn("associative",s,event("cap:late-context",{worldHours=3,capabilities={cook=true}}))
    check(s.capabilities.cook==false and s.capabilityHours==10,
        "late evidence rewound capability context")
    for _,h in ipairs(M.summary("associative",s,10).hypotheses) do
        check(h.depth<4,"late personal context unlocked a stale analogy")
    end
end)
case("derived refutation continuity",function()
    local s=M.newState("associative")
    learn("associative",s,inspection("continuity:contains",true,nil))
    learn("associative",s,transfer("continuity:convey"))
    learn("associative",s,event("continuity:operate",{capabilities={cook=true}}))
    local key,id
    for _,h in ipairs(s.hypotheses) do
        if h.depth==4 and h.branch=="electrical-systems" then key,id=h.key,h.id break end
    end
    check(id~=nil,"continuity fixture lacks derived path")
    learn("associative",s,inspection("continuity:counter",false,nil))
    local held
    for _,h in ipairs(s.hypotheses) do if h.key==key then held=h end end
    check(held and held.id==id and held.active==false and held.status=="refined",
        "contradicted derived branch lost its identity")
    check(#held.revisions>=2 and held.revisions[#held.revisions].active==false,
        "branch refutation history was erased")
    local foundCounter=false
    for _,eid in ipairs(held.evidenceIds) do if eid=="continuity:counter" then foundCounter=true end end
    check(foundCounter,"held branch omitted actual counterevidence")
    -- Query eligibility is independent of retained display order.
    local inactive
    for i,h in ipairs(s.hypotheses) do
        if h.active==false and h.from=="food" then inactive=h table.remove(s.hypotheses,i) break end
    end
    check(inactive~=nil,"continuity fixture lacks held food interpretation")
    table.insert(s.hypotheses,1,inactive)
    check(M.propose("associative",s,frame({hunger=0.8,thirst=0.01})).hypothesisId~=inactive.id,
        "held branch was used as current interpretation")
    s=copy(s)
    learn("associative",s,inspection("continuity:renewed",true,nil))
    local renewed
    for _,h in ipairs(s.hypotheses) do if h.key==key then renewed=h end end
    check(renewed and renewed.id==id and renewed.active==true and renewed.status=="refined",
        "renewed support invented a fresh branch identity")
    check(#renewed.revisions>=3 and renewed.revisions[2].active==false
        and renewed.revisions[#renewed.revisions].active==true,
        "renewed support erased prior refutation")
    check(#renewed.missing>0 and renewed.confidence<0.5,
        "renewed support granted operational realization")
end)
case("bounded refutation history",function()
    local s=M.newState("associative")
    learn("associative",s,inspection("history:contains",true,nil))
    learn("associative",s,transfer("history:convey"))
    learn("associative",s,event("history:operate",{capabilities={cook=true}}))
    local id,key
    for _,h in ipairs(s.hypotheses) do
        if h.depth==4 and h.branch=="electrical-systems" then id,key=h.id,h.key break end
    end
    for i=1,42 do
        local e=inspection("history:revision:"..i,math.floor((i-1)/3)%2==1,nil)
        learn("associative",s,e)
    end
    local retained
    for _,h in ipairs(s.hypotheses) do if h.key==key then retained=h end end
    check(retained and retained.id==id and #retained.revisions<=8 and retained.omittedRevisions>0,
        "refutation history exceeded its bound or lost identity")
    check(#s.hypotheses<=32 and #s.beliefOrder+#s.hypotheses<=64,
        "retained branches exceeded model capacity")
end)
case("plan exact acquisition changes relative order",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id)
        local a,b=plan("a",nil,nil,"holder:1","Base.Food"),plan("b",nil,nil,"holder:2","Base.Food")
        b.utility=0.05
        check(M.interpretPlans(id,s,{a,b},context()).selected=="b","plan baseline utility changed")
        learn(id,s,transfer("plan:own:1"))
        local result=M.interpretPlans(id,s,{a,b},context())
        check(result.selected=="a" and result.ranked[1].predictions[1].probability>0.5,
            "exact acquisition did not change relative plan order")
        check(result.ranked[2].predictions[1].probability==0.5,
            "exact acquisition leaked to another source")
        check(result.ranked[1].predictions[1].evidenceIds[1]=="plan:own:1"
            and result.ranked[1].predictions[1].basis=="exact-experience"
            and result.ranked[1].interpretation~=result.ranked[2].interpretation,
            "candidate prediction omitted specific basis")
    end
end)
case("plan unrelated evidence isolation",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id)
        local c=plan("untouched",nil,nil,"holder:unknown","Base.Other")
        local before=M.planScore(id,c,0.6,s,context())
        for i=1,4 do learn(id,s,transfer("plan:unrelated:"..i,"holder:elsewhere")) end
        check(M.planScore(id,c,0.6,s,context())==before
            and M.planPrediction(id,c,s,context()).predictions[1].probability==0.5,
            "unrelated strongest belief changed plan value")
        local specific=plan("wrong-type",nil,nil,"holder:elsewhere","Base.Other")
        check(M.planPrediction(id,specific,s,context()).predictions[1].probability==0.5,
            "another item type became exact acquisition evidence")
    end
end)
case("plan contradiction reverses prior choice",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) local a,b=plan("a",nil,nil,"holder:1"),plan("b",nil,nil,"holder:2")
        b.utility=0.02
        learn(id,s,transfer("plan:positive"))
        check(M.interpretPlans(id,s,{a,b},context()).selected=="a","plan contradiction fixture lacks support")
        for i=1,3 do local e=transfer("plan:negative:"..i) e.status="no-effect" learn(id,s,e) end
        local result=M.interpretPlans(id,s,{a,b},context())
        check(result.selected=="b" and result.ranked[2].predictions[1].probability<0.5,
            "plan counterevidence did not reverse choice")
    end
end)
case("plan decay changes relative choice without learning",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) local a,b=plan("a",nil,nil,"holder:1"),plan("b",nil,nil,"holder:2") b.utility=0.02
        learn(id,s,transfer("plan:old-success"))
        local snapshot=copy(s)
        check(M.interpretPlans(id,s,{a,b},context()).selected=="a","plan decay fixture lacks support")
        check(M.interpretPlans(id,s,{a,b},context(250)).selected=="b",
            "plan evidence did not age at query clock")
        check(equal(s,snapshot),"plan query trained or aged stored facts")
    end
end)
case("plan actor and time boundaries",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) learn(id,s,transfer("plan:private")) local c=plan("a",nil,nil,"holder:1")
        local ctx=context() ctx.actorId="p2"
        check(M.interpretPlans(id,s,{c},ctx)==nil and M.planPrediction(id,c,s,ctx)==nil
            and M.planScore(id,c,0.6,s,ctx)==nil,"foreign actor plan prediction admitted")
        ctx=context(9)
        check(M.interpretPlans(id,s,{c},ctx)==nil and M.planPrediction(id,c,s,ctx)==nil,
            "future state entered plan prediction")
        local unrelated=plan("unrelated",nil,nil,"holder:unknown")
        check(M.planPrediction(id,unrelated,s,ctx)==nil,"future state entered plan prediction")
        local corrupt=copy(s) corrupt.actorId=nil
        check(M.planPrediction(id,c,corrupt,context())==nil,"unbound learned state entered plan prediction")
        corrupt=copy(s)
        for _,belief in pairs(corrupt.beliefs) do
            if belief.planKind=="acquire" then belief.samples[1].hours=11 end
        end
        check(M.planPrediction(id,c,corrupt,context())==nil,"future receipt entered plan prediction")
    end
end)
case("plan strict frame and consequence contract",function()
    local s=M.newState("ordinary") local c=plan("a",nil,nil,"holder:1")
    local ctx=context() ctx.atHours=nil
    check(M.interpretPlans("ordinary",s,{c},ctx)==nil,"plan missing clock admitted")
    local bad=copy(c) bad.consequences[1].hiddenStock=9
    check(M.planPrediction("ordinary",bad,s,context())==nil,"private plan admitted hidden consequence field")
    for _,field in ipairs({"value","sourceId","itemType","kind","category","condition"}) do
        bad=copy(c)
        bad.consequences[1][field]=field=="value" and 3 or field=="sourceId" and string.rep("x",161)
            or field=="itemType" and string.rep("x",161) or "invalid"
        check(M.planPrediction("ordinary",bad,s,context())==nil,"invalid consequence admitted: "..field)
    end
    bad=copy(c) bad.consequences[3]=copy(bad.consequences[1])
    check(M.planPrediction("ordinary",bad,s,context())==nil,"sparse consequence list admitted")
    bad=copy(c) for i=2,5 do bad.consequences[i]=copy(bad.consequences[1]) end
    check(M.planPrediction("ordinary",bad,s,context())==nil,"unbounded consequence list admitted")
    bad=copy(c) bad.evidence="0.5"
    check(M.interpretPlans("ordinary",s,{bad},context())==nil,"string plan scalar admitted")
    ctx=context() ctx.capabilities.cook=1
    check(M.interpretPlans("ordinary",s,{c},ctx)==nil,"invalid plan capability admitted")
    ctx=context() ctx.needs.fatigue=2
    check(M.interpretPlans("ordinary",s,{c},ctx)==nil,"invalid plan need admitted")
    check(M.interpretPlans("ordinary",s,{c,copy(c)},context())==nil,"duplicate plan identity admitted")
    check(M.interpretPlans("ordinary",s,{[1]=c,[3]=copy(c)},context())==nil,"sparse plan candidate list admitted")
end)
case("plan current capability prior and zero skill",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) local c=plan("prepare","prepare","food","stove:1","Base.Food")
        local ctx=context() local low=M.planPrediction(id,c,s,ctx).predictions[1]
        check(low.probability>0 and low.probability==0.5 and low.basis=="unknown",
            "zero cooking capability became impossibility")
        ctx.capabilities.cook=true
        local experienced=M.planPrediction(id,c,s,ctx).predictions[1]
        check(experienced.probability>low.probability and experienced.probability<0.75
            and #experienced.evidenceIds==0 and #s.beliefOrder==0,
            "current capability prior invented experience or certainty")
        ctx=context() ctx.capabilities.forage=true ctx.capabilities.treat=true
        check(M.planPrediction(id,c,s,ctx).predictions[1].probability==low.probability,
            "unrelated capability supplied preparation evidence")
    end
end)
case("performed watch and return informs the next accepted objective",function()
    local event={id="commitment/p1/1",actorId="p1",observerId="p1",
        worldHours=10,occurredAtHours=10,kind="commitment-outcome",
        category="social",sourceId="matter:watch:1",perspective="performed",
        status="completed",actionKind="watch-return",succeeded=true}
    for _,id in ipairs({"ordinary","associative"}) do
        local state=M.newState(id)
        local exact=plan("same","commitment","social","matter:watch:1")
        exact.consequences[1].condition="watch-return"
        local other=plan("next","commitment","social","matter:watch:2")
        other.consequences[1].condition="watch-return"
        local unknown=M.planPrediction(id,exact,state,context()).predictions[1]
        check(unknown.probability==0.5,"new objective gained unperformed skill")
        learn(id,state,event)
        local known=M.planPrediction(id,exact,state,context()).predictions[1]
        local transferred=M.planPrediction(id,other,state,context()).predictions[1]
        check(known.probability>unknown.probability
            and known.basis=="exact-experience",
            "performed objective failed to revise own prediction")
        if id=="ordinary" then
            check(transferred.probability==unknown.probability,
                "ordinary model invented transfer between requests")
        else
            check(transferred.probability>unknown.probability
                and transferred.probability<known.probability
                and transferred.basis=="related-experience",
                "similar objective failed to use weaker learned evidence")
        end
        check(M.observe(id,state,event,4)=="ignored:duplicate",
            "objective experience replay changed the model")
    end
end)
case("plan preparation exact type and weaker transfer",function()
    local results={}
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) learn(id,s,preparation(1))
        local exact=M.planPrediction(id,plan("exact","prepare","food","stove:1","Base.Food"),s,context()).predictions[1]
        local related=M.planPrediction(id,plan("related","prepare","food","stove:2","Base.Food"),s,context()).predictions[1]
        local other=M.planPrediction(id,plan("other","prepare","food","stove:2","Base.Other"),s,context()).predictions[1]
        local typeOnly=M.planPrediction(id,plan("type","prepare","food",nil,"Base.Food"),s,context()).predictions[1]
        check(exact.probability>0.5 and typeOnly.probability>0.5 and other.probability==0.5,
            "preparation evidence lost exact item conditioning")
        if id=="ordinary" then check(related.probability==0.5,"ordinary plan used unperformed preparation source")
        else check(related.probability>0.5 and related.probability<exact.probability
            and related.basis=="related-experience" and related.evidenceIds[1]=="cooking/p1/1",
            "related preparation failed to transfer with lower confidence") end
        results[id]={state=s,exact=exact,related=related}
    end
end)
case("plan inspection predicts actual contents",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) learn(id,s,inspection("plan:empty",false,true))
        local food=M.planPrediction(id,plan("food","inspect","food","holder:1"),s,context()).predictions[1]
        local water=M.planPrediction(id,plan("water","inspect","water","holder:1"),s,context()).predictions[1]
        local contents=M.planPrediction(id,plan("contents","inspect","container","holder:1"),s,context()).predictions[1]
        check(food.probability<0.5 and water.probability>0.5 and contents.probability>0.5,
            "empty inspection became successful food discovery")
        local other=M.planPrediction(id,plan("other","inspect","water","holder:2"),s,context()).predictions[1]
        if id=="associative" then check(other.probability>0.5 and other.probability<water.probability,
            "related inspection failed to transfer with lower confidence")
        else check(other.probability==0.5,"ordinary inspection invented contents at another source") end
    end
end)
case("plan entry and recovery use same evidence owner",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) learn(id,s,entry(1,"door:1",false))
        local a,b=plan("door1","entry","body","door:1"),plan("door2","entry","body","door:2")
        a.consequences[1].condition="closed" b.consequences[1].condition="closed"
        check(M.interpretPlans(id,s,{a,b},context()).selected=="door2","entry failure did not change shared plan choice")
        a.consequences[1].condition="open"
        check(M.planPrediction(id,a,s,context()).predictions[1].probability==0.5,
            "entry experience ignored changed aperture condition")
        learn(id,s,{id="recovery/p1/1",actorId="p1",observerId="p1",worldHours=10,occurredAtHours=10,
            kind="recovery-outcome",category="body",perspective="performed",status="completed",actionKind="sleep",
            succeeded=true,beforeValue=0.8,afterValue=0.5,durationHours=1})
        local sleep=M.planPrediction(id,plan("sleep","sleep","body"),s,context()).predictions[1]
        local rest=M.planPrediction(id,plan("rest","rest","body"),s,context()).predictions[1]
        check(sleep.probability>0.5 and rest.probability==0.5,"sleep result credited awake rest")
    end
end)
case("plan detached bounded predictions",function()
    local s=M.newState("associative") learn("associative",s,transfer("plan:detach"))
    local c=plan("a",nil,nil,"holder:1") local before=copy(s) local original=copy(c)
    local predicted=M.planPrediction("associative",c,s,context())
    predicted.predictions[1].evidenceIds[1]="mutated" predicted.predictions[1].beliefIds[1]="mutated"
    local view=M.interpretPlans("associative",s,{c},context())
    view.ranked[1].predictions[1].evidenceIds[1]="again"
    check(equal(s,before) and equal(c,original),"plan prediction aliases or mutates source state")
    local p=M.planPrediction("associative",c,s,context())
    check(#p.predictions==1 and #p.predictions[1].evidenceIds<=8 and #p.predictions[1].beliefIds<=8
        and p.expectedValue>=0 and p.expectedValue<=8 and p.predictions[1].uncertainty>=0
        and p.predictions[1].uncertainty<=1,"plan prediction escaped its bounds")
end)
case("plan structural fallback and utility preservation",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local c=plan("a",nil,nil,"holder:1") c.utility=1.25
        check(M.planScore(id,c,0.6)==1.25,"cold plan fallback changed situational utility")
        c.consequences={}
        check(M.planScore(id,c,0.6)==1.25,"empty consequences changed situational utility")
        c.utility=nil c.consequences=nil
        local expected=id=="ordinary" and (0.5*0.55+0.2*0.30+0.6*0.15)
            or (0.5*0.25+0.2*0.15+0.1*0.20+0.2*0.30+0.6*0.10)
        check(math.abs(M.planScore(id,c,0.6)-expected)<0.000001,"legacy plan structural baseline changed")
        c.id=string.rep("x",129)
        c.consequences={{kind="acquire",category="food",sourceId="holder:1",
            itemType=string.rep("y",161),value=0.8}}
        local fallback=M.planScore(id,c,0.6)
        check(fallback~=nil and math.abs(fallback-expected)<0.000001,
            "long native identity lost neutral structural fallback")
        check(M.planPrediction(id,c,M.newState(id),context())==nil,
            "long native identity entered bounded prediction")
        c.utility=0/0
        check(M.planScore(id,c,0.6)==nil,"nonfinite situational utility admitted")
    end
end)
case("plan owner bounds influence without changing evidence",function()
    local s=M.newState("ordinary")
    for i=1,8 do learn("ordinary",s,transfer("plan:cap:"..i)) end
    local c=plan("a",nil,nil,"holder:1") c.utility=1 c.maxAdjustment=0.15
    local p=M.planPrediction("ordinary",c,s,context()).predictions[1]
    check(p.probability>0.8 and math.abs(M.planScore("ordinary",c,0.6,s,context())-1.15)<0.000001,
        "plan adjustment cap changed belief or exceeded owner bound")
    c.maxAdjustment=-1
    check(M.planScore("ordinary",c,0.6,s,context())==nil,"invalid plan influence bound admitted")
end)
case("plan legacy exact evidence read remains inert",function()
    for _,id in ipairs({"ordinary","associative"}) do
        local s=M.newState(id) learn(id,s,entry(1,"door:1",true))
        s.version="sao-"..id.."/2" local before=copy(s)
        local c=plan("entry","entry","body","door:1") c.consequences[1].condition="closed"
        check(M.planPrediction(id,c,s,context()).predictions[1].probability>0.5 and equal(s,before),
            "legacy plan evidence was discarded or migrated on read")
    end
end)
return "PASS "..tostring(cases).." cases"
end
