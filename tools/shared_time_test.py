#!/usr/bin/env python3
"""Border 168: shared county time and native pacing stay distinct ([C53]).

Runs the shipped History, Controller decision-time reader, Controller host
callback and WorldGenesis boundary in the engine's Kahlua VM. Controls remove
each repair and must fail at the defect that motivated it.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua"
HISTORY = LUA / "shared/SAO_History.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
GENESIS = LUA / "shared/SAO_WorldGenesis.lua"
CHECK = ROOT / "tools/check.sh"
SUBSTRATE = ROOT / "SUBSTRATE.md"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")

PRELUDE = r'''
__md={} __hours=0 __flushes=0 __corpses=0 __integrationTicks={}
ModData={getOrCreate=function(k) __md[k]=__md[k] or {} return __md[k] end}
GameTime={getInstance=function() return {
 getWorldAgeHours=function() return __hours end,
 getMonth=function() return 6 end,
 getTimeOfDay=function() return __hours % 24 end
} end}
SandboxVars={SurvivorAwareness={DayZero=false},DayLength=1}
Events=setmetatable({}, {__index=function(t,k)
 local slot={Add=function(fn) __handlers=__handlers or {} __handlers[k]=fn end,
  Remove=function() end}
 rawset(t,k,slot) return slot
end})
getSpecificPlayer=function() return nil end
getTimestampMs=function() return 1 end
SAO={
 Log={EVERY=600,line=function() end,flush=function() __flushes=__flushes+1 end},
 Disposition={describe=function() return 'test' end},
 Standing={sameGroup=function() return false end,playerKey=function() return nil end},
 Perception={EARSHOT=30,beliefs={},forget=function() end,describe=function() return '' end},
 Body={active={},foreign={},get=function() return nil end,hasRepresentation=function() return false end},
 Identity={all=function() return __records or {} end},
 WorldSources={ownsActor=function(id)
  return __sourceOwned and __sourceOwned[tostring(id)]==true
 end},
 Voice={forget=function() end},
 Locomotion={cancel=function() end},
}
SAOJavaBridge={
 daysBehindAtStart=function() return 0 end,
 recordDayToday=function() return -100000 end,
 countyMonth=function() return 6 end,
 ensureCorpse=function() __corpses=__corpses+1 return 'DIED' end,
}
'''

PHASE = r'''
local s=ModData.getOrCreate('SurvivorAwareness_Standing')
s.yearsAsked=true s.yearsOwed=3 s.yearsRun=0 s.yearsTicks=137
__beforeReload=SAO.Controller.tick()
'''

CASES = r'''(function()
 local faults={}
 local function check(ok,why) if not ok then faults[#faults+1]=why end end
 local s=ModData.getOrCreate('SurvivorAwareness_Standing')
 check(__beforeReload==137,'initial historical decision time was wrong')
 s.yearsTicks=377
 check(SAO.Controller.tick()==377,'reload lost current historical decision time')
 s.yearsTicks=617
 check(SAO.Controller.tick()==617,'historical substep clock stayed stale')

 -- Midnight and DayLength are unit boundaries, not pacing inputs.
 check(SAO.History.ticksFromHours(24)==216000,'midnight tick is wrong')
 check(SAO.History.tickAtDayStart(1)==216000,'day start conversion is wrong')
 local before=SAO.History.tickAtDayStart(7)
 SandboxVars.SurvivorAwareness.DayZero=true SandboxVars.DayLength=8
 check(SAO.History.tickAtDayStart(7)==before,'settings changed county units')
 SandboxVars.SurvivorAwareness.DayZero=false SandboxVars.DayLength=30
 check(SAO.History.tickAtDayStart(7)==before,'DayLength changed county units')

 -- Host callbacks pace native animation and operational output even when the
 -- county clock skips by days on each callback.
 s.yearsRun=s.yearsOwed
 SAO.Controller.pendingCorpses={p={body={},atHostTick=0}}
 for i=1,119 do __hours=i*24 SAO.Controller.__testOnTick() end
 check(__corpses==0,'corpse grace followed county time')
 __hours=120*24 SAO.Controller.__testOnTick()
 check(__corpses==1,'corpse grace did not follow host callbacks')
 check(__flushes==1,'county skips accelerated operational flushing')
 for i=121,601 do __hours=i*24 SAO.Controller.__testOnTick() end
 check(__flushes==2,'operational flush did not follow host callbacks')

 -- If History is unavailable, only host callbacks advance the fallback;
 -- repeated decision reads do not manufacture time.
 local realTicks=SAO.History.ticks
 SAO.History.ticks=function() error('clock unavailable') end
 local held=SAO.Controller.tick()
 check(SAO.Controller.tick()==held,'fallback advanced on a decision read')
 SAO.Controller.__testOnTick()
 check(SAO.Controller.tick()==held+1,'host fallback did not advance once')
 SAO.History.ticks=realTicks

 __sourceOwned={p1=true}
 __records={p1={id='p1',x=4,y=5},p2={id='p2',x=6,y=7}}
 __integrationIds={}
 SAO.Integration={ensure=function() return true end,
  apply=function(id,agent,tick) __integrationTicks[#__integrationTicks+1]=tick
   __integrationIds[#__integrationIds+1]=id
   return {branch='test'} end}
 for _,day in ipairs({0,1,7}) do
  check(SAO.WorldGenesis.applyDay(day)==1,'world graph did not apply')
 end
 check(__integrationTicks[1]==0 and __integrationTicks[2]==216000
  and __integrationTicks[3]==1512000,'WorldGenesis passed a day as a tick')
 check(__integrationIds[1]=='p2' and __integrationIds[2]=='p2'
  and __integrationIds[3]=='p2','source-owned actor received world graph')
 check(__records.p1.worldGraph==nil and __records.p2.worldGraphDay==7,
  'world graph ownership result was not durable')
 if #faults>0 then return 'FAIL '..table.concat(faults,'; ') end
 return 'PASS'
end)()'''


def read(path):
    return path.read_text(encoding="utf-8")


def run(work, history, controller, genesis):
    controller = controller.replace(
        "return Ctl\n", "Ctl.__testOnTick = onTickInner\nreturn Ctl\n")
    if "Ctl.__testOnTick" not in controller:
        return "ERROR controller test seam did not land"
    chunks = []
    for name, body in (("prelude.lua", PRELUDE), ("history.lua", history),
                       ("controller.lua", controller), ("phase.lua", PHASE),
                       ("history_reload.lua", history), ("genesis.lua", genesis)):
        path = work / name
        path.write_text(body, encoding="utf-8")
        chunks.append(str(path))
    done = subprocess.run(
        [str(JDK / "java.exe"), "-cp", str(GAME / "projectzomboid.jar") + ";.",
         "LuaRun", *chunks, "--", CASES], cwd=work, capture_output=True,
        text=True, timeout=120)
    lines = [line for line in done.stdout.splitlines()
             if line.startswith(("VALUE ", "ERROR "))]
    return "\n".join(lines) or (done.stdout + done.stderr)[-1600:]


def main():
    for path in (HISTORY, CONTROLLER, GENESIS, CHECK, SUBSTRATE, RUNNER):
        if not path.is_file():
            print("FAULT: missing " + str(path))
            return 1
    history, controller, genesis = read(HISTORY), read(CONTROLLER), read(GENESIS)
    substrate = read(SUBSTRATE)
    seams = {
        "the gate runs this border": "tools/shared_time_test.py" in read(CHECK),
        "partial catch-up and reload remain gated":
            "tools/years_progress_test.py" in read(CHECK)
            and "partial-day reload" in read(ROOT / "tools/years_progress_test.py"),
        "decision reads refresh the county clock":
            "function Ctl.tick()\n    -- [C53]" in controller
            and "refreshCountyTick()\n    return tickCount" in controller,
        "native pacing has its own host counter":
            "hostTickCount = hostTickCount + 1" in controller
            and "Ctl.settleCorpses(hostTickCount)" in controller,
        "WorldGenesis converts at its boundary":
            "SAO.History.tickAtDayStart(day)" in genesis
            and "id, agent, tick, record.x, record.y" in genesis,
        "WorldGenesis respects source transaction ownership":
            "and not sourceOwnsActor(id) then" in genesis
            and "SAO.WorldSources.ownsActor(id) == true" in genesis,
        "the durable and runtime axes are inventoried":
            all(term in substrate for term in (
                "County hours", "Elapsed county day", "County tick",
                "Host callback", "Wall milliseconds", "Non-time legacy names",
                "lastSeenAt", "lastAdvancedDay", "nextDormantMoveAt",
                "atHostTick", "Identity.updatedAt")),
    }
    faults = [name for name, ok in seams.items() if not ok]
    if not (JDK / "javac.exe").is_file() or not (GAME / "projectzomboid.jar").is_file():
        print("SKIPPED: installed game and JDK required for shared-time VM proof")
        for name, ok in seams.items():
            print(("yes  " if ok else "NO   ") + name)
        return 1 if faults else 0

    with tempfile.TemporaryDirectory(prefix="sao-shared-time-") as tmp:
        work = Path(tmp)
        shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
        built = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"),
             "-d", str(work), str(RUNNER)], capture_output=True, text=True,
            timeout=120)
        if built.returncode:
            print("FAULT: VM runner build\n" + built.stderr)
            return 1
        result = run(work, history, controller, genesis)
        print("production: " + result)
        if result != "VALUE PASS":
            faults.append("production shared-time contract")
        controls = (
            ("stale decision cache", "controller", "    refreshCountyTick()\n    return tickCount",
             "    return tickCount", "historical substep clock stayed stale"),
            ("day handed to tick consumer", "genesis", "id, agent, tick, record.x, record.y",
             "id, agent, day, record.x, record.y", "WorldGenesis passed a day as a tick"),
            ("source transaction bypassed", "genesis", "and not sourceOwnsActor(id) then",
             "then", "source-owned actor received world graph"),
            ("county time paces corpse animation", "controller",
             "Ctl.settleCorpses(hostTickCount)", "Ctl.settleCorpses(tickCount)",
             "corpse grace followed county time"),
        )
        for label, target, old, new, expected in controls:
            bodies = {"history": history, "controller": controller, "genesis": genesis}
            if bodies[target].count(old) != 1:
                faults.append("control seam " + label)
                continue
            bodies[target] = bodies[target].replace(old, new, 1)
            result = run(work, bodies["history"], bodies["controller"], bodies["genesis"])
            rejected = result.startswith("VALUE FAIL ") and expected in result
            print("CONTROL " + label + ": " + ("REJECTED " if rejected else "SURVIVED ") + result)
            if not rejected:
                faults.append(label)

    for name, ok in seams.items():
        print(("yes  " if ok else "NO   ") + name)
    print("  168) " + ("FAULT " + ", ".join(dict.fromkeys(faults)) if faults else
          "PASS -- current decision time, boundary conversion, reload and host pacing"))
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
