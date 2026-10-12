-- Real native shell/cell/source/items. Clock, permissions and action-end are
-- explicit isolated instrument inputs; the changed personal owners are loaded.
__consumer=__prepareIntegratedNative()
__consumer.id="ingredient-person"
__consumer.record.bodyOwnerToken="ingredient-native-token"
__consumer.record.resourceProductionSequence=0
__consumer.body:getModData().SAOExternalToken="ingredient-native-token"
Perks=Perks or {Maintenance=ScriptManager.instance:getCraftRecipe("Base.MakeCrudeWhetstone"):getRequiredSkill(0):getPerk()}
__consumer.body:setPerkLevelDebug(Perks.Maintenance,10)
__consumer.body:setTimedActionInstantCheat(true)
__consumerHours=100
ModData={getOrCreate=function(key)return __nativeModData(key)end,get=function(key)return __nativeModData(key)end}
SAO={Pharmacology={},Cooking={},Body={active={[__consumer.id]=__consumer.body},foreign={}},History={countyHours=function()return __consumerHours end,
 ticks=function()return __consumerHours*9000 end,ticksFromHours=function(n)return n*9000 end,literacyOf=function()return "reads" end},
 Log={line=function()end,tally=function()end},Standing={mayTakeCurrent=function()return __consumerPermission~=false end,
 mayAttemptBelieved=function()return __consumerPermission~=false end,mayEnterBelieved=function()return __consumerPermission~=false end,
 provisioningContextAt=function()return "personal"end},Lessons={desperationBump=function()return 0 end},
 Locomotion={jobs={},cancel=function(id)SAO.Locomotion.jobs[id]=nil end,
 order=function(id,body,x,y,z)
  if not __consumerAllowApproach and (math.floor(body:getX())~=x or math.floor(body:getY())~=y or math.floor(body:getZ())~=z)then return false end
  SAO.Locomotion.jobs[id]={body=body,done=true,result="arrived",goal={x=x,y=y,z=z}};return true
 end},Census={skillOf=function(_,perk)return Perks[perk] and __consumer.body:getPerkLevel(Perks[perk]) or 0 end}}
Events=setmetatable({},{__index=function(t,key)local event={Add=function()end,Remove=function()end};rawset(t,key,event);return event end})
SandboxVars={SurvivorAwareness={Desperation=.95}}
function require()end
function instanceof(object,name)return __nativeInstanceof(object,name)end
function isClient()return false end
function isServer()return false end
function getWorld()return {getWorld=function()return "isolated-recipe-consumer"end,getCell=function()return __consumer.body:getCell()end,
 getMetaGrid=function()return nil end}end
function getCore()return {getGameMode=function()return "Sandbox"end}end
function getText(text)return text end
function getTimestampMs()return 10000 end
function convertToPZNetTable(t)return t end
function showDebugInfoInChat()end
function log()end
DebugType={CraftLogic="fixture-native-craft-log",Action={warn=function()end}}
ISInventoryPage={dirtyUI=function()end}
ItemPicker={updateOverlaySprite=function()end} -- UI overlay is not a stock effect.
ISLogSystem={logAction=function()end} -- UI logging is an explicit fixture port.
ISInventoryPaneContextMenu={getContainers=function()local rows=ArrayList.new();rows:add(__consumer.body:getInventory());return rows end}
ISTakeWaterAction={}
ISGrabItemAction={}
function removeItemTransaction()end
function createItemTransaction()return 1 end -- SP native transfer has no network transaction.
function getPlayerData()return nil end -- UI inventory refresh only.
Actions={addOrDropItem=function(body,item)
 body:getInventory():AddItemBlind(item);item:setContainer(body:getInventory())
end}
