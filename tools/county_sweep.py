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

THE ENGINE MODE

`--engine` exposes the real shipped bridge and loads the game's own
data through it: the name pools, filled by the game's own fill
functions, and the profession definitions, registered by the game's
own two-phase script pass over its own generated files. A county run
this way names its people and skills its work with the engine's data.

It is a DIFFERENT county from the same save name run without the
flag. A name costs two county draws at `Identity.create`, and
`listProfessions` grows the catalog the occupation draw runs against,
so the draws diverge from the first person onward. [C66] holds per
harness shape: same name plus `--engine` reproduces the engine county,
same name without it reproduces the plain one, and neither reproduces
the other. The ratified rows cite plain dumps, which is why the mode
is a flag and not the default.

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
ENGINE_SRC = HERE / "luacheck" / "LuaRunEngine.java"
OUT = ROOT / "java" / "out" / "luacheck"
KAHLUA = HERE / "lib" / "kahlua-j2se.jar"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
GAME = pathlib.Path(
    os.environ.get("SAO_GAME")
    or r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = GAME / "projectzomboid.jar"
STDLIB = GAME / "stdlib.lua"
# The mod's own jar, tracked in the mod tree where build-java.sh
# copies it ([B33]) - the same bridge the game loads. Engine mode puts
# it on the classpath so LuaRun can expose it.
SAO_JAR = ROOT / "mod" / "42.20" / "media" / "java" / "SAO.jar"
# The game's own name-pool fill file, and the harness chunk that calls
# its fill functions by name - boot events never fire headless.
ENGINE_FILL_LUA = GAME / "media" / "lua" / "shared" / "NPCs" / \
    "MainCreationMethods.lua"

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
    "shared/SAO_Course.lua", "shared/SAO_Neuro.lua",
    "shared/SAO_Trajectory.lua",
    "shared/SAO_Adaptation.lua", "shared/SAO_Isolation.lua",
    "shared/SAO_Organization.lua", "shared/SAO_Settlement.lua",
    "shared/SAO_Material.lua", "shared/SAO_Recognition.lua",
    "shared/SAO_Communication.lua", "shared/SAO_GraphPersistence.lua",
    "shared/SAO_Integration.lua", "shared/SAO_Branching.lua",
    "shared/SAO_Labor.lua", "shared/SAO_PathogenPressure.lua",
    "shared/SAO_PlaceAttachment.lua", "shared/SAO_PlayerInteraction.lua",
    "shared/SAO_Pressure.lua", "shared/SAO_WorldDevelopment.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_PathogenEvents.lua", "shared/SAO_WorldGenesis.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_AfflictedReturn.lua", "client/SAO_Nuke.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

# ZAO's dormant half, loaded when the sister tree is present
# (`ZAO_ROOT` or `../zombie-awareness`). The years already call
# `SAO.PathogenEvents.simulateDay`; without these modules that call
# returns false and the unwatched county has no pathogen.
ZAO_MODULES = [
    "shared/ZAO_Sandbox.lua",
    "shared/ZAO_StateStore.lua",
    "shared/ZAO_State.lua",
    "shared/ZAO_Forms.lua",
    "shared/ZAO_Pathogen.lua",
    "shared/ZAO_Recovery.lua",
    "shared/ZAO_Settlement.lua",
    "shared/ZAO_Binding.lua",
    "shared/ZAO_API.lua",
]


def zao_root():
    env = os.environ.get("ZAO_ROOT")
    if env:
        p = pathlib.Path(env)
        if (p / "mod" / "42.20" / "media" / "lua" / "shared"
                / "ZAO_Pathogen.lua").exists():
            return p
    sibling = ROOT.parent / "zombie-awareness"
    if (sibling / "mod" / "42.20" / "media" / "lua" / "shared"
            / "ZAO_Pathogen.lua").exists():
        return sibling
    return None

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
    "Driving": "drives materialised vehicles; dormant half has no vehicle drivers",
    "UI": "renders player UI widgets; dormant half has no screen",
    "MedicalWindow": "renders doctor UI window; dormant half has no screen",
    "Inspect": "renders inspection window; dormant half has no screen",
    "Harness": "manages local client test harness and body loops",
    "Gesture": "plays physical character animations; dormant half has no bodies",
    "Exchange": "handles active trade window; dormant half has no screen",
    "Drugs": "administers ingested items to active bodies; dormant half has no inventory",
    "Medical": "performs timed first aid actions; dormant half has no bodies",
    "Absorb": "absorbs items from containers into body",
    "Animals": "interacts with animal bodies; dormant half has no animals",
    "Neighbours": "scans spatial grids for loaded zombies",
    "Sandbox": "manages sandbox options GUI",
    "RadioEar": "listens to audio frequencies on held radio",
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
  local standing, biggest, of3 = 0, 0, 0
  for _, n in pairs(liveGroups) do
    if n > 1 then standing = standing + 1 end
    if n >= 3 then of3 = of3 + 1 end
    if n > biggest then biggest = n end
  end
  local pacts = 0
  do
    local seenP = {}
    for g, n in pairs(liveGroups) do
      if n > 1 and not seenP[g] and SAO.Standing.pactPartnerOf then
        local p = SAO.Standing.pactPartnerOf(g)
        if p then
          seenP[g] = true
          seenP[tostring(p)] = true
          pacts = pacts + 1
        end
      end
    end
  end
  local best, atLine = 0, 0
  for _, rels in pairs(s.relations or {}) do
    for _, r in pairs(rels) do
      local t = tonumber(r.trust) or 0
      if t > best then best = t end
      if t >= 0.5 then atLine = atLine + 1 end
    end
  end
  local totalNeuro, afflictedCount = 0, 0
  for _, r in pairs(SAO.Identity.all()) do
    if not r.dead then
      local n = tonumber(r.neuroinflammation) or 0
      totalNeuro = totalNeuro + n
      if n >= 0.30 then afflictedCount = afflictedCount + 1 end
    end
  end
  local meanNeuro = alive > 0 and (totalNeuro / alive) or 0
  return '{"ranTo":' .. tostring(s.yearsRun)
    .. ',"alive":' .. alive .. ',"dead":' .. dead
    .. ',"housesFounded":' .. foundedEver
    .. ',"housesStanding":' .. standing
    .. ',"housesOf3":' .. of3
    .. ',"pacts":' .. pacts
    .. ',"inAHouse":' .. inHouse
    .. ',"biggestHouse":' .. biggest
    .. ',"deadOnRosters":' .. stale
    .. ',"pairsAtLine":' .. atLine
    .. ',"bestTrust":' .. string.format('%.3f', best)
    .. ',"meanNeuro":' .. string.format('%.3f', meanNeuro)
    .. ',"afflicted":' .. afflictedCount .. '}'
end)()'''

COLUMNS = [
    ("alive", "survivors at the end"),
    ("dead", "died over the run"),
    ("housesFounded", "houses founded"),
    ("housesStanding", "houses standing at the end"),
    ("housesOf3", "standing houses of three or more"),
    ("pacts", "pacts between standing houses"),
    ("inAHouse", "survivors in a house"),
    ("biggestHouse", "largest house"),
    ("pairsAtLine", "pairs above the company line"),
    ("deadOnRosters", "dead still on a roster"),
    ("meanNeuro", "mean neuroinflammation"),
    ("afflicted", "afflicted survivors"),
]


def java_home_bin(name):
    """`java` / `javac` from the Windows install, JAVA_HOME, or PATH."""
    win = JDK / (name + ".exe")
    if win.exists():
        return str(win)
    home = os.environ.get("JAVA_HOME")
    if home:
        for n in (name + ".exe", name):
            p = pathlib.Path(home) / "bin" / n
            if p.exists():
                return str(p)
    found = shutil.which(name)
    if found:
        return found
    return None


def vm_classpath(engine=False):
    """Classpath for LuaRun. Game jar if present, else bundled Kahlua."""
    sep = os.pathsep
    if engine and PZ.exists() and SAO_JAR.exists():
        return sep.join([str(PZ), str(SAO_JAR), "."])
    if PZ.exists():
        return sep.join([str(PZ), "."])
    if KAHLUA.exists():
        return sep.join([str(KAHLUA), "."])
    return "."


def has_world():
    return (CACHE / "map.lua").exists() and (CACHE / "regions.lua").exists()


def has_vm():
    return PZ.exists() or KAHLUA.exists()


def build_runner():
    cls = OUT / "LuaRun.class"
    javac = java_home_bin("javac")
    if not javac:
        return False
    sources = [SRC]
    cp = str(PZ) if PZ.exists() else str(KAHLUA)
    if PZ.exists() and ENGINE_SRC.exists():
        sources.append(ENGINE_SRC)
    newest_src = max(p.stat().st_mtime for p in sources if p.exists())
    if cls.exists() and cls.stat().st_mtime >= newest_src:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [javac, "-cp", cp, "-d", str(OUT)] + [str(p) for p in sources],
        capture_output=True, text=True, timeout=300)
    if done.returncode != 0:
        sys.stderr.write(done.stderr or done.stdout or "javac failed\n")
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


def one(name, lua, owed, refill, engine=False):
    java = java_home_bin("java")
    if not java:
        return None
    prelude = (SWEEP / "prelude.lua").read_text(encoding="utf-8")
    prelude = prelude.replace("_G.__owed = 1096", "_G.__owed = %d" % owed)
    if refill is not None:
        prelude = prelude.replace("RefillDays = 2.0",
                                  "RefillDays = %s" % refill)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        if STDLIB.exists():
            shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        pre = work / "prelude.lua"
        pre.write_text(prelude, encoding="utf-8")
        args = [java, "-cp", vm_classpath(engine), "LuaRun"]
        if engine:
            args += ["--engine", str(GAME)]
        args += [str(pre)]
        if engine:
            # The game's own fill file, then the chunk that calls its
            # fill functions - before the mod's modules, which is the
            # game's own load order: engine Lua first, mod Lua after.
            args += [str(ENGINE_FILL_LUA), str(SWEEP / "engine_fill.lua")]
        args += [str(CACHE / "map.lua"), str(SWEEP / "places.lua")]
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
        err = (done.stderr or "") + out
        if err:
            sys.stderr.write(err[-4000:] + "\n")
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
    ap.add_argument("--engine", action="store_true",
                    help="expose the real bridge and load the game's own "
                         "name pools and profession definitions; a "
                         "different county from the same name (see the "
                         "engine mode above)")
    args = ap.parse_args()

    print("=" * 74)
    print("COUNTY SWEEP - what the shipped county produced, over %d runs"
          % args.runs)
    print("=" * 74)

    if not (SRC.exists() and has_vm() and (GAME.exists() or has_world())):
        print("  SKIPPED - no Kahlua VM (game jar or tools/lib/kahlua-j2se.jar),")
        print("  runner, or world cache. The sweep needs the shipped map")
        print("  (SAO_SWEEP_CACHE) or the game install. Nothing is asserted,")
        print("  so there is nothing to fail.")
        return 0
    if args.engine and not SAO_JAR.exists():
        print("  the mod jar is not built (%s)." % SAO_JAR)
        print("  Engine mode exposes the shipped bridge, so build it "
              "first: bash tools/build-java.sh")
        return 1
    if args.engine and not ENGINE_FILL_LUA.exists():
        print("  the game's own fill file is not where this install "
              "has it (%s)" % ENGINE_FILL_LUA)
        return 1

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

    print("  %d counties, %d days owed, one process each%s%s"
          % (args.runs, args.days,
             "" if args.refill is None else ", RefillDays=%s" % args.refill,
             ", engine data on" if args.engine else ""))
    if args.engine:
        print("  engine data on: real name pools and profession "
              "definitions,")
        print("  exposed through the shipped bridge. Same name plus "
              "--engine")
        print("  reproduces this county; without it the plain county - "
              "a different")
        print("  one - answers ([C66] per harness shape).")
    print()

    rows = []
    with concurrent.futures.ThreadPoolExecutor(
            max_workers=args.workers) as pool:
        futures = {pool.submit(one, "County%03d" % k, lua, args.days,
                               args.refill, args.engine)
                   : k for k in range(args.runs)}
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
