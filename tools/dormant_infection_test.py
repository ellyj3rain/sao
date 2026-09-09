#!/usr/bin/env python3
r"""Border 143 - the unwatched county can catch it ([C79]).

`knoxInfected` and `biteDeathAtHours` had exactly one writer in the
tree: the block that releases a body to the dormant county, reading the
bite off the character as it goes dark. So nobody out there was ever
bitten. The county's people died of thirst, of hunger and of the risk
the county carries, and never of Knox they caught themselves.

`[C78]` gave the infected a fight, and it reached almost nobody -
because almost nobody out there was ever infected. This is the half
that makes it matter: when the county takes somebody, the encounter
either kills them or they get away from it having been opened up, and
on this build a bite infects with certainty (F-047), so getting away IS
catching it.

WHAT THIS HOLDS, WHICH IS THE MECHANISM AND NOT THE RATE.

How often a county catches Knox is a distribution and belongs to the
sweep, for `[C69]`'s reason - a border is a point and a county is a
distribution. What is a point, and what this asserts, is that the path
EXISTS and is bounded: that infections appear at all where they
previously could not, that they resolve both ways rather than being a
slower death sentence, and that a mortality setting with no window
infects nobody instead of stamping a clock that already expired.

ITS CONTROL is the `[C78]` tree, where `dormantAttrition` has no bite
path and a dormant county runs for a year with not one infection in it.
The border prints that rather than merely failing.
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
    "shared/SAO_Course.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

# The county's risk dial is wound up so encounters happen inside a
# bounded run. What is being asserted is that the PATH exists, not how
# busy it is; the rate is the sweep's to report.
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
    DormantRisk = 30, DayZero = false,
    MaterializeRadius = 45, HibernateRadius = 70,
}, ZombieLore = { Transmission = 1, Mortality = 5 } }
SAO.Body = { active = {}, get = function() return nil end }
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

-- A county of people who are drinking and eating, so nothing here dies
-- of thirst and every death is the county taking them.
function COUNTY(n, housed)
    local out = {}
    for i = 1, n do
        local r = SAO.Identity.create(nil, nil, 9000 + i, 9000, 0)
        pcall(function() SAO.History.generate(r.id, r) end)
        r.homeX, r.homeY, r.homeZ = 9000 + i, 9000, 0
        r.lastRiskDay = 0
        out[#out + 1] = r
    end
    -- Care is the thing the model says is decisive, so half the runs
    -- need somebody being cared for. A house of two, with a hearth
    -- burning, which is what `qualityOf` reads.
    if housed then
        for i = 1, n, 2 do
            local a, b2 = out[i], out[i + 1]
            if a and b2 then
                local name = "house-" .. i
                if SAO.Standing.formCompany then
                    SAO.Standing.formCompany({ a.id, b2.id }, name)
                else
                    SAO.Standing.joinGroup(a.id, name)
                    SAO.Standing.joinGroup(b2.id, name)
                end
                pcall(function()
                    SAO.Standing.setHearth(name, 9000 + i, 9000, 0, true)
                end)
            end
        end
    end
    return out
end

-- One county day: the clock moves, everybody's water and food stay
-- current, and the pass runs.
function DAY(people)
    local tick = _G.__handlers.OnTick
    _G.__hours = _G.__hours + 24
    local today = math.floor(_G.__hours / 24)
    for _, r in ipairs(people) do
        r.lastWaterDay, r.lastFoodDay = today, today
    end
    for _ = 1, 240 do tick() end
end

-- What the county looks like after a run.
function CENSUS(people)
    local infected, survived, dead, rose = 0, 0, 0, 0
    for _, r in ipairs(people) do
        if r.knoxInfected then infected = infected + 1 end
        survived = survived + (tonumber(r.infectionsSurvived) or 0)
        if r.dead then
            dead = dead + 1
            if r.turnedDormant then rose = rose + 1 end
        end
    end
    return infected, survived, dead, rose
end
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
    return {k: float(v) for k, v in
            re.findall(r"([A-Za-z_]+)=(-?[0-9.eE+-]+)", line or "")}


def main():
    faults = []
    print("=" * 74)
    print("THE UNWATCHED COUNTY CAN CATCH IT")
    print("=" * 74)

    pop = (LUA / "client" / "SAO_Population.lua").read_text(
        encoding="utf-8", errors="ignore")
    if "ESCAPE_BASE" not in pop:
        print("  143) the county can catch it: CONTROL")
        print("  CONTROL: `dormantAttrition` has no bite path on this")
        print("  tree. `knoxInfected` is written only where a body is")
        print("  released to the dormant county, so a county can run for")
        print("  a year without one infection in it, and [C78]'s fight")
        print("  reaches nobody out there.")
        return 1

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print("  143) the county can catch it: TEXT ONLY, the engine "
              "install is absent")
        return 0

    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # 1. The path exists at all, and it resolves BOTH ways - some
    #    throw it off and some go down with it. An infection that only
    #    ever kills is a slower death sentence, which is what [C78]
    #    was written against.
    line = probe(
        '(function()'
        ' local p = COUNTY(120, true)'
        ' for _ = 1, 200 do DAY(p) end'
        ' local inf, surv, dead, rose = CENSUS(p)'
        ' return "infected=" .. inf .. " survived=" .. surv'
        ' .. " dead=" .. dead .. " rose=" .. rose'
        ' end)()')
    n = numbers(line)
    if len(n) < 4:
        print("  FAULT: the county probe returned nothing usable")
        print("    " + str(line)[:300])
        faults.append("county")
    else:
        print("  120 people, 200 county days, risk wound up:")
        print("    carrying it at the end : %d" % int(n["infected"]))
        print("    threw it off           : %d" % int(n["survived"]))
        print("    died                   : %d" % int(n["dead"]))
        print("    ...and rose            : %d" % int(n["rose"]))
        if n["infected"] + n["survived"] + n["rose"] == 0:
            print("  FAULT: a whole county ran and nobody ever caught it.")
            faults.append("never")
        if n["survived"] == 0:
            print("  FAULT: nobody ever threw one off, so an infection")
            print("  out there is a slower death sentence and [C78]")
            print("  reaches nothing.")
            faults.append("hopeless")
        if n["rose"] == 0:
            print("  FAULT: nobody who died of it rose, so catching it")
            print("  costs the county nothing it would not have paid.")
            faults.append("harmless")

    # 1b. And care is what makes the difference. The same county with
    #     nobody keeping anybody throws off fewer, because a house, a
    #     hearth and a pact are most of what `qualityOf` can offer a
    #     body that is already drinking.
    line = probe(
        '(function()'
        ' local p = COUNTY(120, false)'
        ' for _ = 1, 200 do DAY(p) end'
        ' local inf, surv, dead, rose = CENSUS(p)'
        ' return "alone=" .. surv .. " dead=" .. dead'
        ' end)()')
    n1b = numbers(line)
    if len(n1b) == 2 and "survived" in n:
        print("  the same county with nobody keeping anybody:")
        print("    threw it off           : %d" % int(n1b["alone"]))
        if n1b["alone"] > n["survived"]:
            print("  FAULT: being kept by a house makes somebody WORSE at")
            print("  surviving a bite, so the care terms are inverted.")
            faults.append("care")
    else:
        faults.append("care")

    # 2. A mortality setting with no window infects nobody. The guard
    #    matters because a zero span would stamp a clock that has
    #    already expired and hand the course an impossible position.
    line = probe(
        '(function()'
        ' SandboxVars.ZombieLore.Mortality = 1'
        ' local p = COUNTY(120)'
        ' for _ = 1, 200 do DAY(p) end'
        ' local inf, surv, dead, rose = CENSUS(p)'
        ' return "infected=" .. inf .. " survived=" .. surv'
        ' .. " dead=" .. dead'
        ' end)()')
    n2 = numbers(line)
    if len(n2) == 3:
        print("  with no mortality window at all:")
        print("    carrying it : %d" % int(n2["infected"]))
        print("    threw it off: %d" % int(n2["survived"]))
        print("    died        : %d" % int(n2["dead"]))
        if n2["infected"] + n2["survived"] > 0:
            print("  FAULT: somebody caught it where the setting gives")
            print("  the infection no course to run.")
            faults.append("window")
        if n2["dead"] == 0:
            print("  FAULT: nobody died either, so the bite path is")
            print("  swallowing the encounter instead of guarding it.")
            faults.append("swallowed")
    else:
        faults.append("window")

    print("-" * 74)
    if faults:
        print("  143) the unwatched county can catch it: FAIL")
        print("REFUSED: " + ", ".join(sorted(set(faults))))
        return 1
    print("  143) the county catches it, throws some of it off, and "
          "buries the rest")
    print("MATCH: infections arise out there where they could not before,")
    print("they resolve both ways, and a setting with no course infects")
    print("nobody.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
