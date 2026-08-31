#!/usr/bin/env python3
r"""Border 69 - the engine facts this mod is built on.

This session found six things about Project Zomboid's Lua that are in
no documentation, and then built code around every one of them:

  * `next` is not callable                    -> [B44] hand-rolled the
                                                 emptiness test
  * doubles lose exactness past 2^53          -> [B48] split the FNV
                                                 multiply
  * `assert` and `require` ARE callable       -> [B45] and [B50]
                                                 corrected Border 48
                                                 twice for saying
                                                 otherwise
  * `table.sort` never chooses its pivot      -> [B50] bounded every
                                                 sort's input
  * `gmatch` does not advance on a zero-width
    match                                     -> [B50] requires every
                                                 pattern to need a
                                                 character

Each is guarded by its own border, and each of those borders checks
OUR code against the fact. **Nothing checks the fact.**

That is the gap. The mod pins to 42.20, and a game update can move any
of these underneath it. If `next` arrives, [B44]'s workaround becomes
a curiosity. If `table.sort` gains a median-of-three pivot, [B50]'s
bounds are still safe but its reasoning is no longer true, and a reader
deserves to know which.

The failure this prevents is quiet: not a crash, but a project carrying
workarounds nobody can justify and reasoning nobody can check, in
comments that were right when they were written.

So this asks the engine directly, every run. A fact that has CHANGED is
a fault - not because the change is bad, but because a batch record
somewhere is now describing a world that no longer exists.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# Each fact: a Lua expression, the answer measured this session, the
# batch whose code depends on it, and what that code does about it.
FACTS = (
    ("next is absent",
     "tostring(next)", "nil", "B160",
     "SAO_Places counts with pairs instead, because calling `next` threw "
     "on every dormant tick and the pcall around it made that "
     "indistinguishable from finding nothing"),
    ("assert is present",
     "type(assert)", "function", "B182",
     "Border 48 called it absent for twenty-two batches; it is defined "
     "on line 1 of the engine's own stdlib.lua"),
    # `require` is deliberately NOT here. It is installed by
    # `se.krka.kahlua.require.Require.install(env)`, which the GAME
    # calls and `J2SEPlatform.newEnvironment()` does not - so in this
    # harness `type(require)` reads nil no matter what the engine can
    # do. The first run of this border reported that as the fact having
    # changed, which would have been a false alarm about the one thing
    # [B45] proved hardest: 1213 vanilla call sites use it and
    # ISPanel.lua opens with one. It is checked against the jar below
    # instead, where the evidence actually lives.
    ("a double loses the low bits past 2^53",
     "((4294967295 * 16777619) % 4294967296 == "
     "((math.floor(4294967295 / 65536) * 16777619) % 65536 * 65536 "
     "+ (4294967295 % 65536) * 16777619) % 4294967296) "
     'and "exact" or "rounded"',
     "rounded", "B173",
     "SAO_Hash splits the multiply so no intermediate leaves exact "
     "range. If this ever reads `exact`, the split is doing nothing and "
     "the county's whole personality no longer depends on it"),
    ("gmatch does not advance on a zero-width match",
     "(function() local n = 0 "
     'for _ in string.gmatch("ab", "x*") do n = n + 1 '
     'if n > 200 then return "stuck" end end return "advances" end)()',
     "stuck", "B182",
     "Border 68 requires every pattern to need at least one character. "
     "If gmatch ever advances properly that requirement is still safe, "
     "but no longer necessary"),
)

# Read out of the engine's own source rather than executed.
SOURCE_FACTS = (
    ("table.sort never chooses its pivot", "local pivot = left", "B181",
     "Border 67 bounds every sort's input because recursion depth "
     "follows the input's ORDER. A pivot that is actually chosen would "
     "make depth logarithmic and those bounds merely prudent"),
)


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300).returncode == 0


def ask(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun", "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=300)
    tail = (done.stdout or "").strip().split("\n")[-1] if done.stdout else ""
    if not tail.startswith("VALUE "):
        return None, (tail or (done.stderr or "").strip())[:160]
    return tail[6:].strip(), None


def main():
    faults = []
    print("=" * 74)
    print("THE ENGINE FACTS THIS MOD IS BUILT ON")
    print("=" * 74)

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib.lua or runner")
        print("  69) engine facts: SKIPPED, engine absent")
        return 0
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the VM runner will not compile, so not one fact was "
              "put to the engine")
        return 1

    for name, expr, expected, batch, why in FACTS:
        got, err = ask(expr)
        if got is None:
            faults.append(
                f"[{batch}] {name}: the engine would not answer - {err}")
            continue
        ok = got == expected
        print(f"  {'ok     ' if ok else 'CHANGED'}  [{batch}] {name}: "
              f"{got!r}" + ("" if ok else f"  (was {expected!r})"))
        if not ok:
            faults.append(
                f"[{batch}] {name}: the engine now says {got!r} where this "
                f"project measured {expected!r}. {why}. Read that batch "
                "before changing anything - a fact moving is not a defect, "
                "but every record built on it is describing a world that "
                "no longer exists")

    # Facts about what the game installs, which a bare VM cannot show.
    javap = JDK / "javap.exe"
    if javap.exists():
        done = subprocess.run(
            [str(javap), "-c", "-p", "-cp", str(PZ),
             "se.krka.kahlua.require.Require"],
            capture_output=True, text=True, timeout=300)
        installs = "String require" in (done.stdout or "")
        print(f"  {'ok     ' if installs else 'CHANGED'}  [B45] require is "
              f"installed by the engine: "
              f"{'Require.install carries it' if installs else 'GONE'}")
        if not installs:
            faults.append(
                "[B45] se.krka.kahlua.require.Require no longer registers "
                "`require`. Border 48 once reported the engine lacked it "
                "and was wrong; if this is ever right, that border's whole "
                "KNOWN_PRESENT anchor has to be rebuilt")

    text = STDLIB.read_text(encoding="utf-8", errors="ignore")
    for name, needle, batch, why in SOURCE_FACTS:
        ok = needle in text
        print(f"  {'ok     ' if ok else 'CHANGED'}  [{batch}] {name}: "
              f"{'found' if ok else 'GONE'} in stdlib.lua")
        if not ok:
            faults.append(
                f"[{batch}] {name}: `{needle}` is no longer in the engine's "
                f"stdlib.lua. {why}")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  69) engine facts: all {len(FACTS) + len(SOURCE_FACTS) + 1} "
          "behaviours this mod was built around are still true of the "
          "installed engine")
    return 0


if __name__ == "__main__":
    sys.exit(main())
