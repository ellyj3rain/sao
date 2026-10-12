SAO.Cognition.configure(.5,12,3)
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
local function physicalReady(person,option,action)
 __nativeAction(action);__finish(action)
 if option.mode=='pull' then
  SAO.FurnitureWork.tick(person.id,__body);SAO.FurnitureWork.tick(person.id,__body)
  local job=SAO.Locomotion.jobs[person.id];__computedRoute(job.goal.x,job.goal.y)
  for i=1,200 do if job.done then break end;SAO.Locomotion.tick(person.id);__nativeFoot()end
  SAO.FurnitureWork.tick(person.id,__body)
  action=ISTimedActionQueue.getTimedActionQueue(__body).current
  print('SECOND_RETREAT_DIAGNOSTIC',person.id,job.done,job.result,__body:getX(),__body:getY(),option.retreat.x,option.retreat.y,person.furnitureWork.status,SAO.FurnitureWork.outcome(person.id,person.furnitureWork.resultSequence) and SAO.FurnitureWork.outcome(person.id,person.furnitureWork.resultSequence).reason,__body:isAsleep(),__body:isOnBed(),SAOJavaBridge:hasPendingActions(__body),action)
 end
 return action
end
-- Actual failed pickup remains a contrary physical observation, with no relief.
local failed,failedPurpose,failedOption,failedAction=prepare('contrary-native')
failedAction=physicalReady(failed,failedOption,failedAction)
local original=__objects[1];local oldPickup=ISMoveableSpriteProps.pickUpMoveableInternal
ISMoveableSpriteProps.pickUpMoveableInternal=function()error('controlled-native-pickup-refusal')end
__nativeAction(failedAction);__hours=__hours+.001;__finish(failedAction)
ISMoveableSpriteProps.pickUpMoveableInternal=oldPickup
local failure=SAO.FurnitureWork.outcome(failed.id,failed.furnitureWork.resultSequence)
__case('private_contrary_actual_native_attempt',failure and failure.nativeAttempted and not failure.nativeCompleted and original:getObjectIndex()~=-1)
__case('private_contrary_model_retained',failed.cognition.nativeExperienceCursors['furniture-relocation']==failure.sequence)
local candidate={id='same-private-expectation',evidence=.8,continuity=.7,novelty=.2,informationGain=.4,utility=1,blockers=0,
 consequences={{kind='relocate',category='body',sourceId=failure.sourceId,value=1}}}
local context={actorId=failed.id,atHours=__hours,pressure=.65}
local prediction=SAO.CognitiveModels.planPrediction('ordinary',candidate,failed.cognition.models.ordinary,context)
local neutral=SAO.CognitiveModels.newState('ordinary')
local unknown=SAO.CognitiveModels.planPrediction('ordinary',candidate,neutral,context)
__case('private_contrary_individual_prediction_differs',prediction and unknown and prediction.predictions[1].probability<unknown.predictions[1].probability)
__projection('contrary',failed.id)
__case('private_contrary_no_recovery_benefit',not failed.furnitureRelocation.nextUse and failedPurpose.furnitureRelocation.uncertainBenefit)

