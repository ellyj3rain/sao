-- Loaded conflict dispatch. Private appraisal chooses; native owners admit and act.
SAO = SAO or {}
SAO.ConflictResponse = SAO.ConflictResponse or {}
local R = SAO.ConflictResponse

local function call(method, ...)
    if not SAOJavaBridge then return nil end
    local args = {...}
    local ok, value = pcall(function() return SAOJavaBridge[method](SAOJavaBridge, unpack(args)) end)
    return ok and value or nil
end
local function owns(id, agent, body)
    local rec = agent and agent.rec
    if not rec or rec.id~=id or SAO.Identity.get(id)~=rec
        or SAO.Controller.agents[id]~=agent or rec.dead or rec.bodyOwner or agent.passive or not body
        or SAO.Body.get(id) ~= body or SAO.Body.active[id] ~= body
        or SAO.Body.foreign[id] then return false end
    local ok, data = pcall(function() return body:getModData() end)
    return ok and data and data.SAOPersonId == id and data.SAOExternalOwner == nil
        and data.SAOExternalToken == rec.bodyOwnerToken and data.ZAOOwned ~= true
        and call("isShell", body) == true
end
local function routeKey(body, x, y, z)
    return table.concat({math.floor(body:getX()),math.floor(body:getY()),math.floor(body:getZ()),
        math.floor(x),math.floor(y),math.floor(z)}, ":")
end
local function nextToken(agent, owner)
    agent.rec.conflictExecutionSequence = (tonumber(agent.rec.conflictExecutionSequence) or 0) + 1
    return {owner=owner,id=tostring(agent.rec.id)..":"..tostring(agent.rec.conflictExecutionSequence)}
end
local function outcome(id, work, status, reason)
    local planning=SAO.ProceduralPlanning
    if planning.conflictResult(id,work.purposeId,work.token,
        {status=status,reason=tostring(reason):sub(1,256),routeKey=work.routeKey}) then return true end
    -- A late callback proves that custody ended, but lies outside the admitted
    -- observation interval. Retire its exact token without crediting an outcome.
    if planning.conflictResult(id,work.purposeId,work.token,
        {status="cancelled",reason="terminal callback outside the admitted observation interval; outcome uncredited",
            routeKey=work.routeKey}) then return true end
    local current=planning.conflictSnapshot(id)
    return not current or not current.admission or current.admission.owner~=work.token.owner
        or current.admission.id~=work.token.id
end
local function health(body)
    local value=tonumber(call("getShellHealth",body))
    return value and value==value and value>=0 and value<=100 and value or nil
end
local function nativeCrossing(job,body)
    if not job or job.done or job.body~=body then return false end
    local ok,held=pcall(function()
        local state=body:getCurrentStateName()
        return body:isClimbing() or state=="ClimbOverFenceState" or state=="ClimbThroughWindowState"
            or state=="SmashWindowState" or tostring(state):find("OpenWindowState",1,true)~=nil
    end)
    return ok and held or tostring(job.lastVerdict):sub(1,11)=="Transition:"
        or job.lastVerdict=="CLIMBING" or job.lastVerdict=="STARTED_FENCE_CLIMB"
        or job.lastVerdict=="STARTED_WINDOW_CLIMB"
end
local function dangerChanged(work,body,threat,count,personKey)
    local key=threat and (threat.track or threat.name)
    local currentHealth=health(body)
    return not threat or key and key~=work.targetKey or count>work.threatCount
        or currentHealth and work.health and currentHealth<work.health
        or math.abs((threat and threat.dist or 0)-work.distance)>2
        or personKey and not SAO.Standing.mayEngagePerson(work.actorId,personKey)
end
local function ordinaryWork(id,agent,body,threat)
    if agent.conflictRoute or agent.conflictCombat or agent.conflictCoordination or agent.conflictHandover
        or agent.state=="FLEE" or agent.state=="ENGAGE" then return nil end
    local job=SAO.Locomotion.jobs[id]
    if job and job.body==body and not job.done then
        local goal=job.goal
        local approach=goal and goal.z==math.floor(body:getZ())
            and (goal.x+0.5-threat.x)^2+(goal.y+0.5-threat.y)^2
                < (body:getX()-threat.x)^2+(body:getY()-threat.y)^2-0.1
        return "the current journey",approach==true
    end
    if SAO.Study and SAO.Study.active and SAO.Study.active(id,body) then return "the current reading activity" end
    local posture=SAO.Posture and SAO.Posture.jobs[id]
    if posture and posture.body==body then return "the current physical task" end
    if agent.recovery and agent.recoveryBody==body and not agent.sleeping then return "awake recovery" end
    return nil
