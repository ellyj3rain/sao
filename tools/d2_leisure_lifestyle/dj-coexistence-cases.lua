local L=SAO.LeisureLifestyle
local count=0
local function check(name,ok)
 assert(ok,'D2_DJ_COEXISTENCE:'..name)
 count=count+1
end

__freshLifestyle('dj')
local object=__station
local calls=0
local externalAction
local sourceClass={Type='PlayDJBoothAction',isValid=function()return true end}
local sourceValid=sourceClass.isValid
sourceClass.__index=sourceClass
sourceClass.new=function(self,actor,station)
 calls=calls+1
 return setmetatable({Type='PlayDJBoothAction',DJBooth=station,character=actor,sourceDJ=true},self)
end
PlayDJBoothAction=sourceClass
DJBoothMenu.walkToFront=function()return true end
local unrelated={Type='ReadBook',DJBooth=object}
local nativeAdd=ISTimedActionQueue.add
local sourceAdd=function(action)
 if action==unrelated then return action end
 if action.sourceDJ then externalAction=action;return action end
 return nativeAdd(action)
end
ISTimedActionQueue.add=sourceAdd

LS_DJBooth.isPlaying=true
local rows=L.offers('person',__body)
for _,row in ipairs(rows)do
 check('original_active_blocks_offer',row.activity~='perform-dj')
end
LS_DJBooth.isPlaying=false

local function originalCall(station,callback)
 return (callback or DJBoothMenu.onPlay)({},__body,station,'source-track','disc',100,0,0,0,'Bob_PlayDJDefault',false)
end
local original=__originalDJOnPlay
local offered=__offer('perform-dj')
check('original_menu_wrapped_once',DJBoothMenu.onPlay~=original)
local wrapped=DJBoothMenu.onPlay
__event('OnGameBoot');__event('OnGameStart')
check('source_guard_singleton',DJBoothMenu.onPlay==wrapped)

local function noDjOffer()
 for _,row in ipairs(L.offers('person',__body))do
  if row.activity=='perform-dj'then return false end
 end
 return true
end

DJBoothMenu.playerQueueOwner=function(candidate)return candidate==object end
check('owned_player_queue_blocks_npc_offer',noDjOffer())
check('owned_player_queue_blocks_stale_npc_begin',
 not L.begin('person',__body,offered,'purpose:1'))
DJBoothMenu.playerQueueOwner=nil
local oldSpecific=getSpecificPlayer
local player={}
getSpecificPlayer=function(slot)return slot==1 and player or nil end
ISTimedActionQueue.queues={[player]={queue={{Type='PlayDJBoothAction',DJBooth=object,character=player}}}}
check('external_player_queue_blocks_npc_offer',noDjOffer())
check('external_player_queue_blocks_stale_npc_begin',
 not L.begin('person',__body,offered,'purpose:1'))
ISTimedActionQueue.queues[player].queue[1].DJBooth={}
check('other_booth_queue_does_not_block_npc',not noDjOffer())
ISTimedActionQueue.queues={};getSpecificPlayer=oldSpecific

LS_DJBooth.isPlaying=true
check('stale_offer_refuses_original_ownership',
 not L.begin('person',__body,offered,'purpose:1'))
LS_DJBooth.isPlaying=false
local seq=__start('perform-dj')
check('sao_action_has_exact_object_lease',
 L.physicalSourceOwner(object)==true and not L.physicalSourceOwner({}))
local blocked=originalCall(object)
check('original_cannot_start_same_station',
 blocked==false and calls==0 and externalAction==nil)
local other={}
check('original_can_start_other_station',
 originalCall(other)==nil and calls==1 and externalAction.DJBooth==other)
externalAction=nil
check('captured_original_cannot_queue_same_station',
 originalCall(object,original)==nil and calls==2 and externalAction==nil)
local capturedAction=sourceClass:new(__body,object)
check('captured_original_action_invalid_on_lease',capturedAction:isValid()==false)
check('unrelated_action_passes_queue_unchanged',ISTimedActionQueue.add(unrelated)==unrelated)
check('other_station_action_remains_valid',sourceClass:new(__body,other):isValid()==true)
__admit=false
check('retiring_admission_keeps_lease_until_action_cleanup',
 L.physicalSourceOwner(object)==true and originalCall(object)==false and externalAction==nil)
__admit=true
LS_DJBooth.isPlaying=true
check('unexpected_original_takeover_interrupts_private_dj',
 not L.advance('person',__body)
 and L.outcome('person',seq).status=='interrupted'
 and not L.physicalSourceOwner(object))
LS_DJBooth.isPlaying=false
check('released_station_returns_to_original',
 originalCall(object)==nil and externalAction.DJBooth==object)

