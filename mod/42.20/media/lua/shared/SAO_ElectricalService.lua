-- Owned electrical service; native generators alone bill and burn fuel.
-- LGEE/LGRPU are source principles, not redistributed implementations.
SAO=SAO or {};SAO.ElectricalService=SAO.ElectricalService or {}
local E=SAO.ElectricalService
if E.reset then E.reset()end
E.operations={ ["inspect-load"]=true,["shed-load"]=true,["breaker-open"]=true,["breaker-reset"]=true,["verify-service"]=true }
E.tokens={ ["inspect-load"]="utility:load-inspected",["shed-load"]="utility:load-shed",["breaker-open"]="utility:breaker-opened",
 ["breaker-reset"]="utility:breaker-reset",["verify-service"]="utility:service-verified" }
local function finite(x)return type(x)=="number"and x==x and x>=0 and x<math.huge end
local function live(body,object)
 local q=object and object:getSquare()
 return body and q and q:getCell()==body:getCell()and body:getCell()==getCell()
  and getCell():getGridSquare(q:getX(),q:getY(),q:getZ())==q and q:getObjects():contains(object)
end
function E.breakerOpen(generator)
 return generator and generator:getModData().SAOElectricalBreaker==true or false
end
function E.atConsumer(operation)
 return operation=="inspect-load"or operation=="shed-load"or operation=="verify-service"
end
function E.measure(body,generator,consumer,fact,operation,generatorFact)
 if not live(body,generator)or not live(body,consumer)or type(fact)~="table"then return nil end
 local ok,load=pcall(function()
  if generatorFact then
   local pair=SAO.WorldSources.electricalServiceObjects(body,generatorFact,fact,operation,false)
   return pair and pair.generator==generator and pair.consumer==consumer and pair.load or nil
  end
  return SAOJavaBridge:worldElectricalLoad(body,fact.sourceId,fact.fingerprint,consumer)
 end)
 if not ok or type(load)~="table"or not finite(load.partRate)or not finite(load.groupRate)
  or not finite(load.partCount)or load.partCount<1 or load.partCount%1~=0 then return nil end
 local q,c=generator:getSquare(),consumer:getSquare()
 local rate,fuel=generator:getTotalPowerUsing(),generator:getFuel()
 local mods=getActivatedMods and getActivatedMods()
 local external=mods and mods:contains("LGExtendedElectricity")==true and LGEE~=nil
 if not finite(rate)or not finite(fuel)then return nil end
 return {schema="sao-electrical-measurement/1",nativeClass=load.nativeClass,
  partRate=load.partRate,groupRate=load.groupRate,partCount=load.partCount,switchable=load.switchable==true,
  totalRate=rate,fuel=fuel,active=generator:isActivated(),connected=generator:isConnected(),
  breakerOpen=E.breakerOpen(generator),consumerActive=load.consumerActive==true,powered=load.powered==true,
  covered=IsoGenerator.isPoweringSquare(q:getX(),q:getY(),q:getZ(),c:getX(),c:getY(),c:getZ()),
  burnOwner="IsoGenerator.update",loadOwner=external and "external-writer-unresolved"or"native-IsoGenerator",
  atHours=SAO.History.countyHours()}
end
local measurementKeys={schema=true,nativeClass=true,partRate=true,groupRate=true,partCount=true,switchable=true,
 totalRate=true,fuel=true,active=true,connected=true,breakerOpen=true,consumerActive=true,powered=true,covered=true,
 burnOwner=true,loadOwner=true,atHours=true}
function E.measurement(row)
 if type(row)~="table"or getmetatable(row)or row.schema~="sao-electrical-measurement/1"
  or type(row.nativeClass)~="string"or #row.nativeClass==0 or #row.nativeClass>256
  or row.burnOwner~="IsoGenerator.update"or row.loadOwner~="native-IsoGenerator"and row.loadOwner~="external-writer-unresolved"then return false end
 for k in pairs(row)do if not measurementKeys[k]then return false end end
 for _,k in ipairs({"partRate","groupRate","partCount","totalRate","fuel","atHours"})do if not finite(row[k])then return false end end
 if row.partCount<1 or row.partCount%1~=0 then return false end
 for _,k in ipairs({"switchable","active","connected","breakerOpen","consumerActive","powered","covered"})do if type(row[k])~="boolean"then return false end end
 return true
end
function E.sameMeasurement(before,after)
 if not E.measurement(before)or not E.measurement(after)then return false end
 for k,v in pairs(before)do
  if k~="atHours"and k~="fuel"and k~="totalRate"and k~="partRate"and k~="groupRate"and after[k]~=v then return false end
 end
 return after.atHours>=before.atHours
