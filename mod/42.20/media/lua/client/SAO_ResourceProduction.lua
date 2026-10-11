-- Native resource transformations over this person's remembered world and held tools.
require "TimedActions/ISTakeWaterAction"
SAO = SAO or {}
SAO.ResourceProduction = SAO.ResourceProduction or {}
local R = SAO.ResourceProduction
local craftBegin, craftInterrupt, craftTick, craftOutcome, craftRecover
local plumbBegin, plumbInterrupt, plumbTick, plumbOutcome, plumbRecover, plumbOptions
local collector
local bed,shelter
local function nativeEntityKind(kind) return kind=="build-rain-collector" or kind=="build-wood-bed" or kind=="build-shelter-edge" or kind=="use-shelter" end
local fixing
local function nativeCraftKind(kind) return kind=="saw-logs" or kind=="repair-held-item" or kind=="fix-held-item" end
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
    if type(option) ~= "table" or (option.kind ~= "refill-water" and option.kind ~= "plumb-fixture" and option.kind ~= "build-rain-collector") or option.category ~= "water"
        or type(option.sourceId) ~= "string" or string.sub(option.sourceId, 1, 2) ~= "F:"
        or type(option.place) ~= "table" then return false end
    local known = SAO.Perception.knownPlaces(id, true) or {}
    local belief = known[option.place.id] or known[tostring(option.place.id)]
    local fact = belief and belief.sourceFacts and belief.sourceFacts[option.sourceId]
    if option.kind=="build-rain-collector" and (not collector or not SAO.Body.get(id)
        or not collector.site(id,SAO.Body.get(id),option.site,option.sourceX,option.sourceY,option.sourceZ)) then return false end
    return fact ~= nil and fact.kind == "fluid"
        and ((option.kind == "plumb-fixture" or option.kind == "build-rain-collector") and fact.plumbing == "unconnected"
            or option.kind == "refill-water" and fact.state == "available" and tonumber(fact.quantities and fact.quantities.water or 0) > 0)
        and same(fact.id, option.sourceId) and fact.fingerprint == option.fingerprint
        and fact.revision == option.sourceRevision and admitted(belief, option.sourceId, option.sourceRevision)
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
    if collector and #options<16 then collector.options(id, body, vessels, options) end
    if plumbOptions and #options<16 then plumbOptions(id, body, vessels, options) end
    return options
end
local function queued(action)
    return action and ISTimedActionQueue and ISTimedActionQueue.hasAction(action) == true
end
local function permission(id, work)
    return SAO.Standing.mayTakeCurrent(id, work.sourceX, work.sourceY, "standing") == true
end
local function physical(rt, work)
    if work.kind == "plumb-fixture" then
        return permission(work.actorId, work) and SAOJavaBridge:worldPlumbValid(rt.body, rt.fixture,
            work.sourceId, work.fingerprint, work.sourceX, work.sourceY, work.sourceZ, true) == true
    end
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
    local observationKind = receipt.kind == "plumb-fixture" and "observed-native-plumbing" or "observed-native-refill"
    local learned, result = pcall(learn, id, receipt.place, receipt.sourceId, tick, observationKind)
    if not learned or result ~= true then return stop("handled-source-private-refresh-refused") end
    local known = perception.knownPlaces(id, true) or {}
    local belief = known[receipt.place.id] or known[tostring(receipt.place.id)]
    local ownFact = belief and belief.sourceFacts and belief.sourceFacts[receipt.sourceId]
    if not ownFact or ownFact.fingerprint ~= fact.fingerprint or ownFact.revision ~= fact.revision
        or not admitted(belief, receipt.sourceId, fact.revision) then
        return stop("handled-source-private-refresh-unconfirmed")
    end
    observation.status, observation.detail, observation.revision, observation.atHours =
        "confirmed", observationKind, fact.revision, hours()
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
    if type(workId)=="string" and workId:sub(1,10)=="generator/" and SAO.Generator then return SAO.Generator.outcome(id,workId) end
    local rec = SAO.Identity.get(id)
    for _, receipt in ipairs(rec and rec.resourceProductionOutcomes or {}) do
        if receipt.id == workId then
            if nativeEntityKind(receipt.kind) then return collector.outcome(id, receipt) end
            if receipt.kind == "plumb-fixture" then return plumbOutcome(id, receipt) end
            if nativeCraftKind(receipt.kind) then return craftOutcome(id, receipt) end
            return receipt
        end
    end
end
local function reconcile(id)
    local rec, planning = SAO.Identity.get(id), SAO.ProceduralPlanning
    for _, receipt in ipairs(rec and rec.resourceProductionOutcomes or {}) do
        local consumer = planning and (receipt.kind=="use-shelter" and planning.consumeShelterUseResult
            or receipt.kind=="build-shelter-edge" and planning.consumeShelterConstructionResult
            or receipt.kind=="build-wood-bed" and planning.consumeBedConstructionResult
            or (receipt.kind == "repair-held-item" or receipt.kind == "fix-held-item") and planning.consumeRepairProductionResult
            or receipt.kind == "saw-logs" and planning.consumeCraftProductionResult
            or not nativeCraftKind(receipt.kind) and planning.consumeProductionResult)
        local result = receipt.kind == "plumb-fixture" and plumbOutcome(id, receipt)
            or nativeCraftKind(receipt.kind) and craftOutcome(id, receipt) or receipt
        if nativeEntityKind(receipt.kind) then result = collector.outcome(id,receipt) end
        if receipt.kind == "plumb-fixture" and not plumbOutcome(id, receipt) then result = nil end
        if result and receipt.purposeId and not receipt.purposeDelivered and consumer
            and consumer(id, result) then receipt.purposeDelivered = true end
        if not receipt.experienceDelivered and R.onOutcome then
            if nativeEntityKind(receipt.kind) then result = collector.outcome(id, receipt) end
            if receipt.kind == "plumb-fixture" then result = plumbOutcome(id, receipt)
            elseif nativeCraftKind(receipt.kind) then result = craftOutcome(id, receipt) end
            if result then
                local delivered, accepted = pcall(R.onOutcome, id, result)
                if delivered and accepted == true then receipt.experienceDelivered = true end
            end
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
-- SawLogs and portable tool maintenance are operations of this transformation owner. Native handles and
-- exact input lists live only in its capsule, never in the person's save.
local CRAFT_SEAL, CRAFT_RECIPE, CRAFT_LIMIT = {}, "Base.SawLogs", 32
local REPAIR_RECIPE = "Base.FixSaw"
local REPAIR_ORDER={REPAIR_RECIPE,"Base.SharpenBlade","Base.SharpenBladePoorlyWithFile"}
local REPAIR_POLICIES={
    [REPAIR_RECIPE]={category="saw",toolCategory="file",effectMetric="condition"},
    ["Base.SharpenBlade"]={category="blade",toolCategory="whetstone",effectMetric="sharpness"},
    ["Base.SharpenBladePoorlyWithFile"]={category="blade",toolCategory="file",effectMetric="sharpness"}}
function R.repairPolicy(recipeId)
    if fixing and fixing.policy then local p=fixing.policy(recipeId);if p then return p end end
    local p=REPAIR_POLICIES[recipeId]
    return p and {recipeId=recipeId,category=p.category,toolCategory=p.toolCategory,effectMetric=p.effectMetric} or nil
end
local craftInstalled = false
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function integer(v) return finite(v) and v>=0 and v<1000000000 and v%1==0 end
local function textId(v) return type(v)=="string" and #v>0 and #v<=256 end
local function now() local v=hours(); return finite(v) and v>=0 and v or nil end
local function craftLedger(rec)
    if not rec or not integer(rec.resourceProductionSequence or 0) then return false end
    local rows=rec.resourceProductionOutcomes
    if rows==nil then return true end
    if type(rows)~="table" or getmetatable(rows) or #rows>CRAFT_LIMIT then return false end
    local count, previous, seen=0,0,{}
    for k in pairs(rows) do if not integer(k) or k<1 or k>#rows then return false end; count=count+1 end
    if count~=#rows then return false end
    for _,row in ipairs(rows) do
        if type(row)~="table" or getmetatable(row) or not integer(row.sequence) or row.sequence<1
            or row.sequence<=previous or row.sequence>(rec.resourceProductionSequence or 0)
            or row.actorId~=rec.id or row.id~="resource-production/"..tostring(rec.id).."/"..row.sequence
            or seen[row.id] then return false end
        previous,seen[row.id]=row.sequence,true
    end
    return true
end
local CRAFT_FIELDS={id=true,workId=true,sequence=true,actorId=true,kind=true,category=true,recipeId=true,
    logItemId=true,logItemType=true,sawItemId=true,sawItemType=true,purposeId=true,purposeStepId=true,
    requestedPurposeId=true,requestedPurposeStepId=true,token=true,status=true,detail=true,
    startedAt=true,atHours=true,endedAt=true,world=true,bodyToken=true,x=true,y=true,z=true,entryKey=true,
    beforeLogUses=true,afterLogUses=true,sawConditionBefore=true,sawConditionAfter=true,
    logConsumed=true,sawRetained=true,held=true,nativeAttempted=true,nativeOwner=true,
    outputCount=true,outputs=true,nativeCredit=true,nativeObservability=true,
    targetItemId=true,targetItemType=true,toolItemId=true,toolItemType=true,
    beforeCondition=true,afterCondition=true,maxCondition=true,beforeRepairCount=true,afterRepairCount=true,
    beforeToolCondition=true,afterToolCondition=true,targetRetained=true,toolRetained=true,
    nativeCompleted=true,improved=true,fullRestoration=true,effectMetric=true,toolCategory=true,
    beforeSharpness=true,afterSharpness=true,maxSharpness=true,
    beforeHeadCondition=true,afterHeadCondition=true,maxHeadCondition=true,
    purposeDelivered=true,experienceDelivered=true}
local function craftIdentity(id, row)
    if row and row.kind=="fix-held-item" then return fixing and fixing.identity(id,row) or false end
    if not (type(row)=="table" and not getmetatable(row) and row.actorId==id
        and row.id=="resource-production/"..tostring(id).."/"..tostring(row.sequence)
        and integer(row.sequence) and row.sequence>0 and nativeCraftKind(row.kind)
        and textId(row.purposeId) and textId(row.purposeStepId)
        and textId(row.world) and (row.bodyToken==nil or textId(row.bodyToken))
        and textId(row.entryKey) and finite(row.x) and row.x%1==0 and finite(row.y) and row.y%1==0
        and finite(row.z) and row.z%1==0 and finite(row.startedAt) and row.startedAt>=0) then return false end
    if row.kind=="repair-held-item" then
        local policy=REPAIR_POLICIES[row.recipeId]
        local legacy=row.recipeId==REPAIR_RECIPE
        local metric=policy and policy.effectMetric
        return policy~=nil and row.category==policy.category and row.token=="resource:repaired"
            and (row.effectMetric==metric or legacy and row.effectMetric==nil)
            and (row.toolCategory==policy.toolCategory or legacy and row.toolCategory==nil)
            and textId(row.targetItemId) and textId(row.targetItemType) and textId(row.toolItemId) and textId(row.toolItemType)
            and row.targetItemId~=row.toolItemId and integer(row.beforeCondition) and row.beforeCondition>0
            and integer(row.maxCondition) and row.maxCondition>=row.beforeCondition
            and (metric~="condition" or row.maxCondition>row.beforeCondition)
            and (row.beforeSharpness==nil and row.maxSharpness==nil and metric~="sharpness"
                or finite(row.beforeSharpness) and row.beforeSharpness>=0 and finite(row.maxSharpness)
                    and row.maxSharpness>=row.beforeSharpness and (metric~="sharpness" or row.maxSharpness>row.beforeSharpness))
            and (row.beforeHeadCondition==nil and row.maxHeadCondition==nil
                or integer(row.beforeHeadCondition) and integer(row.maxHeadCondition) and row.maxHeadCondition>=row.beforeHeadCondition)
            and integer(row.beforeRepairCount) and integer(row.beforeToolCondition) and row.beforeToolCondition>0
            and row.logItemId==nil and row.logItemType==nil and row.sawItemId==nil and row.sawItemType==nil
            and row.beforeLogUses==nil and row.sawConditionBefore==nil
    end
    return row.recipeId==CRAFT_RECIPE and row.category=="plank" and row.token=="resource:crafted"
        and textId(row.logItemId) and row.logItemType=="Base.Log" and textId(row.sawItemId) and textId(row.sawItemType)
        and row.logItemId~=row.sawItemId and row.targetItemId==nil and row.toolItemId==nil
        and integer(row.beforeLogUses) and row.beforeLogUses==1
        and integer(row.sawConditionBefore) and row.sawConditionBefore>0
end
local function repairOutcome(id,row)
    local metric=REPAIR_POLICIES[row.recipeId].effectMetric
    if type(row.nativeAttempted)~="boolean" or type(row.nativeCompleted)~="boolean"
        or type(row.targetRetained)~="boolean" or type(row.toolRetained)~="boolean"
        or type(row.held)~="boolean" or type(row.improved)~="boolean" or type(row.fullRestoration)~="boolean"
        or row.logConsumed~=nil or row.sawRetained~=nil or row.afterLogUses~=nil or row.sawConditionAfter~=nil
        or row.outputs~=nil or row.outputCount~=nil then return nil end
    local out={}
    for k,v in pairs(row) do
        local kind=type(v)
        if not CRAFT_FIELDS[k] or kind~="string" and kind~="number" and kind~="boolean"
            or kind=="number" and not finite(v) or kind=="string" and #v>512 then return nil end
        out[k]=v
    end
    if row.purposeDelivered~=nil and type(row.purposeDelivered)~="boolean"
        or row.experienceDelivered~=nil and type(row.experienceDelivered)~="boolean" then return nil end
    if row.nativeObservability~=nil then
        if row.nativeObservability~="runtime-unavailable" or row.status~="interrupted" or row.nativeAttempted
            or row.nativeCompleted or row.targetRetained or row.toolRetained or row.held or row.improved or row.fullRestoration
            or row.afterCondition~=nil or row.afterRepairCount~=nil or row.afterToolCondition~=nil
            or row.afterSharpness~=nil or row.afterHeadCondition~=nil or row.nativeCredit~=nil then return nil end
    else
        local before=metric=="sharpness" and row.beforeSharpness or row.beforeCondition
        local after=metric=="sharpness" and row.afterSharpness or row.afterCondition
        local maximum=metric=="sharpness" and row.maxSharpness or row.maxCondition
        if not integer(row.afterCondition) or row.afterCondition>row.maxCondition or not integer(row.afterRepairCount)
            or (row.beforeSharpness==nil and row.afterSharpness~=nil or row.beforeSharpness~=nil
                and (not finite(row.afterSharpness) or row.afterSharpness<0 or row.afterSharpness>row.maxSharpness+0.000001))
            or (row.beforeHeadCondition==nil and row.afterHeadCondition~=nil or row.beforeHeadCondition~=nil
                and (not integer(row.afterHeadCondition) or row.afterHeadCondition>row.maxHeadCondition))
            or not finite(row.afterToolCondition) or row.afterToolCondition%1~=0
            or row.afterToolCondition < -1000000000 or row.afterToolCondition>row.beforeToolCondition
            or row.improved~=(row.nativeCompleted and row.targetRetained and row.held and after>before)
            or row.fullRestoration~=(row.improved and after>=maximum-0.000001)
            or row.nativeCompleted and (not row.nativeAttempted or not row.targetRetained or not row.toolRetained or not row.held)
            or row.held~=(row.targetRetained and row.toolRetained) then return nil end
    end
    if row.status=="completed" and (not row.nativeCompleted or not row.improved or row.nativeCredit~=row.id)
        or row.status~="completed" and row.nativeCredit~=nil then return nil end
    return out
end
craftOutcome=function(id,row)
    if row and row.kind=="fix-held-item" then return fixing and fixing.outcome(id,row) end
    local rec=SAO.Identity.get(id)
    if not craftLedger(rec) or not craftIdentity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISHandcraftAction" or not textId(row.detail)
        or not finite(row.atHours) or row.atHours<row.startedAt or row.endedAt~=row.atHours
        or (row.status~="completed" and row.status~="interrupted" and row.status~="failed") then return nil end
    if row.kind=="repair-held-item" then return repairOutcome(id,row) end
    if type(row.nativeAttempted)~="boolean" or type(row.logConsumed)~="boolean"
        or type(row.sawRetained)~="boolean" or type(row.held)~="boolean" or not integer(row.outputCount)
        or type(row.outputs)~="table" or getmetatable(row.outputs) or #row.outputs>3
        or row.outputCount~=#row.outputs then return nil end
    local out, seen, count={}, {}, 0
    for k,v in pairs(row) do
        if not CRAFT_FIELDS[k] then return nil end
        if k~="outputs" then
            local kind=type(v)
            if kind~="string" and kind~="number" and kind~="boolean" or kind=="number" and not finite(v)
                or kind=="string" and #v>512 then return nil end
            out[k]=v
        end
    end
    out.outputs={}
    for k,v in pairs(row.outputs) do
        if not integer(k) or k<1 or k>#row.outputs or type(v)~="table" or getmetatable(v)
            or not textId(v.itemId) or v.itemType~="Base.Plank" or seen[v.itemId]
            or v.itemId==row.logItemId or v.itemId==row.sawItemId then return nil end
        for field in pairs(v) do if field~="itemId" and field~="itemType" then return nil end end
        count=count+1; seen[v.itemId]=true; out.outputs[k]={itemId=v.itemId,itemType=v.itemType}
    end
    if count~=#row.outputs or row.purposeDelivered~=nil and type(row.purposeDelivered)~="boolean"
        or row.experienceDelivered~=nil and type(row.experienceDelivered)~="boolean" then return nil end
    if row.nativeObservability~=nil then
        if row.nativeObservability~="runtime-unavailable" or row.status~="interrupted"
            or row.nativeAttempted or row.logConsumed or row.sawRetained or row.held or row.outputCount~=0
            or row.afterLogUses~=nil or row.sawConditionAfter~=nil or row.nativeCredit~=nil then return nil end
    elseif not integer(row.afterLogUses) or not integer(row.sawConditionAfter)
        or row.sawConditionAfter>row.sawConditionBefore then return nil end
    if row.status=="completed" and (not row.nativeAttempted or not row.logConsumed or not row.sawRetained
        or not row.held or row.outputCount~=3 or row.afterLogUses~=0 or row.nativeCredit~=row.id) then return nil end
    if row.status~="completed" and row.nativeCredit~=nil or row.logConsumed and not row.nativeAttempted
        or row.outputCount>0 and not row.nativeAttempted then return nil end
    return out
end
local function installCraft()
    if craftInstalled then return true end
    local action=pcall(require,"Entity/TimedActions/ISHandcraftAction")
    local transfer=pcall(require,"TimedActions/ISInventoryTransferAction")
    craftInstalled=action and transfer and type(ISHandcraftAction)=="table"
        and type(ISHandcraftAction.new)=="function" and type(ISHandcraftAction.performRecipe)=="function"
        and type(ISInventoryTransferAction)=="table" and type(ISInventoryTransferAction.perform)=="function"
        and ScriptManager and ScriptManager.instance and HandcraftLogic and ArrayList and CraftRecipeManager
    return craftInstalled and true or false
end
local function registeredRecipe(recipeId)
    return installCraft() and ScriptManager.instance:getCraftRecipe(recipeId or CRAFT_RECIPE) or nil
end
local function craftPosition(id,body)
    local world,sq=getWorld(),body:getCurrentSquare()
    return world and sq and body:getCell()==world:getCell() and sq:canStand()
        and body:getCell():getGridSquare(sq:getX(),sq:getY(),sq:getZ())==sq
        and (body:getCell():getObjectList():contains(body) or body:getCell():getAddList():contains(body))
        and SAO.Standing.mayTakeCurrent(id,sq:getX(),sq:getY(),"standing")==true
end
function R.craftingAvailable(id,body)
    local ok,available=pcall(function()
        local recipe=registeredRecipe()
        if not owner(id,body) or not now() or not recipe or not craftPosition(id,body)
            or not CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body) then return false end
        for i=0,recipe:getRequiredSkillCount()-1 do
            if not CraftRecipeManager.hasPlayerRequiredSkill(recipe:getRequiredSkill(i),body) then return false end
        end
        return true
    end)
    return ok and available==true
end
local function craftCarried(body,itemId,itemType,maxItems)
    local items=SAOJavaBridge:privateCarriedItems(body)
    if items:size()>(maxItems or 512) then return nil end
    local found
    for i=0,items:size()-1 do
        local item=items:get(i)
        if same(item:getID(),itemId) then
            if found or item:getFullType()~=itemType then return nil end
            found=item
        end
    end
    return found
end
local function ownItem(rt,item)
    local container=item and item:getContainer()
    return container and rt.inventory:containsRecursive(item)
        and (container==rt.inventory or container:getOutermostContainer()==rt.inventory)
end
local function repairTargetEligible(target,input,policy)
    if not input or input:getResourceType()~=ResourceType.Item or input:getIntAmount()~=1 or not input:isKeep() then return false end
    if policy.effectMetric=="sharpness" then return input:isSharpenable() and target:isSharpenable() end
    return input:isDamaged() and target:isDamaged() and target:getCondition()<target:getConditionMax()
end
local function repairToolEligible(tool,policy)
    return tool:hasTag(policy.toolCategory=="whetstone" and ItemTag.WHETSTONE or ItemTag.FILE)
end
function R.repairAvailable(id,body,target,recipeId)
    local ok,available=pcall(function()
        local policy=REPAIR_POLICIES[recipeId]
        local recipe=policy and registeredRecipe(recipeId)
        if not recipe or not owner(id,body) or not now() or not craftPosition(id,body) or not target
            or craftCarried(body,tostring(target:getID()),target:getFullType())~=target
            or not ownItem({inventory=body:getInventory()},target) or target:getIsCraftingConsumed()
            or target:isBroken() or target:getCondition()<=0
            or not CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body) then return false end
        for i=0,recipe:getRequiredSkillCount()-1 do
            if not CraftRecipeManager.hasPlayerRequiredSkill(recipe:getRequiredSkill(i),body) then return false end
        end
        local input=CraftRecipeManager.getValidInputScriptForItem(recipe,target,body)
        return recipe:getInputs():size()==2 and recipe:getOutputs():size()==0
            and repairTargetEligible(target,input,policy) and not target:hasTag(ItemTag.FILE)
            and not target:hasTag(ItemTag.WHETSTONE)
    end)
    return ok and available==true
