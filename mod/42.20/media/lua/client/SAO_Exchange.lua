-- SAO_Exchange - the per-pair conversation ([A15] extraction).
-- ---------------------------------------------------------------------------
-- Everything two survivors within talking distance do to each other in one
-- decision pass: warnings, bread, charity, settlement, the bond, smokes,
-- barter, leadership, lessons, grudges, company and moving in. Extracted
-- VERBATIM from the controller's exchange loop as a pure refactor - the
-- blocks' order and cooldown semantics are documented in [A15]'s trace and
-- unchanged here. `agent` is the INITIATOR's agent table (cooldown fields
-- live on it); state transitions never happen inside an exchange.

SAO = SAO or {}
SAO.Exchange = SAO.Exchange or {}
local Exchange = SAO.Exchange

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("XCHG", msg) end

-- The same sandbox reader the controller uses (world policy, one place
-- per file by design - the schema is the shared truth).
local function policy()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return {
        desperation = (sv and tonumber(sv.Desperation)) or 0.7,
        trustToCompany = (sv and tonumber(sv.TrustToCompany)) or 0.5,
        errandRadius = (sv and tonumber(sv.ErrandRadius)) or 12,
    }
end

local Ctl = nil   -- resolved lazily; SAO.Controller loads after shared files

-- The economy takes sides ([A21]): during a feud, a member who can
-- PLACE the other in the enemy company (their own seenInFaction belief
-- - never a roster peek) gives them nothing. Spoken once per pair;
-- refusal is a fact between people, not a hidden filter.
local function refusesColors(id, agent, otherId, tickCount)
    local myG = SAO.Standing.groupOf(id)
    if not myG then return false end
    local orec = SAO.Identity.get(otherId)
    local oname = SAO.Identity.displayName(orec)
    if not oname then return false end
    local b = SAO.Perception.beliefs[id]
    local pb = b and b.people[oname] or nil
    local theirG = pb and pb.seenInFaction or nil
    if not theirG or theirG == myG then return false end
    if not SAO.Standing.feudBetween(myG, theirG) then return false end
    agent.colorRefusalSaid = agent.colorRefusalSaid or {}
    if not agent.colorRefusalSaid[otherId] then
        agent.colorRefusalSaid[otherId] = true
        pcall(function() SAO.Voice.onEvent(id, "colors", tickCount) end)
        log(id .. " gives " .. otherId .. " nothing - not with their colors")
    end
    return true
end

-- The state colors the meeting ([B9]): drink loosens (every feeling
-- moves further, both ways), pain and panic shorten the fuse (the
-- warm channels narrow, the sharp ones bite), low morale withdraws.
-- Bounded: at most half again as sharp, at most half as warm - the
-- state is weather, never the person. Both people's states count;
-- a meeting is what the two of them are, together.
local function meetingTemper(body, otherBody)
    local a = SAO.Needs.temper and SAO.Needs.temper(body) or nil
    local b = SAO.Needs.temper and SAO.Needs.temper(otherBody) or nil
    if not a and not b then return 1.0, 1.0 end
    local function pull(v) return v or {
        drunk = 0, pain = 0, stress = 0, anger = 0, morale = 0.5 } end
    a, b = pull(a), pull(b)
    local drunk = (a.drunk + b.drunk) * 0.5
    local sore = (a.pain + b.pain + a.stress + b.stress
        + a.anger + b.anger) / 6.0
    local low = 1.0 - math.min(1.0, (a.morale + b.morale) * 0.5)
    -- Warm channels: drink opens them, soreness and flat morale
    -- close them. Sharp channels: drink and soreness both open them.
    local warm = 1.0 + drunk * 0.5 - sore * 0.5 - low * 0.25
    local sharp = 1.0 + drunk * 0.5 + sore * 0.5
    warm = math.max(0.5, math.min(1.5, warm))
    sharp = math.max(0.5, math.min(1.5, sharp))
    return warm, sharp
end

