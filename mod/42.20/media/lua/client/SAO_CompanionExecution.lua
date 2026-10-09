-- A separately embodied companion can temporarily lend its native movement
-- execution to a named controller. The local game has no named-peer verifier
-- yet, so all transport-facing commands refuse before reaching these owners.
SAO = SAO or {}
SAO.CompanionExecution = SAO.CompanionExecution or {}
local C = SAO.CompanionExecution

local grants, returning, adapters, finalResults = {}, {}, {}, {}
local tokenSequence, receiptSequence = 0, 0
local RETURN_WAIT_TICKS = 90

local function validId(value)
    return type(value) == "string" and #value > 0 and #value <= 128
        and value:match("^[%w_%-]+$") ~= nil
end

local function companionOwner(owner)
    return type(owner) == "string" and owner:sub(1, 10) == "companion:"
end

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function currentTick()
    local ok, tick = pcall(function() return SAO.History.ticks() end)
    return ok and finite(tick) and tick or nil
end

local function currentPlayerKey()
    local playerAt = SAO.Participants and SAO.Participants.player or getSpecificPlayer
    if type(playerAt) ~= "function" or not SAO.Standing
        or not SAO.Standing.playerKey then return nil end
    local ok, player = pcall(playerAt, 0)
    if not ok or not player then return nil end
    local ready, key = pcall(function()
        if player:isDead() or not player:getCurrentSquare() then return nil end
        return SAO.Standing.playerKey(player)
    end)
    return ready and type(key) == "string" and key ~= "" and key or nil, player
end

local function recordResult(grant, requestId, status, reason)
    receiptSequence = receiptSequence + 1
    local result = { grantId = grant.id, personId = grant.personId,
        bindingId = grant.bindingId, sessionId = grant.sessionId,
        bindingEpoch = grant.bindingEpoch, actorId = grant.actorId,
        sequence = receiptSequence, requestId = requestId,
        status = status, reason = reason }
    finalResults[grant.id] = finalResults[grant.id] or {}
    finalResults[grant.id][requestId or "return"] = result
    return result
end

local function ownedBody(grant)
    local rec = SAO.Identity and SAO.Identity.get(grant.personId)
    if not rec or rec.dead or rec.bodyOwner ~= grant.owner
        or rec.bodyOwnerToken ~= grant.token then return nil, nil end
    local body = SAO.Body and SAO.Body.foreign and SAO.Body.foreign[rec.id]
    return rec, body
end

local function exactRoute(grant, attempt)
    return attempt.job and attempt.jobId == grant.personId
        and SAO.Locomotion and SAO.Locomotion.jobs
        and SAO.Locomotion.jobs[grant.personId] == attempt.job
end

local function interruptOwned(grant, reason)
    for requestId, attempt in pairs(grant.attempts) do
        if attempt.status == "running" then
            if attempt.job and attempt.job.done then
                attempt.status = attempt.job.result == "arrived" and "arrived" or "failed"
                recordResult(grant, requestId, attempt.status, attempt.job.result)
            else
                attempt.status = "interrupted"
                -- The terminal result exists before native route cancellation.
                recordResult(grant, requestId, "interrupted", reason)
                if exactRoute(grant, attempt) then
                    SAO.Locomotion.cancel(attempt.jobId)
                end
            end
        end
    end
end

local function queueReturn(rec, reason)
    if not rec or not companionOwner(rec.bodyOwner) then return false end
    local pending = rec.companionReturn
    if pending and pending.owner ~= rec.bodyOwner then return false end
    if not pending then
        pending = { version = 1, owner = rec.bodyOwner, reason = reason,
            attempts = 0, deadlineTicks = RETURN_WAIT_TICKS,
            status = "return-pending" }
        rec.companionReturn = pending
    end
    if reason == "zao-terminal" then pending.reason = reason end
    returning[rec.id] = true
    return true
end

