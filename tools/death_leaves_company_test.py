#!/usr/bin/env python3
r"""Border 136 - a death leaves the company ([C68]).

`Identity.markDead` is the funnel every death path reaches, and its own
comments say twice why things belong there rather than on a call site:
"[B38] Every death path funnels here, so the instrument goes here too
rather than on the one call site that prompted it."

It forgets nine things about a dead survivor - perception, voice,
conditions, habits, the smoker assert, the pair cooldowns, politics,
the locomotion job, the controller agent - and never touches
`s.groups`. So a dead member stays on the roster forever:

    leaderWas=sao-1  deadStillOnRoster=true  rosterRows=2
    livingMembers=1  survivorStillInHouse=company-sao-1

The survivor is alone in a house the widow rule says may not exist, and
was never released, so they never got the group's claim as their own
and `Voice.onEvent(id, "aloneAgain")` - which the controller fires when
membership dissolves under someone - never fires for a death.

`electLeader` and `groupSize` both already filter the dead when they
run, so the semantics were always "the dead are not members". Nothing
ran them. One call site re-elected, in `SAO_Controller`, and only when
the corpse had been the LEADER - so a non-leader's death left the house
untouched, and the dormant half of the county, where most deaths
happen, had no equivalent at all.

None of this was reachable before `[C67]`, because no company existed.

THIS BORDER MEASURES THE HOUSE AFTER A DEATH.

The control is the `[C67]` tree, where a house of two loses its
non-leader and comes back holding two rows, one of them a corpse, with
the survivor still in it.

An optional argv[1] points the checker at another tree root.
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
IDENTITY = LUA / "shared" / "SAO_Identity.lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
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
SAO.Body = { active = {}, get = function() return nil end }
SAOJavaBridge = {
    daysBehindAtStart = function() return 0 end,
    recordDayToday = function() return 0 end,
}
'''

# A house of three loses its non-leader, then a second, then the last
# member stands alone. Every step is a death, never a departure.
DEATH = r'''(function()
  local s = ModData.getOrCreate("SurvivorAwareness_Standing")
  local function rows(g)
    local n = 0
    for _, gg in pairs(s.groups or {}) do if gg == g then n = n + 1 end end
    return n
  end
  local function living(g)
    if SAO.Standing.groupSize then return SAO.Standing.groupSize(g) end
    local n = 0
    for id, gg in pairs(s.groups or {}) do
      local r = SAO.Identity.get(id)
      if gg == g and not (r and r.dead) then n = n + 1 end
    end
    return n
  end
  local made = {}
  for i = 1, 3 do
    made[i] = SAO.Identity.create(nil, nil, 10500, 9000, 0)
    pcall(function() SAO.History.generate(made[i].id, made[i]) end)
  end
  for i = 1, 3 do
    for j = 1, 3 do
      if i ~= j then SAO.Standing.adjustTrust(made[i].id, made[j].id, 0.85) end
    end
  end
  local name = "company-" .. made[1].id
  if SAO.Standing.formCompany then
    SAO.Standing.formCompany({ made[1].id, made[2].id, made[3].id }, name)
  else
    for i = 1, 3 do SAO.Standing.joinGroup(made[i].id, name) end
  end
  local founded = rows(name)
  local leader = SAO.Standing.leaderOf(name)
  -- The group holds ground, so the widow release has something to hand on.
  s.groupClaims = s.groupClaims or {}
  s.groupClaims[name] = { minX = 1, minY = 2, maxX = 3, maxY = 4, z = 0 }
  -- A non-leader dies.
  local victim = nil
  for i = 1, 3 do if made[i].id ~= leader then victim = made[i] break end end
  SAO.Identity.markDead(victim, 0, "border")
  local afterOne = rows(name) .. "/" .. living(name)
  local corpseInHouse = tostring(SAO.Standing.groupOf(victim.id))
  -- The LEADER dies. This is the case `SAO_Controller` used to handle
  -- on its own, and this batch deleted that call site, so the funnel
  -- has to be shown doing its job. Its own people and its own house:
  -- borrowing the three above let this block decide their fate and
  -- broke every assertion after it.
  local leadGone = "n/a"
  do
    local p1 = SAO.Identity.create(nil, nil, 10600, 9100, 0)
    local p2 = SAO.Identity.create(nil, nil, 10600, 9100, 0)
    pcall(function() SAO.History.generate(p1.id, p1) end)
    pcall(function() SAO.History.generate(p2.id, p2) end)
    SAO.Standing.adjustTrust(p1.id, p2.id, 0.85)
    SAO.Standing.adjustTrust(p2.id, p1.id, 0.85)
    if SAO.Standing.formCompany then
      SAO.Standing.formCompany({ p1.id, p2.id }, "chair-test")
    else
      SAO.Standing.joinGroup(p1.id, "chair-test")
      SAO.Standing.joinGroup(p2.id, "chair-test")
    end
    local chair = SAO.Standing.leaderOf("chair-test")
    local other = (p1.id == chair) and p2.id or p1.id
    local chairRec = SAO.Identity.get(chair)
    if chairRec then SAO.Identity.markDead(chairRec, 0, "border") end
    leadGone = tostring(SAO.Standing.leaderOf("chair-test"))
      .. ":" .. tostring(SAO.Standing.groupOf(other))
  end

  -- A second non-leader dies: one living member is left.
  local victim2 = nil
  for i = 1, 3 do
    if made[i].id ~= leader and made[i].id ~= victim.id then
      victim2 = made[i]
    end
  end
  SAO.Identity.markDead(victim2, 0, "border")
  local afterTwo = rows(name) .. "/" .. living(name)
  local lastGroup = tostring(SAO.Standing.groupOf(leader))
  local lastClaim = (s.claims and s.claims[leader]) and "kept" or "lost"
  local lastJob = "nil"
  for i = 1, 3 do
    if made[i].id == leader then lastJob = tostring(made[i].designation) end
  end
  return "founded=" .. founded .. " leader=" .. tostring(leader)
    .. " afterOneDeath=" .. afterOne
    .. " corpseInHouse=" .. corpseInHouse
    .. " afterTwoDeaths=" .. afterTwo
    .. " lastMemberGroup=" .. lastGroup
    .. " lastMemberClaim=" .. lastClaim
    .. " lastMemberJob=" .. lastJob
    .. " chairDied=" .. leadGone
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


def main():
    faults = []
    print("=" * 74)
    print("A DEATH LEAVES THE COMPANY")
    print("=" * 74)
    if not IDENTITY.exists():
        print("  FAULT: SAO_Identity.lua does not exist")
        return 1

    seams = {
        "the death funnel releases the dead from their house":
            "leaveOnDeath" in read(IDENTITY) or "S.releaseDead" in read(STANDING),
        "the widow release is still in the election":
            "s.groups[widow] = nil" in read(STANDING),
        "no call site re-elects on a death of its own":
            "leadership passes from the dead" not in read(CONTROLLER),
        "the gate runs this border":
            "tools/death_leaves_company_test.py" in read(CHECK),
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
        print("  136) a death leaves the company: TEXT ONLY, the engine "
              "install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(DEATH)
    got = numbers(line)
    print()
    print("     a house of three loses two members to death:")
    print("       " + line)
    print()
    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the deaths")
        return 1

    if got.get("founded") != "3":
        faults.append("the house was not founded with three members (%s), "
                      "so nothing below measures what it claims"
                      % got.get("founded"))
    if got.get("afterOneDeath") != "2/2":
        faults.append(
            "a house of three lost one member to death and holds %s "
            "(rows/living). A corpse is not a member: electLeader and "
            "groupSize both already filter the dead, so leaving the row "
            "makes groupOf the only reader that disagrees with them"
            % got.get("afterOneDeath"))
    if got.get("corpseInHouse") != "nil":
        faults.append("the dead survivor is still in their house (%s)"
                      % got.get("corpseInHouse"))
    if got.get("afterTwoDeaths") != "0/0":
        faults.append(
            "the last living member of a house whose others DIED still "
            "holds %s (rows/living). The widow release fires when a "
            "housemate leaves and not when one dies, so a survivor is "
            "left alone in a house the rule says may not exist"
            % got.get("afterTwoDeaths"))
    if got.get("lastMemberGroup") != "nil":
        faults.append("the last member was never released (%s)"
                      % got.get("lastMemberGroup"))
    if got.get("lastMemberClaim") != "kept":
        faults.append(
            "the released widow did not keep the house: the group claim "
            "is meant to become their personal claim before it lapses, "
            "and a death took the ground with it")
    chair = got.get("chairDied")
    if chair == "n/a":
        faults.append("this tree has no founding verb, so the chair "
                      "case could not be set up")
    elif chair != "nil:nil":
        faults.append(
            "a house of two lost its LEADER and came back %s "
            "(leader:survivor's house), wanted nil:nil - the survivor "
            "is the last of a house and is released with it. This is "
            "the case SAO_Controller handled on its own before this "
            "batch, and that call site is gone, so the funnel has to "
            "do it for every death path including the dormant ones "
            "that never reached the controller at all" % chair)

    if got.get("lastMemberJob") != "nil":
        faults.append("the released widow kept their designation (%s)"
                      % got.get("lastMemberJob"))

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
        print("  136) a death leaves the company: FAIL")
        return 1
    print("  136) a death leaves the company, the house re-elects, and a "
          "house emptied by death releases its last member with the "
          "ground: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
