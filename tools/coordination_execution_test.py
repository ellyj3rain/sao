#!/usr/bin/env python3
"""Border 197: accepted material work executes through production owners.

This installed-Kahlua probe joins the seams that the earlier borders verify in
isolation.  A delivered acceptance enters the real Controller, Needs and
SourceUse admission path; only a witnessed native transfer changes the durable
commitment to carrying; Locomotion arrival remains short of delivery; and the
real Handover action alone completes it.  Release and stopped-handover paths
prove failed and partial outcomes cannot strand an exact pending receipt.
"""
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
NEEDS = LUA / "client/SAO_Needs.lua"
SOURCE_USE = LUA / "client/SAO_SourceUse.lua"
PROVISIONING = LUA / "shared/SAO_Provisioning.lua"
HANDOVER = LUA / "shared/SAO_Handover.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
WORLD_SOURCES = LUA / "shared/SAO_WorldSources.lua"
CHECK = ROOT / "tools/check.sh"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


PRELUDE = r'''
_G.__now = 100
_G.__stores = { SurvivorAwareness_Graph = { schema=3,
  branching={patterns={},offices={}},
  organization={organizations={},offices={},claims={},decisions={}},
  settlement={bases={}},
  material={stores={},reconciliations={},sourceOwners={}},
  communication={messages={}}, player={claims={}}, migrations={} } }
_G.__people, _G.__bodies = {}, {}
_G.__queue, _G.__pending = {}, {}
_G.__sourceSequence, _G.__resultSequence = 0, 0
_G.__sourceReservations, _G.__sourceResults = {}, {}
_G.__routeStatus, _G.__routeBody = 'none', nil

ModData = { getOrCreate=function(key)
  __stores[key]=__stores[key] or {}; return __stores[key]
end }
Events = setmetatable({}, { __index=function(t,key)
  local slot={Add=function() end,Remove=function() end}
  rawset(t,key,slot); return slot
end })
SandboxVars = { SurvivorAwareness={ Material=false, Settlement=false } }
getSpecificPlayer = function() return nil end

local function inventory(id)
  return { id=id }
end
local function body(id, x)
  local value={ id=id, x=x or 0, y=0, z=0,
    inventory=inventory('inventory:'..id) }
  function value:getModData() return { SAOPersonId=self.id } end
  function value:getInventory() return self.inventory end
  function value:getX() return self.x end
  function value:getY() return self.y end
  function value:getZ() return self.z end
  __bodies[id]=value
  return value
end
function makeItem(id, fullType, container)
  local value={ id=id, fullType=fullType, container=container }
  function value:getID() return self.id end
  function value:getFullType() return self.fullType end
  function value:getType() return self.fullType end
  function value:getContainer() return self.container end
  function value:setContainer(nextContainer) self.container=nextContainer end
  return value
end
_G.__sourceContainer=inventory('world-source')
for index,id in ipairs({'origin','worker','worker2'}) do
  __people[id]={ id=id, forename=id, surname='Border', dead=false,
    profile={frozen='private'} }
  body(id,index-1)
end
__people.worker.bodyOwner='ZAO'
__people.worker2.bodyOwner='ZAO'

SAO = {
  History={ countyHours=function() return __now end,
    ticks=function() return math.floor(__now*60) end },
  Log={ line=function() end },
  Identity={ get=function(id) return __people[tostring(id)] end },
  Body={ active={origin=__bodies.origin}, foreign={},
    get=function(id) return __bodies[tostring(id)] end,
    hasRepresentation=function(id) return __bodies[tostring(id)]~=nil end },
  Controller={ agents={} },
  Perception={ EARSHOT=10 },
  Standing={
    groupOf=function() return nil end,
    trust=function() return .5 end,
    isHostileTo=function() return false end,
    mayAttemptBelieved=function() return true end,
    mayTakeCurrent=function() return true end,
    provisioningContextAt=function() return 'personal',nil,nil end,
  },
}

ISTimedActionQueue={
  add=function(action)
    __queue[action]=true; __lastAction=action
    if action and action.character then __pending[action.character]=true end
  end,
  hasAction=function(action) return __queue[action]==true end,
  clear=function(character)
    for action in pairs(__queue) do
      if action.character==character then __queue[action]=nil end
    end
    __pending[character]=false
  end,
}
ISInventoryTransferAction={}
function ISInventoryTransferAction:derive(_)
  local child={}; child.__index=child
  setmetatable(child,{__index=self}); return child
end
function ISInventoryTransferAction.new(self, character, item, source, destination)
  local action={ character=character,item=item,sourceInventory=source,
    destinationInventory=destination }
  setmetatable(action,{__index=self}); return action
end
function ISInventoryTransferAction.isValid(self)
  return self and self.character~=nil and self.item~=nil
    and self.sourceInventory~=nil and self.destinationInventory~=nil
    and self.item:getContainer()==self.sourceInventory
end
function ISInventoryTransferAction.transferItem(self,item)
  item:setContainer(self.destinationInventory); return true
end
function ISInventoryTransferAction.stop(_) return true end
ISEatFoodAction={ complete=function() return true end,
  stop=function() return true end }
function ISEatFoodAction:new(character,item,amount)
  return setmetatable({character=character,item=item,amount=amount},{__index=self})
end
ISDrinkFluidAction={ complete=function() return true end,
  stop=function() return true end }
function ISDrinkFluidAction:new(character,item,amount)
  return setmetatable({character=character,item=item,amount=amount},{__index=self})
end

SAOJavaBridge={
  canConverseNow=function(_,a,b,_) return a~=nil and b~=nil end,
  findFoodSource=function(_,_,_) return '0:0:0:crate' end,
  foodSourceWithinReach=function() return true end,
  foodSourceItem=function() return __sourceItem end,
  foodSourceContainer=function() return __sourceContainer end,
  bindWorldSourceAction=function()
    return 'BOUND:0:0:0'
  end,
  bindWorldStoreAction=function() return 'BOUND:0:0:0' end,
  worldSourceActionItem=function() return __sourceItem end,
  worldSourceActionContainer=function() return __sourceContainer end,
  worldSourceActionPermissionContainer=function() return __sourceContainer end,
  worldSourceActionOriginContainer=function(_,body) return body:getInventory() end,
  containerAccessibleNow=function() return true end,
  worldTransferPosition=function() return 'AT:0:0:0' end,
  carriedWorldSourceItem=function(_,body,itemId,itemType)
    if __sourceItem and tostring(__sourceItem:getID())==tostring(itemId)
        and __sourceItem:getFullType()==itemType
        and __sourceItem:getContainer()==body:getInventory() then
      return __sourceItem
    end
    return nil
  end,
  observeWorldChunk=function() return 'snapshot' end,
  clearWorldSourceAction=function() end,
  hasPendingActions=function(_,body) return __pending[body]==true end,
  findSpareFood=function(_,body)
    if __sourceItem and __sourceItem:getContainer()==body:getInventory() then
      return __sourceItem
    end
    return nil
  end,
  grantXP=function() return true end,
  canWitnessWorldTransfer=function() return false end,
}

local function copyReceipt(receipt)
  local out={}
  for key,value in pairs(receipt) do
    if key~='acknowledgements' then out[key]=value end
  end
  out.acknowledgements={}
  return out
end
local function publishSource(reservation,status,detail)
  reservation.status=status
  __resultSequence=__resultSequence+1
  local receipt={ reservationId=reservation.id,actorId=reservation.actorId,
    placeId='fixture-place',placeX=0,placeY=0,placeZ=0,
    placeMinX=0,placeMinY=0,placeMaxX=2,placeMaxY=2,
    sourceId=reservation.sourceId,sourceFingerprint=reservation.fingerprint,
    sourceKind='container',sourceX=0,sourceY=0,sourceZ=0,
    itemId=reservation.itemId,itemType=reservation.itemType,
    operation=reservation.operation,category=reservation.category,
    provisioningContext='personal',materialProjectionEnabled=false,
    processId=reservation.processId,
    processRevision=reservation.processRevision,
    commitmentId=reservation.commitmentId,
    status=status,detail=detail,at=__now,order=__resultSequence,
    preRevision='r1',postRevision='r2',acknowledgements={} }
  __sourceResults[reservation.id]=receipt
  local rec=SAO.Identity.get(reservation.actorId)
  if rec and rec.worldSourceReservation==reservation.id then
    rec.worldSourceReservation=nil
  end
  return receipt
end
SAO.WorldSources={
  transferOptions=function()
    return {options={{id='exact-source',parameters={sourceId='fixture'}}}}
  end,
  beginTransfer=function(id,body,category,admission,item,container,operation,_)
    __sourceSequence=__sourceSequence+1
    local rid='R'..tostring(__sourceSequence)
    local reservation={ id=rid,actorId=tostring(id),status='reserved',
      phase='offered',category=category,admission=admission,
      operation=operation,sourceId='C:fixture:'..tostring(__sourceSequence),
      fingerprint='fp:'..tostring(__sourceSequence),revision='r1',
      itemId=tostring(item:getID()),itemType=item:getFullType(),
      sourceX=0,sourceY=0,sourceZ=0,sourceKind='container',
      placeId='fixture-place',placeX=0,placeY=0,placeZ=0,
      placeMinX=0,placeMinY=0,placeMaxX=2,placeMaxY=2 }
    __sourceReservations[rid]=reservation
    SAO.Identity.get(id).worldSourceReservation=rid
    return reservation
  end,
  reservation=function(id) return __sourceReservations[tostring(id)] end,
  pendingActionFor=function(id)
    local rec=SAO.Identity.get(id)
    local reservation=rec and __sourceReservations[rec.worldSourceReservation]
    return reservation and reservation.status=='reserved' and reservation or nil
  end,
  setPhase=function(id,actor,phase)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.actorId~=tostring(actor) then return false end
    reservation.phase=phase; return true
  end,
  prepareActionPre=function() return true end,
  parse=function(_) return {header={cx=0,cy=0}} end,
  applySnapshot=function() return true end,
  reconcileActionSnapshot=function(id,actor,_,_)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.actorId~=tostring(actor) then return false end
    reservation.postRevision='r2'; return true
  end,
  carriedTransferMatches=function() return true end,
  markTransferred=function(id,actor)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.actorId~=tostring(actor) then return false end
    reservation.transferProven=true; return true
  end,
  recordTransferObservation=function() return true end,
  markNative=function(id,actor,status,quantity,detail)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.actorId~=tostring(actor) then return false end
    reservation.phase='native-complete'; reservation.nativeStatus=status
    reservation.actualQuantity=quantity; reservation.nativeDetail=detail
    return true
  end,
  finishAction=function(id,actor)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.actorId~=tostring(actor)
        or reservation.phase~='native-complete' then return nil end
    return publishSource(reservation,reservation.nativeStatus,
      reservation.nativeDetail)
  end,
  release=function(id,reason)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.status~='reserved' then return false end
    publishSource(reservation,'released',tostring(reason or 'interrupted'))
    return true
  end,
  failAction=function(id,actor,reason)
    local reservation=__sourceReservations[tostring(id)]
    if not reservation or reservation.actorId~=tostring(actor)
        or reservation.status~='reserved' then return false end
    publishSource(reservation,'conflict',tostring(reason or 'failed'))
    return true
  end,
  completedResults=function(consumer,_)
    local out={}
    if consumer~='provisioning' then return out end
    for _,receipt in pairs(__sourceResults) do
      if not receipt.acknowledgements.provisioning
          and (receipt.status=='completed' or receipt.commitmentId) then
        out[#out+1]=copyReceipt(receipt)
      end
    end
    table.sort(out,function(a,b) return a.order<b.order end)
    return out
  end,
  acknowledgeResult=function(id,consumer,reason)
    local receipt=__sourceResults[tostring(id)]
    if not receipt or consumer~='provisioning' then return false end
    receipt.acknowledgements.provisioning=
      receipt.acknowledgements.provisioning or {at=__now,reason=reason}
    return true
  end,
  resultAcknowledged=function(id,consumer)
    local receipt=__sourceResults[tostring(id)]
    return receipt and receipt.acknowledgements[consumer]~=nil or false
  end,
  pendingProjectionChanges=function() return {} end,
  acknowledgeProjectionChange=function() return true end,
}

SAO.Locomotion={ jobs={} }
function SAO.Locomotion.order(id,body,x,y,z)
  SAO.Locomotion.jobs[tostring(id)]={body=body,goal={x=x,y=y,z=z}}
  __routeBody=body; __routeStatus='moving'; return true
end
function SAO.Locomotion.tick(id)
  local job=SAO.Locomotion.jobs[tostring(id)]
  if job and __routeStatus=='done:arrived' then
    job.body.x,job.body.y,job.body.z=job.goal.x,job.goal.y,job.goal.z
  end
end
function SAO.Locomotion.status(_) return __routeStatus end
function SAO.Locomotion.cancel(id)
  SAO.Locomotion.jobs[tostring(id)]=nil; __routeStatus='none'
end
'''


