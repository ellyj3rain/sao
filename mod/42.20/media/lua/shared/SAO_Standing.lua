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
local function store()
    local ok, s = pcall(function() return ModData.getOrCreate("SurvivorAwareness_Standing") end)
    if not ok or type(s) ~= "table" then return nil end
    s.relations = s.relations or {}   -- [id][otherKey] = { trust, hostile }
    s.groups = s.groups or {}         -- [id] = groupName
    s.claims = s.claims or {}         -- [id] = { minX, minY, maxX, maxY, z }
    return s
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
        return GameTime.getInstance():getWorldAgeHours()
    end)
    if okTS then r.atHours = hTS end
    return r.trust
end

function S.trust(id, otherKey)
    local s = store(); if not s then return 0 end
    local r = rel(s, id, otherKey, false)
    return r and r.trust or 0
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
        return GameTime.getInstance():getWorldAgeHours()
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
                return GameTime.getInstance():getWorldAgeHours()
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

-- Temperament gates company ([A27]): trust opens the door, the
-- circle decides whether to walk through. Loners refuse membership
-- outright; band-people refuse when the joined roster would exceed
-- their circle of three. Bonds are not groups - a loner's bond
-- stands.
function S.circleRefuses(id, groupName)
    local circle = SAO.Disposition and SAO.Disposition.circle
        and SAO.Disposition.circle(id) or "house"
    if circle == "loner" then return true end
    if circle == "band" then
        local s = store(); if not s then return false end
        local n = 1
        for _, g in pairs(s.groups or {}) do
            if g == tostring(groupName) then n = n + 1 end
        end
        return n > 3
    end
    return false
end

function S.joinGroup(id, groupName)
    local s = store(); if not s then return false end
    s.groups[id] = tostring(groupName)
    -- Membership changed: leadership settles again.
    S.electLeader(tostring(groupName))
    return true
end

-- Leaving is a verb ([A17]): membership ends, leadership reruns over
-- the remainder, and the leaver's own claims/home are untouched.
function S.leaveGroup(id)
    local s = store(); if not s then return false end
    local groupName = s.groups[id]
    if not groupName then return false end
    s.groups[id] = nil
    local lrec = SAO.Identity and SAO.Identity.get(id) or nil
    if lrec then lrec.designation = nil end
    S.electLeader(groupName)
    return true
end

-- ---------------------------------------------------------------------------
-- Governance (DR-006 S3): leadership is a settled standing fact - who the
-- group defers to - derived from trust-sums among LIVING members, stored
-- as group metadata, recomputed on membership and trust shifts. Claims-
-- first: no narrative, one fact with a timestamp.

function S.leaderOf(groupName)
    local s = store(); if not s then return nil end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)]
    return meta and meta.leaderId or nil
end

-- Trust-sum election: each living member's standing is the sum of the
-- others' trust toward them. Highest defers to nobody; ties settle
-- lexically for determinism. Returns newLeaderId, oldLeaderId.
-- The four creeds, and which chafe against which ([A18]): rules
-- chafe the free (order vs road), gates chafe the open hand (wall vs
-- mercy). Opposition is structural, not a mood.
--
-- DECLARED HERE with the other creed constants rather than beside
-- `creedOf` where they read best: [B23]'s division block lives inside
-- `electLeader` five hundred lines above, and a Lua local is
-- invisible to any function compiled before it. Sitting lower, this
-- resolved to a nil global - which the [B23] border caught on the
-- first run of this very batch.
local CREED_KEYS = { "order", "mercy", "wall", "road" }
local CREED_OPPOSES = { order = "road", road = "order",
                        wall = "mercy", mercy = "wall" }

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

