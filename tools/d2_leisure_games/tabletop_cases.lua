local G=SAO.LeisureGames
local checks=0
local function check(name,value)assert(value,'NATIVE_TABLETOP:'..name);checks=checks+1;print('CASE '..name)end
local generation=0
local function fresh(name)
 G.reset('proof-reset');__clearInventory();__queue=nil;__hours=10;__client=false;__server=false
 generation=generation+1;local token='native-tabletop-'..generation
 __records={person={id='person',bodyOwnerToken=token,gamesSequence=generation-1},other={id='other'}};__bodies={person=__body,other=__other}
 __body:getModData().SAOPersonId='person';__body:getModData().SAOExternalToken=token;__body:setAsleep(false);__body:setHealth(100)
 __other:getModData().SAOPersonId='other';__other:getModData().SAOExternalToken=nil;__other:setAsleep(false)
 __item=__items[name];__body:getInventory():AddItem(__item);__item:setJobDelta(0)
 __emitter:reset();__seed(177)
end
local function offer(kind)
 local list,err=G.offers('person',__body);if err then error(err)end
 for _,o in ipairs(list)do if o.activity==kind then return o end end
end
local function purpose(o)
 local p={id='purpose-games',domain='leisure',status='maintained',affordance=o.sourceId,cursor=1,
  leisure={activity=o.activity,itemKey=o.itemKey,activityKey=o.id},steps={{id='perform-activity',owner='SAO.LeisureGames',token='leisure:performed',target=o.activity,status='available'}}}
 __records.person.proceduralPlanning={schema=1,purposes={['purpose-games']=p},order={'purpose-games'},spatial={},spatialOrder={},practice={}}
 return p
end
local function begin(kind)
 local o=assert(offer(kind),'no native offer '..kind);local p=purpose(o)
 assert(G.begin('person',__body,o,p.id),'begin refused '..kind);return __queue,p,o
