local P,G,O,C,M,Ctl = SAO.ProceduralPlanning,SAO.Gesture,SAO.Organization,SAO.Coordination,SAO.Communication,SAO.Controller
local function finish(action)
    action:update();__emitter:finish();action:update();action:perform();__finishNativeAction(action.action)
end
local function solo()
    __clock(12);fresh();__pulseReset();__deaf(false);__talk=0.8;__threat=nil;__relations={}
    __records.listener={id="listener"};SAO.Body.active.listener=__other
    Ctl.agents.listener={rec=__records.listener,state="IDLE"}
    Ctl.agents.person.state="IDLE"
    __other:getModData().SAOPersonId="listener";__other:getModData().SAOExternalToken=nil;__other:setAsleep(false)
    __body:getStats():set(CharacterStat.HUNGER,0);__body:getStats():set(CharacterStat.THIRST,0);__body:getStats():set(CharacterStat.FATIGUE,0)
    __other:getStats():set(CharacterStat.HUNGER,0);__other:getStats():set(CharacterStat.THIRST,0);__other:getStats():set(CharacterStat.FATIGUE,0)
    __moveListener(12.5,20.5,-1,0);__body:setForwardDirection(1,0)
    O.processes={};O.processOrder={};O.processMeta={sequence=0};O.workReceipts={}
    SAO.Perception.beliefs={}
    local p=P.planLeisure("person",{activity="music",itemKey=tostring(__harmonica:getID()),affordance="Base.Harmonica",
        nativeVerb="blow-harmonica",owner="SAO.Gesture",locationKey="current",atLocation=true})
    assert(G.playInstrument("person",__body,"harmonica","Base.Harmonica",__harmonica,p.id))
    finish(ISTimedActionQueue.queues[__body].queue[1])
    assert(P.participationSource("person",p.id),"authentic solo source")
    return p,Ctl.agents.person,Ctl.agents.listener
end
local function know(id,other)
    SAO.Perception.beliefs[id]={people={named={id=other,source="observed",at=Ctl.tick(),atHours=SAO.History.countyHours(),x=12.5,y=20.5}}}
end
local function propose()
    local old,a,b=solo();know("person","listener")
    assert(Ctl.proposeLeisureParticipation("person",a,__body,1000),"Controller invitation")
    local source=P.participationSource("person",old.id)
    local pc=O.activeCommitment("person","leisure-participation")
    return old,a,b,source.processId,pc
end
local function assent(processId)
    local answer=C.formResponse("listener",processId,__other,"IDLE")
    assert(answer and answer.response=="accept","private recipient assent")
    assert(M.deliverPendingResponses("listener","person","spoken")==1,"actual returned assent")
    return O.activeCommitment("listener","leisure-participation")
end
local function dispatch(id,agent,body,commitment)
    agent.rec.ordinaryPurposeDecision={kind="commitment",status="selected"}
    return Ctl.dispatchOrdinaryPurpose(id,agent,body,SAO.History.ticks(),SAO.Needs.read(body),"commitment",{payload=commitment})
end

