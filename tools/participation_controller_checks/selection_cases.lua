-- Actual ordinary candidate collection and dispatch. The shared comparison
-- receiver chooses the first offered candidate; it never supplies a missing
-- commitment. Native/social admission and hearing remain the production owners.
SAO.Disposition.drinkAt=function()return 0.4 end
SAO.Disposition.eatAt=function()return 0.4 end
SAO.Standing.mayEnterBelieved=function()return false end
SAO.Standing.insideClaim=function()return false end
SAO.Study.offer=function()return nil end
SAO.WorldSources={}
SAO.SourceUse={}
local function accepted()
    local old,a,b,process,pc=propose();local lc=assent(process)
    SAO.Perception.beliefs.person.zombies={}
    SAO.Perception.beliefs.listener=SAO.Perception.beliefs.listener or {people={}}
    SAO.Perception.beliefs.listener.zombies={}
    return old,a,b,process,pc,lc
end
local function choose(id,agent,body)
    return Ctl.chooseOrdinaryPurpose(id,agent,body,SAO.History.ticks(),SAO.Needs.read(body))
end
local function candidate(agent,commitment)
    for _,row in ipairs(agent.rec.ordinaryPurposeDecision and agent.rec.ordinaryPurposeDecision.alternatives or {}) do
        if row.id=="commitment:"..commitment.id then return row end
    end
end
local function ready(id,body,commitment)
    local plan=assert(O.workPlan(commitment.id,id))
    local step=plan.privateProcedure.beliefs[plan.intendedStepId]
    return Ctl.coordinationStudyReady(id,body,commitment,plan,step)
end
local function selectedPerformance()
    local old,a,b,process,pc,lc=accepted()
    local kind,offered=choose("person",a,__body)
    assert(kind=="commitment" and offered.payload.id==pc.id,"actual ordinary performer choice")
    assert(Ctl.dispatchOrdinaryPurpose("person",a,__body,SAO.History.ticks(),SAO.Needs.read(__body),kind,offered))
    return old,a,b,process,pc,lc,ISTimedActionQueue.queues[__body].queue[1]
end

