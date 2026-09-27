-- SAO_Orienting - private auditory cues admitted by the current body owner.
-- Perception owns acquisition, Neuro owns current response projections, and
-- the native actuator owns finite motion. This owner cannot plan or steer.
SAO = SAO or {}
SAO.Orienting = SAO.Orienting or {}
local O = SAO.Orienting
if O.reset then O.reset() end
local states = {}
local CONSUMED_LIMIT = 64

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function clearNative(body)
    if body and SAOJavaBridge then
        pcall(function() SAOJavaBridge:clearOrientation(body) end)
    end
end

function O.forget(id, body)
    if id == nil then return end
    id = tostring(id)
    local row = states[id]
    if row and (body == nil or row.body == body) then
        clearNative(row.body)
        states[id] = nil
    end
end

function O.reset()
    for _, row in pairs(states) do clearNative(row.body) end
    states = {}
end

-- These reads establish one exact human-shell owner without repairing or
-- creating any persistent state. Ordinary SAO ownership is intentionally nil.
local function currentOwner(id, body, context)
    if type(context) ~= "table" or not body then return nil end
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or tostring(rec.id or "") ~= id or rec.dead == true
        or context.bodyOwnerToken ~= rec.bodyOwnerToken then return nil end
    local bodies = SAO.Body
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[id] or nil
    local data = body:getModData()
    if type(data) ~= "table" or tostring(data.SAOPersonId or "") ~= id
        or not bodies then return nil end
    if context.owner == "SAO" then
        if rec.bodyOwner ~= nil or bodies.active[id] ~= body
            or bodies.foreign[id] ~= nil or not agent or agent.rec ~= rec
            or agent.passive == true or agent.state == "PASSIVE"
            or data.SAOExternalOwner ~= nil or data.ZAOOwned == true then return nil end
    elseif context.owner == "ZAO" then
        local controlled = ZAO and ZAO.Controller and ZAO.Controller.controlled
        if rec.bodyOwner ~= "ZAO" or type(rec.bodyOwnerToken) ~= "string"
            or rec.bodyOwnerToken == "" or bodies.foreign[id] ~= body
            or bodies.active[id] ~= nil or agent ~= nil
            or not controlled or controlled[id] ~= body
            or data.SAOExternalOwner ~= "ZAO"
            or data.SAOExternalToken ~= rec.bodyOwnerToken
            or data.ZAOOwned ~= true then return nil end
    else
        return nil
    end
    return rec
end

local function nativeAvailable(body)
    return SAOJavaBridge and SAOJavaBridge:isShell(body) == true
        and body:isDead() == false and body:isAsleep() == false
        and body:isExistInTheWorld() == true and body:getCurrentSquare() ~= nil
        and body:isAttacking() == false and body:isAiming() == false
        and body:isClimbing() == false and body:isClimbingRope() == false
        and body:getVehicle() == nil
end

local function workAvailable(id, rec, body, owner)
    -- pendingActionFor repairs invalid pointers; observing this reservation
    -- marker instead leaves every SourceUse decision with its current owner.
    if rec.worldSourceReservation ~= nil then return false end
    local queue = ISTimedActionQueue and ISTimedActionQueue.queues
        and ISTimedActionQueue.queues[body] or nil
    if queue and type(queue.queue) == "table" and #queue.queue > 0 then return false end
    if owner == "SAO" then
        local agent = SAO.Controller.agents[id]
        if agent.sleeping == true or agent.state == "ENGAGE" then return false end
    end
    return true
end

local function remember(row, token, at)
    row.consumed[token] = at
    local count, oldestToken, oldestAt = 0, nil, nil
    for key, consumedAt in pairs(row.consumed) do
        count = count + 1
        if not oldestAt or consumedAt < oldestAt
            or consumedAt == oldestAt and key < oldestToken then
            oldestToken, oldestAt = key, consumedAt
        end
    end
    if count > CONSUMED_LIMIT then row.consumed[oldestToken] = nil end
end

local function validCue(cue, now, horizon)
    return type(cue) == "table" and cue.source == "heard"
        and type(cue.cueId) == "string" and #cue.cueId > 0 and #cue.cueId <= 56
        and finite(cue.x) and finite(cue.y) and finite(cue.distance)
        and cue.distance >= 0 and finite(cue.heardAt)
        and now >= cue.heardAt and now - cue.heardAt <= horizon
end

function O.consider(id, body, context)
    if id == nil then return false, "unavailable" end
    id = tostring(id)
    local ok, rec = pcall(currentOwner, id, body, context)
    if not ok or not rec then
        O.forget(id)
        return false, "owner-mismatch"
    end
    local nativeOk, available = pcall(nativeAvailable, body)
    if not nativeOk or not available or not workAvailable(id, rec, body, context.owner) then
        O.forget(id)
        return false, "body-unavailable"
    end
    local clockOk, now = pcall(function() return SAO.History.ticks() end)
    local p = SAO.Perception
    if not clockOk or not finite(now) or not p or not p.soundCues
        or not finite(p.SOUND_CUE_FRESH) or p.SOUND_CUE_FRESH <= 0 then
        O.forget(id)
        return false, "cue-unavailable"
    end
    local row = states[id]
    if row and (row.body ~= body or row.owner ~= context.owner
        or row.ownerToken ~= rec.bodyOwnerToken or now < row.at) then
        O.forget(id)
        row = nil
    end
    if not row then
        row = { body = body, owner = context.owner,
            ownerToken = rec.bodyOwnerToken, at = now, consumed = {} }
        states[id] = row
    end
    row.at = now
    local cuesOk, cues = pcall(p.soundCues, id, body, now)
    if not cuesOk or type(cues) ~= "table" then return false, "cue-unavailable" end
    local pending, newest = nil, nil
    for index = 1, math.min(#cues, 64) do
        local cue = cues[index]
        if validCue(cue, now, p.SOUND_CUE_FRESH)
            and row.consumed[cue.cueId] == nil then
            if row.pending and cue.cueId == row.pending.cueId
                and cue.heardAt == row.pending.heardAt
                and cue.x == row.pending.x and cue.y == row.pending.y then
                pending = row.pending
            end
            if not newest or cue.heardAt > newest.heardAt
                or cue.heardAt == newest.heardAt and cue.distance < newest.distance
                or cue.heardAt == newest.heardAt and cue.distance == newest.distance
                    and cue.cueId < newest.cueId then
                newest = cue
            end
        end
    end
    row.pending = pending or newest
    local cue = row.pending
    if not cue then return false, "no-fresh-cue" end
    local scalarOk, readiness, steadiness = pcall(function()
        return SAO.Neuro.clarityOf(rec), SAO.Neuro.motorSteadiness(rec)
    end)
    if not scalarOk or not finite(readiness) or not finite(steadiness) then
        return false, "projection-unavailable"
    end
    readiness = math.max(0, math.min(1, readiness))
    steadiness = math.max(0, math.min(1, steadiness))
    local job = SAO.Locomotion and SAO.Locomotion.jobs
        and SAO.Locomotion.jobs[id] or nil
    local allowBodyTurn = context.allowBodyTurn == true
        and (not job or job.done == true)
    local admittedOk, admitted = pcall(function()
        return SAOJavaBridge:requestOrientation(body, cue.cueId, cue.x, cue.y,
            readiness, steadiness, allowBodyTurn)
    end)
    if not admittedOk or admitted ~= true then return false, "native-refused" end
    -- A refused/throwing request remains pending only until its original
    -- acquisition expires. Admission is the sole consumption event.
    remember(row, cue.cueId, now)
    row.pending = nil
    return true, "admitted"
end

return O
