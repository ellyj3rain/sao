check("ordinary_gesture_starts_real_native_action", function()
    fresh()
    local admitted = SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
    local row = ISTimedActionQueue.queues[__cook]
    return admitted and SAO.Needs.busy(__cook) and #row.queue == 1
        and __cook:getCharacterActions():get(0):getTable() == row.queue[1]
        and row.queue[1].Type == "SAOGestureAction"
end)
check("idle_cooking_resists_other_person_meeting", function()
    local rec = fresh()
    if not SAO.Cooking.begin("cook", __cook) then error("native cooking begin refused") end
    local work = rec.cookingWork
    SAO.Exchange.betweenPair("speaker", SAO.Controller.agents.speaker, __speaker, "cook", __cook, 46)
    local result = SAO.Cooking.tick("cook", __cook)
    return SAO.Needs.busy(__speaker) and not SAO.Needs.busy(__cook)
        and rec.cookingWork == work and result == "transfer" and transferCount() == 1
        and rec.cookingOutcomes == nil
end)
check("cook_state_resists_other_person_meeting", function()
    local rec = fresh(); assert(SAO.Cooking.begin("cook", __cook))
    SAO.Controller.agents.cook.state = "COOK"
    SAO.Exchange.betweenPair("speaker", SAO.Controller.agents.speaker, __speaker, "cook", __cook, 46)
    return SAO.Cooking.tick("cook", __cook) == "transfer" and rec.cookingWork ~= nil
end)
check("source_owner_gap_rejects_social_gesture", function()
    local rec = fresh(); rec.worldSourceReservation = "reserved-with-no-native-action"
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and __cook:getCharacterActions():isEmpty() and rec.worldSourceReservation ~= nil
end)
check("source_reconciliation_allows_later_gesture", function()
    local rec = fresh(); rec.worldSourceReservation = "reserved"
    SAO.SourceUse.closeForOwnershipTransfer("cook", __cook)
    return SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and SAO.Needs.busy(__cook)
end)
check("external_owner_rejects_unsolicited_gesture", function()
    local rec = fresh(); rec.bodyOwner = "ZAO"
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and __cook:getCharacterActions():isEmpty() and rec.bodyOwner == "ZAO"
        and (not ISTimedActionQueue.queues[__cook] or #ISTimedActionQueue.queues[__cook].queue == 0)
end)
check("external_native_mark_rejects_gesture", function()
    fresh(); __cook:getModData().SAOExternalOwner = "ZAO"
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and __cook:getCharacterActions():isEmpty()
        and __cook:getModData().SAOExternalOwner == "ZAO"
end)
check("external_native_owned_flag_rejects_gesture", function()
    fresh(); __cook:getModData().ZAOOwned = true
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and __cook:getCharacterActions():isEmpty() and __cook:getModData().ZAOOwned == true
end)
check("pending_handoff_rejects_gesture", function()
    local rec = fresh(); rec.zaoTransferPending = {}
    local pending = rec.zaoTransferPending
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and __cook:getCharacterActions():isEmpty() and rec.zaoTransferPending == pending
end)
check("pending_crossed_handoff_rejects_gesture", function()
    local rec = fresh(); rec.crossedTransferPending = {}
    local pending = rec.crossedTransferPending
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and __cook:getCharacterActions():isEmpty() and rec.crossedTransferPending == pending
end)
check("lua_queued_action_gap_rejects_gesture", function()
    fresh(); local queue = ISTimedActionQueue.getTimedActionQueue(__cook)
    local pending = SAOGestureAction:new(__cook, "Converse_ArmForward", 60)
    queue.queue = { pending }
    return not SAO.Needs.busy(__cook)
        and not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and #queue.queue == 1 and queue.queue[1] == pending
end)
check("real_foreign_action_still_interrupts_cooking", function()
    local rec = fresh(); assert(SAO.Cooking.begin("cook", __cook))
    ISTimedActionQueue.add(SAOGestureAction:new(__cook, "Converse_Listening02", 60))
    return SAO.Needs.busy(__cook) and SAO.Cooking.tick("cook", __cook) == "interrupted"
        and rec.cookingOutcomes[1].detail == "different-native-action" and transferCount() == 0
end)
check("standup_cleanup_survives_work_owner", function()
    local rec = fresh(); rec.cookingWork = { id = "held" }
    __cook:setVariable("SAOSeat", "IsSittingLoop")
    return SAO.Gesture.standUp(__cook) and __cook:getVariableString("SAOSeat") ~= "IsSittingLoop"
end)
check("legitimate_cpr_keeps_three_native_queue_members", function()
    fresh(); SAO.Controller.agents.cook.state = "TREAT"
    return SAO.Gesture.cpr("cook", __cook)
        and #ISTimedActionQueue.queues[__cook].queue == 3 and SAO.Needs.busy(__cook)
end)
check("instrument_rest_gesture_still_admitted", function()
    fresh(); SAO.Controller.agents.cook.state = "REST"
    return SAO.Gesture.play("cook", __cook, "PlayGuitarDefault", 60) and SAO.Needs.busy(__cook)
end)
check("owned_work_blocks_native_emote", function()
    local rec = fresh(); rec.cookingWork = { id = "held" }
    return SAO.Gesture.onEvent("cook", "parting", 0) == false
end)
check("native_busy_still_refuses_second_gesture", function()
    fresh(); assert(SAO.Gesture.play("cook", __cook, "Converse_ArmForward", 60))
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
        and #ISTimedActionQueue.queues[__cook].queue == 1
end)
check("sleeping_body_still_refuses", function()
    fresh(); __cook:setAsleep(true)
    return not SAO.Gesture.play("cook", __cook, "Converse_Listening02", 60)
end)
