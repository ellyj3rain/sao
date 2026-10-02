-- SAO_Animals — the ranch's own bodies and actions ([C123]).
-- ---------------------------------------------------------------------------
-- Animal state belongs to Build 42. A designated ranch supplies its animals,
-- troughs and hutches. Horse assets, gear, mounting, riding physics, stamina
-- and networking are source-integrated under the Horse team's credited
-- modules; this module joins that physical execution to SAO people, plans and
-- durable records.

SAO = SAO or {}
SAO.Animals = SAO.Animals or {}
local A = SAO.Animals

require "TimedActions/Animals/ISFeedAnimalFromHand"

local Mounts = require("HorseMod/Mounts")
local Mounting = require("HorseMod/Mounting")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local HorseManager = require("HorseMod/HorseManager")
local HorseRiding = require("HorseMod/Riding")
local Stamina = require("HorseMod/Stamina")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")

local CARE_RADIUS = 3
local TRAVEL_MOUNT_RADIUS = 8
local TRAVEL_MIN_TILES = 12
local TRAVEL_REACH = 1.75
local TRAVEL_HEADING_MIN_LENGTH = 0.05
local TRAVEL_STALL_TICKS = 480
A.travelJobs = A.travelJobs or {}
A.careRuntime = A.careRuntime or {}
A.careEpoch = A.careEpoch or 0
local careRuntime = A.careRuntime
local MAX_CARE_OUTCOMES = 32

function A.forget(id)
    A.travelJobs[id] = nil
    local work = careRuntime[id]
    if work then
        work.action.saoAnimalCareDenied = true
        pcall(function() SAOJavaBridge:animalCareCancelFeed(work.body, work.token) end)
        careRuntime[id] = nil
    end
end

local function log(msg) SAO.Log.line("ANIMAL", msg) end

local function number(value)
    local n = tonumber(value)
    return n and n == n and n > -math.huge and n < math.huge and n or nil
end

local function careOwner(id, body)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local agent = SAO.Controller and SAO.Controller.agents[id]
    if not rec or rec.dead or rec.bodyOwner ~= nil or rec.bodyOwnerToken ~= nil
        or rec.zaoTransferPending or rec.crossedTransferPending or not body
        or not SAO.Body or SAO.Body.active[id] ~= body or SAO.Body.get(id) ~= body
        or SAO.Body.foreign[id] ~= nil or not agent or agent.rec ~= rec or agent.passive
        or agent.state == "PASSIVE" or SAO.Body.isTransitioning(rec) then return nil end
    local data = body:getModData()
    if tostring(data.SAOPersonId or "") ~= tostring(id) or data.SAOExternalOwner ~= nil
        or data.SAOExternalToken ~= nil or data.ZAOOwned == true
        or SAOJavaBridge:isShell(body) ~= true or not body:isExistInTheWorld()
        or body:isDead() or not body:getCurrentSquare() then return nil end
    return rec
end

-- An existing ZAO actor keeps its own native feeding action. SAO authenticates
-- that retained owner without admitting private care work for it.
local function foreignCareOwner(id, body)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local agent = SAO.Controller and SAO.Controller.agents[id]
    if not rec or tostring(rec.id or "") ~= id or rec.dead or rec.bodyOwner ~= "ZAO"
        or type(rec.bodyOwnerToken) ~= "string" or rec.bodyOwnerToken == ""
        or rec.zaoTransferPending or rec.crossedTransferPending or not body
        or not SAO.Body or SAO.Body.active[id] ~= nil or SAO.Body.foreign[id] ~= body
        or SAO.Body.get(id) ~= body or SAO.Body.isTransitioning(rec)
        or not agent or agent.rec ~= rec or agent.passive ~= true then return nil end
    local data = body:getModData()
    if tostring(data.SAOPersonId or "") ~= id or data.SAOExternalOwner ~= "ZAO"
        or data.SAOExternalToken ~= rec.bodyOwnerToken
        or SAOJavaBridge:isShell(body) ~= true or not body:isExistInTheWorld()
        or body:isDead() or not body:getCurrentSquare() then return nil end
    local world = type(getWorld) == "function" and getWorld() or nil
    local cell = world and world:getCell()
    if not cell or (not cell:getObjectList():contains(body)
        and not cell:getAddList():contains(body)) then return nil end
    return rec