end
function R.detach(id,agent,body,reason,force)
    if not agent then return true end
    local combat=agent.conflictCombat
    if combat and not force and combat.body==body and owns(id,agent,body)
        and call("cancelCombatObserved",body)~="COMBAT_CANCELLED" then return false end
    if agent.conflictHandover and not force and R.pendingTransfer(id,agent,body,nil,0,nil,reason) then return false end
    for _,key in ipairs({"conflictRoute","conflictCombat","conflictHandover","conflictCoordination"}) do
        if agent[key] then
            if not outcome(id,agent[key],"cancelled",reason) then return false end
            agent[key]=nil
        end
    end
    agent.conflictGestureHold=nil
    if SAO.Gesture and SAO.Gesture.releaseConflict then SAO.Gesture.releaseConflict(id,body) end
    return true
end

-- Optional animation admission consults this current response owner. No
-- durable belief or threat is created, and a stale watch cannot block leisure.
function R.gesturePriority(id,body,decision)
    local agent=SAO.Controller and SAO.Controller.agents[id]
    if not owns(id,agent,body) then return false end
    local hold=agent.conflictGestureHold
    if not hold or hold.body~=body or hold.rec~=agent.rec
        or hold.bodyToken~=agent.rec.bodyOwnerToken then return false end
    local view=SAO.ProceduralPlanning.conflictSnapshot(id)
    if not view or view.purposeId~=hold.purposeId or view.selected~=hold.selected
        or view.frameId~=hold.frameId then return false end
    if decision and (decision.purposeId~=hold.purposeId or decision.selected~=hold.selected
        or decision.frameId~=hold.frameId) then return false end
    for _,key in ipairs({"conflictRoute","conflictCombat","conflictCoordination","conflictHandover"}) do
        local work=agent[key]
        if work and work.body==body and work.purposeId==hold.purposeId then return true end
    end
    local tick=SAO.Controller.tick()
    return tick>=hold.at and tick<=hold.untilTick
end
function R.finishCoordination(id,agent,body,job,status,reason)
    local work=agent.conflictCoordination
    if not work or work.body~=body or work.nativeJob~=job then return false end
    if not outcome(id,work,status,reason) then return false end
    agent.conflictCoordination=nil
    return true
end
function R.coordinationThreatChanged(id,agent,body,threat,count,personKey)
    local work=agent.conflictCoordination
    return not work or work.body~=body or not owns(id,agent,body)
        or work.nativeJob~=(SAO.Posture and SAO.Posture.jobs[id])
        or dangerChanged(work,body,threat,count,personKey)
end

function R.finishMovement(id, agent, body, setState)
    local work, job = agent.conflictRoute, SAO.Locomotion.jobs[id]
    if not work then return false end
    if not owns(id,agent,body) or work.body ~= body or job ~= work.job then
        if not outcome(id,work,"cancelled","movement owner changed") then return true end
        agent.conflictRoute = nil
        return false
    end
    if not job.done then return false end
    local reason = tostring(job.result or "native movement ended")
    if not outcome(id,work,reason == "arrived" and "completed" or "failed",reason) then return true end
    agent.conflictRoute = nil
    agent.nextDecisionAt = 0
    setState(agent,id,"ALERT",reason == "arrived" and "Reached the chosen ground; reassessing danger."
        or "The attempted route failed; considering other ways through.")
    return true
end

