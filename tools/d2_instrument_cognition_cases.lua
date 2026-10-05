-- Actual C/M/Controller, controlled canonical Gesture receipt query. Native
-- Gesture execution is established by its separate owner proof.
local C,M=SAO.Cognition,SAO.CognitiveModels
local n=0
local function check(name,ok) assert(ok,'D2_INSTRUMENT:'..name);n=n+1;print('CASE '..name) end
local function clone(x) if type(x)~='table' then return x end local out={} for k,v in pairs(x) do out[k]=clone(v) end return out end
hours=12
records={a={id='a',skills={Cooking=2},recipeMastery={existing=0.25}},b={id='b'}}
SAO.Identity.get=function(id)return records[id]end
SAO.History.countyHours=function()return hours end
SAO.Labor={capabilityOf=function()return {canCook=false,canForage=false,canTreat=false}end}
local receipts={a={},b={}}
local calls=0
SAO.Gesture={instrumentOutcome=function(id,sequence)calls=calls+1;return receipts[id] and clone(receipts[id][sequence])end}
local function receipt(id,sequence)
 return {actorId=id,sequence=sequence,workId='instrument:'..id..':'..sequence,
 bodyGenerationKnown=true,bodyToken='private-body:'..id,verb='blow-harmonica',itemType='Base.Harmonica',itemId='42',
 status='completed',admittedAtHours=10,atHours=11,soundEmitted=true,worldSoundEmitted=true,
 soundHandle=1,startedAtHours=10,endedAtHours=11,soundEnded=true,cleanupPending=false}
end
local function put(id,sequence,value) receipts[id][sequence]=value or receipt(id,sequence) end
local function recreation(itemType,source)
 return {id='recreate',evidence=.5,continuity=.5,novelty=.5,informationGain=.5,blockers=0,utility=.4,
 consequences={{kind='recreate',category='leisure',sourceId=source or 'native:sound:BlowHarmonica',itemType=itemType or 'Base.Harmonica',value=1}}}
end
local idle={id='idle',evidence=.5,continuity=.5,novelty=.5,informationGain=.5,blockers=0,utility=.45}
local function choices(id,itemType,source)
 return C.interpretPlans(id,{recreation(itemType,source),idle},{actorId=id,atHours=hours})
