-- Production planner cases; native inventory and SourceUse outcomes are controlled.
local checks = {}
local function check(name, value) checks[#checks + 1] = name .. "=" .. tostring(value == true) end
local function actor(id)
    __records[id] = { id = id, dead = false }
    return id
end
local function source(category, item, revision, known, distance)
    return { sourceId = "holder:" .. category, revision = revision or 1, itemId = item,
        itemType = category == "glass-pane" and "RepairableWindows.LargeGlassPane" or ({ hammer = "Base.Hammer", plank = "Base.Plank", nails = "Base.Nails", log = "Base.Log", saw = "Base.Saw", file = "Base.File" })[category],
        category = category, known = known ~= false, distance = distance or 1,
        place = { sourceId = "place:home", cx = 5, cy = 5, z = 0 } }
end
local function context(operation, materials, sources)
    return { operation = operation, insideOwnedGround = true, knownGround = true,
        entryKey = "window:5:5:0:N", materials = materials, sources = sources or {}, atHours = __hours }
end
local outcomes, boardResult, windowResult = {}, nil, nil
local boardAcknowledgements, windowAcknowledgements = 0, 0
local craftResult
SAO.ResourceProduction = { outcome = function(id, workId)
    return craftResult and craftResult.actorId == id and craftResult.id == workId and craftResult or nil
end }
SAO.WorldSources = { actionOutcome = function(reservationId, actorId)
    local result = outcomes[reservationId]
    return result and result.actorId == actorId and result or nil
end }
SAO.Build = { outcome = function() return boardResult end,
    acknowledge = function() boardAcknowledgements = boardAcknowledgements + 1; return true end }
SAO.WindowRepair = { outcome = function() return windowResult end,
    acknowledge = function() windowAcknowledgements = windowAcknowledgements + 1; return true end }
local function admit(id, purpose, step, reservationId, status)
    local P = SAO.ProceduralPlanning
    local admitted = P.noteAdmission(id, purpose.id, "SAO.SourceUse", reservationId, step.id)
    outcomes[reservationId] = { reservationId = reservationId, actorId = id, purposeId = purpose.id,
        purposeStepId = step.id, operation = "acquire", status = status or "completed", sourceId = step.sourceId,
        preRevision = step.sourceRevision, itemId = step.itemId, itemType = step.itemType, category = step.category,
        measurement = "native-item-transfer", observedQuantity = 1, at = __hours }
    return admitted, outcomes[reservationId]
end
local function consume(result)
    return SAO.ProceduralPlanning.consumeSourceResult({ reservationId = result.reservationId,
        actorId = result.actorId, purposeId = result.purposeId, purposeStepId = result.purposeStepId })
end

function __runD3MaterialPlanningCases()
    local P, id = SAO.ProceduralPlanning, actor("d3-glass")
    local c = context("repair", { ["glass-pane"] = 0 }, { ["glass-pane"] = {
        source("glass-pane", 2, 1, false, 0), source("glass-pane", 3, 1, true, 2) } })
    c.destination = { x = 5, y = 5, z = 0, key = c.entryKey }
    local purpose, step = P.planFortification(id, c)
    check("d3_missing_pane_has_exact_acquisition", purpose.key == "repair:" .. c.entryKey
        and step.owner == "SAO.SourceUse" and step.category == "glass-pane" and step.itemId == 3
        and step.sourceRevision == 1 and step.token == "resource:acquired" and purpose.windowRepair == true)
    check("d3_unknown_material_source_refused", step.itemId ~= 2)
    local destination = P.constructionDestination(id)
    destination.x = 1000
    check("d3_return_destination_is_plain_exact_and_detached", P.constructionDestination(id).x == 5
        and destination.purposeId == purpose.id and destination.operation == "repair"
        and destination.entryKey == c.entryKey and destination.pendingAdmission == false)
    check("d3_forged_acquisition_refused", P.recordResult(id, purpose.id,
        { owner = "SAO.SourceUse", token = "resource:acquired", status = "completed", atHours = __hours }) == false
        and purpose.cursor == 1)
    local admitted, result = admit(id, purpose, step, "glass-1")
    check("d3_forged_admitted_acquisition_refused", P.recordResult(id, purpose.id,
        { owner = "SAO.SourceUse", token = "resource:acquired", status = "completed",
            correlationId = "glass-1", atHours = __hours }) == false and purpose.cursor == 1)
    local savedStep, savedAdmission, revision = step, purpose.admission, purpose.revision
    c.materials["glass-pane"] = 1
    c.sources = { ["glass-pane"] = { source("glass-pane", 99, 2) } }
    local pending, pendingStep = P.planFortification(id, c)
    check("d3_pending_admission_preserves_exact_step", admitted and pending == purpose and pendingStep == savedStep
        and pending.admission == savedAdmission and pending.revision == revision)
    result.sourceId = "other-holder"
    check("d3_wrong_source_result_refused", consume(result) == false and purpose.cursor == 1)
    result.sourceId = step.sourceId
    result.preRevision = 2
    check("d3_wrong_revision_result_refused", consume(result) == false and purpose.cursor == 1)
    result.preRevision = 1
    result.itemType = "Base.Window"
    check("d3_wrong_item_type_result_refused", consume(result) == false and purpose.cursor == 1)
    result.itemType = step.itemType
    local acquired = consume(result)
    purpose, step = P.planFortification(id, c)
    check("d3_acquisition_preserves_repair_purpose", acquired and purpose == pending
        and step.owner == "SAO.WindowRepair" and step.status == "available"
        and purpose.completedSteps[1].id == savedStep.id and purpose.completedSteps[1].status == "completed")
    check("d3_resource_authority_cannot_complete_repair", P.consumeSourceResult({ reservationId = "glass-1",
        actorId = id, purposeId = purpose.id, purposeStepId = savedStep.id }) == true
        and step.status ~= "completed"
        and P.recordResult(id, purpose.id, { owner = "SAO.WindowRepair", token = "construction:window-repaired",
            status = "completed", atHours = __hours }) == false)
    local repairAdmission = P.noteAdmission(id, purpose.id, "SAO.WindowRepair", "window-work/1")
    windowResult = { sequence = 1, actorId = id, purposeId = purpose.id, workId = "window-work/1",
        entryKey = c.entryKey, status = "completed", endedAt = __hours,
        paneConsumed = true, smashedBefore = true, smashedAfter = false, glassRemovedAfter = false }
    local repaired = P.consumeWindowRepairOutcome(id, 1)
    local repairPractice = P.techniqueProfile(id).practice[c.entryKey].completed
    check("d3_native_window_result_after_acquisition", repairAdmission and repaired and purpose.status == "completed")
    check("d3_window_duplicate_acknowledges_without_credit", P.consumeWindowRepairOutcome(id, 1) == true
        and P.techniqueProfile(id).practice[c.entryKey].completed == repairPractice and windowAcknowledgements == 2)

    local nailsId = actor("d3-nails")
    local nc = context("board", { hammer = 1, plank = 1, nails = 0 }, { nails = { source("nails", 10, 1) } })
    local np, first = P.planFortification(nailsId, nc)
    local firstAdmitted, n1 = admit(nailsId, np, first, "nails-1")
    local firstConsumed = consume(n1)
    nc.materials.nails = 1
    np, step = P.planFortification(nailsId, nc)
    check("d3_one_nail_cannot_complete_recipe", firstAdmitted and firstConsumed
        and step.owner == "SAOBuild" and step.status == "blocked" and np.status == "blocked")
    nc.sources.nails = { source("nails", 11, 2) }
    local secondPurpose, second = P.planFortification(nailsId, nc)
    check("d3_second_nail_requires_new_exact_acquisition", secondPurpose == np and second.category == "nails"
        and second.id ~= first.id and second.sourceRevision == 2 and np.completedSteps[1].id == first.id)
    local secondAdmitted, n2 = admit(nailsId, np, second, "nails-2")
    local secondConsumed = consume(n2)
    nc.materials.nails = 2
    np, step = P.planFortification(nailsId, nc)
    check("d3_two_native_nails_open_boarding", secondAdmitted and secondConsumed
        and step.owner == "SAOBuild" and step.status == "available" and #np.completedSteps == 2)
    local boardAdmission = P.noteAdmission(nailsId, np.id, "SAOBuild", "board-work/1", step.id)
    check("d3_forged_board_completion_refused", boardAdmission
        and P.recordResult(nailsId, np.id, { owner = "SAOBuild", token = "construction:boarded",
            correlationId = "board-work/1", status = "completed", atHours = __hours }) == false)
    boardResult = { actorId = nailsId, purposeId = np.id, workId = "board-work/1", sequence = 1,
        status = "completed", entryKey = nc.entryKey, nativeOwner = "ISBarricadeAction", endedAt = __hours,
        plankConsumed = true, nailsConsumed = 1, barricadeChanged = true }
    check("d3_board_requires_two_consumed_nails", P.consumeBarricadeOutcome(nailsId, 1) == false and np.cursor == 1)
    boardResult.nailsConsumed, boardResult.entryKey = 2, "other-window"
    check("d3_board_wrong_aperture_refused", P.consumeBarricadeOutcome(nailsId, 1) == false and np.cursor == 1)
    boardResult.entryKey, boardResult.actorId = nc.entryKey, "other-actor"
    check("d3_board_wrong_actor_refused", P.consumeBarricadeOutcome(nailsId, 1) == false and np.cursor == 1)
    boardResult.actorId = nailsId
    local boarded = P.consumeBarricadeOutcome(nailsId, 1)
    check("d3_exact_native_boarding_advances_once", boarded and np.steps[1].status == "completed" and np.cursor == 2
        and np.status == "completed"
        and P.consumeBarricadeOutcome(nailsId, 1) == true and boardAcknowledgements == 2
        and P.techniqueProfile(nailsId).practice[nc.entryKey].completed == 1)
    local previousBoardPurpose = np.id
    nc.entryKey = "second-window"
    np, step = P.planFortification(nailsId, nc)
    check("d3_new_aperture_does_not_inherit_completed_board", step.target == "second-window"
        and step.id == "board-known-entry:second-window:" .. np.id
        and np.id ~= previousBoardPurpose and step.status == "available" and np.cursor == 1)

    local interruptedId = actor("d3-interrupted")
    local ic = context("repair", { ["glass-pane"] = 0 }, { ["glass-pane"] = { source("glass-pane", 20, 1) } })
    local ip, interruptedStep = P.planFortification(interruptedId, ic)
    local interruptAdmission, ir = admit(interruptedId, ip, interruptedStep, "glass-interrupted", "released")
    local interrupted = consume(ir)
    ip, step = P.planFortification(interruptedId, ic)
    check("d3_interruption_keeps_purpose_and_delays_retry", interruptAdmission and interrupted
        and step.owner == "SAO.WindowRepair" and step.status == "blocked" and ip.admission == nil
        and ip.routeFailures[1].retryAt > __hours and not ip.completedSteps)
    __hours = __hours + .1
    ic.atHours = __hours
    local resumed, resumedStep = P.planFortification(interruptedId, ic)
    check("d3_retry_resumes_same_exact_unfinished_step", resumed == ip and resumedStep.id == interruptedStep.id
        and resumedStep.status == "available")
    local looseId = actor("d3-loose-nails")
    local box, loose = source("nails", 700, 1, true, 1), source("nails", 701, 1, true, 5)
    box.itemType = "Base.NailsBox"
    local nailsContext = context("board", { hammer = 1, plank = 1, nails = 0 }, { nails = { box, loose } })
    local loosePurpose, looseStep = P.planFortification(looseId, nailsContext)
    check("d3_loose_nails_precede_nearer_box", looseStep.status == "available"
        and looseStep.itemId == 701 and looseStep.itemType == "Base.Nails")
    nailsContext.sources.nails = { box }
    local boxPurpose, boxStep = P.planFortification(actor("d3-box-only"), nailsContext)
    check("d3_box_without_unpacking_stays_blocked", boxStep.verb == "construct"
        and boxStep.status == "blocked" and boxPurpose.status == "blocked")
    local refusedId = actor("d3-refused-entry")
    local refusedContext = context("board", { hammer = 1, plank = 1, nails = 2 })
    refusedContext.destination = { key = refusedContext.entryKey, x = 5, y = 5, z = 0 }
    local refusedPurpose, refusedStep = P.planFortification(refusedId, refusedContext)
    check("d3_unavailable_entry_defers_without_losing_purpose", P.deferConstructionTarget(refusedId,
        refusedPurpose.id, refusedContext.entryKey, "another person filled the entry")
        and P.constructionDestination(refusedId) == nil and refusedPurpose.status == "blocked"
        and refusedPurpose.constructionDestination.key == refusedContext.entryKey)
    refusedContext.entryKey = "entry:8:5:0"
    refusedContext.destination = { key = refusedContext.entryKey, x = 8, y = 5, z = 0 }
    refusedContext.observedEntry = true
    local revisedPurpose, revisedStep = P.planFortification(refusedId, refusedContext)
    check("d3_fresh_observation_revises_same_security_purpose", revisedPurpose == refusedPurpose
        and revisedStep.status == "available" and revisedStep.target == refusedContext.entryKey
        and revisedPurpose.constructionTargetRefusal == nil)
    P.noteAdmission(refusedId, revisedPurpose.id, "SAOBuild", "board-pending", revisedStep.id)
    check("d3_target_refusal_cannot_displace_native_admission", not P.deferConstructionTarget(refusedId,
        revisedPurpose.id, refusedContext.entryKey, "refused") and revisedPurpose.admission.correlationId == "board-pending")
    local priorityId = actor("d3-priority")
    local blockedContext = context("repair", { ["glass-pane"] = 0 })
    blockedContext.destination = { x = 5, y = 5, z = 0, key = blockedContext.entryKey }
    local blockedPurpose = P.planFortification(priorityId, blockedContext)
    local boardContext = context("board", { hammer = 1, plank = 1, nails = 2 })
    boardContext.destination = blockedContext.destination
    local availablePurpose, availableStep = P.planFortification(priorityId, boardContext)
    check("d3_available_material_work_precedes_blocked_repair", P.constructionDestination(priorityId).purposeId == availablePurpose.id
        and blockedPurpose.status == "blocked")
    local priorityAdmitted = P.noteAdmission(priorityId, availablePurpose.id, "SAOBuild", "priority-board", availableStep.id)
    blockedContext.materials["glass-pane"] = 1
    P.planFortification(priorityId, blockedContext)
    check("d3_pending_material_admission_precedes_available_work", priorityAdmitted
        and P.constructionDestination(priorityId).purposeId == availablePurpose.id
        and P.constructionDestination(priorityId).pendingAdmission == true)
    local craftId = actor("d3-craft-planks")
    local craftContext = context("board", { hammer = 1, nails = 2, plank = 0, log = 0, saw = 0 }, {
        plank = { source("plank", 600, 1, true, 9) },
        log = { source("log", 601, 1, true, 1) }, saw = { source("saw", 602, 1, true, 1) } })
    craftContext.craftingAvailable = true
    craftContext.destination = { key = craftContext.entryKey, x = 5, y = 5, z = 0 }
    local craftPurpose, craft = P.planFortification(craftId, craftContext)
    check("d3_craft_finished_plank_remains_direct_means", craft.category == "plank" and craft.itemId == 600)
    craftContext.sources.plank = {}
    craftPurpose, craft = P.planFortification(craftId, craftContext)
    check("d3_craft_acquires_exact_known_log", craft.owner == "SAO.SourceUse" and craft.category == "log" and craft.itemId == 601)
    local logAdmitted, logResult = admit(craftId, craftPurpose, craft, "craft-log-acquire")
    craftContext.materials.log = 1
    local pinned, pinnedStep = P.planFortification(craftId, craftContext)
    check("d3_craft_acquisition_pins_original_purpose", logAdmitted and pinned.id == craftPurpose.id
        and pinnedStep.itemId == 601 and pinned.admission.correlationId == "craft-log-acquire")
    local logAccepted = consume(logResult)
    craftPurpose, craft = P.planFortification(craftId, craftContext)
    check("d3_craft_next_acquires_exact_known_saw", logAccepted and craft.category == "saw" and craft.itemId == 602)
    local sawAdmitted, sawResult = admit(craftId, craftPurpose, craft, "craft-saw-acquire")
    local sawAccepted = consume(sawResult)
    craftContext.materials.saw = 1
    craftContext.craftInputs = { logItemId = "601", logItemType = "Base.Log", sawItemId = "602", sawItemType = "Base.Saw" }
    craftPurpose, craft = P.planFortification(craftId, craftContext)
    check("d3_craft_exact_inputs_open_native_recipe", sawAdmitted and sawAccepted and craft.verb == "produce"
        and craft.recipeId == "Base.SawLogs" and craft.logItemId == "601" and craft.sawItemId == "602")
    local disabled = context("board", {hammer=1,nails=2,plank=0,log=1,saw=1})
    disabled.craftInputs, disabled.craftingAvailable = craftContext.craftInputs, false
    local _, disabledStep = P.planFortification(actor("d3-craft-disabled"), disabled)
    check("d3_craft_unavailable_recipe_remains_blocked", disabledStep.verb == "construct" and disabledStep.status == "blocked")
    local unknown = context("board", {hammer=1,nails=2,plank=0,log=0,saw=0}, {
        log={source("log",700,1,false)},saw={source("saw",701,1,false)}})
    unknown.craftingAvailable = true
    local _, unknownStep = P.planFortification(actor("d3-craft-unknown"), unknown)
    check("d3_craft_unknown_material_means_remain_blocked", unknownStep.verb == "construct" and unknownStep.status == "blocked")
    local work = { id = "native-craft-result", actorId = craftId, kind = "saw-logs", recipeId = "Base.SawLogs",
        purposeId = craftPurpose.id, purposeStepId = craft.id, logItemId = "601", logItemType = "Base.Log",
        sawItemId = "602", sawItemType = "Base.Saw" }
    local craftAdmitted = P.admitCraftProduction(craftId, work)
    craftContext.materials.plank = 3
    local heldPurpose, heldStep = P.planFortification(craftId, craftContext)
    check("d3_craft_admission_pins_step_without_output_credit", craftAdmitted and heldPurpose.id == craftPurpose.id
        and heldStep.id == craft.id and heldPurpose.status ~= "completed")
    check("d3_craft_generic_completion_refused", not P.recordResult(craftId, craftPurpose.id,
        {owner="SAO.ResourceProduction",token="resource:crafted",correlationId=work.id,status="completed",atHours=__hours}))
    craftResult = {id=work.id,actorId=craftId,purposeId=craftPurpose.id,purposeStepId=craft.id,
        kind="saw-logs",recipeId="Base.SawLogs",token="resource:crafted",nativeOwner="ISHandcraftAction",
        logItemId="601",logItemType="Base.Log",sawItemId="602",sawItemType="Base.Saw",
        status="completed",atHours=__hours,outputCount=3,nativeCredit=work.id,nativeAttempted=true,
        logConsumed=true,sawRetained=true,held=true,
        outputs={{itemId="801",itemType="Base.Plank"},{itemId="802",itemType="Base.Plank"},{itemId="803",itemType="Base.Plank"}}}
    local caller = {id=work.id,purposeId=craftPurpose.id}
    for _, field in ipairs({"recipeId","actorId","logItemId","sawItemId","nativeCredit","outputCount",
        "nativeAttempted","logConsumed","sawRetained","held"}) do
        local saved = craftResult[field]
        craftResult[field] = type(saved)=="boolean" and false or type(saved)=="number" and 2 or "wrong"
        check("d3_craft_rejects_"..string.lower(field), not P.consumeCraftProductionResult(craftId, caller))
        craftResult[field] = saved
    end
    craftResult.outputs[3].itemId="802"
    check("d3_craft_duplicate_output_identity_refused",not P.consumeCraftProductionResult(craftId,caller))
    craftResult.outputs[3].itemId="803";craftResult.outputs[3].itemType="Base.Log"
    check("d3_craft_wrong_output_type_refused",not P.consumeCraftProductionResult(craftId,caller))
    craftResult.outputs[3].itemType="Base.Plank"
    local accepted = P.consumeCraftProductionResult(craftId,caller)
    local twice = P.consumeCraftProductionResult(craftId,caller)
    local profile=P.techniqueProfile(craftId).practice["Base.SawLogs"]
    check("d3_craft_measured_native_result_advances_once",accepted and twice and profile.completed==1)
    local resumed, boardStep=P.planFortification(craftId,craftContext)
    check("d3_craft_returns_to_original_boarding_purpose",resumed.id==craftPurpose.id and boardStep.owner=="SAOBuild"
        and boardStep.status=="available" and resumed.constructionDestination.key==craftContext.entryKey)
    local failureId=actor("d3-craft-failure")
    craftContext.materials.plank=0
    local failedPurpose, failedStep=P.planFortification(failureId,craftContext)
    work.id,work.actorId,work.purposeId,work.purposeStepId="native-craft-failure",failureId,failedPurpose.id,failedStep.id
    local failureAdmitted=P.admitCraftProduction(failureId,work)
    craftResult.id,craftResult.actorId,craftResult.purposeId,craftResult.purposeStepId=work.id,failureId,failedPurpose.id,failedStep.id
    craftResult.status,craftResult.nativeCredit="failed",nil
    local failed=P.consumeCraftProductionResult(failureId,{id=work.id,purposeId=failedPurpose.id})
    local delayedPurpose, delayedCraft=P.planFortification(failureId,craftContext)
    check("d3_craft_failure_retains_purpose_and_retry",failureAdmitted and failed and delayedPurpose.id==failedPurpose.id
        and delayedCraft.verb=="produce" and delayedCraft.status=="blocked" and not delayedPurpose.admission)
    __hours=__hours+1;craftContext.atHours=__hours
    local retryPurpose,retryCraft=P.planFortification(failureId,craftContext)
    check("d3_craft_retry_preserves_exact_means",retryPurpose.id==failedPurpose.id and retryCraft.status=="available"
        and retryCraft.logItemId=="601" and retryPurpose.constructionDestination.key==craftContext.entryKey)
    local maintenanceId=actor("d3-maintenance")
    local m=context("board",{hammer=1,plank=0,nails=2,log=1,saw=1})
    m.destination={key=m.entryKey,x=5,y=5,z=0}
    m.craftingAvailable=true
    m.craftInputs={logItemId="601",logItemType="Base.Log",sawItemId="602",sawItemType="Base.Saw"}
    m.repairInputs={available=true,targetItemId="602",targetItemType="Base.Saw",toolItemId="603",toolItemType="Base.File",condition=9,maxCondition=10}
    local mp,ms=P.planFortification(maintenanceId,m)
    check("d3_usable_saw_can_continue_without_repair",ms.productionKind=="saw-logs")
    m.repairInputs.condition=2
    mp,ms=P.planFortification(maintenanceId,m)
    check("d3_condition_pressure_selects_exact_native_maintenance",ms.productionKind=="repair-held-item"
        and ms.targetItemId=="602" and ms.toolItemId=="603" and ms.recipeId=="Base.FixSaw")
    m.pressure=1
    local pressured, immediate=P.planFortification(maintenanceId,m)
    check("d3_immediate_security_pressure_can_precede_maintenance",immediate.productionKind=="saw-logs")
    m.pressure=0;m.repairInputs.available=false
    local unqualified, usable=P.planFortification(maintenanceId,m)
    check("d3_missing_native_repair_eligibility_keeps_usable_craft",usable.productionKind=="saw-logs")
    m.repairInputs.available=true;m.repairInputs.toolItemId=nil;m.repairInputs.toolItemType=nil
    m.sources.file={source("file",603,7,false)}
    mp,ms=P.planFortification(maintenanceId,m)
    check("d3_unobserved_file_supplies_no_maintenance_means",ms.productionKind=="saw-logs")
    m.sources.file[1].known=true
    mp,ms=P.planFortification(maintenanceId,m)
    check("d3_maintenance_acquires_exact_private_file",ms.owner=="SAO.SourceUse" and ms.category=="file"
        and ms.itemId==603 and ms.sourceRevision==7 and mp.constructionDestination.key==m.entryKey)
    local madmitted,mresult=admit(maintenanceId,mp,ms,"maintenance-file")
    local macquired=consume(mresult)
    m.repairInputs.toolItemId="603";m.repairInputs.toolItemType="Base.File"
    mp,ms=P.planFortification(maintenanceId,m)
    check("d3_acquired_file_retains_original_construction_purpose",madmitted and macquired
        and mp.id==pressured.id and ms.productionKind=="repair-held-item")
    local mw={id="native-repair",actorId=maintenanceId,kind="repair-held-item",recipeId="Base.FixSaw",
        targetItemId=ms.targetItemId,targetItemType=ms.targetItemType,toolItemId=ms.toolItemId,toolItemType=ms.toolItemType,
        requestedPurposeId=mp.id,requestedPurposeStepId=ms.id}
    mw.targetItemId="999"
    check("d3_repair_wrong_target_admission_refused",not P.admitRepairProduction(maintenanceId,mw))
    mw.targetItemId="602";mw.toolItemId="999"
    check("d3_repair_wrong_file_admission_refused",not P.admitRepairProduction(maintenanceId,mw))
    mw.toolItemId="603"
    local ma=P.admitRepairProduction(maintenanceId,mw)
    check("d3_repair_generic_completion_refused",ma and not P.recordResult(maintenanceId,mp.id,
        {owner="SAO.ResourceProduction",token="resource:repaired",status="completed",correlationId=mw.id,atHours=__hours}))
    m.repairInputs.condition=10
    local retained, pending=P.planFortification(maintenanceId,m)
    check("d3_repair_admission_retains_exact_work",retained.id==mp.id and pending.id==ms.id and retained.admission.correlationId==mw.id)
    craftResult={id=mw.id,actorId=maintenanceId,purposeId=mp.id,purposeStepId=ms.id,kind="repair-held-item",
        recipeId="Base.FixSaw",token="resource:repaired",nativeOwner="ISHandcraftAction",atHours=__hours,status="completed",
        targetItemId="999",targetItemType="Base.Saw",toolItemId="603",toolItemType="Base.File",
        nativeAttempted=true,nativeCompleted=true,nativeCredit=mw.id,targetRetained=true,held=true,improved=true,
        beforeCondition=2,afterCondition=8,maxCondition=10}
    local mr={id=mw.id,purposeId=mp.id}
    check("d3_repair_wrong_target_result_refused",not P.consumeRepairProductionResult(maintenanceId,mr))
    craftResult.targetItemId="602";craftResult.nativeCredit=nil
    check("d3_repair_without_native_credit_refused",not P.consumeRepairProductionResult(maintenanceId,mr))
    craftResult.nativeCredit=mw.id;craftResult.held=false
    check("d3_repair_unheld_target_refused",not P.consumeRepairProductionResult(maintenanceId,mr))
    craftResult.held=true;craftResult.afterCondition=2
    check("d3_repair_without_condition_gain_refused",not P.consumeRepairProductionResult(maintenanceId,mr))
    craftResult.afterCondition=8
    local mc=P.consumeRepairProductionResult(maintenanceId,mr)
    local again=P.consumeRepairProductionResult(maintenanceId,mr)
    check("d3_repair_measured_partial_gain_advances_once",mc and again and P.techniqueProfile(maintenanceId).practice["Base.FixSaw"].completed==1)
    local resumedRepair,resumedCraft=P.planFortification(maintenanceId,m)
    check("d3_repair_continues_same_plank_and_boarding_purpose",resumedRepair.id==mp.id
        and resumedCraft.productionKind=="saw-logs" and resumedRepair.constructionDestination.key==m.entryKey)
    return table.concat(checks, ",")
end

function __prepareD3MaterialReload()
    local id = actor("d3-reload")
    __d3ReloadContext = context("repair", { ["glass-pane"] = 0 }, { ["glass-pane"] = { source("glass-pane", 30, 1) } })
    local purpose, step = SAO.ProceduralPlanning.planFortification(id, __d3ReloadContext)
    local admitted, result = admit(id, purpose, step, "glass-reload")
    __d3ReloadId, __d3ReloadPurpose, __d3ReloadStep, __d3ReloadResult = id, purpose.id, step.id, result
    __d3ReloadAdmitted = admitted
    SAO.ProceduralPlanning = nil
end

function __finishD3MaterialReload()
    local P, id = SAO.ProceduralPlanning, __d3ReloadId
    local purpose, step = P.planFortification(id, __d3ReloadContext)
    local pending = __d3ReloadAdmitted and purpose.id == __d3ReloadPurpose and step.id == __d3ReloadStep
        and purpose.admission.correlationId == "glass-reload"
    local acquired = consume(__d3ReloadResult)
    __d3ReloadContext.materials["glass-pane"] = 1
    local resumed, nextStep = P.planFortification(id, __d3ReloadContext)
    return "d3_reload_preserves_pending_admission=" .. tostring(pending == true)
        .. ",d3_reload_consumes_exact_terminal_once=" .. tostring(acquired and resumed.id == purpose.id
            and nextStep.owner == "SAO.WindowRepair" and #resumed.completedSteps == 1)
end
