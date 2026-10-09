#!/usr/bin/env python3
"""Installed BWO Active.Main through the SAO Week One person adapter."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

ACTIVE = (Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600") /
          "3403180543/mods/BanditsWeekOne/42.20/media/lua/shared/"
          "ZombiePrograms/WeekOne/ZPActive.lua")
ACTIVE_SHA = "8ab864fafbe5d311d09960648a9b4536e8dc09d5a8bd822ca69d07eec9620579"

PORTS = r'''
ZombiePrograms={}
__brains={} __bodies={} __sourceTargetCalls=0 __setPrograms=0
BanditBrain={Get=function(body) return __brains[body.id] end}
BanditZombie.GetInstanceById=function(id) return __bodies[id] end
SandboxVars={Bandits={General_RunAway=true}}
BanditUtils={
 GetTarget=function(body,config)
  __sourceTargetCalls=__sourceTargetCalls+1
  return {dist=50},nil
 end,
 GetMoveTask=function(endurance,x,y,z,walkType,dist)
  return {action='Move',x=x,y=y,z=z,walkType=walkType,dist=dist}
 end}
Bandit={
 SetProgram=function(body,program)
  __setPrograms=__setPrograms+1
  if __failSetProgram then error('source-set-program-failed') end
  if __noChangeSetProgram then return end
  __brains[body.id].program={name=program,stage='Prepare'}
 end,
 GetCombatWalktype=function() return 'Run' end}
BanditPrograms={FallbackAction=function() return {{action='Time',anim='ShiftWeight',time=200}} end}
function __actor(id,origin,fallback)
 local brain=__brain(id,origin)
 brain.program={name='Active',stage='Main'}
 brain.programFallback=fallback
 local body=__body(id)
 __brains[id]=brain __bodies[id]=body
 return brain,body
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
assert(W.activeWrapped and ZombiePrograms.Active.Main==W.activeWrapped,
 'installed Active.Main did not receive its exact SAO adapter')
local brain,body=__actor(701,'BanditsWeekOne','Walker')
ZombiePrograms.Walker={Main=function() return 'walker' end}
local moved=ZombiePrograms.Active.Main(body)
assert(moved and moved.status and moved.next=='Main' and #moved.tasks==1
 and moved.tasks[1].action=='Move' and moved.tasks[1].x==82
 and __sourceTargetCalls==0 and __setPrograms==0,
 'stamped Active person did not choose a current native observed move')
local person=body.md.SAOWeekOnePersonId
assert(person and __records[person].weekOne.decision.adapter=='Active.Main'
 and __records[person].weekOne.sourceFallbackProgram=='Walker',
 'Active decision or original source fallback was not pinned to the person')
__tick=121 __target='none' __threat=0
local resumed=ZombiePrograms.Active.Main(body)
assert(resumed and resumed.status and #resumed.tasks==0
 and brain.program.name=='Walker' and __setPrograms==1
 and __records[person].weekOne.decision.kind=='resume-program'
 and __records[person].weekOne.decision.program=='Walker'
 and __sourceTargetCalls==0,
 'fresh private no-enemy sight did not resume the exact original program')
__tick=150
local retryBrain,retryBody=__actor(703,'BanditsWeekOne','Postal')
local noProgram=ZombiePrograms.Active.Main(retryBody)
local retryPerson=retryBody.md.SAOWeekOnePersonId
assert(noProgram.tasks[1].action=='Time' and __setPrograms==1
 and __records[retryPerson].weekOne.decision.resumeRefusal=='source-fallback-unavailable',
 'unloaded source program resumed without a durable refusal')
ZombiePrograms.Postal={Main=function() return 'postal' end}
__tick=151
local cached=ZombiePrograms.Active.Main(retryBody)
assert(cached and cached.tasks[1] and cached.tasks[1].action=='Time' and __setPrograms==1,
 'cached no-enemy sight resumed a source program without a current scan')
__tick=171
local retried=ZombiePrograms.Active.Main(retryBody)
assert(#retried.tasks==0 and retryBrain.program.name=='Postal' and __setPrograms==2,
 'available source program was not retried after a fresh private scan')
__tick=190
local changedBrain,changedBody=__actor(705,'BanditsWeekOne','Walker')
local changedPerson=W.observeBrain(changedBrain,changedBody)
changedBrain.programFallback='Postal'
__tick=201
local changed=ZombiePrograms.Active.Main(changedBody)
assert(changed and changed.tasks[1] and changed.tasks[1].action=='Time' and __setPrograms==2
 and __records[changedPerson].weekOne.decision.resumeRefusal=='source-fallback-changed',
 'mutated original source fallback displaced the person decision')
__tick=230
local stuckBrain,stuckBody=__actor(707,'BanditsWeekOne','Walker')
__noChangeSetProgram=true
local unchanged=ZombiePrograms.Active.Main(stuckBody)
local stuckPerson=stuckBody.md.SAOWeekOnePersonId
assert(unchanged.tasks[1] and unchanged.tasks[1].action=='Time'
 and stuckBrain.program.name=='Active'
 and __records[stuckPerson].weekOne.decision.resumeRefusal=='source-program-transition-failed',
 'source program call with no state transition was accepted as a resume')
__noChangeSetProgram=false __tick=251
local successful=ZombiePrograms.Active.Main(stuckBody)
assert(#successful.tasks==0 and stuckBrain.program.name=='Walker',
 'failed program transition did not retry on a fresh private scan')
__tick=300 __target='zombie' __threat=2
for id=720,723 do
 local b,z=__actor(id,'BanditsWeekOne','Walker')
 assert(ZombiePrograms.Active.Main(z).tasks[1].action=='Move',
  'shared private scanner did not admit a bounded active cohort')
end
local deferredBrain,deferredBody=__actor(724,'BanditsWeekOne','Walker')
local deferred=ZombiePrograms.Active.Main(deferredBody)
assert(deferred and deferred.next=='Main' and #deferred.tasks==0
 and __sourceTargetCalls==0
 and W.costMetrics().budgetDeferred>=1,
 'deferred stamped emergency ran the source escape')
__tick=301 W.onBudgetTick()
local admitted=ZombiePrograms.Active.Main(deferredBody)
assert(admitted.tasks[1].action=='Move' and __sourceTargetCalls==0,
 'deferred active person did not receive a FIFO private retry')
local foreign,foreignBody=__actor(727,'Bandits2','Walker')
local priorTarget,priorSet=__sourceTargetCalls,__setPrograms
local source=ZombiePrograms.Active.Main(foreignBody)
assert(source.next=='Main' and __sourceTargetCalls==priorTarget+1
 and __setPrograms==priorSet+1 and foreignBody.md.SAOWeekOnePersonId==nil,
 'foreign Active source did not execute exactly once')
local wrongBrain,wrongBody=__actor(728,'BanditsWeekOne','Walker')
__brains[729]=wrongBrain
local mismatched=ZombiePrograms.Active.Main(__body(729))
assert(mismatched.next=='Main' and #mismatched.tasks==0
 and __stores.SurvivorAwareness_WeekOneContinuity.lastActiveRefusal.reason=='source-or-body-mismatch',
 'mismatched stamped body ran source emergency after refusal')
local missingBrain,markedBody=__actor(730,'BanditsWeekOne','Walker')
assert(W.observeBrain(missingBrain,markedBody),
 'active body was not marked before lookup failure')
__brains[730]=nil
local missing=ZombiePrograms.Active.Main(markedBody)
assert(missing.next=='Main' and #missing.tasks==0
 and __sourceTargetCalls==priorTarget+1,
 'marked Active body ran source emergency after brain lookup failed')
return 'PASS'
'''

CONTROLS = [
    ("active-hook", 'W.activeWrapped = wrapped', 'W.activeWrapped = nil',
     'installed Active.Main did not receive its exact SAO adapter'),
    ("private-native-move", 'plan.kind == "move" and plan.source == "sao-observed"',
     'plan.kind == "move" and plan.source == "wrong-source"',
     'stamped Active person did not choose a current native observed move'),
    ("fresh-no-enemy", 'plan.reason == "no-private-enemy" and plan.observedAtTick == plan.atTick',
     'plan.reason == "no-private-enemy"',
     'cached no-enemy sight resumed a source program without a current scan'),
    ("original-program-pin", 'if brain.programFallback ~= program then return nil, "source-fallback-changed" end',
     'if false then return nil, "source-fallback-changed" end',
     'mutated original source fallback displaced the person decision'),
    ("program-transition-postcondition", 'if ok and type(brain.program) == "table"',
     'if ok or type(brain.program) == "table"',
     'source program call with no state transition was accepted as a resume'),
    ("deferred-source-fallback", 'if markedWeekOneActor(brain, body) then',
     'if false then',
     'deferred stamped emergency ran the source escape'),
]


def main():
    if not all(path.is_file() for path in
               (SOURCE, ACTIVE, GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                JDK / "java.exe", JDK / "javac.exe")):
        raise SystemExit("missing SAO source, exact installed Active source, or Kahlua")
    active_bytes = ACTIVE.read_bytes()
    active_hash = hashlib.sha256(active_bytes).hexdigest()
    if active_hash != ACTIVE_SHA:
        raise RuntimeError("installed BWO Active.Main source drifted: " + active_hash)
    sao_source = SOURCE.read_text(encoding="utf-8")
    receipt = {"saoSourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "installedActiveSource": str(ACTIVE),
               "installedActiveSha256": active_hash, "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-active-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + PORTS, encoding="utf-8")
        (work / "active.lua").write_bytes(active_bytes)
        (work / "cases.lua").write_text("function __cases()\n" + CASES
            + "\nend\nfunction __safe() local ok,value=pcall(__cases)"
            + " if ok then return value end return 'FAIL:'..tostring(value) end",
            encoding="utf-8")

        def run(name, source):
            (work / "sao.lua").write_text(source, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "active.lua"),
                str(work / "sao.lua"), str(work / "cases.lua"), "--", "__safe()"],
                cwd=work, capture_output=True, text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                "output": output[-1200:]})
            return done.returncode, output

        code, output = run("installed-active-with-sao-person", sao_source)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("production Active adapter failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in sao_source:
                raise RuntimeError("missing inverse target " + name)
            code, output = run(name, sao_source.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " did not trip its contract: " + output)
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/active-program.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS installed BWO Active.Main under SAO person adapter and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