-- The external death observer clears body ownership after a verified native
-- death. Its former adapter must then leave the transient communication map;
-- a blocked living return keeps that adapter until the body really returns.
local function settleDeadOwner(owner, rec)
    if not rec or rec.dead ~= true or not companionOwner(owner)
        or rec.bodyOwner == owner then return false end
    local pending = rec.companionReturn
    if pending and pending.owner == owner then rec.companionReturn = nil end
    returning[rec.id] = nil
    local communication = SAO.Communication
    if adapters[owner] and communication
        and communication.unregisterExecutionOwner then
        communication.unregisterExecutionOwner(owner, adapters[owner])
    end
    return true
end

local function expireGrant(grant, reason)
    if grant.dead then return true end
    grant.dead = true
    grant.deadReason = reason or "grant-expired"
    interruptOwned(grant, grant.deadReason)
    local rec = SAO.Identity and SAO.Identity.get(grant.personId)
    if rec and rec.bodyOwner == grant.owner
        and rec.bodyOwnerToken == grant.token then
        return queueReturn(rec, grant.deadReason)
    end
    return true
end

local function ownerAdapter(owner)
    local adapter = adapters[owner]
    if adapter then return adapter end
    adapter = {
        bodyFor = function(id, rec)
            if rec and rec.id == id and rec.bodyOwner == owner then
                return SAO.Body and SAO.Body.foreign and SAO.Body.foreign[id]
            end
            return nil
        end,
        -- A returned companion is restored under SAO. No other controller
        -- may wake a dormant body while this lease is held.
        advanceDormant = function() return false, "companion-return-pending" end,
    }
    adapters[owner] = adapter
    return adapter
end

local function registerOwner(owner)
    local communication = SAO.Communication
    if not communication or not communication.registerExecutionOwner then
        return false, "communication-owner-unavailable"
    end
    local adapter = ownerAdapter(owner)
    local existing = communication.executionOwners
        and communication.executionOwners[owner]
    if existing and existing ~= adapter then return false, "owner-adapter-held" end
    if not communication.registerExecutionOwner(owner, adapter) then
        return false, "owner-adapter-refused"
    end
    return true
end

local function principalMatches(grant, principal)
    return type(principal) == "table" and principal.peerId == grant.peerId
        and principal.actorId == grant.actorId
        and principal.bindingId == grant.bindingId
        and principal.sessionId == grant.sessionId
        and principal.bindingEpoch == grant.bindingEpoch
end

