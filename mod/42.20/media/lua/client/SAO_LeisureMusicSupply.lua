-- Source slot preparation for an admitted personal NewMusic listening work.
-- Original slot actions and original intent/transition/inventory owners apply effects.
SAO=SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end;SAO.LeisureMusicSupply=SAO.LeisureMusicSupply or {}
local S=SAO.LeisureMusicSupply
if S.reset then S.reset("module-reload")end
local runtime={};local prepared={};local OWNER="SAO.LeisureMusic"
local PINS={
 ["shared/intent/NMIntentInventoryOps.lua"]={"fe1498c8e56dfd9f540bc1ea5c0317468dd0cd62a8ba0b46e0a0aad762fa7802",452997369,1154535901,175},
 ["client/ui/shared/slots/NMBatterySlotTimedAction.lua"]={"3b83249977e050efe19364fa2680c8fa20d5fecb45e7ba4b5da4a6160daa90c6",173850813,438301888,98},
 ["client/ui/shared/slots/NMMediaSlotTimedAction.lua"]={"16b3f99625d82bf8ff9eb8d6fda36dbf443f6eb377d81f423be65e5b8c0624f3",818867511,1608582503,236},
 ["client/ui/shared/slots/NMHeadphoneSlotTimedAction.lua"]={"4d9f39a8414b447c795797845a6ab5fc30d929e4273f6f846aae6ecbd3287b4d",321392234,7217635,101},
}
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<1000000000 end
local function copy(v,depth)
 depth=depth or 0;if type(v)=="string"or type(v)=="boolean"then return v end
 if type(v)=="number"then return finite(v)and v or nil end
 if type(v)~="table"or depth>10 then return nil end
 local out={}for k,x in pairs(v)do if type(k)=="string"or type(k)=="number"then out[k]=copy(x,depth+1)end end;return out
