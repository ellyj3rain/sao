-- SAO_Standing — the Standing pillar (ARCHITECTURE §Standing).
-- ---------------------------------------------------------------------------
-- What is ALLOWED. Relationships, group membership, territory claims,
-- hostility state; channels a preference into a permitted action. Owns
-- whether this survivor may engage that person, enter that claim, take from
-- that place. Never invents knowledge (subjects must be believed-known via
-- Perception) and never executes.
--
-- Persisted in the identity store alongside records: standing is part of who
-- a person is, not runtime decoration.

SAO = SAO or {}

-- [B16] This file logs four times ([B2]'s skill deal, [B13]'s step-up,
-- [B8]'s walk-out, [B7]'s council) and never declared `log` - every
-- one of those calls would have thrown at the moment it mattered
-- most, inside an election. Found by the undeclared-identifier audit
-- on its first honest run; the same prefix idiom every other file
-- uses.
-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("STANDING", msg) end
SAO.Standing = SAO.Standing or {}
local S = SAO.Standing


-- [B40] How far enemy ground reaches, and why the two numbers differ.
--
-- Both were spelled bare, in different files, at different values,
-- eight literals between them - the same question asked twice with no
-- name and no stated relationship.
--
-- A HOME is permanent and a day is not, so the buffer you keep when
-- choosing where to live is wider than the one you keep when choosing
-- where to walk. That is the whole of the difference and it is a
-- choice, so it is written down rather than left in two files to be
-- discovered.
S.FEUD_KEEP_OUT = 30   -- will not settle this close to a feuding company
S.FEUD_DETOUR = 20     -- a day's walk bends away at this range
local STANDING_SCHEMA = 4
-- Evidence reads may not initialize or migrate standing as a side effect.
function S.knowledgeEvidenceReady(id)
    local s = ModData.get("SurvivorAwareness_Standing")
    if type(s) ~= "table" or s.schema ~= STANDING_SCHEMA then return false end
    for _, key in ipairs({ "relations", "groups", "claims", "groupMeta",
        "groupClaims", "migrations" }) do
        if type(s[key]) ~= "table" then return false end
    end
    if type(s.relations[id]) ~= "table" then return false end
    return true
end

local C63_STANDING_PROVENANCE =
    "initialized at C63 upgrade from represented C62 state; no earlier history inferred"

local function migrateLegacyMaterialClaims(s, priorSchema)
    local retiredLarders, retiredWaterStores, retiredHearths = 0, 0, 0
    for _, meta in pairs(s.groupMeta) do
        if type(meta) == "table" then
            if meta.larder ~= nil then retiredLarders = retiredLarders + 1 end
            if meta.waterStore ~= nil then
                retiredWaterStores = retiredWaterStores + 1
            end
            if meta.hearth ~= nil then retiredHearths = retiredHearths + 1 end
            meta.larder = nil
            meta.waterStore = nil
            meta.hearth = nil
        end
    end
    local migratedGroupClaims = 0
    local claimSequence = math.floor(tonumber(s.claimSequence) or 0)
    for _, claim in pairs(s.groupClaims) do
        local incarnation = type(claim) == "table"
            and math.floor(tonumber(claim.claimIncarnation) or 0) or 0
        if incarnation > claimSequence then claimSequence = incarnation end
    end
    for _, claim in pairs(s.groupClaims) do
        if type(claim) == "table"
            and (tonumber(claim.claimIncarnation) or 0) <= 0 then
            claimSequence = claimSequence + 1
            claim.claimIncarnation = claimSequence
            migratedGroupClaims = migratedGroupClaims + 1
        end
    end
    s.claimSequence = claimSequence
    s.migrations.c63LegacyMaterialClaims = {
        fromSchema = priorSchema,
        toSchema = 2,
        provenance = C63_STANDING_PROVENANCE,
        retiredLarders = retiredLarders,
        retiredWaterStores = retiredWaterStores,
        retiredHearths = retiredHearths,
        migratedGroupClaims = migratedGroupClaims,
    }
end

local function migratePartialMaterialClaims(s, priorSchema)
    local retiredLarders, retiredWaterStores = 0, 0
    for _, meta in pairs(s.groupMeta) do
        if type(meta) == "table" then
            if type(meta.larder) == "table"
                and meta.larder.basis == "completed-native-source-results" then
                meta.larder = nil
                retiredLarders = retiredLarders + 1
            end
            if type(meta.waterStore) == "table"
                and meta.waterStore.basis
                    == "completed-native-source-results" then
                meta.waterStore = nil
                retiredWaterStores = retiredWaterStores + 1
            end
        end
    end
    s.migrations.c64PartialMaterialCorrection = {
        fromSchema = priorSchema,
        toSchema = STANDING_SCHEMA,
        provenance = "C64 retires house-wide claims derived from selected source results",
        retiredPartialLarders = retiredLarders,
        retiredPartialWaterStores = retiredWaterStores,
    }
end

local function migrateInferredMaterialClaims(s, priorSchema)
    local retiredLarders, retiredWaterStores = 0, 0
    for _, meta in pairs(s.groupMeta) do
        if type(meta) == "table" then
            if type(meta.larder) == "table"
                and meta.larder.basis ~= "completed-native-source-results" then
                meta.larder = nil
                retiredLarders = retiredLarders + 1
            end
            if type(meta.waterStore) == "table"
                and meta.waterStore.basis
                    ~= "completed-native-source-results" then
                meta.waterStore = nil
                retiredWaterStores = retiredWaterStores + 1
            end
        end
    end
    s.migrations.c71InferredMaterialCorrection = {
        fromSchema = priorSchema,
        toSchema = STANDING_SCHEMA,
        provenance = "C71 retires house totals inferred from bounded private inventory",
        retiredInferredLarders = retiredLarders,
        retiredInferredWaterStores = retiredWaterStores,
    }
end

local function store()
    local ok, s = pcall(function() return ModData.getOrCreate("SurvivorAwareness_Standing") end)
    if not ok or type(s) ~= "table" then return nil end
    local priorSchema = tonumber(s.schema) or 0
    if priorSchema > STANDING_SCHEMA then return nil end
    s.relations = type(s.relations) == "table" and s.relations or {}
    s.groups = type(s.groups) == "table" and s.groups or {}
    s.claims = type(s.claims) == "table" and s.claims or {}
    s.groupMeta = type(s.groupMeta) == "table" and s.groupMeta or {}
    s.groupClaims = type(s.groupClaims) == "table" and s.groupClaims or {}
    s.migrations = type(s.migrations) == "table" and s.migrations or {}
    if priorSchema < 2 then
        migrateLegacyMaterialClaims(s, priorSchema)
    end
    if priorSchema < 3 then
        migratePartialMaterialClaims(s, priorSchema)
    end
    if priorSchema < 4 then
        migrateInferredMaterialClaims(s, priorSchema)
    end
    if priorSchema < STANDING_SCHEMA then
        s.schema = STANDING_SCHEMA
    end
    return s
end

local function materialEnabled()
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return not options or options.Material ~= false
end

local function materialWriteAllowed(evidence)
    return materialEnabled() or (type(evidence) == "table"
        and evidence.materialProjectionEnabled == true)
end

local function completeMaterialClaimAllowed(basis, evidence)
    return materialWriteAllowed(evidence)
        and tostring(basis or "") == "completed-native-source-results"
        and type(evidence) == "table"
        and evidence.completeCoverage == true
        and evidence.reservationId ~= nil
        and evidence.sourceId ~= nil
        and tonumber(evidence.materialGeneration) ~= nil
end

local function materialEvidence(evidence)
    local atHours = type(evidence) == "table"
        and tonumber(evidence.atHours or evidence.at) or nil
    if atHours == nil then
        local ok, current = pcall(function()
            return SAO.History.countyHours()
        end)
        atHours = ok and tonumber(current) or 0
    end
    return atHours,
        type(evidence) == "table" and tonumber(evidence.order) or nil,
        type(evidence) == "table" and evidence.reservationId or nil,
        type(evidence) == "table" and evidence.sourceId or nil,
        type(evidence) == "table"
            and tonumber(evidence.materialGeneration) or nil
end

local function materialEvidenceSuperseded(prior, basis, atHours, order,
    generation)
    if type(prior) ~= "table" then return false end
    local priorGeneration = tonumber(prior.materialGeneration)
    local projectionBasis = "completed-native-source-results"
    local bothProjection = prior.basis == projectionBasis
        and tostring(basis or "unspecified") == projectionBasis
    if bothProjection and priorGeneration and generation
        and priorGeneration ~= generation then
        return priorGeneration > generation
    end
    local priorAt = tonumber(prior.atHours)
    if priorAt and priorAt > atHours then return true end
    if priorAt and priorAt < atHours then return false end
    if priorGeneration and generation and priorGeneration ~= generation then
        return priorGeneration > generation
    end
    local priorOrder = tonumber(prior.resultOrder)
    return priorAt == atHours and priorOrder and order and priorOrder > order
end

-- Canonical person keys. Survivors are their RECORD ID; the real player is
-- "player:<username>". Perception speaks usernames; everything stored here
-- speaks these keys; the controller converts at the boundary.
function S.keyForObserved(name)
    local id = SAO.Identity and SAO.Identity.idByName(name) or nil
    if id then return id end
    -- Other people's people ([B10]): a marked label is another mod's
    -- NPC. They are real to our survivors - seen, feared, trusted -
    -- but they get their OWN key domain and can never be confused
    -- with the player or with one of ours.
    local marked = tostring(name):match("^~(.+)$")
    if marked then return "foreign:" .. marked end
    return "player:" .. tostring(name)
end

-- [B27] The player's key, in one place. Three key domains exist -
-- `sao-<n>` for ours, `foreign:<name>` for another mod's people, and
-- `player:<name>` - and the last was being spelled out by hand at
-- fifteen sites across five files. They all agree today; a single
-- constructor is how they go on agreeing.
function S.playerKey(playerObj)
    if not playerObj then return nil end
    local ok, name = pcall(function() return playerObj:getUsername() end)
    if not ok or not name then return nil end
    return "player:" .. tostring(name)
end

-- [B35] The other half of [B27]'s "one spelling". That batch put
-- the CONSTRUCTOR in one place and left the TEST spelled out by hand
-- wherever it was needed - and a hand-spelled domain test is the same
-- drift risk as a hand-spelled key, just quieter, because it fails by
-- not matching rather than by building something wrong.
function S.isPlayerKey(key)
    return key ~= nil and string.sub(tostring(key), 1, 7) == "player:"
end

function S.keyForAttackerTag(kind, name)
    if kind == "shell" then
        local id = SAO.Identity and SAO.Identity.idByName(name) or nil
        return id or ("shell:" .. tostring(name))
    end
    return "player:" .. tostring(name)
end

local function rel(s, id, otherKey, create)
    s.relations[id] = s.relations[id] or {}
    local r = s.relations[id][otherKey]
    if not r and create then
        r = { trust = 0.0, hostile = false }
        s.relations[id][otherKey] = r
    end
    return r
end

-- ---------------------------------------------------------------------------
-- Relations

function S.setHostile(id, otherKey, hostile)
    local s = store(); if not s then return false end
    rel(s, id, otherKey, true).hostile = hostile and true or false
    return true
end

function S.isHostileTo(id, otherKey)
    local s = store(); if not s then return false end
    local r = rel(s, id, otherKey, false)
    return r ~= nil and r.hostile == true
end

-- Every feeling has a DATE ([B8]): the stamp is what lets time
-- soften what nobody has refreshed. Cheap - one field per relation.
function S.adjustTrust(id, otherKey, delta)
    local s = store(); if not s then return 0 end
    local r = rel(s, id, otherKey, true)
    r.trust = math.max(-1.0, math.min(1.0, (r.trust or 0) + delta))
    local okTS, hTS = pcall(function()
        return SAO.History.countyHours()
    end)
    if okTS then r.atHours = hTS end
    return r.trust
end

function S.trust(id, otherKey)
    local s = store(); if not s then return 0 end
    local r = rel(s, id, otherKey, false)
    return r and r.trust or 0
end

-- The relation rows a person holds. Read-only; the isolation surface uses
-- it to count trusted contacts without walking the whole county.
function S.relationsOf(id)
    local s = store(); if not s then return {} end
    return s.relations[id] or {}
end

-- [B20] Familiarity, NOT affection. A relation row exists once two
-- people have had anything to do with each other, whatever its sign,
-- so this answers "do I know this person" without asking whether I
-- like them. Recognising someone's voice is not a favour - an enemy
-- knows it better than a stranger who mildly approves of you. Reads
-- through the same `rel` accessor as everything else and creates
-- nothing.
function S.knowsOf(id, otherKey)
    local s = store(); if not s then return false end
    return rel(s, id, otherKey, false) ~= nil
end

-- First-greeting bookkeeping: greeting happens once per relation, when
-- trust first clears the acquaintance line.
function S.wasGreeted(id, otherKey)
    local s = store(); if not s then return true end
    local r = rel(s, id, otherKey, false)
    return r ~= nil and r.greeted == true
end

function S.markGreeted(id, otherKey)
    local s = store(); if not s then return end
    rel(s, id, otherKey, true).greeted = true
end

-- Testimony: a survivor tells another who has wronged them. Hearing is not
-- seeing - testimony LOWERS the receiver's trust in the offender (scaled by
-- how much the receiver trusts the teller); hostility forms only when the
-- receiver's own trust in the offender collapses below -0.5. Told never
-- equals observed, in standing exactly as in perception. Returns how many
-- grudges moved the receiver.
function S.tellGrudges(fromId, toId)
    local s = store(); if not s then return 0 end
    local tellerCred = S.trust(toId, fromId)
    if tellerCred <= 0.3 and not S.sameGroup(fromId, toId) then return 0 end
    local moved = 0
    local mine = s.relations[fromId]
    if not mine then return 0 end
    for offender, r in pairs(mine) do
        if r.hostile == true and offender ~= toId
            and not S.isHostileTo(toId, offender) then
            -- One testimony per (hearer, offender, teller) - F-040:
            -- repeating yourself is not new evidence, and without this
            -- rule road-meeting retellings compounded one grudge into
            -- a collapse (equilibrium re-run, [A23]).
            local hr = rel(s, toId, offender, true)
            hr.testifiedBy = hr.testifiedBy or {}
            if not hr.testifiedBy[fromId] then
                hr.testifiedBy[fromId] = true
                local before = S.trust(toId, offender)
                local delta = -0.4 * math.max(0.3, tellerCred)
                local after = S.adjustTrust(toId, offender, delta)
                moved = moved + 1
                -- The testimony floor (F-040b, [A23] equilibrium law):
                -- words can make you WARY, never at WAR. Hearsay clamps
                -- just above the hostility line - it primes, so one
                -- thing SEEN or SUFFERED tips it - and it never deepens
                -- a distrust already earned by stronger provenance
                -- (floor = min(before, -0.45); testimony never raises
                -- either).
                local floor = math.min(before, -0.45)
                if after < floor then
                    local hr2 = rel(s, toId, offender, true)
                    hr2.trust = floor
                end
            end
        end
    end
    -- [C105] The tell happened; the record hears it. Only a tell
    -- that actually moved someone is a message worth carrying.
    if moved > 0 and SAO.Recognition then
        SAO.Recognition.onTold(fromId, toId, "grudge", { moved = moved })
    end
    return moved
end

-- Debts: what one person owes another, in items. Created only by a trade
-- that half-completed (gifts are gifts and never owe); settled at the
-- next meeting where the debtor has something to spare.
function S.addDebt(creditorId, debtorKey, amount)
    local s = store(); if not s then return end
    local r = rel(s, creditorId, debtorKey, true)
    r.owedToMe = (r.owedToMe or 0) + (amount or 1)
end

function S.debt(creditorId, debtorKey)
    local s = store(); if not s then return 0 end
    local r = rel(s, creditorId, debtorKey, false)
    return r and r.owedToMe or 0
end

function S.settleDebt(creditorId, debtorKey, amount)
    local s = store(); if not s then return end
    local r = rel(s, creditorId, debtorKey, false)
    if r and r.owedToMe then
        r.owedToMe = math.max(0, r.owedToMe - (amount or 1))
    end
end

