#!/usr/bin/env python3
"""Border 162: execute the shipped person handoff and its callers in Kahlua.

Engine bodies/bridge are fault-injection doubles. Lua ownership, caller flow,
and staging are production code. Native snapshot fidelity has a separate JVM
probe. Controls mutate shipped functions and must fail on their named defect.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from lua_read import function_body

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
LUA = ROOT / 'mod/42.20/media/lua/client'
GAME = Path(r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid')
JDK = Path(r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin')
SHARED_FILES = {'SAO_Identity.lua', 'SAO_BodySnapshot.lua', 'SAO_PhysicalFacts.lua'}


def source_path(name):
    return LUA.parent / ('shared' if name in SHARED_FILES else 'client') / name


FILES = ['SAO_PhysicalFacts.lua', 'SAO_BodySnapshot.lua', 'SAO_Body.lua',
         'SAO_SourceUse.lua', 'SAO_Controller.lua',
         'SAO_PopulationAdmissions.lua', 'SAO_PopulationRepresentation.lua', 'SAO_DormantPopulation.lua',
         'SAO_Population.lua', 'SAO_Harness.lua',
         'SAO_Age.lua', 'SAO_Drugs.lua', 'SAO_AfflictedReturn.lua',
         'SAO_CrossedTransfer.lua', 'SAO_Nuke.lua', 'SAO_Identity.lua']

PRELUDE = r'''
Events=setmetatable({}, {__index=function() return {Add=function() end,Remove=function() end} end})
getSpecificPlayer=function() return nil end
getGameTime=function() return {getMinutesStamp=function() return __minute or 0 end} end
SandboxVars={ZombieLore={Mortality=5}}
ISTimedActionQueue={queues={},clear=function() table.insert(__sourceEvents,'queue-clear') end}
__records={} __logs={} __mode='ok' __remove='ok' __restore='ok' __now=42
 __captures=0 __removed=0 __restored=0 __spawned=0 __forgot=0 __events=0 __accounted=0
 __sourceReservation=nil __sourceEvents={} __allowObserve=false __nearestObserved=nil
__zombieThreat=nil __formedThreat=nil __hostileKey=nil __sourceBusy=false
__locomotionStatus='moving' __locomotionTicks=0
SAO={
 Log={line=function(tag,msg) table.insert(__logs,msg) end},
 Identity={all=function() return __records end,
   get=function(id) return __records[id] end,
   remove=function(id) __records[id]=nil __forgot=__forgot+1 end,
   femaleOf=function() return false end, knownName=function() return nil end,
   beliefKey=function(rec) return rec and rec.id or nil end,
   updatePosition=function(rec,x,y,z) rec.x=x rec.y=y rec.z=z end},
 History={countyHours=function() return __now end,
   countyTimeOfDay=function() return 12 end},
  Standing={groupOf=function() return nil end,allGroupClaims=function() return {} end,
    ownsRadio=function() return __radio==true end,
    mayEnterBelieved=function() return true end,
    mayAttemptBelieved=function() return true end,
   keyForObserved=function(name) return tostring(name) end,
   isHostileTo=function(id,key) return tostring(key)==tostring(__hostileKey) end},
 Disposition={describe=function() return 'test' end,
   fleeDistance=function() return 4 end},
  Claims={isHeld=function() return false end},
  Lessons={desperationBump=function() return 0 end},
  Places={comfortHorizon=function() return 300 end,
    commitHorizon=function() return 900 end},
 Census={rowOf=function() return {engineKey='test'} end},
 Locomotion={jobs={},cancel=function(id)
   if __cancelThrow then error('cancel unavailable') end
   table.insert(__sourceEvents,'cancel') SAO.Locomotion.jobs[tostring(id)]=nil
 end,order=function(id,body,x,y,z)
   table.insert(__sourceEvents,'order')
   SAO.Locomotion.jobs[tostring(id)]={done=false}
   return true
 end,tick=function() __locomotionTicks=__locomotionTicks+1 end,
 status=function() return __locomotionStatus end},
 Perception={beliefs={},forget=function() end,
   observe=function()
     if not __allowObserve then error('pending body advanced') end
     table.insert(__sourceEvents,'observe')
   end,
   nearestBelievedZombie=function() return __zombieThreat end,
   believedThreatCount=function() return __zombieThreat and 1 or 0 end,
   nearestFormedPerson=function() return __formedThreat end},
 Needs={busy=function() return __sourceBusy end},
 Voice={forget=function() end},
 Rand={int=function() return 0 end},
 PathogenEvents={emit=function() __events=__events+1 end},
  WorldSources={
   reconcileReservations=function() return 0 end,
   nearestObserved=function() return __nearestObserved end,
   actionOptions=function(place,category,id,body,quantity,admission)
     if not __nearestObserved then return nil,'none-observed' end
     return {options={{id='handoff-fixture-source',owner='SAO.SourceUse',
       parameters={actorId=tostring(id),category=category}}}}
   end,
   beginAction=function(place,category,id,body,quantity,admission,selected)
     if not __nearestObserved then return nil,'none-observed' end
     assert(selected and selected.id=='handoff-fixture-source'
       and selected.parameters.actorId==tostring(id),
       'source choice did not reach reservation owner')
     __sourceReservation={id='controller-source-begin',actorId=tostring(id),
       status='reserved',phase='approaching-place',category=category,
       placeId=place.id,placeX=place.cx,placeY=place.cy,placeZ=0}
     __records[tostring(id)].worldSourceReservation=__sourceReservation.id
     return __sourceReservation
   end,
   pendingActionFor=function(id)
     if __sourceReservation
       and __sourceReservation.actorId==tostring(id)
       and (__sourceReservation.status=='reserved'
         or __sourceReservation.unavailable) then
       return __sourceReservation
     end
   end,
   release=function(reservationId,reason)
     if not __sourceReservation
       or __sourceReservation.id~=reservationId
       or __sourceReservation.unavailable then return false end
     __sourceReservation.status='released'
     __sourceReservation.detail=reason
     local rec=__records[__sourceReservation.actorId]
     if rec and rec.worldSourceReservation==reservationId then
       rec.worldSourceReservation=nil
     end
     table.insert(__sourceEvents,'release')
     __sourceReservation=nil
     return true
   end,
 }
}
function __body()
 local b={md={},inventory={},payload='carried',visual='current-look',x=200,y=210,z=0}
 function b:getX() return self.x end
 function b:getY() return self.y end
 function b:getZ() return self.z end
 function b:getModData() return self.md end
 function b:getInventory() return self.inventory end
 function b:setNpc() end
 function b:isNpc() return true end
 function b:resetModelNextFrame() end
 function b:dressInRandomOutfit() self.randomDress=true end
 function b:getHealth() return 1 end
 function b:setHealth() __mutations=__mutations+1 end
 function b:SetOnFire() __mutations=__mutations+1 end
 function b:isDead() error('pending body advanced') end
 return b
end
SAOJavaBridge={
 canReleaseShell=function() return __mode~='busy' end,
 isShell=function() return true end,
 isInventoryOf=function(self,b,reference)
   return type(reference)=='table' and reference.outer==b.inventory
 end,
 beginCombatNearest=function()
   table.insert(__sourceEvents,'combat') return 'COMBAT_STARTED'
 end,
 hibernate=function(self,b)
   __captures=__captures+1
   if __mode=='throw' then error('capture unavailable') end
   if __mode=='empty' then return '' end
   if __mode=='malformed' then return 'broken' end
   return 'SNAP:'..b.payload
 end,
 captureReturnLiving=function(self,b) return SAOJavaBridge:hibernate(b) end,
 validateHibernation=function(self,p) return type(p)=='string' and p:sub(1,5)=='SNAP:' end,
 validateReturnVisual=function(self,p) return type(p)=='string' and p:sub(1,4)=='VIS:' end,
 captureReturnVisual=function(self,b)
   if __mode=='visual-throw' then error('visual capture unavailable') end
   if __mode=='visual-empty' then return '' end
   return 'VIS:'..b.visual
 end,
 restoreReturnVisual=function(self,b,visual)
   __visualRestored=__visualRestored+1
   if __visualRestore=='throw' then error('visual restore unavailable') end
   if __visualRestore=='false' then b.visual='partial' return false end
   if type(visual)~='string' or visual:sub(1,4)~='VIS:' then return false end
   b.visual=visual:sub(5) b.visualRestoredAfter=b.payload return true
 end,
 removeShell=function(self,b)
   __removed=__removed+1
   if __remove=='throw' then error('remove unavailable') end
   if __remove=='false' then b.partial=true return false end
   b.removed=true return true
 end,
 woundInfection=function() if __mode=='facts-throw' then error('facts unavailable') end return 0.5 end,
 biteHoursLeft=function() return '8' end,
 spawnShellNamed=function(self,fn,sn,x,y,z,sex,accountNow)
   assert(accountNow==false,'spawn accounted before restore')
   __spawned=__spawned+1 return __body()
 end,
 accountShell=function(self,b)
   if __expectRestoredVisual then
     assert(b.visual==__expectRestoredVisual,'accounted before visual restore')
   end
   __accounted=__accounted+1
 end,
 setProfession=function(self,b,key) b.perk=(b.perk or 0)+2 end,
 awaken=function(self,b,packed,elapsed)
   __restored=__restored+1
   if __restore=='throw' then error('restore unavailable') end
   if __restore=='false' then return 'AWAKEN_FAILED partial' end
   b.payload=packed:sub(6) b.perk=7 b.elapsed=elapsed return 'AWAKENED items=1'
 end
}
function __setup()
 __mode='ok' __remove='ok' __restore='ok' __now=42 __cancelThrow=false
 __captures=0 __removed=0 __restored=0 __spawned=0 __forgot=0 __events=0 __logs={}
 __accounted=0 __radio=true
 __sourceReservation=nil __sourceEvents={} SAO.Locomotion.jobs={}
 __allowObserve=false __nearestObserved=nil
 __zombieThreat=nil __formedThreat=nil __hostileKey=nil
 __sourceBusy=false __locomotionStatus='moving' __locomotionTicks=0
 SAO.Perception.beliefs={}
 __visualRestore='ok' __visualRestored=0 __expectRestoredVisual=nil
 SAO.Body.active={} SAO.Body.foreign={} SAO.Body.failedRestore={} SAO.Body.discarding={}
 SAO.Controller.agents={} ISTimedActionQueue.queues={}
 local r={id='p1',forename='Test',surname='Person',occupation='test',x=190,y=195,z=0,
   hibernation='SNAP:previous',releasedAtHours=5,kitGranted=true,epistemicMonths=1}
 __records={p1=r} local b=__body() SAO.Body.active[r.id]=b
 SAO.Controller.adopt(r) SAO.Harness.activeId=r.id
 return r,b,SAO.Controller.agents[r.id]
end
'''

CASES = r'''
for _,mode in ipairs({'empty','throw','malformed','facts-throw','busy','visual-throw','visual-empty'}) do
 local r,b,a=__setup() __mode=mode
 local ok=SAO.Body.release(r)
 assert(not ok, 'capture failure reported success: '..mode)
 assert(__removed==0 and SAO.Body.active.p1==b and SAO.Controller.agents.p1==a,
   'capture failure relinquished ownership: '..mode)
 assert(r.hibernation=='SNAP:previous' and r.releasedAtHours==5 and r.x==190
   and r.bodyRelease==nil and r.knoxInfected==nil, 'capture failure mutated record')
end
do
 local r,b,a=__setup() __now=0/0
 assert(not SAO.Body.release(r) and __removed==0 and r.bodyRelease==nil,'invalid clock accepted')
end
for _,mode in ipairs({'false','throw'}) do
 local r,b,a=__setup() __remove=mode
 local ok,why=SAO.Body.release(r)
 assert(not ok and why=='teardown-failed','teardown failure reported success')
 assert(SAO.Body.active.p1==b and SAO.Controller.agents.p1==a,'teardown lost ownership')
 assert(SAO.Body.get('p1')==nil and SAO.Body.hasRepresentation('p1'),
   'pending body remained available or became dormant')
 assert(r.bodyRelease and r.hibernation=='SNAP:previous','pending capture not separate')
 local get=SAO.Body.get
 SAO.Body.get=function() error('pending body advanced') end
 __update('p1',a)
 SAO.Body.get=get
 b.payload='partial' __remove='ok' __cancelThrow=true
 assert(SAO.Body.release(r),'retry failed')
 assert(__captures==1 and r.hibernation=='SNAP:carried','retry recaptured partial body')
 assert(r.bodyVisual=='VIS:current-look','release lost captured appearance')
 assert(r.x==200 and r.y==210 and r.releasedAtHours==42 and r.biteDeathAtHours==50,
   'release facts did not commit together')
 assert(r.infectionStartedAtHours==42 and r.infectionSpanHours==8,
   'release lost the observed infection interval')
 assert(SAO.Body.active.p1==nil and SAO.Controller.agents.p1==nil and r.bodyRelease==nil,
   'successful release kept ownership')
 assert(__events==1,'infection event missing or duplicated')
 assert(r.hasRadio==true,'current radio possession lost')
 assert(not SAO.Body.release(r) and __captures==1,'second release repeated capture')
end
do
 local r,b=__setup() __remove='false' SAO.Body.release(r)
 SAO.Body.active={} SAO.Controller.agents={} __remove='ok'
 assert(SAO.Body.recover(r) and r.hibernation=='SNAP:carried','saved pending release lost')
 assert(__captures==1 and __removed==1,'reload recaptured or removed absent body')
end
do
 local r,b=__setup() ISTimedActionQueue.queues[b]={queue={{}},current={}}
 assert(not SAO.Body.release(r) and __captures==0,'queued Lua action captured')
 ISTimedActionQueue.queues[b].queue={}
 assert(SAO.Body.release(r),'stale queue.current blocked idle body')
end
for _,target in ipairs({'body','inventory','nested'}) do
 local r,b=__setup() local doctor={}
 local reference=target=='body' and b or b.inventory
 if target=='nested' then reference={outer=b.inventory} end
 ISTimedActionQueue.queues[doctor]={queue={{otherPlayer=reference}}}
 assert(not SAO.Body.release(r) and __captures==0,'incoming action did not retain target')
end
do
 local r,b,a=__setup() __mode='empty' __band(0,0,{materialize=10,hibernate=20})
 assert(SAO.Controller.agents.p1==a and SAO.Body.active.p1==b,'population dropped early')
 assert(r.knoxInfected==nil and r.x==190,'population committed failed capture')
 assert(not table.concat(__logs,' '):find('continues without you',1,true),'false dormant log')
 __mode='ok' __band(0,0,{materialize=10,hibernate=20})
 assert(SAO.Controller.agents.p1==nil and SAO.Body.active.p1==nil,'population did not release')
end
do
 local r,b,a=__setup() __mode='throw' __release()
 assert(SAO.Controller.agents.p1==a and SAO.Body.active.p1==b,'harness dropped early')
 __mode='ok' __release() __now=45 __rematerialize()
 local restored=SAO.Body.get('p1')
 assert(restored and restored.payload=='carried' and restored.elapsed==3,
   'harness did not restore current person')
 assert(restored.visual=='current-look' and restored.visualRestoredAfter=='carried',
   'appearance did not restore after native state')
 assert(restored.perk==7,'profession granted twice after native restore')
 assert(__restored==1 and not restored.randomDress and SAO.Controller.agents.p1,
   'restore duplicated or dressed new person')
 __rematerialize() assert(__restored==1,'active body restored twice')
end
for _,mode in ipairs({'false','throw'}) do
 local r,b=__setup() r.bodyVisual='VIS:dyed-look'
 SAO.Body.active={} SAO.Controller.agents={}
 __visualRestore=mode __remove='false'
 assert(SAO.Body.materialize(r)==nil,'failed visual restore exposed body')
 assert(SAO.Body.active.p1 and SAO.Body.failedRestore.p1 and SAO.Body.get('p1')==nil,
   'failed visual restore lost cleanup ownership')
 assert(r.bodyVisual=='VIS:dyed-look' and r.hibernation=='SNAP:previous'
   and __accounted==0,'failed visual restore changed saved person')
 __visualRestore='ok' __remove='ok' __expectRestoredVisual='dyed-look'
 local restored=SAO.Body.materialize(r)
 assert(restored and restored.visual=='dyed-look' and restored.visualRestoredAfter=='previous',
   'visual restore retry lost saved appearance')
end
do
 local r=__setup() SAO.Body.active={} SAO.Controller.agents={}
 local restored=SAO.Body.materialize(r)
 assert(restored and __visualRestored==0,'legacy missing visual rejected or invented')
end
for _,mode in ipairs({'false','throw'}) do
 local r,b=__setup() SAO.Body.release(r) local x=r.x
 __restore=mode __remove='false'
 assert(SAO.Body.materialize(r)==nil,'failed restore published body')
 assert(__accounted==0,'failed restore consumed population')
 assert(r.hibernation=='SNAP:carried' and r.x==x and SAO.Controller.agents.p1==nil,
   'failed restore changed person')
 assert(SAO.Body.active.p1 and SAO.Body.failedRestore.p1,'partial shell handle lost')
 __restore='ok' __remove='ok'
 __band(200,210,{materialize=10,hibernate=20})
 assert(SAO.Body.get('p1') and SAO.Controller.agents.p1 and __restored==2,
   'population restore retry failed')
end
do
 local r,b,a=__setup() __mode='throw' __remove='false' __forget()
 assert(__captures==0 and __records.p1==r and SAO.Body.active.p1==b
   and SAO.Controller.agents.p1==a and SAO.Harness.activeId=='p1','failed clear orphaned person')
 __remove='ok' __forget()
 assert(__records.p1==nil and SAO.Body.active.p1==nil and SAO.Controller.agents.p1==nil
   and SAO.Harness.activeId==nil and __forgot==1,'explicit clear failed')
end
do
 local r,b=__setup() SAO.Body.active.p1=nil SAO.Body.foreign.p1=b
 __forget() assert(__records.p1==r and __removed==0,'clear removed foreign owner')
end
do
 local r,b=__setup() SAO.Body.active={} SAO.Controller.agents={} r.hibernation='broken'
 assert(SAO.Body.materialize(r)==nil and __spawned==0,'invalid saved snapshot spawned body')
end
do
 local r,b=__setup() __remove='false' SAO.Body.release(r) __mutations=0
 local function mutate() __mutations=__mutations+1 end
 SAO.Age.drift=mutate SAO.Age.hearThings=mutate SAO.Age.woundWatch=mutate
 SAO.Age.forgetSkills=mutate SAO.Age.growthSpurt=mutate
 __age() assert(__mutations==0,'age mutated pending body')
 BenzoAddict=mutate BenzoEffect=mutate
 __minute=0 __drug() __minute=11 __drug()
 assert(__mutations==0,'drugs mutated pending body')
 ZAO={StateStore={read=function() return {terminalState='afflicted',currentForm='test'} end}}
 SAO.AfflictedReturn.stampLive(1)
 assert(b.md.ZAOForm==nil,'afflicted callback mutated pending body')
 local strike={circles={{x=200,y=210,r=20,name='test'}}}
 __strike(strike) __radiation(strike)
 assert(__mutations==0,'nuke callback mutated pending body')
end
for _,kind in ipairs({'release','restore','discard'}) do
 local r,b=__setup() __remove='false'
 if kind=='release' then SAO.Body.release(r)
 elseif kind=='restore' then SAO.Body.failedRestore.p1=true
 else SAO.Body.discarding.p1=true end
 assert(SAO.Body.pendingTransitionCount()==1,'pending transition count missing')
 assert(SAO.Body.activeCount()==0,'pending body counted as available')
 local before=__removed
 SAO.Identity.markDead(r,1,'test')
 assert(__removed==before+1,'death did not attempt pending cleanup')
 assert(r.dead and SAO.Body.active.p1==b and SAO.Body.isTransitioning(r),
   'failed death cleanup orphaned body')
 assert(not SAO.Body.recover(r),'dead transition falsely completed')
 assert(SAO.Body.materialize(r)==nil and __spawned==0,'dead person reconstructed')
 __remove='ok'
 assert(SAO.Body.recover(r),'dead cleanup retry failed')
 assert(r.hibernation=='SNAP:previous' and r.bodyRelease==nil,
   'death committed pending live snapshot')
 assert(SAO.Body.active.p1==nil and SAO.Controller.agents.p1==nil
   and SAO.Body.pendingTransitionCount()==0,'dead cleanup retained ownership')
end
do
 local r,b=__setup()
 SAO.Identity.markDead(r,1,'test')
 assert(__removed==0 and SAO.Body.active.p1==b,'ordinary corpse removed')
 assert(SAO.Body.recover(r) and __removed==0,'ordinary corpse removed during recovery')
 assert(SAO.Body.materialize(r)==nil,'ordinary dead person reconstructed')
end
do
 local r=__setup() r.bodyRelease={}
 SAO.Body.failedRestore.p1=true SAO.Body.discarding.p1=true
 assert(SAO.Body.pendingTransitionCount()==1,'pending transition counted twice')
 r.crossedTransferPending={token='blood:pending'}
 assert(SAO.Body.pendingTransitionCount()==1 and SAO.Body.activeCount()==0,
   'pending Crossed transfer counted as an available body')
 SAO.Body.discarding.p2=true
 assert(SAO.Body.pendingTransitionCount()==2,'pending unbound handle omitted')
end
do
 local r,b=__setup()
 b.isDead=function() return false end
 __sourceReservation={id='source-route',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 ZAO={Controller={acceptExternal=function() return true end}}
 assert(SAO.CrossedTransfer.begin('p1',b,'blood:source-route',42),
   'Crossed transfer did not close source route ownership')
 assert(r.bodyOwner=='ZAO' and r.worldSourceReservation==nil
   and SAO.Locomotion.jobs.p1==nil and SAO.Body.canTransfer(b),
   'source route still made the body busy after closure')
 assert(__sourceEvents[1]=='cancel' and __sourceEvents[2]=='release',
   'source route released before its locomotion owner was cancelled')
end
do
 local r,b,a=__setup()
 __nearestObserved={id='observed-place',cx=220,cy=210,minX=219,minY=209,
   maxX=222,maxY=212}
 local started=__beginObservedUse('p1',a,b,0.8,'food',0.5)
 assert(started and __sourceReservation
   and SAO.Locomotion.jobs.p1 and __sourceEvents[1]=='order',
   'controller did not begin the exact observed-source route')
 assert(__setState(a,'p1','SOURCEWARD','approaches observed food')
   and a.state=='SOURCEWARD' and __sourceReservation
   and r.worldSourceReservation=='controller-source-begin'
   and SAO.Locomotion.jobs.p1 and #__sourceEvents==1,
   'initial SOURCEWARD projection cancelled its own durable action')
end
do
 local r,b,a=__setup()
 __sourceReservation={id='order-travel',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 assert(SAO.Controller.orderTravel('p1',220,210,0)
   and a.state=='TRAVEL','stale source projection blocked lawful travel close')
 assert(__sourceEvents[1]=='cancel' and __sourceEvents[2]=='release'
   and __sourceEvents[3]=='order',
   'travel began before durable source ownership closed')
end
do
 local r,b,a=__setup()
 __sourceReservation={id='internal-mourn-route',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 assert(__orderTravelState(a,'p1',b,230,210,0,'MOURNWARD',
   'witness route') and a.state=='MOURNWARD',
   'internal cross-agent travel did not use the guarded route primitive')
 assert(__sourceEvents[1]=='cancel' and __sourceEvents[2]=='release'
   and __sourceEvents[3]=='order',
   'internal travel replaced source locomotion before ownership closed')
end
do
 local r,b,a=__setup()
 __sourceReservation={id='harness-travel',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 assert(__harnessTravel('p1',225,210,0) and a.state=='TRAVEL',
   'Harness travel did not enter the guarded Controller route')
 assert(__sourceEvents[1]=='cancel' and __sourceEvents[2]=='release'
   and __sourceEvents[3]=='order',
   'Harness route replaced source locomotion before ownership closed')
end
do
 local r,b,a=__setup()
 __sourceReservation={id='order-engage',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 local bodyBeforeEngage=SAO.Body.get('p1')
 local engaged=SAO.Controller.orderEngageNearest('p1',true)
 assert(engaged and a.state=='ENGAGE',
   'stale source projection blocked lawful combat close: ordered='
     ..tostring(engaged)..' state='..tostring(a.state)
     ..' events='..table.concat(__sourceEvents,',')
     ..' active='..tostring(SAO.Body.active.p1==b)
     ..' bodyBefore='..tostring(bodyBeforeEngage==b)
     ..' transitioning='..tostring(SAO.Body.isTransitioning(r))
     ..' logs='..table.concat(__logs,'|'))
 assert(__sourceEvents[1]=='cancel' and __sourceEvents[2]=='release'
   and __sourceEvents[3]=='combat',
   'combat began before durable source ownership closed')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end __allowObserve=true
 __sourceReservation={id='projection-route',actorId='p1',status='reserved',
   phase='approaching-place',placeX=220,placeY=210,placeZ=0}
 r.worldSourceReservation=__sourceReservation.id
 a.state='ROAM' a.taskDeadline=99999
 __update('p1',a)
 assert(a.state=='SOURCEWARD' and __sourceEvents[1]=='observe'
   and __sourceEvents[2]=='order',
   'non-IDLE projection did not reconstruct durable source route')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end
 __sourceReservation={id='future-source',actorId='p1',status='unavailable',
   phase='unavailable',unavailable=true}
 r.worldSourceReservation=__sourceReservation.id
 a.state='SOURCEWARD' a.taskDeadline=99999 a.passive=true
 __update('p1',a)
 assert(a.state=='SOURCEWARD' and r.worldSourceReservation=='future-source'
   and __locomotionTicks==0 and a.nextDecisionAt==0
   and #__sourceEvents==0 and not SAO.Body.canTransfer(b),
   'opaque future source owner failed open across Controller or Body')
end
for _,opaque in ipairs({false,true}) do
 local r,b,a=__setup()
 SAO.Body.active.p1=nil SAO.Controller.agents.p1=nil
 r.homeX=190 r.homeY=195 r.x=190 r.y=195 r.nextDormantMoveAt=77
 __sourceReservation={id=opaque and 'future-dormant' or 'live-dormant',
   actorId='p1',status=opaque and 'unavailable' or 'reserved',
   phase=opaque and 'unavailable' or 'transferring',unavailable=opaque or nil}
 r.worldSourceReservation=__sourceReservation.id
 SAO.DormantPopulation.dormantLife({},100)
 SAO.DormantPopulation.dormantAttrition(100)
 assert(r.x==190 and r.y==195 and r.nextDormantMoveAt==77
   and r.lastWaterDay==nil and r.lastFoodDay==nil and r.lastRiskDay==nil
   and not r.dead and r.worldSourceReservation==__sourceReservation.id,
   'dormant approximation mutated a source-owned actor')
end
do
 __setup()
 SAO.Body.active={} SAO.Controller.agents={}
 __records={
   p1={id='p1',x=100,y=100,homeX=100,homeY=100},
   p2={id='p2',x=101,y=100,homeX=101,homeY=100},
 }
 __sourceReservation={id='whole-dormant-owner',actorId='p1',
   status='reserved',phase='transferring'}
 __records.p1.worldSourceReservation=__sourceReservation.id
 local oldGroupOf=SAO.Standing.groupOf
 local oldGroupSize=SAO.Standing.groupSize
 local oldMembersOf=SAO.Standing.membersOf
 local oldGroupClaimOf=SAO.Standing.groupClaimOf
 local oldSetGroupClaim=SAO.Standing.setGroupClaim
 local oldSetLarder=SAO.Standing.setLarder
 local oldSetWaterStore=SAO.Standing.setWaterStore
 local oldSetHearth=SAO.Standing.setHearth
 local oldReturnsOf=SAO.Perception.returnsOf
 local effects=0
 SAO.Standing.groupOf=function() return 'g' end
 SAO.Standing.groupSize=function() return 2 end
 SAO.Standing.membersOf=function() return {'p1','p2'} end
 SAO.Standing.groupClaimOf=function() return nil end
 SAO.Standing.setGroupClaim=function() effects=effects+1 end
 SAO.Standing.setLarder=function() effects=effects+1 end
 SAO.Standing.setWaterStore=function() effects=effects+1 end
 SAO.Standing.setHearth=function() effects=effects+1 end
 SAO.Perception.returnsOf=function() effects=effects+1 return {} end
 SAO.DormantPopulation.dormantSettle()
 SAO.Standing.groupClaimOf=function()
   return {minX=90,minY=90,maxX=110,maxY=110}
 end
 SAO.DormantPopulation.dormantProvision()
 SAO.DormantPopulation.rebindWorld()
 SAO.DormantPopulation.dormantEncounters(100)
 assert(effects==0 and __records.p1.x==100 and __records.p2.x==101,
   'source-owned dormant actor settled, provisioned, or encountered')
 SAO.Standing.groupOf=oldGroupOf
 SAO.Standing.groupSize=oldGroupSize
 SAO.Standing.membersOf=oldMembersOf
 SAO.Standing.groupClaimOf=oldGroupClaimOf
 SAO.Standing.setGroupClaim=oldSetGroupClaim
 SAO.Standing.setLarder=oldSetLarder
 SAO.Standing.setWaterStore=oldSetWaterStore
 SAO.Standing.setHearth=oldSetHearth
 SAO.Perception.returnsOf=oldReturnsOf
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end __allowObserve=true __sourceBusy=true
 __sourceReservation={id='projection-transfer',actorId='p1',status='reserved',
   phase='transferring'}
 r.worldSourceReservation=__sourceReservation.id
 a.state='SOURCEWARD' a.taskDeadline=99999
 __update('p1',a)
 assert(a.state=='SOURCEUSE' and __sourceReservation.phase=='transferring'
   and __locomotionTicks==0,
   'durable transfer phase was re-run as SOURCEWARD movement')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end __allowObserve=true
 __sourceReservation={id='route-hold',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 a.state='SOURCEWARD' a.taskDeadline=99999
 __update('p1',a)
 assert(a.state=='SOURCEWARD' and __locomotionTicks==1
   and __sourceReservation~=nil,
   'SOURCEWARD fell through to another action producer')
end
for _,kind in ipairs({'hostile','formed'}) do
 local r,b,a=__setup()
 b.isDead=function() return false end __allowObserve=true
 __sourceReservation={id='route-threat-'..kind,actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 a.state='SOURCEWARD' a.taskDeadline=99999
 if kind=='hostile' then
   __hostileKey='Enemy'
   SAO.Perception.beliefs.p1={people={Enemy={at=0,x=201,y=210,
     dist=1,source='observed'}}}
 else
   __formedThreat={x=201,y=210,dist=1,fromPerson=true}
 end
 __update('p1',a)
 assert(a.state=='ALERT' and __sourceReservation==nil
   and __sourceEvents[2]=='cancel' and __sourceEvents[3]=='release',
   kind..' threat did not close source ownership before response')
end
do
 local r,b,a=__setup()
 b.isDead=function() return true end __allowObserve=true
 __sourceReservation={id='route-death',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 a.state='SOURCEWARD' a.taskDeadline=99999
 __update('p1',a)
 assert(r.dead and SAO.Controller.agents.p1==nil
   and __sourceReservation==nil and SAO.Locomotion.jobs.p1==nil
   and __locomotionTicks==0,
   'death during SOURCEWARD advanced or stranded source ownership')
end
do
 local r,b,a=__setup()
 b.isDead=function() return true end
 r.crossedTransferPending={token='crossed:dead-source',atHours=42}
 __sourceReservation={id='dead-crossed-source',actorId='p1',status='reserved',
   phase='approaching-place'}
 r.worldSourceReservation=__sourceReservation.id
 SAO.Locomotion.jobs.p1={done=false}
 __update('p1',a)
 assert(r.dead and not r.bodyOwner and not r.crossedTransferPending
   and not r.bodyTransfer and __sourceReservation==nil
   and SAO.Controller.agents.p1==nil,
   'dead active shell transferred while source reconciliation was pending')
end
do
 local r,b,a=__setup()
 b.isDead=function() return true end
 r.crossedTransferPending={token='crossed:dead-captured',atHours=42}
 r.bodyTransfer={version=1,owner='ZAO',token='crossed:dead-captured',
   phase='captured',captured={opaque='captured-living-state'}}
 __update('p1',a)
 assert(r.dead and not r.bodyOwner and not r.crossedTransferPending
   and not r.bodyTransfer and SAO.Controller.agents.p1==nil,
   'captured handoff published an engine-dead active shell')
end
do
 local r,b=__setup()
 b.isDead=function() return true end
 r.crossedTransferPending={token='crossed:direct-dead',atHours=42}
 r.bodyTransfer={version=1,owner='ZAO',token='crossed:direct-dead',
   phase='captured',captured={opaque='captured-living-state'}}
 local ok,why=SAO.CrossedTransfer.resume(r)
 assert(not ok and why=='person-dead' and not r.bodyOwner
   and not r.crossedTransferPending and not r.bodyTransfer,
   'Crossed retry committed a captured engine-dead shell')
end
do
 local r,b,a=__setup()
 local close=SAO.SourceUse.closeForOwnershipTransfer
 SAO.SourceUse.closeForOwnershipTransfer=function() return false end
 assert(not SAO.Controller.drop('p1') and SAO.Controller.agents.p1==a,
   'fault drop deleted the only pending source executor')
 SAO.SourceUse.closeForOwnershipTransfer=close
 assert(SAO.Controller.drop('p1') and SAO.Controller.agents.p1==nil,
   'controller could not drop after source ownership closed')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end __allowObserve=true
 __sourceReservation={id='crossed-retry',actorId='p1',status='reserved',
   phase='native-complete'}
 r.worldSourceReservation=__sourceReservation.id
 r.crossedTransferPending={token='crossed:controller-retry',atHours=42}
 ZAO={Controller={acceptExternal=function() return true end}}
 local close=SAO.SourceUse.closeForOwnershipTransfer
 local terminal=false
 SAO.SourceUse.closeForOwnershipTransfer=function()
   if not terminal then return false end
   __sourceReservation=nil r.worldSourceReservation=nil
   SAO.Locomotion.jobs.p1=nil
   return true
 end
 __update('p1',a)
 assert(r.bodyOwner==nil and r.crossedTransferPending,
   'Crossed handoff ignored pending source reconciliation')
 terminal=true __update('p1',a)
 SAO.SourceUse.closeForOwnershipTransfer=close
 assert(r.bodyOwner=='ZAO' and r.crossedTransferPending==nil,
   'controller did not trigger Crossed handoff after source terminal')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end
 local accepted=0
 ZAO={Controller={acceptExternal=function(id,seen,token)
   assert(id=='p1' and seen==b and token=='blood:p1') accepted=accepted+1 return true
 end}}
 assert(SAO.CrossedTransfer.begin('p1',b,'blood:p1',42),'crossed transfer failed')
 assert(r.bodyOwner=='ZAO' and r.bodyOwnerToken=='blood:p1'
   and r.hibernation=='SNAP:carried','external owner or snapshot did not commit')
 assert(SAO.Body.active.p1==nil and SAO.Body.foreign.p1==b
   and SAO.Controller.agents.p1==nil,'one body retained two runtime owners')
 assert(not b.removed and b.md.ZAOOwned and b.md.SAOExternalToken=='blood:p1',
   'transfer replaced the human shell or omitted its owner mark')
 assert(SAO.Body.get('p1')==b and SAO.Body.hasRepresentation('p1'),
   'external body disappeared from observation')
 local captured=__captures
 assert(SAO.CrossedTransfer.begin('p1',b,'blood:p1',42),
   'exact transfer retry failed')
 assert(__captures==captured and accepted==2,'transfer retry recaptured or changed owner')

 b.payload='after-transfer'
 local report=SAO.Body.checkpointActive()
 assert(report.saved==1 and r.hibernation=='SNAP:after-transfer',
   'save checkpoint skipped ZAO-owned living shell')

 SAO.Body.foreign={} Ctl=nil
 local ordinary,why=SAO.Body.materialize(r)
 assert(ordinary==nil and why=='external-owner',
   'ordinary SAO materialization stole external owner')
 __now=50
 local restored=SAO.Body.materializeExternal(r,'ZAO','blood:p1')
 assert(restored and SAO.Body.foreign.p1==restored and SAO.Body.active.p1==nil
   and restored.payload=='after-transfer','external reload did not restore same person')
 restored.isDead=function() return false end
 assert(SAO.Body.hibernateExternal(r,restored,'ZAO','blood:p1'),
   'external owner could not hibernate its shell')
 assert(SAO.Body.foreign.p1==nil and r.bodyOwner=='ZAO'
   and SAO.Body.hasRepresentation('p1'),'dormancy returned person to SAO simulation')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end
 ZAO={Controller={acceptExternal=function() return true end}}
 assert(SAO.CrossedTransfer.begin('p1',b,'blood:death',42),
   'death fixture transfer failed')
 b.isDead=function() return true end
 assert(SAO.Controller.observeExternalDeath('p1',b,'ZAO'),
   'external death did not enter county death funnel')
 assert(r.dead and r.deathCause=='crossed body killed'
   and r.bodyOwner==nil and r.bodyOwnerToken==nil,
   'external death retained living ownership or lost its cause')
 assert(SAO.Body.foreign.p1==nil and SAO.Controller.agents.p1==nil
   and SAO.Controller.pendingCorpses.p1.body==b,
   'external death lost the corpse or retained a runtime owner')
 assert(not SAO.Controller.observeExternalDeath('p1',b,'ZAO'),
   'external death completed twice')
end
do
 local r,b,a=__setup()
 b.isDead=function() return false end
 ZAO={
  Pathogen={stateOf=function() return {terminalState='crossed',
    crossedTransferToken='crossed:p1:retry'} end},
  Controller={acceptExternal=function() return true end}
 }
 __mode='busy'
 assert(not SAO.CrossedTransfer.begin('p1',b,'crossed:p1:retry',42)
   and r.bodyTransfer==nil and r.bodyOwner==nil
   and r.crossedTransferPending.token=='crossed:p1:retry',
   'busy conversion falsely transferred')
 local get=SAO.Body.get
 SAO.Body.get=function() error('pending Crossed body advanced') end
 __update('p1',a)
 SAO.Body.get=get
 assert(not SAO.CrossedTransfer.resumePending(),
   'busy conversion reported all retries complete')
 __mode='ok'
 assert(SAO.CrossedTransfer.resumePending()
   and r.bodyOwner=='ZAO' and SAO.Body.foreign.p1==b,
   'busy conversion was not retried from durable pending state')
end
do
 local r,b=__setup()
 b.isDead=function() return false end
 ZAO={Controller={acceptExternal=function() return true end}}
 __mode='busy'
 assert(not SAO.CrossedTransfer.begin('p1',b,'crossed:p1:reload',42),
   'reload fixture transferred before its action boundary')
 local report=SAO.Body.checkpointActive()
 assert(report.saved==1 and r.hibernation=='SNAP:carried',
   'pending conversion was not checkpointed before reload')
 SAO.Body.active={} SAO.Controller.agents={} __mode='ok'
 assert(SAO.CrossedTransfer.resumePending()
   and r.bodyOwner=='ZAO' and r.bodyOwnerToken=='crossed:p1:reload'
   and SAO.Body.foreign.p1==nil and SAO.Body.hasRepresentation('p1')
   and r.crossedTransferPending==nil,
   'pending conversion reload did not transfer dormant snapshot')
end
-- One snapshot contract serves pending release and external ownership.
-- A journal can be corrupted after capture or restored from a damaged save.
for _,kind in ipairs({'release','transfer'}) do
 for _,field in ipairs({'packed','visual','hours','x','facts'}) do
  local r,b,a=__setup()
  local pending
  if kind=='release' then
   __remove='false' SAO.Body.release(r) __remove='ok' pending=r.bodyRelease
  else
   assert(SAO.Body.prepareExternalTransfer(r,b,'ZAO','snapshot-control'))
   pending=r.bodyTransfer.captured
  end
  if field=='facts' then pending.facts=nil
  elseif field=='hours' or field=='x' then pending[field]=0/0
  else pending[field]='broken' end
  local removed=__removed
  local ok,reason
  if kind=='release' then ok,reason=SAO.Body.release(r)
  else ok,reason=SAO.Body.commitExternalTransfer(r) end
  assert(ok==false and reason=='invalid-pending-snapshot',
    'invalid '..kind..' snapshot was published')
  assert(__removed==removed and SAO.Body.active.p1==b and SAO.Controller.agents.p1==a
    and r.hibernation=='SNAP:previous' and r.bodyOwner==nil,
    'invalid snapshot changed state or ownership')
 end
end
-- Native durable strings may be chunk tables. Their engine validators own
-- that representation; a release cannot narrow it back to plain text.
do
 local capture,visual=SAOJavaBridge.hibernate,SAOJavaBridge.captureReturnVisual
 local valid,validVisual=SAOJavaBridge.validateHibernation,SAOJavaBridge.validateReturnVisual
 SAOJavaBridge.hibernate=function(self,b) return {opaque=capture(self,b)} end
 SAOJavaBridge.captureReturnVisual=function(self,b) return {opaque=visual(self,b)} end
 SAOJavaBridge.validateHibernation=function(self,v)
  return type(v)=='table' and valid(self,v.opaque) end
 SAOJavaBridge.validateReturnVisual=function(self,v)
  return type(v)=='table' and validVisual(self,v.opaque) end
 local r,b=__setup()
 assert(SAO.Body.release(r) and r.hibernation.opaque=='SNAP:carried'
   and r.bodyVisual.opaque=='VIS:current-look','release refused durable table payload')
 SAOJavaBridge.hibernate,SAOJavaBridge.captureReturnVisual=capture,visual
 SAOJavaBridge.validateHibernation,SAOJavaBridge.validateReturnVisual=valid,validVisual
end
return 'PASS'
'''

def instrument(name, source):
    if name == 'SAO_Identity.lua':
        body = function_body(source, 'Identity.markDead')
        assert body is not None, 'Identity.markDead extraction failed'
        return ('local Identity=SAO.Identity\nlocal function log() end\n'
                'function Identity.markDead(' + body + '\nend\n')
    if name == 'SAO_Controller.lua':
        return source.replace('return Ctl\n',
                '__update=updateAgent __orderTravelState=orderTravelState '
                '__beginObservedUse=beginObservedUse __setState=setState\nreturn Ctl\n')
    if name == 'SAO_PopulationRepresentation.lua':
        return source.replace('return R\n', '__band=materializeBand\nreturn R\n')
    if name == 'SAO_Harness.lua':
        return (source + '\n__release=release __forget=forget '
                '__rematerialize=rematerialize '
                '__harnessTravel=orderCommandTravel\n')
    if name == 'SAO_Age.lua':
        return source.replace('return Age\n', '__age=everyTenMinutes\nreturn Age\n')
    if name == 'SAO_Drugs.lua':
        return source.replace('return Dg\n', '__drug=onTick\nreturn Dg\n')
    if name == 'SAO_Nuke.lua':
        return source.replace('return N\n', '__strike=strike __radiation=attrition\nreturn N\n')
    return source


def run(work, sources):
    pre = work / 'prelude.lua'; pre.write_text(PRELUDE, encoding='utf-8')
    chunks = [str(pre)]
    for name in FILES:
        path = work / name; path.write_text(instrument(name, sources[name]), encoding='utf-8')
        chunks.append(str(path))
    case = work / 'cases.lua'; case.write_text('function __cases()\n'+CASES+'\nend', encoding='utf-8')
    chunks.append(str(case))
    result = subprocess.run([str(JDK/'java.exe'), '-cp', str(GAME/'projectzomboid.jar')+';.',
        'LuaRun', *chunks, '--', '__cases()'], cwd=work, capture_output=True, text=True, timeout=90)
    lines = [line for line in result.stdout.splitlines() if line.startswith(('VALUE ', 'ERROR '))]
    return '\n'.join(lines) or (result.stdout+result.stderr)[-2000:]


def main():
    sources = {}
    for name in FILES:
        path = source_path(name)
        if not path.is_file():
            print('FAULT: missing production module '+name); return 1
        sources[name] = path.read_text(encoding='utf-8')
    if not (GAME/'projectzomboid.jar').is_file() or not (JDK/'javac.exe').is_file():
        print('SKIPPED: installed game and JDK required for handoff proof'); return 0
    faults = []
    with tempfile.TemporaryDirectory(prefix='sao-person-handoff-') as tmp:
        work=Path(tmp); shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
        built=subprocess.run([str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar'),'-d',str(work),
            str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=120)
        if built.returncode:
            print('FAULT: runner compilation\n'+built.stderr); return 1
        result=run(work,sources); print('production: '+result)
        if result!='VALUE PASS': faults.append('production')
        controls=[
            ('SAO_Body.lua','if not SAO.BodySnapshot.valid(pending) then return false, "invalid-pending-snapshot" end',
             '', 'invalid release snapshot was published'),
            ('SAO_Body.lua','if not SAO.BodySnapshot.valid(pending.captured) then',
             'if false then', 'invalid transfer snapshot was published'),
            ('SAO_BodySnapshot.lua','or SAOJavaBridge:validateReturnVisual(captured.visual) == true)',
             'or true)', 'invalid release snapshot was published'),
            ('SAO_BodySnapshot.lua','or SAOJavaBridge:validateReturnVisual(captured.visual) == true)',
             'or (type(captured.visual) == "string" and SAOJavaBridge:validateReturnVisual(captured.visual) == true))',
             'release refused durable table payload'),
            ('SAO_Identity.lua','pcall(SAO.Body.discard, rec)',
             '', 'death did not attempt pending cleanup'),
            ('SAO_Body.lua','if rec.dead then return nil, "dead-record" end',
             '', 'ordinary dead person reconstructed'),
            ('SAO_Body.lua','if Body.isTransitioning(rec) then return Body.discard(rec) end',
             'if Body.isTransitioning(rec) then return true end', 'dead transition falsely completed'),
            ('SAO_Body.lua','if not ok or not captured then return false, "capture-failed" end',
             'if not ok or not captured then Body.active[rec.id]=nil return false, "capture-failed" end',
             'capture failure relinquished ownership'),
            ('SAO_Body.lua','return SAOJavaBridge:removeShell(body) == true',
             'SAOJavaBridge:removeShell(body) return true','teardown failure reported success'),
            ('SAO_Body.lua','pending = captured\n        rec.bodyRelease = pending',
             'pending = captured','saved pending release lost'),
            ('SAO_PopulationRepresentation.lua','local released, reason = SAO.Body.release(rec)',
             'SAO.Controller.drop(id) local released, reason = SAO.Body.release(rec)',
             'population dropped early'),
            ('SAO_PhysicalFacts.lua','rec.infectionStartedAtHours = now\n',
             'rec.infectionStartedAtHours = nil\n',
             'release lost the observed infection interval'),
            ('SAO_Harness.lua','local ok, reason = SAO.Body.release(rec)',
             'SAO.Controller.drop(H.activeId) local ok, reason = SAO.Body.release(rec)',
             'harness dropped early'),
            ('SAO_Body.lua','return SAOJavaBridge:awaken(body, rec.hibernation, elapsed)',
             'return "AWAKENED skipped"','harness did not restore current person'),
            ('SAO_BodySnapshot.lua','rec.bodyVisual = captured.visual',
             '', 'release lost captured appearance'),
            ('SAO_Body.lua','if not ok or restored ~= true then',
             'if false then', 'failed visual restore exposed body'),
            ('SAO_Harness.lua','if not ok then log("forget refused: " .. tostring(reason)) return end',
             'if not ok then log("forget refused: " .. tostring(reason)) end',
             'failed clear orphaned person'),
            ('SAO_Controller.lua','if SAO.Body.isTransitioning(agent.rec) and not crossedPending then return end',
             'if false then return end', 'pending body advanced'),
            ('SAO_Controller.lua','if agent.rec.crossedTransferPending then',
             'if false then', 'pending Crossed body advanced'),
            ('SAO_Age.lua','if rec and not SAO.Body.isTransitioning(rec) then',
             'if rec then', 'age mutated pending body'),
            ('SAO_Drugs.lua','if SAO.Body.isTransitioning(SAO.Identity.get(id)) then return end',
             '', 'drugs mutated pending body'),
            ('SAO_AfflictedReturn.lua','if okState and state and SAO.Body.get(id) == body',
             'if okState and state', 'afflicted callback mutated pending body'),
            ('SAO_Body.lua','if reference == body or reference == inventory then return false end',
             'if false then return false end', 'incoming action did not retain target'),
            ('SAO_Body.lua','if SAOJavaBridge and SAOJavaBridge:isInventoryOf(body, reference) then',
             'if false then', 'incoming action did not retain target'),
            ('SAO_Body.lua','SAO.BodySnapshot.commit(rec, pending.captured)',
             '', 'external owner or snapshot did not commit'),
            ('SAO_Body.lua','Body.active[rec.id] = nil\n    rec.bodyOwner = pending.owner',
             'rec.bodyOwner = pending.owner', 'one body retained two runtime owners'),
            ('SAO_Body.lua','if rec.bodyOwner ~= nil then',
             'if false then', 'ordinary SAO materialization stole external owner'),
            ('SAO_Controller.lua','rec.bodyOwner, rec.bodyOwnerToken = nil, nil',
             '', 'external death retained living ownership or lost its cause'),
            ('SAO_CrossedTransfer.lua','elseif rec.crossedTransferPending then',
             'elseif false then', 'busy conversion was not retried from durable pending state'),
            ('SAO_Body.lua','rec.bodyOwner, rec.bodyOwnerToken = owner, token',
             'rec.bodyOwnerToken = token',
             'pending conversion reload did not transfer dormant snapshot'),
        ]
        for name,old,new,expected in controls:
            if sources[name].count(old)!=1:
                faults.append('control seam '+expected); continue
            changed=dict(sources); changed[name]=changed[name].replace(old,new,1)
            result=run(work,changed)
            # Earlier failure of the same persistence defect is also specific.
            reasons=[expected]
            if expected=='saved pending release lost':
                reasons+=['pending capture not separate','pending body remained available or became dormant']
            if expected=='busy conversion was not retried from durable pending state':
                reasons+=['busy conversion reported all retries complete',
                           'controller did not trigger Crossed handoff after source terminal']
            if expected=='pending Crossed body advanced':
                reasons+=['controller did not trigger Crossed handoff after source terminal']
            rejected=result.startswith('ERROR ') and any(x in result for x in reasons)
            print('CONTROL '+expected+': '+('REJECTED ' if rejected else 'SURVIVED ')+result)
            if not rejected: faults.append(expected)
    print("  162) "+('FAULT '+', '.join(faults) if faults else 'PASS')+' -- person ownership handoff')
    return bool(faults)


if __name__=='__main__':
    sys.exit(main())
