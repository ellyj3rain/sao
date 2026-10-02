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
local RESOURCE_RESULT = {}
local WINDOW_REPAIR_RESULT = {}

local MAX_PURPOSES, MAX_FACTS, MAX_EVENTS = 12, 64, 32
local MAX_RESIDENCE_ATTEMPTS = 16
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
local function dataCopy(value, depth)
    depth = depth or 0
    if depth > 6 then return nil end
    if type(value) == "string" then return string.sub(value, 1, 512) end
    if type(value) == "number" then return finite(value) and value or nil end
    if type(value) == "boolean" then return value end
    if type(value) ~= "table" then return nil end
    local out, count = {}, 0
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            count = count + 1
            if count > 32 then break end
            out[key] = dataCopy(item, depth + 1)
        end
    end
    return out
end

local function retirePurpose(s, index)
    local removed = table.remove(s.order, index)
    local old = s.purposes[removed]
    local goal = old and old.resourceOutcome
    local request = goal and s.resourceOutcomeRequests and s.resourceOutcomeRequests[goal.id]
    if request and request.purposeId == removed then
        request.retired = { purposeId = removed, status = old.status,
            resolution = old.resolution, resolvedAt = old.resolvedAt,
            outcomeProgress = dataCopy(old.outcomeProgress) }
    end
    s.purposes[removed] = nil
end

