-- Conflict choice is a controlled available-offer selection here; these cases
-- exercise actual Response, Gesture, Exchange and installed native queue custody.
local originalFresh=fresh
local clock,view,wanted,orders,results,refusals=46,nil,'withdraw',0,{},0
local nativeBridge=__realBridge
local originalBetween=SAO.Exchange.betweenPair
SAOJavaBridge={isShell=function(_,body)return nativeBridge:isShell(body)end,
    getShellHealth=function(_,body)return nativeBridge:getShellHealth(body)end,
    localCombatMoves=function(_,body)return 'MOVE\t'..tostring(math.floor(body:getX())+2)..'\t'..tostring(math.floor(body:getY()))..'\t0' end,
    combatOpportunity=function()return 'REFUSED\tno-owned-native-target' end}
SAO.Controller.tick=function()return clock end
SAO.Controller.appraiseCoordination=nil
SAO.Cognition={appraiseConflict=function()end}
SAO.Coordination=nil;SAO.Organization=nil;SAO.Study=nil;SAO.PathogenPressure=nil
SAO.Perception={believedZombieContacts=function()return {} end}
SAO.Disposition.conflictValues=function()return {selfPreservation=.8}end
SAO.Disposition.fear=function()return 0 end
SAO.Disposition.fleeDistance=function()return 8 end
SAO.Disposition.overwhelmThreshold=function()return 4 end
SAO.Disposition.decisionInterval=function()return 20 end
SAO.Disposition.paceUnderThreat=function()return 'run' end
SAO.Standing.mayEngageZombie=function()return true end
SAO.ProceduralPlanning={
    spatialKnowledge=function()return {}end,conflictRouteBlocked=function()return false end,
    planConflict=function(id,frame,offers)
        for _,offer in ipairs(offers)do if offer.kind==wanted and offer.available then
            view={actorId=id,purposeId='current-conflict',frameId='frame-current',selected=offer.id,kind=offer.kind,reason=offer.reason}
            return view
        end end
    end,
    conflictSnapshot=function()return view end,
    conflictRefusal=function()refusals=refusals+1;return true end,
    conflictAdmission=function(id,purpose,token,offer)
        return view and purpose==view.purposeId and offer==view.selected
    end,
    conflictResult=function()return true end,
    recordResult=function(id,purpose,result)results[#results+1]=result;return true end}
SAO.Needs.busy=function(body)return nativeBridge:hasPendingActions(body)end
SAO.Locomotion.order=function(id,body,x,y,z)
    orders=orders+1
    SAO.Locomotion.jobs[id]={body=body,goal={x=x,y=y,z=z},done=false}
    return true
end
local hooks={mayEnter=function()return true end,advance=function()end,coordinate=function()return false end,
    setState=function(agent,id,state)agent.state=state;return true end}
local function reset()
    local rec=originalFresh()
    view=nil;wanted='withdraw';orders=0;results={};refusals=0;clock=46
    SAO.Locomotion.jobs={}
    return rec,SAO.Controller.agents.cook
end
local function response(agent,threat)
    return SAO.ConflictResponse.decide('cook',agent,__cook,clock,threat,1,nil,nil,hooks)
end
local function threat()
    return {x=__cook:getX()-1,y=__cook:getY(),dist=1,source='observed',track='fixture-private-contact',at=clock}
end
local function gesture(receipt)
    assert(SAO.Gesture.play('cook',__cook,'Converse_Listening02',60,receipt))
    local action=ISTimedActionQueue.queues[__cook].queue[1]
    action.action:start()
    return action
end
local function stop(action)
    __gestureNativeStop(__cook,action.action,true)
end
local function release(action)
    __gestureNativeStop(__cook,action.action,false)
end

check("optional_gesture_yields_only_after_native_release",function()
    local rec,agent=reset();local action=gesture()
    response(agent,threat())
    if orders~=0 or refusals~=0 or not __gestureStopRequested(action.action) then return false end
    stop(action)
    response(agent,threat())
    if orders~=0 or refusals~=0 or ISTimedActionQueue.hasAction(action)
        or not __cook:getCharacterActions():contains(action.action) then return false end
    release(action);response(agent,threat())
    return orders==1 and agent.state=='FLEE' and agent.conflictRoute~=nil
end)
check("conversation_cannot_requeue_during_pending_or_maintained_response",function()
    local rec,agent=reset();local action=gesture()
    response(agent,threat());stop(action);release(action)
    -- The other participant initiates the actual Exchange path in the gap.
    originalBetween('speaker',SAO.Controller.agents.speaker,__speaker,'cook',__cook,46)
    if SAO.Needs.busy(__cook) then return false end
    response(agent,threat());clock=100
    return agent.conflictRoute~=nil and not SAO.Gesture.play('cook',__cook,'Converse_ArmForward',60)
end)
check("interrupted_leisure_never_completes_or_rewards",function()
    local rec,agent=reset();local action=gesture({actorId='cook',purposeId='leisure-1',owner='SAO.Gesture',token='receipt-1'})
    response(agent,threat());stop(action);release(action);action:perform();action:stop()
    return #results==1 and results[1].status=='interrupted' and results[1].reason=='gesture-yielded-to-conflict'
end)
check("later_unrelated_action_survives_exact_gesture_stop",function()
    local rec,agent=reset();local action=gesture();response(agent,threat())
    local other=ISBaseTimedAction:new(__cook);other.maxTime=600;other.isValid=function()return true end
    other.Type='ISOpenWindow';ISTimedActionQueue.add(other)
    stop(action);release(action);response(agent,threat())
    return orders==0 and ISTimedActionQueue.hasAction(other) and ISTimedActionQueue.queues[__cook].current==other
        and __cook:getCharacterActions():contains(other.action) and #ISTimedActionQueue.queues[__cook].queue==1
end)
check("direct_unregistered_action_and_cpr_are_not_optional",function()
    local rec,agent=reset();local other=SAOGestureAction:new(__cook,'StartCpr',600)
    ISTimedActionQueue.add(other);response(agent,threat())
    if orders~=0 or __gestureStopRequested(other.action) then return false end
    rec,agent=reset();SAO.Gesture.cpr('cook',__cook);response(agent,threat())
    return orders==0 and #ISTimedActionQueue.queues[__cook].queue==3
        and not __gestureStopRequested(ISTimedActionQueue.queues[__cook].queue[1].action)
end)
check("stale_body_token_refuses_gesture_handoff",function()
    local rec,agent=reset();local action=gesture();rec.bodyOwnerToken='new-generation'
    response(agent,threat())
    local result=not __gestureStopRequested(action.action) and orders==0
    rec.bodyOwnerToken=nil;return result
end)
check("foreign_or_stale_decision_cannot_yield",function()
    local rec,agent=reset();local action=gesture()
    -- Create the current decision but hold a native crossing before handoff.
    SAO.Locomotion.jobs.cook={body=__cook,done=false,lastVerdict='Transition:STARTED_WINDOW_CLIMB',goal={x=12,y=20,z=0}}
    response(agent,threat())
    local current=view;view={purposeId='replacement',selected=current.selected,frameId=current.frameId}
    return not SAO.Gesture.yieldToConflict('cook',__cook,current) and not __gestureStopRequested(action.action)
end)
check("accepted_native_crossing_keeps_gesture_and_route_custody",function()
    local rec,agent=reset();local action=gesture()
    local job={body=__cook,done=false,lastVerdict='Transition:STARTED_WINDOW_CLIMB',goal={x=12,y=20,z=0}}
    SAO.Locomotion.jobs.cook=job;response(agent,threat())
    return not __gestureStopRequested(action.action) and SAO.Locomotion.jobs.cook==job and orders==0
end)
check("watch_hold_expires_and_no_threat_releases",function()
    local rec,agent=reset();wanted='watch';response(agent,threat())
    if SAO.Gesture.play('cook',__cook,'Converse_ArmForward',60) then return false end
    clock=67
    if not SAO.Gesture.play('cook',__cook,'Converse_ArmForward',60) then return false end
    rec,agent=reset();wanted='watch';response(agent,threat());response(agent,nil)
    return SAO.Gesture.play('cook',__cook,'Converse_ArmForward',60)
end)
check("detach_releases_watch_and_unrelated_actor_remains_free",function()
    local rec,agent=reset();wanted='watch';response(agent,threat())
    if not SAO.Gesture.play('speaker',__speaker,'Converse_ArmForward',60) then return false end
    if not SAO.ConflictResponse.detach('cook',agent,__cook,'fixture detach') then return false end
    return SAO.Gesture.play('cook',__cook,'Converse_ArmForward',60)
end)
check("completion_race_after_yield_remains_interrupted",function()
    local rec,agent=reset();local action=gesture({actorId='cook',purposeId='leisure-race',owner='SAO.Gesture',token='race'})
    response(agent,threat());action:perform();release(action)
    return #results==1 and results[1].status=='interrupted' and not ISTimedActionQueue.hasAction(action)
end)
check("late_retired_callback_preserves_new_action",function()
    local rec,agent=reset();local action=gesture();response(agent,threat());stop(action);release(action)
    response(agent,nil)
    local other=gesture();action:stop();action:perform()
    return ISTimedActionQueue.hasAction(other) and __cook:getCharacterActions():contains(other.action)
end)
check("changed_generation_cannot_retire_old_gesture",function()
    local rec,agent=reset();local action=gesture({actorId='cook',purposeId='prior-generation',owner='SAO.Gesture',token='prior'})
    response(agent,threat())
    rec.bodyOwnerToken='successor';__cook:getModData().SAOExternalToken='successor'
    stop(action)
    local retained=#results==0 and ISTimedActionQueue.hasAction(action)
    release(action);rec.bodyOwnerToken=nil;__cook:getModData().SAOExternalToken=nil
    return retained
end)
check("new_generation_does_not_inherit_watch_suppression",function()
    local rec,agent=reset();wanted='watch';response(agent,threat())
    rec.bodyOwnerToken='successor';__cook:getModData().SAOExternalToken='successor'
    local released=not SAO.ConflictResponse.gesturePriority('cook',__cook)
    rec.bodyOwnerToken=nil;__cook:getModData().SAOExternalToken=nil
    return released
end)
check("native_open_smash_climb_without_job_remain_owned",function()
    for _,state in ipairs({'open','smash','climb'})do
        local rec,agent=reset();local action=gesture()
        __gestureFixtureState(__cook,state)
        response(agent,threat())
        local retained=not __gestureStopRequested(action.action) and orders==0
        __gestureFixtureState(__cook,'idle')
        if not retained then return false end
    end
    return true
end)
check("settled_old_handoff_does_not_hide_a_new_optional_action",function()
    local rec,agent=reset();local first=gesture()
    response(agent,threat());stop(first);release(first)
    response(agent,nil)
    local nextAction=gesture()
    response(agent,threat())
    return __gestureStopRequested(nextAction.action) and refusals==0 and orders==0
end)
check("replaced_native_owner_keeps_its_stack_and_queued_successor",function()
    local rec,agent=reset();local action=gesture({actorId='cook',purposeId='displaced',owner='SAO.Gesture',token='old'})
    response(agent,threat())
    local nativeOther=ISBaseTimedAction:new(__cook);nativeOther.maxTime=600;nativeOther.isValid=function()return true end
    nativeOther:begin()
    local queuedOther=ISBaseTimedAction:new(__cook);queuedOther.maxTime=600;queuedOther.isValid=function()return true end
    ISTimedActionQueue.add(queuedOther)
    action:stop();action:perform();response(agent,threat())
    return orders==0 and #results==0 and __cook:getCharacterActions():contains(nativeOther.action)
        and ISTimedActionQueue.hasAction(action) and ISTimedActionQueue.hasAction(queuedOther)
        and queuedOther.action==nil
end)
check("detach_releases_pending_handback_without_touching_native_action",function()
    local rec,agent=reset();local action=gesture();response(agent,threat())
    if SAO.Gesture.releaseConflict('cook',__speaker) then return false end
    if not SAO.ConflictResponse.detach('cook',agent,__cook,'fixture detach') then return false end
    return not SAO.Gesture.releaseConflict('cook',__cook) and ISTimedActionQueue.hasAction(action)
        and __cook:getCharacterActions():contains(action.action)
end)
check("dead_or_transferred_owner_retires_without_further_decision",function()
    for _,kind in ipairs({'dead','transferred'}) do
        local rec,agent=reset();local action=gesture();response(agent,threat());stop(action)
        if kind=='dead' then rec.dead=true else rec.bodyOwner='ZAO' end
        for _,fn in ipairs(__fixtureTicks) do if fn~=ISTimedActionQueue.onTick then fn() end end
        if SAO.Gesture.releaseConflict('cook',__cook) or #results~=0
            or not __cook:getCharacterActions():contains(action.action) then return false end
    end
    return true
end)
check("settled_handback_retires_without_further_decision",function()
    local rec,agent=reset();local action=gesture();response(agent,threat());stop(action)
    for _,fn in ipairs(__fixtureTicks) do if fn~=ISTimedActionQueue.onTick then fn() end end
    -- The still-native handback must remain pending after its Lua removal.
    if SAO.Gesture.yieldToConflict('cook',__cook,view) then return false end
    release(action)
    for _,fn in ipairs(__fixtureTicks) do if fn~=ISTimedActionQueue.onTick then fn() end end
    return not SAO.Gesture.releaseConflict('cook',__cook) and orders==0 and refusals==0
end)
check("terminal_optional_actions_leave_live_registry",function()
    for _,kind in ipairs({'perform','stop'}) do
        local rec,agent=reset();local action=gesture()
        if not __gestureFixtureRegistry[action] then return false end
        action[kind](action)
        if __gestureFixtureRegistry[action] then return false end
    end
    return true
end)
check("lost_owner_optional_actions_retire_without_callbacks",function()
    for _,kind in ipairs({'dead','transferred','removed'}) do
        local rec,agent=reset();local action=gesture()
        if kind=='dead' then rec.dead=true
        elseif kind=='transferred' then rec.bodyOwner='ZAO'
        else
            ISTimedActionQueue.queues[__cook].queue={}
            __cook:getCharacterActions():clear()
        end
        for _,fn in ipairs(__fixtureTicks) do if fn~=ISTimedActionQueue.onTick then fn() end end
        if __gestureFixtureRegistry[action] then return false end
        action:stop();action:perform()
        if #results~=0 then return false end
    end
    return true
end)
