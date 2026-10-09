-- Appended to native-cases in the same actual native body/station fixture.
seq=__start('turn-on-jukebox');__complete();seq=__start('select-jukebox-music');__complete()
local operator=__other;operator:setX(1000);operator:setY(1000)
local g=setmetatable({},{__index=_G});g._G=g;g.SAO=SAO;g.getPlayer=function()return operator end
local list={juke};g.getCell=function()return juke:getCell()end
local function sourceRequire(name)
 if name=='SAO_SourceIntegration'then return SAO.SourceIntegration end
 if name=='Properties/Objects/List'then return list end
 local src=__sources['LifestyleHobbies:client/'..name..'.lua']or __sources['LifestyleHobbies:shared/'..name..'.lua']
 if src then local fn=assert(loadstring(src,name));setfenv(fn,g);return fn()end
end
g.require=sourceRequire
for _,name in ipairs({'InteractionRange','LSEffectsAux'})do local fn=assert(loadstring(__sources['Owned:'..name],name));setfenv(fn,g);fn()end
sourceRequire('LSEffectsJukeboxFunctions')
local d=juke:getModData();local handle=d.OnPlayEMITTER
check(L.physicalSourceOwner(juke),'native_current_exact_physical_lease')
g.LSrefreshJB(operator);g.JukeboxMusicCheck(operator)
check(d.JukeinRange=='in range'and d.SilenceMusic~='yes'and __emitter:isPlaying(handle),'native_far_operator_cannot_silence')
operator:setX(10.5);operator:setY(20.5);g.LSrefreshJB(operator)
check(operator:getModData().IsListeningToJukebox==true,'native_operator_listening_preserved')
__emitter:finish();g.JukeboxMusicCheck(operator)
check(d.genre~='JukeboxAfterTurnOn','native_global_cannot_advance_owned_ending')
__event('OnTick');check(d.genre=='JukeboxAfterTurnOn','native_private_original_ending_once')
local before=__milliseconds;__milliseconds=before+4000;g.JukeboxMusicCheck(operator)
check(d.genre=='JukeboxAfterTurnOn','native_global_cannot_advance_owned_pause')
__event('OnTick');check(d.OnPlay=='playing'and d.genre~='JukeboxAfterTurnOn','native_private_original_next_track_once')
check(__milliseconds==before+4000,'native_source_clock_unchanged')
local last=d.OnPlayEMITTER;md.SAOExternalToken='native:replacement';check(not L.physicalSourceOwner(juke),'native_body_token_loss_releases_lease')
__event('OnTick');check(not __emitter:isPlaying(last),'native_owned_sound_cleanup_after_generation_loss')
print('PASS native Lifestyle '..checks)
