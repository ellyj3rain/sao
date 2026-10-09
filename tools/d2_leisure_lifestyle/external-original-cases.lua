-- Selected original source callbacks run beside one SAO-owned physical station.
local L=SAO.LeisureLifestyle
local checks=0
local function check(name,ok)
 assert(ok,'D2_EXTERNAL_ORIGINAL:'..name)
 checks=checks+1
end
__freshLifestyle()
local object=__station
local pdata={}
local px,py=1000,1000
local player={getX=function()return px end,getY=function()return py end,
 getZ=function()return 0 end,getModData=function()return pdata end}
local g=setmetatable({},{__index=_G});g._G=g;g.SAO=SAO
g.getPlayer=function()return player end
g.getCell=function()return object:getCell()end
g.objects={object}
g.require=function(name)
 if name=='Properties/Objects/List'then return g.objects end
 local source=__sources['LifestyleHobbies:client/'..name..'.lua']
  or __sources['LifestyleHobbies:shared/'..name..'.lua']
 if source then local fn=assert(loadstring(source,name));setfenv(fn,g);return fn()end
end
g.require('InteractionRange')
g.require('LSEffectsAux')
g.require('DiscoStateChange')
g.require('LSEffectsJukeboxFunctions')
OnJukeboxStyleChange=function()end
check('original_range_callback',type(g.LSrefreshJB)=='function')
check('original_track_callback',type(g.JukeboxMusicCheck)=='function')

local priorRequire=require
require=function(name)
 if name=='Properties/Objects/List'then return g.objects end
 return g.require(name)or priorRequire(name)
end
local registry=SAO.SourceIntegration
local priorExternal=registry.externalSelected
registry.externalSelected=function(id)return id=='LifestyleHobbies'end
local originalPlayCalls,originalTurnCalls=0,0
local releasedAtPlay=false
local menuSource=__sources['LifestyleHobbies:client/JukeboxContextMenu.lua']
check('selected_original_menu_loaded',type(menuSource)=='string')
local menuEnv=setmetatable({},{__index=_G});menuEnv._G=menuEnv
menuEnv.LS_FileMng={getLineValue=function()return .7 end,
 getOrCreateLineValue=function()return true end}
menuEnv.LSUtil={walkToAdj=function()return true end,
 walkToFront=function()return true end,
 isValidObj=function()return true end,sqrHasEnergy=function()return true end}
menuEnv.JukeboxPlay={new=function(_,_,selected)return{kind='play',object=selected}end}
menuEnv.JukeboxOn={new=function(_,_,selected)return{kind='on',object=selected}end}
menuEnv.JukeboxOff={new=function(_,_,selected)return{kind='off',object=selected}end}
menuEnv.ISTimedActionQueue={add=function(action)
 if action.kind=='play'then
  originalPlayCalls=originalPlayCalls+1
  releasedAtPlay=action.object==object and not L.physicalSourceOwner(action.object)
 else originalTurnCalls=originalTurnCalls+1 end
end}
local selectedMenuChunk=assert(loadstring(menuSource,'selected-original-jukebox-menu'))
setfenv(selectedMenuChunk,menuEnv);selectedMenuChunk()
JukeboxMenu=menuEnv.JukeboxMenu
check('selected_original_callbacks',type(JukeboxMenu.onPlay)=='function'
 and type(JukeboxMenu.onTurnOnOff)=='function'
 and JukeboxMenu.onTurnOn==nil and JukeboxMenu.onTurnOff==nil)
local originalOnPlay=JukeboxMenu.onPlay
JukeboxMenu.onTurnOnOff(player,object,{nil,nil,'On',false})
check('selected_original_turn_action',originalTurnCalls==1)
_G.LSrefreshJB=g.LSrefreshJB
_G.JukeboxMusicCheck=g.JukeboxMusicCheck
local offer
for _,row in ipairs(L.offers('person',__body))do
 if row.activity=='turn-on-jukebox'then offer=row;break end
end
check('private_physical_offer_with_external',offer and offer.activity=='turn-on-jukebox')
check('external_callbacks_wrapped',_G.LSrefreshJB~=g.LSrefreshJB
 and _G.JukeboxMusicCheck~=g.JukeboxMusicCheck)
local seq=__start('turn-on-jukebox');__complete()
seq=__start('select-jukebox-music');__complete()
local d=object:getModData();local handle=d.OnPlayEMITTER
check('private_station_current',L.physicalSourceOwner(object)and __playing[handle])
_G.LSrefreshJB(player);_G.JukeboxMusicCheck(player)
check('far_operator_cannot_silence_private_station',d.JukeinRange=='in range'
 and d.SilenceMusic~='yes'and __playing[handle])
px,py=10,10
_G.LSrefreshJB(player)
check('operator_listening_preserved',pdata.IsListeningToJukebox==true)
JukeboxMenu.configVol=.42
__event('OnTick')
check('operator_volume_reaches_private_source',d.JukeboxVolume==.42)
__playing[handle]=false
_G.JukeboxMusicCheck(player)
check('external_cannot_advance_private_ending',d.genre~='JukeboxAfterTurnOn')
__event('OnTick')
check('private_source_advances_once',d.genre=='JukeboxAfterTurnOn')

local wrappedRange=_G.LSrefreshJB
_G.LSrefreshJB=g.LSrefreshJB;_G.JukeboxMusicCheck=g.JukeboxMusicCheck
JukeboxMenu.onPlay=originalOnPlay
check('callback_replacement_releases_claim',not L.physicalSourceOwner(object))
__event('OnTick')
check('lifecycle_rewrap_restores_claim',_G.LSrefreshJB~=wrappedRange
 and _G.LSrefreshJB~=g.LSrefreshJB and L.physicalSourceOwner(object))
local privateHandle=d.OnPlayEMITTER
JukeboxMenu.onPlay(player,object,{nil,nil,nil,nil,nil,false})
check('operator_action_receives_released_station',releasedAtPlay)
check('player_control_handoff',originalPlayCalls==1 and not L.physicalSourceOwner(object)
 and not __playing[privateHandle])
check('original_external_callbacks_remain_available',type(_G.JukeboxMusicCheck)=='function')
registry.externalSelected=priorExternal
require=priorRequire
print('PASS D2 external original '..checks)
