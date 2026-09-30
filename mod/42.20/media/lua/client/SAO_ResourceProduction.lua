-- Native resource transformations over this person's remembered world and held tools.
require "TimedActions/ISTakeWaterAction"
SAO = SAO or {}
SAO.ResourceProduction = SAO.ResourceProduction or {}
local R = SAO.ResourceProduction
local KNOWN_FIXTURE_SEARCH_RADIUS = 32
local MAX_CARRIED_RELIEF_ITEMS = 240
local runtime = {}
local sourceRefresh = {}
local refreshHandledSource
local function retireRefresh(id, reason)
    local pending = sourceRefresh[id]
    if pending then
        pending.receipt.sourceObservation.status = "unconfirmed"
        pending.receipt.sourceObservation.detail = reason or "handled-source-observation-retired"
        sourceRefresh[id] = nil
    end
end
local function hours() return SAO.History.countyHours() end
local function owner(id, body)
    local rec = SAO.Identity.get(id)
    local agent = SAO.Controller and SAO.Controller.agents[id]
    if not rec or rec.dead or rec.bodyOwner ~= nil or rec.zaoTransferPending or rec.crossedTransferPending
        or not body or SAO.Body.active[id] ~= body or SAO.Body.foreign[id] ~= nil
        or SAO.Body.get(id) ~= body or not agent or agent.rec ~= rec or agent.passive
        or agent.state == "PASSIVE" then return nil end
    local data = body:getModData()
    if tostring(data.SAOPersonId or "") ~= tostring(id) or data.SAOExternalToken ~= rec.bodyOwnerToken
        or data.SAOExternalOwner ~= nil or data.ZAOOwned == true
        or SAOJavaBridge:isShell(body) ~= true or not body:isExistInTheWorld()
        or body:isDead() or body:isAsleep() or not body:getCurrentSquare()
        or body:getVehicle() ~= nil or body:isAttacking() or body:isAiming()
        or body:isClimbing() or body:isClimbingRope() then return nil end
    return rec
end
local function same(a, b) return tostring(a or "") == tostring(b or "") end
local function admitted(belief, id, revision)
    for entry in string.gmatch(tostring(belief.sourceRevision or ""), "[^,]+") do
        if entry == tostring(id) .. "@" .. tostring(revision) then return true end
    end
    return false
end
function R.privatelyKnown(id, option)
    if type(option) ~= "table" or option.kind ~= "refill-water" or option.category ~= "water"
        or type(option.sourceId) ~= "string" or string.sub(option.sourceId, 1, 2) ~= "F:"
        or type(option.place) ~= "table" then return false end
    local known = SAO.Perception.knownPlaces(id, true) or {}
    local belief = known[option.place.id] or known[tostring(option.place.id)]
    local fact = belief and belief.sourceFacts and belief.sourceFacts[option.sourceId]
    return fact ~= nil and fact.kind == "fluid" and fact.state == "available"
        and same(fact.id, option.sourceId) and fact.fingerprint == option.fingerprint
        and fact.revision == option.sourceRevision and admitted(belief, option.sourceId, option.sourceRevision)
        and tonumber(fact.quantities and fact.quantities.water or 0) > 0
        and fact.x == option.sourceX and fact.y == option.sourceY and fact.z == option.sourceZ
end
local function vessel(body, item)
    if not item or item:getContainer() ~= body:getInventory() or not item:canStoreWater() then return nil end
    local fluid = item:getFluidContainer()
    if not fluid or fluid:isPoisonous() or fluid:isTainted() then return nil end
    local amount, capacity = fluid:getAmount(), fluid:getCapacity()
    if amount ~= amount or capacity ~= capacity or amount < 0 or capacity - amount <= 0.01
        or amount > 0 and not fluid:isWaterSource() then return nil end
    return fluid, amount, capacity
