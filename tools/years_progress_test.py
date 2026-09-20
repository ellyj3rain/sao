#!/usr/bin/env python3
"""Run the production catch-up scheduler in the installed game's Kahlua VM.

The population module and History load whole. Unrelated dormant subsystems
are replaced at their local boundaries by clock-observing counters; the
production OnTick, slice loop, clock, daily gate and telemetry remain intact.
This verifies scheduling, never society outcomes or live gameplay.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HERE.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
POP = LUA / "client" / "SAO_Population.lua"
HISTORY = LUA / "shared" / "SAO_History.lua"
GAME = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
RUNNER = HERE / "luacheck" / "LuaRun.java"

PRELUDE = r'''
__test = {steps=0, ms=0, opened=0, closed=0, daily=0, faults=0,
          calls={}, night=false, day=false, maxSlice=0, genesisReady=true}
__md = {}
ModData = {getOrCreate=function(key)
    __md[key] = __md[key] or {} return __md[key]
end}
__hours = 0
GameTime = {getInstance=function() return {
    getWorldAgeHours=function() return __hours end,
    getTimeOfDay=function() return 3 end,
    getMonth=function() return 6 end
} end}
SAOJavaBridge = {daysBehindAtStart=function() return __owed end}
SandboxVars = {TimeSinceApo=99, DayLength=4, SurvivorAwareness={
    Enable=true, FastSimulation=true, PopulationGoverned=true, Population=1}}
Events = setmetatable({OnTick={Add=function(fn) __tick=fn end, Remove=function() end}},
    {__index=function() return {Add=function() end, Remove=function() end} end})
getSpecificPlayer = function() return nil end
getTimestampMs = function()
    if __test.noTimer then error("timer unavailable") end
    __test.ms=__test.ms+1 return __test.ms
end
SAO = {
    Log={line=function(tag,msg)
        if string.find(msg,"fault",1,true) then __test.faults=__test.faults+1 end
    end, tally=function() end},
    Identity={all=function() return {} end, livingCount=function() return 0 end},
    Standing={driftStandings=function() __test.calls.drift=(__test.calls.drift or 0)+1 end},
    Rand={int=function() return 0 end},
    Body={active={}, get=function() return nil end,
          hasRepresentation=function() return false end, recover=function() return true end},
    Telemetry={conditions=function() return {} end,
        run=function(kind)
            if kind=="opened" then __test.opened=__test.opened+1 end
            if kind=="closed" then __test.closed=__test.closed+1 end
        end, county=function() end},
    PathogenEvents={simulateDay=function(day)
        if __test.lastDay and day<=__test.lastDay then __test.faults=__test.faults+1 end
        __test.lastDay=day __test.daily=__test.daily+1
    end},
    WorldGenesis={applyDay=function() end},
    Trajectory={shouldFastSimulate=function() error("retired model invoked") end,
                extrapolate=function() error("fabricated history invoked") end}
}
function __step(name)
    __test.calls[name]=(__test.calls[name] or 0)+1
    if name~="life" then return end
    local ticks=SAO.History.ticks()
    local previous=__test.lastTicks or __test.startTicks or 0
    if ticks-previous~=240 then __test.faults=__test.faults+1 end
    if math.abs(SAO.History.countyHours()*9000-ticks)>0.01 then
        __test.faults=__test.faults+1
    end
    __test.lastTicks=ticks
    __test.steps=__test.steps+1
    local face=SAO.History.countyTimeOfDay()
    if face<6 then __test.night=true end
    if face>=12 and face<18 then __test.day=true end
end
function __drive(limit)
    local s=ModData.getOrCreate("SurvivorAwareness_Standing")
    for i=1,limit do
        local before=__test.steps
        __tick()
        local took=__test.steps-before
        if took>__test.maxSlice then __test.maxSlice=took end
        if (s.yearsRun or 0)>=__owed then break end
    end
end
'''

# Local substitutions are inserted after every production helper has been
# defined. They observe the scheduler without copying its implementation.
COUNTERS = r'''
ensurePopulation=function(conf)
    local s=ModData.getOrCreate("SurvivorAwareness_Standing")
    if __test.genesisHours==nil then __test.genesisHours=SAO.History.countyHours() end
    s.countySettled=__test.genesisReady
end
dormantLife=function() __step("life") end
dormantAttrition=function() __step("attrition") end
dormantSettle=function() __step("settle") end
dormantProvision=function() __step("provision") end
dormantEncounters=function() __step("encounters") end
lookAtSomeGround=function() __test.ground=(__test.ground or 0)+1 end
inhabitKnox=function() end
bootDigest=function() end
'''

PROBE = r'''(function()
    __drive(__owed*1000+10)
    local s=ModData.getOrCreate("SurvivorAwareness_Standing")
    local expected=(__owed-(__test.startDay or 0))*900
    if __test.genesisHours~=(__test.startDay or 0)*24 then return "FAIL genesis used future time" end
    if __test.steps~=expected then return "FAIL steps="..__test.steps.." expected="..expected end
    if s.yearsRun~=__owed then return "FAIL incomplete="..tostring(s.yearsRun) end
    if s.yearsTicks~=__owed*216000 then return "FAIL ticks="..tostring(s.yearsTicks) end
    if __test.faults~=0 then return "FAIL clock or callback faults="..__test.faults end
    if __test.opened~=1 or __test.closed~=1 then return "FAIL run boundaries" end
    if not __test.night or not __test.day then return "FAIL day and night not observed" end
    for _,name in ipairs({"life","attrition","drift","settle","provision","encounters"}) do
        if __test.calls[name]~=expected then return "FAIL cadence="..name end
    end
    local max=__test.noTimer and 1 or 60
    if __test.maxSlice>max then return "FAIL unbounded slice="..__test.maxSlice end
    if SAO.History.countyHours()~=__owed*24 then return "FAIL clock handoff" end
    __hours=2
    if SAO.History.countyHours()~=__owed*24+2 then return "FAIL live clock" end
    if __test.daily~=(__owed-(__test.startDay or 0)+1) then return "FAIL daily="..__test.daily end
    if __test.ground~=(__owed-(__test.startDay or 0)) then return "FAIL ground cadence" end
    return "PASS days="..__owed.." steps="..__test.steps.." maxSlice="..__test.maxSlice
end)()'''

# One genuine record, selected by the production life table and hash to die
# on day one (and survive day zero). The real dormant attrition and Neuro
# integrate its septic wound. Random ambient injury is held off so this
# probe isolates elapsed health and old age, rather than another cause.
RECORD_MODULES = (
    "shared/SAO_Hash.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Neuro.lua", "client/SAO_Age.lua",
)
RECORD_SETUP = r'''
SAO.Claims={isHeld=function() return false end}
SAO.Lessons={has=function() return false end}
SAO.Standing.groupOf=function() return nil end
SAO.Rand.int=function(n) return n-1 end
for i=1,200000 do
    local id="elapsed-elder-"..i
    local risk=SAO.History.oldAgeRiskPerDay(SAO.History.ageOf(id))
    local zero=(SAO.Hash.of(id,"old-age:0")%1000000)/1000000
    local one=(SAO.Hash.of(id,"old-age:1")%1000000)/1000000
    if zero>=risk and one<risk then
        __person=SAO.Identity.ensure(id,"Elder","Test",0,0,0)
        break
    end
end
assert(__person,"could not find the deterministic old-age fixture")
__person.woundInfected=true
__person.neuroinflammation=0
SAO.Neuro.observe(__person, 0, "fixture-sepsis")
__test.ageCalls=0
local dailyRoll=SAO.Age.dailyRoll
SAO.Age.dailyRoll=function(...)
    __test.ageCalls=__test.ageCalls+1
    return dailyRoll(...)
end
__test.snapshots={}
SAO.Telemetry.county=function()
    __test.snapshots[math.floor(SAO.History.countyHours()/24)]=SAO.Identity.livingCount()
end
'''
RECORD_PROBE = r'''(function()
    __tick()
    if __person.dead then return "FAIL death before elapsed day" end
    if __test.ageCalls~=0 then return "FAIL initial partial day aged" end
    local initial=SAO.Neuro.stateOf(__person)
    if not initial or initial.atHours~=0 or initial.burden~=0 then
        return "FAIL initial partial day neuro debit"
    end
    if __test.snapshots[0]~=1 then return "FAIL initial living snapshot" end
    __drive(100)
    if __test.faults~=0 then return "FAIL real record callback faults="..__test.faults end
    if not __person.dead or __person.deathCause~="old age" then return "FAIL real age roll did not kill" end
    if __person.diedAtHours~=24 then return "FAIL durable death time="..tostring(__person.diedAtHours) end
    local state=SAO.Neuro.stateOf(__person)
    local expectedBurden,expectedLoad=SAO.Neuro.project(
        0,{wound=true,clearance=1},0,24,true)
    if not state or state.atHours~=24
        or math.abs(state.burden-expectedBurden)>0.0000001
        or math.abs(SAO.Neuro.loadOf(__person)-expectedLoad)>0.0000001 then
        return "FAIL elapsed brain history="..tostring(state and state.burden)
    end
    if __test.ageCalls~=1 then return "FAIL daily age calls="..__test.ageCalls end
    if __test.snapshots[1]~=0 then return "FAIL daily digest preceded real death" end
    return "PASS real person died at hour24, causal brain history advanced24h, digest sees death"
end)()'''


def instrument(source, counters=COUNTERS):
    anchor = "local function populationTick()"
    if source.count(anchor) != 1:
        raise ValueError("production populationTick anchor is missing or ambiguous")
    return source.replace(anchor, counters + "\n" + anchor)


def run_case(work, source, history, *, days=90, reload=False, start=0,
             no_timer=False, mutation=None, before="", probe=PROBE,
             modules=(), counters=COUNTERS):
    init = PRELUDE + "\n__owed=%d\n" % days
    if start:
        init += ("local s=ModData.getOrCreate('SurvivorAwareness_Standing') "
                 "s.yearsAsked=true s.yearsOwed=__owed s.yearsRun=%d "
                 "__test.startDay=%d __test.startTicks=%d\n" %
                 (start, start, start*216000))
    if no_timer:
        init += "__test.noTimer=true\n"
    pre = work / "prelude.lua"
    pre.write_text(init, encoding="utf-8")
    hist = work / "history.lua"
    hist.write_text(history, encoding="utf-8")
    pop = work / "population.lua"
    if mutation:
        old, new = mutation
        if source.count(old) != 1:
            raise ValueError("control did not find exactly one motivating seam")
        source = source.replace(old, new)
    pop.write_text(instrument(source, counters), encoding="utf-8")
    chunks = [str(pre), str(hist), *[str(LUA / m) for m in modules], str(pop)]
    if before:
        first = work / "before.lua"
        first.write_text(before, encoding="utf-8")
        chunks.append(str(first))
    if reload:
        phase = work / "partial.lua"
        phase.write_text("__drive(137)\nassert(__test.steps % 900 ~= 0, 'reload must interrupt a day')\n", encoding="utf-8")
        chunks += [str(phase), str(hist), str(pop)]
    done = subprocess.run(
        [str(JDK / "java.exe"), "-cp", str(GAME / "projectzomboid.jar") + ";.",
         "LuaRun", *chunks, "--", probe], cwd=work,
        capture_output=True, text=True, timeout=120)
    values = [line[6:] for line in done.stdout.splitlines() if line.startswith("VALUE ")]
    return values[-1] if values else "ERROR " + (done.stdout + done.stderr)[-1400:]


def main():
    if not POP.exists() or not HISTORY.exists():
        print("FAULT: production Population or History missing")
        return 1
    if not (JDK / "javac.exe").exists() or not (GAME / "projectzomboid.jar").exists():
        print("SKIPPED: installed game and JDK required for scheduler VM proof")
        return 0
    source, history = POP.read_text(encoding="utf-8"), HISTORY.read_text(encoding="utf-8")
    faults = []
    with tempfile.TemporaryDirectory(prefix="sao-years-progress-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
        build = subprocess.run([str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"),
                                "-d", str(work), str(RUNNER)], capture_output=True, text=True, timeout=120)
        if build.returncode:
            print("FAULT: VM runner build\n" + build.stderr)
            return 1
        for label, options in (
            ("90 calendar days", {}),
            ("365 calendar days", {"days":365}),
            ("partial-day reload", {"reload":True}),
            ("legacy completed-day migration", {"start":61}),
            ("unavailable timer remains bounded", {"days":2,"no_timer":True}),
            ("genesis must complete first", {"days":2, "before":
                "__test.genesisReady=false __tick() __tick() "
                "assert(__test.steps==0, 'unfinished genesis advanced history') "
                "__test.genesisReady=true"}),
            ("unreadable clock retries without inventing history", {"days":2, "before":
                "__owed=-1 __tick() __tick() "
                "assert(__test.steps==0, 'unknown days became a live county') __owed=2"}),
        ):
            result = run_case(work, source, history, **options)
            print(label + ": " + result)
            if not result.startswith("PASS"):
                faults.append(label)
        record_options = dict(days=1, modules=RECORD_MODULES,
            counters=COUNTERS.replace('dormantAttrition=function() __step("attrition") end', ''),
            before=RECORD_SETUP, probe=RECORD_PROBE)
        result = run_case(work, source, history, **record_options)
        print("real person daily timing: " + result)
        if not result.startswith("PASS"):
            faults.append("real person daily timing")
        age_start = source.index("    if previousDay and day > previousDay then")
        digest_start = source.index("    pcall(function() SAO.Telemetry.county() end)", age_start)
        age_block = source[age_start:digest_start]
        digest_line = "    pcall(function() SAO.Telemetry.county() end)\n"
        for label, mutation in (
            ("initial partial day cannot age", ("if previousDay and day > previousDay then", "if true then")),
            ("digest cannot precede age death", (age_block + digest_line, digest_line + age_block)),
        ):
            result = run_case(work, source, history, mutation=mutation, **record_options)
            killed = result.startswith("FAIL")
            print("control " + label + ": " + ("REJECTED " if killed else "SURVIVED ") + result)
            if not killed:
                faults.append(label)
        for label, mutation in (
            ("old callback gate stalls catch-up", ("if not pending\n        and tickCounter", "if tickCounter")),
            ("daily jumps cannot replace live cadence", ("ticks + TICK_INTERVAL", "ticks + ticksADay")),
            ("completed progress cannot be discarded", ("s.yearsTicks = ticks", "s.yearsTicks = 0")),
        ):
            result = run_case(work, source, history, days=2, mutation=mutation)
            killed = result.startswith("FAIL")
            print("control " + label + ": " + ("REJECTED " if killed else "SURVIVED ") + result)
            if not killed:
                faults.append(label)
        frozen = history.replace("return elapsed % 24.0", "return 12.0")
        if frozen == history:
            faults.append("noon control did not land")
        else:
            result = run_case(work, source, frozen, days=2)
            print("control frozen noon: " + result)
            if not result.startswith("FAIL"):
                faults.append("frozen noon")
    print("  160) " + ("FAULT " + ", ".join(faults) if faults else "PASS") +
          " -- causal elapsed-history scheduler")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
