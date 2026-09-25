-- SAO_Perception — the Perception pillar (ARCHITECTURE §Perception).
-- ---------------------------------------------------------------------------
-- A survivor decides on a private belief set, never on map truth. This module
-- owns that belief set: acquisition (via the bridge scanner — one compact
-- string, no engine objects), provenance, memory decay, and the query API the
-- controller consumes. Nothing outside this file may hand the controller a
-- world fact.
--
-- Belief sets per survivor:
--   zombies[key]  { x, y, dist, at, source, teller? } - source is
--                 "observed" | "heard" (sound origin, imprecise) |
--                 "told" (teller named; observed > heard > told, and told
--                 beliefs are never retold - no chains of whispers);
--                 a ZAO body may also carry form, performance, and
--                 attribute mutations
--   people[name]  { x, y, dist, at, source, condition ("ok|hurt|bad"
--                 with "+u" when visibly unkempt), seenInFaction? -
--                 durable across re-scans: a fresh look updates position,
--                 it does not cause amnesia; a living body changed by
--                 ZAO may also carry form, performance, and attributes }
--   factions[g]   { baseX/Y, bounds, at, source, name?, stance } - where
--                 a held place is (observed near it, or told); its NAME
--                 travels only by a member's introduction; no decay
--                 (places do not move; dissolved factions ghost in old
--                 heads deliberately)
--
-- Distance is PERSONAL (F-014): queries recompute from the asker's
-- position. Decay: a belief past its horizon is not acted on; past twice
-- the horizon it is forgotten. "Believes clear" and "has not looked" stay
-- distinguishable via lastScanAt.

SAO = SAO or {}
SAO.Perception = SAO.Perception or {}
local P = SAO.Perception

-- id -> { zombies = { [key]=belief }, people = { [name]=belief },
--         lastScanAt, scanCount }
--
-- [C15] Whole minds survive the reload (DR-020): this table is bound
-- to a ModData store at game start, so the engine saves and loads it
-- with the world. Before the bind (module load runs earlier than
-- ModData), writes land in this plain table and are carried into the
-- store when it opens. Growth is bounded by the decay pass and the
-- death funnel (P.forget), as before.
P.beliefs = P.beliefs or {}

-- [C108] Counted whenever any belief record is written, dropped, or
-- the whole store is swapped for a save's. Derived group answers
-- (a company's ranked places) recompute against this number, so a
-- derivation is never served after the facts moved under it - the
-- cost law of [C77] without a cache that lies.
P.beliefVersion = P.beliefVersion or 0

-- The bind itself lives at the bottom of this file, past the one
-- logging door it reports through.

-- [B49] measured this as frames and called the oddity by name: "a
-- belief's shelf life following the graphics card." [C112] ends the
-- oddity the whole-mod way - the tick is the county's clock now (a
-- 9000th of a county hour, `SAO.History.ticks`), so these spans keep
-- their numbers and their default-day pace on every machine, and the
-- horizons stay in step with the scan that feeds them because both
-- read the same axis.
local ZOMBIE_HORIZON = 600     -- county ticks a zombie belief stays actionable
local PEOPLE_HORIZON = 1800
local SCAN_INTERVAL  = 20      -- acquisition cadence per survivor, county ticks
-- [B20] How long a recognised cry keeps its tile from being read
-- as a threat. ONE definition: the guard in the S-row path and
-- the prune in the decay pass both read this, or they drift and
-- the table leaks.
local CRY_RECOGNITION = 600

-- [C32] How long THIS person keeps a recent belief: the horizon above
-- times a factor that is a fact about them (SAO_Conditions.memoryFactor
-- - the demented keep the recent half as long, the old past
-- seventy-five a fifth less, the haunted keep a threat half again as
-- long). Knowledge decays per person, not at one rate (DR-032). One
-- for everyone else, so nothing below moves for them. Read once per
-- pass, not per belief.
local function horizonFor(id, kind)
    local base = (kind == "zombies") and ZOMBIE_HORIZON or PEOPLE_HORIZON
    local factor = 1.0
    pcall(function() factor = SAO.Conditions.memoryFactor(id, kind) end)
    if type(factor) ~= "number" or factor <= 0 then factor = 1.0 end
    return base * factor
end
P.horizonFor = horizonFor

local function parseAttributes(text)
    local attributes = {}
    for name, value in string.gmatch(
            tostring(text or ""), "([^=;]+)=([^;]+)") do
        attributes[name] = tonumber(value) or 0.0
    end
    return attributes
end
-- [C5] A person talking does not say coordinates. These bands turn a
-- believed position into the words somebody standing HERE would use
-- for it; the figures are judgments about speech, not reaches, and
-- nothing gates on them.
local WORD_CLOSE = 20          -- tiles: "just <dir> of here"
local WORD_WALK  = 75          -- tiles: "a short walk <dir>"
local WORD_FAR   = 300         -- tiles: "a good walk <dir>"

-- [C5] Where a thing is, said the way a person says it, from where
-- the speaker stands. World text is a person talking (SPEECH.md):
-- every renderer that used to print "at 10842,9195" reads this now.
function P.whereWord(x, y, fromX, fromY)
    if not (x and y and fromX and fromY) then return "somewhere about" end
    local dx, dy = x - fromX, y - fromY
    local d = math.sqrt(dx * dx + dy * dy)
    local dir
    if math.abs(dx) > 2 * math.abs(dy) then
        dir = dx > 0 and "east" or "west"
    elseif math.abs(dy) > 2 * math.abs(dx) then
        dir = dy > 0 and "south" or "north"
    else
        dir = (dy > 0 and "south" or "north")
            .. (dx > 0 and "east" or "west")
    end
    if d <= WORD_CLOSE then return "just " .. dir .. " of here" end
    if d <= WORD_WALK then return "a short walk " .. dir end
    if d <= WORD_FAR then return "a good walk " .. dir end
    return "a long way " .. dir
end
-- [B35] How close a survivor must be to notice a place is nobody's
-- now. The same eight tiles the dormant drift uses to LEARN a place
-- ([A15]), because learning and forgetting should not have different
-- reaches.
-- [B40] EXPORTED, because the comment above was a claim nobody
-- enforced. This was a file-level local read four times here, for
-- FORGETTING, while SAO_Population hardcoded the number eight times
-- for LEARNING - so "learning and forgetting should not have
-- different reaches" was true only by coincidence. Move this and the
-- two halves diverge silently: a survivor could learn a place at
-- eight tiles they can only forget at ten.
P.PLACE_SIGHT = 8

-- [B40] And how near to learn where a COMPANY's ground is. Wider
-- than a personal place because a faction's base is a bigger and more
-- visible thing - a camp is seen from further off than a house. Was
-- spelled bare four lines below; named here so the two sight reaches
-- sit together and their difference is a stated choice.
P.FACTION_SIGHT = 12

-- [B43] How wide a NAMED GROUND is, for the purpose of talking about
-- it. Not a sight reach at all - the two above are about learning a
-- place by being near it, and this is about which of your beliefs
-- COUNT as being about somewhere when you brief a goer or hear their
-- report.
--
-- [B19] built the report as "the briefing's own idiom, reversed and
-- bounded identically", and then bounded both with a bare `1600` -
-- forty tiles squared - written six times across `announceDeparture`
-- and `reportReturn`. Identical by intent and by coincidence at once:
-- nothing tied the two ends together, so the sentence saying they
-- match was true only for as long as nobody edited one of them.
--
-- Squared where it is used, the way [B41] made `MEET_RANGE` agree
-- with its own docstring by construction.
P.GROUND_REACH = 40

-- [B43] How far an ordinary spoken word carries. Two sites asked it
-- and both typed it bare: `announceDeparture` deciding who is close
-- enough to HEAR somebody say they are leaving, and the controller
-- deciding who is close enough to be TOLD something. That is one rule -
-- people within earshot - spelled in two files.
--
-- It sits four lines from GROUND_REACH deliberately, because the two
-- live in the SAME FUNCTION and are not the same thing: forty tiles is
-- what the announcement is ABOUT, ten is who can hear it. Different
-- numbers, one function, two rules - which is the trap of [B40] run
-- backwards, and the reason each is named for what it governs rather
-- than for how far it reaches.
--
-- A CRY is louder and is not this: `cryForHelp` carries 20 tiles scaled
-- by the weather's own masking, because screaming is not speaking.
P.EARSHOT = 10

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("PERCEPT", msg) end

local function store(id)
    P.beliefs[id] = P.beliefs[id] or { zombies = {}, people = {},
        factions = {}, places = {}, lastScanAt = 0, scanCount = 0 }
    P.beliefs[id].factions = P.beliefs[id].factions or {}
    P.beliefs[id].places = P.beliefs[id].places or {}
    return P.beliefs[id]
end

-- Completed transfers are dated episodes, separate from short-lived position
-- sightings and current source contents. The initial recall span follows the
-- existing fourteen-day relation window; personal memory conditions scale it.
local TRANSFER_LIMIT = 64
local TRANSFER_HOURS = 14 * 24

local function transferNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function transferNow(given)
    if given ~= nil then
        return transferNumber(given) and given >= 0 and given or nil
    end
    local ok, at = pcall(function() return SAO.History.countyHours() end)
    return ok and transferNumber(at) and at >= 0 and at or nil
end

local function appraisalCopy(fact, now)
    local appraisal = fact.appraisal
    if type(appraisal) ~= "table" or not transferNumber(appraisal.reciprocity)
        or appraisal.reciprocity < -1 or appraisal.reciprocity > 1 then return nil end
    if fact.source == "observed" and transferNumber(appraisal.pressure)
        and appraisal.pressure >= 0 and appraisal.pressure <= 1 then
        return { pressure = appraisal.pressure,
            reciprocity = appraisal.reciprocity }
    end
    if fact.source ~= "told" or appraisal.basis ~= "testimony-household-request"
        or not transferNumber(appraisal.appraisedAt)
        or appraisal.appraisedAt < fact.acquiredAt
        or (now ~= nil and appraisal.appraisedAt > now)
        or not transferNumber(appraisal.evidenceWeight)
        or appraisal.evidenceWeight < 0 or appraisal.evidenceWeight > 0.4
        or not transferNumber(appraisal.relationshipTrust)
        or appraisal.relationshipTrust < -1 or appraisal.relationshipTrust > 1
        or not transferNumber(appraisal.tellerTrust)
        or appraisal.tellerTrust < -1 or appraisal.tellerTrust > 1
        or not transferNumber(appraisal.compassion)
        or appraisal.compassion < 0.15 or appraisal.compassion > 0.85
        or type(appraisal.requestGroupId) ~= "string"
        or appraisal.requestGroupId == ""
        or appraisal.requestCategory ~= "food"
        or not transferNumber(appraisal.requestedAt)
        or not transferNumber(appraisal.requestAcquiredAt)
        or appraisal.requestedAt > fact.eventAt
        or appraisal.requestedAt > appraisal.requestAcquiredAt
        or appraisal.requestAcquiredAt > appraisal.appraisedAt
        or (appraisal.requestSource ~= "requested"
            and appraisal.requestSource ~= "told")
        or (appraisal.requestSource == "told"
            and (type(appraisal.requestTeller) ~= "string"
                or appraisal.requestTeller == ""))
        or (appraisal.requestSource == "requested"
            and appraisal.requestTeller ~= nil)
        or type(appraisal.requestOriginId) ~= "string"
        or appraisal.requestOriginId == ""
        or not transferNumber(appraisal.requestOriginAcquiredAt)
        or appraisal.requestOriginAcquiredAt < appraisal.requestedAt
        or appraisal.requestOriginAcquiredAt > appraisal.requestAcquiredAt
        or (appraisal.claimKind ~= "faction" and appraisal.claimKind ~= "place")
        or (appraisal.claimSource ~= "observed"
            and appraisal.claimSource ~= "heard"
            and appraisal.claimSource ~= "told")
        or (appraisal.claimSource == "told"
            and (type(appraisal.claimTeller) ~= "string"
                or appraisal.claimTeller == ""))
        or (appraisal.claimSource ~= "told"
            and appraisal.claimTeller ~= nil)
        or not transferNumber(appraisal.claimMinX)
        or not transferNumber(appraisal.claimMinY)
        or not transferNumber(appraisal.claimMaxX)
        or not transferNumber(appraisal.claimMaxY)
        or appraisal.claimMinX > appraisal.claimMaxX
        or appraisal.claimMinY > appraisal.claimMaxY
        or not transferNumber(fact.x) or not transferNumber(fact.y)
        or fact.x < appraisal.claimMinX or fact.x > appraisal.claimMaxX
        or fact.y < appraisal.claimMinY or fact.y > appraisal.claimMaxY then
        return nil
    end
    return {
        basis = appraisal.basis, appraisedAt = appraisal.appraisedAt,
        reciprocity = appraisal.reciprocity,
        evidenceWeight = appraisal.evidenceWeight,
        relationshipTrust = appraisal.relationshipTrust,
        tellerTrust = appraisal.tellerTrust,
        compassion = appraisal.compassion,
        requestGroupId = appraisal.requestGroupId,
        requestCategory = appraisal.requestCategory,
        requestedAt = appraisal.requestedAt,
        requestAcquiredAt = appraisal.requestAcquiredAt,
        requestSource = appraisal.requestSource,
        requestTeller = appraisal.requestTeller,
        requestOriginId = appraisal.requestOriginId,
        requestOriginAcquiredAt = appraisal.requestOriginAcquiredAt,
        claimKind = appraisal.claimKind,
        claimSource = appraisal.claimSource,
        claimTeller = appraisal.claimTeller,
        claimMinX = appraisal.claimMinX, claimMinY = appraisal.claimMinY,
        claimMaxX = appraisal.claimMaxX, claimMaxY = appraisal.claimMaxY,
    }
end

local function transferCopy(fact, includeAppraisal, now)
    local out = {}
    for _, key in ipairs({ "eventId", "actorId", "operation", "itemType",
        "category", "sourceId", "placeId", "x", "y", "z", "eventAt",
        "acquiredAt", "source", "teller", "originId", "originSource",
        "originAcquiredAt" }) do
        out[key] = fact[key]
    end
    if includeAppraisal then out.appraisal = appraisalCopy(fact, now) end
    return out
end

local function transferHorizon(id)
    local ok, factor = pcall(function()
        return SAO.Conditions.memoryFactor(id, "transfers")
    end)
    if not ok or not transferNumber(factor) or factor <= 0 then factor = 1 end
    return TRANSFER_HOURS * factor
end

