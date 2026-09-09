#!/usr/bin/env python3
r"""Border 137 - a belief is about a person ([C71]).

Every belief this mod holds about a person is keyed by
`Identity.displayName`, which is a name when the record has one and
the string "Unnamed" when it does not. `backfillName` takes a name off
the engine shell the first time a body is built for somebody, so a
survivor the county has never materialised has no name - and a dormant
county materialises nobody. Measured in the engine's own VM against
the shipped map: 271 people, 271 of them "Unnamed", one distinct
display name for the entire county.

So every belief about every one of them landed on one string. The
county's whole memory of its dead was a single slot per head, and the
second death overwrote the first.

Three things compounded it, each found by this border refusing to
pass. The dormant attrition pass read `P.beliefs[hearer]` without
opening one, so word of a death reached nobody who had never been told
anything by anybody - the median county had ONE person in it holding
any belief about any person at all. That pass also returns before
anything when `DormantRisk` is zero, so a dial that means "the county
stops collecting" also silenced news of deaths that had already
happened. And it asked a corpse for its fellows, which [C68] had
already taken it off the roster of, so the company half of "word finds
the bonded and the company" reached nobody at all.

Beside those, a dormant meeting - a firsthand sighting with lessons,
doctrine, grudges and credits changing hands - wrote nothing down: not
one survivor in eight counties believed a living person was anywhere.

THIS BORDER MEASURES THE BELIEF, NOT THE CALL.

Everything below runs the shipped modules in the engine's own VM and
then reads the belief store. A border asserting that the meeting calls
`sawPerson`, or that `beliefKey` exists, would pass a tree that spelled
both and still put the whole county in one slot - which is what the
tree did.

The properties it holds:

  * TWO UNNAMED PEOPLE ARE TWO KEYS. The defect exactly: the shared
    sentinel, measured rather than described.
  * A MEETING LEAVES BOTH SIDES BELIEVING THEY SAW THE OTHER, at
    observed provenance, at the other's position.
  * A DEATH REACHES A HEARER WHO HAS NEVER BEEN TOLD ANYTHING, which
    needs the store opened rather than found.
  * TWO DEATHS ARE TWO BELIEFS. One death overwriting the last is the
    consequence that cost the county its memory.
  * A NAME ARRIVING CARRIES THE BELIEFS ACROSS. A person's key changes
    the first time a player walks near them, and without the migration
    everybody who knew them would lose them at that moment.
  * A HOUSE HEARS ITS OWN LOSSES. The house is asked by name, so a
    corpse being off the roster does not silence the news of it.
  * NO ID REACHES A PLAYER (DR-017). `knownName` still refuses the
    sentinel, so a key that is an id can never be spoken.

Genesis does not run here and there is no map: `SpawnRegionMgr` and
the meta grid are absent on purpose, because what is being measured is
what a meeting and a death write down, and a county built from spawn
points would decide when those happen instead of this file. The
records are made directly and their positions are held, so the meeting
is the subject rather than the coincidence that usually produces one.

An optional argv[1] points the checker at another tree root, which is
how its control runs.
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
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The dormant county's own module set, which is what writes and reads
# these beliefs.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

PRELUDE = r'''
SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
_G.__out = {}
ModData = { getOrCreate = function(k) __md[k] = __md[k] or {} return __md[k] end }
getWorld = function() return {
    getWorld = function() return "BorderSave" end,
    getMetaGrid = function() return nil end } end
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return _G.__hours end,
    getStartYear = function() return 1996 end,
    getStartMonth = function() return 6 end,
    getStartDay = function() return 8 end,
    getMonth = function() return 6 end,
    getDay = function() return 8 end,
    getYear = function() return 1996 end,
    getTimeOfDay = function() return 12.0 end,
    getHelicopterDay = function() return 7 end,
    getNightsSurvived = function()
        return math.floor((_G.__hours or 0) / 24) end,
    getCalender = function() return {
        getTimeInMillis = function() return 8640000000 end } end } end }
getGameTime = function() return GameTime.getInstance() end
getTimestampMs = function() _G.__ms = (_G.__ms or 0) + 1 return _G.__ms end
ZombRand = function(a, b) if b == nil then return 0 end return a end
getSpecificPlayer = function() return nil end
getSandboxOptions = function()
    return { getWaterShutModifier = function() return 30 end } end
getScriptManager = function() return { getItem = function() return nil end } end
mergeTable = function(...) return {} end
getFileWriter = function()
    return { write = function() end, close = function() end } end
-- Captured, not replaced: the county runs its own cadence.
Events = setmetatable({}, { __index = function(t, k)
    local slot = {
        Add = function(fn) _G.__handlers = _G.__handlers or {}
            _G.__handlers[k] = fn end,
        Remove = function() end }
    rawset(t, k, slot)
    return slot
end })
SandboxVars = { SurvivorAwareness = {
    Enable = true, Telemetry = false, TrustToCompany = 0.5,
    PopulationGoverned = true, Population = 2,
    NewcomersGoverned = true, Newcomers = 0,
    RoadTraffic = 0, RefillDays = 2.0, Desperation = 0.7,
    DormantRisk = 0, DayZero = false,
    MaterializeRadius = 45, HibernateRadius = 70,
}, ZombieLore = { Transmission = 1 } }
SAO.Body = { active = {}, get = function() return nil end }
SAOJavaBridge = {
    daysBehindAtStart = function() return 0 end,
    recordDayToday = function() return 0 end,
    countyMonth = function() return 5 end,
    surveyClaim = function() return "ways=6 boarded=0 rooms=4" end,
    listKnoxHumans = function() return "" end,
    isCombatPatchReady = function() return false end,
}
'''

# Two people standing together, a meeting, a house losing two members,
# and a name arriving. Every answer is read out of the belief store.
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
    if SAO.Identity.beliefKey then
      return tostring(SAO.Identity.beliefKey(r))
    end
    return tostring(SAO.Identity.displayName(r))
  end
  local a = make(10500, 9000)
  local b = make(10500, 9000)

  -- Two people the county has never named. This is the defect: one
  -- key for both, or one key each.
  local keyA, keyB = keyOf(a), keyOf(b)
  local shownA = tostring(SAO.Identity.knownName(a))

  SAO.Standing.bond(a.id, b.id)
  SAO.Standing.adjustTrust(a.id, b.id, 0.85)
  SAO.Standing.adjustTrust(b.id, a.id, 0.85)

  -- A house of four, scattered, meeting nobody. Their beliefs can only
  -- come from news.
  local house = { make(10900, 9400), make(11400, 9400),
                  make(11900, 9400), make(12400, 9400) }
  local hk = {}
  for i = 1, 4 do hk[i] = keyOf(house[i]) end
  local ids = {}
  for i = 1, 4 do ids[i] = house[i].id end
  if SAO.Standing.formCompany then
    SAO.Standing.formCompany(ids, "border-house")
  else
    for i = 1, 4 do SAO.Standing.joinGroup(ids[i], "border-house") end
  end

  local function hold()
    a.x, a.y = 10500, 9000
    b.x, b.y = 10501, 9000
    for i = 1, 4 do
      if not house[i].dead then
        house[i].x, house[i].y = 10400 + i * 500, 9400
      end
    end
  end

  -- Hold them and let the county's own encounter pass find the pair.
  -- Their positions are pinned because the dormant day would otherwise
  -- walk them apart, and where they wander is not what is measured.
  for i = 1, 240 * 40 do hold(); tick() end
  local ba = SAO.Perception.beliefs[a.id]
  local bb = SAO.Perception.beliefs[b.id]
  local sawB = ba and ba.people[keyB] or nil
  local sawA = bb and bb.people[keyA] or nil
  local seenSrc = sawB and tostring(sawB.source) or "none"
  local seenX = sawB and tostring(sawB.x) or "none"
  local bothWays = (sawA and sawB) and "yes" or "no"

  -- A death reaching a housemate who has been told nothing by anybody.
  -- house[1] has met nobody, so it has no belief store at all until
  -- the news opens one.
  local hadStore = SAO.Perception.beliefs[ids[1]] and "yes" or "no"
  _G.__hours = _G.__hours + 240
  SAO.Identity.markDead(house[2], 0, "border")
  house[2].deathNewsAt = 0
  for i = 1, 240 * 4 do hold(); tick() end
  local b1 = SAO.Perception.beliefs[ids[1]]
  local heard = (b1 and b1.people[hk[2]] and b1.people[hk[2]].dead)
    and "yes" or "no"

  -- And a second death is a second belief rather than an overwrite.
  _G.__hours = _G.__hours + 240
  SAO.Identity.markDead(house[3], 0, "border")
  house[3].deathNewsAt = 0
  for i = 1, 240 * 4 do hold(); tick() end
  b1 = SAO.Perception.beliefs[ids[1]]
  local dead = 0
  for _, pb in pairs((b1 and b1.people) or {}) do
    if pb.dead then dead = dead + 1 end
  end

  -- A name arriving. Everybody who knew them keeps knowing them.
  local moved, underNew, underOld = "absent", "no", "yes"
  if SAO.Perception.migratePersonKey then
    local e = make(10500, 9000)
    local keyE = keyOf(e)
    SAO.Perception.sawPerson(ids[1], keyE, 10500, 9000, 1, e.id)
    e.forename, e.surname = "Rosa", "Delgado"
    SAO.Identity.noteRenamed()
    local n = SAO.Perception.migratePersonKey(keyE, keyOf(e))
    moved = tostring(n)
    local store = SAO.Perception.beliefs[ids[1]]
    underNew = (store and store.people["Rosa Delgado"]) and "yes" or "no"
    underOld = (store and store.people[keyE]) and "yes" or "no"
  end

  return "keyA=" .. keyA .. " keyB=" .. keyB
    .. " shownA=" .. shownA
    .. " bothWays=" .. bothWays .. " seenSrc=" .. seenSrc
    .. " seenX=" .. seenX .. " hadStore=" .. hadStore
    .. " heard=" .. heard .. " deadBeliefs=" .. dead
    .. " moved=" .. moved .. " underNew=" .. underNew
    .. " underOld=" .. underOld
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
        prelude.write_text(PRELUDE, encoding="utf-8")
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


def display_keyed_beliefs():
    """Sites still keying a person-belief on the DISPLAY name.

    The shape, across the tree, rather than a phrase in one file: a
    local assigned from `displayName` and then used to index a
    `people` table. That is what [C71] moved onto `beliefKey`, and a
    new one appearing is the defect coming back by another door.
    """
    found = []
    for path in sorted(LUA.rglob("*.lua")):
        text = read(path)
        lines = text.splitlines()
        named = {}
        for i, line in enumerate(lines):
            m = re.search(r"local\s+(\w+)\s*=.*displayName\(", line)
            if m:
                named[m.group(1)] = i + 1
            # A multi-line assignment: `local x = SAO.Identity.displayName(`
            # is caught above; the closing paren on the next line is not
            # needed to know the local's source.
        for i, line in enumerate(lines):
            m = re.search(r"\.people\[\s*(\w+)\s*\]", line)
            if m and m.group(1) in named:
                found.append("%s:%d (%s from line %d)"
                             % (path.relative_to(LUA).as_posix(), i + 1,
                                m.group(1), named[m.group(1)]))
    return found


def main():
    faults = []
    print("=" * 74)
    print("A BELIEF IS ABOUT A PERSON")
    print("=" * 74)

    strays = display_keyed_beliefs()
    print("  person-beliefs still keyed on the display name: %d"
          % len(strays))
    for name in strays[:6]:
        print("      " + name)

    identity = read(LUA / "shared" / "SAO_Identity.lua")
    perception = read(LUA / "shared" / "SAO_Perception.lua")
    standing = read(LUA / "shared" / "SAO_Standing.lua")
    seams = {
        "a record renders a belief key of its own":
            "function Identity.beliefKey(" in identity,
        "a key that is an id resolves back to the person":
            re.search(r"ipairs\(\{[^}]*\bid\b[^}]*\}\)", identity)
            is not None,
        "a meeting can be written down":
            "function P.sawPerson(" in perception,
        "a death can be learned by somebody with no store":
            "function P.learnOfDeath(" in perception,
        "a house can be asked who is in it by name":
            "function S.membersOf(" in standing,
        "a name arriving carries the beliefs":
            "function P.migratePersonKey(" in perception,
        "no belief is keyed on the display name":
            not strays,
        "the gate runs this border":
            "tools/person_belief_test.py" in read(CHECK),
    }

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
        print("  137) a belief is about a person: TEXT ONLY, the engine "
              "install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     a pair meeting, a house losing two members, and a name:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    if got.get("keyA") == got.get("keyB"):
        faults.append(
            "two different people share the belief key %s. That is the "
            "defect this border exists for: the county names nobody it "
            "has not materialised, so every belief about every dormant "
            "survivor lands on one string and each one overwrites the "
            "last" % got.get("keyA"))
    if got.get("shownA") != "nil":
        faults.append(
            "a survivor with no name is shown to a player as %s. The "
            "belief key may be an id; what a player is told may not "
            "(DR-017)" % got.get("shownA"))
    if got.get("bothWays") != "yes":
        faults.append(
            "a dormant meeting left one or both parties believing "
            "nothing about the other. They stood three tiles apart and "
            "traded lessons, doctrine, grudges and credits; a survivor "
            "who cannot remember meeting anybody has nobody to decide "
            "about tomorrow")
    if got.get("seenSrc") != "observed":
        faults.append(
            "the sighting a meeting leaves is recorded as %s. They were "
            "there and they saw each other; that is observed"
            % got.get("seenSrc"))
    if got.get("seenX") not in ("10501", "10501.0"):
        faults.append(
            "the sighting put them at %s rather than where the other "
            "actually stood" % got.get("seenX"))
    if got.get("hadStore") != "no":
        faults.append(
            "the subject of the death half already held beliefs before "
            "the news, so this cannot test whether the news opens a "
            "store")
    if got.get("heard") != "yes":
        faults.append(
            "word of a housemate's death never reached somebody who had "
            "been told nothing by anybody. Two things do that: the "
            "attrition pass reading a belief store rather than opening "
            "one, which in a dormant county means almost nobody, and "
            "asking a corpse for its fellows when [C68] takes it off "
            "the roster at the moment of death")
    if got.get("deadBeliefs") != "2":
        faults.append(
            "two deaths left %s belief(s) about the dead. One death "
            "overwriting the last is what a shared key costs the county: "
            "its whole memory of its losses is one person deep"
            % got.get("deadBeliefs"))
    if got.get("moved") == "absent":
        faults.append("this tree cannot carry a belief across a rename, "
                      "so a person is forgotten by everybody who knew "
                      "them the first time a player walks near them")
    else:
        if got.get("moved") != "1":
            faults.append("a name arriving moved %s belief(s) rather "
                          "than the one that existed"
                          % got.get("moved"))
        if got.get("underNew") != "yes":
            faults.append("the belief is not under the name the person "
                          "was just given")
        if got.get("underOld") != "no":
            faults.append("the belief is still under the key the person "
                          "no longer answers to, so the county holds two "
                          "memories of one person")

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
        print("  137) a belief is about a person: FAIL")
        return 1
    print("  137) every person has their own belief key, a meeting is "
          "written down, and news reaches a head with nothing in it: "
          "PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
