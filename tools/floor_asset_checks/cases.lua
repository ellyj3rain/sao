local P,WS,SU,Ctl=SAO.ProceduralPlanning,SAO.WorldSources,SAO.SourceUse,SAO.Controller
local failures={}
local function check(name,fn)
    local ok,value=pcall(fn);print("CHECK "..name.."="..tostring(ok and value==true))
    if not ok then print("ERROR "..name..": "..tostring(value)) end
    if not ok or value~=true then failures[#failures+1]=name end
end
local function setup(item,x,y,z)
    SAO.Study.interrupt("person",__body,"fixture-reset")
    fresh();__clearGround();__stores={};SAO.Perception.beliefs={};__permit=true;__deferDelivery=false
    Ctl.agents.person.state="IDLE";__body:setForwardDirection(1,0)
    __body:getInventory():clear();__place(item or __harmonica,x or 11,y or 20,z or 0)
    return Ctl.agents.person
end
local function observed(item)
    local a=setup(item);assert(SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()),"private sight");return a
end
local function selected(item)
    local a=observed(item);assert(Ctl.__floorRest("person",a,__body,SAO.History.ticks(),a.rec),"selected acquisition")
    return a,assert(WS.pendingActionFor("person"),"reservation")
end
local function arrive()
    local moved=SU.onMovementDone("person",__body,"arrived")
    if moved=="moving" then moved=SU.onMovementDone("person",__body,"arrived") end
    return moved
end
local function transfer(a,r,item,deliver)
    assert(arrive()=="using","native transfer admission")
    local action=assert(ISTimedActionQueue.queues[__body].queue[1])
    assert(item:getContainer()~=__body:getInventory(),"queue is not pickup")
    action:perform();__finishNativeAction(action.action)
    __deferDelivery=deliver==false
    assert(SU.tick("person",__body)=="completed","native transfer result")
    __deferDelivery=false
    if deliver~=false then SAO.Provisioning.consumeCompleted() end
    local result=assert(WS.actionOutcome(r.id,"person"))
    assert(result.status=="completed" and result.measurement=="native-item-transfer")
    a.state="IDLE";a.pressure=nil;return a,r,result
end
local function acquire(item)local a,r=selected(item);return transfer(a,r,item)end
local function purpose(a,r)return a.rec.proceduralPlanning.purposes[r.purposeId]end
local function use(a)return Ctl.__floorRest("person",a,__body,SAO.History.ticks()+1,a.rec)end
local function empty(t)for _ in pairs(t)do return false end;return true end
check("visible_ground_enters_only_observing_person",function()
    local a=observed(__harmonica)
    return #Ctl.leisureGroundOffers("person",__body)==1 and SAO.Perception.beliefs.foreign==nil
        and __harmonica:getContainer()~=__body:getInventory() and a.rec.proceduralPlanning==nil
end)
check("ordinary_perception_cadence_produces_floor_offer",function()
    setup(__harmonica)
    SAO.Perception.observe("person",__body,SAO.History.ticks(),false)
    return #Ctl.leisureGroundOffers("person",__body)==1
end)
check("hidden_or_other_floor_is_not_observed",function()
    setup(__harmonica,4,20,0)
    if SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()) then return false end
    setup(__harmonica,11,20,1);return not SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks())
end)
check("foreign_asleep_dead_and_external_bodies_refused",function()
    local a=setup()
    if SAO.Perception.observeLooseItems("person",__other,SAO.History.ticks()) then return false end
    __body:setAsleep(true)
    if SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()) then return false end
    __body:setAsleep(false);a.rec.dead=true
    if SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()) then return false end
    a.rec.dead=nil;__body:getModData().ZAOOwned=true
    local refused=not SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks())
    __body:getModData().ZAOOwned=nil;return refused
end)
check("future_observation_time_cannot_create_private_offer",function()
    setup();return not SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()+1)
        and SAO.Perception.beliefs.person==nil
end)
check("visible_packet_preserves_other_observed_source",function()
    setup(__harmonica);__place(__book,12,20,0)
    assert(SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()))
    return #Ctl.leisureGroundOffers("person",__body)==2
end)
check("passive_sight_does_not_reveal_hidden_fluid_safety",function()
    __fluid(__bottle,false);observed(__bottle)
    local function fact()
        for _,belief in pairs(SAO.Perception.knownPlaces("person",true)) do
            for _,row in pairs(belief.sourceFacts) do return row end
        end
    end
    local first=assert(fact())
    if not first.visibleItem or not empty(first.quantities) or not empty(first.candidates) then return false end
    local initiallyUnknown=WS.knownHydrationAmount("person",first.id,first.visibleItem.id,first.revision)==nil
    __fluid(__bottle,true)
    assert(SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()))
    local second=assert(fact())
    return initiallyUnknown and first.revision~=second.revision and first.visibleItem.id==second.visibleItem.id
        and first.visibleItem.type==second.visibleItem.type and first.knowledgeKind=="visible-ground"
        and empty(first.quantities) and empty(second.quantities)
        and empty(first.candidates) and empty(second.candidates)
        and WS.knownHydrationAmount("person",second.id,second.visibleItem.id,second.revision)==nil
