#!/usr/bin/env python3
r"""Border 141: visits preserve personal familiarity without assigning residence.

Production Standing, Perception and dormant scheduling run in installed Kahlua.
Repeated visits supply neither a collective property claim nor the members'
assent to relocate. Existing exact Afflicted arrival checks remain covered.
The control restores automatic group claims and member rehoming and must fail
the same current residence verdict. Bodies and the clock are controlled.
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
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_WorldKnowledge.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "shared/SAO_PhysicalFacts.lua",
    "client/SAO_PopulationAdmissions.lua",
    "client/SAO_PopulationRepresentation.lua",
    "client/SAO_DormantPopulation.lua",
    "client/SAO_Population.lua",
]

PRELUDE = r'''
SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
ModData = { getOrCreate = function(k) __md[k] = __md[k] or {} return __md[k] end }
getWorld = function() return {
    getWorld = function() return "BorderSave" end,
    getMetaGrid = function() return nil end } end
getCell = function() return {
    getCellSizeInSquares = function() return 300 end } end
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
SAO.Body = { active = {}, get = function() return nil end,
    hasRepresentation = function() return false end,
    recover = function() return true end }
SAOJavaBridge = {
    daysBehindAtStart = function() return 0 end,
    recordDayToday = function() return 0 end,
    countyMonth = function() return 5 end,
    surveyClaim = function() return "ways=6 boarded=0 rooms=4" end,
    listKnoxHumans = function() return "" end,
    isCombatPatchReady = function() return false end,
    forenameCount = function() return 0 end,
    surnameCount = function() return 0 end,
}
'''

PROBE = r'''(function()
  -- [C112] moved every cadence onto the county's clock, and this
  -- harness used to leave that clock frozen: __hours never moved, so
  -- History.ticks read zero for the whole probe, the population pass
  -- gate opened exactly once, and every settle() after the first
  -- measured nothing while its cases read as real passes. The engine
  -- advances the county's hours as it burns frames; the wrapper does
  -- the same - one call is a tenth of a county hour (900 ticks, past
  -- the 240-tick pass interval, so every call is a real pass), and
  -- settle()'s 720 calls are the three county days it always claimed
  -- to be.
  local realTick = _G.__handlers.OnTick
  local tick = function()
    _G.__hours = (_G.__hours or 0) + 0.1
    realTick()
  end

  local function person(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    r.homeX, r.homeY, r.homeZ = x, y, 0
    r.lastWaterDay, r.lastFoodDay, r.lastRiskDay = 0, 0, 0
    return r
  end

  -- A building somebody has been in, written the way arriving writes
  -- it. `visits` is what the real path increments; this sets it in one
  -- go rather than walking somebody there a hundred times. The tick is
  -- the county's own, the axis the real arrival path stamps on.
  local function beenTo(id, pid, cx, cy, visits, water)
    for _ = 1, visits do
      SAO.Perception.learnBuilding(id, {
        id = pid, cx = cx, cy = cy,
        minX = cx - 5, minY = cy - 5, maxX = cx + 5, maxY = cy + 5,
        offers = water and { water = true } or {},
      }, SAO.History.ticks(), "observed")
    end
  end

  local function house(name, a, b)
    if SAO.Standing.formCompany then
      SAO.Standing.formCompany({ a.id, b.id }, name)
    else
      SAO.Standing.joinGroup(a.id, name)
      SAO.Standing.joinGroup(b.id, name)
    end
  end

  local function settle()
    for _ = 1, 240 * 3 do tick() end
  end

  -- 1. A house of two. One building both of them keep going back to,
  --    one that only the first went back to more often.
  local a1 = person(9000, 9000)
  local a2 = person(9000, 9000)
  house("house-one", a1, a2)
  beenTo(a1.id, 101, 9100, 9000, 3, false)
  beenTo(a2.id, 101, 9100, 9000, 3, false)
  beenTo(a1.id, 102, 9200, 9000, 5, false)
  settle()
  local c1 = SAO.Standing.groupClaimOf("house-one")
  local at1 = c1 and (math.floor((c1.minX + c1.maxX) / 2)) or -1
  local home1 = a2.homeX or -1

  -- 2. A house whose people have never gone back anywhere.
  local b1 = person(9000, 12000)
  local b2 = person(9000, 12000)
  house("house-none", b1, b2)
  settle()
  local c2 = SAO.Standing.groupClaimOf("house-none")

  -- 3. A house of one.
  local d1 = person(9000, 14000)
  SAO.Standing.joinGroup(d1.id, "house-solo")
  beenTo(d1.id, 301, 9100, 14000, 9, false)
  settle()
  local c3 = SAO.Standing.groupClaimOf("house-solo")

  -- 4. Ground another living company already holds.
  local e1 = person(9000, 16000)
  local e2 = person(9000, 16000)
  house("house-late", e1, e2)
  SAO.Standing.setGroupClaim("house-held", 9090, 15990, 9110, 16010, 0)
  beenTo(e1.id, 401, 9100, 16000, 9, false)
  beenTo(e2.id, 401, 9100, 16000, 9, false)
  settle()
  local c4 = SAO.Standing.groupClaimOf("house-late")

  -- 5. An Afflicted route completes against the exact privately known
  --    building it started toward. Known-place records omit their map key, so
  --    comparing place.id would compare nil with nil and accept a stale route
  --    after another destination becomes the person's best current ground.
  local f1 = person(20000, 20000)
  ZAO = { StateStore = { read = function(id)
    if tostring(id) == tostring(f1.id) then
      return { terminalState = "afflicted" }
    end
    return nil
  end } }
  beenTo(f1.id, 501, 20100, 20000, 2, false)
  local staleDestination = SAO.Standing.outcastDriftDestination(f1.id)
  beenTo(f1.id, 502, 20200, 20000, 5, false)
  local arrived = {
    getX = function() return 20200 end,
    getY = function() return 20000 end,
    getZ = function() return 0 end,
  }
  local staleAccepted = SAO.Standing.completeOutcastDrift(
    f1.id, arrived, staleDestination)
  local currentDestination = SAO.Standing.outcastDriftDestination(f1.id)
  local currentAccepted = SAO.Standing.completeOutcastDrift(
    f1.id, arrived, currentDestination)

  return "at1=" .. at1 .. " home1=" .. home1
    .. " none=" .. (c2 and "claimed" or "nothing")
    .. " solo=" .. (c3 and "claimed" or "nothing")
    .. " overHeld=" .. (c4 and "claimed" or "nothing")
    .. " driftStale=" .. (staleAccepted and "accepted" or "refused")
    .. " driftCurrent=" .. (currentAccepted and "accepted" or "refused")
    .. " driftId=" .. tostring(currentDestination and currentDestination.id)
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


def probe(expr, overrides=None):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        for index, module in enumerate(MODULES):
            source=LUA/module
            if source.exists():
                if overrides and module in overrides:
                    source=work/f'changed-{index}.lua'
                    source.write_text(overrides[module],encoding='utf-8')
                args.append(str(source))
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


def strip_prose(text):
    out = []
    for line in text.splitlines():
        cut = line.find("--")
        out.append(line if cut < 0 else line[:cut])
    return "\n".join(out)


def main():
    faults = []
    print("=" * 74)
    print("DORMANT RESIDENCE AND PERSONAL RETURN HISTORY")
    print("=" * 74)

    pop = strip_prose(read(LUA / "client" / "SAO_DormantPopulation.lua"))
    seams = {
        "the scheduled compatibility owner remains available":
            "local function dormantSettle()" in pop,
        "the gate runs this border": "tools/settle_test.py" in read(CHECK),
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
        print("  141) a house takes ground: TEXT ONLY, the engine install "
              "is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     four houses, and what each one ended up holding:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    if got.get("at1") != "-1":
        faults.append("repeated personal visits created a collective property claim")
    if got.get("home1") != "9000":
        faults.append("a dormant member was rehomed without their own decision and arrival")
    source=read(LUA/"client/SAO_DormantPopulation.lua")
    anchor="local function dormantSettle()\n    return 0\nend"
    restored="""local function dormantSettle()
    for id,rec in pairs(SAO.Identity.all()) do
        local group=SAO.Standing.groupOf(id)
        if group and not SAO.Standing.groupClaimOf(group) and SAO.Standing.groupSize(group)>1 then
            local members=SAO.Standing.membersOf(group)
            local first=SAO.Perception.returnsOf(members)[1]
            if first then
                local p=first.place
                SAO.Standing.setGroupClaim(group,p.minX-1,p.minY-1,p.maxX+1,p.maxY+1,0)
                for _,mid in ipairs(members) do
                    local r=SAO.Identity.get(mid)
                    r.homeX,r.homeY,r.homeZ=p.cx,p.cy,0
                end
                return 1
            end
        end
    end