local offeredBeforeMenuLoss=__offer('perform-dj')
local selectedMenu=DJBoothMenu
DJBoothMenu=nil
check('missing_menu_refuses_new_npc_offer',noDjOffer())
check('missing_menu_refuses_stale_npc_begin',
 not L.begin('person',__body,offeredBeforeMenuLoss,'purpose:1'))
check('missing_menu_releases_previous_wrapper',selectedMenu.onPlay==original)
DJBoothMenu=selectedMenu
check('restored_menu_rebinds_guard',not noDjOffer())
local qualifiedWrapper=DJBoothMenu.onPlay
local changedCallback=function(...)return original(...)end
DJBoothMenu.onPlay=changedCallback
check('changed_callback_refuses_npc_offer',noDjOffer())
check('changed_callback_left_for_player',DJBoothMenu.onPlay==changedCallback)
DJBoothMenu.onPlay=original
check('source_callback_rebound_guard_restored',
 not noDjOffer() and DJBoothMenu.onPlay==qualifiedWrapper)
local reboundWrapper=DJBoothMenu.onPlay
local reboundOffer=__offer('perform-dj')
local reboundStarted,reboundSeq=L.begin('person',__body,reboundOffer,'purpose:1')
check('source_callback_rebound_still_blocks_lease',
 reboundStarted and originalCall(__station)==false)
DJBoothMenu.onPlay=changedCallback
local beforeLateAction=externalAction
check('late_callback_cannot_queue_same_station',
 originalCall(__station,original)==nil and externalAction==beforeLateAction)
check('late_callback_invalidates_npc_lease',
 not L.advance('person',__body) and L.outcome('person',reboundSeq).status=='interrupted')
check('late_callback_player_resumes_after_cleanup',
 originalCall(object,changedCallback)==nil and externalAction.DJBooth==object)
DJBoothMenu.onPlay=original
check('rebound_wrapper_singleton',not noDjOffer() and DJBoothMenu.onPlay==reboundWrapper)

__freshLifestyle('dj')
local active=SAO.SourceIntegration.active
SAO.SourceIntegration.active=function(id)
 if id=='LifestyleHobbies'then return false end
 return active(id)
end
local externalOffer=__offer('perform-dj')
local ok,externalSeq=L.begin('person',__body,externalOffer,'purpose:1')
check('external_source_idle_allows_npc_dj',ok and externalSeq)
local priorExternal=externalAction
check('external_original_blocked_by_npc_station_lease',
 originalCall(__station)==false and externalAction==priorExternal)
L.interrupt('person',__body,'fixture-end')
SAO.SourceIntegration.active=active

__freshLifestyle('dj')
local queueOffer=__offer('perform-dj')
local queueStarted,queueSeq=L.begin('person',__body,queueOffer,'purpose:1')
check('npc_started_before_player_queue',queueStarted and queueSeq)
local activePlayer={}
local oldSpecific2=getSpecificPlayer
getSpecificPlayer=function(slot)return slot==2 and activePlayer or nil end
ISTimedActionQueue.queues={[activePlayer]={queue={{Type='PlayDJBoothAction',DJBooth=__station,character=activePlayer}}}}
check('queued_external_player_interrupts_same_booth_npc',
 not L.advance('person',__body)
 and L.outcome('person',queueSeq).status=='interrupted')
ISTimedActionQueue.queues={};getSpecificPlayer=oldSpecific2

__freshLifestyle('dj')
local swapObject=__station
local swapSeq=__start('perform-dj')
local classAWrapper=sourceClass.isValid
local replacementValid=function(action)return action.allowed~=false end
local replacementClass={Type='PlayDJBoothAction',isValid=replacementValid,new=sourceClass.new}
replacementClass.__index=replacementClass
local retiredMenu=DJBoothMenu
local replacementMenuOriginal=function(...)return original(...)end
local replacementMenu={onPlay=replacementMenuOriginal,walkToFront=function()return true end}
PlayDJBoothAction=replacementClass
DJBoothMenu=replacementMenu
__event('OnGameStart')
local classBWrapper=replacementClass.isValid
check('recreated_class_restores_previous_wrapper',sourceClass.isValid==sourceValid)
check('recreated_class_binds_new_wrapper',classBWrapper~=replacementValid
 and L._originalDJGuard.actionClass==replacementClass)
check('paired_recreated_menu_restores_previous_wrapper',retiredMenu.onPlay==original)
check('paired_recreated_menu_binds_new_wrapper',
 replacementMenu.onPlay~=replacementMenuOriginal
 and L._originalDJGuard.menu==replacementMenu)
