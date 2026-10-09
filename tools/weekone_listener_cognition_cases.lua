-- Actual Perception -> Cognition -> both CognitiveModels path on installed Kahlua.
local P,C,M=SAO.Perception,SAO.Cognition,SAO.CognitiveModels
local count=0
local function check(name,value)
    assert(value,"WEEKONE_LISTENER:"..name)
    count=count+1
    print("CASE "..name)
end
local function clone(value)
    if type(value)~="table" then return value end
    local out={}
    for k,v in pairs(value) do out[k]=clone(v) end
    return out
end
hours=24
local nativeNow=12
local listenerBody={getX=function()return 11 end,getY=function()return 20 end,
    getZ=function()return 0 end}
local otherBody={}
local nearBody={}
local priorBody={}
local performerBody={}
records={listener={id="listener"},other={id="other"},near={id="near"},
    prior={id="prior"},
    ["bwo-73"]={id="bwo-73",weekOne={source="BanditsWeekOne",
        status="external",brainId=73,born=12.5}}}
SAO.Identity.get=function(id)return records[id]end
SAO.History.countyHours=function()return hours end
SAO.Labor={capabilityOf=function()return {canCook=false,
    canForage=false,canTreat=false}end}
SAO.Claims={heldBy=function(rec)
    return rec==records["bwo-73"] and "BanditsWeekOne" or nil end}
SAO.Needs={ownsRecoveryBody=function(id,body)
    return id=="listener" and body==listenerBody
        or id=="other" and body==otherBody
        or id=="near" and body==nearBody
        or id=="prior" and body==priorBody end}
local current=true
local epoch="01234567-89ab-cdef-0123-456789abcdef"
local occurrence={schema="sao.weekone-performance-occurrence/1",
    actorId="bwo-73",brainId=73,born=12.5,clock="native-world-age-hours",
    soundId="BWOInstrumentBassGuitar1",soundHandle=37,
    pulseId=epoch.."-1",epoch=epoch,sequence=1,emittedAtHours=11.9}
SAO.WeekOneContinuity={livePerformance=function(id)
    if current and id=="bwo-73" then return performerBody,clone(occurrence) end
end,livePerformanceIds=function()return current and {"bwo-73"} or {} end}
local hearing={schema="sao.weekone-performance-hearing/1",
    observerId="listener",actorId="bwo-73",brainId=73,born=12.5,
    clock="native-world-age-hours",basis="native-scanner-acquired-occurrence",
    soundId=occurrence.soundId,soundHandle=37,pulseId=occurrence.pulseId,
    epoch=epoch,sequence=1,emittedAtHours=11.9,heardAtHours=11.91,
    witnessedAtHours=11.92,atHours=11.93}
GameTime={getInstance=function()return {
    getWorldAgeHours=function()return nativeNow end}end}
getGameTime=function()return GameTime.getInstance()end
SAOJavaBridge={claimWeekOnePerformanceHearing=function(self,body,source,
        actorId,brainId,born,pulse)
    if source~=performerBody or actorId~="bwo-73" or brainId~=73
        or born~=12.5 or pulse~=occurrence.pulseId then return nil end
    local row=clone(hearing)
    row.observerId=body==listenerBody and "listener"
        or body==otherBody and "other"
        or body==nearBody and "near"
        or body==priorBody and "prior" or "unowned"
    return row
end,perceive=function()return "" end}
local urgent={id="urgent",evidence=.5,continuity=.5,novelty=.5,
    informationGain=.5,blockers=0,utility=1}
local music={id="music",evidence=.5,continuity=.5,novelty=.5,
    informationGain=.5,blockers=0,utility=.2}
local choices={urgent,music}
check("configured",C.configure(.5,12,3))
local before=C.interpretPlans("listener",choices,{domain="ordinary-needs"})
check("urgent_before_exposure",before and before.selected=="urgent"
    and records.listener.cognition==nil)
check("source_hearing_acquired",P.acquireWeekOnePerformanceHearing(
    "listener",listenerBody,"bwo-73")~=nil)