local function alternatives(id, agent, body, tick, threat, count, person, personKey, hooks)
    local now = SAO.History.countyHours()
    local kind = person and "person" or (threat.fromPerson and "person" or "zombie")
    local key = person or threat.name or threat.track
    local permitted = kind == "person" and personKey and SAO.Standing.mayEngagePerson(id,personKey)
        or kind == "zombie" and SAO.Standing.mayEngageZombie(id)
    local native = key and call("combatOpportunity",body,kind,key) or "REFUSED\tno-observed-target"
    local mode = type(native) == "string" and native:match("^AVAILABLE\t([^\t]+)") or nil
    local values = SAO.Disposition.conflictValues(id)
    local recognition=SAO.Knowledge and SAO.Knowledge.contactRecognition
        and SAO.Knowledge.contactRecognition(id)
    local unresolvedCause=kind=="zombie" and (agent.rec.personalAwareness~=nil or recognition and recognition.configured==true)
        and (not recognition or recognition.possible~=true)
    local frame = {actorId=id,atHours=now,threat={kind=kind,key=key or "unresolved-contact",
        distance=threat.dist,count=count,source=threat.source or "unknown",at=threat.at or tick,
        z=threat.z,observerZ=math.floor(body:getZ()),
        form=threat.form,formPerformance=threat.formPerformance,attributeMutations=threat.attributeMutations},
        values=values,fear=SAO.Disposition.fear(id),
        overwhelmed=count >= SAO.Disposition.overwhelmThreshold(id),escapeBlocked=false}
    local geometry=SAO.CognitiveModels and SAO.CognitiveModels.contactGeometry
        and SAO.CognitiveModels.contactGeometry(frame.threat)
    if geometry then
        frame.threat.floorKnown=geometry.floorKnown
        frame.threat.sameFloor=geometry.sameFloor
        frame.threat.reachability=geometry.reachability
    end
    local offers, actions, seen = {}, {}, {}
    local function add(offer, action)
        if seen[offer.id] or #offers >= (offer.kind=="watch" and 16 or 15) then return end
        seen[offer.id]=true;offers[#offers+1]=offer;actions[offer.id]=action or {}
    end
    local bx,by,bz=body:getX(),body:getY(),math.floor(body:getZ())
    local contacts=SAO.Perception.believedZombieContacts
        and SAO.Perception.believedZombieContacts(id,tick,bx,by,bz) or {}
    local dx,dy=bx-threat.x,by-threat.y
    local distance=math.sqrt(dx*dx+dy*dy)
    local job=SAO.Locomotion.jobs[id]
    local function move(x,y,z,known,continuing)
        x,y,z=math.floor(x),math.floor(y),math.floor(z)
        if z~=bz then return end
        -- A farther endpoint can still require walking toward the believed
        -- attacker. Neither distance alone nor arrival intent proves a route.
        if (x+0.5-bx)*dx+(y+0.5-by)*dy < -0.1 then return end
        local separation=math.sqrt((x+0.5-threat.x)^2+(y+0.5-threat.y)^2)
        local away=separation>distance+0.15
        local lateral=math.abs(separation-distance)<=0.75
        if not away and not lateral then return end
        local rk=continuing and agent.conflictRoute.routeKey or routeKey(body,x,y,z)
        local blocked=SAO.ProceduralPlanning.conflictRouteBlocked(id,rk,now)
        if blocked then frame.escapeBlocked=true end
        local allowed=hooks.mayEnter(id,x,y)
        -- Getting farther from the nearest contact may carry me toward a
        -- different remembered threat. Keep that possible harm in this
        -- person's appraisal; neither a direction nor a belief proves safety.
        -- Multiple sightings add one objection, not a manufactured crowd.
        local approachesBelievedThreat=false
        for _,contact in ipairs(contacts) do
            if (x+0.5-bx)*(bx-contact.x)+(y+0.5-by)*(by-contact.y) < -0.1 then
                approachesBelievedThreat=true
                break
            end
        end
        local effect=away and "break-contact" or "create-space"
        local object={id="route:"..rk,kind=away and "withdraw" or "reposition",routeKey=rk,
            available=not blocked and allowed,continuing=continuing==true,
            reason=known and "Move through personally remembered ground." or "Try the visible ground beside me.",
            effects={effect},objections=blocked and {"blocks-movement"}
                or approachesBelievedThreat and {"exposure","bodily-harm","approaches-another-believed-threat"}
                or {"exposure"}}
        add(object,{x=x,y=y,z=z,routeKey=rk,job=continuing and job or nil})
    end
    if agent.conflictRoute and job==agent.conflictRoute.job and job.body==body and not job.done then
        local goal=job.goal
        move(goal.x,goal.y,goal.z,true,true)
    end
    -- Remembered geometry belongs to this actor; another actor's destination is private.
    local facts=SAO.ProceduralPlanning.spatialKnowledge(id,now)
    local kept=0
    for _,fact in ipairs(facts or {}) do
        if fact.usable and fact.routeKnown and fact.z==bz and (fact.x-bx)^2+(fact.y-by)^2<=400 then
            move(fact.x,fact.y,fact.z,true,false);kept=kept+1
            if kept>=2 then break end
        end
    end
    local localMoves=call("localCombatMoves",body)
    if type(localMoves)=="string" then
        for x,y,z in localMoves:gmatch("MOVE\t([%-%.%d]+)\t([%-%.%d]+)\t([%-%.%d]+)") do
            move(tonumber(x),tonumber(y),tonumber(z),false,false)
        end
    end
    add({id="defend",kind="defend",available=permitted==true and mode~=nil,
        nativeMode=mode,targetKey=key,reason="Use a brief physical defense to make room.",
        effects={"create-space"},objections={"bodily-harm"}}, {mode=mode,targetKind=kind,targetKey=key})
    if mode and mode~="shove" then
        local objections={"bodily-harm","exposure"}
        if unresolvedCause then objections[#objections+1]="unanswered" end
        add({id="engage",kind="engage",available=permitted==true,nativeMode=mode,targetKey=key,
            reason=unresolvedCause and "The contact may harm me, but I have not identified what is happening."
                or "Attempt a bounded strike against this observed threat.",
            effects={"stop-threat"},objections=objections},
            {mode=mode,targetKind=kind,targetKey=key})
    end
    if personKey and threat.source=="observed" and threat.dist<=4 then
        local day=math.floor(now/24)
        agent.demandedAt=agent.demandedAt or {};agent.yieldedAt=agent.yieldedAt or {}
        if permitted and SAO.Disposition.wouldDemand(id) and agent.demandedAt[personKey]~=day
            and SAO.Communication and SAO.Communication.canConverse(id,personKey)==true then
            add({id="demand:"..personKey,kind="communicate",available=true,
                reason="Try to make this person comply through a spoken threat.",
                effects={"imposed-compliance"},objections={"response-unconfirmed","exposure"}},
                {demand=personKey,day=day})
        end
        if SAO.Disposition.wouldYieldTo(id) and agent.yieldedAt[personKey]~=day then
            local spare=call("findSpareFood",body)
            local recipient=SAO.Body.get(personKey)
            if spare and recipient and SAO.Handover then
                add({id="concede:"..personKey,kind="concede",available=true,
                    reason="Offer a spare meal in the hope this person lets me leave.",
                    effects={"possible-agreement","create-space"},objections={"loss-of-supplies","response-unconfirmed"}},
                    {recipient=recipient,recipientId=personKey,item=spare,day=day})
            end
        end
    end
    local knownContacts=SAO.Coordination and SAO.Coordination.knownContacts
        and SAO.Coordination.knownContacts(id) or {}
    if #knownContacts>0 and SAO.Coordination.originatePrivateSituation
        and tick >= (agent.nextConflictProposalAt or 0) then
        add({id="request-support",kind="communicate",available=true,
            reason="Propose watching the danger while we move to fallback ground.",
            effects={"possible-agreement","mutual-support"},objections={"response-unconfirmed","exposure"}},
            {request=true})
    end
    local org=SAO.Organization
    for index,commitment in ipairs(org and org.activeCommitments(id) or {}) do
        if index>8 then break end
        local plan=org.workPlan(commitment.id,id)
        if commitment.actorId==id and type(commitment.acceptedAt)=="number"
            and commitment.acceptedAt<=now and plan and plan.proposal
            and plan.proposal.scope and plan.proposal.scope.action=="tactical-withdrawal" then
            frame.commitment={kind="tactical-withdrawal",protectOther=true,accepted=true,key=commitment.id}
            add({id="coordinate:"..commitment.id,kind="coordinate",available=true,
                continuing=agent.conflictCoordination and agent.conflictCoordination.commitmentId==commitment.id or false,
                reason="Carry out my accepted part of our withdrawal.",effects={"mutual-support","break-contact"},
                objections={"exposure"}}, {commitment=commitment})
            break
        end
    end
    local continuing,approaching=ordinaryWork(id,agent,body,threat)
    add({id="watch",kind="watch",available=true,continuing=continuing~=nil,
        reason=continuing and "Continue "..continuing.." while reassessing the unresolved danger."
            or "Keep watching while looking for a usable response.",
        effects={},objections=approaching and {"exposure","bodily-harm"} or {"exposure"}},
        {continueOrdinary=continuing~=nil})
    local retreatAvailable=false
    for _,offer in ipairs(offers) do
        if offer.kind=="withdraw" and offer.available then retreatAvailable=true;break end
    end
    frame.escapeBlocked=not retreatAvailable
    return frame,offers,actions
end

function R.decide(id,agent,body,tick,threat,count,person,personKey,hooks)
    if not owns(id,agent,body) then return false end
    if not threat then agent.conflictGestureHold=nil;return false end
    if not (SAO.Cognition and SAO.Cognition.appraiseConflict
        and SAO.ProceduralPlanning and SAO.ProceduralPlanning.planConflict) then
        hooks.setState(agent,id,"ALERT","Conflict appraisal is unavailable.")
        return true
    end
    local fleeAt=SAO.PathogenPressure and SAO.PathogenPressure.fleeDistance(id,threat)
        or SAO.Disposition.fleeDistance(id)
    if SAO.Controller.appraiseCoordination then SAO.Controller.appraiseCoordination(id,body,agent.state) end
    local frame,offers,actions=alternatives(id,agent,body,tick,threat,count,person,personKey,hooks)
    local decision=SAO.ProceduralPlanning.planConflict(id,frame,offers)
    if not decision then
        hooks.setState(agent,id,"ALERT","No admitted conflict response is available.")
        return true
    end
    local action=actions[decision.selected]
    if not action then return true end
    agent.conflictGestureHold={body=body,rec=agent.rec,bodyToken=agent.rec.bodyOwnerToken,
        purposeId=decision.purposeId,selected=decision.selected,
        frameId=decision.frameId,at=tick,untilTick=tick+math.max(1,SAO.Disposition.decisionInterval(id))}
    -- Observation and orientation can update while a native crossing owns the
    -- body. Appraisal does not cancel that crossing or manufacture an action.
    if nativeCrossing(SAO.Locomotion.jobs[id],body) then
        if hooks.pumpMovement then hooks.pumpMovement(id) end
        return true
    end
    if decision.kind=="watch" and not agent.conflictRoute and not agent.conflictCoordination
        and (action.continueOrdinary or threat.dist>fleeAt and count<SAO.Disposition.overwhelmThreshold(id)) then
        -- Keeping awareness is compatible with existing work. Its physical
        -- owner and the ordinary needs caller still govern what happens next.
        agent.conflictGestureHold=nil
        return false
    end
    if action.job then
        agent.pressure={answer="threat",detail=decision.reason,at=tick}
        hooks.advance(id,agent,body,tick)
        return true
    end
    if action.commitment and agent.conflictCoordination then
        local owned=agent.conflictCoordination
        if owned.commitmentId==action.commitment.id and owned.body==body
            and (owned.nativeJob==(SAO.Posture and SAO.Posture.jobs[id])
                or owned.nativeJob==SAO.Locomotion.jobs[id] and not owned.nativeJob.done) then
            agent.pressure={answer="threat",detail=decision.reason,at=tick}
            return true
        end
    end
    if SAO.Study and SAO.Study.interrupt(id,body,"conflict response")~=true then return true end
    if SAO.Gesture and SAO.Gesture.yieldToConflict
        and not SAO.Gesture.yieldToConflict(id,body,decision) then return true end
    if SAO.Needs and SAO.Needs.busy and SAO.Needs.busy(body) then
        SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
            {frameId=decision.frameId,reason="another native timed action still owns the body"})
        return true
    end
    if not hooks.setState(agent,id,"ALERT",decision.reason) then return true end
    if agent.conflictRoute then
        if not outcome(id,agent.conflictRoute,"cancelled","another response was selected") then return true end
        agent.conflictRoute=nil
    end
    if agent.conflictCoordination then
        if not outcome(id,agent.conflictCoordination,"cancelled","another response was selected") then return true end
        agent.conflictCoordination=nil
    end
    if action.x then
        local token=nextToken(agent,"Locomotion")
        if SAO.Locomotion.order(id,body,action.x,action.y,action.z,
            SAO.Disposition.paceUnderThreat(id)=="run") then
            if SAO.ProceduralPlanning.conflictAdmission(id,decision.purposeId,token,decision.selected) then
                agent.conflictRoute={body=body,job=SAO.Locomotion.jobs[id],token=token,
                    purposeId=decision.purposeId,routeKey=action.routeKey}
                agent.fleeTargetX,agent.fleeTargetY=action.x,action.y
                hooks.setState(agent,id,"FLEE",decision.reason)
                hooks.advance(id,agent,body,tick)
            else SAO.Locomotion.cancel(id) end
        else
            SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
                {frameId=decision.frameId,reason="native movement admission refused",routeKey=action.routeKey})
        end
    elseif action.mode then
        local verdict=call("beginCombatObserved",body,action.targetKind,action.targetKey,action.mode)
        if type(verdict)=="string" and verdict:find("COMBAT_STARTED",1,true)==1 then
            local token=nextToken(agent,"SAO.Combat")
            if SAO.ProceduralPlanning.conflictAdmission(id,decision.purposeId,token,decision.selected) then
                agent.conflictCombat={body=body,token=token,purposeId=decision.purposeId,
                    actorId=id,targetKey=action.targetKey,threatCount=count,distance=threat.dist,
                    health=health(body),nextReview=tick+SAO.Disposition.decisionInterval(id)}
                hooks.setState(agent,id,"ENGAGE",decision.reason)
            else call("cancelCombatObserved",body) end
        else
            SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
                {frameId=decision.frameId,reason=tostring(verdict or "native combat admission unavailable")})
        end
    elseif action.request then
        local process,why=SAO.Coordination.originatePrivateSituation(id,body,agent.state,"Controller.conflict",
            {threat=threat,threatCount=count,position={x=body:getX(),y=body:getY(),z=math.floor(body:getZ())}})
        agent.nextConflictProposalAt=tick+300
        if process then
            local token=nextToken(agent,"SAO.Communication")
            if SAO.ProceduralPlanning.conflictAdmission(id,decision.purposeId,token,decision.selected) then
                outcome(id,{purposeId=decision.purposeId,token=token},"completed",
                    "proposal "..tostring(why or "created").."; agreement remains unconfirmed")
            end
        else
            SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
                {frameId=decision.frameId,reason=tostring(why or "proposal not created")})
        end
    elseif action.demand then
        local token=nextToken(agent,"SAO.Communication")
        local receipt,why=SAO.Communication.deliverThreat(id,action.demand,token.id,
            {source="personal-conflict-appraisal",proximity=threat.dist})
        agent.demandedAt[action.demand]=action.day
        if receipt then
            if SAO.ProceduralPlanning.conflictAdmission(id,decision.purposeId,token,decision.selected) then
                outcome(id,{purposeId=decision.purposeId,token=token},"completed",
                    "spoken threat received; compliance remains unconfirmed")
            end
            if SAO.Voice then SAO.Voice.onEvent(id,"demand",tick) end
        else
            SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
                {frameId=decision.frameId,reason=tostring(why or "speech not received")})
        end
    elseif action.recipient then
        local receipt,why=SAO.Handover.begin(id,body,action.recipientId,action.recipient,action.item,"yield",{
            effect={trust={{from=id,to=action.recipientId,delta=-0.05}},voice={actor=id,kind="yielded",at=tick}}})
        if receipt then
            agent.yieldedAt[action.recipientId]=action.day
            local token={owner="Handover",id=tostring(receipt.id)}
            if SAO.ProceduralPlanning.conflictAdmission(id,decision.purposeId,token,decision.selected) then
                agent.conflictHandover={body=body,receiptId=receipt.id,token=token,purposeId=decision.purposeId,
                    actorId=id,targetKey=threat.track or threat.name or person,threatCount=count,
                    distance=threat.dist,health=health(body),startedAt=SAO.History.countyHours()}
            end
        else
            SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
                {frameId=decision.frameId,reason=tostring(why or "material transfer not admitted")})
        end
    elseif action.commitment then
        local admitted,why=hooks.coordinate(id,body,agent,action.commitment)
        local job=SAO.Posture and SAO.Posture.jobs[id]
            or agent.coordinationRoute and SAO.Locomotion.jobs[id]
        if admitted and job and job.body==body then
            local token=nextToken(agent,"SAO.Coordination")
            if SAO.ProceduralPlanning.conflictAdmission(id,decision.purposeId,token,decision.selected) then
                agent.conflictCoordination={actorId=id,body=body,nativeJob=job,token=token,purposeId=decision.purposeId,
                    commitmentId=action.commitment.id,targetKey=threat.track or threat.name or person,
                    threatCount=count,distance=threat.dist,health=health(body)}
            end
        elseif not admitted then
            SAO.ProceduralPlanning.conflictRefusal(id,decision.purposeId,decision.selected,
                {frameId=decision.frameId,reason=tostring(why or "accepted work not currently executable")})
        end
    elseif decision.kind=="watch" then
        -- Native turning changes gaze; it does not establish sight or safety.
        pcall(function() body:faceLocationF(threat.x,threat.y) end)
    end
    return true
