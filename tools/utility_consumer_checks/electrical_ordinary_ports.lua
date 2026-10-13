-- Source-shaped lifetime, Standing, private storage and route endpoints.
-- Actual native shell/world/items/query/action/queue/clock remain Java.
require=function()end;isClient=function()return false end;isServer=function()return false end
getCell=function()return body:getCell()end;getWorld=function()return __world end
getSpecificPlayer=function()return body end -- original offslot HUD/action lookup
getActivatedMods=function()return {contains=function()return false end}end
instanceof=function(object,name)return object and string.find(tostring(object),name,1,true)~=nil end
getText=function(t)return t end;getDebug=function()return false end
sendServerCommand=function()end;sendClientCommand=function()end;sendSyncPlayerFields=function()end
ISInventoryPage={dirtyUI=function()end};ISLogSystem={logAction=function()end}
local g=__game..'/media/lua/'
for _,p in ipairs({'shared/ISBaseObject.lua','shared/TimedActions/ISBaseTimedAction.lua','client/TimedActions/ISTimedActionQueue.lua','shared/TimedActions/ISActivateGenerator.lua','shared/TimedActions/ISToggleStoveAction.lua','shared/TimedActions/ISToggleLightAction.lua','shared/TimedActions/ISFixGenerator.lua','shared/TimedActions/ISAddFuel.lua','shared/TimedActions/ISPlugGenerator.lua','client/TimedActions/ISGeneratorInfoAction.lua','client/TimedActions/ISInventoryTransferAction.lua','shared/TimedActions/ISEquipWeaponAction.lua'})do __load(g..p)end
ModData={get=function(k)return __native('store',k)end,getOrCreate=function(k)return __native('store-create',k)end}
Perks=PerkFactory.Perks
local id='electrical-cook';local rec={id=id,name='Electrical Cook',skills={Cooking=0,Electricity=4},homeX=11,homeY=20,homeZ=0,claim={minX=0,minY=8,maxX=31,maxY=31,z=0}}
__record=rec
assert(__native('register',rec)) -- initial original native person registry
SAO={Identity={get=function(k)return k==id and rec or nil end},Body={active={[id]=body},foreign={}},Controller={agents={[id]={rec=rec,state='IDLE'}}},
 History={countyHours=function()return __native('facts').hours end,ticks=function()return math.floor(__native('facts').hours*9000)end},
 Log={line=function(...)print('SAO_LOG',...)end},Pharmacology={},ResourceProduction={},Needs={},Locomotion={jobs={}},Standing={}}
SAO.Body.get=function(k)return SAO.Body.active[k]end
SAO.Standing.mayTakeCurrent=function(k,x,y)return k==id and x>=0 and x<=31 and y>=8 and y<=31 end
SAO.Standing.mayAttemptBelieved=SAO.Standing.mayTakeCurrent
SAO.Standing.mayEnterBelieved=SAO.Standing.mayTakeCurrent
SAO.Standing.provisioningContextAt=function()return 'personal'end
SAO.Census={skillOf=function(k,skill)local perk=Perks[skill];return k==id and perk and body:getPerkLevel(perk)or 0 end}
SAO.Needs.busy=function(b)local q=ISTimedActionQueue.getTimedActionQueue(b);return q.current~=nil or #q.queue>0 end
SAO.Needs.read=function(b)return {hunger=b:getStats():get(CharacterStat.HUNGER),thirst=b:getStats():get(CharacterStat.THIRST),fatigue=b:getStats():get(CharacterStat.FATIGUE)}end
SAO.Needs.queueVerified=function(a)ISTimedActionQueue.add(a);local q=ISTimedActionQueue.getTimedActionQueue(a.character);return q.current==a and q.queue[1]==a end
SAO.Needs.ownsRecoveryBody=function(k,b)return SAO.Body.get(k)==b and b:getModData().SAOPersonId==k end
SAO.Locomotion.order=function(k,b,x,y,z)assert(k==id and b==body and z==0);__native('move',x,y);SAO.Locomotion.jobs[k]={body=b,done=true,result='arrived',goal={x=x,y=y,z=z}};return true end
SAO.Locomotion.tick=function(k)return SAO.Locomotion.jobs[k]end
IsoGenerator={isPoweringSquare=__coverage}
local lua=__unit..'/mod/42.20/media/lua/'
for _,p in ipairs({'shared/SAO_Ordering.lua','shared/SAO_HouseholdService.lua','shared/SAO_ElectricalService.lua','shared/SAO_WorldSources.lua','shared/SAO_Perception.lua','shared/SAO_SituationAppraisal.lua','shared/SAO_Labor.lua','shared/SAO_CognitiveModels.lua','shared/SAO_Cognition.lua','shared/SAO_ProceduralPlanning.lua','client/SAO_Generator.lua','client/SAO_Cooking.lua','client/SAO_CapabilityExperience.lua'})do __load(lua..p)end
assert(SAO.Cognition.ensureGameDefaults())

DebugType={Action={warn=function(...)print("ORIGINAL_QUEUE_WARNING",...)end}}
local originalQueueAdmission=SAO.Needs.queueVerified
SAO.Needs.queueVerified=function(action)
 if __holdPrestart then
  __holdPrestart=false;local wait=action.waitToStart
  action.waitToStart=function(self)wait(self);return true end
 end
 return originalQueueAdmission(action)
end

if __case=="review-corrections"and CONTROL~="omit-receiver"then
 SAO.Disposition={eatAt=function()return .3 end,drinkAt=function()return .3 end}
 __load(__unit..'/controller-functions.lua')
 __load(__unit..'/mod/42.20/media/lua/client/SAO_ElectricalMenu.lua')
end
