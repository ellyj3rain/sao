#!/usr/bin/env python3
"""Border 209: private situations naturally form executable cooperation."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORG = LUA / "shared/SAO_Organization.lua"
COORD = LUA / "shared/SAO_Coordination.lua"
POSTURE = LUA / "client/SAO_Posture.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
OBSERVATION = LUA / "client/SAO_Observation.lua"
ORIENTATION = ROOT / "java/src/com/sao/engine/SAOOrientation.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

FORMATION_PRELUDE = r'''
_G.__now=100
_G.__contacts={}
_G.__records={}
_G.__situation={resolved=false,category='food',pressure=.8,waterPressure=.1,
  foodPressure=.8,destination={minX=8,minY=8,maxX=12,maxY=12,z=0},
  destinationSource='retained-home',represented=false,observedAtHours=100,
  needOwner='private-history'}
local function record(id)
  if not __records[id] then __records[id]={id=id,dead=false,designation=nil} end
  return __records[id]
end
SAO={History={countyHours=function() return __now end},Branching={},Settlement={},
 Material={},PlayerInteraction={},Cooking={},Posture={},
 Identity={get=record},
 Standing={groupOf=function(id) return 'group' end,
  relationsOf=function(id) return {} end,
  isHostileTo=function() return false end,
  trust=function() return .6 end},
 Perception={knownPeople=function(id) return __contacts[id] or {} end},
 DormantPopulation={privateProvisioningSituation=function() return __situation end,
  companyNeedPressure=function() return .1,true end},
 Communication={deliverProcessProposal=function(fromId,toId,processId)
  _G.__delivered=(_G.__delivered or 0)+1
  return {id='message:'..tostring(__delivered),processId=processId,toId=toId}
 end}}
Events=setmetatable({}, {__index=function(t,key)
 local slot={Add=function() end,Remove=function() end};rawset(t,key,slot);return slot end})
'''

FORMATION_PROBE = r'''(function()
 local checks={}
 local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
 local function contacts(origin,count)
  local rows={}
  for i=1,count do
   local id=origin..'-p'..tostring(i);__records[id]={id=id,dead=false}
   rows[#rows+1]={id=id,beliefKey=id,x=i,y=i,observedAtHours=99,
    observedAt=99,source='observed',hostile=false}
  end
  __contacts[origin]=rows;__records[origin]={id=origin,dead=false}
  return rows
 end
 local Org=SAO.Organization
 contacts('requester',3)
 local food=SAO.Coordination.originatePrivateSituation('requester',nil,'dormant','border209')
 local foodPlan=food and Org.enactedProcedure(food.id,1)
 check('food_pressure_forms_collect_prepare_deliver',foodPlan~=nil
  and food.kind=='provisioning' and foodPlan.steps~=nil
  and foodPlan.steps['acquire-material']~=nil
  and foodPlan.steps['prepare-material'].sameActorAs=='acquire-material'
  and foodPlan.steps['deliver-material'].sameActorAs=='acquire-material')
 local runner='requester-p1'
 Org.recordReception(food.id,runner,1,'spoken','requester',{})
 local accepted=Org.appraiseMatter(food.id,runner,{choice='accept',owner='border209',
  executor='border209',currentActivity='idle',capabilities={acquire=true,prepare=true,
  carry=true,deliver=true},maxProcedureSteps=4,relationship=.6,ownNeed=.1,
  destinationKnown=true,constraints={executionOwnerAvailable=true,ownNeedAvailable=true},
  inputOwners={}})
 Org.deliverResponse(food.id,runner,'requester','spoken',{})
 local work=Org.activeCommitment(runner,'provisioning')
 check('one_physical_actor_claims_material_chain',accepted~=nil and accepted.response=='accept'
  and work~=nil and work.stepIds~=nil
  and work.stepIds['acquire-material']==true and work.stepIds['prepare-material']==true
  and work.stepIds['carry-material']==true and work.stepIds['deliver-material']==true)
 local other='requester-p2'
 Org.recordReception(food.id,other,1,'spoken','requester',{})
 local otherOptions=Org.responseOptions(food.id,other,{currentActivity='idle',
  capabilities={acquire=true,prepare=true,carry=true,deliver=true}})
 local canAccept=false;for _,option in ipairs(otherOptions) do if option=='accept' then canAccept=true end end
 check('continuity_prevents_split_item_ownership',canAccept==false)

 contacts('leader',6)
 local tactical=SAO.Coordination.originatePrivateSituation('leader',nil,'idle','border209',{
  threat={x=40,y=30,z=0,dist=18,at=400,source='observed'},threatCount=3,
  position={x=30,y=30,z=0}})
 local enacted=tactical and Org.enactedProcedure(tactical.id,1)
 local own=Org.activeCommitment('leader','strategic-cooperation')
 local addressed=0;for id,row in pairs(tactical.participants) do
  if id~='leader' and row.addressed then addressed=addressed+1 end end
 check('private_threat_forms_watch_and_withdrawal',enacted~=nil
  and tactical.kind=='strategic-cooperation'
  and enacted.steps and enacted.steps['watch-threat']
  and enacted.steps['watch-threat'].claims.leader~=nil
  and own and own.stepIds and own.stepIds['watch-threat']==true)
 check('two_to_seven_population_is_bounded',addressed==6
  and enacted and enacted.steps and enacted.steps['move-fallback']
  and enacted.steps['move-fallback'].minActors==2
  and enacted.steps['move-fallback'].maxActors==2)
 for i=1,2 do
  local actor='leader-p'..tostring(i)
  Org.recordReception(tactical.id,actor,1,'spoken','leader',{})
  Org.appraiseMatter(tactical.id,actor,{choice='accept',owner='border209',executor='border209',
   currentActivity='idle',capabilities={move=true},preferredRoles={withdraw=true},
   relationship=.6,ownNeed=.1,destinationKnown=true,
   constraints={executionOwnerAvailable=true,ownNeedAvailable=true},inputOwners={}})
  Org.deliverResponse(tactical.id,actor,'leader','spoken',{})
 end
 Org.recordReception(tactical.id,'leader-p3',1,'spoken','leader',{})
 local refusal=Org.appraiseMatter(tactical.id,'leader-p3',{choice='decline',owner='border209',
  executor='border209',currentActivity='idle',capabilities={hold=true},relationship=.2,
  ownNeed=.1,destinationKnown=true,constraints={executionOwnerAvailable=true,
  ownNeedAvailable=true},inputOwners={}})
 Org.deliverResponse(tactical.id,'leader-p3','leader','spoken',{})
 check('recipient_disagreement_remains_a_response',refusal.response=='decline'
  and Org.activeCommitment('leader-p3','strategic-cooperation')==nil)
 Org.noteWorkAdmission(own.id,'Posture','posture-result',{stepId='watch-threat'})
 Org.consumeProcedureResult({id='posture-result',actorId='leader',commitmentId=own.id,
  stepId='watch-threat',token='posture:maintained',owner='Posture',status='completed',at=101})
 for i=1,2 do
  local actor='leader-p'..tostring(i)
  local move=Org.activeCommitment(actor,'strategic-cooperation')
  Org.noteWorkAdmission(move.id,'Locomotion','route-'..tostring(i),{stepId='move-fallback'})
  Org.consumeProcedureResult({id='route-'..tostring(i),actorId=actor,commitmentId=move.id,
   stepId='move-fallback',token='route:travelling',owner='Locomotion',status='completed',at=101+i})
 end
 enacted=Org.enactedProcedure(tactical.id,1)
 check('exact_posture_and_movement_results_close_plan',enacted.status=='completed'
  and tactical.status=='closed' and enacted.steps['cover-movement'].status=='not-needed')

 local matrix=true
 for size=2,7 do
  local origin='matrix-'..tostring(size);contacts(origin,size-1)
  local process=SAO.Coordination.originatePrivateSituation(origin,nil,'idle','border209',{
   threat={x=20+size,y=10,z=0,dist=14+size,at=500+size,source='observed'},
   threatCount=size%4+1,position={x=10,y=10,z=0}})
  local procedure=process and Org.enactedProcedure(process.id,1)
  local count=0;for id,row in pairs(process and process.participants or {}) do
   if id~=origin and row.addressed then count=count+1 end end
  matrix=matrix and procedure~=nil and count==size-1
   and procedure.steps['move-fallback'].minActors==(size==2 and 1 or 2)
 end
 check('varied_two_to_seven_situations_form_without_map_truth',matrix)
 return table.concat(checks,',')
end)()'''

POSTURE_PRELUDE = r'''
local data={SAOPersonId='actor'}
local body={}
function body:getModData() return data end
function body:isDead() return false end
function body:isAsleep() return false end
function body:getVehicle() return nil end
function body:isExistInTheWorld() return true end
function body:getCurrentSquare() return {} end
_G.__body=body
_G.__native={active=false,mode='none',actionId='',reason='idle',maintainedSeconds=0}
_G.__consumed={}
SAO={History={countyHours=function() return 10 end},
 Identity={get=function() return {id='actor',dead=false,postureSequence=0} end},
 Body={active={actor=body},foreign={},get=function(id) return id=='actor' and body or nil end},
 Controller={agents={actor={rec=nil,passive=false}}},
 Neuro={clarityOf=function() return .8 end,motorSteadiness=function() return .7 end},
 Observation={record=function() end},
 Organization={consumeProcedureResult=function(value) __consumed[#__consumed+1]=value return true end}}
local rec=SAO.Identity.get('actor');SAO.Identity.get=function() return rec end
SAO.Controller.agents.actor.rec=rec
SAOJavaBridge={}
function SAOJavaBridge:isShell(value) return value==body end
function SAOJavaBridge:requestPosture(value,actionId,x,y,readiness,steadiness,duration)
 __native={active=true,mode='posture',actionId=actionId,reason='posture-admitted',
  maintainedSeconds=0,requiredSeconds=duration};return value==body end
function SAOJavaBridge:orientationState() return __native end
function SAOJavaBridge:clearPosture() end
Events=setmetatable({}, {__index=function(t,key)
 local slot={Add=function() end,Remove=function() end};rawset(t,key,slot);return slot end})
'''

POSTURE_PROBE = r'''(function()
 local checks={};local function check(n,v) checks[#checks+1]=n..'='..tostring(v==true) end
 local P=SAO.Posture
 local ok,job=P.begin('actor',__body,{processId='p',processRevision=1,
  commitmentId='c',stepId='watch',completionToken='posture:maintained',
  target={x=3,y=4,z=0},posture='watch',durationSeconds=2})
 check('native_admission_starts_exact_posture',ok and job~=nil and P.tick('actor',__body)=='holding'
  and #__consumed==0)
 __native.active=false;__native.reason='blocked';__native.maintainedSeconds=.4
 local failed=P.tick('actor',__body)
 check('ended_without_maintenance_is_failure',failed=='failed' and #__consumed==1
  and __consumed[1].status=='failed')
 ok,job=P.begin('actor',__body,{processId='p2',processRevision=1,
  commitmentId='c2',stepId='cover',completionToken='posture:maintained',
  target={x=5,y=6,z=0},posture='cover',durationSeconds=2})
 __native.active=false;__native.reason='completed';__native.maintainedSeconds=2
 local completed=P.tick('actor',__body)
 check('maintained_native_posture_publishes_exact_result',ok and completed=='completed'
  and #__consumed==2 and __consumed[2].status=='completed'
  and __consumed[2].actorId=='actor' and __consumed[2].stepId=='cover'
  and __consumed[2].token=='posture:maintained')
 return table.concat(checks,',')
end)()'''

FORMATION_EXPECTED = {
    "food_pressure_forms_collect_prepare_deliver",
    "one_physical_actor_claims_material_chain",
    "continuity_prevents_split_item_ownership",
    "private_threat_forms_watch_and_withdrawal",
    "two_to_seven_population_is_bounded",
    "recipient_disagreement_remains_a_response",
    "exact_posture_and_movement_results_close_plan",
    "varied_two_to_seven_situations_form_without_map_truth",
}
POSTURE_EXPECTED = {
    "native_admission_starts_exact_posture",
    "ended_without_maintenance_is_failure",
    "maintained_native_posture_publishes_exact_result",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(prelude: str, sources: list[tuple[str, str]], probe: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-natural-cooperation-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        (work / "prelude.lua").write_text(prelude, encoding="utf-8")
        files = [str(work / "prelude.lua")]
        for name, source in sources:
            path = work / name
            path.write_text(source, encoding="utf-8")
            files.append(str(path))
        (work / "probe.lua").write_text("__result=" + probe, encoding="utf-8")
        files.append(str(work / "probe.lua"))
        done = subprocess.run([str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
                               *files, "--", "__result"], cwd=work,
                              capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def complete(found: dict[str, str], expected: set[str]) -> bool:
    return set(found) == expected and all(value == "true" for value in found.values())


def static_contract() -> tuple[bool, str]:
    sources = {
        "organization": ORG.read_text(encoding="utf-8"),
        "coordination": COORD.read_text(encoding="utf-8"),
        "posture": POSTURE.read_text(encoding="utf-8"),
        "controller": CONTROLLER.read_text(encoding="utf-8"),
        "observation": OBSERVATION.read_text(encoding="utf-8"),
        "orientation": ORIENTATION.read_text(encoding="utf-8"),
        "bridge": BRIDGE.read_text(encoding="utf-8"),
    }
    required = (
        ("function Org.commitOriginator", "organization"),
        ("sameActorAs", "organization"),
        ("originateTacticalSituation", "coordination"),
        ("materialDeliveryProcedure(situation.category)", "coordination"),
        ("function P.begin", "posture"),
        ("requestPosture", "orientation"),
        ("requestPosture", "bridge"),
        ('setState(agent, id, "POSTURE"', "controller"),
        ('row(s, "Recent procedure event"', "observation"),
    )
    missing = [anchor for anchor, source in required if anchor not in sources[source]]
    return not missing, "all natural joins present" if not missing else repr(missing)


def main() -> int:
    print("=" * 74)
    print("NATURAL COOPERATIVE FORMATION AND EXACT POSTURE EXECUTION")
    print("=" * 74)
    required = [ORG, COORD, POSTURE, CONTROLLER, OBSERVATION, ORIENTATION,
                BRIDGE, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    if not all(path.is_file() for path in (PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe")):
        print("Border 209 SKIPPED: installed game VM or JDK absent")
        return 0
    static_ok, detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL") + f" ({detail})")
    built, detail = compile_runner()
    if not built:
        print("  FAULT: runner compile failed " + detail[-1200:])
        return 1
    org_source = ORG.read_text(encoding="utf-8-sig")
    coord_source = COORD.read_text(encoding="utf-8-sig")
    posture_source = POSTURE.read_text(encoding="utf-8-sig")
    formation_value, formation_detail = run_probe(FORMATION_PRELUDE,
        [("organization.lua", org_source), ("coordination.lua", coord_source)],
        FORMATION_PROBE)
    posture_value, posture_detail = run_probe(POSTURE_PRELUDE,
        [("posture.lua", posture_source)], POSTURE_PROBE)
    formation = verdicts(formation_value)
    posture = verdicts(posture_value)
    controls_ok = True
    controls = [
        ("same-actor continuity", "and anchor.claims[actorId]", "and anchor.claims['different-actor']",
         FORMATION_PRELUDE, [("organization.lua", org_source), ("coordination.lua", coord_source)],
         FORMATION_PROBE, FORMATION_EXPECTED),
        ("natural tactical origin", "local tactical, tacticalWhy = originateTacticalSituation(id, ownerLabel,\n        contacts, situation)",
         "local tactical, tacticalWhy = nil, 'disabled'",
         FORMATION_PRELUDE, [("organization.lua", org_source), ("coordination.lua", coord_source)],
         FORMATION_PROBE, FORMATION_EXPECTED),
        ("native completion", 'if state.reason == "completed" then', 'if true then',
         POSTURE_PRELUDE, [("posture.lua", posture_source)], POSTURE_PROBE, POSTURE_EXPECTED),
    ]
    for name, old, new, prelude, source_files, probe, expected in controls:
        matched = sum(source.count(old) for _, source in source_files)
        if matched != 1:
            print(f"  FAULT: {name} mutation seam count {matched}")
            controls_ok = False
            continue
        mutated = [(filename, source.replace(old, new, 1) if old in source else source)
                   for filename, source in source_files]
        value, _ = run_probe(prelude, mutated, probe)
        if complete(verdicts(value), expected):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (three causal controls)")
    formation_ok = complete(formation, FORMATION_EXPECTED)
    posture_ok = complete(posture, POSTURE_EXPECTED)
    if not static_ok or not controls_ok or not formation_ok or not posture_ok:
        print("  FAULT: formation=" + repr(formation_value)
              + " posture=" + repr(posture_value))
        if not formation_ok: print("  " + formation_detail[-2400:].replace("\n", " "))
        if not posture_ok: print("  " + posture_detail[-2400:].replace("\n", " "))
        return 1
    print("  verdicts: PASS (8 formation and 3 exact-posture cases)")
    print("  209) private pressures form bounded cooperation across two to seven")
    print("       people; native posture and movement results remain exact")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
