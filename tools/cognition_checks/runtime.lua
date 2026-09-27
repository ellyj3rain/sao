local C, M = SAO.Cognition, SAO.CognitiveModels
local n = 0
local function check(name, value) assert(value, "COGNITION:" .. name); n = n + 1; print("CASE " .. name) end
function frame(id)
    return {actorId=id,worldHours=hours,hunger=.7,thirst=.7,fatigue=.2,eatAt=.3,drinkAt=.3,
        foodAllowed=true,waterAllowed=true,inspectionAllowed=true,knownFood=1,knownWater=1,knownPlaces=1,
        capabilities={cook=true,forage=true,treat=false}}
end
local function last(id) local es=records[id].cognition.episodes;return es[#es] end
check("disabled_no_actor_state",not C.isDue("a") and C.choose("a",frame("a"))==nil and records.a.cognition==nil)
check("invalid_atomic_settings", not C.configure(.4,0,3) and not C.settings().enabled)
check("enable_configuration",C.configure(.5,12,3))
check("idempotent_configuration",C.configure(.5,12,3))
check("paused_configuration",C.configure(.6,12,3) and C.settings().opponentShare==.6 and C.configure(.5,12,3))
check("due_read_is_inert",C.isDue("a") and C.isDue("a") and records.a.cognition==nil)
local capability=SAO.Labor.capabilityOf
SAO.Labor.capabilityOf=function(id)return {canCook=false,canForage=false,canTreat=id=="c"}end
local caps=C.capabilities("c")
check("capability_uses_shared_authority",caps.treat and not caps.cook and not caps.forage)
SAO.Labor.capabilityOf=capability
local original=M.propose
local seen={}
M.propose=function(id,s,f)
    seen[#seen+1]=f.hunger
    local p=original(id,s,f);s.tainted=true;f.hunger=0;return p
end
local f=frame("a")
local action,episode=C.choose("a",f)
M.propose=original
check("both_receive_same_private_frame",episode and seen[1]==.7 and seen[2]==.7 and f.hunger==.7)
check("proposal_state_isolation",not records.a.cognition.models.ordinary.tainted and not records.a.cognition.models.associative.tainted)
f.hunger=0
check("immutable_prior_frame",last("a").frame.hunger==.7)
local snap=C.snapshot("a");snap.episodes[1].frame.hunger=0;snap.settings.opponentShare=0
check("detached_projection",last("a").frame.hunger==.7 and C.settings().opponentShare==.5)
check("queued_not_observed",C.started("a",episode,true,"queued") and last("a").executionStatus=="queued" and not last("a").outcome)
local token=C.capture("a","native-use")
check("attempt_start",C.attempted("a",token) and last("a").executionStatus=="attempted")
check("actual_relief",C.publish("a",token,{kind="consume",category=action,status="completed",hungerDelta=.2,thirstDelta=.2}))
check("selected_action_only",last("a").status=="observed" and last("a").outcome.actionId==action
    and last("a").outcome.success and last("a").outcome.predictions.ordinary and not last("a").outcome.alternatives)
local rev=records.a.cognition.models.ordinary.revision
check("duplicate_no_learning",C.publish("a",token,{kind="consume",category=action,status="completed",hungerDelta=.2,thirstDelta=.2})
    and records.a.cognition.models.ordinary.revision==rev)
check("conflicting_duplicate_rejected",not C.publish("a",token,{kind="consume",category=action,status="completed",hungerDelta=.4,thirstDelta=.2})
    and records.a.cognition.models.ordinary.revision==rev)
check("opportunity_rate",C.choose("a",frame("a"))==nil)
hours=hours+1
local a2,e2=C.choose("a",frame("a"));local old=C.capture("a","native-use")
hours=hours+1
check("single_pending",not C.isDue("a") and C.choose("a",frame("a"))==nil and last("a").id==e2)
C.interrupt("a","danger")
check("interruption_censored",last("a").status=="censored" and not last("a").outcome)
hours=hours+1
local a3,e3=C.choose("a",frame("a"))
check("late_outcome_cannot_resolve_new_episode",C.publish("a",old,{kind="consume",category=a2,status="completed",hungerDelta=.1,thirstDelta=.1})
    and last("a").id==e3 and last("a").status=="proposed")
local current=C.capture("a","native-use")
check("measured_no_effect",C.publish("a",current,{kind="consume",category=a3,status="no-effect",hungerDelta=0,thirstDelta=0})
    and last("a").status=="observed" and last("a").outcome.success==false)
hours=hours+1;C.choose("a",frame("a"));local refused=C.capture("a","source")
rev=records.a.cognition.models.ordinary.revision
check("refusal_censors_without_learning",C.publish("a",refused,{kind="acquire",category=last("a").selectedActionId,status="unavailable",detail="permission"})
    and last("a").status=="censored" and records.a.cognition.models.ordinary.revision==rev)
local x={id="witness-1",actorId="b",observerId="a",worldHours=hours,kind="acquire",category="food",status="completed",perspective="observed",hungerDelta=.3}
check("other_private_need_rejected",not C.experience("a",x));x.hungerDelta=nil
check("observed_transfer_admitted",C.experience("a",x))
x.id="future";x.worldHours=hours+1
check("future_event_rejected",not C.experience("a",x));x.worldHours=hours;x.observerId="b"
check("foreign_observer_rejected",not C.experience("a",x))
hours=hours+1;local bad=frame("a");bad.objectiveStock=100
check("objective_frame_rejected",C.choose("a",bad)==nil)
bad=frame("a");bad.hunger=0/0
check("nonfinite_frame_rejected",C.choose("a",bad)==nil)
local beforeCount=#records.a.cognition.experiences
local observe=M.observe
M.observe=function(id,s,event,depth) if id=="associative" then error("fixture model failed") end;return observe(id,s,event,depth) end
local test=C.capture("a","inspection");rev=records.a.cognition.models.ordinary.revision
check("model_failure_atomic",not C.publish("a",test,{kind="inspection",category="container",status="completed",foodPresent=false,waterPresent=false})
    and records.a.cognition.models.ordinary.revision==rev and #records.a.cognition.experiences==beforeCount)
M.observe=observe
check("empty_inspection_is_observation",C.publish("a",test,{kind="inspection",category="container",status="completed",foodPresent=false,waterPresent=false}))
local learned=records.a.cognition.models.associative.beliefs["relation:contain:container:food"]
check("empty_contents_counterevidence",learned and learned.against>0)
hours=hours+1;check("configure_extreme",C.configure(1,60,4))
local chosen,ep=C.choose("b",frame("b"))
check("rival_can_execute",ep and last("b").selectedModelId=="associative")
C.interrupt("b","test")
hours=hours+1;C.configure(.25,60,4)
local rival=0
for i=1,80 do
    hours=hours+1/59
    local a,e=C.choose("b",frame("b"));assert(e,"allocation admission")
    if last("b").selectedModelId=="associative" then rival=rival+1 end
    C.interrupt("b","bounded choice")
end
check("counterbalanced_selection",rival==20)
check("episode_retention",#records.b.cognition.episodes==64 and records.b.cognition.omittedEpisodes==17)
check("display_archive_separate",#C.snapshot("b").episodes==8 and #C.snapshot("b",true).episodes==64)
for i=1,270 do
    hours=hours+.01
    C.experience("b",{id="large-"..i,actorId="b",observerId="b",worldHours=hours,
        kind="acquire",category="food",status="completed",perspective="performed"})
end
check("experience_retention",#records.b.cognition.experiences==256 and records.b.cognition.omittedExperiences==14)
rev=records.b.cognition.models.ordinary.revision
local ok,why=C.experience("b",{id="large-1",actorId="b",observerId="b",worldHours=hours-2.69,
    kind="acquire",category="food",status="completed",perspective="performed"})
check("evicted_replay_refused",not ok and why=="retired-evidence-frontier" and records.b.cognition.models.ordinary.revision==rev)
local eventCount=records.a.cognition.eventSequence
C.rebindWorld();C.capture("a","native-use")
check("reload_preserves_event_serial",records.a.cognition.eventSequence==eventCount+1)
hours=hours+1;C.choose("a",frame("a"));C.rebindWorld()
check("reload_pending_censored",last("a").status=="censored" and last("a").reason=="world-reloaded")
local longId=string.rep("z",128);records[longId]={id=longId};hours=hours+1
local longAction,longEpisode=C.choose(longId,frame(longId))
check("bounded_scoped_ids",longEpisode and #longEpisode<=128 and #last(longId).frame.id<=128)
local t1,t2=C.capture("a","native-use"),C.capture("b","native-use")
check("distinct_performer_event_ids",t1 and t2 and t1.id~=t2.id)
local serial=stores.SurvivorAwareness_Cognition.eventSequence
C.rebindWorld();local t3=C.capture("a","native-use")
check("global_event_serial_durable",stores.SurvivorAwareness_Cognition.eventSequence==serial+1 and t3.id~=t1.id)
records[longId].dead=true
local deadCount=#records[longId].cognition.episodes
check("dead_snapshot_retained",#C.snapshot(longId).episodes==deadCount and C.choose(longId,frame(longId))==nil)
C.rebindWorld()
check("dead_pending_censored",last(longId).status=="censored" and last(longId).reason=="world-reloaded")
hours=hours+1;C.configure(0,60,4);records.c.cognition=nil
C.choose("c",frame("c"));C.interrupt("c","test");hours=hours+1
records.c.cognition.allocation=1
C.choose("c",frame("c"))
check("zero_weight_never_selected",last("c").selectedModelId=="ordinary" and last("c").selectionWeight==1
    and last("c").selectionPolicy=="deterministic-balanced")
local summary=M.summary
M.summary=function(id,s,at)
    local out={beliefs={},hypotheses={}}
    for i=1,64 do out.beliefs[i]={id="belief/"..i,label=string.rep("\1",512),confidence=.5,status="supported"} end
    for i=1,12 do
        local missing={};for j=1,8 do missing[j]=string.rep("\2",256)end
        out.hypotheses[i]={id="hyp/"..i,label=string.rep("\3",512),branch="forage",depth=3,
            confidence=.5,status="hypothesis",evidenceIds={"one"},parentIds={},missing=missing}
    end
    return out
end
MAXIMAL_SNAPSHOT=C.snapshot("b")
local maximalSummary=M.summary
M.summary=function(id,s,at)
    local out=maximalSummary(id,s,at)
    -- The installed lexer truncates non-ASCII source literals. Construct
    -- real UTF-16 code units through the installed string library instead.
    local label=string.rep(string.char(26519),256)..string.rep(string.char(55357,56832),128)
    local missing=string.rep(string.char(30028),128)..string.rep(string.char(55357,56832),64)
    for _,row in ipairs(out.beliefs)do row.label=label end
    for _,row in ipairs(out.hypotheses)do
        row.label=label
        for i=1,#row.missing do row.missing[i]=missing end
    end
    return out
end
MAXIMAL_UNICODE_SNAPSHOT=C.snapshot("b")
M.summary=summary
check("bounded_projection_reports_omissions",MAXIMAL_SNAPSHOT.models[1].omittedBeliefs>0
    and MAXIMAL_SNAPSHOT.models[1].omittedHypotheses>0 and #records.b.cognition.episodes==64)
M.summary=function()error("summary unavailable")end
check("failed_summary_not_partial_schema",C.snapshot("a")==nil)
M.summary=summary
RESULT="PASS cognition runtime "..n
