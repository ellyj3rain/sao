#!/usr/bin/env python3
r"""Border 61 - ask the engine, not a model.

[B48] tested four hypotheses about the lesson draw and cleared all
four. Every test simulated the Lua in Python, in exact integers.
[B48] then found the defect: `value * 16777619` overruns the 2^53 a
double holds, so Kahlua rounds the low bits off every character and
the county's whole personality space collapsed to six values.

The simulation was not wrong about the code. It was wrong about the
machine - and **a model more capable than the machine will always
confirm that the code is fine**.

So this border does not model anything. `tools/luacheck/LuaRun.java`
loads the shipped `SAO_Hash.lua` into a real Kahlua VM out of
`projectzomboid.jar`, calls the real function, and reads back what the
engine actually computed.

WHAT IT ASKS
------------
Two questions, in order of how much they matter.

1. **Does it spread?** Two hundred ids across two salts. The broken
   version returned six distinct values out of fifty-nine; the fixed
   one must return essentially all of them. This is the property the
   county actually needs - that two people are two people - and it can
   be checked without knowing what the right answer is.

2. **Is it the intended function?** The engine's values are compared
   against exact-integer FNV. This is the secondary check, and the
   weaker one, because it is the model again - but a hash that spreads
   and is not FNV would mean the arithmetic had been quietly replaced
   rather than repaired, and that is worth knowing too.

The bar for the first question is 95% distinct, not 100%: FNV over
2^32 has a birthday collision rate that makes an occasional repeat
correct behaviour. Six percent is what broken looks like. Anything
near a hundred is what working looks like. There is no honest reading
that puts the true value between them.

SKIPs when the JDK, the engine jar, or the engine's own `stdlib.lua`
is absent - `newEnvironment()` bootstraps from that file, so the VM
cannot start without it.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
HASH = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Hash.lua"
SRC = ROOT / "tools" / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

IDS = 400
SALTS = ("aggression", "nerve")
SPREAD_BAR = 0.95
# A runs test tolerates real variance; independence predicts ~2Np(1-P)
# and this only refuses a sequence well under that. One pass scored
# 137 against a prediction of 198 - clumping this border exists to
# catch - and two passes scored 193 against 195.
RUNS_LOW = 0.85
# And an upper bound, because the same linearity wears both signs. One
# pass scored 69% on `nerve` (long clumps: neighbours alike) and 157%
# on `aggression` (near-alternating: neighbours opposite). Both are a
# sequence that knows what came before it; only the middle is people.
RUNS_HIGH = 1.30


def exact_fnv(id_, salt):
    """The intended function, in exact integers - BOTH passes.

    [B48] added the second pass over the decimal digits of the first
    result, because our ids differ in the MIDDLE of the hashed text and
    a single FNV pass therefore leaves consecutive ids a constant
    distance apart. This model has to follow, or it would report the
    fix as a corruption.
    """
    def once(text, value=2166136261):
        for ch in text:
            value = (value * 16777619 + ord(ch)) % 4294967296
        return value
    return once(str(once(f"{id_}:{salt}")))


def runs(flags):
    total = 1
    for a, b in zip(flags, flags[1:]):
        if a != b:
            total += 1
    return total


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    if done.returncode != 0:
        for line in (done.stderr or "").strip().split("\n")[:6]:
            print("    " + line)
        return False
    return True


def ask_engine(salt):
    """Run the shipped hash in Kahlua and read back every value."""
    expr = ('(function() local t = {} for n = 1, ' + str(IDS)
            + ' do t[#t + 1] = SAO.Hash.of("sao-" .. n, "' + salt
            + '") end return table.concat(t, ",") end)()')
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(HASH), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=600)
    line = (done.stdout or "").strip()
    if not line.startswith("VALUE "):
        return None, line or (done.stderr or "").strip()[:200]
    return [int(x) for x in line[6:].split(",") if x], None


def main():
    faults = []
    print("=" * 74)
    print("ASK THE ENGINE, NOT A MODEL")
    print("=" * 74)

    # An absent ENGINE is a skip - this machine simply cannot answer.
    # An absent HASH is a fault: the thing under test is gone, and
    # skipping would let a verdict about nothing read as a pass. Border
    # 54 caught exactly that in this border's first draft, by running
    # it against a tree with the Lua removed.
    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib.lua or runner")
        print("  61) hash spread: SKIPPED, engine absent")
        return 0
    if not HASH.exists():
        print()
        print("VERDICT:")
        print("  FAULT: " + HASH.name + " is not there to run. Every trait, "
              "occupation and face in the county comes through it, so its "
              "absence is not a reason to skip - it is the loudest possible "
              "finding")
        return 1
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the VM runner will not compile, so nothing was run "
              "on the engine this pass. A border that cannot run is not a "
              "border that passed")
        return 1

    for salt in SALTS:
        values, err = ask_engine(salt)
        if values is None:
            faults.append(
                f"the engine would not compute the hash for salt '{salt}': "
                f"{err}. Until it runs, nothing here is known")
            continue
        if len(values) != IDS:
            faults.append(
                f"asked the engine for {IDS} values on salt '{salt}' and got "
                f"{len(values)} back - the run was cut short and a partial "
                "answer is not an answer")
            continue

        distinct = len(set(values))
        spread = distinct / len(values)
        wrong = sum(1 for n, v in enumerate(values, 1)
                    if v != exact_fnv(f"sao-{n}", salt))

        # The third question, and the one the county actually feels.
        # Our ids are sequential and households are contiguous blocks
        # of them, so a hash that merely SPREADS can still hand a
        # family traits in a ramp. Reduce as a trait does and count
        # runs across a threshold: independence predicts ~2Np(1-p).
        flags = [1 if (0.15 + (v % 1000) / 1000 * 0.70) < 0.45 else 0
                 for v in values]
        share = sum(flags) / len(flags)
        seen_runs = runs(flags)
        expect = 2 * len(flags) * share * (1 - share) + 1
        ratio = seen_runs / expect if expect else 1.0

        print(f"  salt '{salt}': {distinct}/{len(values)} distinct "
              f"({spread:.0%}), {wrong} disagreeing with exact FNV, "
              f"{seen_runs} runs vs ~{expect:.0f} expected "
              f"({ratio:.0%})")

        if spread < SPREAD_BAR:
            faults.append(
                f"the engine computes only {distinct} distinct values from "
                f"{len(values)} ids on salt '{salt}' ({spread:.0%}). Two "
                "people are not two people: every trait, occupation and face "
                "in the county comes through this, and [B48] found it "
                "collapsed to six values because the multiply overran the "
                "mantissa. Whatever is in SAO_Hash.lua now, the engine "
                "cannot spread it")
        if not (RUNS_LOW <= ratio <= RUNS_HIGH):
            shape = ("clumps - neighbouring survivors alike"
                     if ratio < RUNS_LOW
                     else "alternates - neighbouring survivors opposite")
            faults.append(
                f"on salt '{salt}' a trait threshold falls in {seen_runs} "
                f"runs where independence predicts {expect:.0f} "
                f"({ratio:.0%}); it {shape}. The values are distinct and "
                "they are not INDEPENDENT: consecutive ids march. "
                "Households are contiguous blocks of ids, so a family "
                "comes out sorted by a trait instead of made of "
                "individuals - before [B48]'s second hash pass this "
                "scored 69% on nerve and 157% on aggression")
        if wrong:
            faults.append(
                f"{wrong} of {len(values)} values on salt '{salt}' differ "
                "from exact-integer FNV. The hash spreads but is no longer "
                "the function that was written - which means the arithmetic "
                "was replaced rather than repaired, and every id in every "
                "existing save moves for a reason nobody chose")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  61) hash spread: the engine itself computes {IDS} ids across "
          f"{len(SALTS)} salts - all distinct, all equal to exact FNV, and "
          "a trait threshold falls in as many runs as independence predicts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
