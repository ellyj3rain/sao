#!/usr/bin/env python3
r"""Run counties in the engine's own VM and report what they produced.

This is not a border and it is not in the gate. It asserts nothing and
it passes nothing. A border is a point and a county is a distribution:
whether a social structure forms is a proportion over many runs, not a
verdict about one, and a build gate that turned a gradient into a
pass/fail would be forcing a deterministic result over the thing being
measured.

So it prints min, median, max and mean over N counties and stops. What
the numbers mean is the reader's to decide.

WHAT IT RUNS

The shipped modules, in Kahlua, driven through the tick handler the
mod registers with `Events.OnTick` - captured rather than replaced, so
the county runs its own real cadence and the mod carries no test hook.
Genesis builds the county through its own path from the map's own
spawn regions; nothing here places anybody.

The world is the shipped one: every town's `spawnpoints.lua` as its own
spawn region, and the buildings and room names of every cell those
towns occupy, read out of the game's `.lotheader` files. See
`tools/sweep/world.py`. It is cached beside the sweep and rebuilt when
the game's maps are newer.

Each county differs only by its save identity, which is what [C66]
seeds the whole draw from. Same code, same map, same spawn points,
same weights, different world.

WHY EACH COUNTY GETS ITS OWN PROCESS

`SAO_Population`, `SAO_Places` and `SAO_Rand` all hold module-level
state - the tick counter, the encounter cursor, the place caches, the
memoised store. Reusing a VM lets one county's leftovers decide the
next one's outcome. Slower, and the only way the runs are independent.

THE MODULE CHECK

Twice, a sweep ran to completion and reported numbers that meant
nothing because a module the loaded code calls was not loaded.

  `SpawnRegionMgr` absent: `loadRegionPoints` returned nil, genesis
  deferred forever, and every county measured had genesis switched off.
  Zero arrivals, ever, reported as a county.

  `SAO_Census` absent: `SAO.Census` was nil, nobody in any county held
  an occupation, and every call reaching it died inside a `pcall` -
  including the one that deals a company its work.

Neither failed loudly. So before any county runs, this resolves every
`SAO.X` the loaded modules reference against what is actually loaded.

A module can be correctly absent - the ones that need a body, a screen
or the player are, because a sweep is the unobserved half of the
county. Those are declared by name with the argument for each, so that
a real gap is reported on its own rather than in a list of eight
expected ones nobody reads. Anything referenced, unloaded and
undeclared is printed loudly.

It does not stop the run. It makes the gap visible instead of letting
it be discovered three conclusions later.

  python tools/county_sweep.py --runs 24
  python tools/county_sweep.py --runs 8 --lua /path/to/another/tree
"""
import argparse
import concurrent.futures
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "sweep"))
import world as World                                   # noqa: E402

SWEEP = HERE / "sweep"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
GAME = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = GAME / "projectzomboid.jar"
STDLIB = GAME / "stdlib.lua"

# Where the generated world lives. Not in the tree: it is the game's
# data, it is large, and it is only meaningful against the install
# that produced it.
CACHE = pathlib.Path(
    os.environ.get("SAO_SWEEP_CACHE")
    or (pathlib.Path(tempfile.gettempdir()) / "sao-sweep-world"))

# The modules a dormant county runs. Client modules that need a body,
# a screen or the player are absent on purpose - a sweep is the
# unobserved half of the county.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Course.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

# Modules a dormant county does not run, and the argument for each.
# An unnamed absence is what this check exists to catch, so an absence
# that is CORRECT has to be declared and argued rather than filtered
# out quietly - otherwise the check reports a real gap in the same
# breath as five expected ones and nobody reads it.
NOT_DORMANT = {
    "Appearance": "renders how a body looks; nobody is materialised",
    "Controller": "drives materialised agents; the dormant half has none",
    "Locomotion": "queues a move onto a body",
    "Needs": "acts on a body's needs through the engine",
    "Voice": "speaks aloud to a player who is present",
    "Body": "the prelude answers for it - nobody is materialised",
    "Population": "the module doing the loading names itself",
    "Telemetry": "same",
}

