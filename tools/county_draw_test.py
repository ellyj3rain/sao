#!/usr/bin/env python3
r"""Border 134 - the county's draw is its own, and it is measured ([C66]).

Forty-two places asked the engine for a random number through
`ZombRand`, which carries no state SAO can see, set or write down. No
county could be run twice: a reported defect could not be reproduced,
and a sweep moving one sandbox dial could not tell whether what it saw
came from the dial or from the draw. The operator ruled that SAO
carries its own generator.

THIS BORDER MEASURES THE DRAW. It does not read the formula.

That is the whole point of it. [C66]'s first draft was
`SAO.Hash.of(seed, counter) % n` - counter in the salt position,
answer off FNV's low digits - and it produced

    14, 15, 16, 17, 18, 55, 56, 57, ...

with 1626 of 1999 consecutive draws exactly the one before plus one.
Every "random" choice in the county would have marched in lockstep,
and from inside a game it would have looked like variety. A border
asserting that the module calls `SAO.Hash` would have passed it. A
border asserting the corrected expression would pass any future
rewrite that happened to spell it the same way while meaning something
else.

So the checks below run the real module in the engine's own VM and do
statistics on what comes out, at the three moduli that matter: the coin
([B38] measured FNV's low bit at 9% heads), a small pool, and a wide
one. The bounds are the chi-square critical values at p=0.001, which
is loose enough that nothing flaps and tight enough that the first
draft fails every one of them.

The other four things it holds:

  * REPRODUCIBLE. The same save drawing from the same count produces
    the same sequence, which is the property the whole batch is for.
  * DISTINCT PER SAVE. A different save identity draws differently,
    so one seed does not give every county on the machine the same
    people.
  * PERSISTENT. The count is in the save, so a reload continues the
    sequence instead of repeating it.
  * OFFLINE-SAFE. With no save to be identified, the draw falls
    through to the engine, so nothing that runs before a world exists
    runs differently.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree has no module and
forty-two direct calls to the engine.
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
RAND = LUA / "shared" / "SAO_Rand.lua"
HASH = LUA / "shared" / "SAO_Hash.lua"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

DRAWS = 6000
# Chi-square at p=0.001. Loose enough that a sound generator never
# flaps, tight enough that the ramping first draft fails all three.
CRITICAL = {2: 10.83, 6: 20.52, 100: 148.2}

PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
_G.__md = {}
ModData = { getOrCreate = function(k) __md[k] = __md[k] or {} return __md[k] end }
_G.__world = "SaveA"
_G.__noWorld = false
getWorld = function()
    if _G.__noWorld then error("no world") end
    return { getWorld = function() return _G.__world end }
end
GameTime = { getInstance = function()
    if _G.__noWorld then error("no clock") end
    return {
        getStartYear = function() return 1996 end,
        getStartMonth = function() return 6 end,
        getStartDay = function() return 8 end }
end }
_G.__engineAsked = 0
ZombRand = function(n) _G.__engineAsked = _G.__engineAsked + 1 return 42 end
-- Between cases: a fresh save, and the module's memo dropped the only
-- way a module local can be dropped from outside.
function __freshSave(name)
    __md["SurvivorAwareness_Standing"] = nil
    _G.__world = name
end
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
             str(prelude), str(HASH), str(RAND), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# The statistics, computed in the VM over what the real module draws.
SPREAD = ("(function() local out = {} "
          "for _, n in ipairs({2, 6, 100}) do "
          "__freshSave('SaveA') "
          "local seen, runs, prev = {}, 0, nil "
          "for i = 0, n - 1 do seen[i] = 0 end "
          "for i = 1, %d do local v = SAO.Rand.int(n) "
          "seen[v] = seen[v] + 1 "
          "if prev ~= nil and v == (prev + 1) %% n then runs = runs + 1 end "
          "prev = v end "
          "local exp = %d / n local x2 = 0 "
          "for i = 0, n - 1 do local d = seen[i] - exp x2 = x2 + d * d / exp end "
          "out[#out + 1] = 'chi' .. n .. '=' .. string.format('%%.2f', x2) "
          "out[#out + 1] = 'runs' .. n .. '=' .. runs "
          "end return table.concat(out, ' ') end)()" % (DRAWS, DRAWS))

# Reproducible, distinct per save, persistent.
#
# Each of these runs in its OWN VM process, which is the only honest
# way to ask them. The module memoises the store table, and the first
# draft of this border cleared ModData between cases and left that memo
# pointing at the old table - so nothing reset, the count ran on to 21,
# and the border reported the module irreproducible when what had
# failed was the probe. A separate process is also what the property
# actually means: the same save, opened again, draws the same county.
def draws(world, count=6, extra=0):
    expr = ("(function() _G.__world = '%s' local a = {} "
            "for i = 1, %d do a[#a + 1] = SAO.Rand.int(1000) end "
            "local b = {} for i = 1, %d do b[#b + 1] = SAO.Rand.int(1000) end "
            "local seed, n = SAO.Rand.state() "
            "return 'seed=' .. tostring(seed) .. ' count=' .. n "
            ".. ' first=' .. table.concat(a, '.') "
            ".. ' next=' .. table.concat(b, '.') end)()"
            % (world, count, extra))
    return numbers(value(probe(expr)))


# Both arities, because the engine declares both and nine sites use
# the second. A one-parameter draw answers the LOW bound as its
# modulus, which is negative at seven of them, and every one of those
# collapsed to a constant.
ARITY = ("(function() _G.__world = 'SaveA' local out = {} "
         "local lo, hi = 9999, -9999 "
         "for i = 1, 400 do local v = SAO.Rand.int(-3, 4) "
         "if v < lo then lo = v end if v > hi then hi = v end end "
         "out[#out + 1] = 'twoLo=' .. lo .. ' twoHi=' .. hi "
         "local l2, h2 = 9999, -9999 "
         "for i = 1, 400 do local v = SAO.Rand.int(10) "
         "if v < l2 then l2 = v end if v > h2 then h2 = v end end "
         "out[#out + 1] = 'oneLo=' .. l2 .. ' oneHi=' .. h2 "
         "out[#out + 1] = 'empty=' .. SAO.Rand.int(5, 5) "
         "return table.concat(out, ' ') end)()")

OFFLINE = ("(function() __freshSave('SaveA') _G.__noWorld = true "
           "_G.__engineAsked = 0 "
           "local v = SAO.Rand.int(100) "
           "return 'engineAsked=' .. _G.__engineAsked .. ' value=' .. v end)()")


def main():
    faults = []
    print("=" * 74)
    print("THE COUNTY'S DRAW IS ITS OWN, AND IT IS MEASURED")
    print("=" * 74)
    if not RAND.exists():
        print("  FAULT: SAO_Rand.lua does not exist, so the county's "
              "randomness is the engine's and no save can be run twice")
        return 1

    # Nothing but the module itself asks the engine.
    strays = []
    for path in sorted(LUA.rglob("*.lua")):
        if path.name == "SAO_Rand.lua":
            continue
        if "ZombRand" in read(path):
            strays.append(path.relative_to(LUA).as_posix())
    print("  modules still drawing from the engine: %d" % len(strays))
    for name in strays[:6]:
        print("      " + name)

    seams = {
        # The function, not one spelling of its signature. This named
        # `R.int(n)` and went red when [C66] gave the draw the engine's
        # second arity - refusing a fix for the shape of its own
        # declaration, which is what Border 118 was corrected for
        # earlier the same day.
        "the county has its own draw":
            "function R.int(" in read(RAND),
        "the seed is derived from the save and written down":
            "getWorld():getWorld()" in read(RAND)
            and "s.randSeed" in read(RAND),
        "the count is in the save, not a module local":
            "s.randCount" in read(RAND),
        "the run can say what to feed back":
            "function R.state()" in read(RAND),
        "SAO_Rand is the only module asking the engine":
            not strays,
        "the gate runs this border":
            "tools/county_draw_test.py" in read(CHECK),
    }

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
        print("  134) the county's draw: TEXT ONLY, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # ------------------------------------------------------------------
    # The measurement. This is the check the first draft would fail.
    # ------------------------------------------------------------------
    got = numbers(value(probe(SPREAD)))
    print()
    print("     %d draws, chi-square against p=0.001 and consecutive runs:"
          % DRAWS)
    for n in (2, 6, 100):
        x2 = got.get("chi%d" % n)
        runs = got.get("runs%d" % n)
        expected_runs = DRAWS // n
        print("       n=%-4d chi2=%-8s critical=%-7s runs=%-6s expected~%d"
              % (n, x2, CRITICAL[n], runs, expected_runs))
        if x2 is None:
            faults.append("no chi-square came back for n=%d" % n)
            continue
        if float(x2) > CRITICAL[n]:
            faults.append("the draw is not flat at n=%d: chi-square %s "
                          "against a critical value of %s"
                          % (n, x2, CRITICAL[n]))
        if runs is None:
            faults.append("no run count came back for n=%d" % n)
        elif int(runs) > expected_runs * 5:
            faults.append("the draw ramps at n=%d: %s consecutive draws "
                          "were exactly the one before plus one, against "
                          "about %d expected by chance. That is [B48]'s "
                          "arithmetic progression, and [C66]'s own first "
                          "draft produced 1626 of 1999"
                          % (n, runs, expected_runs))

    # ------------------------------------------------------------------
    # Reproducible, distinct, persistent - each in its own process.
    # ------------------------------------------------------------------
    a = draws("SaveA", 6, 3)
    again = draws("SaveA", 6, 3)
    other = draws("SaveB", 6, 3)
    print("     SaveA      : %s  count=%s" % (a.get("first"), a.get("count")))
    print("     SaveA again: %s  count=%s"
          % (again.get("first"), again.get("count")))
    print("     SaveB      : %s  count=%s"
          % (other.get("first"), other.get("count")))
    if not a.get("first"):
        faults.append("the module drew nothing at all")
    if a.get("first") != again.get("first"):
        faults.append("the same save drew %s and then %s, so no county can "
                      "be run twice and the whole batch buys nothing"
                      % (a.get("first"), again.get("first")))
    if a.get("first") == other.get("first"):
        faults.append("two different saves drew the same sequence, so one "
                      "seed gives every county on the machine the same "
                      "people")
    if a.get("seed") == other.get("seed"):
        faults.append("two different saves derived the same seed (%s)"
                      % a.get("seed"))
    if a.get("first") == a.get("next"):
        faults.append("the count did not carry: the next three draws "
                      "repeated the first three, so a reload would replay "
                      "draws the save had already made")
    if a.get("count") != "9":
        faults.append("nine draws left the count at %s" % a.get("count"))

    got = numbers(value(probe(ARITY)))
    print("     arities: " + " ".join("%s=%s" % kv for kv in got.items()))
    if got.get("twoLo") != "-3" or got.get("twoHi") != "3":
        faults.append("R.int(-3, 4) ranged %s..%s, wanted -3..3. The engine "
                      "declares ZombRand(double, double) and nine sites in "
                      "this tree use it; a draw that answers only one arity "
                      "hands the low bound back as a modulus and collapses "
                      "every one of them to a constant"
                      % (got.get("twoLo"), got.get("twoHi")))
    if got.get("oneLo") != "0" or got.get("oneHi") != "9":
        faults.append("R.int(10) ranged %s..%s, wanted 0..9"
                      % (got.get("oneLo"), got.get("oneHi")))
    if got.get("empty") != "5":
        faults.append("an empty range answered %s, wanted its low bound 5"
                      % got.get("empty"))

    got = numbers(value(probe(OFFLINE)))
    print("     with no world: " + " ".join("%s=%s" % kv for kv in got.items()))
    if got.get("engineAsked") != "1":
        faults.append("with no save to seed from, the draw asked the engine "
                      "%s times, wanted once - nothing that runs before a "
                      "world exists may run differently"
                      % got.get("engineAsked"))

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
        print("  134) the county's draw: FAIL")
        return 1
    print("  134) the county's draw is its own, flat at every modulus "
          "measured, and reproducible: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
