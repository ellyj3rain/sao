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

function A.forget(id)
    A.travelJobs[id] = nil
end

local function log(msg) SAO.Log.line("ANIMAL", msg) end

local function number(value)
    local n = tonumber(value)
    return n and n == n and n or nil
end

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

local function tryCare(body, animal, kind, tools, radius)
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
            return ISFeedAnimalFromHand:new(body, bodyAnimal, food)
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
        if rank and kind then
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
    if best and tryCare(body, best.animal, best.kind, tools, radius) then
        log(id .. " " .. best.kind .. "s " .. best.animal.type)
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
