#!/usr/bin/env python3
"""Exact installed Week One stage ownership under the SAO person record."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE
from weekone_active_program_test import PORTS

COGNITIVE_MODELS = ROOT / "mod/42.20/media/lua/shared/SAO_CognitiveModels.lua"
COGNITION = ROOT / "mod/42.20/media/lua/shared/SAO_Cognition.lua"

PROGRAMS = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600") / (
    "3403180543/mods/BanditsWeekOne/42.20/media/lua/shared/"
    "ZombiePrograms/WeekOne")
PINS = {
    "ZPActive.lua": "8ab864fafbe5d311d09960648a9b4536e8dc09d5a8bd822ca69d07eec9620579",
    "ZPArmyGuard.lua": "34c2d7bf2de3e48771ad62b3099af7138956b120fc08e8f4301da5bfbacd565d",
    "ZPBabe.lua": "100346399efd379052d1789c12b98de89c774e098d5cbd38f2b6f9683af62d78",
    "ZPBanditSimple.lua": "d2c28bc85520ddcdb196eaf7cde011c29c2df63b44265d72c650d13e012ab557",
    "ZPEntertainer.lua": "62fb427ee9714b1f2aef53c09259370b4e41c2d69b0d7310ebcf861f2a655e8f",
    "ZPFireman.lua": "84ab9293d146b03425c1f8f7e7ce4fcfc0f9c9eb72dcef1a6425e984e58a8490",
    "ZPGardener.lua": "ccaad72c2cee5c9bdf7e368b84a9958adb5a2552951a2610e29c789090e60ecd",
    "ZPInhabitant.lua": "3f5cfd5b251e20d6e628eddc91f5d56aececa9ae4c650677d709ded0aeea47b2",
    "ZPJanitor.lua": "d21abd17f3e7488d942da58d3790f1fdc451383d55beb5c145ba17564bb94965",
    "ZPMedic.lua": "7882a3c9e9e01f5ff9eccff0009bfcc78f88e5d13fff6da4a2c6a0fd804ba1da",
    "ZPPassenger.lua": "22114ad17d9759ae315f317240be3abd68dc6fec74390919e22f515ca24f6b9c",
    "ZPPatrol.lua": "82fa6a5efe68cfb07a664dfef9be80bbc482fd48d4926d77c96ec71c637f9f97",
    "ZPPolice.lua": "f8b986164f7b85c536ea102229b45840e28c6e8ef469aca09aecfc7fd2141ec9",
    "ZPPostal.lua": "be1612f4a306a08401c51ec89d725ba849ae9213e3d9744c07bf0ef6a803ffba",
    "ZPRiotPolice.lua": "9d6993f3718ceffb606f6abbb8edb4b6b7cd002b9030fc84bd65c192ac85f227",
    "ZPRunner.lua": "030e16df3960d6b3379bf10577248792f0d8558d05558c0d07b6f76b59020dc0",
    "ZPShahid.lua": "ac3bc3220afc0547c885f3171eee19eacfa3920e73b3e0529ff3b4d9eb6d868c",
    "ZPSurvivor.lua": "9c9eaf258a307c06ab867dc5153bf3445f0fad8af39955c62685e8cd88ec30bd",
    "ZPVandal.lua": "3463a002e06042e38f681be2e61982cae7a1bf8a27dc61bf35ba7839e14594eb",
    "ZPWalker.lua": "ad6ff8a9d0d6b022d03324f7378d5f611b92af6d511fee5d06e1ff6ea7053bcd",
}
BASE_BANDIT = (Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600") /
    "3268487204/mods/Bandits/42.20/media/lua/shared/ZombiePrograms/ZPBandit.lua")
BASE_BANDIT_SHA = "6889da52395e7f2c2af6e3f8e6c16d4b297d0059027b1a6e84c10cb2aaf31238"
BANDIT_DISPATCH = BASE_BANDIT.parents[1] / "Bandit.lua"
BANDIT_DISPATCH_SHA = "4236dd55e614445e0d85c4be14fa9f7420576557452d90372a3464f9b4e43ca2"

ADDITIONS = r'''
__stationary=0 __sourceTargetCalls=0 __sourceBaseCalls=0
__sourceRandomCalls=0 __explosions=0 __hostileChanges=0
ZombieActions={}
__roleFeature=nil __roleComplete=0 __bandageCalls=0 __waterRemoved=0
__fireStopped=false __trashRemoved=false __markerRemoved={}
__performancePulse=0
getWorldSoundManager=function() return {addSound=function(self,body,x,y,z,radius,volume)
 return {source=body,x=x,y=y,z=z,radius=radius,volume=volume,life=16} end} end
BWOServer={Commands={ObjectRemove=function(_,args)
 __markerRemoved[args.otype]=true end}}
__roleObject={getContainer=function() return {} end,
 getX=function() return 80 end,getY=function() return 80 end,
 getZ=function() return 0 end,
 getAttachedAnimSprite=function() return nil end}
__roleSquare={getX=function() return 80 end,getY=function() return 80 end,
 getZ=function() return 0 end,
 getWall=function() return __roleObject end,
 stopFire=function() __fireStopped=true end,
 transmitRemoveItemFromSquare=function(self,object)
  if object==__roleObject then __trashRemoved=true end end,
 getObjects=function() return {size=function() return 1 end,
  get=function() return __roleObject end} end}
__roadSquare={getX=function() return 86 end,getY=function() return 80 end,
 getZ=function() return 0 end}
SAOJavaBridge.weekOneObservedFeature=function(self,body,target,kind)
 return ((__roleFeature==kind and (target==__roleSquare or target==__roleObject))
  or (__roleFeature=='road' and kind=='road' and target==__roadSquare))
  and not (kind=='fire' and __fireStopped)
  and not (kind=='trash' and target==__roleObject and __trashRemoved)
  or __roleFeature=='fire' and kind=='ground' and target==__roleSquare
end
SAOJavaBridge.weekOneObservedCareTarget=function(self,body,name)
 if __roleFeature=='care' and name=='Morgan Hill' then
  return 'CARE\t80.8\t80.2\t0\t0.9\t1' end
 return 'REFUSED\tpatient'
end
SAOJavaBridge.weekOneBandageObservedPatient=function(self,body,name)
 __bandageCalls=__bandageCalls+1
 if __roleFeature=='care' and name=='Morgan Hill' then
  return 'TREATED\t0\t173\tBase.Bandage\t1' end
 return 'REFUSED\tpatient'
end
SAOJavaBridge.bindWeekOnePerformanceOccurrence=function(self,body,sound,id,brain,born,name,handle)
 if sound.source~=body or sound.radius~=45 or sound.volume~=45
  or not body.emitter:isPlaying(handle) then return nil end
 __performancePulse=__performancePulse+1
 local seq=__performancePulse
 return {schema='sao.weekone-performance-occurrence/1',actorId=id,
  brainId=brain,born=born,soundId=name,soundHandle=handle,
  clock='native-world-age-hours',epoch='00000000-0000-0000-0000-000000000000',
  sequence=seq,pulseId='00000000-0000-0000-0000-000000000000-'..seq,
  emittedAtHours=__clock} end
SAOJavaBridge.renewWeekOnePerformanceOccurrence=function(self,body,pulse) return true end
SAOJavaBridge.revokeWeekOnePerformanceOccurrence=function(self,body,pulse) return true end
AdjacentFreeTileFinder={Find=function(square) return square end}
Bandit.ForceStationary=function(body,value) __stationary=__stationary+1 end
Bandit.Expertise={Electrician=1,Mechanic=2,Thief=3,Recon=4,Tracker=5}
Bandit.HasExpertise=function() return false end
Bandit.GetWeapons=function() return {} end
BanditPlayerBase={GetBaseClosest=function()
 __sourceBaseCalls=__sourceBaseCalls+1 return nil,nil end}
ZombRand=function() __sourceRandomCalls=__sourceRandomCalls+1 return 0 end
Bandit.SetHostileP=function(body,value) __hostileChanges=__hostileChanges+1 end
Bandit.ClearTasks=function() error('source cleared live tasks') end
Bandit.Say=function() error('source spoke without private decision') end
BanditCompatibility={InstanceItem=function(name) return {name=name} end}
BanditUtils.GetClosestPlayerLocation=function()
 error('source selected unobserved player') end
BanditUtils.GetClosestZombieLocation=function()
 error('source selected global zombie') end
BWOEvents={Explode=function() __explosions=__explosions+1 end}
BanditZombie.GetAll=function() return {} end
getCell=function()
 return {getGridSquare=function(self,x,y,z)
  if __roleFeature=='road' and x==86 and y==80 then return __roadSquare end
  if __roleFeature=='wall' and y==80 and x>=79 and x<=81 then
   return __roleSquare end
  if __roleFeature and x==80 and y==80 then return __roleSquare end
  if x==75 and y==80 then return {isFree=function() return true end} end
  return nil
 end}
end
function __stage(id,family,stage,origin)
 local brain,body=__actor(id,origin or 'BanditsWeekOne','Walker')
 brain.program={name=family,stage=stage}
 brain.bornCoords={x=80,y=80}
 body.isFemale=function() return false end
 body.isOutside=function() return false end
 body.getCell=function() return getCell() end
 body.getPrimaryHandItem=function(self) return self.primary end
  body.getSecondaryHandItem=function(self) return self.secondary end
 body.getInventory=function(self) return self.inventoryMock end
 body.getBumpType=function(self) return self.bump end
 body.setBumpType=function(self,value) self.bump=value end
 body.getEmitter=function(self) return self.emitter end
 body.getForwardDirection=function() return {
  getX=function() return 1 end,getY=function() return 0 end} end
 body.emitter={playing=false,active={},nextHandle=1,
  isPlaying=function(self,value)
   if type(value)=='number' then return self.active[value]~=nil end
   for _,name in pairs(self.active) do if name==value then return true end end
   return false end,
  playSound=function(self,name)
   local handle=self.nextHandle self.nextHandle=handle+1
   self.active[handle]=name self.playing=true return handle end,
  stopSound=function(self,handle)
   self.active[handle]=nil self.playing=false
   for _ in pairs(self.active) do self.playing=true break end end,
  stopSoundByName=function(self,name)
   for handle,value in pairs(self.active) do
    if value==name then self.active[handle]=nil end end
   self.playing=false
   for _ in pairs(self.active) do self.playing=true break end end}
 body.inventoryMock={getItemFromType=function(self,kind)
  return self.item and self.item:getFullType()==kind and self.item or nil end,
  getItems=function(self) local box=self return {
   size=function() return box.item and 1 or 0 end,
   get=function() return box.item end} end,
  contains=function(self,item) return item==self.item end}
 body.setPrimaryHandItem=function(self,item) self.primary=item end
 return brain,body
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local names={'Active','ArmyGuard','Babe','Bandit','BanditSimple','Entertainer',
 'Fireman','Gardener','Inhabitant','Janitor','Medic','Passenger',
 'Patrol','Police','Postal','RiotPolice','Runner','Shahid',
 'Survivor','Vandal','Walker'}
local original={}
for _,name in ipairs(names) do original[name]=ZombiePrograms[name].Prepare end
local ready,count=W.installProgramAdapters()
assert(ready and count==52,'the exact stage wrappers did not install once')
for n,name in ipairs(names) do
 local brain,body=__stage(1000+n,name,'Prepare')
 local result=ZombiePrograms[name].Prepare(body)
 local person=body.md.SAOWeekOnePersonId
 assert(result and result.status and result.next=='Main' and #result.tasks==0
  and person and __records[person].heldBy=='BanditsWeekOne'
  and __records[person].weekOne.decision.adapter==name..'.Prepare',
  'source preparation was not owned by the exact SAO person: '..name)
 if name=='Walker' then assert(brain.bag==nil,
  'source arbitrary briefcase changed exact saved inventory') end
end
assert(__stationary==21,'prepare pose changed without the exact body count')
assert(ZombieActions.SAOBandagePerson
 and ZombieActions.SAOPerform and ZombieActions.SAOWaterFlowerbed
 and ZombieActions.SAOGraffiti and W.installRoleActions(),
 'SAO-owned physical role actions were not installed')
local initializing,initialBody=__stage(1039,'BanditSimple','Init')
local initialized=ZombiePrograms.BanditSimple.Init(initialBody)
assert(initialized.next=='Prepare' and #initialized.tasks==0
 and __records[initialBody.md.SAOWeekOnePersonId].weekOne.decision.adapter
  =='BanditSimple.Init',
 'source empty Init did not establish exact person before preparation')
local conflict,conflictBody=__stage(1040,'Walker','Prepare')
conflictBody.md.SAOWeekOnePersonId='another-person'
local held=ZombiePrograms.Walker.Prepare(conflictBody)
assert(held.next=='Prepare' and #held.tasks==0 and conflict.bag==nil
 and __stationary==21 and __records['bwo-23']==nil,
 'conflicted exact source body ran the arbitrary source possession branch')
local foreign,foreignBody=__stage(1030,'ArmyGuard','Prepare','Bandits2')
local foreignResult=ZombiePrograms.ArmyGuard.Prepare(foreignBody)
assert(foreignResult.next=='Main' and foreignBody.md.SAOWeekOnePersonId==nil
 and __stationary==22,'foreign Week One source no longer follows native source')
__target='zombie' __threat=2
for n,name in ipairs({'ArmyGuard','BanditSimple','Inhabitant','Police','Shahid','Survivor'}) do
 __tick=300+n*21
 local stage=name=='Inhabitant' and 'Defend' or 'Main'
 local brain,body=__stage(1100+n,name,stage)
 local result=ZombiePrograms[name][stage](body)
 local person=body.md.SAOWeekOnePersonId
 assert(result and result.tasks[1] and result.tasks[1].action=='Move'
  and result.tasks[1].x==82 and __records[person].weekOne.decision.adapter==name..'.'..stage,
  'source hostile/global decision displaced SAO sight: '..name)
end
assert(__sourceTargetCalls==0 and __explosions==0,
 'source target or automatic global explosion escaped SAO ownership')
__tick=500 __target='none' __threat=0
local police,policeBody=__stage(1230,'Police','Main')
local patrol=ZombiePrograms.Police.Main(policeBody)
local policePerson=policeBody.md.SAOWeekOnePersonId
assert(patrol and #patrol.tasks==0 and police.program.name=='Patrol'
 and __records[policePerson].weekOne.decision.kind=='resume-program'
 and __records[policePerson].weekOne.decision.program=='Patrol',
 'private no-enemy police decision did not resume exact patrol program')
local inhabitant,inhabitantBody=__stage(1240,'Inhabitant','Defend')
local calm=ZombiePrograms.Inhabitant.Defend(inhabitantBody)
assert(calm.next=='Main' and calm.tasks[1].action=='Time'
 and __hostileChanges==1,
 'private no-enemy defender did not de-escalate')
__tick=550 __target='zombie' __threat=2
for _,name in ipairs({'Active','Police'}) do
 local brain,body=__stage(1300+#name,name,'Escape')
 local escaped=ZombiePrograms[name].Escape(body)
 local person=body.md.SAOWeekOnePersonId
 assert(escaped.next=='Escape' and escaped.tasks[1]
  and escaped.tasks[1].action=='Move' and escaped.tasks[1].x==75
  and __records[person].weekOne.decision.kind=='escape'
  and __records[person].weekOne.decision.adapter==name..'.Escape',
  'source random flight displaced current observed escape: '..name)
end
__tick=570
local waiting,waitingBody=__stage(1390,'Active','Wait')
local resumed=ZombiePrograms.Active.Wait(waitingBody)
assert(resumed.next=='Main' and #resumed.tasks==0
 and __records[waitingBody.md.SAOWeekOnePersonId].weekOne.decision.kind=='resume',
 'source Wait bypassed person stage persistence')
__step='Bandit.Main/private'
__target='zombie' __threat=2 __tick=575
local banditMain,banditMainBody=__stage(1420,'Bandit','Main')
banditMain.loyal=true
local mainChoice=ZombiePrograms.Bandit.Main(banditMainBody)
assert(mainChoice.tasks[1] and mainChoice.tasks[1].action=='Move'
 and mainChoice.tasks[1].x==82
 and __records[banditMainBody.md.SAOWeekOnePersonId].weekOne.decision.adapter
  =='Bandit.Main' and __sourceBaseCalls==0 and __sourceTargetCalls==0,
 'hour-87 Bandit Main ran source sabotage or loyalty instead of private sight')
__step='Bandit.Surrender/private-person'
__target='person' __hostile=true __threat=0 __tick=576
local surrendered,surrenderBody=__stage(1421,'Bandit','Surrender')
surrendered.loyal=false
local surrenderChoice=ZombiePrograms.Bandit.Surrender(surrenderBody)
assert(surrenderChoice.next=='Surrender' and #surrenderChoice.tasks==1
 and surrenderChoice.tasks[1].action=='Time'
 and surrenderChoice.tasks[1].anim=='Surrender'
 and __records[surrenderBody.md.SAOWeekOnePersonId].weekOne.decision.kind
  =='surrender' and __sourceRandomCalls==0,
 'observed person and private caution did not own physical surrender')
__step='Bandit.Surrender/private-zombie'
__target='zombie' __threat=2 __tick=577
local zombieSurrender,zombieSurrenderBody=__stage(1422,'Bandit','Surrender')
local fled=ZombiePrograms.Bandit.Surrender(zombieSurrenderBody)
assert(fled.next=='Escape' and fled.tasks[1]
 and fled.tasks[1].action=='Move' and fled.tasks[1].x==75
 and __sourceRandomCalls==0,
 'the person surrendered to a zombie or used source random flight')
__step='Bandit.Escape/private'
__tick=578
local banditEscape,banditEscapeBody=__stage(1423,'Bandit','Escape')
local escapeChoice=ZombiePrograms.Bandit.Escape(banditEscapeBody)
assert(escapeChoice.next=='Escape' and escapeChoice.tasks[1]
 and escapeChoice.tasks[1].action=='Move' and escapeChoice.tasks[1].x==75
 and __records[banditEscapeBody.md.SAOWeekOnePersonId].weekOne.decision.adapter
  =='Bandit.Escape' and __sourceRandomCalls==0,
 'stamped Bandit Escape selected source random destination')
__step='Bandit.Surrender/private-calm'
__target='none' __threat=0 __hostile=false __tick=579
local calmBandit,calmBanditBody=__stage(1424,'Bandit','Surrender')
local calmSurrender=ZombiePrograms.Bandit.Surrender(calmBanditBody)
assert(calmSurrender.next=='Main' and calmSurrender.tasks[1]
 and calmSurrender.tasks[1].action=='Time'
 and calmSurrender.tasks[1].anim~='Surrender'
 and __sourceRandomCalls==0,
 'source Surrender persisted after private sight found no enemy')
__target='zombie' __threat=2
for n,entry in ipairs({{'Police','Follow'},{'Medic','Walk'}}) do
 local brain,body=__stage(1390+n,entry[1],entry[2])
 local resumed=ZombiePrograms[entry[1]][entry[2]](body)
 assert(resumed.next=='Main' and #resumed.tasks==0
  and __records[body.md.SAOWeekOnePersonId].weekOne.decision.adapter
   ==entry[1]..'.'..entry[2],
 'source no-task stage bypassed exact person continuity')
end
__target='none' __threat=0
local ordinary={
 {'Babe','Main'},{'Babe','Guard'},{'Babe','Base'},
 {'Entertainer','Main'},{'Fireman','Main'},{'Gardener','Main'},
 {'Inhabitant','Main'},{'Janitor','Main'},{'Medic','Main'},
 {'Passenger','Main'},{'Patrol','Main'},{'Postal','Main'},
 {'RiotPolice','Main'},{'Runner','Main'},{'Vandal','Main'},
 {'Walker','Main'}}
for n,entry in ipairs(ordinary) do
 __tick=590+n*21
 local brain,body=__stage(1500+n,entry[1],entry[2])
 local result=ZombiePrograms[entry[1]][entry[2]](body)
 local person=body.md.SAOWeekOnePersonId
 local phase=person and __records[person].weekOne
 assert(result and result.tasks[1] and result.tasks[1].action=='Time'
  and phase and phase.decision.kind=='ordinary'
  and phase.decision.adapter==entry[1]..'.'..entry[2]
  and phase.ordinary.role==nil
  and phase.ordinary.sourceProgram==entry[1],
  'ordinary stage fell through to unowned source: '..entry[1]..'.'..entry[2])
end
assert(__sourceTargetCalls==0 and __explosions==0,
 'ordinary source selected global targets or explosions')
local materialId=1000
local function material(kind)
 materialId=materialId+1
 local id=materialId
 return {getFullType=function() return kind end,condition=3,
  getID=function() return id end,
  getCondition=function(self) return self.condition end,
  setCondition=function(self,value) self.condition=value end}
end
local function role(name,feature,id,item)
 __step=name..':'..feature
 __roleFeature=feature __tick=1400+id*21
 local brain,body=__stage(1600+id,name,'Main')
 body.primary=item
 return brain,body,ZombiePrograms[name].Main(body)
end
local _,fireBody,fire=role('Fireman','fire',1,
 material('Bandits.Extinguisher'))
assert(fire.tasks[1].action=='SAOExtinguishFire' and fire.tasks[1].item==nil
 and fire.tasks[1].x==80 and fireBody.md.SAOWeekOnePersonId,
 'visible fire and physical extinguisher did not choose source fire actuator')
ZombieActions.SAOExtinguishFire.onStart(fireBody,fire.tasks[1])
ZombieActions.SAOExtinguishFire.onComplete(fireBody,fire.tasks[1])
assert(__fireStopped and __markerRemoved.fire
 and fireBody.primary.condition==2
 and __records[fireBody.md.SAOWeekOnePersonId].weekOne.lastOrdinaryOutcome.result
  =='physical-fire-extinguished',
 'owned fire action did not consume physical tool and settle visible fire')
__fireStopped=false
ZombieActions.SAOExtinguishFire.onComplete(fireBody,fire.tasks[1])
assert(fireBody.primary.condition==2
 and __records[fireBody.md.SAOWeekOnePersonId].weekOne.nextOrdinaryOutcome==2,
 'one physical fire task replayed after completion')
__fireStopped=true
local _,janitorBody,clean=role('Janitor','trash',2,material('Base.Broom'))
assert(clean.tasks[1].action=='SAOCleanTrash'
 and clean.tasks[1].customName=='Trash' and janitorBody.md.SAOWeekOnePersonId,
 'visible physical trash with a real broom was not cleaned')
ZombieActions.SAOCleanTrash.onStart(janitorBody,clean.tasks[1])
ZombieActions.SAOCleanTrash.onComplete(janitorBody,clean.tasks[1])
assert(__trashRemoved and __markerRemoved.trash
 and __records[janitorBody.md.SAOWeekOnePersonId].weekOne.lastOrdinaryOutcome.result
  =='physical-trash-cleared',
 'owned janitor action did not clear exact visible trash and source marker')
local _,passengerBody,seat=role('Passenger','chair',3)
assert(seat.tasks[1].action=='SitInChair' and seat.tasks[1].x==80
 and seat.tasks[1].y==80 and passengerBody.md.SAOWeekOnePersonId,
 'visible chair was not selected at exact world coordinates')
local _,postalBody,post=role('Postal','mailbox',4)
postalBody.inventoryMock.item=material('Base.Newspaper')
__tick=__tick+21
local delivered=ZombiePrograms.Postal.Main(postalBody)
assert(post.tasks[1].action=='Time'
 and delivered.tasks[1].action=='PutInContainer'
 and delivered.tasks[1].itemType=='Base.Newspaper'
 and delivered.tasks[1].x==80,
 'physical newspaper and visible mailbox did not yield delivery')
local fluid={amount=1,isWaterOnlySource=function() return true end,
 getAmount=function(self) return self.amount end,
 removeFluid=function(self,amount) self.amount=self.amount-amount
  __waterRemoved=__waterRemoved+amount end}
local water=material('Base.WateredCan')
water.getFluidContainerFromSelfOrWorldItem=function() return fluid end
local _,gardenBody,garden=role('Gardener','flowerbed',6,water)
local gardenTask=garden.tasks[1]
assert(gardenTask.action=='SAOWaterFlowerbed',
 'physical water and visible flowerbed did not choose owned tending action')
ZombieActions.SAOWaterFlowerbed.onStart(gardenBody,gardenTask)
ZombieActions.SAOWaterFlowerbed.onComplete(gardenBody,gardenTask)
local gardenPhase=__records[gardenBody.md.SAOWeekOnePersonId].weekOne
assert(__waterRemoved==0.1 and gardenPhase.lastOrdinaryOutcome.result
 =='decorative-flowerbed-tended',
 'owned gardener action did not consume physical water and record outcome')
__roleFeature='care' __tick=1550
local medic,medicBody=__stage(1700,'Medic','Main')
local bandage=material('Base.Bandage')
bandage.isCanBandage=function() return true end
bandage.getBandagePower=function() return 1.5 end
bandage.isInfected=function() return false end
medicBody.inventoryMock.item=bandage
local treatment=ZombiePrograms.Medic.Main(medicBody)
local careTask=treatment.tasks[1]
assert(careTask.action=='SAOBandagePerson'
 and careTask.saoPatientName=='Morgan Hill',
 'visible bleeding patient and owned bandage did not choose native care')
ZombieActions.SAOBandagePerson.onStart(medicBody,careTask)
ZombieActions.SAOBandagePerson.onComplete(medicBody,careTask)
local carePhase=__records[medicBody.md.SAOWeekOnePersonId].weekOne
assert(__bandageCalls==1 and carePhase.lastOrdinaryOutcome.result
 =='TREATED\t0\t173\tBase.Bandage\t1',
 'owned medic action did not retain exact native treatment receipt')
ZombieActions.SAOBandagePerson.onComplete(medicBody,careTask)
assert(__bandageCalls==1 and carePhase.nextOrdinaryOutcome==2,
 'one physical treatment task replayed after completion')
__roleFeature=nil __tick=1571
local musician,musicBody=__stage(1701,'Entertainer','Main')
musician.occupation='BassPlayer'
musicBody.primary=material('Base.GuitarElectric')
local performance=ZombiePrograms.Entertainer.Main(musicBody)
local musicTask=performance.tasks[1]
musician.tasks=performance.tasks
assert(musicTask.action=='SAOPerform' and musicTask.sound==nil
 and musicTask.saoSound=='BWOInstrumentBassGuitar1',
 'physical musician did not own one bounded sound action')
assert(SAO.Cognition.configure(.5,12,3)==true,
 'private cognition did not admit the configured source test')
ZombieActions.SAOPerform.onStart(musicBody,musicTask)
assert(musicBody.emitter.playing==true,
 'physical musician did not start local emission')
local musicId=musicBody.md.SAOWeekOnePersonId
local liveBody,liveOccurrence=SAO.WeekOneContinuity.livePerformance(musicId)
local liveIds=SAO.WeekOneContinuity.livePerformanceIds()
assert(liveBody==musicBody and liveOccurrence
 and liveOccurrence.schema=='sao.weekone-performance-occurrence/1'
 and liveOccurrence.actorId==musicId
 and liveOccurrence.soundHandle==SAO.WeekOneContinuity.performanceSoundOwners[musicTask].soundHandle
 and liveIds[1]==musicId,
 'physical performance did not expose its current exact listener source')
musician.tasks={}
assert(SAO.WeekOneContinuity.livePerformance(musicId)==nil,
 'unqueued performance remained a live listener source')
musician.tasks=performance.tasks
musician.born=musician.born+1
assert(SAO.WeekOneContinuity.livePerformance(musicId)==nil,
 'changed source generation remained a live listener source')
musician.born=musician.born-1
ZombieActions.SAOPerform.onComplete(musicBody,musicTask)
local musicPhase=__records[musicBody.md.SAOWeekOnePersonId].weekOne
assert(SAO.WeekOneContinuity.livePerformance(musicId)==nil,
 'completed performance still exposed a live listener source')
assert(musicBody.emitter.playing==false
 and musicPhase.lastOrdinaryOutcome.result=='physical-performance',
 'owned performance did not end sound and record occurrence: sound='
 ..tostring(musicBody.emitter.playing)..', result='
 ..tostring(musicPhase.lastOrdinaryOutcome and musicPhase.lastOrdinaryOutcome.result)
 ..', owner='..tostring(SAO.WeekOneContinuity.performanceSoundOwners[musicTask]
  and SAO.WeekOneContinuity.performanceSoundOwners[musicTask].soundHandle)
 ..', cancel='..tostring(musicTask.saoCancelled))
local performanceReceipt=SAO.WeekOneContinuity.performanceOutcome(musicId,1)
local private=SAO.Cognition.snapshot(musicId,true)
local played=private and private.experiences and private.experiences[1]
assert(performanceReceipt and performanceReceipt.actorId==musicId
 and performanceReceipt.sequence==1 and performanceReceipt.claimOwner=='BanditsWeekOne'
 and performanceReceipt.brainId==musician.id and performanceReceipt.bodyId==musician.id
 and performanceReceipt.born==musician.born
 and performanceReceipt.decisionAtTick==musicTask.saoWeekOneAtTick
 and performanceReceipt.itemId==musicBody.primary:getID()
 and performanceReceipt.itemType=='Base.GuitarElectric'
 and performanceReceipt.soundId=='BWOInstrumentBassGuitar1'
 and performanceReceipt.sourceProgram=='Entertainer'
 and performanceReceipt.sourceStage=='Main' and performanceReceipt.status=='completed'
 and played and played.id=='weekone-instrument-performance/'..musicId..'/1'
 and played.sourceId=='BanditsWeekOne:SAOPerform'
 and played.itemId==performanceReceipt.itemId and played.soundId==performanceReceipt.soundId
 and played.sourceBrainId==musician.id and played.sourceBorn==musician.born
 and played.sourceBodyId==musician.id and played.claimOwner=='BanditsWeekOne'
 and played.decisionAtTick==musicTask.saoWeekOneAtTick
 and __records[musicId].cognition.models.ordinary.nativePositions['weekone-instrument-performance']=='1'
 and __records[musicId].cognition.models.associative.nativePositions['weekone-instrument-performance']=='1',
 'private weekone performance not acquired with exact source custody')
local revision=__records[musicId].cognition.models.ordinary.revision
local duplicate, duplicateReason=SAO.Cognition.weekOnePerformanceOutcome(musicId,1)
assert(duplicate==true and duplicateReason=='duplicate'
 and __records[musicId].cognition.models.ordinary.revision==revision
 and #__records[musicId].cognition.experiences==1,
 'weekone performance replay taught the private model twice')
local forged, forgeryReason=SAO.Cognition.experience(musicId,played)
assert(forged==false and forgeryReason=='behavior-owner-required',
 'public cognition input forged a weekone performance')
local receiptRow=musicPhase.performanceOutcomes[1]
local originalSound=receiptRow.soundId
receiptRow.soundId='other-sound'
local changed, changedReason=SAO.Cognition.weekOnePerformanceOutcome(musicId,1)
receiptRow.soundId=originalSound
assert(changed==false and changedReason=='weekone-performance-sound-mismatch'
 and #__records[musicId].cognition.experiences==1,
 'changed source sound crossed into private cognition')
local predicted=SAO.CognitiveModels.planPrediction('associative',
 {id='later-music',evidence=.8,continuity=.5,novelty=.2,informationGain=.2,blockers=0,
  consequences={{kind='hobby',category='leisure',sourceId='LifestyleHobbies',
   itemType='Base.GuitarElectric',condition='perform-instrument',value=1}}},
 __records[musicId].cognition.models.associative,
 {actorId=musicId,atHours=__clock,pressure=0})
assert(predicted and predicted.predictions[1].basis=='related-experience'
 and predicted.predictions[1].evidenceIds[1]==played.id,
 'source performance did not inform later music as uncertain related evidence')
local later={actorId=musicId,sequence=1,workId='music:1',purposeId='later-music',
 sourceId='LifestyleHobbies',revision='installed-test',activity='perform-instrument',
 itemType='Base.GuitarElectric',status='completed',admittedAtHours=__clock,
 atHours=__clock}
local priorLeisureMusic,priorPlanning=SAO.LeisureMusic,SAO.ProceduralPlanning
SAO.LeisureMusic={outcome=function(id,sequence)
 return id==musicId and sequence==1 and later or nil end}
SAO.ProceduralPlanning={hobbyAdmission=function(id,purposeId,workId)
 if id==musicId and purposeId==later.purposeId and workId==later.workId then
  local binding={ownerName='SAO.LeisureMusic'}
  for key,value in pairs(later) do binding[key]=value end
  return binding end
end}
local laterOk=SAO.Cognition.hobbyOutcome(musicId,'SAO.LeisureMusic',1)
SAO.LeisureMusic,SAO.ProceduralPlanning=priorLeisureMusic,priorPlanning
assert(laterOk==true and #__records[musicId].cognition.experiences==2
 and __records[musicId].cognition.nativeExperienceCursors['weekone-instrument-performance']==1
 and __records[musicId].cognition.nativeExperienceCursors['leisure-music']==1
 and __records[musicId].cognition.experiences[2].kind=='leisure-music',
 'later D2 music receipt collided with the source performance sequence')
ZombieActions.SAOPerform.onComplete(musicBody,musicTask)
assert(musicPhase.nextPerformanceOutcome==2
 and #__records[musicId].cognition.experiences==2,
 'completed performance callback replayed its source receipt')
local abandoned={}
for key,value in pairs(musicTask) do abandoned[key]=value end
abandoned.saoCompleted=nil
ZombieActions.SAOPerform.onComplete(musicBody,abandoned)
assert(musicPhase.nextPerformanceOutcome==2
 and #__records[musicId].cognition.experiences==2,
 'reconstructed task without runtime emission minted a receipt')
__tick=__tick+21
local interrupted=ZombiePrograms.Entertainer.Main(musicBody).tasks[1]
ZombieActions.SAOPerform.onStart(musicBody,interrupted)
musicBody.primary=nil
assert(ZombieActions.SAOPerform.onWorking(musicBody,interrupted)==true,
 'lost instrument did not interrupt performance')
ZombieActions.SAOPerform.onComplete(musicBody,interrupted)
assert(musicPhase.nextPerformanceOutcome==2
 and #__records[musicId].cognition.experiences==2,
 'interrupted performance minted a private event')
 musicBody.primary=material('Base.GuitarElectric')
local function privateLeisureCases()
__step='private-leisure-county-clock'
local originalCounty=SAO.History.countyHours
local originalDaysOwed=SAO.History.daysOwed
local daysBehind=__testDaysBehind or 0
SAO.History.daysOwed=function() return daysBehind end
SAO.History.countyHours=function()
 return __clock+SAO.History.daysOwed()*24 end
assert(SAO.History.countyHours()==__clock+daysBehind*24
 and (daysBehind==0 or SAO.History.countyHours()>__clock),
 'county clock fixture did not retain its native offset')
assert(SAO.Cognition.configure(0,12,3)==true,
 'ordinary private comparison could not be selected for its control')
__roleFeature=nil __target='none' __threat=0 __tick=1863
local dualBrain,dualBody=__stage(9301,'Entertainer','Main')
dualBody.primary=material('Base.Violin')
local firstResult=ZombiePrograms.Entertainer.Main(dualBody)
local firstViolin=firstResult.tasks[1]
local firstPhase=__records[dualBody.md.SAOWeekOnePersonId].weekOne
assert(firstViolin and firstViolin.action=='SAOPerform' and firstViolin.itemType=='Base.Violin',
 'only held violin did not remain an executable option: '
 ..tostring(firstViolin and firstViolin.action)..'/'
 ..tostring(dualBody.md.SAOWeekOnePersonId)..'/'
 ..tostring(firstResult.next)..'/'..tostring(__tick)..'/'
 ..tostring(__records[dualBody.md.SAOWeekOnePersonId].weekOne.decision
  and __records[dualBody.md.SAOWeekOnePersonId].weekOne.decision.purpose)..'/'
 ..tostring(__stores.SurvivorAwareness_WeekOneContinuity.lastActiveRefusal
  and __stores.SurvivorAwareness_WeekOneContinuity.lastActiveRefusal.reason)..'/'
 ..tostring(firstPhase.status)..'/'..tostring(firstPhase.lastCognitionTick))
dualBrain.tasks={firstViolin}
ZombieActions.SAOPerform.onStart(dualBody,firstViolin)
ZombieActions.SAOPerform.onComplete(dualBody,firstViolin)
local dualId=dualBody.md.SAOWeekOnePersonId
local dualRec=__records[dualId]
local dualReceipt=W.performanceOutcome(dualId,1)
assert(dualReceipt and dualReceipt.startedAtHours==__clock
 and dualReceipt.atHours==__clock
 and dualReceipt.countyAtHours==SAO.History.countyHours()
 and dualReceipt.countyAtHours-dualReceipt.atHours==daysBehind*24,
 'physical performance did not retain native and contemporaneous county clocks')
assert(dualRec.cognition and dualRec.cognition.experiences[1]
 and dualRec.cognition.experiences[1].kind=='weekone-instrument-performance'
 and dualRec.cognition.experiences[1].occurredAtHours==dualReceipt.countyAtHours
 and dualRec.cognition.experiences[1].nativeCompletedAtHours==dualReceipt.atHours,
 'own physical violin did not enter private evidence')
local violin=dualBody.primary
dualBody.primary=material('Base.GuitarElectric')
dualBody.secondary=violin
__tick=__tick+21
local preferred=ZombiePrograms.Entertainer.Main(dualBody).tasks[1]
local comparison=dualRec.weekOne.leisureComparison
local function score(record,id)
 for _,model in ipairs(record.models or {}) do
  if model.modelId==record.selectedModelId then
   for _,rank in ipairs(model.ranked or {}) do
    if rank.id==id then return rank.score end
   end
  end
 end
end
assert(preferred.action=='SAOPerform' and preferred.itemType=='Base.Violin'
 and preferred.saoItemId==violin:getID()
 and comparison.actorId==dualId and comparison.selectedModelId=='ordinary'
 and comparison.selected=='instrument:Base.Violin'
 and score(comparison,'instrument:Base.Violin')
  > score(comparison,'instrument:Base.GuitarElectric'),
 'private own success did not outrank the first held instrument')
local sameTypeReplacement=material('Base.Violin')
dualBody.secondary=sameTypeReplacement
ZombieActions.SAOPerform.onStart(dualBody,preferred)
assert(preferred.saoCancelled==true and dualRec.weekOne.nextPerformanceOutcome==2,
 'selected physical item changed before execution but still emitted or earned credit')
dualBody.secondary=violin
local failedMusic={actorId=dualId,sequence=1,workId='dual-music:1',
 purposeId='dual-later-music',sourceId='LifestyleHobbies',revision='installed-test',
 activity='perform-instrument',itemType='Base.Violin',status='interrupted',
 admittedAtHours=SAO.History.countyHours(),
 atHours=SAO.History.countyHours()}
local formerMusic,formerPlanning=SAO.LeisureMusic,SAO.ProceduralPlanning
SAO.LeisureMusic={outcome=function(id,sequence)
 return id==dualId and sequence==1 and failedMusic or nil end}
SAO.ProceduralPlanning={hobbyAdmission=function(id,purposeId,workId)
 if id==dualId and purposeId==failedMusic.purposeId and workId==failedMusic.workId then
  local binding={ownerName='SAO.LeisureMusic'}
  for key,value in pairs(failedMusic) do binding[key]=value end
  return binding end
end}
local failedAcquired=SAO.Cognition.hobbyOutcome(dualId,'SAO.LeisureMusic',1)
SAO.LeisureMusic,SAO.ProceduralPlanning=formerMusic,formerPlanning
assert(failedAcquired==true,
 'later failed own violin attempt did not enter private evidence')
__tick=__tick+21
local reconsidered=ZombiePrograms.Entertainer.Main(dualBody).tasks[1]
comparison=dualRec.weekOne.leisureComparison
assert(reconsidered.action=='SAOPerform'
 and reconsidered.itemType=='Base.GuitarElectric'
 and comparison.selected=='instrument:Base.GuitarElectric'
 and score(comparison,'instrument:Base.GuitarElectric')
  > score(comparison,'instrument:Base.Violin'),
 'later failed own violin attempt did not change the private comparison')

__step='private-leisure-hearing-and-scene'
local oldNeeds=SAO.Needs
local shellNeedsCalls=0
SAO.Needs={read=function()
 shellNeedsCalls=shellNeedsCalls+1
 return nil
end}
__roleFeature='chair' __tick=1926
local listenerBrain,listenerBody=__stage(9302,'Entertainer','Main')
listenerBrain.endurance=.1
listenerBody.primary=material('Base.GuitarElectric')
listenerBody.secondary=material('Base.Violin')
local listenerId=W.observeBrain(listenerBrain,listenerBody)
local listenerRec=__records[listenerId]
local exactBody,exactBrain=W.sourceBodyFor(listenerId)
assert(exactBody==listenerBody and exactBrain==listenerBrain,
 'source proxy needs fixture did not bind the live person, brain and body')
local epoch='00000000-0000-0000-0000-000000000000'
local heard={actorId=musicId,brainId=musician.id,born=musician.born,
 observerBrainId=listenerBrain.id,observerBorn=listenerBrain.born,
 soundId='BWOInstrumentBassGuitar1',soundHandle=1,
 pulseId=epoch..'-1',epoch=epoch,sequence=1,clock='native-world-age-hours',
 emittedAtHours=168.5,heardAtHours=168.51,witnessedAtHours=168.52,
 atHours=168.53,acquiredAtCountyHours=168.54}
listenerRec.weekOnePerformanceHearings={heard}
local originalHearings=SAO.Perception.weekOnePerformanceHearings
SAO.Perception.weekOnePerformanceHearings=function(id)
 return id==listenerId and listenerRec.weekOnePerformanceHearings or {} end
local heardOk=SAO.Cognition.weekOnePerformanceHearings(listenerId)
assert(heardOk==true and SAO.Cognition.weekOneMusicInterest(listenerId).status
 =='single-hearing' and #listenerRec.cognition.experiences==1
 and listenerRec.cognition.experiences[1].kind=='weekone-performance-hearing'
 and listenerRec.cognition.experiences[1].succeeded==nil,
 'one foreign performance hearing became own hobby success')
local tired=ZombiePrograms.Entertainer.Main(listenerBody).tasks[1]
local tiredChoice=listenerRec.weekOne.leisureComparison
assert(tired.action=='SitInChair'
 and tiredChoice.selected=='rest:visible-chair'
 and math.abs(tiredChoice.pressure-.9)<.000000001
 and tiredChoice.pressureSource=='Bandits2:action-endurance'
 and tiredChoice.sourceEndurance==.1
 and tiredChoice.atHours==SAO.History.countyHours()
 and tiredChoice.heardMusicInterest.status=='single-hearing'
 and score(tiredChoice,'rest:visible-chair')
  > score(tiredChoice,'instrument:Base.GuitarElectric'),
 'source action budget did not favor a visible seat over one foreign hearing: '
 ..tostring(tired.action)..'/'..tostring(tiredChoice.selected)..'/'
 ..tostring(score(tiredChoice,'rest:visible-chair'))..'/'
 ..tostring(score(tiredChoice,'instrument:Base.GuitarElectric'))..'/'
 ..tostring(tiredChoice.heardMusicInterest.status))
listenerBrain.endurance=.95
__roleFeature='road' __tick=__tick+21
local walking=ZombiePrograms.Entertainer.Main(listenerBody).tasks[1]
local walkingChoice=listenerRec.weekOne.leisureComparison
assert(walking.action=='Move' and walkingChoice.selected=='walk:visible-ground'
 and math.abs(walkingChoice.pressure-.05)<.000000001
 and walkingChoice.pressureSource=='Bandits2:action-endurance'
 and walkingChoice.sourceEndurance==.95
 and walkingChoice.atHours==SAO.History.countyHours()
 and score(walkingChoice,'walk:visible-ground')
  > score(walkingChoice,'instrument:Base.GuitarElectric'),
 'current source action budget and visible route did not compete with held music: '
 ..tostring(walking.action)..'/'..tostring(walkingChoice.selected)..'/'
 ..tostring(walkingChoice.pressure))
listenerBody.primary=nil listenerBody.secondary=nil
__roleFeature='chair' __tick=__tick+21
local liveSourceBodyFor=W.sourceBodyFor
W.sourceBodyFor=function() return nil end
local noItem=ZombiePrograms.Entertainer.Main(listenerBody).tasks[1]
W.sourceBodyFor=liveSourceBodyFor
local noItemChoice=listenerRec.weekOne.leisureComparison
assert(noItem.action=='SitInChair' and #noItemChoice.alternatives==1
 and noItemChoice.alternatives[1].id=='rest:visible-chair'
 and noItemChoice.pressure==nil
 and noItemChoice.sourceEndurance==nil
 and noItemChoice.pressureSource==nil
 and noItemChoice.alternatives[1].utility==nil,
 'missing item or unresolved source body fabricated music or pressure')
assert(shellNeedsCalls==0,
 'source proxy leisure asked the native-shell-only SAO.Needs reader')
__step='private-leisure-fallback-custody'
local realComparison=SAO.Cognition.interpretPlans
SAO.Cognition.interpretPlans=function()
 listenerRec.heldBy='other-owner'
 error('comparison interrupted after source claim changed')
end
__tick=__tick+21
local staleFallback=ZombiePrograms.Entertainer.Main(listenerBody)
SAO.Cognition.interpretPlans=realComparison
listenerRec.heldBy='BanditsWeekOne'
assert(staleFallback and (type(staleFallback.tasks[1])~='table'
 or staleFallback.tasks[1].action=='Time'),
 'private comparison failure ran chair or walk after exact claim changed')
SAO.Perception.weekOnePerformanceHearings=originalHearings
SAO.Needs=oldNeeds
SAO.History.countyHours=originalCounty
SAO.History.daysOwed=originalDaysOwed
assert(SAO.Cognition.configure(.5,12,3)==true,
 'private model settings were not restored after the comparison control')
end
for n,name in ipairs({'Patrol','Runner','Walker'}) do
 local _,body,travel=role(name,'road',9+n)
  assert(travel.tasks[1] and travel.tasks[1].action=='Move' and travel.tasks[1].x==86
  and travel.tasks[1].walkType=='Walk'
  and __records[body.md.SAOWeekOnePersonId].weekOne.ordinary.role==nil
  and __records[body.md.SAOWeekOnePersonId].weekOne.ordinary.sourceProgram==name,
   'ordinary visible road motion lost per-person program: '..name
   ..'/'..tostring(travel.tasks[1] and travel.tasks[1].action)
   ..'/'..tostring(__records[body.md.SAOWeekOnePersonId]
    and __records[body.md.SAOWeekOnePersonId].weekOne.decision.purpose))
end
local _,homeBody,home=role('Inhabitant','chair',13)
assert(home.tasks[1].action=='SitInChair' and home.tasks[1].x==80
 and __records[homeBody.md.SAOWeekOnePersonId].weekOne.ordinary.purpose
 =='sit-at-visible-chair',
 'person did not choose visible chair rest')
ZombieActions.Graffiti={onComplete=function() __roleComplete=__roleComplete+1 end}
local conflictValues=SAO.Disposition.conflictValues
SAO.Disposition.conflictValues=function(id)
 local values=conflictValues(id) values.aggression=.9 values.discipline=.1
 return values
end
local spray=material('Base.SprayPaint')
spray.Use=function() __roleComplete=__roleComplete+10 end
local _,vandalBody,paint=role('Vandal','wall',14,spray)
SAO.Disposition.conflictValues=conflictValues
assert(paint.tasks[1].action=='SAOGraffiti' and paint.tasks[1].dir=='N',
 'material and disposition did not select observed unpainted wall')
ZombieActions.SAOGraffiti.onStart(vandalBody,paint.tasks[1])
ZombieActions.SAOGraffiti.onComplete(vandalBody,paint.tasks[1])
assert(__roleComplete==11
 and __records[vandalBody.md.SAOWeekOnePersonId].weekOne.lastOrdinaryOutcome.result
  =='physical-graffiti',
 'owned vandal action did not consume real paint before source wall art')
-- Source family is provenance. The same person-visible trash and broom
-- must produce the same owned action across unrelated source callbacks.
__trashRemoved=false
local cleaning={}
for n,name in ipairs({'Walker','Janitor','Fireman'}) do
 __step='stress:'..name
 __roleFeature='trash' __tick=1700+n*21
 local brain,body=__stage(1680+n,name,'Main')
 body.primary=material('Base.Broom')
 local result=ZombiePrograms[name].Main(body)
 local phase=__records[body.md.SAOWeekOnePersonId].weekOne
 assert(result.tasks[1].action=='SAOCleanTrash'
  and phase.ordinary.purpose=='remove-visible-trash'
  and phase.ordinary.role==nil
  and phase.ordinary.sourceProgram==name,
  'source family changed a person-equal cleaning decision: '..name)
 cleaning[#cleaning+1]=result.tasks[1].action
end
assert(cleaning[1]==cleaning[2] and cleaning[2]==cleaning[3],
 'source family changed a person-equal cleaning decision')
__roleFeature='fire' __fireStopped=false __tick=1800
local _,unsafeFire=__stage(1800,'Fireman','Main')
assert(ZombiePrograms.Fireman.Main(unsafeFire).tasks[1].action=='Time',
 'visible fire without material minted a fire response')
__roleFeature='unrelated' __tick=1821
local _,unseenTrash=__stage(1801,'Janitor','Main')
unseenTrash.primary=material('Base.Broom')
assert(ZombiePrograms.Janitor.Main(unseenTrash).tasks[1].action=='Time',
 'unseen trash selected a world mutation')
__roleFeature='care' __tick=1842
local _,unfundedMedic=__stage(1802,'Medic','Main')
assert(ZombiePrograms.Medic.Main(unfundedMedic).tasks[1].action=='Time',
 'visible injury without physical bandage minted treatment')
__roleFeature=nil
privateLeisureCases()
__tick=2000 __target='zombie' __threat=2
for id=1400,1403 do
 local b,z=__stage(id,'Shahid','Main')
 assert(ZombiePrograms.Shahid.Main(z).tasks[1].action=='Move')
end
local queued,queuedBody=__stage(1404,'Shahid','Main')
local deferred=ZombiePrograms.Shahid.Main(queuedBody)
assert(deferred.next=='Main' and #deferred.tasks==0
 and W.costMetrics().budgetDeferred>=1 and __explosions==0,
 'deferred private scan fell through to global-source explosion')
__tick=2001 W.onBudgetTick()
local admitted=ZombiePrograms.Shahid.Main(queuedBody)
assert(admitted.tasks[1].action=='Move',
 'deferred named program did not regain FIFO private decision')
__step='Bandit/hour-87-123-cohort'
__tick=2200 __target='zombie' __threat=2
local beforeScans=__observations
local cohort={}
for n=1,24 do
 local id=4000+n
 local brain,body=__stage(id,'Bandit','Main')
 brain.loyal=n%2==0
 brain.saoWeekOneReinforcement={source='VBandit.schedule/SpawnGroup',
  eventRef=string.format('%032x',id),age=n<=12 and 87 or 123,
  minute=n<=12 and 33 or 39,variantId=2,count=12,
  brainId=id,born=brain.born}
 cohort[n]={brain=brain,body=body}
 local choice=ZombiePrograms.Bandit.Main(body)
 local person=body.md.SAOWeekOnePersonId
 local event=person and __records[person].weekOne.sourceEvent
 assert(event and event.kind=='reinforcement'
  and event.age==(n<=12 and 87 or 123)
  and event.brainId==id and __records[person].heldBy=='BanditsWeekOne',
  'hour-87/123 Bandit lost exact stamped person admission')
 assert(choice.next=='Main' and #choice.tasks==(n<=4 and 1 or 0),
  '24-actor burst exceeded four private scans or lost deferral')
end
assert(__observations==beforeScans+4 and W.costMetrics().scanQueuePeak>=20
 and __sourceBaseCalls==0 and __sourceTargetCalls==0,
 '24 stamped Bandits bypassed four-scan private budget or source ownership')
for wave=1,5 do
 __tick=2200+wave W.onBudgetTick()
 assert(__observations==beforeScans+4*(wave+1),
  'deferred Bandit burst did not advance by four FIFO private scans')
 for n=wave*4+1,wave*4+4 do
  local choice=ZombiePrograms.Bandit.Main(cohort[n].body)
  assert(choice.tasks[1] and choice.tasks[1].action=='Move'
   and choice.tasks[1].x==82,
   'admitted Bandit did not consume its own deferred sight')
 end
end
assert(__sourceBaseCalls==0 and __sourceRandomCalls==0
 and __sourceTargetCalls==0,
 'the stamped 24-actor cohort reached source sabotage or random programs')
__step='Bandit/broken-body-and-claim'
__tick=2400
local broken,brokenBody=__stage(4100,'Bandit','Main')
local brokenPerson=W.observeBrain(broken,brokenBody)
brokenBody.md.SAOWeekOnePersonId='foreign-person'
local blocked=ZombiePrograms.Bandit.Main(brokenBody)
assert(blocked.next=='Main' and #blocked.tasks==0
 and __records[brokenPerson].heldBy=='BanditsWeekOne'
 and __sourceBaseCalls==0,
 'conflicted Bandit body fell back to source program')
local unclaimed,unclaimedBody=__stage(4101,'Bandit','Main')
local unclaimedPerson=W.observeBrain(unclaimed,unclaimedBody)
__records[unclaimedPerson].heldBy='other-owner'
local heldBandit=ZombiePrograms.Bandit.Main(unclaimedBody)
assert(heldBandit.next=='Main' and #heldBandit.tasks==0
 and __sourceBaseCalls==0,
 'Bandit source callback ran after exact person claim changed')
__step='Bandit/missing-brain'
local missingBrain,missingBody=__stage(4103,'Bandit','Main')
assert(W.observeBrain(missingBrain,missingBody),
 'marked body was not admitted before a source brain lookup failure')
__brains[4103]=nil
local missingResult=ZombiePrograms.Bandit.Main(missingBody)
assert(missingResult.next=='Main' and #missingResult.tasks==0
 and __sourceBaseCalls==0,
 'already marked Bandit body ran source program after brain lookup failed')
__step='Bandit/changed-origin'
local changedOrigin,changedBody=__stage(4104,'Bandit','Main')
assert(W.observeBrain(changedOrigin,changedBody),
 'marked body was not admitted before source origin changed')
changedOrigin.saoWeekOneOrigin='Bandits2'
local changedResult=ZombiePrograms.Bandit.Main(changedBody)
assert(changedResult.next=='Main' and #changedResult.tasks==0
 and __sourceBaseCalls==0,
 'marked Bandit body ran source program after origin changed')
__step='Bandit/unstamped-source'
local foreignBandit,foreignBanditBody=__stage(4102,'Bandit','Main','Bandits2')
foreignBanditBody.getSquare=function() return {
 getRoom=function() return nil end} end
local originalBase,originalTarget=__sourceBaseCalls,__sourceTargetCalls
local originalMain=ZombiePrograms.Bandit.Main(foreignBanditBody)
assert(originalMain.next=='Main' and originalMain.tasks[1].anim=='Shrug'
 and __sourceBaseCalls==originalBase+1
 and __sourceTargetCalls==originalTarget+1
 and foreignBanditBody.md.SAOWeekOnePersonId==nil,
 'unstamped Bandits2 Main did not execute original exactly once')
foreignBandit.program.stage='Escape'
local originalClosest=BanditUtils.GetClosestPlayerLocation
local sourceEscapeCalls=0
BanditUtils.GetClosestPlayerLocation=function()
 sourceEscapeCalls=sourceEscapeCalls+1 return {x=80,y=80,z=0} end
local originalEscape=ZombiePrograms.Bandit.Escape(foreignBanditBody)
BanditUtils.GetClosestPlayerLocation=originalClosest
assert(originalEscape.next=='Escape' and sourceEscapeCalls==1
 and originalEscape.tasks[1].action=='Move'
 and __sourceRandomCalls==4,
 'unstamped Bandits2 Escape did not execute original exactly once')
foreignBandit.program.stage='Surrender'
local originalSurrender=ZombiePrograms.Bandit.Surrender(foreignBanditBody)
assert(originalSurrender.next=='Surrender'
 and originalSurrender.tasks[1].anim=='Surrender'
 and __sourceRandomCalls==5,
 'unstamped Bandits2 Surrender did not execute original exactly once')
__step='dynamic/dispatcher'
assert(W.dispatchWrapped==Bandit.GetProgram
 and ZombiePrograms.SAOWeekOnePrivateDispatcher==W.dispatchFamily
 and W.dispatchFamily.Main==W.dispatchStageWrapped,
 'installed Bandit.GetProgram did not receive the central SAO guard')
local function dispatch(body)
 local selected=Bandit.GetProgram(body)
 assert(selected and selected.name and selected.stage,
  'central dispatcher did not select a callback')
 local result=ZombiePrograms[selected.name][selected.stage](body)
 if result.status and result.next then Bandit.SetProgramStage(body,result.next) end
 return selected,result
end
local dynamicSourceCalls=0
ZombiePrograms.FutureWeekOne={Scout=function()
 dynamicSourceCalls=dynamicSourceCalls+1
 return {status=true,next='Scout',tasks={{action='SourceTask'}}}
end}
__roleFeature='trash' __target='none' __threat=0 __tick=2600
local dynamicBrain,dynamicBody=__stage(4200,'FutureWeekOne','Scout')
dynamicBody.primary=material('Base.Broom')
local routed,chosen=dispatch(dynamicBody)
local dynamicPerson=dynamicBody.md.SAOWeekOnePersonId
assert(routed.name=='SAOWeekOnePrivateDispatcher' and chosen.next=='Scout'
 and chosen.tasks[1] and chosen.tasks[1].action=='SAOCleanTrash'
 and dynamicBrain.program.name=='FutureWeekOne'
 and dynamicBrain.program.stage=='Scout' and dynamicSourceCalls==0
 and __records[dynamicPerson].weekOne.ordinary.sourceProgram=='FutureWeekOne'
 and __records[dynamicPerson].weekOne.decision.adapter=='FutureWeekOne.Scout',
 'dynamic source family changed the person choice or source provenance')
__tick=2610
local equalBrain,equalBody=__stage(4205,'OtherSourceName','UnlistedStage')
equalBody.primary=material('Base.Broom')
local equalRoute,equalChoice=dispatch(equalBody)
local equalPhase=__records[equalBody.md.SAOWeekOnePersonId].weekOne
assert(equalRoute.name=='SAOWeekOnePrivateDispatcher'
 and equalChoice.tasks[1] and equalChoice.tasks[1].action
  ==chosen.tasks[1].action
 and equalPhase.ordinary.role==nil
 and equalPhase.ordinary.sourceProgram=='OtherSourceName'
 and equalBrain.program.name=='OtherSourceName',
 'source family changed an otherwise equal private cleaning decision')
__step='dynamic/prepare'
ZombiePrograms.FutureWeekOne.Prepare=function()
 dynamicSourceCalls=dynamicSourceCalls+1
 return {status=true,next='Main',tasks={{action='SourceTask'}}}
end
local priorStationary=__stationary
local prepareBrain,prepareBody=__stage(4204,'FutureWeekOne','Prepare')
local prepareRoute,prepareChoice=dispatch(prepareBody)
assert(prepareRoute.name=='SAOWeekOnePrivateDispatcher'
 and prepareChoice.next=='Main' and #prepareChoice.tasks==0
 and prepareBrain.program.name=='FutureWeekOne'
 and prepareBrain.program.stage=='Main' and __stationary==priorStationary+1
 and dynamicSourceCalls==0,
 'dynamic preparation did not admit and release the exact person')
__step='dynamic/unknown-stage'
ZombiePrograms.Bandit.Ambush=function()
 dynamicSourceCalls=dynamicSourceCalls+1
 return {status=true,next='Ambush',tasks={{action='SourceTask'}}}
end
__roleFeature=nil __target='zombie' __threat=2 __tick=2620
local newStageBrain,newStageBody=__stage(4201,'Bandit','Ambush')
local stageRoute,stageChoice=dispatch(newStageBody)
assert(stageRoute.name=='SAOWeekOnePrivateDispatcher'
 and stageChoice.next=='Ambush' and stageChoice.tasks[1].action=='Move'
 and newStageBrain.program.name=='Bandit'
 and newStageBrain.program.stage=='Ambush' and dynamicSourceCalls==0,
 'unknown source stage bypassed private sight or changed provenance')
__step='dynamic/unloaded-family'
__roleFeature='road' __target='none' __threat=0 __tick=2640
local missingFamilyBrain,missingFamilyBody=__stage(4202,'UnloadedWeekOne','Observe')
local missingRoute,missingChoice=dispatch(missingFamilyBody)
assert(missingRoute.name=='SAOWeekOnePrivateDispatcher'
 and missingChoice.next=='Observe' and missingChoice.tasks[1].action=='Move'
 and missingFamilyBrain.program.name=='UnloadedWeekOne'
 and missingFamilyBrain.program.stage=='Observe',
 'unloaded dynamic source family was dereferenced or displaced provenance')
__step='dynamic/survivor-load-order'
__tick=2660
local survivorBrain,survivorBody=__stage(4203,'Survivor','Main')
local survivorRoute,survivorChoice=dispatch(survivorBody)
assert(survivorRoute==survivorBrain.program
 and survivorChoice.status and dynamicSourceCalls==0
 and __records[survivorBody.md.SAOWeekOnePersonId].weekOne.decision.adapter
  =='Survivor.Main',
 'marked Survivor did not retain its installed SAO stage wrapper')
local survivorWrapper=ZombiePrograms.Survivor.Main
ZombiePrograms.Survivor.Main=function()
 dynamicSourceCalls=dynamicSourceCalls+1
 return {status=true,next='Main',tasks={{action='SourceTask'}}}
end
__tick=2680
local replacedRoute,replacedChoice=dispatch(survivorBody)
assert(replacedRoute.name=='SAOWeekOnePrivateDispatcher'
 and replacedChoice.tasks[1].action=='Move' and dynamicSourceCalls==0
 and survivorBrain.program.name=='Survivor',
 'later Survivor callback replacement escaped the private dispatcher')
ZombiePrograms.Survivor.Main=survivorWrapper
__step='dynamic/budget-and-body'
__roleFeature=nil __target='zombie' __threat=2 __tick=2700
for id=4230,4233 do
 local _,body=__stage(id,'FutureWeekOne','Scout')
 assert(dispatch(body).name=='SAOWeekOnePrivateDispatcher')
end
local deferredBrain,deferredBody=__stage(4234,'FutureWeekOne','Scout')
local deferredRoute,deferredChoice=dispatch(deferredBody)
assert(deferredRoute.name=='SAOWeekOnePrivateDispatcher'
 and deferredChoice.next=='Scout' and #deferredChoice.tasks==0
 and deferredBrain.program.stage=='Scout' and dynamicSourceCalls==0,
 'dynamic private deferral ran a source callback')
local wrongBrain,properBody=__stage(4240,'FutureWeekOne','Scout')
local wrongBody=__body(4241) __brains[4241]=wrongBrain
local wrongRoute,wrongChoice=dispatch(wrongBody)
assert(wrongRoute.name=='SAOWeekOnePrivateDispatcher'
 and wrongChoice.next=='Scout' and #wrongChoice.tasks==0
 and properBody.md.SAOWeekOnePersonId==nil and dynamicSourceCalls==0,
 'dynamic body mismatch ran a source callback')
__step='dynamic/foreign-passthrough'
local foreignDynamic,foreignDynamicBody=__stage(4242,'FutureWeekOne','Scout','Bandits2')
local sourceGet=BanditBrain.Get
local brainGets=0
BanditBrain.Get=function(body) brainGets=brainGets+1 return sourceGet(body) end
local foreignProgram=Bandit.GetProgram(foreignDynamicBody)
BanditBrain.Get=sourceGet
local sourceChoice=ZombiePrograms[foreignProgram.name][foreignProgram.stage](foreignDynamicBody)
assert(foreignProgram==foreignDynamic.program and brainGets==2
 and sourceChoice.tasks[1].action=='SourceTask' and dynamicSourceCalls==1,
 'foreign dynamic source did not pass through exactly once')
__step='dynamic/conflicts'
local getHook=Bandit.GetProgram
Bandit.GetProgram=function() return nil end
local dispatchSafe,dispatchReason=W.installDispatchAdapter()
assert(dispatchSafe==false and dispatchReason=='dispatch-hook-changed'
 and __stores.SurvivorAwareness_WeekOneContinuity.lastProgramHookConflict
  =='Bandit.GetProgram',
 'foreign replacement of central dispatcher was accepted silently')
Bandit.GetProgram=getHook
local dispatchFamily=W.dispatchFamily
ZombiePrograms.SAOWeekOnePrivateDispatcher={Main=function() return nil end}
local familySafe,familyReason=W.installDispatchAdapter()
assert(familySafe==false and familyReason=='dispatch-family-conflict',
 'foreign dispatch family was overwritten')
ZombiePrograms.SAOWeekOnePrivateDispatcher=dispatchFamily
assert(W.installDispatchAdapter()==true,
 'central dispatcher failed to revalidate after conflict removal')
local wrapper=ZombiePrograms.Shahid.Main
ZombiePrograms.Shahid.Main=function() return {status=true,next='Main',tasks={}} end
local safe,reason=W.installProgramAdapters()
assert(safe==false and reason=='program-hook-changed:Shahid.Main'
 and __stores.SurvivorAwareness_WeekOneContinuity.lastProgramHookConflict=='Shahid.Main',
 'foreign replacement of an owned program callback was accepted silently')
ZombiePrograms.Shahid.Main=wrapper
return 'PASS'
'''

ADVERSARIAL_CASES = r'''
__step='performance/custody-inverses'
assert(SAO.Cognition.configure(.5,12,3)==true,
 'private cognition did not enable the custody control')
local itemId=1900
local function material()
 itemId=itemId+1 local id=itemId
 return {getFullType=function() return 'Base.GuitarElectric' end,
  getID=function() return id end}
end
local function freshPerformance(id)
 __roleFeature=nil __target='none' __threat=0 __tick=__tick+21
 local brain,body=__stage(id,'Entertainer','Main')
 body.primary=material()
 local selected=ZombiePrograms.Entertainer.Main(body)
 assert(selected.tasks[1] and selected.tasks[1].action=='SAOPerform',
  'adversarial source fixture did not select physical performance')
 return body,selected.tasks[1],__records[body.md.SAOWeekOnePersonId]
end
local swappedBody,swappedTask,swappedRec=freshPerformance(9201)
ZombieActions.SAOPerform.onStart(swappedBody,swappedTask)
swappedBody.primary=material()
assert(ZombieActions.SAOPerform.onWorking(swappedBody,swappedTask)==true,
 'same-type replacement did not interrupt exact instrument custody')
ZombieActions.SAOPerform.onComplete(swappedBody,swappedTask)
assert(swappedRec.weekOne.performanceOutcomes==nil and swappedRec.cognition==nil,
 'replacement instrument minted a performance receipt')
local staleBody,staleTask,staleRec=freshPerformance(9202)
ZombieActions.SAOPerform.onStart(staleBody,staleTask)
staleRec.weekOne.decision.atTick=staleRec.weekOne.decision.atTick+1
assert(ZombieActions.SAOPerform.onWorking(staleBody,staleTask)==true,
 'stale source decision did not stop its performance')
ZombieActions.SAOPerform.onComplete(staleBody,staleTask)
assert(staleRec.weekOne.performanceOutcomes==nil and staleRec.cognition==nil,
 'stale decision minted a performance receipt')
local claimBody,claimTask,claimRec=freshPerformance(9203)
ZombieActions.SAOPerform.onStart(claimBody,claimTask)
claimRec.heldBy=nil
assert(ZombieActions.SAOPerform.onWorking(claimBody,claimTask)==true,
 'lost source claim did not stop its performance')
ZombieActions.SAOPerform.onComplete(claimBody,claimTask)
assert(claimRec.weekOne.performanceOutcomes==nil and claimRec.cognition==nil,
 'lost source claim minted a performance receipt')
local sharedBody,sharedTask,sharedRec=freshPerformance(9204)
ZombieActions.SAOPerform.onStart(sharedBody,sharedTask)
local ownedHandle=SAO.WeekOneContinuity.performanceSoundOwners[sharedTask].soundHandle
local otherHandle=sharedBody.emitter:playSound(sharedTask.saoSound)
ZombieActions.SAOPerform.onComplete(sharedBody,sharedTask)
assert(not sharedBody.emitter:isPlaying(ownedHandle)
 and sharedBody.emitter:isPlaying(otherHandle)
 and sharedRec.weekOne.performanceOutcomes[1],
 'source action stopped a different same-name sound or lost its own receipt')
sharedBody.emitter:stopSound(otherHandle)
local wrongBody,wrongTask,wrongRec=freshPerformance(9205)
ZombieActions.SAOPerform.onStart(wrongBody,wrongTask)
local owner=SAO.WeekOneContinuity.performanceSoundOwners[wrongTask]
local originalHandle=owner.soundHandle
owner.soundHandle=originalHandle+100
ZombieActions.SAOPerform.onComplete(wrongBody,wrongTask)
assert(wrongTask.saoCancelled==true
 and not wrongBody.emitter:isPlaying(originalHandle)
 and wrongRec.weekOne.performanceOutcomes==nil,
 'stale source handle minted credit or left its exact audio running')
local delayedBody,delayedTask,delayedRec=freshPerformance(9301)
local settings=ModData.getOrCreate('SurvivorAwareness_Cognition').settings
settings.enabled=false
for sequence=1,32 do
 if sequence>1 then
  __tick=__tick+21
  delayedTask=ZombiePrograms.Entertainer.Main(delayedBody).tasks[1]
 end
 assert(delayedTask and delayedTask.action=='SAOPerform',
  'disabled cognition displaced physical source performance')
 ZombieActions.SAOPerform.onStart(delayedBody,delayedTask)
 ZombieActions.SAOPerform.onComplete(delayedBody,delayedTask)
 assert(SAO.WeekOneContinuity.performanceOutcome(delayedRec.id,sequence),
  'unadmitted canonical performance was lost from bounded journal')
end
__tick=__tick+21
local saturated=ZombiePrograms.Entertainer.Main(delayedBody).tasks[1]
assert(saturated and saturated.action~='SAOPerform',
 'full unadmitted journal scheduled a performance it could not record')
assert(#delayedRec.weekOne.performanceOutcomes==32
 and delayedRec.weekOne.nextPerformanceOutcome==33
 and delayedRec.cognition==nil
 and __stores.SurvivorAwareness_WeekOneContinuity.pendingPerformanceByPerson[delayedRec.id],
 'disabled cognition silently advanced or trimmed the source journal')
-- The live brain row may already have been archived by the time cognition
-- returns; the durable person pending index must still find its receipt.
local delayedStore=__stores.SurvivorAwareness_WeekOneContinuity
assert(delayedStore.byBrain['9301']
 and delayedStore.byBrain['9301'].personId==delayedRec.id,
 'delayed source fixture lacked its live crosswalk')
delayedStore.byBrain['9301']=nil
settings.enabled=true
SAO.WeekOneContinuity.poll(true)
assert(delayedRec.weekOne.performanceCognitionThrough==32
 and delayedRec.cognition.nativeExperienceCursors['weekone-instrument-performance']==32
 and #delayedRec.cognition.experiences==32
 and #delayedRec.weekOne.performanceOutcomes==16
 and __stores.SurvivorAwareness_WeekOneContinuity.pendingPerformanceByPerson[delayedRec.id]==nil,
 'bounded poll did not replay every delayed source performance in order')
local refusedBody,refusedTask,refusedRec=freshPerformance(9302)
local realCallback=SAO.Cognition.weekOnePerformanceOutcome
SAO.Cognition.weekOnePerformanceOutcome=function() return false,'test-refusal' end
ZombieActions.SAOPerform.onStart(refusedBody,refusedTask)
ZombieActions.SAOPerform.onComplete(refusedBody,refusedTask)
assert(refusedRec.weekOne.performanceOutcomes[1]
 and refusedRec.weekOne.performanceCognitionThrough==nil
 and refusedRec.cognition==nil,
 'refused private acquisition was mistaken for completion')
SAO.WeekOneContinuity.poll(true)
assert(refusedRec.cognition==nil and refusedRec.weekOne.performanceOutcomes[1],
 'poll discarded a still-refused source performance')
SAO.Cognition.weekOnePerformanceOutcome=realCallback
SAO.WeekOneContinuity.poll(true)
assert(refusedRec.weekOne.performanceCognitionThrough==1
 and refusedRec.cognition.nativeExperienceCursors['weekone-instrument-performance']==1
 and #refusedRec.cognition.experiences==1,
 'refused source receipt did not replay after cognition recovered')
local failedStopBody,failedStopTask,failedStopRec=freshPerformance(9303)
local actualStop=failedStopBody.emitter.stopSound
failedStopBody.emitter.stopSound=function() error('temporary emitter refusal') end
ZombieActions.SAOPerform.onStart(failedStopBody,failedStopTask)
ZombieActions.SAOPerform.onComplete(failedStopBody,failedStopTask)
assert(failedStopBody.emitter.playing==true
 and failedStopRec.weekOne.performanceOutcomes==nil
 and failedStopRec.cognition==nil,
 'failed sound stop minted credit or falsely claimed silence')
failedStopBody.emitter.stopSound=actualStop
SAO.WeekOneContinuity.poll(true)
assert(failedStopBody.emitter.playing==false
 and failedStopRec.weekOne.performanceOutcomes==nil
 and failedStopRec.cognition==nil,
 'poll did not retry the exact refused emitter cleanup')
local orphanBody,orphanTask,orphanRec=freshPerformance(9304)
local orphanBrain=BanditBrain.Get(orphanBody)
orphanBrain.tasks={orphanTask}
ZombieActions.SAOPerform.onStart(orphanBody,orphanTask)
assert(orphanBody.emitter.playing==true,
 'queued physical task did not start its owned sound')
SAO.WeekOneContinuity.poll(true)
assert(orphanBody.emitter.playing==true and orphanTask.saoCancelled~=true,
 'still-queued source task was mistaken for an orphan')
orphanBrain.tasks={}
SAO.WeekOneContinuity.poll(true)
assert(orphanBody.emitter.playing==false and orphanTask.saoCancelled==true
 and orphanRec.weekOne.performanceOutcomes==nil and orphanRec.cognition==nil,
 'cleared source task retained its prior exact sound or minted credit')
return 'PASS'
'''

CONTROLS = [
    ("family-prepare", 'local stages = { "Prepare" }',
     'local stages = { }', 'the exact stage wrappers did not install once'),
    ("private-stage", 'function W.ownedProgramStage(brain, body, family, stage)\n',
     'function W.ownedProgramStage(brain, body, family, stage)\n'
     '    acceptedStagePlan = function() return nil, "source-plan-unavailable" end\n',
     'source hostile/global decision displaced SAO sight'),
    ("escape-sight", 'local task, x, y, z = escapeTask(body, plan)',
     'local task, x, y, z = nil, nil, nil, nil',
     'the person surrendered to a zombie or used source random flight'),
    ("stamped-no-source", 'return stageResult(stage)\n',
     'return previous(body)\n',
     'conflicted exact source body ran the arbitrary source possession branch'),
    ("fire-material", 'if physicalExtinguisher(body) then',
     'if true then', 'visible fire without material minted a fire response'),
    ("family-independence", 'if physicalItem(body, "Base.Broom") then',
     'if brain.program.name == "Janitor" and physicalItem(body, "Base.Broom") then',
     "source family changed a person-equal cleaning decision"),
    ("feature-sight", 'if visibleFeature(body, square, kind) then',
     'if square then', 'ordinary visible road motion lost per-person program'),
    ("medic-material", 'if physicalBandage(body) then',
     'if true then', 'visible injury without physical bandage minted treatment'),
    ("action-once", 'if task.saoCompleted then return true end',
     'if false then return true end',
     'one physical fire task replayed after completion'),
    ("weekone-private-performance",
     'if receipt then W.reconcilePerformanceOutcomes(receipt.actorId) end',
     'if receipt then W.reconcilePerformanceOutcomes = function() return false end end',
     'private weekone performance not acquired with exact source custody'),
    ("paint-material", 'local consumed = pcall(function() spray:Use() end)',
     'local consumed = true',
     'owned vandal action did not consume real paint before source wall art'),
    ("bandit-main-stage", 'Bandit = { Main = true, Escape = true, Surrender = true },',
     'Bandit = { Escape = true, Surrender = true },',
     'the exact stage wrappers did not install once'),
    ("bandit-escape-stage", 'Bandit = { Main = true, Escape = true, Surrender = true },',
     'Bandit = { Main = true, Surrender = true },',
     'the exact stage wrappers did not install once'),
    ("bandit-surrender-stage", 'Bandit = { Main = true, Escape = true, Surrender = true },',
     'Bandit = { Main = true, Escape = true },',
     'the exact stage wrappers did not install once'),
    ("bandit-person-surrender", 'plan.targetKind == "person" and plan.dist <= 6',
     'plan.targetKind == "zombie" and plan.dist <= 6',
     'observed person and private caution did not own physical surrender'),
    ("marked-source-loss", 'if marked then return stageResult(stage) end',
     'if marked then return previous(body) end',
     'FAIL:Bandit/missing-brain:'),
    ("four-scan-bandit-budget", 'local SCANS_PER_TICK = 4',
     'local SCANS_PER_TICK = 5',
     'deferred private scan fell through to global-source explosion'),
    ("central-dispatch-hook", 'W.dispatchWrapped = wrapped',
     'W.dispatchWrapped = nil',
     'installed Bandit.GetProgram did not receive the central SAO guard'),
    ("dynamic-source-bypass",
     'return { name = DISPATCH_FAMILY, stage = "Main" }\n'
     '        end\n        return previous(body)',
     'return program\n        end\n        return previous(body)',
     'dynamic source family changed the person choice or source provenance'),
    ("dynamic-private-choice",
     'local ok, result = pcall(W.dynamicProgramStage, brain, body)',
     'local ok, result = false, nil',
     'dynamic source family changed the person choice or source provenance'),
    ("dynamic-stage-writeback",
     'local nextStage = stage == "Main" and "Main" or stage',
     'local nextStage = "Main"',
     'dynamic source family changed the person choice or source provenance'),
    ("dynamic-prepare-admission",
     'if stage == "Prepare" then\n'
     '        return W.prepareProgram(brain, body, family) end',
     'if false then\n'
     '        return W.prepareProgram(brain, body, family) end',
     'dynamic preparation did not admit and release the exact person'),
    ("dispatch-family-conflict",
     'if existing and existing ~= W.dispatchFamily then',
     'if false then',
     'foreign dispatch family was overwritten'),
]

LATE_CASES = r'''
__step='late-load/dispatcher'
local W=SAO.WeekOneContinuity
assert(W.dispatchWrapped==nil,
 'central dispatcher installed before the source Bandit.GetProgram existed')
local installed,reason=W.installDispatchAdapter()
assert(installed==true and W.dispatchWrapped==Bandit.GetProgram,
 'late source dispatcher did not install after Bandit.lua')
assert(W.installDispatchAdapter()==true,
 'late source dispatcher was not idempotent')
__roleFeature='road' __target='none' __threat=0 __tick=100
local survivor,survivorBody=__stage(5100,'Survivor','Main')
local selected=Bandit.GetProgram(survivorBody)
local result=ZombiePrograms[selected.name][selected.stage](survivorBody)
assert(selected==survivor.program and result.status
 and __records[survivorBody.md.SAOWeekOnePersonId].weekOne.decision.adapter
  =='Survivor.Main',
 'late load order displaced marked Survivor ownership')
local sourceCalls=0
ZombiePrograms.UnlistedWeekOne={Investigate=function()
 sourceCalls=sourceCalls+1
 return {status=true,next='Investigate',tasks={{action='SourceTask'}}}
end}
__tick=120
local unknown,unknownBody=__stage(5101,'UnlistedWeekOne','Investigate')
local route=Bandit.GetProgram(unknownBody)
local choice=ZombiePrograms[route.name][route.stage](unknownBody)
Bandit.SetProgramStage(unknownBody,choice.next)
assert(route.name=='SAOWeekOnePrivateDispatcher'
 and choice.tasks[1] and choice.tasks[1].action=='Move'
 and unknown.program.name=='UnlistedWeekOne'
 and unknown.program.stage=='Investigate' and sourceCalls==0,
 'late source dynamic program bypassed private choice')
return 'PASS'
'''

LATE_CONFLICT_CASES = r'''
__step='late-load/family-conflict'
local W=SAO.WeekOneContinuity
assert(W.dispatchWrapped==nil,
 'central dispatcher installed before the source Bandit.GetProgram existed')
local sourceGet=Bandit.GetProgram
local foreign={Main=function() return 'foreign' end}
ZombiePrograms.SAOWeekOnePrivateDispatcher=foreign
local installed,reason=W.installDispatchAdapter()
assert(installed==false and reason=='dispatch-family-conflict'
 and ZombiePrograms.SAOWeekOnePrivateDispatcher==foreign
 and Bandit.GetProgram==sourceGet and W.dispatchWrapped==nil,
 'preexisting dispatch family was overwritten at late install')
return 'PASS'
'''

RELOAD_BEFORE = r'''
__step='reload/before'
__roleFeature=nil __target='none' __threat=0 __tick=2300
assert(SAO.Cognition.configure(.5,12,3)==true,
 'reload fixture cognition unavailable')
local pendingBrain,pendingBody=__stage(9102,'Entertainer','Main')
pendingBody.primary={getFullType=function() return 'Base.GuitarElectric' end,
 getID=function() return 1902 end}
local pendingTask=ZombiePrograms.Entertainer.Main(pendingBody).tasks[1]
local settings=ModData.getOrCreate('SurvivorAwareness_Cognition').settings
assert(settings and settings.enabled==true,'reload fixture cognition unavailable')
settings.enabled=false
ZombieActions.SAOPerform.onStart(pendingBody,pendingTask)
ZombieActions.SAOPerform.onComplete(pendingBody,pendingTask)
__reloadPendingId=pendingBody.md.SAOWeekOnePersonId
assert(SAO.WeekOneContinuity.performanceOutcome(__reloadPendingId,1)
 and __records[__reloadPendingId].cognition==nil,
 'reload fixture lost the disabled canonical receipt')
settings.enabled=true
__tick=__tick+21
local brain,body=__stage(9101,'Entertainer','Main')
body.primary={getFullType=function() return 'Base.GuitarElectric' end,
 getID=function() return 1901 end}
local stage=ZombiePrograms.Entertainer.Main(body)
__reloadBody=body __reloadTask=stage.tasks[1]
__reloadId=body.md.SAOWeekOnePersonId
assert(__reloadTask.action=='SAOPerform'
 and SAO.Cognition.configure(.5,12,3)==true,
 'reload fixture lacked a source-owned physical performance')
ZombieActions.SAOPerform.onStart(body,__reloadTask)
assert(body.emitter.playing==true,'reload fixture did not emit sound')
__reloadOldAction=ZombieActions.SAOPerform
'''

RELOAD_AFTER = r'''
__step='reload/after'
assert(ZombieActions.SAOPerform~=__reloadOldAction
 and SAO.WeekOneContinuity.roleActions.SAOPerform==ZombieActions.SAOPerform,
 'source module reload did not install its new action owner')
assert(__reloadBody.emitter.playing==false,
 'source module reload left its prior exact instrument sound playing')
assert(__records[__reloadPendingId].cognition==nil,
 'source module reload invented private receipt without reconciliation')
SAO.WeekOneContinuity.poll(true)
assert(__records[__reloadPendingId].cognition
 and __records[__reloadPendingId].cognition.nativeExperienceCursors['weekone-instrument-performance']==1,
 'source module reload lost a previously refused terminal receipt')
ZombieActions.SAOPerform.onComplete(__reloadBody,__reloadTask)
local phase=__records[__reloadId].weekOne
assert(phase.nextPerformanceOutcome==nil
 and phase.performanceOutcomes==nil
 and __records[__reloadId].cognition==nil,
 'module reload promoted an earlier unowned sound to private performance')
return 'PASS'
'''

RECOVERY_CONTROLS = [
    ("weekone-exact-sound-handle",
     'emitter:stopSound(owner.soundHandle)',
     'emitter:stopSoundByName(owner.sound)',
     'source action stopped a different same-name sound or lost its own receipt',
     'adversarial'),
    ("weekone-pending-index",
     'local performanceKeys = pollKeys(s.pendingPerformanceByPerson,',
     'local performanceKeys = pollKeys({},',
     'bounded poll did not replay every delayed source performance in order',
     'adversarial'),
    ("weekone-no-unadmitted-trim",
     'and type(rows[1]) == "table" and rows[1].sequence <= through do',
     'and type(rows[1]) == "table" and rows[1].sequence >= 0 do',
     'full unadmitted journal scheduled a performance it could not record',
     'adversarial'),
    ("weekone-hot-reload-silence",
     'W.stopStalePerformanceSounds()\nlocal actionPhase',
     'local actionPhase',
     'source module reload left its prior exact instrument sound playing',
     'reload'),
    ("weekone-cleared-task-silence",
     'if owner.generation ~= performanceGeneration or owner.revoked == true\n            or not queuedOwnedPerformance(task, owner) then',
     'if owner.generation ~= performanceGeneration or owner.revoked == true then',
     'cleared source task retained its prior exact sound or minted credit',
     'adversarial'),
]


def main():
    paths = [PROGRAMS / name for name in PINS] + [BASE_BANDIT, BANDIT_DISPATCH]
    if not all(path.is_file() for path in [SOURCE, COGNITIVE_MODELS, COGNITION,
        GAME / "projectzomboid.jar", GAME / "stdlib.lua",
        JDK / "java.exe", JDK / "javac.exe", *paths]):
        raise SystemExit("missing exact installed Week One source or Kahlua")
    observed = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in paths}
    if observed != {**PINS, BASE_BANDIT.name: BASE_BANDIT_SHA,
        BANDIT_DISPATCH.name: BANDIT_DISPATCH_SHA}:
        raise RuntimeError("installed Week One program catalog drifted")
    source = SOURCE.read_text(encoding="utf-8")
    inputs = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (SOURCE, COGNITIVE_MODELS, COGNITION, Path(__file__))}
    receipt = {"saoSourceSha256": inputs[str(SOURCE)],
        "cognitiveModelsSha256": inputs[str(COGNITIVE_MODELS)],
        "cognitionSha256": inputs[str(COGNITION)],
        "inputs": inputs, "installedSources": observed, "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-programs-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + PORTS + ADDITIONS
            + "\nSAO.History.countyHours=function() return __clock end\n"
            + "\n__banditTestMethods={}\nfor key,value in pairs(Bandit) do "
              "__banditTestMethods[key]=value end\n",
            encoding="utf-8")
        (work / "post_dispatch.lua").write_text(
            "for key,value in pairs(__banditTestMethods) do "
            "if key~='GetProgram' and key~='SetProgramStage' then "
            "Bandit[key]=value end end\n", encoding="utf-8")
        (work / "cases.lua").write_text("function __cases()\n" + CASES
            + "\nend\nfunction __safe() local ok,value=pcall(__cases)"
            + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        (work / "late_cases.lua").write_text(
            "function __lateCases()\n" + LATE_CASES
            + "\nend\nfunction __lateSafe() local ok,value=pcall(__lateCases)"
            + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        (work / "late_conflict_cases.lua").write_text(
            "function __lateConflictCases()\n" + LATE_CONFLICT_CASES
            + "\nend\nfunction __lateConflictSafe() local ok,value=pcall(__lateConflictCases)"
            + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        (work / "adversarial_cases.lua").write_text(
            "function __adversarialCases()\n" + ADVERSARIAL_CASES
            + "\nend\nfunction __adversarialSafe() local ok,value=pcall(__adversarialCases)"
            + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        (work / "reload_before.lua").write_text(RELOAD_BEFORE,
            encoding="utf-8")
        (work / "reload_after.lua").write_text(
            "function __reloadCases()\n" + RELOAD_AFTER
            + "\nend\nfunction __reloadSafe() local ok,value=pcall(__reloadCases)"
            + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        for path in [*paths, COGNITIVE_MODELS, COGNITION]:
            (work / path.name).write_bytes(path.read_bytes())

        def run(name, current, late=False, conflict=False,
                adversarial=False, reload=False, days_behind=0):
            (work / "sao.lua").write_text(current, encoding="utf-8")
            if reload:
                scripts = [str(work / "prelude.lua"),
                    *(str(work / path.name) for path in paths),
                    str(work / "post_dispatch.lua"),
                    str(work / COGNITIVE_MODELS.name),
                    str(work / COGNITION.name), str(work / "sao.lua"),
                    str(work / "reload_before.lua"), str(work / "sao.lua"),
                    str(work / "reload_after.lua")]
                expression = "__reloadSafe()"
            elif adversarial:
                scripts = [str(work / "prelude.lua"),
                    *(str(work / path.name) for path in paths),
                    str(work / "post_dispatch.lua"),
                    str(work / COGNITIVE_MODELS.name),
                    str(work / COGNITION.name), str(work / "sao.lua"),
                    str(work / "adversarial_cases.lua")]
                expression = "__adversarialSafe()"
            elif late:
                scripts = [str(work / "prelude.lua"),
                    *(str(work / path.name) for path in paths[:-1]),
                    str(work / "sao.lua"), str(work / BANDIT_DISPATCH.name),
                    str(work / "post_dispatch.lua"),
                    str(work / ("late_conflict_cases.lua" if conflict
                        else "late_cases.lua"))]
                expression = "__lateConflictSafe()" if conflict else "__lateSafe()"
            else:
                (work / "cases.lua").write_text(
                    "function __cases()\n__testDaysBehind=" + str(days_behind) + "\n"
                    + CASES + "\nend\nfunction __safe() local ok,value=pcall(__cases)"
                    " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
                    encoding="utf-8")
                scripts = [str(work / "prelude.lua"),
                    *(str(work / path.name) for path in paths),
                    str(work / "post_dispatch.lua"),
                    str(work / COGNITIVE_MODELS.name),
                    str(work / COGNITION.name), str(work / "sao.lua"),
                    str(work / "cases.lua")]
                expression = "__safe()"
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                *scripts, "--", expression],
                cwd=work, capture_output=True, text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                "output": output[-1400:]})
            return done.returncode, output

        code, output = run("installed-program-ownership", source)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("production program adapter failed: " + output)
        code, output = run("positive-days-behind-leisure", source,
            days_behind=11)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("positive days-behind private leisure failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in source:
                raise RuntimeError("missing inverse target " + name)
            code, output = run(name, source.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " did not trip its contract: " + output)
        code, output = run("late-installed-dispatcher", source, late=True)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("late source dispatcher failed: " + output)
        code, output = run("late-preexisting-family-conflict", source,
            late=True, conflict=True)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("late dispatch conflict failed: " + output)
        late_before = 'if not (Bandit and type(Bandit.GetProgram) == "function") then'
        if late_before not in source:
            raise RuntimeError("missing late dispatcher inverse target")
        code, output = run("late-install-disabled",
            source.replace(late_before, "if true then", 1), late=True)
        if "VALUE FAIL:" not in output or "late source dispatcher did not install" not in output:
            raise RuntimeError("late source install inverse did not trip: " + output)
        code, output = run("performance-custody-controls", source,
            adversarial=True)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("performance custody controls failed: " + output)
        code, output = run("source-module-reload", source, reload=True)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("source module reload failed: " + output)
        for name, before, replacement, expected, mode in RECOVERY_CONTROLS:
            if source.count(before) != 1:
                raise RuntimeError("missing or ambiguous recovery inverse: " + name)
            code, output = run(name, source.replace(before, replacement, 1),
                adversarial=mode == "adversarial", reload=mode == "reload")
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " did not trip its contract: " + output)
        after = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (SOURCE, COGNITIVE_MODELS, COGNITION, Path(__file__))}
        if after != inputs:
            raise RuntimeError("source or focused test changed during proof")
        receipt["inputsAfter"] = after
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone-bandit-program-adapter01/receipt.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS installed Week One and Bandits source program adapters with {len(CONTROLS) + 1 + len(RECOVERY_CONTROLS)} inverses, performance custody, replay and module reload proof")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
