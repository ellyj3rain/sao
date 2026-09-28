#!/usr/bin/env python3
"""Border 207: enacted procedure truth remains separate from private plans."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
COMMUNICATION = LUA / "shared/SAO_Communication.lua"
GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
COORDINATION = LUA / "shared/SAO_Coordination.lua"
STANDING = LUA / "shared/SAO_Standing.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
_G.__now = 100
SAO = {
  History = { countyHours = function() return __now end },
  Branching = {}, Settlement = {}, Material = {}, PlayerInteraction = {},
  Identity = { get = function(id) return { id=id, dead=false } end },
}
_G.__stores = { SurvivorAwareness_Graph = {
  schema=4, branching={patterns={},offices={}},
  organization={organizations={},offices={},claims={},decisions={},
    claimHistory={},decisionHistory={},processes={},processOrder={},
    processMeta={sequence=0},workReceipts={}},
  settlement={bases={}}, material={stores={},reconciliations={},sourceOwners={}},
  communication={messages={}}, player={claims={}}, migrations={},
} }
ModData = { getOrCreate=function(key) __stores[key]=__stores[key] or {}
  return __stores[key] end }
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
  check('persistence_owner_initialized', SAO.GraphPersistence.bind()==true
    and __stores.SurvivorAwareness_Graph.migrations.c90CooperativeProcedures~=nil)

  local invalid=Org.raiseMatter('origin','invalid',nil,{procedure={
    {id='a',verb='a',dependsOn={'b'},completesOn='a'},
    {id='b',verb='b',dependsOn={'a'},completesOn='b'},
  }},{},{})
  check('cyclic_procedure_refused', invalid==nil)

  local procedure={
    {id='acquire-material',verb='acquire',capability='acquire',
      completesOn='source:acquire'},
    {id='carry-material',verb='carry',capability='carry',required=false,
      dependsOn={'acquire-material'},completesOn='route:carrying'},
    {id='deliver-material',verb='deliver',capability='deliver',
      dependsOn={'acquire-material'},
      completesOn={'source:store','handover:completed'}},
  }
  local process=Org.raiseMatter('origin','food-delivery',nil,{
    destination={minX=4,minY=4,maxX=6,maxY=6,z=0},
    requiredCapabilities={acquire=true,carry=true,deliver=true},
    scope={category='food',quantity=1},procedure=procedure,
  },{'actor','silent'},{need='private'})
  local actual=Org.enactedProcedure(process.id,1)
  check('authorship_does_not_broadcast_private_plan',
    Org.privateProcedure('origin',process.id,1)~=nil
    and Org.privateProcedure('actor',process.id,1)==nil
    and Org.privateProcedure('silent',process.id,1)==nil
    and actual.steps['acquire-material'].status=='available'
    and actual.steps['deliver-material'].status=='blocked')

  local message=SAO.Communication.send('origin','actor','process-proposal',
    {processId=process.id,revision=1})
  message.transportAdmitted=true; message.channel='spoken'
  message.transportEvidence={distance=2}
  SAO.Communication.deliver(message)
  local acquired=Org.privateProcedure('actor',process.id,1)
  check('reception_creates_only_recipient_projection', acquired~=nil
    and acquired.acquiredBy=='spoken'
    and acquired.intendedStepId=='acquire-material'
    and Org.privateProcedure('silent',process.id,1)==nil)

  Org.appraiseMatter(process.id,'actor',{choice='accept',owner='border207',
    executor='border207',bodyOwner='SAO',currentActivity='idle',
    relationship=.5,ownNeed=.1,destinationKnown=true,
    canAcquire=true,canCarry=true,canDeliver=true,
    constraints={represented=false,executionOwnerAvailable=true,
      ownNeedAvailable=true},inputOwners={}})
  Org.deliverResponse(process.id,'actor','origin','spoken',{})
  local commitment=Org.activeCommitment('actor','food-delivery')
  local actorPlan=Org.workPlan(commitment.id,'actor')
  check('execution_reads_actor_projection_only', actorPlan~=nil
    and actorPlan.privateProcedure.personId=='actor'
    and actorPlan.enactedProcedure==nil
    and Org.workPlan(commitment.id,'origin')==nil
    and Org.workPlan(commitment.id,nil)==nil)

  Org.revisePrivateProcedure(process.id,'actor',1,
    {intendedStepId='deliver-material',beliefs={['deliver-material']='possible'}},
    {kind='disagreement',model='associative'})
  check('private_disagreement_does_not_rewrite_process',
    Org.privateProcedure('actor',process.id,1).intendedStepId=='deliver-material'
    and Org.privateProcedure('origin',process.id,1).intendedStepId
      =='acquire-material'
    and Org.enactedProcedure(process.id,1).steps['deliver-material'].status
      =='blocked')

  Org.startWork(commitment.id,'SAO','acquiring')
  Org.noteWorkAdmission(commitment.id,'SourceUse','source-207',{})
  Org.consumeSourceResult({reservationId='source-207',processId=process.id,
    processRevision=1,commitmentId=commitment.id,actorId='actor',
    operation='acquire',status='completed',at=101})
  actual=Org.enactedProcedure(process.id,1)
  local actorAfterAcquire=Org.privateProcedure('actor',process.id,1)
  local originAfterAcquire=Org.privateProcedure('origin',process.id,1)
  check('source_receipt_advances_truth_and_actor_only',
    actual.steps['acquire-material'].status=='completed'
    and actual.steps['deliver-material'].status=='available'
    and actorAfterAcquire.beliefs['acquire-material'].status=='completed'
    and actorAfterAcquire.intendedStepId=='deliver-material'
    and originAfterAcquire.beliefs['acquire-material'].status=='planned')

  local route=Org.noteRoute(commitment.id,'Locomotion',5,5,0,'carrying',{})
  Org.routeOutcome(commitment.id,'arrived','arrived')
  actual=Org.enactedProcedure(process.id,1)
  check('carrying_receipt_advances_optional_step_privately',
    actual.steps['carry-material'].status=='completed'
    and Org.privateProcedure('actor',process.id,1).beliefs['carry-material'].status
      =='completed'
    and Org.privateProcedure('origin',process.id,1).beliefs['carry-material'].status
      =='planned')

  Org.noteWorkAdmission(commitment.id,'Handover','handover-207',{})
  Org.consumeHandoverResult({id='handover-207',processId=process.id,
    processRevision=1,commitmentId=commitment.id,actorId='actor',
    recipientId='origin',status='completed',completedAt=102})
  actual=Org.enactedProcedure(process.id,1)
  check('handover_receipt_updates_direct_participants',
    actual.status=='completed'
    and actual.steps['deliver-material'].status=='completed'
    and Org.privateProcedure('actor',process.id,1).beliefs['deliver-material'].status
      =='completed'
    and Org.privateProcedure('origin',process.id,1).beliefs['deliver-material'].status
      =='completed'
    and Org.privateProcedure('silent',process.id,1)==nil)

  local savedActor=Org.privateProcedure('actor',process.id,1)
  Org.processes={}; Org.processOrder={}; Org.processMeta={}; Org.workReceipts={}
  SAO.GraphPersistence.bind()
  check('reload_preserves_truth_and_distinct_projections',
    Org.enactedProcedure(process.id,1).status=='completed'
    and Org.privateProcedure('actor',process.id,1).updatedAt==savedActor.updatedAt
    and Org.privateProcedure('origin',process.id,1).beliefs['acquire-material'].status
      =='planned')
  return table.concat(checks,',')
end)()'''

EXPECTED = {
    'persistence_owner_initialized', 'cyclic_procedure_refused',
    'authorship_does_not_broadcast_private_plan',
    'reception_creates_only_recipient_projection',
    'execution_reads_actor_projection_only',
    'private_disagreement_does_not_rewrite_process',
    'source_receipt_advances_truth_and_actor_only',
    'carrying_receipt_advances_optional_step_privately',
    'handover_receipt_updates_direct_participants',
    'reload_preserves_truth_and_distinct_projections',
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / 'javac.exe'), '-cp', str(PZ), '-d', str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(org_source: str, communication_source: str,
              graph_source: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix='sao-cooperative-procedure-') as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / 'stdlib.lua')
        for cls in OUT.glob('LuaRun*.class'):
            shutil.copy2(cls, work / cls.name)
        files = {'prelude.lua': PRELUDE, 'organization.lua': org_source,
                 'communication.lua': communication_source,
                 'graph.lua': graph_source, 'probe.lua': '__result = ' + PROBE}
        for name, source in files.items():
            (work / name).write_text(source, encoding='utf-8')
        done = subprocess.run(
            [str(JDK / 'java.exe'), '-cp', f'{PZ};.', 'LuaRun',
             str(work / 'prelude.lua'), str(work / 'organization.lua'),
             str(work / 'communication.lua'), str(work / 'graph.lua'),
             str(work / 'probe.lua'), '--', '__result'], cwd=work,
            capture_output=True, text=True, timeout=300)
    output = (done.stdout or '') + (done.stderr or '')
    lines = (done.stdout or '').strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith('VALUE ') else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r'([a-z0-9_]+)=(true|false)', value or ''))


def static_contract() -> tuple[bool, str]:
    org = ORGANIZATION.read_text(encoding='utf-8')
    coordination = COORDINATION.read_text(encoding='utf-8')
    standing = STANDING.read_text(encoding='utf-8')
    controller = CONTROLLER.read_text(encoding='utf-8')
    required = ('function Org.privateProcedure',
                'function Org.enactedProcedure',
                'function Org.revisePrivateProcedure',
                'completeProcedureToken(commitment, "source:acquire"',
                'completeProcedureToken(commitment, "handover:completed"')
    if any(anchor not in org for anchor in required):
        return False, 'procedure owner or native receipt join absent'
    if ('procedure = materialDeliveryProcedure(situation.category)' not in coordination
            or 'completesOn = { "source:store", "handover:completed" }'
            not in standing):
        return False, 'native situation producers do not publish procedure terms'
    if 'SAO.Organization.workPlan(commitment.id, id)' not in controller:
        return False, 'controller does not request its actor-private plan'
    return True, 'durable truth, private projections and native joins are wired'


def main() -> int:
    print('=' * 74)
    print('COOPERATIVE PROCEDURE TRUTH AND PRIVATE PARTICIPANT PROJECTIONS')
    print('=' * 74)
    required = [ORGANIZATION, COMMUNICATION, GRAPH, COORDINATION, STANDING,
                CONTROLLER, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print('  FAULT: repository input absent: ' + ', '.join(map(str, missing)))
        return 1
    installed = [PZ, STDLIB, JDK / 'java.exe', JDK / 'javac.exe']
    if not all(path.is_file() for path in installed):
        print('Border 207 SKIPPED: installed game VM or JDK absent')
        return 0
    static_ok, detail = static_contract()
    print('  static contract: ' + ('PASS' if static_ok else 'FAIL')
          + ' (' + detail + ')')
    built, detail = compile_runner()
    if not built:
        print('  FAULT: runner compile failed ' + detail[-1000:])
        return 1
    org = ORGANIZATION.read_text(encoding='utf-8-sig')
    communication = COMMUNICATION.read_text(encoding='utf-8-sig')
    graph = GRAPH.read_text(encoding='utf-8-sig')
    value, detail = run_probe(org, communication, graph)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != 'true')
    controls = [
        ('actor plan boundary',
         'or personId ~= commitment.actorId then', 'or false then', 'org'),
        ('dependency availability',
         'if not dependency or dependency.status ~= "completed" then',
         'if false then', 'org'),
        ('source truth join', '"source:acquire", receiptId,',
         '"source:missing", receiptId,', 'org'),
        ('handover shared witness',
         '{ commitment.actorId, commitment.beneficiaryId },',
         '{ commitment.actorId },', 'org'),
        ('process persistence',
         'SAO.Organization.processes = store.organization.processes\n'
         '        SAO.Organization.processOrder = store.organization.processOrder',
         'SAO.Organization.processes = {}\n'
         '        SAO.Organization.processOrder = store.organization.processOrder', 'graph'),
    ]
    controls_ok = True
    for name, old, new, target in controls:
        source = org if target == 'org' else graph
        if source.count(old) < 1:
            print(f'  FAULT: {name} mutation seam changed')
            controls_ok = False
            continue
        mutant = source.replace(old, new, 1)
        mutant_org = mutant if target == 'org' else org
        mutant_graph = mutant if target == 'graph' else graph
        mutant_value, _ = run_probe(mutant_org, communication, mutant_graph)
        mutant_found = verdicts(mutant_value)
        if (set(mutant_found) == EXPECTED
                and all(result == 'true' for result in mutant_found.values())):
            print(f'  FAULT: {name} mutation survived')
            controls_ok = False
    print('  mutation controls: ' + ('PASS' if controls_ok else 'FAIL')
          + ' (five production controls)')
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print('  FAULT: missing=' + repr(sorted(EXPECTED - set(found)))
              + ' failed=' + repr(failed) + ' value=' + repr(value))
        print('  ' + detail[-2500:].replace('\n', ' '))
        return 1
    print('  verdicts: PASS (10 actor-private and enacted-process cases)')
    print('  207) long-form procedure dependencies persist separately from each '
          'participant projection and advance only through owned receipts')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
