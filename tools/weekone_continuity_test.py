#!/usr/bin/env python3
"""Run the Week One identity and retirement contract on installed Kahlua."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneContinuity.lua"
BODY = ROOT / "mod/42.20/media/lua/client/SAO_Body.lua"
DORMANT = ROOT / "mod/42.20/media/lua/client/SAO_DormantPopulation.lua"

PRELUDE = r'''
__stores={} __records={} __source=nil __age=169 __clock=169 __tick=100 __capture=true
__countyOffset=0 __countyOverride=nil __countyThrow=false
__saveName='WeekOneTestSave' __saveMode='Sandbox' __calendar=nil
__ageAdmissions={}
__observations=0 __audibleObservations=0 __hearingDrains=0 __nativeCalls=0 __target='zombie' __hostile=false __stale=false
__threat=2 __nerve=.5 __discipline=.7
Events=setmetatable({}, {__index=function() return {Add=function() end,Remove=function() end} end})
ModData={getOrCreate=function(k) __stores[k]=__stores[k] or {} return __stores[k] end,
 get=function(k) return __stores[k] end}
BWOScheduler={WorldAge=169}
getWorld=function() return {getWorld=function() return __saveName end,
 getGameMode=function() return __saveMode end} end
getGameTime=function()
 local age=type(BWOScheduler)=='table'
  and type(BWOScheduler.WorldAge)=='number'
  and BWOScheduler.WorldAge or __clock
 local day=math.floor(age/24)
 local hour=age-day*24
 local chosen=__calendar or {}
 return {getWorldAgeHours=function() return __clock end,
  getStartTimeOfDay=function() return chosen.startHour or 0 end,
  getStartDay=function() return chosen.startDay or 0 end,
  getStartMonth=function() return chosen.startMonth or 0 end,
  getStartYear=function() return chosen.startYear or 1993 end,
  getHour=function() return chosen.hour or hour end,
  getTimeOfDay=function() return chosen.time or chosen.hour or hour end,
  getDay=function() return chosen.day or day end,
  getMonth=function() return chosen.month or 0 end,
  getYear=function() return chosen.year or 1993 end}
end
SandboxVars={SurvivorAwareness={WeekOneBodyMode=1},BanditsWeekOne={StartTime=1}}
SAO={
 Identity={get=function(id) return __records[id] end,
 ensure=function(id,first,last,x,y,z)
   local rec={id=id,forename=first,surname=last,x=x,y=y,z=z}
   __records[id]=rec return rec
  end,
  remove=function(id) __records[id]=nil return true end,
  updatePosition=function(rec,x,y,z) rec.x=x rec.y=y rec.z=z end},
 Claims={heldBy=function(rec) return rec.heldBy end,
  claim=function(rec,owner) rec.heldBy=owner return true end,
  release=function(rec) rec.heldBy=nil return true end},
 Body={hasRepresentation=function() return __represented==true end},
 History={ticks=function() return __tick end,
  countyHours=function()
   if __countyThrow then error('county clock unavailable') end
   if __countyOverride~=nil then return __countyOverride end
   return __clock+__countyOffset
  end,
  admitExternalAdult=function(rec,evidence)
   if __records[rec.id]~=rec or evidence.source~='BanditsWeekOne'
    or evidence.nativeDefaultScaleBody~=true
    or evidence.sourceKey~=tostring(rec.weekOne.brainId)..'@'..tostring(rec.weekOne.born)
    then return false,'wrong-source-evidence' end
   if __ageAdmissions[rec.id] and __ageAdmissions[rec.id]~=evidence.sourceKey
    then return false,'chronology-conflict' end
   __ageAdmissions[rec.id]=evidence.sourceKey
   return true,'admitted'
  end},
 Perception={beliefs={},observeAudible=function(id,body,tick)
  __audibleObservations=__audibleObservations+1
  __audibleActor=id __audibleBody=body __audibleTick=tick
 end,observe=function(id,body,tick)
  __observations=__observations+1
  local zombies={}
  if __target=='zombie' then zombies.a={source='observed',at=tick,track='t-1',x=82,y=80} end
  SAO.Perception.beliefs[id]={lastScanAt=__stale and tick-1 or tick,zombies=zombies,
   people={['Morgan Hill']={source='observed',at=tick,x=83,y=80}}}
 end,believedThreatCount=function() return __threat end},
 Cognition={weekOnePerformanceHearings=function(id)
  __hearingDrains=__hearingDrains+1
  __hearingActor=id
  return true
 end},
 Disposition={conflictValues=function(id) return {actorId=id,selfPreservation=.8,
  aggression=.2,nerve=__nerve,discipline=__discipline} end},
 Standing={keyForObserved=function(name) return 'known:'..name end,
  trust=function() return .6 end,isHostileTo=function(id,key)
   return __hostile and key=='known:Morgan Hill' end}}
local pollSourcePairs=pairs
local pollStreams={}
SAOJavaBridge={
 weekOnePollReset=function(self,stream)
  pollStreams[stream]=nil return true end,
 weekOnePollEntries=function(self,source,stream,limit)
  if type(source)~='table' or limit<1 or limit>128 then return nil end
  local state=pollStreams[stream]
  if not state then
   state={source=source,keys={},index=1}
   for key in pollSourcePairs(source) do
    state.keys[#state.keys+1]=key end
   pollStreams[stream]=state
  end
  local batch={}
  while #batch<limit and state.index<=#state.keys do
   local key=state.keys[state.index]
   state.index=state.index+1
   if __pollVisitHook then __pollVisitHook(state.source,stream,key) end
   batch[#batch+1]=key
  end
  if #batch==0 then pollStreams[stream]=nil end
  return batch
 end,
 perceive=function() return '' end,
 weekOneObservedTarget=function(self,body,kind,key)
  __nativeCalls=__nativeCalls+1
  if __target=='zombie' and kind=='zombie' and key=='t-1' then
   return 'TARGET\t82\t80\t0\t2' end
  if __target=='person' and kind=='person' and key=='Morgan Hill' then
   return 'TARGET\t83\t80\t0\t3' end
  return 'REFUSED\tsight'
 end,
 createReturnBody=function(self,first,last,x,y,z,female)
  local body={md={}}
  body.getModData=function(b) return b.md end
  return body
 end,
 returnBodyNeedsCleanup=function() return false end,
 captureWeekOne=function(self,source,destination,brain)
  __capturedGear=brain
  if __capture then return 'PACK:weekone' end return '' end,
 validateHibernation=function(self,value) return value=='PACK:weekone' end,
 discardReturnBody=function() return true end,
 findReturnDestination=function() return nil end}
BanditZombie={CacheLightB={},GetInstanceById=function(self,id) return __source end}
__player={getX=function() return 0 end,getY=function() return 0 end,
 CanSee=function() return __seen==true end}
getSpecificPlayer=function() return __player end
sendClientCommand=function(player,module,command,args)
 __query={player=player,module=module,command=command,args=args}
end
function __body(id)
 local b={id=id,x=80,y=80,z=0,alive=true,health=1,md={}}
 local list={present=true}
 list.contains=function(self,body) return self.present and body==b end
 local cell={getZombieList=function() return list end}
 b.currentSquare={}
 b.getPersistentOutfitID=function(self) return self.id end
 b.isAlive=function(self) return self.alive end
 b.getX=function(self) return self.x end
 b.getY=function(self) return self.y end
 b.getZ=function(self) return self.z end
 b.getHealth=function(self) return self.health end
 b.getVehicle=function() return nil end
 b.getModData=function(self) return self.md end
 b.getCell=function() return cell end
 b.getCurrentSquare=function(self) return self.currentSquare end
 b.getSquare=function() return {isCanSee=function() return __squareSeen==true end} end
 b.removeFromSquare=function(self) self.currentSquare=nil end
 b.removeFromWorld=function(self) list.present=false self.removed=true end
 return b
end
function __removeWithProof(W,ticket,brain,body)
 local args={id=ticket.id or ticket.brainId,born=ticket.born,
  token=ticket.token,personId=ticket.personId}
 W.onServerCommand('SAOWeekOne','Prepared',args)
 local decision,reason=W.confirmPreparedRetire(args,brain,body,__player)
 assert(decision=='remove',
  'exact loaded body did not receive native removal decision: '..tostring(reason))
 body:removeFromSquare() body:removeFromWorld()
 assert(W.recordPhysicalRemoval(args,brain,body,__player)==true,
  'successful native removal did not establish exact local proof')
end
function __brain(id,origin)
 return {id=id,born=12.5,saoWeekOneOrigin=origin,fullname='Alex Harper',female=false,
  health=1,program={name='Survivor'},inventory={},loot={},weapons={melee='Base.BareHands',
   primary={bulletsLeft=0,magCount=0},secondary={bulletsLeft=0,magCount=0}}}
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local foreign=__brain(9,'Bandits2') local body=__body(9)
__step='foreign-call'
local foreignId=W.observeBrain(foreign,body)
__step='foreign-check'
local count=0 for _ in pairs(__records) do count=count+1 end
assert(foreignId==nil and count==0,'foreign actor admitted')
local brain=__brain(7,'BanditsWeekOne') body=__body(7) __source=body
brain.saoWeekOneReinforcement={source='VBandit.schedule/SpawnGroup',
 eventRef='00000000000000000000000000000007',age=87,minute=33,variantId=2,count=5,
 brainId=7,born=12.5}
__step='observe'
local id=W.observeBrain(brain,body)
assert(id and __records[id].heldBy=='BanditsWeekOne','source person not held')
assert(__ageAdmissions[id]=='7@12.5',
 'source person missed exact durable adult chronology admission')
assert(__records[id].weekOne.sourceEvent
 and __records[id].weekOne.sourceEvent.eventRef=='00000000000000000000000000000007'
 and __records[id].weekOne.sourceEvent.kind=='reinforcement',
 'source reinforcement event was not retained as SAO person provenance')
local scenarioBrain=__brain(8,'BanditsWeekOne')
local scenarioBody=__body(8)
scenarioBrain.saoWeekOneScenarioBirth={source='VBandit.setup/SpawnGroupArea',
 eventRef='00000000000000000000000000000008',variant='Bandits',
 variantId=2,ordinal=3,count=24,brainId=8,born=12.5}
local scenarioId=W.observeBrain(scenarioBrain,scenarioBody)
assert(scenarioId and __records[scenarioId].weekOne.sourceEvent
 and __records[scenarioId].weekOne.sourceEvent.eventRef
  =='00000000000000000000000000000008'
 and __records[scenarioId].weekOne.sourceEvent.kind=='scenario-arrival',
 'selected scenario actor lost public arrival provenance')
SAO.Standing.playerAccountKey=function() return 'account:417' end
SAO.Standing.playerKey=function() return 'character:417' end
__player.isDead=function() return false end
__player.getDescriptor=function() return {getID=function() return 417 end,
 getForename=function() return 'Riley' end,getSurname=function() return 'Stone' end} end
__player.getModData=function() return {SAOCreationReceipt={
 schema='sao-created-player/1',newWorld=true,weekOneStartBabe=true,
 playerKey='character:417'}} end
getWorld=function() return {getWorld=function() return 'Rosewood' end,
 getGameMode=function() return 'Sandbox' end} end
local startBrain=__brain(13,'BanditsWeekOne')
local startBody=__body(13)
startBrain.program={name='Walker'}
startBrain.saoWeekOneStartEntry={source='BWOEvents.Start/StartBabe',
 eventRef='0000000000000000000000000000000d',selected=true,
 sourceProgram='Babe',program='Walker',brainId=13,born=12.5}
local startId=W.observeBrain(startBrain,startBody)
assert(startId and not __records[startId].weekOne.sourceSpawn
 and __query and __query.command=='QueryOwnerReceipt'
 and __query.args.brainId==13,
 'start actor acquired a player origin without the private owner receipt')
local owner={source='BWOEvents.Start/StartBabe',
 eventRef='0000000000000000000000000000000d',brainId=13,born=12.5,
 accountKey='account:417',playerKey='account:417',nativeDescriptorId=417,
 forename='Riley',surname='Stone',world='Rosewood',gameMode='Sandbox'}
local wrong={} for key,value in pairs(owner) do wrong[key]=value end
wrong.accountKey='other-account'
W.onServerCommand('SAOWeekOne','OwnerReceipt',wrong)
W.observeBrain(startBrain,startBody)
assert(not __records[startId].weekOne.sourceSpawn,
 'foreign owner receipt admitted a selected start')
W.onServerCommand('SAOWeekOne','OwnerReceipt',owner)
W.observeBrain(startBrain,startBody)
assert(__records[startId].weekOne.sourceSpawn
 and __records[startId].weekOne.sourceSpawn.eventRef==owner.eventRef
 and __records[startId].weekOne.sourceSpawn.playerKey==nil
 and __records[startId].weekOne.sourceSpawn.accountKey==nil
 and W.selectedStartProvenance(startId).playerKey=='character:417',
 'private owner receipt did not bind the selected start to this character')
assert(__records[id].weekOne.bodyMode=='native'
 and W.nativeBodyPreferred(brain,body)==true,
 'new person did not prefer SAO native body')
__records[id].weekOne.bodyMode='legacy-source'
assert(W.nativeBodyPreferred(brain,body)==false,
 'saved legacy source timing was changed')
SandboxVars.SurvivorAwareness.WeekOneBodyMode=2
local cheapBrain=__brain(12,'BanditsWeekOne') local cheapBody=__body(12)
local cheapId=W.observeBrain(cheapBrain,cheapBody)
assert(cheapId and __records[cheapId].weekOne.bodyMode=='lightweight'
 and W.nativeBodyPreferred(cheapBrain,cheapBody)==false,
 'explicit lightweight source proxy became native default')
SandboxVars.SurvivorAwareness.WeekOneBodyMode=1
__step='chronology-refusal'
local savedAdmission=SAO.History.admitExternalAdult
SAO.History.admitExternalAdult=function() return false,'chronology-conflict' end
local refusedBody=__body(11)
local refused,refusal=W.observeBrain(__brain(11,'BanditsWeekOne'),refusedBody)
local refusedRow=__stores.SurvivorAwareness_WeekOneContinuity.byBrain['11']
assert(refused==nil and refusal=='chronology-conflict'
 and refusedBody.md.SAOWeekOnePersonId==nil
 and refusedRow and __records[refusedRow.personId]==nil,
 'chronology refusal still marked a source person for transfer')
SAO.History.admitExternalAdult=savedAdmission
__step='appraisal'
assert(body.md.SAOWeekOnePersonId==id and body.md.SAOWeekOneOrigin=='BanditsWeekOne',
 'exact body was not marked for human perception')
local appraisal=W.assessForBandit(brain,body)
assert(appraisal and appraisal.actorId==id and appraisal.observedThreats==2
 and appraisal.trustedSeen==1 and appraisal.preference=='caution'
 and __observations==1 and __hearingDrains==1 and __hearingActor==id
 and __records[id].weekOne.appraisal==appraisal,
 'private Week One cognition was not retained')
assert(W.assessForBandit(brain,body)==appraisal and __observations==1,
 'repeated same-tick program callback rescanned the cell')
for i=1,100 do assert(W.assessForBandit(brain,body)==appraisal) end
assert(__observations==1 and W.costMetrics().throttled>=100,
 'same-tick callback load exceeded the private scanner cadence')
local firstPlan=W.planForBandit(brain,body)
assert(firstPlan and firstPlan.kind=='move' and firstPlan.targetKind=='zombie'
 and firstPlan.source=='sao-observed' and firstPlan.x==82
 and __observations==1 and __nativeCalls==1,
 'private observed zombie did not yield one native-verified SAO task')
__tick=110
local cachedPlan=W.planForBandit(brain,body)
assert(cachedPlan and cachedPlan.kind=='move' and cachedPlan.atTick==110
 and cachedPlan.observedAtTick==100 and __observations==1 and __nativeCalls==2,
 'bounded cached sight lost SAO authority or skipped current native sight')
assert(__audibleObservations==1 and __audibleActor==id
 and __audibleBody==body and __audibleTick==110,
 'cached source callback missed sound-only acquisition')
W.assessForBandit(brain,body)
assert(__audibleObservations==1 and __observations==1,
 'same-tick source callback repeated native sound or full sight scan')
__tick=111
body.md.SAOWeekOnePersonId=nil
body.md.SAOWeekOneOrigin=nil
body.md.SAOWeekOneBrainId=nil
body.md.SAOWeekOneBorn=nil
assert(W.assessForBandit(brain,body)==appraisal
 and body.md.SAOWeekOnePersonId==id and __audibleObservations==2
 and __audibleActor==id and __audibleBody==body and __audibleTick==111
 and __observations==1,
 'saved source rebind skipped sound acquisition on the second throttle')
W.assessForBandit(brain,body)
assert(__audibleObservations==2 and __observations==1,
 'rebound same-tick callback duplicated native sound or full sight scan')
__records[id].weekOne.appraisal.atTick=80
SAO.Perception.beliefs[id].lastScanAt=80
SAO.Perception.beliefs[id].zombies.a.at=80
assert(W.planForBandit(brain,body)==nil,
 'aged private observation yielded an action plan')
__records[id].weekOne.appraisal.atTick=100
SAO.Perception.beliefs[id].lastScanAt=100
SAO.Perception.beliefs[id].zombies.a.at=100
__tick=90
assert(W.planForBandit(brain,body)==nil and __observations==1,
 'clock rollback accepted private observation')
local rollbackBrain=__brain(10,'BanditsWeekOne')
assert(W.assessForBandit(rollbackBrain,__body(10))==nil,
 'global scan budget admitted a new person during clock rollback')
__target='none' __threat=0 __tick=125
local fallback=W.planForBandit(brain,body)
assert(fallback and fallback.kind=='fallback' and __nativeCalls==2
 and fallback.source=='sao-person-appraisal' and fallback.anim=='ShiftWeight'
 and fallback.duration==170 and __records[id].weekOne.decision.anim=='ShiftWeight',
 'no private enemy did not choose BWO fallback under SAO authority')
__target='person' __threat=2 __hostile=true __tick=150
local hostilePlan=W.planForBandit(brain,body)
assert(hostilePlan and hostilePlan.kind=='move' and hostilePlan.targetKind=='person',
 'Standing-hostile observed person did not yield native-verified SAO task')
__hostile=false __tick=175
local neutralPlan=W.planForBandit(brain,body)
assert(neutralPlan and neutralPlan.kind=='fallback' and neutralPlan.anim=='WipeBrow',
 'unknown living person became an enemy without Standing')
__stale=true __tick=200
assert(W.planForBandit(brain,body)==nil,
 'stale private sight yielded an action plan')
__stale=false __target='none' __tick=225
assert(W.observeBrain(brain,body)==id,'same brain created another person')
__nerve=.2 __discipline=.3 __threat=0 __tick=246
local wary=W.planForBandit(brain,body)
assert(wary and wary.kind=='fallback' and wary.anim=='ChewNails'
 and wary.duration==200 and __records[id].weekOne.decision.duration==200,
 'person appraisal did not select the deterministic anxious Time task')
local wrong=__body(8)
assert(W.observeBrain(brain,wrong)==nil,'mismatched body admitted')
assert(W.planForBandit(brain,wrong)==nil,'mismatched body yielded action plan')
__seen=true
assert(W.prepareRetire(brain,body,__player)==false,'visible body retired')
__seen=false __squareSeen=false
body.health=0.6
brain.weapons.melee='Base.Hammer'
brain.weapons.primary={name='Base.Pistol',type='mag',bulletsLeft=7,
 magCount=2,magSize=15,magName='Base.9mmClip',clipIn=true,racked=false}
brain.keys={hospital=612}
brain.permaInv={{fullType='Base.WaterBottle'}}
brain.bag={name='Base.Bag_BigHikingBag'}
brain.inventory[1]='Base.Unknown'
assert(W.prepareRetire(brain,body,__player)==false,
 'unresolved virtual inventory transferred')
brain.inventory={}
brain.infection=4
assert(W.prepareRetire(brain,body,__player)==false,
 'unrepresented BWO infection transferred')
brain.infection=0
__capture=false
__step='capture-refusal'
assert(W.prepareRetire(brain,body,__player)==false and not __records[id].weekOne.pending,
 'failed native capture retired actor')
__capture=true
__step='prepare'
local accepted,transfer=W.prepareRetire(brain,body,__player)
assert(accepted and type(transfer)=='table' and transfer.personId==id
 and __records[id].heldBy=='BanditsWeekOne' and __capturedGear==brain,
 'injured live source failed detached capture')
assert(W.retirementPending(brain,body)==true
 and W.retirementPending(brain,__body(99))==false,
 'exact pending source body did not reserve its despawn quota')
assert(W.planForBandit(brain,body)==nil,'pending retirement yielded action plan')
__query=nil W.poll(true)
assert(__query and __query.command=='PrepareRetire'
 and __query.args.personId==id and __query.args.token==transfer.token,
 'initial server preparation was not recoverable')
local prepared={id=7,born=12.5,token=transfer.token,personId=id}
W.onServerCommand('SAOWeekOne','Prepared',
 {id=7,born=12.5,token=transfer.token,personId='wrong-person'})
assert(__records[id].weekOne.pending.serverPrepared~=true,
 'foreign person acknowledged source removal')
W.onServerCommand('SAOWeekOne','Prepared',prepared)
assert(__records[id].weekOne.pending.serverPrepared==true,
 'exact server preparation was not recorded')
__source=nil
assert(W.confirmPreparedRetire(prepared,brain,nil,__player)==nil,
 'source absence without local removal intent was treated as safe')
__source=body
__seen=true
assert(W.confirmPreparedRetire(prepared,brain,body,__player)==nil
 and __records[id].weekOne.pending.localRemovalIntent~=true,
 'visible source body was removed after preparation')
__seen=false
body.health=0.5
assert(W.confirmPreparedRetire(prepared,brain,body,__player)=='remove'
 and __records[id].weekOne.pending.localRemovalIntent==true
 and __records[id].weekOne.pending.packed=='PACK:weekone',
 'server-prepared source did not refresh its final physical snapshot')
__source=nil
assert(W.confirmPreparedRetire(prepared,brain,nil,__player)==nil,
 'saved removal intent authorized an unloaded-body resend')
__source=body
W.onServerCommand('SAOWeekOne','Retired',{id=7,born=12.5,token='spoof',personId=id})
assert(__records[id].weekOne.pending.serverRemoved==false,'spoofed receipt accepted')
W.onServerCommand('SAOWeekOne','Retired',{id=7,born=13.5,token=transfer.token,personId=id})
assert(__records[id].weekOne.pending.serverRemoved==false,'wrong birth accepted')
W.onServerCommand('SAOWeekOne','Retired',
 {id=7,born=12.5,token=transfer.token,personId='foreign-person'})
assert(__records[id].weekOne.pending
 and __records[id].weekOne.pending.serverRemoved==false
 and __records[id].heldBy=='BanditsWeekOne',
 'foreign person retirement ACK settled pending source custody')
W.onServerCommand('SAOWeekOne','Retired',
 {id=7,born=12.5,token=transfer.token,personId=id})
__step='ack'
assert(__records[id].weekOne.pending and __records[id].heldBy=='BanditsWeekOne',
 'body still present but second controller admitted')
local sourceLookup=BanditZombie.GetInstanceById
BanditZombie.GetInstanceById=nil W.poll()
assert(__records[id].weekOne.pending and __records[id].heldBy=='BanditsWeekOne',
 'unavailable source lookup released the source claim')
BanditZombie.GetInstanceById=function() error(nil) end W.poll()
assert(__records[id].weekOne.pending and __records[id].heldBy=='BanditsWeekOne',
 'failed source lookup released the source claim')
BanditZombie.GetInstanceById=sourceLookup
body:removeFromSquare()
assert(W.recordPhysicalRemoval(prepared,brain,body,__player)==false,
 'half-removed body gained physical removal proof')
body:removeFromWorld()
assert(W.recordPhysicalRemoval({id=7,born=12.5,token='foreign-token',
 personId=id},brain,body,__player)==false,
 'foreign token gained physical removal proof')
assert(W.recordPhysicalRemoval(prepared,brain,body,__player)==true,
 'native postcondition did not establish exact local proof')
__source=nil
assert(W.confirmPreparedRetire(prepared,brain,nil,__player)=='resend',
 'same-session physical proof did not recover lost removal command')
W.poll()
__step='retired'
assert(__records[id].weekOne.status=='dormant' and __records[id].hibernation=='PACK:weekone'
 and __records[id].heldBy=='BanditsWeekOne','server receipt did not preserve dormant source')
local premature=__brain(7,'BanditsWeekOne') premature.born=13.5
assert(W.observeBrain(premature,__body(7))==nil
 and __stores.SurvivorAwareness_WeekOneContinuity.byBrain['7'].personId==id,
 'new source birth displaced dormant person before week boundary')
BWOScheduler.WorldAge=170 W.poll()
__step='boundary'
assert(__records[id].weekOne.status=='transferred' and __records[id].heldBy==nil,
 'week boundary did not release exact held person')
assert(__stores.SurvivorAwareness_WeekOneContinuity.byBrain['7']==nil
 and __stores.SurvivorAwareness_WeekOneContinuity.retiredBySource['7@12.5'].personId==id,
 'settled crosswalk was not pruned into a durable source tombstone')
__source=body
assert(W.observeBrain(brain,body)==nil,'returned source body claimed twice')
local reused=__brain(7,'BanditsWeekOne') reused.born=13.5
local reusedId=W.observeBrain(reused,__body(7))
assert(reusedId and reusedId~=id and __records[reusedId].heldBy=='BanditsWeekOne',
 'reused source ID with a new birth could not admit a distinct person')
local newBrain=__brain(8,'BanditsWeekOne') local newBody=__body(8)
__source=newBody
local newId=W.observeBrain(newBrain,newBody)
assert(newId~=id and __records[newId].heldBy=='BanditsWeekOne','second person identity collision')
assert(__records[newId].weekOne.bodyMode=='native'
 and W.nativeBodyPreferred(newBrain,newBody)==true,
 'new native default lost saved representation choice')
local ok,info=W.prepareRetire(newBrain,newBody,__player)
assert(ok and info.token,'second source did not capture')
__source=nil BWOScheduler.WorldAge=170 W.poll()
assert(__records[newId].weekOne.pending and __records[newId].heldBy=='BanditsWeekOne',
 'missing server receipt treated as removal')
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
__query=nil W.poll(true)
assert(__query and __query.command=='PrepareRetire'
 and __query.args.token==info.token and __records[newId].heldBy=='BanditsWeekOne',
 'reload did not renew the exact server preparation')
W.onServerCommand('SAOWeekOne','Prepared',
 {id=8,born=12.5,token=info.token,personId=newId})
__query=nil W.poll(true)
assert(__query and __query.command=='QueryRetired'
 and __query.args.token==info.token,
 'prepared retirement did not query its exact pending ticket')
__source=newBody
__removeWithProof(W,{id=8,born=12.5,token=info.token,personId=newId},
 newBrain,newBody)
__source=nil
W.onServerCommand('SAOWeekOne','Retired',
 {id=8,born=12.5,token=info.token,personId=newId})
W.poll()
assert(__records[newId].weekOne.status=='transferred'
 and __records[newId].heldBy==nil
 and __records[newId].hibernation=='PACK:weekone',
 'native default did not release exact captured person after receipt')
BWOScheduler.WorldAge=170 W.poll()
assert(__records[newId].weekOne.status=='transferred' and __records[newId].heldBy==nil,
 'native transfer changed at the later Week One boundary')
BWOScheduler.WorldAge=169 __target='none' __tick=250
local crowd={} local bodies={}
for i=100,124 do
 crowd[i]={id=i,brain=__brain(i,'BanditsWeekOne')}
 bodies[i]=__body(i)
end
BanditZombie.CacheLightB=crowd
BanditZombie.GetInstanceById=function(id) return bodies[id] end
local priorScans=W.costMetrics().scans
W.poll()
local firstScans=W.costMetrics().scans-priorScans
assert(firstScans==4 and W.costMetrics().budgetDeferred>=8
 and W.costMetrics().scanQueuePeak==8,
 'crowd scan exceeded the shared per-tick budget')
local crosswalk=__stores.SurvivorAwareness_WeekOneContinuity.byBrain
local queuedRow=crosswalk['104']
assert(queuedRow and __records[queuedRow.personId].weekOne.scanRequestedAtTick==250
 and W.assessForBandit(crowd[104].brain,bodies[104])==nil,
 'direct callback bypassed a queued person')
__tick=251 W.onBudgetTick()
assert(W.costMetrics().scans-priorScans==8
 and __records[queuedRow.personId].weekOne.scanGrantedAtTick==251,
 'first queued people did not receive FIFO private scans')
__tick=252 W.onBudgetTick()
assert(W.costMetrics().scans-priorScans==12,
 'queued poll cohort was not drained within the bounded tick budget')
__tick=275 W.poll()
__tick=276 W.onBudgetTick()
__tick=277 W.onBudgetTick()
__tick=300 W.poll()
__tick=301 W.onBudgetTick()
__tick=302 W.onBudgetTick()
assert(W.costMetrics().scans-priorScans>=25
 and W.costMetrics().scans-priorScans<=36,
 'round-robin scanner starved people or exceeded its tick budget')
for i=100,124 do
 local row=crosswalk[tostring(i)]
 assert(row and __records[row.personId].weekOne.appraisal,
  'round-robin budget starved stamped Week One people')
end
local staleId=crosswalk['100'].personId
BanditZombie.CacheLightB={}
BanditZombie.GetInstanceById=function(id) return nil end
__clock=171 __tick=325
local archived=false
for minute=1,8 do
 W.poll()
 if crosswalk['100']==nil then archived=true break end
 __tick=__tick+1
end
assert(archived and __records[staleId]
 and __stores.SurvivorAwareness_WeekOneContinuity.inactiveBySource['100@12.5'].personId==staleId,
 'inactive crosswalk was not eventually pruned without deleting the durable person')
assert(W.observeBrain(crowd[100].brain,bodies[100])==staleId,
 'returning Week One source lost its durable person identity')
return 'PASS'
'''

AGE_CASES = r'''
local W=SAO.WeekOneContinuity
local function world(name, option, calendar)
 __stores={} __records={} __ageAdmissions={} __source=nil
 __query=nil
 __saveName=name __saveMode='Sandbox' __calendar=calendar __clock=169
 __countyOffset=0 __countyOverride=nil __countyThrow=false
 BWOScheduler={WorldAge=169}
 BanditZombie={CacheLightB={},GetInstanceById=function(self,id) return __source end}
 SandboxVars.BanditsWeekOne={StartTime=option}
 W.rebindWorld()
end
local function retire(id, mode)
 local brain,body=__brain(id,'BanditsWeekOne'),__body(id)
 __source=body
 local personId=W.observeBrain(brain,body)
 assert(personId and __records[personId].heldBy=='BanditsWeekOne',
  'source person was not admitted')
 local rec=__records[personId]
 rec.weekOne.bodyMode=mode
 local accepted,ticket=W.prepareRetire(brain,body,__player)
 assert(accepted and ticket and ticket.personId==personId,
  'exact source retirement was not prepared')
 __removeWithProof(W,ticket,brain,body)
 __source=nil
 W.onServerCommand('SAOWeekOne','Retired',
  {id=id,born=brain.born,token=ticket.token,personId=personId})
 W.poll()
 return rec,body
end
local function dueWithoutScheduler()
 BWOScheduler=nil __calendar.hour=__calendar.hour+1 __clock=__clock+1
 W.poll()
end
local function held(rec, message)
 assert(rec.weekOne.status=='dormant' and rec.heldBy=='BanditsWeekOne'
  and rec.weekOne.handoffAge==nil,message)
end
__step='source-present-equivalence'
world('source-present',1,{day=7,hour=1,month=0,year=1993})
local rec=retire(1001,'legacy-source')
held(rec,'source-present person left before the boundary')
local clock=__stores.SurvivorAwareness_WeekOneContinuity.weekOneTransitionClock
assert(clock and clock.ageHours==169 and clock.shiftHours==0
 and clock.sourceCompared==true and clock.world=='source-present'
 and rec.weekOne.retirementReceipt
 and rec.weekOne.retirementReceipt.personId==rec.id
 and rec.weekOne.retiredAtHours==169
 and rec.weekOne.sourceRemovedAtWorldHours==169
 and rec.weekOne.sourceRemovedAtCountyHours==169
 and rec.weekOne.retirementReceipt.removedAtCountyHours==169
 and rec.releasedAtHours==169,
 'source-present world age or exact retirement receipt was not saved')
BWOScheduler.WorldAge=170 __calendar.hour=2 __clock=170 W.poll()
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil
 and rec.weekOne.handoffAge.ageHours==170
 and rec.weekOne.handoffAge.retirementBasis=='current-session-native-removal',
 'source-present due handoff was not equivalent')

__step='source-absent-due'
world('source-absent',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1002,'legacy-source')
held(rec,'saved source proxy left before the boundary')
BWOScheduler=nil W.poll()
held(rec,'missing scheduler invented a premature handoff')
__calendar.hour=2 __clock=170 W.poll()
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil
 and rec.weekOne.handoffAge.ageHours==170
 and rec.weekOne.handoffAge.sourceCompared==false,
 'missing scheduler held a due saved source proxy')

__step='county-offset-physical-removal'
world('county-offset',1,{day=7,hour=1,month=0,year=1993})
__countyOffset=72
local offsetBrain,offsetBody=__brain(1230,'BanditsWeekOne'),__body(1230)
__source=offsetBody
local offsetId=W.observeBrain(offsetBrain,offsetBody)
local offsetRec=__records[offsetId]
offsetRec.weekOne.bodyMode='legacy-source'
local accepted,offsetTicket=W.prepareRetire(offsetBrain,offsetBody,__player)
assert(accepted and offsetTicket,'offset source did not prepare retirement')
__removeWithProof(W,offsetTicket,offsetBrain,offsetBody)
assert(offsetRec.weekOne.pending.removedAtWorldHours==169
 and offsetRec.weekOne.pending.removedAtCountyHours==241
 and offsetRec.weekOne.pending.removalCountyClockSource
  =='SAO.History.countyHours',
 'native removal did not save its paired county checkpoint')
__source=nil BWOScheduler=nil __calendar.hour=3 __clock=171
W.onServerCommand('SAOWeekOne','Retired',
 {id=1230,born=offsetBrain.born,token=offsetTicket.token,personId=offsetId})
assert(offsetRec.weekOne.status=='dormant'
 and offsetRec.releasedAtHours==241
 and offsetRec.weekOne.retiredAtHours==169
 and offsetRec.weekOne.retirementReceipt.atWorldHours==169
 and offsetRec.weekOne.retirementReceipt.removedAtWorldHours==169
 and offsetRec.weekOne.retirementReceipt.removedAtCountyHours==241
 and offsetRec.weekOne.retirementReceipt.countyClockSource
  =='SAO.History.countyHours',
 'delayed server reply moved the physical county checkpoint')
local wakeElapsed=math.max(0,SAO.History.countyHours()-offsetRec.releasedAtHours)
local oldWalkAt=offsetRec.releasedAtHours-2
local walkAt=math.max(oldWalkAt,offsetRec.releasedAtHours)
local dormantElapsed=math.max(0,SAO.History.countyHours()-walkAt)
assert(wakeElapsed==2 and dormantElapsed==2,
 'Body wake or Dormant walk read a native release hour as county time')
__countyOverride=0/0 W.poll()
held(offsetRec,'invalid county clock released the source claim')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-county-clock-unavailable',
 'invalid due county clock was not named')
__countyOverride=240 W.poll()
held(offsetRec,'regressed county clock released the source claim')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-county-clock-regression',
 'regressed due county clock was not named')
__countyOverride=nil
W.poll()
assert(offsetRec.weekOne.status=='transferred' and offsetRec.heldBy==nil,
 'paired offset clock blocked a due physical handoff')

__step='county-offset-save-rebind'
world('county-rebind',1,{day=7,hour=1,month=0,year=1993})
__countyOffset=48
rec=retire(1231,'legacy-source')
assert(rec.releasedAtHours==217
 and rec.weekOne.sourceRemovedAtCountyHours==217,
 'saved county offset was not attached to exact retirement')
W.rebindWorld()
BWOScheduler=nil __calendar.hour=2 __clock=170 W.poll()
held(rec,'rebind substituted the saved clock for lost physical proof')
assert(rec.releasedAtHours==217
 and rec.weekOne.retirementReceipt.removedAtCountyHours==217
 and __stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
  =='physical-removal-proof-unavailable',
 'rebind damaged paired county provenance or claim custody')

__step='county-clock-unavailable'
world('county-invalid',1,{day=7,hour=1,month=0,year=1993})
local invalidBrain,invalidBody=__brain(1232,'BanditsWeekOne'),__body(1232)
__source=invalidBody
local invalidId=W.observeBrain(invalidBrain,invalidBody)
local invalidRec=__records[invalidId]
invalidRec.weekOne.bodyMode='legacy-source'
local prepared,invalidTicket=W.prepareRetire(invalidBrain,invalidBody,__player)
assert(prepared and invalidTicket,'invalid-clock source did not prepare')
local invalidArgs={id=1232,born=invalidBrain.born,
 token=invalidTicket.token,personId=invalidId}
__countyOverride=0/0
local decision,reason=W.confirmPreparedRetire(invalidArgs,invalidBrain,
 invalidBody,__player)
assert(decision==nil and reason=='clock-unavailable'
 and invalidBody:getCurrentSquare()~=nil,
 'invalid county clock removed a live source body')
__countyOverride=nil
__removeWithProof(W,invalidTicket,invalidBrain,invalidBody)
__source=nil __countyThrow=true
W.onServerCommand('SAOWeekOne','Retired',invalidArgs)
assert(invalidRec.weekOne.pending and invalidRec.heldBy=='BanditsWeekOne'
 and invalidRec.releasedAtHours==nil,
 'unavailable county clock completed a pending retirement')
__countyThrow=false W.poll()
assert(invalidRec.weekOne.status=='dormant'
 and invalidRec.releasedAtHours==169,
 'valid restored county clock did not complete saved physical proof')

__step='legacy-ticket-without-county'
world('legacy-ticket-county',1,{day=7,hour=1,month=0,year=1993})
__countyOffset=72
rec=retire(1233,'legacy-source')
rec.releasedAtHours=rec.weekOne.retiredAtHours
rec.weekOne.sourceRemovedAtWorldHours=nil
rec.weekOne.sourceRemovedAtCountyHours=nil
rec.weekOne.retirementReceipt.removedAtWorldHours=nil
rec.weekOne.retirementReceipt.removedAtCountyHours=nil
rec.weekOne.retirementReceipt.countyClockSource=nil
dueWithoutScheduler()
held(rec,'unpaired ticketed retirement crossed native/county clock boundary')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-county-clock-unproven',
 'legacy ticket acquired an invented county checkpoint')

__step='start-time-shifts'
local shifted={
 {day=7,hour=1,month=0,year=1993},
 {day=14,hour=1,month=0,year=1993},
 {day=28,hour=1,month=0,year=1993},
 {day=25,hour=1,month=3,year=1993},
 {day=7,hour=1,month=0,year=1994},
 {day=0,hour=1,month=0,year=2003}}
local shifts={0,168,504,1848,8760,87432}
for option=1,6 do
 world('shift-'..option,option,shifted[option])
 rec=retire(1100+option,'legacy-source')
 held(rec,'shifted source proxy left before the boundary')
 local saved=__stores.SurvivorAwareness_WeekOneContinuity.weekOneTransitionClock
 assert(saved and saved.legacyAgeHours==169
  and saved.shiftHours==shifts[option]
  and saved.startTimeOption==option,
  'selected StartTime shift was not represented by owned clock')
 dueWithoutScheduler()
 assert(rec.weekOne.status=='transferred' and rec.heldBy==nil
  and rec.weekOne.handoffAge.shiftHours==shifts[option],
  'selected StartTime shift did not transfer after source disappearance')
end

__step='native-calendar-leap'
world('leap-year',1,{startYear=1992,startMonth=1,startDay=28,
 startHour=0,year=1992,month=2,day=0,hour=1})
BWOScheduler.WorldAge=73
local leapAge=W.weekOneTransitionAge()
local leapFact=__stores.SurvivorAwareness_WeekOneContinuity.weekOneTransitionClock
assert(leapAge==25 and leapFact.legacyAgeHours==73,
 'native year age inherited the source fixed-calendar drift')

__step='native-clock-fraction'
world('fractional-hour',1,{startYear=1993,startMonth=0,startDay=0,
 startHour=9.5,year=1993,month=0,day=0,hour=10,time=10.25})
BWOScheduler.WorldAge=.5
local fractional=W.weekOneTransitionAge()
assert(fractional==.75
 and __stores.SurvivorAwareness_WeekOneContinuity.weekOneTransitionClock
 .legacyAgeHours==.5,
 'native age dropped elapsed minutes into the source hour truncation')

__step='legacy-month-backstep'
world('month-crossing',1,{day=30,hour=23,month=0,year=1993})
BWOScheduler.WorldAge=743 __clock=743
assert(W.weekOneTransitionAge()==743,
 'native clock did not admit the source month-end sample')
__calendar.month=1 __calendar.day=0 __calendar.hour=0
BWOScheduler.WorldAge=0 __clock=744
assert(W.weekOneTransitionAge()==744,
 'native elapsed age inherited the source month-index backstep')

__step='native-before-boundary'
world('native-before-boundary',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1201,'native')
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil
 and rec.weekOne.handoffAge.ageHours==169,
 'native preferred body waited for the old source boundary')

__step='reload-absent-source'
world('reload-absent-source',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1202,'legacy-source')
held(rec,'reload candidate left before source boundary')
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
dueWithoutScheduler()
held(rec,'reload without native physical witness released source claim')
assert(__stores.SurvivorAwareness_WeekOneContinuity.weekOneTransitionClock
 .ageHours==170
 and __stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
  =='physical-removal-proof-unavailable',
 'saved world clock or physical removal boundary was lost on Lua reload')

__step='foreign-save-identity'
world('save-original',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1203,'legacy-source')
__saveName='different-save'
dueWithoutScheduler()
held(rec,'foreign save used another save transition clock')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastTransitionClockRefusal
 =='save-identity-mismatch','foreign save did not refuse its clock')

__step='clock-regression'
world('clock-regression',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1204,'legacy-source')
BWOScheduler=nil __calendar.hour=2 __clock=168 W.poll()
held(rec,'backward native clock released a saved source proxy')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastTransitionClockRefusal
 =='transition-clock-regression','backward native clock was not named')

__step='source-age-mismatch'
world('source-mismatch',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1205,'legacy-source')
__calendar.hour=2 __clock=170 W.poll()
held(rec,'stale scheduler overrode the native transition clock')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastTransitionClockRefusal
 =='source-age-mismatch','active source disagreement was not named')

__step='source-age-failure'
world('source-failure',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1206,'legacy-source')
BWOScheduler.WorldAge='bad' __calendar.hour=2 __clock=170 W.poll()
held(rec,'invalid scheduler age released a saved source proxy')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastTransitionClockRefusal
 =='source-age-mismatch','invalid scheduler age was not named')
BWOScheduler=true W.poll()
held(rec,'invalid scheduler global released a saved source proxy')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastTransitionClockRefusal
 =='source-age-mismatch','invalid scheduler global was not named')

__step='saved-choice-without-source-options'
world('removed-source-options',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1213,'legacy-source')
BWOScheduler=nil SandboxVars.BanditsWeekOne=nil
__calendar.hour=2 __clock=170 W.poll()
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil,
 'saved StartTime choice was lost when the external options disappeared')

__step='changed-start-choice'
world('start-choice',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1207,'legacy-source')
BWOScheduler=nil SandboxVars.BanditsWeekOne.StartTime=2
__calendar.hour=2 __clock=170 W.poll()
held(rec,'changed start choice rewrote the saved timing')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastTransitionClockRefusal
 =='start-time-choice-changed','changed start choice was not named')

__step='native-clock-failure'
world('native-failure',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1208,'legacy-source')
local realGameTime=getGameTime
BWOScheduler=nil getGameTime=function() return {getWorldAgeHours=function()
 return 170 end} end
W.poll()
held(rec,'missing native calendar released a saved source proxy')
getGameTime=realGameTime

__step='retirement-evidence'
world('retirement-evidence',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1209,'legacy-source')
rec.releasedAtHours=rec.releasedAtHours-1
dueWithoutScheduler()
held(rec,'dormant status without exact retirement completion took ownership')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-county-clock-mismatch',
 'mismatched county checkpoint was not named')

__step='retirement-receipt-identity'
world('receipt-identity',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1210,'legacy-source')
rec.weekOne.retirementReceipt.personId='foreign-person'
dueWithoutScheduler()
held(rec,'foreign source retirement receipt took ownership')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-receipt-mismatch','foreign retirement receipt was not named')

__step='new-completion-receipt-removed'
world('new-receipt-removed',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1211,'legacy-source')
assert(rec.weekOne.retirementProtocol=='server-ticket-v1',
 'new completion omitted its protocol discriminator')
assert(ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
 .byBrain['1211'].retirementProtocolEra=='ticketed-v1',
 'new completion omitted its independent persisted row era')
rec.weekOne.retirementReceipt=nil
dueWithoutScheduler()
held(rec,'newly completed source lost its receipt but took ownership')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-receipt-mismatch',
 'missing new receipt was mislabeled as pre-token provenance')

__step='new-completion-both-phase-fields-removed'
world('new-both-removed',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1220,'legacy-source')
rec.weekOne.retirementReceipt=nil rec.weekOne.retirementProtocol=nil
dueWithoutScheduler()
held(rec,'new completed row with lost phase fields became historical')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='retirement-provenance-mismatch',
 'independent row era failed to discriminate new completion')

__step='historical-saved-completion'
world('saved-completion',1,{day=7,hour=1,month=0,year=1993})
W.poll()
local old=SAO.Identity.ensure('bwo-historical','Older','Survivor',80,80,0)
old.weekOne={source='BanditsWeekOne',brainId=1214,born=12.5,
 status='dormant',bodyMode='legacy-source',retirementOffCamera=true,
 retiredAtHours=169}
old.releasedAtHours=169 old.hibernation='PACK:weekone'
SAO.Claims.claim(old,'BanditsWeekOne')
local oldStore=ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
oldStore.byBrain['1214']={personId=old.id,brainId=1214,born='12.5',
 source='BanditsWeekOne',status='external'}
W.poll()
held(old,'pre-token saved person left before boundary')
assert(old.weekOne.preTokenCompletion
 and old.weekOne.preTokenCompletion.schema
  =='sao-week-one-pre-token-completion/1'
 and oldStore.byBrain['1214'].retirementProtocolEra=='pre-token-v0'
 and old.weekOne.retirementProtocol==nil,
 'historical saved completion did not gain bounded migration provenance')
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
dueWithoutScheduler()
held(old,'historical tokenless row used cache nil as physical proof')
assert(oldStore.lastHandoffRefusal=='historical-physical-absence-unproven',
 'older completed dormant save hid its unresolved physical custody')

__step='source-body-still-present'
world('source-returned',1,{day=7,hour=1,month=0,year=1993})
local body; rec,body=retire(1212,'legacy-source')
__source=__body(1212) BWOScheduler=nil __calendar.hour=2 __clock=170 W.poll()
held(rec,'returned source body was taken over')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='source-body-still-present','returned source body was not named')
__source=nil W.poll()
held(rec,'cache miss cleared an observed returned physical body')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='source-body-return-unresolved',
 'returned physical body was forgotten after cache miss')

__step='stale-cache-exact-removed-body'
world('stale-removed-cache',1,{day=7,hour=1,month=0,year=1993})
rec,body=retire(1224,'legacy-source')
__source=body BWOScheduler.WorldAge=170 __calendar.hour=2 __clock=170
W.poll()
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil,
 'stale cache reference to exact removed body blocked native proof')

__step='saved-due-after-source-month-backstep'
world('due-before-month',1,{day=7,hour=1,month=0,year=1993})
rec,body=retire(1215,'legacy-source')
rec.weekOne.retirementReceipt.personId='held-for-due-observation'
BWOScheduler.WorldAge=170
__calendar.hour=2 __clock=170 W.poll()
held(rec,'unmatched receipt released source ownership at due boundary')
local dueStore=ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
assert(dueStore.weekOneTransitionClock.legacyDueObservedAtWorldHours==170,
 'verified source boundary did not persist its due observation')
rec.weekOne.retirementReceipt.personId=rec.id
BWOScheduler=nil __calendar.month=1
__calendar.day=0 __calendar.hour=0 __clock=744
W.poll()
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil
 and rec.weekOne.handoffAge.legacyAgeHours==0
 and rec.weekOne.handoffAge.legacyDueObservedAtWorldHours==170,
 'source month backstep erased a previously observed due handoff')

__step='pre-due-month-backstep'
world('not-due-before-month',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1216,'legacy-source')
BWOScheduler=nil __calendar.month=1 __calendar.day=0
__calendar.hour=0 __clock=744 W.poll()
held(rec,'source month backstep fabricated a boundary never observed')
assert(ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
 .weekOneTransitionClock.legacyDueObservedAtWorldHours==nil,
 'pre-due source proxy gained a false due observation')

__step='completed-server-proof-without-source-runtime'
world('completed-proof',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1217,'legacy-source')
local ticket=rec.weekOne.retirementReceipt
BanditZombie=nil BWOScheduler=nil __calendar.hour=2 __clock=170
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
__query=nil W.poll(true)
held(rec,'reloaded completed ticket substituted for lost physical proof')
assert(__query==nil and __stores.SurvivorAwareness_WeekOneContinuity
 .lastHandoffRefusal=='physical-removal-proof-unavailable',
 'reloaded dormant ticket was treated as a native absence query')
W.onServerCommand('SAOWeekOne','Retired',{id=ticket.brainId,
 born=ticket.born,token='foreign-token',personId=rec.id})
W.poll()
held(rec,'foreign completed ticket released the source claim')
W.onServerCommand('SAOWeekOne','Retired',{id=ticket.brainId,
 born=ticket.born,token=ticket.token,personId='foreign-person'})
W.poll()
held(rec,'foreign person completed ticket released the source claim')
W.onServerCommand('SAOWeekOne','Retired',{id=ticket.brainId,
 born=ticket.born,token=ticket.token,personId=rec.id})
W.poll()
held(rec,'exact server ticket replaced lost local physical witness')

__step='same-session-proof-without-source-runtime'
world('same-session-proof',1,{day=7,hour=1,month=0,year=1993})
rec=retire(1222,'legacy-source')
BanditZombie=nil BWOScheduler=nil __calendar.hour=2 __clock=170 W.poll()
assert(rec.weekOne.status=='transferred' and rec.heldBy==nil
 and rec.weekOne.handoffAge.retirementBasis=='current-session-native-removal',
 'same-session native removal proof did not survive source runtime loss')

__step='completed-proof-returned-body-then-runtime-absent'
world('returned-then-runtime-absent',1,{day=7,hour=1,month=0,year=1993})
local returnedBody; rec,returnedBody=retire(1221,'legacy-source')
local returnedTicket=rec.weekOne.retirementReceipt
__source=__body(1221) W.poll()
assert(rec.weekOne.sourceBodyReturnObserved==true,
 'returned completed source body was not remembered')
BanditZombie=nil BWOScheduler=nil __calendar.hour=2 __clock=170
W.onServerCommand('SAOWeekOne','Retired',{id=returnedTicket.brainId,
 born=returnedTicket.born,token=returnedTicket.token,personId=rec.id})
W.poll()
held(rec,'returned body was forgotten when its lookup disappeared')
assert(__stores.SurvivorAwareness_WeekOneContinuity.lastHandoffRefusal
 =='source-body-return-unresolved',
 'unresolved physical source return did not state its boundary')
__source=nil
BanditZombie={CacheLightB={},GetInstanceById=function(self,id) return __source end}
W.poll()
held(rec,'cache nil cleared an observed returned body after runtime return')

__step='pending-server-proof-without-source-runtime'
world('pending-proof',1,{day=7,hour=1,month=0,year=1993})
local brain,pendingBody=__brain(1218,'BanditsWeekOne'),__body(1218)
__source=pendingBody
local pendingId=W.observeBrain(brain,pendingBody)
local accepted,pendingTicket=W.prepareRetire(brain,pendingBody,__player)
assert(accepted and pendingTicket.personId==pendingId,
 'pending source retirement was not prepared')
local pendingRec=__records[pendingId]
__source=nil BanditZombie=nil BWOScheduler=nil
__calendar.hour=2 __clock=170 __query=nil W.poll(true)
assert(pendingRec.weekOne.pending and pendingRec.heldBy=='BanditsWeekOne'
 and not pendingRec.weekOne.retirementReceipt,
 'unconfirmed pending retirement took source ownership')
pendingRec.weekOne.pending.serverRemoved=true
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
__query=nil W.poll(true)
assert(pendingRec.weekOne.pending and __query
 and __query.command=='QueryRetired'
 and __query.args.token==pendingTicket.token,
 'saved serverRemoved flag completed without fresh server proof')
pendingRec.weekOne.pending.serverRemoved=false
W.onServerCommand('SAOWeekOne','Retired',{id=1218,born=brain.born,
 token=pendingTicket.token,personId='foreign-person'})
assert(pendingRec.weekOne.pending
 and pendingRec.weekOne.pending.serverRemoved~=true
 and pendingRec.heldBy=='BanditsWeekOne',
 'foreign pending reply completed a missing source body')
W.onServerCommand('SAOWeekOne','Retired',{id=1218,born=brain.born,
 token=pendingTicket.token,personId=pendingId})
W.poll()
assert(pendingRec.weekOne.pending and pendingRec.heldBy=='BanditsWeekOne',
 'confirmed pending ticket bypassed physical source absence')
BanditZombie={CacheLightB={},GetInstanceById=function(self,id) return __source end}
W.poll()
assert(pendingRec.weekOne.pending and pendingRec.heldBy=='BanditsWeekOne'
 and not pendingRec.weekOne.retirementReceipt,
 'restored cache miss completed pending retirement without native proof')

__step='pending-removed-crash-before-server-command'
world('pending-crash',1,{day=7,hour=1,month=0,year=1993})
brain,pendingBody=__brain(1223,'BanditsWeekOne'),__body(1223)
__source=pendingBody
pendingId=W.observeBrain(brain,pendingBody)
accepted,pendingTicket=W.prepareRetire(brain,pendingBody,__player)
assert(accepted and pendingTicket.personId==pendingId,
 'crash candidate did not prepare exact source retirement')
__removeWithProof(W,pendingTicket,brain,pendingBody)
__source=nil
assert(W.physicalRemovalProofCount()==1,
 'pending retry lost its exact same-session native body witness')
local crashArgs={id=1223,born=brain.born,token=pendingTicket.token,
 personId=pendingId}
assert(W.confirmPreparedRetire(crashArgs,brain,nil,__player)=='resend',
 'same-session native proof could not replay lost command')
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
assert(W.confirmPreparedRetire(crashArgs,brain,nil,__player)==nil,
 'reload treated saved intent as a surviving physical witness')
assert(W.physicalRemovalProofCount()==0,
 'rebind carried a stale native body witness into a new session')
W.onServerCommand('SAOWeekOne','Retired',crashArgs)
BanditZombie=nil BWOScheduler=nil __calendar.hour=2 __clock=170 W.poll()
assert(__records[pendingId].weekOne.pending
 and __records[pendingId].heldBy=='BanditsWeekOne'
 and not __records[pendingId].weekOne.retirementReceipt,
 'server ticket completed after volatile physical proof was lost')

__step='historical-no-token-source-runtime-absent'
world('historical-no-runtime',1,{day=7,hour=1,month=0,year=1993})
W.poll()
old=SAO.Identity.ensure('bwo-old-unresolved','Older','Survivor',80,80,0)
old.weekOne={source='BanditsWeekOne',brainId=1219,born=12.5,
 status='dormant',bodyMode='legacy-source',retirementOffCamera=true,
 retiredAtHours=169}
old.releasedAtHours=169 old.hibernation='PACK:weekone'
SAO.Claims.claim(old,'BanditsWeekOne')
local unresolved=ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
unresolved.byBrain['1219']={personId=old.id,brainId=1219,born='12.5',
 source='BanditsWeekOne',status='external'}
BanditZombie=nil BWOScheduler=nil __calendar.hour=2 __clock=170
__query=nil W.poll(true)
held(old,'historical tokenless save inferred source absence')
assert(__query==nil and unresolved.lastHandoffRefusal
 =='historical-physical-absence-unproven',
 'historical tokenless save made up a query or completion')

__step='bounded-retirement-proof-lifetime'
world('proof-lifetime',1,{day=7,hour=1,month=0,year=1993})
for n=1,48 do
 local person=retire(1300+n,'legacy-source')
 assert(person.weekOne.status=='dormant'
  and person.heldBy=='BanditsWeekOne',
  'pre-due proof inventory released a source claim')
end
assert(W.physicalRemovalProofCount()==48,
 'pending source proof inventory lost an exact native body')
BWOScheduler.WorldAge=170 __calendar.hour=2 __clock=170 W.poll()
local proofStore=ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
assert(proofStore.metrics.rowsPruned==48,
 'bounded due handoff did not archive each exact source row')
assert(W.physicalRemovalProofCount()==0,
 'settled source archive retained a removed native body')
W.poll()
assert(proofStore.metrics.rowsPruned==48
 and W.physicalRemovalProofCount()==0,
 'duplicate poll repeated settled source archival')
return 'PASS'
'''

CONTROLS = [
    ("reinforcement-provenance", 'and reinforcement.brainId == brain.id',
     'and false', 'source reinforcement event was not retained as SAO person provenance'),
    ("scenario-provenance", 'and scenario.brainId == brain.id',
     'and false', 'selected scenario actor lost public arrival provenance'),
    ("start-private-receipt", 'or owner.eventRef ~= spawn.eventRef',
     'or true', 'private owner receipt did not bind the selected start to this character'),
    ("native-default", 'return selected == 2 and "lightweight" or "native"',
     'return "lightweight"', 'new person did not prefer SAO native body'),
    ("prepare-reload", 'or "PrepareRetire"',
     'or "QueryRetired"', 'initial server preparation was not recoverable'),
    ("removal-intent", 'if exactPhysicalRemovalProof(rec, p.token, p.brainId, p.born) then',
     'if p.localRemovalIntent == true then',
     'saved removal intent authorized an unloaded-body resend'),
    ("pending-physical-proof", 'if not exactPhysicalRemovalProof(rec, p.token, p.brainId, p.born) then',
     'if false then',
     'server receipt did not preserve dormant source'),
    ("native-cell-postcondition", 'return ok and current == nil and inCell == false',
     'return ok and current == nil',
     'half-removed body gained physical removal proof'),
    ("pending-quota-crosswalk", 'local p = phase and phase.pending',
     'local p = nil',
     'exact pending source body did not reserve its despawn quota'),
    ("foreign-admission", 'brain.saoWeekOneOrigin ~= OWNER', 'false', 'foreign actor admitted'),
    ("chronology-refusal", 'if not okAge or admitted ~= true then',
     'if false then', 'chronology refusal still marked a source person for transfer'),
    ("ack-token", 'p.token ~= args.token', 'false', 'spoofed receipt accepted'),
    ("week-boundary", 'transitionFact.legacyAgeHours >= 170',
     'transitionFact.legacyAgeHours >= 169',
     'server receipt did not preserve dormant source'),
    ("private-cognition", 'if not okObserve then', 'if okObserve then',
     'private Week One cognition was not retained'),
    ("private-hearing-drain", 'pcall(SAO.Cognition.weekOnePerformanceHearings, personId)',
     'pcall(function() return true end)',
     'private Week One cognition was not retained'),
    ("cached-source-sound", 'and SAO.Perception and SAO.Perception.observeAudible then',
     'and false then', 'cached source callback missed sound-only acquisition'),
    ("rebound-source-sound", 'sampleSourceAudible(personId, brain, body, tick)\n        return rec.weekOne.appraisal',
     'return rec.weekOne.appraisal', 'saved source rebind skipped sound acquisition on the second throttle'),
    ("private-sight", 'beliefs.lastScanAt ~= observedTick', 'false',
     'stale private sight yielded an action plan'),
    ("cached-plan-current-sight", 'seen.at == observedTick', 'seen.at == tick',
     'bounded cached sight lost SAO authority or skipped current native sight'),
    ("cached-plan-age", 'tick - frame.atTick >= 20', 'tick - frame.atTick >= 200',
     'aged private observation yielded an action plan'),
    ("scan-clock-rollback", 'if budgetTick and tick < budgetTick then return false, "scan-clock-rollback" end',
     'if false then return false, "scan-clock-rollback" end',
     'global scan budget admitted a new person during clock rollback'),
    ("injured-body", 'or bodyHealth <= 0',
     'or bodyHealth <= 0 or math.abs(bodyHealth - brain.health) > 0.02',
     'injured live source failed detached capture'),
    ("virtual-gear-admission", 'SAOJavaBridge:captureWeekOne(body, stage, brain)',
     'SAOJavaBridge:captureWeekOne(body, stage)',
     'injured live source failed detached capture'),
    ("shared-scan-budget", 'local SCANS_PER_TICK = 4',
     'local SCANS_PER_TICK = 12',
     'crowd scan exceeded the shared per-tick budget'),
    ("queued-exact-body", 'body == request.body and currentBody(request.brain, body)',
     'body ~= request.body and currentBody(request.brain, body)',
     'first queued people did not receive FIFO private scans'),
    ("fifo-head", 'local request = scanQueue[scanHead]',
     'local request = scanQueue[scanTail]',
     'first queued people did not receive FIFO private scans'),
    ("settled-crosswalk-prune", 'archiveRow(s, entry.id, entry.row, entry.settled)',
     'do end', 'settled crosswalk was not pruned into a durable source tombstone'),
    ("dormant-id-reuse", 'or old.weekOne.status == "dormant"',
     'or false', 'new source birth displaced dormant person before week boundary'),
    ("appraisal-fallback", 'if frame.observedThreats > 0 then anim = "WipeBrow"',
     'if frame.observedThreats > 0 then anim = "ShiftWeight"',
     'unknown living person became an enemy without Standing'),
    ("fallback-source", 'source = "sao-person-appraisal", anim = anim',
     'source = "sao-observed", anim = anim',
     'no private enemy did not choose BWO fallback under SAO authority'),
]

AGE_CONTROLS = [
    ("native-leap", "return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)",
     "return false", "native year age inherited the source fixed-calendar drift"),
    ("native-minute", "+ currentTime - startHour - shift",
     "+ hour - startHour - shift",
     "native age dropped elapsed minutes into the source hour truncation"),
    ("selected-shift", "local WEEK_ONE_START_SHIFTS = { 0, 168, 504, 1848, 8760, 87432 }",
     "local WEEK_ONE_START_SHIFTS = { 0, 167, 504, 1848, 8760, 87432 }",
     "selected StartTime shift was not represented by owned clock"),
    ("missing-scheduler", 'if transitionFact and (rec.weekOne.bodyMode == "native"',
     'if transitionFact and BWOScheduler and (rec.weekOne.bodyMode == "native"',
     "missing scheduler held a due saved source proxy"),
    ("foreign-save", "or prior.world ~= world or prior.mode ~= mode",
     "or false or prior.mode ~= mode",
     "foreign save used another save transition clock"),
    ("native-clock-regression", "worldHours + 0.000001 < prior.atWorldHours",
     "false", "backward native clock was not named"),
    ("active-source-comparison", "math.abs(sourceAge - legacyAge) > 0.000001",
     "false", "stale scheduler overrode the native transition clock"),
    ("native-body-choice", 'rec.weekOne.bodyMode == "native"',
     'false', "native preferred body waited for the old source boundary"),
    ("legacy-source-timing", "transitionFact.legacyAgeHours >= 170",
     "transitionFact.ageHours >= 170",
     "shifted source proxy left before the boundary"),
    ("retirement-completion", "or rec.releasedAtHours ~= receipt.removedAtCountyHours",
     "or false", "dormant status without exact retirement completion took ownership"),
    ("county-release-domain", "rec.hibernation, rec.releasedAtHours = p.packed, p.removedAtCountyHours",
     "rec.hibernation, rec.releasedAtHours = p.packed, p.hours",
     "delayed server reply moved the physical county checkpoint"),
    ("county-removal-pair", "p.removedAtCountyHours = removedAtCountyHours",
     "p.removedAtCountyHours = removedAtWorldHours",
     "native removal did not save its paired county checkpoint"),
    ("county-ack-delay", "rec.hibernation, rec.releasedAtHours = p.packed, p.removedAtCountyHours",
     "rec.hibernation, rec.releasedAtHours = p.packed, currentCountyHours",
     "delayed server reply moved the physical county checkpoint"),
    ("legacy-ticket-county", 'return false, "retirement-county-clock-unproven" end',
     'return true, "retirement-county-clock-unproven" end',
     "unpaired ticketed retirement crossed native/county clock boundary"),
    ("county-due-availability", 'local currentCountyHours = countyHours()\n    if not currentCountyHours then\n        return false, "retirement-county-clock-unavailable" end\n    if currentCountyHours + 0.000001 < receipt.removedAtCountyHours then\n        return false, "retirement-county-clock-regression" end',
     'local currentCountyHours = countyHours()',
     "invalid county clock released the source claim"),
    ("county-due-regression", 'if currentCountyHours + 0.000001 < receipt.removedAtCountyHours then',
     'if false then',
     "regressed county clock released the source claim"),
    ("proof-release-cleanup", "physicalRemovalProofs[rec.id] = nil\n        end\n    end\nend\n\nlocal function rowFor",
     "-- missing cleanup\n        end\n    end\nend\n\nlocal function rowFor",
     "settled source archive retained a removed native body"),
    ("retirement-receipt-identity", "and receipt.personId == rec.id and receipt.brainId == phase.brainId",
     "and true and receipt.brainId == phase.brainId",
     "foreign source retirement receipt took ownership"),
    ("new-completion-protocol", "or phase.retirementProtocol ~= nil then",
     "or false then", "missing new receipt was mislabeled as pre-token provenance"),
    ("new-completion-row-era", "and row.retirementProtocolEra ~= \"pre-token-v0\" then",
     "and false then", "independent row era failed to discriminate new completion"),
    ("saved-legacy-due-latch", "or finite(transitionFact.legacyDueObservedAtWorldHours)",
     "or false and finite(transitionFact.legacyDueObservedAtWorldHours)",
     "source month backstep erased a previously observed due handoff"),
    ("dormant-physical-proof", "if not exactPhysicalRemovalProof(rec, receipt.token,\n        receipt.brainId, receipt.born) then",
     "if false then", "rebind substituted the saved clock for lost physical proof"),
    ("pending-person-ack", "if args.personId ~= rec.id then return end",
     "if false then return end", "foreign pending reply completed a missing source body"),
    ("source-body-absence", "if sourceBody ~= nil\n        and sourceBody ~= physicalRemovalProofs[rec.id].body then",
     "if false then", "returned source body was taken over"),
    ("remembered-source-return", 'if phase.sourceBodyReturnObserved == true then\n        return false, "source-body-return-unresolved" end',
     'if false then\n        return false, "source-body-return-unresolved" end',
     'cache miss cleared an observed returned physical body'),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path,
        default=ROOT / "_scratch/d2-leisure-01/weekone21/continuity-kahlua28.json")
    out = parser.parse_args().out.resolve()
    if not SOURCE.is_file():
        raise SystemExit("missing Week One production source")
    if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
        print("SKIPPED installed engine/JDK unavailable")
        return 0
    original = SOURCE.read_text(encoding="utf-8")
    body_source = BODY.read_text(encoding="utf-8")
    dormant_source = DORMANT.read_text(encoding="utf-8")
    if ("elapsed = math.max(0, now - (rec.releasedAtHours or now))"
            not in body_source
            or "local okTime, now = pcall(SAO.History.countyHours)"
            not in body_source
            or "walkAt = math.max(walkAt or rec.releasedAtHours, rec.releasedAtHours)"
            not in dormant_source
            or "sinceH = math.max(0, nowH - walkAt)"
            not in dormant_source
            or "return SAO.History.countyHours()" not in dormant_source):
        raise RuntimeError("Body/Dormant county checkpoint consumer contract changed")
    receipt = {"sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "testSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "bodyConsumerSha256": hashlib.sha256(BODY.read_bytes()).hexdigest(),
               "dormantConsumerSha256": hashlib.sha256(DORMANT.read_bytes()).hexdigest(),
               "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"),
            "-d", str(work), str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError(built.stderr)
        (work / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (work / "cases.lua").write_text("function __cases()\n" + CASES
            + "\nend\nfunction __safe() local ok,value=pcall(__cases) if ok then return value end"
            + " return 'FAIL:'..tostring(__step)..':'..tostring(value) end", encoding="utf-8")

        def run(name, source, cases=CASES):
            code = work / "SAO_WeekOneContinuity.lua"
            code.write_text(source, encoding="utf-8")
            (work / "reload.lua").write_text("function __reloadWeekOne()\n" + source
                + "\nend\n", encoding="utf-8")
            (work / "cases.lua").write_text("function __cases()\n" + cases
                + "\nend\nfunction __safe() local ok,value=pcall(__cases) if ok then return value end"
                + " return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
                encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun", str(work / "prelude.lua"),
                str(code), str(work / "reload.lua"), str(work / "cases.lua"), "--", "__safe()"], cwd=work,
                capture_output=True, text=True, timeout=60)
            result = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode, "output": result[-1600:]})
            return done.returncode, result

        exitcode, output = run("production", original)
        if exitcode or "VALUE PASS" not in output:
            raise RuntimeError("production failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in original:
                raise RuntimeError(f"missing control target {name}")
            exitcode, output = run(name, original.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"control {name} failed incorrectly: {output}")
        exitcode, output = run("age-handoff", original, AGE_CASES)
        if exitcode or "VALUE PASS" not in output:
            raise RuntimeError("age handoff failed: " + output)
        for name, before, after, expected in AGE_CONTROLS:
            if before not in original:
                raise RuntimeError(f"missing age inverse target {name}")
            exitcode, output = run(name, original.replace(before, after, 1), AGE_CASES)
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"age control {name} failed incorrectly: {output}")
        receipt["status"] = "PASS"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One Kahlua source, age handoff and {len(CONTROLS) + len(AGE_CONTROLS)} defect inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