-- Time softens ([B8]): once a world-day, feelings nobody has
-- refreshed in two weeks drift toward neutral, and a hostility whose
-- trust has faded back inside neutral LAPSES - forgiveness by
-- forgetting, which is how most human enmity actually ends. Bonds are
-- exempt: a bond is its own fact, not a trust reading. Returns how
-- many relations moved.
-- How many survivors' rows of feelings age in one pass. At thirty
-- entries a row this is about two milliseconds, against a pass every
-- 240 frames - so a county of ten thousand rows finishes its day in
-- under four minutes of real time, inside a game day of about an
-- hour.
local DRIFT_BUDGET = 200

function S.driftStandings()
    local s = store(); if not s then return 0 end
    local okH, nowH = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return 0 end
    local day = math.floor(nowH / 24)
    if s.lastDriftDay == day then return 0 end

    -- [B51] This used to walk the WHOLE relations table in one call.
    -- `s.relations` is `[id][otherKey]`, it is in the save, and its
    -- only removal is a rekey migration - so it holds a row for
    -- everybody who ever lived, quadratic in a county the dead never
    -- leave.
    --
    -- Measured on the engine, with the cost of building the table
    -- separated out: 5 ms at fifteen thousand entries, 59 at a
    -- hundred and sixty-five thousand, 231 at six hundred and thirty
    -- thousand. That last is a quarter-second freeze on one frame,
    -- once a game day, growing with the graveyard.
    --
    -- So the day's drift is spread across passes, the same answer
    -- [B51] gave the encounter sweep. The cursor is IN THE SAVE
    -- rather than a module local, so a reload mid-sweep resumes
    -- instead of restarting - restarting would age some feelings
    -- twice, which is small and would have been silent.
    local rows = 0
    local resumed = s.driftCursor == nil
    local moved = 0
    local last = nil
    for id, rels in pairs(s.relations or {}) do
        if not resumed then
            if id == s.driftCursor then resumed = true end
        elseif rows >= DRIFT_BUDGET then
            break
        else
            rows = rows + 1
            last = id
            for _, r in pairs(rels) do
                if r.bonded ~= true and r.atHours
                    and nowH - r.atHours > 336
                    and r.trust and math.abs(r.trust) > 0.01 then
                    r.trust = r.trust * 0.92
                    moved = moved + 1
                    -- Enmity that has faded to nothing is over. Nobody
                    -- shook hands; they simply stopped mattering to each
                    -- other.
                    if r.hostile == true and math.abs(r.trust) < 0.2 then
                        r.hostile = false
                    end
                end
            end
        end
    end
    -- A cursor naming a row that has since gone - a rekey removes one -
    -- means `resumed` never became true and nothing was walked. Start
    -- the day over rather than let it advance on a sweep that did
    -- nothing, which would have skipped one day's drift in silence.
    if not resumed then
        s.driftCursor = nil
        return 0
    end
    -- `last` is nil when the walk reached the end without filling its
    -- budget: the day is done, and only then does the day advance.
    if last == nil or rows < DRIFT_BUDGET then
        s.lastDriftDay = day
        s.driftCursor = nil
    else
        s.driftCursor = last
    end
    return moved
end

-- Letting go ([B10]): what the county releases when a player dies.
-- Not their memory - grief, trauma, and the walk to where they fell
-- are what the county KEEPS. What lapses is what only a living
-- person can hold: a chair, a membership, a debt owed to them, and
-- a voice on the band. The chair lapses with its proper
-- consequence, exactly as an unseating.
function S.releasePlayer(playerKey)
    local s = store(); if not s then return end
    playerKey = tostring(playerKey)
    for g, meta in pairs(s.groupMeta or {}) do
        if meta.playerChair == playerKey then
            meta.playerChair = nil
            local okH, h = pcall(function()
                return SAO.History.countyHours()
            end)
            meta.govHistory = meta.govHistory or {}
            meta.govHistory[#meta.govHistory + 1] = {
                kind = "unseated", atHours = okH and h or 0,
            }
            S.pushRadioNews({ kind = "unseated", group = g })
        end
        if meta.playerMemberOf == playerKey then
            meta.playerMemberOf = nil
        end
        if meta.chairOffer == playerKey then
            meta.chairOffer = nil
        end
    end
    for _, rels in pairs(s.relations or {}) do
        -- The field is owedToMe (verified against addDebt - a `debt`
        -- guess would have silently cleared nothing).
        local r = rels[playerKey]
        if r and r.owedToMe then r.owedToMe = nil end
    end
    if s.onAir then
        s.onAir.heardBy = nil
        s.onAir.heardSolo = nil
        s.onAir.lastAckAt = nil
    end
end

-- Your household ([B18]): re-home everyone who walks with this
-- player to their claim - or to nowhere, when the claim is given up.
-- Homes are per-record and every homing path reads them key-blind,
-- so this is a claim, not a system.
function S.rehomeCompanions(playerKey, x, y, z)
    if not (SAO.Controller and SAO.Controller.agents) then return 0 end
    local moved = 0
    for aid, agent in pairs(SAO.Controller.agents) do
        if agent.companioning then
            local rec = SAO.Identity and SAO.Identity.get(aid) or nil
            if rec then
                rec.homeX, rec.homeY, rec.homeZ = x, y, z
                moved = moved + 1
            end
        end
    end
    return moved
end

-- The good word ([B8]): testimony's mirror. A survivor tells another
-- about someone they genuinely think well of; the hearer warms toward
-- a stranger they have never met. Same laws as the grudge: scaled by
-- the teller's credibility, once per (hearer, subject, teller), and
-- CEILINGED - words make you well-disposed, never loyal. Returns how
-- many credits moved.
local function policyTrustToCompany()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return (sv and tonumber(sv.TrustToCompany)) or 0.5
end