RUN = r'''(function()
  _G.__world = 'RUN_NAME'
  local s = ModData.getOrCreate('SurvivorAwareness_Standing')
  -- Houses EVER founded, counted at the verb. A count of house names
  -- in the store answers "standing at the end" and cannot answer
  -- this, because [C68] stopped the dead holding a roster open.
  local foundedEver = 0
  if SAO.Standing.formCompany then
    local realForm = SAO.Standing.formCompany
    SAO.Standing.formCompany = function(ids, name)
      local ok = realForm(ids, name)
      if ok then foundedEver = foundedEver + 1 end
      return ok
    end
  end
  -- No county is built here. ensurePopulation fills it through the
  -- real path, from the map's own spawn regions.
  local tick = _G.__handlers.OnTick
  for i = 1, 240 * 9000 do
    tick()
    if i % 240 == 0
      and (tonumber(s.yearsRun) or 0) >= (tonumber(s.yearsOwed) or -1) then
      break
    end
  end
  local alive, dead = 0, 0
  for _, r in pairs(SAO.Identity.all()) do
    if r.dead then dead = dead + 1 else alive = alive + 1 end
  end
  local liveGroups, inHouse, stale = {}, 0, 0
  for id, g in pairs(s.groups or {}) do
    local r = SAO.Identity.get(id)
    if r and not r.dead then
      inHouse = inHouse + 1
      liveGroups[g] = (liveGroups[g] or 0) + 1
    else
      stale = stale + 1
    end
  end
  local standing, biggest = 0, 0
  for _, n in pairs(liveGroups) do
    if n > 1 then standing = standing + 1 end
    if n > biggest then biggest = n end
  end
  local best, atLine = 0, 0
  for _, rels in pairs(s.relations or {}) do
    for _, r in pairs(rels) do
      local t = tonumber(r.trust) or 0
      if t > best then best = t end
      if t >= 0.5 then atLine = atLine + 1 end
    end
  end
  return '{"ranTo":' .. tostring(s.yearsRun)
    .. ',"alive":' .. alive .. ',"dead":' .. dead
    .. ',"housesFounded":' .. foundedEver
    .. ',"housesStanding":' .. standing
    .. ',"inAHouse":' .. inHouse
    .. ',"biggestHouse":' .. biggest
    .. ',"deadOnRosters":' .. stale
    .. ',"pairsAtLine":' .. atLine
    .. ',"bestTrust":' .. string.format('%.3f', best) .. '}'
end)()'''

COLUMNS = [
    ("alive", "survivors at the end"),
    ("dead", "died over the run"),
    ("housesFounded", "houses founded"),
    ("housesStanding", "houses standing at the end"),
    ("inAHouse", "survivors in a house"),
    ("biggestHouse", "largest house"),
    ("pairsAtLine", "pairs above the company line"),
    ("deadOnRosters", "dead still on a roster"),
]


def build_runner():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def modules_referenced(lua):
    """Every `SAO.X` the loaded modules name, and which are loaded."""
    named, loaded = set(), set()
    for rel in MODULES:
        p = lua / rel
        if not p.exists():
            continue
        loaded.add(p.stem.replace("SAO_", ""))
        text = p.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"SAO\.([A-Z][A-Za-z]*)", text):
            named.add(m.group(1))
    return sorted(named - loaded - set(NOT_DORMANT)), sorted(loaded)


