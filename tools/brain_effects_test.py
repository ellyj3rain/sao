#!/usr/bin/env python3
"""Border 175: event-derived brain load changes shipped survivor behavior."""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get(
    "PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get(
    "JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
ZAO = ROOT.parent / "zombie-awareness"
FILES = {
    "state": ZAO / "mod/42.20/media/lua/shared/ZAO_StateStore.lua",
    "brain": ZAO / "mod/42.20/media/lua/shared/ZAO_Brain.lua",
    "neuro": ROOT / "mod/42.20/media/lua/shared/SAO_Neuro.lua",
    "conditions": ROOT / "mod/42.20/media/lua/shared/SAO_Conditions.lua",
    "pressure": ROOT / "mod/42.20/media/lua/shared/SAO_Pressure.lua",
    "locomotion": ROOT / "mod/42.20/media/lua/client/SAO_Locomotion.lua",
    "controller": ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua",
}

HOST = r'''
local durable, records, now = {}, {}, 0
ModData = { getOrCreate = function(key)
    durable[key] = durable[key] or {}
    return durable[key]
end }
Events = setmetatable({}, { __index = function()
    return { Add = function() end, Remove = function() end }
end })
SandboxVars = {
    Rain = 0, Temperature = 1,
    SurvivorAwareness = { Neuroinflammation = true },
}
getSpecificPlayer = function() return nil end
getGameTime = function() return { getMinutesStamp = function() return 0 end } end
SAO = {
    Log = { line = function() end },
    History = {
        countyHours = function() return now end,
        ageOf = function() return 34 end,
    },
    Hash = { of = function() return 9999 end },
    Identity = { get = function(id) return records[tostring(id)] end },
    Habits = { withdrawalPhase = function() return 0 end },
    Disposition = { decisionInterval = function() return 100 end },
    Perception = { nearestBelievedZombie = function() return nil end },
    Course = {},
}
ZAO = {}
SAOJavaBridge = {
    paced = 0, walking = 0,
    moveToPaced = function(self)
        self.paced = self.paced + 1
        return "MOVE_STARTED paced"
    end,
    moveTo = function(self)
        self.walking = self.walking + 1
        return "MOVE_STARTED walking"
    end,
}
function __record(id, values)
    values = values or {}
    values.id = id
    records[id] = values
    return values
end
function __store() return ZAO.StateStore.store() end
'''

PROBE = r'''(function()
    local clean = __record("clean", { immuneProgress = 0.20 })
    local affected = __record("affected", { immuneProgress = 0.20 })
    __store().people.affected = { terminalState = "crossed" }
    SAO.Neuro.observe(affected, 0, "crossed")
    assert(SAO.Neuro.loadOf(affected) >= 0.90,
        "fixture did not produce event-derived brain load")

    SAO.Conditions.asserted.clean = {}
    SAO.Conditions.asserted.affected = {}
    local cleanMemory = SAO.Conditions.memoryFactor("clean", "people")
    local affectedMemory = SAO.Conditions.memoryFactor("affected", "people")
    assert(cleanMemory == 1 and affectedMemory < cleanMemory,
        "brain history did not reduce actual memory retention")

    local cleanDecision = __decisionIntervalFor("clean")
    local affectedDecision = __decisionIntervalFor("affected")
    assert(cleanDecision == 100 and affectedDecision > cleanDecision,
        "brain history did not lengthen actual decision cadence")

    local cleanPressure = SAO.Pressure.total("clean", 0, 0, 0)
    local affectedPressure = SAO.Pressure.total("affected", 0, 0, 0)
    assert(math.abs(cleanPressure - 0.20) < 0.000001
        and affectedPressure > cleanPressure,
        "brain history did not amplify existing pressure")

    local cleanBody, affectedBody = {}, {}
    assert(SAO.Locomotion.order("clean", cleanBody, 1, 1, 0, true))
    assert(SAO.Locomotion.order("affected", affectedBody, 2, 2, 0, true))
    assert(SAOJavaBridge.paced == 1 and SAOJavaBridge.walking == 1,
        "motor impairment did not remove sprint pace from the selected route")
    return "brain effects hold"
end)()'''


def run(work: Path, sources: dict[str, str]) -> subprocess.CompletedProcess[str]:
    chunks = [str(work / "host.lua")]
    for name in FILES:
        source = sources[name]
        if name == "controller":
            source = source.replace(
                "\nreturn Ctl\n",
                "\n__decisionIntervalFor = decisionIntervalFor\nreturn Ctl\n",
                1,
            )
        path = work / f"{name}.lua"
        path.write_text(source, encoding="utf-8")
        chunks.append(str(path))
    return subprocess.run(
        [str(JDK / "java.exe"), "-cp",
         f"{GAME / 'projectzomboid.jar'}{os.pathsep}{work}", "LuaRun",
         *chunks, "--", PROBE], cwd=work,
        capture_output=True, text=True, timeout=60)


def main() -> int:
    required = [GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                JDK / "java.exe", JDK / "javac.exe", RUNNER, *FILES.values()]
    if not all(path.is_file() for path in required):
        print("Border 175 SKIPPED: installed game VM, JDK, or paired ZAO branch absent")
        return 0
    sources = {name: path.read_text(encoding="utf-8-sig")
               for name, path in FILES.items()}
    if sources["controller"].count("\nreturn Ctl\n") != 1:
        print("REFUSED: controller instrumentation seam changed")
        return 1
    controls = [
        ("conditions", "factor = factor * math.max(0.2, clarity)",
         "factor = factor * 1.0", "memory retention"),
        ("controller",
         "interval = SAO.Neuro.decisionInterval(id, interval)",
         "interval = interval", "decision cadence"),
        ("pressure", "total = total * (1.0 + volatility * 0.50)",
         "total = total", "affective pressure"),
        ("locomotion", "SAO.Neuro.motorSteadiness(rec) < 0.60",
         "SAO.Neuro.motorSteadiness(rec) < -1.0", "motor pace"),
    ]
    for name, old, _, label in controls:
        if sources[name].count(old) != 1:
            print(f"REFUSED: {label} mutation seam changed")
            return 1

    with tempfile.TemporaryDirectory(prefix="sao-brain-effects-") as tmp:
        work = Path(tmp)
        shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
        (work / "host.lua").write_text(HOST, encoding="utf-8")
        built = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"),
             "-d", str(work), str(RUNNER)], cwd=work,
            capture_output=True, text=True, timeout=60)
        if built.returncode:
            print(built.stdout + built.stderr)
            return 1
        fixed = run(work, sources)
        if fixed.returncode or "VALUE brain effects hold" not in fixed.stdout:
            print("REFUSED: brain-effects production path failed\n"
                  + fixed.stdout + fixed.stderr)
            return 1
        for name, old, new, label in controls:
            changed = dict(sources)
            changed[name] = changed[name].replace(old, new, 1)
            mutant = run(work, changed)
            if mutant.returncode == 0:
                print(f"REFUSED: {label} mutation survived\n"
                      + mutant.stdout + mutant.stderr)
                return 1
    print("Border 175 PASS: one causal brain history changes shipped memory, decision cadence, pressure reactivity and motor pace; four controls fail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
