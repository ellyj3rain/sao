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
if not SAO.SituationAppraisal and type(require)=="function" then pcall(require,"SAO_SituationAppraisal") end
local retainSituation=SAO.SituationAppraisal and SAO.SituationAppraisal.bindPlanner(P)
local RESOURCE_RESULT = {}
local WINDOW_REPAIR_RESULT = {}
local BARRICADE_RESULT = {}
local CRAFT_RESULT = {}
local REPAIR_RESULT = {}
local BED_RESULT = {}
local BED_RECOVERY_RESULT = {}
local INSTRUMENT_RESULT = {}
local NOTE_RESULT = {}
local HOBBY_RESULT = {}
local GENERATOR_RESULT = {}
local GENERATOR_READING_RESULT = {}

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
local function dataCopy(value, depth, maximumDepth)
    depth = depth or 0
    maximumDepth = maximumDepth or 6
    if depth > maximumDepth then return nil end
    if type(value) == "string" then return string.sub(value, 1, 512) end
    if type(value) == "number" then return finite(value) and value or nil end
    if type(value) == "boolean" then return value end
    if type(value) ~= "table" then return nil end
    local out, count = {}, 0
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            count = count + 1
            if count > 32 then break end
            out[key] = dataCopy(item, depth + 1, maximumDepth)
        end
    end
    return out
end

-- A completed personal activity can leave an optional invitation to share.
-- That possibility is not an admitted obligation and need not occupy a live
-- intention slot while another purpose needs attention.
local function optionalSharing(purpose)
    if not purpose or not purpose.leisure or purpose.admission
        or purpose.status == "abandoned" or purpose.status == "completed" then return false end
    local performed, pending = false, false
    for _, step in ipairs(purpose.steps or {}) do
        if step.id == "perform-activity" and step.status == "completed" then performed = true end
        if step.status ~= "completed" then
            if step.required ~= false then return false end
            pending = true
        end
    end
    return performed and pending
end
local function suspendedPurpose(s, key)
    for _, ledger in ipairs({ s.suspendedLeisure or {}, s.queuedPurposes or {} }) do
        for _, id in ipairs(ledger.order or {}) do
            local purpose = ledger.purposes[id]
            if purpose and purpose.key == key and purpose.status == "suspended"
                and purpose.suspendedStatus ~= "completed" and purpose.suspendedStatus ~= "abandoned" then return purpose, ledger end
        end
    end
