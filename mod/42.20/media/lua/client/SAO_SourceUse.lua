-- SAO_SourceUse - one actor-specific source access and native-use proof.
--
-- C61 records exact native source and item revisions. This module performs the
-- first narrow action over that substrate: a live actor approaches the known
-- place, resolves the same source again, walks to an engine-selected
-- interaction square, transfers the exact item through a vanilla timed action,
-- and eats/drinks that exact carried item through vanilla. Durable ownership
-- and results live in SAO_WorldSources; Java holds only current-world object
-- references and verifies the physical effect.

SAO = SAO or {}
SAO.SourceUse = SAO.SourceUse or {}
local SU = SAO.SourceUse

local function log(message)
    if SAO.Log and SAO.Log.line then
        SAO.Log.line("SOURCE-USE", tostring(message))
    end
end

local function clearBinding(body)
    pcall(function() SAOJavaBridge:clearWorldSourceAction(body) end)
end

local PHYSICAL_REFUSAL = {
    SOURCE_MISSING = true, ITEM_MISSING = true,
    FINGERPRINT_CHANGED = true, REVISION_CHANGED = true,
    ITEM_CHANGED = true, ["vehicle-left-observed-place"] = true,
}

local function refreshDisprovedSource(id, body, reservation, reason)
    if not reservation or not PHYSICAL_REFUSAL[tostring(reason)] then return end
    local sx = reservation.currentSourceX or reservation.sourceX
    local sy = reservation.currentSourceY or reservation.sourceY
    if sx and sy then
        pcall(function()
            local text = SAOJavaBridge:observeWorldChunk(
                math.floor(sx / 8), math.floor(sy / 8))
            local snapshot = SAO.WorldSources.parse(text)
            if snapshot then SAO.WorldSources.applySnapshot(snapshot,
                reservation.id) end
        end)
    end
    local learned = false
    pcall(function()
        local place = SAO.Places.at(reservation.placeX, reservation.placeY)
        if place and tostring(place.id) == tostring(reservation.placeId) then
            learned = SAO.Perception.learnSource(id, place,
                reservation.sourceId, SAO.History.ticks(),
                "source-revalidation") == true
        end
    end)
    if not learned and SAO.Perception and SAO.Perception.forgetSource then
        pcall(SAO.Perception.forgetSource, id, reservation.placeId,
            reservation.sourceId, SAO.History.ticks(),
            "source-revalidation")
    end
end

local function reservationFor(id)
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(tostring(id)) or nil
    if not rec then return nil, nil end
    return SAO.WorldSources.pendingActionFor(tostring(id)), rec
end

local function fail(id, body, reservation, reason)
    refreshDisprovedSource(id, body, reservation, reason)
    if reservation then
        SAO.WorldSources.failAction(reservation.id, id, reason)
    end
    clearBinding(body)
    log(tostring(id) .. " source action refused: " .. tostring(reason))
    return "failed"
end

local function actionTarget(body, reservation)
    local ok, answer = pcall(function()
        return SAOJavaBridge:worldSourceActionTarget(body,
            reservation.sourceId, reservation.fingerprint,
            reservation.revision, reservation.itemId,
            reservation.itemType, reservation.sourceX,
            reservation.sourceY, reservation.sourceZ)
    end)
    if not ok or type(answer) ~= "string" then return nil, "bridge-failed" end
    local x, y, z, sourceX, sourceY, sourceZ = string.match(answer,
        "^READY:(%-?%d+):(%-?%d+):(%-?%d+):"
        .. "(%-?%d+):(%-?%d+):(%-?%d+)$")
    if not x then return nil, answer end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z),
        sourceX = tonumber(sourceX), sourceY = tonumber(sourceY),
        sourceZ = tonumber(sourceZ) }
end

local function orderInteraction(id, body, reservation)
    local target, why = actionTarget(body, reservation)
    if not target then return false, why end
    reservation.currentSourceX = target.sourceX
    reservation.currentSourceY = target.sourceY
    reservation.currentSourceZ = target.sourceZ
    if reservation.sourceKind == "vehicle"
        and (not reservation.placeMinX or not reservation.placeMinY
            or not reservation.placeMaxX or not reservation.placeMaxY
            or target.sourceX < reservation.placeMinX
            or target.sourceX >= reservation.placeMaxX
            or target.sourceY < reservation.placeMinY
            or target.sourceY >= reservation.placeMaxY) then
        return false, "vehicle-left-observed-place"
    end
    if not SAO.WorldSources.setPhase(reservation.id, id,
        "approaching-source") then return false, "reservation-lost" end
    if not SAO.Locomotion.order(id, body, target.x, target.y, target.z) then
        return false, "interaction-route-refused"
    end
    return true
