-- SAO_AfflictedReturn - authorized transfer from ZAO to a living person.
-- The durable phase owns the person until source removal and controller
-- adoption succeed. Detached staged shells never enter ordinary Body.get.
SAO = SAO or {}
SAO.AfflictedReturn = SAO.AfflictedReturn or {}
local Return = SAO.AfflictedReturn
local running = false

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function hibernationVersion(packed)
    if SAOJavaBridge and SAOJavaBridge.hibernationVersion then
        local ok, version = pcall(function()
            return SAOJavaBridge:hibernationVersion(packed)
        end)
        if ok and type(version) == "number" then return version end
        return 0
    end
    return 3
end

local function dependencies()
    return ZAO and ZAO.StateStore and ZAO.StateStore.returnAuthorization
        and ZAO.Controller and ZAO.Controller.returnSource and SAOJavaBridge
        and SAO.Identity and SAO.Body and SAO.Controller
end

function Return.authorized(rec)
    local p = rec and rec.returnTransition
    if not p or p.version ~= 1 or not dependencies() then return false end
    if p.sourceRemoved then return true end
    local event = ZAO.StateStore.returnAuthorization(rec.id)
    return event and event.token == p.event
        and (event.deathSequence == nil or event.deathSequence == (rec.deathSequence or 0))
end

local function begin(rec)
    if not rec.dead or SAO.Body.hasRepresentation(rec.id) then return false, "represented" end
    if not ZAO.Controller.restoreReturnHealth then return false, "recovery-state-unavailable" end
    if SAO.Controller.pendingCorpses and SAO.Controller.pendingCorpses[rec.id] then
        return false, "corpse-pending"
    end
    local event = ZAO.StateStore.returnAuthorization(rec.id)
    if not event or event.token == rec.returnEvent then return false, "no-new-reversion" end
    if event.deathSequence ~= nil and event.deathSequence ~= (rec.deathSequence or 0) then
        return false, "reversion-belongs-to-prior-death"
    end
    if rec.afflictedReturn and rec.returnEvent == nil
        and tostring(event.token):sub(1, 7) == "legacy:" then
        rec.returnEvent = event.token
        return false, "legacy-reversion-already-consumed"
    end
    if tonumber(event.day) == nil or event.day < math.floor((rec.diedAtHours or 0) / 24) then
        return false, "reversion-predates-death"
    end
    local source = ZAO.Controller.returnSource(rec.id)
    if source and (not ZAO.Controller.canReturnSource
        or not ZAO.Controller.canReturnSource(source)) then
        return false, "source-persistence-unavailable"
    end
    local kind = source and "loaded" or "dormant"
    if not source and rec.turnedDormant ~= true then return false, "source-unavailable" end
    if source and rec.returnLivingDeath ~= (rec.deathSequence or 0) then
        return false, "living-state-belongs-to-prior-death"
    end
    local living = source and rec.returnLiving or rec.hibernation
    if not SAOJavaBridge:validateHibernation(living) then return false, "living-state-unavailable" end
    local x, y, z = rec.x, rec.y, rec.z
    if source then x, y, z = source:getX(), source:getY(), source:getZ() end
    local hours = SAO.History.countyHours()
    if not (finite(x) and finite(y) and finite(z) and finite(hours)) then return false, "invalid-return-position" end
    rec.returnTransition = { version = 1, event = event.token,
        token = rec.id .. ":" .. event.token, phase = "preparing", source = kind, destination = kind,
        x = x, y = y, z = z, hours = hours, living = living }
    return true
end

local function stamp(body, state)
    local data = body:getModData()
    data.ZAOForm = state.currentForm or "none"
    data.ZAOFormPerformance = tonumber(state.formPerformance) or 0
    data.ZAOAttributes = ZAO.Pathogen and ZAO.Pathogen.attributeString(state) or ""
    data.ZAOTerminalState = state.terminalState
    data.ZAODormantKnox = state.terminalState == "afflicted" or nil
end

