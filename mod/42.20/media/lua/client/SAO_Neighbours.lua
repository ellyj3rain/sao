-- SAO_Neighbours.lua - what this mod does about the others in the
-- load order ([B45], grown at [C3]).
--
-- Reported from play: another survivor mod pushes overhead prompts
-- into the player's game unasked - "Set a Home Base first" - and
-- narrates people who are not there:
--
--     "A living voice drops to a whisper nearby."
--     "You hear someone breathe, wait, then move again."
--
-- Those are not descriptions of anything this county knows. They fire
-- off a fifty-eight-tile scan for an actor the player cannot
-- necessarily see, on a mod whose survivors are not our survivors, and
-- the player has no way to tell that narration from ours.
--
-- [C3] found the [B45] hold had never once engaged: it tested the
-- global `KS`, and the neighbour's global is `KnoxSurvivors` - `KS` is
-- a per-file LOCAL in his tree (`local KS = KnoxSurvivors`). The hold
-- was a no-op for its whole life; every neighbour line the operator
-- saw got through because of it. The namespace is now resolved from
-- what actually exists, and this file's second job is ONE PERSON, ONE
-- MENU - superimposed, not beside (DR-015): the neighbour's own
-- per-survivor root ("<name> - Talk / Ask Along" / "<name> - Open
-- Survivor Panel") is the UI the player already knows, so it stays,
-- and this county rewrites what is INSIDE it - the county's talk and
-- tell, then his working verbs (his follow, his card, his recruitment
-- - his bodies, per DR-009) through his own public functions. SAO owns
-- whether; his execution owns how. The county adds no second person
-- menu for his people.
--
-- WHAT THIS DOES NOT DO
--
-- It does not touch his settings (`PZAPI.ModOptions` tickboxes), does
-- not write his profile tables beyond the name law (DR-014), and never
-- drives his bodies. The two prompt channels are HELD, not replaced:
-- originals kept, every held call counted, the count on the Ledger's
-- top line - a world where something was silenced must not look like
-- a world where nothing happened.

SAO = SAO or {}
SAO.Neighbours = SAO.Neighbours or {}
local Nb = SAO.Neighbours

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("neighbours", msg) end

-- [C3] The neighbour's own context menu attaches to the nearest of his
-- actors within this radius of the clicked square (his
-- findActorNearSquare); the strip below must look exactly as far as he
-- does, no further.
local NEIGHBOUR_MENU_REACH = 3.5

-- The neighbour's real namespace, resolved from what exists rather
-- than remembered: `KnoxSurvivors` is his global; `KS` is checked
-- first for older builds that exported the short alias.
function Nb.namespace()
    local short = KS
    if type(short) == "table" and type(short.IsActor) == "function" then
        return short
    end
    local full = KnoxSurvivors
    if type(full) == "table" then return full end
    return nil
end

-- Everything we have taken over, by the name it is known by in the
-- neighbour's own namespace, so `restore` is exact rather than
-- best-effort.
Nb.held = Nb.held or {}      -- label -> how many calls we have held
Nb.original = Nb.original or {}
Nb.taken = Nb.taken or false

function Nb.holdCount()
    local n = 0
    for _, c in pairs(Nb.held) do n = n + c end
    return n
end

-- The Ledger asks this; nil means there is nothing to say, and a
-- surface with nothing to say says nothing ([B33]).
function Nb.line()
    if not Nb.taken then return nil end
    local n = Nb.holdCount()
    if n <= 0 then return nil end
    return "Holding another mod's prompts: " .. n
        .. (n == 1 and " message" or " messages") .. " this session"
end

-- Give a neighbour back exactly what we took. Nothing calls this in
-- normal play; it exists because a takeover you cannot undo is a
-- takeover you cannot be honest about, and because the console can.
function Nb.restore()
    if not Nb.taken then return false end
    local ns = Nb.namespace()
    if not ns then return false end
    local ok = pcall(function()
        for label, fn in pairs(Nb.original) do
            if label == "KS.Notify" then ns.Notify = fn end
            if label == "KS.Say" then ns.Say = fn end
        end
    end)
    if ok then
        Nb.taken = false
        log("gave back " .. tostring(Nb.holdCount()) .. " held call(s)")
    end
    return ok
end

local function hold(label, current)
    Nb.original[label] = current
    Nb.held[label] = 0
    return function()
        Nb.held[label] = (Nb.held[label] or 0) + 1
        if Nb.held[label] == 1 then
            log("first " .. label .. " held - this county speaks for "
                .. "itself now")
        end
    end
end

local function take()
    -- [C40] DR-035: asked for, not assumed. This used to hold unless
    -- the switch said otherwise, which meant a fresh world with both
    -- mods installed replaced two of their functions with no one
    -- having asked for it.
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if not (sv and sv.HoldNeighbourPrompts == true) then
        log("not holding: this county touches nothing of theirs")
        return
    end
    local ns = Nb.namespace()
    if not ns then return end

    local wrapped = {}
    if type(ns.Notify) == "function" then
        ns.Notify = hold("KS.Notify", ns.Notify)
        wrapped[#wrapped + 1] = "KS.Notify"
    end
    if type(ns.Say) == "function" then
        ns.Say = hold("KS.Say", ns.Say)
        wrapped[#wrapped + 1] = "KS.Say"
    end

    if #wrapped == 0 then return end
    Nb.taken = true
    log("holding " .. table.concat(wrapped, " and ")
        .. " - the originals are kept and SAO.Neighbours.restore() "
        .. "hands them back")
end

-- ---------------------------------------------------------------------
-- [C3] One person, one menu.
-- ---------------------------------------------------------------------

-- The neighbour's actor and profile for one of this county's ks:
-- records, or nothing. The record id carries his profile id: "ks:<id>".
function Nb.profileFor(recId)
    local ns = Nb.namespace()
    if not ns or type(recId) ~= "string" then return nil, nil, ns end
    local kid = recId:match("^ks:(.+)$")
    if not kid then return nil, nil, ns end
    local actor, profile
    pcall(function()
        if ns.GetActor then actor = ns.GetActor(kid) end
        if actor and ns.GetActorProfile then
            profile = ns.GetActorProfile(actor)
        end
    end)
    return profile, actor, ns
end

-- The county's person submenu grows the neighbour's working verbs for
-- his people, driven through his own public functions - one menu,
-- SAO's, deciding WHETHER; his machinery executing HOW (DR-009: his
-- bodies are never driven by ours). Sparse on purpose.
function Nb.addPersonOptions(person, playerObj, recId)
    local profile, actor, ns = Nb.profileFor(recId)
    if not profile or not actor or not ns then return false end
    local owned = false
    pcall(function()
        owned = ns.GetPlayerKey
            and profile.owner == ns.GetPlayerKey(playerObj) or false
    end)
    local function dispatch(command)
        return function()
            pcall(function()
                if ns.DispatchSurvivorCommand then
                    ns.DispatchSurvivorCommand(playerObj, profile, command,
                        { source = "sao-person-menu" })
                end
            end)
        end
    end
    if owned then
        person:addOption("Walk with me", nil, dispatch("follow"))
        person:addOption("Wait here", nil, dispatch("hold"))
        person:addOption("Go back to your base", nil, dispatch("return"))
        if ns.OpenSurvivorCard then
            person:addOption("Their card", nil, function()
                pcall(function() ns.OpenSurvivorCard(playerObj, profile) end)
            end)
        end
    else
        if ns.Greet then
            person:addOption("Introduce yourself", nil, function()
                pcall(function() ns.Greet(playerObj, actor) end)
            end)
        end
        if profile.recruitable and profile.stance ~= "hostile"
            and ns.Recruit then
            person:addOption("Ask to come along", nil, function()
                pcall(function() ns.Recruit(playerObj, actor) end)
            end)
        end
        if ns.OfferNeededResourceToSurvivor then
            person:addOption("Offer what they need", nil, function()
                pcall(function()
                    ns.OfferNeededResourceToSurvivor(playerObj, actor)
                end)
            end)
        end
    end
    return true
end

-- [C7] Superimposed, not beside (DR-015, the operator's correction of
-- [C3]'s reading). The neighbour's per-survivor root is the UI the
-- player already knows, so it STAYS - and this county becomes what is
-- inside it. His menu attaches by proximity (nearest of his actors
-- within 3.5 tiles of the clicked square); for an adopted person the
-- county predicts the same attachment, adds no second person menu of
-- its own, retitles his root to the person (one person, one name),
-- clears his submenu, and rebuilds it: the county's talk and tell,
-- then his own working verbs through his own public functions. His
-- GENERIC root ("Knox Survivors" - notebook, base setup, field guide)
-- is his own surface and stays untouched, as do unadopted people.

local function squareOf(worldobjects)
    for _, o in ipairs(worldobjects or {}) do
        if o and o.getSquare then
            local ok, s = pcall(function() return o:getSquare() end)
            if ok and s then return s end
        end
    end
    return nil
end

-- Which of his actors his menu will attach to for this click: the
-- nearest alive within his own radius. Mirrors his findActorNearSquare
-- exactly - the county's menu skip and the superimposition both stand
-- on this one prediction.
local function nearestActorTo(sq)
    local ns = Nb.namespace()
    if not ns or type(ns.RUNTIME) ~= "table"
        or type(ns.RUNTIME.actors) ~= "table" then
        return nil, nil, ns
    end
    local sx, sy = sq:getX(), sq:getY()
    local best, bestD = nil, nil
    for _, actor in pairs(ns.RUNTIME.actors) do
        pcall(function()
            if actor:isAlive() then
                local dx, dy = actor:getX() - sx, actor:getY() - sy
                local distSq = dx * dx + dy * dy
                if distSq <= NEIGHBOUR_MENU_REACH * NEIGHBOUR_MENU_REACH
                    and (not bestD or distSq < bestD) then
                    best, bestD = actor, distSq
                end
            end
        end)
    end
    if not best then return nil, nil, ns end
    local kid = nil
    pcall(function()
        if ns.GetActorId then kid = ns.GetActorId(best) end
    end)
    return best, kid, ns
end

-- The Harness asks this before building its own person menu: will the
-- neighbour's root carry this person on this click?
-- [C40] DR-035: the same door as the absorption's. Closed - which is
-- the default - this county never rewrites another mod's menu and
-- never predicts one, so every person the player right-clicks gets
-- this county's own menu and nobody's surface is touched.
function Nb.bridgeOpen()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return sv ~= nil and sv.NeighbourBridge == true
end

function Nb.willSuperimpose(recId, worldobjects)
    if not Nb.bridgeOpen() then return false end
    local sq = squareOf(worldobjects)
    if not sq then return false end
    local actor, kid = nearestActorTo(sq)
    if not actor or not kid then return false end
    return ("ks:" .. tostring(kid)) == recId
end

local function superimposePersonRoot(playerNum, context, worldobjects)
    if not Nb.bridgeOpen() then return end
    local sq = squareOf(worldobjects)
    if not sq then return end
    local actor, kid, ns = nearestActorTo(sq)
    if not actor or not kid or not ns then return end
    local recId = "ks:" .. tostring(kid)
    local rec = SAO.Identity.get(recId)
    if not (rec and SAO.Claims.isHeld(rec)) then
        -- Not adopted yet: his person, his menu, untouched.
        return
    end
    local profile = nil
    pcall(function()
        if ns.GetActorProfile then profile = ns.GetActorProfile(actor) end
    end)
    local pname = profile and tostring(profile.name or "") or ""
    if pname == "" then return end
    local root = nil
    for _, title in ipairs({
        pname .. " - Talk / Ask Along",
        pname .. " - Open Survivor Panel",
    }) do
        root = context:getOptionFromName(title)
        if root then break end
    end
    if not root or not root.subOption then return end
    local sub = nil
    local okSub, got = pcall(function()
        return context:getSubMenu(root.subOption)
    end)
    if okSub then sub = got end
    if not sub then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    pcall(function() sub:clear() end)
    -- One person, one name: the root's label is the person, not the
    -- neighbour's verb summary.
    root.name = pname .. "..."
    sub:addOption("Talk to them", nil, function()
        pcall(function() SAO.Harness.talkTo(playerObj, recId) end)
    end)
    pcall(function()
        SAO.Harness.addTellOption(sub, playerObj, recId)
    end)
    Nb.addPersonOptions(sub, playerObj, recId)
    Nb.superimposed = (Nb.superimposed or 0) + 1
end

-- OnGameStart, not file scope: every mod's Lua is loaded by then, so
-- this does not depend on who the load order put first - and for the
-- superimposition the late registration is load-bearing (it must run
-- after the neighbour's own context handler has built his root).
Events.OnGameStart.Add(function()
    pcall(take)
    pcall(function()
        Events.OnFillWorldObjectContextMenu.Remove(superimposePersonRoot)
        Events.OnFillWorldObjectContextMenu.Add(superimposePersonRoot)
    end)
end)