end

function R.pendingTransfer(id,agent,body,threat,count,personKey,reason)
    local work=agent.conflictHandover
    if not work then return false end
    if not owns(id,agent,body) or work.body~=body then
        if not outcome(id,work,"cancelled","transfer body owner changed") then return true end
        agent.conflictHandover=nil
        return false
    end
    SAO.Handover.reconcile(false)
    local receipt=SAO.Handover.result(work.receiptId)
    if reason or dangerChanged(work,body,threat,count or 0,personKey)
        or SAO.History.countyHours()-(work.startedAt or 0)>2 then
        work.reconsider=reason or "danger changed during transfer"
    end
    if receipt and receipt.actorId==id and receipt.status=="pending" and not work.reconsider then return true end
    -- A completed transfer can still have a retiring native action. Respect
    -- that handback before starting another physical response.
    if SAO.Handover.cancelAttempt(work.receiptId,id,body,work.reconsider or "transfer ended")~=true then return true end
    receipt=SAO.Handover.result(work.receiptId)
    local completed=receipt and receipt.actorId==id and receipt.status=="completed"
    if not outcome(id,work,completed and "completed" or "failed",completed
        and "spare food transferred; counterpart response remains unconfirmed"
        or "transfer ended without a completed material receipt") then return true end
    agent.conflictHandover=nil;agent.nextDecisionAt=0
    return false
