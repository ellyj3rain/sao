#!/usr/bin/env python3
r"""Border 140 - a day of walking is a day of walking ([C75], F-061).

The dormant walk stepped `math.min(4, len)` tiles per pass. A pass
means two different things in the two halves of the county: live,
`dormantLife` runs every 240 frames and the move gate opens every 1800
to 3600, so a game day holds hundreds of them; in the years, `[C45]`
advances the counter 3600 ticks per simulated day and calls the pass
once, so a day held exactly one. Four tiles.

Measured before it was changed: **1.8 tiles per person per simulated
day**, across a map fifteen thousand tiles wide with towns hundreds of
tiles apart. Three simulated years carried somebody under two
kilometres, and 179 of 287 people lived and died without meeting
anybody.

`[C45]` chose one move per simulated day deliberately and its record
says why - a day should advance the counter far enough to open each
frame-paced gate about once. What it never asked is what one move is
worth in ground. That is F-061 and this is the correction.

THE RULE IS A RATE, AND THE RATE IS NOT CHOSEN HERE.

`[C25]` ratified `Places.comfortHorizon` as the home neighbourhood,
reached by a day of ordinary living, and it derives from the engine's
own `getCellSizeInSquares`. So a day of walking reaches it, an hour
reaches a twenty-fourth of it, and a goal further off takes the days it
takes - nobody is capped and where they go is still need and knowledge
(DR-027). The pace of the age scales it, the same modifier `[C30]`
sets on a live body.

A real-world walking distance was tried first and abandoned: nothing
in the installed build establishes what a tile is in metres, and the
shipped map is not to a consistent scale - 1.28 to 2.71 metres per tile
across ten real town pairs (F-062).

THIS BORDER MEASURES THE GROUND COVERED, NOT THE FORMULA.

A border reading `comfortHorizon` out of the source would pass a tree
that computed it and stepped four tiles anyway. Everything below runs
the shipped module in the engine's own VM, moves the county's clock,
and reads the walker's position.

The properties:

  * A DAY OF CLOCK IS A DAY OF WALKING. One pass over 24 county hours
    covers the day's reach, not one pass's worth.
  * AN HOUR IS AN HOUR'S WORTH. The step is proportional to the time
    that passed, not a constant.
  * THE TWO HALVES AGREE. A day delivered in one pass and the same day
    delivered in many cover the same ground, which is the law that
    loaded and unloaded survivors are governed by the same rules
    ([B39], [B42]).
  * NOBODY OVERSHOOTS. A goal nearer than the day's reach is arrived
    at, not passed.
  * IDLE TIME IS SPENT, NOT BANKED. Somebody standing at their goal
    for a week does not cross the county in one stride when they are
    given a new one. Found in this batch's own first draft, which read
    the clock only when there was somewhere to walk.

An optional argv[1] points the checker at another tree root, which is
how its control runs.
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
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

# No map: `Places.around` finds nothing, the day goal falls to the
# wilderness drift, and the walker still walks. That is the point -
# what is measured here is the walking, not the choosing.
PRELUDE = r'''
SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
ModData = { getOrCreate = function(k) __md[k] = __md[k] or {} return __md[k] end }
getWorld = function() return {
    getWorld = function() return "BorderSave" end,
    getMetaGrid = function() return nil end } end
getCell = function() return {
    getCellSizeInSquares = function() return 300 end } end
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return _G.__hours end,
    getStartYear = function() return 1996 end,
    getStartMonth = function() return 6 end,
    getStartDay = function() return 8 end,
    getMonth = function() return 6 end,
    getDay = function() return 8 end,
    getYear = function() return 1996 end,
    getTimeOfDay = function() return 12.0 end,
    getHelicopterDay = function() return 7 end,
    getNightsSurvived = function()
        return math.floor((_G.__hours or 0) / 24) end,
    getCalender = function() return {
        getTimeInMillis = function() return 8640000000 end } end } end }
getGameTime = function() return GameTime.getInstance() end
getTimestampMs = function() _G.__ms = (_G.__ms or 0) + 1 return _G.__ms end
ZombRand = function(a, b) if b == nil then return 0 end return a end
getSpecificPlayer = function() return nil end
getSandboxOptions = function()
    return { getWaterShutModifier = function() return 30 end } end
getScriptManager = function() return { getItem = function() return nil end } end
mergeTable = function(...) return {} end
getFileWriter = function()
    return { write = function() end, close = function() end } end
Events = setmetatable({}, { __index = function(t, k)
    local slot = {
        Add = function(fn) _G.__handlers = _G.__handlers or {}
            _G.__handlers[k] = fn end,
        Remove = function() end }
    rawset(t, k, slot)
    return slot
end })
SandboxVars = { SurvivorAwareness = {
    Enable = true, Telemetry = false, TrustToCompany = 0.5,
    PopulationGoverned = true, Population = 2,
    NewcomersGoverned = true, Newcomers = 0,
    RoadTraffic = 0, RefillDays = 2.0, Desperation = 0.7,
    DormantRisk = 0, DayZero = false,
    MaterializeRadius = 45, HibernateRadius = 70,
}, ZombieLore = { Transmission = 1 } }
SAO.Body = { active = {}, get = function() return nil end }
SAOJavaBridge = {
    daysBehindAtStart = function() return 0 end,
    recordDayToday = function() return 0 end,
    countyMonth = function() return 5 end,
    surveyClaim = function() return "ways=6 boarded=0 rooms=4" end,
    listKnoxHumans = function() return "" end,
    isCombatPatchReady = function() return false end,
    forenameCount = function() return 0 end,
    surnameCount = function() return 0 end,
}
'''

# One walker, a goal a long way off, and the clock moved by hand.
PROBE = r'''(function()
  local tick = _G.__handlers.OnTick
  local reach = SAO.Places.comfortHorizon()

  local function walker(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    r.homeX, r.homeY, r.homeZ = x, y, 0
    r.lastWaterDay, r.lastFoodDay, r.lastRiskDay = 0, 0, 0
    return r
  end

  -- Pin the goal every pass so the chooser cannot move it: what is
  -- measured is the walking, not where they decided to go.
  -- One pass to set the walk stamp. A record the county has never
  -- looked at has no previous reading to measure from, so its first
  -- pass covers nothing - correctly, and exactly once in its life.
  -- Measuring that pass would be measuring the seeding.
  local function warm(r)
    _G.__hours = _G.__hours + 1
    r.dayGoalX, r.dayGoalY = r.x, r.y
    r.nextDormantMoveAt = 0
    for _ = 1, 240 do tick() end
  end

  local function march(r, gx, gy, hours, passes)
    local x0, y0 = r.x, r.y
    for i = 1, passes do
      _G.__hours = _G.__hours + (hours / passes)
      r.dayGoalX, r.dayGoalY = gx, gy
      r.dayGoalPlaceId, r.dayGoalPerson = nil, nil
      r.nextDormantMoveAt = 0
      for _ = 1, 240 do tick() end
    end
    local dx, dy = r.x - x0, r.y - y0
    return math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
  end

  -- A day of clock, delivered in ONE pass, and then the same day
  -- delivered in twenty-four - by the SAME walker. The pace of the age
  -- is drawn per person, so two walkers would be two paces and the
  -- comparison would pass or fail on which ids they happened to get
  -- rather than on whether a day is a day.
  local a = walker(10000, 9000)
  warm(a)
  local oneDay = march(a, 10000 + reach * 8, 9000, 24, 1)
  a.x, a.y = 10000, 9000
  local manyPasses = march(a, 10000 + reach * 8, 9000, 24, 24)

  -- An hour of clock.
  local c = walker(10000, 9000)
  warm(c)
  local oneHour = march(c, 10000 + reach * 8, 9000, 1, 1)

  -- A goal nearer than the day's reach: arrived at, not overshot.
  local d = walker(10000, 9000)
  warm(d)
  local near = math.floor(reach / 4)
  march(d, 10000 + near, 9000, 24, 1)
  local overshoot = math.abs(d.x - (10000 + near))

  -- Idle time is spent, not banked. Sit somebody ON their goal for a
  -- week of clock, then give them a distant one and let a single day
  -- pass: they get a day's walking, not a week's.
  local e = walker(10000, 9000)
  warm(e)
  march(e, 10000, 9000, 168, 7)
  local afterIdle = march(e, 10000 + reach * 8, 9000, 24, 1)

  return "reach=" .. reach
    .. " oneDay=" .. oneDay
    .. " manyPasses=" .. manyPasses
    .. " oneHour=" .. oneHour
    .. " overshoot=" .. overshoot
    .. " afterIdle=" .. afterIdle
end)()'''


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
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        args += [str(LUA / m) for m in MODULES if (LUA / m).exists()]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-400:]
    return out[at + 6:].strip().split("\n")[0]


def strip_prose(text):
    """Lua with its comments removed.

    The module that retired the constant step names it in the comment
    explaining why, so a bare search finds the very thing it is
    checking has gone. That is GOVERNANCE's prose-is-not-code clause,
    and this border hit it on its first run.
    """
    out = []
    for line in text.splitlines():
        cut = line.find("--")
        out.append(line if cut < 0 else line[:cut])
    return "\n".join(out)


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:']+)", line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("A DAY OF WALKING IS A DAY OF WALKING")
    print("=" * 74)

    pop = read(LUA / "client" / "SAO_Population.lua")
    seams = {
        "the step is a rate over the county's clock":
            "lastWalkHours" in pop,
        "the rate is the ratified day-reach, not a figure chosen here":
            "comfortHorizon()" in pop,
        "the pace of the age scales it":
            "speedModOf" in pop,
        "no constant tile step survives":
            re.search(r"math\.min\(\s*4\s*,\s*len\s*\)",
                      strip_prose(pop)) is None,
        "the gate runs this border":
            "tools/walk_rate_test.py" in read(CHECK),
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
        print("  140) a day of walking: TEXT ONLY, the engine install is "
              "absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     one walker, a goal eight neighbourhoods off, the clock "
          "moved by hand:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    try:
        reach = int(got.get("reach") or 0)
        one_day = int(got.get("oneDay") or 0)
        many = int(got.get("manyPasses") or 0)
        one_hour = int(got.get("oneHour") or 0)
        overshoot = int(got.get("overshoot") or 0)
    except ValueError:
        print("  FAULT: the probe did not return numbers")
        return 1

    if reach <= 0:
        faults.append("the county reports a day-reach of %s" % reach)
    # The pace of the age is drawn per person, so the day's ground is
    # reach x pace and pace lives in [0.65, 1.0]. A tenth of the reach
    # is far below any pace and far above the four tiles a pass used to
    # deliver, so it separates the two without pinning either.
    floor = max(1, int(reach * 0.10))
    if one_day < floor:
        faults.append(
            "a day of county clock carried somebody %d tiles against a "
            "day-reach of %d. That is the defect this border exists for: "
            "the step was a constant per PASS, and the years call the "
            "pass once per simulated day, so a day delivered four tiles "
            "and three years carried a person under two kilometres"
            % (one_day, reach))
    if one_hour >= one_day and one_day > 0:
        faults.append(
            "an hour of clock carried somebody %d tiles and a day carried "
            "%d. The step has to be proportional to the time that passed, "
            "or it is a constant wearing a rate's clothes"
            % (one_hour, one_day))
    # Same walker, same pace, so the two answers are the same
    # arithmetic delivered differently and a real gap is small.
    if one_day > 0 and abs(many - one_day) > max(2, one_day * 0.05):
        faults.append(
            "a day delivered in one pass covered %d tiles and the same day "
            "delivered in twenty-four passes covered %d. Loaded and "
            "unloaded survivors are governed by the same rules ([B39], "
            "[B42]), and a day is a day in both halves" % (one_day, many))
    after_idle = int(got.get("afterIdle") or 0)
    if one_day > 0 and after_idle > one_day * 1.6:
        faults.append(
            "somebody who stood at their goal for a week of clock then "
            "covered %d tiles in a single day, against %d for a day from "
            "rest. Idle time is spent, not banked - reading the clock "
            "only when there is somewhere to walk lets a person cross "
            "the county in one stride" % (after_idle, one_day))
    if overshoot > 3:
        faults.append(
            "a goal nearer than the day's reach was overshot by %d tiles. "
            "Walking further than the destination is not walking"
            % overshoot)

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
        print("  140) a day of walking is a day of walking: FAIL")
        return 1
    print("  140) a day of county clock carries a day's walking, an hour "
          "carries an hour's, and both halves of the county agree: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