PROBE = r'''(function()
  local checks={}
  local function check(name,value)
    checks[#checks+1]=name..'='..tostring(value==true)
  end
  local function outcomes(commitment)
    return #(commitment and commitment.work and commitment.work.outcomes or {})
  end
  SAO.GraphPersistence.bind()
  SAO.Communication.registerExecutionOwner('ZAO',{
    bodyFor=function(id) return __bodies[tostring(id)] end,
    snapshot=function() return {bodyOwner='ZAO',represented=true,
      currentActivity='idle',canAcquire=true,canCarry=true,canDeliver=true,
      canExecute=true} end,
  })
  local function accepted(actor,suffix)
    __bodies.origin.x,__bodies[actor].x=0,1
    local process=SAO.Organization.raiseMatter('origin','food-delivery',nil,{
      intentKey='food:'..suffix,destinationRequired=true,
      destination={minX=19,minY=0,maxX=21,maxY=1,z=0},
      requiredCapabilities={acquire=true,carry=true,deliver=true},
      scope={action='deliver-material',category='food',quantity=1},
    },{actor},{need=.8})
    local message=SAO.Communication.deliverProcessProposal(
      'origin',actor,process.id,nil,{distance=1})
    SAO.Organization.appraiseMatter(process.id,actor,{
      owner='border197.private',executor='ZAO.Driver',bodyOwner='ZAO',
      currentActivity='idle',canAcquire=true,canCarry=true,canDeliver=true,
      canExecute=true,choice='accept',relationship=.7,ownNeed=.1,
      destinationKnown=true,constraints={represented=true,
        executionOwnerAvailable=true,ownNeedAvailable=true} })
    local returned=SAO.Communication.deliverPendingResponses(
      actor,'origin',nil,{distance=1})
    return process,SAO.Organization.activeCommitment(actor,'food-delivery'),
      message,returned
  end
  local function finishAcquisition(actor,itemId,suffix)
    __sourceItem=makeItem(itemId,'Base.Apple',__sourceContainer)
    local process,commitment,message,returned=accepted(actor,suffix)
    local owned,status=SAO.Controller.advanceExternalCoordination(
      actor,__bodies[actor],'ZAO','idle')
    local admission=commitment.work.pendingReceiptId
    check(suffix..'_delivered_acceptance_enters_source_owner',message~=nil
      and returned==1 and owned==true and status=='TAKE'
      and admission~=nil and commitment.work.acquiredAt==nil
      and commitment.status=='in-progress' and commitment.work.phase=='admitted'
      and __sourceItem:getContainer()==__sourceContainer)
    local action=__lastAction
    action:transferItem(__sourceItem)
    __queue[action]=nil; __pending[__bodies[actor]]=false
    local settled,settledStatus=SAO.Controller.advanceExternalCoordination(
      actor,__bodies[actor],'ZAO','idle')
    check(suffix..'_native_acquisition_becomes_carrying_once',settled==true
      and settledStatus=='source:completed'
      and commitment.work.acquisitionReceiptId==admission
      and commitment.work.acquiredAt~=nil
      and commitment.work.phase=='carrying'
      and __sourceItem:getContainer()==__bodies[actor]:getInventory())
    return process,commitment,__sourceItem
  end

  local process,commitment,item=finishAcquisition('worker',1,'complete')
  local processId,commitmentId=process.id,commitment.id
  SAO.Organization.processes,SAO.Organization.processOrder={},{ }
  SAO.Organization.processMeta,SAO.Organization.workReceipts={sequence=0},{}
  SAO.Controller.coordinationRuntime={}
  SAO.GraphPersistence.bind()
  commitment=SAO.Organization.commitment(commitmentId)
  check('carrying_survives_graph_rebind',commitment~=nil
    and commitment.processId==processId and commitment.work.phase=='carrying'
    and commitment.work.acquisitionReceiptId~=nil)

  __bodies.origin.x,__bodies.worker.x=20,0
  local routed,routeStatus=SAO.Controller.advanceExternalCoordination(
    'worker',__bodies.worker,'ZAO','idle')
  local route=commitment.work.routeAttempts[#commitment.work.routeAttempts]
  check('carrying_uses_locomotion_without_claiming_delivery',routed==true
    and routeStatus=='route' and route and route.phase=='carrying'
    and route.status=='pending' and commitment.status~='completed')
  __routeStatus='done:arrived'
  local arrived,arrivedStatus=SAO.Controller.advanceExternalCoordination(
    'worker',__bodies.worker,'ZAO','idle')
  check('locomotion_arrival_is_delivery_ready_not_completion',arrived==true
    and arrivedStatus=='arrived' and route.status=='arrived'
    and commitment.work.phase=='delivery-ready'
    and commitment.status~='completed')
  local handed,handoverStatus=SAO.Controller.advanceExternalCoordination(
    'worker',__bodies.worker,'ZAO','idle')
  local handoverId=commitment.work.pendingReceiptId
  local handover=handoverId and SAO.Handover.result(handoverId)
  check('handover_queue_is_admission_not_completion',handed==true
    and handoverStatus=='handover' and handover and handover.status=='pending'
    and commitment.status~='completed'
    and item:getContainer()==__bodies.worker:getInventory())
  local handoverAction=SAO.Handover._runtime[handoverId].action
  handoverAction:transferItem(item)
  local beforeReplay=outcomes(commitment)
  local replay,replayWhy=SAO.Organization.consumeHandoverResult(
    SAO.Handover.result(handoverId))
  SAO.Handover.reconcile(true)
  check('native_handover_completes_exactly_once',commitment.status=='completed'
    and commitment.work.phase=='completed'
    and commitment.work.deliveryReceiptId==handoverId
    and item:getContainer()==__bodies.origin:getInventory()
    and replay==true and replayWhy=='duplicate'
    and outcomes(commitment)==beforeReplay)

  __sourceItem=makeItem(2,'Base.Apple',__sourceContainer)
  local _,failed=accepted('worker2','release')
  local began,beginStatus=SAO.Controller.advanceExternalCoordination(
    'worker2',__bodies.worker2,'ZAO','idle')
  local failedReceipt=failed.work.pendingReceiptId
  local failedAction=__lastAction
  __queue[failedAction]=nil; __pending[__bodies.worker2]=false
  local released,releasedStatus=SAO.Controller.advanceExternalCoordination(
    'worker2',__bodies.worker2,'ZAO','idle')
  local stillPending=failed.work.pendingReceiptId==failedReceipt
  local consumed,pending=SAO.Provisioning.consumeCompleted(32)
  check('released_native_transfer_closes_failed_work_once',began==true
    and beginStatus=='TAKE' and released==true
    and releasedStatus=='source:released' and stillPending
    and consumed>=1 and pending==0 and failed.status=='failed'
    and failed.work.phase=='failed' and failed.work.pendingReceiptId==nil
    and SAO.WorldSources.resultAcknowledged(failedReceipt,'provisioning'))

  local _,partial,partialItem=finishAcquisition('worker2',3,'partial')
  __bodies.origin.x,__bodies.worker2.x=1,0
  local queued,queuedStatus=SAO.Controller.advanceExternalCoordination(
    'worker2',__bodies.worker2,'ZAO','idle')
  local partialHandover=partial.work.pendingReceiptId
  local partialAction=SAO.Handover._runtime[partialHandover].action
  partialAction:stop()
  check('stopped_native_handover_is_partial_not_completion',queued==true
    and queuedStatus=='handover' and partial.status=='interrupted'
    and partial.work.phase=='partial'
    and partialItem:getContainer()==__bodies.worker2:getInventory()
    and SAO.Handover.result(partialHandover).status=='interrupted')

  return table.concat(checks,',')
end)()'''


