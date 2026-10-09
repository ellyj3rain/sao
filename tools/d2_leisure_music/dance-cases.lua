count=0
check=function(name,value)if not value then error('D2_DANCE:'..name)end;count=count+1;print('CHECK '..name)end
SandboxVars.Debug={DanceAnim=false};Metabolics.Fitness='Fitness';CharacterTrait.PARTYANIMAL='PARTYANIMAL'
local operatorHalo=0;HaloTextHelper.addTextWithArrow=function()operatorHalo=operatorHalo+1 end
local function fresh()
 local state=fixture('placed',true);__body.getPrimaryHandItem=function()return nil end;__body.getSecondaryHandItem=function()return nil end
 __body.setPrimaryHandItem=function()end;__body.setSecondaryHandItem=function()end
 __body.isTimedActionInstant=function()return false end;__body.setMetabolicTarget=function(_,v)__metabolic=v end
 __body.isDead=function()return false end
 ZombRand=function(a,b)if b then return a end;return 0 end
 __body:getModData().SAOPersonId='person';__body:getModData().PlayerVoice=0
 __seconds=1;__metabolic=nil;__sourceTick();__stats:set(CharacterStat.ENDURANCE,.8)
 return state
end
local function offer()local rows,why=M.offers('person',__body);assert(not why,tostring(why));for _,row in ipairs(rows)do if row.activity=='dance'then return row end end end
local function begin()
 local selected=assert(offer(),'source dance offer missing');local ok,w=M.begin('person',__body,selected,'purpose:1');assert(ok,tostring(w));local action=__queued;action:start();return w,action
end
local state=fresh();local fact=M.currentHeardMusic('person',__body)
check('acquired_native_source_hearing_fact',fact and fact.sourceKey==__row.key and fact.deviceUUID=='public:1'and fact.soundObserved)
local selected=offer();check('source_cycle_unit_explicit',selected and selected.participationUnit=='one-source-dance-cycle')
__hearing=false;check('native_receiver_hearing_required',offer()==nil and M.currentHeardMusic('person',__body)==nil)
state=fresh();__stopSound();check('no_actual_audio_no_dance_offer',offer()==nil)
state=fresh();NMPlaybackRuntime.Active={};__body:getModData().IsListeningToMusicStyle='disco'
check('stale_listening_flags_no_hearing_authority',offer()==nil)
state=fresh();__visible=false;check('hidden_source_no_dance_offer',offer()==nil)
state=fresh();local w,action=begin();__delta=1;action:perform()
check('premature_perform_has_no_credit',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0)
state=fresh();w,action=begin();__seconds=1;action:update()
check('ordinary_source_update_no_cycle_credit',M.outcome('person',w.sequence)==nil and __skillRequests==0 and __metabolic==Metabolics.Fitness)
check('private_caller_retains_nonzero_default_action_type',action.actionType=='Bob_PreDancingDefault' and action.AnimDelayEnd==40)
__seconds=40;action:update();local outcome=M.outcome('person',w.sequence)
check('actual_source_cycle_completed',outcome and outcome.status=='completed'and outcome.nativeProgress.sourceDanceCycle.sourceCallbackCompleted)
check('source_real_metabolic_and_mood_effects',__stats:get(CharacterStat.ENDURANCE)<.8 and __stats:get(CharacterStat.FATIGUE)>.2
 and __stats:get(CharacterStat.BOREDOM)<15 and __stats:get(CharacterStat.STRESS)<.2 and __stats:get(CharacterStat.UNHAPPINESS)<30)
check('exact_source_dancing_and_fitness_requests',__skillRequests==2 and __records.person.leisureMusicSkillRequests[1].perkName=='Dancing'
 and __records.person.leisureMusicSkillRequests[2].perkName=='Fitness')
