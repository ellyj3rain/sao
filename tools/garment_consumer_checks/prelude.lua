-- Initial native scene, clock/Standing/route/UI/animation/network endpoints only.
__scene=__configureGarmentScene();body=__scene.body
__replaceNativeRecord(nil)
__garmentHours=100
ModData={getOrCreate=function(key)return __nativeModData(key)end,get=function(key)return __nativeModData(key)end}
SAO={Body={active={['garment-person']=body}},Pharmacology={},Cooking={},History={countyHours=function()return __garmentHours end,ticks=function()return __garmentHours*9000 end,ticksFromHours=function(n)return n*9000 end},
 Log={line=function()end,tally=function()end},Standing={mayTakeCurrent=function()return __standing~=false end,mayAttemptBelieved=function()return __standing~=false end,mayEnterBelieved=function()return __standing~=false end,provisioningContextAt=function()return "personal"end},
 Lessons={desperationBump=function()return 0 end},Locomotion={jobs={},cancel=function(id)SAO.Locomotion.jobs[id]=nil end,order=function(id,b,x,y,z)__moveGarmentBody(x,y);SAO.Locomotion.jobs[id]={body=b,done=true,result="arrived",goal={x=x,y=y,z=z}};return true end}}
Events=setmetatable({},{__index=function(t,key)local event={Add=function()end,Remove=function()end};rawset(t,key,event);return event end})
SandboxVars={SurvivorAwareness={Desperation=.95}}
function require()end
function isClient()return false end
function isServer()return false end
function getWorld()return {getWorld=function()return "isolated-normal-garment"end,getCell=function()return body:getCell()end,getMetaGrid=function()return nil end}end
function getCore()return {getGameMode=function()return "Sandbox"end}end
function getText(text)return text end
function getDebug()return false end
function getTimestampMs()return __nativeTimestamp()end
function getSpecificPlayer()return body end -- same-actor source Lua lookup, native body remains offslot
function getCell()return body:getCell()end
function convertToPZNetTable(t)return t end
function showDebugInfoInChat()end
function log()end
function sendRemoveItemFromContainer()end
function sendAddItemToContainer()end
function syncItemFields()end
function addXp(chr,perk,amount)chr:getXp():AddXP(perk,amount)end
function ZombRand(...)return __nativeRandom(...)end
ISGarmentUI={setBodyPartActionForPlayer=function()end}
ISLogSystem={logAction=function()end}
ISInventoryPage={dirtyUI=function()end}
ItemPicker={updateOverlaySprite=function()end}
function createItemTransaction()return 1 end
function removeItemTransaction()end
function getPlayerData()return nil end
Perks=PerkFactory.Perks

-- Original installed removal emits this native event; UI subscribers are outside the isolated scene.
function triggerEvent(name,actor)__nativeGarmentEvent(name,actor)end