end

local function carriedItem(body, reservation)
    local ok, item = pcall(function()
        return SAOJavaBridge:carriedWorldSourceItem(body,
            reservation.itemId, reservation.itemType)
    end)
    return ok and item or nil
end

local function queueNativeUse(id, body, reservation)
    local item = carriedItem(body, reservation)
    if item == nil then return false, "exact-item-not-carried" end
    if not SAO.WorldSources.markTransferred(reservation.id, id) then
        return false, "transfer-proof-refused"
    end
    local okMeasure, measure = pcall(function()
        return SAOJavaBridge:carriedWorldSourceMeasure(body,
            reservation.itemId, reservation.itemType, reservation.category)
    end)
    measure = okMeasure and tonumber(measure) or -1
    if measure < 0 then
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "native-measure-refused")
        return false, "native-measure-refused", true
    end
    if reservation.useBaseline == nil then
        reservation.useBaseline = reservation.category == "water"
            and reservation.itemAmount or measure
    end
    local useFraction = 1
    if reservation.category == "water" then
        if measure <= 0 and not reservation.nativeStarted then
            SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
                "native-water-empty")
            return false, "native-water-empty", true
        end
        if not reservation.nativeStarted
            and math.abs(measure - (tonumber(reservation.useBaseline) or measure))
                > 0.0001 then
            SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
                "native-prestart-measure-changed")
            return false, "native-prestart-measure-changed", true
        end
        local target = tonumber(reservation.useTargetQuantity) or 0
        local consumed = math.max(0,
            (tonumber(reservation.useBaseline) or measure) - measure)
        local remaining = math.max(0, target - consumed)
        if reservation.nativeStarted and remaining <= 0.0001 then
            SAO.WorldSources.markNative(reservation.id, id, "completed",
                consumed, "native-resume-observed")
            return false, "native-already-complete", true
        end
        if measure <= 0 then
            SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
                "native-water-empty")
            return false, "native-water-empty", true
        end
        useFraction = math.min(1, remaining / measure)
    end
    local okBegin, began = pcall(function()
        return SAOJavaBridge:beginWorldSourceUse(body,
            reservation.itemId, reservation.itemType, reservation.category,
            reservation.useBaseline)
    end)
    if not okBegin or began ~= true then
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "native-snapshot-refused")
        return false, "native-snapshot-refused", true
    end
    reservation.nativeStarted = true
    local action = nil
    local okAction = pcall(function()
        if reservation.category == "food" then
            action = ISEatFoodAction:new(body, item, 1)
        elseif reservation.category == "water" then
            action = ISDrinkFluidAction:new(body, item, useFraction)
        end
    end)
    if not okAction or action == nil then
        clearBinding(body)
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "unsupported-native-use")
        return false, "unsupported-native-use", true
    end
    action.saoSourceReservation = reservation.id
    action.saoSourceActor = tostring(id)
    if not SAO.Needs.queueVerified(action) then
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "native-action-not-queued")
        return false, "native-action-not-queued", true
    end
    SAO.WorldSources.setPhase(reservation.id, id, "using")
    log(tostring(id) .. " begins native " .. reservation.category
        .. " use from " .. reservation.sourceId)
    return true
end

