local checks=0
local function check(name,yes)assert(yes,'PREPARATION:'..name);checks=checks+1;print('CASE '..name)end
local function fresh(mode)
 if SAO.LeisurePreparation.reset then SAO.LeisurePreparation.reset('fixture reset')end
 __mode=mode;__busy=false;__denied=false;__bleeding=0;__cold=0;__threat=false;__routeRefuse=false;__queueRefuse=false;__offerUnavailable=false;__initialized=false;__begun=0
 __records={person={id='person',bodyOwner='SAO',bodyOwnerToken='native-body-1'},other={id='other',bodyOwner='SAO',bodyOwnerToken='native-body-2'}}
 __bodies={person=__body,other=__other}
 for _,pair in ipairs({{__body,'person'},{__other,'other'}})do
  local body=pair[1];body:getModData().SAOPersonId=pair[2];body:getModData().SAOExternalToken=__records[pair[2]].bodyOwnerToken
  body:setAsleep(false);body:setPrimaryHandItem(nil);body:setSecondaryHandItem(nil);body:setSitOnGround(false)
  body:removeWornItem(__bag);body:removeWornItem(__mask)
  body:getInventory():clear()
  ISTimedActionQueue.queues[body]=nil
 end
 __body:setX(10.5);__body:setY(20.5)
 for _,value in ipairs({__dumbbell,__barbell,__bag,__mask})do __body:getInventory():AddItem(value) end
 SAO.Locomotion.jobs={}
 local offer=SAO.LeisureExercise.intentOffers('person',__body)[1]
 local purpose={id='purpose-1',domain='leisure',status='maintained',affordance=offer.sourceId,revision=1,
  leisure={activityKey=offer.id,activity=offer.activity,itemKey=offer.itemKey},
  steps={{id='perform-activity',owner='SAO.LeisureExercise',target=offer.activity,token='leisure:performed',status='available'}}}
 __records.person.proceduralPlanning={schema=1,purposes={['purpose-1']=purpose},order={'purpose-1'},spatial={},spatialOrder={},practice={}}
 return offer,purpose
end
local function begin(mode)
 local offer,purpose=fresh(mode)
 local accepted,ready=SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1')
 check('begin_'..mode,accepted and not ready)
 return __action,purpose
end
local function started(action)
 action.action:waitToStart()
 action.action:setCurrentTime(action.maxTime)
 action.action:setJobDelta(1)
 action:update()
 check('native_started_timing',action.action:isStarted() and action:getJobDelta()==1)
end
local function nativeFinish(action)
 -- Installed IsoGameCharacter performs at1334 before complete at1344 in SP.
 action.action:perform();action.action:complete()
end
local function ready()
 local held,result=SAO.LeisurePreparation.advance('person',__body)
 return not held and result and result.purposeId=='purpose-1' and __records.person.leisurePreparation.status=='completed'
