local L=SAO.LeisureLifestyle;local n=0
local function check(name,v)n=n+1;assert(v,'OWNED_LIFESTYLE:'..name);print('CASE '..name)end
__freshLifestyle();local offer=__offer('turn-on-jukebox');check('owned_station_offer',offer~=nil)
local seq=__start('turn-on-jukebox');__complete();check('owned_original_station_effect',L.outcome('person',seq).status=='completed'and __station:getModData().OnOff=='on')
__freshLifestyle();local stale=__offer('turn-on-jukebox');__externalSource='LifestyleHobbies'
check('private_source_available_with_external',SAO.SourceIntegration.available('LifestyleHobbies')==true)
local rows=L.offers('person',__body);local physical=false
for _,row in ipairs(rows)do if row.activity=='turn-on-jukebox'or row.activity=='turn-off-jukebox'
 or row.activity=='select-jukebox-music'then physical=true end end
check('private_station_offer_with_external',not physical)
local admitted=L.begin('person',__body,stale,'purpose:1')
check('stale_physical_offer_refused_with_external',admitted==false)
local d=__station:getModData();d.OnOff='on';d.OnPlay='playing';d.genre='source-track'
d.Emitter=__worldEmitter;d.OnPlayEMITTER=__worldEmitter:playSound('source-track')
local heard=L.currentHeardMusic('person',__body)
check('personal_original_hearing_with_external',heard and heard.sourceContext=='lifestyle-jukebox'
 and heard.nativeHeard==true and heard.sourceSoundId==d.OnPlayEMITTER)
local listen=false
for _,row in ipairs(L.intentOffers('person',__body))do if row.activity=='listen-lifestyle-music'then listen=true end end
check('personal_listening_offer_with_external',listen)
__externalSource=nil
print('PASS owned lifestyle '..n)