end

local function carePositionPermission(id, x, y)
    return SAO.Standing and SAO.Standing.mayTakeCurrent
        and SAO.Standing.mayTakeCurrent(id, x, y, "standing") == true
end

local function carePermission(id, animal)
    return carePositionPermission(id, animal:getX(), animal:getY())
end

local function careState(rec)
    local s = rec.animalCare
    if s == nil then
        s = { schema = 1, sequence = 0, acknowledgedThrough = 0, omittedOutcomes = 0, outcomes = {} }
        rec.animalCare = s
    end
    if type(s) ~= "table" or s.schema ~= 1 or type(s.outcomes) ~= "table"
        or not number(s.sequence) or s.sequence < 0 or s.sequence ~= math.floor(s.sequence)
        or not number(s.acknowledgedThrough) or s.acknowledgedThrough < 0
        or s.acknowledgedThrough > s.sequence or not number(s.omittedOutcomes)
        or s.omittedOutcomes < 0 then return nil end
    return s
end

-- Only this actor's retained canonical receipts reach the private learning owner.
-- Disabled or unavailable learning never prevents native animal care.
function A.deliverCareOutcomes(id)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local s = rec and careState(rec)
    local cognition = SAO.Cognition
    if not s or not cognition or not cognition.animalCareOutcome then return false end
    while #s.outcomes > 0 do
        local row = s.outcomes[1]
        local ok, accepted = pcall(cognition.animalCareOutcome, id, row)
        if not ok or accepted ~= true then return false end
        s.acknowledgedThrough = row.position
        table.remove(s.outcomes, 1)
    end
    return true
end

