local function check(name, condition)
    if not condition then error("PLAYER_OBJECTIVE:" .. name) end
    __checks = (__checks or 0) + 1
end

local objectives = SAO.PlayerObjectives
local organization = SAO.Organization
local communication = SAO.Communication
local player = __player
local helper = "helper"
local target = __square(12, 0, 0)

check("no_mark_refused", objectives.ask(player, helper) == nil)
check("foreign_player_refused", objectives.mark({
    getUsername = function() return "operator" end,
    getCurrentSquare = function() return __square(0, 0, 0) end,
    isDead = function() return false end,
}, target) == nil)
local place = objectives.mark(player, target)
check("marked_square_named", place == "square 12,0,0")
check("near_mark_refused", objectives.mark(player, __square(3, 0, 0)) ~= nil
    and objectives.ask(player, helper) == nil)
objectives.mark(player, target)
local menu = { options = {} }
function menu:addOption(label, _, callback)
    self.options[label] = callback or true
end
SAO.Harness.addObjectiveOptions(menu, player, helper)
check("ordinary_person_menu_offers_bounded_request",
    menu.options["Ask them to watch the marked place and return"] ~= nil)
communication.registerExecutionOwner("ZAO", {
    bodyFor = function() return __body end,
    snapshot = function() return {
        bodyOwner = "ZAO", represented = true,
        currentActivity = "idle", competingPressure = 0,
        capabilities = { move = true, watch = true },
    } end,
})
__person.bodyOwner = "ZAO"
check("foreign_owner_refused", objectives.ask(player, helper) == nil)
__person.bodyOwner = nil
SAO.Body.active.helper = nil
check("missing_native_body_refused", objectives.ask(player, helper) == nil)
SAO.Body.active.helper = __body
__heard = false
check("unheard_request_refused", objectives.ask(player, helper) == nil)
check("no_unheard_process_invented", #organization.processOrder == 0)
__heard = true

local processId, state = objectives.ask(player, helper)
check("proposal_recorded", type(processId) == "string" and state == "recorded")
local process = organization.processes[processId]
check("player_authored_existing_process", process and process.originatorId
    == "player:operator" and process.kind == "cooperative-action")
local recipient = process.participants.helper
check("native_reception_recorded", recipient and recipient.receptions["1"]
    and recipient.receptions["1"].channel == "spoken")
check("player_review_does_not_read_private_reception",
    objectives.review(player, helper).requestReceived == nil)
local answer = recipient.responses["1"]
check("separate_returned_acceptance", answer and answer.response == "accept"
    and answer.delivered == true and answer.channel == "spoken")
local commitments = organization.activeCommitments(helper)
check("accepted_work_exists", #commitments == 1)
local commitment = commitments[1]
check("all_three_steps_claimed", commitment.stepIds.outbound
    and commitment.stepIds.watch and commitment.stepIds["return"])
check("native_work_plan_selected", organization.workPlan(commitment.id, helper)
    .intendedStepId == "outbound")
local acceptedMenu = { options = {} }
function acceptedMenu:addOption(label, _, callback)
    self.options[label] = callback or true
end
SAO.Harness.addObjectiveOptions(acceptedMenu, player, helper)
check("accepted_person_menu_offers_review_and_withdraw",
    acceptedMenu.options["Review marked-place request"] ~= nil
    and acceptedMenu.options["Withdraw marked-place request"] ~= nil
    and acceptedMenu.options["Repeat marked-place request"] == nil)
local initial = objectives.instrumentedWork(player, helper)
check("accepted_is_not_done", initial
    and initial.steps.outbound == nil and initial.returnedToPlace == false)
local publicInitial = objectives.review(player, helper)
check("accepted_without_work_report", publicInitial.response == "accept"
    and publicInitial.workReportDelivered == false
    and publicInitial.steps == nil
    and string.find(objectives.describe(publicInitial), "no work report",
        1, true) ~= nil)
check("inspection_does_not_record_player_review",
    organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil)
local sameId, retry = objectives.ask(player, helper)
check("repeated_request_reuses_process", sameId == processId
    and retry == "retried" and #organization.processOrder == 1)
player.x = 20
check("remote_withdrawal_refused", objectives.withdraw(player, helper) == false)
__lastText = nil
acceptedMenu.options["Review marked-place request"]()
check("stale_menu_review_rechecks_conversation",
    __lastText == "no-current-conversation")
player.x = 0

local failedOutbound = organization.noteRoute(commitment.id, "Locomotion",
    12, 0, 0, "travelling", { fixture = true, blocked = true })
check("failed_outbound_attempt_admitted", failedOutbound
    and failedOutbound.status == "pending")
organization.routeOutcome(commitment.id, "failed", "blocked")
local failedAttempt = objectives.review(player, helper)
check("failed_route_is_source_qualified_in_review", failedAttempt
    and failedAttempt.workOutcome == "failed-attempt"
    and failedAttempt.attempts[1].id == failedOutbound.id
    and failedAttempt.attempts[1].status == "failed"
    and string.find(objectives.describe(failedAttempt), "failed", 1, true)
        ~= nil)
__clock = __clock + 1
local outRoute = organization.noteRoute(commitment.id, "Locomotion",
    12, 0, 0, "travelling", { fixture = true })
check("outbound_route_admitted", outRoute and outRoute.status == "pending")
organization.routeOutcome(commitment.id, "arrived", "arrived")
__body.x = 12
local atTarget = objectives.instrumentedWork(player, helper)
check("outbound_arrival_distinct", atTarget.steps.outbound == outRoute.id
    and atTarget.steps.watch == nil and atTarget.steps["return"] == nil
    and atTarget.returnedToPlace == false)
check("watch_next", organization.workPlan(commitment.id, helper)
    .intendedStepId == "watch")

check("posture_admitted", organization.noteWorkAdmission(commitment.id,
    "Posture", "posture/helper/1", { stepId = "watch" }) == true)
local refused = organization.consumeProcedureResult({
    id = "posture/helper/1", actorId = "other",
    commitmentId = commitment.id, stepId = "watch",
    token = "posture:maintained", owner = "Posture", status = "completed",
})
check("foreign_native_result_refused", refused == false)
local watched = organization.consumeProcedureResult({
    id = "posture/helper/1", actorId = helper,
    commitmentId = commitment.id, stepId = "watch",
    token = "posture:maintained", owner = "Posture", status = "completed",
    evidence = { maintainedSeconds = 3, requiredSeconds = 3 },
})
check("posture_receipt_consumed", watched == true)
local beforeReturn = objectives.instrumentedWork(player, helper)
check("watch_is_not_return", beforeReturn.steps.watch == "posture/helper/1"
    and beforeReturn.returnedToPlace == false)
check("return_next", organization.workPlan(commitment.id, helper)
    .intendedStepId == "return")
local backRoute = organization.noteRoute(commitment.id, "Locomotion",
    0, 0, 0, "travelling", { fixture = true })
check("return_route_admitted", backRoute and backRoute.status == "pending")
organization.routeOutcome(commitment.id, "interrupted", "blocked")
local failedReturn = objectives.instrumentedWork(player, helper)
check("failed_route_does_not_return", failedReturn.steps["return"] == nil
    and failedReturn.returnedToPlace == false)
check("failed_route_keeps_responsibility", commitment.status == "paused")
player.x = 9
local partial = objectives.review(player, helper)
check("partial_route_is_source_qualified_in_review", partial
    and partial.workOutcome == "partial"
    and partial.attempts[2].id == outRoute.id
    and partial.attempts[2].status == "arrived"
    and partial.attempts[3].id == backRoute.id
    and partial.attempts[3].status == "interrupted"
    and string.find(objectives.describe(partial), "interrupted", 1, true)
        ~= nil)
local partialAction = objectives.reviewAction(player, helper,
    process.id, process.revision)
check("partial_review_does_not_claim_completed_return", partialAction
    and partialAction.workReportDelivered == false
    and organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil)
player.x = 0
__clock = __clock + 1
local retryRoute = organization.noteRoute(commitment.id, "Locomotion",
    0, 0, 0, "travelling", { fixture = true, routeChanged = 1 })
check("changed_route_retry_admitted", retryRoute ~= false)
organization.routeOutcome(commitment.id, "arrived", "arrived")
local returnRecorded = objectives.instrumentedWork(player, helper)
check("return_receipt_is_not_current_reunion",
    returnRecorded.returnedToPlace == true
    and returnRecorded.withPlayerNow == false)
check("remote_completion_cannot_deliver_work_report",
    organization.objectiveReportFor(process.id, helper,
        "player:operator") == nil
    and objectives.review(player, helper) == nil)
__body.x = 0
local completed = objectives.instrumentedWork(player, helper)
check("return_receipt_distinct", completed.steps["return"] == retryRoute.id
    and completed.returnedToPlace == true)
retryRoute.x = 1
check("review_requires_exact_return_route", objectives.instrumentedWork(player, helper)
    .returnedToPlace == false)
check("changed_return_route_cannot_be_reported",
    objectives.reviewAction(player, helper,
        process.id, process.revision).workReportDelivered == false)
retryRoute.x = 0
retryRoute.status = "interrupted"
check("review_requires_arrived_return", objectives.instrumentedWork(player, helper)
    .returnedToPlace == false)
check("interrupted_return_cannot_be_reported",
    objectives.reviewAction(player, helper,
        process.id, process.revision).workReportDelivered == false)
retryRoute.status = "arrived"
check("physical_reunion_requires_current_proximity", completed.withPlayerNow
    == true)
check("procedure_completed_by_exact_receipts", process.status == "closed"
    and commitment.status == "completed")
local learning = organization.fulfilledWorkOutcome(helper,
    __person.fulfilledWorkSequence)
check("completed_watch_return_teaches_once", learning
    and learning.workKind == "watch-return"
    and learning.nativeReceiptId == retryRoute.id
    and #__objectiveLearning == 1
    and __objectiveLearning[1].receiptId == retryRoute.id)
organization.routeOutcome(commitment.id, "arrived", "duplicate")
check("returned_learning_not_replayed", #__objectiveLearning == 1)
check("direct_work_receipt_cannot_forge_report",
    organization.recordObjectiveWorkReport(process.id, helper,
        "player:operator") == nil)
local publicCompleted = objectives.review(player, helper)
check("inspection_does_not_deliver_or_record_work_report",
    publicCompleted.workReportDelivered == false
    and organization.objectiveReportFor(process.id, helper,
        "player:operator") == nil)
acceptedMenu.options["Review marked-place request"]()
publicCompleted = objectives.review(player, helper)
check("returned_helper_delivers_exact_work_report",
    publicCompleted.workReportDelivered == true
    and publicCompleted.workReportStatus == "completed"
    and publicCompleted.steps == nil
    and string.find(objectives.describe(publicCompleted), "Returned", 1, true)
        ~= nil)
local savedReport = organization.objectiveReportFor(process.id, helper,
    "player:operator")
check("reported_receipts_match_exact_native_work", savedReport
    and savedReport.outboundReceiptId == outRoute.id
    and savedReport.watchReceiptId == "posture/helper/1"
    and savedReport.returnReceiptId == retryRoute.id
    and savedReport.channel == "spoken")
check("report_id_alone_cannot_claim_player_review",
    organization.recordObjectivePlayerReview(process.id, helper,
        "player:operator", retryRoute.id) == nil)
check("wrong_return_receipt_cannot_claim_player_review",
    organization.recordObjectivePlayerReview(process.id, helper,
        "player:operator", backRoute.id, player) == nil)
local spoofPlayer = { getUsername = function() return "operator" end }
check("same_key_foreign_body_cannot_claim_player_review",
    organization.recordObjectivePlayerReview(process.id, helper,
        "player:operator", retryRoute.id, spoofPlayer) == nil)
local playerReview = organization.objectivePlayerReviewFor(process.id,
    helper, "player:operator")
check("explicit_player_review_binds_exact_delivered_report", playerReview
    and playerReview.processId == process.id
    and playerReview.revision == process.revision
    and playerReview.actorId == helper
    and playerReview.playerId == "player:operator"
    and playerReview.commitmentId == commitment.id
    and playerReview.returnReceiptId == retryRoute.id
    and playerReview.reportDeliveredAt == savedReport.deliveredAt
    and playerReview.attempts[1].status == "failed"
    and playerReview.attempts[3].status == "interrupted"
    and playerReview.attempts[4].status == "arrived")
check("player_review_does_not_invent_cost_or_training_admission",
    playerReview.injury == nil and playerReview.cost == nil
    and playerReview.trainingStatus == nil and playerReview.admission == nil)
check("player_review_does_not_replay_helper_experience",
    #__objectiveLearning == 1 and __objectiveLearning[1].actorId == helper)
local sameReport = objectives.review(player, helper)
check("returned_work_report_is_not_replayed", sameReport.workReportDelivered
    and organization.objectiveReportFor(process.id, helper,
        "player:operator").deliveredAt == savedReport.deliveredAt)
local reviewEventCount = #process.events
acceptedMenu.options["Review marked-place request"]()
check("duplicate_player_review_is_idempotent", #process.events
    == reviewEventCount
    and organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator").reviewedAt == playerReview.reviewedAt)
local reportKey = helper .. ":" .. tostring(process.revision)
process.objectiveWorkReports[reportKey].outboundReceiptId = "changed-outbound"
check("tampered_report_source_receipt_refused",
    organization.objectiveReportFor(process.id, helper,
        "player:operator") == nil)
process.objectiveWorkReports[reportKey].outboundReceiptId = outRoute.id
organization.workReceipts["procedure:posture/helper/1"].receiptId =
    "changed-watch"
check("tampered_watch_receipt_id_refuses_review",
    organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil)
organization.workReceipts["procedure:posture/helper/1"].receiptId =
    "posture/helper/1"
organization.workReceipts["route:" .. failedOutbound.id].status = "arrived"
local mismatchedAttempt = objectives.review(player, helper)
check("mismatched_attempt_receipt_is_excluded", mismatchedAttempt
    and #mismatchedAttempt.attempts == 3
    and mismatchedAttempt.attempts[1].id == outRoute.id
    and organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil)
organization.workReceipts["route:" .. failedOutbound.id].status = "failed"
process.objectiveWorkReports[reportKey].returnReceiptId = "changed-return"
check("changed_report_receipt_refuses_review_replay",
    organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil
    and organization.recordObjectivePlayerReview(process.id, helper,
        "player:operator", retryRoute.id, player) == nil)
process.objectiveWorkReports[reportKey].returnReceiptId = retryRoute.id
process.revision = process.revision + 1
check("changed_process_revision_refuses_review_replay",
    organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil
    and organization.recordObjectivePlayerReview(process.id, helper,
        "player:operator", retryRoute.id, player) == nil)
process.revision = process.revision - 1
process.originatorId = "other"
check("changed_player_binding_refuses_review_replay",
    organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator") == nil)
process.originatorId = "player:operator"
local function savedCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = savedCopy(item) end
    return copy
end
organization.processes[process.id] = savedCopy(process)
organization.workReceipts = savedCopy(organization.workReceipts)
check("player_review_survives_durable_process_rebind",
    organization.objectivePlayerReviewFor(process.id, helper,
        "player:operator").returnReceiptId == retryRoute.id)

__dropAfterFirst, __canCalls = true, 0
local unheardId = objectives.ask(player, helper)
local unheard = organization.processes[unheardId]
check("lost_delivery_retains_open_request", unheard and unheard.status == "open"
    and unheard.participants.helper.receptions["1"] == nil)
__dropAfterFirst, __canCalls = false, 0
check("unheard_request_has_no_commitment", #organization.activeCommitments(helper)
    == 0 and objectives.review(player, helper).response == "unanswered"
    and objectives.review(player, helper).requestReceived == nil)
local retriedId = objectives.ask(player, helper)
check("recovered_transport_reuses_open_request", retriedId == unheardId
    and #organization.processOrder == 2)
check("recovered_transport_forms_real_assent", unheard.participants.helper
    .responses["1"].delivered == true and #organization.activeCommitments(helper)
    == 1)

check("withdraw_recovered_request", objectives.withdraw(player, helper) == true)
__failAfterCanCalls, __canCalls = 3, 0
local unheardAnswerId = objectives.ask(player, helper)
local unheardAnswer = organization.processes[unheardAnswerId]
check("recipient_hears_unreturned_answer",
    unheardAnswer and unheardAnswer.participants.helper.receptions["1"]
        ~= nil and unheardAnswer.participants.helper.responses["1"]
        and unheardAnswer.participants.helper.responses["1"].delivered == false)
__failAfterCanCalls, __canCalls = nil, 0
local publicUnanswered = objectives.review(player, helper)
check("unreturned_answer_stays_private", publicUnanswered.response
    == "unanswered" and publicUnanswered.requestReceived == nil
    and publicUnanswered.workReportDelivered == false
    and objectives.describe(publicUnanswered)
        == "Request for square 12,0,0: no answer has returned.")

for slot = 1, 3 do
    __playerSlot = slot
    check("player_slot_" .. tostring(slot) .. "_resolves_supplied_body",
        communication.bodyFor("player:operator") == player)
    local repeatedId, repeated = objectives.ask(player, helper)
    check("player_slot_" .. tostring(slot) .. "_native_request",
        repeatedId == unheardAnswerId and repeated == "retried")
end
__playerSlot = 1
__duplicateSlot = 2
__duplicatePlayer = { getUsername = function() return "operator" end }
check("ambiguous_same_key_players_refused",
    communication.bodyFor("player:operator") == nil
    and objectives.ask(player, helper) == nil)
__duplicatePlayer, __duplicateSlot = nil, nil
__playerSlot = 0
__player.observer = true
check("observer_slot_refused", communication.bodyFor("player:operator")
    == nil and objectives.ask(player, helper) == nil)
__player.observer = nil

SandboxVars = { SurvivorAwareness = { NeighbourBridge = true } }
local actor = { isAlive = function() return true end,
    getX = function() return 0 end, getY = function() return 0 end }
KnoxSurvivors = { RUNTIME = { actors = { actor } },
    GetActorId = function() return 7 end,
    GetActorProfile = function() return { name = "Mara" } end }
local worldobjects = { { getSquare = function() return __square(0, 0, 0) end } }
local missingRoot = { getOptionFromName = function() return nil end }
check("missing_neighbour_root_fallback",
    SAO.Neighbours.willSuperimpose("ks:7", worldobjects,
        missingRoot) == false)
local root = { subOption = 3 }
local originalRoot = {
    getOptionFromName = function(_, title)
        return title == "Mara - Talk / Ask Along" and root or nil
    end,
    getSubMenu = function() return {} end,
}
check("present_neighbour_root_superimposes",
    SAO.Neighbours.willSuperimpose("ks:7", worldobjects,
        originalRoot) == true)
local missingSubmenu = {
    getOptionFromName = originalRoot.getOptionFromName,
    getSubMenu = function() return nil end,
}
check("missing_neighbour_submenu_fallback",
    SAO.Neighbours.willSuperimpose("ks:7", worldobjects,
        missingSubmenu) == false)

print("PASS player objectives " .. tostring(__checks))
__result = __checks