current=false -- The physical sound ended; remembered hearing remains historical.
local after=C.interpretPlans("listener",choices,{domain="ordinary-needs"})
local state=records.listener.cognition
local event=state and state.experiences[1]
check("actual_plan_path_ingests_historical_hearing",after and event
    and event.kind=="weekone-performance-hearing"
    and event.actorId=="bwo-73" and event.observerId=="listener"
    and event.perspective=="observed" and event.sourceId=="BanditsWeekOne:SAOPerform")
check("exact_source_and_occurrence",event.pulseId==occurrence.pulseId
    and event.sourceEpoch==epoch and event.sourceSequence==1
    and event.sourceBrainId==73 and event.sourceBorn==12.5
    and event.soundId==occurrence.soundId and event.soundHandle==37
    and event.nativeEmittedAtHours==11.9 and event.nativeHeardAtHours==11.91
    and event.nativeWitnessedAtHours==11.92 and event.nativeClaimedAtHours==11.93
    and event.occurredAtHours==24 and event.worldHours==24)
check("private_memory_only",records.other.cognition==nil
    and records["bwo-73"].cognition==nil and event.succeeded==nil
    and event.actionKind==nil and event.itemType==nil
    and records.listener.enjoyment==nil and records.listener.assent==nil)
local key="heard:weekone-performance:bwo-73:"..occurrence.soundId
local belief=state.models.ordinary.beliefs[key]
local noHobbyPromotion=true
for _,model in ipairs({state.models.ordinary,state.models.associative}) do
    for _,fact in pairs(model.beliefs) do
        if fact.planKind=="hobby" or fact.planKind=="recreate" then
            noHobbyPromotion=false
        end
    end
end
check("both_models_remember_acoustic_source",belief
    and state.models.associative.beliefs[key]
    and belief.planKind==nil and state.models.associative.beliefs[key].planKind==nil
    and state.models.ordinary.revision==1 and state.models.associative.revision==1)
check("hearing_is_not_hobby_success",noHobbyPromotion)
check("single_hearing_stays_neutral",C.weekOneMusicInterest("listener").status
    =="single-hearing" and C.weekOneMusicInterest("listener").informationGain==0)
check("urgent_priority_survives_exposure",after.selected=="urgent"
    and after.models[1].selected=="urgent" and after.models[2].selected=="urgent")
local snapshot=C.snapshot("listener",true)
snapshot.experiences[1].soundId="caller-mutated"
check("detached_private_history",state.experiences[1].soundId==occurrence.soundId)
local revision=state.models.ordinary.revision
hours=25
check("repeated_plan_does_not_relearn",C.interpretPlans("listener",choices,{})
    and state.models.ordinary.revision==revision and #state.experiences==1
    and state.nativeExperienceCursors["weekone-performance-hearing"]==1)