function S.electLeader(groupName)
    local s = store(); if not s then return nil, nil end
    groupName = tostring(groupName)
    s.groupMeta = s.groupMeta or {}
    local members = {}
    for id, g in pairs(s.groups) do
        if g == groupName then
            local rec = SAO.Identity and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then
                members[#members + 1] = id
            end
        end
    end
    if #members == 0 then
        -- The roster emptied: the faction is DONE. Meta, name, claim,
        -- and player membership all lapse together; only the ghost of
        -- its base in old heads remains ([A15] beliefs, deliberately).
        s.groupMeta[groupName] = nil
        if s.groupClaims then s.groupClaims[groupName] = nil end
        return nil, nil
    end
    if #members == 1 then
        -- The widow of a company ([A15]): a group of one is a memory,
        -- not a membership. The last member is RELEASED - free to keep
        -- company again - and keeps the house: the group claim becomes
        -- their personal claim before it lapses.
        local widow = members[1]
        local gc = s.groupClaims and s.groupClaims[groupName] or nil
        if gc then
            s.claims[widow] = { minX = gc.minX, minY = gc.minY,
                maxX = gc.maxX, maxY = gc.maxY, z = gc.z or 0 }
            s.groupClaims[groupName] = nil
        end
        s.groups[widow] = nil
        s.groupMeta[groupName] = nil
        local wrec = SAO.Identity and SAO.Identity.get(widow) or nil
        if wrec then
            wrec.designation = nil
            wrec.designatedBy = nil
        end
        return nil, nil
    end
    table.sort(members)
    local bestId, bestSum
    for _, id in ipairs(members) do
        local sum = 0
        for _, otherId in ipairs(members) do
            if otherId ~= id then
                sum = sum + S.trust(otherId, id)
            end
        end
        if not bestSum or sum > bestSum then
            bestId, bestSum = id, sum
        end
    end
    -- The company has jobs (DR-011, [A18]): a designation per member,
    -- dealt from who they were. The leader leads; the rest work their
    -- class. Solo lives stay undesignated - that is a different day,
    -- and the controller renders it honestly.
    for _, mid in ipairs(members) do
        local mrec = SAO.Identity and SAO.Identity.get(mid) or nil
        if mrec then
            if mid == bestId then
                mrec.designation = "leads"
            elseif mrec.designatedBy ~= "chair" then
                -- The chair's assignments survive elections ([A27]):
                -- the steward deals work only to the undealt.
                local cls = (SAO.Census and SAO.Census.classOf)
                    and SAO.Census.classOf(mrec.occupation) or nil
                mrec.designation = (cls == "hardened" and "watch")
                    or (cls == "outdoors" and "scout")
                    or (cls == "carer" and "medic")
                    or (cls == "settled" and "quartermaster")
                    or "forager"
                -- The deal follows the best hand ([B2]): the class
                -- prior yields when this member's OWN skill for
                -- another job beats their skill for the dealt one by
                -- 3+ - the house hands the rifle to whoever can
                -- shoot. Quartermaster has no honest perk (organized
                -- is a trait, not a skill) - the class prior stands.
                if SAO.Census.skillOf then
                    -- [B20] The shared table - see Census.JOB_PERK.
                    local JOB_PERK = SAO.Census.JOB_PERK or {}
                    local dealt = mrec.designation
                    local dealtPerk = JOB_PERK[dealt]
                    local dealtLvl = dealtPerk
                        and SAO.Census.skillOf(mid, dealtPerk) or 0
                    if dealtLvl < 0 then dealtLvl = 0 end
                    local bestJob, bestLvl = nil, dealtLvl
                    for job, perk in pairs(JOB_PERK) do
                        if job ~= dealt then
                            local lvl = SAO.Census.skillOf(mid, perk)
                            if lvl and lvl >= bestLvl + 3 then
                                bestJob, bestLvl = job, lvl
                            end
                        end
                    end
                    if bestJob then
                        mrec.designation = bestJob
                        log(mid .. " takes the " .. bestJob
                            .. " work - best hands for it ("
                            .. bestLvl .. ")")
                    end
                end
            end
        end
    end
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
                return GameTime.getInstance():getWorldAgeHours()
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
                    -- [B25] The quartermaster IS judgeable, and [B25]
                    -- was wrong to say otherwise. All three of the
                    -- house's counts - larder, water, hearth - are
                    -- made in their branch and nowhere else. Those
                    -- counts are what [B23] reads for council or
                    -- flight, [B23] for the ask, [A26] for the
                    -- ration policy and [B13] to fill a gap. They are
                    -- the house's eyes on its own supplies.
                    --
                    -- The failure is a STALE count: all three age out
                    -- at 48 hours, so a claim that exists and has
                    -- expired means the rounds stopped. A claim that
                    -- never existed is NOT counted against them - a
                    -- house that just formed has given nobody time.
                    --
                    -- And it separates bad work from a bad world,
                    -- which is [B21]'s whole standard: an empty world
                    -- still gets counted, as lean, as dry, as dark.
                    -- Only an absent quartermaster leaves no count.
                    local okQH, qh = pcall(function()
                        return GameTime.getInstance():getWorldAgeHours()
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
                    else
                        evidence = -1
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
    -- The political economy of scale ([A26]): a COMMUNITY (8+) must
    -- answer who eats first, and the answer comes from what the house
    -- believes - order feeds the watch, mercy feeds the weakest, wall
    -- feeds the house and no one else, road keeps every pack light.
    -- Below 8 the question never formalizes (a band shares personally)
    -- and any standing policy lapses. DISSENT is material: members
    -- whose own class-creed conflicts with the policy lose a little
    -- faith in the chair at every election - logistics feeding the
    -- same trust, election, and schism machinery as everything else.
    s.groupMeta = s.groupMeta or {}
    do
        local meta0 = s.groupMeta[groupName] or {}
        if #members >= 8 then
            -- [B23] Settled, not live - the policy follows what the
            -- house has actually turned into.
            local creedName0 = S.creedNameOf(groupName)
            local policy = creedName0 and ({ order = "watch-first",
                mercy = "weak-first", wall = "house-first",
                road = "carry-light" })[creedName0] or nil
            if policy and meta0.rationPolicy ~= policy then
                meta0.rationPolicy = policy
                -- Governance leaves traces: the change is chronicled
                -- so a returning player DISCOVERS what the house
                -- decided in their absence.
                meta0.govHistory = meta0.govHistory or {}
                local okGH, gh = pcall(function()
                    return GameTime.getInstance():getWorldAgeHours()
                end)
                meta0.govHistory[#meta0.govHistory + 1] = {
                    kind = "policy", policy = policy,
                    atHours = okGH and gh or 0,
                }
                s.groupMeta[groupName] = meta0
                S.pushRadioNews({ kind = "policy", group = groupName,
                    policy = policy })
            end
            local OPPOSED_POLICY = {
                ["watch-first"] = "carer", ["house-first"] = "carer",
                ["weak-first"] = "hardened",
            }
            local dissentClass = policy and OPPOSED_POLICY[policy] or nil
            if dissentClass then
                local lead0 = meta0.leaderId
                for _, mid in ipairs(members) do
                    if mid ~= lead0 then
                        local mrec0 = SAO.Identity and SAO.Identity.get(mid)
                        local cls0 = mrec0 and SAO.Census
                            and SAO.Census.classOf
                            and SAO.Census.classOf(mrec0.occupation) or nil
                        if cls0 == dissentClass and lead0 then
                            S.adjustTrust(mid, lead0, -0.02)
                        end
                    end
                end
            end
        elseif meta0.rationPolicy then
            meta0.rationPolicy = nil
            s.groupMeta[groupName] = meta0
        end
    end

    -- Doctrine colors the deal ([A24]): an ORDER company posts one
    -- more watch - the first forager stands to it. Rules and watches
    -- are what order means.
    local creed = S.creedOf(groupName)
    if creed and creed.name == "order" then
        for _, mid in ipairs(members) do
            local mrec = SAO.Identity and SAO.Identity.get(mid) or nil
            if mrec and mrec.designation == "forager" then
                mrec.designation = "watch"
                break
            end
        end
    end
    -- The house adapts ([B13]): work was dealt from who people ARE
    -- and never from what the house NEEDS. A company could hold a
    -- fevered member and no medic until somebody died. Now an unmet
    -- need pulls the best-suited person into the gap - skill first,
    -- class affinity as tiebreak - and only from people whose
    -- current job is not itself answering a need. One promotion per
    -- election: houses change a person at a time.
    do
        local have = {}
        for _, mid in ipairs(members) do
            local mr = SAO.Identity and SAO.Identity.get(mid) or nil
            if mr and mr.designation then have[mr.designation] = true end
        end
        local needJob = nil
        local hurt = false
        for _, mid in ipairs(members) do
            local mb = SAO.Body and SAO.Body.get and SAO.Body.get(mid)
            if mb and SAO.Needs then
                if (SAO.Needs.bleeding and SAO.Needs.bleeding(mb) > 0)
                    or (SAO.Needs.woundInfection
                        and SAO.Needs.woundInfection(mb) > 0) then
                    hurt = true
                    break
                end
            end
        end
        if hurt and not have.medic then
            needJob = "medic"
        elseif not have.forager then
            local lard = S.larderOf(groupName)
            local wat = S.waterStoreOf(groupName)
            local hear = S.hearthOf(groupName)
            if (lard and lard.word == "lean")
                or (wat and wat.word == "dry")
                or (hear and hear.burning == false) then
                needJob = "forager"
            end
        end
        if not needJob and not have.watch then
            for g2 in pairs(s.groupClaims or {}) do
                if g2 ~= groupName and S.feudBetween(groupName, g2) then
                    needJob = "watch"
                    break
                end
            end
        end
        if needJob then
            local NEED_PERK = { medic = "Doctor", forager = "Foraging",
                watch = "Aiming" }
            local ANSWERING = { medic = true, forager = true,
                watch = true, leads = true }
            local best, bestScore = nil, -1
            for _, mid in ipairs(members) do
                local mr = SAO.Identity and SAO.Identity.get(mid) or nil
                if mr and not ANSWERING[mr.designation]
                    and mr.designatedBy ~= "chair" then
                    local sk = SAO.Census and SAO.Census.skillOf
                        and SAO.Census.skillOf(mid, NEED_PERK[needJob]) or 0
                    if sk < 0 then sk = 0 end
                    local cls = SAO.Census and SAO.Census.classOf
                        and SAO.Census.classOf(mr.occupation) or nil
                    local affinity =
                        (needJob == "medic" and cls == "carer" and 2)
                        or (needJob == "forager" and cls == "outdoors" and 2)
                        or (needJob == "watch" and cls == "hardened" and 2)
                        or 0
                    local score = sk + affinity
                    if score > bestScore then
                        best, bestScore = mid, score
                    end
                end
            end
            if best then
                local brec = SAO.Identity.get(best)
                if brec then
                    brec.designation = needJob
                    log(best .. " takes up the " .. needJob
                        .. " work - the house needed one")
                    if SAO.Body and SAO.Body.get and SAO.Body.get(best) then
                        pcall(function()
                            SAO.Voice.onEvent(best, "stepUp")
                        end)
                    end
                end
            end
        end
    end

    -- The crowded walk out ([B8]): a member whose house has
    -- outgrown their wanted circle and whose faith in the chair has
    -- gone below neutral LEAVES, rather than souring forever. They
    -- keep their own ground and become a company of one - which is
    -- what a loner in a crowded house wanted all along. One per
    -- election: houses come apart a person at a time.
    do
        local metaW = s.groupMeta[groupName] or {}
        local leadW = metaW.leaderId
        if leadW and #members > 2 then
            for _, mid in ipairs(members) do
                if mid ~= leadW and SAO.Disposition
                    and SAO.Disposition.circleCap
                    and #members > SAO.Disposition.circleCap(mid)
                    and S.trust(mid, leadW) < 0 then
                    s.groups[mid] = nil
                    local wrecW = SAO.Identity and SAO.Identity.get
                        and SAO.Identity.get(mid) or nil
                    if wrecW then
                        wrecW.designation = nil
                        wrecW.designatedBy = nil
                    end
                    if SAO.Body and SAO.Body.get and SAO.Body.get(mid) then
                        pcall(function()
                            SAO.Voice.onEvent(mid, "walkOut")
                        end)
                    end
                    log(mid .. " walks out of " .. tostring(groupName)
                        .. " - too many people, too little faith")
                    break
                end
            end
        end
    end

    -- The council ([B7]): the house is already assembled here, and
    -- three FRESH counts can say one thing together - this ground is
    -- finished. Lean shelves, dry bottles, and a dark hearth is not
    -- a mood; it is the house's own arithmetic. The claim is
    -- released, the chronicle keeps it, and the settle machinery
    -- carries them - it has always known how to find a home; now
    -- there is nothing to go back to. Company-scale only: a pair
    -- moves without a council.
    if #members >= 4 then
        local lard8 = S.larderOf(groupName)
        local wat8 = S.waterStoreOf(groupName)
        local hear8 = S.hearthOf(groupName)
        if lard8 and wat8 and hear8
            and lard8.word == "lean" and wat8.word == "dry"
            and hear8.burning == false
            and s.groupClaims and s.groupClaims[groupName] then
            local metaA8 = s.groupMeta[groupName] or {}
            local okA8, hA8 = pcall(function()
                return GameTime.getInstance():getWorldAgeHours()
            end)
            -- [B42] WHERE they gave up. Every other kind in this
            -- history carries its subject - `creed` the creed, `form`
            -- the form, `policy` the policy, `schism` how many walked -
            -- and `abandon` carried a timestamp and nothing else, so
            -- the Chronicle could say a house gave up their ground and
            -- never which ground. Read off the claim before the line
            -- below clears it, because after that nothing in the world
            -- remembers it was theirs.
            local goneA8 = s.groupClaims[groupName]
            metaA8.govHistory = metaA8.govHistory or {}
            metaA8.govHistory[#metaA8.govHistory + 1] = {
                kind = "abandon", atHours = okA8 and hA8 or 0,
                atX = goneA8 and math.floor(
                    (goneA8.minX + goneA8.maxX) / 2) or nil,
                atY = goneA8 and math.floor(
                    (goneA8.minY + goneA8.maxY) / 2) or nil,
            }
            s.groupMeta[groupName] = metaA8
            s.groupClaims[groupName] = nil
            -- The counts that decided it are spent: the new ground
            -- will be counted on its own terms.
            metaA8.larder = nil
            metaA8.waterStore = nil
            metaA8.hearth = nil
            -- And NOBODY GOES BACK ([B7], the audit's other half):
            -- home fields still pointed at the dead ground, so dusk
            -- homing and dormant night-drift would have walked them
            -- home to the place they just gave up. Cleared - they
            -- have no home until they find one, and both homing
            -- paths already guard on its absence. The settle
            -- machinery re-homes the whole roster at arrival.
            for _, mid8 in ipairs(members) do
                local mrec8 = SAO.Identity and SAO.Identity.get
                    and SAO.Identity.get(mid8) or nil
                if mrec8 then
                    mrec8.homeX, mrec8.homeY, mrec8.homeZ = nil, nil, nil
                end
            end
            S.pushRadioNews({ kind = "abandon", group = groupName })
            -- The house says it out loud - whoever is standing there
            -- to hear it. Voice is client-side; the guard keeps the
            -- shared layer honest in any context.
            for _, mid8 in ipairs(members) do
                if SAO.Body and SAO.Body.get and SAO.Body.get(mid8) then
                    pcall(function()
                        SAO.Voice.onEvent(mid8, "abandon")
                    end)
                    break
                end
            end
            log("COUNCIL: " .. tostring(groupName)
                .. " gives up its ground - lean, dry, and dark")
        end
    end

    -- Housekeeping ([B5] discipline, applied here because every
    -- living house passes this table): the chronicles APPEND - policy
    -- turns, schisms, pacts, wars - and a long county would grow them
    -- without end inside a save. Trimmed oldest-first to the last 40
    -- entries each; the Chronicle reads the recent past, and the
    -- county's oldest griefs pass out of living memory the way they
    -- do among people. Group death still lapses the whole meta
    -- (verified: the roster-empty and widow branches nil it whole).
    do
        local metaH = s.groupMeta[groupName]
        if metaH then
            for _, field in ipairs({ "govHistory", "feudHistory" }) do
                local list = metaH[field]
                if type(list) == "table" then
                    while #list > 40 do table.remove(list, 1) end
                end
            end
        end
    end

    -- Crowding is politics ([A27]): a member whose wanted circle the
    -- roster exceeds loses a little faith in the face of the crowd -
    -- the leader - every election. The pressure resolves through the
    -- same election and schism machinery as everything else; nobody
    -- is ejected by a rule.
    do
        local metaK = s.groupMeta[groupName] or {}
        local leadK = metaK.leaderId
        if leadK and #members > 1 then
            for _, mid in ipairs(members) do
                if mid ~= leadK and SAO.Disposition
                    and SAO.Disposition.circleCap then
                    local cap = SAO.Disposition.circleCap(mid)
                    if #members > cap then
                        S.adjustTrust(mid, leadK,
                            SAO.Disposition.circle(mid) == "loner"
                            and -0.04 or -0.02)
                    end
                end
            end
        end
    end

    -- The chair ([A27]): a house whose members trust their player
    -- fellow past the peak OFFERS the chair - governance by the user
    -- is granted by the governed, never taken. A chaired house whose
    -- trust collapses takes the chair back at the same table.
    do
        local metaC = s.groupMeta[groupName] or {}
        local pKey = metaC.playerMemberOf
        if pKey then
            local sumC, nC = 0, 0
            for _, mid in ipairs(members) do
                sumC = sumC + S.trust(mid, pKey)
                nC = nC + 1
            end
            local avgC = nC > 0 and (sumC / nC) or 0
            local okCH, ch = pcall(function()
                return GameTime.getInstance():getWorldAgeHours()
            end)
            local nowC = okCH and ch or 0
            if metaC.playerChair then
                if avgC < 0.2 then
                    metaC.playerChair = nil
                    metaC.govHistory = metaC.govHistory or {}
                    metaC.govHistory[#metaC.govHistory + 1] = {
                        kind = "unseated", atHours = nowC,
                    }
                    S.pushRadioNews({ kind = "unseated",
                        group = groupName })
                end
            elseif not metaC.chairOffer
                and avgC > 0.55
                and nowC - (metaC.chairDeclinedAt or -1e9) > 48 then
                metaC.chairOffer = pKey
            end
            s.groupMeta[groupName] = metaC
        end
    end
    local meta = s.groupMeta[groupName] or {}
    local old = meta.leaderId
    if old ~= bestId then
        meta.leaderId = bestId
        local okH, h = pcall(function()
            return GameTime.getInstance():getWorldAgeHours()
        end)
        meta.sinceHours = okH and h or 0
        s.groupMeta[groupName] = meta
        S.pushRadioNews({ kind = "election", group = groupName,
            leader = bestId })
    end
    return bestId, old
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
        return GameTime.getInstance():getWorldAgeHours()
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
function S.callForBread(groupName)
    local s = store(); if not s then return false end
    if not groupName then return false end
    groupName = tostring(groupName)
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[groupName] or {}
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    local now = okH and h or 0
    -- A house does not spend all day saying it is hungry.
    if meta.askedAtHours and now - meta.askedAtHours < 72 then
        return false
    end
    meta.askedAtHours = now
    s.groupMeta[groupName] = meta
    S.pushRadioNews({ kind = "ask", group = groupName })
    return true
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
        return GameTime.getInstance():getWorldAgeHours()
    end)
    if not okH then return false end
    return (h - meta.askedAtHours) <= 96
end

-- [B23] The nearest house that has asked and that THIS house would
-- answer. Person-blind and price-blind: it decides who is heard, not
-- what anything is worth.
function S.nearestAsking(fromGroup)
    local s = store(); if not s then return nil end
    if not fromGroup then return nil end
    fromGroup = tostring(fromGroup)
    -- You answer out of surplus, never out of your own children's
    -- mouths.
    local mine = S.larderOf(fromGroup)
    if not (mine and mine.word == "full") then return nil end
    if not ANSWERS_ASK[S.creedNameOf(fromGroup) or ""] then return nil end
    local ourClaim = S.groupClaimOf(fromGroup)
    if not ourClaim then return nil end
    local best, bestD = nil, 1e18
    for g, meta in pairs(s.groupMeta or {}) do
        -- [B23] One definition of "is asking", shared with the
        -- Ledger. Two copies of the window is how the two surfaces
        -- would come to disagree about who is hungry.
        if g ~= fromGroup and S.isAsking(g)
            and not S.feudBetween(fromGroup, g) then
            local theirClaim = S.groupClaimOf(g)
            if theirClaim then
                local dx = ((theirClaim.minX + theirClaim.maxX) / 2)
                    - ((ourClaim.minX + ourClaim.maxX) / 2)
                local dy = ((theirClaim.minY + theirClaim.maxY) / 2)
                    - ((ourClaim.minY + ourClaim.maxY) / 2)
                local d2 = dx * dx + dy * dy
                if d2 < bestD then best, bestD = g, d2 end
            end
        end
    end
    return best
end

-- [B23] The option to say how it should be. INFLUENCE, not command:
-- the operator's ruling that meeting enough people should earn the
-- option to say how the house ought to be - so it is gated on
-- standing, and it takes only where the house's own shape allows.
--
-- It is a standing wish rather than a one-shot order, and it fades.
-- A house does not remember being lectured forever.
function S.urgeForm(groupName, playerKey, form)
    local s = store(); if not s then return false end
    if not (groupName and form) then return false end
    groupName = tostring(groupName)
    -- Only the two a person can actually ASK for. Nobody urges a
    -- house to split, and nobody urges away an empty larder.
    if form ~= "council" and form ~= "ladder" then return false end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[groupName] or {}
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    meta.urgedForm = form
    meta.urgedAtHours = okH and h or 0
    meta.urgedBy = playerKey
    s.groupMeta[groupName] = meta
    return true
end

function S.formOf(groupName)
    local s = store(); if not s then return "empty" end
    if not groupName then return "empty" end
    groupName = tostring(groupName)
    -- FLIGHT first, because it is terminal and it is not a form of
    -- government at all - it is what is left when nobody held. The
    -- same three counts [B7] reads before it gives up the ground.
    local lardF = S.larderOf(groupName)
    local watF = S.waterStoreOf(groupName)
    local hearF = S.hearthOf(groupName)
    if lardF and watF and hearF
        and lardF.word == "lean" and watF.word == "dry"
        and hearF.burning == false then
        return "flight"
    end
    local live = S.creedOf(groupName)
    local settled = S.creedNameOf(groupName)
    if not (live and settled) then return "empty" end
    local n = live.size or 0
    if n < 3 then return "empty" end
    -- DIVIDED: not two different creeds, two OPPOSED ones. The tree
    -- has said which oppose which since [A18] - rules chafe the free,
    -- gates chafe the open hand.
    -- [B25] The quarrel a house is ACTUALLY having. This used to
    -- compare the settled creed against its formal opposite - but
    -- [B24] made the settled creed baseline-relative while these
    -- components stayed raw, so the two can name different pairs. A
    -- house holding wall 4.5 against mercy 2.0, named `road` because
    -- road is what it has unusually much of, was checked for a
    -- road-versus-order split, found none, and called undivided.
    --
    -- So: find the opposed pair the house is genuinely contesting -
    -- the one whose WEAKER side is strongest, since that is the
    -- faction with enough followers to be a faction at all - rather
    -- than assuming the argument must involve the house's name.
    local mine, theirs, foe = 0, 0, nil
    do
        local bestFloor = -1
        for _, a in ipairs(CREED_KEYS) do
            local b = CREED_OPPOSES[a]
            local va = (live.comp and live.comp[a]) or 0
            local vb = (b and live.comp and live.comp[b]) or 0
            local floor = (va < vb) and va or vb
            if b and floor > bestFloor then
                bestFloor = floor
                if va >= vb then
                    mine, theirs, foe = va, vb, b
                else
                    mine, theirs, foe = vb, va, a
                end
            end
        end
    end
    -- [B25] The near-parity clause `(mine - theirs) < 1.5` is gone,
    -- and this is a correction rather than a tuning. The operator's
    -- conditions were "density, surplus enough to stay, and A MARGIN
    -- OF FOLLOWERS" - and `theirs >= 1.5` IS that margin. Requiring
    -- the two sides to be nearly EQUAL was something [B23] added on
    -- its own, and it meant a house of seven holding four for wall
    -- and three for mercy was not considered divided.
    --
    -- A faction does not need parity to split a house. [B23]'s schism
    -- leaves with "everyone who trusts the core more than the
    -- leader", which a determined minority can absolutely carry.
    if n >= 4 and foe and theirs >= 1.5 then
        -- Surplus enough to STAY. A house with nothing left does not
        -- hold a quarrel; people leave.
        local lard = S.larderOf(groupName)
        if not (lard and lard.word == "lean") then
            return "divided"
        end
    end
    -- [B23] A standing wish from someone with the house's ear. It is
    -- checked AFTER flight and division on purpose: you cannot talk a
    -- splitting house back together, and you cannot wish shelves
    -- full. It fades after a week of world time.
    local meta = s.groupMeta and s.groupMeta[groupName] or nil
    if meta and meta.urgedForm then
        local okU, hu = pcall(function()
            return GameTime.getInstance():getWorldAgeHours()
        end)
        local fresh = okU and (hu - (meta.urgedAtHours or 0)) <= 168
        if fresh then
            if meta.urgedForm == "ladder" then return "ladder" end
            if meta.urgedForm == "council" then
                local lardU = S.larderOf(groupName)
                -- Talk is still a luxury of surplus, whoever asked.
                if not (lardU and lardU.word == "lean") then
                    return "council"
                end
            end
        end
    end
    if STRUCTURED_CREED[settled] then return "ladder" end
    local lard2 = S.larderOf(groupName)
    if lard2 and lard2.word == "lean" then return "ladder" end
    return "council"
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
    local s = store(); if not s then return nil end
    if not groupName then return nil end
    groupName = tostring(groupName)
    -- [B23] A deputy belongs to the LADDER form. A divided house has
    -- no second because it has no single voice to be second to, and a
    -- council house does not want one.
    if S.formOf(groupName) ~= "ladder" then return nil end
    local members = {}
    for id, g in pairs(s.groups) do
        if tostring(g) == groupName then
            local rec = SAO.Identity and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then
                members[#members + 1] = id
            end
        end
    end
    -- A leader and one other person is not a hierarchy, it is two
    -- people.
    if #members < 3 then return nil end
    table.sort(members)
    local meta = s.groupMeta and s.groupMeta[groupName] or nil
    local lead = meta and meta.leaderId or nil
    local bestId, bestSum = nil, nil
    for _, id in ipairs(members) do
        if id ~= lead then
            local sum = 0
            for _, otherId in ipairs(members) do
                if otherId ~= id then
                    sum = sum + S.trust(otherId, id)
                end
            end
            if not bestSum or sum > bestSum then
                bestId, bestSum = id, sum
            end
        end
    end
    return bestId
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

-- Peace has a path ([A21]): a feud lifts when the two LEADERS meet
-- with mutual personal trust healed past 0.3 - the warm channels
-- (charity, barter, smoke shares, witnessed respect) still run during
-- a feud, so peace is EARNED person-to-person by the two people who
-- can end it. Returns true when the feud lifted.
-- Feud history ([A22]): the county remembers its wars - declaration
-- and peace timestamps on the meta of each side.
local function noteFeudEvent(s, gA, gB, field)
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    local at = okH and h or 0
    S.pushRadioNews({
        kind = (field == "declaredAtHours") and "feud" or "peace",
        a = tostring(gA), b = tostring(gB),
    })
    for _, pair in ipairs({ { gA, gB }, { gB, gA } }) do
        local meta = s.groupMeta[tostring(pair[1])] or {}
        meta.feudHistory = meta.feudHistory or {}
        local entry = nil
        for i = #meta.feudHistory, 1, -1 do
            if meta.feudHistory[i].other == tostring(pair[2])
                and not meta.feudHistory[i].liftedAtHours then
                entry = meta.feudHistory[i]
                break
            end
        end
        if field == "declaredAtHours" then
            if not entry then
                meta.feudHistory[#meta.feudHistory + 1] = {
                    other = tostring(pair[2]), declaredAtHours = at,
                }
            end
        elseif entry then
            entry.liftedAtHours = at
        end
        s.groupMeta[tostring(pair[1])] = meta
    end
end

function S.tryPeace(idA, idB, gA, gB)
    local s = store(); if not s then return false end
    if S.leaderOf(gA) ~= tostring(idA) or S.leaderOf(gB) ~= tostring(idB) then
        return false
    end
    if S.trust(idA, idB) <= 0.3 or S.trust(idB, idA) <= 0.3 then
        return false
    end
    local metaA = s.groupMeta[tostring(gA)]
    local metaB = s.groupMeta[tostring(gB)]
    if metaA and metaA.feudWith then metaA.feudWith[tostring(gB)] = nil end
    if metaB and metaB.feudWith then metaB.feudWith[tostring(gA)] = nil end
    noteFeudEvent(s, gA, gB, "liftedAtHours")
    return true
end

-- Hostile cross-pairs between two rosters (living members only) - the
-- evidence a feud declaration stands on.
local function hostileCrossPairs(s, gA, gB)
    local count = 0
    for idA, g in pairs(s.groups) do
        if tostring(g) == tostring(gA) then
            local recA = SAO.Identity and SAO.Identity.get(idA) or nil
            if not (recA and recA.dead) then
                for idB, g2 in pairs(s.groups) do
                    if tostring(g2) == tostring(gB) then
                        local recB = SAO.Identity and SAO.Identity.get(idB) or nil
                        if not (recB and recB.dead)
                            and (S.isHostileTo(idA, idB)
                                or S.isHostileTo(idB, idA)) then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count
end

function S.politick(idA, idB, tick)
    local gA, gB = S.groupOf(idA), S.groupOf(idB)
    if not gA or not gB or tostring(gA) == tostring(gB) then return nil end
    -- Feuding companies are done talking ([A20]) - unless the two
    -- who CAN end it meet with trust healed ([A21]): leaders whose
    -- mutual regard crossed 0.3 lift the feud on the spot.
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
        return GameTime.getInstance():getWorldAgeHours()
    end)
    if not okH then return nil end
    if nowH - (politickAt[pairKey] or -1e9) < 0.5 then return nil end
    politickAt[pairKey] = nowH
    local verdict = S.creedClash(gA, gB)
    if verdict == "aligned" then
        S.adjustTrust(idA, idB, 0.05)
        S.adjustTrust(idB, idA, 0.05)
        if S.tryPact(idA, idB, gA, gB) then
            return "pact"
        end
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
            -- Two hostile cross-pairs make it the COMPANIES' business:
            -- the feud settles on both metas, once.
            local s2 = store()
            if s2 and hostileCrossPairs(s2, gA, gB) >= 2 then
                s2.groupMeta = s2.groupMeta or {}
                local metaA = s2.groupMeta[tostring(gA)] or {}
                local metaB = s2.groupMeta[tostring(gB)] or {}
                metaA.feudWith = metaA.feudWith or {}
                metaB.feudWith = metaB.feudWith or {}
                if not metaA.feudWith[tostring(gB)] then
                    metaA.feudWith[tostring(gB)] = true
                    metaB.feudWith[tostring(gA)] = true
                    -- A feud between pact partners is BETRAYAL
                    -- ([A26]): the pact dies, the chronicle says so,
                    -- and the two leaders carry the extra wound.
                    if metaA.pactWith and metaA.pactWith[tostring(gB)] then
                        metaA.pactWith[tostring(gB)] = nil
                        if metaB.pactWith then
                            metaB.pactWith[tostring(gA)] = nil
                        end
                        local okBH, bh = pcall(function()
                            return GameTime.getInstance():getWorldAgeHours()
                        end)
                        local bAt = okBH and bh or 0
                        for _, pr in ipairs({ { metaA, gB }, { metaB, gA } }) do
                            pr[1].govHistory = pr[1].govHistory or {}
                            pr[1].govHistory[#pr[1].govHistory + 1] = {
                                kind = "pactBroke",
                                other = tostring(pr[2]), atHours = bAt,
                            }
                        end
                        if metaA.leaderId and metaB.leaderId then
                            S.adjustTrust(metaA.leaderId, metaB.leaderId, -0.2)
                            S.adjustTrust(metaB.leaderId, metaA.leaderId, -0.2)
                        end
                        S.pushRadioNews({ kind = "pactBroke",
                            a = tostring(gA), b = tostring(gB) })
                    end
                    s2.groupMeta[tostring(gA)] = metaA
                    s2.groupMeta[tostring(gB)] = metaB
                    noteFeudEvent(s2, gA, gB, "declaredAtHours")
                    verdict = "feud-declared"
                end
            end
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

-- Schism ([A22]): when a company holds INTERNAL mutual hostility, it
-- splits. The leader's bloc keeps the name and the ground; the
-- estranged core plus everyone trusting them more than the leader
-- leave and found their own company, at feud with the old house from
-- the first breath - the split is the declaration. Returns the new
-- group name, or nil when the house stands. Never called from inside
-- electLeader (the callers are meeting-time seams); leaveGroup/join
-- re-elections inside are recursion-safe because this function is not
-- in that path.
function S.checkSchism(groupName)
    local s = store(); if not s then return nil end
    groupName = tostring(groupName)
    local members = {}
    for id, g in pairs(s.groups) do
        if tostring(g) == groupName then
            local rec = SAO.Identity and SAO.Identity.get(id) or nil
            if not (rec and rec.dead) then
                members[#members + 1] = id
            end
        end
    end
    if #members < 3 then return nil end
    table.sort(members)
    -- Any mutually hostile pair inside the roster?
    local pairA, pairB = nil, nil
    for i = 1, #members do
        for j = i + 1, #members do
            if S.isHostileTo(members[i], members[j])
                and S.isHostileTo(members[j], members[i]) then
                pairA, pairB = members[i], members[j]
                break
            end
        end
        if pairA then break end
    end
    if not pairA then return nil end
    local leader = S.leaderOf(groupName)
    -- The estranged core: whichever of the pair stands further from
    -- the chair - the leader's enemy if the pair touches the leader,
    -- else the one the roster trusts less.
    local core
    if pairA == leader then core = pairB
    elseif pairB == leader then core = pairA
    else
        local sumA, sumB = 0, 0
        for _, m in ipairs(members) do
            if m ~= pairA then sumA = sumA + S.trust(m, pairA) end
            if m ~= pairB then sumB = sumB + S.trust(m, pairB) end
        end
        core = (sumA <= sumB) and pairA or pairB
    end
    if core == leader then return nil end
    -- The leaving bloc: the core and everyone who trusts them more
    -- than the leader.
    local leavers = { core }
    for _, m in ipairs(members) do
        if m ~= core and m ~= leader
            and S.trust(m, core) > S.trust(m, leader) then
            leavers[#leavers + 1] = m
        end
    end
    -- A schism of ONE is an exile, not a rival house: the core leaves
    -- alone (keeps their home; the personal hostility already speaks)
    -- and no new company or feud forms.
    if #leavers < 2 then
        s.groups[core] = nil
        local crec = SAO.Identity and SAO.Identity.get(core) or nil
        if crec then crec.designation = nil end
        S.electLeader(groupName)
        return nil
    end
    local newGroup = "schism-" .. tostring(core)
    -- The break is chronicled on the house that broke.
    do
        local metaS = s.groupMeta[groupName] or {}
        metaS.govHistory = metaS.govHistory or {}
        local okGH, gh = pcall(function()
            return GameTime.getInstance():getWorldAgeHours()
        end)
        metaS.govHistory[#metaS.govHistory + 1] = {
            kind = "schism", left = #leavers,
            atHours = okGH and gh or 0,
        }
        s.groupMeta[groupName] = metaS
        S.pushRadioNews({ kind = "schism", group = groupName,
            left = #leavers })
    end
    for _, m in ipairs(leavers) do
        s.groups[m] = nil
        local mrec = SAO.Identity and SAO.Identity.get(m) or nil
        if mrec then mrec.designation = nil end
    end
    S.electLeader(groupName)
    -- Batch-join THEN one election: joining one-by-one would run the
    -- widow release at roster size 1 and dissolve the new house as it
    -- formed. The store is this verb's to write.
    for _, m in ipairs(leavers) do
        s.groups[m] = newGroup
    end
    S.electLeader(newGroup)
    -- The split is the declaration: the two houses start at feud.
    s.groupMeta = s.groupMeta or {}
    local metaOld = s.groupMeta[groupName] or {}
    local metaNew = s.groupMeta[newGroup] or {}
    metaOld.feudWith = metaOld.feudWith or {}
    metaNew.feudWith = metaNew.feudWith or {}
    metaOld.feudWith[newGroup] = true
    metaNew.feudWith[groupName] = true
    s.groupMeta[groupName] = metaOld
    s.groupMeta[newGroup] = metaNew
    noteFeudEvent(s, groupName, newGroup, "declaredAtHours")
    return newGroup, core, #leavers
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
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if not meta or meta.chairOffer ~= tostring(playerKey) then
        return false
    end
    meta.chairOffer = nil
    meta.playerChair = tostring(playerKey)
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    meta.govHistory = meta.govHistory or {}
    meta.govHistory[#meta.govHistory + 1] = {
        kind = "chair", atHours = okH and h or 0,
    }
    s.groupMeta[tostring(groupName)] = meta
    S.pushRadioNews({ kind = "chair", group = groupName })
    return true
end

function S.declineChair(groupName)
    local s = store(); if not s then return false end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    if not meta then return false end
    meta.chairOffer = nil
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    meta.chairDeclinedAt = okH and h or 0
    s.groupMeta[tostring(groupName)] = meta
    return true
end

-- The promise ([B3]): "if I turn, you do it" is a CLAIM between two
-- people, recorded at the moment it is asked, kept or carried.
function S.recordPromise(bittenId, keeperId)
    local s = store(); if not s then return end
    s.promises = s.promises or {}
    s.promises[tostring(bittenId)] = tostring(keeperId)
end

function S.promiseKeeperOf(bittenId)
    local s = store(); if not s then return nil end
    return s.promises and s.promises[tostring(bittenId)] or nil
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
        return GameTime.getInstance():getWorldAgeHours()
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
function S.roadworthy(groupName)
    local m = S.motorPoolOf(groupName)
    if not (m and m.cars) then return nil end
    local best = nil
    for _, c in ipairs(m.cars) do
        local runs = (c.fuel or 0) > 5 and (c.engine or 0) > 20
        if runs then
            local open = (c.ignition or 0) == 1 or (c.hotwired or 0) == 1
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
        return GameTime.getInstance():getWorldAgeHours()
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
    local s = store(); if not s then return end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    meta.hearth = { burning = burning and true or false,
        atHours = okH and h or 0 }
    s.groupMeta[tostring(groupName)] = meta
end

function S.hearthOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local hh = meta and meta.hearth or nil
    if not hh then return nil end
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    if okH and h - (hh.atHours or 0) > 48 then return nil end
    return hh
end

-- The water claim ([B6]): what the house knows it has to drink -
-- read at the same rounds as the shelves, aged the same way.
function S.setWaterStore(groupName, word, units)
    local s = store(); if not s then return end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    meta.waterStore = { word = word, units = units,
        atHours = okH and h or 0 }
    s.groupMeta[tostring(groupName)] = meta
end

function S.waterStoreOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local w = meta and meta.waterStore or nil
    if not w then return nil end
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    if okH and h - (w.atHours or 0) > 48 then return nil end
    return w
end

function S.setLarder(groupName, word, count)
    local s = store(); if not s then return end
    s.groupMeta = s.groupMeta or {}
    local meta = s.groupMeta[tostring(groupName)] or {}
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    meta.larder = { word = word, count = count, atHours = okH and h or 0 }
    s.groupMeta[tostring(groupName)] = meta
end

function S.larderOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    local l = meta and meta.larder or nil
    if not l then return nil end
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
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

-- The pact ([A26]): the positive mirror of the feud. Two leaders of
-- complementary companies - one bread-rich, one watch-rich - who meet
-- ALIGNED with mutual trust healed past 0.2 shake on bread-for-watch:
-- passage on each other's ground, chronicled, aired on the wire.
-- Formation is leader-to-leader like peace ([A21]) - made by the two
-- people who can make it.
function S.tryPact(idA, idB, gA, gB)
    local s = store(); if not s then return false end
    s.groupMeta = s.groupMeta or {}
    local metaA = s.groupMeta[tostring(gA)] or {}
    local metaB = s.groupMeta[tostring(gB)] or {}
    if metaA.leaderId ~= tostring(idA) and metaA.leaderId ~= idA then
        return false
    end
    if metaB.leaderId ~= tostring(idB) and metaB.leaderId ~= idB then
        return false
    end
    if metaA.pactWith and metaA.pactWith[tostring(gB)] then return false end
    if S.trust(idA, idB) < 0.2 or S.trust(idB, idA) < 0.2 then
        return false
    end
    local shA, shB = S.groupShape(gA), S.groupShape(gB)
    if not shA or not shB or shA.n < 4 or shB.n < 4 then return false end
    local complement =
        (shA.forageShare >= 0.2 and shB.watchShare >= 0.2)
        or (shB.forageShare >= 0.2 and shA.watchShare >= 0.2)
    if not complement then return false end
    metaA.pactWith = metaA.pactWith or {}
    metaB.pactWith = metaB.pactWith or {}
    metaA.pactWith[tostring(gB)] = true
    metaB.pactWith[tostring(gA)] = true
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    local at = okH and h or 0
    for _, pair in ipairs({ { metaA, gB }, { metaB, gA } }) do
        pair[1].govHistory = pair[1].govHistory or {}
        pair[1].govHistory[#pair[1].govHistory + 1] = {
            kind = "pact", other = tostring(pair[2]), atHours = at,
        }
    end
    s.groupMeta[tostring(gA)] = metaA
    s.groupMeta[tostring(gB)] = metaB
    S.adjustTrust(idA, idB, 0.1)
    S.adjustTrust(idB, idA, 0.1)
    S.pushRadioNews({ kind = "pact", a = tostring(gA), b = tostring(gB) })
    return true
end

-- The county hears you ([A26]): a player voice on the wire reaches
-- every company that keeps a watch (the watch keeps the radio). Trust
-- warms a little - a voice on the air is a neighbor, not a stranger -
-- capped at once per game hour; the house remembers hearing you
-- (heardOnAir, feeding Talk); and the wire acknowledges a new voice
-- in its next bulletin, once a day at most.
-- Does this survivor actually possess a receiver? Nothing conjured
-- ([A27]): a LOADED body is scanned for a real device item; an
-- unloaded record answers from claims - the kit that granted a
-- handset (rec.hasRadio) or a hibernation pack physically holding
-- one. A never-met person owns nothing yet and hears nothing; reach
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
            local items = body:getInventory():getItems()
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
                if dd then
                    local ft = tostring(it:getFullType() or "")
                    if ft:find("Walkie") or ft:find("Radio") then
                        found = true
                        break
                    end
                end
            end
        end)
        return found
    end
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    if not rec then return false end
    if rec.hasRadio then return true end
    return type(rec.hibernation) == "string"
        and rec.hibernation:find("WalkieTalkie") ~= nil
end

function S.hearPlayerOnAir(playerKey)
    local s = store(); if not s then return end
    local okH, h = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    local now = okH and h or 0
    s.onAir = s.onAir or {}
    if now - (s.onAir.lastHeardAt or -9) < 1 then return end
    s.onAir.lastHeardAt = now
    -- Hearing is OWNERSHIP ([A27]): whoever actually carries a
    -- receiver catches the voice; their house learns it indoors (the
    -- owner tells the room). No house set is conjured, no size gate -
    -- a band of two with one handset hears as a band.
    local heard = false
    for _, rec in pairs((SAO.Identity and SAO.Identity.all
        and SAO.Identity.all()) or {}) do
        if not rec.dead and S.ownsRadio(rec.id) then
            heard = true
            s.onAir.heardSolo = s.onAir.heardSolo or {}
            s.onAir.heardSolo[rec.id] = now
            S.adjustTrust(rec.id, playerKey, 0.02)
            local g = s.groups and s.groups[rec.id] or nil
            if g then
                s.onAir.heardBy = s.onAir.heardBy or {}
                if s.onAir.heardBy[g] ~= now then
                    s.onAir.heardBy[g] = now
                    for mid, mg in pairs(s.groups) do
                        if mg == g and mid ~= rec.id then
                            S.adjustTrust(mid, playerKey, 0.02)
                        end
                    end
                end
            end
        end
    end
    if heard and now - (s.onAir.lastAckAt or -48) >= 24 then
        s.onAir.lastAckAt = now
        S.pushRadioNews({ kind = "onAir" })
    end
end

-- Whether this survivor's company has heard the player on the wire.
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
    if s.onAir and s.onAir.heardSolo and s.onAir.heardSolo[id] then
        return true
    end
    local g = s.groups and s.groups[id] or nil
    return (g and s.onAir and s.onAir.heardBy
        and s.onAir.heardBy[g]) ~= nil
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

-- Does this member's own class dissent from their community's policy?
function S.dissentsFromPolicy(id)
    local g = S.groupOf(id)
    if not g then return false end
    local policy = S.rationPolicyOf(g)
    if not policy then return false end
    local rec = SAO.Identity and SAO.Identity.get(id) or nil
    local cls = rec and SAO.Census and SAO.Census.classOf
        and SAO.Census.classOf(rec.occupation) or nil
    if (policy == "watch-first" or policy == "house-first")
        and cls == "carer" then
        return true
    end
    return policy == "weak-first" and cls == "hardened"
end

-- The chronicle of a group's own governance, or {}.
function S.govHistoryOf(groupName)
    local s = store(); if not s then return {} end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return (meta and meta.govHistory) or {}
end

function S.rationPolicyOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return meta and meta.rationPolicy or nil
end

function S.groupOf(id)
    local s = store(); if not s then return nil end
    return s.groups[id]
end

-- All other members of this id's group (plain Lua ids; caller resolves
-- bodies). Empty table when ungrouped or alone.
-- Fellowship ends at death; the living remember, but the roster is of
-- the living.
function S.fellowsOf(id)
    local s = store(); if not s then return {} end
    local g = s.groups[id]
    if not g then return {} end
    local out = {}
    for otherId, otherGroup in pairs(s.groups) do
        if otherId ~= id and otherGroup == g then
            local rec = SAO.Identity and SAO.Identity.get(otherId) or nil
            if not (rec and rec.dead) then
                out[#out + 1] = otherId
            end
        end
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
    local okH, h = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
    s.groupClaims[tostring(groupName)] = {
        minX = minX, minY = minY, maxX = maxX, maxY = maxY, z = z or 0,
        sinceHours = okH and h or 0,
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
    local okH, h = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
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
    local okH, h = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
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
    local okH, h = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
    meta.playerSinceHours = okH and h or 0
    s.groupMeta[tostring(groupName)] = meta
    return true
end

function S.playerMemberOf(groupName)
    local s = store(); if not s then return nil end
    local meta = s.groupMeta and s.groupMeta[tostring(groupName)] or nil
    return meta and meta.playerMemberOf or nil
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

function S.describe(id)
    local s = store(); if not s then return "no-store" end
    local nRel = 0
    for _ in pairs(s.relations[id] or {}) do nRel = nRel + 1 end
    return "standing: group=" .. tostring(s.groups[id])
        .. " relations=" .. nRel
        .. " claim=" .. tostring(s.claims[id] ~= nil)
end

return S
