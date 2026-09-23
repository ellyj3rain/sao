-- SAO_Knowledge - what one person knows, as one surface ([C27]).
-- ---------------------------------------------------------------------------
-- Rung 1 of SPEECH.md, built to SPEECH_ML_DESIGN.md's ratified
-- contract: everything the two learned pieces will read in one call
-- - the person's facts, organized by topic, each carrying how they
-- know it and how old it is - plus the conditioning the speaker is
-- ratified to take: the eight temperament axes, trust toward the
-- listener, and the moment (war, grief, debt, their own bite).
--
-- READ-ONLY BY LAW (the one-loop law, [B27]): this module is a
-- transport over the stores the county already keeps. It writes
-- nothing - no records, no beliefs, no standing, and it opens no
-- ModData store (even getOrCreate writes on first touch, so it is
-- banned here; everything goes through the owning module's own
-- readers). Asking a question changes nothing.
--
-- OFFLINE BY CONSTRUCTION: the file loads in a bare Kahlua VM with
-- no engine and no sibling modules - every sibling read sits inside
-- a function behind pcall - which is what lets Border 101 drive it
-- against stub stores with the same runner the other mirrors use.

SAO = SAO or {}
SAO.Knowledge = SAO.Knowledge or {}
local K = SAO.Knowledge

-- A capture needs to distinguish an empty answer from a failed reader. Normal
-- inspection keeps its partial-answer behavior; evidence collection records
-- every invoked boundary and refuses completeness after any failure.
local evidenceReads = nil
local function readSource(name, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if evidenceReads then
        evidenceReads.readers[name] = true
        if not ok then evidenceReads.failures[name] = "reader-failed" end
    end
    return ok, a, b
end

-- The closed set of things a person can be asked about. This is the
-- understander's target space: free text resolves to these (plus a
-- name for "person"), or to nothing, honestly.
K.TOPICS = { "self", "person", "zombies", "dead", "food", "water",
             "house", "ground", "lessons",
             "mutations",
             "world",
             -- [C38] the life before, and the day it started.
             "before", "started" }

function K.topics()
    local out = {}
    for i, t in ipairs(K.TOPICS) do out[i] = t end
    return out
end

-- The earned line ([C26], unchanged): lessons, pacts, and what a
-- body admits are shared past this much trust; the rest is open.
K.EARNED_AT = 0.3

-- How old a sighting-axis memory is, in the words a person uses.
-- Models read the raw number; people read the word.
function K.ageWord(deltaTicks)
    if not deltaTicks or deltaTicks < 0 then return nil end
    if deltaTicks < 1800 then return "just now" end
    if deltaTicks < 10800 then return "not long ago" end
    if deltaTicks < 43200 then return "a while back" end
    return "a long time back"
end

local function beliefsOf(id)
    local b = nil
    readSource("perception.beliefs", function() b = SAO.Perception.beliefs[id] end)
    return b
end

-- Where the speaker stands (body first, record second) - positions
-- become direction words from here, never coordinates (DR-017).
function K.speakerAt(id)
    local sx, sy
    readSource("body.position", function()
        local body = SAO.Body.get(id)
        if body then sx, sy = body:getX(), body:getY() end
    end)
    if not sx then
        readSource("identity.position", function()
            local rec = SAO.Identity.get(id)
            sx, sy = rec and rec.x, rec and rec.y
        end)
    end
    return sx, sy
end

local function whereWord(x, y, sx, sy)
    local w = nil
    readSource("perception.direction", function() w = SAO.Perception.whereWord(x, y, sx, sy) end)
    return w
end

-- [C38] The county's date for a world-age hour, in the words a
-- person uses ("July 12, 1993"), from the bridge's calendar - the
-- save's own start date and [C36]'s arithmetic; nil where there is
-- no bridge, and the fact carries the day count instead. The
-- chronicle reads the same call.
function K.dateOf(hours)
    if type(hours) ~= "number" then return nil end
    local d = nil
    readSource("calendar.date", function() d = SAOJavaBridge:countyDate(hours) end)
    if type(d) == "string" and d ~= "" then return d end
    return nil
end

local function dayOf(hours)
    return math.max(1, math.floor((hours or 0) / 24))
end

-- ---------------------------------------------------------------
-- The topics. Each returns a list of flat fact records (or nil when
-- the person holds nothing), every record carrying source / teller /
-- age where the store has them.
-- ---------------------------------------------------------------

local function aboutSelf(id, opts)
    local rec = nil
    readSource("identity.self", function() rec = SAO.Identity.get(id) end)
    if not rec then return nil end
    local out = {}
    readSource("census.trade", function()
        local trade = SAO.Census.describe(rec)
        if trade then
            out[#out + 1] = { fact = "trade", text = trade,
                              source = "lived" }
        end
    end)
    readSource("census.origin", function()
        local origin = SAO.Census.originNote(rec)
        if origin then
            out[#out + 1] = { fact = "origin", text = origin,
                              source = "lived" }
        end
    end)
    if rec.newcomer and rec.arrivedAtHours then
        readSource("history.arrival", function()
            local nh = SAO.History.countyHours()
            out[#out + 1] = { fact = "arrival", source = "lived",
                days = math.max(1,
                    math.floor((nh - rec.arrivedAtHours) / 24)) }
        end)
    end
    if rec.designation then
        out[#out + 1] = { fact = "work", source = "lived",
                          designation = tostring(rec.designation) }
    end
    readSource("lessons.first", function()
        local fh = SAO.Lessons.firstLessonHours(id)
        if fh then
            out[#out + 1] = { fact = "changed", source = "lived",
                day = math.max(1, math.floor(fh / 24)) }
        end
    end)
    if #out == 0 then return nil end
    return out