function Exchange.betweenPair(id, agent, body, otherId, otherBody, tickCount)
    Ctl = Ctl or SAO.Controller
        local n = SAO.Perception.tell(id, otherId, tickCount)
        if n > 0 then
            log(id .. " told " .. otherId .. " about " .. n .. " threat(s)")
            pcall(function() SAO.Voice.onEvent(id, "warned", tickCount) end)
        end
        -- Bread among company: a same-group fellow who is
        -- visibly hungry (their own eat line, plus a bit)
        -- gets the spare piece. Company speaks openly; need
        -- travels only inside this conversation. Trust rises
        -- on both sides of the handover.
        -- The house answers the bite ([B3]): meeting a housemate you
        -- BELIEVE bitten, the creed decides the shape of the moment.
        -- Mercy nurses - the bandage changes hands and someone stays
        -- close. Wall and order put DISTANCE - a small trust drip,
        -- once a day per pair: the debate is trust moving, and where
        -- it goes from there is the elections' and schisms' business,
        -- not a script's. No exile verb exists by design.
        if SAO.Standing.sameGroup(id, otherId) then
            local orec3 = SAO.Identity.get(otherId)
            local oname3 = orec3 and SAO.Identity.displayName(orec3)
            local b3 = SAO.Perception.beliefs[id]
            local opb3 = b3 and oname3 and b3.people[oname3] or nil
            if opb3 and opb3.condition == "bitten" then
                agent.bittenSaidAt = agent.bittenSaidAt or {}
                local okBH, bh3 = pcall(function()
                    return GameTime.getInstance():getWorldAgeHours()
                end)
                local nowB3 = okBH and bh3 or 0
                if nowB3 - (agent.bittenSaidAt[otherId] or -99) >= 24 then
                    agent.bittenSaidAt[otherId] = nowB3
                    local g3 = SAO.Standing.groupOf(id)
                    local creed3 = g3 and SAO.Standing.creedOf(g3) or nil
                    local cname3 = creed3 and creed3.name or nil
                    if cname3 == "mercy" then
                        pcall(function()
                            SAO.Needs.aidWound(id, body, otherBody)
                        end)
                        SAO.Standing.adjustTrust(otherId, id, 0.05)
                        pcall(function()
                            SAO.Voice.onEvent(id, "nurse", tickCount)
                        end)
                        log(id .. " tends " .. otherId
                            .. " - mercy does not leave the bitten")
                    elseif cname3 == "wall" or cname3 == "order" then
                        SAO.Standing.adjustTrust(id, otherId, -0.02)
                        pcall(function()
                            SAO.Voice.onEvent(id, "bittenWary", tickCount)
                        end)
                        log(id .. " keeps distance from " .. otherId
                            .. " - the house is afraid")
                    end
                    -- The bitten answer the moment ([B3]), by nerve:
                    -- the fearful deny, the composed ask for the
                    -- promise. The middle hold their tongue.
                    if cname3 == "mercy" or cname3 == "wall"
                        or cname3 == "order" then
                        local bn3 = SAO.Disposition.traits(otherId).nerve
                        pcall(function()
                            if bn3 < 0.45 then
                                SAO.Voice.onEvent(otherId,
                                    "scratchDenial", tickCount)
                            elseif bn3 >= 0.55 then
                                SAO.Voice.onEvent(otherId,
                                    "promiseMe", tickCount)
                                -- The ask is a CLAIM ([B3]): this
                                -- hearer carries the promise.
                                SAO.Standing.recordPromise(otherId, id)
                            end
                        end)
                    end
                end
            end
        end
        if SAO.Standing.sameGroup(id, otherId)
            and tickCount >= (agent.nextShareAt or 0) then
            local fellowNeeds = SAO.Needs.read(otherBody)
            local giveFn = SAO.Standing.isBondedTo(id, otherId)
                and SAO.Needs.shareAllWith
                or SAO.Needs.shareFoodWith
            -- Policy eats first ([A26]): under watch-first, a fellow
            -- ON WATCH is fed a full tenth earlier; everyone else waits
            -- for real hunger. The bonded exemption stands above policy
            -- (the bond predates the house).
            local shareBar = SAO.Disposition.eatAt(otherId) + 0.15
            do
                local pg = SAO.Standing.groupOf(id)
                local pol = pg and SAO.Standing.rationPolicyOf(pg) or nil
                local orec2 = SAO.Identity.get(otherId)
                if pol == "watch-first" and orec2
                    and orec2.designation == "watch" then
                    shareBar = shareBar - 0.10
                end
            end
            if fellowNeeds and fellowNeeds.hunger >= shareBar
                and giveFn(id, body, otherBody) then
                agent.nextShareAt = tickCount + 3600
                SAO.Standing.adjustTrust(otherId, id, 0.10)
                SAO.Standing.adjustTrust(id, otherId, 0.03)
                pcall(function()
                    SAO.Voice.onEvent(id, "share", tickCount)
                end)
                log(id .. " gave food to hungry fellow " .. otherId)
            end
        end

        -- Doctrine meets doctrine (census C5, [A18]): members
        -- of two companies talk politics on a slow per-pair
        -- clock. What happens happens - through standing only.
        if not SAO.Standing.sameGroup(id, otherId) then
            local warmM, sharpM = meetingTemper(body, otherBody)
            local verdict = SAO.Standing.politick(id, otherId, tickCount)
            -- The state's share of what just happened ([B9]): a
            -- top-up on the politick's own move, so doctrine still
            -- decides the direction and the state decides how hard.
            if verdict == "aligned" then
                SAO.Standing.adjustTrust(id, otherId, 0.05 * (warmM - 1))
                SAO.Standing.adjustTrust(otherId, id, 0.05 * (warmM - 1))
            elseif verdict == "opposed" then
                SAO.Standing.adjustTrust(id, otherId, -0.08 * (sharpM - 1))
                SAO.Standing.adjustTrust(otherId, id, -0.08 * (sharpM - 1))
            end
            if verdict == "aligned" then
                pcall(function()
                    SAO.Voice.onEvent(id, "creedAligned", tickCount)
                end)
                log(id .. " and " .. otherId
                    .. " find their companies see it the same way")
            elseif verdict == "opposed" then
                pcall(function()
                    SAO.Voice.onEvent(id, "creedOpposed", tickCount)
                end)
                log(id .. " and " .. otherId
                    .. " argue doctrine - their companies won't mix")
            elseif verdict == "hostile" then
                pcall(function()
                    SAO.Voice.onEvent(id, "feud", tickCount)
                end)
                log("words became weapons between " .. id
                    .. " and " .. otherId)
            elseif verdict == "peace" then
                pcall(function()
                    SAO.Voice.onEvent(id, "peace", tickCount)
                end)
                log("PEACE: " .. tostring(SAO.Standing.groupOf(id))
                    .. " and " .. tostring(SAO.Standing.groupOf(otherId))
                    .. " end their feud - their leaders shook on it")
            elseif verdict == "feud-declared" then
                pcall(function()
                    SAO.Voice.onEvent(id, "feud", tickCount)
                end)
                log("FEUD: " .. tostring(SAO.Standing.groupOf(id))
                    .. " and " .. tostring(SAO.Standing.groupOf(otherId))
                    .. " are enemies now")
            elseif verdict == "pact" then
                pcall(function()
                    SAO.Voice.onEvent(id, "pact", tickCount)
                end)
                log("PACT: " .. tostring(SAO.Standing.groupOf(id))
                    .. " and " .. tostring(SAO.Standing.groupOf(otherId))
                    .. " shook on bread-for-watch")
            end
        end

        -- Charity: a compassionate survivor who SEES a
        -- stranger in visibly bad shape gives the spare
        -- piece - no bond required, only eyes and
        -- temperament. The desperate remember kindness
        -- harder than company does.
        -- Policy closes hands ([A26]): under house-first, charity to
        -- strangers stops - the house feeds the house. The member may
        -- disagree; that is what dissent is for.
        local charityShut = false
        do
            local pg2 = SAO.Standing.groupOf(id)
            charityShut = pg2
                and SAO.Standing.rationPolicyOf(pg2) == "house-first" or false
        end
        -- A full shelf opens hands ([A28]): situation can carry a
        -- giver past a temperament that would just barely refuse -
        -- generosity is easier when the house KNOWS it has plenty.
        local larderOpen = false
        do
            local lg5 = SAO.Standing.groupOf(id)
            local ll5 = lg5 and SAO.Standing.larderOf
                and SAO.Standing.larderOf(lg5) or nil
            -- [B35] The road's policy governed NOTHING. Four creeds
            -- each adopt a ration policy and three of them change
            -- behaviour; `carry-light` was assigned to a road house,
            -- announced on the wire as "light packs, nothing held
            -- back", and then read by no gate anywhere - so a road
            -- house behaved exactly like a house with no policy at
            -- all.
            --
            -- It is the mirror of house-first, which shuts charity,
            -- so it belongs on the same switch rather than a new one:
            -- a house that holds nothing back gives as though the
            -- shelf were full, because keeping stores is not their
            -- way.
            local lp5 = lg5 and SAO.Standing.rationPolicyOf
                and SAO.Standing.rationPolicyOf(lg5) or nil
            larderOpen = (ll5 and ll5.word == "full")
                or lp5 == "carry-light" or false
        end
        local warmC = select(1, meetingTemper(body, otherBody))
        if not charityShut
            and warmC >= 0.85
            and not SAO.Standing.sameGroup(id, otherId)
            and tickCount >= (agent.nextShareAt or 0)
            and (SAO.Disposition.wouldGiveToStranger(id) or larderOpen)
            and not refusesColors(id, agent, otherId, tickCount) then
            local otherName = SAO.Identity.displayName(
                SAO.Identity.get(otherId))
            local seenOther = otherName
                and SAO.Perception.beliefs[id]
                and SAO.Perception.beliefs[id].people[otherName] or nil
            -- The carer's charity ([A20]): a carer facing a HURT
            -- stranger reaches for the bandage before the bread -
            -- occupation shapes what kindness hands over.
            if seenOther and seenOther.condition
                and (tickCount - seenOther.at) <= 120
                and not SAO.Standing.isHostileTo(id, otherId)
                and (string.find(seenOther.condition, "hurt", 1, true)
                    or string.find(seenOther.condition, "bad", 1, true))
                and SAO.Census and SAO.Census.classOf
                and SAO.Census.classOf(SAO.Identity.get(id)
                    and SAO.Identity.get(id).occupation) == "carer"
                and SAO.Needs.aidWound(id, body, otherBody) then
                agent.nextShareAt = tickCount + 3600
                SAO.Standing.adjustTrust(otherId, id, 0.15)
                pcall(function()
                    SAO.Voice.onEvent(id, "aid", tickCount)
                end)
                log(id .. " gave a bandage to a hurt stranger ("
                    .. otherId .. ")")
            elseif seenOther and seenOther.condition
                and string.find(seenOther.condition, "bad", 1, true)
                and (tickCount - seenOther.at) <= 120
                and not SAO.Standing.isHostileTo(id, otherId)
                and SAO.Needs.shareFoodWith(id, body, otherBody) then
                agent.nextShareAt = tickCount + 3600
                SAO.Standing.adjustTrust(otherId, id, 0.15)
                pcall(function()
                    SAO.Voice.onEvent(id, "share", tickCount)
                end)
                log(id .. " gave food to a suffering stranger (" .. otherId .. ")")
            end
        end

        -- Settlement: debts clear before new trades. The
        -- DEBTOR (this agent, if they owe the other) hands
        -- over a spare when they have one; the ledger
        -- forgives, trust mends a little, and it is said.
        if SAO.Standing.debt(otherId, id) > 0
            and tickCount >= (agent.nextBarterAt or 0) then
            local paid = SAO.Needs.shareFoodWith(id, body, otherBody)
                or SAO.Needs.shareDrinkWith(id, body, otherBody)
            if paid then
                agent.nextBarterAt = tickCount + 3600
                SAO.Standing.settleDebt(otherId, id, 1)
                SAO.Standing.adjustTrust(otherId, id, 0.08)
                pcall(function()
                    SAO.Voice.onEvent(id, "settle", tickCount)
                end)
                log(id .. " settles their debt to " .. otherId)
            end
        end

        -- The bond ([A14] S7): sustained high mutual
        -- trust inside company settles into one fact on
        -- both relations - at most one bonded partner per
        -- person, voiced once. To the end of it.
        if SAO.Standing.sameGroup(id, otherId)
            and not SAO.Standing.bondedWith(id)
            and not SAO.Standing.bondedWith(otherId)
            and SAO.Standing.trust(id, otherId) > 0.75
            and SAO.Standing.trust(otherId, id) > 0.75 then
            -- Mutual trust past 0.75 IS the tenure
            -- evidence: encounter warmth accrues at
            -- 0.002 a meeting - nobody reaches this line
            -- quickly, and shared fights got them here.
            if SAO.Standing.bond(id, otherId) then
                pcall(function()
                    SAO.Voice.onEvent(id, "bonded", tickCount)
                end)
                log(id .. " and " .. otherId
                    .. " are bonded now - one fact, both relations")
            end
        end

        -- The smokers' bond ([A14]): a smoker with spares
        -- beside a smoker with none hands one over - the
        -- oldest social glue there is. Small mutual trust.
        if tickCount >= (agent.nextSmokeShareAt or 0)
            and SAO.Disposition.isSmoker(id)
            and SAO.Disposition.isSmoker(otherId)
            and not refusesColors(id, agent, otherId, tickCount)
            and not SAO.Standing.isHostileTo(id, otherId)
            and SAO.Needs.smokableCount(body) >= 2
            and SAO.Needs.smokableCount(otherBody) == 0 then
            if SAO.Needs.shareSmokeWith(id, body, otherBody) then
                agent.nextSmokeShareAt = tickCount + 3600
                SAO.Standing.adjustTrust(id, otherId, 0.04)
                SAO.Standing.adjustTrust(otherId, id, 0.04)
                pcall(function()
                    SAO.Voice.onEvent(id, "smokeShare", tickCount)
                end)
                log(id .. " and " .. otherId .. " share a smoke")
            end
        end

        -- Barter: inverse surpluses swap. I am thirsty
        -- and food-rich; they are hungry and drink-rich -
        -- one piece each, through two vanilla transfers.
        -- No currency, no UI: trade is what need-shapes do
        -- when they meet. Non-hostile only; group members
        -- share freely above and never need this.
        if not SAO.Standing.sameGroup(id, otherId)
            and tickCount >= (agent.nextBarterAt or 0)
            and not SAO.Standing.isHostileTo(id, otherId)
            and not SAO.Standing.isHostileTo(otherId, id)
            and not refusesColors(id, agent, otherId, tickCount) then
            local myNeeds = SAO.Needs.read(body)
            local theirNeeds = SAO.Needs.read(otherBody)
            if myNeeds and theirNeeds
                and myNeeds.thirst >= SAO.Disposition.drinkAt(id)
                and theirNeeds.hunger >= SAO.Disposition.eatAt(otherId) then
                local gaveFood = SAO.Needs.shareFoodWith(id, body, otherBody)
                local gaveDrink = gaveFood
                    and SAO.Needs.shareDrinkWith(otherId, otherBody, body)
                if gaveFood and gaveDrink then
                    agent.nextBarterAt = tickCount + 3600
                    SAO.Standing.adjustTrust(id, otherId, 0.05)
                    SAO.Standing.adjustTrust(otherId, id, 0.05)
                    pcall(function()
                        SAO.Voice.onEvent(id, "barter", tickCount)
                    end)
                    log(id .. " and " .. otherId
                        .. " traded food for water")
                elseif gaveFood then
                    -- Half a trade is a debt, not a loss:
                    -- they owe me one, and the ledger
                    -- remembers until we meet with spares.
                    agent.nextBarterAt = tickCount + 3600
                    SAO.Standing.addDebt(id, otherId, 1)
                    log(otherId .. " owes " .. id
                        .. " one (trade half-completed)")
                end
            end
        end

        -- The county's oldest currency ([A21]): a HUNGRY survivor with
        -- spare smokes offers one to a craving smoker who has food to
        -- spare - cigarettes for bread, two vanilla transfers, the same
        -- debt ledger as any half-trade. Only need-shapes meeting; no
        -- prices, no UI.
        if not SAO.Standing.sameGroup(id, otherId)
            and tickCount >= (agent.nextBarterAt or 0)
            and not SAO.Standing.isHostileTo(id, otherId)
            and not SAO.Standing.isHostileTo(otherId, id)
            and SAO.Disposition.isSmoker(otherId)
            and SAO.Needs.smokableCount(body) >= 2
            and not refusesColors(id, agent, otherId, tickCount) then
            local myNeeds2 = SAO.Needs.read(body)
            local theirNeeds2 = SAO.Needs.read(otherBody)
            if myNeeds2 and theirNeeds2
                and myNeeds2.hunger >= SAO.Disposition.eatAt(id)
                and (theirNeeds2.nicotine or 0) >= 0.2 then
                local gaveSmoke = SAO.Needs.shareSmokeWith(id, body, otherBody)
                local gaveFood = gaveSmoke
                    and SAO.Needs.shareFoodWith(otherId, otherBody, body)
                if gaveSmoke and gaveFood then
                    agent.nextBarterAt = tickCount + 3600
                    SAO.Standing.adjustTrust(id, otherId, 0.05)
                    SAO.Standing.adjustTrust(otherId, id, 0.05)
                    pcall(function()
                        SAO.Voice.onEvent(id, "barter", tickCount)
                    end)
                    log(id .. " and " .. otherId
                        .. " traded smokes for food")
                elseif gaveSmoke then
                    agent.nextBarterAt = tickCount + 3600
                    SAO.Standing.addDebt(id, otherId, 1)
                    log(otherId .. " owes " .. id
                        .. " one (smoke handed, nothing back yet)")
                end
            end
        end

        -- Leadership settles in conversation ([A14]):
        -- same-group meetings re-derive the deferred-to
        -- member from the trust web; a flip is a standing
        -- event, logged and voiced by whoever takes point.
        if SAO.Standing.sameGroup(id, otherId)
            and tickCount >= (agent.nextElectionAt or 0) then
            agent.nextElectionAt = tickCount + 1800
            local electGroup = SAO.Standing.groupOf(id)
            local newLeader, oldLeader =
                SAO.Standing.electLeader(electGroup)
            -- Schism ([A22]): the election moment is where a divided
            -- house discovers it cannot stand.
            -- Dissent has a voice ([A25]): a member whose class
            -- chafes under the community's policy says so where
            -- politics happen.
            if SAO.Standing.dissentsFromPolicy
                and SAO.Standing.dissentsFromPolicy(id) then
                pcall(function()
                    SAO.Voice.onEvent(id, "grumble", tickCount)
                end)
            end
            local newHouse, core, leaverCount =
                SAO.Standing.checkSchism(electGroup)
            if newHouse then
                pcall(function()
                    SAO.Voice.onEvent(core, "feud", tickCount)
                end)
                log("SCHISM: " .. tostring(core) .. " leads "
                    .. tostring(leaverCount) .. " out of "
                    .. tostring(SAO.Standing.factionName(electGroup)
                        or electGroup) .. " - two houses now, at feud")
            end
            if newLeader and oldLeader and newLeader ~= oldLeader then
                log(electGroup .. ": leadership passes "
                    .. tostring(oldLeader) .. " -> " .. newLeader)
                if Ctl.agents[newLeader] then
                    pcall(function()
                        SAO.Voice.onEvent(newLeader, "takePoint", tickCount)
                    end)
                end
            end
        end

        -- One lesson per conversation: survival knowledge
        -- moves along the same roads, at told weight - a
        -- lesson heard is weaker than a lesson lived.
        local lessonTold = SAO.Lessons.tellOne(id, otherId)
        if lessonTold then
            pcall(function()
                SAO.Voice.onEvent(id, "lessonTold", tickCount)
            end)
            log(id .. " passed a lesson to " .. otherId
                .. ": " .. lessonTold)
        end

        -- Grudges travel the same roads as warnings, and
        -- carry less weight than being there ever does.
        -- What the house teaches ([B11]): the skilled bring the
        -- unskilled along. Same house, the learner's OWN trade, a
        -- real margin (3+), once a game hour per pair - and the
        -- teacher gains a little too, because teaching cements what
        -- you know. This is most of why people join houses, and the
        -- reason a loner's circle costs them more than safety.
        if SAO.Standing.sameGroup(id, otherId) and SAO.Census.skillOf then
            local okTH, nowTH = pcall(function()
                return GameTime.getInstance():getWorldAgeHours()
            end)
            agent.taughtAt = agent.taughtAt or {}
            if okTH and nowTH - (agent.taughtAt[otherId] or -9) >= 1 then
                -- [B20] The shared table - see Census.JOB_PERK.
                local JOB_PERK17 = SAO.Census.JOB_PERK or {}
                local orec17 = SAO.Identity.get(otherId)
                local perk17 = orec17 and orec17.designation
                    and JOB_PERK17[orec17.designation] or nil
                if perk17 then
                    local mine17 = SAO.Census.skillOf(id, perk17)
                    local theirs17 = SAO.Census.skillOf(otherId, perk17)
                    if mine17 and theirs17 and mine17 >= 0
                        and theirs17 >= 0 and mine17 >= theirs17 + 3 then
                        agent.taughtAt[otherId] = nowTH
                        pcall(function()
                            SAOJavaBridge:grantXP(otherBody, perk17, 6.0)
                            SAOJavaBridge:grantXP(body, perk17, 1.0)
                        end)
                        SAO.Standing.adjustTrust(otherId, id, 0.03)
                        SAO.Standing.adjustTrust(id, otherId, 0.02)
                        pcall(function()
                            SAO.Voice.onEvent(id, "teaching", tickCount)
                        end)
                        log(id .. " shows " .. otherId .. " the "
                            .. perk17 .. " of it (" .. mine17 .. " to "
                            .. theirs17 .. ")")
                    end
                end
            end
        end
        -- Both kinds of word travel the same road ([B8]).
        local c = SAO.Standing.tellCredits(id, otherId)
        if c > 0 then
            pcall(function()
                SAO.Voice.onEvent(id, "goodWord", tickCount)
            end)
            log(id .. " speaks well of " .. c
                .. " people to " .. otherId)
        end
        local g = SAO.Standing.tellGrudges(id, otherId)
        if g > 0 then
            log(id .. " told " .. otherId .. " who wronged them ("
                .. g .. " name(s))")
            pcall(function() SAO.Voice.onEvent(id, "grudgeTold", tickCount) end)
        end
        -- Emergent company: mutual trust past the threshold
        -- and at least one of them unattached. Two strangers
        -- found a company; a third wheel with the trust of a
        -- member JOINS that member's company (both-grouped
        -- pairs stay as they are - mergers are politics, not
        -- an if-branch).
        local myGroup = SAO.Standing.groupOf(id)
        local otherGroup = SAO.Standing.groupOf(otherId)
        -- Mercy takes people in ([A24]): when the grouped side's creed
        -- is mercy, the company line softens a tenth - that is what
        -- mercy MEANS, mechanically.
        local companyBar = policy().trustToCompany
        do
            local hostG = myGroup or otherGroup
            if hostG then
                local hc = SAO.Standing.creedOf(hostG)
                if hc and hc.name == "mercy" then
                    companyBar = companyBar - 0.1
                end
            end
        end
        if not (myGroup and otherGroup) and (not myGroup or not otherGroup)
            and SAO.Standing.trust(id, otherId) > companyBar
            and SAO.Standing.trust(otherId, id) > companyBar then
            local groupName = myGroup or otherGroup
                or ("company-" .. tostring(id))
            -- Their own company ([A27]): trust opened the door; the
            -- circle decides. A refusal is said ONCE, costs nothing,
            -- and stands - temperament is not a bug to wear down.
            local refuser = nil
            if SAO.Standing.circleRefuses(id, groupName) then
                refuser = id
            elseif SAO.Standing.circleRefuses(otherId, groupName) then
                refuser = otherId
            end
            if refuser then
                agent.circleSaid = agent.circleSaid or {}
                if not agent.circleSaid[otherId] then
                    agent.circleSaid[otherId] = true
                    pcall(function()
                        SAO.Voice.onEvent(refuser, "ownCompany", tickCount)
                    end)
                    log(refuser .. " keeps their own company - no hard"
                        .. " feelings")
                end
                return
            end
            SAO.Standing.joinGroup(id, groupName)
            SAO.Standing.joinGroup(otherId, groupName)
            log(id .. " and " .. otherId
                .. " now keep company (mutual trust)")
            -- Moving in: the JOINER moves; the standing
            -- member keeps their house. Only when both were
            -- unattached does lexical order pick the host.
            local anchorId, moverId
            if myGroup and not otherGroup then
                anchorId, moverId = id, otherId
            elseif otherGroup and not myGroup then
                anchorId, moverId = otherId, id
            else
                anchorId = (id < otherId) and id or otherId
                moverId = (id < otherId) and otherId or id
            end
            -- The joiner moves in with the LEADER, not
            -- merely the member they befriended ([A14]).
            local settledLeader = SAO.Standing.leaderOf(groupName)
            if settledLeader and settledLeader ~= moverId then
                anchorId = settledLeader
            end
            local anchorRec = SAO.Identity.get(anchorId)
            local moverRec = SAO.Identity.get(moverId)
            if anchorRec and moverRec and anchorRec.homeX then
                moverRec.homeX = anchorRec.homeX
                moverRec.homeY = anchorRec.homeY
                moverRec.homeZ = anchorRec.homeZ
                pcall(function()
                    -- [B34] Moving in means moving into THEIR
                    -- ground, so take the ground they actually hold
                    -- rather than inventing a fresh box around their
                    -- doorstep. Two people in one house now describe
                    -- the same house; before this they described two
                    -- overlapping squares that happened to share a
                    -- centre. Only where the anchor holds nothing
                    -- does a radius have to be guessed at.
                    local ac = SAO.Standing.claimOf(anchorId)
                    if ac then
                        SAO.Standing.claim(moverId, ac.minX, ac.minY,
                            ac.maxX, ac.maxY, ac.z or 0)
                    else
                        local mnX, mnY, mxX, mxY =
                            SAO.Standing.groundAround(
                                SAO.Body.get(anchorId),
                                anchorRec.homeX, anchorRec.homeY, 4)
                        SAO.Standing.claim(moverId, mnX, mnY, mxX, mxY,
                            anchorRec.homeZ or 0)
                    end
                end)
                pcall(function()
                    SAO.Voice.onEvent(anchorId, "movein", tickCount)
                end)
                log(moverId .. " moves in with " .. anchorId)
            end
            pcall(function() SAO.Voice.onEvent(id, "company", tickCount) end)
        end
end

log("exchange module loaded")

return Exchange