local function commit(rec, p, body, destination)
    rec.hibernation, rec.releasedAtHours = p.packed, SAO.History.countyHours()
    if hibernationVersion(p.packed) >= 4 then rec.bodyVisual = nil
    else rec.bodyVisual = p.visual end
    rec.bodyCheckpointFailure = nil
    rec.woundInfected, rec.hasRadio = p.facts.woundInfected or nil, p.facts.hasRadio == true
    rec.x, rec.y, rec.z = p.x, p.y, p.z
    rec.dead, rec.turnedDormant = false, false
    rec.afflictedReturn, rec.returnedAtHours, rec.returnEvent = true, p.hours, p.event
    rec.knoxInfected, rec.biteDeathAtHours = nil, nil
    rec.deathNewsAt = nil
    -- Activation remains retryable under the phase; callbacks see no body
    -- until both native publication and controller enrollment have succeeded.
    if destination == "loaded" and not SAOJavaBridge:activateReturnBody(body) then
        return false, "activation-pending"
    end
    SAO.Body.returning[rec.id] = nil
    rec.returnTransition = nil
    return true, "returned"
end

local function step(rec)
    local p = rec.returnTransition
    if not p then return true end
    if not dependencies() then return false, "return-owner-unavailable" end
    if not Return.authorized(rec) then
        if p.sourceRemoved then return false, "return-authorization-unavailable" end
        if not SAO.Body.discardReturn(rec) then return false, "stage-cleanup-pending" end
        if p.source == "loaded" then
            local old = ZAO.Controller.returnSource(rec.id)
            if not old or not ZAO.Controller.cancelReturn(rec.id, old, p.token) then
                return false, "source-resume-pending"
            end
        end
        rec.returnTransition = nil
        return false, "authorization-revoked"
    end
    if p.sourceRemoved and (p.destination or p.source) == "dormant" then
        -- Complete the existing temporary shell's teardown. Creating another
        -- shell here would restart deferred cleanup on every retry.
        if not SAO.Body.discardReturn(rec) then return false, "stage-cleanup-pending" end
        return commit(rec, p, nil, "dormant")
    end
    if p.cleanup then
        if not SAO.Body.discardReturn(rec) then return false, "stage-cleanup-pending" end
        p.cleanup = nil
        if p.recapture then
            p.packed, p.visual, p.facts, p.phase, p.recapture = nil, nil, nil, "preparing", nil
        end
    end
    local source
    if p.source == "loaded" and not p.sourceRemoved then
        source = ZAO.Controller.returnSource(rec.id)
        if not source then return false, "source-unavailable" end
        if not SAO.Body.canTransfer(source) then return false, "source-busy" end
        if not ZAO.Controller.holdReturn(rec.id, source, p.token) then return false, "source-hold-pending" end
        p.destination = ZAO.Controller.returnSourceDormant(rec.id, source, p.token)
            and "dormant" or "loaded"
        if p.phase == "preparing" then
            local x, y, z = source:getX(), source:getY(), source:getZ()
            if not (finite(x) and finite(y) and finite(z)) then return false, "invalid-return-position" end
            p.x, p.y, p.z = x, y, z
        end
    end
    local body, reason = SAO.Body.stageReturn(rec)
    if not body then return false, reason end
    if p.phase == "preparing" then
        if not SAOJavaBridge:restoreReturnLiving(body, p.living) then
            p.cleanup = true
            return false, "living-restore-failed"
        end
        if p.source == "dormant" and rec.bodyVisual
            and hibernationVersion(p.living) < 4
            and not SAOJavaBridge:restoreReturnVisual(body, rec.bodyVisual) then
            p.cleanup = true
            return false, "living-visual-restore-failed"
        end
        -- Recovery physiology belongs to the pathogen owner. A successful
        -- body transfer cannot silently substitute a fresh healthy body.
        if not ZAO.Controller.restoreReturnHealth
            or not ZAO.Controller.restoreReturnHealth(rec, body, p.event) then
            return false, "recovery-state-unavailable"
        end
        local packed = source and SAOJavaBridge:captureReturn(source, body)
            or SAOJavaBridge:hibernate(body)
        local visual = SAOJavaBridge:captureReturnVisual(source or body)
        if not SAOJavaBridge:validateHibernation(packed)
            or hibernationVersion(packed) == 0
            or not SAOJavaBridge:validateReturnVisual(visual) then
            p.cleanup = true
            return false, "return-capture-failed"
        end
        if source then p.x, p.y, p.z = source:getX(), source:getY(), source:getZ() end
        p.packed, p.visual, p.phase = packed, visual, "captured"
    end
    if body:getModData().SAOReturnReady ~= p.token then
        if not SAOJavaBridge:restoreReturnLiving(body, p.packed)
            or not SAOJavaBridge:restoreReturnVisual(body, p.visual) then
            p.cleanup = true
            return false, "return-restore-failed"
        end
        body:getModData().SAOReturnReady = p.token
    end
    local state = ZAO.StateStore.read(rec.id)
    if not state then return false, "pathogen-state-unavailable" end
    stamp(body, state)
    if not p.facts then
        p.facts = SAO.Population.captureBodyFacts(rec, body, SAO.History.countyHours())
    end
    if not p.sourceRemoved then
        if source then
            if not SAO.Body.canTransfer(source) then return false, "source-busy" end
            if not SAOJavaBridge:returnMaterialsMatch(source, p.packed, p.visual) then
                p.cleanup, p.recapture = true, true
                return false, "source-changed"
            end
            if not ZAO.Controller.removeReturn(rec.id, source, p.token) then
                return false, "source-removal-pending"
            end
        end
        p.sourceRemoved, p.phase = true, "removed"
    end
    local destination = p.destination or p.source
    if destination == "dormant" then
        if not SAO.Body.discardReturn(rec) then return false, "stage-cleanup-pending" end
    else
        if not SAOJavaBridge:publishReturnBody(body) then return false, "publication-pending" end
        SAO.Body.active[rec.id] = body
        local agent = SAO.Controller.agents[rec.id]
        if agent and (agent.rec ~= rec or agent.passive) then SAO.Controller.drop(rec.id) end
        if SAO.Controller.adopt(rec) ~= true then return false, "adoption-pending" end
        agent = SAO.Controller.agents[rec.id]
        if not agent or agent.rec ~= rec or agent.passive then return false, "adoption-pending" end
    end
    return commit(rec, p, body, destination)
