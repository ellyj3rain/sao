#!/usr/bin/env python3
r"""Border 133 - the years pass leaves a trajectory ([C65]).

[C45] lives the days a later save owes and writes nothing down. It
mutates state in place, so the county at the end answers "what is this
county like now" and destroys "what happened" - which is the thing the
operator's chosen model is fitted to. The only lines that reached the
telemetry file during a span of years were the incidental death and
lesson events, with no run boundary around them and nothing about what
the county held.

Three things were missing and all three are checked here.

A RUN BOUNDARY. The file is append-only across every session on this
machine, so without one the lines from three different counties
interleave into a single stream that reads like one county behaving
impossibly. Every line carries its run while a run is open, and none
does outside one, which is what live play is.

WHAT THE RUN WAS RUN UNDER. Two runs with identical population curves
can have had opposite risk settings, and none of the sandbox dials is
recoverable from the county lines afterwards.

WHAT THE COUNTY HELD. The county line counted living, dead, lessons and
units. It declared `dry` and `hungry` and never assigned or emitted
them, so it said nothing about need - the pressure that drives most of
what the county does - and nothing about groups, claims, or how shut
the places are, which are the outcomes the years are run to produce.

Checked in the engine's own VM (tools/luacheck/LuaRun) against the real
SAO_Telemetry, with `getFileWriter` stubbed to capture what is written.
The assertions are made against the actual JSONL the module emits, not
against its source.

And by text: the years pass writes a line per simulated day, opens the
run once rather than per pass, and clears the identifier when the span
ends.

An optional argv[1] points the checker at another tree root, which is
how its control runs: on the pre-batch tree the county line carries
none of those fields and no line carries a run.
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
TELEM = LUA / "client" / "SAO_Telemetry.lua"
POP = LUA / "client" / "SAO_Population.lua"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# A county with known properties, and a file writer that keeps what it
# is handed instead of writing it. Day 20 in the county's own clock.
#
#   p1  living, group h1, claim, 5 days dry,  7 ways in, 3 shut
#   p2  living, group h1, claim, drank today, 9 days hungry, 5 ways in
#   p3  living, group h2, no claim, fed and watered today
#   p4  dead
PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
SAO.History = {
    countyHours = function() return 20 * 24.0 end,
    daysOwed = function() return 1096 end,
}
local COUNTY = {
    p1 = { id = "p1", lastWaterDay = 15, lastFoodDay = 20,
           waysIntoHome = 7, boardedAtHome = 3,
           lessonsKnown = { a = 1, b = 1 }, unitId = "u1" },
    p2 = { id = "p2", lastWaterDay = 20, lastFoodDay = 11,
           waysIntoHome = 5, boardedAtHome = 0,
           lessonsKnown = { a = 1 } },
    p3 = { id = "p3", lastWaterDay = 20, lastFoodDay = 20,
           lessonsKnown = {} },
    p4 = { id = "p4", dead = true },
}
SAO.Identity = {
    all = function() return COUNTY end,
    get = function(id) return COUNTY[id] end,
}
local GROUP = { p1 = "h1", p2 = "h1", p3 = "h2" }
local CLAIM = { p1 = true, p2 = true }
SAO.Standing = {
    groupOf = function(id) return GROUP[id] end,
    claimOf = function(id) return CLAIM[id] and { minX = 0 } or nil end,
}
SandboxVars = { SurvivorAwareness = {
    Telemetry = true, DormantRisk = 1.5, TrustToCompany = 0.4,
    Desperation = 3, RefillDays = 30, RoadTraffic = 2,
    PopulationGoverned = true, Population = 216,
    NewcomersGoverned = false, Newcomers = 0, DayZero = false,
} }
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return 0 end,
    getStartYear = function() return 1996 end,
    getStartMonth = function() return 6 end,
    getStartDay = function() return 8 end } end }
getGameTime = function() return GameTime.getInstance() end
ZombRand = function(n) return 7 end
getTimestampMs = function() return 1234 end
getSpecificPlayer = function() return nil end
_G.__written = {}
getFileWriter = function(name, append, create)
    return {
        write = function(self, line) _G.__written[#_G.__written + 1] = line end,
        close = function(self) end,
    }
end
'''


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(TELEM), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def lines_of(expr):
    """The JSONL the module actually wrote, parsed."""
    said = value(probe(expr))
    if not said:
        return []
    out = []
    for chunk in said.split("\x1f"):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            out.append(json.loads(chunk))
        except ValueError:
            pass
    return out


# Everything the module writes, joined by a separator no JSON value has.
DRAIN = ("local out = {} "
         "for _, l in ipairs(_G.__written) do "
         "out[#out + 1] = (string.gsub(l, '\\r\\n', '')) end "
         "return table.concat(out, string.char(31))")

COUNTY = "(function() SAO.Telemetry.county() " + DRAIN + " end)()"

RUN = ("(function() SAO.Telemetry.runId = 'r-1' "
       "local c = SAO.Telemetry.conditions() c.run = 'r-1' c.owed = 1096 "
       "SAO.Telemetry.run('opened', c) "
       "SAO.Telemetry.county() "
       "SAO.Telemetry.runId = nil "
       "SAO.Telemetry.county() SAO.Telemetry.flush() "
       + DRAIN + " end)()")


def main():
    faults = []
    print("=" * 74)
    print("THE YEARS PASS LEAVES A TRAJECTORY")
    print("=" * 74)
    for path in (TELEM, POP):
        if not path.exists():
            print("  FAULT: %s does not exist" % path.name)
            return 1

    telem, pop = read(TELEM), read(POP)
    seams = {
        "a run opens and closes":
            "function T.run(phase, fields)" in telem,
        "and carries what it was run under":
            "function T.conditions()" in telem
            and "dormantRisk" in telem and "daysOwed" in telem,
        "every line carries its run while one is open":
            "if T.runId then fields.run = T.runId end" in telem,
        "the years pass writes a line a day":
            "pcall(function() SAO.Telemetry.county() end)" in pop,
        "the run is made once, not once a pass":
            "if s.yearsRunId == nil then" in pop,
        "and cleared when the span ends":
            "SAO.Telemetry.runId = nil" in pop,
        "the gate runs this border":
            "tools/years_trajectory_test.py" in read(CHECK),
    }

    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print()
        for k, v in seams.items():
            print(f"  {'yes' if v else 'NO '}  {k}")
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  133) the years pass leaves a trajectory: TEXT ONLY, the "
              "engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # ------------------------------------------------------------------
    # The county line, read off what the module actually wrote.
    # ------------------------------------------------------------------
    said = lines_of(COUNTY)
    county = [r for r in said if r.get("kind") == "county"]
    print()
    if not county:
        print("     the county wrote nothing parseable: %r" % (said,))
        faults.append("SAO.Telemetry.county() emitted no county line")
    else:
        row = county[0]
        shown = {k: row[k] for k in sorted(row) if k not in ("kind",)}
        print("     county: " + " ".join("%s=%s" % kv for kv in shown.items()))
        want = {
            "living": 3, "dead": 1,
            "dry": 1, "dryDaysMax": 5,
            "hungry": 1, "hungryDaysMax": 9,
            "groups": 2, "grouped": 3, "largestGroup": 2,
            "claimsHeld": 2,
            "waysIn": 12, "waysShut": 3,
            "day": 20,
        }
        for k, v in want.items():
            got = row.get(k)
            if got is None:
                faults.append("the county line carries no %s - the years "
                              "produce it and nothing recorded it" % k)
            elif int(got) != v:
                faults.append("the county line says %s=%s, wanted %s"
                              % (k, got, v))

    # ------------------------------------------------------------------
    # The run boundary and its conditions.
    # ------------------------------------------------------------------
    said = lines_of(RUN)
    opened = [r for r in said if r.get("kind") == "run"]
    counties = [r for r in said if r.get("kind") == "county"]
    print("     lines written: %d (%d run, %d county)"
          % (len(said), len(opened), len(counties)))
    if not opened:
        faults.append("no run line was written, so a span of years has no "
                      "boundary and its lines interleave with every other "
                      "county's in the same file")
    else:
        row = opened[0]
        print("     run: " + " ".join(
            "%s=%s" % (k, row[k]) for k in sorted(row)
            if k in ("phase", "run", "owed", "dormantRisk", "population",
                     "startYear", "daysOwed")))
        if row.get("phase") != "opened":
            faults.append("the run line has phase %r" % row.get("phase"))
        for k, v in (("dormantRisk", 1.5), ("population", 216),
                     ("startYear", 1996), ("daysOwed", 1096),
                     ("owed", 1096)):
            got = row.get(k)
            if got is None or abs(float(got) - v) > 1e-9:
                faults.append("the run line says %s=%s, wanted %s - it is "
                              "not recoverable from the county lines"
                              % (k, got, v))

    if len(counties) >= 2:
        inside, outside = counties[0], counties[1]
        print("     run stamped inside=%r outside=%r"
              % (inside.get("run"), outside.get("run")))
        if inside.get("run") != "r-1":
            faults.append("a line written during a run carries run=%r"
                          % inside.get("run"))
        if "run" in outside:
            faults.append("a line written outside a run carries run=%r, so "
                          "live play would be filed under a span of years "
                          "that has ended" % outside.get("run"))
    else:
        faults.append("expected two county lines from the run probe, got %d"
                      % len(counties))

    print()
    for k, v in seams.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        print("  133) the years pass leaves a trajectory: FAIL")
        return 1
    print("  133) the years pass leaves a trajectory: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