end
function E.effect(operation,before,after)
 if not E.operations[operation]or not E.measurement(before)or not E.measurement(after)
  or before.nativeClass~=after.nativeClass or before.partCount~=after.partCount or after.atHours<before.atHours
  or before.burnOwner~=after.burnOwner or before.loadOwner~=after.loadOwner then return false end
 if operation=="inspect-load"then return true end
 if before.loadOwner~="native-IsoGenerator"or after.loadOwner~="native-IsoGenerator"then return false end
 if operation=="shed-load"then return before.covered and after.covered and before.active and before.connected
  and after.active and after.connected and before.fuel>0 and after.fuel>0 and before.switchable and before.consumerActive and not after.consumerActive
  and after.groupRate<before.groupRate end
 if operation=="breaker-open"then return before.active and not after.active and after.breakerOpen end
 if operation=="breaker-reset"then return before.breakerOpen and not after.breakerOpen and after.active end
 return after.covered and after.powered and after.active and after.connected and not after.breakerOpen
end
function E.receipt(row)
 local work=row and row.electricalService
 return type(work)=="table"and not getmetatable(work)and work.schema=="sao-electrical-service/1"
  and work.consumerId==row.consumerId and work.sourceId==row.sourceId
  and work.consumerCompleted==false and E.effect(row.operation,work.before,work.after)
end
-- Original constructors use different native receiver fields.
-- Reached physical inspection of all parts; no amount or occupancy is inferred from an empty logical row.
function E.idleConsumer(body,object,id)
 if not live(body,object)or not instanceof(object,"IsoStove")then return nil end
 local ok,idle=pcall(function()
  local parts=object:getSpriteGridObjectsIncludingSelf(ArrayList.new());if parts:isEmpty()then parts:add(object)end
  local containers=0;local seen={}
  for i=0,parts:size()-1 do local part=parts:get(i)
   if not seen[part]then
    seen[part]=true;local q=part:getSquare()
    if not live(body,part)or q:getZ()~=body:getCurrentSquare():getZ()or not body:getCurrentSquare():canReachTo(q)
     or (body:getX()-q:getX()-.5)^2+(body:getY()-q:getY()-.5)^2>=4
     or id and SAO.Standing.mayAttemptBelieved(id,q:getX(),q:getY(),"standing")~=true then return false end
    local container=part:getContainer()
    if container then
     if not container:isExplored()then return nil end
     containers=containers+1;if not container:getItems():isEmpty()then return false end
    end
   end
  end
  return containers>0
 end)
 if ok then return idle end
 return nil
end
function E.actionCurrent(action,body,generator,consumer,operation)
 if not action or action.character~=body then return false end
 if operation=="shed-load"then return action.object==consumer end
 if operation=="breaker-open"or operation=="breaker-reset"then
  return action.generator==generator and action.activate==(operation=="breaker-reset")
 end
 return (operation=="inspect-load"or operation=="verify-service")and action.generator==generator and action.consumer==consumer
end
function E.action(body,generator,consumer,operation)
 require "TimedActions/ISBaseTimedAction"
 require "TimedActions/ISActivateGenerator"
 require "TimedActions/ISToggleStoveAction"
 require "TimedActions/ISToggleLightAction"
 if not E.operations[operation]or not live(body,generator)or not live(body,consumer)then return nil end
 if operation=="shed-load"and(not generator:isActivated()or not generator:isConnected()or generator:getFuel()<=0 or generator:getCondition()<=0)then return nil end
 if operation=="breaker-reset"or operation=="verify-service"then
  if not generator:getSquare():isOutside()or not generator:isConnected()or generator:getFuel()<=0 or generator:getCondition()<=0 then return nil end
 end
 if operation=="breaker-reset"and not E.breakerOpen(generator)then return nil end
 if operation=="breaker-open"or operation=="breaker-reset"then
  return ISActivateGenerator:new(body,generator,operation=="breaker-reset")
 end
 if operation=="shed-load"then
  if instanceof(consumer,"IsoStove")and consumer:Activated()then return ISToggleStoveAction:new(body,consumer)end
  if instanceof(consumer,"IsoLightSwitch")and consumer:isActivated()then return ISToggleLightAction:new(body,consumer)end
  return nil
 end
 if not E.inspectionAction then
  local A=ISBaseTimedAction:derive("SAOElectricalInspection")
  function A:isValid()return live(self.character,self.generator)and live(self.character,self.consumer)end
  function A:waitToStart()self.character:faceThisObject(self.consumer);return self.character:shouldBeTurning()end
  function A:update()self.character:faceThisObject(self.consumer)end
  function A:start()self:setActionAnim("Loot");self.character:SetVariable("LootPosition","Low");self.character:reportEvent("EventLootItem")end
  function A:perform()ISBaseTimedAction.perform(self)end
  function A:complete()return live(self.character,self.generator)and live(self.character,self.consumer)end
  function A:new(character,g,c)local o=ISBaseTimedAction.new(self,character);o.generator,o.consumer=g,c;o.maxTime=30;return o end
  E.inspectionAction=A
 end
 return E.inspectionAction:new(body,generator,consumer)