local function transferState(fact, now, horizon)
    if type(fact) ~= "table" or not transferNumber(fact.eventAt)
        or not transferNumber(fact.acquiredAt)
        or fact.eventAt < 0 or fact.eventAt > fact.acquiredAt
        or fact.acquiredAt > now
        or type(fact.eventId) ~= "string" or fact.eventId == ""
        or type(fact.actorId) ~= "string" or fact.actorId == ""
        or type(fact.itemType) ~= "string" or fact.itemType == ""
        or type(fact.sourceId) ~= "string" or fact.sourceId == ""
        or (fact.operation ~= "store" and fact.operation ~= "acquire")
        or (fact.category ~= "food" and fact.category ~= "water")
        or not transferNumber(fact.x) or not transferNumber(fact.y)
        or not transferNumber(fact.z)
        or (fact.source ~= "performed" and fact.source ~= "observed"
            and fact.source ~= "told")
        or type(fact.originId) ~= "string" or fact.originId == ""
        or (fact.originSource ~= "performed" and fact.originSource ~= "observed")
        or not transferNumber(fact.originAcquiredAt)
        or fact.originAcquiredAt < fact.eventAt
        or fact.originAcquiredAt > fact.acquiredAt
        or (fact.source == "told" and (type(fact.teller) ~= "string"
            or fact.teller == "")) then return "unavailable" end
    return now - fact.eventAt <= horizon and "remembered" or "forgotten"
end

local function transferOrder(a, b)
    local atA, atB = tonumber(a.eventAt) or -math.huge,
        tonumber(b.eventAt) or -math.huge
    if atA ~= atB then return atA < atB end
    return tostring(a.eventId) < tostring(b.eventId)
end

