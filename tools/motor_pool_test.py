#!/usr/bin/env python3
r"""Border 126 - the objection picks the car, it does not end the
question ([C54], Day Zero slice 5).

A house's motor pool holds every car the quartermaster appraised, and
`SAO_Standing.roadworthy` returned exactly one of them - the roomiest
openable runner. The venture then applied the goer's own objection to
that one car: somebody who has learned that noise is a debt refuses a
loud one and walks ([B19], and the refusal is right). With one car
returned, the refusal discarded the whole yard. A house with a loud
six-seater and a quiet hatchback sent that person out on foot.

The ceiling goes in with the ask now, so what comes back is the
roomiest car this person would actually take, and the walk only
happens when the yard holds nothing quiet enough.

Run against the real `SAO_Standing.roadworthy` in the engine's own VM
(tools/luacheck/LuaRun), over pools built for the cases that matter:

  * a yard with a loud roomy runner and a quiet small one returns the
    loud one to a caller with no ceiling, and the quiet one to a
    caller with one - which is the defect, stated as a pair;
  * a yard of only loud runners returns nothing under a ceiling, so
    the walk survives where it was always right;
  * the ceiling never changes the answer for a caller that passes
    none, so the panel reads what it always read;
  * openability still outranks room, and room still breaks ties,
    under a ceiling as without one;
  * a car that does not run is never returned, ceiling or no.

And by text: the venture asks with the goer's own ceiling, and the
second loudness test at the call site is gone rather than left
sitting dead.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree returns the loud car to a
caller that refuses it.
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
STANDING = LUA / "shared" / "SAO_Standing.lua"
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# Standing is a large module with engine reads at load; the probe
# gives it the little it needs and then installs a motor pool by hand.
PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
SAO.Identity = { get = function() return nil end, all = function() return {} end }
SAO.Hash = { of = function() return 0 end, unit = function() return 0.5 end }
SAO.Disposition = { traits = function() return {} end }
SAO.Lessons = { has = function() return false end, weight = function() return 0 end }
ModData = { getOrCreate = function(k) _G.__md = _G.__md or {} ; _G.__md[k] = _G.__md[k] or {} ; return _G.__md[k] end }
GameTime = { getInstance = function() return { getWorldAgeHours = function() return 100 end } end }
getGameTime = function() return GameTime.getInstance() end
ZombRand = function(n) return 0 end
'''

# name, seats, free, loud, fuel, engine, ignition
POOLS = {
    # The defect's own shape: a loud roomy runner beside a quiet one.
    "mixed": [("LoudSix", 6, 5, 80, 60, 90, 1),
              ("QuietTwo", 2, 1, 20, 60, 90, 1)],
    # Only loud runners: the walk is right and must survive.
    "allloud": [("LoudSix", 6, 5, 80, 60, 90, 1),
                ("LoudFour", 4, 3, 70, 60, 90, 1)],
    # Openability outranks room, under a ceiling as without one.
    "locked": [("LockedSix", 6, 5, 10, 60, 90, 0),
               ("OpenTwo", 2, 1, 10, 60, 90, 1)],
    # A wreck is never returned.
    "wrecks": [("DryEight", 8, 7, 10, 0, 90, 1),
               ("DeadEight", 8, 7, 10, 60, 5, 1),
               ("GoodTwo", 2, 1, 10, 60, 90, 1)],
}


def pool_lua(name):
    cars = []
    for n, seats, free, loud, fuel, engine, ign in POOLS[name]:
        cars.append("{ name = '%s', seats = %d, free = %d, loud = %d, "
                    "fuel = %d, engine = %d, ignition = %d }"
                    % (n, seats, free, loud, fuel, engine, ign))
    return ("local s = ModData.getOrCreate('SurvivorAwareness_Standing') "
            "s.groupMeta = s.groupMeta or {} "
            "s.groupMeta['h'] = { motorPool = { atHours = 100, cars = { "
            + ", ".join(cars) + " } } } ")


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
             # [C62] SAO_History answers what hour it is; the stub clock
             # above is what it reads.
             str(prelude), str(LUA / "shared" / "SAO_History.lua"),
             str(STANDING), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


def ask(pool, *asks):
    """One probe over one pool: a list of (label, ceiling-or-nil)."""
    parts = ["(function() " + pool_lua(pool) + "local out = {} "]
    for label, ceiling in asks:
        parts.append(
            "do local c = SAO.Standing.roadworthy('h', %s) "
            "out[#out + 1] = '%s=' .. (c and tostring(c.name) or 'none') end "
            % (ceiling, label))
    parts.append("return table.concat(out, ' ') end)()")
    return numbers(value(probe("".join(parts))))


def main():
    faults = []
    print("=" * 74)
    print("THE OBJECTION PICKS THE CAR")
    print("=" * 74)
    if not STANDING.exists():
        print("  FAULT: SAO_Standing.lua does not exist")
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        # [C56] SKIPPED, not a finding. This border reads the installed
        # game, and a machine without it - CI, or anybody's clone - is
        # not a machine with a defect. A check that cannot run must
        # never look like a check that passed either, so it says so
        # twice and the gate prints it.
        print("  SKIPPED - no JDK, engine jar, stdlib or runner")
        print("  126) the objection picks the car: SKIPPED, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    mixed = ask("mixed", ("nofilter", "nil"), ("quiet", "50"))
    print("     a loud roomy runner beside a quiet one: "
          + " ".join("%s=%s" % kv for kv in mixed.items()))
    if mixed.get("nofilter") != "LoudSix":
        faults.append("with no ceiling the roomiest runner should still win; "
                      "got %s" % mixed.get("nofilter"))
    if mixed.get("quiet") != "QuietTwo":
        faults.append("a goer who refuses a loud car got %s - the pool holds "
                      "a quiet runner and the refusal is still discarding it"
                      % mixed.get("quiet"))

    allloud = ask("allloud", ("nofilter", "nil"), ("quiet", "50"))
    print("     only loud runners:                      "
          + " ".join("%s=%s" % kv for kv in allloud.items()))
    if allloud.get("nofilter") != "LoudSix":
        faults.append("with no ceiling the roomiest runner should win; got %s"
                      % allloud.get("nofilter"))
    if allloud.get("quiet") != "none":
        faults.append("a yard of loud runners answered %s under a ceiling; "
                      "the walk is right there and must survive"
                      % allloud.get("quiet"))

    locked = ask("locked", ("nofilter", "nil"), ("quiet", "50"))
    print("     a locked six beside an open two:        "
          + " ".join("%s=%s" % kv for kv in locked.items()))
    for k in ("nofilter", "quiet"):
        if locked.get(k) != "OpenTwo":
            faults.append("openability must outrank room (%s answered %s)"
                          % (k, locked.get(k)))

    wrecks = ask("wrecks", ("nofilter", "nil"), ("quiet", "50"))
    print("     two wrecks and a runner:                "
          + " ".join("%s=%s" % kv for kv in wrecks.items()))
    for k in ("nofilter", "quiet"):
        if wrecks.get(k) != "GoodTwo":
            faults.append("a car that does not run was returned (%s answered "
                          "%s)" % (k, wrecks.get(k)))

    ctl, st = read(CONTROLLER), read(STANDING)
    seams = {
        "the appraisal takes a loudness ceiling":
            "function S.roadworthy(groupName, loudCeiling)" in st
            and "if runs and loudCeiling and (c.loud or 0) >= loudCeiling then" in st,
        "the venture asks with the goer's own ceiling":
            'if SAO.Lessons.has(id, "noise-is-a-debt") then' in ctl
            and "SAO.Standing.roadworthy(gW, ceiling)" in ctl,
        "the second loudness test is gone rather than left dead":
            "local tooLoud" not in ctl
            and "too loud to" not in ctl,
        "the walk is still said when the yard holds nothing quiet":
            "quiet enough to be worth it" in ctl,
        "the panel still asks the way it always did":
            "SAO.Standing.roadworthy(g) or nil" in read(LUA / "client" / "SAO_UI.lua"),
        "the gate runs this border":
            "tools/motor_pool_test.py" in read(CHECK),
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
    print("  126) the objection picks the car: a goer who refuses a loud one "
          "gets the quiet one out of the same yard, and walks only when there "
          "is nothing quiet to take")
    return 0


if __name__ == "__main__":
    sys.exit(main())
