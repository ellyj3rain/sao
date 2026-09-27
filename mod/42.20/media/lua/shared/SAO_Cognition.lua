-- Independent interpretations share private observations, never one another's decisions.
SAO = SAO or {}
SAO.Cognition = SAO.Cognition or {}
local C = SAO.Cognition
local STORE = "SurvivorAwareness_Cognition"
local MODEL_IDS = { "ordinary", "associative" }
local ACTIONS = { food = true, water = true, inspect = true, continue = true }
local MAX_EPISODES, MAX_EXPERIENCES = 64, 256
local function finite(n, low, high)
    return type(n) == "number" and n == n and n >= low and n <= high
end
local function text(s, bound)
    return type(s) == "string" and #s > 0 and #s <= bound
end
local function clock()
    local ok, n = pcall(function() return SAO.History.countyHours() end)
    return ok and finite(n, 0, 1000000000) and n or nil
end
local function copy(value, depth, budget, seen)
    depth, budget, seen = depth or 0, budget or { left = 32768 }, seen or {}
    local kind = type(value)
    if kind == "nil" or kind == "boolean" then return value end
    if kind == "number" then assert(finite(value, -1000000000000, 1000000000000), "nonfinite"); return value end
    if kind == "string" then assert(#value <= 4096, "long scalar"); return value end
    assert(kind == "table" and depth < 16 and not seen[value], "non-data state")
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        budget.left = budget.left - 1
        assert(budget.left >= 0 and (type(k) == "string" or type(k) == "number"), "data bound")
        out[k] = copy(v, depth + 1, budget, seen)
    end
    seen[value] = nil
    return out
end
local function detached(value)
    local ok, out = pcall(copy, value)
    return ok and out or nil
end
local function defaults()
    return { enabled = false, opponentShare = 0.5, opportunitiesPerHour = 12, maxDepth = 3 }
end
function C.settings()
    local ok, data = pcall(function() return ModData.get(STORE) end)
    if ok and type(data) == "table" and type(data.settings) == "table" then
        return detached(data.settings) or defaults()
    end
    return defaults()
end
function C.configure(share, rate, depth)
    if not finite(share, 0, 1) or not finite(rate, 1, 60)
        or rate ~= math.floor(rate) or not finite(depth, 1, 4)
        or depth ~= math.floor(depth) then return false end
    local now = clock()
    if not now then return false end
    local ok, data = pcall(function() return ModData.getOrCreate(STORE) end)
    if not ok or type(data) ~= "table" then return false end
    local old = data.settings
    if old and old.enabled and old.opponentShare == share
        and old.opportunitiesPerHour == rate and old.maxDepth == depth then return true end
    data.settings = { enabled = true, opponentShare = share,
        opportunitiesPerHour = rate, maxDepth = depth }
    data.configuredAt = now
    return true
end
local function record(id, allowDead)
    if not text(id, 128) then return nil end
    local rec = SAO.Identity and SAO.Identity.get(id)
    return rec and (allowDead or not rec.dead) and rec or nil
end
local function newState()
    local models = {}
    for _, name in ipairs(MODEL_IDS) do models[name] = SAO.CognitiveModels.newState(name) end
    return { schema = 1, sequence = 0, eventSequence = 0, episodes = {}, experiences = {},
        seen = {}, models = models, omittedEpisodes = 0, omittedExperiences = 0,
        rejectedExperiences = 0, retiredThroughHour = -1, allocation = nil }
end
local function state(id, create, allowDead)
    local rec = record(id, allowDead)
    if not rec then return nil end
    if not rec.cognition and create and SAO.CognitiveModels then
        local ok, value = pcall(newState)
        if ok then rec.cognition = detached(value) end
    end
    local s = rec.cognition
    if type(s) ~= "table" or s.schema ~= 1 or type(s.models) ~= "table"
        or type(s.episodes) ~= "table" or type(s.experiences) ~= "table"
        or type(s.seen) ~= "table" or not finite(s.sequence, 0, 1000000000)
        or not finite(s.eventSequence, 0, 1000000000) then return nil end
    return s
end
local function capabilityCopy(value)
    if type(value) ~= "table" then return nil end
    local out = {}
    for _, k in ipairs({ "cook", "forage", "treat" }) do
        if type(value[k]) ~= "boolean" then return nil end
        out[k] = value[k]
    end
    return out
end
function C.capabilities(id)
    local out = { cook = false, forage = false, treat = false }
    if not record(id) then return out end
    local ok, own = pcall(function() return SAO.Labor.capabilityOf(id) end)
    if ok and type(own) == "table" then
        out.cook, out.forage, out.treat = own.canCook == true, own.canForage == true, own.canTreat == true
    end
    return out
end
local FRAME_KEYS = { id = true, actorId = true, worldHours = true, hunger = true,
    thirst = true, fatigue = true, eatAt = true, drinkAt = true, foodAllowed = true,
    waterAllowed = true, inspectionAllowed = true, knownFood = true, knownWater = true,
    knownPlaces = true, capabilities = true, priorIntent = true }
local function frameCopy(id, f, now)
    if type(f) ~= "table" or f.actorId ~= id or (f.id ~= nil and not text(f.id, 128))
        or not finite(f.worldHours, 0, now) then return nil end
    for k in pairs(f) do if not FRAME_KEYS[k] then return nil end end
    local out = { id = f.id, actorId = id, worldHours = f.worldHours }
    for _, k in ipairs({ "hunger", "thirst", "fatigue", "eatAt", "drinkAt" }) do
        if not finite(f[k], 0, 1) then return nil end
        out[k] = f[k]
    end
    for _, k in ipairs({ "foodAllowed", "waterAllowed", "inspectionAllowed" }) do
        if type(f[k]) ~= "boolean" then return nil end
        out[k] = f[k]
    end
    for _, k in ipairs({ "knownFood", "knownWater", "knownPlaces" }) do
        if not finite(f[k], 0, 100000) or f[k] ~= math.floor(f[k]) then return nil end
        out[k] = f[k]
    end
    out.capabilities = capabilityCopy(f.capabilities)
    if not out.capabilities then return nil end
    if f.priorIntent ~= nil then
        if not ACTIONS[f.priorIntent] then return nil end
        out.priorIntent = f.priorIntent
    end
    return out
end
local function proposalCopy(p, name, f)
    if type(p) ~= "table" or p.modelId ~= name or not text(p.version, 128)
        or not ACTIONS[p.actionId]
        or not text(p.interpretation, 512) or not finite(p.confidence, 0, 1)
        or type(p.predictions) ~= "table" then return nil end
    if (p.actionId == "food" and not f.foodAllowed)
        or (p.actionId == "water" and not f.waterAllowed)
        or (p.actionId == "inspect" and not f.inspectionAllowed) then return nil end
    local out = { modelId = name, version = tostring(p.version), actionId = p.actionId,
        interpretation = p.interpretation, confidence = p.confidence, predictions = {} }
    for action in pairs(ACTIONS) do
        local prediction = p.predictions[action]
        if type(prediction) ~= "table" or not finite(prediction.probability, 0, 1)
            or not text(prediction.claim, 256) then return nil end
        out.predictions[action] = { probability = prediction.probability, claim = prediction.claim }
    end
    if p.hypothesisId ~= nil then
        if not text(p.hypothesisId, 128) then return nil end
        out.hypothesisId = p.hypothesisId
    end
    return out
end
local function pending(s)
    local last = s.episodes[#s.episodes]
    return last and last.id == s.pendingEpisode and last or nil
end
local function boundedModel(value)
    if type(value) ~= "table" then return nil end
    local count = 0
    for _, field in ipairs({ "beliefs", "hypotheses" }) do
        if type(value[field]) ~= "table" then return nil end
        for _ in pairs(value[field]) do count = count + 1 end
    end
    if count > 64 then return nil end
    return detached(value)
end
function C.isDue(id)
    local settings, now = C.settings(), clock()
    local rec = record(id)
    if not settings.enabled or not now or not rec or not SAO.CognitiveModels then return false end
    if rec.cognition == nil then return true end
    local s = state(id)
    return s ~= nil and not s.pendingEpisode and now >= (s.nextAt or 0)
end
function C.choose(id, supplied)
    local settings, now = C.settings(), clock()
    if not settings.enabled or not now or not SAO.CognitiveModels then return nil end
    local frame = frameCopy(id, supplied, now)
    local s = frame and state(id, true)
    if not s or s.pendingEpisode or (frame.id ~= nil and frame.id == s.lastFrameId)
        or frame.worldHours < (s.nextAt or 0) then return nil end
    frame.id = frame.id or ("frame/" .. tostring(s.sequence + 1))
    local proposals = {}
    for _, name in ipairs(MODEL_IDS) do
        local own = detached(s.models[name])
        local ok, p = pcall(SAO.CognitiveModels.propose, name, own, copy(frame))
        local admitted = ok and proposalCopy(p, name, frame) or nil
        if not admitted then return nil end
        proposals[#proposals + 1] = admitted
    end
    if #proposals ~= 2 then return nil end
    local allocation = s.allocation
    if not finite(allocation, 0, 1) or allocation == 1 then
        allocation = SAO.Hash and SAO.Hash.unit(id, "cognition-selection") or 0.5
    end
    allocation = allocation + settings.opponentShare
    local index = allocation >= 1 and 2 or 1
    if index == 2 then allocation = allocation - 1 end
    s.sequence = s.sequence + 1
    local episode = { id = "episode/" .. tostring(s.sequence),
        worldHours = frame.worldHours, status = "proposed", frame = frame, proposals = proposals,
        selectedModelId = MODEL_IDS[index], selectedActionId = proposals[index].actionId,
        selectionWeight = index == 2 and settings.opponentShare or 1 - settings.opponentShare,
        selectionPolicy = "deterministic-balanced",
        disagreement = proposals[1].actionId ~= proposals[2].actionId }
    s.allocation, s.lastFrameId = allocation, frame.id
    s.nextAt = frame.worldHours + 1 / settings.opportunitiesPerHour
    s.episodes[#s.episodes + 1] = episode
    if #s.episodes > MAX_EPISODES then
        table.remove(s.episodes, 1); s.omittedEpisodes = s.omittedEpisodes + 1
    end
    s.pendingEpisode = episode.id
    return episode.selectedActionId, episode.id
end
function C.started(id, episodeId, started, detail)
    local s = state(id)
    local e = s and pending(s)
    if not e or e.id ~= episodeId or type(started) ~= "boolean" then return false end
    if detail ~= nil and (type(detail) ~= "string" or #detail > 512) then return false end
    if started then
        if e.status == "proposed" then e.status, e.executionStatus = "attempted", "queued" end
    else
        e.status, e.executionStatus, s.pendingEpisode = "censored", "censored", nil
    end
    e.reason = detail
    return true
end
function C.interrupt(id, reason)
    local s = state(id, false, true)
    local e = s and pending(s)
    if not e then return false end
    e.status, e.executionStatus, s.pendingEpisode = "censored", "censored", nil
    e.reason = string.sub(tostring(reason or "interrupted"), 1, 512)
    return true
end
-- Tokens are plain durable data captured at admission, before the action runs.
function C.capture(id, producer)
    if not C.settings().enabled or not text(producer, 32) then return nil end
    local s, now = state(id, true), clock()
    if not s or not now then return nil end
    local ok, data = pcall(function() return ModData.getOrCreate(STORE) end)
    if not ok or type(data) ~= "table" then return nil end
    local serial = data.eventSequence or 0
    if not finite(serial, 0, 1000000000000 - 1) or serial ~= math.floor(serial) then return nil end
    -- One saved world counter names events across performers without a hash alias.
    data.eventSequence, s.eventSequence = serial + 1, s.eventSequence + 1
    local eventId = "native/" .. tostring(data.eventSequence)
    return { id = eventId, actorId = id,
        episodeId = s.pendingEpisode, admittedAt = now, producer = producer,
        capabilities = C.capabilities(id) }
end
function C.attempted(id, token)
    local s = state(id)
    local e = s and pending(s)
    if not e or type(token) ~= "table" or token.actorId ~= id
        or token.episodeId ~= e.id then return false end
    e.status, e.executionStatus = "attempted", "attempted"
    return true
end
local KINDS = { inspection = true, acquire = true, store = true, consume = true }
local STATUSES = { completed = true, ["no-effect"] = true, interrupted = true, unavailable = true }
local EXPERIENCE_KEYS = { id = true, actorId = true, observerId = true, worldHours = true,
    kind = true, category = true, perspective = true, status = true, sourceId = true,
    itemType = true, episodeId = true, detail = true, foodPresent = true, waterPresent = true,
    hungerDelta = true, thirstDelta = true, capabilities = true }
local function experienceCopy(id, x, now)
    if type(x) ~= "table" or not text(x.id, 128) or not text(x.actorId, 128)
        or x.observerId ~= id or not finite(x.worldHours, 0, now)
        or not KINDS[x.kind] or not STATUSES[x.status]
        or (x.category ~= "food" and x.category ~= "water" and x.category ~= "container")
        or (x.perspective ~= "performed" and x.perspective ~= "observed") then return nil end
    for k in pairs(x) do if not EXPERIENCE_KEYS[k] then return nil end end
    if x.perspective == "performed" and x.actorId ~= id then return nil end
    if x.kind == "inspection" and x.category ~= "container" then return nil end
    if x.kind ~= "inspection" and (x.category == "container" or x.foodPresent ~= nil or x.waterPresent ~= nil) then return nil end
    if x.kind ~= "consume" and (x.hungerDelta ~= nil or x.thirstDelta ~= nil) then return nil end
    if x.perspective == "observed" and (x.actorId == id or x.kind == "inspection"
        or x.kind == "consume" or x.foodPresent ~= nil or x.waterPresent ~= nil
        or x.hungerDelta ~= nil or x.thirstDelta ~= nil or x.episodeId ~= nil) then return nil end
    local out = { id = x.id, actorId = x.actorId, observerId = id, worldHours = x.worldHours,
        kind = x.kind, category = x.category, perspective = x.perspective, status = x.status }
    for _, k in ipairs({ "sourceId", "itemType", "episodeId" }) do
        if x[k] ~= nil then if not text(x[k], 160) then return nil end; out[k] = x[k] end
    end
    if x.detail ~= nil then
        if type(x.detail) ~= "string" or #x.detail > 512 then return nil end
        out.detail = x.detail
    end
    for _, k in ipairs({ "foodPresent", "waterPresent" }) do
        if x[k] ~= nil then if type(x[k]) ~= "boolean" then return nil end; out[k] = x[k] end
    end
    for _, k in ipairs({ "hungerDelta", "thirstDelta" }) do
        if x[k] ~= nil then if not finite(x[k], -1, 1) then return nil end; out[k] = x[k] end
    end
    if x.capabilities ~= nil then
        out.capabilities = capabilityCopy(x.capabilities)
        if not out.capabilities then return nil end
    end
    return out
end
local function qualified(x)
    if x.status ~= "completed" and x.status ~= "no-effect" then return false end
    if x.kind == "inspection" then return type(x.foodPresent) == "boolean" and type(x.waterPresent) == "boolean" end
    if x.kind == "consume" then
        return x.category == "food" and x.hungerDelta ~= nil
            or x.category == "water" and x.thirstDelta ~= nil
    end
    return x.status == "completed"
end
local function matchIntent(e, x)
    if x.perspective ~= "performed" or x.episodeId ~= e.id or x.worldHours < e.worldHours then return false end
    if e.selectedActionId == "inspect" then return x.kind == "inspection" end
    return (e.selectedActionId == "food" or e.selectedActionId == "water")
        and x.category == e.selectedActionId and (x.kind == "acquire" or x.kind == "consume")
end
local function sameData(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not sameData(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function C.experience(id, supplied)
    local now = clock()
    if not C.settings().enabled or not now then return false, "disabled" end
    local x, s = experienceCopy(id, supplied, now), state(id, true)
    if not x or not s then return false, "invalid-experience" end
    if s.seen[x.id] then
        for _, prior in ipairs(s.experiences) do
            if prior.id == x.id and sameData(prior, x) then return true, "duplicate" end
        end
        s.rejectedExperiences = s.rejectedExperiences + 1
        return false, "conflicting-event-id"
    end
    if x.worldHours <= s.retiredThroughHour then
        s.rejectedExperiences = s.rejectedExperiences + 1
        return false, "retired-evidence-frontier"
    end
    local good, updated, revisions = qualified(x), {}, {}
    if good then
        for _, name in ipairs(MODEL_IDS) do
            local own = detached(s.models[name])
            if not own then return false, "invalid-model-state" end
            local observed = copy(x)
            observed.episodeId = nil
            local ok, revision = pcall(SAO.CognitiveModels.observe, name, own, observed, C.settings().maxDepth)
            updated[name] = ok and boundedModel(own) or nil
            if not updated[name] or type(revision) ~= "string" or #revision > 512
                or string.sub(revision, 1, 8) ~= "revised:" then
                return false, "model-observation-refused"
            end
            revisions[name] = revision
        end
    end
    if good then s.models = updated end
    s.seen[x.id] = true
    s.experiences[#s.experiences + 1] = x
    if #s.experiences > MAX_EXPERIENCES then
        local old = table.remove(s.experiences, 1)
        s.seen[old.id] = nil
        s.retiredThroughHour = math.max(s.retiredThroughHour, old.worldHours)
        s.omittedExperiences = s.omittedExperiences + 1
    end
    local e = pending(s)
    if e and matchIntent(e, x) then
        e.outcome = { eventId = x.id, worldHours = x.worldHours, actionId = e.selectedActionId,
            status = x.status, detail = x.detail }
        if good then
            local success = x.kind ~= "consume" or (x.category == "food"
                and x.hungerDelta > 0.0001 or x.category == "water" and x.thirstDelta > 0.0001)
            e.status, e.executionStatus = "observed", "observed"
            e.outcome.success, e.outcome.revisions = success, revisions
            e.outcome.predictions = {}
            for _, p in ipairs(e.proposals) do
                local prediction = p.predictions[e.selectedActionId]
                e.outcome.predictions[p.modelId] = { probability = prediction.probability,
                    claim = prediction.claim, squaredError = (prediction.probability - (success and 1 or 0)) ^ 2 }
            end
        else
            e.status, e.executionStatus = "censored", "censored"
        end
        s.pendingEpisode = nil
    end
    return true, good and "observed" or "censored"
end
function C.publish(id, token, values)
    if type(token) ~= "table" or token.actorId ~= id or not text(token.id, 128)
        or not finite(token.admittedAt, 0, clock() or -1) then return false end
    local x = detached(values)
    if not x then return false end
    x.id, x.actorId, x.observerId = token.id, id, id
    x.perspective, x.episodeId = "performed", token.episodeId
    token.observedAt = token.observedAt or x.worldHours or clock()
    if not finite(token.observedAt, token.admittedAt, clock() or -1) then return false end
    x.capabilities, x.worldHours = detached(token.capabilities), token.observedAt
    return C.experience(id, x)
end
-- A result reader is independent of Provisioning's acknowledgement stream.
function C.sourceResult(receipt, token)
    if type(receipt) ~= "table" or not token or receipt.actorId ~= token.actorId then return false end
    local quantity = tonumber(receipt.observedQuantity)
    local status = receipt.status == "completed" and quantity and quantity > 0 and "completed" or "unavailable"
    if receipt.status == "interrupted" or receipt.status == "released" then status = "interrupted" end
    local values = { kind = receipt.operation, category = receipt.category, sourceId = receipt.sourceId,
        itemType = receipt.itemType, status = status, detail = receipt.detail }
    -- Source use proves exact consumption, but does not export bodily relief.
    -- Its own native callback publishes relief separately; never infer a delta.
    if values.kind == "consume" and status == "completed" then return false end
    return C.publish(receipt.actorId, token, values)
end
local function boundedList(values, count, width)
    local out = {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        if #out >= count then break end
        if type(value) == "string" then out[#out + 1] = string.sub(value, 1, width) end
    end
    return out
end
local function displayEntry(value, hypothesis)
    if type(value) ~= "table" or not text(value.id, 128)
        or not finite(value.confidence, 0, 1) or not text(value.status, 64)
        or type(value.label) ~= "string" then return nil end
    local out = { id = value.id, label = string.sub(value.label, 1, 512),
        confidence = value.confidence, status = value.status }
    if hypothesis then
        if not finite(value.depth, 1, 4) or value.depth ~= math.floor(value.depth)
            or not text(value.branch, 160) or (value.status ~= "hypothesis"
            and value.status ~= "supported" and value.status ~= "refined"
            and value.status ~= "falsified") then return nil end
        out.branch, out.depth = value.branch, value.depth
        out.evidenceIds = boundedList(value.evidenceIds, 8, 128)
        out.parentIds = boundedList(value.parentIds, 4, 128)
        out.missing = boundedList(value.missing, 8, 256)
    end
    return out
end
-- Upper bound for this plain-data JSON projection, including escaped strings.
-- Kahlua exposes UTF-16 code units; the writer emits UTF-8 bytes.
local function jsonBytes(value)
    if type(value) == "string" then
        local n, i = 2, 1
        while i <= #value do
            local b = string.byte(value, i)
            if b < 32 then n = n + 6
            elseif b == 34 or b == 92 then n = n + 2
            elseif b < 128 then n = n + 1
            elseif b < 2048 then n = n + 2
            elseif b >= 55296 and b <= 56319 and i < #value
                and string.byte(value, i + 1) >= 56320 and string.byte(value, i + 1) <= 57343 then
                n, i = n + 4, i + 1
            else n = n + 3 end
            i = i + 1
        end
        return n
    end
    if type(value) ~= "table" then return 32 end
    local n = 2
    for k, v in pairs(value) do n = n + jsonBytes(tostring(k)) + 2 + jsonBytes(v) end
    return n
end
function C.snapshot(id, full)
    local s = state(id, false, true)
    local out = { schema = "simulation.cognition/1", settings = C.settings(), actorId = id,
        sequence = s and s.sequence or 0, omittedEpisodes = s and s.omittedEpisodes or 0,
        omittedExperiences = s and s.omittedExperiences or 0,
        rejectedExperiences = s and s.rejectedExperiences or 0, episodes = {}, models = {} }
    if not s then return out end
    local first = full == true and 1 or math.max(1, #s.episodes - 7)
    out.omittedEpisodes = out.omittedEpisodes + first - 1
    for i = first, #s.episodes do out.episodes[#out.episodes + 1] = detached(s.episodes[i]) end
    for _, name in ipairs(MODEL_IDS) do
        local ok, view = pcall(SAO.CognitiveModels.summary, name, copy(s.models[name]), clock() or 0)
        if ok and type(view) == "table" and text(s.models[name].version, 128) then
            local model = { id = name, version = s.models[name].version,
                beliefs = {}, hypotheses = {} }
            for i, belief in ipairs(view.beliefs or {}) do
                if i <= 64 then
                    local entry = displayEntry(belief, false)
                    if entry then model.beliefs[#model.beliefs + 1] = entry end
                end
            end
            for i, hypothesis in ipairs(view.hypotheses or {}) do
                if i <= (full == true and 64 or 12) then
                    local entry = displayEntry(hypothesis, true)
                    if entry then model.hypotheses[#model.hypotheses + 1] = entry end
                end
            end
            model.omittedHypotheses = math.max(0, #(view.hypotheses or {}) - #model.hypotheses)
                + (s.models[name].omittedHypotheses or 0)
            model.omittedBeliefs = math.max(0, #(view.beliefs or {}) - #model.beliefs)
                + (s.models[name].omittedBeliefs or 0)
            out.models[#out.models + 1] = model
        else return nil end
    end
    if full == true then
        out.experiences = detached(s.experiences)
    else
        while jsonBytes(out) > 65536 do
            if #out.episodes > 1 then
                table.remove(out.episodes, 1); out.omittedEpisodes = out.omittedEpisodes + 1
            else
                local removed = false
                for _, model in ipairs(out.models) do
                    if #model.hypotheses > 0 then
                        table.remove(model.hypotheses); model.omittedHypotheses = model.omittedHypotheses + 1; removed = true
                    elseif #model.beliefs > 0 then
                        table.remove(model.beliefs); model.omittedBeliefs = model.omittedBeliefs + 1; removed = true
                    end
                end
                if not removed then break end
            end
        end
    end
    return out
end
function C.rebindWorld()
    for id, rec in pairs(SAO.Identity and SAO.Identity.all() or {}) do
        if rec.cognition then C.interrupt(id, "world-reloaded") end
    end
end
if Events and Events.OnGameStart then
    if C.onGameStart then Events.OnGameStart.Remove(C.onGameStart) end
    C.onGameStart = function() C.rebindWorld() end
    Events.OnGameStart.Add(C.onGameStart)
end
return C
