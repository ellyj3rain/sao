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
--                 beliefs are never retold - no chains of whispers)
--   people[name]  { x, y, dist, at, source, condition ("ok|hurt|bad"
--                 with "+u" when visibly unkempt), seenInFaction? -
--                 durable across re-scans: a fresh look updates position,
--                 it does not cause amnesia }
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
P.beliefs = P.beliefs or {}

-- [B49] FRAMES, not seconds - a tick is one rendered frame, so this
-- is ~10s at 60fps and half that on a 120Hz machine. A belief's
-- shelf life following the graphics card is a real oddity and is
-- left as it is: the whole perception loop is paced in frames, and
-- moving one horizon to the wall clock would put it out of step with
-- the scan that feeds it.
local ZOMBIE_HORIZON = 600     -- frames a zombie belief stays actionable
local PEOPLE_HORIZON = 1800
local SCAN_INTERVAL  = 20      -- acquisition cadence per survivor
-- [B20] How long a recognised cry keeps its tile from being read
-- as a threat. ONE definition: the guard in the S-row path and
-- the prune in the decay pass both read this, or they drift and
-- the table leaks.
local CRY_RECOGNITION = 600
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
                    b.zombies[x .. "," .. y] = { x = x, y = y, dist = d, at = tick, source = "observed" }
                    -- The turned are recognizable ([B3]): a named
                    -- zombie whose name belongs to one of the DEAD is
                    -- the county's darkest moment, once per witness.
                    local zname = f[5]
                    if zname and zname ~= "" then
                        local zid = SAO.Identity and SAO.Identity.idByName
                            and SAO.Identity.idByName(zname) or nil
                        local zrec = zid and SAO.Identity.get(zid) or nil
                        if zrec and zrec.dead then
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
                        return GameTime.getInstance():getWorldAgeHours()
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
                    b.people[name] = { x = x, y = y, dist = d, at = tick,
                        atHours = okRH and rh or nil,
                        source = "observed", condition = f[6] or "ok",
                        seenInFaction = prev and prev.seenInFaction or nil }
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
    for key, belief in pairs(b.zombies) do
        if tick - belief.at > ZOMBIE_HORIZON * 2 then b.zombies[key] = nil end
    end
    for name, belief in pairs(b.people) do
        -- F-033: memory of the dead is durable - a dead-flagged belief
        -- never decays, or the news would die with the clock and the
        -- county could not keep retelling its losses.
        if not belief.dead
            and tick - belief.at > PEOPLE_HORIZON * 2 then
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
    for _, belief in pairs(b.zombies) do
        if tick - belief.at <= ZOMBIE_HORIZON then
            local d = distanceFor(belief, fromX, fromY)
            if not best or d < bestDist then best, bestDist = belief, d end
        end
    end
    if best then
        return { x = best.x, y = best.y, dist = bestDist, at = best.at,
                 source = best.source, teller = best.teller }
    end
    return nil
end

