#!/usr/bin/env python3
r"""Border 63 - a range a comment promises and the code cannot reach.

Eight decisions in `SAO_Disposition.lua` carry their range in a
trailing comment:

    return 3.0 + (1.0 - t.nerve) * 5.0 + t.selfPreservation * 3.0
        -- 3.0 .. 11.0 tiles

Every one of the eight was wrong, and all eight in the same way. They
were written as if a trait ran 0..1. It does not - `trait()` returns
**0.15 .. 0.85**, the human envelope [A14] imposes so that history
bends a person and never breaks the species, and the echoes that shift
it are clamped to the same band.

Asked the engine over three thousand ids:

    fleeDistance        3.0 .. 11.0   ->   4.27 .. 9.76
    overwhelmThreshold  2 .. 7        ->   2 .. 6
    decisionInterval    8 .. 30       ->   11 .. 26
    roamRange           4 .. 12       ->   5 .. 10
    eatAt               0.30 .. 0.55  ->   0.3375 .. 0.5123
    talkativeness       0.20 .. 0.85  ->   0.2975 .. 0.7520
    drinkAt             0.25 .. 0.45  ->   0.28 .. 0.4199
    followGap           4 .. 8        ->   4.6 .. 7.40

`overwhelmThreshold` is the sharpest: the comment promises a seventh
step that is structurally unreachable. The others describe survivors
who cannot exist.

It has already cost something. [B46] reasoned from "talkativeness runs
0.20 to 0.85" that a reserved survivor ignored four questions in five.
The floor is 0.2975, so it was nearer three in five. The conclusion
held; the number did not - and the number came from a comment.

WHY THIS IS A BORDER AND NOT A TIDY-UP
--------------------------------------
[B40] and [B41] both found a comment asserting an invariant the code
only happened to satisfy, and both fixed the instance. This is the
same class in the one place it can be checked by **execution**: the
range is a claim about output, and output can be sampled.

So the comment is read out of the source, the function is run in a
real Kahlua VM over three thousand ids, and the two are compared. A
comment promising more than the code reaches is a fault; so is a
comment promising less, because then the comment is not describing the
function either.

SKIPs when the engine is absent. FAULTs when the module is missing -
Border 54's lesson.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
DISP = LUA / "shared" / "SAO_Disposition.lua"
HASH = LUA / "shared" / "SAO_Hash.lua"
SRC = ROOT / "tools" / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

IDS = 3000
# Sampling reaches the extreme but never quite touches it, and a
# documented figure is rounded for a reader. One part in fifty of the
# span is loose enough for both and far tighter than any of the eight
# errors this border was written for - the smallest of them, drinkAt,
# was out by 15% of its span at one end.
TOLERANCE = 0.02

DECL = re.compile(
    r"^function D\.(\w+)\(id\)\s*\n(?:.*\n)*?.*?"
    r"--\s*([0-9.]+)\s*\.\.\s*([0-9.]+)", re.M)


def documented():
    text = DISP.read_text(encoding="utf-8", errors="ignore")
    out = {}
    for block in text.split("\nfunction D.")[1:]:
        name = block.split("(", 1)[0]
        head = block.split("\nend", 1)[0]
        m = re.search(r"--\s*([0-9.]+)\s*\.\.\s*([0-9.]+)", head)
        if m:
            out[name] = (float(m.group(1)), float(m.group(2)))
    return out


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300).returncode == 0


def measure(names):
    lua_names = ", ".join('"' + n + '"' for n in names)
    expr = (
        '(function() local fns = {' + lua_names + '} local out = {} '
        'for _, name in ipairs(fns) do local lo, hi = nil, nil '
        'for i = 1, ' + str(IDS) + ' do '
        'local v = SAO.Disposition[name]("sao-" .. i) '
        'if not lo or v < lo then lo = v end '
        'if not hi or v > hi then hi = v end end '
        'out[#out + 1] = name .. " " .. lo .. " " .. hi end '
        'return table.concat(out, "|") end)()')
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(HASH), str(DISP), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=600)
    tail = (done.stdout or "").strip().split("\n")[-1] if done.stdout else ""
    if not tail.startswith("VALUE "):
        return None, (tail or (done.stderr or "").strip())[:200]
    got = {}
    for part in tail[6:].split("|"):
        bits = part.split()
        if len(bits) == 3:
            got[bits[0]] = (float(bits[1]), float(bits[2]))
    return got, None


def main():
    faults = []
    print("=" * 74)
    print("A RANGE A COMMENT PROMISES")
    print("=" * 74)

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib.lua or runner")
        print("  63) decision range: SKIPPED, engine absent")
        return 0
    for path in (DISP, HASH):
        if not path.exists():
            print()
            print("VERDICT:")
            print(f"  FAULT: {path.name} is gone, so no range was checked. "
                  "An absent module is the finding, not a reason to skip")
            return 1
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the VM runner will not compile, so nothing ran on "
              "the engine. A border that cannot run is not one that passed")
        return 1

    claims = documented()
    print(f"  decisions documenting a range: {len(claims)}")
    if not claims:
        faults.append(
            "not one decision in SAO_Disposition.lua states its range any "
            "more. Eight of them did, and every one was wrong - losing the "
            "claims is not the same as fixing them")
        print()
        print("VERDICT:")
        for f in faults:
            print(f"  FAULT: {f}")
        return 1

    got, err = measure(sorted(claims))
    if got is None:
        print()
        print("VERDICT:")
        print(f"  FAULT: the engine would not run the decisions: {err}")
        return 1

    for name in sorted(claims):
        want_lo, want_hi = claims[name]
        if name not in got:
            faults.append(
                f"`{name}` documents a range and the engine never returned "
                "a value for it - the claim is unchecked, which is where "
                "all eight of these started")
            continue
        lo, hi = got[name]
        span = max(want_hi - want_lo, 1e-9)
        slack = span * TOLERANCE
        ok = abs(lo - want_lo) <= slack and abs(hi - want_hi) <= slack
        print(f"     {name:<20} says {want_lo:g}..{want_hi:g}   "
              f"engine {lo:.4g}..{hi:.4g}   {'ok' if ok else 'WRONG'}")
        if not ok:
            faults.append(
                f"`{name}` documents {want_lo:g}..{want_hi:g} and the engine "
                f"produces {lo:.4g}..{hi:.4g} over {IDS} survivors. A range "
                "in a comment is a claim about what this county can contain: "
                "promise more than the code reaches and it describes people "
                "who cannot exist, promise less and it is not describing the "
                "function at all. Traits run 0.15..0.85, not 0..1 - that is "
                "what every one of the original eight forgot")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  63) decision range: all {len(claims)} documented ranges match "
          f"what the engine produces over {IDS} survivors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
