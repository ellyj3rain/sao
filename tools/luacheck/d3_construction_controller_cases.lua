-- Actual Controller/Planner/WindowRepair and installed repair action/queue.
-- SourceUse transfers and Build cancellation acknowledgements are controlled
-- owner boundaries. Their physical producers have independent native proofs.
local C, P, W = SAO.Controller, SAO.ProceduralPlanning, SAO.WindowRepair
local sources, terminals, sourceCalls, buildWork, windowReconciles, boardReconciles = {}, {}, {}, {}, {}, {}
local eagerCalls, travelCalls = 0, 0
local function check(name, value)
    __windowCheck(name, value)
    print(name .. "=" .. tostring(value == true))
end
local function list(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end
SAOJavaBridge.privateCarriedItems = function(_, body) return list(body:getInventory().items) end
getSpecificPlayer = function() return nil end
SAO.Disposition.describe = function() return "controlled fixture" end
SAOJavaBridge.boardWindow = function() eagerCalls = eagerCalls + 1; return 1 end
SAO.Perception.knownPlaces = function(id)
    return sources[id] and { material = { sourceId = "place:materials", cx = 4, cy = 4, z = 0 } } or {}
end
SAO.WorldSources = {
    actionOptions = function(place, category, id)
        local source = sources[id]
        if source and source.category == category then return { options = {{ parameters = source }} } end
        return { options = {} }
    end,
    privatelyKnowsItem = function(id, sourceId, itemId)
        local source = sources[id]
        return source and source.known == true and source.sourceId == sourceId and source.itemId == itemId or false
    end,
    actionOutcome = function(reservationId, id)
        local row = terminals[reservationId]
        return row and row.actorId == id and row or nil
    end,
}
SAO.SourceUse = {
    beforeStateChange = function() return true end,
    closeForOwnershipTransfer = function() return true end,
    detach = function() return true end,
    beginAcquisition = function(id, body, place, category, context)
        local rec = SAO.Identity.get(id)
        local purpose = rec.proceduralPlanning.purposes[context.purposeId]
        local step = purpose.steps[purpose.cursor]
        rec.controlledMaterialSequence = (rec.controlledMaterialSequence or 0) + 1
        local reservationId = "controlled-material:" .. id .. ":" .. tostring(rec.controlledMaterialSequence)
        sourceCalls[id] = { place = place, category = category, context = context, reservationId = reservationId,
            expectedSource = step.sourceId, expectedRevision = step.sourceRevision, expectedItem = step.itemId,
            expectedType = step.itemType, expectedStep = step.id, purpose = purpose }
        if not P.noteAdmission(id, context.purposeId, "SAO.SourceUse", reservationId, context.purposeStepId) then return false end
        rec.worldSourceReservation = reservationId
        return true
    end,
}
SAO.Locomotion.order = function(id, body, x, y, z)
    travelCalls = travelCalls + 1
    body.orderedTravel = { x = x, y = y, z = z }
    return true
end
SAO.Build.begin = function(id, body, offer, purposeId, stepId)
    local rec=SAO.Identity.get(id)
    rec.barricade=rec.barricade or {schema=1,nextWork=0,nextResult=0,outcomes={},order={}}
    local nextWork=rec.barricade.nextWork+1
    local workId=id.."/barricade-work/"..nextWork
    local accepted = P.noteAdmission(id, purposeId, "SAOBuild", workId, stepId)
    if accepted then
        rec.barricade.nextWork=nextWork
        buildWork[id] = { pendingAck = true, interruptCalls = {}, forgetCalls = 0,
            id=workId,purposeId = purposeId, stepId = stepId, entryKey = offer.entryKey }
        body.boardingAdmitted = buildWork[id]
    end
    return accepted
end
SAO.Build.offer = function(id, body, key)
    local entry = body.boardEntry or "barricade:0:0:0:0:true"
    if not body.boardTargetUnavailable and body.boardKit and (key == nil or key == entry) then
        return { entryKey = entry }
    end
end
SAO.Build.destination=function(id,body,offer) return {key=offer.entryKey,x=0,y=0,z=0} end
SAO.Build.reconcileSaved = function(id)
    boardReconciles[id] = (boardReconciles[id] or 0) + 1
    SAO.Build.flush(id)
    return not (buildWork[id] and buildWork[id].pendingAck)
end
local reconcileWindow = W.reconcileSaved
W.reconcileSaved = function(id, body)
    windowReconciles[id] = (windowReconciles[id] or 0) + 1
    return reconcileWindow(id, body)
end
SAO.Build.interrupt = function(id, body, reason)
    local work = buildWork[id]
    if not work then return true end
    work.interruptCalls[#work.interruptCalls + 1] = reason
    return not work.pendingAck
end
SAO.Build.forget = function(id)
    local work = buildWork[id]
    if not work then return true end
    work.forgetCalls = work.forgetCalls + 1
    if work.pendingAck then return false end
    buildWork[id] = nil
    return true
end
SAO.Build.active = function(id) return buildWork[id] ~= nil end
local acknowledgeBuild,ackWithoutAgent=SAO.Build.acknowledge,{}
SAO.Build.acknowledge=function(id,sequence)
    local accepted=acknowledgeBuild(id,sequence)
    if accepted and C.agents[id]==nil then ackWithoutAgent[id]=true end
    return accepted
end

local function fixture(id, pane)
    local f = __windowFixture(id)
    f.rec.forename, f.rec.surname, f.rec.x, f.rec.y = "Controller", "Fixture", 0, 0
    function f.pane:getFluidContainerFromSelfOrWorldItem() return nil end
    if not pane then f.inventory.items = {}; f.pane.container = nil end
    C.agents[id] = f.agent
    return f
end
local function knownPane(f, known)
    sources[f.id] = { sourceId = "holder:glass", itemId = f.pane:getID(), revision = 7,
        itemType = f.pane:getFullType(), category = "glass-pane", known = known }
end
local function acquiredPane(f)
    local call = sourceCalls[f.id]
    f.inventory.items, f.pane.container = { f.pane }, f.inventory
    -- The deterministic SourceUse boundary supplies its canonical measured
    -- result independently from the connector arguments under inspection.
    local result = { actorId = f.id, reservationId = call.reservationId, purposeId = call.purpose.id,
        purposeStepId = call.expectedStep, operation = "acquire", status = "completed",
        sourceId = call.expectedSource, preRevision = call.expectedRevision, itemId = call.expectedItem,
        itemType = call.expectedType, category = call.category,
        observedQuantity = 1, measurement = "native-item-transfer", at = __hours }
    terminals[call.reservationId] = result
    f.rec.worldSourceReservation = nil
    return P.consumeSourceResult(result)
end
local function noEffect(f)
    return f.window:isSmashed() and #ISTimedActionQueue.getTimedActionQueue(f.body).queue == 0
        and f.rec.windowRepairWork == nil
end

local function boardingTerminal(f,status,planksBefore)
    -- Physical Build effects are a controlled boundary. Its actual canonical
    -- outcome validator, flush, planner consumer and acknowledgement execute.
    local work,s=buildWork[f.id],f.rec.barricade
    local completed=status=="completed"
    planksBefore=planksBefore or 0
    s.nextResult=s.nextResult+1
    local sequence=s.nextResult
    local row={id=f.id.."/barricade-result/"..sequence,sequence=sequence,actorId=f.id,
        purposeId=work.purposeId,stepId=work.stepId,workId=work.id,entryKey=work.entryKey,
        status=status,startedAt=__hours,endedAt=__hours,reason="controlled-native-terminal",
        nativeOwner="ISBarricadeAction",plankConsumed=completed,nailsConsumed=completed and 2 or 0,
        barricadeChanged=completed,nativeAttempted=completed,itemId="controlled-plank",hammerId="controlled-hammer",
        world="controlled-"..f.id,bodyToken=f.rec.bodyOwnerToken,x=0,y=0,z=0,objectIndex=0,north=true,
        planksBefore=planksBefore,planksAfter=planksBefore+(completed and 1 or 0)}
    s.outcomes[tostring(sequence)],s.order[#s.order+1]=row,sequence
    work.pendingAck=false
    return row
end

function __runD3ConstructionControllerCases()
    check("d3_controller_native_repair_guard_installs", W.install() == true)
    local missing = fixture("d3-controller-missing", false)
    local blocked = __decideHome(missing.id, missing.agent, missing.body, 50, missing.rec) ~= true
    local destination = P.constructionDestination(missing.id)
    check("d3_controller_missing_pane_retains_observed_purpose", blocked and destination ~= nil
        and destination.operation == "repair" and destination.status == "blocked" and noEffect(missing))
    knownPane(missing, false)
    local stillBlocked = __decideHome(missing.id, missing.agent, missing.body, 51, missing.rec) ~= true
    check("d3_controller_unknown_private_material_stays_blocked", stillBlocked and sourceCalls[missing.id] == nil
        and P.constructionDestination(missing.id).purposeId == destination.purposeId and noEffect(missing))

    sources[missing.id].known = true
    local dispatched = __decideHome(missing.id, missing.agent, missing.body, 52, missing.rec)
    local call = sourceCalls[missing.id]
    check("d3_controller_dispatches_exact_material_identity", dispatched == true and call ~= nil
        and call.category == "glass-pane" and call.context.purposeId == destination.purposeId
        and call.context.purposeStepId == call.expectedStep and call.context.sourceId == "holder:glass"
        and call.context.sourceRevision == 7 and call.context.itemId == missing.pane:getID()
        and call.context.itemType == missing.pane:getFullType() and missing.agent.state == "SOURCEWARD")
    local purpose = call and call.purpose
    check("d3_controller_material_admission_has_no_construction_credit", purpose and purpose.cursor == 1
        and P.techniqueProfile(missing.id).practice[destination.entryKey] == nil
        and missing.window:isSmashed() and not missing.inventory:contains(missing.pane))
    local admission, step = purpose and purpose.admission, purpose and purpose.steps[purpose.cursor]
    local hold = C.advanceConstruction(missing.id, missing.agent, missing.body, 53, P.constructionDestination(missing.id))
    check("d3_controller_pending_material_admission_is_preserved", hold == false
        and purpose.admission == admission and purpose.steps[purpose.cursor] == step)
    local transferred = call and acquiredPane(missing)
    check("d3_controller_authenticated_transfer_preserves_construction_purpose", transferred == true
        and purpose.admission == nil and P.techniqueProfile(missing.id).practice[destination.entryKey] == nil)
    missing.body.x, missing.body.y = 4.5, 4.5
    __setState(missing.agent, missing.id, "IDLE", "controlled SourceUse terminal handback")
    local returned = __decideHome(missing.id, missing.agent, missing.body, 54, missing.rec)
    local route = missing.body.orderedTravel
    check("d3_controller_returns_through_production_travel", returned == true and missing.agent.state == "TRAVEL"
        and route and route.x == destination.x and route.y == destination.y and route.z == destination.z
        and P.constructionDestination(missing.id).purposeId == destination.purposeId)
    missing.body.x, missing.body.y = .5, .5
    __setState(missing.agent, missing.id, "IDLE", "controlled native route arrived")
    missing.inventory.mirror, missing.window.mirror = true, true
    __nativeOp("reset")
    local reacquired = __decideHome(missing.id, missing.agent, missing.body, 55, missing.rec)
    local action = ISTimedActionQueue.getTimedActionQueue(missing.body).current
    check("d3_controller_reacquires_exact_native_repair_target", reacquired == true and action ~= nil
        and missing.agent.state == "WINDOWREPAIR" and missing.rec.windowRepairWork
        and missing.rec.windowRepairWork.purposeId == destination.purposeId
        and missing.rec.windowRepairWork.entryKey == destination.entryKey)
    __hours = __hours + .1
    local completed = action and action:complete() == true
    if action then action:perform() end
    local result = W.outcome(missing.id, 1)
    check("d3_controller_native_repair_consumes_pane_and_closes_same_purpose", completed and result
        and result.status == "completed" and result.paneConsumed and result.planningAcknowledged
        and __nativeOp("poststate") == true and purpose.status == "completed"
        and result.purposeId == destination.purposeId and P.constructionDestination(missing.id) == nil)

    local changed = fixture("d3-controller-target-changed", false)
    __decideHome(changed.id, changed.agent, changed.body, 60, changed.rec)
    local retained = P.constructionDestination(changed.id)
    changed.inventory.items, changed.pane.container = { changed.pane }, changed.inventory
    changed.window.north = false
    changed.body.dx,changed.body.dy=-1,0
    local targetRefused = C.advanceConstruction(changed.id, changed.agent, changed.body, 61, retained)
    check("d3_controller_changed_aperture_blocks_repair", targetRefused ~= true and noEffect(changed)
        and P.constructionDestination(changed.id).entryKey == retained.entryKey)
    changed.window.north = true
    local claim = changed.rec.claim
    changed.rec.claim = nil
    local standingRefused = C.advanceConstruction(changed.id, changed.agent, changed.body, 62, retained)
    check("d3_controller_changed_standing_blocks_repair", standingRefused ~= true and noEffect(changed)
        and P.constructionDestination(changed.id).status == "blocked")
    changed.rec.claim = claim

    local otherWork = fixture("d3-controller-blocked-repair-board", false)
    __decideHome(otherWork.id, otherWork.agent, otherWork.body, 65, otherWork.rec)
    local oldRepair = P.constructionDestination(otherWork.id)
    otherWork.body.boardKit = true
    local otherAdmitted = __decideHome(otherWork.id, otherWork.agent, otherWork.body, 66, otherWork.rec)
    check("d3_controller_blocked_repair_allows_observed_boarding", otherAdmitted == true
        and otherWork.agent.state == "BOARDING" and otherWork.body.boardingAdmitted ~= nil
        and otherWork.rec.proceduralPlanning.purposes[oldRepair.purposeId].status == "blocked"
        and P.constructionDestination(otherWork.id).operation == "board")

    local board = fixture("d3-controller-board", true)
    board.body.boardKit = true
    local boardAdmitted = C.tryBoarding(board.id, board.agent, board.body, 70)
    check("d3_controller_boarding_uses_native_owner_without_eager_bridge", boardAdmitted == true
        and board.agent.state == "BOARDING" and board.body.boardingAdmitted ~= nil and eagerCalls == 0
        and P.techniqueProfile(board.id).practice[board.body.boardingAdmitted.entryKey] == nil)
    local work, beforeTravel = buildWork[board.id], travelCalls
    local stateRefused = __setState(board.agent, board.id, "IDLE", "interrupt controlled boarding")
    local travelRefused = __d3OrderTravel(board.agent, board.id, board.body, 2, 2, 0, "TRAVEL", "replace boarding route")
    check("d3_controller_board_cancellation_preflight_holds_for_ack", stateRefused == false and travelRefused == false
        and board.agent.state == "BOARDING" and travelCalls == beforeTravel and work.pendingAck)
    board.rec.zaoTransferPending = { controlled = true }
    local transferBefore = __transferRetries or 0
    __updateAgent(board.id, board.agent)
    check("d3_controller_zao_transfer_waits_for_board_ack", (__transferRetries or 0) == transferBefore
        and work.pendingAck and C.agents[board.id] == board.agent)
    work.pendingAck = false
    __updateAgent(board.id, board.agent)
    check("d3_controller_zao_transfer_resumes_after_board_ack", (__transferRetries or 0) == transferBefore + 1)

    local dead = fixture("d3-controller-board-death", true)
    dead.body.boardKit = true
    C.tryBoarding(dead.id, dead.agent, dead.body, 80)
    local deadWork = buildWork[dead.id]
    dead.body.dead = true
    __updateAgent(dead.id, dead.agent)
    local deathRequested = false
    for _, reason in ipairs(deadWork.interruptCalls) do if reason == "death" then deathRequested = true end end
    check("d3_controller_death_requests_board_cancellation_and_retains_ack", dead.rec.dead == true
        and C.agents[dead.id] == nil and SAO.Body.active[dead.id] == nil
        and deathRequested and deadWork.pendingAck and deadWork.forgetCalls > 0 and buildWork[dead.id] == deadWork)
    deadWork.pendingAck = false
    check("d3_controller_late_board_ack_retires_without_live_agent", SAO.Build.forget(dead.id) == true
        and buildWork[dead.id] == nil and C.agents[dead.id] == nil)

    local inspected=fixture("d3-controller-board-inspection",true)
    inspected.body.boardKit=true
    local inspectedAdmission=C.tryBoarding(inspected.id,inspected.agent,inspected.body,81)
    C.reconcileBoardingInspection(inspected.id)
    check("d3_controller_boarding_admission_does_not_increment_inspection",inspectedAdmission
        and inspected.rec.boarded==0 and inspected.agent.boarded==0 and __d3InspectBoarded(inspected.id)==nil)
    local completedBoard=boardingTerminal(inspected,"completed")
    __d3BoardHold(inspected.id,inspected.agent,inspected.body,82)
    local inspectedCount,inspectedRows=__d3InspectBoarded(inspected.id)
    check("d3_controller_canonical_board_completion_updates_inspection",completedBoard.planningAcknowledged==true
        and inspected.rec.boarded==1 and inspected.rec.boardedResultSequence==completedBoard.sequence
        and inspected.agent.boarded==1 and inspectedCount==1 and inspectedRows[1]=="boarded 1 window")
    SAO.Build.flush(inspected.id)
    P.consumeBarricadeOutcome(inspected.id,completedBoard.sequence)
    __d3BoardHold(inspected.id,inspected.agent,inspected.body,83)
    C.reconcileConstruction(inspected.id,inspected.body)
    check("d3_controller_repeated_board_terminal_does_not_double_inspection",inspected.rec.boarded==1
        and inspected.agent.boarded==1 and __d3InspectBoarded(inspected.id)==1)

    local priorBoard=inspected.rec.proceduralPlanning.purposes[completedBoard.purposeId]
    local priorStep=priorBoard.steps[1]
    __setState(inspected.agent,inspected.id,"IDLE","controlled first native boarding work retired")
    local nextPlank=C.tryBoarding(inspected.id,inspected.agent,inspected.body,84)
    local nextWork=buildWork[inspected.id]
    local nextPurpose=nextWork and inspected.rec.proceduralPlanning.purposes[nextWork.purposeId]
    local nextStep=nextPurpose and nextPurpose.steps[nextPurpose.cursor]
    check("d3_controller_same_aperture_accepts_next_completed_plank",nextPlank==true
        and priorBoard.status=="completed" and priorStep.status=="completed"
        and nextWork and nextWork.id~=completedBoard.workId and nextWork.entryKey==completedBoard.entryKey
        and nextPurpose and nextPurpose.id~=priorBoard.id and nextStep
        and nextStep.id~=priorStep.id and nextStep.status=="available" and nextPurpose.admission~=nil)
    if not nextPlank or not nextPurpose then error("next plank was not admitted") end
    inspected.rec=__nativeRoundtrip(inspected.rec)
    __records[inspected.id],inspected.agent.rec=inspected.rec,inspected.rec
    nextPurpose=inspected.rec.proceduralPlanning.purposes[nextWork.purposeId]
    nextStep=nextPurpose.steps[nextPurpose.cursor]
    local nextAdmission=nextPurpose.admission
    local pendingContext=C.constructionContext(inspected.id,inspected.agent,inspected.body,"board",
        nextWork.entryKey,{key=nextWork.entryKey,x=0,y=0,z=0})
    pendingContext.materials={hammer=0,plank=0,nails=0}
    local pendingPurpose,pendingStep=P.planFortification(inspected.id,pendingContext)
    check("d3_controller_next_plank_pending_admission_survives_replan",pendingPurpose==nextPurpose
        and pendingStep==nextStep and pendingPurpose.admission==nextAdmission
        and nextAdmission.correlationId==nextWork.id
        and nextAdmission.stepId==nextStep.id and nextAdmission.target==nextWork.entryKey)
    local secondBoard=boardingTerminal(inspected,"completed",1)
    __d3BoardHold(inspected.id,inspected.agent,inspected.body,85)
    SAO.Build.flush(inspected.id)
    P.consumeBarricadeOutcome(inspected.id,secondBoard.sequence)
    C.reconcileConstruction(inspected.id,inspected.body)
    check("d3_controller_sequential_planks_complete_once_each_after_saved_replay",secondBoard.planningAcknowledged==true
        and nextPurpose.status=="completed" and nextPurpose.admission==nil
        and inspected.rec.boarded==2 and __d3InspectBoarded(inspected.id)==2
        and P.techniqueProfile(inspected.id).practice[secondBoard.entryKey].completed==2)

    local absent=fixture("d3-controller-board-inspection-adoption",true)
    absent.body.boardKit=true
    C.tryBoarding(absent.id,absent.agent,absent.body,84)
    local absentResult=boardingTerminal(absent,"completed")
    C.reconcileBoardingInspection(absent.id)
    check("d3_controller_unacknowledged_board_result_has_no_inspection_count",absentResult.planningAcknowledged~=true
        and absent.rec.boarded==0 and absent.rec.boardedResultSequence==0 and __d3InspectBoarded(absent.id)==nil)
    C.agents[absent.id]=nil
    local absentAdopted=C.adopt(absent.rec)
    absent.agent=C.agents[absent.id]
    check("d3_controller_adoption_flushes_board_count_without_prior_agent",absentAdopted==true
        and ackWithoutAgent[absent.id]==true and absentResult.planningAcknowledged==true
        and absent.rec.boarded==1 and absent.rec.boardedResultSequence==absentResult.sequence
        and absent.agent and absent.agent.boarded==1 and __d3InspectBoarded(absent.id)==1)
    absent.rec=__nativeRoundtrip(absent.rec)
    __records[absent.id]=absent.rec
    C.agents[absent.id]=nil
    local savedAdopted=C.adopt(absent.rec)
    SAO.Build.flush(absent.id)
    P.consumeBarricadeOutcome(absent.id,absentResult.sequence)
    C.reconcileConstruction(absent.id,absent.body)
    check("d3_controller_saved_board_counter_replay_is_once_only",savedAdopted==true
        and absent.rec.boarded==1 and absent.rec.boardedResultSequence==absentResult.sequence
        and C.agents[absent.id].boarded==1 and __d3InspectBoarded(absent.id)==1)

    local stoppedBoard=fixture("d3-controller-board-inspection-interrupted",true)
    stoppedBoard.body.boardKit=true
    C.tryBoarding(stoppedBoard.id,stoppedBoard.agent,stoppedBoard.body,85)
    local stoppedResult=boardingTerminal(stoppedBoard,"interrupted")
    __d3BoardHold(stoppedBoard.id,stoppedBoard.agent,stoppedBoard.body,86)
    check("d3_controller_interrupted_board_result_has_no_inspection_count",stoppedResult.planningAcknowledged==true
        and stoppedBoard.rec.boarded==0 and stoppedBoard.rec.boardedResultSequence==stoppedResult.sequence
        and stoppedBoard.agent.boarded==0 and __d3InspectBoarded(stoppedBoard.id)==nil)
    local failedBoard=fixture("d3-controller-board-inspection-failed",true)
    failedBoard.body.boardKit=true
    C.tryBoarding(failedBoard.id,failedBoard.agent,failedBoard.body,87)
    local failedResult=boardingTerminal(failedBoard,"failed")
    __d3BoardHold(failedBoard.id,failedBoard.agent,failedBoard.body,88)
    check("d3_controller_invalid_failed_board_result_has_no_inspection_count",SAO.Build.outcome(failedBoard.id,failedResult.sequence)==nil
        and failedResult.planningAcknowledged~=true and failedBoard.rec.boarded==0
        and failedBoard.agent.boarded==0 and __d3InspectBoarded(failedBoard.id)==nil)
    local legacyCount=fixture("d3-controller-existing-board-inspection",true)
    legacyCount.agent.boarded=2
    C.adopt(legacyCount.rec)
    C.reconcileConstruction(legacyCount.id,legacyCount.body)
    check("d3_controller_existing_session_board_count_is_preserved",legacyCount.rec.boarded==2
        and legacyCount.agent.boarded==2 and __d3InspectBoarded(legacyCount.id)==2)

    local saved = fixture("d3-controller-saved-window", true)
    saved.inventory.mirror, saved.window.mirror = true, true
    __nativeOp("reset")
    local savedAdmission = C.tryWindowRepair(saved.id, saved.agent, saved.body, 90)
    local savedDestination = P.constructionDestination(saved.id)
    local savedPurposeId = savedDestination and savedDestination.purposeId
    local snapshot = __nativeRoundtrip(saved.rec)
    local oldAction = ISTimedActionQueue.getTimedActionQueue(saved.body).current
    local oldRetired = W.interrupt(saved.id, saved.body, "controlled old native owner acknowledged")
    if not oldRetired and oldAction then oldAction:stop(); oldRetired = W.interrupt(saved.id, saved.body, "acknowledged") end
    __records[saved.id], saved.rec = snapshot, snapshot
    C.agents[saved.id] = nil
    local wBefore, bBefore = windowReconciles[saved.id] or 0, boardReconciles[saved.id] or 0
    local adopted = C.adopt(saved.rec)
    saved.agent = C.agents[saved.id]
    local recovered = W.outcome(saved.id, 1)
    check("d3_controller_adoption_reconciles_actual_saved_window_owner", savedAdmission and oldRetired and adopted
        and (windowReconciles[saved.id] or 0) == wBefore + 1 and (boardReconciles[saved.id] or 0) == bBefore + 1
        and recovered and recovered.recoveryOnly == true and recovered.status == "interrupted"
        and recovered.nativeOwner == "SAO.WindowRepair.reconcileSaved" and recovered.planningAcknowledged == true)
    local savedPurpose = saved.rec.proceduralPlanning.purposes[savedPurposeId]
    local practice = P.techniqueProfile(saved.id).practice[savedDestination.entryKey]
    local continuedDestination = P.constructionDestination(saved.id)
    check("d3_controller_saved_recovery_preserves_goal_without_completion_credit", savedPurpose
        and savedPurpose.admission == nil and savedPurpose.status ~= "completed" and continuedDestination
        and continuedDestination.purposeId == savedPurposeId and continuedDestination.entryKey == savedDestination.entryKey
        and continuedDestination.x == savedDestination.x and (not practice or practice.completed == 0)
        and __nativeOp("contains") == true and __nativeOp("smashed") == true
        and #ISTimedActionQueue.getTimedActionQueue(saved.body).queue == 0)

    local held = fixture("d3-controller-idle-native-ack", true)
    local heldAdmission = C.tryWindowRepair(held.id, held.agent, held.body, 95)
    local heldAction = ISTimedActionQueue.getTimedActionQueue(held.body).current
    held.body.holdCancellation, held.body.stopAllThrows = true, true
    C.agents[held.id] = nil
    C.adopt(held.rec)
    held.agent = C.agents[held.id]
    held.agent.nextGearAt, held.agent.nextAmmoAt = 99999, 99999
    held.body.boardKit = true
    local idleBefore = windowReconciles[held.id] or 0
    local heldIdle = __decideHome(held.id, held.agent, held.body, 96, held.rec)
    check("d3_controller_idle_holds_for_window_cancellation_ack", heldAdmission and heldIdle ~= true
        and (windowReconciles[held.id] or 0) == idleBefore + 1 and held.agent.state == "IDLE"
        and ISTimedActionQueue.hasAction(heldAction) and held.body.boardingAdmitted == nil)
    held.body.holdCancellation, held.body.stopAllThrows = false, false
    if heldAction then heldAction:stop() end
    check("d3_controller_reconciliation_accepts_exact_late_window_ack", C.reconcileConstruction(held.id, held.body) == true
        and not ISTimedActionQueue.hasAction(heldAction) and held.window:isSmashed() and held.inventory:contains(held.pane))

    local function observedBoardPurpose(f)
        f.body.boardKit = true
        f.window.smashed, f.window.glass = false, false
        local offer = SAO.Build.offer(f.id, f.body)
        local destination = SAO.Build.destination(f.id, f.body, offer)
        local context = C.constructionContext(f.id, f.agent, f.body, "board", offer.entryKey, destination)
        context.observedEntry = true
        return P.planFortification(f.id, context), offer.entryKey
    end
    local readyRepair=fixture("d3-controller-blocked-board-ready-repair",true)
    local unfinishedBoard,unfinishedEntry=observedBoardPurpose(readyRepair)
    readyRepair.body.boardKit=false
    readyRepair.window.smashed,readyRepair.window.glass=true,true
    readyRepair.inventory.mirror,readyRepair.window.mirror=true,true
    __nativeOp("reset")
    local repairedInstead=__decideHome(readyRepair.id,readyRepair.agent,readyRepair.body,96,readyRepair.rec)
    local repairWork=readyRepair.rec.windowRepairWork
    local repairAction=ISTimedActionQueue.getTimedActionQueue(readyRepair.body).current
    check("d3_controller_blocked_board_allows_ready_window_repair",repairedInstead==true
        and readyRepair.agent.state=="WINDOWREPAIR" and repairWork and repairAction
        and repairWork.entryKey=="window:0:0:0:0:true" and repairWork.purposeId~=unfinishedBoard.id)
    check("d3_controller_ready_repair_keeps_unfinished_board_purpose",unfinishedBoard.status=="blocked"
        and unfinishedBoard.admission==nil and unfinishedBoard.materialWork.operation=="board"
        and unfinishedBoard.materialWork.entryKey==unfinishedEntry
        and unfinishedBoard.constructionDestination.key==unfinishedEntry
        and readyRepair.rec.proceduralPlanning.purposes[unfinishedBoard.id]==unfinishedBoard
        and P.techniqueProfile(readyRepair.id).practice[unfinishedEntry]==nil)
    local finishedRepair=repairAction and repairAction:complete()==true
    if repairAction then repairAction:perform() end
    local readyRepairResult=W.outcome(readyRepair.id,1)
    local survivingBoard=P.constructionDestination(readyRepair.id)
    check("d3_controller_ready_repair_completion_keeps_unfinished_board_purpose",finishedRepair
        and readyRepairResult and readyRepairResult.status=="completed" and readyRepairResult.planningAcknowledged
        and __nativeOp("poststate")==true and not readyRepair.inventory:contains(readyRepair.pane)
        and unfinishedBoard.status=="blocked" and unfinishedBoard.admission==nil
        and survivingBoard and survivingBoard.purposeId==unfinishedBoard.id and survivingBoard.entryKey==unfinishedEntry)

    local pendingBoard=fixture("d3-controller-pending-board-ready-repair",true)
    local pendingPurpose,pendingEntry=observedBoardPurpose(pendingBoard)
    pendingBoard.body.boardKit=false
    pendingBoard.window.smashed,pendingBoard.window.glass=true,true
    sources[pendingBoard.id]={sourceId="holder:hammer",itemId=712,revision=11,
        itemType="Base.Hammer",category="hammer",known=true}
    local materialStarted=C.advanceConstruction(pendingBoard.id,pendingBoard.agent,pendingBoard.body,96,
        P.constructionDestination(pendingBoard.id))
    local pendingCall=sourceCalls[pendingBoard.id]
    local pendingAdmission=pendingPurpose.admission
    local pendingStep=pendingPurpose.steps[pendingPurpose.cursor]
    -- The controlled SourceUse state projection allows an IDLE decision while
    -- its exact canonical material admission still belongs to the work owner.
    __setState(pendingBoard.agent,pendingBoard.id,"IDLE","controlled pending material state projection")
    local competingRepair=__decideHome(pendingBoard.id,pendingBoard.agent,pendingBoard.body,97,pendingBoard.rec)
    local pendingDestination=P.constructionDestination(pendingBoard.id)
    check("d3_controller_pending_board_material_admission_blocks_ready_repair",materialStarted==true
        and pendingCall and pendingCall.category=="hammer" and pendingCall.context.sourceRevision==11
        and pendingCall.context.purposeId==pendingPurpose.id and pendingCall.context.purposeStepId==pendingStep.id
        and competingRepair~=true and pendingBoard.agent.state=="IDLE" and noEffect(pendingBoard)
        and pendingPurpose.admission==pendingAdmission and pendingPurpose.steps[pendingPurpose.cursor]==pendingStep
        and pendingDestination and pendingDestination.pendingAdmission and pendingDestination.entryKey==pendingEntry)

    local orientRepair=fixture("d3-controller-orient-repair",true)
    orientRepair.body.x=.25
    local orientOffer=W.offer(orientRepair.id,orientRepair.body)
    local orientDestination=W.destination(orientRepair.id,orientRepair.body,orientOffer)
    local orientContext=C.constructionContext(orientRepair.id,orientRepair.agent,orientRepair.body,"repair",orientOffer.entryKey,orientDestination)
    orientContext.observedEntry=true
    local orientPurpose=P.planFortification(orientRepair.id,orientContext)
    orientRepair.body.dx,orientRepair.body.dy=0,1
    function orientRepair.body:faceThisObject(target) self.turnedTarget=target;self.turnPending=true end
    function orientRepair.body:shouldBeTurning() return self.turnPending==true end
    local repairTurn=C.advanceConstruction(orientRepair.id,orientRepair.agent,orientRepair.body,96,P.constructionDestination(orientRepair.id))
    check("d3_controller_returned_repair_waits_for_native_turn",repairTurn==true
        and orientRepair.body.turnedTarget==orientRepair.window and orientRepair.rec.windowRepairWork==nil
        and orientPurpose.admission==nil and orientPurpose.status~="completed")
    -- Native turn completion is a controlled locomotor boundary; native offer
    -- facing and exact target admission still execute through the real owner.
    function orientRepair.body:faceThisObject(target) self.turnedTarget=target;self.dx=0;self.dy=-1;self.turnPending=false end
    local repairFacing=C.advanceConstruction(orientRepair.id,orientRepair.agent,orientRepair.body,97,P.constructionDestination(orientRepair.id))
    check("d3_controller_returned_repair_reacquires_after_native_turn",repairFacing==true
        and orientRepair.rec.windowRepairWork and orientRepair.rec.windowRepairWork.purposeId==orientPurpose.id)
    local orientBoard=fixture("d3-controller-orient-board",true)
    local orientBoardPurpose,orientBoardEntry=observedBoardPurpose(orientBoard)
    orientBoard.body.dx=-1
    local originalBoardOffer=SAO.Build.offer
    SAO.Build.offer=function(id,body,key)
        if body==orientBoard.body and body.dx<0 then return nil end
        return originalBoardOffer(id,body,key)
    end
    function orientBoard.body:faceThisObject(target) self.turnedTarget=target;self.turnPending=true end
    function orientBoard.body:shouldBeTurning() return self.turnPending==true end
    local boardTurn=C.advanceConstruction(orientBoard.id,orientBoard.agent,orientBoard.body,98,P.constructionDestination(orientBoard.id))
    check("d3_controller_returned_board_waits_without_refusal",boardTurn==true
        and orientBoard.body.turnedTarget==orientBoard.window and orientBoardPurpose.admission==nil
        and orientBoardPurpose.constructionTargetRefusal==nil and orientBoardPurpose.status~="completed")
    function orientBoard.body:faceThisObject(target) self.turnedTarget=target;self.dx=1;self.turnPending=false end
    local boardFacing=C.advanceConstruction(orientBoard.id,orientBoard.agent,orientBoard.body,99,P.constructionDestination(orientBoard.id))
    check("d3_controller_returned_board_reacquires_after_native_turn",boardFacing==true
        and orientBoard.body.boardingAdmitted and orientBoard.body.boardingAdmitted.purposeId==orientBoardPurpose.id)
    SAO.Build.offer=originalBoardOffer
    local changedOrientation=fixture("d3-controller-orient-changed",true)
    changedOrientation.window.north=false
    function changedOrientation.window:getNorth() return self.north end
    function changedOrientation.body:faceThisObject(target) self.turnedTarget=target;self.turnPending=true end
    function changedOrientation.body:shouldBeTurning() return self.turnPending==true end
    local changedTurn=C.orientConstructionEntry(changedOrientation.body,{operation="repair",entryKey="window:0:0:0:0:true"})
    check("d3_controller_changed_entry_does_not_orient",changedTurn==false and changedOrientation.body.turnedTarget==nil)
    local unavailable = fixture("d3-controller-unavailable-board", true)
    local oldPurpose, oldEntry = observedBoardPurpose(unavailable)
    unavailable.body.boardTargetUnavailable = true
    local noOffer = __decideHome(unavailable.id, unavailable.agent, unavailable.body, 100, unavailable.rec)
    check("d3_controller_unavailable_board_target_retains_bounded_deferral", noOffer ~= true
        and oldPurpose.constructionTargetRefusal and oldPurpose.constructionTargetRefusal.entryKey == oldEntry
        and oldPurpose.constructionTargetRefusal.retryAt == __hours + .1 and oldPurpose.status == "blocked"
        and oldPurpose.constructionDestination.key == oldEntry and oldPurpose.admission == nil
        and P.constructionDestination(unavailable.id) == nil)
    local replacement = fixture("d3-controller-new-board-offer", true)
    local replacementPurpose, priorEntry = observedBoardPurpose(replacement)
    replacement.body.boardEntry = "barricade:0:0:0:1:true"
    local nextOffer = __decideHome(replacement.id, replacement.agent, replacement.body, 105, replacement.rec)
    local nextDestination = P.constructionDestination(replacement.id)
    local refusalEvent = false
    for _, event in ipairs(replacementPurpose.events) do
        if event.kind == "construction-target-refused" then refusalEvent = true end
    end
    check("d3_controller_new_visible_boarding_preserves_deferred_purpose", nextOffer == true
        and replacement.agent.state == "BOARDING" and replacement.body.boardingAdmitted
        and replacement.body.boardingAdmitted.purposeId == replacementPurpose.id
        and nextDestination and nextDestination.purposeId == replacementPurpose.id
        and nextDestination.entryKey == replacement.body.boardEntry and nextDestination.entryKey ~= priorEntry
        and replacementPurpose.constructionTargetRefusal == nil and refusalEvent)
    -- The native craft owner's effects are independently exercised by the
    -- installed handcraft proof. Here its canonical result is a controlled
    -- boundary, joined to the complete production context/dispatch/recovery.
    ItemTag = ItemTag or { SAW = "controlled-native-saw" }
    local crafting = fixture("d3-controller-crafting", false)
    crafting.body.boardKit = true
    local oldCount = SAOJavaBridge.constructionMaterialCount
    SAOJavaBridge.constructionMaterialCount = function(self, body, category)
        if body ~= crafting.body then return oldCount(self, body, category) end
        if category == "hammer" then return 1 end
        if category == "nails" then return 2 end
        if category == "plank" then return body.plankCount or 0 end
        return body[category .. "Held"] and 1 or 0
    end
    local function craftItem(id, fullType, isSaw)
        return { condition=10,getID=function()return id end,getFullType=function()return fullType end,
            getFluidContainerFromSelfOrWorldItem=function()return nil end,
            getIsCraftingConsumed=function()return false end,
            hasTag=function(_,tag)return isSaw and tag==ItemTag.SAW end,
            getCondition=function(self)return self.condition end,getConditionMax=function()return 10 end,isBroken=function()return false end }
    end
    local log, saw = craftItem(910,"Base.Log",false), craftItem(911,"Base.Saw",true)
    local craftWork, craftOutcome, savedFlushes
    savedFlushes=0
    SAO.ResourceProduction = {
        options=function()return {} end,
        craftingAvailable=function(_,body)return body==crafting.body end,
        interrupt=function()return true end,
        outcome=function(id,workId)return craftOutcome and craftOutcome.actorId==id and craftOutcome.id==workId and craftOutcome or nil end,
        reconcileSaved=function(id)
            if id==crafting.id and craftOutcome and not craftOutcome.purposeDelivered then
                savedFlushes=savedFlushes+1
                craftOutcome.purposeDelivered=P.consumeCraftProductionResult(id,craftOutcome)
            end
            return true
        end,
        begin=function(id,body,step,context)
            craftWork={id="resource-production/"..id.."/1",actorId=id,kind="saw-logs",recipeId="Base.SawLogs",
                purposeId=context.purposeId,purposeStepId=context.purposeStepId,
                logItemId=step.logItemId,logItemType=step.logItemType,sawItemId=step.sawItemId,sawItemType=step.sawItemType}
            if not P.admitCraftProduction(id,craftWork) then return false end
            crafting.rec.resourceProductionWork=craftWork
            return true
        end,
    }
    local craftPurpose, craftEntry=observedBoardPurpose(crafting)
    sources[crafting.id]={sourceId="holder:log",itemId=910,revision=8,itemType="Base.Log",category="log",known=true}
    local logRoute=C.advanceConstruction(crafting.id,crafting.agent,crafting.body,120,P.constructionDestination(crafting.id))
    local acquiredCall=sourceCalls[crafting.id]
    check("d3_controller_craft_acquires_private_log",logRoute and acquiredCall and acquiredCall.category=="log"
        and acquiredCall.context.itemId==910 and acquiredCall.context.purposeId==craftPurpose.id)
    local function finishAcquisition(item)
        local call=sourceCalls[crafting.id]
        crafting.inventory.items[#crafting.inventory.items+1]=item
        crafting.rec.worldSourceReservation=nil
        local result={actorId=crafting.id,reservationId=call.reservationId,purposeId=craftPurpose.id,
            purposeStepId=call.expectedStep,operation="acquire",status="completed",sourceId=call.expectedSource,
            preRevision=call.expectedRevision,itemId=call.expectedItem,itemType=call.expectedType,category=call.category,
            observedQuantity=1,measurement="native-item-transfer",at=__hours}
        terminals[result.reservationId]=result
        local consumed=P.consumeSourceResult(result)
        crafting.agent.state="IDLE"
        return consumed
    end
    local logConsumed=finishAcquisition(log);crafting.body.logHeld=true
    -- Separate source outcomes have independent exact reservation identities.
    sources[crafting.id]={sourceId="holder:saw",itemId=911,revision=9,itemType="Base.Saw",category="saw",known=true}
    local sawRoute=C.advanceConstruction(crafting.id,crafting.agent,crafting.body,121,P.constructionDestination(crafting.id))
    check("d3_controller_craft_acquires_private_saw",logConsumed and sawRoute and sourceCalls[crafting.id].category=="saw")
    local sawConsumed=finishAcquisition(saw);crafting.body.sawHeld=true
    local deepItems={}
    for i=1,241 do deepItems[#deepItems+1]=craftItem(10000+i,"Base.GlassPanel",false) end
    deepItems[#deepItems+1],deepItems[#deepItems+2]=log,saw
    crafting.inventory.items=deepItems
    local deepContext=C.constructionContext(crafting.id,crafting.agent,crafting.body,"board",craftEntry,{key=craftEntry,x=0,y=0,z=0})
    check("d3_controller_exact_craft_inputs_after_240_items",deepContext.craftInputs
        and deepContext.craftInputs.logItemId=="910" and deepContext.craftInputs.sawItemId=="911")
    local boundedItems={}
    for i=1,510 do boundedItems[#boundedItems+1]=craftItem(30000+i,"Base.GlassPanel",false) end
    boundedItems[511],boundedItems[512]=log,saw;crafting.inventory.items=boundedItems
    local lastContext=C.constructionContext(crafting.id,crafting.agent,crafting.body,"board",craftEntry,{key=craftEntry,x=0,y=0,z=0})
    check("d3_controller_exact_craft_inputs_at_512_bound",lastContext.craftingAvailable==true
        and lastContext.craftInputs.logItemId=="910" and lastContext.craftInputs.sawItemId=="911")
    boundedItems[513]=craftItem(31000,"Base.GlassPanel",false)
    local excessiveContext=C.constructionContext(crafting.id,crafting.agent,crafting.body,"board",craftEntry,{key=craftEntry,x=0,y=0,z=0})
    check("d3_controller_craft_over_native_inventory_bound_unavailable",excessiveContext.craftingAvailable~=true
        and excessiveContext.craftInputs==nil and excessiveContext.materials.log==nil and crafting.rec.resourceProductionWork==nil)
    crafting.inventory.items=deepItems
    crafting.body.x=2.5
    local started=C.advanceConstruction(crafting.id,crafting.agent,crafting.body,122,P.constructionDestination(crafting.id))
    check("d3_controller_dispatches_craft_before_return_travel",sawConsumed and started and crafting.agent.state=="RESOURCE"
        and craftWork and craftWork.logItemId=="910" and craftWork.sawItemId=="911"
        and crafting.body.orderedTravel==nil and craftPurpose.status~="completed")
    craftOutcome={id=craftWork.id,actorId=crafting.id,purposeId=craftPurpose.id,purposeStepId=craftWork.purposeStepId,
        kind="saw-logs",recipeId="Base.SawLogs",token="resource:crafted",nativeOwner="ISHandcraftAction",
        logItemId="910",logItemType="Base.Log",sawItemId="911",sawItemType="Base.Saw",
        status="completed",atHours=__hours,outputCount=3,nativeCredit=craftWork.id,nativeAttempted=true,
        logConsumed=true,sawRetained=true,held=true,
        outputs={{itemId="921",itemType="Base.Plank"},{itemId="922",itemType="Base.Plank"},{itemId="923",itemType="Base.Plank"}}}
    crafting.rec.resourceProductionWork=nil
    local restored=C.reconcileConstruction(crafting.id,crafting.body)
    check("d3_controller_restored_craft_result_flushes_without_work",restored and savedFlushes==1
        and craftOutcome.purposeDelivered and craftPurpose.admission==nil)
    crafting.body.plankCount=3;crafting.agent.state="IDLE"
    local returns=C.advanceConstruction(crafting.id,crafting.agent,crafting.body,123,P.constructionDestination(crafting.id))
    check("d3_controller_crafted_planks_return_to_original_entry",returns and crafting.agent.state=="TRAVEL"
        and crafting.body.orderedTravel and crafting.body.orderedTravel.x==0
        and P.constructionDestination(crafting.id).entryKey==craftEntry)
    crafting.body.x=.5;crafting.agent.state="IDLE"
    local boards=C.advanceConstruction(crafting.id,crafting.agent,crafting.body,124,P.constructionDestination(crafting.id))
    check("d3_controller_crafted_planks_resume_same_boarding_purpose",boards and crafting.agent.state=="BOARDING"
        and crafting.body.boardingAdmitted.purposeId==craftPurpose.id)
    __windowResults = table.concat(__checks, "\n")
end
