-- This extension runs after the unchanged actual PersonState owner cases.
local decisionChecks=0
local function checkDecision(name,value)
    if not value then error("DECISION_STATE:"..name)end
    decisionChecks=decisionChecks+1
end
local function frame(at,id)
    return {id=id or "decision-fixture",actorId=rec.id,worldHours=at or now,hunger=.1,thirst=.1,fatigue=.1,
        eatAt=.5,drinkAt=.4,foodAllowed=true,waterAllowed=true,inspectionAllowed=true,
        knownFood=0,knownWater=0,knownPlaces=1,capabilities={cook=false,forage=false,treat=false}}
end
local function choose(at,id)
    verify("decision_settings",SAO.Cognition.configure(.5,12,3))
    local action,episodeId=SAO.Cognition.choose(rec.id,frame(at,id))
    checkDecision("actual_models_choose",action~=nil and episodeId~=nil)
    local snap=SAO.Cognition.snapshot(rec.id,true)
    checkDecision("actual_snapshot_available",type(snap)=="table" and #snap.episodes==1)
    return snap.episodes[1],snap
end
fresh()
local actualBefore=SAO.PersonState.query(rec.id,body,SAO.History.ticks())
local episode=choose()
local side=episode.decisionPersonState
checkDecision("actual_producer_schema",side.schema=="sao-person-decision-state/1" and side.actorId==rec.id
    and side.decisionId==episode.frame.id and side.atHours==episode.worldHours and side.atTick==SAO.History.ticks())
checkDecision("actual_whole_state",side.status=="available" and side.reason==nil and equal(side.personState,actualBefore))
local retained=copy(rec.cognition)
side.personState.modelView.recall.episodes[1].description="snapshot mutation"
side.personState.audit.retainedMemory.initial.episodes[1].valence=-1
checkDecision("snapshot_detached",equal(rec.cognition,retained))
checkDecision("snapshot_keeps_sidecar",SAO.Cognition.snapshot(rec.id,false).episodes[1].decisionPersonState.personState.modelView.recall.episodes[1].description~="snapshot mutation")
local frozen=copy(retained.episodes[1].decisionPersonState)
rec.traitEchoes.initiative=.9;now=1
checkDecision("later_projection_not_substituted",equal(SAO.Cognition.snapshot(rec.id,true).episodes[1].decisionPersonState,frozen))
rec.cognition=__nativeRoundtrip(rec.cognition)
checkDecision("fresh_module_loaded",__reloadCognition())
checkDecision("native_serialization_reload",equal(SAO.Cognition.snapshot(rec.id,true).episodes[1].decisionPersonState,frozen))
local ownerQuery=SAO.PersonState.query
fresh()
local returned
SAO.PersonState.query=function(...)returned=ownerQuery(...);return returned end
local originalPropose=SAO.CognitiveModels.propose;local proposalCalls=0
SAO.CognitiveModels.propose=function(...)
    proposalCalls=proposalCalls+1
    if returned==nil then __captureOrderBad=true;return originalPropose(...) end
    checkDecision("capture_before_proposal",true)
    returned.modelView.effectiveTraits.initiative=99
    returned.audit.retainedMemory.initial.episodes[1].description="proposal mutation"
    return originalPropose(...)
end
local ordered=choose().decisionPersonState
checkDecision("capture_before_proposal",__captureOrderBad~=true)
checkDecision("both_models_after_capture",proposalCalls==2)
checkDecision("preproposal_deep_freeze",ordered.personState.modelView.effectiveTraits.initiative~=99
    and ordered.personState.audit.retainedMemory.initial.episodes[1].description~="proposal mutation")
SAO.CognitiveModels.propose=originalPropose;SAO.PersonState.query=ownerQuery
fresh();now=1
local queryCalls=0
SAO.PersonState.query=function(...)queryCalls=queryCalls+1;return ownerQuery(...)end
local stale=choose(0).decisionPersonState
checkDecision("historic_frame_no_later_state",stale.status=="unavailable" and stale.reason=="decision-clock-mismatch"
    and stale.atTick==SAO.History.ticks() and stale.personState==nil and queryCalls==0)
SAO.PersonState.query=ownerQuery
fresh();local future=frame(1)
checkDecision("future_frame_refused",SAO.Cognition.choose(rec.id,future)==nil)
local foreign=frame();foreign.actorId="foreign"
checkDecision("foreign_frame_refused",SAO.Cognition.choose(rec.id,foreign)==nil)
fresh();SAO.PersonState.query=nil
local absent=choose().decisionPersonState
checkDecision("missing_owner_explicit",absent.status=="unavailable" and absent.reason=="person-state-owner-unavailable" and absent.personState==nil)
SAO.PersonState.query=ownerQuery
fresh();SAO.PersonState.query=function()error("owner failed")end
local threw=choose().decisionPersonState
checkDecision("query_failure_explicit",threw.status=="unavailable" and threw.reason=="person-state-query-unavailable" and threw.personState==nil)
SAO.PersonState.query=ownerQuery
fresh();local bodyOwner=SAO.Body.get;SAO.Body.get=function()return nil end
local missingBody=choose().decisionPersonState
checkDecision("missing_body_explicit",missingBody.status=="unavailable" and missingBody.reason=="decision-body-unavailable" and missingBody.personState==nil)
SAO.Body.get=bodyOwner
fresh();missingMoodles=true
local unavailable=choose().decisionPersonState
checkDecision("actual_unavailable_view_retained",unavailable.status=="unavailable" and unavailable.reason=="moodles-unavailable"
    and unavailable.personState.status=="unavailable" and unavailable.personState.reason==unavailable.reason)
fresh();rec.brainHealth=nil
local noBrain=choose().decisionPersonState
checkDecision("unknown_brain_not_healthy",noBrain.status=="unavailable" and noBrain.personState.modelView.cognition.clarity==nil)
fresh();source.saveId="foreign-save"
local rebound=choose().decisionPersonState
checkDecision("foreign_memory_source_refused",rebound.personState.modelView.recall.status=="unavailable"
    and #rebound.personState.modelView.recall.episodes==0)
fresh();SAO.Body.foreign[rec.id]=body
local foreignBody=choose().decisionPersonState
checkDecision("foreign_body_custody_refused",foreignBody.status=="unavailable" and foreignBody.personState.modelView.body.status=="unavailable")
fresh();local ticksOwner=SAO.History.ticks;SAO.History.ticks=nil
checkDecision("legacy_missing_tick_omits",choose().decisionPersonState==nil)
SAO.History.ticks=ticksOwner
for _,badTick in ipairs({-1,.5,math.huge})do
    fresh();SAO.History.ticks=function()return badTick end
    checkDecision("invalid_tick_omits",choose().decisionPersonState==nil)
end
SAO.History.ticks=ticksOwner
fresh();SAO.PersonState.query=function(...)
    local value=ownerQuery(...);value.actorId="foreign";return value
end
local alien=choose().decisionPersonState
checkDecision("foreign_query_metadata_refused",alien.status=="unavailable" and alien.personState==nil and alien.reason=="person-state-binding-unavailable")
SAO.PersonState.query=ownerQuery
fresh();SAO.PersonState.query=function(...)
    local value=ownerQuery(...);value.modelView.atHours=1;return value
end
local wrongTime=choose().decisionPersonState
checkDecision("foreign_inner_clock_refused",wrongTime.status=="unavailable" and wrongTime.personState==nil)
SAO.PersonState.query=ownerQuery
fresh();SAO.PersonState.query=function(...)
    local value=ownerQuery(...);now=1;return value
end
local clockChanged=choose().decisionPersonState
checkDecision("clock_changed_during_query_refused",clockChanged.status=="unavailable" and clockChanged.reason=="decision-clock-changed" and clockChanged.personState==nil)
SAO.PersonState.query=ownerQuery
fresh();SAO.PersonState.query=function(...)
    local value=ownerQuery(...);value.audit.loop=value;return value
end
local cyclic=choose().decisionPersonState
checkDecision("cyclic_state_explicit_refusal",cyclic.status=="unavailable" and cyclic.reason=="person-state-copy-unavailable" and cyclic.personState==nil)
SAO.PersonState.query=ownerQuery
fresh()
for i=1,64 do
    local e=copy(source.episodes[1]);e.id="bounded-history-"..i;e.description=string.rep("x",1024)
    e.participants={};e.relations={}
    for j=1,16 do e.participants[j]=string.rep("person",18)..j
        e.relations[j]={from="reading",relation="supports",into="comfort"..j,confidence=.7} end
    source.episodes[i]=e
end
rec.personalMemory=nil
verify("large_history_source_attached",SAO.PersonalMemory.attachInitial(rec))
local large=choose().decisionPersonState
checkDecision("whole_bounded_owner_not_clipped",large.status=="available"
    and #large.personState.modelView.recall.episodes==64 and #large.personState.audit.retainedMemory.initial.episodes==64
    and #large.personState.modelView.recall.episodes[64].relations==16 and #large.personState.modelView.recall.episodes[64].participants==16)
checkDecision("compact_oversized_state_explicit_refusal",SAO.Cognition.snapshot(rec.id,false)==nil)
rec.cognition=__nativeRoundtrip(rec.cognition)
checkDecision("large_frozen_serialization",#SAO.Cognition.snapshot(rec.id,true).episodes[1].decisionPersonState.personState.modelView.recall.episodes==64)
fresh();local finalEpisode,finalSnapshot=choose()
checkDecision("producer_fixture_emitted",__emitPersonState({context={personState=ownerQuery(rec.id,body,SAO.History.ticks()),cognition=finalSnapshot}}))
__result="PASS decision person state: "..decisionChecks.." checks + "..checks.." owner checks"
