local M,S=SAO.LeisureMusic,SAO.LeisureMusicSupply
local checks=0
local function check(name,yes)checks=checks+1;assert(yes,"D2_MUSIC_SUPPLY:"..name);print("CASE "..name)end
local previousRequire=require;local loaded={}
require=function(name)
 local k="NewMusic:shared/"..name..".lua"
 if __sources[k]then
  if not loaded[k]then loaded[k]=true;assert(loadstring(__sources[k],k))()end
  return true
 end
 return previousRequire(name)
end
local function source(path)local k="NewMusic:"..path;loaded[k]=true;return assert(loadstring(assert(__sources[k]),path))()end
for _,path in ipairs(__nmModules)do source(path)end
print("SOURCE_MODULES_LOADED")
local store={};ModData={getOrCreate=function(key)store[key]=store[key]or{};return store[key]end}
for _,name in ipairs({"sameNativeLuaSourceFunction","nativeLuaSourceFunctionUsesEnvironment"})do SAOJavaBridge[name]=function(_,...)return __bridge[name](__bridge,...)end end
getActivatedMods=function()return{contains=function()return false end}end
-- This native supply fixture qualifies NewMusic, independently of Lifestyle skill fixtures.
SAO.SourceIntegration.active=function(id)return __active and __tali and id=="NewMusic"end
SAO.SourceIntegration.available=SAO.SourceIntegration.active
local native=__nativeBody
local freshOld=__fresh
local function fresh(kind)
 freshOld();S.reset("fixture-reset");__tali=true;__queued=nil;__actions={};__dead=false;__permission=true
 __body=native;__body:getCharacterActions():clear();__body:getInventory():getItems():clear()
 __body:setPrimaryHandItem(nil);__body:setSecondaryHandItem(nil);__body:getWornItems():clear();__body:setHealth(1)
 local md=__body:getModData();md.SAOPersonId="person";md.SAOExternalToken="supply:body:1"
 __emitter:reset();__stats=__body:getStats();__items={}
 local function add(fulltype)local it=__newItem(fulltype);__body:getInventory():AddItem(it);return it end
 __device=add(kind or "NewMusic.WalkmanBlue");SAO.Perception.leisureAudioSources=function()return{}end
 __battery=add("Base.Battery");__battery:setCurrentUsesFloat(.8)
 __media=add("NewMusic.CassettePZOSTA");__headphones=add("Base.Earbuds")
 local st={deviceUUID="supply:uuid:1",revision=1,playbackEpoch=0,sourceGeneration=1,batteryPresent=false,batteryCharge=0,
 mediaFullType=nil,volume=1,isPlaying=false,isOn=false,trackIndex=1,trackCount=0,_headphoneSlotInitialized=true}
 __device:getModData().nm_device_state=st
 SAO.Needs.ownsRecoveryBody=function(id,b)return id=="person"and b==__body and __owned end
 SAO.Needs.workAvailable=function()return __queued==nil end
 SAOJavaBridge.privateCarriedItems=function(_,b)return b:getInventory():getItems()end
 SAO.Standing={mayEnterCurrent=function()return __permission end}
 return st
end
ISTimedActionQueue.add=function(a)if __queueRefusal then return end;__queued=a;__nativeQueue(a)end
ISTimedActionQueue.hasAction=function(a)return __queued==a end
ISTimedActionQueue.getTimedActionQueue=function()return{current=__queued,onCompleted=function(_,a)if __queued==a then __queued=nil end end,
 removeFromQueue=function(_,a)if __queued==a then __queued=nil end end,resetQueue=function()error("unowned queue reset")end}end
local function offer()
 for _,o in ipairs(M.offers("person",__body))do if o.sourceId=="NewMusic"then return o end end
end
local function begin()
 local o=assert(offer(),"preparable offer absent");local ok,w=M.begin("person",__body,o,"purpose:1");assert(ok,tostring(w));return w,o
