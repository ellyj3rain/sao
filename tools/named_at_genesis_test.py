#!/usr/bin/env python3
r"""Border 139 - a person is named when they are made ([C73], DR-039).

`backfillName` read a forename and surname off the engine descriptor
the first time a body was materialised for somebody, so a survivor
nobody had ever stood near carried the `Unnamed` sentinel for the life
of the save. Measured in the engine's own VM against the shipped map:
271 of 271 people in a dormant county. `[C71]` made that survivable by
keying beliefs on the person rather than on what they are called; the
operator ruled for the cure.

A name is a fact about a person and not about their body. It is drawn
at `Identity.create`, the one funnel every person is made through, out
of the engine's own pools - `SurvivorFactory.MaleForenames`,
`FemaleForenames` and `Surnames`, public statics needing no body - with
`SAO.Rand` picking the index so a county still runs twice the same way
([C66]) and this project ships no name list of its own.

The pools are split by sex, so the record carries one. It is a hash
fact like every durable trait, drawn against Kentucky's own rate rather
than a half: 1,837,344 male and 1,954,944 female on July 1 1993,
51.551 percent female, summed over every county and age band of the
Census Bureau's intercensal estimates (CO-99-12, `casrh21.txt`).

THIS BORDER MEASURES THE RECORD AND THE DRAW, NOT THE CALL.

A border asserting that `Identity.create` calls `nameFromEngine` would
pass a tree that called it and dropped the answer. Everything below
runs the shipped modules in the engine's own VM and reads the records
that come out.

The properties:

  * A PERSON MADE WITH NO NAME COMES OUT WITH ONE, before any body
    exists.
  * THE NAME MATCHES THE SEX. A female record draws from the female
    pool; the two are not independently drawn.
  * THE DRAW IS THE COUNTY'S. Two runs of the same save produce the
    same names, and two different saves do not.
  * NO POOL IS NO CRASH. Without a bridge the record keeps the
    sentinel and nothing throws - which is the pre-batch behaviour,
    and `[C71]` is what makes it survivable.
  * THE SPLIT IS THE SOURCED ONE. Over a thousand people the female
    share sits near 51.551 percent rather than near a half.
  * A CALLER THAT PASSED A NAME KEEPS IT. Knox adoption brings people
    who arrive already named.

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
BRIDGE_SRC = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"

MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
]

# The engine's pools, stood in for by two small ones whose members
# cannot be confused: every male name starts with M and every female
# name with F, so a name drawn from the wrong pool is visible in the
# answer rather than inferred from a count.
POOLS = '''
_G.__MALE = { "Marcus", "Miles", "Morgan", "Mitchell", "Malcolm" }
_G.__FEMALE = { "Fern", "Frida", "Florence", "Faye", "Frances" }
_G.__SUR = { "Abbot", "Baird", "Crane", "Dover", "Ellis" }
'''

PRELUDE = r'''
SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
ModData = { getOrCreate = function(k) __md[k] = __md[k] or {} return __md[k] end }
getWorld = function() return {
    getWorld = function() return _G.__save or "BorderSave" end,
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
Events = setmetatable({}, { __index = function(t, k)
    local slot = { Add = function() end, Remove = function() end }
    rawset(t, k, slot)
    return slot
end })
SandboxVars = { SurvivorAwareness = {
    Enable = true, Telemetry = false, TrustToCompany = 0.5,
    Population = 216, DayZero = false,
}, ZombieLore = { Transmission = 1 } }
SAO.Body = { active = {}, get = function() return nil end }
POOLS_HERE
_G.__bridge = {
    daysBehindAtStart = function() return 0 end,
    recordDayToday = function() return 0 end,
    forenameCount = function(self, female)
        return female and #_G.__FEMALE or #_G.__MALE end,
    forenameAt = function(self, female, i)
        local pool = female and _G.__FEMALE or _G.__MALE
        return pool[i + 1] or "" end,
    surnameCount = function(self) return #_G.__SUR end,
    surnameAt = function(self, i) return _G.__SUR[i + 1] or "" end,
}
SAOJavaBridge = _G.__bridge
'''.replace("POOLS_HERE", POOLS)

PROBE = r'''(function()
  local function make() return SAO.Identity.create(nil, nil, 10, 10, 0) end
  -- A tree without the verb must report what is missing rather than
  -- throw: a control has to fail NAMING the thing that is broken.
  local function femaleOf(r)
    if not SAO.Identity.femaleOf then return nil end
    return SAO.Identity.femaleOf(r)
  end

  -- A person made with no name, before any body exists.
  local a = make()
  local named = tostring(a.forename)
  local sur = tostring(a.surname)

  -- The name and the sex are one draw, not two. Every male pool name
  -- starts with M and every female one with F, so a name from the
  -- wrong pool shows in the answer.
  local wrongPool, people = 0, 0
  local female = 0
  local firstNames = {}
  for i = 1, 400 do
    local r = make()
    people = people + 1
    local f = femaleOf(r)
    if f == true then female = female + 1 end
    local initial = string.sub(tostring(r.forename), 1, 1)
    if f == nil then
      -- No sex on the record at all: every name is from the wrong
      -- pool because there is no right one to be from.
      wrongPool = wrongPool + 1
    elseif (f and initial ~= "F") or ((not f) and initial ~= "M") then
      wrongPool = wrongPool + 1
    end
    if i <= 3 then firstNames[#firstNames + 1] = tostring(r.forename) end
  end

  -- A caller that passed a name keeps it.
  local kept = SAO.Identity.create("Nicole", "Reyes", 10, 10, 0)
  local keptName = tostring(kept.forename) .. "/" .. tostring(kept.surname)

  -- No pool is no crash: the sentinel stands and nothing throws.
  SAOJavaBridge = nil
  local okBare, bare = pcall(function()
    local r = SAO.Identity.create(nil, nil, 10, 10, 0)
    return tostring(r.forename)
  end)
  SAOJavaBridge = _G.__bridge

  return "named=" .. named .. " sur=" .. sur
    .. " wrongPool=" .. wrongPool .. " people=" .. people
    .. " female=" .. female
    .. " sample=" .. table.concat(firstNames, "|")
    .. " kept=" .. keptName
    .. " bareOk=" .. tostring(okBare) .. " bare=" .. tostring(bare)
end)()'''

# The same save twice, and a different save once: the draw is the
# county's own and is seeded off the save ([C66]).
REPLAY = r'''(function()
  _G.__save = "SAVE_ID"
  local out = {}
  for i = 1, 5 do
    local r = SAO.Identity.create(nil, nil, 10, 10, 0)
    out[#out + 1] = tostring(r.forename) .. tostring(r.surname)
  end
  return table.concat(out, ",")
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
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:'|]+)", line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("A PERSON IS NAMED WHEN THEY ARE MADE")
    print("=" * 74)

    ident = read(LUA / "shared" / "SAO_Identity.lua")
    body = read(LUA / "client" / "SAO_Body.lua")
    bridge = read(BRIDGE_SRC)
    seams = {
        "a record carries which half of the county it is":
            "function Identity.femaleOf(" in ident,
        "the name comes from the engine's own pools":
            "function Identity.nameFromEngine(" in ident
            and "SurvivorFactory.FemaleForenames" in bridge,
        "the county makes the draw, not the engine":
            re.search(r"SAO\.Rand\.int\(\s*[nm]\s*\)", ident) is not None,
        "the share is sourced rather than halved":
            re.search(r"FEMALE_SHARE\s*=\s*0\.5[0-9]+", ident) is not None
            and "1,954,944" in ident,
        "the shell is built to the record's sex":
            "femaleOf(rec)" in body and "desc.setFemale(" in bridge,
        "the gate runs this border":
            "tools/named_at_genesis_test.py" in read(CHECK),
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
        print("  139) a person is named when they are made: TEXT ONLY, "
              "the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     four hundred people made, and no body anywhere:")
    print("       " + line)

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    if got.get("named") in (None, "Unnamed", "nil"):
        faults.append(
            "a person made with no name came out as %s. That is the "
            "defect this border exists for: a name arrived off the first "
            "shell ever built for somebody, so a county that materialises "
            "nobody had 271 people all rendering as one string"
            % got.get("named"))
    if got.get("sur") in (None, "Survivor", "nil"):
        faults.append("the person came out with no surname (%s)"
                      % got.get("sur"))
    if got.get("wrongPool") != "0":
        faults.append(
            "%s of %s people drew a forename from the pool for the other "
            "sex. The pools are split and the record carries which one it "
            "is; drawing them independently gives a name the body will "
            "contradict" % (got.get("wrongPool"), got.get("people")))
    try:
        n = int(got.get("people") or 0)
        f = int(got.get("female") or 0)
        share = f / float(n) if n else 0.0
    except ValueError:
        n, share = 0, 0.0
    print("       female share over %d: %.3f (sourced 0.516)" % (n, share))
    if n and not (0.44 <= share <= 0.59):
        faults.append(
            "the county came out %.1f percent female over %d people. The "
            "share is Kentucky's own - 51.551 percent on July 1 1993 - "
            "and a draw this far from it is not that figure"
            % (100.0 * share, n))
    if got.get("kept") != "Nicole/Reyes":
        faults.append(
            "a caller that passed a name got %s back. Knox adoption "
            "brings people who arrive already named and this must not "
            "overwrite them" % got.get("kept"))
    if got.get("bareOk") != "true":
        faults.append("making a person without a bridge threw")
    if got.get("bare") != "Unnamed":
        faults.append(
            "without the engine's pools the record came out as %s rather "
            "than the sentinel. There is nowhere else for a name to come "
            "from, and inventing one here would ship a name list this "
            "project does not have" % got.get("bare"))

    same_a = probe(REPLAY.replace("SAVE_ID", "ReplaySave"))
    same_b = probe(REPLAY.replace("SAVE_ID", "ReplaySave"))
    other = probe(REPLAY.replace("SAVE_ID", "OtherSave"))
    print()
    print("     the same save twice, and a different one:")
    print("       A: " + same_a)
    print("       B: " + same_b)
    print("       C: " + other)
    if same_a.startswith("ERROR") or same_a != same_b:
        faults.append(
            "the same save produced different names twice, so a county "
            "cannot be run again - which is what [C66] exists for")
    if same_a == other:
        faults.append(
            "two different saves produced the same names, so the draw is "
            "not seeded off the save")

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
        print("  139) a person is named when they are made: FAIL")
        return 1
    print("  139) a person is named where they are made, from the engine's "
          "pools on the county's own draw, at Kentucky's own split: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
