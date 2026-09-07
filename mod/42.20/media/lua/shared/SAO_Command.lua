-- SAO_Command - the Standing pillar's command surface (ARCHITECTURE
-- §Standing: "orders ... and who may direct whom").
-- ---------------------------------------------------------------------------
-- [C37] An order lands through standing (DR-033, ruled 2026-09-06).
-- Whether a person does what they are told is a social fact - the
-- houses, leaders and designations Standing keeps, the trust the
-- person holds in the one asking, and the competence that one has
-- shown - never a control scheme. CAO's Authority pillar is the model
-- the operator named, carried over whole: the giver's command
-- standing (an office over the follower, shaded by the follower's
-- opinion of them), the follower's conformity and discipline, three
-- bands, refusal a visible event with its reason. Refusal is
-- contextual: what the person would do at all is the disposition's
-- and Standing's business, asked here the way the controller asks it
-- for their own decisions.
--
-- Nothing here executes and nothing here speaks: the harness voices
-- the verdict and the controller walks the order. Reads Standing,
-- Disposition, Perception and the census; writes nothing.

SAO = SAO or {}
SAO.Command = SAO.Command or {}
local Cmd = SAO.Command

-- CAO's Authority.CommandStanding: a squad leader's word 0.8, a
-- fire-team lead's 0.65, anyone else's 0.4; the follower's opinion
-- moves it by half a point either way (opinion -100 .. 100 over 200
-- there; trust -1 .. 1 over 2 here, the same half point).
Cmd.OFFICE = { leader = 0.80, second = 0.65, none = 0.40 }

-- CAO's Authority.Check: standing 0.55, conformity 0.25, discipline
-- 0.20; at 0.44 complies, at 0.34 goes along reluctantly, under it
-- refuses. CAO's own tuning note holds here unchanged: the default
-- person under a peer scores 0.445 and complies cleanly - reluctance
-- and refusal are for genuinely low conformity or discipline, or real
-- dislike, not ambient noise.
Cmd.WEIGHT = { standing = 0.55, conformity = 0.25, discipline = 0.20 }
Cmd.COMPLIES_AT = 0.44
Cmd.RELUCTANT_AT = 0.34

-- CAO's reasons, in order: thinks little of the giver (opinion at or
-- under -15 of 100, so trust at or under -0.15), sees no authority in
-- them (standing under 0.45), or simply will not be told.
Cmd.DISLIKE_AT = -0.15
Cmd.NO_STANDING_AT = 0.45

-- [B19]'s teaching margin, the county's one measure of a hand that
-- outranks another: three levels. The controller's teaching reads it
-- from here now, so the two cannot drift.
Cmd.TEACH_MARGIN = 3

-- What is asked, and what it is asked in. `engage` is a fight and the
-- ground of the fight is kills; `work` is a job and its matter is the
-- census's own perk for that job; everything else - hold, keep close,
-- walk, board, step out, travel - is asked in no matter at all.
Cmd.KINDS = { "hold", "close", "walk", "travel", "board", "unboard",
              "work", "engage" }

local function playerBody(giverKey)
    local body = nil
    pcall(function()
        if getSpecificPlayer then body = getSpecificPlayer(0) end
    end)
    if body then
        local ok, key = pcall(function()
            return SAO.Standing.playerKey(body)
        end)
        if ok and key and tostring(key) ~= tostring(giverKey) then
            body = nil
        end
    end
    return body
end

local function bodyOf(key)
    local S = SAO.Standing
    if S.isPlayerKey and S.isPlayerKey(key) then return playerBody(key) end
    local body = nil
    pcall(function() body = SAO.Body.get(key) end)
    return body
end

