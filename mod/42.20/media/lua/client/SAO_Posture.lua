-- A finite native watch/cover owner.  Organization owns the accepted role;
-- this module owns only the admitted body orientation and its exact result.
SAO = SAO or {}
SAO.Posture = SAO.Posture or {}
local P = SAO.Posture
P.jobs = P.jobs or {}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function hours()
    local value = 0
    pcall(function() value = SAO.History.countyHours() end)
    return finite(value) and value or 0
end

local function record(id, phase, detail)
    if SAO.Observation then
        pcall(SAO.Observation.record, id, "Posture", phase,
            tostring(detail or phase))
    end
end

local function owner(id, body)
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or tostring(rec.id or "") ~= id or rec.dead or not body
        or not (SAO.Body and SAO.Body.get and SAO.Body.get(id) == body)
        or not SAOJavaBridge or SAOJavaBridge:isShell(body) ~= true then
        return nil
    end
    local data = body:getModData()
    if type(data) ~= "table" or tostring(data.SAOPersonId or "") ~= id
        or data.SAOExternalToken ~= rec.bodyOwnerToken
        or body:isDead() or body:isAsleep() or body:getVehicle() ~= nil
        or not body:isExistInTheWorld() or not body:getCurrentSquare() then
        return nil
    end
    if rec.bodyOwner == nil then
        local agent = SAO.Controller and SAO.Controller.agents
            and SAO.Controller.agents[id] or nil
        if SAO.Body.active[id] ~= body or SAO.Body.foreign[id] ~= nil
            or not agent or agent.rec ~= rec or agent.passive
            or data.SAOExternalOwner ~= nil or data.ZAOOwned == true then
            return nil
        end
    elseif rec.bodyOwner == "ZAO" then
        local controlled = ZAO and ZAO.Controller and ZAO.Controller.controlled
        if SAO.Body.foreign[id] ~= body or SAO.Body.active[id] ~= nil
            or not controlled or controlled[id] ~= body
            or data.SAOExternalOwner ~= "ZAO"
            or data.ZAOOwned ~= true then return nil end
    else
        return nil
    end
    return rec
end

local function finish(id, status, reason, nativeState)
    local job = P.jobs[id]
    if not job then return status end
    P.jobs[id] = nil
    pcall(function() SAOJavaBridge:clearPosture(job.body, job.id) end)
    local receipt = {
        id = job.id, actorId = id, processId = job.processId,
        processRevision = job.processRevision,
        commitmentId = job.commitmentId, stepId = job.stepId,
        token = job.completionToken, status = status,
        reason = tostring(reason or status), owner = "Posture",
        startedAtHours = job.startedAtHours, atHours = hours(),
        target = { x = job.target.x, y = job.target.y, z = job.target.z },
        posture = job.posture,
        maintainedSeconds = nativeState
            and tonumber(nativeState.maintainedSeconds) or 0,
        requiredSeconds = job.durationSeconds,
    }
    if SAO.Organization and SAO.Organization.consumeProcedureResult then
        pcall(SAO.Organization.consumeProcedureResult, {
            id = receipt.id, actorId = id,
            commitmentId = receipt.commitmentId, stepId = receipt.stepId,
            token = receipt.token, owner = receipt.owner,
            status = status == "completed" and "completed"
                or status == "interrupted" and "interrupted" or "failed",
            reason = receipt.reason, at = receipt.atHours,
            evidence = { target = receipt.target, posture = receipt.posture,
                maintainedSeconds = receipt.maintainedSeconds,
                requiredSeconds = receipt.requiredSeconds },
        })
    end
    record(id, status, receipt.reason)
    if P.onOutcome then pcall(P.onOutcome, id, receipt) end
    return status, receipt
end

function P.begin(id, body, context)
    id, context = tostring(id or ""), type(context) == "table" and context or {}
    local target = type(context.target) == "table" and context.target or {}
    local x, y, z = tonumber(target.x), tonumber(target.y), tonumber(target.z) or 0
    local commitmentId, stepId = tostring(context.commitmentId or ""),
        tostring(context.stepId or "")
    if id == "" or commitmentId == "" or stepId == ""
        or not finite(x) or not finite(y) or not finite(z) then return false end
    local prior = P.jobs[id]
    if prior then
        if prior.body == body and prior.commitmentId == commitmentId
            and prior.stepId == stepId then return true, prior end
        return false
    end
    local rec = owner(id, body)
    if not rec then return false end
    rec.postureSequence = math.max(0,
        math.floor(tonumber(rec.postureSequence) or 0)) + 1
    local duration = math.max(0.5, math.min(30,
        tonumber(context.durationSeconds) or 3))
    local readiness, steadiness = 1, 1
    pcall(function()
        readiness = SAO.Neuro.clarityOf(rec)
        steadiness = SAO.Neuro.motorSteadiness(rec)
    end)
    readiness = math.max(0, math.min(1, tonumber(readiness) or 0))
    steadiness = math.max(0, math.min(1, tonumber(steadiness) or 0))
    local actionId = "posture/" .. id .. "/" .. tostring(rec.postureSequence)
    local ok, admitted = pcall(function()
        return SAOJavaBridge:requestPosture(body, actionId, x, y,
            readiness, steadiness, duration)
    end)
    if not ok or admitted ~= true then return false end
    local job = {
        id = actionId, actorId = id, body = body,
        processId = context.processId,
        processRevision = context.processRevision,
        commitmentId = commitmentId, stepId = stepId,
        completionToken = context.completionToken or "posture:maintained",
        target = { x = x, y = y, z = z },
        posture = tostring(context.posture or "watch"),
        durationSeconds = duration, startedAtHours = hours(),
    }
    P.jobs[id] = job
    record(id, "started", job.posture .. " toward "
        .. tostring(x) .. "," .. tostring(y))
    return true, job
end

function P.tick(id, body)
    id = tostring(id or "")
    local job = P.jobs[id]
    if not job then return "none" end
    if body ~= job.body or not owner(id, body) then
        return finish(id, "interrupted", "body-owner-unavailable")
    end
    local ok, state = pcall(function()
        return SAOJavaBridge:orientationState(body)
    end)
    if not ok or type(state) ~= "table" or state.mode ~= "posture"
        or tostring(state.actionId or "") ~= job.id then
        return finish(id, "failed", "native-posture-unavailable", state)
    end
    if state.active == true then return "holding" end
    if state.reason == "completed" then
        return finish(id, "completed", "target-maintained", state)
    end
    return finish(id, "failed", state.reason or "native-posture-ended", state)
end

function P.interrupt(id, body, reason)
    id = tostring(id or "")
    local job = P.jobs[id]
    if not job or body and job.body ~= body then return false end
    finish(id, "interrupted", reason or "interrupted")
    return true
end

function P.forget(id)
    id = tostring(id or "")
    local job = P.jobs[id]
    if not job then return false end
    finish(id, "interrupted", "death")
    -- Explicit here as well as in finish: this function is the per-person
    -- lifetime boundary named by Identity.markDead.
    P.jobs[id] = nil
    return true
end

function P.status(id)
    local job = P.jobs[tostring(id or "")]
    return job and "active" or "none"
end

function P.reset()
    for id, job in pairs(P.jobs) do
        pcall(function() SAOJavaBridge:clearPosture(job.body, job.id) end)
        P.jobs[id] = nil
    end
end

for _, eventName in ipairs({ "OnGameStart", "OnLoad", "OnNewGame" }) do
    if Events and Events[eventName] then
        Events[eventName].Remove(P.reset)
        Events[eventName].Add(P.reset)
    end
end
return P
