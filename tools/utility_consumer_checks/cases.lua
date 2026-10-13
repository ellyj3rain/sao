local function check(name,value)print("CHECK "..name.."="..tostring(value==true));if not value then error(name)end end
local id="utility-owner";local rec=SAO.Identity.get(id);local H=SAO.HouseholdService;local Ctl,P,G=SAO.Controller,SAO.ProceduralPlanning,SAO.Generator
check("utility_native_person_adopted",rec==__record and SAO.Body.get(id)==body and body:getModData().SAOExternalToken==nil)
check("utility_default_models",SAO.Cognition.ensureGameDefaults())
local loaded=__utilityOwnedCallbackFacts(H.onTick)
check("utility_owned_packaged_startup",H.available()and not LGEE and not LGEP and require("SAO_HouseholdService")==H and loaded.count==(__utilityControl=="producer-callback"and 0 or 1)and string.find(loaded.filename,__utilityOwnedPackage,1,true)~=nil)
print("UTILITY_OWNED_LOADER",loaded.count,loaded.filename)
local retainedGeneratorPurposeId
local agent={rec=rec,state="IDLE",stateSince=0,nextDecisionAt=0};Ctl.agents[id]=agent
check("utility_native_declared_unknown_tool_manual",body:getInventory():getCountTypeRecurse("Base.PipeWrench")==0 and body:getInventory():getCountTypeRecurse("Base.ElectronicsMag4")==0 and not body:isRecipeActuallyKnown("Generator"))
check("utility_native_initial_no_installation_power",not __scene.generator:isConnected()and not __scene.generator:isActivated()and __scene.generator:getFuel()==0 and not H.isGeneratorPlumbed(__scene.generator))
print("UTILITY_RAW_AVAILABILITY",__scene.fixture:getFluidAmount(),__scene.pump:getFluidAmount(),H.isPumped(__scene.pump),__scene.pump:getSquare():haveElectricity())
local initialWater=SAO.Needs.findWater(id,body)
check("utility_initial_no_clean_water_original_sensor",initialWater==nil and __scene.pump:isTaintedWater() and __scene.pump:getFluidAmount()==4 and __scene.fixture:getFluidAmount()==0)
print("UTILITY_INITIAL_NATIVE_SUPPLY",H.connection(10,20,0),H.supplyGroup(10,20,0),__scene.fixture:FindExternalWaterSource())
local observed=SAO.Perception.observeGenerators(id,body,SAO.History.ticks())
print("UTILITY_GENERATOR_OBSERVE",observed)
print("UTILITY_ACTUAL_HISTORY",SAO.History.ageOf(id),SAO.History.literacyOf(id));check("utility_original_history_loaded",type(SAO.History.literacyOf)=="function"and not body:isRecipeActuallyKnown("Generator"))
local needs=SAO.Needs.read(body);print("UTILITY_NATIVE_NEEDS",needs and needs.thirst,needs and needs.hunger)
local water=Ctl.beginHydrationAcquisition(id,agent,body,1,needs)
local purpose,step=P.resourceDemand(id,"water")
print("UTILITY_NORMAL_WATER_FIRST",water,agent.state,purpose and purpose.id,step and step.id,step and step.status,step and step.verb)
check("utility_original_water_purpose",purpose~=nil and purpose.resourceCategory=="water")
if agent.state=="IDLE"then
 local dispatched=Ctl.advanceGeneratorPurpose(id,agent,body,2,needs)
 local gp,gs=P.generatorPurpose(id);retainedGeneratorPurposeId=gp and gp.id
 print("UTILITY_NORMAL_GENERATOR_FIRST",dispatched,agent.state,gp and gp.id,gs and gs.operation,gs and gs.verb,gs and gs.status)
 if gp then for k,v in pairs(gp.generatorPower or{})do if type(v)~="table"then print("UTILITY_REQUEST_FIELD",k,v)end end end
 if gs then
  for label,fields in pairs({generator=gs.generator,consumer=gs.consumer})do for k,v in pairs(fields or{})do if type(v)~="table"then print("UTILITY_SELECTED_FIELD",label,k,v)end end end
  print("UTILITY_NATIVE_GENERATOR_TARGET",SAO.WorldSources.generatorTarget(body,gs.generator,"inspect"),SAO.WorldSources.generatorObject(body,gs.generator,"inspect"),SAO.WorldSources.generatorValid(body,__scene.generator,gs.generator,"inspect"))
 end
 print("UTILITY_PARENT_CURRENT",purpose.revision,purpose.cursor,#purpose.steps,gp and P.generatorRequestCurrent(id,{purposeId=gp.id}),rec.generatorSequence,rec.resourceProductionWork)

 check("utility_actual_normal_generator_dispatch",dispatched and gp~=nil and gp.generatorPower.requestingPurposeId==purpose.id and gp.generatorPower.requestingActivity=="hydration")
else
 print("UTILITY_DIRECT_WATER_OR_PREPARATION_FIRST",agent.state)
 check("utility_actual_normal_generator_dispatch",false)
end

local function finishNative()
 local q=ISTimedActionQueue.getTimedActionQueue(body);local action=q.current
 if not action then error("actual native queue action absent")end
 print("UTILITY_NATIVE_ACTION",action.Type,action:isValidStart(),action:isValid())
 if action.Type=="SAOConnectGeneratorSupply"then
  for _,phase in ipairs({"perform","complete"})do
   local original=action[phase];action[phase]=function(self,...)
    local ok,result=pcall(original,self,...);print("UTILITY_OWNED_PLUMB_PHASE",phase,ok,result)
    if not ok then error(result)end;return result
   end
  end
 end
 if not action.action:isStarted()then action:start()end
 print("UTILITY_NATIVE_PRE_END",action.nativeStarted,action:getJobDelta(),rec.studyWork and rec.studyWork.progress,action.action:isStarted())
 if action.Type=="SAOStudyAction"then __utilityAdvanceNativeTimer(action.action)end
 action.action:forceComplete()
 -- Native animation-end signal yields actual jobDelta1; run original update so
 -- the owned reader records its own measured progress, never a fixture setter.
 if action.update then action:update()end
 print("UTILITY_NATIVE_POST_UPDATE",action.nativeStarted,action:getJobDelta(),rec.studyWork and rec.studyWork.progress,action.action:finished(),action.action:isForceComplete())
 action.action:perform();action.action:complete();body:getCharacterActions():remove(action.action)
 return action
end
local first=rec.resourceProductionWork;local firstNativeAction=ISTimedActionQueue.getTimedActionQueue(body).current.action;finishNative();G.tick(id,body)
local inquiry=G.outcome(id,first.id)
print("UTILITY_ACTUAL_INQUIRY_RESULT",inquiry and inquiry.status,inquiry and inquiry.nativeOwner,inquiry and inquiry.nativeCredit)
check("utility_actual_canonical_source_inquiry",inquiry and inquiry.status=="completed"and inquiry.operation=="inspect"and inquiry.nativeCredit==inquiry.id)
__utilityUpdateAgent(id,agent);check("utility_original_resource_release",agent.state=="IDLE")
local second=Ctl.advanceGeneratorPurpose(id,agent,body,1002,SAO.Needs.read(body));local nextPurpose,nextStep=P.generatorPurpose(id)
print("UTILITY_NORMAL_POST_INQUIRY",second,agent.state,nextPurpose and nextPurpose.id,nextStep and nextStep.operation,nextStep and nextStep.verb,nextStep and nextStep.category,nextStep and nextStep.status)
for _,place in pairs(SAO.Perception.knownPlaces(id,true))do for key,f in pairs(place.sourceFacts or{})do if key:sub(1,2)=="J:"then print("UTILITY_POST_SERVICE_KNOWLEDGE",f.serviceKnowledgeRequired,f.fuelServiceEligible,f.serviceRevision)end end end
check("utility_actual_next_normal_dispatch",second==true)

-- Continue original current generator purpose. No direct inspection or acquired facts.
local function advanceClock()
 __utilityHours=__utilityHours+.1;Ctl.tick();return SAO.History.ticks()
end
local sawForage=false;local hydrationAction
for turn=1,48 do
 local q=ISTimedActionQueue.getTimedActionQueue(body)
 local gp,gs=P.generatorPurpose(id)
 print("UTILITY_CONTINUATION",turn,agent.state,gp and gp.id,gs and gs.owner,gs and gs.operation,gs and gs.verb,gs and gs.status,q.current and q.current.Type,body:isRecipeActuallyKnown("Generator"))
 if agent.forageInspection then
  sawForage=true;Ctl.tick();__utilityUpdateMovement(id,agent,body)
  print("UTILITY_ORIGINAL_FORAGE_ACK",agent.state,agent.forageInspection)
 elseif q.current then
  if q.current.Type=="ISTakeWaterAction"and __utilityCase~="normal"then
   local action=q.current;local parent=rec.proceduralPlanning.purposes[purpose.id]
   local fluidBefore=(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount());local thirstBefore=SAO.Needs.read(body).thirst;local sequenceBefore=rec.generatorSequence
   check("utility_guard_original_admitted_action",action.character==body and action.waterObject==__scene.fixture and parent.status~="completed")
   if __utilityCase=="parent-revoked"then parent.status="abandoned" -- Explicit negative revocation, never positive goal/status grant.
   elseif __utilityCase=="source-removed"then action.waterObject:getSquare():getObjects():remove(action.waterObject)
   elseif __utilityCase=="cancel"then body:StopAllActionQueue()
   elseif __utilityCase=="native-swapped"then action.action:forceComplete();action.action=firstNativeAction end
   if __utilityCase=="native-swapped"then action:perform();action:complete()
   elseif __utilityCase~="cancel"then finishNative()end
   local row=SAO.Needs.hydrationUseOutcome(id,action)
   print("UTILITY_ACTUAL_CANCEL_ENDPOINT",__utilityCase,ISTimedActionQueue.getTimedActionQueue(body).current,__utilityNativeActionFacts(action.action,action).forceStop,body:getCharacterActions():contains(action.action))
   if __utilityCase=="cancel"then check("utility_guard_actual_native_cancel_release",ISTimedActionQueue.getTimedActionQueue(body).current==nil and not body:getCharacterActions():contains(action.action))end
   check("utility_guard_no_native_effect",(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount())==fluidBefore and SAO.Needs.read(body).thirst==thirstBefore)
   check("utility_guard_interrupted_canonical",row and row.status=="interrupted"and row.nativeCredit==nil)
   check("utility_guard_original_goal_uncredited",parent.status~="completed"and parent.hydrationUseReceipt==nil and P.consumeHydrationUse(id,action)==false and rec.generatorSequence==sequenceBefore)
   action:perform();action:complete()
   check("utility_guard_inert_late_callback",(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount())==fluidBefore and SAO.Needs.read(body).thirst==thirstBefore and SAO.Needs.hydrationUseOutcome(id,action).id==row.id)
   __utilityWriteProjection("current-use-refusal",{scenario=__utilityCase,outcome=row,parent=parent,generatorOutcomes=rec.generatorOutcomes,native={waterBefore=fluidBefore,waterAfter=(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount()),thirstBefore=thirstBefore,thirstAfter=SAO.Needs.read(body).thirst},cognition=SAO.Cognition.snapshot(id,true)})
   return
  end
  local sourceReservation=rec.worldSourceReservation
  local endedAction=finishNative()
 if endedAction.Type=="SAOConnectGeneratorSupply"then
  local result=G.outcome(id,rec.generatorSequence)
  print("UTILITY_OWNED_PLUMB_CANONICAL",result and result.status,result and result.nativeAttempted,result and result.nativeCompleted,result and result.beforePlumbed,result and result.afterPlumbed,result and result.detail)
  if result and result.status=="failed"then __utilityWriteProjection("owned-plumb-failure",{canonical=result,purpose=P.snapshot(id),native={plumbed=H.isGeneratorPlumbed(__scene.generator),fuel=__scene.generator:getFuel(),source=__scene.pump:getFluidAmount(),header=__scene.header:getFluidAmount()}});error("authentic-owned-plumb-failure")end
 end
 if endedAction.Type=="ISTakeWaterAction"then hydrationAction=endedAction end;advanceClock();print("UTILITY_AFTER_ORIGINAL_NATIVE",agent.state,body:isRecipeActuallyKnown("Generator"),rec.studyWork,rec.resourceProductionWork)
  if agent.state~="IDLE"then __utilityUpdateAgent(id,agent)end
  if sourceReservation then
   __utilityWriteProjection("source-actor-"..tostring(turn),{authoritative=SAO.WorldSources.actionOutcome(sourceReservation,id),purpose=P.snapshot(id),cognition=SAO.Cognition.snapshot(id,true),sourceStore=ModData.getOrCreate("SurvivorAwareness_WorldSources")})
  end
  local canonical=SAO.WorldSources.completedResults("provisioning",true)
  for _,row in ipairs(canonical)do
   print("UTILITY_PENDING_SOURCE_RECEIPT",row.status,row.operation,row.category,row.purposeId,row.purposeStepId,row.reservationId,row.at,row.measurement,row.observedQuantity)
   __utilityWriteProjection("canonical-source-"..tostring(turn),{receipt=row,authoritative=SAO.WorldSources.actionOutcome(row.reservationId,id),purpose=P.snapshot(id),cognition=SAO.Cognition.snapshot(id,true)})
   local accepted,why=SAO.Provisioning.processReceipt(row)
   print("UTILITY_ORIGINAL_PROVISIONING_REPLAY",accepted,why)
  end
 elseif agent.state~="IDLE"then
  advanceClock();__utilityUpdateAgent(id,agent)
 else
  local tick=advanceClock();local currentNeeds=SAO.Needs.read(body)
  if __scene.generator:isActivated()then
   local wx,wy,wz=SAO.Needs.findWater(id,body)
   print("UTILITY_HYDRATION_NATIVE_SENSOR",wx,wy,wz,SAOJavaBridge:waterSourceObject(body),SAOJavaBridge:waterSourceWithinReach(body))
   for label,obj in pairs({pump=__scene.pump,fixture=__scene.fixture})do
    print("UTILITY_HYDRATION_NATIVE_FLUID",label,obj:getFluidAmount(),obj:hasWater(),obj:isTaintedWater(),obj:getFluidContainer():getPrimaryFluid())
   end
   print("UTILITY_HYDRATION_PRIVATE_OPTIONS",#SAO.ResourceProduction.options(id,body,"water"))
  end
  local next=__utilityDecideNeeds(id,agent,body,tick,currentNeeds)
  if not next and agent.state=="IDLE"then next=Ctl.advanceGeneratorPurpose(id,agent,body,tick,currentNeeds)end
  print("UTILITY_CURRENT_NORMAL_DISPATCH",next)
 end
 if H.isGeneratorPlumbed(__scene.generator)then
  raise("EveryTenMinutes")
  -- Original engine environmental callbacks drain the existing requested sweep;
  -- no registry insertion, generator fuel/power setter or result grant.
  for frame=1,32 do __utilityEnvironmentTick()end
 end
 print("UTILITY_NATIVE_CURRENT_PROVIDER",__scene.fuel:getFluidAmount(),__scene.generator:getFuel(),__scene.generator:isConnected(),__scene.generator:isActivated(),H.isGeneratorPlumbed(__scene.generator),__scene.pump:getSquare():haveElectricity(),__scene.pump:getFluidAmount(),SAO.Needs.read(body).thirst)
 if SAO.Needs.read(body).thirst<.2 then break end
end
check("utility_original_signed_forage_path",sawForage)
check("utility_original_manual_native_learned",body:isRecipeActuallyKnown("Generator"))
check("utility_original_wrench_native_acquired",body:getInventory():getCountTypeRecurse("Base.PipeWrench")>0)

check("utility_actual_original_generator_plumbed",H.isGeneratorPlumbed(__scene.generator))
check("utility_actual_finite_fuel_provider",__scene.fuel:getFluidAmount()<7 and __scene.generator:getFuel()>0)
check("utility_actual_native_generator_power",__scene.generator:isConnected()and __scene.generator:isActivated()and __scene.pump:getSquare():haveElectricity())

check("utility_actual_original_hydration",SAO.Needs.read(body).thirst<.2)
check("utility_actual_water_conservation",math.abs((4-(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount()))-(__scene.initialThirst-body:getStats():get(CharacterStat.THIRST))*2)<0.00001)
local rawParent=rec.proceduralPlanning.purposes[purpose.id]
local use=hydrationAction and SAO.Needs.hydrationUseOutcome(id,hydrationAction)
check("utility_original_parent_authentic_native_relief",rawParent.status=="completed"and rawParent.resolution=="native-hydration-relief"and use and use.status=="completed"and use.nativeCredit==use.id and rawParent.hydrationUseReceipt.id==use.id and use.request.purposeId==purpose.id and use.bodyToken==nil and use.thirstDelta>.0001)
local completedConsume=false;local installationEvents=0
for _,event in ipairs(SAO.Cognition.snapshot(id,true).experiences or{})do
 if event.kind=="consume"and event.category=="water"and event.status=="completed"and event.thirstDelta and event.thirstDelta>.0001 then completedConsume=true end
 if event.kind=="generator-operation"and event.status=="completed"then installationEvents=installationEvents+1 end
end
check("utility_independent_successful_native_use_feedback",completedConsume and installationEvents>=4)
local obsoleteUtility=rec.proceduralPlanning.purposes[retainedGeneratorPurposeId]
check("utility_original_obsolete_prerequisite_retired",obsoleteUtility and obsoleteUtility.status=="abandoned"and rec.generatorOutcomes[#rec.generatorOutcomes].operation=="activate"and rec.generatorOutcomes[#rec.generatorOutcomes].status=="completed")
local beforeReplay=SAO.Cognition.snapshot(id,true);local beforeSequence=rec.generatorSequence;local beforeFluid=(__scene.pump:getFluidAmount()+__scene.header:getFluidAmount())
check("utility_original_use_replay_once",P.consumeHydrationUse(id,hydrationAction)==true and rawParent.hydrationUseReceipt.id==use.id and rec.generatorSequence==beforeSequence and (__scene.pump:getFluidAmount()+__scene.header:getFluidAmount())==beforeFluid and #SAO.Cognition.snapshot(id,true).experiences==#beforeReplay.experiences)
local forged={};for k,v in pairs(use)do forged[k]=v end
check("utility_original_use_forged_copy_refused",P.consumeHydrationUse(id,forged)==false and SAO.Needs.hydrationUseOutcome("foreign-person",hydrationAction)==nil and rawParent.hydrationUseReceipt.id==use.id)
-- Explicit post-normal safety fixture: unchanged vanilla neutral base action,
-- no consumer/strategy/effect credit, retained only as a real queued successor.
local successor=ISBaseTimedAction:new(body);ISTimedActionQueue.add(successor)
local successorQueue=ISTimedActionQueue.getTimedActionQueue(body);local successorNative=successor.action
check("utility_actual_native_successor_queued",successorQueue.current==successor and successorNative:getTable()==successor and body:getCharacterActions():contains(successorNative))
hydrationAction:stop();hydrationAction:perform();hydrationAction:complete();hydrationAction:start()
check("utility_obsolete_callbacks_preserve_successor",successorQueue.current==successor and successorQueue:indexOf(successor)~=-1 and successor.action==successorNative and not __utilityNativeActionFacts(successorNative,successor).forceStop and body:getCharacterActions():contains(successorNative)and (__scene.pump:getFluidAmount()+__scene.header:getFluidAmount())==beforeFluid and #SAO.Cognition.snapshot(id,true).experiences==#beforeReplay.experiences)
-- Original native cancellation ends this safety fixture; it produces no work result.
successorNative:forceStop();successorNative:stop();body:getCharacterActions():remove(successorNative)
local plainSaved=nativePlainRoundTrip(rec)
check("utility_native_plain_parent_saved",plainSaved.proceduralPlanning.purposes[purpose.id].status=="completed"and plainSaved.proceduralPlanning.purposes[purpose.id].hydrationUseReceipt.id==use.id and #plainSaved.generatorOutcomes==#rec.generatorOutcomes)
local coldGenerator=roundTripGenerator(__scene.generator)
check("utility_native_generator_primitive_saved",coldGenerator:getFuel()==__scene.generator:getFuel()and coldGenerator:isConnected()==__scene.generator:isConnected()and coldGenerator:isActivated()==__scene.generator:isActivated()and H.isGeneratorPlumbed(coldGenerator))
__utilityWriteProjection("canonical-hydration-use",{outcome=use,purpose=rawParent,savedParent=plainSaved.proceduralPlanning.purposes[purpose.id],generatorOutcomes=rec.generatorOutcomes,primitiveCold={fuel=coldGenerator:getFuel(),connected=coldGenerator:isConnected(),active=coldGenerator:isActivated(),plumbed=H.isGeneratorPlumbed(coldGenerator)}})
__utilityWriteProjection("consumer-final",{captureHours=SAO.History.countyHours(),record=rec,purpose=P.snapshot(id),cognition=SAO.Cognition.snapshot(id,true),sourceStore=ModData.getOrCreate("SurvivorAwareness_WorldSources"),native={fuelProvider=__scene.fuel:getFluidAmount(),generatorFuel=__scene.generator:getFuel(),connected=__scene.generator:isConnected(),active=__scene.generator:isActivated(),plumbed=H.isGeneratorPlumbed(__scene.generator),powered=__scene.pump:getSquare():haveElectricity(),waterProvider=__scene.pump:getFluidAmount(),thirst=SAO.Needs.read(body).thirst,fixture=__utilityNativeSourceFacts(__scene.fixture),reservoir=__utilityNativeSourceFacts(__scene.pump),header=__utilityNativeSourceFacts(__scene.header),initialThirst=__scene.initialThirst,ownedCallback=loaded,effectiveSource=__utilityNativeSourceFacts(__scene.fixture:FindExternalWaterSource())}})
