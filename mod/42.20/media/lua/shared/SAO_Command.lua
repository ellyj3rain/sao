-- SAO_Command - a spoken request and its matter-scoped response.
--
-- A request is addressed to one person, must actually reach them, and is
-- answered from that person's present activity, capability, relationship and
-- interests. An accepted food delivery or any other unrelated responsibility
-- is never command authority. Authority exists only through an active enacted
-- office whose jurisdiction covers this command kind, or through an active
-- commitment to this exact `command:<kind>` matter.
--
-- Nothing here executes the requested act. The harness or controller may act
-- only on the delivered response returned by `Cmd.order`; the durable proposal,
-- private appraisal, response and any resulting scoped commitment belong to
-- Organization.

SAO = SAO or {}
SAO.Command = SAO.Command or {}
local Cmd = SAO.Command

-- [B19]'s teaching margin, the county's one measure of a hand that
-- outranks another: three levels. The controller's teaching reads it
-- from here now, so the two cannot drift.
Cmd.TEACH_MARGIN = 3

-- What is asked, and what it is asked in. `engage` is a fight and the
-- ground of the fight is kills; `work` is a job and its matter is the
-- census's own perk for that job; `rouse` is being woken for
-- something somebody else has seen and its matter is the watch;
-- `leave` is being told off ground and its matter is the ground;
-- everything else - hold, keep close, walk, board, step out, travel -
-- is asked in no matter at all.
--
-- [C49] `rouse` and `leave` are issued only by SAO_Controller; no
-- menu uses them. `rouse` is the keeper waking the house, `leave` is
-- an owner telling a trespasser off their claim.
Cmd.KINDS = { "hold", "close", "walk", "travel", "board", "unboard",
              "work", "engage", "rouse", "leave" }

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
    pcall(function()
        body = SAO.Communication and SAO.Communication.bodyFor(key) or nil
    end)
    return body
end

local function recipientNeed(id)
    local body = bodyOf(id)
    if not (body and SAO.Needs and SAO.Needs.read) then return 0 end
    local need = nil
    pcall(function() need = SAO.Needs.read(body) end)
    if type(need) ~= "table" then return 0 end
    return math.max(tonumber(need.hunger) or 0, tonumber(need.thirst) or 0)
end

local function activeCommitment(commitmentId, giverKey, group, matter)
    local Org = SAO.Organization
    if not (Org and Org.authorityFor and commitmentId) then return false end
    for _, scope in ipairs(Org.authorityFor(tostring(giverKey), group,
        matter)) do
        if scope.commitmentId == commitmentId then return true end
    end
    return false
end

local function jurisdictionCovers(office, kind)
    local jurisdiction = office and office.jurisdiction or nil
    return type(jurisdiction) == "table" and (jurisdiction.command == true
        or jurisdiction[tostring(kind)] == true
        or jurisdiction["command:" .. tostring(kind)] == true)
end

-- The office or direct mandate the giver holds for this exact command kind.
-- Roster membership, a legacy leader projection and unrelated commitments
-- supply no authority.
function Cmd.officeOf(giverKey, id, kind)
    local S = SAO.Standing
    local group = nil
    pcall(function() group = S.groupOf(id) end)
    if not group then return "none" end
    giverKey, group, kind = tostring(giverKey), tostring(group), tostring(kind)
    local Org = SAO.Organization
    for _, candidate in ipairs({ { "chair", "leader" },
            { "deputy", "second" } }) do
        local office = Org and Org.offices
            and Org.offices[group .. ":" .. candidate[1]] or nil
        local held = office and office.holders and office.holders[giverKey]
            or nil
        if type(held) == "table" and held.commitmentId
            and jurisdictionCovers(office, kind)
            and activeCommitment(held.commitmentId, giverKey, group) then
            return candidate[2]
        end
    end
    if Org and Org.authorityFor
        and #Org.authorityFor(giverKey, group, "command:" .. kind) > 0 then
        return "mandate"
    end
    return "none"
end