-- This function is private until a named-peer verifier exists at the native
-- operator route. A focused fixture exercises it without exporting it in game.
local function claimVerified(principal, request)
    if type(principal) ~= "table" or principal.verified ~= true
        or not validId(principal.peerId) or principal.peerId == "peer:shared"
        or not validId(principal.actorId)
        or not validId(principal.bindingId)
        or not validId(principal.sessionId)
        or not finite(principal.bindingEpoch)
        or principal.bindingEpoch < 0
        or math.floor(principal.bindingEpoch) ~= principal.bindingEpoch
        or not finite(principal.expiresAtTick)
        or type(request) ~= "table" or not validId(request.grantId)
        or not validId(request.personId)
        or not validId(request.requestId) then return false, "invalid-grant" end
    local tick = currentTick()
    if not tick or principal.expiresAtTick <= tick then
        return false, "grant-expired"
    end
    if grants[request.grantId] then return false, "grant-id-in-use" end
    local playerKey, player = currentPlayerKey()
    if not playerKey or principal.playerKey ~= playerKey then
        return false, "player-binding-mismatch"
    end
    local rec = SAO.Identity and SAO.Identity.get(request.personId)
    if not rec then return false, "missing-person" end
    if rec.dead then return false, "person-dead" end
    if rec.bodyOwner or rec.bodyTransfer or rec.zaoTransferPending
        or rec.crossedTransferPending or rec.companionReturn
        or SAO.Body.isTransitioning(rec) then return false, "person-owned-or-transitioning" end
    if rec.cookingWork or rec.studyWork and rec.studyWork.status == "reading" then
        return false, "work-pending"
    end
    if SAO.CrossedTransfer and SAO.CrossedTransfer.terminalOf
        and SAO.CrossedTransfer.terminalOf(rec) then return false, "zao-terminal" end
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[rec.id]
    if not agent or agent.rec ~= rec or agent.companioning ~= true then
        return false, "not-current-player-companion"
    end
    local body = SAO.Body.active[rec.id]
    if not body or body == player then return false, "separate-body-unavailable" end
    if type(getSpecificPlayer) ~= "function" then
        return false, "native-player-slots-unavailable"
    end
    for slot = 0, 3 do
        local slotOK, slotBody = pcall(getSpecificPlayer, slot)
        if not slotOK then return false, "native-player-slots-unavailable" end
        if slotBody == body then return false, "separate-body-unavailable" end
    end
    local okBody, living = pcall(function()
        local data = body:getModData()
        return SAOJavaBridge and SAOJavaBridge:isShell(body) == true
            and body:isDead() ~= true and data.SAOPersonId == rec.id
            and data.SAOExternalOwner == nil
    end)
    if not okBody or not living then return false, "living-native-body-unavailable" end
    local ready, why = SAO.Body.canTransfer(body)
    if not ready then return false, why or "body-busy" end
    local owner = "companion:" .. request.grantId
    local registered, registrationReason = registerOwner(owner)
    if not registered then return false, registrationReason end
    tokenSequence = tokenSequence + 1
    local token = "sao-companion-" .. tostring(tokenSequence) .. ":" .. tostring({})
    local prepared, reason = SAO.Body.prepareExternalTransfer(rec, body, owner, token)
    if not prepared then
        SAO.Communication.unregisterExecutionOwner(owner, adapters[owner])
        return false, reason
    end
    local called, committed, committedReason = pcall(SAO.Body.commitExternalTransfer, rec)
    if not called or not committed then
        if not rec.bodyOwner and rec.bodyTransfer
            and rec.bodyTransfer.owner == owner
            and rec.bodyTransfer.token == token
            and SAO.Body.active[rec.id] == body then rec.bodyTransfer = nil end
        if rec.bodyOwner == owner and rec.bodyOwnerToken == token then
            queueReturn(rec, "claim-commit-exception")
        else
            SAO.Communication.unregisterExecutionOwner(owner, adapters[owner])
        end
        return false, called and committedReason or "claim-commit-exception"
    end
    grants[request.grantId] = { id = request.grantId, personId = rec.id,
        playerKey = playerKey, peerId = principal.peerId,
        actorId = principal.actorId, bindingId = principal.bindingId,
        sessionId = principal.sessionId, bindingEpoch = principal.bindingEpoch,
        expiresAtTick = principal.expiresAtTick,
        owner = owner, token = token, attempts = {}, dead = false }
    return true, recordResult(grants[request.grantId], request.requestId,
        "claimed", committedReason)
end

