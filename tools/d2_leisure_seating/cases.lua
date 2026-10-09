local checks=0
local function check(name,yes)assert(yes,'SEATING:'..name);checks=checks+1;print('CASE '..name)end
local function fresh()
 if SAO.LeisureSeating.reset then SAO.LeisureSeating.reset('fixture reset')end
 __ms=1000000;__busy=false;__denied=false;__routeRefuse=false;__queueRefuse=false;__hidden=false;__offerUnavailable=false
 __records={person={id='person',bodyOwner='SAO',bodyOwnerToken='native-body-1'},other={id='other',bodyOwner='SAO',bodyOwnerToken='native-body-2'}}
 __bodies={person=__body,other=__other}
 for _,pair in ipairs({{__body,'person'},{__other,'other'}})do
  local body=pair[1];__exitSeating(body);body:getModData().SAOPersonId=pair[2];body:getModData().SAOExternalToken=__records[pair[2]].bodyOwnerToken
  body:setAsleep(false);body:setPrimaryHandItem(nil);body:setSecondaryHandItem(nil)
  body:setSitOnFurnitureObject(nil);body:clearVariable('SitOnFurnitureStarted');body:clearVariable('SitOnFurnitureDirection')
  body:getActionContext():clearActionContextEvents()
  ISTimedActionQueue.queues[body]=nil
 end
 __seat:setSatChair(false);__body:setX(10.5);__body:setY(20.5);__settleFacing(__body)
 SAO.Locomotion.jobs={}
 __objects={piano=__piano,pair=__pair,seat=__seat}
 __observations={{key='piano',concept='piano',actorId='person',kind='object',source='native-personal-visibility',runtimeInstance='piano-1',spriteName=__piano:getSpriteName()},
  {key='pair',concept='piano',actorId='person',kind='object',source='native-personal-visibility',runtimeInstance='pair-1',spriteName=__pair:getSpriteName()},
  {key='seat',concept='seat',actorId='person',kind='object',source='native-personal-visibility',runtimeInstance='seat-1',spriteName=__seat:getSpriteName()}}
 __offer={id='piano:fixture',activity='practice-instrument',sourceId='Lifestyle:PlayInstrumentTraining',revision='fixture-source-1',itemKey='piano',instrumentType='Piano',
  objectKey='piano',pairObjectKey='pair',objectSpriteName=__piano:getSpriteName(),pairSpriteName=__pair:getSpriteName(),
  objectObservation=__observations[1],pairObservation=__observations[2],sourceOffset={x=.1,y=.1},requiresPreparation={sitFurniture=true,faceObject=true,adjacentObject=true}}
 local purpose={id='purpose-1',domain='leisure',status='maintained',affordance=__offer.sourceId,revision=1,
  leisure={activityKey=__offer.id,activity=__offer.activity,itemKey=__offer.itemKey},
  steps={{id='perform-activity',owner='SAO.LeisureMusic',target=__offer.activity,token='leisure:performed',status='available'}}}
 __records.person.proceduralPlanning={schema=1,purposes={['purpose-1']=purpose},order={'purpose-1'},spatial={},spatialOrder={},practice={}}
 return purpose
end
local function begin()
 local purpose=fresh()
 local accepted,ready=SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1')
 check('canonical_begin',accepted and not ready)
 local route=SAO.Locomotion.jobs.person
 if route then
  __body:setX(route.x);__body:setY(route.y);route.done=true;route.result='arrived'
  check('actual_native_adjacent_arrival',SAO.LeisureSeating.advance('person',__body))
 end
 return __action,purpose
end
local function start(a)
 for i=1,5 do a.action:waitToStart();__settleFacing(__body)end
 check('native_source_started',a.action:isStarted() and __body:getSitOnFurnitureObject()==__seat)
end
local function sourceEnd(a)
 a.action:update();a.action:perform();a.action:complete()