end
check('actual_source_allowlist',SAOJavaBridge:nativeLeisureActionSource('unknown')==nil and SAOJavaBridge:nativeLeisureActionSource('../ISWearClothing')==nil)
check('actual_source_hash_tamper',__tamperRejected())
local a,p=begin('primary')
check('queued_not_native_equipped',__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='preparing')
check('early_complete_refused',a:complete()==false and __body:getPrimaryHandItem()==nil)
a:perform();check('early_perform_refused',ISTimedActionQueue.hasAction(a))
started(a);nativeFinish(a)
check('native_primary_effect',__body:getPrimaryHandItem()==__dumbbell and __other:getPrimaryHandItem()==nil)
check('native_perform_before_complete_reconciles',ready())
check('preparation_does_not_close_hobby',p.status=='maintained' and p.steps[1].status=='available' and not p.admission)
check('source_environment_preserves_globals',getPlayerHotbar==nil and getPlayerInventory==nil and ISEquipWeaponAction==nil and ISWearClothing==nil and ISUnequipAction==nil)
local oldStatus=__records.person.leisurePreparation.status;a:complete();a:perform()
check('duplicate_callback_no_new_effect',__records.person.leisurePreparation.status==oldStatus and __body:getPrimaryHandItem()==__dumbbell)
a=begin('secondary');started(a);nativeFinish(a)
check('native_secondary_effect',__body:getSecondaryHandItem()==__dumbbell and __body:getPrimaryHandItem()==nil and ready())
a=begin('twoHands');started(a);nativeFinish(a)
check('native_two_hand_barbell_effect',__body:getPrimaryHandItem()==__barbell and __body:getSecondaryHandItem()==__barbell and ready())
fresh('bag');__body:setWornItem(__bag:canBeEquipped(),__bag)
local offer=SAO.LeisureExercise.intentOffers('person',__body)[1]
check('bag_begin',SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1'))
a=__action;started(a);nativeFinish(a)
check('native_bag_unequip_effect',not __body:isEquippedClothing(__bag) and ready())
a=begin('mask');started(a);nativeFinish(a)
local maskReady=ready()
check('native_clothing_wear_effect',__body:isEquippedClothing(__mask) and maskReady)
fresh('clearHands');__body:setPrimaryHandItem(__dumbbell)
offer=SAO.LeisureExercise.intentOffers('person',__body)[1]
check('clear_hands_begin',SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1'))
a=__action;started(a);nativeFinish(a)
check('native_clear_hands_effect',__body:getPrimaryHandItem()==nil and ready())
offer,p=fresh('primary');p.status='abandoned'
check('retired_purpose_refused',not SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1') and __body:getPrimaryHandItem()==nil)
offer,p=fresh('primary');p.steps[1].owner='SAO.LeisureMusic'
check('foreign_purpose_owner_refused',not SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1'))
offer,p=fresh('primary')
check('foreign_actor_refused',not SAO.LeisurePreparation.begin('person',__other,'SAO.LeisureExercise',offer,'purpose-1'))
offer=fresh('primary');offer.revision='spoof'
check('forged_source_revision_refused',not SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1') and __body:getPrimaryHandItem()==nil)
offer=fresh('primary');offer.sourceId='forged-source'
check('forged_source_owner_refused',not SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1'))
a=begin('primary');__records.person.leisurePreparation.offer.activity='forged-activity';started(a);nativeFinish(a)
check('saved_offer_does_not_replace_private_selection',ready() and __body:getPrimaryHandItem()==__dumbbell)
a=begin('primary');check('foreign_interrupt_preserves_owned_work',not SAO.LeisurePreparation.interrupt('person',__other,'forged') and __records.person.leisurePreparation.status=='preparing')
SAO.LeisurePreparation.interrupt('person',__body,'cleanup')
a,p=begin('primary');started(a);p.status='abandoned';nativeFinish(a);SAO.LeisurePreparation.advance('person',__body)
check('retired_during_native_no_effect',__body:getPrimaryHandItem()==nil and p.status=='abandoned' and __records.person.leisurePreparation.status=='interrupted')
a=begin('primary');started(a);__body:getModData().SAOExternalToken='replaced';__records.person.bodyOwnerToken='replaced';nativeFinish(a);SAO.LeisurePreparation.advance('person',__body)
check('replaced_body_token_no_effect',__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='interrupted')
a=begin('primary');started(a);__body:getInventory():Remove(__dumbbell);__replacement:setID(__dumbbell:getID());__body:getInventory():AddItem(__replacement);nativeFinish(a)
if not a.action:valid() then a.action:stop() end -- exact native invalid-action branch
SAO.LeisurePreparation.advance('person',__body)
check('replacement_item_identity_no_effect',__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='interrupted')
a=begin('primary');started(a);a.action:setJobDelta(.5);nativeFinish(a);SAO.LeisurePreparation.advance('person',__body)
check('partial_time_no_effect',__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='preparing')
SAO.LeisurePreparation.interrupt('person',__body,'partial cleanup')
a=begin('primary');started(a);ISTimedActionQueue.getTimedActionQueue(__body):removeFromQueue(a);nativeFinish(a);SAO.LeisurePreparation.advance('person',__body)
check('lost_queue_no_effect',__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='interrupted')
a=begin('primary');started(a);__reloadPreparation();SAO.LeisurePreparation.advance('person',__body);nativeFinish(a)
check('reload_does_not_invent_completion',__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='interrupted')
a=begin('primary');started(a);a.action:setJobDelta(.4);a:update()
local follower={character=__body,begin=function()__followerBegun=true end,isValidStart=function()return true end,isStarted=function()return false end,forceCancel=function()__followerCancelled=true end}
local queue=ISTimedActionQueue.getTimedActionQueue(__body);table.insert(queue.queue,follower);__followerBegun=false;__followerCancelled=false
SAO.LeisurePreparation.interrupt('person',__body,'urgent fixture')
check('interrupt_preserves_unrelated_queue',#queue.queue==1 and queue.queue[1]==follower and not __followerCancelled)
check('interrupt_reconciles_native_source_cleanup',__dumbbell:getJobDelta()==0 and (not a.sound or not __emitter:isPlaying(a.sound)))
for _,pressure in ipairs({'__bleeding','__cold','__threat','thirst','hunger','endurance','fatigue'})do
 a=begin('primary');started(a)
 local needs={thirst=0,hunger=0,endurance=1,fatigue=0}
 if pressure=='__bleeding'then __bleeding=1 elseif pressure=='__cold'then __cold=2 elseif pressure=='__threat'then __threat=true
 elseif pressure=='endurance'then needs.endurance=.1 elseif pressure=='fatigue'then needs.fatigue=1 else needs[pressure]=1 end
 local agent={rec=__records.person}
 Ctl.advanceLeisure('person',agent,__body,1,needs);nativeFinish(a)
 check('controller_preempts_'..pressure,__body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='interrupted' and __begun==0)
end
offer=fresh('route');check('route_begin',SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1'))
local route=SAO.Locomotion.jobs.person;check('route_exact_target',route.x==11.5 and route.y==20.5 and route.z==0)
check('route_pending_not_success',SAO.LeisurePreparation.advance('person',__body) and __records.person.leisurePreparation.status=='preparing')
route.done=true;route.result='failed';SAO.LeisurePreparation.advance('person',__body)
check('route_failure_no_success',__records.person.leisurePreparation.status=='interrupted')
offer=fresh('route');SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1');route=SAO.Locomotion.jobs.person
route.done=true;route.result='arrived';__body:setX(11.5)
check('exact_route_arrival_reconciles',ready())
offer=fresh('route');SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1');SAO.Locomotion.jobs.person={done=true,result='arrived'};SAO.LeisurePreparation.advance('person',__body)
check('replaced_route_refused',__records.person.leisurePreparation.status=='interrupted')
offer=fresh('initialize');local ok,result=SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1')
check('source_initialization_requery',ok and result and __initialized)
offer=fresh('stand');__body:setSitOnGround(true);offer=SAO.LeisureExercise.intentOffers('person',__body)[1]
local standOK,standReady=SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1')
check('native_ground_standing_effect',standOK and standReady and not __body:isSitOnGround())
offer=fresh('primary');__queueRefuse=true
check('queue_refusal_no_effect',not SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1') and __body:getPrimaryHandItem()==nil and __records.person.leisurePreparation.status=='interrupted')
check('no_preparation_XP_or_clock',__xpWrites==0 and __clockWrites==0)
offer=fresh('route');SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1')
local restorePump=__installRoutePumpFixture(__body)
check('production_route_tick_reaches_preparation',ready() and __pumpCalls==1)
restorePump()
offer=fresh('primary');__body:setPrimaryHandItem(nil);__body:getInventory():AddItem(__heavy);__body:setSecondaryHandItem(__heavy)
check('secondary_only_heavy_item_refused',__heavy:isForceDropHeavyItem()
    and not SAO.LeisurePreparation.begin('person',__body,'SAO.LeisureExercise',offer,'purpose-1')
    and __body:getSecondaryHandItem()==__heavy)
print('PASS preparation '..checks)
