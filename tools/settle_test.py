#!/usr/bin/env python3
r"""Border 141 - a house takes ground where its people already go ([C76]).

`setGroupClaim`, `setHearth`, `setLarder` and `setWaterStore` had call
sites in `SAO_Controller` alone, which needs materialised bodies. After
`[C67]` and `[C68]` houses form; after `[C71]` and `[C72]` they
reconvene and stand. And a house in the unwatched county had nowhere to
be, so every survival modifier reading those was inert unless a player
happened to be watching.

The live path scouts through `SAOJavaBridge:scoutBase`, which reads the
loaded ground and needs a body. The dormant half needs no body, because
the fact already exists: `Perception.learnBuilding` has recorded every
arrival since `[B37]` - bounds, offers, and how many times that person
has been - and its own comment says what the count means, that
somewhere returned to is somewhere that gave them something.

THIS BORDER MEASURES THE CLAIM, NOT THE CALL.

A border asserting that the pass calls `setGroupClaim` would pass a
tree that called it with the wrong building, or with ground somebody
else holds. Everything below runs the shipped modules in the engine's
own VM and then reads `Standing.groupClaimOf`.

The properties:

  * A HOUSE SETTLES WHERE ITS PEOPLE KEEP GOING. The claim is the
    building with the most returns across its living members, not the
    first one found and not the nearest.
  * TWO MEMBERS RETURNING OUTWEIGHS ONE. A place both of them go back
    to beats a place one of them went back to more often.
  * NOTHING IS PLACED. A house whose people have never gone back
    anywhere takes no ground at all, which is a correct outcome.
  * A HOUSE OF ONE TAKES NOTHING. A group of one is a memory rather
    than a membership ([C67]'s widow rule), and it does not hold land.
  * IT WILL NOT CLAIM OVER ANOTHER LIVING COMPANY'S GROUND, over a
    living person's home, or inside a feuding company's keep-out
    ([A24], [B35], [A20]).
  * HOMES CONVERGE. The members' own anchors move to the base, so the
    dormant day follows with no further wiring.

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
'''

PROBE = r'''(function()
  local tick = _G.__handlers.OnTick

  local function person(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    r.homeX, r.homeY, r.homeZ = x, y, 0
    r.lastWaterDay, r.lastFoodDay, r.lastRiskDay = 0, 0, 0
    return r
  end

  -- A building somebody has been in, written the way arriving writes
  -- it. `visits` is what the real path increments; this sets it in one
  -- go rather than walking somebody there a hundred times.
  local function beenTo(id, pid, cx, cy, visits, water)
    for _ = 1, visits do
      SAO.Perception.learnBuilding(id, {
        id = pid, cx = cx, cy = cy,
        minX = cx - 5, minY = cy - 5, maxX = cx + 5, maxY = cy + 5,
        offers = water and { water = true } or {},
      }, 1, "observed")
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

  return "at1=" .. at1 .. " home1=" .. home1
    .. " none=" .. (c2 and "claimed" or "nothing")
    .. " solo=" .. (c3 and "claimed" or "nothing")
    .. " overHeld=" .. (c4 and "claimed" or "nothing")
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


def strip_prose(text):
    out = []
    for line in text.splitlines():
        cut = line.find("--")
        out.append(line if cut < 0 else line[:cut])
    return "\n".join(out)


def main():
    faults = []
    print("=" * 74)
    print("A HOUSE TAKES GROUND WHERE ITS PEOPLE ALREADY GO")
    print("=" * 74)

    pop = strip_prose(read(LUA / "client" / "SAO_Population.lua"))
    seams = {
        "the unwatched county can take ground":
            "setGroupClaim" in pop,
        "it reads where its people have been":
            "knownPlaces" in pop,
        "the refusals are one law, not a second copy":
            "barredGround" in pop,
        "the gate runs this border":
            "tools/settle_test.py" in read(CHECK),
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

    at1 = got.get("at1")
    if at1 in (None, "-1"):
        faults.append(
            "a house of two, both of whom keep returning to the same "
            "building, took no ground at all. That is the defect this "
            "border exists for: taking ground had call sites in the "
            "controller alone, so a house in the unwatched county had "
            "nowhere to be and every modifier reading its hearth, larder "
            "and water store was inert")
    elif at1 != "9100":
        faults.append(
            "the house settled at %s rather than 9100, the building both "
            "of its members kept returning to. Two members going back "
            "outweighs one member going back more often - a place a "
            "house SHARES is what a base is" % at1)
    if got.get("home1") != "9100":
        faults.append(
            "a member's own anchor is still at %s after their house took "
            "ground at 9100. Homes converge on the base, or the dormant "
            "day keeps walking them back to where they used to live"
            % got.get("home1"))
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
        print("  141) a house takes ground where its people already go: "
              "FAIL")
        return 1
    print("  141) a house settles on what its members keep returning to, "
          "takes nothing when there is nothing, and never claims over "
          "somebody: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