-- A detached reader: questions neither create a mind nor refresh its memory.
-- Forgotten entries reveal no former actor, item or location to a consumer.
function P.transferFacts(id, nowHours)
    local now = transferNow(nowHours)
    local b = P.beliefs[tostring(id or "")]
    if not now or not b or type(b.transfers) ~= "table" then
        return {}, "unavailable"
    end
    local ordered = {}
    for eventId, fact in pairs(b.transfers) do
        ordered[#ordered + 1] = { eventId = tostring(eventId),
            eventAt = type(fact) == "table" and fact.eventAt or nil,
            fact = fact }
    end
    table.sort(ordered, transferOrder)
    local out, horizon = {}, transferHorizon(id)
    for _, entry in ipairs(ordered) do
        local state = transferState(entry.fact, now, horizon)
        local fact = state == "remembered" and transferCopy(entry.fact, true, now)
            or { eventId = entry.eventId }
        fact.state = state
        out[#out + 1] = fact
    end
    return out, "available"
end

function P.transferFact(id, eventId, nowHours)
    local facts, availability = P.transferFacts(id, nowHours)
    for _, fact in ipairs(facts) do
        if fact.eventId == tostring(eventId or "") then
            return fact, fact.state
        end
    end
    return nil, availability == "available" and "not-known" or "unavailable"
end

function P.reciprocityToward(id, actorId, nowHours)
    local strongest, eventId = 0, nil
    for _, fact in ipairs(P.transferFacts(id, nowHours)) do
        local value = fact.appraisal and fact.appraisal.reciprocity
        if fact.state == "remembered"
            and (fact.source == "observed" or fact.source == "told")
            and fact.actorId == tostring(actorId or "") and transferNumber(value)
            and math.abs(value) >= math.abs(strongest) then
            strongest, eventId = value, fact.eventId
        end
    end
    return strongest, eventId
end

local function sameTransfer(a, b)
    for _, key in ipairs({ "eventId", "actorId", "operation", "itemType",
        "category", "sourceId", "placeId", "x", "y", "z", "eventAt" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

local function rememberTransfer(id, fact)
    local b = store(tostring(id))
    b.transfers = b.transfers or {}
    if type(b.transferFloor) == "table" and not transferOrder(b.transferFloor, fact) then
        return false
    end
    local existing = b.transfers[fact.eventId]
    -- The first telling stays dated; another telling cannot refresh it or
    -- replace a firsthand episode. A captured firsthand result may replace
    -- testimony about that exact same event.
    if existing and (existing.source ~= "told" or fact.source == "told") then
        return false
    end
    b.transfers[fact.eventId] = transferCopy(fact, true, transferNow())
    local ordered = {}
    for eventId, entry in pairs(b.transfers) do
        ordered[#ordered + 1] = { eventId = eventId, eventAt = entry.eventAt }
    end
    table.sort(ordered, transferOrder)
    for i = 1, #ordered - TRANSFER_LIMIT do
        b.transfers[ordered[i].eventId] = nil
        b.transferFloor = { eventAt = ordered[i].eventAt, eventId = ordered[i].eventId }
    end
    P.beliefVersion = P.beliefVersion + 1
    return b.transfers[fact.eventId] ~= nil
end

-- The action owner supplies witnesses captured at the native transfer. Later
-- membership, proximity and receipt reconciliation never add witnesses.
function P.receiveTransferResult(receipt)
    if type(receipt) ~= "table" then return false, "invalid-result" end
    local observation = receipt.transferObservation
    if receipt.status ~= "completed" and receipt.status ~= "conflict"
        and receipt.status ~= "released" and receipt.status ~= "interrupted" then
        return false, "unperformed-transfer"
    end
    if observation == nil then
        if receipt.status == "completed" then return true, "observation-unavailable" end
        return false, "unproved-transfer"
    end
    if type(observation) ~= "table" or observation.nativeTransferProven ~= true
        or (receipt.operation ~= "store" and receipt.operation ~= "acquire") then
        return false, "unproved-transfer"
    end
    local now = transferNow()
    if not now then return false, "clock-unavailable" end
    if type(observation) ~= "table"
        or type(observation.witnesses) ~= "table"
        or type(receipt.reservationId) ~= "string" or receipt.reservationId == ""
        or type(receipt.actorId) ~= "string" or receipt.actorId == ""
        or observation.actorId ~= receipt.actorId
        or type(receipt.itemType) ~= "string" or receipt.itemType == ""
        or type(receipt.sourceId) ~= "string" or receipt.sourceId == ""
        or (receipt.category ~= "food" and receipt.category ~= "water")
        or not transferNumber(observation.at) or observation.at < 0
        or not transferNumber(receipt.at) or observation.at > receipt.at
        or receipt.at > now or not transferNumber(observation.x)
        or not transferNumber(observation.y) or not transferNumber(observation.z) then
        return false, "invalid-observation"
    end
    local fact = { eventId = receipt.reservationId, actorId = receipt.actorId,
        operation = receipt.operation, itemType = receipt.itemType,
        category = receipt.category, sourceId = receipt.sourceId,
        placeId = receipt.placeId and tostring(receipt.placeId) or nil,
        x = observation.x, y = observation.y, z = observation.z,
        eventAt = observation.at, acquiredAt = observation.at,
        originAcquiredAt = observation.at }
    local recipients = { [receipt.actorId] = "performed" }
    local count = 0
    for key, witness in pairs(observation.witnesses) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key)
            or type(witness) ~= "string" or witness == "" then
            return false, "invalid-witnesses"
        end
        if witness ~= receipt.actorId then recipients[witness] = "observed" end
    end
    if count ~= #observation.witnesses then return false, "invalid-witnesses" end
    local appraisals = observation.appraisals
    if appraisals ~= nil and type(appraisals) ~= "table" then
        return false, "invalid-appraisal"
    end
    for id, appraisal in pairs(appraisals or {}) do
        if recipients[id] ~= "observed" or receipt.operation ~= "store"
            or type(appraisal) ~= "table" or not transferNumber(appraisal.pressure)
            or appraisal.pressure < 0 or appraisal.pressure > 1
            or not transferNumber(appraisal.reciprocity)
            or appraisal.reciprocity < -1 or appraisal.reciprocity > 1 then
            return false, "invalid-appraisal"
        end
    end
    for id in pairs(recipients) do
        local b = P.beliefs[id]
        local existing = b and b.transfers and b.transfers[fact.eventId]
        if existing and (type(existing) ~= "table" or not sameTransfer(existing, fact)) then
            return false, "conflicting-event"
        end
    end
    for id, source in pairs(recipients) do
        fact.source, fact.originSource, fact.originId = source, source, id
        fact.appraisal = source == "observed" and appraisals and appraisals[id] or nil
        rememberTransfer(id, fact)
    end
    return true, "recorded"
end

local function tellTransfers(fromId, toId, channel, aroundX, aroundY)
    local admitted, canConverse = pcall(function()
        return SAO.Communication.canConverse(fromId, toId, channel)
    end)
    if not admitted or canConverse ~= true then return 0 end
    local now = transferNow()
    if not now then return 0 end
    local facts, moved = P.transferFacts(fromId, now), 0
    for _, fact in ipairs(facts) do
        local inGround = true
        if aroundX and aroundY then
            local dx, dy = (fact.x or math.huge) - aroundX,
                (fact.y or math.huge) - aroundY
            inGround = fact.source ~= "told"
                and dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH
        end
        if fact.state == "remembered" and inGround
            and now - fact.eventAt <= transferHorizon(toId) then
            local told = transferCopy(fact)
            told.source, told.teller, told.acquiredAt = "told", tostring(fromId), now
            if rememberTransfer(toId, told) then moved = moved + 1 end
        end
    end
    return moved
end

-- A broadcast receipt is transport evidence owned by the listener. It says
-- which physical endpoint received which bounded claims; it does not itself
-- make any claim true. Content-specific consumers run only after this write.
local RADIO_LIMIT = 64
local RADIO_CLAIM_FIELDS = { "kind", "group", "requestedAt", "speakerId",
    "id", "a", "b", "leader", "policy", "form", "x", "y", "z",
    "target", "creed", "left", "name", "processId", "processRevision" }
local RADIO_CLAIM_FIELD_SET = {}
for _, key in ipairs(RADIO_CLAIM_FIELDS) do RADIO_CLAIM_FIELD_SET[key] = true end

local function radioClaimCopy(item)
    if type(item) ~= "table" or type(item.kind) ~= "string"
        or item.kind == "" then return nil end
    local copy = {}
    for key, value in pairs(item) do
        if type(key) ~= "string" or not RADIO_CLAIM_FIELD_SET[key] then
            return nil
        end
        if type(value) ~= "string" and type(value) ~= "number"
            and type(value) ~= "boolean" then return nil end
        if type(value) == "number" and not transferNumber(value) then
            return nil
        end
        copy[key] = value
    end
    return copy
end

local function radioReceiptCopy(receipt)
    if type(receipt) ~= "table" then return nil end
    local out = { broadcastId = receipt.broadcastId,
        sourceId = receipt.sourceId, frequency = receipt.frequency,
        receivedAt = receipt.receivedAt,
        representation = receipt.representation,
        deviceItemId = receipt.deviceItemId,
        deviceType = receipt.deviceType, channel = receipt.channel,
        power = receipt.power, claims = {} }
    for _, item in ipairs(receipt.claims or {}) do
        local claim = radioClaimCopy(item)
        if not claim then return nil end
        out.claims[#out.claims + 1] = claim
    end
    return out
end

local function sameRadioReceipt(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for _, key in ipairs({ "broadcastId", "sourceId", "frequency",
        "receivedAt", "representation", "deviceItemId", "deviceType",
        "channel", "power" }) do
        if a[key] ~= b[key] then return false end
    end
    if #(a.claims or {}) ~= #(b.claims or {}) then return false end
    for i, left in ipairs(a.claims or {}) do
        local right = b.claims[i]
        for _, key in ipairs(RADIO_CLAIM_FIELDS) do
            if left[key] ~= right[key] then return false end
        end
    end
    return true
end

function P.recordRadioReception(id, broadcastId, sourceId, frequency,
        receivedAt, access, items)
    local now = transferNow()
    if not now or type(id) ~= "string" or id == ""
        or type(broadcastId) ~= "string" or broadcastId == ""
        or type(sourceId) ~= "string" or sourceId == ""
        or type(frequency) ~= "number" or frequency ~= math.floor(frequency)
        or frequency <= 0 or frequency > 1000000
        or not transferNumber(receivedAt) or receivedAt < 0 or receivedAt > now
        or type(access) ~= "table"
        or (access.representation ~= "loaded"
            and access.representation ~= "dormant")
        or type(access.deviceItemId) ~= "number"
        or access.deviceItemId ~= math.floor(access.deviceItemId)
        or type(access.deviceType) ~= "string" or access.deviceType == ""
        or access.channel ~= frequency or not transferNumber(access.power)
        or access.power < 0 or access.power > 1.000001
        or type(items) ~= "table" then return false, "invalid-reception" end
    local claims, count = {}, 0
    for key, item in pairs(items) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key)
            or key > 64 then return false, "invalid-claims" end
        local claim = radioClaimCopy(item)
        if not claim then return false, "invalid-claims" end
        claims[key] = claim
    end
    if count ~= #items then return false, "invalid-claims" end
    local receipt = { broadcastId = broadcastId, sourceId = sourceId,
        frequency = frequency, receivedAt = receivedAt,
        representation = access.representation,
        deviceItemId = access.deviceItemId, deviceType = access.deviceType,
        channel = access.channel, power = access.power, claims = claims }
    local b = store(id)
    b.radioReceptions = b.radioReceptions or {}
    local existing = b.radioReceptions[broadcastId]
    if existing then
        return sameRadioReceipt(existing, receipt),
            sameRadioReceipt(existing, receipt) and radioReceiptCopy(existing)
                or "conflicting-reception"
    end
    local order = { eventAt = receivedAt, eventId = broadcastId }
    if type(b.radioReceptionFloor) == "table"
        and not transferOrder(b.radioReceptionFloor, order) then
        return false, "evicted-reception"
    end
    b.radioReceptions[broadcastId] = receipt
    local ordered = {}
    for eventId, value in pairs(b.radioReceptions) do
        ordered[#ordered + 1] = { eventId = eventId,
            eventAt = value.receivedAt }
    end
    table.sort(ordered, transferOrder)
    for i = 1, #ordered - RADIO_LIMIT do
        b.radioReceptions[ordered[i].eventId] = nil
        b.radioReceptionFloor = { eventAt = ordered[i].eventAt,
            eventId = ordered[i].eventId }
    end
    P.beliefVersion = P.beliefVersion + 1
    return b.radioReceptions[broadcastId] ~= nil,
        radioReceiptCopy(b.radioReceptions[broadcastId])
end

function P.radioReceptions(id, strict)
    local b = P.beliefs[tostring(id or "")]
    if strict and b and b.radioReceptions ~= nil
        and type(b.radioReceptions) ~= "table" then
        return nil, "radio-reception-unreadable"
    end
    if not b or type(b.radioReceptions) ~= "table" then return {} end
    local ordered = {}
    for broadcastId, receipt in pairs(b.radioReceptions) do
        if strict then
            if type(receipt) ~= "table" or type(receipt.claims) ~= "table" then
                return nil, "radio-reception-unreadable"
            end
            local count = 0
            for index in pairs(receipt.claims) do
                count = count + 1
                if type(index) ~= "number" or index < 1 or index ~= math.floor(index)
                    or index > #receipt.claims or count > 64 then
                    return nil, "radio-reception-unreadable"
                end
            end
            if count ~= #receipt.claims then return nil, "radio-reception-unreadable" end
        end
        local copy = radioReceiptCopy(receipt)
        if strict and (not copy or copy.broadcastId ~= broadcastId
            or type(copy.sourceId) ~= "string" or copy.sourceId == ""
            or not transferNumber(copy.receivedAt)) then
            return nil, "radio-reception-unreadable"
        end
        if copy then
            ordered[#ordered + 1] = { eventId = broadcastId,
                eventAt = copy.receivedAt, receipt = copy }
        end
    end
    table.sort(ordered, transferOrder)
    local out = {}
    for _, entry in ipairs(ordered) do out[#out + 1] = entry.receipt end
    return out
end

function P.radioReception(id, broadcastId)
    for _, receipt in ipairs(P.radioReceptions(id)) do
        if receipt.broadcastId == tostring(broadcastId or "") then
            return receipt
        end
    end
    return nil
end

local AID_REQUEST_HOURS = 96

function P.recordAidRequest(id, groupId, requestedAt, source, teller, category,
                            processId, processRevision, channel, evidence)
    local now = transferNow()
    if not now or type(id) ~= "string" or id == ""
        or type(groupId) ~= "string" or groupId == ""
        or not transferNumber(requestedAt) or requestedAt < 0
        or requestedAt > now or now - requestedAt > AID_REQUEST_HOURS
        or (category ~= nil and category ~= "food")
        or (source ~= "requested" and source ~= "told") then return false end
    category = category or "food"
    if processId ~= nil and (type(processId) ~= "string" or processId == ""
        or type(processRevision) ~= "number"
        or processRevision < 1
        or processRevision ~= math.floor(processRevision)) then return false end
    local originId, originAcquiredAt = id, requestedAt
    if source == "told" then
        if type(teller) ~= "string" or teller == "" then return false end
        local from = P.beliefs[teller]
        local original = from and from.aidRequests and from.aidRequests[groupId]
        local originalCategory = type(original) == "table"
            and (original.category or "food") or nil
        if type(original) ~= "table" or original.requestedAt ~= requestedAt
            or originalCategory ~= category
            or original.processId ~= processId
            or original.processRevision ~= processRevision
            or not transferNumber(original.acquiredAt)
            or original.acquiredAt > now then return false end
        originId = original.originId
        originAcquiredAt = original.originAcquiredAt
        if type(originId) ~= "string" or originId == ""
            or not transferNumber(originAcquiredAt)
            or originAcquiredAt < requestedAt
            or originAcquiredAt > now then return false end
    end
    local b = store(id)
    b.aidRequests = b.aidRequests or {}
    local order = { eventAt = requestedAt, eventId = groupId }
    if type(b.aidRequestFloor) == "table" and not transferOrder(b.aidRequestFloor, order) then
        return false
    end
    local existing = b.aidRequests[groupId]
    if type(existing) == "table" then
        if existing.requestedAt > requestedAt then return false end
        if (existing.category or "food") ~= category then return false end
        if existing.requestedAt == requestedAt
            and (existing.source == "requested" or source == "told") then
            return true
        end
    end
    b.aidRequests[groupId] = { groupId = groupId, category = category,
        requestedAt = requestedAt,
        acquiredAt = source == "requested" and requestedAt or now,
        source = source, teller = source == "told" and teller or nil,
        originId = originId, originAcquiredAt = originAcquiredAt,
        processId = processId, processRevision = processRevision }
    local ordered = {}
    for group, request in pairs(b.aidRequests) do
        ordered[#ordered + 1] = { eventId = group, eventAt = request.requestedAt }
    end
    table.sort(ordered, transferOrder)
    for i = 1, #ordered - TRANSFER_LIMIT do
        b.aidRequests[ordered[i].eventId] = nil
        b.aidRequestFloor = { eventAt = ordered[i].eventAt, eventId = ordered[i].eventId }
    end
    P.beliefVersion = P.beliefVersion + 1
    if processId and SAO.Organization and SAO.Organization.recordReception then
        local received = nil
        if source == "told" and SAO.Organization.recordTransportReception then
            received = SAO.Organization.recordTransportReception(processId,
                originId, id, processRevision, channel or source,
                teller, evidence or {
                    requestedAt = requestedAt, category = category })
        else
            received = SAO.Organization.recordReception(processId, id,
                processRevision, channel or source, teller or originId,
                evidence or { requestedAt = requestedAt, category = category })
        end
        if received ~= true then
            b.aidRequests[groupId] = existing
            return false
        end
    end
    return b.aidRequests[groupId] ~= nil
end

-- Request age and destination knowledge are independent. Hearing a request
-- can leave a person unable to locate the house that asked.
function P.knownAidRequests(id, nowHours)
    local current = transferNow()
    local b, now = P.beliefs[tostring(id or "")], transferNow(nowHours)
    if not now or not b or type(b.aidRequests) ~= "table" then
        return {}, "unavailable"
    end
    local out = {}
    for groupId, request in pairs(b.aidRequests) do
        if type(request) == "table" and transferNumber(request.requestedAt)
            and transferNumber(request.acquiredAt) and request.requestedAt >= 0
            and request.requestedAt <= request.acquiredAt and request.acquiredAt <= now
            and now - request.requestedAt <= AID_REQUEST_HOURS
            and (request.category == nil or request.category == "food")
            and (request.source == "requested" or request.source == "told") then
            -- C67 had one request producer, callForBread, so a persisted
            -- pre-C69 row with no category is unambiguously food.
            local category = request.category or "food"
            local copy = { groupId = groupId, category = category,
                requestedAt = request.requestedAt,
                acquiredAt = request.acquiredAt, source = request.source,
                teller = request.teller, originId = request.originId,
                originAcquiredAt = request.originAcquiredAt,
                processId = request.processId,
                processRevision = request.processRevision }
            local ground = b.factions and b.factions[groupId]
                or b.places and b.places[groupId]
            -- Legacy ground beliefs do not preserve this recipient's actual
            -- acquisition time. They support current routing, not a historical
            -- join that would give yesterday's request tomorrow's location.
            if now == current and type(ground) == "table" and transferNumber(ground.minX)
                and transferNumber(ground.minY) and transferNumber(ground.maxX)
                and transferNumber(ground.maxY) and ground.minX <= ground.maxX
                and ground.minY <= ground.maxY then
                copy.minX, copy.minY, copy.maxX, copy.maxY = ground.minX,
                    ground.minY, ground.maxX, ground.maxY
            end
            out[#out + 1] = copy
        end
    end
    table.sort(out, function(a, b)
        if a.requestedAt ~= b.requestedAt then return a.requestedAt < b.requestedAt end
        return tostring(a.groupId) < tostring(b.groupId)
    end)
    return out, "available"
end

function P.knownAidRequest(id, groupId, nowHours)
    local requests, availability = P.knownAidRequests(id, nowHours)
    for _, request in ipairs(requests) do
        if request.groupId == tostring(groupId or "") then return request, "available" end
    end
    return nil, availability == "available" and "not-known" or "unavailable"
end

-- Private appraisal reads an external person's execution state through the
-- registered owner. Both loaded and dormant reception use this one boundary
-- so representation cannot change which ZAO-owned inputs are admitted.
local function privateExecutionContext(id, rec, fallbackActivity)
    local bodyOwner = rec and rec.bodyOwner or "SAO"
    local registeredOwner = SAO.Communication
        and SAO.Communication.executionOwners
        and SAO.Communication.executionOwners[bodyOwner] or nil
    local execution = nil
    if bodyOwner ~= "SAO" and SAO.Communication
        and SAO.Communication.actorSnapshot then
        execution = SAO.Communication.actorSnapshot(id)
    end
    local executionAvailable = bodyOwner == "SAO"
        or registeredOwner ~= nil and type(execution) == "table"
    execution = type(execution) == "table" and execution or {}
    local activity = string.lower(tostring(execution.currentActivity
        or fallbackActivity or "dormant"))
    local ownNeed, ownNeedAvailable = rec and tonumber(rec.hunger) or 0, true
    if bodyOwner == "ZAO" then
        -- ZAO reports a source-owned competing pressure, not a diet verdict.
        -- The same value must feed loaded and dormant appraisal without SAO
        -- inferring what either living pathogen state eats or how it acts.
        if execution.competingPressureAvailable ~= false
            and tonumber(execution.competingPressure) then
            ownNeed = tonumber(execution.competingPressure)
        else
            ownNeed, ownNeedAvailable = 0, false
        end
    end
    return bodyOwner, execution, executionAvailable, activity,
        ownNeed, ownNeedAvailable
end

local function executionOwnerAppraisal(id, rec, processView, context)
    if not (rec and rec.bodyOwner and SAO.Communication
        and SAO.Communication.actorAppraisal) then return context end
    local supplied = SAO.Communication.actorAppraisal(id, processView, context)
    if type(supplied) ~= "table" then return context end
    for _, key in ipairs({ "owner", "executor", "bodyOwner",
            "currentActivity", "canAcquire", "canCarry", "canDeliver",
            "canExecute", "incapable", "dead", "contest", "ownNeed",
            "relationship", "destinationKnown", "choice", "reconsider",
            "terms", "interests", "constraints", "inputOwners" }) do
        if supplied[key] ~= nil then context[key] = supplied[key] end
    end
    return context
end

function P.appraiseAidRequest(id, groupId, owner, currentActivity)
    if not (SAO.Organization and SAO.Organization.appraiseMatter) then
        return nil, "organization-unavailable"
    end
    local request = P.knownAidRequest(id, groupId)
    if not request or not request.processId then return nil, "request-unavailable" end
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id) or nil
    local view = SAO.Organization.viewFor(id, request.processId, false)
    local proposal = view and view.proposal and view.proposal.proposal or {}
    local destination = proposal.destination
    local destinationKnown = type(destination) == "table"
        and tonumber(destination.minX) ~= nil
        and tonumber(destination.minY) ~= nil
        and tonumber(destination.maxX) ~= nil
        and tonumber(destination.maxY) ~= nil
    local relationship, hostile = 0, false
    pcall(function()
        relationship = SAO.Standing.trust(id, view.originatorId)
        hostile = SAO.Standing.isHostileTo(id, view.originatorId)
    end)
    local designation = rec and rec.designation or nil
    local bodyOwner, execution, executionAvailable, activity,
        ownNeed, ownNeedAvailable = privateExecutionContext(
            id, rec, currentActivity)
    local choice = not executionAvailable and "defer"
        or hostile and "contest"
        or (activity ~= "idle" and activity ~= "dormant") and "defer"
        or not ownNeedAvailable and "defer"
        or ownNeed >= 0.75 and "qualify"
        or destinationKnown and (designation == "forager"
            or designation == "quartermaster" or relationship >= 0.30)
            and "accept"
        or destinationKnown and "counter-propose" or "defer"
    local context = {
        owner = owner or "Perception.aid-request",
        executor = execution.executor or owner or "private-aid-appraisal",
        bodyOwner = bodyOwner,
        currentActivity = activity,
        canAcquire = executionAvailable and execution.canAcquire ~= false
            and not (rec and rec.dead),
        canCarry = executionAvailable and execution.canCarry ~= false
            and not (rec and rec.dead),
        canDeliver = executionAvailable and execution.canDeliver ~= false
            and not (rec and rec.dead),
        canExecute = executionAvailable and execution.canExecute ~= false
            and not (rec and rec.dead),
        executionOwnerAvailable = executionAvailable,
        incapable = not executionAvailable,
        dead = rec and rec.dead or false,
        contest = hostile,
        ownNeed = ownNeed,
        relationship = relationship,
        destinationKnown = destinationKnown,
        choice = choice,
        interests = { designation = designation,
            ownGroup = SAO.Standing and SAO.Standing.groupOf
                and SAO.Standing.groupOf(id) or nil },
        constraints = { represented = SAO.Body
            and SAO.Body.hasRepresentation
            and SAO.Body.hasRepresentation(id) or false,
            currentActivity = activity,
            executionOwnerAvailable = executionAvailable,
            ownNeedAvailable = ownNeedAvailable },
        inputOwners = {
            currentActivity = execution.executor
                or owner or "Perception.aid-request",
            capabilities = execution.executor
                or (bodyOwner == "ZAO" and "ZAO.Driver")
                or "SAO.DormantPopulation",
            ownNeed = bodyOwner == "ZAO"
                and (execution.inputOwners
                    and execution.inputOwners.competingPressure
                    or "ZAO.Driver") or "SAO.Identity",
            relationship = "SAO.Standing",
            interests = "SAO.Identity+SAO.Standing",
            constraints = owner or "Perception.aid-request",
        },
    }
    context = executionOwnerAppraisal(id, rec, view, context)
    return SAO.Organization.appraiseMatter(request.processId, id, context)
end

local function tellAidRequests(fromId, toId, channel, aroundX, aroundY)
    local admitted, canConverse = pcall(function()
        return SAO.Communication.canConverse(fromId, toId, channel)
    end)
    if not admitted or canConverse ~= true then return 0 end
    local requests, moved = P.knownAidRequests(fromId), 0
    for _, request in ipairs(requests) do
        local inGround = true
        if aroundX and aroundY then
            local dx = request.minX and ((request.minX + request.maxX) / 2 - aroundX)
                or math.huge
            local dy = request.minY and ((request.minY + request.maxY) / 2 - aroundY)
                or math.huge
            inGround = request.source == "requested"
                and dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH
        end
        local to = P.beliefs[toId]
        local existing = to and to.aidRequests and to.aidRequests[request.groupId]
        if inGround and (not existing or existing.requestedAt < request.requestedAt)
            and P.recordAidRequest(toId, request.groupId, request.requestedAt,
                "told", fromId, request.category, request.processId,
                request.processRevision, channel or "spoken",
                { teller = fromId }) then
            moved = moved + 1
            -- A bodyless recipient still answers from their own durable
            -- condition and relationship. The answer is formed here because
            -- this encounter proved acquisition; work waits for a body-owning
            -- executor and no dormant item transfer is invented.
            if request.processId and SAO.Organization
                and SAO.Organization.appraiseMatter then
                local rec = SAO.Identity and SAO.Identity.get
                    and SAO.Identity.get(toId) or nil
                local relationship, hostile = 0, false
                pcall(function()
                    relationship = SAO.Standing.trust(toId,
                        request.originId or fromId)
                    hostile = SAO.Standing.isHostileTo(toId,
                        request.originId or fromId)
                end)
                local view = SAO.Organization.viewFor(toId,
                    request.processId, false)
                local proposal = view and view.proposal
                    and view.proposal.proposal or {}
                local destination = proposal.destination
                local destinationKnown = type(destination) == "table"
                    and tonumber(destination.minX) ~= nil
                    and tonumber(destination.minY) ~= nil
                    and tonumber(destination.maxX) ~= nil
                    and tonumber(destination.maxY) ~= nil
                local designation = rec and rec.designation or nil
                local bodyOwner, execution, executionAvailable, activity,
                    ownNeed, ownNeedAvailable = privateExecutionContext(
                        toId, rec, nil)
                local choice = not executionAvailable and "defer"
                    or hostile and "contest"
                    or (activity ~= "idle" and activity ~= "dormant") and "defer"
                    or not ownNeedAvailable and "defer"
                    or ownNeed >= 0.75 and "qualify"
                    or destinationKnown and (designation == "forager"
                        or designation == "quartermaster"
                        or relationship >= 0.30) and "accept"
                    or destinationKnown and "counter-propose" or "defer"
                local context = {
                    owner = "Perception.dormant-encounter",
                    executor = execution.executor or "dormant-person",
                    bodyOwner = bodyOwner,
                    currentActivity = activity,
                    canAcquire = executionAvailable
                        and execution.canAcquire ~= false and not (rec and rec.dead),
                    canCarry = executionAvailable
                        and execution.canCarry ~= false and not (rec and rec.dead),
                    canDeliver = executionAvailable
                        and execution.canDeliver ~= false and not (rec and rec.dead),
                    canExecute = executionAvailable
                        and execution.canExecute ~= false and not (rec and rec.dead),
                    executionOwnerAvailable = executionAvailable,
                    incapable = not executionAvailable,
                    dead = rec and rec.dead or false,
                    contest = hostile,
                    ownNeed = ownNeed,
                    relationship = relationship,
                    destinationKnown = destinationKnown,
                    choice = choice,
                    interests = { designation = designation,
                        ownGroup = SAO.Standing and SAO.Standing.groupOf
                            and SAO.Standing.groupOf(toId) or nil },
                    constraints = { represented = false,
                        currentActivity = activity,
                        executionOwnerAvailable = executionAvailable,
                        ownNeedAvailable = ownNeedAvailable },
                    inputOwners = {
                        currentActivity = execution.executor
                            or "SAO.DormantPopulation",
                        capabilities = execution.executor
                            or (bodyOwner == "ZAO" and "ZAO.Driver")
                            or "SAO.DormantPopulation",
                        ownNeed = bodyOwner == "ZAO"
                            and (execution.inputOwners
                                and execution.inputOwners.competingPressure
                                or "ZAO.Driver") or "SAO.Identity",
                        relationship = "SAO.Standing",
                        interests = "SAO.Identity+SAO.Standing",
                        constraints = "SAO.DormantPopulation",
                    },
                }
                context = executionOwnerAppraisal(toId, rec, view, context)
                SAO.Organization.appraiseMatter(request.processId, toId, context)
            end
        end
    end
    if SAO.Communication and SAO.Communication.deliverPendingResponses then
        moved = moved + SAO.Communication.deliverPendingResponses(
            fromId, toId, channel, { exchange = "aid-request" })
        moved = moved + SAO.Communication.deliverPendingResponses(
            toId, fromId, channel, { exchange = "aid-request" })
    end
    return moved
end

-- A non-witness can form a private response only from evidence that belongs to
-- them now.  The completed act and food request arrive independently; current
-- household membership and an explicit private ground claim join them.  No
-- historical body need, giver intent, trust write, or collectible debt is
-- reconstructed.  Once formed, this appraisal stays frozen with the episode.
function P.appraiseKnownTransfers(id)
    id = tostring(id or "")
    local now = transferNow()
    local b = P.beliefs[id]
    if id == "" or not now or not b or type(b.transfers) ~= "table"
        or not (SAO.Standing and SAO.Standing.groupOf
            and SAO.Standing.trust and SAO.Disposition
            and SAO.Disposition.testimonyAssistanceAppraisal) then return 0 end
    local okGroup, groupId = pcall(SAO.Standing.groupOf, id)
    groupId = okGroup and groupId and tostring(groupId) or nil
    if not groupId or groupId == "" then return 0 end
    local request = P.knownAidRequest(id, groupId, now)
    if not request or request.category ~= "food" then return 0 end
    local claim, claimKind = b.factions and b.factions[groupId], "faction"
    if type(claim) ~= "table" then
        claim, claimKind = b.places and b.places[groupId], "place"
    end
    if type(claim) ~= "table"
        or (claim.source ~= "observed" and claim.source ~= "heard"
            and claim.source ~= "told")
        or (claim.source == "told"
            and (type(claim.teller) ~= "string" or claim.teller == ""))
        or (claim.source ~= "told" and claim.teller ~= nil)
        or not transferNumber(claim.minX) or not transferNumber(claim.minY)
        or not transferNumber(claim.maxX) or not transferNumber(claim.maxY)
        or claim.minX > claim.maxX or claim.minY > claim.maxY then return 0 end
    local changed, horizon = 0, transferHorizon(id)
    for _, fact in pairs(b.transfers) do
        if transferState(fact, now, horizon) == "remembered"
            and fact.source == "told" and fact.operation == "store"
            and fact.category == request.category and fact.actorId ~= id
            and fact.appraisal == nil and request.requestedAt <= fact.eventAt
            and fact.x >= claim.minX and fact.x <= claim.maxX
            and fact.y >= claim.minY and fact.y <= claim.maxY then
            local okTrust, tellerTrust = pcall(SAO.Standing.trust,
                id, fact.teller)
            if okTrust and transferNumber(tellerTrust)
                and tellerTrust >= -1 and tellerTrust <= 1 then
                local okAppraisal, appraisal = pcall(
                    SAO.Disposition.testimonyAssistanceAppraisal,
                    id, fact.actorId, tellerTrust)
                if okAppraisal and type(appraisal) == "table" then
                    appraisal.basis = "testimony-household-request"
                    appraisal.appraisedAt = now
                    appraisal.requestGroupId = groupId
                    appraisal.requestCategory = request.category
                    appraisal.requestedAt = request.requestedAt
                    appraisal.requestAcquiredAt = request.acquiredAt
                    appraisal.requestSource = request.source
                    appraisal.requestTeller = request.teller
                    appraisal.requestOriginId = request.originId
                    appraisal.requestOriginAcquiredAt = request.originAcquiredAt
                    appraisal.claimKind = claimKind
                    appraisal.claimSource = claim.source
                    appraisal.claimTeller = claim.teller
                    appraisal.claimMinX, appraisal.claimMinY = claim.minX, claim.minY
                    appraisal.claimMaxX, appraisal.claimMaxY = claim.maxX, claim.maxY
                    fact.appraisal = appraisal
                    fact.appraisal = appraisalCopy(fact, now)
                    if fact.appraisal then changed = changed + 1 end
                end
            end
        end
    end
    if changed > 0 then P.beliefVersion = P.beliefVersion + 1 end
    return changed
end

local function split(s, sep)
    local parts = {}
    for piece in string.gmatch(s, "([^" .. sep .. "]+)") do
        parts[#parts + 1] = piece
    end
    return parts
end

-- Acquisition: ask the scanner what is visible, integrate as observed beliefs.
-- [B19] `asleep` is not decoration. Acquisition used to run
-- "regardless of state", and that included asleep - so every
-- sleeping survivor in the county was a perfect sentry, registering
-- every zombie and passerby all night with their eyes shut. Nothing
-- depended on it, because nothing had to: an unwatched house was
-- never punished. Asleep, only what is effectively on top of you
-- registers, and nothing else does.
function P.observe(id, body, tick, asleep)
    local b = store(id)
    if tick - b.lastScanAt < SCAN_INTERVAL then return end
    b.lastScanAt = tick
    b.scanCount = b.scanCount + 1

    -- [B42] Whoever has a body learns the ground they are standing on,
    -- on the same cadence they see by. Placed here rather than in the
    -- controller's tick because this is exactly where the LIVE half of
    -- perception already throttles itself, and because it must not
    -- depend on the bridge below - whose house this is is read off the
    -- county's own claims, not off the engine.
    --
    -- The player runs through here too ([B41]), so they now learn a
    -- neighbour's ground by walking past it rather than only by being
    -- told about it.
    pcall(function()
        P.learnGroundNear(id, body:getX(), body:getY())
    end)

    if not SAOJavaBridge then return end
    local ok, seen = pcall(function() return SAOJavaBridge:perceive(body) end)
    if not ok or type(seen) ~= "string" then return end

    if seen ~= "" then
        local rows = split(seen, "|")
        if asleep then
            -- The scanner already reports a real distance per row, so
            -- this bound is READ, not modelled. Four tiles is "in the
            -- room with you".
            local near = {}
            for _, entry in ipairs(rows) do
                local f0 = split(entry, ":")
                if f0[1] == "Z" then
                    local dd = tonumber(f0[4])
                    if dd and dd <= 4.0 then near[#near + 1] = entry end
                end
            end
            rows = near
        end
        for _, entry in ipairs(rows) do
            local f = split(entry, ":")
            if f[1] == "Z" and #f >= 4 then
                local x, y, d = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
                if x and y then
                    local belief = { x = x, y = y, dist = d, at = tick, source = "observed" }
                    if f[6] == "zao" and f[7] and f[8] then
                        belief.form = f[7]
                        belief.formPerformance = tonumber(f[8]) or 0
                    end
                    if f[9] == "attrs" and f[10] then
                        belief.attributeMutations = parseAttributes(f[10])
                    end
                    -- [C124] Ground stance: crawler, tripping, or prone zombie.
                    for idx = 5, #f do
                        if f[idx] == "prone" then
                            belief.prone = true
                            break
                        end
                    end
                    if belief.form and belief.form ~= "none" then
                        pcall(function()
                            local day = math.floor(
                                (SAO.History.countyHours() or 0) / 24.0)
                            SAO.Adaptation.observe(
                                id,
                                belief.form,
                                belief.formPerformance,
                                "lived",
                                day)
                        end)
                    end
                    b.zombies[x .. "," .. y] = belief
                    -- The turned are recognizable ([B3], corrected
                    -- [C8]): the zombie's descriptor is built FRESH at
                    -- reanimation, so a name in field 5 never comes off
                    -- a turned body any more - the id does, riding the
                    -- modData the engine copies through the turn
                    -- (F-044). One resolver reads both forms; a known
                    -- face on the dead is still the county's darkest
                    -- moment, once per witness.
                    local ztag = f[5]
                    if ztag and ztag ~= "" then
                        local zid, zrec, zname =
                            SAO.Identity.resolveBodyTag(ztag)
                        if zrec and zrec.dead and zname then
                            local pb = b.people[zname]
                            if not pb then
                                pb = { x = x, y = y, dist = d, at = tick,
                                    source = "observed", dead = true }
                                b.people[zname] = pb
                            end
                            pb.dead = true
                            if not pb.turnedSeen then
                                pb.turnedSeen = true
                                pb.turned = true
                                if P.turnedHandler then
                                    pcall(P.turnedHandler, id, zname,
                                        zid, x, y, tick)
                                end
                            end
                        end
                    end
                end
            elseif f[1] == "S" and #f >= 4 then
                -- Heard: origin tile of a world sound that reached this
                -- survivor. Imprecise by nature - recorded as its own source
                -- and never upgraded past an "observed" belief.
                local x, y, d = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
                if x and y then
                    local key = x .. "," .. y
                    local existing = b.zombies[key]
                    -- [B20] You know what that was. A cry you
                    -- recognised a moment ago is not a monster on the
                    -- next scan - without this, the sound of a
                    -- housemate calling for help would write a threat
                    -- belief on the tile they are lying on.
                    local recognised = b.criedTiles and b.criedTiles[key]
                    if recognised and (tick - recognised) <= CRY_RECOGNITION then
                        -- a voice, already understood
                    elseif not existing or existing.source ~= "observed" then
                        b.zombies[key] = { x = x, y = y, dist = d, at = tick, source = "heard" }
                    end
                end
            elseif f[1] == "P" and #f >= 5 then
                local name = f[2]
                local x, y, d = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
                if name and x and y then
                    -- Durable knowledge survives the fresh look: colors
                    -- seen once are remembered ([A15] - a re-scan is a
                    -- position update, not amnesia).
                    local prev = b.people[name]
                    -- The reunion ([A28]): the observed write has
                    -- always outranked told-dead by replacement; now
                    -- the correction is a MOMENT. Scanner P rows are
                    -- living only (engine gate), so this never fires
                    -- on a corpse.
                    if prev and prev.dead and P.reunionHandler then
                        pcall(P.reunionHandler, id, name,
                            prev.teller, prev.presumed == true, tick)
                    end
                    local okRH, rh = pcall(function()
                        return SAO.History.countyHours()
                    end)
                    -- Returns teach ([A28]): seeing someone whose
                    -- departure you were told closes the out-claim
                    -- and updates the house's sense of how long that
                    -- kind of errand takes.
                    if prev and prev.out and okRH then
                        local dur = rh - (prev.out.saidAtHours or rh)
                        if dur > 0.2 then
                            local outKey = SAO.Standing.keyForObserved
                                and SAO.Standing.keyForObserved(name) or nil
                            local og9 = outKey and SAO.Standing.groupOf
                                and SAO.Standing.groupOf(outKey) or nil
                            if og9 and SAO.Standing.noteVentureReturn then
                                SAO.Standing.noteVentureReturn(
                                    og9, prev.out.kind, dur)
                            end
                            -- [B19] And they REPORT. This is the
                            -- moment the tree already finds; the
                            -- out-claim still holds the ground they
                            -- were sent to, which is exactly the
                            -- bound the briefing used on the way out.
                            -- Housemates only - you do not tell a
                            -- stranger where the hordes are.
                            if outKey and og9 and prev.out.x
                                and SAO.Standing.groupOf(id) == og9
                                and P.beliefs[outKey] then
                                local told = P.reportReturn(outKey, id,
                                    tick, prev.out.x, prev.out.y)
                                if told > 0 then
                                    pcall(function()
                                        SAO.Voice.onEvent(outKey,
                                            "report", tick)
                                    end)
                                end
                            end
                        end
                    end
                    local form, formPerformance, attributeMutations
                    if f[7] == "zao" and f[8] and f[9] then
                        form = f[8]
                        formPerformance = tonumber(f[9]) or 0
                        if f[10] == "attrs" and f[11] then
                            attributeMutations = parseAttributes(f[11])
                        end
                    end
                    -- [C116] A living person carrying a form teaches
                    -- the witness what that form is, the same moment a
                    -- formed zombie does - the returned afflicted are
                    -- the county's own mid-course people, and what
                    -- their neighbors learn from seeing them is the
                    -- same learning, on the same cadence.
                    if form and form ~= "none" then
                        pcall(function()
                            local day = math.floor(
                                (SAO.History.countyHours() or 0) / 24.0)
                            SAO.Adaptation.observe(
                                id,
                                form,
                                formPerformance,
                                "lived",
                                day)
                        end)
                    end
                    local prone = (f[6] and string.find(f[6], "+p", 1, true) ~= nil) or false
                    b.people[name] = { x = x, y = y, dist = d, at = tick,
                        atHours = okRH and rh or nil,
                        source = "observed", condition = f[6] or "ok",
                        seenInFaction = prev and prev.seenInFaction or nil,
                        form = form,
                        formPerformance = formPerformance,
                        attributeMutations = attributeMutations,
                        prone = prone }
                end
            end
        end
    end

    -- Faction acquisition ([A15]): standing within sight of a HELD place
    -- forms an observed belief about it - where it is and whose it is not
    -- (theirs). The claim rects are the scan's world-read edge, the same
    -- as seeing a zombie is. What they CALL themselves is never observed;
    -- names travel only by word of mouth.
    -- [B19] You do not learn whose ground you are standing on with
    -- your eyes shut.
    if not asleep and SAO.Standing and SAO.Standing.allGroupClaims then
        local bx2, by2 = body:getX(), body:getY()
        local myGroup = SAO.Standing.groupOf and SAO.Standing.groupOf(id) or nil
        for groupName, c in pairs(SAO.Standing.allGroupClaims()) do
            if groupName ~= myGroup
                and bx2 >= c.minX - P.FACTION_SIGHT
                and bx2 <= c.maxX + P.FACTION_SIGHT
                and by2 >= c.minY - P.FACTION_SIGHT
                and by2 <= c.maxY + P.FACTION_SIGHT then
                local existing = b.factions[groupName]
                b.factions[groupName] = {
                    baseX = math.floor((c.minX + c.maxX) / 2),
                    baseY = math.floor((c.minY + c.maxY) / 2),
                    minX = c.minX, minY = c.minY, maxX = c.maxX, maxY = c.maxY,
                    at = tick, source = "observed",
                    name = existing and existing.name or nil,
                    stance = existing and existing.stance or "neutral",
                }
            end
        end
        -- Place acquisition ([A15]): a scanned person standing inside
        -- THEIR OWN claim is the observable scene "that is their place" -
        -- the claim rect is the same world-read edge the faction block
        -- uses. Durable; told never overrides observed.
        for name, pb in pairs(b.people) do
            if (tick - pb.at) <= SCAN_INTERVAL * 2 then
                local ownerKey = SAO.Standing.keyForObserved
                    and SAO.Standing.keyForObserved(name) or nil
                local oc = ownerKey and SAO.Standing.claimOf
                    and SAO.Standing.claimOf(ownerKey) or nil
                if oc and pb.x >= oc.minX and pb.x <= oc.maxX
                    and pb.y >= oc.minY and pb.y <= oc.maxY then
                    b.places[ownerKey] = {
                        minX = oc.minX, minY = oc.minY,
                        maxX = oc.maxX, maxY = oc.maxY,
                        at = tick, source = "observed",
                    }
                end
            end
        end

        -- Membership is inferred from where people stand: a person seen
        -- INSIDE a believed base wears its colors in this survivor's eyes.
        for name, pb in pairs(b.people) do
            if (tick - pb.at) <= SCAN_INTERVAL * 2 then
                for groupName, fb in pairs(b.factions) do
                    if pb.x >= fb.minX and pb.x <= fb.maxX
                        and pb.y >= fb.minY and pb.y <= fb.maxY then
                        pb.seenInFaction = groupName
                    end
                end
            end
        end
    end

    -- decay pass
    local zombieHorizon2 = horizonFor(id, "zombies") * 2   -- [C32] this person's
    local peopleHorizon2 = horizonFor(id, "people") * 2
    for key, belief in pairs(b.zombies) do
        if tick - belief.at > zombieHorizon2 then b.zombies[key] = nil end
    end
    for name, belief in pairs(b.people) do
        -- F-033: memory of the dead is durable - a dead-flagged belief
        -- never decays, or the news would die with the clock and the
        -- county could not keep retelling its losses.
        if not belief.dead
            and tick - belief.at > peopleHorizon2 then
            b.people[name] = nil
        end
    end
    -- [B20] Recognised cries expire like everything else. Without this
    -- the table gains a permanent entry per cry per tile, in every
    -- hearer, persisted - an unbounded leak dressed as a memory. Past
    -- the recognition window the mark does nothing anyway, so keeping
    -- it is pure cost.
    if b.criedTiles then
        for key, at in pairs(b.criedTiles) do
            if tick - at > CRY_RECOGNITION then b.criedTiles[key] = nil end
        end
    end
    -- [B35] A place is unlearned the way it was learned: by being
    -- there. `places` was the one table nothing ever cleared, and
    -- unlike a stale sighting it was also WRONG - releaseClaim drops
    -- the claim and touches no belief, and believesClaimed asks
    -- whether the owner died but never whether the claim still
    -- stands. Ground given up stayed avoided for the whole session.
    --
    -- Not expiry by time: line 244 is right that place knowledge is
    -- durable, and a house does not stop being someone's because
    -- nobody looked at it. Proximity, so a survivor learns the ground
    -- is free by standing on it rather than by being told from
    -- nowhere.
    if b.places and SAO.Standing and SAO.Standing.claimOf then
        local okP, px, py = pcall(function()
            return body:getX(), body:getY()
        end)
        if okP and px and py then
            for ownerKey, pc in pairs(b.places) do
                if px >= pc.minX - P.PLACE_SIGHT
                    and px <= pc.maxX + P.PLACE_SIGHT
                    and py >= pc.minY - P.PLACE_SIGHT
                    and py <= pc.maxY + P.PLACE_SIGHT
                    and not SAO.Standing.claimOf(ownerKey) then
                    b.places[ownerKey] = nil
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Query API (what the controller is allowed to know)

-- Distance is PERSONAL (F-014): a belief's position is memory, but how far
-- it is from ME is a fact about me, now. When the asker's position is
-- given, distance is recomputed from it; the formation-time value is only
-- the fallback for callers without a body.
local function distanceFor(belief, fromX, fromY)
    if fromX and fromY then
        local dx, dy = belief.x - fromX, belief.y - fromY
        return math.sqrt(dx * dx + dy * dy)
    end
    return belief.dist
end

-- Nearest zombie this survivor currently BELIEVES in, or nil. Never scans.
-- The returned table carries dist AS SEEN FROM (fromX, fromY) when given.
function P.nearestBelievedZombie(id, tick, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return nil end
    local best, bestDist
    local horizon = horizonFor(id, "zombies")   -- [C32]
    for _, belief in pairs(b.zombies) do
        if tick - belief.at <= horizon then
            local d = distanceFor(belief, fromX, fromY)
            if not best or d < bestDist then best, bestDist = belief, d end
        end
    end
    if best then
        return { x = best.x, y = best.y, dist = bestDist, at = best.at,
                 source = best.source, teller = best.teller,
                 form = best.form, formPerformance = best.formPerformance,
                 attributeMutations = best.attributeMutations,
                 prone = best.prone and true or false }
    end
    return nil
end

-- [C116] The nearest LIVING person this survivor believes carries a
-- form - the returned afflicted, ghoul-shaped in a person's clothes
-- ([MUTATION.md]: the residue rides what capability survived). The
-- belief is a person-belief and decays on the people horizon; what it
-- carries is the form the scanner appended from the marks the
-- adoption stamped. The name rides along because a person is not a
-- tile: who they are is half of what seeing them means.
function P.nearestFormedPerson(id, tick, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return nil end
    local best, bestDist, bestName
    local horizon = horizonFor(id, "people")   -- [C32]
    for name, belief in pairs(b.people) do
        if belief.form and belief.form ~= "none"
            and tick - belief.at <= horizon then
            local d = distanceFor(belief, fromX, fromY)
            if not best or d < bestDist then
                best, bestDist, bestName = belief, d, name
            end
        end
    end
    if best then
        return { x = best.x, y = best.y, dist = bestDist, at = best.at,
                 source = best.source, name = bestName,
                 form = best.form, formPerformance = best.formPerformance,
                 attributeMutations = best.attributeMutations,
                 fromPerson = true,
                 prone = best.prone and true or false }
    end
    return nil
end

-- [C117] Does this survivor currently BELIEVE a person carries a
-- form, and which? The belief reader for every standing-side
-- question about the afflicted among the living: keyed the way
-- beliefs are keyed (the person's belief key), fresh on the people
-- horizon, answering the form or nil. Never a scan, never the truth
-- - what they believe, which is what the house argues over and the
-- company door reads.
function P.believedFormOf(id, otherKey, tick)
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(otherKey) or nil
    local key = rec and SAO.Identity.beliefKey(rec) or nil
    if not key then return nil end
    local pb = P.believedPerson(id, key)
    if not pb then return nil end
    if not (pb.form and pb.form ~= "none") then return nil end
    local horizon = horizonFor(id, "people")   -- [C32]
    if tick - (pb.at or 0) > horizon then return nil end
    return pb.form
end

-- [C116] The nearest believed carrier of a form, living or dead: the
-- zombie the survivor believes in and the person they believe is
-- shaped, whichever is closer. This is the pathogen pressure's read -
-- a body that carries the form presses the same nerve whatever
-- clothes it is wearing - and it is a SEPARATE query because the
-- callers that must never conflate the two (the engage machinery,
-- the threat count) still use the two single-kind queries.
function P.nearestBelievedThreat(id, tick, fromX, fromY)
    local zombie = P.nearestBelievedZombie(id, tick, fromX, fromY)
    local formed = P.nearestFormedPerson(id, tick, fromX, fromY)
    if formed and (not zombie or formed.dist < zombie.dist) then
        return formed
    end
    return zombie
end

function P.believedThreatCount(id, tick, radius, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return 0 end
    local n = 0
    local horizon = horizonFor(id, "zombies")   -- [C32]
    for _, belief in pairs(b.zombies) do
        if tick - belief.at <= horizon
            and distanceFor(belief, fromX, fromY) <= (radius or 10) then
            n = n + 1
        end
    end
    return n
end

-- Distinguishes "believes clear" from "has not looked recently".
function P.hasLookedRecently(id, tick)
    local b = P.beliefs[id]
    return b ~= nil and (tick - b.lastScanAt) <= SCAN_INTERVAL * 3
end

-- [C32] A threat nobody else hears (SAO_Conditions.hearsThingsNow;
-- Scotty's hallucination, at the county's cadence): a heard belief
-- placed six to twelve tiles off, on a bearing that is a fact about
-- the person and the moment, held and acted on like any other heard
-- belief and forgotten by the same decay. Marked so the record can
-- tell a phantom from a sound.
function P.hallucinate(id, tick, fromX, fromY)
    if not (fromX and fromY) then return nil end
    local b = store(id)
    local bearing = (SAO.Hash.of(id, "phantom-bearing:" .. tostring(tick)) % 360)
        * math.pi / 180
    local dist = 6 + (SAO.Hash.of(id, "phantom-dist:" .. tostring(tick)) % 7)
    local x = math.floor(fromX + math.cos(bearing) * dist)
    local y = math.floor(fromY + math.sin(bearing) * dist)
    b.zombies[x .. "," .. y] = { x = x, y = y, dist = dist, at = tick,
                                  source = "heard", phantom = true }
    return x, y
end

function P.believedPerson(id, name)
    local b = P.beliefs[id]
    return b and b.people[name] or nil
end

-- [C60] A participant candidate acquired by this person's own eyes. The
-- ordinary people horizon is memory; an immediate shared action needs the
-- last two scanner intervals and refuses told, dead or stale records.
function P.freshObservedPerson(id, name, tick, maxAge)
    if not (id and name and tick) then return nil end
    local belief = P.believedPerson(id, name)
    if not belief or belief.dead or belief.source ~= "observed" then
        return nil
    end
    local age = tick - (tonumber(belief.at) or -math.huge)
    if age < 0 or age > (maxAge or SCAN_INTERVAL * 2) then return nil end
    return belief
end

-- [C71] Laying eyes on somebody, from the half of the county that has
-- no eyes to scan with.
--
-- The live half writes this belief off the scanner - the `P` rows in
-- `observe` above. The dormant half has no body and no scanner, and it
-- has been producing firsthand meetings all along: two people standing
-- three tiles apart, teaching each other lessons, arguing doctrine,
-- passing grudges and credits, forming houses. None of it was ever
-- written down. Measured over eight counties of 1096 days: not one
-- survivor in any of them held a belief that a LIVING person was
-- anywhere, and the only person-beliefs that existed at all were death
-- notices. Law 1's second half calls that a defect - failing to act on
-- what they did see is as wrong as knowing what they did not.
--
-- Same write, same provenance, for a caller that knows who and where
-- rather than reading it off a scan. Durable knowledge survives it as
-- it does there: a fresh look is a position update, not amnesia.
function P.sawPerson(id, name, x, y, tick, otherId, dist)
    if not (id and name and x and y and tick) then return false end
    if name == "" or name == "Unnamed" then return false end
    local b = store(id)
    local prev = b.people[name]
    local hours = nil
    pcall(function() hours = SAO.History.countyHours() end)
    -- The reunion ([A28]): somebody you believed dead is standing in
    -- front of you. `observe` makes this a moment rather than a silent
    -- overwrite, and one rule with two spellings is how they drift.
    if prev and prev.dead and P.reunionHandler then
        pcall(P.reunionHandler, id, name, prev.teller,
            prev.presumed == true, tick)
    end
    b.people[name] = {
        x = x, y = y,
        -- [C87] The caller states the distance it measured; a road
        -- meeting passes the value it already computed rather than
        -- throwing it away, so a re-meeting refreshes the distance
        -- instead of carrying the first one forever. A caller that
        -- knows no distance - the same write from any other hand -
        -- keeps the seed honest: carried, then zero.
        dist = dist or (prev and prev.dist) or 0,
        at = tick, atHours = hours,
        source = "observed",
        condition = (prev and prev.condition) or "ok",
        seenInFaction = prev and prev.seenInFaction or nil,
        -- The dormant caller knows exactly who this is; the scanner
        -- never does, because it reads a name off a shell. Carried
        -- only where it is known, so `Identity.idByName` stays the
        -- answer everywhere else and this is never a second index.
        id = otherId and tostring(otherId) or (prev and prev.id) or nil,
    }
    return true
end

-- [C71] Somebody the county knew by their id has been given a name.
--
-- A person is keyed in this store by `Identity.beliefKey`, which is
-- their id until the engine hands `backfillName` a name off the first
-- shell built for them. Without this, everybody who had ever met them
-- would lose them at that moment and the county's memory of a person
-- would reset the first time a player walked near them.
--
-- Shaped on `Standing.migrateKey`, which does the same job for
-- relation rows. The sentinel is refused rather than moved: beliefs
-- keyed "Unnamed" were written before this batch and belong to no
-- particular person, so handing them to whoever materialises first
-- would invent a memory rather than carry one.
function P.migratePersonKey(oldKey, newKey)
    if not (oldKey and newKey) then return 0 end
    oldKey, newKey = tostring(oldKey), tostring(newKey)
    if oldKey == newKey or oldKey == "Unnamed" then return 0 end
    local moved = 0
    for _, b in pairs(P.beliefs) do
        local old = b.people and b.people[oldKey]
        if old then
            local held = b.people[newKey]
            -- The fresher sighting wins, and what only the older one
            -- knows is kept: a belief that somebody died does not
            -- expire because a newer look found their body walking.
            if not held or (old.at or 0) > (held.at or 0) then
                if held then
                    old.dead = old.dead or held.dead
                    old.turned = old.turned or held.turned
                    old.seenInFaction = old.seenInFaction
                        or held.seenInFaction
                end
                b.people[newKey] = old
            elseif old.dead and not held.dead then
                held.dead = true
                held.turned = held.turned or old.turned
            end
            b.people[oldKey] = nil
            moved = moved + 1
        end
    end
    return moved
end

-- [C71] Learning that somebody is dead, from the half of the county
-- that has no eyes.
--
-- `P.tell` carries death news between two people who are talking and
-- has always written this belief itself. The dormant attrition pass
-- wrote its own copy of the same thing - word reaching the bonded and
-- the company a day or two after somebody never came back - and it
-- read `P.beliefs[hearer]` directly rather than opening a store, so
-- for a survivor who had never been told anything by anybody the news
-- landed nowhere. In a dormant county that is nearly everybody: the
-- median county had ONE person in it holding any belief about any
-- person at all.
function P.learnOfDeath(id, key, x, y, tick, turned)
    if not (id and key and tick) then return false end
    if key == "" or key == "Unnamed" then return false end
    local b = store(id)
    local pb = b.people[key]
    if pb then
        pb.dead = true
        if turned then pb.turned = true end
    else
        b.people[key] = {
            x = x, y = y, dist = 999, at = tick,
            source = "told", dead = true, turned = turned or nil,
        }
    end
    if P.deathNewsHandler then
        pcall(P.deathNewsHandler, id, key, tick)
    end
    return true
end

function P.describe(id, tick)
    local b = P.beliefs[id]
    if not b then return "no-beliefs" end
    local zn, pn = 0, 0
    local zh, ph = horizonFor(id, "zombies"), horizonFor(id, "people")   -- [C32]
    for _, belief in pairs(b.zombies) do
        if tick - belief.at <= zh then zn = zn + 1 end
    end
    for _, belief in pairs(b.people) do
        if tick - belief.at <= ph then pn = pn + 1 end
    end
    return "beliefs: zombies=" .. zn .. " people=" .. pn
        .. " scans=" .. b.scanCount
        .. " looked=" .. tostring(P.hasLookedRecently(id, tick))
end

-- [B41] The listener's skepticism, in ONE place.
--
-- `P.tell` has always applied it and said why - "the LISTENER's
-- skepticism is not waived by anyone choosing to speak" - and
-- `P.reportReturn` never had to, because a briefed goer reporting back
-- to the house that briefed them is not a stranger asking to be
-- believed. A PLAYER choosing to speak is neither of those, and the
-- moment a second caller needed the rule, the rule had to become
-- something both could read rather than a line living inside one of
-- them. Two spellings of one judgement is [B40]'s defect, and this is
-- where it would have started.
function P.willBelieve(toId, fromId)
    if SAO.Standing and SAO.Standing.trust(toId, fromId) < -0.2 then
        return false
    end
    return true
end

-- [B41] Is there anything this person could pass on at all?
--
-- The menu that offers it iterated `zombies` and `places` in the
-- harness, which was a second spelling of a rule that lives here, and
-- it had the rule wrong in both directions: it never counted
-- `factions`, which `tell` carries, and it counted every zombie belief
-- when `tell` carries only the ones that are still ACTIONABLE.
--
-- That second half is the whole complaint. `tell` shares a sighting
-- only while `tick - at <= ZOMBIE_HORIZON` - about ten seconds at
-- 60fps frames on the default day - and
-- forgets it entirely at twice that. A gate that ignores the horizon
-- opens on a memory the transfer will refuse, so the option appears,
-- you speak, and nothing crosses. Opening on exactly what can cross is
-- the rule; this reads `tell`'s own test rather than approximating it.
function P.hasAnythingToPass(id, tick)
    local b = P.beliefs[id]
    if not b then return false end
    for _ in pairs(b.factions or {}) do return true end
    for _ in pairs(b.places or {}) do return true end
    local horizon = horizonFor(id, "zombies")   -- [C32]
    for _, zb in pairs(b.zombies or {}) do
        if zb.source ~= "told"
            and tick and (tick - zb.at) <= horizon then
            return true
        end
    end
    -- The death news. `tell` carries a person only when they are known
    -- dead, so this opens on the same condition: knowing somebody died
    -- and nothing else is a reason to speak, and the offer used to stay
    -- shut on it entirely.
    for _, pb in pairs(b.people or {}) do
        if pb.dead then return true end
    end
    for _, fact in ipairs(P.transferFacts(id)) do
        if fact.state == "remembered" then return true end
    end
    if #P.knownAidRequests(id) > 0 then return true end
    return false
end

-- Told-by exchange: survivor A shares actionable zombie beliefs with B.
-- Recorded as "told" with the teller named; a told belief never overrides an
-- observed one, and B's trust in A (Standing) gates acceptance.
-- [B27] `chosen` is the ONE distinction between how the player
-- communicates with them and how they communicate with each other.
-- Everything below this line - what crosses, at what provenance, who
-- is recorded as the teller, what the listener does with it - is
-- identical either way. Only the decision to open your mouth differs,
-- because for a survivor that decision is a trust calculation and for
-- a player it was a click.
function P.tell(fromId, toId, tick, chosen, channel)
    local from = P.beliefs[fromId]
    if not from then return 0 end
    -- The LISTENER's skepticism is not waived by anyone choosing to
    -- speak. A survivor who distrusts you does not believe you.
    if not P.willBelieve(toId, fromId) then return 0 end
    -- Warnings flow along trust or membership; strangers keep their own counsel.
    if not chosen and SAO.Standing
        and not SAO.Standing.sameGroup(fromId, toId)
        and SAO.Standing.trust(fromId, toId) < 0.3 then
        return 0
    end
    local to = store(toId)
    local shared = tellTransfers(fromId, toId, channel)
        + tellAidRequests(fromId, toId, channel)
    -- [C5] What actually landed, so the listener can SAY it. "They
    -- note 3 things" is not speech; a person acknowledges the thing
    -- itself. Every adoption below counts and leaves a note; the
    -- spoken acknowledgment is built at the end, most grave first.
    local deadName, factionNote, placeShared = nil, nil, false
    local zSharedN, zX, zY = 0, nil, nil
    -- The introduction: a member shares their OWN house's public facts
    -- firsthand ("we're the Rosewood Circle; we hold the place on the
    -- hill") - the only road a faction's NAME enters the belief web by.
    if SAO.Standing.sameGroup then
        local tellerGroup = SAO.Standing.groupOf(fromId)
        if tellerGroup and not SAO.Standing.sameGroup(fromId, toId) then
            local tc = SAO.Standing.groupClaimOf
                and SAO.Standing.groupClaimOf(tellerGroup) or nil
            local tname = SAO.Standing.factionName
                and SAO.Standing.factionName(tellerGroup) or nil
            if tc then
                local existing = to.factions[tellerGroup]
                if not existing or existing.source == "told" then
                    to.factions[tellerGroup] = {
                        baseX = math.floor((tc.minX + tc.maxX) / 2),
                        baseY = math.floor((tc.minY + tc.maxY) / 2),
                        minX = tc.minX, minY = tc.minY,
                        maxX = tc.maxX, maxY = tc.maxY,
                        at = tick, source = "told", teller = fromId,
                        name = tname,
                        stance = existing and existing.stance or "neutral",
                    }
                    shared = shared + 1
                    factionNote = factionNote
                        or { name = tname,
                             x = math.floor((tc.minX + tc.maxX) / 2),
                             y = math.floor((tc.minY + tc.maxY) / 2) }
                elseif not existing.name and tname then
                    existing.name = tname
                    shared = shared + 1
                    factionNote = factionNote or { name = tname,
                        x = existing.baseX, y = existing.baseY }
                end
            end
        end
    end

    -- Faction knowledge travels: where a base is, and what its people
    -- call themselves. Told never overrides observed.
    for groupName, fb in pairs(from.factions or {}) do
        local existing = to.factions[groupName]
        if not existing or existing.source == "told" then
            to.factions[groupName] = {
                baseX = fb.baseX, baseY = fb.baseY,
                minX = fb.minX, minY = fb.minY, maxX = fb.maxX, maxY = fb.maxY,
                at = fb.at, source = "told", teller = fromId,
                name = fb.name,
                stance = existing and existing.stance or "neutral",
            }
            shared = shared + 1
            factionNote = factionNote or { name = fb.name,
                x = fb.baseX, y = fb.baseY }
        elseif existing and not existing.name and fb.name then
            existing.name = fb.name
            shared = shared + 1
            factionNote = factionNote or { name = fb.name,
                x = existing.baseX, y = existing.baseY }
        end
    end
    -- Place knowledge travels ("that's the Reyes place - leave it be").
    for ownerKey, pc in pairs(from.places or {}) do
        local existing = to.places[ownerKey]
        if not existing or existing.source == "told" then
            to.places[ownerKey] = {
                minX = pc.minX, minY = pc.minY,
                maxX = pc.maxX, maxY = pc.maxY,
                at = pc.at, source = "told", teller = fromId,
            }
            shared = shared + 1
            placeShared = true
        end
    end
    -- News of the dead travels ([A19]): a teller who BELIEVES someone
    -- dead (they watched, or stood over the body) passes it on. The
    -- receiver's belief is told-weight; hearing of your bonded's death
    -- grieves through the handler - belief to belief, never a peek at
    -- the global record (DR-007).
    -- Fear presumes ([A28]): before passing word, a fearful and
    -- talkative teller reads their own stale beliefs the worst way -
    -- someone last SEEN hurt, unseen for a week of world time, is
    -- spoken of as dead. Presumption, not fabrication: the flag rides
    -- the belief so the reunion can weigh the teller's sin honestly.
    -- World-hours gate only (atHours) - beliefs lacking the stamp are
    -- never presumed (two tick clocks exist; hours is the shared one).
    do
        local okT, tt = pcall(function()
            return SAO.Disposition.traits(fromId)
        end)
        if okT and tt and tt.nerve < 0.4 and tt.talkativeness > 0.55 then
            local okH, nowH = pcall(function()
                return SAO.History.countyHours()
            end)
            if okH then
                -- The window is FELT, not flat ([A28]): the
                -- fearful bury sooner. nerve 0.15 presumes near five
                -- days; nerve up to the gate (0.4) holds past a week.
                local window = 96 + tt.nerve * 240
                for _, pb0 in pairs(from.people or {}) do
                    -- Everyone knows what a bite means ([B3]): the
                    -- bitten-absent are buried in half the time.
                    local w0 = window
                    if pb0.condition == "bitten" then w0 = window / 2 end
                    if not pb0.dead and pb0.source == "observed"
                        and pb0.condition and pb0.condition ~= "ok"
                        and pb0.atHours
                        and nowH - pb0.atHours > w0 then
                        pb0.dead = true
                        pb0.presumed = true
                    end
                end
            end
        end
    end
    for name, pb in pairs(from.people or {}) do
        if pb.dead then
            local existing = to.people[name]
            if existing then
                if not existing.dead then
                    existing.dead = true
                    shared = shared + 1
                    deadName = deadName or name
                    if P.deathNewsHandler then
                        pcall(P.deathNewsHandler, toId, name, tick)
                    end
                end
                -- "They TURNED" is exactly what people say ([B3]).
                if pb.turned and not existing.turned then
                    existing.turned = true
                end
            else
                to.people[name] = {
                    x = pb.x, y = pb.y, dist = pb.dist or 999,
                    at = tick, source = "told", teller = fromId,
                    dead = true, presumed = pb.presumed or nil,
                    turned = pb.turned or nil,
                }
                shared = shared + 1
                deadName = deadName or name
                if P.deathNewsHandler then
                    pcall(P.deathNewsHandler, toId, name, tick)
                end
            end
        end
    end
    local tellerHorizon = horizonFor(fromId, "zombies")   -- [C32] the teller's own
    for key, belief in pairs(from.zombies) do
        if tick - belief.at <= tellerHorizon and belief.source ~= "told" then
            local existing = to.zombies[key]
            if not existing or existing.source == "told" then
                -- dist here is the TELLER's; every consumer recomputes
                -- from their own position (F-014), so it is only a seed.
                to.zombies[key] = {
                    x = belief.x, y = belief.y, dist = belief.dist,
                    at = belief.at, source = "told", teller = fromId,
                    form = belief.form,
                    formPerformance = belief.formPerformance,
                    attributeMutations = belief.attributeMutations,
                }
                shared = shared + 1
                zSharedN = zSharedN + 1
                if not zX then zX, zY = belief.x, belief.y end
                if belief.form and belief.form ~= "none" then
                    pcall(function()
                        local day = math.floor(
                            (SAO.History.countyHours() or 0) / 24.0)
                        SAO.Adaptation.observe(
                            toId,
                            belief.form,
                            belief.formPerformance,
                            "told",
                            day)
                    end)
                end
            end
        end
    end
    -- [C5] The acknowledgment, gravest first, in the listener's own
    -- position words. This is what the LISTENER says back - the thing
    -- itself, never a count of things.
    local spoken = nil
    do
        local lx, ly = nil, nil
        pcall(function()
            local lb = SAO.Body and SAO.Body.get and SAO.Body.get(toId)
            if lb then lx, ly = lb:getX(), lb:getY() end
        end)
        if deadName then
            spoken = "So " .. deadName .. " is gone. I'll carry that."
        elseif zSharedN > 0 and zX then
            spoken = "The dead, " .. P.whereWord(zX, zY, lx or zX, ly or zY)
                .. ". I'll keep clear."
        elseif factionNote then
            spoken = (factionNote.name
                and ("The " .. factionNote.name .. ", ")
                or "Somebody holding ground, ")
                .. P.whereWord(factionNote.x, factionNote.y,
                    lx or factionNote.x, ly or factionNote.y)
                .. ". Good to know."
        elseif placeShared then
            spoken = "Whose ground is whose - I'll leave it be."
        end
    end
    P.appraiseKnownTransfers(toId)
    return shared, spoken
end

-- The word before the walk ([A28]): nobody leaves without telling
-- whoever is standing close enough to hear. The announcement is a
-- CLAIM in the hearers' heads - who went, what for, where roughly,
-- and when they said it. Only those told carry it; leaving unheard
-- is possible and worse.
-- The report ([B19]): the map that went out comes back. The briefing
-- moves the house's knowledge of a named ground TO the goer; nothing
-- ever moved what the goer LEARNED back, because P.tell carries
-- factions and places but never zombies - so the one thing a scout
-- is FOR could not travel. A person could stand in front of forty of
-- them, walk home, and the house would send the next one out blind.
--
-- The briefing's own idiom, reversed and bounded identically:
-- firsthand only (or the briefing would echo back and launder
-- told-knowledge into second-hand), about the ground they were sent
-- to, told-provenance with the teller stamped, and told never
-- overrides observed.
--
-- [B41] The player reports through this too, which is what made the
-- skepticism gate below necessary. A briefed goer coming home did not
-- need it - the house had sent them - so the rule lived in `tell`
-- alone. Once a second kind of speaker uses this road, a listener who
-- distrusts the speaker has to be able to refuse here as well, or
-- speaking would be believed simply because of which function carried
-- it. Applied to every caller rather than only the new one: the rule
-- is about the listener, not about the errand.
function P.reportReturn(fromId, toId, tick, aroundX, aroundY, channel)
    if not (aroundX and aroundY) then return 0 end
    local from = P.beliefs[fromId]
    local to = P.beliefs[toId]
    if not (from and to) then return 0 end
    if not P.willBelieve(toId, fromId) then return 0 end
    local moved = tellTransfers(fromId, toId, channel, aroundX, aroundY)
        + tellAidRequests(fromId, toId, channel, aroundX, aroundY)
    for key, zb in pairs(from.zombies or {}) do
        if zb.source ~= "told" then
            local dx, dy = zb.x - aroundX, zb.y - aroundY
            if dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH then
                local existing = to.zombies[key]
                if not existing or existing.source == "told" then
                    to.zombies[key] = { x = zb.x, y = zb.y,
                        dist = zb.dist, at = zb.at,
                        source = "told", teller = fromId,
                        form = zb.form,
                        formPerformance = zb.formPerformance,
                        attributeMutations = zb.attributeMutations }
                    moved = moved + 1
                    if zb.form and zb.form ~= "none" then
                        pcall(function()
                            local day = math.floor(
                                (SAO.History.countyHours() or 0) / 24.0)
                            SAO.Adaptation.observe(
                                toId,
                                zb.form,
                                zb.formPerformance,
                                "told",
                                day)
                        end)
                    end
                end
            end
        end
    end
    for gname, fb in pairs(from.factions or {}) do
        local fdx = (fb.baseX or 0) - aroundX
        local fdy = (fb.baseY or 0) - aroundY
        if fdx * fdx + fdy * fdy <= P.GROUND_REACH * P.GROUND_REACH and not to.factions[gname] then
            to.factions[gname] = { baseX = fb.baseX, baseY = fb.baseY,
                minX = fb.minX, minY = fb.minY,
                maxX = fb.maxX, maxY = fb.maxY, at = fb.at,
                source = "told", teller = fromId, name = fb.name,
                stance = fb.stance }
            moved = moved + 1
        end
    end
    P.appraiseKnownTransfers(toId)
    return moved
end

-- The cry ([B20]): a badly hurt person calls out, and the people who
-- know that voice learn it was a PERSON rather than a noise.
--
-- The shout itself is the engine's own (`Callout()`, what a player
-- does on Q) and is made by the caller - so the sound is real, the
-- radius is real, and it draws the dead exactly as a player's shout
-- does. This function is the other half: the meaning, carried to
-- whoever can make it out.
--
-- Without it a cry would be actively harmful. An anonymous world
-- sound lands on the `S:` path, which writes a ZOMBIE belief at the
-- sound's tile - so calling for help would send your own house
-- running from you.
function P.cryForHelp(fromId, tick)
    local fromRec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(fromId) or nil
    -- [C71] The key this store holds them under, not the name a
    -- player would be shown.
    local fromName = fromRec and SAO.Identity.beliefKey(fromRec) or nil
    if not fromName then return 0 end
    local fromBody = SAO.Body and SAO.Body.get and SAO.Body.get(fromId)
    if not fromBody then return 0 end
    local fx, fy = fromBody:getX(), fromBody:getY()
    local g = SAO.Standing.groupOf and SAO.Standing.groupOf(fromId) or nil
    -- The scanner's own mask, not a second copy of it.
    local mask = 1.0
    pcall(function()
        mask = SAOJavaBridge:weatherHearing()
    end)
    mask = tonumber(mask) or 1.0
    -- A voice carries further than sight and not forever. The 20 is a
    -- judgment on a real scale; the MASKING is read.
    local reach = 20.0 * mask
    local tileKey = math.floor(fx) .. "," .. math.floor(fy)
    -- [B20] WHO heard, not just how many. A cry that goes unanswered
    -- has to know whose silence it was.
    local heardBy = {}
    for otherId, ob in pairs(P.beliefs) do
        if otherId ~= fromId and ob then
            local obody = SAO.Body.get(otherId)
            if obody then
                local dx, dy = obody:getX() - fx, obody:getY() - fy
                local d2 = dx * dx + dy * dy
                if d2 <= reach * reach then
                    -- You know that voice - and recognising it is
                    -- FAMILIARITY, not affection. This first read
                    -- `trust > 0.3`, which had it backwards: someone
                    -- who hates you knows your voice better than a
                    -- stranger who mildly approves of you, and would
                    -- have heard only an anonymous noise.
                    --
                    -- What they DO with it is a separate question the
                    -- tree already answers: the aid loop excludes
                    -- hostiles, and a hostile who now knows a hated
                    -- neighbour is hurt and nearby is handled by the
                    -- hostility machinery that already exists. Nobody
                    -- had to write "raiders hunt the wounded" - the
                    -- cry simply tells your enemies where you are and
                    -- that you are bleeding, which is the second
                    -- honest cost of screaming.
                    local knows = (g and SAO.Standing.groupOf(otherId) == g)
                        or SAO.Standing.knowsOf(otherId, fromId)
                    if knows then
                        local existing = ob.people[fromName]
                        if existing and existing.source == "observed" then
                            -- The ladder holds: heard never overwrites
                            -- observed. But hearing someone scream IS
                            -- current news about them, so the urgency
                            -- refreshes even though the provenance
                            -- does not fall.
                            existing.at = tick
                            existing.condition = "bad"
                        else
                            ob.people[fromName] = {
                                x = fx, y = fy, dist = math.sqrt(d2),
                                at = tick, source = "heard",
                                condition = "bad",
                            }
                        end
                        -- ...so it is not a monster to you. Marked so
                        -- the NEXT scan's S row does not undo this by
                        -- writing a threat on the tile they are lying
                        -- on.
                        ob.criedTiles = ob.criedTiles or {}
                        ob.criedTiles[tileKey] = tick
                        ob.zombies[tileKey] = nil
                        heardBy[#heardBy + 1] = otherId
                    end
                end
            end
        end
    end
    -- [B20] The reach goes back with the hearers: the PLAYER is told
    -- by the Controller (where [B18] put that idiom), and it must use
    -- the same weather-masked distance a survivor standing there
    -- would have. A third distance constant is how the mask drifts.
    return heardBy, reach
end

function P.announceDeparture(fromId, kind, destX, destY)
    local fromRec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(fromId) or nil
    -- [C71] The belief key, as above.
    local fromName = fromRec and SAO.Identity.beliefKey(fromRec) or nil
    if not fromName then return end
    local fromBody = SAO.Body and SAO.Body.get and SAO.Body.get(fromId)
    if not fromBody then return end
    local fx, fy = fromBody:getX(), fromBody:getY()
    local g = SAO.Standing.groupOf and SAO.Standing.groupOf(fromId) or nil
    if not g then return end
    local okH, nowH = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return end
    -- Announced terms ([B1]): the goer knows how long their own
    -- errands take - the house's learned expectation is THEIR
    -- estimate too, so the word carries a back-by time when history
    -- exists. Far scout runs sometimes carry "don't wait up"
    -- (noClock): no worry clock at all, and the hearer knows it.
    local backBy = nil
    local noClock = nil
    do
        local expected = SAO.Standing.ventureExpectation
            and SAO.Standing.ventureExpectation(g, kind) or nil
        if expected then
            backBy = nowH + expected * 1.5
        end
        if kind == "scout" and destX then
            local ddx, ddy = destX - fx, destY - fy
            if ddx * ddx + ddy * ddy > 40000
                and SAO.Rand.int(4) == 0 then
                noClock = true
                backBy = nil
            end
        end
    end
    local goerB = P.beliefs[fromId]
    -- [B19] The hearers are the point, not a by-product: this loop
    -- already finds every housemate in earshot and the caller had no
    -- way to know who they were, so nobody could ever decide to come
    -- along. Collected and returned; the JOINING is the Controller's
    -- to decide, because who does what is not Perception's pillar.
    local hearers = {}
    local bestBriefer, bestKnown = nil, 0
    for otherId, og in pairs(P.beliefs) do
        if otherId ~= fromId
            and SAO.Standing.groupOf(otherId) == g then
            local ob = SAO.Body.get(otherId)
            if ob then
                local dx, dy = ob:getX() - fx, ob:getY() - fy
                if dx * dx + dy * dy <= P.EARSHOT * P.EARSHOT then
                    hearers[#hearers + 1] = otherId
                    local b2 = P.beliefs[otherId]
                    local pb2 = b2.people[fromName]
                    if pb2 then
                        pb2.out = { kind = kind, x = destX, y = destY,
                            saidAtHours = nowH, backByHours = backBy,
                            noClock = noClock }
                    end
                    -- The briefing ([B1]): who among the hearers
                    -- knows the named ground best - counted as their
                    -- firsthand beliefs within 40 tiles of it.
                    if destX and goerB then
                        local known = 0
                        for _, zb in pairs(b2.zombies or {}) do
                            if zb.source ~= "told" then
                                local zdx, zdy = zb.x - destX, zb.y - destY
                                if zdx * zdx + zdy * zdy <= P.GROUND_REACH * P.GROUND_REACH then
                                    known = known + 1
                                end
                            end
                        end
                        for _, fb in pairs(b2.factions or {}) do
                            local fdx = (fb.baseX or 0) - destX
                            local fdy = (fb.baseY or 0) - destY
                            if fdx * fdx + fdy * fdy <= P.GROUND_REACH * P.GROUND_REACH then
                                known = known + 2
                            end
                        end
                        if known > bestKnown then
                            bestBriefer, bestKnown = otherId, known
                        end
                    end
                end
            end
        end
    end
    -- The knower dictates what is where ([B1]): their near-ground
    -- beliefs transfer told-provenance, the same idiom as every tell.
    -- Nobody knowing anything is also true - no briefing happens.
    if bestBriefer and goerB then
        local bB = P.beliefs[bestBriefer]
        local moved = 0
        for key, zb in pairs(bB.zombies or {}) do
            if zb.source ~= "told" then
                local zdx, zdy = zb.x - destX, zb.y - destY
                if zdx * zdx + zdy * zdy <= P.GROUND_REACH * P.GROUND_REACH then
                    local ex = goerB.zombies[key]
                    if not ex or ex.source == "told" then
                        goerB.zombies[key] = { x = zb.x, y = zb.y,
                            dist = zb.dist, at = zb.at,
                            source = "told", teller = bestBriefer }
                        moved = moved + 1
                    end
                end
            end
        end
        for gname, fb in pairs(bB.factions or {}) do
            local fdx = (fb.baseX or 0) - destX
            local fdy = (fb.baseY or 0) - destY
            if fdx * fdx + fdy * fdy <= P.GROUND_REACH * P.GROUND_REACH
                and not goerB.factions[gname] then
                goerB.factions[gname] = { baseX = fb.baseX,
                    baseY = fb.baseY, minX = fb.minX, minY = fb.minY,
                    maxX = fb.maxX, maxY = fb.maxY, at = fb.at,
                    source = "told", name = fb.name,
                    stance = fb.stance }
                moved = moved + 1
            end
        end
        if moved > 0 then
            pcall(function()
                SAO.Voice.onEvent(bestBriefer, "briefing")
            end)
        end
    end
    return hearers
end


-- A believed faction base within `near` tiles of (x,y), or nil.
function P.believedFactionNear(id, x, y, near)
    local b = P.beliefs[id]
    if not b or not b.factions then return nil end
    for groupName, fb in pairs(b.factions) do
        if x >= fb.minX - (near or 0) and x <= fb.maxX + (near or 0)
            and y >= fb.minY - (near or 0) and y <= fb.maxY + (near or 0) then
            return groupName, fb
        end
    end
    return nil
end

function P.setFactionStance(id, groupName, stance)
    local b = P.beliefs[id]
    if b and b.factions and b.factions[groupName] then
        b.factions[groupName].stance = stance
    end
end

function P.factionStanceToward(id, personName)
    local b = P.beliefs[id]
    if not b then return nil end
    local pb = b.people[personName]
    local g = pb and pb.seenInFaction or nil
    if g and b.factions[g] then
        return b.factions[g].stance, g
    end
    return nil
end

-- The objection teaches ([A15]): being told off at the door is
-- firsthand knowledge of whose place this is.
-- [B39] How a place came to be known, said by the CALLER.
--
-- This wrote `source = "observed"` unconditionally, so no caller could
-- state how the knowledge arrived - and two of them had already
-- written the truth in a comment above the call. `SAO_Controller:5112`
-- says "Told, not seen: they know it because somebody standing there
-- said so" and then recorded that it was seen. The manner of
-- acquisition was stated in prose and lost in the data, which is the
-- root of the defect class [B35], [B35] and [B37] each fixed one
-- instance of.
--
-- Omission records "unknown" rather than claiming observation,
-- because a silent default claiming the strongest provenance is
-- exactly how this happened. Border 28 fails on "unknown", so a new
-- caller that forgets is caught rather than believed.
function P.learnPlace(id, ownerKey, bounds, source)
    local b = store(id)
    b.places[ownerKey] = {
        minX = bounds.minX, minY = bounds.minY,
        maxX = bounds.maxX, maxY = bounds.maxY,
        at = b.lastScanAt, source = tostring(source or "unknown"),
    }
    P.appraiseKnownTransfers(id)
end

-- [B42] Being near somebody's ground teaches you it is theirs, and a
-- claim that ended un-teaches the same way ([A15], [A15], [B35]).
--
-- This rule lived only inside `dormantLife`, which gates its whole
-- loop on `not SAO.Body.get(id)`. So an UNLOADED survivor drifting
-- past a fence learned whose house it was, and a survivor with a body
-- could stand in the kitchen indefinitely and never learn it. [B35]
-- wired the player's claim into this - the `isPlayerKey` branch below
-- exists for exactly that - and put it in the half that can never see
-- a survivor who is actually standing there, which is why the ledger
-- reports "Nobody has come past it yet" with somebody in the room.
--
-- The county's property law does not depend on whether a cell happens
-- to be loaded. Same rule, both halves, one spelling: [B39] and
-- [B39] are the same finding about `Desperation` and `ErrandRadius`.
function P.learnGroundNear(id, x, y)
    if not (x and y and SAO.Standing) then return end
    local sight = P.PLACE_SIGHT or 8
    local function near(c)
        return x >= c.minX - sight and x <= c.maxX + sight
            and y >= c.minY - sight and y <= c.maxY + sight
    end

    if SAO.Standing.allGroupClaims then
        for gname, c in pairs(SAO.Standing.allGroupClaims()) do
            if near(c) then
                local b = P.beliefs[id]
                if not (b and b.factions and b.factions[gname]) then
                    P.learnPlace(id, gname, c, "observed")
                end
            end
        end
    end

    -- [B35] Walking past also UNTEACHES. A claim that ended leaves
    -- the ground free, and you find that out the same way you found
    -- out it was held - by being there.
    local bU = P.beliefs[id]
    if bU and bU.places then
        for ownerKey, pc in pairs(bU.places) do
            if near(pc) and not SAO.Standing.claimOf(ownerKey) then
                bU.places[ownerKey] = nil
            end
        end
    end

    if SAO.Standing.allPersonalClaims then
        for ownerId, c in pairs(SAO.Standing.allPersonalClaims()) do
            if ownerId ~= id and near(c) then
                -- [B35] The player holds ground under a player: key
                -- and has no Identity record, so a guard written to
                -- skip the DEAD skips the player unless it says so.
                local orec = SAO.Identity and SAO.Identity.get(ownerId)
                if SAO.Standing.isPlayerKey(ownerId)
                    or (orec and not orec.dead) then
                    P.learnPlace(id, ownerId, c, "observed")
                end
            end
        end
    end
end

-- Does this survivor BELIEVE (x,y) is somebody's place? Returns the
-- owner key (personal) or group name (faction base), else nil.
function P.believesClaimed(id, x, y)
    local b = P.beliefs[id]
    if not b then return nil end
    for ownerKey, pc in pairs(b.places or {}) do
        if x >= pc.minX and x <= pc.maxX
            and y >= pc.minY and y <= pc.maxY then
            -- F-034: the estate rule reaches beliefs - the dead hold
            -- nothing (same authority claimedByOther already applies;
            -- record death is corpse-visible truth, not a rumor).
            local orec = SAO.Identity and SAO.Identity.get
                and SAO.Identity.get(ownerKey) or nil
            if not (orec and orec.dead) then
                return ownerKey
            end
        end
    end
    for groupName, fb in pairs(b.factions or {}) do
        if x >= fb.minX and x <= fb.maxX
            and y >= fb.minY and y <= fb.maxY then
            return groupName
        end
    end
    return nil
end

-- [B37] A place known as a PLACE, not as somebody's ground.
--
-- `b.places` above answers "whose is this?" and is keyed by owner. It
-- cannot represent the thing the operator named as the only thing a
-- survivor can know off the road - "that this is a house that has
-- things in it". Until now the belief store had no way to say it, so
-- the dormant day had nowhere to go and walked to a random
-- coordinate instead.
--
-- Keyed by building id, because a building is the same building
-- whoever is standing in it. `sources` is the exact native stock this
-- person observed on arrival; room vocabulary remains only a possible
-- reason to explore and never enters the belief as availability.
function P.learnBuilding(id, place, tick, source)
    if not place or not place.id then return end
    local b = store(id)
    b.known = b.known or {}
    local was = b.known[place.id]
    local sources, sourceRevision, sourceAccess, sourceFacts = {}, "", {}, {}
    pcall(function()
        sources, sourceRevision, sourceAccess, sourceFacts =
            SAO.WorldSources.beliefSnapshot(place)
    end)
    b.known[place.id] = {
        cx = place.cx, cy = place.cy,
        minX = place.minX, minY = place.minY,
        maxX = place.maxX, maxY = place.maxY,
        sources = sources,
        sourceAccess = sourceAccess,
        sourceRevision = sourceRevision,
        sourceFacts = sourceFacts,
        at = tick or b.lastScanAt,
        -- [B39] Said by the caller; "unknown" when nobody said.
        source = tostring(source or "unknown"),
        -- How many times they have been. Somewhere returned to is
        -- somewhere that gave them something.
        visits = (was and was.visits or 0) + 1,
    }
    -- [C108] An arrival is a write; derived readers recompute.
    P.beliefVersion = P.beliefVersion + 1
end

local function rebuildKnownSources(belief)
    local sources, access, revisions = {}, {}, {}
    for id, fact in pairs(belief.sourceFacts or {}) do
        if fact.state == "available" then
            for category, quantity in pairs(fact.quantities or {}) do
                if (tonumber(quantity) or 0) > 0 then
                    sources[category] = true
                    if fact.access == "accessible" then access[category] = true end
                end
            end
        end
        local entry = tostring(id) .. "@" .. tostring(fact.revision)
        local at = #revisions + 1
        while at > 1 and revisions[at - 1] > entry do
            revisions[at] = revisions[at - 1]
            at = at - 1
        end
        revisions[at] = entry
    end
    belief.sources = sources
    belief.sourceAccess = access
    belief.sourceRevision = table.concat(revisions, ",")
end

-- Refresh only the source this actor physically handled. Whole-building
-- learning here would reveal unrelated changes made outside their observation.
function P.learnSource(id, place, sourceId, tick, source)
    if not place or place.id == nil or not sourceId then return false end
    local b = store(id)
    b.known = b.known or {}
    local belief = b.known[place.id] or b.known[tostring(place.id)]
    if not belief then return false end
    belief.sourceFacts = belief.sourceFacts or {}
    belief.sourceFacts[tostring(sourceId)] = nil
    local fact = nil
    pcall(function() fact = SAO.WorldSources.beliefFact(sourceId) end)
    local belongs = fact and (fact.buildingId == tostring(place.id)
        or (fact.kind == "vehicle" and place.minX and place.minY
            and place.maxX and place.maxY
            and fact.x >= place.minX and fact.x < place.maxX
            and fact.y >= place.minY and fact.y < place.maxY))
    if belongs then belief.sourceFacts[tostring(sourceId)] = fact end
    rebuildKnownSources(belief)
    belief.at = tick or b.lastScanAt
    belief.source = tostring(source or "observed-source")
    P.beliefVersion = P.beliefVersion + 1
    return true
end

-- A current, reachable container inspection admits precisely one source.
-- The caller has verified the native inspection; other sources in the same
-- engine chunk never become this person's knowledge through this operation.
function P.learnInspectedSource(id, place, sourceId, tick, provenance)
    if not place or place.id == nil or not sourceId then return false end
    local fact = SAO.WorldSources and SAO.WorldSources.beliefFact(sourceId)
    if not fact then return false end
    local belongs = tostring(fact.buildingId) == tostring(place.id)
        or tostring(place.sourceId or "") == tostring(sourceId)
        or (fact.kind == "vehicle" and place.minX and place.minY
            and place.maxX and place.maxY and fact.x >= place.minX
            and fact.x < place.maxX and fact.y >= place.minY
            and fact.y < place.maxY)
    if not belongs then return false end
    local b = store(tostring(id))
    b.known = b.known or {}
    local key = b.known[place.id] and place.id or tostring(place.id)
    local belief = b.known[place.id] or b.known[key] or { id = place.id }
    belief.cx, belief.cy, belief.z = place.cx, place.cy, place.z
    belief.minX, belief.minY = place.minX, place.minY
    belief.maxX, belief.maxY = place.maxX, place.maxY
    belief.sourceId = place.sourceId
    belief.sourceFacts = belief.sourceFacts or {}
    belief.sourceFacts[tostring(sourceId)] = fact
    rebuildKnownSources(belief)
    belief.at = tick or b.lastScanAt
    belief.source = tostring(provenance or "inspected-source")
    b.known[key] = belief
    P.beliefVersion = P.beliefVersion + 1
    return true
end

function P.forgetSource(id, placeId, sourceId, tick, source)
    local b = store(id)
    local belief = b.known and (b.known[placeId]
        or b.known[tostring(placeId)]) or nil
    if not belief then return false end
    belief.sourceFacts = belief.sourceFacts or {}
    belief.sourceFacts[tostring(sourceId)] = nil
    rebuildKnownSources(belief)
    belief.at = tick or b.lastScanAt
    belief.source = tostring(source or "source-disproved")
    P.beliefVersion = P.beliefVersion + 1
    return true
end

-- Everything this survivor knows is out there. Empty for someone who
-- has not been anywhere, which is the correct answer for them.
function P.knownPlaces(id, includeSourceAnchors)
    local b = P.beliefs[id]
    local known = (b and b.known) or {}
    if includeSourceAnchors then return known end
    -- Physical source anchors carry remembered goods, not building visits.
    local places = {}
    for key, belief in pairs(known) do
        if not belief.sourceId then places[key] = belief end
    end
    return places
end

-- Have they been here, and how long ago in ticks? nil when the place
-- is not one they know.
function P.placeAge(id, placeId, tick)
    local b = P.beliefs[id]
    local k = b and b.known and b.known[placeId]
    if not k then return nil end
    return (tick or 0) - (k.at or 0)
end

function P.forget(id)
    P.beliefs[id] = nil
    -- [C108] A dropped mind is a write; derived readers recompute.
    P.beliefVersion = P.beliefVersion + 1
end

-- [C108] A company's places, ranked - the generalised [C76] scorer.
--
-- [C76] picked ONE building for a settling house: the places its
-- members actually reach, visits summed across them times the
-- distinct members who reach them, water doubled. That same walk
-- answers a bigger question the operator named as a real error
-- rather than a missing feature (DR-006 S4): a group's ground is not
-- one rectangle under one name. So the same facts - every arrival
-- `learnBuilding` has recorded since [B37], the same score, the same
-- water doubling - are ranked here instead of picked from, and the
-- settling pass reads the top of the ranking, which keeps the seat
-- and the set from becoming two laws ([C25]).
--
-- Recency breaks ties: `lastAt` is when the last of them was last
-- there, so of two places equally returned to, the one somebody
-- still goes to ranks above the one they have stopped going to. A
-- place stops being the group's when its people stop going, and it
-- stops the same way it started - through the walking. Nothing is
-- stored, so nothing expires.
--
-- Living members only - callers pass `membersOf`, which already
-- refuses the dead - so the estate rule (F-034) holds on the derived
-- side too: the dead keep no ground.
--
-- Returns a list sorted best-first, each entry
--   { id = building id, place = the known record, visits, who,
--     lastAt, score }
-- Recomputed when asked; group-shaped readers cache against
-- `P.beliefVersion` so they do not pay this walk per call ([C77]).
function P.returnsOf(members)
    if not members then return {} end
    local returns = {}
    for _, mid in ipairs(members) do
        local b = P.beliefs[mid]
        if b and b.known then
            for pid, kp in pairs(b.known) do
                if not kp.sourceId and kp.minX and kp.cx then
                    local t = returns[pid]
                    if not t then
                        t = { id = pid, place = kp, visits = 0,
                              who = 0, lastAt = kp.at or 0 }
                        returns[pid] = t
                    end
                    t.visits = t.visits + (kp.visits or 1)
                    t.who = t.who + 1
                    if (kp.at or 0) > t.lastAt then
                        t.lastAt = kp.at
                    end
                end
            end
        end
    end
    local ranked = {}
    for _, t in pairs(returns) do
        local kp = t.place
        -- [C76]'s own score, unchanged: returned to, by more than
        -- one of them, worth returning to. Water is the only source
        -- weighed, because it is the need that kills first ([B37])
        -- and the one a base either has or does not.
        t.score = t.visits * t.who
        if kp.sources and kp.sources.water then
            t.score = t.score * 2
        end
        ranked[#ranked + 1] = t
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.lastAt > b.lastAt
    end)
    return ranked
end

-- ---------------------------------------------------------------------------
-- [C15] Whole minds survive the reload (DR-020)

-- [C112] The rebase that lived here is GONE, and its reason with it:
-- it zeroed every tick-stamped field on bind because "the tick axis
-- cannot cross sessions - a frame count from a dead session is
-- meaningless in a live one." The tick is the county's clock now
-- (`SAO.History.ticks`, world-age quantized), so the axis crosses
-- sessions as of course as the atHours stamps always did: a belief
-- saved yesterday reads as yesterday, with no grace period and no
-- reset. Zeroing fresh stamps on every reload would now be the bug
-- the rebase cured - it would age a two-minute-old belief to the
-- beginning of the world on every load.
--
-- What a save from an older build carries instead is FRAME-domain
-- stamps, and they cut both ways. Most sit below the county's ticks
-- and read as ANCIENT - stale, pruned by their horizon, rescan: the
-- safe direction. But a long pre-[C112] session's frame count can sit
-- ABOVE a young county's ticks, and an `at` ahead of now reads as
-- ultra-fresh forever (every freshness test passes a negative age) -
-- the exact defect the old rebase existed to prevent. In the county
-- domain a stamp can never be ahead of now (stamps are made at now,
-- and the clock never runs backwards), so ahead-of-now is a domain
-- mark, not a value: the check below drops every such stamp to 0,
-- which reads as long ago. One reload's relearn per old save, both
-- directions safe, then never again. The durable truths are as they
-- were - dead-flagged people never decay (F-033), places prune by
-- proximity not time, and the world-hours stamps (atHours and the
-- out-terms) still carry a belief's REAL age for every reader that
-- needs it.
--
-- The scan self-throttle is the same law right side up: a stamp of 0
-- (or a defaulted one) reads as long ago, so "do it now" is the
-- default, never "never".
local function dropForeignStamps(b, now)
    if type(b) ~= "table" then return end
    for key, value in pairs(b) do
        if type(value) == "number" and type(key) == "string"
            and key:sub(-2) == "At" and not key:find("Hours")
            and value > now then
            b[key] = 0
        end
    end
    for _, tableName in ipairs({ "zombies", "people", "factions" }) do
        local entries = b[tableName]
        if type(entries) == "table" then
            for _, entry in pairs(entries) do
                if type(entry) == "table"
                    and type(entry.at) == "number"
                    and entry.at > now then
                    entry.at = 0
                end
            end
        end
    end
    if type(b.criedTiles) == "table" then
        for key, value in pairs(b.criedTiles) do
            if type(value) == "number" and value > now then
                b.criedTiles[key] = 0
            end
        end
    end
    -- The owned-ground map and the known-buildings map both carry a
    -- tick-domain `at` on every entry (keyed by owner or building id,
    -- which is why the generic "At"-suffix walk above cannot reach
    -- them), and `placeAge` subtracts them from now exactly as the
    -- sighting stamps are subtracted - so a foreign ahead-of-now one
    -- reads as just-visited by the same arithmetic.
    for _, tableName in ipairs({ "places", "known" }) do
        local entries = b[tableName]
        if type(entries) == "table" then
            for _, entry in pairs(entries) do
                if type(entry) == "table"
                    and type(entry.at) == "number"
                    and entry.at > now then
                    entry.at = 0
                end
            end
        end
    end
end

function P.bindPersistentStore()
    local ok, persisted = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Beliefs")
    end)
    if not ok or type(persisted) ~= "table" then
        -- Stated, not silent: without the store, minds are
        -- session-scoped this run, exactly the pre-[C15] behavior.
        log("belief store unavailable (" .. tostring(persisted)
            .. "); minds are session-scoped this run")
        return false
    end
    if persisted == P.beliefs then
        return true   -- already bound; a second start must not rebind
    end
    -- [C112] The domain check's now. Read through a pcall: a bind
    -- that happens before the bridge is up understates the county's
    -- hours by the days it owes, which can zero a legitimate stamp -
    -- and zeroing reads as ancient, the safe direction, so an early
    -- bind costs freshness, never correctness.
    local now = 0
    pcall(function() now = SAO.History.ticks() end)
    local restored = 0
    for _, b in pairs(persisted) do
        if type(b) == "table" then
            dropForeignStamps(b, now)
            restored = restored + 1
        end
    end
    for id, b in pairs(P.beliefs) do
        persisted[id] = b   -- pre-bind session entries carry over
    end
    P.beliefs = persisted
    -- [C108] The store was swapped; derived readers recompute.
    P.beliefVersion = P.beliefVersion + 1
    log(restored .. " mind(s) restored from the save (DR-020)")
    return true
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        pcall(P.bindPersistentStore)
    end)
end

return P
