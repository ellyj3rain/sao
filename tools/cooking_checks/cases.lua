case("queued_deposit_has_no_cooked_write_or_credit", function()
    newFixture() beginCooking() local status = tickCooking()
    return status == "transfer" and not F.food.cooked and F.xp == 0 and F.creditCalls == 0
        and F.food.container == F.inventory and F.rec.cookingWork ~= nil
end)
case("physical_deposit_requires_personal_inspection", function()
    newFixture() beginCooking() tickCooking()
    return F.inspected == 1 and F.inspectionSource == "oven-1" and F.transferCalls == 1
end)
case("inspection_refusal_prevents_transfer", function()
    newFixture() F.inspectRefused = true beginCooking() tickCooking()
    return F.transferCalls == 0 and lastOutcome().status == "unavailable"
end)
case("physical_deposit_has_no_cooked_write", function()
    newFixture() beginCooking() tickCooking() settleTransfer()
    return F.food.container == F.container and not F.food.cooked and F.xp == 0
end)
case("native_toggle_completion_owns_activation", function()
    newFixture() beginCooking() tickCooking() local waiting = settleTransfer()
    local before = not F.stove.active and F.queueCalls == 1 and F.stove.toggleCalls == 0
    local pending = tickCooking()
    local completed = completeToggle()
    return waiting == "switching-appliance" and before and pending == "switching-appliance"
        and completed and F.stove.active and F.stove.toggleCalls == 1 and tickCooking() == "heating"
end)
case("native_progression_retrieval_and_shutdown_complete", function()
    newFixture() heatSetup() nativeCooked() local retrieve = tickCooking()
    local stillOwned = F.rec.cookingWork ~= nil and F.food.container == F.container
    local shutdown = settleTransfer() local wasActive = F.stove.active
    local done = completeToggle() local terminal = tickCooking() local receipt = lastOutcome()
    local again = tickCooking()
    return retrieve == "transfer" and stillOwned and shutdown == "switching-appliance" and wasActive
        and done and terminal == "completed" and again == false and F.food.container == F.inventory
        and not F.stove.active and F.stove.toggleCalls == 2 and F.xp == 10 and F.creditCalls == 1
        and receipt.heatObserved and receipt.retrieved and receipt.nativeCredit == receipt.id
        and receipt.sequence == 1 and receipt.id == "cooking/cook-a/1"
        and receipt.beforeCookingTime == 0 and receipt.afterCookingTime == 51 and receipt.shutdown == "off"
end)
case("fake_cooked_flag_cannot_finish", function()
    newFixture() heatSetup() F.food.cooked = true tickCooking()
    return lastOutcome().status == "unavailable" and lastOutcome().detail == "thermal-progression-not-observed"
        and F.xp == 0 and F.food.container == F.container
end)
case("native_completion_refusal_cannot_report_success", function()
    newFixture() heatSetup() nativeCooked() F.creditRefused = true tickCooking()
    return lastOutcome().status == "unavailable" and F.xp == 0 and F.transferCalls == 1
end)
case("thermal_actor_mismatch_refused", function()
    newFixture() heatSetup() nativeCooked() F.creditChanges = { actorId = "other" } tickCooking()
    return lastOutcome().status == "unavailable" and F.transferCalls == 1
end)
case("thermal_work_mismatch_refused", function()
    newFixture() heatSetup() nativeCooked() F.creditChanges = { workId = "other" } tickCooking()
    return lastOutcome().status == "unavailable" and F.transferCalls == 1
end)
case("thermal_item_mismatch_refused", function()
    newFixture() heatSetup() nativeCooked() F.creditChanges = { itemId = 72 } tickCooking()
    return lastOutcome().status == "unavailable" and F.transferCalls == 1
end)
case("unbound_native_replacement_remains_unknown", function()
    newFixture() heatSetup() F.thermalLost = true tickCooking()
    return lastOutcome().status == "unavailable" and lastOutcome().detail == "native-food-result-unbound"
        and F.xp == 0 and F.transferCalls == 1
end)
case("burnt_result_has_no_completion", function()
    newFixture() heatSetup() F.food.burnt = true tickCooking()
    return lastOutcome().status == "no-effect" and F.creditCalls == 0 and F.xp == 0
end)
case("unpowered_stove_has_no_queued_toggle", function()
    newFixture() F.stove.powered = false beginCooking() tickCooking() settleTransfer()
    return lastOutcome().status == "no-effect" and F.queueCalls == 0 and not F.food.cooked
end)
case("unlit_fireplace_has_no_fabricated_fire", function()
    newFixture() F.appliance.kind = "fireplace" beginCooking() tickCooking() settleTransfer()
    return lastOutcome().status == "no-effect" and F.queueCalls == 0 and F.stove.toggleCalls == 0
end)
case("unowned_prior_active_stove_remains_on", function()
    newFixture() F.stove.active = true beginCooking() tickCooking()
    assert(settleTransfer() == "heating") nativeCooked() tickCooking() local result = settleTransfer()
    return result == "completed" and F.stove.active and F.queueCalls == 0
        and lastOutcome().shutdown == "prior-state-preserved"
end)
case("another_meal_prevents_owned_shutdown", function()
    newFixture() heatSetup() nativeCooked() tickCooking()
    local other = { isCookable = function() return true end, isBurnt = function() return false end }
    F.transferReady = { move = true }
    SAO.SourceUse.tick(F.rec.id, F.body) F.container.items.values = { other }
    local result = tickCooking()
    return result == "completed" and F.stove.active and F.queueCalls == 1 and lastOutcome().shutdown == "shared-use"
end)
case("failed_shutdown_queue_is_not_success", function()
    newFixture() heatSetup() nativeCooked() tickCooking() F.queueAccept = false local result = settleTransfer()
    return result == "interrupted" and F.stove.active and lastOutcome().status == "interrupted"
end)
case("failed_native_shutdown_is_not_success", function()
    newFixture() heatSetup() nativeCooked() tickCooking() settleTransfer() F.stove.refuseToggle = true
    local completed = completeToggle() local result = tickCooking()
    return not completed and result == "interrupted" and F.stove.active and lastOutcome().status == "interrupted"
end)
case("activation_queue_refusal_is_not_heating", function()
    newFixture() F.queueAccept = false beginCooking() tickCooking() local result = settleTransfer()
    return result == "no-effect" and F.stove.toggleCalls == 0 and F.xp == 0
end)
case("lost_toggle_queue_cannot_keep_ownership", function()
    newFixture() beginCooking() tickCooking() settleTransfer()
    local own = F.action ISTimedActionQueue.queues[F.body].queue = { {} } F.busy = true
    local result = tickCooking()
    return result == "interrupted" and own.saoCancelled and not own:complete() and F.stove.toggleCalls == 0
end)
case("toggle_permission_rechecked_at_native_complete", function()
    newFixture() beginCooking() tickCooking() settleTransfer() F.allowed = false
    local completed = completeToggle() tickCooking()
    return not completed and F.stove.toggleCalls == 0 and lastOutcome().status == "interrupted"
end)
case("toggle_exact_body_rechecked_at_native_complete", function()
    newFixture() beginCooking() tickCooking() settleTransfer() local action = F.action
    action.character = { data = F.body.data, getModData = function(self) return self.data end }
    return not action:complete() and F.stove.toggleCalls == 0
end)
case("transfer_receipt_requires_actor", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { actorId = "other" })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_reservation", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { reservationId = "R:other" })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_source", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { sourceId = "other-oven" })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_operation", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { operation = "acquire" })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_item", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { itemId = 99 })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_item_type", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { itemType = "Base.OtherFood" })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_observed_effect", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { observedQuantity = 0 })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("transfer_receipt_requires_native_measurement", function()
    newFixture() beginCooking() tickCooking() settleTransfer(true, { measurement = "not-recorded" })
    return lastOutcome().status == "unavailable" and F.queueCalls == 0
end)
case("completed_receipt_requires_physical_item_transfer", function()
    newFixture() beginCooking() tickCooking() settleTransfer(false)
    return lastOutcome().status == "unavailable" and lastOutcome().detail == "transfer-not-observed"
        and F.queueCalls == 0 and F.food.container == F.inventory
end)
case("transfer_queue_refusal_ends_work_without_credit", function()
    newFixture() F.transferAccept = false beginCooking() tickCooking()
    return lastOutcome().status == "unavailable" and F.rec.worldSourceReservation == nil and F.xp == 0
end)
case("interruption_preserves_unreconciled_source_owner", function()
    newFixture() beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation
    local first = SAO.Cooking.interrupt(F.rec.id, F.body, "combat")
    local preserved = F.rec.cookingWork ~= nil and F.rec.worldSourceReservation == reservation and lastOutcome() == nil
    F.closeAccept = true local terminal = tickCooking()
    return not first and preserved and terminal == "interrupted" and F.closeCalls == 2
        and F.rec.worldSourceReservation == nil and lastOutcome().status == "interrupted"
end)
case("foreign_source_owner_is_not_closed", function()
    newFixture() heatSetup() F.rec.worldSourceReservation = "R:foreign" tickCooking()
    return lastOutcome().status == "interrupted" and F.rec.worldSourceReservation == "R:foreign" and F.closeCalls == 0
end)
case("foreign_route_prevents_admission", function()
    newFixture() local job = { body = F.body } SAO.Locomotion.jobs[F.rec.id] = job
    return not SAO.Cooking.begin(F.rec.id, F.body) and SAO.Locomotion.jobs[F.rec.id] == job and F.cancels == 0
end)
case("owned_route_does_not_replace_foreign_route", function()
    newFixture() F.applianceReachable = false beginCooking() assert(tickCooking() == "travelling")
    local foreign = { body = F.body } SAO.Locomotion.jobs[F.rec.id] = foreign tickCooking()
    return lastOutcome().status == "interrupted" and SAO.Locomotion.jobs[F.rec.id] == foreign
        and F.cancels == 0 and F.routeCalls == 1
end)
case("new_foreign_route_interrupts_stationary_cooking", function()
    newFixture() heatSetup() local foreign = { body = F.body }
    SAO.Locomotion.jobs[F.rec.id] = foreign tickCooking()
    return lastOutcome().status == "interrupted" and SAO.Locomotion.jobs[F.rec.id] == foreign and F.cancels == 0
end)
case("owned_route_arrives_before_deposit", function()
    newFixture() F.applianceReachable = false beginCooking() local first = tickCooking()
    local wasCarried = F.food.container == F.inventory and F.transferCalls == 0
    F.arrive = true local second = tickCooking()
    return first == "travelling" and wasCarried and second == "transfer" and F.cancels == 1
        and F.routeCalls == 1 and F.transferCalls == 1
end)
case("route_permission_refusal_does_not_order", function()
    newFixture() F.applianceReachable = false F.enter = false beginCooking() tickCooking()
    return lastOutcome().status == "unavailable" and F.routeCalls == 0
end)
case("world_food_acquires_before_deposit", function()
    newFixture(false) beginCooking() local first = tickCooking()
    local acquire = F.pendingTransfer.operation == "acquire" and F.pendingTransfer.sourceId == "fridge-1"
    local second = settleTransfer()
    return first == "transfer" and acquire and second == "transfer" and F.food.container == F.inventory
        and F.pendingTransfer.operation == "store" and F.inspected == 1
end)
case("current_permission_loss_closes_owned_transfer", function()
    newFixture() beginCooking() tickCooking() F.allowed = false tickCooking()
    return lastOutcome().status == "interrupted" and F.closeCalls == 1 and F.rec.worldSourceReservation == nil
end)
case("sleeping_body_cannot_begin", function()
    newFixture() F.body.sleeping = true return not SAO.Cooking.begin(F.rec.id, F.body) and F.rec.cookingWork == nil
end)
case("sleeping_body_interrupts_work", function()
    newFixture() heatSetup() F.body.sleeping = true tickCooking()
    return lastOutcome().status == "interrupted" and F.clears == 1 and F.creditCalls == 0
end)
case("stale_shell_cannot_begin", function()
    newFixture() local stale = { data = F.body.data, getModData = function(self) return self.data end }
    return not SAO.Cooking.begin(F.rec.id, stale)
end)
case("passive_sao_owner_cannot_begin", function()
    newFixture() SAO.Controller.agents[F.rec.id].passive = true return not SAO.Cooking.begin(F.rec.id, F.body)
end)
case("foreign_token_mismatch_cannot_begin", function()
    newFixture() F.rec.bodyOwner = "ZAO" F.rec.bodyOwnerToken = "new-token"
    SAO.Body.active[F.rec.id] = nil SAO.Body.foreign[F.rec.id] = F.body SAO.Controller.agents[F.rec.id] = nil
    ZAO.Controller.controlled[F.rec.id] = F.body F.body.data.SAOExternalOwner = "ZAO"
    F.body.data.SAOExternalToken = "old-token" F.body.data.ZAOOwned = true
    return not SAO.Cooking.begin(F.rec.id, F.body)
end)
case("exclusive_zao_human_body_may_begin", function()
    newFixture() F.rec.bodyOwner = "ZAO" F.rec.bodyOwnerToken = "token"
    SAO.Body.active[F.rec.id] = nil SAO.Body.foreign[F.rec.id] = F.body SAO.Controller.agents[F.rec.id] = nil
    ZAO.Controller.controlled[F.rec.id] = F.body F.body.data.SAOExternalOwner = "ZAO"
    F.body.data.SAOExternalToken = "token" F.body.data.ZAOOwned = true
    return SAO.Cooking.begin(F.rec.id, F.body) and F.rec.cookingWork.ownerName == "ZAO"
end)
case("owner_change_terminates_old_work", function()
    newFixture() heatSetup() F.rec.bodyOwnerToken = "changed" F.body.data.SAOExternalToken = "changed" tickCooking()
    return lastOutcome().status == "interrupted" and F.creditCalls == 0
end)
case("detached_body_refused", function()
    newFixture() F.body.attached = false return not SAO.Cooking.begin(F.rec.id, F.body)
end)
case("combat_body_refused", function()
    newFixture() F.body.attack = true return not SAO.Cooking.begin(F.rec.id, F.body)
end)
case("vehicle_body_refused", function()
    newFixture() F.body.vehicle = {} return not SAO.Cooking.begin(F.rec.id, F.body)
end)
case("load_clears_runtime_without_restored_success", function()
    newFixture() heatSetup() local work = F.rec.cookingWork
    for _, fn in ipairs(Events.OnGameStart.handlers) do fn() end
    local retained = F.rec.cookingWork == work and F.binding == nil
    tickCooking()
    return retained and lastOutcome().status == "interrupted" and F.xp == 0
        and lastOutcome().detail == "native-binding-unavailable"
end)
case("load_reconciles_persisted_transfer_before_exit", function()
    newFixture() beginCooking() tickCooking() F.closeAccept = false
    for _, fn in ipairs(Events.OnGameStart.handlers) do fn() end
    local first = tickCooking() local retained = F.rec.worldSourceReservation ~= nil and F.rec.cookingWork ~= nil
    F.closeAccept = true local second = tickCooking()
    return first == "reconciling" and retained and second == "interrupted" and F.closeCalls == 2 and F.xp == 0
end)
case("cancelled_toggle_cannot_fire_after_load", function()
    newFixture() beginCooking() tickCooking() settleTransfer() local action = F.action
    for _, fn in ipairs(Events.OnGameStart.handlers) do fn() end
    return action.saoCancelled and not action:complete() and F.stove.toggleCalls == 0
end)
case("expiry_cannot_create_completion", function()
    newFixture() heatSetup() F.at = 17 tickCooking()
    return lastOutcome().status == "unavailable" and lastOutcome().detail == "preparation-expired" and F.xp == 0
end)
case("durable_work_and_receipt_contain_only_primitives", function()
    newFixture() heatSetup()
    for _, value in pairs(F.rec.cookingWork) do if type(value) == "table" or type(value) == "userdata" then return false end end
    nativeCooked() tickCooking() settleTransfer() completeToggle() tickCooking()
    for _, value in pairs(lastOutcome()) do if type(value) == "table" or type(value) == "userdata" then return false end end
    return true
end)
case("death_detach_drops_runtime_with_unresolved_transfer", function()
    newFixture() beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation
    assert(not SAO.Cooking.interrupt(F.rec.id, F.body, "death"))
    F.busy = false ISTimedActionQueue.queues[F.body].queue = {} F.body.dead = true
    local released, state = SAO.Cooking.detach(F.rec.id, F.body, "death")
    local work = F.rec.cookingWork
    return released and state == "source-pending" and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil
        and work and work.detached and work.detachedAt == F.at and work.terminalStatus == "interrupted"
        and work.terminalReason == "death" and work.transferId == reservation
        and F.rec.worldSourceReservation == reservation and F.closeCalls == 1 and F.clears == 1
        and lastOutcome() == nil and F.xp == 0
end)
case("death_pending_marker_settles_as_interrupted_only", function()
    newFixture() beginCooking() tickCooking() F.closeAccept = false F.busy = false
    SAO.Cooking.detach(F.rec.id, F.body, "death")
    F.rec.worldSourceReservation = nil
    local result = tickCooking() local receipt = lastOutcome()
    return result == "interrupted" and receipt.status == "interrupted" and receipt.detached
        and not receipt.retrieved and receipt.nativeCredit == nil and F.xp == 0
end)
case("death_detach_clears_exact_thermal_binding", function()
    newFixture() heatSetup() F.body.dead = true
    local released, state = SAO.Cooking.detach(F.rec.id, F.body, "death")
    return released and state == "interrupted" and F.binding == nil and F.clears == 1
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and lastOutcome().status == "interrupted"
end)
case("death_detach_invalidates_pending_toggle", function()
    newFixture() beginCooking() tickCooking() settleTransfer() local action = F.action
    F.busy = false ISTimedActionQueue.queues[F.body].queue = {}
    SAO.Cooking.detach(F.rec.id, F.body, "identity-retired")
    return action.saoCancelled and not action:complete() and F.stove.toggleCalls == 0
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil
end)
case("detach_refuses_wrong_body_without_releasing_work", function()
    newFixture() heatSetup() local own = SAO.Cooking.__fixtureRuntime()[F.rec.id]
    local released, reason = SAO.Cooking.detach(F.rec.id, {}, "death")
    return not released and reason == "body-mismatch" and SAO.Cooking.__fixtureRuntime()[F.rec.id] == own
        and F.binding ~= nil and F.rec.cookingWork ~= nil and F.clears == 0
end)
case("detach_preserves_foreign_route_and_reservation", function()
    newFixture() F.applianceReachable = false beginCooking() tickCooking()
    local foreign = { body = F.body } SAO.Locomotion.jobs[F.rec.id] = foreign
    F.rec.worldSourceReservation = "R:foreign"
    SAO.Cooking.detach(F.rec.id, F.body, "death")
    return SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and SAO.Locomotion.jobs[F.rec.id] == foreign
        and F.rec.worldSourceReservation == "R:foreign" and F.cancels == 0 and F.closeCalls == 0
        and lastOutcome().status == "interrupted"
end)
case("identity_retirement_releases_missing_record_runtime", function()
    newFixture() heatSetup() local id, body = F.rec.id, F.body
    SAO.Identity.get = function() return nil end
    local released = SAO.Cooking.detach(id, body, "identity-retired")
    return released and F.binding == nil and F.clears == 1 and SAO.Cooking.__fixtureRuntime()[id] == nil
end)
case("detach_cleanup_failure_cannot_retain_body", function()
    newFixture() F.applianceReachable = false beginCooking() tickCooking()
    SAO.Locomotion.cancel = function() error("native movement unavailable") end
    local released = SAO.Cooking.detach(F.rec.id, F.body, "death")
    return released and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and F.clears == 1
        and lastOutcome().status == "interrupted"
end)
case("detach_does_not_retire_replacement_work", function()
    newFixture() heatSetup()
    local replacement = { id = "cooking/cook-a/new", transferId = "R:new" }
    F.rec.cookingWork = replacement F.rec.worldSourceReservation = "R:new"
    local released = SAO.Cooking.detach(F.rec.id, F.body, "death")
    return released and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and F.binding == nil
        and F.rec.cookingWork == replacement and replacement.terminalStatus == nil
        and F.rec.worldSourceReservation == "R:new" and F.closeCalls == 0
end)
case("repeated_detach_preserves_first_retirement_time", function()
    newFixture() beginCooking() tickCooking() F.closeAccept = false F.busy = false
    SAO.Cooking.detach(F.rec.id, F.body, "death") F.at = 11
    local released, state = SAO.Cooking.detach(F.rec.id, F.body, "death")
    return released and state == "source-pending" and F.rec.cookingWork.detachedAt == 10
        and F.closeCalls == 0 and F.clears == 1 and lastOutcome() == nil
end)
case("bumped_cook_reapproaches_same_heat_without_remote_read", function()
    newFixture() heatSetup()
    local work, binding, reads = F.rec.cookingWork, F.binding, F.thermalReads
    F.applianceReachable = false
    local first = tickCooking()
    local held = first == "travelling" and F.rec.cookingWork == work and F.binding == binding
        and F.routeCalls == 1 and F.routeTarget.x == 5 and F.routeTarget.y == 6
        and F.thermalReads == reads and F.creditCalls == 0 and F.transferCalls == 1 and F.clears == 0
    local again = tickCooking()
    F.arrive = true
    local returned = tickCooking()
    return held and again == "travelling" and returned == "heating" and F.routeCalls == 1
        and F.rec.cookingWork == work and work.stage == "heat" and F.binding == binding
        and F.food.container == F.container and lastOutcome() == nil
end)
case("reapproached_cooked_food_keeps_exact_retrieval_receipt", function()
    newFixture() heatSetup()
    local work = F.rec.cookingWork
    F.applianceReachable = false
    if tickCooking() ~= "travelling" then return false end
    nativeCooked() F.arrive = true
    local retrieving = tickCooking()
    local shutdown = settleTransfer()
    local closed = completeToggle() and tickCooking() == "completed"
    local receipt = lastOutcome()
    return retrieving == "transfer" and shutdown == "switching-appliance" and closed
        and receipt.id == work.id and receipt.itemId == 71 and receipt.retrieved
        and receipt.heatObserved and F.food.container == F.inventory and F.creditCalls == 1
end)
case("reach_repair_keeps_six_hour_budget", function()
    newFixture() heatSetup() F.applianceReachable = false
    if tickCooking() ~= "travelling" then return false end
    F.at = 16.1
    return tickCooking() == "unavailable" and lastOutcome().detail == "preparation-expired"
        and F.routeCalls == 1 and F.creditCalls == 0
end)
case("reach_repair_rechecks_private_permission", function()
    newFixture() heatSetup() F.applianceReachable = false
    if tickCooking() ~= "travelling" then return false end
    F.allowed = false
    return tickCooking() == "interrupted" and lastOutcome().detail == "current-appliance-permission-refused"
        and F.routeCalls == 1 and F.creditCalls == 0
end)
case("reach_repair_rejects_changed_appliance_identity", function()
    newFixture() heatSetup() F.applianceReachable = false F.approachSource = "replacement-oven"
    return tickCooking() == "unavailable" and lastOutcome().detail == "appliance-identity-changed"
        and F.routeCalls == 0 and F.creditCalls == 0
end)
case("reach_repair_rejects_relocated_source", function()
    newFixture() heatSetup() F.applianceReachable = false F.approachSourceX = 99
    return tickCooking() == "unavailable" and lastOutcome().detail == "appliance-identity-changed"
        and F.routeCalls == 0 and F.creditCalls == 0
end)
case("destroyed_appliance_cannot_be_reapproached", function()
    newFixture() heatSetup() F.stove.removed = true F.applianceReachable = false
    return tickCooking() == "interrupted" and lastOutcome().detail == "appliance-unavailable"
        and F.routeCalls == 0 and F.creditCalls == 0
end)
case("reach_repair_cannot_steal_foreign_route", function()
    newFixture() heatSetup() F.applianceReachable = false
    if tickCooking() ~= "travelling" then return false end
    local foreign = { body = F.body, done = false }
    SAO.Locomotion.jobs[F.rec.id] = foreign
    return tickCooking() == "interrupted" and lastOutcome().detail == "different-route-owner"
        and SAO.Locomotion.jobs[F.rec.id] == foreign and F.cancels == 0
end)
case("reach_repair_failed_path_has_no_completion", function()
    newFixture() heatSetup() F.applianceReachable = false F.routeAccept = false
    return tickCooking() == "unavailable" and lastOutcome().detail == "route-refused"
        and F.creditCalls == 0 and F.food.container == F.container
end)
__cookingResults = table.concat(__cookingCases, "\n")