end
check('configured',C.configure(.5,12,3))
local unknown=choices('a')
check('unmeasured_sound_remains_unknown',unknown and unknown.selected=='idle' and unknown.models[1].ranked[2].predictions[1].basis=='unknown')
put('a',1)
check('canonical_acquisition',C.instrumentOutcome('a',1))
local s=records.a.cognition
local e=s.experiences[1]
check('exact_item_source_verb',e.itemId==42 and e.itemType=='Base.Harmonica' and e.sourceId=='native:sound:BlowHarmonica' and e.actionKind=='blow-harmonica' and e.succeeded==true and e.occurredAtHours==11)
check('private_owner_queried',calls==1 and e.actorId=='a' and e.observerId=='a' and records.b.cognition==nil)
local successful=choices('a')
check('shared_sound_expectation_changes_choice',successful and successful.selected=='recreate' and successful.models[1].selected=='recreate' and successful.models[2].selected=='recreate')
check('foreign_item_stays_unknown',choices('a','Base.Guitar').selected=='idle')
check('forged_plan_source_refused',choices('a',nil,'native:sound:invented')==nil)
check('independent_models',s.models.ordinary~=s.models.associative and s.models.ordinary.beliefs~=s.models.associative.beliefs and s.models.ordinary.revision==1 and s.models.associative.revision==1)
local before=s.models.associative.revision
s.models.ordinary.__test=true
check('no_model_alias',s.models.associative.__test==nil and s.models.associative.revision==before)
s.models.ordinary.__test=nil
local snap=C.snapshot('a',true);snap.experiences[1].itemId=99
check('detached_snapshot',s.experiences[1].itemId==42)
local firstHour=e.worldHours
hours=13
local ok,why=C.instrumentOutcome('a',1)
check('duplicate_no_relearning',ok and why=='duplicate' and #s.experiences==1 and s.models.ordinary.revision==1 and s.experiences[1].worldHours==firstHour)
local fake=clone(e);fake.id='instrument/a/2';fake.worldHours=13
ok,why=C.experience('a',fake)
check('generic_authority_refused',not ok and why=='behavior-owner-required' and #s.experiences==1)
check('caller_payload_refused',not C.instrumentOutcome('a',receipt('a',2)))
check('absent_owner_refused',not C.instrumentOutcome('a',2))
for _,sequence in ipairs({0,-1,.5,math.huge}) do check('invalid_sequence_'..tostring(sequence),not C.instrumentOutcome('a',sequence)) end
local invalid={
 {'foreign_actor','actorId','b'}, {'foreign_sequence','sequence',3},
 {'future','atHours',14}, {'negative_date','atHours',-1},
 {'unknown_verb','verb','play-guitar'}, {'missing_body','bodyToken',''},
 {'missing_work','workId',''}, {'foreign_work','workId','instrument:b:2'},
 {'unknown_generation_flag','bodyGenerationKnown','yes'}, {'unknown_with_token','bodyGenerationKnown',false},
 {'missing_generation','bodyGenerationKnown',nil},
 {'missing_item_type','itemType',''},
 {'fractional_item','itemId','42.5'}, {'overflow_item','itemId','2147483648'},
 {'non_item','itemId','not-native-id'}, {'invalid_status','status','pending'},
 {'string_sound','soundEmitted','true'}, {'string_world_sound','worldSoundEmitted','true'},
 {'completed_without_sound','soundEmitted',false}, {'completed_without_world_sound','worldSoundEmitted',false},
 {'cleanup_pending','cleanupPending',true}, {'sound_not_ended','soundEnded',false},
 {'missing_cleanup_flag','cleanupPending',nil}, {'missing_ended_flag','soundEnded',nil},
 {'negative_sound_handle','soundHandle',-1}, {'missing_sound_handle','soundHandle',nil},
 {'future_sound_start','startedAtHours',12}, {'start_before_admission','startedAtHours',9},
 {'future_sound_end','endedAtHours',12}, {'end_before_start','endedAtHours',9},
 {'future_admission','admittedAtHours',12}}
for _,case in ipairs(invalid) do local r=receipt('a',2);r[case[2]]=case[3];put('a',2,r)
 check('refuses_'..case[1],not C.instrumentOutcome('a',2) and #s.experiences==1) end
local interrupted=receipt('a',2);interrupted.status='interrupted';interrupted.soundEmitted=false;interrupted.worldSoundEmitted=false
interrupted.soundHandle=nil;interrupted.startedAtHours=nil;interrupted.endedAtHours=nil;interrupted.soundEnded=false
put('a',2,interrupted)
check('interrupted_attempt_acquired',C.instrumentOutcome('a',2))
check('interrupted_not_performance',s.experiences[2].status=='completed' and s.experiences[2].succeeded==false and s.experiences[2].episodeId==nil)
local negative=false
for _,belief in pairs(s.models.ordinary.beliefs) do if belief.planKind=='recreate' then negative=belief.against>0 end end
check('failed_attempt_counterevidence',negative)
local revised=choices('a')
check('contrary_attempt_changes_choice',revised and revised.selected=='idle' and revised.models[1].selected=='idle' and revised.models[2].selected=='idle')
check('private_query_does_not_relearn',s.models.ordinary.revision==2 and s.models.associative.revision==2)
-- The Rosewood floor-asset run emitted real sound before interruption. Its
-- terminal owner refused completion; both models must retain counterevidence.
records.c={id='c'};receipts.c={}
local partial=receipt('c',1);partial.status='interrupted'
partial.soundEnded=false;partial.endedAtHours=nil
put('c',1,partial)
check('partial_sound_attempt_acquired',C.instrumentOutcome('c',1))
local partialState=records.c.cognition
check('partial_sound_not_success',partialState.experiences[1].succeeded==false
 and partialState.experiences[1].status=='completed')
local partialNegative=false
for _,belief in pairs(partialState.models.ordinary.beliefs) do
 if belief.planKind=='recreate' then partialNegative=belief.against>0 and belief.forWeight==nil end
end
check('partial_sound_counterevidence',partialNegative)
local partialRevision=partialState.models.ordinary.revision
local partialOk,partialWhy=C.instrumentOutcome('c',1)
check('partial_sound_duplicate_inert',partialOk and partialWhy=='duplicate'
 and partialState.models.ordinary.revision==partialRevision and #partialState.experiences==1)
-- inspect the measured plan prediction rather than an invented native completion.
local plan=C.interpretPlans('a',{{id='ordinary',evidence=.5,continuity=.5,novelty=.5,informationGain=.5,blockers=0,
 consequences={{kind='acquire',category='food',sourceId='held-food',itemType='Base.Apple',value=.5}}}},{actorId='a',atHours=hours})
check('legacy_plan_query_available',type(plan)=='table')
check('no_skill_or_assent_grant',records.a.skills.Cooking==2 and records.a.recipeMastery.existing==.25 and records.a.assent==nil and records.a.instrumentSkill==nil)
local fact=clone(e);fact.worldHours=13;fact.id='instrument/a/3'
check('valid_model_fact',M.acceptsExperience(fact))
for _,case in ipairs({{'wrong_category','category','food'},{'wrong_source','sourceId','native:sound:invented'},
 {'wrong_verb','actionKind','play-guitar'},{'unsupported_mastery','recipeMastery',1},
 {'fractional_item','itemId',42.5},
 {'unsupported_leisure','repertoire','mastered'},{'private_relief','hungerDelta',.1},
 {'irrelevant_stats','stats',{}},{'irrelevant_quantity','consumedAmount',1},
 {'foreign_observer','observerId','b'},{'wrong_status','status','interrupted'}}) do
 local f=clone(fact);f[case[2]]=case[3];check('model_refuses_'..case[1],not M.acceptsExperience(f)) end
local ordinary={id='legacy/a/1',actorId='a',observerId='a',worldHours=13,kind='acquire',category='food',perspective='performed',status='completed',itemType='Base.Apple'}
check('legacy_valid',M.acceptsExperience(ordinary) and C.experience('a',ordinary))
local bad=clone(ordinary);bad.category='leisure'
check('legacy_cannot_claim_leisure',not M.acceptsExperience(bad))
bad=clone(ordinary);bad.actionKind='blow-harmonica';bad.succeeded=true
check('legacy_cannot_gain_action_fields',not M.acceptsExperience(bad))
bad=clone(ordinary);bad.recipeMastery=3
check('legacy_cannot_gain_mastery',not M.acceptsExperience(bad))
local unknownBody=receipt('b',1);unknownBody.bodyGenerationKnown=false;unknownBody.bodyToken=nil;put('b',1,unknownBody)
check('second_actor_independent',C.instrumentOutcome('b',1) and #records.b.cognition.experiences==1 and records.b.cognition.models.ordinary.actorId=='b')
local foreign=clone(fact);foreign.actorId='b';foreign.observerId='b';foreign.id='instrument/b/2'
check('model_actor_separation',M.observe('ordinary',s.models.ordinary,foreign,3)=='rejected:foreign-observer')
records=__nativeRoundtrip(records);s=records.a.cognition
SAO.Identity.get=function(id)return records[id]end
check('native_roundtrip',s.experiences[1].itemId==42 and s.nativeExperienceCursors.instrument==2 and s.models.ordinary~=s.models.associative)
ok,why=C.instrumentOutcome('a',2)
check('reload_duplicate_inert',ok and why=='duplicate' and s.models.ordinary.revision==3)
for position=3,260 do put('a',position);check('eviction_receipt_'..position,C.instrumentOutcome('a',position)) end
local revision=s.models.ordinary.revision
ok,why=C.instrumentOutcome('a',1)
check('evicted_cursor_refuses_replay',not ok and why=='retired-native-receipt' and s.models.ordinary.revision==revision and #s.experiences==256)
local direct=M.newState('ordinary')
check('model_native_cursor',string.sub(M.observe('ordinary',direct,fact,3),1,8)=='revised:')
direct.seen[fact.id]=nil
check('model_cursor_refuses_replay',M.observe('ordinary',direct,fact,3)=='ignored:native-receipt')

-- Actual Controller rest function, only physical admission receiver controlled.
if SAO.Controller and SAO.Controller.__d2Rest then
local material={getFullType=function()return 'Base.Harmonica'end,getID=function()return 42 end}
local ownerCalls=0;local admitted=true
SAO.Needs.carriedInstrument=function(id,body)return material,{kind='harmonica',verb='blow-harmonica'}end
SAO.Needs.ownsRecoveryBody=function(id,body)return id=='a' and body==__d2Body end
SAO.Needs.workAvailable=function(body)return body==__d2Body end
SAO.Study=nil;SAO.Census={}
local purposeCalls=0;local purposeAllowed=true
SAO.ProceduralPlanning={planLeisure=function(id,offer)
 purposeCalls=purposeCalls+1
 check('controller_prequeue_purpose',ownerCalls==purposeCalls-1 and id=='a' and offer.activity=='blow-harmonica' and offer.nativeVerb=='blow-harmonica' and offer.itemKey=='42' and offer.affordance=='Base.Harmonica' and offer.locationKey=='1:2:0')
 return purposeAllowed and {id='private-leisure-purpose'} or nil
end}
SAO.Gesture.playInstrument=function(id,body,kind,fullType,item,purposeId)
 ownerCalls=ownerCalls+1
 check('controller_exact_carried_join',id=='a' and body==__d2Body and kind=='harmonica' and fullType=='Base.Harmonica' and item==material and purposeId=='private-leisure-purpose')
 return admitted
end
__d2Body={getX=function()return 1.5 end,getY=function()return 2.5 end,getZ=function()return 0 end}
local agent={rec=records.a}
check('controller_admission_not_completion',SAO.Controller.__d2Rest('a',agent,__d2Body,10,{}) and agent.pressure.phase=='preparing' and agent.pressure.owner=='SAO.Gesture' and agent.nextTuneAt==2410)
check('controller_cooldown_inert',not SAO.Controller.__d2Rest('a',agent,__d2Body,11,{}) and ownerCalls==1)
admitted=false;agent={rec=records.a}
check('controller_refusal_yields',not SAO.Controller.__d2Rest('a',agent,__d2Body,10,{}) and agent.pressure.phase=='refused' and agent.nextTuneAt==310)
purposeAllowed=false;agent={rec=records.a};local beforeCalls=ownerCalls
check('controller_purpose_refusal_blocks_native',not SAO.Controller.__d2Rest('a',agent,__d2Body,10,{}) and ownerCalls==beforeCalls)
check('controller_no_cognitive_completion',#records.a.cognition.experiences==256)
local reconciled=0
SAO.ProceduralPlanning.reconcileInstrument=function(id,reason)
 check('adoption_exact_actor',id=='a' and type(reason)=='string')
 reconciled=reconciled+1
end
SAO.Disposition.describe=function()return 'controlled person'end
SAO.Controller.agents.a=nil
check('adoption_reconciles_absent_owner',SAO.Controller.adopt(records.a) and reconciled==1)
check('existing_agent_does_not_reconcile',SAO.Controller.adopt(records.a) and reconciled==1)
end
__result='PASS D2 instrument cognition '..n