-- [C49] What standing the giver has in this specific matter, read
-- from records that already exist. DR-033 names designations,
-- competence and the Standing pillar as the inputs.
--
--   engage  their zombie kills, higher than the follower's and at
--           least one
--   work    the census perk for that job, at least TEACH_MARGIN
--           levels above the follower's ([B19]) - or the giver holds
--           that designation, which is the house having already
--           given them the job
--   rouse   the giver holds the "watch" designation
--   leave   the giver's claim covers the square in question
--
-- Read live where the value is live (the player's kills off the
-- player, a survivor's skills through the census) and off the record
-- otherwise. Anything unreadable counts as no standing.
local function designationOf(key)
    local rec = nil
    pcall(function() rec = SAO.Identity and SAO.Identity.get(key) or nil end)
    return rec and rec.designation or nil
end

function Cmd.provenIn(giverKey, id, kind, arg)
    if kind == "rouse" then
        return designationOf(giverKey) == "watch"
    end
    if kind == "leave" then
        if not (type(arg) == "table" and arg.x and arg.y) then return false end
        local inside = false
        pcall(function()
            inside = SAO.Standing.insideClaim(giverKey, arg.x, arg.y) and true
                or false
        end)
        return inside
    end
    -- A dealt designation needs no body and no skill comparison: the
    -- house has already assigned the job.
    if kind == "work" and arg and designationOf(giverKey) == arg then
        return true
    end
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
    if kind ~= "work" or not arg then return false end
    local perk = SAO.Census and SAO.Census.JOB_PERK
        and SAO.Census.JOB_PERK[arg] or nil
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

-- Read the latest delivered response to a matching request. This compatibility
-- query reports enacted history; it does not predict assent from a score.
function Cmd.obedience(giverKey, id, kind, arg)
    local office = Cmd.officeOf(giverKey, id, kind)
    local processes = SAO.Organization and SAO.Organization.processes or {}
    local order = SAO.Organization and SAO.Organization.processOrder or {}
    for index = #order, 1, -1 do
        local process = processes[order[index]]
        if process and process.originatorId == tostring(giverKey)
            and process.kind == "command:" .. tostring(kind) then
            local participant = process.participants
                and process.participants[tostring(id)] or nil
            local response = participant and participant.responses
                and participant.responses[tostring(process.revision)] or nil
            if response and response.delivered then
                if response.response == "accept" then
                    return "complies", nil, 1, 1, office
                end
                return "refuses", response.response, 0, 0, office
            end
        end
    end
    return "refuses", "has not accepted this request", 0, 0, office
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

-- The whole of it: who asks whom to do what. The recipient's physical
-- envelope is one input to their own response; it is not a substitute for
-- acquiring the request or answering it.
function Cmd.order(giverKey, id, kind, arg)
    local ok, why = Cmd.envelope(id, kind, arg)
    if not (SAO.Organization and SAO.Communication) then
        return "refuses", "shared process is unavailable"
    end
    local group = SAO.Standing.groupOf(id)
    local explicitOffice = Cmd.officeOf(giverKey, id, kind)
    local process = SAO.Organization.raiseMatter(tostring(giverKey),
        "command:" .. tostring(kind), group, {
            kind = kind,
            argument = type(arg) == "table" and arg or { value = arg },
            recipientId = tostring(id),
            requiredCapabilities = { execute = true },
            scope = { action = kind, recipientId = tostring(id) },
        }, { tostring(id) }, {
            source = "spoken-command",
            proven = Cmd.provenIn(giverKey, id, kind, arg),
            office = explicitOffice,
        })
    if not process then return "refuses", "proposal could not be recorded" end
    if SAO.Communication.canConverse(tostring(giverKey), tostring(id)) ~= true then
        return "refuses", "did not receive the request"
    end
    if SAO.Organization.recordReception(process.id, tostring(id),
        process.revision, "spoken", tostring(giverKey),
        { kind = kind }) ~= true then
        return "refuses", "request reception was not recorded"
    end
    local trust, hostile = 0, false
    pcall(function()
        trust = SAO.Standing.trust(id, giverKey) or 0
        hostile = SAO.Standing.isHostileTo(id, giverKey) == true
    end)
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[tostring(id)] or nil
    local activity = agent and string.lower(tostring(agent.state or "idle"))
        or "dormant"
    local explicit = explicitOffice ~= "none"
    local ownNeed = recipientNeed(id)
    local choice = not ok and "decline"
        or hostile and "contest"
        or (kind == "leave" and ownNeed >= 0.75) and "decline"
        or (activity ~= "idle" and kind ~= "rouse" and kind ~= "leave")
            and "defer"
        or (explicit or Cmd.provenIn(giverKey, id, kind, arg)
            or trust >= 0.30) and "accept"
        or "qualify"
    local response = SAO.Organization.appraiseMatter(process.id,
        tostring(id), {
            owner = "Command.order", executor = "SAO.Command",
            currentActivity = activity,
            canAcquire = ok, canCarry = ok, canDeliver = ok,
            canExecute = ok,
            incapable = not ok, contest = hostile,
            relationship = trust, ownNeed = ownNeed,
            destinationKnown = true,
            choice = choice,
            terms = choice == "qualify" and {
                reason = "no accepted authority or relationship",
            } or {},
            constraints = { envelope = ok, reason = why },
            interests = { explicitAuthority = explicit,
                proven = Cmd.provenIn(giverKey, id, kind, arg),
                currentNeed = ownNeed },
        })
    if not response then return "refuses", "did not answer the request" end
    SAO.Organization.deliverResponse(process.id, tostring(id),
        tostring(giverKey), "spoken", { kind = kind })
    if response.response == "accept" then return "complies", nil end
    if response.response == "qualify" then
        return "refuses", "qualified the request; terms are not yet accepted"
    end
    return "refuses", why or response.response
end

-- The panel reports recorded response history rather than predicting what a
-- person would do from a roster or aggregate score.
function Cmd.describe(id, giverKey)
    local verdict, reason, _, _, office = Cmd.obedience(giverKey, id, "walk", nil)
    local who = ({ leader = "their leader", second = "their second",
                   mandate = "a scoped mandate", none = "no office" })[office]
        or "no office"
    if verdict == "complies" then
        return "accepted the last request, " .. who
    end
    if reason == "has not accepted this request" then
        return "no accepted request, " .. who
    end
    return "last response " .. tostring(reason) .. ", " .. who
end

return Cmd
