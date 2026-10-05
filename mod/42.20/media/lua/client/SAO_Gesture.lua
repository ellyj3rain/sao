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
if G.resetInstruments then G.resetInstruments() end
-- Only play() owns optional cosmetics. CPR's separate native chain is not
-- registered here and cannot be retired by a conflict handoff.
local optional = {}
local yielding = {}
local soundCleanup = {}
local finishInstrument, startInstrument, updateInstrument

local function stopOwnedSound(state)
    if not state.emitter or not state.sound or state.sound == 0 then return true end
    local ok, stopped = pcall(function()
        state.emitter:stopSound(state.sound)
        return state.emitter:isPlaying(state.sound) == false
    end)
    ok = ok and stopped == true
    return ok
end

local function currentOwner(id, body, rec, token)
    local current = SAO.Identity and SAO.Identity.get(id)
    if not current or current ~= rec or current.dead or current.bodyOwner
        or current.zaoTransferPending or current.crossedTransferPending
        or not body or SAO.Body.get(id) ~= body then return false end
    local data = body:getModData()
    return data and data.SAOPersonId == id and data.SAOExternalOwner == nil
        and data.ZAOOwned ~= true and data.SAOExternalToken == token
        and current.bodyOwnerToken == token and not body:isDead()
end

local function optionalOwner(action, work)
    return work and action.character == work.body
        and currentOwner(work.id, work.body, work.rec, work.token)
end

-- Retiring a response releases its references, not somebody's native action.
function G.releaseConflict(id, body)
    local work = yielding[id]
    if not work or work.body ~= body then return false end
    yielding[id] = nil
    work.action = nil
    return true
end

-- A pending cancellation can outlive the last decision (death, transfer or
-- removal). Poll only those handbacks; do not wait for another appraisal.
local function retireHandbacks()
    -- Exact sound handles remain owned only while this person/body binding does.
    -- On loss of that binding an unresolved cleanup remains unknown in the
    -- terminal receipt; its native references retire, without touching a successor.
    for state, owner in pairs(soundCleanup) do
        if not currentOwner(owner.id, owner.body, owner.rec, owner.token) then soundCleanup[state] = nil
        else
            local ok, playing = pcall(function() return state.emitter:isPlaying(state.sound) end)
            if ok and (playing == false or stopOwnedSound(state)) then soundCleanup[state] = nil end
        end
    end
    for action, work in pairs(optional) do
        if not optionalOwner(action, work)
            or ISTimedActionQueue.hasAction(action) ~= true
                and not (action.action and work.body:getCharacterActions():contains(action.action)) then
            optional[action] = nil
            work.retired = true
            if work.instrument then finishInstrument(action, work, "interrupted") end
            if yielding[work.id] ~= work then work.action = nil end
        end
    end
    for id, work in pairs(yielding) do
        local action = work.action
        if not action or not optionalOwner(action, work)
            or ISTimedActionQueue.hasAction(action) ~= true
                and not (action.action and work.body:getCharacterActions():contains(action.action)) then
            G.releaseConflict(id, work.body)
        end
    end
end
Events.OnTick.Add(retireHandbacks)

local function log(msg) SAO.Log.line("GESTURE", msg) end

-- ---------------------------------------------------------------------------
-- The action.
-- ---------------------------------------------------------------------------
SAOGestureAction = ISBaseTimedAction:derive("SAOGestureAction")

function SAOGestureAction:isValid()
    if self.character == nil or self.character:isDead() then return false end
    if self.requiredItem then
        if not SAO.Needs.ownsRecoveryBody(self.personId, self.character)
            or self.character:getModData().SAOExternalToken ~= self.bodyToken then return false end
        local items = SAOJavaBridge:privateCarriedItems(self.character)
        for i = 0, items:size() - 1 do
            if items:get(i) == self.requiredItem then return true end
        end
        return false
    end
    return true
end

function SAOGestureAction:update()
    if self.requiredItem and not self:isValid() then self:forceStop() end
end