local function queueTransfer(id, body, reservation)
    local okBind, answer = pcall(function()
        return SAOJavaBridge:bindWorldSourceAction(body,
            reservation.sourceId, reservation.fingerprint,
            reservation.revision, reservation.itemId,
            reservation.itemType, reservation.sourceX,
            reservation.sourceY, reservation.sourceZ)
    end)
    local boundX, boundY, boundZ = nil, nil, nil
    if okBind and type(answer) == "string" then
        boundX, boundY, boundZ = string.match(answer,
            "^BOUND:(%-?%d+):(%-?%d+):(%-?%d+)$")
    end
    if not boundX then
        return false, okBind and tostring(answer) or "bind-failed"
    end
    reservation.currentSourceX = tonumber(boundX)
    reservation.currentSourceY = tonumber(boundY)
    reservation.currentSourceZ = tonumber(boundZ)
    if reservation.sourceKind == "vehicle"
        and (not reservation.placeMinX or not reservation.placeMinY
            or not reservation.placeMaxX or not reservation.placeMaxY
            or reservation.currentSourceX < reservation.placeMinX
            or reservation.currentSourceX >= reservation.placeMaxX
            or reservation.currentSourceY < reservation.placeMinY
            or reservation.currentSourceY >= reservation.placeMaxY) then
        clearBinding(body)
        return false, "vehicle-left-observed-place"
    end
    if not (SAO.Standing and SAO.Standing.mayTakeCurrent
        and SAO.Standing.mayTakeCurrent(id, reservation.currentSourceX,
            reservation.currentSourceY, reservation.admission)) then
        clearBinding(body)
        return false, "current-claim-refused"
    end
    -- Provisioning attribution is captured at the same current-source bind
    -- that authorizes the native transfer. Group membership alone is not
    -- enough: the exact source must stand inside that group's held ground.
    local contextOk, context, group, claimIncarnation = pcall(function()
        if not (SAO.Standing and SAO.Standing.provisioningContextAt) then
            return nil, nil
        end
        return SAO.Standing.provisioningContextAt(id,
            reservation.currentSourceX, reservation.currentSourceY)
    end)
    if not contextOk or context == nil then
        clearBinding(body)
        return false, "provisioning-context-unavailable"
    end
    reservation.provisioningContext = tostring(context)
    reservation.provisioningGroup = group and tostring(group) or nil
    reservation.provisioningClaimIncarnation =
        tonumber(claimIncarnation)
    if reservation.provisioningContext == "held-group"
        and (not reservation.provisioningClaimIncarnation
            or reservation.provisioningClaimIncarnation <= 0) then
        clearBinding(body)
        return false, "provisioning-context-unavailable"
    end
    local preObserved = false
    pcall(function()
        local text = SAOJavaBridge:observeWorldChunk(
            math.floor(reservation.currentSourceX / 8),
            math.floor(reservation.currentSourceY / 8))
        local snapshot = SAO.WorldSources.parse(text)
        if snapshot then
            preObserved = SAO.WorldSources.applySnapshot(snapshot,
                reservation.id) == true
        end
    end)
    if not preObserved then
        clearBinding(body)
        return false, "pre-source-observation-refused"
    end
    if not SAO.WorldSources.prepareActionPre(reservation.id, id) then
        clearBinding(body)
        return false, "REVISION_CHANGED"
    end
    local action = nil
    if reservation.sourceKind == "ground" then
        local okWorld, worldItem = pcall(function()
            return SAOJavaBridge:worldSourceActionWorldItem(body)
        end)
        if okWorld and worldItem ~= nil then
            action = ISGrabItemAction:new(body, worldItem, 50)
        end
    else
        local okItem, item = pcall(function()
            return SAOJavaBridge:worldSourceActionItem(body)
        end)
        local okSource, sourceContainer = pcall(function()
            return SAOJavaBridge:worldSourceActionContainer(body)
        end)
        local okPermission, permissionContainer = pcall(function()
            return SAOJavaBridge:worldSourceActionPermissionContainer(body)
        end)
        if okItem and okSource and okPermission and item ~= nil
            and sourceContainer ~= nil and permissionContainer ~= nil then
            action = SAO.Needs.worldSourceTransferAction(body, item,
                sourceContainer, permissionContainer)
        end
    end
    if action == nil or not SAO.Needs.queueVerified(action) then
        clearBinding(body)
        return false, "exact-transfer-not-queued"
    end
    SAO.WorldSources.setPhase(reservation.id, id, "transferring")
    log(tostring(id) .. " transfers exact item "
        .. tostring(reservation.itemType) .. " from " .. reservation.sourceId)
    return true
end

-- Start only after the controller has applied its need/ration/desperation law.
function SU.begin(id, body, place, category, admission)
    if category ~= "food" and category ~= "water" then
        return false, "unsupported-category"
    end
    local reservation, why = SAO.WorldSources.beginAction(place, category,
        id, body, category == "water" and 0.01 or 1, admission)
    if not reservation then return false, why end
    if not SAO.Locomotion.order(id, body, reservation.placeX,
        reservation.placeY, reservation.placeZ) then
        fail(id, body, reservation, "place-route-refused")
        return false, "place-route-refused"
    end
    log(tostring(id) .. " approaches privately observed " .. category
        .. " at place " .. tostring(reservation.placeId))
    return true
