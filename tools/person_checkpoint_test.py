#!/usr/bin/env python3
"""Save-event person checkpoint in Kahlua, with installed-engine save ordering.

The bridge/body doubles expose current inventory as an opaque snapshot payload.
Native component fidelity is covered by native_person_test.py. This test runs
the shipped Body and physical-fact producer, not an alternate checkpoint model.
It does not launch the game or write a world save.
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import person_handoff_test as vm

ROOT = vm.ROOT
HOST = r'''
__saveCallbacks={}
Events.OnSave={
 Add=function(fn) table.insert(__saveCallbacks,fn) end,
 Remove=function(fn)
  for i=#__saveCallbacks,1,-1 do if __saveCallbacks[i]==fn then table.remove(__saveCallbacks,i) end end
 end
}
local oldBody=__body
function __body()
 local b=oldBody() b.isDead=function() return b.nativeDead==true end return b
end
function __plainCopy(value, seen)
 local kind=type(value)
 assert(kind=='table' or kind=='number' or kind=='string' or kind=='boolean' or kind=='nil',
   'transient value entered saved identity')
 if kind~='table' then return value end
 seen=seen or {} assert(not seen[value],'cyclic or body reference entered saved identity') seen[value]=true
 local copy={}
 for k,v in pairs(value) do copy[__plainCopy(k,seen)]=__plainCopy(v,seen) end
 seen[value]=nil return copy
end
function __save()
 local checkpointCount=0
 for _,fn in ipairs(__saveCallbacks) do
  if fn==SAO.Body.onSaveCheckpoint then checkpointCount=checkpointCount+1 end
 end
 assert(checkpointCount==1,'save checkpoint callback missing or duplicated')
 -- Mirrors the verified native GameWindow.save ordering, without world IO.
 for _,fn in ipairs(__saveCallbacks) do fn() end
 __persisted=__plainCopy(__records)
 return SAO.Body.lastCheckpointReport
end
'''

CASES = r'''
do
 local r,b,a=__setup()
 SAO.Body.unloaded.p1=true
 assert(SAO.Body.get('p1')==nil and SAO.Body.hasRepresentation('p1'),
   'unloaded checkpoint fixture lost retained ownership')
 local report=__save()
 assert(report.saved==1 and __persisted.p1.hibernation=='SNAP:carried',
   'save persisted stale consumed/acquired items during unloaded checkpoint')
 assert(SAO.Body.active.p1==b and SAO.Body.unloaded.p1,
   'checkpoint changed live ownership during unloaded checkpoint')
end
do
 local r,b,a=__setup()
 r.hibernation='SNAP:consumed-apple' b.payload='acquired-key'
 r.bodyVisual='VIS:old-look' b.visual='dyed-current-look'
 b.x=310 b.y=311 b.z=1 __now=57
 -- Save captures current state even while an action owns the live body;
 -- checkpointing neither tears down nor serializes that action.
 ISTimedActionQueue.queues[b]={queue={{target=b}}}
 local report=__save()
 assert(report.saved==1 and report.failed==0 and report.skipped==0,'save checkpoint did not run')
 local saved=__persisted.p1
 assert(saved.hibernation=='SNAP:acquired-key','save persisted stale consumed/acquired items')
 assert(saved.bodyVisual=='VIS:dyed-current-look','save persisted stale appearance')
 assert(saved.x==310 and saved.y==311 and saved.z==1 and saved.releasedAtHours==57,
   'save position/time were stale')
 assert(saved.woundInfected and saved.knoxInfected and saved.biteDeathAtHours==65 and saved.hasRadio,
   'save omitted current body facts')
 assert(__captures==1 and __removed==0 and __spawned==0 and SAO.Body.active.p1==b
   and SAO.Controller.agents.p1==a and not r.bodyRelease,'checkpoint changed live ownership')
 assert(saved.bodyCheckpointFailure==nil and __events==1,'checkpoint infection or failure status wrong')
 __save() assert(__events==1,'checkpoint duplicated infection event')
 -- A full restart has the durable record and no off-slot native shell.
 __records=__persisted SAO.Body.active={} SAO.Controller.agents={} ISTimedActionQueue.queues={}
 local restored=SAO.Body.materialize(__records.p1)
 assert(restored and restored.payload=='acquired-key' and restored.elapsed==0,
   'saved person could not reconstruct current inventory')
 assert(restored.visual=='dyed-current-look','saved person could not reconstruct current appearance')
end
for _,mode in ipairs({'empty','throw','malformed','facts-throw','clock','position','bridge','visual-empty','visual-throw'}) do
 local r,b,a=__setup()
 r.bodyVisual='VIS:old-look'
 local bridge=SAOJavaBridge
 if mode=='clock' then __now=0/0
 elseif mode=='position' then b.x=math.huge
 elseif mode=='bridge' then SAOJavaBridge=nil
 else __mode=mode end
 local report=__save()
 SAOJavaBridge=bridge
 assert(report.failed==1 and report.saved==0,'capture failure reported faithful save: '..mode)
 assert(r.hibernation=='SNAP:previous' and r.x==190 and r.releasedAtHours==5
   and r.knoxInfected==nil and r.bodyVisual=='VIS:old-look','checkpoint failure changed last valid state')
 assert(__persisted.p1.bodyCheckpointFailure and report.failures.p1
   and table.concat(__logs,' '):find('current body state was not saved',1,true),
   'checkpoint failure was hidden')
 assert(SAO.Body.active.p1==b and SAO.Controller.agents.p1==a and __removed==0,
   'checkpoint failure relinquished body')
 __now=60 b.x=200 __mode='ok'
 report=__save()
 assert(report.saved==1 and not r.bodyCheckpointFailure,'checkpoint retry did not clear failure')
end
for _,kind in ipairs({'return','release','restore','discard','returning','dead','native-dead','foreign','not-shell'}) do
 local r,b,a=__setup()
 local isShell=SAOJavaBridge.isShell
 if kind=='return' then r.returnTransition={packed='SNAP:journal',sourceRemoved=true}
 elseif kind=='release' then r.bodyRelease={packed='SNAP:journal'}
 elseif kind=='restore' then SAO.Body.failedRestore.p1=true
 elseif kind=='discard' then SAO.Body.discarding.p1=true
 elseif kind=='returning' then SAO.Body.returning.p1=b
 elseif kind=='dead' then r.dead=true
 elseif kind=='native-dead' then b.nativeDead=true
 elseif kind=='foreign' then SAO.Body.foreign.p1=b
 else SAOJavaBridge.isShell=function() return false end end
 local journal=r.returnTransition or r.bodyRelease
 local report=__save()
 assert(report.skipped==1 and report.saved==0 and report.failed==0 and __captures==0,
   'checkpoint captured excluded owner: '..kind)
 assert(r.hibernation=='SNAP:previous' and (r.returnTransition or r.bodyRelease)==journal,
   'checkpoint overwrote transition capture')
 assert(SAO.Body.active.p1==b and SAO.Controller.agents.p1==a,'excluded owner changed')
 SAOJavaBridge.isShell=isShell SAO.Body.returning={}
end
do
 local r=__setup() __mode='throw' __save() __mode='ok'
 __records=__persisted SAO.Body.active={} SAO.Controller.agents={}
 local body,reason=SAO.Body.materialize(__records.p1)
 assert(not body and reason=='checkpoint-state-unavailable' and __spawned==0,
   'failed checkpoint reconstructed stale possessions')
end
do
 local r=__setup() __mode='throw' __save() __mode='ok'
 assert(SAO.Body.release(r) and not r.bodyCheckpointFailure,
   'later validated release retained stale checkpoint failure')
end
do
 local r,b=__setup()
 local second={id='p2',hibernation='SNAP:old',releasedAtHours=3}
 __records.p2=second SAO.Body.active.p2=__body()
 local capture=SAOJavaBridge.hibernate
 SAOJavaBridge.hibernate=function(self,body)
  if body==b then error('one broken person') end return capture(self,body)
 end
 local report=__save()
 assert(report.saved==1 and report.failed==1 and second.hibernation=='SNAP:carried',
   'one checkpoint failure prevented other person save')
 SAOJavaBridge.hibernate=capture
end
do
 local r=__setup()
 local foreign=__body() SAO.Body.foreign.p2=foreign
 __records.p2={id='p2',hibernation='SNAP:foreign'}
 __save()
 assert(__captures==1 and __persisted.p2.hibernation=='SNAP:foreign','foreign body was checkpointed')
end
do
 local r,b=__setup()
 -- The bridge owns the chunk representation and native serialization. Lua
 -- must preserve its validated table payload as an opaque durable value.
 local capture,visual=SAOJavaBridge.hibernate,SAOJavaBridge.captureReturnVisual
 local valid,validVisual=SAOJavaBridge.validateHibernation,SAOJavaBridge.validateReturnVisual
 SAOJavaBridge.hibernate=function(self,body) return {opaque=capture(self,body)} end
 SAOJavaBridge.captureReturnVisual=function(self,body) return {opaque=visual(self,body)} end
 SAOJavaBridge.validateHibernation=function(self,value) return type(value)=='table' and valid(self,value.opaque) end
 SAOJavaBridge.validateReturnVisual=function(self,value) return type(value)=='table' and validVisual(self,value.opaque) end
 local report=__save()
 assert(report.saved==1 and __persisted.p1.hibernation.opaque=='SNAP:carried'
   and __persisted.p1.bodyVisual.opaque=='VIS:current-look','checkpoint refused durable table payload')
 SAOJavaBridge.hibernate,SAOJavaBridge.captureReturnVisual=capture,visual
 SAOJavaBridge.validateHibernation,SAOJavaBridge.validateReturnVisual=valid,validVisual
end
return 'PASS'
'''


def native_method(class_name, signature):
    result = subprocess.run([str(vm.JDK/'javap.exe'), '-c', '-p', '-classpath',
        str(vm.GAME/'projectzomboid.jar'), class_name], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr)
    lines = result.stdout.splitlines()
    start = next(i for i, line in enumerate(lines) if signature in line)
    end = next((i for i in range(start+1, len(lines))
        if re.match(r'^  (public|private|protected|static) ', lines[i])), len(lines))
    return '\n'.join(lines[start:end])


def engine_contract():
    save = native_method('zombie.GameWindow', 'public static void save(boolean)')
    offsets = lambda pattern: [int(match[0]) for match in
        re.findall(r'^\s*(\d+):.*(' + pattern + r').*$', save, re.M)]
    event = max(offsets('String OnSave'))
    cell = min(offsets('Method zombie/iso/IsoCell.save:'))
    durable = min(offsets('Method zombie/world/moddata/GlobalModData.save:'))
    assert event < cell < durable, 'OnSave no longer precedes native/global persistence'
    players = native_method('zombie.savefile.PlayerDB', 'private void savePlayersAsync()')
    square = native_method('zombie.iso.IsoGridSquare',
        'public void save(java.nio.ByteBuffer, java.io.ObjectOutputStream, boolean)')
    assert 'Field zombie/characters/IsoPlayer.players:' in players
    assert 'Field movingObjects:' not in square and 'class zombie/iso/objects/IsoDeadBody' in square
    print(f'ENGINE save order: OnSave {event} < IsoCell.save {cell} < GlobalModData.save {durable}')
    print('ENGINE destination boundary: PlayerDB saves player slots; square save excludes living movingObjects')


def main():
    if not all(path.is_file() for path in (vm.GAME/'projectzomboid.jar', vm.JDK/'javac.exe', vm.JDK/'javap.exe')):
        print('SKIPPED person checkpoint: installed engine/JDK absent'); return 0
    sources = {name: vm.source_path(name).read_text(encoding='utf-8')
        for name in vm.FILES}
    engine_contract()
    vm.PRELUDE += HOST
    vm.CASES = CASES
    controls = [
        ('Events.OnSave.Add(Body.onSaveCheckpoint)', '', 'save checkpoint callback missing or duplicated'),
        ('rec.hibernation = captured.packed', 'rec.hibernation = rec.hibernation',
         'save persisted stale consumed/acquired items'),
        ('rec.bodyVisual = captured.visual', 'rec.bodyVisual = rec.bodyVisual',
         'save persisted stale appearance'),
        ('rec.releasedAtHours = captured.hours', 'rec.releasedAtHours = rec.releasedAtHours',
         'save position/time were stale'),
        ('if SAOJavaBridge:validateHibernation(packed) ~= true then', 'if false then',
         'capture failure reported faithful save'),
        ('rec.bodyCheckpointFailure = { reason = reason,', 'rec.bodyCheckpointFailure = nil local unused = { reason = reason,',
         'checkpoint failure was hidden'),
        ('or hasTransitionJournal(rec) then', 'or false then', 'checkpoint captured excluded owner'),
        ('not rec or rec.dead or Body.foreign[id] or Body.returning[id]',
         'not rec or rec.dead or false or Body.returning[id]', 'checkpoint captured excluded owner'),
        ('SAO.BodySnapshot.commit(rec, captured)\n                report.saved = report.saved + 1\n                local facts',
         'SAO.BodySnapshot.commit(rec, captured)\n                Body.active[id] = nil report.saved = report.saved + 1\n                local facts',
         'checkpoint changed live ownership'),
        ('if rec.bodyCheckpointFailure then return nil, "checkpoint-state-unavailable" end', '',
         'failed checkpoint reconstructed stale possessions'),
        ('if SAOJavaBridge:validateHibernation(packed) ~= true then',
         'if type(packed) ~= "string" or SAOJavaBridge:validateHibernation(packed) ~= true then',
         'checkpoint refused durable table payload'),
    ]
    faults=[]
    with tempfile.TemporaryDirectory(prefix='sao-person-checkpoint-') as tmp:
        work=Path(tmp); shutil.copy2(vm.GAME/'stdlib.lua',work/'stdlib.lua')
        built=subprocess.run([str(vm.JDK/'javac.exe'),'-cp',str(vm.GAME/'projectzomboid.jar'),'-d',str(work),
            str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=60)
        if built.returncode: raise RuntimeError(built.stderr)
        result=vm.run(work,sources); print('production: '+result)
        if result!='VALUE PASS': faults.append('production')
        for before,after,reason in controls:
            candidates = [name for name in ('SAO_Body.lua', 'SAO_BodySnapshot.lua')
                          if before in sources[name]]
            if len(candidates) != 1 or sources[candidates[0]].count(before) != 1:
                faults.append('control seam '+reason); continue
            name = candidates[0]
            changed=dict(sources); changed[name]=changed[name].replace(before,after,1)
            result=vm.run(work,changed)
            rejected=result.startswith('ERROR ') and reason in result
            print('CONTROL '+reason+': '+('REJECTED ' if rejected else 'SURVIVED ')+result)
            if not rejected: faults.append(reason)
    print('FAULT '+', '.join(faults) if faults else "  166) PASS -- person save checkpoint")
    return bool(faults)


if __name__=='__main__':
    try: sys.exit(main())
    except (OSError, RuntimeError, AssertionError, StopIteration, subprocess.TimeoutExpired) as error:
        print('FAULT person checkpoint: '+str(error)); sys.exit(1)