end
-- Breaker state is committed only after the original native action changed supply.
function E.commit(generator,operation)
 if operation=="breaker-open"and not generator:isActivated()then generator:getModData().SAOElectricalBreaker=true;return true end
 if operation=="breaker-reset"and generator:isActivated()then generator:getModData().SAOElectricalBreaker=nil;return true end
 return operation~="breaker-open"and operation~="breaker-reset"
end
-- Human entry retains the same original native actions. Its saved rows belong
-- only to this real player body, never to a manufactured SAO person.
local humanRuntime=setmetatable({},{__mode="k"})
local function human(body)
 return body and not SAOJavaBridge:isShell(body)and getSpecificPlayer(body:getPlayerNum())==body
  and not body:isDead()and not body:isAsleep()and body:isExistInTheWorld()
end
function E.beginHuman(body,generator,consumer,operation)
 if not human(body)or not E.operations[operation]or humanRuntime[body]or not live(body,generator)or not live(body,consumer)then return false end
 local rec=body:getModData();local queue=ISTimedActionQueue.getTimedActionQueue(body)
 if rec.resourceProductionWork or queue.current or #queue.queue>0 or SAOJavaBridge:hasPendingActions(body)then return false end
 local fact={sourceId="human-direct",fingerprint="human-direct"}
 local before=E.measure(body,generator,consumer,fact)
 if not before or operation~="inspect-load"and before.loadOwner~="native-IsoGenerator"
  or operation=="shed-load"and(not before.covered or not before.active or not before.connected or before.fuel<=0 or generator:getCondition()<=0)then return false end
 local action=E.action(body,generator,consumer,operation);if not action then return false end
 local sequence=SAO.HouseholdService.reservePlayerWorkSequence(body);if not sequence then return false end
 local work={id="electrical/native-player/"..body:getPlayerNum().."/"..sequence,kind="electrical-service",operation=operation,
  sequence=sequence,actorId="native-player/"..body:getPlayerNum(),world=getWorld():getWorld(),startedAt=SAO.History.countyHours()}
 local rt={action=action,body=body,generator=generator,consumer=consumer,work=work,queue=queue,record=rec}
 humanRuntime[body]=rt;rec.resourceProductionWork=work
 local valid,start,perform,complete,stop,create=action.isValid,action.start,action.perform,action.complete,action.stop,action.create
 local function exact(self)
  return self==action and E.actionCurrent(action,body,generator,consumer,operation)and humanRuntime[body]==rt and rec.resourceProductionWork==work
   and human(body)and body:getModData()==rec and getWorld():getWorld()==work.world
   and live(body,generator)and live(body,consumer)and ISTimedActionQueue.queues[body]==queue
   and(operation~="shed-load"or generator:isActivated()and generator:isConnected()and generator:getFuel()>0 and generator:getCondition()>0)
   and (operation~="breaker-reset"and operation~="verify-service"or generator:getSquare():isOutside()
    and generator:isConnected()and generator:getFuel()>0 and generator:getCondition()>0)
 end
 local function nativeExact()return rt.native and action.action==rt.native and rt.native:getTable()==action end
 local function current()return queue.current==action and queue.queue[1]==action end
 local function finish(status)
  if rt.done or rec.resourceProductionWork~=work then return false end
  rt.done=true;humanRuntime[body]=nil;rec.resourceProductionWork=nil
  local after=E.measure(body,generator,consumer,fact)
  local row={id=work.id,actorId=work.actorId,sequence=sequence,kind=work.kind,operation=operation,world=work.world,
   startedAt=work.startedAt,atHours=SAO.History.countyHours(),status=status,before=before,after=after,
   nativeAttempted=rt.performed==true,consumerCompleted=false}
  row.nativeCompleted=status=="completed"and E.effect(operation,before,after)or false
  if status=="completed"and not row.nativeCompleted then row.status="failed"end
  row.nativeCredit=row.nativeCompleted and row.id or nil
  rec.electricalServiceOutcomes=rec.electricalServiceOutcomes or{}
  local rows=rec.electricalServiceOutcomes;rows[#rows+1]=row;if #rows>32 then table.remove(rows,1)end
  return row.nativeCompleted
 end
 function action:isValid()
  return exact(self)and not rt.done and not rt.performed and current()
   and E.sameMeasurement(before,E.measure(body,generator,consumer,fact))and valid(self)==true
 end
 if create then function action:create()
  if rt.native or not exact(self)or not current()or rt.done then return false end
  local result=create(self);if self.action and self.action:getTable()==self then rt.native=self.action end;return result
 end end
 function action:start()
  if not exact(self)or not current()or rt.done or not nativeExact()or not self:isValid()then return false end
  local ok,result=pcall(start,self)
  if not ok then finish("failed");error(result)end
  if result==false then return false end
  if not nativeExact()then return false end
  rt.started=true;return result
 end
 function action:perform()
  if not exact(self)or rt.done or rt.performed or not rt.started or not nativeExact()or not current()or not self:isValid()then return false end
  local ok,finished=pcall(function()return rt.native:isStarted()and rt.native:finished()and not rt.native:isForceComplete()end)
  if not ok or not finished then return false end
  rt.performed=true;return perform(self)
 end
 function action:complete()
  if not exact(self)or rt.done or not rt.performed or not rt.started or not nativeExact()then return false end
  if not E.sameMeasurement(before,E.measure(body,generator,consumer,fact))then return finish("failed")end
  before=E.measure(body,generator,consumer,fact)
  if not before then return finish("failed")end
  local ok,result=pcall(complete,self)
  if ok and result==true and E.commit(generator,operation)then return finish("completed")end
  finish("failed");return false
 end
 function action:stop()
  if self~=action or rt.done or humanRuntime[body]~=rt or self.character~=body
   or rec.resourceProductionWork~=work or rt.native and not nativeExact()then return false end
  if current()then stop(self)else queue:removeFromQueue(self)end
  finish("interrupted");return true
 end
 function action:forceCancel()
  if self~=action or rt.done or humanRuntime[body]~=rt or self.character~=body
   or rec.resourceProductionWork~=work or rt.native and not nativeExact()then return false end
  if rt.native and nativeExact()and not rt.started then
   local ok,absent=pcall(function()return not rt.native:isStarted()and not body:getCharacterActions():contains(rt.native)end)
   if ok and absent then
    queue:removeFromQueue(self);if queue.current==self then queue.current=nil end
    finish("interrupted");return true
   end
  end
  if rt.native and current()then rt.native:forceStop();return true end
  if not self.action then queue:removeFromQueue(self);if queue.current==self then queue.current=nil end;finish("interrupted");return true end
  return false
 end
 rt.interrupt=function()
  if rt.done then return false end
  if rt.native and nativeExact()and current()then rt.native:forceStop();return true end
  return action:forceCancel()
 end
 action.canMergeAction=function()return false end
 local queued=SAO.Needs.queueVerified(action)==true
 if queued then return true end
 if not rt.done and humanRuntime[body]==rt and rec.resourceProductionWork==work then
  local ok,present=pcall(function()return rt.native and body:getCharacterActions():contains(rt.native)end)
  if ok and not present then
   queue:removeFromQueue(action);if queue.current==action then queue.current=nil end
   finish("failed")
  else action:forceCancel()end
 end
 return false
end
function E.reconcileHuman(body)
 if not human(body)then return false end
 local rec=body:getModData();local work=rec.resourceProductionWork
 if not work or work.kind~="electrical-service"or humanRuntime[body]then return true end
 if SAOJavaBridge:hasPendingActions(body)then return false end
 local actor="native-player/"..body:getPlayerNum()
 if work.actorId~=actor or work.world~=getWorld():getWorld()or not finite(work.sequence)
  or work.sequence<1 or work.sequence%1~=0 or work.id~="electrical/"..actor.."/"..work.sequence then return false end
 local row={id=work.id,actorId=work.actorId,sequence=work.sequence,kind=work.kind,world=work.world,
  operation=work.operation,startedAt=work.startedAt,atHours=SAO.History.countyHours(),status="interrupted",
  nativeAttempted=false,nativeCompleted=false,consumerCompleted=false}
 rec.electricalServiceOutcomes=rec.electricalServiceOutcomes or{};local rows=rec.electricalServiceOutcomes
 rows[#rows+1]=row;if #rows>32 then table.remove(rows,1)end;rec.resourceProductionWork=nil;return true
end
function E.interruptHuman(body)
 local rt=humanRuntime[body];return rt and rt.interrupt()or false
end
function E.reset()
 for body in pairs(humanRuntime)do E.interruptHuman(body)end
end
if Events and Events.OnPlayerDeath then
 if E.onDeath then Events.OnPlayerDeath.Remove(E.onDeath)end
 E.onDeath=E.interruptHuman;Events.OnPlayerDeath.Add(E.onDeath)
end
if Events and Events.OnInitGlobalModData then
 if E.onInit then Events.OnInitGlobalModData.Remove(E.onInit)end
 E.onInit=E.reset;Events.OnInitGlobalModData.Add(E.onInit)
end
return E