function S.tellCredits(fromId, toId)
    local s = store(); if not s then return 0 end
    local tellerCred = S.trust(toId, fromId)
    if tellerCred <= 0.3 and not S.sameGroup(fromId, toId) then return 0 end
    local moved = 0
    local mine = s.relations[fromId]
    if not mine then return 0 end
    local ceiling = policyTrustToCompany() - 0.1
    for subject, r in pairs(mine) do
        -- Only the genuinely well-regarded, and never the hearer
        -- themselves or someone they already distrust for their own
        -- reasons (a kind word does not undo a wrong you SAW).
        if subject ~= toId and (r.trust or 0) > 0.6
            and not S.isHostileTo(toId, subject)
            and S.trust(toId, subject) < ceiling then
            local hr = rel(s, toId, subject, true)
            hr.creditedBy = hr.creditedBy or {}
            if not hr.creditedBy[fromId] then
                hr.creditedBy[fromId] = true
                local before = S.trust(toId, subject)
                local after = S.adjustTrust(toId, subject,
                    0.25 * math.max(0.3, tellerCred))
                moved = moved + 1
                -- The credit ceiling (F-040b's mirror): hearsay never
                -- carries anyone past the company line on its own,
                -- and never lowers a regard already earned.
                if after > ceiling then
                    local hr2 = rel(s, toId, subject, true)
                    hr2.trust = math.max(before, ceiling)
                end
            end
        end
    end
    -- [C105] The credit was passed; the record hears it.
    if moved > 0 and SAO.Recognition then
        SAO.Recognition.onTold(fromId, toId, "credit", { moved = moved })
    end
    return moved
end

-- Posthumous testimony: the dead's own recorded enemies, for a mourner to
-- inherit at testimony weight. Returns a plain list of canonical keys.
function S.enemiesOf(id)
    local s = store(); if not s then return {} end
    local out = {}
    local mine = s.relations[id]
    if mine then
        for otherKey, r in pairs(mine) do
            if r.hostile == true then out[#out + 1] = otherKey end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Groups

-- [C111] Need, alongside trust, as what carries a person to company.
--
-- The operator's ruling (2026-09-12, on the queue's item 3): a road
-- meeting is worth more, most people not only want but NEED to be
-- around people, and trust is not always the principal determinant of
-- whether a group forms - which depends on how far along into the
-- apocalypse the world is. Until this batch every formation gate read
-- trust alone, so with a meeting worth 0.005 the line was two hundred
-- meetings off and a house could only ever grow out of trust settled
-- at genesis: nobody lonely ever founded anything.
--
-- The pull is three factors, each a fact the county already holds:
--
--   appetite    who somebody is - `SAO_History.contactFactor`, the
--               same 0.10-1.00 hash that scales how fast their past
--               settled. A hermit's need carries almost nothing.
--   isolation   where they are right now - `SAO_Isolation`'s own
--               reading, one minus saturating contact. That state
--               surface has existed since [C94] and nothing gated
--               anything on it; this is the job it was built for.
--   openness    how far the county's condition makes company a need
--               rather than a risk: months since the fall on the
--               split clock ([C61], `clockMonths`), over a horizon of
--               six. An ordinary county forms its houses through
--               acquaintance and need carries nobody; a county six
--               months into collapse is a county where being alone is
--               what kills you, and a fully isolated sociable
--               person's need can carry the whole company line.
--
-- The horizon is the one number here that is not already the
-- county's - half a year of collapse, stated at [C111] so the
-- operator could move it. [C115] makes the move real: the horizon is
-- the sandbox dial OpennessHorizonMonths, read per pull-hour recompute
-- with the stated half year as its fallback (also the declared
-- default, so a fresh world and a configured world agree). Openness
-- still rides the clock as the world is played, and a world generated
-- already deep still reads deep from its first minute - the dial
-- moves where the horizon sits, not how openness rides it.
--
-- Zero whenever any factor cannot be read - offline, a bare VM, a
-- dead or unknown id - so every gate degrades to trust alone, which
-- is the law that ran before this batch.
--
-- Read once a county hour and held: a person's need does not change
-- inside one, and the live seams ask for it often enough that
-- recomputing the whole belief store per ask would be the cost of
-- the feature.
local pullHour, pullMemo = nil, {}

function S.companyPull(id)
    local hour = nil
    pcall(function()
        hour = SAO.History and SAO.History.countyHours() or nil
    end)
    if type(hour) ~= "number" then hour = 0 end
    if hour ~= pullHour then pullHour, pullMemo = hour, {} end
    local key = tostring(id)
    if pullMemo[key] ~= nil then return pullMemo[key] end
    local reading = nil
    pcall(function()
        reading = SAO.Isolation and SAO.Isolation.of(id) or nil
    end)
    local pull = 0
    if reading then
        local months = 0
        pcall(function()
            months = SAO.History and SAO.History.clockMonths() or 0
        end)
        if type(months) ~= "number" or months < 0 then months = 0 end
        -- [C115] The horizon is the operator's dial; the fallback is
        -- the ruled half year, which is the declared default.
        local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
        local horizon = (sv and tonumber(sv.OpennessHorizonMonths)) or 6.0
        if type(horizon) ~= "number" or horizon <= 0 then horizon = 6.0 end
        local openness = math.min(1.0, months / horizon)
        pull = (tonumber(reading.appetite) or 0)
            * (tonumber(reading.isolation) or 0)
            * openness
    end
    pullMemo[key] = pull
    return pull
end

-- [C111] The standing one person brings to a company door: their
-- trust toward the other, plus their own pull - NEED substitutes for
-- trust not yet built; it never cancels trust already spent against
-- somebody, so the pull only reads where trust is not negative. Each
-- door keeps its own comparison and its own bar (mercy softens it
-- where it did before); this is the value both sides of every such
-- door read, so the road, the table, and the player's own company
-- cannot disagree about the same person on the same day.
function S.companyStanding(id, otherKey)
    local t = S.trust(id, otherKey)
    if t < 0 then return t end
    local v = t + S.companyPull(id)
    -- [C117] The afflicted at the company door. The judge's own
    -- belief poses the question and the judge's own character answers
    -- it - [B3]'s law for the bitten, at the deeper bend: a survivor
    -- who believes the other carries a form reads their door value
    -- down by their own fear, nerve holding it and compassion
    -- opening it, and nothing is refused by badge. Need does not
    -- overrule who somebody is ([C111]) and neither does this: the
    -- composed can still take the shaped stranger in, the frightened
    -- cannot, and both are the same person on the same day at every
    -- door - the road, the table, the visit, the companion walk, and
    -- the player's own asks - because this is the value, and the
    -- value is the one law.
    if SAO.Perception and SAO.Perception.believedFormOf then
        local tick = nil
        pcall(function()
            tick = SAO.Controller and SAO.Controller.tick
                and SAO.Controller.tick() or nil
        end)
        if type(tick) == "number" then
            local form = nil
            pcall(function()
                form = SAO.Perception.believedFormOf(id, otherKey, tick)
            end)
            if form then
                local tr = SAO.Disposition and SAO.Disposition.traits
                    and SAO.Disposition.traits(id) or nil
                local fear = 0
                pcall(function()
                    fear = SAO.Disposition and SAO.Disposition.fear
                        and SAO.Disposition.fear(id) or 0
                end)
                if tr then
                    local weight = (1.0 - (tonumber(tr.nerve) or 0.5))
                        + (tonumber(fear) or 0)
                        - (tonumber(tr.compassion) or 0.5)
                    if weight > 0 then v = v - weight * 0.6 end
                end
            end
        end
    end
    return v
end

-- Company is a personal decision. Social contact can satisfy a need or
-- strain somebody who prefers solitude; neither fact sets a headcount.
-- The isolation surface owns those two normalized readings. Their product
-- is the unwanted share of the contact this person actually experiences.
-- A member also feels their own unmet food/water need, measured by the
-- population module against the same patience their day already uses.
-- An outsider cannot read the house's supplies; their own hunger may be
-- why they seek company, so it is not a cost of that unknown house.
function S.companyPressure(id, groupName)
    local reading = nil
    pcall(function()
        reading = SAO.Isolation and SAO.Isolation.of(id) or nil
    end)
    local pressure = 0
    if reading and type(reading.appetite) == "number"
        and type(reading.experiencedContact) == "number" then
        pressure = (1 - math.max(0, math.min(1, reading.appetite)))
            * math.max(0, math.min(1, reading.experiencedContact))
    end
    if groupName and S.groupOf(id) == tostring(groupName) then
        local need = 0
        pcall(function()
            need = SAO.Population and SAO.Population.companyNeedPressure
                and SAO.Population.companyNeedPressure(id) or 0
        end)
        if type(need) == "number" then
            pressure = pressure + math.max(0, math.min(1, need))
        end
    end
    return pressure
end

-- The caller supplies the person actually met. No roster size, floor area,
-- or unseen larder enters either side's answer. Existing callers without a
-- counterpart may use their own chair; an outsider with no named contact
-- has only their own social need to weigh, not an invented relationship.
function S.circleRefuses(id, groupName, otherKey)
    if not id or not groupName then return false end
    groupName = tostring(groupName)
    if not otherKey and S.groupOf(id) == groupName then
        otherKey = S.leaderOf(groupName)
        if otherKey == id then otherKey = nil end
    end
    if otherKey and S.isHostileTo(id, otherKey) then return true end
    local support = otherKey and S.companyStanding(id, otherKey)
        or S.companyPull(id)
    return support < 0 or S.companyPressure(id, groupName) > support
end

-- One person proposes keeping company to the person actually encountered.
-- Two unattached people can found a roster because they are its complete
-- constituency. Joining an existing roster additionally requires explicit
-- membership jurisdiction; otherwise acceptance is durable sponsorship, not
-- admission silently imposed on absent members.
function S.proposeCompany(originatorId, recipientId, channel, activity)
    originatorId, recipientId = tostring(originatorId or ""),
        tostring(recipientId or "")
    if originatorId == "" or recipientId == ""
        or originatorId == recipientId
        or not (SAO.Organization and SAO.Communication)
        or SAO.Communication.canConverse(originatorId, recipientId,
            channel) ~= true then return nil, nil, false, "not-delivered" end
    local originGroup, recipientGroup = S.groupOf(originatorId),
        S.groupOf(recipientId)
    if originGroup and recipientGroup then
        return nil, nil, false, "already-affiliated"
    end
    local groupName = originGroup or recipientGroup
        or ("company-" .. originatorId)
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local bar = (options and tonumber(options.TrustToCompany)) or 0.5
    if originGroup or recipientGroup then
        local creed = S.creedOf(groupName)
        if creed and creed.name == "mercy" then bar = bar - 0.1 end
    end
    local originStanding = S.companyStanding(originatorId, recipientId)
    if originStanding <= bar
        or S.circleRefuses(originatorId, groupName, recipientId) then
        return nil, nil, false, "originator-declined"
    end
    local founding = not originGroup and not recipientGroup
    local newcomerId = originGroup and recipientId or originatorId
    local hostId = originGroup and originatorId
        or recipientGroup and recipientId or nil
    local process = SAO.Organization.raiseMatter(originatorId,
        founding and "company-formation" or "membership", groupName, {
            recipientId = recipientId, personId = newcomerId,
            scope = { action = founding and "cofound-company"
                    or "sponsor-membership",
                organization = groupName, personId = newcomerId,
                founding = founding },
        }, { recipientId }, {
            source = channel == "dormant-encounter"
                and "dormant-encounter" or "represented-conversation",
            companyStanding = originStanding,
            currentGroup = originGroup,
        })
    if not process or not SAO.Organization.recordReception(process.id,
        recipientId, process.revision, channel or "spoken", originatorId,
        { actualRecipient = true }) then
        return process, nil, false, "not-delivered"
    end
    local recipientStanding = S.companyStanding(recipientId, originatorId)
    local hostile = S.isHostileTo(recipientId, originatorId) == true
    local currentActivity = tostring(activity or (channel == "dormant-encounter"
        and "dormant" or "conversation"))
    local choice = hostile and "contest"
        or S.circleRefuses(recipientId, groupName, originatorId) and "decline"
        or (currentActivity ~= "idle" and currentActivity ~= "dormant"
            and currentActivity ~= "conversation") and "defer"
        or recipientStanding > bar and "accept"
        or "decline"
    local response = SAO.Organization.appraiseMatter(process.id,
        recipientId, {
            owner = "Standing.proposeCompany", executor = "SAO.Standing",
            currentActivity = currentActivity,
            relationship = S.trust(recipientId, originatorId),
            contest = hostile, choice = choice,
            interests = { companyStanding = recipientStanding,
                currentGroup = recipientGroup },
            constraints = { actualRecipient = true,
                existingRoster = not founding },
        })
    if not response or not SAO.Organization.deliverResponse(process.id,
        recipientId, originatorId, channel or "spoken",
        { actualRecipient = true }) then
        return process, response, false, "response-not-delivered"
    end
    if response.response ~= "accept" then
        return process, response, false, response.response
    end
    if founding then
        local formed = S.formCompany({ originatorId, recipientId }, groupName)
        return process, response, formed == true,
            formed and "founded" or "founding-refused"
    end
    local canAdmit = SAO.Recognition and SAO.Recognition.membershipAuthority
        and SAO.Recognition.membershipAuthority(groupName, hostId) == true
    if canAdmit then
        return process, response, S.joinGroup(newcomerId, groupName), "admitted"
    end
    return process, response, false, "sponsor-only"
end

-- Membership cleanup is lifecycle work, not an election. It owns only the
-- empty-house retirement and the one-survivor widow release that must still
-- happen after leaving or death.
function S.maintainRoster(groupName)
    local s = store(); if not s or not groupName then return 0 end
    groupName = tostring(groupName)
    local members = {}
    for id, group in pairs(s.groups or {}) do
        if tostring(group) == groupName then
            local rec = SAO.Identity and SAO.Identity.get
                and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then members[#members + 1] = id end
        end
    end
    if #members == 0 then
        s.groupMeta[groupName] = nil
        if s.groupClaims then s.groupClaims[groupName] = nil end
        if SAO.Material and SAO.Material.forgetHouse then
            SAO.Material.forgetHouse(groupName)
        end
        if SAO.Recognition then SAO.Recognition.onHouseDissolved(groupName) end
        return 0
    end
    if #members > 1 then return #members end
    local widow = members[1]
    local claim = s.groupClaims and s.groupClaims[groupName] or nil
    if claim then
        s.claims[widow] = { minX = claim.minX, minY = claim.minY,
            maxX = claim.maxX, maxY = claim.maxY, z = claim.z or 0 }
        s.groupClaims[groupName] = nil
        if SAO.Material and SAO.Material.forgetHouse then
            SAO.Material.forgetHouse(groupName)
        end
        if SAO.Settlement and SAO.Settlement.clearStorageProjection then
            SAO.Settlement.clearStorageProjection(groupName)
        end
    end
    s.groups[widow] = nil
    s.groupMeta[groupName] = nil
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(widow) or nil
    if rec then rec.designation, rec.designatedBy = nil, nil end
    if SAO.Recognition then SAO.Recognition.onHouseDissolved(groupName) end
    return 1
end

function S.joinGroup(id, groupName)
    local s = store(); if not s then return false end
    s.groups[id] = tostring(groupName)
    return true
end

-- Founding writes the roster as one event. It creates the house's lifecycle
-- metadata, but assigns no leader, office, job, policy, assent, or outcome.
-- Widow release remains shrink-only cleanup in maintainRoster.
function S.formCompany(ids, groupName)
    local s = store(); if not s then return false end
    if type(ids) ~= "table" then return false end
    groupName = tostring(groupName)
    local roster = {}
    for i = 1, #ids do
        local id = ids[i]
        if id ~= nil and not roster[id] then
            local rec = SAO.Identity and SAO.Identity.get
                and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then roster[id] = true end
        end
    end
    local n = 0
    for id in pairs(roster) do
        n = n + 1
        s.groups[id] = groupName
    end
    if n < 2 then
        for id in pairs(roster) do s.groups[id] = nil end
        return false
    end
    s.groupMeta = s.groupMeta or {}
    s.groupMeta[groupName] = s.groupMeta[groupName] or {}
    return true
end

-- How many LIVING members a company holds.
function S.groupSize(groupName)
    local s = store(); if not s then return 0 end
    groupName = tostring(groupName)
    local n = 0
    for id, g in pairs(s.groups or {}) do
        if g == groupName then
            local rec = SAO.Identity and SAO.Identity.get
                and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then n = n + 1 end
        end
    end
    return n
end

function S.leaveGroup(id)
    local s = store(); if not s then return false end
    local groupName = s.groups[id]
    if not groupName then return false end
    s.groups[id] = nil
    if SAO.Organization and SAO.Organization.leave then
        SAO.Organization.leave(groupName, tostring(id))
    end
    local lrec = SAO.Identity and SAO.Identity.get(id) or nil
    if lrec then lrec.designation = nil end
    S.maintainRoster(groupName)
    return true
end

-- Voluntary separation is an originator-owned act. Nearby named recipients
-- may acquire the notice, but nobody's assent is invented or required. The
-- process closes only after Standing, the roster owner, performs the leave.
function S.withdrawFromCompany(id, reason, recipientIds, channel, evidence)
    id = tostring(id or "")
    local groupName = S.groupOf(id)
    if id == "" or not groupName or not SAO.Organization then
        return nil, false
    end
    local addressed = {}
    for _, recipientId in ipairs(type(recipientIds) == "table"
        and recipientIds or {}) do
        recipientId = tostring(recipientId or "")
        if recipientId ~= "" and recipientId ~= id
            and SAO.Communication
            and SAO.Communication.canConverse(id, recipientId, channel) == true then
            addressed[#addressed + 1] = recipientId
        end
    end
    local process = SAO.Organization.raiseMatter(id,
        "membership-withdrawal", groupName, {
            reason = tostring(reason or "voluntary"),
            scope = { action = "leave-membership",
                organization = groupName, personId = id },
        }, addressed, evidence or { source = "private-choice" })
    if not process then return nil, false end
    for _, recipientId in ipairs(addressed) do
        SAO.Organization.recordReception(process.id, recipientId,
            process.revision, channel or "spoken", id,
            { actualRecipient = true, notice = "withdrawal" })
    end
    local left = S.leaveGroup(id)
    if left then
        SAO.Organization.closeMatter(process.id, id,
            "originator-left-membership", {
                organization = groupName, reason = reason,
            })
    end
    return process, left, groupName
end

-- A death leaves the company ([C68]).
--
-- `electLeader` and `groupSize` have always filtered the dead when they
-- run, so the roster has always MEANT living membership. Nothing ran
-- them on a death. `markDead` forgets nine things about a dead
-- survivor and never touched `s.groups`, so the row stayed forever:
-- `groupOf` was the only reader disagreeing with the two that decide,
-- the store grew for the life of the save the way `dormantLastMet` did
-- before `[B51]`, and - the part that costs a survivor something - the
-- widow release fired when a housemate LEFT and never when one DIED.
-- A survivor whose company died around them was left alone in a house
-- the rule says may not exist, never released, so the group's ground
-- never became theirs and the controller's `aloneAgain` never spoke.
--
-- One call site re-elected: `SAO_Controller`, and only when the corpse
-- had been the leader. A non-leader's death left the house untouched,
-- and the dormant half of the county, where most deaths happen, had no
-- equivalent at all. This is the funnel's job, by the argument
-- `markDead` already makes twice in its own comments.
--
-- Which house they died in stays ON THE RECORD, because death is
-- durable here and a person belonged somewhere when it happened.
-- Returns the group they left, or nil.
function S.releaseDead(id)
    local s = store(); if not s then return nil end
    local groupName = s.groups[id]
    if not groupName then
        if SAO.Organization and SAO.Organization.releaseActor then
            SAO.Organization.releaseActor(tostring(id), "actor-dead")
        end
        return nil
    end
    s.groups[id] = nil
    if SAO.Organization and SAO.Organization.releaseActor then
        SAO.Organization.releaseActor(tostring(id), "actor-dead")
    elseif SAO.Organization and SAO.Organization.leave then
        SAO.Organization.leave(groupName, tostring(id))
    end
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    if rec then
        rec.diedInGroup = groupName
        rec.designation = nil
        rec.designatedBy = nil
    end
    S.maintainRoster(groupName)
    return groupName
end

-- ---------------------------------------------------------------------------
-- Governance is read from explicit enacted authority. A roster and its trust
-- relations remain inputs people may use; neither produces a leader.

function S.leaderOf(groupName)
    if not (SAO.Organization and groupName) then return nil end
    local office = SAO.Organization.offices[
        tostring(groupName) .. ":chair"]
    local found = nil
    for personId, evidence in pairs(office and office.holders or {}) do
        if type(evidence) == "table" and evidence.commitmentId then
            if found then return nil end -- shared authority has no sole leader
            found = personId
        end
    end
    return found
end

-- The four creed terms below remain observations of a roster's lived
-- composition. They do not appoint anyone or cause a split.
--
-- DECLARED HERE with the other creed constants rather than beside
-- `creedOf` where they read best: the related readers are compiled above and
-- Lua locals remain invisible before their declaration.
local CREED_KEYS = { "order", "mercy", "wall", "road" }
local CREED_OPPOSES = { order = "road", road = "order",
                        wall = "mercy", mercy = "wall" }
-- A person's lived pull may inform what they propose; it never installs a
-- house policy. Only an explicit Organization decision can do that.
local RATION_PREFERENCE = {
    order = "watch-first", mercy = "weak-first",
    wall = "house-first", road = "carry-light",
}

-- [B23] Whether a house has RANKS at all is what it believes.
--
-- The creeds already carry postures about structure or flatness, and
-- their own ration policies say so: order feeds the watch first, wall
-- feeds the house and nobody else - both are precedence. Mercy feeds
-- the weakest and road keeps every pack light - both are levelling.
-- So this is read off meaning the creeds already had, not assigned to
-- them.
--
-- A commune is a real outcome here rather than a special case: it is
-- what a mercy house IS.
--
-- DECLARED HERE, not beside `secondOf` where it reads more naturally:
-- [B23]'s turn block lives inside `electLeader` far above that, and a
-- Lua local is invisible to any function compiled before it. Sitting
-- lower, this resolved to a nil global and indexing it would have
-- thrown inside an election.
local STRUCTURED_CREED = { order = true, wall = true }

local function updateElectionCreed(s, groupName)
    -- [B23] The turn of a house. Culture already adapted - the creed
    -- is rendered from who is alive and what they have learned - but
    -- nothing ever COMPARED, so a transformation could not be noticed
    -- even in principle. And with no margin, a house near a tie would
    -- flip every election: churn wearing culture's clothes.
    do
        local metaT = s.groupMeta[groupName] or {}
        local live = S.creedOf(groupName)
        if live and live.name then
            local settled = metaT.creedName
            local okTH, th = pcall(function()
                return SAO.History.countyHours()
            end)
            local nowT = okTH and th or 0
            if not settled then
                -- The first reading is not a turn. It is just who
                -- these people are.
                metaT.creedName = live.name
                metaT.creedSinceHours = nowT
                s.groupMeta[groupName] = metaT
            elseif live.name ~= settled then
                -- A challenger must LEAD, not tie. Components score
                -- one per member and a half per relevant lesson, so
                -- this margin is about a member and a lesson's worth
                -- of difference - a house does not abandon what it
                -- believes because one person had a bad week.
                local gain = (live.comp and live.comp[live.name] or 0)
                    - (live.comp and live.comp[settled] or 0)
                if gain >= 1.5 then
                    -- [B23] The form before and after, not a
                    -- has-ladder boolean: a house can move between
                    -- council, ladder and divided, and each is a
                    -- different kind of place to live.
                    local formWas = S.formOf(groupName)
                    metaT.creedName = live.name
                    metaT.creedSinceHours = nowT
                    metaT.govHistory = metaT.govHistory or {}
                    metaT.govHistory[#metaT.govHistory + 1] = {
                        kind = "creed", creed = live.name,
                        from = settled, atHours = nowT,
                    }
                    s.groupMeta[groupName] = metaT
                    S.pushRadioNews({ kind = "creed", group = groupName,
                        creed = live.name })
                    log(tostring(groupName) .. " turns: " .. tostring(settled)
                        .. " -> " .. tostring(live.name))
                    -- A house becoming flat, or growing a ladder, is a
                    -- bigger thing than a change of menu and is
                    -- recorded as its own governance event.
                    local formNow = S.formOf(groupName)
                    if formWas ~= formNow then
                        metaT.govHistory[#metaT.govHistory + 1] = {
                            kind = "form", form = formNow,
                            wasForm = formWas, atHours = nowT,
                        }
                        S.pushRadioNews({ kind = "form",
                            group = groupName, form = formNow })
                        log(tostring(groupName) .. " is governed differently"
                            .. " now: " .. tostring(formWas) .. " -> "
                            .. tostring(formNow))
                    end
                end
            end
        end
    end
end

local function applyElectionDivision(groupName, members)
    -- [B23] A division that goes somewhere. [B23] built the state
    -- and left it sitting: `checkSchism` fires on a mutually hostile
    -- pair and knows nothing about creed, so two opposed truths could
    -- share a roof forever. The operator's whole point was the
    -- "until".
    --
    -- No new schism machinery, because the existing one is already
    -- trust-shaped - it leaves with "the core and everyone who trusts
    -- them more than the leader". Bend trust along the fault line and
    -- the split follows it on its own.
    --
    -- Two FACES, not everybody against everybody: the naive version
    -- would sour sixteen pairs at once in a house of eight and make a
    -- schism a formality within days - the [B19] aggregate failure
    -- wearing politics. The quarrel is between the most-trusted
    -- adherent of each creed: the challenger who could lead and does
    -- not hold the chair.
    if S.formOf(groupName) == "divided" then
        local settledC = S.creedNameOf(groupName)
        local foeC = settledC and CREED_OPPOSES[settledC] or nil
        if foeC then
            local faceOurs, faceOursT = nil, -1e9
            local faceTheirs, faceTheirsT = nil, -1e9
            for _, mid in ipairs(members) do
                local lean = S.leansToward(mid)
                if lean == settledC or lean == foeC then
                    local sum = 0
                    for _, other in ipairs(members) do
                        if other ~= mid then
                            sum = sum + S.trust(other, mid)
                        end
                    end
                    if lean == settledC and sum > faceOursT then
                        faceOurs, faceOursT = mid, sum
                    elseif lean == foeC and sum > faceTheirsT then
                        faceTheirs, faceTheirsT = mid, sum
                    end
                end
            end
            if faceOurs and faceTheirs then
                for _, mid in ipairs(members) do
                    local lean = S.leansToward(mid)
                    local mine = (lean == settledC) and faceOurs
                        or (lean == foeC) and faceTheirs or nil
                    local theirs = (lean == settledC) and faceTheirs
                        or (lean == foeC) and faceOurs or nil
                    -- You draw closer to your side as you pull away
                    -- from theirs. Both halves are one phenomenon.
                    if mine and mid ~= mine then
                        S.adjustTrust(mid, mine, 0.02)
                    end
                    if theirs and mid ~= theirs then
                        S.adjustTrust(mid, theirs, -0.03)
                    end
                end
                -- [B23] And the two faces can come to BLOWS. The
                -- mirror found the real wall here: `politick` returns
                -- nil the moment both people are in the same group,
                -- so housemates could never become hostile through
                -- politics at all - only by attacking each other.
                -- Division drove cross-lean trust to the floor and
                -- `checkSchism`, which needs a mutually hostile pair,
                -- could never fire. The feature could not do the one
                -- thing it exists for.
                --
                -- The bar is not invented: `hostilityBar` is the same
                -- per-person threshold strangers cross ([A27]) - an
                -- aggressive pairing ignites early, two meek people
                -- endure arguments that would have been a war.
                local tA = S.trust(faceOurs, faceTheirs)
                local tB = S.trust(faceTheirs, faceOurs)
                local barA = SAO.Disposition and SAO.Disposition.hostilityBar
                    and SAO.Disposition.hostilityBar(faceOurs) or -0.5
                local barB = SAO.Disposition and SAO.Disposition.hostilityBar
                    and SAO.Disposition.hostilityBar(faceTheirs) or -0.5
                if tA < barA and tB < barB
                    and not (S.isHostileTo(faceOurs, faceTheirs)
                        or S.isHostileTo(faceTheirs, faceOurs)) then
                    S.setHostile(faceOurs, faceTheirs, true)
                    S.setHostile(faceTheirs, faceOurs, true)
                    log(tostring(groupName) .. ": " .. tostring(faceOurs)
                        .. " and " .. tostring(faceTheirs)
                        .. " are done pretending")
                end
                log(tostring(groupName) .. " is two rooms now: "
                    .. tostring(faceOurs) .. " and "
                    .. tostring(faceTheirs))
            end
        end
    end
end

local function applyAfflictedDispute(groupName, members)
    -- [C117] The afflicted member in the room. [B23]'s quarrel runs
    -- on creed; this one runs on the pathogen's marks: a member the
    -- house can SEE is shaped ([C116]'s scanner stamps the form on
    -- the person-belief) is a question the house answers out of
    -- character, the same law [B3] set for the bitten - the fearful
    -- pull away, the composed stand by, and nobody is exiled by
    -- badge. Only members who hold a FRESH belief of the form take a
    -- stance at all; a member who has not seen them recently does
    -- not argue, and when the belief ages past the people horizon the
    -- argument quiets on its own. The bending runs on this cadence
    -- and at the sibling's magnitudes, the blows cross the same
    -- per-person bar, and everything after the blows is the split
    -- machinery's own ([A22]): checkSchism at the meeting seams,
    -- whose schism of one is the exile ([A21]) - the cast-out.
    do
        local tickNow = nil
        pcall(function()
            tickNow = SAO.Controller and SAO.Controller.tick
                and SAO.Controller.tick() or nil
        end)
        if type(tickNow) == "number"
            and SAO.Perception and SAO.Perception.believedFormOf then
            for _, mid in ipairs(members) do
                local afraid, standBy = {}, {}
                for _, oid in ipairs(members) do
                    if oid ~= mid then
                        local form = nil
                        pcall(function()
                            form = SAO.Perception.believedFormOf(
                                oid, mid, tickNow)
                        end)
                        if form then
                            local tr = SAO.Disposition
                                and SAO.Disposition.traits
                                and SAO.Disposition.traits(oid) or nil
                            if tr then
                                local fear = 0
                                pcall(function()
                                    fear = SAO.Disposition.fear(oid) or 0
                                end)
                                local weight =
                                    (1.0 - (tonumber(tr.nerve) or 0.5))
                                    + (tonumber(fear) or 0)
                                    - (tonumber(tr.compassion) or 0.5)
                                if weight > 0 then
                                    afraid[#afraid + 1] = oid
                                    S.adjustTrust(oid, mid, -0.03)
                                else
                                    standBy[#standBy + 1] = oid
                                end
                            end
                        end
                    end
                end
                if #afraid > 0 then
                    -- The subject is a person too, and the argument is
                    -- about them: they hear the room turn, and their
                    -- own trust bends against whoever pulled away. A
                    -- hollow returnee bends the same - trust is the
                    -- county's store, not the disposition's.
                    for _, a in ipairs(afraid) do
                        S.adjustTrust(mid, a, -0.02)
                    end
                    -- The two faces sour at each other, as divided
                    -- faces do.
                    for _, a in ipairs(afraid) do
                        for _, b in ipairs(standBy) do
                            S.adjustTrust(a, b, -0.02)
                            S.adjustTrust(b, a, -0.02)
                        end
                    end
                    -- [B23]'s come-to-blows clause, the same
                    -- per-person bar: when the subject and their
                    -- afraid face, or the two faces, cross their own
                    -- bars, hostility speaks, and the meeting seams'
                    -- checkSchism settles what the house becomes. The
                    -- roster can trust either side more - the cast-out
                    -- is whoever the split casts out, not a script's.
                    local pairsToTest = {}
                    for _, a in ipairs(afraid) do
                        pairsToTest[#pairsToTest + 1] = { a, mid }
                        for _, b in ipairs(standBy) do
                            pairsToTest[#pairsToTest + 1] = { a, b }
                        end
                    end
                    for _, p in ipairs(pairsToTest) do
                        local a, b = p[1], p[2]
                        local barA = SAO.Disposition
                            and SAO.Disposition.hostilityBar
                            and SAO.Disposition.hostilityBar(a) or -0.5
                        local barB = SAO.Disposition
                            and SAO.Disposition.hostilityBar
                            and SAO.Disposition.hostilityBar(b) or -0.5
                        if S.trust(a, b) < barA and S.trust(b, a) < barB
                            and not (S.isHostileTo(a, b)
                                or S.isHostileTo(b, a)) then
                            S.setHostile(a, b, true)
                            S.setHostile(b, a, true)
                            log(tostring(groupName) .. ": "
                                .. tostring(a) .. " and " .. tostring(b)
                                .. " are done pretending about "
                                .. tostring(mid))
                        end
                    end
                    log(tostring(groupName) .. " argued over "
                        .. tostring(mid) .. ": " .. #afraid .. " afraid, "
                        .. #standBy .. " standing by")
                end
            end
        end
    end
end

local function reviewElectionWork(s, groupName, members)
    -- [B21] The work is JUDGED. [B2] made the roster self-correcting
    -- on skill and [B13] on need; neither ever looked at whether the
    -- work was getting DONE. A designation, once dealt, was permanent
    -- unless somebody better turned up - which is a seating chart,
    -- not a society.
    --
    -- Judged by the STATE OF THE WORK, never by attribution. Nothing
    -- tracks who applied which dressing and nothing needs to: the
    -- house does not audit, it looks around, and the evidence is
    -- lying in plain sight where anyone can see it.
    --
    -- Watch, scout, forager and quartermaster are deliberately NOT
    -- judged. A quiet night does not prove the watch was good and a
    -- thin larder does not prove the forager was lazy - it may mean
    -- there is nothing left out there. A measure that cannot tell bad
    -- work from a bad world is worse than no measure.
    do
        local worstId, worstJob, worstEvidence = nil, nil, 0
        local provenId, provenJob = nil, nil
        for _, mid in ipairs(members) do
            local mr = SAO.Identity and SAO.Identity.get(mid) or nil
            local job = mr and mr.designation or nil
            local mb = SAO.Body and SAO.Body.get and SAO.Body.get(mid) or nil
            -- Work that cannot be SEEN cannot be judged. An unloaded
            -- person's larder is nobody's evidence.
            if job and mb and SAO.Needs then
                local evidence = 0
                if job == "medic" then
                    for _, oid in ipairs(members) do
                        if oid ~= mid then
                            local ob = SAO.Body.get(oid)
                            if ob then
                                if SAO.Needs.dirtyBandages
                                    and SAO.Needs.dirtyBandages(ob) > 0 then
                                    evidence = evidence + 1
                                end
                                if SAO.Needs.bleeding
                                    and SAO.Needs.bleeding(ob) > 0 then
                                    evidence = evidence + 1
                                end
                            end
                        end
                    end
                elseif job == "cook" then
                    -- No evidence is NOT evidence of none. This is
                    -- Standing's first use of the bridge, so if it is
                    -- absent the cook becomes UNJUDGEABLE and keeps
                    -- the job - rather than being declared proven by
                    -- our own blindness, which is what a swallowed
                    -- pcall leaving zero would have meant.
                    evidence = -1
                    if SAOJavaBridge then
                        local okRaw, raw45 = pcall(function()
                            return SAOJavaBridge:countRawDangerNearby(mb, 6)
                        end)
                        if okRaw then evidence = tonumber(raw45) or 0 end
                    end
                elseif job == "quartermaster" then
                    -- [C71] Only complete material reconciliation may
                    -- author larder and water claims. The quartermaster's
                    -- bounded private view can guide action but cannot make
                    -- a house total. Existing complete claims and the real
                    -- hearth observation remain judgeable by staleness.
                    evidence = -1
                    if materialEnabled() then
                        local okQH, qh = pcall(function()
                            return SAO.History.countyHours()
                        end)
                        if okQH then
                            local metaQ = s.groupMeta
                                and s.groupMeta[groupName] or nil
                            local stale = 0
                            if metaQ then
                                local l = metaQ.larder
                                if l and (qh - (l.atHours or 0)) > 48 then
                                    stale = stale + 1
                                end
                                local w = metaQ.waterStore
                                if w and (qh - (w.atHours or 0)) > 48 then
                                    stale = stale + 1
                                end
                                local hh = metaQ.hearth
                                if hh and (qh - (hh.atHours or 0)) > 48 then
                                    stale = stale + 1
                                end
                            end
                            evidence = stale
                        end
                    end
                else
                    evidence = -1
                end
                if evidence > worstEvidence then
                    worstId, worstJob, worstEvidence = mid, job, evidence
                elseif evidence == 0 and not provenId then
                    provenId, provenJob = mid, job
                end
            end
        end
        -- One revocation per election: houses come apart a person at a
        -- time, and [B13] fills the gap next time round with whoever
        -- is actually suited.
        if worstId and worstEvidence >= 2 then
            local wrec45 = SAO.Identity.get(worstId)
            if wrec45 then
                wrec45.designation = nil
                wrec45.designatedBy = nil
            end
            if SAO.Body and SAO.Body.get and SAO.Body.get(worstId) then
                pcall(function()
                    SAO.Voice.onEvent(worstId, "workDoubted")
                end)
            end
            log(worstId .. " is no longer the " .. tostring(worstJob)
                .. " - the work shows (" .. worstEvidence
                .. " against them)")
        elseif provenId then
            -- Keeping it IS the reward, and the house says so. Trust
            -- is what elections, chairs and company already run on, so
            -- good work becomes standing without inventing anything
            -- new to carry it.
            for _, oid in ipairs(members) do
                if oid ~= provenId then
                    S.adjustTrust(oid, provenId, 0.03)
                end
            end
            log(provenId .. " keeps the " .. tostring(provenJob)
                .. " work - it shows, and the house sees it")
        end
    end
end

-- Automatic trust-sum elections are retired. Leadership may be projected only
-- from an explicit, revisioned authority process; that projector is owned by
-- Organization rather than this standing reader.
function S.electLeader(groupName)
    return nil, S.leaderOf(groupName), "explicit-process-required"
end

-- Doctrine (census C5, [A18]): a company's creed is RENDERED from its
-- living roster - who they were (occupation class) and what they hold
-- (claims) - never stored prose. Four components; the loudest names the
-- creed. order: rules and watches. mercy: taking people in. wall:
-- ground held and doors kept. road: mobility and quiet. Opposition is
-- structural: rules chafe the free (order vs road), gates chafe the
-- open hand (wall vs mercy).

-- [B23] Which way ONE person pulls, read exactly as `creedOf` reads a
-- whole house: their occupation class, and the lessons they have
-- actually lived. The veteran leans order; the carer leans mercy.
-- Nobody assigns a side - their past and their scars do.
--
-- This is what makes a divided house generate instead of being
-- staged: the operator's bar - the veteran and the carer must not
-- hear the same speech - is not a rule written here, it is what
-- falls out of
-- reading the same numbers per-person that the house is read by.
-- [B24] ONE reader for what a person contributes to a creed. It was
-- copied into `creedOf` and `leansToward`; the baseline below needs
-- it too, and three copies of this arithmetic is how they would come
-- to disagree about what a house believes.
--
-- `weak` reports that the only pull came from the unclassified
-- default - the +0.5 a trades life adds to wall for want of anywhere
-- better to put it. That is not a conviction, and [B24] stops
-- treating it as one.
function S.creedPullOf(id, into)
    local comp = into or { order = 0, mercy = 0, wall = 0, road = 0 }
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
        or nil
    if not rec or rec.dead then return comp, true end
    local weak = false
    local cls = (SAO.Census and SAO.Census.classOf)
        and SAO.Census.classOf(rec.occupation) or nil
    if cls == "hardened" then comp.order = comp.order + 1
    elseif cls == "carer" then comp.mercy = comp.mercy + 1
    elseif cls == "outdoors" then comp.road = comp.road + 1
    elseif cls == "settled" then comp.wall = comp.wall + 1
    else
        comp.wall = comp.wall + 0.5
        weak = true
    end
    if SAO.Lessons then
        if SAO.Lessons.has(id, "routine-is-armor") then
            comp.order = comp.order + 0.5
            weak = false
        end
        if SAO.Lessons.has(id, "people-are-worth-it") then
            comp.mercy = comp.mercy + 0.5
            weak = false
        end
        if SAO.Lessons.has(id, "claimed-places-bite") then
            comp.wall = comp.wall + 0.5
            weak = false
        end
        if SAO.Lessons.has(id, "noise-is-a-debt")
            or SAO.Lessons.has(id, "running-has-a-price") then
            comp.road = comp.road + 0.5
            weak = false
        end
    end
    return comp, weak
end

-- [B24] The county's own baseline - what a creed pull looks like
-- across everyone still alive. Cached by the day: the population
-- does not turn over hourly and this walks the whole roster.
local creedBase = { atHours = -1e9, share = nil }

local function countyCreedShare()
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    local now = okH and h or 0
    if creedBase.share and (now - creedBase.atHours) < 24 then
        return creedBase.share
    end
    local total = { order = 0, mercy = 0, wall = 0, road = 0 }
    local n = 0
    if SAO.Identity and SAO.Identity.all then
        for _, rec in pairs(SAO.Identity.all()) do
            if rec and not rec.dead and rec.id then
                n = n + 1
                S.creedPullOf(rec.id, total)
            end
        end
    end
    local sum = 0
    for _, k in ipairs(CREED_KEYS) do sum = sum + (total[k] or 0) end
    local share = { order = 0.25, mercy = 0.25, wall = 0.25, road = 0.25 }
    if n > 0 and sum > 0 then
        for _, k in ipairs(CREED_KEYS) do
            share[k] = (total[k] or 0) / sum
        end
    end
    creedBase = { atHours = now, share = share }
    return share
end

-- [B24] Which way ONE person pulls. Returns nil for a life whose only
-- pull is the unclassified default: most people do not have a
-- conviction about how the house should be run, and pretending they
-- do made 81% of the county nominally "wall" and every divided house
-- impossible.
function S.leansToward(id)
    local comp, weak = S.creedPullOf(id)
    if weak then return nil end
    local best, bestV = nil, -1
    for _, k in ipairs(CREED_KEYS) do
        if comp[k] > bestV then best, bestV = k, comp[k] end
    end
    return best
end

-- A lived pull supplies one person's preference, never the house's form.
-- Multiple delivered commitments or an explicitly held office are what the
-- form summary observes later.
function S.formPreferenceOf(id)
    local pull = S.leansToward(id)
    if not pull then return nil end
    return STRUCTURED_CREED[pull] and "ladder" or "council"
end

-- [B23] What FORM this house has taken. Not "how much hierarchy" -
-- how many settled truths are under the roof, and whether the house
-- can afford to argue about it.
--
--   empty    - nobody has earned the right to speak for the house
--   council  - enough people and enough surplus to talk the work out
--   ladder   - one creed, a deputy, change only on a real margin
--   divided  - two creeds under one roof until the room splits
--   flight   - NOT a government. The larder, the water and the hearth
--              have all failed; the ground is being abandoned
--
-- The operator's map, and it is the whole map for this climate:
-- everything else is costume. A dictatorship is a hard ladder. A
-- democracy is a council with more mouths. A cult is a creed with no
-- challenger margin - which falls out of `divided` for free, because
-- a creed whose opposite never reaches the margin simply cannot be
-- contested.
--
-- Talk is a luxury of surplus: when the shelves go lean a council
-- house cannot afford it any more and falls back to a ladder. Flight
-- is that same arithmetic run to its end - the three counts [B7]
-- already reads to decide a ground is finished, named as the state
-- they leave the house in.
-- [B23] A lean house says so. Not a request to anyone in
-- particular - just word, on the same wire every other piece of
-- county news travels. Scarcity became politically load-bearing at
-- [B23] and was the one thing that never travelled.
function S.callForBread(groupName, speakerId)
    local s = store(); if not s then return false end
    if not groupName or type(speakerId) ~= "string" or speakerId == "" then
        return false
    end
    groupName = tostring(groupName)
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[groupName] or {}
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    local now = okH and h or 0
    -- A house does not spend all day saying it is hungry.
    if meta.askedAtHours and now - meta.askedAtHours < 72 then
        return false
    end
    -- The concrete proposal is owned by Organization. The speaker's larder
    -- observation stays private; recipients get only the terms and destination
    -- carried by speech or a separately proved radio receipt.
    local process = nil
    if speakerId then
        if S.groupOf(speakerId) ~= groupName
            or not (SAO.Perception and SAO.Perception.recordAidRequest
                and SAO.Organization and SAO.Organization.raiseMatter) then
            return false
        end
        local claim = S.groupClaimOf(groupName)
        local larder = S.larderOf(groupName)
        process = SAO.Organization.raiseMatter(speakerId,
            "food-delivery", groupName, {
                requesterId = speakerId,
                targetGroup = groupName,
                category = "food",
                quantity = 1,
                responsePolicy = "first-completion",
                expiresAtHours = now + 72,
                destinationRequired = true,
                requiredCapabilities = {
                    acquire = true, carry = true, deliver = true,
                },
                destination = claim and {
                    minX = claim.minX, minY = claim.minY,
                    maxX = claim.maxX, maxY = claim.maxY,
                    z = claim.z or 0,
                } or {},
                scope = { action = "acquire-carry-deliver",
                    category = "food", quantity = 1,
                    targetGroup = groupName },
            }, {}, {
                source = "private-house-situation",
                speakerId = speakerId,
                larder = larder and {
                    word = larder.word, amount = larder.amount,
                    provenance = larder.provenance,
                } or { availability = "unobserved" },
            })
        if not process then return false end
        if SAO.Perception.recordAidRequest(
            speakerId, groupName, now, "requested", nil, "food",
            process.id, process.revision, "authored",
            { source = "call-for-bread" }) ~= true then
            process.status = "withdrawn"
            return false
        end
    end
    meta.askedAtHours = now
    s.groupMeta[groupName] = meta
    meta.activeAidProcessId = process and process.id or nil
    s.groupMeta[groupName] = meta
    S.pushRadioNews({ kind = "ask", group = groupName, requestedAt = now,
        speakerId = speakerId, processId = process and process.id or nil,
        processRevision = process and process.revision or nil })
    return true
end

-- A member can turn the shortage they presently live with into a concrete
-- proposal. This is called from both represented and dormant life; the
-- seventy-two-hour source cooldown makes those execution modes one producer.
function S.maybeCallForBread(id)
    id = tostring(id or "")
    if id == "" then return false end
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or rec.dead then return false end
    local groupName = S.groupOf(id)
    if not groupName then return false end
    local larder = S.larderOf(groupName)
    if not larder or larder.word ~= "lean" then return false end
    return S.callForBread(groupName, id)
end

-- Whether a creed answers a stranger's hunger, read off the ration
-- policy each one has been broadcasting about itself since [A26].
-- Wall does not answer; "their own and no one else" is its own
-- sentence, not a rule added here.
local ANSWERS_ASK = { mercy = true, road = true, order = true,
                      wall = false }

-- [B23] Is this house asking? A reader, so the Ledger does not have
-- to reach into groupMeta itself - the same window `nearestAsking`
-- uses, from one definition rather than two.
function S.isAsking(groupName)
    local s = store(); if not s then return false end
    if not groupName then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if not (meta and meta.askedAtHours) then return false end
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return false end
    return (h - meta.askedAtHours) <= 96
end

-- The nearest privately known request this carrier's house would answer.
-- World metadata still owns whether a house has asked; it does not tell the
-- carrier that the request was heard or where the other house stands.
function S.nearestAsking(fromGroup, actorId)
    local s = store(); if not s then return nil end
    if not fromGroup or not actorId or not (SAO.Perception
        and SAO.Perception.knownAidRequests) then return nil end
    fromGroup = tostring(fromGroup)
    -- You answer out of surplus, never out of your own children's
    -- mouths.
    local mine = S.larderOf(fromGroup)
    if not (mine and mine.word == "full") then return nil end
    if not ANSWERS_ASK[S.creedNameOf(fromGroup) or ""] then return nil end
    local ourClaim = S.groupClaimOf(fromGroup)
    if not ourClaim then return nil end
    local best, bestD, bestClaim = nil, 1e18, nil
    for _, request in ipairs(SAO.Perception.knownAidRequests(actorId)) do
        local g = request.groupId
        if g ~= fromGroup
            and not S.feudBetween(fromGroup, g) then
            local theirClaim = request
            if theirClaim.minX and theirClaim.minY
                and theirClaim.maxX and theirClaim.maxY then
                local dx = ((theirClaim.minX + theirClaim.maxX) / 2)
                    - ((ourClaim.minX + ourClaim.maxX) / 2)
                local dy = ((theirClaim.minY + theirClaim.maxY) / 2)
                    - ((ourClaim.minY + ourClaim.maxY) / 2)
                local d2 = dx * dx + dy * dy
                if d2 < bestD or (d2 == bestD and tostring(g) < tostring(best)) then
                    best, bestD, bestClaim = g, d2, request
                end
            end
        end
    end
    return best, bestClaim
end

-- A player can raise a concrete arrangement with the person they are
-- actually speaking to. That person receives and answers for themselves;
-- neither the click nor their answer settles the absent roster's form.
function S.urgeForm(groupName, playerKey, form, recipientId)
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if options and options.PlayerInteraction == false then return nil end
    if not (groupName and playerKey and recipientId and SAO.Organization)
        or (form ~= "council" and form ~= "ladder")
        or S.groupOf(recipientId) ~= tostring(groupName) then return nil end
    groupName, playerKey, recipientId = tostring(groupName),
        tostring(playerKey), tostring(recipientId)
    local process = SAO.Organization.raiseMatter(playerKey,
        "governance-form", groupName, {
            proposedForm = form,
            scope = { action = "support-form-proposal",
                organization = groupName, arrangement = true },
        }, { recipientId }, {
            source = "player-conversation", proposedForm = form,
        })
    if not process then return nil end
    if not SAO.Organization.recordReception(process.id, recipientId,
        process.revision, "spoken", playerKey,
        { actualRecipient = true }) then return process end
    local activity = "dormant"
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[recipientId] or nil
    if agent then activity = string.lower(tostring(agent.state or "idle")) end
    local trust = S.trust(recipientId, playerKey)
    local hostile = S.isHostileTo(recipientId, playerKey)
    local preference = S.formPreferenceOf
        and S.formPreferenceOf(recipientId) or nil
    local choice = hostile and "contest"
        or (activity ~= "idle" and activity ~= "dormant") and "defer"
        or preference == form and "accept"
        or preference and "counter-propose"
        or trust >= 0.30 and "qualify"
        or "defer"
    local response = SAO.Organization.appraiseMatter(process.id,
        recipientId, {
            owner = "Standing.urgeForm", executor = "SAO.Standing",
            currentActivity = activity, relationship = trust,
            contest = hostile, destinationKnown = true, choice = choice,
            terms = choice == "counter-propose"
                and { proposedForm = preference }
                or choice == "qualify" and { needsOtherParticipants = true }
                or {},
            interests = { preferredForm = preference,
                currentForm = S.formOf(groupName) },
            constraints = { actualRecipient = true },
        })
    if response then
        SAO.Organization.deliverResponse(process.id, recipientId,
            playerKey, "spoken", { actualRecipient = true })
    end
    return process, response
end

-- Form is a summary of enacted arrangements, not a target selected from
-- creed, scarcity, roster size, or an urged label.
function S.formOf(groupName)
    if not groupName or S.groupSize(groupName) < 2 then return "empty" end
    groupName = tostring(groupName)
    local holderCount, contested, shared = 0, false, 0
    if SAO.Organization then
        for _, office in pairs(SAO.Organization.offices or {}) do
            if office.organization == groupName then
                for _, holder in pairs(office.holders or {}) do
                    if type(holder) == "table" and holder.commitmentId then
                        holderCount = holderCount + 1
                    end
                end
            end
        end
        for _, process in pairs(SAO.Organization.processes or {}) do
            local revision = process.revisions
                and process.revisions[tostring(process.revision or 1)] or nil
            local scope = revision and revision.proposal
                and revision.proposal.scope or nil
            if process.organizationId == groupName
                and type(scope) == "table" and scope.arrangement == true then
                contested = contested or process.contested == true
                for _, commitment in pairs(process.commitments or {}) do
                    if commitment.status == "accepted"
                        or commitment.status == "in-progress" then
                        shared = shared + 1
                    end
                end
            end
        end
    end
    if contested then return "divided" end
    if holderCount > 1 or shared > 1 then return "council" end
    if holderCount == 1 then return "ladder" end
    return "unsettled"
end

-- [B23] What a house has SETTLED into, as opposed to what a single
-- reading of its roster says this second. Stored as a dated claim -
-- which is claims-not-chapters working rather than breaking it:
-- "this house settled into mercy at hour N" is a claim with
-- provenance, and it is the cultural history the question was about.
--
-- Everything downstream reads THIS, not the raw reading, so a house
-- near a tie cannot flicker its ration policy and its ladder every
-- election. Culture turns; it does not flicker.
function S.creedNameOf(groupName)
    local s = store(); if not s then return nil end
    if not groupName then return nil end
    groupName = tostring(groupName)
    local meta = s.groupMeta and s.groupMeta[groupName] or nil
    if meta and meta.creedName then return meta.creedName end
    -- Never settled yet (a young house, or an old save): the live
    -- reading is the honest answer until an election settles one.
    local live = S.creedOf(groupName)
    return live and live.name or nil
end

-- The second - derived at read time from the SAME trust sum the
-- election runs on, never stored. No rank field, no appointment, no
-- ceremony: standing shifts the moment trust does, which is how
-- [B21]'s "kept work becomes standing" reaches the top of a house.
function S.secondOf(groupName)
    if not (groupName and SAO.Organization) then return nil end
    local office = SAO.Organization.offices[
        tostring(groupName) .. ":deputy"]
    local found = nil
    for personId, evidence in pairs(office and office.holders or {}) do
        if type(evidence) == "table" and evidence.commitmentId then
            if found then return nil end
            found = personId
        end
    end
    return found
end

function S.creedOf(groupName)
    local s = store(); if not s then return nil end
    if not groupName then return nil end
    groupName = tostring(groupName)
    local comp = { order = 0, mercy = 0, wall = 0, road = 0 }
    local n = 0
    for id, g in pairs(s.groups) do
        if tostring(g) == groupName then
            local rec = SAO.Identity and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then
                n = n + 1
                -- [B24] The shared reader, so the house, the person
                -- and the county baseline cannot drift apart.
                -- The reader applies the lessons too; a leftover
                -- copy of them here double-counted every one.
                S.creedPullOf(id, comp)
            end
        end
    end
    if n == 0 then return nil end
    -- [B24] A creed is what DISTINGUISHES this house, not what
    -- everybody is. Scored on the raw maximum, `wall` won almost
    -- everywhere - the census is 54% settled and every unclassified
    -- life adds another half to wall, so wall carried 79% of the
    -- county's pull and all seventeen companies in the mirror held
    -- it. That is not a creed; it is a default.
    --
    -- Now each component is measured against what the county's own
    -- living population would predict, so a house is mercy because it
    -- holds MORE carers than usual, not because carers exist.
    local share = countyCreedShare()
    local best, bestV = nil, -1e9
    for _, k in ipairs(CREED_KEYS) do
        local expected = (share[k] or 0.25) * n
        local excess = (comp[k] or 0) - expected
        if excess > bestV then best, bestV = k, excess end
    end
    return { name = best, comp = comp, size = n }
end

-- aligned / neutral / opposed - or nil when either side has no
-- company. [A24]: the clash reads the FULL per-capita component
-- vectors, not just the loudest name - two wall companies, one
-- order-tempered and one mercy-tempered, have real doctrinal friction
-- in what they are SECONDARILY. Clash = overlap along the opposition
-- axes (order-road, wall-mercy); alignment = overlap along the same
-- components. Names still decide when the vectors are ambiguous.
function S.creedClash(gA, gB)
    local a, b = S.creedOf(gA), S.creedOf(gB)
    if not a or not b then return nil end
    local av, bv = {}, {}
    for _, k in ipairs(CREED_KEYS) do
        av[k] = (a.comp[k] or 0) / math.max(1, a.size)
        bv[k] = (b.comp[k] or 0) / math.max(1, b.size)
    end
    local clash = math.min(av.order, bv.road) + math.min(av.road, bv.order)
        + math.min(av.wall, bv.mercy) + math.min(av.mercy, bv.wall)
    local align = 0
    for _, k in ipairs(CREED_KEYS) do
        align = align + math.min(av[k], bv[k])
    end
    if clash > align and clash > 0.15 then return "opposed" end
    if a.name == b.name or align > 2 * clash then return "aligned" end
    if CREED_OPPOSES[a.name] == b.name then return "opposed" end
    return "neutral"
end

-- Political fallout ([A18]): members of two companies talk doctrine on
-- a slow per-pair clock. Aligned warms a little, opposed cools and
-- turns both faction stances wary in the two believers' eyes. Standing
-- only - politics chills the water; it never pulls a trigger itself.
local politickAt = {}

-- Are these two companies in feud? A settled fact on both metas.
function S.feudBetween(gA, gB)
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(gA)] or nil
    if not (meta ~= nil and meta.feudWith ~= nil
        and meta.feudWith[tostring(gB)] == true) then
        return false
    end
    -- Lazy lapse ([A21]): a feud with a DEAD company is a memory, not
    -- a standing fact - when the other side's meta is gone (roster
    -- emptied), the entry clears itself on first read.
    if not (s.groupMeta[tostring(gB)]) then
        meta.feudWith[tostring(gB)] = nil
        return false
    end
    return true
end

-- Compatibility entry points for the old trust-triggered treaty mutations.
-- An encounter and a score can motivate a proposal; neither can enact a pact
-- or peace for two absent rosters.
function S.tryPeace(idA, idB, gA, gB)
    return false, "explicit-process-required"
end

function S.politick(idA, idB, tick)
    local gA, gB = S.groupOf(idA), S.groupOf(idB)
    if not gA or not gB or tostring(gA) == tostring(gB) then return nil end
    -- A feud remains a live constraint until an explicit inter-group process
    -- changes it. Contact or repaired trust can motivate that process; neither
    -- silently lifts the recorded conflict.
    if S.feudBetween(gA, gB) then
        if S.tryPeace(idA, idB, gA, gB) then
            return "peace"
        end
        return "feud"
    end
    local a, b = tostring(idA), tostring(idB)
    local pairKey = (a < b) and (a .. "|" .. b) or (b .. "|" .. a)
    -- F-028: callers live on DIFFERENT tick counters (the controller's
    -- and the population layer's), so the cooldown runs on the one
    -- clock everyone shares - world age hours. Half an hour of world
    -- time between arguments; the tick param stays for API shape only.
    local okH, nowH = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return nil end
    if nowH - (politickAt[pairKey] or -1e9) < 0.5 then return nil end
    politickAt[pairKey] = nowH
    local verdict = S.creedClash(gA, gB)
    if verdict == "aligned" then
        S.adjustTrust(idA, idB, 0.05)
        S.adjustTrust(idB, idA, 0.05)
    elseif verdict == "opposed" then
        local tAB = S.adjustTrust(idA, idB, -0.08)
        local tBA = S.adjustTrust(idB, idA, -0.08)
        if SAO.Perception and SAO.Perception.setFactionStance then
            pcall(function()
                SAO.Perception.setFactionStance(idA, gB, "wary")
                SAO.Perception.setFactionStance(idB, gA, "wary")
            end)
        end
        -- Words become weapons ([A20]): mutual collapse below -0.5
        -- through politics declares hostility - the spark is the
        -- accumulated arguments; what happens next happens under the
        -- combat lawbook that already exists.
        -- The short fuse ([A27]): each side crosses their OWN bar -
        -- an aggressive pairing ignites early, two meek people endure
        -- arguments that would have been a war under the flat law.
        local barA = SAO.Disposition and SAO.Disposition.hostilityBar
            and SAO.Disposition.hostilityBar(idA) or -0.5
        local barB = SAO.Disposition and SAO.Disposition.hostilityBar
            and SAO.Disposition.hostilityBar(idB) or -0.5
        if tAB < barA and tBA < barB
            and not (S.isHostileTo(idA, idB) or S.isHostileTo(idB, idA)) then
            S.setHostile(idA, idB, true)
            S.setHostile(idB, idA, true)
            verdict = "hostile"
        end
    end
    return verdict
end

-- Key migration ([A19]): everything standing knows under oldKey moves
-- under newKey - outbound relations (merged; existing newKey facts
-- win), inbound relations from every other holder, group membership,
-- personal claim, and leadership references. Used by the Knox
-- adoption shim; safe to call repeatedly (no-ops once oldKey is bare).
function S.migrateKey(oldKey, newKey)
    local s = store(); if not s then return false end
    oldKey, newKey = tostring(oldKey), tostring(newKey)
    if oldKey == newKey then return false end
    local moved = false
    local mine = s.relations[oldKey]
    if mine then
        s.relations[newKey] = s.relations[newKey] or {}
        for otherKey, r in pairs(mine) do
            if s.relations[newKey][otherKey] == nil then
                s.relations[newKey][otherKey] = r
            end
        end
        s.relations[oldKey] = nil
        moved = true
    end
    for holder, rels in pairs(s.relations) do
        local r = rels[oldKey]
        if r then
            if rels[newKey] == nil then rels[newKey] = r end
            rels[oldKey] = nil
            moved = true
        end
    end
    if s.groups[oldKey] then
        if not s.groups[newKey] then s.groups[newKey] = s.groups[oldKey] end
        s.groups[oldKey] = nil
        moved = true
    end
    if s.claims[oldKey] then
        if not s.claims[newKey] then s.claims[newKey] = s.claims[oldKey] end
        s.claims[oldKey] = nil
        moved = true
    end
    for _, meta in pairs(s.groupMeta or {}) do
        if meta.leaderId == oldKey then
            meta.leaderId = newKey
            moved = true
        end
    end
    return moved
end

-- Hostility is evidence a person may use in a withdrawal proposal; it no
-- longer moves rosters, creates a faction, or declares a feud by score.
function S.checkSchism(_groupName)
    return nil, nil, 0, "explicit-process-required"
end

-- The community's standing answer to who eats first, or nil below the
-- scale where the question formalizes ([A26]).
-- The shape of a company ([A26]): what share of the house works
-- which trade - read from designations, the county's own job claims.
function S.groupShape(groupName)
    local s = store(); if not s then return nil end
    local n, forage, watch = 0, 0, 0
    for id, g in pairs(s.groups or {}) do
        if g == groupName then
            n = n + 1
            local rec = SAO.Identity and SAO.Identity.get(id) or nil
            -- [B24] "forager", not "forage". This one character held
            -- `forageShare` at zero for the whole life of the
            -- project, which made `tryPact`'s complement check
            -- permanently false - so no pact ever formed, and every
            -- feature downstream of one was dead code.
            if rec and rec.designation == "forager" then
                forage = forage + 1
            elseif rec and rec.designation == "watch" then
                watch = watch + 1
            end
        end
    end
    if n == 0 then return nil end
    return { n = n, forageShare = forage / n, watchShare = watch / n }
end

-- The chair ([A27]): readers and the two verbs of consent.
function S.chairOfferOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return meta and meta.chairOffer or nil
end

function S.playerChairOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return meta and meta.playerChair or nil
end

-- The group a player key chairs, or nil.
function S.groupChairedBy(playerKey)
    local s = store(); if not s then return nil end
    for g, meta in pairs(s.groupMeta or {}) do
        if meta.playerChair == tostring(playerKey) then return g end
    end
    return nil
end

function S.acceptChair(groupName, playerKey)
    return false, "explicit-process-required"
end

function S.declineChair(groupName)
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if not meta then return false end
    local wasOffer = meta.chairOffer
    meta.chairOffer = nil
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    meta.chairDeclinedAt = okH and h or 0
    s.groupMeta[tostring(groupName)] = meta
    -- [C105] The refusal is the response half of the chair claim.
    if SAO.Recognition and wasOffer then
        SAO.Recognition.onChairDeclined(tostring(groupName), wasOffer)
    end
    return true
end

-- "If I turn, you do it" is a concrete addressed proposal. The old path
-- wrote the hearer into `promises` at the instant the bitten person spoke,
-- which converted hearing into assent. The compatibility projection below
-- is written only after the hearer's delivered acceptance; Organization owns
-- the durable response, scope and responsibility.
function S.recordPromise(bittenId, keeperId)
    bittenId, keeperId = tostring(bittenId or ""), tostring(keeperId or "")
    local s = store()
    if not s or bittenId == "" or keeperId == ""
        or not (SAO.Organization and SAO.Communication)
        or SAO.Communication.canConverse(bittenId, keeperId) ~= true then
        return nil, "not-delivered"
    end
    local process = SAO.Organization.raiseMatter(bittenId, "promise",
        S.groupOf(bittenId), {
            action = "mercy-if-turned", recipientId = keeperId,
            requiredCapabilities = { execute = true },
            scope = { responsibility = "mercy-if-turned",
                personId = bittenId },
        }, { keeperId }, { source = "spoken-promise-request" })
    if not process or not SAO.Organization.recordReception(process.id,
        keeperId, process.revision, "spoken", bittenId,
        { actualRecipient = true }) then return process, "not-delivered" end
    local rec = SAO.Identity and SAO.Identity.get(keeperId) or nil
    local snapshot = SAO.Communication.actorSnapshot(keeperId) or {}
    local activity = snapshot.currentActivity or "dormant"
    local trust, hostile, nerve = S.trust(keeperId, bittenId), false, 0.5
    pcall(function()
        hostile = S.isHostileTo(keeperId, bittenId) == true
        nerve = SAO.Disposition.traits(keeperId).nerve or nerve
    end)
    local choice = hostile and "contest"
        or (activity ~= "idle" and activity ~= "dormant") and "defer"
        or (rec and not rec.dead and nerve >= 0.45 and trust >= 0.15)
            and "accept"
        or "decline"
    local response = SAO.Organization.appraiseMatter(process.id, keeperId, {
        owner = "Standing.recordPromise", executor = "SAO.Standing",
        currentActivity = activity, relationship = trust,
        canExecute = rec ~= nil and rec.dead ~= true,
        incapable = rec == nil or rec.dead == true,
        contest = hostile, choice = choice,
        interests = { nerve = nerve },
        constraints = { actualRecipient = true },
    })
    if not response or not SAO.Organization.deliverResponse(process.id,
        keeperId, bittenId, "spoken", { actualRecipient = true }) then
        return process, response
    end
    if response.response == "accept" then
        local commitment = nil
        for _, candidate in pairs(process.commitments or {}) do
            if candidate.actorId == keeperId
                and candidate.revision == process.revision then
                commitment = candidate
                break
            end
        end
        s.promises = s.promises or {}
        s.promises[bittenId] = { keeperId = keeperId,
            processId = process.id,
            commitmentId = commitment and commitment.id or nil }
    end
    return process, response
end

function S.promiseKeeperOf(bittenId)
    local s = store(); if not s then return nil end
    local promise = s.promises and s.promises[tostring(bittenId)] or nil
    return type(promise) == "table" and promise.keeperId or promise
end

function S.promiseCommitmentOf(bittenId)
    local s = store(); if not s then return nil end
    local promise = s.promises and s.promises[tostring(bittenId)] or nil
    return type(promise) == "table" and promise.commitmentId or nil
end

function S.clearPromise(bittenId)
    local s = store(); if not s then return end
    if s.promises then s.promises[tostring(bittenId)] = nil end
end

-- The felt clock ([A28]): a house LEARNS how long each kind of
-- errand takes by watching its people come back. Rolling average per
-- venture kind, claims not constants.
function S.noteVentureReturn(groupName, kind, hours)
    if not groupName or not kind or not hours or hours <= 0 then return end
    local s = store(); if not s then return end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    meta.ventures = meta.ventures or {}
    local v = meta.ventures[kind] or { avgHours = hours, n = 0 }
    v.avgHours = (v.avgHours * v.n + hours) / (v.n + 1)
    v.n = math.min(v.n + 1, 20)
    meta.ventures[kind] = v
    s.groupMeta[tostring(groupName)] = meta
end

function S.ventureExpectation(groupName, kind)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local v = meta and meta.ventures and meta.ventures[kind] or nil
    return v and v.avgHours or nil
end

-- The motor pool ([B1]): what the house KNOWS it can drive - read
-- from the real vehicles standing on its ground at the rounds, aging
-- honestly like the larder. A house with no cars knows it has none.
function S.setMotorPool(groupName, cars)
    local s = store(); if not s then return end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    meta.motorPool = { cars = cars, atHours = okH and h or 0 }
    s.groupMeta[tostring(groupName)] = meta
end

-- [B19] What the wheels are actually WORTH. Derived at read time
-- from the appraised pool and never stored as prose (claims, not
-- chapters): a car with a dead engine and an empty tank is
-- scenery, and a house that "has three cars" may have none it can
-- drive. Person-blind by design - whether THIS survivor can start
-- it is the Controller's question, because it depends on who they
-- are.
-- [C54] `loudCeiling` skips any car at or above it. The pool holds
-- more than one car and this function returned exactly one, so a goer
-- who refuses the car it picked walked - even with a quieter runner
-- in the same yard. The refusal is a real decision ([B19]: somebody
-- who learned that noise is a debt would rather take longer than
-- announce themselves) and it should choose the next car, not discard
-- the pool. Passing nothing keeps the old answer, so the panel's
-- reading of what the house can drive is unchanged.
function S.roadworthy(groupName, loudCeiling)
    local m = S.motorPoolOf(groupName)
    if not (m and m.cars) then return nil end
    local best = nil
    for _, c in ipairs(m.cars) do
        local runs = (c.fuel or 0) > 5 and (c.engine or 0) > 20
        if runs and loudCeiling and (c.loud or 0) >= loudCeiling then
            runs = false
        end
        if runs then
            -- [C122] A car the appraiser holds the key for claims
            -- like one with keys dangling - the engine's own holder
            -- read, and the ring mods' vacuums are recursed by the
            -- engine's own read, not by us. The driver's own pocket
            -- is still the truth at the start; this is the pool's
            -- preference, not its permission.
            local open = (c.ignition or 0) == 1
                or (c.hotwired or 0) == 1
                or (c.key or 0) == 1
            local better = false
            if not best then
                better = true
            elseif open and not best.open then
                better = true
            elseif open == best.open
                and (c.free or 0) > (best.free or 0) then
                better = true
            end
            if better then
                best = {
                    name = c.name, seats = c.seats, free = c.free,
                    loud = c.loud, storage = c.storage,
                    fuel = c.fuel, open = open,
                }
            end
        end
    end
    return best
end

function S.motorPoolOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local m = meta and meta.motorPool or nil
    if not m then return nil end
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    if okH and h - (m.atHours or 0) > 48 then return nil end
    return m
end

-- The larder ([A28]): a claim READ from the real shelves at the
-- quartermaster's rounds - never asserted, and honest about age:
-- consumers treat claims older than 48 hours as no claim at all.
-- The warm house ([B6]): whether this house keeps a fire burning,
-- noted at the rounds and aged like every other read claim.
function S.setHearth(groupName, burning)
    if not materialEnabled() then return false end
    local s = store(); if not s then return end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    meta.hearth = { burning = burning and true or false,
        atHours = okH and h or 0 }
    s.groupMeta[tostring(groupName)] = meta
    return true
end

function S.hearthOf(groupName)
    if not materialEnabled() then return nil end
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local rec = meta and meta.hearth or nil
    if not rec or type(rec.burning) ~= "boolean" then return nil end
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    if okH and h - (rec.atHours or 0) > 48 then return nil end
    return rec
end

-- The water claim ([B6]): what the house knows it has to drink -
-- read at the same rounds as the shelves, aged the same way.
function S.setWaterStore(groupName, word, units, basis, evidence)
    if not completeMaterialClaimAllowed(basis, evidence) then return false end
    local s = store(); if not s then return false end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local atHours, resultOrder, reservationId, sourceId, materialGeneration =
        materialEvidence(evidence)
    if materialEvidenceSuperseded(meta.waterStore, basis, atHours, resultOrder,
        materialGeneration) then
        return true
    end
    meta.waterStore = { word = word, units = units,
        basis = tostring(basis or "unspecified"),
        atHours = atHours, resultOrder = resultOrder,
        reservationId = reservationId, sourceId = sourceId,
        materialGeneration = materialGeneration }
    s.groupMeta[tostring(groupName)] = meta
    return true
end

function S.waterStoreOf(groupName)
    if not materialEnabled() then return nil end
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local w = meta and meta.waterStore or nil
    if not w then return nil end
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    if okH and h - (w.atHours or 0) > 48 then return nil end
    return w
end

function S.setLarder(groupName, word, count, basis, evidence)
    if not completeMaterialClaimAllowed(basis, evidence) then return false end
    local s = store(); if not s then return false end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local atHours, resultOrder, reservationId, sourceId, materialGeneration =
        materialEvidence(evidence)
    if materialEvidenceSuperseded(meta.larder, basis, atHours, resultOrder,
        materialGeneration) then
        return true
    end
    meta.larder = { word = word, count = count,
        basis = tostring(basis or "unspecified"),
        atHours = atHours, resultOrder = resultOrder,
        reservationId = reservationId, sourceId = sourceId,
        materialGeneration = materialGeneration }
    s.groupMeta[tostring(groupName)] = meta
    return true
end

function S.larderOf(groupName)
    if not materialEnabled() then return nil end
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local l = meta and meta.larder or nil
    if not l then return nil end
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    if okH and h - (l.atHours or 0) > 48 then return nil end
    return l
end

-- First pact partner of a group, or nil ([A26]).
function S.pactPartnerOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if meta and meta.pactWith then
        for og, v in pairs(meta.pactWith) do
            if v == true then return og end
        end
    end
    return nil
end

function S.pactBetween(gA, gB)
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(gA)] or nil
    return (meta and meta.pactWith
        and meta.pactWith[tostring(gB)]) == true
end

function S.tryPact(idA, idB, gA, gB)
    return false, "explicit-process-required"
end

-- The county hears you ([A26]): a player voice on the wire reaches
-- every company that keeps a watch (the watch keeps the radio). Trust
-- warms a little - a voice on the air is a neighbor, not a stranger -
-- capped at once per game hour; the house remembers hearing you
-- (heardOnAir, feeding Talk); and the wire acknowledges a new voice
-- in its next bulletin, once a day at most.
-- Does this survivor actually possess a receiver? Nothing conjured
-- ([A27]): a LOADED body is scanned for a real device item; an
-- dormant body answers from its validated native manifest. A never-met
-- person owns nothing yet and hears nothing; reach
-- crystallizes with lives, like every possession.
-- [B27] `body` is optional and exists for one reason: the player
-- owns a radio the same way a survivor does - by carrying one - but
-- SAO.Body.get resolves survivors only. The TEST is unchanged; the
-- caller may just supply the body it already has. Shared code stays
-- free of client globals this way.
function S.ownsRadio(id, body)
    body = body or (SAO.Body and SAO.Body.get and SAO.Body.get(id) or nil)
    if body then
        local found = false
        pcall(function()
            local items = SAOJavaBridge:privateCarriedItems(body)
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                -- [B42] ASK before calling. `getDeviceData` is declared
                -- on `zombie.inventory.types.Radio`, not on
                -- `InventoryItem`, so this threw on every ordinary thing
                -- a survivor was carrying - once per item, every time
                -- anyone asked whether they owned a radio. [B42] fixed
                -- the same call in SAO_RadioEar; this was the other half
                -- of the population, and Border 38 is what found it.
                --
                -- The type test below stays: a television is also a
                -- Radio to the engine, and it is not a radio to us.
                local dd = nil
                if instanceof(it, "Radio") then
                    local okD
                    okD, dd = pcall(function()
                        return it:getDeviceData()
                    end)
                    if not okD then dd = nil end
                end
                if dd and SAOJavaBridge:privateItemIsRadio(it) then
                    found = true
                    break
                end
            end
        end)
        return found
    end
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    if not rec then return false end
    if not SAOJavaBridge or rec.hibernation == nil then return false end
    local ok, has = pcall(function()
        return SAOJavaBridge:privateDormantHasRadio(rec.hibernation)
    end)
    return ok and has == true
end

function S.beginRadioBroadcast(sourceId, kind)
    local s = store(); if not s then return nil end
    if type(sourceId) ~= "string" or sourceId == "" then return nil end
    local okH, now = pcall(function() return SAO.History.countyHours() end)
    if not okH or type(now) ~= "number" or now ~= now or now < 0
        or now == math.huge or now == -math.huge then return nil end
    s.onAir = s.onAir or {}
    s.onAir.sequence = math.max(0, tonumber(s.onAir.sequence) or 0) + 1
    return "player-radio:" .. tostring(s.onAir.sequence) .. ":"
        .. tostring(kind or "voice"), now
end

function S.hearPlayerOnAir(playerKey, body, frequency)
    local s = store(); if not s then return end
    local okH, h = pcall(function()
        return SAO.History.countyHours()
    end)
    local now = okH and h or nil
    if type(now) ~= "number" or now ~= now or now < 0
        or now == math.huge or now == -math.huge then return false end
    frequency = tonumber(frequency)
    if not (SAO.Communication and SAO.Communication.radioTransmitterAccess
        and SAO.Communication.radioTransmitterAccess(
            playerKey, frequency, body)) then return false end
    s.onAir = s.onAir or {}
    if now - (s.onAir.lastHeardAt or -9) < 1 then return false end
    local broadcastId, broadcastAt = S.beginRadioBroadcast(playerKey, "voice")
    if not broadcastId then return false end
    now = broadcastAt
    s.onAir.lastHeardAt = now
    -- The transmission belongs only to the people whose current receivers
    -- admit it. Household membership is not an unperformed second telling.
    local heard = 0
    for _, rec in pairs((SAO.Identity and SAO.Identity.all
        and SAO.Identity.all()) or {}) do
        local received = false
        if not rec.dead and rec.id ~= playerKey
            and SAO.Communication and SAO.Communication.radioReception then
            received = SAO.Communication.radioReception(rec.id, broadcastId,
                frequency, now, { { kind = "onAir", speakerId = playerKey } },
                nil, playerKey) == true
        end
        if received then
            heard = heard + 1
            s.onAir.heardSolo = s.onAir.heardSolo or {}
            s.onAir.heardSolo[rec.id] = now
            S.adjustTrust(rec.id, playerKey, 0.02)
        end
    end
    if heard > 0 and now - (s.onAir.lastAckAt or -48) >= 24 then
        s.onAir.lastAckAt = now
        S.pushRadioNews({ kind = "onAir" })
    end
    return heard
end

-- Whether this survivor has received the player's transmission.
-- Death hygiene ([A27]): the dead leave the listener rolls.
-- [B51] `politickAt` is keyed by a PAIR - "a|b", sorted - so one
-- entry per pair of survivors who have ever argued doctrine, and
-- until now nothing ever removed one. A pair with a dead member can
-- never argue again, so the entry is read by nobody for the rest of
-- the session; the cost is quadratic in the county and the county's
-- dead are kept on purpose ([B51] measured the shape).
--
-- Scanning for the id is O(entries) and death is rare. A reverse
-- index would be faster and would be a second thing to keep true.
function S.forgetPolitics(id)
    local a = tostring(id)
    local doomed = {}
    for key in pairs(politickAt) do
        local left, right = string.match(key, "^([^|]+)|([^|]+)$")
        if left == a or right == a then
            doomed[#doomed + 1] = key
        end
    end
    for i = 1, #doomed do politickAt[doomed[i]] = nil end
    return #doomed
end

function S.forgetSoloListener(id)
    local s = store(); if not s then return end
    if s.onAir and s.onAir.heardSolo then
        s.onAir.heardSolo[id] = nil
    end
end

function S.heardPlayerOnAir(id)
    local s = store(); if not s then return false end
    return s.onAir and s.onAir.heardSolo
        and s.onAir.heardSolo[id] ~= nil or false
end

-- The county wire ([A26]): political events append themselves here as
-- CLAIMS (ids and kinds, never prose); the radio channel renders and
-- airs them. Capped - the wire reports news, not archives.
function S.pushRadioNews(item)
    local s = store(); if not s then return end
    s.radioNews = s.radioNews or {}
    s.radioNews[#s.radioNews + 1] = item
    while #s.radioNews > 24 do table.remove(s.radioNews, 1) end
end

function S.policyPreferenceOf(id)
    local pull = S.leansToward(id)
    return pull and RATION_PREFERENCE[pull] or nil
end

-- Does this member's own preference differ from their community's enacted or
-- preserved legacy policy? Difference can raise a matter; it cannot change
-- the policy or roster by itself.
function S.dissentsFromPolicy(id)
    local g = S.groupOf(id)
    if not g then return false end
    local policy = S.rationPolicyOf(g)
    if not policy then return false end
    local preferred = S.policyPreferenceOf(id)
    return preferred ~= nil and preferred ~= policy
end

-- The chronicle of a group's own governance, or {}.
function S.govHistoryOf(groupName)
    local s = store(); if not s then return {} end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return (meta and meta.govHistory) or {}
end

function S.rationPolicyOf(groupName)
    if not (groupName and SAO.Organization and SAO.Organization.decisions) then
        return nil
    end
    local decision = SAO.Organization.decisions[
        tostring(groupName) .. ":assembly:ration-policy"]
    local policy = decision and decision.decision or nil
    if policy == "watch-first" or policy == "weak-first"
        or policy == "house-first" or policy == "carry-light" then
        return policy
    end
    return nil
end

function S.groupOf(id)
    local s = store(); if not s then return nil end
    return s.groups[id]
end

-- SourceUse needs an attribution answer that distinguishes an ungrouped
-- person from an unavailable Standing store. It also reads membership and
-- held ground from one durable snapshot, so a transient lookup fault cannot
-- silently turn a house action into personal use.
function S.provisioningContextAt(id, x, y)
    local s = store()
    if not s then return nil, nil end
    local groupName = s.groups[id]
    if not groupName then return "personal", nil end
    local claim = s.groupClaims and s.groupClaims[tostring(groupName)] or nil
    x, y = tonumber(x), tonumber(y)
    if claim and x and y
        and x >= claim.minX and x <= claim.maxX
        and y >= claim.minY and y <= claim.maxY then
        return "held-group", tostring(groupName), claim.claimIncarnation
    end
    return "personal", nil
end

-- The result consumer must also distinguish a released claim from a failed
-- store read. A released/moved claim downgrades an old receipt to no-new-owner;
-- an unavailable store leaves the receipt pending for retry.
function S.provisioningClaimOf(groupName)
    local s = store()
    if not s or not groupName then return false, nil end
    return true, s.groupClaims and s.groupClaims[tostring(groupName)] or nil
end

-- All other members of this id's group (plain Lua ids; caller resolves
-- bodies). Empty table when ungrouped or alone.
-- Fellowship ends at death; the living remember, but the roster is of
-- the living.
-- [C71] Who is in a house, asked by the house's name.
--
-- `fellowsOf` below answers the same question through a member, which
-- is what every living caller has. A house whose only way in was one
-- of its members could not be reached about a member who had died:
-- [C68] takes a corpse off the roster at the moment of death, and it
-- is right to, so a dead person has no fellows by the time word of
-- their death is due.
--
-- The roster means LIVING membership, as it always has, so the dead
-- are filtered here rather than at each caller.
local function livingMembers(s, groupName)
    local out = {}
    for otherId, otherGroup in pairs(s.groups) do
        if otherGroup == groupName then
            local rec = SAO.Identity and SAO.Identity.get(otherId) or nil
            if not (rec and rec.dead) then
                out[#out + 1] = otherId
            end
        end
    end
    return out
end

-- Provisioning must distinguish an empty living roster from an unavailable
-- durable Standing store; the general reader retains its historical empty
-- fallback for callers that use absence as no fellows.
function S.provisioningMembers(groupName)
    local s = store(); if not s or not groupName then return nil end
    return livingMembers(s, groupName)
end

function S.membersOf(groupName)
    local s = store(); if not s or not groupName then return {} end
    return livingMembers(s, groupName)
end

function S.fellowsOf(id)
    local s = store(); if not s then return {} end
    local out = {}
    for _, otherId in ipairs(S.membersOf(s.groups[id])) do
        if otherId ~= id then out[#out + 1] = otherId end
    end
    return out
end

function S.sameGroup(id, otherId)
    local s = store(); if not s then return false end
    local g = s.groups[id]
    return g ~= nil and g == s.groups[otherId]
end

-- ---------------------------------------------------------------------------
-- Territory claims

-- [B34] What "this ground" actually covers.
--
-- Three sites used to invent three different squares around a pair of
-- feet: the player took 17x17, a survivor settling took 9x9, and
-- nobody had written down why the same act should mean three and a
-- half times as much ground for one of them. None of it derived from
-- anything - a claim made standing in a doorway put half the street
-- inside it.
--
-- A building knows its own bounds. Where there is one the claim IS
-- the house, exactly, and no two houses are the same size. Where
-- there is none - a field, a camp, a car park - a radius is the only
-- honest answer left, and the caller is told that is what it got, so
-- the one invented number in the system is never mistaken for a
-- measured one.
--
-- Returns minX, minY, maxX, maxY, kind - kind being "house" or "open".
function S.groundAround(body, x, y, radius)
    local r = tonumber(radius) or 4
    if body and SAOJavaBridge then
        local ok, packed = pcall(function()
            return SAOJavaBridge:buildingBoundsAt(body)
        end)
        if ok and type(packed) == "string" and packed ~= "" then
            local a, b, c, d = string.match(packed,
                "^(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)$")
            if a then
                return tonumber(a), tonumber(b), tonumber(c),
                    tonumber(d), "house"
            end
        end
    end
    return x - r, y - r, x + r, y + r, "open"
end

-- [B34] How wide a claim is, for anything that wants to say so.
function S.claimSpan(id)
    local c = S.claimOf(id)
    if not c then return nil end
    return (c.maxX - c.minX + 1), (c.maxY - c.minY + 1)
end

function S.claim(id, minX, minY, maxX, maxY, z)
    local s = store(); if not s then return false end
    s.claims[id] = { minX = minX, minY = minY, maxX = maxX, maxY = maxY, z = z or 0 }
    return true
end

-- [B34] Reshape a claim that already exists, by taking in one more
-- point. "Definable" is the operator's word and this is the verb
-- behind it: a house is the honest default, and a yard, a shed or a
-- stretch of fence is something you add by walking there and saying
-- so. Refuses when there is no claim to grow - founding is a
-- different act with a different meaning.
function S.growClaim(id, x, y, body)
    local s = store(); if not s then return false end
    local c = s.claims[id]
    if not c or not x or not y then return false end
    -- [B34] Take the WHOLE outbuilding, not the tile you stand on.
    -- A property is rarely one structure - a yard with two hen houses
    -- and a shed is four things and a fence - and absorbing a single
    -- pair of feet would stretch the boundary to reach the hen house
    -- without ever containing it. The same ruler that founded the
    -- claim measures what gets added to it.
    local aX, aY, bX, bY = x, y, x, y
    if body then
        local mnX, mnY, mxX, mxY, kind = S.groundAround(body, x, y, 0)
        if kind == "house" then
            aX, aY, bX, bY = mnX, mnY, mxX, mxY
        end
    end
    if aX < c.minX then c.minX = math.floor(aX) end
    if aY < c.minY then c.minY = math.floor(aY) end
    if bX > c.maxX then c.maxX = math.floor(bX) end
    if bY > c.maxY then c.maxY = math.floor(bY) end
    return true
end

-- The acquisition edges' reads of claim bounds.
function S.allPersonalClaims()
    local s = store(); if not s then return {} end
    return s.claims or {}
end

function S.claimOf(id)
    local s = store(); if not s then return nil end
    return s.claims[id]
end

function S.releaseClaim(id)
    local s = store(); if not s then return false end
    s.claims[id] = nil
    return true
end

function S.insideClaim(id, x, y)
    local s = store(); if not s then return false end
    local c = s.claims[id]
    if c ~= nil and x >= c.minX and x <= c.maxX and y >= c.minY and y <= c.maxY then
        return true
    end
    -- A member stands inside their group's claim as inside their own:
    -- the house is theirs to defend.
    local g = s.groups[id]
    local gc = g and s.groupClaims and s.groupClaims[g] or nil
    return gc ~= nil and x >= gc.minX and x <= gc.maxX
        and y >= gc.minY and y <= gc.maxY
end

-- Group claims (DR-006 S4): a faction's base is claimed by the GROUP -
-- one settled bounds fact per group name.
function S.setGroupClaim(groupName, minX, minY, maxX, maxY, z)
    local s = store(); if not s then return false end
    s.groupClaims = s.groupClaims or {}
    groupName = tostring(groupName)
    local prior = s.groupClaims[groupName]
    local changed = not prior or prior.minX ~= minX or prior.minY ~= minY
        or prior.maxX ~= maxX or prior.maxY ~= maxY
        or (prior.z or 0) ~= (z or 0)
    if prior and changed and SAO.Material and SAO.Material.forgetHouse then
        SAO.Material.forgetHouse(groupName)
    end
    if prior and changed then
        local meta = s.groupMeta and s.groupMeta[groupName] or nil
        if meta then
            meta.larder = nil
            meta.waterStore = nil
            meta.hearth = nil
        end
        if SAO.Settlement and SAO.Settlement.clearStorageProjection then
            SAO.Settlement.clearStorageProjection(groupName)
        end
    end
    local okH, h = pcall(function() return SAO.History.countyHours() end)
    local claimIncarnation = prior
        and tonumber(prior.claimIncarnation) or nil
    if changed or not claimIncarnation or claimIncarnation <= 0 then
        s.claimSequence = math.floor(tonumber(s.claimSequence) or 0) + 1
        claimIncarnation = s.claimSequence
    end
    s.groupClaims[groupName] = {
        minX = minX, minY = minY, maxX = maxX, maxY = maxY, z = z or 0,
        sinceHours = not changed and prior and prior.sinceHours
            or (okH and h or 0),
        claimIncarnation = claimIncarnation,
    }
    return true
end

-- The acquisition edge reads where claims ARE (like seeing a wall);
-- everything downstream must go through beliefs.
function S.allGroupClaims()
    local s = store(); if not s then return {} end
    return s.groupClaims or {}
end

function S.groupClaimOf(groupName)
    local s = store(); if not s then return nil end
    return s.groupClaims and s.groupClaims[tostring(groupName)] or nil
end

-- [C108] A group's places, ranked best-first. DERIVED, not stored
-- (DR-006 S4): what a place IS to a group comes from where its
-- living members actually go, so the ranking is recomputed from
-- `Perception.returnsOf` whenever any belief changes, and nothing
-- accumulates and nothing expires. The seat is unchanged -
-- `groupClaimOf` above still answers "where is the group" for every
-- reader that asks it; this answers "where does the group HOLD",
-- which is a different question exactly where holding several
-- changes the answer: trespass, the feud keep-out, and where a
-- venture brings things back to.
--
-- The cache is keyed on `Perception.beliefVersion`, so a derivation
-- is never served after the facts moved under it, and it costs one
-- walk per group per change rather than one walk per reader per call
-- ([C77]'s law).
local placesCache = {}
local function sameRoster(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end
function S.placesOf(groupName)
    if not groupName then return {} end
    groupName = tostring(groupName)
    local members = S.membersOf(groupName)
    -- Membership can change without any belief changing (a death, a
    -- join), so the roster is part of the cache's truth: the list
    -- recomputes when the members move, not only when their knowledge
    -- does. `pairs` order is not stable, so a shifted order recomputes
    -- too - a wasted walk, never a stale answer.
    local ver = (SAO.Perception and SAO.Perception.beliefVersion) or 0
    local c = placesCache[groupName]
    if c and c.version == ver and sameRoster(members, c.members) then
        return c.list
    end
    local list = {}
    if SAO.Perception and SAO.Perception.returnsOf then
        list = SAO.Perception.returnsOf(members) or {}
    end
    placesCache[groupName] = { version = ver, members = members,
        list = list }
    return list
end

-- [C108] Is this point inside group G's ground - ANY of its places,
-- each grown by `margin` (the feud keep-out passes its own shadow;
-- nil means the plain ground). One definition, so the two halves'
-- refusals cannot drift ([C25]).
--
-- The settled seat is tested first and always: it is the one rect
-- every reader already honoured, and a scouted settlement ([B52])
-- is chosen off the loaded ground, not derived from visits - so a
-- company's seat is theirs whether or not `learnBuilding` ever
-- recorded an arrival in it.
function S.onGroundOf(groupName, x, y, margin)
    if not (groupName and x and y) then return false end
    local m = margin or 0
    local c = S.groupClaimOf(groupName)
    if c and x >= c.minX - m and x <= c.maxX + m
        and y >= c.minY - m and y <= c.maxY + m then
        return true
    end
    for _, t in ipairs(S.placesOf(groupName)) do
        local pc = t.place
        if x >= pc.minX - m and x <= pc.maxX + m
            and y >= pc.minY - m and y <= pc.maxY + m then
            return true
        end
    end
    return false
end

-- [C117] The cast-out and the gather: a groupless person whose own
-- state says afflicted drifts, once a county day, toward the best
-- ground THEY have actually walked to that no living hand holds -
-- their own `returnsOf` ranking, minus every company's seat and
-- every other living person's claim (`claimedByOther`), minus what
-- they already hold (`insideClaim`, which is where they live). The
-- law is the settle pass's own ([C76]/[C108]): nothing is scored the
-- county did not already measure by walking, nothing is placed, and
-- a cast-out who has never gone back anywhere has no candidate and
-- keeps the ground they stand on - measure, then guide (DR-021).
--
-- The home they leave was theirs to keep ([A21]'s exile clause), and
-- leaving it is their own answer to the doors closing: the drift
-- reads only their own facts - groupless, mid-course, and the places
-- their own feet reached - never a badge and never a script. What
-- they abandon goes back to the county unclaimed. The GATHER is the
-- doors' own question and needs nothing here: outcasts who drift to
-- the same abandoned ground cross paths, and the road and the table
-- decide by the same `companyStanding` every other pair is decided
-- by - a house of outcasts is a county's own answer, not a category.
function S.outcastDrift()
    local s = store(); if not s then return false end
    if not (ZAO and ZAO.StateStore and ZAO.StateStore.read) then
        return false
    end
    if not (SAO.Perception and SAO.Perception.returnsOf) then
        return false
    end
    local moved = 0
    for id, rec in pairs(SAO.Identity.all()) do
        if not rec.dead and not s.groups[id] then
            local saved = ZAO.StateStore.read(id)
            local terminal = saved and saved.terminalState or nil
            if terminal == "afflicted" then
                local ranked = SAO.Perception.returnsOf({ id }) or {}
                for _, t in ipairs(ranked) do
                    local pc = t.place
                    if pc and pc.cx and pc.minX
                        and not S.claimedByOther(id, pc.cx, pc.cy)
                        and not S.insideClaim(id, pc.cx, pc.cy) then
                        local mnX, mnY, mxX, mxY =
                            S.groundAround(SAO.Body.get(id),
                                pc.cx, pc.cy, 4)
                        S.releaseClaim(id)
                        S.claim(id, mnX, mnY, mxX, mxY, 0)
                        rec.homeX, rec.homeY, rec.homeZ =
                            pc.cx, pc.cy, 0
                        -- Say WHY this ground and not another, the
                        -- settle pass's own law: the visits are the
                        -- person's own, and the claim is the county's
                        -- answer to who holds the rest.
                        log(id .. " takes the abandoned ground at "
                            .. tostring(pc.cx) .. "," .. tostring(pc.cy)
                            .. " - they had been back "
                            .. tostring(t.visits)
                            .. " time(s) and nobody holds it")
                        moved = moved + 1
                        break
                    end
                end
            end
        end
    end
    return moved > 0
end

-- Faction naming: a settled fact, once, at 3+ members. Deterministic from
-- the group's name hash - terse, never a story.
local FACTION_SUFFIX = { "Company", "Circle", "Crew", "House", "Watch" }
function S.factionName(groupName)
    local s = store(); if not s then return nil end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)]
    return meta and meta.factionName or nil
end

function S.nameFaction(groupName, region)
    local s = store(); if not s then return nil end
    groupName = tostring(groupName)
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[groupName] or {}
    if meta.factionName then return meta.factionName end
    local value = 5381
    for index = 1, #groupName do
        value = (value * 33 + string.byte(groupName, index)) % 4294967296
    end
    local suffix = FACTION_SUFFIX[(value % #FACTION_SUFFIX) + 1]
    meta.factionName = tostring(region or "Knox") .. " " .. suffix
    local okH, h = pcall(function() return SAO.History.countyHours() end)
    meta.namedAtHours = okH and h or 0
    s.groupMeta[groupName] = meta
    return meta.factionName
end

-- Bonds (S7): one settled fact on both relations - at most one bonded
-- partner per person, ever set through S.bond (which enforces it).
function S.bondedWith(id)
    local s = store(); if not s then return nil end
    local mine = s.relations[id]
    if not mine then return nil end
    for otherKey, r in pairs(mine) do
        if r.bonded == true then return otherKey end
    end
    return nil
end

function S.bond(id, otherId)
    local s = store(); if not s then return false end
    if S.bondedWith(id) or S.bondedWith(otherId) then return false end
    rel(s, id, otherId, true).bonded = true
    rel(s, otherId, id, true).bonded = true
    local okH, h = pcall(function() return SAO.History.countyHours() end)
    rel(s, id, otherId, false).bondedAtHours = okH and h or 0
    return true
end

-- Betrayal ends the fact on BOTH relations; history keeps only the
-- timestamp of when it was true.
function S.severBond(id, otherKey)
    local s = store(); if not s then return end
    local mine = rel(s, id, otherKey, false)
    if mine then mine.bonded = nil end
    local theirs = rel(s, otherKey, id, false)
    if theirs then theirs.bonded = nil end
end

function S.isBondedTo(id, otherKey)
    local s = store(); if not s then return false end
    local r = rel(s, id, otherKey, false)
    return r ~= nil and r.bonded == true
end

-- Player membership (S5): a settled fact per group - the player key the
-- faction counts as one of its own (member-guest).
function S.setPlayerMember(groupName, playerKey)
    local s = store(); if not s then return false end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    meta.playerMemberOf = tostring(playerKey)
    local okH, h = pcall(function() return SAO.History.countyHours() end)
    meta.playerSinceHours = okH and h or 0
    s.groupMeta[tostring(groupName)] = meta
    return true
end

function S.playerMemberOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return meta and meta.playerMemberOf or nil
end

-- [C106] The player leaving a house ends the member-guest fact with
-- the claim. Removal is explicit - never setPlayerMember(group, nil),
-- which would write the literal string "nil" and poison the reader
-- for every house that ever checked.
function S.clearPlayerMember(groupName, playerKey)
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if not meta or meta.playerMemberOf ~= tostring(playerKey) then
        return false
    end
    meta.playerMemberOf = nil
    s.groupMeta[tostring(groupName)] = meta
    return true
end

-- [C106] A chair who leaves the house leaves the chair with it - the
-- same fact the trust collapse unseats through, entered voluntarily.
-- The office itself is the [C105] bridge's to empty, not this side's.
function S.clearPlayerChair(groupName, playerKey)
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if not meta or meta.playerChair ~= tostring(playerKey) then
        return false
    end
    meta.playerChair = nil
    local okH, h = pcall(function() return SAO.History.countyHours() end)
    meta.govHistory = meta.govHistory or {}
    meta.govHistory[#meta.govHistory + 1] = {
        kind = "left", atHours = okH and h or 0,
    }
    s.groupMeta[tostring(groupName)] = meta
    S.pushRadioNews({ kind = "left", group = groupName })
    -- [C105] The office empties with the fact.
    if SAO.Recognition then
        SAO.Recognition.onChairWithdrawn(tostring(groupName),
            tostring(playerKey))
    end
    return true
end

-- Is this person key (survivor id or player key) counted inside this
-- group - member or accepted player?
function S.countsAsMember(groupName, key)
    local s = store(); if not s then return false end
    if s.groups[key] == tostring(groupName) then return true end
    return S.playerMemberOf(groupName) == tostring(key)
end

-- Is (x,y) inside anyone ELSE's claim? Returns the claimant id or nil.
-- The dead hold nothing: a claim lapses with its owner - the corpse's
-- house is an estate, not a fortress.
function S.claimedByOther(id, x, y)
    local s = store(); if not s then return nil end
    for owner, c in pairs(s.claims) do
        if owner ~= id and x >= c.minX and x <= c.maxX and y >= c.minY and y <= c.maxY then
            local rec = SAO.Identity and SAO.Identity.get(owner) or nil
            if not (rec and rec.dead) then
                return owner
            end
        end
    end
    -- Group claims: a non-member inside a faction's base is inside
    -- someone else's claim; the claimant answers as the group's leader
    -- (hostility toward the leader reads as hostility toward the house).
    local myGroup = s.groups[id]
    for groupName, c in pairs(s.groupClaims or {}) do
        if groupName ~= myGroup
            and not S.countsAsMember(groupName, id)
            and x >= c.minX and x <= c.maxX and y >= c.minY and y <= c.maxY then
            local leader = S.leaderOf(groupName)
            if leader then
                return leader
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Permission checks (the channel)

-- [C62] Permission to approach ground this person privately believes is
-- claimed. Perception supplies the believed owner; Standing alone answers
-- whether that belief permits entry. Own ground and ground with no believed
-- owner are enterable. A pact grants passage, a feud grants hostile entry,
-- and personal hostility permits the same break-in the live controller has
-- always permitted. Keeping this here makes the source-action executor ask
-- the same authority as every other live errand.
local function mayPassHolder(id, owner)
    if not owner then return true end
    local myGroup = S.groupOf(id)
    if myGroup then
        local otherGroup = S.groupOf(owner) or owner
        if otherGroup and S.pactBetween
            and S.pactBetween(myGroup, otherGroup) then
            return true
        end
        if otherGroup and S.feudBetween(myGroup, otherGroup) then
            return true
        end
    end
    return S.isHostileTo(id, owner) or S.isHostileTo(owner, id)
end

function S.mayEnterBelieved(id, x, y)
    if S.insideClaim(id, x, y) then return true end
    local owner = SAO.Perception and SAO.Perception.believesClaimed
        and SAO.Perception.believesClaimed(id, x, y) or nil
    return mayPassHolder(id, owner)
end

-- Standing owns the need exception as well as ordinary passage. Execution
-- supplies the admission already chosen by the need law; it never bypasses
-- this authority on its own.
function S.mayAttemptBelieved(id, x, y, admission)
    return tostring(admission or "standing") == "desperate"
        or S.mayEnterBelieved(id, x, y)
end

-- The final source-access check uses the county's current claim ledger. Private
-- belief is what motivated the trip; mutation authority is answered against
-- who actually holds the interaction square when the hand reaches it.
function S.mayEnterCurrent(id, x, y)
    return mayPassHolder(id, S.claimedByOther(id, x, y))
end


function S.mayTakeCurrent(id, x, y, admission)
    return tostring(admission or "standing") == "desperate"
        or S.mayEnterCurrent(id, x, y)
end

-- May this survivor engage that person? Requires standing hostility or the
-- target being hostile to it; group members are never permitted targets.
function S.mayEngagePerson(id, otherKey)
    if S.sameGroup(id, otherKey) then return false end
    return S.isHostileTo(id, otherKey) or S.isHostileTo(otherKey, id)
end

-- Zombies are always permitted targets; permission is about people.
function S.mayEngageZombie(id)
    return true
end

-- May it enter (x,y)? Own/unclaimed ground yes; someone else's claim only if
-- hostile relations already exist (a break-in is a hostile act, not a stroll).
function S.mayEnter(id, x, y)
    local other = S.claimedByOther(id, x, y)
    if not other then return true end
    return S.isHostileTo(id, other) or S.isHostileTo(other, id)
end

-- [C42] HAS THE FALL REACHED THIS COUNTY?
--
-- The question nothing was asking. The county wrote three stamps at
-- the moments that matter ([B1], [B3]) and read them only to print a
-- chronicle; not one decision consulted them, so a household in a
-- working world posted a sentry every night and people went looking
-- for a better weapon on an ordinary Tuesday. The switch on the
-- sandbox screen never fixed that, because a switch says how the
-- world STARTED and this asks what the county now knows.
--
-- Two ways it becomes true, and either is enough:
--
--   the calendar   the record's own day has come. A world that
--                  begins on or after the day the fall began is a
--                  fallen world from its first minute, whatever
--                  anybody here has personally seen ([C36] put the
--                  county on that calendar).
--   the county     somebody here saw it. A world that begins BEFORE
--                  that day is an ordinary county until its own
--                  first horror, which is exactly the day-zero
--                  start watching itself happen.
--
-- Derived from the record and never from the dial, so the answer is
-- the same whether a player checked the box or set the date by hand.
function S.fallHasCome()
    local s = store()
    if s and (s.outbreakAtHours or s.firstTurnedAtHours
        or s.tapsDryAtHours) then
        return true, "seen"
    end
    -- [C62] Through SAO_History, which is the one reader of the
    -- record's calendar and knows the day being lived while [C45]
    -- runs the years. Asking the bridge here read a stopped clock
    -- for the whole span.
    local day = nil
    pcall(function() day = SAO.History.recordDay() end)
    if type(day) == "number" and day >= 0 then
        return true, "calendar"
    end
    return false, (type(day) == "number") and "before" or "unknown"
end

-- [C38] The county's own stamps, for a reader that may not open the
-- store itself (the knowledge surface is read-only by law): the
-- first of them seen to kill, the first turning, the taps.
function S.chronicle()
    local s = store(); if not s then return nil end
    return { outbreakAtHours = s.outbreakAtHours,
             firstTurnedAtHours = s.firstTurnedAtHours,
             tapsDryAtHours = s.tapsDryAtHours }
end

function S.describe(id)
    local s = store(); if not s then return "no-store" end
    local nRel = 0
    for _ in pairs(s.relations[id] or {}) do nRel = nRel + 1 end
    return "standing: group=" .. tostring(s.groups[id])
        .. " relations=" .. nRel
        .. " claim=" .. tostring(s.claims[id] ~= nil)
end

return S
