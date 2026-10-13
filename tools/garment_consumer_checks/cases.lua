local function check(name,value)print("CHECK "..name.."="..tostring(value==true));if not value then error(name)end end
local function quote(value)return '"'..value:gsub('[%z\1-\31\\"]',function(c)if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'else return string.format('\\u%04x',string.byte(c))end end)..'"'end
local seen={}
local function json(v)
 local t=type(v);if t=="nil"then return"null"elseif t=="string"then return quote(v)elseif t=="number"then if v~=v or v==math.huge or v==-math.huge then error("nonfinite export")end;return tostring(v)elseif t=="boolean"then return v and"true"or"false"elseif t~="table"or seen[v]then error("nonplain/cyclic export")end
 seen[v]=true;local keys={};local dense=true;local count=0
 for k in pairs(v)do keys[#keys+1]=k;count=count+1;if type(k)~="number"or k<1 or k~=math.floor(k)then dense=false end end
 dense=dense and count>0 and count==#v;local fields={}
 if dense then for _,x in ipairs(v)do fields[#fields+1]=json(x)end else table.sort(keys,function(a,b)return tostring(a)<tostring(b)end);for _,k in ipairs(keys)do fields[#fields+1]=quote(tostring(k))..":"..json(v[k])end end
 seen[v]=nil;return(dense and"["or"{")..table.concat(fields,",")..(dense and"]"or"}")
end
local id="garment-person";local rec=SAO.Identity.get(id);local Ctl,P,R=SAO.Controller,SAO.ProceduralPlanning,SAO.ResourceProduction
check("garment_normal_native_identity",rec~=nil and rec==__record and SAO.Body.get(id)==body)
check("garment_ordinary_nil_token",rec.bodyOwnerToken==nil and body:getModData().SAOExternalToken==nil)
check("garment_default_models",SAO.Cognition.ensureGameDefaults())
local agent={rec=rec,state="IDLE",stateSince=0,nextDecisionAt=0};Ctl.agents[id]=agent
if __garmentCase=="layers"and __garmentLayer=="highskill"then
 SAO.Perception.observeGarments(id,body);local rawBenefit
 for _,fact in ipairs(SAO.Perception.garments(id,body))do if fact.hole>0 then for _,option in ipairs(R.garmentOptions(id,body,fact))do if option.fabricType=="Leather"then rawBenefit=option.benefit end end end end
 check("garment_highskill_raw_native_benefit_retained",rawBenefit==24)
 local chosen=Ctl.tryGarmentWork(id,agent,body,1);local purpose,step=P.garmentPurpose(id)
 print("GARMENT_HIGHSKILL_NORMAL_CHOICE",chosen,agent.state,purpose and purpose.id,step and step.id)
 check("garment_highskill_default_choice_valid",chosen and purpose~=nil and purpose.interpretations~=nil and purpose.garmentMaintenance~=nil and step~=nil)
 check("garment_highskill_choice_no_physical_credit",rec.resourceProductionWork==nil and purpose.garmentMaintenance.physicalResultId==nil and not purpose.garmentMaintenance.wornBenefitMeasured)
 body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id
 check("garment_highskill_actual_native_snapshot",body:getModData().SAOExternalToken==nil and SAO.Perception.observeGarments(id,body))
 check("garment_highskill_whole_exports",__retainGarmentProjection("private-archive",json(SAO.Cognition.snapshot(id,true)))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({pendingPurposeId=purpose.id,inputs=__nativeModData("SurvivorAwareness_WorldSources").results})))
 return
end
if __garmentCase=="layers"and __garmentLayer=="zero"or __garmentCase=="final-contracts"and __garmentLayer=="zero-benefit"then
 check("garment_contract_zero_owned_native_inputs",body:getInventory():getCountTypeRecurse("Base.Needle")==1 and body:getInventory():getCountTypeRecurse("Base.Thread")==1 and body:getInventory():getCountTypeRecurse("Base.RippedSheets")==1)
 SAO.Perception.observeGarments(id,body);local known,cotton;local fullOptions
 for _,fact in ipairs(SAO.Perception.garments(id,body))do if fact.hole>0 then fullOptions=R.garmentOptions(id,body,fact);for _,option in ipairs(fullOptions)do if option.fabricType=="Cotton"and option.requestedEffect=="restore-hole"and option.ready then known,cotton=fact,option end end end end
 check("garment_contract_zero_actual_native_forecast",cotton and cotton.benefit==0 and R.garmentOptionCurrent(id,body,known,cotton))
 -- Exact current metadata offer isolates protection-value admission; no forced Cotton selection or physical effect.
 local purpose=P.planGarmentWork(id,body,{actorId=id,observation=known,options={cotton}})
 check("garment_contract_zero_protection_unadmitted",purpose==nil and rec.resourceProductionWork==nil and rec.worldSourceReservation==nil)
 check("garment_contract_zero_native_stock_unchanged",body:getInventory():getCountTypeRecurse("Base.RippedSheets")==1 and __scene.clothing:getVisual():getHole(__scene.damagePart)>0 and __scene.clothing:getPatchType(__scene.damagePart)==nil)
 body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id
 check("garment_contract_zero_actual_native_snapshot",SAO.Perception.observeGarments(id,body)and body:getModData().SAOExternalToken==nil)
 check("garment_contract_zero_no_feedback_credit",#(SAO.Cognition.snapshot(id,true).experiences or{})==0)
 check("garment_contract_zero_whole_exports",__retainGarmentProjection("private-archive",json(SAO.Cognition.snapshot(id,true)))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({options=fullOptions,zeroProtectionOffer=cotton,inputs=__nativeModData("SurvivorAwareness_WorldSources").results})))
 return
end
if __garmentCase=="stale-use"then
 -- Declared original native stock before private inspection; the second repair must acquire it normally.
 local extra=instanceItem("Base.LeatherStrips");__scene.container:AddItemBlind(extra);extra:setContainer(__scene.container)
 check("garment_stale_two_native_fabrics_declared",__scene.container:getCountTypeRecurse("Base.LeatherStrips")==2)
end
check("garment_initial_missing_native_materials",body:getInventory():getCountTypeRecurse("Base.Needle")==0 and body:getInventory():getCountTypeRecurse("Base.Thread")==0)
check("garment_initial_declared_worn_damage",__scene.clothing:getVisual():getHole(__scene.damagePart)>0)
local advanced=Ctl.tryGarmentWork(id,agent,body,1)
local purpose,step=P.garmentPurpose(id)
print("GARMENT_NORMAL_FIRST_DISPATCH",advanced,agent.state,purpose and purpose.id,step and step.id,step and step.verb,step and step.status)
check("garment_actual_private_choice",purpose~=nil and purpose.interpretations~=nil and purpose.garmentMaintenance~=nil)
check("garment_world_stock_requires_private_inspection",__scene.container:isExplored()and agent.forageInspection~=nil and step.verb=="inspect")

local function finishNative()
 local q=ISTimedActionQueue.getTimedActionQueue(body);local action=q.current
 if not action then error("ordinary native action absent")end
 print("GARMENT_NATIVE_ACTION",action.Type,action:isValid(),action:isValidStart())
 if not action.action:isStarted()then print("GARMENT_NATIVE_START_RETURN",action:start())end
 print("GARMENT_NATIVE_AFTER_START",action:isValid(),action.action:isStarted(),q.current==action,q:indexOf(action),rec.resourceProductionWork and rec.resourceProductionWork.status)
 action.action:forceComplete();action.action:perform();action.action:complete()
 body:getCharacterActions():remove(action.action)
 return action
end
local inspected,acquired=0,0
local function reachNativeWork()
while not rec.resourceProductionWork do
 if agent.forageInspection then
  local context=agent.forageInspection
  local ok,why=SAO.WorldSources.inspectContainer(id,body,context)
  print("GARMENT_NORMAL_INSPECTION",ok,why,context.sourceId)
  if not ok then error("normal signed garment source inspection refused:"..tostring(why))end
  inspected=inspected+1;agent.forageInspection=nil;SAO.Locomotion.jobs[id]=nil;agent.state="IDLE"
 elseif rec.worldSourceReservation then
  local result=SAO.SourceUse.onMovementDone(id,body,"arrived")
  if result=="moving"then result=SAO.SourceUse.onMovementDone(id,body,"arrived")end
  print("GARMENT_NORMAL_SOURCE_USE",result)
  if result~="using"then error("normal garment source action absent:"..tostring(result))end
  finishNative();local terminal=SAO.SourceUse.tick(id,body)
  if terminal~="completed"then error("native garment input transfer failed:"..tostring(terminal))end
  print("GARMENT_NATIVE_INPUT_HELD",body:getInventory():getCountTypeRecurse("Base.Needle"),body:getInventory():getCountTypeRecurse("Base.Thread"),purpose.cursor,purpose.admission and purpose.admission.owner)
  acquired=acquired+1;agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
 else
  print("GARMENT_ACTUAL_PROGRESS_STOPPED",step and step.status,purpose and purpose.admission and purpose.admission.owner);break
 end
 local ok=Ctl.tryGarmentWork(id,agent,body,acquired+inspected+2)
 purpose,step=P.garmentPurpose(id)
 print("GARMENT_NORMAL_ADVANCE",ok,agent.state,step and step.id,step and step.verb,step and step.status)
end
end
reachNativeWork()
if __garmentCase=="upgrade"then
 local firstPurpose=purpose.id;local removalWork=rec.resourceProductionWork
 check("garment_upgrade_native_retained_patch_choice",removalWork.operation=="remove-patch"and __scene.clothing:getPatchType(__scene.damagePart)~=nil)
 finishNative();R.reconcileSaved(id,body);local removal=R.outcome(id,removalWork.id)
 print("GARMENT_UPGRADE_REMOVAL_ROW",json(removal),"nativePatch",__scene.clothing:getPatchType(__scene.damagePart))
 check("garment_upgrade_original_paid_removal",removal and removal.status=="completed"and removal.nativeCredit==removal.id and removal.requestedEffectMeasured and removal.paymentMeasured and removal.operation=="remove-patch")
 local g=purpose.garmentMaintenance
 check("garment_upgrade_preparatory_no_use_credit",g.physicalResultId==nil and g.wornUseReceipt==nil and not g.wornBenefitMeasured and g.preparatoryWorkIds and g.preparatoryWorkIds[1]==removal.id and purpose.status~="completed"and purpose.awaitingReassessment==true)
 SAO.Perception.observeGarments(id,body)
 local native,observed=SAO.Perception.garmentForResult(id,body,removal.id)
 local noBenefit=native and R.garmentUseObservation(id,body,removal.id,native,observed)
 check("garment_upgrade_removal_no_benefit",noBenefit and not noBenefit.beneficial and not noBenefit.nativeUseMeasured)
 agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
 local progressed=Ctl.tryGarmentWork(id,agent,body,10);purpose,step=P.garmentPurpose(id)
 check("garment_upgrade_same_original_reassessment",progressed and purpose.id==firstPurpose and purpose.garmentMaintenance.operation=="repair-clothing"and purpose.garmentMaintenance.preparatoryWorkIds[1]==removal.id)
 reachNativeWork()
 __preparatoryRemoval=removal
end
check("garment_actual_signed_inspection",inspected>0)
check("garment_actual_three_role_acquisitions",acquired==3)
check("garment_existing_r_actual_dispatch",rec.resourceProductionWork.kind=="maintain-garment"and rec.resourceProductionWork.purposeId==purpose.id)
if __garmentCase=="final-contracts"and __garmentLayer=="unconfirmed"then
 __scene.clothing:getModData().SAOPhysicalService=setmetatable({},{})
end
local work=rec.resourceProductionWork;local physical=finishNative();R.reconcileSaved(id,body)
local row=R.outcome(id,work.id)
print("GARMENT_NORMAL_PHYSICAL",row and row.status,row and row.detail,row and row.serviceRelationStatus)
check("garment_original_native_service_payment_effect",row and row.status=="completed"and row.nativeCredit==row.id and row.paymentMeasured and row.requestedEffectMeasured)
if not(__garmentCase=="final-contracts"and __garmentLayer=="unconfirmed")then
check("garment_original_purpose_awaits_use",purpose.status~="completed"and purpose.garmentMaintenance.physicalResultId==row.id and not row.consumerCompleted)
end

if __garmentCase=="final-contracts"and __garmentLayer=="unconfirmed"then
 check("garment_contract_unconfirmed_actual_paid_truth",row.serviceRelationStatus=="unconfirmed"and row.serviceRelation==nil and row.nativeCredit==row.id and row.paymentMeasured and row.requestedEffectMeasured)
 check("garment_contract_unconfirmed_not_linked",purpose.garmentMaintenance.physicalResultId==nil and purpose.garmentMaintenance.unconfirmedWorkIds[1]==row.id and purpose.awaitingReassessment and step.verb=="produce")
 local pending,current=P.garmentPurpose(id)
 check("garment_contract_unconfirmed_no_available_use",pending.status~="completed"and(not current or current.verb~="use"or current.status~="available")and not pending.garmentMaintenance.wornUseReceipt and not pending.garmentMaintenance.wornBenefitMeasured)
 agent.state="IDLE";local replan=Ctl.tryGarmentWork(id,agent,body,20)
 check("garment_contract_unconfirmed_fresh_reassessment",replan==false and pending.awaitingReassessment and pending.garmentMaintenance.physicalResultId==nil and rec.resourceProductionWork==nil)
 local cold=roundTripGarment(__scene.clothing);body:getInventory():Remove(__scene.clothing);body:getInventory():AddItemBlind(cold);cold:setContainer(body:getInventory());wear(cold)
 body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id;SAO.Perception.observeGarments(id,body)
 check("garment_contract_unconfirmed_cold_no_fake_marker",SAO.Perception.garmentForResult(id,body,row.id)==nil and P.garmentUseReceipt(id,pending.id)==nil)
 local archive=SAO.Cognition.snapshot(id,true);local physical,use=0,0;for _,e in ipairs(archive.experiences or{})do if e.kind=="garment-maintenance"then physical=physical+1 elseif e.kind=="garment-use"then use=use+1 end end
 check("garment_contract_unconfirmed_physical_archive_only",physical==1 and use==0)
 check("garment_contract_unconfirmed_full_exports",__retainGarmentProjection("private-archive",json(archive))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({physical=row,inputs=__nativeModData("SurvivorAwareness_WorldSources").results,inspection=rec.worldInspectionReceipts})))
 return
elseif __garmentCase=="final-contracts"and __garmentLayer=="wrong-token"then
 local originalMeasurement=R.garmentUseObservation;local captured
 R.garmentUseObservation=function(...)
  local measured=originalMeasurement(...)
  if measured then measured=__plainGarmentSave(measured);measured.currentBodyToken="wrong-current-token";captured=measured end
  return measured
 end
 SAO.Perception.observeGarments(id,body)
 local accepted=P.consumeGarmentUse(id,body,purpose.id);R.garmentUseObservation=originalMeasurement
 check("garment_contract_current_token_refused",captured~=nil and accepted==false and purpose.status~="completed"and not purpose.garmentMaintenance.wornBenefitMeasured and not purpose.garmentMaintenance.wornUseReceipt)
 check("garment_contract_wrong_token_paid_truth_retained",R.outcome(id,row.id).nativeCredit==row.id and purpose.garmentMaintenance.physicalResultId==row.id and P.garmentUseReceipt(id,purpose.id)==nil)
 body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id;SAO.Perception.observeGarments(id,body)
 local archive=SAO.Cognition.snapshot(id,true);local use=0;for _,e in ipairs(archive.experiences or{})do if e.kind=="garment-use"then use=use+1 end end
 check("garment_contract_wrong_token_no_use_event",use==0)
 check("garment_contract_wrong_token_full_exports",__retainGarmentProjection("private-archive",json(archive))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({physical=row,corruptMeasurement=captured,inputs=__nativeModData("SurvivorAwareness_WorldSources").results,inspection=rec.worldInspectionReceipts})))
 return
