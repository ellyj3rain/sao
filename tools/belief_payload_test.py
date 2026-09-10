#!/usr/bin/env python3
r"""Border 147 - what a belief carries ([C87]).

The operator ruled on two of the gaps [C86] came back with, and this
border holds both rulings as measured properties rather than as
spellings.

THE DISTANCE. The road-meeting caller computed the distance between
two people to decide whether they met -
`dx * dx + dy * dy <= MEET_RANGE * MEET_RANGE` - and then threw it
away, passing only the position; the belief wrote
`dist = (prev and prev.dist) or 0`. Two consequences, both measured
here rather than described: a first meeting was recorded at distance
zero, and a RE-meeting carried the first meeting's distance forever
- meet at three tiles, meet again at one, and the county still
believed the second meeting happened three tiles out. The scanner
path (the live half) always wrote the real distance; `sawPerson` was
the one person-belief writer that did not. The ruling: keep the value
the county already computes. The caller passes it; a caller that
knows no distance keeps the honest seed - carried, then zero.

THE PLAIN READING. The engine stores a person's name as its own
translation key (`SurvivorName_Elliot`) and renders it in English as
the key's own suffix. That is not an assumption: this border reads
the engine's own `Translate/EN/SurvivorNames.json` and holds that
every entry renders as its suffix, entry for entry. The ruling: a
row reads the plain form, the engine's storage is unchanged, and the
raw key stays beside it. `plainNameOf` lives in the sweep prelude -
the environment the dump actually runs - and the dump's member row
carries `displayName` beside `name`, so nothing captured is curated
and nothing raw is lost.

THIS BORDER MEASURES THE BELIEF AND THE READING, NOT THE CALL.

Everything below runs the shipped modules behind the REAL sweep
prelude - the one the dump runs, because the plain reading lives
there - and then reads the belief store. A border asserting that the
meeting spells `metDist` would pass a tree that spelled it and still
wrote zero.

The properties it holds:

  * A MEETING WRITES THE DISTANCE THE COUNTY COMPUTED, both ways.
  * A RE-MEETING CARRIES THE NEW DISTANCE, not the first one.
  * A CALLER THAT SAYS NOTHING KEEPS THE HONEST SEED: carried, then
    zero - the same write from any other hand.
  * THE PLAIN READING IS THE ENGINE'S OWN ENGLISH, read against the
    engine's own translation file, entry for entry.
  * THE FIRST-NIGHT SPELLING COMPUTES, so the two spellings of one
    write cannot drift apart if mates ever spawn apart.

An optional argv[1] points the checker at another tree root, which is
how its control runs.
"""
import json
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
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
PRELUDE_FILE = ROOT / "tools" / "sweep" / "prelude.lua"
DUMP = ROOT / "tools" / "county_dump.py"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
ENGINE_NAMES = PZ_DIR / "media" / "lua" / "shared" / "Translate" / "EN" \
    / "SurvivorNames.json"

# The dormant county's own module set, which is what writes and reads
# these beliefs - the same set Border 137 runs.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

