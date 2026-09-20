#!/usr/bin/env python3
"""Border 171: durable health cadence and frozen abstinence in Kahlua.

Runs the shipped Habits and Drugs modules in the installed game VM.  The
callback is driven at deliberately offset minute stamps, across skipped
intervals and day boundaries.  Person-record markers stand in for a save/load;
runtime callback locals are never accepted as completion evidence.
"""
from __future__ import annotations

from pathlib import Path
import os
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
HABITS = ROOT / "mod/42.20/media/lua/shared/SAO_Habits.lua"
DRUGS = ROOT / "mod/42.20/media/lua/client/SAO_Drugs.lua"

HOST = r'''
local records = {
    p1 = { id = "p1", habitsGained = { opioids = true },
        lastUseHours = { opioids = 0 }, drugDay = 0, drinksToday = 8 },
    legacy = { id = "legacy", drinksToday = 4 },
}
local nowHours, minuteStamp = 23.9, 100
local tenCalls, minuteCalls, refreshes = 0, 0, 0
local bodyData = { NnCMethadoneEffect = 1 }
local body = {
    getModData = function() return bodyData end,
    hasTrait = function(self, trait) return trait == NnCReg.OpioidAddict end,
}
SAO = {
    Hash = { of = function() return 9999 end },
    History = { countyHours = function() return nowHours end,
        ageOf = function() return 34 end },
    Identity = { get = function(id) return records[tostring(id)] end },
    Body = { active = { p1 = body }, isTransitioning = function() return false end },
    Controller = { tick = function() return 1 end },
    Population = { refreshBodyFacts = function(rec, seen, at)
        assert(rec == records.p1 and seen == body and at == nowHours)
        refreshes = refreshes + 1
    end },
    Neuro = { advance = function() end },
    Rand = { int = function() return 1 end },
    Log = { line = function() end },
}
Events = { OnTick = { Add = function(fn) SAO.__eventTick = fn end } }
function getGameTime() return { getMinutesStamp = function() return minuteStamp end } end
NnCReg = { OpioidAddict = {} }
BenzoAddict = function() tenCalls = tenCalls + 1 end
CokeHead = function() tenCalls = tenCalls + 1 end
MethHead = function() tenCalls = tenCalls + 1 end
MDMAAddict = function() tenCalls = tenCalls + 1 end
OpioidAddict = function() tenCalls = tenCalls + 1 end
PotHead = function() tenCalls = tenCalls + 1 end
SteroidAddict = function() tenCalls = tenCalls + 1 end
BenzoEffect = function() minuteCalls = minuteCalls + 1 end
CokeEffect = function() minuteCalls = minuteCalls + 1 end
MethEffect = function() minuteCalls = minuteCalls + 1 end
MDMAEffect = function() minuteCalls = minuteCalls + 1 end
OpioidEffect = function() minuteCalls = minuteCalls + 1 end
WeeeeedEffect = function() minuteCalls = minuteCalls + 1 end
SteroidEffect = function() minuteCalls = minuteCalls + 1 end
NnCPainRemoval = function() minuteCalls = minuteCalls + 1 end
function __setClock(minutes, hours) minuteStamp, nowHours = minutes, hours end
function __record(id) return records[id] end
function __bodyData() return bodyData end
function __counts() return tenCalls, minuteCalls, refreshes end
'''

PROBE = r'''(function()
    local tick = SAO.Drugs.__testTick
    local rec = __record("p1")
    tick() -- establish runtime offsets; no daily work is consumed
    assert(rec.drinksToday == 8 and rec.drinkTolerance == nil)

    __setClock(101, 24.01)
    tick() -- the one-minute callback crosses midnight first
    assert(rec.drinksToday == 8 and rec.drinkTolerance == nil,
        "one-minute callback consumed ten-minute daily work")

    __setClock(110, 24.16)
    tick()
    assert(rec.drinksToday == 0 and rec.drinkTolerance == 0.01,
        "ten-minute boundary did not close the drinking day")
    assert(rec.drugDay == 1)
    local ten, one, refresh = __counts()
    assert(ten == 7 and one == 80 and refresh == 1,
        "offset callback cadence changed")

    __setClock(140, 24.66)
    tick()
    ten, one, refresh = __counts()
    assert(ten == 28 and one == 320 and refresh == 2,
        "skipped callback intervals were sampled only once")
    assert(rec.drinkTolerance == 0.01,
        "durable daily marker repeated tolerance work")

    -- Frozen clean time is readable while the treatment remains active.
    local frozenAt = rec.useFrozen.opioids
    local cleanAtFreeze = SAO.Habits.cleanDays("p1", "opioids", frozenAt)
    assert(math.abs(SAO.Habits.cleanDays("p1", "opioids", 72) - cleanAtFreeze) < 0.000001,
        "active maintenance treatment advanced abstinence")
    __bodyData().NnCMethadoneEffect = 0
    __setClock(150, 96)
    tick()
    assert(rec.useFrozen.opioids == nil, "expired treatment stayed frozen")
    assert(math.abs(SAO.Habits.cleanDays("p1", "opioids", 96) - cleanAtFreeze) < 0.000001,
        "resume did not preserve the frozen interval")

    -- Legacy migration preserves an unknown current count.  Once grounded,
    -- a multi-day gap closes it once and durably records every boundary.
    local legacy = __record("legacy")
    assert(SAO.Drugs.completeThrough(legacy, 5) == 0 and legacy.drinksToday == 4)
    legacy.drinksToday = 8
    assert(SAO.Drugs.completeThrough(legacy, 8) == 3)
    assert(legacy.drinkTolerance == 0.01 and legacy.drinksToday == 0
        and legacy.drugDay == 8)
    assert(SAO.Drugs.completeThrough(legacy, 8) == 0
        and legacy.drinkTolerance == 0.01,
        "reload-equivalent repeat duplicated completed daily work")
    return "health clocks hold"
end)()'''


