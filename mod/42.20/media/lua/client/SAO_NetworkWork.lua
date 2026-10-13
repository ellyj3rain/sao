require "SAO_HouseholdService"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISGrabItemAction"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISEquipWeaponAction"
SAO=SAO or {};SAO.NetworkWork=SAO.NetworkWork or {}
local N,H=SAO.NetworkWork,SAO.HouseholdService
local runtime={}
local operations={place=true,remove=true,open=true,close=true,activate=true,deactivate=true,attach=true,detach=true}
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<math.huge end
local function copy(v,depth)
 if type(v)~="table"then return v end
 if getmetatable(v)or(depth or 0)>8 then return nil end
 local out={};for k,x in pairs(v)do out[k]=copy(x,(depth or 0)+1)end;return out
end
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~="table"then return a==b end
 if getmetatable(a)or getmetatable(b)then return false end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function now()return SAO.History.countyHours()end
local function held(body,item)
 return item and item:getContainer()==body:getInventory()and body:getInventory():contains(item)
  and item:getScriptItem()==getScriptManager():getItem(item:getFullType())and not item:getIsCraftingConsumed()
end
local function carriedOwned(body,item)
 local container=item and item:getContainer()
 return container and container:contains(item)and container:getOutermostContainer()==body:getInventory()
  and item:getScriptItem()==getScriptManager():getItem(item:getFullType())and not item:getIsCraftingConsumed()or false
end
local function human(body)
 return body and not SAOJavaBridge:isShell(body)and getSpecificPlayer(body:getPlayerNum())==body
end
local function owner(id,body,localPlayer)
 if not body or body:isDead()or body:isAsleep()or not body:isExistInTheWorld()or body:getCell()~=getCell()
  or not body:getCurrentSquare()or isClient()or isServer()then return nil end
 if localPlayer then
  if not human(body)or id~="native-player/"..body:getPlayerNum()then return nil end
  return body:getModData()
 end
 local r=SAO.Identity.get(id);local agent=SAO.Controller and SAO.Controller.agents[id]
 if not r or r.dead or r.bodyOwner or r.zaoTransferPending or r.crossedTransferPending
  or not agent or agent.rec~=r or agent.passive or SAO.Body.get(id)~=body or SAO.Body.active[id]~=body
  or SAO.Body.foreign[id]or not SAOJavaBridge:isShell(body)then return nil end
 local d=body:getModData()
 return d.SAOPersonId==id and d.SAOExternalToken==r.bodyOwnerToken and not d.SAOExternalOwner and not d.ZAOOwned and r or nil
end
local function purpose(rt)
 if rt.human then return true end
 local p=SAO.ProceduralPlanning
 return p and p.networkRequestCurrent and p.networkRequestCurrent(rt.id,rt.work)==true
end
local function current(rt)
 local q=rt.queue;return ISTimedActionQueue.queues[rt.body]==q and q.current==rt.action
  and q.queue[1]==rt.action and q:indexOf(rt.action)==1
end
local function nativeExact(rt)
 local ok,value=pcall(function()return rt.native and rt.action.action==rt.native and rt.native:getTable()==rt.action end)
 return ok and value==true
end
local function actionExact(rt)
 local a=rt.action
 if not a then return true end
 if a.character~=rt.body then return false end
 if rt.preparing then
  local c=rt.preparation
  return c and a.item==c.item and(c.kind=="equip"and a.primary or c.kind=="transfer"and a.srcContainer==c.source and a.destContainer==rt.inventory)or false
 end
 return rt.operation~="remove"or a.item==rt.object and a.destContainer==rt.inventory
