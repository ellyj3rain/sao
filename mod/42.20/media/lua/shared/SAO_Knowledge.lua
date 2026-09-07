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

-- The closed set of things a person can be asked about. This is the
-- understander's target space: free text resolves to these (plus a
-- name for "person"), or to nothing, honestly.
K.TOPICS = { "self", "person", "zombies", "dead", "food", "water",
             "house", "ground", "lessons" }

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
    pcall(function() b = SAO.Perception.beliefs[id] end)
    return b
end

-- Where the speaker stands (body first, record second) - positions
-- become direction words from here, never coordinates (DR-017).
function K.speakerAt(id)
    local sx, sy
    pcall(function()
        local body = SAO.Body.get(id)
        if body then sx, sy = body:getX(), body:getY() end
    end)
    if not sx then
        pcall(function()
            local rec = SAO.Identity.get(id)
            sx, sy = rec and rec.x, rec and rec.y
        end)
    end
    return sx, sy
end

local function whereWord(x, y, sx, sy)
    local w = nil
    pcall(function() w = SAO.Perception.whereWord(x, y, sx, sy) end)
    return w
end

-- ---------------------------------------------------------------
-- The topics. Each returns a list of flat fact records (or nil when
-- the person holds nothing), every record carrying source / teller /
-- age where the store has them.
-- ---------------------------------------------------------------

local function aboutSelf(id, opts)
    local rec = nil
    pcall(function() rec = SAO.Identity.get(id) end)
    if not rec then return nil end
    local out = {}
    pcall(function()
        local trade = SAO.Census.describe(rec)
        if trade then
            out[#out + 1] = { fact = "trade", text = trade,
                              source = "lived" }
        end
    end)
    pcall(function()
        local origin = SAO.Census.originNote(rec)
        if origin then
            out[#out + 1] = { fact = "origin", text = origin,
                              source = "lived" }
        end
    end)
    if rec.newcomer and rec.arrivedAtHours then
        pcall(function()
            local nh = GameTime.getInstance():getWorldAgeHours()
            out[#out + 1] = { fact = "arrival", source = "lived",
                days = math.max(1,
                    math.floor((nh - rec.arrivedAtHours) / 24)) }
        end)
    end
    if rec.designation then
        out[#out + 1] = { fact = "work", source = "lived",
                          designation = tostring(rec.designation) }
    end
    pcall(function()
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
local function aboutNeed(id, offer)
    local out = {}
    pcall(function()
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
    pcall(function()
        local sx, sy = K.speakerAt(id)
        if not sx then return end
        local place = SAO.Places.nearestOffering(sx, sy, offer,
            SAO.Places.comfortHorizon())
        if place then
            out[#out + 1] = { fact = "knownPlace", offer = offer,
                whereWord = whereWord(place.cx, place.cy, sx, sy),
                source = "observed" }
        end
    end)
    if #out == 0 then return nil end
    return out
end

local function aboutHouse(id, opts)
    local g = nil
    pcall(function() g = SAO.Standing.groupOf(id) end)
    if not g then return nil end
    local out = {}
    pcall(function()
        local fname = SAO.Standing.factionName(g)
        if fname then
            out[#out + 1] = { fact = "houseName", name = fname,
                              source = "lived" }
        end
    end)
    pcall(function()
        local leaderId = SAO.Standing.leaderOf(g)
        local lrec = leaderId and SAO.Identity.get(leaderId) or nil
        local lname = SAO.Identity.knownName(lrec)
        if lname then
            out[#out + 1] = { fact = "leader", name = lname,
                              source = "lived" }
        end
    end)
    pcall(function()
        local creed = SAO.Standing.creedOf(g)
        if creed and creed.name then
            out[#out + 1] = { fact = "creed",
                              name = tostring(creed.name),
                              source = "lived" }
        end
    end)
    pcall(function()
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
        pcall(function()
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
        pcall(function()
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
    pcall(function()
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

local ABOUT = {
    self = aboutSelf,
    person = aboutPerson,
    zombies = aboutZombies,
    dead = aboutDead,
    food = function(id) return aboutNeed(id, "food") end,
    water = function(id) return aboutNeed(id, "water") end,
    house = aboutHouse,
    ground = aboutGround,
    lessons = aboutLessons,
}

-- What does person N know about topic T? opts carries tick (for
-- ages), trusted (the earned line, computed by claims() when the
-- listener is known), and name (for topic "person").
function K.about(id, topic, opts)
    local f = ABOUT[topic]
    if not f then return nil end
    local ok, facts = pcall(f, id, opts)
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
    pcall(function() out.traits = SAO.Disposition.traits(id) end)
    if listenerKey then
        pcall(function()
            out.trust = SAO.Standing.trust(id, listenerKey)
        end)
        pcall(function()
            out.moment.debt = SAO.Standing.debt(id, listenerKey) > 0
        end)
        pcall(function()
            out.moment.hostile =
                SAO.Standing.isHostileTo(id, listenerKey) == true
        end)
    end
    out.trusted = (out.trust or 0) >= K.EARNED_AT
    pcall(function()
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
    pcall(function()
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
    pcall(function()
        local body = SAO.Body.get(id)
        if body and body:getBodyDamage():getNumPartsBitten() > 0 then
            out.moment.bitten = true
        end
    end)
    return out
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

return K