end
local function carried(body, id, fullType)
    local items, found = SAOJavaBridge:privateCarriedItems(body), nil
    for index = 0, math.min(items:size(), 128) - 1 do
        local item = items:get(index)
        if same(item:getID(), id) then
            if found or not same(item:getFullType(), fullType) then return nil end
            found = item
        end
    end
    return found
end
function R.options(id, body, category)
    local options = {}
    if refreshHandledSource then refreshHandledSource(id) end
    if category ~= "water" or not owner(id, body) or SAO.Needs.busy(body) then return options end
    local vessels, items = {}, SAOJavaBridge:privateCarriedItems(body)
    for index = 0, math.min(items:size(), 128) - 1 do
        local item = items:get(index)
        local fluid, amount, capacity = vessel(body, item)
        if fluid then vessels[#vessels + 1] = { itemId = item:getID(), itemType = item:getFullType(),
            beforeAmount = amount, capacity = capacity } end
        if #vessels >= 8 then break end
    end
    if #vessels == 0 then return options end
    local checked = 0
    for placeId, belief in pairs(SAO.Perception.knownPlaces(id, true) or {}) do
        for sourceId, fact in pairs(belief.sourceFacts or {}) do
            checked = checked + 1
            if checked > 128 then return options end
            if fact.kind == "fluid" and fact.state == "available" and admitted(belief, sourceId, fact.revision)
                and tonumber(fact.quantities and fact.quantities.water or 0) > 0
                and tonumber(fact.x) and tonumber(fact.y) and tonumber(fact.z)
                and SAO.Standing.mayAttemptBelieved(id, fact.x, fact.y, "standing") == true then
                local dx, dy = fact.x + 0.5 - body:getX(), fact.y + 0.5 - body:getY()
                if dx * dx + dy * dy <= KNOWN_FIXTURE_SEARCH_RADIUS * KNOWN_FIXTURE_SEARCH_RADIUS then
                    for _, held in ipairs(vessels) do
                        options[#options + 1] = { kind = "refill-water", owner = "SAO.ResourceProduction",
                            category = "water", known = true, sourceId = sourceId, sourceRevision = fact.revision,
                            fingerprint = fact.fingerprint, sourceX = fact.x, sourceY = fact.y, sourceZ = fact.z,
                            place = { id = placeId, sourceId = belief.sourceId, cx = belief.cx, cy = belief.cy, z = belief.z,
                                minX = belief.minX, maxX = belief.maxX, minY = belief.minY, maxY = belief.maxY },
                            itemId = held.itemId, itemType = held.itemType, beforeAmount = held.beforeAmount,
                            capacity = held.capacity, quantityUnit = "fluid", distance = math.sqrt(dx * dx + dy * dy) }
                        if #options >= 16 then return options end
                    end
                end
            end
        end
    end
    return options
end
local function queued(action)
    return action and ISTimedActionQueue and ISTimedActionQueue.hasAction(action) == true
end
local function permission(id, work)
    return SAO.Standing.mayTakeCurrent(id, work.sourceX, work.sourceY, "standing") == true
end
local function physical(rt, work)
    return permission(work.actorId, work) and SAOJavaBridge:worldRefillValid(rt.body, rt.fixture,
        work.sourceId, work.fingerprint, work.sourceX, work.sourceY, work.sourceZ) == true
end
local function rememberedPlace(id, option)
    local known = SAO.Perception.knownPlaces(id, true) or {}
    local belief = known[option.place.id] or known[tostring(option.place.id)]
    local fact = belief and belief.sourceFacts and belief.sourceFacts[option.sourceId]
    if not fact then return nil end
    return { id = option.place.id, sourceId = belief.sourceId, cx = belief.cx, cy = belief.cy, z = belief.z,
        minX = belief.minX, maxX = belief.maxX, minY = belief.minY, maxY = belief.maxY }, fact.chunkX, fact.chunkY