end

function Return.resume(rec)
    local ok, result, reason = pcall(step, rec)
    if not ok then reason, result = "return-step-failed: " .. tostring(result), false end
    local p = rec and rec.returnTransition
    if p and not result and p.lastReason ~= reason then
        p.lastReason = reason
        if SAO.Log and SAO.Log.line then
            SAO.Log.line("RETURN", rec.id .. " " .. tostring(p.phase) .. ": " .. tostring(reason))
        end
    end
    return result, reason
end

function Return.resumePending()
    if running or not dependencies() then return false end
    running = true
    local completed, pending = 0, 0
    local ok = pcall(function()
        for _, rec in pairs(SAO.Identity.all()) do
            if rec.returnTransition then
                if Return.resume(rec) then completed = completed + 1
                else pending = pending + 1 end
            end
        end
    end)
    running = false
    return ok and pending == 0, completed, pending
end

function Return.adopt(day)
    if not dependencies() then return false end
    local adopted = false
    for _, rec in pairs(SAO.Identity.all()) do
        local ok, started = pcall(function()
            if rec.returnTransition then return true end
            return begin(rec)
        end)
        if ok and started then
            local done = Return.resume(rec)
            if done then adopted = true end
        end
    end
    return adopted
end

Events.OnGameStart.Add(function() Return.resumePending() end)

-- [C116] The marks on every live afflicted body, once per county day.
-- The afflicted are not only the returned: a live infected person the
-- pathogen's recovery branch flipped to afflicted never died and
-- needs no adoption - but their live shell carries no marks, and a
-- body without marks reads as a body with nothing on it. The stamp
-- is the pathogen's own state read back onto the body that carries
-- it, on the same cadence the marks decay, so what the scanner
-- reports about a formed person is the form they have TODAY.
function Return.stampLive(day)
    if not (ZAO and ZAO.StateStore and SAO.Body) then
        return false
    end

    local stamped = 0
    for id, body in pairs(SAO.Body.active) do
        id = tostring(id)
        local okState, state = pcall(function()
            return ZAO.StateStore.read(id)
        end)
        if okState and state and SAO.Body.get(id) == body
            and state.terminalState == "afflicted"
            and body then
            local ok = pcall(function()
                local data = body:getModData()
                if type(data) == "table" then
                    data.ZAOForm = state.currentForm or "none"
                    data.ZAOFormPerformance =
                        tonumber(state.formPerformance) or 0.0
                    data.ZAOAttributes = ZAO.Pathogen
                        and ZAO.Pathogen.attributeString(state) or ""
                end
            end)
            if ok then stamped = stamped + 1 end
        end
    end

    return stamped > 0
end

return SAO.AfflictedReturn
