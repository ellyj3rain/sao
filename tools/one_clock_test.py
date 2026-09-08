#!/usr/bin/env python3
r"""Border 130 - one clock for how long this has been going on ([C61]).

Three things in this tree answer "how far into the collapse is this
save", and until now one of them answered from a different source.

  `SAORecord.daysBehindAtStart`  the record's calendar   [C45]
  `SAORecord.recordDayToday`     the record's calendar   [C42]
  `SAO_History.clockMonths`      SandboxVars.TimeSinceApo

[C42] ruled that whether the fall has come is derived from the
county's own stamps and the record's calendar "and never from the
sandbox dial". `clockMonths` is what ages every person's KNOWLEDGE -
the split clock turns it into contact months, and the lesson pool and
the claims a person carries are drawn from that - and it was still
reading the dial. A 1996 save runs about a thousand days of county
forward ([C45]) and then told every survivor in it they were one
month in, because the dial's default is one.

Checked in the engine's own VM (tools/luacheck/LuaRun) with the real
SAO_History loaded and the bridge stubbed, over the cases that decide
it:

  * a save a thousand record-days in reads about thirty-three months,
    whatever the dial says;
  * the dial is not consulted at all while the calendar answers - the
    same record day gives the same months with the dial at 1 and at
    60;
  * before the fall the answer is zero, because a county that has not
    had its outbreak has nobody who has lived through one;
  * with no bridge at all the dial still answers, so this module stays
    offline by construction and the mirrors that load it in a bare VM
    read what they always read;
  * the sentinel the bridge returns when the clock cannot be read
    (-90000 and below) falls through to the dial rather than being
    taken as a date before the fall.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree answers off the dial and the
record day changes nothing.
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
HASH = LUA / "shared" / "SAO_Hash.lua"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


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
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(PRELUDE), str(HASH), str(HISTORY), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


CLOCK = (
    "(function() local out = {} "
    "local function say(label, v) out[#out + 1] = label .. '=' "
    ".. string.format('%.2f', v) end "
    # the calendar answers, and the dial is not consulted
    "SandboxVars = { TimeSinceApo = 1 } "
    "GameTime = { getInstance = function() return { "
    "getWorldAgeHours = function() return 0 end } end } "
    "SAOJavaBridge = { recordDayToday = function() return 1000 end } "
    "say('deep_dial1', SAO.History.clockMonths()) "
    "SandboxVars.TimeSinceApo = 60 "
    "say('deep_dial60', SAO.History.clockMonths()) "
    # before the fall
    "SAOJavaBridge.recordDayToday = function() return -40 end "
    "say('before', SAO.History.clockMonths()) "
    # day zero itself
    "SAOJavaBridge.recordDayToday = function() return 0 end "
    "say('dayzero', SAO.History.clockMonths()) "
    # the unreadable sentinel falls through to the dial
    "SAOJavaBridge.recordDayToday = function() return -99999 end "
    "SandboxVars.TimeSinceApo = 7 "
    "say('sentinel_dial7', SAO.History.clockMonths()) "
    # no bridge at all: still the dial
    "SAOJavaBridge = nil "
    "say('nobridge_dial7', SAO.History.clockMonths()) "
    "return table.concat(out, ' ') end)()")


def main():
    faults = []
    print("=" * 74)
    print("ONE CLOCK FOR HOW LONG THIS HAS BEEN GOING ON")
    print("=" * 74)
    if not HISTORY.exists():
        print("  FAULT: SAO_History.lua does not exist")
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib or runner")
        print("  130) one clock: SKIPPED, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    got = numbers(value(probe(CLOCK)))
    print("     months: " + " ".join("%s=%s" % kv for kv in got.items()))
    want = {"deep_dial1": "33.33", "deep_dial60": "33.33",
            "before": "0.00", "dayzero": "0.00",
            "sentinel_dial7": "6.00", "nobridge_dial7": "6.00"}
    for k, v in want.items():
        if got.get(k) != v:
            faults.append("clockMonths: %s is %s, wanted %s"
                          % (k, got.get(k), v))
    if got.get("deep_dial1") != got.get("deep_dial60"):
        faults.append("the dial moved the answer while the calendar was "
                      "readable - the dial is not the county's clock")

    hist = read(HISTORY)
    seams = {
        # The CALL forms, not the names. The first spelling compared
        # the position of "recordDayToday" against "TimeSinceApo" and
        # failed on this batch's own comment, which names the dial
        # while explaining why it is no longer asked first - the
        # "prose is not code" rule in GOVERNANCE.md, paid for again.
        "the calendar is asked first":
            "SAOJavaBridge:recordDayToday()" in hist
            and hist.index("SAOJavaBridge:recordDayToday()")
                < hist.index("tonumber(sv.TimeSinceApo)"),
        "the dial survives as the offline answer":
            "SandboxVars.TimeSinceApo" in hist or "sv.TimeSinceApo" in hist,
        "before the fall is zero, not a negative age":
            "if day < 0 then return 0 end" in hist,
        "the gate runs this border":
            "tools/one_clock_test.py" in read(CHECK),
    }
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
        return 1
    print("  130) one clock: what a person knows is aged off the record's own "
          "calendar, the dial answering only where the calendar cannot be read")
    return 0


if __name__ == "__main__":
    sys.exit(main())
