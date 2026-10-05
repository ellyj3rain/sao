check("native_metadata_includes_harmonica_not_weapon_or_whistle", function()
    fresh()
    local cap = SAO.Needs.instrumentCapability(__harmonica)
    return cap and cap.kind == "harmonica" and cap.radius == 45 and cap.sound == "BlowHarmonica"
        and SAO.Needs.instrumentCapability(__guitar) == nil and SAO.Needs.instrumentCapability(__whistle) == nil
end)
check("pure_carried_query_uses_exact_current_owner", function()
    local rec = fresh()
    local item, cap = SAO.Needs.carriedInstrument("person", __body)
    return item == __harmonica and cap.verb == "blow-harmonica" and rec.instrumentOutcomes == nil
        and __emitter:getPlayed() == 0 and __noiseCount() == 0
end)
check("installed_callout_confirms_same_native_sound_and_radius", function()
    fresh(); __body:setPrimaryHandItem(__harmonica); __body:Callout(false)
    return __emitter:getPlayed() == 1 and __noiseCount() == 1 and __noiseExact()
end)
check("another_person_or_stale_body_cannot_supply_instrument", function()
    fresh()
    return SAO.Needs.carriedInstrument("other", __body) == nil
        and SAO.Needs.carriedInstrument("person", __other) == nil
end)
check("unsupported_itemless_and_type_only_music_refused", function()
    fresh()
    return SAO.Gesture.playInstrument("person", __body, "guitar", nil) == false
        and SAO.Gesture.playInstrument("person", __body, "harmonica", "Base.Whistle", __harmonica) == false
        and __emitter:getPlayed() == 0
end)
check("native_cannot_shout_or_asleep_refuses", function()
    fresh(); __body:setCanShout(false)
    local blocked = SAO.Needs.carriedInstrument("person", __body) == nil
    __body:setCanShout(true); __body:setAsleep(true)
    return blocked and SAO.Needs.carriedInstrument("person", __body) == nil
end)
check("native_queue_admission_starts_sound_but_not_completion", function()
    local rec = fresh(); local action = queueBlow()
    local work = SAO.Gesture.instrumentWork("person")
    return action.action ~= nil and __body:getCharacterActions():contains(action.action)
        and __emitter:getPlayed() == 1 and rec.instrumentOutcomes == nil
        and work and work.admittedAtHours == 2 and work.sequence == 1
        and work.bodyGenerationKnown == false and work.bodyToken == nil
end)
check("actual_native_sound_and_world_stimulus_once", function()
    fresh(); local action = queueBlow(); action:start(); action:update()
    return __emitter:getPlayed() == 1 and __noiseCount() == 1 and __noiseExact()
        and SAO.Gesture.instrumentOutcome("person") == nil
end)
check("native_sound_end_owns_narrow_completion_no_social_reward", function()
    fresh(); SAO.Gesture.planReceipt("person", "purpose", "unconsenting-listener")
    local action = queueBlow(); action:start(); action:update(); __emitter:finish(); action:update(); action:perform()
    local result = SAO.Gesture.instrumentOutcome("person")
    return result and result.status == "completed" and result.verb == "blow-harmonica"
        and result.soundEmitted and result.worldSoundEmitted and result.itemType == "Base.Harmonica"
        and result.soundEnded == true and result.startedAtHours == 2 and result.endedAtHours == 2
        and #__results == 1 and __results[1].status == "completed"
end)
check("animation_or_early_perform_never_completes_sound", function()
    fresh(); local action = queueBlow(); action:perform()
    local result = SAO.Gesture.instrumentOutcome("person")
    return result and result.status == "interrupted" and result.soundEnded == false
        and result.endedAtHours == nil and __emitter:getStopped() == 1
end)
check("interruption_stops_exact_sound_retains_unrelated_sound", function()
    fresh(); local action = queueBlow(); action:start(); action:update()
    local unrelated = __emitter:playSound("unrelated-native-action")
    action:stop()
    local result = SAO.Gesture.instrumentOutcome("person")
    return result and result.status == "interrupted" and result.soundEmitted
        and __emitter:getStopped() == 1 and __emitter:isPlaying(unrelated)
end)
check("item_loss_after_admission_prevents_completion", function()
    fresh(); local action = queueBlow()
    __body:getInventory():Remove(__harmonica); __other:getInventory():AddItem(__harmonica)
    __body:getInventory():AddItem(__whistle)
    local valid = action:isValid()
    action:update(); action:stop()
    return not valid and __emitter:getStopped() == 1
        and SAO.Gesture.instrumentOutcome("person").status == "interrupted"
end)
check("generation_loss_retires_only_own_sound_without_record_credit", function()
    local rec = fresh(); local action = queueBlow(); action:start(); action:update()
    local unrelated = __emitter:playSound("future-owner")
    rec.bodyOwnerToken = "changed"; __body:getModData().SAOExternalToken = "changed"
    for _, callback in ipairs(__ticks) do if callback ~= ISTimedActionQueue.onTick then callback() end end
    action:perform()
    return __emitter:getStopped() == 1 and __emitter:isPlaying(unrelated) and rec.instrumentOutcomes == nil
end)
check("sound_refusal_cannot_grant_completed_use", function()
    fresh(); __emitter:setRefuse(true); local action = queueBlow(); action:start(); action:perform()
    return SAO.Gesture.instrumentOutcome("person").status == "interrupted" and __noiseCount() == 0
end)
check("module_reload_cancels_sound_and_preserves_detached_outcome", function()
    local rec = fresh(); local action = queueBlow(); action:start(); action:update()
    __reloadGesture()
    local result = SAO.Gesture.instrumentOutcome("person")
    if not result then return false end
    result.status = "invented"
    return __emitter:getStopped() == 1 and rec.instrumentOutcomes[1].status == "interrupted"
        and SAO.Gesture.instrumentOutcome("person").status == "interrupted"
end)
check("prepared_purpose_precedes_inline_native_failure", function()
    fresh(); __emitter:setRefuse(true)
    SAO.Gesture.playInstrument("person", __body, "harmonica", "Base.Harmonica", __harmonica, "purpose")
    local result = SAO.Gesture.instrumentOutcome("person", 1)
    return __admission and __admission.status == "prepared" and __admission.queueAdmitted == false
        and result and result.status == "interrupted" and result.workId == __admission.workId
        and #__physical == 1 and __physical[1].admitted and #__cognitive == 1
end)
check("refused_purpose_never_reaches_native_sound", function()
    fresh(); __rejectAdmission = true
    local admitted = SAO.Gesture.playInstrument("person", __body, "harmonica", "Base.Harmonica", __harmonica, "wrong-purpose")
    return not admitted and __emitter:getPlayed() == 0 and __noiseCount() == 0
        and SAO.Gesture.instrumentOutcome("person") == nil and SAO.Gesture.instrumentWork("person") == nil
end)
check("world_stimulus_exception_stops_started_sound", function()
    fresh(); local native = getWorldSoundManager
    getWorldSoundManager = function() error("controlled native world stimulus fault") end
    local ok = pcall(function() queueBlow() end)
    getWorldSoundManager = native
    local result = SAO.Gesture.instrumentOutcome("person", 1)
    return ok and result and result.status == "interrupted" and not result.worldSoundEmitted
        and __emitter:getPlayed() == 1 and __emitter:getStopped() == 1
end)
check("playback_query_exception_stops_exact_sound", function()
    fresh(); local action = queueBlow(); __emitter:setPlayingFault(true); action:update()
    __emitter:setPlayingFault(false)
    local result = SAO.Gesture.instrumentOutcome("person", 1)
    return result and result.status == "interrupted" and __emitter:getStopped() == 1
end)
check("failed_cleanup_is_interrupted_and_retries_only_owned_handle", function()
    fresh(); local action = queueBlow(); action:update()
    local other = __emitter:playSound("another-action")
    __emitter:setStopFault(true); action:stop()
    local result = SAO.Gesture.instrumentOutcome("person", 1)
    __emitter:setStopFault(false)
    for _, callback in ipairs(__ticks) do if callback ~= ISTimedActionQueue.onTick then callback() end end
    return result and result.status == "interrupted" and result.cleanupPending
        and __emitter:getStopped() == 1 and __emitter:isPlaying(other)
end)
check("exact_terminal_lookup_keeps_distinct_repeated_attempts", function()
    local rec = fresh(); local action = queueBlow(); action:stop()
    __body:getCharacterActions():clear()
    action = queueBlow(); action:update(); __emitter:finish(); action:update(); action:perform()
    local first = SAO.Gesture.instrumentOutcome("person", 1)
    local second = SAO.Gesture.instrumentOutcome("person", "instrument:person:2")
    return first and second and first.status == "interrupted" and second.status == "completed"
        and second.queueAdmitted and second.sequence == 2 and SAO.Gesture.nextInstrumentSequence("person") == 3
        and SAO.Gesture.instrumentOutcome("foreign", 2) == nil and SAO.Gesture.instrumentOutcome("person", 3) == nil
        and #rec.instrumentOutcomes == 2
end)
check("native_person_serialization_retains_exact_terminal_without_replaying_sound", function()
    fresh(); local action = queueBlow(); action:update(); __emitter:finish(); action:update(); action:perform()
    local played = __emitter:getPlayed()
    local rec = __roundTrip(__records.person); __records.person = rec; SAO.Controller.agents.person.rec = rec
    __reloadGesture()
    local result = SAO.Gesture.instrumentOutcome("person", "instrument:person:1")
    return result and result.status == "completed" and result.soundEnded and result.queueAdmitted
        and result.bodyGenerationKnown == false and result.bodyToken == nil
        and result.admittedAtHours == 2 and result.endedAtHours == 2
        and SAO.Gesture.instrumentWork("person") == nil and SAO.Gesture.nextInstrumentSequence("person") == 2
        and __emitter:getPlayed() == played
end)
check("pending_cleanup_retires_after_detach_without_touching_successor", function()
    local rec = fresh(); local action = queueBlow(); action:update()
    __emitter:setStopFault(true); action:stop(); __emitter:setStopFault(false)
    SAO.Body.active.person = nil
    for _, callback in ipairs(__ticks) do if callback ~= ISTimedActionQueue.onTick then callback() end end
    SAO.Body.active.person = __body
    __body:getCharacterActions():clear()
    local native = __emitter:getPlayed()
    action = queueBlow()
    return __emitter:getStopped() == 0 and __emitter:getPlayed() == native + 1
        and rec.instrumentOutcomes[1].cleanupPending and rec.instrumentOutcomes[1].status == "interrupted"
end)
