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

-- Residence uses the same private evidence as immediate work. A remembered
-- building is a lead, even when its contents have never been inspected.
function Labor.assessResidence(id, context)
    context = type(context) == "table" and context or {}
    local rec = SAO.Identity and SAO.Identity.get(id)
    local position = context.position
    if not rec or rec.dead or type(position) ~= "table"
        or type(position.x) ~= "number" or type(position.y) ~= "number" then return nil end
    local needs = context.needs or {}
    local standing, perception = SAO.Standing, SAO.Perception
    local known = perception and perception.knownPlaces and perception.knownPlaces(id) or {}
    local tick = tonumber(context.tick) or 0
    local out = { personId = id, atHours = context.atHours,
        capacity = { fatigue = needs.fatigue, health = context.health,
            canMove = context.canMove ~= false },
        needs = { hunger = needs.hunger, thirst = needs.thirst },
        home = rec.homeX and rec.homeY and { x = rec.homeX, y = rec.homeY, z = rec.homeZ or 0 } or nil,
        homeDanger = { status = "unknown", count = 0 }, conflict = 0,
        attachment = 0, responsibilities = 0, candidates = {},
        stock = "unknown-until-private-inspection", routeCoverage = "unknown",
        currentResourceOwner = context.currentResourceOwner == true,
        localRelief = context.localRelief == true, recoveryKind = context.recoveryKind }
    if out.home and perception and perception.believedThreatCount then
        out.homeDanger.count = perception.believedThreatCount(id, tick, 12, rec.homeX, rec.homeY)
        if out.homeDanger.count > 0 then out.homeDanger.status = "remembered-danger" end
    end
    for otherId, relation in pairs(standing and standing.relationsOf and standing.relationsOf(id) or {}) do
        if type(relation) == "table" and otherId ~= id then
            if standing.sameGroup and standing.sameGroup(id, otherId) then
                if relation.hostile then out.conflict = out.conflict + 1 end
                if tonumber(relation.trust) and relation.trust > 0 then
                    out.attachment = out.attachment + relation.trust
                end
            end
        end
    end
    if SAO.Organization and SAO.Organization.activeCommitments then
        for index, obligation in ipairs(SAO.Organization.activeCommitments(id) or {}) do
            if index > 8 then break end
            if type(obligation.acceptedAt) == "number"
                and obligation.acceptedAt <= (context.atHours or 0) then
                out.responsibilities = out.responsibilities + 1
            end
        end
    end
    local inspected = 0
    for key, belief in pairs(known) do
        inspected = inspected + 1
        if inspected > 128 then break end
        if type(belief) == "table" and type(belief.cx) == "number" and type(belief.cy) == "number"
            and not belief.sourceId and belief.cx == belief.cx and belief.cy == belief.cy then
            local z = tonumber(belief.z) or 0
            local atHome = out.home and belief.cx >= (belief.minX or belief.cx)
                and rec.homeX >= (belief.minX or belief.cx) and rec.homeX <= (belief.maxX or belief.cx)
                and rec.homeY >= (belief.minY or belief.cy) and rec.homeY <= (belief.maxY or belief.cy)
            if atHome and z == (rec.homeZ or 0) and standing
                and standing.mayAttemptBelieved(id, rec.homeX, rec.homeY, "standing") then
                out.recoveryHome = true
            end
            if not atHome and standing and standing.mayAttemptBelieved(id, belief.cx, belief.cy, "standing") then
                local danger = perception.believedThreatCount
                    and perception.believedThreatCount(id, tick, 12, belief.cx, belief.cy) or 0
                local dx, dy = belief.cx - position.x, belief.cy - position.y
                out.candidates[#out.candidates + 1] = { id = tostring(key),
                    cx = belief.cx, cy = belief.cy, z = z,
                    minX = belief.minX, minY = belief.minY, maxX = belief.maxX, maxY = belief.maxY,
                    distance = math.sqrt(dx * dx + dy * dy), visits = tonumber(belief.visits) or 0,
                    acquiredAt = belief.at, source = belief.source,
                    danger = danger, dangerStatus = danger > 0 and "remembered-danger" or "unknown",
                    stock = "unknown-until-private-inspection" }
            end
        end
    end
    -- Seeing an exterior establishes a possible place to inspect. It carries
    -- only the outside approach personally observed by this actor.
    local exteriorInspected = 0
    for key, belief in pairs(perception and perception.knownBuildingLeads
        and perception.knownBuildingLeads(id, tick) or {}) do
        exteriorInspected = exteriorInspected + 1
        if exteriorInspected > 64 then break end
        if standing and standing.mayAttemptBelieved(id, belief.cx, belief.cy, "standing") then
            local danger = perception.believedThreatCount
                and perception.believedThreatCount(id, tick, 12, belief.cx, belief.cy) or 0
            local dx, dy = belief.cx - position.x, belief.cy - position.y
            out.candidates[#out.candidates + 1] = { id = "exterior:" .. key,
                buildingId = belief.buildingId, approachId = key,
                exterior = true, cx = belief.cx, cy = belief.cy, z = belief.z,
                surfaceX = belief.surfaceX, surfaceY = belief.surfaceY, kind = belief.kind,
                apertureState = belief.apertureState, entryFailure = belief.entryFailure,
                distance = math.sqrt(dx * dx + dy * dy), visits = 0,
                acquiredAt = belief.at, source = belief.source, danger = danger,
                dangerStatus = danger > 0 and "remembered-danger" or "unknown",
                stock = "unknown-until-private-inspection" }
        end
    end
    table.sort(out.candidates, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.id < b.id
    end)
    while #out.candidates > 16 do table.remove(out.candidates) end
    return out
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
    out.sourceId = short(value.sourceId)
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
        if fact and fact.revision == (source.revision or source.sourceRevision) then return fact end
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