end
function R.maintenanceOptions(id,body)
    local ok,options=pcall(function()
        local out={}
        if not owner(id,body) or not now() or not craftPosition(id,body) then return out end
        local items=SAOJavaBridge:privateCarriedItems(body)
        if items:size()>512 then return out end
        local candidates={}
        for _,recipeId in ipairs(REPAIR_ORDER) do
            local recipe=registeredRecipe(recipeId)
            if recipe then candidates[#candidates+1]={id=recipeId,recipe=recipe,policy=REPAIR_POLICIES[recipeId]} end
        end
        for i=0,items:size()-1 do
            local item=items:get(i)
            if item:getCondition()>0 and not item:isBroken() and not item:getIsCraftingConsumed() then
            for _,candidate in ipairs(candidates) do
                local recipeId=candidate.id
                local input=CraftRecipeManager.getValidInputScriptForItem(candidate.recipe,item,body)
                if repairTargetEligible(item,input,candidate.policy) and R.repairAvailable(id,body,item,recipeId) then
                    local option=R.repairPolicy(recipeId)
                    option.targetItemId,option.targetItemType=tostring(item:getID()),item:getFullType()
                    option.condition,option.maxCondition=item:getCondition(),item:getConditionMax()
                    option.sharpness,option.maxSharpness=item:getSharpness(),item:getMaxSharpness()
                    out[#out+1]=option
                    if #out==32 then return out end
                end
            end
            end
        end
        for _,option in ipairs(fixing.options(id,body)) do if #out>=32 then break end;out[#out+1]=option end
        return out
    end)
    return ok and options or {}
end
local function craftPurposeTarget(p,work)
    local material=p and p.materialWork
    if not material or material.entryKey~=work.entryKey then return false end
    if material.operation=="board" then return true end
    return (work.kind=="repair-held-item" or work.kind=="fix-held-item") and material.operation=="maintain-tool"
        and material.entryKey=="held-item:"..work.targetItemId
        and material.targetItemId==work.targetItemId and material.targetItemType==work.targetItemType
end
local function craftPurpose(rec,work)
    local state=rec.proceduralPlanning
    local p=state and state.purposes and state.purposes[work.purposeId]
    local step=p and p.steps and p.steps[p.cursor]
    local a=p and p.admission
    if not p or p.status=="completed" or p.status=="abandoned" or not craftPurposeTarget(p,work)
        or not step or step.id~=work.purposeStepId or step.owner~="SAO.ResourceProduction"
        or step.token~=work.token or step.productionKind~=work.kind or step.recipeId~=work.recipeId
        or step.target~=work.recipeId or step.category~=work.category
        or not a or a.owner~=step.owner or a.correlationId~=work.id or a.stepId~=step.id
        or a.target~=step.target or not finite(a.at) or a.at<work.startedAt then return nil end
    if work.kind=="fix-held-item" then
        if not fixing.sameStep(step,work) then return nil end
    elseif work.kind=="repair-held-item" then
        if step.targetItemId~=work.targetItemId or step.targetItemType~=work.targetItemType
            or step.toolItemId~=work.toolItemId or step.toolItemType~=work.toolItemType
            or step.toolCategory~=nil and step.toolCategory~=REPAIR_POLICIES[work.recipeId].toolCategory
            or step.effectMetric~=nil and step.effectMetric~=REPAIR_POLICIES[work.recipeId].effectMetric then return nil end
    elseif step.logItemId~=work.logItemId or step.logItemType~=work.logItemType
        or step.sawItemId~=work.sawItemId or step.sawItemType~=work.sawItemType then return nil end
    return p,step,a
end
local function craftAnchors(rt,work)
    if work.kind~=rt.kind or work.recipeId~=rt.recipeId then return false end
    if rt.kind=="fix-held-item" then return fixing.anchors(rt,work) end
    if rt.kind=="repair-held-item" then
        return work.targetItemId==rt.targetItemId and work.targetItemType==rt.targetItemType
            and work.toolItemId==rt.toolItemId and work.toolItemType==rt.toolItemType
            and work.beforeCondition==rt.beforeCondition and work.maxCondition==rt.maxCondition
            and work.beforeRepairCount==rt.beforeRepairCount and work.beforeToolCondition==rt.beforeToolCondition
            and work.effectMetric==rt.effectMetric and work.toolCategory==rt.toolCategory
            and work.beforeSharpness==rt.beforeSharpness and work.maxSharpness==rt.maxSharpness
            and work.beforeHeadCondition==rt.beforeHeadCondition and work.maxHeadCondition==rt.maxHeadCondition
    end
    return work.logItemId==rt.work.logItemId and work.sawItemId==rt.work.sawItemId
        and work.beforeLogUses==rt.beforeLogUses and work.sawConditionBefore==rt.sawConditionBefore
end
local function craftBound(rt,materials)
    local rec,body,work=owner(rt.id,rt.body),rt.body,rt.work
    local p,step
    if rec then p,step=craftPurpose(rec,work) end
    local world=getWorld()
    if rec~=rt.record or runtime[rt.id]~=rt or rt.cancelling or rec.resourceProductionWork~=work
        or not craftIdentity(rt.id,work) or work.id~=rt.workId or work.startedAt~=rt.startedAt
        or work.bodyToken~=rt.token or work.world~=rt.world or not craftLedger(rec)
        or work.entryKey~=rt.entryKey or work.x~=rt.square:getX() or work.y~=rt.square:getY() or work.z~=rt.square:getZ()
        or not craftAnchors(rt,work)
        or not now() or now()<rt.startedAt or not world or world:getWorld()~=rt.world
        or world:getCell()~=rt.cell or body:getCell()~=rt.cell or body:getCurrentSquare()~=rt.square
        or body:getInventory()~=rt.inventory or body:getModData().SAOExternalToken~=rt.token
        or not craftPosition(rt.id,body) or math.abs(body:getX()-rt.x)>.01 or math.abs(body:getY()-rt.y)>.01
        or math.floor(body:getZ())~=work.z or p~=rt.purpose or step~=rt.step
        or ISTimedActionQueue.getTimedActionQueue(body)~=rt.queue
        or (rt.kind~="fix-held-item" and registeredRecipe(work.recipeId)~=rt.recipe) then return false end
    if rt.kind=="fix-held-item" then return fixing.bound(rt,materials) end
    if materials then
        if rt.kind=="repair-held-item" then
            if not ownItem(rt,rt.target) or not ownItem(rt,rt.tool)
                or craftCarried(body,work.targetItemId,work.targetItemType)~=rt.target
                or craftCarried(body,work.toolItemId,work.toolItemType)~=rt.tool
                or rt.target:getCondition()~=rt.beforeCondition or rt.target:getConditionMax()~=rt.maxCondition
                or rt.target:getHaveBeenRepaired()~=rt.beforeRepairCount or rt.tool:getCondition()~=rt.beforeToolCondition
                or rt.beforeSharpness~=nil and (rt.target:getSharpness()~=rt.beforeSharpness or rt.target:getMaxSharpness()~=rt.maxSharpness)
                or rt.beforeHeadCondition~=nil and (rt.target:getHeadCondition()~=rt.beforeHeadCondition or rt.target:getHeadConditionMax()~=rt.maxHeadCondition)
                or rt.target:isBroken() or rt.tool:isBroken()
                or not R.repairAvailable(rt.id,body,rt.target,rt.recipeId)
                or rt.target:getIsCraftingConsumed() or rt.tool:getIsCraftingConsumed()
                or not repairToolEligible(rt.tool,REPAIR_POLICIES[rt.recipeId])
                or rt.prepared and (rt.target:getContainer()~=rt.inventory or rt.tool:getContainer()~=rt.inventory) then return false end
        elseif not ownItem(rt,rt.log) or not ownItem(rt,rt.saw)
            or craftCarried(body,work.logItemId,work.logItemType)~=rt.log
            or craftCarried(body,work.sawItemId,work.sawItemType)~=rt.saw
            or rt.log:getCurrentUses()~=work.beforeLogUses or rt.log:getIsCraftingConsumed()
            or rt.saw:getCondition()~=work.sawConditionBefore or rt.saw:isBroken()
            or rt.saw:getIsCraftingConsumed() or not rt.saw:hasTag(ItemTag.SAW)
            or rt.prepared and (rt.log:getContainer()~=rt.inventory or rt.saw:getContainer()~=rt.inventory) then return false end
    end
    return true
end
local function craftSelection(rt)
    local logic=HandcraftLogic.new(rt.body,nil,nil)
    local containers=ArrayList.new(); containers:add(rt.inventory)
    for _,item in ipairs(rt.inputs) do
        if item:getContainer()~=rt.inventory and not containers:contains(item:getContainer()) then containers:add(item:getContainer()) end
    end
    logic:setContainers(containers); logic:setRecipe(rt.recipe); logic:setTargetVariableInputRatio(1)
    logic:setManualSelectInputs(true); logic:clearManualInputs()
    local manual,inputs={},rt.recipe:getInputs()
    if inputs:size()~=2 then return nil end
    local seen={}
    for _,item in ipairs(rt.inputs) do
        local input=CraftRecipeManager.getValidInputScriptForItem(rt.recipe,item,rt.body)
        if not input or input:getResourceType()~=ResourceType.Item or input:getIntAmount()~=1
            or input:isKeep()~=(rt.kind=="repair-held-item" or item==rt.saw) or seen[input] then return nil end
        seen[input]=true
        local items=ArrayList.new(); items:add(item)
        if logic:setManualInputsFor(input,items)~=true then return nil end
        manual[rt.recipe:getIndexForIO(input)]=items
    end
    for i=0,inputs:size()-1 do if not seen[inputs:get(i)] then return nil end end
    if logic:canPerformCurrentRecipe()~=true then return nil end
    return logic,containers,manual,logic:getRecipeData():getAllInputItems()
end
local function craftExactInputs(c)
    local a,rt=c.action,c.rt
    if a.craftRecipe~=rt.recipe or a.character~=rt.body or a.isoObject~=nil or a.craftBench~=nil
        or a.recipeItem~=nil or a.force or a.variableInputRatio~=1 or a.eatPercentage~=0
        or a.manualInputs~=c.manual or a.containers~=c.containers or a.items~=c.items then return false end
    local count,seen=0,{}
    for index,items in pairs(a.manualInputs) do
        local input=rt.recipe:getIOForIndex(index)
        if not input or items:size()~=1 then return false end
        local item=items:get(0)
        if item~=rt.inputs[1] and item~=rt.inputs[2] or seen[item]
            or CraftRecipeManager.getValidInputScriptForItem(rt.recipe,item,rt.body)~=input then return false end
        count=count+1;seen[item]=true
    end
    return count==2 and c.items:size()==2 and c.items:contains(rt.inputs[1]) and c.items:contains(rt.inputs[2])
end
local function craftCapsule(action)
    local f=action and action._SAOCraftBinding
    return type(f)=="function" and f(CRAFT_SEAL) or nil
end
local function craftCurrent(c)
    return craftCapsule(c.action)==c and runtime[c.rt.id]==c.rt and c.rt.current==c
        and ISTimedActionQueue.getTimedActionQueue(c.rt.body)==c.rt.queue
        and c.rt.queue.current==c.action and c.rt.queue.queue[1]==c.action and c.rt.queue:indexOf(c.action)==1
end
local function craftNativeEnded(action)
    local ok,ended=pcall(function() return action.action and action.action:isStarted()
        and (action.action:finished() or action.action:isForceComplete()) end)
    return ok and ended==true
end
local function craftRetired(rt)
    for _,c in ipairs(rt.actions) do
        if rt.queue:indexOf(c.action)~=-1 or rt.queue.current==c.action or c.action.action and not c.ack then return false end
    end
    return true
end
local function craftMeasurement(rt)
    if rt.kind=="fix-held-item" then return fixing.measure(rt) end
    local work=rt.work
    if rt.kind=="repair-held-item" then
        local targetRetained=ownItem(rt,rt.target) and craftCarried(rt.body,work.targetItemId,work.targetItemType)==rt.target or false
        local toolRetained=ownItem(rt,rt.tool) and craftCarried(rt.body,work.toolItemId,work.toolItemType)==rt.tool or false
        local held=targetRetained and toolRetained
        local completed=rt.nativeCompleted==true
        local after=rt.effectMetric=="sharpness" and rt.target:getSharpness() or rt.target:getCondition()
        local before=rt.effectMetric=="sharpness" and rt.beforeSharpness or rt.beforeCondition
        local maximum=rt.effectMetric=="sharpness" and rt.maxSharpness or rt.maxCondition
        local improved=completed and held and after>before
        local measured={afterCondition=rt.target:getCondition(),afterRepairCount=rt.target:getHaveBeenRepaired(),
            afterToolCondition=rt.tool:getCondition(),targetRetained=targetRetained,toolRetained=toolRetained,
            nativeAttempted=rt.nativeAttempted==true,nativeCompleted=completed,held=held,improved=improved,
            fullRestoration=improved and after>=maximum-0.000001}
        if rt.beforeSharpness~=nil then measured.afterSharpness=rt.target:getSharpness() end
        if rt.beforeHeadCondition~=nil then measured.afterHeadCondition=rt.target:getHeadCondition() end
        return measured
    end
    local measured={afterLogUses=math.max(0,rt.log:getCurrentUses()),sawConditionAfter=rt.saw:getCondition(),
        logConsumed=rt.nativeAttempted==true and not rt.inventory:containsRecursive(rt.log) and rt.log:getCurrentUses()==0,
        sawRetained=ownItem(rt,rt.saw) and same(rt.saw:getID(),work.sawItemId) and rt.saw:getFullType()==work.sawItemType,
        held=true,outputs={},outputCount=0,nativeAttempted=rt.nativeAttempted==true}
    local seen={}
    for _,item in ipairs(rt.outputItems or {}) do
        local id=tostring(item:getID())
        if #measured.outputs>=3 or seen[id] or rt.beforeIds[id] or item:getFullType()~="Base.Plank" then measured.held=false; break end
        seen[id]=true; measured.outputs[#measured.outputs+1]={itemId=id,itemType=item:getFullType()}
        -- SawLogs consumes one admitted item and creates three; only its exact outputs allow that net gain.
        if not ownItem(rt,item) or craftCarried(rt.body,id,"Base.Plank",514)~=item then measured.held=false end
    end
    measured.outputCount=#measured.outputs
    return measured
end
local function craftDispose(rt)
    runtime[rt.id]=nil
    for _,c in ipairs(rt.actions) do
        local a=c.action; a._SAOCraftBinding=false
        a._SAOCraftRetireSaved=false
        local function inert() return false end
        a.isValidStart,a.isValid,a.start,a.serverStart,a.perform,a.performRecipe,a.complete,a.stop,a.forceCancel=
            inert,inert,inert,inert,inert,inert,inert,inert,inert
    end
end
local function craftClose(rt,status,detail)
    local rec,work,t=rt.record,rt.work,now()
    if not craftRetired(rt) or SAO.Identity.get(rt.id)~=rec or rec.resourceProductionWork~=work
        or not craftIdentity(rt.id,work) or not craftLedger(rec) or not t or t<rt.startedAt then return false end
    local rows=rec.resourceProductionOutcomes or {}
    for _,row in ipairs(rows) do if row.id==work.id then return false end end
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local m=craftMeasurement(rt)
    if status=="completed" and rt.kind=="fix-held-item" and (not m.improved or not m.reequipped or not m.paymentConsumed or not m.returnsMeasured) then
        status,detail="failed","native-fixing-without-restored-equipment"
    elseif status=="completed" and rt.kind=="repair-held-item" and not m.improved then
        status,detail="failed","native-repair-without-held-improvement"
    elseif status=="completed" and rt.kind=="saw-logs" and (not rt.nativeCompleted or not rt.nativeAttempted or not rt.paymentMeasured
        or not m.logConsumed or not m.sawRetained or not m.held or m.outputCount~=3) then
        status,detail="failed","native-plank-output-not-proven"
    end
    local row={}
    for key in pairs(CRAFT_FIELDS) do if key~="outputs" then row[key]=work[key] end end
    if rt.kind=="fix-held-item" then row=fixing.copy(work) end
    row.workId,row.status,row.detail,row.nativeOwner=work.id,status,detail,rt.kind=="fix-held-item" and "ISFixAction" or "ISHandcraftAction"
    row.atHours,row.endedAt=t,t
    for k,v in pairs(m) do row[k]=v end
    row.nativeCredit=status=="completed" and work.id or nil
    rows[#rows+1]=row; rec.resourceProductionOutcomes=rows
    if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    if not craftOutcome(rt.id,row) then table.remove(rows); return false end
    rec.resourceProductionWork=nil; rt.closed=true; craftDispose(rt); reconcile(rt.id)
    if SAO.Observation then pcall(SAO.Observation.record,rt.id,"ResourceProduction",status,
        rt.kind=="repair-held-item" and (status=="completed" and "Maintained a carried tool" or "Tool maintenance: "..detail)
            or status=="completed" and "Sawed a carried log into planks" or "Plank crafting: "..detail) end
    return true
end
local function craftRefuse(rt,reason)
    rt.cancelling,rt.cancelReason=true,rt.cancelReason or reason
    if rt.record.resourceProductionWork==rt.work then rt.work.status="interrupted" end
    return false
end
local function craftRecoveryAnchor(rt,rec,work)
    return SAO.Identity.get(rt.id)==rec and rec.id==rt.id and craftIdentity(rt.id,work) and work.id==rt.workId
        and work.purposeId==rt.work.purposeId and work.purposeStepId==rt.work.purposeStepId
        and craftAnchors(rt,work)
        and work.bodyToken==rt.token and work.world==rt.world and work.startedAt==rt.startedAt
        and work.entryKey==rt.entryKey and work.x==rt.square:getX() and work.y==rt.square:getY() and work.z==rt.square:getZ()
end
local function craftSavedRetirement(rt,c)
    c.action.actorId,c.action.workId,c.action.bodyToken=rt.id,rt.workId,rt.token
    c.action._SAOCraftRetireSaved=function(rec,work)
        if craftCapsule(c.action)~=c or not craftRecoveryAnchor(rt,rec,work) then return false end
        local closed=craftInterrupt(rt.id,rt.body,"craft-runtime-unavailable")
        if not closed and craftRetired(rt) and rec.resourceProductionWork~=rt.work then craftDispose(rt);return true end
        return closed
    end
end
local craftEnqueue
local function craftGuardStop(rt,c,transfer)
    local a=c.action
    function a:stop()
        if c.ack or craftCapsule(self)~=c then return false end
        local owned=craftCurrent(c)
        craftRefuse(rt,"native-craft-stopped")
        if owned and craftCurrent(c) then
            if transfer then
                pcall(function() self:playSourceContainerCloseSound() end)
                pcall(function() self:playDestContainerCloseSound() end)
                pcall(function() self:stopLoopingSound() end)
                pcall(function() c.item:setJobDelta(0) end)
                pcall(function() if self.action then self.action:setLoopedAction(false) end end)
                pcall(function() removeItemTransaction(self.transactionId,true) end)
                self.started=false
            elseif rt.kind=="fix-held-item" then
                pcall(function() self.item:setJobDelta(0) end)
                if c.kind=="equip" then
                    pcall(function() if self.sound then rt.body:getEmitter():stopSound(self.sound) end end)
                    pcall(function() self:restoreWeaponType() end)
                end
            else
                pcall(function() self:clearItemsProgressBar(false) end)
                pcall(function() self:stopSound() end)
            end
            if rt.kind~="fix-held-item" then rt.body:setIsFarming(false) end
            c.ack=true; rt.queue:onCompleted(self)
        else
            c.ack=true; rt.queue:removeFromQueue(self)
            if rt.queue.current==self then rt.queue.current=nil end
        end
        craftClose(rt,"interrupted",rt.cancelReason); return true
    end
    function a:forceCancel()
        if c.ack or craftCapsule(self)~=c then return false end
        craftRefuse(rt,"native-craft-force-cancel")
        if not self.action then
            c.ack=true; rt.queue:removeFromQueue(self)
            if rt.queue.current==self then rt.queue.current=nil end
        end
        return false
    end
end
local function craftTransfer(rt,item)
    local source=item:getContainer()
    local a=ISInventoryTransferAction:new(rt.body,item,source,rt.inventory)
    local c={rt=rt,action=a,item=item,source=source,kind="transfer"}
    a._SAOCraftBinding=function(seal) if seal==CRAFT_SEAL then return c end end
    a.canMergeAction=function() return false end
    local nativeValid,nativePerform=a.isValid,a.perform
    local function valid()
        return craftCapsule(a)==c and not c.done and craftBound(rt,true)
            and a.item==item and a.srcContainer==source and a.destContainer==rt.inventory
            and item:getContainer()==source and source:getOutermostContainer()==rt.inventory and source:contains(item)
    end
    function a:isValidStart() return valid() and nativeValid(self)==true or false end
    function a:isValid() return valid() and nativeValid(self)==true or false end
    function a:perform()
        local ql=self.queueList
        if c.performed or not craftCurrent(c) or not craftNativeEnded(self) or not valid()
            or type(ql)~="table" or #ql~=1 or #ql[1].items~=1 or ql[1].items[1]~=item then
            return craftRefuse(rt,"craft-transfer-owner-changed")
        end
        c.performed=true
        local ok=pcall(nativePerform,self)
        c.done,c.ack=true,true
        if not ok or not craftBound(rt,true) or item:getContainer()~=rt.inventory or source:contains(item)
            or rt.queue:indexOf(self)~=-1 or rt.queue.current==self then return craftRefuse(rt,"craft-transfer-unconfirmed") end
        return craftEnqueue(rt,c.position+1)
    end
    function a:complete() return false end
    craftGuardStop(rt,c,true)
    c.position=#rt.actions+1;rt.actions[c.position]=c
    craftSavedRetirement(rt,c)
end
local function craftAction(rt,containers,manual,items)
    local a=ISHandcraftAction:new(rt.body,rt.recipe,containers,nil,nil,manual,items,nil,1,0)
    local c={rt=rt,action=a,kind="craft",manual=a.manualInputs,containers=containers,items=items}
    a._SAOCraftBinding=function(seal) if seal==CRAFT_SEAL then return c end end
    local valid,start,perform,complete,performRecipe=a.isValid,a.start,a.perform,a.complete,a.performRecipe
    function a:isValidStart() return not c.done and craftBound(rt,true) and craftExactInputs(c) and valid(self)==true or false end
    function a:isValid() return not c.done and craftBound(rt,true) and craftExactInputs(c) and valid(self)==true or false end
    function a:start()
        if not craftCurrent(c) or not self:isValid() then return craftRefuse(rt,"craft-start-owner-changed") end
        local ok=pcall(start,self)
        c.logic=self.logic
        if not ok or not self.craftStarted or not craftBound(rt,true) or not craftExactInputs(c)
            or not c.logic or c.logic:isManualSelectInputs()~=true or c.logic:canPerformCurrentRecipe()~=true then
            return craftRefuse(rt,"native-craft-start-refused")
        end
        rt.work.stage="crafting"; return true
    end
    function a:serverStart() return false end -- Owned shell work is admitted locally; no unbound network replay.
    function a:performRecipe()
        if c.effectInvoked or not c.performing or not craftCurrent(c) or not craftNativeEnded(self)
            or not craftBound(rt,true) or not craftExactInputs(c) or self.logic~=c.logic
            or not self.craftStarted or c.logic:isManualSelectInputs()~=true
            or c.logic:canPerformCurrentRecipe()~=true then return craftRefuse(rt,"craft-effect-owner-changed") end
        local applied=c.logic:getRecipeData():getAllInputItems()
        if applied:size()~=2 or not applied:contains(rt.inputs[1]) or not applied:contains(rt.inputs[2]) then
            return craftRefuse(rt,"craft-applied-inputs-changed")
        end
        c.effectInvoked,rt.nativeAttempted=true,true
        local ok=pcall(performRecipe,self)
        local data=c.logic:getRecipeData()
        local made,consumed=data:getAllCreatedItems(),data:getAllConsumedItems()
        if rt.kind=="repair-held-item" then
            local kept=data:getAllKeepInputItems()
            rt.nativeCompleted=ok and not rt.cancelling and craftBound(rt,false)
                and made:size()==0 and not consumed:contains(rt.target) and not consumed:contains(rt.tool)
                and kept:size()==2 and kept:contains(rt.target) and kept:contains(rt.tool)
                and ownItem(rt,rt.target) and ownItem(rt,rt.tool)
                and craftCarried(rt.body,rt.targetItemId,rt.targetItemType)==rt.target
                and craftCarried(rt.body,rt.toolItemId,rt.toolItemType)==rt.tool
                and rt.target:getConditionMax()==rt.maxCondition
            if not rt.nativeCompleted then craftRefuse(rt,"native-repair-effect-unconfirmed") end
            return rt.nativeCompleted
        end
        rt.outputItems={}
        for i=0,math.min(made:size(),4)-1 do rt.outputItems[#rt.outputItems+1]=made:get(i) end
        rt.paymentMeasured=consumed:contains(rt.log) and not rt.inventory:containsRecursive(rt.log)
            and rt.log:getCurrentUses()==0 and ownItem(rt,rt.saw)
        local m=craftMeasurement(rt)
        rt.nativeCompleted=ok and not rt.cancelling and craftBound(rt,false) and rt.paymentMeasured
            and m.logConsumed and m.sawRetained and m.held and made:size()==3 and m.outputCount==3
        if not rt.nativeCompleted then craftRefuse(rt,"native-craft-effect-unconfirmed") end
        return rt.nativeCompleted
    end
    function a:perform()
        if c.performed or c.done or not craftCurrent(c) or not craftNativeEnded(self)
            or not c.logic or not craftBound(rt,true) or not craftExactInputs(c) then
            return craftRefuse(rt,"craft-perform-owner-changed")
        end
        c.performed,c.performing=true,true
        local ok=pcall(perform,self); c.performing=false
        if not ok or not c.effectInvoked then return craftRefuse(rt,"native-craft-perform-unconfirmed") end
        return true
    end
    function a:complete()
        if c.done or not c.performed or not c.effectInvoked or craftCapsule(self)~=c
            or rt.queue:indexOf(self)~=-1 or rt.queue.current or #rt.queue.queue>0 then
            return craftRefuse(rt,"craft-complete-owner-changed")
        end
        c.done,c.ack=true,true
        local ok,result=pcall(complete,self)
        local completed=ok and result==true and rt.nativeCompleted and not rt.cancelling and craftBound(rt,false)
        return craftClose(rt,completed and "completed" or "interrupted",
            completed and (rt.kind=="repair-held-item" and "native-tool-benefit-and-wear-measured"
                or "native-log-payment-and-planks-measured") or rt.cancelReason or "native-craft-completion-unconfirmed")
    end
    craftGuardStop(rt,c,false)
    c.position=#rt.actions+1;rt.actions[c.position]=c
    craftSavedRetirement(rt,c)
end
craftEnqueue=function(rt,index)
    local c=rt.actions[index]
    if not c or not craftBound(rt,not rt.nativeAttempted) or rt.queue.current or #rt.queue.queue>0 then
        return craftRefuse(rt,"craft-preparation-queue-changed")
    end
    if c.kind=="fix" then
        if not fixing.prepare(rt) then return craftRefuse(rt,"native-fixing-payment-preparation-changed") end
        rt.prepared=true
    end
    if c.kind=="craft" or c.kind=="fix" then rt.prepared=true; if not craftBound(rt,true) then return craftRefuse(rt,"craft-material-preparation-changed") end end
    rt.current=c;rt.action=c.action
    if not SAO.Needs.queueVerified(c.action) then return craftRefuse(rt,"native-craft-queue-refused") end
    return true
end
craftBegin=function(id,body,step,context)
    local rec=owner(id,body)
    if not rec or runtime[id] or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or not craftLedger(rec) or not R.craftingAvailable(id,body) or SAO.Needs.busy(body)
        or step.owner~="SAO.ResourceProduction" or step.token~="resource:crafted" or step.recipeId~=CRAFT_RECIPE
        or step.category~="plank" or not textId(step.logItemId) or not textId(step.sawItemId)
        or step.logItemType~="Base.Log" or not textId(step.sawItemType) or isClient() or isServer() then return false end
    local route=SAO.Locomotion.jobs[id]
    if route and not route.done then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or not p.materialWork or p.materialWork.operation~="board" or not textId(p.materialWork.entryKey)
        or p.steps[p.cursor]~=step or step.id~=context.purposeStepId or p.admission then return false end
    local log=craftCarried(body,step.logItemId,step.logItemType)
    local saw=craftCarried(body,step.sawItemId,step.sawItemType)
    local square,world=body:getCurrentSquare(),getWorld()
    local rt={kind="saw-logs",recipeId=CRAFT_RECIPE,id=id,body=body,record=rec,inventory=body:getInventory(),recipe=registeredRecipe(),
        log=log,saw=saw,inputs={log,saw},actions={},queue=ISTimedActionQueue.getTimedActionQueue(body),purpose=p,step=step,
        square=square,cell=body:getCell(),world=world:getWorld(),token=body:getModData().SAOExternalToken,
        x=body:getX(),y=body:getY(),startedAt=now(),beforeIds={}}
    if not log or not saw or log==saw or not ownItem(rt,log) or not ownItem(rt,saw)
        or log:getCurrentUses()~=1 or log:getIsCraftingConsumed() or not saw:hasTag(ItemTag.SAW)
        or saw:getIsCraftingConsumed() or saw:getCondition()<=0 or saw:isBroken()
        or rt.queue.current or #rt.queue.queue>0 then return false end
    local logic,containers,manual,items=craftSelection(rt)
    if not logic or items:size()~=2 or not items:contains(log) or not items:contains(saw) then return false end
    local held=SAOJavaBridge:privateCarriedItems(body)
    if held:size()>512 then return false end
    for i=0,held:size()-1 do rt.beforeIds[tostring(held:get(i):getID())]=true end
    local seq=(rec.resourceProductionSequence or 0)+1
    local work={id="resource-production/"..tostring(id).."/"..seq,sequence=seq,actorId=id,kind="saw-logs",
        recipeId=CRAFT_RECIPE,category="plank",token="resource:crafted",logItemId=step.logItemId,logItemType=step.logItemType,
        sawItemId=step.sawItemId,sawItemType=step.sawItemType,requestedPurposeId=context.purposeId,
        requestedPurposeStepId=context.purposeStepId,purposeId=context.purposeId,purposeStepId=context.purposeStepId,
        entryKey=p.materialWork.entryKey,world=rt.world,bodyToken=rt.token,x=square:getX(),y=square:getY(),z=square:getZ(),
        beforeLogUses=log:getCurrentUses(),sawConditionBefore=saw:getCondition(),startedAt=rt.startedAt,
        stage="preparing",status="crafting"}
    rt.work,rt.workId=work,work.id
    rt.entryKey,rt.beforeLogUses,rt.sawConditionBefore=work.entryKey,work.beforeLogUses,work.sawConditionBefore
    if not craftIdentity(id,work) then return false end
    for _,item in ipairs({log,saw}) do if item:getContainer()~=rt.inventory then craftTransfer(rt,item) end end
    craftAction(rt,containers,manual,items)
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,work,rt
    local planning=SAO.ProceduralPlanning
    if not planning or not planning.admitCraftProduction or planning.admitCraftProduction(id,work)~=true then
        rec.resourceProductionWork=nil;craftDispose(rt);return false
    end
    if not craftBound(rt,true) or not craftEnqueue(rt,1) then craftInterrupt(id,body,"native-craft-admission-refused");return false end
    return true
end
local function repairBegin(id,body,step,context)
    local rec=owner(id,body)
    local policy=REPAIR_POLICIES[step.recipeId]
    if not policy or not rec or runtime[id] or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or not craftLedger(rec) or SAO.Needs.busy(body) or step.owner~="SAO.ResourceProduction"
        or step.token~="resource:repaired" or step.target~=step.recipeId or step.category~=policy.category
        or (step.toolCategory~=policy.toolCategory and (step.recipeId~=REPAIR_RECIPE or step.toolCategory~=nil))
        or step.effectMetric~=nil and step.effectMetric~=policy.effectMetric
        or not textId(step.targetItemId) or not textId(step.targetItemType)
        or not textId(step.toolItemId) or not textId(step.toolItemType) or isClient() or isServer() then return false end
    local route=SAO.Locomotion.jobs[id]
    if route and not route.done then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or not p.materialWork or not textId(p.materialWork.entryKey)
        or not craftPurposeTarget(p,{kind="repair-held-item",entryKey=p.materialWork.entryKey,
            targetItemId=step.targetItemId,targetItemType=step.targetItemType})
        or p.steps[p.cursor]~=step or step.id~=context.purposeStepId or p.admission then return false end
    local target=craftCarried(body,step.targetItemId,step.targetItemType)
    local tool=craftCarried(body,step.toolItemId,step.toolItemType)
    if not R.repairAvailable(id,body,target,step.recipeId) then return false end
    local square,world=body:getCurrentSquare(),getWorld()
    local rt={kind="repair-held-item",recipeId=step.recipeId,id=id,body=body,record=rec,inventory=body:getInventory(),
        recipe=registeredRecipe(step.recipeId),target=target,tool=tool,inputs={target,tool},actions={},
        queue=ISTimedActionQueue.getTimedActionQueue(body),purpose=p,step=step,square=square,cell=body:getCell(),
        world=world:getWorld(),token=body:getModData().SAOExternalToken,x=body:getX(),y=body:getY(),startedAt=now()}
    if not tool or target==tool or not ownItem(rt,target) or not ownItem(rt,tool) or not repairToolEligible(tool,policy)
        or tool:getCondition()<=0 or tool:isBroken() or tool:getIsCraftingConsumed()
        or rt.queue.current or #rt.queue.queue>0 then return false end
    local logic,containers,manual,items=craftSelection(rt)
    if not logic or items:size()~=2 or not items:contains(target) or not items:contains(tool) then return false end
    local seq=(rec.resourceProductionSequence or 0)+1
    local work={id="resource-production/"..tostring(id).."/"..seq,sequence=seq,actorId=id,kind=rt.kind,
        recipeId=step.recipeId,category=policy.category,effectMetric=policy.effectMetric,toolCategory=policy.toolCategory,
        token="resource:repaired",targetItemId=step.targetItemId,
        targetItemType=step.targetItemType,toolItemId=step.toolItemId,toolItemType=step.toolItemType,
        requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,
        purposeId=context.purposeId,purposeStepId=context.purposeStepId,entryKey=p.materialWork.entryKey,
        world=rt.world,bodyToken=rt.token,x=square:getX(),y=square:getY(),z=square:getZ(),
        beforeCondition=target:getCondition(),maxCondition=target:getConditionMax(),beforeRepairCount=target:getHaveBeenRepaired(),
        beforeToolCondition=tool:getCondition(),startedAt=rt.startedAt,stage="preparing",status="crafting"}
    if target:hasSharpness() then work.beforeSharpness,work.maxSharpness=target:getSharpness(),target:getMaxSharpness() end
    if target:hasHeadCondition() then work.beforeHeadCondition,work.maxHeadCondition=target:getHeadCondition(),target:getHeadConditionMax() end
    rt.work,rt.workId,rt.entryKey=work,work.id,work.entryKey
    for _,key in ipairs({"targetItemId","targetItemType","toolItemId","toolItemType","beforeCondition",
        "maxCondition","beforeRepairCount","beforeToolCondition","effectMetric","toolCategory",
        "beforeSharpness","maxSharpness","beforeHeadCondition","maxHeadCondition"}) do rt[key]=work[key] end
    if not craftIdentity(id,work) then return false end
    for _,item in ipairs(rt.inputs) do if item:getContainer()~=rt.inventory then craftTransfer(rt,item) end end
    craftAction(rt,containers,manual,items)
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,work,rt
    local planning=SAO.ProceduralPlanning
    if not planning or not planning.admitRepairProduction or planning.admitRepairProduction(id,work)~=true then
        rec.resourceProductionWork=nil;craftDispose(rt);return false
    end
    if not craftBound(rt,true) or not craftEnqueue(rt,1) then craftInterrupt(id,body,"native-repair-admission-refused");return false end
    return true
end

-- Registered native item fixing uses the same physical-work claim and native
-- acknowledgement machinery; FixingManager owns payment and weapon contents.
fixing={}
function fixing.copy(v,depth)
    depth=depth or 0;if depth>8 then return nil end
    if type(v)~="table" then return v end
    if getmetatable(v) then return nil end
    local out,n={},0
    for k,x in pairs(v) do
        n=n+1;if n>160 or type(k)~="string" and type(k)~="number" then return nil end
        local kind=type(x)
        if kind~="table" and kind~="string" and kind~="number" and kind~="boolean" then return nil end
        local copied=fixing.copy(x,depth+1);if copied==nil then return nil end;out[k]=copied
    end
    return out
end
function fixing.install()
    local ok=pcall(function() require "TimedActions/ISFixAction";require "TimedActions/ISEquipWeaponAction";require "TimedActions/ISInventoryTransferAction" end)
    return ok and FixingManager and ScriptManager and ScriptManager.instance and ArrayList and ISFixAction and ISEquipWeaponAction
end
function fixing.key(def,index)
    return "fixing:"..def:getModule():getName().."."..def:getName()..":"..tostring(index)
end
function fixing.policy(key)
    if not fixing.install() or not textId(key) or key:sub(1,7)~="fixing:" then return nil end
    local all=ScriptManager.instance:getAllFixing(ArrayList.new())
    for i=0,all:size()-1 do
        local def=all:get(i)
        for j=0,def:getFixers():size()-1 do
            local fixer=def:getFixers():get(j)
            if fixing.key(def,j)==key and fixer:getNumberOfUse()==1 and def:getGlobalItem()==nil then
                return {recipeId=key,category="weapon",toolCategory="weapons",effectMetric="condition",productionKind="fix-held-item"}
            end
        end
    end
end
function fixing.registered(body,target,key)
    if not fixing.policy(key) then return nil end
    local all=FixingManager.getFixes(target)
    for i=0,all:size()-1 do
        local def=all:get(i)
        for j=0,def:getFixers():size()-1 do
            local fixer=def:getFixers():get(j)
            if fixing.key(def,j)==key then
                local skills=fixer:getFixerSkills()
                for n=0,(skills and skills:size() or 0)-1 do
                    local skill=skills:get(n)
                    if body:getPerkLevel(Perks.FromString(skill:getSkillName()))<skill:getSkillLevel() then return nil end
                end
                return def,fixer,i,j
            end
        end
    end
end
function R.fixingAvailable(id,body,target,key)
    local ok,value=pcall(function()
        return owner(id,body) and now() and craftPosition(id,body)
            and target and instanceof(target,"HandWeapon") and target:isRanged() and not target:isBroken()
            and target:getCondition()>0 and target:getCondition()<target:getConditionMax() and not target:getIsCraftingConsumed()
            and craftCarried(body,tostring(target:getID()),target:getFullType())==target
            and ownItem({inventory=body:getInventory()},target) and fixing.registered(body,target,key)~=nil
    end)
    return ok and value==true
end
function fixing.options(id,body)
    local out={}
    if not fixing.install() then return out end
    local items=SAOJavaBridge:privateCarriedItems(body)
    if items:size()>512 then return out end
    for n=0,items:size()-1 do
        local target=items:get(n)
        if instanceof(target,"HandWeapon") and target:isRanged() and target:getCondition()>0
            and not target:isBroken() and target:getCondition()<target:getConditionMax() then
            local defs=FixingManager.getFixes(target)
            for i=0,defs:size()-1 do local def=defs:get(i)
                for j=0,def:getFixers():size()-1 do
                    local key=fixing.key(def,j)
                    if R.fixingAvailable(id,body,target,key) then
                        local option=fixing.policy(key);local fixer=def:getFixers():get(j)
                        option.targetItemId,option.targetItemType=tostring(target:getID()),target:getFullType()
                        option.condition,option.maxCondition=target:getCondition(),target:getConditionMax()
                        option.requiredItemType=fixer:getFixerName()
                        -- Native firearm fixers consume one same-full-type weapon. The
                        -- private carried selection excludes reserved donors before
                        -- native root payment order is prepared and revalidated.
                        for donorIndex=0,items:size()-1 do
                            local donor=items:get(donorIndex)
                            if donor~=target and donor:getFullType()==fixer:getFixerName()
                                and not donor:getIsCraftingConsumed()
                                and ownItem({inventory=body:getInventory()},donor)
                                and craftCarried(body,tostring(donor:getID()),donor:getFullType())==donor then
                                option.toolItemId,option.toolItemType=tostring(donor:getID()),donor:getFullType()
                                break
                            end
                        end
                        out[#out+1]=option;if #out==32 then return out end
                    end
                end
            end
        end
    end
    return out
end
function fixing.sameStep(s,w)
    return s.targetItemId==w.targetItemId and s.targetItemType==w.targetItemType
        and s.toolItemId==w.toolItemId and s.toolItemType==w.toolItemType
        and s.toolCategory=="weapons" and s.effectMetric=="condition"
end
local FIXING_FIELDS={}
for _,key in ipairs({"id","sequence","actorId","kind","recipeId","category","effectMetric","toolCategory","token",
    "targetItemId","targetItemType","toolItemId","toolItemType","requestedPurposeId","requestedPurposeStepId",
    "purposeId","purposeStepId","entryKey","world","bodyToken","x","y","z","beforeCondition","maxCondition",
    "beforeRepairCount","beforeToolCondition","fixingNum","fixerNum","startedAt","stage","status","workId",
    "detail","nativeOwner","atHours","endedAt","nativeCredit","nativeObservability","nativeAttempted","nativeCompleted",
    "afterCondition","afterRepairCount","targetRetained","held","paymentConsumed","returnsMeasured","reequipped",
    "improved","fullRestoration","returnedItems","purposeDelivered","experienceDelivered"}) do FIXING_FIELDS[key]=true end
function fixing.identity(id,w)
    if type(w)~="table" or getmetatable(w) then return false end
    for k,v in pairs(w) do
        if not FIXING_FIELDS[k] or k~="returnedItems" and (type(v)~="string" and type(v)~="number" and type(v)~="boolean"
            or type(v)=="number" and not finite(v) or type(v)=="string" and #v>512) then return false end
    end
    return type(w)=="table" and not getmetatable(w) and w.actorId==id and integer(w.sequence) and w.sequence>=1
        and w.id=="resource-production/"..tostring(id).."/"..w.sequence and textId(w.purposeId) and textId(w.purposeStepId)
        and w.kind=="fix-held-item" and w.category=="weapon" and w.toolCategory=="weapons" and w.effectMetric=="condition"
        and w.token=="resource:repaired" and fixing.policy(w.recipeId)~=nil
        and textId(w.targetItemId) and textId(w.targetItemType) and textId(w.toolItemId) and textId(w.toolItemType)
        and w.targetItemId~=w.toolItemId and integer(w.beforeCondition) and w.beforeCondition>0
        and integer(w.maxCondition) and w.beforeCondition<w.maxCondition and integer(w.beforeRepairCount)
        and integer(w.beforeToolCondition) and finite(w.startedAt) and w.startedAt>=0
        and textId(w.world) and (w.bodyToken==nil or textId(w.bodyToken)) and textId(w.entryKey)
        and w.entryKey=="held-item:"..w.targetItemId and finite(w.x) and finite(w.y) and finite(w.z)
        and integer(w.fixingNum) and integer(w.fixerNum)
end
function fixing.anchors(rt,w)
    for _,key in ipairs({"targetItemId","targetItemType","toolItemId","toolItemType","beforeCondition","maxCondition",
        "beforeRepairCount","beforeToolCondition","fixingNum","fixerNum"}) do if w[key]~=rt[key] then return false end end
    return true
end
-- Match the producer's raw root traversal, including entries with stale custody
-- or reservation flags; custody eligibility applies to the captured donor only.
function fixing.rawDonor(rt)
    local items=rt.inventory:getItems()
    for i=0,items:size()-1 do local item=items:get(i)
        if item~=rt.target and item and item:getFullType()==rt.fixer:getFixerName() then return item end
    end
end
function fixing.prepare(rt)
    if rt.target:getContainer()~=rt.inventory or rt.tool:getContainer()~=rt.inventory then return false end
    local items=rt.inventory:getItems();local first,selected
    for i=0,items:size()-1 do local item=items:get(i)
        if item==rt.tool then selected=i end
        if first==nil and item~=rt.target and item and item:getFullType()==rt.fixer:getFixerName() then first=i end
    end
    if first==nil or selected==nil then return false end
    if first~=selected then local displaced=items:get(first);items:set(first,rt.tool);items:set(selected,displaced) end
    return fixing.rawDonor(rt)==rt.tool
end
function fixing.bound(rt,materials)
    if isClient() or isServer() then return false end
    local def,fixer,i,j=fixing.registered(rt.body,rt.target,rt.recipeId)
    if def~=rt.fixing or fixer~=rt.fixer or i~=rt.fixingNum or j~=rt.fixerNum then return false end
    if not ownItem(rt,rt.target) or craftCarried(rt.body,rt.targetItemId,rt.targetItemType,rt.nativeAttempted and 640 or 512)~=rt.target
        or rt.target:getConditionMax()~=rt.maxCondition then return false end
    if rt.nativeCompleted and (rt.target:getCondition()~=rt.afterCondition
        or rt.target:getHaveBeenRepaired()~=rt.afterRepairCount) then return false end
    if materials then
        if not R.fixingAvailable(rt.id,rt.body,rt.target,rt.recipeId) or not ownItem(rt,rt.tool)
            or craftCarried(rt.body,rt.toolItemId,rt.toolItemType)~=rt.tool or rt.tool==rt.target
            or rt.tool:getFullType()~=rt.fixer:getFixerName() or rt.tool:getIsCraftingConsumed()
            or rt.target:getCondition()~=rt.beforeCondition or rt.target:getHaveBeenRepaired()~=rt.beforeRepairCount
            or rt.tool:getCondition()~=rt.beforeToolCondition or not fixing.contentsEqual(rt)
            or rt.prepared and (rt.target:getContainer()~=rt.inventory or rt.tool:getContainer()~=rt.inventory
                or fixing.rawDonor(rt)~=rt.tool) then return false end
    end
    return true
end
function fixing.contents(rt)
    local donor=rt.tool;rt.parts={};local parts=donor:getAllWeaponParts()
    for i=0,parts:size()-1 do rt.parts[#rt.parts+1]=parts:get(i) end
    rt.magazine=donor:getMagazineType();rt.clip=donor:isContainsClip()
    rt.ammo=donor:getCurrentAmmoCount();rt.chamber=donor:haveChamber() and donor:isRoundChambered()
    rt.ammoType=donor:getAmmoType() and donor:getAmmoType():getItemKey() or nil
end
function fixing.contentsEqual(rt)
    local d=rt.tool;local parts=d:getAllWeaponParts()
    if parts:size()~=#rt.parts or d:getMagazineType()~=rt.magazine or d:isContainsClip()~=rt.clip
        or d:getCurrentAmmoCount()~=rt.ammo or (d:haveChamber() and d:isRoundChambered())~=rt.chamber
        or (d:getAmmoType() and d:getAmmoType():getItemKey() or nil)~=rt.ammoType then return false end
    for i=0,parts:size()-1 do if parts:get(i)~=rt.parts[i+1] then return false end end
    return true
end
function fixing.returned(rt,before)
    local expected,parts={},{}
    for _,part in ipairs(rt.parts) do parts[part]=true end
    if rt.magazine and rt.clip then expected[rt.magazine]=1 end
    local loose=(rt.magazine and rt.clip and 0 or rt.ammo)+(rt.chamber and 1 or 0)
    if loose>0 then expected[rt.ammoType]=(expected[rt.ammoType] or 0)+loose end
    local rows,items={},rt.inventory:getItems()
    for i=0,items:size()-1 do local item=items:get(i)
        if not before[item] then
            if item:getContainer()~=rt.inventory or #rows>=128 then return false end
            if parts[item] then parts[item]=nil
            elseif (expected[item:getFullType()] or 0)>0 then
                expected[item:getFullType()]=expected[item:getFullType()]-1
                if rt.magazine and rt.clip and item:getFullType()==rt.magazine and item:getCurrentAmmoCount()~=rt.ammo then return false end
            else return false end
            rows[#rows+1]={itemId=tostring(item:getID()),itemType=item:getFullType(),ammoCount=item:getCurrentAmmoCount()}
        end
    end
    for _,n in pairs(expected) do if n~=0 then return false end end
    for _ in pairs(parts) do return false end
    rt.returnedItems=rows;return true
end
function fixing.measure(rt)
    local held=ownItem(rt,rt.target) and craftCarried(rt.body,rt.targetItemId,rt.targetItemType,640)==rt.target or false
    local completed=rt.nativeCompleted==true and held
    local after=rt.afterCondition or rt.beforeCondition
    local gain=completed and after>rt.beforeCondition
    return {nativeAttempted=rt.nativeAttempted==true,nativeCompleted=completed,
        afterCondition=after,afterRepairCount=rt.afterRepairCount or rt.beforeRepairCount,
        targetRetained=held,held=held,paymentConsumed=rt.paymentConsumed==true,returnsMeasured=rt.returnsMeasured==true,
        reequipped=completed and rt.reequipped==true,improved=gain,fullRestoration=gain and after>=rt.maxCondition,
        returnedItems=fixing.copy(rt.returnedItems or {})}
end
function fixing.outcome(id,row)
    for k,v in pairs(type(row)=="table" and row or {}) do
        if not FIXING_FIELDS[k] or k~="returnedItems" and (type(v)~="string" and type(v)~="boolean" and type(v)~="number"
            or type(v)=="number" and not finite(v) or type(v)=="string" and #v>512) then return nil end
    end
    local rec=SAO.Identity.get(id)
    if not craftLedger(rec) or not fixing.identity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISFixAction" or not textId(row.detail)
        or not finite(row.atHours) or row.atHours<row.startedAt or row.endedAt~=row.atHours
        or row.status~="completed" and row.status~="failed" and row.status~="interrupted" then return nil end
    for _,key in ipairs({"nativeAttempted","nativeCompleted","targetRetained","held","paymentConsumed","returnsMeasured","reequipped","improved","fullRestoration"}) do
        if type(row[key])~="boolean" then return nil end
    end
    local returned=row.returnedItems
    if type(returned)~="table" or getmetatable(returned) or #returned>128 then return nil end
    local seen,n={},0
    for k,v in pairs(returned) do
        if not integer(k) or k<1 or k>#returned or type(v)~="table" or getmetatable(v)
            or not textId(v.itemId) or not textId(v.itemType) or not integer(v.ammoCount) or seen[v.itemId]
            or v.itemId==row.targetItemId or v.itemId==row.toolItemId then return nil end
        for key in pairs(v) do if key~="itemId" and key~="itemType" and key~="ammoCount" then return nil end end
        seen[v.itemId]=true;n=n+1
    end
    if n~=#returned then return nil end
    if row.nativeObservability=="runtime-unavailable" then
        if row.status~="interrupted" or row.nativeAttempted or row.nativeCompleted or row.held or row.paymentConsumed
            or row.returnsMeasured or row.reequipped or row.improved or row.afterCondition~=nil or #returned~=0 then return nil end
    elseif row.nativeObservability~=nil or not integer(row.afterCondition) or row.afterCondition>row.maxCondition
        or not integer(row.afterRepairCount) or row.held~=row.targetRetained
        or row.improved~=(row.nativeCompleted and row.held and row.afterCondition>row.beforeCondition)
        or row.fullRestoration~=(row.improved and row.afterCondition>=row.maxCondition)
        or row.nativeCompleted and (not row.nativeAttempted or not row.paymentConsumed or not row.returnsMeasured or not row.held)
        or row.reequipped and not row.nativeCompleted
        or (row.paymentConsumed or row.returnsMeasured) and not row.nativeAttempted
        or row.nativeCompleted and row.afterRepairCount~=(row.improved and row.beforeRepairCount+1 or row.beforeRepairCount) then return nil end
    if row.status=="completed" and (not row.nativeCompleted or not row.improved or not row.reequipped or row.nativeCredit~=row.id)
        or row.status~="completed" and row.nativeCredit~=nil then return nil end
    return fixing.copy(row)
end
local function fixingAction(rt)
    local a=ISFixAction:new(rt.body,rt.target,rt.fixingNum,rt.fixerNum)
    local c={rt=rt,action=a,kind="fix"}
    a._SAOCraftBinding=function(seal) if seal==CRAFT_SEAL then return c end end
    local valid,start,perform,complete=a.isValid,a.start,a.perform,a.complete
    function a:serverStart() return false end
    local function exact() return a.character==rt.body and a.item==rt.target and a.fixing==rt.fixing and a.fixer==rt.fixer
        and a.fixingNum==rt.fixingNum and a.fixerNum==rt.fixerNum end
    function a:isValidStart() return not c.done and exact() and craftBound(rt,true) and valid(self)==true end
    function a:isValid() return self:isValidStart() end
    function a:start()
        if not craftCurrent(c) or not self:isValid() then return craftRefuse(rt,"native-fixing-start-owner-changed") end
        local ok=pcall(start,self);if not ok then return craftRefuse(rt,"native-fixing-start-failed") end
        rt.work.stage="fixing";return true
    end
    function a:perform()
        if c.performed or c.done or not craftCurrent(c) or not craftNativeEnded(self) or not self:isValid() then return craftRefuse(rt,"native-fixing-perform-owner-changed") end
        c.performed=true;local ok=pcall(perform,self)
        if not ok then return craftRefuse(rt,"native-fixing-perform-failed") end
        return true
    end
    function a:complete()
        if c.done or not c.performed or craftCapsule(self)~=c or runtime[rt.id]~=rt or rt.current~=c
            or not exact() or not craftBound(rt,true) or valid(self)~=true
            or rt.queue:indexOf(self)~=-1 or rt.queue.current or #rt.queue.queue>0 then return craftRefuse(rt,"native-fixing-complete-owner-changed") end
        local before={};local items=rt.inventory:getItems()
        for i=0,items:size()-1 do before[items:get(i)]=true end
        c.done,c.ack,rt.nativeAttempted=true,true,true
        local ok,result=pcall(complete,self)
        rt.paymentConsumed=not rt.inventory:containsRecursive(rt.tool)
        rt.returnsMeasured=ok and fixing.returned(rt,before)
        rt.afterCondition,rt.afterRepairCount=rt.target:getCondition(),rt.target:getHaveBeenRepaired()
        rt.nativeCompleted=ok and result==true and craftBound(rt,false) and rt.paymentConsumed and rt.returnsMeasured
        if rt.nativeCompleted and not rt.target:isBroken() and rt.target:getCondition()>0 then return craftEnqueue(rt,c.position+1) end
        return craftClose(rt,"failed","native-fixing-result-measured")
    end
    craftGuardStop(rt,c,false);c.position=#rt.actions+1;rt.actions[c.position]=c;craftSavedRetirement(rt,c)
end
local function fixingEquip(rt)
    local a=ISEquipWeaponAction:new(rt.body,rt.target,25,true,rt.target:isTwoHandWeapon())
    local c={rt=rt,action=a,kind="equip"}
    a._SAOCraftBinding=function(seal) if seal==CRAFT_SEAL then return c end end
    local valid,start,perform,complete=a.isValid,a.start,a.perform,a.complete
    function a:serverStart() return false end
    local function exact() return a.character==rt.body and a.item==rt.target and a.primary==true
        and a.twoHands==(rt.target:isTwoHandWeapon() or rt.target:isRequiresEquippedBothHands()) end
    function a:isValidStart() return not c.done and exact() and rt.nativeCompleted and craftBound(rt,false) and valid(self)==true and exact() end
    function a:isValid() return self:isValidStart() end
    function a:start()
        if not craftCurrent(c) or not self:isValid() then return craftRefuse(rt,"native-fixing-equip-start-changed") end
        local alreadyEquipped=self:isAlreadyEquipped()==true
        local result=start(self)
        -- The installed start completes an already held exact item without
        -- writing either hand; its complete reports false for that same path.
        c.alreadyEquipped=alreadyEquipped and self.action and self.action:isForceComplete()==true or false
        return result
    end
    function a:perform()
        if c.done or c.performed or not craftCurrent(c) or not craftNativeEnded(self) or not self:isValid() then return craftRefuse(rt,"native-fixing-equip-perform-changed") end
        c.performed=true;return perform(self)
    end
    function a:complete()
        if c.done or not c.performed or craftCapsule(self)~=c or runtime[rt.id]~=rt or rt.current~=c
            or not self:isValid() or rt.queue:indexOf(self)~=-1 or rt.queue.current or #rt.queue.queue>0 then return craftRefuse(rt,"native-fixing-equip-complete-changed") end
        c.done,c.ack=true,true;local ok,result=pcall(complete,self)
        rt.reequipped=ok and (result==true or c.alreadyEquipped and result==false)
            and craftBound(rt,false) and exact() and rt.body:getPrimaryHandItem()==rt.target
            and (not a.twoHands or rt.body:getSecondaryHandItem()==rt.target)
        return craftClose(rt,rt.reequipped and "completed" or "failed","native-fixing-payment-and-equipment-measured")
    end
    craftGuardStop(rt,c,false);c.position=#rt.actions+1;rt.actions[c.position]=c;craftSavedRetirement(rt,c)
end
function fixing.begin(id,body,step,context)
    local rec=owner(id,body)
    if not rec or runtime[id] or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or not craftLedger(rec) or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) or isClient() or isServer()
        or step.owner~="SAO.ResourceProduction" or step.token~="resource:repaired" or step.target~=step.recipeId
        or step.category~="weapon" or step.toolCategory~="weapons" or step.effectMetric~="condition" then return false end
    local route=SAO.Locomotion.jobs[id];if route and not route.done then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or p.steps[p.cursor]~=step or p.admission or not craftPurposeTarget(p,{kind="fix-held-item",
        entryKey=p.materialWork and p.materialWork.entryKey,targetItemId=step.targetItemId,targetItemType=step.targetItemType}) then return false end
    local target,tool=craftCarried(body,step.targetItemId,step.targetItemType),craftCarried(body,step.toolItemId,step.toolItemType)
    if not R.fixingAvailable(id,body,target,step.recipeId) or not tool or tool==target or tool:getIsCraftingConsumed() then return false end
    local def,fixer,fi,xi=fixing.registered(body,target,step.recipeId)
    if tool:getFullType()~=fixer:getFixerName() then return false end
    local square,world=body:getCurrentSquare(),getWorld()
    local rt={kind="fix-held-item",recipeId=step.recipeId,id=id,body=body,record=rec,inventory=body:getInventory(),
        fixing=def,fixer=fixer,target=target,tool=tool,inputs={target,tool},actions={},
        queue=ISTimedActionQueue.getTimedActionQueue(body),purpose=p,step=step,square=square,cell=body:getCell(),
        world=world:getWorld(),token=body:getModData().SAOExternalToken,x=body:getX(),y=body:getY(),startedAt=now()}
    if not ownItem(rt,tool) or rt.queue.current or #rt.queue.queue>0 then return false end
    fixing.contents(rt);if #rt.parts+rt.ammo+(rt.chamber and 1 or 0)>128 then return false end
    local seq=(rec.resourceProductionSequence or 0)+1
    local work={id="resource-production/"..id.."/"..seq,sequence=seq,actorId=id,kind=rt.kind,
        recipeId=step.recipeId,category="weapon",effectMetric="condition",toolCategory="weapons",token="resource:repaired",
        targetItemId=step.targetItemId,targetItemType=step.targetItemType,toolItemId=step.toolItemId,toolItemType=step.toolItemType,
        requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,purposeId=context.purposeId,purposeStepId=context.purposeStepId,
        entryKey=p.materialWork.entryKey,world=rt.world,bodyToken=rt.token,x=square:getX(),y=square:getY(),z=square:getZ(),
        beforeCondition=target:getCondition(),maxCondition=target:getConditionMax(),beforeRepairCount=target:getHaveBeenRepaired(),
        beforeToolCondition=tool:getCondition(),fixingNum=fi,fixerNum=xi,startedAt=rt.startedAt,stage="preparing",status="crafting"}
    rt.work,rt.workId,rt.entryKey=work,work.id,work.entryKey
    for _,key in ipairs({"targetItemId","targetItemType","toolItemId","toolItemType","beforeCondition","maxCondition",
        "beforeRepairCount","beforeToolCondition","fixingNum","fixerNum"}) do rt[key]=work[key] end
    if not fixing.identity(id,work) then return false end
    for _,item in ipairs(rt.inputs) do if item:getContainer()~=rt.inventory then craftTransfer(rt,item) end end
    fixingAction(rt);fixingEquip(rt)
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,work,rt
    if not SAO.ProceduralPlanning.admitRepairProduction(id,work) then rec.resourceProductionWork=nil;craftDispose(rt);return false end
    if not craftBound(rt,true) or not craftEnqueue(rt,1) then craftInterrupt(id,body,"native-fixing-admission-refused");return false end
    return true
end

craftRecover=function(id,body)
    reconcile(id)
    -- Quiescence is separate from permission to drive physical effects. An
    -- adopting controller or pending body transfer still owns saved work.
    local rec=SAO.Identity.get(id)
    local work=rec and rec.resourceProductionWork
    if not work then return true end
    if runtime[id] then return craftInterrupt(id,body,"craft-owner-reconciled") end
    local t=now()
    if not craftLedger(rec) or not craftIdentity(id,work) or work.sequence>rec.resourceProductionSequence
        or (work.status~="crafting" and work.status~="interrupted") or not t or t<work.startedAt
        or not body or tostring(body:getModData().SAOPersonId or "")~=tostring(id)
        or work.bodyToken~=body:getModData().SAOExternalToken or work.world~=getWorld():getWorld()
        or not craftPurpose(rec,work) then return false end
    for _,pendingQueue in pairs(ISTimedActionQueue.queues) do
        local pending={}
        for _,a in ipairs(pendingQueue.queue) do pending[#pending+1]=a end
        if pendingQueue.current and pendingQueue:indexOf(pendingQueue.current)==-1 then pending[#pending+1]=pendingQueue.current end
        for _,a in ipairs(pending) do
            if a.actorId==id and a.workId==work.id and a.bodyToken==work.bodyToken then
                if type(a._SAOCraftRetireSaved)~="function" then return false end
                local ok,closed=pcall(a._SAOCraftRetireSaved,rec,work)
                if not ok or not closed then return false end
            end
        end
    end
    if rec.resourceProductionWork==nil then return true end
    if SAOJavaBridge:hasPendingActions(body) then return false end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if q.current or #q.queue>0 then return false end
    local rows=rec.resourceProductionOutcomes or {}
    for _,row in ipairs(rows) do if row.id==work.id then return false end end
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row={}
    for key in pairs(CRAFT_FIELDS) do if key~="outputs" then row[key]=work[key] end end
    if work.kind=="fix-held-item" then row=fixing.copy(work) end
    row.workId,row.status,row.detail,row.nativeOwner=work.id,"interrupted","craft-runtime-unavailable",work.kind=="fix-held-item" and "ISFixAction" or "ISHandcraftAction"
    row.atHours,row.endedAt,row.nativeObservability=t,t,"runtime-unavailable"
    if work.kind=="fix-held-item" then
        row.nativeAttempted,row.nativeCompleted,row.targetRetained,row.paymentConsumed,row.returnsMeasured,row.reequipped,row.held,row.improved,row.fullRestoration=false,false,false,false,false,false,false,false,false
        row.returnedItems={}
    elseif work.kind=="repair-held-item" then
        row.nativeAttempted,row.nativeCompleted,row.targetRetained,row.toolRetained,row.held,row.improved,row.fullRestoration=
            false,false,false,false,false,false,false
    else
        row.nativeAttempted,row.logConsumed,row.sawRetained,row.held,row.outputCount,row.outputs=false,false,false,false,0,{}
    end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows
    if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    if not craftOutcome(id,row) then table.remove(rows);return false end
    rec.resourceProductionWork=nil;reconcile(id);return true
end
craftInterrupt=function(id,body,reason)
    local rt=runtime[id]
    if not rt then return craftRecover(id,body) end
    if not nativeCraftKind(rt.kind) or body and rt.body~=body then return false end
    if rt.nativeCompleted and craftRetired(rt) and not rt.cancelling then
        return craftClose(rt,"completed","native-craft-completed-before-interruption")
    end
    craftRefuse(rt,reason or "higher-priority-work")
    for _,c in ipairs(rt.actions) do
        if not c.ack then
            if c.action.action then pcall(function() c.action:forceStop() end)
            else c.action:forceCancel() end
        end
    end
    return rt.closed==true or craftClose(rt,"interrupted",rt.cancelReason)
end
craftTick=function(id,body)
    local rt=runtime[id]
    if not rt then return craftRecover(id,body) and "interrupted" or "cancelling" end
    if rt.cancelling or rt.body~=body or not craftBound(rt,not rt.nativeAttempted)
        or not now() or now()-rt.startedAt>.5 then
        return craftInterrupt(id,rt.body,rt.cancelReason or "craft-owner-or-material-changed") and "interrupted" or "cancelling"
    end
    if queued(rt.action) then return rt.work.stage end
    if not craftRetired(rt) then return craftInterrupt(id,body,"craft-native-acknowledgement-missing") and "interrupted" or "cancelling" end
    return craftClose(rt,rt.nativeCompleted and "completed" or "failed","native-craft-ended") and "completed" or "cancelling"
end
-- Plumbing changes an observed fixture; the following refill still owns water gain.
local PLUMB_SEAL = {}
local PLUMB_FIELDS={id=true,workId=true,sequence=true,actorId=true,kind=true,category=true,token=true,
    sourceId=true,sourceRevision=true,fingerprint=true,sourceX=true,sourceY=true,sourceZ=true,
    sourceChunkX=true,sourceChunkY=true,place=true,itemId=true,itemType=true,beforeAmount=true,capacity=true,
    toolCategory=true,toolItemId=true,toolItemType=true,purposeId=true,purposeStepId=true,
    requestedPurposeId=true,requestedPurposeStepId=true,world=true,bodyToken=true,startedAt=true,
    status=true,detail=true,atHours=true,endedAt=true,nativeOwner=true,nativeAttempted=true,nativeCompleted=true,
    toolRetained=true,beforeUsesExternalWaterSource=true,beforeCanBeWaterPiped=true,beforePlumbingEligible=true,
    afterUsesExternalWaterSource=true,afterCanBeWaterPiped=true,connected=true,nativeCredit=true,
    nativeObservability=true,sourceObservation=true,purposeDelivered=true,experienceDelivered=true}
local function plumbCopy(value,depth)
    local kind=type(value)
    if kind=="string" then return #value<=512 and value or nil end
    if kind=="number" then return finite(value) and value or nil end
    if kind=="boolean" then return value end
    if kind~="table" or getmetatable(value) or depth>3 then return nil end
    local out,count={},0
    for k,v in pairs(value) do
        count=count+1
        if count>32 or type(k)~="string" or #k>128 then return nil end
        local copied=plumbCopy(v,depth+1)
        if copied==nil then return nil end
        out[k]=copied
    end
    return out
end
local function plumbIdentity(id,w)
    if w and nativeEntityKind(w.kind) then return collector.identity(id,w) end
    return type(w)=="table" and not getmetatable(w) and w.actorId==id and integer(w.sequence) and w.sequence>0
        and w.id=="resource-production/"..tostring(id).."/"..w.sequence and w.kind=="plumb-fixture"
        and w.category=="water" and w.token=="resource:plumbed" and textId(w.purposeId) and textId(w.purposeStepId)
        and textId(w.sourceId) and w.sourceId:sub(1,2)=="F:" and textId(w.sourceRevision) and textId(w.fingerprint)
        and finite(w.sourceX) and w.sourceX%1==0 and finite(w.sourceY) and w.sourceY%1==0 and finite(w.sourceZ) and w.sourceZ%1==0
        and finite(w.sourceChunkX) and finite(w.sourceChunkY) and type(w.place)=="table" and not getmetatable(w.place)
        and finite(w.itemId) and w.itemId%1==0 and textId(w.itemType) and textId(w.toolItemId) and textId(w.toolItemType)
        and w.toolCategory=="pipe-wrench" and tostring(w.itemId)~=w.toolItemId
        and finite(w.beforeAmount) and w.beforeAmount>=0 and finite(w.capacity) and w.capacity>w.beforeAmount
        and w.beforeUsesExternalWaterSource==false and w.beforePlumbingEligible==true
        and (w.beforeCanBeWaterPiped==nil or type(w.beforeCanBeWaterPiped)=="boolean")
        and textId(w.world) and (w.bodyToken==nil or textId(w.bodyToken)) and finite(w.startedAt) and w.startedAt>=0
end
plumbOutcome=function(id,row)
    local rec,t=SAO.Identity.get(id),now()
    if not craftLedger(rec) or not plumbIdentity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISPlumbItem" or not t or not finite(row.atHours)
        or row.atHours<row.startedAt or row.atHours>t or row.endedAt~=row.atHours
        or row.status~="completed" and row.status~="failed" and row.status~="interrupted"
        or type(row.nativeAttempted)~="boolean" or type(row.nativeCompleted)~="boolean"
        or type(row.toolRetained)~="boolean" or type(row.connected)~="boolean" then return nil end
    if row.nativeObservability=="runtime-unavailable" then
        if row.status~="interrupted" or row.nativeAttempted or row.nativeCompleted or row.toolRetained or row.connected
            or row.afterUsesExternalWaterSource~=nil or row.afterCanBeWaterPiped~=nil or row.nativeCredit~=nil then return nil end
    elseif row.nativeObservability=="fixture-unbound" then
        if row.status~="interrupted" or row.nativeAttempted or row.nativeCompleted or row.connected
            or row.beforeCanBeWaterPiped~=nil or row.afterUsesExternalWaterSource~=nil
            or row.afterCanBeWaterPiped~=nil or row.nativeCredit~=nil then return nil end
    elseif row.nativeObservability~=nil or type(row.beforeCanBeWaterPiped)~="boolean" or type(row.afterUsesExternalWaterSource)~="boolean"
        or type(row.afterCanBeWaterPiped)~="boolean" or row.connected~=(row.nativeCompleted
            and row.afterUsesExternalWaterSource and not row.afterCanBeWaterPiped) then return nil end
    local completed=row.status=="completed"
    if completed and (not row.nativeAttempted or not row.nativeCompleted or not row.connected or not row.toolRetained)
        or completed and row.nativeCredit~=row.id or not completed and row.nativeCredit~=nil then return nil end
    local out={}
    for k,v in pairs(row) do
        if not PLUMB_FIELDS[k] then return nil end
        local copied=plumbCopy(v,0)
        if copied==nil then return nil end
        out[k]=copied
    end
    return out
end
local function plumbInstall()
    if not ItemTag or not ItemTag.PIPE_WRENCH or isClient() or isServer() then return false end
    local a=pcall(require,"TimedActions/ISPlumbItem")
    local b=pcall(require,"TimedActions/ISEquipWeaponAction")
    local c=pcall(require,"TimedActions/ISInventoryTransferAction")
    return a and b and c and ISPlumbItem and ISEquipWeaponAction and ISInventoryTransferAction
end
local function plumbTool(item)
    return item and not item:isBroken() and item:getCondition()>0 and not item:getIsCraftingConsumed()
        and (item:getType()=="PipeWrench" or item:hasTag(ItemTag.PIPE_WRENCH))
end
plumbOptions=function(id,body,vessels,options)
    if not plumbInstall() then return end
    local tool,items=nil,SAOJavaBridge:privateCarriedItems(body)
    if items:size()<=512 then
        for i=0,items:size()-1 do if plumbTool(items:get(i)) then tool=items:get(i);break end end
    end
    local checked=0
    for placeId,belief in pairs(SAO.Perception.knownPlaces(id,true) or {}) do
        for sourceId,fact in pairs(belief.sourceFacts or {}) do
            checked=checked+1;if checked>128 then return end
            if fact.kind=="fluid" and fact.plumbing=="unconnected" and admitted(belief,sourceId,fact.revision)
                and tonumber(fact.x) and tonumber(fact.y) and tonumber(fact.z)
                and SAO.Standing.mayAttemptBelieved(id,fact.x,fact.y,"standing")==true then
                local dx,dy=fact.x+.5-body:getX(),fact.y+.5-body:getY()
                if dx*dx+dy*dy<=KNOWN_FIXTURE_SEARCH_RADIUS*KNOWN_FIXTURE_SEARCH_RADIUS then
                    for _,held in ipairs(vessels) do
                        options[#options+1]={kind="plumb-fixture",owner="SAO.ResourceProduction",category="water",token="resource:plumbed",
                            known=true,sourceId=sourceId,sourceRevision=fact.revision,fingerprint=fact.fingerprint,
                            sourceX=fact.x,sourceY=fact.y,sourceZ=fact.z,toolCategory="pipe-wrench",
                            toolItemId=tool and tostring(tool:getID()) or nil,toolItemType=tool and tool:getFullType() or nil,
                            place={id=placeId,sourceId=belief.sourceId,cx=belief.cx,cy=belief.cy,z=belief.z,
                                minX=belief.minX,maxX=belief.maxX,minY=belief.minY,maxY=belief.maxY},
                            itemId=held.itemId,itemType=held.itemType,beforeAmount=held.beforeAmount,capacity=held.capacity,
                            quantityUnit="fluid",distance=math.sqrt(dx*dx+dy*dy)}
                        if #options>=16 then return end
                    end
                end
            end
        end
    end
end
local function plumbPurpose(rec,w)
    if w and nativeEntityKind(w.kind) then return collector.purpose(rec,w) end
    local state=rec and rec.proceduralPlanning
    local p=state and state.purposes and state.purposes[w.purposeId]
    local s=p and p.steps and p.steps[p.cursor]
    local a=p and p.admission
    if not p or p.status=="completed" or p.status=="abandoned" or p.resourceCategory~="water" or not s or not a
        or s.id~=w.purposeStepId or s.owner~="SAO.ResourceProduction" or s.productionKind~=w.kind or s.token~=w.token
        or a.owner~=s.owner or a.stepId~=s.id or a.correlationId~=w.id or a.target~=s.target
        or not finite(a.at) or a.at<w.startedAt
        or s.sourceId~=w.sourceId or s.sourceRevision~=w.sourceRevision or s.fingerprint~=w.fingerprint
        or s.sourceX~=w.sourceX or s.sourceY~=w.sourceY or s.sourceZ~=w.sourceZ
        or s.itemId~=w.itemId or s.itemType~=w.itemType or s.toolCategory~="pipe-wrench"
        or tostring(s.toolItemId)~=w.toolItemId or s.toolItemType~=w.toolItemType then return nil end
    return p,s
end
local function plumbBound(rt,pre)
    if nativeEntityKind(rt.kind) then return collector.bound(rt,pre) end
    if not rt.body or rt.closed then return false end
    local rec,w,body=owner(rt.id,rt.body),rt.work,rt.body
    local p,s=plumbPurpose(rec,w)
    local world=getWorld()
    local fluid,amount=vessel(body,rt.item)
    return rec==rt.record and runtime[rt.id]==rt and rec.resourceProductionWork==w and not rt.cancelling
        and plumbIdentity(rt.id,w) and craftLedger(rec) and w.id==rt.workId and w.startedAt==rt.startedAt
        and w.bodyToken==rt.token and w.world==rt.world and w.sourceId==rt.sourceId and w.sourceRevision==rt.sourceRevision
        and w.fingerprint==rt.fingerprint and w.itemId==rt.itemId and w.itemType==rt.itemType
        and w.toolItemId==rt.toolId and w.toolItemType==rt.toolType and w.sourceX==rt.sx and w.sourceY==rt.sy and w.sourceZ==rt.sz
        and w.beforeAmount==rt.beforeAmount and w.capacity==rt.capacity and w.beforeCanBeWaterPiped==rt.beforeCanBeWaterPiped
        and p==rt.purpose and s==rt.step and now() and now()>=rt.startedAt and world and world:getWorld()==rt.world
        and world:getCell()==rt.cell and body:getCell()==rt.cell and body:getInventory()==rt.inventory
        and ISTimedActionQueue.getTimedActionQueue(body)==rt.queue and body:getModData().SAOExternalToken==rt.token
        and carried(body,w.itemId,w.itemType)==rt.item and fluid and amount==w.beforeAmount and fluid:getCapacity()==w.capacity
        and craftCarried(body,w.toolItemId,w.toolItemType)==rt.tool and ownItem(rt,rt.tool) and plumbTool(rt.tool)
        and (not rt.square or body:getCurrentSquare()==rt.square and math.abs(body:getX()-rt.x)<.01 and math.abs(body:getY()-rt.y)<.01)
        and permission(rt.id,w) and (not rt.fixture or SAOJavaBridge:worldPlumbValid(body,rt.fixture,w.sourceId,w.fingerprint,
            w.sourceX,w.sourceY,w.sourceZ,rt.nativeCompleted==true)==true)
        and (not pre or not rt.nativeAttempted and (not rt.fixture or rt.fixture:getUsesExternalWaterSource()==false
            and (rt.fixture:getModData().canBeWaterPiped==true)==rt.beforeCanBeWaterPiped))
end
local function plumbCapsule(a) return a and type(a._SAOPlumbBinding)=="function" and a._SAOPlumbBinding(PLUMB_SEAL) or nil end
local function plumbCurrent(c)
    local rt=c.rt
    return plumbCapsule(c.action)==c and runtime[rt.id]==rt and rt.current==c and c.action.character==rt.body
        and ISTimedActionQueue.queues[rt.body]==rt.queue and rt.queue.current==c.action and rt.queue.queue[1]==c.action
        and rt.queue:indexOf(c.action)==1
end
local function plumbRetired(rt)
    if rt.route and not rt.route.done then return false end
    for _,c in ipairs(rt.actions) do
        if rt.queue:indexOf(c.action)~=-1 or rt.queue.current==c.action or c.action.action and not c.ack then return false end
    end
    return true
end
local function plumbDispose(rt)
    if rt.passageToken and rt.body then pcall(function() SAOJavaBridge:worldShelterForgetPassage(rt.body,rt.passageToken) end);rt.passageToken=nil end
    for _,c in ipairs(rt.actions) do c.action._SAOPlumbBinding=function() return nil end;c.action._SAOPlumbRetireSaved=nil end
    if runtime[rt.id]==rt then runtime[rt.id]=nil end
    rt.body,rt.fixture,rt.tool,rt.item,rt.record,rt.purpose,rt.step,rt.current,rt.route=nil,nil,nil,nil,nil,nil,nil,nil,nil
    if nativeEntityKind(rt.kind) then
        if rt.builder then rt.builder.character,rt.builder.buildPanelLogic,rt.builder.saoCreated=nil,nil,nil end
        rt.builder,rt.logic,rt.materials,rt.siteSquare,rt.square,rt.cell,rt.inventory=nil,nil,nil,nil,nil,nil,nil
    end
end
local function plumbRefuse(rt,reason)
    rt.cancelling,rt.cancelReason=true,rt.cancelReason or reason
    if rt.record and rt.record.resourceProductionWork==rt.work then rt.work.status="interrupted" end
    return false
end
local function plumbClose(rt,status,detail)
    if nativeEntityKind(rt.kind) then return collector.close(rt,status,detail) end
    if rt.closed then return true end
    local rec,w,t=SAO.Identity.get(rt.id),rt.work,now()
    if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not plumbIdentity(rt.id,w)
        or not plumbPurpose(rec,w) or not craftLedger(rec) or not t or t<w.startedAt then return false end
    local rows=rec.resourceProductionOutcomes or {}
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row={}
    for k in pairs(PLUMB_FIELDS) do if w[k]~=nil then row[k]=plumbCopy(w[k],0) end end
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISPlumbItem",status,detail,t,t
    row.nativeAttempted,row.nativeCompleted=rt.nativeAttempted==true,rt.nativeCompleted==true
    row.toolRetained=rt.tool and craftCarried(rt.body,w.toolItemId,w.toolItemType)==rt.tool and ownItem(rt,rt.tool) or false
    row.afterUsesExternalWaterSource=rt.fixture and rt.fixture:getUsesExternalWaterSource()==true or false
    row.afterCanBeWaterPiped=rt.fixture and rt.fixture:getModData().canBeWaterPiped==true or false
    row.connected=row.nativeCompleted and row.afterUsesExternalWaterSource and not row.afterCanBeWaterPiped
    if not rt.fixture then
        row.nativeObservability="fixture-unbound"
        row.afterUsesExternalWaterSource,row.afterCanBeWaterPiped=nil,nil
    end
    if status=="completed" and (not row.nativeAttempted or not row.connected or not row.toolRetained or not plumbBound(rt,false)) then
        row.status,row.detail="failed","native-plumbing-transition-unconfirmed"
    end
    row.nativeCredit=row.status=="completed" and w.id or nil
    row.sourceObservation={status="unconfirmed",detail="no-bound-native-connection",attempts=0}
    if not plumbOutcome(rt.id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    if row.status=="completed" then
        sourceRefresh[rt.id]={receipt=row,rt={body=rt.body,fixture=rt.fixture}}
        refreshHandledSource(rt.id)
    end
    rec.resourceProductionWork=nil;rt.closed=true;plumbDispose(rt);reconcile(rt.id);return true
end
local plumbEnqueue
local function plumbGuard(rt,a,kind,item)
    local c={rt=rt,action=a,kind=kind,item=item,source=kind=="transfer" and item:getContainer() or nil}
    a._SAOPlumbBinding=function(seal) if seal==PLUMB_SEAL then return c end end
    a.actorId,a.workId,a.bodyToken=rt.id,rt.workId,rt.token
    local valid,perform,complete,start=a.isValid,a.perform,a.complete,a.start
    local function exact()
        return plumbCapsule(a)==c and a.character==rt.body and a.actorId==rt.id and a.workId==rt.workId and a.bodyToken==rt.token
            and (kind=="collector" and collector.exact(rt,a)
                or kind=="shelter-door" and shelter.doorExact(rt,a)
                or kind=="plumb" and a.itemToPipe==rt.fixture and a.wrench==rt.tool
                or kind=="equip" and a.item==item and a.primary==true
                or kind=="transfer" and a.item==item and a.srcContainer==c.source and a.destContainer==rt.inventory)
    end
    function a:isValidStart() return not c.done and exact() and plumbBound(rt,true) and valid(self)==true and exact() or false end
    function a:isValid() return not c.done and exact() and plumbBound(rt,true) and valid(self)==true and exact() or false end
    function a:start()
        if not plumbCurrent(c) or not self:isValid() then return plumbRefuse(rt,"plumbing-start-owner-changed") end
        return start(self)
    end
    function a:perform()
        if c.performed or c.done or not plumbCurrent(c) or not craftNativeEnded(self) or not self:isValid() then
            return plumbRefuse(rt,"plumbing-perform-owner-changed")
        end
        if kind=="transfer" then
            local ql=self.queueList
            if type(ql)~="table" or #ql~=1 or #ql[1].items~=1 or ql[1].items[1]~=item then return plumbRefuse(rt,"plumbing-transfer-selection-changed") end
        end
        c.performed=true
        if kind=="collector" then c.performing=true end
        local ok,result=pcall(perform,self)
        c.performing=false
        if not ok then return plumbRefuse(rt,"native-plumbing-perform-failed") end
        if kind=="collector" then
            c.done,c.ack=true,true
            rt.nativeCompleted=collector.measure(rt)
            return plumbClose(rt,rt.nativeCompleted and "completed" or "failed","native-collector-build-ended")
        end
        if kind=="transfer" then
            c.done,c.ack=true,true
            if not exact() or not plumbBound(rt,true) or item:getContainer()~=rt.inventory or c.source:contains(item)
                or rt.queue:indexOf(self)~=-1 or rt.queue.current==self then return plumbRefuse(rt,"plumbing-transfer-unconfirmed") end
            return plumbEnqueue(rt,c.position+1)
        end
        return result
    end
    function a:complete()
        if kind=="collector" then return false end
        if kind=="transfer" then return false end
        if c.done or not c.performed or not exact() or not plumbBound(rt,true) or valid(self)~=true or not exact()
            or rt.queue:indexOf(self)~=-1 or rt.queue.current or #rt.queue.queue>0 then return plumbRefuse(rt,"plumbing-complete-owner-changed") end
        c.done,c.ack=true,true
        if kind=="plumb" then rt.nativeAttempted=true end
        local ok,result=pcall(complete,self)
        if kind=="shelter-door" then return shelter.doorFinished(rt,self,ok and result==true) end
        if kind=="equip" then
            if not ok or result~=true or rt.body:getPrimaryHandItem()~=item or not plumbBound(rt,true) then return plumbRefuse(rt,"plumbing-equipment-unconfirmed") end
            return plumbEnqueue(rt,c.position+1)
        end
        rt.nativeCompleted=ok and result==true
        return plumbClose(rt,rt.nativeCompleted and "completed" or "failed","native-plumbing-ended")
    end
    function a:stop()
        if c.ack or plumbCapsule(self)~=c then return false end
        local current=plumbCurrent(c)
        plumbRefuse(rt,"native-plumbing-stopped")
        if current and plumbCurrent(c) then
            if kind=="transfer" then
                pcall(function() self:playSourceContainerCloseSound() end);pcall(function() self:playDestContainerCloseSound() end)
                pcall(function() self:stopLoopingSound() end);pcall(function() item:setJobDelta(0) end)
                pcall(function() if self.action then self.action:setLoopedAction(false) end end)
                pcall(function() removeItemTransaction(self.transactionId,true) end);self.started=false
            elseif kind=="equip" then
                pcall(function() if self.sound then rt.body:getEmitter():stopSound(self.sound);self.sound=nil end end)
                pcall(function() item:setJobDelta(0) end);pcall(function() self:restoreWeaponType() end)
            elseif kind=="collector" then collector.cleanup(rt,self)
            else pcall(function() rt.body:stopOrTriggerSound(self.sound) end) end
            rt.body:setIsFarming(false);c.ack=true;rt.queue:onCompleted(self)
        else
            c.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end
        end
        plumbClose(rt,"interrupted",rt.cancelReason);return true
    end
    function a:forceCancel()
        if c.ack or plumbCapsule(self)~=c then return false end
        plumbRefuse(rt,"native-plumbing-force-cancel")
        if not self.action then c.ack=true;rt.queue:removeFromQueue(self);if rt.queue.current==self then rt.queue.current=nil end end
        return false
    end
    a.canMergeAction=function() return false end
    a._SAOPlumbRetireSaved=function(rec,w)
        if plumbCapsule(a)~=c or SAO.Identity.get(rt.id)~=rec or rec.id~=rt.id
            or not plumbIdentity(rt.id,w) or not plumbPurpose(rec,w) or w.id~=rt.workId
            or w.purposeId~=rt.work.purposeId or w.purposeStepId~=rt.work.purposeStepId
            or w.bodyToken~=rt.token or w.world~=rt.world or w.startedAt~=rt.startedAt
            or w.sourceId~=rt.sourceId or w.sourceRevision~=rt.sourceRevision or w.fingerprint~=rt.fingerprint
            or w.sourceX~=rt.sx or w.sourceY~=rt.sy or w.sourceZ~=rt.sz
            or w.itemId~=rt.itemId or w.itemType~=rt.itemType or w.toolItemId~=rt.toolId or w.toolItemType~=rt.toolType
            or w.beforeAmount~=rt.beforeAmount or w.capacity~=rt.capacity or w.beforeCanBeWaterPiped~=rt.beforeCanBeWaterPiped then return false end
        if nativeEntityKind(rt.kind) and not collector.anchors(rt,w) then return false end
        local closed=plumbInterrupt(rt.id,rt.body,"plumbing-runtime-unavailable")
        if not closed and plumbRetired(rt) and rec.resourceProductionWork~=rt.work then plumbDispose(rt);return true end
        return closed
    end
    c.position=#rt.actions+1;rt.actions[c.position]=c;return c
end
plumbEnqueue=function(rt,index)
    local c=rt.actions[index]
    if not c or not plumbBound(rt,true) or rt.queue.current or #rt.queue.queue>0 then return plumbRefuse(rt,"plumbing-preparation-queue-changed") end
    rt.current,rt.action=c,c.action;rt.work.stage=c.kind=="collector" and "building" or c.kind=="plumb" and "plumbing" or "preparing"
    return SAO.Needs.queueVerified(c.action)==true or plumbRefuse(rt,"native-plumbing-queue-refused")
end
local function plumbQueue(rt)
    local w=rt.work
    local fixture=SAOJavaBridge:worldPlumbObject(rt.body,w.sourceId,w.fingerprint,w.sourceRevision,w.sourceX,w.sourceY,w.sourceZ)
    if not fixture then return false end
    rt.fixture,rt.square,rt.x,rt.y=fixture,rt.body:getCurrentSquare(),rt.body:getX(),rt.body:getY()
    rt.beforeCanBeWaterPiped=fixture:getModData().canBeWaterPiped==true
    w.beforeCanBeWaterPiped=rt.beforeCanBeWaterPiped
    if not plumbBound(rt,true) then return false end
    if rt.tool:getContainer()~=rt.inventory then
        plumbGuard(rt,ISInventoryTransferAction:new(rt.body,rt.tool,rt.tool:getContainer(),rt.inventory),"transfer",rt.tool)
    end
    if rt.body:getPrimaryHandItem()~=rt.tool then plumbGuard(rt,ISEquipWeaponAction:new(rt.body,rt.tool,50,true,false),"equip",rt.tool) end
    plumbGuard(rt,ISPlumbItem:new(rt.body,fixture,rt.tool),"plumb",rt.tool)
    return plumbEnqueue(rt,1)
end
plumbBegin=function(id,body,step,context)
    local rec,t=owner(id,body),now()
    if not rec or not t or not plumbInstall() or not craftLedger(rec) or rec.resourceProductionWork or rec.worldSourceReservation
        or rec.cookingWork or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) then return false end
    local option={kind="plumb-fixture",category="water",sourceId=step.sourceId,sourceRevision=step.sourceRevision,
        fingerprint=step.fingerprint,sourceX=step.sourceX,sourceY=step.sourceY,sourceZ=step.sourceZ,place=step.place}
    if not R.privatelyKnown(id,option) then return false end
    local item,tool=carried(body,step.itemId,step.itemType),craftCarried(body,tostring(step.toolItemId),step.toolItemType)
    local fluid,amount=vessel(body,item)
    if not fluid or not plumbTool(tool) then return false end
    local place,cx,cy=rememberedPlace(id,option)
    local target=SAOJavaBridge:worldPlumbTarget(body,step.sourceId,step.fingerprint,step.sourceRevision,step.sourceX,step.sourceY,step.sourceZ)
    local x,y,z=tostring(target):match("^READY:(%-?%d+):(%-?%d+):(%-?%d+)$")
    local route=SAO.Locomotion.jobs[id]
    if not x or route and not route.done then return false end
    local seq=(rec.resourceProductionSequence or 0)+1
    local world=getWorld()
    if not world then return false end
    local admittedNeeds=SAO.Needs.read(body) or {}
    local readHealth,admittedHealth=pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    local w={id="resource-production/"..tostring(id).."/"..seq,sequence=seq,actorId=id,kind="plumb-fixture",category="water",token="resource:plumbed",
        sourceId=step.sourceId,sourceRevision=step.sourceRevision,fingerprint=step.fingerprint,sourceX=step.sourceX,sourceY=step.sourceY,sourceZ=step.sourceZ,
        sourceChunkX=cx,sourceChunkY=cy,place=place,itemId=item:getID(),itemType=item:getFullType(),beforeAmount=amount,capacity=fluid:getCapacity(),
        toolCategory="pipe-wrench",toolItemId=tostring(tool:getID()),toolItemType=tool:getFullType(),
        purposeId=context.purposeId,purposeStepId=context.purposeStepId,requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,
        world=world:getWorld(),bodyToken=rec.bodyOwnerToken,startedAt=t,status="plumbing",stage="approaching",
        beforeUsesExternalWaterSource=false,beforePlumbingEligible=true,
        admittedNeeds={hunger=tonumber(admittedNeeds.hunger),thirst=tonumber(admittedNeeds.thirst),fatigue=tonumber(admittedNeeds.fatigue)},
        admittedHealth=readHealth and tonumber(admittedHealth) or nil}
    if not plumbIdentity(id,w) then return false end
    local rt={id=id,kind=w.kind,record=rec,body=body,work=w,workId=w.id,startedAt=t,token=w.bodyToken,world=w.world,cell=body:getCell(),
        inventory=body:getInventory(),queue=ISTimedActionQueue.getTimedActionQueue(body),item=item,tool=tool,actions={},
        sourceId=w.sourceId,sourceRevision=w.sourceRevision,fingerprint=w.fingerprint,itemId=w.itemId,itemType=w.itemType,
        toolId=w.toolItemId,toolType=w.toolItemType,sx=w.sourceX,sy=w.sourceY,sz=w.sourceZ,beforeAmount=amount,capacity=fluid:getCapacity()}
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,w,rt
    if not SAO.ProceduralPlanning or SAO.ProceduralPlanning.admitProduction(id,w)~=true then rec.resourceProductionWork=nil;plumbDispose(rt);return false end
    rt.purpose,rt.step=plumbPurpose(rec,w)
    if not plumbBound(rt,true) then plumbInterrupt(id,body,"plumbing-admission-refused");return false end
    if SAOJavaBridge:worldPlumbObject(body,w.sourceId,w.fingerprint,w.sourceRevision,w.sourceX,w.sourceY,w.sourceZ) then
        if plumbQueue(rt) then return true end
    elseif SAO.Standing.mayAttemptBelieved(id,tonumber(x),tonumber(y),"standing")==true and SAO.Locomotion.order(id,body,tonumber(x),tonumber(y),tonumber(z)) then
        rt.route=SAO.Locomotion.jobs[id];if rt.route and rt.route.body==body then return true end
    end
    plumbInterrupt(id,body,"native-plumbing-approach-refused");return false
end
plumbRecover=function(id,body)
    reconcile(id)
    local rec=SAO.Identity.get(id);local w=rec and rec.resourceProductionWork
    if not w then return true end
    if runtime[id] then return plumbInterrupt(id,body,"plumbing-owner-reconciled") end
    local t=now();local world=getWorld()
    if not craftLedger(rec) or not plumbIdentity(id,w) or w.sequence>rec.resourceProductionSequence or not plumbPurpose(rec,w)
        or w.status~="plumbing" and w.status~="interrupted" or not t or t<w.startedAt or not world or world:getWorld()~=w.world
        or not body or tostring(body:getModData().SAOPersonId or "")~=tostring(id) or body:getModData().SAOExternalToken~=w.bodyToken then return false end
    for _,q in pairs(ISTimedActionQueue.queues) do
        local pending={};for _,a in ipairs(q.queue) do pending[#pending+1]=a end
        if q.current and q:indexOf(q.current)==-1 then pending[#pending+1]=q.current end
        for _,a in ipairs(pending) do
            if a.actorId==id and a.workId==w.id and a.bodyToken==w.bodyToken then
                if type(a._SAOPlumbRetireSaved)~="function" then return false end
                local ok,closed=pcall(a._SAOPlumbRetireSaved,rec,w);if not ok or not closed then return false end
            end
        end
    end
    if not rec.resourceProductionWork then return true end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if SAOJavaBridge:hasPendingActions(body) or q.current or #q.queue>0 then return false end
    local rows=rec.resourceProductionOutcomes or {}
    for _,row in ipairs(rows) do if row.id==w.id then return false end end
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row={};for k in pairs(PLUMB_FIELDS) do if w[k]~=nil then row[k]=plumbCopy(w[k],0) end end
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISPlumbItem","interrupted","plumbing-runtime-unavailable",t,t
    row.nativeObservability="runtime-unavailable";row.nativeAttempted,row.nativeCompleted,row.toolRetained,row.connected=false,false,false,false
    if not plumbOutcome(id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rec.resourceProductionWork=nil;reconcile(id);return true
end
plumbInterrupt=function(id,body,reason)
    local rt=runtime[id]
    if not rt then return plumbRecover(id,body) end
    if rt.kind~="plumb-fixture" and not nativeEntityKind(rt.kind) or body and rt.body~=body then return false end
    if rt.nativeCompleted and not rt.cancelling and plumbRetired(rt) then return plumbClose(rt,"completed","native-plumbing-completed-before-interruption") end
    plumbRefuse(rt,reason or "higher-priority-work")
    if rt.route and not rt.route.done then
        local ok,cancelled=pcall(function() return SAOJavaBridge:cancelMove(rt.body) end)
        if not ok or cancelled~="MOVE_CANCELLED" then return false end
        rt.route.done=true
    end
    for _,c in ipairs(rt.actions) do
        if not c.ack then if c.action.action then pcall(function() c.action:forceStop() end) else c.action:forceCancel() end end
    end
    return rt.closed==true or plumbClose(rt,"interrupted",rt.cancelReason)
end
plumbTick=function(id,body)
    local rt=runtime[id]
    if not rt then return plumbRecover(id,body) and "interrupted" or "cancelling" end
    if rt.cancelling or rt.body~=body or not plumbBound(rt,not rt.nativeAttempted) or not now() or now()-rt.startedAt>.5 then
        return plumbInterrupt(id,rt.body,rt.cancelReason or "plumbing-owner-changed") and "interrupted" or "cancelling"
    end
    if rt.work.stage=="approaching" then
        if SAO.Locomotion.jobs[id]~=rt.route then return plumbInterrupt(id,body,"plumbing-route-owner-lost") and "interrupted" or "cancelling" end
        SAO.Locomotion.tick(id)
        if not rt.route.done then return "moving" end
        if rt.route.result=="arrived" and plumbQueue(rt) then return rt.work.stage end
        return plumbInterrupt(id,body,"native-plumbing-approach-refused") and "interrupted" or "cancelling"
    end
    if queued(rt.action) then return rt.work.stage end
    return plumbInterrupt(id,body,"native-plumbing-acknowledgement-missing") and "interrupted" or "cancelling"
end
-- Finite native entity construction shares the water owner's exact preparation
-- and cancellation custody; recipe payment and placement remain engine effects.
collector={entities={"Base.RainCollector","Base.RainCollectorRound","Base.RainCollector_Tarp","Base.RainCollectorRound_Tarp"}}
function collector.copy(v,depth)
    if type(v)~="table" then return plumbCopy(v,0) end
    if getmetatable(v) or (depth or 0)>5 then return nil end
    local out,n={},0
    for k,x in pairs(v) do
        n=n+1;if n>((depth or 0)==0 and 96 or 32) or type(k)~="string" and not integer(k) then return nil end
        local y=collector.copy(x,(depth or 0)+1);if y==nil then return nil end;out[k]=y
    end
    return out
end
function collector.install()
    if isClient() or isServer() or not ItemTag or not ItemTag.HAMMER then return false end
    local ok=pcall(function()
        require "BuildingObjects/ISBuildingObject"
        require "BuildingObjects/ISBuildIsoEntity"
        require "BuildingObjects/TimedActions/ISBuildAction"
        require "TimedActions/ISInventoryTransferAction"
        require "TimedActions/ISEquipWeaponAction"
    end)
    return ok and BuildLogic and SpriteConfigManager and ISBuildIsoEntity and ISBuildAction and CraftRecipeManager and ArrayList
end
function collector.recipe(entityId,body)
    if entityId=="Base.Wood_Bed" then return bed.recipe(body) end
    local allowed=false;for _,id in ipairs(collector.entities) do if id==entityId then allowed=true end end
    if not allowed or not collector.install() then return nil end
    local infos=SpriteConfigManager.GetObjectInfoList()
    for i=0,infos:size()-1 do
        local info=infos:get(i);local script=info:getScript()
        if script and script:getParent():getScriptObjectFullType()==entityId and info:getRecipe() then
            local recipe=info:getRecipe():getCraftRecipe()
            if not recipe or not CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body) then return nil end
            for j=0,recipe:getRequiredSkillCount()-1 do
                if not CraftRecipeManager.hasPlayerRequiredSkill(recipe:getRequiredSkill(j),body) then return nil end
            end
            local requirements={}
            if recipe:getInputs():size()~=4 then return nil end
            for j=0,3 do
                local input=recipe:getInputs():get(j)
                local category=j==0 and "hammer" or j==1 and "plank" or j==2 and "nails"
                    or entityId:find("_Tarp",1,true) and "tarp" or "garbage-bag"
                if input:getResourceType()~=ResourceType.Item or input:getIntAmount()<1 or input:getIntAmount()>16
                    or input:isKeep()~=(j==0) then return nil end
                requirements[#requirements+1]={inputIndex=j,mode=input:isKeep() and "keep" or "consume",
                    count=input:getIntAmount(),category=category}
            end
            local fluid=script:getParent():getComponentScriptFor(ComponentType.FluidContainer)
            local face=info:getFace("S")
            if not fluid or not face or face:getWidth()~=1 or face:getHeight()~=1 or face:getzLayers()~=1 then return nil end
            return {info=info,recipe=recipe,recipeId=recipe:getScriptObjectFullType(),requirements=requirements,capacity=fluid:getCapacity()}
        end
    end
end
function collector.inputs(policy,body)
    local rows,items,seen={},SAOJavaBridge:privateCarriedItems(body),{}
    if items:size()>512 then return rows end
    for _,requirement in ipairs(policy.requirements) do
        local input=policy.recipe:getInputs():get(requirement.inputIndex);local count=0
        for i=0,items:size()-1 do
            local item=items:get(i);local id=tostring(item:getID())
            if not seen[id] and not item:getIsCraftingConsumed() and ISBuildIsoEntity.predicateMaterial(item)
                and ownItem({inventory=body:getInventory()},item)
                and CraftRecipeManager.getValidInputScriptForItem(policy.recipe,item,body)==input
                and (requirement.mode~="keep" or item:hasTag(ItemTag.HAMMER) and not item:isBroken() and item:getCondition()>0
                    and (not policy.shelterEdge or not item:isRequiresEquippedBothHands())) then
                rows[#rows+1]={inputIndex=requirement.inputIndex,itemId=id,itemType=item:getFullType(),mode=requirement.mode}
                seen[id],count=true,count+1;if count==requirement.count then break end
            end
        end
    end
    return rows
end
function collector.rowsEqual(a,b)
    if type(a)~="table" or type(b)~="table" or getmetatable(a) or getmetatable(b) or #a~=#b then return false end
    for i,v in ipairs(a) do for _,k in ipairs({"inputIndex","itemId","itemType","mode","count","category"}) do
        if v[k]~=b[i][k] then return false end
    end end
    return true
end
function collector.site(id,body,site,sourceX,sourceY,sourceZ)
    if type(site)~="table" or not textId(site.key) or not textId(site.revision) or not finite(site.observedAtHours)
        or not now() or site.observedAtHours>now() or site.observedAtHours<0 or not finite(site.x) or site.x%1~=0
        or not finite(site.y) or site.y%1~=0 or not finite(site.z) or site.z%1~=0
        or math.abs(site.x-sourceX)>1 or math.abs(site.y-sourceY)>1 or site.z~=sourceZ+1 then return false end
    for _,known in ipairs(SAO.Perception.collectorSites(id,body) or {}) do
        if known.key==site.key and known.revision==site.revision and known.x==site.x and known.y==site.y
            and known.z==site.z and known.observedAtHours>=site.observedAtHours and known.observedAtHours<=now() then return true end
    end
    return false
end
function collector.options(id,body,vessels,options)
    if not collector.install() or not SAO.Perception.collectorSites then return end
    local limit=math.min(16,#options+4)
    local policies={}
    for _,entityId in ipairs(collector.entities) do local p=collector.recipe(entityId,body);if p then
        p.inputs=collector.inputs(p,body);policies[#policies+1]=p
    end end
    local checked=0
    for placeId,belief in pairs(SAO.Perception.knownPlaces(id,true) or {}) do
        for sourceId,fact in pairs(belief.sourceFacts or {}) do
            checked=checked+1;if checked>128 then return end
            if fact.kind=="fluid" and fact.plumbing=="unconnected" and admitted(belief,sourceId,fact.revision)
                and (tonumber(fact.quantities and fact.quantities.water) or 0)<=0
                and finite(fact.x) and finite(fact.y) and finite(fact.z)
                and SAO.Standing.mayAttemptBelieved(id,fact.x,fact.y,"standing")==true then
                for _,site in ipairs(SAO.Perception.collectorSites(id,body) or {}) do
                    if collector.site(id,body,site,fact.x,fact.y,fact.z)
                        and SAO.Standing.mayAttemptBelieved(id,site.x,site.y,"standing")==true then
                        for _,held in ipairs(vessels) do for _,p in ipairs(policies) do
                            options[#options+1]={kind="build-rain-collector",owner="SAO.ResourceProduction",category="water",
                                token="resource:collector-built",known=true,sourceId=sourceId,sourceRevision=fact.revision,
                                fingerprint=fact.fingerprint,sourceX=fact.x,sourceY=fact.y,sourceZ=fact.z,
                                place={id=placeId,sourceId=belief.sourceId,cx=belief.cx,cy=belief.cy,z=belief.z,
                                    minX=belief.minX,maxX=belief.maxX,minY=belief.minY,maxY=belief.maxY},
                                itemId=held.itemId,itemType=held.itemType,beforeAmount=held.beforeAmount,capacity=held.capacity,
                                entityId=p.info:getScript():getParent():getScriptObjectFullType(),recipeId=p.recipeId,
                                requirements=collector.copy(p.requirements),inputs=collector.copy(p.inputs),site=collector.copy(site),
                                distance=math.sqrt((site.x+.5-body:getX())^2+(site.y+.5-body:getY())^2)}
                            if #options>=limit then return end
                        end end
                    end
                end
            end
        end
    end
end
function collector.identity(id,w)
    if w and w.kind=="use-shelter" then return shelter.useIdentity(id,w) end
    if w and w.kind=="build-shelter-edge" then return shelter.identity(id,w) end
    if w and w.kind=="build-wood-bed" then return bed.identity(id,w) end
    if type(w)~="table" or getmetatable(w) or w.kind~="build-rain-collector" or w.category~="water"
        or w.token~="resource:collector-built" or w.actorId~=id or not integer(w.sequence) or w.sequence<1
        or w.id~="resource-production/"..tostring(id).."/"..w.sequence or not textId(w.purposeId) or not textId(w.purposeStepId)
        or not textId(w.entityId) or not textId(w.recipeId) or not textId(w.sourceId) or w.sourceId:sub(1,2)~="F:"
        or not textId(w.sourceRevision) or not textId(w.fingerprint) or type(w.place)~="table"
        or not textId(w.world) or w.bodyToken~=nil and not textId(w.bodyToken)
        or not finite(w.startedAt) or w.startedAt<0 or not finite(w.itemId) or w.itemId%1~=0 or not textId(w.itemType)
        or not textId(w.toolItemId) or not textId(w.toolItemType) or w.toolCategory~="hammer"
        or not finite(w.beforeAmount) or w.beforeAmount<0 or not finite(w.capacity) or w.capacity<=w.beforeAmount
        or not textId(w.siteKey) or not textId(w.siteRevision) or not finite(w.siteObservedAtHours)
        or type(w.inputs)~="table" or getmetatable(w.inputs) or #w.inputs<1 or #w.inputs>16
        or type(w.requirements)~="table" or #w.requirements~=4 or not finite(w.collectorCapacity) or w.collectorCapacity<=0 then return false end
    for _,k in ipairs({"sourceX","sourceY","sourceZ","siteX","siteY","siteZ","sourceChunkX","sourceChunkY"}) do
        if not finite(w[k]) or w[k]%1~=0 then return false end
    end
    local counts,seen={},{}
    for _,row in ipairs(w.inputs) do
        if type(row)~="table" or not integer(row.inputIndex) or row.inputIndex>3 or not textId(row.itemId)
            or not textId(row.itemType) or row.mode~="keep" and row.mode~="consume" or seen[row.itemId] then return false end
        seen[row.itemId]=true;counts[row.inputIndex]=(counts[row.inputIndex] or 0)+1
    end
    for i,r in ipairs(w.requirements) do
        if r.inputIndex~=i-1 or not integer(r.count) or r.count<1 or counts[r.inputIndex]~=r.count
            or r.mode~=(i==1 and "keep" or "consume") or not textId(r.category) then return false end
    end
    return counts[0]==1 and w.inputs[1].itemId==w.toolItemId and w.inputs[1].itemType==w.toolItemType
end
function collector.purpose(rec,w)
    if w and w.kind=="use-shelter" then return shelter.usePurpose(rec,w) end
    if w and w.kind=="build-shelter-edge" then return shelter.purpose(rec,w) end
    if w and w.kind=="build-wood-bed" then return bed.purpose(rec,w) end
    local state=rec and rec.proceduralPlanning
    local p=state and state.purposes and state.purposes[w.purposeId];local s=p and p.steps[p.cursor];local a=p and p.admission
    if not p or not p.collector or p.status=="completed" or p.status=="abandoned" or not s or not a
        or p.resourceCategory~="water" or s.owner~="SAO.ResourceProduction" or s.productionKind~=w.kind or s.token~=w.token
        or s.id~=w.purposeStepId or a.owner~=s.owner or a.stepId~=s.id or a.target~=s.target or a.correlationId~=w.id
        or not finite(a.at) or a.at<w.startedAt or s.entityId~=w.entityId or s.recipeId~=w.recipeId
        or s.sourceId~=w.sourceId or s.sourceRevision~=w.sourceRevision or s.fingerprint~=w.fingerprint
        or s.sourceX~=w.sourceX or s.sourceY~=w.sourceY or s.sourceZ~=w.sourceZ
        or s.itemId~=w.itemId or s.itemType~=w.itemType or not s.site or s.site.key~=w.siteKey or s.site.revision~=w.siteRevision
        or s.site.x~=w.siteX or s.site.y~=w.siteY or s.site.z~=w.siteZ or s.site.observedAtHours~=w.siteObservedAtHours
        or not collector.rowsEqual(s.inputs,w.inputs) or not collector.rowsEqual(s.requirements,w.requirements) then return nil end
    return p,s
end
function collector.anchors(rt,w)
    if rt and rt.kind=="use-shelter" then return shelter.useAnchors(rt,w) end
    if rt and rt.kind=="build-shelter-edge" then return shelter.anchors(rt,w) end
    if rt.kind=="build-wood-bed" then return bed.anchors(rt,w) end
    return w.entityId==rt.policy.info:getScript():getParent():getScriptObjectFullType() and w.recipeId==rt.policy.recipeId
        and w.siteKey==rt.site.key and w.siteRevision==rt.site.revision and w.siteX==rt.site.x and w.siteY==rt.site.y
        and w.siteZ==rt.site.z and w.siteObservedAtHours==rt.site.observedAtHours and w.collectorCapacity==rt.policy.capacity
        and collector.rowsEqual(w.inputs,rt.inputs) and collector.rowsEqual(w.requirements,rt.policy.requirements)
end
function collector.bound(rt,pre)
    if rt and rt.kind=="use-shelter" then return shelter.useBound(rt) end
    if rt and rt.kind=="build-shelter-edge" then return shelter.bound(rt,pre) end
    if rt.kind=="build-wood-bed" then return bed.bound(rt,pre) end
    local body,w=rt.body,rt.work
    if not body or rt.closed or rt.cancelling or runtime[rt.id]~=rt then return false end
    local rec=owner(rt.id,body);local p,s=collector.purpose(rec,w)
    local fluid,amount=vessel(body,rt.item);local world=getWorld()
    if rec~=rt.record or rec.resourceProductionWork~=w or not collector.identity(rt.id,w) or not craftLedger(rec)
        or not collector.anchors(rt,w) or w.id~=rt.workId or w.startedAt~=rt.startedAt
        or w.sourceId~=rt.sourceId or w.sourceRevision~=rt.sourceRevision or w.fingerprint~=rt.fingerprint
        or w.sourceX~=rt.sx or w.sourceY~=rt.sy or w.sourceZ~=rt.sz or w.itemId~=rt.itemId or w.itemType~=rt.itemType
        or w.toolItemId~=rt.toolId or w.toolItemType~=rt.toolType or w.bodyToken~=rt.token or w.world~=rt.world
        or p~=rt.purpose or s~=rt.step or not now() or now()<rt.startedAt or not world or world:getWorld()~=rt.world
        or world:getCell()~=rt.cell or body:getCell()~=rt.cell or body:getInventory()~=rt.inventory
        or ISTimedActionQueue.getTimedActionQueue(body)~=rt.queue or body:getModData().SAOExternalToken~=rt.token
        or not fluid or carried(body,w.itemId,w.itemType)~=rt.item or amount~=rt.beforeAmount or fluid:getCapacity()~=rt.capacity
        or not permission(rt.id,w) or SAO.Standing.mayTakeCurrent(rt.id,w.siteX,w.siteY,"standing")~=true
        or not collector.site(rt.id,body,rt.site,w.sourceX,w.sourceY,w.sourceZ)
        or w.stage~="approaching" and (body:getCurrentSquare()~=rt.square or math.abs(body:getX()-rt.x)>.01 or math.abs(body:getY()-rt.y)>.01) then return false end
    if not pre then return true end
    if rt.nativeAttempted or body:isBuildCheat() or w.stage~="approaching"
        and SAOJavaBridge:worldCollectorPlacementSquare(body,w.siteX,w.siteY,w.siteZ,w.siteRevision)~=rt.siteSquare then return false end
    for i,row in ipairs(rt.inputs) do local item=rt.materials[i]
        if craftCarried(body,row.itemId,row.itemType)~=item or not ownItem(rt,item) or item:getIsCraftingConsumed()
            or not ISBuildIsoEntity.predicateMaterial(item)
            or CraftRecipeManager.getValidInputScriptForItem(rt.policy.recipe,item,body)~=rt.policy.recipe:getInputs():get(row.inputIndex)
            or row.mode=="keep" and (item:isBroken() or item:getCondition()<=0) then return false end
    end
    return true
end
function collector.exact(rt,a)
    return a.item==rt.builder and a.x==rt.site.x and a.y==rt.site.y and a.z==rt.site.z and a.spriteName==rt.sprite
        and rt.builder.character==rt.body and rt.builder.objectInfo==rt.policy.info and rt.builder.buildPanelLogic==rt.logic
        and rt.logic:getRecipe()==rt.policy.recipe and rt.builder.craftRecipe==rt.policy.recipe
        and rt.builder:isValid(rt.siteSquare)==true and (rt.kind~="build-shelter-edge" or rt.builder.previousStageObject==rt.previous) and collector.manualExact(rt)
end
function collector.manualExact(rt)
    if not rt.logic:isManualSelectInputs() or rt.logic:getRecipeDataInProgress():getRecipe()~=rt.policy.recipe then return false end
    for _,r in ipairs(rt.policy.requirements) do
        local input=rt.policy.recipe:getInputs():get(r.inputIndex)
        for _,data in ipairs({rt.logic:getRecipeData(),rt.logic:getRecipeDataInProgress()}) do
            local actual=data:getManualInputsFor(input,ArrayList.new())
            if actual:size()~=r.count then return false end
            local n=0;for i,row in ipairs(rt.inputs) do if row.inputIndex==r.inputIndex then
                n=n+1;if actual:get(n-1)~=rt.materials[i] then return false end
            end end
        end
    end
    return true
end
function collector.payment(rt)
    local data=rt.logic:getRecipeDataInProgress()
    local consumed,kept=data:getAllConsumedItems(),data:getAllKeepInputItems();local expected=0
    for i,row in ipairs(rt.inputs) do local item=rt.materials[i]
        if row.mode=="consume" then
            expected=expected+1
            if not consumed:contains(item) or craftCarried(rt.body,row.itemId,row.itemType)~=nil or ownItem(rt,item) then return false end
        elseif not kept:contains(item) or craftCarried(rt.body,row.itemId,row.itemType)~=item or not ownItem(rt,item) then return false end
    end
    return consumed:size()==expected and kept:size()==1
end
function collector.measure(rt)
    if rt and rt.kind=="build-shelter-edge" then return shelter.measure(rt) end
    if rt.kind=="build-wood-bed" then return bed.measure(rt) end
    local object=rt.builder.saoCreated;local data=rt.logic:getRecipeDataInProgress()
    if not object or rt.beforeObjects[object] or SAOJavaBridge:worldCollectorCreated(rt.body,object,rt.work.entityId,rt.site.x,rt.site.y,rt.site.z)~=true then return false end
    local fluid=object:getFluidContainer()
    if not fluid or fluid:getCapacity()~=rt.policy.capacity or rt.builder.saoInitialAmount~=0 then return false end
    return collector.payment(rt)
end
function collector.cleanup(rt,a)
    rt.builder.ghostSprite=nil
    for _,key in ipairs({"sawSound","hammerSound","craftingSound"}) do
        local sound=a[key];if sound and sound~=0 and rt.body:getEmitter():isPlaying(sound) then rt.body:getEmitter():stopSound(sound) end
    end
    pcall(function() removeAction(rt.body,a.transactionId,true) end)
    rt.logic:stopCraftAction()
end
function collector.outcome(id,row)
    if row and row.kind=="use-shelter" then return shelter.useOutcome(id,row) end
    if row and row.kind=="build-shelter-edge" then return shelter.outcome(id,row) end
    if row and row.kind=="build-wood-bed" then return bed.outcome(id,row) end
    local rec,t=SAO.Identity.get(id),now()
    if not craftLedger(rec) or not collector.identity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISBuildAction" or not t or not finite(row.atHours)
        or row.atHours<row.startedAt or row.atHours>t or row.endedAt~=row.atHours then return nil end
    for _,k in ipairs({"nativeAttempted","nativeCompleted","constructed","placed","exactInputs","inputsConsumed","toolRetained","feedsFixture"}) do
        if type(row[k])~="boolean" then return nil end
    end
    if row.status~="completed" and row.status~="failed" and row.status~="interrupted" then return nil end
    if row.status=="completed" then
        if not row.nativeAttempted or not row.nativeCompleted or not row.constructed or not row.placed or not row.exactInputs
            or not row.inputsConsumed or not row.toolRetained or row.nativeCredit~=row.id or row.beforeCollectorAmount~=0
            or not finite(row.afterCollectorAmount) or row.afterCollectorAmount<0 or row.afterCollectorAmount>row.collectorCapacity then return nil end
    elseif row.nativeCredit~=nil then return nil end
    if row.nativeObservability~=nil and (row.nativeObservability~="runtime-unavailable" or row.status~="interrupted"
        or row.nativeAttempted or row.nativeCompleted or row.constructed or row.placed or row.inputsConsumed or row.toolRetained
        or row.afterCollectorAmount~=nil or row.beforeCollectorAmount~=nil) then return nil end
    return collector.copy(row)
end
function collector.refresh(rt,row)
    row.sourceObservation={status="unconfirmed",detail="native-created-source-unconfirmed",attempts=1}
    local object=rt.builder.saoCreated
    local identity=SAOJavaBridge:worldCollectorSource(rt.body,object,row.entityId,row.siteX,row.siteY,row.siteZ)
    local sourceId,fp=tostring(identity):match("^([^|]+)|([^|]+)$")
    if not sourceId or sourceId:sub(1,2)~="F:" then return end
    row.collectorSourceId,row.collectorFingerprint=sourceId,fp
    local W,M=SAO.WorldSources,SAO.Perception
    local ok=pcall(function()
        if W.observeChunk(math.floor(row.siteX/8),math.floor(row.siteY/8))~=true then return end
        local fact=W.beliefFact(sourceId)
        if not fact or fact.fingerprint~=fp or fact.x~=row.siteX or fact.y~=row.siteY or fact.z~=row.siteZ then return end
        local place={id="source:"..sourceId,sourceId=sourceId,cx=row.siteX+.5,cy=row.siteY+.5,z=row.siteZ,
            minX=row.siteX,maxX=row.siteX,minY=row.siteY,maxY=row.siteY}
        if M.learnInspectedSource(rt.id,place,sourceId,SAO.History.ticks and SAO.History.ticks() or math.floor(now()*9000),"observed-native-construction")~=true then return end
        row.sourceObservation={status="confirmed",detail="observed-native-construction",attempts=1,revision=fact.revision,atHours=now()}
    end)
    if not ok then row.sourceObservation.detail="created-source-observation-unavailable" end
end
function collector.close(rt,status,detail)
    if rt and rt.kind=="use-shelter" then return shelter.useClose(rt,status,detail) end
    if rt and rt.kind=="build-shelter-edge" then return shelter.close(rt,status,detail) end
    if rt.kind=="build-wood-bed" then return bed.close(rt,status,detail) end
    if rt.closed then return true end
    local rec,w,t=SAO.Identity.get(rt.id),rt.work,now()
    if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not collector.identity(rt.id,w)
        or not collector.purpose(rec,w) or not collector.anchors(rt,w) or not craftLedger(rec) or not t or t<w.startedAt then return false end
    local rows=rec.resourceProductionOutcomes or {}
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row=collector.copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISBuildAction",status,detail,t,t
    row.nativeAttempted,row.nativeCompleted=rt.nativeAttempted==true,rt.nativeCompleted==true
    row.exactInputs=true;row.constructed,row.placed=rt.nativeCompleted==true,rt.nativeCompleted==true
    row.inputsConsumed=rt.nativeAttempted==true and collector.payment(rt)
    row.toolRetained=craftCarried(rt.body,w.toolItemId,w.toolItemType)==rt.tool and ownItem(rt,rt.tool)
    row.feedsFixture=false
    if rt.nativeCompleted then
        row.beforeCollectorAmount=rt.builder.saoInitialAmount;row.afterCollectorAmount=rt.builder.saoCreated:getFluidContainer():getAmount()
        row.feedsFixture=SAOJavaBridge:worldCollectorFeedsFixture(rt.body,rt.builder.saoCreated,w.sourceId,w.fingerprint,w.sourceX,w.sourceY,w.sourceZ)==true
        collector.refresh(rt,row)
    end
    if row.status=="completed" and (not row.toolRetained or not collector.bound(rt,false)) then row.status="failed" end
    row.nativeCredit=row.status=="completed" and w.id or nil
    if not collector.outcome(rt.id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rt.logic:stopCraftAction();rec.resourceProductionWork=nil;rt.closed=true;plumbDispose(rt);reconcile(rt.id);return true
end
function collector.begin(id,body,step,context)
    local rec,t=owner(id,body),now();local policy=rec and collector.recipe(step.entityId,body)
    if not policy or not t or not craftLedger(rec) or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) or step.recipeId~=policy.recipeId
        or step.owner~="SAO.ResourceProduction" or step.token~="resource:collector-built" or step.category~="water"
        or not R.privatelyKnown(id,{kind="build-rain-collector",category="water",sourceId=step.sourceId,sourceRevision=step.sourceRevision,
            fingerprint=step.fingerprint,sourceX=step.sourceX,sourceY=step.sourceY,sourceZ=step.sourceZ,place=step.place,site=step.site})
        or not collector.site(id,body,step.site,step.sourceX,step.sourceY,step.sourceZ) then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or not p.collector or p.collector.constructedWorkId or p.admission or p.steps[p.cursor]~=step or step.id~=context.purposeStepId then return false end
    for _,old in ipairs(rec.resourceProductionOutcomes or {}) do
        if old.kind=="build-rain-collector" and old.purposeId==p.id and old.status=="completed" then return false end
    end
    local selected=collector.inputs(policy,body)
    if not collector.rowsEqual(selected,step.inputs) or not collector.rowsEqual(policy.requirements,step.requirements) then return false end
    local item=carried(body,step.itemId,step.itemType);local fluid,amount=vessel(body,item)
    local sq=SAOJavaBridge:worldCollectorPlacementSquare(body,step.site.x,step.site.y,step.site.z,step.site.revision)
    if not fluid then return false end
    local route=SAO.Locomotion.jobs[id];if route and not route.done then return false end
    local world=getWorld();if not world then return false end
    local rt={kind="build-rain-collector",id=id,record=rec,body=body,item=item,policy=policy,inputs=collector.copy(selected),
        materials={},site=collector.copy(step.site),siteSquare=sq,inventory=body:getInventory(),
        square=body:getCurrentSquare(),x=body:getX(),y=body:getY(),world=world:getWorld(),cell=body:getCell(),
        queue=ISTimedActionQueue.getTimedActionQueue(body),token=body:getModData().SAOExternalToken,startedAt=t,actions={},beforeObjects={},
        sourceId=step.sourceId,sourceRevision=step.sourceRevision,fingerprint=step.fingerprint,sx=step.sourceX,sy=step.sourceY,sz=step.sourceZ,
        itemId=item:getID(),itemType=item:getFullType(),beforeAmount=amount,capacity=fluid:getCapacity()}
    local containers=ArrayList.new();containers:add(rt.inventory)
    local logic=BuildLogic.new(body,nil,nil);logic:setContainers(containers);logic:setRecipe(policy.recipe);logic:setManualSelectInputs(true);logic:clearManualInputs()
    for _,r in ipairs(policy.requirements) do local manual=ArrayList.new()
        for _,row in ipairs(selected) do if row.inputIndex==r.inputIndex then
            local material=craftCarried(body,row.itemId,row.itemType);if not material then return false end
            manual:add(material);rt.materials[#rt.materials+1]=material
        end end
        if manual:size()~=r.count or logic:setManualInputsFor(policy.recipe:getInputs():get(r.inputIndex),manual)~=true then return false end
    end
    if not logic:canPerformCurrentRecipe() then return false end
    rt.logic,rt.tool=logic,rt.materials[1];rt.toolId,rt.toolType=selected[1].itemId,selected[1].itemType
    local place,cx,cy=rememberedPlace(id,step)
    local seq=(rec.resourceProductionSequence or 0)+1
    local needs=SAO.Needs.read(body) or {};local ok,health=pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    local w={id="resource-production/"..id.."/"..seq,sequence=seq,actorId=id,kind=rt.kind,category="water",token="resource:collector-built",
        purposeId=context.purposeId,purposeStepId=context.purposeStepId,requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,
        sourceId=rt.sourceId,sourceRevision=rt.sourceRevision,fingerprint=rt.fingerprint,sourceX=rt.sx,sourceY=rt.sy,sourceZ=rt.sz,
        sourceChunkX=cx,sourceChunkY=cy,place=place,itemId=rt.itemId,itemType=rt.itemType,beforeAmount=amount,capacity=rt.capacity,
        toolCategory="hammer",toolItemId=rt.toolId,toolItemType=rt.toolType,entityId=step.entityId,recipeId=policy.recipeId,
        requirements=collector.copy(policy.requirements),inputs=collector.copy(selected),collectorCapacity=policy.capacity,
        siteKey=rt.site.key,siteRevision=rt.site.revision,siteX=rt.site.x,siteY=rt.site.y,siteZ=rt.site.z,siteObservedAtHours=rt.site.observedAtHours,
        world=rt.world,bodyToken=rt.token,startedAt=t,status="constructing",stage="approaching",
        admittedNeeds={hunger=tonumber(needs.hunger),thirst=tonumber(needs.thirst),fatigue=tonumber(needs.fatigue)},admittedHealth=ok and tonumber(health) or nil}
    rt.work,rt.workId=w,w.id
    if not collector.identity(id,w) then return false end
    rt.containers=containers
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,w,rt
    if SAO.ProceduralPlanning.admitProduction(id,w)~=true then rec.resourceProductionWork=nil;plumbDispose(rt);return false end
    rt.purpose,rt.step=collector.purpose(rec,w)
    if sq then return collector.queue(rt) end
    local destination=collector.destination(rt)
    if destination and SAO.Locomotion.order(id,body,destination.x,destination.y,destination.z) then
        rt.route=SAO.Locomotion.jobs[id]
        if rt.route and rt.route.body==body then return true end
    end
    plumbInterrupt(id,body,"native-collector-approach-refused");return false
end
function collector.destination(rt)
    if rt and rt.kind=="build-shelter-edge" then return shelter.destination(rt) end
    if rt.kind=="build-wood-bed" then return bed.destination(rt) end
    local site=rt.site
    for _,known in ipairs(SAO.Perception.collectorSites(rt.id,rt.body) or {}) do
        if known.z==site.z and math.abs(known.x-site.x)<=1 and math.abs(known.y-site.y)<=1
            and (known.x~=site.x or known.y~=site.y) and SAO.Standing.mayAttemptBelieved(rt.id,known.x,known.y,"standing")==true then return known end
    end
    if rt.body:getZ()~=site.z then return site end
end
function collector.queue(rt)
    if rt and rt.kind=="build-shelter-edge" then return shelter.queue(rt) end
    if rt.kind=="build-wood-bed" then return bed.queue(rt) end
    local w,body,policy,id=rt.work,rt.body,rt.policy,rt.id
    local sq=SAOJavaBridge:worldCollectorPlacementSquare(body,w.siteX,w.siteY,w.siteZ,w.siteRevision)
    if not sq then return false end
    rt.siteSquare,rt.square,rt.x,rt.y=sq,body:getCurrentSquare(),body:getX(),body:getY()
    w.stage="preparing"
    rt.builder=collector.newEntity(rt,rt.containers);rt.sprite=rt.builder:getSprite()
    local objects=sq:getObjects();for i=0,objects:size()-1 do rt.beforeObjects[objects:get(i)]=true end
    for _,material in ipairs(rt.materials) do if material:getContainer()~=rt.inventory then
        plumbGuard(rt,ISInventoryTransferAction:new(body,material,material:getContainer(),rt.inventory),"transfer",material)
    end end
    if body:getPrimaryHandItem()~=rt.tool then plumbGuard(rt,ISEquipWeaponAction:new(body,rt.tool,50,true,false),"equip",rt.tool) end
    local a=ISBuildAction:new(body,rt.builder,rt.site.x,rt.site.y,rt.site.z,rt.builder.north,rt.sprite,policy.recipe:getTime(body))
    -- BuildLogic copies its exact manual slots from the native multicraft
    -- selection cache when starting construction.
    if rt.logic:getPossibleCraftCount(true)<1 then plumbInterrupt(id,body,"native-collector-inputs-refused");return false end
    rt.logic:startCraftAction(a);plumbGuard(rt,a,"collector",rt.tool)
    if not collector.bound(rt,true) or not plumbEnqueue(rt,1) then plumbInterrupt(id,body,"native-collector-admission-refused");return false end
    return true
end
function collector.recover(id,body)
    local saved=SAO.Identity.get(id);if saved and saved.resourceProductionWork and saved.resourceProductionWork.kind=="use-shelter" then return shelter.useRecover(id,body) end
    reconcile(id);local rec=SAO.Identity.get(id);local w=rec and rec.resourceProductionWork
    if not w then return true end
    if runtime[id] then return plumbInterrupt(id,body,"collector-owner-reconciled") end
    local t=now();local world=getWorld()
    if not craftLedger(rec) or not collector.identity(id,w) or w.sequence>rec.resourceProductionSequence or not collector.purpose(rec,w)
        or w.status~="constructing" and w.status~="interrupted" or not t or t<w.startedAt or not world or world:getWorld()~=w.world
        or not body or tostring(body:getModData().SAOPersonId or "")~=tostring(id) or body:getModData().SAOExternalToken~=w.bodyToken then return false end
    for _,q in pairs(ISTimedActionQueue.queues) do
        local pending={};for _,a in ipairs(q.queue) do pending[#pending+1]=a end
        if q.current and q:indexOf(q.current)==-1 then pending[#pending+1]=q.current end
        for _,a in ipairs(pending) do if a.actorId==id and a.workId==w.id and a.bodyToken==w.bodyToken then
            if type(a._SAOPlumbRetireSaved)~="function" then return false end
            local ok,closed=pcall(a._SAOPlumbRetireSaved,rec,w);if not ok or not closed then return false end
        end end
    end
    if not rec.resourceProductionWork then return true end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if SAOJavaBridge:hasPendingActions(body) or q.current or #q.queue>0 then return false end
    local rows=rec.resourceProductionOutcomes or {}
    for _,r in ipairs(rows) do if r.id==w.id then return false end end
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row=collector.copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISBuildAction","interrupted","collector-runtime-unavailable",t,t
    row.nativeObservability="runtime-unavailable"
    row.nativeAttempted,row.nativeCompleted,row.constructed,row.placed,row.exactInputs,row.inputsConsumed,row.toolRetained,row.feedsFixture=false,false,false,false,false,false,false,false
    if w.kind=="build-wood-bed" or w.kind=="build-shelter-edge" then row.feedsFixture=nil;row.parts={} end
    if not collector.outcome(id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rec.resourceProductionWork=nil;reconcile(id);return true
end
function collector.tick(id,body)
    local saved=SAO.Identity.get(id);if saved and saved.resourceProductionWork and saved.resourceProductionWork.kind=="use-shelter" then return shelter.useTick(id,body) end
    local rt=runtime[id]
    if not rt then return collector.recover(id,body) and "interrupted" or "cancelling" end
    if rt.cancelling or rt.body~=body or not collector.bound(rt,not rt.nativeAttempted) or not now() or now()-rt.startedAt>.5 then
        return plumbInterrupt(id,rt.body,rt.cancelReason or "collector-owner-changed") and "interrupted" or "cancelling"
    end
    if rt.work.stage=="approaching" then
        if not rt.route or SAO.Locomotion.jobs[id]~=rt.route then return plumbInterrupt(id,body,"collector-route-owner-lost") and "interrupted" or "cancelling" end
        SAO.Locomotion.tick(id)
        if not rt.route.done then return "moving" end
        if rt.route.result=="arrived" then
            if collector.queue(rt) then return rt.work.stage end
            if rt.kind=="build-wood-bed" then SAO.Perception.observeBedSites(id,body,now()) end
            if SAO.Perception.observeCollectorSites then SAO.Perception.observeCollectorSites(id,body,now()) end
            local destination=collector.destination(rt)
            if destination and not rt.interactionReturn and SAO.Locomotion.order(id,body,destination.x,destination.y,destination.z) then
                rt.route=SAO.Locomotion.jobs[id];rt.interactionReturn=true;return "moving"
            end
        end
        return plumbInterrupt(id,body,"native-collector-approach-refused") and "interrupted" or "cancelling"
    end
    if queued(rt.action) then return rt.work.stage end
    return plumbInterrupt(id,body,"native-collector-acknowledgement-missing") and "interrupted" or "cancelling"
end
-- Installed ISBuildIsoEntity.setInfo adapted only at exact actor and measured
-- created-object boundaries. The native constructor/factory/place path is retained.
function collector.setInfo(self, square, north, sprite, openSprite)

	if self.objectInfo:getScript():isProp() then
		local props = ISMoveableSpriteProps.new(IsoObject.new(square, sprite):getSprite())
		props.rawWeight = 10
		props:placeMoveableInternal(self.character, square, instanceItem(ItemKey.Weapon.PLANK), sprite)
		return;
	end

	-- get correct thumpable
	local thumpable;
	if openSprite then
		thumpable = IsoThumpable.new(getCell(), square, sprite, openSprite, north, self);
	else
		thumpable = IsoThumpable.new(getCell(), square, sprite, north, self);
	end

	-- set property flags
	local spriteType = thumpable:getType();
	local thumpableProps = thumpable:getProperties();
	self.blockAllTheSquare = thumpableProps and thumpableProps:has(IsoPropertyType.BLOCKS_PLACEMENT); -- need to consider prop IsHigh and IsLow here
	self.canPassThrough = thumpableProps and not (thumpableProps:has(IsoFlagType.solid) or thumpableProps:has(IsoFlagType.solidtrans) or
		thumpableProps:has(IsoFlagType.doorN) or thumpableProps:has(IsoFlagType.doorW) or
		thumpableProps:has(IsoFlagType.WallN) or thumpableProps:has(IsoFlagType.WallNTrans) or thumpableProps:has(IsoFlagType.WallW) or
		thumpableProps:has(IsoFlagType.WallWTrans) or thumpableProps:has(IsoFlagType.WallNW));
	self.hoppable = thumpableProps and (thumpableProps:has(IsoFlagType.HoppableN) or thumpableProps:has(IsoFlagType.HoppableW) or thumpableProps:has(IsoFlagType.TallHoppableN) or thumpableProps:has(IsoFlagType.TallHoppableW));
	self.isStairs = spriteType and (spriteType == IsoObjectType.stairsTW or spriteType == IsoObjectType.stairsTN or spriteType == IsoObjectType.stairsMW or spriteType == IsoObjectType.stairsMN or spriteType == IsoObjectType.stairsBW or spriteType == IsoObjectType.stairsBN);
	self.isDoorFrame = spriteType and (spriteType == IsoObjectType.doorFrN or spriteType == IsoObjectType.doorFrW);
	self.isDoor = spriteType and (spriteType == IsoObjectType.doorN or spriteType == IsoObjectType.doorW);
	self.isFloor = thumpableProps and thumpableProps:has(IsoFlagType.solidfloor);
	if self.isDoor then	-- set thumpDmg override for doors
		self.thumpDmg = 5;
	end
	self.canBarricade = ((spriteType and (spriteType == IsoObjectType.doorN or spriteType == IsoObjectType.doorW)) or (thumpableProps and (thumpableProps:has(IsoFlagType.WindowN) or thumpableProps:has(IsoFlagType.WindowW) or thumpableProps:has(IsoFlagType.windowN) or thumpableProps:has(IsoFlagType.windowW))))
			and thumpableProps and not (thumpableProps:has(IsoPropertyType.DOUBLE_DOOR) or thumpableProps:has(IsoPropertyType.GARAGE_DOOR));

	buildUtil.setInfo(thumpable, self);

	if self.isDoor and self.modData["keyId"] ~= nil then
		thumpable:setKeyId(self.modData["keyId"])
	end

	local playerObj = self.character
	local craftRecipe = self.objectInfo:getRecipe():getCraftRecipe()
	local perk = craftRecipe:getHighestRelevantSkill(playerObj)
	local perkLevel = playerObj:getPerkLevel(perk)

	-- Use at least the minimum required perk level in cheat mode, to avoid zero-health thumpables.
	if playerObj:isBuildCheat() then
		for i=1,craftRecipe:getRequiredSkillCount() do
			local requiredSkill = craftRecipe:getRequiredSkill(i-1)
			if (requiredSkill:getPerk() ~= nil) and (requiredSkill:getLevel() > perkLevel) then
				perkLevel = requiredSkill:getLevel()
			end
		end
	end

	local bonusHealth = self.objectInfo:getScript():getBonusHealth();
	local skillBonus = craftRecipe:getHighestRelevantSkillLevel(playerObj) * self.objectInfo:getScript():getSkillBaseHealth();
	local baseHealth = math.max(self.objectInfo:getScript():getHealth(), 0);
	-- MULTIPLY BONUS HEALTH
	local bonusHealthMultiplier = getSandboxOptions():getOptionByName("ConstructionBonusPoints"):getValue()
	if bonusHealthMultiplier == 1 then bonusHealth = bonusHealth * 0.5; end
	if bonusHealthMultiplier == 2 then bonusHealth = bonusHealth * 0.7; end
	if bonusHealthMultiplier == 4 then bonusHealth = bonusHealth * 1.3; end
	if bonusHealthMultiplier == 5 then bonusHealth = bonusHealth * 1.5; end
	local totalHealth = baseHealth + bonusHealth + skillBonus;
	thumpable:setMaxHealth(totalHealth);
	thumpable:setHealth(thumpable:getMaxHealth())

	thumpable:setBreakSound(self.objectInfo:getScript():getBreakSound());

	if thumpableProps and thumpableProps:has(IsoPropertyType.IS_STACKABLE) then
		local props = ISMoveableSpriteProps.new(thumpable:getSprite())
		local offsetY = props:getTotalTableHeight(square)
		thumpable:setRenderYOffset(offsetY)
	end

	if self.objectInfo:getScript() and self.objectInfo:getScript():getParent() then
		local gameEntityScript = self.objectInfo:getScript():getParent();
		local isFirstTimeCreated = true;
		GameEntityFactory.CreateIsoObjectEntity(thumpable, gameEntityScript, isFirstTimeCreated);
        if thumpable:getFluidContainer() then self.saoInitialAmount=thumpable:getFluidContainer():getAmount() end
	else
		if SAO.Log and SAO.Log.line then SAO.Log.line("RESOURCE", "Collector entity script missing") end
	end

	local replacedObjectIndex = -1;
	if self.previousStageObject and self.previousStageObject:getSquare() == square then
		replacedObjectIndex = self.previousStageObject:getSquare():transmitRemoveItemFromSquare(self.previousStageObject);
		self.previousStageObject = nil;
	end

	-- lightsource properties
	if self.objectInfo:getScript():getLightRadius() then
		local script = self.objectInfo:getScript();

		-- get our FaceScript (not FaceInfo!)
		local index = self.nSprite; -- W and E
		if index == 2 then index = 0 end -- N
		if index == 4 then index = 2 end -- S
		local face = script:getFace(index);
		-- to build a lamp on pillar for ex. we need to check the torch used to add it's battery remaining values in the thumpable, we need to find what items has been used for it
		local consumedItems = self.buildPanelLogic:getAllConsumedItems();
		local torchUsed = nil;
		if consumedItems then
			for i=0, consumedItems:size() -1 do
				-- we can either have a full type (Base.Torch) or a list of tags
				local item = consumedItems:get(i);
				if script:getLightsourceItem() and item:getFullType() == script:getLightsourceItem() then
					torchUsed = item;
					break;
				end
				if script:getLightsourceTagItem() then
					for j=0, script:getLightsourceTagItem():size()-1 do
						local tag = script:getLightsourceTagItem():get(j);
						if item:hasTag(ItemTag.get(ResourceLocation.of(tag))) then
							torchUsed = item;
							break;
						end
					end
				end
			end
		end

		if not torchUsed and self.character:isBuildCheat() and self.objectInfo:getScript():getDebugItem() then
			torchUsed = instanceItem(self.objectInfo:getScript():getDebugItem());
		end

		if torchUsed then
			thumpable:createLightSource(script:getLightRadius(), face:getLightsourceOffsetX(), face:getLightsourceOffsetY(), face:getLightsourceOffsetZ(), 0, script:getLightsourceFuel(), torchUsed, playerObj)
		end
	end

	square:AddSpecialObject(thumpable, replacedObjectIndex);
    self.saoCreated=thumpable
    self.saoCreatedParts=self.saoCreatedParts or {};self.saoCreatedParts[#self.saoCreatedParts+1]=thumpable
	buildUtil.checkCorner(square:getX(), square:getY(), square:getZ(), north, thumpable, self);

	-- This is so any containers that are in a tile are flagged as "already explored" so they don't spawn loot in them
	thumpable:setExplored(true)

	local result = nil;
	if self.objectInfo:getScript():getOnCreate() then
        local facing = self:getFace():getFaceName();
		local func = self.objectInfo:getScript():getOnCreate();
		result = BaseCraftingLogic.callLuaObject(func, {thumpable = thumpable, craftRecipeData = self.buildPanelLogic:getRecipeData(), character = playerObj, facing = facing});
	end

	square:RecalcAllWithNeighbours(true);
	if result ~= nil then
		-- object transmitted somewhere in OnCreate function, don't send again
		-- can be used when you have to transmit not just one object
		if result.objectAlreadyTransmitted then
			return;
		end

		-- transmitted object is not just isoThumpable,
		-- replace it to make sure client will get correct instance of the object
		if (result.replaceObject and result.object ~= nil) then
			result.object:transmitCompleteItemToClients();
		end
		return;
	end

	thumpable:transmitCompleteItemToClients();
end

function collector.newEntity(rt,containers)
    if not collector.entityClass then
        collector.entityClass=ISBuildIsoEntity:derive("SAORainCollectorEntity")
        collector.entityClass.setInfo=collector.setInfo
    end
    local direction=rt.kind=="build-shelter-edge" and (rt.site.face=="N" and 2 or 1) or (rt.site.face=="E" and 3 or 4)
    local builder=ISBuildIsoEntity.new(collector.entityClass,rt.body,rt.policy.info,direction,containers,rt.logic)
    if rt.kind=="build-shelter-edge" then builder.north=rt.site.face=="N" end
    local nativeCreate=ISBuildIsoEntity.create
    function builder:create(x,y,z,north,sprite)
        local c=rt.current
        if not c or not c.performing or not plumbCurrent(c) or not collector.bound(rt,true)
            or not collector.exact(rt,c.action) or x~=rt.site.x or y~=rt.site.y or z~=rt.site.z or sprite~=rt.sprite then return false end
        rt.nativeAttempted=true
        return nativeCreate(self,x,y,z,north,sprite)
    end
    function builder:setInfo(square,north,sprite,openSprite)
        local c=rt.current
        if not c or not c.performing or not plumbCurrent(c) or not rt.nativeAttempted or not collector.bound(rt,false)
            or not collector.payment(rt) or (rt.kind=="build-wood-bed" and not bed.partExpected(rt,square,sprite)
                or rt.kind~="build-wood-bed" and (square~=rt.siteSquare or sprite~=rt.sprite)) then return false end
        return collector.setInfo(self,square,north,sprite,openSprite)
    end
    local face=builder:getFace()
    local sprite=face:getTileInfo(0,0,0):getSpriteName()
    builder:setSprite(sprite);builder:setSouthSprite(sprite);builder:setNorthSprite(sprite)
    builder.dragNilAfterPlace=false
    return builder
end


-- The same native construction owner supplies a wooden bed for retained sleep.
-- Recovery means and measured physiology stay with Needs and its ordinary consumers.
bed={}
function bed.recipe(body)
    if not collector.install() then return nil end
    local infos=SpriteConfigManager.GetObjectInfoList()
    for i=0,infos:size()-1 do
        local info=infos:get(i);local script=info:getScript()
        if script and script:getParent():getScriptObjectFullType()=="Base.Wood_Bed" and info:getRecipe() then
            local recipe=info:getRecipe():getCraftRecipe()
            if not recipe or not CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body) then return nil end
            for j=0,recipe:getRequiredSkillCount()-1 do
                if not CraftRecipeManager.hasPlayerRequiredSkill(recipe:getRequiredSkill(j),body) then return nil end
            end
            if recipe:getInputs():size()~=4 or script:isProp() then return nil end
            local requirements={}
            for index,category in ipairs({"hammer","plank","nails","mattress"}) do
                local input=recipe:getInputs():get(index-1)
                if input:getResourceType()~=ResourceType.Item or input:getIntAmount()~=(index==1 and 1 or index==2 and 6 or index==3 and 4 or 1)
                    or input:isKeep()~=(index==1) then return nil end
                requirements[#requirements+1]={inputIndex=index-1,category=category,count=input:getIntAmount(),mode=input:isKeep() and "keep" or "consume"}
            end
            for _,name in ipairs({"S","E"}) do local face=info:getFace(name)
                if not face or face:getWidth()~=(name=="S" and 2 or 1) or face:getHeight()~=(name=="S" and 1 or 2)
                    or face:getzLayers()~=1 then return nil end
            end
            return {info=info,recipe=recipe,recipeId=recipe:getScriptObjectFullType(),requirements=requirements}
        end
    end
end
function bed.site(id,body,site)
    if type(site)~="table" or not textId(site.key) or not textId(site.revision)
        or site.actorId~=id or site.observed~=true or site.source~="native-personal-visibility"
        or site.face~="S" and site.face~="E" or not finite(site.observedAtHours) or site.observedAtHours<0
        or not now() or site.observedAtHours>now() then return false end
    for _,row in ipairs(SAO.Perception.bedSites(id,body) or {}) do
        if row.key==site.key and row.revision==site.revision and row.x==site.x and row.y==site.y and row.z==site.z and row.face==site.face
            and row.approachX==site.approachX and row.approachY==site.approachY and row.approachZ==site.approachZ
            and row.observedAtHours>=site.observedAtHours and row.observedAtHours<=now() then return true end
    end
    return false
end
function R.bedOptions(id,body)
    local ok,out=pcall(function()
        if not owner(id,body) or not now() or not SAO.Perception.bedSites then return {} end
        local policy=bed.recipe(body);if not policy then return {} end
        local inputs=collector.inputs(policy,body);local out={}
        for _,site in ipairs(SAO.Perception.bedSites(id,body)) do
            local width,height=site.face=="S" and 2 or 1,site.face=="S" and 1 or 2
            local permitted=bed.site(id,body,site) and SAO.Standing.mayAttemptBelieved(id,site.approachX,site.approachY,"standing")==true
            for x=0,width-1 do for y=0,height-1 do
                if SAO.Standing.mayAttemptBelieved(id,site.x+x,site.y+y,"standing")~=true then permitted=false end
            end end
            if permitted then
                out[#out+1]={kind="build-wood-bed",owner="SAO.ResourceProduction",category="construction",known=true,
                    token="resource:bed-built",entityId="Base.Wood_Bed",recipeId=policy.recipeId,
                    requirements=collector.copy(policy.requirements),inputs=collector.copy(inputs),site=collector.copy(site),
                    distance=math.sqrt((site.approachX+.5-body:getX())^2+(site.approachY+.5-body:getY())^2)}
                if #out>=16 then break end
            end
        end
        return out
    end)
    return ok and out or {}
end
local BED_FIELDS={}
for _,key in ipairs({"id","workId","sequence","actorId","kind","category","token","entityId","recipeId",
    "purposeId","purposeStepId","requestedPurposeId","requestedPurposeStepId","toolCategory","toolItemId","toolItemType",
    "requirements","inputs","site","siteKey","siteRevision","siteObservedAtHours","siteX","siteY","siteZ","face",
    "world","bodyToken","startedAt","stage","status","admittedNeeds","admittedHealth","nativeOwner","detail","atHours","endedAt",
    "nativeAttempted","nativeCompleted","constructed","placed","exactInputs","inputsConsumed","toolRetained","nativeCredit",
    "parts","bedKey","sourceObservation","nativeObservability","purposeDelivered","experienceDelivered"}) do BED_FIELDS[key]=true end
function bed.identity(id,w)
    if type(w)~="table" or getmetatable(w) or w.actorId~=id or w.kind~="build-wood-bed" or w.category~="construction"
        or w.token~="resource:bed-built" or w.entityId~="Base.Wood_Bed" or not textId(w.recipeId)
        or not integer(w.sequence) or w.sequence<1 or w.id~="resource-production/"..id.."/"..w.sequence
        or not textId(w.purposeId) or not textId(w.purposeStepId) or not textId(w.world)
        or w.bodyToken~=nil and not textId(w.bodyToken) or not finite(w.startedAt) or w.startedAt<0
        or w.toolCategory~="hammer" or not textId(w.toolItemId) or not textId(w.toolItemType)
        or not textId(w.siteKey) or not textId(w.siteRevision) or not finite(w.siteObservedAtHours)
        or w.siteObservedAtHours>w.startedAt or w.siteObservedAtHours<0 or w.face~="S" and w.face~="E"
        or type(w.site)~="table" or w.site.key~=w.siteKey or w.site.revision~=w.siteRevision
        or w.site.face~=w.face or w.site.x~=w.siteX or w.site.y~=w.siteY or w.site.z~=w.siteZ
        or type(w.inputs)~="table" or getmetatable(w.inputs) or #w.inputs~=12
        or type(w.requirements)~="table" or getmetatable(w.requirements) or #w.requirements~=4 then return false end
    for key in pairs(w) do if not BED_FIELDS[key] then return false end end
    for _,key in ipairs({"siteX","siteY","siteZ"}) do if not finite(w[key]) or w[key]%1~=0 then return false end end
    local seen,counts={},{}
    for _,row in ipairs(w.inputs) do
        if type(row)~="table" or getmetatable(row) or not integer(row.inputIndex) or row.inputIndex>3
            or not textId(row.itemId) or not textId(row.itemType) or seen[row.itemId]
            or row.mode~=(row.inputIndex==0 and "keep" or "consume") then return false end
        if row.inputIndex==1 and row.itemType~="Base.Plank" or row.inputIndex==2 and row.itemType~="Base.Nails"
            or row.inputIndex==3 and row.itemType~="Base.Mattress" then return false end
        seen[row.itemId]=true;counts[row.inputIndex]=(counts[row.inputIndex] or 0)+1
    end
    for i,category in ipairs({"hammer","plank","nails","mattress"}) do local req=w.requirements[i]
        local count=i==1 and 1 or i==2 and 6 or i==3 and 4 or 1
        if req.inputIndex~=i-1 or req.count~=count or counts[i-1]~=count or req.category~=category
            or req.mode~=(i==1 and "keep" or "consume") then return false end
    end
    return w.inputs[1].itemId==w.toolItemId and w.inputs[1].itemType==w.toolItemType and collector.copy(w)~=nil
end
function bed.purpose(rec,w)
    local planning=rec and rec.proceduralPlanning;local p=planning and planning.purposes[w.purposeId]
    local step=p and p.steps[p.cursor];local a=p and p.admission
    if not p or not p.bedConstruction or p.bedConstruction.recoveryKind~="sleep" or p.bedConstruction.constructedWorkId
        or p.status=="completed" or p.status=="abandoned" or not step or not a or step.owner~="SAO.ResourceProduction"
        or step.productionKind~=w.kind or step.token~=w.token or step.id~=w.purposeStepId or step.target~=w.entityId
        or step.entityId~=w.entityId or step.recipeId~=w.recipeId or a.owner~=step.owner or a.stepId~=step.id
        or a.correlationId~=w.id or a.target~=step.target or not finite(a.at) or a.at<w.startedAt
        or not collector.rowsEqual(step.inputs,w.inputs) or not collector.rowsEqual(step.requirements,w.requirements)
        or type(step.site)~="table" then return nil end
    for _,key in ipairs({"key","revision","x","y","z","face","approachX","approachY","approachZ","observedAtHours"}) do
        if step.site[key]~=w.site[key] then return nil end
    end
    return p,step
end
function bed.anchors(rt,w)
    return w.recipeId==rt.policy.recipeId and w.entityId=="Base.Wood_Bed" and w.siteKey==rt.site.key and w.siteRevision==rt.site.revision
        and w.siteX==rt.site.x and w.siteY==rt.site.y and w.siteZ==rt.site.z and w.face==rt.site.face
        and w.siteObservedAtHours==rt.site.observedAtHours and collector.rowsEqual(w.inputs,rt.inputs)
        and collector.rowsEqual(w.requirements,rt.policy.requirements)
end
function bed.bound(rt,pre)
    local body,w=rt.body,rt.work;local rec=owner(rt.id,body);local p,step=bed.purpose(rec,w);local world=getWorld()
    if not body or rt.closed or rt.cancelling or runtime[rt.id]~=rt or rec~=rt.record or rec.resourceProductionWork~=w
        or not bed.identity(rt.id,w) or not craftLedger(rec) or not bed.anchors(rt,w) or w.id~=rt.workId or w.startedAt~=rt.startedAt
        or w.bodyToken~=rt.token or body:getModData().SAOExternalToken~=rt.token or w.world~=rt.world
        or not now() or now()<rt.startedAt or not world or world:getWorld()~=rt.world or world:getCell()~=rt.cell
        or body:getCell()~=rt.cell or body:getInventory()~=rt.inventory or ISTimedActionQueue.getTimedActionQueue(body)~=rt.queue
        or p~=rt.purpose or step~=rt.step or not bed.site(rt.id,body,rt.site)
        or w.stage~="approaching" and (body:getCurrentSquare()~=rt.square or math.abs(body:getX()-rt.x)>.01 or math.abs(body:getY()-rt.y)>.01) then return false end
    local width,height=w.face=="S" and 2 or 1,w.face=="S" and 1 or 2
    for x=0,width-1 do for y=0,height-1 do if SAO.Standing.mayTakeCurrent(rt.id,w.siteX+x,w.siteY+y,"standing")~=true then return false end end end
    if SAO.Standing.mayTakeCurrent(rt.id,rt.site.approachX,rt.site.approachY,"standing")~=true then return false end
    if not pre then return true end
    if rt.nativeAttempted or body:isBuildCheat() or isClient() or isServer() then return false end
    if w.stage~="approaching" and SAOJavaBridge:worldBedPlacementSquare(body,w.siteX,w.siteY,w.siteZ,w.face,w.siteRevision)~=rt.siteSquare then return false end
    for i,row in ipairs(rt.inputs) do local item=rt.materials[i]
        if craftCarried(body,row.itemId,row.itemType)~=item or not ownItem(rt,item) or item:getIsCraftingConsumed()
            or not ISBuildIsoEntity.predicateMaterial(item)
            or CraftRecipeManager.getValidInputScriptForItem(rt.policy.recipe,item,body)~=rt.policy.recipe:getInputs():get(row.inputIndex)
            or row.mode=="keep" and (item:isBroken() or item:getCondition()<=0 or item:isRequiresEquippedBothHands()) then return false end
    end
    return true
end
function bed.partExpected(rt,square,sprite)
    local face=rt.builder:getFace()
    for x=0,face:getWidth()-1 do for y=0,face:getHeight()-1 do
        local info=face:getTileInfo(x,y,0)
        if square==rt.cell:getGridSquare(rt.site.x+x,rt.site.y+y,rt.site.z) and info and sprite==info:getSpriteName() then return true end
    end end
    return false
end
function bed.measure(rt)
    local parts=rt.builder.saoCreatedParts or {}
    if #parts~=2 or parts[1]==parts[2] or rt.beforeObjects[parts[1]] or rt.beforeObjects[parts[2]]
        or SAOJavaBridge:worldBedCreated(rt.body,parts[1],parts[2],rt.site.x,rt.site.y,rt.site.z,rt.site.face)~=true then return false end
    return collector.payment(rt)
end
function bed.refresh(rt,row)
    row.sourceObservation={status="unconfirmed",detail="new-bed-not-currently-admissible",atHours=now()}
    for _,place in ipairs(SAO.Needs.recoveryPlaces(rt.id,rt.body) or {}) do
        if place.kind=="bed" and place.available==true and place.objectX==row.siteX and place.objectY==row.siteY
            and place.objectZ==row.siteZ then
            row.bedKey=place.key
            row.sourceObservation={status="confirmed",detail="observed-native-bed-construction",atHours=now(),key=place.key}
            return
        end
    end
end
function bed.outcome(id,row)
    local rec,t=SAO.Identity.get(id),now()
    if not craftLedger(rec) or not bed.identity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISBuildAction" or not t or not finite(row.atHours)
        or row.atHours<row.startedAt or row.atHours>t or row.endedAt~=row.atHours
        or row.status~="completed" and row.status~="failed" and row.status~="interrupted" then return nil end
    for _,key in ipairs({"nativeAttempted","nativeCompleted","constructed","placed","exactInputs","inputsConsumed","toolRetained"}) do
        if type(row[key])~="boolean" then return nil end
    end
    if type(row.parts)~="table" or getmetatable(row.parts) or #row.parts>2 then return nil end
    if row.status=="completed" then
        if not row.nativeAttempted or not row.nativeCompleted or not row.constructed or not row.placed
            or not row.exactInputs or not row.inputsConsumed or not row.toolRetained or row.nativeCredit~=row.id or #row.parts~=2 then return nil end
        local names=row.face=="S" and {"carpentry_02_72","carpentry_02_73"} or {"carpentry_02_75","carpentry_02_74"}
        for i,part in ipairs(row.parts) do
            if type(part)~="table" or part.x~=row.siteX+(row.face=="S" and i-1 or 0)
                or part.y~=row.siteY+(row.face=="E" and i-1 or 0) or part.z~=row.siteZ or part.sprite~=names[i]
                or not integer(part.objectIndex) then return nil end
        end
    elseif row.nativeCredit~=nil then return nil end
    if row.nativeObservability~=nil and (row.nativeObservability~="runtime-unavailable" or row.status~="interrupted"
        or row.nativeAttempted or row.nativeCompleted or row.constructed or row.placed or row.inputsConsumed or row.toolRetained
        or #row.parts~=0 or row.bedKey~=nil) then return nil end
    if row.bedKey~=nil and (not textId(row.bedKey) or type(row.sourceObservation)~="table"
        or row.sourceObservation.status~="confirmed" or row.sourceObservation.key~=row.bedKey) then return nil end
    return collector.copy(row)
end
function bed.close(rt,status,detail)
    if rt.closed then return true end
    local rec,w,t=SAO.Identity.get(rt.id),rt.work,now()
    if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not bed.identity(rt.id,w)
        or not bed.purpose(rec,w) or not bed.anchors(rt,w) or not craftLedger(rec) or not t or t<w.startedAt then return false end
    local rows=rec.resourceProductionOutcomes or {}
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row=collector.copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISBuildAction",status,detail,t,t
    row.nativeAttempted,row.nativeCompleted=rt.nativeAttempted==true,rt.nativeCompleted==true
    row.exactInputs=true;row.constructed,row.placed=rt.nativeCompleted==true,rt.nativeCompleted==true
    row.inputsConsumed=rt.nativeAttempted==true and collector.payment(rt)
    row.toolRetained=craftCarried(rt.body,w.toolItemId,w.toolItemType)==rt.tool and ownItem(rt,rt.tool);row.parts={}
    if rt.nativeCompleted then
        for _,part in ipairs(rt.builder.saoCreatedParts) do row.parts[#row.parts+1]={x=part:getX(),y=part:getY(),z=part:getZ(),sprite=part:getSpriteName(),objectIndex=part:getObjectIndex()} end
        bed.refresh(rt,row)
    end
    if row.status=="completed" and (not row.toolRetained or not bed.bound(rt,false)) then row.status="failed" end
    row.nativeCredit=row.status=="completed" and w.id or nil
    if not bed.outcome(rt.id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rt.logic:stopCraftAction();rec.resourceProductionWork=nil;rt.closed=true;plumbDispose(rt);reconcile(rt.id);return true
end
function bed.destination(rt)
    return {x=rt.site.approachX+.5,y=rt.site.approachY+.5,z=rt.site.approachZ}
end
function bed.queue(rt)
    local w,body,policy,id=rt.work,rt.body,rt.policy,rt.id
    local sq=SAOJavaBridge:worldBedPlacementSquare(body,w.siteX,w.siteY,w.siteZ,w.face,w.siteRevision)
    if not sq then return false end
    rt.siteSquare,rt.square,rt.x,rt.y=sq,body:getCurrentSquare(),body:getX(),body:getY();w.stage="preparing"
    rt.builder=collector.newEntity(rt,rt.containers);rt.sprite=rt.builder:getSprite()
    local face=rt.builder:getFace()
    for x=0,face:getWidth()-1 do for y=0,face:getHeight()-1 do
        local square=rt.cell:getGridSquare(w.siteX+x,w.siteY+y,w.siteZ)
        if not square then return false end;local objects=square:getObjects()
        for i=0,objects:size()-1 do rt.beforeObjects[objects:get(i)]=true end
    end end
    for _,material in ipairs(rt.materials) do if material:getContainer()~=rt.inventory then
        plumbGuard(rt,ISInventoryTransferAction:new(body,material,material:getContainer(),rt.inventory),"transfer",material)
    end end
    if body:getPrimaryHandItem()~=rt.tool then plumbGuard(rt,ISEquipWeaponAction:new(body,rt.tool,50,true,false),"equip",rt.tool) end
    local a=ISBuildAction:new(body,rt.builder,w.siteX,w.siteY,w.siteZ,rt.builder.north,rt.sprite,policy.recipe:getTime(body))
    if rt.logic:getPossibleCraftCount(true)<1 then return false end
    rt.logic:startCraftAction(a);plumbGuard(rt,a,"collector",rt.tool)
    return bed.bound(rt,true) and plumbEnqueue(rt,1)
end
function bed.begin(id,body,step,context)
    local rec,t=owner(id,body),now();local policy=rec and bed.recipe(body)
    if not policy or not t or not craftLedger(rec) or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) or step.recipeId~=policy.recipeId
        or step.owner~="SAO.ResourceProduction" or step.token~="resource:bed-built" or step.category~="construction"
        or step.entityId~="Base.Wood_Bed" or not bed.site(id,body,step.site) then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or not p.bedConstruction or p.bedConstruction.constructedWorkId or p.admission
        or p.steps[p.cursor]~=step or step.id~=context.purposeStepId then return false end
    local selected=collector.inputs(policy,body)
    if #selected~=12 or not collector.rowsEqual(selected,step.inputs) or not collector.rowsEqual(policy.requirements,step.requirements) then return false end
    local route=SAO.Locomotion.jobs[id];if route and not route.done then return false end
    local world=getWorld();if not world then return false end
    local rt={kind="build-wood-bed",id=id,record=rec,body=body,policy=policy,inputs=collector.copy(selected),materials={},
        site=collector.copy(step.site),inventory=body:getInventory(),square=body:getCurrentSquare(),x=body:getX(),y=body:getY(),
        world=world:getWorld(),cell=body:getCell(),queue=ISTimedActionQueue.getTimedActionQueue(body),
        token=body:getModData().SAOExternalToken,startedAt=t,actions={},beforeObjects={}}
    local containers=ArrayList.new();containers:add(rt.inventory)
    local logic=BuildLogic.new(body,nil,nil);logic:setContainers(containers);logic:setRecipe(policy.recipe);logic:setManualSelectInputs(true);logic:clearManualInputs()
    for _,r in ipairs(policy.requirements) do local manual=ArrayList.new()
        for _,row in ipairs(selected) do if row.inputIndex==r.inputIndex then
            local material=craftCarried(body,row.itemId,row.itemType);if not material then return false end
            if material:getContainer()~=rt.inventory and not containers:contains(material:getContainer()) then containers:add(material:getContainer()) end
            manual:add(material);rt.materials[#rt.materials+1]=material
        end end
        if manual:size()~=r.count or logic:setManualInputsFor(policy.recipe:getInputs():get(r.inputIndex),manual)~=true then return false end
    end
    if not logic:canPerformCurrentRecipe() then return false end
    rt.logic,rt.tool,rt.containers=logic,rt.materials[1],containers;rt.toolId,rt.toolType=selected[1].itemId,selected[1].itemType
    local seq=(rec.resourceProductionSequence or 0)+1
    local needs=SAO.Needs.read(body) or {};local ok,health=pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    local w={id="resource-production/"..id.."/"..seq,sequence=seq,actorId=id,kind=rt.kind,category="construction",token="resource:bed-built",
        purposeId=context.purposeId,purposeStepId=context.purposeStepId,requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,
        toolCategory="hammer",toolItemId=rt.toolId,toolItemType=rt.toolType,entityId="Base.Wood_Bed",recipeId=policy.recipeId,
        requirements=collector.copy(policy.requirements),inputs=collector.copy(selected),site=collector.copy(rt.site),
        siteKey=rt.site.key,siteRevision=rt.site.revision,siteX=rt.site.x,siteY=rt.site.y,siteZ=rt.site.z,siteObservedAtHours=rt.site.observedAtHours,face=rt.site.face,
        world=rt.world,bodyToken=rt.token,startedAt=t,status="constructing",stage="approaching",
        admittedNeeds={hunger=tonumber(needs.hunger),thirst=tonumber(needs.thirst),fatigue=tonumber(needs.fatigue)},admittedHealth=ok and tonumber(health) or nil}
    rt.work,rt.workId=w,w.id
    if not bed.identity(id,w) then return false end
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,w,rt
    if not SAO.ProceduralPlanning.admitBedConstruction(id,w) then rec.resourceProductionWork=nil;plumbDispose(rt);return false end
    rt.purpose,rt.step=bed.purpose(rec,w)
    if bed.queue(rt) then return true end
    local destination=bed.destination(rt)
    if SAO.Standing.mayAttemptBelieved(id,destination.x,destination.y,"standing")
        and SAO.Locomotion.order(id,body,destination.x,destination.y,destination.z) then
        rt.route=SAO.Locomotion.jobs[id];if rt.route and rt.route.body==body then return true end
    end
    plumbInterrupt(id,body,"native-bed-approach-refused");return false
end

-- Observed wooden wall and door stages share this exact native construction claim.
shelter={}
shelter.entities={"Base.WoodenWallFrame","Base.WoodenWallLvl1","Base.WoodenWallLvl2","Base.WoodenWallLvl3",
    "Base.WoodDoorFrameLvl1","Base.WoodDoorFrameLvl2","Base.WoodDoorFrameLvl3",
    "Base.WoodenDoorLvl1","Base.WoodenDoorLvl2","Base.WoodenDoorLvl3"}
function shelter.spec(entityId)
    for i,name in ipairs(shelter.entities) do if name==entityId then
        local category=i==1 and "wall-frame" or i<=4 and "wall" or i<=7 and "door-frame" or "door-leaf"
        local counts=i==1 and {1,2,2} or i<=4 and {1,2,4} or i<=7 and {1,4,4} or {1,4,4,2,1}
        return category,counts
    end end
end
function shelter.recipe(body,entityId)
    local kind,counts=shelter.spec(entityId);if not kind or not collector.install() then return nil end
    local infos=SpriteConfigManager.GetObjectInfoList()
    for i=0,infos:size()-1 do
        local info=infos:get(i);local script=info:getScript()
        if script and script:getParent():getScriptObjectFullType()==entityId and info:getRecipe() then
            local recipe=info:getRecipe():getCraftRecipe()
            if not recipe or not CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body) or script:isProp() then return nil end
            for j=0,recipe:getRequiredSkillCount()-1 do
                if not CraftRecipeManager.hasPlayerRequiredSkill(recipe:getRequiredSkill(j),body) then return nil end
            end
            if recipe:getInputs():size()~=#counts then return nil end
            local requirements={}
            for index,count in ipairs(counts) do
                local input=recipe:getInputs():get(index-1)
                if input:getResourceType()~=ResourceType.Item or input:getIntAmount()~=count or input:isKeep()~=(index==1) then return nil end
                requirements[#requirements+1]={inputIndex=index-1,category=({"hammer","plank","nails","hinge","doorknob"})[index],
                    count=count,mode=input:isKeep() and "keep" or "consume"}
            end
            for _,name in ipairs({"N","W"}) do local face=info:getFace(name)
                if not face or face:getWidth()~=1 or face:getHeight()~=1 or face:getzLayers()~=1 then return nil end
            end
            return {info=info,recipe=recipe,recipeId=recipe:getScriptObjectFullType(),entityId=entityId,kind=kind,shelterEdge=true,requirements=requirements}
        end
    end
end
function shelter.sameSite(a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    for _,key in ipairs({"key","revision","x","y","z","face","approachX","approachY","approachZ","insideX","insideY",
        "originX","originY","mode","previousEntity","actorId","observed","roof","observedAtHours","source"}) do
        if a[key]~=b[key] then return false end
    end
    return true
end
function shelter.site(id,body,site)
    if type(site)~="table" or site.actorId~=id or site.observed~=true or site.roof~=true
        or not textId(site.key) or not textId(site.revision) or not finite(site.observedAtHours)
        or site.observedAtHours>now() or site.observedAtHours<0 or site.face~="N" and site.face~="W" then return false end
    for _,known in ipairs(SAO.Perception.shelterSites(id,body) or {}) do
        if known.key==site.key and known.revision==site.revision and known.face==site.face
            and known.mode==site.mode and known.observedAtHours>=site.observedAtHours then
            for _,key in ipairs({"x","y","z","approachX","approachY","approachZ","insideX","insideY","originX","originY"}) do
                if site[key]~=known[key] then return false end
            end
            return true
        end
    end
    return false
end
function R.shelterOptions(id,body,retained)
    local ok,out=pcall(function()
        if not owner(id,body) or not SAO.Perception.shelterSites then return {} end
        local policies={};for _,entityId in ipairs(shelter.entities) do
            local policy=shelter.recipe(body,entityId);if policy then
                policy.inputs=collector.inputs(policy,body);policies[#policies+1]=policy
            end
        end
        local out={};local built=retained and retained.completedEdges or {}
        for _,site in ipairs(SAO.Perception.shelterSites(id,body)) do
            if (not retained or not retained.stageHistory[site.key] or retained.stageHistory[site.key].revision~=site.revision)
                and (not built[site.key] or site.previousEntity~=built[site.key]) and shelter.site(id,body,site)
                and SAO.Standing.mayAttemptBelieved(id,site.x,site.y,"standing")==true
                and SAO.Standing.mayAttemptBelieved(id,site.approachX,site.approachY,"standing")==true then
                for _,policy in ipairs(policies) do if policy.kind==site.mode then
                    out[#out+1]={kind="build-shelter-edge",known=true,entityId=policy.entityId,recipeId=policy.recipeId,
                        requirements=collector.copy(policy.requirements),inputs=collector.copy(policy.inputs),site=collector.copy(site),
                        distance=math.sqrt((body:getX()-site.approachX-.5)^2+(body:getY()-site.approachY-.5)^2)}
                    if #out>=32 then return out end
                end end
            end
        end
        return out
    end)
    if not ok and SAO.Log and SAO.Log.line then SAO.Log.line("RESOURCE","native shelter means unavailable: "..tostring(out)) end
    return ok and out or {}
end
local SHELTER_FIELDS={}
for _,key in ipairs({"id","workId","sequence","actorId","kind","category","token","entityId","recipeId",
    "purposeId","purposeStepId","requestedPurposeId","requestedPurposeStepId","toolCategory","toolItemId","toolItemType",
    "requirements","inputs","site","siteKey","siteRevision","siteObservedAtHours","siteX","siteY","siteZ","face",
    "world","bodyToken","startedAt","stage","status","admittedNeeds","admittedHealth","nativeOwner","detail","atHours","endedAt",
    "nativeAttempted","nativeCompleted","constructed","placed","exactInputs","inputsConsumed","toolRetained","nativeCredit",
    "parts","doorKey","sourceObservation","nativeObservability","purposeDelivered","experienceDelivered"}) do SHELTER_FIELDS[key]=true end
function shelter.identity(id,w)
    local kind,counts;if type(w)=="table" then kind,counts=shelter.spec(w.entityId) end
    if type(w)~="table" or getmetatable(w) or not kind or w.actorId~=id or w.kind~="build-shelter-edge"
        or w.category~="construction" or w.token~="resource:shelter-built" or not textId(w.recipeId)
        or not integer(w.sequence) or w.sequence<1 or w.id~="resource-production/"..id.."/"..w.sequence
        or not textId(w.purposeId) or not textId(w.purposeStepId) or not textId(w.world)
        or w.bodyToken~=nil and not textId(w.bodyToken) or not finite(w.startedAt) or w.startedAt<0
        or w.toolCategory~="hammer" or not textId(w.toolItemId) or not textId(w.toolItemType)
        or not textId(w.siteKey) or not textId(w.siteRevision) or not finite(w.siteObservedAtHours)
        or w.siteObservedAtHours>w.startedAt or w.siteObservedAtHours<0 or w.face~="N" and w.face~="W"
        or type(w.site)~="table" or w.site.key~=w.siteKey or w.site.revision~=w.siteRevision
        or w.site.face~=w.face or w.site.x~=w.siteX or w.site.y~=w.siteY or w.site.z~=w.siteZ
        or type(w.inputs)~="table" or getmetatable(w.inputs) or #w.inputs>16
        or type(w.requirements)~="table" or getmetatable(w.requirements) or #w.requirements~=#counts then return false end
    for key in pairs(w) do if not SHELTER_FIELDS[key] then return false end end
    for _,key in ipairs({"siteX","siteY","siteZ"}) do if not finite(w[key]) or w[key]%1~=0 then return false end end
    local seen,numbers={},{}
    for _,row in ipairs(w.inputs) do
        if type(row)~="table" or getmetatable(row) or not integer(row.inputIndex) or row.inputIndex>=#counts
            or not textId(row.itemId) or not textId(row.itemType) or seen[row.itemId]
            or row.mode~=(row.inputIndex==0 and "keep" or "consume") then return false end
        local expected=({"Base.Plank","Base.Nails","Base.Hinge","Base.Doorknob"})[row.inputIndex]
        if row.inputIndex>0 and row.itemType~=expected then return false end
        seen[row.itemId]=true;numbers[row.inputIndex]=(numbers[row.inputIndex] or 0)+1
    end
    for i,count in ipairs(counts) do local req=w.requirements[i]
        if req.inputIndex~=i-1 or req.count~=count or numbers[i-1]~=count
            or req.category~=({"hammer","plank","nails","hinge","doorknob"})[i]
            or req.mode~=(i==1 and "keep" or "consume") then return false end
    end
    return w.inputs[1].itemId==w.toolItemId and w.inputs[1].itemType==w.toolItemType and collector.copy(w)~=nil
end
function shelter.purpose(rec,w)
    local planning=rec and rec.proceduralPlanning;local p=planning and planning.purposes[w.purposeId]
    local step=p and p.steps[p.cursor];local a=p and p.admission
    if not p or not p.shelterConstruction or not p.shelterConstruction.recoveryKind
        or p.status=="completed" or p.status=="abandoned" or not step or not a or step.owner~="SAO.ResourceProduction"
        or step.productionKind~=w.kind or step.token~=w.token or step.id~=w.purposeStepId or step.target~=w.entityId
        or step.entityId~=w.entityId or step.recipeId~=w.recipeId or a.owner~=step.owner or a.stepId~=step.id
        or a.correlationId~=w.id or a.target~=step.target or not finite(a.at) or a.at<w.startedAt
        or not collector.rowsEqual(step.inputs,w.inputs) or not collector.rowsEqual(step.requirements,w.requirements)
        or not shelter.sameSite(step.site,w.site) then return nil end
    for _,key in ipairs({"key","revision","x","y","z","face","approachX","approachY","approachZ","observedAtHours"}) do
        if step.site[key]~=w.site[key] then return nil end
    end
    return p,step
end
function shelter.anchors(rt,w)
    return shelter.sameSite(w.site,rt.site) and w.recipeId==rt.policy.recipeId and w.entityId==rt.policy.entityId and w.siteKey==rt.site.key and w.siteRevision==rt.site.revision
        and w.siteX==rt.site.x and w.siteY==rt.site.y and w.siteZ==rt.site.z and w.face==rt.site.face
        and w.siteObservedAtHours==rt.site.observedAtHours and collector.rowsEqual(w.inputs,rt.inputs)
        and collector.rowsEqual(w.requirements,rt.policy.requirements)
end
function shelter.bound(rt,pre)
    local body,w=rt.body,rt.work;local rec=owner(rt.id,body);local p,step=shelter.purpose(rec,w);local world=getWorld()
    if not body or rt.closed or rt.cancelling or runtime[rt.id]~=rt or rec~=rt.record or rec.resourceProductionWork~=w
        or not shelter.identity(rt.id,w) or not craftLedger(rec) or not shelter.anchors(rt,w) or w.id~=rt.workId or w.startedAt~=rt.startedAt
        or w.bodyToken~=rt.token or body:getModData().SAOExternalToken~=rt.token or w.world~=rt.world
        or not now() or now()<rt.startedAt or not world or world:getWorld()~=rt.world or world:getCell()~=rt.cell
        or body:getCell()~=rt.cell or body:getInventory()~=rt.inventory or ISTimedActionQueue.getTimedActionQueue(body)~=rt.queue
        or p~=rt.purpose or step~=rt.step or not shelter.site(rt.id,body,rt.site)
        or w.stage~="approaching" and (body:getCurrentSquare()~=rt.square or math.abs(body:getX()-rt.x)>.01 or math.abs(body:getY()-rt.y)>.01) then return false end
    local width,height=1,1
    for x=0,width-1 do for y=0,height-1 do if SAO.Standing.mayTakeCurrent(rt.id,w.siteX+x,w.siteY+y,"standing")~=true then return false end end end
    if SAO.Standing.mayTakeCurrent(rt.id,rt.site.approachX,rt.site.approachY,"standing")~=true then return false end
    if not pre then return true end
    if w.stage~="approaching" and SAOJavaBridge:worldShelterPreviousStage(body,w.siteKey,w.siteRevision)~=rt.observedStage then return false end
    if rt.nativeAttempted or body:isBuildCheat() or isClient() or isServer() then return false end
    if w.stage~="approaching" and SAOJavaBridge:worldShelterPlacementSquare(body,w.siteKey,w.siteRevision)~=rt.siteSquare then return false end
    for i,row in ipairs(rt.inputs) do local item=rt.materials[i]
        if craftCarried(body,row.itemId,row.itemType)~=item or not ownItem(rt,item) or item:getIsCraftingConsumed()
            or not ISBuildIsoEntity.predicateMaterial(item)
            or CraftRecipeManager.getValidInputScriptForItem(rt.policy.recipe,item,body)~=rt.policy.recipe:getInputs():get(row.inputIndex)
            or row.mode=="keep" and (item:isBroken() or item:getCondition()<=0 or item:isRequiresEquippedBothHands()) then return false end
    end
    return true
end
function shelter.partExpected(rt,square,sprite)
    local face=rt.builder:getFace()
    for x=0,face:getWidth()-1 do for y=0,face:getHeight()-1 do
        local info=face:getTileInfo(x,y,0)
        if square==rt.cell:getGridSquare(rt.site.x+x,rt.site.y+y,rt.site.z) and info and sprite==info:getSpriteName() then return true end
    end end
    return false
end
function shelter.measure(rt)
    local parts=rt.builder.saoCreatedParts or {}
    if #parts~=1 or rt.beforeObjects[parts[1]]
        or SAOJavaBridge:worldShelterCreated(rt.body,parts[1],rt.previous,rt.policy.entityId,rt.site.x,rt.site.y,rt.site.z,rt.site.face)~=true then return false end
    if rt.frame and (rt.frame:getSquare()~=rt.siteSquare or not rt.siteSquare:getObjects():contains(rt.frame)) then return false end
    return collector.payment(rt)
end
function shelter.refresh(rt,row)
    row.sourceObservation={status="measured",detail="observed-native-shelter-edge",atHours=now()}
end
function shelter.outcome(id,row)
    local rec,t=SAO.Identity.get(id),now()
    if not craftLedger(rec) or not shelter.identity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISBuildAction" or not t or not finite(row.atHours)
        or row.atHours<row.startedAt or row.atHours>t or row.endedAt~=row.atHours
        or row.status~="completed" and row.status~="failed" and row.status~="interrupted" then return nil end
    for _,key in ipairs({"nativeAttempted","nativeCompleted","constructed","placed","exactInputs","inputsConsumed","toolRetained"}) do
        if type(row[key])~="boolean" then return nil end
    end
    if type(row.parts)~="table" or getmetatable(row.parts) or #row.parts>1 then return nil end
    if row.status=="completed" then
        if not row.nativeAttempted or not row.nativeCompleted or not row.constructed or not row.placed
            or not row.exactInputs or not row.inputsConsumed or not row.toolRetained or row.nativeCredit~=row.id or #row.parts~=1 then return nil end
        local part=row.parts[1]
        if type(part)~="table" or part.x~=row.siteX or part.y~=row.siteY or part.z~=row.siteZ
            or not textId(part.sprite) or not integer(part.objectIndex) then return nil end
    elseif row.nativeCredit~=nil then return nil end
    if row.nativeObservability~=nil and (row.nativeObservability~="runtime-unavailable" or row.status~="interrupted"
        or row.nativeAttempted or row.nativeCompleted or row.constructed or row.placed or row.inputsConsumed or row.toolRetained
        or #row.parts~=0 or row.doorKey~=nil) then return nil end
    if row.doorKey~=nil and (not textId(row.doorKey) or type(row.sourceObservation)~="table"
        or row.sourceObservation.status~="confirmed" or row.sourceObservation.key~=row.doorKey) then return nil end
    return collector.copy(row)
end
function shelter.close(rt,status,detail)
    if rt.closed then return true end
    local rec,w,t=SAO.Identity.get(rt.id),rt.work,now()
    if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not shelter.identity(rt.id,w)
        or not shelter.purpose(rec,w) or not shelter.anchors(rt,w) or not craftLedger(rec) or not t or t<w.startedAt then return false end
    local rows=rec.resourceProductionOutcomes or {}
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row=collector.copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISBuildAction",status,detail,t,t
    row.nativeAttempted,row.nativeCompleted=rt.nativeAttempted==true,rt.nativeCompleted==true
    row.exactInputs=true;row.constructed,row.placed=rt.nativeCompleted==true,rt.nativeCompleted==true
    row.inputsConsumed=rt.nativeAttempted==true and collector.payment(rt)
    row.toolRetained=craftCarried(rt.body,w.toolItemId,w.toolItemType)==rt.tool and ownItem(rt,rt.tool);row.parts={}
    if rt.nativeCompleted then
        for _,part in ipairs(rt.builder.saoCreatedParts) do row.parts[#row.parts+1]={x=part:getX(),y=part:getY(),z=part:getZ(),sprite=part:getSpriteName(),objectIndex=part:getObjectIndex()} end
        shelter.refresh(rt,row)
    end
    if row.status=="completed" and (not row.toolRetained or not shelter.bound(rt,false)) then row.status="failed" end
    row.nativeCredit=row.status=="completed" and w.id or nil
    if not shelter.outcome(rt.id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rt.logic:stopCraftAction();rec.resourceProductionWork=nil;rt.closed=true
    if row.status=="completed" then SAO.Perception.observeShelterSites(rt.id,rt.body,rt.site) end
    plumbDispose(rt);reconcile(rt.id);return true
end
function shelter.destination(rt)
    return {x=rt.site.approachX+.5,y=rt.site.approachY+.5,z=rt.site.approachZ}
end
function shelter.queue(rt)
    local w,body,policy,id=rt.work,rt.body,rt.policy,rt.id
    local sq=SAOJavaBridge:worldShelterPlacementSquare(body,w.siteKey,w.siteRevision)
    if not sq then return false end
    rt.siteSquare,rt.square,rt.x,rt.y=sq,body:getCurrentSquare(),body:getX(),body:getY();w.stage="preparing"
    local observed=SAOJavaBridge:worldShelterPreviousStage(body,w.siteKey,w.siteRevision)
    rt.observedStage=observed;rt.previous=policy.kind=="wall" and observed or nil;rt.frame=policy.kind=="door-leaf" and observed or nil
    rt.builder=collector.newEntity(rt,rt.containers);rt.sprite=rt.builder:getSprite()
    if rt.builder:isValid(sq)~=true or rt.builder.previousStageObject~=rt.previous then return false end
    local face=rt.builder:getFace()
    for x=0,face:getWidth()-1 do for y=0,face:getHeight()-1 do
        local square=rt.cell:getGridSquare(w.siteX+x,w.siteY+y,w.siteZ)
        if not square then return false end;local objects=square:getObjects()
        for i=0,objects:size()-1 do rt.beforeObjects[objects:get(i)]=true end
    end end
    for _,material in ipairs(rt.materials) do if material:getContainer()~=rt.inventory then
        plumbGuard(rt,ISInventoryTransferAction:new(body,material,material:getContainer(),rt.inventory),"transfer",material)
    end end
    if body:getPrimaryHandItem()~=rt.tool then plumbGuard(rt,ISEquipWeaponAction:new(body,rt.tool,50,true,false),"equip",rt.tool) end
    local a=ISBuildAction:new(body,rt.builder,w.siteX,w.siteY,w.siteZ,rt.builder.north,rt.sprite,policy.recipe:getTime(body))
    if rt.logic:getPossibleCraftCount(true)<1 then return false end
    rt.logic:startCraftAction(a);plumbGuard(rt,a,"collector",rt.tool)
    return shelter.bound(rt,true) and plumbEnqueue(rt,1)
end
function shelter.begin(id,body,step,context)
    local rec,t=owner(id,body),now();local policy=rec and shelter.recipe(body,step.entityId)
    if not policy or not t or not craftLedger(rec) or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) or step.recipeId~=policy.recipeId
        or step.owner~="SAO.ResourceProduction" or step.token~="resource:shelter-built" or step.category~="construction"
        or not shelter.spec(step.entityId) or not shelter.site(id,body,step.site) then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or not p.shelterConstruction or p.admission
        or p.steps[p.cursor]~=step or step.id~=context.purposeStepId then return false end
    local selected=collector.inputs(policy,body)
    if not SAO.ProceduralPlanning.collectorReady({requirements=policy.requirements,inputs=selected}) or not collector.rowsEqual(selected,step.inputs) or not collector.rowsEqual(policy.requirements,step.requirements) then return false end
    local route=SAO.Locomotion.jobs[id];if route and not route.done then return false end
    local world=getWorld();if not world then return false end
    local rt={kind="build-shelter-edge",id=id,record=rec,body=body,policy=policy,inputs=collector.copy(selected),materials={},
        site=collector.copy(step.site),inventory=body:getInventory(),square=body:getCurrentSquare(),x=body:getX(),y=body:getY(),
        world=world:getWorld(),cell=body:getCell(),queue=ISTimedActionQueue.getTimedActionQueue(body),
        token=body:getModData().SAOExternalToken,startedAt=t,actions={},beforeObjects={}}
    local containers=ArrayList.new();containers:add(rt.inventory)
    local logic=BuildLogic.new(body,nil,nil);logic:setContainers(containers);logic:setRecipe(policy.recipe);logic:setManualSelectInputs(true);logic:clearManualInputs()
    for _,r in ipairs(policy.requirements) do local manual=ArrayList.new()
        for _,row in ipairs(selected) do if row.inputIndex==r.inputIndex then
            local material=craftCarried(body,row.itemId,row.itemType);if not material then return false end
            if material:getContainer()~=rt.inventory and not containers:contains(material:getContainer()) then containers:add(material:getContainer()) end
            manual:add(material);rt.materials[#rt.materials+1]=material
        end end
        if manual:size()~=r.count or logic:setManualInputsFor(policy.recipe:getInputs():get(r.inputIndex),manual)~=true then return false end
    end
    if not logic:canPerformCurrentRecipe() then return false end
    rt.logic,rt.tool,rt.containers=logic,rt.materials[1],containers;rt.toolId,rt.toolType=selected[1].itemId,selected[1].itemType
    local seq=(rec.resourceProductionSequence or 0)+1
    local needs=SAO.Needs.read(body) or {};local ok,health=pcall(function() return body:getBodyDamage():getOverallBodyHealth() end)
    local w={id="resource-production/"..id.."/"..seq,sequence=seq,actorId=id,kind=rt.kind,category="construction",token="resource:shelter-built",
        purposeId=context.purposeId,purposeStepId=context.purposeStepId,requestedPurposeId=context.purposeId,requestedPurposeStepId=context.purposeStepId,
        toolCategory="hammer",toolItemId=rt.toolId,toolItemType=rt.toolType,entityId=step.entityId,recipeId=policy.recipeId,
        requirements=collector.copy(policy.requirements),inputs=collector.copy(selected),site=collector.copy(rt.site),
        siteKey=rt.site.key,siteRevision=rt.site.revision,siteX=rt.site.x,siteY=rt.site.y,siteZ=rt.site.z,siteObservedAtHours=rt.site.observedAtHours,face=rt.site.face,
        world=rt.world,bodyToken=rt.token,startedAt=t,status="constructing",stage="approaching",
        admittedNeeds={hunger=tonumber(needs.hunger),thirst=tonumber(needs.thirst),fatigue=tonumber(needs.fatigue)},admittedHealth=ok and tonumber(health) or nil}
    rt.work,rt.workId=w,w.id
    if not shelter.identity(id,w) then return false end
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,w,rt
    if not SAO.ProceduralPlanning.admitShelterConstruction(id,w) then rec.resourceProductionWork=nil;plumbDispose(rt);return false end
    rt.purpose,rt.step=shelter.purpose(rec,w)
    if shelter.queue(rt) then return true end
    local destination=shelter.destination(rt)
    if SAO.Standing.mayAttemptBelieved(id,destination.x,destination.y,"standing")
        and SAO.Locomotion.order(id,body,destination.x,destination.y,destination.z) then
        rt.route=SAO.Locomotion.jobs[id];if rt.route and rt.route.body==body then return true end
    end
    plumbInterrupt(id,body,"native-bed-approach-refused");return false
end

-- Native doorway use remains a separate result from the paid edge construction.
function shelter.useIdentity(id,w)
    if type(w)~="table" or getmetatable(w) or w.actorId~=id or w.kind~="use-shelter"
        or w.category~="construction" or w.token~="resource:shelter-used" or not integer(w.sequence) or w.sequence<1
        or w.id~="resource-production/"..id.."/"..w.sequence or not textId(w.purposeId) or not textId(w.purposeStepId)
        or not textId(w.world) or w.bodyToken~=nil and not textId(w.bodyToken) or not finite(w.startedAt) or w.startedAt<0
        or not textId(w.siteKey) or not textId(w.siteRevision) or type(w.site)~="table"
        or w.site.key~=w.siteKey or w.site.revision~=w.siteRevision or w.site.mode~="door"
        or w.site.actorId~=id or w.site.roof~=true or w.site.face~="N" and w.site.face~="W" then return false end
    local allowed={id=true,sequence=true,actorId=true,kind=true,category=true,token=true,purposeId=true,purposeStepId=true,
        site=true,siteKey=true,siteRevision=true,world=true,bodyToken=true,startedAt=true,status=true,stage=true,
        admittedNeeds=true,admittedHealth=true,beforeCover=true,afterCover=true,workId=true,nativeOwner=true,
        atHours=true,endedAt=true,detail=true,nativeAttempted=true,nativeCompleted=true,nativeCredit=true,
        opened=true,crossedOut=true,crossedIn=true,closedDoor=true,enclosureConfirmed=true,nativeObservability=true,
        purposeDelivered=true,experienceDelivered=true}
    for key in pairs(w) do if not allowed[key] then return false end end
    return collector.copy(w)~=nil
end
function shelter.usePurpose(rec,w)
    local p=rec and rec.proceduralPlanning and rec.proceduralPlanning.purposes[w.purposeId]
    local step,ad=p and p.steps[p.cursor],p and p.admission
    if not p or not p.shelterConstruction or p.status=="completed" or p.status=="abandoned"
        or not step or not ad or step.owner~="SAO.ResourceProduction" or step.productionKind~="use-shelter"
        or step.id~=w.purposeStepId or step.site.key~=w.siteKey or step.site.revision~=w.siteRevision
        or not shelter.sameSite(step.site,w.site) or ad.owner~=step.owner or ad.stepId~=step.id or ad.correlationId~=w.id or ad.target~=step.target then return nil end
    return p,step
end
function shelter.useAnchors(rt,w)
    return w.id==rt.workId and w.startedAt==rt.startedAt and w.bodyToken==rt.token and w.world==rt.world
        and w.siteKey==rt.site.key and w.siteRevision==rt.site.revision and shelter.sameSite(w.site,rt.site)
end
function shelter.useBound(rt)
    local body,w=rt.body,rt.work;local rec=owner(rt.id,body);local p,step=shelter.usePurpose(rec,w);local world=getWorld()
    if not body or rt.closed or rt.cancelling or runtime[rt.id]~=rt or rec~=rt.record or rec.resourceProductionWork~=w
        or not shelter.useIdentity(rt.id,w) or not craftLedger(rec) or not shelter.useAnchors(rt,w)
        or not world or world:getWorld()~=rt.world or world:getCell()~=rt.cell or body:getCell()~=rt.cell
        or body:getModData().SAOExternalToken~=rt.token or ISTimedActionQueue.getTimedActionQueue(body)~=rt.queue
        or p~=rt.purpose or step~=rt.step or not now() or now()<rt.startedAt
        or not rt.door or rt.door:getObjectIndex()<0 or rt.door:isDestroyed()
        or not (instanceof(rt.door,"IsoDoor") or instanceof(rt.door,"IsoThumpable") and rt.door:isDoor())
        or rt.door:getSquare()~=rt.siteSquare or rt.door:getNorth()~=(rt.site.face=="N") then return false end
    for _,point in ipairs({{rt.site.x,rt.site.y},{rt.site.approachX,rt.site.approachY},{rt.site.insideX,rt.site.insideY},
        {rt.outX,rt.outY}}) do
        if SAO.Standing.mayTakeCurrent(rt.id,point[1],point[2],"standing")~=true then return false end
    end
    return true
end
function shelter.doorExact(rt,a)
    return a.item==rt.door and a.character==rt.body and rt.door:IsOpen()==a.saoBeforeOpen
        and (rt.work.stage=="opening" or rt.work.stage=="closing" or rt.work.stage=="closing-initial")
        and math.min((rt.body:getX()-rt.site.x-.5)^2+(rt.body:getY()-rt.site.y-.5)^2,
            (rt.body:getX()-rt.otherX-.5)^2+(rt.body:getY()-rt.otherY-.5)^2)<=.13
end
function shelter.useRoute(rt,x,y,stage)
    if stage=="crossing-out" or stage=="crossing-in" then
        rt.passageToken=SAOJavaBridge:worldShelterBeginPassage(rt.body,rt.door,rt.site.key,rt.site.revision,stage=="crossing-in")
        if not textId(rt.passageToken) then return false end
    end
    if not shelter.useBound(rt) or rt.queue.current or #rt.queue.queue>0
        or not SAO.Locomotion.order(rt.id,rt.body,x+.5,y+.5,rt.site.z) then return false end
    rt.route=SAO.Locomotion.jobs[rt.id]
    if not rt.route or rt.route.body~=rt.body then return false end
    rt.route.shelterWorkId=rt.workId;rt.work.stage=stage;return true
end
function shelter.useDoor(rt,want,stage)
    if not shelter.useBound(rt) or rt.queue.current or #rt.queue.queue>0 or rt.door:IsOpen()==want then return false end
    local action=ISOpenCloseDoor:new(rt.body,rt.door)
    action.saoBeforeOpen,action.saoWantOpen=rt.door:IsOpen(),want
    rt.work.stage=stage;plumbGuard(rt,action,"shelter-door",rt.door)
    rt.current,rt.action=rt.actions[#rt.actions],action
    return SAO.Needs.queueVerified(action)==true
end
function shelter.doorFinished(rt,a,success)
    rt.nativeAttempted=true
    if not success or not shelter.useBound(rt) or rt.door:IsOpen()~=a.saoWantOpen then
        return plumbInterrupt(rt.id,rt.body,"native-door-toggle-not-observed")
    end
    if rt.work.stage=="closing-initial" then return shelter.useDoor(rt,true,"opening") end
    if rt.work.stage=="opening" then
        rt.opened=true
        return shelter.useRoute(rt,rt.outX,rt.outY,"crossing-out") or plumbInterrupt(rt.id,rt.body,"shelter-exit-route-refused")
    end
    rt.closedDoor=true;rt.work.stage="awaiting-native-enclosure";return true
end
function shelter.useOutcome(id,row)
    local rec,t=SAO.Identity.get(id),now()
    if not craftLedger(rec) or not shelter.useIdentity(id,row) or row.sequence>rec.resourceProductionSequence
        or row.workId~=row.id or row.nativeOwner~="ISOpenCloseDoor+SAO.Locomotion" or not finite(row.atHours)
        or row.atHours<row.startedAt or not t or row.atHours>t or row.endedAt~=row.atHours
        or row.status~="completed" and row.status~="failed" and row.status~="interrupted" then return nil end
    for _,key in ipairs({"nativeAttempted","nativeCompleted","opened","crossedOut","crossedIn","closedDoor","enclosureConfirmed"}) do
        if type(row[key])~="boolean" then return nil end
    end
    if row.status=="completed" then
        local cover=row.afterCover
        if not row.nativeAttempted or not row.nativeCompleted or not row.opened or not row.crossedOut or not row.crossedIn
            or not row.closedDoor or not row.enclosureConfirmed or row.nativeCredit~=row.id or type(cover)~="table"
            or cover.reached~=true or cover.roof~=true or cover.regionKnown~=true or cover.enclosed~=true or cover.fullyRoofed~=true then return nil end
    elseif row.nativeCredit~=nil then return nil end
    if row.nativeObservability~=nil and (row.nativeObservability~="runtime-unavailable" or row.status~="interrupted"
        or row.nativeAttempted or row.nativeCompleted or row.opened or row.crossedOut or row.crossedIn or row.closedDoor
        or row.enclosureConfirmed) then return nil end
    return collector.copy(row)
end
function shelter.useClose(rt,status,detail)
    if rt.closed then return true end
    local rec,w,t=SAO.Identity.get(rt.id),rt.work,now()
    if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not shelter.useIdentity(rt.id,w)
        or not shelter.usePurpose(rec,w) or not shelter.useAnchors(rt,w) or not t or t<w.startedAt then return false end
    local rows=rec.resourceProductionOutcomes or {}
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row=collector.copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISOpenCloseDoor+SAO.Locomotion",status,detail,t,t
    row.nativeAttempted,row.nativeCompleted=rt.nativeAttempted==true,rt.nativeCompleted==true
    row.opened,row.crossedOut,row.crossedIn,row.closedDoor=rt.opened==true,rt.crossedOut==true,rt.crossedIn==true,rt.closedDoor==true
    row.enclosureConfirmed=rt.enclosureConfirmed==true;row.afterCover=collector.copy(rt.afterCover or {})
    if row.status=="completed" and not shelter.useBound(rt) then row.status="failed" end
    row.nativeCredit=row.status=="completed" and w.id or nil
    if not shelter.useOutcome(rt.id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rec.resourceProductionWork=nil;rt.closed=true;rt.door=nil;plumbDispose(rt);reconcile(rt.id);return true
end
function shelter.useRecover(id,body)
    local rec,w=SAO.Identity.get(id);w=rec and rec.resourceProductionWork
    if not w or w.kind~="use-shelter" then return true end
    local t,world=now(),getWorld()
    if not shelter.useIdentity(id,w) or not shelter.usePurpose(rec,w) or not craftLedger(rec) or not t
        or t<w.startedAt or not world or world:getWorld()~=w.world or not body
        or tostring(body:getModData().SAOPersonId or "")~=tostring(id) or body:getModData().SAOExternalToken~=w.bodyToken then return false end
    for _,q in pairs(ISTimedActionQueue.queues) do
        local pending={};for _,action in ipairs(q.queue) do pending[#pending+1]=action end
        if q.current and q:indexOf(q.current)==-1 then pending[#pending+1]=q.current end
        for _,action in ipairs(pending) do if action.actorId==id and action.workId==w.id and action.bodyToken==w.bodyToken then
            if type(action._SAOPlumbRetireSaved)~="function" then return false end
            local ok,retired=pcall(action._SAOPlumbRetireSaved,rec,w);if not ok or not retired then return false end
        end end
    end
    local route=SAO.Locomotion.jobs[id]
    if route and not route.done and route.shelterWorkId==w.id then
        if route.body~=body or SAOJavaBridge:cancelMove(body)~="MOVE_CANCELLED" then return false end;route.done=true
    end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if SAOJavaBridge:hasPendingActions(body) or q.current or #q.queue>0 then return false end
    if rec.resourceProductionWork~=w then return true end
    local rows=rec.resourceProductionOutcomes or {}
    if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end
    local row=collector.copy(w);row.stage,row.admittedNeeds,row.admittedHealth=nil,nil,nil
    row.workId,row.nativeOwner,row.status,row.detail,row.atHours,row.endedAt=w.id,"ISOpenCloseDoor+SAO.Locomotion","interrupted","shelter-use-runtime-unavailable",t,t
    row.nativeObservability="runtime-unavailable"
    for _,key in ipairs({"nativeAttempted","nativeCompleted","opened","crossedOut","crossedIn","closedDoor","enclosureConfirmed"}) do row[key]=false end
    if not shelter.useOutcome(id,row) then return false end
    rows[#rows+1]=row;rec.resourceProductionOutcomes=rows;if #rows>CRAFT_LIMIT then table.remove(rows,1) end
    rec.resourceProductionWork=nil;reconcile(id);return true
end
function shelter.useTick(id,body)
    local rt=runtime[id]
    if not rt then return shelter.useRecover(id,body) and "interrupted" or "cancelling" end
    if rt.cancelling or rt.body~=body or not shelter.useBound(rt) or now()-rt.startedAt>.5 then
        return plumbInterrupt(id,rt.body,rt.cancelReason or "shelter-use-owner-changed") and "interrupted" or "cancelling"
    end
    local stage=rt.work.stage
    if stage=="approaching" or stage=="crossing-out" or stage=="crossing-in" then
        if not rt.route or SAO.Locomotion.jobs[id]~=rt.route or rt.route.shelterWorkId~=rt.workId then
            return plumbInterrupt(id,body,"shelter-route-owner-lost") and "interrupted" or "cancelling"
        end
        SAO.Locomotion.tick(id);if not rt.route.done then return "moving" end
        local expectedX=stage=="crossing-out" and rt.outX or rt.site.insideX
        local expectedY=stage=="crossing-out" and rt.outY or rt.site.insideY
        if rt.route.result~="arrived" or math.floor(body:getX())~=expectedX or math.floor(body:getY())~=expectedY
            or stage~="approaching" and SAOJavaBridge:worldShelterPassage(body,rt.passageToken)~=true then
            return plumbInterrupt(id,body,"shelter-native-passage-unconfirmed") and "interrupted" or "cancelling"
        end
        if stage=="approaching" then
            return shelter.useDoor(rt,not rt.door:IsOpen(),rt.door:IsOpen() and "closing-initial" or "opening") and "using" or "cancelling"
        elseif stage=="crossing-out" then
            rt.crossedOut=true
            return shelter.useRoute(rt,rt.site.insideX,rt.site.insideY,"crossing-in") and "moving" or "cancelling"
        else
            rt.crossedIn=true
            return shelter.useDoor(rt,false,"closing") and "using" or "cancelling"
        end
    elseif stage=="awaiting-native-enclosure" then
        if rt.door:IsOpen() or body:getCurrentSquare()~=rt.cell:getGridSquare(rt.site.insideX,rt.site.insideY,rt.site.z) then
            return plumbInterrupt(id,body,"shelter-current-door-or-occupancy-changed") and "interrupted" or "cancelling"
        end
        local cover=SAOJavaBridge:worldShelterCover(body,rt.site.insideX,rt.site.insideY,rt.site.z)
        rt.afterCover=collector.copy(cover)
        if rt.afterCover and cover.reached==true and cover.roof==true and cover.regionKnown==true
            and cover.enclosed==true and cover.fullyRoofed==true then
            rt.enclosureConfirmed,rt.nativeCompleted=true,true
            return shelter.useClose(rt,"completed","native-doorway-used-and-enclosure-observed") and "completed" or "cancelling"
        end
        return "awaiting-native-enclosure"
    end
    if queued(rt.action) then return "using" end
    return plumbInterrupt(id,body,"shelter-native-door-acknowledgement-missing") and "interrupted" or "cancelling"
end
function shelter.useBegin(id,body,step,context)
    local rec,t=owner(id,body),now()
    if not rec or not t or not craftLedger(rec) or rec.resourceProductionWork or rec.worldSourceReservation or rec.cookingWork
        or SAO.Needs.busy(body) or SAOJavaBridge:hasPendingActions(body) or not shelter.site(id,body,step.site)
        or step.owner~="SAO.ResourceProduction" or step.token~="resource:shelter-used" or step.productionKind~="use-shelter"
        or isClient() or isServer() or not collector.install() then return false end
    local loaded=pcall(require,"TimedActions/ISOpenCloseDoor");if not loaded or not ISOpenCloseDoor then return false end
    local p=rec.proceduralPlanning and rec.proceduralPlanning.purposes[context.purposeId]
    if not p or not p.shelterConstruction or p.admission or p.steps[p.cursor]~=step or step.id~=context.purposeStepId then return false end
    local door=SAOJavaBridge:worldShelterDoor(body,step.site.key,step.site.revision);if not door then return false end
    local world=getWorld();if not world then return false end
    local site=step.site;local otherX,otherY=site.x-(site.face=="W" and 1 or 0),site.y-(site.face=="N" and 1 or 0)
    local outX,outY=site.insideX==site.x and site.insideY==site.y and otherX or site.x,
        site.insideX==site.x and site.insideY==site.y and otherY or site.y
    local rt={kind="use-shelter",id=id,record=rec,body=body,site=collector.copy(site),siteSquare=door:getSquare(),door=door,
        inventory=body:getInventory(),world=world:getWorld(),cell=body:getCell(),queue=ISTimedActionQueue.getTimedActionQueue(body),
        token=body:getModData().SAOExternalToken,startedAt=t,actions={},otherX=otherX,otherY=otherY,outX=outX,outY=outY}
    local seq=(rec.resourceProductionSequence or 0)+1;local needs=SAO.Needs.read(body) or {}
    local w={id="resource-production/"..id.."/"..seq,sequence=seq,actorId=id,kind=rt.kind,category="construction",
        token="resource:shelter-used",purposeId=context.purposeId,purposeStepId=context.purposeStepId,
        site=collector.copy(site),siteKey=site.key,siteRevision=site.revision,world=rt.world,bodyToken=rt.token,
        startedAt=t,status="using",stage="approaching",admittedNeeds={hunger=needs.hunger,thirst=needs.thirst,fatigue=needs.fatigue},
        beforeCover=collector.copy(SAOJavaBridge:worldShelterCover(body,site.insideX,site.insideY,site.z))}
    rt.work,rt.workId=w,w.id
    if not shelter.useIdentity(id,w) then return false end
    rec.resourceProductionSequence,rec.resourceProductionWork,runtime[id]=seq,w,rt
    if not SAO.ProceduralPlanning.admitShelterUse(id,w) then rec.resourceProductionWork=nil;plumbDispose(rt);return false end
    rt.purpose,rt.step=shelter.usePurpose(rec,w)
    if not shelter.useRoute(rt,site.insideX,site.insideY,"approaching") then
        plumbInterrupt(id,body,"native-shelter-approach-refused");return false
    end
    return true
end

function R.reconcileSaved(id,body)
    local rec=SAO.Identity.get(id)
    if SAO.Study and SAO.Study.reconcileGeneratorReading and not SAO.Study.reconcileGeneratorReading(id,body) then return false end
    if rec and rec.resourceProductionWork and rec.resourceProductionWork.kind=="generator-operation" then
        return SAO.Generator and SAO.Generator.reconcileSaved(id,body) or false
    end
    if SAO.Generator then SAO.Generator.reconcileSaved(id,body) end
    if rec and rec.resourceProductionWork and nativeEntityKind(rec.resourceProductionWork.kind) then return collector.recover(id,body) end
    if rec and rec.resourceProductionWork and rec.resourceProductionWork.kind=="plumb-fixture" then return plumbRecover(id,body) end
    if rec and rec.resourceProductionWork and nativeCraftKind(rec.resourceProductionWork.kind) then return craftRecover(id,body) end
    reconcile(id);return true
end
function R.retryCraftCancellations()
    for id,rt in pairs(runtime) do
        if (rt.kind=="plumb-fixture" or nativeEntityKind(rt.kind)) and rt.cancelling then plumbInterrupt(id,rt.body,rt.cancelReason)
        elseif nativeCraftKind(rt.kind) and rt.cancelling then craftInterrupt(id,rt.body,rt.cancelReason) end
    end
end
if Events and Events.OnTick then Events.OnTick.Add(R.retryCraftCancellations) end

function R.begin(id, body, step, context)
    context = context or {}
    if step and step.owner=="SAO.Generator" then return SAO.Generator and SAO.Generator.begin(id,body,step,context) or false end
    if step and step.productionKind == "use-shelter" then return shelter.useBegin(id,body,step,context) end
    if step and step.productionKind == "build-shelter-edge" then return shelter.begin(id,body,step,context) end
    if step and step.productionKind == "build-wood-bed" then return bed.begin(id,body,step,context) end
    if step and step.productionKind == "build-rain-collector" then return collector.begin(id, body, step, context) end
    if step and step.productionKind == "plumb-fixture" then return plumbBegin(id, body, step, context) end
    if step and step.productionKind == "saw-logs" then return craftBegin(id, body, step, context) end
    if step and step.productionKind == "repair-held-item" then return repairBegin(id, body, step, context) end
    if step and step.productionKind == "fix-held-item" then return fixing.begin(id, body, step, context) end
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
    if rec and rec.resourceProductionWork and rec.resourceProductionWork.kind=="generator-operation" then
        return SAO.Generator and SAO.Generator.interrupt(id,body,reason) or false
    end
    if rt and nativeEntityKind(rt.kind) or rec and rec.resourceProductionWork
        and nativeEntityKind(rec.resourceProductionWork.kind) then
        if not rt then return collector.recover(id,body) end
        return plumbInterrupt(id,body,reason)
    end
    if rt and rt.kind == "plumb-fixture" or rec and rec.resourceProductionWork
        and rec.resourceProductionWork.kind == "plumb-fixture" then return plumbInterrupt(id, body, reason) end
    if rt and nativeCraftKind(rt.kind) or rec and rec.resourceProductionWork
        and nativeCraftKind(rec.resourceProductionWork.kind) then return craftInterrupt(id, body, reason) end
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
    if category ~= "water" or not work or (work.kind ~= "refill-water" and work.kind ~= "plumb-fixture" and work.kind ~= "build-rain-collector")
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
    if SAO.Needs.bleeding(body) > 0 then return true end
    local prior = work.admittedNeeds or {}
    local urgent = tonumber(emergencyHunger) or 0.85
    -- Ordinary discomfort can yield to an immediately usable carried drink;
    -- it does not cancel unfinished work merely to retry an unavailable need.
    if needs.thirst >= SAO.Disposition.drinkAt(id) and not R.servesNeed(id, body, "water") then
        local ok, readyDrink = pcall(function() return SAOJavaBridge:findCarriedDrink(body) end)
        if ok and readyDrink ~= nil or needs.thirst >= math.max(urgent, SAO.Disposition.drinkAt(id)) then return true end
    end
    if needs.hunger >= SAO.Disposition.eatAt(id) then
        local ok, readyFood = pcall(function() return SAOJavaBridge:findCarriedFood(body) end)
        local threshold = math.max(urgent, SAO.Disposition.eatAt(id))
        if ok and readyFood ~= nil or needs.hunger >= threshold
            and (not prior.hunger or prior.hunger < threshold) then return true end
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
    if work.kind=="generator-operation" then return SAO.Generator and SAO.Generator.tick(id,body) or "cancelling" end
    if nativeEntityKind(work.kind) then return collector.tick(id, body) end
    if work.kind == "plumb-fixture" then return plumbTick(id, body) end
    if nativeCraftKind(work.kind) then return craftTick(id, body) end
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
    if SAO.Generator then SAO.Generator.reset() end
    for id, rt in pairs(runtime) do R.interrupt(id, rt.body, "world-reset") end
    for id in pairs(sourceRefresh) do retireRefresh(id, "handled-source-observation-retired") end
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(R.reset) end
return R
