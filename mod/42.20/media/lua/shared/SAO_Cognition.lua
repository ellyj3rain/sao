-- Independent interpretations share private observations, never one another's decisions.
SAO = SAO or {}
SAO.Cognition = SAO.Cognition or {}
local C = SAO.Cognition
if not SAO.SituationAppraisal and type(require)=="function" then pcall(require,"SAO_SituationAppraisal") end
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

-- Normal worlds use the existing bounded two-contestant budget. A saved
-- setting, including an explicit disabled or malformed one, remains the
-- operator's setting and is never repaired implicitly at load.
function C.ensureGameDefaults()
    if not ModData or type(ModData.get)~="function" then return false,"storage-unavailable" end
    local ok,data=pcall(function()return ModData.get(STORE)end)
    if not ok or data~=nil and type(data)~="table" then return false,"storage-unavailable" end
    if data and data.settings~=nil then return true,"saved-settings" end
    if not C.configure(0.5,12,3) then return false,"clock-or-storage-unavailable" end
    return true,"initialized"
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
-- Preserve the actual decision-time owner view separately from bounded model detail.
local function personStateCopy(value, depth, budget, seen)
    depth,budget,seen=depth or 0,budget or {left=65536},seen or {}
    local kind=type(value)
    if kind=="nil" or kind=="boolean" then return value end
    if kind=="number" then assert(value==value and math.abs(value)<math.huge,"nonfinite person state");return value end
    if kind=="string" then assert(#value<=4096,"long person scalar");return value end
    assert(kind=="table" and depth<32 and not seen[value],"non-data person state")
    seen[value]=true
    local out={}
    for key,item in pairs(value) do
        budget.left=budget.left-1
        assert(budget.left>=0 and (type(key)=="string" or type(key)=="number"),"person state bound")
        out[key]=personStateCopy(item,depth+1,budget,seen)
    end
    seen[value]=nil
    return out
end
local function detachedPersonState(value)
    local ok,result=pcall(personStateCopy,value)
    return ok and result or nil
end
local function decisionPersonState(id,frame,now)
    local ok,tick=pcall(function() return SAO.History.ticks() end)
    -- Older/partial runtimes cannot supply this optional field without an owned tick.
    if not ok or type(tick)~="number" or tick~=tick or tick<0 or tick>=math.huge or tick%1~=0 then return nil end
    local out={schema="sao-person-decision-state/1",actorId=id,decisionId=frame.id,
        atHours=frame.worldHours,atTick=tick,status="unavailable"}
    if frame.worldHours~=now then out.reason="decision-clock-mismatch";return out end
    if not SAO.PersonState or type(SAO.PersonState.query)~="function" then
        out.reason="person-state-owner-unavailable";return out
    end
    local bodyOk,body=pcall(function() return SAO.Body.get(id) end)
    if not bodyOk or body==nil then out.reason="decision-body-unavailable";return out end
    local queryOk,value=pcall(SAO.PersonState.query,id,body,tick)
    if not queryOk or type(value)~="table" then out.reason="person-state-query-unavailable";return out end
    local current=clock()
    local tickOk,currentTick=pcall(function() return SAO.History.ticks() end)
    if current~=now or not tickOk or currentTick~=tick then out.reason="decision-clock-changed";return out end
    if value.schema~="sao-person-state/1" or value.actorId~=id or value.atTick~=tick
        or value.atHours~=nil and value.atHours~=frame.worldHours
        or value.status~="available" and value.status~="unavailable" then
        out.reason="person-state-binding-unavailable";return out
    end
    if value.status=="available" then
        local model=value.modelView
        if value.atHours~=frame.worldHours or type(value.currentInstant)~="string"
            or type(model)~="table" or model.actorId~=id or model.atTick~=tick
            or model.atHours~=frame.worldHours or model.currentInstant~=value.currentInstant then
            out.reason="person-state-binding-unavailable";return out
        end
    elseif not text(value.reason,512) then
        out.reason="person-state-unavailable-without-reason";return out
    end
    local frozen=detachedPersonState(value)
    if not frozen then out.reason="person-state-copy-unavailable";return out end
    out.personState=frozen;out.status=value.status
    if value.status=="unavailable" then out.reason=value.reason end
    return out
end
local function episodeCopy(value)
    local base={}
    for key,item in pairs(value) do if key~="decisionPersonState" then base[key]=item end end
    local out=detached(base)
    if not out then return nil end
    if value.decisionPersonState~=nil then
        out.decisionPersonState=detachedPersonState(value.decisionPersonState)
        if not out.decisionPersonState then return nil end
    end
    return out
end
function C.choose(id, supplied)
    local settings, now = C.settings(), clock()
    if not settings.enabled or not now or not SAO.CognitiveModels then return nil end
    local frame = frameCopy(id, supplied, now)
    local s = frame and state(id, true)
    if not s or s.pendingEpisode or (frame.id ~= nil and frame.id == s.lastFrameId)
        or frame.worldHours < (s.nextAt or 0) then return nil end
    frame.id = frame.id or ("frame/" .. tostring(s.sequence + 1))
    local frozenPersonState = decisionPersonState(id,frame,now)
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
        decisionPersonState = frozenPersonState,
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
local HOBBY_KINDS={ ["leisure-meditation"]=true,["leisure-exercise"]=true,
    ["leisure-art"]=true,["leisure-music"]=true,["leisure-games"]=true,["leisure-radio"]=true,["leisure-lifestyle"]=true,
    ["leisure-duet"]=true,["leisure-dance"]=true }
local EXTENDED = { ["medication-use"] = true, ["physical-change"] = true, preparation = true,
    ["animal-care"] = true, ["window-repair"] = true, ["material-crafting"] = true, ["tool-repair"] = true, ["entry-outcome"] = true, ["recovery-outcome"] = true, ["study-outcome"] = true, ["commitment-outcome"] = true, ["instrument-use"] = true, ["leisure-reading"] = true,
    ["leisure-meditation"]=true,["leisure-exercise"]=true,["leisure-art"]=true,["leisure-music"]=true,["leisure-games"]=true,["leisure-radio"]=true,["leisure-lifestyle"]=true,
    ["leisure-duet"]=true,["leisure-dance"]=true,["weekone-instrument-performance"]=true,
    ["weekone-performance-hearing"]=true }
local STATUSES = { completed = true, ["no-effect"] = true, interrupted = true, unavailable = true }
local EXPERIENCE_KEYS = { id = true, actorId = true, observerId = true, worldHours = true,
    kind = true, category = true, perspective = true, status = true, sourceId = true,
    itemType = true, episodeId = true, detail = true, foodPresent = true, waterPresent = true,
    hungerDelta = true, thirstDelta = true, capabilities = true }
local function experienceCopy(id, x, now)
    if type(x) == "table" and EXTENDED[x.kind] then
        -- These experiences are independent of the four executable intents.
        -- A new private fact cannot settle an unrelated selected action.
        if x.observerId ~= id or not finite(x.worldHours, 0, now) or x.episodeId ~= nil
            or not SAO.CognitiveModels.acceptsExperience(x) then return nil end
        return detached(x)
    end
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
    if EXTENDED[x.kind] then return x.status == "completed" or x.kind == "tool-repair" and x.status == "no-effect" end
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
local BEHAVIOR_RESULT = {}
function C.experience(id, supplied, authority)
    if type(supplied)=="table" and (supplied.kind=="tool-repair" or supplied.kind=="material-crafting" or supplied.kind=="window-repair" or supplied.kind=="entry-outcome" or supplied.kind=="recovery-outcome" or supplied.kind=="study-outcome" or supplied.kind=="commitment-outcome" or supplied.kind=="preparation" or supplied.kind=="instrument-use" or supplied.kind=="leisure-reading" or supplied.kind=="weekone-instrument-performance" or supplied.kind=="weekone-performance-hearing" or HOBBY_KINDS[supplied.kind])
        and authority~=BEHAVIOR_RESULT then return false,"behavior-owner-required" end
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
    if not EXTENDED[x.kind] then
        if x.worldHours <= s.retiredThroughHour then
            s.rejectedExperiences = s.rejectedExperiences + 1
            return false, "retired-evidence-frontier"
        end
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
-- Producer callbacks use their existing monotonic durable positions. These
-- scalar cursors prevent replay after the bounded experience log evicts
-- the original event. They are not exposure-to-effect attribution links.
local function nativeExperience(id, producer, position, x)
    if not finite(position, 0, 9007199254740991) or position ~= math.floor(position) then
        return false, "invalid-native-position"
    end
    if not experienceCopy(id, x, clock() or -1) then return false, "invalid-experience" end
    local s = state(id, false)
    local cursors = s and s.nativeExperienceCursors
    if cursors ~= nil and type(cursors) ~= "table" then return false, "invalid-native-cursors" end
    local prior = cursors and cursors[producer]
    if prior ~= nil and not finite(prior, 0, 9007199254740991) then return false, "invalid-native-cursor" end
    if prior and position <= prior then
        local retained
        for _, old in ipairs(s.experiences) do if old.id == x.id then retained = old break end end
        if not retained then return false, "retired-native-receipt" end
        -- Re-delivery does not refresh the original private acquisition time.
        -- The ordinary conflict check still compares every normalized fact.
        x.worldHours = retained.worldHours
        x.capabilities = detached(retained.capabilities)
    else
        -- Existing personal capacities contextualize this newly acquired fact.
        -- They are read from Labor, never inferred from the native receipt.
        x.capabilities = C.capabilities(id)
    end
    local ok, reason = C.experience(id, x, BEHAVIOR_RESULT)
    if ok then
        s = state(id, false)
        s.nativeExperienceCursors = s.nativeExperienceCursors or {}
        s.nativeExperienceCursors[producer] = math.max(prior or 0, position)
    end
    return ok, reason
end
-- A paired source result may become shareable after a newer work sequence:
-- the other performer owns the final callback. Give the acquired fact its own
-- monotonic delivery position while keeping the native work sequence inside
-- the fact. Claims remain only while their Organization process is retained.
local MAX_PAIRED_CLAIMS=1024
local function pairedSourceExperience(id,receipt,producer,kind,x)
    if not C.settings().enabled then return false,"disabled" end
    local s=state(id,true)
    if not s then return false,"person-unavailable" end
    local claims=s.pairedSourceClaims or {}
    local order=s.pairedSourceClaimOrder or {}
    if type(claims)~="table" or type(order)~="table" or #order>MAX_PAIRED_CLAIMS then
        return false,"invalid-paired-claims" end
    local key=producer..":"..tostring(#receipt.processId)..":"..receipt.processId..":"..tostring(receipt.revision)
    local prior=claims[key]
    if prior then
        if type(prior)~="table" or prior.processId~=receipt.processId
            or prior.revision~=receipt.revision or prior.workId~=receipt.workId
            or prior.sourceSequence~=receipt.sequence or prior.partnerId~=receipt.partnerId
            or prior.partnerResultId~=receipt.coPerformance.partnerResultId
            or prior.atHours~=receipt.atHours or prior.musicKey~=receipt.musicKey
            or prior.role~=receipt.role then return false,"conflicting-paired-receipt" end
        return true,"duplicate"
    end
    if #order>=MAX_PAIRED_CLAIMS then
        local processes=SAO.Organization and SAO.Organization.processes
        if type(processes)~="table" then return false,"process-map-unavailable" end
        local held={}
        for _,claimKey in ipairs(order) do
            local row=claims[claimKey]
            if type(row)~="table" or not text(row.processId,160) then
                return false,"invalid-paired-claims" end
            if processes[row.processId] then held[#held+1]=claimKey
            else claims[claimKey]=nil end
        end
        order=held
        s.pairedSourceClaimOrder=order
        if #order>=MAX_PAIRED_CLAIMS then return false,"paired-claim-capacity" end
    end
    local cursors=s.nativeExperienceCursors
    if cursors~=nil and type(cursors)~="table" then return false,"invalid-native-cursors" end
    local position=cursors and cursors[producer] or 0
    if not finite(position,0,9007199254740990) or position~=math.floor(position) then
        return false,"invalid-native-cursor" end
    position=position+1
    x.id=kind.."/"..id.."/"..tostring(position)
    x.sourceWorkSequence=receipt.sequence
    local ok,reason=nativeExperience(id,producer,position,x)
    if not ok then return false,reason end
    claims[key]={processId=receipt.processId,revision=receipt.revision,
        workId=receipt.workId,sourceSequence=receipt.sequence,
        partnerId=receipt.partnerId,partnerResultId=receipt.coPerformance.partnerResultId,
        atHours=receipt.atHours,musicKey=receipt.musicKey,role=receipt.role,
        deliveryPosition=position}
    order[#order+1]=key
    s.pairedSourceClaims,s.pairedSourceClaimOrder=claims,order
    return true,reason
end
local function privateFact(id, kind, category, eventId, acquired, occurred)
    return { id = eventId, actorId = id, observerId = id, worldHours = acquired,
        occurredAtHours = occurred, kind = kind, category = category,
        perspective = "performed", status = "completed" }
end
-- The physical producer owns the durable receipt; callers cannot manufacture
-- a lesson by submitting plausible fields to the public ledger.
function C.behaviorOutcome(id, receipt)
    local now,rec=clock(),record(id)
    if not now or not rec or type(receipt)~="table" or receipt.actorId~=id
        or not finite(receipt.sequence,1,9007199254740991) or receipt.sequence~=math.floor(receipt.sequence)
        or not finite(receipt.atHours,0,now) then return false,"unqualified-behavior" end
    local entry=receipt.kind=="entry-outcome"
    if not entry and receipt.kind~="recovery-outcome" then return false,"unqualified-behavior" end
    local owner=entry and SAO.Perception or SAO.Needs
    local canonical=owner and owner.behaviorOutcome and owner.behaviorOutcome(id,receipt.sequence)
    if not canonical or not sameData(canonical,receipt) then return false,"behavior-owner-unavailable" end
    local producer=entry and "entry" or "recovery"
    local x=privateFact(id,receipt.kind,"body",producer.."/"..id.."/"..tostring(receipt.sequence),now,receipt.atHours)
    x.sourceId,x.actionKind,x.apertureState=receipt.sourceId,receipt.actionKind,receipt.apertureState
    x.succeeded=receipt.succeeded
    x.beforeValue,x.afterValue,x.durationHours=receipt.beforeValue,receipt.afterValue,receipt.durationHours
    return nativeExperience(id,producer,receipt.sequence,x)
end
function C.behaviorExpectation(id, kind, sourceId, condition, hours)
    local s=state(id,false)
    if not C.settings().enabled or not s or not finite(hours,0,clock() or -1)
        or not SAO.CognitiveModels or not SAO.CognitiveModels.behaviorExpectation then return nil end
    local own=s.models.ordinary
    if own.actorId~=id then return nil end
    return SAO.CognitiveModels.behaviorExpectation("ordinary",own,kind,sourceId,condition,hours)
end

-- Reading pages is an acquired execution fact. Neither this receipt nor its
-- prediction claims understanding, assessed knowledge, skill or practice XP.
function C.studyOutcome(id,receipt)
    local now=clock()
    if not now or type(receipt)~="table" or receipt.actorId~=id or receipt.status~="completed"
        or receipt.nativeOwner~="ISReadABook.complete" or receipt.token~="reading:progressed"
        or not finite(receipt.sequence,1,9007199254740991) or receipt.sequence~=math.floor(receipt.sequence)
        or receipt.workId~="study/"..tostring(receipt.sequence)
        or not text(receipt.bookSkill,96) or not finite(receipt.atHours,0,now)
        or not finite(receipt.beganAt,0,receipt.atHours)
        or not finite(receipt.totalPages,1,1000000000)
        or not finite(receipt.pagesBefore,0,receipt.totalPages)
        or not finite(receipt.pagesAfter,receipt.totalPages,1000000000)
        or receipt.pagesAfter<=receipt.pagesBefore then return false,"unqualified-study" end
    local canonical=SAO.Study and SAO.Study.outcome and SAO.Study.outcome(id,receipt.sequence)
    if not canonical or not sameData(canonical,receipt) then return false,"study-owner-unavailable" end
    local x=privateFact(id,"study-outcome","learning","study/"..id.."/"..tostring(receipt.sequence),now,receipt.atHours)
    x.sourceId,x.itemId,x.itemType="manual:"..receipt.bookSkill,receipt.itemId,receipt.itemType
    x.beforeValue,x.afterValue=receipt.pagesBefore,receipt.pagesAfter
    return nativeExperience(id,"study",receipt.sequence,x)
end
-- The terminal native owner supplies the measured sound attempt. Hearing a
-- blow establishes neither repertoire nor another person's participation.
function C.instrumentOutcome(id,sequence)
    local now=clock()
    if not now or not finite(sequence,1,9007199254740991) or sequence~=math.floor(sequence) then
        return false,"unqualified-instrument"
    end
    local owner=SAO.Gesture
    local receipt=owner and owner.instrumentOutcome and owner.instrumentOutcome(id,sequence)
    if type(receipt)~="table" or receipt.actorId~=id or receipt.sequence~=sequence
        or receipt.workId~="instrument:"..id..":"..tostring(sequence)
        or type(receipt.bodyGenerationKnown)~="boolean"
        or receipt.bodyGenerationKnown and not text(receipt.bodyToken,160)
        or not receipt.bodyGenerationKnown and receipt.bodyToken~=nil
        or receipt.verb~="blow-harmonica" or not text(receipt.itemType,160)
        or not text(receipt.itemId,32)
        or (receipt.status~="completed" and receipt.status~="interrupted")
        or not finite(receipt.atHours,0,now)
        or not finite(receipt.admittedAtHours,0,receipt.atHours)
        or type(receipt.cleanupPending)~="boolean" or type(receipt.soundEnded)~="boolean"
        or type(receipt.soundEmitted)~="boolean" or type(receipt.worldSoundEmitted)~="boolean" then
        return false,"instrument-owner-unavailable"
    end
    if receipt.soundEmitted and (not finite(receipt.soundHandle,1,9007199254740991)
        or not finite(receipt.startedAtHours,receipt.admittedAtHours,receipt.atHours)) then
        return false,"invalid-instrument-sound"
    end
    if receipt.status=="completed" and (not receipt.soundEmitted or not receipt.worldSoundEmitted
        or not receipt.soundEnded or receipt.cleanupPending
        or not finite(receipt.endedAtHours,receipt.startedAtHours,receipt.atHours)) then
        return false,"unmeasured-instrument"
    end
    local itemId=tonumber(receipt.itemId)
    if not finite(itemId,-2147483648,2147483647) or itemId~=math.floor(itemId) then
        return false,"invalid-instrument-item"
    end
    local x=privateFact(id,"instrument-use","leisure","instrument/"..id.."/"..tostring(sequence),now,receipt.atHours)
    x.sourceId,x.itemId,x.itemType="native:sound:BlowHarmonica",itemId,receipt.itemType
    -- Acquiring the terminal experience is complete even when the physical
    -- attempt was interrupted. Emitting a partial sound is not performance.
    x.actionKind,x.succeeded=receipt.verb,receipt.status=="completed"
    return nativeExperience(id,"instrument",sequence,x)
end

-- The Week One source action completes on its own body. Its terminal journal
-- is read back before the performed fact enters this person's private models.
function C.weekOnePerformanceOutcome(id, sequence)
    local now = clock()
    local okNative, nativeNow = pcall(function()
        return getGameTime():getWorldAgeHours() end)
    if not okNative or not finite(nativeNow, 0, 1000000000) then
        nativeNow = now end
    if not now or not finite(sequence, 1, 9007199254740991)
        or sequence ~= math.floor(sequence) then return false, "unqualified-weekone-performance" end
    local owner = SAO.WeekOneContinuity
    local r = owner and owner.performanceOutcome and owner.performanceOutcome(id, sequence)
    if type(r) ~= "table" or r.actorId ~= id or r.sequence ~= sequence
        or r.sourceId ~= "BanditsWeekOne:SAOPerform" or r.sourceAction ~= "SAOPerform"
        or r.claimOwner ~= "BanditsWeekOne" or r.purpose ~= "perform-with-physical-instrument"
        or r.status ~= "completed" or not text(r.sourceProgram, 96)
        or not text(r.sourceStage, 96)
        or not finite(r.brainId, -2147483648, 2147483647)
        or r.brainId ~= math.floor(r.brainId) or r.bodyId ~= r.brainId
        or not finite(r.born, -1000000000000, 1000000000000)
        or not finite(r.decisionAtTick, 0, 9007199254740991)
        or r.decisionAtTick ~= math.floor(r.decisionAtTick)
        or not finite(r.itemId, -2147483648, 2147483647)
        or r.itemId ~= math.floor(r.itemId)
        or not finite(r.startedAtHours, 0, nativeNow)
        or not finite(r.atHours, r.startedAtHours, nativeNow)
        or r.countyAtHours ~= nil
            and not finite(r.countyAtHours, 0, now) then
        return false, "weekone-performance-owner-unavailable"
    end
    local sounds = {
        ["Base.GuitarElectric"] = "BWOInstrumentBassGuitar1",
        ["Base.Violin"] = "BWOInstrumentViolinPaganini",
        ["Base.Saxophone"] = "BWOInstrumentSax1",
    }
    if sounds[r.itemType] ~= r.soundId then return false, "weekone-performance-sound-mismatch" end
    local x = privateFact(id, "weekone-instrument-performance", "leisure",
        "weekone-instrument-performance/"..id.."/"..tostring(sequence),
        now, r.countyAtHours or r.atHours)
    x.sourceId, x.itemId, x.itemType = r.sourceId, r.itemId, r.itemType
    x.actionKind, x.succeeded, x.soundId = "perform-instrument", true, r.soundId
    x.sourceBrainId, x.sourceBorn, x.sourceBodyId = r.brainId, r.born, r.bodyId
    x.decisionAtTick, x.claimOwner = r.decisionAtTick, r.claimOwner
    x.sourceProgram, x.sourceStage, x.startedAtHours = r.sourceProgram, r.sourceStage, r.startedAtHours
    -- The source receipt keeps native world age. Only a completion stamped
    -- at the physical action can establish its place in county chronology;
    -- older receipts remain valid facts without invented ordering.
    x.nativeCompletedAtHours = r.countyAtHours and r.atHours or nil
    return nativeExperience(id, "weekone-instrument-performance", sequence, x)
end
-- A listener's physical hearing is an observed acoustic encounter. The
-- Perception journal owns the native acquisition; cognition reads its current
-- validated copy and retains exact source/pulse identity without granting a
-- performance, enjoyment, agreement or hobby-success outcome to the listener.
function C.weekOnePerformanceHearings(id)
    local now, rec = clock(), record(id)
    if not C.settings().enabled then return false, "disabled" end
    if not now or not rec or not SAO.Perception
        or type(SAO.Perception.weekOnePerformanceHearings) ~= "function" then
        return false, "hearing-owner-unavailable" end
    local journal = rec.weekOnePerformanceHearings
    if journal == nil or type(journal) == "table" and #journal == 0 then
        return true, "unchanged" end
    local omitted = rec.weekOnePerformanceHearingsOmitted or 0
    if type(journal) ~= "table" or #journal > 16
        or not finite(omitted, 0, 9007199254740991)
        or omitted ~= math.floor(omitted) then return false, "invalid-hearing-journal" end
    local ok, validated = pcall(SAO.Perception.weekOnePerformanceHearings, id)
    if not ok or type(validated) ~= "table" then return false, "hearing-owner-unavailable" end
    local current = state(id, false)
    if rec.cognition ~= nil and not current then return false, "invalid-model-state" end
    local cursors = current and current.nativeExperienceCursors
    if cursors ~= nil and type(cursors) ~= "table" then return false, "invalid-native-cursors" end
    local prior = cursors and cursors["weekone-performance-hearing"] or 0
    if not finite(prior, 0, 9007199254740991) or prior ~= math.floor(prior) then
        return false, "invalid-native-cursor" end
    local seenPulses, acquired = {}, 0
    for index, stored in ipairs(journal) do
        local position = omitted + index
        if not finite(position, 1, 9007199254740991) then
            return false, "invalid-hearing-position" end
        local pulse = type(stored) == "table" and stored.pulseId
        if type(pulse) == "string" and not seenPulses[pulse] then
            seenPulses[pulse] = true
            if position > prior then
                local row
                for _, candidate in ipairs(validated) do
                    if candidate.pulseId == pulse and sameData(candidate, stored) then
                        row = candidate; break end
                end
                if row then
                    local x = { id = "weekone-heard/"..tostring(position),
                        actorId = row.actorId, observerId = id, worldHours = now,
                        occurredAtHours = row.acquiredAtCountyHours,
                        kind = "weekone-performance-hearing", category = "leisure",
                        perspective = "observed", status = "completed",
                        sourceId = "BanditsWeekOne:SAOPerform",
                        sourceBrainId = row.brainId, sourceBorn = row.born,
                        observerBrainId = row.observerBrainId,
                        observerBorn = row.observerBorn,
                        soundId = row.soundId, soundHandle = row.soundHandle,
                        pulseId = row.pulseId, sourceEpoch = row.epoch,
                        sourceSequence = row.sequence, nativeClock = row.clock,
                        nativeEmittedAtHours = row.emittedAtHours,
                        nativeHeardAtHours = row.heardAtHours,
                        nativeWitnessedAtHours = row.witnessedAtHours,
                        nativeClaimedAtHours = row.atHours }
                    local accepted, reason = nativeExperience(id,
                        "weekone-performance-hearing", position, x)
                    if not accepted then return false, reason end
                    acquired = acquired + 1
                end
            end
        end
    end
    return true, acquired > 0 and acquired or "unchanged"
end
-- Repetition alone is familiarity. A small exploratory music signal requires
-- two different, time-separated heard performances and this listener's own
-- later completed music action. The latest own attempt may also counter it.
-- This is a planning curiosity signal, not mood, pleasure or social assent.
function C.weekOneMusicInterest(id)
    local out = { schema = "sao-private-weekone-music-interest/1", actorId = id,
        status = "unobserved", informationGain = 0, evidenceIds = {} }
    local s = state(id, false)
    if not s or not SAO.CognitiveModels then return out end
    local heard, latestOwn = {}, nil
    for _, x in ipairs(s.experiences) do
        if type(x) == "table" and SAO.CognitiveModels.acceptsExperience(x) then
            if x.kind == "weekone-performance-hearing"
                and x.observerId == id and x.actorId ~= id then
                heard[#heard + 1] = x
            elseif (x.kind == "instrument-use" or x.kind == "leisure-music"
                    or x.kind == "weekone-instrument-performance"
                        and x.nativeCompletedAtHours ~= nil)
                and x.actorId == id and x.observerId == id
                and x.perspective == "performed" and x.status == "completed"
                and (not latestOwn or x.occurredAtHours >= latestOwn.occurredAtHours) then
                latestOwn = x
            end
        end
    end
    if #heard == 0 then return out end
    out.status = "single-hearing"
    local first, second
    for a = 1, #heard do
        for b = a + 1, #heard do
            local earlier, later = heard[a], heard[b]
            if earlier.nativeEmittedAtHours > later.nativeEmittedAtHours then
                earlier, later = later, earlier
            end
            if earlier.pulseId ~= later.pulseId
                and later.nativeEmittedAtHours - earlier.nativeEmittedAtHours >= 0.05 then
                first, second = earlier, later
                break
            end
        end
        if first then break end
    end
    if not first then return out end
    out.status = "familiarity-only"
    out.evidenceIds = { first.id, second.id }
    if latestOwn and latestOwn.occurredAtHours > first.occurredAtHours then
        out.evidenceIds[3] = latestOwn.id
        if latestOwn.succeeded == true then
            out.status = "supported-exploration"
            out.informationGain = 0.2
        else
            out.status = "mixed-evidence"
        end
    end
    return out
end
-- Canonical terminal reading is a private attempted fact. Completion certifies
-- page use or exact text exposure, never understanding, skill or content claims.
function C.leisureReadingOutcome(id, sequence)
    local now = clock()
    if not now or not finite(sequence, 1, 9007199254740991) or sequence ~= math.floor(sequence) then
        return false, "unqualified-leisure-reading"
    end
    local owner = SAO.Study
    local r = owner and owner.leisureOutcome and owner.leisureOutcome(id, sequence)
    if type(r) ~= "table" or r.actorId ~= id or r.sequence ~= sequence
        or r.workId ~= "study/"..tostring(sequence) or not text(r.purposeId, 160)
        or not text(r.itemId, 32) or not text(r.itemType, 160)
        or type(r.bodyGenerationKnown) ~= "boolean"
        or r.bodyGenerationKnown and not text(r.bodyToken, 160)
        or not r.bodyGenerationKnown and r.bodyToken ~= nil
        or (r.status ~= "completed" and r.status ~= "interrupted")
        or type(r.nativeStarted) ~= "boolean" or type(r.nativeCompleted) ~= "boolean"
        or type(r.custodyVerified) ~= "boolean" or not finite(r.atHours, 0, now)
        or not finite(r.beganAt, 0, r.atHours) or not finite(r.progress, 0, 1)
        or r.nativeStarted and not finite(r.startedAt, r.beganAt, r.atHours)
        or not r.nativeStarted and r.startedAt ~= nil then return false, "reading-owner-unavailable" end
    local note = r.actionKind == "read-note"
    if note then
        if r.sourceId ~= "native:literature:customPages" or r.nativeOwner ~= "SAONoteReadAction/ISBaseTimedAction"
            or r.token ~= "note:text-exposed" or r.contentBinding ~= r.workId
            or not finite(r.contentPages, 1, 32) or r.contentPages ~= math.floor(r.contentPages)
            or not finite(r.contentBytes, 1, 65536) or r.contentBytes ~= math.floor(r.contentBytes)
            or r.pagesBefore ~= nil or r.pagesAfter ~= nil or r.totalPages ~= nil or r.mood ~= nil then
            return false, "unqualified-note-exposure"
        end
    elseif r.actionKind ~= "read-book" or r.sourceId ~= "native:literature:ISReadABook"
        or r.nativeOwner ~= "ISReadABook.complete" or r.token ~= "leisure:performed"
        or not finite(r.totalPages, -1000000000, 1000000000) or r.totalPages == 0
        or not finite(r.pagesBefore, 0, 1000000000) or not finite(r.pagesAfter, 0, 1000000000)
        or r.contentBinding ~= nil or r.contentPages ~= nil or r.contentBytes ~= nil then
        return false, "unqualified-native-reading"
    end
    if r.status == "completed" and (not r.nativeStarted or not r.nativeCompleted
        or not r.custodyVerified or r.progress <= 0
        or not note and r.totalPages > 0 and (r.pagesAfter <= r.pagesBefore or r.pagesAfter < r.totalPages)) then
        return false, "unmeasured-reading-completion"
    end
    if r.mood ~= nil and (r.status ~= "completed" or r.moodMeasurement ~= "immediate-native-completion")
        or r.mood == nil and r.moodMeasurement ~= nil then return false, "unmeasured-reading-mood" end
    local itemId = tonumber(r.itemId)
    if not finite(itemId, -2147483648, 2147483647) or itemId ~= math.floor(itemId) then
        return false, "invalid-reading-item"
    end
    local x = privateFact(id, "leisure-reading", "leisure", "leisure-reading/"..id.."/"..tostring(sequence), now, r.atHours)
    x.sourceId, x.itemId, x.itemType, x.actionKind = r.sourceId, itemId, r.itemType, r.actionKind
    x.succeeded, x.stats = r.status == "completed", detached(r.mood)
    if r.mood ~= nil and x.stats == nil then return false, "invalid-reading-mood" end
    return nativeExperience(id, "leisure-reading", sequence, x)
end
-- Native participation is a private execution fact. Pleasure and mastery need
-- their own measured source evidence; interval effects may have other causes.
function C.hobbyOutcome(id,ownerName,sequence)
    local kinds={ ["SAO.Leisure"]="leisure-meditation",["SAO.LeisureExercise"]="leisure-exercise",
        ["SAO.LeisureArt"]="leisure-art",["SAO.LeisureMusic"]="leisure-music",["SAO.LeisureGames"]="leisure-games",["SAO.LeisureRadio"]="leisure-radio",["SAO.LeisureLifestyle"]="leisure-lifestyle" }
    local owners={ ["SAO.Leisure"]=SAO.Leisure,["SAO.LeisureExercise"]=SAO.LeisureExercise,
        ["SAO.LeisureArt"]=SAO.LeisureArt,["SAO.LeisureMusic"]=SAO.LeisureMusic,["SAO.LeisureGames"]=SAO.LeisureGames,["SAO.LeisureRadio"]=SAO.LeisureRadio,["SAO.LeisureLifestyle"]=SAO.LeisureLifestyle }
    local kind,owner,now=kinds[ownerName],owners[ownerName],clock()
    if not now or not kind or not owner or not owner.outcome or not finite(sequence,1,9007199254740991)
        or sequence~=math.floor(sequence) then return false,"hobby-owner-unavailable" end
    local receipt=owner.outcome(id,sequence)
    if type(receipt)~="table" or receipt.actorId~=id or receipt.sequence~=sequence
        or not text(receipt.workId,160) or not text(receipt.purposeId,160)
        or not text(receipt.sourceId,160) or not text(receipt.revision,160)
        or not text(receipt.activity,96) or not finite(receipt.atHours,0,now)
        or not finite(receipt.admittedAtHours,0,receipt.atHours)
        or (receipt.status~="completed" and receipt.status~="interrupted") then return false,"unqualified-hobby" end
    local binding=SAO.ProceduralPlanning and SAO.ProceduralPlanning.hobbyAdmission
        and SAO.ProceduralPlanning.hobbyAdmission(id,receipt.purposeId,receipt.workId,true)
    if not binding or binding.ownerName~=ownerName then return false,"hobby-admission-unavailable" end
    for _,key in ipairs({"actorId","sequence","workId","purposeId","sourceId","revision","activity",
        "itemKey","itemType","bodyGenerationKnown","bodyToken","admittedAtHours","nativeOwner"}) do
        if binding[key]~=receipt[key] then return false,"hobby-binding-changed" end
    end
    local x=privateFact(id,kind,"leisure",kind.."/"..id.."/"..tostring(sequence),now,receipt.atHours)
    x.sourceId,x.itemType,x.actionKind,x.succeeded=receipt.sourceId,receipt.itemType,receipt.activity,receipt.status=="completed"
    x.detail="Native attempt; interval effects have concurrent causes; source revision "..receipt.revision
    return nativeExperience(id,kind,sequence,x)
end

-- A duet is acquired by each performer only after Organization holds both
-- exact committed native outcomes. The private model learns that this pairing
-- happened; measured mood remains in that person's source receipt and is not
-- interpreted as pleasure, trust or a change in their relationship.
function C.duetOutcome(id,processId)
    local now=clock()
    local O=SAO.Organization
    local receipt=O and O.duetParticipationFor and O.duetParticipationFor(id,processId)
    local shared=receipt and receipt.coPerformance
    if not now or type(receipt)~="table" or receipt.actorId~=id
        or receipt.processId~=processId or not text(receipt.processId,160)
        or not text(receipt.partnerId,128) or receipt.partnerId==id
        or not finite(receipt.revision,1,9007199254740991)
        or receipt.revision~=math.floor(receipt.revision)
        or receipt.sourceId~="LifestyleHobbies"
        or not finite(receipt.sequence,1,9007199254740991)
        or receipt.sequence~=math.floor(receipt.sequence)
        or not finite(receipt.atHours,0,now)
        or receipt.measurementAuthority~="actual-source-interval; concurrent-effects-not-isolated"
        or type(receipt.before)~="table" or type(receipt.after)~="table"
        or type(shared)~="table" or shared.status~="completed"
        or shared.basis~="two-committed-native-source-duet-results"
        or shared.ownResultId~=receipt.workId
        or not text(shared.partnerResultId,160) then
        return false,"duet-source-unavailable" end
    local x=privateFact(id,"leisure-duet","leisure","",now,receipt.atHours)
    x.sourceId,x.actionKind,x.succeeded="LifestyleHobbies","duet",true
    x.partnerId,x.processId,x.processRevision=receipt.partnerId,
        receipt.processId,receipt.revision
    x.detail="Two committed native performances; own interval effects have concurrent causes."
    return pairedSourceExperience(id,receipt,"duet","leisure-duet",x)
end

-- Source partner dance reaches memory only after both exact native cycles
-- have completed and Organization has frozen each actor's own measurements.
-- This supports a later feasibility estimate, not an enjoyment or trust claim.
function C.danceOutcome(id,processId)
    local now=clock()
    local O=SAO.Organization
    local receipt=O and O.danceParticipationFor and O.danceParticipationFor(id,processId)
    local shared=receipt and receipt.coPerformance
    if not now or type(receipt)~="table" or receipt.actorId~=id
        or receipt.processId~=processId or not text(receipt.processId,160)
        or not text(receipt.partnerId,128) or receipt.partnerId==id
        or not finite(receipt.revision,1,9007199254740991)
        or receipt.revision~=math.floor(receipt.revision)
        or receipt.sourceId~="LifestyleHobbies"
        or not text(receipt.musicKey,160)
        or (receipt.role~="source" and receipt.role~="target")
        or not finite(receipt.sequence,1,9007199254740991)
        or receipt.sequence~=math.floor(receipt.sequence)
        or not finite(receipt.atHours,0,now)
        or receipt.measurementAuthority~="actual-source-interval; concurrent-effects-not-isolated"
        or type(receipt.before)~="table" or type(receipt.after)~="table"
        or type(shared)~="table" or shared.status~="completed"
        or shared.basis~="two-committed-native-source-dance-results"
        or shared.ownResultId~=receipt.workId
        or not text(shared.partnerResultId,160) then
        return false,"dance-source-unavailable" end
    local x=privateFact(id,"leisure-dance","leisure","",now,receipt.atHours)
    x.sourceId,x.actionKind,x.succeeded="LifestyleHobbies","dance",true
    x.partnerId,x.processId,x.processRevision=receipt.partnerId,
        receipt.processId,receipt.revision
    x.musicKey,x.role=receipt.musicKey,receipt.role
    x.detail="Two committed native dance cycles; own interval effects have concurrent causes."
    return pairedSourceExperience(id,receipt,"dance","leisure-dance",x)
end
function C.commitmentOutcome(id,receipt)
    local now=clock()
    if not now or type(receipt)~="table" or receipt.actorId~=id or receipt.status~="completed"
        or (receipt.workKind~="prepare" and receipt.workKind~="deliver"
            and receipt.workKind~="watch-return")
        or not text(receipt.commitmentId,160) or not text(receipt.nativeReceiptId,160)
        or not finite(receipt.sequence,1,9007199254740991) or receipt.sequence~=math.floor(receipt.sequence)
        or not finite(receipt.atHours,0,now) or not finite(receipt.acceptedAt,0,receipt.atHours) then return false,"unqualified-commitment-work" end
    local canonical=SAO.Organization and SAO.Organization.fulfilledWorkOutcome
        and SAO.Organization.fulfilledWorkOutcome(id,receipt.sequence)
    if not canonical or not sameData(canonical,receipt) then return false,"commitment-owner-unavailable" end
    local x=privateFact(id,"commitment-outcome","social","commitment/"..id.."/"..tostring(receipt.sequence),now,receipt.atHours)
    x.sourceId,x.actionKind,x.succeeded=receipt.commitmentId,receipt.workKind,true
    return nativeExperience(id,"commitment",receipt.sequence,x)
end

function C.medicationUse(id, receipt)
    local now = clock()
    if not now or type(receipt) ~= "table" or receipt.actorId ~= id
        or receipt.status ~= "completed" or receipt.consumed ~= 1
        or not finite(receipt.sequence, 1, 9007199254740991) or receipt.sequence ~= math.floor(receipt.sequence)
        or not finite(receipt.atHours, 0, now) then return false, "unqualified-medication-use" end
    local x = privateFact(id, "medication-use", "medicine", "medication/" .. tostring(receipt.sequence), now, receipt.atHours)
    x.itemId, x.itemType = receipt.itemId, receipt.itemType
    -- family/profile/dose efficacy from the producer never enters cognition.
    return nativeExperience(id, "medication", receipt.sequence, x)
end
function C.physicalChange(id, receipt)
    local now = clock()
    if not now or type(receipt) ~= "table" or receipt.kind ~= "physical-change"
        or not finite(receipt.minute, 0, 60000000000) or receipt.minute ~= math.floor(receipt.minute)
        or not finite(receipt.atHours, 0, now) or math.abs(receipt.atHours - receipt.minute / 60) > 0.00000001
        or not finite(receipt.observedAtHours, receipt.atHours, now)
        or receipt.actorId ~= nil and receipt.actorId ~= id then return false, "unqualified-physical-change" end
    local x = privateFact(id, "physical-change", "body", "physical/" .. tostring(receipt.minute), receipt.observedAtHours, receipt.atHours)
    x.stats = detached(receipt.stats)
    -- Only the felt values cross this boundary. In particular, exposures and
    -- last-dose/family counters are God-view accounting, not private evidence.
    return nativeExperience(id, "physical", receipt.minute, x)
end
-- The animal owner retains the full native completion proof. Only this
-- person's performed feed transfer crosses into their private experience.
function C.animalCareOutcome(id, receipt)
    local now, rec = clock(), record(id)
    if not now or not rec or type(receipt) ~= "table" or receipt.actorId ~= id
        or receipt.kind ~= "feed" or receipt.status ~= "completed"
        or receipt.reason ~= "native-feed-consumed"
        or not finite(receipt.position, 1, 9007199254740991)
        or receipt.position ~= math.floor(receipt.position)
        or receipt.id ~= "animal-care/" .. tostring(id) .. "/" .. tostring(receipt.position)
        or not finite(receipt.worldHours, 0, now)
        or not finite(receipt.consumedAmount, 0.000000001, 1000000000) then
        return false, "unqualified-animal-care"
    end
    local canonical
    for _, row in ipairs(rec.animalCare and rec.animalCare.outcomes or {}) do
        if row.id == receipt.id then canonical = row break end
    end
    if not canonical or not sameData(canonical, receipt) then
        return false, "animal-care-owner-unavailable"
    end
    local x = privateFact(id, "animal-care", "animal", receipt.id, now, receipt.worldHours)
    x.sourceId = "animal/" .. tostring(receipt.animalId)
    x.itemId, x.itemType = receipt.itemId, receipt.itemType
    x.consumedAmount, x.quantityUnit = receipt.consumedAmount, receipt.quantityUnit
    return nativeExperience(id, "animal-care", receipt.position, x)
end

-- The repair owner keeps geometry, material and native completion proof.
-- Private experience records only the actor's performed replacement.
function C.windowRepairOutcome(id, receipt)
    local now, rec = clock(), record(id)
    if not now or not rec or type(receipt) ~= "table" or receipt.actorId ~= id
        or receipt.status ~= "completed" or receipt.paneConsumed ~= true
        or receipt.nativeAttempted ~= true or receipt.smashedBefore ~= true
        or receipt.smashedAfter ~= false or receipt.glassRemovedAfter ~= false
        or receipt.nativeOwner ~= "AddWindowAction.complete"
        or not finite(receipt.sequence, 1, 9007199254740991)
        or receipt.sequence ~= math.floor(receipt.sequence)
        or receipt.id ~= id .. "/window-result/" .. tostring(receipt.sequence)
        or not finite(receipt.endedAt, 0, now) then
        return false, "unqualified-window-repair"
    end
    local owner = SAO.WindowRepair
    local authoritative = owner and owner.outcome and owner.outcome(id, receipt.sequence)
    if not authoritative or not sameData(authoritative, receipt) then
        return false, "window-repair-owner-unavailable"
    end
    local x = privateFact(id, "window-repair", "construction", receipt.id, now, receipt.endedAt)
    x.sourceId, x.itemId, x.itemType = receipt.entryKey, tonumber(receipt.itemId), receipt.fullType
    return nativeExperience(id, "window-repair", receipt.sequence, x)
end

-- The native transformation owner certifies exact inputs and held outputs.
-- This private fact records performed crafting; competence stays native.
function C.materialCraftOutcome(id, receipt)
    local now = clock()
    if not now or type(receipt) ~= "table" or receipt.actorId ~= id
        or receipt.kind ~= "saw-logs" or receipt.recipeId ~= "Base.SawLogs"
        or receipt.nativeOwner ~= "ISHandcraftAction" or receipt.token ~= "resource:crafted"
        or not finite(receipt.sequence, 1, 9007199254740991) or receipt.sequence ~= math.floor(receipt.sequence)
        or receipt.id ~= "resource-production/" .. id .. "/" .. tostring(receipt.sequence)
        or not finite(receipt.atHours, 0, now) or not finite(receipt.startedAt, 0, receipt.atHours) then
        return false, "unqualified-material-crafting"
    end
    local owner = SAO.ResourceProduction
    local canonical = owner and owner.outcome and owner.outcome(id, receipt.id)
    if not canonical or not sameData(canonical, receipt) then return false, "craft-owner-unavailable" end
    if receipt.status == "failed" or receipt.status == "interrupted" then return true, "unfinished-craft-retained-by-planner" end
    if receipt.status ~= "completed" or receipt.nativeCredit ~= receipt.id or receipt.nativeAttempted ~= true
        or receipt.logConsumed ~= true or receipt.sawRetained ~= true or receipt.held ~= true
        or receipt.outputCount ~= 3 or type(receipt.outputs) ~= "table" or #receipt.outputs ~= 3 then return false end
    local ids = {}
    for _, output in ipairs(receipt.outputs) do
        local itemId = type(output) == "table" and tonumber(output.itemId) or nil
        if not itemId or not finite(itemId, -2147483648, 2147483647) or itemId ~= math.floor(itemId)
            or output.itemType ~= "Base.Plank" or ids[itemId] then return false end
        ids[itemId] = true
    end
    local x = privateFact(id, "material-crafting", "construction", receipt.id, now, receipt.atHours)
    x.sourceId, x.itemId, x.itemType = receipt.recipeId, tonumber(receipt.outputs[1].itemId), "Base.Plank"
    return nativeExperience(id, "material-crafting", receipt.sequence, x)
end

function C.toolRepairOutcome(id, receipt)
    local now = clock()
    if not now or type(receipt) ~= "table" or receipt.actorId ~= id
        or receipt.kind ~= "repair-held-item" or receipt.recipeId ~= "Base.FixSaw"
        or receipt.nativeOwner ~= "ISHandcraftAction" or receipt.token ~= "resource:repaired"
        or not finite(receipt.sequence, 1, 9007199254740991) or receipt.sequence ~= math.floor(receipt.sequence)
        or receipt.id ~= "resource-production/" .. id .. "/" .. tostring(receipt.sequence)
        or not finite(receipt.atHours, 0, now) or not finite(receipt.startedAt, 0, receipt.atHours) then return false end
    local owner = SAO.ResourceProduction
    local canonical = owner and owner.outcome and owner.outcome(id, receipt.id)
    if not canonical or not sameData(canonical, receipt) then return false, "repair-owner-unavailable" end
    if receipt.status == "interrupted" or receipt.nativeCompleted ~= true then
        return true, "unfinished-repair-retained-by-planner"
    end
    if receipt.nativeAttempted ~= true or receipt.targetRetained ~= true or receipt.held ~= true
        or not finite(receipt.beforeCondition, 1, 1000000000)
        or not finite(receipt.maxCondition, receipt.beforeCondition, 1000000000)
        or not finite(receipt.afterCondition, 0, receipt.maxCondition)
        or (receipt.status ~= "completed" and receipt.status ~= "failed") then return false end
    local improved = receipt.afterCondition > receipt.beforeCondition
    if receipt.improved ~= improved or (improved and (receipt.status ~= "completed" or receipt.nativeCredit ~= receipt.id))
        or (not improved and (receipt.status ~= "failed" or receipt.nativeCredit ~= nil)) then return false end
    local itemId = tonumber(receipt.targetItemId)
    if not itemId or not finite(itemId, -2147483648, 2147483647) or itemId ~= math.floor(itemId) then return false end
    local x = privateFact(id, "tool-repair", "construction", receipt.id, now, receipt.atHours)
    x.status = improved and "completed" or "no-effect"
    x.sourceId, x.itemId, x.itemType = receipt.recipeId, itemId, receipt.targetItemType
    x.beforeValue, x.afterValue = receipt.beforeCondition, receipt.afterCondition
    return nativeExperience(id, "tool-repair", receipt.sequence, x)
end

function C.preparationOutcome(id, receipt)
    local now = clock()
    if not now or type(receipt) ~= "table" or receipt.actorId ~= id
        or not finite(receipt.sequence, 1, 9007199254740991) or receipt.sequence ~= math.floor(receipt.sequence)
        or receipt.id ~= "cooking/" .. tostring(id) .. "/" .. tostring(receipt.sequence)
        or receipt.status ~= "completed" or receipt.detail ~= "native-food-cooked-and-retrieved"
        or receipt.nativeCredit ~= receipt.id or receipt.retrieved ~= true or receipt.heatObserved ~= true
        or not finite(receipt.atHours, 0, now) or not finite(receipt.startedAt, 0, receipt.atHours) then
        return false, "unqualified-preparation"
    end
    local canonical=SAO.Cooking and SAO.Cooking.outcome and SAO.Cooking.outcome(id,receipt.sequence)
    if not canonical or not sameData(canonical,receipt) then return false,"preparation-owner-unavailable" end
    local x = privateFact(id, "preparation", "food", receipt.id, now, receipt.atHours)
    x.itemId, x.itemType, x.sourceId = receipt.itemId, receipt.itemType, receipt.sourceId
    x.beforeCookingTime, x.afterCookingTime, x.heatObserved = receipt.beforeCookingTime, receipt.afterCookingTime, true
    return nativeExperience(id, "preparation", receipt.sequence, x)
end
-- A result reader is independent of Provisioning's acknowledgement stream.
function C.sourceResult(receipt, token)
    if type(receipt) ~= "table" or not token or receipt.actorId ~= token.actorId then return false end
    local quantity = tonumber(receipt.observedQuantity)
    local status = receipt.status == "completed" and quantity and quantity > 0 and "completed" or "unavailable"
    if receipt.status == "interrupted" or receipt.status == "released" then status = "interrupted" end
    local values = { kind = receipt.operation, category = receipt.category, sourceId = receipt.sourceId,
        itemType = receipt.itemType, status = status, detail = receipt.detail }
    if receipt.category == "drink" then
        local intent = token.hydrationAdmission
        local owner = SAO.WorldSources
        local native = intent and owner and owner.actionOutcome
            and owner.actionOutcome(receipt.reservationId, receipt.actorId)
        if receipt.operation ~= "acquire" or not native or native.category ~= "drink"
            or native.operation ~= "acquire" or native.sourceId ~= intent.sourceId
            or native.itemId ~= intent.itemId or native.preRevision ~= intent.revision
            or receipt.reservationId ~= intent.reservationId or native.status ~= receipt.status
            or receipt.sourceId ~= native.sourceId or receipt.itemId ~= native.itemId
            or receipt.itemType ~= native.itemType or receipt.preRevision ~= native.preRevision
            or receipt.observedQuantity ~= native.observedQuantity then return false end
        -- Admission relates this material to thirst. Transfer never reports
        -- relief; the native carried-drink callback measures that separately.
        values.category = "water"
    end
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
    for i = first, #s.episodes do
        local episode=episodeCopy(s.episodes[i])
        if not episode then return nil end
        out.episodes[#out.episodes + 1]=episode
    end
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
                if not removed then return nil end
            end
        end
    end
    return out
end

-- Plan interpretation is read-only. Both contestants receive detached copies
-- of the same person's candidates and their own model state; neither sees the
-- other's answer and selection here does not create an execution episode.
local function planFrame(id, context)
    local now = clock()
    if not record(id) or not now or type(context) ~= "table"
        or context.actorId ~= nil and context.actorId ~= id then return nil end
    local frame = detached(context)
    if not frame then return nil end
    frame.actorId = id
    frame.atHours = frame.atHours or now
    frame.pressure = frame.pressure or 0
    -- Capabilities are read from the current person. They cannot supply a
    -- prior for an earlier frame after that person's competence has changed.
    if not finite(frame.atHours, 0, now) or frame.atHours ~= now then return nil end
    if frame.domain ~= nil and not text(frame.domain, 80) then return nil end
    frame.capabilities = C.capabilities(id)
    return frame
end
local function planModel(id, frame)
    local settings = C.settings()
    if not settings.enabled then return "ordinary" end
    if not finite(settings.opportunitiesPerHour, 1, 60)
        or not finite(settings.opponentShare, 0, 1) then return "ordinary" end
    -- Stable for this private decision interval. Re-reading a plan does not
    -- spend an opportunity, revise evidence or switch its selected contestant.
    local interval = math.floor(frame.atHours * settings.opportunitiesPerHour)
    local draw = SAO.Hash and SAO.Hash.unit(id,
        "plan-selection:" .. tostring(frame.domain or "activity") .. ":" .. tostring(interval)) or 0.5
    return draw < settings.opponentShare and "associative" or "ordinary"
end
function C.scorePlan(id, candidate, context)
    local frame = planFrame(id, context)
    if not frame or not SAO.CognitiveModels then return nil end
    local name, s = planModel(id, frame), state(id, false)
    if record(id).cognition ~= nil and not s then return nil end
    if not C.settings().enabled then s = nil end
    local own = s and detached(s.models[name]) or SAO.CognitiveModels.newState(name)
    local offered = detached(candidate)
    if not own or not offered then return nil end
    local ok, result = pcall(SAO.CognitiveModels.interpretPlans, name, own, { offered }, frame)
    return ok and type(result) == "table" and result.score or nil
end
function C.interpretPlans(id, candidates, context)
    local frame = planFrame(id, context or {})
    if not frame or not SAO.CognitiveModels
        or type(SAO.CognitiveModels.interpretPlans) ~= "function" then return nil end
    local s, offered = state(id, false), detached(candidates)
    if not offered then return nil end
    if record(id).cognition ~= nil and not s then return nil end
    -- An existing private scanner receipt may be learned before this person's
    -- next plan. A malformed or unavailable journal cannot block urgent plans.
    if C.settings().enabled then
        pcall(C.weekOnePerformanceHearings, id)
        s = state(id, false)
        if record(id).cognition ~= nil and not s then return nil end
    end
    local enabled = C.settings().enabled
    if not enabled then s = nil end
    local interest
    if enabled and frame.domain == "leisure-action" then
        interest = C.weekOneMusicInterest(id)
        if interest.informationGain > 0 then
            for _, candidate in ipairs(offered) do
                if candidate.kind == "instrument"
                    and finite(candidate.informationGain, 0, 1)
                    and candidate.utility == nil then
                    candidate.informationGain = math.min(1,
                        candidate.informationGain + interest.informationGain)
                end
            end
        end
    end
    local out = { models = {}, selectedModelId = planModel(id, frame),
        selectionPolicy = "deterministic-private-interval", atHours = frame.atHours,
        purposes = frame.purposes,
        decisionPersonState = decisionPersonState(id, {id = "plan:"..tostring(frame.domain or "activity"),
            worldHours = frame.atHours}, frame.atHours) }
    if interest and interest.status ~= "unobserved" then
        out.heardMusicInterest = detached(interest)
    end
    for _, name in ipairs(MODEL_IDS) do
        local own = s and detached(s.models[name]) or SAO.CognitiveModels.newState(name)
        if not own then return nil end
        local ok, view = pcall(SAO.CognitiveModels.interpretPlans, name,
            own, copy(offered), detached(frame))
        if not ok or type(view) ~= "table" then return nil end
        out.models[#out.models + 1] = view
        if name == out.selectedModelId then out.selected = view.selected end
    end
    out.disagreement = out.models[1].selected ~= out.models[2].selected
    return out
end
-- Ordinary inquiry and contact appraisal share acquired person evidence.
-- Input exploration uses the source's presented scene and valid controls.
-- A later visual change is an observation after input, not a causal win label.
function C.chooseGameInput(id,body)
    local r,now=record(id),clock()
    local G,P=SAO.LeisureGames,SAO.ProceduralPlanning
    if not r or not now or not G or not G.context or not G.inputOffers or not G.submitInput
        or not SAO.Needs.ownsRecoveryBody(id,body) or not P or not P.hobbyAdmission then return false end
    local scene=G.context(id,body)
    if not scene or scene.actorId~=id or scene.status~="presented-source-scene" or scene.atHours~=now
        or not text(scene.workId,160) or not text(scene.sourceId,160) or not text(scene.revision,160)
        or not finite(scene.frameId,1,9007199254740991) or type(scene.commands)~="table" then return false end
    local work=G.work and G.work(id)
    local admission=work and P.hobbyAdmission(id,work.purposeId,scene.workId)
    if not admission or admission.ownerName~="SAO.LeisureGames" or work.actorId~=id
        or work.sequence~=scene.workSequence or work.sourceId~=scene.sourceId or work.revision~=scene.revision then return false end
    local value=SAO.Disposition and SAO.Disposition.curiosity and SAO.Disposition.curiosity(id)
    if not value or not finite(value.effective,0,1) then return false end
    local memory=r.gameInputExperience
    if memory and (memory.actorId~=id or type(memory.sources)~="table" or type(memory.order)~="table") then return false end
    memory=memory or {actorId=id,sources={},order={},observations={},omittedSources=0,omittedObservations=0}
    local sourceKey=scene.sourceId..":"..scene.revision
    local own=memory.sources[sourceKey] or {counts={},lastInput=nil}
    if own.workId==scene.workId and own.frameId==scene.frameId then return false end
    local textRows={}
    for i,command in ipairs(scene.commands) do
        if i>256 then break end
        if command.kind=="text" and type(command.args)=="table" and type(command.args[1])=="string" then
            textRows[#textRows+1]=command.args[1]:sub(1,256)
        end
    end
    local offered={}
    for i,input in ipairs(G.inputOffers(id,body)) do
        if i>128 then return false end
        if input.actorId~=id or input.workId~=scene.workId or input.workSequence~=scene.workSequence
            or input.frameId~=scene.frameId or input.sourceId~=scene.sourceId or input.revision~=scene.revision
            or not text(input.id,256) or type(input.keys)~="table" or #input.keys>2 then return false end
        local keys=table.concat(input.keys,"+")
        local tries=own.counts[keys] or 0
        if not finite(tries,0,9007199254740991) then return false end
        offered[#offered+1]={input=input,key=keys,tries=tries,novelty=#input.keys>0 and 1/(1+tries) or 0}
    end
    if #offered==0 then return false end
    table.sort(offered,function(a,b)
        if a.novelty~=b.novelty then return a.novelty>b.novelty end
        if #a.input.keys~=#b.input.keys then return #a.input.keys<#b.input.keys end
        return a.key<b.key
    end)
    local candidates,receivers={},{}
    for i,row in ipairs(offered) do
        if i>16 then break end
        local instruction=0
        if SAO.History.literacyOf and SAO.History.literacyOf(id)=="reads" and type(scene.labels)=="table" then
            for _,key in ipairs(row.input.keys) do
                local label=scene.labels[key]
                if text(label,80) then for _,line in ipairs(textRows) do
                    local words=line:upper()
                    local start,ending=words:find(label:upper(),1,true)
                    while start do
                        local before,after=words:sub(start-1,start-1),words:sub(ending+1,ending+1)
                        if not before:match("[%w_]") and not after:match("[%w_]")
                            and (words:find("START",1,true) or words:find("CONTINUE",1,true)) then instruction=0.2 end
                        start,ending=words:find(label:upper(),ending+1,true)
                    end
                end end
            end
        end
        candidates[#candidates+1]={id=row.input.id,evidence=1,continuity=own.lastInput==row.key and 1 or 0,
            novelty=row.novelty,informationGain=row.novelty,blockers=0,consequences={},
            utility=0.05+value.effective*0.3*row.novelty
                +(own.lastInput==row.key and 0.1*(1-value.effective) or 0)+instruction,
            displayedInstruction=instruction>0 and "presented label with start or continue instruction" or nil,
            curiosityBasis="uncalibrated exploration of source-valid controls"}
        receivers[row.input.id]=row
    end
    local view=C.interpretPlans(id,candidates,{domain="game-input",atHours=now,pressure=0})
    local selected=view and receivers[view.selected]
    local fresh=G.context(id,body)
    if not selected or not fresh or fresh.actorId~=id or fresh.workId~=scene.workId
        or fresh.frameId~=scene.frameId or fresh.sourceId~=scene.sourceId or fresh.revision~=scene.revision
        or not P.hobbyAdmission(id,work.purposeId,scene.workId) or not G.submitInput(id,body,selected.input) then return false end
    if not memory.sources[sourceKey] then
        if #memory.order>=32 then memory.sources[table.remove(memory.order,1)]=nil;memory.omittedSources=memory.omittedSources+1 end
        memory.order[#memory.order+1]=sourceKey;memory.sources[sourceKey]=own
    end
    if own.pending and own.pending.workId==scene.workId then
        if #memory.observations>=32 then table.remove(memory.observations,1);memory.omittedObservations=memory.omittedObservations+1 end
        memory.observations[#memory.observations+1]={actorId=id,workId=scene.workId,sourceId=scene.sourceId,
            revision=scene.revision,previousInput=own.pending.keys,previousFrameId=own.pending.frameId,
            frameId=scene.frameId,previousText=own.pending.text,presentedText=detached(textRows),atHours=now,
            interpretation="presented after own input; causal effect remains uncertain"}
    end
    own.counts[selected.key]=selected.tries+1;own.lastInput=selected.key;own.workId=scene.workId;own.frameId=scene.frameId
    own.pending={workId=scene.workId,keys=detached(selected.input.keys),frameId=scene.frameId,text=detached(textRows)}
    r.gameInputExperience=memory
    r.gameInputDecision={actorId=id,workId=scene.workId,sourceId=scene.sourceId,revision=scene.revision,
        frameId=scene.frameId,atHours=now,selected=selected.input.id,keys=detached(selected.input.keys),
        curiosity=detached(value),presentedText=detached(textRows),viewport=detached(scene.viewport),
        interpretations=view,alternatives=detached(candidates),omittedAlternatives=math.max(0,#offered-16),
        status="source-input-accepted",completionCredit=false,skillCredit=false}
    return true
end
-- This query neither spends an opportunity nor admits an investigation.
function C.appraiseSituation(id,body,tick)
    if not SAO.SituationAppraisal or not SAO.SituationAppraisal.query then return nil end
    return SAO.SituationAppraisal.query(id,body,tick)
end
-- Shared conflict appraisal is a pure private query. Only the person's own
-- disposition and acquired concept owner supply values and associations.
function C.appraiseConflict(id, supplied, candidates)
    local person,now=record(id),clock()
    if not person or not now or type(supplied)~="table" or supplied.actorId~=id
        or not finite(supplied.atHours,0,now) or type(supplied.threat)~="table"
        or type(candidates)~="table" or #candidates<1 or #candidates>16
        or not SAO.CognitiveModels or not SAO.Disposition then return nil,"invalid-private-conflict" end
    local own=SAO.Disposition.conflictValues and SAO.Disposition.conflictValues(id)
    if not own or type(supplied.values)~="table" or supplied.values.actorId~=id then return nil,"foreign-conflict-values" end
    for _,key in ipairs({"selfPreservation","aggression","nerve","discipline","compassion"}) do
        if not finite(own[key],0,1) or own[key]~=supplied.values[key] then return nil,"changed-conflict-values" end
    end
    local threat=supplied.threat
    if threat.distance~=nil and not finite(threat.distance,0,100000)
        or threat.count~=nil and not finite(threat.count,0,100000)
        or threat.at~=nil and not finite(threat.at,0,1000000000000)
        or not finite(supplied.fear,0,1)
        or type(supplied.overwhelmed)~="boolean" or type(supplied.escapeBlocked)~="boolean" then return nil,"invalid-conflict-pressure" end
    local frame={actorId=id,atHours=supplied.atHours,values=detached(own),fear=supplied.fear,
        overwhelmed=supplied.overwhelmed,escapeBlocked=supplied.escapeBlocked,relations={},
        threat={distance=threat.distance,count=threat.count or 0,at=threat.at}}
    local geometry=SAO.CognitiveModels.contactGeometry(threat)
    if not geometry then return nil,"invalid-conflict-geometry" end
    if threat.observerZ~=nil then
        local observerOk,currentZ=pcall(function()return math.floor(SAO.Body.get(id):getZ())end)
        if not observerOk or currentZ~=threat.observerZ then return nil,"changed-conflict-observer-floor" end
    end
    frame.threat.z,frame.threat.observerZ=threat.z,threat.observerZ
    frame.threat.floorKnown,frame.threat.sameFloor=geometry.floorKnown,geometry.sameFloor
    frame.threat.reachability=geometry.reachability
    for _,key in ipairs({"kind","key","source"}) do
        if threat[key]~=nil and not text(threat[key],128) then return nil,"invalid-conflict-threat" end
        frame.threat[key]=threat[key] or "unknown"
    end
    if supplied.risk~=nil or threat.risk~=nil then return nil,"caller-conflict-risk-refused" end
    if threat.form~=nil and threat.form~="none" then
        if not text(threat.form,96) or not finite(threat.formPerformance or 0,0,1)
            or (threat.source~="observed" and threat.source~="told")
            or not SAO.PathogenPressure or not SAO.PathogenPressure.appraise then return nil,"invalid-recognized-conflict-form" end
        frame.threat.form=threat.form;frame.threat.formPerformance=threat.formPerformance or 0
        frame.threat.attributeMutations={}
        if threat.attributeMutations~=nil then
            if type(threat.attributeMutations)~="table" then return nil,"invalid-recognized-conflict-attributes" end
            local count=0
            for key,value in pairs(threat.attributeMutations) do
                count=count+1
                if count>32 or not text(key,96) or not finite(value,0,1) then return nil,"invalid-recognized-conflict-attributes" end
                frame.threat.attributeMutations[key]=value
            end
        end
        frame.risk=SAO.PathogenPressure.appraise(id,frame.threat)
        if not frame.risk or frame.risk.actorId~=id or frame.risk.contactKey~=frame.threat.key
            or frame.risk.source~=frame.threat.source then return nil,"foreign-conflict-risk" end
    end
    if supplied.commitment~=nil then
        local c=supplied.commitment
        if type(c)~="table" or c.key~=nil and not text(c.key,128)
            or c.kind~=nil and not text(c.kind,64) then return nil,"invalid-conflict-commitment" end
        frame.commitment={key=c.key,kind=c.kind,accepted=c.accepted==true,protectOther=c.protectOther==true}
    end
    local offered=detached(candidates)
    if not offered then return nil,"invalid-conflict-offers" end
    -- Whitelist the executor's scalar offer. No body, another person's state,
    -- or hidden world object can cross the shared interpretation boundary.
    local allowed={id=true,kind=true,available=true,reason=true,effects=true,objections=true,
        nativeMode=true,targetKey=true,routeKey=true,continuing=true}
    for _,offer in ipairs(offered) do
        if type(offer)~="table" then return nil,"invalid-conflict-offer" end
        for key in pairs(offer) do if not allowed[key] then return nil,"foreign-conflict-field" end end
        for _,key in ipairs({"nativeMode","targetKey","routeKey"}) do
            if offer[key]~=nil and not text(offer[key],128) then return nil,"invalid-conflict-target" end
        end
        if offer.kind=="engage" or offer.kind=="defend" then
            if offer.available and (not offer.nativeMode or not offer.targetKey) then return nil,"native-conflict-target-required" end
        end
        if offer.kind=="withdraw" and offer.available then frame.escapeBlocked=false end
    end
    local associations={ ["bodily-harm"]="assault",["break-contact"]="separation",
        ["blocks-movement"]="obstruction",["create-space"]="defense",["stop-threat"]="force",
        ["possible-agreement"]="communication",["mutual-support"]="cooperation",
        ["imposed-compliance"]="coercion",["concession:possible-agreement"]="concession",
        ["concession:create-space"]="concession" }
    local contextKey=frame.threat.key:match("^[%w_:%-%.]+$") and #frame.threat.key<=96 and frame.threat.key or nil
    for effect,from in pairs(associations) do
        local ok,inference=pcall(function()
            return SAO.ConceptKnowledge and SAO.ConceptKnowledge.infer(id,from,
                effect:gsub("^concession:",""),contextKey)
        end)
        local path=ok and type(inference)=="table" and type(inference.paths)=="table" and inference.paths[1]
        frame.relations[effect]={supported=path~=nil,basis=path and "personal-relational-expectation"
            or ok and inference and inference.status=="challenged" and "personally-challenged" or "unresolved",
            from=from,into=effect:gsub("^concession:",""),evidenceIds=path and detached(path.evidenceIds) or {},
            links=path and detached(path.roots) or {},
            contradictions=ok and inference and detached(inference.contradictions) or {}}
    end
    -- Changes of clock or exact distance within the same tactical envelope do
    -- not abandon an executing choice. Changed premises or feasibility do.
    local material=detached(frame)
    material.atHours=nil;material.threat.at=nil
    material.threat.distance=threat.distance==nil and "unknown" or geometry.close and "close"
        or threat.distance<=8 and "near" or "distant"
    material.offers=detached(offered)
    table.sort(material.offers,function(a,b)return tostring(a.id)<tostring(b.id)end)
    for _,offer in ipairs(material.offers) do offer.continuing=nil;offer.reason=nil end
    local function serial(value)
        if type(value)~="table" then local s=tostring(value);return type(value)..":"..#s..":"..s end
        local keys={} for key in pairs(value) do keys[#keys+1]=key end
        SAO.Perception.sortEvidence(keys,function(a,b)return tostring(a)<tostring(b)end)
        local parts={"{"} for _,key in ipairs(keys) do parts[#parts+1]=serial(key)..serial(value[key]) end
        parts[#parts+1]="}";return table.concat(parts)
    end
    local encoded=serial(material)
    local first,second=0,0
    for i=1,#encoded do
        local byte=string.byte(encoded,i)
        first=(first*31+byte)%2147483647;second=(second*37+byte)%2147483629
    end
    frame.evidenceKey=tostring(#encoded)..":"..tostring(first)..":"..tostring(second)
    local prior=supplied.priorAction
    if type(prior)=="table" and text(prior.id,128) then
        frame.priorAction={id=prior.id,kind=prior.kind}
        frame.preserveContinuity=prior.evidenceKey==frame.evidenceKey
    end
    frame.frameId=id.."/conflict/"..tostring(frame.atHours).."/"..frame.evidenceKey
    local ok,result=pcall(SAO.CognitiveModels.interpretConflict,frame,offered)
    if not ok then return nil,"conflict-interpreter-refused" end
    return detached(result)
end

function C.rebindWorld()
    for id, rec in pairs(SAO.Identity and SAO.Identity.all() or {}) do
        if rec.cognition then C.interrupt(id, "world-reloaded") end
    end
end
if Events and Events.OnGameStart then
    if C.onGameStart then Events.OnGameStart.Remove(C.onGameStart) end
    C.onGameStart = function()
        C.ensureGameDefaults()
        C.rebindWorld()
    end
    Events.OnGameStart.Add(C.onGameStart)
end
return C
