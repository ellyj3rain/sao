#!/usr/bin/env python3
r"""Border 153 - the tick is the county's clock ([C112]).

The old county ran its cadences on two clocks that were not clocks:
frame counts, which run at a different rate on every machine, and
calibrated jumps bolted on afterward (YEARS_TICKS_PER_DAY) to drag
them back in line. The operator's ruling (2026-09-12): a robust
system puts every timer on the county's own clock.

One law now: a tick is a 9000th of a county hour, and
`ticks = floor(countyHours * 9000)`. The corollaries this border
holds, measured rather than described:

  * ONE CLOCK, TWO READERS. The population reads History's ticks at its
    callback and every controller decision read refreshes from History,
    including historical substeps inside one callback. A host callback
    advances the fallback only when SAO_History cannot answer.
  * A CADENCE IS A STAMP PLUS A SPAN, NEVER A MODULO. The clock can
    skip values - fast-forward, a lag spike - and a modulo gate
    fires only when a multiple lands exactly. The skip proof below
    jumps a quarter county hour at a time in single steps (2250
    ticks; 2250 % 240 is 90) and the pass gate opens on every skip.
  * A STAMP OF ZERO READS AS LONG AGO, so a fresh record's cadences
    are due on their first pass, not a year away.
  * THE ONE PERSISTED FUTURE DUE-TIME IS DOMAIN-GUARDED: a walk
    scheduled further ahead than now + 3600 drops to now, so a
    foreign or corrupted stamp cannot freeze a walker forever.
    Foreign stamps drop on belief-store bind the same way.
  * THE VOICE KEEPS THE WALL CLOCK ([B49]): its cooldown is real
    seconds (`getTimestampMs`), and its pick is deterministic on the
    tick - `list[(tick % #list) + 1]` - so the same county hour
    hears the same line.
  * YEARS_TICKS_PER_DAY IS GONE: nothing calibrates the clock,
    because the clock is the thing being read.

The [C112] batch record closed with: "A border for this law belongs
to the end pass with the rest of the deferred verification; none was
written here, per the standing order." This is that border. The
arithmetic and the skip are MEASURED: the VM runs the shipped
dormant set behind the real sweep prelude and reads the stamps the
passes actually write.

An optional argv[1] points the checker at another tree root, which
is how its control runs.
"""
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
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
PRELUDE_FILE = ROOT / "tools" / "sweep" / "prelude.lua"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The dormant county's own module set - the clocks, the pass gate,
# the walk guard, the belief store, the voice. The same set Border
# 147 runs.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "shared/SAO_PhysicalFacts.lua",
    "client/SAO_PopulationAdmissions.lua", "client/SAO_PopulationRepresentation.lua",
    "client/SAO_DormantPopulation.lua",
    "client/SAO_Population.lua", "client/SAO_Voice.lua",
]

