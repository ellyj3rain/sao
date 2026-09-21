(function()
    if __productionPerceptionCases then
        local WS, P = SAO.WorldSources, SAO.Perception
        local checks = {}
        local function check(name, value)
            checks[#checks+1] = name .. "=" .. tostring(value and true or false)
        end
        __stores = {}
        __records = {a={id="a",forename="Ada",surname="Stone",occupation="farmer"},
            b={id="b",forename="Ben",surname="North",occupation="farmer"}}
        __bodies = {a=__newBody(8,8),b=__newBody(8,8)}
        SAO.Body.active = __bodies
        P.beliefs = {}
        __standingAllowed = true
        local building = {id=42,cx=8,cy=8,minX=8,minY=8,maxX=10,maxY=9}
        SAO.Places.at = function(x,y)
            if x == 8 and y == 8 then return building end
        end
        SAO.Standing.claimOf = function() return nil end
        SAO.Standing.groupOf = function() return nil end
        SAO.Standing.insideClaim = function() return false end
        WS.resetRuntime()
        WS.applySnapshot(WS.parse(__acquire_pre))
        local anchor = {id="source:C:food-token:0",sourceId="C:food-token:0",
            cx=8,cy=8,z=0,minX=8,minY=8,maxX=9,maxY=9}
        local learned = P.learnInspectedSource("a",anchor,"C:food-token:0",4800,
            "native-transfer-inspection")
        P.learnInspectedSource("a",anchor,"C:food-token:0",4801,"observed-transfer")
        local row = P.knownPlaces("a",true)[anchor.id]
        check("production_inspection_geometry",learned and row and row.cx == 8
            and row.cy == 8 and row.z == 0 and row.minX == 8 and row.minY == 8
            and row.maxX == 9 and row.maxY == 9 and row.sourceId == anchor.sourceId)
        local recalled = WS.nearestObserved("a",8,8,"food",10)
        check("production_anchor_recall",recalled and recalled.id == anchor.id
            and recalled.sourceId == anchor.sourceId and recalled.cx == 8 and recalled.cy == 8
            and WS.nearestObserved("b",8,8,"food",10) == nil)
        local _, _, _, scopedFacts = WS.beliefSnapshot(anchor)
        local offered = recalled and WS.actionOptions(recalled,"food","a",__bodies.a,1,"standing")
        check("production_anchor_exact_scope",row and row.sourceFacts
            and row.sourceFacts[anchor.sourceId] and not row.sourceFacts["C:neighbor:0"]
            and scopedFacts[anchor.sourceId] and not scopedFacts["C:neighbor:0"]
            and offered and #offered.options == 1
            and offered.options[1].parameters.sourceId == anchor.sourceId)
        local reservation = offered and WS.beginAction(recalled,"food","a",__bodies.a,
            1,"standing",offered.options[1])
        check("production_consume_anchor",reservation and reservation.operation == "consume"
            and reservation.placeId == anchor.id and reservation.placeSourceId == anchor.sourceId
            and reservation.sourceId == anchor.sourceId and reservation.itemId == 101)
        if reservation then WS.release(reservation.id,"fixture-complete") end
        local attachment = SAO.PlaceAttachment.of("a")
        local knownCount = 0
        for _ in pairs(P.knownPlaces("a")) do knownCount = knownCount + 1 end
        check("production_inspection_no_attachment",row and (row.visits or 0) == 0
            and knownCount == 0 and #P.returnsOf({"a"}) == 0
            and attachment and attachment.knownPlaces == 0 and attachment.visitedPlaces == 0
            and attachment.attachment == 0 and attachment.claimKind == "none")
        local unavailable = WS.nearestBelieved("a",8,8,"food",10)
        WS.applySnapshot(WS.parse(__anchor_accessible))
        P.learnInspectedSource("a",anchor,anchor.sourceId,4802,"native-transfer-inspection")
        local executable = WS.nearestBelieved("a",8,8,"food",10)
        check("production_anchor_access_route",unavailable == nil and executable
            and executable.id == anchor.id and executable.sourceId == anchor.sourceId)
        P.learnBuilding("a",building,4803,"observed-building")
        local known = P.knownPlaces("a")
        local ranking = P.returnsOf({"a"})
        attachment = SAO.PlaceAttachment.of("a")
        check("production_building_visit_preserved",known[42] and known[42].visits == 1
            and known[anchor.id] == nil and #ranking == 1 and ranking[1].id == 42
            and attachment.knownPlaces == 1 and attachment.visitedPlaces == 1)
        return table.concat(checks,"|")
    end
    local WS, SU, Ctl = SAO.WorldSources, SAO.SourceUse, SAO.Controller
    local checks, diagnostics = {}, {}
    local function check(name, value)
        checks[#checks+1] = name .. "=" .. tostring(value and true or false)
        if not value then
            local pending = WS.pendingActionFor("a")
            diagnostics[#diagnostics+1] = "CASE " .. name .. " pending=" .. tostring(pending and pending.phase)
                .. " holder=" .. tostring(__holderState) .. " moves=" .. tostring(__nativeMoves)
            local durable = __stores.SurvivorAwareness_WorldSources or {}
            for _, receipt in pairs(durable.results or {}) do
                diagnostics[#diagnostics+1] = "RESULT " .. tostring(receipt.status) .. " " .. tostring(receipt.detail)
            end
        end
    end
    local function reset(operation)
        __stores, __records, __bodies, __known, __places = {}, {}, {}, {}, {}
        SAO.Body.active, SAO.Body.foreign = __bodies, {}
        SAO.Perception.beliefs = {a={evidence={value="before"}}}
        local body = __newBody(8,8)
        __inventory, __sourceContainer, __permissionContainer, __originContainer = {}, {}, {}, {}
        body.getInventory = function() return __inventory end
        __records.a = {id="a",forename="Ada",surname="Stone",occupation="farmer",
            profile={note="before"}}
        __bodies.a = body
        Ctl.agents = {a={rec=__records.a,state="SOURCEUSE"}}
        __operation, __sourceItem = operation, {id=101,type="Base.Apple"}
        __observeText = operation == "store" and __store_pre or __acquire_pre
        local row = operation == "store" and __store_row or __acquire_row
        __offerText = row .. "\n" .. __observeText
        __carriedText = operation == "store" and row or ""
        __carriedItem = operation == "store" and __sourceItem or nil
        __destinationItem = nil
        __holderState = operation == "store" and "CARRIED" or "SOURCE"
        __bindAnswer, __targetAnswer = "BOUND:8:8:0", "READY:8:8:0:8:8:0"
        __queueReject, __busy, __queued, __queueCalls = false, false, nil, 0
        __standingAllowed, __accessible, __nativeValid = true, true, true
        __withinReach, __routeAllowed, __attemptAllowed = true, true, true
        __lastOrder, __attempt, __searchedRadius = nil, nil, nil
        __discoveredSource = "8:8:0:Apple"
        __bindCalls, __clears, __nativeMoves, __consumeCalls = 0, 0, 0, 0
        __xpCalls, __voiceCalls, __trustCalls, __debtCalls = 0, 0, 0, 0
        __groupByActor, __groupClaims, __standingStoreUnavailable = nil, nil, false
        __lastLearn = nil
        __move = function()
            __observeText = operation == "store" and __store_post or __acquire_post
            __carriedItem = operation == "acquire" and __sourceItem or nil
            __destinationItem = operation == "store" and __sourceItem or nil
            __carriedText = operation == "acquire" and __acquire_row or ""
            __holderState = "TRANSFERRED"
        end
        WS.resetRuntime()
        return body
    end
    local function begin(body, operation, context)
        local ok, why = SU.beginTransfer("a",body,"food","standing",__sourceItem,
            __sourceContainer,operation,context or {purpose="forage"})
        local reservation = WS.pendingActionFor("a")
        return ok, reservation, why
    end
    local function outcome(reservation)
        return reservation and WS.actionOutcome(reservation.id,"a") or nil
    end
    local function moveAndFinish(body)
        if __queued then __queued:transferItem(__sourceItem) end
        __busy, __queued = false, nil
        return SU.tick("a",body)
    end
    local function reload(body)
        __busy, __queued = false, nil
        SAOJavaBridge:clearWorldSourceAction(body)
        WS.resetRuntime()
        WS.reconcileReservations()
        local restored = __newBody(8,8)
        restored.getInventory = function() return __inventory end
        __bodies.a = restored
        return restored
    end

    local body = reset("acquire")
    local ok, reservation = begin(body,"acquire")
    local acquired = moveAndFinish(body)
    local receipt = outcome(reservation)
    check("acquire_performed",ok and acquired == "completed" and receipt
        and receipt.operation == "acquire" and receipt.observedQuantity == 1
        and WS.source("C:food-token:0").items["101"] == nil
        and __carriedItem == __sourceItem and __nativeMoves == 1)
    local acquireNoUse = __consumeCalls == 0 and __records.a.lastFoodDay == nil
        and __records.a.lastWaterDay == nil

    body = reset("store")
    ok, reservation = begin(body,"store",{deliveryGroup="home",requestedByGroup="home"})
    check("queued_is_not_performed",ok and __busy and outcome(reservation).status == "pending"
        and WS.source("C:food-token:0").items["101"] == nil and __xpCalls == 0)
    check("queue_has_no_social_credit",__trustCalls == 0 and __debtCalls == 0
        and __voiceCalls == 0 and __xpCalls == 0)
    local stored = moveAndFinish(body)
    receipt = outcome(reservation)
    check("store_performed",stored == "completed" and receipt
        and receipt.operation == "store" and receipt.observedQuantity == 1
        and WS.source("C:food-token:0").items["101"] ~= nil and __carriedItem == nil)
    check("no_consumption_or_need_credit",acquireNoUse and __consumeCalls == 0
        and __records.a.lastFoodDay == nil and __records.a.lastWaterDay == nil)
    local creditBefore = __xpCalls
    local repeated = Ctl.provisioningCompleted("a",body,receipt,reservation)
    check("completed_work_credit_once",creditBefore == 1 and __xpCalls == 1
        and __xpPerk == "Fitness" and __xpAmount == 1 and not repeated)
    local creditOrder = __records.a.provisioningCreditOrder
    local badActor = Ctl.provisioningCompleted("a",body,
        {actorId="other",status="completed",order=999},reservation)
    local badStatus = Ctl.provisioningCompleted("a",body,
        {actorId="a",status="pending",order=999},reservation)
    local oldOrder = Ctl.provisioningCompleted("a",body,
        {actorId="a",status="completed",order=0},reservation)
    check("credit_actor_status_order",not badActor and not badStatus and not oldOrder
        and __records.a.provisioningCreditOrder == creditOrder and __xpCalls == creditBefore)
    local physical = __known.a and __known.a[reservation.placeId]
    check("physical_anchor_refresh",reservation.placeSourceId == "C:food-token:0"
        and physical and physical.sourceFacts["C:food-token:0"].revision == "store-r2"
        and __lastLearn.provenance == "observed-transfer"
        and not physical.sourceFacts["C:neighbor:0"])

    body = reset("store")
    ok, reservation = begin(body,"store")
    __busy, __queued = false, nil
    check("queue_without_move_releases",SU.tick("a",body) == "released"
        and outcome(reservation).status == "released" and __nativeMoves == 0
        and __xpCalls == 0 and #WS.completedResults("provisioning") == 0)

    body = reset("store")
    __queueReject = true
    ok, reservation = begin(body,"store")
    check("rejected_enqueue",not ok and not __busy and not reservation
        and __queueCalls == 1 and __nativeMoves == 0 and __xpCalls == 0
        and #WS.completedResults("provisioning") == 0)

    body = reset("acquire")
    ok, reservation = begin(body,"acquire")
    SU.interrupt("a",body,"threat")
    check("interrupt_before_move",outcome(reservation).status == "released"
        and __carriedItem == nil and __nativeMoves == 0 and __xpCalls == 0)
    body = reset("store")
    ok, reservation = begin(body,"store")
    __queued:transferItem(__sourceItem)
    SU.interrupt("a",body,"threat")
    check("interrupt_after_move",outcome(reservation).status == "completed"
        and __nativeMoves == 1 and __xpCalls == 1)

    body = reset("store")
    ok, reservation = begin(body,"store")
    body = reload(body)
    local state = SU.resume("a",body)
    check("reload_before_move",state == "SOURCEUSE" and __bindCalls == 2
        and __queueCalls == 2 and __nativeMoves == 0
        and WS.pendingActionFor("a").id == reservation.id)
    body = reset("store")
    ok, reservation = begin(body,"store")
    __queued:transferItem(__sourceItem)
    body = reload(body)
    SU.resume("a",body)
    local afterReload = outcome(reservation)
    SU.resume("a",body)
    check("reload_after_move_once",afterReload and afterReload.status == "completed"
        and __queueCalls == 1 and __nativeMoves == 1 and __xpCalls == 1
        and #WS.completedResults("provisioning") == 1)

    body = reset("store")
    ok, reservation = begin(body,"store")
    body = reload(body)
    __holderState = "UNAVAILABLE"
    local waiting = SU.resume("a",body)
    check("unavailable_destination_pending",waiting == "SOURCEUSE"
        and SU.tick("a",body) == "pending" and outcome(reservation).status == "pending"
        and __queueCalls == 1 and __nativeMoves == 0)
    __holderState = "CONFLICT"
    __destinationItem = __sourceItem
    local conflictState = SU.resume("a",body)
    check("both_holders_conflict",conflictState == nil
        and outcome(reservation).status == "conflict" and __xpCalls == 0)
    body = reset("store")
    ok, reservation = begin(body,"store")
    body = reload(body)
    __carriedItem, __destinationItem = nil, nil
    conflictState = SU.resume("a",body)
    check("neither_holder_conflict",conflictState == nil
        and outcome(reservation).status == "conflict" and __xpCalls == 0)

    body = reset("store")
    ok, reservation = begin(body,"store")
    local acceptedAction = __queued
    __standingAllowed = false
    acceptedAction:transferItem(__sourceItem)
    __busy = false
    SU.tick("a",body)
    check("standing_revocation_prevents_mutation",ok and __nativeMoves == 0
        and acceptedAction.dontAdd == true and outcome(reservation).status == "released"
        and __carriedItem == __sourceItem and __xpCalls == 0)

    body = reset("acquire")
    ok, reservation = begin(body,"acquire")
    __queued:transferItem(__sourceItem)
    __carriedText = string.gsub(__carriedText,"condition=10","condition=9",1)
    __busy = false
    SU.tick("a",body)
    check("acquired_contents_mismatch",outcome(reservation).status == "conflict"
        and __records.a.lastFoodDay == nil and __xpCalls == 0)

    body = reset("acquire")
    __standingAllowed = false
    ok = SAO.Needs.queueTake("a",body,{category="food",purpose="forage",admission="standing"})
    check("standing_food_refusal",not ok and not WS.pendingActionFor("a")
        and __queueCalls == 0 and __nativeMoves == 0 and __standingAdmission == "standing")
    body = reset("acquire")
    __standingAllowed = false
    ok = SAO.Needs.queueTake("a",body,{category="food",purpose="forage",admission="desperate"})
    reservation = WS.pendingActionFor("a")
    local desperateOutcome = moveAndFinish(body)
    check("desperate_food_admission",ok and reservation and reservation.admission == "desperate"
        and __standingAdmission == "desperate" and desperateOutcome == "completed"
        and __nativeMoves == 1 and __records.a.lastFoodDay == nil)
    body = reset("acquire")
    __sourceItem = {id=404,type="Base.Pills"}
    __offerText = ""
    ok = SAO.Needs.queueTake("a",body,{category="legacy"})
    check("legacy_medication_route",ok and __queueCalls == 1 and __queued.item == __sourceItem
        and not WS.pendingActionFor("a") and __consumeCalls == 0)
    body = reset("acquire")
    __offerText = ""
    ok = SAO.Needs.queueTake("a",body)
    check("legacy_missing_context",ok and __queueCalls == 1 and not WS.pendingActionFor("a"))

    body = reset("acquire")
    __withinReach, __discoveredSource = false, "12:11:2:Apple"
    local nearbyState, nearbyContext = SAO.Needs.collectNearby("a",body,20,99)
    check("nearby_approach_exact",nearbyState == "FORAGE" and nearbyContext
        and nearbyContext.category == "food" and nearbyContext.purpose == "forage"
        and nearbyContext.admission == "standing" and nearbyContext.haulRemaining == 3
        and nearbyContext.haulRadius == 4 and __searchedRadius == 20
        and __lastOrder and __lastOrder.id == "a" and __lastOrder.x == 12
        and __lastOrder.y == 11 and __lastOrder.z == 2 and __attempt
        and __attempt.x == 12 and __attempt.y == 11 and __attempt.admission == "standing"
        and __queueCalls == 0 and not WS.pendingActionFor("a") and __nativeMoves == 0)
    body = reset("acquire")
    __withinReach, __routeAllowed = false, false
    nearbyState = SAO.Needs.collectNearby("a",body,4,2)
    check("nearby_route_refusal",nearbyState == nil and __lastOrder
        and __queueCalls == 0 and not WS.pendingActionFor("a") and __nativeMoves == 0)
    body = reset("acquire")
    __withinReach, __attemptAllowed = false, false
    nearbyState = SAO.Needs.collectNearby("a",body,4,2)
    check("nearby_standing_refusal",nearbyState == nil and __attempt
        and __attempt.admission == "standing" and not __lastOrder
        and __queueCalls == 0 and not WS.pendingActionFor("a") and __nativeMoves == 0)
    body = reset("acquire")
    nearbyState, nearbyContext = SAO.Needs.collectNearby("a",body,0,0)
    reservation = WS.pendingActionFor("a")
    check("nearby_reached_transfer",nearbyState == "TAKE" and nearbyContext
        and nearbyContext.haulRemaining == 0 and nearbyContext.haulRadius == 1
        and reservation and reservation.operation == "acquire" and reservation.itemId == 101
        and __queued and __queued.item == __sourceItem and __queueCalls == 1
        and not __lastOrder and __nativeMoves == 0)

    body = reset("store")
    local choose = SU.chooseOption
    SU.chooseOption = function(offered)
        __records.a.profile.note = "during"
        SAO.Perception.beliefs.a.evidence.value = "during"
        return choose(offered)
    end
    local capture = SAODecisionCapture.beginSourceUse({runId="run-transfer",county="Knox"})
    ok, reservation = begin(body,"store")
    moveAndFinish(body)
    __records.a.profile.note = "after"
    SAO.Perception.beliefs.a.evidence.value = "after"
    local text = capture.finish()
    SU.chooseOption = choose
    local function has(needle) return string.find(text,needle,1,true) ~= nil end
    check("capture_transfer_bound",ok and has('"eventCount":1')
        and has('"captureFailureCount":0') and has('"reservationId":"' .. reservation.id .. '"')
        and has('"status":"completed"') and not has('"action-not-bound"'))
    check("capture_decision_frozen",has('"note":"before"') and has('"value":"before"')
        and not has('"note":"during"') and not has('"note":"after"'))
    check("capture_item_units",has('"quantityUnit":"item"')
        and has('"measurement":"native-item-transfer"') and has('"observedQuantity":1'))

    body = reset("acquire")
    capture = SAODecisionCapture.beginSourceUse({runId="run-bad-result",county="Knox"})
    ok, reservation = begin(body,"acquire")
    local read = WS.actionOutcome
    WS.actionOutcome = function() return nil,"store-unavailable" end
    text = capture.finish()
    WS.actionOutcome = read
    check("capture_required_result_failure",ok and has('"eventCount":0')
        and has('"captureFailureCount":1') and has('"stage":"result"')
        and not has('"status":"censored"'))

    body = reset("store")
    local age = SAO.History.ageOf
    SAO.History.ageOf = function() error("fixture age reader unavailable") end
    capture = SAODecisionCapture.beginSourceUse({runId="run-bad-person",county="Knox"})
    ok, reservation = begin(body,"store")
    text = capture.finish()
    SAO.History.ageOf = age
    check("capture_required_person_failure",ok and __busy and reservation
        and has('"eventCount":0') and has('"captureFailureCount":1')
        and has('History.ageOf'))
    return table.concat(checks,"|") .. "|DETAIL " .. table.concat(diagnostics," ; ")
end)()