check('native_perform_clears_source_flags',__body:getModData().IsDancingFull==false and __body:getModData().IsDancingPartner=='none')
check('adapted_source_lineage_four_sites',#outcome.sourceAdaptations.sites==4 and outcome.participationUnit=='one-source-dance-cycle')
check('private_source_action_binding_lineage_two_sites',#outcome.sourceAdaptations.ownershipSites==2
 and outcome.sourceAdaptations.rawRevision==outcome.revision and outcome.sourceAdaptations.derivedRevision.bytes>0)
check('dance_does_not_stop_public_music',__publicEmitter:isPlaying(NMPlaybackRuntime.Active['public:1'].soundId))
state=fresh();w,action=begin();__hearing=false;__seconds=50;action:update()
check('lost_current_music_interrupts_before_effect',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0 and math.abs(__stats:get(CharacterStat.ENDURANCE)-.8)<.00001)
state=fresh();w,action=begin();state.playbackEpoch=state.playbackEpoch+1;__sourceTick();__seconds=50;action:update()
check('source_epoch_change_interrupts',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0)
state=fresh();w,action=begin();__admit=false;__seconds=50;action:update()
check('lost_maintained_purpose_blocks_cycle',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0)
state=fresh();w,action=begin();__body:getModData().IsDancingPartner='source';__seconds=50;action:update()
check('unaccepted_partner_state_refused',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0)
state=fresh();w,action=begin();__body.isDead=function()return true end;M.interrupt('person',__body,'native-death')
check('native_death_clears_owned_source_flags',M.outcome('person',w.sequence).status=='interrupted'and __body:getModData().IsDancingFull==false)
state=fresh();w,action=begin();M.interrupt('person',__body,'urgent-need')
check('urgent_interrupt_no_completed_credit',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0)
state=fresh();w,action=begin();__body:getModData().LSMoodles.PartyGood.Value=.6;__body:getModData().LSMoodles.PartyBad.Value=0
action.voiceCooldown=0
ZombRand=function(a,b)if b then return a end;if a==20 then return 19 end;return 0 end
__seconds=40;action:update()
outcome=M.outcome('person',w.sequence)
check('private_source_note_sink',outcome and outcome.status=='completed'and outcome.nativeNotes and #outcome.nativeNotes>0)
local empty=true;for _,playing in pairs(__playing)do if playing then empty=false end end
check('captured_source_audio_owned_cleanup',empty and outcome.cleanupSucceeded)
check('operator_volume_and_clock_unchanged',__volume==.61 and __hours==10 and __milliseconds==100000)
-- Reentrant source XP happens after its cycle group, before its original
-- update returns. A partial callback cannot be converted into completion.
state=fresh();w,action=begin();__seconds=1;action:update()
local sourceConsume=SAO.LeisureSkill.consume;local reentered=false
SAO.LeisureSkill.consume=function(...)
 if not reentered then reentered=true;action:perform();return false end
 return sourceConsume(...)
end
__seconds=40;action:update();SAO.LeisureSkill.consume=sourceConsume
check('partial_original_callback_not_completed',reentered and M.outcome('person',w.sequence).status=='interrupted')
-- Whole installed repertoire and source-defined skill selection; the source
-- genre state below is controlled, never supplied as a fabricated acquired fact.
local genres={{'disco','disco'},{'salsa','salsa'},{'metal','club'},{'pop','common'}}
for _,genre in ipairs(genres)do
 for _,tier in ipairs({{0,'Basic'},{4,'Intermediate'},{8,'Advanced'}})do
  state=fresh();__level=tier[1];__body:getModData().IsListeningToMusicStyle=genre[1]
  ZombRand=function(a,b)if b then return a end;if a==30 then return 29 end;if a==20 then return 19 end;return 0 end
  w,action=begin();local repertoire=action[genre[2]..'Anim'..tier[2]];local exact={}
  for _,move in ipairs(repertoire)do exact[move.Anim]=true end
  __seconds=40;action:update();outcome=M.outcome('person',w.sequence)
  check('original_repertoire_'..genre[2]..'_'..tier[2],#repertoire>0 and exact[action.AnimToplay]
    and outcome and outcome.status=='completed')
 end
end
state=fresh();__level=10;w,action=begin();__seconds=40;action:update()
check('mastery_source_zero_XP_noop',M.outcome('person',w.sequence).status=='completed'and __skillRequests==0)
local function moodCycle(party,trait,endurance,mult)
 state=fresh();__body:getModData().LSMoodles.PartyGood.Value=party
 __body.hasTrait=function(_,t)return trait and t==CharacterTrait.PARTYANIMAL end
 __stats:set(CharacterStat.ENDURANCE,endurance);SandboxVars.Dancing.StrengthMultiplier=mult
 w,action=begin();__seconds=40;action:update();return M.outcome('person',w.sequence)
end
local base=moodCycle(0,false,.8,2);local good=moodCycle(.6,true,.8,2)
check('source_party_and_trait_weight_actual_moods',good.nativeProgress.sourceDanceCycle.moods.Boredom[1]<base.nativeProgress.sourceDanceCycle.moods.Boredom[1])
local exhausted=moodCycle(0,false,.35,2);local strong=moodCycle(0,false,.8,4)
check('source_endurance_and_sandbox_weight_actual_moods',exhausted.nativeProgress.sourceDanceCycle.moods.Boredom[1]>base.nativeProgress.sourceDanceCycle.moods.Boredom[1]
 and strong.nativeProgress.sourceDanceCycle.moods.Boredom[1]<base.nativeProgress.sourceDanceCycle.moods.Boredom[1])
SandboxVars.Dancing.StrengthMultiplier=2
state=fresh();__body:getModData().DidFitnessActivity=0;__body:getModData().FitnessActivityMuscles=0
w,action=begin();__seconds=40;action:update()
check('original_fitness_muscle_load',__body:getModData().DidFitnessActivity==1 and __body:getModData().FitnessActivityMuscles==1.5)
-- Actual source RNG chooses a critical fall, then original elapsed-source
-- updates play scream/impact and stop applies pain/embarrassment. No invented timer.
local function beginFall()
 state=fresh();ZombRand=function(a,b)if b then return a end;if a==100 then return 99 end;if a==2 then return 1 end;return 0 end
 w,action=begin();__seconds=40;action:update();return w,action
end
w,action=beginFall()
check('original_failed_move_stays_in_source_sequence',action.criticalFailure==2 and action.AnimToplay=='Bob_DancingUnskilledB' and M.outcome('person',w.sequence)==nil)
__seconds=2;action:update();__seconds=10;action:update()
check('original_fall_scream_and_impact',#__played==2 and string.sub(__played[1],1,7)=='ManFall'and string.sub(__played[2],1,12)=='Body_Falling')
__seconds=60;action:update();outcome=M.outcome('person',w.sequence)
check('original_failed_move_native_pain_and_embarrassment',outcome and outcome.status=='interrupted'and __stats:get(CharacterStat.PAIN)==40
 and __body:getModData().LSMoodles.Embarrassed.Value==.25 and __skillRequests==2)
check('private_dance_Halo_never_operator',operatorHalo==0 and outcome.nativeNotes and #outcome.nativeNotes>=2)
empty=true;for _,playing in pairs(__playing)do if playing then empty=false end end
check('failed_source_sequence_captured_audio_cleanup',empty and outcome.cleanupSucceeded)
w,action=beginFall();__seconds=2;action:update();local beforePain=__stats:get(CharacterStat.PAIN);local beforeXP=__skillRequests
__body.isDead=function()return true end;M.interrupt('person',__body,'native-death')
empty=true;for _,playing in pairs(__playing)do if playing then empty=false end end
check('dead_failure_cleanup_no_injury_XP_or_effect_replay',empty and __stats:get(CharacterStat.PAIN)==beforePain and __skillRequests==beforeXP
 and __body:getModData().LSMoodles.Embarrassed.Value==0 and M.outcome('person',w.sequence).status=='interrupted')
state=fresh();w,action=begin();__seconds=1;action:update();M.reset('source-reload')
check('reload_partial_source_never_completes',M.outcome('person',w.sequence).status=='interrupted'and __skillRequests==0)
state=fresh();w,action=begin();local foreign={};local interrupted=M.interrupt('person',foreign,'foreign')
check('foreign_body_cannot_interrupt_native_work',interrupted==false and M.work('person').status=='active')
__seconds=40;action:update();local prior=M.outcome('person',w.sequence);local effects=__skillRequests;action:update();action:perform()
check('duplicate_source_callbacks_no_replay',M.outcome('person',w.sequence).status=='completed'and effects==__skillRequests
 and prior.workId==M.outcome('person',w.sequence).workId)
print('PASS D2 source dance '..count)