end
-- Native handling reveals the changed fixture to its actor, not the rest of
-- the chunk or anybody else's mind. The observation keeps the pre-transfer
-- revision on the receipt intact for exact admission/outcome matching.
refreshHandledSource = function(id)
    local pending = sourceRefresh[id]
    if not pending then return end
    local receipt, rt = pending.receipt, pending.rt
    local observation = receipt.sourceObservation
    local rec = owner(id, rt.body)
    observation.attempts = observation.attempts + 1
    local function stop(detail)
        observation.status, observation.detail = "unconfirmed", detail
        sourceRefresh[id] = nil
    end
    if not rec or rec.resourceProductionWork and rec.resourceProductionWork.id ~= receipt.id
        or not physical(rt, receipt) then return stop("handled-source-no-longer-accessible") end
    local sources, perception = SAO.WorldSources, SAO.Perception
    if not receipt.place or not receipt.sourceChunkX or not receipt.sourceChunkY
        or not sources or not sources.observeChunk or not sources.beliefFact then
        return stop("handled-source-observation-unavailable")
    end
    local observed, accepted, detail = pcall(sources.observeChunk, receipt.sourceChunkX, receipt.sourceChunkY)
    if not observed or accepted ~= true then
        observation.detail = observed and tostring(detail) or "handled-source-observation-error"
        if observation.attempts >= 3 then stop(observation.detail) end
        return
    end
    if not owner(id, rt.body) or not physical(rt, receipt) then return stop("handled-source-changed-during-observation") end
    local fact = sources.beliefFact(receipt.sourceId)
    if not fact or fact.kind ~= "fluid" or not same(fact.id, receipt.sourceId)
        or fact.fingerprint ~= receipt.fingerprint or fact.x ~= receipt.sourceX
        or fact.y ~= receipt.sourceY or fact.z ~= receipt.sourceZ
        or fact.chunkX ~= receipt.sourceChunkX or fact.chunkY ~= receipt.sourceChunkY then
        return stop("handled-source-identity-unconfirmed")
    end
    local learn = receipt.place.sourceId and perception.learnInspectedSource or perception.learnSource
    local tick = SAO.History.ticks and SAO.History.ticks() or math.floor(hours() * 9000)
    local learned, result = pcall(learn, id, receipt.place, receipt.sourceId, tick, "observed-native-refill")
    if not learned or result ~= true then return stop("handled-source-private-refresh-refused") end
    local known = perception.knownPlaces(id, true) or {}
    local belief = known[receipt.place.id] or known[tostring(receipt.place.id)]
    local ownFact = belief and belief.sourceFacts and belief.sourceFacts[receipt.sourceId]
    if not ownFact or ownFact.fingerprint ~= fact.fingerprint or ownFact.revision ~= fact.revision
        or not admitted(belief, receipt.sourceId, fact.revision) then
        return stop("handled-source-private-refresh-unconfirmed")
    end
    observation.status, observation.detail, observation.revision, observation.atHours =
        "confirmed", "observed-native-refill", fact.revision, hours()
    sourceRefresh[id] = nil
end
local function measured(rt, work)
    if not rt or not rt.item or carried(rt.body, work.itemId, work.itemType) ~= rt.item
        or rt.item:getContainer() ~= rt.body:getInventory() then return work.beforeAmount, false, false end
    local fluid = rt.item:getFluidContainer()
    return fluid:getAmount(), true, fluid:getAmount() > 0 and fluid:isWaterSource()
        and not fluid:isPoisonous() and not fluid:isTainted()
end
function R.outcome(id, workId)
    local rec = SAO.Identity.get(id)
    for _, receipt in ipairs(rec and rec.resourceProductionOutcomes or {}) do
        if receipt.id == workId then return receipt end
    end
end
local function reconcile(id)
    local rec, planning = SAO.Identity.get(id), SAO.ProceduralPlanning
    for _, receipt in ipairs(rec and rec.resourceProductionOutcomes or {}) do
        if receipt.purposeId and not receipt.purposeDelivered and planning and planning.consumeProductionResult
            and planning.consumeProductionResult(id, receipt) then receipt.purposeDelivered = true end
        if not receipt.experienceDelivered and R.onOutcome then
            local delivered, result = pcall(R.onOutcome, id, receipt)
            if delivered and result == true then receipt.experienceDelivered = true end
        end
    end