check("ordinary_commitment_dispatch_queues_fresh_exact_native_work",function()
    local old,a,b,process,pc=propose();assent(process);local before=__noiseCount()
    if not dispatch("person",a,__body,pc) then return false end
    local work=G.instrumentWork("person");local action=ISTimedActionQueue.queues[__body].queue[1]
    return work and action and ISTimedActionQueue.hasAction(action) and work.sequence==2
        and work.itemId==tostring(__harmonica:getID()) and __noiseCount()==before+1
        and a.rec.ordinaryPurposeDecision.status=="admitted" and old.status~="completed"
end)
check("listener_wait_yields_ordinary_dispatch_without_hearing",function()
    local old,a,b,process,pc=propose();local lc=assent(process)
    local advanced=dispatch("listener",b,__other,lc)
    return advanced==false and b.pressure and b.pressure.phase=="intended"
        and b.rec.ordinaryPurposeDecision.status=="unavailable" and __records.listener.instrumentHearings==nil
        and old.status~="completed" and SAO.Needs.workAvailable(__other)
end)
check("unreturned_assent_does_not_start_controller_performance",function()
    local old,a,b,process,pc=propose();assert(C.formResponse("listener",process,__other,"IDLE"))
    local count=__noiseCount()
    return dispatch("person",a,__body,pc)==false and __noiseCount()==count
        and G.instrumentWork("person")==nil and old.status~="completed"
end)
check("active_performance_is_retained_without_second_queue",function()
    local old,a,b,process,pc=propose();assent(process);assert(dispatch("person",a,__body,pc))
    local work=G.instrumentWork("person");local count=__noiseCount()
    local advanced,why=Ctl.advanceLeisureParticipation("person",a,__body,pc.id)
    return advanced and why=="participation-performance-started" and G.instrumentWork("person").workId==work.workId
        and __noiseCount()==count and a.pressure.phase=="executing"
end)
check("actual_scanner_hearing_and_return_complete_exact_shared_occurrence",function()
    local old,a,b,process,pc=propose();local lc=assent(process);assert(dispatch("person",a,__body,pc))
    local action=ISTimedActionQueue.queues[__body].queue[1];local work=G.instrumentWork("person")
    if dispatch("listener",b,__other,lc) or __records.listener.instrumentHearings then return false end
    __scan(__other)
    if not dispatch("listener",b,__other,lc) or b.pressure.phase~="observed" or old.status=="completed" then return false end
    finish(action)
    local outcome=O.participationOutcome("person",process)
    return outcome and outcome.workId==work.workId and old.status=="completed"
        and #__records.listener.instrumentHearings==1 and P.snapshot("person").practiceDomains==0
end)
check("nearby_unobserved_person_is_not_an_invitation_candidate",function()
    local old,a=solo()
    return Ctl.proposeLeisureParticipation("person",a,__body,1000)==false and #O.processOrder==0
end)
check("another_person_contact_does_not_supply_invitation_source",function()
    local old,a=solo();know("foreign","listener")
    return Ctl.proposeLeisureParticipation("person",a,__body,1000)==false and #O.processOrder==0
end)
check("privately_hostile_contact_is_not_invited",function()
    local old,a=solo();know("person","listener");__relations.person={listener={hostile=true,trust=-1}}
    return Ctl.proposeLeisureParticipation("person",a,__body,1000)==false and #O.processOrder==0
end)
check("known_contact_still_requires_current_transport",function()
    local old,a=solo();know("person","listener");__moveListener(26.5,20.5,-1,0)
    if Ctl.proposeLeisureParticipation("person",a,__body,1000) or #O.processOrder~=0 then return false end
    __moveListener(12.5,20.5,-1,0)
    return Ctl.proposeLeisureParticipation("person",a,__body,1001)==true and #O.processOrder==1
end)
check("refusal_yields_and_retry_suppresses_only_until_existing_deadline",function()
    local old,a=solo();know("person","listener");__body:getStats():set(CharacterStat.HUNGER,0.9)
    if Ctl.proposeLeisureParticipation("person",a,__body,1000) or #O.processOrder~=0 or a.nextParticipationAt~=1300 then return false end
    __body:getStats():set(CharacterStat.HUNGER,0)
    if Ctl.proposeLeisureParticipation("person",a,__body,1299) or #O.processOrder~=0 then return false end
    return Ctl.proposeLeisureParticipation("person",a,__body,1300)==true and #O.processOrder==1
end)
check("lost_exact_material_refuses_and_keeps_sharing_unfinished",function()
    local old,a,b,process,pc=propose();assent(process);local count=__noiseCount()
    __body:getInventory():Remove(__harmonica);__other:getInventory():AddItem(__harmonica)
    return dispatch("person",a,__body,pc)==false and __noiseCount()==count
        and G.instrumentWork("person")==nil and old.status~="completed"
end)
check("current_bodily_need_or_private_threat_preserves_ordinary_turn",function()
    local old,a,b,process,pc=propose();assent(process);local count=__noiseCount()
    __body:getStats():set(CharacterStat.FATIGUE,0.9)
    if dispatch("person",a,__body,pc) then return false end
    __body:getStats():set(CharacterStat.FATIGUE,0);__threat={dist=1}
    return dispatch("person",a,__body,pc)==false and __noiseCount()==count and old.status~="completed"
end)
check("foreign_body_cannot_execute_returned_assent",function()
    local old,a,b,process,pc=propose();assent(process);local count=__noiseCount()
    return Ctl.advanceLeisureParticipation("person",a,__other,pc.id)==false
        and __noiseCount()==count and G.instrumentWork("person")==nil
end)
check("native_refusal_does_not_become_generic_completion",function()
    local old,a,b,process,pc=propose();assent(process);__body:setCanShout(false);local count=__noiseCount()
    return dispatch("person",a,__body,pc)==false and old.status~="completed" and __noiseCount()==count
        and O.participationOutcome("person",process)==nil
end)
check("native_interruption_retains_unfinished_source",function()
    local old,a,b,process,pc=propose();assent(process);assert(dispatch("person",a,__body,pc))
    local action=ISTimedActionQueue.queues[__body].queue[1];local work=G.instrumentWork("person")
    action:stop();__finishNativeAction(action.action)
    return G.instrumentOutcome("person",work.workId).status=="interrupted" and old.status~="completed"
        and O.participationOutcome("person",process)==nil
end)
print("PARTICIPATION_CONTROLLER_DONE")
