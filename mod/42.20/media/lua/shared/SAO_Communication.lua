-- SAO_Communication.lua - claims that pass between people.

SAO = SAO or {}
SAO.Communication = SAO.Communication or {}
local Communication = SAO.Communication

Communication.messages = Communication.messages or {}
-- Runtime-only execution ownership. Durable ownership remains on the Identity
-- record; each owner must actively register how its currently driven human
-- shell and activity snapshot are resolved.
Communication.executionOwners = Communication.executionOwners or {}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function bodyFor(id)
    id = tostring(id or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if rec and rec.bodyOwner then
        local owner = Communication.executionOwners[tostring(rec.bodyOwner)]
        if not owner or type(owner.bodyFor) ~= "function" then return nil end
        local ok, body = pcall(owner.bodyFor, id, rec)
        if ok and body then return body end
        return nil
    end
    local body = SAO.Body and SAO.Body.get and SAO.Body.get(id) or nil
    if not body then
        body = SAO.Body and SAO.Body.active and SAO.Body.active[id] or nil
    end
    if body then return body end
    local ok, player = pcall(function() return (SAO.Participants and SAO.Participants.player or getSpecificPlayer)(0) end)
    if ok and player and SAO.Standing and SAO.Standing.playerKey
        and SAO.Standing.playerKey(player) == id then return player end
    return nil
end

function Communication.registerExecutionOwner(ownerId, adapter)
    ownerId = type(ownerId) == "string" and ownerId or nil
    if not ownerId or ownerId == "" or type(adapter) ~= "table"
        or type(adapter.bodyFor) ~= "function" then return false end
    Communication.executionOwners[ownerId] = adapter
    return true
end

function Communication.unregisterExecutionOwner(ownerId, adapter)
    local existing = Communication.executionOwners[tostring(ownerId or "")]
    if not existing or (adapter ~= nil and existing ~= adapter) then return false end
    Communication.executionOwners[tostring(ownerId)] = nil
    return true
end

-- Body snapshots are shared physical envelopes, but elapsed bodyless
-- physiology belongs to the registered execution owner.  SAO restores an
-- externally owned shell without running survivor hunger/eating and asks the
-- owner to advance its own state before the body becomes observable.
function Communication.advanceExternalDormancy(ownerId, personId, rec, body,
        elapsedHours, atHours)
    ownerId, personId = tostring(ownerId or ""), tostring(personId or "")
    elapsedHours = tonumber(elapsedHours) or 0
    if ownerId == "" or personId == "" or type(rec) ~= "table"
        or body == nil or elapsedHours < 0 then
        return false, "invalid-external-dormancy"
    end
    if elapsedHours == 0 then return true, "no-elapsed-time" end
    local owner = Communication.executionOwners[ownerId]
    if not owner then return false, "execution-owner-unregistered" end
    if type(owner.advanceDormant) ~= "function" then
        return false, "dormant-owner-unavailable"
    end
    local ok, advanced, reason = pcall(owner.advanceDormant, personId, rec,
        body, elapsedHours, tonumber(atHours))
    if not ok then return false, "dormant-owner-exception" end
    if advanced ~= true then
        return false, reason or "dormant-owner-refused"
    end
    return true, reason or "advanced"
end

function Communication.bodyFor(id)
    return bodyFor(id)
end

function Communication.actorSnapshot(id)
    id = tostring(id or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if rec and rec.bodyOwner then
        local owner = Communication.executionOwners[tostring(rec.bodyOwner)]
        if not owner then return nil, "execution-owner-unregistered" end
        if type(owner.snapshot) == "function" then
            local ok, snapshot = pcall(owner.snapshot, id, rec)
            if ok and type(snapshot) == "table" then return snapshot end
        end
        return nil, "execution-snapshot-unavailable"
    end
    local body = bodyFor(id)
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[id] or nil
    return {
        bodyOwner = "SAO",
        represented = body ~= nil,
        currentActivity = agent and string.lower(tostring(agent.state or "idle"))
            or "dormant",
        canAcquire = body ~= nil,
        canCarry = body ~= nil,
        canDeliver = body ~= nil,
    }
end

-- A registered execution owner may interpret an acquired proposal from the
-- actor's private state.  The returned context is still consumed by
-- Organization, which freezes feasible options, choice and provenance; the
-- adapter receives no authority to create a response or commitment itself.
function Communication.actorAppraisal(id, processView, baseContext)
    id = tostring(id or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or not rec.bodyOwner then return nil, "native-owner" end
    local owner = Communication.executionOwners[tostring(rec.bodyOwner)]
    if not owner then return nil, "execution-owner-unregistered" end
    if type(owner.appraiseMatter) ~= "function" then
        return nil, "appraisal-owner-unavailable"
    end
    local ok, context = pcall(owner.appraiseMatter, id, rec, processView,
        type(baseContext) == "table" and baseContext or {})
    if not ok or type(context) ~= "table" then
        return nil, ok and "appraisal-unanswered" or "appraisal-owner-exception"
    end
    return context
end

-- Ask the registered behavioral owner whether this actor's current private
-- situation warrants a social matter.  SAO supplies the process and transport
-- services, but does not substitute survivor need, movement or motivation for
-- an externally owned person.
function Communication.actorMatter(id, context)
    id = tostring(id or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or not rec.bodyOwner then return nil, "native-owner" end
    local owner = Communication.executionOwners[tostring(rec.bodyOwner)]
    if not owner then return nil, "execution-owner-unregistered" end
    if type(owner.originateMatter) ~= "function" then
        return nil, "matter-owner-unavailable"
    end
    local ok, process, status = pcall(owner.originateMatter, id, rec,
        type(context) == "table" and context or {})
    if not ok then return nil, "matter-owner-exception" end
    return process, status or (process and "originated" or "no-matter")
end

-- Continue contact-seeking under an external body's registered owner.  SAO
-- supplies the actor-private address and common county time; the owner alone
-- may move or update its durable execution state.  Reaching an address is not
-- reception--the ordinary encounter transport must still prove that later.
function Communication.actorContactStep(id, candidate, context)
    id = tostring(id or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or not rec.bodyOwner then return nil, "native-owner" end
    local owner = Communication.executionOwners[tostring(rec.bodyOwner)]
    if not owner then return nil, "execution-owner-unregistered" end
    if type(owner.advanceContact) ~= "function" then
        return nil, "contact-owner-unavailable"
    end
    local ok, advanced, status = pcall(owner.advanceContact, id, rec,
        type(candidate) == "table" and candidate or nil,
        type(context) == "table" and context or {})
    if not ok then return nil, "contact-owner-exception" end
    return advanced, status or (advanced and "advanced" or "idle")
end

local function dormantHearing(rec, listener)
    if rec.dormantSleeping == true then return nil, "asleep" end
    if rec.dormantSleeping ~= false then return nil, "sleep-unobserved" end
    if rec.hibernation == nil then
        if rec.speechAccessOrigin == "generated-empty-traits" then return 1 end
        return nil, "hearing-unobserved"
    end
    local ok, access = pcall(function()
        return SAOJavaBridge:hibernationHearingAccess(rec.hibernation)
    end)
    if not ok or type(access) ~= "string" then return nil, "hearing-unavailable" end
    if access == "REFUSED:deaf" then
        if listener then return nil, "deaf" end
        return 1 -- Hearing is not required to speak.
    end
    local amount = tonumber(string.match(access, "^AVAILABLE:([%d%.eE%+%-]+)$"))
    if not amount or amount ~= amount or amount <= 0 or amount == math.huge then
        return nil, "hearing-unavailable"
    end
    return amount
end

-- A transport must establish its listeners before private testimony travels.
-- Loaded speech uses native hearing; dormant speech belongs to a real adjacent
-- encounter in the existing bodyless simulation, with no loaded participant.
function Communication.canConverse(fromId, toId, channel)
    if type(fromId) ~= "string" or type(toId) ~= "string"
        or fromId == toId then return false end
    for _, id in ipairs({ fromId, toId }) do
        local agent = SAO.Controller and SAO.Controller.agents
            and SAO.Controller.agents[id]
        if agent and agent.sleeping then return false end
    end
    if channel == "dormant-encounter" then
        if not (SAO.Identity and SAO.Identity.get and SAO.Body
            and SAO.Body.hasRepresentation) then return false end
        local a, b = SAO.Identity.get(fromId), SAO.Identity.get(toId)
        if not a or not b or a.dead or b.dead
            or SAO.Body.hasRepresentation(fromId)
            or SAO.Body.hasRepresentation(toId)
            or a.sleeping or b.sleeping then return false end
        local speaker, speakerWhy = dormantHearing(a, false)
        if not speaker then return false, speakerWhy end
        local hearing, hearingWhy = dormantHearing(b, true)
        if not hearing then return false, hearingWhy end
        local ax, ay, az = tonumber(a.x), tonumber(a.y), tonumber(a.z)
        local bx, by, bz = tonumber(b.x), tonumber(b.y), tonumber(b.z)
        if not ax or not ay or not az or not bx or not by or not bz
            or az ~= bz then return false end
        local dx, dy = ax - bx, ay - by
        local ok, weather = pcall(function() return SAOJavaBridge:speechWeatherHearing() end)
        if not ok or type(weather) ~= "number" or weather ~= weather
            or weather <= 0 or weather > 1 then return false, "weather-unavailable" end
        local reach = math.min(3, (SAO.Perception and SAO.Perception.EARSHOT or 10)
            * hearing * weather)
        return dx * dx + dy * dy <= reach * reach
    end
    if channel ~= nil then return false end
    local a, b = bodyFor(fromId), bodyFor(toId)
    if not a or not b then return false end
    local ok, heard = pcall(function()
        return SAOJavaBridge:canConverseNow(a, b,
            SAO.Perception and SAO.Perception.EARSHOT or 10)
    end)
    return ok and heard == true
end

local function radioDetails(access, representation)
    if type(access) ~= "string" then return nil, "device-unavailable" end
    local itemId, fullType, channel, power = string.match(access,
        "^AVAILABLE:(%-?%d+):([^:]+):(%d+):([%d%.eE%+%-]+)$")
    itemId, channel, power = tonumber(itemId), tonumber(channel), tonumber(power)
    if not itemId or type(fullType) ~= "string" or fullType == ""
        or not channel or not finite(power) or power < 0 or power > 1.000001 then
        return nil, string.match(access, "^REFUSED:(.+)$")
            or "device-unavailable"
    end
    return { representation = representation, deviceItemId = itemId,
        deviceType = fullType, channel = channel, power = power }
end

local function radioHour(value)
    local ok, now = pcall(function() return SAO.History.countyHours() end)
    if not ok or not finite(now) or now < 0 then return nil end
    if value == nil then return now end
    local at = tonumber(value)
    if not finite(at) or at < 0 or math.abs(at - now) > 0.000001 then
        return nil
    end
    return now
end

-- A receiver is an endpoint at an event, not an ownership flag. Loaded
-- access reads the current direct-root DeviceData. Dormant access first
-- advances the checkpointed battery state to the event hour and then admits
-- the same device predicates. Legacy possession-only records stay unknown.
function Communication.radioReceiverAccess(id, frequency, atHours, body)
    if type(id) ~= "string" then return nil, "invalid-radio-event" end
    frequency, atHours = tonumber(frequency), radioHour(atHours)
    if id == "" or not frequency or frequency ~= math.floor(frequency)
        or not atHours or not SAOJavaBridge then
        return nil, "invalid-radio-event"
    end
    local resolved = bodyFor(id)
    if body and resolved ~= body then return nil, "body-mismatch" end
    body = resolved
    if body then
        local agent = SAO.Controller and SAO.Controller.agents
            and SAO.Controller.agents[id]
        if agent and agent.sleeping then return nil, "asleep" end
        local okBody, awake = pcall(function()
            return SAOJavaBridge:canReceiveRadioNow(body)
        end)
        if not okBody or awake ~= true then return nil, "cannot-hear-now" end
        local okDevice, access = pcall(function()
            return SAOJavaBridge:loadedRadioReceiverAccess(body, frequency)
        end)
        if not okDevice then return nil, "device-unavailable" end
        return radioDetails(access, "loaded")
    end
    if not (SAO.Identity and SAO.Identity.get and SAO.Body
        and SAO.Body.hasRepresentation) then return nil, "record-unavailable" end
    local rec = SAO.Identity.get(id)
    if not rec or rec.dead then return nil, "dead-or-missing" end
    if SAO.Body.hasRepresentation(id) then return nil, "body-unavailable" end
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[id]
    if agent and agent.sleeping then return nil, "asleep" end
    local hearing, hearingWhy = dormantHearing(rec, true)
    if not hearing then return nil, hearingWhy end
    local capturedAt = tonumber(rec.radioStateAtHours)
    if type(rec.radioState) ~= "string" or rec.radioState == ""
        or not finite(capturedAt) or capturedAt < 0 or capturedAt > atHours then
        return nil, "receiver-unobserved"
    end
    local okAdvance, advanced = pcall(function()
        return SAOJavaBridge:advanceDormantRadioState(
            rec.radioState, atHours - capturedAt)
    end)
    if not okAdvance or type(advanced) ~= "string" or advanced == ""
        or SAOJavaBridge:validateRadioState(advanced) ~= true then
        return nil, "receiver-state-unavailable"
    end
    -- The advancement is physical passage of time and remains true whether or
    -- not this broadcast finds a usable receiver.
    rec.radioState = advanced
    rec.radioStateAtHours = atHours
    local okDevice, access = pcall(function()
        return SAOJavaBridge:dormantRadioReceiverAccess(advanced, frequency)
    end)
    if not okDevice then return nil, "device-unavailable" end
    return radioDetails(access, "dormant")
end

function Communication.radioTransmitterAccess(id, frequency, body)
    if type(id) ~= "string" then return nil, "invalid-transmitter" end
    frequency = tonumber(frequency)
    local resolved = bodyFor(id)
    if body and resolved ~= body then return nil, "body-mismatch" end
    body = resolved
    if id == "" or not body or not frequency
        or frequency ~= math.floor(frequency) or not SAOJavaBridge then
        return nil, "invalid-transmitter"
    end
    local agent = SAO.Controller and SAO.Controller.agents
        and SAO.Controller.agents[id]
    if agent and agent.sleeping then return nil, "asleep" end
    local okBody, awake = pcall(function()
        return SAOJavaBridge:canTransmitRadioNow(body)
    end)
    if not okBody or awake ~= true then return nil, "cannot-transmit-now" end
    local okDevice, access = pcall(function()
        return SAOJavaBridge:loadedRadioTransmitterAccess(body, frequency)
    end)
    if not okDevice then return nil, "device-unavailable" end
    return radioDetails(access, "loaded")
end

function Communication.radioReception(id, broadcastId, frequency, atHours,
        items, body, sourceId)
    sourceId = sourceId or "county-wire"
    if type(id) ~= "string" or id == ""
        or type(broadcastId) ~= "string" or broadcastId == ""
        or type(sourceId) ~= "string" or sourceId == "" then
        return false, "invalid-radio-event"
    end
    local eventAt = radioHour(atHours)
    if not eventAt then return false, "invalid-radio-event" end
    local access, why = Communication.radioReceiverAccess(
        id, frequency, eventAt, body)
    if not access then return false, why end
    if not (SAO.Perception and SAO.Perception.recordRadioReception) then
        return false, "perception-unavailable"
    end
    local accepted, receipt = SAO.Perception.recordRadioReception(
        id, broadcastId, sourceId, tonumber(frequency),
        eventAt, access, items)
    if accepted ~= true then return false, receipt or "receipt-refused" end
    return true, receipt
end

function Communication.send(fromId, toId, kind, payload)
    if type(fromId) ~= "string" or type(toId) ~= "string"
        or type(kind) ~= "string" then
        return nil
    end
    local message = {
        from = fromId,
        to = toId,
        kind = kind,
        payload = payload,
        at = SAO.History and SAO.History.countyHours() or 0,
        delivered = false,
    }
    Communication.messages[#Communication.messages + 1] = message
    return message
end

local function admittedConversation(fromId, toId, requestedChannel)
    if requestedChannel == "dormant-encounter" then
        local admitted, why = Communication.canConverse(fromId, toId,
            "dormant-encounter")
        return admitted == true and "dormant-encounter" or nil, why
    end
    local admitted, why = Communication.canConverse(fromId, toId)
    if admitted == true then return "spoken" end
    if requestedChannel == "spoken" then return nil, why end
    admitted, why = Communication.canConverse(fromId, toId,
        "dormant-encounter")
    if admitted == true then return "dormant-encounter" end
    return nil, why or "transport-refused"
end

-- Send the current revision to one addressed person through an actual speech
-- or dormant-encounter transport.  This is the high-level path producers use;
-- generic send/deliver deliberately remains insufficient evidence.
function Communication.deliverProcessProposal(fromId, toId, processId,
        requestedChannel, evidence)
    fromId, toId, processId = tostring(fromId or ""), tostring(toId or ""),
        tostring(processId or "")
    if fromId == "" or toId == "" or processId == ""
        or not (SAO.Organization and SAO.Organization.transportRevision) then
        return nil, "invalid-process-proposal"
    end
    local revision, kind = SAO.Organization.transportRevision(
        processId, fromId, toId)
    if not revision then return nil, kind or "not-addressed" end
    local channel, why = admittedConversation(fromId, toId, requestedChannel)
    if not channel then return nil, why or "transport-refused" end
    local message = Communication.send(fromId, toId, "process-proposal", {
        processId = processId, revision = revision, kind = kind,
    })
    if not message then return nil, "message-refused" end
    message.transportAdmitted = true
    message.channel = channel
    message.transportEvidence = type(evidence) == "table" and evidence or {}
    if Communication.deliver(message) ~= true then
        return nil, "delivery-refused"
    end
    return message, "received"
end

-- Carry every currently addressed revision between these two people through
-- the same admitted channel.  Addressing remains durable intent; this call is
-- the separate event that can turn it into reception.
function Communication.deliverPendingProposals(fromId, toId, channel, evidence)
    if not (SAO.Organization and SAO.Organization.pendingProposals) then
        return 0
    end
    local delivered = 0
    for _, pending in ipairs(SAO.Organization.pendingProposals(fromId, toId)) do
        local message = Communication.deliverProcessProposal(fromId, toId,
            pending.processId, channel, evidence)
        if message then delivered = delivered + 1 end
    end
    return delivered
end

function Communication.deliver(message)
    if type(message) ~= "table" then return false end
    message.delivered = true
    if SAO.Organization and message.kind == "claim"
        and type(message.payload) == "table"
        and type(message.payload.kind) == "string" then
        SAO.Organization.recordClaim(
            message.from,
            message.payload.kind,
            message.payload.target,
            message.payload.organization
        )
    end
    -- A process envelope remains only a message unless its transport supplied
    -- explicit reception evidence. Generic delivery never means heard or
    -- accepted and therefore creates no response or commitment.
    if SAO.Organization and message.kind == "process-proposal"
        and type(message.payload) == "table"
        and message.transportAdmitted == true then
        SAO.Organization.recordReception(message.payload.processId,
            message.to, message.payload.revision,
            message.channel or "communication", message.from,
            message.transportEvidence or {})
    end
    -- [C105] Delivered is done: the fact now lives where it was
    -- recorded, and the carrier does not hoard spent messages -
    -- a county that talks for years must not grow a wire that
    -- never shortens.
    for i, m in ipairs(Communication.messages) do
        if m == message then
            table.remove(Communication.messages, i)
            break
        end
    end
    return true
end

-- A threat is communication only when the ordinary speech transport admits
-- it.  Delivery does not disclose the recipient's private fear and does not
-- imply compliance.  The recipient's execution owner may register the event;
-- callers receive only a public reception status and must observe later
-- conduct or a completed material receipt for any consequence.
function Communication.deliverThreat(fromId, toId, threatToken, evidence)
    fromId, toId = tostring(fromId or ""), tostring(toId or "")
    threatToken = tostring(threatToken or "")
    if fromId == "" or toId == "" or threatToken == "" then
        return nil, "invalid-threat"
    end
    local admitted, why = Communication.canConverse(fromId, toId)
    if admitted ~= true then return nil, why or "transport-refused" end
    local message = Communication.send(fromId, toId, "threat", {
        threatToken = threatToken,
        evidence = type(evidence) == "table" and evidence or {},
    })
    if not message then return nil, "message-refused" end
    message.transportAdmitted = true
    message.channel = "spoken"
    message.transportEvidence = {
        heard = true,
        proximity = type(evidence) == "table" and evidence.proximity or nil,
    }
    if Communication.deliver(message) ~= true then
        return nil, "delivery-refused"
    end

    local registered, response = false, "unanswered"
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(toId)
        or nil
    local owner = rec and rec.bodyOwner
        and Communication.executionOwners[tostring(rec.bodyOwner)] or nil
    local receiver = owner and owner.receiveThreat
        or SAO.Controller and SAO.Controller.receiveThreat or nil
    if type(receiver) == "function" then
        local ok, accepted, publicResponse = pcall(receiver, toId, fromId,
            threatToken, type(evidence) == "table" and evidence or {})
        registered = ok and accepted == true
        if registered and type(publicResponse) == "string"
            and publicResponse ~= "" then response = publicResponse end
    end
    return {
        version = 1,
        token = threatToken,
        fromId = fromId,
        toId = toId,
        delivered = true,
        channel = "spoken",
        receivedByOwner = registered,
        response = response,
        atHours = message.at,
    }
end

-- A later query can expose conduct caused by the admitted event, never the
-- recipient's hidden moodles or appraisal inputs.  Absence remains unanswered.
function Communication.observeThreatResponse(toId, fromId, threatToken)
    toId, fromId, threatToken = tostring(toId or ""), tostring(fromId or ""),
        tostring(threatToken or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(toId)
        or nil
    local owner = rec and rec.bodyOwner
        and Communication.executionOwners[tostring(rec.bodyOwner)] or nil
    local observer = owner and owner.observeThreatResponse
        or SAO.Controller and SAO.Controller.observeThreatResponse or nil
    if type(observer) ~= "function" then return nil, "owner-unavailable" end
    local ok, result = pcall(observer, toId, fromId, threatToken)
    if not ok or type(result) ~= "table" then
        return nil, ok and "unanswered" or "owner-exception"
    end
    return result
end

-- Return already-formed answers during an actual bidirectional exchange.
-- The caller names the same admitted channel that carried the conversation;
-- this function rechecks it rather than treating a queued message as proof.
function Communication.deliverPendingResponses(fromId, toId, channel, evidence)
    if not (SAO.Organization and SAO.Organization.pendingResponses) then return 0 end
    local admitted = admittedConversation(fromId, toId, channel)
    if not admitted then return 0 end
    local delivered = 0
    for _, pending in ipairs(SAO.Organization.pendingResponses(fromId, toId)) do
        if SAO.Organization.deliverResponse(pending.processId, fromId, toId,
            admitted, evidence or {}) then
            delivered = delivered + 1
        end
    end
    return delivered
end

-- One proved conversation carries outstanding proposals in both directions,
-- lets each recipient form only their own appraisal, then attempts the return
-- path while the same channel is still present.  Silence and failed transport
-- remain visible because no row is synthesized when any stage is unavailable.
function Communication.exchangeProcesses(firstId, secondId, channel, evidence)
    firstId, secondId = tostring(firstId or ""), tostring(secondId or "")
    if firstId == "" or secondId == "" or firstId == secondId then
        return nil, "invalid-participants"
    end
    local admitted, why = admittedConversation(firstId, secondId, channel)
    if not admitted then return nil, why or "transport-refused" end
    local carried = Communication.deliverPendingProposals(firstId, secondId,
        channel, evidence) + Communication.deliverPendingProposals(secondId,
        firstId, channel, evidence)
    local appraised = 0
    if SAO.Coordination and SAO.Coordination.appraisePending then
        for _, id in ipairs({ firstId, secondId }) do
            local snapshot = Communication.actorSnapshot(id) or {}
            appraised = appraised + (SAO.Coordination.appraisePending(id,
                bodyFor(id), snapshot.currentActivity or "dormant",
                "Communication.exchangeProcesses") or 0)
        end
    end
    local returned = Communication.deliverPendingResponses(firstId, secondId,
        channel, evidence) + Communication.deliverPendingResponses(secondId,
        firstId, channel, evidence)
    return { channel = admitted, proposals = carried,
        appraisals = appraised, responses = returned }, "exchanged"
end

function Communication.pendingFor(id)
    local pending = {}
    for _, message in ipairs(Communication.messages) do
        if message.to == id and not message.delivered then
            pending[#pending + 1] = message
        end
    end
    return pending
end

return Communication
