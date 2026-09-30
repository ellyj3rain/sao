#!/usr/bin/env python3
"""Cached inspection and exact execution observations in installed Kahlua.

The bodies, inventory receivers and durable process records are controlled
fixtures. Production observation, voice, locomotion and native-panel Lua run in
the installed VM. This is not a loaded-game rendering or inventory proof.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua/client"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")

PRELUDE = r'''
SAO = { Log={line=function() end}, Body={active={}}, Controller={agents={}},
    Rand={int=function() return 0 end}, Identity={get=function() error("identity mutation/read owner called") end},
    Organization={processes={},processOrder={}} }
local all = { a={id="a"}, b={id="b"} }
__records = all
__sources={schema=6,reservations={},results={},resultByActor={}}
SAO.WorldSources={pendingActionFor=function(id) all[id].worldSourceReservation=nil;return nil end}
ModData={get=function(key) if key=="SurvivorAwareness_WorldSources" then return __sources end;assert(key=="SurvivorAwareness_Records");return {records=all} end,
    getOrCreate=function() error("created records during inspection") end}
__ms,__hours,__reads,__say=1000,2,0,{}
function getTimestampMs() return __ms end
function getGameTime() return {getWorldAgeHours=function() return __hours end} end
SAO.History={countyHours=function() return __hours+24 end}
Events={OnTick={Add=function(fn) __tick=fn end},OnTickEvenPaused={Add=function(fn) __paused=fn end},
    OnKeyPressed={Add=function(fn) end}}
function require(name) end
function instanceof(item, name) return item.bag==true and name=="InventoryContainer" end
local function list(values) return {size=function() return #values end,get=function(_,i)return values[i+1] end} end
local food={getFullType=function()return "Base.CannedBeans" end,getName=function()return "Beans" end,getID=function()return 17 end}
local inner={getItems=function()return list({food}) end}
local bag={bag=true,getFullType=function()return "Base.Bag" end,getName=function()return "Bag" end,getID=function()return 16 end,getInventory=function()return inner end}
local inventory={getItems=function()return list({bag}) end}
__body={getCurrentSquare=function()return {} end,getInventory=function()return inventory end,
    getHealth=function()return 77 end,getX=function()return 1 end,getY=function()return 2 end,
    Say=function(_,line)if __sayFail then error("native Say refused") end;__say[#__say+1]=line end}
__bodyHealth=23.75
__body.getBodyDamage=function()
    if __healthThrows then error("body health unavailable") end
    if __noBodyDamage then return nil end
    return {getOverallBodyHealth=function()return __bodyHealth end}
end
__records.a.lastLivingHealth=0.91
SAO.Body.active.a=__body
SAO.Body.get=function(id)return SAO.Body.active[id] end
SAO.Controller.agents.a={state="FLEE",pressure={answer="escape",detail="current private threat",at=8}}
SAO.Controller.tick=function()return 8 end
__verdict="Working"
SAOJavaBridge={getNeeds=function()__reads=__reads+1;if __needsFail then error("needs unavailable") end;return "h=0.3|t=0.2|f=0.1|e=0.8|n=0.0" end,
 moveTo=function()return "MOVE_STARTED" end,moveToPaced=function()return "MOVE_STARTED" end,
 tickMove=function()return __verdict end,cancelMove=function()end}
SandboxVars={SurvivorAwareness={Voice=true}}
ISCollapsableWindow={derive=function(self,name)local d={};setmetatable(d,{__index=self});return d end,
 new=function(self,x,y,w,h)local o={javaObject={native=true},visible=true};setmetatable(o,{__index=self});return o end,
 initialise=function()end,addToUIManager=function()end,removeFromUIManager=function()end,
 isVisible=function(self)return self.visible end,setVisible=function(self,v)self.visible=v end,render=function()end}
function getCore()return {getScreenWidth=function()return 1000 end,getScreenHeight=function()return 700 end} end
'''
PROBE = r'''(function()
local checks = 0
local function check(name, value) if not value then error("OBSERVATION_CHECK:"..name) end; checks = checks + 1 end
local function find(rows, label)
 for _,s in ipairs(rows or {})do for _,r in ipairs(s.rows or {})do if r.label==label then return r.value end end end
end
local function section(rows, id)
 for _,s in ipairs(rows or {})do if s.id==id then return s end end
end
local O=SAO.Observation
__tick();__paused();check("disabled-inert",__reads==0)
O.enable();check("unknown-selection",not O.select("missing") and __records.missing==nil)
O.select("a")
local privatePlan={objective='retain usable food',status='blocked',resourceCategory='food',
 demand={pressure=.35,ownedReady=0,ownedRaw=0,ownedWater=0},
 sequence={{verb='inspect',owner='SAONeeds',status='available'}},
 rationale='inspect remembered ground',uncertainty='access and helper assent remain unknown',
 capacity={fatigue=.25,skills={Cooking=0},commitments={{id='accepted'}}},contacts={'b'},
 labor={slack={status='unknown'},groupValues={status='unknown'}}}
SAO.ProceduralPlanning={snapshot=function()return {purposes={privatePlan},spatialFacts=0,practiceDomains=0} end}
__records.a.worldSourceReservation="missing-source"
__sources.resultByActor.a="r1";__sources.results.r1={actorId="a",reservationId="r1",status="failed",detail="source unavailable"}
SAO.Organization.processOrder={"p"}
SAO.Organization.processes.p={id="p",kind="delivery",status="open",participants={a={
 receptions={['1']={at=1.1,channel="direct",fromId="b"}},
 responses={['1']={response="accept",formedAt=1.2,delivered=false}}}},
 commitments={c={actorId="a",status="executing",work={phase="route",sourceReceipts={}}}},
 revision=1,procedures={['1']={status='active',order={'acquire','deliver'},steps={
  acquire={verb='acquire',status='completed'},deliver={verb='deliver',status='available'}}}},
 privatePlans={a={['1']={intendedStepId='deliver',beliefs={
  acquire={verb='acquire',status='completed'},deliver={verb='deliver',status='planned'}}}}}}
__tick();local first=O.snapshot()
check("county-clock",first.worldHours==__hours+24)
check("physical-needs",find(first.people.a.sections,"Hunger")=="0.3000")
check("body-health",find(first.people.a.sections,"Health (%)")=="23.75")
check("nested-carried-items",find(first.people.a.sections,"Base.CannedBeans")=="Beans [id 17]")
check("pressure-record",find(first.people.a.sections,"answer")=="escape")
check("resource-plan-visible",find(first.people.a.sections,"Resource goal")=="food / pressure 35% / usable food 0 / raw food 0 / water vessels 0"
 and find(first.people.a.sections,"Work sequence")=="inspect (available)"
 and find(first.people.a.sections,"Potential helpers")=="1 personally known; capacity and assent unconfirmed")
check("resource-unknowns-visible",find(first.people.a.sections,"Uncertainty")==privatePlan.uncertainty
 and string.find(find(first.people.a.sections,"Labor assessment"),'slack: unknown',1,true)~=nil)
check("planning-projection-read-only",privatePlan.status=='blocked' and privatePlan.demand.pressure==.35
 and privatePlan.sequence[1].status=='available')
check("autonomous-not-assigned",find(first.people.a.sections,"Goal source")==nil)
check("read-only-source-join",__records.a.worldSourceReservation=="missing-source"
 and find(first.people.a.sections,"Source action")=="Recorded pointer has no matching actor reservation")
check("source-terminal-receipt",find(first.people.a.sections,"Latest result.status")=="failed")
check("stage-distinction",find(first.people.a.sections,"Formed response 1")=="accept at hour 1.2"
  and find(first.people.a.sections,"Response delivery 1")=="Not recorded as delivered"
  and find(first.people.a.sections,"Commitment c")=="executing")
check("procedure-perspectives",find(first.people.a.sections,"Enacted procedure")=="active"
 and find(first.people.a.sections,"Actual: deliver")=="available"
 and find(first.people.a.sections,"Personal next step")=="deliver"
 and find(first.people.a.sections,"Belief: deliver")=="planned")
__ms=1999;__paused();check("shared-throttle",__reads==1 and O.snapshot().sequence==1)
__ms=2000;__paused();check("paused-refresh",__reads==2 and O.snapshot().sequence==2)
__needsFail=true;__ms=3000;__tick();check("failure-time",O.snapshot().status=="failed" and O.snapshot().capturedAtUnixMs==2000 and O.snapshot().sequence==2)
__needsFail=false
SAO.Voice.onTransition("a","FLEE",8)
check("speech-exact",#__say==1)
__sayFail=true;SAO.Voice.onTransition("a","FLEE",9);__sayFail=false
SAO.Locomotion.order("a",__body,20,30,0,false)
__verdict="Succeeded";SAO.Locomotion.tick("a");SAO.Locomotion.cancel("a")
__ms=4000;__tick();local events=O.snapshot().people.a.events
local emitted, exact = 0, false
for _,event in ipairs(events) do if event.stage=="emitted" then emitted=emitted+1;exact=event.summary==__say[1] end end
check("speech-after-success",emitted==1 and exact)
check("arrival-survives-cleanup",events[#events].stage=="arrived")
SAO.Locomotion.order("a",__body,10,20,0,false);SAO.Locomotion.cancel("a")
__ms=5000;__tick();events=O.snapshot().people.a.events
check("explicit-cancel",events[#events].stage=="cancelled")
check("panel-validates",not O.panel("unknown","a",true) and not O.panel("person-inspection","missing",true))
check("native-panel-show",O.panel("person-inspection","a",true) and O.nativePanel().native==true and SAO.Inspect.selectedId=="a")
local rows=SAOInspectWindow.instance:build();check("cached-panel",#rows>4 and __reads==5)
check("native-panel-hide",O.panel("person-inspection","a",false) and O.nativePanel()==nil)
O.select("b");__ms=6000;__paused();local dormant=O.snapshot().people.b
check("dormant-unavailable",section(dormant.sections,"needs").status=="unavailable"
 and section(dormant.sections,"inventory").status=="unavailable")
for n=1,90 do O.record("a","Voice","emitted","line "..n) end
__ms=7000;__tick();check("bounded-history",#O.snapshot().people.a.events==24 and O.snapshot().omittedEvents>0)
local same=O.snapshot();O.record("a","Voice","emitted","after sample")
check("immutable-snapshot",same.people.a.events[24].summary=="line 90")
local function healthSample()
 __ms=__ms+1000;__tick()
 local snapshot=O.snapshot()
 check("health-failure-is-local",snapshot.status=="available"
  and find(snapshot.people.a.sections,"Hunger")=="0.3000")
 return find(snapshot.people.a.sections,"Health (%)")
end
__bodyHealth=0;check("zero-body-health",healthSample()=="0.00")
__bodyHealth=100;check("full-body-health",healthSample()=="100.00")
__bodyHealth=0/0;check("nan-body-health",healthSample()=="unavailable")
__bodyHealth=math.huge;check("infinite-body-health",healthSample()=="unavailable")
__bodyHealth=-1;check("negative-body-health",healthSample()=="unavailable")
__bodyHealth=101;check("overscale-body-health",healthSample()=="unavailable")
__bodyHealth=nil;check("missing-body-health",healthSample()=="unavailable")
__noBodyDamage=true;check("missing-body-damage",healthSample()=="unavailable")
__noBodyDamage=false;__healthThrows=true;check("throwing-body-damage",healthSample()=="unavailable")
__healthThrows=false
privatePlan.resourceOutcome={category='food',target=4,unit='usable-food-item',deadlineAfterHours=6}
privatePlan.outcomeProgress={held=2,coverage='all-native-private-carried-items'}
__ms=__ms+1000;__tick();local assigned=O.snapshot().people.a.sections
check("assigned-outcome-provenance",find(assigned,"Goal source")=="Assigned for this trial; the survivor chooses the means")
check("assigned-food-stock",find(assigned,"Supplies secured")=="2 / 4 food items"
 and find(assigned,"Goal time limit")=="6 game hours from assignment")
check("assigned-read-only",privatePlan.resourceOutcome.target==4
 and privatePlan.outcomeProgress.held==2 and privatePlan.status=='blocked')
privatePlan.resourceOutcome={category='water',target=3.5,unit='native-clean-fluid-amount'}
privatePlan.outcomeProgress={held=1.25,coverage='first-128-native-private-carried-items-lower-bound'}
__ms=__ms+1000;__tick();assigned=O.snapshot().people.a.sections
check("assigned-water-lower-bound",find(assigned,"Supplies secured")=="At least 1.25 / 3.5 water units"
 and find(assigned,"Goal time limit")==nil)
privatePlan.outcomeProgress=nil
__ms=__ms+1000;__tick();assigned=O.snapshot().people.a.sections
check("unchecked-stock-not-zero",find(assigned,"Supplies secured")=="Not checked / 3.5 water units")
return "OBSERVATION_PASS " .. checks .. " checks"
end)()'''

NATIVE_PROBE = r'''
SAO.Body.active.a=__nativeBody;SAOJavaBridge=__nativeBridge
local O=SAO.Observation;O.enable();O.select("a")
local function health()
 __ms=__ms+1000;__tick()
 local snap=O.snapshot()
 assert(snap.status=="available","NATIVE_HEALTH_CHECK:snapshot available")
 for _,s in ipairs(snap.people.a.sections) do
  for _,r in ipairs(s.rows) do if r.label=="Health (%)" then return r.value end end
 end
end
assert(__nativeBody:getHealth()==1 and __nativeBody:getBodyDamage():getOverallBodyHealth()==37.5,
 "NATIVE_HEALTH_CHECK:unequal native receivers")
assert(health()=="37.50","NATIVE_HEALTH_CHECK:body percent")
__nativeBody:getBodyDamage():setOverallBodyHealth(0)
assert(health()=="0.00","NATIVE_HEALTH_CHECK:zero body percent")
__nativeBody:getBodyDamage():setOverallBodyHealth(100)
assert(health()=="100.00","NATIVE_HEALTH_CHECK:full body percent")
NATIVE_HEALTH_RESULT="NATIVE_HEALTH_PASS 4 checks"
'''

def main():
    if not (JDK / "javac.exe").is_file() or not (GAME / "projectzomboid.jar").is_file():
        print("SKIPPED: installed engine or JDK unavailable")
        return 0
    names = ["SAO_Observation.lua", "SAO_Locomotion.lua", "SAO_Voice.lua", "SAO_Inspect.lua"]
    sources = {name: (LUA / name).read_text(encoding="utf-8") for name in names}
    controls = [
        ("assigned-outcome-provenance", "SAO_Observation.lua", 'Assigned for this trial; the survivor chooses the means', 'The survivor autonomously chose this goal'),
        ("assigned-water-lower-bound", "SAO_Observation.lua", 'stock = "At least " .. stock', 'stock = stock'),
        ("resource-plan-visible", "SAO_Observation.lua", 'row(s, "Work sequence", #sequence > 0', 'row(s, "Hidden sequence", #sequence > 0'),
        ("body-health", "SAO_Observation.lua", "damage:getOverallBodyHealth()", "body:getHealth()"),
        ("body-health", "SAO_Observation.lua", "string.format(\"%.2f\", health)", "string.format(\"%.2f\", health / 100)"),
        ("zero-body-health", "SAO_Observation.lua", "health >= 0", "health > 0"),
        ("infinite-body-health", "SAO_Observation.lua", "ok and finite(health) and health >= 0 and health <= 100", "ok and type(health) == \"number\" and health == health and health >= 0"),
        ("negative-body-health", "SAO_Observation.lua", " and health >= 0", ""),
        ("overscale-body-health", "SAO_Observation.lua", " and health <= 100", ""),
        ("county-clock", "SAO_Observation.lua", "SAO.History.countyHours()", "getGameTime():getWorldAgeHours()"),
        ("read-only-source-join", "SAO_Observation.lua", "local reservation = pointer and store.reservations and store.reservations[tostring(pointer)]", "local reservation = SAO.WorldSources.pendingActionFor(id)"),
        ("shared-throttle", "SAO_Observation.lua", "if nowMs < nextSample then return cached end", "if false then return cached end"),
        ("paused-refresh", "SAO_Observation.lua", "Events.OnTickEvenPaused.Add(refresh)", "Events.OnTickEvenPaused.Add(function() end)"),
        ("failure-time", "SAO_Observation.lua", 'cached.status = "failed"; cached.message = text(result, 1024)', 'cached.capturedAtUnixMs = nowMs; cached.status = "failed"; cached.message = text(result, 1024)'),
        ("arrival-survives-cleanup", "SAO_Locomotion.lua", 'if not job.done then observed(id, "cancelled", job, "Route owner cancelled") end', 'observed(id, "cancelled", job, "Route owner cancelled")'),
        ("speech-after-success", "SAO_Voice.lua", 'if SAO.Observation then\n            pcall(SAO.Observation.record, id, "Voice", "emitted", line)\n        end', ''),
        ("dormant-unavailable", "SAO_Observation.lua", 'if not body then s.status = "unavailable"; s.message = "No loaded body; native needs were not sampled"; return s end', 'if not body then return s end'),
        ("procedure-perspectives", "SAO_Observation.lua", 'row(s, "Personal next step", plan.intendedStepId or "No next step")', 'row(s, "Personal next step", "No next step")'),
    ]
    with tempfile.TemporaryDirectory(prefix="sao-observation-") as folder:
        temp = Path(folder)
        version = temp / "SAOVersion.java"
        version.write_text("package com.sao; public final class SAOVersion { public static final String VALUE = "
            + json.dumps((ROOT / "VERSION").read_text(encoding="utf-8-sig").strip()) + "; }\n", encoding="utf-8")
        classpath = os.pathsep.join(map(str, (GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar")))
        built = subprocess.run([str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", classpath, "-d", str(temp),
            *map(str, sorted((ROOT / "java/src").rglob("*.java"))), str(version),
            *[str(ROOT / "tools/luacheck" / name) for name in
              ("LuaRun.java", "MovementCrossingProbe.java", "ObservationHealthProbe.java")]],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError(built.stdout + built.stderr)
        (temp / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (temp / "probe.lua").write_text("__result = " + PROBE, encoding="utf-8")
        def run(changes):
            for name, source in changes.items():
                (temp / name).write_text(source, encoding="utf-8")
            result = subprocess.run([str(JDK / "java.exe"), "-cp", str(temp) + ";" + str(GAME / "projectzomboid.jar"), "LuaRun", str(temp / "prelude.lua"), *[str(temp / n) for n in names], str(temp / "probe.lua"), "--", "__result"], cwd=GAME, capture_output=True, text=True, timeout=45)
            return result.returncode, result.stdout + result.stderr
        code, output = run(sources)
        print(output.strip())
        if code or "OBSERVATION_PASS" not in output:
            return 1
        for expected, name, old, new in controls:
            if sources[name].count(old) != 1:
                raise AssertionError("control seam changed: " + expected)
            mutated = dict(sources); mutated[name] = sources[name].replace(old, new)
            code, output = run(mutated)
            if code == 0 or "OBSERVATION_CHECK:" + expected not in output:
                raise AssertionError(expected + " did not flip its named verdict: " + output)
            print("CONTROL_PASS " + expected)
        shutil.copy2(GAME / "stdlib.lua", temp / "stdlib.lua")
        (temp / "native-health.lua").write_text(NATIVE_PROBE, encoding="utf-8")
        observation = sources["SAO_Observation.lua"]
        for label, source, expected in [
            ("production", observation, None),
            ("character-health", observation.replace("damage:getOverallBodyHealth()", "body:getHealth()"), "body percent"),
            ("wrong-scale", observation.replace('string.format("%.2f", health)', 'string.format("%.2f", health / 100)'), "body percent"),
            ("zero-unavailable", observation.replace("health >= 0", "health > 0"), "zero body percent"),
        ]:
            (temp / "SAO_Observation.lua").write_text(source, encoding="utf-8")
            result = subprocess.run([str(JDK / "java.exe"), "-Duser.home=" + str(temp),
                "-Djava.awt.headless=true", "--enable-native-access=ALL-UNNAMED", "-cp",
                str(temp) + os.pathsep + classpath, "ObservationHealthProbe", str(temp / "prelude.lua"),
                str(temp / "SAO_Observation.lua"), str(temp / "native-health.lua")], cwd=temp,
                capture_output=True, text=True, timeout=60)
            output = result.stdout + result.stderr
            if expected is None:
                assert result.returncode == 0 and "NATIVE_HEALTH_PASS" in output, output
                print("NATIVE_HEALTH_PASS 4 checks")
            else:
                assert result.returncode != 0 and "NATIVE_HEALTH_CHECK:" + expected in output, output
                print("NATIVE_CONTROL_PASS " + label)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