end

local function aboutPerson(id, opts)
    local name = opts and opts.name
    if not name then return nil end
    local b = beliefsOf(id)
    local pb = b and b.people and b.people[name] or nil
    if not pb then return nil end
    local tick = opts and opts.tick
    local fact = { fact = "person", name = name,
                   dead = pb.dead == true,
                   source = pb.source, teller = pb.teller,
                   presumed = pb.presumed == true,
                   condition = pb.condition,
                   form = pb.form,
                   formPerformance = pb.formPerformance,
                   attributeMutations = pb.attributeMutations,
                   ageTicks = tick and pb.at and (tick - pb.at) or nil }
    fact.ageWord = K.ageWord(fact.ageTicks)
    if not pb.dead and pb.x then
        local sx, sy = K.speakerAt(id)
        fact.whereWord = whereWord(pb.x, pb.y, sx, sy)
    end
    return { fact }
end

local function aboutZombies(id, opts)
    local b = beliefsOf(id)
    if not (b and b.zombies) then return nil end
    local tick = opts and opts.tick
    local n, nearest, freshest = 0, nil, nil
    for _, zb in pairs(b.zombies) do
        n = n + 1
        if not nearest or (zb.dist or 1e9) < (nearest.dist or 1e9) then
            nearest = zb
        end
        if not freshest or (zb.at or 0) > (freshest.at or 0) then
            freshest = zb
        end
    end
    if n == 0 then return nil end
    local fact = { fact = "crowds", count = n,
                   ageTicks = tick and freshest and freshest.at
                       and (tick - freshest.at) or nil }
    fact.ageWord = K.ageWord(fact.ageTicks)
    if nearest and nearest.x then
        local sx, sy = K.speakerAt(id)
        fact.whereWord = whereWord(nearest.x, nearest.y, sx, sy)
        fact.source = nearest.source
    end
    return { fact }
end

local function aboutDead(id, opts)
    local b = beliefsOf(id)
    if not b then return nil end
    local out = {}
    for name, pb in pairs(b.people or {}) do
        if pb.dead then
            out[#out + 1] = { fact = "death", name = name,
                              source = pb.source, teller = pb.teller }
        end
    end
    if #out == 0 then return nil end
    return out
end