end
local function retirePurpose(s, index)
    local removed = table.remove(s.order, index)
    local old = s.purposes[removed]
    if optionalSharing(old) then
        s.suspendedLeisure = s.suspendedLeisure or { purposes = {}, order = {}, omitted = 0 }
        local ledger = s.suspendedLeisure
        old.status, old.suspendedAt = "suspended", nowHours()
        old.suspensionReason = "another-purpose-needs-active-capacity"
        addEvent(old, "suspended", "optional-sharing-remains-unresolved", old.suspendedAt)
        ledger.purposes[removed] = old
        ledger.order[#ledger.order + 1] = removed
        while #ledger.order > MAX_EVENTS do
            ledger.purposes[table.remove(ledger.order, 1)] = nil
            ledger.omitted = ledger.omitted + 1 -- bounded retention, never a completion claim
        end
    end
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
    local suspended, suspensionLedger
    if not purpose then suspended, suspensionLedger = suspendedPurpose(s, spec.key) end
    local at = finite(spec.atHours) and spec.atHours or nowHours()
    if suspended and suspensionLedger == s.queuedPurposes then return P.resumeQueuedPurpose(id, suspended.id) end
    if not purpose then
        if #s.order >= MAX_PURPOSES then
            local removable
            for i, purposeId in ipairs(s.order) do
                local prior = s.purposes[purposeId]
                if not prior or not prior.admission and (not prior.leisure or optionalSharing(prior)
                    or prior.status == "completed" or prior.status == "abandoned") and (not prior.residence
                    or prior.status == "completed" or prior.status == "abandoned") and (not prior.resourceOutcome
                    or prior.status == "completed" or prior.status == "abandoned") then removable = i; break end
            end
            if not removable then return nil end
            retirePurpose(s, removable)
        end
        if suspended then
            local ledger = suspensionLedger
            ledger.purposes[suspended.id] = nil
            for i, id in ipairs(ledger.order) do
                if id == suspended.id then table.remove(ledger.order, i); break end
            end
            purpose = suspended
            purpose.status, purpose.revivedAt = purpose.suspendedStatus or "maintained", at
            addEvent(purpose, "revived", "retained-purpose-requires-owned-execution", at)
        else
        s.nextPurpose = s.nextPurpose + 1
        purpose = { id = "purpose/" .. tostring(s.nextPurpose), key = spec.key,
            objective = spec.objective, domain = tostring(spec.domain or "general"),
            origin = tostring(spec.origin or "self"), authority = spec.authority,
            createdAt = at, updatedAt = at, status = "maintained", revision = 1,
            blockers = {}, steps = {}, cursor = 1, events = {} }
        addEvent(purpose, "formed", purpose.objective, at)
        end
        s.purposes[purpose.id] = purpose
        s.order[#s.order + 1] = purpose.id
    elseif purpose.objective ~= spec.objective then
        purpose.objective, purpose.revision = spec.objective, purpose.revision + 1
        addEvent(purpose, "revised", purpose.objective, at)
    end
    purpose.updatedAt = at
    return purpose
end

function P.queuedPurpose(id)
    local s = state(id)
    local ledger = s and s.queuedPurposes
    for _, key in ipairs(ledger and ledger.order or {}) do
        local purpose = ledger.purposes[key]
        if purpose and not purpose.conflict and purpose.status == "suspended"
            and purpose.suspendedStatus ~= "completed" and purpose.suspendedStatus ~= "abandoned" then
            return { id = purpose.id, key = purpose.key, domain = purpose.domain, status = purpose.status }
        end
    end
end

function P.resumeQueuedPurpose(id, purposeId)
    local s = state(id)
    local ledger = s and s.queuedPurposes
    local next = not purposeId and P.queuedPurpose(id)
    local key = purposeId or next and next.id
    local purpose = ledger and key and ledger.purposes[key]
    if not purpose or purpose.admission or purpose.status ~= "suspended"
        or purpose.suspendedStatus == "completed" or purpose.suspendedStatus == "abandoned" then return nil end
    local replace
    if #s.order >= MAX_PURPOSES then
        for index, activeId in ipairs(s.order) do
            local active = s.purposes[activeId]
            if active and not active.admission then
                replace = replace or index
                -- The ordinary caller has established that no current danger
                -- owns this turn; preserve that conflict record off the live set.
                if not purpose.conflict and active.conflict then replace = index; break end
            end
        end
        if not replace then return nil, "native-handback-required" end
    end
    for index, queuedId in ipairs(ledger.order) do
        if queuedId == key then table.remove(ledger.order, index); break end
    end
    ledger.purposes[key] = nil
    if replace then
        local activeId = table.remove(s.order, replace)
        local active = s.purposes[activeId];s.purposes[activeId] = nil
        active.suspendedStatus, active.status = active.status, "suspended"
        active.suspendedIndex = replace
        active.suspendedAt, active.suspensionReason = nowHours(), "another-retained-purpose-resumes"
        addEvent(active, "suspended", active.suspensionReason, active.suspendedAt)
        ledger.purposes[activeId] = active;ledger.order[#ledger.order + 1] = activeId
    end
    purpose.status, purpose.revivedAt = purpose.suspendedStatus or "maintained", nowHours()
    s.purposes[key] = purpose
    local position = finite(purpose.suspendedIndex) and math.floor(purpose.suspendedIndex) or #s.order + 1
    table.insert(s.order, clamp(position, 1, #s.order + 1), key)
    addEvent(purpose, "revived", "retained-purpose-requires-owned-execution", purpose.revivedAt)
    if purpose.resourceOutcome then P.resourceOutcomeDemand(id) end
    return purpose
end

-- This handoff is reachable only after canonical private conflict appraisal.
-- It preserves accepted work without pretending that its executor completed or
-- cancelled anything. A native admission must hand back through its own owner.
local function queueForConflict(s, at)
    if not s then return false, "conflict-purpose-capacity" end
    local ledger = s.queuedPurposes
    if ledger and #ledger.order >= MAX_EVENTS then return false, "queued-purpose-capacity" end
    for index, id in ipairs(s.order) do
        local purpose = s.purposes[id]
        if purpose and not purpose.admission then
            s.queuedPurposes = ledger or { purposes = {}, order = {} }
            ledger = s.queuedPurposes
            purpose.suspendedStatus, purpose.status = purpose.status, "suspended"
            purpose.suspendedIndex = index
            purpose.suspendedAt, purpose.suspensionReason = at, "current-conflict-needs-execution"
            addEvent(purpose, "suspended", purpose.suspensionReason, at)
            ledger.purposes[id] = purpose; ledger.order[#ledger.order + 1] = id
            table.remove(s.order, index);s.purposes[id] = nil
            return true
        end
    end
    return false, "conflict-native-handback-required"
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
    local oldPurpose = prior and (s.purposes[prior.purposeId]
        or s.queuedPurposes and s.queuedPurposes.purposes[prior.purposeId])
    if prior then
        if prior.request.sourceDefinition ~= request.sourceDefinition then
            return nil, "outcome-source-conflict"
        end
        if request.revision <= prior.request.revision then
            if sameOutcome(prior.request, request) then
                if not oldPurpose then return nil, "outcome-purpose-retired" end
                if not s.purposes[oldPurpose.id] then
                    local revived = P.resumeQueuedPurpose(id, oldPurpose.id)
                    if not revived then return nil, "outcome-awaiting-active-capacity" end
                    oldPurpose = revived
                end
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
            if not p or not p.admission and (not p.leisure or optionalSharing(p)
                or p.status == "completed" or p.status == "abandoned") and (not p.residence
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
    if purpose.resourceCategory or purpose.materialWork then
        local kept = {}
        for _, step in ipairs(steps) do kept[step.id] = true end
        for _, old in ipairs(purpose.steps or {}) do
            local replacement = nil
            if purpose.materialWork then
                for _, step in ipairs(steps) do if step.id == old.id then replacement = step; break end end
            end
            if old.status == "completed" and (not kept[old.id]
                or replacement and replacement.target ~= old.target) then
                purpose.completedSteps = purpose.completedSteps or {}
                purpose.completedSteps[#purpose.completedSteps + 1] = dataCopy(old)
                if #purpose.completedSteps > 16 then table.remove(purpose.completedSteps, 1) end
            end
        end
    end
    for _, step in ipairs(steps) do
        local old = prior[step.id]
        if old and old.status == "completed" and (not purpose.materialWork
            or old.owner == step.owner and old.target == step.target
                and old.sourceId == step.sourceId and old.sourceRevision == step.sourceRevision
                and old.itemId == step.itemId and old.itemType == step.itemType) then
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

-- Pausing for recovery preserves the uncompleted search without teaching a
-- route failure or carrying an old native admission through reload.
function P.pauseResidenceForRecovery(id)
    local purpose = P.residencePurpose(id)
    if not purpose or purpose.mode ~= "search" then return false end
    purpose.recoveryInterrupted = { mode = purpose.mode, destination = dataCopy(purpose.destination),
        steps = dataCopy(purpose.steps), cursor = purpose.cursor, at = nowHours() }
    purpose.admission, purpose.exteriorEntryPending = nil, nil
    purpose.status, purpose.nextAppraisalAt = "maintained", nowHours()
    addEvent(purpose, "residence-search-paused", "bodily-recovery", nowHours())
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
    local recovery = (appraisal.recoveryKind == "sleep" or appraisal.recoveryKind == "rest")
        and appraisal.recoveryHome == true and appraisal.conflict == 0 and appraisal.homeDanger.count == 0
        and not appraisal.currentResourceOwner and not appraisal.localRelief
    if purpose.exteriorEntryPending and not recovery and at < (purpose.exteriorEntryUntil or 0)
        and purpose.status ~= "blocked" then return purpose end
    purpose.exteriorEntryPending = nil
    local hunger, thirst = tonumber(appraisal.needs.hunger) or 0, tonumber(appraisal.needs.thirst) or 0
    local urgent = math.max(hunger, thirst) >= 0.35
    local unsafeHome = appraisal.conflict > 0 or appraisal.homeDanger.count > 0
    local fatigue = tonumber(appraisal.capacity.fatigue) or 0
    local traits = SAO.Disposition and SAO.Disposition.traits and SAO.Disposition.traits(id) or {}
    local fear = 1 - (tonumber(traits.nerve) or 0.5)
    local best, bestScore
    local alternatives, destinations = {}, {}
    for _, candidate in ipairs(appraisal.candidates) do
        local failure = purpose.residenceAttempts and purpose.residenceAttempts[candidate.id]
        local delayed = failure and not failure.supersededAt and finite(failure.retryAt) and at < failure.retryAt
        if delayed and failure.apertureState and candidate.apertureState ~= "unknown"
            and candidate.apertureState ~= failure.apertureState
            and finite(candidate.acquiredAt) and candidate.acquiredAt > (failure.observedAt or math.huge) then
            delayed = false
            failure.supersededAt = at
        end
        if not delayed and (candidate.distance > 3 or candidate.exterior) then
            local score = 1 - candidate.distance / 400 - candidate.danger * (0.5 + fear)
                - fatigue * candidate.distance / 250 - appraisal.responsibilities * 0.1
            if candidate.exterior then
                -- Visible passage and encountered resistance change the cost of
                -- this approach. These bounded weights remain policy choices.
                local condition = candidate.apertureState
                if candidate.kind == "window" then score = score - 0.15 end
                if condition == "open" or condition == "clear" then score = score + 0.3
                elseif condition == "smashed" then score = score - 0.5
                elseif condition == "barricaded" then score = score - 1 end
                local encountered = candidate.entryFailure
                if encountered and finite(encountered.atHours) and encountered.atHours <= at then
                    score = score - (1 + math.min(4, encountered.attempts or 1) * 0.25)
                        / (1 + at - encountered.atHours)
                end
            end
            if unsafeHome then score = score + 1 - math.min(0.6, appraisal.attachment * 0.15) end
            if urgent then score = score + math.max(hunger, thirst) end
            if not bestScore or score > bestScore then best, bestScore = candidate, score end
            alternatives[#alternatives + 1] = { id = candidate.id, utility = clamp(score, -16, 16),
                evidence = 1, continuity = 0, novelty = 0, informationGain = 0, blockers = 0,
                consequences = candidate.exterior and { { kind = "entry", category = "body",
                    sourceId = candidate.id, condition = candidate.apertureState, value = 1.5 } } or {} }
            destinations[candidate.id] = candidate
        end
    end
    local views = #alternatives > 0 and interpretations(id, alternatives,
        { actorId = id, domain = "residence", pressure = math.max(hunger, thirst), atHours = at }) or nil
    if views and destinations[views.selected] then
        best = destinations[views.selected]
        for _, view in ipairs(views.models) do
            if view.modelId == views.selectedModelId then bestScore = view.score end
        end
    end
    purpose.interpretations = dataCopy(views, 0, 8)
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
    if recovery then
        if purpose.mode == "search" then P.pauseResidenceForRecovery(id) end
        mode, reason = "recover", "chooses bodily recovery at the remembered permitted home"
    elseif depart then
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
        and not unsafeHome and not recovery then mode, reason = "search", "observes and inspects the reached place"; best = nil end
    local destination = (mode == "search" or mode == "depart") and best
        or (mode == "return" or mode == "recover" and context.awayFromHome) and { id = "home", cx = appraisal.home.x, cy = appraisal.home.y, z = appraisal.home.z } or nil
    local priorTarget = purpose.destination and purpose.destination.id
    local newTarget = destination and destination.id
    if purpose.mode ~= mode or priorTarget ~= newTarget then
        purpose.revision = purpose.revision + 1
        addEvent(purpose, "residence-choice", mode .. ":" .. tostring(newTarget or "current-place"), at)
    end
    if purpose.mode == "recover" and mode ~= "recover" and purpose.recoveryInterrupted then
        addEvent(purpose, "residence-search-reconsidered", mode, at)
        purpose.recoveryInterrupted = nil
    end
    purpose.mode, purpose.destination, purpose.rationale = mode, dataCopy(destination), reason
    purpose.status, purpose.updatedAt = "maintained", at
    purpose.steps = destination and { { id = mode .. ":" .. destination.id, verb = "move",
        owner = "SAO.Locomotion", token = "route:arrived", target = destination.id,
        status = "available", x = destination.cx, y = destination.cy, z = destination.z or 0 } } or {}
    purpose.cursor = 1
    if destination and destination.exterior
        and (destination.kind == "door" or destination.kind == "window") then
        -- A seen doorway supports an entry hypothesis one tile beyond its
        -- boundary. Native locomotion resolves locks and crossings; this is
        -- neither a known interior route nor evidence of contents.
        purpose.steps[2] = { id = "entry:" .. destination.id, verb = "move", owner = "SAO.Locomotion",
            token = "route:arrived", target = destination.id, status = "dependent",
            x = 2 * destination.surfaceX - destination.cx,
            y = 2 * destination.surfaceY - destination.cy, z = destination.z,
            basis = destination.kind == "window" and "observed-window-entry-hypothesis"
                or "observed-doorway-entry-hypothesis" }
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
        retryAt = at + 0.25 * count, reason = tostring(reason or "native-route-refused"),
        apertureState = purpose.destination.apertureState, observedAt = purpose.destination.acquiredAt }
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
    if job.result ~= "arrived" then
        if SAO.Perception and SAO.Perception.noteEntryOutcome then
            SAO.Perception.noteEntryOutcome(id, body, job)
        end
        return P.deferResidenceRoute(id, "native-route:" .. tostring(job.result))
    end
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
        if SAO.Perception.noteEntrySuccess then SAO.Perception.noteEntrySuccess(id,body,job) end
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
    purpose.mode = (mode == "search" or mode == "recover" or exterior) and mode or "stay"
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
    if not purpose or not (purpose.resourceCategory or purpose.materialWork) or purpose.admission
        or purpose.status == "completed" or purpose.status == "abandoned"
        or not step or step.id ~= stepId then return false end
    local at = finite(atHours) and atHours or nowHours()
    resourceFailure(purpose, purpose.selectedStrategy, reason, at, step.id)
    step.status, purpose.status = "blocked", "blocked"
    purpose.blockers, purpose.updatedAt = { "known-route-retry-delayed" }, at
    addEvent(purpose, "resource-route-refused", tostring(reason or "native-route-refused"), at)
    return true
end

local materialSource, materialAcquisitionId
local function plumbingTool(option)
    return (finite(option.toolItemId) or type(option.toolItemId) == "string" and option.toolItemId ~= "")
        and type(option.toolItemType) == "string" and option.toolItemType ~= ""
end
local function plumbingStep(option, status)
    return { id = "plumb:" .. option.sourceId .. ":" .. option.sourceRevision
            .. ":" .. tostring(option.itemId) .. ":" .. tostring(option.toolItemId or "missing-tool"),
        verb = "produce", owner = "SAO.ResourceProduction", token = "resource:plumbed",
        target = "plumb-fixture", productionKind = "plumb-fixture", category = "water", status = status,
        sourceId = option.sourceId, sourceRevision = option.sourceRevision, fingerprint = option.fingerprint,
        sourceX = option.sourceX, sourceY = option.sourceY, sourceZ = option.sourceZ,
        place = dataCopy(option.place), itemId = option.itemId, itemType = option.itemType,
        beforeAmount = option.beforeAmount, capacity = option.capacity, quantityUnit = "fluid",
        toolCategory = "pipe-wrench", toolItemId = plumbingTool(option) and tostring(option.toolItemId) or nil,
        toolItemType = option.toolItemType }
end

local COLLECTOR_MATERIALS = { hinge=true,doorknob=true,mattress=true, hammer = true, plank = true, nails = true, ["garbage-bag"] = true, tarp = true }
local function collectorDeficits(option)
    if type(option.requirements) ~= "table" or #option.requirements < 1 or #option.requirements > 8
        or type(option.inputs) ~= "table" or #option.inputs > 32 then return nil end
    local slots, counts, identities = {}, {}, {}
    for _, required in ipairs(option.requirements) do
        if type(required) ~= "table" or not finite(required.inputIndex) or required.inputIndex < 0
            or required.inputIndex ~= math.floor(required.inputIndex) or slots[required.inputIndex]
            or not COLLECTOR_MATERIALS[required.category] or not finite(required.count)
            or required.count < 1 or required.count > 16 or required.count ~= math.floor(required.count)
            or required.mode ~= "keep" and required.mode ~= "consume" then return nil end
        slots[required.inputIndex], counts[required.inputIndex] = required, 0
    end
    for _, input in ipairs(option.inputs) do
        local required = type(input) == "table" and slots[input.inputIndex]
        local identity = type(input) == "table" and (finite(input.itemId) or type(input.itemId) == "string" and input.itemId ~= "")
            and tostring(input.itemId)
        if not required or not identity or identities[identity] or type(input.itemType) ~= "string" or input.itemType == ""
            or input.mode ~= required.mode then return nil end
        identities[identity] = true
        counts[input.inputIndex] = counts[input.inputIndex] + 1
        if counts[input.inputIndex] > required.count then return nil end
    end
    local missing = {}
    for _, required in ipairs(option.requirements) do
        if counts[required.inputIndex] < required.count then missing[#missing + 1] = required end
    end
    return missing
end
function P.collectorReady(option)
    local missing = type(option) == "table" and collectorDeficits(option)
    return missing ~= nil and #missing == 0, missing and dataCopy(missing) or nil
end
local function collectorSite(row)
    return row and (row.site or { key = row.siteKey, revision = row.siteRevision,
        x = row.siteX, y = row.siteY, z = row.siteZ, observedAtHours = row.siteObservedAtHours })
end
local function collectorSame(a, b)
    local first, second = collectorSite(a), collectorSite(b)
    return a and b and a.entityId == b.entityId and a.recipeId == b.recipeId
        and a.sourceId == b.sourceId and a.sourceRevision == b.sourceRevision and a.fingerprint == b.fingerprint
        and a.itemId == b.itemId and a.itemType == b.itemType and first and second
        and first.key == second.key and first.revision == second.revision
        and first.x == second.x and first.y == second.y and first.z == second.z
end
local function collectorStep(option, status)
    local step = plumbingStep(option, status)
    step.id = "collector:" .. option.sourceId .. ":" .. option.sourceRevision .. ":" .. tostring(option.itemId)
        .. ":" .. option.entityId .. ":" .. option.site.key .. ":" .. tostring(option.site.revision)
    step.target, step.productionKind, step.token = option.entityId, "build-rain-collector", "resource:collector-built"
    step.entityId, step.recipeId, step.site = option.entityId, option.recipeId, dataCopy(option.site)
    step.requirements, step.inputs = dataCopy(option.requirements), dataCopy(option.inputs)
    step.toolCategory, step.toolItemId, step.toolItemType = nil, nil, nil
    return step
end
local function collectorMeans(purpose, option, sources, at)
    local missing = collectorDeficits(option)
    if not missing then return nil, "invalid-native-collector-inputs" end
    if #missing == 0 then return nil, nil, true end
    local required = missing[1]
    local source, delayed = materialSource(purpose, sources, required.category, at)
    return source, not source and (delayed and "known-route-retry-delayed" or "missing-private-collector-" .. required.category) or nil, false
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
    local executable = false
    for _, option in ipairs(assessment.options) do
        if option.kind == "build-rain-collector" then
            local built = purpose.collector and purpose.collector.constructedWorkId and purpose.collector.sourceId == option.sourceId
            if built then option.collectorUnavailable = true
            else
                option.materialSource, option.materialBlocker, option.collectorReady = collectorMeans(purpose, option, assessment.materialSources, at)
                option.collectorUnavailable = not option.collectorReady and not option.materialSource
                if not option.collectorUnavailable then executable = true end
            end
        elseif option.kind == "plumb-fixture" then
            local held = plumbingTool(option)
            local source, delayed
            if not held then source, delayed = materialSource(purpose, assessment.toolSources, "pipe-wrench", at) end
            option.toolSource, option.toolDelayed = source, not held and delayed
            option.toolUnavailable = not held and not source
            if held or source then executable = true end
        else executable = true end
    end
    if purpose.collector and not purpose.collector.constructedWorkId and current then
        local retry = false
        for _, failure in ipairs(purpose.routeFailures or {}) do
            if failure.stepId == current.id and finite(failure.retryAt) and at < failure.retryAt then retry = true end
        end
        if not retry then
            for _, option in ipairs(assessment.options) do
                if option.kind == "build-rain-collector" and collectorSame(purpose.collector, option)
                    and (option.collectorReady or option.materialSource) then
                    local steps = {}
                    if option.materialSource then
                        local source = option.materialSource
                        steps[1] = { id = materialAcquisitionId(source), verb = "acquire", owner = "SAO.SourceUse",
                            token = "resource:acquired", target = source.sourceId .. ":" .. tostring(source.itemId),
                            status = "available", category = source.category, sourceId = source.sourceId,
                            sourceRevision = source.revision, place = dataCopy(source.place), itemId = source.itemId,
                            itemType = source.itemType, quantity = 1, quantityUnit = "item" }
                    end
                    steps[#steps + 1] = collectorStep(option, #steps > 0 and "dependent" or "available")
                    setPlan(purpose, steps, {}, purpose.interpretations, at)
                    return purpose, purpose.steps[purpose.cursor]
                end
            end
        end
    end
    -- Exact acquired means retain their personally observed fixture while the
    -- native owner takes the return route. Carried water can satisfy the parent
    -- above; this continuation does not force plumbing before useful hydration.
    if purpose.plumbing and current and current.productionKind == "plumb-fixture" then
        local retry = false
        for _, failure in ipairs(purpose.routeFailures or {}) do
            if failure.stepId == current.id and finite(failure.retryAt) and at < failure.retryAt then retry = true end
        end
        if not retry then
            for _, option in ipairs(assessment.options) do
                if option.kind == "plumb-fixture" and plumbingTool(option)
                    and option.sourceId == current.sourceId and option.sourceRevision == current.sourceRevision
                    and option.fingerprint == current.fingerprint and option.itemId == current.itemId
                    and option.itemType == current.itemType and tostring(option.toolItemId) == current.toolItemId
                    and option.toolItemType == current.toolItemType then
                    local step = plumbingStep(option, "available")
                    setPlan(purpose, { step }, {}, purpose.interpretations, at)
                    return purpose, purpose.steps[purpose.cursor]
                end
            end
        end
    end
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
            appraisal = dataCopy(option.appraisal), consequences = dataCopy(option.consequences) }
        if failure then candidate.evidence = math.max(0, candidate.evidence - math.min(0.4, failure.attempts * 0.1)) end
        if purpose.selectedStrategy == option.id and not failure then candidate.continuity = 1 end
        if option.kind == "build-rain-collector" and (purpose.collector and purpose.collector.constructedWorkId
            and purpose.collector.sourceId == option.sourceId or option.collectorUnavailable and executable) then
            option.retryDelayed = true
        elseif option.kind == "build-rain-collector" and option.materialBlocker == "known-route-retry-delayed" then
            option.retryDelayed, delayed = true, true
        elseif option.kind == "plumb-fixture" and option.toolDelayed then
            option.retryDelayed, delayed = true, true
        elseif option.kind == "plumb-fixture" and option.toolUnavailable and executable then
            option.retryDelayed = true
        elseif failure and finite(failure.retryAt) and at < failure.retryAt then
            option.retryDelayed, delayed = true, true
        else
            candidates[#candidates + 1] = candidate
        end
    end
    -- Both models share their existing sixteen-candidate contract. Preserve
    -- a private inspection route alongside the strongest known work routes.
    if #candidates > 16 then
        local scores = {}
        for _, candidate in ipairs(candidates) do
            scores[candidate.id] = SAO.Cognition and SAO.Cognition.scorePlan
                and SAO.Cognition.scorePlan(id, candidate, { domain = "provisioning",
                    category = assessment.category, pressure = assessment.demand.pressure, atHours = at })
        end
        local inspect
        for _, candidate in ipairs(candidates) do
            if string.sub(candidate.id, 1, 8) == "inspect:" then inspect = candidate; break end
        end
        table.sort(candidates, function(a, b)
            local aScore = SAO.CognitiveModels.planScore("ordinary", a, assessment.demand.pressure)
            local bScore = SAO.CognitiveModels.planScore("ordinary", b, assessment.demand.pressure)
            aScore, bScore = scores[a.id] or aScore or -math.huge,
                scores[b.id] or bScore or -math.huge
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
    local selected = views and views.selected
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
            if score and (not best or score > best) then
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
    if not option and not delayed and #candidates > 0 and not assessment.blocker then
        blockers[#blockers + 1] = "resource-interpretation-unavailable"
    end
    if option then
        if option.kind == "inspect" then
            steps[#steps + 1] = { id = option.id, verb = "inspect",
                owner = "SAO.WorldSources", token = "resource:inspected",
                target = option.place.sourceId, sourceId = option.place.sourceId, fingerprint = option.fingerprint,
                sourceX = option.sourceX, sourceY = option.sourceY, sourceZ = option.sourceZ,
                status = "available", category = assessment.category, place = dataCopy(option.place) }
        elseif option.kind == "build-rain-collector" then
            local source = option.materialSource
            if source then
                steps[#steps + 1] = { id = materialAcquisitionId(source), verb = "acquire", owner = "SAO.SourceUse",
                    token = "resource:acquired", target = source.sourceId .. ":" .. tostring(source.itemId),
                    status = "available", category = source.category, sourceId = source.sourceId,
                    sourceRevision = source.revision, place = dataCopy(source.place), itemId = source.itemId,
                    itemType = source.itemType, quantity = 1, quantityUnit = "item" }
            elseif option.materialBlocker then blockers[#blockers + 1] = option.materialBlocker end
            local step = collectorStep(option, #blockers > 0 and "blocked" or #steps > 0 and "dependent" or "available")
            steps[#steps + 1] = step
            purpose.collector = dataCopy(step)
        elseif option.kind == "plumb-fixture" then
            local source = option.toolSource
            local selected = plumbingStep(option, "available")
            if not plumbingTool(option) then
                if source then
                    steps[#steps + 1] = { id = materialAcquisitionId(source), verb = "acquire",
                        owner = "SAO.SourceUse", token = "resource:acquired",
                        target = source.sourceId .. ":" .. tostring(source.itemId), status = "available",
                        category = "pipe-wrench", sourceId = source.sourceId, sourceRevision = source.revision,
                        place = dataCopy(source.place), itemId = source.itemId, itemType = source.itemType,
                        quantity = 1, quantityUnit = "item" }
                    selected.toolItemId, selected.toolItemType = tostring(source.itemId), source.itemType
                else blockers[#blockers + 1] = "missing-private-usable-pipe-wrench" end
            end
            local step = plumbingStep(selected, #blockers > 0 and "blocked" or #steps > 0 and "dependent" or "available")
            steps[#steps + 1] = step
            purpose.plumbing = dataCopy(step)
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
    local retained, included = {}, {}
    -- Keep every considered alternative visible before diagnostic rows for
    -- delayed or pruned work; report the remainder explicitly.
    for _, candidate in ipairs(candidates) do
        for _, offered in ipairs(assessment.options) do
            if offered.id == candidate.id and not included[offered.id] then
                retained[#retained + 1] = offered; included[offered.id] = true; break
            end
        end
    end
    for _, offered in ipairs(assessment.options) do
        if #retained >= 32 then break end
        if not included[offered.id] then
            retained[#retained + 1] = offered; included[offered.id] = true
        end
    end
    purpose.alternatives = dataCopy(retained)
    purpose.omittedAlternatives = #assessment.options - #retained
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

materialAcquisitionId = function(source)
    return "acquire:" .. source.category .. ":" .. tostring(source.sourceId)
        .. ":" .. tostring(source.revision) .. ":" .. tostring(source.itemId)
end

materialSource = function(purpose, sources, category, at)
    local best, bestDistance, delayed
    for index, source in ipairs(type(sources) == "table" and sources or {}) do
        if index > 128 then break end
        if type(source) == "table" and source.known == true and source.category == category
            and type(source.sourceId) == "string" and source.sourceId ~= ""
            and source.revision ~= nil and (type(source.revision) == "string" or finite(source.revision))
            and (type(source.itemId) == "string" or finite(source.itemId))
            and type(source.itemType) == "string" and source.itemType ~= ""
            and type(source.place) == "table"
            and (category ~= "glass-pane" or source.itemType == "RepairableWindows.LargeGlassPane")
            and (category ~= "nails" or source.itemType == "Base.Nails")
            and (category ~= "log" or source.itemType == "Base.Log") then
            local stepId, used, retry = materialAcquisitionId(source), false, false
            for _, ledger in ipairs({ purpose.steps or {}, purpose.completedSteps or {} }) do
                for _, old in ipairs(ledger) do
                    if old.id == stepId and old.status == "completed" then used = true; break end
                end
            end
            for _, failure in ipairs(purpose.routeFailures or {}) do
                if failure.stepId == stepId and finite(failure.retryAt) and at < failure.retryAt then retry = true end
            end
            local distance = finite(source.distance) and math.max(0, source.distance) or math.huge
            if not used and not retry and (not best or distance < bestDistance) then
                best, bestDistance = source, distance
            elseif not used and retry then delayed = true end
        end
    end
    return best, delayed
end

local GeneratorPlanning = {}
GeneratorPlanning.tokens = { inspect = "utility:generator-inspected", repair = "utility:generator-repaired",
    fuel = "utility:generator-fuelled", connect = "utility:generator-connected",
    activate = "utility:generator-activated", ["verify-power"] = "utility:consumer-powered",
    ["learn-generator"] = "utility:generator-known" }
function GeneratorPlanning.anchor(value, prefix)
    if type(value) ~= "table" then return nil end
    local sourceId = value.sourceId or value.id
    if type(sourceId) ~= "string" or sourceId:sub(1,2) ~= prefix or type(value.fingerprint) ~= "string"
        or value.fingerprint == "" or type(value.revision) ~= "string" or value.revision == ""
        or not finite(value.x) or not finite(value.y) or not finite(value.z) then return nil end
    local out = dataCopy(value)
    out.sourceId = sourceId
    return out
end
function GeneratorPlanning.same(a, b, revision)
    return a and b and (a.sourceId or a.id) == (b.sourceId or b.id)
        and a.fingerprint == b.fingerprint and a.x == b.x and a.y == b.y and a.z == b.z
        and (not revision or a.revision == b.revision)
end
function GeneratorPlanning.step(option, status)
    local reading = option.materialCategory == "generator-manual"
    local operation = reading and "learn-generator" or option.operation
    return { id = "generator:" .. option.generator.sourceId .. ":" .. option.generator.revision
            .. ":" .. option.consumer.sourceId .. ":" .. option.consumer.revision .. ":" .. operation
            .. ":" .. tostring(option.inputItemId or "no-input"),
        verb = reading and "read" or "produce", owner = reading and "SAO.Study" or "SAO.Generator",
        token = GeneratorPlanning.tokens[operation], target = option.generator.sourceId,
        operation = operation, productionKind = "generator-operation", status = status,
        generator = dataCopy(option.generator), consumer = dataCopy(option.consumer),
        inputItemId = option.inputItemId and tostring(option.inputItemId), inputItemType = option.inputItemType,
        materialCategory = option.materialCategory, requestingPurposeId = option.requestingPurposeId,
        requestingActivity = option.requestingActivity, foodItemId = option.foodItemId,
        foodItemType = option.foodItemType, applianceSourceId = option.applianceSourceId }
end
function P.generatorPurpose(id)
    local s, selected, priority = state(id)
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        if purpose and purpose.generatorPower and purpose.status ~= "completed" and purpose.status ~= "abandoned" then
            local step = purpose.steps[purpose.cursor]
            local rank = purpose.admission and 1 or step and step.status == "available" and 2 or 3
            if not selected or rank < priority then selected, priority = purpose, rank end
        end
    end
    return selected, selected and selected.steps[selected.cursor]
end
function P.planGenerator(id, context)
    context = type(context) == "table" and context or {}
    local s = state(id, true)
    if not s then return nil, "person-unavailable" end
    local intent = type(context.intent) == "table" and context.intent or {}
    local consumer = GeneratorPlanning.anchor(intent.consumer, "E:")
    if not consumer then return nil, "private-consumer-unavailable" end
    local purpose = purposeByKey(s, "utility:power:" .. consumer.sourceId)
    local current = purpose and purpose.steps[purpose.cursor]
    if purpose and purpose.admission then return purpose, current end
    if purpose and not GeneratorPlanning.same(purpose.generatorPower.consumer, consumer, false) then
        purpose.status, purpose.resolution = "abandoned", "consumer-replaced"
        purpose = nil
    end
    local assessment = SAO.Labor and SAO.Labor.assessUtility and SAO.Labor.assessUtility(id, context)
    if not assessment then return purpose, current end
    local at = finite(context.atHours) and context.atHours or nowHours()
    purpose = purpose or P.maintain(id, { key = "utility:power:" .. consumer.sourceId,
        objective = "restore usable power for " .. tostring(intent.requestingActivity or "the intended consumer"),
        domain = "utilities", origin = "private-consumer-intent", atHours = at })
    if not purpose then return nil, "person-unavailable" end
    purpose.generatorPower = purpose.generatorPower or { consumer = consumer,
        requestingPurposeId = intent.requestingPurposeId, requestingActivity = intent.requestingActivity,
        foodItemId = intent.foodItemId, foodItemType = intent.foodItemType, applianceSourceId = intent.applianceSourceId }
    purpose.generatorPower.consumer = consumer
    for _, field in ipairs({ "requestingPurposeId", "requestingActivity", "foodItemId", "foodItemType", "applianceSourceId" }) do
        purpose.generatorPower[field] = dataCopy(intent[field])
    end
    if purpose.awaitingReassessment then
        for _, prior in ipairs(purpose.steps or {}) do
            if prior.status == "completed" then
                purpose.completedSteps = purpose.completedSteps or {}
                purpose.completedSteps[#purpose.completedSteps+1] = dataCopy(prior)
                if #purpose.completedSteps > 16 then table.remove(purpose.completedSteps,1) end
            end
        end
        purpose.steps, purpose.cursor, purpose.awaitingReassessment = {}, 1, nil
    end
    local candidates, offered, executable = {}, {}, false
    for _, option in ipairs(assessment.options or {}) do
        local source, delayed
        if option.materialCategory and not option.inputItemId then
            source, delayed = materialSource(purpose, assessment.sources, option.materialCategory, at)
        end
        option.source, option.delayed = source, delayed
        option.executable = option.blocked ~= true and (not option.materialCategory or option.inputItemId ~= nil or source ~= nil)
        for _, failure in ipairs(purpose.routeFailures or {}) do
            if failure.stepId == GeneratorPlanning.step(option, "available").id
                and finite(failure.retryAt) and at < failure.retryAt then option.executable, option.delayed = false, true end
        end
        if option.executable and not delayed then executable = true end
        offered[option.id] = option
    end
    for _, option in ipairs(assessment.options or {}) do
        if (not executable or option.executable) and not option.delayed then
            candidates[#candidates+1] = { id = option.id, evidence = option.evidence, continuity = option.continuity,
                novelty = option.novelty, informationGain = option.informationGain,
                blockers = option.executable and 0 or 1, appraisal = dataCopy(option.appraisal),
                consequences = dataCopy(option.consequences) }
        end
    end
    local views = #candidates > 0 and interpretations(id, candidates, { domain = "utilities",
        pressure = assessment.pressure, actorId = id, atHours = at }) or nil
    local selected = views and offered[views.selected]
    if not selected then
        local best
        for _, candidate in ipairs(candidates) do
            local score = SAO.CognitiveModels and SAO.CognitiveModels.planScore("ordinary", candidate, assessment.pressure)
            if score and (not best or score > best) then best, selected = score, offered[candidate.id] end
        end
    end
    local steps, blockers = {}, {}
    if selected then
        local source = selected.source
        local option = dataCopy(selected)
        if source then
            steps[1] = { id = materialAcquisitionId(source), verb = "acquire", owner = "SAO.SourceUse",
                token = "resource:acquired", target = source.sourceId .. ":" .. tostring(source.itemId),
                status = "available", category = source.category, sourceId = source.sourceId,
                sourceRevision = source.revision, itemId = source.itemId, itemType = source.itemType,
                place = dataCopy(source.place), quantity = 1, quantityUnit = "item" }
            option.inputItemId, option.inputItemType = tostring(source.itemId), source.itemType
        elseif not selected.executable then blockers[1] = selected.reason or "missing-private-generator-means" end
        steps[#steps+1] = GeneratorPlanning.step(option, #blockers > 0 and "blocked" or #steps > 0 and "dependent" or "available")
        purpose.generatorPower.generator = dataCopy(selected.generator)
    else blockers[1] = "private-generator-option-unavailable" end
    setPlan(purpose, steps, blockers, views, at)
    purpose.selectedStrategy, purpose.alternatives = selected and selected.id, dataCopy(assessment.options)
    purpose.labor, purpose.appraisal, purpose.updatedAt = dataCopy(assessment.dimensions), selected and dataCopy(selected.appraisal), at
    return purpose, purpose.steps[purpose.cursor]
end
function P.deferGenerator(id, purposeId, stepId, reason)
    local s = state(id)
    local purpose = s and s.purposes[purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.generatorPower or purpose.admission or not step or step.id ~= stepId then return false end
    resourceFailure(purpose, purpose.selectedStrategy, reason, nowHours(), step.id)
    step.status, purpose.status = "blocked", "blocked"
    purpose.blockers = { "generator-route-retry-delayed" }
    return true
end
function GeneratorPlanning.attempt(id, work, reading)
    if type(work) ~= "table" or work.actorId ~= id or type(work.id) ~= "string" then return nil end
    local s = state(id)
    local purpose = s and s.purposes[work.requestedPurposeId or work.purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.generatorPower or purpose.status == "completed" or purpose.status == "abandoned"
        or not step or step.id ~= (work.requestedPurposeStepId or work.purposeStepId)
        or step.owner ~= (reading and "SAO.Study" or "SAO.Generator")
        or step.token ~= GeneratorPlanning.tokens[reading and "learn-generator" or work.operation] then return nil end
    if reading then
        if step.operation ~= "learn-generator" or tostring(work.itemId) ~= step.inputItemId
            or work.itemType ~= step.inputItemType then return nil end
    elseif work.operation ~= step.operation or not GeneratorPlanning.same(step.generator, work.generator, true)
        or not GeneratorPlanning.same(step.consumer, work.consumer, true)
        or (work.inputItemId ~= nil and tostring(work.inputItemId) or nil) ~= step.inputItemId
        or work.inputItemType ~= step.inputItemType or work.materialCategory ~= step.materialCategory then return nil end
    return purpose, step
end
function P.admitGenerator(id, work)
    local purpose, step = GeneratorPlanning.attempt(id, work, false)
    if not purpose or step.status ~= "available" or purpose.admission then return false end
    local accepted = P.noteAdmission(id, purpose.id, step.owner, work.id, step.id)
    if accepted then work.purposeId, work.purposeStepId = purpose.id, step.id end
    return accepted
end
function P.admitGeneratorReading(id, work)
    local purpose, step = GeneratorPlanning.attempt(id, work, true)
    if not purpose or step.status ~= "available" or purpose.admission then return false end
    local accepted = P.noteAdmission(id, purpose.id, step.owner, work.id, step.id)
    if accepted then work.purposeId, work.purposeStepId = purpose.id, step.id end
    return accepted
end
function GeneratorPlanning.result(id, row, reading)
    local s = state(id)
    local retained = s and s.purposes[row.purposeId]
    local pending = retained and retained.admission
    if not retained or not retained.generatorPower or not pending or pending.correlationId ~= row.id then
        return true, "purpose-attempt-superseded"
    end
    local purpose, step = GeneratorPlanning.attempt(id, row, reading)
    if not purpose then return false end
    local admission = purpose.admission
    if not admission or admission.correlationId ~= row.id or admission.owner ~= step.owner
        or admission.stepId ~= step.id or admission.target ~= step.target then return true, "purpose-attempt-superseded" end
    if not finite(row.atHours) or not finite(row.startedAt) or row.startedAt > row.atHours
        or row.atHours < admission.at or row.atHours > nowHours() or row.endedAt ~= row.atHours
        or row.status ~= "completed" and row.status ~= "failed" and row.status ~= "interrupted" then return false end
    local completed = row.status == "completed"
    if completed then
        if reading then
            if row.nativeOwner ~= "ISReadABook.complete" or row.nativeStarted ~= true or row.nativeCompleted ~= true
                or not finite(row.progress) or row.progress <= 0 or row.recipeKnown ~= true then return false end
        else
            if (row.operation ~= "inspect" and row.operation ~= "verify-power" and row.nativeAttempted ~= true)
                or row.nativeCompleted ~= true or row.nativeCredit ~= row.id
                or type(row.nativeOwner) ~= "string" or row.nativeOwner == "" then return false end
            if row.operation == "inspect" and (not row.generatorAfter or row.generatorAfter.inspected ~= true) then return false end
            if row.operation == "repair" and (not finite(row.beforeCondition) or not finite(row.afterCondition)
                or row.afterCondition <= row.beforeCondition or row.inputConsumed ~= true) then return false end
            if row.operation == "fuel" and (not finite(row.beforeFuel) or not finite(row.afterFuel)
                or row.afterFuel <= row.beforeFuel or not finite(row.maxFuel) or row.afterFuel > row.maxFuel
                or not finite(row.beforeInputAmount) or not finite(row.afterInputAmount)
                or row.afterInputAmount >= row.beforeInputAmount or row.inputRetained ~= true) then return false end
            if row.operation == "connect" and (row.beforeConnected ~= false or row.afterConnected ~= true) then return false end
            if row.operation == "activate" and (row.beforeActive ~= false or row.afterActive ~= true or row.outside ~= true) then return false end
            if row.operation == "verify-power" and (row.sourceCovered ~= true or row.consumerPowered ~= true) then return false end
            if row.generatorAfter and not GeneratorPlanning.same(step.generator, row.generatorAfter, false) then return false end
            if row.consumerAfter and not GeneratorPlanning.same(step.consumer, row.consumerAfter, false) then return false end
        end
    end
    local accepted = P.recordResult(id, purpose.id, { owner = step.owner, token = step.token,
        status = row.status, correlationId = row.id, reason = row.detail, atHours = row.atHours },
        reading and GENERATOR_READING_RESULT or GENERATOR_RESULT)
    if accepted and not reading and row.status == "failed" and step.operation == "verify-power"
        and row.detail == "native-consumer-power-checked" and row.sourceCovered == false then
        local request = purpose.generatorPower
        request.rejectedGenerators = request.rejectedGenerators or {}
        request.rejectedGenerators[step.generator.sourceId] = step.generator.fingerprint
        local prior = {}
        for sourceId in pairs(request.rejectedGenerators) do
            if sourceId ~= step.generator.sourceId then prior[#prior+1] = sourceId end
        end
        table.sort(prior)
        for index = 1, #prior - 31 do request.rejectedGenerators[prior[index]] = nil end
        request.generator = nil
        purpose.status, purpose.awaitingReassessment = "maintained", true
    end
    if accepted and completed and step.operation ~= "verify-power" then
        purpose.status, purpose.awaitingReassessment = "maintained", true
        if row.generatorAfter then purpose.generatorPower.generator = GeneratorPlanning.anchor(row.generatorAfter, "J:") end
        if row.consumerAfter then purpose.generatorPower.consumer = GeneratorPlanning.anchor(row.consumerAfter, "E:") end
    end
    if accepted and completed and step.operation == "verify-power" and purpose.generatorPower.requestingActivity == "cooking" then
        local request = purpose.generatorPower
        local food = s.purposes[request.requestingPurposeId]
        local pendingFood = food and food.steps[food.cursor]
        if food and food.resourceCategory == "food" and not food.admission and food.status ~= "completed"
            and food.status ~= "abandoned" and pendingFood and pendingFood.owner == "Cooking"
            and tostring(pendingFood.acquiredItemId) == tostring(request.foodItemId) then
            local ready = pendingFood.status == "available" or pendingFood.status == "dependent"
            local unrelated = false
            for _, failure in ipairs(food.routeFailures or {}) do
                if failure.stepId == pendingFood.id and failure.reason == "appliance-unpowered" then
                    failure.retryAt, failure.resolvedByUtility = row.atHours, row.id
                    ready = true
                elseif failure.stepId == pendingFood.id and finite(failure.retryAt) and failure.retryAt > row.atHours then
                    unrelated = true
                end
            end
            if ready and not unrelated then
                food.status, pendingFood.status, food.blockers = "maintained", "available", {}
                record(id).poweredMealReady = {purposeId=food.id,purposeStepId=pendingFood.id,
                    foodItemId=request.foodItemId,foodItemType=request.foodItemType,applianceSourceId=request.applianceSourceId,
                    utilityWorkId=row.id,consumerId=request.consumer.sourceId,consumer=dataCopy(request.consumer)}
            end
        end
    end
    return accepted
end
function P.poweredMeal(id)
    local rec, s = record(id), state(id)
    local pending = rec and rec.poweredMealReady
    local purpose = pending and s and s.purposes[pending.purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or purpose.status == "completed" or purpose.status == "abandoned" or purpose.admission
        or not step or step.id ~= pending.purposeStepId or step.owner ~= "Cooking"
        or tostring(step.acquiredItemId) ~= tostring(pending.foodItemId) then return nil end
    return dataCopy(pending)
end
function P.consumeGeneratorOutcome(id, sequence)
    local owner = SAO.Generator
    local row = owner and owner.outcome and owner.outcome(id, sequence)
    if not row or row.actorId ~= id or row.sequence ~= sequence or row.id ~= "generator/" .. id .. "/" .. tostring(sequence)
        or row.workId ~= row.id or row.token ~= GeneratorPlanning.tokens[row.operation] then return false end
    return GeneratorPlanning.result(id, row, false)
end
function P.consumeGeneratorReading(id, outcomeId)
    local owner = SAO.Study
    local row = owner and owner.generatorOutcome and owner.generatorOutcome(id, outcomeId)
    if not row or row.actorId ~= id or row.id ~= outcomeId or row.workId ~= row.id
        or row.outcomeId ~= row.id then return false end
    return GeneratorPlanning.result(id, row, true)
end

local function repairPolicy(recipeId)
    local owner = SAO.ResourceProduction
    local ok, policy
    if owner and owner.repairPolicy then ok, policy = pcall(owner.repairPolicy, recipeId)
    elseif recipeId == "Base.FixSaw" then
        ok, policy = true, { recipeId = recipeId, category = "saw", toolCategory = "file", effectMetric = "condition" }
    end
    if ok and type(policy) == "table" and policy.recipeId == recipeId
        and (policy.category == "saw" or policy.category == "blade" or policy.category == "weapon")
        and (policy.toolCategory == "file" or policy.toolCategory == "whetstone" or policy.toolCategory == "weapons")
        and (policy.effectMetric == "condition" or policy.effectMetric == "sharpness") then return policy end
end

local function repairMeasure(option, policy)
    local before, maximum = option.condition, option.maxCondition
    if policy.effectMetric == "sharpness" then before, maximum = option.sharpness, option.maxSharpness end
    if not finite(before) or not finite(maximum) or before < 0 or maximum <= before
        or policy.effectMetric == "condition" and before <= 0 then return nil end
    return before, maximum
end

local function repairStep(option, policy, status)
    local before = repairMeasure(option, policy)
    return { id = "repair-held:" .. policy.recipeId .. ":" .. option.targetItemId
            .. ":" .. policy.effectMetric .. ":" .. tostring(before),
        verb = "produce", owner = "SAO.ResourceProduction", token = "resource:repaired",
        target = policy.recipeId, recipeId = policy.recipeId, productionKind = policy.productionKind or "repair-held-item",
        category = policy.category, toolCategory = policy.toolCategory, effectMetric = policy.effectMetric,
        targetItemId = option.targetItemId, targetItemType = option.targetItemType,
        toolItemId = option.toolItemId, toolItemType = option.toolItemType, status = status }
end

function P.maintenancePurpose(id)
    local s, selected, priority = state(id)
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        if purpose and purpose.materialWork and purpose.materialWork.operation == "maintain-tool"
            and purpose.status ~= "completed" and purpose.status ~= "abandoned" then
            local step = purpose.steps[purpose.cursor]
            local rank = purpose.admission and 1 or step and step.status == "available" and 2 or 3
            if not selected or rank < priority then selected, priority = purpose, rank end
        end
    end
    return selected, selected and selected.steps[selected.cursor]
end


function P.bedPurpose(id)
    local s=state(id)
    for _,key in ipairs(s and s.order or {}) do local p=s.purposes[key]
        if p and p.bedConstruction and p.status~="completed" and p.status~="abandoned" then return p,p.steps[p.cursor] end
    end
end
function P.bedReady(option)
    return P.collectorReady(option)
end
local function bedStep(option,status)
    return {id="bed:"..option.site.key..":"..option.site.revision,verb="produce",owner="SAO.ResourceProduction",
        token="resource:bed-built",target="Base.Wood_Bed",productionKind="build-wood-bed",category="construction",
        entityId=option.entityId,recipeId=option.recipeId,site=dataCopy(option.site),
        requirements=dataCopy(option.requirements),inputs=dataCopy(option.inputs),status=status}
end
function P.planBedConstruction(id,context)
    context=type(context)=="table" and context or {};local s=state(id,true)
    if not s or context.recoveryKind~="sleep" or not finite(context.fatigue) or context.fatigue<0 or context.fatigue>1 then return nil end
    local retained,current=P.bedPurpose(id)
    if retained and (retained.admission or retained.bedConstruction.constructedWorkId) then return retained,current end
    local at=finite(context.atHours) and context.atHours or nowHours()
    local candidates={{id="continue",evidence=1,continuity=.7,novelty=0,informationGain=0,utility=.25,blockers=0}}
    local offered={}
    for i,option in ipairs(type(context.options)=="table" and context.options or {}) do
        if i>15 then break end
        local ready,missing=P.bedReady(option)
        if type(option)=="table" and option.entityId=="Base.Wood_Bed" and option.kind=="build-wood-bed"
            and option.known==true and type(option.site)=="table" and option.site.actorId==id and option.site.observed==true
            and finite(option.site.observedAtHours) and option.site.observedAtHours<=at and missing then
            local source,delayed
            if not ready then source,delayed=materialSource(retained or {},context.materialSources,missing[1].category,at) end
            local key="bed-option:"..i
            candidates[#candidates+1]={id=key,evidence=1,continuity=retained and 1 or .7,novelty=.1,informationGain=.2,
                utility=.8+context.fatigue-.1*math.min(1,(tonumber(option.distance) or 100)/100),
                blockers=(not ready and not source or delayed) and 1 or 0,
                consequences={{kind="construct",category="construction",sourceId=option.site.key,itemType="Base.Wood_Bed",value=.5}}}
            offered[key]={option=option,source=source,ready=ready,delayed=delayed}
        end
    end
    local view=interpretations(id,candidates,{domain="construction",pressure=context.fatigue,atHours=at})
    local selected=view and offered[view.selected]
    if not selected then return retained,nil,"bed-means-unavailable" end
    local p=retained or P.maintain(id,{key="sleep-with-built-bed",domain="body",objective="sleep using a bed made from personally known means",origin="recovery-concern",atHours=at})
    if not p then return nil end
    local steps,blockers={},{}
    if not selected.ready then
        if selected.source and not selected.delayed then local source=selected.source
            steps[#steps+1]={id=materialAcquisitionId(source),verb="acquire",owner="SAO.SourceUse",token="resource:acquired",
                target=source.sourceId..":"..tostring(source.itemId),category=source.category,sourceId=source.sourceId,
                sourceRevision=source.revision,itemId=source.itemId,itemType=source.itemType,place=dataCopy(source.place),
                quantity=1,quantityUnit="item",status="available"}
        else blockers[#blockers+1]=selected.delayed and "known-route-retry-delayed" or "missing-private-bed-material" end
    end
    local step=bedStep(selected.option,#blockers>0 and "blocked" or #steps>0 and "dependent" or "available")
    steps[#steps+1]=step
    steps[#steps+1]={id="sleep-in-created-bed",verb="recover",owner="SAONeeds",token="recovery:measured",
        target=step.site.key,status="dependent"}
    p.materialWork={operation="build-bed",entryKey=step.site.key}
    p.bedConstruction={recoveryKind="sleep",site=dataCopy(step.site),entityId=step.entityId,recipeId=step.recipeId}
    setPlan(p,steps,blockers,dataCopy(view),at);p.selectedStrategy=steps[1].id
    return p,p.steps[p.cursor]
end
function P.admitBedConstruction(id,w)
    local p,step=P.bedPurpose(id)
    if type(w)~="table" or w.actorId~=id or w.kind~="build-wood-bed" or not p or p.admission
        or p.id~=w.purposeId or not step or step.status~="available" or step.owner~="SAO.ResourceProduction"
        or step.productionKind~=w.kind or step.id~=w.purposeStepId or step.recipeId~=w.recipeId or step.site.key~=w.siteKey
        or step.site.revision~=w.siteRevision or step.site.face~=w.face or not P.bedReady(step) then return false end
    return P.noteAdmission(id,p.id,step.owner,w.id,step.id)
end
function P.consumeBedConstructionResult(id,supplied)
    local canonical=type(supplied)=="table" and SAO.ResourceProduction.outcome(id,supplied.id)
    if not canonical or canonical.actorId~=id or canonical.kind~="build-wood-bed" or canonical.token~="resource:bed-built"
        or canonical.nativeOwner~="ISBuildAction" or not finite(canonical.atHours) or canonical.atHours>nowHours() then return false end
    local s=state(id);local p=s and s.purposes[canonical.purposeId]
    if not p or p.status=="abandoned" then return true end
    for _,key in ipairs(p.resultReceipts or {}) do if key=="SAO.ResourceProduction:"..canonical.id then return true end end
    local step,a=p.steps[p.cursor],p.admission
    if not p.bedConstruction or not step or not a or step.owner~="SAO.ResourceProduction" or step.token~=canonical.token
        or step.id~=canonical.purposeStepId or a.stepId~=step.id or a.correlationId~=canonical.id or a.owner~=step.owner
        or a.target~=step.target or canonical.atHours<a.at or step.site.key~=canonical.siteKey
        or step.site.revision~=canonical.siteRevision or step.site.face~=canonical.face or step.recipeId~=canonical.recipeId
        or not P.bedReady(step) or not P.bedReady(canonical) then return false end
    local accepted=P.recordResult(id,p.id,{owner="SAO.ResourceProduction",token="resource:bed-built",status=canonical.status,
        correlationId=canonical.id,reason=canonical.detail,atHours=canonical.atHours},BED_RESULT)
    if accepted and canonical.status=="completed" then
        p.bedConstruction.constructedWorkId,p.bedConstruction.constructedAt=canonical.id,canonical.atHours
        p.bedConstruction.bedKey=canonical.bedKey
        local recovery=p.steps[p.cursor]
        if recovery and recovery.owner=="SAONeeds" and recovery.token=="recovery:measured" then recovery.status="available" end
        p.status="maintained";p.blockers={"awaiting-measured-bed-recovery"}
    end
    return accepted
end
function P.reconcileBedRecovery(id,body)
    local p,step=P.bedPurpose(id);local a=p and p.admission;local rec=record(id)
    if not a or a.owner~="SAONeeds" then return true end
    local b=p.bedConstruction
    if not b or not b.constructedWorkId or not step or step.owner~="SAONeeds" or step.token~="recovery:measured"
        or a.stepId~=step.id or a.correlationId~="bed-recovery:"..p.id or not finite(a.at) or a.at>nowHours()
        or not rec or not body or SAO.Body.get(id)~=body or not SAO.Needs.ownsRecoveryBody(id,body) then return false end
    local ok,quiet=pcall(function()
        return rec.recoveryIntent==nil and not SAO.Needs.recoveryActive(id,body) and not SAOJavaBridge:hasPendingActions(body)
            and body:getCurrentStateName()=="IdleState" and not body:isAsleep() and not body:isOnBed() and not body:isResting()
            and not (SAO.RecoveryPose and SAO.RecoveryPose.pendingExits and SAO.RecoveryPose.pendingExits[body])
    end)
    if not ok or not quiet then return false end
    p.lastAdmission=dataCopy(a);p.admission=nil;step.status="available";p.status="maintained"
    b.recoverySequenceBefore=nil;p.blockers={"recovery-interrupted-awaiting-retry"}
    addEvent(p,"bed-recovery-interrupted","native pose and queue retired without completed sleep",nowHours())
    return true
end
function P.admitBedRecovery(id,kind,place)
    local p,step=P.bedPurpose(id);local rec=record(id);local b=p and p.bedConstruction
    if not b or not b.constructedWorkId or kind~="sleep" or not step or step.owner~="SAONeeds" or step.token~="recovery:measured"
        or p.admission or type(place)~="table" or place.kind~="bed" or place.available~=true
        or place.objectX~=b.site.x or place.objectY~=b.site.y or place.objectZ~=b.site.z
        or not rec.recoveryIntent or rec.recoveryIntent.kind~=kind or rec.recoveryIntent.place.key~=place.key then return false end
    b.bedKey=place.key
    b.recoverySequenceBefore=rec.recoveryExperienceSequence or 0
    return P.noteAdmission(id,p.id,"SAONeeds","bed-recovery:"..p.id,step.id)
end
function P.consumeBedRecovery(id,sequence)
    local canonical=SAO.Needs.behaviorOutcome(id,sequence);local p,step=P.bedPurpose(id);local b=p and p.bedConstruction
    local a=p and p.admission
    if not canonical or not b or not a or not step or step.owner~="SAONeeds" or a.owner~="SAONeeds"
        or a.stepId~=step.id or canonical.actorId~=id or canonical.kind~="recovery-outcome" or canonical.actionKind~="sleep"
        or canonical.sourceId~=b.bedKey or sequence<=b.recoverySequenceBefore or canonical.atHours<a.at
        or canonical.atHours>nowHours() or not finite(canonical.durationHours) or canonical.durationHours<=0
        or canonical.succeeded~=true or not finite(canonical.beforeValue) or not finite(canonical.afterValue)
        or canonical.afterValue>=canonical.beforeValue then return false end
    return P.recordResult(id,p.id,{owner="SAONeeds",token="recovery:measured",status="completed",
        correlationId=a.correlationId,atHours=canonical.atHours,reason="native-created-bed-fatigue-reduction"},BED_RECOVERY_RESULT)
end

local SHELTER_RESULT,SHELTER_USE_RESULT,SHELTER_RECOVERY_RESULT={},{},{}
function P.shelterPurpose(id)
    local s=state(id)
    for _,key in ipairs(s and s.order or {}) do local p=s.purposes[key]
        if p and p.shelterConstruction and p.status~="completed" and p.status~="abandoned" then return p,p.steps[p.cursor] end
    end
end
local function shelterSurfaceNeeded(own,site)
    if not own then return true end
    if site.z==own.origin.z then return true end
    for _,need in ipairs(own.coverNeeds or {}) do
        if need.x==site.x and need.y==site.y and need.z+1==site.z
            and not (own.completedSurfaces and own.completedSurfaces[site.key]) then return true end
    end
    return false
end
local function shelterMovementPlan(p,verb,target,x,y,z,at)
    local step={id="shelter-"..verb..":"..target,verb=verb,owner="SAO.Controller",token="shelter:movement-observed",
        target=target,x=x,y=y,z=z,status="available"}
    setPlan(p,{step},{},nil,at);p.status="maintained";return p,p.steps[p.cursor]
end
function P.finishShelterMovement(id,body,purposeId,routeId,job)
    local s=state(id);local p=s and s.purposes[purposeId];local ad=p and p.admission;local step=p and p.steps[p.cursor]
    if not p or not p.shelterConstruction or not ad or ad.owner~="SAO.Controller" or ad.correlationId~=routeId
        or not step or ad.stepId~=step.id or step.owner~="SAO.Controller" or not job or job.body~=body or not job.done
        or SAO.Body.get(id)~=body or SAO.Locomotion.jobs[id]~=job or not job.goal
        or job.goal.x~=step.x or job.goal.y~=step.y or job.goal.z~=step.z then return false end
    local arrived=job.result=="arrived" and math.floor(body:getZ())==step.z
        and (body:getX()-step.x)^2+(body:getY()-step.y)^2<=.35^2
    P.reconcileShelterFeedback(id)
    p.lastAdmission=dataCopy(ad);p.admission=nil;p.status="maintained";step.status=arrived and "completed" or "available"
    local own=p.shelterConstruction;own.accessAttempts=own.accessAttempts or {}
    own.accessAttempts[step.target]={at=nowHours(),arrived=arrived,retryAt=arrived and nowHours() or nowHours()+.25}
    if arrived then
        SAO.Perception.observeShelterSurfaces(id,body)
        SAO.Perception.observeShelterSites(id,body,own.origin)
        p.blockers={"awaiting-current-surface-and-cover-observation"}
    else p.blockers={"native-shelter-access-unavailable"} end
    if arrived then
        local sequence=(s.shelterMovementSequence or 0)+1;s.shelterMovementSequence=sequence
        local row={id="shelter-movement/"..id.."/"..sequence,actorId=id,sequence=sequence,purposeId=p.id,
            routeId=routeId,sourceId=step.target,actionKind=step.verb,succeeded=true,atHours=nowHours()}
        s.shelterMovementResults=s.shelterMovementResults or {};s.shelterMovementResults[#s.shelterMovementResults+1]=row
        P.reconcileShelterFeedback(id)
    end
    addEvent(p,"shelter-movement-ended",job.result,nowHours());return true
end
function P.shelterMovementOutcome(id,sequence)
    local s=state(id)
    for _,row in ipairs(s and s.shelterMovementResults or {}) do
        if row.sequence==sequence and row.actorId==id and row.id=="shelter-movement/"..id.."/"..sequence
            and row.succeeded==true and (row.actionKind=="inspect" or row.actionKind=="return")
            and finite(row.atHours) and row.atHours<=nowHours() then return dataCopy(row) end
    end
end
function P.reconcileShelterFeedback(id)
    local s=state(id);if not s then return true end
    for _,row in ipairs(s.shelterMovementResults or {}) do
        if not row.experienceDelivered then
            local ok,accepted=pcall(function()return SAO.Cognition and SAO.Cognition.shelterMovementOutcome(id,dataCopy(row))end)
            if not ok or accepted~=true then return false end
            row.experienceDelivered=true
        end
    end
    -- Acknowledged history stays bounded; pending receipts never own physical arrival.
    local rows=s.shelterMovementResults or {};local index=1
    while #rows>32 and index<=#rows do
        if rows[index].experienceDelivered then table.remove(rows,index) else index=index+1 end
    end
    return true
end
function P.reconcileShelterMovement(id,body)
    P.reconcileShelterFeedback(id)
    local p,step=P.shelterPurpose(id);local ad=p and p.admission
    if not ad or ad.owner~="SAO.Controller" then return true end
    local agent=SAO.Controller and SAO.Controller.agents[id]
    if agent and agent.shelterRoute and agent.shelterRoute.routeId==ad.correlationId then return true end
    if SAO.Body.get(id)~=body or not step or step.owner~="SAO.Controller" then return false end
    local job=SAO.Locomotion.jobs[id]
    if job and not job.done then
        if job.body~=body or job.shelterPurposeId~=p.id or job.shelterStepId~=step.id then return false end
        local ok,cancelled=pcall(function()return SAOJavaBridge:cancelMove(body)end)
        if not ok or cancelled~="MOVE_CANCELLED" then return false end
        SAO.Locomotion.cancel(id);return false
    end
    local ok,quiet=pcall(function()return body:getCurrentStateName()=="IdleState" and not body:isClimbing()
        and not SAOJavaBridge:hasPendingActions(body)end)
    if not ok or not quiet then return false end
    p.lastAdmission=dataCopy(ad);p.admission=nil;step.status="available";p.status="maintained"
    p.blockers={"saved-shelter-access-requires-current-observation"};return true
end
function P.refreshShelterCover(id,body)
    local p=P.shelterPurpose(id);local own=p and p.shelterConstruction
    if not own or not body or SAO.Body.get(id)~=body or math.floor(body:getZ())~=own.origin.z then return false end
    local at=nowHours();local unresolved={}
    for _,need in ipairs(own.coverNeeds or {}) do unresolved[need.x..":"..need.y..":"..need.z]=need end
    for _,need in ipairs(SAO.Perception.shelterCoverNeeds(id)) do
        if need.actorId==id and need.source=="native-personal-visibility" and need.z==own.origin.z
            and finite(need.observedAtHours) and need.observedAtHours<=at then unresolved[need.x..":"..need.y..":"..need.z]=dataCopy(need) end
    end
    for _,seen in ipairs(SAO.Perception.shelterCoverObservations(id)) do
        if seen.actorId==id and seen.source=="native-personal-visibility" and seen.roof==true and seen.z==own.origin.z
            and finite(seen.observedAtHours) and seen.observedAtHours==at then unresolved[seen.x..":"..seen.y..":"..seen.z]=nil end
    end
    local ok,cover=pcall(function()return SAOJavaBridge:worldShelterCover(body,own.origin.originX,own.origin.originY,own.origin.z)end)
    if ok and type(cover)=="table" and cover.reached==true and cover.roof==true and cover.regionKnown==true
        and cover.enclosed==true and cover.fullyRoofed==true then unresolved={} end
    own.coverNeeds={};local keys={} for key in pairs(unresolved) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do own.coverNeeds[#own.coverNeeds+1]=unresolved[key] end
    return true
end
function P.planShelterConstruction(id,context)
    context=type(context)=="table" and context or {};local s=state(id,true)
    if not s or context.recoveryKind~="sleep" and context.recoveryKind~="rest"
        or not finite(context.fatigue) or context.fatigue<0 or context.fatigue>1 then return nil end
    local retained,current=P.shelterPurpose(id)
    if retained and (retained.admission or retained.shelterConstruction.usedWorkId) then return retained,current end
    local at=finite(context.atHours) and context.atHours or nowHours()
    if not retained and #(context.coverNeeds or {})>0 and type(context.position)=="table" then
        retained=P.maintain(id,{key="recover-in-repaired-shelter",domain="body",objective="use personally known repaired shelter for bodily recovery",origin="recovery-concern",atHours=at})
        if retained then retained.shelterConstruction={recoveryKind=context.recoveryKind,
            origin={originX=math.floor(context.position.x),originY=math.floor(context.position.y),z=math.floor(context.position.z)},
            stageHistory={},completedEdges={},completedSurfaces={},constructionResults={},coverNeeds=dataCopy(context.coverNeeds)} end
    end
    local own=retained and retained.shelterConstruction
    P.refreshShelterCover(id,SAO.Body.get(id))
    local candidates={{id="continue",evidence=1,continuity=.7,novelty=0,informationGain=0,utility=.25,blockers=0}}
    local offered,ranked={},{}
    for i,option in ipairs(context.options or {}) do
        if i>32 then break end
        local ready,missing=P.collectorReady(option);local site=option.site;local own=retained and retained.shelterConstruction
        if (option.kind=="build-shelter-edge" or option.kind=="build-shelter-surface" or option.kind=="build-shelter-stairs") and option.known==true and site and site.actorId==id and site.observed==true
            and (site.roof==true or option.kind=="build-shelter-surface" and site.supported==true and site.missingFloor==true
                or option.kind=="build-shelter-stairs" and site.mode=="stairs" and site.supported==true and site.landingObserved==false)
            and finite(site.observedAtHours) and site.observedAtHours<=at and missing
            and (not own or own.origin.originX==site.originX and own.origin.originY==site.originY and own.origin.z==(site.originZ or site.z))
            and (option.kind~="build-shelter-surface" or shelterSurfaceNeeded(own,site))
            and (option.kind~="build-shelter-stairs" or own and #(own.coverNeeds or {})>0 and site.z==own.origin.z)
            and (option.kind~="build-shelter-edge" or not own or #(own.coverNeeds or {})==0)
            and (not own or not own.stageHistory[site.key] or own.stageHistory[site.key].entityId~=option.entityId) then
            local source,delayed
            if not ready then source,delayed=materialSource(retained or {},context.materialSources,missing[1].category,at) end
            ranked[#ranked+1]={option=option,source=source,ready=ready,delayed=delayed,
                actionable=ready or source~=nil and not delayed,index=i}
        end
    end
    table.sort(ranked,function(a,b)
        if a.actionable~=b.actionable then return a.actionable end
        if a.ready~=b.ready then return a.ready end
        local da,db=tonumber(a.option.distance) or 100,tonumber(b.option.distance) or 100
        if da~=db then return da<db end
        return a.index<b.index
    end)
    local omitted=math.max(0,#ranked-15)
    for i,choice in ipairs(ranked) do
        if i>15 then break end
        local option=choice.option;local site=option.site;local key="shelter-option:"..i
        candidates[#candidates+1]={id=key,evidence=1,continuity=retained and 1 or .7,novelty=.1,informationGain=.2,
            utility=.9+context.fatigue-.1*math.min(1,(tonumber(option.distance) or 100)/100),
            blockers=choice.actionable and 0 or 1,
            consequences={{kind="construct",category="construction",sourceId=site.key,itemType=option.entityId,value=.5}}}
        offered[key]=choice
    end
    local view=interpretations(id,candidates,{domain="construction",pressure=context.fatigue,atHours=at})
    local selected=view and offered[view.selected]
    if not selected then
        if retained and context.position then
            local own=retained.shelterConstruction;local level=math.floor(context.position.z)
            if level~=own.origin.z then
                return shelterMovementPlan(retained,"return","original-use-level",own.origin.originX+.5,own.origin.originY+.5,own.origin.z,at)
            elseif #(own.coverNeeds or {})>0 then
                for _,access in ipairs(context.access or {}) do
                    local prior=own.accessAttempts and own.accessAttempts[access.key]
                    if access.actorId==id and access.basis=="visible-native-stair-top" and access.landingObserved==false
                        and access.z==own.origin.z and access.landingZ==own.origin.z+1 and finite(access.observedAtHours)
                        and access.observedAtHours<=at and (not prior or at>=prior.retryAt) then
                        return shelterMovementPlan(retained,"inspect",access.key,access.landingX+.5,access.landingY+.5,access.landingZ,at)
                    end
                end
                retained.blockers={"personally observed upper-level access unavailable"};return retained,nil,"shelter-access-unavailable"
            end
        end
        local missingObserved=#ranked>0
        local own=retained and retained.shelterConstruction
        for _,site in ipairs(context.sites or {}) do
            local history=own and own.stageHistory[site.key]
            if own and site.originX==own.origin.originX and site.originY==own.origin.originY and site.z==own.origin.z
                and site.mode~="door" and site.mode~="covered-interior" and (not history or history.revision~=site.revision) then missingObserved=true end
        end
        if retained and not missingObserved then
            local own=retained.shelterConstruction
            for _,site in ipairs(context.sites or {}) do
                if site.mode=="door" and site.originX==own.origin.originX and site.originY==own.origin.originY and site.z==own.origin.z
                    and not own.usedWorkId then
                    local step={id="shelter-use:"..tostring(#own.constructionResults+1),verb="produce",owner="SAO.ResourceProduction",
                        productionKind="use-shelter",token="resource:shelter-used",target=site.key,site=dataCopy(site),
                        category="construction",status="available"}
                    setPlan(retained,{step,{id="shelter-recovery",verb="recover",owner="SAONeeds",token="recovery:measured",
                        target=site.key,status="dependent"}},{},dataCopy(view),at)
                    return retained,retained.steps[retained.cursor]
                end
            end
            retained.blockers={"known-shelter-means-or-native-enclosure-unavailable"}
        end
        if retained then retained.blockers={"known-shelter-means-or-native-enclosure-unavailable"};retained.omittedAlternatives=omitted end
        return retained,nil,"shelter-means-unavailable"
    end
    local option,source=selected.option,selected.source
    if retained and not selected.ready and not source and option.kind=="build-shelter-edge" then
        local target="reobserve:"..option.site.key;local prior=retained.shelterConstruction.accessAttempts and retained.shelterConstruction.accessAttempts[target]
        if not prior or prior.at<option.site.observedAtHours then
            return shelterMovementPlan(retained,"inspect",target,option.site.approachX+.5,option.site.approachY+.5,option.site.approachZ,at)
        end
    end
    local p=retained or P.maintain(id,{key="recover-in-repaired-shelter",domain="body",
        objective="use personally known repaired shelter for bodily recovery",origin="recovery-concern",atHours=at})
    if not p then return nil end
    local origin=dataCopy(option.site);origin.z=option.site.originZ or option.site.z
    p.shelterConstruction=p.shelterConstruction or {recoveryKind=context.recoveryKind,origin=origin,
        stageHistory={},completedEdges={},completedSurfaces={},constructionResults={},coverNeeds=dataCopy(context.coverNeeds or {})}
    local steps,blockers={},{}
    if not selected.ready then
        if source and not selected.delayed then
            steps[#steps+1]={id=materialAcquisitionId(source),verb="acquire",owner="SAO.SourceUse",token="resource:acquired",
                target=source.sourceId..":"..tostring(source.itemId),category=source.category,sourceId=source.sourceId,
                sourceRevision=source.revision,itemId=source.itemId,itemType=source.itemType,place=dataCopy(source.place),
                quantity=1,quantityUnit="item",status="available"}
        else blockers[#blockers+1]=selected.delayed and "known-route-retry-delayed" or "missing-private-shelter-material" end
    end
    local index=#p.shelterConstruction.constructionResults+1
    local step={id="shelter-build:"..index,verb="produce",owner="SAO.ResourceProduction",token="resource:shelter-built",
        target=option.entityId,productionKind=option.kind,category="construction",
        entityId=option.entityId,recipeId=option.recipeId,site=dataCopy(option.site),requirements=dataCopy(option.requirements),
        inputs=dataCopy(option.inputs),status=#blockers>0 and "blocked" or #steps>0 and "dependent" or "available"}
    steps[#steps+1]=step
    -- Replanning observes the next native stage; no hypothetical completed room is inserted here.
    p.materialWork={operation="repair-shelter",entryKey=step.site.key}
    setPlan(p,steps,blockers,dataCopy(view),at);p.selectedStrategy=steps[1].id;p.omittedAlternatives=omitted
    return p,p.steps[p.cursor]
end
function P.admitShelterConstruction(id,w)
    local p,step=P.shelterPurpose(id)
    if not p or p.admission or not step or step.status~="available" or w.actorId~=id or p.id~=w.purposeId
        or step.productionKind~=w.kind or step.id~=w.purposeStepId or step.recipeId~=w.recipeId
        or step.site.key~=w.siteKey or step.site.revision~=w.siteRevision or not P.collectorReady(step) then return false end
    return P.noteAdmission(id,p.id,step.owner,w.id,step.id)
end
function P.consumeShelterConstructionResult(id,supplied)
    local canonical=type(supplied)=="table" and SAO.ResourceProduction.outcome(id,supplied.id)
    if not canonical or canonical.actorId~=id or canonical.kind~="build-shelter-edge" and canonical.kind~="build-shelter-surface" and canonical.kind~="build-shelter-stairs"
        or canonical.token~="resource:shelter-built" or canonical.nativeOwner~="ISBuildAction"
        or not finite(canonical.atHours) or canonical.atHours>nowHours() then return false end
    local s=state(id);local p=s and s.purposes[canonical.purposeId]
    if not p or p.status=="abandoned" then return true end
    for _,key in ipairs(p.resultReceipts or {}) do if key=="SAO.ResourceProduction:"..canonical.id then return true end end
    local step,ad=p.steps[p.cursor],p.admission
    if not p.shelterConstruction or not step or not ad or ad.owner~="SAO.ResourceProduction" or ad.stepId~=step.id
        or ad.correlationId~=canonical.id or ad.target~=step.target or step.id~=canonical.purposeStepId
        or canonical.atHours<ad.at or step.site.key~=canonical.siteKey or step.site.revision~=canonical.siteRevision
        or step.entityId~=canonical.entityId or step.recipeId~=canonical.recipeId
        or not P.collectorReady(step) or not P.collectorReady(canonical) then return false end
    local accepted=P.recordResult(id,p.id,{owner="SAO.ResourceProduction",token=canonical.token,status=canonical.status,
        correlationId=canonical.id,reason=canonical.detail,atHours=canonical.atHours},SHELTER_RESULT)
    if accepted and canonical.status=="completed" then
        local own=p.shelterConstruction
        own.stageHistory[canonical.siteKey]={entityId=canonical.entityId,revision=canonical.siteRevision,workId=canonical.id,at=canonical.atHours}
        if canonical.kind=="build-shelter-surface" then
            own.completedSurfaces=own.completedSurfaces or {};own.completedSurfaces[canonical.siteKey]=canonical.id
        end
        if canonical.entityId:find("WoodenWallLvl",1,true) or canonical.entityId:find("WoodenDoorLvl",1,true) then own.completedEdges[canonical.siteKey]=canonical.entityId end
        own.constructionResults[#own.constructionResults+1]=canonical.id
        p.status="maintained";p.blockers={"awaiting-next-observed-stage-and-usable-shelter"}
    end
    return accepted
end
function P.admitShelterUse(id,w)
    local p,step=P.shelterPurpose(id)
    if not p or p.admission or not step or step.status~="available" or w.actorId~=id or w.kind~="use-shelter"
        or p.id~=w.purposeId or step.id~=w.purposeStepId or step.productionKind~=w.kind
        or step.site.key~=w.siteKey or step.site.revision~=w.siteRevision then return false end
    return P.noteAdmission(id,p.id,"SAO.ResourceProduction",w.id,step.id)
end
function P.consumeShelterUseResult(id,supplied)
    local canonical=type(supplied)=="table" and SAO.ResourceProduction.outcome(id,supplied.id)
    if not canonical or canonical.kind~="use-shelter" or canonical.actorId~=id or canonical.atHours>nowHours() then return false end
    local s=state(id);local p=s and s.purposes[canonical.purposeId]
    if not p or p.status=="abandoned" then return true end
    for _,key in ipairs(p.resultReceipts or {}) do if key=="SAO.ResourceProduction:"..canonical.id then return true end end
    local step,ad=p.steps[p.cursor],p.admission
    if not p.shelterConstruction or not step or not ad or ad.owner~="SAO.ResourceProduction"
        or ad.stepId~=step.id or ad.correlationId~=canonical.id or step.id~=canonical.purposeStepId
        or step.site.key~=canonical.siteKey or step.site.revision~=canonical.siteRevision or canonical.atHours<ad.at then return false end
    local accepted=P.recordResult(id,p.id,{owner="SAO.ResourceProduction",token=canonical.token,status=canonical.status,
        correlationId=canonical.id,reason=canonical.detail,atHours=canonical.atHours},SHELTER_USE_RESULT)
    if accepted and canonical.status=="completed" then
        p.shelterConstruction.usedWorkId=canonical.id;p.shelterConstruction.useSite=dataCopy(canonical.site)
        p.shelterConstruction.cover=dataCopy(canonical.afterCover)
        local next=p.steps[p.cursor];if next and next.owner=="SAONeeds" then next.status="available" end
        p.status="maintained";p.blockers={"awaiting-ordinary-shelter-recovery"}
    end
    return accepted
end
function P.reconcileShelterRecovery(id,body)
    local p,step=P.shelterPurpose(id);local ad=p and p.admission;local rec=record(id)
    if not ad or ad.owner~="SAONeeds" then return true end
    if not p.shelterConstruction.usedWorkId or not step or ad.stepId~=step.id or ad.correlationId~="shelter-recovery:"..p.id
        or not rec or SAO.Body.get(id)~=body or not SAO.Needs.ownsRecoveryBody(id,body) then return false end
    local ok,quiet=pcall(function()
        return rec.recoveryIntent==nil and not SAO.Needs.recoveryActive(id,body) and not SAOJavaBridge:hasPendingActions(body)
            and body:getCurrentStateName()=="IdleState" and not body:isAsleep() and not body:isOnBed() and not body:isResting()
            and not (SAO.RecoveryPose and SAO.RecoveryPose.pendingExits and SAO.RecoveryPose.pendingExits[body])
    end)
    if not ok or not quiet then return false end
    p.lastAdmission=dataCopy(ad);p.admission=nil;step.status="available";p.status="maintained"
    p.shelterConstruction.recoverySequenceBefore=nil;p.blockers={"shelter-recovery-interrupted-awaiting-retry"};return true
end
function P.admitShelterRecovery(id,kind,place)
    local p,step=P.shelterPurpose(id);local rec=record(id);local own=p and p.shelterConstruction
    local site=own and own.useSite
    if not own or not own.usedWorkId or own.recoveryKind~=kind or not step or step.owner~="SAONeeds"
        or p.admission or not site or place.available~=true or place.z~=site.z or not rec.recoveryIntent
        or rec.recoveryIntent.kind~=kind or rec.recoveryIntent.place.key~=place.key then return false end
    local body=SAO.Body.get(id);local use=SAO.ResourceProduction.outcome(id,own.usedWorkId)
    if not body or not SAO.Needs.ownsRecoveryBody(id,body) or not use or not getWorld() or getWorld():getWorld()~=use.world then return false end
    local cover=SAOJavaBridge:worldShelterCover(body,math.floor(place.x),math.floor(place.y),place.z)
    if type(cover)~="table" or cover.reached~=true or cover.roof~=true or cover.regionKnown~=true
        or cover.enclosed~=true or cover.fullyRoofed~=true then return false end
    if SAOJavaBridge:worldShelterRecoveryValid(body,site.key,site.revision,place.x,place.y,place.z,true)~=true then return false end
    own.recoveryKey=place.key;own.recoverySequenceBefore=rec.recoveryExperienceSequence or 0
    return P.noteAdmission(id,p.id,"SAONeeds","shelter-recovery:"..p.id,step.id)
end
function P.consumeShelterRecovery(id,sequence)
    local canonical=SAO.Needs.behaviorOutcome(id,sequence);local p,step=P.shelterPurpose(id);local own=p and p.shelterConstruction
    local ad=p and p.admission
    if not canonical or not own or not ad or not step or step.owner~="SAONeeds" or ad.owner~="SAONeeds"
        or ad.stepId~=step.id or canonical.actorId~=id or canonical.actionKind~=own.recoveryKind
        or canonical.sourceId~=own.recoveryKey or sequence<=(own.recoverySequenceBefore or math.huge)
        or canonical.atHours<ad.at or canonical.atHours>nowHours() or canonical.succeeded~=true
        or not finite(canonical.durationHours) or canonical.durationHours<=0 or not finite(canonical.beforeValue)
        or not finite(canonical.afterValue) or (own.recoveryKind=="sleep" and canonical.afterValue>=canonical.beforeValue
            or own.recoveryKind=="rest" and canonical.afterValue<=canonical.beforeValue) then return false end
    return P.recordResult(id,p.id,{owner="SAONeeds",token="recovery:measured",status="completed",
        correlationId=ad.correlationId,atHours=canonical.atHours,reason="native-recovery-in-used-shelter"},SHELTER_RECOVERY_RESULT)
end

function P.planToolMaintenance(id, context)
    context = type(context) == "table" and context or {}
    local s = state(id, true)
    if not s then return nil, "person-unavailable" end
    local retained, current = P.maintenancePurpose(id)
    if retained and retained.admission then return retained, current end
    local at = finite(context.atHours) and context.atHours or nowHours()
    local pressure = clamp(tonumber(context.pressure) or 0, 0, 1)
    local candidates, offered, executable = {{ id = "continue-use", evidence = 1, continuity = 0.7,
        novelty = 0, informationGain = 0, blockers = 0, utility = 0.25 + pressure }}, {}
    for index, option in ipairs(type(context.options) == "table" and context.options or {}) do
        if index > 32 then break end
        local policy = type(option) == "table" and repairPolicy(option.recipeId)
        local before, maximum
        if policy then before, maximum = repairMeasure(option, policy) end
        if before and type(option.targetItemId) == "string" and option.targetItemId ~= ""
            and type(option.targetItemType) == "string" and option.targetItemType ~= ""
            and option.category == policy.category and option.toolCategory == policy.toolCategory
            and option.effectMetric == policy.effectMetric then
            local key = "maintain-tool:" .. option.targetItemId .. ":" .. option.targetItemType
            local purpose = purposeByKey(s, key)
            local known = context.sources and (context.sources[option.recipeId] or context.sources[policy.toolCategory])
            if policy.productionKind=="fix-held-item" then
                local matching={}
                for _,source in ipairs(type(known)=="table" and known or {}) do
                    if source.itemType==option.requiredItemType and tostring(source.itemId)~=option.targetItemId then matching[#matching+1]=source end
                end
                known=matching
            end
            local source, delayed = materialSource(purpose or {}, known, policy.toolCategory, at)
            local step = repairStep(option, policy, "available")
            local heldTool = type(option.toolItemId) == "string" and option.toolItemId ~= ""
                and type(option.toolItemType) == "string" and option.toolItemType ~= ""
            local waiting = not heldTool and delayed
            for _, failure in ipairs(purpose and purpose.routeFailures or {}) do
                if failure.stepId == step.id and finite(failure.retryAt) and at < failure.retryAt then waiting = true end
            end
            local travel = not heldTool and source and clamp((tonumber(source.distance) or 100) / 100, 0, 1) or 0
            local choice = step.id
            if not offered[choice] then
                local consequences = {{ kind = "tool-repair", category = "construction",
                    sourceId = policy.recipeId, itemType = option.targetItemType, value = 1 - before / maximum }}
                if policy.effectMetric == "sharpness" or policy.productionKind=="fix-held-item" then
                    consequences[#consequences + 1] = { kind = "tool-repair", category = "construction",
                        sourceId = policy.recipeId, itemType = option.targetItemType, condition = "damage", value = -0.25 }
                end
                candidates[#candidates + 1] = { id = choice, evidence = 1, continuity = purpose and 1 or 0.7,
                    novelty = purpose and 0 or 0.1, informationGain = 0.2,
                    blockers = (waiting or not heldTool and not source) and 1 or 0,
                    utility = 1 - before / maximum - travel, consequences = consequences }
                offered[choice] = { option = option, policy = policy, purpose = purpose, key = key,
                    step = step, source = not heldTool and source or nil, heldTool = heldTool, waiting = waiting,
                    executable = not waiting and (heldTool or source ~= nil) }
                if offered[choice].executable then executable = true end
            end
        end
    end
    -- The existing private interpreter admits sixteen alternatives. Keep its
    -- continued-use option, retained targets, then the largest observed deficit.
    local ranked = {}
    for index = 2, #candidates do
        local candidate = candidates[index]
        if not executable or offered[candidate.id].executable then ranked[#ranked + 1] = candidate end
    end
    table.sort(ranked, function(a, b)
        local aRetained, bRetained = offered[a.id].purpose ~= nil, offered[b.id].purpose ~= nil
        if aRetained ~= bRetained then return aRetained end
        if a.utility ~= b.utility then return a.utility > b.utility end
        return a.id < b.id
    end)
    candidates = { candidates[1] }
    for index = 1, math.min(15, #ranked) do candidates[#candidates + 1] = ranked[index] end
    local view = interpretations(id, candidates, { domain = "construction", pressure = pressure, atHours = at })
    local chosen = view and offered[view.selected]
    if not chosen then
        if retained then
            if current then current.status = "blocked" end
            retained.status = "blocked"
            retained.blockers = { #candidates == 1 and "native-maintenance-target-unavailable" or "maintenance-deferred" }
            retained.interpretations, retained.updatedAt = dataCopy(view), at
        end
        return retained, nil, "maintenance-deferred"
    end
    local purpose = chosen.purpose or P.maintain(id, { key = chosen.key,
        objective = "maintain an exact carried tool", domain = "construction", origin = "kit-tending", atHours = at })
    if not purpose then return nil, "person-unavailable" end
    local option, policy, step = chosen.option, chosen.policy, chosen.step
    purpose.materialWork = { operation = "maintain-tool", entryKey = "held-item:" .. option.targetItemId,
        targetItemId = option.targetItemId, targetItemType = option.targetItemType }
    local blockers, steps = {}, {}
    if chosen.waiting then blockers[#blockers + 1] = "known-route-retry-delayed" end
    if not chosen.heldTool then
        if chosen.source and not chosen.waiting then
            local source = chosen.source
            steps[#steps + 1] = { id = materialAcquisitionId(source), verb = "acquire", owner = "SAO.SourceUse",
                token = "resource:acquired", target = source.sourceId .. ":" .. tostring(source.itemId),
                category = source.category, sourceId = source.sourceId, sourceRevision = source.revision,
                itemId = source.itemId, itemType = source.itemType, place = dataCopy(source.place),
                quantity = 1, quantityUnit = "item", status = "available" }
        elseif not chosen.waiting then blockers[#blockers + 1] = "missing-known-" .. policy.toolCategory end
    end
    step.status = chosen.waiting and "blocked" or chosen.heldTool and "available"
        or #steps > 0 and "dependent" or "blocked"
    steps[#steps + 1] = step
    setPlan(purpose, steps, blockers, dataCopy(view), at)
    purpose.selectedStrategy = steps[1].id
    return purpose, purpose.steps[purpose.cursor]
end

function P.planFortification(id, context)
    context = type(context) == "table" and context or {}
    local repair = context.operation == "repair"
    if repair and (type(context.entryKey) ~= "string" or context.entryKey == "") then
        return nil, "window-not-observed"
    end
    local purpose = P.maintain(id, { key = repair and "repair:" .. context.entryKey or "fortify-home",
        objective = repair and "replace glass in a damaged entrance on held ground"
            or "reduce exposed entrances on held ground",
        domain = "construction", origin = "place-security", atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    local current = purpose.steps[purpose.cursor]
    -- Native admission fixes the exact material or aperture until its owner
    -- hands back a terminal result, even when newer observations arrive.
    if purpose.admission then return purpose, current end
    local at = finite(context.atHours) and context.atHours or nowHours()
    purpose.windowRepair = repair or nil
    purpose.materialWork = { operation = repair and "repair" or "board", entryKey = context.entryKey }
    if context.observedEntry == true then purpose.constructionTargetRefusal = nil end
    local destination = context.destination
    if type(destination) == "table" and destination.key == context.entryKey
        and finite(destination.x) and finite(destination.y) and finite(destination.z) then
        purpose.constructionDestination = { key = destination.key, x = destination.x,
            y = destination.y, z = destination.z }
    elseif purpose.constructionDestination and purpose.constructionDestination.key ~= context.entryKey then
        purpose.constructionDestination = nil
    end
    local steps, blockers = {}, {}
    if not context.insideOwnedGround then blockers[#blockers + 1] = "not-on-owned-ground" end
    if not context.knownGround then
        if repair then blockers[#blockers + 1] = "window-not-observed"
        else steps[#steps + 1] = { id = "survey-entrances", verb = "inspect", owner = "SAOBuild",
            status = context.insideOwnedGround and "available" or "blocked", token = "ground:surveyed" } end
    end
    local recipe = repair and {{ "glass-pane", 1 }} or {{ "hammer", 1 }, { "plank", 1 }, { "nails", 2 }}
    local supplied, selected, craftStep = true, nil, nil
    for _, need in ipairs(recipe) do
        local category, count = need[1], nil
        if type(context.materials) == "table" then count = context.materials[category]
        elseif repair and context.hasPane or not repair and context.hasKit then count = need[2] end
        count = finite(count) and math.max(0, math.floor(count)) or 0
        if count < need[2] then
            supplied = false
            local source, delayed = materialSource(purpose, context.sources and context.sources[category], category, at)
            if category == "plank" and not source and context.craftingAvailable == true then
                local craftReady, means = true, nil
                for _, input in ipairs({ "log", "saw" }) do
                    local held = context.materials and context.materials[input] or 0
                    if not finite(held) or held < 1 then
                        craftReady = false
                        local known, wait = materialSource(purpose, context.sources and context.sources[input], input, at)
                        if not means and known then means = known end
                        if not known then blockers[#blockers + 1] = wait and "known-route-retry-delayed"
                            or "missing-known-" .. input end
                    end
                end
                if craftReady and type(context.craftInputs) == "table" then
                    local inputs = context.craftInputs
                    if inputs.logItemId and inputs.logItemType == "Base.Log" and inputs.sawItemId
                        and type(inputs.sawItemType) == "string" then
                        local stepId = "craft-planks:" .. tostring(inputs.logItemId) .. ":" .. tostring(inputs.sawItemId)
                        local waiting = false
                        for _, failure in ipairs(purpose.routeFailures or {}) do
                            if failure.stepId == stepId and finite(failure.retryAt) and at < failure.retryAt then waiting = true end
                        end
                        craftStep = { id = stepId, verb = "produce", owner = "SAO.ResourceProduction",
                            token = "resource:crafted", target = "Base.SawLogs", recipeId = "Base.SawLogs",
                            productionKind = "saw-logs", category = "plank", quantity = 3,
                            logItemId = tostring(inputs.logItemId), logItemType = inputs.logItemType,
                            sawItemId = tostring(inputs.sawItemId), sawItemType = inputs.sawItemType,
                            status = waiting and "blocked" or "available" }
                        if waiting then blockers[#blockers + 1] = "native-craft-retry-delayed" end
                    end
                end
                source = means
            end
            if not source and not craftStep then blockers[#blockers + 1] = delayed and "known-route-retry-delayed"
                or "missing-known-" .. category end
            if not selected and source and context.insideOwnedGround and context.knownGround and context.entryKey then
                selected = source
            end
        end
    end
    -- A usable saw remains a means. Maintenance competes with immediate use
    -- through this person's existing interpreter and actual held condition.
    local maintenanceView
    local inputs = context.repairInputs
    if craftStep and type(inputs) == "table" and inputs.available == true
        and inputs.targetItemId == craftStep.sawItemId and inputs.targetItemType == craftStep.sawItemType
        and finite(inputs.condition) and finite(inputs.maxCondition)
        and inputs.condition > 0 and inputs.maxCondition > inputs.condition then
        local source = not inputs.toolItemId and materialSource(purpose, context.sources and context.sources.file, "file", at)
        if inputs.toolItemId or source then
            local ratio = inputs.condition / inputs.maxCondition
            local stepId = "repair-saw:" .. inputs.targetItemId .. ":" .. tostring(inputs.condition)
            local waiting = false
            for _, failure in ipairs(purpose.routeFailures or {}) do
                if failure.stepId == stepId and finite(failure.retryAt) and at < failure.retryAt then waiting = true end
            end
            local travel = source and clamp((tonumber(source.distance) or 100) / 100, 0, 1) or 0
            local candidates = {
                { id = craftStep.id, evidence = 1, continuity = 0.8, novelty = 0, informationGain = 0,
                    blockers = craftStep.status == "available" and 0 or 1,
                    utility = ratio + clamp(tonumber(context.pressure) or 0, 0, 1) },
                { id = stepId, evidence = 1, continuity = 0.8, novelty = 0, informationGain = 0.2,
                    blockers = waiting and 1 or 0, utility = 1 - ratio - travel,
                    consequences = {{ kind = "tool-repair", category = "construction",
                        sourceId = "Base.FixSaw", itemType = inputs.targetItemType, value = 1 - ratio }} },
            }
            if not waiting then
                maintenanceView = interpretations(id, candidates, { domain = "construction",
                    pressure = clamp(tonumber(context.pressure) or 0, 0, 1), atHours = at })
                local chosen = maintenanceView and maintenanceView.selected
                if not chosen and SAO.CognitiveModels and SAO.CognitiveModels.planScore then
                    local a = SAO.CognitiveModels.planScore("ordinary", candidates[1], 0)
                    local b = SAO.CognitiveModels.planScore("ordinary", candidates[2], 0)
                    chosen = a and b and b > a and stepId or craftStep.id
                end
                if chosen == stepId then
                    selected = source
                    craftStep = { id = stepId, verb = "produce", owner = "SAO.ResourceProduction",
                        token = "resource:repaired", target = "Base.FixSaw", recipeId = "Base.FixSaw",
                        productionKind = "repair-held-item", category = "saw", toolCategory = "file", effectMetric = "condition",
                        targetItemId = inputs.targetItemId, targetItemType = inputs.targetItemType,
                        toolItemId = inputs.toolItemId, toolItemType = inputs.toolItemType,
                        status = inputs.toolItemId and "available" or "dependent" }
                end
            end
        end
    end
    if selected then
        steps[#steps + 1] = { id = materialAcquisitionId(selected), verb = "acquire", owner = "SAO.SourceUse",
            token = "resource:acquired", target = selected.sourceId .. ":" .. tostring(selected.itemId),
            category = selected.category, sourceId = selected.sourceId, sourceRevision = selected.revision,
            itemId = selected.itemId, itemType = selected.itemType, place = dataCopy(selected.place),
            quantity = 1, quantityUnit = "item", status = "available" }
    elseif craftStep and context.insideOwnedGround and context.knownGround and context.entryKey then
        steps[#steps + 1] = craftStep
    end
    local ready = supplied and context.knownGround and context.insideOwnedGround and context.entryKey
    local constructionId = repair and "repair-known-window" or "board-known-entry"
    if not repair and type(context.materials) == "table" then
        constructionId = constructionId .. ":" .. tostring(context.entryKey) .. ":" .. purpose.id
    end
    steps[#steps + 1] = { id = constructionId, verb = "construct",
        owner = repair and "SAO.WindowRepair" or "SAOBuild",
        token = repair and "construction:window-repaired" or "construction:boarded", target = context.entryKey,
        status = ready and "available" or (selected or craftStep) and "dependent" or "blocked" }
    setPlan(purpose, steps, blockers, interpretations(id, {
        { id = repair and "repair" or "board", evidence = context.knownGround and 0.9 or 0.2,
            continuity = 0.7, novelty = 0.1, informationGain = 0.3, blockers = #blockers },
        { id = "survey", evidence = context.knownGround and 0.8 or 0.4,
            continuity = 0.4, novelty = 0.2, informationGain = 0.9,
            blockers = context.insideOwnedGround and 0 or 1 },
    }, { domain = "construction", pressure = tonumber(context.pressure) or 0 }), at)
    if maintenanceView then purpose.interpretations = dataCopy(maintenanceView) end
    purpose.selectedStrategy = selected and materialAcquisitionId(selected) or craftStep and craftStep.id or nil
    return purpose, purpose.steps[purpose.cursor]
end

function P.deferConstructionTarget(id, purposeId, entryKey, reason)
    local s = state(id)
    local purpose = s and s.purposes[purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    local at = nowHours()
    if not purpose or purpose.admission or not purpose.materialWork
        or purpose.materialWork.entryKey ~= entryKey or not step or step.verb ~= "construct"
        or step.target ~= entryKey or not finite(at) then return false end
    purpose.constructionTargetRefusal = { entryKey = entryKey, atHours = at, retryAt = at + 0.1 }
    step.status, purpose.status = "blocked", "blocked"
    purpose.blockers = { "native-entry-revalidation-required" }
    addEvent(purpose, "construction-target-refused", tostring(reason or "native-entry-unavailable"), at)
    return true
end

function P.constructionDestination(id)
    local s = state(id)
    local selected, priority
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        local work, destination = purpose and purpose.materialWork, purpose and purpose.constructionDestination
        local refusal = purpose and purpose.constructionTargetRefusal
        local at = nowHours()
        local waiting = type(refusal) == "table" and work and refusal.entryKey == work.entryKey
            and finite(refusal.atHours) and finite(refusal.retryAt)
            and at >= refusal.atHours and at < refusal.retryAt
        if work and destination and destination.key == work.entryKey
            and purpose.status ~= "completed" and purpose.status ~= "abandoned"
            and (purpose.admission or not waiting) then
            local step = purpose.steps[purpose.cursor]
            local rank = purpose.admission and 1 or step and step.status == "available" and 2 or 3
            if not selected or rank < priority then selected, priority = purpose, rank end
        end
    end
    if selected then
        local work, destination = selected.materialWork, selected.constructionDestination
        return { purposeId = selected.id, operation = work.operation, entryKey = work.entryKey,
            x = destination.x, y = destination.y, z = destination.z,
            pendingAdmission = selected.admission ~= nil, status = selected.status }
    end
end

local function leisurePurpose(id, activity, itemKey, unfinishedInstrument)
    local s, person = state(id), record(id)
    local candidates = {}
    for _, purposeId in ipairs(s and s.order or {}) do candidates[#candidates + 1] = s.purposes[purposeId] end
    local suspended = s and s.suspendedLeisure
    for _, purposeId in ipairs(suspended and suspended.order or {}) do
        candidates[#candidates + 1] = suspended.purposes[purposeId]
    end
    for _, purpose in ipairs(candidates) do
        local choice = purpose and type(purpose.leisure) == "table" and purpose.leisure
        local work = person and person.studyWork
        if purpose and not (purpose.hobby and (purpose.status=="completed" or purpose.status=="abandoned"))
            and ((choice and (choice.activityKey or choice.activity) == activity and choice.itemKey == itemKey)
            or not choice and purpose.key == "leisure:" .. activity
                and (not itemKey or work and work.purposeId == purpose.id and work.itemId == itemKey)) then
            local performed = false
            for _, step in ipairs(purpose.steps or {}) do
                if step.id == "perform-activity" and step.status == "completed" then performed = true end
            end
            if not unfinishedInstrument or purpose.instrument and not performed then return purpose end
        end
    end
end

-- Pure exact-item choice feedback. A performed step may still have unfinished
-- sharing; choosing another item must leave that purpose and its receipts intact.
function P.leisureChoice(id, activity, itemKey, activityKey)
    if not record(id) then return false, "person-unavailable" end
    local purpose = leisurePurpose(id, type(activityKey) == "string" and activityKey or activity, itemKey)
    if not purpose then return true end
    for _, step in ipairs(purpose.steps or {}) do
        if step.id == "perform-activity" and step.status == "completed" then
            return false, "activity-already-performed"
        end
    end
    local refusal, at = type(purpose.leisure) == "table" and purpose.leisure.refusal, nowHours()
    if type(refusal) == "table" and finite(refusal.at) and finite(refusal.retryAt)
        and refusal.at <= at and at < refusal.retryAt and refusal.retryAt <= refusal.at + 1 / 60 then
        return false, "native-reading-recently-refused"
    end
    return true
end

function P.leisureRefusal(id, purposeId, workId)
    local s, person = state(id), record(id)
    local purpose = s and s.purposes[purposeId]
    local work = person and person.studyWork
    local at = nowHours()
    if not purpose or not purpose.leisure or not work or work.kind ~= "leisure"
        or work.id ~= workId or work.purposeId ~= purposeId or work.itemId ~= purpose.leisure.itemKey
        or work.status ~= "interrupted" or work.reason ~= "native-reading-queue-refused"
        or not finite(work.endedAt) or work.endedAt > at or at - work.endedAt > 1 / 60 then return false end
    if purpose.leisure.refusal and purpose.leisure.refusal.workId == workId then return true end
    -- One game minute is a bounded admission retry policy, not learned value.
    purpose.leisure.refusal = { workId = workId, at = work.endedAt, retryAt = work.endedAt + 1 / 60,
        reason = work.reason, basis = "Study-native-queue-refusal" }
    addEvent(purpose, "admission-refused", work.reason, work.endedAt)
    return true
end

local function leisureAcquisitionStep(step)
    return step and (step.id=="acquire-leisure-item" or string.sub(step.id or "",1,21)=="acquire-leisure-item:")
end
local function acquiredLeisurePurpose(id, itemKey, itemType, owner, activity)
    local s = state(id)
    for index = #(s and s.order or {}), 1, -1 do
        local purposeId = s.order[index]
        local purpose = s.purposes[purposeId]
        local acquisitions={}
        if purpose and purpose.leisureAcquisition then acquisitions[1]=purpose.leisureAcquisition end
        for _,prior in ipairs(purpose and purpose.leisureAcquisitions or {}) do acquisitions[#acquisitions+1]=prior end
        for _,acquisition in ipairs(acquisitions) do
        if acquisition and not purpose.leisure and purpose.status ~= "abandoned" and not purpose.admission
            and acquisition.itemId == itemKey and acquisition.itemType == itemType and acquisition.owner == owner
            and (not activity or acquisition.kind == activity)
            and acquisition.resultId then
            local result = SAO.WorldSources.actionOutcome(acquisition.resultId, id)
            if result and result.status == "completed" and result.operation == "acquire"
                and result.measurement == "native-item-transfer" and (tonumber(result.observedQuantity) or 0) > 0
                and result.preRevision == acquisition.revision and finite(result.at) and result.at <= nowHours()
                and result.purposeId == purpose.id and tostring(result.itemId) == itemKey
                and result.itemType == itemType and result.sourceId == acquisition.sourceId then return purpose end
        end
        end
    end
end

function P.leisureAcquisitionAvailable(id, sourceId, itemId, revision)
    local s = state(id)
    for _, purposeId in ipairs(s and s.order or {}) do
        local purpose = s.purposes[purposeId]
        local acquisition = purpose and purpose.leisureAcquisition
        if acquisition and acquisition.sourceId == sourceId and acquisition.itemId == tostring(itemId)
            and acquisition.revision == revision then
            if purpose.admission then return false end
            if finite(acquisition.failedAt) and nowHours() < acquisition.failedAt + 1/60 then return false end
        end
    end
    return true
end

function P.leisureAcquiredPurpose(id, itemKey, itemType, owner, activity)
    local purpose = acquiredLeisurePurpose(id, itemKey, itemType, owner, activity)
    return purpose and { id=purpose.id, itemKey=itemKey } or nil
end

-- Only selected, privately known native source options create acquisition work.
function P.planLeisureAcquisition(id, body, offer, kind, observedPlace)
    local requirement=type(kind)=="table" and kind or nil
    local owner=requirement and requirement.owner or kind=="instrument" and "SAO.Gesture" or "SAONeeds"
    if requirement then
        local valid=false
        local receiver=SAO.LeisureAcquisition
        for _,current in ipairs(receiver and receiver.requirements(id,body,offer and offer.parameters and offer.parameters.itemType) or {}) do
            if current.owner==requirement.owner and current.activity==requirement.activity
                and current.requirementId==requirement.requirementId and current.sourceId==requirement.sourceId
                and current.revision==requirement.revision and current.role==requirement.role then valid=true;break end
        end
        if not valid then return nil end
        kind=requirement.activity
    elseif kind ~= "reading" and kind ~= "instrument" then return nil end
    if type(offer) ~= "table" then return nil end
    local parameters = offer.parameters
    if not parameters or (parameters.sourceKind ~= "ground" and parameters.sourceKind ~= "container")
        or parameters.category ~= (requirement and "leisure-material" or kind == "reading" and "reading" or "instrument")
        or not P.leisureAcquisitionAvailable(id, parameters.sourceId, parameters.itemId, parameters.revision) then return nil end
    local place = observedPlace or {id="source:"..parameters.sourceId,sourceId=parameters.sourceId,
        cx=parameters.sourceX+0.5,cy=parameters.sourceY+0.5,z=parameters.sourceZ}
    local options = SAO.WorldSources.actionOptions(place,parameters.category,id,body,1,"standing","acquire")
    local exact
    for _, candidate in ipairs(options and options.options or {}) do
        local p = candidate.parameters
        if p.sourceId==parameters.sourceId and p.itemId==parameters.itemId and p.itemType==parameters.itemType
            and p.revision==parameters.revision and p.fingerprint==parameters.fingerprint then exact=p;break end
    end
    if not exact then return nil end
    local key="leisure-acquire:"..exact.sourceId..":"..tostring(exact.itemId)..":"..exact.revision
    if requirement then key=key..":"..owner..":"..requirement.requirementId end
    -- A genuinely reobserved dropped item can be acquired again. Preserve the
    -- old native receipt and purpose rather than rewriting their acquisition.
    local s, previous = state(id), nil
    for _, purposeId in ipairs(s and s.order or {}) do
        local prior = s.purposes[purposeId]
        local a = prior and prior.leisureAcquisition
        if a and a.sourceId==exact.sourceId and a.itemId==tostring(exact.itemId)
            and a.revision==exact.revision and a.resultId then previous=a.resultId end
    end
    if previous then key=key..":after:"..previous end
    local purpose
    if requirement and requirement.role=="material" then
        for index=#(s and s.order or {}),1,-1 do
            local prior=s.purposes[s.order[index]];local a=prior and prior.leisureAcquisition
            if a and a.owner==owner and a.kind==kind and a.requirement and a.requirement.role=="material"
                and not prior.leisure and not prior.admission
                and (prior.status=="maintained" or prior.status=="interrupted") then
                -- Retrying the unfinished exact supply retains the original chain.
                -- Its failed native receipt remains failed in the source ledger.
                if not a.resultId and a.sourceId==exact.sourceId and a.itemId==tostring(exact.itemId)
                    and a.itemType==exact.itemType and a.revision==exact.revision and a.fingerprint==exact.fingerprint
                    and a.requirement.requirementId==requirement.requirementId
                    and a.requirement.sourceId==requirement.sourceId and a.requirement.revision==requirement.revision then
                    purpose=prior;break
                elseif a.resultId then
                    local verified=acquiredLeisurePurpose(id,a.itemId,a.itemType,owner,kind)
                    if verified==prior and #(prior.leisureAcquisitions or {})<MAX_EVENTS-1 then purpose=prior;break end
                end
            end
        end
    end
    local steps={}
    if purpose then
        purpose.leisureAcquisitions=purpose.leisureAcquisitions or {}
        if purpose.leisureAcquisition.resultId then
            purpose.leisureAcquisitions[#purpose.leisureAcquisitions+1]=dataCopy(purpose.leisureAcquisition)
        end
        for _,prior in ipairs(purpose.steps or {}) do
            if leisureAcquisitionStep(prior) and prior.status=="completed" then steps[#steps+1]=dataCopy(prior) end
        end
    end
    purpose=purpose or P.maintain(id,{key=key,domain="leisure",objective="obtain "..exact.itemType.." for "..kind,origin="observed-material"})
    if not purpose then return nil end
    purpose.leisureAcquisition={sourceId=exact.sourceId,itemId=tostring(exact.itemId),itemType=exact.itemType,
        revision=exact.revision,fingerprint=exact.fingerprint,kind=kind,owner=owner,
        requirement=requirement and dataCopy(requirement) or nil}
    steps[#steps+1]={id=#steps==0 and "acquire-leisure-item" or "acquire-leisure-item:"..tostring(#steps+1),verb="acquire",owner="SAO.SourceUse",status="available",
        token="leisure:item-acquired",target=exact.sourceId,itemId=exact.itemId,itemType=exact.itemType,sourceId=exact.sourceId}
    steps[#steps+1]={id="use-acquired-item",verb="recreate",owner=purpose.leisureAcquisition.owner,status="dependent",
        token="leisure:performed",target=kind}
    setPlan(purpose,steps, {}, nil,nowHours())
    return purpose,purpose.steps[purpose.cursor],place
end

function P.planLeisure(id, context)
    context = type(context) == "table" and context or {}
    local activity = tostring(context.activity or "recreation")
    local activityKey = type(context.activityKey) == "string" and context.activityKey or activity
    local itemKey = type(context.itemKey) == "string" and context.itemKey or nil
    local instrument = context.nativeVerb == "blow-harmonica" and context.owner == "SAO.Gesture" and itemKey
    local sequence
    if instrument then
        local owner = SAO.Gesture
        sequence = owner and owner.nextInstrumentSequence and owner.nextInstrumentSequence(id)
        if not finite(sequence) or sequence < 1 or sequence ~= math.floor(sequence) then
            return nil, "instrument-sequence-unavailable"
        end
    else
        local available, reason = P.leisureChoice(id, activity, itemKey, activityKey)
        if not available then return nil, reason end
    end
    local key = "leisure:" .. activityKey .. (itemKey and ":item:" .. itemKey or "")
    local acquired
    if context.acquiredPurposeId then
        local s=state(id);local pending=s and s.purposes[context.acquiredPurposeId]
        local a=pending and pending.leisureAcquisition
        if a and a.owner==context.owner and a.kind==activity then
            local acquisitions={a}
            for _,prior in ipairs(pending.leisureAcquisitions or {}) do acquisitions[#acquisitions+1]=prior end
            for _,supply in ipairs(acquisitions) do
                if supply.owner==context.owner and supply.kind==activity then
                    local verified=acquiredLeisurePurpose(id,supply.itemId,supply.itemType,context.owner,activity)
                    if verified==pending then acquired=pending;break end
                end
            end
            if not acquired or acquired.id~=context.acquiredPurposeId then return nil,"acquisition-purpose-unavailable" end
        else return nil,"acquisition-purpose-unavailable" end
    end
    local purpose = acquired or leisurePurpose(id, activityKey, itemKey, instrument)
        or acquiredLeisurePurpose(id, itemKey, context.affordance, context.owner)
    if instrument then
        if purpose and purpose.admission then return purpose, purpose.steps[purpose.cursor] end
        key = key .. ":occurrence:" .. tostring(purpose and purpose.instrument and purpose.instrument.occurrence or sequence)
    end
    if purpose then purpose.key = key end
    purpose = purpose or P.maintain(id, { key = key,
        objective = "make time for " .. activity .. " in a usable shared place",
        domain = "leisure", origin = context.spontaneous and "impulse" or "routine",
        atHours = context.atHours })
    if not purpose then return nil, "person-unavailable" end
    purpose.leisure = purpose.leisure or { activity = activity, itemKey = itemKey,
        activityKey = type(context.activityKey) == "string" and context.activityKey or nil }
    if context.nativeVerb == "read-written-note" and context.owner == "SAONeeds" and itemKey then
        purpose.noteReading = true
    end
    if instrument then
        purpose.instrument = purpose.instrument or { verb = context.nativeVerb, itemKey = itemKey,
            itemType = context.affordance, occurrence = sequence }
        purpose.instrument.expectedSequence = sequence
    end
    local blockers, steps = {}, {}
    if purpose.leisureAcquisition then
        for _, prior in ipairs(purpose.steps or {}) do
            if leisureAcquisitionStep(prior) and prior.status == "completed" then
                steps[#steps + 1] = dataCopy(prior)
            end
        end
    end
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
        token = purpose.noteReading and "note:text-exposed" or "leisure:performed", target = activity }
    steps[#steps + 1] = { id = "share-activity", verb = "socialize",
        owner = "native-participation", status = "dependent",
        token = "leisure:shared", target = activity, required = false }
    local planned = { id = "planned", evidence = context.affordance and 0.8 or 0.1,
        continuity = 0.8, novelty = 0.2, informationGain = 0.2,
        blockers = #blockers }
    local spontaneous = { id = "spontaneous", evidence = context.atLocation and 0.7 or 0.2,
        continuity = 0.2, novelty = 0.8, informationGain = 0.5,
        blockers = #blockers }
    if instrument then
        -- The predicted consequence is one physically emitted native sound.
        -- Pleasure, competence and another person's participation need evidence.
        local effect = { kind = "recreate", category = "leisure",
            sourceId = "native:sound:BlowHarmonica", itemType = context.affordance, value = 1 }
        planned.consequences, spontaneous.consequences = { dataCopy(effect) }, { dataCopy(effect) }
    end
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

-- A concept inquiry concerns a means to an existing end. Its relational path
-- supplies a question; only personally observed frontiers supply route targets.
-- Exact means failures are temporary, person-private objections. The native
-- owner supplies a correlated receipt; an appraisal cannot manufacture one.
function P.meansResult(id,owner,sequence)
    if owner~="SAO.Needs" or not SAO.Needs or not SAO.Needs.meansResult then return false end
    local row=SAO.Needs.meansResult(id,sequence)
    local at=nowHours()
    if not row or row.schema~="sao.physical-means-result/1" or row.actorId~=id or row.owner~=owner
        or not finite(row.sequence) or row.sequence~=sequence or not finite(row.atHours) or row.atHours~=at
        or type(row.sourceId)~="string" or #row.sourceId>256 or type(row.candidateId)~="string" or #row.candidateId>384
        or type(row.available)~="boolean" or type(row.reason)~="string" or #row.reason>160
        or (row.scope~="geometry" and row.scope~="approach" and row.scope~="admission") then return false end
    local s=state(id,false)
    if row.available and not s then return true end
    s=s or state(id,true)
    if not s then return false end
    s.meansReadThrough=s.meansReadThrough or {}
    if sequence<=(s.meansReadThrough[owner] or 0) then return false end
    s.meansReadThrough[owner]=sequence
    s.meansFailures,s.meansFailureOrder=s.meansFailures or {},s.meansFailureOrder or {}
    local goals={}
    if row.actionKind=="sleep" or not row.actionKind then goals[#goals+1]="relief-from-tiredness" end
    if row.actionKind=="rest" or not row.actionKind and row.sourceKind=="ground" then goals[#goals+1]="relief-from-exertion" end
    for _,goal in ipairs(goals) do
        local key=goal.."\30"..row.sourceId.."\30"..row.candidateId.."\30"..row.scope
        if row.available then
            -- A visible clear approach revokes only a geometry refusal. It says
            -- nothing about whether a previous route or queued action succeeded.
            s.meansFailures[key]=nil
            for index=#s.meansFailureOrder,1,-1 do
                if s.meansFailureOrder[index]==key then table.remove(s.meansFailureOrder,index) end
            end
        else
            if not s.meansFailures[key] then
                if #s.meansFailureOrder>=64 then s.meansFailures[table.remove(s.meansFailureOrder,1)]=nil end
                s.meansFailureOrder[#s.meansFailureOrder+1]=key
            end
            local failure=dataCopy(row)
            failure.goal=goal
            -- Same bounded retry as the existing recovery approach owner, in
            -- the persisted county clock rather than a runtime body binding.
            failure.retryAtHours=at+600/(SAO.History.TICKS_PER_HOUR or 9000)
            s.meansFailures[key]=failure
        end
    end
    return true
end
function P.meansUnavailable(id,goal,sourceId,candidateId)
    if type(sourceId)~="string" then return false end
    local s,at=state(id,false),nowHours()
    for _,key in ipairs(s and s.meansFailureOrder or {}) do
        local failure=s.meansFailures and s.meansFailures[key]
        if failure and failure.actorId==id and failure.goal==goal and failure.sourceId==sourceId
            and finite(failure.atHours) and failure.atHours<=at and finite(failure.retryAtHours) and at<failure.retryAtHours
            and (not candidateId or failure.scope=="geometry" or failure.candidateId==candidateId) then
            return true,dataCopy(failure)
        end
    end
    return false
end
local function excludedMeans(id,goal,fact)
    return P.meansUnavailable(id,goal,fact.recoverySourceId)
end
function P.conceptFrontierKey(frontier)
    return tostring(frontier.key).."@"..tostring(frontier.roomId)
end
function P.conceptInquiryTarget(offer)
    if type(offer)~="table" then return nil end
    if offer.mode=="inspect-holder" and offer.observedMeans then
        if type(offer.sourceId)~="string" then return nil end
        local fact=offer.observedMeans
        -- This is the known holder used for appraisal, never a walking tile.
        return {key="holder:"..offer.sourceId,x=fact.x,y=fact.y,z=fact.z}
    end
    if offer.approach then
        return {key="remembered:"..offer.observedMeans.key.."@"..offer.approach.roomId,
            x=offer.approach.x,y=offer.approach.y,z=offer.approach.z}
    end
    local frontier=offer.frontier
    return frontier and {key=P.conceptFrontierKey(frontier),x=frontier.entryX,y=frontier.entryY,z=frontier.entryZ} or nil
end
function P.conceptInquiryOffer(id,goal,tick)
    local knowledge,perception=SAO.ConceptKnowledge,SAO.Perception
    if not knowledge or not perception or not perception.conceptContext then return nil end
    local context=perception.conceptContext(id,tick)
    local s=state(id,false)
    local retained=s and purposeByKey(s,"concept-inquiry:"..tostring(goal)..":"..tostring(context.buildingId))
    local attempts=retained and retained.inquiry and retained.inquiry.attempts or {}
    local out={goal=goal,status="unresolved",reason="No current personally observed place is available."}
    -- A personally witnessed holder can be inspected for possible contents.
    -- The query reads only this person's evidence. Native candidate selection
    -- and its walkable approach belong to the selected dispatch below.
    local tried=0 for _ in pairs(attempts) do tried=tried+1 end
    if context.status=="observed" and context.roomId and context.buildingId and tried<12 then
        for _,fact in ipairs(context.observations) do
            if fact.kind=="object" and fact.roomId==context.roomId and type(fact.sourceId)=="string"
                and #fact.sourceId<=512 and string.sub(fact.sourceId,1,2)=="C:"
                and finite(fact.x) and finite(fact.y) and finite(fact.z) then
                local attempt=attempts["holder:"..fact.sourceId]
                local previous=attempt and SAO.WorldSources and SAO.WorldSources.inspectionOutcome
                    and SAO.WorldSources.inspectionOutcome(id,attempt.receiptId)
                local inspected=previous and previous.actorId==id and previous.sourceId==fact.sourceId
                    and previous.status=="completed" and previous.nativeInspected==true and previous.privateLearned==true
                    and finite(previous.atHours) and previous.atHours<=nowHours()
                if not inspected then
                    local inference=knowledge.infer(id,fact.concept,goal,context.buildingId)
                    for _,path in ipairs(inference and inference.paths or {}) do
                        local first=path.roots[1]
                        if first and (first.relation=="may-contain" or first.relation=="typically-contains"
                            or first.relation=="contains") then
                            out.status,out.mode,out.sourceId="actionable","inspect-holder",fact.sourceId
                            out.observedMeans,out.path=dataCopy(fact),path
                            out.contextId,out.desiredConcept=context.buildingId,first.into
                            out.reason=knowledge.explain(path).." I can inspect that observed holder; its contents are unconfirmed."
                            return out
                        end
                    end
                end
            end
        end
    end
    -- A visible usable means outranks an unlocated intermediate room label.
    -- Only affordance/effect links count here: a container's possible contents
    -- still require inspection, so its presence cannot establish food or water.
    for _,fact in ipairs(context.observations) do
        if fact.kind=="object" and fact.roomId==context.roomId and not excludedMeans(id,goal,fact) then
            local inference=knowledge.infer(id,fact.concept,goal,context.buildingId)
            for _,path in ipairs(inference and inference.paths or {}) do
                local means=true
                for _,edge in ipairs(path.roots) do
                    if edge.relation=="contains" or edge.relation=="typically-contains"
                        or edge.relation=="may-contain" then means=false;break end
                end
                if means then
                    out.status,out.observedMeans,out.path="observed-means",dataCopy(fact),path
                    out.reason="A possible means is already personally observed here; its native owner must check usability."
                    return out
                end
            end
        end
    end
    -- Memory supplies a reason to revisit a witnessed location, never current
    -- usability. The approach is a tile this person actually occupied in that
    -- room, not the object's possibly solid tile or an invented adjacent tile.
    local memories=perception.conceptMemories and perception.conceptMemories(id,tick) or {}
    for _,fact in ipairs(memories) do
        if fact.kind=="object" and fact.roomId and fact.buildingId and not excludedMeans(id,goal,fact) then
            local inference=knowledge.infer(id,fact.concept,goal,fact.buildingId)
            for _,path in ipairs(inference and inference.paths or {}) do
                local direct=true
                for _,edge in ipairs(path.roots) do
                    if edge.relation=="contains" or edge.relation=="typically-contains" or edge.relation=="may-contain" then direct=false;break end
                end
                if direct then
                    local memoryPurpose=s and purposeByKey(s,"concept-inquiry:"..tostring(goal)..":"..fact.buildingId)
                    local memoryAttempts=memoryPurpose and memoryPurpose.inquiry and memoryPurpose.inquiry.attempts or {}
                    local key="remembered:"..fact.key.."@"..fact.roomId
                    local used=0 for _ in pairs(memoryAttempts) do used=used+1 end
                    if used>=12 then
                        out.limitReached=true
                        out.reason="I have exhausted this bounded search and need another lead."
                    elseif not memoryAttempts[key] then
                        out.reason="I remember a possible means, but do not have an observed approach to its room."
                    end
                    if not memoryAttempts[key] and used<12 then
                        for _,room in ipairs(memories) do
                            if room.kind=="room" and room.roomId==fact.roomId and room.buildingId==fact.buildingId and room.z==fact.z then
                                out.status,out.mode="actionable","remembered-means"
                                out.observedMeans,out.approach,out.path=dataCopy(fact),dataCopy(room),path
                                out.contextId,out.desiredConcept=fact.buildingId,fact.concept
                                out.reason="I remember "..fact.concept.." in a room I have visited. "..knowledge.explain(path)
                                    .." I can return to that observed place and check whether it is usable now."
                                return out
                            end
                        end
                    end
                end
            end
        end
    end
    if context.status~="observed" or not context.roomId or not context.buildingId then return out end
    local tried=0 for _ in pairs(attempts) do tried=tried+1 end
    if tried>=12 then out.reason="I have exhausted this bounded search and need another lead.";out.limitReached=true;return out end
    for _,anchor in ipairs(context.observations) do
        if (anchor.kind=="room" or anchor.kind=="place") and anchor.roomId==context.roomId then
            local inference=knowledge.infer(id,anchor.concept,goal,context.buildingId)
            out.inference=inference
            for _,path in ipairs(inference and inference.paths or {}) do
                local means=path.roots[1] and path.roots[1].into
                local seen=false
                for _,fact in ipairs(context.observations) do
                    if fact.roomId==context.roomId and fact.concept==means and not excludedMeans(id,goal,fact) then seen=true;break end
                end
                if not seen then
                    out.path,out.desiredConcept,out.contextId=path,means,context.buildingId
                    out.reason=knowledge.explain(path)
                    local selected,backtrack
                    for _,frontier in ipairs(context.frontiers) do
                        if not attempts[P.conceptFrontierKey(frontier)] then
                            local crossed=false
                            for key,attempt in pairs(attempts) do
                                if (attempt.frontierKey==frontier.key or key==frontier.key)
                                    and attempt.status=="approached" then crossed=true;break end
                            end
                            if not crossed then selected=frontier;break end
                            backtrack=backtrack or frontier
                        end
                    end
                    selected=selected or backtrack
                    if selected then
                        out.status,out.frontier="actionable",dataCopy(selected)
                        out.backtracking=selected==backtrack
                        if out.backtracking then out.reason=out.reason.." I can return through a known doorway to continue looking." end
                        return out
                    end
                    out.reason=out.reason.." I do not currently know an unchecked way onward."
                else out.reason="A relevant means is already personally observed here." end
            end
        end
    end
    return out
end
-- A question about present circumstances supplies its own end. It needs no
-- deprivation and does not turn a remembered sound origin into a walking tile.
function P.situationInquiryOffer(id,body,tick)
    local cognition=SAO.Cognition
    local view=cognition and cognition.appraiseSituation and cognition.appraiseSituation(id,body,tick)
    if not view or view.status~="questions" or view.actorId~=id or view.clarity<=0 then return nil,view end
    local context=view.context
    if not context or context.status~="observed" then return nil,view end
    local s=state(id,false)
    for _,question in ipairs(view.questions) do
        if context.buildingId and context.roomId then
            local key="situation-inquiry:"..question.key..":"..context.buildingId
            local retained=s and purposeByKey(s,key)
            local attempts=retained and retained.inquiry and retained.inquiry.attempts or {}
            local count=0 for _ in pairs(attempts) do count=count+1 end
            if count<12 then
                for _,frontier in ipairs(context.frontiers or {}) do
                    local targetKey=P.conceptFrontierKey(frontier)
                    if not attempts[targetKey] and finite(frontier.entryX) and finite(frontier.entryY) and finite(frontier.entryZ) then
                        return {status="actionable",mode="situation",goal="understanding",subject=question.subject,
                            questionKey=question.key,contextId=context.buildingId,frontier=dataCopy(frontier),
                            appraisal=dataCopy(question,0,10),utility=question.utility,reason=question.reason},view
                    end
                end
            end
        elseif question.subject=="unclassified-sound" and body then
            local located,x,y,z=pcall(function()return body:getX(),body:getY(),body:getZ()end)
            if located and finite(x) and finite(y) and finite(z) then
                for _,heard in ipairs(question.evidence or {}) do
                    if heard.basis=="heard" and type(heard.id)=="string" and #heard.id<=56
                        and finite(heard.x) and finite(heard.y) then
                        local dx,dy=heard.x-x,heard.y-y
                        local length=dx*dx+dy*dy
                        local contextId="exterior:"..heard.id
                        local key="situation-inquiry:"..question.key..":"..contextId
                        local retained=s and purposeByKey(s,key)
                        local attempts=retained and retained.inquiry and retained.inquiry.attempts or {}
                        local count=0 for _ in pairs(attempts) do count=count+1 end
                        if length>1 and count<12 then
                            local best,progress,side
                            local leads={}
                            for _,row in ipairs(context.observations or {}) do leads[#leads+1]=row end
                            for _,row in ipairs(context.approaches or {}) do leads[#leads+1]=row end
                            for _,lead in ipairs(leads) do
                                if lead.actorId==id and lead.at==context.at
                                    and lead.source=="native-personal-visibility"
                                    and (lead.kind=="object" or lead.kind=="visible-ground")
                                    and type(lead.key)=="string" and finite(lead.x) and finite(lead.y)
                                    and lead.z==z then
                                    local ox,oy=lead.x-x,lead.y-y
                                    local advance=ox*dx+oy*dy
                                    local lateral=math.abs(ox*dy-oy*dx)
                                    if ox*ox+oy*oy>1 and advance>0 and advance<=length
                                        and lateral<=advance
                                        and not attempts["remembered:"..lead.key.."@exterior"]
                                        and (not best or advance>progress
                                            or advance==progress and lateral<side
                                            or advance==progress and lateral==side and lead.key<best.key) then
                                        best,progress,side=lead,advance,lateral
                                    end
                                end
                            end
                            if best then
                                return {status="actionable",mode="situation",goal="understanding",
                                    subject=question.subject,questionKey=question.key,contextId=contextId,
                                    observedMeans={key=best.key},approach={roomId="exterior",x=best.x,y=best.y,z=best.z},
                                    appraisal=dataCopy(question,0,10),utility=question.utility,reason=question.reason},view
                            end
                        end
                    end
                end
            end
        end
    end
    return nil,view
end
local function planSituationInquiry(id,body,offer,tick,owner,token)
    local fresh=P.situationInquiryOffer(id,body,tick)
    local target,current=P.conceptInquiryTarget(offer),fresh and P.conceptInquiryTarget(fresh)
    if not fresh or not target or not current or fresh.questionKey~=offer.questionKey
        or target.key~=current.key or target.x~=current.x or target.y~=current.y or target.z~=current.z then return nil end
    local purpose=P.maintain(id,{key="situation-inquiry:"..fresh.questionKey..":"..fresh.contextId,
        domain="inquiry",origin="personal-situation",objective="investigate "..fresh.subject.." from a known approach"})
    if not purpose or purpose.admission or not retainSituation then return nil end
    local prior=purpose.inquiry
    local sequence=prior and prior.sourceSequence or 0
    if not finite(sequence) or sequence<0 or sequence%1~=0
        or sequence>=2147483647
        or not retainSituation(id,body,tick,fresh.questionKey,"selected") then return nil end
    purpose.inquiry={mode="situation",questionKey=fresh.questionKey,goal=fresh.goal,contextId=fresh.contextId,
        subject=fresh.subject,frontier=dataCopy(fresh.frontier),appraisal=dataCopy(fresh.appraisal,0,10),
        attempts=prior and prior.attempts or {},sourceSequence=sequence}
    purpose.rationale=fresh.reason
    purpose.steps={{id="look:"..target.key,verb="investigate",owner=owner,token=token,
        target=target.key,status="available",x=target.x,y=target.y,z=target.z}}
    purpose.cursor,purpose.status=1,"maintained"
    return purpose,purpose.steps[1]
end
function P.planSourceSituationInquiry(id,body,offer,tick)
    local source=SAO.WeekOneContinuity
    local exact,owned,brain=pcall(function()
        if source and source.sourceBodyFor then return source.sourceBodyFor(id) end
    end)
    if not exact or owned~=body or type(brain)~="table" or type(offer)~="table"
        or offer.mode~="situation" or offer.subject~="unclassified-sound"
        or not finite(tick) then return nil end
    local purpose,step=planSituationInquiry(id,body,offer,tick,
        "SAO.WeekOneContinuity","inquiry:observed-native-position")
    if purpose and step then
        local sequence=purpose.inquiry.sourceSequence
        if not finite(sequence) or sequence<0 or sequence%1~=0
            or sequence>=2147483647 then return nil end
        local nextSequence=sequence+1
        if not P.noteAdmission(id,purpose.id,"SAO.WeekOneContinuity",
            "source-inquiry:"..tostring(nextSequence),step.id) then return nil end
        purpose.inquiry.sourceSequence=nextSequence
        purpose.inquiry.sourceSelection={sequence=purpose.inquiry.sourceSequence,
            atTick=tick,targetKey=step.target,
            x=step.x,y=step.y,z=step.z}
    end
    return purpose,step
end
-- The source actuator gives no trustworthy route-completion receipt. Keep a
-- selected attempt in this person's purpose; reconcile either fresh physical
-- position/sight or an explicit unconfirmed interruption, never an inferred
-- sound cause or a BWO task result.
function P.finishSourceSituationInquiry(id,body,purposeId,sequence,result,tick)
    local rec=record(id)
    local phase=rec and rec.weekOne
    local pending=phase and phase.sourceInquiry
    local s=state(id,false)
    local purpose=s and s.purposes[purposeId]
    local inquiry=purpose and purpose.inquiry
    local selection=inquiry and inquiry.sourceSelection
    local step=purpose and purpose.steps and purpose.steps[purpose.cursor]
    local admission=purpose and purpose.admission
    if not pending or pending.purposeId~=purposeId or pending.sequence~=sequence
        or not selection or selection.sequence~=sequence or inquiry.mode~="situation"
        or not step or step.owner~="SAO.WeekOneContinuity"
        or not admission or admission.owner~="SAO.WeekOneContinuity"
        or admission.correlationId~="source-inquiry:"..tostring(sequence)
        or admission.stepId~=step.id or admission.target~=step.target
        or step.target~=selection.targetKey or step.x~=selection.x
        or step.y~=selection.y or step.z~=selection.z
        or not finite(tick) or result=="observed" and tick<selection.atTick
        or (result~="observed" and result~="deadline" and result~="interrupted") then return false end
    if result=="observed" then
        local source=SAO.WeekOneContinuity
        local ok,exact,brain=pcall(function()
            if source and source.sourceBodyFor then return source.sourceBodyFor(id) end
        end)
        if not ok or exact~=body or type(brain)~="table" then return false end
        local located,x,y,z,square=pcall(function()
            local cell=body:getCell()
            return body:getX(),body:getY(),body:getZ(),
                cell and cell:getGridSquare(step.x,step.y,step.z)
        end)
        if not located or not finite(x) or not finite(y) or z~=step.z
            or not square then return false end
        local dx,dy=x-(step.x+.5),y-(step.y+.5)
        if dx*dx+dy*dy>1 then return false end
        local seen,visible=pcall(function()
            return square:getX()==step.x and square:getY()==step.y
                and square:getZ()==step.z and square:getRoom()==nil
                and SAOJavaBridge:weekOneObservedFeature(body,square,"ground")
        end)
        if not seen or visible~=true then return false end
        if not (SAO.Perception and SAO.Perception.conceptObservationReceipt
            and SAO.Perception.conceptObservationReceipt(id,body,tick)) then return false end
        local context=SAO.Perception and SAO.Perception.conceptContext
            and SAO.Perception.conceptContext(id,tick,body)
        if not context or context.status~="observed" or context.at~=tick
            or not retainSituation or not retainSituation(id,body,tick,
                inquiry.questionKey,"observed-after-route") then return false end
    end
    local at=nowHours()
    inquiry.attempts[step.target]={at=at,status=result=="observed"
        and "approached" or "route-unconfirmed"}
    inquiry.sourceSelection=nil
    purpose.lastAdmission=dataCopy(admission)
    purpose.admission=nil
    purpose.status="maintained"
    purpose.blockers={result=="observed" and "cause-not-yet-established"
        or result=="deadline" and "inquiry-deadline" or "inquiry-interrupted"}
    addEvent(purpose,"source-inquiry-observation",result,at)
    return true
end
function P.planConceptInquiry(id,offer,tick,inspectionContext)
    if type(offer)=="table" and offer.mode=="situation" then
        local body=SAO.Body and SAO.Body.get and SAO.Body.get(id)
        return planSituationInquiry(id,body,offer,tick,
            "SAO.Locomotion","inquiry:approached")
    end
    if type(offer)~="table" or offer.status~="actionable" or type(offer.path)~="table" then return nil end
    local fresh=P.conceptInquiryOffer(id,offer.goal,tick)
    local target=P.conceptInquiryTarget(offer)
    local current=fresh and P.conceptInquiryTarget(fresh)
    if not fresh or fresh.status~="actionable" or not target or not current or current.key~=target.key
        or current.x~=target.x or current.y~=target.y or current.z~=target.z
        or fresh.path.id~=offer.path.id then return nil end
    local anchor
    if fresh.mode=="inspect-holder" then
        local body=SAO.Body and SAO.Body.get and SAO.Body.get(id)
        anchor=SAO.WorldSources and SAO.WorldSources.currentInspectionAnchor
            and SAO.WorldSources.currentInspectionAnchor(id,body,inspectionContext)
        if not anchor or anchor.sourceId~=fresh.sourceId or anchor.sourceX~=fresh.observedMeans.x
            or anchor.sourceY~=fresh.observedMeans.y or anchor.sourceZ~=fresh.observedMeans.z then return nil end
    end
    local purpose=P.maintain(id,{key="concept-inquiry:"..offer.goal..":"..offer.contextId,domain="inquiry",origin="personal-expectation",
        objective="look for "..offer.desiredConcept.." as a possible means to "..offer.goal})
    if not purpose or purpose.admission then return nil end
    local prior=purpose.inquiry
    purpose.inquiry={goal=offer.goal,desiredConcept=offer.desiredConcept,contextId=offer.contextId,
        mode=offer.mode,sourceId=offer.sourceId,observedMeans=dataCopy(offer.observedMeans),approach=dataCopy(offer.approach),
        path=dataCopy(offer.path),frontier=dataCopy(offer.frontier),attempts=prior and prior.attempts or {}}
    purpose.rationale=offer.reason
    purpose.steps={{id="look:"..target.key,verb="investigate",owner="SAO.Locomotion",
        token="inquiry:approached",target=target.key,status="available",x=target.x,y=target.y,z=target.z}}
    if anchor then
        purpose.steps={{id="inspect:"..anchor.sourceId..":"..anchor.fingerprint,verb="inspect",owner="SAO.WorldSources",
            token="inquiry:inspected",target=anchor.sourceId,sourceId=anchor.sourceId,fingerprint=anchor.fingerprint,
            sourceX=anchor.sourceX,sourceY=anchor.sourceY,sourceZ=anchor.sourceZ,
            status="available",x=anchor.cx,y=anchor.cy,z=anchor.z}}
    end
    purpose.cursor,purpose.status=1,"maintained"
    return purpose,purpose.steps[1]
end
function P.interruptConceptInquiry(id,reason)
    local s=state(id,false)
    for _,key in ipairs(s and s.order or {}) do
        local purpose=s.purposes[key]
        -- Controller interruption owns its ordinary body routes. A source
        -- proxy's admitted inquiry is reconciled by WeekOneContinuity.
        if purpose and purpose.inquiry and purpose.admission
            and (purpose.admission.owner=="SAO.Locomotion"
                or purpose.admission.owner=="SAO.WorldSources") then
            purpose.admission=nil
            purpose.status="interrupted"
            purpose.blockers={tostring(reason or "interrupted")}
            addEvent(purpose,"inquiry-interrupted",reason,nowHours())
        end
    end
end
-- An interrupted intention may compete again only through current personal
-- evidence. This read grants neither a route nor the sought material.
function P.pendingConceptInquiries(id,tick)
    local rec, s = record(id), state(id,false)
    local out = {}
    if not rec or rec.id ~= id or rec.dead then return out end
    local now = nowHours()
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        if purpose and purpose.domain == "inquiry" and purpose.origin == "personal-expectation"
            and purpose.inquiry and not purpose.admission
            and (purpose.status == "maintained" or purpose.status == "interrupted")
            and finite(purpose.createdAt) and purpose.createdAt <= now then
            local offer = P.conceptInquiryOffer(id,purpose.inquiry.goal,tick)
            if offer and offer.status == "actionable" and offer.contextId == purpose.inquiry.contextId then
                out[#out+1] = {purposeId=purpose.id,offer=offer}
                if #out >= 4 then break end
            end
        end
    end
    return out
end
function P.finishConceptInquiry(id,body,purposeId,routeId,job)
    local s=state(id,false)
    local purpose=s and s.purposes[purposeId]
    local admission=purpose and purpose.admission
    local step=purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.inquiry or not admission or admission.correlationId~=routeId
        or not step or admission.stepId~=step.id or not job or job.body~=body or not job.done
        or not SAO.Locomotion or SAO.Locomotion.jobs[id]~=job or not job.goal
        or job.goal.x~=step.x or job.goal.y~=step.y or job.goal.z~=step.z then return false end
    local at=nowHours()
    purpose.inquiry.attempts[step.target]={at=at,status=job.result=="arrived" and "approached" or "route-blocked"}
    local attempt=purpose.inquiry.attempts[step.target]
    if attempt and purpose.inquiry.frontier then attempt.frontierKey=purpose.inquiry.frontier.key;attempt.fromRoomId=purpose.inquiry.frontier.roomId end
    if purpose.inquiry.mode=="situation" then
        purpose.inquiry.pendingRevision={routeId=routeId,atHours=at,result=job.result}
    end
    purpose.admission=nil
    purpose.status="maintained"
    purpose.blockers={job.result=="arrived" and "desired-means-not-yet-observed" or "inquiry-route-blocked"}
    addEvent(purpose,"inquiry-route-ended",job.result,at)
    -- A route result establishes neither an unseen room nor the desired object.
    return true
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

function P.noteAdmission(id, purposeId, owner, correlationId, stepId, authority)
    local s = state(id)
    local purpose = s and s.purposes[tostring(purposeId or "")]
    if not purpose or purpose.conflict or type(owner) ~= "string" or type(correlationId) ~= "string" then return false end
    if purpose.instrument and authority ~= INSTRUMENT_RESULT then return false end
    if purpose.hobby and authority ~= HOBBY_RESULT then return false end
    local step = purpose.steps[purpose.cursor]
    if purpose.generatorPower and (not step or step.status ~= "available" or step.owner ~= owner
        or step.id ~= stepId or purpose.admission) then return false end
    if purpose.materialWork and (not step or step.status ~= "available" or step.owner ~= owner
        or stepId and stepId ~= step.id or step.verb == "acquire" and stepId ~= step.id
        or purpose.admission) then return false end
    if purpose.resourceCategory and (not step or step.owner ~= owner) then return false end
    if purpose.resourceCategory and step.owner == "SAO.WorldSources" and not step.sourceId then return false end
    if stepId and (not step or step.id ~= stepId or step.owner ~= owner) then return false end
    local noteWork
    if purpose.noteReading then
        noteWork = SAO.Study and SAO.Study.noteWork and SAO.Study.noteWork(id)
        if not noteWork or noteWork.actorId ~= id or noteWork.workId ~= correlationId
            or noteWork.purposeId ~= purposeId or owner ~= "SAONeeds" or noteWork.status ~= "prepared"
            or noteWork.itemId ~= purpose.leisure.itemKey or noteWork.activityKey ~= purpose.leisure.activityKey
            or not step or step.token ~= "note:text-exposed" then return false end
    end
    purpose.admission = { owner = owner, correlationId = correlationId,
        stepId = step and step.id, target = step and step.target, token = step and step.token,
        at = nowHours() }
    if noteWork then
        purpose.admission.note = dataCopy(noteWork)
        purpose.admission.stage = "prepared"
    end
    addEvent(purpose, "admitted", owner .. ":" .. correlationId, purpose.admission.at)
    return true
end

function P.recordResult(id, purposeId, result, authority)
    local s = state(id)
    local purpose = s and s.purposes[tostring(purposeId or "")]
    local step = purpose and purpose.steps[purpose.cursor]
    if purpose and purpose.generatorPower then
        if not step or step.owner == "SAO.SourceUse" and authority ~= RESOURCE_RESULT
            or step.owner == "SAO.Study" and authority ~= GENERATOR_READING_RESULT
            or step.owner == "SAO.Generator" and authority ~= GENERATOR_RESULT
            or step.owner ~= "SAO.SourceUse" and step.owner ~= "SAO.Study" and step.owner ~= "SAO.Generator" then return false end
    end
    if purpose and purpose.leisureAcquisition and not purpose.leisure and authority ~= RESOURCE_RESULT then return false end
    if purpose and purpose.conflict then return false end
    if purpose and purpose.resourceCategory and authority ~= RESOURCE_RESULT then return false end
    if purpose and purpose.windowRepair and (not step or step.owner ~= "SAO.SourceUse") then
        if purpose and purpose.windowRepair and authority ~= WINDOW_REPAIR_RESULT then return false end
    end
    if purpose and purpose.shelterConstruction then
        if not step or step.owner=="SAO.ResourceProduction" and
            (step.token=="resource:shelter-built" and authority~=SHELTER_RESULT
                or step.token=="resource:shelter-used" and authority~=SHELTER_USE_RESULT)
            or step.owner=="SAONeeds" and authority~=SHELTER_RECOVERY_RESULT
            or step.owner~="SAO.ResourceProduction" and step.owner~="SAONeeds" and step.owner~="SAO.SourceUse" then return false end
    end
    if purpose and purpose.bedConstruction then
        if not step or step.owner=="SAO.ResourceProduction" and authority~=BED_RESULT
            or step.owner=="SAONeeds" and authority~=BED_RECOVERY_RESULT
            or step.owner~="SAO.ResourceProduction" and step.owner~="SAONeeds" and step.owner~="SAO.SourceUse" then return false end
    end
    if purpose and purpose.materialWork then
        if not step then return false end
        if step.owner == "SAO.SourceUse" and (step.verb ~= "acquire" or step.token ~= "resource:acquired"
            or authority ~= RESOURCE_RESULT) then return false end
        if step.owner == "SAOBuild" and step.token == "construction:boarded"
            and authority ~= BARRICADE_RESULT then return false end
        if step.owner == "SAO.ResourceProduction" and (step.verb ~= "produce"
            or step.token == "resource:crafted" and authority ~= CRAFT_RESULT
            or step.token == "resource:repaired" and authority ~= REPAIR_RESULT
            or step.token == "resource:bed-built" and authority ~= BED_RESULT
            or step.token == "resource:shelter-built" and authority ~= SHELTER_RESULT
            or step.token == "resource:shelter-used" and authority ~= SHELTER_USE_RESULT
            or step.token ~= "resource:crafted" and step.token ~= "resource:repaired" and step.token ~= "resource:bed-built" and step.token ~= "resource:shelter-built" and step.token ~= "resource:shelter-used") then return false end
    end
    if purpose and purpose.instrument and authority ~= INSTRUMENT_RESULT then return false end
    if purpose and purpose.noteReading and authority ~= NOTE_RESULT then return false end
    if purpose and purpose.hobby and authority ~= HOBBY_RESULT then return false end
    -- Inspection of a conceptual means is consumed only from WorldSources'
    -- canonical private receipt, never a caller-authored completion table.
    if purpose and purpose.inquiry and purpose.inquiry.mode=="inspect-holder" then return false end
    if not purpose or type(result) ~= "table" or type(result.owner) ~= "string"
        or type(result.token) ~= "string"
        or (result.status ~= "completed" and result.status ~= "failed"
            and result.status ~= "interrupted") then return false end
    local receiptKey = result.correlationId and (result.owner .. ":" .. result.correlationId)
    for _, key in ipairs(purpose.resultReceipts or {}) do
        if key == receiptKey then return true end
    end
    if not step or step.owner ~= result.owner or step.token ~= result.token then return false end
    if purpose.materialWork and step.verb ~= "inspect" and not result.correlationId then return false end
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
        if not purpose.instrument and not purpose.noteReading and not purpose.hobby and (step.verb == "practice" or step.verb == "produce"
            or step.verb == "construct" or step.verb == "recreate"
            or step.verb == "socialize") then
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
        if not purpose.instrument and not purpose.noteReading and not purpose.hobby and not purpose.leisureAcquisition then
            local key = tostring(step.target or purpose.domain)
            local practice = s.practice[key] or { completed = 0, failed = 0 }
            practice.failed, practice.lastAt = practice.failed + 1, at
            s.practice[key] = practice
        end
        if (purpose.resourceCategory or purpose.materialWork) and (result.status == "failed"
            or result.routeFailure == true or purpose.materialWork and result.status == "interrupted") then
            resourceFailure(purpose, purpose.selectedStrategy or step.id, result.reason, at, step.id)
        end
    end
    purpose.updatedAt = at
    if receiptKey then
        purpose.resultReceipts = purpose.resultReceipts or {}
        purpose.resultReceipts[#purpose.resultReceipts + 1] = receiptKey
        if #purpose.resultReceipts > MAX_EVENTS then table.remove(purpose.resultReceipts, 1) end
    end
    if purpose.resourceCategory or purpose.materialWork or purpose.windowRepair or purpose.leisure or purpose.leisureAcquisition or purpose.generatorPower then
        purpose.lastAdmission = dataCopy(purpose.admission)
        purpose.admission = nil
    end
    addEvent(purpose, "result", result.status .. ":" .. result.token, at)
    return true
end

function P.consumeNoteOutcome(id, sequence)
    local owner = SAO.Study
    local result = owner and owner.noteOutcome and owner.noteOutcome(id, sequence)
    local s = state(id)
    local purpose = result and s and s.purposes[result.purposeId]
    local admission = purpose and (purpose.admission or purpose.lastAdmission)
    local expected = admission and admission.note
    if not purpose or not purpose.noteReading or not expected or type(result) ~= "table"
        or result.actorId ~= id or result.status ~= "completed" or result.sequence ~= sequence
        or result.nativeOwner ~= "SAONoteReadAction/ISBaseTimedAction" or result.token ~= "note:text-exposed"
        or admission.owner ~= "SAONeeds" or result.workId ~= admission.correlationId
        or result.workId ~= expected.workId or result.sequence ~= expected.sequence
        or result.itemId ~= expected.itemId or result.itemType ~= expected.itemType
        or result.contentBinding ~= expected.contentBinding or result.contentBinding ~= result.workId
        or result.bodyToken ~= expected.bodyToken or result.bodyGenerationKnown ~= expected.bodyGenerationKnown
        or (result.bodyGenerationKnown ~= true and result.bodyGenerationKnown ~= false)
        or result.bodyGenerationKnown and (type(result.bodyToken) ~= "string" or result.bodyToken == "")
        or not result.bodyGenerationKnown and result.bodyToken ~= nil
        or result.beganAt ~= expected.beganAt or not finite(result.beganAt)
        or not finite(result.startedAt) or not finite(result.endedAt) or not finite(result.atHours)
        or result.startedAt < result.beganAt or result.endedAt < result.startedAt
        or result.atHours < result.endedAt or result.atHours < admission.at or result.atHours > nowHours()
        or type(result.content) ~= "table" or type(result.content.pages) ~= "table"
        or result.content.pageCount ~= expected.contentPages or result.content.bytes ~= expected.contentBytes
        or result.content.source ~= "native-Literature.customPages" then return false end
    local bytes = 0
    if not finite(result.content.pageCount) or result.content.pageCount < 1 or result.content.pageCount > 32
        or result.content.pageCount ~= math.floor(result.content.pageCount)
        or #result.content.pages ~= result.content.pageCount then return false end
    for _, text in ipairs(result.content.pages) do
        if type(text) ~= "string" or #text > 16384 then return false end
        bytes = bytes + #text
    end
    if bytes ~= result.content.bytes or bytes > 65536 then return false end
    return P.recordResult(id, purpose.id, { owner = "SAONeeds", token = "note:text-exposed",
        status = "completed", correlationId = result.workId, atHours = result.atHours }, NOTE_RESULT)
end

function P.consumeWindowRepairOutcome(id, sequence)
    local owner = SAO.WindowRepair
    local result = owner and owner.outcome(id, sequence)
    local s = state(id)
    local purpose = result and s and s.purposes[result.purposeId]
    if not result or not purpose or not purpose.windowRepair or result.actorId ~= id
        or result.sequence ~= sequence then return false end
    local admission = purpose.admission or purpose.lastAdmission
    if not admission or admission.owner ~= "SAO.WindowRepair"
        or admission.correlationId ~= result.workId
        or admission.target ~= result.entryKey then return false end
    local receipt = { owner = "SAO.WindowRepair", token = "construction:window-repaired",
        correlationId = result.workId, status = result.status, reason = result.reason,
        atHours = result.endedAt }
    if result.status == "completed" and (result.paneConsumed ~= true or result.smashedBefore ~= true
        or result.smashedAfter ~= false or result.glassRemovedAfter ~= false) then return false end
    for _, key in ipairs(purpose.resultReceipts or {}) do
        if key == "SAO.WindowRepair:" .. tostring(result.workId) then return owner.acknowledge(id, sequence) end
    end
    if not P.recordResult(id, purpose.id, receipt, WINDOW_REPAIR_RESULT) then return false end
    return owner.acknowledge(id, sequence)
end

function P.consumeBarricadeOutcome(id, sequence)
    local owner = SAO.Build
    local result = owner and owner.outcome and owner.outcome(id, sequence)
    local s = state(id)
    local purpose = result and s and s.purposes[result.purposeId]
    local work = purpose and purpose.materialWork
    local admission = purpose and (purpose.admission or purpose.lastAdmission)
    local step = purpose and purpose.steps[purpose.cursor]
    if not result or not work or work.operation ~= "board" or result.actorId ~= id
        or result.sequence ~= sequence or result.nativeOwner ~= "ISBarricadeAction"
        or not admission or admission.owner ~= "SAOBuild" or admission.correlationId ~= result.workId
        or admission.target ~= result.entryKey or work.entryKey ~= result.entryKey
        or not finite(result.endedAt) or result.endedAt < admission.at or result.endedAt > nowHours()
        or result.status ~= "completed" and result.status ~= "failed" and result.status ~= "interrupted" then return false end
    if result.status == "completed" and (result.plankConsumed ~= true or result.nailsConsumed ~= 2
        or result.barricadeChanged ~= true) then return false end
    for _, key in ipairs(purpose.resultReceipts or {}) do
        if key == "SAOBuild:" .. tostring(result.workId) then
            return owner.acknowledge and owner.acknowledge(id, sequence) == true
        end
    end
    if not step or step.owner ~= "SAOBuild" or step.token ~= "construction:boarded"
        or admission.stepId ~= step.id or step.target ~= result.entryKey then return false end
    if not P.recordResult(id, purpose.id, { owner = "SAOBuild", token = "construction:boarded",
        correlationId = result.workId, status = result.status, reason = result.reason,
        atHours = result.endedAt }, BARRICADE_RESULT) then return false end
    return owner.acknowledge and owner.acknowledge(id, sequence) == true
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
    if purpose.materialWork and (authoritative.actorId ~= receipt.actorId
        or authoritative.reservationId ~= receipt.reservationId) then return false end
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
    if purpose.generatorPower and (authoritative.actorId ~= receipt.actorId
        or authoritative.reservationId ~= receipt.reservationId or step.owner ~= "SAO.SourceUse"
        or step.verb ~= "acquire" or step.token ~= "resource:acquired" or admission.owner ~= step.owner
        or step.sourceId ~= authoritative.sourceId or step.sourceRevision ~= authoritative.preRevision
        or step.itemId ~= authoritative.itemId or step.itemType ~= authoritative.itemType
        or step.category ~= authoritative.category or not finite(authoritative.at)
        or authoritative.at < admission.at or authoritative.at > nowHours()) then return false end
    if purpose.materialWork and (step.owner ~= "SAO.SourceUse" or step.verb ~= "acquire"
        or step.token ~= "resource:acquired" or admission.owner ~= "SAO.SourceUse"
        or step.sourceId ~= authoritative.sourceId or step.sourceRevision ~= authoritative.preRevision
        or step.itemId ~= authoritative.itemId or step.itemType ~= authoritative.itemType
        or step.category ~= authoritative.category or not finite(authoritative.at)
        or authoritative.at < admission.at or authoritative.at > nowHours()) then return false end
    if purpose.plumbing and (authoritative.actorId ~= receipt.actorId
        or authoritative.reservationId ~= receipt.reservationId or step.owner ~= "SAO.SourceUse"
        or step.verb ~= "acquire" or step.token ~= "resource:acquired" or admission.owner ~= step.owner
        or step.sourceId ~= authoritative.sourceId or step.sourceRevision ~= authoritative.preRevision
        or step.itemId ~= authoritative.itemId or step.itemType ~= authoritative.itemType
        or step.category ~= authoritative.category or not finite(authoritative.at)
        or authoritative.at < admission.at or authoritative.at > nowHours()) then return false end
    if purpose.collector and (authoritative.actorId ~= receipt.actorId
        or authoritative.reservationId ~= receipt.reservationId or step.owner ~= "SAO.SourceUse"
        or step.verb ~= "acquire" or step.token ~= "resource:acquired" or admission.owner ~= step.owner
        or step.sourceId ~= authoritative.sourceId or step.sourceRevision ~= authoritative.preRevision
        or step.itemId ~= authoritative.itemId or step.itemType ~= authoritative.itemType
        or step.category ~= authoritative.category or not finite(authoritative.at)
        or authoritative.at < admission.at or authoritative.at > nowHours()) then return false end
    if completed and (authoritative.measurement ~= "native-item-transfer"
        or (tonumber(authoritative.observedQuantity) or 0) <= 0) then return false end
    if completed and purpose.resourceCategory and (step.sourceId ~= authoritative.sourceId
        or step.itemId ~= authoritative.itemId or step.category ~= authoritative.category) then return false end
    local acquisition=purpose.leisureAcquisition
    if acquisition then
        if not leisureAcquisitionStep(step) or acquisition.sourceId~=authoritative.sourceId
            or acquisition.itemId~=tostring(authoritative.itemId) or acquisition.itemType~=authoritative.itemType
            or acquisition.revision~=authoritative.preRevision then return false end
    end
    local accepted = P.recordResult(receipt.actorId, purpose.id, {
        owner = "SAO.SourceUse", token = admission.token,
        status = completed and "completed" or "interrupted",
        reason = authoritative.detail, correlationId = authoritative.reservationId,
        routeFailure = authoritative.status == "conflict",
        atHours = authoritative.at,
    }, RESOURCE_RESULT)
    if accepted and acquisition then
        if completed then acquisition.resultId=authoritative.reservationId else acquisition.failedAt=nowHours() end
    end
    return accepted
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
    local concept=purpose and purpose.inquiry and purpose.inquiry.mode=="inspect-holder"
        and purpose.inquiry.sourceId==receipt.sourceId
    if not purpose or not (purpose.resourceCategory or concept) or purpose.status == "completed" or purpose.status == "abandoned"
        or not step or step.status ~= "available" or step.owner ~= "SAO.WorldSources"
        or step.token ~= (concept and "inquiry:inspected" or "resource:inspected") or step.id ~= receipt.purposeStepId
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
    local concept=purpose.inquiry and purpose.inquiry.mode=="inspect-holder"
        and purpose.inquiry.sourceId==canonical.sourceId
    if not step or not admission or step.owner ~= "SAO.WorldSources"
        or step.token ~= (concept and "inquiry:inspected" or "resource:inspected")
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
    if concept then
        if not finite(canonical.atHours) or canonical.atHours<admission.at or canonical.atHours>nowHours() then return false end
        local key="SAO.WorldSources:"..canonical.id
        purpose.resultReceipts=purpose.resultReceipts or {}
        for _,seen in ipairs(purpose.resultReceipts) do if seen==key then return true end end
        purpose.resultReceipts[#purpose.resultReceipts+1]=key
        if #purpose.resultReceipts>MAX_EVENTS then table.remove(purpose.resultReceipts,1) end
        purpose.inquiry.attempts=purpose.inquiry.attempts or {}
        purpose.inquiry.attempts["holder:"..canonical.sourceId]={receiptId=canonical.id,
            at=canonical.atHours,status=canonical.status,fingerprint=canonical.fingerprint}
        purpose.lastAdmission,purpose.admission=dataCopy(admission),nil
        step.status=canonical.status
        purpose.status,purpose.updatedAt="maintained",canonical.atHours
        purpose.blockers={canonical.status=="completed" and "holder-inspected-goal-unfulfilled" or tostring(canonical.reason)}
        addEvent(purpose,"inquiry-inspection-ended",canonical.status,canonical.atHours)
        -- Only knowledge changed. No item was acquired and no personal goal,
        -- practice or material consequence is completed by this receipt.
        return true
    end
    local consumed = P.recordResult(id, purpose.id, { owner = "SAO.WorldSources", token = "resource:inspected",
        status = canonical.status, correlationId = canonical.id, reason = canonical.reason,
        atHours = canonical.atHours }, RESOURCE_RESULT)
    if consumed and canonical.status == "completed" then
        purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "maintained", nil, true
    end
    return consumed
end

function P.admitCraftProduction(id, work)
    if type(work) ~= "table" or type(work.id) ~= "string" or work.actorId ~= id
        or work.kind ~= "saw-logs" or work.recipeId ~= "Base.SawLogs" then return false end
    local s = state(id)
    local purpose = s and s.purposes[work.requestedPurposeId or work.purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.materialWork or purpose.materialWork.operation ~= "board"
        or purpose.status == "completed" or purpose.status == "abandoned" or not step
        or step.id ~= (work.requestedPurposeStepId or work.purposeStepId)
        or step.owner ~= "SAO.ResourceProduction" or step.verb ~= "produce"
        or step.productionKind ~= work.kind or step.recipeId ~= work.recipeId
        or step.token ~= "resource:crafted" or step.status ~= "available"
        or step.logItemId ~= work.logItemId or step.logItemType ~= work.logItemType
        or step.sawItemId ~= work.sawItemId or step.sawItemType ~= work.sawItemType then return false end
    if purpose.admission then return false end
    local admitted = P.noteAdmission(id, purpose.id, step.owner, work.id, step.id)
    if admitted then work.purposeId, work.purposeStepId = purpose.id, step.id end
    return admitted
end

function P.consumeCraftProductionResult(id, receipt)
    if type(receipt) ~= "table" or type(receipt.id) ~= "string" then return false end
    local owner = SAO.ResourceProduction
    local canonical = owner and owner.outcome and owner.outcome(id, receipt.id)
    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id
        or canonical.purposeId ~= receipt.purposeId or canonical.kind ~= "saw-logs"
        or canonical.recipeId ~= "Base.SawLogs" or canonical.token ~= "resource:crafted"
        or canonical.nativeOwner ~= (canonical.kind=="fix-held-item" and "ISFixAction" or "ISHandcraftAction") or not finite(canonical.atHours)
        or canonical.atHours > nowHours() or (canonical.status ~= "completed"
            and canonical.status ~= "interrupted" and canonical.status ~= "failed") then return false end
    local s = state(id)
    local purpose = s and s.purposes[canonical.purposeId]
    if not purpose or purpose.status == "abandoned" then return true, "purpose-retired" end
    local receiptKey = "SAO.ResourceProduction:" .. canonical.id
    for _, seen in ipairs(purpose.resultReceipts or {}) do if seen == receiptKey then return true end end
    local step, admission = purpose.steps[purpose.cursor], purpose.admission
    if not purpose.materialWork or purpose.materialWork.operation ~= "board" or not step or not admission
        or step.owner ~= "SAO.ResourceProduction" or step.token ~= "resource:crafted"
        or step.id ~= canonical.purposeStepId or admission.stepId ~= step.id
        or admission.owner ~= step.owner or admission.correlationId ~= canonical.id
        or admission.target ~= step.target or canonical.atHours < admission.at
        or canonical.recipeId ~= step.recipeId or canonical.kind ~= step.productionKind
        or canonical.logItemId ~= step.logItemId or canonical.logItemType ~= step.logItemType
        or canonical.sawItemId ~= step.sawItemId or canonical.sawItemType ~= step.sawItemType then return false end
    if canonical.status == "completed" then
        if canonical.nativeCredit ~= canonical.id or canonical.nativeAttempted ~= true
            or canonical.logConsumed ~= true or canonical.sawRetained ~= true or canonical.held ~= true
            or canonical.outputCount ~= 3 or type(canonical.outputs) ~= "table" or #canonical.outputs ~= 3 then return false end
        local outputs = {}
        for _, item in ipairs(canonical.outputs) do
            if type(item) ~= "table" or item.itemType ~= "Base.Plank" or type(item.itemId) ~= "string"
                or item.itemId == "" or outputs[item.itemId] then return false end
            outputs[item.itemId] = true
        end
    end
    return P.recordResult(id, purpose.id, { owner = "SAO.ResourceProduction", token = "resource:crafted",
        status = canonical.status, correlationId = canonical.id, reason = canonical.detail,
        atHours = canonical.atHours }, CRAFT_RESULT)
end

function P.admitRepairProduction(id, work)
    if type(work) ~= "table" or type(work.id) ~= "string" or work.actorId ~= id
        or (work.kind ~= "repair-held-item" and work.kind ~= "fix-held-item") then return false end
    local policy = repairPolicy(work.recipeId)
    if not policy or work.category ~= policy.category
        or work.toolCategory and work.toolCategory ~= policy.toolCategory
        or work.effectMetric and work.effectMetric ~= policy.effectMetric then return false end
    local s = state(id)
    local purpose = s and s.purposes[work.requestedPurposeId or work.purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    local material = purpose and purpose.materialWork
    if not material or (material.operation ~= "board" and material.operation ~= "maintain-tool")
        or material.operation == "maintain-tool" and (material.entryKey ~= "held-item:" .. tostring(work.targetItemId)
            or material.targetItemId ~= work.targetItemId or material.targetItemType ~= work.targetItemType)
        or purpose.status == "completed" or purpose.status == "abandoned" or not step or purpose.admission
        or step.id ~= (work.requestedPurposeStepId or work.purposeStepId)
        or step.owner ~= "SAO.ResourceProduction" or step.verb ~= "produce"
        or step.productionKind ~= work.kind or step.recipeId ~= work.recipeId
        or step.category ~= policy.category or step.toolCategory and step.toolCategory ~= policy.toolCategory
        or step.effectMetric and step.effectMetric ~= policy.effectMetric
        or step.token ~= "resource:repaired" or step.status ~= "available"
        or step.targetItemId ~= work.targetItemId or step.targetItemType ~= work.targetItemType
        or step.toolItemId ~= work.toolItemId or step.toolItemType ~= work.toolItemType then return false end
    local admitted = P.noteAdmission(id, purpose.id, step.owner, work.id, step.id)
    if admitted then work.purposeId, work.purposeStepId = purpose.id, step.id end
    return admitted
end

function P.consumeRepairProductionResult(id, receipt)
    if type(receipt) ~= "table" or type(receipt.id) ~= "string" then return false end
    local owner = SAO.ResourceProduction
    local canonical = owner and owner.outcome and owner.outcome(id, receipt.id)
    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id
        or canonical.purposeId ~= receipt.purposeId or (canonical.kind ~= "repair-held-item" and canonical.kind ~= "fix-held-item")
        or canonical.token ~= "resource:repaired"
        or canonical.nativeOwner ~= (canonical.kind=="fix-held-item" and "ISFixAction" or "ISHandcraftAction") or not finite(canonical.atHours)
        or canonical.atHours > nowHours() or (canonical.status ~= "completed"
            and canonical.status ~= "interrupted" and canonical.status ~= "failed") then return false end
    local policy = repairPolicy(canonical.recipeId)
    if not policy or canonical.category ~= policy.category
        or canonical.toolCategory and canonical.toolCategory ~= policy.toolCategory
        or canonical.effectMetric and canonical.effectMetric ~= policy.effectMetric
        or policy.effectMetric == "sharpness" and canonical.effectMetric ~= "sharpness" then return false end
    if canonical.kind=="fix-held-item" and (policy.productionKind~="fix-held-item"
        or canonical.status=="completed" and (not canonical.paymentConsumed or not canonical.returnsMeasured or not canonical.reequipped)) then return false end
    local s = state(id)
    local purpose = s and s.purposes[canonical.purposeId]
    if not purpose or purpose.status == "abandoned" then return true, "purpose-retired" end
    local receiptKey = "SAO.ResourceProduction:" .. canonical.id
    for _, seen in ipairs(purpose.resultReceipts or {}) do if seen == receiptKey then return true end end
    local step, admission = purpose.steps[purpose.cursor], purpose.admission
    local material = purpose.materialWork
    if not material or (material.operation ~= "board" and material.operation ~= "maintain-tool")
        or material.operation == "maintain-tool" and (material.entryKey ~= "held-item:" .. tostring(canonical.targetItemId)
            or material.targetItemId ~= canonical.targetItemId or material.targetItemType ~= canonical.targetItemType)
        or not step or not admission
        or step.owner ~= "SAO.ResourceProduction" or step.token ~= "resource:repaired"
        or step.id ~= canonical.purposeStepId or admission.stepId ~= step.id
        or admission.owner ~= step.owner or admission.correlationId ~= canonical.id
        or admission.target ~= step.target or canonical.atHours < admission.at
        or canonical.recipeId ~= step.recipeId or canonical.kind ~= step.productionKind
        or step.category ~= policy.category or step.toolCategory and step.toolCategory ~= policy.toolCategory
        or step.effectMetric and step.effectMetric ~= policy.effectMetric
        or canonical.targetItemId ~= step.targetItemId or canonical.targetItemType ~= step.targetItemType
        or canonical.toolItemId ~= step.toolItemId or canonical.toolItemType ~= step.toolItemType then return false end
    local before, after, maximum = canonical.beforeCondition, canonical.afterCondition, canonical.maxCondition
    if policy.effectMetric == "sharpness" then
        before, after, maximum = canonical.beforeSharpness, canonical.afterSharpness, canonical.maxSharpness
    end
    if canonical.status == "completed" and (canonical.nativeCredit ~= canonical.id
        or canonical.nativeAttempted ~= true or canonical.nativeCompleted ~= true
        or canonical.targetRetained ~= true or canonical.held ~= true or canonical.improved ~= true
        or not finite(before) or not finite(after) or not finite(maximum) or before < 0
        or policy.effectMetric == "condition" and before <= 0
        or after <= before or after > maximum) then return false end
    return P.recordResult(id, purpose.id, { owner = "SAO.ResourceProduction", token = "resource:repaired",
        status = canonical.status, correlationId = canonical.id, reason = canonical.detail,
        atHours = canonical.atHours }, REPAIR_RESULT)
end

local function collectorAttempt(step, work)
    if not collectorSame(step, work) or not P.collectorReady(step) or not P.collectorReady(work)
        or work.sourceX ~= step.sourceX or work.sourceY ~= step.sourceY or work.sourceZ ~= step.sourceZ
        or collectorSite(work).observedAtHours ~= step.site.observedAtHours or #work.requirements ~= #step.requirements then return false end
    local slots, selected = {}, {}
    for _, required in ipairs(step.requirements) do slots[required.inputIndex] = required end
    for _, required in ipairs(work.requirements) do
        local expected = slots[required.inputIndex]
        if not expected or expected.mode ~= required.mode or expected.count ~= required.count
            or expected.category ~= required.category then return false end
    end
    for _, input in ipairs(step.inputs) do selected[tostring(input.itemId)] = input end
    for _, input in ipairs(work.inputs) do
        local expected = selected[tostring(input.itemId)]
        if not expected or expected.inputIndex ~= input.inputIndex or expected.mode ~= input.mode
            or expected.itemType ~= input.itemType then return false end
    end
    return true
end

function P.admitProduction(id, work)
    if type(work) ~= "table" or type(work.id) ~= "string" or work.actorId ~= id
        or work.kind ~= "refill-water" and work.kind ~= "plumb-fixture" and work.kind ~= "build-rain-collector" then return false end
    local plumbing = work.kind == "plumb-fixture"
    local collector = work.kind == "build-rain-collector"
    local s = state(id)
    local purposeId = work.requestedPurposeId or work.purposeId
    local stepId = work.requestedPurposeStepId or work.purposeStepId
    local purpose = s and s.purposes[purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or purpose.status == "completed" or purpose.status == "abandoned"
        or purpose.resourceCategory ~= "water" or not step
        or step.id ~= stepId or step.owner ~= "SAO.ResourceProduction"
        or step.productionKind ~= work.kind or step.token ~= (collector and "resource:collector-built" or plumbing and "resource:plumbed" or "resource:filled")
        or step.itemId ~= work.itemId or step.itemType ~= work.itemType
        or step.sourceId ~= work.sourceId or step.sourceRevision ~= work.sourceRevision
        or step.fingerprint ~= work.fingerprint then return false end
    if plumbing and (not purpose.plumbing or step.toolCategory ~= "pipe-wrench" or work.toolCategory ~= step.toolCategory
        or not plumbingTool(work) or tostring(work.toolItemId) ~= step.toolItemId
        or work.toolItemType ~= step.toolItemType or work.sourceX ~= step.sourceX
        or work.sourceY ~= step.sourceY or work.sourceZ ~= step.sourceZ) then return false end
    if collector and (not purpose.collector or not collectorAttempt(step, work)) then return false end
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
    local plumbing = canonical and canonical.kind == "plumb-fixture"
    local collector = canonical and canonical.kind == "build-rain-collector"
    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id
        or canonical.purposeId ~= receipt.purposeId or canonical.kind ~= "refill-water" and not plumbing and not collector
        or canonical.token ~= (collector and "resource:collector-built" or plumbing and "resource:plumbed" or "resource:filled")
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
    if plumbing and (not purpose.plumbing or step.toolCategory ~= "pipe-wrench" or canonical.toolCategory ~= step.toolCategory
        or tostring(canonical.toolItemId) ~= step.toolItemId or canonical.toolItemType ~= step.toolItemType
        or canonical.sourceX ~= step.sourceX or canonical.sourceY ~= step.sourceY
        or canonical.sourceZ ~= step.sourceZ or not finite(canonical.atHours)
        or canonical.atHours < admission.at or canonical.atHours > nowHours()) then return false end
    if collector and (not purpose.collector or not collectorAttempt(step, canonical)
        or not finite(canonical.atHours) or canonical.atHours < admission.at
        or canonical.atHours > nowHours()) then return false end
    if completed and plumbing and (canonical.nativeCredit ~= canonical.id or canonical.nativeOwner ~= "ISPlumbItem"
        or canonical.nativeAttempted ~= true or canonical.nativeCompleted ~= true or canonical.toolRetained ~= true
        or canonical.connected ~= true or canonical.beforeUsesExternalWaterSource ~= false
        or canonical.afterUsesExternalWaterSource ~= true or type(canonical.beforeCanBeWaterPiped) ~= "boolean"
        or canonical.beforePlumbingEligible ~= true
        or canonical.afterCanBeWaterPiped ~= false) then return false end
    if completed and collector and (canonical.nativeCredit ~= canonical.id or canonical.nativeOwner ~= "ISBuildAction"
        or canonical.nativeAttempted ~= true or canonical.nativeCompleted ~= true or canonical.constructed ~= true
        or canonical.placed ~= true or canonical.exactInputs ~= true or canonical.inputsConsumed ~= true
        or canonical.toolRetained ~= true or canonical.beforeCollectorAmount ~= 0
        or not finite(canonical.collectorCapacity) or canonical.collectorCapacity <= 0
        or not finite(canonical.afterCollectorAmount) or canonical.afterCollectorAmount < 0
        or canonical.afterCollectorAmount > canonical.collectorCapacity) then return false end
    if completed and not plumbing and not collector and (not (canonical.nativeCredit == canonical.id) or canonical.held ~= true
        or canonical.clean ~= true or not finite(canonical.nativeGain) or canonical.nativeGain <= 0
        or not finite(canonical.beforeAmount) or not finite(canonical.afterAmount)
        or canonical.afterAmount <= canonical.beforeAmount) then return false end
    local consumed = P.recordResult(id, purpose.id, { owner = "SAO.ResourceProduction", token = step.token,
        status = completed and "completed" or canonical.status == "interrupted" and "interrupted" or "failed",
        correlationId = canonical.id, reason = canonical.detail, atHours = canonical.atHours }, RESOURCE_RESULT)
    if consumed and completed and plumbing then
        purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "maintained", nil, true
        purpose.plumbing.connectedWorkId, purpose.plumbing.connectedAt = canonical.id, canonical.atHours
    end
    if consumed and completed and collector then
        purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "maintained", nil, true
        purpose.collector.constructedWorkId, purpose.collector.constructedAt = canonical.id, canonical.atHours
        purpose.collector.collectorSourceId, purpose.collector.collectorFingerprint = canonical.collectorSourceId, canonical.collectorFingerprint
    end
    return consumed
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
        suspendedLeisure = { purposes = {}, omitted = s.suspendedLeisure and s.suspendedLeisure.omitted or 0 },
        queuedPurposes = {},
        study = SAO.Study and SAO.Study.snapshot and SAO.Study.snapshot(id) or nil,
        practiceDomains = 0 }
    local queued = s.queuedPurposes
    for _, purposeId in ipairs(queued and queued.order or {}) do
        local purpose = queued.purposes[purposeId]
        out.queuedPurposes[#out.queuedPurposes + 1] = { id = purpose.id, key = purpose.key,
            status = purpose.status, suspendedStatus = purpose.suspendedStatus,
            reason = purpose.suspensionReason, suspendedAt = purpose.suspendedAt,
            domain = purpose.domain, objective = purpose.objective,
            revision = purpose.revision, resourceOutcome = dataCopy(purpose.resourceOutcome),
            steps = dataCopy(purpose.steps), resultReceipts = copyList(purpose.resultReceipts),
            lastAdmission = dataCopy(purpose.lastAdmission) }
    end
    local suspended = s.suspendedLeisure
    for _, purposeId in ipairs(suspended and suspended.order or {}) do
        local purpose = suspended.purposes[purposeId]
        out.suspendedLeisure.purposes[#out.suspendedLeisure.purposes + 1] = {
            id = purpose.id, key = purpose.key, status = purpose.status,
            activity = purpose.leisure.activity, itemKey = purpose.leisure.itemKey,
            suspendedAt = purpose.suspendedAt, reason = purpose.suspensionReason,
            steps = dataCopy(purpose.steps), resultReceipts = copyList(purpose.resultReceipts),
            lastAdmission = dataCopy(purpose.lastAdmission) }
    end
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
                interpretations = dataCopy(purpose.interpretations, 0, 8),
                resourceCategory = purpose.resourceCategory, demand = dataCopy(purpose.demand),
                origin = purpose.origin, authority = purpose.authority,
                resourceOutcome = dataCopy(purpose.resourceOutcome), outcomeProgress = dataCopy(purpose.outcomeProgress),
                resolution = purpose.resolution, resolvedAt = purpose.resolvedAt,
                contacts = copyList(purpose.contacts, 16), capacity = dataCopy(purpose.capacity),
                labor = dataCopy(purpose.labor), selectedStrategy = purpose.selectedStrategy,
                rationale = purpose.rationale, uncertainty = purpose.uncertainty,
                appraisal = dataCopy(purpose.appraisal),
                inquiry = dataCopy(purpose.inquiry),
                generatorPower = dataCopy(purpose.generatorPower),
                shelterConstruction=dataCopy(purpose.shelterConstruction),
                decisionAt = purpose.decisionAt, assessedAt = purpose.assessedAt,
                sequence = dataCopy(purpose.steps), completedSteps = dataCopy(purpose.completedSteps),
                alternatives = dataCopy(purpose.alternatives), omittedAlternatives = purpose.omittedAlternatives or 0,
                routeFailures = dataCopy(purpose.routeFailures) }
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

-- One maintained conflict purpose survives individual attempts. Refusal is
-- different from admission, and completing an attempt does not prove that a
-- threat was defeated or that another person agreed.
local CONFLICT_ROUTE_MEMORY = 0.05 -- bounded engineering retry policy, not empirical calibration
local CONFLICT_ATTEMPT_HORIZON = 2
local CONFLICT_OWNERS={withdraw="Locomotion",reposition="Locomotion",engage="SAO.Combat",
    defend="SAO.Combat",communicate="SAO.Communication",coordinate="SAO.Coordination",concede="Handover",watch="Posture"}
local function conflictText(value,maximum)
    return type(value)=="string" and #value>0 and #value<=maximum
end

local function hobbyOwner(name)
    if name==nil or name=="SAO.Leisure" then return SAO.Leisure,"SAO.Leisure" end
    if name=="SAO.LeisureExercise" then return SAO.LeisureExercise,name end
    if name=="SAO.LeisureArt" then return SAO.LeisureArt,name end
    if name=="SAO.LeisureMusic" then return SAO.LeisureMusic,name end
    if name=="SAO.LeisureGames" then return SAO.LeisureGames,name end
    if name=="SAO.LeisureRadio" then return SAO.LeisureRadio,name end
    if name=="SAO.LeisureLifestyle" then return SAO.LeisureLifestyle,name end
end
function P.leisurePreparationPurpose(id,purposeId,ownerName,activityKey,activity,sourceId,itemKey)
    local owner=hobbyOwner(ownerName)
    local s=state(id);local purpose=s and s.purposes[purposeId]
    if not owner or not purpose or purpose.status~="maintained" or purpose.admission or not purpose.leisure
        or purpose.leisure.activityKey~=activityKey or purpose.leisure.activity~=activity
        or purpose.leisure.itemKey~=itemKey or purpose.affordance~=sourceId then return nil end
    for _,step in ipairs(purpose.steps or {}) do
        if step.id=="perform-activity" and step.owner==ownerName and step.target==activity
            and step.token=="leisure:performed" and (step.status=="available" or step.status=="dependent") then
            return {actorId=id,purposeId=purposeId,ownerName=ownerName,activityKey=activityKey,
                activity=activity,sourceId=sourceId,itemKey=itemKey,revision=purpose.revision}
        end
    end
end
function P.admitHobbyWork(id,purposeId,sequence,ownerName)
    local owner,name=hobbyOwner(ownerName)
    local work=owner and owner.work and owner.work(id)
    local s=state(id)
    local purpose=s and s.purposes[purposeId]
    local step=purpose and purpose.steps[purpose.cursor]
    local now=nowHours()
    if not owner or not purpose or purpose.status~="maintained" or not purpose.leisure or not step or step.owner~=name
        or step.id~="perform-activity" or step.token~="leisure:performed" or type(work)~="table"
        or work.actorId~=id or work.purposeId~=purposeId or work.sequence~=sequence
        or not finite(sequence) or sequence<1 or sequence~=math.floor(sequence)
        or not conflictText(work.workId,160) or not conflictText(work.family,96)
        or not conflictText(work.sourceId,160) or not conflictText(work.revision,160)
        or not conflictText(work.nativeOwner,160) or work.activity~=purpose.leisure.activity
        or work.sourceId~=purpose.affordance or work.itemKey~=purpose.leisure.itemKey
        or (work.status~="prepared" and work.status~="active")
        or type(work.bodyGenerationKnown)~="boolean"
        or work.bodyGenerationKnown and not conflictText(work.bodyToken,160)
        or not work.bodyGenerationKnown and work.bodyToken~=nil
        or not finite(work.admittedAtHours) or work.admittedAtHours<0 or work.admittedAtHours>now then return false end
    if purpose.admission then return purpose.admission.owner==name and purpose.admission.correlationId==work.workId end
    purpose.hobby={owner=name,family=work.family,sourceId=work.sourceId,revision=work.revision,
        activity=work.activity,itemKey=work.itemKey,itemType=work.itemType,nativeOwner=work.nativeOwner}
    if not P.noteAdmission(id,purposeId,name,work.workId,step.id,HOBBY_RESULT) then return false end
    purpose.admission.hobby=dataCopy(work)
    return true
end
function P.consumeHobbyOutcome(id,sequence,ownerName)
    local owner,name=hobbyOwner(ownerName)
    local result=owner and owner.outcome and owner.outcome(id,sequence)
    local s=state(id)
    local purpose=type(result)=="table" and s and s.purposes[result.purposeId]
    local admission=purpose and (purpose.admission or purpose.lastAdmission)
    local work=admission and admission.hobby
    if not purpose or not purpose.hobby or purpose.hobby.owner~=name or type(work)~="table"
        or result.actorId~=id or result.sequence~=sequence or result.workId~=admission.correlationId
        or admission.owner~=name or not finite(result.atHours) or result.atHours>nowHours()
        or result.atHours<work.admittedAtHours
        or (result.status~="completed" and result.status~="interrupted") then return false end
    for _,key in ipairs({"actorId","sequence","workId","purposeId","family","sourceId","revision",
        "activity","itemKey","itemType","bodyGenerationKnown","bodyToken","admittedAtHours","nativeOwner"}) do
        if result[key]~=work[key] then return false end
    end
    if type(result.nativeProgress)~="table" then return false end
    local alreadyConsumed=false
    for _,key in ipairs(purpose.resultReceipts or {}) do
        if key==name..":"..result.workId then alreadyConsumed=true;break end
    end
    if not alreadyConsumed and (purpose.status~="maintained" or purpose.admission~=admission) then return false end
    local consumed=P.recordResult(id,purpose.id,{owner=name,token="leisure:performed",
        status=result.status,correlationId=result.workId,atHours=result.atHours,
        reason=result.status=="interrupted" and result.reason or nil},HOBBY_RESULT)
    if consumed and result.status=="completed" and not purpose.participation then
        local optional=purpose.steps[purpose.cursor]
        if optional and optional.id=="share-activity" and optional.required==false then
            optional.status="not-required"
            purpose.cursor=purpose.cursor+1
            purpose.status=purpose.cursor>#purpose.steps and "completed" or purpose.status
        end
    end
    if consumed and SAO.Cognition and SAO.Cognition.hobbyOutcome then
        SAO.Cognition.hobbyOutcome(id,name,sequence)
    end
    return consumed
end
function P.hobbyAdmission(id,purposeId,workId,terminal)
    local s=state(id)
    local purpose=s and s.purposes[purposeId]
    local admission=purpose and purpose.hobby and (purpose.admission or terminal and purpose.lastAdmission)
    if not admission or admission.correlationId~=workId then return nil end
    if terminal then
        local consumed=false
        for _,key in ipairs(purpose.resultReceipts or {}) do
            if key==purpose.hobby.owner..":"..workId then consumed=true;break end
        end
        if not consumed then return nil end
    end
    local step=purpose.steps[purpose.cursor]
    if not terminal and (purpose.status~="maintained" or not step or step.id~="perform-activity"
        or step.owner~=purpose.hobby.owner or step.token~="leisure:performed") then return nil end
    local out=dataCopy(admission.hobby)
    out.ownerName=purpose.hobby.owner
    return out
end

function P.admitInstrument(id, purposeId, workId)
    local owner = SAO.Gesture
    local work = owner and owner.instrumentWork and owner.instrumentWork(id)
    local s = state(id)
    local purpose = s and s.purposes[purposeId]
    local step = purpose and purpose.steps[purpose.cursor]
    if not purpose or not purpose.instrument or not step or step.id ~= "perform-activity"
        or step.owner ~= "SAO.Gesture" or type(work) ~= "table" or work.actorId ~= id
        or work.workId ~= workId or work.sequence ~= purpose.instrument.expectedSequence
        or work.workId ~= "instrument:" .. id .. ":" .. tostring(work.sequence)
        or work.itemId ~= purpose.instrument.itemKey
        or work.itemType ~= purpose.instrument.itemType or work.verb ~= purpose.instrument.verb
        or (work.status ~= "prepared" and work.status ~= "admitted" and work.status ~= "started")
        or (work.bodyGenerationKnown ~= true and work.bodyGenerationKnown ~= false)
        or (work.bodyGenerationKnown == true and type(work.bodyToken) ~= "string")
        or (work.bodyGenerationKnown == false and work.bodyToken ~= nil)
        or not finite(work.admittedAtHours) or work.admittedAtHours > nowHours() then return false end
    if purpose.admission then return purpose.admission.correlationId == workId end
    if purpose.participation and not (SAO.Organization and SAO.Organization.admitParticipation
        and SAO.Organization.admitParticipation(purpose.participation.processId, id, purposeId, workId)) then return false end
    if not P.noteAdmission(id, purposeId, "SAO.Gesture", workId, step.id, INSTRUMENT_RESULT) then return false end
    purpose.admission.bodyToken = work.bodyToken
    purpose.admission.bodyGenerationKnown = work.bodyGenerationKnown
    purpose.admission.itemId, purpose.admission.itemType = work.itemId, work.itemType
    purpose.admission.nativeAdmittedAt = work.admittedAtHours
    purpose.admission.sequence = work.sequence
    purpose.admission.stage = work.status -- prepared binds intent before native add/start

    return true
end

function P.consumeInstrumentOutcome(id, sequenceOrWorkId)
    local owner = SAO.Gesture
    local result = owner and owner.instrumentOutcome and owner.instrumentOutcome(id, sequenceOrWorkId)
    local s = state(id)
    if not s or type(result) ~= "table" or result.actorId ~= id
        or type(result.workId) ~= "string" or not finite(result.atHours) or result.atHours > nowHours()
        or (result.status ~= "completed" and result.status ~= "interrupted") then return false end
    for _, purposeId in ipairs(s.order) do
        local purpose = s.purposes[purposeId]
        local admission = purpose and (purpose.admission or purpose.lastAdmission)
        if purpose and purpose.instrument and admission and admission.owner == "SAO.Gesture"
            and admission.correlationId == result.workId then
            if result.sequence ~= admission.sequence or result.itemId ~= admission.itemId or result.itemType ~= admission.itemType
                or result.verb ~= purpose.instrument.verb or result.bodyToken ~= admission.bodyToken
                or result.bodyGenerationKnown ~= admission.bodyGenerationKnown
                or result.admittedAtHours ~= admission.nativeAdmittedAt
                or result.atHours < admission.at then return false end
            if result.status == "completed" and (result.queueAdmitted ~= true
                or result.soundEmitted ~= true or result.worldSoundEmitted ~= true
                or result.soundEnded ~= true or not finite(result.startedAtHours)
                or not finite(result.endedAtHours) or result.startedAtHours < admission.nativeAdmittedAt
                or result.endedAtHours < result.startedAtHours or result.endedAtHours > result.atHours) then return false end
            local consumed = P.recordResult(id, purposeId, { owner = "SAO.Gesture", token = "leisure:performed",
                correlationId = result.workId, status = result.status, atHours = result.atHours,
                reason = result.status == "interrupted" and "native-instrument-interrupted" or nil }, INSTRUMENT_RESULT)
            if consumed and purpose.participation then
                purpose.participation.physicalResult = { workId = result.workId, status = result.status, atHours = result.atHours }
                SAO.Organization.consumeParticipationPerformance(purpose.participation.processId, id, result.workId)
            end
            return consumed
        end
    end
    return false
end
-- Called only by the runtime adoption boundary after establishing that its
-- former native owner is absent. Missing execution cannot become completion.
function P.reconcileInstrument(id, reason)
    local owner = SAO.Gesture
    if not owner or not owner.instrumentWork or owner.instrumentWork(id) then return false end
    local s, changed = state(id), false
    for _, key in ipairs(s and s.order or {}) do
        local purpose = s.purposes[key]
        local admission = purpose and purpose.instrument and purpose.admission
        if admission and admission.owner == "SAO.Gesture" and finite(admission.at) and admission.at <= nowHours() then
            if not P.consumeInstrumentOutcome(id, admission.correlationId) then
                purpose.lastAdmission, purpose.admission = dataCopy(admission), nil
                P.interrupt(id, purpose.id, reason or "instrument-runtime-unavailable", nowHours())
                addEvent(purpose, "instrument-unobservable", admission.correlationId, nowHours())
                if purpose.participation then
                    purpose.participation.physicalResult = { workId = admission.correlationId,
                        status = "unobservable", atHours = nowHours() }
                    SAO.Organization.reconcileParticipation(purpose.participation.processId, id, purpose.id)
                end
            end
            changed = true
        end
    end
    return changed
end

-- Study has already retained its own terminal before handing planning back.
-- A refused retry therefore cannot inherit an earlier action's admission.
function P.releaseStudy(id, purposeId, workId)
    local person, s = record(id), state(id)
    local work = person and person.studyWork
    local purpose = s and s.purposes[purposeId]
    local admission = purpose and purpose.admission
    if not work or work.id ~= workId or work.purposeId ~= purposeId or work.status ~= "interrupted"
        or not finite(work.endedAt) or work.endedAt > nowHours() or not admission
        or admission.owner ~= "SAONeeds" or admission.correlationId ~= workId then return false end
    purpose.lastAdmission, purpose.admission = dataCopy(admission), nil
    return true
end

local function conflictPurpose(id,purposeId,allowDead)
    local s,rec=state(id,false),record(id)
    local key = s and (purposeId or s.conflictPurposeId)
    local purpose=s and (s.purposes[key] or s.queuedPurposes and s.queuedPurposes.purposes[key])
    if rec and (allowDead or not rec.dead) and purpose and purpose.conflict then return purpose,s end
end
function P.conflictRouteBlocked(id,routeKey,atHours)
    local at=atHours or nowHours()
    if not conflictText(routeKey,128) or not finite(at) or at<0 or at>nowHours() then return false end
    local s=state(id,false)
    for _,failure in ipairs(s and s.conflictRouteFailures or {}) do
        if failure.routeKey==routeKey and failure.atHours<=at and at-failure.atHours<CONFLICT_ROUTE_MEMORY then return true end
    end
    return false
end
local function conflictFailure(s,routeKey,reason,at)
    if not routeKey then return end
    s.conflictRouteFailures=s.conflictRouteFailures or {}
    for i=#s.conflictRouteFailures,1,-1 do
        if s.conflictRouteFailures[i].routeKey==routeKey then table.remove(s.conflictRouteFailures,i) end
    end
    s.conflictRouteFailures[#s.conflictRouteFailures+1]={routeKey=routeKey,reason=reason,atHours=at,
        expiresAtHours=at+CONFLICT_ROUTE_MEMORY,basis="native-refusal-or-failed-attempt",
        expiryPolicy="bounded-engineering-retry"}
    if #s.conflictRouteFailures>8 then table.remove(s.conflictRouteFailures,1) end
end
local function sameConflictOffer(a,b)
    return a.id==b.id and a.kind==b.kind and a.routeKey==b.routeKey
        and a.targetKey==b.targetKey and a.nativeMode==b.nativeMode
end
local function conflictOfferFailure(s,offer,reason,at)
    s.conflictOfferFailures=s.conflictOfferFailures or {}
    local row={id=offer.id,kind=offer.kind,routeKey=offer.routeKey,targetKey=offer.targetKey,
        nativeMode=offer.nativeMode,reason=reason,atHours=at}
    s.conflictOfferFailures[#s.conflictOfferFailures+1]=row
    if #s.conflictOfferFailures>16 then table.remove(s.conflictOfferFailures,1) end
end
function P.planConflict(id,frame,offers)
    if not SAO.Cognition or not SAO.Cognition.appraiseConflict then return nil,"conflict-appraisal-unavailable" end
    -- Validate the supplied data before the planner copies it into retention.
    local initial,why=SAO.Cognition.appraiseConflict(id,frame,offers)
    if not initial then return nil,why end
    local old,s=conflictPurpose(id)
    if old and frame.atHours<old.updatedAt then return nil,"old-conflict-frame" end
    local ownFrame,offered=dataCopy(frame,0,12),dataCopy(offers,0,12)
    ownFrame.priorAction=nil
    if old and not old.conflict.needsReappraisal and old.conflict.appraisal.selected then
        ownFrame.priorAction={id=old.conflict.appraisal.selected,kind=old.conflict.appraisal.kind,
            evidenceKey=old.conflict.appraisal.evidenceKey}
    end
    for _,offer in ipairs(offered) do
        if offer.routeKey and P.conflictRouteBlocked(id,offer.routeKey,frame.atHours) then
            offer.available=false
            offer.reason="This exact route was recently refused or failed; it needs changed conditions or a later retry."
        end
        for _,failed in ipairs(s and s.conflictOfferFailures or {}) do
            if sameConflictOffer(offer,failed) and failed.atHours<=frame.atHours
                and frame.atHours-failed.atHours<CONFLICT_ROUTE_MEMORY then
                offer.available=false;offer.reason="This exact attempt was recently refused or failed; I need another feasible response."
            end
        end
    end
    local appraisal=SAO.Cognition.appraiseConflict(id,ownFrame,offered)
    if not appraisal then return nil,"conflict-appraisal-refused" end
    if old and not s.purposes[old.id] and appraisal.kind ~= "watch" then
        local resumed, why = P.resumeQueuedPurpose(id, old.id)
        if not resumed then return nil, why or "conflict-native-handback-required" end
        old = resumed
    end
    local purpose=old or P.maintain(id,{key="conflict:current",objective="Respond to believed danger without assuming an outcome",
        domain="conflict",origin="private-threat-appraisal",atHours=frame.atHours})
    if not purpose then
        local executable = false
        for _, offer in ipairs(offered) do
            if offer.id == appraisal.selected and offer.available == true and offer.kind ~= "watch" then executable = true end
        end
        if not executable then return nil, "conflict-purpose-capacity" end
        local queued, reason = queueForConflict(state(id,false), frame.atHours)
        if not queued then return nil, reason end
        purpose = P.maintain(id, {key="conflict:current",objective="Respond to believed danger without assuming an outcome",
            domain="conflict",origin="private-threat-appraisal",atHours=frame.atHours})
        if not purpose then return nil, "conflict-purpose-capacity" end
    end
    s=state(id,false);s.conflictPurposeId=purpose.id
    purpose.conflict=purpose.conflict or {receipts={}}
    local conflict=purpose.conflict
    conflict.revision=(conflict.revision or 0)+1
    appraisal.frameId=appraisal.frameId.."/"..tostring(conflict.revision)
    conflict.appraisal=dataCopy(appraisal,0,12)
    conflict.threat=dataCopy(frame.threat)
    conflict.offers=offered
    conflict.needsReappraisal=false
    purpose.updatedAt,purpose.status=frame.atHours,s.purposes[purpose.id] and "maintained" or "suspended"
    purpose.rationale=appraisal.reason
    return {selected=appraisal.selected,kind=appraisal.kind,reason=appraisal.reason,
        purposeId=purpose.id,frameId=appraisal.frameId,continuing=appraisal.continuing}
end
local function conflictOffer(purpose,offerId)
    local conflict=purpose and purpose.conflict
    if not conflict or conflict.appraisal.selected~=offerId then return nil end
    for _,offer in ipairs(conflict.offers or {}) do
        if offer.id==offerId and offer.available then return offer end
    end
end
function P.conflictAdmission(id,purposeId,token,offerId)
    local purpose=conflictPurpose(id,purposeId)
    local offer=conflictOffer(purpose,offerId)
    local at=nowHours()
    if not offer or state(id).purposes[purpose.id] ~= purpose or type(token)~="table" or token.owner~=CONFLICT_OWNERS[offer.kind]
        or not conflictText(token.id,128) or at<purpose.updatedAt
        or at-purpose.updatedAt>CONFLICT_ROUTE_MEMORY or purpose.admission then return false end
    for _,receipt in ipairs(purpose.conflict.receipts) do
        if receipt.owner==token.owner and receipt.id==token.id then return false end
    end
    purpose.admission={owner=token.owner,correlationId=token.id,offerId=offerId,kind=offer.kind,
        frameId=purpose.conflict.appraisal.frameId,routeKey=offer.routeKey,targetKey=offer.targetKey,nativeMode=offer.nativeMode,at=at}
    purpose.conflict.needsReappraisal=false
    addEvent(purpose,"conflict-admitted",token.owner..":"..token.id,at)
    return true
end
function P.conflictResult(id,purposeId,token,result)
    local purpose,s=conflictPurpose(id,purposeId,true)
    local admission=purpose and purpose.admission
    local at=nowHours()
    if not admission or type(token)~="table" or token.owner~=admission.owner
        or token.id~=admission.correlationId or type(result)~="table"
        or (result.status~="failed" and result.status~="completed" and result.status~="cancelled")
        or not conflictText(result.reason,256) or result.routeKey~=nil and result.routeKey~=admission.routeKey
        or at<admission.at or at-admission.at>CONFLICT_ATTEMPT_HORIZON and result.status~="cancelled" then return false end
    local conflict=purpose.conflict
    conflict.lastOutcome={status=result.status,reason=result.reason,offerId=admission.offerId,kind=admission.kind,
        routeKey=admission.routeKey,atHours=at,admitted=true,owner=token.owner,id=token.id}
    conflict.receipts[#conflict.receipts+1]={owner=token.owner,id=token.id,status=result.status,atHours=at}
    if #conflict.receipts>16 then table.remove(conflict.receipts,1) end
    if result.status=="failed" then
        conflictFailure(s,admission.routeKey,result.reason,at)
        conflictOfferFailure(s,{id=admission.offerId,kind=admission.kind,routeKey=admission.routeKey,
            targetKey=admission.targetKey,nativeMode=admission.nativeMode},result.reason,at)
    end
    purpose.admission=nil
    conflict.needsReappraisal=true
    addEvent(purpose,"conflict-attempt-"..result.status,result.reason,at)
    return true
end
function P.conflictRefusal(id,purposeId,offerId,result)
    local purpose,s=conflictPurpose(id,purposeId)
    local offer=conflictOffer(purpose,offerId)
    local at=nowHours()
    if not offer or purpose.admission or type(result)~="table"
        or result.frameId~=purpose.conflict.appraisal.frameId
        or not conflictText(result.reason,256) or result.routeKey~=nil and result.routeKey~=offer.routeKey
        or at<purpose.updatedAt or at-purpose.updatedAt>CONFLICT_ROUTE_MEMORY then return false end
    local conflict=purpose.conflict
    if conflict.lastRefusalFrame==result.frameId and conflict.lastRefusalOffer==offerId then return false end
    conflict.lastRefusalFrame,conflict.lastRefusalOffer=result.frameId,offerId
    conflict.lastOutcome={status="refused",reason=result.reason,offerId=offerId,kind=offer.kind,
        routeKey=offer.routeKey,atHours=at,admitted=false}
    conflict.needsReappraisal=true
    conflictFailure(s,offer.routeKey,result.reason,at)
    conflictOfferFailure(s,offer,result.reason,at)
    addEvent(purpose,"conflict-refused",result.reason,at)
    return true
end
function P.conflictSnapshot(id)
    local purpose,s=conflictPurpose(id,nil,true)
    if not purpose then return nil end
    local conflict=purpose.conflict
    local appraisal=conflict.appraisal
    local admission=purpose.admission
    return dataCopy({schema=1,actorId=id,purposeId=purpose.id,status=purpose.status,
        atHours=purpose.updatedAt,threat=conflict.threat,selected=appraisal.selected,kind=appraisal.kind,
        reason=appraisal.reason,frameId=appraisal.frameId,alternatives=appraisal.alternatives,
        admission=admission and {owner=admission.owner,id=admission.correlationId,
            offerId=admission.offerId,atHours=admission.at},
        lastOutcome=conflict.lastOutcome,routeFailures=s.conflictRouteFailures or {}},0,12)
end

-- The adopting runtime calls this only after establishing that no live owner
-- remains. A saved admission is intent evidence, not proof of unseen work.
function P.reconcileConflict(id,reason)
    local purpose=conflictPurpose(id,nil,true)
    local admission=purpose and purpose.admission
    if not admission or not conflictText(reason,256) then return false end
    local accepted=P.conflictResult(id,purpose.id,{owner=admission.owner,id=admission.correlationId},
        {status="cancelled",reason=reason})
    if accepted then purpose.conflict.lastOutcome.observability="runtime-owner-lost" end
    return accepted
end

local function retainedLeisure(s, purposeId)
    return s and (s.purposes[purposeId]
        or s.suspendedLeisure and s.suspendedLeisure.purposes[purposeId]
        or s.queuedPurposes and s.queuedPurposes.purposes[purposeId])
end

-- Pure private offer: an unfinished sharing intention can survive outside
-- active execution capacity. It never implies that another person joined.
function P.participationSource(id, purposeId)
    local s, person = state(id), record(id)
    if not s or not person or person.dead then return nil end
    local ids = purposeId and { purposeId } or copyList(s.order, MAX_PURPOSES)
    if not purposeId then
        for _, key in ipairs(s.suspendedLeisure and s.suspendedLeisure.order or {}) do ids[#ids + 1] = key end
    end
    for _, key in ipairs(ids) do
        local purpose = retainedLeisure(s, key)
        if purpose and purpose.instrument and optionalSharing(purpose) and not purpose.participation then
            return { purposeId = key, activity = purpose.leisure.activity, itemId = purpose.instrument.itemKey,
                itemType = purpose.instrument.itemType, processId = purpose.participationProcessId }
        end
    end
end

function P.bindParticipationSource(id, purposeId, processId)
    local source = P.participationSource(id, purposeId)
    local view = SAO.Organization and SAO.Organization.viewFor(id, processId, false)
    local terms = view and view.proposal and view.proposal.proposal
    if not source or not terms or view.originatorId ~= id or view.kind ~= "leisure-participation"
        or terms.sourcePurposeId ~= purposeId or terms.itemId ~= source.itemId then return false end
    retainedLeisure(state(id), purposeId).participationProcessId = processId
    return true
end
-- Called after Perception has had its own chance to acquire current native
-- observations. The planner has no writer for the presumed event or cause.
function P.reviseSituationInquiry(id,body,purposeId,routeId,tick)
    local s=state(id,false)
    local purpose=s and s.purposes[purposeId]
    local pending=purpose and purpose.inquiry and purpose.inquiry.pendingRevision
    if not pending or purpose.inquiry.mode~="situation" or purpose.admission or pending.routeId~=routeId
        or not finite(pending.atHours) or pending.atHours>nowHours() then return false end
    local retained=retainSituation and retainSituation(id,body,tick,purpose.inquiry.questionKey,"observed-after-route") or false
    if retained then purpose.inquiry.pendingRevision=nil end
    return retained
end

function P.planParticipation(id, commitmentId, body)
    local offer = SAO.Coordination and SAO.Coordination.participationOffer(id, body, commitmentId)
    if not offer or offer.role ~= "perform" or offer.workId then return nil end
    local source = P.participationSource(id, offer.sourcePurposeId)
    if not source or source.processId ~= offer.processId then return nil end
    local purpose = P.planLeisure(id, { activity = offer.activity, itemKey = offer.itemId,
        affordance = offer.itemType, owner = "SAO.Gesture", nativeVerb = "blow-harmonica",
        locationKey = "current-observed-place", atLocation = true })
    if not purpose or purpose.admission or purpose.steps[purpose.cursor].id ~= "perform-activity" then return nil end
    purpose.participation = { processId = offer.processId, revision = offer.revision,
        commitmentId = commitmentId, sourcePurposeId = offer.sourcePurposeId }
    return purpose
end

function P.participationBinding(id, purposeId)
    local purpose = retainedLeisure(state(id), purposeId)
    return purpose and dataCopy(purpose.participation)
end

function P.participationInterests(id, activity)
    local s, out = state(id), { related = false, competing = false }
    for _, key in ipairs(s and s.order or {}) do
        local p = s.purposes[key]
        if p and p.status ~= "completed" and p.status ~= "abandoned" then
            if p.leisure and p.leisure.activity == activity then out.related = true end
            if p.admission or p.resourceOutcome or p.resourceCategory or p.domain == "learning" then out.competing = true end
        end
    end
    return out
end

function P.consumeParticipation(id, processId)
    local result = SAO.Organization and SAO.Organization.participationOutcome(id, processId)
    if not result or result.actorId ~= id or result.processId ~= processId
        or not finite(result.atHours) or result.atHours > nowHours() then return false end
    local s = state(id)
    local performed = retainedLeisure(s, result.purposeId)
    local source = retainedLeisure(s, result.sourcePurposeId)
    local binding = performed and performed.participation
    if not source or not binding or binding.processId ~= processId or binding.revision ~= result.revision
        or binding.sourcePurposeId ~= source.id or source.participationProcessId ~= processId
        or not binding.physicalResult or binding.physicalResult.status ~= "completed"
        or binding.physicalResult.workId ~= result.workId or source.instrument.itemKey ~= result.itemId then return false end
    -- Exact current social receipt advances only these sharing steps. Neither
    -- native sound nor acknowledgement grants practice, trust or enjoyment.
    for _, purpose in ipairs({ source, performed }) do
        for index, step in ipairs(purpose.steps) do
            if step.id == "share-activity" and step.owner == "native-participation" and step.status ~= "completed" then
                step.status, step.completedAt = "completed", result.atHours
                purpose.participationResult = dataCopy(result)
                purpose.cursor, purpose.status = index + 1, "completed"
                purpose.updatedAt = result.atHours
                addEvent(purpose, "result", "delivered-participation-acknowledgement", result.atHours)
            end
        end
    end
    return true
end

return P
