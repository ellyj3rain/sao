#!/usr/bin/env python3
"""Border 194: generic acquired matters and exact arrival serve external lives."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORG = LUA / "shared/SAO_Organization.lua"
COMM = LUA / "shared/SAO_Communication.lua"
GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
COORDINATION = LUA / "shared/SAO_Coordination.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
NEEDS = LUA / "client/SAO_Needs.lua"
DORMANT = LUA / "client/SAO_DormantPopulation.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
_G.__now = 100
_G.__people = {}
_G.__bodies = {}
local function body(id, x)
  local b = { id=id, x=x or 0, y=0, z=0 }
  function b:getX() return self.x end
  function b:getY() return self.y end
  function b:getZ() return self.z end
  __bodies[id] = b
  return b
end
for index,id in ipairs({'origin','external-a','external-b','intruder'}) do
  __people[id] = { id=id, forename=id, surname='Border', dead=false,
    profile={ frozen='private' } }
  body(id, index)
end
__people['external-a'].bodyOwner='ZAO'
__people['external-b'].bodyOwner='ZAO'
SAO = {
  History={ countyHours=function() return __now end },
  Identity={ get=function(id) return __people[id] end },
  Body={ active={ origin=__bodies.origin, intruder=__bodies.intruder },
    hasRepresentation=function(id) return __bodies[id] ~= nil end },
  Controller={ agents={} },
  Perception={ EARSHOT=10 },
  Standing={ groupOf=function() return nil end,trust=function() return .5 end,
    isHostileTo=function() return false end },
  Needs={ read=function() return {hunger=.1,thirst=.1,fatigue=.1} end },
}
SAOJavaBridge = {
  canConverseNow=function(self,a,b,reach) return a ~= nil and b ~= nil end,
}
getSpecificPlayer=function() return nil end
Events=setmetatable({}, {__index=function(t,k)
  local slot={Add=function() end,Remove=function() end}; rawset(t,k,slot); return slot
end})
_G.__stores={ SurvivorAwareness_Graph={ schema=3,
  branching={patterns={},offices={}},
  organization={organizations={},offices={},claims={},decisions={}},
  settlement={bases={}},
  material={stores={},reconciliations={},sourceOwners={}},
  communication={messages={}}, player={claims={}}, migrations={} } }
ModData={ getOrCreate=function(key)
  __stores[key]=__stores[key] or {}; return __stores[key]
end }
'''

PROBE = r'''(function()
  local checks={}
  local function check(name,value)
    checks[#checks+1]=name..'='..tostring(value==true)
  end
  local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
  SAO.GraphPersistence.bind()
  SAO.Communication.registerExecutionOwner('ZAO', {
    bodyFor=function(id) return __bodies[id] end,
    snapshot=function(id) return { bodyOwner='ZAO', executor='ZAO.Driver',
      represented=true, currentActivity='idle', canAcquire=true,
      canCarry=true, canDeliver=true, canExecute=true,
      competingPressure=.2, inputOwners={competingPressure='ZAO.Driver'} }
    end,
    appraiseMatter=function(id,rec,view,base)
      return { owner='ZAO.Driver.appraisal', executor='ZAO.Driver',
        bodyOwner='ZAO', currentActivity='idle', canAcquire=true,
        canCarry=true, canDeliver=true, canExecute=true,
        ownNeed=.2, relationship=id=='external-a' and .8 or -.6,
        destinationKnown=true,
        choice=id=='external-a' and 'accept' or 'contest',
        interests={relationship=id=='external-a' and .8 or -.6},
        constraints={represented=true,executionOwnerAvailable=true,
          ownNeedAvailable=true},
        inputOwners={currentActivity='ZAO.Driver',capabilities='ZAO.Mind',
          ownNeed='ZAO.Driver',relationship='SAO.Standing',
          interests='ZAO.Mind',constraints='ZAO.Driver'} }
    end,
  })

  local p=SAO.Organization.raiseMatter('origin','provisioning',nil,{
    intentKey='water:0:0:0:3', destinationRequired=true,
    destination={minX=0,minY=0,maxX=2,maxY=2,z=0},
    requiredCapabilities={acquire=true,carry=true,deliver=true},
    scope={action='deliver-material',category='water',quantity=1},
  },{'external-a','external-b'},{need=.8})
  local generic=SAO.Communication.send('origin','external-a',
    'process-proposal',{processId=p.id,revision=p.revision})
  SAO.Communication.deliver(generic)
  check('generic_message_is_not_acquisition',
    #SAO.Organization.pendingAppraisals('external-a')==0)
  local denied,why=SAO.Communication.deliverProcessProposal(
    'origin','intruder',p.id,nil,{distance=1})
  check('only_addressed_recipient_can_acquire',denied==nil and why=='not-addressed')
  local ma=SAO.Communication.deliverProcessProposal(
    'origin','external-a',p.id,nil,{distance=1})
  local mb=SAO.Communication.deliverProcessProposal(
    'origin','external-b',p.id,nil,{distance=1})
  check('admitted_transport_enqueues_current_appraisal',ma~=nil and mb~=nil
    and #SAO.Organization.pendingAppraisals('external-a')==1
    and #SAO.Organization.pendingAppraisals('external-b')==1)
  local formedA=SAO.Coordination.appraisePending('external-a',nil,'dormant',
    'DormantPopulation.coordination')
  local formedB=SAO.Coordination.appraisePending('external-b',nil,'dormant',
    'DormantPopulation.coordination')
  local originView=SAO.Organization.viewFor('origin',p.id,false)
  check('external_owner_forms_independent_responses',
    formedA==1 and formedB==1
    and originView.responses['external-a'].response=='accept'
    and originView.responses['external-b'].response=='contest'
    and originView.proposal.proposal.scope.category=='water')
  check('delivered_acceptance_scopes_material_work',
    SAO.Organization.activeCommitment('external-a','provisioning')~=nil
    and SAO.Organization.workPlan(
      SAO.Organization.activeCommitment('external-a','provisioning').id)
      .proposal.scope.category=='water')

  local r=SAO.Organization.raiseMatter('origin','rendezvous-holding',nil,{
    intentKey='known-ground:8:8:0',destinationRequired=true,
    destination={minX=7,minY=7,maxX=9,maxY=9,z=0},
    requiredCapabilities={execute=true},
    scope={action='rendezvous-holding',arrivalActivity='holding-with-kin'},
  },{'external-b'},{knowledge='private'})
  SAO.Communication.deliverProcessProposal('origin','external-b',r.id,nil,{})
  SAO.Organization.appraiseMatter(r.id,'external-b',{
    owner='ZAO.Driver.appraisal',executor='ZAO.Driver',bodyOwner='ZAO',
    currentActivity='idle',canExecute=true,choice='accept',relationship=.5,
    ownNeed=.1,destinationKnown=true,
    constraints={represented=true,executionOwnerAvailable=true,
      ownNeedAvailable=true} })
  SAO.Communication.deliverPendingResponses('external-b','origin',nil,{})
  local commitment=SAO.Organization.activeCommitment(
    'external-b','rendezvous-holding')
  SAO.Organization.startWork(commitment.id,'ZAO','travelling')
  local route=SAO.Organization.noteRoute(commitment.id,'Locomotion',8,8,0,
    'travelling')
  local early,earlyWhy=SAO.Organization.completeArrival(commitment.id,
    route.id,'holding-with-kin',{})
  SAO.Organization.routeOutcome(commitment.id,'arrived','arrived')
  local done=SAO.Organization.completeArrival(commitment.id,route.id,
    'holding-with-kin',{position=true})
  local outcomes=#commitment.work.outcomes
  local replay,replayWhy=SAO.Organization.completeArrival(commitment.id,
    route.id,'holding-with-kin',{})
  check('arrival_requires_exact_locomotion_result',early==false
    and earlyWhy=='arrival-not-admitted' and done==true
    and commitment.status=='completed'
    and commitment.work.arrivalActivity=='holding-with-kin')
  check('arrival_receipt_is_consumed_once',replay==true
    and replayWhy=='duplicate' and #commitment.work.outcomes==outcomes
    and SAO.Organization.workReceipts['arrival:'..route.id]~=nil)

  local revised=SAO.Organization.reviseMatter(p.id,'origin',{
    intentKey='food:0:0:0:2',destinationRequired=true,
    destination={minX=0,minY=0,maxX=2,maxY=2,z=0},
    requiredCapabilities={acquire=true,carry=true,deliver=true},
    scope={action='deliver-material',category='food',quantity=1},
  },{need=.6})
  check('revision_requires_fresh_acquisition',revised~=nil
    and #SAO.Organization.pendingAppraisals('external-a')==0)
  SAO.Communication.deliverProcessProposal('origin','external-a',p.id,nil,{})
  check('fresh_revision_reenters_appraisal',
    #SAO.Organization.pendingAppraisals('external-a')==1)
  SAO.Organization.withdrawMatter(p.id,'origin','probe-finished',{})

  local exp=SAO.Organization.raiseMatter('origin','expiry-test',nil,{
    expiresAtHours=101,requiredCapabilities={execute=true},scope={action='wait'}
  },{'external-a'},{})
  SAO.Communication.deliverProcessProposal('origin','external-a',exp.id,nil,{})
  SAO.Organization.appraiseMatter(exp.id,'external-a',{
    choice='accept',currentActivity='idle',canExecute=true,
    relationship=.5,ownNeed=0,destinationKnown=true})
  SAO.Communication.deliverPendingResponses('external-a','origin',nil,{})
  local expCommit=SAO.Organization.activeCommitment('external-a','expiry-test')
  __now=102
  SAO.Organization.latestMatter('origin','expiry-test')
  check('expiry_ends_live_responsibility_without_erasure',
    exp.status=='expired' and expCommit.status=='withdrawn'
    and exp.closedAt==102
    and SAO.Organization.viewFor('external-a',exp.id,true)~=nil)

  local resumed=SAO.Organization.raiseMatter('origin','rendezvous-holding',nil,{
    intentKey='reload-ground:4:4:0',destinationRequired=true,
    destination={minX=3,minY=3,maxX=5,maxY=5,z=0},
    requiredCapabilities={execute=true},
    scope={action='rendezvous-holding',arrivalActivity='holding-home'},
  },{'external-a'},{knowledge='private'})
  SAO.Communication.deliverProcessProposal('origin','external-a',resumed.id,nil,{})
  SAO.Organization.appraiseMatter(resumed.id,'external-a',{
    owner='ZAO.Driver.appraisal',executor='ZAO.Driver',bodyOwner='ZAO',
    currentActivity='idle',canExecute=true,choice='accept',relationship=.5,
    ownNeed=.1,destinationKnown=true,
    constraints={represented=true,executionOwnerAvailable=true,
      ownNeedAvailable=true} })
  SAO.Communication.deliverPendingResponses('external-a','origin',nil,{})
  local resumedCommit=SAO.Organization.activeCommitment(
    'external-a','rendezvous-holding')
  SAO.Organization.startWork(resumedCommit.id,'ZAO','travelling')
  local remembered=SAO.Organization.noteRoute(resumedCommit.id,'Locomotion',
    4,4,0,'travelling')
  local routeStatus='moving'
  SAO.Locomotion={jobs={},
    order=function(id,b,x,y,z) __reissued={id=id,x=x,y=y,z=z}; return true end,
    tick=function() end,status=function() return routeStatus end,
    cancel=function() end}
  SAO.Controller.coordinationRuntime={}
  SAO.Organization.processes,SAO.Organization.processOrder={},{ }
  SAO.Organization.processMeta,SAO.Organization.workReceipts={sequence=0},{}
  SAO.GraphPersistence.bind()
  resumedCommit=SAO.Organization.activeCommitment(
    'external-a','rendezvous-holding')
  local resumedOwned,resumedStatus=SAO.Controller.advanceExternalCoordination(
    'external-a',__bodies['external-a'],'ZAO','idle')
  check('pending_route_rebinds_without_duplicate',resumedOwned==true
    and resumedStatus=='route' and __reissued~=nil
    and #resumedCommit.work.routeAttempts==1
    and SAO.Controller.coordinationRuntime['external-a'].coordinationRoute.routeId
      ==remembered.id)
  routeStatus='done:arrived'
  local completed,completedStatus=SAO.Controller.advanceExternalCoordination(
    'external-a',__bodies['external-a'],'ZAO','idle')
  check('rebound_route_completes_exact_promised_activity',completed==true
    and completedStatus=='completed:holding-home'
    and resumedCommit.status=='completed'
    and resumedCommit.work.arrivalReceiptId==remembered.id
    and #resumedCommit.work.routeAttempts==1)

  local saved=r.id
  SAO.Organization.processes,SAO.Organization.processOrder={},{ }
  SAO.Organization.processMeta,SAO.Organization.workReceipts={sequence=0},{}
  SAO.GraphPersistence.bind()
  check('process_and_arrival_survive_rebind',
    SAO.Organization.processes[saved]~=nil
    and count(SAO.Organization.workReceipts)>0)
  return table.concat(checks,',')
end)()'''

EXPECTED = {
    "generic_message_is_not_acquisition",
    "only_addressed_recipient_can_acquire",
    "admitted_transport_enqueues_current_appraisal",
    "external_owner_forms_independent_responses",
    "delivered_acceptance_scopes_material_work",
    "arrival_requires_exact_locomotion_result",
    "arrival_receipt_is_consumed_once",
    "revision_requires_fresh_acquisition",
    "fresh_revision_reenters_appraisal",
    "expiry_ends_live_responsibility_without_erasure",
    "pending_route_rebinds_without_duplicate",
    "rebound_route_completes_exact_promised_activity",
    "process_and_arrival_survive_rebind",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(org: str, communication: str, coordination: str,
              controller: str) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-external-life-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        sources = {
            "prelude.lua": PRELUDE,
            "organization.lua": org,
            "communication.lua": communication,
            "coordination.lua": coordination,
            "controller.lua": controller,
            "probe.lua": "__result = " + PROBE,
        }
        for name, source in sources.items():
            (work / name).write_text(source, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(work / "prelude.lua"), str(work / "organization.lua"),
             str(work / "communication.lua"), str(GRAPH),
             str(work / "coordination.lua"),
             str(work / "controller.lua"),
             str(work / "probe.lua"), "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract() -> tuple[bool, str]:
    controller = CONTROLLER.read_text(encoding="utf-8")
    coordination = COORDINATION.read_text(encoding="utf-8")
    needs = NEEDS.read_text(encoding="utf-8")
    dormant = DORMANT.read_text(encoding="utf-8")
    coordination_required = {
        "generic acquired appraisal": "SAO.Organization.pendingAppraisals(id)",
        "registered owner appraisal": "SAO.Communication.actorAppraisal(",
    }
    controller_required = {
        "water acquisition": "SAO.Needs.collectStoredWater",
        "water handover": "SAO.Needs.shareDrinkWith",
        "arrival completion": "SAO.Organization.completeArrival(",
        "rendezvous work family": 'plan.kind == "rendezvous-holding"',
    }
    for name, anchor in coordination_required.items():
        if anchor not in coordination:
            return False, f"coordination owner lacks {name}"
    for name, anchor in controller_required.items():
        if anchor not in controller:
            return False, f"controller lacks {name}"
    if "function N.collectStoredWater" not in needs or "context or" not in needs:
        return False, "water transfer does not retain coordinated context"
    if ("SAO.Coordination.appraisePending(id, nil, \"dormant\"" not in dormant
            or '"dormant-encounter"' not in dormant):
        return False, "dormant appraisal/return channel is absent"
    return True, "generic appraisal, material and arrival owners are wired"


def main() -> int:
    print("=" * 74)
    print("EXTERNAL LIFE COORDINATION")
    print("=" * 74)
    required = [ORG, COMM, GRAPH, COORDINATION, CONTROLLER, NEEDS, DORMANT,
                RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    installed = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 194 SKIPPED: installed game VM or JDK absent")
        return 0
    static_ok, detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL")
          + " (" + detail + ")")
    built, detail = compile_runner()
    if not built:
        print("  FAULT: runner compile failed " + detail[-1000:])
        return 1
    org = ORG.read_text(encoding="utf-8-sig")
    comm = COMM.read_text(encoding="utf-8-sig")
    coordination = COORDINATION.read_text(encoding="utf-8-sig")
    controller = CONTROLLER.read_text(encoding="utf-8-sig")
    value, output = run_probe(org, comm, coordination, controller)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")
    controls = [
        ("acquisition required", "organization",
         "local reception = row and row.receptions and row.receptions[key] or nil",
         "local reception = row and row.receptions and row.receptions[key] or { at = 0 }"),
        ("address required", "organization",
         "or process.originatorId ~= fromId or not row or row.addressed ~= true",
         "or process.originatorId ~= fromId or false"),
        ("arrived route required", "organization",
         'if not matched or matched.status ~= "arrived"',
         "if not matched or false"),
        ("arrival exact once", "organization",
         "local prior = Org.workReceipts[key]\n    if prior then",
         "local prior = nil\n    if prior then"),
        ("pending route reconstruction", "controller",
         'and not runtime.coordinationRoute then',
         'and false then'),
        ("shared dormant appraisal owner", "coordination",
         "for _, request in ipairs(SAO.Organization.pendingAppraisals(id)) do",
         "for _, request in ipairs({}) do"),
    ]
    controls_ok = True
    sources = {"organization": org, "coordination": coordination,
               "controller": controller}
    for name, target, old, new in controls:
        if sources[target].count(old) != 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutated = sources[target].replace(old, new, 1)
        mutant_value, _ = run_probe(
            mutated if target == "organization" else org,
            comm, mutated if target == "coordination" else coordination,
            mutated if target == "controller" else controller)
        if not any(result == "false" for result in verdicts(mutant_value).values()):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (six production controls)")
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + output[-2500:].replace("\n", " "))
        return 1
    print("  194) external people acquire and appraise current matters; water and "
          "exact arrival work retain revision, receipt and reload boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