end

-- The controller calls this when Locomotion closes a SOURCEWARD leg.
function SU.onMovementDone(id, body, movementStatus)
    local reservation = reservationFor(id)
    if not reservation then return "failed" end
    if not string.find(tostring(movementStatus), "arrived", 1, true) then
        return fail(id, body, reservation,
            "route-ended:" .. tostring(movementStatus))
    end
    if reservation.phase == "approaching-place" then
        local ordered, why = orderInteraction(id, body, reservation)
        if not ordered then return fail(id, body, reservation, why) end
        return "moving"
    end
    if reservation.phase == "approaching-source" then
        local queued, why = queueTransfer(id, body, reservation)
        if not queued then return fail(id, body, reservation, why) end
        return "using"
    end
    return fail(id, body, reservation,
        "movement-in-phase:" .. tostring(reservation.phase))
end

local function applyFreshSnapshot(reservation, body)
    local chunks, seen = {}, {}
    local function add(cx, cy)
        local key = tostring(cx) .. ":" .. tostring(cy)
        if not seen[key] then
            seen[key] = true
            chunks[#chunks + 1] = { x = cx, y = cy }
        end
    end
    if reservation.currentSourceX and reservation.currentSourceY then
        add(math.floor(reservation.currentSourceX / 8),
            math.floor(reservation.currentSourceY / 8))
    end
    add(reservation.chunkX, reservation.chunkY)
    local okBody, bx, by = pcall(function()
        return body:getX(), body:getY()
    end)
    if okBody and bx and by then
        add(math.floor(bx / 8), math.floor(by / 8))
    end
    local accepted, refusal = false, nil
    for _, chunk in ipairs(chunks) do
        local ok, text = pcall(function()
            return SAOJavaBridge:observeWorldChunk(chunk.x, chunk.y)
        end)
        local snapshot = ok and SAO.WorldSources.parse(text) or nil
        if snapshot then
            local applied = SAO.WorldSources.applySnapshot(snapshot,
                reservation.id)
            if applied then
                local reconciled, why = SAO.WorldSources.reconcileActionSnapshot(
                    reservation.id, reservation.actorId,
                    snapshot.header.cx, snapshot.header.cy)
                if reconciled then accepted = true end
                if why == "native-source-conflict"
                    or why == "reservation-lost" then refusal = why end
            end
        end
        if accepted or refusal then break end
    end
    return accepted, refusal
end

local function finalize(id, body, reservation)
    local applied, why = applyFreshSnapshot(reservation, body)
    if not applied then
        if why then return fail(id, body, reservation, why) end
        return "pending"
    end
    -- The actor is standing at the changed native source. Refresh only their
    -- private place belief so a later attempt names the post-transfer revision
    -- (or no longer names a removed ground item); the durable result below
    -- still carries both sides of this action's revision boundary.
    pcall(function()
        local place = SAO.Places.at(reservation.placeX, reservation.placeY)
        if place and tostring(place.id) == tostring(reservation.placeId) then
        SAO.Perception.learnSource(id, place, reservation.sourceId,
            SAO.History.ticks(), "observed-source")
        end
    end)
    local receipt = SAO.WorldSources.finishAction(reservation.id, id)
    if not receipt then return fail(id, body, reservation, "result-refused") end
    -- R9 is a downstream consumer. Failure leaves this receipt unacknowledged
    -- for the population cadence/reload retry; it never rewrites action truth.
    if receipt.status == "completed" and SAO.Provisioning
        and SAO.Provisioning.consumeCompleted then
        pcall(SAO.Provisioning.consumeCompleted, 32)
    end
    clearBinding(body)
    log(tostring(id) .. " source action " .. tostring(receipt.status)
        .. " (" .. tostring(receipt.preRevision) .. " -> "
        .. tostring(receipt.postRevision) .. ")")
    return receipt.status
end

function SU.tick(id, body)
    local reservation = reservationFor(id)
    if not reservation then return "failed" end
    if reservation.phase == "transferring" then
        if SAO.Needs.busy(body) then return "pending" end
        local queued, why, reconcile = queueNativeUse(id, body, reservation)
        if not queued then
            if reconcile then return finalize(id, body, reservation) end
            return fail(id, body, reservation, why)
        end
        return "pending"
    end
    if reservation.phase == "using" then
        if SAO.Needs.busy(body) then return "pending" end
        -- The exact item already left the source. Losing the timed-action
        -- callback cannot turn that physical delta into an abandoned conflict
        -- or an unspent release; keep ownership and reconcile with no credit.
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "native-action-ended-without-result")
        return finalize(id, body, reservation)
    end
    if reservation.phase == "native-complete" then
        return finalize(id, body, reservation)
    end
    return "pending"
