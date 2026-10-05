local P,G,O,C,M = SAO.ProceduralPlanning,SAO.Gesture,SAO.Organization,SAO.Coordination,SAO.Communication
local function finish(action)
    action:update();__emitter:finish();action:update();action:perform();__finishNativeAction(action.action)
end
local function start(purpose)
    assert(G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,purpose.id),"native performance admission")
    return ISTimedActionQueue.queues[__body].queue[1],G.instrumentWork("person")
end
local function setup()
    __clock(12);fresh();__pulseReset();__deaf(false);__talk=0.8;__threat=nil
    __records.listener={id="listener"};SAO.Body.active.listener=__other
    SAO.Controller.agents.listener={rec=__records.listener,state="IDLE"}
    __other:getModData().SAOPersonId="listener";__other:getModData().SAOExternalToken=nil;__other:setAsleep(false)
    __moveListener(12.5,20.5,-1,0);__body:setForwardDirection(1,0)
    O.processes={};O.processOrder={};O.processMeta={sequence=0};O.workReceipts={}
    local p=P.planLeisure("person",{activity="music",itemKey=tostring(__harmonica:getID()),affordance="Base.Harmonica",
        nativeVerb="blow-harmonica",owner="SAO.Gesture",locationKey="current",atLocation=true})
    local a=start(p);finish(a)
    assert(P.participationSource("person",p.id),"authentic solo leaves sharing intention")
    local process,why=C.proposeLeisure("person","listener",p.id)
    assert(process,"proposal "..tostring(why))
    return p,process
end
local function accept(row)
    local response,context=C.formResponse("listener",row.processId,__other,"IDLE")
    assert(response,"response missing")
    assert(response.response=="accept","response "..tostring(response.response).." "..tostring(context and context.terms.reason))
    assert(M.deliverPendingResponses("listener","person","spoken")==1,"returned assent")
    local c=O.activeCommitment("listener","leisure-participation")
    local p=C.prepareParticipation("person",__body,row.commitmentId)
    assert(p,"fresh performance plan")
    return p,c
end
check("native_shared_occurrence_requires_proposal_assent_hearing_and_ack",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    if work.sequence<2 or O.participationOutcome("person",row.processId)~=nil then return false end
    __scan(__other);local heard,why=C.advanceParticipation("listener",__other,c.id)
    assert(heard,"hearing "..tostring(why));if old.status=="completed" then return false end
    finish(action)
    local outcome=O.participationOutcome("person",row.processId)
    return outcome and outcome.workId==work.workId and old.status=="completed" and p.status=="completed"
        and P.snapshot("person").practiceDomains==0
end)
check("recipient_independently_declines_or_defers",function()
    local old,row=setup();__talk=0.2
    local response=C.formResponse("listener",row.processId,__other,"IDLE")
    if not response or response.response~="decline" then return false end
    old,row=setup();__threat={dist=2}
    response=C.formResponse("listener",row.processId,__other,"IDLE")
    return response and response.response=="defer" and C.prepareParticipation("person",__body,row.commitmentId)==nil
end)
check("response_must_return_before_performance",function()
    local old,row=setup();local response=C.formResponse("listener",row.processId,__other,"IDLE")
    return response and response.response=="accept" and C.prepareParticipation("person",__body,row.commitmentId)==nil
        and O.deliverResponse(row.processId,"listener","person","spoken",{})==false
end)
check("heard_without_return_does_not_complete_performer",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    __scan(__other);local heard=SAO.Perception.acquireInstrumentHearing("listener",__other,"person",work.workId)
    if not heard or not O.consumeParticipationHearing(row.processId,"listener") then return false end
    finish(action)
    return O.participationOutcome("person",row.processId)==nil and old.status~="completed"
        and O.receiveParticipation(row.processId,"listener","person","acknowledgement")==false
end)
check("generic_result_and_caller_authored_assent_refused",function()
    local old,row=setup()
    if O.respond(row.processId,"listener","accept",{stepIds={"listen"}},{})~=nil then return false end
    local p,c=accept(row);local action,work=start(p)
    return O.noteWorkAdmission(c.id,"SAO.Perception","forged",{stepId="listen"})==false
        and O.consumeProcedureResult({commitmentId=c.id,id="forged",actorId="listener",token="participation:heard",status="completed"})==false
        and P.recordResult("person",old.id,{owner="native-participation",token="leisure:shared",status="completed"})==false
end)
check("related_private_intention_can_change_same_invitation_choice",function()
    local old,row=setup();__talk=0.2
    P.planLeisure("listener",{activity="music",affordance="listening",locationKey="current",atLocation=true})
    local answer=C.formResponse("listener",row.processId,__other,"IDLE")
    return answer and answer.response=="accept" and O.viewFor("person",row.processId,false).privateInputs.interests==nil
end)
check("own_unfinished_material_need_defers_same_invitation",function()
    local old,row=setup()
    local p=P.maintain("listener",{key="own-food",objective="find food",domain="resource"});p.resourceCategory="food"
    local answer=C.formResponse("listener",row.processId,__other,"IDLE")
    return answer and answer.response=="defer"
end)
check("other_accepted_obligation_defers_same_invitation",function()
    local old,row=setup()
    local work=O.raiseMatter("listener","supplies",nil,{cooperative=true,procedure={{id="work",verb="hold",capability="hold",assignedTo="listener",completesOn="held"}}},{"person"},{})
    assert(O.commitOriginator(work.id,"listener",{stepIds={"work"},capabilities={hold=true}}))
    local answer=C.formResponse("listener",row.processId,__other,"IDLE")
    return answer and answer.response=="defer"
end)
check("anonymous_sound_or_no_scanner_never_completes_listening",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    if C.advanceParticipation("listener",__other,c.id)~=false then return false end
    __moveListener(16.5,20.5,1,0);__scan(__other)
    return C.advanceParticipation("listener",__other,c.id)==false and old.status~="completed"
end)
check("stale_body_or_current_danger_prevents_prequeue_performance",function()
    local old,row=setup();local p,c=accept(row);local count=__noiseCount()
    __threat={dist=1}
    if G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id) then return false end
    __threat=nil;__records.person.bodyOwnerToken="foreign"
    return C.participationOffer("person",__body,row.commitmentId)==nil and __noiseCount()==count
