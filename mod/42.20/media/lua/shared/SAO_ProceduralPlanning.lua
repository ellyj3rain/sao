-- SAO_ProceduralPlanning.lua - person-private purposes, spatial knowledge,
-- and bounded plans whose claims are tested only by native result receipts.
--
-- The planner does not execute work and it does not grant competence. It
-- preserves why a person is acting, what they believe is required, where
-- their knowledge came from, what interrupted them, and which exact result
-- would let them advance. Native owners remain the authority for every verb.

SAO = SAO or {}
SAO.ProceduralPlanning = SAO.ProceduralPlanning or {}
local P = SAO.ProceduralPlanning

local MAX_PURPOSES, MAX_FACTS, MAX_EVENTS = 12, 64, 32
local MIN_TACTICAL_ROUTE_TILES, MAX_TACTICAL_ROUTE_TILES = 2, 40
local SKILLS = { "Cooking", "Fitness", "Strength", "Lightfooted", "Nimble",
    "Sprinting", "Sneak", "Woodwork", "Aiming", "Reloading", "Farming",
    "Fishing", "Trapping", "PlantScavenging", "Doctor", "Electricity",
    "Blacksmith", "MetalWelding", "Mechanics", "Spear", "Maintenance",
    "Tracking", "Husbandry", "FlintKnapping", "Masonry", "Pottery",
    "Carving", "Butchering", "Glassmaking" }

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function clamp(n, low, high)
    return math.max(low, math.min(high, n))
end
local function nowHours()
    local ok, value = pcall(function() return SAO.History.countyHours() end)
    return ok and finite(value) and value or 0
end
local function record(id)
    return type(id) == "string" and SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
end
local function state(id, create)
    local rec = record(id)
    if not rec then return nil end
    if create and type(rec.proceduralPlanning) ~= "table" then
        rec.proceduralPlanning = { schema = 1, nextPurpose = 0,
            purposes = {}, order = {}, spatial = {}, spatialOrder = {},
            practice = {} }
    end
    local value = rec.proceduralPlanning
    if type(value) ~= "table" or value.schema ~= 1
        or type(value.purposes) ~= "table" or type(value.order) ~= "table"
        or type(value.spatial) ~= "table"
        or type(value.spatialOrder) ~= "table"
        or type(value.practice) ~= "table" then return nil end
    return value
end
local function addEvent(purpose, kind, detail, at)
    purpose.events = purpose.events or {}
    purpose.events[#purpose.events + 1] = { at = at, kind = kind,
        detail = tostring(detail or "") }
    if #purpose.events > MAX_EVENTS then table.remove(purpose.events, 1) end
end
local function purposeByKey(s, key)
    for _, id in ipairs(s.order) do
        local purpose = s.purposes[id]
        if purpose and purpose.key == key and purpose.status ~= "completed"
            and purpose.status ~= "abandoned" then return purpose end
    end