-- The office the giver holds over this person: their house's leader
-- (or the player seated in its chair, which is the same office), its
-- second, or none. A person of no house is under nobody's office.
function Cmd.officeOf(giverKey, id)
    local S = SAO.Standing
    local group = nil
    pcall(function() group = S.groupOf(id) end)
    if not group then return "none" end
    giverKey = tostring(giverKey)
    local lead, chair, second = nil, nil, nil
    pcall(function() lead = S.leaderOf(group) end)
    pcall(function() chair = S.playerChairOf(group) end)
    if (lead and tostring(lead) == giverKey)
        or (chair and tostring(chair) == giverKey) then
        return "leader"
    end
    pcall(function() second = S.secondOf(group) end)
    if second and tostring(second) == giverKey then return "second" end
    return "none"
end

-- The competence the giver has shown in the matter (DR-033: the
-- skills and the kills already carry it). A job's perk against the
-- follower's own by the teaching margin; a fight by kills, the giver
-- having more than the follower and at least one. Read live - the
-- player's off the player, a survivor's through the census. What
-- cannot be read is not shown.
function Cmd.provenIn(giverKey, id, kind, job)
    local giver = bodyOf(giverKey)
    if not giver then return false end
    if kind == "engage" then
        local mine, theirs = -1, 0
        pcall(function() mine = giver:getZombieKills() end)
        pcall(function()
            local body = SAO.Body.get(id)
            if body then theirs = body:getZombieKills() end
        end)
        return type(mine) == "number" and mine > 0 and mine > theirs
    end
    if kind ~= "work" or not job then return false end
    local perk = SAO.Census and SAO.Census.JOB_PERK
        and SAO.Census.JOB_PERK[job] or nil
    if not perk then return false end
    local mine, theirs = -1, -1
    pcall(function()
        local perkObj = Perks and Perks[perk] or nil
        if perkObj then mine = giver:getPerkLevel(perkObj) end
    end)
    pcall(function() theirs = SAO.Census.skillOf(id, perk) or -1 end)
    return type(mine) == "number" and type(theirs) == "number"
        and mine >= 0 and theirs >= 0 and mine >= theirs + Cmd.TEACH_MARGIN
end

-- Command standing: the office's word, or - where no office holds - a
-- proven hand's, followed like a second (the ruling's "competence and
-- background" in the currency CAO's ladder already has); then the
-- person's own trust in the giver, half a point either way.
function Cmd.standingOf(giverKey, id, kind, job)
    local office = Cmd.officeOf(giverKey, id)
    local base = Cmd.OFFICE[office] or Cmd.OFFICE.none
    if office == "none" and Cmd.provenIn(giverKey, id, kind, job) then
        base = Cmd.OFFICE.second
        office = "proven"
    end
    local trust = 0
    pcall(function() trust = SAO.Standing.trust(id, giverKey) or 0 end)
    if type(trust) ~= "number" then trust = 0 end
    local standing = math.max(0, math.min(1, base + trust / 2))
    return standing, office, trust
end

-- Does this person take the giver's word in this matter? CAO's check
-- on the county's own axes. Conformity is not one of the eight; the
-- initiative axis is, and its own definition is "self-starts vs
-- waits" - the one who waits is the one who takes telling - so
-- conformity is read off it, inverted, inside the same envelope.
function Cmd.obedience(giverKey, id, kind, job)
    local standing, office, trust = Cmd.standingOf(giverKey, id, kind, job)
    local t = nil
    pcall(function() t = SAO.Disposition.traits(id) end)
    t = t or {}
    local conformity = 1 - (t.initiative or 0.5)
    local discipline = t.discipline or 0.5
    local score = standing * Cmd.WEIGHT.standing
        + conformity * Cmd.WEIGHT.conformity
        + discipline * Cmd.WEIGHT.discipline
    local verdict = "refuses"
    if score >= Cmd.COMPLIES_AT then
        verdict = "complies"
    elseif score >= Cmd.RELUCTANT_AT then
        verdict = "reluctant"
    end
    local reason = nil
    if verdict ~= "complies" then
        if trust <= Cmd.DISLIKE_AT then
            reason = "does not think much of you"
        elseif standing < Cmd.NO_STANDING_AT then
            reason = "sees no standing in you"
        else
            reason = "is not one to be told"
        end
    end
    return verdict, reason, score, standing, office