elseif __garmentCase=="final-contracts"and __garmentLayer=="subclass"then
 check("garment_contract_actual_native_subclass",row.beforeObservation.nativeClass=="NormalGarmentConsumerProbe$OriginalSourceClothing"and row.afterObservation.nativeClass==row.beforeObservation.nativeClass and row.serviceRelation.nativeClass==row.beforeObservation.nativeClass and instanceof(__scene.clothing,"Clothing"))
 SAO.Perception.observeGarments(id,body);local current,observed=SAO.Perception.garmentForResult(id,body,row.id)
 check("garment_contract_subclass_current_native_relation",current==__scene.clothing and observed.nativeClass==row.beforeObservation.nativeClass)
 agent.state="IDLE";local use=P.consumeGarmentUse(id,body,purpose.id)
 check("garment_contract_subclass_separate_use",use and purpose.status=="completed"and purpose.garmentMaintenance.wornBenefitMeasured)
 if __garmentCase=="final-contracts"and __garmentLayer=="current-token"then
 local use=purpose.garmentMaintenance.wornUseReceipt
 check("garment_contract_historical_current_tokens_distinct",use.currentBodyToken==rec.bodyOwnerToken and use.currentObservation.bodyToken==rec.bodyOwnerToken and use.beforeObservation.bodyToken==nil and use.afterPaidObservation.bodyToken==nil and use.serviceRelation.bodyToken==nil and P.garmentUseReceipt(id,purpose.id)~=nil)