end
local function nativePose()
 check('original_source_requested_furniture_event',__body:getActionContext():hasEventOccurred('EventSitOnFurniture'))
 __enterSeating(__body)
 __settleFacing(__body)
 check('actual_native_seating_state',__body:isSittingOnFurniture())
 __sitAnimationEnd(__body)
 __settleFacing(__body)
end
check('actual_installed_seating_data',SeatingManager.getInstance():getTilePositionCount(__seat)>0)
check('rest_source_audited',SAOJavaBridge:nativeLeisureActionSource('ISRestAction').sha256=='dcd87cadfeb028770795a9a745ca8c2f4a866baf28c202a7ae654ad98bc92444')
check('rest_unknown_source_path_refused',SAOJavaBridge:nativeLeisureActionSource('../ISRestAction')==nil and SAOJavaBridge:nativeLeisureActionSource('unknown')==nil)
check('actual_rest_source_tamper_refused',__tamperRestRejected())
local a,p=begin()
check('queued_not_seated',not __body:isSittingOnFurniture())
a:perform();check('premature_perform_refused',ISTimedActionQueue.hasAction(a))
check('premature_complete_refused',a:complete()==false)
start(a);sourceEnd(a)
check('source_force_complete_not_pose',not __body:isSittingOnFurniture() and SAO.LeisureSeating.advance('person',__body) and __records.person.leisureSeating.status=='preparing')
check('original_source_requested_furniture_event',__body:getActionContext():hasEventOccurred('EventSitOnFurniture'))
__enterSeating(__body);__settleFacing(__body)
check('state_entry_without_animation_end_not_success',SAO.LeisureSeating.advance('person',__body) and __records.person.leisureSeating.status=='preparing')
__sitAnimationEnd(__body);__settleFacing(__body)
for i=1,3 do SAO.LeisureSeating.advance('person',__body);__settleFacing(__body)end
check('source_pose_and_facing_complete',__records.person.leisureSeating.status=='completed' and __body:isFacingObject(__piano,.8))
check('no_hobby_completion_or_XP',p.status=='maintained' and p.steps[1].status=='available' and not p.admission and __xpWrites==0)
check('private_source_environment',ISRestAction==nil)
a=begin();start(a);sourceEnd(a);nativePose();SAO.LeisureSeating.advance('person',__body);local status=__records.person.leisureSeating.status;a:complete();a:perform()
check('duplicate_callbacks_do_not_recredit',__records.person.leisureSeating.status==status)
a=begin();start(a);sourceEnd(a);__ms=1015001;SAO.LeisureSeating.advance('person',__body)
check('pending_pose_timeout',__records.person.leisureSeating.status=='interrupted' and not __body:isSittingOnFurniture())
a=begin();__ms=999999;a.action:waitToStart()
check('regressed_clock_no_source_event',not __body:getActionContext():hasEventOccurred('EventSitOnFurniture'))
SAO.LeisureSeating.advance('person',__body)
check('regressed_clock_no_completion',__records.person.leisureSeating.status=='interrupted')
fresh();__hidden=true
check('hidden_seat_cannot_be_discovered',not SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1'))
fresh();table.remove(__observations,3)
check('unobserved_seat_refused',not SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1'))
fresh();__observations[3].actorId='other'
check('foreign_observation_refused',not SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1'))
fresh();__offer.objectObservation={runtimeInstance='spoof'}
check('forged_piano_generation_refused',not SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1'))
fresh();check('foreign_body_refused',not SAO.LeisureSeating.begin('person',__other,'SAO.LeisureMusic',__offer,'purpose-1'))
fresh();__seat:setSatChair(true);__other:setSitOnFurnitureObject(__seat);__occupySeat(__other)
check('occupied_native_seat_refused',__seat:isFurnitureOccupied(__body) and not SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1'))
a,p=begin();start(a);p.status='abandoned';sourceEnd(a);SAO.LeisureSeating.advance('person',__body)
check('retired_purpose_no_completion',__records.person.leisureSeating.status=='interrupted' and p.status=='abandoned' and not __body:isSittingOnFurniture())
a=begin();start(a);__body:getModData().SAOExternalToken='new-body';__records.person.bodyOwnerToken='new-body';sourceEnd(a);SAO.LeisureSeating.advance('person',__body)
check('same_body_token_replacement_refused',__records.person.leisureSeating.status=='interrupted' and not __body:isSittingOnFurniture())
a=begin();start(a);__objects.seat=__replacementSeat;sourceEnd(a);SAO.LeisureSeating.advance('person',__body)
check('native_seat_replacement_refused',__records.person.leisureSeating.status=='interrupted')
a=begin();start(a);__observations[3].runtimeInstance='seat-2';sourceEnd(a);SAO.LeisureSeating.advance('person',__body)
check('seat_observation_generation_replaced',__records.person.leisureSeating.status=='interrupted')
a=begin();start(a);__hidden=true;sourceEnd(a);SAO.LeisureSeating.advance('person',__body)
check('lost_visibility_refused',__records.person.leisureSeating.status=='interrupted')
a=begin();start(a);__reloadSeating();sourceEnd(a)
check('reload_has_no_pose_completion',__records.person.leisureSeating.status=='interrupted' and not __body:isSittingOnFurniture())
a=begin();start(a)
local follower={character=__body,begin=function()end,isValidStart=function()return true end,isStarted=function()return false end,forceCancel=function()__followerCancelled=true end}
local q=ISTimedActionQueue.getTimedActionQueue(__body);table.insert(q.queue,follower);__followerCancelled=false
SAO.LeisureSeating.interrupt('person',__body,'urgent need')
check('stop_preserves_unrelated_queue',#q.queue==1 and q.queue[1]==follower and not __followerCancelled)
check('stop_clears_native_pending_reservation',__body:getSitOnFurnitureObject()==nil and not __body:isSittingOnFurniture())
a=begin();start(a);check('foreign_interrupt_refused',not SAO.LeisureSeating.interrupt('person',__other,'foreign') and __records.person.leisureSeating.status=='preparing')
SAO.LeisureSeating.interrupt('person',__body,'cleanup')
fresh();__body:setX(13.5)
check('route_admitted',SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1'))
local route=SAO.Locomotion.jobs.person;check('native_manager_exact_route',route and route.x~=13.5)
route.done=true;route.result='arrived';SAO.LeisureSeating.advance('person',__body)
check('arrival_without_actual_position_refused',__records.person.leisureSeating.status=='interrupted')
fresh();__body:setX(13.5);SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1');SAO.Locomotion.jobs.person={done=true,result='arrived'};SAO.LeisureSeating.advance('person',__body)
check('foreign_route_receipt_refused',__records.person.leisureSeating.status=='interrupted')
fresh();__queueRefuse=true
local accepted=SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1')
local route=SAO.Locomotion.jobs.person;if route then __body:setX(route.x);__body:setY(route.y);route.done=true;route.result='arrived';SAO.LeisureSeating.advance('person',__body)end
check('queue_refusal_no_pose',__records.person.leisureSeating.status=='interrupted' and not __body:isSittingOnFurniture())
check('no_operator_clock_or_XP',__clockWrites==0 and __xpWrites==0)
fresh();__body:setX(13.5);SAO.LeisureSeating.begin('person',__body,'SAO.LeisureMusic',__offer,'purpose-1')
local restorePump=__installRoutePumpFixture(__body)
local held=SAO.LeisureSeating.advance('person',__body)
check('production_route_tick_reaches_seating',held and __pumpCalls==1 and __action
    and __records.person.leisureSeating.phase=='native-rest')
restorePump()
print('PASS seating '..checks)
__freshSeating=fresh;__sourceStartSeating=start;__sourceEndSeating=sourceEnd;__nativePoseSeating=nativePose