check("actual_chooser_selects_music_without_food_and_dispatches_exact_native_work",function()
    local old,a,b,process,pc=accepted()
    if not ready("person",__body,pc) then return false end
    local kind,offered=choose("person",a,__body)
    local row=candidate(a,pc);local noise=__noiseCount()
    if kind~="commitment" or not row or offered.payload.id~=pc.id then return false end
    if not Ctl.dispatchOrdinaryPurpose("person",a,__body,SAO.History.ticks(),SAO.Needs.read(__body),kind,offered) then return false end
    local work=G.instrumentWork("person")
    return work and work.itemId==tostring(__harmonica:getID()) and work.sequence==2
        and __noiseCount()==noise+1 and a.coordinationCommitment==pc.id
        and a.rec.ordinaryPurposeDecision.status=="admitted" and old.status~="completed"
end)
check("music_candidate_does_not_predict_material_delivery",function()
    local old,a,b,process,pc=accepted();choose("person",a,__body)
    local row=candidate(a,pc)
    return row and #row.consequences==1 and row.consequences[1].sourceId==pc.id
        and row.consequences[1].kind=="commitment" and row.consequences[1].condition==nil
end)
check("pending_listener_yields_actual_ordinary_choice_without_acquiring_hearing",function()
    local old,a,b,process,pc,lc,action=selectedPerformance()
    if ready("listener",__other,lc) then return false end
    local kind=choose("listener",b,__other)
    if kind~="continue" or candidate(b,lc) or __records.listener.instrumentHearings then return false end
    __scan(__other)
    -- The native scanner has evidence, but this readiness query must not acquire it.
    return ready("listener",__other,lc)==false and choose("listener",b,__other)=="continue"
        and __records.listener.instrumentHearings==nil and b.coordinationCommitment==nil
end)
check("pending_listener_does_not_preempt_existing_unrelated_study",function()
    local old,a,b,process,pc,lc=selectedPerformance()
    local active,interrupt=SAO.Study.active,SAO.Study.interrupt
    local interrupted=0
    SAO.Study.active=function(id)return id=="listener" end
    SAO.Study.interrupt=function()interrupted=interrupted+1;return true end
    -- An independently owned study action is the controlled physical receiver.
    -- The pending listener must fail readiness before touching its queue/cancel API.
    b.rec.studyWork={id="unrelated-study"}
    ISTimedActionQueue.queues[__other]={queue={{workId="unrelated-study",personId="listener"}}}
    local result=Ctl.preemptStudyForCoordination("listener",b,__other,lc)
    SAO.Study.active=active;SAO.Study.interrupt=interrupt
    ISTimedActionQueue.queues[__other]=nil
    return result==false and interrupted==0 and b.studyCancellationPending==nil
        and __records.listener.instrumentHearings==nil
end)
check("privately_acquired_hearing_enters_actual_listener_choice_and_ack",function()
    local old,a,b,process,pc,lc,action=selectedPerformance();local work=G.instrumentWork("person")
    __scan(__other)
    assert(SAO.Perception.acquireInstrumentHearing("listener",__other,"person",work.workId))
    if not ready("listener",__other,lc) then return false end
    local kind,offered=choose("listener",b,__other)
    if kind~="commitment" or offered.payload.id~=lc.id or not candidate(b,lc) then return false end
    if not Ctl.dispatchOrdinaryPurpose("listener",b,__other,SAO.History.ticks(),SAO.Needs.read(__other),kind,offered) then return false end
    if b.coordinationCommitment~=nil or b.pressure.phase~="observed" then return false end
    finish(action)
    return O.participationOutcome("person",process)~=nil and old.status=="completed"
end)
check("completed_performance_flag_clears_before_ordinary_recovery_comparison",function()
    local old,a,b,process,pc,lc,action=selectedPerformance()
    __scan(__other);assert(dispatch("listener",b,__other,lc));finish(action)
    assert(O.participationOutcome("person",process) and #O.activeCommitments("person")==0)
    assert(a.coordinationCommitment==pc.id and G.instrumentWork("person")==nil)
    local kind=choose("person",a,__body)
    local needs={hunger=0,thirst=0,fatigue=0.8,endurance=1}
    local actual=SAO.Needs.recoveryAlternatives("person",needs,{committed=a.coordinationCommitment~=nil})
    local clear=SAO.Needs.recoveryAlternatives("person",needs,{committed=false})
    return kind=="continue" and a.coordinationCommitment==nil and actual[1].utility==clear[1].utility
end)
check("interrupted_performance_flag_clears_without_completing_sharing",function()
    local old,a,b,process,pc,lc,action=selectedPerformance();local work=G.instrumentWork("person")
    action:stop();__finishNativeAction(action.action)
    local advanced=Ctl.advanceLeisureParticipation("person",a,__body,pc.id)
    return advanced==false and a.coordinationCommitment==nil and G.instrumentWork("person")==nil
        and G.instrumentOutcome("person",work.workId).status=="interrupted"
        and old.status~="completed" and O.participationOutcome("person",process)==nil
end)
check("live_exact_performer_commitment_flag_is_retained",function()
    local old,a,b,process,pc=selectedPerformance();local work=G.instrumentWork("person")
    Ctl.reconcileLeisureCommitment("person",a)
    return a.coordinationCommitment==pc.id and G.instrumentWork("person").workId==work.workId
end)
check("foreign_actor_commitment_flag_is_not_cleared",function()
    local old,a,b,process,pc=selectedPerformance()
    b.coordinationCommitment=pc.id
    Ctl.reconcileLeisureCommitment("listener",b)
    return b.coordinationCommitment==pc.id and a.coordinationCommitment==pc.id
        and G.instrumentWork("person")~=nil
end)
check("foreign_agent_call_preserves_actual_performer_flag",function()
    local old,a,b,process,pc=selectedPerformance()
    return choose("listener",a,__other)==nil and a.coordinationCommitment==pc.id
        and G.instrumentWork("person")~=nil
end)
check("lost_exact_material_is_omitted_from_actual_ordinary_choice",function()
    local old,a,b,process,pc=accepted();local count=__noiseCount()
    __body:getInventory():Remove(__harmonica);__other:getInventory():AddItem(__harmonica)
    return ready("person",__body,pc)==false and choose("person",a,__body)=="continue"
        and candidate(a,pc)==nil and __noiseCount()==count and old.status~="completed"
end)
check("current_native_transport_refusal_is_omitted_from_choice",function()
    local old,a,b,process,pc=accepted();__body:setCanShout(false)
    return ready("person",__body,pc)==false and choose("person",a,__body)=="continue"
        and candidate(a,pc)==nil and G.instrumentWork("person")==nil
end)
check("unreturned_assent_is_omitted_from_actual_ordinary_choice",function()
    local old,a,b,process,pc=propose();assert(C.formResponse("listener",process,__other,"IDLE"))
    SAO.Perception.beliefs.person.zombies={}
    return choose("person",a,__body)=="continue" and candidate(a,pc)==nil and G.instrumentWork("person")==nil
end)
check("private_threat_and_current_body_still_guard_ordinary_participation",function()
    local old,a,b,process,pc=accepted()
    SAO.Perception.beliefs.person.zombies.near={source="observed",at=Ctl.tick(),atHours=SAO.History.countyHours(),x=10.5,y=20.5,z=0}
    if choose("person",a,__body)~=nil then return false end
    SAO.Perception.beliefs.person.zombies={}
    return choose("person",a,__other)==nil and G.instrumentWork("person")==nil
end)