function SAOGestureAction:start()
    if self.requiredItem and not self:isValid() then self:forceStop(); return end
    -- The variable the SAO_* nodes in AnimSets/player/actions read.
    self:setAnimVariable("SAOGesture", self.gesture)
end

local function ownsMaterialQueue(action, work)
    if work and (work.retired or not optionalOwner(action, work)
        or ISTimedActionQueue.hasAction(action) ~= true) then return false end
    if work then
        local native = action.character:getCharacterActions()
        if not native:isEmpty() and not (action.action and native:contains(action.action)) then return false end
    end
    return not action.requiredItem or SAO.Needs.ownsRecoveryBody(action.personId, action.character)
        and action.bodyToken == action.character:getModData().SAOExternalToken
        and ISTimedActionQueue.hasAction(action) == true
end
local function stopGesture(self, work)
    if not ownsMaterialQueue(self, work) then return end
    if work and work.instrument then finishInstrument(self, work, "interrupted") end
    if work then
        optional[self] = nil
        work.retired = true
        if yielding[work.id] ~= work then work.action = nil end
    end
    if self.planReceipt and SAO.ProceduralPlanning then
        SAO.ProceduralPlanning.recordResult(self.planReceipt.actorId,
            self.planReceipt.purposeId, { owner = self.planReceipt.owner,
                token = self.planReceipt.token, status = "interrupted",
                reason = work and work.cancelled and "gesture-yielded-to-conflict" or "gesture-interrupted" })
    end
    if work then
        -- Same exact-action handback as Handover. The vanilla base stop resets
        -- the entire shared queue, including actions admitted after this one.
        local queue = ISTimedActionQueue.queues[self.character]
        if queue.current == self then queue:onCompleted(self)
        else queue:removeFromQueue(self) end
    else ISBaseTimedAction.stop(self) end
end
function SAOGestureAction:stop() stopGesture(self, nil) end

local function performGesture(self, work)
    if not ownsMaterialQueue(self, work) then return end
    if work and work.cancelled then self:stop(); return end
    if work and work.instrument then
        if not work.instrument.ended or not self:isValid() then self:stop(); return end
        finishInstrument(self, work, "completed")
    end
    if work then optional[self] = nil;work.retired = true;work.action = nil end
    ISBaseTimedAction.perform(self)
    if self.planReceipt and SAO.ProceduralPlanning then
        local accepted = SAO.ProceduralPlanning.recordResult(
            self.planReceipt.actorId, self.planReceipt.purposeId,
            { owner = self.planReceipt.owner, token = self.planReceipt.token,
                status = "completed" })
        local other = accepted and not (work and work.instrument) and self.planReceipt.rewardWith or nil
        if other and SAO.Standing then
            SAO.Standing.adjustTrust(self.planReceipt.actorId, other, 0.01)
            SAO.Standing.adjustTrust(other, self.planReceipt.actorId, 0.01)
        end
    end
end
function SAOGestureAction:perform() performGesture(self, nil) end

function SAOGestureAction:new(character, gesture, ticks, planReceipt)
    local o = ISBaseTimedAction.new(self, character)
    o.gesture = gesture
    o.maxTime = ticks
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.planReceipt = planReceipt
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
-- [C119] The bard's own instrument: the county picks up whatever the
-- world holds (Population's instrument take reads the engine's own
-- InstrumentWeapon category), and until now every flute and sax
-- played the guitar's clip. The carried type names the clip; the
-- types with no clip of their own keep the guitar list as before.
-- The clips are Week One's, copied with permission (CREDITS.md).
G.BARD = {
    ["Base.Flute"] = "BardFlute",
    ["Base.Saxophone"] = "BardSaxophone",
    ["Base.Trumpet"] = "BardTrumpet",
    ["Base.Violin"] = "BardViolin",
    ["Base.GuitarElectricBass"] = "BardGuitarBass",
    ["Base.GuitarElectric"] = "BardGuitarElectric",
}
G.DANCES = { "DancingFreestyleA", "DancingFreestyleB", "DancingFreestyleC",
             "DancingFreestyleD", "DancingFreestyleE", "DancingFreestyleF",
             "DancingFreestyleG", "DancingFreestyleH", "DancingFreestyleI",
             "DancingSideStep", "DancingHandWave", "DancingHandsInAir",
             "DancingMoveAround", "DancingShake", "DancingRunningMan",
             "DancingMacarena",
             -- [C119] Week One's four, joining the porch-tune crowd
             -- through the same pick every dance already uses.
             "DancingWeekOne1", "DancingWeekOne2",
             "DancingWeekOne3", "DancingWeekOne4" }
