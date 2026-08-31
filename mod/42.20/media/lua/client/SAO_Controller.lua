-- SAO_Controller — the Controller layer, v2: the composition running live.
-- ---------------------------------------------------------------------------
--   Perception admits -> Disposition decides -> Standing channels -> Execution acts
--
-- Each decision update selects ONE state and one action owns the body. The
-- controller consumes ONLY Perception queries — it never reads the world. Its
-- decision cadence comes from Disposition (skill changes latency), its
-- permissions from Standing, and its movement from the Java-side loop.
--
-- State families:
--   Decision  IDLE (roam cadence, evening seat), ALERT (hold, keep looking)
--   Movement  TRAVEL FLEE ROAM HOMEWARD FORAGE WATERWARD GEARWARD FOLLOW
--             (Locomotion owns the body; exits ride its verdicts; leaving
--             the family cancels the route - F-012 invariant in setState)
--   Hold      EAT TAKE DRINK TREAT RELOAD (the body's own action stack is
--             the truth; threat interrupts clear the queue), RIP (charged
--             time), ENGAGE (combat pump owns the body; evidence verdicts)
-- One state owns the body at a time; decide() picks by priority:
-- threats > bleeding > thirst > hunger > company > homing > gear > roam.

SAO = SAO or {}
SAO.Controller = SAO.Controller or {}
local Ctl = SAO.Controller

-- id -> { rec, state, stateSince, nextDecisionAt, fleeTarget }
Ctl.agents = Ctl.agents or {}

local tickCount = 0

-- [B43] What it takes to have WITNESSED something happen to somebody.
--
-- The county asks this in three places - a killing (twice) and a fight -
-- and every one of them asked it the same way: do I hold an OBSERVED
-- belief of that person, taken recently, from close by. One question,
-- and it was spelled three times with two different answers: ten tiles
-- for a killing, twelve for a fight, and nothing anywhere saying why.
--
-- [B41] found this shape before, where a docstring said "within 3
-- tiles" and the code said `<= 9.0` - correct only by coincidence. Here
-- the coincidence had already broken and nobody could see it, because
-- there was no name for the two spellings to disagree about.
--
-- Unified rather than kept apart. [B40] kept two feud reaches
-- different on purpose and WROTE THE REASON DOWN; there is no reason
-- here - the perceptual question is identical whether the person in
-- front of you is being killed or being fought, and a killing is if
-- anything the more noticeable of the two. So the twelve was a third
-- spelling, not a decision, and it joins the rule.
local WITNESS_REACH = 10.0    -- tiles: close enough to have made it out
local WITNESS_FRESH = 120     -- frames (~2s at 60fps): recently enough to be NOW

-- [B45] Two more rules that were being typed rather than named.
--
-- ARRIVAL_REACH is the live half of a question the dormant half
-- already had a name for. `MEET_RANGE = 3` in Population decides that
-- two RECORDS crossed paths; this decides that a BODY got where it was
-- going - the player who came when someone cried, the medic who
-- reached the wounded, the one who walked to the grave they promised
-- to visit. Same three tiles, deliberately NOT the same constant: move
-- the dormant meeting rate and this must not move with it, and move
-- this and the dormant sweep must not. They agree by scale, not by
-- rule, and [B40] is the reason that distinction gets written down
-- instead of collapsed.
--
-- TALK_REACH is the distance at which two people are in each other's
-- company. Word of mouth passes at it (both the passive Knox path on
-- its slow cadence and the live path every tick), and a person seen
-- inside it, recently, and not hostile warms slightly toward you. That
-- last one is the same rule and not a coincidence: the trust drip is
-- payment for company, and company is the range at which you would
-- actually have said something.
local ARRIVAL_REACH = 3       -- tiles: close enough to have got there
local TALK_REACH = 6          -- tiles: close enough to be company

-- [B47] Arrival is readable from outside, because the same rule
-- reads backwards: if three tiles means you have got there, then a
-- destination three tiles off is one you have already arrived at.
-- The harness refuses a walk order that short for exactly that
-- reason, and it cannot see a file-local.
Ctl.ARRIVAL_REACH = ARRIVAL_REACH

-- World policy from the sandbox screen (defaults mirror the schema).
local function policy()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return {
        desperation = (sv and tonumber(sv.Desperation)) or 0.7,
        trustToCompany = (sv and tonumber(sv.TrustToCompany)) or 0.5,
        errandRadius = (sv and tonumber(sv.ErrandRadius)) or 12,
    }
end

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("CTL", msg) end

function Ctl.adopt(rec)
    if not rec or not rec.id then return false end
    Ctl.agents[rec.id] = Ctl.agents[rec.id] or {
        rec = rec, state = "IDLE", stateSince = tickCount, nextDecisionAt = 0,
    }
    log("adopted " .. rec.id .. " | " .. SAO.Disposition.describe(rec.id))
    return true
end

-- Passive adoption ([A17]): a Knox person stands in the economy - the
-- exchange reaches them, their death mourns - but our controller NEVER
-- drives their body. Their KS life is their own.
function Ctl.adoptPassive(rec)
    if not rec or not rec.id then return false end
    if Ctl.agents[rec.id] then return true end
    Ctl.agents[rec.id] = {
        rec = rec, state = "PASSIVE", stateSince = tickCount,
        nextDecisionAt = 0, passive = true,
    }
    log("stands among us: " .. rec.id .. " (passive; their life is their own)")
    return true
end

function Ctl.drop(id)
    id = tostring(id)
    if Ctl.agents[id] then
        SAO.Locomotion.cancel(id)
        Ctl.agents[id] = nil
        log("dropped " .. id)
    end
end

local setStateRef

-- When one runs, the company looks up: a fleeing survivor's present
-- fellows hear it immediately - beliefs shared without ceremony (same
-- group always passes the tell gates), decisions re-made this tick, the
-- idle put on ALERT. Doctrine v1: cohesion under flight.
-- [B19] Renamed from broadcastFlight: it is no longer only flight
-- that rouses a company. A night keeper who SEES something and keeps
-- their nerve has to be able to wake the house too - otherwise the
-- braver the sentry, the more useless the watch.
local function rouseCompany(id, body, reason)
    for otherId in pairs(Ctl.agents) do
        if otherId ~= id and SAO.Standing.sameGroup(id, otherId) then
            local other = Ctl.agents[otherId]
            local otherBody = SAO.Body.get(otherId)
            if other and otherBody then
                local dx = otherBody:getX() - body:getX()
                local dy = otherBody:getY() - body:getY()
                if dx * dx + dy * dy
                    <= SAO.Perception.EARSHOT * SAO.Perception.EARSHOT then
                    SAO.Perception.tell(id, otherId, tickCount)
                    other.nextDecisionAt = 0
                    if other.state == "IDLE" or other.state == "ROAM" then
                        setStateRef(other, otherId, "ALERT",
                            reason
                            or (id .. " is running - company reacts"))
                    end
                end
            end
        end
    end
end

-- States whose body movement is owned by the Locomotion layer. Leaving
-- this family for any non-member state MUST cancel the route: between
-- order() and first capture the engine's own pathfind behavior walks the
-- body autonomously, and an orphaned job is exactly the historical
-- independent-wandering defect (F-012).
local MOVEMENT_STATES = {
    TRAVEL = true, FLEE = true, ROAM = true, HOMEWARD = true,
    FORAGE = true, WATERWARD = true, GEARWARD = true, FOLLOW = true,
    AMMOWARD = true, MOURNWARD = true, PLAYERFOLLOW = true,
    SETTLEWARD = true, MEDICWARD = true, SEARCHWARD = true,
    HEARTHWARD = true,
}

-- The four answers (DR-011, [A18]): what is the pressure doing to this
-- body right now - need, designation, chosen rest, or errand. Every
-- transition passes through setState, so a mannequin is structurally
-- impossible: the fallback answer is an errand, never nothing.
--
-- [B52] FOUR, and the tree spelled five. Four sites answered `"rest"`
-- against three answering `"chosen rest"` - the evening seat, sleep, a
-- short rest with a weapon in reach, and a mourner standing where
-- somebody fell. Nothing compared against either spelling, so the
-- split cost nothing and was invisible; the day somebody writes
-- `answer == "chosen rest"` it would silently miss four of the seven
-- rests in the county. Border 78 holds the domain closed now.
local PRESSURE_ANSWER = {
    FLEE = "need", TREAT = "need", RIP = "need", EAT = "need",
    TAKE = "need", DRINK = "need", WATERWARD = "need", FORAGE = "need",
    RELOAD = "need", AMMOWARD = "need", SMOKE = "need",
    MOURNWARD = "need", MOURNING = "need", MEDICWARD = "need",
    SEARCHWARD = "need", HEARTHWARD = "need", WARMING = "need",
    -- F-025: a firefight is not an errand. Combat and threat-holds
    -- answer "need" - the pressure IS the threat.
    ENGAGE = "need", ALERT = "need",
}

-- [B19] Tonight's keeper, derived and never assigned. A pure
-- function of facts every housemate can see, so each agent reaches
-- the same answer without any shared state and nobody double-posts.
--
-- The watch takes the watch where a watch exists; otherwise the
-- house shares it. It rotates by night so the same person does not
-- sit up forever. Nobody alone sits up - a rota of one is not a
-- rota, and a person living alone who never sleeps is a bug wearing
-- a duty's clothes.
-- [B22] Where the house's work is actually happening - read, never
-- registered. The temptation is a table of stations (kitchen, wall,
-- infirmary); that would be authoring the map instead of reading it,
-- and it would break the moment a house used a different room.
--
-- DR-011's four answers already carry the fact. Someone answering
-- their DESIGNATION is at work by definition, and the state machine
-- already separates moving from standing. Stationary plus designated
-- IS the station, and it moves when they do.
--
-- Movement states are deliberately excluded: you gather where work is
-- DONE, not where it is walked to. A line of idlers trailing a
-- patrolling watchman would be the mechanism working and the
-- simulation failing.
local function whereTheWorkIs(id, body)
    local myG = SAO.Standing.groupOf(id)
    if not myG then return nil end
    local bestId, bestBody, bestD2 = nil, nil, 1e9
    for oid, oag in pairs(Ctl.agents) do
        if oid ~= id
            and oag.pressure
            and oag.pressure.answer == "designation"
            and not MOVEMENT_STATES[oag.state]
            and SAO.Standing.groupOf(oid) == myG then
            local ob = SAO.Body.get(oid)
            if ob then
                local dx = ob:getX() - body:getX()
                local dy = ob:getY() - body:getY()
                local d2 = dx * dx + dy * dy
                if d2 <= 400.0 and d2 < bestD2 then
                    bestId, bestBody, bestD2 = oid, ob, d2
                end
            end
        end
    end
    return bestId, bestBody, math.sqrt(bestD2)
end