local menuBWrapper=replacementMenu.onPlay
check('recreated_class_retains_exact_lease',
 L.physicalSourceOwner(swapObject)==true
 and replacementClass:new(__body,swapObject):isValid()==false
 and replacementClass:new(__body,other):isValid()==true)
local beforeRebindQueue=externalAction
check('paired_recreated_menu_blocks_same_station',
 originalCall(swapObject)==false and externalAction==beforeRebindQueue)
check('recreated_class_captured_menu_cannot_queue_leased_booth',
 originalCall(swapObject,original)==nil and externalAction==beforeRebindQueue)
check('recreated_class_player_uses_other_booth',
 originalCall(other)==nil and externalAction.DJBooth==other)
__event('OnGameBoot')
check('recreated_class_wrapper_singleton',replacementClass.isValid==classBWrapper
 and replacementMenu.onPlay==menuBWrapper)
L.interrupt('person',__body,'fixture-swap')
check('recreated_class_player_resumes_after_lease',
 replacementClass:new(__body,swapObject):isValid()==true
 and originalCall(swapObject)==nil and externalAction.DJBooth==swapObject)
check('recreated_class_unrelated_action_unchanged',ISTimedActionQueue.add(unrelated)==unrelated)

local externalValid=function()return false end
replacementClass.isValid=externalValid
local externalMenu=function(...)return replacementMenuOriginal(...)end
replacementMenu.onPlay=externalMenu
local latestValid=function()return true end
local latestClass={Type='PlayDJBoothAction',isValid=latestValid,new=sourceClass.new}
latestClass.__index=latestClass
local latestMenuOriginal=function(...)return original(...)end
local latestMenu={onPlay=latestMenuOriginal,walkToFront=function()return true end}
PlayDJBoothAction=latestClass
DJBoothMenu=latestMenu
__event('OnGameStart')
check('rebind_preserves_external_override_on_retired_class',replacementClass.isValid==externalValid)
check('rebind_preserves_external_override_on_retired_menu',replacementMenu.onPlay==externalMenu)
check('second_recreated_class_binds_once',
 L._originalDJGuard.actionClass==latestClass and latestClass.isValid~=latestValid)
check('second_recreated_menu_binds_once',
 L._originalDJGuard.menu==latestMenu and latestMenu.onPlay~=latestMenuOriginal)
local latestWrapper=latestClass.isValid
local latestMenuWrapper=latestMenu.onPlay
__event('OnGameBoot')
check('second_recreated_class_wrapper_singleton',latestClass.isValid==latestWrapper
 and latestMenu.onPlay==latestMenuWrapper)

local priorGuard=L._originalDJGuard
local priorMenuWrapper=DJBoothMenu.onPlay
__reload()
check('module_reload_restores_current_class',
 priorGuard.active==false and latestClass.isValid==latestValid)
check('module_reload_restores_other_callbacks',
 DJBoothMenu.onPlay==latestMenuOriginal and ISTimedActionQueue.add==sourceAdd)
__event('OnGameStart')
local guard=L._originalDJGuard
check('module_reload_ignores_stale_hooks',
 guard~=priorGuard and priorGuard.actionClass==nil
 and guard.active==true and guard.actionClass==latestClass
 and latestClass.isValid==guard.validWrapper and DJBoothMenu.onPlay==guard.menuWrapper)
check('module_reload_rebinds_once',not noDjOffer() and latestClass.isValid==guard.validWrapper)
local reloadSeq=__start('perform-dj')
local beforeRetiredMenu=calls
check('retired_captured_menu_delegates_to_current_lease_guard',
 originalCall(swapObject,priorMenuWrapper)==nil and calls==beforeRetiredMenu+1
 and L.physicalSourceOwner(swapObject)==true)
L.interrupt('person',__body,'fixture-reload')

L.reset('fixture-final')
local currentMenu=DJBoothMenu
local currentQueue=ISTimedActionQueue.add
local currentValid=latestClass.isValid
check('guard_active_before_cleanup',currentMenu.onPlay==guard.menuWrapper
 and currentQueue==guard.queueWrapper and currentValid==guard.validWrapper)
guard.restore()
check('cleanup_restores_source_callbacks',currentMenu.onPlay==latestMenuOriginal
 and ISTimedActionQueue.add==sourceAdd and latestClass.isValid==latestValid)
check('cleanup_preserves_normal_player_use',originalCall(swapObject)==nil and externalAction.DJBooth==swapObject)
__event('OnGameStart')
check('cleanup_leaves_retired_guards_inactive',
 latestClass.isValid==latestValid and DJBoothMenu.onPlay==latestMenuOriginal)

print('PASS D2 DJ coexistence '..count)
