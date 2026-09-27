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

import argparse
import hashlib
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
PERCEPTION = LUA / "shared/SAO_Perception.lua"
CHECK = ROOT / "tools/check.sh"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
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
_G.__orders, _G.__sourceX, _G.__within = 0, 0, true
_G.__known, _G.__permitted = {}, true
_G.__sourceCache = true
_G.__visible, _G.__sightCalls = true, 0

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
_G.replaceBody=function(id,x) return body(id,x) end
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
  Perception={ EARSHOT=10,knownPlaces=function(id) return __known[id] or {} end },
  Standing={
    groupOf=function() return nil end,
    trust=function() return .5 end,
    isHostileTo=function() return false end,
    mayAttemptBelieved=function() return __permitted end,
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
  -- Controlled native receiver: actual scanner geometry is covered by the
  -- installed-engine perception/orienting gates. This probe varies its answer.
  canSeePersonNow=function(_,a,b,range)
    __sightCalls=__sightCalls+1
    if not __visible or not a or not b or a.z~=b.z then return false end
    local dx,dy=a.x-b.x,a.y-b.y
    local reach=math.min(14,range)
    return dx*dx+dy*dy<=reach*reach
  end,
  findFoodSource=function(_,_,_)
    __sourceCache=true;return tostring(__sourceX)..':0:0:crate'
  end,
  foodSourceWithinReach=function() return __sourceCache and __within end,
  resourceApproach=function(_,_,_,x,y,z)
    return 'AT:'..tostring(x)..':'..tostring(y)..':'..tostring(z)
  end,
  foodSourceItem=function() return __sourceCache and __sourceItem or nil end,
  foodSourceContainer=function() return __sourceCache and __sourceContainer or nil end,
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
  __orders=__orders+1
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
  local function empty(values)
    for _ in pairs(values or {}) do return false end
    return true
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
    __bodies.origin.y,__bodies[actor].y=0,0
    __bodies.origin.z,__bodies[actor].z=0,0
    __visible=true
    SAO.Perception.sawPerson(actor,'origin',0,0,SAO.History.ticks(),'origin',1)
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
    local commitment=nil
    for _,candidate in pairs(process.commitments or {}) do
      if candidate.actorId==actor then commitment=candidate;break end
    end
    return process,commitment,message,returned
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

  -- Reproduce native02: accepted request -> real collectNearby FORAGE route
  -- -> native failure without any acquisition. Retry remains the same goal.
  __within=false;__sourceX=12;__sourceItem=makeItem(4,'Base.Apple',__sourceContainer)
  __known.worker={oldHome={at=1,source='lived-place',sourceFacts={cabinet={
    x=12,y=0,z=0,revision='old-r1',fingerprint='cabinet',state='available',access='open'}}},
    rememberedAnchor={at=0,sourceFacts={cabinet={x=12,y=0,z=0,revision='old-r0',
    fingerprint='cabinet',state='available',access='open'}}}}
  local retryProcess,retry=accepted('worker','route-retry')
  SAO.Perception.beliefs.worker.known=__known.worker
  local function advanceRetry()
    return SAO.Controller.advanceExternalCoordination('worker',__bodies.worker,'ZAO','idle')
  end
  local firstOrders=__orders
  local beganRoute,firstStatus=advanceRetry()
  local first=retry.work.routeAttempts[1]
  check('private_old_source_still_admits_attempt',beganRoute==true and firstStatus=='FORAGE'
    and first and first.retryEvidence and first.retryEvidence.knownSources:find('old-r1',1,true)~=nil)
  check('private_duplicate_source_facts_are_stable',first and first.retryEvidence
    and first.retryEvidence.knownSources:find('old-r0',1,true)~=nil
    and first.retryEvidence.knownSources:find('old-r1',1,true)~=nil)
  __routeStatus='done:failed';advanceRetry()
  check('failed_attempt_retains_accepted_goal',first and first.status=='interrupted'
    and first.detail=='failed' and retry.status=='paused'
    and retry.work.acquiredAt==nil and retry.work.endedAt==nil
    and empty(retry.work.sourceReceipts)
    and SAO.Organization.activeCommitment('worker','food-delivery')==retry
    and SAO.Organization.workReceipts['route:'..first.id]~=nil)
  local beforeDuplicate=outcomes(retry)
  local duplicate=SAO.Organization.routeOutcome(retry.id,'interrupted','failed')
  check('failed_attempt_receipt_is_consumed_once',duplicate==false and outcomes(retry)==beforeDuplicate)
  local held,heldReason=advanceRetry()
  check('route_backoff_prevents_immediate_restart',held==false and heldReason=='route-backoff'
    and __orders==firstOrders+1 and #retry.work.routeAttempts==1)

  local retryId=retry.id
  SAO.Organization.processes,SAO.Organization.processOrder={},{ }
  SAO.Organization.processMeta,SAO.Organization.workReceipts={sequence=0},{}
  SAO.Controller.coordinationRuntime={};SAO.GraphPersistence.bind()
  retry=SAO.Organization.commitment(retryId)
  held,heldReason=advanceRetry()
  check('route_backoff_survives_graph_rebind',retry.status=='paused'
    and held==false and heldReason=='route-backoff' and __orders==firstOrders+1)
  for index=2,3 do
    __now=(retry.work.routeRetryAt or __now)+.001
    advanceRetry();__routeStatus='done:failed';advanceRetry()
  end
  __now=(retry.work.routeRetryAt or __now)+.001
  local attemptsBefore=#retry.work.routeAttempts
  local ordersBefore=__orders
  for index=1,4 do advanceRetry() end
  check('equivalent_failures_wait_for_changed_evidence',#retry.work.routeAttempts==3
    and #retry.work.routeAttempts==attemptsBefore and __orders==ordersBefore
    and retry.status=='paused' and retry.work.pauseReason=='route-awaits-changed-evidence')
  local sameNativeTile=SAO.Organization.routeMayStart(retry.id,12.4,.4,0,'acquiring',
    retry.work.routeAttempts[1].retryEvidence)
  check('fractional_target_jitter_does_not_reset_failures',sameNativeTile==false)
  __known.worker.oldHome.at=__now*60
  advanceRetry()
  check('unchanged_fact_rescan_does_not_reset_failures',__orders==ordersBefore)
  __known.worker.oldHome.sourceFacts.cabinet.revision='old-r2'
  __permitted=false;advanceRetry()
  check('retry_rechecks_current_permission',__orders==ordersBefore and retry.status=='paused')
  __permitted=true
  local changed,changedStatus=advanceRetry()
  local latest=retry.work.routeAttempts[#retry.work.routeAttempts]
  check('changed_private_source_reopens_same_goal',changed==true and changedStatus=='FORAGE'
    and __orders==ordersBefore+1 and #retry.work.routeAttempts==4
    and latest.retryEvidence.knownSources:find('old-r2',1,true)~=nil
    and retry.id==retryId and retry.work.acquiredAt==nil)
  __routeStatus='done:failed';advanceRetry()
  __now=(retry.work.routeRetryAt or __now)+.001
  __sourceX=16
  changed,changedStatus=advanceRetry()
  check('different_selected_source_remains_eligible',changed==true and changedStatus=='FORAGE'
    and retry.work.routeAttempts[#retry.work.routeAttempts].x==16
    and retry.id==retryId and retry.status~='completed')
  SAO.Organization.withdrawMatter(retryProcess.id,'origin','request-no-longer-needed',{})
  local stopped,stopReason=advanceRetry()
  check('explicit_withdrawal_stops_retained_route',stopped==true and stopReason=='work-ended'
    and retry.status=='withdrawn' and SAO.Locomotion.jobs.worker==nil)

  -- Carrying failures retain the measured acquisition, but confer no delivery.
  __within=true;__sourceX=0
  local carryProcess,carry=finishAcquisition('worker',5,'carryretry')
  __bodies.origin.x,__bodies.worker.x=20,0
  ordersBefore=__orders;__permitted=false;advanceRetry()
  check('carrying_route_rechecks_permission',__orders==ordersBefore and carry.status=='paused')
  __permitted=true
  advanceRetry();__routeStatus='done:failed';advanceRetry()
  check('carrying_route_failure_preserves_cargo_proof',carry.status=='paused'
    and carry.work.acquisitionReceiptId~=nil and carry.work.acquiredAt~=nil
    and carry.work.deliveryReceiptId==nil and carry.work.endedAt==nil)
  __now=(carry.work.routeRetryAt or __now)+.001
  SAO.Organization.reviseMatter(carryProcess.id,'origin',{
    scope={category='food',quantity=2},destination={minX=19,minY=0,maxX=21,maxY=1,z=0}}, {})
  ordersBefore=__orders;advanceRetry()
  check('supersession_cannot_resume_old_goal',carry.status=='superseded' and __orders==ordersBefore)
  local deathProcess,death=accepted('worker','dead')
  __within=false;__sourceX=12;advanceRetry()
  __people.worker.dead=true;SAO.Organization.releaseActor('worker','actor-dead')
  stopped,stopReason=advanceRetry()
  check('death_stops_retained_goal',death.status=='withdrawn' and stopReason=='work-ended'
    and SAO.Locomotion.jobs.worker==nil)

  -- The loaded FORAGE consumer runs updateMovement before the next decision.
  __people.worker.dead=false
  local loadedProcess,loaded=accepted('worker','loaded-route')
  local agent={state='IDLE',rec=__people.worker}
  local function advanceLoaded()
    return SAO.Controller.__coordinationProbeAdvance('worker',__bodies.worker,'SAO','idle',agent)
  end
  advanceLoaded();__routeStatus='done:failed'
  SAO.Controller.__coordinationProbeMovement('worker',agent,__bodies.worker)
  check('loaded_forage_failure_preserves_goal',loaded.status=='paused' and agent.state=='IDLE'
    and agent.coordinationRoute==nil and loaded.work.acquiredAt==nil
    and loaded.work.routeAttempts[1].status=='interrupted')
  ordersBefore=__orders;advanceLoaded()
  check('loaded_forage_respects_backoff',__orders==ordersBefore and agent.state=='IDLE')
  __now=(loaded.work.routeRetryAt or __now)+.001
  local resumed,resumedStatus=advanceLoaded()
  check('loaded_forage_resumes_same_commitment',resumed==true and resumedStatus=='FORAGE'
    and agent.state=='FORAGE' and agent.coordinationCommitment==loaded.id
    and #loaded.work.routeAttempts==2 and loaded.work.acquiredAt==nil)
  SAO.Organization.withdrawMatter(loadedProcess.id,'origin','no-longer-needed',{})
  SAO.Controller.__coordinationProbeMovement('worker',agent,__bodies.worker)
  check('loaded_withdrawal_cancels_route_owner',agent.state=='IDLE'
    and agent.coordinationCommitment==nil and SAO.Locomotion.jobs.worker==nil)

  __sourceItem=makeItem(6,'Base.Apple',__sourceContainer)
  local firstProcess,firstGoal=accepted('worker','first-paused')
  for index=1,3 do
    advanceRetry();__routeStatus='done:failed';advanceRetry()
    __now=(firstGoal.work.routeRetryAt or __now)+.001
  end
  local secondProcess,secondGoal=accepted('worker','second-executable')
  local secondAdvanced,secondStatus=advanceRetry()
  check('paused_goal_does_not_starve_other_accepted_work',secondAdvanced==true
    and secondStatus=='FORAGE' and firstGoal.status=='paused'
    and #firstGoal.work.routeAttempts==3 and secondGoal.status=='in-progress'
    and #secondGoal.work.routeAttempts==1)
  SAO.Controller.advanceExternalCoordination('worker',__bodies.worker,'ZAO','flee')
  check('competing_activity_pauses_actual_selected_goal',secondGoal.status=='paused'
    and secondGoal.work.pauseReason=='external-competing-activity'
    and firstGoal.work.pauseReason=='route-awaits-changed-evidence'
    and SAO.Locomotion.jobs.worker==nil)
  SAO.Organization.withdrawMatter(secondProcess.id,'origin','second-closed',{})
  __known.worker.oldHome.sourceFacts.cabinet.revision='old-r3'
  local revisited,revisitedStatus=advanceRetry()
  check('earlier_paused_goal_can_be_revisited',revisited==true and revisitedStatus=='FORAGE'
    and #firstGoal.work.routeAttempts==4 and firstGoal.status=='in-progress'
    and firstGoal.work.acquiredAt==nil)
  SAO.Organization.withdrawMatter(firstProcess.id,'origin','first-closed',{})
  advanceRetry()

  local pendingProcess,pendingGoal=accepted('worker','pending-reload')
  advanceRetry()
  local pendingRoute=pendingGoal.work.routeAttempts[1]
  SAO.Controller.coordinationRuntime={}
  __permitted=false;ordersBefore=__orders
  advanceRetry()
  check('pending_route_rechecks_permission_after_rebind',__orders==ordersBefore
    and pendingRoute.status=='interrupted' and pendingGoal.status=='paused')
  SAO.Organization.withdrawMatter(pendingProcess.id,'origin','pending-closed',{})
  __permitted=true

  local cacheProcess,cacheGoal=accepted('worker','native-cache-reload')
  advanceRetry()
  local cacheRoute=cacheGoal.work.routeAttempts[1]
  SAO.Controller.coordinationRuntime={}
  replaceBody('worker',1);__sourceCache=false
  local restored,restoredStatus=advanceRetry()
  check('pending_route_reuses_existing_attempt_after_rebind',restored==true
    and restoredStatus=='route' and #cacheGoal.work.routeAttempts==1
    and cacheGoal.work.routeAttempts[1].id==cacheRoute.id)
  __routeStatus='done:arrived';__within=true
  local atSource,atSourceStatus=advanceRetry()
  check('lost_native_cache_preserves_arrived_goal',atSource==true
    and atSourceStatus=='acquisition-queue-refused' and cacheRoute.status=='arrived'
    and cacheGoal.status=='paused' and cacheGoal.work.acquiredAt==nil)
  local reselected,reselectedStatus=advanceRetry()
  check('source_selection_rebinds_cache_without_inventing_transfer',reselected==true
    and reselectedStatus=='TAKE' and cacheGoal.work.pendingReceiptId~=nil
    and cacheGoal.work.acquiredAt==nil and __sourceCache
    and __sourceItem:getContainer()==__sourceContainer)


  -- Private requester targeting uses the same delivered proposal, actual
  -- acquisition and durable commitment as the retained C85 controls above.
  -- Only the native visibility/transfer receivers are controlled here.
  local shareFood=SAO.Needs.shareFoodWith
  local shareAttempts=0
  SAO.Needs.shareFoodWith=function(...)
    shareAttempts=shareAttempts+1
    return shareFood(...)
  end
  local depositChecks=0
  SAOJavaBridge.findNearbyContainer=function()
    depositChecks=depositChecks+1;return nil
  end
  local itemSequence=100
  local function carryingCase(label)
    itemSequence=itemSequence+1
    local actor='address-'..label
    __people[actor]={id=actor,forename=actor,surname='Border',dead=false,
      bodyOwner='ZAO',profile={frozen='private'}}
    replaceBody(actor,1)
    __bodies.origin.id='origin'
    __within=true;__sourceX=0;__permitted=true
    local process,goal,cargo=finishAcquisition(actor,itemSequence,'address_'..label)
    __bodies[actor].x,__bodies[actor].y=0,0
    return actor,process,goal,cargo
  end
  local function observe(actor,x,y)
    SAO.Perception.sawPerson(actor,'origin',x,y,SAO.History.ticks(),'origin',12)
  end
  local function advanceAddress(actor)
    return SAO.Controller.advanceExternalCoordination(actor,__bodies[actor],'ZAO','idle')
  end
  local function jobAt(actor,x,y,z)
    local job=SAO.Locomotion.jobs[actor]
    return job and job.goal.x==x and job.goal.y==y and job.goal.z==z
  end

  local actor,addressProcess,addressGoal,cargo=carryingCase('visible')
  __bodies.origin.x,__bodies.origin.y=13,2
  __bodies.origin.z,__bodies[actor].z=1,1
  observe(actor,12,1)
  local addressReceipt=addressGoal.work.acquisitionReceiptId
  local did,why=advanceAddress(actor)
  local addressRoute=addressGoal.work.routeAttempts[#addressGoal.work.routeAttempts]
  check('fresh_private_identity_routes_observed_xy_on_seen_floor',did==true and why=='route'
    and jobAt(actor,12,1,1) and addressRoute.x==12 and addressRoute.y==1
    and addressRoute.z==1 and addressGoal.work.deliveryReceiptId==nil
    and SAO.Perception.believedPerson(actor,'origin').x==12)

  SAO.Controller.coordinationRuntime={};SAO.Locomotion.cancel(actor)
  did,why=advanceAddress(actor)
  check('visible_pending_route_keeps_private_attempt_identity',did==true and why=='route'
    and jobAt(actor,12,1,1) and #addressGoal.work.routeAttempts==1
    and addressGoal.work.routeAttempts[1].id==addressRoute.id)

  -- The native cache disappears on load. Private memory and the accepted
  -- destination survive; the currently unseen body supplies neither XY nor Z.
  SAO.Perception.bindPersistentStore()
  SAO.Perception.beliefs={};SAO.Perception.bindPersistentStore()
  SAO.Organization.processes,SAO.Organization.processOrder={},{ }
  SAO.Organization.processMeta,SAO.Organization.workReceipts={sequence=0},{}
  SAO.Controller.coordinationRuntime={};SAO.Locomotion.cancel(actor)
  SAO.GraphPersistence.bind()
  addressGoal=SAO.Organization.commitment(addressGoal.id)
  __visible=false;__bodies.origin.x=70;__bodies.origin.z=4
  local beforeOrders=__orders
  did,why=advanceAddress(actor)
  check('pending_person_route_revalidates_after_reload',did==false
    and why=='route-destination-unavailable' and __orders==beforeOrders
    and addressRoute.status=='interrupted' and addressGoal.status=='paused'
    and addressGoal.work.acquisitionReceiptId==addressReceipt
    and addressGoal.work.deliveryReceiptId==nil and addressGoal.work.endedAt==nil)
  __now=(addressGoal.work.routeRetryAt or __now)+.001
  did,why=advanceAddress(actor)
  local fallback=addressGoal.work.routeAttempts[#addressGoal.work.routeAttempts]
  check('unseen_requester_uses_complete_received_address',did==true and why=='route'
    and jobAt(actor,20,.5,0) and fallback.id~=addressRoute.id
    and addressGoal.work.acquisitionReceiptId==addressReceipt)
  __bodies.origin.x,__bodies.origin.y,__bodies.origin.z=90,30,5
  beforeOrders=__orders
  advanceAddress(actor)
  check('unseen_moving_requester_cannot_redirect_owned_route',__orders==beforeOrders
    and jobAt(actor,20,.5,0) and #addressGoal.work.routeAttempts==2)
  -- A still-valid received destination remains authoritative even when a
  -- different nearby address becomes visible during reconstruction.
  __visible=true;__bodies.origin.x,__bodies.origin.y,__bodies.origin.z=13,2,1
  observe(actor,12,1)
  SAO.Controller.coordinationRuntime={};SAO.Locomotion.cancel(actor)
  did,why=advanceAddress(actor)
  check('received_pending_route_keeps_attempt_identity',did==true and why=='route'
    and jobAt(actor,20,.5,0) and #addressGoal.work.routeAttempts==2
    and addressGoal.work.routeAttempts[2].id==fallback.id)
  __visible=false;__bodies.origin.x,__bodies.origin.y,__bodies.origin.z=90,30,5
  __routeStatus='done:arrived';advanceAddress(actor)
  local attemptsAtAddress=#addressGoal.work.routeAttempts
  local sharesAtAddress=shareAttempts
  did,why=advanceAddress(actor)
  check('absent_requester_at_address_is_unresolved_not_delivery',did==false
    and why=='delivery-holder-unavailable' and shareAttempts==sharesAtAddress
    and addressGoal.work.deliveryReceiptId==nil and addressGoal.status~='completed'
    and cargo:getContainer()==__bodies[actor]:getInventory())
  __now=__now+24
  SAO.Controller.coordinationRuntime={};SAO.GraphPersistence.bind()
  beforeOrders=__orders;advanceAddress(actor)
  check('unresolved_address_retains_same_goal_across_day',__orders==beforeOrders
    and addressGoal.work.acquisitionReceiptId==addressReceipt
    and #addressGoal.work.routeAttempts==attemptsAtAddress
    and addressGoal.work.deliveryReceiptId==nil and addressGoal.work.endedAt==nil)
  __bodies.origin.x,__bodies.origin.y,__bodies.origin.z=21,0,0
  __visible=true;observe(actor,21,0)
  did,why=advanceAddress(actor)
  local received=addressGoal.work.pendingReceiptId
  local receivedAction=received and SAO.Handover._runtime[received]
  check('fresh_evidence_repairs_same_delivery_goal',did==true and why=='handover'
    and receivedAction and shareAttempts==sharesAtAddress+1
    and addressGoal.work.acquisitionReceiptId==addressReceipt
    and addressGoal.work.deliveryReceiptId==nil
    and cargo:getContainer()==__bodies[actor]:getInventory())
  if receivedAction then receivedAction.action:transferItem(cargo) end
  check('repaired_target_requires_exact_native_transfer',addressGoal.status=='completed'
    and addressGoal.work.deliveryReceiptId==received
    and cargo:getContainer()==__bodies.origin:getInventory())

  for _,label in ipairs({'absent','stale','told','false_sight','private_id',
      'native_id','actor_id','floor','future','invalid'}) do
    local a,_,goal,item=carryingCase(label)
    __bodies.origin.x=1;observe(a,1,0)
    local belief=SAO.Perception.believedPerson(a,'origin')
    if label=='absent' then SAO.Perception.beliefs[a].people={}
    elseif label=='stale' then belief.at=SAO.History.ticks()-41
    elseif label=='told' then belief.source='told'
    elseif label=='false_sight' then __visible=false
    elseif label=='private_id' then
      SAO.Perception.sawPerson(a,'origin',1,0,SAO.History.ticks(),'other-person',1)
    elseif label=='native_id' then __bodies.origin.id='different-shell'
    elseif label=='actor_id' then __bodies[a].id='different-actor'
    elseif label=='floor' then __bodies.origin.z=1
    elseif label=='future' then belief.at=SAO.History.ticks()+1
    elseif label=='invalid' then belief.x=math.huge end
    local sharesBefore=shareAttempts
    local advanced,status=advanceAddress(a)
    check(label..'_requester_cannot_admit_handover',advanced==true and status=='route'
      and jobAt(a,20,.5,0) and shareAttempts==sharesBefore
      and goal.work.pendingReceiptId==nil and goal.work.deliveryReceiptId==nil
      and item:getContainer()==__bodies[a]:getInventory())
  end

  local floorActor,_,floorGoal=carryingCase('destination_floor')
  __bodies[floorActor].x,__bodies[floorActor].y,__bodies[floorActor].z=20,.5,1
  __visible=false;local depositsBefore=depositChecks
  did,why=advanceAddress(floorActor)
  check('received_destination_floor_is_not_current_deposit_floor',did==true
    and why=='route' and jobAt(floorActor,20,.5,0)
    and depositChecks==depositsBefore and floorGoal.work.pendingReceiptId==nil)

  local missingActor,_,missingGoal=carryingCase('missing_body')
  observe(missingActor,12,0)
  local savedOrigin=__bodies.origin;__bodies.origin=nil;SAO.Body.active.origin=nil
  did,why=advanceAddress(missingActor)
  check('missing_native_requester_uses_received_destination',did==true and why=='route'
    and jobAt(missingActor,20,.5,0) and missingGoal.work.deliveryReceiptId==nil)
  __bodies.origin=savedOrigin;SAO.Body.active.origin=savedOrigin

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
    "private_old_source_still_admits_attempt",
    "private_duplicate_source_facts_are_stable",
    "failed_attempt_retains_accepted_goal",
    "failed_attempt_receipt_is_consumed_once",
    "route_backoff_prevents_immediate_restart",
    "route_backoff_survives_graph_rebind",
    "equivalent_failures_wait_for_changed_evidence",
    "fractional_target_jitter_does_not_reset_failures",
    "unchanged_fact_rescan_does_not_reset_failures",
    "retry_rechecks_current_permission",
    "changed_private_source_reopens_same_goal",
    "different_selected_source_remains_eligible",
    "explicit_withdrawal_stops_retained_route",
    "carryretry_delivered_acceptance_enters_source_owner",
    "carryretry_native_acquisition_becomes_carrying_once",
    "carrying_route_failure_preserves_cargo_proof",
    "carrying_route_rechecks_permission",
    "supersession_cannot_resume_old_goal",
    "death_stops_retained_goal",
    "loaded_forage_failure_preserves_goal",
    "loaded_forage_respects_backoff",
    "loaded_forage_resumes_same_commitment",
    "loaded_withdrawal_cancels_route_owner",
    "paused_goal_does_not_starve_other_accepted_work",
    "competing_activity_pauses_actual_selected_goal",
    "earlier_paused_goal_can_be_revisited",
    "pending_route_rechecks_permission_after_rebind",
    "pending_route_reuses_existing_attempt_after_rebind",
    "lost_native_cache_preserves_arrived_goal",
    "source_selection_rebinds_cache_without_inventing_transfer",
}

ADDRESS_CASES = {'visible', 'absent', 'stale', 'told', 'false_sight',
                 'private_id', 'native_id', 'actor_id', 'floor', 'future',
                 'invalid', 'destination_floor', 'missing_body'}
EXPECTED.update('address_' + label + suffix for label in ADDRESS_CASES
                for suffix in ('_delivered_acceptance_enters_source_owner',
                               '_native_acquisition_becomes_carrying_once'))
EXPECTED.update(label + '_requester_cannot_admit_handover' for label in
                ADDRESS_CASES - {'visible', 'destination_floor', 'missing_body'})
EXPECTED.update({
    'fresh_private_identity_routes_observed_xy_on_seen_floor',
    'pending_person_route_revalidates_after_reload',
    'visible_pending_route_keeps_private_attempt_identity',
    'unseen_requester_uses_complete_received_address',
    'unseen_moving_requester_cannot_redirect_owned_route',
    'received_pending_route_keeps_attempt_identity',
    'absent_requester_at_address_is_unresolved_not_delivery',
    'unresolved_address_retains_same_goal_across_day',
    'fresh_evidence_repairs_same_delivery_goal',
    'repaired_target_requires_exact_native_transfer',
    'received_destination_floor_is_not_current_deposit_floor',
    'missing_native_requester_uses_received_destination',
})



def compile_runner(output: pathlib.Path) -> tuple[bool, str]:
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(output), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(overrides: dict[str, str] | None = None,
              expected_failure: str | None = None) -> tuple[str | None, str]:
    overrides = overrides or {}
    with tempfile.TemporaryDirectory(prefix="sao-coordination-execution-") as tmp:
        work = pathlib.Path(tmp)
        built, detail = compile_runner(work)
        if not built:
            return None, "Private Kahlua runner compile failed: " + detail
        shutil.copy2(STDLIB, work / "stdlib.lua")
        source_paths = {
            "perception": PERCEPTION,
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
            source = overrides.get(name, path.read_text(encoding="utf-8-sig"))
            if name == "controller":
                if source.count("return Ctl\n") != 1:
                    return None, "Controller exposure seam differs"
                source = source.replace("return Ctl\n",
                    "Ctl.__coordinationProbeAdvance = advanceCoordination\n"
                    "Ctl.__coordinationProbeMovement = updateMovement\nreturn Ctl\n")
            target.write_text(source, encoding="utf-8")
            generated[name] = target
        probe = work / "probe.lua"
        probe_text = PROBE
        if expected_failure:
            probe_text = probe_text.replace("local function check(name,value)\n",
                "local function check(name,value)\n"
                f"    if name=='{expected_failure}' and value~=true then "
                "error('COORDINATION_CHECK:'..name) end\n", 1)
        probe.write_text("__result = " + probe_text, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(generated["perception"]),
             str(generated["organization"]),
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
    global ROOT, LUA, ORGANIZATION, COMMUNICATION, GRAPH, NEEDS, SOURCE_USE
    global PROVISIONING, HANDOVER, CONTROLLER, WORLD_SOURCES, PERCEPTION, CHECK, RUNNER
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=pathlib.Path, default=ROOT)
    parser.add_argument("--controller", type=pathlib.Path)
    args = parser.parse_args()
    ROOT = args.source_root.resolve()
    LUA = ROOT / "mod/42.20/media/lua"
    ORGANIZATION = LUA / "shared/SAO_Organization.lua"
    COMMUNICATION = LUA / "shared/SAO_Communication.lua"
    GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
    NEEDS = LUA / "client/SAO_Needs.lua"
    SOURCE_USE = LUA / "client/SAO_SourceUse.lua"
    PROVISIONING = LUA / "shared/SAO_Provisioning.lua"
    HANDOVER = LUA / "shared/SAO_Handover.lua"
    CONTROLLER = args.controller.resolve() if args.controller else LUA / "client/SAO_Controller.lua"
    WORLD_SOURCES = LUA / "shared/SAO_WorldSources.lua"
    PERCEPTION = LUA / "shared/SAO_Perception.lua"
    CHECK = ROOT / "tools/check.sh"
    RUNNER = ROOT / "tools/luacheck/LuaRun.java"
    print("=" * 74)
    print("PRODUCTION COORDINATION ACQUISITION, CARRYING AND DELIVERY")
    print("=" * 74)
    required = [ORGANIZATION, COMMUNICATION, GRAPH, NEEDS, SOURCE_USE,
                PROVISIONING, HANDOVER, CONTROLLER, WORLD_SOURCES, PERCEPTION, CHECK,
                RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    installed = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 197 SKIPPED: installed game VM or JDK absent")
        return 0
    before_hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in required}
    static_ok, detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL")
          + " (" + detail + ")")
    value, output = run_probe()
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")

    sources = {
        "perception": PERCEPTION.read_text(encoding="utf-8-sig"),
        "organization": ORGANIZATION.read_text(encoding="utf-8-sig"),
        "source_use": SOURCE_USE.read_text(encoding="utf-8-sig"),
        "provisioning": PROVISIONING.read_text(encoding="utf-8-sig"),
        "handover": HANDOVER.read_text(encoding="utf-8-sig"),
        "controller": CONTROLLER.read_text(encoding="utf-8-sig"),
        "needs": NEEDS.read_text(encoding="utf-8-sig"),
    }
    controls = [
        ("queue admission is not acquisition", "organization",
         'workEvent(commitment, "admitted", { owner = ownerKind,',
         'workEvent(commitment, "carrying", { owner = ownerKind,',
         "complete_delivered_acceptance_enters_source_owner"),
        ("source completion reaches result consumer", "source_use",
         "pcall(SAO.Provisioning.consumeCompleted, 32)",
         "pcall(function() end)", "complete_native_acquisition_becomes_carrying_once"),
        ("arrival is not delivery", "organization",
         'or "delivery-ready"', 'or "completed"',
         "locomotion_arrival_is_delivery_ready_not_completion"),
        ("terminal source refusal is admitted", "provisioning",
         "            and not coordinated)", "            and true)",
         "released_native_transfer_closes_failed_work_once"),
        ("failed navigation used to end the goal", "organization",
         'Org.pauseWork(commitmentId, "route-" .. route.status, {\n            detail = detail, routeId = route.id,\n            retryAt = commitment.work.routeRetryAt,\n        })',
         'Org.interruptWork(commitmentId, "route-" .. route.status, false)',
         "failed_attempt_retains_accepted_goal"),
        ("retry backoff cannot be skipped", "organization",
         'if nowHours() < (tonumber(commitment.work.routeRetryAt) or 0) then',
         'if false then', "route_backoff_prevents_immediate_restart"),
        ("equivalent failures cannot repeat without bound", "organization",
         '>= MAX_EQUIVALENT_ROUTE_FAILURES then', '>= math.huge then',
         "equivalent_failures_wait_for_changed_evidence"),
        ("changed private facts permit reappraisal", "organization",
         '        and left.knownSources == right.knownSources\n', '\n',
         "changed_private_source_reopens_same_goal"),
        ("timestamps are not changed route facts", "controller",
         'local value = tostring(sourceId) .. "@" .. tostring(fact.revision)',
         'local value = tostring(sourceId) .. "@" .. tostring(fact.revision) .. tostring(belief.at)',
         "unchanged_fact_rescan_does_not_reset_failures"),
        ("current delivery permission is rechecked", "controller",
         'and SAO.Standing.mayAttemptBelieved(id, x, y, "standing")', 'and true',
         "carrying_route_rechecks_permission"),
        ("withdrawal stops external movement owner", "controller",
         'if coordinationWorkEnded(active) then', 'if false then',
         "explicit_withdrawal_stops_retained_route"),
        ("withdrawal stops loaded movement owner", "controller",
         'if agent.coordinationRoute and agent.coordinationCommitment\n        and SAO.Organization and coordinationWorkEnded(',
         'if false and agent.coordinationCommitment\n        and SAO.Organization and coordinationWorkEnded(',
         "loaded_withdrawal_cancels_route_owner"),
        ("native tile identity binds retry budget", "organization",
         'and math.floor(route.x) == math.floor(x)', 'and route.x == x',
         "fractional_target_jitter_does_not_reset_failures"),
        ("duplicate private memories cannot depend on table iteration", "controller",
         'if not seen[value] then\n                    seen[value] = true',
         'if not seen[sourceId] then\n                    seen[sourceId] = true',
         "private_duplicate_source_facts_are_stable"),
        ("paused work cannot starve later accepted work", "controller",
         'for offset = 0, math.min(count, 8) - 1 do', 'for offset = 0, 0 do',
         "paused_goal_does_not_starve_other_accepted_work"),
        ("competing pressure keeps exact work ownership", "controller",
         'if commitment.id == preferredId then return commitment end',
         'if false then return commitment end',
         "competing_activity_pauses_actual_selected_goal"),
        ("pending routes recheck permission", "controller",
         'if not allowed then\n            SAO.Organization.routeOutcome(commitment.id, "interrupted",',
         'if false then\n            SAO.Organization.routeOutcome(commitment.id, "interrupted",',
         "pending_route_rechecks_permission_after_rebind"),
        ("lost runtime source cache does not end responsibility", "controller",
         'pauseCoordinationRoute(SAO.Organization.commitment(route.commitmentId),\n            "acquisition-source-revalidation-needed")',
         'SAO.Organization.interruptWork(route.commitmentId, "acquisition-queue-refused", false)',
         "lost_native_cache_preserves_arrived_goal"),
    ]

    # Restored defect: registry membership supplies an unseen body's location.
    # Keep the real downstream source, permission and handover owners intact.
    private_target = "    local requester = coordinationRequesterInSight(id, body, plan)"
    global_target = """    local requesterBody = SAO.Communication.bodyFor(plan.requesterId)
    local requester = requesterBody and { body = requesterBody,
        x = requesterBody:getX(), y = requesterBody:getY(),
        z = math.floor(requesterBody:getZ()) } or nil"""
    controls.extend([
        ("unseen live registry position cannot replace received address", "controller",
         private_target, global_target,
         "unseen_requester_uses_complete_received_address"),
        ("body availability is not private identity", "controller",
         private_target, global_target, "absent_requester_cannot_admit_handover"),
        ("native sight cannot be replaced by distance", "controller",
         'if ok and visible == true then\n                return { body = other',
         'if ok and floor ~= nil and (body:getX()-other:getX())^2 '
         '+ (body:getY()-other:getY())^2 <= 14^2 then\n                return { body = other',
         "false_sight_requester_cannot_admit_handover"),
        ("retained observation is not fresh action evidence", "controller",
         'local belief = SAO.Perception.freshObservedPerson(id,',
         'local belief = SAO.Perception.believedPerson(id,',
         "stale_requester_cannot_admit_handover"),
        ("private contact identity cannot become the desired requester", "controller",
         'if tostring(known.id) == tostring(plan.requesterId) then',
         'if true then\n            known.id = plan.requesterId',
         "private_id_requester_cannot_admit_handover"),
        ("recipient native identity is checked before sharing", "controller",
         '                    or tostring(otherData.SAOPersonId or "") ~= tostring(known.id)\n',
         '', "native_id_requester_cannot_admit_handover"),
        ("actor native identity is checked before sharing", "controller",
         '                    or tostring(ownData.SAOPersonId or "") ~= tostring(id)\n',
         '', "actor_id_requester_cannot_admit_handover"),
        ("route coordinates remain acquired observations", "controller",
         'requester.x, requester.y, requester.z, "carrying")',
         'requesterBody:getX(), requesterBody:getY(), requester.z, "carrying")',
         "fresh_private_identity_routes_observed_xy_on_seen_floor"),
        ("unseen saved target is revalidated after reload", "controller",
         'if remembered.phase == "carrying" and not (',
         'if false and not (',
         "pending_person_route_revalidates_after_reload"),
        ("received floor is required before local deposit", "controller",
         '        and math.floor(body:getZ()) == math.floor(destination.z)\n', '',
         "received_destination_floor_is_not_current_deposit_floor"),
    ])

    controls_ok = True
    for control in controls:
        name, target, old, new = control[:4]
        reason = control[4] if len(control) > 4 else None
        if sources[target].count(old) != 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        mutated = sources[target].replace(old, new, 1)
        mutant_value, mutant_output = run_probe({target: mutated}, reason)
        mutant_found = verdicts(mutant_value)
        if reason and "COORDINATION_CHECK:" + reason not in mutant_output:
            print(f"  FAULT: {name} did not fail named verdict {reason}: {mutant_value}")
            controls_ok = False
        elif (mutant_value is not None
                and set(mutant_found) == EXPECTED
                and not any(result == "false"
                            for result in mutant_found.values())):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
        else:
            print(f"  PASS control: {name}" + (f" -> {reason}" if reason else ""))
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + f" ({len(controls)} joined-owner controls)")
    after_hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in required}
    stable_inputs = before_hashes == after_hashes
    print("  stable source inputs: " + ("PASS" if stable_inputs else "FAIL"))
    if not static_ok or not controls_ok or not stable_inputs or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + output[-3000:].replace("\n", " "))
        return 1
    print(f"  verdicts: PASS ({len(EXPECTED)} actual-owner cases)")
    print("  197) delivered acceptance executes exact acquisition, carrying and "
          "handover; route failures retain goals with bounded private-evidence reappraisal; "
          "native transfer release/interruption remains failed/partial; "
          "requester destinations require private identity and current sight or received address")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
