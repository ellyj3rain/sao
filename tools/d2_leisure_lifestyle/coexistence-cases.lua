local L=SAO.LeisureLifestyle;local checks=0
local function check(value,name)assert(value,'D2_COEXISTENCE:'..name);checks=checks+1;print('COEXISTENCE '..name)end
local function setup()
 __freshLifestyle();__start('turn-on-jukebox');__complete();__start('select-jukebox-music');__complete()
 local object=__station;local pdata={};local px,py=1000,1000
 local player={getX=function()return px end,getY=function()return py end,getZ=function()return 0 end,getModData=function()return pdata end}
 local g=setmetatable({},{__index=_G});g._G=g;g.SAO=SAO;g.__physicalCalls=0
 g.getPlayer=function()return player end;g.getCell=function()return object:getCell()end
 g.require=function(name)
  if name=='SAO_SourceIntegration'then return SAO.SourceIntegration end
  if name=='Properties/Objects/List'then return g.objects end
  local src=__sources['LifestyleHobbies:client/'..name..'.lua']or __sources['LifestyleHobbies:shared/'..name..'.lua']
  if src then local fn=assert(loadstring(src,name));setfenv(fn,g);return fn()end
 end
 local function loadOwned(name)local fn=assert(loadstring(__sources['Owned:'..name],name));setfenv(fn,g);fn()end
 g.objects={object};loadOwned('InteractionRange');loadOwned('LSEffectsAux');g.require('DiscoStateChange');g.require('LSEffectsJukeboxFunctions')
 local prior=g.OnJukeboxStyleChange
 g.OnJukeboxStyleChange=function(...)g.__physicalCalls=g.__physicalCalls+1;return prior(...)end
 return object,g,player,pdata,function(x,y)px,py=x,y end
end
local object,g,player,pdata,position=setup();local d=object:getModData();local handle=d.OnPlayEMITTER
check(L.physicalSourceOwner(object)==true,'lease_from_completed_native_work')
check(L.physicalSourceOwner({})==false and L.physicalSourceOwner(nil)==false,'exact_object_only')
g.LSrefreshJB(player);g.JukeboxMusicCheck(player)
check(d.JukeinRange=='in range'and d.SilenceMusic~='yes'and d.OnPlayEMITTER==handle and __playing[handle],'operator_far_cannot_silence_owned_source')
position(10,10);g.LSrefreshJB(player);check(pdata.IsListeningToJukebox==true,'near_player_listener_preserved')
position(1000,1000);g.LSrefreshJB(player);check(not pdata.IsListeningToJukebox,'far_player_listener_original_range')
position(10,10);local sourceClock=__milliseconds
__playing[handle]=false;g.JukeboxMusicCheck(player)
check(d.genre~='JukeboxAfterTurnOn'and g.__physicalCalls==0,'global_cannot_advance_owned_track')
__event('OnTick');check(d.genre=='JukeboxAfterTurnOn','private_original_advances_real_ending_once')
g.JukeboxMusicCheck(player);check(g.__physicalCalls==0,'global_cannot_advance_owned_pause')
__milliseconds=sourceClock+4000;g.JukeboxMusicCheck(player);check(g.__physicalCalls==0,'operator_clock_cannot_duplicate_scheduler')
__event('OnTick');check(d.genre~='JukeboxAfterTurnOn'and d.OnPlay=='playing','private_original_pause_ends_once')
check(__milliseconds==sourceClock+4000,'source_clock_unchanged')
local privateHandle=d.OnPlayEMITTER;local calls=g.__physicalCalls;__owned=false
check(not L.physicalSourceOwner(object),'owner_loss_releases_lease')
g.JukeboxMusicCheck(player);check(g.__physicalCalls==calls,'owner_loss_no_fabricated_new_track')
__event('OnTick');check(not __playing[privateHandle],'owner_loss_private_captured_sound_retired')
object,g,player,pdata,position=setup();d=object:getModData();privateHandle=d.OnPlayEMITTER
__body:getModData().SAOExternalToken='generation:replacement'
check(not L.physicalSourceOwner(object),'body_token_replacement_releases_lease')
__event('OnTick');check(not __playing[privateHandle],'body_replacement_retirement_exact_old_sound')
object,g,player,pdata,position=setup();d=object:getModData();local originalRec=__records.person;__records.person=__roundtrip(originalRec)
check(not L.physicalSourceOwner(object),'record_replacement_releases_lease')
__event('OnTick');__records.person=originalRec;check(not L.physicalSourceOwner(object),'retired_core_not_restored_by_saved_receipt')
object,g,player,pdata,position=setup();d=object:getModData();__power=false
check(not L.physicalSourceOwner(object),'power_loss_releases_lease')
__event('OnTick');check(not L.physicalSourceOwner(object),'power_retirement_no_stale_lease')
object,g,player,pdata,position=setup();d=object:getModData();__records.person.leisureLifestyleOutcomes={}
check(not L.physicalSourceOwner(object),'canonical_source_receipt_required')
__event('OnTick')
object,g,player,pdata,position=setup();d=object:getModData();position(1000,1000)
L.reset('explicit-release');check(not L.physicalSourceOwner(object),'explicit_reset_releases_lease')
d.OnOff='on';d.OnPlay='playing';d.JukeinRange='in range';d.genre='foreign-song';d.Emitter=__worldEmitter;d.OnPlayEMITTER=__worldEmitter:playSound('foreign-song')
g.LSrefreshJB(player);check(d.JukeinRange=='out of range'and d.SilenceMusic=='yes','unowned_global_range_preserved')
g.JukeboxMusicCheck(player);check(d.OnPlay=='nothing'and d.SilenceMusic=='no','unowned_global_silence_preserved')
position(10,10);d.JukeinRange='in range';d.OnPlay='playing';d.genre='foreign-song';d.Length=0;d.OnPlayEMITTER=99999
local calls=g.__physicalCalls;g.JukeboxMusicCheck(player)
check(g.__physicalCalls==calls+1 and d.genre=='JukeboxAfterTurnOn','unowned_global_ending_preserved')
check(__volume==.61,'operator_volume_unchanged')
object,g,player,pdata,position=setup();d=object:getModData();privateHandle=d.OnPlayEMITTER
local originalActive=SAO.SourceIntegration.active
SAO.SourceIntegration.active=function(id)
 if id=='LifestyleHobbies' then return false end
 return originalActive(id)
end
check(not L.physicalSourceOwner(object),'external_activation_releases_private_station_lease')
__event('OnTick')
check(not __playing[privateHandle]and not L.physicalSourceOwner(object),'external_activation_retires_captured_sound')
SAO.SourceIntegration.active=originalActive
print('PASS D2 coexistence '..checks)
