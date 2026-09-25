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

Missing required modules stop the run. A partial county is never admitted
to an aggregate as a completed simulation.

  python tools/county_sweep.py --runs 24
  python tools/county_sweep.py --runs 8 --lua /path/to/another/tree
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import functools
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

# Sister project ZAO modules for real pathogen and state tracking
ZAO_ROOT = ROOT.parent / "zombie-awareness" / "mod" / "42.20" / "media" / "lua"
ZAO_MODULES = [
    "shared/ZAO_Sandbox.lua",
    "shared/ZAO_Forms.lua",
    "shared/ZAO_StateStore.lua",
    "shared/ZAO_Brain.lua",
    "shared/ZAO_State.lua",
    "shared/ZAO_Maintenance.lua",
    "shared/ZAO_Mind.lua",
    "shared/ZAO_Recovery.lua",
    "shared/ZAO_Settlement.lua",
    "shared/ZAO_Pathogen.lua",
    "shared/ZAO_API.lua",
]

# The modules a dormant county runs. Client modules that need a body,
# a screen or the player are absent on purpose - a sweep is the
# unobserved half of the county.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Course.lua", "shared/SAO_Neuro.lua",
    "shared/SAO_Adaptation.lua", "shared/SAO_Isolation.lua",
    "shared/SAO_Organization.lua", "shared/SAO_Settlement.lua",
    "shared/SAO_Material.lua", "shared/SAO_Recognition.lua",
    "shared/SAO_Communication.lua", "shared/SAO_GraphPersistence.lua",
    "shared/SAO_Integration.lua", "shared/SAO_Branching.lua",
    "shared/SAO_Labor.lua", "shared/SAO_PathogenPressure.lua",
    "shared/SAO_PlaceAttachment.lua", "shared/SAO_PlayerInteraction.lua",
    "shared/SAO_Pressure.lua", "shared/SAO_WorldDevelopment.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_BodySnapshot.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_WorldKnowledge.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_PathogenEvents.lua", "shared/SAO_WorldGenesis.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "shared/SAO_WorldSources.lua", "shared/SAO_Provisioning.lua",
    "client/SAO_CrossedTransfer.lua", "client/SAO_AfflictedReturn.lua",
    "client/SAO_Nuke.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "shared/SAO_PhysicalFacts.lua",
    "client/SAO_PopulationAdmissions.lua", "client/SAO_PopulationRepresentation.lua",
    "client/SAO_DormantPopulation.lua",
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
    "Handover": "executes native item actions between materialised bodies; dormant exchange remains unimplemented",
    "Treatment": "executes patient-bound native bandaging on materialised bodies; dormant treatment remains unimplemented",
    "SourceUse": "executes source actions on materialised bodies; dormant capture reports the absent executor",
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
  local evidence = SAOSweepEvidence.begin()
  local s = ModData.getOrCreate('SurvivorAwareness_Standing')
  -- No county is built here. ensurePopulation fills it through the
  -- real path, from the map's own spawn regions.
  local tick = _G.__handlers.OnTick
  for i = 1, 240 * 9000 do
    tick()
    evidence.observe()
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
  local ge4, ge8, ge15 = 0, 0, 0
  for _, n in pairs(liveGroups) do
    if n > 1 then
      standing = standing + 1
      if n >= 4 then ge4 = ge4 + 1 end
      if n >= 8 then ge8 = ge8 + 1 end
      if n >= 15 then ge15 = ge15 + 1 end
    end
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
  local totalNeuro, afflictedCount = 0, 0
  local infectedCount, turnedCount = 0, 0
  for _, r in pairs(SAO.Identity.all()) do
    if not r.dead then
      local n = tonumber(r.neuroinflammation) or 0
      totalNeuro = totalNeuro + n
      if r.pathogenState and r.pathogenState.terminalState == 'afflicted' then
        afflictedCount = afflictedCount + 1
      end
      if r.knoxInfected then infectedCount = infectedCount + 1 end
    else
      if r.turnedDormant then turnedCount = turnedCount + 1 end
    end
  end
  local zTurned, zDead, zInfected, zAfflicted, zCrossed = 0, 0, 0, 0, 0
  if ZAO and ZAO.StateStore then
    local store = ZAO.StateStore.store()
    if store and store.people then
      for _, p in pairs(store.people) do
        local t = p.terminalState
        if t == "turned" then zTurned = zTurned + 1
        elseif t == "dead" then zDead = zDead + 1
        elseif t == "infected" then zInfected = zInfected + 1
        elseif t == "afflicted" then zAfflicted = zAfflicted + 1
        elseif t == "crossed" then zCrossed = zCrossed + 1
        end
      end
    end
  end
  local pactCount = 0
  for _, meta in pairs(s.groupMeta or {}) do
    if meta.pactWith then
      for _, v in pairs(meta.pactWith) do
        if v == true then pactCount = pactCount + 1 end
      end
    end
  end
  pactCount = math.floor(pactCount / 2)
  local meanNeuro = alive > 0 and (totalNeuro / alive) or 0
  local detail = evidence.finish()
  return '{"ranTo":' .. tostring(s.yearsRun)
    .. ',"yearsTicks":' .. tostring(s.yearsTicks or 0)
    .. ',"evidence":' .. detail
    .. ',"alive":' .. alive .. ',"dead":' .. dead
    .. ',"housesStanding":' .. standing
    .. ',"inAHouse":' .. inHouse
    .. ',"biggestHouse":' .. biggest
    .. ',"housesGe4":' .. ge4
    .. ',"housesGe8":' .. ge8
    .. ',"housesGe15":' .. ge15
    .. ',"pacts":' .. pactCount
    .. ',"deadOnRosters":' .. stale
    .. ',"pairsAtLine":' .. atLine
    .. ',"bestTrust":' .. string.format('%.3f', best)
    .. ',"meanNeuro":' .. string.format('%.3f', meanNeuro)
    .. ',"afflicted":' .. afflictedCount
    .. ',"infected":' .. infectedCount
    .. ',"turned":' .. turnedCount
    .. ',"zaoTurned":' .. zTurned
    .. ',"zaoDead":' .. zDead
    .. ',"zaoInfected":' .. zInfected
    .. ',"zaoAfflicted":' .. zAfflicted
    .. ',"zaoCrossed":' .. zCrossed .. '}'
