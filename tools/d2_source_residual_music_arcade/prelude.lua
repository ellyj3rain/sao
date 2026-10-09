CHECKS=0
function check(ok,name)if not ok then nativeFail(name)end CHECKS=CHECKS+1 end
SAO={SourceIntegration={active=function()return true end}}
function require(name)return CATALOGUES[name] or {}end
function isServer()return SERVER==true end
function isClient()return MODE=='worldsounds' end
NOW=10000
function getTimestampMs()return NOW end
function getTimeInMillis()return NOW end
function getTimestamp()return NOW/1000 end
function getText(key)return key end
function getTexture(key)return key end
function ZombRand()return 0 end
function ZombRandFloat(a,b)return a end
Perks={Strength='Strength',Nimble='Nimble'};CharacterTrait={};SandboxVars={ProjectArcade={SfxVolumePct=50}}
IsoDirections={N='N',S='S',E='E',W='W'}
function list(items)return{size=function()return #items end,get=function(_,i)return items[i+1]end}end
function getActivatedMods()return{contains=function(_,id)return id==MOD_ID end}end
EMISSIONS={};UI_SOUNDS={};COMMANDS={};LOGS={};OVERLAYS={}
function print(text)LOGS[#LOGS+1]=tostring(text)end
function getTileOverlays()return{addOverlays=function(_,data)OVERLAYS[#OVERLAYS+1]=data end}end
getContainerOverlays=getTileOverlays
function emitter()
 local e={}
 function e:setPos(x,y,z)self.pos={x,y,z}end
 function e:playClip(clip)EMISSIONS[#EMISSIONS+1]={clip=clip,pos=self.pos};self.playing=true;return #EMISSIONS end
 function e:setVolume(id,v)EMISSIONS[id].volume=v end
 function e:set3D(id,v)EMISSIONS[id].is3D=v end
 function e:tick()end
 function e:isPlaying()return self.playing end
 function e:stopSound()self.playing=false end
 function e:stopAll()self.playing=false end
 return e
end
GameSounds={getSound=function(name)if name=='missing' then return nil end return{getRandomClip=function()return{name=name,getVolume=function()return 0.8 end}end}end}
IsoWorld={instance={getFreeEmitter=function()return emitter()end}}
function sendServerCommand(...)COMMANDS[#COMMANDS+1]={...}end
function getSpecificPlayer()return PLAYER end
function getPlayer()return PLAYER end
function getOnlinePlayers()return list({})end
function getCell()return{getZombieList=function()return list({})end}end
NMCore={isSubsystemDebugEnabled=function()return DEBUG==true end,isMPClientRuntime=function()return false end,isMultiplayerMode=function()return true end,NetModule='NewMusic',logChannel=function(channel,tag,detail)LOGS[#LOGS+1]={channel=channel,tag=tag,detail=detail}end,clamp=function(v,a,b)return math.max(a,math.min(b,v))end}
NMZombieSandboxRarity={getVisualTargetPublishIntervalTicks=function()return 1 end}
NMZombieVisualTargetContract={PublishIntervalTicks=1}
NMMediaSlot={};NMBatterySlot={}
NMMediaSlotEnv=setmetatable({NMMediaSlot=NMMediaSlot},{__index=_G})
NMBatterySlotEnv=setmetatable({NMBatterySlot=NMBatterySlot,BATTERY_FULL_TYPE='Base.Battery'},{__index=_G})
NMWalkmanWindowEnv=setmetatable({},{__index=_G})
NMCDPlayerWindowEnv=setmetatable({},{__index=_G})
WalkmanWindow={};CDPlayerWindow={}
NMPortableUiSoundContract={playNamedSound=function(window,name)UI_SOUNDS[#UI_SOUNDS+1]={window=window,name=name}end,playCDManualPlay=function(window)UI_SOUNDS[#UI_SOUNDS+1]={window=window,name='CDManualPlay'}end}
NMSlotHostLifecycle={initHostState=function()end,resolveFrameContext=function()return{}end}
NMTranslations={ui=function(_,fallback)return fallback end}
NMMusic={resolveTracks=function()return{tracks={'one','two'}}end}
ProjectArcade_Currency={};ProjectArcade_HighscoreUI={Show=function(score,kind)HS_SHOW={score,kind}end}
BuildRecipeCode={floor={OnCreate=function(params)NATIVE_BUILD=params;return 'native' end,OnIsValid=function()return true end}}
ISMouseDrag={dragging={}};ISInventoryPane={getActualItems=function(items)return items end}
function getMouseX()return 3 end
function getMouseY()return 3 end
if string.find(MODE,'tiletrue') then TILEZED=true elseif string.find(MODE,'tilefalse') then TILEZED=false end