end

function R.pump(id,agent,body,tick,threat,count,personKey,setState)
    local work=agent.conflictCombat
    if not work then return false end
    if work.body~=body or not owns(id,agent,body) then
        if not outcome(id,work,"cancelled","combat body ownership changed") then return true end
        agent.conflictCombat=nil
        return true
    end
    if tick>=work.nextReview then
        work.nextReview=tick+SAO.Disposition.decisionInterval(id)
        if dangerChanged(work,body,threat,count,personKey) then work.reconsider=true end
    end
    if work.reconsider and call("cancelCombatObserved",body)=="COMBAT_CANCELLED" then
        if not outcome(id,work,"cancelled","danger changed; reconsidering the next action") then return true end
        agent.conflictCombat=nil;agent.nextDecisionAt=0
        setState(agent,id,"ALERT","Danger changed; reconsidering the next action.")
        return true
    end
    local verdict=tostring(call("tickCombat",body) or "COMBAT_FAILED bridge-unavailable")
    if verdict~=agent.lastCombatVerdict then
        SAO.Log.line("CTRL",id.." "..verdict);agent.lastCombatVerdict=verdict
    end
    if verdict:find("COMBAT_COMPLETED",1,true)==1 or verdict:find("COMBAT_FAILED",1,true)==1
        or verdict=="COMBAT_CANCELLED" or verdict=="COMBAT_IDLE" then
        if not outcome(id,work,verdict=="COMBAT_CANCELLED" and "cancelled"
            or verdict:find("COMBAT_COMPLETED",1,true)==1 and "completed" or "failed",verdict) then return true end
        agent.conflictCombat=nil;agent.nextDecisionAt=0
        setState(agent,id,"ALERT","The physical attempt ended; reassessing its consequences.")
    end
    return true
end
return R