-- A later native bed refusal is separate from the earlier real physical success.
local recipient,recipientPurpose,recipientOption,recipientAction=prepare('later-use')
recipientAction=physicalReady(recipient,recipientOption,recipientAction)
__nativeAction(recipientAction);__hours=__hours+.001;__finish(recipientAction)
__case('private_later_use_physical_completed',recipient.furnitureWork.status=='completed')
-- Reinsert the exact moved object at the newly cleared approach at this fixture boundary.
local obstruction=recipientAction._session.binding.members[1].placed
obstruction:getSquare():getObjects():remove(obstruction)
local square=__cell:getGridSquare(recipientOption.source.x,recipientOption.source.y,recipientOption.source.z)
obstruction:setSquare(square);square:getObjects():add(obstruction);square:RecalcProperties()
SAO.Needs.recoveryPlaces(recipient.id,__body)
local access=SAO.FurnitureWork.useOutcome(recipient.id,1)
__case('private_native_later_consumer_refusal',access and access.origin=='means' and access.actionKind=='geometry' and not access.succeeded)
__case('private_access_refusal_not_physical_reversal',SAO.FurnitureWork.outcome(recipient.id,1).nativeCompleted and recipientPurpose.furnitureRelocation.uncertainBenefit)
local revision=recipient.cognition.models.ordinary.revision
local floor=recipient.furnitureRelocation.useSequenceFloor.means
-- Eviction of a bounded receipt cannot reopen a consumed native owner sequence.
recipient.furnitureRelocation.useResults={};recipient.furnitureRelocation.useOrder={};recipient.furnitureRelocation.seenUse={}
__case('private_evicted_use_receipt_replay_admitted',SAO.FurnitureWork.consumeUse(recipient.id,'means',floor))
__case('private_evicted_use_replay_invariant',recipient.furnitureRelocation.nextUse==1 and recipient.cognition.models.ordinary.revision==revision)
local restored=__roundtrip(recipient);SAO.Identity.records[recipient.id]=restored
SAO.FurnitureWork.reconcile(recipient.id,__body);SAO.FurnitureWork.reconcile(recipient.id,__body)
__case('private_use_plain_save_replay_invariant',restored.furnitureRelocation.nextUse==1 and restored.furnitureRelocation.useSequenceFloor.means==floor and restored.cognition.models.ordinary.revision==revision)

-- Controlled private beliefs/relationships call the actual Standing owner.
local S=SAO.Standing;local inside,group,feud,hostile,belief=S.insideClaim,S.groupOf,S.feudBetween,S.isHostileTo,SAO.Perception.believesClaimed
local holder=nil;local same=false;local war=false;local hostility=false
S.insideClaim=function()return false end;SAO.Perception.believesClaimed=function()return holder end
S.groupOf=function(who)return same and 'shared-group' or who..'-group'end
S.feudBetween=function()return war end;S.isHostileTo=function()return hostility end
__case('private_standing_unknown_admitted',S.mayRelocateBelieved('actor',1,1,'standing'))
holder='actor';__case('private_standing_own_admitted',S.mayRelocateBelieved('actor',1,1,'standing'))
holder='other';__case('private_standing_other_peaceful_refused',not S.mayRelocateBelieved('actor',1,1,'standing'))
same=true;__case('private_standing_group_admitted',S.mayRelocateBelieved('actor',1,1,'standing'));same=false
war=true;__case('private_standing_feud_admitted',S.mayRelocateBelieved('actor',1,1,'standing'));war=false
hostility=true;__case('private_standing_hostility_admitted',S.mayRelocateBelieved('actor',1,1,'standing'));hostility=false
__case('private_standing_desperate_admitted',S.mayRelocateBelieved('actor',1,1,'desperate'))
S.insideClaim=function()return true end;__case('private_standing_claim_admitted',S.mayRelocateBelieved('actor',1,1,'standing'))
local pact=S.pactBetween;S.insideClaim=function()return false end;S.pactBetween=function()return true end
__case('private_standing_pact_passage_preserved',S.mayEnterBelieved('actor',1,1))
__case('private_standing_pact_not_alteration',not S.mayRelocateBelieved('actor',1,1,'standing'))
S.pactBetween=pact
S.insideClaim=inside;S.groupOf=group;S.feudBetween=feud;S.isHostileTo=hostile;SAO.Perception.believesClaimed=belief
__projection('access',recipient.id)