end
local function bound(rt,pre)
 if rt.closed or runtime[rt.id]~=rt or owner(rt.id,rt.body,rt.human)~=rt.record
  or rt.record.resourceProductionWork~=rt.work or not equal(rt.work,rt.frozen)or not actionExact(rt)or not purpose(rt)
  or getWorld():getWorld()~=rt.world or rt.body:getCell()~=rt.cell or rt.body:getInventory()~=rt.inventory
  or rt.body:getModData().SAOExternalToken~=rt.token or not finite(now())or now()<rt.startedAt
  or not(rt.preparing and carriedOwned(rt.body,rt.tool)or not rt.preparing and held(rt.body,rt.tool))or rt.tool:isBroken()
  or not rt.preparing and rt.body:getPrimaryHandItem()~=rt.tool
  or rt.tool:getCondition()~=rt.toolCondition or rt.tool:getCurrentUses()~=rt.toolUses then return false end
 local site=rt.work.site
 if not rt.human and SAO.Standing.mayTakeCurrent(rt.id,site.x,site.y,"standing")~=true then return false end
 if math.floor(rt.body:getZ())~=site.z or math.abs(rt.body:getX()-site.x-.5)>1.8
  or math.abs(rt.body:getY()-site.y-.5)>1.8 then return false end
 if pre and rt.operation=="place"then
  local fresh=SAOJavaBridge:networkSite(rt.body,site.kind,site.axis,site.x,site.y,site.z)
  return equal(fresh,site)and not H.edgeOccupied(site)and(rt.preparing and carriedOwned(rt.body,rt.item)or not rt.preparing and held(rt.body,rt.item))and rt.item:getWorldItem()==nil
   and rt.item:getFullType()==site.itemType and rt.item:getCondition()==rt.itemCondition
 end
 if pre and(rt.operation=="attach"or rt.operation=="detach")then
  return rt.object:getFluidContainer()==rt.fluid and rt.fluid:getAmount()==rt.beforeSourceAmount
   and SAOJavaBridge:networkFluidObject(rt.body,rt.work.source)==rt.object
 end
 if pre then return equal(rt.part,rt.partBaseline)and H.currentPart(rt.part)==rt.object
  and SAOJavaBridge:networkPartCurrent(rt.body,rt.object,rt.item)==true end
 return true
end
function N.mutationCurrent(id,work,object,definition)
 local rt=runtime[id]
 return rt and rt.work==work and rt.mutating==true and rt.performed==true and rt.started==true
  and nativeExact(rt)and current(rt)and bound(rt,false)
  and (rt.operation=="place"and definition==rt.work.site and object==rt.object
    and SAOJavaBridge:networkPartCurrent(rt.body,object,rt.item)==true and not held(rt.body,rt.item)
   or(rt.operation=="attach"or rt.operation=="detach")and definition==rt.work.site and object==rt.object
    and object:getFluidContainer()==rt.fluid and rt.fluid:getAmount()==rt.beforeSourceAmount
    and SAOJavaBridge:networkFluidObject(rt.body,rt.work.source)==object
   or rt.operation~="place"and definition==rt.part and object==rt.object
    and SAOJavaBridge:networkPartCurrent(rt.body,object,rt.item)==true)or false
end
function N.removalCurrent(id,work,row,object)
 local rt=runtime[id]
 return rt and rt.work==work and rt.part==row and rt.object==object and rt.operation=="remove"
  and rt.mutating and rt.performed and rt.started and nativeExact(rt)and bound(rt,false)
  and held(rt.body,rt.item)and rt.item:getWorldItem()==nil and not rt.square:getWorldObjects():contains(object)or false
end
function N.placementPhaseCurrent(id,work)
 local rt=runtime[id]
 if not rt or rt.work~=work or rt.operation~="place"or not rt.started or not rt.performed or not rt.mutating
  or not nativeExact(rt)or not current(rt)or owner(id,rt.body,rt.human)~=rt.record
  or rt.record.resourceProductionWork~=work or not equal(work,rt.frozen)or not rt.object
  or not actionExact(rt)or getWorld():getWorld()~=rt.world or rt.body:getCell()~=rt.cell
  or rt.body:getInventory()~=rt.inventory or rt.body:getModData().SAOExternalToken~=rt.token
  or held(rt.body,rt.item)or rt.item:getContainer()~=nil
  or rt.item:getCondition()~=rt.itemCondition or rt.item:getFullType()~=work.site.itemType
  or rt.item:getIsCraftingConsumed()or rt.item:getModData().SAOWaterNetworkPart~=nil
  or SAOJavaBridge:networkPartCurrent(rt.body,rt.object,rt.item)~=true then return false end
 local site=work.site;local q=rt.object:getSquare()
 local yaw=site.kind=="riser"and 0 or site.kind=="valve"and(site.axis=="x"and 0 or 90)or(site.axis=="x"and 90 or 0)
 return q==rt.cell:getGridSquare(site.x,site.y,site.z)and q:getX()==site.x and q:getY()==site.y and q:getZ()==site.z
  and rt.item:getWorldXRotation()==(site.kind=="riser"and 90 or 0)
  and rt.item:getWorldYRotation()==0 and rt.item:getWorldZRotation()==yaw or false