local function attemptVerified(principal, grantId, requestId, goal)
    local grant = grants[tostring(grantId or "")]
    if not grant then return false, "grant-unavailable" end
    if grant.dead then return false, "grant-expired" end
    if not principalMatches(grant, principal) then return false, "session-binding-mismatch" end
    local tick = currentTick()
    if not tick or tick >= grant.expiresAtTick then
        expireGrant(grant, "grant-expired")
        return false, "grant-expired"
    end
    if not validId(requestId) or type(goal) ~= "table"
        or not finite(goal.x) or not finite(goal.y) or not finite(goal.z)
        or math.floor(goal.z) ~= goal.z then return false, "invalid-move" end
    if grant.attempts[requestId] then
        return true, finalResults[grant.id] and finalResults[grant.id][requestId]
            or "attempt-running"
    end
    local rec, body = ownedBody(grant)
    if not rec or not body then
        expireGrant(grant, "body-owner-lost")
        return false, "body-owner-lost"
    end
    if rec.zaoTransferPending or rec.crossedTransferPending then
        C.terminalPending(rec.id)
        return false, "zao-terminal"
    end
    local playerKey = currentPlayerKey()
    if playerKey ~= grant.playerKey then
        expireGrant(grant, "player-session-ended")
        return false, "grant-expired"
    end
    for _, attempt in pairs(grant.attempts) do
        if attempt.status == "running" then return false, "attempt-already-running" end
    end
    if not SAO.Locomotion or not SAO.Locomotion.order then
        return false, "locomotion-owner-unavailable"
    end
    local accepted = SAO.Locomotion.order(rec.id, body,
        goal.x, goal.y, goal.z, goal.running == true, { footOnly = true })
    local job = SAO.Locomotion.jobs and SAO.Locomotion.jobs[rec.id]
    if accepted ~= true or not job or job.body ~= body or job.mode == "horse" then
        return false, "route-refused"
    end
    grant.attempts[requestId] = { jobId = rec.id, job = job,
        status = "running" }
    return true, recordResult(grant, requestId, "running", "native-route-started")
end

local function revokeVerified(principal, grantId, reason)
    local grant = grants[tostring(grantId or "")]
    if not grant then return false, "grant-unavailable" end
    if not principalMatches(grant, principal) then return false, "session-binding-mismatch" end
    if grant.dead then
        local result = finalResults[grant.id] and finalResults[grant.id]["return"]
        return true, result or "return-pending"
    end
    expireGrant(grant, reason or "grant-revoked")
    return true, recordResult(grant, nil, "return-pending", grant.deadReason)
end

local function settleRunning(grant)
    for requestId, attempt in pairs(grant.attempts) do
        if attempt.status == "running" then
            if not exactRoute(grant, attempt) then
                attempt.status = "interrupted"
                recordResult(grant, requestId, "interrupted", "route-owner-changed")
            else
                SAO.Locomotion.tick(attempt.jobId)
                if attempt.job.done then
                    attempt.status = attempt.job.result == "arrived" and "arrived" or "failed"
                    recordResult(grant, requestId, attempt.status, attempt.job.result)
                end
            end
        end
    end
end

-- Crossed/Afflicted ownership is recorded by CrossedTransfer before this call.
-- A repeated notification keeps the same held return and never resets its wait.
function C.terminalPending(personId)
    local rec = SAO.Identity and SAO.Identity.get(tostring(personId or ""))
    if not rec or not companionOwner(rec.bodyOwner)
        or not (rec.zaoTransferPending or rec.crossedTransferPending) then return false end
    local grantId = rec.bodyOwner:sub(11)
    local grant = grants[grantId]
    if grant and grant.personId == rec.id and grant.owner == rec.bodyOwner then
        expireGrant(grant, "zao-terminal")
    end
    return queueReturn(rec, "zao-terminal")
end