SAO.FurnitureWork.reset('ordinary-case-boundary');ISTimedActionQueue.queues[__body]=nil
__fixture('single',true);__recoveryScene();local ordinary='ordinary-owned-consumer';__body:getModData().SAOPersonId=ordinary
local ordinaryRec={id=ordinary,dead=false};SAO.Identity.records[ordinary]=ordinaryRec;SAO.Body.active[ordinary]=__body
local ordinaryAgent={rec=ordinaryRec,state='IDLE',criedHeard={},passive=false};SAO.Controller.agents[ordinary]=ordinaryAgent
__case('private_actual_controller_furniture_consumer',SAO.Controller.tryFurnitureRecovery(ordinary,ordinaryAgent,__body,1,{fatigue=.65},'sleep',{}))
local ordinaryPurpose,ordinaryStep=SAO.ProceduralPlanning.furniturePurpose(ordinary)
__case('private_actual_controller_owned_dispatch',ordinaryAgent.state=='FURNITURE' and ordinaryPurpose and ordinaryPurpose.admission.owner=='SAO.FurnitureWork' and ordinaryStep.owner=='SAO.FurnitureWork')
__case('private_actual_controller_not_effect',ordinaryRec.furnitureWork.status=='approaching' and __objects[1]:getObjectIndex()~=-1)

-- Passage over the exact contact/retreat is independent of alteration.
SAO.FurnitureWork.reset('passage-offer-boundary');ISTimedActionQueue.queues[__body]=nil
__fixture('single',true);__recoveryScene();local pid='passage-offers';__body:getModData().SAOPersonId=pid
local pr={id=pid,dead=false};SAO.Identity.records[pid]=pr;SAO.Body.active[pid]=__body
SAO.Controller.agents[pid]={rec=pr,state='IDLE',criedHeard={},passive=false}
local open=__cell:getGridSquare(9,22,0)
for i=open:getObjects():size()-1,0,-1 do local object=open:getObjects():get(i);if object:getProperties():has(IsoFlagType.solidtrans) then open:getObjects():remove(object)end end
open:RecalcProperties()
local function find(offered,mode,x,y)
 for _,o in ipairs(offered)do if o.mode==mode and o.destination.x==x and o.destination.y==y then return o end end
end
local available=SAO.FurnitureWork.options(pid,__body,'sleep','standing')
local push=find(available,'push',9,20);local pull=find(available,'pull',8,21)
__case('private_passage_native_push_pull_offered',push~=nil and pull~=nil)
local believes=SAO.Perception.believesClaimed;local denied
SAO.Perception.believesClaimed=function(_,x,y)if denied and x==denied.x and y==denied.y then return 'peaceful-foreign-holder'end end
denied=push.contact
__case('private_push_contact_passage_refused',find(SAO.FurnitureWork.options(pid,__body,'sleep','standing'),'push',9,20)==nil)
denied=pull.retreat
__case('private_pull_retreat_passage_refused',find(SAO.FurnitureWork.options(pid,__body,'sleep','standing'),'pull',8,21)==nil)
denied=nil
local stalePurpose=SAO.ProceduralPlanning.planFurnitureRecovery(pid,{kind='sleep',fatigue=.65,options={pull},recoveryPlaces={}})
__position(pull.contact.x+.5,pull.contact.y+.5);denied=pull.retreat
__case('private_stale_offer_begin_passage_refused',not SAO.FurnitureWork.begin(pid,__body,stalePurpose,pull))
SAO.Perception.believesClaimed=believes
local withdrawal,wp,wo,wa=prepare('passage-withdrawal')
__nativeAction(wa);__finish(wa)
__case('private_passage_effort_completed_first',wa._session.effortCompleted==true and __objects[1]:getObjectIndex()~=-1)
SAO.Perception.believesClaimed=function(_,x,y)if x==wo.retreat.x and y==wo.retreat.y then return 'peaceful-foreign-holder'end end
local foreign={Type='declared-foreign-successor'};local queue=ISTimedActionQueue.getTimedActionQueue(__body);queue.current=foreign;queue.queue={foreign}
local foreignJob={body=__body,goal={x=15,y=20,z=0},done=false};SAO.Locomotion.jobs[withdrawal.id]=foreignJob
SAO.FurnitureWork.tick(withdrawal.id,__body)
__case('private_passage_withdrawal_no_effect',wa._session.cancelled and __objects[1]:getObjectIndex()~=-1 and not wa._session.binding.spent)
__case('private_passage_withdrawal_foreign_custody',queue.current==foreign and queue.queue[1]==foreign and SAO.Locomotion.jobs[withdrawal.id]==foreignJob and not foreignJob.done)
SAO.Perception.believesClaimed=believes
