#!/usr/bin/env python3
r"""Border 62 - the county gets seven kinds of past, in the engine.

The operator's session settled forty-nine pasts and every one of them
was `doors-decide-lives`. [B48] tested four hypotheses and disproved
all four - every test a reimplementation of the loop in Python, in
exact integers. [B48] found the real cause: Kahlua computes the FNV
step in doubles, the product overruns the mantissa, and every trait in
the county collapsed to a handful of values. [B48] then found that
even with the arithmetic repaired the values marched, because our ids
differ in the middle of the hashed text and FNV is linear.

Three batches, and none of them could have been closed by reading. So
this one does not read. `LuaRun` loads the real `SAO_Hash`,
`SAO_Disposition`, `SAO_Census` and `SAO_History` into a real Kahlua
VM, calls the real `H.generate` three hundred times, and records what
the real draw drew.

The only thing replaced is the endpoint: `SAO.Lessons.learn` writes the
key into a list instead of into a survivor.

WHAT IT REQUIRES
----------------
1. **Every key in the grammar is drawn at least once.** Seven entries
   describe seven kinds of person; a county that only ever produces
   some of them is not the county that was written. This is the check
   that would have failed loudly in the operator's session.

2. **No key takes more than 60% of the draws.** `claimed-places-bite`
   fits everybody, so it is in every pool and legitimately leads - it
   came out at 39%. Sixty is comfortably above that and comfortably
   below the hundred that was actually happening.

Both bars are about the SHAPE of a county, not about a hash, which is
why this border sits beside Border 61 rather than inside it. Border 61
asks whether the numbers are good. This asks whether the people are.

SKIPs when the engine is absent. FAULTs when the modules or the probe
are absent - a verdict about nothing is not a pass, which Border 54
had to teach Border 61 by catching it.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
CHECK = ROOT / "tools" / "luacheck"
PROBE = CHECK / "probe_lessons.lua"
SRC = CHECK / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

MODULES = ("shared/SAO_Log.lua", "shared/SAO_Hash.lua",
           "shared/SAO_Disposition.lua", "shared/SAO_Census.lua",
           "shared/SAO_History.lua")
PEOPLE = 300
DOMINANT = 0.60


def grammar_keys():
    text = (LUA / "shared" / "SAO_History.lua").read_text(
        encoding="utf-8", errors="ignore")
    import re
    block = re.search(r"local GRAMMAR = \{(.*?)\n\}", text, re.S)
    if not block:
        return []
    return re.findall(r'\{\s*key = "([a-z-]+)"', block.group(1))


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def draw():
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        args = [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun"]
        args += [str(LUA / m) for m in MODULES]
        args += [str(PROBE), "--", f"PROBE_DRAW({PEOPLE})"]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=600)
    tail = (done.stdout or "").strip().split("\n")[-1] if done.stdout else ""
    if not tail.startswith("VALUE "):
        return None, (tail or (done.stderr or "").strip())[:200]
    return [k for k in tail[6:].split(",") if k], None


def main():
    faults = []
    print("=" * 74)
    print("SEVEN KINDS OF PAST, IN THE ENGINE")
    print("=" * 74)

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib.lua or runner")
        print("  62) lesson draw: SKIPPED, engine absent")
        return 0

    missing = [m for m in MODULES if not (LUA / m).exists()]
    if missing or not PROBE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: " + ", ".join(missing + ([PROBE.name] if not
              PROBE.exists() else [])) + " missing, so the draw was never "
              "run. An absent module is the finding, not a reason to skip")
        return 1
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the VM runner will not compile, so nothing ran on "
              "the engine. A border that cannot run is not one that passed")
        return 1

    keys = grammar_keys()
    if len(keys) < 2:
        faults.append(
            "fewer than two grammar entries were found in SAO_History.lua, "
            "so either the grammar is gone or this border cannot read it - "
            "and a draw with one option is not a draw")

    drawn, err = draw()
    if drawn is None:
        print()
        print("VERDICT:")
        print(f"  FAULT: the engine would not run the draw: {err}")
        return 1

    counts = Counter(drawn)
    print(f"  people generated : {PEOPLE}")
    print(f"  lessons drawn    : {len(drawn)}")
    print(f"  grammar keys     : {len(keys)}")
    for k in keys:
        n = counts.get(k, 0)
        share = n / len(drawn) if drawn else 0
        print(f"     {n:>4}  ({share:>5.1%})  {k}")

    if not drawn:
        faults.append(
            f"three hundred people were generated and not one lesson was "
            "drawn. The past is what makes a survivor somebody in "
            "particular, and nobody got one")

    for k in keys:
        if counts.get(k, 0) == 0:
            faults.append(
                f"`{k}` is in the grammar and the engine never drew it over "
                f"{PEOPLE} people. Seven entries describe seven kinds of "
                "person; a county that cannot produce one of them is not "
                "the county that was written - and the operator's session "
                "produced exactly one kind, forty-nine times")

    for k, n in counts.most_common(1):
        if drawn and n / len(drawn) > DOMINANT:
            faults.append(
                f"`{k}` took {n / len(drawn):.0%} of every past this county "
                f"settled. `claimed-places-bite` fits everybody and still "
                "only reaches about 39%; anything past 60% means the draw "
                "has collapsed onto one answer, which is what [B48] and "
                "[B48] were both about")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  62) lesson draw: the engine settles {len(drawn)} pasts over "
          f"{PEOPLE} people across all {len(keys)} kinds, none dominating")
    return 0


if __name__ == "__main__":
    sys.exit(main())