end
local archive=SAO.Cognition.snapshot(id,true);local physicalEvents,useEvents=0,0;for _,e in ipairs(archive.experiences or{})do if e.kind=="garment-maintenance"then physicalEvents=physicalEvents+1 elseif e.kind=="garment-use"then useEvents=useEvents+1 end end
 check("garment_contract_sourceclass_full_feedback",physicalEvents==1 and useEvents==1)
 local cold=roundTripGarment(current);body:getInventory():Remove(current);body:getInventory():AddItemBlind(cold);cold:setContainer(body:getInventory());wear(cold)
 body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id;SAO.Perception.observeGarments(id,body)
 check("garment_contract_subclass_cold_factory_limit",cold~=current and SAO.Perception.garmentForResult(id,body,row.id)==nil)
 check("garment_contract_subclass_full_exports",__retainGarmentProjection("private-archive",json(archive))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({physical=row,use=purpose.garmentMaintenance.wornUseReceipt,coldClassRefused=true,inputs=__nativeModData("SurvivorAwareness_WorldSources").results,inspection=rec.worldInspectionReceipts})))
 return
end
if __garmentCase=="stale-use"then
 local originalPurposeId=purpose.id;local oldRow=row;local originalTarget=__scene.clothing
 local nativePart=BloodBodyPartType.FromString(oldRow.part)
 check("garment_stale_initial_paid_pending_use",purpose.garmentMaintenance.physicalResultId==oldRow.id and not purpose.garmentMaintenance.wornBenefitMeasured and oldRow.nativeCredit==oldRow.id)
 if __garmentLayer=="missing"then
  wear(nil);SAO.Perception.observeGarments(id,body);agent.state="IDLE"
  local deferred=Ctl.tryGarmentWork(id,agent,body,21);local retained=P.garmentPurpose(id)
  check("garment_stale_missing_current_evidence_defers",deferred==false and retained.id==originalPurposeId and retained.garmentMaintenance.physicalResultId==oldRow.id and not retained.awaitingReassessment and not retained.garmentMaintenance.retiredUseWorkIds and rec.resourceProductionWork==nil)
  check("garment_stale_missing_no_use_credit",not P.consumeGarmentUse(id,body,retained.id)and not retained.garmentMaintenance.wornUseReceipt and not retained.garmentMaintenance.wornBenefitMeasured and retained.status~="completed")
  local oldBody=body;body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id;SAO.Perception.observeGarments(id,body)
  check("garment_stale_missing_native_snapshot",body~=oldBody and body:getWornItems():size()==0 and retained.garmentMaintenance.physicalResultId==oldRow.id)
  local archive=SAO.Cognition.snapshot(id,true);local physical,use=0,0;for _,event in ipairs(archive.experiences or{})do if event.kind=="garment-maintenance"then physical=physical+1 elseif event.kind=="garment-use"then use=use+1 end end
  check("garment_stale_missing_physical_truth_only",physical==1 and use==0 and R.outcome(id,oldRow.id).nativeCredit==oldRow.id)
  check("garment_stale_missing_full_exports",__retainGarmentProjection("private-archive",json(archive))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({physical=oldRow,inputs=__nativeModData("SurvivorAwareness_WorldSources").results,inspection=rec.worldInspectionReceipts})))
  return
 elseif __garmentLayer=="missing-history"or __garmentLayer=="foreign-history"then
  -- Explicit native plain-save corruption negative; no successful admission/effect claim.
  originalTarget:removePatch(nativePart);originalTarget:getVisual():setHole(nativePart);SAO.Perception.observeGarments(id,body)
  local retired=P.consumeGarmentUse(id,body,purpose.id)
  check("garment_stale_history_authentic_retirement",retired==false and purpose.garmentMaintenance.physicalResultId==nil and purpose.garmentMaintenance.retiredUseWorkIds[1]==oldRow.id and purpose.awaitingReassessment)
  local saved=__plainGarmentSave(rec);local savedBelief=__plainGarmentSave(SAO.Perception.beliefs[id]);local savedPurpose=saved.proceduralPlanning.purposes[purpose.id]
  if __garmentLayer=="missing-history"then
   local phantom="resource-production/"..id.."/999";savedPurpose.garmentMaintenance.retiredUseWorkIds[#savedPurpose.garmentMaintenance.retiredUseWorkIds]=phantom
   savedPurpose.resultReceipts[#savedPurpose.resultReceipts+1]="SAO.ResourceProduction:"..phantom
  else
   for _,prior in ipairs(saved.resourceProductionOutcomes)do if prior.id==oldRow.id then prior.purposeId="foreign-purpose"end end
  end
  __replaceNativeRecord(saved);rec=saved;__record=saved;agent.rec=saved;SAO.Perception.beliefs[id]=savedBelief;SAO.Identity.rebindWorld();purpose=savedPurpose;agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
  check("garment_stale_corrupt_history_native_save",SAO.Identity.get(id)==saved and SAO.Perception.observeGarments(id,body))
  local refused=Ctl.tryGarmentWork(id,agent,body,21)
  print("GARMENT_CORRUPT_HISTORY_ATTEMPT",__garmentLayer,refused,agent.state,rec.worldSourceReservation,rec.resourceProductionWork)
  check("garment_stale_corrupt_history_refused",refused==false and rec.worldSourceReservation==nil and rec.resourceProductionWork==nil)
  check("garment_stale_corrupt_history_no_effect",originalTarget:getVisual():getHole(nativePart)>0 and originalTarget:getPatchType(nativePart)==nil and __scene.container:getCountTypeRecurse("Base.LeatherStrips")==1 and purpose.garmentMaintenance.physicalResultId==nil and not purpose.garmentMaintenance.wornUseReceipt and not purpose.garmentMaintenance.wornBenefitMeasured)
  local oldBody=body;body=__garmentSnapshotRebind(body);SAO.Body.active[id]=body;body:getModData().SAOPersonId=rec.id
  check("garment_stale_corrupt_history_native_snapshot",body~=oldBody and body:getModData().SAOExternalToken==nil and SAO.Perception.observeGarments(id,body))
  local archive=SAO.Cognition.snapshot(id,true);local physical,use=0,0;for _,event in ipairs(archive.experiences or{})do if event.kind=="garment-maintenance"then physical=physical+1 elseif event.kind=="garment-use"then use=use+1 end end
  check("garment_stale_corrupt_history_no_use_event",physical==1 and use==0)
  check("garment_stale_corrupt_history_full_exports",__retainGarmentProjection("private-archive",json(archive))and __retainGarmentProjection("person-save",json(__plainGarmentSave(rec)))and __retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id])))and __retainGarmentProjection("native-outcomes",json({originalPaid=oldRow,corruptedStoredRows=rec.resourceProductionOutcomes,inputs=__nativeModData("SurvivorAwareness_WorldSources").results,inspection=rec.worldInspectionReceipts,corruption=__garmentLayer})))
  return
 elseif __garmentLayer=="replacement"then
  local replacement=give("Shirt_FormalWhite");replacement:setID(originalTarget:getID());replacement:getVisual():setHole(nativePart)
  body:getInventory():Remove(originalTarget);wear(replacement);__scene.clothing=replacement
  SAO.Perception.observeGarments(id,body)
  check("garment_stale_replacement_old_relation_refused",replacement:getModData().SAOPhysicalService==nil and SAO.Perception.garmentForResult(id,body,oldRow.id)==nil)
 else
  originalTarget:removePatch(nativePart);originalTarget:getVisual():setHole(nativePart)
  check("garment_stale_original_native_target_damage",originalTarget:getPatchType(nativePart)==nil and originalTarget:getVisual():getHole(nativePart)>0 and originalTarget:getModData().SAOPhysicalService[oldRow.part].workId==oldRow.id)
 end
 agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
 local advanced=Ctl.tryGarmentWork(id,agent,body,21);purpose,step=P.garmentPurpose(id)
 if not advanced and purpose and purpose.garmentMaintenance.physicalResultId==nil then advanced=Ctl.tryGarmentWork(id,agent,body,22);purpose,step=P.garmentPurpose(id)end
 print("GARMENT_STALE_NORMAL_REPLAN",__garmentLayer,advanced,purpose and purpose.id,purpose and purpose.garmentMaintenance.physicalResultId,step and step.verb)
 check("garment_stale_same_original_replan",advanced and purpose.id==originalPurposeId and purpose.garmentMaintenance.physicalResultId~=oldRow.id and step and step.verb~="use")
 check("garment_stale_old_physical_truth_no_use",R.outcome(id,oldRow.id).status=="completed"and R.outcome(id,oldRow.id).nativeCredit==oldRow.id and not purpose.garmentMaintenance.wornUseReceipt and not purpose.garmentMaintenance.wornBenefitMeasured)
 reachNativeWork();local nextWork=rec.resourceProductionWork
 check("garment_stale_second_exact_source_acquisition",acquired==4 and nextWork and nextWork.purposeId==originalPurposeId and nextWork.id~=oldRow.id)
 finishNative();R.reconcileSaved(id,body);row=R.outcome(id,nextWork.id);work=nextWork
 check("garment_stale_next_original_native_service",row and row.status=="completed"and row.nativeCredit==row.id and row.paymentMeasured and row.requestedEffectMeasured and purpose.garmentMaintenance.physicalResultId==row.id)
 __stalePhysical=oldRow
