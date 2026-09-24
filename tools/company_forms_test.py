#!/usr/bin/env python3
r"""Border 135 - a roster can form without manufacturing government.

The roster primitive writes two consenting founders atomically, a standing
house can admit a third person through its owning procedure, and shrink-only
lifecycle cleanup still releases a widow. Founding itself assigns no leader,
office, job, policy, assent or outcome; those require their own enacted process.
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
STANDING = LUA / "shared" / "SAO_Standing.lua"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# Load the real roster and identity owners in the engine VM.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_WorldKnowledge.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
]

PRELUDE = r'''
SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
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
Events = setmetatable({}, { __index = function(t, k)
    local slot = { Add = function() end, Remove = function() end }
    rawset(t, k, slot)
    return slot
end })
SandboxVars = { SurvivorAwareness = {
    Enable = true, Telemetry = false, TrustToCompany = 0.5,
    Population = 216, DayZero = false,
}, ZombieLore = { Transmission = 1 } }
SAO.Body = { active = {}, get = function() return nil end,
    hasRepresentation = function() return false end,
    recover = function() return true end }
SAOJavaBridge = {
    daysBehindAtStart = function() return 0 end,
    recordDayToday = function() return 0 end,
}
'''

# Exercise the roster primitive directly. Production encounter callers are
# separately held to `proposeCompany`, where both people acquire and answer.
FOUND = r'''(function()
  local s = ModData.getOrCreate("SurvivorAwareness_Standing")
  local function size(g)
    local n = 0
    for _, gg in pairs(s.groups or {}) do if gg == g then n = n + 1 end end
    return n
  end
  local a = SAO.Identity.create(nil, nil, 10500, 9000, 0)
  local b = SAO.Identity.create(nil, nil, 10500, 9000, 0)
  pcall(function() SAO.History.generate(a.id, a) end)
  pcall(function() SAO.History.generate(b.id, b) end)
  SAO.Standing.adjustTrust(a.id, b.id, 0.85)
  SAO.Standing.adjustTrust(b.id, a.id, 0.85)
  local name = "company-" .. a.id
  if SAO.Standing.formCompany then
    SAO.Standing.formCompany({ a.id, b.id }, name)
  else
    SAO.Standing.joinGroup(a.id, name)
    SAO.Standing.joinGroup(b.id, name)
  end
  local born = size(name)
  local lead = tostring(SAO.Standing.leaderOf(name))
  local jobs = tostring(a.designation) .. "/" .. tostring(b.designation)
  local c = SAO.Identity.create(nil, nil, 10500, 9000, 0)
  pcall(function() SAO.History.generate(c.id, c) end)
  SAO.Standing.joinGroup(c.id, name)
  local three = size(name)
  SAO.Standing.leaveGroup(c.id)
  local stillTwo = size(name)
  SAO.Standing.leaveGroup(b.id)
  local widow = size(name)
  local freed = tostring(SAO.Standing.groupOf(a.id))
  local freedJob = tostring(a.designation)
  local solo = "absent"
  if SAO.Standing.formCompany then
    SAO.Standing.formCompany({ c.id }, "company-solo")
    solo = tostring(SAO.Standing.groupOf(c.id))
  end
  return "born=" .. born .. " leader=" .. lead .. " jobs=" .. jobs
    .. " third=" .. three .. " stillTwo=" .. stillTwo
    .. " widow=" .. widow .. " freed=" .. freed
    .. " freedJob=" .. freedJob .. " solo=" .. solo
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
        args += [str(LUA / m) for m in MODULES]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-300:]
    return out[at + 6:].strip().split("\n")[0]


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:']+)", line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def one_at_a_time():
    """Sites that still write a company's roster a member at a time."""
    found = []
    for path in sorted(LUA.rglob("*.lua")):
        lines = read(path).splitlines()
        for i in range(len(lines) - 1):
            if "joinGroup(" not in lines[i]:
                continue
            nxt = lines[i + 1].strip()
            if nxt.startswith("--") or not nxt:
                continue
            if "joinGroup(" in nxt:
                found.append("%s:%d" % (path.relative_to(LUA).as_posix(),
                                        i + 1))
    return found


def main():
    faults = []
    print("=" * 74)
    print("A FOUNDED COMPANY IS STILL STANDING AFTERWARDS")
    print("=" * 74)
    if not STANDING.exists():
        print("  FAULT: SAO_Standing.lua does not exist")
        return 1

    strays = one_at_a_time()
    print("  sites founding a company a member at a time: %d" % len(strays))
    for name in strays[:6]:
        print("      " + name)

    seams = {
        "a company is founded from its roster":
            "function S.formCompany(" in read(STANDING),
        "the widow release remains lifecycle cleanup":
            "function S.maintainRoster(" in read(STANDING)
            and "s.groups[widow] = nil" in read(STANDING),
        "founding assigns no automatic authority or work":
            "assigns no leader, office, job, policy, assent, or outcome"
            in read(STANDING),
        "no site founds a company a member at a time":
            not strays,
        "the gate runs this border":
            "tools/company_forms_test.py" in read(CHECK),
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
        print("  135) a founded company: TEXT ONLY, the engine install "
              "is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(FOUND)
    got = numbers(line)
    print()
    print("     two people at mutual trust 0.85 found a company:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the founding")
        return 1

    if got.get("born") != "2":
        faults.append(
            "founding a company from two people left a house of %s. That "
            "is the defect this border exists for: joining one member and "
            "then the other passes through a roster of one, where the "
            "election performs the widow release, so the company is "
            "dissolved by the act of founding it and no social structure "
            "can form in the county at all" % got.get("born"))
    if got.get("leader") != "nil":
        faults.append("founding manufactured a leader (%s) without an "
                      "enacted authority process" % got.get("leader"))
    jobs = got.get("jobs") or ""
    if jobs != "nil/nil":
        faults.append("founding manufactured work designations (%s) without "
                      "an accepted work process" % jobs)
    if got.get("third") != "3":
        faults.append("a third member joining a standing house left %s in "
                      "it, so the plain single join no longer works once "
                      "there IS a house to join" % got.get("third"))
    if got.get("stillTwo") != "2":
        faults.append("a house of three lost one member and became %s: a "
                      "house that shrinks to two still stands"
                      % got.get("stillTwo"))
    if got.get("widow") != "0":
        faults.append(
            "a house that shrank to one still holds %s member(s). The "
            "widow release is the rule that a group of one is a memory "
            "rather than a membership, and it is right - this batch only "
            "stops it firing in the middle of a founding, never removes it"
            % got.get("widow"))
    if got.get("freed") != "nil":
        faults.append("the last member of a dissolved house is still in "
                      "it (%s)" % got.get("freed"))
    if got.get("freedJob") != "nil":
        faults.append("the released widow kept their designation (%s): "
                      "there is no work without a house to do it for"
                      % got.get("freedJob"))
    if got.get("solo") == "absent":
        faults.append("this tree has no founding verb to ask, so a house "
                      "of one could not be tested")
    elif got.get("solo") != "nil":
        faults.append(
            "a house of ONE was founded (%s). The founding verb must not "
            "smuggle a roster of one past the rule it stops firing "
            "mid-sentence" % got.get("solo"))

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
        print("  135) a founded company: FAIL")
        return 1
    print("  135) a consenting roster stands without an automatic leader or "
          "jobs, and a house that shrinks to one still ends: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
