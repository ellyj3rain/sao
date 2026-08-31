-- SAO_Neighbours.lua - what this mod does about the others in the
-- load order ([B45]).
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
-- the player has no way to tell that narration from ours. The
-- operator's word for it was that it outright contradicts - and it
-- does: two systems describing the same street to the same person,
-- disagreeing, both speaking in the game's own voice.
--
-- Both channels are one function each. `KS.Notify` writes the halo
-- note over the player; `KS.Say` puts words over an actor. The camp
-- signs, the status prompts, and the dialogue captions all leave
-- through those two.
--
-- WHAT THIS DOES NOT DO
--
-- It does not touch his settings. He ships three tickboxes through the
-- engine's own `PZAPI.ModOptions` - Show Survivor Dialogue Captions,
-- Show Status Notifications, Show Passive Camp Signs - and a player
-- who turns those off gets the same silence with no code from us at
-- all. Reaching in to flip them would leave his options screen saying
-- one thing while the game did another, which is worse than the
-- problem.
--
-- So: the two functions are HELD, not replaced. The originals are kept
-- and handed back on request, every held call is counted, and the
-- count reaches the Ledger's top line - because the whole hazard of
-- suppression is that its result is an ABSENCE, and this project has
-- now found the same shape at [B33], [B42], [B42] and [B44]. A
-- world where something was silenced must not look like a world where
-- nothing happened.

SAO = SAO or {}
SAO.Neighbours = SAO.Neighbours or {}
local Nb = SAO.Neighbours

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("neighbours", msg) end

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
    local ok = pcall(function()
        for label, fn in pairs(Nb.original) do
            if label == "KS.Notify" then KS.Notify = fn end
            if label == "KS.Say" then KS.Say = fn end
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
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if sv and sv.HoldNeighbourPrompts == false then
        log("not holding: the sandbox screen says let them through")
        return
    end
    if type(KS) ~= "table" then return end

    local wrapped = {}
    if type(KS.Notify) == "function" then
        KS.Notify = hold("KS.Notify", KS.Notify)
        wrapped[#wrapped + 1] = "KS.Notify"
    end
    if type(KS.Say) == "function" then
        KS.Say = hold("KS.Say", KS.Say)
        wrapped[#wrapped + 1] = "KS.Say"
    end

    if #wrapped == 0 then return end
    Nb.taken = true
    log("holding " .. table.concat(wrapped, " and ")
        .. " - the originals are kept and SAO.Neighbours.restore() "
        .. "hands them back")
end

-- OnGameStart, not file scope: every mod's Lua is loaded by then, so
-- this does not depend on who the load order put first.
Events.OnGameStart.Add(function() pcall(take) end)