end
local original=__scene.clothing
check("garment_authentic_native_service_marker",row.serviceRelationStatus=="confirmed"and original:getModData().SAOPhysicalService[row.part].workId==row.id)
local cold=roundTripGarment(original)
check("garment_native_item_cold_save",cold~=original and cold:getID()==original:getID()and cold:getModData().SAOPhysicalService[row.part].workId==row.id)
body:getInventory():Remove(original);body:getInventory():AddItemBlind(cold);cold:setContainer(body:getInventory());wear(cold)
check("garment_fresh_cold_worn_observation",SAO.Perception.observeGarments(id,body))
local coldNative,coldFact=SAO.Perception.garmentForResult(id,body,row.id)
check("garment_cold_current_authentic_result",coldNative==cold and coldFact~=nil)
if __garmentCase=="layers"then
 check("garment_layer_outer_native_removed",__setOuterGarment(false))
 check("garment_layer_fresh_after_outer_change",SAO.Perception.observeGarments(id,body))
 coldNative,coldFact=SAO.Perception.garmentForResult(id,body,row.id)
end
local coldUse=R.garmentUseObservation(id,body,row.id,cold,coldFact)
if __garmentCase=="layers"then
 check("garment_layer_target_survives_lower_aggregate",coldUse and coldUse.beneficial and coldUse.currentObservation.targetScratchDefense>row.beforeObservation.targetScratchDefense and coldUse.currentObservation.wornScratchDefense<row.beforeObservation.wornScratchDefense and coldUse.targetScratchDefense==coldUse.currentObservation.targetScratchDefense and coldUse.targetBiteDefense==coldUse.currentObservation.targetBiteDefense)