end
local function completeStep()
 local old=assert(__queued);for n=1,400 do __nativeUpdate(__body);if old.action:getJobDelta()>=1 then break end end
 assert(old.action:getJobDelta()>=.999999,"native elapsed slot duration missing")
 __nativePerform(__body);return old
end
local st=fresh();local o=offer();local rr,why=M.offers("person",__body);assert(o,"initial offer absent:"..tostring(why).." profiles:"..tostring(NMDeviceProfiles.getForItem(__device)).." plan:"..tostring(S.plan(__body,__device,NMDeviceProfiles.getForItem(__device),st,"stowed")))
check("exact_supply_IDs_and_material_keys",o.sourceSupplies.battery.itemId==tostring(__battery:getID())and o.sourceSupplies.media.itemId==tostring(__media:getID())
 and o.materials.battery.id==tostring(__battery:getID())and o.materials.headphones.id==tostring(__headphones:getID()))
local w=begin();check("typed_admission_before_slots",M.supplyContext("person",__body,w.sequence)and __queued and not st.isPlaying)
check("original_battery_duration",__queued.maxTime==80)
check("queued_is_not_completion",M.outcome("person",w.sequence)==nil and #__records.person.leisureMusicSupplyWork.steps==0)
local old=completeStep();print("BATTERY_RESULT "..tostring(st.batteryPresent).." "..tostring(st.batteryCharge).." "..tostring(__body:getInventory():contains(__battery)));for _,r in ipairs(__records.person.leisureMusicSupplyOutcomes or{})do print("SUPPLY_OUT "..tostring(r.reason));for _,step in ipairs(r.steps)do print("STEP "..tostring(step.sourceAccepted).." "..tostring(step.reason))end end;check("actual_native_battery_consumed",st.batteryPresent and math.abs(st.batteryCharge-o.sourceSupplies.battery.charge)<.000001 and not __body:getInventory():contains(__battery))
check("original_media_duration",__queued.maxTime==40);completeStep()
check("actual_native_media_consumed",st.mediaFullType=="NewMusic.CassettePZOSTA"and not __body:getInventory():contains(__media))
check("original_headphones_duration",__queued.maxTime==50);completeStep()
check("actual_native_Earbuds_consumed",st.headphoneItemFullType=="Base.Earbuds"and not __body:getInventory():contains(__headphones))
check("preparation_not_leisure_completion",M.outcome("person",w.sequence)==nil and not st.isPlaying and #__records.person.leisureMusicSupplyOutcomes==1)
local ok,phase,receipt=S.advance("person",__body,w.sequence);check("prepared_canonical_receipt",ok and phase=="prepared"and receipt.completedSteps==3 and receipt.steps[1].nativeStarted)
receipt.status="forged";check("detached_supply_receipt",select(3,S.advance("person",__body,w.sequence)).status=="prepared")
local ok,why=M.advance("person",__body);check("fresh_offer_original_playback_after_slots",ok and st.isPlaying)
check("fresh_offer_original_playback_after_slots",st.isPlaying and M.work("person").nativeProgress.sourceSupplyPreparation.completedSteps==3)
check("no_prep_XP_or_outcome",__skillRequests==0 and __consumed==0)
old:perform();check("slot_replay_no_duplicate_effect",#__records.person.leisureMusicSupplyOutcomes==1)
M.interrupt("person",__body,"test-done")
st=fresh();__admit=false;local initial=__body:getInventory():getItems():size();o=offer()
check("typed_refusal_prevents_source_effects",not M.begin("person",__body,o,"purpose:1")and not st.batteryPresent and __queued==nil and __body:getInventory():getItems():size()==initial)
st=fresh();__body:getInventory():DoRemoveItem(__battery);check("missing_battery_no_offer",offer()==nil)
st=fresh();__battery:setCurrentUsesFloat(0);check("empty_battery_no_offer",offer()==nil)
st=fresh();__body:getInventory():DoRemoveItem(__headphones);check("required_headset_no_offer",offer()==nil)
st=fresh();w=begin();__body:getInventory():DoRemoveItem(__media);__nativeUpdate(__body);M.advance("person",__body)
check("lost_unconsumed_supply_interrupts",M.outcome("person",w.sequence).status=="interrupted"and not st.batteryPresent)
st=fresh();w=begin();local saved=__queued;__admit=false;completeStep();check("retired_purpose_no_original_dispatch",not st.batteryPresent);M.advance("person",__body)
check("retired_purpose_interrupts",M.outcome("person",w.sequence).status=="interrupted"and not st.batteryPresent)
st=fresh();w=begin();completeStep();S.interrupt("person",__body,"partial-stop")
check("partial_physical_prep_retained",st.batteryPresent and st.mediaFullType==nil and __body:getInventory():contains(__media)and not __body:getInventory():contains(__battery))
check("partial_receipt_measured",__records.person.leisureMusicSupplyOutcomes[1].completedSteps==1)
M.interrupt("person",__body,"test-done")
st=fresh();st.batteryPresent=true;st.batteryCharge=0;w=begin();check("exhausted_slot_original_eject_first",__queued.actionName=="eject_battery");completeStep()
check("ejected_native_battery_receipt",__records.person.leisureMusicSupplyWork.steps[1].producedBattery and __records.person.leisureMusicSupplyWork.steps[1].producedBattery.charge==0)
M.interrupt("person",__body,"test-done")
st=fresh();w=begin();__sourceDrift=true;completeStep();M.advance("person",__body)
check("changed_source_refused",(M.outcome("person",w.sequence)or{}).status=="interrupted")
-- Pure installed-source previews and contextual missing requirements.
st=fresh();local bridgeItems=SAOJavaBridge.privateCarriedItems;SAOJavaBridge.privateCarriedItems=function()error("preview read private inventory")end
local identity=SAO.Identity.get;SAO.Identity.get=function()error("preview read private person")end
local function requirements(fulltype,activity)
 local out={}for _,r in ipairs(M.materialRequirementsForType(nil,fulltype))do if not activity or r.activity==activity then out[#out+1]=r end end;return out
end
check("pure_headphone_original_policy",#requirements("Base.Headphones")==2 and #requirements("Base.Earbuds")==2 and #requirements("Base.Whistle")==0)
check("pure_media_battery_context_activities",#requirements("Base.Battery")==2 and #requirements("NewMusic.CassettePZOSTA")==2)
check("pure_unpreparable_device_pruned",#requirements("NewMusic.BoomboxBlue")==0 and #requirements("NewMusic.WalkmanBlue")==1)
SAO.Identity.get=identity;SAOJavaBridge.privateCarriedItems=bridgeItems
local br=requirements("Base.Battery","listen-recorded-music")[1];local publicBr=requirements("Base.Battery","listen-source-world-music")[1]
check("carried_backup_prevents_acquisition",not M.materialRequirementAvailable("person",__body,br))
__body:getInventory():DoRemoveItem(__battery)
check("missing_carried_supply_context",M.materialRequirementAvailable("person",__body,br))
__body:getInventory():DoRemoveItem(__media)
local function aggregateRequirement(activity)
 for _,r in ipairs(__bridge:leisureMaterialRequirements(__body,"NewMusic.CassettePZOSTA"))do
  if r.owner=="SAO.LeisureMusic"and r.activity==activity then return r end
 end
end
local aggregatePrivate=assert(aggregateRequirement("listen-recorded-music"))
check("native_aggregate_preserves_private_carrier",aggregatePrivate.carrier==NMMediaContract.CASSETTE_CARRIER and M.materialRequirementAvailable("person",__body,aggregatePrivate))
check("public_requirement_not_private_context",not M.materialRequirementAvailable("person",__body,publicBr))
st.batteryPresent=true;st.batteryCharge=.4;check("fulfilled_context_no_acquisition",not M.materialRequirementAvailable("person",__body,br))
-- Only original source-supported headset install performs actual native wear.
st=fresh();__body:getInventory():DoRemoveItem(__headphones);__headphones=__newItem("Base.Headphones");__body:getInventory():AddItem(__headphones)
ISInventoryPage={renderDirty=false};getPlayerInventory=function()error("operator inventory page escaped isolation")end
w=begin();local headContext=M.supplyContext("person",__body,w.sequence);local visual,visualWhy=NMWorldItemVisuals.ensureVisual(__headphones);print("HEAD_VISUAL "..tostring(visual).." "..tostring(visualWhy).." location:"..tostring(__headphones:getBodyLocation()));completeStep();completeStep();completeStep()
for _,rr in ipairs(__records.person.leisureMusicSupplyOutcomes or{})do print("HEADPHONE_OUT "..tostring(rr.reason));for _,step in ipairs(rr.steps)do print("HEADPHONE_STEP "..tostring(step.action).." "..tostring(step.reason))end end
check("original_native_headphones_worn",NMAttachmentHelpers.findWornHeadphones(__body)==__headphones and __body:getInventory():contains(__headphones))
check("operator_UI_not_mutated",ISInventoryPage.renderDirty==false)
__body:getWornItems():clear();check("prepared_headphones_loss_refused",not S.advance("person",__body,w.sequence));M.advance("person",__body)
check("headphone_loss_not_listening_success",M.outcome("person",w.sequence).status=="interrupted"and not st.isPlaying)
st=fresh();w=begin();local a=__queued;__nativeUpdate(__body);a:perform()
check("partial_native_elapsed_cannot_dispatch",not st.batteryPresent and __body:getInventory():contains(__battery))
check("foreign_body_supply_refused",not S.advance("person",__other,w.sequence)and M.work("person")~=nil)
__body:getModData().SAOExternalToken="replacement";M.advance("person",__body)
check("replaced_body_token_refused",not st.batteryPresent and M.outcome("person",w.sequence).status=="interrupted")
st=fresh();w=begin();st.revision=st.revision+1;completeStep();check("changed_source_no_original_dispatch",not st.batteryPresent);M.advance("person",__body)
check("source_state_changed_refused",not st.batteryPresent and M.outcome("person",w.sequence).status=="interrupted")
st=fresh();w=begin();local ctx=M.supplyContext("person",__body,w.sequence);ctx.env.NMIntentInventoryOps.applyTransitionOps=function()return true end;M.advance("person",__body)
check("source_dependency_changed_refused",not st.batteryPresent and M.outcome("person",w.sequence).status=="interrupted")
st=fresh();w=begin();__body:setHealth(0);M.advance("person",__body)
check("death_no_source_effects",not st.batteryPresent and __body:getInventory():contains(__battery)and M.outcome("person",w.sequence).status=="interrupted")
st=fresh();w=begin();completeStep();local selected=__media;__body:getInventory():DoRemoveItem(selected)
__media=__newItem("NewMusic.CassettePZOSTA");__media:setID(selected:getID());__body:getInventory():AddItem(__media);completeStep()
check("native_same_ID_replacement_refused",not st.mediaFullType and __body:getInventory():contains(__media));M.advance("person",__body)
st=fresh();w=begin();completeStep();__milliseconds=100100;local pending=__queued
local follower={tag="other-owner"};local qOld=ISTimedActionQueue.getTimedActionQueue;local followerRemoved=false
ISTimedActionQueue.getTimedActionQueue=function(body)return{current=pending,onCompleted=function(_,a)if a==pending then __queued=follower else followerRemoved=true end end,
 removeFromQueue=function(_,a)if a==pending then __queued=follower else followerRemoved=true end end,resetQueue=function()followerRemoved=true;__queued=nil end}end
S.interrupt("person",__body,"urgent-need")
check("partial_stop_preserves_queue_follower",__queued==follower and not followerRemoved and __forceStopped(pending.action) and st.batteryPresent and not st.mediaFullType)
ISTimedActionQueue.getTimedActionQueue=qOld;__queued=nil;M.interrupt("person",__body,"fixture-done")
st=fresh();w=begin();__nativeRemoveFault(__battery:getID());completeStep();__nativeRemoveFault(-1)
check("actual_native_effect_callback_fault_interrupts",__records.person.leisureMusicSupplyOutcomes[1].status=="interrupted"and __body:getInventory():contains(__battery))
check("callback_fault_no_false_listening",not st.isPlaying and S.advance("person",__body,w.sequence)==false)
M.advance("person",__body);check("callback_fault_main_owner_interrupts",M.outcome("person",w.sequence).status=="interrupted")
-- Restart snapshot contains actual completed battery slot plus unfinished media slot.
st=fresh();w=begin();completeStep();__nativeUpdate(__body);local saved=__roundtrip(__records.person.leisureMusicSupplyWork)
M.reset("fixture-process-restart");S.reset("fixture-process-restart");__queued=nil;__body:getCharacterActions():clear()
__records.person.leisureMusicSupplyOutcomes={};__records.person.leisureMusicSupplyWork=saved
assert(loadstring(__sources["own:supply"]))();S=SAO.LeisureMusicSupply
local newWork=begin();local oldReceipt=__records.person.leisureMusicSupplyOutcomes[1]
check("orphan_partial_saved_steps_retained",oldReceipt and oldReceipt.reason=="runtime-owner-lost"and oldReceipt.completedSteps==1 and oldReceipt.steps[1].after.batteryPresent)
check("orphan_no_fabricated_current_measurement",oldReceipt.afterCurrent==false and oldReceipt.afterMeasurementAvailable==false and not st.isPlaying)
check("orphan_fresh_actual_remaining_slot",__queued.actionName=="insert_media"and not __records.person.leisureMusicSupplyWork.selection.battery)
M.interrupt("person",__body,"fixture-done")
-- Actual Planner and acquisition-purpose caller join. Incoming acquisition receipt is a controlled transport seam;
-- source slot effects, inventory, native actions and installed media catalogue above remain native.
SAO.ProceduralPlanning={};assert(loadstring(__sources["own:planner"]))();assert(loadstring(__sources["own:acquisition"]))()
local P,A=SAO.ProceduralPlanning,SAO.LeisureAcquisition
SAOJavaBridge.leisureMaterialRequirements=function(_,body,itemType)
 return __bridge:leisureMaterialRequirements(body,itemType)
end
-- The Java type preview stays person-free; Acquisition adds the actor's
-- interest and physical context before a recorded dance item is selectable.
st=fresh();local availableSource=SAO.SourceIntegration.available
SAO.SourceIntegration.available=function(id)return availableSource(id)or id=="LifestyleHobbies"end
local function acquiredRequirement(itemType,activity)
 for _,row in ipairs(A.requirements("person",__body,itemType))do
  if row.owner=="SAO.LeisureMusic"and row.activity==activity then return row end
 end
end
local danceDevice=acquiredRequirement("NewMusic.WalkmanBlue","dance-to-recorded-music")
check("native_dance_device_acquisition_preview",danceDevice and danceDevice.role=="playable-item"
 and danceDevice.itemType=="NewMusic.WalkmanBlue"and acquiredRequirement("NewMusic.WalkmanBlue","listen-recorded-music"))
__familiar=false
check("native_missing_personal_concept_refuses_dance_device",not acquiredRequirement("NewMusic.WalkmanBlue","dance-to-recorded-music"))
__familiar=true
local danceBattery=acquiredRequirement("Base.Battery","dance-to-recorded-music")
local danceMedia=acquiredRequirement("NewMusic.CassettePZOSTA","dance-to-recorded-music")
check("native_carried_supply_prevents_dance_acquisition",not danceBattery and not danceMedia)
__body:getInventory():DoRemoveItem(__battery);__body:getInventory():DoRemoveItem(__media)
danceBattery=acquiredRequirement("Base.Battery","dance-to-recorded-music")
danceMedia=acquiredRequirement("NewMusic.CassettePZOSTA","dance-to-recorded-music")
check("native_missing_supplies_admit_dance_acquisition",danceBattery and danceBattery.role=="material"
 and danceMedia and danceMedia.role=="material"and danceMedia.carrier==NMMediaContract.CASSETTE_CARRIER)
st=fresh();__body:getInventory():DoRemoveItem(__headphones)
local danceHeadphones=acquiredRequirement("Base.Earbuds","dance-to-recorded-music")
check("native_missing_headphones_admit_dance_acquisition",danceHeadphones and danceHeadphones.role=="material"
 and danceHeadphones.requirementId=="source-audio-headphones:dance")
SAO.SourceIntegration.available=availableSource
local function acquired(offer,item,activity)
 local purpose=assert(P.maintain("person",{key="native-supply-acquired",domain="leisure",objective="get supply"}))
 local result={status="completed",operation="acquire",measurement="native-item-transfer",observedQuantity=1,preRevision="native-prior-receipt",
 at=__hours,purposeId=purpose.id,itemId=item:getID(),itemType=item:getFullType(),sourceId="prior-exact-source"}
 purpose.leisureAcquisition={itemId=tostring(item:getID()),itemType=item:getFullType(),owner="SAO.LeisureMusic",kind=activity,
 resultId="prior:receipt",revision=result.preRevision,sourceId=result.sourceId}
 purpose.steps={{id="acquire-leisure-item",status="completed",owner="SAO.SourceUse"}};purpose.cursor=2
 SAO.WorldSources={actionOutcome=function(rid,id)return rid=="prior:receipt"and id=="person"and result or nil end}
 local bound=A.acquiredPurpose("person",__body,"SAO.LeisureMusic",offer)
 return purpose,bound
end
st=fresh();o=assert(offer());local p,b=acquired(o,__media,o.activity)
check("actual_A_P_carried_retained_supply_purpose",b and b.id==p.id)
local wrong={};for k,v in pairs(o)do wrong[k]=v end;wrong.activity="listen-source-world-music"
check("actual_A_P_cross_activity_refused",A.acquiredPurpose("person",__body,"SAO.LeisureMusic",wrong)==nil)
local chosen=assert(P.planLeisure("person",{activity=o.activity,activityKey=o.id,itemKey=o.itemKey,owner="SAO.LeisureMusic",
 affordance=o.sourceId,acquiredPurposeId=p.id,atLocation=true,locationKey="actual-native-device-place"}))
check("actual_P_same_purpose_before_native_slots",chosen==p)
local ok,nw=M.begin("person",__body,o,p.id);assert(ok,tostring(nw));completeStep();completeStep();completeStep();M.advance("person",__body)
check("actual_P_admission_survives_consumed_supplies",P.hobbyAdmission("person",p.id,nw.workId)and M.work("person").purposeId==p.id and st.isPlaying)
M.advance("person",__body);__emitter:finish();M.advance("person",__body);__milliseconds=__milliseconds+2000;M.advance("person",__body);__milliseconds=__milliseconds+2000;M.advance("person",__body)
check("actual_P_source_terminal_consumed",M.outcome("person",nw.sequence)and M.outcome("person",nw.sequence).status=="completed"and p.status=="completed")
-- Public placed source uses the actual native world item and original scheduler/intent.
st=fresh("NewMusic.BoomboxBlue");local object=__placed(__device);local sq=object:getSquare()
local obs={key="native-placed:1",actorId="person",sourceKind="placed",itemKey=tostring(__device:getID()),itemType=__device:getFullType(),x=sq:getX(),y=sq:getY(),z=0}
SAO.Perception.leisureAudioSources=function()return{obs}end
SAO.Perception.resolveLeisureAudioSource=function(id,body,k)return id=="person"and body==__body and k==obs.key and{object=object,item=__device}or nil end
SAO.Perception.canHearLeisureSource=function()return true end
local publicAggregate=assert(aggregateRequirement("listen-source-world-music"));__body:getInventory():DoRemoveItem(__media)
check("native_aggregate_preserves_public_carrier",M.materialRequirementAvailable("person",__body,publicAggregate));__body:getInventory():AddItem(__media)
local rows,why=M.offers("person",__body);o=assert(offer(),"public original preparable offer missing:"..tostring(why).." item:"..tostring(__device:getWorldItem()).." obj:"..tostring(object:getItem()==__device).." plan:"..tostring(S.plan(__body,__device,NMDeviceProfiles.getForItem(__device),st,"placed")));p,b=acquired(o,__media,o.activity)
check("actual_A_P_public_retained_supply_purpose",o.activity=="listen-source-world-music"and b and b.id==p.id)
assert(P.planLeisure("person",{activity=o.activity,activityKey=o.id,itemKey=o.itemKey,owner="SAO.LeisureMusic",affordance=o.sourceId,
 acquiredPurposeId=p.id,atLocation=true,locationKey="actual-native-public-place"}))
ok,nw=M.begin("person",__body,o,p.id);assert(ok,tostring(nw));completeStep();completeStep();ok=M.advance("person",__body);assert(ok,"public source prep advance")
check("actual_public_original_slots_and_playback",st.isPlaying and M.work("person").purposeId==p.id and M.work("person").nativeProgress.sourceSupplyPreparation.completedSteps==2)
M.interrupt("person",__body,"fixture-done")
-- Native vehicle/part/passenger context and strict acquired-purpose binding, separate from vehicle slot effects.
st=fresh();__body:getInventory():DoRemoveItem(__device);__device=__newItem("Base.RadioBlack");__body:getInventory():AddItem(__device)
local target=__vehicleSource(__device);local vehicle,part=target.vehicle,target.part
part:getModData().nm_device_state=st
obs={key="native-vehicle:1",actorId="person",sourceKind="vehicle",itemKey=tostring(__device:getID()),itemType=__device:getFullType(),
 vehicleId=tostring(vehicle:getId()),vehicleSqlId=tostring(vehicle:getSqlId()),partId="Radio",x=vehicle:getX(),y=vehicle:getY(),z=0}
SAO.Perception.leisureAudioSources=function()return{obs}end
SAO.Perception.resolveLeisureAudioSource=function(id,body,k)return id=="person"and body==__body and k==obs.key and target or nil end
__body:getInventory():DoRemoveItem(__media)
check("native_vehicle_public_material_context",M.materialRequirementAvailable("person",__body,publicAggregate))
check("native_vehicle_private_activity_refused",not M.materialRequirementAvailable("person",__body,aggregatePrivate))
__body:setVehicle(nil);check("native_vehicle_nonoccupant_context_refused",not M.materialRequirementAvailable("person",__body,publicAggregate));__body:setVehicle(vehicle)
__body:getInventory():AddItem(__media);o=assert(offer(),"native vehicle preparable offer missing")
p,b=acquired(o,__media,o.activity)
check("actual_A_P_vehicle_retained_supply_purpose",o.sourceContext=="vehicle"and o.activity=="listen-source-world-music"and b and b.id==p.id and o.materials.media.id==tostring(__media:getID()))
wrong={};for k,v in pairs(o)do wrong[k]=v end;wrong.activity="listen-recorded-music"
check("actual_A_P_vehicle_cross_activity_refused",not A.acquiredPurpose("person",__body,"SAO.LeisureMusic",wrong))
vehicle:clearPassenger(0);__body:setVehicle(nil)
print("PASS D2 native Music supply "..checks)
