-- SAO_Animals — the ranch's own bodies and actions ([C123]).
-- ---------------------------------------------------------------------------
-- Animal state belongs to Build 42. A designated ranch supplies its animals,
-- troughs and hutches; this module only chooses among the state the engine
-- reports and queues its own actions with opaque real objects. There is no
-- animal inventory, product table, or horse implementation here.

SAO = SAO or {}
SAO.Animals = SAO.Animals or {}
local A = SAO.Animals

local CARE_RADIUS = 3

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
        local items = body:getInventory():getItems()
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

-- Horse riding is optional Horse Mod machinery, not a second vehicle system.
-- `HorseRiding` alone is not an association: the mod's mount map must still
-- name a loaded horse, whose engine animal id is the persisted fact.
function A.mountedHorse(body)
    if not body or not Mounts or type(Mounts.hasMount) ~= "function"
        or type(Mounts.getMount) ~= "function" then return nil end
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

return A