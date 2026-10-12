__fixture('single',true);__recoveryScene()
local id='furniture-person'
local r={id=id,name='controlled native person',dead=false}
SAO.Identity.records[id]=r;SAO.Body.active[id]=__body
SAO.Controller.agents[id]={rec=r,state='IDLE',criedHeard={},passive=false}
SAO.Cognition.configure(.5,12,3)
local ok,native=pcall(function()return SAOJavaBridge:furnitureObservation(__body,8)end)
print('PRIVATE_OBSERVATION_DIAGNOSTIC',ok,type(native),type(native)=='table' and native.actorId or tostring(native),__body:getModData().SAOPersonId,
 __body:isExistInTheWorld(),__body:isDead(),__body:isAsleep(),__body:getX(),__body:getY(),__body:getCurrentSquare():getX(),__body:getCurrentSquare():getY())
__case('private_native_observation',SAO.Perception.observeFurniture(id,__body))
local facts=SAO.Perception.furnitureFacts(id,__body)
__case('private_observation_actor_time',facts.actorId==id and facts.source=='native-personal-visibility' and facts.atHours==__hours)
local options=SAO.FurnitureWork.options(id,__body,'sleep','standing')
if #options==0 then
 print('OPTIONS_DIAGNOSTIC',#facts.squares,SAO.Needs.ownsRecoveryBody(id,__body),SAO.Needs.workAvailable(__body))
 for _,s in ipairs(facts.squares)do for _,o in ipairs(s.objects)do if o.bed or o.movable then print('OBSERVED_DIAGNOSTIC',s.x,s.y,s.free,o.sprite,o.bed,o.movable,o.recoverySource)end end end
end
__case('private_acquired_obstruction_destination_offer',#options>0)
local p,step,view=SAO.ProceduralPlanning.planFurnitureRecovery(id,{kind='sleep',fatigue=.65,options=options,recoveryPlaces={}})
__case('private_actual_interpreter_selects_relocation',p~=nil and step.owner=='SAO.FurnitureWork' and p.furnitureRelocation.uncertainBenefit==true)
local selected=p.furnitureRelocation.option
__position(selected.contact.x+.5,selected.contact.y+.5)
__case('private_current_purpose_begin',SAO.FurnitureWork.begin(id,__body,p,selected))
__case('private_ordinary_work_dispatch',SAO.FurnitureWork.tick(id,__body))
local q=ISTimedActionQueue.getTimedActionQueue(__body);local a=q.current
__case('private_native_queue_has_effort',a and a.Type=='SAOFurnitureRelocationAction' and a.phase=='effort')
__nativeAction(a);__hours=__hours+.001;__finish(a)
if selected.mode=='pull' then
 __case('private_effort_is_not_relocation',r.furnitureWork.resultSequence==nil and __objects[1]:getObjectIndex()~=-1)
 SAO.FurnitureWork.tick(id,__body);SAO.FurnitureWork.tick(id,__body)
 local job=SAO.Locomotion.jobs[id]
 __case('private_actual_loco_retreat_requested',job and not job.done and job.goal.x==selected.retreat.x and job.goal.y==selected.retreat.y)
 __case('private_unreached_retreat_has_no_effect',__objects[1]:getObjectIndex()~=-1 and r.furnitureWork.resultSequence==nil)
 __computedRoute(job.goal.x,job.goal.y)
 for i=1,200 do if job.done then break end;SAO.Locomotion.tick(id);__nativeFoot() end
 print('RETREAT_DIAGNOSTIC',job.done,job.result,job.lastVerdict,job.faults,__body:getX(),__body:getY(),selected.retreat.x,selected.retreat.y)
 __case('private_native_loco_retreat_arrived',job.done and job.result=='arrived' and __body:getCurrentSquare():getX()==selected.retreat.x and __body:getCurrentSquare():getY()==selected.retreat.y)
 SAO.FurnitureWork.tick(id,__body);a=q.current;__nativeAction(a);__finish(a)
end
local row=SAO.FurnitureWork.outcome(id,r.furnitureWork.resultSequence)
__case('private_exact_physical_canonical_result',row and row.status=='completed' and row.actorId==id and row.purposeId==p.id and row.nativeCompleted)
__case('private_physical_success_not_benefit',p.furnitureRelocation.uncertainBenefit and p.status~='completed')
local learned,learningReason=SAO.Cognition.furnitureOutcome(id,SAO.FurnitureWork.outcome(id,row.sequence))
print('MODEL_DIAGNOSTIC',learned,learningReason,SAO.Cognition.settings().enabled,row.nativeAttempted,row.sourceId,row.geometry.mode)
local event={id=row.id,actorId=id,observerId=id,worldHours=__hours,occurredAtHours=row.atHours,kind='furniture-relocation',category='body',
 perspective='performed',status='completed',sourceId=row.sourceId,actionKind=row.geometry.mode,succeeded=true,capabilities=SAO.Cognition.capabilities(id)}
for _,name in ipairs({'ordinary','associative'})do
 local diagnostic=SAO.CognitiveModels.newState(name)
 local good,answer=pcall(SAO.CognitiveModels.observe,name,diagnostic,event,3)
 print('MODEL_GUARD_DIAGNOSTIC',name,SAO.CognitiveModels.acceptsExperience(event),good,answer)
end
__case('private_physical_model_receipt',r.cognition and r.cognition.nativeExperienceCursors and r.cognition.nativeExperienceCursors['furniture-relocation']==row.sequence)
local before=r.cognition.models.ordinary.revision
__case('private_physical_learning_replay',SAO.Cognition.furnitureOutcome(id,SAO.FurnitureWork.outcome(id,row.sequence)))
__case('private_physical_replay_invariant',r.cognition.models.ordinary.revision==before)
local saved=__roundtrip(r);SAO.Identity.records[id]=saved;SAO.Controller.agents[id].rec=saved
SAO.FurnitureWork.reset('fixture-plain-reload');SAO.FurnitureWork.reconcile(id,__body);SAO.FurnitureWork.reconcile(id,__body)
__case('private_plain_save_terminal_no_new_result',saved.furnitureRelocation.nextResult==row.sequence and saved.cognition.models.ordinary.revision==before)
local live=SAO.ProceduralPlanning.furniturePurpose(id)
__case('private_retained_return_admission',SAO.FurnitureWork.returnForRecovery(id,__body,live))
SAO.FurnitureWork.tick(id,__body)
local returnJob=SAO.Locomotion.jobs[id]
__computedRoute(returnJob.goal.x,returnJob.goal.y,7,20,9,20)
for i=1,300 do if returnJob.done then break end;SAO.Locomotion.tick(id);__nativeFoot() end
__case('private_actual_return_arrived',returnJob.done and returnJob.result=='arrived')
SAO.FurnitureWork.tick(id,__body)
local oldBedKey=live.furnitureRelocation.expectedBed.key
local physicalOriginalBedKey=SAO.FurnitureWork.outcome(id,row.sequence).expectedBed.key
for _,variant in ipairs({'changed','missing','footprint','occluded','foreign'})do
 __reconstructBed((variant=='occluded' or variant=='foreign') and 'same' or variant)
 if variant=='occluded' then __position(7.5,18.5);__body:setForwardDirection(-1,0) end
 local belief=SAO.Perception.believesClaimed
 if variant=='foreign' then SAO.Perception.believesClaimed=function(_,x,y)if x==10 then return 'peaceful-foreign-holder' end end end
 local bound=SAO.FurnitureWork.rebindRecovery(id,__body,SAO.Needs.recoveryPlaces(id,__body))
 __case('private_reconstructed_'..variant..'_refused',not bound and live.furnitureRelocation.recoveryBindingUnavailable)
 __case('private_reconstructed_'..variant..'_no_benefit',live.furnitureRelocation.uncertainBenefit and live.status~='completed' and saved.furnitureRelocation.nextResult==row.sequence and not saved.furnitureRelocation.nextUse)
 SAO.Perception.believesClaimed=belief
 if variant=='occluded' then __position(9.5,21.5);__body:setForwardDirection(0,1) end
end
-- Reconstruct the saved native appearance, not the original native pointers.
-- The fixture's original grid/sprites are retained as scene constructor inputs.
__case('private_native_bed_reconstructed',__reconstructBed('same'))
local choices=SAO.Needs.recoveryPlaces(id,__body)
SAO.Controller.tryFurnitureRecovery(id,SAO.Controller.agents[id],__body,100,{fatigue=.65},'sleep',choices)
__case('private_reconstructed_source_bound',live.furnitureRelocation.expectedBed.key~=oldBedKey and not live.furnitureRelocation.recoveryBindingUnavailable)
__case('private_reconstructed_historical_source_preserved',SAO.FurnitureWork.outcome(id,row.sequence).expectedBed.key==physicalOriginalBedKey and live.furnitureRelocation.originalBedKey==oldBedKey and live.furnitureRelocation.bedBindings[1].persistentObjectIdentity==false)
local places=SAO.Needs.recoveryPlaces(id,__body);local place
for _,v in ipairs(places)do if v.kind=='bed' and v.key==live.furnitureRelocation.expectedBed.key then place=v end end
__case('private_fresh_native_bed_use_available',place~=nil)
local accepted,reason=SAO.Controller.admitRecoveryPlace(id,SAO.Controller.agents[id],__body,101,'sleep',place)
print('POSE_DIAGNOSTIC',accepted,reason)
__case('private_native_recovery_owner_begins',accepted)
__case('private_independent_recovery_admission',live.admission and live.admission.owner=='SAONeeds')
local entry=ISTimedActionQueue.getTimedActionQueue(__body).current
if __admissionResume then
 local admittedPurpose=live.id;local admittedPhysical=live.furnitureRelocation.resultId
 local admittedKey=live.furnitureRelocation.expectedBed.key;local admitted=__roundtrip(saved)
 __case('private_admitted_live_native_custody_preserved',not SAO.ProceduralPlanning.reconcileFurnitureRecovery(id,__body) and live.admission~=nil)
 __case('private_admitted_actual_interruption',SAO.Needs.stopRecovery(id,__body,'controlled-native-interruption'))
 __nativeStop(entry)
 SAO.Identity.records[id]=admitted;saved=admitted
 SAO.Controller.agents[id]={rec=saved,state='IDLE',criedHeard={},passive=false}
 live=SAO.ProceduralPlanning.furniturePurpose(id)
 __case('private_admitted_save_holds_uncertain_admission',live.admission and live.furnitureRelocation.uncertainBenefit and saved.recoveryIntent and not saved.furnitureRelocation.nextUse)
 local admission=live.admission;local correlation=admission.correlationId
 admission.correlationId='foreign-correlation'
 __case('private_admitted_foreign_admission_preserved',not SAO.ProceduralPlanning.reconcileFurnitureRecovery(id,__body) and live.admission==admission and saved.recoveryIntent~=nil)
 admission.correlationId=correlation
 local token=__body:getModData().SAOExternalToken;__body:getModData().SAOExternalToken='foreign-token'
 __case('private_admitted_foreign_body_preserved',not SAO.ProceduralPlanning.reconcileFurnitureRecovery(id,__body) and live.admission==admission and saved.recoveryIntent~=nil)
 __body:getModData().SAOExternalToken=token
 local foreign=ISWalkToTimedAction:new(__body,__body:getCurrentSquare());ISTimedActionQueue.add(foreign)
 local queue=ISTimedActionQueue.getTimedActionQueue(__body)
 __case('private_admitted_foreign_native_queue_preserved',not SAO.ProceduralPlanning.reconcileFurnitureRecovery(id,__body) and live.admission==admission and queue.current==foreign)
 -- Only the fixture scheduler retires this independent native action.
 __nativeStop(foreign)
 __reconstructBed('same')
 SAO.Controller.tryFurnitureRecovery(id,SAO.Controller.agents[id],__body,200,{fatigue=.65},'sleep',SAO.Needs.recoveryPlaces(id,__body))
 __case('private_admitted_reconciliation_releases_exact_work',live.admission==nil and saved.recoveryIntent==nil and live.id==admittedPurpose and live.furnitureRelocation.resultId==admittedPhysical and live.furnitureRelocation.uncertainBenefit)
 __case('private_admitted_reconstructed_binding_fresh',live.furnitureRelocation.expectedBed.key~=admittedKey and not live.furnitureRelocation.recoveryBindingUnavailable)
 local fresh
 for _,v in ipairs(SAO.Needs.recoveryPlaces(id,__body))do if v.kind=='bed' and v.key==live.furnitureRelocation.expectedBed.key then fresh=v end end
 __case('private_admitted_ordinary_readmission',fresh and SAO.Controller.admitRecoveryPlace(id,SAO.Controller.agents[id],__body,201,'sleep',fresh))
 __case('private_admitted_censored_use_unscored',saved.furnitureRelocation.nextResult==row.sequence and not saved.furnitureRelocation.nextUse and saved.cognition.nativeExperienceCursors['furniture-relocation']==row.sequence)
 entry=ISTimedActionQueue.getTimedActionQueue(__body).current
end
__case('private_actual_native_bed_event',__bedEvent(entry))
__nativeAction(entry);__finish(entry)
for i=1,4 do __animate();if SAO.Needs.pollRecovery(id,__body)=='running' then break end end
__case('private_native_pose_and_sleep',SAO.RecoveryPose.observed(__body,'sleep') and __body:isAsleep())
__case('private_native_independent_fatigue_reduction',__nativeSleep())
__hours=__hours+.1
__case('private_measured_benefit_closes_retained_purpose',SAO.Needs.pollRecovery(id,__body)=='completed' and live.status=='completed' and not live.furnitureRelocation.uncertainBenefit)
__case('private_separate_benefit_model_receipt',saved.furnitureRelocation.nextUse==1 and saved.cognition.nativeExperienceCursors['furniture-use']==1)
local use=SAO.FurnitureWork.useOutcome(id,1);local useRevision=saved.cognition.models.ordinary.revision
__case('private_separate_use_replay',SAO.Cognition.furnitureUseOutcome(id,use))
__case('private_use_replay_invariant',saved.cognition.models.ordinary.revision==useRevision)
local afterUse=__roundtrip(saved);SAO.Identity.records[id]=afterUse;SAO.Controller.agents[id].rec=afterUse
SAO.FurnitureWork.reset('after-reconstructed-benefit');SAO.FurnitureWork.reconcile(id,__body);SAO.FurnitureWork.reconcile(id,__body)
__case('private_reconstructed_benefit_save_replay',afterUse.furnitureRelocation.nextResult==row.sequence and afterUse.furnitureRelocation.nextUse==1 and afterUse.cognition.models.ordinary.revision==useRevision)
__projection('benefit',id)
if __admissionResume then return end
local function prepare(name,mode)
 SAO.FurnitureWork.reset('case-boundary');ISTimedActionQueue.queues[__body]=nil
 __fixture('single',true);__recoveryScene();__body:getModData().SAOPersonId=name
 local person={id=name,dead=false};SAO.Identity.records[name]=person;SAO.Body.active[name]=__body
 SAO.Controller.agents[name]={rec=person,state='IDLE',criedHeard={},passive=false}
 local offered=SAO.FurnitureWork.options(name,__body,'sleep','standing')
 if mode then local filtered={};for _,v in ipairs(offered)do if v.mode==mode then filtered[#filtered+1]=v end end;offered=filtered end
 local purpose,step=SAO.ProceduralPlanning.planFurnitureRecovery(name,{kind='sleep',fatigue=.65,options=offered,recoveryPlaces={}})
 local option=purpose.furnitureRelocation.option;__position(option.contact.x+.5,option.contact.y+.5)
 __case(name..'_purpose_and_native_begin',SAO.FurnitureWork.begin(name,__body,purpose,option))
 SAO.FurnitureWork.tick(name,__body)
 return person,purpose,option,ISTimedActionQueue.getTimedActionQueue(__body).current
end
for _,fault in ipairs({'actor','queue','parent','death','transfer','cancel','source'})do
 local name='refuse-'..fault;local person,purpose,option,action=prepare(name);__nativeAction(action)
 if fault=='actor' then __body:getModData().SAOExternalToken='foreign-token'
 elseif fault=='queue' then ISTimedActionQueue.queues[__body]=nil;ISTimedActionQueue.getTimedActionQueue(__body)
 elseif fault=='parent' then purpose.admission.correlationId='foreign-purpose'
 elseif fault=='death' then person.dead=true
 elseif fault=='transfer' then person.zaoTransferPending={}
 elseif fault=='cancel' then action:forceCancel()
 elseif fault=='source' then __objects[1]:getSquare():getObjects():remove(__objects[1]) end
 __finish(action)
 __case('private_'..fault..'_rejects_effort',not action._session.effortCompleted)
 __case('private_'..fault..'_no_completed_effect',not action._session.succeeded and (not person.furnitureWork.resultSequence or SAO.FurnitureWork.outcome(name,person.furnitureWork.resultSequence).status~='completed'))
 __body:getModData().SAOExternalToken=nil
 SAO.FurnitureWork.forget(name)
end
local person,purpose,option,action=prepare('saved-active')
local original=__objects[1]
local plain=__roundtrip(person);SAO.Identity.records['saved-active']=plain;SAO.Controller.agents['saved-active'].rec=plain
SAO.FurnitureWork.reset('runtime-lost');SAO.FurnitureWork.reconcile('saved-active',__body);SAO.FurnitureWork.reconcile('saved-active',__body)
__case('private_interrupted_save_no_effect',original:getObjectIndex()~=-1 and plain.furnitureWork.status=='interrupted')
print('INTERRUPTED_DIAGNOSTIC',plain.furnitureRelocation.nextResult,plain.furnitureWork.nativeAttempted,plain.cognition and plain.cognition.nativeExperienceCursors and plain.cognition.nativeExperienceCursors['furniture-relocation'])
__case('private_interrupted_save_once',plain.furnitureRelocation.nextResult==1 and (not plain.cognition or not plain.cognition.nativeExperienceCursors or not plain.cognition.nativeExperienceCursors['furniture-relocation']))
local eventBad=copyTable(event);eventBad.actorId='another-person'
__case('private_model_foreign_actor_rejected',not SAO.CognitiveModels.acceptsExperience(eventBad))
eventBad=copyTable(event);eventBad.sourceId='unowned-source'
__case('private_model_foreign_source_rejected',not SAO.CognitiveModels.acceptsExperience(eventBad))
eventBad=copyTable(event);eventBad.id='another-person/furniture-result/1'
__case('private_model_foreign_result_rejected',not SAO.CognitiveModels.acceptsExperience(eventBad))