PROBE = r"""(function()
  -- The county's own arithmetic, measured as deltas on its clock.
  _G.__hours = 0
  local t0 = SAO.History.ticks()
  _G.__hours = 1.0
  local step = SAO.History.ticks() - t0
  _G.__hours = 1.0 + 1.0 / 90000.0
  local quant = SAO.History.ticks() - t0 - step
  _G.__hours = 2.0
  local twoHour = SAO.History.ticks() - t0

  -- The skip. Two people held at the meet range's boundary; the
  -- clock then jumps a quarter county hour at a time, each jump one
  -- step of 2250 ticks - a value no 240 modulo ever lands on,
  -- because 2250 % 240 is 90. A stamp-plus-span gate opens on every
  -- skip; the second skip's pass is the sweep that meets again (the
  -- first is the encounter rotation's cursor pass, [A16], which by
  -- design carries no outer records after a full sweep), and the
  -- meeting stamps on the county's own axis. Movement is pinned the
  -- way Border 147 pins it, renewed every call, because the county's
  -- own foreign-stamp drop resets a one-time far pin to now.
  local realTick = _G.__handlers.OnTick
  -- This probe starts after history has completed; its people are born
  -- today and it measures live skipped-clock handling.
  local population = ModData.getOrCreate("SurvivorAwareness_Standing")
  population.yearsAsked = true
  population.yearsOwed = _G.__owed or 1096
  population.yearsRun = population.yearsOwed
  population.yearsTicks = population.yearsOwed * 216000
  population.countySettled = true
  local function make(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    r.homeX, r.homeY, r.homeZ = x, y, 0
    -- Created into a county 1096 days deep means created TODAY; the
    -- day stamps keep the attrition pass from reading this person as
    -- three years dry. That pass is not what this border measures.
    local today = math.floor((SAO.History.countyHours() or 0) / 24.0)
    r.lastWaterDay, r.lastFoodDay, r.lastRiskDay = today, today, today
    return r
  end
  local function keyOf(r)
    return tostring(SAO.Identity.beliefKey(r))
  end
  local a = make(10500, 9000)
  local b = make(10503, 9000)
  local keyB = keyOf(b)
  local function hold()
    local due = (SAO.History.ticks() or 0) + 3600
    a.nextDormantMoveAt, b.nextDormantMoveAt = due, due
    a.x, a.y = 10500, 9000
    b.x, b.y = 10503, 9000
  end

  _G.__hours = 2.0001
  hold(); realTick()
  local ba = SAO.Perception.beliefs[a.id]
  local sawB = ba and ba.people[keyB] or nil
  local firstAt = sawB and sawB.at or -1
  _G.__hours = _G.__hours + 0.25
  hold(); realTick()
  _G.__hours = _G.__hours + 0.25
  hold(); realTick()
  ba = SAO.Perception.beliefs[a.id]
  sawB = ba and ba.people[keyB] or nil
  local secondAt = sawB and sawB.at or -1
  local now = SAO.History.ticks()

  return "step=" .. tostring(step)
    .. " quant=" .. tostring(quant)
    .. " twoHour=" .. tostring(twoHour)
    .. " firstSpan=" .. tostring(firstAt - t0)
    .. " secondSpan=" .. tostring(secondAt - t0)
    .. " jump=" .. tostring(secondAt - firstAt)
    .. " onAxis=" .. tostring(now == secondAt and 1 or 0)
end)()"""


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
        prelude.write_text(PRELUDE_FILE.read_text(encoding="utf-8"),
                           encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        args += [str(LUA / m) for m in MODULES]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-400:]
    return out[at + 6:].strip().split("\n")[0]


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:' ]+?)(?=\s\w+=|$)",
                                        line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    missing = [str(LUA / name) for name in MODULES if not (LUA / name).is_file()]
    if missing:
        print("  FAULT: required VM modules missing: " + ", ".join(missing))
        return 1
    faults = []
    print("=" * 74)
    print("THE TICK IS THE COUNTY'S CLOCK")
    print("=" * 74)

    history = read(LUA / "shared" / "SAO_History.lua")
    population = read(LUA / "client" / "SAO_Population.lua")
    dormant = read(LUA / "client" / "SAO_DormantPopulation.lua")
    controller = read(LUA / "client" / "SAO_Controller.lua")
    perception = read(LUA / "shared" / "SAO_Perception.lua")
    voice = read(LUA / "client" / "SAO_Voice.lua")

    seams = {
        "the arithmetic is named where the clock lives":
            "local TICKS_PER_HOUR = 9000" in history
            and "function H.ticksFromHours(hours)" in history
            and "return H.ticksFromHours(H.countyHours()) or 0" in history,
        "the controller reads the one clock at decision time":
            "local function refreshCountyTick()" in controller
            and re.search(r"function Ctl\.tick\(\)[\s\S]*?refreshCountyTick\(\)"
                          r"[\s\S]*?return tickCount", controller) is not None,
        "the population reads the same clock":
            'tickCounter = (okT and type(t) == "number") and t'
            in population,
        "only a missing clock advances the controller fallback":
            "if not refreshCountyTick() then tickCount = tickCount + 1 end"
            in controller
            and re.search(r"tickCounter\s*=\s*tickCounter\s*\+",
                          population) is None,
        "the pass gate is a stamp plus a span, never a modulo":
            "tickCounter - (lastPassAt or -TICK_INTERVAL) < TICK_INTERVAL"
            in population
            and "lastPassAt = tickCounter" in population,
        "the tally flush keeps a host stamp":
            "lastLogFlushHostTick" in controller
            and "hostTickCount - (lastLogFlushHostTick" in controller,
        "native corpse grace keeps host pacing":
            "CORPSE_GRACE_HOST_TICKS" in controller
            and "Ctl.settleCorpses(hostTickCount)" in controller,
        "the calibrated jump is gone":
            "YEARS_TICKS_PER_DAY" not in history + population,
        "the one persisted due-time is domain-guarded":
            "rec.nextDormantMoveAt > tickCounter + 3600" in dormant,
        "foreign stamps drop on belief-store bind":
            "dropForeignStamps" in perception,
        "the voice cooldown keeps the engine's wall clock":
            "getTimestampMs" in voice,
        "the voice pick is deterministic on the tick":
            "list[(tick % #list) + 1]" in voice,
        "the gate runs this border":
            "tools/tick_law_test.py" in read(CHECK),
    }

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print()
        for k, v in seams.items():
            print("  %s  %s" % ("yes" if v else "NO ", k))
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  153) the tick is the county's clock: TEXT ONLY, the "
              "engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     the arithmetic, then two quarter-hour skips:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    want = {
        "step": ("9000",
                 "one county hour advanced the tick by %s; a tick is a "
                 "9000th of a county hour"),
        "quant": ("0",
                  "a tenth of a tick past the hour read as %s; the clock "
                  "is floored, never rounded up"),
        "twoHour": ("18000",
                    "two county hours read as %s ticks; the arithmetic "
                    "is linear in the county's hours"),
        "firstSpan": ("18000",
                      "the first meeting stamped %s past the base; the "
                      "stamp must be the county's own arithmetic at "
                      "2.0001 hours"),
        "secondSpan": ("22500",
                       "the second meeting stamped %s past the base; the "
                       "stamp must be the county's own arithmetic at "
                       "2.5001 hours"),
        "jump": ("4500",
                 "the two quarter-hour skips spanned %s ticks between "
                 "the two stamps; no 240 modulo ever lands on either "
                 "skip (2250 % 240 is 90), and the meeting happened "
                 "anyway"),
        "onAxis": ("1",
                   "the clock read after the jump does not match the "
                   "meeting's own stamp; both readers are on the "
                   "county's axis or neither is"),
    }
    for key, (expected, story) in want.items():
        if got.get(key) != expected:
            faults.append(story.replace("%s", str(got.get(key))))

    print()
    for k, v in seams.items():
        print("  %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        print("  153) the tick is the county's clock: FAIL")
        return 1
    print("  153) floor(countyHours * 9000), current decision reads and "
          "population passes on one clock, stamp-plus-span cadences that "
          "fire on a skipped clock, native pacing kept on host time: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
