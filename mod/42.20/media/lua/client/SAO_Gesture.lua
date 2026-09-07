-- SAO_Gesture - the county's gestures ([C35], DR-034).
-- ---------------------------------------------------------------------------
-- The operator named Week One's art and then Lifestyle: Hobbies as the
-- existing art the county could wear, and ruled that it crosses copied
-- into SAO with the credited authors' permission (CREDITS.md). The
-- files live under media/anims_X and media/sound; the bindings are
-- SAO's own animation-set nodes, conditioned on variables only this
-- module sets, so nothing here overlaps another mod's nodes.
--
-- A gesture is a timed action that carries one animation variable for
-- a while and nothing else. It rides the engine's own path: a timed
-- action puts the body in the actions state, the action's variable
-- selects the node, and the queue ends it. Every entry point below is
-- a MOMENT the county already has - a meeting's verdict, a voice
-- event, the evening seat, the porch tune - so a gesture is never
-- authored on its own; it is what a decision already made looks like.
--
-- The seated variants ride the engine's own sitting state instead:
-- a variable set when the evening seat begins and cleared when the
-- person stands, read by nodes in the sitting loop.

SAO = SAO or {}
SAO.Gesture = SAO.Gesture or {}
local G = SAO.Gesture

local function log(msg) SAO.Log.line("GESTURE", msg) end

-- ---------------------------------------------------------------------------
-- The action.
-- ---------------------------------------------------------------------------
SAOGestureAction = ISBaseTimedAction:derive("SAOGestureAction")

function SAOGestureAction:isValid()
    return self.character ~= nil and not self.character:isDead()
end

function SAOGestureAction:update() end

function SAOGestureAction:start()
    -- The variable the SAO_* nodes in AnimSets/player/actions read.
    self:setAnimVariable("SAOGesture", self.gesture)
end

function SAOGestureAction:stop()
    ISBaseTimedAction.stop(self)
end

function SAOGestureAction:perform()
    ISBaseTimedAction.perform(self)
end

function SAOGestureAction:new(character, gesture, ticks)
    local o = ISBaseTimedAction.new(self, character)
    o.gesture = gesture
    o.maxTime = ticks
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    return o
end