end)
check("visible_leisure_candidates_do_not_refill_hidden_fields",function()
    observed(__harmonica)
    local p=assert(Ctl.leisureGroundOffers("person",__body)[1]).option.parameters
    local fact=WS.beliefFact(p.sourceId,"visible-ground");local candidate=fact.candidates.instrument
    return p.itemAmount==nil and p.itemUses==nil and p.itemHydrationAmount==nil and p.itemSignature==nil
        and candidate.amount==nil and candidate.fluid==nil and candidate.poison==nil
        and candidate.tainted==nil and candidate.currentUses==nil and candidate.hydrationAmount==nil
end)
check("material_support_uses_installed_metadata",function()
    observed(__whistle);if #Ctl.leisureGroundOffers("person",__body)~=0 then return false end
    observed(__guitar);if #Ctl.leisureGroundOffers("person",__body)~=0 then return false end
    observed(__harmonica);return #Ctl.leisureGroundOffers("person",__body)==1
end)
check("selection_creates_only_selected_exact_purpose",function()
    local a=setup(__harmonica);__place(__book,12,20,0)
    assert(SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()));assert(use(a))
    local r=assert(WS.pendingActionFor("person"));local p=purpose(a,r)
    local selected
    for _,offer in ipairs(a.rec.leisureDecision.alternatives) do
        if offer.id==a.rec.leisureDecision.selected then selected=offer end
    end
    return #a.rec.proceduralPlanning.order==1 and #a.rec.leisureDecision.alternatives==2
        and selected and selected.kind=="acquire"
        and p.leisureAcquisition.itemId==selected.itemKey and p.steps[1].status~="completed"
        and r.purposeId==p.id and tostring(r.itemId)==selected.itemKey
        and p.leisureAcquisition.itemType==selected.itemType and r.itemType==selected.itemType
