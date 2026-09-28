#!/usr/bin/env python3
"""Border 208: people claim, execute and revise cooperative procedure roles."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
COORDINATION = LUA / "shared/SAO_Coordination.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
COOKING = LUA / "client/SAO_Cooking.lua"
EXPERIENCE = LUA / "client/SAO_CapabilityExperience.lua"
OBSERVATION = LUA / "client/SAO_Observation.lua"
CATALOGUE = ROOT / "artifacts/audits/c91-autonomous-cooperation/PRIOR_ART_CATALOGUE.md"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
_G.__now = 100
SAO = {
  History = { countyHours = function() return __now end },
  Branching = {}, Settlement = {}, Material = {}, PlayerInteraction = {},
  Identity = { get = function(id) return { id=id, dead=false } end },
  Standing = { groupOf = function() return nil end },
  Communication = { deliverProcessProposal = function(...)
    _G.__delivered = (_G.__delivered or 0) + 1
    return { id='message:' .. tostring(_G.__delivered) }
  end },
}
Events = setmetatable({}, { __index=function(t,key)
  local slot={Add=function() end,Remove=function() end}; rawset(t,key,slot)
  return slot end })
'''

PROBE = r'''(function()
  local checks={}
  local function check(name,value)
    checks[#checks+1]=name .. '=' .. tostring(value==true)
  end
  local Org=SAO.Organization
  local api=SAO.Coordination.proposeCooperation('planner',
    'cooperative-action',{objective='move together',procedure={{id='move',
      verb='move',domain='movement',role='mover',capability='move',
      target={x=1,y=2,z=0},completesOn='route:travelling'}}},
    {'worker'},{source='private-plan'})
  local apiActual=api and Org.enactedProcedure(api.id,1)
  check('actor_authored_api_records_and_transports_generic_plan',api~=nil
    and apiActual.cooperative==true and __delivered==1)
  local procedure={
    {id='scout-move',verb='move',domain='movement',role='scout',
      capability='move',maxActors=1,target={x=10,y=10,z=0},
      completesOn='route:travelling'},
    {id='cover-move',verb='move',domain='movement',role='cover',
      capability='move',maxActors=1,target={x=12,y=10,z=0},
      completesOn='route:travelling'},
    {id='hold-line',verb='hold',domain='posture',role='hold',
      posture='watch',capability='hold',minActors=2,maxActors=2,
      dependsOn={'scout-move','cover-move'},completesOn='action:hold'},
  }
  local process=Org.raiseMatter('origin','strategic-cooperation',nil,{
    cooperative=true,responsePolicy='procedure-completion',
    objective='observe and hold the crossing',procedure=procedure,
    requiredCapabilities={move=true,hold=true},
  },{'scout','cover','holder-a','holder-b','extra'},{source='private-plan'})

  local function accept(id,caps,roles)
    Org.recordReception(process.id,id,1,'spoken','origin',{})
    local response=Org.appraiseMatter(process.id,id,{
      choice='accept',owner='border208',executor='border208',
      currentActivity='idle',capabilities=caps,preferredRoles=roles,
      relationship=.6,ownNeed=.1,destinationKnown=true,
      constraints={represented=false,executionOwnerAvailable=true,
        ownNeedAvailable=true},inputOwners={}})
    Org.deliverResponse(process.id,id,'origin','spoken',{})
    return response,Org.activeCommitment(id,'strategic-cooperation')
  end

  local rs,scout=accept('scout',{move=true},{scout=true})
  local rc,cover=accept('cover',{move=true},{cover=true})
  local rh1,holdA=accept('holder-a',{hold=true},{hold=true})
  local rh2,holdB=accept('holder-b',{hold=true},{hold=true})
  local actual=Org.enactedProcedure(process.id,1)
  check('partial_capability_can_accept_one_role',rs.response=='accept'
    and rh1.response=='accept' and scout.stepIds['scout-move']==true
    and cover.stepIds['cover-move']==true
    and holdA.stepIds['hold-line']==true
    and actual.steps['hold-line'].claims['holder-b']~=nil)
  check('capacity_and_preferences_divide_roles',
    actual.steps['scout-move'].claims.scout~=nil
    and actual.steps['cover-move'].claims.cover~=nil
    and actual.steps['hold-line'].minActors==2
    and actual.steps['hold-line'].maxActors==2)

  Org.recordReception(process.id,'extra',1,'spoken','origin',{})
  local extraOptions=Org.responseOptions(process.id,'extra',{
    capabilities={move=true},currentActivity='idle'})
  local extraCanAccept=false
  for _,option in ipairs(extraOptions) do
    if option=='accept' then extraCanAccept=true end
  end
  check('filled_roles_are_not_offered_again',extraCanAccept==false)

  Org.noteWorkAdmission(scout.id,'Locomotion','route-s',
    {stepId='scout-move'})
  local rejected=Org.consumeProcedureResult({id='route-s',actorId='cover',
    commitmentId=scout.id,stepId='scout-move',token='route:travelling',
    owner='Locomotion',status='completed'})
  check('wrong_actor_cannot_complete_claim',rejected==false)

  local movedS=Org.consumeProcedureResult({id='route-s',actorId='scout',
    commitmentId=scout.id,stepId='scout-move',token='route:travelling',
    owner='Locomotion',status='completed',at=101})
  Org.noteWorkAdmission(cover.id,'Locomotion','route-c',
    {stepId='cover-move'})
  local movedC=Org.consumeProcedureResult({id='route-c',actorId='cover',
    commitmentId=cover.id,stepId='cover-move',token='route:travelling',
    owner='Locomotion',status='completed',at=102})
  actual=Org.enactedProcedure(process.id,1)
  check('parallel_movements_use_exact_owned_results',movedS==true and movedC==true
    and actual.steps['scout-move'].status=='completed'
    and actual.steps['cover-move'].status=='completed'
    and process.status=='open')

  check('dependency_completion_is_not_telepathic',
    Org.workPlan(holdA.id,'holder-a').intendedStepId==nil)
  for _,id in ipairs({'holder-a','holder-b'}) do
    Org.revisePrivateProcedure(process.id,id,1,{beliefs={
      ['scout-move']='completed',['cover-move']='completed'}},
      {kind='communication',source='movement-report'})
  end
  check('communicated_arrivals_open_posture_work',
    Org.workPlan(holdA.id,'holder-a').intendedStepId=='hold-line'
    and Org.workPlan(holdB.id,'holder-b').intendedStepId=='hold-line')

  Org.noteWorkAdmission(holdA.id,'Posture','hold-a',{stepId='hold-line'})
  Org.consumeProcedureResult({id='hold-a',actorId='holder-a',
    commitmentId=holdA.id,stepId='hold-line',token='action:hold',
    owner='Posture',status='completed',at=103})
  actual=Org.enactedProcedure(process.id,1)
  check('first_contribution_does_not_complete_barrier',
    actual.steps['hold-line'].status~='completed'
    and actual.steps['hold-line'].contributions['holder-a']~=nil
    and process.status=='open')
  Org.noteWorkAdmission(holdB.id,'Posture','hold-b',{stepId='hold-line'})
  Org.consumeProcedureResult({id='hold-b',actorId='holder-b',
    commitmentId=holdB.id,stepId='hold-line',token='action:hold',
    owner='Posture',status='completed',at=104})
  actual=Org.enactedProcedure(process.id,1)
  check('threshold_closes_shared_procedure',
    actual.steps['hold-line'].status=='completed'
    and actual.status=='completed' and process.status=='closed'
    and process.closureReason=='procedure-completion')

  local failed=Org.raiseMatter('origin','cooperative-action',nil,{
    cooperative=true,responsePolicy='procedure-completion',
    objective='reach a safer approach',procedure={{id='reroute',verb='move',
      domain='movement',role='scout',capability='move',maxActors=1,
      target={x=30,y=30,z=0},completesOn='route:travelling'}},
  },{'runner'},{source='private-plan'})
  Org.recordReception(failed.id,'runner',1,'spoken','origin',{})
  Org.appraiseMatter(failed.id,'runner',{choice='accept',owner='border208',
    executor='border208',currentActivity='idle',capabilities={move=true},
    preferredRoles={scout=true},relationship=.5,ownNeed=.1,
    destinationKnown=true,constraints={executionOwnerAvailable=true,
      ownNeedAvailable=true},inputOwners={}})
  Org.deliverResponse(failed.id,'runner','origin','spoken',{})
  local run=Org.activeCommitment('runner','cooperative-action')
  Org.noteWorkAdmission(run.id,'Locomotion','route-f',{stepId='reroute'})
  Org.consumeProcedureResult({id='route-f',actorId='runner',
    commitmentId=run.id,stepId='reroute',token='route:travelling',
    owner='Locomotion',status='failed',reason='route-blocked',at=105})
  local failedActual=Org.enactedProcedure(failed.id,1)
  check('failed_role_opens_revision_without_reassignment',
    failedActual.revisionNeeded.reason=='route-blocked'
    and failedActual.steps.reroute.claims.runner.status=='failed'
    and run.status=='paused')
  local revised=Org.reviseMatter(failed.id,'origin',{
    cooperative=true,responsePolicy='procedure-completion',
    objective='reach a different approach',procedure={{id='reroute-2',
      verb='move',domain='movement',role='scout',capability='move',
      target={x=25,y=28,z=0},completesOn='route:travelling'}},
  },{source='observed-route-failure'})
  check('revision_requires_fresh_reception_and_response',revised.revision==2
    and run.status=='superseded'
    and Org.privateProcedure('runner',failed.id,2)==nil
    and Org.enactedProcedure(failed.id,2).steps['reroute-2'].status=='available')
  return table.concat(checks,',')
end)()'''

EXPECTED = {
    "actor_authored_api_records_and_transports_generic_plan",
    "partial_capability_can_accept_one_role",
    "capacity_and_preferences_divide_roles",
    "filled_roles_are_not_offered_again",
    "wrong_actor_cannot_complete_claim",
    "parallel_movements_use_exact_owned_results",
    "dependency_completion_is_not_telepathic",
    "communicated_arrivals_open_posture_work",
    "first_contribution_does_not_complete_barrier",
    "threshold_closes_shared_procedure",
    "failed_role_opens_revision_without_reassignment",
    "revision_requires_fresh_reception_and_response",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(source: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-autonomous-cooperation-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        (work / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (work / "organization.lua").write_text(source, encoding="utf-8")
        (work / "coordination.lua").write_text(
            COORDINATION.read_text(encoding="utf-8-sig"), encoding="utf-8")
        (work / "probe.lua").write_text("__result = " + PROBE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(work / "prelude.lua"), str(work / "organization.lua"),
             str(work / "coordination.lua"), str(work / "probe.lua"),
             "--", "__result"], cwd=work,
            capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract() -> tuple[bool, str]:
    org = ORGANIZATION.read_text(encoding="utf-8")
    coordination = COORDINATION.read_text(encoding="utf-8")
    controller = CONTROLLER.read_text(encoding="utf-8")
    cooking = COOKING.read_text(encoding="utf-8")
    experience = EXPERIENCE.read_text(encoding="utf-8")
    observation = OBSERVATION.read_text(encoding="utf-8")
    catalogue = CATALOGUE.read_text(encoding="utf-8")
    required = (
        ("function Org.claimProcedureStep", org),
        ("function Org.consumeProcedureResult", org),
        ('responsePolicy == "procedure-completion"', org),
        ("function Coordination.proposeCooperation", coordination),
        ("procedureMove = true", controller),
        ('completionToken = "cooking:prepared"', controller),
        ("commitmentId = context.commitmentId", cooking),
        ("SAO.Organization.consumeProcedureResult", experience),
        ('row(s, "Revision needed"', observation),
        ("OpenXRay A-Life", catalogue),
        ("Living Fellows", catalogue),
        ("Colonist Awareness", catalogue),
        ("Strategic cooperation vocabulary", catalogue),
    )
    missing = [anchor for anchor, source in required if anchor not in source]
    return not missing, "all joins present" if not missing else repr(missing)


def main() -> int:
    print("=" * 74)
    print("AUTONOMOUS COOPERATIVE ROLES, STRATEGIC ACTIONS AND REVISION")
    print("=" * 74)
    required = [ORGANIZATION, COORDINATION, CONTROLLER, COOKING,
                EXPERIENCE, OBSERVATION, CATALOGUE, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    if not all(path.is_file() for path in (PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe")):
        print("Border 208 SKIPPED: installed game VM or JDK absent")
        return 0
    static_ok, detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL") + f" ({detail})")
    built, detail = compile_runner()
    if not built:
        print("  FAULT: runner compile failed " + detail[-1000:])
        return 1
    source = ORGANIZATION.read_text(encoding="utf-8-sig")
    value, detail = run_probe(source)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")
    controls = [
        ("claim capacity", "local capacity = step and activeClaimCount(step) < (step.maxActors or 1)",
         "local capacity = true"),
        ("actor result ownership", "or result.actorId ~= commitment.actorId",
         "or false"),
        ("synchronization threshold", "contributions >= (step.minActors or 1)",
         "contributions >= 1"),
        ("fresh revision reception", "createPrivatePlan(process, originatorId, process.revision,",
         "createPrivatePlan(process, 'runner', process.revision,"),
    ]
    controls_ok = True
    for name, old, new in controls:
        if source.count(old) < 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutant = source.replace(old, new, 1)
        mutant_value, _ = run_probe(mutant)
        mutant_found = verdicts(mutant_value)
        if (set(mutant_found) == EXPECTED
                and all(result == "true" for result in mutant_found.values())):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (four production controls)")
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + detail[-2500:].replace("\n", " "))
        return 1
    print("  verdicts: PASS (12 role, movement, synchronization and revision cases)")
    print("  208) cooperative procedures divide work by actor capability, preserve")
    print("       private dependency knowledge and revise only from exact outcomes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