local function retryReturn(rec)
    local pending = rec and rec.companionReturn
    if not rec or not pending or pending.version ~= 1
        or pending.owner ~= rec.bodyOwner or not companionOwner(rec.bodyOwner) then
        returning[rec and rec.id or ""] = nil
        return
    end
    local owner, grantId = rec.bodyOwner, rec.bodyOwner:sub(11)
    if SAO.Body.unloaded[rec.id] and SAO.Body.foreign[rec.id]
        and SAO.Body.recover then
        -- Body's companion unload path checks readiness without clearing
        -- anybody else's timed actions or source reservation.
        pcall(SAO.Body.recover, rec)
    end
    local body = SAO.Body.foreign[rec.id]
    if body then
        local ok, dead = pcall(function() return body:isDead() end)
        if not ok or dead then
            if ok and dead and SAO.Controller
                and SAO.Controller.observeExternalDeath
                and SAO.Controller.observeExternalDeath(rec.id, body, owner) == true then
                settleDeadOwner(owner, rec)
            else
                pending.lastReason = "death-observation-pending"
                pending.status = "return-blocked"
            end
            return
        end
    end
    pending.attempts = (tonumber(pending.attempts) or 0) + 1
    local ok, released, reason = pcall(SAO.Body.returnExternal,
        rec, owner, rec.bodyOwnerToken)
    if ok and released == true then
        returning[rec.id] = nil
        if SAO.Communication and SAO.Communication.unregisterExecutionOwner then
            SAO.Communication.unregisterExecutionOwner(owner, adapters[owner])
        end
        finalResults[grantId] = finalResults[grantId] or {}
        finalResults[grantId].returnResult = { grantId = grantId,
            personId = rec.id, status = "returned", reason = reason }
        if rec.zaoTransferPending and SAO.CrossedTransfer
            and SAO.CrossedTransfer.resumePending then
            SAO.CrossedTransfer.resumePending()
        end
        return
    end
    pending.lastReason = ok and reason or "return-exception"
    pending.status = pending.attempts >= (pending.deadlineTicks or RETURN_WAIT_TICKS)
        and "return-blocked" or "return-pending"
    finalResults[grantId] = finalResults[grantId] or {}
    finalResults[grantId].returnResult = { grantId = grantId,
        personId = rec.id, status = pending.status, reason = pending.lastReason }
end

function C.onGameStart()
    for id in pairs(grants) do grants[id] = nil end
    for id in pairs(returning) do returning[id] = nil end
    if not SAO.Identity or not SAO.Identity.all then return end
    for _, rec in pairs(SAO.Identity.all()) do
        if rec and not rec.dead and companionOwner(rec.bodyOwner) then
            registerOwner(rec.bodyOwner)
            queueReturn(rec, rec.zaoTransferPending and "zao-terminal"
                or "grant-expired")
        end
    end
end

function C.onTick()
    for _, grant in pairs(grants) do
        if not grant.dead then
            local rec, body = ownedBody(grant)
            local tick = currentTick()
            if not tick or tick >= grant.expiresAtTick then
                expireGrant(grant, "grant-expired")
            elseif not rec then expireGrant(grant, "body-owner-lost")
            elseif rec.zaoTransferPending or rec.crossedTransferPending then
                C.terminalPending(rec.id)
            elseif currentPlayerKey() ~= grant.playerKey then
                expireGrant(grant, "player-session-ended")
            elseif body then
                local ok, dead = pcall(function() return body:isDead() end)
                if not ok or dead then
                    local observed = false
                    if SAO.Controller and SAO.Controller.observeExternalDeath then
                        if ok and dead then
                            observed = SAO.Controller.observeExternalDeath(
                                rec.id, body, grant.owner) == true
                        end
                    end
                    if observed then settleDeadOwner(grant.owner, rec) end
                    expireGrant(grant, "person-dead")
                else settleRunning(grant) end
            else expireGrant(grant, "body-unloaded") end
        end
    end
    for id in pairs(returning) do
        local rec = SAO.Identity and SAO.Identity.get(id)
        retryReturn(rec)
    end
end

-- The available loopback/session route does not attest a named peer. These
-- commands remain closed even if a caller supplies plausible identity fields.
function C.requestGrant() return false, "peer-auth-unavailable" end
function C.requestAttempt() return false, "peer-auth-unavailable" end
function C.requestRevoke() return false, "peer-auth-unavailable" end
function C.commandResult() return false, "peer-auth-unavailable" end

if Events and Events.OnGameStart then
    if C._startEvent then Events.OnGameStart.Remove(C._startEvent) end
    C._startEvent = function() C.onGameStart() end
    Events.OnGameStart.Add(C._startEvent)
end
if Events and Events.OnTick then
    if C._tickEvent then Events.OnTick.Remove(C._tickEvent) end
    C._tickEvent = function() C.onTick() end
    Events.OnTick.Add(C._tickEvent)
end

return C