end
local function finish(id, status, detail)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    local work = rec and rec.resourceProductionWork
    if not work or rt and rt.workId ~= work.id then return status end
    local after, held, clean = measured(rt, work)
    local gain = rt and rt.nativeGain or 0
    if status == "completed" and (not rt or not rt.nativeCompleted or not held or not clean
        or gain <= 0.0001 or after <= work.beforeAmount + 0.0001) then
        status, detail = "failed", "native-filled-water-not-proven"
    end
    if status ~= "completed" and status ~= "interrupted" then status = "failed" end
    local receipt = { id = work.id, workId = work.id, sequence = work.sequence, actorId = id,
        kind = work.kind, sourceId = work.sourceId, sourceRevision = work.sourceRevision,
        place = work.place, sourceX = work.sourceX, sourceY = work.sourceY, sourceZ = work.sourceZ,
        sourceChunkX = work.sourceChunkX, sourceChunkY = work.sourceChunkY,
        fingerprint = work.fingerprint, itemId = work.itemId, itemType = work.itemType,
        purposeId = work.purposeId, purposeStepId = work.purposeStepId, token = "resource:filled",
        cognitiveToken = work.cognitiveToken,
        status = status, detail = detail, startedAt = work.startedAt, atHours = hours(),
        beforeAmount = work.beforeAmount, afterAmount = after, nativeGain = gain, held = held, clean = clean,
        nativeCredit = status == "completed" and work.id or nil }
    receipt.sourceObservation = { status = "unconfirmed", detail = "no-bound-native-transfer", attempts = 0 }
    if rt and gain > 0.0001 and rt.fixture then
        sourceRefresh[id] = { receipt = receipt, rt = rt }
        refreshHandledSource(id)
    end
    rec.resourceProductionOutcomes = rec.resourceProductionOutcomes or {}
    rec.resourceProductionOutcomes[#rec.resourceProductionOutcomes + 1] = receipt
    if #rec.resourceProductionOutcomes > 32 then table.remove(rec.resourceProductionOutcomes, 1) end
    rec.resourceProductionWork, runtime[id] = nil, nil
    if rt and rt.route and SAO.Locomotion.jobs[id] == rt.route then pcall(SAO.Locomotion.cancel, id) end
    if SAO.Observation then pcall(SAO.Observation.record, id, "ResourceProduction", status,
        status == "completed" and "Filled a carried vessel with water" or "Water collection: " .. tostring(detail)) end
    reconcile(id)
    return status
end
local function bound(action)
    local rec, rt = owner(action.actorId, action.character), runtime[action.actorId]
    local work = rec and rec.resourceProductionWork
    return work and rt and not rt.cancelling and rt.action == action and rt.body == action.character and work.id == action.workId
        and action.bodyToken == rec.bodyOwnerToken and rt.item == action.item
        and carried(action.character, work.itemId, work.itemType) == action.item
        and action.item:getContainer() == action.character:getInventory() and physical(rt, work)
end
local SAORefillWaterAction = ISTakeWaterAction:derive("SAORefillWaterAction")
function SAORefillWaterAction:isValid()
    return bound(self) and ISTakeWaterAction.isValid(self)
end
function SAORefillWaterAction:updateUse(delta)
    if not bound(self) then return end
    local rt = runtime[self.actorId]
    local before = self.item:getFluidContainer():getAmount()
    ISTakeWaterAction.updateUse(self, delta)
    local after = self.item:getFluidContainer():getAmount()
    rt.nativeGain = rt.nativeGain + math.max(0, after - before)
end
function SAORefillWaterAction:complete()
    if not bound(self) then self.saoEnded, self.saoReason = "unavailable", "refill-owner-or-source-changed" return false end
    local result = ISTakeWaterAction.complete(self)
    local rt = runtime[self.actorId]
    if rt then rt.nativeCompleted = result == true end
    self.saoEnded = result == true and "completed" or "unavailable"
    return result
end
function SAORefillWaterAction:stop()
    self.saoEnded, self.saoReason = "interrupted", self.saoReason or "native-refill-stopped"
    ISTakeWaterAction.stop(self)
end
function SAORefillWaterAction:forceCancel()
    self.saoEnded, self.saoReason = "interrupted", self.saoReason or "native-refill-cancelled"
end
local function queue(id, rt, work)
    if not permission(id, work) then return false, "current-water-permission-refused" end
    local fixture = SAOJavaBridge:worldRefillObject(rt.body, work.sourceId, work.fingerprint,
        work.sourceRevision, work.sourceX, work.sourceY, work.sourceZ)
    if not fixture then return false, "remembered-water-fixture-not-accessible" end
    local fluid, amount = vessel(rt.body, rt.item)
    if not fluid or amount ~= work.beforeAmount then return false, "held-vessel-state-changed" end
    rt.fixture = fixture
    local action = SAORefillWaterAction:new(rt.body, rt.item, fixture, false)
    action.actorId, action.workId, action.bodyToken = id, work.id, rt.body:getModData().SAOExternalToken
    rt.action = action
    if not tonumber(action.waterUnit) or action.waterUnit <= 0 then return false, "native-vessel-capacity-unavailable" end
    if not SAO.Needs.queueVerified(action) then return false, "native-refill-queue-refused" end
    work.stage = "filling"
    return true
end
function R.begin(id, body, step, context)
    context = context or {}
    refreshHandledSource(id)
    local rec = owner(id, body)
    local option = { kind = step and (step.kind or step.productionKind or step.target), category = "water",
        sourceId = step and step.sourceId, sourceRevision = step and step.sourceRevision,
        fingerprint = step and step.fingerprint, sourceX = step and step.sourceX,
        sourceY = step and step.sourceY, sourceZ = step and step.sourceZ, place = step and step.place }
    if not rec or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or SAO.Needs.busy(body) or not R.privatelyKnown(id, option) then return false end
    local place, chunkX, chunkY = rememberedPlace(id, option)
    local existingRoute = SAO.Locomotion.jobs[id]
    if existingRoute and not existingRoute.done then return false end
    local item = carried(body, step.itemId, step.itemType)
    local fluid, amount = vessel(body, item)
    if not fluid then return false end
    local target = SAOJavaBridge:worldRefillTarget(body, step.sourceId, step.fingerprint,
        step.sourceRevision, step.sourceX, step.sourceY, step.sourceZ)
    local x, y, z = string.match(tostring(target), "^READY:(%-?%d+):(%-?%d+):(%-?%d+)$")
    if not x then return false end
    rec.resourceProductionSequence = (rec.resourceProductionSequence or 0) + 1
    local admittedNeeds = SAO.Needs.read(body) or {}
    local readHealth, admittedHealth = pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    local work = { id = "resource-production/" .. tostring(id) .. "/" .. tostring(rec.resourceProductionSequence),
        sequence = rec.resourceProductionSequence, actorId = id, kind = "refill-water",
        sourceId = step.sourceId, sourceRevision = step.sourceRevision, fingerprint = step.fingerprint,
        sourceX = step.sourceX, sourceY = step.sourceY, sourceZ = step.sourceZ,
        place = place, sourceChunkX = chunkX, sourceChunkY = chunkY,
        itemId = item:getID(), itemType = item:getFullType(), beforeAmount = amount,
        requestedPurposeId = context.purposeId, requestedPurposeStepId = context.purposeStepId,
        purposeId = context.purposeId, purposeStepId = context.purposeStepId,
        admittedNeeds = { hunger = tonumber(admittedNeeds.hunger), thirst = tonumber(admittedNeeds.thirst),
            fatigue = tonumber(admittedNeeds.fatigue) },
        admittedHealth = readHealth and tonumber(admittedHealth) or nil,
        startedAt = hours(), stage = "approaching", token = "resource:filled" }
    local rt = { body = body, item = item, workId = work.id, nativeGain = 0 }
    rec.resourceProductionWork, runtime[id] = work, rt
    local started, why
    local fixture = SAOJavaBridge:worldRefillObject(body, work.sourceId, work.fingerprint,
        work.sourceRevision, work.sourceX, work.sourceY, work.sourceZ)
    if fixture then started, why = queue(id, rt, work)
    elseif SAO.Standing.mayAttemptBelieved(id, tonumber(x), tonumber(y), "standing") == true then
        started = SAO.Locomotion.order(id, body, tonumber(x), tonumber(y), tonumber(z))
        rt.route = started and SAO.Locomotion.jobs[id] or nil
        if not rt.route or rt.route.body ~= body then started = false end
    end
    if not started then finish(id, "unavailable", why or "native-water-approach-refused") return false end
    local planning = SAO.ProceduralPlanning
    if not planning or not planning.admitProduction or planning.admitProduction(id, work) ~= true then
        R.interrupt(id, body, "resource-purpose-admission-refused") return false
    end
    if SAO.Cognition and SAO.Cognition.capture then
        local captured, token = pcall(SAO.Cognition.capture, id, "ResourceProduction")
        if captured then work.cognitiveToken = token end
    end
    return true
end
function R.interrupt(id, body, reason)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    if rt and body and rt.body ~= body then return false end
    if not rec or not rec.resourceProductionWork then
        retireRefresh(id, "handled-source-observation-retired")
        if rt and queued(rt.action) then
            pcall(function() rt.action:forceStop() end)
            if queued(rt.action) and SAO.Body.get(id) == rt.body then return false end
        end
        if rt and rt.route and SAO.Locomotion.jobs[id] == rt.route then pcall(SAO.Locomotion.cancel, id) end
        runtime[id] = nil
        return true
    end
    if rt and rt.action and rt.action.saoEnded == "completed" and not queued(rt.action) then
        finish(id, "completed", "native-refill-completed-before-interruption")
        return true
    end
    if rt then rt.cancelling, rt.cancelReason = true, reason or "higher-priority-work" end
    if rt and queued(rt.action) then
        rt.action.saoReason = reason or "higher-priority-work"
        pcall(function() rt.action:forceStop() end)
        if queued(rt.action) then return false end
    end
    if rt and rt.route and SAO.Locomotion.jobs[id] == rt.route and not rt.route.done then
        local ok, cancelled = pcall(function() return SAOJavaBridge:cancelMove(rt.body) end)
        if not ok or cancelled ~= "MOVE_CANCELLED" then return false end
    end
    finish(id, "interrupted", reason or "higher-priority-work")
    return true
end
function R.detach(id, body, reason)
    retireRefresh(id, "handled-source-body-retired")
    local closed = R.interrupt(id, body, reason or "body-retired")
    -- Retiring an active partial fill can create its final observation retry.
    -- A retired body's native handles cannot survive that finalization either.
    retireRefresh(id, "handled-source-body-retired")
    return closed
end
-- The exact water-producing owner can answer its initiating thirst. Already
-- usable carried water instead permits the ordinary immediate drink owner.
function R.servesNeed(id, body, category)
    local rec, rt = owner(id, body), runtime[id]
    local work = rec and rec.resourceProductionWork
    if category ~= "water" or not work or work.kind ~= "refill-water"
        or not rt or rt.body ~= body or rt.workId ~= work.id or rt.cancelling
        or not SAO.Needs.portableWaterItem then return false end
    local items = SAOJavaBridge:privateCarriedItems(body)
    for index = 0, math.min(items:size(), MAX_CARRIED_RELIEF_ITEMS) - 1 do
        local item = items:get(index)
        local fillingOwnVessel = item == rt.item and work.stage == "filling" and queued(rt.action)
            and rt.nativeGain > 0 and work.beforeAmount <= 0.01
        if not fillingOwnVessel and SAO.Needs.portableWaterItem(item) then return false end
    end
    return true
end
function R.needInterruption(id, body, needs, emergencyHunger)
    local rec = owner(id, body)
    local work = rec and rec.resourceProductionWork
    if not work or not needs then return false end
    local rt = runtime[id]
    if rt and rt.action and rt.action.saoEnded == "completed" and not queued(rt.action) then return false end
    if SAO.Needs.bleeding(body) > 0 or needs.fatigue >= 0.7 then return true end
    local prior = work.admittedNeeds or {}
    if needs.thirst >= SAO.Disposition.drinkAt(id) and not R.servesNeed(id, body, "water") then return true end
    if needs.hunger >= SAO.Disposition.eatAt(id) then
        local ok, readyFood = pcall(function() return SAOJavaBridge:findCarriedFood(body) end)
        if ok and readyFood ~= nil or not prior.hunger or prior.hunger < SAO.Disposition.eatAt(id)
            or emergencyHunger and needs.hunger >= emergencyHunger and prior.hunger < emergencyHunger then return true end
    end
    local ok, health = pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    return ok and work.admittedHealth and health < work.admittedHealth or false
end
local function tick(id, body)
    refreshHandledSource(id)
    reconcile(id)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    local work = rec and rec.resourceProductionWork
    if not work then return "idle" end
    if not rt then
        -- A module reload can leave the exact native action in the queue.
        -- Retire that action before releasing the durable body claim; missing
        -- transient transfer measurements cannot be reconstructed as credit.
        local q = ISTimedActionQueue and ISTimedActionQueue.queues[body]
        for _, action in ipairs(q and q.queue or {}) do
            if action.actorId == id and action.workId == work.id and action.character == body
                and action.bodyToken == body:getModData().SAOExternalToken then
                pcall(function() action:forceStop() end)
                if queued(action) then return "cancelling" end
            end
        end
        return finish(id, "unavailable", "native-resource-attempt-unavailable-after-reload")
    end
    if rt.body ~= body or not owner(id, body) then
        return R.interrupt(id, rt.body, "resource-body-owner-changed") and "interrupted" or "cancelling"
    end
    if rt.cancelling then
        return R.interrupt(id, body, rt.cancelReason) and "interrupted" or "cancelling"
    end
    if hours() - work.startedAt > 0.5 then
        return R.interrupt(id, body, "resource-attempt-time-limit") and "interrupted" or "cancelling"
    end
    if work.stage == "approaching" then
        if not rt.route or SAO.Locomotion.jobs[id] ~= rt.route then return finish(id, "unavailable", "native-water-route-owner-lost") end
        SAO.Locomotion.tick(id)
        if not rt.route.done then return "moving" end
        if rt.route.result ~= "arrived" then return finish(id, "unavailable", "native-water-route:" .. tostring(rt.route.result)) end
        local started, why = queue(id, rt, work)
        if not started then return finish(id, "unavailable", why) end
        return "filling"
    end
    if queued(rt.action) then return "filling" end
    return finish(id, rt.action and rt.action.saoEnded or "unavailable",
        rt.action and rt.action.saoReason or "native-refill-queue-lost")
end
function R.tick(id, body)
    local ok, result = pcall(tick, id, body)
    if ok then return result end
    if R.interrupt(id, body, "native-resource-owner-error") then return "unavailable" end
    return "cancelling"
end
function R.snapshot(id)
    local rec = SAO.Identity.get(id)
    local work = rec and rec.resourceProductionWork
    return work and { stage = work.stage, kind = work.kind, itemType = work.itemType,
        sourceId = work.sourceId, startedAt = work.startedAt, purposeId = work.purposeId }
end
function R.reset()
    for id, rt in pairs(runtime) do R.interrupt(id, rt.body, "world-reset") end
    for id in pairs(sourceRefresh) do retireRefresh(id, "handled-source-observation-retired") end
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(R.reset) end
return R
