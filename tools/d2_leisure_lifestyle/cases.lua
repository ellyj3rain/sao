local L=SAO.LeisureLifestyle;local checks=0
local function check(v,name)assert(v,'D2_LIFESTYLE:'..name);checks=checks+1 end
__freshLifestyle();local offered=__offer('turn-on-jukebox')
check(offered.sourceProducer=='shared/TimedActions/JukeboxOn.lua','source_constructor_named')
offered.actorId='foreign';check(not L.begin('person',__body,offered,'purpose:1'),'spoof_refused')
__freshLifestyle();local offer=__offer('turn-on-jukebox');__owned=false
check(not L.begin('person',__body,offer,'purpose:1'),'foreign_body_refused')
__freshLifestyle();offer=__offer('turn-on-jukebox');__admit=false
check(not L.begin('person',__body,offer,'purpose:1')and not __queued,'planner_refusal_no_effect')
__freshLifestyle();local seq=__start('turn-on-jukebox');check(__animation=='Loot','original_native_animation')
__delta=.4;__queued:perform();check(not L.outcome('person',seq),'partial_action_no_terminal')
__complete();local result=L.outcome('person',seq)
check(result and result.status=='completed'and __station:getModData().OnOff=='on','original_turn_on_physical_state')
check(result.cleanupSucceeded and result.nativeProgress.observedUpdates==0,'control_no_fake_music_participation')
seq=__start('select-jukebox-music');__complete();result=L.outcome('person',seq)
check(result and result.status=='completed'and __station:getModData().OnPlay=='playing','original_world_source_playback')
local originalObjects=__objects;local other={};for k,v in pairs(__station)do other[k]=v end
local otherState={OnOff='on'};other.getModData=function()return otherState end
__objectHandles.secondStation=other;__objects={originalObjects[1],{actorId='person',key='secondStation',runtimeInstance='station:2',x=10,y=10,z=0,customName='Jukebox',spriteName='ls_jukebox_01_0'}}
local stationStyles={};for _,row in ipairs(L.offers('person',__body))do if row.activity=='select-jukebox-music'then stationStyles[row.objectKey]=(stationStyles[row.objectKey]or 0)+1 end end
check(stationStyles.station==15 and stationStyles.secondStation==15,'all_acquired_station_style_opportunities')
__objects=originalObjects;__objectHandles.secondStation=nil
local fact=L.currentHeardMusic('person',__body);check(fact and fact.sourceKey=='station'and fact.soundObserved,'acquired_actual_jukebox_heard')
__hearing=false;check(not L.currentHeardMusic('person',__body),'native_hearing_required');__hearing=true
__playing[__station:getModData().OnPlayEMITTER]=false;check(not L.currentHeardMusic('person',__body),'actual_emitter_required')
__event('OnTick');check(__station:getModData().genre=='JukeboxAfterTurnOn','original_real_ending_scheduler_pause')
__milliseconds=__milliseconds+4000;__event('OnTick');check(__station:getModData().OnPlay=='playing'and __station:getModData().genre~='JukeboxAfterTurnOn','original_scheduler_selects_next_track')
seq=__start('listen-lifestyle-music');__engineHours=__engineHours+1/60;__event('EveryOneMinute')
check(not L.outcome('person',seq),'source_listener_pending_not_completion')
local stress=LSUtil.getCharacterMood(__body,'Stress');__engineHours=__engineHours+1/6;__event('EveryTenMinutes')
result=L.outcome('person',seq);check(result and result.status=='completed'and LSUtil.getCharacterMood(__body,'Stress')<stress,'native_accounting_applies_mood')
check(result.nativeProgress.sourceListenerInvocations==1 and result.nativeProgress.sourceMoodCalls==1,'exact_original_listener_accounting')
check(__volume==.61,'operator_volume_unchanged')
local saved=__roundtrip(result);saved.status='forged';check(L.outcome('person',seq).status=='completed','detached_persisted_receipt')
seq=__start('turn-off-jukebox');__complete();check(L.outcome('person',seq).status=='completed'and __station:getModData().OnOff=='off','original_off_physical_source')
__freshLifestyle();__sourceDrift=true;local rows,reason=L.offers('person',__body)
-- Catalogue was already validated and cached, so construction must revalidate
-- the action and its dependencies at admission.
if #rows>0 then check(not L.begin('person',__body,rows[1],'purpose:1'),'source_drift_refused')else check(reason~=nil,'source_drift_refused')end
__freshLifestyle('dj');check(#__objects==3,'actual_source_tripart_station')
local slow=__offer('perform-dj');check(slow.track.mode=='slow','source_skill_gate_slow')
seq=__start('perform-dj');check(__body:getModData().PlayingInstrument==true,'original_dj_source_started')
for n=1,100 do if __queued then __queued:update()end end
check(__queued and __queued.gameSound~=0 and __playing[__queued.gameSound],'original_dj_real_track_started')
__delta=1;__queued:perform();check(not L.outcome('person',seq)or L.outcome('person',seq).status~='completed','no_timer_dj_completion')
__freshLifestyle('dj');seq=__start('perform-dj');for n=1,100 do __queued:update()end
local action=__queued;__playing[action.gameSound]=false;__delta=1;action:update();result=L.outcome('person',seq)
check(result and result.status=='completed'and result.nativeProgress.soundObserved,'real_dj_source_ending_receipt')
check(result.nativeProgress.sourceMoodCalls>0 and __skillRequests>0,'original_dj_native_effect_and_xp_request')
check(__volume==.61,'dj_operator_volume_unchanged')
-- Source input stops its old handle before a later native milestone starts the next.
__freshLifestyle('dj');seq=__start('perform-dj');for n=1,100 do __queued:update()end
local mixing=__queued;local oldHandle=mixing.gameSound;__level=3;mixing.keyPause=false;mixing.countstart=0;mixing.countend=10000
mixing:update();mixing:update()
check(not L.outcome('person',seq)and mixing.mode=='medium'and not __playing[oldHandle],'source_mix_not_terminal')
L.interrupt('person',__body,'mix-test-end')
-- Preserve original failure RNG, embarrassment, failure clips and recovery.
__freshLifestyle('dj');seq=__start('perform-dj');for n=1,100 do __queued:update()end
local failing=__queued;local originalRandom=ZombRand
ZombRand=function(a,b)if b==200 then return 199 end;if b then return a end;return 0 end
failing.countstart=failing.countend;failing:update();check(failing.Failstate==true,'source_random_failure')
failing.countstart=failing.countend;failing:update();ZombRand=originalRandom
check(failing.audio=='dj_booth_fail3'and __body:getModData().LSMoodles.Embarrassed.Value>.0,'source_failure_embarrassment')
__playing[failing.gameSound]=false;failing.countstart=0;failing.countend=10000;failing:update()
check(not L.outcome('person',seq),'failure_sound_not_success')
L.interrupt('person',__body,'failure-test-end')
-- Only acquired, currently seen source-range contacts enter original audience math.
__freshLifestyle('dj');seq=__start('perform-dj')
local sourceBody=__body;local contacts={};local people={person=sourceBody}
for n=1,3 do local peer={};for k,v in pairs(sourceBody)do peer[k]=v end;people['audience'..n]=peer;contacts[n]={id='audience'..n}end
people.unknown=sourceBody
SAO.Body.get=function(id)return people[id]end;SAO.Perception.knownPeople=function()return contacts end
__engineHours=__engineHours+1/6;__event('EveryTenMinutes');local audienceWork=L.work('person')
check(audienceWork and audienceWork.nativeProgress.sourceAcquiredAudience==3,'acquired_source_audience_only')
check(sourceBody:getModData().LSMoodles.DJAudience.Value==.2,'original_source_audience_moodle')
local audienceValue=sourceBody:getModData().LSMoodles.DJAudience.Value;__event('EveryTenMinutes')
check(sourceBody:getModData().LSMoodles.DJAudience.Value==audienceValue,'audience_duplicate_callback_no_effect')
L.interrupt('person',sourceBody,'audience-test-end');SAO.Perception.knownPeople=function()return{}end
-- A faulty source stop still receives independent captured-handle cleanup.
__freshLifestyle('dj');seq=__start('perform-dj');for n=1,100 do __queued:update()end
local faulty=__queued;local ownedHandle=faulty.gameSound;faulty.stop=function()error('controlled-native-source-stop-fault')end
check(L.interrupt('person',__body,'fault-test'),'source_stop_fault_contained')
result=L.outcome('person',seq)
check(result and result.status=='interrupted'and not result.cleanupSucceeded and not __playing[ownedHandle]and not L.work('person'),'captured_cleanup_after_fault')
__freshLifestyle('dj');seq=__start('perform-dj');__objectHandles.part2=nil
check(not L.advance('person',__body)and L.outcome('person',seq).status=='interrupted','source_side_custody_lost')
__freshLifestyle('dj');seq=__start('perform-dj');__bodyDead=true;L.interrupt('person',__body,'death')
check(L.outcome('person',seq).status=='interrupted'and __skillRequests==0,'death_no_source_effect_replay')
__freshLifestyle('dj');local staleDJ=__offer('perform-dj');local selectedMenu=DJBoothMenu;DJBoothMenu=nil
local absentRows=L.offers('person',__body);local absentDJ=true
for _,row in ipairs(absentRows)do if row.activity=='perform-dj'then absentDJ=false end end
check(absentDJ,'missing_menu_refuses_dj_offer')
check(not L.begin('person',__body,staleDJ,'purpose:1'),'missing_menu_refuses_dj_begin')
DJBoothMenu=selectedMenu
__freshLifestyle();seq=__start('turn-on-jukebox');local stored=__roundtrip(__records.person);L.reset('reload');__records.person=stored;L.advance('person',__body)
check(L.outcome('person',seq).status=='interrupted','reload_no_fabricated_completion')
__freshLifestyle();seq=__start('turn-on-jukebox');stored=__roundtrip(__records.person);L.reset('controlled-runtime-loss');__records.person=stored
local consumedBefore=__consumed;local retryRows=L.offers('person',__body);local orphan=L.outcome('person',seq)
check(orphan and orphan.status=='interrupted'and orphan.reason=='source-runtime-not-revalidated'and orphan.purposeId=='purpose:1'and orphan.afterCurrent==false,'offer_archives_lost_runtime')
check(__consumed==consumedBefore+1 and __records.person.leisureLifestyleWork==nil,'orphan_typed_consumption_once')
L.offers('person',__body);check(__consumed==consumedBefore+1,'orphan_duplicate_no_consumption')
local admittedAgain,nextSequence=L.begin('person',__body,retryRows[1],'purpose:1')
check(admittedAgain and nextSequence>seq and L.outcome('person',seq).reason=='source-runtime-not-revalidated','retry_preserves_original_terminal')
print('PASS D2 Lifestyle '..checks)
