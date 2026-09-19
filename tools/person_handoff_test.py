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
FILES = ['SAO_Body.lua', 'SAO_Controller.lua', 'SAO_Population.lua', 'SAO_Harness.lua',
         'SAO_Age.lua', 'SAO_Drugs.lua', 'SAO_AfflictedReturn.lua', 'SAO_Nuke.lua', 'SAO_Identity.lua']

PRELUDE = r'''
Events=setmetatable({}, {__index=function() return {Add=function() end,Remove=function() end} end})
getSpecificPlayer=function() return nil end
getGameTime=function() return {getMinutesStamp=function() return __minute or 0 end} end
SandboxVars={ZombieLore={Mortality=5}}
ISTimedActionQueue={queues={}}
__records={} __logs={} __mode='ok' __remove='ok' __restore='ok' __now=42
__captures=0 __removed=0 __restored=0 __spawned=0 __forgot=0 __events=0 __accounted=0
SAO={
 Log={line=function(tag,msg) table.insert(__logs,msg) end},
 Identity={all=function() return __records end,
   get=function(id) return __records[id] end,
   remove=function(id) __records[id]=nil __forgot=__forgot+1 end,
   femaleOf=function() return false end, knownName=function() return nil end,
   updatePosition=function(rec,x,y,z) rec.x=x rec.y=y rec.z=z end},
 History={countyHours=function() return __now end},
 Standing={groupOf=function() return nil end,allGroupClaims=function() return {} end,
   ownsRadio=function() return __radio==true end},
 Disposition={describe=function() return 'test' end},
 Claims={isHeld=function() return false end},
 Census={rowOf=function() return {engineKey='test'} end},
 Locomotion={cancel=function() if __cancelThrow then error('cancel unavailable') end end},
 Perception={forget=function() end,observe=function() error('pending body advanced') end},
 Voice={forget=function() end},
 Rand={int=function() return 0 end},
 PathogenEvents={emit=function() __events=__events+1 end}
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
 SAO.Body.discarding.p2=true
 assert(SAO.Body.pendingTransitionCount()==2,'pending unbound handle omitted')
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
        return source.replace('return Ctl\n', '__update=updateAgent\nreturn Ctl\n')
    if name == 'SAO_Population.lua':
        return source.replace('return Pop\n', '__band=materializeBand\nreturn Pop\n')
    if name == 'SAO_Harness.lua':
        return source + '\n__release=release __forget=forget __rematerialize=rematerialize\n'
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
        path = (LUA.parent/'shared'/name) if name == 'SAO_Identity.lua' else LUA/name
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
            ('SAO_Population.lua','local released, reason = SAO.Body.release(rec)',
             'SAO.Controller.drop(id) local released, reason = SAO.Body.release(rec)',
             'population dropped early'),
            ('SAO_Harness.lua','local ok, reason = SAO.Body.release(rec)',
             'SAO.Controller.drop(H.activeId) local ok, reason = SAO.Body.release(rec)',
             'harness dropped early'),
            ('SAO_Body.lua','return SAOJavaBridge:awaken(body, rec.hibernation, elapsed)',
             'return "AWAKENED skipped"','harness did not restore current person'),
            ('SAO_Body.lua','rec.bodyVisual = pending.visual',
             '', 'release lost captured appearance'),
            ('SAO_Body.lua','if not ok or restored ~= true then',
             'if false then', 'failed visual restore exposed body'),
            ('SAO_Harness.lua','if not ok then log("forget refused: " .. tostring(reason)) return end',
             'if not ok then log("forget refused: " .. tostring(reason)) end',
             'failed clear orphaned person'),
            ('SAO_Controller.lua','if SAO.Body.isTransitioning(agent.rec) then return end',
             '', 'pending body advanced'),
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
            rejected=result.startswith('ERROR ') and any(x in result for x in reasons)
            print('CONTROL '+expected+': '+('REJECTED ' if rejected else 'SURVIVED ')+result)
            if not rejected: faults.append(expected)
    print("  162) "+('FAULT '+', '.join(faults) if faults else 'PASS')+' -- person ownership handoff')
    return bool(faults)


if __name__=='__main__':
    sys.exit(main())
