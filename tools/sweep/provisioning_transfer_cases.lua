(function()
    local checks = {}
    local WS = SAO.WorldSources
    local function check(name, value)
        checks[#checks + 1] = name .. "=" .. tostring(value and true or false)
    end
    local function reset(operation, snapshot, row)
        __stores = {}
        __records.a, __records.b = {id="a"}, {id="b"}
        __bodies.a, __bodies.b = bodyA, bodyB
        SAO.Perception._known = {}
        __permit, __learnRefused, __offerCalls = true, false, 0
        __carriedText = row or (operation == "store" and __store_row or __acquire_row)
        __offerText = __carriedText .. "\n" .. snapshot
        WS.resetRuntime()
    end
    local function offer(operation, actor, body)
        return WS.transferOptions(actor or "a", body or bodyA, "food",
            "standing", {}, {}, operation)
    end
    local function begin(operation, category)
        return WS.beginTransfer("a", bodyA, category or "food", "standing",
            {}, {}, operation)
    end
    local function close(reservation, snapshot)
        if not reservation then return nil end
        local actor = reservation.actorId
        WS.markTransferred(reservation.id, actor)
        WS.markNative(reservation.id, actor, "completed", 1, "native-transfer-observed")
        WS.applySnapshot(WS.parse(snapshot), reservation.id)
        if not WS.reconcileActionSnapshot(reservation.id, actor, 1, 1) then return nil end
        return WS.finishAction(reservation.id, actor)
    end

    reset("store", __store_pre)
    local offered = offer("store")
    local known = SAO.Perception._known.a or {}
    local private = offered and known[offered.place.id]
    check("exact_private_offer", offered and #offered.options == 1
        and offered.options[1].parameters.itemId == 101
        and offered.place.sourceId == "C:food-token:0"
        and private and private.sourceFacts["C:food-token:0"]
        and not private.sourceFacts["C:neighbor:0"]
        and not SAO.Perception._known.b
        and WS.source("C:neighbor:0") ~= nil)
    if offered then offered.options[1].parameters.itemType = "Base.Forged" end
    local another = offer("store")
    check("detached_offer", another and another.options[1].parameters.itemType == "Base.Apple")
    local forged, forgedWhy = WS.beginTransfer("a", bodyA, "food", "standing",
        {}, {}, "store", offered and offered.options[1])
    check("forged_choice_refused", not forged and forgedWhy == "selected-option-changed")

    reset("store", __store_pre)
    check("live_actor_required", offer("store", "a", bodyB) == nil)
    __permit = false
    check("current_permission_required", offer("store") == nil)
    __permit, __learnRefused = true, true
    check("private_admission_required", offer("store") == nil)

    reset("store", __store_pre)
    local valid = __offerText
    local malformed = {string.gsub(valid,"id=101","id=0",1),
        string.gsub(valid,"amount=0.000000","amount=nan",1),
        string.gsub(valid,"poison=0","poison=2",1),
        string.gsub(valid,"type=Base.Apple","type=Base.Apple%%zz",1),
        string.gsub(valid,"|uses=1","|uses=1|uses=2",1),
        string.gsub(valid,"cats=food","cats=unknown",1)}
    local malformedRefused = true
    for _, text in ipairs(malformed) do
        __offerText = text
        if offer("store") ~= nil then malformedRefused = false end
    end
    check("malformed_offer_refused", malformedRefused)
    __offerText = string.sub(valid, 1, #valid - 2)
    check("complete_snapshot_required", offer("store") == nil)

    reset("store", __store_pre)
    local selected = offer("store")
    __offerText = string.gsub(__offerText, "store%-r1", "store-r2", 1)
    local changed, changedWhy = WS.beginTransfer("a",bodyA,"food","standing",{},{},
        "store", selected and selected.options[1])
    check("changed_choice_refused", not changed and changedWhy == "selected-option-changed")

    reset("store", __store_pre)
    local reservation = begin("store")
    check("single_actor_and_source_owner", reservation and not offer("store")
        and not offer("store", "b", bodyB)
        and __records.a.worldSourceReservation == reservation.id
        and __records.b.worldSourceReservation == nil)

    local function independentTransfers(operation)
        reset("acquire", __acquire_pre)
        local first = begin("acquire")
        if not first or not WS.prepareActionPre(first.id,"a") then return false end
        -- A's item has moved physically, but its callback has not proved that
        -- fact yet. B independently inspects and binds the other container.
        __carriedText = operation == "store" and __neighbor_store_row or __neighbor_acquire_row
        __offerText = __carriedText .. "\n" .. __acquire_post
        local second = WS.beginTransfer("b",bodyB,"food","standing",{},{},operation)
        local retained = WS.source(first.sourceId)
        if not second or not retained or retained.revision ~= "acquire-r1"
            or retained.conflict or first.transferProven then return false end
        if not WS.prepareActionPre(second.id,"b") then return false end
        local post = operation == "store" and __dual_stored or __dual_acquired
        local secondReceipt = close(second,post)
        retained = WS.source(first.sourceId)
        local remainedPrivate = retained and retained.revision == "acquire-r1"
            and not retained.conflict and not first.transferProven
        local firstReceipt = close(first,post)
        return remainedPrivate and firstReceipt and secondReceipt
            and firstReceipt.status == "completed" and secondReceipt.status == "completed"
            and __records.a.worldSourceReservation == nil
            and __records.b.worldSourceReservation == nil
            and __records.a.lastFoodDay == nil and __records.b.lastFoodDay == nil
    end
    check("same_chunk_acquire_acquire",independentTransfers("acquire"))
    check("same_chunk_acquire_store",independentTransfers("store"))

    reset("acquire", __acquire_pre)
    local first = begin("acquire")
    if first then WS.prepareActionPre(first.id,"a") end
    local neighbor = WS.beliefFact("C:neighbor:0")
    SAO.Perception._known.b = {[42]={cx=8,cy=8,sources={food=true},
        sourceRevision=neighbor.id .. "@" .. neighbor.revision,
        sourceFacts={[neighbor.id]=neighbor}}}
    local consume = WS.beginAction({id=42,cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16},
        "food","b",bodyB,1,"standing")
    local consumePrepared = consume and WS.prepareActionPre(consume.id,"b")
    local consumeReceipt = close(consume,__dual_acquired)
    local retained = first and WS.source(first.sourceId)
    local acquireUnchanged = retained and retained.revision == "acquire-r1"
        and not retained.conflict and not first.transferProven
    local firstReceipt = close(first,__dual_acquired)
    check("same_chunk_acquire_consume",consumePrepared and acquireUnchanged
        and consumeReceipt and firstReceipt and __records.b.lastFoodDay == 2
        and __records.a.lastFoodDay == nil)

    local function foreignSourceEvidence(snapshot, finalSnapshot)
        reset("acquire",__acquire_pre)
        local pending = begin("acquire")
        if not pending then return false,false end
        WS.prepareActionPre(pending.id,"a")
        __offerText = __neighbor_acquire_row .. "\n" .. snapshot
        local second = WS.beginTransfer("b",bodyB,"food","standing",{},{},"acquire")
        local previous = WS.source(pending.sourceId)
        local unchanged = second and previous and previous.revision == "acquire-r1"
            and previous.fingerprint == "food-fp" and not previous.conflict
        if second then WS.prepareActionPre(second.id,"b") end
        local secondReceipt = close(second,finalSnapshot)
        local durable = __stores.SurvivorAwareness_WorldSources
        local memberKept = durable.chunks["1:1"].sourceIds[pending.sourceId] == true
        local firstResult = close(pending,finalSnapshot)
        local ownObserved = WS.source(pending.sourceId)
        return unchanged and secondReceipt ~= nil,
            memberKept and firstResult == nil and ownObserved
            and ownObserved.state == "conflicted"
    end
    local missingRetained, missingIndexed = foreignSourceEvidence(__dual_missing,__dual_missing_post)
    check("foreign_missing_source_retained",missingRetained)
    check("foreign_missing_membership_retained",missingIndexed)
    local fingerprintRetained, ownFingerprintConflict = foreignSourceEvidence(
        __dual_replaced,__dual_replaced_post)
    check("foreign_fingerprint_retained",fingerprintRetained and ownFingerprintConflict)

    reset("acquire",__acquire_pre)
    first = begin("acquire")
    WS.applySnapshot(WS.parse(__acquire_post))
    retained = first and WS.source(first.sourceId)
    check("unscoped_changes_conflict",retained and retained.state == "conflicted")
    reset("acquire",__acquire_pre)
    first = begin("acquire")
    WS.applySnapshot(WS.parse(__acquire_post),"missing:reservation")
    retained = first and WS.source(first.sourceId)
    local invalidRejected = retained and retained.state == "conflicted"
    reset("acquire",__acquire_pre)
    first = begin("acquire")
    __stores.SurvivorAwareness_WorldSources.reservations.bad = {status="reserved",sourceId=""}
    WS.applySnapshot(WS.parse(__acquire_post),"bad")
    retained = first and WS.source(first.sourceId)
    check("invalid_owner_cannot_defer",invalidRejected
        and retained and retained.state == "conflicted")

    reset("store", __store_pre)
    reservation = begin("store")
    local goodCarried = __carriedText
    __carriedText = string.gsub(goodCarried, "condition=10", "condition=9", 1)
    check("carried_signature_required", reservation
        and not WS.carriedTransferMatches(reservation, bodyA)
        and not WS.prepareActionPre(reservation.id,"a"))
    __carriedText = goodCarried
    check("no_unperformed_completion", reservation
        and not WS.markNative(reservation.id,"a","completed",1,"queued-only")
        and not WS.finishAction(reservation.id,"a"))
    if reservation then WS.release(reservation.id,"queue-refused") end
    local refused = reservation and WS.actionOutcome(reservation.id,"a")
    check("failed_queue_no_stock_or_need_credit", refused and refused.status == "released"
        and refused.observedQuantity == nil and #WS.completedResults("provisioning") == 0
        and __records.a.lastFoodDay == nil
        and WS.source("C:food-token:0").items["101"] == nil)

    reset("store", __store_pre)
    reservation = begin("store")
    local prepared = reservation and WS.prepareActionPre(reservation.id,"a")
    WS.resetRuntime()
    check("reload_retains_transfer", reservation and WS.reconcileReservations() == 0
        and WS.pendingActionFor("a").operation == "store"
        and WS.reservation(reservation.id).preItems["202"] ~= nil
        and WS.reservation(reservation.id).itemSignature ~= nil)
    local receipt = close(reservation,__store_post)
    check("store_exact_addition", prepared and receipt and receipt.status == "completed"
        and receipt.preRevision == "store-r1" and receipt.postRevision == "store-r2"
        and WS.source("C:food-token:0").items["101"].type == "Base.Apple"
        and __records.a.worldSourceReservation == nil)
    check("transfer_no_need_stamp", receipt and __records.a.lastFoodDay == nil
        and __records.a.lastWaterDay == nil)
    local outcome = reservation and WS.actionOutcome(reservation.id,"a")
    check("transfer_result_units", outcome and outcome.operation == "store"
        and outcome.quantityUnit == "item" and outcome.requestedQuantity == 1
        and outcome.observedQuantity == 1 and outcome.itemAmount == 0
        and outcome.itemUses == 1 and outcome.measurement == "native-item-transfer")
    local deliveries = WS.completedResults("provisioning")
    if deliveries[1] then deliveries[1].itemType = "Base.Corrupted" end
    local second = WS.completedResults("provisioning")
    check("repeated_delivery_isolated", receipt and not WS.finishAction(reservation.id,"a")
        and #deliveries == 1 and #second == 1 and second[1].itemType == "Base.Apple"
        and WS.acknowledgeResult(reservation.id,"provisioning","applied")
        and WS.acknowledgeResult(reservation.id,"provisioning","retry")
        and #WS.completedResults("provisioning") == 0)
    check("actor_result_isolation", reservation and WS.actionOutcome(reservation.id,"b") == nil)

    local function conflictCase(snapshot)
        reset("store", __store_pre)
        local pending = begin("store")
        if not pending then return false end
        WS.prepareActionPre(pending.id,"a")
        local finished = close(pending,snapshot)
        local source = WS.source("C:food-token:0")
        return not finished and source and source.state == "conflicted"
            and #WS.completedResults("provisioning") == 0
    end
    check("concurrent_change_conflicts",conflictCase(__store_changed))
    check("unrelated_addition_conflicts",conflictCase(__store_added))
    check("stored_contents_mismatch_conflicts",conflictCase(__store_mismatch))

    reset("acquire", __acquire_pre)
    reservation = begin("acquire")
    prepared = reservation and WS.prepareActionPre(reservation.id,"a")
    local carried = reservation and WS.carriedTransferMatches(reservation,bodyA)
    __carriedText = string.gsub(__carriedText,"currentUses=1","currentUses=0.5",1)
    check("carried_acquisition_signature",carried
        and not WS.carriedTransferMatches(reservation,bodyA))
    __carriedText = __acquire_row
    receipt = close(reservation,__acquire_post)
    check("acquire_exact_removal", prepared and receipt and receipt.operation == "acquire"
        and receipt.quantity == 1 and __records.a.lastFoodDay == nil
        and WS.source("C:food-token:0").items["101"] == nil)

    reset("acquire",__water_pre,__water_row)
    reservation = begin("acquire","water")
    if reservation then WS.prepareActionPre(reservation.id,"a") end
    receipt = close(reservation,__water_post)
    outcome = receipt and WS.actionOutcome(reservation.id,"a")
    check("water_transfer_counts_item", outcome and outcome.observedQuantity == 1
        and outcome.itemAmount == 0.75 and outcome.itemCurrentUses == 0.75
        and outcome.quantityUnit == "item" and __records.a.lastWaterDay == nil)

    reset("store",__legacy_pre)
    reservation = begin("store")
    if reservation then WS.prepareActionPre(reservation.id,"a") end
    check("legacy_optional_metadata",close(reservation,__legacy_post) ~= nil)

    reset("acquire",__acquire_pre)
    WS.applySnapshot(WS.parse(__acquire_pre))
    local _, revisions, _, facts = WS.beliefSnapshot(__places[42])
    SAO.Perception._known.a = {[42]={cx=8,cy=8,sources={food=true},sourceFacts=facts,
        sourceRevision=revisions}}
    reservation = WS.beginAction(__places[42],"food","a",bodyA,1,"standing")
    local durable = __stores.SurvivorAwareness_WorldSources
    if reservation then reservation.operation = nil end
    durable.schema = 5
    check("schema6_migration",reservation and WS.reservation(reservation.id).operation == "consume"
        and durable.schema == 6)
    if reservation then WS.prepareActionPre(reservation.id,"a") end
    receipt = close(reservation,__acquire_post)
    check("consume_retains_need_stamp",receipt and receipt.operation == "consume"
        and __records.a.lastFoodDay == 2)

    reset("store",__store_pre)
    __stores.SurvivorAwareness_WorldSources = {schema=7,sentinel="future"}
    __records.a.worldSourceReservation = "future:reservation"
    check("future_schema_refused",offer("store") == nil
        and WS.pendingActionFor("a").unavailable
        and __stores.SurvivorAwareness_WorldSources.schema == 7
        and __stores.SurvivorAwareness_WorldSources.sentinel == "future")

    reset("store",__store_pre)
    offer("store")
    durable = __stores.SurvivorAwareness_WorldSources
    for index=1,2048 do durable.reservations[tostring(index)] = {status="reserved"} end
    local bounded, boundWhy = offer("store")
    check("reservation_bound",not bounded and boundWhy == "reservation-bound")
    durable.reservations = {}
    for index=1,2048 do durable.results[tostring(index)] = {status="completed"} end
    bounded,boundWhy = offer("store")
    check("protected_result_bound",not bounded and boundWhy == "result-bound")

    reset("store",__acquire_pre)
    check("store_duplicate_refused",offer("store") == nil)
    reset("store",__medicine)
    local medicineOffer = offer("store")
    local medicineSource = WS.source("C:medicine:0")
    check("native_medicine_category",medicineOffer and medicineSource
        and medicineSource.items["902"].categories.medicine
        and not SAO.Perception._known.a[medicineOffer.place.id].sourceFacts["C:medicine:0"])
    return table.concat(checks,"|")
end)()
