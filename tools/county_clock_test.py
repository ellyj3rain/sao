#!/usr/bin/env python3
r"""Border 131 - the county's clock moves while the years are lived ([C62]).

[C45] lives the days a later save owes before anybody is spawned. It
calls the county's own systems to do it, and the game clock does not
move while it runs, so every system that gates on a CHANGE of day saw
one day for the whole span:

  * attrition stamped `lastRiskDay` on the first simulated day and its
    `today > lastRiskDay` gate was false on every day after it;
  * `lastWaterDay` and `lastFoodDay` never advanced, so nobody grew
    thirsty and nobody went looking for water;
  * `driftStandings` returned on `s.lastDriftDay == day`, so no
    feeling aged after the first day;
  * the winter multiplier read GameTime's month, which stayed the
    save's start month for three simulated years;
  * `dormantLife` read GameTime's time of day, so a save begun at
    three in the morning sent everybody home for the whole span.

[C62] gives county replay one clock, in SAO_History beside [C61]'s.
Checked in the engine's own VM
(tools/luacheck/LuaRun) with the real SAO_History and SAO_Standing
loaded:

  * the clock is the day being lived while the years run, and the
    days this save began behind the record plus the game's own hours
    after them - the same number on both sides of the join, so a
    stamp made during the years stays in the past;
  * a save with no years behind it reads the game's own hours and
    nothing else;
  * `driftStandings` moves feelings on three simulated days running,
    which is the defect stated as a measurement;
  * the month is asked for the hour the county has reached, and the
    engine's own month answers where no record can;
  * a simulated day is at noon and the engine's own hour answers
    once the years are done.

The source boundary covers the replay producers SAO_Standing,
SAO_Population and SAO_DormantPopulation. Their elapsed time and month
come from SAO_History, and the years pass writes the day it is living
before it lives it. Native playback, lifecycle, presentation and
transport owners keep their source or engine timing.

An optional argv[1] points the checker at another tree root, which is
how its control runs: on the pre-batch tree the second day's drift is
zero and sixty-seven sites read the engine directly.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from lua_read import strip_lua

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
HISTORY = LUA / "shared" / "SAO_History.lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
POP = LUA / "client" / "SAO_Population.lua"
DORMANT = LUA / "client" / "SAO_DormantPopulation.lua"
COUNTY_MODELS = (STANDING, POP, DORMANT)
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# Standing is a large module with engine reads at load; the probe gives
# it the little it needs. The bridge answers with what the caller asked
# for, so the checks below are about what the Lua hands it.
PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
SAO.Identity = { get = function() return nil end, all = function() return {} end }
SAO.Hash = { of = function() return 0 end, unit = function() return 0.5 end }
SAO.Disposition = { traits = function() return {} end }
SAO.Lessons = { has = function() return false end, weight = function() return 0 end }
ModData = { getOrCreate = function(k) _G.__md = _G.__md or {} ; _G.__md[k] = _G.__md[k] or {} ; return _G.__md[k] end }
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return _G.__hours or 0 end,
    getMonth = function() return _G.__month or 6 end } end }
getGameTime = function() return GameTime.getInstance() end
ZombRand = function(n) return 0 end
SAOJavaBridge = {
    daysBehindAtStart = function() return _G.__behind or 0 end,
    recordDayToday = function() return -100000 end,
    countyMonth = function(self, h) _G.__askedWith = h return 3 end,
}
'''

# One shared store, set to a county partway through the years it owes.
def years(run, owed=1000):
    return ("local s = ModData.getOrCreate('SurvivorAwareness_Standing') "
            "s.yearsAsked = true s.yearsOwed = %d s.yearsRun = %d "
            % (owed, run))


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr, history_path=HISTORY):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(history_path), str(STANDING), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# ---------------------------------------------------------------------------
# What the clock reads. Only the new tree has one, so this is reported
# and not the border's control - the drift below is.
# ---------------------------------------------------------------------------
CLOCK = (
    "(function() local out = {} "
    "local function say(l, v) out[#out + 1] = l .. '=' .. "
    "string.format('%.1f', tonumber(v) or -1) end "
    "_G.__behind = 1000 _G.__hours = 0 "
    + years(1) +
    "say('day1', SAO.History.countyHours()) "
    "s.yearsRun = 500 say('day500', SAO.History.countyHours()) "
    "s.yearsRun = 999 say('day999', SAO.History.countyHours()) "
    # the years are done: the game's own hours carry on from where
    # they stopped rather than dropping back to zero
    "s.yearsRun = 1000 say('done', SAO.History.countyHours()) "
    "_G.__hours = 48 say('done_plus2', SAO.History.countyHours()) "
    "return table.concat(out, ' ') end)()")

# A save that owes nothing reads the game's own hours and nothing else.
NOYEARS = (
    "(function() _G.__behind = 0 _G.__hours = 137 "
    "return 'plain=' .. string.format('%.1f', SAO.History.countyHours()) end)()")

# ---------------------------------------------------------------------------
# THE CONTROL. Only the years store moves; the game clock is held at a
# hundred thousand hours so BOTH trees soften on the first call and the
# difference is isolated to the days after it.
# ---------------------------------------------------------------------------
DRIFT = (
    "(function() _G.__hours = 100000 _G.__behind = 1000 "
    + years(100) +
    "s.relations = { a = { b = { trust = 0.5, atHours = 0 } }, "
    "c = { d = { trust = 0.5, atHours = 0 } } } "
    "local out = {} "
    "out[#out + 1] = 'first=' .. tostring(SAO.Standing.driftStandings()) "
    "s.yearsRun = 101 "
    "out[#out + 1] = 'second=' .. tostring(SAO.Standing.driftStandings()) "
    "s.yearsRun = 102 "
    "out[#out + 1] = 'third=' .. tostring(SAO.Standing.driftStandings()) "
    "return table.concat(out, ' ') end)()")

# The hour of day, which is the same defect with a different answer:
# catch-up now carries every hour, including nights. The engine clock
# resumes after the historical span has finished.
CLOCKFACE = (
    "(function() _G.__behind = 1000 _G.__hours = 0 "
    "GameTime.getInstance = function() return { "
    "getWorldAgeHours = function() return _G.__hours or 0 end, "
    "getMonth = function() return _G.__month or 6 end, "
    "getTimeOfDay = function() return 3.0 end } end "
    + years(400) +
    "s.yearsTicks = 400 * 216000 + 13 * 9000 "
    "local function o(v) return string.format('%.1f', tonumber(v) or -1) end "
    "local during = o(SAO.History.countyTimeOfDay()) "
    "s.yearsRun = 1000 "
    "local after = o(SAO.History.countyTimeOfDay()) "
    "return 'during=' .. during .. ' after=' .. after end)()")

# The years pass advances from midnight. Native world age starts at 07:00,
# so a replay interval can cross two different civil-hour mappings at the
# saved years-owed join without changing any persisted county-hour stamp.
CIVIL_REPLAY = (
    "(function() _G.__behind = 10 _G.__hours = 2 _G.__civil = 9 "
    "GameTime.getInstance = function() return { "
    "getWorldAgeHours = function() return _G.__hours end, "
    "getTimeOfDay = function() return _G.__civil end } end "
    + years(10, 10) +
    "local H = SAO.History local out = {} "
    "local function say(name, at) local h, join = H.civilTimeAtCountyHours(at) "
    "out[#out + 1] = name .. '=' .. tostring(h) "
    "if join then out[#out + 1] = name .. 'join=' .. tostring(join) end end "
    "say('hist22', 22) say('hist239', 239) "
    "say('join240', 240) say('live241', 241) say('live242', 242) "
    "_G.__hours = 5 _G.__civil = 12 say('noon', 245) "
    "_G.__hours = 6 _G.__civil = 13 say('onepm', 246) "
    "_G.__civil = nil say('missinglive', 246) say('historywithoutlive', 239) "
    "s.yearsRun = 9 s.yearsTicks = 240 * 9000 "
    "say('lastcatchuptick', 240) "
    "s.yearsOwed = 10.5 say('invalidowed', 239) "
    "return table.concat(out, ' ') end)()")

# The record month follows the historical midnight phase and the native
# civil phase. A missing record during replay cannot borrow the static
# native month; once native play owns the clock, its month is a valid fallback.
MONTH = (
    "(function() _G.__hours = 0 _G.__behind = 1000 _G.__month = 6 _G.__civil = 9 "
    "GameTime.getInstance = function() return { "
    "getWorldAgeHours = function() return _G.__hours end, "
    "getMonth = function() return _G.__month end, "
    "getTimeOfDay = function() return _G.__civil end } end "
    + years(400) +
    "local m = SAO.History.countyMonth() "
    "local asked = _G.__askedWith "
    "local bridge = SAOJavaBridge "
    "SAOJavaBridge = nil "
    "local replayMissing = SAO.History.countyMonth() "
    "SAOJavaBridge = bridge s.yearsRun = 1000 _G.__hours = 15 _G.__civil = 0 "
    "local live = SAO.History.countyMonth() local liveAsked = _G.__askedWith "
    "SAOJavaBridge = nil "
    "local fallback = SAO.History.countyMonth() "
    "return 'month=' .. tostring(m) .. ' asked=' .. tostring(asked) "
    ".. ' replayMissing=' .. tostring(replayMissing) "
    ".. ' live=' .. tostring(live) .. ' liveAsked=' .. tostring(liveAsked) "
    ".. ' fallback=' .. tostring(fallback) end)()")


def county_clock_reads(paths=COUNTY_MODELS):
    """County replay producers use History; native owners retain engine time."""
    hours, months = [], []
    for path in paths:
        body = strip_lua(read(path))
        if re.search(r"\bgetWorldAgeHours\s*\(", body):
            hours.append(path)
        if re.search(r"\bgetMonth\s*\(", body):
            months.append(path)
    return hours, months


def main():
    faults = []
    print("=" * 74)
    print("THE COUNTY'S CLOCK MOVES WHILE THE YEARS ARE LIVED")
    print("=" * 74)
    for path in (HISTORY, STANDING, POP, DORMANT, SRC):
        if not path.is_file():
            print("  FAULT: %s does not exist" % path.name)
            return 1

    hist = read(HISTORY)
    pop = read(POP)
    dormant = read(DORMANT)

    # ------------------------------------------------------------------
    # By text: replay producers read History, and the years pass publishes
    # the day it is living before it lives it.
    # ------------------------------------------------------------------
    hour_paths, month_paths = county_clock_reads()
    stray_hours = [path.relative_to(LUA).as_posix() for path in hour_paths]
    stray_month = [path.relative_to(LUA).as_posix() for path in month_paths]

    print("  county replay producers reading the engine clock: %d" % len(stray_hours))
    for name in stray_hours[:6]:
        print("      " + name)
    if len(stray_hours) > 6:
        print("      and %d more" % (len(stray_hours) - 6))
    print("  county replay producers reading the engine month: %d" % len(stray_month))
    for name in stray_month[:6]:
        print("      " + name)

    seams = {
        "county replay producers use History for elapsed time":
            not stray_hours,
        "county replay producers use History for the month":
            not stray_month,
        "the county's clock exists":
            "function H.countyHours()" in hist,
        "and the county's month with it":
            "function H.countyMonth()" in hist,
        "how long this has been going on reads the same source":
            "local day = H.recordDay()" in hist,
        "the county has an hour of day too":
            "function H.countyTimeOfDay()" in hist,
        "the dormant day asks the county for it":
            "SAO.History.countyTimeOfDay()" in dormant
            and "getTimeOfDay" not in dormant,
        "a clock that cannot be reached is said out loud":
            "THE COUNTY HAS NO CLOCK" in pop
            and "clockAnswers()" in pop
            and 'SAO.Seams.wentDark("county-clock"' in pop,
        "the years pass writes elapsed ticks before it lives them":
            re.search(r"s\.yearsTicks = ticks[\s\S]*?oneYearsStep\(conf, run, run > priorDay\)", pop) is not None,
        "the gate runs this border":
            "tools/county_clock_test.py" in read(CHECK),
    }

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()):
        print("  SKIPPED the VM - no JDK, engine jar or stdlib")
        print()
        for k, v in seams.items():
            print(f"  {'yes' if v else 'NO '}  {k}")
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  131) the county's clock: TEXT ONLY, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # ------------------------------------------------------------------
    # In the VM.
    # ------------------------------------------------------------------
    clock = numbers(value(probe(CLOCK)))
    print()
    print("     the clock: " + " ".join("%s=%s" % kv for kv in clock.items()))
    want = {"day1": "24.0", "day500": "12000.0", "day999": "23976.0",
            "done": "24000.0", "done_plus2": "24048.0"}
    for k, v in want.items():
        if clock.get(k) != v:
            faults.append("the clock: %s is %s, wanted %s"
                          % (k, clock.get(k), v))
    # The join is what a stamp made during the years depends on.
    if clock.get("day999") and clock.get("done"):
        if float(clock["done"]) < float(clock["day999"]):
            faults.append("the clock went backwards when the years ended")

    plain = numbers(value(probe(NOYEARS)))
    print("     no years owed: " + " ".join("%s=%s" % kv for kv in plain.items()))
    if plain.get("plain") != "137.0":
        faults.append("a save with no years behind it reads %s, wanted the "
                      "game's own 137.0" % plain.get("plain"))

    drift = numbers(value(probe(DRIFT)))
    print("     feelings aged, three simulated days running: "
          + " ".join("%s=%s" % kv for kv in drift.items()))
    for day in ("first", "second", "third"):
        got = drift.get(day)
        if got is None or not got.isdigit() or int(got) <= 0:
            faults.append("driftStandings moved %s feelings on the %s day"
                          % (got, day))

    month = numbers(value(probe(MONTH)))
    print("     the month: " + " ".join("%s=%s" % kv for kv in month.items()))
    if month.get("asked") != "9600":
        faults.append("the month was asked for hour %s, wanted the county's "
                      "own 9600" % month.get("asked"))
    if month.get("month") != "3":
        faults.append("the record's month was not taken: %s" % month.get("month"))
    if month.get("replayMissing") != "nil":
        faults.append("historical replay used a native month after its record failed: %s"
                      % month.get("replayMissing"))
    if month.get("liveAsked") != "24024":
        faults.append("native midnight asked for county hour %s, wanted 24024"
                      % month.get("liveAsked"))
    if month.get("fallback") != "6":
        faults.append("in native play the engine's own month must answer, "
                      "not %s" % month.get("fallback"))

    face = numbers(value(probe(CLOCKFACE)))
    print("     the hour of day: "
          + " ".join("%s=%s" % kv for kv in face.items()))
    if face.get("during") != "13.0":
        faults.append("the elapsed clock is at %s o'clock, wanted 13"
                      % face.get("during"))
    if face.get("after") != "3.0":
        faults.append("after the years the engine's own hour must answer, "
                      "not %s" % face.get("after"))

    civil = numbers(value(probe(CIVIL_REPLAY)))
    print("     civil-hour replay: "
          + " ".join("%s=%s" % kv for kv in civil.items()))
    expected_civil = {
        "hist22": "22", "hist22join": "240", "hist239": "23",
        "hist239join": "240", "join240": "7", "live241": "8",
        "live242": "9", "noon": "12", "onepm": "13",
        "missinglive": "nil", "historywithoutlive": "23",
        "historywithoutlivejoin": "240", "lastcatchuptick": "0",
        "invalidowed": "nil",
    }
    for key, wanted in expected_civil.items():
        if civil.get(key) != wanted:
            faults.append(f"civil replay {key}={civil.get(key)}, wanted {wanted}")

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
        print("  131) the county's clock: FAIL")
        return 1
    print("  131) the county's clock moves while the years are lived: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
