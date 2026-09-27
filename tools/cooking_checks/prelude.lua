-- Controlled action receivers; installed ISBaseTimedAction/ISToggleStoveAction
-- and the actual candidate are loaded after this fixture by LuaRun.
require = function() end
Events = { OnGameStart = { handlers = {} } }
Events.OnGameStart.Add = function(fn) table.insert(Events.OnGameStart.handlers, fn) end
SAO = {}
local function list(values)
    return { values = values or {}, size = function(self) return #self.values end,
        get = function(self, index) return self.values[index + 1] end }
end
function newFixture(carried)
    if SAO.Cooking and SAO.Cooking.reset then SAO.Cooking.reset() end
    local cooking = SAO.Cooking
    F = { thermalReads = 0, at = 10, allowed = true, foodAllowed = true, enter = true, applianceReachable = true,
        queueAccept = true, transferAccept = true, closeAccept = true, routeAccept = true,
        inspected = 0, queueCalls = 0, transferCalls = 0, closeCalls = 0, routeCalls = 0,
        cancels = 0, clears = 0, creditCalls = 0, xp = 0, receipt = nil, sourceSequence = 0 }
    F.rec = { id = "cook-a" }
    F.inventory = { getItems = function(self) return self.items end, items = list() }
    F.container = { getItems = function(self) return self.items end, items = list(), explored = true }
    F.foodContainer = { getItems = function(self) return self.items end, items = list() }
    F.body = {
        data = { SAOPersonId = "cook-a" }, attached = true, shell = true,
        getModData = function(self) return self.data end,
        getInventory = function() return F.inventory end,
        getCurrentSquare = function(self) return self.attached and {} or nil end,
        isExistInTheWorld = function(self) return self.attached end,
        isAsleep = function(self) return self.sleeping == true end,
        isDead = function(self) return self.dead == true end,
        isAiming = function(self) return self.aim == true end,
        isAttacking = function(self) return self.attack == true end,
        isClimbing = function(self) return self.climb == true end,
        isClimbingRope = function(self) return self.rope == true end,
        getVehicle = function(self) return self.vehicle end,
        setIsFarming = function() end, faceThisObject = function() end,
    }
    F.food = { id = 71, fullType = "Base.MuttonChop", cooked = false, burnt = false, cookable = true,
        container = carried == false and F.foodContainer or F.inventory,
        getID = function(self) return self.id end, getFullType = function(self) return self.fullType end,
        getContainer = function(self) return self.container end,
        isCooked = function(self) return self.cooked end, isBurnt = function(self) return self.burnt end,
        isCookable = function(self) return self.cookable end,
    }
    F.food.container.items.values = { F.food }
    F.stove = { active = false, powered = true, toggleCalls = 0,
        Activated = function(self) return self.active end,
        getObjectIndex = function(self) return self.removed and -1 or 0 end,
        Toggle = function(self) self.toggleCalls = self.toggleCalls + 1
            if not self.refuseToggle then self.active = not self.active end end,
        PlayToggleSound = function() end,
    }
    F.appliance = { object = F.stove, container = F.container, sourceId = "oven-1", kind = "stove",
        sourceX = 1, sourceY = 2, sourceZ = 0, approachX = 1, approachY = 2, approachZ = 0 }
    F.foodOffer = { item = F.food, container = F.food.container, worldContainer = F.foodContainer,
        itemId = 71, itemType = "Base.MuttonChop", sourceId = "fridge-1", carried = carried ~= false,
        sourceX = 3, sourceY = 4, sourceZ = 0, approachX = 3, approachY = 4, approachZ = 0 }
    SAO = { Cooking = cooking,
        Identity = { get = function(id) return id == F.rec.id and F.rec or nil end },
        Body = { active = { [F.rec.id] = F.body }, foreign = {}, get = function(id) return id == F.rec.id and F.body or nil end },
        Controller = { agents = { [F.rec.id] = { rec = F.rec, state = "IDLE" } } },
        History = { countyHours = function() return F.at end },
        Standing = { mayTakeCurrent = function(id, x) return F.allowed and (x ~= 3 or F.foodAllowed) end,
            mayEnterBelieved = function() return F.enter end },
        Observation = { record = function() end },
        Locomotion = { jobs = {},
            cancel = function(id) F.cancels = F.cancels + 1 SAO.Locomotion.jobs[id] = nil end,
            order = function(id, body, x, y, z) F.routeCalls = F.routeCalls + 1
                F.routeTarget = { x = x, y = y, z = z }
                if not F.routeAccept then return false end
                SAO.Locomotion.jobs[id] = { body = body, done = false } return true end,
            tick = function(id) if F.arrive then
                SAO.Locomotion.jobs[id].done = true SAO.Locomotion.jobs[id].result = "arrived"
                F.applianceReachable = true F.foodReachable = true end end },
    }
    ZAO = { Controller = { controlled = {} } }
    local queue = { queue = {}, resetQueue = function(self) self.queue = {} F.busy = false end,
        onCompleted = function(self) self.queue = {} F.busy = false end }
    ISTimedActionQueue = { queues = { [F.body] = queue }, getTimedActionQueue = function() return queue end }
    SAO.Needs = { busy = function() return F.busy == true end,
        queueVerified = function(action) F.queueCalls = F.queueCalls + 1
            if not F.queueAccept then return false end
            F.action = action F.busy = true queue.queue = { action } return true end }
    SAO.WorldSources = {
        inspectionCandidate = function(id, body, admission, radius, sourceId)
            F.inspectionSource = sourceId
            if F.inspectionRefused then return nil, "inspection-refused" end
            return { sourceId = sourceId }
        end,
        inspectContainer = function(id, body, context)
            F.inspected = F.inspected + 1 return not F.inspectRefused, "inspection-refused"
        end,
        actionOutcome = function() return F.receipt end,
    }
    SAO.SourceUse = {
        beginTransfer = function(id, body, category, admission, item, container, operation)
            F.transferCalls = F.transferCalls + 1
            if not F.transferAccept then return false, "queue-refused" end
            F.sourceSequence = F.sourceSequence + 1
            local reservation = { id = "R:" .. tostring(F.sourceSequence) }
            F.rec.worldSourceReservation = reservation.id
            F.pendingTransfer = { id = reservation.id, actorId = id, itemId = item.id,
                itemType = item.fullType, container = container, operation = operation,
                sourceId = container == F.container and "oven-1" or "fridge-1" }
            F.busy = true return true, reservation
        end,
        tick = function(id, body)
            if not F.transferReady then return "pending" end
            local pending = F.pendingTransfer
            if F.transferReady.move ~= false then
                F.food.container.items.values = {}
                F.food.container = pending.operation == "acquire" and F.inventory or pending.container
                F.food.container.items.values = { F.food }
            end
            local receipt = { reservationId = pending.id, actorId = pending.actorId, itemId = pending.itemId,
                itemType = pending.itemType, sourceId = pending.sourceId, operation = pending.operation,
                status = "completed", measurement = "native-item-transfer", observedQuantity = 1 }
            for key, value in pairs(F.transferReady.changes or {}) do receipt[key] = value end
            F.receipt = receipt F.rec.worldSourceReservation = nil F.busy = false
            F.transferReady = nil return "completed"
        end,
        closeForOwnershipTransfer = function()
            F.closeCalls = F.closeCalls + 1
            if not F.closeAccept then return false end
            F.rec.worldSourceReservation = nil F.busy = false return true
        end,
    }
    SAOJavaBridge = {
        isShell = function(self, body) return body.shell end,
        cookingOffers = function() return { appliances = { F.appliance }, foods = { F.foodOffer } } end,
        worldTransferPosition = function() return F.foodReachable == false and "" or "1:2:0" end,
        inspectCookingAppliance = function(self, body, object, container)
            if not F.applianceReachable or object ~= F.stove or container ~= F.container or F.stove.removed then return nil end
            return { sourceId = F.changedSource or "oven-1", kind = F.appliance.kind,
                active = F.stove.active, powered = F.stove.powered }
        end,
        cookingApproach = function(self, body, object, container)
            if F.approachMissing or object ~= F.stove or container ~= F.container or F.stove.removed then return nil end
            return { sourceId = F.approachSource or "oven-1", sourceX = F.approachSourceX or 1, sourceY = 2, sourceZ = 0,
                approachX = F.freshX or 5, approachY = F.freshY or 6, approachZ = 0 }
        end,
        beginCookingHeat = function(self, body, workId, item, object, container)
            if F.bindRefused or item.container ~= F.container or item.cooked then return false end
            F.binding = { body = body, workId = workId, item = item }
            F.thermal = { beforeCookingTime = 0, cookingTime = 0, progressed = false }
            return true
        end,
        cookingHeatState = function()
            F.thermalReads = F.thermalReads + 1
            if not F.binding or F.thermalLost then return nil end
            return { itemId = F.food.id, workId = F.binding.workId, actorId = F.rec.id,
                beforeCookingTime = F.thermal.beforeCookingTime, cookingTime = F.thermal.cookingTime,
                progressed = F.thermal.progressed, cooked = F.food.cooked, burnt = F.food.burnt }
        end,
        completeCookingHeat = function(self)
            F.creditCalls = F.creditCalls + 1
            if F.creditRefused or not F.food.cooked or not F.thermal.progressed then return nil end
            if not F.credited then F.xp = F.xp + 10 F.credited = true end
            local result = self:cookingHeatState() result.credited = true
            for key, value in pairs(F.creditChanges or {}) do result[key] = value end
            return result
        end,
        clearCookingHeat = function(self, body, workId)
            F.clears = F.clears + 1
            if F.binding and F.binding.body == body and F.binding.workId == workId then F.binding = nil end
        end,
    }
    return F
end
function beginCooking() assert(SAO.Cooking.begin(F.rec.id, F.body), "begin refused") end
function tickCooking() return SAO.Cooking.tick(F.rec.id, F.body) end
function settleTransfer(move, changes)
    F.transferReady = { move = move, changes = changes }
    return tickCooking()
end
function completeToggle()
    local action = F.action assert(action, "no toggle")
    local result = action:complete()
    F.busy = false ISTimedActionQueue.queues[F.body].queue = {}
    return result
end
function heatSetup()
    beginCooking() assert(tickCooking() == "transfer", "deposit not queued")
    assert(settleTransfer() == "switching-appliance", "activation not queued")
    assert(completeToggle(), "activation refused")
    assert(tickCooking() == "heating", "not heating")
end
function nativeCooked()
    F.food.cooked = true F.thermal.cookingTime = 51 F.thermal.progressed = true
end
function lastOutcome() return F.rec.cookingOutcomes and F.rec.cookingOutcomes[#F.rec.cookingOutcomes] end
__cookingCases = {}
function case(name, fn)
    local ok, value = pcall(fn)
    table.insert(__cookingCases, name .. "=" .. tostring(ok and value == true))
    if not ok then print("CASE_ERROR " .. name .. ": " .. tostring(value)) end
end