local forged=clone(event)
forged.id="weekone-heard/2"
check("generic_caller_cannot_mint_hearing",not C.experience("listener",forged)
    and #state.experiences==1)
local wrong={
    {"fake_pleasure","succeeded",true},
    {"fake_action","actionKind","perform-instrument"},
    {"wrong_source","sourceId","invented"},
    {"wrong_pulse","pulseId",epoch.."-2"},
    {"wrong_actor","actorId","listener"},
    {"wrong_handle","soundHandle",0},
    {"future_county","occurredAtHours",26},
    {"future_native","nativeClaimedAtHours",11.91},
}
for _,case in ipairs(wrong) do
    local row=clone(event);row[case[2]]=case[3]
    check("model_refuses_"..case[1],not M.acceptsExperience(row))
end
local foreign=clone(event);foreign.id="weekone-heard/2"
foreign.observerId="other"
check("foreign_model_owner_refused",M.observe("ordinary",
    state.models.ordinary,foreign,3)=="rejected:foreign-observer")
local function planScore(view,index,candidateId)
    for _,row in ipairs(view.models[index].ranked) do
        if row.id==candidateId then return row.score end
    end
end
local musicOptions={
    {id="instrument",kind="instrument",evidence=.5,continuity=.5,
        novelty=.5,informationGain=0,blockers=0},
    {id="reading",kind="reading",evidence=.5,continuity=.5,
        novelty=.5,informationGain=0,blockers=0},
}
current=true
hours=26;nativeNow=12.3
occurrence.sequence=2;occurrence.pulseId=epoch.."-2"
occurrence.emittedAtHours=12.2
hearing.sequence=2;hearing.pulseId=occurrence.pulseId
hearing.emittedAtHours=12.2;hearing.heardAtHours=12.21
hearing.witnessedAtHours=12.22;hearing.atHours=12.23
check("second_distinct_hearing_acquired",P.acquireWeekOnePerformanceHearing(
    "listener",listenerBody,"bwo-73")~=nil)
local passive=C.interpretPlans("listener",musicOptions,{domain="leisure-action"})
local passiveInterest=C.weekOneMusicInterest("listener")
check("repeated_passive_hearing_is_familiarity",passive and passiveInterest.status
    =="familiarity-only" and passiveInterest.informationGain==0
    and passive.heardMusicInterest.status=="familiarity-only")
local passiveInstrument=planScore(passive,2,"instrument")
local passiveReading=planScore(passive,2,"reading")
local ownOutcome={actorId="listener",sequence=1,workId="instrument:listener:1",
    bodyGenerationKnown=true,bodyToken="own-body:listener",
    verb="blow-harmonica",itemType="Base.Harmonica",itemId="42",
    status="completed",admittedAtHours=25.5,atHours=26,
    soundEmitted=true,worldSoundEmitted=true,soundHandle=77,
    startedAtHours=25.6,endedAtHours=26,soundEnded=true,cleanupPending=false}
SAO.Gesture={instrumentOutcome=function(id,sequence)
    if id=="listener" and sequence==ownOutcome.sequence then
        return clone(ownOutcome) end
end}
check("own_music_action_canonical",C.instrumentOutcome("listener",1))
local interest=C.weekOneMusicInterest("listener")
check("repeated_hearing_plus_own_action_supports_exploration",
    interest.status=="supported-exploration"
    and interest.informationGain==.2 and #interest.evidenceIds==3)
local supported=C.interpretPlans("listener",musicOptions,{domain="leisure-action"})
check("bounded_private_music_option_effect",supported
    and supported.heardMusicInterest.status=="supported-exploration"
    and math.abs(planScore(supported,2,"instrument")-passiveInstrument-.06)<.000001
    and planScore(supported,2,"reading")==passiveReading
    and planScore(supported,1,"instrument")==planScore(passive,1,"instrument"))
check("other_person_has_no_borrowed_interest",
    C.weekOneMusicInterest("other").status=="unobserved")
local unrelated=C.interpretPlans("listener",musicOptions,{domain="ordinary-needs"})
check("unrelated_plan_domain_untouched",unrelated
    and unrelated.heardMusicInterest==nil
    and planScore(unrelated,2,"instrument")==passiveInstrument)
check("urgent_priority_survives_supported_interest",
    C.interpretPlans("listener",choices,{domain="ordinary-needs"}).selected=="urgent"
    and records.listener.enjoyment==nil and records.listener.assent==nil)
hours=27
ownOutcome.sequence=2;ownOutcome.workId="instrument:listener:2"
ownOutcome.status="interrupted";ownOutcome.admittedAtHours=26.5
ownOutcome.atHours=27;ownOutcome.soundEmitted=false
ownOutcome.worldSoundEmitted=false;ownOutcome.soundHandle=nil
ownOutcome.startedAtHours=nil;ownOutcome.endedAtHours=nil
ownOutcome.soundEnded=false
check("own_failed_attempt_retained",C.instrumentOutcome("listener",2))
local mixed=C.weekOneMusicInterest("listener")
local mixedView=C.interpretPlans("listener",musicOptions,{domain="leisure-action"})
check("latest_failed_attempt_counters_exploration",mixed.status=="mixed-evidence"
    and mixed.informationGain==0
    and planScore(mixedView,2,"instrument")==passiveInstrument)
hours=28;nativeNow=13.1
occurrence.sequence=3;occurrence.pulseId=epoch.."-3"
occurrence.emittedAtHours=13
hearing.sequence=3;hearing.pulseId=occurrence.pulseId
hearing.emittedAtHours=13;hearing.heardAtHours=13.001
hearing.witnessedAtHours=13.002;hearing.atHours=13.003
check("near_listener_first_hearing",P.acquireWeekOnePerformanceHearing(
    "near",nearBody,"bwo-73")~=nil)
check("near_listener_first_ingestion",C.interpretPlans("near",musicOptions,
    {domain="leisure-action"})~=nil)
hours=28.01;nativeNow=13.15
occurrence.sequence=4;occurrence.pulseId=epoch.."-4"
occurrence.emittedAtHours=13.01
hearing.sequence=4;hearing.pulseId=occurrence.pulseId
hearing.emittedAtHours=13.01;hearing.heardAtHours=13.02
hearing.witnessedAtHours=13.03;hearing.atHours=13.04
check("near_listener_second_hearing",P.acquireWeekOnePerformanceHearing(
    "near",nearBody,"bwo-73")~=nil)
check("near_listener_second_ingestion",C.interpretPlans("near",musicOptions,
    {domain="leisure-action"})~=nil)
hours=28.1
local nearOutcome=clone(ownOutcome)
nearOutcome.actorId="near";nearOutcome.sequence=1
nearOutcome.workId="instrument:near:1"
nearOutcome.bodyToken="own-body:near";nearOutcome.admittedAtHours=28.01
nearOutcome.startedAtHours=28.02;nearOutcome.endedAtHours=28.1
nearOutcome.atHours=28.1;nearOutcome.status="completed"
nearOutcome.soundEmitted=true;nearOutcome.worldSoundEmitted=true
nearOutcome.soundHandle=78;nearOutcome.soundEnded=true
SAO.Gesture.instrumentOutcome=function(id,sequence)
    if id=="near" and sequence==1 then return clone(nearOutcome) end
end
check("near_listener_own_action",C.instrumentOutcome("near",1))
check("near_occurrences_do_not_make_interest",
    C.weekOneMusicInterest("near").status=="single-hearing"
    and C.weekOneMusicInterest("near").informationGain==0)
hours=29
local priorOutcome=clone(nearOutcome)
priorOutcome.actorId="prior";priorOutcome.workId="instrument:prior:1"
priorOutcome.bodyToken="own-body:prior"
priorOutcome.admittedAtHours=20;priorOutcome.startedAtHours=20.1
priorOutcome.endedAtHours=20.2;priorOutcome.atHours=20.2
SAO.Gesture.instrumentOutcome=function(id,sequence)
    if id=="prior" and sequence==1 then return clone(priorOutcome) end
end
check("prior_music_action_canonical",C.instrumentOutcome("prior",1))
hours=30;nativeNow=14
occurrence.sequence=5;occurrence.pulseId=epoch.."-5"
occurrence.emittedAtHours=13.9
hearing.sequence=5;hearing.pulseId=occurrence.pulseId
hearing.emittedAtHours=13.9;hearing.heardAtHours=13.91
hearing.witnessedAtHours=13.92;hearing.atHours=13.93
check("prior_listener_first_hearing",P.acquireWeekOnePerformanceHearing(
    "prior",priorBody,"bwo-73")~=nil)
check("prior_listener_first_ingestion",C.interpretPlans("prior",musicOptions,
    {domain="leisure-action"})~=nil)
hours=31;nativeNow=14.4
occurrence.sequence=6;occurrence.pulseId=epoch.."-6"
occurrence.emittedAtHours=14.3
hearing.sequence=6;hearing.pulseId=occurrence.pulseId
hearing.emittedAtHours=14.3;hearing.heardAtHours=14.31
hearing.witnessedAtHours=14.32;hearing.atHours=14.33
check("prior_listener_second_hearing",P.acquireWeekOnePerformanceHearing(
    "prior",priorBody,"bwo-73")~=nil)
check("prior_listener_second_ingestion",C.interpretPlans("prior",musicOptions,
    {domain="leisure-action"})~=nil)
check("prior_action_does_not_claim_response",
    C.weekOneMusicInterest("prior").status=="familiarity-only"
    and C.weekOneMusicInterest("prior").informationGain==0)
-- Persistence eviction can remove the event and model seen maps. The private
-- producer cursor still bars a second interpretation of the same occurrence.
revision=state.models.ordinary.revision
state.experiences={};state.seen={}
state.models.ordinary.seen={};state.models.associative.seen={}
check("evicted_hearing_not_relearned",C.interpretPlans("listener",choices,{})
    and #state.experiences==0 and state.models.ordinary.revision==revision)
-- The other observer must acquire their own receipt before their own model can
-- remember the same source. The first listener's journal cannot be borrowed.
current=true
check("other_has_no_borrowed_history",C.interpretPlans("other",choices,{})
    and records.other.cognition==nil)
check("other_person_acquires_own_hearing",P.acquireWeekOnePerformanceHearing(
    "other",otherBody,"bwo-73")~=nil)
check("other_private_model_independent",C.interpretPlans("other",choices,{})
    and records.other.cognition.experiences[1].observerId=="other"
    and records.other.cognition.models.ordinary~=state.models.ordinary)
-- Corrupt old journal rows are ignored; a normal urgent route still resolves.
records.other.weekOnePerformanceHearings[1].pulseId="invalid"
records.other.cognition=nil
check("bad_journal_does_not_block_urgent_plan",C.interpretPlans("other",choices,{})
    and records.other.cognition==nil)
local proxyBody={getX=function()return 11 end,getY=function()return 20 end,
    getZ=function()return 0 end}
local proxyBrain={id=84,born=44.5}
local proxy={id="bwo-84",weekOne={source="BanditsWeekOne",
    status="external",brainId=84,born=44.5}}
records["bwo-84"]=proxy
SAO.Claims.heldBy=function(rec)
    return (rec==records["bwo-73"] or rec==proxy)
        and "BanditsWeekOne" or nil
end
SAO.WeekOneContinuity.sourceBodyFor=function(id)
    if id=="bwo-84" then return proxyBody,proxyBrain end
end
local recoveryClaim=SAOJavaBridge.claimWeekOnePerformanceHearing
SAOJavaBridge.claimWeekOnePerformanceHearing=function(self,body,...)
    local row=recoveryClaim(self,body==proxyBody and listenerBody or body,...)
    if row and body==proxyBody then
        row.observerId="bwo-84"
        row.observerBrainId=84;row.observerBorn=44.5
    end
    return row
end
check("source_proxy_acquires_own_exact_hearing",
    P.acquireWeekOnePerformanceHearing("bwo-84",proxyBody,"bwo-73")~=nil
    and proxy.weekOnePerformanceHearings[1].observerBorn==44.5)
local proxyIngested=C.weekOnePerformanceHearings("bwo-84")
check("source_proxy_private_cognition_drain",proxyIngested
    and proxy.cognition and #proxy.cognition.experiences==1
    and proxy.cognition.experiences[1].observerId=="bwo-84"
    and proxy.cognition.experiences[1].observerBrainId==84
    and proxy.cognition.experiences[1].observerBorn==44.5
    and records["bwo-73"].cognition==nil)
check("source_proxy_does_not_borrow_recovery_body",
    not SAO.Needs.ownsRecoveryBody("bwo-84",proxyBody)
    and SAO.Claims.heldBy(proxy)=="BanditsWeekOne")
-- A source proxy's own completed instrument action uses the source native
-- clock and a separately stamped county clock. Hearing alone is familiarity.
hours=32;nativeNow=14.8
occurrence.sequence=7;occurrence.pulseId=epoch.."-7"
occurrence.emittedAtHours=14.6
hearing.sequence=7;hearing.pulseId=occurrence.pulseId
hearing.emittedAtHours=14.6;hearing.heardAtHours=14.61
hearing.witnessedAtHours=14.62;hearing.atHours=14.63
check("proxy_second_distinct_hearing",
    P.acquireWeekOnePerformanceHearing("bwo-84",proxyBody,"bwo-73")~=nil)
check("proxy_second_private_hearing",
    C.weekOnePerformanceHearings("bwo-84")
    and C.weekOneMusicInterest("bwo-84").status=="familiarity-only")
local sourceOutcome={actorId="bwo-84",sequence=1,
    sourceId="BanditsWeekOne:SAOPerform",sourceAction="SAOPerform",
    claimOwner="BanditsWeekOne",purpose="perform-with-physical-instrument",
    status="completed",sourceProgram="BWOInstrument",
    sourceStage="Perform",brainId=84,born=44.5,bodyId=84,
    decisionAtTick=380,itemId=49,itemType="Base.Violin",
    soundId="BWOInstrumentViolinPaganini",
    startedAtHours=14.7,atHours=14.75}
local sourceOutcomes={[1]=clone(sourceOutcome)}
SAO.WeekOneContinuity.performanceOutcome=function(id,sequence)
    if id=="bwo-84" and sourceOutcomes[sequence] then
        return clone(sourceOutcomes[sequence]) end
end
check("legacy_unstamped_performance_can_be_remembered",
    C.weekOnePerformanceOutcome("bwo-84",1))
local legacyEvent=proxy.cognition.experiences[#proxy.cognition.experiences]
check("legacy_native_time_does_not_invent_county_order",
    legacyEvent.kind=="weekone-instrument-performance"
    and legacyEvent.startedAtHours==14.7
    and legacyEvent.nativeCompletedAtHours==nil
    and legacyEvent.occurredAtHours==14.75
    and C.weekOneMusicInterest("bwo-84").status=="familiarity-only")
hours=32.2;nativeNow=14.9
sourceOutcome.sequence=2;sourceOutcome.startedAtHours=14.76
sourceOutcome.atHours=14.79;sourceOutcome.countyAtHours=32.19
sourceOutcomes[2]=clone(sourceOutcome)
check("stamped_source_performance_acquired",
    C.weekOnePerformanceOutcome("bwo-84",2))
local sourceEvent=proxy.cognition.experiences[#proxy.cognition.experiences]
check("source_performance_clocks_preserved",
    sourceEvent.kind=="weekone-instrument-performance"
    and sourceEvent.startedAtHours==14.76
    and sourceEvent.nativeCompletedAtHours==14.79
    and sourceEvent.occurredAtHours==32.19
    and sourceEvent.worldHours==32.2
    and sourceEvent.sourceBrainId==84 and sourceEvent.sourceBorn==44.5)
local sourceInterest=C.weekOneMusicInterest("bwo-84")
check("source_own_performance_supports_private_exploration",
    sourceInterest.status=="supported-exploration"
    and sourceInterest.informationGain==.2
    and #sourceInterest.evidenceIds==3
    and sourceInterest.evidenceIds[3]==sourceEvent.id
    and C.weekOneMusicInterest("listener").status~="supported-exploration")
local invalidNative=clone(sourceEvent)
invalidNative.nativeCompletedAtHours=14.7
check("model_refuses_native_completion_before_start",
    not M.acceptsExperience(invalidNative))
sourceOutcome.sequence=3;sourceOutcome.startedAtHours=14.8
sourceOutcome.atHours=14.85;sourceOutcome.countyAtHours=32.3
sourceOutcomes[3]=clone(sourceOutcome)
check("future_county_completion_refused",
    not C.weekOnePerformanceOutcome("bwo-84",3))
sourceOutcome.countyAtHours="invalid"
sourceOutcomes[3]=clone(sourceOutcome)
check("invalid_county_completion_refused",
    not C.weekOnePerformanceOutcome("bwo-84",3))
sourceOutcome.countyAtHours=-1
sourceOutcomes[3]=clone(sourceOutcome)
check("negative_county_completion_refused",
    not C.weekOnePerformanceOutcome("bwo-84",3))
sourceOutcome.countyAtHours=32.19
sourceOutcome.atHours=15.1
sourceOutcomes[3]=clone(sourceOutcome)
check("future_native_completion_refused",
    not C.weekOnePerformanceOutcome("bwo-84",3))
__weekOneListenerResult="PASS Week One listener cognition "..count
return __weekOneListenerResult
