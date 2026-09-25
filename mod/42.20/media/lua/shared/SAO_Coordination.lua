-- SAO_Coordination - one actor-private response policy for every representation.
--
-- Organization owns durable matters, responses and commitments. Communication
-- owns actual reception and return transport. This module owns only the
-- recipient's current appraisal envelope, so the same policy is callable from
-- a loaded controller, a dormant encounter and a headless county episode.

SAO = SAO or {}
SAO.Coordination = SAO.Coordination or {}
local Coordination = SAO.Coordination

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function destinationKnown(proposal)
    local destination = proposal and proposal.destination or nil
    return type(destination) == "table"
        and tonumber(destination.minX) ~= nil
        and tonumber(destination.minY) ~= nil
        and tonumber(destination.maxX) ~= nil
        and tonumber(destination.maxY) ~= nil
end

local function nowHours()
    local value = nil
    pcall(function() value = SAO.History.countyHours() end)
    return finite(value) and value or 0
end

-- Detached contacts assembled only from this person's retained perception and
-- standing.  They are possible addressees, not proof of current location,
-- health, willingness or reachability.
function Coordination.knownContacts(id)
    id = tostring(id or "")
    local contacts = SAO.Perception and SAO.Perception.knownPeople
        and SAO.Perception.knownPeople(id) or {}
    local relations = SAO.Standing and SAO.Standing.relationsOf
        and SAO.Standing.relationsOf(id) or {}
    for _, contact in ipairs(contacts) do
        local relation = relations[contact.id]
            or relations[contact.beliefKey] or {}
        contact.relationship = tonumber(relation.trust) or 0
        contact.hostile = relation.hostile == true
    end
    table.sort(contacts, function(a, b)
        if a.hostile ~= b.hostile then return b.hostile == true end
        if a.relationship ~= b.relationship then
            return a.relationship > b.relationship
        end
        local ah, bh = tonumber(a.observedAtHours) or -math.huge,
            tonumber(b.observedAtHours) or -math.huge
        if ah ~= bh then return ah > bh end
        return a.id < b.id
    end)
    return contacts
end

-- The best privately known address for a current proposal that has not yet
-- reached its named recipient.  Organization supplies only the current
-- addressed envelope; Perception supplies only this originator's retained
-- location.  No current body, liveness, or recipient response is consulted.
function Coordination.pendingContact(id)
    id = tostring(id or "")
    if id == "" or not (SAO.Organization
        and SAO.Organization.pendingProposals) then return nil end
    local eligible = {}
    for _, contact in ipairs(Coordination.knownContacts(id)) do
        local x, y = tonumber(contact.x), tonumber(contact.y)
        local observedAt, lookedAt = tonumber(contact.observedAt),
            tonumber(contact.lookedAt)
        local unspent = not (lookedAt and observedAt and lookedAt >= observedAt)
        if contact.hostile ~= true and x and y and unspent then
            local pending = SAO.Organization.pendingProposals(id, contact.id)
            if #pending > 0 then
                eligible[#eligible + 1] = {
                    processId = pending[1].processId,
                    processRevision = pending[1].processRevision,
                    kind = pending[1].kind,
                    recipientId = contact.id,
                    beliefKey = contact.beliefKey,
                    x = x, y = y,
                    observedAt = observedAt,
                    observedAtHours = contact.observedAtHours,
                    relationship = contact.relationship,
                    source = contact.source,
                }
            end
        end
    end
    -- Trust and activity can reorder several possible recipients while an
    -- actor is already travelling or waiting. That is not a decision to
    -- abandon the current person. Resume the durable attempt first; ranking
    -- selects a recipient only when no attempt is active. A newer private
    -- sighting still changes the address returned to the movement owner, but
    -- it does not make the same proposal/recipient attempt a new social act.
    if SAO.Organization.activeContact then
        for _, candidate in ipairs(eligible) do
            if SAO.Organization.activeContact(candidate.processId, id,
                candidate.recipientId) then return candidate end
        end
    end
    if #eligible > 0 then return eligible[1] end
    return nil
end

