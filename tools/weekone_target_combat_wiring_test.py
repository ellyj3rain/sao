#!/usr/bin/env python3
"""Exercise the person decision to exact player attack task handoff."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE
from weekone_active_program_test import PORTS

FIXTURE = r'''
__target='person' __hostile=true __threat=2 __combatReady=true __combatCalls=0
SAO.Disposition.conflictValues=function(id)
 return {actorId=id,selfPreservation=.1,aggression=.9,nerve=.7,discipline=.7}
end
SAO.WeekOneTargetCombat={
 ready=function() return __combatReady end,
 authorizedTaskForObserved=function(brain,body,personId,name,tick)
  __combatCalls=__combatCalls+1
  assert(brain==__brains[body.id] and personId==body.md.SAOWeekOnePersonId
   and name=='Morgan Hill' and tick==__tick,
   'person combat received a different source person or sight frame')
  return {action='Smack',saoWeekOneTargetKey='player:Morgan Hill',eid=17}
 end}
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local paths={
 {'Active','Main',W.activeDecision},
 {'Walker','Main',function(brain,body)
   return W.ordinaryProgramStage(brain,body,'Walker','Main') end},
 {'ArmyGuard','Main',function(brain,body)
   return W.ownedProgramStage(brain,body,'ArmyGuard','Main') end},
}
for index,path in ipairs(paths) do
 __tick=300+index*25
 local brain,body=__actor(880+index,'BanditsWeekOne','Walker')
 brain.program={name=path[1],stage=path[2]}
 local result=path[3](brain,body)
 local phase=__records[body.md.SAOWeekOnePersonId].weekOne
 assert(result and result.status and result.tasks[1]
  and result.tasks[1].action=='Smack'
  and result.tasks[1].saoWeekOneTargetKey=='player:Morgan Hill'
  and phase.decision.kind=='attack' and phase.decision.attackMethod=='native-melee'
  and phase.decision.adapter==path[1]..'.'..path[2],
  'person attack task missing from '..path[1]..':'
   ..tostring(result and result.tasks[1] and result.tasks[1].action)..':'
   ..tostring(phase.decision.kind)..':'..tostring(phase.decision.adapter))
end
assert(__combatCalls==3,'one decision emitted duplicate or missing combat tasks')
__combatReady=false __tick=400
local closed,closedBody=__actor(890,'BanditsWeekOne','Walker')
closed.program={name='Walker',stage='Main'}
local moved=W.ordinaryProgramStage(closed,closedBody,'Walker','Main')
assert(moved and moved.tasks[1] and moved.tasks[1].action=='Move'
 and __combatCalls==3,'uninstalled physical gate emitted an attack')
__combatReady=true __hostile=false __tick=425
local neutral,neutralBody=__actor(891,'BanditsWeekOne','Walker')
neutral.program={name='Walker',stage='Main'}
local rested=W.ordinaryProgramStage(neutral,neutralBody,'Walker','Main')
assert(rested and rested.tasks[1] and rested.tasks[1].action=='Time'
 and __combatCalls==3,'nonhostile observed person emitted an attack')
return 'PASS'
'''

CONTROLS = [
    ("active-handoff", 'local attack = personCombatTask(brain, body, plan, phase)',
     'local attack = nil', 'person attack task missing from Active', 1),
    ("ordinary-handoff", 'local attack = personCombatTask(brain, body, plan, phase)',
     'local attack = nil', 'person attack task missing from Walker', 2),
    ("owned-handoff", 'local attack = personCombatTask(brain, body, plan, phase)',
     'local attack = nil', 'person attack task missing from ArmyGuard', 3),
    ("gate-readiness", 'and combat.ready() == true', 'and true',
     'uninstalled physical gate emitted an attack', 1),
    ("person-preference", 'phase.appraisal.preference == "continue"',
     'phase.appraisal.preference == "caution"',
     'person attack task missing from Active', 1),
]


def main() -> int:
    original = SOURCE.read_text(encoding="utf-8")
    receipt = {"sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "status": "OPEN", "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-combat-wiring-") as tmp:
        work = Path(tmp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        (work / "prelude.lua").write_text(PRELUDE + PORTS + FIXTURE,
                                           encoding="utf-8")
        (work / "cases.lua").write_text(
            "function __cases()\n" + CASES + "\nend\n"
            "function __safe() local ok,value=pcall(__cases) "
            "if ok then return value end return 'FAIL:'..tostring(value) end",
            encoding="utf-8")
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")], capture_output=True,
            text=True, timeout=120)
        if built.returncode:
            raise RuntimeError(built.stderr)

        def run(name: str, code: str) -> str:
            (work / "SAO_WeekOneContinuity.lua").write_text(code,
                                                        encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"),
                str(work / "SAO_WeekOneContinuity.lua"),
                str(work / "cases.lua"), "--", "__safe()"], cwd=work,
                capture_output=True, text=True, timeout=90)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                                     "output": output[-1600:]})
            return output

        production = run("production", original)
        if "VALUE PASS" not in production:
            raise RuntimeError("production W combat handoff failed: " + production)
        for name, before, after, expected, occurrence in CONTROLS:
            if original.count(before) < occurrence:
                raise RuntimeError("missing mutation anchor " + name)
            start = -1
            for _ in range(occurrence):
                start = original.index(before, start + 1)
            mutant = original[:start] + after + original[start + len(before):]
            output = run(name, mutant)
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"{name} failed incorrectly: {output}")
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/target-combat-wiring.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One combat decision wiring and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