-- Food or water: the house word, and the nearest KNOWN place
-- offering it ([C25]'s own surface, spoken instead of walked).
local function aboutNeed(id, offer, opts)
    local out = {}
    readSource("standing.stock", function()
        local g = SAO.Standing.groupOf(id)
        if not g then return end
        if offer == "water" then
            local ws = SAO.Standing.waterStoreOf(g)
            if ws and ws.word then
                out[#out + 1] = { fact = "houseWater",
                                  word = tostring(ws.word),
                                  source = "lived" }
            end
        else
            local lt = SAO.Standing.larderOf(g)
            if lt and lt.word then
                out[#out + 1] = { fact = "houseFood",
                                  word = tostring(lt.word),
                                  source = "lived" }
            end
        end
    end)
    readSource("worldSources.nearest", function()
        local sx, sy = K.speakerAt(id)
        if not sx then return end
        local place = SAO.WorldSources.nearestBelieved(id, sx, sy, offer,
            SAO.Places.comfortHorizon())
        if place then
            out[#out + 1] = { fact = "knownPlace", offer = offer,
                whereWord = whereWord(place.cx, place.cy, sx, sy),
                source = "observed" }
        end
    end)
    readSource("perception.transfers", function()
        local now = opts and opts.nowHours
        if now == nil and opts and opts.tick ~= nil then
            now = opts.tick / SAO.History.TICKS_PER_HOUR
        end
        if now == nil then now = SAO.History.countyHours() end
        local sx, sy = K.speakerAt(id)
        for _, episode in ipairs(SAO.Perception.transferFacts(id, now)) do
            if episode.state == "remembered" and episode.category == offer then
                out[#out + 1] = { fact = "transfer", eventId = episode.eventId,
                    actorId = episode.actorId, operation = episode.operation,
                    itemType = episode.itemType, category = episode.category,
                    sourceId = episode.sourceId, placeId = episode.placeId,
                    whereWord = whereWord(episode.x, episode.y, sx, sy),
                    eventAt = episode.eventAt, acquiredAt = episode.acquiredAt,
                    ageHours = now - episode.eventAt,
                    source = episode.source, teller = episode.teller,
                    originId = episode.originId, originSource = episode.originSource,
                    originAcquiredAt = episode.originAcquiredAt }
            end
        end
        if offer == "food" then
            for _, request in ipairs(SAO.Perception.knownAidRequests(id, now)) do
                local x = request.minX and (request.minX + request.maxX) / 2 or nil
                local y = request.minY and (request.minY + request.maxY) / 2 or nil
                out[#out + 1] = { fact = "aidRequest", groupId = request.groupId,
                    category = request.category, requestedAt = request.requestedAt,
                    acquiredAt = request.acquiredAt,
                    source = request.source, teller = request.teller,
                    originId = request.originId, originAcquiredAt = request.originAcquiredAt,
                    whereWord = whereWord(x, y, sx, sy) }
            end
        end
    end)
    if #out == 0 then return nil end
    return out
end

local function aboutHouse(id, opts)
    local g = nil
    readSource("standing.group", function() g = SAO.Standing.groupOf(id) end)
    if not g then return nil end
    local out = {}
    readSource("standing.name", function()
        local fname = SAO.Standing.factionName(g)
        if fname then
            out[#out + 1] = { fact = "houseName", name = fname,
                              source = "lived" }
        end
    end)
    readSource("standing.leader", function()
        local leaderId = SAO.Standing.leaderOf(g)
        local lrec = leaderId and SAO.Identity.get(leaderId) or nil
        local lname = SAO.Identity.knownName(lrec)
        if lname then
            out[#out + 1] = { fact = "leader", name = lname,
                              source = "lived" }
        end
    end)
    readSource("standing.creed", function()
        local creed = SAO.Standing.creedOf(g)
        if creed and creed.name then
            out[#out + 1] = { fact = "creed",
                              name = tostring(creed.name),
                              source = "lived" }
        end
    end)
    readSource("standing.feuds", function()
        for og in pairs(SAO.Standing.allGroupClaims()) do
            if og ~= g and SAO.Standing.feudBetween(g, og) then
                out[#out + 1] = { fact = "feud",
                    with = tostring(SAO.Standing.factionName(og) or og),
                    source = "lived" }
            end
        end
    end)
    -- The pacts are the house's business ([C26]'s earned split).
    if opts and opts.trusted then
        readSource("standing.pacts", function()
            for og in pairs(SAO.Standing.allGroupClaims()) do
                if og ~= g and SAO.Standing.pactBetween(g, og) then
                    out[#out + 1] = { fact = "pact",
                        with = tostring(
                            SAO.Standing.factionName(og) or og),
                        source = "lived" }
                end
            end
        end)
    end
    if #out == 0 then return nil end
    return out
end

-- Ground held: whose lines they believe in - the warning that was
-- always meant to travel free.
local function aboutGround(id, opts)
    local b = beliefsOf(id)
    if not (b and b.places) then return nil end
    local out = {}
    local sx, sy = K.speakerAt(id)
    for ownerKey, pc in pairs(b.places) do
        local owner = nil
        readSource("identity.groundOwner", function()
            owner = SAO.Identity.knownName(SAO.Identity.get(ownerKey))
        end)
        out[#out + 1] = { fact = "held", owner = owner,
            source = pc.source, teller = pc.teller,
            whereWord = whereWord(
                math.floor(((pc.minX or 0) + (pc.maxX or 0)) / 2),
                math.floor(((pc.minY or 0) + (pc.maxY or 0)) / 2),
                sx, sy) }
    end
    if #out == 0 then return nil end
    return out
end

-- "A lesson if trust permits" - the one gate the advertisement
-- always named ([C26]).
local function aboutLessons(id, opts)
    if not (opts and opts.trusted) then
        return { { fact = "withheld", source = "lived" } }
    end
    local out = {}
    readSource("lessons.known", function()
        local rec = SAO.Identity.get(id)
        if not (rec and rec.lessonsKnown) then return end
        for key in pairs(rec.lessonsKnown) do
            local entry = SAO.Lessons.REGISTRY[key]
            local meta = rec.lessonMeta and rec.lessonMeta[key] or nil
            if entry then
                out[#out + 1] = { fact = "lesson", key = tostring(key),
                    line = entry.line,
                    source = meta and meta.src or "lived",
                    of = meta and meta.of or nil }
            end
        end
    end)
    if #out == 0 then return nil end
    return out
end

local function aboutMutations(id, opts)
    local rec = nil
    readSource("identity.mutations", function() rec = SAO.Identity.get(id) end)
    if not rec or not rec.mutationKnowledge then return nil end
    local out = {}
    for form, entry in pairs(rec.mutationKnowledge) do
        out[#out + 1] = {
            fact = "mutation",
            form = form,
            source = entry.source,
            weight = entry.weight,
            firstDay = entry.firstDay,
            lastDay = entry.lastDay,
            performance = entry.performance,
            events = entry.events,
        }
    end
    if #out == 0 then return nil end
    return out
end

