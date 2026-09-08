#!/usr/bin/env python3
r"""Border 129 - the player's looting spends a place ([C60], [B39]).

A survivor taking something calls `SAO_Places.take` and the place is
spent for everybody. The player's looting called nothing, so a shop
the player had stripped still read as full stock, `isSpent` stayed
false, and the county kept sending foragers to it. SESSION_STATE has
carried that as a standing gap since [B39].

Nothing here counts the player's actions. The engine marks a container
looted when it has been emptied - `ItemContainer.isHasBeenLooted`, a
flag SAO never writes - so the reading is the ground itself: how many
containers around the place the game says are done with. A read cannot
miss a way of taking things that nobody thought to hook.

Checked in the engine's own VM (tools/luacheck/LuaRun) against the
real SAO_Places with a stock store installed:

  * a place with more looted containers than it has takes is spent
    further, and `isSpent` turns over once the count reaches capacity;
  * the count RAISES the tally and never lowers it - a place the
    county already spent does not refill because the player walked in;
  * a count at or below what the place already had changes nothing,
    and leaves the refill stamp alone, so standing in an untouched
    room does not reset its clock;
  * a count above capacity is held at capacity;
  * zero, a negative, a missing place and a missing count all do
    nothing.

And by text: the engine method reads the engine's own flag and writes
none, the bridge exposes it, and the player's own ten-minute pass
calls it.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree has no `observeLooted` and
the county never learns.
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
PLACES = LUA / "shared" / "SAO_Places.lua"
AGE = LUA / "client" / "SAO_Age.lua"
NEEDS_JAVA = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAONeeds.java"
BRIDGE_JAVA = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
SAO.Identity = { get = function() return nil end, all = function() return {} end }
SAO.Standing = {}
SAO.Perception = {}
ModData = { getOrCreate = function(k) _G.__md = _G.__md or {}
    _G.__md[k] = _G.__md[k] or {} return _G.__md[k] end }
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return _G.__hours or 100 end } end }
getGameTime = function() return GameTime.getInstance() end
SandboxVars = { LootRespawn = 0 }
ZombRand = function(n) return 0 end
getWorld = function() return nil end
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
             # [C62] SAO_History answers what hour it is; the stub clock
             # above is what it reads.
             str(prelude), str(LUA / "shared" / "SAO_History.lua"),
             str(PLACES), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# A four-room place: capacity is whatever SAO_Places says it is, and
# the probe asks rather than assuming.
SPEND = (
    "(function() local Pl = SAO.Places "
    "local place = { id = 'shop', roomCount = 4, offers = {} } "
    "local cap = Pl.capacityOf(place) local out = {} "
    "out[#out + 1] = 'capacity=' .. cap "
    "out[#out + 1] = 'before=' .. Pl.takesAt('shop') "
    "out[#out + 1] = 'spent_before=' .. tostring(Pl.isSpent(place)) "
    "out[#out + 1] = 'first=' .. Pl.observeLooted(place, 3) "
    "out[#out + 1] = 'after_first=' .. Pl.takesAt('shop') "
    "out[#out + 1] = 'again_lower=' .. Pl.observeLooted(place, 2) "
    "out[#out + 1] = 'still=' .. Pl.takesAt('shop') "
    "out[#out + 1] = 'to_cap=' .. Pl.observeLooted(place, cap + 99) "
    "out[#out + 1] = 'at_cap=' .. Pl.takesAt('shop') "
    "out[#out + 1] = 'spent_after=' .. tostring(Pl.isSpent(place)) "
    "return table.concat(out, ' ') end)()")

# The county's own takes are never undone, and an unchanged reading
# leaves the refill stamp where it was.
GUARDS = (
    "(function() local Pl = SAO.Places "
    "local place = { id = 'yard', roomCount = 4, offers = {} } "
    "_G.__hours = 100 "
    "Pl.take(place) Pl.take(place) Pl.take(place) "
    "local countyTakes = Pl.takesAt('yard') "
    "local store = ModData.getOrCreate('SurvivorAwareness_Places') "
    "_G.__hours = 500 "
    "local none = Pl.observeLooted(place, 2) "
    "local afterLower = Pl.takesAt('yard') "
    "local stampHeld = (store.taken and store.taken['yard'] "
    "  and store.taken['yard'].at) or -1 "
    "local zero = Pl.observeLooted(place, 0) "
    "local negative = Pl.observeLooted(place, -5) "
    "local noPlace = Pl.observeLooted(nil, 4) "
    "local noCount = Pl.observeLooted(place, nil) "
    "return 'county=' .. countyTakes .. ' lower_did=' .. none "
    ".. ' after_lower=' .. afterLower .. ' stamp=' .. stampHeld "
    ".. ' zero=' .. zero .. ' negative=' .. negative "
    ".. ' noplace=' .. noPlace .. ' nocount=' .. noCount end)()")


def main():
    faults = []
    print("=" * 74)
    print("THE PLAYER'S LOOTING SPENDS A PLACE")
    print("=" * 74)
    if not PLACES.exists():
        print("  FAULT: SAO_Places.lua does not exist")
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib or runner")
        print("  129) the player's looting spends a place: SKIPPED,"
              " the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    spend = numbers(value(probe(SPEND)))
    print("     spending: " + " ".join("%s=%s" % kv for kv in spend.items()))
    try:
        cap = int(spend["capacity"])
        want = {"before": "0", "spent_before": "false", "first": "3",
                "after_first": "3", "again_lower": "0", "still": "3",
                "at_cap": str(cap), "spent_after": "true"}
        for k, v in want.items():
            if spend.get(k) != v:
                faults.append("spending: %s is %s, wanted %s"
                              % (k, spend.get(k), v))
        if int(spend.get("to_cap", -1)) != cap - 3:
            faults.append("a reading above capacity raised the tally by %s; "
                          "capacity is %d and it had 3"
                          % (spend.get("to_cap"), cap))
    except (KeyError, ValueError):
        faults.append("the spending probe did not answer: %r" % spend)

    guards = numbers(value(probe(GUARDS)))
    print("     guards:   " + " ".join("%s=%s" % kv for kv in guards.items()))
    wantG = {"county": "3", "lower_did": "0", "after_lower": "3",
             "stamp": "100", "zero": "0", "negative": "0",
             "noplace": "0", "nocount": "0"}
    for k, v in wantG.items():
        if guards.get(k) != v:
            faults.append("guards: %s is %s, wanted %s - %s"
                          % (k, guards.get(k), v,
                             "the county's own takes must never be undone by "
                             "a reading, and an unchanged reading must leave "
                             "the refill stamp alone"))

    needs, bridge, age = read(NEEDS_JAVA), read(BRIDGE_JAVA), read(AGE)
    seams = {
        "the engine's own flag is what is read":
            "c.isHasBeenLooted()" in needs
            and "setHasBeenLooted" not in needs,
        "the read writes nothing":
            "public static String lootedNearby(IsoPlayer shell, int radius)" in needs
            and "setExplored" not in needs,
        "the bridge exposes it":
            "public String lootedNearby(Object object, int radius)" in bridge,
        "the player's own pass calls it":
            "function Age.playerLoots(player)" in age
            and "Age.playerLoots(me)" in age,
        "it goes through the place ledger, not around it":
            "SAO.Places.observeLooted(place, looted)" in age,
        "the tally is raised, never lowered":
            "if lootedCount <= had then return 0 end" in read(PLACES),
        "the gate runs this border":
            "tools/player_looting_test.py" in read(CHECK),
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
    print("  129) the player's looting spends a place: read off the engine's "
          "own looted flag, raising the county's tally and never lowering it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