local function currentProposal(process, originatorId)
    local view = process and SAO.Organization
        and SAO.Organization.viewFor(originatorId, process.id, false) or nil
    return view and view.proposal and view.proposal.proposal or nil
end

local function nativeRecipients(id, contacts)
    local recipients = {}
    for _, contact in ipairs(contacts or {}) do
        if contact.hostile ~= true then
            recipients[#recipients + 1] = contact.id
            if #recipients >= 3 then break end
        end
    end
    return recipients
end

local function originateNativeSituation(id, body, ownerLabel, contacts)
    if not (SAO.DormantPopulation
        and SAO.DormantPopulation.privateProvisioningSituation
        and SAO.Organization and SAO.Organization.openMatter) then
        return nil, "situation-owner-unavailable"
    end
    local situation, why = SAO.DormantPopulation.privateProvisioningSituation(
        id, body)
    local open = SAO.Organization.openMatter(id, "provisioning")
    if not situation then return open, why or "situation-unavailable" end
    if situation.resolved then
        if open and SAO.Organization.withdrawMatter then
            SAO.Organization.withdrawMatter(open.id, id, "personal-need-resolved", {
                owner = situation.needOwner,
                observedAtHours = situation.observedAtHours,
            })
            return open, "withdrawn"
        end
        return nil, "no-current-pressure"
    end

    local recipients = nativeRecipients(id, contacts)
    if #recipients == 0 and not open then
        return nil, "no-known-recipient"
    end
    local destination = situation.destination
    local band = math.max(1, math.min(4,
        math.ceil((tonumber(situation.pressure) or 0) * 4)))
    local intentKey = table.concat({ tostring(situation.category),
        tostring(destination.minX), tostring(destination.minY),
        tostring(destination.z), tostring(band) }, ":")
    local proposal = {
        intentKey = intentKey,
        requesterId = id,
        category = situation.category,
        quantity = 1,
        purpose = "provisioning under current personal need",
        responsePolicy = "first-completion",
        expiresAtHours = nowHours() + 72,
        destinationRequired = true,
        destination = destination,
        requiredCapabilities = {
            acquire = true, carry = true, deliver = true,
        },
        scope = { action = "deliver-material",
            category = situation.category, quantity = 1 },
    }
    local privateEvidence = {
        source = "private-person-situation",
        owner = ownerLabel or "SAO.Coordination",
        needOwner = situation.needOwner,
        pressure = situation.pressure,
        waterPressure = situation.waterPressure,
        foodPressure = situation.foodPressure,
        represented = situation.represented,
        destinationSource = situation.destinationSource,
        observedAtHours = situation.observedAtHours,
    }
    if open then
        local prior = currentProposal(open, id) or {}
        if tostring(prior.intentKey or "") ~= intentKey then
            open = SAO.Organization.reviseMatter(open.id, id, proposal,
                privateEvidence)
        end
    else
        open = SAO.Organization.raiseMatter(id, "provisioning",
            SAO.Standing and SAO.Standing.groupOf
                and SAO.Standing.groupOf(id) or nil,
            proposal, recipients, privateEvidence)
    end
    if not open then return nil, "matter-refused" end
    if SAO.Organization.addressMatter then
        SAO.Organization.addressMatter(open.id, id, recipients)
    end
    local delivered = 0
    for _, recipientId in ipairs(recipients) do
        local message = SAO.Communication
            and SAO.Communication.deliverProcessProposal
            and SAO.Communication.deliverProcessProposal(id, recipientId,
                open.id, nil, { source = ownerLabel or "SAO.Coordination",
                    proposedAtHours = nowHours() }) or nil
        if message then delivered = delivered + 1 end
    end
    return open, delivered > 0 and "delivered" or "open-unheard"
end

-- Turn a person's own current situation into durable social intent.  Native
-- survivor need is read by its existing owner; an external person is handed
-- back to the registered behavioral owner with only private contacts and
-- common process context.  Neither branch infers reception or completion.
function Coordination.originatePrivateSituation(id, body, activity, ownerLabel)
    id = tostring(id or "")
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if id == "" or not rec or rec.dead then return nil, "actor-unavailable" end
    local contacts = Coordination.knownContacts(id)
    if rec.bodyOwner then
        if not (SAO.Communication and SAO.Communication.actorMatter) then
            return nil, "execution-owner-unavailable"
        end
        return SAO.Communication.actorMatter(id, {
            owner = ownerLabel or "SAO.Coordination",
            currentActivity = tostring(activity or "dormant"),
            knownContacts = contacts,
            atHours = nowHours(),
        })
    end
    return originateNativeSituation(id, body, ownerLabel, contacts)
end

-- Build only from facts available to this recipient now. A registered
-- external owner may replace the bounded appraisal fields, but cannot create a
-- response or commitment itself and cannot pass diagnosis/diet/private state
-- through fields the common envelope does not admit.
function Coordination.privateContext(id, agent, body, request, ownerLabel)
    if not (SAO.Organization and SAO.Organization.viewFor
        and SAO.Identity and SAO.Identity.get) then return nil end
    id = tostring(id or "")
    local processId = request and request.processId or request
    local processView = SAO.Organization.viewFor(id, processId, false)
    if not processView then return nil end
    local proposal = processView.proposal and processView.proposal.proposal or {}
    local rec = SAO.Identity.get(id)
    local execution, executionUnavailable = {}, false
    if rec and rec.bodyOwner and SAO.Communication
        and SAO.Communication.actorSnapshot then
        local snapshot = SAO.Communication.actorSnapshot(id)
        if type(snapshot) == "table" then
            execution = snapshot
        else
            executionUnavailable = true
        end
    end

    local ownNeed, ownNeedAvailable = 0, true
    if rec and rec.bodyOwner == "ZAO" then
        if tonumber(execution.competingPressure) then
            ownNeed = tonumber(execution.competingPressure)
        else
            ownNeed, ownNeedAvailable = 0, false
        end
    elseif body and SAO.Needs and SAO.Needs.read then
        local needs = SAO.Needs.read(body)
        ownNeed = needs and tonumber(needs.hunger) or 0
    elseif rec and SAO.DormantPopulation
        and SAO.DormantPopulation.companyNeedPressure then
        local available = false
        ownNeed, available = SAO.DormantPopulation.companyNeedPressure(id)
        ownNeedAvailable = available == true
    elseif rec then
        ownNeed = tonumber(rec.hunger) or 0
        ownNeedAvailable = rec.hunger ~= nil
    end

    local originator = processView.originatorId
    local relationship, hostile = 0, false
    pcall(function() relationship = SAO.Standing.trust(id, originator) end)
    pcall(function() hostile = SAO.Standing.isHostileTo(id, originator) end)
    local activity = execution.currentActivity
        and string.lower(tostring(execution.currentActivity))
        or agent and string.lower(tostring(agent.state or "idle"))
        or "dormant"
    local knowsDestination = destinationKnown(proposal)
    local designation = rec and rec.designation or nil
    local prior = processView.response
    local choice = nil
    if hostile then
        choice = "contest"
    elseif activity ~= "idle" and activity ~= "dormant" then
        choice = "defer"
    elseif not ownNeedAvailable then
        choice = "defer"
    elseif ownNeed >= 0.75 then
        choice = "qualify"
    elseif knowsDestination and (designation == "forager"
        or designation == "quartermaster" or relationship >= 0.30
        or (SAO.Lessons and SAO.Lessons.has
            and SAO.Lessons.has(id, "people-are-worth-it"))) then
        choice = "accept"
    elseif knowsDestination then
        choice = "counter-propose"
    else
        choice = "defer"
    end

    local represented = body ~= nil
    if execution.represented ~= nil then
        represented = execution.represented == true
    end
    local owner = ownerLabel or "Controller.coordination"
    local context = {
        owner = owner,
        executor = execution.executor or (rec and rec.bodyOwner == "ZAO"
            and "ZAO.Driver" or "SAO.Controller"),
        bodyOwner = execution.bodyOwner or (rec and rec.bodyOwner) or "SAO",
        currentActivity = activity,
        canAcquire = not executionUnavailable
            and execution.canAcquire ~= false and not (rec and rec.dead),
        canCarry = not executionUnavailable
            and execution.canCarry ~= false and not (rec and rec.dead),
        canDeliver = not executionUnavailable
            and execution.canDeliver ~= false and not (rec and rec.dead),
        canExecute = not executionUnavailable
            and execution.canExecute ~= false and not (rec and rec.dead),
        incapable = executionUnavailable or execution.incapable == true,
        dead = execution.dead == true or rec and rec.dead or false,
        contest = hostile,
        ownNeed = ownNeed,
        relationship = relationship,
        destinationKnown = knowsDestination,
        choice = choice,
        reconsider = prior and prior.response == "defer"
            and choice ~= "defer" or false,
        interests = { designation = designation,
            ownGroup = SAO.Standing.groupOf(id) },
        constraints = { represented = represented,
            currentActivity = activity,
            executionOwnerAvailable = not executionUnavailable,
            ownNeedAvailable = ownNeedAvailable },
        inputOwners = {
            currentActivity = execution.executor
                or (rec and rec.bodyOwner == "ZAO" and "ZAO.Driver")
                or "SAO.Controller",
            capabilities = execution.executor
                or (rec and rec.bodyOwner == "ZAO" and "ZAO.Driver")
                or "SAO.Controller",
            ownNeed = rec and rec.bodyOwner == "ZAO"
                and (execution.inputOwners
                    and execution.inputOwners.competingPressure
                    or "ZAO.Driver")
                or body and "SAO.Needs" or "SAO.Identity",
            relationship = "SAO.Standing",
            interests = "SAO.Identity+SAO.Standing",
            constraints = ownerLabel or "SAO.Controller",
        },
    }

    if rec and rec.bodyOwner and SAO.Communication
        and SAO.Communication.actorAppraisal then
        local supplied = SAO.Communication.actorAppraisal(id, processView,
            context)
        if type(supplied) == "table" then
            for _, key in ipairs({ "owner", "executor", "bodyOwner",
                    "currentActivity", "canAcquire", "canCarry",
                    "canDeliver", "canExecute", "incapable", "dead",
                    "contest", "ownNeed", "relationship",
                    "destinationKnown", "choice", "reconsider", "terms",
                    "interests", "constraints", "inputOwners" }) do
                if supplied[key] ~= nil then context[key] = supplied[key] end
            end
        end
    end
    return context
end

function Coordination.formResponse(id, processId, body, activity, ownerLabel)
    if not (SAO.Organization and SAO.Organization.appraiseMatter) then
        return nil, "organization-unavailable"
    end
    id, processId = tostring(id or ""), tostring(processId or "")
    if id == "" or processId == "" then return nil, "invalid-appraisal" end
    local agent = activity and { state = tostring(activity) } or nil
    local context = Coordination.privateContext(id, agent, body,
        { processId = processId }, ownerLabel)
    if not context then return nil, "process-unavailable" end
    return SAO.Organization.appraiseMatter(processId, id, context), context
end

function Coordination.appraisePending(id, body, activity, ownerLabel)
    if not (SAO.Organization and SAO.Organization.pendingAppraisals) then
        return 0
    end
    id = tostring(id or "")
    local formed = 0
    for _, request in ipairs(SAO.Organization.pendingAppraisals(id)) do
        if request.processId and request.processRevision then
            local response, context = Coordination.formResponse(id,
                request.processId, body, activity, ownerLabel)
            if response then formed = formed + 1 end
            -- A formed response remains private until an actual return
            -- transport reaches the originator. Retry an earlier response too.
            local processView = SAO.Organization.viewFor(
                id, request.processId, false)
            local originator = processView and processView.originatorId
            if originator and SAO.Communication
                and SAO.Communication.deliverPendingResponses then
                SAO.Communication.deliverPendingResponses(id, originator,
                    nil, { reply = response and "immediate" or "retry",
                        activity = context and context.currentActivity
                            or tostring(activity or "dormant") })
            end
        end
    end
    return formed
end

Coordination.appraise = Coordination.appraisePending

return Coordination