end)
check("permission_refuses_offer_and_current_native_admission",function()
    local a=observed(__harmonica);__permit=false
    if #Ctl.leisureGroundOffers("person",__body)~=0 then return false end
    __permit=true;assert(use(a));__permit=false
    return arrive()=="failed" and not __body:getInventory():contains(__harmonica) and not SAO.Needs.busy(__body)
end)
check("changed_native_revision_cannot_transfer_old_offer",function()
    local a,r=selected(__harmonica);local old=__harmonica:getCondition();__harmonica:setCondition(old-1)
    local answer=arrive();__harmonica:setCondition(old)
    return answer=="failed" and not __body:getInventory():contains(__harmonica)
end)
check("same_type_replacement_cannot_satisfy_exact_item",function()
    selected(__harmonica);local replacement=__cloneItem(__harmonica);__clearGround();__place(replacement,11,20,0)
    return arrive()=="failed" and not __body:getInventory():contains(replacement) and not __body:getInventory():contains(__harmonica)
end)
check("queue_and_generic_result_are_not_acquisition",function()
    local a,r=selected(__harmonica);local p=purpose(a,r);assert(arrive()=="using")
    local accepted=P.recordResult("person",p.id,{owner="SAO.SourceUse",token="leisure:item-acquired",
        correlationId=r.id,status="completed",atHours=SAO.History.countyHours()})
    return not accepted and p.steps[1].status~="completed" and p.leisureAcquisition.resultId==nil
        and not __body:getInventory():contains(__harmonica)
end)
check("interrupted_acquisition_delays_only_exact_source_retry",function()
    local a,r=selected(__harmonica);SU.interrupt("person",__body,"threat");SAO.Provisioning.consumeCompleted()
    local p=purpose(a,r)
    return p.steps[1].status~="completed" and p.leisureAcquisition.resultId==nil
        and not P.leisureAcquisitionAvailable("person",r.sourceId,r.itemId,r.revision)
        and P.leisureAcquisitionAvailable("person",r.sourceId,tostring(r.itemId).."-other",r.revision)
end)
check("superseded_step_cannot_receive_old_native_result",function()
    local a,r=selected(__harmonica);local p=purpose(a,r);transfer(a,r,__harmonica,false)
    p.steps[1].target="a different exact source";SAO.Provisioning.consumeCompleted()
    return p.steps[1].status~="completed" and p.leisureAcquisition.resultId==nil
end)
check("contrary_private_acquisition_identity_refuses_result",function()
    local a,r=selected(__harmonica);local p=purpose(a,r);transfer(a,r,__harmonica,false)
    p.leisureAcquisition.itemId="other-item"
    return not P.consumeSourceResult(WS.actionOutcome(r.id,"person")) and p.steps[1].status~="completed"
end)
check("actual_harmonica_acquisition_then_same_purpose_native_sound",function()
    local a,r=acquire(__harmonica);local p=purpose(a,r)
    if p.steps[1].status~="completed" or p.status=="completed" or not use(a) then return false end
    local work=SAO.Gesture.instrumentWork("person")
    if not work or not p.admission or p.admission.correlationId~=work.workId or work.itemId~=tostring(__harmonica:getID()) then return false end
    local action=ISTimedActionQueue.queues[__body].queue[1]
    action:update();__emitter:finish();action:update();action:perform();__finishNativeAction(action.action)
    return SAO.Gesture.instrumentOutcome("person",work.workId).status=="completed"
        and p.steps[p.cursor].id=="share-activity" and p.status~="completed"
end)
check("actual_written_item_acquisition_then_same_purpose_note_owner",function()
    __notebook:addPage(1,"Existing private journal text.");local a,r=acquire(__notebook);local p=purpose(a,r)
    if not use(a) then return false end
    local w=a.rec.studyWork
    if not(w and w.contentKind=="written-note" and w.purposeId==r.purposeId and w.itemId==tostring(__notebook:getID())
        and w.status=="reading" and w.content==nil) then return false end
    local action=ISTimedActionQueue.queues[__body].queue[1]
    __nativeAction(action.action,"progress",1);__nativeAction(action.action,"perform");__nativeAction(action.action,"complete")
    __finishNativeAction(action.action)
    return w.status=="completed" and w.exposureCompleted and p.steps[p.cursor].id=="share-activity"
        and p.status~="completed" and __body:getAlreadyReadPages(__notebook:getFullType())==0
end)
check("acquired_reading_purpose_competes_with_other_carried_material",function()
    __notebook:addPage(1,"Existing private journal text.");local a,r=acquire(__notebook)
    __body:getInventory():AddItem(__harmonica)
    if not use(a) then return false end
    return a.rec.studyWork and a.rec.studyWork.purposeId==r.purposeId
        and not SAO.Gesture.instrumentWork("person")
        and a.rec.leisureDecision.selected=="reading:"..tostring(__notebook:getID())
end)
check("actual_book_acquisition_reaches_native_book_owner",function()
    local a,r=acquire(__book);if not use(a) then return false end;local w=a.rec.studyWork
    if not(w and w.contentKind=="native-book" and w.purposeId==r.purposeId and w.status=="reading"
        and w.itemId==tostring(__book:getID()) and w.progress==0) then return false end
    local action=ISTimedActionQueue.queues[__body].queue[1]
    __nativeAction(action.action,"progress",1);__nativeAction(action.action,"perform");__nativeAction(action.action,"complete")
    __finishNativeAction(action.action)
    return w.status=="completed" and action.nativeCompleted==true
        and purpose(a,r).steps[purpose(a,r).cursor].id=="share-activity"
end)
check("serialized_acquisition_preserves_identity_before_and_after_transfer",function()
    local a,r=selected(__harmonica);local oldPurpose=r.purposeId
    a.rec.proceduralPlanning=__roundTrip(a.rec.proceduralPlanning);__stores=__roundTrip(__stores)
    SAO.Perception.beliefs=__roundTrip(SAO.Perception.beliefs)
    if SU.resume("person",__body)~="SOURCEWARD" then return false end
    r=WS.pendingActionFor("person");transfer(a,r,__harmonica)
    a.rec.proceduralPlanning=__roundTrip(a.rec.proceduralPlanning);__stores=__roundTrip(__stores)
    if not use(a) then return false end
    local w=SAO.Gesture.instrumentWork("person");local p=a.rec.proceduralPlanning.purposes[oldPurpose]
    return w and p.admission and p.admission.correlationId==w.workId and p.steps[1].status=="completed"
        and p.leisureAcquisition.resultId==r.id
end)
check("foreign_canonical_transfer_cannot_rebind_acquired_purpose",function()
    local a,r=acquire(__harmonica);local p=purpose(a,r);p.leisureAcquisition.resultId="another-person-result"
    assert(use(a));return p.leisure==nil and #a.rec.proceduralPlanning.order==2
end)
check("reobserved_dropped_item_retains_prior_acquisition_receipt",function()
    local a,r=acquire(__harmonica);local p=purpose(a,r);__place(__harmonica,11,20,0)
    assert(SAO.Perception.observeLooseItems("person",__body,SAO.History.ticks()))
    if not use(a) then return false end
    local next=WS.pendingActionFor("person")
    return next and next.purposeId~=r.purposeId and p.leisureAcquisition.resultId==r.id
        and p.steps[1].status=="completed" and WS.actionOutcome(r.id,"person").status=="completed"
end)
print("FLOOR_ASSET_DONE")
if #failures>0 then error("FLOOR_ASSET_FAIL:"..table.concat(failures,",")) end