end)
check("old_solo_receipt_cannot_fulfil_fresh_accepted_roles",function()
    local old,row=setup();local prior=G.instrumentOutcome("person");local p,c=accept(row)
    return O.consumeParticipationPerformance(row.processId,"person",prior.workId)==false
        and O.consumeParticipationHearing(row.processId,"listener")==false and old.status~="completed"
end)
check("native_interruption_preserves_unfinished_sharing",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    __scan(__other);assert(C.advanceParticipation("listener",__other,c.id))
    action:stop();__finishNativeAction(action.action)
    local result=G.instrumentOutcome("person",work.workId)
    return result and result.status=="interrupted" and O.participationOutcome("person",row.processId)==nil
        and old.status~="completed"
end)
check("missing_return_transport_preserves_private_hearing_for_later_ack",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    __scan(__other);assert(SAO.Perception.acquireInstrumentHearing("listener",__other,"person",work.workId))
    assert(O.consumeParticipationHearing(row.processId,"listener"));finish(action)
    __moveListener(26.5,20.5,-1,0)
    if M.deliverParticipationAcknowledgements("listener","person")~=0 or old.status=="completed" then return false end
    __moveListener(12.5,20.5,-1,0)
    return M.deliverParticipationAcknowledgements("listener","person")==1 and old.status=="completed"
end)
check("native_serialization_preserves_pending_ack_without_replaying_pulse",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    __scan(__other);assert(SAO.Perception.acquireInstrumentHearing("listener",__other,"person",work.workId))
    assert(O.consumeParticipationHearing(row.processId,"listener"));finish(action)
    O.processes=__roundTrip(O.processes);O.workReceipts=__roundTrip(O.workReceipts)
    for _,id in ipairs({"person","listener"}) do
        __records[id]=__roundTrip(__records[id]);SAO.Controller.agents[id].rec=__records[id]
    end
    __pulseReset()
    if SAO.Perception.acquireInstrumentHearing("listener",__other,"person",work.workId)~=nil then return false end
    if M.deliverParticipationAcknowledgements("listener","person")~=1 then return false end
    local restored=__records.person.proceduralPlanning.purposes[old.id]
    return restored.status=="completed" and M.deliverParticipationAcknowledgements("listener","person")==0
        and P.consumeParticipation("person",row.processId)==true
end)
check("lost_runtime_reconciles_to_unobservable_not_completion",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    -- Process restart loses its runtime queue and cannot recreate a pulse.
    local saved=__roundTrip(__records.person);local graph=__roundTrip(O.processes)
    G.resetInstruments();__finishNativeAction(action.action)
    __records.person=saved;SAO.Controller.agents.person.rec=saved;O.processes=graph
    assert(P.reconcileInstrument("person","native-owner-lost"))
    local cc=O.commitment(row.commitmentId)
    return cc.status=="paused" and cc.work.pauseReason=="native-performance-owner-lost"
        and saved.proceduralPlanning.purposes[old.id].status~="completed" and O.participationOutcome("person",row.processId)==nil
end)
check("suspended_sharing_receives_exact_result_without_active_capacity",function()
    local old,row=setup()
    for i=1,14 do assert(P.maintain("person",{key="pressure"..i,objective="other unfinished work"})) end
    local s=__records.person.proceduralPlanning
    if not s.suspendedLeisure or not s.suspendedLeisure.purposes[old.id] then return false end
    local p,c=accept(row);local action,work=start(p);__scan(__other)
    assert(C.advanceParticipation("listener",__other,c.id));finish(action)
    return old.status=="completed" and #s.order<=12 and s.suspendedLeisure.purposes[old.id].participationResult.workId==work.workId
end)
check("withdrawal_or_future_assent_refuses_stale_prepared_purpose",function()
    local old,row=setup();local p,c=accept(row)
    assert(O.withdrawMatter(row.processId,"person","reconsidered"))
    if G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id) then return false end
    old,row=setup();p,c=accept(row)
    local process=O.processes[row.processId]
    process.participants.listener.responses["1"].deliveredAt=SAO.History.countyHours()+1
    return G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id)==false