function P.believedThreatCount(id, tick, radius, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return 0 end
    local n = 0
    for _, belief in pairs(b.zombies) do
        if tick - belief.at <= ZOMBIE_HORIZON
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

function P.believedPerson(id, name)
    local b = P.beliefs[id]
    return b and b.people[name] or nil
end

function P.describe(id, tick)
    local b = P.beliefs[id]
    if not b then return "no-beliefs" end
    local zn, pn = 0, 0
    for _, belief in pairs(b.zombies) do
        if tick - belief.at <= ZOMBIE_HORIZON then zn = zn + 1 end
    end
    for _, belief in pairs(b.people) do
        if tick - belief.at <= PEOPLE_HORIZON then pn = pn + 1 end
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
-- 60fps - and
-- forgets it entirely at twice that. A gate that ignores the horizon
-- opens on a memory the transfer will refuse, so the option appears,
-- you speak, and nothing crosses. Opening on exactly what can cross is
-- the rule; this reads `tell`'s own test rather than approximating it.
function P.hasAnythingToPass(id, tick)
    local b = P.beliefs[id]
    if not b then return false end
    for _ in pairs(b.factions or {}) do return true end
    for _ in pairs(b.places or {}) do return true end
    for _, zb in pairs(b.zombies or {}) do
        if zb.source ~= "told"
            and tick and (tick - zb.at) <= ZOMBIE_HORIZON then
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
function P.tell(fromId, toId, tick, chosen)
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
    local shared = 0
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
                elseif not existing.name and tname then
                    existing.name = tname
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
        elseif existing and not existing.name and fb.name then
            existing.name = fb.name
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
        end
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
function P.reportReturn(fromId, toId, tick, aroundX, aroundY)
    if not (aroundX and aroundY) then return 0 end
    local from = P.beliefs[fromId]
    local to = P.beliefs[toId]
    if not (from and to) then return 0 end
    if not P.willBelieve(toId, fromId) then return 0 end
    local moved = 0
    for key, zb in pairs(from.zombies or {}) do
        if zb.source ~= "told" then
            local dx, dy = zb.x - aroundX, zb.y - aroundY
            if dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH then
                local existing = to.zombies[key]
                if not existing or existing.source == "told" then
                    to.zombies[key] = { x = zb.x, y = zb.y,
                        dist = zb.dist, at = zb.at,
                        source = "told", teller = fromId }
                    moved = moved + 1
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
                source = "told", name = fb.name,
                stance = fb.stance }
            moved = moved + 1
        end
    end
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
    local fromName = fromRec and SAO.Identity.displayName(fromRec) or nil
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
    local fromName = fromRec and SAO.Identity.displayName(fromRec) or nil
    if not fromName then return end
    local fromBody = SAO.Body and SAO.Body.get and SAO.Body.get(fromId)
    if not fromBody then return end
    local fx, fy = fromBody:getX(), fromBody:getY()
    local g = SAO.Standing.groupOf and SAO.Standing.groupOf(fromId) or nil
    if not g then return end
    local okH, nowH = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
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
                and ZombRand(4) == 0 then
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
                return GameTime.getInstance():getWorldAgeHours()
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
                if P.deathNewsHandler then
                    pcall(P.deathNewsHandler, toId, name, tick)
                end
            end
        end
    end
    for key, belief in pairs(from.zombies) do
        if tick - belief.at <= ZOMBIE_HORIZON and belief.source ~= "told" then
            local existing = to.zombies[key]
            if not existing or existing.source == "told" then
                -- dist here is the TELLER's; every consumer recomputes
                -- from their own position (F-014), so it is only a seed.
                to.zombies[key] = {
                    x = belief.x, y = belief.y, dist = belief.dist,
                    at = belief.at, source = "told", teller = fromId,
                }
                shared = shared + 1
            end
        end
    end
    return shared
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
-- whoever is standing in it. `offers` is what its rooms read as
-- (SAO_Places), and `at` gives the belief an age like every other
-- belief here - a place remembered is not a place seen.
function P.learnBuilding(id, place, tick, source)
    if not place or not place.id then return end
    local b = store(id)
    b.known = b.known or {}
    local was = b.known[place.id]
    b.known[place.id] = {
        cx = place.cx, cy = place.cy,
        minX = place.minX, minY = place.minY,
        maxX = place.maxX, maxY = place.maxY,
        offers = place.offers,
        at = tick or b.lastScanAt,
        -- [B39] Said by the caller; "unknown" when nobody said.
        source = tostring(source or "unknown"),
        -- How many times they have been. Somewhere returned to is
        -- somewhere that gave them something.
        visits = (was and was.visits or 0) + 1,
    }
end

-- Everything this survivor knows is out there. Empty for someone who
-- has not been anywhere, which is the correct answer for them.
function P.knownPlaces(id)
    local b = P.beliefs[id]
    return (b and b.known) or {}
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
end

return P
