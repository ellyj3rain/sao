(function()
    local P, K = SAO.Perception, SAO.Knowledge
    local results = {}
    local function check(name, value)
        __deliveryKnowledgeLast = name
        results[#results + 1] = name .. "=" .. tostring(value == true)
    end
    local function reset()
        P.beliefs, P.beliefVersion = {}, 0
        __now, __canConverse, __socialWrites = 100, true, 0
        __factors, __trust, __persisted = {}, {}, {}
        __traitUnits = {}
        __communicationPresent = true
    end
    local function receipt(eventId, at, actor, witnesses)
        return { reservationId = eventId or "transfer-1", actorId = actor or "ada",
            operation = "store", status = "completed", category = "food",
            itemType = "Base.Apple", itemId = "private-native-item",
            sourceId = "C:pantry:0", placeId = "building-1",
            sourceX = 10, sourceY = 12, sourceZ = 0, at = at or __now,
            transferPurpose = "delivery", deliveryGroup = "recipient-house",
            requestedByGroup = "recipient-house", itemPoison = 99,
            itemSignature = "private-signature", sourceFingerprint = "private-fingerprint",
            inventory = { "private contents" },
            transferObservation = { actorId = actor or "ada", at = at or __now,
                nativeTransferProven = true,
                x = 10, y = 12, z = 0,
                witnesses = witnesses or { "bea" } } }
    end
    local function fact(person, eventId, at)
        return P.transferFact(person, eventId or "transfer-1", at)
    end
    local function remembered(person, eventId, at)
        local value = fact(person, eventId, at)
        return value and value.state == "remembered"
    end
    local function countKeys(value)
        local count = 0
        for _ in pairs(value or {}) do count = count + 1 end
        return count
    end
    local function transferClaim(person, topic, opts)
        for _, value in ipairs(K.about(person, topic or "food", opts) or {}) do
            if value.fact == "transfer" then return value end
        end
        return nil
    end

    reset()
    local result = receipt()
    local ok = P.receiveTransferResult(result)
    local actor, witness = fact("ada"), fact("bea")
    check("performed_and_observed", ok and actor and witness
        and actor.source == "performed" and witness.source == "observed"
        and actor.actorId == "ada" and witness.actorId == "ada"
        and actor.originId == "ada" and witness.originId == "bea")
    check("private_witness_scope", fact("remote-leader") == nil
        and fact("other-member") == nil and P.beliefs["remote-leader"] == nil)
    check("neutral_visible_fields", witness and witness.itemType == "Base.Apple"
        and witness.category == "food" and witness.operation == "store"
        and witness.sourceId == "C:pantry:0" and witness.x == 10
        and witness.y == 12 and witness.z == 0 and witness.placeId == "building-1"
        and witness.itemId == nil and witness.itemPoison == nil
        and witness.itemSignature == nil and witness.sourceFingerprint == nil
        and witness.inventory == nil and witness.transferPurpose == nil
        and witness.deliveryGroup == nil and witness.requestedByGroup == nil)
    check("no_source_inventory_or_social_effect", P.beliefs.bea.known == nil
        and countKeys(P.beliefs.bea.factions) == 0 and __socialWrites == 0)
    actor.actorId, witness.itemType = "tampered", "invented"
    result.itemType, result.transferObservation.witnesses[1] = "changed", "other-member"
    check("receipt_and_reader_detached", fact("ada").actorId == "ada"
        and fact("bea").itemType == "Base.Apple" and fact("other-member") == nil)
    local version = P.beliefVersion
    __now = 106
    local again = receipt("transfer-1", 100)
    check("duplicate_preserves_acquisition", P.receiveTransferResult(again)
        and fact("ada").acquiredAt == 100 and fact("bea").acquiredAt == 100
        and P.beliefVersion == version)
    again.itemType = "Base.Banana"
    local conflict, reason = P.receiveTransferResult(again)
    check("conflicting_identity_refused", not conflict and reason == "conflicting-event"
        and fact("ada").itemType == "Base.Apple")

    reset()
    local bad = receipt()
    bad.status = "pending"
    check("unperformed_result_refused", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad.transferObservation = nil
    check("pending_without_observation_refused", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.transferObservation.nativeTransferProven = nil
    local unproved = P.receiveTransferResult(bad) == false
    bad.status = "conflict"
    check("unproved_observation_refused", unproved and P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.operation = "consume"
    check("consume_not_transfer_memory", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.transferObservation = nil
    check("legacy_no_witness_invention", P.receiveTransferResult(bad) == true
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.transferObservation.actorId = "someone-else"
    check("actor_binding_refused", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.transferObservation.witnesses = { "bea", false }
    check("invalid_witness_atomic_refusal", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.transferObservation.at = 101
    check("future_event_refused", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.transferObservation.z = 0 / 0
    check("invalid_coordinate_refused", P.receiveTransferResult(bad) == false
        and countKeys(P.beliefs) == 0)
    bad = receipt(); bad.operation = "acquire"; bad.category = "water"
    check("acquire_water_supported", P.receiveTransferResult(bad)
        and fact("bea").operation == "acquire" and fact("bea").category == "water")

    reset()
    local terminalFacts = true
    for _, status in ipairs({"conflict", "released", "interrupted"}) do
        local observed = receipt(status)
        observed.status = status
        terminalFacts = terminalFacts and P.receiveTransferResult(observed)
            and fact("bea", status) ~= nil and observed.status == status
    end
    check("proved_terminal_observation_retained", terminalFacts and __socialWrites == 0)

    reset()
    P.receiveTransferResult(receipt())
    __now = 105
    local moved = P.tell("bea", "cy", 945000, true)
    local told = fact("cy")
    check("testimony_preserves_event_and_origin", moved == 1 and told
        and told.source == "told" and told.teller == "bea"
        and told.actorId == "ada" and told.eventAt == 100
        and told.acquiredAt == 105 and told.originId == "bea"
        and told.originSource == "observed" and told.originAcquiredAt == 100)
    __now = 106
    P.tell("cy", "dee", 954000, true)
    local retold = fact("dee")
    check("retelling_keeps_immediate_teller", retold and retold.teller == "cy"
        and retold.originId == "bea" and retold.actorId == "ada"
        and retold.eventAt == 100 and retold.acquiredAt == 106)
    __now = 107
    P.tell("dee", "cy", 963000, true)
    check("testimony_cycle_no_refresh", fact("cy").acquiredAt == 105
        and fact("cy").eventAt == 100 and fact("cy").teller == "bea")
    P.tell("dee", "bea", 963000, true)
    check("told_never_overwrites_firsthand", fact("bea").source == "observed"
        and fact("bea").acquiredAt == 100 and fact("bea").teller == nil)
    local firsthand = receipt("transfer-1", 100, "ada", { "cy" })
    P.receiveTransferResult(firsthand)
    check("captured_firsthand_supersedes_testimony", fact("cy").source == "observed"
        and fact("cy").acquiredAt == 100 and fact("cy").originId == "cy"
        and fact("cy").teller == nil)

    __canConverse = false
    check("physical_conversation_required", P.tell("bea", "far-away", 963000, true) == 0
        and fact("far-away") == nil)
    __canConverse = true; __communicationPresent = false
    check("missing_communication_fails_closed", P.tell("bea", "unchecked", 963000, true) == 0
        and fact("unchecked") == nil)
    __communicationPresent = true
    __trust["skeptic|bea"] = -0.3
    check("listener_skepticism_preserved", P.tell("bea", "skeptic", 963000, true) == 0
        and fact("skeptic") == nil)
    __trust["bea|stranger"] = 0
    check("speaker_trust_preserved", P.tell("bea", "stranger", 963000, false) == 0
        and fact("stranger") == nil)
    __lastChannel = nil
    P.tell("bea", "dormant-peer", 963000, true, "dormant-encounter")
    check("conversation_channel_forwarded", __lastChannel == "dormant-encounter"
        and remembered("dormant-peer"))

    P.beliefs.reporter = { zombies = {}, people = {}, factions = {}, places = {} }
    P.beliefs.listener = { zombies = {}, people = {}, factions = {}, places = {} }
    P.beliefs.unrelated = { zombies = {}, people = {}, factions = {}, places = {} }
    P.receiveTransferResult(receipt("report-1", 100, "ada", { "reporter" }))
    check("return_report_grounded", P.reportReturn("reporter", "listener", 963000,
        10, 12) == 1 and remembered("listener", "report-1")
        and P.reportReturn("reporter", "unrelated", 963000, 1000, 1000) == 0
        and fact("unrelated", "report-1") == nil)
    P.beliefs.echo = { zombies = {}, people = {}, factions = {}, places = {} }
    check("return_report_firsthand_only", P.reportReturn("listener", "echo", 963000,
        10, 12) == 0 and fact("echo", "report-1") == nil)
    __canConverse = false
    check("return_report_channel_required", P.reportReturn("reporter", "echo", 963000,
        10, 12) == 0 and fact("echo", "report-1") == nil)
    __canConverse = true

    reset()
    P.receiveTransferResult(receipt())
    __now = 110
    __factors.bea = 0.5
    check("episode_outlives_position_sighting", remembered("ada")
        and P.hasAnythingToPass("ada", 990000))
    __now = 269
    local lost = fact("bea")
    check("person_specific_retention", remembered("ada") and lost
        and lost.state == "forgotten" and lost.actorId == nil
        and lost.itemType == nil and countKeys(lost) == 2)
    check("forgotten_not_told_or_claimed", not P.hasAnythingToPass("bea", 2421000)
        and P.tell("bea", "cy", 2421000, true) == 0
        and transferClaim("bea") == nil)
    __now = 437
    check("event_age_never_rejuvenated", fact("ada").state == "forgotten"
        and P.tell("ada", "late", 3933000, true) == 0
        and not P.hasAnythingToPass("ada", 3933000))
    local before = P.beliefVersion
    local unknown, availability = P.transferFacts("unknown", 437)
    check("unavailable_reader_is_read_only", #unknown == 0 and availability == "unavailable"
        and P.beliefs.unknown == nil and P.beliefVersion == before)
    check("past_view_excludes_future_acquisition", fact("ada", nil, 99).state == "unavailable")

    reset()
    __now = 200
    for i = 70, 1, -1 do
        P.receiveTransferResult(receipt(string.format("event-%03d", i), 100 + i, "ada", {}))
    end
    local bounded = P.transferFacts("ada")
    check("bounded_by_event_time", #bounded == 64 and countKeys(P.beliefs.ada.transfers) == 64
        and bounded[1].eventId == "event-007" and bounded[64].eventId == "event-070"
        and fact("ada", "event-006") == nil)
    P.receiveTransferResult(receipt("event-070a", 170, "ada", {}))
    local ordered = P.transferFacts("ada")
    check("deterministic_equal_time_order", #ordered == 64
        and ordered[63].eventId == "event-070" and ordered[64].eventId == "event-070a")

    reset()
    P.receiveTransferResult(receipt())
    __now = 104
    P.tell("bea", "cy", 936000, true)
    __persisted = P.beliefs
    P.beliefs = {}
    local bound = P.bindPersistentStore()
    __now = 105
    P.receiveTransferResult(receipt("transfer-1", 100))
    check("persistent_bind_preserves_episode", bound and remembered("cy")
        and fact("cy").acquiredAt == 104 and fact("cy").eventAt == 100
        and fact("ada").acquiredAt == 100)
    local claim = transferClaim("cy", "food", { nowHours = 105 })
    check("knowledge_food_provenance", claim and claim.source == "told"
        and claim.teller == "bea" and claim.actorId == "ada"
        and claim.originId == "bea" and claim.eventAt == 100
        and claim.acquiredAt == 104 and claim.ageHours == 5
        and claim.itemType == "Base.Apple" and claim.transferPurpose == nil
        and claim.itemPoison == nil and claim.x == nil)
    claim.itemType = "changed"
    check("knowledge_read_only_detached", transferClaim("cy").itemType == "Base.Apple"
        and fact("cy").itemType == "Base.Apple")
    check("knowledge_topic_and_time_separation", transferClaim("cy", "water") == nil
        and transferClaim("cy", "food", { tick = 103 * 9000 }) == nil)
    local water = receipt("water-1", 105, "ada", { "bea" })
    water.category, water.operation, water.itemType = "water", "acquire", "Base.WaterBottle"
    P.receiveTransferResult(water)
    check("knowledge_water_supported", transferClaim("bea", "water").itemType == "Base.WaterBottle")
    check("no_relationship_policy_created", __socialWrites == 0)

    reset()
    local frozen = receipt()
    frozen.sourceX, frozen.sourceY, frozen.sourceZ = 900, 901, 2
    frozen.transferObservation.appraisals = { bea = { pressure = 0.8, reciprocity = 0.4 } }
    P.receiveTransferResult(frozen)
    check("observation_position_frozen", fact("bea").x == 10
        and fact("bea").y == 12 and fact("bea").z == 0)
    check("private_own_appraisal", fact("bea").appraisal.pressure == 0.8
        and fact("bea").appraisal.reciprocity == 0.4 and fact("ada").appraisal == nil
        and P.reciprocityToward("bea", "ada") == 0.4
        and P.reciprocityToward("bea", "someone-else") == 0)
    local private = fact("bea")
    private.appraisal.reciprocity = 1
    frozen.transferObservation.appraisals.bea.reciprocity = -1
    check("appraisal_detached", P.reciprocityToward("bea", "ada") == 0.4)
    P.tell("bea", "cy", 900000, true)
    check("appraisal_does_not_travel", fact("cy").appraisal == nil
        and P.reciprocityToward("cy", "ada") == 0
        and transferClaim("bea").appraisal == nil
        and transferClaim("bea").reciprocity == nil)
    local second = receipt("transfer-2")
    second.transferObservation.appraisals = { bea = { pressure = 0.5, reciprocity = 0.2 } }
    P.receiveTransferResult(second)
    local third = receipt("transfer-3")
    third.transferObservation.appraisals = { bea = { pressure = 0.8, reciprocity = -0.6 } }
    P.receiveTransferResult(third)
    check("reciprocity_strongest_without_accumulation", P.reciprocityToward("bea", "ada") == -0.6
        and __socialWrites == 0)
    __now = 437
    check("forgotten_appraisal_unavailable", P.reciprocityToward("bea", "ada") == 0
        and fact("bea").appraisal == nil)
    reset()
    local invalid = receipt()
    invalid.transferObservation.appraisals = { remote = { pressure = 1, reciprocity = 1 } }
    local refused = P.receiveTransferResult(invalid) == false and countKeys(P.beliefs) == 0
    invalid.transferObservation.appraisals = { ada = { pressure = 1, reciprocity = 1 } }
    refused = refused and P.receiveTransferResult(invalid) == false and countKeys(P.beliefs) == 0
    invalid.transferObservation.appraisals = { bea = { pressure = 1, reciprocity = 2 } }
    check("invalid_appraisal_atomic_refusal", refused and P.receiveTransferResult(invalid) == false
        and countKeys(P.beliefs) == 0)

    reset()
    __now = 200
    local older = receipt("old-event", 100, "old-actor", { "bea" })
    P.receiveTransferResult(older)
    for i = 1, 65 do
        P.receiveTransferResult(receipt("new-event-" .. tostring(i), 100 + i,
            "bulk-actor", { "bea" }))
    end
    local floor = P.beliefs.bea.transferFloor
    local floorVersion = P.beliefVersion
    P.tell("old-actor", "bea", 1800000, true)
    P.receiveTransferResult(older)
    check("evicted_event_cannot_return", floor and floor.eventAt >= 100
        and fact("bea", "old-event") == nil and #P.transferFacts("bea") == 64
        and P.beliefVersion == floorVersion)
    __persisted = P.beliefs; P.beliefs = {}; P.bindPersistentStore()
    P.tell("old-actor", "bea", 1800000, true)
    check("eviction_floor_survives_bind", fact("bea", "old-event") == nil
        and P.beliefs.bea.transferFloor.eventAt == floor.eventAt
        and P.beliefs.bea.transferFloor.eventId == floor.eventId)

    reset()
    check("request_original_private", P.recordAidRequest("asker", "hungry-house", 100, "requested")
        and #P.knownAidRequests("asker") == 1 and #P.knownAidRequests("other-member") == 0
        and P.beliefs["other-member"] == nil)
    local request = P.knownAidRequest("asker", "hungry-house")
    check("request_geometry_stays_unknown", request and request.minX == nil
        and request.maxY == nil and request.source == "requested"
        and P.hasAnythingToPass("asker", 900000))
    __now = 105
    P.tell("asker", "helper", 945000, true)
    local heard = P.knownAidRequest("helper", "hungry-house")
    check("request_testimony_provenance", heard and heard.requestedAt == 100
        and heard.acquiredAt == 105 and heard.source == "told" and heard.teller == "asker"
        and heard.originId == "asker" and heard.originAcquiredAt == 100)
    P.beliefs.helper.factions["hungry-house"] = { minX=8,minY=10,maxX=12,maxY=14 }
    local located = P.knownAidRequest("helper", "hungry-house")
    located.minX = -999
    check("request_geometry_private_and_detached", P.knownAidRequest("helper", "hungry-house").minX == 8
        and P.knownAidRequest("asker", "hungry-house").minX == nil)
    __now = 106
    local historical = P.knownAidRequest("helper", "hungry-house", 105)
    local future = P.knownAidRequest("helper", "hungry-house", 107)
    check("request_historical_geometry_withheld", historical and historical.requestedAt == 100
        and historical.minX == nil and historical.maxY == nil
        and future and future.minX == nil and P.knownAidRequest("helper", "hungry-house").minX == 8)
    P.tell("helper", "relay", 954000, true)
    __now = 107
    P.tell("relay", "helper", 963000, true)
    local unchanged = P.knownAidRequest("helper", "hungry-house")
    check("request_cycle_no_refresh", unchanged.requestedAt == 100 and unchanged.acquiredAt == 105
        and unchanged.teller == "asker")
    __canConverse = false
    P.tell("asker", "unheard", 963000, true)
    check("request_channel_required", #P.knownAidRequests("unheard") == 0)
    __canConverse = true; __trust["skeptic|asker"] = -0.3
    P.tell("asker", "skeptic", 963000, true)
    __trust["asker|stranger"] = 0
    P.tell("asker", "stranger", 963000, false)
    check("request_trust_gates_preserved", #P.knownAidRequests("skeptic") == 0
        and #P.knownAidRequests("stranger") == 0)
    local foodRequest = nil
    for _, value in ipairs(K.about("asker", "food", { nowHours = 107 }) or {}) do
        if value.fact == "aidRequest" then foodRequest = value end
    end
    check("knowledge_food_request", foodRequest and foodRequest.groupId == "hungry-house"
        and foodRequest.requestedAt == 100 and foodRequest.source == "requested")
    __now = 197
    check("request_expires_from_origin", #P.knownAidRequests("helper") == 0
        and #P.knownAidRequests("asker") == 0 and not P.hasAnythingToPass("asker", 1773000)
        and P.recordAidRequest("late", "hungry-house", 100, "requested") == false)
    check("unsupported_request_channel_refused", P.recordAidRequest("radio", "g", 197, "radio") == false)

    reset()
    P.recordAidRequest("asker", "g", 100, "requested")
    P.beliefs.asker.factions.g = { minX=8,minY=10,maxX=12,maxY=14 }
    P.beliefs.receiver = { zombies={},people={},factions={},places={} }
    check("request_return_report", P.reportReturn("asker", "receiver", 900000, 10, 12) >= 1
        and P.knownAidRequest("receiver", "g") ~= nil)
    P.beliefs.echo = { zombies={},people={},factions={},places={} }
    P.reportReturn("receiver", "echo", 900000, 10, 12)
    check("request_report_preserves_firsthand_scope", P.knownAidRequest("echo", "g") == nil)

    reset()
    __now = 170
    P.recordAidRequest("old-asker", "old-house", 100, "requested")
    P.tell("old-asker", "holder", 1530000, true)
    for i=1,65 do P.recordAidRequest("holder", "house-" .. tostring(i), 104 + i, "requested") end
    P.tell("old-asker", "holder", 1530000, true)
    check("request_bound_and_eviction_floor", #P.knownAidRequests("holder") == 64
        and P.knownAidRequest("holder", "old-house") == nil
        and P.beliefs.holder.aidRequestFloor ~= nil)

    reset()
    local D = SAO.Disposition
    __traitUnits.low = 0
    __traitUnits.high = 1
    __traitUnits.marginal = 4 / 7
    local noNeed = D.assistanceAppraisal("marginal", "ada", 0)
    check("disposition_zero_need_neutral", noNeed and noNeed.reciprocity == 0
        and D.assistanceAppraisal("marginal", "ada", -1) == nil
        and D.assistanceAppraisal("marginal", "ada", 0 / 0) == nil)
    __trust["marginal|ada"] = -0.8
    check("disposition_hostility_can_decline", D.assistanceAppraisal("marginal", "ada", 1).reciprocity < 0)
    __trust["marginal|ada"] = 0.6
    check("disposition_compassion_differs", D.assistanceAppraisal("high", "ada", 0.5).reciprocity
        > D.assistanceAppraisal("low", "ada", 0.5).reciprocity)
    local beforeHelp = D.wouldGiveToStranger("marginal", "ada")
    local help = receipt("appraised-help", 100, "ada", { "marginal" })
    help.transferObservation.appraisals = {
        marginal = D.assistanceAppraisal("marginal", "ada", 1) }
    P.receiveTransferResult(help)
    local helpsBenefactor = D.wouldGiveToStranger("marginal", "ada")
    local helpsSomeoneElse = D.wouldGiveToStranger("marginal", "other")
    __now = 437
    check("disposition_reciprocity_changes_own_choice", not beforeHelp and helpsBenefactor
        and not helpsSomeoneElse and not D.wouldGiveToStranger("marginal", "ada")
        and __socialWrites == 0)
    return table.concat(results, "|")
end)()