end)
check("future_hearing_and_foreign_process_cannot_create_ack",function()
    local old,row=setup();local p,c=accept(row);local action,work=start(p)
    __scan(__other);assert(SAO.Perception.acquireInstrumentHearing("listener",__other,"person",work.workId))
    local hearing=__records.listener.instrumentHearings[1]
    hearing.acquiredAtCountyHours=SAO.History.countyHours()+1
    if O.consumeParticipationHearing(row.processId,"listener") then return false end
    hearing.acquiredAtCountyHours=SAO.History.countyHours()
    return O.consumeParticipationHearing("foreign-process","listener")==false
        and O.participationOutcome("listener",row.processId)==nil
end)
check("current_generation_required_for_returned_assent",function()
    local old,row=setup();assert(C.formResponse("listener",row.processId,__other,"IDLE"))
    __records.listener.bodyOwnerToken="not-this-body"
    return M.deliverPendingResponses("listener","person","spoken")==0
        and O.viewFor("person",row.processId,false).responses.listener.response=="unanswered"
end)
check("expired_proposal_cannot_execute_but_intention_can_be_reoffered",function()
    local old,row=setup();local p,c=accept(row)
    __clock(13.01)
    if C.prepareParticipation("person",__body,row.commitmentId)~=nil
        or G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id) then return false end
    local next=C.proposeLeisure("person","listener",old.id)
    return next and next.processId~=row.processId and old.status~="completed"
end)
check("current_item_and_revision_required_at_native_admission",function()
    local old,row=setup();local p,c=accept(row);p.participation.revision=p.participation.revision+1
    if G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id) then return false end
    old,row=setup();p,c=accept(row);__body:getInventory():Remove(__harmonica)
    return G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id)==false
end)
check("transport_exception_retires_transient_delivery_authority",function()
    local old,row=setup();assert(C.formResponse("listener",row.processId,__other,"IDLE"))
    local original=O.deliverResponse;O.deliverResponse=function() error("controlled receiver failure") end
    local count=M.deliverPendingResponses("listener","person","spoken");O.deliverResponse=original
    return count==0 and not M.participationTransport(row.processId,"listener","person","response")
        and O.deliverResponse(row.processId,"listener","person","spoken",{})==false
end)
check("actual_unfinished_study_intention_enters_private_comparison",function()
    local old,row=setup()
    local purpose=P.planStudy("listener","cook",{perk="Cooking",bookSkill="Cooking",bookOwned=true,literacy="fluent"})
    if not purpose or purpose.domain~="learning" then return false end
    local response=C.formResponse("listener",row.processId,__other,"IDLE")
    return response and response.response=="defer"
end)
