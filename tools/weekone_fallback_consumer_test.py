#!/usr/bin/env python3
"""Exercise the actual SAO Week One plan through the selected BWO consumer."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

PATCH = (ROOT.parent.parent / "mod-patches" /
         "patches/004-weekone-person-provenance/patch.lua")

PORTS = r'''
__target='none' __threat=0 __originalCalls=0 __randomFallbackCalls=0
BanditBrain={Get=function(body) return __currentBrain end}
BanditPrograms={FallbackAction=function()
 __randomFallbackCalls=__randomFallbackCalls+1 return {'random-bwo'} end}
ZombiePrograms={Survivor={Main=function(body)
 __originalCalls=__originalCalls+1
 return {status=true,next='Main',tasks={'source-main'}}
end}}
BanditUtils={GetMoveTask=function() return {action='Move'} end}
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local brain=__brain(701,'BanditsWeekOne')
brain.program.stage='Main'
local body=__body(701) __source=body __currentBrain=brain
local result=ZombiePrograms.Survivor.Main(body)
assert(result and result.status==true and result.next=='Main'
 and #result.tasks==1 and result.tasks[1].action=='Time'
 and result.tasks[1].anim=='ShiftWeight' and result.tasks[1].time==170
 and __observations==1 and __originalCalls==0 and __randomFallbackCalls==0,
 'actual SAO fallback did not become the selected native BWO Time task')
local person=body.md.SAOWeekOnePersonId
assert(person and __records[person].weekOne.decision.source=='sao-person-appraisal'
 and __records[person].weekOne.decision.anim=='ShiftWeight'
 and __records[person].weekOne.decision.duration==170,
 'selected fallback lost the exact person decision provenance')
local again=ZombiePrograms.Survivor.Main(body)
assert(again.tasks[1].action=='Time' and __observations==1
 and __originalCalls==0 and __randomFallbackCalls==0,
 'repeated source callback bypassed bounded private cognition')
local foreign=__brain(702,'Bandits2')
local foreignBody=__body(702) __currentBrain=foreign
local unchanged=ZombiePrograms.Survivor.Main(foreignBody)
assert(unchanged.tasks[1]=='source-main' and __originalCalls==1,
 'unqualified actor did not keep the normal source program')
__currentBrain=brain body.md.SAOWeekOnePersonId='other-person'
local mismatched=ZombiePrograms.Survivor.Main(body)
assert(mismatched.next=='Main' and #mismatched.tasks==0
 and __originalCalls==1,
 'conflicting source body marker ran an unowned source task')
return 'PASS'
'''

SOURCE_GUARD = ('source = "sao-person-appraisal", anim = anim',
    'source = "sao-observed", anim = anim')
PATCH_GUARD = ('plan.source == "sao-person-appraisal"',
    'plan.source == "sao-observed"')
SAO_GUARD = ('Survivor = { Main = true }',
    'Survivor = {}')


def main():
    if not all(path.is_file() for path in
               (SOURCE, PATCH, GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                JDK / "java.exe", JDK / "javac.exe")):
        raise SystemExit("missing installed Kahlua, SAO source, or selected BWO patch")
    sources = {SOURCE: SOURCE.read_text(encoding="utf-8"),
               PATCH: PATCH.read_text(encoding="utf-8")}
    receipt = {"saoSourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "selectedPatchPath": str(PATCH),
               "selectedPatchSha256": hashlib.sha256(PATCH.read_bytes()).hexdigest(),
               "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-consumer-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + PORTS, encoding="utf-8")
        (work / "cases.lua").write_text("function __cases()\n" + CASES
            + "\nend\nfunction __safe() local ok,value=pcall(__cases)"
            + " if ok then return value end return 'FAIL:'..tostring(value) end",
            encoding="utf-8")

        def run(name, sao_source, patch_source):
            (work / "sao.lua").write_text(sao_source, encoding="utf-8")
            (work / "selected-patch.lua").write_text(patch_source, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "sao.lua"),
                str(work / "selected-patch.lua"), str(work / "cases.lua"),
                "--", "__safe()"], cwd=work, capture_output=True, text=True,
                timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                "output": output[-1200:]})
            return done.returncode, output

        code, output = run("actual-sao-and-selected-bwo", sources[SOURCE], sources[PATCH])
        if code or "VALUE PASS" not in output:
            raise RuntimeError("combined production failed: " + output)
        for name, source_guard, patch_guard, expected in [
            ("plan-source-inverse", SOURCE_GUARD, None,
                "VALUE FAIL:actual SAO fallback did not become"),
            ("patch-guard-covered-by-owned-stage", None, PATCH_GUARD,
                "VALUE PASS"),
            ("owned-stage-mismatch-inverse", SAO_GUARD, None,
                "VALUE FAIL:conflicting source body marker ran an unowned source task"),
            ("both-consumer-guards-inverse", SAO_GUARD, PATCH_GUARD,
                "VALUE FAIL:actual SAO fallback did not become"),
        ]:
            sao_source, patch_source = sources[SOURCE], sources[PATCH]
            if source_guard:
                before, after = source_guard
                if before not in sao_source:
                    raise RuntimeError("missing SAO target " + name)
                sao_source = sao_source.replace(before, after, 1)
            if patch_guard:
                before, after = patch_guard
                if before not in patch_source:
                    raise RuntimeError("missing patch target " + name)
                patch_source = patch_source.replace(before, after, 1)
            code, output = run(name, sao_source, patch_source)
            if code or expected not in output:
                raise RuntimeError(name + " had wrong combined verdict: " + output)
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/actual-fallback-consumer.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("PASS actual SAO Week One fallback, dual-consumer recovery, and 2 inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