-- [C119] The trade's shape and the crowd's: the cashier at the
-- counter ([C113]'s trade ground), the protest when two dissenters
-- stand together ([A25]'s policy grumble grown a body). Week One's
-- clips, copied with permission (CREDITS.md); a gesture is never
-- authored on its own - each rides a decision the county already
-- made.
G.CASHIER = { "Cashier" }
G.PROTEST = { "Protest1", "Protest2", "Protest3" }
G.CPR = { "StartCpr", "LoopCpr", "EndCpr" }
-- [C120] The child's throw: a kid with a ball and somebody to throw it
-- to. Week One's clip, copied with permission (CREDITS.md); it was
-- orphaned art in their own mod, bound by nothing there, and the
-- county binds it the way it bound the cashier - at a moment it
-- already has.
G.BALL = { "BallThrow" }
-- The seats: nodes under AnimSets/player/sitonground-sitting, read
-- while the engine's own sitting state runs.
G.SEATS = { "IsSittingLoop", "IsSittingLoopArmsCrossed", "IsSittingLoopHandsOnFace",
            "IsSittingLoopHandsOnThigh", "IsSittingLoopLeanForward_Pensive",
            "IsSittingLoopLeanForward_CleanTear", "IsSittingLoopLegAbove",
            "IsSittingLoopHandsOnThigh_SlightLeanForward" }

-- How long, in the action's ticks: the Hobbies mod's own timings for
-- its talking table (60 a gesture, 30 a sharp one), longer for a tune
-- and a dance.
local TICKS = { gesture = 60, sharp = 30, serve = 90, tune = 600, dance = 300,
                -- [C119] The medic's three-stage machine: the kneel,
                -- the work, the letting-go. The loop holds long
                -- enough to be real work on a body.
                cprStart = 60, cprLoop = 300, cprEnd = 60,
                -- [C120] A throw: a gesture's length, the arm's own.
                ball = 60 }

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
        -- A physical work owner can be between native actions. A social
        -- gesture must not fill that gap and cancel the admitted operation.
        local data = body:getModData()
        local id = data and data.SAOPersonId
        local rec = id and SAO.Identity and SAO.Identity.get(tostring(id))
        if id and SAO.ConflictResponse and SAO.ConflictResponse.gesturePriority
            and SAO.ConflictResponse.gesturePriority(tostring(id), body) then return true end
        if rec then
            if rec.cookingWork ~= nil or rec.worldSourceReservation ~= nil then return true end
            if rec.bodyOwner ~= nil or rec.zaoTransferPending ~= nil
                or rec.crossedTransferPending ~= nil then return true end
        end
        if data and (data.SAOExternalOwner ~= nil or data.ZAOOwned == true) then return true end
        local queue = ISTimedActionQueue and ISTimedActionQueue.queues
            and ISTimedActionQueue.queues[body]
        if queue and type(queue.queue) == "table" and #queue.queue > 0 then return true end
        return false
    end)
    if not ok or blocked then return false end
    if SAO.Needs and SAO.Needs.busy and SAO.Needs.busy(body) then return false end
    return true
end

-- Queue one gesture. Returns true when it was queued.
local function queueGesture(id, body, name, ticks, planReceipt, requiredItem, instrument, purposeId)
    if not name or not free(body) then return false end
    local rec = SAO.Identity and SAO.Identity.get(id)
    local token = body:getModData().SAOExternalToken
    if not currentOwner(id, body, rec, token) then return false end
    if instrument then
        for _, owner in pairs(soundCleanup) do
            if owner.body == body and currentOwner(owner.id, owner.body, owner.rec, owner.token) then return false end
        end
    end
    local action = SAOGestureAction:new(body, name, ticks or TICKS.gesture, planReceipt)
    local work = {id=id,body=body,rec=rec,token=token,action=action}
    -- The action owns its late-callback tombstone. Kahlua's table metatable
    -- does not implement weak collection; the live registry retires explicitly.
    action.stop = function(self) if self == action then stopGesture(self, work) end end
    action.perform = function(self) if self == action then performGesture(self, work) end end
    if requiredItem then
        action.requiredItem, action.personId = requiredItem, id
        action.bodyToken = body:getModData().SAOExternalToken
        if not action:isValid() then return false end
    end
    if instrument then
        local sequence = G.nextInstrumentSequence(id)
        local admitted = SAO.History.countyHours()
        if not sequence or type(admitted) ~= "number" or admitted ~= admitted
            or admitted < 0 or admitted == math.huge then return false end
        rec.instrumentSequence = sequence
        work.instrument = { capability = instrument, item = requiredItem,
            sequence = sequence, workId = "instrument:" .. id .. ":" .. tostring(sequence),
            admittedAtHours = admitted, prepared = true }
        local baseValid = action.isValid
        action.isValid = function(self)
            if self ~= action or not optionalOwner(self, work) or not baseValid(self) then return false end
            local current = SAO.Needs.instrumentAvailable(id, body, requiredItem)
            return current and current.sound == instrument.sound and current.radius == instrument.radius or false
        end
        action.start = function(self) if self == action then startInstrument(self, work) end end
        action.update = function(self) if self == action then updateInstrument(self, work) end end
    end
    optional[action] = work
    if instrument and purposeId then
        local planner = SAO.ProceduralPlanning
        if not planner or not planner.admitInstrument or not planner.admitInstrument(id, purposeId, work.instrument.workId) then
            optional[action] = nil; work.retired = true; work.action = nil
            return false
        end
    end
    if instrument then work.instrument.prepared = false end
    local ok = pcall(function()
        ISTimedActionQueue.add(action)
    end)
    ok = ok and ISTimedActionQueue.hasAction(action) == true
    if instrument then work.instrument.queueAdmitted = ok end
    if not ok and instrument then
        finishInstrument(action, work, "interrupted")
        if ISTimedActionQueue.hasAction(action) == true then action:stop() end
    end
    if not ok then optional[action] = nil;work.retired = true;work.action = nil end
    if ok then log(tostring(id) .. " " .. name) end
    return ok
end

function G.play(id, body, name, ticks, planReceipt, requiredItem)
    return queueGesture(id, body, name, ticks, planReceipt, requiredItem)
end

-- A request from the current selected response, followed by native handback.
-- Neither a gesture type string nor a new decision can authorize another
-- person's action. Returning true never means a conflict action succeeded.
function G.yieldToConflict(id, body, decision)
    if not SAO.ConflictResponse or not SAO.ConflictResponse.gesturePriority(id,body,decision) then return false end
    local state = body:getCurrentStateName()
    if body:isClimbing() or state == "ClimbOverFenceState" or state == "ClimbThroughWindowState"
        or state == "SmashWindowState" or tostring(state):find("OpenWindowState",1,true) then return false end
    local work = yielding[id]
    if work and (work.body ~= body or not optionalOwner(work.action,work)) then
        yielding[id] = nil
        work = nil
    end
    if work and ISTimedActionQueue.hasAction(work.action) ~= true
        and not (work.action.action and body:getCharacterActions():contains(work.action.action)) then
        yielding[id] = nil
        work.action = nil
        work = nil
    end
    if not work then
        local queue = ISTimedActionQueue.queues and ISTimedActionQueue.queues[body]
        local action = queue and queue.queue and queue.queue[1]
        work = action and optional[action]
        if not work then return true end
        if work.id ~= id or not optionalOwner(action,work) then return false end
        work.action = action
        yielding[id] = work
    end
    local action = work.action
    if work.body ~= body or not optionalOwner(action,work) then return false end
    local function present()
        return ISTimedActionQueue.hasAction(action) == true,
            action.action and body:getCharacterActions():contains(action.action) == true
    end
    local queued, native = present()
    work.cancelled = true
    if native then
        if not work.stopIssued and not work.retired then
            local ok = pcall(function() action:forceStop() end)
            if ok then work.stopIssued = true end
        end
    elseif queued then action:stop() end
    queued, native = present()
    if queued or native then return false end
    yielding[id] = nil
    work.action = nil
    return true
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
    -- [C37] a word given: taken, taken grudgingly, refused.
    orderYes = "positive", orderGrudging = "frustrated", orderNo = "negative",
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
-- [C119] The carried type is read when there is one: a bard with a
-- flute plays the flute's clip, not the guitar's - the clip the
-- county now owns because the world actually holds the instrument.
-- `what` still names the tune's sound and label (banjo, harmonica,
-- the rest); only the SHAPE follows the carried thing.
G.pendingPlanReceipt = nil