end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function items(body)
 local out={};local list=SAOJavaBridge:privateCarriedItems(body)
 for n=0,list:size()-1 do out[#out+1]=list:get(n)end;return out
end
local function key(item)return "item:"..tostring(item:getID())..":"..item:getFullType()end
local function resolve(body,itemKey)for _,item in ipairs(items(body))do if key(item)==itemKey then return item end end end
local function mediaPayload(item,profile,device)
 local p=NMMediaHelpers and NMMediaHelpers.resolveMediaInsertPayload and NMMediaHelpers.resolveMediaInsertPayload(item)
 if not p or p.mediaCarrier~=profile.supportedCarrier or type(p.mediaFullType)~="string"or p.mediaFullType==""then return nil end
 local required=NMMediaContract and NMMediaContract.resolveContainerMediaBinding and device and device.getFullType
  and NMMediaContract.resolveContainerMediaBinding(device:getFullType())
 if required and required~=""and not(NMMediaContract.areMediaEquivalent and NMMediaContract.areMediaEquivalent(p.mediaEjectFullType,required))
  and required~=p.mediaEjectFullType then return nil end
 local count=NMTrackCountResolver and NMTrackCountResolver.resolveFromState and NMTrackCountResolver.resolveFromState({mediaFullType=p.mediaFullType})
 if not finite(count)or count<1 then return nil end
 return copy(p)
end
-- Read only. Selection is restricted to actual private carried items.
function S.plan(body,device,profile,state,sourceContext)
 if not body or not device or not profile or not state or state.isPlaying or not state.deviceUUID then return nil end
 local out={};local needed=false
 if profile.requiresBattery and not(state.batteryPresent==true and finite(state.batteryCharge)and state.batteryCharge>0)then
  needed=true
  for _,item in ipairs(items(body))do
   local charge=item:getFullType()=="Base.Battery"and NMCore and NMCore.readDrainableFraction and NMCore.readDrainableFraction(item,0)
   if finite(charge)and charge>0 then out.battery={itemKey=key(item),itemType=item:getFullType(),itemId=tostring(item:getID()),charge=charge,
    ejectExisting=state.batteryPresent==true};break end
  end
  if not out.battery then return nil end
 end
 if not state.mediaFullType or state.mediaFullType==""then
  needed=true
  for _,item in ipairs(items(body))do
   local payload=mediaPayload(item,profile,device)
   if payload then out.media={itemKey=key(item),itemType=item:getFullType(),itemId=tostring(item:getID()),payload=payload};break end
  end
  if not out.media then return nil end
 end
 if NMDeviceProfiles.requiresHeadphonesForPlayback(profile)and not state.headphoneItemFullType then
  needed=true
  for _,item in ipairs(items(body))do
   local supported=NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.isSupported(item:getFullType())
   local detaches=sourceContext=="placed"and NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.shouldDetachOnGround(item:getFullType())
   local selectable=item:getFullType()~="Base.Headphones"or NMInventoryHelpers.findDirectItemById(body:getInventory(),tostring(item:getID()))==item
   if supported and selectable and not detaches then out.headphones={itemKey=key(item),itemType=item:getFullType(),itemId=tostring(item:getID())};break end
  end
  if not out.headphones then return nil end
 end
 return needed and out or nil
end
function S.outputMode(profile,state,sourceContext,plan)
 if not plan or not plan.headphones then return NMDeviceProfiles.resolveOutputMode(profile,state,sourceContext,false)end
 local projected=copy(state);projected.headphoneItemFullType=plan.headphones.itemType
 return NMDeviceProfiles.resolveOutputMode(profile,projected,sourceContext,false)
end
function S.materialKeys(plan)
 local out={}for name,row in pairs(plan or {})do out[name]={id=row.itemId,itemType=row.itemType}end;return out
end
function S.requirementUnmet(body,device,profile,state,row,sourceContext)
 if not body or not profile or not state or profile.deviceType=="media_container"or state.isPlaying then return false end
 if row.requirementId=="source-audio-battery"then
  if not profile.requiresBattery or state.batteryPresent==true and finite(state.batteryCharge)and state.batteryCharge>0 then return false end
  for _,item in ipairs(items(body))do
   if item:getFullType()=="Base.Battery"then local charge=NMCore.readDrainableFraction(item,0);if finite(charge)and charge>0 then return false end end
  end
  return true
 end
 if row.requirementId=="source-audio-headphones"then
  if not NMDeviceProfiles.requiresHeadphonesForPlayback(profile)or state.headphoneItemFullType then return false end
  for _,item in ipairs(items(body))do
   if NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.isSupported(item:getFullType())
    and not(sourceContext=="placed"and NMInsertedHeadphonePolicy.shouldDetachOnGround(item:getFullType()))
    and(item:getFullType()~="Base.Headphones"or NMInventoryHelpers.findDirectItemById(body:getInventory(),tostring(item:getID()))==item)then return false end
  end
  return true
 end
 if not row.carrier or row.carrier~=profile.supportedCarrier or state.mediaFullType and state.mediaFullType~=""then return false end
 for _,item in ipairs(items(body))do if mediaPayload(item,profile,device)then return false end end
 return true
end
local function record(id)return SAO.Identity and SAO.Identity.get(id)end
local function now()return SAO.History.countyHours()end
local function removeOwned(a)
 local q=ISTimedActionQueue.getTimedActionQueue(a.body)
 if not q then return end
 if q.current==a.action then q:onCompleted(a.action)
 elseif q.removeFromQueue then q:removeFromQueue(a.action)end
end
-- Capture source dependency identities at admission. Mutable physical state remains source-owned.
local DEPENDENCIES={NMCore={"readDrainableFraction","clamp"},NMDeviceTransitions={"apply"},
 NMIntentInventoryOps={"applyTransitionOps","removeItemById","addItemByFullType"},
 NMAttachmentHelpers={"equipHeadphonesByItemId","findWornHeadphones"},NMIntentPayloadBuilder={"buildItemPayload","buildVehiclePayload"},NMInventoryHelpers={"findItemById","collectItemsRecursive"},
 NMMediaHelpers={"resolveMediaInsertPayload"},NMMediaContract={"resolveMediaCarrier","resolveContainerMediaBinding"},
 NMTrackCountResolver={"resolveFromState"},NMInsertedHeadphonePolicy={"isSupported","shouldDetachOnGround"},
 NMWorldItemVisuals={"addItemWithVisual"}}
local function captureDependencies(env)
 local rows={}
 for name,fields in pairs(DEPENDENCIES)do
  local obj=env[name];if type(obj)~="table"then error("supply-source-dependency-unavailable:"..name)end
  local row={name=name,object=obj,fields={}}
  for _,field in ipairs(fields)do row.fields[field]=obj[field]end
  rows[#rows+1]=row
 end
 return rows
end
local function dependenciesCurrent(a)
 for _,row in ipairs(a.dependencies)do
  if a.env[row.name]~=row.object then return false end
  for field,fn in pairs(row.fields)do if row.object[field]~=fn then return false end end
 end
 return true
end
local function context(a)
 if SAO.LeisureMusic~=a.owner or a.owner.supplyContext~=a.query or not dependenciesCurrent(a)then return nil end
 local c=a.query(a.id,a.body,a.workSequence)
 if not c or c.body~=a.body or c.device~=a.device or c.env~=a.env or c.workId~=a.workId or c.purposeId~=a.purposeId
  or c.bodyToken~=a.bodyToken or c.deviceState~=a.deviceState or c.profile~=a.profile or c.contextKey~=a.contextKey
  or c.env.NMClientIntentDispatch.performIntent~=a.intent or c.env.NMClientIntentDispatch.performVehicleIntent~=a.vehicleIntent
  or c.stateOwner~=a.stateOwner or c.stateOwner.export~=a.export or c.stateOwner.peek~=a.peek
  or c.body:isDead()or c.body:isAsleep()or not same(c.supplies,a.selection)then return nil end
 return c
end
local function owned(a)
 local r=record(a.id);return runtime[a.id]==a and r==a.record and r.leisureMusicSupplyWork==a.row
  and a.row.actorId==a.id and a.row.workId==a.workId and a.row.purposeId==a.purposeId
  and a.row.workSequence==a.workSequence and a.row.bodyToken==a.bodyToken and same(a.row.selection,a.selection)
  and a.row.status=="preparing"and context(a)~=nil
end
local function stateSame(a)return same(a.expectedState,a.export(a.deviceState))end
local function supplyCurrent(a)
 if a.selection.battery and not a.batteryInstalled then
  local item=resolve(a.body,a.selection.battery.itemKey)
  if item~=a.battery or NMCore.readDrainableFraction(item,0)~=a.selection.battery.charge then return false end
 end
 if a.selection.media and not a.mediaInstalled then
  if resolve(a.body,a.selection.media.itemKey)~=a.media or not same(mediaPayload(a.media,a.profile,a.device),a.selection.media.payload)then return false end
 end
 if a.selection.headphones and not a.headphonesInstalled and resolve(a.body,a.selection.headphones.itemKey)~=a.headphones then return false end
 if a.headphonesInstalled and a.selection.headphones.itemType=="Base.Headphones"then
  local worn=NMAttachmentHelpers.findWornHeadphones(a.body);if worn~=a.headphones then return false end
 end
 return true
end
local function finish(a,status,reason)
 if runtime[a.id]~=a then return false end
 local measured,after=pcall(a.export,a.deviceState);local currentOk,current=pcall(context,a)
 a.row.status=status;a.row.reason=reason;a.row.atHours=now();a.row.after=measured and copy(after)or copy(a.expectedState)
 a.row.afterCurrent=measured and currentOk and current~=nil;a.row.afterMeasurementAvailable=measured
 local r=record(a.id);r.leisureMusicSupplyOutcomes=r.leisureMusicSupplyOutcomes or {}
 r.leisureMusicSupplyOutcomes[#r.leisureMusicSupplyOutcomes+1]=copy(a.row)
 if #r.leisureMusicSupplyOutcomes>32 then table.remove(r.leisureMusicSupplyOutcomes,1)end
 r.leisureMusicSupplyWork=nil;runtime[a.id]=nil
 if status=="prepared"then a.finalReceipt=copy(a.row);prepared[a.id]=a end
 return true
end
local function loader(env,path)
 local pin=PINS[path];local reader=pin and SAO.SourceIntegration and SAO.SourceIntegration.reader("NewMusic","media/lua/"..path)
 if not reader then error("supply-source-unavailable:"..path)end
 local lines,h1,h2,size={},0,0,0
 local ok,why=pcall(function()while true do local line=reader:readLine();if line==nil then break end;line=tostring(line)
  size=size+#line+1;if size>1048576 then error("supply-source-too-large")end;lines[#lines+1]=line
  for n=1,#line do local b=string.byte(line,n);h1=(h1*31+b)%2147483647;h2=(h2*131+b)%2147483647 end
  h1=(h1*31+10)%2147483647;h2=(h2*131+10)%2147483647
 end end);reader:close();if not ok then error(why)end
 if h1~=pin[2]or h2~=pin[3]or #lines~=pin[4]then error("supply-source-revision-changed:"..path)end
 local fn,err=loadstring(table.concat(lines,"\n").."\n",path);if not fn then error(err)end;setfenv(fn,env);fn()
end
-- Preserve original inventory/attachment effects in the source actor environment.
-- Only presentation receivers are local; native worn/inventory mutations are original source calls.
function S.prepareEnvironment(env)
 env.NMIntentInventoryOps={};env.ISInventoryPage={}
 env.getPlayerInventory=function()return nil end
 loader(env,"shared/intent/NMIntentInventoryOps.lua")
 return true
end
local queueStep
local function queueContains(action)return ISTimedActionQueue.hasAction(action)==true end
local function nativeReady(a)
 local native=a.action and a.action.action
 local actions=a.body:getCharacterActions()
 return native and actions and actions:size()>0 and actions:get(0)==native
  and native.isStarted and native:isStarted()==true and native.getJobDelta and native:getJobDelta()>=.999999
end
local function dispatch(a,action,args)
 if not owned(a)or not stateSame(a)or not supplyCurrent(a)or a.dispatched or not a.started
  or not queueContains(a.action)or not nativeReady(a)or action~=a.step.action then error("supply-callback-owner-lost")end
 local expectedArgs=copy(a.step.args);if not same(args,expectedArgs)then error("supply-callback-arguments-changed")end
 a.dispatched=true
 local before=copy(a.export(a.deviceState));local c=assert(context(a))
 local beforeItems={}for _,item in ipairs(items(a.body))do beforeItems[key(item)]=true end
 local ok,accepted,why=pcall(function()
  if c.target and c.target.part then return a.vehicleIntent(a.body,c.target.vehicle,c.target.part,action,args)end
  return a.intent(a.body,a.device,action,args)
 end)
 local after=copy(a.export(a.deviceState));a.expectedState=copy(after)
 local effect=false;local producedBattery
 if ok and accepted==true then
  if action=="eject_battery"then
   for _,item in ipairs(items(a.body))do
    if not beforeItems[key(item)]and item:getFullType()=="Base.Battery"
     and math.abs(NMCore.readDrainableFraction(item,0)-(before.batteryCharge or 0))<.000001 then
      producedBattery={itemKey=key(item),itemType=item:getFullType(),charge=NMCore.readDrainableFraction(item,0)};break
    end
   end
   effect=after.batteryPresent==false and after.batteryCharge==0 and producedBattery~=nil
  elseif action=="insert_battery"then effect=after.batteryPresent==true and finite(after.batteryCharge)
    and math.abs(after.batteryCharge-a.selection.battery.charge)<.000001 and resolve(a.body,a.selection.battery.itemKey)==nil
    if effect then a.batteryInstalled=true end
  elseif action=="insert_media"then effect=after.mediaFullType==a.selection.media.payload.mediaFullType
    and after.mediaRecordedMediaIndex==a.selection.media.payload.mediaRecordedMediaIndex and resolve(a.body,a.selection.media.itemKey)==nil
    if effect then a.mediaInstalled=true end
  elseif action=="insert_headphones"then
   effect=after.headphoneItemFullType==a.selection.headphones.itemType
   if effect and a.selection.headphones.itemType=="Base.Headphones"then effect=NMAttachmentHelpers.findWornHeadphones(a.body)==a.headphones
   elseif effect then effect=resolve(a.body,a.selection.headphones.itemKey)==nil end
   if effect then a.headphonesInstalled=true end
  end
 end
 a.stepEffect=effect;a.stepFailure=not effect and (not ok and tostring(accepted)or tostring(why or "source-slot-effect-unmeasured"))or nil
 a.row.steps[#a.row.steps+1]={action=action,sourceId="NewMusic",revision=PINS[a.step.path][1],atHours=now(),
  nativeJobDelta=a.action.action:getJobDelta(),nativeStarted=true,sourceAccepted=ok and accepted==true,
  status=effect and"prepared"or"interrupted",before=before,after=after,producedBattery=producedBattery,selection=copy(a.step.selection),reason=a.stepFailure}
 return effect
end
queueStep=function(a)
 a.index=a.index+1;a.step=a.steps[a.index]
 if not a.step then
  if owned(a)and stateSame(a)and supplyCurrent(a)then finish(a,"prepared")else finish(a,"interrupted","supply-final-custody-lost")end
  return true
 end
 if not owned(a)or not stateSame(a)or not supplyCurrent(a)then finish(a,"interrupted","supply-step-custody-lost");return false end
 local env=setmetatable({},{__index=a.env});env._G=env;env.NMBatterySlotEnv=env;env.NMMediaSlotEnv=env;env.NMHeadphoneSlotEnv=env
 env.NMBatterySlotTimedAction=nil;env.NMMediaSlotTimedAction=nil;env.NMHeadphoneSlotTimedAction=nil
 -- Original stop's global reset is scoped to this actor's owned action.
 env.ISBaseTimedAction=ISBaseTimedAction:derive("SAONewMusicSupplyBase")
 env.ISBaseTimedAction.stop=function()removeOwned(a)end
 env.NMSlotHostLifecycle={invalidateForTimedAction=function()end}
 env.playPortableUiSoundEvent=function(_,event)
  a.row.presentation=a.row.presentation or {};if #a.row.presentation<16 then a.row.presentation[#a.row.presentation+1]=event end
 end
 loader(env,a.step.path)
 local Core=a.step.action=="insert_media"and env.NMMediaSlotTimedAction
  or a.step.action=="insert_headphones"and env.NMHeadphoneSlotTimedAction or env.NMBatterySlotTimedAction
 local Action=Core:derive("SAONewMusicOwnedSupply")
 local window={target={kind=a.target and a.target.part and"vehicle"or"item"}}
 window.dispatchSlotAction=function(_,action,args)return dispatch(a,action,args)end
 local act=Action:new(a.body,window,a.step.action,copy(a.step.args));a.action=act;a.started=false;a.dispatched=false;a.stepEffect=false;a.stepFailure=nil
 a.row.phase=a.step.action;a.row.nativeJobDelta=0
 act.isValid=function()return owned(a)and stateSame(a)and supplyCurrent(a)end
 act.start=function(self)
  if not self:isValid()or not queueContains(self)then return end
  a.started=true;Core.start(self)
 end
 act.update=function(self)
  if not a.started or not self:isValid()or not queueContains(self)then return end
  Core.update(self);a.row.nativeJobDelta=self:getJobDelta()
 end
 act.perform=function(self)
  if self~=a.action or a.performed or not a.started or not self:isValid()or not queueContains(self)or not nativeReady(a)then return end
  a.performed=true
  local ok,why=pcall(Core.perform,self)
  if not ok or not a.stepEffect then
   removeOwned(a);finish(a,"interrupted",a.stepFailure or "source-slot-callback-failed:"..tostring(why));return
  end
  a.row.completedSteps=(a.row.completedSteps or 0)+1;queueStep(a)
 end
 act.stop=function(self)
  if self~=a.action or a.stopped then return end;a.stopped=true
  local ok=pcall(Core.stop,self);removeOwned(a);finish(a,"interrupted",ok and"native-slot-stopped"or"native-slot-stop-failed")
 end
 act.forceCancel=function(self)self:stop()end
 a.performed=false;a.stopped=false
 local ok=pcall(ISTimedActionQueue.add,act)
 if not ok or not queueContains(act)then removeOwned(a);finish(a,"interrupted","native-slot-queue-refused");return false end
 return true
end
function S.retireSaved(id,reason)
 if runtime[id]then return false end
 local r=record(id);local saved=r and r.leisureMusicSupplyWork
 if not saved then return false end
 local receipt=copy(saved);receipt.status="interrupted";receipt.reason=reason or"runtime-owner-lost"
 receipt.atHours=now();receipt.afterCurrent=false;receipt.afterMeasurementAvailable=false
 local last=receipt.steps and receipt.steps[#receipt.steps]
 receipt.after=copy(last and last.after or receipt.before)
 receipt.afterAuthority="last-observed-source-state; current-runtime-unavailable"
 r.leisureMusicSupplyOutcomes=r.leisureMusicSupplyOutcomes or{}
 r.leisureMusicSupplyOutcomes[#r.leisureMusicSupplyOutcomes+1]=receipt
 if #r.leisureMusicSupplyOutcomes>32 then table.remove(r.leisureMusicSupplyOutcomes,1)end
 r.leisureMusicSupplyWork=nil;return true
end
function S.begin(id,body,workSequence)
 if runtime[id]or not SAO.LeisureMusic or not SAO.LeisureMusic.supplyContext then return false,"supply-owner-unavailable"end
 prepared[id]=nil
 local owner=SAO.LeisureMusic;local c=owner.supplyContext(id,body,workSequence)
 if not c or not c.supplies or not c.env or not c.deviceState then return false,"supply-binding-unavailable"end
 local r=record(id);if not r then return false,"supply-person-unavailable"end
 S.retireSaved(id,"runtime-owner-lost")
 local captured,a=pcall(function()return {id=id,body=body,record=r,owner=owner,query=owner.supplyContext,workSequence=workSequence,workId=c.workId,purposeId=c.purposeId,
  bodyToken=c.bodyToken,device=c.device,deviceState=c.deviceState,profile=c.profile,contextKey=c.contextKey,target=c.target,
  env=c.env,stateOwner=c.stateOwner,export=c.stateOwner.export,peek=c.stateOwner.peek,
  intent=c.env.NMClientIntentDispatch.performIntent,vehicleIntent=c.env.NMClientIntentDispatch.performVehicleIntent,
  selection=copy(c.supplies),dependencies=captureDependencies(c.env),steps={},index=0,expectedState=copy(c.stateOwner.export(c.deviceState))}end)
 if not captured then return false,"supply-source-binding-failed:"..tostring(a)end
 if a.selection.battery then
  a.battery=resolve(body,a.selection.battery.itemKey)
  if a.selection.battery.ejectExisting then a.steps[#a.steps+1]={action="eject_battery",path="client/ui/shared/slots/NMBatterySlotTimedAction.lua",args={},selection=copy(a.selection.battery)}end
  a.steps[#a.steps+1]={action="insert_battery",path="client/ui/shared/slots/NMBatterySlotTimedAction.lua",args={batteryItemId=a.selection.battery.itemId},selection=copy(a.selection.battery)}
 end
 if a.selection.media then
  a.media=resolve(body,a.selection.media.itemKey)
  a.steps[#a.steps+1]={action="insert_media",path="client/ui/shared/slots/NMMediaSlotTimedAction.lua",args={mediaItemId=a.selection.media.itemId},selection=copy(a.selection.media)}
 end
 if a.selection.headphones then
  a.headphones=resolve(body,a.selection.headphones.itemKey)
  a.steps[#a.steps+1]={action="insert_headphones",path="client/ui/shared/slots/NMHeadphoneSlotTimedAction.lua",args={headphoneItemId=a.selection.headphones.itemId},selection=copy(a.selection.headphones)}
 end
 a.row={actorId=id,workId=c.workId,purposeId=c.purposeId,workSequence=workSequence,sourceId="NewMusic",status="preparing",
  bodyToken=c.bodyToken,deviceUUID=c.deviceState.deviceUUID,contextKey=c.contextKey,admittedAtHours=now(),
  selection=copy(a.selection),before=copy(a.expectedState),steps={}}
 r.leisureMusicSupplyWork=a.row;runtime[id]=a
 local ok,why=pcall(queueStep,a)
 if not ok then removeOwned(a);finish(a,"interrupted","supply-construction-failed:"..tostring(why));return false,"supply-construction-failed"end
 return runtime[id]~=nil or a.row.status=="prepared",copy(a.row)
end
function S.advance(id,body,workSequence)
 local a=runtime[id]
 if a then
  if a.body~=body or a.workSequence~=workSequence then return false,"foreign-supply-work"end
  if not owned(a)or not stateSame(a)or not supplyCurrent(a)or not queueContains(a.action)then S.interrupt(id,body,"supply-custody-lost");return false,"supply-custody-lost"end
  return true,"preparing",copy(a.row)
 end
 local done=prepared[id]
 if done and done.body==body and done.workSequence==workSequence and context(done)and stateSame(done)and supplyCurrent(done)then
  return true,"prepared",copy(done.finalReceipt)
 end
 return false,"supply-work-unavailable"
end
function S.release(id,body,workSequence)
 local done=prepared[id]
 if done and done.body==body and done.workSequence==workSequence then prepared[id]=nil;return true end
 return false
end
function S.current(id,body,workSequence)
 local a=runtime[id];return a and a.body==body and a.workSequence==workSequence and owned(a)and stateSame(a)and supplyCurrent(a)or false
end
function S.interrupt(id,body,reason)
 local a=runtime[id]
 if not a then local done=prepared[id];if done and done.body==body then prepared[id]=nil;return true end;return false end
 if a.body~=body then return false end
 if a.action and not a.stopped then pcall(a.action.stop,a.action)end
 if a.action and a.action.action then pcall(a.action.action.forceStop,a.action.action)end
 removeOwned(a)
 if runtime[id]==a then finish(a,"interrupted",reason or"supply-interrupted")end
 return true
end
function S.reset(reason)
 local pending={}for id,a in pairs(runtime)do pending[#pending+1]={id=id,body=a.body}end
 for _,row in ipairs(pending)do S.interrupt(row.id,row.body,reason or"supply-owner-lost")end
 prepared={}
end