end
check("garment_actual_cold_worn_benefit",coldUse and coldUse.effectMatchesCanonical and coldUse.nativeUseMeasured and coldUse.beneficial)
local saved=__plainGarmentSave(rec);local savedBelief=__plainGarmentSave(SAO.Perception.beliefs[id])
check("garment_person_belief_plain_save",saved.proceduralPlanning.purposes[purpose.id].garmentMaintenance.physicalResultId==row.id and savedBelief.garments~=nil)
if __garmentCase=="stale-use"then check("garment_stale_retired_history_plain_save",saved.proceduralPlanning.purposes[purpose.id].garmentMaintenance.retiredUseWorkIds[1]==__stalePhysical.id)end
__replaceNativeRecord(saved);rec=saved;__record=saved;agent.rec=saved;SAO.Perception.beliefs[id]=savedBelief;SAO.Identity.rebindWorld()
local oldBody=body;body=__garmentSnapshotRebind(oldBody);SAO.Body.active[id]=body
-- Original Body publication binds runtime identity; NativeSnapshot deliberately excludes SAOPersonId.
body:getModData().SAOPersonId=rec.id
if __garmentCase=="final-contracts"and __garmentLayer=="current-token"then
 rec.bodyOwnerToken="current-cold-rebind-token";body:getModData().SAOExternalToken=rec.bodyOwnerToken
 check("garment_contract_legitimate_current_token",row.bodyToken==nil and row.serviceRelation.bodyToken==nil and body:getModData().SAOExternalToken==rec.bodyOwnerToken and rec.bodyOwnerToken~=row.bodyToken and SAO.Body.get(id)==body)