function G.planReceipt(id, purposeId, rewardWith)
    if type(id) ~= "string" or type(purposeId) ~= "string" then return false end
    G.pendingPlanReceipt = { actorId = id, purposeId = purposeId,
        owner = "SAO.Gesture", token = "leisure:performed",
        rewardWith = rewardWith }
    return true
end

local function takePlanReceipt(id)
    local receipt = G.pendingPlanReceipt
    G.pendingPlanReceipt = nil
    return receipt and receipt.actorId == id and receipt or nil
end

function G.playInstrument(id, body, what, itemType, requiredItem, purposeId)
    local receipt = takePlanReceipt(id)
    local capability = SAO.Needs and SAO.Needs.instrumentAvailable(id, body, requiredItem)
    if not capability or requiredItem:getFullType() ~= itemType then return false end
    return queueGesture(id, body, "PlayHarmonicaDefault", TICKS.tune, receipt, requiredItem, capability, purposeId)
end

-- The native Callout item path emits one sound and one world stimulus. Keeping
-- the exact emitter handle makes this action's interruption independently owned.
finishInstrument = function(action, work, status)
    local state = work.instrument
    if not state or state.terminal then return end
    state.terminal = true
    local stopped = stopOwnedSound(state)
    if not stopped then status = "interrupted" end
    if not currentOwner(work.id, work.body, work.rec, work.token) then return end
    if not stopped then
        soundCleanup[state] = { id = work.id, body = work.body, rec = work.rec, token = work.token }
    end
    local now = SAO.History.countyHours()
    if type(now) ~= "number" or now ~= now or now == math.huge or now < 0 then return end
    local rec = work.rec
    rec.instrumentOutcomes = type(rec.instrumentOutcomes) == "table" and rec.instrumentOutcomes or {}
    rec.instrumentOutcomes[#rec.instrumentOutcomes + 1] = { actorId = work.id, sequence = state.sequence,
        workId = state.workId, bodyToken = work.token, soundHandle = state.sound,
        bodyGenerationKnown = type(work.token) == "string" and work.token ~= "",
        itemId = tostring(state.item:getID()), itemType = state.item:getFullType(),
        verb = state.capability.verb, status = status, atHours = now,
        admittedAtHours = state.admittedAtHours, startedAtHours = state.startedAtHours,
        endedAtHours = state.endedAtHours, soundEnded = state.ended == true,
        queueAdmitted = state.queueAdmitted == true,
        cleanupPending = not stopped,
        soundEmitted = state.heardPlaying == true, worldSoundEmitted = state.worldSound == true,
        occurrence = state.occurrence }
    while #rec.instrumentOutcomes > 16 do table.remove(rec.instrumentOutcomes, 1) end
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeInstrumentOutcome then
        SAO.ProceduralPlanning.consumeInstrumentOutcome(work.id, state.sequence)
    end
    if SAO.Cognition and SAO.Cognition.instrumentOutcome then
        SAO.Cognition.instrumentOutcome(work.id, state.sequence)
    end