end)()'''

COLUMNS = [
    ("alive", "survivors at the end"),
    ("dead", "died over the run"),
    ("housesFounded", "houses founded"),
    ("survivorsJoined", "survivors joined a house"),
    ("housesStanding", "houses standing at the end"),
    ("inAHouse", "survivors in a house"),
    ("biggestHouse", "largest house"),
    ("housesGe4", "houses >= 4 members"),
    ("housesGe8", "houses >= 8 members"),
    ("housesGe15", "houses >= 15 members"),
    ("pacts", "house pacts"),
    ("pairsAtLine", "pairs above the company line"),
    ("deadOnRosters", "dead still on a roster"),
    ("meanNeuro", "mean neuroinflammation"),
    ("afflicted", "afflicted survivors"),
    ("infected", "infected survivors"),
    ("turned", "turned to zombies"),
    ("zaoTurned", "ZAO recorded turned"),
    ("zaoDead", "ZAO recorded dead"),
    ("zaoInfected", "ZAO recorded infected"),
    ("zaoAfflicted", "ZAO recorded afflicted"),
    ("zaoCrossed", "ZAO recorded crossed"),
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
        # A compatibility module may publish more than its filename (for
        # example the generalized ZAO-person transfer while retaining the
        # historical CrossedTransfer alias). Those explicit owners are loaded,
        # not missing modules.
        for owner in re.finditer(r"SAO\.([A-Z][A-Za-z]*)\s*=", text):
            loaded.add(owner.group(1))
        for m in re.finditer(r"SAO\.([A-Z][A-Za-z]*)", text):
            named.add(m.group(1))
    return sorted(named - loaded - set(NOT_DORMANT)), sorted(loaded)


class EvidenceError(RuntimeError):
    """The run cannot support a completed simulation claim."""


def sha256(path):
    digest = hashlib.sha256()
    with pathlib.Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def cell_span():
    return _cell_span(str(PZ), PZ.stat().st_mtime_ns)


@functools.lru_cache(maxsize=2)
def _cell_span(path, modified):
    done = subprocess.run([str(JDK / 'javap.exe'), '-classpath', str(PZ), '-c',
                           'zombie.iso.IsoCell'], capture_output=True, text=True, timeout=60)
    match = re.search(r'public static int getCellSizeInSquares\(\);\s+Code:\s+'
                      r'0:\s+(?:sipush|bipush)\s+(\d+)\s+3:\s+ireturn', done.stdout)
    if done.returncode or not match:
        raise EvidenceError('installed cell span could not be verified from IsoCell bytecode')
    return int(match.group(1))


def require_modules(lua, joint=False):
    paths = [lua / rel for rel in MODULES]
    if joint:
        paths = [ZAO_ROOT / rel for rel in ZAO_MODULES] + paths
    absent = [str(path) for path in paths if not path.is_file()]
    missing, _ = modules_referenced(lua)
    if absent or missing:
        raise EvidenceError('missing simulation modules: ' + ', '.join(absent + missing))
    if joint:
        loaded = {path.stem.removeprefix('ZAO_') for path in paths if path.name.startswith('ZAO_')}
        named = set()
        for path in paths:
            named.update(re.findall(r'ZAO\.([A-Z][A-Za-z]*)', path.read_text(encoding='utf-8')))
        # Controller and Driver require loaded bodies; the dormant seam advances
        # pathogen and maintenance state directly from durable person records.
        absent = named - loaded - {'Controller', 'Driver'}
        if absent:
            raise EvidenceError('unloaded joint pathogen modules: ' + ', '.join(sorted(absent)))
    return paths


def validate_result(result, owed, engine=False, engine_counts=None, joint=False):
    """Completion and observability are requirements; outcomes never are."""
    if result.get('ranTo') != owed:
        raise EvidenceError('incomplete horizon: requested %s, completed %s'
                            % (owed, result.get('ranTo')))
    if result.get('yearsTicks') != owed * 216000:
        raise EvidenceError('completed-day claim does not match the county clock')
    if result.get('alive', 0) + result.get('dead', 0) <= 0:
        raise EvidenceError('empty county; genesis did not produce people')
    detail = result.get('evidence', {})
    if detail.get('faultCount') != 0:
        raise EvidenceError('protected callback failures: %s' % detail.get('faults', detail))
    if not detail.get('seed'):
        raise EvidenceError('county seed absent')
    if engine and (not engine_counts or any(n <= 0 for n in engine_counts.values())):
        raise EvidenceError('engine name pools or profession registry absent')
    if joint and detail.get('callbackCounts', {}).get('simulateDay', 0) < owed:
        raise EvidenceError('joint pathogen daily callback did not cover the horizon')
    return result


HISTORY_ORIGIN = datetime.date(1993, 7, 9)


def calendar_fields(date):
    return {'iso': date.isoformat(), 'year': date.year,
            'month0': date.month - 1, 'day0': date.day - 1}


def evidence_host(owed):
    target = HISTORY_ORIGIN + datetime.timedelta(days=owed)
    epoch_ms = (target - datetime.date(1970, 1, 1)).days * 86400000
    return ((SWEEP / 'evidence_host.lua').read_text(encoding='utf-8')
            .replace('SWEEP_CELL_SPAN', str(cell_span()))
            .replace('SWEEP_START_EPOCH_MS', str(epoch_ms)))


def provenance(name, lua, owed, refill, population, engine, joint, paths):
    loaded = {str(path): sha256(path) for path in paths}
    host = [PZ, STDLIB, SRC, OUT / 'LuaRun.class', JDK / 'java.exe', JDK.parent / 'release',
            SWEEP / 'prelude.lua', SWEEP / 'places.lua',
            SWEEP / 'evidence.lua', SWEEP / 'evidence_host.lua', pathlib.Path(__file__),
            CACHE / 'map.lua', CACHE / 'regions.lua']
    if engine:
        host += [SAO_JAR, ENGINE_FILL_LUA, SWEEP / 'engine_fill.lua',
                 GAME / 'media/scripts/generated/characters/character_traits.txt',
                 GAME / 'media/scripts/generated/characters/character_professions.txt']
    source_hashes = {str(path): sha256(path) for path in host}
    return {'schema': 'sao-simulation-evidence-v1', 'saveName': name,
            'runtime': 'Kahlua from the installed Project Zomboid jar',
            'requestedDays': owed, 'engineData': engine, 'jointPathogen': joint,
            'populationOverride': population, 'refillOverride': refill,
            'historyOrigin': calendar_fields(HISTORY_ORIGIN),
            'startCalendar': calendar_fields(HISTORY_ORIGIN + datetime.timedelta(days=owed)),
            'calendarPolicy': 'Exact Gregorian origin plus elapsed days; game starts at target midnight.',
            'cohortPolicy': 'Independent initialization per horizon; actual seed includes target start date.',
            'cellSpanFromInstalledBytecode': cell_span(),
            'loadedModules': loaded, 'moduleLoadOrder': [str(path) for path in paths],
            'sourceHashes': source_hashes,
            'limits': ['Dormant records only; no loaded bodies or physical actions.',
                       'Map rooms and spawnpoints from installed game.',
                       'Claim chunk surveys unavailable; no fabricated boarding.',
                       'Production birth year derives from target start year; horizons are not one cohort.']}


def one(name, lua, owed, refill, population=None, engine=False, joint=False,
        timeout=3600):
    lua = pathlib.Path(lua)
    if owed <= 0 or not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
        raise EvidenceError('positive calendar days and a safe save name are required')
    paths = require_modules(lua, joint)
    identity = provenance(name, lua, owed, refill, population, engine, joint, paths)
    prelude = (SWEEP / "prelude.lua").read_text(encoding="utf-8")
    prelude = prelude.replace("_G.__owed = 1096", "_G.__owed = %d" % owed)
    if refill is not None:
        prelude = prelude.replace("RefillDays = 2.0",
                                  "RefillDays = %s" % refill)
    if population is not None:
        prelude = prelude.replace("PopulationGoverned = false, Population = 216,",
                                  "PopulationGoverned = true, Population = %d," % population)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        pre = work / "prelude.lua"
        pre.write_text(prelude, encoding="utf-8")
        host_path = work / 'evidence_host.lua'
        host_path.write_text(evidence_host(owed), encoding='utf-8')
        cp = "%s;%s;." % (PZ, SAO_JAR) if engine else "%s;." % PZ
        args = [str(JDK / "java.exe"), "-cp", cp, "LuaRun"]
        if engine:
            args += ["--engine", str(GAME)]
        args += [str(pre), str(host_path)]
        if engine:
            # The game's own fill file, then the chunk that calls its
            # fill functions - before the mod's modules, which is the
            # game's own load order: engine Lua first, mod Lua after.
            args += [str(ENGINE_FILL_LUA), str(SWEEP / "engine_fill.lua")]
        args += [str(CACHE / "map.lua"), str(SWEEP / "places.lua")]
        # SAO owns the living records; ZAO resolves those records at invocation.
        # All declarations are loaded before the first county callback.
        if joint:
            args += [str(ZAO_ROOT / m) for m in ZAO_MODULES]
        args += [str(lua / m) for m in MODULES]
        args += [str(CACHE / "regions.lua"), str(SWEEP / 'evidence.lua'),
                 "--", RUN.replace("RUN_NAME", name)]
        try:
            done = subprocess.run(args, cwd=str(work), capture_output=True,
                                  text=True, encoding='utf-8', errors='replace', timeout=timeout)
        except subprocess.TimeoutExpired:
            raise EvidenceError('%s timed out before completing %s days' % (name, owed))
        except OSError as exc:
            raise EvidenceError('%s VM could not start: %s' % (name, exc)) from exc
    out = done.stdout or ""
    if done.returncode != 0 or re.search(r'^ERROR ', out, re.M):
        raise EvidenceError('%s VM failed (exit %s): %s' %
                            (name, done.returncode, (out + done.stderr)[-4000:]))
    values = re.findall(r'^VALUE (.+)$', out, re.M)
    if len(values) != 1:
        raise EvidenceError('%s did not return exactly one result' % name)
    try:
        result = json.loads(values[0])
    except ValueError as exc:
        raise EvidenceError('%s returned invalid JSON: %s' % (name, exc)) from exc
    match = re.search(r'^ENGINE pools male=(\d+) female=(\d+) surnames=(\d+) professions=(\d+)$', out, re.M)
    counts = dict(zip(('maleNames', 'femaleNames', 'surnames', 'professions'),
                      map(int, match.groups()))) if match else None
    validate_result(result, owed, engine, counts, joint)
    # Concurrent edits invalidate provenance even if the VM happened to finish.
    if provenance(name, lua, owed, refill, population, engine, joint, paths) != identity:
        raise EvidenceError('%s source changed during simulation' % name)
    identity['engineRegistry'] = counts
    identity['seed'] = result['evidence']['seed']
    identity['drawCount'] = result['evidence'].get('drawCount')
    result['housesFounded'] = result['evidence']['housesFounded']
    result['survivorsJoined'] = result['evidence']['survivorsJoined']
    result['survivorsLeft'] = result['evidence']['survivorsLeft']
    result['provenance'] = identity
    result['completed'] = True
    return result


def prepare(lua, engine=False, joint=False):
    require_modules(pathlib.Path(lua), joint)
    required = [JDK / 'java.exe', JDK / 'javac.exe', JDK / 'javap.exe', PZ, STDLIB, SRC]
    if engine:
        required += [SAO_JAR, ENGINE_FILL_LUA]
    absent = [str(path) for path in required if not path.is_file()]
    if absent:
        raise EvidenceError('required runtime files absent: ' + ', '.join(absent))
    maps = World.maps_dir(GAME)
    newest = max((p.stat().st_mtime for p in maps.rglob('*')
                  if p.is_file() and (p.name == 'spawnpoints.lua' or p.suffix == '.lotheader')),
                 default=0)
    if not all((CACHE / name).is_file() for name in ('map.lua', 'regions.lua')) or \
            (CACHE / 'map.lua').stat().st_mtime < newest:
        if not World.build(GAME, CACHE):
            raise EvidenceError('installed map could not be extracted')
    if not build_runner():
        raise EvidenceError('LuaRun did not compile against the installed engine')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--runs", type=int, default=12)
    ap.add_argument("--days", type=int, default=1096,
                    help="days the county owes at genesis")
    ap.add_argument("--refill", default=None,
                    help="RefillDays, through the sandbox rather than the code")
    ap.add_argument("--population", type=int, default=None,
                    help="initial genesis living population (default 216)")
    ap.add_argument("--lua", default=None,
                    help="another tree's lua root, for a before/after")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--engine", action="store_true",
                    help="expose the real bridge and load the game's own "
                         "name pools and profession definitions; a "
                         "different county from the same name (see the "
                         "engine mode above)")
    ap.add_argument('--joint', action='store_true',
                    help='load the sibling ZAO pathogen modules explicitly')
    ap.add_argument('--timeout', type=int, default=3600,
                    help='per-county timeout in seconds; expiry is a failed run')
    args = ap.parse_args()
    if args.runs <= 0 or args.days <= 0 or args.workers <= 0:
        ap.error('runs, days and workers must be positive')

    print("=" * 74)
    print("COUNTY SWEEP - what the shipped county produced, over %d runs"
          % args.runs)
    print("=" * 74)

    if not SRC.exists():
        print('  FAILED - repository LuaRun source is absent.')
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and GAME.exists()):
        # The historical sweep CLI participates in the repository's no-game
        # census. This is explicitly no sample; evidence APIs still refuse.
        print('  SKIPPED - game or JDK absent; no counties run and no data produced.')
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
        print("  REFERENCED BY LOADED CODE, NOT LOADED, NOT DECLARED "
              "ABSENT:")
        for name in missing:
            print("      SAO.%s" % name)
        print('  FAILED - no simulation started.')
        return 1
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
    try:
        prepare(lua, args.engine, args.joint)
    except EvidenceError as exc:
        print('  FAILED:', exc)
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
                               args.refill, args.population, args.engine,
                               args.joint, args.timeout)
                   : k for k in range(args.runs)}
        for f in concurrent.futures.as_completed(futures):
            try:
                r = f.result()
            except EvidenceError as exc:
                print('  run %s FAILED: %s' % (futures[f], exc))
                continue
            if r:
                rows.append(r)
                print("  run %-3d alive=%-4d dead=%-4d founded=%-3d standing=%-3d "
                      "biggest=%-2d ge4=%-2d ge8=%-2d zTurned=%-3d zCrossed=%-2d"
                      % (futures[f], r["alive"], r["dead"], r["housesFounded"],
                         r["housesStanding"], r["biggestHouse"],
                         r.get("housesGe4", 0), r.get("housesGe8", 0),
                         r.get("zaoTurned", 0), r.get("zaoCrossed", 0)))
            else:
                print("  run %-3d did not finish" % futures[f])

    if len(rows) != args.runs:
        print('\n  FAILED: %s/%s counties completed; aggregate withheld'
              % (len(rows), args.runs))
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
