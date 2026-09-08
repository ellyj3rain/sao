#!/usr/bin/env python3
r"""Border 112 - the era remembered ([C38], Day Zero slice 6).

"Before" and "the day it started" are carried as lived claims: the
knowledge surface answers what a person was before the fall - the
year they were born, the war their life put them in, where they were
from, where home is from here, innocent or hardened - and the day it
started as they know it - their own first horror with its date and
what it taught, the county's own stamps aired as news, the record's
first day for anyone with a radio - every fact with its provenance
and, where the calendar answers, the county's date in a person's
words. The chronicle reads its days through the same calendar.

Driven in the engine's own VM (tools/luacheck/LuaRun) against Border
101's stub county with a history, a chronicle, a radio and a calendar
installed over it; then with no calendar, so the day count stands
alone; then with nothing learned, so innocence is said. By text: the
topics, the Standing accessor, the chronicle's one calendar, the
bridge, the record class and its check, the roadmap. An optional
argv[1] points the checker at another tree root, which is how its
control runs: the pre-batch tree faults at every seam.
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
K = LUA / "shared" / "SAO_Knowledge.lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
UI = LUA / "client" / "SAO_UI.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
RECORD = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAORecord.java"
RECORD_CHECK = ROOT / "tools" / "javacheck" / "RecordCheck.java"
ROADMAP = ROOT / "ROADMAP.md"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_knowledge.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The stub county, grown: p1 was a veteran from Muldraugh with a home
# to the north, born 1949, who learned their one lesson at hour 72;
# the county's stamps; a radio; a calendar on a July 1 start.
STUB = (
    "local g = SAO.Identity.get "
    "SAO.Identity.get = function(id) local r = g(id) if r and id == 'p1' then "
    "r.homeX = 40 r.homeY = 60 r.occupation = 'veteran' r.originRegion = 'Muldraugh' "
    "r.lessonMeta['keep-quiet'].atHours = 72 end return r end "
    "SAO.History = { birthYearOf = function(id) return 1949 end, "
    "servedIn = function(id, occ) if occ == 'veteran' then return 'Vietnam' end return nil end } "
    "SAO.Standing.chronicle = function() return { outbreakAtHours = 100, firstTurnedAtHours = 130, tapsDryAtHours = 200 } end "
    "SAO.Standing.ownsRadio = function(id) return true end "
    "SAO.Lessons.hasAny = function(id) return true end ")
CALENDAR = (
    "SAOJavaBridge = { countyDate = function(self, h) return 'July ' .. (1 + math.floor(h / 24)) .. ', 1993' end, "
    "recordDayZero = function(self) return 'July 9, 1993' end } ")


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
             str(PRELUDE), str(K), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=300)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.-]+)=([-\w./']+)", line or "")}


def facts(topic, prefix=""):
    return (
        "(function() " + STUB + prefix +
        "local f = SAO.Knowledge.about('p1', '%s') if not f then return 'none=true' end "
        "local out = {} for _, x in ipairs(f) do "
        "local v = x.year or x.war or x.region or x.whereWord or x.lessons or x.key or x.day or x.date or x.source "
        "local d = (x.date and x.fact ~= 'news') and ('/' .. tostring(x.date)) or (x.fact == 'mine' or x.fact == 'county' or x.fact == 'turned' or x.fact == 'taps') and '/nil' or '' "
        "local s = (x.fact == 'first') and ('/' .. tostring(x.source)) or '' "
        "out[#out + 1] = x.fact .. '=' .. (tostring(v) .. d .. s):gsub('[ ,]', '_') end "
        "return table.concat(out, ' ') end)()" % topic)


def main():
    faults = []
    print("=" * 74)
    print("THE ERA REMEMBERED")
    print("=" * 74)
    for path, what in ((K, "SAO_Knowledge.lua"), (STANDING, "SAO_Standing.lua"),
                       (UI, "SAO_UI.lua"), (BRIDGE, "SAOBridge.java"),
                       (RECORD, "SAORecord.java"), (RECORD_CHECK, "RecordCheck.java"),
                       (PRELUDE, "the probe")):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        # [C56] SKIPPED, not a finding. This border reads the installed
        # game, and a machine without it - CI, or anybody's clone - is
        # not a machine with a defect. A check that cannot run must
        # never look like a check that passed either, so it says so
        # twice and the gate prints it.
        print("  SKIPPED - no JDK, engine jar, stdlib or runner")
        print("  112) the era remembered: SKIPPED, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    before = numbers(value(probe(facts("before", CALENDAR))))
    print("     before: " + " ".join("%s=%s" % kv for kv in before.items()))
    for k, v in {"born": "1949", "war": "Vietnam", "from": "Muldraugh",
                 "home": "north_of_here", "hardened": "1"}.items():
        if before.get(k) != v:
            faults.append("before: %s is %s, wanted %s" % (k, before.get(k), v))
    if "innocent" in before:
        faults.append("before says innocent of a person who has learned")

    innocent = numbers(value(probe(facts(
        "before", CALENDAR + "SAO.Lessons.hasAny = function(id) return false end "))))
    print("     innocent: " + " ".join("%s=%s" % kv for kv in innocent.items()))
    if innocent.get("innocent") != "lived" or "hardened" in innocent:
        faults.append("a person who has learned nothing is not said to be innocent: %r"
                      % innocent)

    started = numbers(value(probe(facts("started", CALENDAR))))
    print("     started: " + " ".join("%s=%s" % kv for kv in started.items()))
    for k, v in {"mine": "3/July_4__1993", "first": "keep-quiet/lived",
                 "county": "4/July_5__1993", "turned": "5/July_6__1993",
                 "taps": "8/July_9__1993", "news": "July_9__1993"}.items():
        if started.get(k) != v:
            faults.append("started: %s is %s, wanted %s" % (k, started.get(k), v))

    bare = numbers(value(probe(facts("started"))))
    print("     no calendar: " + " ".join("%s=%s" % kv for kv in bare.items()))
    if bare.get("mine") != "3/nil" or bare.get("county") != "4/nil":
        faults.append("with no bridge the day count should stand alone: %r" % bare)
    if "news" in bare:
        faults.append("with no bridge the record's first day is still claimed")

    ktext, st, ui = read(K), read(STANDING), read(UI)
    br, rc, chk = read(BRIDGE), read(RECORD), read(RECORD_CHECK)
    seams = {
        "the topics are on the list":
            '"before", "started" }' in ktext,
        "the surface opens no store of its own":
            "ModData.getOrCreate(" not in ktext and "ModData.get(" not in ktext
            and "SAO.Standing.chronicle()" in ktext,
        "Standing hands the stamps over":
            "function S.chronicle()" in st and "outbreakAtHours = s.outbreakAtHours" in st,
        "the chronicle reads one calendar and no day count of its own":
            ui.count("dayWord(") >= 14 and ui.count('"day " .. math') == 1,
        "the bridge gives the county's date and the record's first day":
            "public String countyDate(double hours)" in br and "public String recordDayZero()" in br,
        "the record class holds the words":
            "public static String countyDate(int year, int month0, int day0, double hours)" in rc
            and "public static String recordDayZero()" in rc,
        "the record check asks for them":
            "SAORecord.countyDate(1993, 6, 0, 72.0)" in chk and "SAORecord.recordDayZero()" in chk,
        "the roadmap marks the slice shipped":
            "6. SHIPPED as `[C38]`" in read(ROADMAP),
        "the gate runs this border":
            "tools/era_test.py" in read(CHECK),
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
    print("  112) the era remembered: before and the day it started answered "
          "with provenance and the county's dates, one calendar")
    return 0


if __name__ == "__main__":
    sys.exit(main())