local function position(x, y, z)
    if finite(x) and finite(y) and finite(z) then return { x = x, y = y, z = z } end
end
local function distance(a, b)
    if not a or not b or a.z ~= b.z then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
local function travelCost(tiles) return tiles and tiles / (tiles + 32) or 0 end

-- These readers supply only this actor's acquired requests and actual assent.
-- Neither a contact nor group membership supplies another person's capacity.
local function socialAppraisal(id, category, at)
    local out = { requests = {}, responsibilities = {}, concern = 0,
        uncertainty = "requests remain unsatisfied; response, carrying and delivery retain their owners" }
    if not finite(at) then return out end
    local perception = SAO.Perception
    local ok, requests = pcall(function() return perception.knownAidRequests(id, at) end)
    for i, request in ipairs(ok and type(requests) == "table" and requests or {}) do
        if i > 8 then break end
        if request.category == category and finite(request.acquiredAt)
            and finite(request.requestedAt) and request.requestedAt >= 0 and request.requestedAt <= request.acquiredAt
            and request.acquiredAt <= at and (request.source == "requested" or request.source == "told") then
            local willing, accepts = false, nil
            if type(request.originId) == "string" and request.originId ~= "" and request.originId ~= id then
                willing, accepts = pcall(function()
                    return SAO.Disposition.wouldGiveToStranger(id, request.originId)
                end)
            end
            local row = { groupId = short(request.groupId),
                originId = short(request.originId), source = request.source,
                requestedAt = request.requestedAt, acquiredAt = request.acquiredAt,
                teller = short(request.teller), processId = short(request.processId),
                processRevision = request.processRevision }
            if willing then row.willing = accepts == true end
            out.requests[#out.requests + 1] = row
            if willing and accepts == true then out.concern = math.max(out.concern, 0.5) end
        end
    end
    local available, obligations = pcall(function() return SAO.Organization.activeCommitments(id) end)
    for i, obligation in ipairs(available and type(obligations) == "table" and obligations or {}) do
        if i > 8 then break end
        local scope = type(obligation.scope) == "table" and obligation.scope or {}
        if obligation.actorId == id and finite(obligation.acceptedAt) and obligation.acceptedAt >= 0 and obligation.acceptedAt <= at
            and scope.category == category and scope.action == "deliver-material" then
            out.responsibilities[#out.responsibilities + 1] = { id = short(obligation.id),
                actorId = id, beneficiaryId = short(obligation.beneficiaryId), acceptedAt = obligation.acceptedAt,
                status = short(obligation.status), processId = short(obligation.processId) }
            out.concern = 1
        end
    end
    return out
end

local function routeAppraisal(id, rec, context, option, social)
    local own = type(context.position) == "table" and position(context.position.x, context.position.y, context.position.z)
    local target = option.kind == "build-rain-collector" and option.site
        and position(option.site.x, option.site.y, option.site.z) or position(option.sourceX, option.sourceY, option.sourceZ)
    if option.kind == "prepare-owned" then target = own end
    if target then target.basis = option.kind == "prepare-owned" and "native-own-position"
        or option.kind == "inspect" and "personally-observed-container-location"
        or "actor-private-source-position" end
    local home = position(rec.homeX, rec.homeY, rec.homeZ)
    local outward, returning = distance(own, target), distance(target, home)
    local danger = { status = "unknown", ordinal = 0,
        uncertainty = "absence of a remembered threat does not establish safety; the whole route remains unobserved" }
    if target and finite(context.tick) and context.tick >= 0 then
        local counted, n = pcall(function()
            return SAO.Perception.believedThreatCount(id, context.tick, 12, target.x, target.y)
        end)
        local found, nearest = pcall(function()
            return SAO.Perception.nearestBelievedThreat(id, context.tick, target.x, target.y)
        end)
        if counted and finite(n) and n >= 0 then
            danger.believedCount = n
            if n > 0 then danger.status, danger.ordinal = "partial", n / (n + 2) end
        end
        if found and type(nearest) == "table" and finite(nearest.dist) and nearest.dist >= 0 then
            danger.status = "partial"
            danger.nearest = { distance = nearest.dist, at = nearest.at,
                source = short(nearest.source), fromPerson = nearest.fromPerson == true,
                form = short(nearest.form) }
            local geometry=SAO.CognitiveModels and SAO.CognitiveModels.contactGeometry
                and SAO.CognitiveModels.contactGeometry({distance=nearest.dist,z=nearest.z,observerZ=target.z})
            if geometry then
                danger.nearest.z,danger.nearest.observerZ=nearest.z,target.z
                danger.nearest.floorKnown,danger.nearest.sameFloor=geometry.floorKnown,geometry.sameFloor
                danger.nearest.reachability=geometry.reachability
                if geometry.sameFloor==false then danger.uncertainty=danger.uncertainty
                    .. "; the contact is remembered on another floor; a usable path and physical reach are unconfirmed" end
            end
            danger.ordinal = math.max(danger.ordinal, 12 / (12 + nearest.dist))
        end
    end
    return { actorId = id, target = target, danger = danger,
        travel = { outwardTiles = outward, returnTiles = returning,
            outwardCost = travelCost(outward), returnCost = travelCost(returning), home = home,
            basis = "own-native-position-and-own-home; straight-line ordinal comparison",
            uncertainty = "barriers, duration and the return route remain unconfirmed" },
        social = social, requestValue = social.concern * (option.kind == "inspect" and 0.5 or 1) }
end

-- These are conditional consequences of already admitted private options.
-- Acquiring material may help a received request; it never predicts that a
-- recipient accepted it or that delivery has happened.
local function resourceConsequences(option, category, concern)
    local out = {}
    local value = 0.8 + (concern or 0) * 0.4
    if option.kind == "inspect" then
        out[1] = { kind = "inspect", category = category,
            sourceId = option.place and option.place.sourceId, value = value * 0.5 }
    elseif option.kind == "acquire-ready" or option.kind == "acquire-prepare" then
        out[1] = { kind = "acquire", category = category,
            sourceId = option.sourceId, itemType = option.itemType, value = value }
    elseif option.kind == "plumb-fixture" then
        out[1] = { kind = "plumb", category = "construction", sourceId = option.sourceId,
            itemType = option.toolItemType, value = 0.5 }
    elseif option.kind == "build-rain-collector" then
        out[1] = { kind = "construct", category = "construction", sourceId = option.sourceId,
            itemType = option.entityId, value = 0.5 }
    end
    if option.cooking then
        out[#out + 1] = { kind = "prepare", category = "food",
            itemType = option.itemType, value = value }
    end
    return out
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
    for _, skill in ipairs({ "Cooking", "PlantScavenging", "Doctor", "Fitness", "Strength", "Woodwork" }) do
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
    local social = socialAppraisal(id, category, context.atHours)
    local function add(option)
        option.blockers = capacity.available and 0 or 1
        option.uncertainty = "native permission, approach and completion revalidate during execution"
        option.technique = { domain = option.cooking and "Cooking"
                or option.kind == "refill-water" and "water collection"
                or option.kind == "build-rain-collector" and "Woodwork"
                or option.kind == "plumb-fixture" and "plumbing" or "carrying",
            level = option.cooking and capacity.skills.Cooking or option.kind == "build-rain-collector" and capacity.skills.Woodwork or nil,
            fatigue = capacity.fatigue, health = capacity.health }
        -- Skill is evidence about technique, not a zero-level action gate.
        option.appraisal = option.appraisal or routeAppraisal(id, rec, context, option, social)
        option.consequences = resourceConsequences(option, category, social.concern)
        if not finite(context.tick) then option.evidence = option.evidence - (out.knownRisk or 0) * 0.1 end
        option.uncertainty = option.uncertainty .. "; " .. option.appraisal.danger.uncertainty
            .. "; " .. option.appraisal.travel.uncertainty .. "; " .. social.uncertainty
        option.rationale = option.rationale .. "; compare personally believed destination danger, own approach and home return"
            .. (#social.requests > 0 and "; acquired food request remains unsatisfied" or "")
            .. (#social.responsibilities > 0 and "; accepted delivery responsibility remains unsatisfied" or "")
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
                local fact = privateSource(id, source)
                local kind = category == "food" and source.cookable == true
                    and "acquire-prepare" or "acquire-ready"
                sources[#sources + 1] = { id = kind .. ":" .. tostring(source.sourceId or source.id)
                        .. ":" .. tostring(source.itemId), kind = kind,
                    sourceId = short(source.sourceId or source.id),
                    sourceRevision = short(source.revision or source.sourceRevision),
                    sourceX = fact and fact.x, sourceY = fact and fact.y, sourceZ = fact and fact.z,
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
    for _, option in ipairs(sources) do
        option.continuity = option.continuity + 0.1 / (1 + option.distance)
        option.blockers = capacity.available and 0 or 1
        option.appraisal = routeAppraisal(id, rec, context, option, social)
        option.consequences = resourceConsequences(option, category, social.concern)
    end
    table.sort(sources, function(a, b)
        if SAO.CognitiveModels and SAO.CognitiveModels.planScore then
            local sa = SAO.CognitiveModels.planScore("ordinary", a, out.demand.pressure)
            local sb = SAO.CognitiveModels.planScore("ordinary", b, out.demand.pressure)
            sa, sb = sa or -math.huge, sb or -math.huge
            if sa ~= sb then return sa > sb end
        end
        if a.distance == b.distance then return a.id < b.id end
        return a.distance < b.distance
    end)
    for _, option in ipairs(sources) do
        -- The input is bounded at 64. Purpose-specific retry and continuity
        -- appraisal precede the planner's single candidate bound.
        -- This is an ordinal preference for a shorter known approach, not a
        -- calibrated travel duration or production-rate claim.
        add(option)
    end
    local production = SAO.ResourceProduction
    local collectorMaterials = { hammer = true, plank = true, nails = true, ["garbage-bag"] = true, tarp = true }
    out.materialSources = {}
    for i, source in ipairs(type(context.materialSources) == "table" and context.materialSources or {}) do
        if i > 128 then break end
        if type(source) == "table" and collectorMaterials[source.category] and source.known == true
            and finite(source.itemId) and short(source.itemType) and short(source.sourceId)
            and short(source.revision) and privateSource(id, source) and inspectedPlace(id, source.place) then
            out.materialSources[#out.materialSources + 1] = source
        end
    end
    out.toolSources = {}
    for i, source in ipairs(type(context.toolSources) == "table" and context.toolSources or {}) do
        if i > 128 then break end
        if type(source) == "table" and source.category == "pipe-wrench" and source.known == true
            and finite(source.itemId) and short(source.itemType) and short(source.sourceId)
            and short(source.revision) and privateSource(id, source) and inspectedPlace(id, source.place) then
            out.toolSources[#out.toolSources + 1] = source
        end
    end
    local productionCount = 0
    for i, candidate in ipairs(type(context.productionOptions) == "table" and context.productionOptions or {}) do
        if i > 16 then break end
        local place = type(candidate) == "table" and inspectedPlace(id, candidate.place)
        local private = false
        if place and production and production.privatelyKnown then
            local ok, known = pcall(production.privatelyKnown, id, candidate)
            private = ok and known == true
        end
        if type(candidate) == "table" and candidate.kind == "build-rain-collector" then
            local observed = false
            local body = SAO.Body and SAO.Body.active and SAO.Body.active[id]
            local ok, sites = pcall(function() return SAO.Perception.collectorSites(id, body) end)
            for _, site in ipairs(ok and type(sites) == "table" and sites or {}) do
                local selected = candidate.site
                if type(selected) == "table" and site.key == selected.key and site.revision == selected.revision
                    and site.x == selected.x and site.y == selected.y and site.z == selected.z
                    and site.observedAtHours == selected.observedAtHours then observed = true; break end
            end
            private = private and observed
        end
        if private and category == "water" and candidate.category == category
            and (candidate.kind == "refill-water" or candidate.kind == "plumb-fixture"
                and candidate.toolCategory == "pipe-wrench" or candidate.kind == "build-rain-collector"
                and short(candidate.entityId) and short(candidate.recipeId) and type(candidate.site) == "table"
                and short(candidate.site.key) and short(candidate.site.revision)
                and finite(candidate.site.x) and finite(candidate.site.y) and finite(candidate.site.z)
                and finite(candidate.site.observedAtHours) and type(candidate.requirements) == "table"
                and #candidate.requirements > 0 and #candidate.requirements <= 8
                and type(candidate.inputs) == "table" and #candidate.inputs <= 16) and candidate.owner == "SAO.ResourceProduction"
            and short(candidate.sourceId) and short(candidate.sourceRevision) and short(candidate.fingerprint)
            and finite(candidate.sourceX) and finite(candidate.sourceY) and finite(candidate.sourceZ)
            and finite(candidate.itemId) and short(candidate.itemType)
            and finite(candidate.beforeAmount) and finite(candidate.capacity)
            and candidate.beforeAmount >= 0 and candidate.capacity > candidate.beforeAmount then
            local site, requirements, inputs
            if candidate.kind == "build-rain-collector" then
                site = { key = candidate.site.key, revision = candidate.site.revision, x = candidate.site.x,
                    y = candidate.site.y, z = candidate.site.z, observedAtHours = candidate.site.observedAtHours }
                requirements, inputs = {}, {}
                for _, required in ipairs(candidate.requirements) do
                    requirements[#requirements + 1] = { inputIndex = required.inputIndex, mode = required.mode,
                        count = required.count, category = required.category }
                end
                for _, input in ipairs(candidate.inputs) do
                    inputs[#inputs + 1] = { inputIndex = input.inputIndex, itemId = input.itemId,
                        itemType = input.itemType, mode = input.mode }
                end
            end
            add({ id = (candidate.kind == "build-rain-collector" and "collector:" or candidate.kind == "plumb-fixture" and "plumb:" or "refill:")
                    .. candidate.sourceId .. ":" .. candidate.sourceRevision
                    .. ":" .. tostring(candidate.itemId) .. (site and ":" .. candidate.entityId .. ":" .. site.key .. ":" .. site.revision or ""), kind = candidate.kind,
                owner = "SAO.ResourceProduction", category = category, place = place,
                sourceId = candidate.sourceId, sourceRevision = candidate.sourceRevision,
                fingerprint = candidate.fingerprint, sourceX = candidate.sourceX,
                sourceY = candidate.sourceY, sourceZ = candidate.sourceZ,
                itemId = candidate.itemId, itemType = candidate.itemType,
                toolCategory = candidate.toolCategory, toolItemId = candidate.toolItemId,
                toolItemType = candidate.toolItemType,
                entityId = candidate.entityId, recipeId = candidate.recipeId, site = site, requirements = requirements, inputs = inputs,
                beforeAmount = candidate.beforeAmount, capacity = candidate.capacity,
                quantityUnit = "fluid", evidence = 0.85, continuity = 0.8,
                novelty = 0.15, informationGain = 0.3,
                rationale = candidate.kind == "build-rain-collector"
                    and "construct a rain collector at a personally observed site, then reassess actual supply"
                    or candidate.kind == "plumb-fixture"
                    and "connect a privately observed eligible fixture, then reassess actual usable water"
                    or "fill a currently held native vessel at a privately observed water fixture" })
            productionCount = productionCount + 1
        end
    end
    local inspect = inspectedPlace(id, context.inspectPlace)
    if inspect then
        local fingerprint = short(context.inspectFingerprint)
        local inspectId = "inspect:" .. tostring(inspect.id)
        if inspect.sourceId and inspect.sourceId ~= "" and fingerprint and fingerprint ~= "" then
            inspectId = "inspect:" .. #inspect.sourceId .. ":" .. inspect.sourceId .. ":" .. fingerprint
        end
        add({ id = inspectId, kind = "inspect", place = inspect,
            fingerprint = fingerprint,
            sourceX = context.inspectX, sourceY = context.inspectY, sourceZ = context.inspectZ,
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
        groupValues = { status = #social.requests + #social.responsibilities > 0 and "person-private" or "unknown",
            requests = social.requests, responsibilities = social.responsibilities,
            gap = "acquired requests do not establish stock, helper assent or completed delivery" },
        lowPressureWish = { status = "open", activity = short(context.lowPressureActivity),
            gap = "low pressure leaves personal activity selection with its existing owners" },
        slack = { status = "unknown", personallyAvailable = capacity.available,
            gap = "own carried stock and contacts do not establish settlement surplus" },
    }
    return out
end

return Labor