end"""
    if source.count(anchor)!=1:
        faults.append("the dormant relocation control anchor differs")
    else:
        control=numbers(probe(PROBE,{"client/SAO_DormantPopulation.lua":source.replace(anchor,restored,1)}))
        if control.get("at1")=="-1" or control.get("home1")=="9000" or not control:
            faults.append("restored automatic relocation did not flip the current residence verdict")
    if got.get("none") != "nothing":
        faults.append(
            "a house whose people have never gone back anywhere took "
            "ground anyway. Nothing is placed: a house with no candidate "
            "holds nothing, and that is a correct outcome rather than a "
            "failure")
    if got.get("solo") != "nothing":
        faults.append(
            "a house of one took ground. A group of one is a memory "
            "rather than a membership ([C67]), and it does not hold land")
    if got.get("overHeld") != "nothing":
        faults.append(
            "a house claimed ground another living company already "
            "holds. Contested ground comes from politics, not from "
            "blindness ([A24])")
    if got.get("driftStale") != "refused":
        faults.append(
            "an Afflicted person's completed route was credited to a newly "
            "ranked building it never targeted. Completion must revalidate "
            "the exact private known-place key, not compare two absent "
            "place.id fields")
    if got.get("driftCurrent") != "accepted" or got.get("driftId") != "502":
        faults.append(
            "the Afflicted arrival could not commit the current privately "
            "known unheld ground after the exact building key was revalidated")

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
        print("  141) dormant residence remains person-owned: "
              "FAIL")
        return 1
    print("  141) visits retain personal familiarity; no inferred property or mass rehome; "
          "exact Afflicted arrival retained; automatic-relocation control: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
