local function reviewCorrections()
local function check(n,v)print("CHECK ordinary_"..n.."="..tostring(v==true));assert(v,n)end
local id="utility-owner";local rec=__record;local H,N,R,P=SAO.HouseholdService,SAO.NetworkWork,SAO.ResourceProduction,SAO.ProceduralPlanning
SAO.Controller.agents[id]=nil
SAO.Controller={agents={[id]={rec=rec}}} -- Declared controlled physical-layer actor endpoint; original dispatcher has no agent.
-- Explicit controlled current-request/admission ports for physical-layer review only.
P.admitNetworkWork=function(actor,w)return actor==id and rec.resourceProductionWork==w end
P.networkRequestCurrent=function(actor,w)return actor==id and rec.resourceProductionWork==w end
P.consumeNetworkResult=function(actor,row)return actor==id and N.outcome(id,row.id)==row end
local tool=__reviewInputs.tool
local function endNative(a)
 if not a.action:isStarted()then a.action:start()end;a.action:forceComplete();if a.update then a:update()end;a.action:perform();a.action:complete();body:getCharacterActions():remove(a.action)
end
local function effect(op,site,item,part,object)
 __moveUtilityBody(site.x,site.y,site.z)
 local step={owner="SAO.ResourceProduction",productionKind="network-operation",operation=op,site=site,itemId=item and tostring(item:getID()),toolItemId=tostring(tool:getID()),toolItemType=tool:getFullType()}
 if op=="attach"then step.source=SAOJavaBridge:networkFluidObservation(body,object)end
 assert(R.begin(id,body,step,{tool=tool,item=item,part=part,object=object,purposeId="controlled-review-hardware",purposeStepId=op}),"queue "..op)
 local work=rec.resourceProductionWork;local a=ISTimedActionQueue.getTimedActionQueue(body).current;assert(a.action:getTable()==a);endNative(a)
 local row=R.outcome(id,work.id);assert(row and row.status=="completed"and row.nativeCredit==row.id and row.paymentMeasured,"canonical "..op)
 return row
end
local function place(kind,axis,x,y,item)
 __moveUtilityBody(x,y,0);local site=SAOJavaBridge:networkSite(body,kind,axis,x,y,0);assert(site,"native site "..kind..x..y);return effect("place",site,item)