local function nightKeeper(id, nightIndex)
    local g = SAO.Standing.groupOf(id)
    if not g then return nil end
    local pool, watchPool = {}, {}
    for _, r in pairs(SAO.Identity.all()) do
        if not r.dead and SAO.Standing.groupOf(r.id) == g then
            local rb = SAO.Body.get(r.id)
            if rb and SAO.Standing.insideClaim(r.id, rb:getX(), rb:getY()) then
                pool[#pool + 1] = r.id
                if r.designation == "watch" then
                    watchPool[#watchPool + 1] = r.id
                end
            end
        end
    end
    local eligible = (#watchPool > 0) and watchPool or pool
    if #eligible < 2 then return nil end
    table.sort(eligible)
    return eligible[(nightIndex % #eligible) + 1]
end

-- [B20] The player hears it too. They hold no belief table, so a
-- companion bleeding in the next room shouted and the player got only
-- an ambient voice line - no name, no idea it was one of theirs.
-- Same idiom [B18] set for a death seen: told once, over their head,
-- the way the game tells them anything. Reach is whatever the cry
-- actually carried, so the player hears exactly what a survivor
-- standing in their shoes would.
local function tellPlayerOfCry(crierId, crierRec, crierBody, reach)
    local me = getSpecificPlayer(0)
    if not me or me:isDead() or not crierBody or not crierRec then return end
    local dx = crierBody:getX() - me:getX()
    local dy = crierBody:getY() - me:getY()
    if dx * dx + dy * dy > (reach or 20.0) * (reach or 20.0) then return end
    local myKey = SAO.Standing.playerKey(me)
    -- [B20] The same familiarity rule the cry itself uses, for the
    -- same reason: the player should hear what a survivor standing in
    -- their shoes hears. Gating this on trust would have meant a
    -- hostile screaming twenty feet away - someone hurt, vulnerable
    -- and no friend of yours - registering as nothing at all, while
    -- every survivor nearby knew exactly who it was.
    local known = SAO.Standing.knowsOf(myKey, crierId)
        or SAO.Standing.knowsOf(crierId, myKey)
        or SAO.Standing.isBondedTo(crierId, myKey)
    if not known then return end
    pcall(function()
        HaloTextHelper.addBadText(me,
            tostring(SAO.Identity.displayName(crierRec))
            .. " is calling for help.")
    end)
    -- [B20] Returns the key it told, because a player who was told is
    -- a player who heard - and the reckoning judges everyone who
    -- heard.
    return myKey
end

-- [B20] The cry, as one decision. Who calls out is who they are, not
-- a flag on a wound: composure holds it in, having been this close
-- before calls sooner, and someone who has learned what a shout costs
-- bites down and deals with it alone. The same injury on two people
-- makes a shout or a silence.
--
-- Lifted out of the wounded block because it was reachable only from
-- the CALM states, so a survivor bleeding badly while running from a
-- horde never made a sound - the exact moment a person screams. One
-- definition, two call sites; copying the formula would be the same
-- drift this batch already refused for the weather mask.
local function tryCry(id, agent, body, tick)
    local sev = 0
    pcall(function()
        sev = (tonumber(SAOJavaBridge:getBleedingCount(body)) or 0)
            + 2.0 * (tonumber(SAOJavaBridge:woundInfection(body)) or 0)
    end)
    if sev < 2 or tick < (agent.nextCryAt or 0) then return false end
    local urge = sev * 0.5
        - 2.0 * SAO.Disposition.traits(id).nerve
        + 1.5 * SAO.Lessons.weight(id, "never-again-that-close")
        - 2.0 * SAO.Lessons.weight(id, "noise-is-a-debt")
    if urge <= 0 then return false end
    agent.nextCryAt = tick + 1800
    -- The engine's own shout: real sound, real reach, and it draws the
    -- dead the same way a player's does. That cost is the point.
    pcall(function() body:Callout() end)
    local heard, reach = nil, nil
    pcall(function()
        heard, reach = SAO.Perception.cryForHelp(id, tick)
    end)
    local toldPlayer = nil
    pcall(function()
        toldPlayer = tellPlayerOfCry(id, agent.rec, body, reach)
    end)
    pcall(function()
        SAO.Voice.onEvent(id, "cryForHelp", tick)
    end)
    -- [B20] Remember whose silence it was. A call that gets nothing
    -- is the more common outcome and it has to be able to cost
    -- somebody something.
    agent.criedAt = tick
    agent.criedHeard = heard or {}
    agent.playerCame = nil
    -- [B20] The player heard it, so the player is in the list. Being
    -- the one person in Knox who can walk past a scream for free is
    -- not a simulation of anything.
    if toldPlayer then
        agent.criedHeard[#agent.criedHeard + 1] = toldPlayer
    end
    log(id .. " calls out - hurt badly ("
        .. tostring(#(heard or {})) .. " knew the voice)")
    return true
end

local function setState(agent, id, state, why, answer)
    agent.pressure = {
        answer = answer or PRESSURE_ANSWER[state] or "errand",
        detail = why or string.lower(tostring(state)),
        at = tickCount,
    }
    -- [B19] A venture ends when the state does. The ones who came
    -- along are following an announced TRIP, not a person - so the
    -- trip has to be able to end, or they would follow forever.
    if state ~= "ROAM" then agent.onVenture = nil end
    if agent.state ~= state then
        if MOVEMENT_STATES[agent.state] and not MOVEMENT_STATES[state] then
            SAO.Locomotion.cancel(id)
        end
        if agent.resting then
            agent.resting = nil
            local restingBody = SAO.Body.get(id)
            if restingBody then
                if agent.sleeping then
                    agent.sleeping = nil
                    agent.lastRestHours = nil
                    pcall(function() SAOJavaBridge:setShellAsleep(restingBody, false) end)
                end
                pcall(function() restingBody:setSitOnGround(false) end)
            end
        end
        log(id .. " " .. agent.state .. " -> " .. state .. " (" .. why .. ")")
        agent.state = state
        agent.stateSince = tickCount
        -- Voice renders the decision audible; it never decides.
        if SAO.Voice then
            pcall(function() SAO.Voice.onTransition(id, state, tickCount) end)
        end
        -- Flight is company business the moment it starts.
        if state == "FLEE" then
            local fleeBody = SAO.Body.get(id)
            if fleeBody then
                pcall(function() rouseCompany(id, fleeBody) end)
            end
        end
        -- [B19] And so is a keeper who saw something. The waking IS
        -- the watch - a sentry who notices and says nothing has done
        -- no one any good. It rides the same machinery flight does,
        -- so the woken learn WHAT was seen (the tell) and not merely
        -- that they should be afraid.
        if state == "ALERT" and agent.keeperTonight then
            local kBody = SAO.Body.get(id)
            if kBody then
                pcall(function()
                    rouseCompany(id, kBody, id .. " wakes the house")
                end)
            end
        end
    end
end
setStateRef = setState

function Ctl.orderEngageNearest(id, live)
    local agent = Ctl.agents[tostring(id)]
    if not agent then log("orderEngage: unknown agent " .. tostring(id)) return false end
    local body = SAO.Body.get(id)
    if not body then log("orderEngage: no active body") return false end
    local ok, verdict = pcall(function()
        return SAOJavaBridge:beginCombatNearest(body, live and true or false)
    end)
    verdict = ok and tostring(verdict) or tostring(verdict)
    log(tostring(id) .. " " .. verdict)
    if verdict:find("COMBAT_STARTED", 1, true) then
        agent.lastCombatVerdict = ""
        setState(agent, tostring(id), "ENGAGE", "operator order")
        return true
    end
    return false
end

function Ctl.orderTravel(id, x, y, z)
    local agent = Ctl.agents[tostring(id)]
    if not agent then log("orderTravel: unknown agent " .. tostring(id)) return false end
    local body = SAO.Body.get(id)
    if not body then log("orderTravel: no active body for " .. tostring(id)) return false end
    if SAO.Locomotion.order(id, body, x, y, z) then
        setState(agent, tostring(id), "TRAVEL", "operator order")
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- The decision update: one state chosen from beliefs, per Disposition cadence.

-- The epistemic entry gate ([A15]): may I go there, BY WHAT I KNOW?
-- Own claim and own group's base are always mine (you know your own
-- house - Standing truth IS the knowledge there). A place believed to be
-- somebody's is entered only against hostility (the raid case); a place
-- never learned is entered innocently - the owner's objection will
-- teach it.
-- The work window ([B5]): claim-bounded world scans walk a box
-- around the WORKER, not the whole house. The body moves, so the
-- claim is still covered over time - and a 900-square building never
-- gets read in one frame.
local function workWindow(claim, body, reach)
    if not claim then return nil end
    reach = reach or 12
    local bx = math.floor(body:getX())
    local by = math.floor(body:getY())
    local minX = math.max(claim.minX, bx - reach)
    local maxX = math.min(claim.maxX, bx + reach)
    local minY = math.max(claim.minY, by - reach)
    local maxY = math.min(claim.maxY, by + reach)
    if minX > maxX or minY > maxY then return nil end
    return minX, minY, maxX, maxY, claim.z or 0
end

-- [B17] Is the sky doing the work? Vanilla's own farming system
-- waters exterior plots while it rains, so hauling water to open rows
-- in a downpour is pointless labour.
local function rainingNow()
    local ok, raining = pcall(function()
        return getClimateManager():isRaining()
    end)
    return ok and raining == true
end

local function mayEnterBelieved(id, x, y)
    if SAO.Standing.insideClaim(id, x, y) then
        return true
    end
    local owner = SAO.Perception.believesClaimed(id, x, y)
    if not owner then
        return true   -- innocent: nothing known against it
    end
    -- Passage rights ([A26]): a pact means allies walk each other's
    -- ground - the bread gets delivered, the watch walks the wall.
    -- War opens it too ([A27]): a feud makes the enemy's ground
    -- enterable for the raiding house - group hostility, not only the
    -- personal kind, is admission.
    local myG = SAO.Standing.groupOf(id)
    if myG then
        local og = SAO.Standing.groupOf(owner) or owner
        if og and SAO.Standing.pactBetween
            and SAO.Standing.pactBetween(myG, og) then
            return true
        end
        if og and SAO.Standing.feudBetween(myG, og) then
            return true
        end
    end
    return SAO.Standing.isHostileTo(id, owner)
        or SAO.Standing.isHostileTo(owner, id)
end

-- [B20] Resolve a body for ANY standing key, the player's included.
-- The aid loop skipped the player for a mundane reason rather than a
-- design one: `SAO.Body.get` only knows shells, so the lookup
-- returned nil and the player was silently dropped as a casualty.
-- Survivors have always SEEN them - the scanner emits a real player
-- as a `P:` row with a condition bracket - so the only thing missing
-- was a body to walk to.
local function bodyForKey(key)
    local b = SAO.Body.get(key)
    if b then return b end
    if SAO.Standing.isPlayerKey(key) then
        local me = getSpecificPlayer(0)
        if me and not me:isDead()
            and SAO.Standing.playerKey(me) == key then
            return me
        end
    end
    -- [B28] The third domain. A survivor could know somebody else's
    -- person by name, trust them, believe them hurt and standing
    -- right there - and never reach them, because this returned nil
    -- and every caller quietly did nothing. The scanner knew where
    -- they were the whole time; nothing asked it the reverse question.
    if string.sub(tostring(key), 1, 8) == "foreign:" then
        local who = string.sub(tostring(key), 9)
        local me2 = getSpecificPlayer(0)
        if me2 and who ~= "" and SAOJavaBridge then
            local okF, fbody = pcall(function()
                return SAOJavaBridge:foreignBodyByName(me2, who)
            end)
            if okF and fbody then return fbody end
        end
    end
    return nil
end

local function nearestHostilePerson(id, tick, fromX, fromY)
    local b = SAO.Perception.beliefs[id]
    if not b then return nil end
    local best, bestName, bestKey, bestDist
    for name, belief in pairs(b.people) do
        local key = SAO.Standing.keyForObserved(name)
        if (tick - belief.at) <= 1800 and SAO.Standing.isHostileTo(id, key) then
            local d = belief.dist
            if fromX and fromY then
                local dx, dy = belief.x - fromX, belief.y - fromY
                d = math.sqrt(dx * dx + dy * dy)
            end
            if not best or d < bestDist then
                best, bestName, bestKey, bestDist = belief, name, key, d
            end
        end
    end
    if best then
        return { x = best.x, y = best.y, dist = bestDist, at = best.at,
                 source = best.source, condition = best.condition },
            bestName, bestKey
    end
    return nil
end

local function decide(id, agent, body)
    local tick = tickCount
    -- Riding ([B1]): a passenger is a passenger - no needs-driven
    -- walks, no threat responses, nothing, until the door opens.
    -- Self-healing: a rider whose vehicle is gone resumes life.
    if agent.riding then
        local okRV, rv = pcall(function() return body:getVehicle() end)
        if okRV and rv then return end
        agent.riding = nil
        setState(agent, id, "IDLE", "back on foot")
    end
    local bodyX, bodyY = body:getX(), body:getY()
    local threat = SAO.Perception.nearestBelievedZombie(id, tick, bodyX, bodyY)
    local threatCount = SAO.Perception.believedThreatCount(id, tick, 10, bodyX, bodyY)

    -- A believed hostile PERSON is a threat like any other; if both exist the
    -- nearer belief governs. Permission asymmetry is Standing's, not ours.
    local hostile, hostileName, hostileKey = nearestHostilePerson(id, tick, bodyX, bodyY)
    local governingPerson, governingPersonKey = nil, nil
    if hostile and (not threat or hostile.dist < threat.dist) then
        threat = hostile
        threatCount = math.max(threatCount, 1)
        governingPerson, governingPersonKey = hostileName, hostileKey
    end

    -- Threat beliefs outrank everything except an active flee.
    if threat then
        local fleeAt = SAO.Disposition.fleeDistance(id)
        local overwhelmed = threatCount >= SAO.Disposition.overwhelmThreshold(id)
        -- Doctrine of the grudge: a hostile PERSON, close, faced by an
        -- armed survivor whose temperament says fight - the confrontation
        -- goes through the same evidence-based combat loop. Standing is the
        -- authority (hostility must exist; same-group is never permitted);
        -- temperament chooses; everyone else still flees below.
        if governingPerson and threat.dist <= fleeAt and not overwhelmed
            and agent.armed and SAO.Disposition.wouldEngage(id, true, threatCount)
            and SAO.Standing.mayEngagePerson(id, governingPersonKey) then
            -- A grudge at range is a shooting matter when a loaded gun
            -- is carried; the bat serves when it is not.
            if threat.dist > 3.0 then
                pcall(function() return SAOJavaBridge:equipBestRanged(body) end)
            end
            local okC, verdict = pcall(function()
                return SAOJavaBridge:beginCombatWithName(body, governingPerson, 15)
            end)
            verdict = tostring(verdict)
            if okC and verdict:find("COMBAT_STARTED", 1, true) then
                agent.lastCombatVerdict = ""
                pcall(function() SAO.Voice.onEvent(id, "confront", tick) end)
                setState(agent, id, "ENGAGE",
                    string.format("confronts %s at %.1f tiles (standing grudge)",
                        governingPerson, threat.dist))
                return
            end
        end

        -- Standing ground is a choice, not a default: armed, willing per
        -- their own aggression and nerve, not overwhelmed, and the threat is
        -- a zombie (person-fights stay flee/hold until doctrine exists).
        local isZombieThreat = threat.source ~= nil and not threat.teller
            and governingPerson == nil
        if isZombieThreat and threat.dist <= fleeAt and not overwhelmed
            and agent.armed and SAO.Disposition.wouldEngage(id, true, threatCount)
            and SAO.Standing.mayEngageZombie(id) then
            local ok, verdict = pcall(function()
                return SAOJavaBridge:beginCombatNearest(body, true)
            end)
            verdict = ok and tostring(verdict) or tostring(verdict)
            if verdict:find("COMBAT_STARTED", 1, true) then
                agent.lastCombatVerdict = ""
                setState(agent, id, "ENGAGE",
                    string.format("stands ground: believed threat at %.1f tiles", threat.dist))
                return
            end
        end

        -- The gun's hour: overwhelmed beyond melee sense, nerve enough to
        -- stand, and a LOADED firearm in the pack - shoot instead of run.
        -- The shot is loud by the engine's own rules; everything that hears
        -- it, dead or living, reacts for real. That price is the doctrine.
        if overwhelmed and agent.armed
            and SAO.Disposition.wouldShootWhenOverwhelmed(id)
            and SAO.Standing.mayEngageZombie(id) then
            local okG, gunVerdict = pcall(function()
                return SAOJavaBridge:equipBestRanged(body)
            end)
            if okG and tostring(gunVerdict):find("EQUIPPED_RANGED", 1, true) then
                local okC, verdict = pcall(function()
                    return SAOJavaBridge:beginCombatNearest(body, true)
                end)
                if okC and tostring(verdict):find("COMBAT_STARTED", 1, true) then
                    agent.lastCombatVerdict = ""
                    setState(agent, id, "ENGAGE",
                        string.format("overwhelmed (%d believed) - opens fire", threatCount))
                    return
                end
            end
        end

        if threat.dist <= fleeAt or overwhelmed then
            -- Flee AWAY FROM THE BELIEF: the believed position, not the live
            -- zombie. If the belief is stale, the survivor flees a ghost —
            -- that is correct behavior for a person, not a bug.
            local bx, by = body:getX(), body:getY()
            local dx, dy = bx - threat.x, by - threat.y
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 0.1 then dx, dy, len = 1, 0, 1 end
            local dist = 8 + math.min(6, threatCount * 2)
            local gx = math.floor(bx + dx / len * dist)
            local gy = math.floor(by + dy / len * dist)
            -- Flight prefers a REFUGE over a bare vector: the nearest
            -- present fellow first (company is safety), then home - but
            -- never a refuge that lies THROUGH the threat (the direction
            -- to it must not oppose the away-vector).
            local function refugeValid(rx, ry, maxDist)
                local ddx, ddy = rx - bx, ry - by
                local dlen = math.sqrt(ddx * ddx + ddy * ddy)
                -- [B47] A refuge nearer than arrival is not a
                -- refuge, it is here. Same rule as the walk order the
                -- harness refuses, read from the other side.
                if dlen < ARRIVAL_REACH or dlen > maxDist then
                    return false
                end
                local dot = (ddx / dlen) * (dx / len) + (ddy / dlen) * (dy / len)
                return dot > 0.1   -- broadly away from the threat
            end
            do
                local fellows = SAO.Standing.fellowsOf(id)
                local flightGroup = SAO.Standing.groupOf(id)
                local flightLeader = flightGroup
                    and SAO.Standing.leaderOf(flightGroup) or nil
                local bestFx, bestFy, bestFd
                local sharedX, sharedY
                -- The bonded outrank even the leader in flight: run to
                -- your person first.
                local bondedKey = SAO.Standing.bondedWith(id)
                if bondedKey and not SAO.Standing.isHostileTo(id, bondedKey) then
                    local bBody = SAO.Body.get(bondedKey)
                    if bBody then
                        local bx2, by2 = bBody:getX(), bBody:getY()
                        if refugeValid(bx2, by2, 50.0) then
                            sharedX, sharedY = bx2, by2
                        end
                    end
                end
                -- The leader's chosen refuge is the company's first choice.
                if not sharedX and flightLeader and flightLeader ~= id then
                    local la = Ctl.agents[flightLeader]
                    if la and la.state == "FLEE" and la.fleeTargetX
                        and refugeValid(la.fleeTargetX, la.fleeTargetY, 60.0) then
                        sharedX, sharedY = la.fleeTargetX, la.fleeTargetY
                    end
                end
                for i = 1, #fellows do
                    local fid = fellows[i]
                    local fellowAgent = Ctl.agents[fid]
                    -- Coordinated flight: a fellow ALREADY running has a
                    -- chosen refuge - converge on it rather than scatter.
                    -- The company that runs together regroups together.
                    if not sharedX and fellowAgent
                        and fellowAgent.state == "FLEE"
                        and fellowAgent.fleeTargetX
                        and refugeValid(fellowAgent.fleeTargetX,
                            fellowAgent.fleeTargetY, 60.0) then
                        sharedX, sharedY = fellowAgent.fleeTargetX, fellowAgent.fleeTargetY
                    end
                    local fbody = SAO.Body.get(fid)
                    if fbody then
                        local fx2, fy2 = fbody:getX(), fbody:getY()
                        if refugeValid(fx2, fy2, 40.0) then
                            local fd = (fx2 - bx) ^ 2 + (fy2 - by) ^ 2
                            if not bestFd or fd < bestFd then
                                bestFx, bestFy, bestFd = fx2, fy2, fd
                            end
                        end
                    end
                end
                local rec2 = agent.rec
                if sharedX then
                    gx, gy = math.floor(sharedX), math.floor(sharedY)
                elseif bestFx then
                    gx, gy = math.floor(bestFx), math.floor(bestFy)
                elseif rec2 and rec2.homeX and refugeValid(rec2.homeX, rec2.homeY, 60.0) then
                    gx, gy = rec2.homeX, rec2.homeY
                end
            end
            agent.fleeTargetX, agent.fleeTargetY = gx, gy
            if mayEnterBelieved(id, gx, gy) then
                local run = SAO.Disposition.paceUnderThreat(id) == "run"
                -- Fleeing is the urgency that licenses forced entry (a person
                -- goes through the glass ahead of a horde; never on a stroll).
                pcall(function() SAOJavaBridge:setForceEntry(body, true) end)
                if SAO.Locomotion.order(id, body, gx, gy, math.floor(body:getZ()), run) then
                    setState(agent, id, "FLEE",
                        string.format("believed threat at %.1f tiles, count=%d", threat.dist, threatCount))
                    -- [B20] Hurt AND running is when a person actually
                    -- screams. The cooldown and the severity gate keep
                    -- it an act rather than a siren, and the sound it
                    -- makes draws more of what they are running from -
                    -- which is the honest price of shouting.
                    tryCry(id, agent, body, tick)
        -- [B20] Did the player come? Sampled while the window is
        -- open, because "did you show up" is the human measure of
        -- answering a cry - not whether you happened to be carrying a
        -- bandage. The offer verb needs them close anyway, so this
        -- catches the player who actually helped as well as the one
        -- who simply came running.
        if agent.criedAt and not agent.playerCame then
            local mePC = getSpecificPlayer(0)
            if mePC and not mePC:isDead() then
                local pcx = mePC:getX() - body:getX()
                local pcy = mePC:getY() - body:getY()
                if pcx * pcx + pcy * pcy
                    <= ARRIVAL_REACH * ARRIVAL_REACH then
                    agent.playerCame = true
                end
            end
        end
        -- [B20] And the reckoning, when nobody came. The crier judges
        -- by OUTCOME - they cannot see that a hearer was answering
        -- their own hunger, or is a loner, or was simply slower than
        -- the window. They know they called and nobody came, and the
        -- simulation should let a person be wronged by someone who
        -- did nothing wrong rather than quietly forgive on their
        -- behalf.
        if agent.criedAt and tick > agent.criedAt + 1800 then
            local answered = (agent.aidedAt or 0) >= agent.criedAt
            local heardList = agent.criedHeard or {}
            local playerCame = agent.playerCame
            agent.criedAt, agent.criedHeard = nil, nil
            agent.playerCame = nil
            if not answered and #heardList > 0 then
                local blamed = 0
                for _, hid in ipairs(heardList) do
                    local hAgent = Ctl.agents[hid]
                    -- Anyone who SET OUT is not blamed: being slow is
                    -- not the same as ignoring. And no faith is lost
                    -- in an enemy who failed to save you, because
                    -- there was none to lose.
                    local tried = hAgent and hAgent.aidTarget == id
                    -- The player is judged by the same rule, measured
                    -- by the same mercy: coming counts, exactly as a
                    -- housemate who set out is not blamed for being
                    -- slow.
                    if SAO.Standing.isPlayerKey(hid) then
                        tried = playerCame == true
                    end
                    if not tried
                        and not SAO.Standing.isHostileTo(id, hid) then
                        SAO.Standing.adjustTrust(id, hid, -0.10)
                        blamed = blamed + 1
                    end
                end
                if blamed > 0 then
                    pcall(function()
                        SAO.Lessons.learn(id, "trust-carefully",
                            0.6, "lived", nil)
                    end)
                    pcall(function()
                        SAO.Voice.onEvent(id, "unanswered", tick)
                    end)
                    log(id .. " called and nobody came - "
                        .. blamed .. " heard it")
                end
            end
        end
                    return
                end
            end
            -- Could not path away (or not permitted): hold ALERT facing it.
            setState(agent, id, "ALERT", "flee blocked; holding")
            return
        end
        setState(agent, id, "ALERT",
            string.format("believed threat at %.1f tiles (holds until %.1f)", threat.dist, fleeAt))
        return
    end

    -- No actionable threat beliefs.
    if agent.state == "FLEE" or agent.state == "ALERT" then
        setState(agent, id, "IDLE",
            SAO.Perception.hasLookedRecently(id, tick) and "believes clear" or "no recent look")
        return
    end

    -- One needs read per decision ([A15]): every appetite block below
    -- consumes this snapshot.
    local needs = SAO.Needs.read(body)

    -- Bleeding outranks every appetite: a wound left open is the fastest
    -- clock there is. Bandage in place when carrying one; without one,
    -- rip carried cloth into rags ([A10]); with neither, note it once and
    -- live with the odds.
    if agent.state == "IDLE" or agent.state == "ROAM" or agent.state == "HOMEWARD"
        or agent.state == "FOLLOW" then
        -- [B20] The cry. You shout BEFORE you start working on
        -- yourself - that is the order it happens in. [B20] made aid
        -- reach the right person and left the wounded unable to ask:
        -- aid gates on having SEEN them, so a medic behind a wall
        -- never knew.
        --
        -- Who calls out is who they are, not a flag on the wound. The
        -- same injury makes one person shout and another bite down -
        -- and someone carrying `noise-is-a-debt` knows exactly what a
        -- shout costs, so they deal with it alone.
        tryCry(id, agent, body, tick)
        -- The sick take their medicine ([B7]): a caught cold is the
        -- engine's own progression, and a survivor carrying pills
        -- takes them. Nothing conjured - the pills are real items the
        -- pockets machinery already spots for carers.
        if tick >= (agent.nextPillAt or 0) then
            local sick9 = 0
            pcall(function()
                sick9 = SAOJavaBridge:sickness(body)
            end)
            if sick9 and sick9 > 25 then
                agent.nextPillAt = tick + 7200
                if SAO.Needs.takePills(id, body) then
                    agent.taskDeadline = tick + 900
                    pcall(function()
                        SAO.Voice.onEvent(id, "sick", tick)
                    end)
                    setState(agent, id, "TREAT",
                        "takes something for the fever", "need")
                    return
                end
            end
        end
        -- The wound tended past the first dressing ([B7]): a fouled
        -- dressing gets changed and an infected wound gets cleaned
        -- with what they carry - before bleeding, because a bleed
        -- they already know how to answer and a fever they do not.
        if SAO.Needs.woundInfection(body) > 0
            and tick >= (agent.nextCleanAt or 0) then
            agent.nextCleanAt = tick + 3600
            if SAO.Needs.disinfectSelf(id, body) then
                local dLvl9 = SAO.Census.skillOf
                    and SAO.Census.skillOf(id, "Doctor") or 0
                if dLvl9 < 0 then dLvl9 = 0 end
                agent.taskDeadline = tick + math.max(600, 1800 - dLvl9 * 120)
                pcall(function()
                    SAO.Voice.onEvent(id, "cleanWound", tick)
                end)
                setState(agent, id, "TREAT", "cleans the wound", "need")
                return
            end
        end
        if SAO.Needs.dirtyBandages(body) > 0
            and tick >= (agent.nextRedressAt or 0) then
            agent.nextRedressAt = tick + 3600
            if SAO.Needs.bandageSelf(id, body) then
                agent.taskDeadline = tick + 1200
                setState(agent, id, "TREAT",
                    "changes a fouled dressing", "need")
                return
            end
        end
        if SAO.Needs.bleeding(body) > 0 then
            if SAO.Needs.bandageSelf(id, body) then
                -- Trained hands are faster ([B2]): the treat window
                -- reads the real Doctor level - a medic binds in half
                -- the time a fumbling cook needs.
                local dLvl = SAO.Census.skillOf
                    and SAO.Census.skillOf(id, "Doctor") or 0
                if dLvl < 0 then dLvl = 0 end
                agent.taskDeadline = tick
                    + math.max(600, 1800 - dLvl * 120)
                setState(agent, id, "TREAT", "bleeding: bandaging now"
                    .. (dLvl >= 5 and " (practiced hands)" or ""))
                return
            end
            -- No bandage: a spare shirt or sheet becomes rags. The time is
            -- charged in the RIP hold; the transform lands when it ends.
            local okR, canRip = pcall(function()
                return SAOJavaBridge:hasRippableCloth(body)
            end)
            if okR and canRip then
                agent.ripDoneAt = tick + 120
                setState(agent, id, "RIP", "bleeding: ripping cloth into rags")
                return
            end
            if not agent.notedNoBandage then
                agent.notedNoBandage = true
                log(id .. " is bleeding with nothing to bind it, and nothing to rip")
            end
        else
            agent.notedNoBandage = nil
        end
    end

    -- Thirst: the sharper clock, checked before hunger. Carried drink
    -- first; else walk to clean water and drink from it directly.
    if agent.state == "IDLE" or agent.state == "ROAM" or agent.state == "HOMEWARD" then
        if needs and needs.thirst >= SAO.Disposition.drinkAt(id) then
            if SAO.Needs.drinkCarried(id, body) then
                agent.taskDeadline = tick + 1800
                setState(agent, id, "DRINK",
                    string.format("thirst %.2f: drinks from pack", needs.thirst))
                return
            end
            if not agent.nextWaterAt or tick >= agent.nextWaterAt then
                local wx, wy, wz = SAO.Needs.findWater(id, body, policy().errandRadius)
                if wx and needs.thirst < policy().desperation + SAO.Lessons.desperationBump(id)
                    and not mayEnterBelieved(id, wx, wy) then
                    SAO.Needs.clearWater(body)
                    agent.nextWaterAt = tick + 600
                    log(id .. " will not drink from a claimed place (not desperate yet)")
                    wx = nil
                end
                if wx then
                    if SAO.Locomotion.order(id, body, wx, wy, wz) then
                        agent.taskDeadline = tick + 3600
                        setState(agent, id, "WATERWARD",
                            string.format("thirst %.2f: heads for water", needs.thirst))
                        return
                    end
                else
                    agent.nextWaterAt = tick + 600
                    log(id .. " is thirsty but knows of no clean water nearby")
                end
            end
        end
    end

    -- Hunger: below threats, above leisure. A hungry survivor eats what
    -- they carry; with empty pockets they seek food the loaded world
    -- actually holds - travel, take through the vanilla transfer, then eat.
    -- Interruptible: the EAT/TAKE hold itself watches believed threats.
    if agent.state == "IDLE" or agent.state == "ROAM" or agent.state == "HOMEWARD" then
        local eatBar = SAO.Disposition.eatAt(id)
        do
            -- Foragers hunt before hunger bites ([A19]): the sweep
            -- starts a tenth early - stocking is their job, not their
            -- stomach.
            local fRec = agent.rec
            if fRec and fRec.designation == "forager" then
                eatBar = math.max(0.1, eatBar - 0.1)
            end
        end
        if needs and needs.hunger >= eatBar then
            if SAO.Needs.eatCarried(id, body) then
                agent.taskDeadline = tick + 1800
                setState(agent, id, "EAT",
                    string.format("hunger %.2f: eats from pack", needs.hunger))
                return
            end
            if not agent.nextForageAt or tick >= agent.nextForageAt then
                local fx, fy, fz, fname = SAO.Needs.findSource(id, body, policy().errandRadius)
                -- Store enforcement ([A25]): under watch-first, a
                -- hungry non-watch member holds off on the COMMUNITY'S
                -- OWN stores a while longer - the watch eats first.
                -- Desperation overrides; policy never starves anyone.
                if fx then
                    local fRec2 = agent.rec
                    local fG = SAO.Standing.groupOf(id)
                    if fG and SAO.Standing.rationPolicyOf(fG) == "watch-first"
                        and fRec2 and fRec2.designation ~= "watch"
                        and SAO.Standing.insideClaim(id, fx, fy)
                        and needs.hunger < eatBar + 0.10
                        and needs.hunger < policy().desperation then
                        SAO.Needs.clearSource(body)
                        agent.nextForageAt = tick + 600
                        log(id .. " waits on the stores - the watch eats first")
                        fx = nil
                    end
                end
                -- Another person's claim stands between a hungry survivor
                -- and their food - unless hunger has passed desperation.
                if fx and needs.hunger < policy().desperation + SAO.Lessons.desperationBump(id)
                    and not mayEnterBelieved(id, fx, fy) then
                    SAO.Needs.clearSource(body)
                    agent.nextForageAt = tick + 600
                    log(id .. " will not take food from a claimed place (not desperate yet)")
                    fx = nil
                end
                if fx then
                    if SAO.Locomotion.order(id, body, fx, fy, fz) then
                        agent.taskDeadline = tick + 3600
                        setState(agent, id, "FORAGE",
                            string.format("hunger %.2f: heads for %s", needs.hunger,
                                tostring(fname)))
                        return
                    end
                else
                    -- Nothing edible loaded nearby; do not spin the scan.
                    agent.nextForageAt = tick + 600
                    log(id .. " is hungry but knows of no food nearby")
                end
            end
        end
    end

    -- Aid ([A19], C4): the bleeding are seen. A medic on their rounds,
    -- a carer by nature, the bonded, or anyone who has watched someone
    -- bleed out (bind-wounds-fast) walks to a hurt fellow and hands
    -- over a bandage - the vanilla transfer; the wounded bind
    -- themselves. Aid is delivery, never puppetry.
    if agent.state == "IDLE" or agent.state == "ROAM" then
        if not agent.nextAidAt or tick >= agent.nextAidAt then
            agent.nextAidAt = tick + 600
            local aidRec = agent.rec
            local aidDesig = aidRec and aidRec.designation
            local aidCarer = SAO.Census and SAO.Census.classOf
                and SAO.Census.classOf(aidRec and aidRec.occupation) == "carer"
            local urgentAider = SAO.Lessons.has(id, "bind-wounds-fast")
            local aidBeliefs = SAO.Perception.beliefs[id]
            if aidBeliefs then
                -- [B20] Triage. This used to take the FIRST
                -- believed-hurt person out of `pairs()` - an order
                -- Lua explicitly does not define - and return. A
                -- scratch and an arterial bleed had equal claim on
                -- the only trained hand in the house.
                --
                -- Severity was never the hard part: the code already
                -- read bleeding and infection off the real body. It
                -- simply never COMPARED them. Its own mirror put the
                -- number on it - the worst-hurt person got nobody in
                -- 14% of casualty scenes.
                local claimedByOthers = {}
                for oid, oag in pairs(Ctl.agents) do
                    if oid ~= id and oag.state == "MEDICWARD"
                        and oag.aidTarget then
                        claimedByOthers[oag.aidTarget] = true
                    end
                end
                local bestKey, bestName, bestBody = nil, nil, nil
                local bestSev, bestFever, bestDist = -1e9, 0, 0
                for name, belief in pairs(aidBeliefs.people) do
                    -- [B20] A cry counts. This gated on "observed"
                    -- alone, which is why a medic behind a wall never
                    -- came: the whole apparatus was blind to anyone it
                    -- could not see.
                    if (belief.source == "observed"
                        or belief.source == "heard")
                        and (tick - belief.at) <= 120
                        and not belief.dead
                        and belief.condition
                        and string.find(belief.condition, "bad", 1, true) then
                        local hurtKey = SAO.Standing.keyForObserved(name)
                        -- [B20] Your own house is a reason. The
                        -- gate was medic / carer / bind-wounds-fast /
                        -- bonded - "the trained and the close" -
                        -- which is right for a stranger and wrong for
                        -- someone you share a larder with. Its own
                        -- mirror measured the cost: 38% of casualty
                        -- scenes had NOBODY eligible, and 363
                        -- bleeding people across the sweep were
                        -- simply walked past by their own company.
                        -- Trust already governs every other question
                        -- of who does what for whom here.
                        local mayAid = aidDesig == "medic" or aidCarer
                            or urgentAider
                            or SAO.Standing.isBondedTo(id, hurtKey)
                            or (SAO.Standing.sameGroup(id, hurtKey)
                                and SAO.Standing.trust(id, hurtKey) > 0.3)
                        if mayAid and hurtKey ~= id
                            and not SAO.Standing.isHostileTo(id, hurtKey) then
                            local hurtBody = bodyForKey(hurtKey)
                            if hurtBody then
                                local hdx = hurtBody:getX() - body:getX()
                                local hdy = hurtBody:getY() - body:getY()
                                local hd = math.sqrt(hdx * hdx + hdy * hdy)
                                if hd <= 15.0 then
                                    local okBl, bleedN = pcall(function()
                                        return SAOJavaBridge:getBleedingCount(hurtBody)
                                    end)
                                    -- The medic answers fever too
                                    -- ([B7]): a wound gone bad is the
                                    -- call a trained hand exists for,
                                    -- and it outranks a wound still
                                    -- clean.
                                    local fever9 = 0
                                    pcall(function()
                                        fever9 = SAOJavaBridge
                                            :woundInfection(hurtBody)
                                    end)
                                    bleedN = (okBl and tonumber(bleedN)) or 0
                                    fever9 = tonumber(fever9) or 0
                                    if bleedN > 0 or fever9 > 0 then
                                        local sev = bleedN + 2.0 * fever9
                                        -- Someone already walking to
                                        -- them is a reason to look at
                                        -- the others FIRST, not a
                                        -- reason nobody else ever
                                        -- can. Demoted, never barred -
                                        -- so a lone casualty still
                                        -- gets everyone.
                                        if claimedByOthers[hurtKey] then
                                            sev = sev - 100.0
                                        end
                                        if sev > bestSev then
                                            bestSev = sev
                                            bestKey, bestName = hurtKey, name
                                            bestBody = hurtBody
                                            bestFever, bestDist = fever9, hd
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if bestKey then
                    if bestDist <= 2.5 then
                        if bestFever > 0
                            and SAO.Needs.shareDisinfectantWith(
                                id, body, bestBody) then
                            do
                                local aidedAgent = Ctl.agents[bestKey]
                                if aidedAgent then
                                    aidedAgent.aidedAt = tick
                                end
                            end
                            SAO.Standing.adjustTrust(bestKey, id, 0.15)
                            pcall(function()
                                SAOJavaBridge:grantXP(
                                    body, "Doctor", 1.5)
                            end)
                            pcall(function()
                                SAO.Voice.onEvent(id, "aid", tick)
                            end)
                            log(id .. " gives " .. bestName
                                .. " something for the fever")
                        elseif SAO.Needs.aidWound(
                                id, body, bestBody) then
                            -- [B20] Someone came. Stamped on the
                            -- person AIDED, because the reckoning is
                            -- theirs to run, not the aider's.
                            do
                                local aidedAgent = Ctl.agents[bestKey]
                                if aidedAgent then
                                    aidedAgent.aidedAt = tick
                                end
                            end
                            SAO.Standing.adjustTrust(bestKey, id, 0.15)
                            SAO.Standing.adjustTrust(id, bestKey, 0.03)
                            pcall(function()
                                SAOJavaBridge:grantXP(body, "Doctor", 1.5)
                            end)
                            pcall(function()
                                SAO.Voice.onEvent(id, "aid", tick)
                            end)
                            log(id .. " hands a bandage to " .. bestName)
                        end
                    elseif SAO.Locomotion.order(id, body,
                            math.floor(bestBody:getX()),
                            math.floor(bestBody:getY()),
                            math.floor(bestBody:getZ())) then
                        agent.aidTarget = bestKey
                        agent.taskDeadline = tick + 1800
                        setState(agent, id, "MEDICWARD",
                            "walks to hurt " .. bestName,
                            aidDesig == "medic" and "designation" or nil)
                        return
                    end
                end
            end
        end
    end

    -- The dead are seen: a KNOWN survivor's corpse in passing is mourned
    -- once per mourner. Grief is spoken; the dead's own recorded enemies
    -- inherit a shadow of suspicion - posthumous testimony, at testimony
    -- weight. Then the living keep moving.
    if agent.state == "IDLE" or agent.state == "ROAM" then
        if not agent.nextCorpseAt or tick >= agent.nextCorpseAt then
            agent.nextCorpseAt = tick + 900
            local okC, corpses = pcall(function()
                return SAOJavaBridge:findNamedCorpses(body, 6)
            end)
            if okC and type(corpses) == "string" and corpses ~= "" then
                agent.mourned = agent.mourned or {}
                for entry in string.gmatch(corpses, "[^|]+") do
                    local name, cxs, cys = string.match(entry, "^([^:]+):(%-?%d+):(%-?%d+)$")
                    local deadId = name and SAO.Identity.idByName(name)
                    local deadRec = deadId and SAO.Identity.get(deadId)
                    if deadRec and deadRec.dead and deadId ~= id
                        and not agent.mourned[deadId] then
                        local cx2, cy2 = tonumber(cxs), tonumber(cys)
                        local ddx = cx2 - body:getX()
                        local ddy = cy2 - body:getY()
                        local cdist = math.sqrt(ddx * ddx + ddy * ddy)
                        -- [B47] Arrival, spelled 2.5 by drift. This
                        -- asks "am I already at the body, or must I
                        -- walk there first" - the same question
                        -- ARRIVAL_REACH answers everywhere else. Half
                        -- a tile is not a distinction anyone chose in
                        -- a world that moves in whole ones.
                        if cdist > ARRIVAL_REACH then
                            -- Walk to the body first: grief is a pause in
                            -- the day, not a drive-by line.
                            if SAO.Locomotion.order(id, body, cx2, cy2,
                                math.floor(body:getZ())) then
                                agent.mournTarget = deadId
                                agent.mournName = name
                                agent.taskDeadline = tick + 1800
                                setState(agent, id, "MOURNWARD",
                                    "walks to where " .. name .. " lies")
                                return
                            end
                        else
                            agent.mourned[deadId] = true
                            local bondedLoss = SAO.Standing.isBondedTo(id, deadId)
                            agent.mournHoldUntil = tick + (bondedLoss and 400 or 200)
                            agent.mournTarget = deadId
                            agent.mournName = name
                            setState(agent, id, "MOURNING",
                                "stands over " .. name)
                            return
                        end
                    end
                end
            end
        end
    end

    -- The habit ([A14] S6): a smoker whose withdrawal bites lights one up
    -- through the same vanilla action meals use. Craving sits below real
    -- needs - nobody smokes instead of bleeding.
    if agent.state == "IDLE" or agent.state == "ROAM" then
        if SAO.Disposition.isSmoker(id) then
            if needs and (needs.nicotine or 0) >= 0.3
                and SAO.Needs.smokeCarried(id, body) then
                agent.taskDeadline = tick + 1200
                setState(agent, id, "EAT", "smoke break")
                return
            end
        end
    end

    -- A gift on the ground: something useful within arm's reach gets
    -- picked up through the vanilla grab (leisure priority - the needy
    -- already found their own food above). Attribution happens at grab
    -- completion: a person SEEN here recently made this a kindness.
    if agent.state == "IDLE" or agent.state == "ROAM" then
        if not agent.nextOfferedAt or tick >= agent.nextOfferedAt then
            agent.nextOfferedAt = tick + 600
            local offeredName = SAO.Needs.findOffered(id, body)
            if offeredName and SAO.Needs.queueGrabOffered(id, body) then
                agent.taskDeadline = tick + 900
                agent.takePurpose = "offered"
                setState(agent, id, "TAKE", "picks up " .. offeredName)
                return
            end
        end
    end

    -- The companion: everything the trust web builds toward. An UNGROUPED
    -- survivor whose trust in the player crossed the company line, with
    -- the player freshly SEEN nearby, walks with them - offered aloud
    -- once, resumed quietly after. Their own beliefs still govern fear
    -- and fight; companionship is a route choice, not a leash. They part
    -- (aloud) when trust falls or the player has been gone a while.
    if (agent.state == "IDLE" or agent.state == "ROAM"
        or agent.state == "PLAYERFOLLOW") then
        local me = getSpecificPlayer(0)
        local myKey = SAO.Standing.playerKey(me)
        -- Costly conversion ([A17]): a GROUPED survivor walks with the
        -- player only by LEAVING their faction - and only when they
        -- trust the player clearly more than their own people on
        -- average. The people remember who took them (-0.1 toward the
        -- player each), leadership reruns, and they keep their own home.
        local convGroup = SAO.Standing.groupOf(id)
        if myKey and convGroup and not agent.companioning then
            local trustPlayer = SAO.Standing.trust(id, myKey)
            local fellows = SAO.Standing.fellowsOf(id)
            if #fellows > 0 and trustPlayer > policy().trustToCompany then
                local sum = 0
                for _, fid in ipairs(fellows) do
                    sum = sum + SAO.Standing.trust(id, fid)
                end
                local avg = sum / #fellows
                if trustPlayer > avg + 0.15 then
                    local groupName = convGroup
                    for _, fid in ipairs(fellows) do
                        SAO.Standing.adjustTrust(fid, myKey, -0.1)
                    end
                    SAO.Standing.leaveGroup(id)
                    pcall(function() SAO.Voice.onEvent(id, "companion", tick) end)
                    log(id .. " leaves " .. tostring(groupName)
                        .. " to walk with the player - their people remember")
                end
            end
        end
        if myKey and not SAO.Standing.groupOf(id) then
            local trustInPlayer = SAO.Standing.trust(id, myKey)
            local pb = SAO.Perception.beliefs[id]
            local seenPlayer = nil
            if pb then
                for pname, belief in pairs(pb.people) do
                    if SAO.Standing.keyForObserved(pname) == myKey
                        and belief.source == "observed" then
                        seenPlayer = belief
                        break
                    end
                end
            end
            local playerFresh = seenPlayer and (tick - seenPlayer.at) <= 1800
            if trustInPlayer > policy().trustToCompany and playerFresh then
                local px2, py2 = me:getX(), me:getY()
                local pdx, pdy = px2 - body:getX(), py2 - body:getY()
                local pdist = math.sqrt(pdx * pdx + pdy * pdy)
                if not agent.companioning then
                    agent.companioning = true
                    -- [B18] They come home with you, if you have one.
                    pcall(function()
                        local pc = SAO.Standing.claimOf(myKey)
                        if pc and agent.rec then
                            agent.rec.homeX =
                                math.floor((pc.minX + pc.maxX) / 2)
                            agent.rec.homeY =
                                math.floor((pc.minY + pc.maxY) / 2)
                            agent.rec.homeZ = pc.z or 0
                            log(id .. " will come home to your ground")
                        end
                    end)
                    pcall(function() SAO.Voice.onEvent(id, "companion", tick) end)
                    log(id .. " chooses to walk with the player")
                end
                -- Companion orders ([A24]): a held companion does not
                -- follow - they hold the spot you asked, legibly, until
                -- released. Their own threats/needs still outrank the
                -- hold (everything above this block already returned).
                if agent.holdPosition then
                    if agent.state == "PLAYERFOLLOW" then
                        SAO.Locomotion.cancel(id)
                        setState(agent, id, "IDLE", "holds where you asked")
                    end
                    if not agent.pressure
                        or tick - (agent.pressure.at or 0) > 600 then
                        agent.pressure = { answer = "designation",
                            detail = "holds where you asked", at = tick }
                    end
                    return
                end
                local companionGap = SAO.Disposition.followGap(id)
                if agent.followTight then
                    companionGap = math.max(2.0, companionGap * 0.5)
                end
                if pdist > companionGap and pdist <= 30.0 then
                    local gx = math.floor(px2 + ZombRand(-1, 2))
                    local gy = math.floor(py2 + ZombRand(-1, 2))
                    if SAO.Locomotion.order(id, body, gx, gy, math.floor(me:getZ())) then
                        setState(agent, id, "PLAYERFOLLOW",
                            string.format("walks with the player (%.0f back)", pdist))
                        return
                    end
                elseif agent.state == "PLAYERFOLLOW" and pdist <= companionGap then
                    SAO.Locomotion.cancel(id)
                    setState(agent, id, "IDLE", "beside the player")
                end
                -- [B19] What you teach them: [B11] made housemates
                -- teach each other and left the PLAYER out, though a
                -- player is an IsoPlayer with real perk levels. Same
                -- margin, same rate, same hour - your competence is
                -- something your people can get from you.
                if pdist <= 4.0 and tick >= (agent.nextTaughtByPlayerAt or 0) then
                    agent.nextTaughtByPlayerAt = tick + 3600
                    pcall(function()
                        -- [B20] The shared table - see
                        -- Census.JOB_PERK.
                        local JOB_PERK33 = SAO.Census.JOB_PERK or {}
                        local rec33 = agent.rec
                        local perk33 = rec33 and rec33.designation
                            and JOB_PERK33[rec33.designation] or "Foraging"
                        local theirs33 = SAO.Census.skillOf(id, perk33)
                        -- `Perks.<Name>` is the surface vanilla's own
                        -- Lua uses (ISHarvestPlantAction reads
                        -- Perks.Farming); PerkFactory.PerkList is a
                        -- JAVA-side list our bridge uses and is not
                        -- what Lua should reach for. Caught by the
                        -- undeclared audit the moment it appeared.
                        local mine33 = -1
                        local perkObj33 = Perks and Perks[perk33] or nil
                        if perkObj33 then
                            mine33 = me:getPerkLevel(perkObj33)
                        end
                        if mine33 >= 0 and theirs33 >= 0
                            and mine33 >= theirs33 + 3 then
                            SAOJavaBridge:grantXP(body, perk33, 6.0)
                            SAO.Standing.adjustTrust(id, myKey, 0.02)
                            SAO.Voice.onEvent(id, "learning", tick)
                            log(id .. " learns " .. perk33
                                .. " from you (" .. mine33 .. " to "
                                .. theirs33 .. ")")
                        end
                    end)
                end
            elseif agent.companioning then
                agent.companioning = nil
                pcall(function() SAO.Voice.onEvent(id, "parting", tick) end)
                log(id .. " parts ways with the player ("
                    .. (playerFresh and "trust faded" or "player long gone") .. ")")
                if agent.state == "PLAYERFOLLOW" then
                    SAO.Locomotion.cancel(id)
                    setState(agent, id, "IDLE", "parted ways")
                end
            end
        end
    end

    -- Keeping company: the lexically greater id follows the lesser (a
    -- deterministic anchor prevents two people walking at each other
    -- forever). Follows only a fellow who is HERE - a dormant fellow is
    -- remembered, not followed. Leisure-priority: threats and hunger above
    -- already returned out of this tick.
    if agent.state == "IDLE" or agent.state == "ROAM" or agent.state == "FOLLOW" then
        local fellows = SAO.Standing.fellowsOf(id)
        local myGroupName = SAO.Standing.groupOf(id)
        local leaderId = myGroupName and SAO.Standing.leaderOf(myGroupName) or nil
        local anchor, anchorBody, anchorDist
        -- The group defers to its leader: a present leader anchors
        -- everyone else ([A14] S3). Leaderless moments fall back to the
        -- deterministic lexical chain.
        -- The escort ([B1]): "can't stop you, won't let you go
        -- alone" outranks the ambient anchor while the search runs.
        -- Cleared the moment the searcher is no longer searching.
        if agent.escortId then
            local sAgent = Ctl.agents[agent.escortId]
            -- [B19] The escort was built for ONE errand - it dropped
            -- unless the person ahead was searching. Company on any
            -- announced venture is the same act, so the same
            -- machinery carries it.
            if not sAgent
                or (sAgent.state ~= "SEARCHWARD"
                    and not (sAgent.state == "ROAM"
                        and sAgent.onVenture)) then
                agent.escortId = nil
            else
                local ebody = SAO.Body.get(agent.escortId)
                if ebody then
                    local dx = ebody:getX() - body:getX()
                    local dy = ebody:getY() - body:getY()
                    anchor, anchorBody, anchorDist = agent.escortId,
                        ebody, math.sqrt(dx * dx + dy * dy)
                end
            end
        end
        if not anchorBody and leaderId and leaderId ~= id then
            local lbody = SAO.Body.get(leaderId)
            if lbody then
                local dx = lbody:getX() - body:getX()
                local dy = lbody:getY() - body:getY()
                anchor, anchorBody, anchorDist =
                    leaderId, lbody, math.sqrt(dx * dx + dy * dy)
            end
        end
        if not anchorBody and (not leaderId or leaderId ~= id) then
            for i = 1, #fellows do
                local fid = fellows[i]
                if fid < id then
                    local fbody = SAO.Body.get(fid)
                    if fbody then
                        local dx = fbody:getX() - body:getX()
                        local dy = fbody:getY() - body:getY()
                        local d = math.sqrt(dx * dx + dy * dy)
                        if not anchorDist or d < anchorDist then
                            anchor, anchorBody, anchorDist = fid, fbody, d
                        end
                    end
                end
            end
        end
        if anchorBody then
            agent.hasLiveAnchor = true
            local gap = SAO.Disposition.followGap(id)
            if anchor and SAO.Standing.isBondedTo(id, anchor) then
                gap = math.max(2.0, gap * 0.5)   -- the bonded walk close
            end
            if anchorDist > gap then
                -- Aim beside the anchor, not on top of it.
                local gx = math.floor(anchorBody:getX() + ZombRand(-1, 2))
                local gy = math.floor(anchorBody:getY() + ZombRand(-1, 2))
                if SAO.Locomotion.order(id, body, gx, gy, anchorBody:getZ()) then
                    setState(agent, id, "FOLLOW",
                        string.format("keeps pace with %s (%.0f tiles back)",
                            anchor, anchorDist))
                    return
                end
            elseif agent.state == "FOLLOW" then
                SAO.Locomotion.cancel(id)
                setState(agent, id, "IDLE", "walking beside " .. anchor)
            end
        else
            agent.hasLiveAnchor = false
            if agent.state == "FOLLOW" then
                SAO.Locomotion.cancel(id)
                setState(agent, id, "IDLE", "company is elsewhere; stays put")
            end
        end
    end

    -- Dusk homing: a person with an address heads for it as night falls -
    -- before the night hold, not instead of it. Threats already returned above.
    -- A follower whose anchor is present stays with the company instead;
    -- their fellow IS where they belong tonight.
    local rec = agent.rec
    if agent.state == "IDLE" and rec.homeX and not agent.hasLiveAnchor
        and not agent.companioning then
        -- Households consolidate around leadership ([A14]): a grouped
        -- survivor's night belongs at the LEADER's address when one is
        -- settled; the solitary keep their own.
        local homeX, homeY, homeZ = rec.homeX, rec.homeY, rec.homeZ
        local homeGroup = SAO.Standing.groupOf(id)
        local homeLeader = homeGroup and SAO.Standing.leaderOf(homeGroup) or nil
        if homeLeader and homeLeader ~= id then
            local leaderRec = SAO.Identity.get(homeLeader)
            if leaderRec and leaderRec.homeX then
                homeX, homeY, homeZ = leaderRec.homeX, leaderRec.homeY, leaderRec.homeZ
            end
        end
        local okH, hour = pcall(function() return GameTime.getInstance():getTimeOfDay() end)
        if okH and (hour >= 20.0 or hour < 6.0) then
            local bx, by = body:getX(), body:getY()
            local dh = math.sqrt((homeX - bx) ^ 2 + (homeY - by) ^ 2)
            if dh > 10.0 then
                pcall(function() SAOJavaBridge:setForceEntry(body, false) end)
                if SAO.Locomotion.order(id, body, homeX, homeY, homeZ or 0) then
                    setState(agent, id, "HOMEWARD",
                        string.format("night falls, home is %.0f tiles away", dh))
                    return
                end
            end
        end
    end

    -- Gearing up: a survivor who knows of a clearly better weapon nearby
    -- goes and takes it. Leisure priority with its own night hold - nobody
    -- shops for bats in the dark. Threats and needs already won the tick.
    if agent.state == "IDLE" then
        local okGH, gearHour = pcall(function() return GameTime.getInstance():getTimeOfDay() end)
        local nightNow = okGH and (gearHour >= 22.0 or gearHour < 6.0)
        if not nightNow and (not agent.nextGearAt or tick >= agent.nextGearAt) then
            agent.nextGearAt = tick + 3600
            local gx, gy, gz, gname = SAO.Needs.findGear(id, body, policy().errandRadius)
            if gx and not mayEnterBelieved(id, gx, gy) then
                SAO.Needs.clearGear(body)
                log(id .. " covets a weapon in a claimed place; wanting is not taking")
                gx = nil
            end
            if gx and SAO.Locomotion.order(id, body, gx, gy, gz) then
                agent.taskDeadline = tick + 3600
                setState(agent, id, "GEARWARD",
                    "knows of a better weapon: " .. tostring(gname))
                return
            end
        end
    end

    -- Feeding the gun: a dry firearm with nothing loadable is an errand
    -- of the same shape as gearing up - leisure, night-held, claims
    -- respected. The reload itself happens when combat or the RELOAD flow
    -- next needs it; this errand only fills the pack.
    if agent.state == "IDLE" then
        local okAH, ammoHour = pcall(function() return GameTime.getInstance():getTimeOfDay() end)
        local ammoNight = okAH and (ammoHour >= 22.0 or ammoHour < 6.0)
        if not ammoNight and (not agent.nextAmmoAt or tick >= agent.nextAmmoAt)
            and SAO.Needs.needsAmmo(body) then
            agent.nextAmmoAt = tick + 3600
            local ax, ay, az, aname = SAO.Needs.findAmmo(id, body, policy().errandRadius)
            if ax and not mayEnterBelieved(id, ax, ay) then
                SAO.Needs.clearAmmo(body)
                log(id .. " knows of ammo in a claimed place; wanting is not taking")
                ax = nil
            end
            if ax and SAO.Locomotion.order(id, body, ax, ay, az) then
                agent.taskDeadline = tick + 3600
                setState(agent, id, "AMMOWARD",
                    "gun is dry - heads for " .. tostring(aname))
                return
            end
        end
    end

    -- Settlement (S4): the settled LEADER of a faction of three or more
    -- with no base yet names the faction (once), scouts the best loaded
    -- building (audited scoring, rejection memory), and WALKS to it. The
    -- claim lands on arrival - a place is taken by standing in it.
    if agent.state == "IDLE" then
        local sGroup = SAO.Standing.groupOf(id)
        -- The scout is the leader - or, when the settled leader is a
        -- PASSIVE inhabitant whose body is not ours to walk ([A17]), the
        -- company's shell member scouts on their behalf: mixed factions
        -- settle too.
        local sLeader = sGroup and SAO.Standing.leaderOf(sGroup) or nil
        local leaderAgent = sLeader and Ctl.agents[sLeader] or nil
        local scoutsForCompany = sLeader == id
            or (leaderAgent and leaderAgent.passive and not agent.passive)
        if sGroup and scoutsForCompany
            and not SAO.Standing.groupClaimOf(sGroup) then
            local members = SAO.Standing.fellowsOf(id)
            if #members >= 2 then
                if not SAO.Standing.factionName(sGroup) then
                    local name = SAO.Standing.nameFaction(
                        sGroup, agent.rec and agent.rec.originRegion or nil)
                    pcall(function() SAO.Voice.onEvent(id, "factionBorn", tick) end)
                    log(sGroup .. " becomes '" .. tostring(name) .. "' ("
                        .. (#members + 1) .. " members)")
                end
                if not agent.nextScoutAt or tick >= agent.nextScoutAt then
                    agent.nextScoutAt = tick + 3600
                    local okS, found = pcall(function()
                        return SAOJavaBridge:scoutBase(body, agent.rejectedBases or "")
                    end)
                    if okS and type(found) == "string" and found ~= "" then
                        -- [B52] Ten fields, not six. `SAOSettlement`
                        -- packs `bx:by:bw:bh:cx:cy:rooms:area:water:score`
                        -- and this read the position and dropped the
                        -- REASONING - which is not spare data, it is
                        -- the score that chose this building over every
                        -- other one the scout could see. Border 15 has
                        -- printed `scoutBase: prefix 6/10` on every run
                        -- of the gate saying so.
                        local bx, by, bw, bh, cx2, cy2,
                            brooms, barea, bwater, bscore =
                            string.match(found,
                                "^(%-?%d+):(%-?%d+):(%d+):(%d+):(%-?%d+):"
                                .. "(%-?%d+):(%d+):(%d+):([01]):([%d%.%-]+)$")
                        -- No settling in a feud's shadow ([A20]): the
                        -- scout knows who the company's enemies are
                        -- (standing truth); a candidate within 30 tiles
                        -- of an enemy's claim is rejected and
                        -- remembered.
                        -- Occupied ground is not a candidate ([A24]):
                        -- another LIVING company's claim - or a living
                        -- person's home - is never claimed over by
                        -- scouting oversight. Contested ground comes
                        -- from politics, not blindness. (The claim
                        -- rects are the world-read edge, [A15].)
                        if bx then
                            local fcx0, fcy0 = tonumber(cx2), tonumber(cy2)
                            for og, oc in pairs(SAO.Standing.allGroupClaims()) do
                                if og ~= sGroup
                                    and fcx0 >= oc.minX and fcx0 <= oc.maxX
                                    and fcy0 >= oc.minY and fcy0 <= oc.maxY then
                                    agent.rejectedBases = (agent.rejectedBases
                                        and (agent.rejectedBases .. ";") or "")
                                        .. bx .. "," .. by
                                    log(id .. " will not claim over "
                                        .. tostring(SAO.Standing.factionName(og)
                                            or og) .. "'s ground")
                                    bx = nil
                                    break
                                end
                            end
                        end
                        if bx then
                            local fcx1, fcy1 = tonumber(cx2), tonumber(cy2)
                            for owner, oc in pairs(
                                SAO.Standing.allPersonalClaims()) do
                                -- [B35] The player holds ground under a
                                -- player: key and has no Identity record,
                                -- so this read nil and the survivor
                                -- claimed straight over the player's
                                -- base. Same guard, same mistake, second
                                -- place: written to skip the DEAD, it
                                -- skipped the one owner who is never
                                -- dead.
                                local orec = SAO.Identity.get(owner)
                                if (SAO.Standing.isPlayerKey(owner)
                                    or (orec and not orec.dead))
                                    and fcx1 >= oc.minX and fcx1 <= oc.maxX
                                    and fcy1 >= oc.minY and fcy1 <= oc.maxY then
                                    agent.rejectedBases = (agent.rejectedBases
                                        and (agent.rejectedBases .. ";") or "")
                                        .. bx .. "," .. by
                                    log(id .. " will not claim over "
                                        .. tostring(orec.forename) .. "'s home")
                                    bx = nil
                                    break
                                end
                            end
                        end
                        if bx then
                            local fcx, fcy = tonumber(cx2), tonumber(cy2)
                            for enemyGroup, ec in pairs(
                                SAO.Standing.allGroupClaims()) do
                                if enemyGroup ~= sGroup
                                    and SAO.Standing.feudBetween(sGroup, enemyGroup)
                                    and fcx >= ec.minX - SAO.Standing.FEUD_KEEP_OUT
                                    and fcx <= ec.maxX + SAO.Standing.FEUD_KEEP_OUT
                                    and fcy >= ec.minY - SAO.Standing.FEUD_KEEP_OUT
                                    and fcy <= ec.maxY + SAO.Standing.FEUD_KEEP_OUT then
                                    agent.rejectedBases = (agent.rejectedBases
                                        and (agent.rejectedBases .. ";") or "")
                                        .. bx .. "," .. by
                                    log(id .. " will not settle in "
                                        .. tostring(SAO.Standing.factionName(enemyGroup)
                                            or enemyGroup) .. "'s shadow (feud)")
                                    bx = nil
                                    break
                                end
                            end
                        end
                        if bx and SAO.Locomotion.order(id, body,
                            tonumber(cx2), tonumber(cy2), 0) then
                            agent.settleCandidate = {
                                minX = tonumber(bx), minY = tonumber(by),
                                maxX = tonumber(bx) + tonumber(bw),
                                maxY = tonumber(by) + tonumber(bh),
                                cx = tonumber(cx2), cy = tonumber(cy2),
                            }
                            agent.taskDeadline = tick + 5400
                            pcall(function()
                                SAO.Voice.onEvent(id, "settleScout", tick)
                            end)
                            -- Say WHY this building and not another.
                            -- The whole claim of this framework is that
                            -- nothing is scripted and a decision follows
                            -- from facts; a decision whose reasons are
                            -- computed, sent, and thrown away is
                            -- indistinguishable from one that was.
                            log(id .. " picks a base at " .. tostring(bx)
                                .. "," .. tostring(by) .. ": "
                                .. tostring(brooms) .. " rooms, "
                                .. tostring(barea) .. " area, "
                                .. (bwater == "1" and "water"
                                    or "no water")
                                .. ", score " .. tostring(bscore))
                            setState(agent, id, "SETTLEWARD",
                                "scouts a base for " .. tostring(
                                    SAO.Standing.factionName(sGroup)))
                            return
                        end
                    end
                end
            end
        end
    end

    -- Idle life: initiative-gated roaming. Short walks on a long personal
    -- cadence; Standing gates the destination like any other goal.
    if agent.state == "IDLE" then
        -- Night hold: people do not stroll in the dark. Threat responses are
        -- untouched; only leisure movement pauses. At home, the hold has a
        -- shape: the evening seat. Stood up from the moment anything
        -- matters (every path out of IDLE stands first).
        local okH, hour = pcall(function() return GameTime.getInstance():getTimeOfDay() end)
        if okH and (hour >= 22.0 or hour < 6.0) then
            if not agent.resting
                and SAO.Standing.insideClaim(id, body:getX(), body:getY()) then
                agent.resting = true
                agent.pressure = { answer = "chosen rest",
                    detail = "the evening seat, door in view", at = tick }
                pcall(function() body:setSitOnGround(true) end)
                log(id .. " settles in for the night")
            end
            -- Sleep proper (F-016): tired enough, at home, seated - the
            -- flag is safe-but-inert off-slot, so recovery is charged
            -- here in real ticks at engine-approximate rates. Waking is
            -- handled where every exit already is: setState stands AND
            -- wakes; the threat branch above outranks this whole block.
            if agent.resting then
                -- Cold outranks sleep ([B6]): nobody sleeps through
                -- freezing. Severe cold breaks the rest so the hearth
                -- block below can answer it; mild cold does not - the
                -- tired sleep through a chill like anyone.
                if SAO.Needs.cold(body) >= 1.5 then
                    agent.resting = nil
                    if agent.sleeping then
                        agent.sleeping = nil
                        pcall(function()
                            SAOJavaBridge:setShellAsleep(body, false)
                        end)
                    end
                    pcall(function() body:setSitOnGround(false) end)
                    log(id .. " wakes - too cold to sleep")
                    setState(agent, id, "IDLE", "woken by the cold", "need")
                    return
                end
                -- [B19] Somebody sits up. Decided ONCE per night,
                -- not once per tick - a full housemate scan every
                -- tick is exactly what the [B5] audit convicted.
                local okNH, nh = pcall(function()
                    return GameTime.getInstance():getWorldAgeHours()
                end)
                -- The +2 is not a fudge: a night runs 22:00 to
                -- 06:00, so it STRADDLES midnight. Bucketing on the
                -- raw hour would have swapped the keeper at 00:00
                -- every night - two shifts by accident rather than
                -- one keeper by design. Shift the boundary out of
                -- the dark and a night is one night.
                local nightIdx = okNH and math.floor((nh + 2) / 24) or 0
                if agent.keeperNight ~= nightIdx then
                    agent.keeperNight = nightIdx
                    agent.keeperTonight = false
                    local gK = SAO.Standing.groupOf(id)
                    -- Only a house with something to keep posts
                    -- anyone. Nothing to lose and nothing near it
                    -- sleeps, all of it.
                    local worth = gK and (
                        (SAO.Standing.larderOf
                            and SAO.Standing.larderOf(gK))
                        or (SAO.Standing.waterStoreOf
                            and SAO.Standing.waterStoreOf(gK))
                        or (SAO.Standing.hearthOf
                            and SAO.Standing.hearthOf(gK))) or nil
                    if not worth then
                        worth = SAO.Perception.believedThreatCount(
                            id, tick, 20, body:getX(), body:getY()) > 0
                    end
                    if worth then
                        agent.keeperTonight =
                            (nightKeeper(id, nightIdx) == id)
                    end
                end
                if agent.keeperTonight then
                    if agent.sleeping then
                        agent.sleeping = nil
                        agent.lastRestHours = nil
                        pcall(function()
                            SAOJavaBridge:setShellAsleep(body, false)
                        end)
                    end
                    agent.pressure = { answer = "designation",
                        detail = "sits up - the house sleeps blind"
                            .. " otherwise", at = tick }
                    if not agent.saidWatchAt
                        or tick - agent.saidWatchAt > 36000 then
                        agent.saidWatchAt = tick
                        pcall(function()
                            SAO.Voice.onEvent(id, "sitUp", tick)
                        end)
                        log(id .. " sits up tonight")
                    end
                    return
                end
                local needs = SAO.Needs.read(body)
                if needs and needs.fatigue and needs.fatigue > 0.2 then
                    if not agent.sleeping then
                        agent.sleeping = true
                        agent.pressure = { answer = "chosen rest",
                            detail = "sleeps - tomorrow starts early", at = tick }
                        pcall(function() SAOJavaBridge:setShellAsleep(body, true) end)
                        log(id .. " falls asleep")
                    end
                    local okWH, nowH = pcall(function()
                        return GameTime.getInstance():getWorldAgeHours()
                    end)
                    if okWH then
                        local delta = nowH - (agent.lastRestHours or nowH)
                        agent.lastRestHours = nowH
                        if delta > 0 then
                            pcall(function()
                                SAOJavaBridge:restRecoverTick(body, delta)
                            end)
                        end
                    end
                elseif agent.sleeping then
                    agent.sleeping = nil
                    agent.lastRestHours = nil
                    pcall(function() SAOJavaBridge:setShellAsleep(body, false) end)
                    log(id .. " slept enough")
                end
            end
            return
        end
        if agent.resting then
            agent.resting = nil
            if agent.sleeping then
                agent.sleeping = nil
                agent.lastRestHours = nil
                pcall(function() SAOJavaBridge:setShellAsleep(body, false) end)
            end
            pcall(function() body:setSitOnGround(false) end)
            log(id .. " rises with the morning")
        end
        -- [B22] The seating chart. Work sent people to real places
        -- and nobody else was ever drawn to them, so work made no map
        -- of who stands next to whom. Drift toward where the house's
        -- work is actually being done - and once standing there, the
        -- [B22] rest chain still runs, so a person sits beside the
        -- cook and turns their keepsake over. Their character shows
        -- while the work happens next to them, and co-location is
        -- what the meeting, telling and trust machinery has always
        -- run on.
        if tick >= (agent.nextDriftAt or 0)
            and (not agent.pressure or agent.pressure.answer ~= "need")
            and not agent.escortId and not agent.riding
            and not agent.companioning
            and SAO.Disposition.circle(id) ~= "loner" then
            agent.nextDriftAt = tick + 1200
            local workerId, workerBody, workDist = whereTheWorkIs(id, body)
            -- Far enough to be somewhere else, close enough that
            -- going is a reasonable thing to do.
            if workerId and workDist and workDist > 4.0 then
                if SAO.Locomotion.order(id, body,
                    math.floor(workerBody:getX()),
                    math.floor(workerBody:getY()),
                    math.floor(workerBody:getZ())) then
                    local wrec47 = SAO.Identity.get(workerId)
                    setState(agent, id, "ROAM",
                        "goes where the work is"
                        .. (wrec47 and (" - "
                            .. tostring(SAO.Identity.displayName(wrec47)))
                            or ""),
                        "chosen rest")
                    return
                end
            end
        end
        -- The between-time is never nothing (DR-011, [A18]): a stale
        -- answer refreshes to what this body is honestly doing while
        -- the legs rest. The undesignated keep hands busy; the
        -- greenhorn without a single hard claim may WAIT - legibly;
        -- the designated rest short with their kit in reach.
        local idleRec = SAO.Identity.get(id)
        if not agent.pressure or tick - (agent.pressure.at or 0) > 600 then
            local detail
            -- [B32] The cooldown belongs in the GUARD, as
            -- study's already does. Tested only inside the body, this
            -- branch was taken even while on cooldown - `detail` is
            -- set above the check - so the chain never fell through
            -- and an instrument-carrier could never study, read, or
            -- handle a keepsake. The inner check below is now
            -- redundant rather than wrong.
            if idleRec and idleRec.instrument
                and tick >= (agent.nextTuneAt or 0) then
                -- Boot-camp leisure, enriched ([A19]): short, pointed,
                -- interruptible - the porch, the instrument, the bat in
                -- reach. Designation earned the pause; the environment
                -- still collects.
                local what = idleRec.instrument == "Base.Banjo" and "banjo"
                    or idleRec.instrument == "Base.Harmonica" and "harmonica"
                    or "guitar"
                detail = "picks the " .. what .. " on the porch, "
                    .. (agent.armed and "weapon" or "bat") .. " in reach"
                -- [B21] And it CARRIES. This used to set a string and
                -- stop - a hobby with no audience is a flavour label.
                -- The sound is real and reaches the dead too, which is
                -- the honest price of playing out loud here.
                if tick >= (agent.nextTuneAt or 0) then
                    agent.nextTuneAt = tick + 2400
                    pcall(function()
                        addSound(body, math.floor(body:getX()),
                            math.floor(body:getY()),
                            math.floor(body:getZ()), 14, 8)
                    end)
                    local heard43 = 0
                    pcall(function()
                        heard43 = SAOJavaBridge:easeListeners(body, 12)
                    end)
                    -- People come. Nothing else had to be built for
                    -- the consequence: co-location is what the
                    -- meeting, telling and trust machinery has always
                    -- run on. The porch makes the seating chart; the
                    -- seating chart was already wired.
                    local came43 = 0
                    local myG43 = SAO.Standing.groupOf(id)
                    if myG43 then
                        for oid43, oag43 in pairs(Ctl.agents) do
                            if oid43 ~= id
                                and oag43.state == "IDLE"
                                and not oag43.escortId
                                and not oag43.riding
                                and (not oag43.pressure
                                    or oag43.pressure.answer ~= "need")
                                and SAO.Standing.groupOf(oid43) == myG43
                                and SAO.Disposition.circle(oid43) ~= "loner"
                            then
                                local ob43 = SAO.Body.get(oid43)
                                if ob43 then
                                    local odx = ob43:getX() - body:getX()
                                    local ody = ob43:getY() - body:getY()
                                    local od2 = odx * odx + ody * ody
                                    if od2 > 16.0 and od2 <= 196.0 then
                                        if SAO.Locomotion.order(oid43, ob43,
                                            math.floor(body:getX()),
                                            math.floor(body:getY()),
                                            math.floor(body:getZ())) then
                                            setState(oag43, oid43, "ROAM",
                                                "drawn by the " .. what,
                                                "chosen rest")
                                            came43 = came43 + 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if heard43 > 0 or came43 > 0 then
                        log(id .. " plays the " .. what .. " - "
                            .. heard43 .. " eased, " .. came43
                            .. " come over")
                    end
                end
            elseif idleRec and idleRec.designation
                and SAO.Census.JOB_PERK
                and SAO.Census.JOB_PERK[idleRec.designation]
                and tick >= (agent.nextStudyAt or 0) then
                -- [B22] The trade reads up. A survivor seeks and
                -- studies the book their OWN work rides on - the perk
                -- their designation was dealt against - so what they
                -- pick up is decided by who the house made them and
                -- by what the place actually holds.
                --
                -- This is the road back that [B21] did not have. A
                -- struggling medic can read, the dressings start
                -- holding, and the evidence against them stops
                -- accumulating. When there is no book there is no
                -- road, and the job goes to someone else - which is
                -- the scarcity doing its work.
                agent.nextStudyAt = tick + 2400
                local perk48 = SAO.Census.JOB_PERK[idleRec.designation]
                -- [B40] Books speak a different vocabulary than perks
                -- do. The medic's perk is `Doctor` and every first-aid
                -- book in the game says `FirstAid`, so this asked for a
                -- book that does not exist and read the empty answer as
                -- scarcity.
                local book48 = SAO.Census.bookSkillFor(perk48)
                detail = "reads up on the work"
                local studied = ""
                pcall(function()
                    studied = SAOJavaBridge:readSkillBook(body, book48)
                end)
                if studied == nil or studied == "" then
                    local got48 = false
                    pcall(function()
                        got48 = SAOJavaBridge:takeSkillBookFor(
                            body, 10, book48)
                    end)
                    if got48 then
                        log(id .. " finds something on " .. tostring(perk48))
                    else
                        detail = "turns the work over in their head -"
                            .. " nothing written to learn it from"
                    end
                else
                    pcall(function()
                        SAO.Voice.onEvent(id, "studies", tick)
                    end)
                    log(id .. " reads up on " .. tostring(studied))
                end
            -- [B32] Same lock as the porch above: on cooldown
            -- this still took the slot, so a reader never reached
            -- their keepsake.
            elseif idleRec and idleRec.reading
                and tick >= (agent.nextPageAt or 0) then
                -- [B22] Something to read, and it GOES ROUND. A
                -- keepsake helps only its owner; the standing law
                -- since [B20] is that a person's value should land on
                -- other bodies. So a reader beside a bored housemate
                -- hands the book over - the same vanilla transfer
                -- every other kindness here uses.
                detail = "reads a while, back to the wall"
                if tick >= (agent.nextPageAt or 0) then
                    agent.nextPageAt = tick + 3000
                    -- [B41] What the book is ABOUT.
                    --
                    -- `rec.reading` has always held the item's full
                    -- type - `Base.BookFancy_Politics` - and every
                    -- reader of it tested truthiness, so a survivor
                    -- carried a specific manual and the county knew
                    -- only that they held something.
                    --
                    -- Derived from the engine, not from the name:
                    -- `getSkillTrained()` is what the script says the
                    -- book teaches, so a mod's manual works without
                    -- this mod knowing it exists ([B38]'s discipline).
                    -- Empty for a novel, which is most of them.
                    local teaches46 = nil
                    pcall(function()
                        local it46 = getScriptManager():getItem(
                            tostring(idleRec.reading))
                        local s46 = it46 and it46:getSkillTrained() or nil
                        if s46 and s46 ~= "" then teaches46 = s46 end
                    end)

                    local passedTo = nil
                    local passedToTrade = nil
                    local myG46 = SAO.Standing.groupOf(id)
                    if myG46 then
                        for oid46 in pairs(Ctl.agents) do
                            if oid46 ~= id
                                and SAO.Standing.groupOf(oid46) == myG46 then
                                local ob46 = SAO.Body.get(oid46)
                                local orec46 = SAO.Identity.get(oid46)
                                if ob46 and orec46 and not orec46.reading then
                                    local bdx = ob46:getX() - body:getX()
                                    local bdy = ob46:getY() - body:getY()
                                    if bdx * bdx + bdy * bdy <= 25.0 then
                                        local bored46 = 0
                                        pcall(function()
                                            bored46 = SAOJavaBridge:boredom(ob46)
                                        end)
                                        -- [B41] A manual goes to whoever
                                        -- the work belongs to, ahead of
                                        -- whoever happens to be bored -
                                        -- their trade rides on it
                                        -- ([B22]). Boredom still decides
                                        -- who gets a novel.
                                        local wants46 = false
                                        if teaches46 then
                                            local jp46 = SAO.Census.JOB_PERK
                                                and SAO.Census.JOB_PERK[
                                                    orec46.designation] or nil
                                            local want46 = jp46
                                                and SAO.Census.bookSkillFor(jp46)
                                            wants46 = want46 ~= nil
                                                and string.lower(want46)
                                                    == string.lower(teaches46)
                                        end
                                        if wants46 then
                                            passedTo = oid46
                                            passedToTrade = true
                                            break
                                        elseif not passedTo
                                            and (tonumber(bored46) or 0) > 0.3 then
                                            passedTo = oid46
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if passedTo and SAO.Needs.passReadingTo then
                        if SAO.Needs.passReadingTo(id, body,
                            SAO.Body.get(passedTo)) then
                            idleRec.reading = nil
                            pcall(function()
                                SAO.Voice.onEvent(id, "passItOn", tick)
                            end)
                            log(id .. " passes the book to " .. passedTo
                                .. (passedToTrade
                                    and (" - it is theirs to read ("
                                        .. tostring(teaches46) .. ")")
                                    or ""))
                        end
                    end
                end
            -- [B32] Last in the chain, so this starved nobody -
            -- but it swallowed its own slot the same way, and a
            -- between-time branch that cannot yield is the shape this
            -- batch is fixing.
            elseif idleRec and idleRec.keepsake
                and tick >= (agent.nextKeepsakeAt or 0) then
                -- [B22] A thing kept for what it means. It does
                -- nothing for the house, which is precisely what
                -- makes it evidence of a person rather than a
                -- function.
                detail = "turns something over in their hands"
                if tick >= (agent.nextKeepsakeAt or 0) then
                    agent.nextKeepsakeAt = tick + 3600
                    pcall(function()
                        SAOJavaBridge:steady(body, 0.04)
                    end)
                end
            -- [B32] The solo life, moved out of the way.
            -- This has no cooldown and always sets a detail, so as the
            -- FIRST branch it could never yield - an undesignated
            -- survivor took the slot every time and could never play,
            -- read, or turn a keepsake over. [B32] fixed three
            -- branches of that shape and missed this one, because
            -- this one starves by construction rather than by a
            -- misplaced cooldown.
            --
            -- The deal says who lands here: "Solo lives stay
            -- undesignated - that is a different day." A person with
            -- no company is the one with the most time and the least
            -- reason not to use it, so what they carry comes first
            -- and this is what they do when nothing else is due.
            elseif idleRec and not idleRec.designation then
                if (idleRec.contactMonths or 0) < 0.5
                    and not SAO.Lessons.has(id, "routine-is-armor")
                    and not SAO.Lessons.has(id, "measure-the-danger") then
                    detail = "waits for someone to come"
                elseif SAO.Disposition.isSmoker(id) then
                    detail = "keeps hands busy - a smoke, eyes on the road"
                else
                    detail = "keeps hands busy, eyes on the road"
                end
            elseif SAO.Disposition.traits(id).discipline > 0.5 then
                detail = "tends their kit between rounds"
            else
                detail = "a short rest, weapon in reach"
            end
            agent.pressure = { answer = "chosen rest", detail = detail, at = tick }
        end

        -- Remembrance ([A21]): on a long cadence, a mourner walks
        -- back to where one of their dead fell - a CHOSEN act, gated to
        -- their own mourned memory and to sites near enough to reach.
        -- The whole MOURNWARD/MOURNING machinery serves; learn() dedupe
        -- makes re-grief safe, and the pause reads "chosen rest" - grief on
        -- purpose is a way of resting.
        if agent.mourned and (not agent.nextMemorialAt
            or tick >= agent.nextMemorialAt) then
            agent.nextMemorialAt = tick + 14400 + ZombRand(14400)
            for deadId in pairs(agent.mourned) do
                local deadRec = SAO.Identity.get(deadId)
                if deadRec and deadRec.dead and deadRec.x then
                    local mdx = deadRec.x - body:getX()
                    local mdy = deadRec.y - body:getY()
                    if mdx * mdx + mdy * mdy <= 1600.0
                        and SAO.Locomotion.order(id, body,
                            math.floor(deadRec.x), math.floor(deadRec.y),
                            math.floor(body:getZ())) then
                        agent.mournTarget = deadId
                        agent.mournName = deadRec.forename or deadId
                        agent.taskDeadline = tick + 1800
                        setState(agent, id, "MOURNWARD",
                            "visits where " .. tostring(deadRec.forename
                                or deadId) .. " fell", "chosen rest")
                        return
                    end
                end
            end
        end

        -- What the dead leave ([B15]): a corpse within arm's reach
        -- carries real things, and every part of whether to take them
        -- is already modelled. Knowing them refuses hardest - that
        -- outranks hunger and creed both, and is the one place here
        -- where dignity beats need. Mercy leaves the dead be short of
        -- desperation. Everyone else takes what they actually lack.
        if tick >= (agent.nextScavengeAt or 0) then
            agent.nextScavengeAt = tick + 3600
            -- Read locally, like every other block in this scope
            -- (`needsNow` was invented in the first draft and would
            -- have been nil - the B10 field-guess class again, caught
            -- by grepping instead of assuming).
            local n23 = SAO.Needs.read(body)
            local needF = n23 and n23.hunger
                and n23.hunger >= SAO.Disposition.eatAt(id)
            local armed23 = false
            pcall(function()
                local its = body:getInventory():getItems()
                for i = 0, its:size() - 1 do
                    if instanceof(its:get(i), "HandWeapon") then
                        armed23 = true
                        break
                    end
                end
            end)
            if needF or not armed23 then
                local knewThem, took, refused = false, nil, false
                pcall(function()
                    -- Did I know whoever this was? The named-corpse
                    -- read already exists ([B1]); a name I hold a
                    -- belief about is a person, not a container.
                    local okC, corpses = pcall(function()
                        return SAOJavaBridge:findNamedCorpses(body, 3)
                    end)
                    if okC and type(corpses) == "string" and corpses ~= "" then
                        local mine = SAO.Perception.beliefs[id]
                        for entry in corpses:gmatch("[^|]+") do
                            local cn = entry:match("^(.-):")
                            if cn and mine and mine.people[cn] then
                                knewThem = true
                                break
                            end
                        end
                    end
                end)
                local creed23 = nil
                do
                    local g23 = SAO.Standing.groupOf(id)
                    local c23 = g23 and SAO.Standing.creedOf(g23) or nil
                    creed23 = c23 and c23.name or nil
                end
                local desperate23 = n23 and n23.hunger
                    and n23.hunger >= policy().desperation
                if knewThem then
                    refused = true
                elseif creed23 == "mercy" and not desperate23 then
                    refused = true
                else
                    pcall(function()
                        local sq = body:getCurrentSquare()
                        local cell23 = getCell()
                        for dx = -2, 2 do
                            if took then break end
                            for dy = -2, 2 do
                                local s23 = cell23:getGridSquare(
                                    math.floor(body:getX()) + dx,
                                    math.floor(body:getY()) + dy,
                                    math.floor(body:getZ()))
                                local bodies = s23 and s23:getDeadBodys()
                                if bodies then
                                    for bi = 0, bodies:size() - 1 do
                                        local corpse = bodies:get(bi)
                                        local cont = corpse
                                            and corpse:getContainer()
                                        if cont then
                                            local its = cont:getItems()
                                            for ii = its:size() - 1, 0, -1 do
                                                local it = its:get(ii)
                                                local wantIt =
                                                    (needF and instanceof(it, "Food"))
                                                    or (not armed23
                                                        and instanceof(it, "HandWeapon"))
                                                if wantIt then
                                                    cont:Remove(it)
                                                    body:getInventory():AddItem(it)
                                                    took = tostring(it:getName())
                                                    break
                                                end
                                            end
                                        end
                                        if took then break end
                                    end
                                end
                                if took then break end
                            end
                        end
                    end)
                end
                if refused then
                    pcall(function()
                        SAO.Voice.onEvent(id, knewThem and "notThem"
                            or "leaveTheDead", tick)
                    end)
                    log(id .. (knewThem
                        and " will not take from someone they knew"
                        or " leaves the dead their things"))
                elseif took then
                    pcall(function()
                        SAO.Voice.onEvent(id, "scavenge", tick)
                        SAOJavaBridge:equipBestMelee(body)
                    end)
                    log(id .. " takes " .. took .. " from the dead")
                end
            end
        end
        -- The hearth ([B6]): cold is a real engine state, and a
        -- cold person goes to the fire. Feeding it comes first when
        -- they carry something that burns - a fire nobody feeds is a
        -- fire nobody has tomorrow. The walk and the warming are
        -- honest answers to a NEED (DR-011: never a mannequin).
        do
            local coldNow = SAO.Needs.cold(body)
            if coldNow >= 0.8 and tick >= (agent.nextHearthAt or 0) then
                local hx, hy, hz, hfuel, hlit =
                    SAO.Needs.findHearth(id, body, 14)
                if hx then
                    local hdx, hdy = hx - body:getX(), hy - body:getY()
                    -- [B47] The same arrival question at the fire.
                    if hdx * hdx + hdy * hdy
                        <= ARRIVAL_REACH * ARRIVAL_REACH then
                        agent.nextHearthAt = tick + 3600
                        -- A dead fire is lit by whoever carries the
                        -- MEANS ([B6]): a lighter or matches, really
                        -- in the pack. Without them the cold stand
                        -- at a dead hearth and that is the honest
                        -- answer.
                        local okLt, lit2 = pcall(function()
                            return SAOJavaBridge:lightNearbyHearth(body, 3)
                        end)
                        if okLt and lit2 then
                            pcall(function()
                                SAO.Voice.onEvent(id, "lightFire", tick)
                            end)
                            log(id .. " lights the fire")
                        end
                        local okFd, fed = pcall(function()
                            return SAOJavaBridge:feedNearbyHearth(body, 3)
                        end)
                        if okFd and type(fed) == "number" and fed > 0 then
                            pcall(function()
                                SAO.Voice.onEvent(id, "feedFire", tick)
                            end)
                            log(id .. " feeds the fire (" .. fed
                                .. " units)")
                        end
                        agent.taskDeadline = tick + 2400
                        setState(agent, id, "WARMING",
                            "warms at the fire, weapon in reach", "need")
                        return
                    end
                    -- Walk to a fire that is burning, or to one you
                    -- could light: fuel plus the means in your pack.
                    local canLight = false
                    pcall(function()
                        local its7 = body:getInventory():getItems()
                        for i7 = 0, its7:size() - 1 do
                            local ft7 = tostring(
                                its7:get(i7):getFullType() or "")
                            if ft7:find("Lighter") or ft7:find("Matches") then
                                canLight = true
                                break
                            end
                        end
                    end)
                    if hfuel and hfuel > 0 and (hlit or canLight)
                        and SAO.Locomotion.order(id, body, hx, hy, hz) then
                        agent.taskDeadline = tick + 2400
                        setState(agent, id, "HEARTHWARD",
                            "cold - goes to the fire", "need")
                        return
                    end
                end
                -- No hearth answers: the cold walk is not retried
                -- every beat.
                agent.nextHearthAt = tick + 3600
            end
        end
        -- The house's water is the house's politics ([B6]): a
        -- thirsty member whose own vessels are dry draws from the
        -- stored vessels on their own ground - and the SAME ration
        -- policy that governs the shelves governs the bottles.
        -- Under watch-first, a non-watch member waits unless thirst
        -- has passed desperation; nobody is ever left to die of it.
        local wNeeds = SAO.Needs.read(body)
        if wNeeds and wNeeds.thirst
            and wNeeds.thirst >= SAO.Disposition.drinkAt(id)
            and SAO.Standing.insideClaim(id, body:getX(), body:getY())
            and tick >= (agent.nextStoreDrawAt or 0) then
            local wpg = SAO.Standing.groupOf(id)
            local wpol = wpg and SAO.Standing.rationPolicyOf(wpg) or nil
            local wrec7 = agent.rec
            -- Desperation always overrides the policy: policy
            -- decides who waits, never who dies.
            local waitTurn = wpol == "watch-first"
                and wrec7 and wrec7.designation ~= "watch"
                and wNeeds.thirst < policy().desperation
            if not waitTurn then
                if SAO.Needs.takeStoredWater(id, body) then
                    agent.nextStoreDrawAt = tick + 3600
                    agent.taskDeadline = tick + 900
                    agent.takePurpose = "deposit"
                    setState(agent, id, "TAKE",
                        "draws water from the stores", "need")
                    return
                end
            elseif not agent.saidWaterWait then
                agent.saidWaterWait = true
                log(id .. " leaves the stored water for the watch")
            end
        end
        -- The firewood run ([B6]): a house whose counted hearth is
        -- DARK sends its foragers and watch for what burns - the same
        -- shape as the water run, and the shelving walks it home. The
        -- fire loop closes: counted, sought, fed, and restocked.
        do
            local frec7 = agent.rec
            local fjob7 = frec7 and (frec7.designation == "forager"
                or frec7.designation == "watch")
            if fjob7 and tick >= (agent.nextWoodRunAt or 0) then
                local fg7 = SAO.Standing.groupOf(id)
                local fh7 = fg7 and SAO.Standing.hearthOf
                    and SAO.Standing.hearthOf(fg7) or nil
                if fh7 and not fh7.burning
                    and not SAO.Standing.insideClaim(
                        id, body:getX(), body:getY()) then
                    agent.nextWoodRunAt = tick + 10800
                    local okW7, tookW7 = pcall(function()
                        return SAOJavaBridge:takeWantedFromNearby(
                            body, 8, "fuel", 2)
                    end)
                    if okW7 and type(tookW7) == "number" and tookW7 > 0 then
                        pcall(function()
                            SAO.Voice.onEvent(id, "woodRun", tick)
                        end)
                        log(id .. " gathers " .. tookW7
                            .. " for the fire")
                    end
                end
            end
        end
        -- The water carried ([B6]): a house that KNOWS it is dry
        -- sends its foragers and quartermasters to fill real vessels
        -- from real sources - the same shelving walks them home. The
        -- errand exists only while the claim says dry: nobody hauls
        -- water they already have.
        do
            local wrec6 = agent.rec
            local wjob6 = wrec6 and (wrec6.designation == "forager"
                or wrec6.designation == "quartermaster")
            if wjob6 and tick >= (agent.nextWaterRunAt or 0) then
                local wg6 = SAO.Standing.groupOf(id)
                local ws6 = wg6 and SAO.Standing.waterStoreOf(wg6) or nil
                if ws6 and ws6.word == "dry" then
                    agent.nextWaterRunAt = tick + 7200
                    local okF6, got6 = pcall(function()
                        return SAOJavaBridge:fillWaterFromNearby(body, 8)
                    end)
                    if okF6 and type(got6) == "number" and got6 > 0 then
                        log(id .. " fills what they carry - "
                            .. math.floor(got6) .. " units")
                        pcall(function()
                            SAO.Voice.onEvent(id, "waterRun", tick)
                        end)
                        -- The shelving must be QUEUED, not merely
                        -- announced ([B6] bug fix): the other deposit
                        -- sites call their deposit verb first, and
                        -- depositSpareFood is food-shaped - the
                        -- vessels would have ridden in the pack
                        -- forever.
                        if SAO.Needs.depositWater(id, body) then
                            agent.taskDeadline = tick + 900
                            agent.takePurpose = "deposit"
                            setState(agent, id, "TAKE",
                                "brings the water in", "designation")
                            return
                        end
                    end
                    -- Nothing to fill from here: the water errand
                    -- becomes a WALK to the nearest known source, the
                    -- same machinery thirst already uses.
                    local wx6, wy6, wz6 = SAO.Needs.findWater(id, body, 30)
                    if wx6 and SAO.Locomotion.order(id, body, wx6, wy6, wz6) then
                        agent.taskDeadline = tick + 3600
                        -- They came to FILL, not to drink ([B6]) -
                        -- the arrival reads the errand's purpose.
                        agent.waterRun = true
                        setState(agent, id, "WATERWARD",
                            "goes for water - the house is dry",
                            "designation")
                        return
                    end
                end
            end
        end
        -- The ground worked ([B4]): a farm hand on their own ground
        -- reads the REAL plants and the REAL soil - SFarmingSystem
        -- and canDigHereSquare are the truth - and acts by one
        -- priority: harvest the ready, water the thirsty, seed the
        -- plowed, plow new ground. The plot cap (4) counts EXISTING
        -- plants so the county never tiles the map; plowing waits for
        -- the growing months (engine months 2-7, the same 0-based
        -- calendar every seasonal law reads) - seeding and tending
        -- what stands is always allowed.
        do
            local rec4 = agent.rec
            local isFarmHand = rec4 and (rec4.occupation == "farmer"
                or (SAO.Census.classOf
                    and SAO.Census.classOf(rec4.occupation) == "settled"))
            if isFarmHand and tick >= (agent.nextFarmAt or 0)
                and SAO.Standing.insideClaim(id, body:getX(), body:getY())
                and SFarmingSystem and SFarmingSystem.instance
                -- [B5] presence guard: these globals are indexed at
                -- argument-evaluation time, before any pcall can
                -- catch it - a missing farming module must skip the
                -- work, not abort the scan.
                and ISFarmingMenu and ISFarmingMenu.canDigHereSquare
                and ISFarmingMenu.getWaterUsesInteger then
                agent.nextFarmAt = tick + 7200
                local fc4 = SAO.Standing.groupOf(id)
                    and SAO.Standing.groupClaimOf(SAO.Standing.groupOf(id))
                    or SAO.Standing.claimOf(id)
                if fc4 then
                    local harvest4, thirsty4, plowed4, digable4 = nil, nil, nil, nil
                    local thirstySq4, plantCount4 = nil, 0
                    pcall(function()
                        local cell4 = getCell()
                        local fx0, fy0, fx1, fy1, fz0 =
                            workWindow(fc4, body, 12)
                        if not fx0 then return end
                        for x4 = fx0, fx1 do
                            for y4 = fy0, fy1 do
                                local sq4 = cell4:getGridSquare(
                                    x4, y4, fz0)
                                if sq4 then
                                    local plant4 = SFarmingSystem.instance
                                        :getLuaObjectOnSquare(sq4)
                                    if plant4 then
                                        plantCount4 = plantCount4 + 1
                                        local okH4, harv4 = pcall(function()
                                            return plant4:canHarvest()
                                        end)
                                        if okH4 and harv4
                                            and not harvest4 then
                                            harvest4 = plant4
                                        end
                                        local st4 = tostring(
                                            plant4.state or "")
                                        local wl4 = tonumber(plant4.waterLvl)
                                        if st4 == "seeded" and wl4
                                            and wl4 < 60
                                            and not thirsty4 then
                                            thirsty4 = plant4
                                            thirstySq4 = sq4
                                        end
                                        if st4 == "plow"
                                            and not plowed4 then
                                            plowed4 = plant4
                                        end
                                    elseif not digable4 then
                                        local okD4, can4 = pcall(
                                            ISFarmingMenu.canDigHereSquare,
                                            sq4)
                                        if okD4 and can4 then
                                            digable4 = sq4
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    -- Gear reads, engine-honest.
                    local seed4, seedType4, plow4, water4, waterUses4
                    pcall(function()
                        local its4 = body:getInventory():getItems()
                        for i4 = 0, its4:size() - 1 do
                            local it4 = its4:get(i4)
                            if not plow4 and ItemTag
                                and it4:hasTag(ItemTag.DIG_PLOW) then
                                plow4 = it4
                            end
                            if not seed4 and farming_vegetableconf
                                and farming_vegetableconf.props then
                                local ft4 = it4:getFullType()
                                for tos4, props4 in pairs(
                                    farming_vegetableconf.props) do
                                    local sts4 = props4.seedTypes
                                        or { props4.seedName }
                                    for _, st4 in ipairs(sts4) do
                                        if st4 == ft4 then
                                            seed4, seedType4 = it4, tos4
                                            break
                                        end
                                    end
                                    if seed4 then break end
                                end
                            end
                            if not water4 then
                                local okU4, u4 = pcall(
                                    ISFarmingMenu.getWaterUsesInteger, it4)
                                if okU4 and u4 and u4 > 0 then
                                    water4, waterUses4 = it4, u4
                                end
                            end
                        end
                    end)
                    local month4 = 5
                    pcall(function()
                        month4 = GameTime.getInstance():getMonth()
                    end)
                    local growing4 = month4 >= 2 and month4 <= 7
                    -- Robustness ([B5]): vanilla constructors run
                    -- behind a guard, and the state only changes if
                    -- the queue actually took the work.
                    local acted4, why4 = false, nil
                    if harvest4 then
                        acted4 = pcall(function()
                            ISTimedActionQueue.add(ISHarvestPlantAction:new(
                                body, harvest4, 100))
                        end)
                        why4 = "brings in the crop"
                    elseif thirsty4 and water4 and not rainingNow() then
                        local wl4 = tonumber(thirsty4.waterLvl) or 0
                        local need4 = math.max(1,
                            math.ceil((100 - wl4) / 10))
                        local use4 = math.min(waterUses4, need4)
                        acted4 = pcall(function()
                            ISTimedActionQueue.add(ISWaterPlantAction:new(
                                body, water4, use4, thirstySq4,
                                20 + 6 * use4))
                        end)
                        why4 = "waters the rows"
                    elseif plowed4 and seed4 and seedType4 then
                        acted4 = pcall(function()
                            ISTimedActionQueue.add(ISSeedActionNew:new(
                                body, seed4, seedType4, plowed4))
                        end)
                        why4 = "seeds the plowed row"
                    elseif digable4 and plow4 and seed4
                        and plantCount4 < 4 and growing4 then
                        acted4 = pcall(function()
                            ISTimedActionQueue.add(ISPlowAction:new(
                                body, digable4, plow4))
                        end)
                        why4 = "breaks new ground"
                    end
                    if acted4 and why4 then
                        setState(agent, id, "TAKE", why4, "designation")
                    end
                    if acted4 then
                        agent.taskDeadline = tick + 1800
                        agent.takePurpose = "farm"
                        return
                    end
                end
            end
        end
        -- Claims fill hours ([A18]): those who watched slack get
        -- someone killed do not sit long. Designation sets the shape
        -- and the pace of the walk itself.
        -- The promise kept ([B3]): a keeper who has SEEN what their
        -- promised became walks to it and ends it - before anything
        -- else the day could ask of them.
        if agent.promiseTarget then
            local pt = agent.promiseTarget
            -- The damper ([B3]): three failed walks and the promise
            -- is CARRIED, not chased - it keeps if they ever see the
            -- turned again.
            pt.tries = (pt.tries or 0) + 1
            if pt.tries > 3 then
                log(id .. " cannot reach what " .. tostring(pt.name)
                    .. " became - the promise is carried, not dropped")
                agent.promiseTarget = nil
                pt = nil
            end
            if pt then
            local pdx = pt.x - body:getX()
            local pdy = pt.y - body:getY()
            if pdx * pdx + pdy * pdy <= ARRIVAL_REACH * ARRIVAL_REACH then
                agent.promiseTarget = nil
                SAO.Standing.clearPromise(pt.deadId)
                pcall(function()
                    SAO.Voice.onEvent(id, "promiseKept", tick)
                end)
                SAO.Controller.orderEngageNearest(id, true)
                log(id .. " keeps the promise to "
                    .. tostring(pt.name))
                return
            end
            if SAO.Locomotion.order(id, body,
                math.floor(pt.x), math.floor(pt.y),
                math.floor(body:getZ())) then
                agent.taskDeadline = tick + 3600
                setState(agent, id, "TRAVEL",
                    "walks toward the promise", "need")
                return
            end
            end
        end
        -- The search ([A28]): love notices absence. Before settling
        -- into the day's walk, a survivor checks the people they hold
        -- close - the bonded, and fellows trusted past 0.5 - against
        -- their own beliefs. A belief gone stale (>48 world-hours,
        -- not dead-flagged: you go looking BEFORE you bury) sends
        -- them to the last place they knew. Once a day at most; the
        -- walk is the whole mechanic, and the scanner does the rest.
        if tick >= (agent.nextSearchAt or 0) then
            agent.nextSearchAt = tick + 43200
            local sb0 = SAO.Perception.beliefs[id]
            local okSH, nowSH = pcall(function()
                return GameTime.getInstance():getWorldAgeHours()
            end)
            if sb0 and okSH then
                -- Worry is FELT, not thresholded ([A28]): you act
                -- because you feel and need. Lateness is measured
                -- against what they SAID they were doing and how long
                -- that errand usually takes (the house has watched
                -- people come back); the first run of a kind is
                -- estimated from the distance they named. What a
                -- worrier can bear is their own nerve; the bonded
                -- bear less. No word at all is worse: unannounced
                -- absence worries on the person's own rhythm, nerve-
                -- scaled, never a county constant.
                local myNerve = SAO.Disposition.traits(id).nerve
                for pname, pb in pairs(sb0.people) do
                    if not pb.dead and pb.atHours and pb.x and pb.y then
                        local mKey = SAO.Standing.keyForObserved
                            and SAO.Standing.keyForObserved(pname) or nil
                        local bonded = mKey
                            and SAO.Standing.isBondedTo(id, mKey)
                        local close = mKey and (bonded
                            or SAO.Standing.trust(id, mKey) > 0.5)
                        -- Worry as a RATIO ([B1]): how far past what
                        -- this person can bear. >1 is overdue; the
                        -- magnitude is the searcher's resolve when
                        -- someone argues.
                        local function worryRatio(nerve0, bonded0)
                            -- "Don't wait up" means exactly that
                            -- ([B1]): no clock, no search - grief if
                            -- word of death ever comes, reunion
                            -- without apology if they walk back in.
                            if pb.out and pb.out.noClock then
                                return 0
                            end
                            -- A SAID term outranks the estimate: they
                            -- told you when to expect them.
                            if pb.out and pb.out.backByHours
                                and pb.out.saidAtHours then
                                local term = math.max(0.5,
                                    pb.out.backByHours
                                    - pb.out.saidAtHours)
                                return (nowSH - pb.out.saidAtHours)
                                    / (term * (1.25 + nerve0)
                                        * (bonded0 and 0.75 or 1.0))
                            end
                            if pb.out and pb.out.saidAtHours then
                                local og0 = SAO.Standing.groupOf(mKey)
                                local expected = og0
                                    and SAO.Standing.ventureExpectation(
                                        og0, pb.out.kind) or nil
                                if not expected then
                                    local ddx = (pb.out.x or pb.x) - pb.x
                                    local ddy = (pb.out.y or pb.y) - pb.y
                                    expected = 2 + math.sqrt(
                                        ddx * ddx + ddy * ddy) / 300
                                end
                                local patience = expected
                                    * (1.5 + nerve0 * 2)
                                    * (bonded0 and 0.6 or 1.0)
                                return (nowSH - pb.out.saidAtHours)
                                    / math.max(0.1, patience)
                            end
                            local bearing = 24 * (1 + nerve0 * 2)
                                * (bonded0 and 0.6 or 1.0)
                            return (nowSH - pb.atHours)
                                / math.max(0.1, bearing)
                        end
                        local overRatio = close
                            and worryRatio(myNerve, bonded) or 0
                        local overdue = overRatio > 1
                        -- Only the truly absent: a fellow standing
                        -- twenty tiles away is not missing.
                        if close and overdue
                            and not (mKey and SAO.Body.get(mKey)) then
                            -- The departure argument ([B1]): whoever
                            -- stands closest runs the SAME worry math
                            -- from their own seat. Not-worried and
                            -- caring about the SEARCHER, they object.
                            -- A barely-over searcher facing a bonded
                            -- objector or a trusted leader desists -
                            -- and the care shown warms both. The
                            -- far-gone go anyway; an objector who
                            -- loses and loves them goes along.
                            local objector = nil
                            do
                                local myG7 = SAO.Standing.groupOf(id)
                                local bestD7 = 1e9
                                if myG7 then
                                    for _, r7 in pairs(SAO.Identity.all()) do
                                        if not r7.dead and r7.id ~= id
                                            and SAO.Standing.groupOf(r7.id)
                                                == myG7 then
                                            local b7 = SAO.Body.get(r7.id)
                                            if b7 then
                                                local dx7 = b7:getX()
                                                    - body:getX()
                                                local dy7 = b7:getY()
                                                    - body:getY()
                                                local d7 = dx7 * dx7
                                                    + dy7 * dy7
                                                if d7 <= 100
                                                    and d7 < bestD7 then
                                                    objector = r7.id
                                                    bestD7 = d7
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            local desisted = false
                            if objector
                                and SAO.Standing.trust(objector, id)
                                    > 0.4 then
                                local oNerve = SAO.Disposition
                                    .traits(objector).nerve
                                local oBonded = mKey and SAO.Standing
                                    .isBondedTo(objector, mKey)
                                local theirRatio =
                                    worryRatio(oNerve, oBonded)
                                if theirRatio <= 1 then
                                    pcall(function()
                                        SAO.Voice.onEvent(objector,
                                            "stayPut", tick)
                                    end)
                                    -- [B23] A deputy who tells you not
                                    -- to go is a real thing about a
                                    -- real kind of house. In a flat
                                    -- house nobody has that standing,
                                    -- which is equally real - and
                                    -- `secondOf` returns nil there, so
                                    -- the difference costs no branch.
                                    local grpHV = SAO.Standing.groupOf(id) or ""
                                    -- [B23] In a DIVIDED house the chair
                                    -- stops being the voice that
                                    -- carries. There is no vote - whose
                                    -- word reaches you is decided by who
                                    -- you lean with, and you listen to
                                    -- your own side. That is the room
                                    -- splitting, and nothing had to be
                                    -- scripted for it.
                                    local formHV = SAO.Standing.formOf
                                        and SAO.Standing.formOf(grpHV) or "empty"
                                    local sameSide = false
                                    if formHV == "divided"
                                        and SAO.Standing.leansToward then
                                        local a = SAO.Standing.leansToward(id)
                                        local b = SAO.Standing.leansToward(
                                            objector)
                                        sameSide = (a ~= nil and a == b)
                                    end
                                    local heavyVoice =
                                        SAO.Standing.isBondedTo(id, objector)
                                        or (sameSide
                                            and SAO.Standing.trust(id, objector)
                                                > 0.5)
                                        or (formHV ~= "divided"
                                            and (SAO.Standing.leaderOf(grpHV)
                                                    == objector
                                                or (SAO.Standing.secondOf
                                                    and SAO.Standing.secondOf(
                                                        grpHV) == objector))
                                            and SAO.Standing.trust(id, objector)
                                                > 0.5)
                                    if overRatio <= 1.25 and heavyVoice then
                                        desisted = true
                                        agent.nextSearchAt = tick + 21600
                                        SAO.Standing.adjustTrust(
                                            id, objector, 0.03)
                                        SAO.Standing.adjustTrust(
                                            objector, id, 0.03)
                                        log(id .. " is talked out of the"
                                            .. " search by " .. objector
                                            .. " - barely worried enough,"
                                            .. " and they care")
                                    elseif SAO.Standing.isBondedTo(
                                            objector, id)
                                        or SAO.Standing.trust(objector, id)
                                            > 0.6 then
                                        local oAgent = Ctl.agents[objector]
                                        if oAgent then
                                            oAgent.escortId = id
                                            pcall(function()
                                                SAO.Voice.onEvent(objector,
                                                    "notAlone", tick)
                                            end)
                                            log(objector .. " cannot stop "
                                                .. id .. " - so they go"
                                                .. " along")
                                        end
                                    else
                                        log(objector .. " watches " .. id
                                            .. " go")
                                    end
                                end
                            end
                            if desisted then return end
                            local sx = (pb.out and pb.out.x) or pb.x
                            local sy = (pb.out and pb.out.y) or pb.y
                            if SAO.Locomotion.order(id, body,
                                math.floor(sx), math.floor(sy),
                                math.floor(body:getZ())) then
                                agent.searchName = pname
                                agent.taskDeadline = tick + 3600
                                pcall(function()
                                    SAO.Voice.onEvent(id, "searchOut", tick)
                                end)
                                -- The searcher tells someone too.
                                pcall(function()
                                    SAO.Perception.announceDeparture(
                                        id, "search",
                                        math.floor(sx), math.floor(sy))
                                end)
                                setState(agent, id, "SEARCHWARD",
                                    pb.out
                                    and ("goes after " .. pname
                                        .. " - said they'd be back by now")
                                    or ("goes looking for " .. pname
                                        .. " - nobody has seen them"),
                                    "need")
                                return
                            end
                        end
                    end
                end
            end
        end
        local interval = SAO.Disposition.roamInterval(id)
        if SAO.Lessons.has(id, "routine-is-armor")
            or SAO.Lessons.has(id, "measure-the-danger") then
            interval = math.floor(interval * 0.7)
        end
        local desig = idleRec and idleRec.designation or nil
        if desig == "scout" then interval = math.floor(interval * 0.6) end
        agent.nextRoamAt = agent.nextRoamAt or (tick + interval)
        if tick >= agent.nextRoamAt then
            agent.nextRoamAt = tick + interval
            local range = SAO.Disposition.roamRange(id)
            local why, answer = nil, nil
            local watchEdge = nil
            local allyWall = false
            local raidG = nil
            local deliveryRun = false
            if desig == "watch" then
                -- The watch walks the EDGE ([A19]): a point on the
                -- boundary of the ground actually held - the company's
                -- claim first, their own second - facing whatever comes.
                local c = nil
                local wg = SAO.Standing.groupOf(id)
                if wg then c = SAO.Standing.groupClaimOf(wg) end
                -- The war party ([A27]): during a feud, one watch
                -- leg in six walks TOWARD THE ENEMY'S GROUND. The walk
                -- is the whole mechanic - what happens when hostile
                -- parties meet is the engine's own combat law, and
                -- witnessing, grudges, death news, and the chronicle
                -- already catch the consequences.
                if wg then
                    for eg in pairs(SAO.Standing.allGroupClaims()) do
                        if eg ~= wg and SAO.Standing.feudBetween(wg, eg)
                            and ZombRand(6) == 0 then
                            local ec = SAO.Standing.groupClaimOf(eg)
                            if ec then
                                c = ec
                                raidG = eg
                            end
                            break
                        end
                    end
                end
                -- The pact kept ([A26]): a watchman of a watch-rich
                -- house walks the ALLY'S wall one leg in three - the
                -- other half of bread-for-watch, visible.
                if not raidG and wg and SAO.Standing.pactPartnerOf then
                    local wAlly = SAO.Standing.pactPartnerOf(wg)
                    local wAllyClaim = wAlly
                        and SAO.Standing.groupClaimOf(wAlly) or nil
                    if wAllyClaim and ZombRand(3) == 0 then
                        c = wAllyClaim
                        allyWall = true
                    end
                end
                c = c or SAO.Standing.claimOf(id)
                if c then
                    local side = ZombRand(4)
                    local ex, ey
                    if side == 0 then
                        ex, ey = c.minX, c.minY + ZombRand(c.maxY - c.minY + 1)
                    elseif side == 1 then
                        ex, ey = c.maxX, c.minY + ZombRand(c.maxY - c.minY + 1)
                    elseif side == 2 then
                        ex, ey = c.minX + ZombRand(c.maxX - c.minX + 1), c.minY
                    else
                        ex, ey = c.minX + ZombRand(c.maxX - c.minX + 1), c.maxY
                    end
                    watchEdge = { x = ex, y = ey }
                end
            end
            -- The dark ([B17]): the far errands do not set out into
            -- the night without a light. Desperation overrides -
            -- starving outranks being sensible, the same way it
            -- overrides claimed ground - and the watch stays out
            -- because the watch that matters is the one nobody can
            -- see coming.
            do
                local okNH, hourNow = pcall(function()
                    return GameTime.getInstance():getHour()
                end)
                local isNight = okNH and (hourNow >= 22.0 or hourNow < 6.0)
                if isNight and (desig == "forager" or desig == "scout") then
                    local nNeeds = SAO.Needs.read(body)
                    local starving = nNeeds and nNeeds.hunger
                        and nNeeds.hunger >= policy().desperation
                    if not starving and not SAO.Needs.hasLight(body) then
                        agent.nextRoamAt = tick + 3600
                        if not agent.saidDark then
                            agent.saidDark = true
                            pcall(function()
                                SAO.Voice.onEvent(id, "waitForLight", tick)
                            end)
                        end
                        setState(agent, id, "IDLE",
                            "waits for light - no lamp, and the sweep can"
                            .. " keep till morning", "chosen rest")
                        return
                    end
                end
            end
            if desig == "scout" then
                range = range * 3
                -- Light feet range farther ([B2]).
                local sLvl = SAO.Census.skillOf
                    and SAO.Census.skillOf(id, "Lightfooted") or 0
                if sLvl and sLvl > 0 then
                    range = math.floor(range * (1 + sLvl * 0.05))
                end
                why, answer = "scouts the ground for the company", "designation"
            elseif desig == "watch" then
                range = math.max(3, math.floor(range / 2))
                why, answer = "walks the watch", "designation"
                if allyWall then why = "walks the ally's wall" end
                -- The wall watched ([B2]): a watcher carrying the
                -- real kit - hammer, plank, nails, however the world
                -- provided them - boards up a needy window on their
                -- OWN ground through the vanilla action. The engine
                -- grants the Carpentry itself.
                if not raidG and not allyWall
                    and tick >= (agent.nextBuildAt or 0) then
                    agent.nextBuildAt = tick + 10800
                    local wc9 = SAO.Standing.groupOf(id)
                        and SAO.Standing.groupClaimOf(
                            SAO.Standing.groupOf(id))
                        or SAO.Standing.claimOf(id)
                    if wc9 and SAO.Standing.insideClaim(
                        id, body:getX(), body:getY()) then
                        local hasKit, hammer9, plank9 = false, nil, nil
                        pcall(function()
                            local inv9 = body:getInventory()
                            local its9 = inv9:getItems()
                            local nails9 = false
                            for i9 = 0, its9:size() - 1 do
                                local it9 = its9:get(i9)
                                local ft9 = tostring(
                                    it9:getFullType() or "")
                                if ft9 == "Base.Hammer" then
                                    hammer9 = it9
                                elseif ft9 == "Base.Plank" then
                                    plank9 = it9
                                elseif ft9 == "Base.Nails"
                                    or ft9 == "Base.NailsBox" then
                                    nails9 = true
                                end
                            end
                            hasKit = hammer9 ~= nil and plank9 ~= nil
                                and nails9
                        end)
                        if hasKit then
                            local target9 = nil
                            pcall(function()
                                local cell9 = getCell()
                                local wx0, wy0, wx1, wy1, wz0 =
                                    workWindow(wc9, body, 10)
                                if not wx0 then return end
                                for x9 = wx0, wx1 do
                                    if target9 then break end
                                    for y9 = wy0, wy1 do
                                        local sq9 = cell9:getGridSquare(
                                            x9, y9, wz0)
                                        if sq9 then
                                            local objs9 = sq9:getObjects()
                                            for o9 = 0, objs9:size() - 1 do
                                                local ob9 = objs9:get(o9)
                                                local okB9, can9 =
                                                    pcall(function()
                                                    if not ob9.isBarricadeAllowed
                                                        or not ob9:isBarricadeAllowed()
                                                    then
                                                        return false
                                                    end
                                                    local bar9 = ob9
                                                        :getBarricadeForCharacter(
                                                            body)
                                                    return bar9 == nil
                                                        or bar9:canAddPlank()
                                                end)
                                                if okB9 and can9 then
                                                    target9 = ob9
                                                    break
                                                end
                                            end
                                            if target9 then break end
                                        end
                                    end
                                end
                            end)
                            if target9 then
                                pcall(function()
                                    body:setPrimaryHandItem(hammer9)
                                    body:setSecondaryHandItem(plank9)
                                    ISTimedActionQueue.add(
                                        ISBarricadeAction:new(
                                            body, target9, false, false))
                                end)
                                agent.taskDeadline = tick + 1800
                                agent.takePurpose = "build"
                                setState(agent, id, "TAKE",
                                    "boards up the window - the wall"
                                    .. " holds", "designation")
                                return
                            end
                        end
                    end
                end
                if raidG then
                    why = "walks toward the enemy's ground"
                    pcall(function()
                        SAO.Voice.onEvent(id, "warpath", tick)
                    end)
                end
            elseif desig == "forager" then
                range = range * 2
                why, answer = "sweeps for supplies", "designation"
                -- Lean shelves stretch the sweep ([A28]): a house
                -- that KNOWS it is short sends its foragers farther.
                do
                    local fG5 = SAO.Standing.groupOf(id)
                    local l5 = fG5 and SAO.Standing.larderOf(fG5) or nil
                    if l5 and l5.word == "lean" then
                        range = math.floor(range * 1.5)
                        why = "sweeps far - the shelves are thin"
                    end
                end
                -- The haul comes home ([A28]): a forager standing on
                -- their own ground with spare food shelves it - the
                -- same sanctioned deposit the quartermaster runs, now
                -- fed by REAL collected goods, closing the loop:
                -- sweep, gather, walk home, shelve.
                if SAO.Standing.insideClaim(id, body:getX(), body:getY())
                    and SAO.Needs.depositSpareFood(id, body) then
                    agent.taskDeadline = tick + 900
                    agent.takePurpose = "deposit"
                    setState(agent, id, "TAKE", "shelves the haul",
                        "designation")
                    return
                end
                -- The pact kept ([A26]): a forager of a bread-rich
                -- house carries the bread OVER. Standing on the ally's
                -- ground with spare food, the delivery is the same
                -- sanctioned deposit the quartermaster runs at home;
                -- otherwise, when the run is due, the roam aims at the
                -- ally's ground instead of nowhere.
                local pg = SAO.Standing.groupOf(id)
                local ally = pg and SAO.Standing.pactPartnerOf
                    and SAO.Standing.pactPartnerOf(pg) or nil
                -- [B23] And when there is no pact, a house that has
                -- ASKED. Same legs, same deposit - the difference is
                -- only who is owed at the end of it.
                local asked = nil
                if not ally and pg and SAO.Standing.nearestAsking then
                    asked = SAO.Standing.nearestAsking(pg)
                end
                local bringTo = ally or asked
                local allyClaim = bringTo
                    and SAO.Standing.groupClaimOf(bringTo) or nil
                if allyClaim then
                    local inAlly = body:getX() >= allyClaim.minX
                        and body:getX() <= allyClaim.maxX
                        and body:getY() >= allyClaim.minY
                        and body:getY() <= allyClaim.maxY
                    if inAlly
                        and SAO.Needs.depositSpareFood(id, body) then
                        agent.taskDeadline = tick + 900
                        agent.takePurpose = "deposit"
                        agent.nextPactRunAt = tick + 21600
                        -- [B23] State first, bookkeeping after. The
                        -- queuing call is the branch condition right
                        -- above; keeping setState next to it is what
                        -- border 6 exists to enforce, and the code
                        -- reads better this way regardless.
                        local why52 = "delivers the bread - the pact kept"
                        if asked then
                            why52 = "answers the ask - bread to "
                                .. tostring(SAO.Standing.factionName(asked)
                                    or asked)
                        end
                        setState(agent, id, "TAKE", why52, "designation")
                        if asked then
                            -- A gift, and it is remembered. No price -
                            -- this county has never had one, and does
                            -- not need one to keep accounts.
                            pcall(function()
                                local theirLead = SAO.Standing.leaderOf(asked)
                                local ourLead = SAO.Standing.leaderOf(pg)
                                if theirLead and ourLead then
                                    SAO.Standing.addDebt(ourLead,
                                        theirLead, 1)
                                    SAO.Standing.adjustTrust(theirLead,
                                        ourLead, 0.15)
                                end
                            end)
                            pcall(function()
                                SAO.Voice.onEvent(id, "answered", tick)
                            end)
                        else
                            pcall(function()
                                SAO.Voice.onEvent(id, "pactKept", tick)
                            end)
                        end
                        return
                    end
                    -- A lean ally quickens the runs ([A28]): pact
                    -- houses talk, so the partner's own counted
                    -- shelves (their fresh larder claim) halve the
                    -- delivery cadence. Composition of existing
                    -- claims - no new fiat.
                    local allyLean = false
                    do
                        local al6 = ally and SAO.Standing.larderOf
                            and SAO.Standing.larderOf(ally) or nil
                        allyLean = (al6 and al6.word == "lean") or false
                    end
                    if not inAlly
                        and tick >= (agent.nextPactRunAt or 0)
                            - (allyLean and 10800 or 0) then
                        watchEdge = {
                            x = (allyClaim.minX + allyClaim.maxX) / 2,
                            y = (allyClaim.minY + allyClaim.maxY) / 2,
                        }
                        why = asked and "carries bread to a house that"
                            .. " asked" or "carries bread to the ally"
                        deliveryRun = true
                    end
                end
            elseif desig == "quartermaster" then
                -- The round does the work ([A19]): standing on held
                -- ground with spare food, the quartermaster stocks the
                -- stores before stretching legs. The walk happens next
                -- cadence; stocking IS the job.
                if SAO.Standing.insideClaim(id, body:getX(), body:getY())
                    and SAO.Needs.depositSpareFood(id, body) then
                    agent.taskDeadline = tick + 900
                    agent.takePurpose = "deposit"
                    setState(agent, id, "TAKE", "stocks the stores", "designation")
                    return
                end
                why, answer = "rounds the stores", "designation"
                -- The larder speaks ([A28]): the round READS the
                -- real shelves - a count of actual edible items in
                -- the actual containers - and the claim it derives is
                -- what the house knows about its own stores.
                if SAO.Standing.insideClaim(id, body:getX(), body:getY()) then
                    local qG = SAO.Standing.groupOf(id)
                    if qG then
                        local okC5, cnt5 = pcall(function()
                            return SAOJavaBridge:countEdibleNearby(body, 12)
                        end)
                        if okC5 and type(cnt5) == "number" then
                            local n5 = #SAO.Standing.fellowsOf(id) + 1
                            -- The winter prepared ([A28]): in autumn
                            -- (engine months 9/10 = Oct/Nov, the same
                            -- 0-based calendar the attrition law
                            -- reads) the SAME real count is judged
                            -- against the winter ahead - thresholds
                            -- x1.5. Judgment derives from calendar
                            -- plus count; the count itself is never
                            -- touched.
                            local seasonScale = 1.0
                            pcall(function()
                                local m6 = GameTime.getInstance():getMonth()
                                if m6 == 9 or m6 == 10 then
                                    seasonScale = 1.5
                                end
                            end)
                            local word = (cnt5 < n5 * 1.5 * seasonScale)
                                and "lean"
                                or (cnt5 > n5 * 4 * seasonScale)
                                and "full" or "fair"
                            SAO.Standing.setLarder(qG, word, cnt5)
                            if word == "lean" then
                                -- [B23] And the county hears it. The
                                -- count is already made; this only
                                -- lets it leave the building.
                                pcall(function()
                                    SAO.Standing.callForBread(qG)
                                end)
                                pcall(function()
                                    SAO.Voice.onEvent(id,
                                        seasonScale > 1 and "winterLean"
                                        or "lean", tick)
                                end)
                            end
                            log(id .. " counts the shelves: " .. cnt5
                                .. " (" .. word
                                .. (seasonScale > 1 and ", judged against winter"
                                    or "") .. ")")
                            -- The motor pool ([B1]): the same rounds
                            -- read the REAL cars on the ground. The
                            -- claim is what the house can plan seats
                            -- around; no car is ever conjured.
                            -- The warm house ([B6]): the round also
                            -- notes whether the hearth is BURNING -
                            -- a claim the dormant world reads, so a
                            -- house that keeps a fire survives the
                            -- cold months better than one that does
                            -- not. Read, never asserted.
                            do
                                local _, _, _, hf7, hl7 =
                                    SAO.Needs.findHearth(id, body, 14)
                                SAO.Standing.setHearth(qG,
                                    (hl7 and hf7 and hf7 > 0) and true or false)
                            end
                            -- Water counted ([B6]): the same round
                            -- reads what the house has to DRINK, and
                            -- notices the day the mains stop. The
                            -- shutoff is a county fact - stamped,
                            -- aired, and chronicled like the first
                            -- bite; sandbox decides when it comes.
                            do
                                local okW6, w6 = pcall(function()
                                    return SAOJavaBridge
                                        :countStoredWaterNearby(body, 12)
                                end)
                                if okW6 and type(w6) == "number" then
                                    local n6 = #SAO.Standing.fellowsOf(id) + 1
                                    local word6 = (w6 < n6 * 2) and "dry"
                                        or (w6 > n6 * 8) and "full" or "fair"
                                    SAO.Standing.setWaterStore(qG, word6, w6)
                                    if word6 == "dry" then
                                        pcall(function()
                                            SAO.Voice.onEvent(id, "dryStore",
                                                tick)
                                        end)
                                    end
                                    log(id .. " counts the water: "
                                        .. math.floor(w6) .. " (" .. word6
                                        .. ")")
                                end
                                local okM6, mainsOn6 = pcall(function()
                                    return SAOJavaBridge:countyWaterOn()
                                end)
                                if okM6 and mainsOn6 == false then
                                    pcall(function()
                                        local sM = ModData.getOrCreate(
                                            "SurvivorAwareness_Standing")
                                        if sM and not sM.tapsDryAtHours then
                                            -- [B34] Stamp LAST. The
                                            -- guard is once-only, so a
                                            -- throw after the stamp
                                            -- lands would keep the day
                                            -- and lose the telling of
                                            -- it, forever. Read the
                                            -- hour and air the news
                                            -- first; the stamp is then
                                            -- a bare assignment on a
                                            -- table already checked,
                                            -- which cannot throw.
                                            local atH = GameTime
                                                .getInstance()
                                                :getWorldAgeHours()
                                            SAO.Standing.pushRadioNews({
                                                kind = "tapsDry" })
                                            sM.tapsDryAtHours = atH
                                        end
                                    end)
                                end
                            end
                            -- The armorer ([B2]): a REAL weapon from
                            -- the REAL stores goes to the steadiest
                            -- unarmed hands present. Pure transfer -
                            -- both bodies are ours; nothing conjured.
                            do
                                local bestUn, bestAim = nil, -1
                                -- The roster, not the county ([B5]).
                                for _, mid2 in ipairs(
                                    SAO.Standing.fellowsOf(id)) do
                                    local mr = SAO.Identity.get(mid2)
                                    if mr and not mr.dead then
                                        local mb = SAO.Body.get(mr.id)
                                        if mb then
                                            local mdx = mb:getX()
                                                - body:getX()
                                            local mdy = mb:getY()
                                                - body:getY()
                                            if mdx * mdx + mdy * mdy
                                                <= 100 then
                                                local armed = false
                                                pcall(function()
                                                    local its =
                                                        mb:getInventory()
                                                        :getItems()
                                                    for i2 = 0,
                                                        its:size() - 1 do
                                                        if instanceof(
                                                            its:get(i2),
                                                            "HandWeapon")
                                                        then
                                                            armed = true
                                                            break
                                                        end
                                                    end
                                                end)
                                                if not armed then
                                                    local aim =
                                                        SAO.Census.skillOf(
                                                        mr.id, "Aiming")
                                                    if aim > bestAim then
                                                        bestUn = mr.id
                                                        bestAim = aim
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if bestUn then
                                    local okW, tookW = pcall(function()
                                        return SAOJavaBridge
                                            :takeWantedFromNearby(
                                                body, 12, "weapon", 1)
                                    end)
                                    if okW and tookW and tookW > 0 then
                                        pcall(function()
                                            local qInv = body:getInventory()
                                            local its = qInv:getItems()
                                            for i2 = its:size() - 1, 0, -1 do
                                                local it2 = its:get(i2)
                                                if instanceof(it2,
                                                    "HandWeapon") then
                                                    qInv:Remove(it2)
                                                    SAO.Body.get(bestUn)
                                                        :getInventory()
                                                        :AddItem(it2)
                                                    SAOJavaBridge
                                                        :equipBestMelee(
                                                        SAO.Body.get(bestUn))
                                                    log(id .. " arms "
                                                        .. bestUn
                                                        .. " from the stores"
                                                        .. " - steadiest"
                                                        .. " hands present")
                                                    break
                                                end
                                            end
                                        end)
                                    end
                                end
                            end
                            -- [B19] The quartermaster APPRAISES
                            -- rather than counts: fuel, engine,
                            -- loudness, storage and whether a key is
                            -- even present. Counting hulks as wealth
                            -- is how the Ledger came to report
                            -- "wheels: 3" for a yard that could not
                            -- move.
                            local okV, vlist = pcall(function()
                                return SAOJavaBridge:appraiseVehiclesNear(
                                    body, 15)
                            end)
                            if okV and type(vlist) == "string" then
                                local cars = {}
                                for entry in vlist:gmatch("[^,]+") do
                                    local vn, vs, vf, vfu, ve, vl,
                                        vst, vig, vh, vd = entry:match(
                                        "^(.-)@(%d+)@(%d+)@(%d+)@(%d+)"
                                        .. "@(%d+)@(%d+)@(%d+)@(%d+)"
                                        .. "@(%d+)$")
                                    if vn then
                                        cars[#cars + 1] = {
                                            name = vn,
                                            seats = tonumber(vs),
                                            free = tonumber(vf),
                                            fuel = tonumber(vfu),
                                            engine = tonumber(ve),
                                            loud = tonumber(vl),
                                            storage = tonumber(vst),
                                            ignition = tonumber(vig),
                                            hotwired = tonumber(vh),
                                            dist = tonumber(vd),
                                        }
                                    end
                                end
                                SAO.Standing.setMotorPool(qG, cars)
                                if #cars > 0 then
                                    log(id .. " counts the motor pool: "
                                        .. #cars .. " vehicle(s)")
                                end
                            end
                        end
                    end
                end
            elseif desig == "cook" then
                -- [B20] The cook cooks. Vanilla gates dangerous raw
                -- food on `isbDangerousUncooked() and not isCooked()`,
                -- so this is the one job whose product is measured in
                -- other people's stomachs: the house's own larder
                -- stops being a thing that might kill you.
                --
                -- Needs a fire that is actually lit and ground that
                -- is actually theirs. A cook with no hearth is a
                -- person with a skill and nowhere to use it, which is
                -- honest and is most of the county's problem.
                why, answer = "works the fire", "designation"
                if SAO.Standing.insideClaim(id, body:getX(), body:getY())
                    and tick >= (agent.nextCookAt or 0) then
                    local hearth41 = nil
                    pcall(function()
                        hearth41 = SAOJavaBridge:hearthNear(body, 6)
                    end)
                    if hearth41 and hearth41 ~= "" then
                        local lvl41 = SAO.Census.skillOf(id, "Cooking")
                        if lvl41 < 0 then lvl41 = 0 end
                        local made41 = 0
                        pcall(function()
                            made41 = SAOJavaBridge:cookNearbyFood(
                                body, 6, lvl41)
                        end)
                        if made41 and made41 > 0 then
                            agent.nextCookAt = tick + 3600
                            agent.taskDeadline = tick + 900
                            pcall(function()
                                SAOJavaBridge:grantXP(body, "Cooking", 3.0)
                            end)
                            pcall(function()
                                SAO.Voice.onEvent(id, "cooks", tick)
                            end)
                            log(id .. " cooks " .. made41
                                .. " - the larder stops being dangerous")
                            setState(agent, id, "TREAT",
                                "cooks for the house", "designation")
                            return
                        end
                    end
                end
            elseif desig == "medic" then
                why, answer = "makes the rounds", "designation"
            elseif desig == "leads" then
                why, answer = "walks the company's ground", "designation"
            else
                why = "stretching legs (" .. range .. " tile range)"
            end
            -- [B19] What wheels actually buy is DISTANCE - the
            -- only currency a venture has. A house whose appraised
            -- pool holds a car that runs, with someone present who
            -- can start it, dares twice as far. A yard of hulks buys
            -- nothing, which is the whole point of appraising
            -- honestly.
            --
            -- The objection is a real decision, not a scripted line:
            -- someone who has learned that noise is a debt, whose
            -- only runnable car is a loud one, LEAVES IT and walks.
            -- They would rather take longer than announce
            -- themselves. (The loudness threshold is a judgment on a
            -- real per-script scale the game ships, the same way the
            -- [B7] cold thresholds are judgments on real degrees.)
            -- [B19] Hoisted out of the block so the seat count
            -- can reach the joining decision below: what car is being
            -- taken and how many seats are free is exactly what caps
            -- the party.
            local takingWheels = nil
            do
                local gW = SAO.Standing.groupOf(id)
                local wheels = gW and SAO.Standing.roadworthy
                    and SAO.Standing.roadworthy(gW) or nil
                if wheels then
                    local canTake = wheels.open
                        or (SAO.Census.canHotwire
                            and SAO.Census.canHotwire(id))
                    local tooLoud = (wheels.loud or 0) >= 50
                        and SAO.Lessons.has(id, "noise-is-a-debt")
                    local plain = tostring(wheels.name or "car")
                        :gsub("^Base%.", "")
                    if canTake and not tooLoud then
                        range = math.floor(range * 2)
                        takingWheels = wheels
                        why = why .. " - taking the " .. plain
                        pcall(function()
                            SAO.Voice.onEvent(id, "wheels", tick)
                        end)
                    elseif canTake and tooLoud then
                        log(id .. " leaves the " .. plain
                            .. " where it sits - too loud to"
                            .. " announce themselves")
                    end
                end
            end
            local bx, by = body:getX(), body:getY()
            local gx = math.floor(bx + ZombRand(-range, range + 1))
            local gy = math.floor(by + ZombRand(-range, range + 1))
            if watchEdge then
                gx, gy = math.floor(watchEdge.x), math.floor(watchEdge.y)
            end
            -- [B31] The trip costs the tank. [B31] found that
            -- `roadworthy` gates on fuel above 5 and NOTHING ever
            -- spent it, so a car sitting at 6% carried doubled-range
            -- ventures forever and still read 6%. Everywhere else in
            -- this mod, acting on real state changes it.
            --
            -- Spent here rather than where the car was chosen,
            -- because the honest quantity is the distance actually
            -- travelled - the range the car bought is a ceiling, not
            -- a journey.
            --
            -- The one judgment, in [B20]'s idiom: the engine exposes
            -- no consumption rate anywhere, so how much a trip costs
            -- cannot be read off anything. A full tank affords about
            -- twenty full-range ventures, so a full-range trip burns
            -- 5%. Everything that judgment scales IS read - the real
            -- distance, the real tank, the real capacity.
            if takingWheels and range > 0 then
                local tdx, tdy = gx - bx, gy - by
                local trip = math.sqrt(tdx * tdx + tdy * tdy)
                local share = trip / range
                if share > 1.0 then share = 1.0 end
                if share > 0.0 then
                    pcall(function()
                        local burned = SAOJavaBridge:spendVehicleFuel(
                            body, 15, tostring(takingWheels.name or ""),
                            5.0 * share)
                        if burned and burned > 0 then
                            log(id .. " burns "
                                .. string.format("%.1f", burned)
                                .. "% of the tank")
                        end
                    end)
                end
            end
            -- The word before the walk ([A28]): a designation venture
            -- with a real destination is TOLD to whoever stands near -
            -- sweeps, walls, war paths. The plain stretch of legs is
            -- not a venture and is not announced.
            -- [B19] A plain stretch of legs is NOT a venture and
            -- must clear the last one, or company from an old trip
            -- would follow someone who is just walking the yard.
            agent.onVenture = nil
            -- [B19] Hoisted: the company forms further down, once
            -- locomotion has actually ACCEPTED the trip. Announcing
            -- and departing are different moments and only the
            -- second one can be joined.
            local vkind, hearers = nil, nil
            if desig and (desig == "forager" or desig == "watch"
                or desig == "scout") then
                vkind = raidG and "warpath"
                    or allyWall and "allywall"
                    or deliveryRun and "delivery"
                    or (desig == "forager" and "sweep")
                    or (desig == "scout" and "scout") or "watchleg"
                pcall(function()
                    hearers = SAO.Perception.announceDeparture(
                        id, vkind, gx, gy)
                end)
                agent.onVenture = vkind
            end
            local nearFaction = SAO.Perception.believedFactionNear(id, gx, gy, 6)
            -- F-031: your own ground is never forbidden ground - a
            -- watch walking their own claim edge must not be blocked
            -- by a belief of their OWN base.
            if nearFaction and SAO.Standing.insideClaim(id, gx, gy) then
                nearFaction = nil
            end
            -- Pact ground is not forbidden ground ([A26]) - the
            -- delivery and the ally patrol must not be blocked by the
            -- very base they serve.
            if nearFaction then
                local pg2 = SAO.Standing.groupOf(id)
                if pg2 and SAO.Standing.pactBetween
                    and SAO.Standing.pactBetween(pg2, nearFaction) then
                    nearFaction = nil
                end
            end
            -- The raider walks in anyway ([A27]): on the war path,
            -- the enemy's believed presence is the POINT, not a
            -- deterrent. Only the raid target is cleared - everyone
            -- else's feud-shadow avoidance stands.
            if nearFaction and raidG and nearFaction == raidG then
                nearFaction = nil
            end
            if nearFaction then
                log(id .. " keeps clear of " .. tostring(nearFaction)
                    .. "'s ground (believed)")
            end
            if (gx ~= math.floor(bx) or gy ~= math.floor(by))
                and not nearFaction
                and mayEnterBelieved(id, gx, gy) then
                pcall(function() SAOJavaBridge:setForceEntry(body, false) end)
                if SAO.Locomotion.order(id, body, gx, gy, math.floor(body:getZ())) then
                    setState(agent, id, "ROAM", why, answer)
                    -- [B19] "They could go with them or they can stay
                    -- behind, let them handle it, learn." The briefing
                    -- was built; the joining never was. Each hearer
                    -- decides from who they ARE - nothing here is a roll,
                    -- and nothing is forced on anyone.
                    if hearers and #hearers > 0 then
                        local willing = {}
                        for _, hid in ipairs(hearers) do
                            local hAgent = Ctl.agents[hid]
                            local hRec = SAO.Identity.get(hid)
                            if hAgent and hRec and not hRec.dead
                                and not hAgent.escortId
                                and not hAgent.riding
                                and not hAgent.companioning then
                                -- Their own need governs (DR-011): a
                                -- person answering a NEED does not drop
                                -- it to keep someone company. Hunger does
                                -- not wait to be sociable.
                                local bound = hAgent.pressure
                                    and hAgent.pressure.answer == "need"
                                -- The circle law ([A27]): a loner keeps
                                -- their own company. Never forced, never
                                -- cured.
                                local solo = SAO.Disposition.circle(hid)
                                    == "loner"
                                -- The wall is not abandoned for a forage
                                -- run.
                                local onWall = hRec.designation == "watch"
                                    and vkind ~= "warpath"
                                local pull = SAO.Standing.trust(hid, id)
                                    + (SAO.Standing.isBondedTo(hid, id)
                                        and 0.3 or 0)
                                    + 0.2 * SAO.Lessons.weight(hid,
                                        "people-are-worth-it")
                                    - 0.2 * SAO.Lessons.weight(hid,
                                        "trust-carefully")
                                    + 0.2 * (SAO.Disposition.traits(hid)
                                        .nerve - 0.5)
                                if not bound and not solo and not onWall
                                    and pull > 0.55 then
                                    willing[#willing + 1] =
                                        { id = hid, pull = pull }
                                end
                            end
                        end
                        -- [B19] The keenest go. Who got turned away
                        -- used to be whatever order the hearer table
                        -- iterated in; the mirror caught it. Someone who
                        -- barely wanted to come is the right one to stay,
                        -- and it makes the "no room" moment mean
                        -- something.
                        table.sort(willing, function(a, b)
                            if a.pull == b.pull then return a.id < b.id end
                            return a.pull > b.pull
                        end)
                        -- Three caps, all real: what this person can bear
                        -- around them ([A27]), how many seats are
                        -- actually free in the car they are taking
                        -- ([B19]) - the goer occupies one - and whether
                        -- the house would be left with nobody minding
                        -- it.
                        local cap = SAO.Disposition.circleCap(id)
                        local seatBound = false
                        if takingWheels then
                            local free = math.max(0,
                                (takingWheels.free or 1) - 1)
                            if free < cap then cap, seatBound = free, true end
                        end
                        -- [B19] Somebody minds the place. Its own mirror
                        -- convicted this: houses of three or more emptied
                        -- behind the goer on a fifth of trips, nobody left
                        -- with a larder, a water store, or a fire to keep.
                        -- NOT a rule that someone must always stay - a
                        -- house holding nothing has nothing to mind and
                        -- all of it can walk. The keeper is the least-keen
                        -- of the willing, which the sort above already put
                        -- last.
                        if #hearers >= 2 then
                            local gH = SAO.Standing.groupOf(id)
                            local holds = gH and (
                                (SAO.Standing.larderOf
                                    and SAO.Standing.larderOf(gH))
                                or (SAO.Standing.waterStoreOf
                                    and SAO.Standing.waterStoreOf(gH))
                                or (SAO.Standing.hearthOf
                                    and SAO.Standing.hearthOf(gH))) or nil
                            if holds and cap > #hearers - 1 then
                                cap = #hearers - 1
                            end
                        end
                        for i = 1, #willing do
                            local wid = willing[i].id
                            local wAgent = Ctl.agents[wid]
                            if i <= cap and wAgent then
                                wAgent.escortId = id
                                pcall(function()
                                    SAO.Voice.onEvent(wid, "comeAlong", tick)
                                end)
                                log(wid .. " goes along with " .. id
                                    .. " on the " .. vkind)
                            else
                                pcall(function()
                                    SAO.Voice.onEvent(wid, "noRoom", tick)
                                end)
                                log(wid .. " stays behind - "
                                    .. (seatBound
                                        and ("no room in the car for "
                                            .. (#willing - cap) .. " more")
                                        or "more than " .. id
                                            .. " wants around them"))
                            end
                        end
                    end
                end
            end
        end
    end
end

-- The death sweep ([A17], shared at [A19]/F-027): the body still in
-- hand names its killer; witnesses judge by the standing rules - SAO
-- witnesses by a FRESH OBSERVED belief of the victim, Knox witnesses by
-- proximity; the routable walk over and the MOURNING close-out mints
-- their claims; the unroutable who loved the dead carry what they saw
-- from where they stand. Returns the cause when the engine names one.
-- One function for EVERY death - a Knox death and an SAO death are
-- witnessed by the same law.
-- The turning seen ([B3]): the zombie wearing a known face. Grief
-- speaks, the lesson lands witnessed, and a recorded promise sends
-- its keeper walking.
SAO.Perception.turnedHandler = function(witnessId, name, deadId, x, y, tick)
    pcall(function()
        SAO.Voice.onEvent(witnessId, "turnedSeen", tick or 0)
    end)
    pcall(function()
        local lessonKey = SAO.Lessons.lessonForCause("zombie")
        if lessonKey then
            SAO.Lessons.learn(witnessId, lessonKey, 0.8, "witnessed", name)
        end
    end)
    -- The county's first turning ([B3]): stamped once, aired once -
    -- the day the dead stopped staying dead is chronicle-grade.
    pcall(function()
        local sT = ModData.getOrCreate("SurvivorAwareness_Standing")
        if sT and not sT.firstTurnedAtHours then
            -- [B34] Stamp LAST, for the same reason as the taps: the
            -- guard only ever opens once, so anything that throws
            -- between the stamp and the telling keeps the day and
            -- loses the chronicle entry with no way back.
            local atH = GameTime.getInstance():getWorldAgeHours()
            SAO.Standing.pushRadioNews({ kind = "turned", name = name })
            sT.firstTurnedAtHours = atH
        end
    end)
    local keeper = SAO.Standing.promiseKeeperOf
        and SAO.Standing.promiseKeeperOf(deadId) or nil
    if keeper == witnessId then
        local agent = Ctl.agents[witnessId]
        if agent then
            agent.promiseTarget = { x = x, y = y, deadId = deadId,
                name = name }
        end
    end
    log(witnessId .. " sees what " .. tostring(name)
        .. " became")
end

-- The reunion ([A28]): a believer who held someone dead sees them
-- alive. The moment is voiced, the standing grief errand for the
-- living is cleared, and the remembered teller takes a wound - light
-- for fear-bred presumption, harder for word passed as witnessed.
-- Beliefs upgraded in place (no teller remembered) wound nobody: the
-- machinery only blames where it actually knows.
SAO.Perception.reunionHandler = function(believerId, name, teller,
        presumed, tick)
    local agent = Ctl.agents[believerId]
    if agent then
        local livingId = SAO.Identity.idByName
            and SAO.Identity.idByName(name) or nil
        if livingId and agent.mourned then
            agent.mourned[livingId] = nil
        end
    end
    pcall(function()
        SAO.Voice.onEvent(believerId, "reunion", tick or 0)
    end)
    if teller then
        SAO.Standing.adjustTrust(believerId, teller,
            presumed and -0.1 or -0.25)
    end
    log(believerId .. " finds " .. tostring(name)
        .. " ALIVE - the word was wrong"
        .. (teller and (" (heard from " .. tostring(teller) .. ")") or ""))
end

-- [B18] The player notices ([A19]'s witnessing, player-ward): when
-- someone they knew dies within sight, the player is told once, the
-- way the game tells them anything - a line over their head, not a
-- console print they will never read. Strangers dying nearby are
-- part of the world's noise; someone you knew is not.
local function tellPlayerOfDeath(deadId, deadRec, deadBody)
    local me = getSpecificPlayer(0)
    if not me or me:isDead() or not deadBody or not deadRec then return end
    local dx = deadBody:getX() - me:getX()
    local dy = deadBody:getY() - me:getY()
    if dx * dx + dy * dy > 900 then return end
    local myKey = SAO.Standing.playerKey(me)
    -- [B20] This asked the wrong question. The comment above says
    -- "someone they knew" and "strangers dying nearby are part of the
    -- world's noise" - that is FAMILIARITY, and the test was
    -- affection. A rival who had been raiding the player for weeks
    -- could drop dead twenty feet away and register as nothing.
    -- Their death is not world noise; it is the most significant news
    -- of the day.
    local known = SAO.Standing.knowsOf(myKey, deadId)
        or SAO.Standing.knowsOf(deadId, myKey)
        or SAO.Standing.isBondedTo(deadId, myKey)
    if not known then return end
    pcall(function()
        HaloTextHelper.addBadText(me,
            tostring(SAO.Identity.displayName(deadRec)) .. " is dead.")
    end)
end

local function witnessDeath(id, agent, body)
    local okA, tag = pcall(function()
        return SAOJavaBridge:getLastAttackerTag(body)
    end)
    tag = okA and tostring(tag) or ""
    local kind, killerName = string.match(tag, "^(%w+):(.+)$")
    local attackerKey = nil
    if kind == "player" or kind == "shell" then
        attackerKey = SAO.Standing.keyForAttackerTag(kind, killerName)
    end
    local cause = attackerKey
        and ("killed by " .. tostring(killerName)) or nil
    -- The fall teaches ([B1], blocker fixed): a zombie's kill carried
    -- no cause and taught NOTHING - "zombie" has no colon and failed
    -- the kind:name match. Named now; lessonForCause does the rest.
    if not cause and tag == "zombie" then
        cause = "zombie"
        -- The first zombie kill anyone witnesses is county news, once:
        -- the moment the innocent county learns what this is.
        local okOB, sOB = pcall(function()
            return ModData.getOrCreate("SurvivorAwareness_Standing")
        end)
        if okOB and sOB and not sOB.outbreakAired then
            sOB.outbreakAired = true
            pcall(function()
                sOB.outbreakAtHours =
                    GameTime.getInstance():getWorldAgeHours()
            end)
            pcall(function()
                SAO.Standing.pushRadioNews({ kind = "outbreak" })
            end)
        end
    end
    -- The skirmish airs ([A27]): a cross-house kill during a feud is
    -- county news, once per death, at the seam that already knows
    -- killer and victim.
    if kind == "shell" and attackerKey then
        local vg = SAO.Standing.groupOf(id)
        local ag = SAO.Standing.groupOf(attackerKey)
        if vg and ag and vg ~= ag
            and SAO.Standing.feudBetween(vg, ag) then
            pcall(function()
                SAO.Standing.pushRadioNews({
                    kind = "skirmish", a = tostring(ag), b = tostring(vg),
                })
            end)
        end
    end
    local dxs = (agent.rec and agent.rec.x) or 0
    local dys = (agent.rec and agent.rec.y) or 0
    local victimName = agent.rec
        and SAO.Identity.displayName(agent.rec) or nil
    if victimName == "Unnamed" then victimName = nil end
    for witnessId, witness in pairs(Ctl.agents) do
        if witnessId ~= id and witnessId ~= attackerKey then
            local qualifies = false
            if witness.passive then
                local wrec = witness.rec
                local wdx = (wrec and wrec.x or 1e9) - dxs
                local wdy = (wrec and wrec.y or 1e9) - dys
                -- [B47] The dormant spelling of the SAME rule the
                -- live branch below reads as WITNESS_REACH. [B43]
                -- argued three spellings of "close enough to have
                -- seen it" down to one constant and never looked in
                -- here, because this half asks the question
                -- positionally - a record has no beliefs to carry a
                -- `dist`. Ten tiles either way, and if the sightline
                -- rule ever moves, the unloaded half of the county
                -- must not keep the old one.
                qualifies = (wdx * wdx + wdy * wdy)
                    <= WITNESS_REACH * WITNESS_REACH
            else
                local beliefs = SAO.Perception.beliefs[witnessId]
                local seen = beliefs and victimName
                    and beliefs.people[victimName] or nil
                qualifies = seen and seen.source == "observed"
                    and (tickCount - seen.at) <= WITNESS_FRESH
                    and seen.dist <= WITNESS_REACH or false
                -- What they saw is now what they know ([A19]): the
                -- death lands on the witness's own belief, and tell()
                -- carries it down the roads from here.
                if qualifies and seen then seen.dead = true end
            end
            if qualifies then
                local lovedVictim = SAO.Standing.trust(witnessId, id) > 0.5
                    or SAO.Standing.isBondedTo(witnessId, id)
                if attackerKey
                    and not SAO.Standing.sameGroup(witnessId, attackerKey) then
                    local after = SAO.Standing.adjustTrust(
                        witnessId, attackerKey, -0.8)
                    if lovedVictim or after
                        < SAO.Disposition.hostilityBar(witnessId) then
                        SAO.Standing.setHostile(witnessId, attackerKey, true)
                    end
                    log(witnessId .. " saw " .. tostring(killerName)
                        .. " kill " .. tostring(victimName or id)
                        .. (lovedVictim and " - a friend; hostility declared"
                            or " - trust now " .. string.format("%.2f", after)))
                end
                pcall(function()
                    SAO.Voice.onEvent(witnessId, "witnessed", tickCount)
                end)
                local routed = false
                if not witness.passive
                    and (witness.state == "IDLE" or witness.state == "ROAM") then
                    local wbody = SAO.Body.get(witnessId)
                    if wbody and SAO.Locomotion.order(witnessId, wbody,
                        math.floor(dxs), math.floor(dys),
                        math.floor(wbody:getZ())) then
                        witness.mournTarget = id
                        witness.mournName = victimName or id
                        witness.taskDeadline = tickCount + 1800
                        setState(witness, witnessId, "MOURNWARD",
                            "walks to where "
                            .. tostring(victimName or id) .. " lies")
                        routed = true
                    end
                end
                if not routed and lovedVictim then
                    if SAO.Standing.isBondedTo(witnessId, id) then
                        local tr = SAO.Disposition.traits(witnessId)
                        local claim = (tr.aggression >= tr.nerve)
                            and "nothing-left-to-lose"
                            or "never-again-that-close"
                        SAO.Lessons.learn(witnessId, claim, 1.0,
                            "lived", victimName or id)
                    else
                        SAO.Lessons.learn(witnessId, "measure-the-danger",
                            0.6, "witnessed", victimName or id)
                    end
                end
            end
        end
    end
    return cause
end

local function updateAgent(id, agent)
    local body = SAO.Body.get(id)
    if not body then return end

    -- The passive path ([A17]): Knox people are subjects and speakers in
    -- the economy, never our puppets. Death is noticed and mourned like
    -- anyone's; on a slow cadence they INITIATE exchanges (lessons,
    -- grudges, company - the record-side blocks; body-side blocks no-op
    -- safely on non-shells), so transmission runs among them, not only
    -- toward us.
    if agent.passive then
        local okDead, dead = pcall(function() return body:isDead() end)
        if okDead and dead then
            -- The county mourns its own ([A17], sweep shared at [A19]):
            -- witnessed, judged, and mourned by the one law all deaths
            -- share.
            local cause = witnessDeath(id, agent, body) or "unknown"
            SAO.Identity.markDead(agent.rec, tickCount, cause)
            tellPlayerOfDeath(id, agent.rec, body)
            SAO.Body.knox[id] = nil
            -- [B51] Both handles on both branches. This branch is
            -- the passive one and a passive agent is very probably
            -- never in `active` - but "very probably" is the kind of
            -- reasoning that expires, and nilling an absent key costs
            -- nothing. Guarded rather than argued.
            SAO.Body.active[id] = nil
            Ctl.agents[id] = nil
            log(id .. " has died (" .. cause .. "); the county remembers")
            return
        end
        pcall(function()
            agent.rec.x, agent.rec.y = body:getX(), body:getY()
        end)
        if tickCount >= (agent.nextDecisionAt or 0) then
            agent.nextDecisionAt = tickCount + 120
            for otherId in pairs(Ctl.agents) do
                if otherId ~= id then
                    local otherBody = SAO.Body.get(otherId)
                    if otherBody then
                        local dx = otherBody:getX() - body:getX()
                        local dy = otherBody:getY() - body:getY()
                        if dx * dx + dy * dy
                            <= TALK_REACH * TALK_REACH then
                            SAO.Exchange.betweenPair(
                                id, agent, body, otherId, otherBody, tickCount)
                        end
                    end
                end
            end
        end
        return
    end

    -- Mortality: the body died in the world. The record becomes a death
    -- record, the agent ends, and the corpse is the engine's - a person
    -- ended, they do not despawn.
    local okDead, dead = pcall(function() return body:isDead() end)
    if okDead and dead then
        -- F-027: an SAO death is witnessed by the SAME sweep as a Knox
        -- death - killer named from the corpse, witnesses judge, the
        -- bereaved routed or minted. The engine's attacker tag outranks
        -- the state-based guesses when it names someone.
        local cause = witnessDeath(id, agent, body)
        if not cause then
            cause = "unknown"
            if agent.state == "ENGAGE" then
                cause = "combat"
            else
                local okB, bleedN = pcall(function()
                    return SAOJavaBridge:getBleedingCount(body)
                end)
                if okB and tonumber(bleedN) and tonumber(bleedN) > 0 then
                    cause = "bleeding"
                end
            end
        end
        SAO.Identity.markDead(agent.rec, tickCount, cause)
        local deadGroup = SAO.Standing.groupOf(id)
        if deadGroup and SAO.Standing.leaderOf(deadGroup) == id then
            local newLeader = SAO.Standing.electLeader(deadGroup)
            log(deadGroup .. ": leadership passes from the dead to "
                .. tostring(newLeader))
        end
        pcall(function()
            SAO.Identity.updatePosition(agent.rec, body:getX(), body:getY(), body:getZ())
        end)
        SAO.Body.active[id] = nil   -- forget the handle; never removeFromWorld a corpse
        SAO.Body.knox[id] = nil     -- [B51] both handles on both branches
        Ctl.agents[id] = nil
        log(id .. " has died")
        return
    end

    -- Perception acquisition runs on its own cadence regardless of
    -- state - except for the one state that has always contradicted
    -- it ([B19]). A sleeping person is not a sentry.
    SAO.Perception.observe(id, body, tickCount, agent.sleeping)

    -- Combat pump: harness-initiated engagements tick Java-side combat and
    -- exit on its evidence-based verdicts.
    if agent.state == "ENGAGE" then
        local ok, verdict = pcall(function() return SAOJavaBridge:tickCombat(body) end)
        verdict = ok and tostring(verdict) or ("tick threw: " .. tostring(verdict))
        if verdict ~= (agent.lastCombatVerdict or "") then
            log(id .. " " .. verdict)
            agent.lastCombatVerdict = verdict
        end
        if verdict:find("OUT_OF_AMMO", 1, true) then
            pcall(function() SAOJavaBridge:resetCombat(body) end)
            if SAO.Needs.queueReload(id, body) then
                agent.taskDeadline = tickCount + 1800
                setState(agent, id, "RELOAD", "gun dry - reloading")
            else
                pcall(function() SAOJavaBridge:equipBestMelee(body) end)
                agent.nextDecisionAt = 0
                setState(agent, id, "ALERT", "gun dry, no reload - back to the bat")
            end
            return
        end
        if verdict:find("SUCCEEDED", 1, true) then
            -- Respect, witnessed: anyone with a fresh observed belief of
            -- this fighter saw them destroy a threat. The positive mirror
            -- of witnessed violence, and it crosses group lines - people
            -- trust demonstrated competence.
            local fighterName = agent.rec
                and SAO.Identity.displayName(agent.rec) or nil
            if fighterName == "Unnamed" then fighterName = nil end
            for witnessId in pairs(Ctl.agents) do
                if witnessId ~= id and fighterName then
                    local wb = SAO.Perception.beliefs[witnessId]
                    local seen = wb and wb.people[fighterName] or nil
                    if seen and seen.source == "observed"
                        and (tickCount - seen.at) <= WITNESS_FRESH
                        and seen.dist <= WITNESS_REACH then
                        SAO.Standing.adjustTrust(witnessId, id, 0.05)
                        log(witnessId .. " saw " .. fighterName
                            .. " handle a threat - respect earned")
                    end
                end
            end
        end
        if verdict:find("SUCCEEDED", 1, true) or verdict:find("FAILED", 1, true)
            or verdict == "COMBAT_IDLE" then
            pcall(function() SAOJavaBridge:resetCombat(body) end)
            -- After gunfire the bat comes back out: quiet is the
            -- default. The HARDENED override it ([A19]) - a deputy or
            -- a soldier keeps a fed gun in hand; who you were decides
            -- what your hands trust.
            local hardened = SAO.Census and SAO.Census.classOf
                and SAO.Census.classOf(agent.rec
                    and agent.rec.occupation) == "hardened"
            local keepGun = false
            if hardened then
                local okD, described = pcall(function()
                    return SAOJavaBridge:describeWeapon(body)
                end)
                local ammo = okD and tonumber(string.match(
                    tostring(described), "^ranged:(%-?%d+)$")) or 0
                keepGun = ammo and ammo > 0
            end
            if not keepGun then
                pcall(function() SAOJavaBridge:equipBestMelee(body) end)
            end
            setState(agent, id, "IDLE", verdict)
        end
        return
    end

    -- RELOAD hold: the vanilla action runs; when the queue drains the gun
    -- is either fed (fight resumes next decision) or still dry (melee).
    if agent.state == "RELOAD" then
        if not SAO.Needs.busy(body) then
            local okD, described = pcall(function()
                return SAOJavaBridge:describeWeapon(body)
            end)
            local ammo = okD and tonumber(string.match(tostring(described), "^ranged:(%-?%d+)$")) or 0
            if ammo and ammo > 0 then
                agent.nextDecisionAt = 0
                setState(agent, id, "ALERT", "reloaded - reassessing")
            else
                pcall(function() SAOJavaBridge:equipBestMelee(body) end)
                agent.nextDecisionAt = 0
                setState(agent, id, "ALERT", "reload yielded nothing - back to the bat")
            end
        elseif agent.taskDeadline and tickCount > agent.taskDeadline then
            pcall(function() SAOJavaBridge:equipBestMelee(body) end)
            setState(agent, id, "ALERT", "reload overstayed its deadline")
        end
        return
    end

    -- MOURNING hold: a pause over the body. Grief speaks at the start;
    -- the suspicion the dead leave behind lands when the pause ends. A
    -- Warming holds ([B6]): sitting at a fire is a real pause, not a
    -- label - it ends when the cold lifts, when the fire dies, when
    -- the hold runs out, or when something closes on them. The
    -- environment still collects: a threat outranks warmth.
    if agent.state == "WARMING" then
        local wThreat = SAO.Perception.nearestBelievedZombie(
            id, tickCount, body:getX(), body:getY())
        local stillCold = SAO.Needs.cold(body) >= 0.4
        local _, _, _, hfuel2 = SAO.Needs.findHearth(id, body, 4)
        if wThreat and wThreat.dist <= SAO.Disposition.fleeDistance(id) then
            setState(agent, id, "IDLE", "leaves the fire - something close")
            return
        end
        if not stillCold then
            setState(agent, id, "IDLE", "warm again")
            return
        end
        if not hfuel2 or hfuel2 <= 0 then
            setState(agent, id, "IDLE", "the fire has gone out")
            return
        end
        if tickCount > (agent.taskDeadline or 0) then
            setState(agent, id, "IDLE", "done warming")
            return
        end
        return
    end

    -- close threat cuts it short - the dead forgive that.
    if agent.state == "MOURNING" then
        if not agent.mournSpoken then
            agent.mournSpoken = true
            pcall(function() SAO.Voice.onEvent(id, "grief", tickCount) end)
            log(id .. " mourns " .. tostring(agent.mournName))
        end
        local mThreat = SAO.Perception.nearestBelievedZombie(
            id, tickCount, body:getX(), body:getY())
        local done = tickCount >= (agent.mournHoldUntil or 0)
        if done or (mThreat and mThreat.dist <= SAO.Disposition.fleeDistance(id)) then
            -- Standing over the body is evidence ([A19]): the mourner's
            -- own belief of this person now carries the death.
            if agent.mournName then
                local mb = SAO.Perception.beliefs[id]
                local pbelief = mb and mb.people[agent.mournName] or nil
                if pbelief then pbelief.dead = true end
            end
            local deadId = agent.mournTarget
            if deadId then
                local deadRec = SAO.Identity.get(deadId)
                local lessonKey = deadRec
                    and SAO.Lessons.lessonForCause(deadRec.deathCause)
                if lessonKey and SAO.Lessons.learn(id, lessonKey, 0.6, "witnessed", agent.mournName) then
                    log(id .. " takes a lesson from how "
                        .. tostring(agent.mournName) .. " died: " .. lessonKey)
                end
                -- The trauma fork ([A14]): losing your BONDED mints a
                -- lived claim at full weight, forked ONCE by who you
                -- already were - vengeance or collapse. No prose.
                if SAO.Standing.isBondedTo(id, deadId) then
                    local tr = SAO.Disposition.traits(id)
                    local claim = (tr.aggression >= tr.nerve)
                        and "nothing-left-to-lose"
                        or "never-again-that-close"
                    if SAO.Lessons.learn(id, claim, 1.0, "lived", agent.mournName) then
                        pcall(function()
                            SAO.Voice.onEvent(id,
                                claim == "nothing-left-to-lose"
                                    and "traumaRage" or "traumaBreak",
                                tickCount)
                        end)
                        log(id .. " is not who they were: '" .. claim
                            .. "' (lost their bonded)")
                    end
                end
            end
            if deadId and SAO.Standing.trust(id, deadId) > 0.3 then
                for _, enemyKey in ipairs(SAO.Standing.enemiesOf(deadId)) do
                    if enemyKey ~= id
                        and not SAO.Standing.isHostileTo(id, enemyKey) then
                        SAO.Standing.adjustTrust(id, enemyKey, -0.2)
                        log(id .. " remembers who " .. tostring(agent.mournName)
                            .. " feared - suspicion inherited")
                    end
                end
            end
            agent.mournTarget, agent.mournName = nil, nil
            agent.mournSpoken, agent.mournHoldUntil = nil, nil
            agent.nextDecisionAt = 0
            setState(agent, id, done and "IDLE" or "ALERT",
                done and "the pause ends; the day continues" or "grief cut short")
        end
        return
    end

    -- RIP hold: the time a rip takes, charged before the transform. A
    -- believed threat inside flee distance abandons the attempt (cloth
    -- stays whole; bleeding continues; flight decides next).
    if agent.state == "RIP" then
        local ripThreat = SAO.Perception.nearestBelievedZombie(
            id, tickCount, body:getX(), body:getY())
        if ripThreat and ripThreat.dist <= SAO.Disposition.fleeDistance(id) then
            agent.ripDoneAt = nil
            agent.nextDecisionAt = 0
            setState(agent, id, "ALERT", "rip abandoned: threat close")
            return
        end
        if tickCount >= (agent.ripDoneAt or 0) then
            agent.ripDoneAt = nil
            local okT, ripped = pcall(function()
                return SAOJavaBridge:ripClothForRags(body)
            end)
            if okT and type(ripped) == "string" and ripped ~= "" then
                agent.nextDecisionAt = 0
                setState(agent, id, "IDLE", "ripped " .. ripped .. " into rags")
            else
                setState(agent, id, "IDLE", "rip yielded nothing")
            end
        end
        return
    end

    -- Need-action holds: the body's own action stack is the truth. EAT and
    -- TAKE end when the queue drains (or the deadline passes - a wedged
    -- action never wedges the person). A believed threat inside this
    -- person's own flee distance interrupts the meal - the queue is cleared
    -- and the next decision handles the danger.
    if agent.state == "EAT" or agent.state == "TAKE" or agent.state == "DRINK"
        or agent.state == "TREAT" then
        local threat = SAO.Perception.nearestBelievedZombie(
            id, tickCount, body:getX(), body:getY())
        if threat and threat.dist <= SAO.Disposition.fleeDistance(id) then
            pcall(function() ISTimedActionQueue.clear(body) end)
            SAO.Needs.clearSource(body)
            agent.nextDecisionAt = 0
            setState(agent, id, "ALERT",
                string.format("meal interrupted: believed threat at %.1f tiles", threat.dist))
            return
        end
        if not SAO.Needs.busy(body) then
            if agent.state == "TAKE" and agent.takePurpose == "offered" then
                agent.takePurpose = nil
                SAO.Needs.clearOffered(body)
                -- Kindness attribution: the nearest person believed HERE,
                -- fresh and close, gets the credit and the thanks.
                local beliefs = SAO.Perception.beliefs[id]
                local giverName, giverDist
                if beliefs then
                    for name, belief in pairs(beliefs.people) do
                        if belief.source == "observed"
                            and (tickCount - belief.at) <= 120 then
                            local dx = belief.x - body:getX()
                            local dy = belief.y - body:getY()
                            local d = math.sqrt(dx * dx + dy * dy)
                            if d <= 5.0 and (not giverDist or d < giverDist) then
                                giverName, giverDist = name, d
                            end
                        end
                    end
                end
                if giverName then
                    local giverKey = SAO.Standing.keyForObserved(giverName)
                    if not SAO.Standing.isHostileTo(id, giverKey) then
                        SAO.Standing.adjustTrust(id, giverKey, 0.15)
                        pcall(function() SAO.Voice.onEvent(id, "thanks", tickCount) end)
                        log(id .. " takes the gift and thanks " .. giverName)
                    end
                else
                    log(id .. " pockets a found item (nobody to thank)")
                end
                pcall(function() SAOJavaBridge:equipBestMelee(body) end)
                setState(agent, id, "IDLE", "ground item taken")
            elseif agent.state == "TAKE" and agent.takePurpose == "deposit" then
                -- A deposit ends with the shelf fuller, not a snack
                -- ([A19]): nothing to clear, nothing to eat. Work
                -- teaches ([A24]): a sliver of fitness for the labor.
                agent.takePurpose = nil
                pcall(function()
                    SAOJavaBridge:grantXP(body, "Fitness", 1.0)
                end)
                setState(agent, id, "IDLE", "the stores are stocked")
            elseif agent.state == "TAKE" and agent.takePurpose == "ammo" then
                agent.takePurpose = nil
                SAO.Needs.clearAmmo(body)
                setState(agent, id, "IDLE", "ammunition pocketed")
            elseif agent.state == "TAKE" and agent.takePurpose == "gear" then
                agent.takePurpose = nil
                SAO.Needs.clearGear(body)
                local okE, what = pcall(function()
                    return SAOJavaBridge:equipBestMelee(body)
                end)
                setState(agent, id, "IDLE",
                    "gear taken: " .. (okE and tostring(what) or "equip failed"))
            elseif agent.state == "TAKE" then
                -- Food now in the pack (or the take failed) - eat if possible.
                -- Work teaches ([A24]): the forage take builds Foraging.
                pcall(function()
                    SAOJavaBridge:grantXP(body, "Foraging", 1.0)
                end)
                SAO.Needs.clearSource(body)
                if SAO.Needs.eatCarried(id, body) then
                    -- [B43] The shelves are not infinite for the LOADED
                    -- half either. [B39] made a place spent by being
                    -- visited and wired it into `dormantLife` alone, so
                    -- `Pl.take` had exactly one caller and a survivor
                    -- standing in a grocery could eat it bare while the
                    -- county's ledger never moved. Same asymmetry as
                    -- [B39] on Desperation, [B39] on ErrandRadius and
                    -- [B42] on whose ground it is - the fourth, and the
                    -- largest, because it is a whole economy only half
                    -- the county was in.
                    --
                    -- The dormant rule is mirrored exactly rather than
                    -- re-invented: recorded only when they ACTUALLY took
                    -- something, so walking through a warehouse for the
                    -- shelter does not empty it.
                    pcall(function()
                        local herePl = SAO.Places.at(body:getX(), body:getY())
                        if herePl then SAO.Places.take(herePl) end
                    end)
                    agent.taskDeadline = tickCount + 1800
                    setState(agent, id, "EAT", "took food, now eats")
                else
                    setState(agent, id, "IDLE", "take yielded nothing edible")
                end
            elseif agent.state == "DRINK" then
                -- [B43] And water, on the same rule. The dormant day
                -- spends a place on `got.water or got.food`; both halves
                -- of the county now read the one rule rather than the
                -- loaded half reading none of it.
                SAO.Needs.clearWater(body)
                pcall(function()
                    local herePl = SAO.Places.at(body:getX(), body:getY())
                    if herePl then SAO.Places.take(herePl) end
                end)
                setState(agent, id, "IDLE", "finished drinking")
            elseif agent.state == "TAKE"
                and agent.takePurpose == "farm" then
                -- The plant is tended or the crop is in the pack
                -- ([B4]); the shelving machinery takes it from here.
                agent.takePurpose = nil
                setState(agent, id, "IDLE", "the ground is worked")
            elseif agent.state == "TAKE"
                and agent.takePurpose == "build" then
                -- The board is up (or the action lapsed) ([B2]): the
                -- engine granted the Carpentry itself; the wall is
                -- the reward.
                agent.takePurpose = nil
                setState(agent, id, "IDLE", "the window is boarded")
            elseif agent.state == "TREAT" then
                -- More wounds? The next decision re-enters TREAT.
                -- Binding your own wound teaches too ([B2]) - the
                -- last write-only gap in the XP loop.
                pcall(function()
                    SAOJavaBridge:grantXP(body, "Doctor", 1.0)
                end)
                setState(agent, id, "IDLE", "wound bound")
            else
                setState(agent, id, "IDLE", "finished eating")
            end
        elseif agent.taskDeadline and tickCount > agent.taskDeadline then
            SAO.Needs.clearSource(body)
            setState(agent, id, "IDLE", "action overstayed its deadline")
        end
        return
    end

    -- Locomotion verdicts drive state exits for movement states.
    if agent.state == "TRAVEL" or agent.state == "FLEE" or agent.state == "ROAM"
        or agent.state == "HOMEWARD" or agent.state == "FORAGE"
        or agent.state == "FOLLOW" or agent.state == "WATERWARD"
        or agent.state == "GEARWARD" or agent.state == "AMMOWARD"
        or agent.state == "MOURNWARD" or agent.state == "PLAYERFOLLOW"
        or agent.state == "SETTLEWARD" or agent.state == "MEDICWARD"
        or agent.state == "SEARCHWARD" or agent.state == "HEARTHWARD" then
        SAO.Locomotion.tick(id)
        local s = SAO.Locomotion.status(id)
        if s:sub(1, 5) == "done:" then
            pcall(function()
                SAO.Identity.updatePosition(agent.rec, body:getX(), body:getY(), body:getZ())
            end)
            -- The restraint decision, visible: a locked or barricaded door on
            -- a non-urgent walk is declined, not forced and not window-smashed.
            if s:find("LOCKED", 1, true) or s:find("BARRICADED", 1, true) then
                if not SAO.Disposition.wouldForceEntry(id, agent.state == "FLEE") then
                    log(id .. " declined forcing a locked door (no urgency, no standing)")
                end
            end
            -- The forager's haul ([A28]): a sweep that ARRIVES
            -- somewhere actually collects - real food out of the real
            -- containers at the destination, conserved. Barren ground
            -- yields nothing; ground sweeps thin over time because the
            -- items genuinely leave the shelves.
            if agent.state == "ROAM" and s:find("arrived", 1, true) then
                local rRec = agent.rec
                -- Never off the house's own shelves ([A28]): the
                -- sweep gathers OUT THERE - collecting at home would
                -- loop take-and-shelve and dodge the watch-first
                -- store gate.
                if rRec and rRec.designation == "forager"
                    and not SAO.Standing.insideClaim(
                        id, body:getX(), body:getY()) then
                    -- Skilled eyes gather more ([B2]): the haul cap
                    -- reads the real Foraging level.
                    local fLvl = SAO.Census.skillOf
                        and SAO.Census.skillOf(id, "Foraging") or 0
                    if fLvl < 0 then fLvl = 0 end
                    local haulMax = math.min(4, 2 + math.floor(fLvl / 4))
                    local okT, took = pcall(function()
                        return SAOJavaBridge:takeWantedFromNearby(
                            body, 4, "food", haulMax)
                    end)
                    if okT and type(took) == "number" and took > 0 then
                        pcall(function()
                            SAOJavaBridge:grantXP(body, "Foraging", 1.0)
                        end)
                        log(id .. " gathered " .. took
                            .. " from the sweep")
                    end
                end
            end
            if agent.state == "SEARCHWARD" then
                -- The search ends where the trail does ([A28]): the
                -- scanner has been looking the whole walk. If the
                -- missing were HERE, the belief refreshed (and the
                -- [A28] reunion fired if they had been buried by
                -- word). If not, the searcher lets the place answer
                -- with silence and goes home; the question stays open.
                local sName = agent.searchName
                local sb = SAO.Perception.beliefs[id]
                local spb = sb and sName and sb.people[sName] or nil
                local found = spb and spb.source == "observed"
                    and (tickCount - spb.at) <= 200
                -- The worst answer ([B1]): the ground is read for the
                -- missing person's NAMED corpse - the engine's own
                -- dead, no conjuring. Finding it writes the witnessed
                -- death into the searcher's head; grief and the
                -- mourning walk compose from the belief.
                if not found and sName and sb then
                    local okC8, corpses = pcall(function()
                        return SAOJavaBridge:findNamedCorpses(body, 8)
                    end)
                    if okC8 and type(corpses) == "string"
                        and corpses ~= "" then
                        for entry in corpses:gmatch("[^|]+") do
                            local cn = entry:match("^(.-):")
                            if cn == sName then
                                local spb2 = sb.people[sName]
                                if spb2 then
                                    spb2.dead = true
                                end
                                pcall(function()
                                    SAO.Voice.onEvent(id, "grief",
                                        tickCount)
                                end)
                                log(id .. " found " .. sName
                                    .. " - too late. The search ends"
                                    .. " in grief")
                                agent.searchName = nil
                                setState(agent, id, "IDLE",
                                    "found " .. sName .. " dead", "need")
                                return
                            end
                        end
                    end
                end
                if found then
                    log(id .. " found " .. tostring(sName)
                        .. " - the search ends well")
                else
                    log(id .. " searched where " .. tostring(sName)
                        .. " was last seen - nothing. The question stays open")
                end
                agent.searchName = nil
                setState(agent, id, "IDLE", found
                    and ("found " .. tostring(sName))
                    or "the search came up empty")
                return
            end
            if agent.state == "MOURNWARD" then
                if s:find("arrived", 1, true) and agent.mournTarget then
                    agent.mourned = agent.mourned or {}
                    agent.mourned[agent.mournTarget] = true
                    agent.mournHoldUntil = tickCount + 200
                    setState(agent, id, "MOURNING",
                        "stands over " .. tostring(agent.mournName))
                    return
                end
                -- Unreachable body: grieve from afar, once - never a
                -- 900-tick retry loop at a corpse behind a wall.
                if agent.mournTarget then
                    agent.mourned = agent.mourned or {}
                    agent.mourned[agent.mournTarget] = true
                    pcall(function() SAO.Voice.onEvent(id, "grief", tickCount) end)
                    local deadRec = SAO.Identity.get(agent.mournTarget)
                    local lessonKey = deadRec
                        and SAO.Lessons.lessonForCause(deadRec.deathCause)
                    if lessonKey then
                        SAO.Lessons.learn(id, lessonKey, 0.6, "witnessed", agent.mournName)
                    end
                    log(id .. " could not reach " .. tostring(agent.mournName)
                        .. "; grieves from afar")
                end
                agent.mournTarget, agent.mournName = nil, nil
                setState(agent, id, "IDLE", "the walk to the dead ended: " .. s)
                return
            end
            if agent.state == "SETTLEWARD" then
                local cand = agent.settleCandidate
                local sGroup = SAO.Standing.groupOf(id)
                if s:find("arrived", 1, true) and cand and sGroup then
                    SAO.Standing.setGroupClaim(sGroup,
                        cand.minX - 1, cand.minY - 1,
                        cand.maxX + 1, cand.maxY + 1, 0)
                    -- Homes converge: the base is where the faction lives
                    -- now; dusk homing and dormant night-drift follow the
                    -- home fields with no further wiring.
                    local moved = 0
                    local rec2 = agent.rec
                    if rec2 then
                        rec2.homeX, rec2.homeY, rec2.homeZ = cand.cx, cand.cy, 0
                    end
                    for _, mid in ipairs(SAO.Standing.fellowsOf(id)) do
                        local mrec = SAO.Identity.get(mid)
                        if mrec then
                            mrec.homeX, mrec.homeY, mrec.homeZ = cand.cx, cand.cy, 0
                            moved = moved + 1
                        end
                    end
                    pcall(function() SAO.Voice.onEvent(id, "settled", tickCount) end)
                    -- The county writes itself ([A24]): a claim note at
                    -- the door - readable by anyone who walks up.
                    pcall(function()
                        local me3 = getSpecificPlayer(0)
                        if me3 then
                            SAOJavaBridge:dropNoteAt(me3,
                                cand.cx, cand.cy, 0,
                                tostring(SAO.Standing.factionName(sGroup)
                                    or "A company") .. " - claim notice",
                                "This place is held by the "
                                .. tostring(SAO.Standing.factionName(sGroup)
                                    or "company")
                                .. ". Ask before you wander in.")
                        end
                    end)
                    log(tostring(SAO.Standing.factionName(sGroup))
                        .. " settles at " .. cand.cx .. "," .. cand.cy
                        .. " (" .. moved .. " households converge)")
                    agent.settleCandidate = nil
                    setState(agent, id, "IDLE", "the faction has a home")
                    return
                end
                -- Could not reach it: remember the rejection, try elsewhere.
                if cand then
                    local key = cand.minX .. "," .. cand.minY
                    agent.rejectedBases = (agent.rejectedBases
                        and (agent.rejectedBases .. ";") or "") .. key
                end
                agent.settleCandidate = nil
                setState(agent, id, "IDLE", "candidate unreachable: " .. s)
                return
            end
            if agent.state == "ROAM"
                and agent.pressure and agent.pressure.answer == "designation"
                and s:find("arrived", 1, true) then
                -- The scout's round teaches quiet feet ([A24]).
                local rec9 = agent.rec
                if rec9 and rec9.designation == "scout" then
                    pcall(function()
                        SAOJavaBridge:grantXP(body, "Lightfooted", 1.0)
                    end)
                end
            end
            if agent.state == "MEDICWARD" then
                local hurtKey = agent.aidTarget
                agent.aidTarget = nil
                if s:find("arrived", 1, true) and hurtKey then
                    local hurtBody = bodyForKey(hurtKey)
                    if hurtBody then
                        local hdx = hurtBody:getX() - body:getX()
                        local hdy = hurtBody:getY() - body:getY()
                        if hdx * hdx + hdy * hdy
                            <= ARRIVAL_REACH * ARRIVAL_REACH
                            and SAO.Needs.aidWound(id, body, hurtBody) then
                            SAO.Standing.adjustTrust(hurtKey, id, 0.15)
                            SAO.Standing.adjustTrust(id, hurtKey, 0.03)
                            pcall(function()
                                SAOJavaBridge:grantXP(body, "Doctor", 1.5)
                            end)
                            pcall(function()
                                SAO.Voice.onEvent(id, "aid", tickCount)
                            end)
                            log(id .. " hands a bandage to " .. tostring(hurtKey))
                        end
                    end
                end
                setState(agent, id, "IDLE", "aid errand ended: " .. s)
                return
            end
            if agent.state == "AMMOWARD" then
                if s:find("arrived", 1, true) and SAO.Needs.queueTakeAmmo(id, body) then
                    agent.taskDeadline = tickCount + 1800
                    agent.takePurpose = "ammo"
                    setState(agent, id, "TAKE", "at the container, taking ammunition")
                    return
                end
                SAO.Needs.clearAmmo(body)
                setState(agent, id, "IDLE", "ammo errand ended: " .. s)
                return
            end
            if agent.state == "GEARWARD" then
                if s:find("arrived", 1, true) and SAO.Needs.queueTakeGear(id, body) then
                    agent.taskDeadline = tickCount + 1800
                    agent.takePurpose = "gear"
                    setState(agent, id, "TAKE", "at the container, taking the weapon")
                    return
                end
                SAO.Needs.clearGear(body)
                setState(agent, id, "IDLE", "gear errand ended: " .. s)
                return
            end
            if agent.state == "HEARTHWARD" then
                if s:find("arrived", 1, true) then
                    local okLt, lit3 = pcall(function()
                        return SAOJavaBridge:lightNearbyHearth(body, 3)
                    end)
                    if okLt and lit3 then
                        pcall(function()
                            SAO.Voice.onEvent(id, "lightFire", tickCount)
                        end)
                        log(id .. " lights the fire")
                    end
                    local okFd, fed = pcall(function()
                        return SAOJavaBridge:feedNearbyHearth(body, 3)
                    end)
                    if okFd and type(fed) == "number" and fed > 0 then
                        pcall(function()
                            SAO.Voice.onEvent(id, "feedFire", tickCount)
                        end)
                        log(id .. " feeds the fire on arrival ("
                            .. fed .. " units)")
                    end
                    agent.taskDeadline = tickCount + 2400
                    setState(agent, id, "WARMING",
                        "warms at the fire, weapon in reach", "need")
                    return
                end
                setState(agent, id, "IDLE", "the fire could not be reached")
                return
            end
            if agent.state == "HOMEWARD" and agent.carryingWater then
                agent.carryingWater = nil
                if SAO.Needs.depositWater(id, body) then
                    agent.taskDeadline = tickCount + 900
                    agent.takePurpose = "deposit"
                    setState(agent, id, "TAKE",
                        "shelves the water they carried", "designation")
                    return
                end
            end
            if agent.state == "WATERWARD" then
                -- The water RUN fills vessels and carries them home
                -- ([B6]); thirst drinks. Same walk, different errand.
                if agent.waterRun then
                    agent.waterRun = nil
                    if s:find("arrived", 1, true) then
                        local okR6, got6 = pcall(function()
                            return SAOJavaBridge:fillWaterFromNearby(body, 3)
                        end)
                        if okR6 and type(got6) == "number" and got6 > 0 then
                            log(id .. " fills at the source - "
                                .. math.floor(got6) .. " units for the house")
                            -- The carry is marked so the walk home
                            -- ends in shelving, not in nothing.
                            agent.carryingWater = true
                            setState(agent, id, "HOMEWARD",
                                "carries the water home", "designation")
                            return
                        end
                    end
                    setState(agent, id, "IDLE",
                        "the water run found nothing to fill")
                    return
                end
                if s:find("arrived", 1, true) and SAO.Needs.queueDrinkFrom(id, body) then
                    agent.taskDeadline = tickCount + 1800
                    setState(agent, id, "DRINK", "at the source, drinking")
                    return
                end
                SAO.Needs.clearWater(body)
                agent.nextWaterAt = tickCount + 600
                setState(agent, id, "IDLE", "water errand ended: " .. s)
                return
            end
            if agent.state == "FORAGE" then
                -- Arrived (or gave up). Within reach: take through the
                -- vanilla transfer. Out of reach or failed: rescan later.
                if s:find("arrived", 1, true) and SAO.Needs.queueTake(id, body) then
                    agent.taskDeadline = tickCount + 1800
                    setState(agent, id, "TAKE", "at the container, taking food")
                    return
                end
                SAO.Needs.clearSource(body)
                agent.nextForageAt = tickCount + 600
                setState(agent, id, "IDLE", "forage attempt ended: " .. s)
                return
            end
            setState(agent, id, "IDLE", s)
        end
        if agent.state == "TRAVEL" then return end  -- operator orders are not re-decided
    end

    -- The widow notices ([A15]): membership that dissolved under them
    -- (the company's last other member died) is felt once, aloud.
    local nowGroup = SAO.Standing.groupOf(id)
    if agent.hadGroup and not nowGroup then
        pcall(function() SAO.Voice.onEvent(id, "aloneAgain", tickCount) end)
        log(id .. " is the last of their company - released, keeps the house")
    end
    agent.hadGroup = nowGroup and true or nil

    -- Armed status for the stand-ground choice (null-check only; the item
    -- object itself never gets indexed from Lua).
    local okW, weapon = pcall(function() return body:getPrimaryHandItem() end)
    agent.armed = okW and weapon ~= nil

    -- Hurt attribution: a health drop names its author. A person who hurt
    -- this survivor becomes hostile standing, both ways, and trust collapses.
    local okHp, hp = pcall(function() return SAOJavaBridge:getShellHealth(body) end)
    if okHp and type(hp) == "number" and hp >= 0 then
        if agent.lastHealth and hp < agent.lastHealth - 0.4 then
            local okA, tag = pcall(function() return SAOJavaBridge:getLastAttackerTag(body) end)
            tag = okA and tostring(tag) or ""
            local kind, name = string.match(tag, "^(%w+):(.+)$")
            if kind == "player" or kind == "shell" then
                local attackerKey = SAO.Standing.keyForAttackerTag(kind, name)
                -- Betrayal by your BONDED severs the bond before anything
                -- else ([A15]): the fact ends, the trauma claim mints (the
                -- same fork as death - who you already were decides), and
                -- hostility lands on what used to be your person.
                if SAO.Standing.isBondedTo(id, attackerKey) then
                    SAO.Standing.severBond(id, attackerKey)
                    local tr = SAO.Disposition.traits(id)
                    local claim = (tr.aggression >= tr.nerve)
                        and "nothing-left-to-lose"
                        or "never-again-that-close"
                    SAO.Lessons.learn(id, claim, 1.0, "lived", name)
                    pcall(function()
                        SAO.Voice.onEvent(id,
                            claim == "nothing-left-to-lose"
                                and "traumaRage" or "traumaBreak", tickCount)
                    end)
                    log(id .. "'s bond with " .. name
                        .. " is severed by betrayal - '" .. claim .. "'")
                end
                -- Ordinary betrayal by someone TRUSTED (not bonded -
                -- that severs above) mints its own lived claim ([A15]).
                if not SAO.Standing.isBondedTo(id, attackerKey)
                    and SAO.Standing.trust(id, attackerKey) > 0.5 then
                    SAO.Lessons.learn(id, "trust-carefully", 1.0, "lived", name)
                end
                SAO.Standing.setHostile(id, attackerKey, true)
                SAO.Standing.adjustTrust(id, attackerKey, -1.0)
                log(id .. " was hurt by " .. name .. " - hostility declared")
                -- Faction wariness ([A15]): if this survivor can PLACE
                -- the attacker in a faction (seen inside its base - an
                -- inference, never a roster), their stance toward that
                -- whole faction turns wary.
                local pb2 = SAO.Perception.beliefs[id]
                local attackerBelief = pb2 and pb2.people[name] or nil
                if attackerBelief and attackerBelief.seenInFaction then
                    SAO.Perception.setFactionStance(id,
                        attackerBelief.seenInFaction, "wary")
                    log(id .. " is wary of "
                        .. tostring(attackerBelief.seenInFaction)
                        .. " now - one of theirs did this")
                end

                -- Witnessed violence: anyone who was WATCHING the victim
                -- when it happened judges firsthand. Seeing outweighs
                -- testimony ([A8]) and sits below suffering: trust in the
                -- attacker drops hard; a witness who counted the victim a
                -- friend turns hostile on the spot. The victim's engine
                -- truth names the attacker; the witness's own fresh
                -- OBSERVED belief of the victim is what makes them a
                -- witness rather than a rumor-hearer.
                local victimName = agent.rec
                    and SAO.Identity.displayName(agent.rec) or nil
                if victimName == "Unnamed" then victimName = nil end
                for witnessId in pairs(Ctl.agents) do
                    if witnessId ~= id and witnessId ~= attackerKey then
                        local beliefs = SAO.Perception.beliefs[witnessId]
                        local seen = beliefs and victimName
                            and beliefs.people[victimName] or nil
                        if seen and seen.source == "observed"
                            and (tickCount - seen.at) <= WITNESS_FRESH
                            and seen.dist <= WITNESS_REACH
                            and not SAO.Standing.sameGroup(witnessId, attackerKey) then
                            local after = SAO.Standing.adjustTrust(witnessId, attackerKey, -0.6)
                            local lovedVictim = SAO.Standing.trust(witnessId, id) > 0.5
                                or SAO.Standing.isBondedTo(witnessId, id)
                            if lovedVictim or after
                                < SAO.Disposition.hostilityBar(witnessId) then
                                SAO.Standing.setHostile(witnessId, attackerKey, true)
                            end
                            log(witnessId .. " saw " .. name .. " hurt "
                                .. tostring(victimName)
                                .. (lovedVictim and " - a friend; hostility declared"
                                    or " - trust now " .. string.format("%.2f", after)))
                            pcall(function()
                                SAO.Voice.onEvent(witnessId, "witnessed", tickCount)
                            end)
                        end
                    end
                end
            end
        end
        agent.lastHealth = hp
    end

    if tickCount >= (agent.nextDecisionAt or 0) then
        agent.nextDecisionAt = tickCount + SAO.Disposition.decisionInterval(id)
        decide(id, agent, body)

        -- Territory objection: an owner AT HOME who sees a person inside
        -- their claim objects - voice first, a slow trust bleed after.
        -- Hostility is never declared here; it forms only if trust collapses
        -- through repetition. The desperate stranger stealing bread pays in
        -- standing, not blood, unless they keep coming back.
        do
            local bx, by = body:getX(), body:getY()
            if SAO.Standing.insideClaim(id, bx, by) then
                local beliefs = SAO.Perception.beliefs[id]
                if beliefs then
                    for name, belief in pairs(beliefs.people) do
                        if (tickCount - belief.at) <= 120
                            and SAO.Standing.insideClaim(id, belief.x, belief.y) then
                            local key = SAO.Standing.keyForObserved(name)
                            if not SAO.Standing.sameGroup(id, key)
                                and not SAO.Standing.isHostileTo(id, key)
                                and SAO.Standing.trust(id, key) <= 0.5 then
                                -- friends are welcome; strangers are not
                                local trespasserId = SAO.Identity.idByName(name)
                                local trespasser = trespasserId and Ctl.agents[trespasserId]
                                -- [B28] WHO THIS IS is a key and it
                                -- answers for all three domains.
                                -- WHOSE FEET WE DRIVE is an agent and
                                -- only ours ever are. [A15] resolved
                                -- both through idByName, which answers
                                -- only for our survivors, so the
                                -- player fell through every
                                -- belief-shaped test below.
                                local mindKey = trespasserId or
                                    (SAO.Perception.beliefs[key] and key or nil)
                                -- Walls muffle: the demand lands only with
                                -- line of sight, or truly close (<=4 tiles,
                                -- shouting through the door).
                                -- [B28] Hearing is distance and walls,
                                -- never whose agent you are. Gated on
                                -- `trespasser`, the player could stand
                                -- four tiles away and never be told.
                                local heard = false
                                if mindKey and belief.dist <= 8.0 then
                                    if belief.dist <= 4.0 then
                                        heard = true
                                    else
                                        local tb = bodyForKey(mindKey)
                                        local okL, line = pcall(function()
                                            return SAOJavaBridge:hasLineTo(body, tb)
                                        end)
                                        heard = okL and line == true
                                    end
                                end
                                -- First offense is innocence ([A15]): if
                                -- the trespasser held no belief that this
                                -- place is claimed, the objection TEACHES
                                -- it and costs nothing. The offense is
                                -- returning against a held belief. The
                                -- player cannot hold beliefs and keeps the
                                -- standing cost - they were told.
                                -- The cost follows the BELIEF, not the
                                -- earshot: only a trespasser who already
                                -- knew this place is claimed pays. Hearing
                                -- governs TEACHING and leaving, not blame.
                                -- [B28] [A15] said "the player cannot
                                -- hold beliefs", true when written.
                                -- [B27] gave them a store, so reading
                                -- this through `trespasserId` made the
                                -- player the one person in Knox who
                                -- could never be pardoned for not
                                -- having known.
                                local heldBelief = false
                                if mindKey then
                                    local tb2 = SAO.Perception.beliefs[mindKey]
                                    heldBelief = (tb2 and tb2.places
                                        and tb2.places[id]) and true or false
                                end
                                -- The objection TEACHES, and it can
                                -- teach the player now. That is the
                                -- whole of [A15]'s rule: the offense is
                                -- RETURNING against a held belief, so
                                -- there has to be a way to come to hold
                                -- one.
                                if heard and mindKey then
                                    local myClaim = SAO.Standing.claimOf(id)
                                    if myClaim then
                                        -- [B39] Heard gates this
                                        -- branch, so heard is what it
                                        -- was. It recorded "observed".
                                        SAO.Perception.learnPlace(
                                            mindKey, id, myClaim, "heard")
                                    end
                                end
                                -- [B28] A mind we cannot see is not a
                                -- mind that knew. Another mod's person
                                -- keeps no store of ours, so they are
                                -- pardoned rather than blamed on a
                                -- guess - the restraint [A15] already
                                -- showed our own.
                                local firstOffense = mindKey ~= nil
                                    and not heldBelief
                                if not firstOffense then
                                    SAO.Standing.adjustTrust(id, key,
                                        -0.05 * SAO.Lessons.objectionEdge(id))
                                else
                                    log(id .. " lets the first offense go - "
                                        .. name .. " did not know")
                                end
                                pcall(function()
                                    SAO.Voice.onEvent(id,
                                        firstOffense and "pardon" or "trespass",
                                        tickCount)
                                end)
                                log(id .. " objects to " .. name .. " inside their claim")
                                if heard and not trespasser.passive then
                                    -- F-026: a PASSIVE inhabitant hears the
                                    -- objection and pays the standing cost
                                    -- like anyone, but their body is never
                                    -- ours to drive - no queue clears, no
                                    -- state; their KS life decides their
                                    -- feet.
                                    local tBody = SAO.Body.get(trespasserId)
                                    local tState = trespasser.state
                                    if tBody and (tState == "FORAGE" or tState == "WATERWARD"
                                        or tState == "GEARWARD" or tState == "AMMOWARD"
                                        or tState == "TAKE") then
                                        local tNeeds = SAO.Needs.read(tBody)
                                        local desperationAt = policy().desperation
                                        local desperate = tNeeds
                                            and (tNeeds.hunger >= desperationAt
                                                or tNeeds.thirst >= desperationAt)
                                        if not desperate then
                                            pcall(function() ISTimedActionQueue.clear(tBody) end)
                                            SAO.Needs.clearSource(tBody)
                                            SAO.Needs.clearWater(tBody)
                                            SAO.Needs.clearGear(tBody)
                                            SAO.Needs.clearAmmo(tBody)
                                            trespasser.nextForageAt = tickCount + 1200
                                            trespasser.nextWaterAt = tickCount + 1200
                                            trespasser.nextGearAt = tickCount + 1200
                                            trespasser.nextAmmoAt = tickCount + 1200
                                            trespasser.nextDecisionAt = 0
                                            setState(trespasser, trespasserId, "ALERT",
                                                "told to leave " .. id .. "'s place - leaving")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Heard gunfire, attributed: a fresh HEARD threat belief whose
        -- origin sits within 2 tiles of an OBSERVED person means they
        -- fired. Gunfire makes strangers warier company - a small trust
        -- bleed toward low-trust shooters (friends firing reads as
        -- defense, and costs nothing).
        do
            local beliefsG = SAO.Perception.beliefs[id]
            if beliefsG and tickCount >= (agent.nextShotJudgeAt or 0) then
                for zkey, zb in pairs(beliefsG.zombies) do
                    if zb.source == "heard" and (tickCount - zb.at) <= 60 then
                        for pname, pb in pairs(beliefsG.people) do
                            if pb.source == "observed"
                                and (tickCount - pb.at) <= 60 then
                                local gdx, gdy = pb.x - zb.x, pb.y - zb.y
                                if gdx * gdx + gdy * gdy <= 4.0 then
                                    local pkey = SAO.Standing.keyForObserved(pname)
                                    if SAO.Standing.trust(id, pkey) < 0.3
                                        and not SAO.Standing.isHostileTo(id, pkey) then
                                        SAO.Standing.adjustTrust(id, pkey, -0.05)
                                        agent.nextShotJudgeAt = tickCount + 600
                                        log(id .. " heard " .. pname
                                            .. " shooting - wary of armed strangers")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Encounters build trust slowly: a person seen close, recently, who
        -- is not hostile, becomes slightly more trusted. Betrayal above
        -- outweighs a hundred pleasant sightings by design.
        local beliefs = SAO.Perception.beliefs[id]
        if beliefs then
            for name, belief in pairs(beliefs.people) do
                local key = SAO.Standing.keyForObserved(name)
                if (tickCount - belief.at) <= 60
                    and belief.dist <= TALK_REACH
                    and not SAO.Standing.isHostileTo(id, key) then
                    -- The tidy warm to the visibly unkempt at half speed
                    -- ([A14]) - judgment, never hostility.
                    local warmth = 0.002
                    if SAO.Disposition.judgesAppearance(id)
                        and belief.condition
                        and string.find(belief.condition, "+u", 1, true) then
                        warmth = 0.001
                    end
                    -- Cold toward the colors of a wary faction ([A15]):
                    -- accrual freezes; nothing turns hostile by badge.
                    local stance = SAO.Perception.factionStanceToward(id, name)
                    if stance == "wary" then
                        warmth = 0
                    end
                    local before = SAO.Standing.trust(id, key)
                    local after = SAO.Standing.adjustTrust(id, key, warmth)
                    -- The first time trust clears the acquaintance line,
                    -- the relation gets a face: one greeting, ever.
                    if after >= 0.3 and before < 0.3
                        and not SAO.Standing.wasGreeted(id, key) then
                        SAO.Standing.markGreeted(id, key)
                        -- [B35] Two lines were written for this
                        -- moment and nothing ever said them:
                        -- `introduce` appeared exactly once in the
                        -- whole tree, in its own definition, so "We
                        -- hold the place up the road. Ask before you
                        -- wander in." could never be heard by anyone.
                        --
                        -- Not a second line after the greeting: the
                        -- speak cooldown is 600 ticks, so a follow-up
                        -- would be swallowed and the lines would stay
                        -- dead. Someone who holds ground introduces
                        -- themselves BY greeting - the greeting is
                        -- where you say who you are - and being told
                        -- is how a place becomes known ([A15]).
                        local myGround = SAO.Standing.claimOf(id)
                        if not myGround then
                            local g11 = SAO.Standing.groupOf(id)
                            myGround = g11 and SAO.Standing.groupClaimOf
                                and SAO.Standing.groupClaimOf(g11) or nil
                        end
                        local theirB = SAO.Perception.beliefs[key]
                        local knowsMyGround = theirB and theirB.places
                            and theirB.places[id] ~= nil
                        if myGround and not knowsMyGround then
                            pcall(function()
                                SAO.Voice.onEvent(id, "introduce", tickCount)
                            end)
                            -- Told, not seen: they know it because
                            -- somebody standing there said so.
                            if theirB then
                                pcall(function()
                                    -- [B39] The comment above has
                                    -- always said told. Now the record
                                    -- says it too.
                                    SAO.Perception.learnPlace(key, id,
                                        myGround, "told")
                                end)
                            end
                        else
                            pcall(function()
                                SAO.Voice.onEvent(id, "greet", tickCount)
                            end)
                        end
                        log(id .. " greets " .. name .. " (an acquaintance now)")
                    end
                end
            end
        end

        -- Word of mouth within talking distance; Perception.tell gates on
        -- trust or membership, so strangers stay strangers until they aren't.
        for otherId in pairs(Ctl.agents) do
            if otherId ~= id then
                local otherBody = SAO.Body.get(otherId)
                if otherBody then
                    local dx = otherBody:getX() - body:getX()
                    local dy = otherBody:getY() - body:getY()
                    if dx * dx + dy * dy <= TALK_REACH * TALK_REACH then
                        SAO.Exchange.betweenPair(id, agent, body, otherId, otherBody, tickCount)
                    end
                end
            end
        end
    end
end

-- Hearing of a death ([A19]): the handler tell() fires when a death
-- lands on someone's beliefs for the first time. A receiver bonded to
-- the named dead grieves at TOLD weight - the trauma fork by who they
-- already were, at 0.4; word of mouth wounds, but not like watching.
SAO.Perception.deathNewsHandler = function(toId, name, tick)
    local key = SAO.Standing.keyForObserved(name)
    if not SAO.Standing.isBondedTo(toId, key) then return end
    local tr = SAO.Disposition.traits(toId)
    local claim = (tr.aggression >= tr.nerve)
        and "nothing-left-to-lose" or "never-again-that-close"
    if SAO.Lessons.learn(toId, claim, 0.4, "told", name) then
        pcall(function()
            SAO.Voice.onEvent(toId,
                claim == "nothing-left-to-lose" and "traumaRage"
                    or "traumaBreak", tick)
        end)
        log(toId .. " hears that " .. name .. " is dead - '"
            .. claim .. "' (told)")
    end
end

-- Fault gates ([A21] bulkheads): each AGENT ticks behind its own
-- pcall - a broken agent accrues its own faults and is dropped ALONE
-- at 3; the county keeps moving. The outer gate stays as the last
-- line against harness-level failure.
local ctlFaults = 0
local agentFaults = {}

-- [B51] The controller's own per-id teardown for anything that is
-- not the agent record. `Ctl.agents` and the body handles are cleared
-- inline at the two death branches, where the order matters; this is
-- for the caches that just need to stop existing.
function Ctl.forget(id)
    agentFaults[tostring(id)] = nil
end
-- [B27] The tick, readable from outside. The player's half of the
-- experience loop is driven by a menu click rather than by this
-- loop, and a belief still has to be stamped with when it crossed.
function Ctl.tick()
    return tickCount
end

local function onTickInner()
    tickCount = tickCount + 1
    -- [B47] The tallies go out on a cadence, so a county that is
    -- quietly meeting people all day says so once every ten seconds
    -- of frames (600 of them; ~10s at 60fps)
    -- instead of once per meeting.
    if tickCount % SAO.Log.EVERY == 0 then SAO.Log.flush() end
    -- [B27] The player perceives through the SAME function every
    -- survivor does. Not a parallel player pathway - `P.observe` was
    -- already generic over the id, `store` is a plain table, and a
    -- survivor IS an IsoPlayer, so the player has an id and a body
    -- like anyone else. This is what gives them something to tell:
    -- you cannot pass on what you never took in. It self-throttles on
    -- SCAN_INTERVAL exactly as the survivors' does, and never runs
    -- asleep, because you are not asleep while you are playing.
    pcall(function()
        local me = getSpecificPlayer(0)
        if not me or me:isDead() then return end
        local myKey = SAO.Standing.playerKey(me)
        if myKey then
            SAO.Perception.observe(myKey, me, tickCount, false)
        end
    end)
    for id, agent in pairs(Ctl.agents) do
        local ok, err = pcall(updateAgent, id, agent)
        if not ok then
            agentFaults[id] = (agentFaults[id] or 0) + 1
            log(id .. " agent fault " .. agentFaults[id] .. "/3: "
                .. tostring(err))
            if agentFaults[id] >= 3 then
                log(id .. " dropped alone after repeated faults"
                    .. " - the county keeps moving")
                Ctl.drop(id)
                agentFaults[id] = nil
            end
        end
    end
end

local function onTick()
    local ok, err = pcall(onTickInner)
    if ok then return end
    ctlFaults = ctlFaults + 1
    if ctlFaults == 1 then
        log("tick fault: " .. tostring(err))
    end
    if ctlFaults >= 3 then
        log("disabling all agents after " .. ctlFaults .. " tick faults")
        for id in pairs(Ctl.agents) do Ctl.drop(id) end
        ctlFaults = 0
    end
end

-- The county mourns the player ([A22]): you were a person here.
-- Survivors who trusted you grieve when you die; active companions and
-- those past the company line carry the trauma fork at lived weight -
-- losing you changes who they are. The near walk to where you fell.
-- No record is conjured; a respawn under the same name resumes the old
-- standing web - the county does not know about resurrection.
local function onPlayerDeath(playerObj)
    -- [B35] [B27] converted fifteen sites and this one rebuilt the
    -- key by hand anyway. Same spelling today; one constructor is how
    -- it stays that way tomorrow.
    local myKey = SAO.Standing.playerKey(playerObj)
    if not myKey then return end
    -- [B45] This was read three lines down and never declared, so the
    -- county mourned a person called "nil": the lesson's subject, the
    -- name in the log, and the belief the walk looks up were all the
    -- string. The one death [A22] exists for was the one death nobody
    -- could name. The scanner labels people by getUsername(), so this
    -- is the spelling `beliefs.people` is keyed by.
    local okU, uname = pcall(function() return playerObj:getUsername() end)
    uname = (okU and uname) and tostring(uname) or nil
    local okP, px, py = pcall(function()
        return playerObj:getX(), playerObj:getY()
    end)
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
    -- [B10] The county lets go of what only the living can hold -
    -- the chair (with its proper unseating), the membership, the
    -- debts owed to them, the voice on the band. Grief and the walk
    -- to where you fell are below, and those it keeps.
    pcall(function() SAO.Standing.releasePlayer(myKey) end)
    for id, agent in pairs(Ctl.agents) do
        if not agent.passive then
            local trustIn = SAO.Standing.trust(id, myKey)
            if trustIn > 0.3 or agent.companioning then
                if agent.companioning or trustIn > companyAt then
                    local tr = SAO.Disposition.traits(id)
                    local claim = (tr.aggression >= tr.nerve)
                        and "nothing-left-to-lose"
                        or "never-again-that-close"
                    if SAO.Lessons.learn(id, claim, 1.0, "lived",
                        uname) then
                        pcall(function()
                            SAO.Voice.onEvent(id,
                                claim == "nothing-left-to-lose"
                                    and "traumaRage" or "traumaBreak",
                                tickCount)
                        end)
                        log(id .. " is not who they were - they lost you")
                    end
                    agent.companioning = nil
                else
                    pcall(function()
                        SAO.Voice.onEvent(id, "grief", tickCount)
                    end)
                    log(id .. " mourns the player")
                end
                local body = SAO.Body.get(id)
                if okP and body
                    and (agent.state == "IDLE" or agent.state == "ROAM") then
                    local ddx = px - body:getX()
                    local ddy = py - body:getY()
                    if ddx * ddx + ddy * ddy <= 900.0
                        and SAO.Locomotion.order(id, body,
                            math.floor(px), math.floor(py),
                            math.floor(body:getZ())) then
                        agent.mournName = uname
                        agent.taskDeadline = tickCount + 1800
                        setState(agent, id, "MOURNWARD",
                            "goes to where you fell")
                    end
                end
            end
        end
    end
end

Events.OnPlayerDeath.Remove(onPlayerDeath)
Events.OnPlayerDeath.Add(onPlayerDeath)

Events.OnTick.Remove(onTick)
Events.OnTick.Add(onTick)

function Ctl.describe(id)
    local agent = Ctl.agents[tostring(id)]
    if not agent then return "no-agent" end
    return "state=" .. agent.state
        .. " | " .. SAO.Perception.describe(tostring(id), tickCount)
        .. " | " .. SAO.Standing.describe(tostring(id))
end

return Ctl