function P.maintain(id, spec)
    local s = state(id, true)
    if not s or type(spec) ~= "table" or type(spec.key) ~= "string"
        or spec.key == "" or type(spec.objective) ~= "string" then return nil end
    local purpose = purposeByKey(s, spec.key)
    local at = finite(spec.atHours) and spec.atHours or nowHours()
    if not purpose then
        if #s.order >= MAX_PURPOSES then
            local removable
            for i, purposeId in ipairs(s.order) do
                local prior = s.purposes[purposeId]
                if not prior or not prior.admission and (not prior.residence
                    or prior.status == "completed" or prior.status == "abandoned") and (not prior.resourceOutcome
                    or prior.status == "completed" or prior.status == "abandoned") then removable = i; break end
            end
            if not removable then return nil end
            retirePurpose(s, removable)
        end
        s.nextPurpose = s.nextPurpose + 1
        purpose = { id = "purpose/" .. tostring(s.nextPurpose), key = spec.key,
            objective = spec.objective, domain = tostring(spec.domain or "general"),
            origin = tostring(spec.origin or "self"), authority = spec.authority,
            createdAt = at, updatedAt = at, status = "maintained", revision = 1,
            blockers = {}, steps = {}, cursor = 1, events = {} }
        s.purposes[purpose.id] = purpose
        s.order[#s.order + 1] = purpose.id
        addEvent(purpose, "formed", purpose.objective, at)
    elseif purpose.objective ~= spec.objective then
        purpose.objective, purpose.revision = spec.objective, purpose.revision + 1
        addEvent(purpose, "revised", purpose.objective, at)
    end
    purpose.updatedAt = at
    return purpose
end

local function outcomeRequest(spec)
    if type(spec) ~= "table" then return nil end
    local allowed = { id = true, revision = true, category = true, target = true,
        unit = true, sourceDefinition = true, issuer = true, deadlineAfterHours = true }
    for key in pairs(spec) do if not allowed[key] then return nil end end
    if type(spec.id) ~= "string" or not spec.id:match("^[a-z][a-z0-9_-]*$")
        or #spec.id > 80 or not finite(spec.revision) or spec.revision < 1
        or spec.revision > 1000000 or spec.revision ~= math.floor(spec.revision)
        or (spec.category ~= "food" and spec.category ~= "water")
        or not finite(spec.target) or spec.target <= 0 or spec.target > 128
        or (spec.category == "food" and (spec.unit ~= "usable-food-item"
            or spec.target ~= math.floor(spec.target)))
        or (spec.category == "water" and spec.unit ~= "native-clean-fluid-amount")
        or type(spec.sourceDefinition) ~= "string" or #spec.sourceDefinition ~= 64
        or not spec.sourceDefinition:match("^[0-9a-f]+$")
        or type(spec.issuer) ~= "string" or spec.issuer == "" or #spec.issuer > 160
        or (spec.deadlineAfterHours ~= nil and (not finite(spec.deadlineAfterHours)
            or spec.deadlineAfterHours <= 0 or spec.deadlineAfterHours > 87600)) then return nil end
    return { id = spec.id, revision = spec.revision, category = spec.category,
        target = spec.target, unit = spec.unit, sourceDefinition = spec.sourceDefinition,
        issuer = spec.issuer, deadlineAfterHours = spec.deadlineAfterHours,
        scope = "actor-owned-carried", authority = "OperatorDirect",
        treatment = "assigned-outcome-discovery" }
end

local function sameOutcome(a, b)
    for _, key in ipairs({ "id", "revision", "category", "target", "unit",
        "sourceDefinition", "issuer", "deadlineAfterHours" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

-- An experimental operator supplies the desired stock only. The actual
-- actor still discovers and executes means through the ordinary private
-- resource planner. This admission carries no conversation or helper assent.
function P.admitResourceOutcome(id, spec)
    local rec, request = record(id), outcomeRequest(spec)
    if not rec or rec.dead then return nil, "person-unavailable" end
    if not request then return nil, "invalid-resource-outcome" end
    local s = state(id, true)
    if not s then return nil, "planning-unavailable" end
    s.resourceOutcomeRequests = s.resourceOutcomeRequests or {}
    s.resourceOutcomeOrder = s.resourceOutcomeOrder or {}
    local prior = s.resourceOutcomeRequests[request.id]
    local oldPurpose = prior and s.purposes[prior.purposeId]
    if prior then
        if prior.request.sourceDefinition ~= request.sourceDefinition then
            return nil, "outcome-source-conflict"
        end
        if request.revision <= prior.request.revision then
            if sameOutcome(prior.request, request) then
                if not oldPurpose then return nil, "outcome-purpose-retired" end
                return oldPurpose, "already-admitted"
            end
            return nil, "outcome-revision-conflict"
        end
        if oldPurpose and oldPurpose.admission then return nil, "native-attempt-active" end
    elseif #s.resourceOutcomeOrder >= MAX_PURPOSES then
        return nil, "outcome-request-capacity"
    end
    -- The bounded purpose ledger must not erase a live requested outcome.
    if #s.order >= MAX_PURPOSES then
        local removable
        for i, purposeId in ipairs(s.order) do
            local p = s.purposes[purposeId]
            if not p or not p.admission and (not p.residence
                or p.status == "completed" or p.status == "abandoned") and (not p.resourceOutcome
                or p.status == "completed" or p.status == "abandoned"
                or p == oldPurpose) then removable = i; break end
        end
        if not removable then return nil, "purpose-capacity" end
        retirePurpose(s, removable)
    end
    local at = nowHours()
    local purpose = P.maintain(id, { key = "operator-outcome:" .. request.id .. ":" .. request.revision,
        objective = "Secure " .. tostring(request.target) .. (request.category == "food"
            and " usable food items" or " water units"),
        domain = "provisioning", origin = "OperatorDirect", authority = request.issuer, atHours = at })
    if not purpose then return nil, "planning-unavailable" end
    if prior then
        local old = oldPurpose
        if old and old.status ~= "completed" and old.status ~= "abandoned" then
            old.status, old.resolution, old.resolvedAt = "abandoned", "superseded", at
            old.supersededBy = purpose.id
            addEvent(old, "outcome-superseded", purpose.id, at)
        end
    else
        s.resourceOutcomeOrder[#s.resourceOutcomeOrder + 1] = request.id
    end
    purpose.resourceCategory, purpose.resourceOutcome = request.category, request
    request.actorId, request.admittedAt = id, at
    if request.deadlineAfterHours then request.deadlineAt = at + request.deadlineAfterHours end
    local history = prior and copyList(prior.history, 6) or {}
    if prior then
        history[#history + 1] = { request = dataCopy(prior.request), purposeId = prior.purposeId,
            status = oldPurpose and oldPurpose.status or prior.retired and prior.retired.status or "unknown",
            resolution = oldPurpose and oldPurpose.resolution or prior.retired and prior.retired.resolution,
            supersededBy = purpose.id }
        if #history > 6 then table.remove(history, 1) end
    end
    s.resourceOutcomeRequests[request.id] = { request = dataCopy(request), purposeId = purpose.id, history = history }
    addEvent(purpose, "outcome-assigned", "desired stock; means and knowledge unchanged", at)
    return purpose, "admitted"
end

function P.resourceOutcomeDemand(id)
    local s, rec, at = state(id), record(id), nowHours()
    local chosen
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        local goal = purpose and purpose.resourceOutcome
        if goal and purpose.status ~= "completed" and purpose.status ~= "abandoned" then
            local reason = rec and rec.dead and "actor-dead"
                or not purpose.admission and goal.deadlineAt and at >= goal.deadlineAt and "deadline-expired"
            if reason then
                purpose.status, purpose.resolution, purpose.resolvedAt = "abandoned", reason, at
                addEvent(purpose, "outcome-retired", reason, at)
            elseif not chosen then chosen = purpose end
        end
    end
    return chosen
end

local function outcomeStock(purpose, context, at)
    local goal = purpose.resourceOutcome
    if not goal then return nil end
    local rows = goal.category == "food" and context.carriedReadyItems or context.carriedWaterItems
    local stock, seen = 0, {}
    for i, item in ipairs(type(rows) == "table" and rows or {}) do
        if i > 128 then break end
        if finite(item.itemId) and type(item.itemType) == "string" and item.itemType ~= ""
            and not seen[item.itemId] then
            seen[item.itemId] = true
            if goal.category == "food" then stock = stock + 1
            elseif finite(item.amount) and item.amount > 0 then stock = stock + item.amount end
        end
    end
    purpose.outcomeProgress = { held = stock, target = goal.target, unit = goal.unit,
        observedAtHours = at, basis = "native-private-carried-usable-stock",
        coverage = context.stockCoverage or "caller-provided-native-rows",
        completeWorkIsSeparate = true }
    return stock >= goal.target
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
    if purpose.resourceCategory then
        local kept = {}
        for _, step in ipairs(steps) do kept[step.id] = true end
        for _, old in ipairs(purpose.steps or {}) do
            if old.status == "completed" and not kept[old.id] then
                purpose.completedSteps = purpose.completedSteps or {}
                purpose.completedSteps[#purpose.completedSteps + 1] = dataCopy(old)
                if #purpose.completedSteps > 16 then table.remove(purpose.completedSteps, 1) end
            end
        end
    end
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

function P.resourceDemand(id, category, ordinaryOnly)
    local s = state(id)
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        if purpose and purpose.resourceCategory and (not category or purpose.resourceCategory == category)
            and (not ordinaryOnly or not purpose.resourceOutcome)
            and purpose.status ~= "completed" and purpose.status ~= "abandoned" then
            return purpose, purpose.steps[purpose.cursor]
        end
    end
end

function P.residencePurpose(id)
    local s = state(id)
    local purpose = s and purposeByKey(s, "residence") or nil
    return purpose and purpose.status ~= "completed" and purpose.status ~= "abandoned" and purpose or nil
end

function P.detachResidence(id, reason)
    local purpose = P.residencePurpose(id)
    if not purpose then return false end
    purpose.admission = nil
    local death = reason == "death"
    purpose.status = death and "abandoned" or "maintained"
    purpose.nextAppraisalAt = nowHours()
    addEvent(purpose, death and "residence-ended" or "residence-owner-detached", reason, nowHours())
    return true
end

-- Thinking keeps its own cadence and can run while a native owner is busy.
-- It does not replace that owner's route or imply knowledge of any stock.
function P.planResidence(id, context)
    local at = finite(context and context.atHours) and context.atHours or nowHours()
    local purpose = P.residencePurpose(id)
    if purpose and finite(purpose.nextAppraisalAt) and at < purpose.nextAppraisalAt
        and at >= (purpose.assessedAt or 0) then return purpose end
    local appraisal = SAO.Labor and SAO.Labor.assessResidence(id, context)
    if not appraisal then return nil end
    purpose = purpose or P.maintain(id, { key = "residence", domain = "residence",
        objective = "maintain a viable place to live and search from", atHours = at })
    if not purpose then return nil end
    purpose.residence = true
    purpose.appraisal, purpose.assessedAt, purpose.nextAppraisalAt = dataCopy(appraisal), at, at + 0.1
    if purpose.admission then return purpose end
    if purpose.exteriorEntryPending and at < (purpose.exteriorEntryUntil or 0)
        and purpose.status ~= "blocked" then return purpose end
    purpose.exteriorEntryPending = nil
    local hunger, thirst = tonumber(appraisal.needs.hunger) or 0, tonumber(appraisal.needs.thirst) or 0
    local urgent = math.max(hunger, thirst) >= 0.35
    local unsafeHome = appraisal.conflict > 0 or appraisal.homeDanger.count > 0
    local fatigue = tonumber(appraisal.capacity.fatigue) or 0
    local traits = SAO.Disposition and SAO.Disposition.traits and SAO.Disposition.traits(id) or {}
    local fear = 1 - (tonumber(traits.nerve) or 0.5)
    local best, bestScore
    for _, candidate in ipairs(appraisal.candidates) do
        local failure = purpose.residenceAttempts and purpose.residenceAttempts[candidate.id]
        local delayed = failure and finite(failure.retryAt) and at < failure.retryAt
        if not delayed and (candidate.distance > 3 or candidate.exterior) then
            local score = 1 - candidate.distance / 400 - candidate.danger * (0.5 + fear)
                - fatigue * candidate.distance / 250 - appraisal.responsibilities * 0.1
            if unsafeHome then score = score + 1 - math.min(0.6, appraisal.attachment * 0.15) end
            if urgent then score = score + math.max(hunger, thirst) end
            if not bestScore or score > bestScore then best, bestScore = candidate, score end
        end
    end
    local mode, reason = "stay", "the current place remains a usable reference"
    local travelAvailable = appraisal.capacity.canMove and best ~= nil and bestScore > 0
    -- These policy weights are uncalibrated choices, not learned competence.
    -- Remaining has its own value; conflict is evidence, not automatic eviction.
    local stayScore = appraisal.home and (0.5 + appraisal.attachment * 0.5
        + appraisal.responsibilities * 0.15 - appraisal.homeDanger.count * (0.5 + fear)
        - appraisal.conflict * (0.25 + (1 - fear) * 0.25)) or 0
    purpose.stayScore = stayScore
    local depart = travelAvailable and (unsafeHome or not appraisal.home) and bestScore > stayScore
    local search = travelAvailable and urgent and not appraisal.localRelief and not appraisal.currentResourceOwner
    if depart then
        mode, reason = "depart", "reconsiders residence from remembered danger, conflict or lack of shelter"
    elseif search then
        mode, reason = "search", "checks a personally known building whose supplies remain unknown"
    elseif appraisal.home and not unsafeHome and context and context.awayFromHome
        and (context.night == true or fatigue >= 0.65 or appraisal.responsibilities > 0)
        and not urgent then
        mode, reason = "return", "chooses to return to the remembered home"
    end
    -- Reaching a search lead gives its local perception and interaction owners
    -- time to inspect. Arrival itself has learned no contents.
    if purpose.mode == "search" and finite(purpose.inspectUntil) and at < purpose.inspectUntil
        and not unsafeHome then mode, reason = "search", "observes and inspects the reached place"; best = nil end
    local destination = (mode == "search" or mode == "depart") and best
        or mode == "return" and { id = "home", cx = appraisal.home.x, cy = appraisal.home.y, z = appraisal.home.z } or nil
    local priorTarget = purpose.destination and purpose.destination.id
    local newTarget = destination and destination.id
    if purpose.mode ~= mode or priorTarget ~= newTarget then
        purpose.revision = purpose.revision + 1
        addEvent(purpose, "residence-choice", mode .. ":" .. tostring(newTarget or "current-place"), at)
    end
    purpose.mode, purpose.destination, purpose.rationale = mode, dataCopy(destination), reason
    purpose.status, purpose.updatedAt = "maintained", at
    purpose.steps = destination and { { id = mode .. ":" .. destination.id, verb = "move",
        owner = "SAO.Locomotion", token = "route:arrived", target = destination.id,
        status = "available", x = destination.cx, y = destination.cy, z = destination.z or 0 } } or {}
    purpose.cursor = 1
    if destination and destination.exterior and destination.kind == "door" then
        -- A seen doorway supports an entry hypothesis one tile beyond its
        -- boundary. Native locomotion resolves locks and crossings; this is
        -- neither a known interior route nor evidence of contents.
        purpose.steps[2] = { id = "entry:" .. destination.id, verb = "move", owner = "SAO.Locomotion",
            token = "route:arrived", target = destination.id, status = "dependent",
            x = 2 * destination.surfaceX - destination.cx,
            y = 2 * destination.surfaceY - destination.cy, z = destination.z,
            basis = "observed-doorway-entry-hypothesis" }
    end
    return purpose
end

function P.residenceSuppressesReturn(id)
    local purpose = P.residencePurpose(id)
    return purpose ~= nil and (purpose.mode == "search" or purpose.mode == "depart")
end

-- Keep the just-handled target and recent exact routes. Bounded insertion
-- avoids sorting an inherited ledger that earlier successful visits widened.
local function trimResidenceAttempts(purpose, currentKey)
    local attempts, newest = purpose.residenceAttempts, {}
    for key, attempt in pairs(attempts) do
        if key ~= currentKey then
            local at = type(attempt) == "table" and finite(attempt.at) and attempt.at or -math.huge
            local index = #newest + 1
            while index > 1 do
                local priorKey = newest[index - 1]
                local prior = attempts[priorKey]
                local priorAt = type(prior) == "table" and finite(prior.at) and prior.at or -math.huge
                if priorAt > at or priorAt == at and tostring(priorKey) < tostring(key) then break end
                index = index - 1
            end
            if index < MAX_RESIDENCE_ATTEMPTS then
                table.insert(newest, index, key)
                if #newest >= MAX_RESIDENCE_ATTEMPTS then table.remove(newest) end
            end
        end
    end
    local kept = { [currentKey] = true }
    for _, key in ipairs(newest) do kept[key] = true end
    for key in pairs(attempts) do
        if not kept[key] then attempts[key] = nil end
    end
end

function P.deferResidenceRoute(id, reason)
    local purpose = P.residencePurpose(id)
    if not purpose or not purpose.destination then return false end
    local at, key = nowHours(), tostring(purpose.destination.id)
    purpose.residenceAttempts = purpose.residenceAttempts or {}
    local old = purpose.residenceAttempts[key]
    local count = math.min(4, (old and old.attempts or 0) + 1)
    purpose.residenceAttempts[key] = { attempts = count, at = at,
        retryAt = at + 0.25 * count, reason = tostring(reason or "native-route-refused") }
    trimResidenceAttempts(purpose, key)
    purpose.status, purpose.admission = "blocked", nil
    purpose.exteriorEntryPending = nil
    purpose.blockers = { tostring(reason or "native-route-refused") }
    purpose.nextAppraisalAt = at + 0.1
    addEvent(purpose, "residence-route-ended", reason, at)
    return true
end

function P.admitResidenceRoute(id, body, routeId)
    local purpose = P.residencePurpose(id)
    local step = purpose and purpose.steps[purpose.cursor]
    local job = SAO.Locomotion and SAO.Locomotion.jobs[id]
    if not purpose or purpose.admission or not step or not job or job.done or job.body ~= body
        or not job.goal or job.goal.x ~= step.x or job.goal.y ~= step.y or job.goal.z ~= step.z
        or type(routeId) ~= "string" then return false end
    purpose.admission = { owner = "SAO.Locomotion", correlationId = routeId,
        stepId = step.id, target = step.target, token = step.token, at = nowHours() }
    purpose.status = "executing"
    return true
end

function P.finishResidenceRoute(id, body, routeId, job)
    local purpose = P.residencePurpose(id)
    local admission = purpose and purpose.admission
    local step = purpose and purpose.steps[purpose.cursor]
    local live = SAO.Locomotion and SAO.Locomotion.jobs[id]
    local agent = SAO.Controller and SAO.Controller.agents[id]
    local binding = agent and agent.residenceRoute
    if not admission or not step or not job or job ~= live or not job.done or job.body ~= body
        or not binding or binding.job ~= job or binding.routeId ~= routeId
        or admission.correlationId ~= routeId or admission.stepId ~= step.id
        or not job.goal or job.goal.x ~= step.x or job.goal.y ~= step.y or job.goal.z ~= step.z then return false end
    if job.result ~= "arrived" then return P.deferResidenceRoute(id, "native-route:" .. tostring(job.result)) end
    local at, mode = nowHours(), purpose.mode
    local exterior = purpose.destination.exterior == true
    if exterior and purpose.cursor == 1 and purpose.steps[2] then
        purpose.admission = nil
        step.status, step.completedAt = "completed", at
        purpose.cursor, purpose.steps[2].status = 2, "available"
        purpose.exteriorEntryPending, purpose.exteriorEntryUntil = true, at + 0.25
        purpose.status, purpose.nextAppraisalAt = "maintained", at
        addEvent(purpose, "exterior-approached", step.target, at)
        return true
    end
    local residence = purpose.destination
    if exterior and purpose.cursor == 2 then
        local known = SAO.Perception.knownPlaces(id)
        local building = known[residence.buildingId] or known[tonumber(residence.buildingId)]
        if not building then return P.deferResidenceRoute(id, "doorway-entry-not-privately-observed") end
        residence = { id = purpose.destination.buildingId, cx = building.cx, cy = building.cy, z = building.z or 0 }
    end
    if mode == "depart" and (not exterior or purpose.cursor == 2) then
        if not (SAO.Standing and SAO.Standing.completeResidence
            and SAO.Standing.completeResidence(id, body, residence)) then
            return P.deferResidenceRoute(id, "residence-arrival-not-admitted")
        end
    end
    purpose.admission = nil
    step.status, step.completedAt = "completed", at
    purpose.residenceAttempts = purpose.residenceAttempts or {}
    purpose.residenceAttempts[tostring(step.target)] = { attempts = 0, at = at,
        retryAt = at + 0.5, reason = "visited-with-stock-still-unresolved" }
    trimResidenceAttempts(purpose, tostring(step.target))
    purpose.lastResidenceResult = { at = at, mode = mode, status = "arrived", target = step.target,
        correlationId = routeId, stock = "unknown-until-private-inspection" }
    purpose.exteriorEntryPending = nil
    purpose.mode = (mode == "search" or exterior) and mode or "stay"
    purpose.inspectUntil = (mode == "search" or exterior) and at + 0.25 or nil
    purpose.status, purpose.nextAppraisalAt = "maintained", at
    addEvent(purpose, "residence-arrived", mode .. ":" .. step.target, at)
    return true
end

-- Reconsider the same unmet purpose from current private means. An admitted
-- attempt or a completed acquisition keeps its exact physical chain while
-- danger, fatigue or accepted shared work can interrupt its execution.
local function resourceFailure(purpose, strategy, reason, at, stepId)
    if type(strategy) ~= "string" then return end
    purpose.routeFailures = purpose.routeFailures or {}
    local failure
    for _, prior in ipairs(purpose.routeFailures) do
        if prior.strategy == strategy then failure = prior; break end
    end
    if not failure then
        failure = { strategy = strategy, attempts = 0 }
        purpose.routeFailures[#purpose.routeFailures + 1] = failure
        if #purpose.routeFailures > 16 then table.remove(purpose.routeFailures, 1) end
    end
    failure.attempts = math.min(8, failure.attempts + 1)
    failure.stepId = stepId
    failure.failedAt, failure.reason = at, tostring(reason or "native-route-refused")
    failure.retryAt = at + math.min(0.5, 0.05 * 2 ^ (failure.attempts - 1))
end

function P.deferResourceRoute(id, purposeId, stepId, reason, atHours)
    local s = state(id)
    local purpose = s and s.purposes[purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.resourceCategory or purpose.admission
        or purpose.status == "completed" or purpose.status == "abandoned"
        or not step or step.id ~= stepId then return false end
    local at = finite(atHours) and atHours or nowHours()
    resourceFailure(purpose, purpose.selectedStrategy, reason, at, step.id)
    step.status, purpose.status = "blocked", "blocked"
    purpose.blockers, purpose.updatedAt = { "known-route-retry-delayed" }, at
    addEvent(purpose, "resource-route-refused", tostring(reason or "native-route-refused"), at)
    return true
end

function P.planResource(id, context)
    context = type(context) == "table" and context or {}
    if not SAO.Labor or not SAO.Labor.assess then return nil, "labor-unavailable" end
    local assessment, why = SAO.Labor.assess(id, context)
    if not assessment then return nil, why or "labor-unavailable" end
    local at = finite(context.atHours) and context.atHours or nowHours()
    P.resourceOutcomeDemand(id)
    local s = state(id)
    local purpose = context.purposeId and s and s.purposes[context.purposeId]
    if context.purposeId and (not purpose or not purpose.resourceOutcome
        or purpose.resourceCategory ~= assessment.category or purpose.status == "completed"
        or purpose.status == "abandoned") then
        return nil, "outcome-purpose-unavailable"
    end
    local current
    if not purpose then purpose, current = P.resourceDemand(id, assessment.category, context.hydrationIntent == true) end
    local supplied = assessment.category == "food" and assessment.demand.ownedReady > 0
        or assessment.category == "water" and (assessment.demand.ownedWater > 0
            or context.hydrationIntent == true and not context.purposeId and assessment.demand.ownedHydration > 0)
    if not purpose and (assessment.demand.pressure < 0.2 or supplied) then return nil, "no-current-resource-demand" end
    purpose = purpose or P.maintain(id, { key = "resource:" .. assessment.category,
        objective = assessment.category == "food" and "retain usable food through anticipated need"
            or "retain safe hydration through anticipated thirst",
        domain = "provisioning", origin = "private-resource-pressure", atHours = at })
    if not purpose then return nil, "person-unavailable" end
    purpose.resourceCategory = assessment.category
    purpose.demand, purpose.contacts, purpose.labor = dataCopy(assessment.demand),
        copyList(assessment.contacts, 16), dataCopy(assessment.dimensions)
    purpose.capacity, purpose.assessedAt = dataCopy(assessment.capacity), at
    if purpose.resourceOutcome then supplied = outcomeStock(purpose, context, at) end
    current = purpose.steps[purpose.cursor]
    if current and purpose.admission and purpose.admission.stepId == current.id then
        return purpose, current
    end
    local function suppliedGoal()
        if not supplied or purpose.admission then return false end
        if assessment.category == "food" and current and current.acquiredItemId then
            -- Retained item identity cannot be confirmed by contradictory
            -- type data. Other currently held usable food can satisfy demand
            -- without crediting the unfinished preparation of this item.
            local usable = false
            for _, item in ipairs(type(context.carriedReadyItems) == "table" and context.carriedReadyItems or {}) do
                if item.itemId ~= current.acquiredItemId or item.itemType == current.itemType then usable = true; break end
            end
            if not usable then return false end
        end
        for _, pending in ipairs(purpose.steps) do
            if pending.status ~= "completed" then pending.status, pending.resolvedAt = "not-required", at end
        end
        purpose.status, purpose.cursor, purpose.blockers = "completed", #purpose.steps + 1, {}
        purpose.updatedAt, purpose.resolvedAt, purpose.resolution = at, at, "native-owned-usable-stock"
        addEvent(purpose, "resource-goal-satisfied", "currently held usable stock satisfies demand without new work credit", at)
        return true
    end
    if purpose.resourceOutcome and suppliedGoal() then return purpose, nil end
    if purpose.awaitingReassessment or purpose.resourceOutcome and purpose.awaitingStock then
        for _, old in ipairs(purpose.steps) do
            purpose.completedSteps = purpose.completedSteps or {}
            purpose.completedSteps[#purpose.completedSteps + 1] = dataCopy(old)
            if #purpose.completedSteps > 16 then table.remove(purpose.completedSteps, 1) end
        end
        purpose.steps, purpose.cursor, purpose.awaitingStock, current = {}, 1, nil, nil
        purpose.awaitingReassessment = nil
    end
    -- A completed acquisition is evidence for this exact held item, not for
    -- arbitrary new raw inventory or another person's stock.
    if current and current.owner == "Cooking" and current.acquiredItemId then
        local acquired
        for _, prior in ipairs(purpose.steps) do
            if prior.owner == "SAO.SourceUse" and prior.status == "completed"
                and prior.itemId == current.acquiredItemId and prior.itemType == current.itemType then
                acquired = prior; break
            end
        end
        if acquired then
            for _, item in ipairs(type(context.carriedReadyItems) == "table" and context.carriedReadyItems or {}) do
                if item.itemId == current.acquiredItemId and item.itemType == current.itemType then
                    current.status, current.resolvedAt = "not-required", at
                    purpose.status, purpose.cursor, purpose.blockers = purpose.resourceOutcome
                        and "maintained" or "completed", #purpose.steps + 1, {}
                    if purpose.resourceOutcome then purpose.awaitingStock = true end
                    purpose.updatedAt = at
                    addEvent(purpose, "conditional-step-not-required", "native held item is already usable", at)
                    return purpose, nil
                end
            end
        end
        if suppliedGoal() then return purpose, nil end
        local held = false
        for _, item in ipairs(type(context.carriedRawItems) == "table" and context.carriedRawItems or {}) do
            if item.itemId == current.acquiredItemId and item.itemType == current.itemType
                and item.cookable == true then held = true; break end
        end
        local retryReady = true
        for _, failure in ipairs(purpose.routeFailures or {}) do
            if failure.stepId == current.id and finite(failure.retryAt) and at < failure.retryAt then retryReady = false end
        end
        if held and retryReady then
            purpose.blockers = assessment.blocker and { assessment.blocker } or {}
            purpose.status = #purpose.blockers > 0 and "blocked" or "maintained"
            current.status = #purpose.blockers > 0 and "blocked" or "available"
            purpose.updatedAt = at
            return purpose, current
        end
        if acquired and #assessment.options == 0 then
            purpose.blockers, purpose.status = { "acquired-item-not-currently-usable" }, "blocked"
            current.status, purpose.updatedAt = "blocked", at
            return purpose, current
        end
    end
    if suppliedGoal() then return purpose, nil end
    local candidates = {}
    local delayed = false
    for _, option in ipairs(assessment.options) do
        local failure
        for _, prior in ipairs(purpose.routeFailures or {}) do
            if prior.strategy == option.id or (option.cooking
                and prior.stepId == "prepare:" .. tostring(option.itemId)) then failure = prior; break end
        end
        if failure then
            option.previousFailures, option.lastFailure, option.retryAt = failure.attempts,
                failure.reason, failure.retryAt
        end
        local candidate = { id = option.id, evidence = option.evidence,
            continuity = option.continuity, novelty = option.novelty,
            informationGain = option.informationGain, blockers = option.blockers,
            appraisal = dataCopy(option.appraisal) }
        if failure then candidate.evidence = math.max(0, candidate.evidence - math.min(0.4, failure.attempts * 0.1)) end
        if purpose.selectedStrategy == option.id and not failure then candidate.continuity = 1 end
        if failure and finite(failure.retryAt) and at < failure.retryAt then
            option.retryDelayed, delayed = true, true
        else
            candidates[#candidates + 1] = candidate
        end
    end
    -- Both models share their existing sixteen-candidate contract. Preserve
    -- a private inspection route alongside the strongest known work routes.
    if #candidates > 16 then
        local inspect
        for _, candidate in ipairs(candidates) do
            if string.sub(candidate.id, 1, 8) == "inspect:" then inspect = candidate; break end
        end
        table.sort(candidates, function(a, b)
            local aScore = SAO.CognitiveModels.planScore("ordinary", a, assessment.demand.pressure)
            local bScore = SAO.CognitiveModels.planScore("ordinary", b, assessment.demand.pressure)
            if aScore == bScore then return a.id < b.id end
            return aScore > bScore
        end)
        local bounded, limit = {}, inspect and 15 or 16
        for _, candidate in ipairs(candidates) do
            if candidate ~= inspect and #bounded < limit then bounded[#bounded + 1] = candidate end
        end
        if inspect then bounded[#bounded + 1] = inspect end
        candidates = bounded
    end
    local views = #candidates > 0 and interpretations(id, candidates,
        { domain = "provisioning", category = assessment.category,
            pressure = assessment.demand.pressure, atHours = at, actorId = id }) or nil
    local selected
    for _, view in ipairs(views and views.models or {}) do
        if view.modelId == "ordinary" then selected = view.selected; break end
    end
    local option
    for _, candidate in ipairs(assessment.options) do
        if candidate.id == selected and not candidate.retryDelayed then option = candidate; break end
    end
    if not option then
        -- Cold model state cannot remove native feasibility. The ordinary
        -- evidence/continuity ordering supplies the same bounded fallback.
        local best
        for i, candidate in ipairs(candidates) do
            local score = SAO.CognitiveModels.planScore("ordinary", candidate, assessment.demand.pressure)
            if not best or score > best then
                for _, offered in ipairs(assessment.options) do
                    if offered.id == candidate.id then option = offered; break end
                end
                best = score
            end
        end
    end
    local steps, blockers = {}, {}
    if assessment.blocker then blockers[#blockers + 1] = assessment.blocker end
    if not option and delayed and not assessment.blocker then blockers[#blockers + 1] = "known-route-retry-delayed" end
    if option then
        if option.kind == "inspect" then
            steps[#steps + 1] = { id = option.id, verb = "inspect",
                owner = "SAO.WorldSources", token = "resource:inspected",
                target = option.place.sourceId, sourceId = option.place.sourceId, fingerprint = option.fingerprint,
                sourceX = option.sourceX, sourceY = option.sourceY, sourceZ = option.sourceZ,
                status = "available", category = assessment.category, place = dataCopy(option.place) }
        elseif option.kind == "refill-water" then
            steps[#steps + 1] = { id = option.id, verb = "produce",
                owner = "SAO.ResourceProduction", token = "resource:filled", target = "refill-water",
                status = "available", category = assessment.category, productionKind = "refill-water",
                sourceId = option.sourceId, sourceRevision = option.sourceRevision,
                fingerprint = option.fingerprint, sourceX = option.sourceX,
                sourceY = option.sourceY, sourceZ = option.sourceZ,
                place = dataCopy(option.place), itemId = option.itemId, itemType = option.itemType,
                beforeAmount = option.beforeAmount, capacity = option.capacity, quantityUnit = "fluid" }
        elseif option.kind ~= "prepare-owned" then
            steps[#steps + 1] = { id = "acquire:" .. tostring(option.sourceId) .. ":" .. tostring(option.sourceRevision)
                    .. ":" .. tostring(option.itemId),
                verb = "acquire", owner = "SAO.SourceUse", token = "resource:acquired",
                target = tostring(option.sourceId) .. ":" .. tostring(option.itemId),
                status = "available", category = option.materialCategory or assessment.category,
                hydrationIntent = option.hydrationIntent, sourceId = option.sourceId,
                sourceRevision = option.sourceRevision, place = dataCopy(option.place),
                itemId = option.itemId, itemType = option.itemType, quantity = 1, quantityUnit = "item" }
        end
        if option.cooking or (assessment.category == "food" and option.kind == "acquire-ready") then
            steps[#steps + 1] = { id = "prepare:" .. tostring(option.itemId), verb = "produce",
                owner = "Cooking", token = "cooking:prepared", target = "Cooking",
                status = #steps == 0 and "available" or "dependent",
                itemType = option.itemType, acquiredItemId = option.itemId,
                conditional = option.kind ~= "prepare-owned" }
        end
    end
    local previous = purpose.selectedStrategy
    setPlan(purpose, steps, blockers, views, at)
    purpose.selectedStrategy = option and option.id or nil
    purpose.rationale = option and option.rationale or blockers[1]
    purpose.appraisal = option and dataCopy(option.appraisal) or nil
    purpose.uncertainty = option and option.uncertainty or assessment.demand.uncertainty
    purpose.alternatives = dataCopy(assessment.options)
    purpose.decisionAt = at
    if previous ~= purpose.selectedStrategy then
        purpose.admission = nil
        addEvent(purpose, "resource-reconsidered", purpose.rationale, at)
    end
    return purpose, purpose.steps[purpose.cursor]
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
    if context.operation == "repair" then
        if type(context.entryKey) ~= "string" then return nil, "window-not-observed" end
        local purpose = P.maintain(id, { key = "repair:" .. context.entryKey,
            objective = "replace glass in a damaged entrance on held ground",
            domain = "construction", origin = "place-security", atHours = context.atHours })
        if not purpose then return nil, "person-unavailable" end
        local blockers = {}
        if not context.insideOwnedGround then blockers[#blockers + 1] = "not-on-owned-ground" end
        if not context.knownGround then blockers[#blockers + 1] = "window-not-observed" end
        if not context.hasPane then blockers[#blockers + 1] = "missing-carried-glass" end
        setPlan(purpose, {{ id = "repair-known-window", verb = "construct", owner = "SAO.WindowRepair",
            status = #blockers == 0 and "available" or "blocked", token = "construction:window-repaired",
            target = context.entryKey }}, blockers, interpretations(id, {
                { id = "repair", evidence = context.knownGround and 0.9 or 0.1,
                  continuity = 0.7, novelty = 0.1, informationGain = 0.3, blockers = #blockers }
            }, { domain = "construction", pressure = tonumber(context.pressure) or 0 }),
            finite(context.atHours) and context.atHours or nowHours())
        purpose.windowRepair = true
        return purpose, purpose.steps[purpose.cursor]
    end
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
    if purpose.resourceCategory and (not step or step.owner ~= owner) then return false end
    if purpose.resourceCategory and step.owner == "SAO.WorldSources" and not step.sourceId then return false end
    if stepId and (not step or step.id ~= stepId or step.owner ~= owner) then return false end
    purpose.admission = { owner = owner, correlationId = correlationId,
        stepId = step and step.id, target = step and step.target, token = step and step.token,
        at = nowHours() }
    addEvent(purpose, "admitted", owner .. ":" .. correlationId, purpose.admission.at)
    return true
end

function P.recordResult(id, purposeId, result, authority)
    local s = state(id)
    local purpose = s and s.purposes[tostring(purposeId or "")]
    if purpose and purpose.resourceCategory and authority ~= RESOURCE_RESULT then return false end
    if purpose and purpose.windowRepair and authority ~= WINDOW_REPAIR_RESULT then return false end
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
        purpose.status = purpose.cursor > #purpose.steps and not purpose.resourceOutcome and "completed" or "maintained"
        if purpose.resourceOutcome and purpose.cursor > #purpose.steps then purpose.awaitingStock = true end
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
            local started = purpose.admission and purpose.admission.at
            if purpose.resourceCategory and finite(started) and at >= started then
                practice.durationHours = practice.durationHours or {}
                practice.durationHours[#practice.durationHours + 1] = at - started
                if #practice.durationHours > 8 then table.remove(practice.durationHours, 1) end
                practice.timeBasis = "actor-native-admission-to-completed-result"
            end
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
        if purpose.resourceCategory and (result.status == "failed" or result.routeFailure == true) then
            resourceFailure(purpose, purpose.selectedStrategy, result.reason, at, step.id)
        end
    end
    purpose.updatedAt = at
    if receiptKey then
        purpose.resultReceipts = purpose.resultReceipts or {}
        purpose.resultReceipts[#purpose.resultReceipts + 1] = receiptKey
        if #purpose.resultReceipts > MAX_EVENTS then table.remove(purpose.resultReceipts, 1) end
    end
    if purpose.resourceCategory or purpose.windowRepair then
        purpose.lastAdmission = dataCopy(purpose.admission)
        purpose.admission = nil
    end
    addEvent(purpose, "result", result.status .. ":" .. result.token, at)
    return true
end

function P.consumeWindowRepairOutcome(id, sequence)
    local owner = SAO.WindowRepair
    local result = owner and owner.outcome(id, sequence)
    local s = state(id)
    local purpose = result and s and s.purposes[result.purposeId]
    if not result or not purpose or not purpose.windowRepair then return false end
    local admission = purpose.admission or purpose.lastAdmission
    if not admission or admission.owner ~= "SAO.WindowRepair"
        or admission.correlationId ~= result.workId
        or admission.target ~= result.entryKey then return false end
    local receipt = { owner = "SAO.WindowRepair", token = "construction:window-repaired",
        correlationId = result.workId, status = result.status, reason = result.reason,
        atHours = result.endedAt }
    if result.status == "completed" and (result.paneConsumed ~= true or result.smashedBefore ~= true
        or result.smashedAfter ~= false or result.glassRemovedAfter ~= false) then return false end
    if not P.recordResult(id, purpose.id, receipt, WINDOW_REPAIR_RESULT) then return false end
    return owner.acknowledge(id, sequence)
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
    if completed and purpose.resourceCategory and (step.sourceId ~= authoritative.sourceId
        or step.itemId ~= authoritative.itemId or step.category ~= authoritative.category) then return false end
    return P.recordResult(receipt.actorId, purpose.id, {
        owner = "SAO.SourceUse", token = admission.token,
        status = completed and "completed" or "interrupted",
        reason = authoritative.detail, correlationId = authoritative.reservationId,
        routeFailure = authoritative.status == "conflict",
        atHours = authoritative.at,
    }, RESOURCE_RESULT)
end

function P.admitInspection(id, receipt)
    if type(receipt) ~= "table" or type(receipt.id) ~= "string" or receipt.actorId ~= id
        or receipt.status ~= "admitted" then return false end
    local canonical = SAO.WorldSources and SAO.WorldSources.inspectionAdmission
        and SAO.WorldSources.inspectionAdmission(id, receipt.id)
    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id or canonical.status ~= "admitted"
        or canonical.purposeId ~= receipt.purposeId or canonical.purposeStepId ~= receipt.purposeStepId
        or canonical.sourceId ~= receipt.sourceId or canonical.fingerprint ~= receipt.fingerprint
        or canonical.sourceX ~= receipt.sourceX or canonical.sourceY ~= receipt.sourceY or canonical.sourceZ ~= receipt.sourceZ then return false end
    local s = state(id)
    local purpose = s and s.purposes[receipt.purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.resourceCategory or purpose.status == "completed" or purpose.status == "abandoned"
        or not step or step.status ~= "available" or step.owner ~= "SAO.WorldSources"
        or step.token ~= "resource:inspected" or step.id ~= receipt.purposeStepId
        or type(step.sourceId) ~= "string" or step.target ~= step.sourceId
        or type(step.fingerprint) ~= "string" or step.sourceId ~= receipt.sourceId
        or step.fingerprint ~= receipt.fingerprint
        or not finite(step.sourceX) or not finite(step.sourceY) or not finite(step.sourceZ)
        or step.sourceX ~= receipt.sourceX or step.sourceY ~= receipt.sourceY or step.sourceZ ~= receipt.sourceZ then return false end
    if purpose.admission and (purpose.admission.owner ~= step.owner
        or purpose.admission.correlationId ~= receipt.id) then return false end
    return P.noteAdmission(id, purpose.id, step.owner, receipt.id, step.id)
end

function P.consumeInspectionResult(id, receipt)
    if type(receipt) ~= "table" or receipt.actorId ~= id or not receipt.purposeId then return false end
    local canonical = SAO.WorldSources and SAO.WorldSources.inspectionOutcome
        and SAO.WorldSources.inspectionOutcome(id, receipt.id)
    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id
        or canonical.purposeId ~= receipt.purposeId or canonical.purposeStepId ~= receipt.purposeStepId
        or canonical.sourceId ~= receipt.sourceId or canonical.fingerprint ~= receipt.fingerprint
        or canonical.sourceX ~= receipt.sourceX or canonical.sourceY ~= receipt.sourceY or canonical.sourceZ ~= receipt.sourceZ
        or (canonical.status ~= "completed" and canonical.status ~= "failed" and canonical.status ~= "interrupted") then return false end
    local s = state(id)
    local purpose = s and s.purposes[canonical.purposeId]
    if not purpose or purpose.status == "abandoned" then return true, "purpose-retired" end
    local step, admission = purpose.steps[purpose.cursor], purpose.admission
    if not step or not admission or step.owner ~= "SAO.WorldSources" or step.token ~= "resource:inspected"
        or step.id ~= canonical.purposeStepId or admission.stepId ~= step.id
        or admission.owner ~= step.owner or canonical.id ~= admission.correlationId or admission.target ~= step.target then
        local key = "SAO.WorldSources:" .. canonical.id
        for _, seen in ipairs(purpose.resultReceipts or {}) do if seen == key then return true end end
        purpose.resultReceipts = purpose.resultReceipts or {}
        purpose.resultReceipts[#purpose.resultReceipts + 1] = key
        if #purpose.resultReceipts > MAX_EVENTS then table.remove(purpose.resultReceipts, 1) end
        addEvent(purpose, "result-retired", canonical.reason or canonical.status, canonical.atHours)
        return true, "purpose-attempt-superseded"
    end
    if step.sourceId ~= canonical.sourceId or step.fingerprint ~= canonical.fingerprint
        or step.sourceX ~= canonical.sourceX or step.sourceY ~= canonical.sourceY or step.sourceZ ~= canonical.sourceZ then return false end
    if canonical.status == "completed" and (canonical.nativeInspected ~= true or canonical.privateLearned ~= true) then return false end
    local consumed = P.recordResult(id, purpose.id, { owner = "SAO.WorldSources", token = "resource:inspected",
        status = canonical.status, correlationId = canonical.id, reason = canonical.reason,
        atHours = canonical.atHours }, RESOURCE_RESULT)
    if consumed and canonical.status == "completed" then
        purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "maintained", nil, true
    end
    return consumed
end

function P.admitProduction(id, work)
    if type(work) ~= "table" or type(work.id) ~= "string" or work.actorId ~= id
        or work.kind ~= "refill-water" then return false end
    local s = state(id)
    local purposeId = work.requestedPurposeId or work.purposeId
    local stepId = work.requestedPurposeStepId or work.purposeStepId
    local purpose = s and s.purposes[purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or purpose.status == "completed" or purpose.status == "abandoned"
        or purpose.resourceCategory ~= "water" or not step
        or step.id ~= stepId or step.owner ~= "SAO.ResourceProduction"
        or step.productionKind ~= work.kind or step.token ~= "resource:filled"
        or step.itemId ~= work.itemId or step.itemType ~= work.itemType
        or step.sourceId ~= work.sourceId or step.sourceRevision ~= work.sourceRevision
        or step.fingerprint ~= work.fingerprint then return false end
    if purpose.admission and (purpose.admission.owner ~= step.owner
        or purpose.admission.correlationId ~= work.id) then return false end
    local admitted = P.noteAdmission(id, purpose.id, step.owner, work.id, step.id)
    if admitted then work.purposeId, work.purposeStepId = purpose.id, step.id end
    return admitted
end

function P.consumeProductionResult(id, receipt)
    if type(receipt) ~= "table" or not receipt.purposeId then return false end
    local owner = SAO.ResourceProduction
    local canonical = owner and owner.outcome and owner.outcome(id, receipt.id)
    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id
        or canonical.purposeId ~= receipt.purposeId or canonical.kind ~= "refill-water"
        or canonical.token ~= "resource:filled"
        or (canonical.status ~= "completed" and canonical.status ~= "interrupted"
            and canonical.status ~= "failed") then return false end
    local s = state(id)
    local purpose = s and s.purposes[canonical.purposeId]
    if not purpose or purpose.status == "abandoned" then return true, "purpose-retired" end
    local step, admission = purpose.steps[purpose.cursor], purpose.admission
    if not step or not admission or step.owner ~= "SAO.ResourceProduction"
        or step.id ~= canonical.purposeStepId or admission.stepId ~= step.id
        or admission.owner ~= step.owner or canonical.id ~= admission.correlationId
        or admission.target ~= step.target then return true, "purpose-attempt-superseded" end
    if canonical.sourceId ~= step.sourceId or canonical.sourceRevision ~= step.sourceRevision
        or canonical.fingerprint ~= step.fingerprint or canonical.itemId ~= step.itemId
        or canonical.itemType ~= step.itemType or canonical.kind ~= step.productionKind then return false end
    local completed = canonical.status == "completed"
    if completed and (not (canonical.nativeCredit == canonical.id) or canonical.held ~= true
        or canonical.clean ~= true or not finite(canonical.nativeGain) or canonical.nativeGain <= 0
        or not finite(canonical.beforeAmount) or not finite(canonical.afterAmount)
        or canonical.afterAmount <= canonical.beforeAmount) then return false end
    return P.recordResult(id, purpose.id, { owner = "SAO.ResourceProduction", token = step.token,
        status = completed and "completed" or canonical.status == "interrupted" and "interrupted" or "failed",
        correlationId = canonical.id, reason = canonical.detail, atHours = canonical.atHours }, RESOURCE_RESULT)
end

function P.admitCooking(id, work)
    if type(work) ~= "table" or type(work.id) ~= "string" then return false end
    local purpose, step
    if work.requestedPurposeId then
        local s = state(id)
        purpose = s and s.purposes[work.requestedPurposeId]
        step = purpose and purpose.steps[purpose.cursor]
        if not purpose or purpose.status == "completed" or purpose.status == "abandoned"
            or not step or step.owner ~= "Cooking" or step.target ~= "Cooking"
            or step.id ~= work.requestedPurposeStepId
            or (step.acquiredItemId and step.acquiredItemId ~= work.itemId) then return false end
    else
        purpose, step = P.pending(id, "practice", "Cooking")
    end
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
    }, RESOURCE_RESULT)
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
    local out = { purposes = {}, resourceOutcomeRequests = {}, spatialFacts = #s.spatialOrder,
        study = SAO.Study and SAO.Study.snapshot and SAO.Study.snapshot(id) or nil,
        practiceDomains = 0 }
    for _, practice in pairs(s.practice) do
        if (tonumber(practice.completed) or 0) > 0 then
            out.practiceDomains = out.practiceDomains + 1
        end
    end
    for _, id in ipairs(s.resourceOutcomeOrder or {}) do
        out.resourceOutcomeRequests[#out.resourceOutcomeRequests + 1] = dataCopy(s.resourceOutcomeRequests[id])
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
                interpretations = dataCopy(purpose.interpretations),
                resourceCategory = purpose.resourceCategory, demand = dataCopy(purpose.demand),
                origin = purpose.origin, authority = purpose.authority,
                resourceOutcome = dataCopy(purpose.resourceOutcome), outcomeProgress = dataCopy(purpose.outcomeProgress),
                resolution = purpose.resolution, resolvedAt = purpose.resolvedAt,
                contacts = copyList(purpose.contacts, 16), capacity = dataCopy(purpose.capacity),
                labor = dataCopy(purpose.labor), selectedStrategy = purpose.selectedStrategy,
                rationale = purpose.rationale, uncertainty = purpose.uncertainty,
                appraisal = dataCopy(purpose.appraisal),
                decisionAt = purpose.decisionAt, assessedAt = purpose.assessedAt,
                sequence = dataCopy(purpose.steps), completedSteps = dataCopy(purpose.completedSteps),
                alternatives = dataCopy(purpose.alternatives), routeFailures = dataCopy(purpose.routeFailures) }
            local row = out.purposes[#out.purposes]
            if purpose.residence then
                row.residence = { mode = purpose.mode, destination = dataCopy(purpose.destination),
                    appraisal = dataCopy(purpose.appraisal), lastResult = dataCopy(purpose.lastResidenceResult),
                    attempts = dataCopy(purpose.residenceAttempts), nextAppraisalAt = purpose.nextAppraisalAt }
            end
        end
    end
    return out
end

return P