-- [C38] The life before (Day Zero slice 6): what a person was before
-- the fall, read off the record and the history - the year they were
-- born, the war their life put them in, where they were from, where
-- home is from here - and whether the fall has taught them anything
-- yet: the innocent-to-hardened arc, visible in talk. The formative
-- claims themselves are the lessons topic, past the earned line.
local function aboutBefore(id, opts)
    local rec = nil
    readSource("identity.before", function() rec = SAO.Identity.get(id) end)
    if not rec then return nil end
    local out = {}
    readSource("history.birth", function()
        local year = SAO.History.birthYearOf(id)
        if year then
            out[#out + 1] = { fact = "born", source = "lived", year = year }
        end
    end)
    readSource("history.service", function()
        local war = SAO.History.servedIn(id, rec.occupation)
        if war then
            out[#out + 1] = { fact = "war", source = "lived",
                              war = tostring(war) }
        end
    end)
    if rec.originRegion then
        out[#out + 1] = { fact = "from", source = "lived",
                          region = tostring(rec.originRegion) }
    end
    if rec.homeX and rec.homeY then
        local sx, sy = K.speakerAt(id)
        local w = sx and whereWord(rec.homeX, rec.homeY, sx, sy) or nil
        if w then
            out[#out + 1] = { fact = "home", source = "lived", whereWord = w }
        end
    end
    readSource("lessons.hardened", function()
        if SAO.Lessons.hasAny(id) then
            local n = 0
            for _ in pairs(rec.lessonsKnown or {}) do n = n + 1 end
            out[#out + 1] = { fact = "hardened", source = "lived", lessons = n }
        else
            out[#out + 1] = { fact = "innocent", source = "lived" }
        end
    end)
    if #out == 0 then return nil end
    return out
end

-- [C38] The day it started, as this person knows it: their own first
-- horror (lived - the day, the county's date, and what it taught,
-- with a name when there was one); county news this person actually
-- received; and this person's first proved radio reception (told).
local function aboutStarted(id, opts)
    local rec = nil
    readSource("identity.started", function() rec = SAO.Identity.get(id) end)
    if not rec then return nil end
    local out = {}
    readSource("lessons.started", function()
        local fh = SAO.Lessons.firstLessonHours(id)
        if not fh then return end
        out[#out + 1] = { fact = "mine", source = "lived",
                          day = dayOf(fh), date = K.dateOf(fh) }
        for key, meta in pairs(rec.lessonMeta or {}) do
            if meta.atHours == fh then
                local entry = SAO.Lessons.REGISTRY[key]
                out[#out + 1] = { fact = "first", source = meta.src or "lived",
                    key = tostring(key), line = entry and entry.line or nil,
                    of = meta.of }
                break
            end
        end
    end)
    readSource("perception.radio", function()
        local receipts = SAO.Perception.radioReceptions(id, evidenceReads ~= nil)
        if type(receipts) ~= "table" then error("radio-reception-unreadable") end
        local now = opts and opts.nowHours
            or (SAO.History and SAO.History.countyHours())
        local first = nil
        local names = { outbreak = "county", turned = "turned", tapsDry = "taps" }
        for _, receipt in ipairs(receipts) do
            if receipt.receivedAt <= now then
                first = first or receipt
                for _, claim in ipairs(receipt.claims) do
                    if names[claim.kind] then
                        out[#out + 1] = { fact = names[claim.kind], source = "told",
                            receivedAt = receipt.receivedAt,
                            broadcastId = receipt.broadcastId, teller = receipt.sourceId,
                            heardDay = dayOf(receipt.receivedAt),
                            heardDate = K.dateOf(receipt.receivedAt) }
                    end
                end
            end
        end
        if first and type(first.receivedAt) == "number" then
            out[#out + 1] = { fact = "news", source = "told",
                day = dayOf(first.receivedAt),
                date = K.dateOf(first.receivedAt) }
        end
    end)
    if #out == 0 then return nil end
    return out
end

-- [C74] Protected prose stays in Speakeasy. The living reader carries the
-- claim identifier and personal provenance needed by a bounded retriever.
local function aboutWorld(id, opts)
    local rows = nil
    readSource("worldKnowledge.claims", function()
        local now = opts and opts.nowHours
            or (SAO.History and SAO.History.countyHours())
        rows = SAO.WorldKnowledge.claimsOf(id, now)
        if type(rows) ~= "table" then error("world-claims-unreadable") end
    end)
    if type(rows) ~= "table" or #rows == 0 then return nil end
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            fact = "world-claim",
            claimId = row.claimId,
            source = row.path,
            acquiredHour = row.acquiredHour,
            carrier = row.carrier,
            knowledgeKind = row.knowledgeKind,
            receiptId = row.receiptId,
            reportHour = row.sourceEvent and row.sourceEvent.atHours,
        }
    end
    return out
end

local ABOUT = {
    self = aboutSelf,
    person = aboutPerson,
    zombies = aboutZombies,
    dead = aboutDead,
    food = function(id, opts) return aboutNeed(id, "food", opts) end,
    water = function(id, opts) return aboutNeed(id, "water", opts) end,
    house = aboutHouse,
    ground = aboutGround,
    lessons = aboutLessons,
    mutations = aboutMutations,
    world = aboutWorld,
    before = aboutBefore,
    started = aboutStarted,
}

-- What does person N know about topic T? opts carries tick (for
-- ages), trusted (the earned line, computed by claims() when the
-- listener is known), and name (for topic "person").
function K.about(id, topic, opts)
    local f = ABOUT[topic]
    if not f then return nil end
    local ok, facts = readSource("topic", f, id, opts)
    if not ok then return nil end
    return facts
end

-- ---------------------------------------------------------------
-- Conditioning: what the speaker model is ratified to read beside
-- the facts - the eight axes, trust toward this listener, and the
-- moment (SPEECH_ML_DESIGN.md, Decision 5).
-- ---------------------------------------------------------------
function K.conditioning(id, listenerKey, tick)
    local out = { moment = {} }
    readSource("disposition.traits", function() out.traits = SAO.Disposition.traits(id) end)
    -- [C32] What they carry, in plain words (SAO_Conditions.words):
    -- a speaker model reads it beside the axes.
    readSource("conditions.words", function() out.conditions = SAO.Conditions.words(id) end)
    -- [C33] And the habits, the same way.
    readSource("habits.words", function() out.habits = SAO.Habits.words(id) end)
    -- [C34] The strain the speaker is under (DR-033): the situation
    -- the controller's own pressure answer names - working, under
    -- threat, resting - and whether they are spent, read off the
    -- body's own stats. The register follows it; the rule floors in
    -- SPEECH_ML_DESIGN.md (Decision 5, amended) shorten it under
    -- strain. Nothing where there is no live agent or body: a reader
    -- that cannot tell says nothing.
    readSource("controller.pressure", function()
        if not SAO.Body.get(id) then return end
        local agent = SAO.Controller.agents[id]
        if not agent then return end
        local state = tostring(agent.state or "")
        local answer = agent.pressure and agent.pressure.answer or nil
        if state == "ENGAGE" or state == "ALERT" or state == "FLEE" then
            out.moment.situation = "under threat"
        elseif answer == "designation" then
            out.moment.situation = "working"
        elseif answer == "chosen rest" then
            out.moment.situation = "resting"
        end
    end)
    readSource("body.needs", function()
        local body = SAO.Body.get(id)
        if not body then return end
        local needs = SAO.Needs.read(body)
        if not needs then return end
        -- Spent: tired past six tenths, or under three tenths of
        -- stamina left (ours; the engine's own 0 to 1 stats).
        out.moment.spent = (needs.fatigue or 0) > 0.6
            or (needs.endurance or 1) < 0.3
    end)
    if listenerKey then
        readSource("standing.trust", function()
            out.trust = SAO.Standing.trust(id, listenerKey)
        end)
        readSource("standing.debt", function()
            out.moment.debt = SAO.Standing.debt(id, listenerKey) > 0
        end)
        readSource("standing.hostility", function()
            out.moment.hostile =
                SAO.Standing.isHostileTo(id, listenerKey) == true
        end)
    end
    out.trusted = (out.trust or 0) >= K.EARNED_AT
    readSource("standing.war", function()
        local g = SAO.Standing.groupOf(id)
        if not g then return end
        for og in pairs(SAO.Standing.allGroupClaims()) do
            if og ~= g and SAO.Standing.feudBetween(g, og) then
                out.moment.war = true
                break
            end
        end
    end)
    -- Grief: a lived loss with a name on it ([C26]'s contextual
    -- source, carried as data now).
    readSource("lessons.grief", function()
        local rec = SAO.Identity.get(id)
        local meta = rec and rec.lessonMeta or nil
        if not meta then return end
        for _, key in ipairs({ "nothing-left-to-lose",
                               "never-again-that-close" }) do
            local m = meta[key]
            if m and m.src == "lived" and m.of then
                out.moment.grief = tostring(m.of)
                break
            end
        end
    end)
    -- Their own bite, read off the body when there is one.
    readSource("body.bite", function()
        local body = SAO.Body.get(id)
        if body and body:getBodyDamage():getNumPartsBitten() > 0 then
            out.moment.bitten = true
        end
    end)
    return out
end

-- [C47] THE CLAIM SET, FLAT, FOR THE FENCE.
--
-- SPEECH_ML_DESIGN Decision 4 (ratified): a speaker may only put
-- this person's own facts into fact positions. The fence that
-- enforces it lives in the jar and needs the claims as flat
-- "field=value" lines, so this renders them - every value the
-- surface holds for this person, under the field it came from.
--
-- Nothing is invented here and nothing is filtered: the fence IS
-- the claim set read sideways, so a value that reaches this
-- function is one the person actually holds, and a value that does
-- not reach it is one they can never say.
function K.flatClaims(id, listenerKey, tick, topics)
    local bundle = K.claims(id, listenerKey, tick, topics)
    local lines = {}
    local seen = {}
    local function put(field, value)
        if value == nil then return end
        value = tostring(value)
        if value == "" then return end
        local key = field .. "=" .. value
        if seen[key] then return end
        seen[key] = true
        lines[#lines + 1] = key
    end
    for _, facts in pairs(bundle.facts or {}) do
        for _, fact in ipairs(facts) do
            for field, value in pairs(fact) do
                -- Booleans and tables are not sayable values; the
                -- fence holds words and numbers.
                local kind = type(value)
                if kind == "string" or kind == "number" then
                    put(field, value)
                end
            end
        end
    end
    return table.concat(lines, "\n")
end

-- One exchange turn's full input: conditioning plus the facts for
-- the asked topics (default: every topic). This is the surface both
-- models are built against, and what the inspect panel reads today.
function K.claims(id, listenerKey, tick, topics)
    local conditioning = K.conditioning(id, listenerKey, tick)
    local opts = { tick = tick, trusted = conditioning.trusted }
    local facts = {}
    for _, topic in ipairs(topics or K.TOPICS) do
        if topic ~= "person" then
            facts[topic] = K.about(id, topic, opts)
        end
    end
    return { conditioning = conditioning, facts = facts }
end

-- [C75] A learned result cannot point at a Lua table or at a value that merely
-- happens to occur in one. Give every fact in one immutable conversation
-- snapshot a local reference. The caller owns snapshotRef and must never reuse
-- it for different bytes; this reader owns only the deterministic catalogue
-- inside that boundary.
local CATALOGUE_SCHEMA = 1
local MAX_CATALOGUE_DEPTH = 16
local MAX_CATALOGUE_VALUES = 8192
-- Kahlua's table.sort always chooses the leftmost pivot and can exhaust the VM
-- stack on adversarial order. Every list sorted below is therefore kept in the
-- low hundreds, well below the earliest measured failure at 1500 entries.
local MAX_CATALOGUE_SORT = 512
local MAX_CATALOGUE_CLAIMS = MAX_CATALOGUE_SORT
local MAX_CATALOGUE_TABLE_ENTRIES = MAX_CATALOGUE_SORT
local MAX_SELECTED_FENCE_LINES = MAX_CATALOGUE_SORT

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function arrayLength(value)
    if type(value) ~= "table" then return nil end
    local count, largest = 0, 0
    for key in pairs(value) do
        if not finiteNumber(key) or key < 1 or key ~= math.floor(key) then
            return nil
        end
        count = count + 1
        if key > largest then largest = key end
    end
    if count ~= largest then return nil end
    return count
end

local function scalarKey(value)
    local kind = type(value)
    if kind == "string" then return "s" .. tostring(#value) .. ":" .. value end
    if kind == "number" and finiteNumber(value) then
        if value == 0 then value = 0 end
        return "n" .. tostring(value)
    end
    return nil
end

-- One pass both detaches the plain data and derives bytes used only for stable
-- ordering. Unsupported values and cycles refuse the catalogue instead of
-- disappearing from a fact.
local function detachCanonical(value, seen, depth, budget)
    local kind = type(value)
    if kind == "string" then
        return value, "s" .. tostring(#value) .. ":" .. value
    end
    if kind == "boolean" then return value, value and "b1" or "b0" end
    if kind == "number" then
        if not finiteNumber(value) then return nil, nil, "non-finite-number" end
        if value == 0 then value = 0 end
        return value, "n" .. tostring(value)
    end
    if kind ~= "table" then return nil, nil, "unsupported-value" end
    if depth > MAX_CATALOGUE_DEPTH then return nil, nil, "catalogue-too-deep" end
    if seen[value] then return nil, nil, "cyclic-value" end
    seen[value] = true
    local entries = {}
    for key, child in pairs(value) do
        if #entries >= MAX_CATALOGUE_TABLE_ENTRIES then
            seen[value] = nil
            return nil, nil, "catalogue-table-too-wide"
        end
        budget.left = budget.left - 1
        if budget.left < 0 then
            seen[value] = nil
            return nil, nil, "catalogue-too-large"
        end
        local keyBytes = scalarKey(key)
        if not keyBytes then
            seen[value] = nil
            return nil, nil, "unsupported-key"
        end
        local childCopy, childBytes, why = detachCanonical(child, seen,
            depth + 1, budget)
        if not childBytes then
            seen[value] = nil
            return nil, nil, why
        end
        entries[#entries + 1] = {
            key = key,
            keyBytes = keyBytes,
            value = childCopy,
            valueBytes = childBytes,
        }
    end
    seen[value] = nil
    table.sort(entries, function(left, right)
        if left.keyBytes ~= right.keyBytes then
            return left.keyBytes < right.keyBytes
        end
        return left.valueBytes < right.valueBytes
    end)
    local copy, bytes = {}, { "t", tostring(#entries), "{" }
    for _, entry in ipairs(entries) do
        copy[entry.key] = entry.value
        bytes[#bytes + 1] = tostring(#entry.keyBytes)
        bytes[#bytes + 1] = ":"
        bytes[#bytes + 1] = entry.keyBytes
        bytes[#bytes + 1] = tostring(#entry.valueBytes)
        bytes[#bytes + 1] = ":"
        bytes[#bytes + 1] = entry.valueBytes
    end
    bytes[#bytes + 1] = "}"
    return copy, table.concat(bytes)
end

local function detach(value, budget)
    return detachCanonical(value, {}, 0,
        budget or { left = MAX_CATALOGUE_VALUES })
end

local function catalogueTopics(topics)
    topics = topics or K.TOPICS
    local count = arrayLength(topics)
    if count == nil then return nil, "topics-not-a-list" end
    local out, seen = {}, {}
    for index = 1, count do
        local topic = topics[index]
        if type(topic) ~= "string" or not ABOUT[topic] then
            return nil, "unknown-topic"
        end
        if seen[topic] then return nil, "duplicate-topic" end
        seen[topic] = true
        out[index] = topic
    end
    return out
end

local function personFacts(id, opts)
    local beliefs = beliefsOf(id)
    local names = {}
    for name in pairs((beliefs and beliefs.people) or {}) do
        if type(name) ~= "string" or name == "" then
            return nil, "person-belief-key-unreadable"
        end
        if #names >= MAX_CATALOGUE_SORT then
            return nil, "too-many-known-people"
        end
        names[#names + 1] = name
    end
    table.sort(names)
    local out = {}
    for _, name in ipairs(names) do
        local rows = aboutPerson(id, {
            name = name,
            tick = opts.tick,
            trusted = opts.trusted,
        })
        for _, row in ipairs(rows or {}) do out[#out + 1] = row end
    end
    return out
end

function K.claimCatalogue(id, listenerKey, tick, snapshotRef, topics)
    if type(id) ~= "string" or id == "" then return nil, "person-required" end
    if listenerKey ~= nil
        and (type(listenerKey) ~= "string" or listenerKey == "") then
        return nil, "listener-reference-unreadable"
    end
    if not finiteNumber(tick) then return nil, "tick-required" end
    if type(snapshotRef) ~= "string" or snapshotRef == "" then
        return nil, "snapshot-reference-required"
    end
    local orderedTopics, topicWhy = catalogueTopics(topics)
    if not orderedTopics then return nil, topicWhy end
    local conditioning = K.conditioning(id, listenerKey, tick)
    local budget = { left = MAX_CATALOGUE_VALUES }
    local conditioningCopy, _, conditioningWhy = detach(conditioning, budget)
    if not conditioningCopy then return nil, conditioningWhy end
    local opts = { tick = tick, trusted = conditioning.trusted,
        nowHours = SAO.History and SAO.History.TICKS_PER_HOUR
            and tick / SAO.History.TICKS_PER_HOUR or nil }
    local candidates = {}
    for topicIndex, topic in ipairs(orderedTopics) do
        local rows, why
        if topic == "person" then rows, why = personFacts(id, opts)
        else rows = K.about(id, topic, opts) end
        if rows == nil and why then return nil, why end
        if rows ~= nil then
            local rowCount = arrayLength(rows)
            if rowCount == nil then return nil, "facts-not-a-list" end
            for rowIndex = 1, rowCount do
                local factCopy, factBytes, factWhy = detach(rows[rowIndex], budget)
                if not factCopy then return nil, factWhy end
                candidates[#candidates + 1] = {
                    topic = topic,
                    topicIndex = topicIndex,
                    fact = factCopy,
                    factBytes = factBytes,
                }
                if #candidates > MAX_CATALOGUE_CLAIMS then
                    return nil, "catalogue-too-many-claims"
                end
            end
        end
    end
    table.sort(candidates, function(left, right)
        if left.topicIndex ~= right.topicIndex then
            return left.topicIndex < right.topicIndex
        end
        return left.factBytes < right.factBytes
    end)
    local claims = {}
    for index, candidate in ipairs(candidates) do
        local entry = {
            ref = snapshotRef .. "/claim/" .. string.format("%04d", index),
            topic = candidate.topic,
            fact = candidate.fact,
        }
        if type(candidate.fact.claimId) == "string"
            and candidate.fact.claimId ~= "" then
            entry.sourceClaimId = candidate.fact.claimId
        end
        claims[index] = entry
    end
    return {
        schema = "sao-claim-catalogue",
        schemaVersion = CATALOGUE_SCHEMA,
        snapshotRef = snapshotRef,
        personId = id,
        listenerRef = listenerKey,
        atTick = tick,
        conditioning = conditioningCopy,
        claims = claims,
    }
end

-- Synchronous observation only: no callback or model runs while these
-- readers are active, and the returned coverage has no alias to later reads.
function K.catalogueEvidence(id, listenerKey, tick, snapshotRef)
    if evidenceReads then return nil, { status = "refused", reason = "capture-reentrant" } end
    local trace = { readers = {}, failures = {} }
    evidenceReads = trace
    local ready = true
    for _, owner in ipairs({ "Standing", "WorldSources", "WorldKnowledge" }) do
        local ok, supported = readSource(owner .. ".state", function()
            return SAO[owner].knowledgeEvidenceReady(id)
        end)
        if not ok or supported ~= true then
            trace.failures[owner .. ".state"] = "owner-state-unavailable"
            ready = false
        end
    end
    local ok, catalogue, why
    if ready then
        ok, catalogue, why = pcall(K.claimCatalogue, id, listenerKey, tick,
            snapshotRef, K.TOPICS)
    else
        ok, why = true, "owner-state-unavailable"
    end
    evidenceReads = nil
    local coverage = { scope = "knowledge-topics-v1", status = "complete",
        topics = {}, readers = {}, failures = {} }
    for _, topic in ipairs(K.TOPICS) do coverage.topics[#coverage.topics + 1] = topic end
    for name in pairs(trace.readers) do coverage.readers[#coverage.readers + 1] = name end
    for name, reason in pairs(trace.failures) do
        coverage.failures[#coverage.failures + 1] = { reader = name, reason = reason }
    end
    table.sort(coverage.readers)
    table.sort(coverage.failures, function(a, b) return a.reader < b.reader end)
    if not ok or not catalogue or #coverage.failures > 0 then
        coverage.status = "refused"
        coverage.reason = why or (not ok and "catalogue-reader-failed") or "source-reader-failed"
        return nil, coverage
    end
    return catalogue, coverage
end

local function validateCatalogue(catalogue)
    if type(catalogue) ~= "table"
        or catalogue.schema ~= "sao-claim-catalogue"
        or catalogue.schemaVersion ~= CATALOGUE_SCHEMA
        or type(catalogue.snapshotRef) ~= "string"
        or catalogue.snapshotRef == ""
        or type(catalogue.personId) ~= "string"
        or catalogue.personId == ""
        or (catalogue.listenerRef ~= nil
            and (type(catalogue.listenerRef) ~= "string"
                or catalogue.listenerRef == ""))
        or not finiteNumber(catalogue.atTick) then
        return nil, "catalogue-unreadable"
    end
    local count = arrayLength(catalogue.claims)
    if count == nil then return nil, "catalogue-claims-not-a-list" end
    if type(catalogue.conditioning) ~= "table" then
        return nil, "catalogue-conditioning-unreadable"
    end
    local budget = { left = MAX_CATALOGUE_VALUES }
    local _, _, conditioningWhy = detach(catalogue.conditioning, budget)
    if conditioningWhy then return nil, conditioningWhy end
    local byRef = {}
    for index = 1, count do
        local entry = catalogue.claims[index]
        if type(entry) ~= "table" or type(entry.ref) ~= "string"
            or entry.ref == "" or type(entry.topic) ~= "string"
            or not ABOUT[entry.topic] or type(entry.fact) ~= "table" then
            return nil, "catalogue-entry-unreadable"
        end
        local sourceClaimId = nil
        if type(entry.fact.claimId) == "string"
            and entry.fact.claimId ~= "" then
            sourceClaimId = entry.fact.claimId
        end
        if entry.sourceClaimId ~= sourceClaimId then
            return nil, "catalogue-entry-unreadable"
        end
        local expected = catalogue.snapshotRef .. "/claim/"
            .. string.format("%04d", index)
        if entry.ref ~= expected or byRef[entry.ref] then
            return nil, "catalogue-reference-unreadable"
        end
        local entryCopy, _, why = detach(entry, budget)
        if not entryCopy then return nil, why end
        byRef[entry.ref] = entryCopy
    end
    return { count = count, byRef = byRef }
end

function K.selectClaims(catalogue, selection)
    local checked, catalogueWhy = validateCatalogue(catalogue)
    if not checked then return nil, catalogueWhy end
    if type(selection) ~= "table"
        or selection.snapshotRef ~= catalogue.snapshotRef then
        return nil, "selection-snapshot-mismatch"
    end
    local refCount = arrayLength(selection.claimRefs)
    if refCount == nil then return nil, "selection-references-not-a-list" end
    local wanted = {}
    for index = 1, refCount do
        local ref = selection.claimRefs[index]
        if type(ref) ~= "string" or ref == "" then
            return nil, "selection-reference-unreadable"
        end
        if wanted[ref] then return nil, "selection-reference-duplicate" end
        if not checked.byRef[ref] then return nil, "selection-reference-unknown" end
        wanted[ref] = true
    end
    local claims = {}
    for index = 1, checked.count do
        local ref = catalogue.claims[index].ref
        if wanted[ref] then claims[#claims + 1] = checked.byRef[ref] end
    end
    return {
        schema = "sao-claim-selection",
        schemaVersion = CATALOGUE_SCHEMA,
        snapshotRef = catalogue.snapshotRef,
        personId = catalogue.personId,
        listenerRef = catalogue.listenerRef,
        atTick = catalogue.atTick,
        claims = claims,
    }
end

-- Project the selected claim records through the same slot/value rule as C47's
-- full fence. The selection can narrow what is sayable; it cannot add a value.
function K.flatSelectedClaims(catalogue, selection)
    local selected, why = K.selectClaims(catalogue, selection)
    if not selected then return nil, why end
    local lines, seen = {}, {}
    for _, entry in ipairs(selected.claims) do
        for field, value in pairs(entry.fact) do
            local kind = type(value)
            if kind == "string" or kind == "number" then
                local line = tostring(field) .. "=" .. tostring(value)
                if not seen[line] then
                    if #lines >= MAX_SELECTED_FENCE_LINES then
                        return nil, "selected-fence-too-large"
                    end
                    seen[line] = true
                    lines[#lines + 1] = line
                end
            end
        end
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

return K