-- ---------------------------------------------------------------------------
-- The vocabulary: node names (the file's name without its Bob_ prefix).
-- Every name here has a node under AnimSets/player/actions and a file
-- under anims_X/Bob; Border 109 holds the three to each other.
-- ---------------------------------------------------------------------------
G.LISTEN = {
    positive = { "Converse_Agreeing", "Converse_AgreeingHandGesture", "Converse_HeadNod" },
    neutral  = { "Converse_Listening01", "Converse_Listening02",
                 "Converse_Acknowledging", "Converse_HeadNod" },
    negative = { "Converse_Angry01", "Converse_Angry02", "Converse_Dismissive01",
                 "Converse_Dismissive02", "Converse_ShakeHeadNo", "Converse_LookingDown" },
}
G.SPEAK = { "Converse_ArmForward", "Converse_ArmGesture" }
G.GRIEF = { "Converse_Agony", "Converse_LookingDown" }
G.FRUSTRATED = { "ConverseEnd_Frustrated01", "ConverseEnd_Frustrated02",
                 "ConverseEnd_Frustrated03", "ConverseEnd_Frustrated04" }
G.TEACH = { "Converse_ArmGesture" }
G.BOW = { "Converse_InformalBow" }
G.SPENT = { "Converse_Yawn" }
G.SERVE = { "WaiterServing" }
G.GUITAR = { "PlayGuitarDefault", "PlayGuitarExperiencedA", "PlayGuitarExperiencedB",
             "PlayGuitarProficientA", "PlayGuitarAcoustic" }
G.HARMONICA = { "PlayHarmonicaDefault", "PlayHarmonicaExperiencedA",
                "PlayHarmonicaProficientA" }
G.DANCES = { "DancingFreestyleA", "DancingFreestyleB", "DancingFreestyleC",
             "DancingFreestyleD", "DancingFreestyleE", "DancingFreestyleF",
             "DancingFreestyleG", "DancingFreestyleH", "DancingFreestyleI",
             "DancingSideStep", "DancingHandWave", "DancingHandsInAir",
             "DancingMoveAround", "DancingShake", "DancingRunningMan",
             "DancingMacarena" }
-- The seats: nodes under AnimSets/player/sitonground-sitting, read
-- while the engine's own sitting state runs.
G.SEATS = { "IsSittingLoop", "IsSittingLoopArmsCrossed", "IsSittingLoopHandsOnFace",
            "IsSittingLoopHandsOnThigh", "IsSittingLoopLeanForward_Pensive",
            "IsSittingLoopLeanForward_CleanTear", "IsSittingLoopLegAbove",
            "IsSittingLoopHandsOnThigh_SlightLeanForward" }

-- How long, in the action's ticks: the Hobbies mod's own timings for
-- its talking table (60 a gesture, 30 a sharp one), longer for a tune
-- and a dance.
local TICKS = { gesture = 60, sharp = 30, serve = 90, tune = 600, dance = 300 }

local function pick(list, id, salt)
    if not list or #list == 0 then return nil end
    local tick = 0
    pcall(function() tick = SAO.Controller.tick() end)
    return list[(SAO.Hash.of(id, salt .. ":" .. tostring(math.floor(tick / 60))) % #list) + 1]
end

-- Can this body carry a gesture now? Not dead, not busy with a real
-- action, not in a vehicle, not asleep.
local function free(body)
    if not body then return false end
    local ok, blocked = pcall(function()
        if body:isDead() then return true end
        if body:getVehicle() ~= nil then return true end
        if body:isAsleep() then return true end
        return false
    end)
    if not ok or blocked then return false end
    if SAO.Needs and SAO.Needs.busy and SAO.Needs.busy(body) then return false end
    return true
end

-- Queue one gesture. Returns true when it was queued.
function G.play(id, body, name, ticks)
    if not name or not free(body) then return false end
    local ok = pcall(function()
        ISTimedActionQueue.add(SAOGestureAction:new(body, name, ticks or TICKS.gesture))
    end)
    if ok then log(tostring(id) .. " " .. name) end
    return ok
end

-- ---------------------------------------------------------------------------
-- The moments.
-- ---------------------------------------------------------------------------

-- The meeting ([B9] temper, census C5 politick): the speaker gestures
-- as they speak; the listener answers the verdict - warm, sharp, or
-- neither - the way Hobbies' own talking table has a listener answer
-- a mood.
function G.meet(id, body, otherId, otherBody, verdict, warm, sharp)
    G.play(id, body, pick(G.SPEAK, id, "speak"), TICKS.gesture)
    local mood = "neutral"
    if verdict == "aligned" or (warm or 1) > (sharp or 1) + 0.2 then mood = "positive"
    elseif verdict == "opposed" or (sharp or 1) > (warm or 1) + 0.2 then mood = "negative" end
    local ticks = (mood == "negative") and TICKS.sharp or TICKS.gesture
    return G.play(otherId, otherBody, pick(G.LISTEN[mood], otherId, "listen"), ticks)
end

-- The voice's events, which are the county's moments already
-- (SAO_Voice raises them); a gesture is what the moment looks like.
-- "emote:" entries are the engine's own emotes (playEmote), the rest
-- are this module's lists; "sound:" entries play a sound instead.
G.EVENTS = {
    share = "serve", thanks = "positive", aid = "positive", promiseKept = "positive",
    goodWord = "positive", settle = "positive", bonded = "positive", pact = "positive",
    peace = "positive", creedAligned = "positive", nurse = "positive",
    warned = "speak", takePoint = "speak", lessonTold = "teach", teaching = "teach",
    grief = "grief", feud = "negative", warpath = "negative", grudgeTold = "negative",
    creedOpposed = "negative", bittenWary = "negative", colors = "negative",
    grumble = "frustrated", unanswered = "frustrated", workDoubted = "frustrated",
    noRoom = "frustrated", stepUp = "bow", parting = "emote:wavebye",
    reunion = "emote:wavehi", companion = "emote:wavehi", sick = "sound:cough",
}
local LISTS = {
    positive = function(id) return pick(G.LISTEN.positive, id, "event") end,
    negative = function(id) return pick(G.LISTEN.negative, id, "event") end,
    speak = function(id) return pick(G.SPEAK, id, "event") end,
    teach = function(id) return pick(G.TEACH, id, "event") end,
    grief = function(id) return pick(G.GRIEF, id, "event") end,
    frustrated = function(id) return pick(G.FRUSTRATED, id, "event") end,
    bow = function(id) return pick(G.BOW, id, "event") end,
    serve = function(id) return pick(G.SERVE, id, "event") end,
}

function G.onEvent(id, event, tick)
    local what = G.EVENTS[event]
    if not what then return false end
    local body = SAO.Body.get(id)
    if not body then return false end
    local kind, arg = string.match(what, "^(%a+):(%a+)$")
    if kind == "emote" then
        if not free(body) then return false end
        local ok = pcall(function() body:playEmote(arg) end)
        if ok then log(tostring(id) .. " " .. arg) end
        return ok
    elseif kind == "sound" then
        if arg == "cough" then return G.cough(body) end
        return false
    end
    local list = LISTS[what]
    if not list then return false end
    local ticks = (what == "negative") and TICKS.sharp or (what == "serve") and TICKS.serve or TICKS.gesture
    return G.play(id, body, list(id), ticks)
end

-- The evening seat ([B19]): how this person sits is who they are and
-- what they carry - a lived loss sits with a hand to the face, the low
-- sit with their head down, the disciplined with arms crossed, the
-- nervous lean forward, and the rest as the hash has them.
function G.seat(id, body)
    if not body then return nil end
    local seat = nil
    pcall(function()
        local rec = SAO.Identity.get(id)
        local meta = rec and rec.lessonMeta or nil
        for _, key in ipairs({ "nothing-left-to-lose", "never-again-that-close" }) do
            local m = meta and meta[key]
            if m and m.src == "lived" then seat = "IsSittingLoopLeanForward_CleanTear" end
        end
    end)
    if not seat then
        pcall(function()
            if SAO.Conditions.has(id, "depression") then seat = "IsSittingLoopHandsOnFace" end
        end)
    end
    if not seat then
        local t = nil
        pcall(function() t = SAO.Disposition.traits(id) end)
        if t and t.discipline > 0.6 then seat = "IsSittingLoopArmsCrossed"
        elseif t and t.nerve < 0.4 then seat = "IsSittingLoopLeanForward_Pensive"
        else
            seat = pick({ "IsSittingLoop", "IsSittingLoopHandsOnThigh", "IsSittingLoopLegAbove",
                          "IsSittingLoopHandsOnThigh_SlightLeanForward" }, id, "seat")
        end
    end
    local ok = pcall(function() body:setVariable("SAOSeat", seat) end)
    if ok then log(tostring(id) .. " sits: " .. tostring(seat)) end
    return ok and seat or nil
end

function G.standUp(body)
    if not body then return false end
    return pcall(function() body:clearVariable("SAOSeat") end)
end

-- The porch tune ([A19]/[B21]): the instrument SAO already names.
function G.playInstrument(id, body, what)
    local list = (what == "harmonica") and G.HARMONICA or G.GUITAR
    return G.play(id, body, pick(list, id, "tune"), TICKS.tune)
end

-- Those already close when the tune starts: half dance, the rest clap.
function G.dance(id, body)
    return G.play(id, body, pick(G.DANCES, id, "dance"), TICKS.dance)
end

function G.clap(body)
    if not body then return false end
    local n = 1
    pcall(function() n = (SAO.Hash.of(tostring(body:getModData().SAOPersonId or "x"),
        "clap:" .. tostring(SAO.Controller.tick())) % 13) + 1 end)
    return pcall(function() body:playSound("SAOClap" .. n) end)
end

-- A cough, in the voice of the body's sex.
function G.cough(body)
    if not body then return false end
    local female = false
    pcall(function() female = body:isFemale() == true end)
    local n = 1
    pcall(function() n = (SAO.Hash.of(tostring(body:getModData().SAOPersonId or "x"),
        "cough:" .. tostring(SAO.Controller.tick())) % 4) + 1 end)
    return pcall(function() body:playSound((female and "SAOCoughF" or "SAOCoughM") .. n) end)
end

log("gesture module loaded (the county's gestures, seats, tunes, dances, claps and coughs)")

return G
