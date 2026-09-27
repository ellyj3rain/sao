-- Exact transfers, native appliance heat and completed retrieval own cooking.
require "TimedActions/ISToggleStoveAction"
SAO = SAO or {}
SAO.Cooking = SAO.Cooking or {}
local C = SAO.Cooking
if C.reset then C.reset() end
local runtime = {}
local function hours() return SAO.History.countyHours() end
local function owner(id, body)
    local rec = SAO.Identity.get(id)
    if not rec or tostring(rec.id or "") ~= tostring(id) or rec.dead or not body or SAO.Body.get(id) ~= body
        or rec.zaoTransferPending or rec.crossedTransferPending then return nil end
    local data = body:getModData()
    if tostring(data.SAOPersonId or "") ~= tostring(id)
        or data.SAOExternalToken ~= rec.bodyOwnerToken then return nil end
    local agent = SAO.Controller and SAO.Controller.agents and SAO.Controller.agents[id]
    if rec.bodyOwner == nil then
        if SAO.Body.active[id] ~= body or SAO.Body.foreign[id] ~= nil or not agent or agent.rec ~= rec
            or agent.passive or agent.state == "PASSIVE" or data.SAOExternalOwner ~= nil
            or data.ZAOOwned == true then return nil end
    elseif rec.bodyOwner == "ZAO" then
        local controlled = ZAO and ZAO.Controller and ZAO.Controller.controlled
        if type(rec.bodyOwnerToken) ~= "string" or rec.bodyOwnerToken == ""
            or SAO.Body.foreign[id] ~= body or SAO.Body.active[id] ~= nil or agent ~= nil
            or not controlled or controlled[id] ~= body or data.SAOExternalOwner ~= "ZAO"
            or data.ZAOOwned ~= true then return nil end
    else return nil end
    if SAOJavaBridge:isShell(body) ~= true or not body:isExistInTheWorld()
        or not body:getCurrentSquare() or body:getVehicle() ~= nil
        or body:isAttacking() or body:isAiming() or body:isClimbing() or body:isClimbingRope() then return nil end
    return rec
end
local function allowed(id, row)
    return SAO.Standing.mayTakeCurrent(id, row.sourceX, row.sourceY, "standing") == true
end
local function record(id, phase, detail)
    if SAO.Observation then pcall(SAO.Observation.record, id, "Cooking", phase, detail) end
end
local outcomeText = {
    completed = "Cooked and collected food", interrupted = "Food preparation interrupted",
    unavailable = "Could not finish preparing food", ["no-effect"] = "Food preparation stopped",
}
local reasonText = {
    ["food-burnt"] = "The food burned", ["appliance-unpowered"] = "The stove has no power",
    ["appliance-unlit"] = "The fire is not lit", ["current-appliance-permission-refused"] = "Use of the cooking area is no longer allowed",
    ["current-food-permission-refused"] = "Taking the food is no longer allowed",
}
local function releaseRuntime(id, rt, workId)
    if not rt then return end
    if rt.route and SAO.Locomotion and SAO.Locomotion.jobs and SAO.Locomotion.jobs[id] == rt.route then
        pcall(SAO.Locomotion.cancel, id)
    end
    if rt.toggle then rt.toggle.saoCancelled = true end
    pcall(function() SAOJavaBridge:clearCookingHeat(rt.body, workId) end)
