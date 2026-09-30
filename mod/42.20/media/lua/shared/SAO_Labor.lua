-- SAO_Labor.lua - work as pressure, capacity, material, and recognition.

SAO = SAO or {}
SAO.Labor = SAO.Labor or {}
local Labor = SAO.Labor

function Labor.capabilityOf(id)
    local capability = {}
    -- Who somebody was is the census's to say (DR-009), so this reads
    -- skills only; nothing here writes `occupation`.
    if SAO.Census then
        capability.canCook = (SAO.Census.skillOf(id, "Cooking") or -1) >= 0
        capability.canForage = (SAO.Census.skillOf(id, "PlantScavenging") or -1) >= 0
        capability.canTreat = (SAO.Census.skillOf(id, "Doctor") or -1) >= 0
    end
    return capability
end

function Labor.possible(id, tick, pressure)
    local work = {}
    local capability = Labor.capabilityOf(id)
    if capability.canCook then work[#work + 1] = "cook" end
    if capability.canForage then work[#work + 1] = "forage" end
    if capability.canTreat then work[#work + 1] = "treat" end
    if SAO.Standing and SAO.Standing.mayEngageZombie(id) then
        work[#work + 1] = "watch"
    end
    if pressure > 0.75 then work[#work + 1] = "urgent" end
    return work
end

function Labor.choose(id, tick, pressure)
    local possible = Labor.possible(id, tick, pressure)
    if #possible == 0 then return nil end
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local materialEnabled = not options or options.Material ~= false
    if materialEnabled and SAO.Material and SAO.Material.storeForPerson then
        local store = SAO.Material.storeForPerson(id)
        -- `next` is not in this engine's Lua, so the emptiness probe
        -- is a pairs walk that stops at the first entry.
        local stocked = false
        if store and store.items then
            for _ in pairs(store.items) do
                stocked = true
                break
            end
        end
        if stocked then
            possible[#possible + 1] = "quartermaster"
        end
    end
    local best, bestScore
    for _, work in ipairs(possible) do
        local score = pressure
        if SAO.Lessons and SAO.Lessons.has(id, work) then
            score = score + 0.15
        end
        if SAO.Standing and SAO.Standing.groupOf(id) then
            score = score + 0.10
        end
        if not bestScore or score > bestScore then
            best, bestScore = work, score
        end
    end
    return best
end

function Labor.recognize(id, work)
    if not SAO.Branching then return nil end
    return SAO.Branching.recognize(id, work)
end

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function unit(n)
    return finite(n) and math.max(0, math.min(1, n)) or nil
end
local function count(n)
    return finite(n) and math.max(0, math.min(1000000, n)) or 0
end
local function short(value)
    return type(value) == "string" and string.sub(value, 1, 256) or nil
end
local function placeCopy(value)
    if type(value) ~= "table" or value.id == nil
        or (type(value.id) ~= "string" and not finite(value.id))
        or not finite(value.cx) or not finite(value.cy) then return nil end
    local out = { id = value.id, cx = value.cx, cy = value.cy }
    for _, key in ipairs({ "z", "minX", "minY", "maxX", "maxY" }) do
        if finite(value[key]) then out[key] = value[key] end
    end
    return out
end
local function privateSource(id, source)
    if source.known ~= true or not source.itemId or not SAO.WorldSources
        or not SAO.WorldSources.privatelyKnowsItem then return false end
    local ok, known = pcall(SAO.WorldSources.privatelyKnowsItem,
        id, source.sourceId or source.id, source.itemId)
    if not ok or known ~= true then return false end
    local places = SAO.Perception.knownPlaces(id, true)
    for _, place in pairs(places or {}) do
        local fact = place.sourceFacts and place.sourceFacts[tostring(source.sourceId or source.id)]
        if fact and fact.revision == (source.revision or source.sourceRevision) then return true end
    end
    return false
end
local function inspectedPlace(id, value)
    local place = placeCopy(value)
    local known = SAO.Perception and SAO.Perception.knownPlaces
        and SAO.Perception.knownPlaces(id, true) or nil
    local belief = place and known and (known[place.id] or known[tostring(place.id)])
    if belief and belief.cx == place.cx and belief.cy == place.cy then
        return place
    end
end

-- The caller supplies native own-inventory and private observation rows.
-- This assessment is a detached decision view, never an allocation or a
-- household total. Occupation remains prior life; no work role is assigned.
function Labor.assess(id, context)
    context = type(context) == "table" and context or {}
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or rec.dead then return nil, "person-unavailable" end
    local category = context.category
    if category ~= "food" and category ~= "water" then return nil, "unsupported-resource" end
    local needs = type(context.needs) == "table" and context.needs or {}
    local capacity = { fatigue = unit(needs.fatigue or context.fatigue),
        health = unit(needs.health or context.health),
        priorLife = short(rec.occupation), skills = {}, commitments = {},
        available = context.canWork ~= false and context.obligationActive ~= true }
    for _, skill in ipairs({ "Cooking", "PlantScavenging", "Doctor", "Fitness", "Strength" }) do
        local ok, level = pcall(function() return SAO.Census.skillOf(id, skill) end)
        local native = type(context.skills) == "table" and context.skills[skill]
        capacity.skills[skill] = finite(native) and native or ok and finite(level) and level or -1
    end
    local practiced = rec.proceduralPlanning and rec.proceduralPlanning.practice
        and rec.proceduralPlanning.practice.Cooking
    local samples = practiced and practiced.durationHours
    if type(samples) == "table" and #samples > 0 then
        local low, high, n
        n = 0
        for i, duration in ipairs(samples) do
            if i > 8 then break end
            if finite(duration) and duration >= 0 then
                low, high = low and math.min(low, duration) or duration,
                    high and math.max(high, duration) or duration
                n = n + 1
            end
        end
        if n > 0 then capacity.timeEvidence = { domain = "Cooking", samples = n,
            observedMinimumHours = low, observedMaximumHours = high,
            basis = "actor-native-admission-to-completed-result",
            uncertainty = "past durations do not establish future yield or access time" } end
    end
    for i, obligation in ipairs(type(context.commitments) == "table" and context.commitments or {}) do
        if i > 8 then break end
        if type(obligation) == "string" then
            capacity.commitments[#capacity.commitments + 1] = { id = short(obligation) }
        elseif type(obligation) == "table" then
            capacity.commitments[#capacity.commitments + 1] = { id = short(obligation.id),
                owner = short(obligation.owner), status = short(obligation.status) }
        end
    end
    local contacts, seen = {}, {}
    for i, contact in ipairs(type(context.contacts) == "table" and context.contacts or {}) do
        if i > 16 then break end
        local who = type(contact) == "string" and short(contact)
            or type(contact) == "table" and short(contact.id)
        if who and who ~= id and not seen[who] then
            contacts[#contacts + 1] = who; seen[who] = true
        end
    end
    local out = { category = category, capacity = capacity, contacts = contacts,
        knownRisk = unit(context.knownRisk), options = {},
        demand = { pressure = unit(context.pressure) or 0,
            ownedReady = count(context.carriedReady), ownedRaw = count(context.carriedRaw),
            ownedWater = count(context.carriedWater), ownedHydration = count(context.carriedHydration),
            ownedItems = count(context.carriedItems),
            basis = "native-own-inventory-and-private-observations", confidence = "observed-stock",
            uncertainty = "future-use, access, yield and helper assent remain unconfirmed" } }
    local function add(option)
        option.blockers = capacity.available and 0 or 1
        option.uncertainty = "native permission, approach and completion revalidate during execution"
        option.technique = { domain = option.cooking and "Cooking"
                or option.kind == "refill-water" and "water collection" or "carrying",
            level = option.cooking and capacity.skills.Cooking or nil,
            fatigue = capacity.fatigue, health = capacity.health }
        -- Skill is evidence about technique, not a zero-level action gate.
        option.evidence = option.evidence - (out.knownRisk or 0) * 0.1
        out.options[#out.options + 1] = option
    end
    if category == "food" then
        for i, item in ipairs(type(context.carriedRawItems) == "table" and context.carriedRawItems or {}) do
            if i > 4 then break end
            if item.cookable == true and finite(item.itemId) and short(item.itemType) then
                add({ id = "prepare-owned:" .. tostring(item.itemId), kind = "prepare-owned",
                    itemId = item.itemId, itemType = short(item.itemType), cooking = true,
                    evidence = 1, continuity = 1, novelty = 0.1, informationGain = 0.3,
                    rationale = "prepare a currently held native raw item" })
            end
        end
    end
    local sources = {}
    for i, source in ipairs(type(context.sources) == "table" and context.sources or {}) do
        if i > 64 then break end
        local hydration = type(source) == "table" and category == "water"
            and context.hydrationIntent == true and context.purposeId == nil
            and source.materialCategory == "drink" and SAO.WorldSources.knownHydrationAmount
            and SAO.WorldSources.knownHydrationAmount(id, source.sourceId or source.id,
                source.itemId, source.revision or source.sourceRevision)
        if type(source) == "table" and source.category == category
            and (source.materialCategory == nil or source.materialCategory == category or hydration)
            and finite(source.itemId) and (tonumber(source.quantity) or 0) > 0 and privateSource(id, source)
            and short(source.revision or source.sourceRevision) and short(source.itemType) then
            local place = inspectedPlace(id, source.place)
            if place then
                local kind = category == "food" and source.cookable == true
                    and "acquire-prepare" or "acquire-ready"
                sources[#sources + 1] = { id = kind .. ":" .. tostring(source.sourceId or source.id)
                        .. ":" .. tostring(source.itemId), kind = kind,
                    sourceId = short(source.sourceId or source.id),
                    sourceRevision = short(source.revision or source.sourceRevision),
                    place = place, itemId = source.itemId, itemType = short(source.itemType),
                    category = category, materialCategory = hydration and "drink" or category,
                    hydrationIntent = hydration and true or nil, quantity = 1, quantityUnit = "item",
                    distance = count(source.distance), cooking = kind == "acquire-prepare",
                    evidence = kind == "acquire-prepare" and 0.85 or 0.9,
                    continuity = kind == "acquire-prepare" and 0.6 or 0.75,
                    novelty = 0.15, informationGain = kind == "acquire-prepare" and 0.35 or 0.2,
                    rationale = kind == "acquire-prepare"
                        and "acquire privately inspected raw food, then prepare the exact held item"
                        or "acquire one privately inspected usable resource item" }
            end
        end
    end
    table.sort(sources, function(a, b)
        if a.distance == b.distance then return a.id < b.id end
        return a.distance < b.distance
    end)
    for i, option in ipairs(sources) do
        if i > 8 then break end
        -- This is an ordinal preference for a shorter known approach, not a
        -- calibrated travel duration or production-rate claim.
        option.continuity = option.continuity + 0.1 / (1 + option.distance)
        add(option)
    end
    local production = SAO.ResourceProduction
    local productionCount = 0
    for i, candidate in ipairs(type(context.productionOptions) == "table" and context.productionOptions or {}) do
        if i > 16 then break end
        local place = type(candidate) == "table" and inspectedPlace(id, candidate.place)
        local private = false
        if place and production and production.privatelyKnown then
            local ok, known = pcall(production.privatelyKnown, id, candidate)
            private = ok and known == true
        end
        if private and category == "water" and candidate.category == category
            and candidate.kind == "refill-water" and candidate.owner == "SAO.ResourceProduction"
            and short(candidate.sourceId) and short(candidate.sourceRevision) and short(candidate.fingerprint)
            and finite(candidate.sourceX) and finite(candidate.sourceY) and finite(candidate.sourceZ)
            and finite(candidate.itemId) and short(candidate.itemType)
            and finite(candidate.beforeAmount) and finite(candidate.capacity)
            and candidate.beforeAmount >= 0 and candidate.capacity > candidate.beforeAmount then
            add({ id = "refill:" .. candidate.sourceId .. ":" .. candidate.sourceRevision
                    .. ":" .. tostring(candidate.itemId), kind = "refill-water",
                owner = "SAO.ResourceProduction", category = category, place = place,
                sourceId = candidate.sourceId, sourceRevision = candidate.sourceRevision,
                fingerprint = candidate.fingerprint, sourceX = candidate.sourceX,
                sourceY = candidate.sourceY, sourceZ = candidate.sourceZ,
                itemId = candidate.itemId, itemType = candidate.itemType,
                beforeAmount = candidate.beforeAmount, capacity = candidate.capacity,
                quantityUnit = "fluid", evidence = 0.85, continuity = 0.8,
                novelty = 0.15, informationGain = 0.3,
                rationale = "fill a currently held native vessel at a privately observed water fixture" })
            productionCount = productionCount + 1
        end
    end
    local inspect = inspectedPlace(id, context.inspectPlace)
    if inspect then
        add({ id = "inspect:" .. tostring(inspect.id), kind = "inspect", place = inspect,
            category = category, evidence = 0.45, continuity = 0.2, novelty = 0.9,
            informationGain = 1, rationale = "inspect a personally remembered place whose usable contents remain uncertain" })
    end
    if #out.options == 0 then
        out.blocker = category == "food" and out.demand.ownedRaw > 0
            and "owned-raw-identity-unavailable" or "no-known-executable-resource-route"
    elseif not capacity.available then
        out.blocker = context.obligationActive == true and "accepted-work-in-progress" or "current-body-unavailable-for-work"
    end
    local projects = {}
    local planning = rec.proceduralPlanning
    for _, key in ipairs(planning and planning.order or {}) do
        local purpose = planning.purposes and planning.purposes[key]
        if purpose and purpose.status ~= "completed" and purpose.status ~= "abandoned" then
            projects[#projects + 1] = { id = purpose.id, objective = short(purpose.objective),
                domain = purpose.domain, status = purpose.status }
            if #projects >= 8 then break end
        end
    end
    out.dimensions = {
        neededNow = { status = "observed", category = category, pressure = out.demand.pressure },
        capableActors = { status = "partial", self = id, contacts = contacts,
            gap = "other people's capacity and assent require their response" },
        timeClaims = { status = "observed", commitments = capacity.commitments },
        materialsAndSpace = { status = "partial", ownedItems = out.demand.ownedItems,
            privateOptions = #sources + productionCount,
            completeness = "partial", basis = "privately recognized native options",
            gap = "uninspected and unrecognized affordances remain unknown; access and appliance readiness revalidate natively" },
        openProjects = { status = "person-private", projects = projects,
            gap = "unacquired project and maintenance requests remain unknown" },
        groupValues = { status = "unknown", gap = "no acquired group requirement supplied to this decision" },
        lowPressureWish = { status = "open", activity = short(context.lowPressureActivity),
            gap = "low pressure leaves personal activity selection with its existing owners" },
        slack = { status = "unknown", personallyAvailable = capacity.available,
            gap = "own carried stock and contacts do not establish settlement surplus" },
    }
    return out
end

return Labor
