#!/usr/bin/env python3
r"""Border 132 - a save the record is moved onto owes no years ([C63]).

DR-036 has two halves and they were deciding the same fact separately.

  * `SAORecord.shiftTo` moves the record's own first day onto a 1993
    save's start when the day-zero switch is on, so the outbreak
    arrives `leadIn()` days into that save ([C43]).
  * `SAORecord.daysBehindAtStart` counted the calendar days from the
    record's day 0 to the save's start and knew nothing about the
    switch, so a July 20 start reported 11, an October 1 start 84 and
    a December 15 start 159 ([C45]).

`[C45]`'s years pass took the second number and lived that many days
of collapse before anybody was spawned. A player who asked to watch
the county before its outbreak got a hundred and fifty-nine days of
it having already happened, handed to them with a record saying the
outbreak was eight days away.

`daysBehindAtStart` takes the switch now and asks `mayShift` - the
same refusal `shiftTo` makes - so the two halves cannot disagree about
which saves the record moves onto. A 1996 start still owes its
thousand with the switch on, because `mayShift` refuses any year but
the record's own.

Checked in the engine's own VM (tools/luacheck/LuaRun) with the real
SAO_History loaded and the bridge stubbed to the rule the Java
implements:

  * a December 15 1993 start with the switch ON owes nothing, so the
    county's clock begins at hour zero;
  * the same start with the switch OFF owes its 159 days;
  * a 1996 start owes its 1096 with the switch either way;
  * the flag the bridge is handed is the sandbox switch itself, not a
    copy of it that could drift.

And by text: `SAO_History` is the only module in the Lua tree that
asks the bridge for the days owed, the years pass goes through it, and
the switch it reads is the one `SAO_Record.placeTimeline` reads.

The Java arithmetic under this is Border 110's, which gained the
day-zero cases with this batch.

An optional argv[1] points the checker at another tree root, which is
how its control runs: on the pre-batch tree the bridge is asked
without the switch, so a December 15 day-zero start reads 3816 hours -
a hundred and fifty-nine days it should not owe.
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
HISTORY = LUA / "shared" / "SAO_History.lua"
POP = LUA / "client" / "SAO_Population.lua"
RECORD_LUA = LUA / "server" / "SAO_Record.lua"
RECORD = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAORecord.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The bridge stub is the rule the Java implements, spelled once: a save
# the record MAY be moved onto, whose player asked for that, owes
# nothing; otherwise the calendar days from the record's day 0. The
# flag it receives is recorded, because whether the Lua hands it over
# at all is what this border is about.
PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
SAO.Hash = { of = function() return 0 end, unit = function() return 0.5 end }
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return 0 end,
    getMonth = function() return 6 end,
    getTimeOfDay = function() return 12.0 end } end }
getGameTime = function() return GameTime.getInstance() end
ZombRand = function(n) return 0 end
SandboxVars = { SurvivorAwareness = { DayZero = false } }
SAOJavaBridge = {
    daysBehindAtStart = function(self, asked)
        _G.__handed = asked
        if asked == true and _G.__mayShift == true then return 0 end
        return _G.__calendarDays or 0
    end,
    recordDayToday = function() return -100000 end,
    countyMonth = function(self, h, asked) _G.__monthAsked = asked return 6 end,
}
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
             str(prelude), str(HISTORY), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# A save the county's clock is read on, with the switch either way.
# `countyHours` is what both trees have, so the control reads a number
# rather than an absence.
def case(may_shift, calendar_days, switch):
    return (
        "(function() _G.__mayShift = %s _G.__calendarDays = %d "
        "SandboxVars.SurvivorAwareness.DayZero = %s "
        "local h = SAO.History.countyHours() "
        "return 'hours=' .. string.format('%%.1f', tonumber(h) or -1) "
        ".. ' handed=' .. tostring(_G.__handed) end)()"
        % ("true" if may_shift else "false", calendar_days,
           "true" if switch else "false"))


def main():
    faults = []
    print("=" * 74)
    print("A SAVE THE RECORD IS MOVED ONTO OWES NO YEARS")
    print("=" * 74)
    for path in (HISTORY, POP, RECORD, BRIDGE):
        if not path.exists():
            print("  FAULT: %s does not exist" % path.name)
            return 1

    hist, pop, record, bridge = (read(HISTORY), read(POP), read(RECORD),
                                 read(BRIDGE))
    record_lua = read(RECORD_LUA)

    # Who else asks the bridge for this number.
    askers = []
    for path in sorted(LUA.rglob("*.lua")):
        if path.name == "SAO_History.lua":
            continue
        if "daysBehindAtStart" in read(path):
            askers.append(path.relative_to(LUA).as_posix())

    seams = {
        "the days owed have one reader":
            "function H.daysOwed()" in hist and not askers,
        "and it hands the bridge the switch":
            "SAOJavaBridge:daysBehindAtStart(dayZeroAsked())" in hist,
        "the switch is the one the timeline reads":
            "sv.DayZero == true" in hist and "sv.DayZero == true" in record_lua,
        "the years pass goes through that reader":
            "SAO.History.daysOwed()" in pop,
        "the record asks the same refusal the shift asks":
            "dayZeroAsked && mayShift(" in record,
        "the bridge takes the switch and decides nothing":
            "public int daysBehindAtStart(boolean dayZeroAsked)" in bridge
            and "SAORecord.daysBehindAtStart(dayZeroAsked)" in bridge,
        "the month anchors on the same number":
            "int behind = com.sao.engine.SAORecord.daysBehindAtStart(dayZeroAsked)"
            in bridge,
        "the gate runs this border":
            "tools/day_zero_owes_test.py" in read(CHECK),
    }
    if askers:
        print("  modules asking the bridge for the days owed themselves:")
        for name in askers:
            print("      " + name)

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
        print("  132) a save the record is moved onto: TEXT ONLY, the engine"
              " install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # December 15, 1993: a 1993 start the record may be moved onto, a
    # hundred and fifty-nine calendar days past the record's day 0.
    print()
    on = numbers(value(probe(case(True, 159, True))))
    off = numbers(value(probe(case(True, 159, False))))
    print("     December 15 1993, day zero ON:  "
          + " ".join("%s=%s" % kv for kv in on.items()))
    print("     December 15 1993, day zero OFF: "
          + " ".join("%s=%s" % kv for kv in off.items()))
    if on.get("hours") != "0.0":
        faults.append("a day-zero start owes %s hours; the record's own first "
                      "day is moved onto it, so it owes nothing"
                      % on.get("hours"))
    if off.get("hours") != "3816.0":
        faults.append("the same start on the shipped timeline owes %s hours, "
                      "wanted its 3816" % off.get("hours"))
    if on.get("handed") != "true" or off.get("handed") != "false":
        faults.append("the bridge was handed %s and %s; it must be handed the "
                      "switch itself" % (on.get("handed"), off.get("handed")))

    # 1996: the record is never moved onto it, so the switch changes
    # nothing and it owes its thousand either way.
    later_on = numbers(value(probe(case(False, 1096, True))))
    later_off = numbers(value(probe(case(False, 1096, False))))
    print("     July 9 1996, day zero ON:       "
          + " ".join("%s=%s" % kv for kv in later_on.items()))
    print("     July 9 1996, day zero OFF:      "
          + " ".join("%s=%s" % kv for kv in later_off.items()))
    for label, got in (("on", later_on), ("off", later_off)):
        if got.get("hours") != "26304.0":
            faults.append("a 1996 start with the switch %s owes %s hours, "
                          "wanted its 26304 - the record is never moved onto "
                          "a year that is not its own"
                          % (label, got.get("hours")))

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
        print("  132) a save the record is moved onto: FAIL")
        return 1
    print("  132) a save the record is moved onto owes no years: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
