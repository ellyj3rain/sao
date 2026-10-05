local P=SAO.ProceduralPlanning
local canonicalAppraisal=SAO.Cognition.appraiseConflict
SAO.Hash.unit=function()return .5 end
SAO.Conditions={bend=function()return 0 end}
ModData={get=function()return nil end}
local checks={}
local function check(name,ok)
 print('CHECK '..name..'='..tostring(ok==true));checks[#checks+1]=name
 if ok~=true then error('D2_REPAIR:'..name) end
end
local context={activity='blow-harmonica',nativeVerb='blow-harmonica',owner='SAO.Gesture',
 itemKey=tostring(__harmonica:getID()),affordance='Base.Harmonica',locationKey='observed-current',atLocation=true}
local rec=fresh();__hours=2
SAO.History.countyHours=function()return __hours end
SAO.Cognition={instrumentOutcome=function()end}
local function begin()
 local purpose=P.planLeisure('person',context)
 if not purpose then return nil end
 assert(SAO.Gesture.playInstrument('person',__body,'harmonica','Base.Harmonica',__harmonica,purpose.id),'native admission')
 local action=ISTimedActionQueue.queues[__body].queue[1]
 action:update();return purpose,action
end
local function complete(purpose,action)
 __hours=__hours+0.001;__emitter:finish();action:update()
 __hours=__hours+0.001;action:perform();__body:getCharacterActions():clear()
 return purpose.steps[2].status=='completed'
end
local first,action=begin();local firstId=first.id
check('delayed_native_perform_accepts_ordered_clock',complete(first,action)
 and SAO.Gesture.instrumentOutcome('person').endedAtHours<SAO.Gesture.instrumentOutcome('person').atHours)
local firstReceipt=first.resultReceipts[1]
local count=1
for i=2,15 do
 local purpose,owner=begin()
 check('routine_sound_capacity_accepts_more_than_twelve',purpose~=nil)
 assert(complete(purpose,owner),'authentic sound completion '..i);count=count+1
end
check('fifteen_authentic_completions_keep_active_bound',count==15 and #rec.proceduralPlanning.order==12)
local request=P.admitResourceOutcome('person',{id='urgent-food',revision=1,category='food',target=1,
 unit='usable-food-item',sourceDefinition=string.rep('a',64),issuer='actual-proof-operator'})
check('material_purpose_admits_after_solo_completions',request~=nil)
SAO.Cognition.appraiseConflict=function(id,frame,offers)
 return {frameId='private:capacity-proof',selected='withdraw',kind='withdraw',reason='privately appraised contact'}
end
local decision=P.planConflict('person',{atHours=__hours,threat={key='observed:proof'}},
 {{id='withdraw',kind='withdraw',available=true}})
check('conflict_purpose_admits_after_solo_completions',decision~=nil
 and P.conflictAdmission('person',decision.purposeId,{owner='Locomotion',id='owned-route'},'withdraw'))
local ledger=rec.proceduralPlanning.suspendedLeisure
local old=ledger and ledger.purposes[firstId]
check('suspension_keeps_unresolved_share_and_exact_receipt',old and old.status=='suspended'
 and old.steps[2].status=='completed' and old.steps[3].required==false
 and old.steps[3].status~='completed' and old.resultReceipts[1]==firstReceipt)
rec=__roundTrip(rec);__records.person=rec;SAO.Controller.agents.person.rec=rec
old=rec.proceduralPlanning.suspendedLeisure.purposes[firstId]
check('native_persistence_retains_optional_evidence',old and old.resultReceipts[1]==firstReceipt
 and old.lastAdmission.sequence==1 and old.steps[3].status~='completed')
local revived=P.maintain('person',{key=old.key,objective=old.objective})
check('same_key_revival_preserves_unresolved_participation',revived and revived.id==firstId
 and revived.status=='maintained' and revived.steps[2].status=='completed'
 and revived.steps[3].status~='completed' and revived.resultReceipts[1]==firstReceipt
 and rec.proceduralPlanning.suspendedLeisure.purposes[firstId]==nil)
local future,owner=begin()
check('old_receipt_cannot_advance_later_occurrence',future and P.consumeInstrumentOutcome('person',1)
 and future.steps[2].status~='completed' and future.admission.sequence==16)
assert(complete(future,owner),'future physical completion')
-- An explicitly required participation step and admitted native work remain live.
revived.steps[3].required=true
for i=17,50 do local purpose,nextAction=begin();assert(purpose and complete(purpose,nextAction),'bounded repetition') end
check('required_participation_is_not_optional_archive',rec.proceduralPlanning.purposes[firstId]==revived)
ledger=rec.proceduralPlanning.suspendedLeisure
check('suspended_history_is_bounded_with_explicit_omission',#ledger.order==32 and ledger.omitted>0
 and #rec.proceduralPlanning.order==12)
local snapshot=P.snapshot('person')
check('snapshot_exposes_suspended_not_completed',#snapshot.suspendedLeisure.purposes==32
 and snapshot.suspendedLeisure.omitted==ledger.omitted
 and snapshot.suspendedLeisure.purposes[1].status=='suspended')
rec=fresh();__hours=3
local abandoned,abandonedAction=begin();assert(complete(abandoned,abandonedAction))
abandoned.status='abandoned'
for i=1,12 do P.maintain('person',{key='other:'..i,objective='other private purpose'}) end
check('abandoned_share_is_not_revived_as_unresolved_intent',rec.proceduralPlanning.purposes[abandoned.id]==nil
 and not (rec.proceduralPlanning.suspendedLeisure and rec.proceduralPlanning.suspendedLeisure.purposes[abandoned.id]))
-- Genuine retained native terminals on reversed clocks must not advance intent.
local function invalidClock(kind)
 rec=fresh();__hours=3;local p,a=begin()
 local consume=P.consumeInstrumentOutcome;P.consumeInstrumentOutcome=function()return false end
 __hours=kind=='reversed-start' and 2.9 or 3.1;__emitter:finish();a:update()
 __hours=kind=='end-after-terminal' and 3.05 or 3.2;a:perform();__body:getCharacterActions():clear()
 P.consumeInstrumentOutcome=consume
 if kind=='future-terminal' then __hours=3.15 end
 return not P.consumeInstrumentOutcome('person',1) and p.steps[2].status~='completed'
end
check('reversed_native_start_end_is_rejected',invalidClock('reversed-start'))
check('native_end_after_terminal_is_rejected',invalidClock('end-after-terminal'))
check('future_native_terminal_is_rejected',invalidClock('future-terminal'))
-- Required authored outcomes use the same active planner capacity; an actual
-- canonical appraisal may suspend unadmitted execution, never the obligation.
rec=fresh();__hours=4
SAO.Cognition.appraiseConflict=canonicalAppraisal
local requests={};local firstRequired
local function fillRequired()
 for i=1,12 do
  local spec={id='authored-food-'..i,revision=1,category='food',target=1,unit='usable-food-item',
    sourceDefinition=string.rep('a',64),issuer='actual-proof-operator'}
  local purpose=P.admitResourceOutcome('person',spec);assert(purpose,'required native API')
  requests[i]=spec;firstRequired=firstRequired or purpose
 end
end
fillRequired()
check('generic_conflict_label_cannot_suspend_obligations',P.maintain('person',{key='forged-conflict',domain='conflict',objective='invented threat'})==nil
 and rec.proceduralPlanning.queuedPurposes==nil)
local frame={actorId='person',atHours=__hours,threat={kind='zombie',key='seen:z1',distance=2,count=1,source='observed',at=100},
 values=SAO.Disposition.conflictValues('person'),fear=.5,overwhelmed=false,escapeBlocked=true}
local offers={{id='defend',kind='defend',available=true,reason='controlled native shove offer',effects={'create-space'},objections={},nativeMode='shove',targetKey='seen:z1'}}
frame.actorId='foreign'
check('foreign_conflict_frame_cannot_suspend_obligations',P.planConflict('person',frame,offers)==nil and rec.proceduralPlanning.queuedPurposes==nil)
frame.actorId='person';frame.atHours=__hours+1
check('future_conflict_frame_cannot_suspend_obligations',P.planConflict('person',frame,offers)==nil and rec.proceduralPlanning.queuedPurposes==nil)
frame.atHours=__hours
local actual=P.planConflict('person',frame,offers)
check('canonical_defense_admits_over_required_capacity',actual and actual.kind=='defend'
 and P.conflictAdmission('person',actual.purposeId,{owner='SAO.Combat',id='current-native-attempt'},'defend'))
local queued=rec.proceduralPlanning.queuedPurposes
local queuedId=queued.order[1];local required=queued.purposes[queuedId]
check('queued_obligation_retains_authority_and_identity',required.id==firstRequired.id
 and required.resourceOutcome.revision==1 and required.resourceOutcome.issuer=='actual-proof-operator'
 and rec.proceduralPlanning.resourceOutcomeRequests['authored-food-1'].purposeId==required.id
 and rec.proceduralPlanning.resourceOutcomeRequests['authored-food-1'].retired==nil)
local detached=P.queuedPurpose('person');detached.domain='foreign'
check('queued_reader_is_detached',required.domain~='foreign' and P.queuedPurpose('person').id==required.id)
assert(P.conflictResult('person',actual.purposeId,{owner='SAO.Combat',id='current-native-attempt'},
 {status='cancelled',reason='native attempt handed back'}),'native handback')
local conflictKey=actual.purposeId
rec=__roundTrip(rec);__records.person=rec;SAO.Controller.agents.person.rec=rec
local resumed=P.resumeQueuedPurpose('person')
check('queued_obligation_resumes_after_native_persistence',resumed and resumed.id==queuedId
 and resumed.status=='maintained' and resumed.resourceOutcome.revision==1
 and resumed.resourceOutcome.issuer=='actual-proof-operator')
local retainedConflict=rec.proceduralPlanning.queuedPurposes.purposes[conflictKey]
check('ordinary_resume_preserves_conflict_identity_history',retainedConflict and retainedConflict.conflict.lastOutcome.status=='cancelled'
 and retainedConflict.conflict.lastOutcome.id=='current-native-attempt' and P.queuedPurpose('person')==nil)
local same=P.admitResourceOutcome('person',requests[1])
check('same_resource_revision_keeps_exact_revived_obligation',same==resumed)
check('restored_obligation_reenters_actual_resource_demand',P.resourceOutcomeDemand('person')==resumed)
local deadline=__hours+0.1
resumed.resourceOutcome.deadlineAt=deadline
__hours=deadline
check('restored_obligation_keeps_deadline_owner',P.resourceOutcomeDemand('person')~=resumed
 and resumed.status=='abandoned' and resumed.resolution=='deadline-expired')
frame.atHours=__hours
local renewed=P.planConflict('person',frame,offers)
check('new_conflict_reactivates_same_retained_identity',renewed and renewed.purposeId==conflictKey
 and rec.proceduralPlanning.purposes[conflictKey].conflict.lastOutcome.id=='current-native-attempt')
rec=fresh();firstRequired=nil;fillRequired()
local expiredDecision=P.planConflict('person',frame,offers);assert(expiredDecision)
firstRequired.resourceOutcome.deadlineAt=__hours-0.1
local expired=P.resumeQueuedPurpose('person')
check('expired_queued_obligation_uses_canonical_deadline_retirement',expired==firstRequired
 and expired.status=='abandoned' and expired.resolution=='deadline-expired'
 and P.resourceDemand('person','food')~=expired)
-- Controlled retained admission rows isolate the all-owned handback boundary.
rec=fresh();firstRequired=nil;fillRequired()
for _,id in ipairs(rec.proceduralPlanning.order) do
 rec.proceduralPlanning.purposes[id].admission={owner='WorldSources',correlationId='retained:'..id}
end
local blocked,why=P.planConflict('person',frame,offers)
check('all_native_admissions_require_owner_handback',blocked==nil and why=='conflict-native-handback-required'
 and rec.proceduralPlanning.queuedPurposes==nil)
print('D2_REPAIR_NATIVE_DONE')