end

-- Would they do it at all? The same questions the controller asks for
-- their own decisions, with the person's own reason when the answer
-- is no. A fight: armed, not past the fear a child carries, and the
-- disposition's own choice against the threats they believe in.
-- Ground: Standing's entry law and what they believe the ground to
-- be, and no walking into what they believe is there and would not
-- face. Everything else is inside anyone's envelope.
function Cmd.envelope(id, kind, arg)
    local D, S, P = SAO.Disposition, SAO.Standing, SAO.Perception
    if kind == "engage" then
        local armed = false
        pcall(function()
            local agent = SAO.Controller.agents[tostring(id)]
            armed = agent and agent.armed and true or false
        end)
        if not armed then return false, "has nothing to fight with" end
        local fear = 0
        pcall(function() fear = D.fear(id) or 0 end)
        if fear >= 0.5 then return false, "is too afraid" end
        local count = 1
        pcall(function()
            local body = SAO.Body.get(id)
            local tick = SAO.Controller.tick()
            count = math.max(1, P.believedThreatCount(id, tick,
                D.fleeDistance(id), body:getX(), body:getY()))
        end)
        local would = false
        pcall(function() would = D.wouldEngage(id, true, count) end)
        if not would then return false, "would not take that fight" end
        return true, nil
    elseif kind == "travel" and type(arg) == "table" and arg.x and arg.y then
        local may = true
        pcall(function() may = S.mayEnter(id, arg.x, arg.y) end)
        if may == false then
            return false, "will not walk onto someone else's ground"
        end
        local owner = nil
        pcall(function() owner = P.believesClaimed(id, arg.x, arg.y) end)
        if owner then
            local hostile = false
            pcall(function()
                hostile = S.isHostileTo(id, owner) or S.isHostileTo(owner, id)
            end)
            if not hostile then
                return false, "believes that ground is somebody's"
            end
        end
        local near = nil
        pcall(function()
            near = P.nearestBelievedZombie(id, SAO.Controller.tick(),
                arg.x, arg.y)
        end)
        if near and near.dist then
            local flee, would = 0, true
            pcall(function() flee = D.fleeDistance(id) end)
            pcall(function()
                local agent = SAO.Controller.agents[tostring(id)]
                would = D.wouldEngage(id, agent and agent.armed and true or false, 1)
            end)
            if near.dist <= flee and not would then
                return false, "will not walk into what they believe is there"
            end
        end
        return true, nil
    end
    return true, nil
end

-- The whole of it: who is asking, of whom, what. Returns the verdict
-- - complies, reluctant, refuses - and the reason when it is not a
-- clean yes. The word comes first (a person who will not be told is
-- not asked whether they could), then the envelope.
function Cmd.order(giverKey, id, kind, arg)
    local job = (kind == "work") and arg or nil
    local verdict, reason = Cmd.obedience(giverKey, id, kind, job)
    if verdict == "refuses" then return verdict, reason end
    local ok, why = Cmd.envelope(id, kind, arg)
    if not ok then return "refuses", why end
    return verdict, reason
end

-- The panel's row, in plain words (DR-017): whether they would take
-- a word from the giver in no particular matter, and why not.
function Cmd.describe(id, giverKey)
    local verdict, reason, _, _, office = Cmd.obedience(giverKey, id, "walk", nil)
    local who = ({ leader = "their leader", second = "their second",
                   proven = "a proven hand", none = "no office" })[office]
        or "no office"
    if verdict == "complies" then return "would do it, " .. who end
    if verdict == "reluctant" then
        return "would, grudgingly, " .. tostring(reason)
    end
    return "would not, " .. tostring(reason)
end

return Cmd