end

startInstrument = function(action, work)
    local state = work.instrument
    if state.started or state.terminal then return end
    if not action:isValid() then action:forceStop(); return end
    state.queueAdmitted = ISTimedActionQueue.hasAction(action) == true
        and action.action ~= nil and action.character:getCharacterActions():contains(action.action)
    state.started = true
    state.startedAtHours = SAO.History.countyHours()
    local ok = pcall(function()
        action:setAnimVariable("SAOGesture", action.gesture)
        action:setOverrideHandModels(state.item, nil)
        state.emitter = action.character:getEmitter()
        state.sound = action.character:playSound(state.capability.sound)
        if not state.sound or state.sound == 0 then return end
        local body, radius = action.character, state.capability.radius
        state.worldSound = getWorldSoundManager():addSound(body,
            math.floor(body:getX()), math.floor(body:getY()), math.floor(body:getZ()),
            radius, radius, false, 0, 1, false, true, false, false, true)
        local emitted = state.worldSound
        state.worldSound = emitted ~= nil and emitted ~= false
        if emitted then
            -- Missing native occurrence evidence leaves solo sound valid, sharing unknown.
            local bound, occurrence = pcall(function()
                return SAOJavaBridge:bindInstrumentOccurrence(body, emitted, state.workId)
            end)
            if bound and type(occurrence) == "table" and occurrence.schema == "sao.instrument-occurrence/1"
                and occurrence.actorId == work.id and occurrence.workId == state.workId then
                state.occurrence = occurrence
            end
        end
    end)
    if not ok or not state.worldSound then
        finishInstrument(action, work, "interrupted")
        action:forceStop()
    end