# Two people held three tiles apart, then one; the meeting pass finds
# the pair and the belief is read out of the store. The direct calls
# pin the optional path: a distance stated, then not.
PROBE = r"""(function()
  local tick = _G.__handlers.OnTick
  local function make(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    r.homeX, r.homeY, r.homeZ = x, y, 0
    r.lastWaterDay, r.lastFoodDay, r.lastRiskDay = 0, 0, 0
    return r
  end
  local function keyOf(r)
    return tostring(SAO.Identity.beliefKey(r))
  end
  local a = make(10500, 9000)
  local b = make(10503, 9000)
  local keyA, keyB = keyOf(a), keyOf(b)

  local function hold(second)
    a.x, a.y = 10500, 9000
    if second then b.x, b.y = 10501, 9000
    else b.x, b.y = 10503, 9000 end
  end

  -- Three tiles apart is the meet range's own boundary: the pass's
  -- test reads 9 <= 9 and the pair meets. The county hours stay put
  -- so nothing attrits; only the encounter pulse runs.
  for _ = 1, 240 * 40 do hold(false); tick() end
  local ba = SAO.Perception.beliefs[a.id]
  local sawB = ba and ba.people[keyB] or nil
  local first = sawB and tostring(sawB.dist) or "none"

  -- They meet again at one tile. The cooldown lapses well inside
  -- this run, and the new belief must carry the NEW distance - the
  -- old spelling carried the first meeting's forever.
  for _ = 1, 240 * 40 do hold(true); tick() end
  ba = SAO.Perception.beliefs[a.id]
  sawB = ba and ba.people[keyB] or nil
  local second = sawB and tostring(sawB.dist) or "none"
  local bb = SAO.Perception.beliefs[b.id]
  local sawA = bb and bb.people[keyA] or nil
  local back = sawA and tostring(sawA.dist) or "none"

  -- A caller that states a distance; the same caller silent. The
  -- silent call is the same write from any other hand, and it must
  -- keep the honest seed: carried, then zero.
  local c = make(10600, 9100)
  local d = make(10600, 9100)
  local e = make(10600, 9100)
  SAO.Perception.sawPerson(c.id, keyOf(d),
      10605, 9100, 10, d.id, 5)
  local stated = tostring(
      SAO.Perception.beliefs[c.id].people[keyOf(d)].dist)
  SAO.Perception.sawPerson(c.id, keyOf(d),
      10606, 9100, 20, d.id)
  local carried = tostring(
      SAO.Perception.beliefs[c.id].people[keyOf(d)].dist)
  SAO.Perception.sawPerson(c.id, keyOf(e),
      10607, 9100, 30, e.id)
  local fresh = tostring(
      SAO.Perception.beliefs[c.id].people[keyOf(e)].dist)

  -- The plain reading, from the prelude the dump itself runs.
  local pok = false
  local pkey, psent = "none", "none"
  pcall(function()
    pkey = plainNameOf("SurvivorName_Elliot",
        "SurvivorSurname_Segura")
    psent = plainNameOf("Unnamed", "Survivor")
    pok = true
  end)
  if not pok then pkey, psent = "absent", "absent" end

  return "first=" .. first .. " second=" .. second
    .. " back=" .. back
    .. " stated=" .. stated .. " carried=" .. carried
    .. " fresh=" .. fresh
    .. " pkey=" .. tostring(pkey) .. " psent=" .. tostring(psent)
end)()"""


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
        prelude.write_text(PRELUDE_FILE.read_text(encoding="utf-8"),
                           encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        args += [str(LUA / m) for m in MODULES if (LUA / m).exists()]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-400:]
    return out[at + 6:].strip().split("\n")[0]


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:' ]+?)(?=\s\w+=|$)",
                                        line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("WHAT A BELIEF CARRIES")
    print("=" * 74)

    population = read(LUA / "client" / "SAO_Population.lua")
    perception = read(LUA / "shared" / "SAO_Perception.lua")
    prelude = read(PRELUDE_FILE)
    dump = read(DUMP)
    seams = {
        "the meeting passes the distance it computed":
            re.search(r"local metDist = math\.sqrt\(dx \* dx \+ dy \* dy\)",
                      population) is not None
            and population.count("tickCounter, idB, metDist)") == 1
            and population.count("tickCounter, idA, metDist)") == 1,
        "the first-night spelling computes from their own positions":
            re.search(r"local fdist = math\.sqrt\(fdx \* fdx \+ fdy \* fdy\)",
                      population) is not None
            and population.count(", fdist)") == 2,
        "the write takes a stated distance and keeps the honest seed":
            "function P.sawPerson(id, name, x, y, tick, otherId, dist)"
            in perception
            and "dist = dist or (prev and prev.dist) or 0" in perception,
        "the prelude carries the plain reading":
            "plainNameOf" in prelude,
        "the dump's member row carries the plain reading beside the key":
            "snap.displayName" in dump and "plainNameOf" in dump,
        "the gate runs this border":
            "tools/belief_payload_test.py" in read(CHECK),
    }

    # The plain reading IS the engine's own English rendering, read
    # against the engine's own translation file: every entry's value
    # equals its key's suffix. Not an assumption - a measurement.
    engine_checked = 0
    if ENGINE_NAMES.exists():
        table = json.loads(ENGINE_NAMES.read_text(encoding="utf-8"))
        bad = []
        for key, value in table.items():
            if key.startswith("SurvivorName_"):
                plain = key[len("SurvivorName_"):]
            elif key.startswith("SurvivorSurname_"):
                plain = key[len("SurvivorSurname_"):]
            else:
                bad.append(key)
                continue
            if value != plain:
                bad.append(key)
        engine_checked = len(table)
        print("  the engine's own EN name table: %d entries, plain "
              "reading matches %d, strays %d"
              % (len(table), len(table) - len(bad), len(bad)))
        for key in bad[:4]:
            print("      %s does not render as its own suffix" % key)
        if bad:
            faults.append(
                "%d of the engine's own name keys do not render as "
                "their own suffix, so stripping the prefix is not the "
                "engine's English and the plain reading would be a "
                "guess" % len(bad))
    else:
        print("  SKIPPED the engine's own name table - no install")

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print()
        for k, v in seams.items():
            print("  %s  %s" % ("yes" if v else "NO ", k))
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  147) what a belief carries: TEXT ONLY, the engine "
              "install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     a pair meeting at three tiles, meeting again at one:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    if got.get("first") not in ("3", "3.0"):
        faults.append(
            "a meeting at three tiles wrote dist=%s. The pass computed "
            "the distance to decide they met and threw it away, so the "
            "belief said they stood at arm's length when they crossed "
            "the road from each other" % got.get("first"))
    if got.get("second") not in ("1", "1.0"):
        faults.append(
            "a re-meeting at one tile wrote dist=%s. The old spelling "
            "carried the first meeting's distance forever: meet at "
            "three, meet again at one, and the county still believed "
            "the second meeting happened three tiles out"
            % got.get("second"))
    if got.get("back") not in ("1", "1.0"):
        faults.append(
            "the other side of the re-meeting wrote dist=%s; a meeting "
            "is two beliefs and they must agree" % got.get("back"))
    if got.get("stated") not in ("5", "5.0"):
        faults.append(
            "a caller that stated distance 5 wrote dist=%s - the "
            "write is not taking what the caller passes"
            % got.get("stated"))
    if got.get("carried") not in ("5", "5.0"):
        faults.append(
            "a silent re-write after a stated one wrote dist=%s; the "
            "honest seed is CARRIED, then zero - a caller that knows "
            "no distance must not erase one that did"
            % got.get("carried"))
    if got.get("fresh") not in ("0", "0.0"):
        faults.append(
            "a silent first write gave dist=%s; with no distance "
            "stated and none carried the seed is zero"
            % got.get("fresh"))
    if got.get("pkey") == "absent":
        faults.append(
            "the prelude the dump runs has no plain reading to ask, "
            "so a row cannot read a name the way the engine renders it")
    elif got.get("pkey") != "Elliot Segura":
        faults.append(
            "the plain reading of SurvivorName_Elliot "
            "SurvivorSurname_Segura came back %s rather than "
            "Elliot Segura" % got.get("pkey"))
    if got.get("psent") != "Unnamed Survivor":
        faults.append(
            "the plain reading of a name that is not a key came back "
            "%s; the sentinel must read as itself, unchanged"
            % got.get("psent"))

    print()
    for k, v in seams.items():
        print("  %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        print("  147) what a belief carries: FAIL")
        return 1
    print("  147) a meeting writes the distance the county computed, a "
          "re-meeting refreshes it, a silent caller keeps the honest "
          "seed, and a row reads the engine's own English: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())