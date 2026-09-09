#!/usr/bin/env python3
r"""Border 138 - the dormant day can go to a person ([C72]).

`chooseDayPlace` decided where a dormant survivor walks from thirst,
hunger, lessons, beliefs and barred ground. It was a real,
attribute-aware decision and it was the ONLY decision a dormant person
made - and it had no social term in it at all. Nobody in this county
had ever decided to go to another person. Every meeting in a county was
two need-driven walks coinciding within three tiles.

What that cost, measured over counties of 1096 days against the
shipped map:

  * 152 housemate pairs are seeded at genesis, bonded, trusting each
    other at 0.6 to 0.9 and standing on the same tile. 27 of them ever
    stood near each other again.
  * 179 of 287 people lived and died without ever meeting anybody.
  * 129 pairs stood above the company line at the end and 16 of them
    had ever met.

THIS BORDER MEASURES THE GOAL, NOT THE CALL.

It runs the shipped dormant modules in the engine's own Kahlua VM
through the tick handler the mod registers, and then reads
`rec.dayGoalPerson` and `rec.dayGoalX/Y` off the record. A border
asserting that `chooseDayGoal` calls `chooseWhoToGoTo` would pass a
tree that called it and threw the answer away.

Whether somebody sets out on a given day is `initiative`, a trait in
[0.15, 0.85] drawn against the county's own counter-based generator,
so every property below is measured over many day-choices rather than
one: a decision that is available is taken at least once, and a
decision that is not available is never taken.

The properties:

  * SOMEBODY TRUSTED AND SEEN IS SOMEWHERE TO GO. The goal is their
    remembered position.
  * TRUST BELOW THE COMPANY LINE IS NOT. The bar is the county's own
    and it binds.
  * SOMEBODY HOSTILE IS NOT.
  * THIRST OUTRANKS COMPANY. A person two days dry goes for water.
  * A SIGHTING WALKED TO AND FOUND EMPTY STOPS BEING THE ANSWER, so
    nobody re-orders the same doorstep forever ([C25]'s rule).

Its control is the pre-batch tree, where no day's goal is ever a
person.

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

# One building with a sink in it, three hundred tiles from home, so
# the thirst case has somewhere real to go and the seeking case is
# never confused with it.
PRELUDE = r'''
SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
ModData = { getOrCreate = function(k) __md[k] = __md[k] or {} return __md[k] end }
local rooms = { "kitchen", "bathroom" }
local roomObjs = {}
for i, name in ipairs(rooms) do
    roomObjs[i - 1] = { getName = function() return name end }
end
local def = {
    getID = function() return 4242 end,
    getX = function() return 10800 end,
    getY = function() return 9000 end,
    getX2 = function() return 10810 end,
    getY2 = function() return 9010 end,
    getRooms = function()
        return { size = function() return 2 end,
                 get = function(self, i) return roomObjs[i] end }
    end,
}
_G.__grid = { getBuildingAt = function(self, x, y)
    if x >= 10800 and x < 10810 and y >= 9000 and y < 9010 then
        return def
    end
    return nil
end }
getWorld = function() return {
    getWorld = function() return "BorderSave" end,
    getMetaGrid = function() return _G.__grid end } end
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

PROBE = r'''(function()
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
  -- The walker, and four people they believe are out there.
  local me = make(10500, 9000)
  local friend = make(10650, 9100)
  local stranger = make(10660, 9110)
  local enemy = make(10670, 9120)
  local kFriend, kStranger, kEnemy =
    keyOf(friend), keyOf(stranger), keyOf(enemy)

  SAO.Standing.adjustTrust(me.id, friend.id, 0.85)
  SAO.Standing.adjustTrust(friend.id, me.id, 0.85)
  SAO.Standing.adjustTrust(me.id, stranger.id, 0.20)
  SAO.Standing.adjustTrust(me.id, enemy.id, 0.85)
  SAO.Standing.setHostile(me.id, enemy.id, true)

  local function believe()
    if not SAO.Perception.sawPerson then return false end
    SAO.Perception.sawPerson(me.id, kFriend, 10650, 9100, 1, friend.id)
    SAO.Perception.sawPerson(me.id, kStranger, 10660, 9110, 1, stranger.id)
    SAO.Perception.sawPerson(me.id, kEnemy, 10670, 9120, 1, enemy.id)
    return true
  end
  local haveVerb = believe() and "yes" or "no"

  -- Many day-choices, because whether somebody sets out on any one day
  -- is their own initiative drawn against the county's generator.
  local function choices(n, prepare)
    local seen = {}
    for i = 1, n do
      -- Fresh sightings each round: the walk itself would otherwise
      -- age them out, and what is being measured is the decision.
      believe()
      if prepare then prepare() end
      me.dayGoalX, me.dayGoalY = nil, nil
      me.dayGoalPlaceId, me.dayGoalPerson = nil, nil
      me.nextDormantMoveAt = 0
      me.x, me.y = 10500, 9000
      for _ = 1, 240 do tick() end
      local who = me.dayGoalPerson
      if who then seen[who] = (seen[who] or 0) + 1 end
      seen.__any = (seen.__any or 0) + (who and 1 or 0)
    end
    return seen
  end

  local today = math.floor(_G.__hours / 24.0)
  local well = choices(40, function()
    me.lastWaterDay, me.lastFoodDay = today, today
  end)
  local toFriend = well[kFriend] or 0
  local toStranger = well[kStranger] or 0
  local toEnemy = well[kEnemy] or 0

  -- Two days without water. Thirst is not a visit.
  local dry = choices(40, function()
    me.lastWaterDay = today - 3
    me.lastFoodDay = today
  end)
  local dryToAnyone = dry.__any or 0

  -- A sighting already walked to and found empty is not an address.
  local spent = 0
  do
    local b = SAO.Perception.beliefs[me.id]
    for i = 1, 40 do
      believe()
      if b and b.people then
        for _, pb in pairs(b.people) do
          pb.lookedAt = (pb.at or 0) + 1
        end
      end
      me.lastWaterDay, me.lastFoodDay = today, today
      me.dayGoalX, me.dayGoalY = nil, nil
      me.dayGoalPlaceId, me.dayGoalPerson = nil, nil
      me.nextDormantMoveAt = 0
      me.x, me.y = 10500, 9000
      for _ = 1, 240 do tick() end
      if me.dayGoalPerson then spent = spent + 1 end
    end
  end

  -- And where the goal actually points when it is a person.
  local atX, atY = "none", "none"
  do
    believe()
    me.lastWaterDay, me.lastFoodDay = today, today
    for i = 1, 40 do
      believe()
      me.dayGoalX, me.dayGoalY = nil, nil
      me.dayGoalPlaceId, me.dayGoalPerson = nil, nil
      me.nextDormantMoveAt = 0
      me.x, me.y = 10500, 9000
      for _ = 1, 240 do tick() end
      if me.dayGoalPerson == kFriend then
        atX, atY = tostring(me.dayGoalX), tostring(me.dayGoalY)
        break
      end
    end
  end

  return "haveVerb=" .. haveVerb
    .. " toFriend=" .. toFriend .. " toStranger=" .. toStranger
    .. " toEnemy=" .. toEnemy .. " dryToAnyone=" .. dryToAnyone
    .. " spent=" .. spent .. " atX=" .. atX .. " atY=" .. atY
end)()'''


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
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:']+)", line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("THE DORMANT DAY CAN GO TO A PERSON")
    print("=" * 74)

    pop = read(LUA / "client" / "SAO_Population.lua")
    seams = {
        "the day's goal may be a person":
            "dayGoalPerson" in pop,
        "somebody is chosen to go to":
            "function chooseWhoToGoTo(" in pop
            or "chooseWhoToGoTo(" in pop,
        "the bar is the county's own company line":
            "TrustToCompany" in pop,
        "the gate runs this border":
            "tools/seek_test.py" in read(CHECK),
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
        print("  138) the dormant day can go to a person: TEXT ONLY, the "
              "engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     forty day-choices per case, one walker, three people:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    if got.get("haveVerb") != "yes":
        faults.append("this tree cannot record having seen a person, so "
                      "there is nobody for a day to be about ([C71])")
    if int(got.get("toFriend") or 0) == 0:
        faults.append(
            "in forty day-choices, a well-fed survivor never once set out "
            "toward somebody they trust at 0.85 and saw yesterday. That is "
            "the defect this border exists for: the dormant goal path has "
            "no social term, so nobody in the county ever decides to go to "
            "another person and every meeting is a coincidence")
    if int(got.get("toStranger") or 0) != 0:
        faults.append(
            "somebody trusted at 0.20 - below the county's own company "
            "line - was walked to %s times. The bar is what stops the "
            "county collapsing into one crowd"
            % got.get("toStranger"))
    if int(got.get("toEnemy") or 0) != 0:
        faults.append(
            "somebody this survivor is hostile to was walked to %s times"
            % got.get("toEnemy"))
    if int(got.get("dryToAnyone") or 0) != 0:
        faults.append(
            "a survivor three days without water went visiting %s times. "
            "Need cuts ahead of company for the same reason it cuts ahead "
            "of curiosity ([C25])" % got.get("dryToAnyone"))
    if int(got.get("spent") or 0) != 0:
        faults.append(
            "a sighting already walked to and found empty was chosen %s "
            "times. Knowledge that did not pan out sends somebody to the "
            "same doorstep every day forever ([C25])" % got.get("spent"))
    if got.get("atX") not in ("10650", "10650.0"):
        faults.append(
            "the goal pointed at %s rather than where they last saw them"
            % got.get("atX"))

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
        print("  138) the dormant day can go to a person: FAIL")
        return 1
    print("  138) somebody trusted and recently seen is somewhere to go, "
          "and thirst, hostility, the company line and a spent address "
          "each stop it: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