end
check("garment_actual_native_wearer_rebind",body~=oldBody and body:getModData().SAOPersonId==id and body:getModData().SAOExternalToken==rec.bodyOwnerToken and SAO.Body.get(id)==body)
check("garment_rebound_private_observation",SAO.Perception.observeGarments(id,body))
local rebound,observed=SAO.Perception.garmentForResult(id,body,row.id)
check("garment_rebound_native_marker_source",rebound~=nil and rebound~=cold and rebound:getID()==cold:getID()and observed~=nil)
purpose=rec.proceduralPlanning.purposes[purpose.id];step=purpose.steps[purpose.cursor];agent.state="IDLE"
check("garment_normal_original_worn_use_closure",Ctl.advanceGarmentWork(id,agent,body,20,purpose,step)and purpose.status=="completed"and purpose.garmentMaintenance.wornBenefitMeasured)
if __garmentCase=="final-contracts"and __garmentLayer=="current-token"then
 local use=purpose.garmentMaintenance.wornUseReceipt
 check("garment_contract_historical_current_tokens_distinct",use.currentBodyToken==rec.bodyOwnerToken and use.currentObservation.bodyToken==rec.bodyOwnerToken and use.beforeObservation.bodyToken==nil and use.afterPaidObservation.bodyToken==nil and use.serviceRelation.bodyToken==nil and P.garmentUseReceipt(id,purpose.id)~=nil)