end
local function start(a)__nativeAction(a.action,'start')end
local function progress(a,n)__nativeAction(a.action,'progress',n)end
local function perform(a)__nativeAction(a.action,'perform')end
local function complete(a)__nativeAction(a.action,'complete')end
local function result(seq)return G.outcome('person',seq or generation)end
for _,row in ipairs({{'CardDeck','draw-card'},{'Dice','roll-dice'},{'Dice_Bone','roll-dice'},{'Dice_Wood','roll-dice'},{'Dice_4','roll-dice'},{'Dice_6','roll-dice'},{'Dice_8','roll-dice'},{'Dice_10','roll-dice'},{'Dice_12','roll-dice'},{'Dice_20','roll-dice'},{'Dice_00','roll-dice'}})do
 local name,kind=row[1],row[2];fresh(name)
 local native=SAOJavaBridge:nativeTabletopAffordance(__body,__item,kind)
 check('loaded_native_recipe_'..name,native and native.time==20 and native.recipeName==(kind=='draw-card'and'DrawRandomCard'or'RollOneDice'))
 local models=__logicModels(__item,kind)
 check('source_hand_models_'..name,models.one==native.prop1 and models.two==native.prop2)
 __seed(177);local expected=__sourceExpected(kind,__item);local calls=__rngCalls();__seed(177)
 local a,p,o=begin(kind)
 local reference={character=__body,craftRecipe=__nativeRecipe(kind),items=__sourceItems(__item),actionScript=__nativeRecipe(kind):getTimedActionScript(),action=a.action}
 setmetatable(reference,{__index=ISHandcraftAction})
 check('native_duration_'..name,a.maxTime==ISHandcraftAction.getDuration(reference)and a.stopOnRun and a.stopOnAim==false)
 check('native_start_no_rng_'..name,__rngCalls()==0 and G.work('person').status=='active')
 start(a);progress(a,.4)
 check('native_partial_'..name,__item:getJobDelta()>.39 and __item:getJobDelta()<.41 and G.work('person').nativeProgress.sourceUpdates==1)
 local sourceProgress=__item:getJobDelta();__item:setJobDelta(0);ISHandcraftAction.update(reference)
 check('original_update_same_item_'..name,__item:getJobDelta()==sourceProgress)
 perform(a)
 check('partial_no_result_'..name,result()==nil and __rngCalls()==0)
 progress(a,1);perform(a);complete(a)
 local r=assert(result(),'native result missing '..name)
 check('native_source_result_'..name,r.status=='completed'and r.sourceResult and(kind=='draw-card'and r.sourceResult.cardKey==expected or kind=='roll-dice'and r.sourceResult.face==expected))
 check('native_rng_exact_'..name,__rngCalls()==calls)
 check('item_kept_'..name,__body:getInventory():contains(__item)and __item:getJobDelta()==0)
 check('typed_result_consumed_'..name,p.status=='completed'and SAO.ProceduralPlanning.hobbyAdmission('person',p.id,r.workId,true)~=nil)
 local reread=SAOJavaBridge:nativeTabletopComplete(__body,__item,kind,r.workId)
 check('duplicate_native_result_'..name,reread and reread.fresh==false and __rngCalls()==calls)
 perform(a);complete(a);check('duplicate_callbacks_'..name,__rngCalls()==calls and #__records.person.gamesOutcomes==1)
 r.sourceResult.display='forged';check('canonical_detached_'..name,result().sourceResult.display~='forged')
 check('native_halo_unchanged_'..name,__haloUnchanged())
end
fresh('CardDeck');local a,p,o=begin('draw-card');start(a);progress(a,.2)
check('native_animation_and_sound',__emitter:getPlayed()>0 and __body:getVariableString('PerformingAction')=='Making')
__nativeAction(a.action,'stop');check('partial_interruption',result().status=='interrupted'and result().sourceResult==nil and __rngCalls()==0 and __body:getInventory():contains(__item))
fresh('CardDeck');a,p,o=begin('draw-card');start(a);progress(a,.2)
__records.person=__roundTrip(__records.person);__reloadGames();G.advance('person',__body)
check('reload_retains_attempt_not_success',result()and result().status=='interrupted'and result().nativeProgress.sourceUpdates==1 and result().sourceResult==nil and __rngCalls()==0)
perform(a);complete(a);check('reload_old_callback_refused',__rngCalls()==0 and #__records.person.gamesOutcomes==1)
fresh('CardDeck');o=offer('draw-card');purpose(o);o.revision='forged'
check('forged_source_refused',not G.begin('person',__body,o,'purpose-games')and __queue==nil and __rngCalls()==0)
fresh('CardDeck');o=offer('draw-card');p=purpose(o);p.leisure.itemKey='item:foreign'
check('wrong_purpose_item_refused',not G.begin('person',__body,o,p.id)and __queue==nil and G.work('person')==nil and __rngCalls()==0)
fresh('CardDeck');o=offer('draw-card');p=purpose(o);p.steps[1].owner='SAO.LeisureMusic'
check('wrong_purpose_owner_refused',not G.begin('person',__body,o,p.id)and __queue==nil and __rngCalls()==0)
p.steps[1].owner='SAO.LeisureGames'
check('stale_offer_after_refusal',not G.begin('person',__body,o,p.id)and __rngCalls()==0)
fresh('CardDeck');a,p=begin('draw-card');start(a);progress(a,1);p.status='abandoned';perform(a);complete(a)
check('retired_purpose_refuses_rng',__rngCalls()==0 and result()==nil)
fresh('CardDeck');a,p=begin('draw-card');start(a);progress(a,1);__body:getInventory():Remove(__item);__other:getInventory():AddItem(__item);perform(a);complete(a)
check('foreign_item_custody_refuses_rng',__rngCalls()==0 and result()==nil)
fresh('Dice_6');a,p=begin('roll-dice');start(a);progress(a,1);__body:getModData().SAOExternalToken='replacement';__records.person.bodyOwnerToken='replacement';perform(a);complete(a)
check('stale_generation_refuses_rng',__rngCalls()==0 and result()==nil)
fresh('Dice_6');o=offer('roll-dice');purpose(o)
check('foreign_body_refused',not G.begin('person',__other,o,'purpose-games')and __rngCalls()==0)
fresh('ChessWhite');check('chess_item_not_invented_rules',#G.offers('person',__body)==0)
fresh('CheckerBoard');check('checker_item_not_invented_rules',#G.offers('person',__body)==0)
fresh('CardDeck');__client=true;check('multiplayer_unjoined_refused',#G.offers('person',__body)==0)
fresh('CardDeck');a,p=begin('draw-card');progress(a,.3);local captured=a.action
check('foreign_interrupt_cannot_retire',G.interrupt('person',__other,'foreign')==false and G.work('person')~=nil and __emitter:getStopped()==0)
__body:setHealth(0);check('native_dead_body',__body:isDead())
G.interrupt('person',__body,'death')
check('death_exact_audio_cleanup',__emitter:getPlayed()==1 and __emitter:getStopped()==1 and __queue==nil and not __body:getCharacterActions():contains(captured))
check('death_keeps_attempt_without_result',result().status=='interrupted'and result().reason=='death'and result().sourceResult==nil and __rngCalls()==0 and __item:getJobDelta()==0)
perform(a);complete(a);check('death_old_callbacks_cannot_roll',__rngCalls()==0)
fresh('CardDeck');a,p=begin('draw-card');progress(a,.3);captured=a.action
__bodies.person=__other;G.interrupt('person',__body,'body-detached')
check('detach_captured_cleanup',__emitter:getStopped()==1 and result().status=='interrupted'and __rngCalls()==0 and not __body:getCharacterActions():contains(captured))
fresh('CardDeck');a,p=begin('draw-card');progress(a,1);captured=a.action;a.action=__foreignNative(a);progress(a,1)
perform(a);complete(a);check('foreign_native_callback_refused',__rngCalls()==0 and result()==nil)
G.interrupt('person',__body,'native-action-replaced');check('replacement_cleanup_uses_captured_native',not __body:getCharacterActions():contains(captured)and result().status=='interrupted')
fresh('CardDeck');__recipeTime(21);check('loaded_recipe_override_refused',#G.offers('person',__body)==0 and __rngCalls()==0);__recipeTime(20)
fresh('CardDeck');a,p=begin('draw-card');progress(a,1);__recipeTime(21);perform(a);complete(a)
check('live_recipe_override_refuses_rng',__rngCalls()==0 and result()==nil);__recipeTime(20)
fresh('CardDeck');a,p=begin('draw-card');__nativeAction(a.action,'delta-only',1);perform(a);complete(a)
check('source_update_required',__rngCalls()==0 and result()==nil)
fresh('CardDeck');a,p=begin('draw-card');progress(a,1);__hours=9;perform(a);complete(a)
check('backwards_clock_refuses_rng',__rngCalls()==0 and result()==nil);__hours=10
for _,kind in ipairs({'xp','prop','tool','callback','tick','amount','ancillary','input'})do
 fresh('CardDeck');__recipeOverride(kind,true)
 check('loaded_'..kind..'_override_refused',#G.offers('person',__body)==0)
 check('native_'..kind..'_override_refused',SAOJavaBridge:nativeTabletopComplete(__body,__item,'draw-card','invalid-'..kind)==nil and __rngCalls()==0)
 __recipeOverride(kind,false);check('native_'..kind..'_restore',#G.offers('person',__body)==1)
 fresh('CardDeck');a,p=begin('draw-card');progress(a,1);__recipeOverride(kind,true);perform(a);complete(a)
 check('live_'..kind..'_override_refuses_rng',__rngCalls()==0 and result()==nil);__recipeOverride(kind,false)
end
print('PASS native tabletop '..checks)