EXPECTED = {
    "complete_delivered_acceptance_enters_source_owner",
    "complete_native_acquisition_becomes_carrying_once",
    "carrying_survives_graph_rebind",
    "carrying_uses_locomotion_without_claiming_delivery",
    "locomotion_arrival_is_delivery_ready_not_completion",
    "handover_queue_is_admission_not_completion",
    "native_handover_completes_exactly_once",
    "released_native_transfer_closes_failed_work_once",
    "partial_delivered_acceptance_enters_source_owner",
    "partial_native_acquisition_becomes_carrying_once",
    "stopped_native_handover_is_partial_not_completion",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(overrides: dict[str, str] | None = None) -> tuple[str | None, str]:
    overrides = overrides or {}
    with tempfile.TemporaryDirectory(prefix="sao-coordination-execution-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        source_paths = {
            "organization": ORGANIZATION,
            "communication": COMMUNICATION,
            "needs": NEEDS,
            "source_use": SOURCE_USE,
            "provisioning": PROVISIONING,
            "handover": HANDOVER,
            "controller": CONTROLLER,
        }
        generated: dict[str, pathlib.Path] = {}
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        for name, path in source_paths.items():
            target = work / f"{name}.lua"
            target.write_text(overrides.get(name,
                              path.read_text(encoding="utf-8-sig")),
                              encoding="utf-8")
            generated[name] = target
        probe = work / "probe.lua"
        probe.write_text("__result = " + PROBE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(generated["organization"]),
             str(generated["communication"]), str(GRAPH),
             str(generated["needs"]), str(generated["source_use"]),
             str(generated["provisioning"]), str(generated["handover"]),
             str(generated["controller"]), str(probe), "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract() -> tuple[bool, str]:
    controller = CONTROLLER.read_text(encoding="utf-8")
    source_use = SOURCE_USE.read_text(encoding="utf-8")
    provisioning = PROVISIONING.read_text(encoding="utf-8")
    handover = HANDOVER.read_text(encoding="utf-8")
    world = WORLD_SOURCES.read_text(encoding="utf-8")
    check = CHECK.read_text(encoding="utf-8")
    required = (
        "SAO.Needs.collectNearby(id, body, 20, 2" in controller,
        "SAO.Needs.shareFoodWith" in controller,
        "SAO.Organization.noteRoute(commitment.id" in controller,
        "SAO.SourceUse.tick(id, body)" in controller,
        "SAO.Organization.noteWorkAdmission" in source_use,
        "SAO.Provisioning.consumeCompleted" in source_use,
        "and not coordinated" in provisioning,
        'or "coordination-result-delivered"' in provisioning,
        "SAO.Organization.noteWorkAdmission" in handover,
        "SAO.Organization.consumeHandoverResult" in handover,
        'if (receipt.status == "completed" or coordinated' in world,
        "tools/coordination_execution_test.py" in check,
    )
    return (all(required), "Controller, native owners and terminal replay are wired")


def main() -> int:
    print("=" * 74)
    print("PRODUCTION COORDINATION ACQUISITION, CARRYING AND DELIVERY")
    print("=" * 74)
    required = [ORGANIZATION, COMMUNICATION, GRAPH, NEEDS, SOURCE_USE,
                PROVISIONING, HANDOVER, CONTROLLER, WORLD_SOURCES, CHECK,
                RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    installed = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 197 SKIPPED: installed game VM or JDK absent")
        return 0
    static_ok, detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL")
          + " (" + detail + ")")
    built, detail = compile_runner()
    if not built:
        print("  FAULT: runner compile failed " + detail[-1000:])
        return 1
    value, output = run_probe()
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")

    sources = {
        "organization": ORGANIZATION.read_text(encoding="utf-8-sig"),
        "source_use": SOURCE_USE.read_text(encoding="utf-8-sig"),
        "provisioning": PROVISIONING.read_text(encoding="utf-8-sig"),
        "handover": HANDOVER.read_text(encoding="utf-8-sig"),
        "controller": CONTROLLER.read_text(encoding="utf-8-sig"),
    }
    controls = [
        ("queue admission is not acquisition", "organization",
         'workEvent(commitment, "admitted", { owner = ownerKind,',
         'workEvent(commitment, "carrying", { owner = ownerKind,'),
        ("source completion reaches result consumer", "source_use",
         "pcall(SAO.Provisioning.consumeCompleted, 32)",
         "pcall(function() end)"),
        ("arrival is not delivery", "organization",
         'or "delivery-ready"', 'or "completed"'),
        ("terminal source refusal is admitted", "provisioning",
         "            and not coordinated)", "            and true)"),
    ]
    controls_ok = True
    for name, target, old, new in controls:
        if sources[target].count(old) != 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutated = sources[target].replace(old, new, 1)
        mutant_value, _ = run_probe({target: mutated})
        mutant_found = verdicts(mutant_value)
        if (mutant_value is not None
                and set(mutant_found) == EXPECTED
                and not any(result == "false"
                            for result in mutant_found.values())):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (four joined-owner controls)")
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + output[-3000:].replace("\n", " "))
        return 1
    print("  197) delivered acceptance executes exact acquisition, carrying and "
          "handover; release and interruption close as failed/partial")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
