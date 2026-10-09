local checks=0;local L=SAO.LeisureLifestyle
local function check(v,name)assert(v,'D2_NATIVE_LIFESTYLE:'..name);checks=checks+1 end
__stats=__nativeBody:getStats();__freshLifestyle('dj');local controlled=__body;__body=__nativeBody;__stats=__body:getStats();__initSourceTraits()
local body=__body;body:setX(10.5);body:setY(20.5);body:setPrimaryHandItem(nil);body:setSecondaryHandItem(nil)
local md=body:getModData();md.SAOPersonId='person';md.SAOExternalToken='native:lifestyle:1';md.PlayerVoice=0;LSMoodleManager.init(body)
__records={person={id='person'}};SAO.Body={get=function(id)return id=='person'and body or nil end}
SAO.Needs.ownsRecoveryBody=function(id,b)return id=='person'and b==body end
SandboxVars.Text={}
SAO.LeisureMusic={prepareActor=function(id,b)LSMoodleManager.init(b);return true end}
local initialized,why=L.prepareActor('person',body);check(initialized,'original_native_tracker_initializer:'..tostring(why))

SAO.Perception.leisureObjects=function()
 return{{actorId='person',key='station',runtimeInstance='native:station:1',x=10,y=19,z=0,customName='Booth',spriteName='ls_djbooth_01_1'},
 {actorId='person',key='part1',runtimeInstance='native:part1:1',x=9,y=19,z=0,customName='Booth',spriteName='ls_djbooth_01_0'},
 {actorId='person',key='part2',runtimeInstance='native:part2:1',x=11,y=19,z=0,customName='Booth',spriteName='ls_djbooth_01_2'}}
end
SAO.Perception.resolveLeisureObject=function(id,b,key)
 if id~='person'or b~=body then return nil end
 return key=='station'and __station0 or key=='part1'and __station1 or key=='part2'and __station2 or nil
end
SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)local w=L.work(id);if __admit and w and w.workId==wid and w.purposeId==pid then w.ownerName='SAO.LeisureLifestyle';return w end end
__stats:set(CharacterStat.ENDURANCE,.8);__stats:set(CharacterStat.FATIGUE,.2);__stats:set(CharacterStat.STRESS,.2);__stats:set(CharacterStat.BOREDOM,15);__stats:set(CharacterStat.UNHAPPINESS,30)
body:setPerkLevelDebug(Perks.Music,0)
check(body:isExistInTheWorld()and body:getPlayerNum()==1,'actual_native_offslot_body')
check(__station1:getSquare():getObjects():contains(__station1)and __station2:getSquare():getObjects():contains(__station2)and __station0:getSquare():getObjects():contains(__station0)and __station0:getSprite():getProperties():get('CustomName')=='Booth','actual_native_source_station')
SandboxVars.ElecShutModifier=30
local offer=__offer('perform-dj');local ok,seq=L.begin('person',body,offer,'purpose:1');check(ok,'canonical_native_admission')
local action=__queued;action:start();check(md.PlayingInstrument==true,'actual_original_source_started')
local xp=body:getXp():getXP(Perks.Music);for n=1,100 do action:update()end
check(action.gameSound~=0 and __emitter:isPlaying(action.gameSound),'actual_source_native_emitter_call')
__emitter:finish();__delta=1;action:update();local result=L.outcome('person',seq)
check(result and result.status=='completed','source_ended_native_result')
local r=SAO.LeisureSkill.receipt('person','SAO.LeisureLifestyle',seq,1)
check(r and r.status=='applied'and body:getXp():getXP(Perks.Music)>xp,'actual_native_Music_XP')
check(__stats:get(CharacterStat.ENDURANCE)<.8 and __stats:get(CharacterStat.FATIGUE)>.2 and __stats:get(CharacterStat.BOREDOM)<15,'actual_native_source_stats')
local after=body:getXp():getXP(Perks.Music);action:perform();action:update();check(body:getXp():getXP(Perks.Music)==after,'native_duplicate_callbacks_no_extra_XP')
check(__volume==.61,'native_operator_volume_unchanged')
check(L.work('person')==nil and not md.PlayingInstrument,'native_source_owner_cleanup')
local juke=__nativeJukebox;juke:getModData().OnOff='off'
SAO.Perception.leisureObjects=function()return{{actorId='person',key='station',runtimeInstance='native:juke:1',x=10,y=19,z=0,customName='Jukebox',spriteName='source-jukebox-fixture'}}end
SAO.Perception.resolveLeisureObject=function(id,b,key)return id=='person'and b==body and key=='station'and juke or nil end
__worldEmitter={playSound=function(_,name)return __emitter:playSound(name)end,playSoundImpl=function(_,name)return __emitter:playSound(name)end,
 isPlaying=function(_,h)return __emitter:isPlaying(h)end,stopSound=function(_,h)return __emitter:stopSound(h)end,
 stopSoundByName=function(_,name)return 0 end,setPos=function()end,setVolume=function()end,set3D=function()end}
seq=__start('turn-on-jukebox');__complete();result=L.outcome('person',seq)
check(result and result.status=='completed'and juke:getModData().OnOff=='on','native_original_jukebox_on')
seq=__start('select-jukebox-music');__complete();result=L.outcome('person',seq)
check(result and result.status=='completed'and juke:getModData().OnPlay=='playing','native_original_jukebox_play')
check(L.currentHeardMusic('person',body).sourceSoundId==juke:getModData().OnPlayEMITTER,'native_exact_jukebox_source_hearing')
seq=__start('listen-lifestyle-music');local stress=__stats:get(CharacterStat.STRESS)
__engineHours=__engineHours+1/60;__event('EveryOneMinute');__engineHours=__engineHours+1/6;__event('EveryTenMinutes')
result=L.outcome('person',seq)
check(result and result.status=='completed'and __stats:get(CharacterStat.STRESS)<stress,'native_original_listener_Stats')
check(result.afterSourceMoodles.MusicGood.Value>0 and result.beforeSourceMoodles.MusicGood.Value==0,'native_original_music_moodle_accounting')
seq=__start('turn-off-jukebox');__complete();check(juke:getModData().OnOff=='off'and L.outcome('person',seq).status=='completed','native_original_jukebox_off')
print('PASS native Lifestyle '..checks)