end

updateInstrument = function(action, work)
    local state = work.instrument
    if state.terminal then return end
    if not action:isValid() then action:forceStop(); return end
    if not state.started or not state.worldSound then return end
    local ok, playing = pcall(function() return state.emitter:isPlaying(state.sound) end)
    if not ok or type(playing) ~= "boolean" then finishInstrument(action, work, "interrupted"); action:forceStop(); return end
    if playing then state.heardPlaying = true
    elseif state.heardPlaying then
        state.ended = true; state.endedAtHours = SAO.History.countyHours(); action:forceComplete()
    end
end

function G.nextInstrumentSequence(id)
    local rec = SAO.Identity and SAO.Identity.get(id)
    if not rec then return nil end
    local sequence = rec.instrumentSequence or 0
    if type(sequence) ~= "number" or sequence < 0 or sequence >= 9007199254740991
        or sequence ~= math.floor(sequence) then return nil end
    return sequence + 1
end

function G.instrumentWork(id)
    for action, work in pairs(optional) do
        if work.id == id and work.instrument and not work.instrument.terminal
            and optionalOwner(action, work) and (work.instrument.prepared
                or ISTimedActionQueue.hasAction(action) == true
                or action.action and work.body:getCharacterActions():contains(action.action)) then
            local state = work.instrument
            return { actorId = id, workId = state.workId, sequence = state.sequence,
                itemId = tostring(state.item:getID()), itemType = state.item:getFullType(),
                verb = state.capability.verb, bodyToken = work.token,
                bodyGenerationKnown = type(work.token) == "string" and work.token ~= "",
                admittedAtHours = state.admittedAtHours,
                queueAdmitted = state.queueAdmitted == true,
                status = state.prepared and "prepared" or state.started and "started" or "admitted" }
        end
    end
end

function G.instrumentOutcome(id, identity)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local rows = rec and rec.instrumentOutcomes
    local row
    if type(rows) == "table" then
        for i = #rows, 1, -1 do
            local candidate = rows[i]
            if type(candidate) == "table" and (identity == nil or candidate.sequence == identity
                or candidate.workId == identity) then row = candidate; break end
        end
    end
    if type(row) ~= "table" or row.actorId ~= id then return nil end
    local out = {}; for key, value in pairs(row) do
        if key == "occurrence" and type(value) == "table" then
            local copy = {}; for field, scalar in pairs(value) do copy[field] = scalar end; out[key] = copy
        else out[key] = value end
    end
    return out