end
local function copyList(source, maximum)
    local out = {}
    for i, value in ipairs(source or {}) do
        if i > (maximum or 32) then break end
        out[#out + 1] = value
    end
    return out
end

function P.maintain(id, spec)
    local s = state(id, true)
    if not s or type(spec) ~= "table" or type(spec.key) ~= "string"
        or spec.key == "" or type(spec.objective) ~= "string" then return nil end
    local purpose = purposeByKey(s, spec.key)
    local at = finite(spec.atHours) and spec.atHours or nowHours()
    if not purpose then
        s.nextPurpose = s.nextPurpose + 1
        purpose = { id = "purpose/" .. tostring(s.nextPurpose), key = spec.key,
            objective = spec.objective, domain = tostring(spec.domain or "general"),
            origin = tostring(spec.origin or "self"), authority = spec.authority,
            createdAt = at, updatedAt = at, status = "maintained", revision = 1,
            blockers = {}, steps = {}, cursor = 1, events = {} }
        s.purposes[purpose.id] = purpose
        s.order[#s.order + 1] = purpose.id
        if #s.order > MAX_PURPOSES then
            local removed = table.remove(s.order, 1)
            s.purposes[removed] = nil
        end
        addEvent(purpose, "formed", purpose.objective, at)
    elseif purpose.objective ~= spec.objective then
        purpose.objective, purpose.revision = spec.objective, purpose.revision + 1
        addEvent(purpose, "revised", purpose.objective, at)
    end
    purpose.updatedAt = at
    return purpose
end

function P.interrupt(id, purposeId, reason, at)
    local s, when = state(id), finite(at) and at or nowHours()
    local purpose = s and s.purposes[tostring(purposeId or "")]
    if not purpose or purpose.status == "completed" then return false end
    purpose.status, purpose.interruptedAt = "interrupted", when
    purpose.blockers = { tostring(reason or "interrupted") }
    addEvent(purpose, "interrupted", reason, when)
    return true
end

function P.rememberSpatial(id, fact)
    local s = state(id, true)
    if not s or type(fact) ~= "table" or type(fact.key) ~= "string"
        or fact.key == "" or type(fact.kind) ~= "string"
        or not finite(fact.x) or not finite(fact.y) then return false end
    local at = finite(fact.observedAtHours) and fact.observedAtHours or nowHours()
    local existing = s.spatial[fact.key]
    if not existing then
        if #s.spatialOrder >= MAX_FACTS then
            local removed = table.remove(s.spatialOrder, 1)
            s.spatial[removed] = nil
        end
        s.spatialOrder[#s.spatialOrder + 1] = fact.key
        existing = {}; s.spatial[fact.key] = existing
    end
    existing.key, existing.kind = fact.key, fact.kind
    existing.x, existing.y, existing.z = fact.x, fact.y, tonumber(fact.z) or 0
    existing.source = tostring(fact.source or "observed")
    existing.observedAtHours = at
    existing.confidence = clamp(tonumber(fact.confidence) or 1, 0, 1)
    existing.familiarity = clamp(tonumber(fact.familiarity) or 0, 0, 1)
    existing.cover = clamp(tonumber(fact.cover) or 0, 0, 1)
    existing.routeKnown = fact.routeKnown == true
    existing.blocksThreatLOS = fact.blocksThreatLOS == true
    existing.owned = fact.owned == true
    existing.usable = fact.usable ~= false
    existing.tags = copyList(fact.tags, 12)
    return true
end

local function rememberedConfidence(fact, at)
    local age = math.max(0, at - (tonumber(fact.observedAtHours) or at))
    local halfLife = 24 + 696 * (tonumber(fact.familiarity) or 0)
    return clamp((tonumber(fact.confidence) or 0) * (0.5 ^ (age / halfLife)), 0, 1)
end

function P.spatialKnowledge(id, at)
    local s, out = state(id), {}
    if not s then return out end
    at = finite(at) and at or nowHours()
    for _, key in ipairs(s.spatialOrder) do
        local fact = s.spatial[key]
        if fact then
            out[#out + 1] = { key = key, kind = fact.kind, x = fact.x,
                y = fact.y, z = fact.z, source = fact.source,
                confidence = rememberedConfidence(fact, at),
                familiarity = fact.familiarity, cover = fact.cover,
                routeKnown = fact.routeKnown, blocksThreatLOS = fact.blocksThreatLOS,
                owned = fact.owned, usable = fact.usable, tags = copyList(fact.tags, 12) }
        end
    end
    return out
end

function P.readingSessions(id, bookSkill)
    local s = state(id)
    local evidence = s and s.practice[bookSkill]
    return tonumber(evidence and evidence.readingSessions) or 0
end

function P.techniqueProfile(id)
    local out = { skills = {}, known = 0, practice = {} }
    local s = state(id, true)
    for _, name in ipairs(SKILLS) do
        local level = -1
        if SAO.Census and SAO.Census.skillOf then
            local ok, value = pcall(SAO.Census.skillOf, id, name)
            if ok and finite(value) then level = value end
        end
        out.skills[name] = level
        if level >= 0 then out.known = out.known + 1 end
    end
    for key, value in pairs(s and s.practice or {}) do
        out.practice[key] = { completed = tonumber(value.completed) or 0,
            failed = tonumber(value.failed) or 0,
            readingSessions = tonumber(value.readingSessions) or 0,
            lastAt = value.lastAt }
    end
    local rec = record(id)
    out.priorLife = rec and rec.occupation or nil
    out.designation = rec and rec.designation or nil
    out.literacy = SAO.History and SAO.History.literacyOf
        and SAO.History.literacyOf(id) or "unknown"
    return out
end

local function setPlan(purpose, steps, blockers, interpretations, at)
    local prior = {}
    for _, step in ipairs(purpose.steps or {}) do prior[step.id] = step end
    for _, step in ipairs(steps) do
        local old = prior[step.id]
        if old and old.status == "completed" then
            step.status, step.completedAt = old.status, old.completedAt
        end
    end
    local changed = #purpose.steps ~= #steps
    if not changed then
        for i, step in ipairs(steps) do
            if not purpose.steps[i] or purpose.steps[i].id ~= step.id
                or purpose.steps[i].status ~= step.status then changed = true; break end
        end
    end
    purpose.steps, purpose.blockers = steps, blockers or {}
    purpose.interpretations = interpretations
    purpose.updatedAt = at
    purpose.status = #purpose.blockers > 0 and "blocked" or "maintained"
    purpose.cursor = 1
    for i, step in ipairs(steps) do
        if step.status ~= "completed" then purpose.cursor = i; break end
        purpose.cursor = i + 1
    end
    if changed then purpose.revision = purpose.revision + 1 end
    return purpose
end

local function interpretations(id, candidates, context)
    if SAO.Cognition and SAO.Cognition.interpretPlans then
        local ok, value = pcall(SAO.Cognition.interpretPlans, id, candidates, context)
        if ok then return value end
    end
    return nil
end

function P.planStudy(id, designation, context)
    context = type(context) == "table" and context or {}
    local perk = context.perk or (SAO.Census and SAO.Census.JOB_PERK
        and SAO.Census.JOB_PERK[designation])
    if not perk then return nil, "no-study-domain" end
    local bookSkill = context.bookSkill or SAO.Census.bookSkillFor(perk)
    local s = state(id)
    local purpose = context.purposeId and s and s.purposes[context.purposeId]
    purpose = purpose or P.maintain(id, { key = "study:" .. tostring(perk)
        .. (context.bookKey and ":" .. tostring(context.bookKey) or ""),
        objective = "improve " .. tostring(perk) .. " through reading and tested practice",
        domain = "learning", origin = "work-demand", atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    local at = finite(context.atHours) and context.atHours or nowHours()
    local literacy = context.literacy or (SAO.History and SAO.History.literacyOf
        and SAO.History.literacyOf(id)) or "unknown"
    local readingTime = tonumber(context.readingTime) or 1
    local fatigue = clamp(tonumber(context.fatigue) or 0, 0, 1)
    local steps, blockers = {}, {}
    if literacy == "none" then blockers[#blockers + 1] = "cannot-yet-read" end
    local access = context.bookOwned == true and "owned"
        or context.bookNearby == true and "nearby" or "unknown"
    if access == "unknown" then
        steps[#steps + 1] = { id = "locate-book", verb = "inspect",
            owner = "SAONeeds", status = "available", token = "reading:located",
            target = bookSkill }
    elseif access == "nearby" then
        steps[#steps + 1] = { id = "acquire-book", verb = "acquire",
            owner = "SAO.SourceUse", status = "available", token = "reading:acquired",
            target = bookSkill }
    end
    steps[#steps + 1] = { id = "read-session", verb = "read",
        owner = "SAONeeds", status = literacy == "none" and "blocked" or "available",
        token = "reading:progressed", target = bookSkill,
        effort = clamp(readingTime * (1 + fatigue), 0.25, 4),
        session = (purpose.sessions or 0) + 1 }
    steps[#steps + 1] = { id = "practice", verb = "practice",
        owner = "native-domain-action", status = "dependent",
        token = "practice:validated", target = perk }
    local candidates = {
        { id = "study", evidence = access == "owned" and 1 or 0.45,
            continuity = purpose.sessions and 1 or 0.5, novelty = 0.2,
            informationGain = 0.5, blockers = #blockers },
        { id = "practice", evidence = context.practiceAvailable and 0.8 or 0.2,
            continuity = 0.3, novelty = 0.3, informationGain = 0.8,
            blockers = context.practiceAvailable and 0 or 1 },
    }
    setPlan(purpose, steps, blockers, interpretations(id, candidates,
        { domain = "learning", pressure = tonumber(context.pressure) or 0 }), at)
    purpose.subject, purpose.bookSkill, purpose.literacy = perk, bookSkill, literacy
    purpose.access, purpose.sessionEffort = access, steps[#steps - 1].effort
    return purpose, purpose.steps[purpose.cursor]
end

function P.planFortification(id, context)
    context = type(context) == "table" and context or {}
    local purpose = P.maintain(id, { key = "fortify-home",
        objective = "reduce exposed entrances on held ground",
        domain = "construction", origin = "place-security", atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    local steps, blockers = {}, {}
    if not context.insideOwnedGround then blockers[#blockers + 1] = "not-on-owned-ground" end
    if not context.knownGround then
        steps[#steps + 1] = { id = "survey-entrances", verb = "inspect",
            owner = "SAOBuild", status = "available", token = "ground:surveyed" }
    end
    if not context.hasKit then blockers[#blockers + 1] = "missing-barricade-materials" end
    steps[#steps + 1] = { id = "board-known-entry", verb = "construct",
        owner = "SAOBuild", status = (#blockers == 0 and context.entryKey)
            and "available" or "blocked", token = "construction:boarded",
        target = context.entryKey }
    steps[#steps + 1] = { id = "inspect-result", verb = "verify",
        owner = "SAOGround", status = "dependent", token = "ground:verified" }
    setPlan(purpose, steps, blockers, interpretations(id, {
        { id = "board", evidence = context.entryKey and 0.9 or 0.2,
            continuity = 0.7, novelty = 0.1, informationGain = 0.3,
            blockers = #blockers },
        { id = "survey", evidence = context.knownGround and 0.8 or 0.4,
            continuity = 0.4, novelty = 0.2, informationGain = 0.9,
            blockers = context.insideOwnedGround and 0 or 1 },
    }, { domain = "construction", pressure = tonumber(context.pressure) or 0 }),
        finite(context.atHours) and context.atHours or nowHours())
    return purpose, purpose.steps[purpose.cursor]
end

function P.planLeisure(id, context)
    context = type(context) == "table" and context or {}
    local activity = tostring(context.activity or "recreation")
    local purpose = P.maintain(id, { key = "leisure:" .. activity,
        objective = "make time for " .. activity .. " in a usable shared place",
        domain = "leisure", origin = context.spontaneous and "impulse" or "routine",
        atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    local blockers, steps = {}, {}
    if not context.affordance then blockers[#blockers + 1] = "missing-activity-affordance" end
    if not context.locationKey then blockers[#blockers + 1] = "no-known-usable-place" end
    if context.crowding and context.crowding > 1 then
        blockers[#blockers + 1] = "place-overcrowded"
    end
    steps[#steps + 1] = { id = "reach-activity-place", verb = "move",
        owner = "Locomotion", status = context.atLocation and "completed"
            or (#blockers == 0 and "available" or "blocked"),
        token = "route:travelling", target = context.locationKey }
    steps[#steps + 1] = { id = "perform-activity", verb = "recreate",
        owner = tostring(context.owner or "native-activity"),
        status = context.atLocation and #blockers == 0 and "available" or "dependent",
        token = "leisure:performed", target = activity }
    steps[#steps + 1] = { id = "share-activity", verb = "socialize",
        owner = "native-participation", status = "dependent",
        token = "leisure:shared", target = activity, required = false }
    local planned = { id = "planned", evidence = context.affordance and 0.8 or 0.1,
        continuity = 0.8, novelty = 0.2, informationGain = 0.2,
        blockers = #blockers }
    local spontaneous = { id = "spontaneous", evidence = context.atLocation and 0.7 or 0.2,
        continuity = 0.2, novelty = 0.8, informationGain = 0.5,
        blockers = #blockers }
    setPlan(purpose, steps, blockers, interpretations(id,
        { planned, spontaneous }, { domain = "leisure",
            pressure = clamp(tonumber(context.boredom) or 0, 0, 1) }),
        finite(context.atHours) and context.atHours or nowHours())
    purpose.locationKey, purpose.affordance = context.locationKey, context.affordance
    return purpose, purpose.steps[purpose.cursor]
end

function P.planHorseTravel(id, context)
    context = type(context) == "table" and context or {}
    local animalId = tostring(context.animalId or "unknown")
    local purpose = P.maintain(id, { key = "horse-travel:" .. animalId,
        objective = "reach the destination with horse " .. animalId,
        domain = "mobility", origin = "route-demand", atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    local blockers = {}
    if context.known ~= true then blockers[#blockers + 1] = "horse-not-known" end
    if context.mountable ~= true then blockers[#blockers + 1] = "horse-not-mountable" end
    local available = #blockers == 0 and "available" or "blocked"
    local steps = {
        { id = "approach-horse", verb = "move", owner = "HorseMount",
            status = available, token = "horse:reached", target = animalId },
        { id = "mount-horse", verb = "mount", owner = "HorseMount",
            status = "dependent", token = "horse:mounted", target = animalId },
        { id = "ride-route", verb = "ride", owner = "HorseTravel",
            status = "dependent", token = "route:arrived",
            target = context.destinationKey or "destination" },
        { id = "dismount-horse", verb = "dismount", owner = "HorseMount",
            status = "dependent", token = "horse:dismounted", target = animalId },
    }
    local direct = { id = "ride-known-horse", evidence = context.known and 0.9 or 0.1,
        continuity = 0.9, novelty = 0.2, informationGain = 0.2,
        blockers = #blockers }
    local investigate = { id = "inspect-horse", evidence = context.known and 0.2 or 0.7,
        continuity = 0.3, novelty = 0.8, informationGain = 0.9,
        blockers = context.mountable and 0 or 1 }
    setPlan(purpose, steps, blockers, interpretations(id, { direct, investigate },
        { domain = "mobility", pressure = tonumber(context.pressure) or 0.4 }),
        finite(context.atHours) and context.atHours or nowHours())
    purpose.animalId, purpose.destinationKey = animalId, context.destinationKey
    return purpose, purpose.steps[purpose.cursor]
end

function P.planMobileHousehold(id, context)
    context = type(context) == "table" and context or {}
    local vehicleId = tostring(context.vehicleId or "unknown")
    local purpose = P.maintain(id, { key = "mobile-household:" .. vehicleId,
        objective = tostring(context.objective or
            "use a known moving place without losing people or supplies"),
        domain = "mobile-household", origin = tostring(context.origin
            or "shelter-and-mobility"), atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    local blockers = {}
    if context.known ~= true then blockers[#blockers + 1] = "vehicle-not-known" end
    if context.loaded ~= true then blockers[#blockers + 1] = "vehicle-not-loaded" end
    if context.accessible ~= true then blockers[#blockers + 1] = "entry-not-accessible" end
    if context.separated == true then blockers[#blockers + 1] = "party-separated" end
    local available = #blockers == 0 and "available" or "blocked"
    local steps = {}
    if context.occupied ~= true then
        steps[#steps + 1] = { id = "inspect-mobile-place", verb = "inspect",
            owner = "MobileHousehold", status = available,
            token = "mobile:identified", target = vehicleId }
        steps[#steps + 1] = { id = "approach-entry", verb = "move",
            owner = "Locomotion", status = "dependent",
            token = "route:arrived", target = vehicleId }
        steps[#steps + 1] = { id = "enter-mobile-place", verb = "enter",
            owner = "MobileHousehold", status = "dependent",
            token = "mobile:entered", target = vehicleId }
    end
    steps[#steps + 1] = { id = "reconcile-occupants-and-stores", verb = "reconcile",
        owner = "MobileHousehold", status = available,
        token = "mobile:reconciled", target = vehicleId }
    steps[#steps + 1] = { id = "depart-or-remain", verb = "decide",
        owner = "Controller", status = "dependent",
        token = "mobile:continuity-decided",
        target = context.destinationKey or vehicleId }
    local stay = { id = "use-moving-place",
        evidence = context.known and context.accessible and 0.9 or 0.2,
        continuity = context.occupied and 1 or 0.6, novelty = 0.2,
        informationGain = context.materialKnown and 0.2 or 0.7,
        blockers = #blockers }
    local inspect = { id = "inspect-before-entry", evidence = context.loaded and 0.7 or 0.1,
        continuity = 0.3, novelty = 0.8, informationGain = 0.9,
        blockers = context.loaded and 0 or 1 }
    setPlan(purpose, steps, blockers, interpretations(id, { stay, inspect },
        { domain = "mobile-household",
            pressure = clamp(tonumber(context.pressure) or 0, 0, 1) }),
        finite(context.atHours) and context.atHours or nowHours())
    purpose.vehicleId, purpose.vehicleKind = vehicleId, context.vehicleKind
    purpose.destinationKey = context.destinationKey
    purpose.materialRevision = context.materialRevision
    purpose.occupantCount = tonumber(context.occupantCount) or 0
    return purpose, purpose.steps[purpose.cursor]
end

function P.chooseFallback(id, situation)
    if type(situation) ~= "table" or type(situation.position) ~= "table"
        or type(situation.threat) ~= "table" then return nil end
    local px, py = tonumber(situation.position.x), tonumber(situation.position.y)
    local tx, ty = tonumber(situation.threat.x), tonumber(situation.threat.y)
    if not (px and py and tx and ty) then return nil end
    local candidates = {}
    for _, fact in ipairs(P.spatialKnowledge(id, situation.atHours)) do
        if fact.usable and fact.confidence >= 0.15 then
            local awayX, awayY = px - tx, py - ty
            local moveX, moveY = fact.x - px, fact.y - py
            local away = awayX * moveX + awayY * moveY
            local distance = math.sqrt(moveX * moveX + moveY * moveY)
            if away > 0 and distance >= MIN_TACTICAL_ROUTE_TILES
                and distance <= MAX_TACTICAL_ROUTE_TILES then
                local score = fact.confidence * 0.25 + fact.cover * 0.35
                    + (fact.blocksThreatLOS and 0.25 or 0)
                    + (fact.routeKnown and 0.15 or 0) - distance * 0.004
                candidates[#candidates + 1] = { id = fact.key, fact = fact,
                    score = score, evidence = fact.confidence,
                    continuity = fact.routeKnown and 1 or 0.2,
                    novelty = 1 - fact.familiarity,
                    informationGain = fact.blocksThreatLOS and 0.2 or 0.6,
                    blockers = 0 }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.score == b.score then return a.id < b.id end
        return a.score > b.score
    end)
    if #candidates == 0 then return nil end
    local purpose = P.maintain(id, { key = "withdraw:" .. tostring(situation.threat.key or "contact"),
        objective = "break contact through known defensible ground",
        domain = "tactical", origin = "perceived-threat", atHours = situation.atHours })
    local views = interpretations(id, candidates,
        { domain = "tactical", pressure = 1 })
    if purpose then
        setPlan(purpose, { { id = "watch-threat", verb = "watch",
            owner = "Posture", status = "available", token = "posture:maintained" },
            { id = "move-fallback", verb = "move", owner = "Locomotion",
                status = "dependent", token = "route:travelling",
                target = candidates[1].id },
            { id = "cover-movement", verb = "cover", owner = "Posture",
                status = "dependent", token = "posture:maintained" } }, {}, views,
            finite(situation.atHours) and situation.atHours or nowHours())
        purpose.selectedSpatialFact = candidates[1].id
    end
    return candidates[1].fact, purpose
end

-- Runtime owners use the existing purpose, rather than making another plan
-- after every inspection, queue admission or interruption.
function P.pending(id, verb, target)
    local s = state(id)
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        local step = purpose and purpose.steps[purpose.cursor]
        if purpose and purpose.status ~= "completed" and purpose.status ~= "abandoned"
            and step and (not verb or step.verb == verb)
            and (not target or step.target == target) then return purpose, step end
    end
end

function P.studyDemand(id)
    local s = state(id)
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        local step = purpose and purpose.steps[purpose.cursor]
        if purpose and purpose.domain == "learning" and purpose.literacy ~= "none"
            and purpose.status ~= "completed" and purpose.status ~= "abandoned"
            and step and (step.verb == "inspect" or step.verb == "acquire" or step.verb == "read") then
            return purpose, step
        end
    end
end

function P.studyPurpose(id, subject)
    local s = state(id)
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        local step = purpose and purpose.steps[purpose.cursor]
        if purpose and purpose.domain == "learning" and purpose.subject == subject
            and purpose.status ~= "completed" and purpose.status ~= "abandoned"
            and step and step.verb ~= "practice" then return purpose end
    end
end

function P.noteAdmission(id, purposeId, owner, correlationId, stepId)
    local s = state(id)
    local purpose = s and s.purposes[tostring(purposeId or "")]
    if not purpose or type(owner) ~= "string" or type(correlationId) ~= "string" then return false end
    local step = purpose.steps[purpose.cursor]
    if stepId and (not step or step.id ~= stepId or step.owner ~= owner) then return false end
    purpose.admission = { owner = owner, correlationId = correlationId,
        stepId = step and step.id, target = step and step.target, token = step and step.token,
        at = nowHours() }
    addEvent(purpose, "admitted", owner .. ":" .. correlationId, purpose.admission.at)
    return true
end

function P.recordResult(id, purposeId, result)
    local s = state(id)
    local purpose = s and s.purposes[tostring(purposeId or "")]
    if not purpose or type(result) ~= "table" or type(result.owner) ~= "string"
        or type(result.token) ~= "string"
        or (result.status ~= "completed" and result.status ~= "failed"
            and result.status ~= "interrupted") then return false end
    local receiptKey = result.correlationId and (result.owner .. ":" .. result.correlationId)
    for _, key in ipairs(purpose.resultReceipts or {}) do
        if key == receiptKey then return true end
    end
    local step = purpose.steps[purpose.cursor]
    if not step or step.owner ~= result.owner or step.token ~= result.token then return false end
    if result.correlationId and (not purpose.admission
        or purpose.admission.owner ~= result.owner
        or purpose.admission.correlationId ~= result.correlationId
        or purpose.admission.stepId ~= step.id
        or purpose.admission.target ~= step.target) then return false end
    local at = finite(result.atHours) and result.atHours or nowHours()
    if result.status == "completed" then
        step.status, step.completedAt = "completed", at
        purpose.cursor = purpose.cursor + 1
        purpose.blockers = {}
        purpose.status = purpose.cursor > #purpose.steps and "completed" or "maintained"
        if step.verb == "read" then
            purpose.sessions = (purpose.sessions or 0) + 1
            local key = tostring(step.target or purpose.domain)
            local practice = s.practice[key] or { completed = 0, failed = 0 }
            practice.readingSessions = (practice.readingSessions or 0) + 1
            practice.lastReadAt = at
            s.practice[key] = practice
        end
        if step.verb == "practice" or step.verb == "produce"
            or step.verb == "construct" or step.verb == "recreate"
            or step.verb == "socialize" then
            local key = tostring(step.target or purpose.domain)
            local practice = s.practice[key] or { completed = 0, failed = 0 }
            practice.completed, practice.lastAt = practice.completed + 1, at
            s.practice[key] = practice
        end
    else
        step.status = result.status
        purpose.status = result.status == "interrupted" and "interrupted" or "blocked"
        purpose.blockers = { tostring(result.reason or result.status) }
        local key = tostring(step.target or purpose.domain)
        local practice = s.practice[key] or { completed = 0, failed = 0 }
        practice.failed, practice.lastAt = practice.failed + 1, at
        s.practice[key] = practice
    end
    purpose.updatedAt = at
    if receiptKey then
        purpose.resultReceipts = purpose.resultReceipts or {}
        purpose.resultReceipts[#purpose.resultReceipts + 1] = receiptKey
        if #purpose.resultReceipts > MAX_EVENTS then table.remove(purpose.resultReceipts, 1) end
    end
    addEvent(purpose, "result", result.status .. ":" .. result.token, at)
    return true
end

function P.consumeSourceResult(receipt)
    if type(receipt) ~= "table" or not receipt.purposeId then return false end
    local authoritative = SAO.WorldSources.actionOutcome(receipt.reservationId, receipt.actorId)
    if not authoritative or authoritative.status == "pending"
        or authoritative.purposeId ~= receipt.purposeId
        or authoritative.purposeStepId ~= receipt.purposeStepId then return false end
    local s = state(receipt.actorId)
    if not s then return false, "planning-unavailable" end
    local purpose = s.purposes[receipt.purposeId]
    if not purpose or purpose.status == "abandoned" then return true, "purpose-retired" end
    if authoritative.operation ~= "acquire" then return false end
    local step = purpose.steps[purpose.cursor]
    local admission = purpose.admission
    if not step or not admission or step.id ~= authoritative.purposeStepId
        or admission.correlationId ~= authoritative.reservationId
        or admission.stepId ~= step.id or admission.target ~= step.target then
        -- A retained receipt still belongs to its old exact attempt after a
        -- goal revision. It cannot advance a replacement step or pin the
        -- sole result stream forever. Retain one private retirement event.
        local key = "SAO.SourceUse:" .. authoritative.reservationId
        for _, seen in ipairs(purpose.resultReceipts or {}) do
            if seen == key then return true end
        end
        purpose.resultReceipts = purpose.resultReceipts or {}
        purpose.resultReceipts[#purpose.resultReceipts + 1] = key
        if #purpose.resultReceipts > MAX_EVENTS then table.remove(purpose.resultReceipts, 1) end
        addEvent(purpose, "result-retired", authoritative.detail or authoritative.status, authoritative.at)
        return true, "purpose-attempt-superseded"
    end
    local completed = authoritative.status == "completed"
    if completed and (authoritative.measurement ~= "native-item-transfer"
        or (tonumber(authoritative.observedQuantity) or 0) <= 0) then return false end
    return P.recordResult(receipt.actorId, purpose.id, {
        owner = "SAO.SourceUse", token = admission.token,
        status = completed and "completed" or "interrupted",
        reason = authoritative.detail, correlationId = authoritative.reservationId,
        atHours = authoritative.at,
    })
end

function P.admitCooking(id, work)
    local purpose, step = P.pending(id, "practice", "Cooking")
    if not purpose then
        purpose = P.maintain(id, { key = "prepare-food", domain = "provisioning",
            objective = "prepare known raw food safely for eating", origin = "food-preparation" })
        if not purpose then return false end
        setPlan(purpose, { { id = "prepare", verb = "produce", owner = "Cooking",
            token = "cooking:prepared", target = "Cooking", status = "available" } }, {},
            interpretations(id, { { id = "prepare", evidence = 1, continuity = 1,
                novelty = 0.1, informationGain = 0.5, blockers = 0 } }, { domain = "provisioning" }), nowHours())
        step = purpose.steps[purpose.cursor]
    end
    if not P.noteAdmission(id, purpose.id, step.owner, work.id, step.id) then return false end
    work.purposeId, work.purposeStepId = purpose.id, step.id
    return true
end

function P.consumeCookingResult(id, receipt)
    if not receipt or not receipt.purposeId then return true end
    local rec = record(id)
    local canonical
    for _, outcome in ipairs(rec and rec.cookingOutcomes or {}) do
        if outcome.id == receipt.id then canonical = outcome; break end
    end
    if not canonical or canonical.actorId ~= id or canonical.purposeId ~= receipt.purposeId then return false end
    local s = state(id)
    if not s then return false end
    local purpose = s.purposes[canonical.purposeId]
    if not purpose or purpose.status == "abandoned" then return true end
    local step, admission = purpose.steps[purpose.cursor], purpose.admission
    if not step or not admission or admission.correlationId ~= canonical.id
        or canonical.purposeStepId ~= step.id or admission.target ~= step.target then
        return true, "purpose-attempt-superseded"
    end
    local completed = canonical.status == "completed"
    if completed and (canonical.nativeCredit ~= canonical.id or not canonical.retrieved
        or not canonical.heatObserved or (canonical.shutdown ~= "off"
            and canonical.shutdown ~= "shared-use"
            and canonical.shutdown ~= "prior-state-preserved")) then return false end
    return P.recordResult(id, purpose.id, {
        owner = admission.owner, token = admission.token,
        status = completed and "completed" or canonical.status == "interrupted"
            and "interrupted" or "failed",
        correlationId = canonical.id, reason = canonical.detail,
        atHours = canonical.atHours,
    })
end

function P.reconcileCooking(id)
    local rec = record(id)
    for _, receipt in ipairs(rec and rec.cookingOutcomes or {}) do
        if receipt.purposeId and not receipt.purposeDelivered
            and P.consumeCookingResult(id, receipt) then receipt.purposeDelivered = true end
    end
end

function P.snapshot(id)
    local s = state(id)
    if not s then return nil end
    local out = { purposes = {}, spatialFacts = #s.spatialOrder,
        study = SAO.Study and SAO.Study.snapshot and SAO.Study.snapshot(id) or nil,
        practiceDomains = 0 }
    for _, practice in pairs(s.practice) do
        if (tonumber(practice.completed) or 0) > 0 then
            out.practiceDomains = out.practiceDomains + 1
        end
    end
    for i = math.max(1, #s.order - 5), #s.order do
        local purpose = s.purposes[s.order[i]]
        if purpose then
            local nextStep = purpose.steps[purpose.cursor]
            out.purposes[#out.purposes + 1] = { id = purpose.id,
                objective = purpose.objective, domain = purpose.domain,
                status = purpose.status, revision = purpose.revision,
                nextStep = nextStep and nextStep.verb or nil,
                nextOwner = nextStep and nextStep.owner or nil,
                blockers = copyList(purpose.blockers, 6),
                selectedSpatialFact = purpose.selectedSpatialFact,
                interpretations = purpose.interpretations }
        end
    end
    return out
end

return P