def run(drugs_source: str) -> subprocess.CompletedProcess[str]:
    jar, stdlib = GAME / "projectzomboid.jar", GAME / "stdlib.lua"
    with tempfile.TemporaryDirectory(prefix="sao-health-clock-") as tmp:
        work = Path(tmp)
        shutil.copy2(stdlib, work / "stdlib.lua")
        (work / "host.lua").write_text(HOST, encoding="utf-8")
        (work / "drugs.lua").write_text(drugs_source, encoding="utf-8")
        compiled = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", str(jar), "-d", str(work), str(RUNNER)],
            cwd=work, capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            return compiled
        return subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{jar}{os.pathsep}{work}", "LuaRun",
             str(work / "host.lua"), str(HABITS), str(work / "drugs.lua"), "--", PROBE],
            cwd=work, capture_output=True, text=True, timeout=60)


def main() -> int:
    required = [GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                JDK / "java.exe", JDK / "javac.exe", RUNNER, HABITS, DRUGS]
    if not all(path.is_file() for path in required):
        print("Border 171 SKIPPED: installed game VM or JDK absent")
        return 0
    source = DRUGS.read_text(encoding="utf-8-sig")
    seam = "return Dg\n"
    if source.count(seam) != 1:
        print("REFUSED: drug callback test seam changed")
        return 1
    instrumented = source.replace(seam, "Dg.__testTick = onTick\nreturn Dg\n")
    fixed = run(instrumented)
    if fixed.returncode or "VALUE health clocks hold" not in fixed.stdout:
        print("REFUSED: health clock production path failed\n" + fixed.stdout + fixed.stderr)
        return 1

    controls = [
        ("daily-before-ten-minute",
         "if tenPasses > 0 then\n                -- Their ten-minute pass",
         "if onePasses > 0 then\n                -- Their ten-minute pass",
         "one-minute callback consumed ten-minute daily work"),
        ("sample-skipped-intervals",
         "for _ = 1, tenPasses do\n                    for _, step in ipairs(NNC_TEN)",
         "for _ = 1, 1 do\n                    for _, step in ipairs(NNC_TEN)",
         "skipped callback intervals were sampled only once"),
    ]
    habits_source = HABITS.read_text(encoding="utf-8-sig")
    frozen_seam = 'if type(frozen) == "number" and frozen < now then now = frozen end'
    if habits_source.count(frozen_seam) != 1:
        print("REFUSED: frozen abstinence control seam changed")
        return 1
    # The callback controls mutate the actual module source.
    for name, old, new, failure in controls:
        if instrumented.count(old) != 1:
            print(f"REFUSED: {name} control seam changed")
            return 1
        result = run(instrumented.replace(old, new, 1))
        if result.returncode == 0:
            print(f"REFUSED: {name} control did not reproduce\n" + result.stdout + result.stderr)
            return 1
    # Frozen behavior is in the other shipped module; use a temporary copy.
    with tempfile.TemporaryDirectory(prefix="sao-health-frozen-control-") as tmp:
        changed = Path(tmp) / "SAO_Habits.lua"
        changed.write_text(habits_source.replace(frozen_seam, ""), encoding="utf-8")
        original = globals()["HABITS"]
        globals()["HABITS"] = changed
        try:
            result = run(instrumented)
        finally:
            globals()["HABITS"] = original
        if result.returncode == 0:
            print("REFUSED: frozen-abstinence control did not reproduce\n" + result.stdout + result.stderr)
            return 1
    print("Border 171 PASS: durable daily completion, offset and skipped callbacks, frozen reload state and treatment expiry; three controls fail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