end
local function finish(id, status, reason)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    local work = rec and rec.cookingWork
    if not work then runtime[id] = nil return status end
    -- Exact SourceUse reconciliation must survive every exit, including reload.
    if work.transferId and rec.worldSourceReservation == work.transferId then
        work.terminalStatus, work.terminalReason = status, reason
        local body = rt and rt.body or SAO.Body.get(id)
        if not body or SAO.SourceUse.closeForOwnershipTransfer(id, body, reason) ~= true then
            return "reconciling"
        end
    end
    releaseRuntime(id, rt, work.id)
    local receipt = { id = work.id, sequence = work.sequence, actorId = id, itemId = work.itemId, itemType = work.itemType,
        sourceId = work.sourceId, startedAt = work.startedAt, atHours = hours(),
        status = status, detail = reason, beforeCookingTime = work.beforeCookingTime,
        afterCookingTime = work.afterCookingTime, heatObserved = work.heatObserved == true,
        nativeCredit = work.nativeCredit, retrieved = work.retrieved == true,
        shutdown = work.shutdown, detached = work.detached == true, detachedAt = work.detachedAt }
    rec.cookingOutcomes = rec.cookingOutcomes or {}
    rec.cookingOutcomes[#rec.cookingOutcomes + 1] = receipt
    if #rec.cookingOutcomes > 32 then table.remove(rec.cookingOutcomes, 1) end
    rec.cookingWork, runtime[id] = nil, nil
    record(id, status, reasonText[reason] or outcomeText[status] or "Food preparation ended")
    if C.onOutcome then pcall(C.onOutcome, id, receipt) end
    return status
end
function C.interrupt(id, body, reason)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    if not rec or not rec.cookingWork or rt and body and rt.body ~= body then return false end
    return finish(id, "interrupted", reason or "interrupted") ~= "reconciling"
end
-- Irreversible death/identity retirement, after native actions were stopped
-- and their SourceUse owner was given its own close/detach opportunity.
-- This boundary retires only exact transient authority. Unresolved physical
-- evidence remains a scalar durable marker with the existing source owner.
function C.detach(id, body, reason)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    if rt and rt.body ~= body then return false, "body-mismatch" end
    if not rt and body and SAO.Body.get(id) and SAO.Body.get(id) ~= body then
        return false, "body-mismatch"
    end
    releaseRuntime(id, rt, rt and rt.workId)
    runtime[id] = nil
    local work = rec and rec.cookingWork
    if not work or rt and work.id ~= rt.workId then return true, "runtime-retired" end
    work.detached = true
    local clockOk, at = pcall(hours)
    work.detachedAt = work.detachedAt or (clockOk and type(at) == "number" and at or nil)
    work.terminalStatus, work.terminalReason = "interrupted", reason or "body-retired"
    if work.transferId and rec.worldSourceReservation == work.transferId then
        return true, "source-pending"
    end
    local finished, result = pcall(finish, id, "interrupted", work.terminalReason)
    return true, finished and result or "receipt-pending"
end
local function otherMeal(id, rt)
    for otherId, other in pairs(runtime) do
        if otherId ~= id and other.appliance.object == rt.appliance.object then return true end
    end
    local items = rt.appliance.container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= rt.food.item and item:isCookable() and not item:isBurnt() then return true end
    end
    return false
end
local function queued(body, action)
    local row = ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[body]
    for _, member in ipairs(row and row.queue or {}) do if member == action then return true end end
    return false
end
local Toggle = ISToggleStoveAction:derive("SAOCookingToggle")
function Toggle:isValid()
    local rt = runtime[self.saoCookId]
    local rec = rt and owner(self.saoCookId, self.character)
    return not self.saoCancelled and rt and rt.body == self.character and rt.toggle == self
        and rec and rec.cookingWork and rec.cookingWork.id == self.saoWorkId
        and allowed(self.saoCookId, rt.appliance)
        and (self.saoDesiredActive or not otherMeal(self.saoCookId, rt))
        and SAOJavaBridge:inspectCookingAppliance(self.character, self.object, rt.appliance.container) ~= nil
        and ISToggleStoveAction.isValid(self)
end
function Toggle:complete()
    if not self:isValid() then self.saoFailed = true return false end
    local rt = runtime[self.saoCookId]
    if self.object:Activated() == self.saoDesiredActive then self.saoDone = true return true end
    local result = ISToggleStoveAction.complete(self)
    self.saoDone = result == true and self.object:Activated() == self.saoDesiredActive
    if self.saoDone and self.saoDesiredActive then rt.turnedOn = true end
    self.saoFailed = not self.saoDone
    return self.saoDone
end
function Toggle:stop()
    self.saoFailed = true
    ISToggleStoveAction.stop(self)
end
local function toggle(id, body, rt, work, desired)
    if rt.toggle then
        if rt.toggle.saoDone then rt.toggle = nil return "done" end
        if not rt.toggle.saoFailed and queued(body, rt.toggle) and SAO.Needs.busy(body) then return "switching-appliance" end
        rt.toggle.saoCancelled = true rt.toggle = nil
        return "failed"
    end
    if SAO.Needs.busy(body) then return "busy" end
    local action = Toggle:new(body, rt.appliance.object)
    action.saoCookId, action.saoWorkId, action.saoDesiredActive = id, work.id, desired
    rt.toggle = action
    if not SAO.Needs.queueVerified(action) then action.saoCancelled = true rt.toggle = nil return "failed" end
    return "switching-appliance"
end
local function route(id, body, rt, target)
    if not SAO.Standing.mayEnterBelieved(id, target.approachX, target.approachY) then
        return false, "route-permission-refused"
    end
    local job = SAO.Locomotion.jobs[id]
    if rt.route then
        if job ~= rt.route then return false, "route-owner-changed" end
        SAO.Locomotion.tick(id)
        if not rt.route.done then return true, "travelling" end
        local result = rt.route.result
        SAO.Locomotion.cancel(id) rt.route = nil
        return false, result == "arrived" and "arrived" or "route-" .. tostring(result)
    end
    if job and not job.done then return false, "different-route-owner" end
    if not SAO.Locomotion.order(id, body, target.approachX, target.approachY, target.approachZ) then
        return false, "route-refused"
    end
    rt.route = SAO.Locomotion.jobs[id]
    if not rt.route or rt.route.body ~= body then return false, "route-owner-unavailable" end
    return true, "travelling"
end
local function releaseRoute(id, rt)
    if not rt.route then return true end
    if SAO.Locomotion.jobs[id] ~= rt.route then return false end
    SAO.Locomotion.cancel(id) rt.route = nil
    return true
end
local function transfer(id, body, rt, work, container, operation, stage, sourceId)
    local accepted, reservation = SAO.SourceUse.beginTransfer(id, body, "food", "standing",
        rt.food.item, container, operation, { purpose = "cooking" })
    if not accepted or not reservation or type(reservation.id) ~= "string" then return false end
    work.stage, work.transferId, work.transferOperation, work.transferSource = stage,
        reservation.id, operation, sourceId
    return true
end
function C.begin(id, body)
    local rec = owner(id, body)
    if not rec or rec.cookingWork or rec.worldSourceReservation or SAO.Needs.busy(body)
        or body:isAsleep() or body:isDead() then return false end
    local job = SAO.Locomotion.jobs[id]
    if job and not job.done then return false end
    local offers = SAOJavaBridge:cookingOffers(body, 12)
    if type(offers) ~= "table" then return false end
    local appliance, food
    for _, row in ipairs(offers.appliances or {}) do if allowed(id, row) then appliance = row break end end
    if not appliance then return false end
    for _, row in ipairs(offers.foods or {}) do if row.carried or allowed(id, row) then food = row break end end
    if not food then return false end
    rec.cookingSequence = (rec.cookingSequence or 0) + 1
    rec.cookingWork = { id = "cooking/" .. tostring(id) .. "/" .. tostring(rec.cookingSequence), sequence = rec.cookingSequence,
        itemId = food.itemId, itemType = food.itemType, sourceId = appliance.sourceId,
        stage = food.carried and "approach-appliance" or "acquire", startedAt = hours(),
        ownerToken = rec.bodyOwnerToken, ownerName = rec.bodyOwner, heatObserved = false }
    runtime[id] = { body = body, food = food, appliance = appliance, workId = rec.cookingWork.id }
    record(id, "started", "Preparing food")
    return true
end
local function tick(id, body)
    local rec, rt = SAO.Identity.get(id), runtime[id]
    if not rec or not rec.cookingWork then return false end
    local work = rec.cookingWork
    if work.terminalStatus then return finish(id, work.terminalStatus, work.terminalReason) end
    if not rt or rt.body ~= body then return finish(id, "interrupted", "native-binding-unavailable") end
    if not owner(id, body) or rec.bodyOwnerToken ~= work.ownerToken or rec.bodyOwner ~= work.ownerName
        or body:isAsleep() or body:isDead() then return finish(id, "interrupted", "body-owner-unavailable") end
    if not allowed(id, rt.appliance) then return finish(id, "interrupted", "current-appliance-permission-refused") end
    if hours() - work.startedAt > 6 or hours() < work.startedAt then return finish(id, "unavailable", "preparation-expired") end
    local job = SAO.Locomotion.jobs[id]
    if job and not job.done and job ~= rt.route then return finish(id, "interrupted", "different-route-owner") end
    local food, appliance, item = rt.food, rt.appliance, rt.food.item
    if item:getID() ~= work.itemId or item:getFullType() ~= work.itemType then return finish(id, "unavailable", "item-identity-changed") end
    if work.transferId then
        if rec.worldSourceReservation == work.transferId then
            SAO.SourceUse.tick(id, body)
            if rec.worldSourceReservation == work.transferId then return "transfer" end
        end
        if rec.worldSourceReservation then return finish(id, "interrupted", "different-source-owner") end
        local receipt = SAO.WorldSources.actionOutcome(work.transferId, id)
        if not receipt or receipt.status ~= "completed" or receipt.measurement ~= "native-item-transfer"
            or receipt.reservationId ~= work.transferId or receipt.actorId ~= id
            or receipt.itemId ~= work.itemId or receipt.itemType ~= work.itemType
            or receipt.operation ~= work.transferOperation or receipt.sourceId ~= work.transferSource
            or not tonumber(receipt.observedQuantity) or receipt.observedQuantity <= 0 then
            return finish(id, "unavailable", "transfer-result-unavailable")
        end
        local expected = (work.stage == "acquire" or work.stage == "retrieve") and body:getInventory() or appliance.container
        if item:getContainer() ~= expected then return finish(id, "unavailable", "transfer-not-observed") end
        work.transferId = nil
        if work.stage == "retrieve" then
            work.stage, work.retrieved, rt.toggle = "shutdown", true, nil
        elseif work.stage == "store" then
            if not SAOJavaBridge:beginCookingHeat(body, work.id, item, appliance.object, appliance.container) then
                return finish(id, "unavailable", "thermal-binding-refused")
            end
            work.stage = "heat"
        else work.stage = "approach-appliance" end
    elseif rec.worldSourceReservation then return finish(id, "interrupted", "different-source-owner") end
    if SAO.Needs.busy(body) and not (rt.toggle and queued(body, rt.toggle)) then return finish(id, "interrupted", "different-native-action") end
    if work.stage == "acquire" then
        if not allowed(id, food) then return finish(id, "interrupted", "current-food-permission-refused") end
        local position = SAOJavaBridge:worldTransferPosition(body, food.worldContainer)
        if not position or position == "" then
            local moving, reason = route(id, body, rt, food)
            if moving then return reason end
            if reason ~= "arrived" then return finish(id, "unavailable", reason) end
        elseif not releaseRoute(id, rt) then return finish(id, "interrupted", "route-owner-changed") end
        if not transfer(id, body, rt, work, food.worldContainer, "acquire", "acquire", food.sourceId) then return finish(id, "unavailable", "food-acquisition-refused") end
        return "transfer"
    end
    local state = SAOJavaBridge:inspectCookingAppliance(body, appliance.object, appliance.container)
    if not state then
        -- Native separation may move a stationary cook just out of reach.
        -- Preserve the exact work and heat binding while physically returning;
        -- no thermal read, transfer or completion is admitted from this distance.
        local approach = SAOJavaBridge:cookingApproach(body, appliance.object, appliance.container)
        if not approach then return finish(id, "interrupted", "appliance-unavailable") end
        if approach.sourceId ~= work.sourceId or approach.sourceX ~= appliance.sourceX
            or approach.sourceY ~= appliance.sourceY or approach.sourceZ ~= appliance.sourceZ then
            return finish(id, "unavailable", "appliance-identity-changed")
        end
        local moving, reason = route(id, body, rt, approach)
        if moving then return reason end
        if reason ~= "arrived" then return finish(id, "unavailable", reason) end
        state = SAOJavaBridge:inspectCookingAppliance(body, appliance.object, appliance.container)
        if not state then return finish(id, "unavailable", "appliance-no-longer-reachable") end
    elseif not releaseRoute(id, rt) then return finish(id, "interrupted", "route-owner-changed") end
    if state.sourceId ~= work.sourceId then return finish(id, "unavailable", "appliance-identity-changed") end
    if work.stage == "shutdown" then
        if not item:isCooked() or item:isBurnt() or item:getContainer() ~= body:getInventory() or not work.nativeCredit then return finish(id, "unavailable", "retrieved-result-changed") end
        if rt.turnedOn and state.active then
            if otherMeal(id, rt) then work.shutdown = "shared-use" return finish(id, "completed", "native-food-cooked-and-retrieved") end
            local switched = toggle(id, body, rt, work, false)
            if switched == "switching-appliance" then return switched end
            if switched ~= "done" then return finish(id, "interrupted", "appliance-shutdown-refused") end
            if appliance.object:Activated() then return finish(id, "interrupted", "appliance-still-active") end
        end
        work.shutdown = rt.turnedOn and "off" or "prior-state-preserved"
        return finish(id, "completed", "native-food-cooked-and-retrieved")
    end
    if work.stage == "approach-appliance" then
        local context, why = SAO.WorldSources.inspectionCandidate(id, body, "standing", 12, work.sourceId)
        if not context then return finish(id, "unavailable", tostring(why)) end
        local inspected, reason = SAO.WorldSources.inspectContainer(id, body, context)
        if not inspected then return finish(id, "unavailable", tostring(reason)) end
        if not transfer(id, body, rt, work, appliance.container, "store", "store", work.sourceId) then return finish(id, "unavailable", "food-deposit-refused") end
        return "transfer"
    end
    local thermal = SAOJavaBridge:cookingHeatState(body, work.id)
    if not thermal then return finish(id, "unavailable", "native-food-result-unbound") end
    if thermal.burnt then return finish(id, "no-effect", "food-burnt") end
    work.beforeCookingTime, work.afterCookingTime = thermal.beforeCookingTime, thermal.cookingTime
    work.heatObserved = thermal.progressed == true
    if thermal.cooked then
        local result = SAOJavaBridge:completeCookingHeat(body, work.id)
        if not result or result.credited ~= true or result.actorId ~= id or result.workId ~= work.id
            or result.itemId ~= work.itemId or result.progressed ~= true then
            return finish(id, "unavailable", "thermal-progression-not-observed")
        end
        work.nativeCredit = work.id
        if not transfer(id, body, rt, work, appliance.container, "acquire", "retrieve", work.sourceId) then return finish(id, "unavailable", "cooked-food-retrieval-refused") end
        return "transfer"
    end
    if state.kind == "stove" and not state.active then
        if state.powered ~= true then return finish(id, "no-effect", "appliance-unpowered") end
        local switched = toggle(id, body, rt, work, true)
        if switched == "switching-appliance" then return switched end
        if switched ~= "done" then return finish(id, "no-effect", "appliance-did-not-activate") end
    elseif not state.active then return finish(id, "no-effect", "appliance-unlit") end
    if rt.toggle and rt.toggle.saoDone then rt.toggle = nil end
    return "heating"
end
function C.tick(id, body)
    local ok, result = pcall(tick, id, body)
    if ok then return result end
    return finish(id, "unavailable", "native-cooking-unavailable")
end
function C.snapshot(id)
    local rec = SAO.Identity.get(id)
    local work = rec and rec.cookingWork
    if not work then return nil end
    return { stage = work.stage, itemType = work.itemType, sourceId = work.sourceId,
        startedAt = work.startedAt, cookingTime = work.afterCookingTime, heatObserved = work.heatObserved }
end
function C.reset()
    for id, rt in pairs(runtime) do
        releaseRuntime(id, rt, rt.workId)
    end
    runtime = {}
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(C.reset) end
return C
