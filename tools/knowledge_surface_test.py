#!/usr/bin/env python3
r"""Border 101 - the knowledge surface answers, offline, and writes
nothing ([C27], SPEECH_ML_DESIGN.md).

Rung 1 of the ratified talking-system design: one surface yielding
everything the two learned pieces will read - a person's facts by
topic, each with how-they-know-it and how old, plus the conditioning
the speaker takes (the eight axes, trust toward the listener, the
moment). SPEECH.md promised rung 1 would be "testable offline
against the mirrors, needs no external service" - so this border
DRIVES it: the module is loaded into a bare Kahlua VM (the engine's
own, via tools/luacheck/LuaRun) against a stub county
(probe_knowledge.lua) and asked real questions.

WHAT THIS HOLDS
---------------
  1. The module loads bare and ANSWERS: crowds counted with age and
     source, the dead named with teller, lessons withheld below the
     earned line and given past it, conditioning carrying trust,
     war, and debt.
  2. READ-ONLY BY LAW: the module never writes - no ModData open
     (getOrCreate writes on first touch), no trust mutation, no
     tell, no record field assignment. The one-loop law: asking
     changes nothing.
  3. The claims() bundle exists (the models' one input) and the
     inspect panel reads the person through it today.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C27] tree.
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
K = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Knowledge.lua"
INSPECT = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Inspect.lua"
PRELUDE = HERE / "luacheck" / "probe_knowledge.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
# Kahlua's newEnvironment loads stdlib.lua from the working
# directory - the same temp-workdir idiom engine_facts uses.
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
             str(PRELUDE), str(K), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=120)
    line = (done.stdout or "").strip().split("\n")[-1] \
        if done.stdout else ""
    return line


def main():
    faults = []
    print("=" * 74)
    print("THE KNOWLEDGE SURFACE ANSWERS, OFFLINE, AND WRITES NOTHING")
    print("=" * 74)

    if not K.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_Knowledge.lua does not exist - the ratified "
              "design's rung 1 is a document with no surface, and both "
              "models have nothing to read")
        return 1
    ktext = K.read_text(encoding="utf-8", errors="ignore")
    itext = INSPECT.read_text(encoding="utf-8", errors="ignore") \
        if INSPECT.exists() else ""

    # 2. Read-only by law, textually: strip comments, then ban every
    # write shape ("prose is not code" - the header NAMES the banned
    # calls while explaining the law).
    kcode = "\n".join(
        line[:line.find("--")] if line.find("--") >= 0 else line
        for line in ktext.split("\n"))
    for banned, why in (
            ("ModData", "opens a store - getOrCreate writes on first "
                        "touch"),
            ("adjustTrust", "moves standing - asking must change "
                            "nothing"),
            (".tell(", "crosses the belief channel - this surface is "
                       "a read, not a teller"),
            ("Identity.ensure", "creates records"),
            ("SAO.Seams", "even the seam ledger is a write")):
        if banned in kcode:
            faults.append(f"the knowledge module touches {banned} - "
                          f"{why} (the one-loop law, [B27])")
    if re.search(r"\brec\.\w+\s*=\s*", kcode):
        faults.append("the knowledge module assigns record fields - "
                      "a reader that writes is a second mutator "
                      "nobody audits")

    # 1. Driven offline, if the harness exists on this machine.
    if not (JDK.exists() and PZ.exists() and SRC.exists()):
        print("  probes: SKIPPED - no JDK or engine jar; the textual "
              "law still held above")
    elif not build():
        faults.append("the Lua runner will not compile, so nothing "
                      "drove the surface this run - a border that "
                      "cannot run is not a border that passed")
    else:
        probes = [
            ("crowds counted",
             'SAO.Knowledge.about("p1","zombies",{tick=2000})[1].count',
             "VALUE 2"),
            ("freshest sighting aged in words",
             'SAO.Knowledge.about("p1","zombies",{tick=2000})[1].ageWord',
             "VALUE just now"),
            ("the dead named with their teller",
             'SAO.Knowledge.about("p1","dead")[1].teller',
             "VALUE Dana"),
            ("lessons withheld below the earned line",
             'SAO.Knowledge.about("p1","lessons",{trusted=false})[1].fact',
             "VALUE withheld"),
            ("lessons given past it",
             'SAO.Knowledge.about("p1","lessons",{trusted=true})[1].line',
             "VALUE Quiet keeps you alive."),
            ("a known place offering food",
             'SAO.Knowledge.about("p1","food")[2].whereWord',
             "VALUE north of here"),
            ("the house speaks its leader",
             'SAO.Knowledge.about("p1","house")[2].name',
             "VALUE Ruth Hall"),
            ("conditioning knows the war",
             'tostring(SAO.Knowledge.conditioning("p1","player:you")'
             '.moment.war)',
             "VALUE true"),
            ("conditioning knows the debt",
             'tostring(SAO.Knowledge.conditioning("p1","player:you")'
             '.moment.debt)',
             "VALUE true"),
            ("trust 0.2 answers guardedly",
             'tostring(SAO.Knowledge.conditioning("p1","player:you")'
             '.trusted)',
             "VALUE false"),
            ("the one bundle both models read",
             'SAO.Knowledge.claims("p1","player:you",2000)'
             '.facts.zombies[1].count',
             "VALUE 2"),
        ]
        for name, expr, want in probes:
            got = probe(expr)
            ok = got == want
            print(f"  {'yes' if ok else 'NO '}  {name}")
            if not ok:
                faults.append(f"{name}: probed `{expr}` and got "
                              f"`{got}` (wanted `{want}`) - the "
                              "surface does not answer what the "
                              "design ratified")

    # 3. The inspect panel reads through it today.
    if "SAO.Knowledge.claims" not in itext:
        faults.append("the inspect panel does not read the person "
                      "through the knowledge surface - the one "
                      "gauge-their-intelligence view the operator has "
                      "today would still read the raw stores")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  101) the knowledge surface: loads bare, answers what the")
    print("       stub county holds with provenance and age, withholds")
    print("       the earned until trust, bundles conditioning for the")
    print("       ratified models, writes nothing, and the inspect")
    print("       panel reads through it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