local function recordFeed(work, wire)
    local fields = {}
    if type(wire) ~= "string" or #wire > 1024 then return false end
    for field in wire:gmatch("[^@]+") do fields[#fields + 1] = field end
    if #fields ~= 11 or fields[1] ~= "completed" or fields[2] ~= work.token
        or fields[11] ~= "native-feed-consumed" then return false end
    local animalId, itemId = number(fields[3]), number(fields[4])
    local before, after, hungerBefore, hungerAfter = number(fields[7]), number(fields[8]), number(fields[9]), number(fields[10])
    if animalId ~= work.animalId or itemId ~= work.itemId or fields[5] ~= work.itemType
        or (fields[6] ~= "uses" and fields[6] ~= "fluid" and fields[6] ~= "food-hunger")
        or not before or not after or after < 0 or before - after <= 0.000001
        or not hungerBefore or not hungerAfter or hungerAfter < 0 or hungerBefore - hungerAfter <= 0.000001 then return false end
    local now = SAO.History and SAO.History.countyHours()
    if work.epoch ~= A.careEpoch or careOwner(work.id, work.body) ~= work.rec or not carePermission(work.id, work.animal)
        or not number(now) or now < work.startedAt then return false end
    local s = careState(work.rec)
    if not s or s.sequence >= 9007199254740991 then return false end
    s.sequence = s.sequence + 1
    local row = { schema = 1, id = "animal-care/" .. work.id .. "/" .. tostring(s.sequence),
        actorId = work.id, position = s.sequence, worldHours = now, kind = "feed", status = "completed",
        nativeToken = work.token, animalId = animalId, itemId = itemId, itemType = work.itemType,
        quantityUnit = fields[6], beforeAmount = before, afterAmount = after, consumedAmount = before - after,
        beforeHunger = hungerBefore, afterHunger = hungerAfter, hungerDelta = hungerBefore - hungerAfter,
        reason = fields[11] }
    if #s.outcomes >= MAX_CARE_OUTCOMES then
        table.remove(s.outcomes, 1)
        s.omittedOutcomes = s.omittedOutcomes + 1
    end
    s.outcomes[#s.outcomes + 1] = row
    A.deliverCareOutcomes(work.id)
    return true
end

local function cancelFeed(action)
    local work = action.saoAnimalCareWork
    local original = work or action.saoAnimalCareForeign or action.saoAnimalCareAdmission
    action.saoAnimalCareDenied = true
    if original then
        -- Native stop resolves its animal, actor and queue from these fields.
        -- Retire the original admitted work even after callback substitution.
        action.character, action.animal, action.food = original.body, original.animal, original.item
    end
    if work and not work.cancelled then
        work.cancelled = true
        if work.token then pcall(function() SAOJavaBridge:animalCareCancelFeed(work.body, work.token) end) end
        if careRuntime[work.id] == work then careRuntime[work.id] = nil end
    end
end

local function refuseFeed(action)
    cancelFeed(action)
    pcall(function() action:forceStop() end)
    return false
end

local function beginFeed(action)
    local body = action.character
    local admission = action.saoAnimalCareAdmission
    if admission and (body ~= admission.body or action.animal ~= admission.animal
        or action.food ~= admission.item or admission.epoch ~= A.careEpoch) then return false end
    local rawId = body and body:getModData().SAOPersonId
    if rawId == nil or SAOJavaBridge:isShell(body) ~= true then return admission == nil end
    local id = tostring(rawId)
    if admission then
        if admission.id ~= id or admission.rec ~= careOwner(id, body) or admission.body ~= body
            or admission.animal ~= action.animal or admission.item ~= action.food
            or admission.epoch ~= A.careEpoch then return false end
    else
        local foreign = foreignCareOwner(id, body)
        if foreign then
            action.saoAnimalCareForeign = { id = id, rec = foreign, body = body,
                ownerToken = foreign.bodyOwnerToken, animal = action.animal, item = action.food,
                epoch = A.careEpoch }
            return true
        end
    end
    local rec = careOwner(id, body)
    local animal, food = action.animal, action.food
    local now = SAO.History and SAO.History.countyHours()
    if not rec or not animal or not food or not number(now) or now < 0 or not carePermission(id, animal) then return false end
    local prior = careRuntime[id]
    if prior and prior.action ~= action then
        if careOwner(id, prior.body) ~= prior.rec then A.forget(id) else return false end
    end
    local token = SAOJavaBridge:animalCareBeginFeed(body, animal, food)
    if type(token) ~= "string" or token == "" then return false end
    local work = { id = id, rec = rec, body = body, animal = animal, item = food, action = action,
        animalId = animal:getAnimalID(), itemId = food:getID(), itemType = food:getFullType(), startedAt = now,
        token = token ~= "BUSY" and token or nil, epoch = A.careEpoch }
    action.saoAnimalCareWork = work
    if work.token then careRuntime[id] = work end
    return true
end

-- The installed action remains the sole physical mutation and native XP owner.
-- Non-SAO player actions pass through unchanged.
if ISFeedAnimalFromHand and not ISFeedAnimalFromHand.SAOAnimalCareWrapped then
    ISFeedAnimalFromHand.SAOAnimalCareWrapped = true
    local baseStart, baseComplete, baseStop = ISFeedAnimalFromHand.start,
        ISFeedAnimalFromHand.complete, ISFeedAnimalFromHand.stop
    function ISFeedAnimalFromHand:start(...)
        if self.saoAnimalCareDenied or self.saoAnimalCareSettled then return false end
        if not self.saoAnimalCareStarted then
            self.saoAnimalCareStarted = true
            local ok, accepted = pcall(beginFeed, self)
            if not ok or accepted ~= true then return refuseFeed(self) end
        end
        local ok, result = pcall(baseStart, self, ...)
        if not ok then cancelFeed(self); error(result) end
        return result
    end
    function ISFeedAnimalFromHand:complete(...)
        if self.saoAnimalCareDenied or self.saoAnimalCareSettled then return false end
        local work = self.saoAnimalCareWork
        if work then
            local ok, ready = pcall(function()
                if work.epoch ~= A.careEpoch or careOwner(work.id, self.character) ~= work.rec or self.character ~= work.body
                    or self.animal ~= work.animal or self.food ~= work.item
                    or not carePermission(work.id, work.animal) then return false end
                if not work.token then
                    local token = SAOJavaBridge:animalCareBeginFeed(work.body, work.animal, work.item)
                    if token == "BUSY" then return true end
                    if type(token) ~= "string" or token == "" then return false end
                    work.token = token
                end
                return SAOJavaBridge:animalCarePrepareFeed(work.body, work.token, work.animal, work.item) == true
            end)
            if not ok or ready ~= true then return refuseFeed(self) end
        elseif self.saoAnimalCareAdmission then return refuseFeed(self)
        elseif self.saoAnimalCareForeign then
            local foreign = self.saoAnimalCareForeign
            local ok, valid = pcall(function()
                return foreign.epoch == A.careEpoch and self.character == foreign.body
                    and self.animal == foreign.animal and self.food == foreign.item
                    and foreignCareOwner(foreign.id, self.character) == foreign.rec
                    and foreign.rec.bodyOwnerToken == foreign.ownerToken
            end)
            if not ok or valid ~= true then return refuseFeed(self) end
        elseif self.character and self.character:getModData().SAOPersonId ~= nil
            and SAOJavaBridge:isShell(self.character) == true then
            local ok, foreign = pcall(foreignCareOwner,
                tostring(self.character:getModData().SAOPersonId), self.character)
            if self.saoAnimalCareAdmission or not ok or not foreign then return refuseFeed(self) end
        end
        self.saoAnimalCareSettled = true
        local ok, result = pcall(baseComplete, self, ...)
        if work then
            if careRuntime[work.id] == work then careRuntime[work.id] = nil end
            if work.token then
                local measured, wire = pcall(function()
                    return SAOJavaBridge:animalCareFinishFeed(work.body, work.token, self.animal, self.food, ok and result == true)
                end)
                if measured and ok and result == true then pcall(recordFeed, work, wire) end
                if not measured then pcall(function() SAOJavaBridge:animalCareCancelFeed(work.body, work.token) end) end
            end
        end
        if not ok then error(result) end
        return result
    end
    function ISFeedAnimalFromHand:stop(...)
        cancelFeed(self)
        return baseStop(self, ...)
    end
end

function A.resetCareForWorld()
    A.careEpoch = A.careEpoch + 1
    for id in pairs(careRuntime) do A.forget(id) end
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(A.resetCareForWorld) end

local function parse(row)
    local fields = {}
    for field in tostring(row):gmatch("[^@]+") do
        fields[#fields + 1] = field
    end
    if #fields ~= 19 or fields[1] == "" then return nil end
    local values = {}
    for index = 2, 19 do
        values[index] = number(fields[index])
        if values[index] == nil then return nil end
    end
    if values[2] ~= math.floor(values[2]) then return nil end
    return {
        type = fields[1], id = values[2], x = values[3], y = values[4],
        z = values[5], hunger = values[6], thirst = values[7],
        stress = values[8], acceptance = values[9],
        zoneAcceptance = values[10], milk = values[11] == 1,
        shear = values[12] == 1, eggs = values[13],
        water = values[14], maxWater = values[15],
        handFeed = values[16] == 1, wild = values[17] == 1,
        baby = values[18] == 1, hutches = values[19],
    }
end

-- Every number here is the engine's present value. An empty or malformed
-- bridge answer is no ranch, not a reason to infer one.
function A.read(body, radius)
    if not SAOJavaBridge then return {} end
    local ok, answer = pcall(function()
        return SAOJavaBridge:animalCareNear(body, radius or CARE_RADIUS)
    end)
    if not ok or type(answer) ~= "string" or answer == "" then return {} end
    local animals = {}
    for row in answer:gmatch("[^|]+") do
        local animal = parse(row)
        if animal then animals[#animals + 1] = animal end
    end
    return animals
end

local function carriedNamed(body, name)
    local found = nil
    pcall(function()
        local items = SAOJavaBridge:privateCarriedItems(body)
        for index = 0, items:size() - 1 do
            local item = items:get(index)
            local kind = string.lower(tostring(item:getFullType() or ""))
            if kind:find(name, 1, true) then
                found = item
                break
            end
        end
    end)
    return found
end

local function target(body, animal, radius)
    local ok, answer = pcall(function()
        return SAOJavaBridge:animalCareTarget(body, animal.id, radius)
    end)
    return ok and answer or nil
end

local function hutchEgg(body, animal, radius)
    local okB, box = pcall(function()
        return SAOJavaBridge:animalCareNestBox(body, animal.id, radius)
    end)
    local okH, hutch = pcall(function()
        return SAOJavaBridge:animalCareHutch(body, animal.id, radius)
    end)
    return okB and okH and box or nil, okB and okH and hutch or nil
end

local function queue(make)
    if not ISTimedActionQueue then return false end
    local ok = pcall(function() ISTimedActionQueue.add(make()) end)
    return ok
end

local function tryCare(body, animal, kind, tools, radius, rec)
    if kind == "milk" and ISMilkAnimal and tools.bucket then
        local bodyAnimal = target(body, animal, radius)
        return bodyAnimal and queue(function()
            return ISMilkAnimal:new(body, bodyAnimal, tools.bucket, true, false)
        end)
    end
    if kind == "shear" and ISShearAnimal and tools.shears then
        local bodyAnimal = target(body, animal, radius)
        return bodyAnimal and queue(function()
            return ISShearAnimal:new(body, bodyAnimal, tools.shears)
        end)
    end
    if kind == "eggs" and ISHutchGrabEgg then
        local box, hutch = hutchEgg(body, animal, radius)
        return box and hutch and queue(function()
            return ISHutchGrabEgg:new(body, box, hutch)
        end)
    end
    if kind == "water" and ISAddWaterToTrough and tools.water then
        local ok, trough = pcall(function()
            return SAOJavaBridge:animalCareTrough(body, animal.id, radius)
        end)
        return ok and trough and queue(function()
            return ISAddWaterToTrough:new(body, trough, tools.water, false)
        end)
    end
    if kind == "feed" and ISFeedAnimalFromHand then
        local ok, food = pcall(function()
            return SAOJavaBridge:animalCareFeed(body, animal.id, radius)
        end)
        local bodyAnimal = target(body, animal, radius)
        return ok and food and bodyAnimal and queue(function()
            local action = ISFeedAnimalFromHand:new(body, bodyAnimal, food)
            action.saoAnimalCareAdmission = { id = tostring(rec.id), rec = rec, body = body,
                animal = bodyAnimal, item = food, epoch = A.careEpoch }
            return action
        end)
    end
    if kind == "pet" and ISPetAnimal then
        local bodyAnimal = target(body, animal, radius)
        return bodyAnimal and queue(function()
            return ISPetAnimal:new(body, bodyAnimal)
        end)
    end
    return false
end

local function choice(animal, tools)
    if not animal.wild then
        if animal.milk and tools.bucket then return 1, "milk" end
        if animal.shear and tools.shears then return 2, "shear" end
        if animal.eggs > 0 and animal.hutches > 0 then return 3, "eggs" end
        if animal.thirst > 0 and animal.water < animal.maxWater and tools.water then
            return 4, "water"
        end
        if animal.hunger > 0 and animal.handFeed then return 5, "feed" end
        if animal.stress > 0 or animal.acceptance < animal.zoneAcceptance then
            return 6, "pet"
        end
    end
    return nil
end

-- A single care action per farm cadence. Product readiness comes from the
-- animal; then the ranch's actual water capacity, hand-feed list, and finally
-- a stress or acceptance need decide. The timed action owns final validity.
function A.care(id, body, radius)
    if not SAOJavaBridge or not body then return nil end
    local ok, owned = pcall(careOwner, id, body)
    if not ok or not owned then return nil end
    A.deliverCareOutcomes(id)
    radius = radius or CARE_RADIUS
    local okW, water = pcall(function() return SAOJavaBridge:animalCareWater(body) end)
    local tools = {
        bucket = carriedNamed(body, "bucket"),
        shears = carriedNamed(body, "scissors") or carriedNamed(body, "shear"),
        water = okW and water or nil,
    }
    local best = nil
    for _, animal in ipairs(A.read(body, radius)) do
        local rank, kind = choice(animal, tools)
        if rank and kind and carePositionPermission(id, animal.x, animal.y) then
            local dx, dy = animal.x - body:getX(), animal.y - body:getY()
            local candidate = {
                animal = animal, rank = rank, kind = kind,
                distance = dx * dx + dy * dy,
            }
            if not best or candidate.rank < best.rank
                or (candidate.rank == best.rank
                    and (candidate.distance < best.distance
                        or (candidate.distance == best.distance
                            and candidate.animal.id < best.animal.id))) then
                best = candidate
            end
        end
    end
    if best and tryCare(body, best.animal, best.kind, tools, radius, owned) then
        log(id .. " queued " .. best.kind .. " for " .. best.animal.type)
        return best.kind
    end
    return nil
end

-- Horse riding uses the source-owned Horse machinery rather than a second
-- vehicle system. `HorseRiding` alone is not an association: the mount map
-- must still name a loaded horse whose engine animal id is the persisted fact.
function A.mountedHorse(body)
    if not body then return nil end
    local variable = AnimationVariable and AnimationVariable.RIDING_HORSE
        or "HorseRiding"
    local okRiding, riding = pcall(function()
        return body:getVariableBoolean(variable)
    end)
    if not okRiding or not riding then return nil end
    local okHas, has = pcall(function() return Mounts.hasMount(body) end)
    if not okHas or not has then return nil end
    local okHorse, horse = pcall(function() return Mounts.getMount(body) end)
    if not okHorse or horse == nil then return nil end
    local okType, kind = pcall(function() return horse:getAnimalType() end)
    if not okType or (kind ~= "stallion" and kind ~= "mare") then return nil end
    local okId, animalId = pcall(function() return horse:getAnimalID() end)
    return okId and { animal = horse, animalId = animalId } or nil
end

local function personRecord(body)
    local id = nil
    pcall(function() id = body:getModData().SAOPersonId end)
    return id, id and SAO.Identity and SAO.Identity.get(id) or nil
end

local function horseId(horse)
    local ok, value = pcall(function() return horse:getAnimalID() end)
    return ok and value or nil
end

function A.horseById(animalId)
    if animalId == nil then return nil end
    local horse = HorseManager.findHorseByID(tonumber(animalId))
    if horse then return horse end
    local animals = getCell() and getCell():getAnimals() or nil
    if not animals then return nil end
    for index = 0, animals:size() - 1 do
        local candidate = animals:get(index)
        if horseId(candidate) == tonumber(animalId) then return candidate end
    end
    return nil
end

-- The durable record keeps the actual animal id and last physical state. The
-- native animal remains the world entity; this record lets a rematerialized
-- survivor know which relationship and unfinished journey existed.
Mounts.onMount:add(function(body, horse)
    local id, rec = personRecord(body)
    local animalId = horseId(horse)
    if not rec or not animalId then return end
    rec.horseMount = rec.horseMount or { schema = 1 }
    rec.horseMount.animalId = animalId
    rec.horseMount.active = true
    rec.horseMount.mountedAtHours = SAO.History.countyHours()
    rec.horseMount.x, rec.horseMount.y, rec.horseMount.z =
        horse:getX(), horse:getY(), horse:getZ()
    log(id .. " mounted horse " .. tostring(animalId))
end)

Mounts.onDismount:add(function(body, horse)
    local id, rec = personRecord(body)
    if not rec then return end
    rec.horseMount = rec.horseMount or { schema = 1 }
    rec.horseMount.active = false
    rec.horseMount.dismountedAtHours = SAO.History.countyHours()
    if horse then
        rec.horseMount.animalId = horseId(horse) or rec.horseMount.animalId
        rec.horseMount.x, rec.horseMount.y, rec.horseMount.z =
            horse:getX(), horse:getY(), horse:getZ()
    end
    log(id .. " dismounted horse " .. tostring(rec.horseMount.animalId))
end)

local function mayRide(id)
    local rec = SAO.Identity and SAO.Identity.get(id)
    if not rec or rec.dead then return false end
    local age = SAO.History and SAO.History.ageOf and SAO.History.ageOf(id) or 18
    if tonumber(age) and age < 10 then return false end
    local husbandry = SAO.Census and SAO.Census.skillOf
        and SAO.Census.skillOf(id, "Husbandry") or -1
    return husbandry >= 1 or rec.occupation == "rancher"
        or rec.occupation == "farmer"
end

local function candidateHorse(body)
    local mounted = Mounts.getMount(body)
    if mounted then return mounted end
    return MountingUtility.getBestMountableHorse(body, TRAVEL_MOUNT_RADIUS)
end

function A.canTravel(id, body, gx, gy, gz)
    if not body or not mayRide(id) or math.floor(body:getZ()) ~= math.floor(gz) then
        return false
    end
    local dx, dy = gx - body:getX(), gy - body:getY()
    return dx * dx + dy * dy >= TRAVEL_MIN_TILES * TRAVEL_MIN_TILES
        and candidateHorse(body) ~= nil
end

local function rememberHorse(id, horse, source)
    if not (SAO.ProceduralPlanning and horse) then return end
    local animalId = horseId(horse)
    if not animalId then return end
    SAO.ProceduralPlanning.rememberSpatial(id, {
        key = "horse:" .. tostring(animalId), kind = "horse",
        x = horse:getX(), y = horse:getY(), z = horse:getZ(),
        source = source or "observed", confidence = 1, familiarity = 0.35,
        routeKnown = true, usable = true,
        tags = { "animal", "mount", "transport", "care" },
    })
end

local function planResult(id, job, owner, token, status, reason)
    if not (job.purposeId and SAO.ProceduralPlanning) then return end
    SAO.ProceduralPlanning.recordResult(id, job.purposeId, {
        owner = owner, token = token, status = status, reason = reason,
    })
end

function A.orderTravel(id, body, gx, gy, gz, running)
    if not A.canTravel(id, body, gx, gy, gz) then return false end
    local horse = candidateHorse(body)
    local purpose = SAO.ProceduralPlanning and SAO.ProceduralPlanning.planHorseTravel(id, {
        animalId = horseId(horse), known = true, mountable = true,
        destinationKey = string.format("%.0f,%.0f,%d", gx, gy, gz),
    }) or nil
    local job = { body = body, horse = horse, animalId = horseId(horse),
        goal = { x = gx, y = gy, z = gz }, running = running == true,
        phase = Mounts.hasMount(body) and "routing" or "mounting",
        purposeId = purpose and purpose.id or nil, unchanged = 0,
        lastX = body:getX(), lastY = body:getY() }
    A.travelJobs[id] = job
    rememberHorse(id, horse, "observed")
    if job.phase == "mounting" then
        local position = MountingUtility.getNearestMountPosition(body, horse,
            TRAVEL_MOUNT_RADIUS)
        if not position then A.travelJobs[id] = nil; return false end
        Mounting.mountHorse(body, horse, position)
    else
        planResult(id, job, "HorseMount", "horse:reached", "completed")
        planResult(id, job, "HorseMount", "horse:mounted", "completed")
        local verdict = tostring(SAOJavaBridge:moveTo(body, gx, gy, gz))
        if not verdict:find("MOVE_STARTED", 1, true) then
            A.travelJobs[id] = nil
            return false
        end
    end
    log(id .. " begins horse travel with " .. tostring(job.animalId))
    return true
end

local function direction(job)
    local tx, ty = job.waypointX or job.goal.x, job.waypointY or job.goal.y
    local x, y = job.horse:getX(), job.horse:getY()
    local dx, dy = tx - x, ty - y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < TRAVEL_HEADING_MIN_LENGTH then return 0, 0 end
    -- Horse interprets keyboard/joypad axes in screen space, then RotLefts the
    -- resulting IsoDirection into world space. Convert the desired world
    -- heading through the inverse transform so autonomous riders do not orbit
    -- a waypoint ninety degrees off course.
    local inputDirection = IsoDirections.fromAngle(dx / length, dy / length):RotRight()
    return inputDirection:dx(), inputDirection:dy()
end

local function mountInput(id, job)
    return function()
        local x, y = direction(job)
        local stamina = Stamina.get(job.horse)
        local far = (job.goal.x - job.horse:getX()) ^ 2
            + (job.goal.y - job.horse:getY()) ^ 2 > 20 * 20
        return { movement = { x = x, y = y },
            run = job.running and far and stamina >= 25,
            trot = not job.running or stamina < 25, jump = false }
    end
end

local function routePoint(body)
    local answer = tostring(SAOJavaBridge:horseRoutePoint(body))
    local x, y, z = answer:match("^WAYPOINT@([^@]+)@([^@]+)@([^@]+)$")
    if x then return "waypoint", tonumber(x), tonumber(y), tonumber(z) end
    if answer == "ROUTE_WORKING" then return "working" end
    if answer == "ROUTE_SUCCEEDED" then return "arrived" end
    return "failed", answer
end

function A.tickTravel(id)
    local job = A.travelJobs[id]
    if not job then return "failed:no-horse-job" end
    local mounted = A.mountedHorse(job.body)
    if job.phase == "mounting" then
        if not mounted then
            if not job.body:hasTimedActions() then
                planResult(id, job, "HorseMount", "horse:reached", "failed",
                    "mount-action-ended")
                A.travelJobs[id] = nil
                return "failed:mount-action-ended"
            end
            return "pending"
        end
        job.horse, job.phase = mounted.animal, "routing"
        planResult(id, job, "HorseMount", "horse:reached", "completed")
        planResult(id, job, "HorseMount", "horse:mounted", "completed")
        local verdict = tostring(SAOJavaBridge:moveTo(job.body,
            job.goal.x, job.goal.y, job.goal.z))
        if not verdict:find("MOVE_STARTED", 1, true) then
            planResult(id, job, "HorseTravel", "route:arrived", "failed", verdict)
            A.travelJobs[id] = nil
            return "failed:" .. verdict
        end
    elseif job.phase == "dismounting" then
        if mounted then return "pending" end
        planResult(id, job, "HorseMount", "horse:dismounted", "completed")
        A.travelJobs[id] = nil
        return "arrived"
    elseif not mounted then
        planResult(id, job, "HorseTravel", "route:arrived", "failed", "mount-lost")
        A.travelJobs[id] = nil
        return "failed:mount-lost"
    end
    local dx, dy = job.goal.x - job.horse:getX(), job.goal.y - job.horse:getY()
    if dx * dx + dy * dy <= TRAVEL_REACH * TRAVEL_REACH then
        local mount = HorseRiding.getMount(job.body)
        if mount then mount:setAutonomousInput(nil) end
        local position = MountingUtility.getNearestMountPosition(job.body, job.horse)
        planResult(id, job, "HorseTravel", "route:arrived", "completed")
        if position then
            Mounting.dismountHorse(job.body, job.horse, position)
            job.phase = "dismounting"
        else
            planResult(id, job, "HorseMount", "horse:dismounted", "failed",
                "no-dismount-position")
            A.travelJobs[id] = nil
            return "failed:no-dismount-position"
        end
        SAOJavaBridge:cancelMove(job.body)
        return "pending"
    end
    local state, x, y = routePoint(job.body)
    if state == "failed" then
        planResult(id, job, "HorseTravel", "route:arrived", "failed", x)
        A.travelJobs[id] = nil
        return "failed:" .. tostring(x)
    end
    if state == "arrived" then job.waypointX, job.waypointY = job.goal.x, job.goal.y
    elseif state == "waypoint" then job.waypointX, job.waypointY = x, y end
    local mount = HorseRiding.getMount(job.body)
    if not mount then return "pending" end
    mount:setAutonomousInput(mountInput(id, job))
    local moved = (job.horse:getX() - job.lastX) ^ 2
        + (job.horse:getY() - job.lastY) ^ 2 > 0.0025
    job.unchanged = moved and 0 or job.unchanged + 1
    job.lastX, job.lastY = job.horse:getX(), job.horse:getY()
    if job.unchanged >= TRAVEL_STALL_TICKS then
        mount:setAutonomousInput(nil)
        planResult(id, job, "HorseTravel", "route:arrived", "failed",
            "horse-route-stalled")
        A.travelJobs[id] = nil
        return "failed:horse-route-stalled"
    end
    return "pending"
end

function A.cancelTravel(id)
    local job = A.travelJobs[id]
    if not job then return end
    local mount = HorseRiding.getMount(job.body)
    if mount then mount:setAutonomousInput(nil) end
    pcall(function() SAOJavaBridge:cancelMove(job.body) end)
    A.travelJobs[id] = nil
end

function A.isTravelling(id) return A.travelJobs[id] ~= nil end

return A
