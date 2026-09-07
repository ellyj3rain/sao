#!/usr/bin/env python3
r"""Border 110 - the record on the county's calendar ([C36], DR-031).

The engine keys its broadcasts to days since the save began and dates
its papers to no calendar; the record itself carries the dates. SAO
re-keys every vanilla channel's running script, once per save, to
begin on the save day that July 9, 1993 falls on, and dates every paper
a container is filled with to the newest issue printed by that day -
or takes it off the shelf when nothing has been printed yet.

Checked here: the date arithmetic, compiled against the installed
game and SAO's own jar and run off the game (tools/javacheck/
RecordCheck.java): the shipped start keys to day 0 and changes
nothing, a July 1 start keys to save day 8, a July 20 start to -11,
and the issues fall out of their own names. By text: the server module
keys once per save with a retry and hooks the container fill; the
bridge exposes the calls and never throws; the option and its words
exist; the harness reports the record's day; the engine contract
records the surfaces; the print-media helper is called in the order
its bytecode takes its arguments.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree faults at every seam.
"""
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
MEDIA = ROOT / "mod" / "42.20" / "media"
RECORD_JAVA = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAORecord.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
JAR = ROOT / "java" / "dist" / "SAOAgent.jar"
CHECK = HERE / "javacheck" / "RecordCheck.java"
LUA = MEDIA / "lua" / "server" / "SAO_Record.lua"
HARNESS = MEDIA / "lua" / "client" / "SAO_Harness.lua"
OPTIONS = MEDIA / "sandbox-options.txt"
WORDS = MEDIA / "lua" / "shared" / "Translate" / "EN" / "Sandbox.json"
CONTRACT = ROOT / "ENGINE_CONTRACT.md"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ_JAR = PZ_DIR / "projectzomboid.jar"
ZB_JAR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600") / "3421256432" / "mods" / "ZombieBuddy" / "42" / "media" / "java" / "ZombieBuddy.jar"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def find_zb():
    if ZB_JAR.exists():
        return ZB_JAR
    for p in (pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")).glob("*/mods/ZombieBuddy/**/ZombieBuddy.jar"):
        return p
    return None


def main():
    faults = []
    print("=" * 74)
    print("THE RECORD ON THE COUNTY'S CALENDAR")
    print("=" * 74)
    for path, what in ((RECORD_JAVA, "SAORecord.java"), (LUA, "SAO_Record.lua"),
                       (CHECK, "the Java check"), (BRIDGE, "SAOBridge.java")):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1

    zb = find_zb()
    missing = [str(p) for p in (JAR, PZ_JAR, JDK / "javac.exe", JDK / "java.exe") if not p.exists()]
    if zb is None:
        missing.append("ZombieBuddy.jar")
    if missing:
        faults.append("the Java check cannot run: missing " + ", ".join(missing)
                      + " - a border that cannot run is not one that passed")
    else:
        with tempfile.TemporaryDirectory() as tmp:
            classpath = os.pathsep.join(str(p) for p in (PZ_JAR, zb, JAR))
            compiled = subprocess.run([str(JDK / "javac.exe"), "-cp", classpath, "-d", tmp, str(CHECK)],
                                      capture_output=True, text=True, timeout=300)
            if compiled.returncode != 0:
                faults.append("the Java check does not compile: " + (compiled.stderr or "")[:400])
            else:
                ran = subprocess.run([str(JDK / "java.exe"), "-cp", os.pathsep.join([classpath, tmp]), "RecordCheck"],
                                     capture_output=True, text=True, timeout=300)
                out = (ran.stdout or "") + (ran.stderr or "")
                for line in out.strip().split("\n"):
                    if line.strip():
                        print("   " + line.rstrip())
                if "RECORD PASS" not in out:
                    faults.append("the date arithmetic does not hold off the game")

    java = read(RECORD_JAVA)
    bridge = read(BRIDGE)
    lua = read(LUA)
    seams = {
        "the record's day 0 is July 9, 1993": "LocalDate.of(1993, 7, 9)" in java,
        "the engine's zero-based month and day are honoured": "LocalDate.of(year, month0 + 1, day0 + 1)" in java,
        "only vanilla channels are re-keyed": "!channel.isVanilla()" in java,
        "through the engine's own re-keying surface": "channel.setActiveScript(script.GetName(), startDay)" in java,
        "a paper not yet printed leaves the shelf": "container.Remove(item)" in java,
        "the print media is written in the helper's own order (title, info, text, id)":
            "RecipeCodeHelper.setPrintMediaInfo(item, title,\n                paper.getTranslationInfoKey(issue), paper.getTranslationTextKey(issue),\n                String.valueOf(paper))" in java,
        "a keyed paper is not keyed twice": '"SAORecordKeyed"' in java,
        "the bridge exposes the start day": "public double recordStartDay()" in bridge or "public int recordStartDay()" in bridge,
        "and the re-key": "public int rekeyRecord(" in bridge,
        "and the papers": "public String keyNewspapers(" in bridge,
        "and a report": "public String recordReport()" in bridge,
        "the module keys once per save": "s.recordKeyedForStart == startDay" in lua,
        "with a retry until the channels exist": "Events.EveryHours.Add(retry)" in lua,
        "and hooks the container fill": "Events.OnFillContainer.Add(onFillContainer)" in lua,
        "behind its option": "SandboxVars.SurvivorAwareness.RecordOnCalendar" in lua,
        "the option exists": "option SurvivorAwareness.RecordOnCalendar" in read(OPTIONS),
        "with its words": "Sandbox_SurvivorAwareness_RecordOnCalendar_tooltip" in read(WORDS),
        "the harness reports the record's day": "The record's day" in read(HARNESS),
        "the contract records the surfaces": "setPrintMediaInfo(item, title, info, text, id)" in read(CONTRACT),
    }
    print()
    print("  THE SEAMS")
    for k, v in seams.items():
        print("    %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append("seam missing: " + k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  110) the record on the county's calendar: the arithmetic holds off the game, and every seam carries it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