end
local archive=SAO.Cognition.snapshot(id,true);local physicalEvents,useEvents=0,0
for _,event in ipairs(archive.experiences or{})do
 if event.kind=="garment-maintenance"then physicalEvents=physicalEvents+1 end
 if event.kind=="garment-use"then useEvents=useEvents+1 end
end
check("garment_independent_full_feedback",physicalEvents==((__garmentCase=="upgrade"or __garmentCase=="stale-use")and 2 or 1) and useEvents==1)
if __garmentCase=="upgrade"then
 local preparatory
 for _,event in ipairs(archive.experiences or{})do if event.kind=="garment-maintenance"and event.garmentWork.operation=="remove-patch"then preparatory=event end end
 check("garment_upgrade_feedback_preparatory_truth",preparatory and preparatory.garmentWork.wornBenefitMeasured==false and preparatory.garmentWork.consumerCompleted==false and purpose.garmentMaintenance.preparatoryWorkIds[1]==__preparatoryRemoval.id and purpose.status=="completed")
end
if __garmentCase=="stale-use"then
 check("garment_stale_latest_use_only",purpose.garmentMaintenance.wornUseReceipt.workId==row.id and __stalePhysical.id~=row.id and R.outcome(id,__stalePhysical.id).nativeCredit==__stalePhysical.id)
 local current,fact=SAO.Perception.garmentForResult(id,body,row.id)
 check("garment_stale_old_result_cannot_reclaim",R.garmentUseObservation(id,body,__stalePhysical.id,current,fact)==nil)
 local priorCount=#SAO.Cognition.snapshot(id,true).experiences
 local oldCallback=P.consumeGarmentOutcome(id,__stalePhysical)
 local oldFeedback,oldWhy=SAO.Cognition.garmentMaintenanceOutcome(id,__stalePhysical)
 check("garment_stale_old_callback_inert",oldCallback==false and oldFeedback and oldWhy=="duplicate"and purpose.status=="completed"and purpose.garmentMaintenance.physicalResultId==row.id and purpose.garmentMaintenance.wornUseReceipt.workId==row.id and #SAO.Cognition.snapshot(id,true).experiences==priorCount)

end
local beforeCount=#archive.experiences
local againPhysical=P.consumeGarmentOutcome(id,row);local againUse=P.consumeGarmentUse(id,body,purpose.id)
local againPhysicalFeedback,physicalWhy=SAO.Cognition.garmentMaintenanceOutcome(id,row);local againUseFeedback,useWhy=SAO.Cognition.garmentUseOutcome(id,purpose.id)
print("GARMENT_REPLAY_RETURNS",againPhysical,againUse,againPhysicalFeedback,physicalWhy,againUseFeedback,useWhy,#SAO.Cognition.snapshot(id,true).experiences,beforeCount)
check("garment_canonical_replay_once",againUse and (againPhysicalFeedback or __garmentCase=="final-contracts"and __garmentLayer=="current-token"and physicalWhy=="garment-owner-unavailable") and againUseFeedback and #SAO.Cognition.snapshot(id,true).experiences==beforeCount and purpose.status=="completed"and R.outcome(id,row.id).id==row.id)
local replacement=give("Shirt_FormalWhite");replacement:setID(rebound:getID());body:getInventory():Remove(rebound);wear(replacement)
SAO.Perception.observeGarments(id,body)
check("garment_same_id_unmarked_replacement_refused",SAO.Perception.garmentForResult(id,body,row.id)==nil)
body:getInventory():Remove(replacement);body:getInventory():AddItemBlind(rebound);rebound:setContainer(body:getInventory());wear(rebound);SAO.Perception.observeGarments(id,body)
check("garment_original_rebound_result_rejoins",SAO.Perception.garmentForResult(id,body,row.id)==rebound)
check("garment_full_private_archive_retained",__retainGarmentProjection("private-archive",json(SAO.Cognition.snapshot(id,true))))
check("garment_full_person_save_retained",__retainGarmentProjection("person-save",json(__plainGarmentSave(rec))))
check("garment_full_private_belief_retained",__retainGarmentProjection("private-belief",json(__plainGarmentSave(SAO.Perception.beliefs[id]))))
check("garment_full_native_outcomes_retained",__retainGarmentProjection("native-outcomes",json({stalePhysical=__stalePhysical,preparatory=__preparatoryRemoval,physical=row,use=purpose.garmentMaintenance.wornUseReceipt,inputs=__nativeModData("SurvivorAwareness_WorldSources").results,inspection=rec.worldInspectionReceipts})))
