local count=0
local function check(name,value)count=count+1;assert(value,'D2_NATIVE_DANCE:'..name);print('CASE '..name)end
local S=SAO.LeisureSkill
local nativeBody=__nativeBody;__stats=nativeBody:getStats()
__initSourceTraits();__body=nativeBody
check('native_registered_trait_and_offslot',nativeBody:getPlayerNum()==1 and not nativeBody:hasTrait(CharacterTrait.PARTYANIMAL))
local state=fixture('placed',true);local sourceBody=__body;__body=nativeBody
SAO.Identity.get=function(id)return __records[id]end
SAO.Body={get=function(id)return id=='person'and nativeBody or nil end}
-- Exact retained actor identity, including native death, remains available to
-- cleanup. Canonical XP receiver independently prohibits dead/native-absent XP.
SAO.Needs.ownsRecoveryBody=function(id,b)return id=='person'and b==nativeBody and b:getModData().SAOExternalToken=='native:dance:1'end
SAO.Perception.resolveLeisureAudioSource=function(id,b,key)return __visible and id=='person'and b==nativeBody and key==__row.key and __target or nil end
SAO.Perception.canHearLeisureSource=function(id,b,row,range)return __hearing and __visible and b==nativeBody and row.actorId==id and range>0 end
SAOJavaBridge={privateCarriedItems=function(_,b)assert(b==nativeBody);return b:getInventory():getItems()end}
SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)local w=M.work(id);if __admit and w and w.purposeId==pid and w.workId==wid then w.ownerName='SAO.LeisureMusic';return w end end
nativeBody:getModData().SAOPersonId='person';nativeBody:getModData().SAOExternalToken='native:dance:1'
nativeBody:getModData().PlayerVoice=0;LSMoodleManager.init(nativeBody)
nativeBody:setPrimaryHandItem(nil);nativeBody:setSecondaryHandItem(nil);nativeBody:setSittingOnFurniture(false);nativeBody:setSitOnGround(false)
SandboxVars.Debug={DanceAnim=false};GTLSCheck=1;__seconds=1;__sourceTick();__delta=0
nativeBody:setPerkLevelDebug(Perks.Dancing,0);nativeBody:setPerkLevelDebug(Perks.Fitness,0)
local function resetStats()
 __stats:set(CharacterStat.ENDURANCE,.8);__stats:set(CharacterStat.FATIGUE,.2);__stats:set(CharacterStat.PAIN,0)
 __stats:set(CharacterStat.BOREDOM,15);__stats:set(CharacterStat.STRESS,.2);__stats:set(CharacterStat.UNHAPPINESS,30)
end
resetStats();sendClientCommand=function()error('original source command escaped private adapter')end
check('native_body_exists_and_acquired_sound',nativeBody:isExistInTheWorld() and M.currentHeardMusic('person',nativeBody).soundObserved)
local function begin()
 local selected;for _,o in ipairs(M.offers('person',nativeBody))do if o.activity=='dance'then selected=o end end
 assert(selected,'native dance offer missing');local ok,w=M.begin('person',nativeBody,selected,'purpose:1');assert(ok,tostring(w));local a=__queued;a:start();return w,a
end
local xp=nativeBody:getXp():getXP(Perks.Dancing);local w,a=begin();__seconds=1;a:update()
check('native_ordinary_update_no_completion',M.outcome('person',w.sequence)==nil and nativeBody:getXp():getXP(Perks.Dancing)==xp)
__seconds=40;a:update();local outcome=M.outcome('person',w.sequence)
local r=S.receipt('person','SAO.LeisureMusic',w.sequence,1)
check('canonical_actual_native_dancing_XP',r and r.status=='applied' and nativeBody:getXp():getXP(Perks.Dancing)>xp)
check('native_original_cycle_stats',__stats:get(CharacterStat.ENDURANCE)<.8 and __stats:get(CharacterStat.FATIGUE)>.2 and __stats:get(CharacterStat.BOREDOM)<15)
check('native_bounded_source_cycle_completed',outcome and outcome.status=='completed' and outcome.nativeProgress.sourceDanceCycle.sourceCallbackCompleted)
check('native_source_muscle_load',nativeBody:getModData().FitnessActivityMuscles==1 and nativeBody:getModData().DidFitnessActivity==1)
local prior=nativeBody:getXp():getXP(Perks.Dancing);a:update();a:perform()
check('native_duplicate_no_XP',nativeBody:getXp():getXP(Perks.Dancing)==prior)
resetStats();nativeBody:getInventory():AddItem(__harmonica);nativeBody:setPrimaryHandItem(__harmonica)
nativeBody:setSecondaryHandItem(__harmonica)
w,a=begin()
check('native_private_start_own_two_hand_argument',a.actionType=='Bob_PreDancingDefault' and a.handItemP==__harmonica and a.handItemS==0)
check('native_private_raw_and_derived_revision_distinct',M.work('person').sourceAdaptations.rawRevision==M.work('person').revision
 and #M.work('person').sourceAdaptations.sites==4 and #M.work('person').sourceAdaptations.ownershipSites==2
 and M.work('person').sourceAdaptations.derivedRevision.bytes>0)
M.interrupt('person',nativeBody,'fixture-custody-requery');nativeBody:setSecondaryHandItem(nil)
w,a=begin();a:start();check('native_source_saved_own_hand_item',a.handItemP==__harmonica)
nativeBody:setPrimaryHandItem(nil);nativeBody:getInventory():Remove(__harmonica);__other:getInventory():AddItem(__harmonica)
__seconds=40;a:update();outcome=M.outcome('person',w.sequence)
check('native_completed_cleanup_cannot_reequip_transferred_hand_item',outcome and outcome.status=='completed'
 and nativeBody:getPrimaryHandItem()==nil and __other:getInventory():contains(__harmonica)and not nativeBody:getInventory():contains(__harmonica))
resetStats();nativeBody:getModData().LSMoodles.Embarrassed.Value=0
ZombRand=function(n,b)if b then return n end;if n==100 then return 99 end;if n==2 then return 1 end;return 0 end
w,a=begin();__seconds=40;a:update()
check('native_failed_animation_continues',a.criticalFailure==2 and M.outcome('person',w.sequence)==nil)
__seconds=2;a:update();__seconds=10;a:update()
check('native_original_scream_impact_sound',__emitter:getPlayed()==2 and not __emitter:isClear())
__seconds=60;a:update();outcome=M.outcome('person',w.sequence)
check('native_failed_move_source_pain',outcome.status=='interrupted'and __stats:get(CharacterStat.PAIN)==40 and nativeBody:getModData().LSMoodles.Embarrassed.Value==.25 and __emitter:isClear())
resetStats();nativeBody:getModData().LSMoodles.Embarrassed.Value=0;__emitter:reset();w,a=begin();__seconds=40;a:update();__seconds=2;a:update()
local before=nativeBody:getXp():getXP(Perks.Dancing);nativeBody:setHealth(0);M.interrupt('person',nativeBody,'native-death')
check('native_dead_cleanup_no_pain_replay',__stats:get(CharacterStat.PAIN)==0 and nativeBody:getModData().LSMoodles.Embarrassed.Value==0)
check('native_dead_source_owned_sound_flags',__emitter:isClear() and nativeBody:getModData().IsDancingFull==false and M.outcome('person',w.sequence).status=='interrupted')
check('native_dead_cleanup_no_XP_replay',nativeBody:getXp():getXP(Perks.Dancing)==before)
print('PASS native source dance '..count)