end

-- Reconstruct executable work from the durable owner. An exact carried item
-- resumes at native use; otherwise the actor re-approaches and revalidates the
-- source revision. Ambiguity never becomes an inferred success.
function SU.runtimeState(reservation)
    if not reservation then return nil end
    if reservation.phase == "approaching-place"
        or reservation.phase == "approaching-source" then
        return "SOURCEWARD"
    end
    if reservation.phase == "transferring" or reservation.phase == "using"
        or reservation.phase == "native-complete" then
        return "SOURCEUSE"
    end
    return nil
end

function SU.resume(id, body)
    local reservation = reservationFor(id)
    if not reservation then return nil end
    if reservation.phase == "native-complete" then return "SOURCEUSE" end
    if (reservation.phase == "transferring" or reservation.phase == "using")
        and SAO.Needs and SAO.Needs.busy and SAO.Needs.busy(body) then
        -- A same-session state assignment may fault after the vanilla action
        -- was accepted. Repair only the projection; never queue or reroute a
        -- second leg beside the action already owned by the body.
        return "SOURCEUSE"
    end
    if reservation.phase == "using" and reservation.transferProven
        and carriedItem(body, reservation) == nil then
        -- Transfer is proven, but absence from inventory cannot distinguish
        -- consumption from loss or restore omission. Preserve the source
        -- delta without awarding a need consequence.
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "carried-item-absent-after-reload")
        return "SOURCEUSE"
    end
    if (reservation.phase == "transferring" or reservation.phase == "using")
        and carriedItem(body, reservation) ~= nil then
        local queued, why, reconcile = queueNativeUse(id, body, reservation)
        if queued then return "SOURCEUSE" end
        if reconcile then return "SOURCEUSE" end
        fail(id, body, reservation, why)
        return nil
    end
    reservation.phase = "approaching-place"
    if SAO.Locomotion.order(id, body, reservation.placeX,
        reservation.placeY, reservation.placeZ) then
        return "SOURCEWARD"
    end
    fail(id, body, reservation, "resume-route-refused")
    return nil
end

-- Queue clearing invokes the tagged vanilla action's stop wrapper first. If
-- it physically applied a partial use, finish that interrupted receipt;
-- otherwise release the still-unspent reservation.
function SU.interrupt(id, body, reason)
    local reservation = reservationFor(id)
    if not reservation then
        clearBinding(body)
        return false
    end
    if reservation.phase == "native-complete" then
        local outcome = finalize(id, body, reservation)
        if reason == "death" and outcome == "pending" then
            fail(id, body, reservation, "death-before-source-reconcile")
        end
    elseif reservation.transferProven
        or ((reservation.phase == "transferring"
            or reservation.phase == "using")
            and carriedItem(body, reservation) ~= nil) then
        -- The vanilla transfer already changed the world even when a threat
        -- prevents eating or drinking, or the carried item is no longer
        -- inspectable. Preserve that physical delta as a zero-use interruption
        -- and reconcile it instead of calling it an unspent release.
        SAO.WorldSources.markTransferred(reservation.id, id)
        SAO.WorldSources.markNative(reservation.id, id, "interrupted", 0,
            "transferred-before-" .. tostring(reason or "interrupted"))
        local outcome = finalize(id, body, reservation)
        if reason == "death" and outcome == "pending" then
            fail(id, body, reservation, "death-before-source-reconcile")
        end
    else
        SAO.WorldSources.release(reservation.id, reason or "interrupted")
        clearBinding(body)
    end
    return true
end