def one(name, lua, owed, refill):
    prelude = (SWEEP / "prelude.lua").read_text(encoding="utf-8")
    prelude = prelude.replace("_G.__owed = 1096", "_G.__owed = %d" % owed)
    if refill is not None:
        prelude = prelude.replace("RefillDays = 2.0",
                                  "RefillDays = %s" % refill)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        pre = work / "prelude.lua"
        pre.write_text(prelude, encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(pre), str(CACHE / "map.lua"), str(SWEEP / "places.lua")]
        args += [str(lua / m) for m in MODULES if (lua / m).exists()]
        args += [str(CACHE / "regions.lua"), "--", RUN.replace("RUN_NAME", name)]
        try:
            done = subprocess.run(args, cwd=str(work), capture_output=True,
                                  text=True, timeout=3600)
        except subprocess.TimeoutExpired:
            return None
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return None
    try:
        return json.loads(out[at + 6:].strip().split("\n")[0])
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--runs", type=int, default=12)
    ap.add_argument("--days", type=int, default=1096,
                    help="days the county owes at genesis")
    ap.add_argument("--refill", default=None,
                    help="RefillDays, through the sandbox rather than the code")
    ap.add_argument("--lua", default=None,
                    help="another tree's lua root, for a before/after")
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    print("=" * 74)
    print("COUNTY SWEEP - what the shipped county produced, over %d runs"
          % args.runs)
    print("=" * 74)

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists() and GAME.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib, runner or game.")
        print("  This runs the shipped modules in the engine's own VM "
              "against the")
        print("  shipped map, so it needs the game installed. Nothing "
              "is asserted,")
        print("  so there is nothing to fail.")
        return 0

    lua = pathlib.Path(args.lua).resolve() if args.lua \
        else ROOT / "mod" / "42.20" / "media" / "lua"
    if not lua.is_dir():
        print("  no lua tree at %s" % lua)
        return 1

    missing, loaded = modules_referenced(lua)
    print("  modules loaded: %d; not run by a dormant county: %d (%s)"
          % (len(loaded), len(NOT_DORMANT), ", ".join(sorted(NOT_DORMANT))))
    if missing:
        print()
        print("  REFERENCED BY LOADED CODE, NOT LOADED, NOT DECLARED "
              "ABSENT:")
        for name in missing:
            print("      SAO.%s" % name)
        print("  Every call reaching one of those is nil, and a guarded "
              "call to it")
        print("  fails silently. Twice this has produced a complete set "
              "of numbers")
        print("  that meant nothing. Read what follows knowing which half "
              "of the")
        print("  county did not run, or load the module and run it again.")
        print()
    else:
        print("  every other SAO module the loaded code calls is loaded")

    newest = 0
    maps = World.maps_dir(GAME)
    if maps.is_dir():
        for d in maps.iterdir():
            f = d / "spawnpoints.lua"
            if f.is_file():
                newest = max(newest, f.stat().st_mtime)
    have = (CACHE / "map.lua").exists() and (CACHE / "regions.lua").exists()
    if not have or (CACHE / "map.lua").stat().st_mtime < newest:
        print("  reading the shipped world ...")
        got = World.build(GAME, CACHE)
        if not got:
            print("  no shipped maps found under %s" % maps)
            return 1
        print("  %d towns, %d spawn points, %d cells, %d buildings, "
              "%d rooms" % (got["towns"], got["points"], got["cells"],
                            got["buildings"], got["rooms"]))
        print("  spawn points inside an extracted building: %d of %d"
              % (got["pointsInABuilding"], got["points"]))
    else:
        print("  world cached at %s" % CACHE)

    if not build_runner():
        print("  LuaRun will not compile against the installed jar")
        return 1

    print("  %d counties, %d days owed, one process each%s"
          % (args.runs, args.days,
             "" if args.refill is None else ", RefillDays=%s" % args.refill))
    print()

    rows = []
    with concurrent.futures.ThreadPoolExecutor(
            max_workers=args.workers) as pool:
        futures = {pool.submit(one, "County%03d" % k, lua, args.days,
                               args.refill): k for k in range(args.runs)}
        for f in concurrent.futures.as_completed(futures):
            r = f.result()
            if r:
                rows.append(r)
                print("  run %-3d alive=%-4d founded=%-4d standing=%-3d "
                      "biggest=%-3d bestTrust=%s"
                      % (futures[f], r["alive"], r["housesFounded"],
                         r["housesStanding"], r["biggestHouse"],
                         r["bestTrust"]))
            else:
                print("  run %-3d did not finish" % futures[f])

    if not rows:
        print("\n  no county completed")
        return 1

    n = len(rows)
    print()
    print("  %d counties completed" % n)
    print("  %-32s %6s %6s %6s %8s"
          % ("", "min", "med", "max", "mean"))
    for key, label in COLUMNS:
        vals = sorted(x.get(key, 0) for x in rows)
        print("  %-32s %6d %6d %6d %8.1f"
              % (label, vals[0], vals[n // 2], vals[-1],
                 sum(vals) / float(n)))

    print()
    for label, pred in (
            ("counties that founded a house",
             lambda x: x["housesFounded"] > 0),
            ("counties with a house standing at the end",
             lambda x: x["housesStanding"] > 0),
            ("counties with anybody left alive", lambda x: x["alive"] > 0)):
        k = sum(1 for x in rows if pred(x))
        print("  %-42s %3d/%-3d (%.0f%%)"
              % (label, k, n, 100.0 * k / n))
    print()
    print("  Nothing here passed or failed. It is a proportion over %d "
          "counties." % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