end
local pump=place("pump","x",13,22,__reviewInputs.pump)
local riser=place("riser","x",12,22,__reviewInputs.riser)
place("floor","y",13,21,__reviewInputs.bypass1)
place("floor","x",13,21,__reviewInputs.bypass2)
place("floor","y",14,21,__reviewInputs.bypass3)
place("floor","x",14,22,__reviewInputs.tail)
place("floor","x",12,22,__reviewInputs.feed)
effect("attach",{kind="source",axis="x",x=15,y=22,z=0},nil,nil,__scene.pump)
effect("attach",{kind="source",axis="x",x=12,y=22,z=1},nil,nil,__scene.header)
local object=H.currentPart(pump.part)
local off=effect("deactivate",pump.site or{kind="pump",axis="x",x=13,y=22,z=0},nil,pump.part,object)
local c=H.connection(13,22,0)
check("review_paid_bypass_connected",c and H.currentBuiltEndpoint(12,22,1)==true and H.isIncluded(__scene.pump))
raise("OnTick",1)
check("review_disabled_no_lift",__scene.pump:getFluidAmount()==4 and __scene.header:getFluidAmount()==0)
local on=effect("activate",{kind="pump",axis="x",x=13,y=22,z=0},nil,off.part,object)
local a=ISActivateGenerator:new(body,__scene.generator,false);ISTimedActionQueue.add(a);endNative(a)
check("review_native_power_off",object:getSquare():haveElectricity()==false and __scene.generator:isActivated()==false)
raise("OnTick",2)
check("review_unpowered_no_lift",__scene.pump:getFluidAmount()==4 and __scene.header:getFluidAmount()==0 and #H.connection(13,22,0).pumps==0)
a=ISActivateGenerator:new(body,__scene.generator,true);ISTimedActionQueue.add(a);endNative(a)
raise("OnTick",3)
check("review_powered_conserved_lift",object:getSquare():haveElectricity()==true and #H.connection(13,22,0).pumps==1 and __scene.pump:getFluidAmount()==0 and __scene.header:getFluidAmount()==4 and __scene.header:isTaintedWater())
__utilityWriteProjection("review-hardware",{record=rec,part=pump.part,donor=__utilityNativeSourceFacts(__scene.pump),header=__utilityNativeSourceFacts(__scene.header),scope="Controlled P request/admission physical-layer only"})

-- Actual signed visible-ground source and current original registered input.
local WS,SU,Perc=SAO.WorldSources,SAO.SourceUse,SAO.Perception
__moveUtilityBody(12,22,0)
assert(Perc.observeLooseItems(id,body,SAO.History.ticks()),"native ground observation")
local item=__reviewInputs.riser;local installed=H.currentPart(riser.part);local token=item:getModData().SAOWorldItemSourceId;assert(token)
local sourceId="G:"..token;local source=WS.source(sourceId);assert(source,"signed source")
local place=Perc.knownPlaces(id,true)["source:"..sourceId];assert(place and place.sourceFacts[sourceId],"actual private source")
local native=SAOJavaBridge:recipeSupplyNeeds(body,"SAO.MakeWaterPump");local slot
for _,v in ipairs(native.slots)do if string.find(v.declaration,"Base.MetalPipe",1,true)then slot=v;break end end
assert(slot,"original native pipe slot")
local requirement={recipeId=native.recipeId,index=slot.index,declaration=slot.declaration,sourceRevision=native.nativeRevision,demandId="controlled-review-input",purposeId="controlled-review-recipe",stepId="controlled-review-acquire",amount=slot.requiredAmount,itemTypes={item:getFullType()}}
P.recipeInputAdmission=function(actor,demand,purpose,step,recipe,index,declaration)return actor==id and demand==requirement.demandId and purpose==requirement.purposeId and step==requirement.stepId and recipe==requirement.recipeId and index==requirement.index and declaration==requirement.declaration end
P.noteAdmission=function(actor,purpose,owner,reservation,step)return actor==id and purpose==requirement.purposeId and owner=="SAO.SourceUse"and step==requirement.stepId and WS.reservation(reservation)~=nil end
local observation=SAOJavaBridge:recipeInputObservation(body,source.id,source.fingerprint,source.revision,requirement.recipeId,requirement.index,requirement.declaration,requirement.demandId,requirement.purposeId,requirement.stepId)
local offered,why=WS.recipeSlotOptions(place,"recipe-input",id,body,requirement,"standing")
__utilityWriteProjection("review-recipe-source",{record=rec,source=source,privatePlace=place,requirement=requirement,nativeObservation=observation,offers=offered,why=why,currentInstalled=installed==item:getWorldItem(),marker=item:getModData().SAOWaterNetworkPart})
if __utilityControl=="recipe-observation"then check("review_installed_observation_refused",observation==nil and offered==nil);return end
if __utilityCase=="recipe-mutation"or __utilityControl=="recipe-transfer"then
 assert(observation and offered,"native omission prerequisite")
 local packet=SAOJavaBridge:observeWorldChunk(1,2);local parsed,reason=WS.parse(packet);__utilityWriteProjection("review-pre-source",{packet=packet,parseReason=reason,parsed=parsed})
 local yes,res=SU.beginAcquisition(id,body,place,"recipe-input",{recipeRequirement=requirement,purposeId=requirement.purposeId,purposeStepId=requirement.stepId,sourceId=source.id,itemId=tostring(item:getID()),itemType=item:getFullType(),sourceRevision=source.revision})
 assert(yes,"source admission "..tostring(res));assert(SU.onMovementDone(id,body,"arrived")=="using","native exact queue")
 local a=ISTimedActionQueue.getTimedActionQueue(body).current;assert(a and a.action:getTable()==a,"actual retained native queue")
 if not a.action:isStarted()then a.action:start()end
 a:transferItem(installed)
 local retained=H.currentPart(riser.part)==installed and not body:getInventory():contains(item)
 __utilityWriteProjection("review-recipe-mutation",{retained=retained,held=body:getInventory():contains(item),marker=item:getModData().SAOWaterNetworkPart,reservation=res,work=riser})
 check("review_installed_mutation_refused",retained)
 body:StopAllActionQueue();ISTimedActionQueue.getTimedActionQueue(body):resetQueue();SU.interrupt(id,body,"review-mutation-end")
else
 check("review_installed_observation_refused",observation==nil and offered==nil and source.items[tostring(item:getID())]==nil)
 check("review_installed_admission_refused",SU.beginAcquisition(id,body,place,"recipe-input",{recipeRequirement=requirement,purposeId=requirement.purposeId,purposeStepId=requirement.stepId})==false and H.currentPart(riser.part)==installed)
end
local removed=effect("remove",{kind="riser",axis="x",x=12,y=22,z=0},nil,riser.part,installed)
check("review_authorized_exact_recovery",removed.nativeCredit==removed.id and body:getInventory():contains(item)and item:getWorldItem()==nil and item:getModData().SAOWaterNetworkPart==nil and not H.currentPart(riser.part))
check("review_recovered_same_recipe_stock",H.networkStockAvailable(item)==true and SAO.RecipePolicy.inputEligible(requirement,item,body)==true)
local supplied=SAOJavaBridge:recipeSupplyNeeds(body,requirement.recipeId);local found=false
for _,v in ipairs(supplied.slots)do if v.index==requirement.index then for _,held in ipairs(v.heldItems)do if held.itemId==tostring(item:getID())then found=true end end end end
check("review_native_recovered_allocation",found)
__utilityWriteProjection("review-recipe-recovery",{record=rec,canonical=removed,itemId=tostring(item:getID()),marker=item:getModData().SAOWaterNetworkPart,nativeSupply=supplied,scope="Controlled exact current recipe demand; actual private ground observation, original Native GRAB recovery and allocation"})

end
if __utilityCase=="review-corrections"or __utilityCase=="recipe-mutation"then reviewCorrections();return end
local function check(name,value)print("CHECK ordinary_"..name.."="..tostring(value==true));assert(value,name)end
local id="utility-owner";local rec=SAO.Identity.get(id);local Ctl,P,H=SAO.Controller,SAO.ProceduralPlanning,SAO.HouseholdService
check("actual_identity",rec==__record and SAO.Body.get(id)==body and body:getModData().SAOExternalToken==nil)
check("actual_default_models",SAO.Cognition.ensureGameDefaults())
local agent={rec=rec,state="IDLE",stateSince=0,nextDecisionAt=0};Ctl.agents[id]=agent
local needs=SAO.Needs.read(body)
check("initial_missing_network",H.connection(10,20,0)==nil and not body:isRecipeActuallyKnown("Generator")and body:getInventory():getCountTypeRecurse("Base.PipeWrench")==0)
local demand=Ctl.beginHydrationAcquisition(id,agent,body,SAO.History.ticks(),needs)
local parent,step=P.resourceDemand(id,"water",true)
print("ORDINARY_INITIAL_PARENT",demand,parent and parent.id,step and step.verb,step and step.status,agent.state)
check("original_water_parent",parent~=nil)
local guardedDone=false;local replacement=false
function __utilityReplaceOriginalRequest()
 if replacement then return true end
 local revision=parent.revision;local p=P.maintain(id,{key=parent.key,objective=parent.objective.." (original request definition replaced)",domain=parent.domain,origin="negative-original-request-replacement",atHours=SAO.History.countyHours()})
 replacement=p==parent and parent.revision==revision+1
 return replacement
end
local function performNative(action)
 if not action.action:isStarted()then action.action:start()end
 action.action:forceComplete();if action.update then action:update()end;action.action:perform();action.action:complete();body:getCharacterActions():remove(action.action)
end
local function parentBoundary(action,work)
 if __utilityCase=="parent-revoked"then assert(__utilityReplaceOriginalRequest())end
 performNative(action)
 if __utilityCase=="parent-revoked"then body:StopAllActionQueue();ISTimedActionQueue.getTimedActionQueue(body):resetQueue();action:forceCancel()end
 local row=SAO.ResourceProduction.outcome(id,work.id);local placed=__utilityPlacedNetworkFacts()
 local unchanged=__utilityCase=="parent-revoked"and #placed==0 or __utilityCase=="parent-postallocation"and #placed==1 and placed[1].containerNull and placed[1].backlinkExact
 local successor=ISBaseTimedAction:new(body);ISTimedActionQueue.add(successor);local q=ISTimedActionQueue.getTimedActionQueue(body);local native=successor.action
 action:stop();action:perform();action:complete();action:start()
 local successorOK=q.current==successor and successor.action==native and native:getTable()==successor and not __utilityNativeActionFacts(native,successor).forceStop
 row=SAO.ResourceProduction.outcome(id,work.id)
 local noCredit=row and row.status~="completed"and row.nativeCredit==nil and row.topologyConfirmed==false
 __utilityWriteProjection("parent-boundary",{record=rec,work=work,canonical=row,placed=placed,requestRevision=parent.revision,replaced=replacement,scope="Actual original P.maintain definition replacement; no terminal abandonment or synthetic positive credit"})
 check("guard_original_definition_replaced",replacement)
 check("guard_parent_physical_truth",unchanged)
 check("guard_obsolete_callback_preserves_successor",successorOK)
 check("guard_parent_no_unauthorized_topology",noCredit)
 guardedDone=true
end
local function installedBoundary(part,object)
 local original=SAO.ResourceProduction.outcome(id,part.workId);local candidate=SAOJavaBridge:findOfferedItem(body);local selected=SAOJavaBridge:offeredWorldItem(body)
 local exact=selected==object and object:getItem():getID()==tonumber(part.itemId)and H.currentPart(part)==object and original and original.nativeCredit==part.workId
 local queued,action=SAO.Needs.queueGrabOffered(id,body)
 if queued then performNative(action)end
 local retained=object:getItem():getWorldItem()==object and object:getSquare()~=nil and H.currentPart(part)==object and not body:getInventory():contains(object:getItem())
 __utilityWriteProjection("installed-boundary",{record=rec,part=part,canonical=original,candidateName=candidate,exact=exact,admissionQueued=queued==true,retainedCurrent=retained,pickupStatus=action and action.saoPickupResult,placed=__utilityPlacedNetworkFacts(),scope="Focused original native enumeration/admission/transfer; no seeded marker/forced strategy"})
 check("guard_installed_exact_native_candidate",exact)
 if __utilityControl=="installed-admission"then check("guard_installed_transfer_refused",retained);check("guard_installed_admission_refused",not queued)
 elseif __utilityControl=="installed-transfer"then check("guard_installed_admission_refused",queued==true);check("guard_installed_transfer_refused",retained)
 else check("guard_installed_admission_refused",not queued);check("guard_installed_transfer_refused",retained)end
 guardedDone=true
end
local function connectionFacts(x,y,z)
 local c=H.connection(x,y,z);if not c then return{available=false}end
 local row={available=true,owned=c.owned,structure=c.structure,tiles={},pumpCount=#c.pumps}
 for _,tile in pairs(c.tiles)do row.tiles[#row.tiles+1]={x=tile.x,y=tile.y,z=tile.z,powered=tile.square:haveElectricity()}end
 return row
end
local function checkpoint(turn,phase)
 local facts=SAO.Perception.networkFluids(id);local headers={}
 for _,fact in ipairs(facts)do headers[#headers+1]={sourceId=fact.sourceId,headerKnown=SAO.Perception.networkHeaderKnown(id,fact.sourceId)}end
 local recipeDiagnostics={}
 for _,purpose in pairs(rec.proceduralPlanning and rec.proceduralPlanning.purposes or{})do
  local demand=purpose.materialWork and purpose.materialWork.recipeDemand
  if demand and demand.kind=="recipe-stock"then
   local current=P.networkMaterialDemandCurrent(id,demand);local ok,means=pcall(function()return SAOJavaBridge:recipeMeansForDemand(body,demand)end)
   local entry={purposeId=purpose.id,demand=demand,current=current,nativeRead=ok,nativeMeans=ok and means or nil,nativeError=not ok and tostring(means)or nil,policies={},installed={HandcraftLogic=HandcraftLogic~=nil,CraftRecipeManager=CraftRecipeManager~=nil,ScriptManager=ScriptManager~=nil,ArrayList=ArrayList~=nil}}
   if ok and type(means)=="table"then
    for _,mean in ipairs(means)do local yes,policy,why=pcall(SAO.ResourceProduction.recipePolicy,id,body,mean.recipeId,demand,nil);entry.policies[#entry.policies+1]={recipeId=mean.recipeId,callOK=yes,policy=policy~=nil and yes,reason=yes and why or(not yes and tostring(policy)or nil)}end
    local yes,options=pcall(SAO.ResourceProduction.recipeOptions,id,body,demand,means,nil);entry.optionsRead=yes;entry.options=yes and options or nil;entry.optionsError=not yes and tostring(options)or nil
   end
   if purpose.recipeSupply and purpose.recipeSupply.recipeId then local yes,needs=pcall(function()return SAOJavaBridge:recipeSupplyNeeds(body,purpose.recipeSupply.recipeId)end);entry.supplyRead=yes;entry.supply=yes and needs or nil;entry.supplyError=not yes and tostring(needs)or nil end
   local step=purpose.steps and purpose.steps[purpose.cursor];local req=step and step.recipeRequirement
   if req then
    entry.resourceTypeInstalled=ResourceType~=nil;entry.originalMaterialType=SAO.Material.recipeObservedType(req,"Base.MetalPipe")
    entry.inputAdmission=P.recipeInputAdmission(id,req.demandId,purpose.id,step.id,req.recipeId,req.index,req.declaration)
    entry.sources={}
    for _,place in pairs(SAO.Perception.knownPlaces(id,true)or{})do
     local sourceEntry={placeId=place.id,sourceId=place.sourceId,sourceRevision=place.sourceRevision,facts=place.sourceFacts}
     local yes,offers,why=pcall(SAO.WorldSources.recipeSlotOptions,place,"recipe-input",id,body,req,"standing");sourceEntry.callOK=yes;sourceEntry.reason=why;sourceEntry.offers=yes and offers or nil;sourceEntry.error=not yes and tostring(offers)or nil;sourceEntry.nativeReads={}
     for _,fact in pairs(place.sourceFacts or{})do
      local ok,native=pcall(function()return SAOJavaBridge:recipeInputObservation(body,fact.id,fact.fingerprint,fact.revision,req.recipeId,req.index,req.declaration,req.demandId,req.purposeId,req.stepId)end)
      sourceEntry.nativeReads[#sourceEntry.nativeReads+1]={sourceId=fact.id,callOK=ok,returned=native~=nil,native=ok and native or nil,error=not ok and tostring(native)or nil}
     end
     entry.sources[#entry.sources+1]=sourceEntry
    end
   end
   recipeDiagnostics[#recipeDiagnostics+1]=entry
  end
 end
 local water,waterStep=P.resourceDemand(id,"water",true);local network,networkStep=P.networkPurpose(id);local offer,route=P.networkOffer(id,body)
 local nativeQueue=ISTimedActionQueue.getTimedActionQueue(body);local nativeAction=nativeQueue.current and nativeQueue.current.action
 local actionFacts=nativeAction and __utilityNativeActionFacts(nativeAction,nativeQueue.current)or nil
 local generatorPurpose,generatorStep=P.generatorPurpose(id)
 local service={donor=__utilityNativeSourceFacts(__scene.pump),header=__utilityNativeSourceFacts(__scene.header),tap=__utilityNativeSourceFacts(__scene.fixture),generator=__utilityCurrentGeneratorFacts(__scene.generator),thirst=body:getStats():get(CharacterStat.THIRST),donorConnection=connectionFacts(10,21,0),headerConnection=connectionFacts(10,20,1),sourceBuiltEndpoint=H.currentBuiltEndpoint(10,21,0),pumpSquarePowered=getCell():getGridSquare(10,20,0):haveElectricity()}
 local actualSite=SAOJavaBridge:networkSite(body,"pump","y",10,20,0)
 __utilityWriteProjection("checkpoint-"..turn.."-"..phase,{record=rec,state=agent.state,service=service,generatorPurpose=generatorPurpose,generatorStep=generatorStep,knownPlaces=SAO.Perception.knownPlaces(id,true),placedNative=__utilityPlacedNetworkFacts(),nativeItems=__utilityNativeInventoryFacts(),nativeAction=actionFacts,actualPumpSite=actualSite,position={x=body:getX(),y=body:getY(),z=body:getZ()},sites=SAO.Perception.networkSites(id),fluids=facts,headers=headers,recipeDiagnostics=recipeDiagnostics,water=water,waterStep=waterStep,network=network,networkStep=networkStep,offer=offer,route=route,captureHours=SAO.History.countyHours()})
end
for turn=1,150 do
 checkpoint(turn,"before")
 local queue=ISTimedActionQueue.getTimedActionQueue(body)
 local network,networkStep=P.networkPurpose(id)
 local offer,route=P.networkOffer(id,body)
 local work=rec.resourceProductionWork
 if (__utilityCase=="parent-revoked"or __utilityCase=="parent-postallocation")and queue.current and queue.current.Type=="ISBaseTimedAction"and work and work.kind=="network-operation"and work.operation=="place"then parentBoundary(queue.current,work);break end
 if __utilityCase=="installed-offer"and agent.state=="IDLE"and not queue.current then
  for _,part in ipairs(H.partsAt(10,20,0))do if part.kind=="riser"then installedBoundary(part,H.currentPart(part));break end end
  if guardedDone then break end
 end
 print("ORDINARY_CURRENT_STAGE",turn,agent.state,queue.current and queue.current.Type,network and network.id,networkStep and networkStep.verb,networkStep and networkStep.status,offer and offer.operation,route)
 print("ORDINARY_ACTUAL_ACQUISITION",#SAO.Perception.networkSites(id),#SAO.Perception.networkFluids(id),body:getX(),body:getY(),body:getZ(),agent.networkInquiry and agent.networkInquiry.purposeId)
 if __utilityCase=="normal"and not __installedExclusionMeasured and agent.state=="IDLE"and not queue.current then
  for _,part in ipairs(H.partsAt(10,20,0))do
   if part.kind=="riser"then
    local object=H.currentPart(part);local canonical=SAO.ResourceProduction.outcome(id,part.workId)
    local name=SAO.Needs.findOffered(id,body);local cached=SAOJavaBridge:offeredWorldItem(body)
    check("installed_network_part_excluded",object~=nil and canonical~=nil and canonical.nativeCredit==part.workId and cached~=object)
    __utilityWriteProjection("installed-exclusion",{part=part,canonical=canonical,currentNativeObjectMatches=object~=nil,offeredName=name,cacheSameInstalled=cached==object,captureHours=SAO.History.countyHours(),physicalPickupPerformed=false})
    __installedExclusionMeasured=true
   end
  end
 end
 if agent.forageInspection then Ctl.tick();__utilityUpdateMovement(id,agent,body)
 elseif queue.current then
  local action=queue.current;print("ORDINARY_NATIVE_ACTION",action.Type,action:isValidStart(),action:isValid())
  if not action.action:isStarted()then action.action:start()end
  if action.Type=="SAOStudyAction"then __utilityAdvanceNativeTimer(action.action)end
  action.action:forceComplete();if action.update then action:update()end;action.action:perform();action.action:complete();body:getCharacterActions():remove(action.action)
 elseif agent.state=="FORAGE"or agent.state=="SOURCEWARD"or agent.state=="TRAVEL"or agent.state=="WATERWARD"or agent.state=="NETWORKWARD"then __utilityUpdateMovement(id,agent,body)
 elseif agent.state=="RESOURCE"then __utilityUpdateAgent(id,agent)
 elseif agent.state=="STUDY"then __utilityUpdateAgent(id,agent,body)
 else
  __utilityHours=__utilityHours+.1;Ctl.tick();local current=SAO.Needs.read(body)
  __utilityUpdateAgent(id,agent)
 end
 __utilityEnvironmentTick();checkpoint(turn,"after")
end
if __utilityCase~="normal"then assert(guardedDone,"boundary not reached");return end
local work=rec.resourceProductionWork
__utilityWriteProjection("first-stage",{record=rec,sites=SAO.Perception.networkSites(id),fluids=SAO.Perception.networkFluids(id),work=work,full=SAO.Cognition.snapshot(id,true),bounded=SAO.Cognition.snapshot(id,false),captureHours=SAO.History.countyHours()})
local water=rec.proceduralPlanning.purposes[parent.id];local completedNetwork
for _,p in pairs(rec.proceduralPlanning.purposes)do if p.waterNetwork and p.waterNetwork.parentPurposeId==parent.id then completedNetwork=p end end
local use=water and water.hydrationUseReceipt
check("original_water_goal_completed",water and water.status=="completed"and water.resolution=="native-hydration-relief"and use and use.status=="completed"and use.nativeCredit==use.id and use.thirstDelta>0)
check("original_network_goal_completed",completedNetwork and completedNetwork.status=="completed"and completedNetwork.resolution=="native-original-network-water-use"and completedNetwork.waterNetwork.useReceiptId==use.id)
local last=completedNetwork and SAO.ResourceProduction.outcome(id,completedNetwork.waterNetwork.lastWorkId)
check("same_authentic_physical_receiver",last and last.status=="completed"and last.nativeCredit==last.id and last.sourceAfter.sourceId==completedNetwork.waterNetwork.receiver.sourceId)
local full,bounded=SAO.Cognition.snapshot(id,true),SAO.Cognition.snapshot(id,false);local consume=0;local networkEvents=0
for _,e in ipairs(full.experiences)do if e.kind=="consume"and e.category=="water"and e.status=="completed"and e.thirstDelta==use.thirstDelta then consume=consume+1 end;if e.kind=="network-operation"and e.status=="completed"then networkEvents=networkEvents+1 end end
check("completed_private_consume_and_network_feedback",consume==1 and networkEvents==4 and #full.models==2 and full.models[1].id~=full.models[2].id)
check("native_water_stock_conserved",math.abs(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount()+use.thirstDelta*2-4)<.00001 and body:getStats():get(CharacterStat.THIRST)==0)
__utilityWriteProjection("consumer-final",{captureHours=SAO.History.countyHours(),record=rec,cognition=full,boundedCognition=bounded,sourceStore=ModData.getOrCreate("SurvivorAwareness_WorldSources"),purpose=P.snapshot(id),native={donor=__utilityNativeSourceFacts(__scene.pump),header=__utilityNativeSourceFacts(__scene.header),tap=__utilityNativeSourceFacts(__scene.fixture),generator=__utilityCurrentGeneratorFacts(__scene.generator),thirst=body:getStats():get(CharacterStat.THIRST)}})