end
function N.removalPhaseCurrent(id,work)
 local rt=runtime[id]
 return rt and rt.work==work and rt.operation=="remove"and rt.started and rt.performed and rt.mutating
  and nativeExact(rt)and owner(id,rt.body,rt.human)==rt.record and rt.record.resourceProductionWork==work
  and equal(rt.work,rt.frozen)and equal(rt.part,rt.partBaseline)
  and held(rt.body,rt.item)and rt.item:getWorldItem()==nil and not rt.square:getWorldObjects():contains(rt.object)or false
end
local function finish(rt,status,detail)
 if rt.closed or rt.record.resourceProductionWork~=rt.work then return false end
 local row=copy(rt.work);row.workId=row.id;row.status=status;row.detail=detail
 row.endedAt=now();row.atHours=row.endedAt
 row.nativeOwner=rt.operation=="remove"and"ISGrabItemAction"or rt.operation=="place"and"SAO.NetworkWork/NativePlacement"
  or"SAO.NetworkWork/HouseholdService"
 row.nativeAttempted=rt.performed==true;row.nativeCompleted=status=="completed"
 row.nativeCredit=status=="completed"and row.id or nil;row.paymentMeasured=status=="completed"
 row.physicalPlaced=rt.object~=nil and rt.item:getWorldItem()==rt.object
 row.topologyConfirmed=status=="completed";row.consumerCompleted=false;row.stockCreated=false
 row.inputRetained=held(rt.body,rt.item)==true;row.toolRetained=held(rt.body,rt.tool)==true
 row.itemId=tostring(rt.item:getID());row.itemType=rt.item:getFullType()
 row.inputs={{itemId=row.itemId,itemType=row.itemType,transferredNative=rt.operation=="place"and row.physicalPlaced,
  held=row.inputRetained,condition=rt.item:getCondition()}}
 row.beforeInputCondition=rt.itemCondition;row.afterInputCondition=rt.item:getCondition()
 row.beforeToolCondition=rt.toolCondition;row.afterToolCondition=rt.tool:getCondition()
 row.beforeToolUses=rt.toolUses;row.afterToolUses=rt.tool:getCurrentUses()
 if rt.partBaseline then
  row.beforeOpen=rt.partBaseline.open;row.afterOpen=rt.part.open
  row.beforeEnabled=rt.partBaseline.enabled;row.afterEnabled=rt.part.enabled
 end
 if rt.fluid then
  row.beforeSourceAmount=rt.beforeSourceAmount;row.afterSourceAmount=rt.fluid:getAmount()
  row.sourceAfter=copy(SAOJavaBridge:networkFluidObservation(rt.body,rt.object))
 end
 local installed=rt.part
 if rt.operation=="place"then for _,part in ipairs(H.partsAt(row.site.x,row.site.y,row.site.z))do
  if part.id==row.id then installed=part end
 end end
 row.part=copy(installed)
 if rt.human then row.purposeDelivered=true;row.experienceDelivered=true end
 local rows=rt.record.resourceProductionOutcomes or{};rows[#rows+1]=row
 rt.record.resourceProductionOutcomes=rows;rt.record.resourceProductionWork=nil
 rt.closed=true;runtime[rt.id]=nil
 if not rt.human then
  local p=SAO.ProceduralPlanning
  if p and p.consumeNetworkResult then p.consumeNetworkResult(rt.id,row)end
  local r=SAO.ResourceProduction;if r and r.onOutcome then r.onOutcome(rt.id,row)end
 end
 return true
end
local function stop(rt)
 if rt.closed or rt.ack then return false end
 -- Original base stop resets the whole queue. Retire only this exact native receiver.
 if rt.native and not nativeExact(rt)then return false end
 if current(rt)then rt.queue:onCompleted(rt.action)
 else rt.queue:removeFromQueue(rt.action)end
 rt.ack=true;return finish(rt,"interrupted","network-action-interrupted")
end
function N.begin(id,body,step,context)
 context=context or{};local localPlayer=context.localPlayer==true
 local rec=owner(id,body,localPlayer);local site=step and step.site;local op=step and step.operation
 if not rec or runtime[id]or rec.resourceProductionWork or not H.available()or not operations[op]
  or step.owner~="SAO.ResourceProduction"or step.productionKind~="network-operation"
  or type(site)~="table"or getmetatable(site)or not H.partSpec(site.kind)then return false end
 local tool,item,part,object=context.tool,context.item,context.part,context.object
 if not carriedOwned(body,tool)or tool:isBroken()or tostring(tool:getID())~=tostring(step.toolItemId)or tool:getFullType()~=step.toolItemType
  or not(tool:getType()=="PipeWrench"or tool:hasTag(ItemTag.PIPE_WRENCH))
  then return false end
 local q=ISTimedActionQueue.getTimedActionQueue(body)
 if q.current or #q.queue>0 or SAOJavaBridge:hasPendingActions(body)then return false end
 if op=="place"then
  if not carriedOwned(body,item)or item:getWorldItem()or tostring(item:getID())~=tostring(step.itemId)or item:getFullType()~=site.itemType
   or H.edgeOccupied(site)or not equal(site,SAOJavaBridge:networkSite(body,site.kind,site.axis,site.x,site.y,site.z))then return false end
 elseif op=="attach"or op=="detach"then
  if not step.source or SAOJavaBridge:networkFluidObject(body,step.source)~=object then return false end
  item=tool
 else
  if not part or H.currentPart(part)~=object or not object then return false end
  -- Private observations and canonical results are plain copies. Resolve the
  -- identical live owned row before retaining a mutable installation target.
  local actual
  for _,candidate in ipairs(H.partsAt(site.x,site.y,site.z))do
   if candidate.id==part.id and equal(candidate,part)and H.currentPart(candidate)==object then
    if actual then return false end;actual=candidate
   end
  end
  if not actual then return false end;part=actual
  item=object:getItem()
  if op=="remove"and not body:getInventory():hasRoomFor(body,item)then return false end
 end
 local rows=rec.resourceProductionOutcomes or{}
 if type(rows)~="table"or getmetatable(rows)then return false end
 if #rows>=32 then
  if not rows[1].purposeDelivered or not rows[1].experienceDelivered then return false end
  table.remove(rows,1)
 end
 local sequence=rec.resourceProductionSequence or 0
 if not finite(sequence)or sequence%1~=0 or sequence<0 then return false end
 local t=now();if not finite(t)then return false end
 sequence=localPlayer and H.reservePlayerWorkSequence(body)or sequence+1
 if not sequence then return false end
 local work={id="resource-production/"..id.."/"..sequence,sequence=sequence,actorId=id,kind="network-operation",
  category="construction",token="resource:network-altered",operation=op,site=copy(site),
  itemId=tostring(item:getID()),itemType=item:getFullType(),toolItemId=tostring(tool:getID()),toolItemType=tool:getFullType(),
  source=copy(step.source),
  purposeId=context.purposeId,purposeStepId=context.purposeStepId,world=getWorld():getWorld(),
  bodyToken=body:getModData().SAOExternalToken,startedAt=t,status="working"}
 local rt={id=id,human=localPlayer,body=body,record=rec,work=work,frozen=copy(work),world=work.world,
  token=work.bodyToken,startedAt=t,cell=body:getCell(),inventory=body:getInventory(),queue=q,
  item=item,tool=tool,operation=op,part=part,partBaseline=copy(part),object=object,square=object and object:getSquare(),
  itemCondition=item:getCondition(),toolCondition=tool:getCondition(),toolUses=tool:getCurrentUses()}
 if op=="attach"or op=="detach"then rt.fluid=object:getFluidContainer();rt.beforeSourceAmount=rt.fluid:getAmount()end
 rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=sequence,work,rt
 if not localPlayer and(not SAO.ProceduralPlanning.admitNetworkWork or not SAO.ProceduralPlanning.admitNetworkWork(id,work))then
  rec.resourceProductionWork=nil;runtime[id]=nil;return false
 end
 local preparationNeeded=not held(body,tool)or body:getPrimaryHandItem()~=tool or op=="place"and not held(body,item)
 local function launch()
 rt.preparing=false;rt.preparation=nil;rt.native=nil
 local a=op=="remove"and ISGrabItemAction:new(body,object,100)or ISBaseTimedAction:new(body)
 rt.action=a;a.maxTime=100;a.stopOnWalk=true;a.stopOnRun=true
 local originalCreate,originalStart,originalPerform,originalValid,originalUpdate=a.create,a.start,a.perform,a.isValid,a.update
 if op=="remove"then
  local transfer=a.transferItem
  function a:transferItem(actual)
   if self~=a or actual~=object or not rt.mutating or rt.performed or not rt.started
    or not nativeExact(rt)or not current(rt)or not bound(rt,true)then return false end
   return transfer(self,actual)
  end
 end
 function a:create()
  if self~=a or rt.native or not current(rt)or not bound(rt,true)then return false end
  originalCreate(self);rt.native=self.action
  return nativeExact(rt)
 end
 function a:isValid()return self==a and not rt.closed and not rt.performed and bound(rt,true)
  and(op~="remove"or originalValid(self)==true)or false end
 function a:waitToStart()
  if self~=a or rt.closed or not current(rt)or not nativeExact(rt)or not bound(rt,true)then return false end
  body:faceLocation(site.x+.5,site.y+.5);return body:shouldBeTurning()
 end
 function a:start()
  if self~=a or not current(rt)or not nativeExact(rt)or not self:isValid()then return false end
  local ok,value=pcall(originalStart,self);if not ok or value==false then stop(rt);if not ok then error(value)end;return false end
  rt.started=true;return value
 end
 function a:update()
  if self~=a or rt.closed or rt.performed or not rt.started or not nativeExact(rt)or not current(rt)or not bound(rt,true)then return false end
  return originalUpdate(self)
 end
 function a:perform()
  if self~=a or rt.closed or rt.performed or not rt.started or not nativeExact(rt)or not current(rt)
   or not rt.native:isStarted()or not(rt.native:finished()or rt.native:isForceComplete())or not self:isValid()then return false end
  -- GRAB consults isValid internally before native transfer.
  rt.mutating=true
  local effected=false
  if op=="remove"then
   if not self.queueList or #self.queueList~=1 or #self.queueList[1].items~=1 or self.queueList[1].items[1]~=object then return false end
   local ok=pcall(originalPerform,self);rt.performed=true
   effected=ok and N.removalCurrent(id,work,part,object)and H.retirePart(id,work,part,object)
  else
   rt.performed=true
   if op=="place"then
    rt.object=SAOJavaBridge:placeNetworkPart(body,item,work.site)
    effected=rt.object~=nil and H.commitPart(id,work,rt.object,work.site)==true
   elseif op=="attach"or op=="detach"then effected=H.changeSource(id,work,object,work.site,op=="attach")==true
   else effected=H.changePart(id,work,part,object,op)==true end
   ISBaseTimedAction.perform(self)
  end
  rt.mutating=false;rt.ack=true
  return finish(rt,effected and"completed"or"failed",effected and"native-network-effect-measured"or"native-network-effect-unconfirmed")
 end
 function a:complete()return false end
 function a:stop()if self~=a then return false end;return stop(rt)end
 function a:forceCancel()
  if self~=a or rt.closed or rt.ack then return false end
  if not rt.native then return stop(rt)end
  if nativeExact(rt)and not rt.native:isStarted()and not body:getCharacterActions():contains(rt.native)then return stop(rt)end
  return false
 end
 a.canMergeAction=function()return false end
 a.actorId,a.workId=id,work.id
 a._SAONetworkRetireSaved=function(r,w)
  if rt.record~=r or rt.work~=w or not equal(w,rt.frozen)or rt.closed then return false end
  if rt.native and nativeExact(rt)and current(rt)then rt.native:forceStop()end
  if not rt.native or nativeExact(rt)and not body:getCharacterActions():contains(rt.native)then return stop(rt)end
  return rt.closed==true
 end
 return SAO.Needs.queueVerified(a)==true
 end
 local function prepare()
  local pending={}
  local function transfer(item)
   if item and item:getContainer()~=rt.inventory then
    pending[#pending+1]={kind="transfer",item=item,source=item:getContainer()}
   end
  end
  transfer(tool);if item~=tool and op=="place"then transfer(item)end
  if body:getPrimaryHandItem()~=tool then pending[#pending+1]={kind="equip",item=tool}end
  local nextAction
  nextAction=function(index)
   if rt.queue.current or #rt.queue.queue>0 then return stop(rt)end
   local stage=pending[index]
   if not stage then rt.preparing=false;rt.native=nil;rt.started=false;return launch()end
   local a=stage.kind=="transfer"and ISInventoryTransferAction:new(body,stage.item,stage.source,rt.inventory)
    or ISEquipWeaponAction:new(body,stage.item,50,true,false)
   rt.action=a;rt.native=nil;rt.preparation=stage
   local create,start,valid,perform,complete,update,transferItem=a.create,a.start,a.isValid,a.perform,a.complete,a.update,a.transferItem
   local started,performed,done=false,false,false
   local function exact()
    return rt.action==a and a.character==body and a.item==stage.item
     and(stage.kind=="equip"and a.primary==true or stage.kind=="transfer"and a.srcContainer==stage.source and a.destContainer==rt.inventory)
   end
   local function allowed()
    return not done and not rt.closed and exact()and bound(rt,true)and current(rt)and nativeExact(rt)
   end
   function a:create()
    if self~=a or done or rt.native or not current(rt)or not exact()or not bound(rt,true)then return false end
    create(self);rt.native=self.action;return nativeExact(rt)
   end
   function a:isValid()return self==a and not done and exact()and bound(rt,true)and valid(self)==true or false end
   function a:start()
    if self~=a or not allowed()or not self:isValid()then return false end
    local ok,value=pcall(start,self)
    if not ok or value==false then stop(rt);if not ok then error(value)end;return false end
    started=true;return value
   end
   function a:update()
    if self~=a or not started or not allowed()then return false end;return update(self)
   end
   if stage.kind=="transfer"then
    function a:transferItem(actual)
     if self~=a or actual~=stage.item or not started or not allowed()then return false end
     return transferItem(self,actual)
    end
   end
   function a:perform()
    if self~=a or performed or not started or not allowed()or not self:isValid()
     or not rt.native:isStarted()or not(rt.native:finished()or rt.native:isForceComplete())then return false end
    if stage.kind=="transfer"and(not self.queueList or #self.queueList~=1 or #self.queueList[1].items~=1
     or self.queueList[1].items[1]~=stage.item)then return false end
    performed=true;local ok,value=pcall(perform,self)
    if not ok then return stop(rt)end
    if stage.kind=="transfer"then
     if not held(body,stage.item)or stage.source:contains(stage.item)then return stop(rt)end
     done=true;return nextAction(index+1)
    end
    return value
   end
   function a:complete()
    if self~=a or done or stage.kind~="equip"or not performed or not started or not exact()or not nativeExact(rt)
     or not bound(rt,true)or valid(self)~=true then return false end
    local ok,value=pcall(complete,self)
    if not ok or value~=true or body:getPrimaryHandItem()~=stage.item then return stop(rt)end
    done=true;return nextAction(index+1)
   end
   function a:stop()if self~=a or done then return false end;done=true;return stop(rt)end
   function a:forceCancel()
    if self~=a or done then return false end
    if not rt.native or nativeExact(rt)and not started and not body:getCharacterActions():contains(rt.native)then
     done=true;return stop(rt)
    end
    return false
   end
   a.actorId,a.workId=id,work.id;a.canMergeAction=function()return false end
   a._SAONetworkRetireSaved=function(r,w)
    if rt.record~=r or rt.work~=w or not equal(w,rt.frozen)or done then return false end
    if nativeExact(rt)and current(rt)then rt.native:forceStop()end
    if not rt.native or nativeExact(rt)and not body:getCharacterActions():contains(rt.native)then done=true;return stop(rt)end
    return rt.closed
   end
   return SAO.Needs.queueVerified(a)==true
  end
  rt.preparing=true;return nextAction(1)
 end
 if preparationNeeded then return prepare()end
 return launch()

end
function N.prepareMeans(id,body,purpose,step,item,tool,part,object)
 return N.begin(id,body,step,{purposeId=purpose.id,purposeStepId=step.id,item=item,tool=tool,part=part,object=object})
end
function N.outcome(id,workId)
 local r=SAO.Identity.get(id)
 for _,row in ipairs(r and r.resourceProductionOutcomes or{})do
  if row.id==workId and row.kind=="network-operation"and row.actorId==id
   and row.workId==row.id and operations[row.operation]and finite(row.atHours)
   and finite(row.sequence)and row.sequence%1==0 and row.sequence>0 and row.sequence<=r.resourceProductionSequence
   and row.id=="resource-production/"..id.."/"..row.sequence
   and(row.status=="completed"and row.nativeCredit==row.id and row.nativeCompleted and row.nativeAttempted and row.paymentMeasured
    or row.status=="failed"and row.nativeCredit==nil or row.status=="interrupted"and row.nativeCredit==nil)then return row end
 end
end
function N.interrupt(id,body)
 local rt=runtime[id];if not rt or rt.body~=body then return false end
 if rt.native and nativeExact(rt)and current(rt)then rt.native:forceStop();return true end
 return rt.action:forceCancel()
end
function N.tick(id,body)
 local rt=runtime[id]
 if rt and rt.body==body and not bound(rt,not rt.performed)then return N.interrupt(id,body)end
 return rt~=nil
end
function N.reset()
 for id,rt in pairs(runtime)do N.interrupt(id,rt.body)end
end
function N.reconcileSaved(id,body)
 local rec=SAO.Identity.get(id);local work=rec and rec.resourceProductionWork
 if not work or work.kind~="network-operation"then return true end
 if runtime[id]then N.interrupt(id,runtime[id].body);return rec.resourceProductionWork==nil end
 for _,q in pairs(ISTimedActionQueue.queues)do
  local actions={};for _,a in ipairs(q.queue)do actions[#actions+1]=a end
  if q.current and q:indexOf(q.current)==-1 then actions[#actions+1]=q.current end
  for _,a in ipairs(actions)do if a.actorId==id and a.workId==work.id then
   if type(a._SAONetworkRetireSaved)~="function"or a._SAONetworkRetireSaved(rec,work)~=true then return false end
  end end
 end
 if rec.resourceProductionWork==nil then return true end
 if not owner(id,body,false)or SAOJavaBridge:hasPendingActions(body)then return false end
 local row=copy(work);row.workId=row.id;row.status="interrupted";row.detail="network-runtime-unavailable"
 row.atHours=now();row.endedAt=row.atHours;row.nativeAttempted=false;row.nativeCompleted=false;row.paymentMeasured=false
 row.topologyConfirmed=false;row.physicalPlaced=false;row.consumerCompleted=false;row.stockCreated=false
 local rows=rec.resourceProductionOutcomes or{};if #rows>=32 then return false end
 rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;rec.resourceProductionWork=nil
 return true
end
return N