end

-- Canonical exact work occurrence only; never infer who heard it.
function G.instrumentOccurrence(id, workId)
    if type(workId) ~= "string" then return nil end
    local occurrence
    for action, work in pairs(optional) do
        if work.id == id and work.instrument and work.instrument.workId == workId
            and optionalOwner(action, work) then occurrence = work.instrument.occurrence; break end
    end
    if not occurrence then
        local result = G.instrumentOutcome(id, workId)
        occurrence = result and result.occurrence
    end
    if type(occurrence) ~= "table" or occurrence.actorId ~= id or occurrence.workId ~= workId then return nil end
    local out = {}; for key, value in pairs(occurrence) do out[key] = value end
    return out
end

function G.resetInstruments()
    for action, work in pairs(optional) do
        if work.instrument then
            finishInstrument(action, work, "interrupted")
            if optionalOwner(action, work) and ISTimedActionQueue.hasAction(action) then
                pcall(function() action:forceStop() end)
            end
        end
    end
    for state, owner in pairs(soundCleanup) do
        if currentOwner(owner.id, owner.body, owner.rec, owner.token) then stopOwnedSound(state) end
        soundCleanup[state] = nil
    end
end

-- Those already close when the tune starts: half dance, the rest clap.
function G.dance(id, body)
    local receipt = takePlanReceipt(id)
    return G.play(id, body, pick(G.DANCES, id, "dance"), TICKS.dance, receipt)
end

-- [C119] The counter ([C113]): a person at their filed trade ground
-- with somebody in front of them. Called by the work arrival seam on
-- the controller; the moment is the commute's own, the shape is
-- Week One's cashier.
function G.cashier(id, body)
    return G.play(id, body, pick(G.CASHIER, id, "cashier"), TICKS.serve)
end

-- [C119] The protest ([A25]): called by the election seam when TWO
-- dissenters stand within reach - a grumble with a body, and a crowd
-- of exactly the size the county's own politics produced. Both of
-- the pair hold the shape; the voice still says the grievance.
function G.protest(id, body)
    return G.play(id, body, pick(G.PROTEST, id, "protest"), TICKS.gesture)
end

-- [C119] The medic's three-stage machine: the kneel beside the
-- body, the work, the end of it. Called by the aid seam when the
-- hurt body is down - desperate aid is what the moment is, and
-- CPR is what desperate aid looks like. Week One's three clips,
-- one queue: the actions run in order and the last one lets go.
function G.cpr(id, body)
    if not body or not free(body) then return false end
    local ok = true
    for i, name in ipairs(G.CPR) do
        local ticks = (i == 1 and TICKS.cprStart)
            or (i == 2 and TICKS.cprLoop) or TICKS.cprEnd
        local queued = pcall(function()
            ISTimedActionQueue.add(
                SAOGestureAction:new(body, name, ticks))
        end)
        if not queued then ok = false end
    end
    if ok then log(tostring(id) .. " cpr") end
    return ok
end

-- [C120] The throw ([C120]'s ball): called by the ROAM arrival seam
-- when a child carrying a ball reaches a street with a playmate at
-- hand. The moment is the walk's own - a kid stretching their legs
-- arrives somewhere with a friend nearby - and the shape is Week
-- One's throw. What the OTHER half of the game does (the catch, the
-- return) has no machinery here and is named in the batch record
-- rather than faked: one child throws, which is what a throw is.
function G.ball(id, body)
    return G.play(id, body, pick(G.BALL, id, "ball"), TICKS.ball)
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

log("gesture module loaded (the county's gestures, seats, tunes, dances, claps, coughs, the counter, the protest, the medic's hands and the kid's throw)")

return G