-- Body ownership cannot move to another controller while a source action
-- still owns a route, timed action or physical source delta. Stop the queued
-- leg first so its native callback can report any effect, then settle or
-- release the durable reservation. A false answer means reconciliation still
-- owns the body and the transfer must retry later.
function SU.closeForOwnershipTransfer(id, body, reason)
    local reservation = reservationFor(id)
    if not reservation then return true end
    if (reservation.phase == "approaching-place"
        or reservation.phase == "approaching-source")
        and SAO.Locomotion and SAO.Locomotion.cancel then
        pcall(SAO.Locomotion.cancel, id)
    end
    if (reservation.phase == "transferring" or reservation.phase == "using")
        and body and ISTimedActionQueue then
        pcall(function() ISTimedActionQueue.clear(body) end)
    end
    SU.interrupt(id, body, reason or "body-ownership-transfer")
    return reservationFor(id) == nil
end

-- Every controller transition passes here. SOURCEWARD -> SOURCEUSE is the one
-- continuation inside the same action; every other exit closes ownership
-- before a route, combat action or ordinary state can compete with it.
function SU.beforeStateChange(id, body, fromState, toState, reason)
    fromState, toState = tostring(fromState or ""), tostring(toState or "")
    local reservation = reservationFor(id)
    if not reservation then return true end
    -- SourceUse.begin durably creates the owner and its first route before the
    -- Controller can project SOURCEWARD. This is the initial projection of
    -- that same action, not an exit that should cancel it.
    if toState == "SOURCEWARD"
        and reservation.phase == "approaching-place" then return true end
    if fromState == "SOURCEWARD" and toState == "SOURCEUSE"
        and (reservation.phase == "transferring"
            or reservation.phase == "using"
            or reservation.phase == "native-complete") then return true end
    return SU.closeForOwnershipTransfer(id, body,
        reason or ("state-exit:" .. fromState .. ":" .. toState))
end

-- Runtime body teardown does not cancel a durable action. A later adopt will
-- reconstruct it from the reservation and the actual item/source state.
function SU.detach(body)
    if body then clearBinding(body) end
end

local function settleTimedAction(action, completed)
    if not action.saoSourceReservation or action.saoSourceSettled then return end
    local ok, outcome = pcall(function()
        return SAOJavaBridge:finishWorldSourceUse(action.character,
            completed == true)
    end)
    local applied, status, quantity, detail = nil, nil, nil, nil
    if ok and type(outcome) == "string" then
        applied, status, quantity, detail = string.match(outcome,
            "^(APPLIED):([^:]+):([^:]+):(.*)$")
    end
    if applied and SAO.WorldSources.markNative(action.saoSourceReservation,
        action.saoSourceActor, status, tonumber(quantity), detail) then
        action.saoSourceSettled = true
        return
    end
    -- Vanilla may already have consumed or altered the transferred item. A
    -- bridge exception or malformed verdict cannot prove the quantity, so the
    -- durable result owns the source delta but awards no survival credit.
    SAO.WorldSources.markNative(action.saoSourceReservation,
        action.saoSourceActor, "interrupted", 0,
        ok and "native-settlement-invalid" or "native-settlement-refused")
    action.saoSourceSettled = true
end

if ISEatFoodAction and not ISEatFoodAction.SAOSourceUseWrapped then
    ISEatFoodAction.SAOSourceUseWrapped = true
    local baseEatComplete = ISEatFoodAction.complete
    local baseEatStop = ISEatFoodAction.stop
    function ISEatFoodAction:complete()
        local result = baseEatComplete(self)
        settleTimedAction(self, true)
        return result
    end
    function ISEatFoodAction:stop()
        local result = baseEatStop(self)
        settleTimedAction(self, false)
        return result
    end
end

if ISDrinkFluidAction and not ISDrinkFluidAction.SAOSourceUseWrapped then
    ISDrinkFluidAction.SAOSourceUseWrapped = true
    local baseDrinkComplete = ISDrinkFluidAction.complete
    local baseDrinkStop = ISDrinkFluidAction.stop
    function ISDrinkFluidAction:complete()
        local result = baseDrinkComplete(self)
        settleTimedAction(self, true)
        return result
    end
    function ISDrinkFluidAction:stop()
        local result = baseDrinkStop(self)
        settleTimedAction(self, false)
        return result
    end
end

return SU
