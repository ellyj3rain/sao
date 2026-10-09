-- SAO_Coordination - one actor-private response policy for every representation.
--
-- Organization owns durable matters, responses and commitments. Communication
-- owns actual reception and return transport. This module owns only the
-- recipient's current appraisal envelope, so the same policy is callable from
-- a loaded controller, a dormant encounter and a headless county episode.

SAO = SAO or {}
SAO.Coordination = SAO.Coordination or {}
local Coordination = SAO.Coordination
local MIN_FALLBACK_VECTOR = 0.1
local MIN_TACTICAL_FALLBACK_SEPARATION_SQUARED = 16
local participationAuthority
function Coordination.participationAuthority(kind, id, processId, value)
    local row = participationAuthority
    return row and row.kind == kind and row.id == id and row.processId == processId
        and (value == nil or row.value == value) or false
end

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

local function materialDeliveryProcedure(category)
    local procedure = {
        { id = "acquire-material", verb = "acquire", domain = "material",
            role = "provisioner", capability = "acquire", owner = "actor",
            maxActors = 1, completesOn = "source:acquire" },
    }
    local prepared = "acquire-material"
    if category == "food" then
        procedure[#procedure + 1] = {
            id = "prepare-material", verb = "prepare", domain = "material",
            role = "provisioner", capability = "prepare", owner = "actor",
            maxActors = 1, sameActorAs = "acquire-material",
            dependsOn = { "acquire-material" },
            completesOn = "cooking:prepared",
        }
        prepared = "prepare-material"
    end
    procedure[#procedure + 1] = {
        id = "carry-material", verb = "carry", domain = "material",
        role = "provisioner", capability = "carry", owner = "actor",
        maxActors = 1, sameActorAs = "acquire-material", required = false,
        dependsOn = { prepared }, completesOn = "route:carrying",
    }
    procedure[#procedure + 1] = {
        id = "deliver-material", verb = "deliver", domain = "material",
        role = "provisioner", capability = "deliver", owner = "actor",
        maxActors = 1, sameActorAs = "acquire-material",
        dependsOn = { prepared },
        completesOn = { "source:store", "handover:completed" },
    }
    return procedure
end

local function authoredStepContext(originatorId, proposal, privateEvidence)
    local requested = type(proposal.originatorStepIds) == "table"
        and proposal.originatorStepIds or {}
    if #requested == 0 then return nil end
    local wanted, capabilities = {}, {}
    local supplied = type(privateEvidence) == "table"
        and type(privateEvidence.originatorCapabilities) == "table"
        and privateEvidence.originatorCapabilities or {}
    for _, stepId in ipairs(requested) do wanted[tostring(stepId)] = true end
    for _, step in ipairs(type(proposal.procedure) == "table"
            and proposal.procedure or {}) do
        if wanted[tostring(step.id)]
            and tostring(step.assignedTo or "") == originatorId then
            local capability = tostring(step.capability or step.verb)
            if supplied[capability] == true then capabilities[capability] = true end
        end
    end
    return { stepIds = requested, maxProcedureSteps = #requested,
        capabilities = capabilities,
        evidence = { source = "authored-cooperative-role",
            privateBasis = privateEvidence and privateEvidence.source or nil } }
end

local function commitAuthoredSteps(originatorId, process, proposal,
        privateEvidence)
    if not (process and SAO.Organization
        and SAO.Organization.commitOriginator) then return nil end
    local context = authoredStepContext(originatorId, proposal, privateEvidence)
    if not context then return nil end
    return SAO.Organization.commitOriginator(process.id, originatorId, context)
end

local function recipientIds(values, originatorId)
    local out, seen = {}, {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        local id = tostring(value or "")
        if id ~= "" and id ~= originatorId and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
            if #out >= 12 then break end
        end
    end
    return out
end

-- An actor-facing cognition owner may author material, movement, posture and
-- action steps through one contract. This function records and transports the
-- proposal; it does not choose roles for recipients or execute any step.
function Coordination.proposeCooperation(originatorId, kind, proposal,
        recipients, privateEvidence)
    originatorId = tostring(originatorId or "")
    kind = tostring(kind or "cooperative-action")
    if originatorId == "" or type(proposal) ~= "table"
        or type(proposal.procedure) ~= "table"
        or not (SAO.Organization and SAO.Organization.raiseMatter) then
        return nil, "invalid-cooperative-proposal"
    end
    local addressed = recipientIds(recipients, originatorId)
    if #addressed == 0 then return nil, "no-addressed-participants" end
    local terms = {}
    for key, value in pairs(proposal) do terms[key] = value end
    terms.cooperative = true
    terms.responsePolicy = "procedure-completion"
    local process, why = SAO.Organization.raiseMatter(originatorId, kind,
        proposal.organizationId, terms, addressed, privateEvidence)
    if not process then return nil, why or "proposal-refused" end
    local authored, authoredWhy = commitAuthoredSteps(originatorId, process,
        terms, privateEvidence)
    if type(terms.originatorStepIds) == "table" and not authored then
        if SAO.Organization.withdrawMatter then
            SAO.Organization.withdrawMatter(process.id, originatorId,
                "originator-role-refused", { reason = authoredWhy })
        end
        return nil, authoredWhy or "originator-role-refused"
    end
    local delivered = 0
    for _, recipientId in ipairs(addressed) do
        local message = SAO.Communication
            and SAO.Communication.deliverProcessProposal
            and SAO.Communication.deliverProcessProposal(originatorId,
                recipientId, process.id, nil, {
                    source = "SAO.Coordination.proposeCooperation",
                    proposedAtHours = nowHours() }) or nil
        if message then delivered = delivered + 1 end
    end
    return process, delivered > 0 and "delivered" or "open-unheard"
end

function Coordination.reviseCooperation(originatorId, processId, proposal,
        recipients, privateEvidence)
    originatorId, processId = tostring(originatorId or ""),
        tostring(processId or "")
    if originatorId == "" or processId == "" or type(proposal) ~= "table"
        or not (SAO.Organization and SAO.Organization.reviseMatter) then
        return nil, "invalid-cooperative-revision"
    end
    local terms = {}
    for key, value in pairs(proposal) do terms[key] = value end
    terms.cooperative = true
    terms.responsePolicy = "procedure-completion"
    local process, why = SAO.Organization.reviseMatter(processId,
        originatorId, terms, privateEvidence)
    if not process then return nil, why or "revision-refused" end
    local authored, authoredWhy = commitAuthoredSteps(originatorId, process,
        terms, privateEvidence)
    if type(terms.originatorStepIds) == "table" and not authored then
        if SAO.Organization.withdrawMatter then
            SAO.Organization.withdrawMatter(process.id, originatorId,
                "originator-role-refused", { reason = authoredWhy })
        end
        return nil, authoredWhy or "originator-role-refused"
    end
    local addressed = recipientIds(recipients, originatorId)
    SAO.Organization.addressMatter(process.id, originatorId, addressed)
    local delivered = 0
    for _, recipientId in ipairs(addressed) do
        local message = SAO.Communication
            and SAO.Communication.deliverProcessProposal
            and SAO.Communication.deliverProcessProposal(originatorId,
                recipientId, process.id, nil, {
                    source = "SAO.Coordination.reviseCooperation",
                    proposedAtHours = nowHours() }) or nil
        if message then delivered = delivered + 1 end
    end
    return process, delivered > 0 and "delivered" or "open-unheard"
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
            if #recipients >= 6 then break end
        end
    end
    return recipients
end

local function blockedResourceSituation(id, situation)
    if not (situation and situation.resolved and SAO.ProceduralPlanning
        and SAO.ProceduralPlanning.resourceDemand) then return situation end
    local now = nowHours()
    local selected
    for _, category in ipairs({ "water", "food" }) do
        local purpose = SAO.ProceduralPlanning.resourceDemand(id, category)
        local demand = purpose and purpose.demand
        local assessedAt = purpose and tonumber(purpose.assessedAt)
        local pressure = demand and tonumber(demand.pressure)
        local owned = demand and tonumber(category == "food"
            and demand.ownedReady or demand.ownedWater)
        local missingMeans = false
        for _, blocker in ipairs(purpose and purpose.blockers or {}) do
            if blocker == "no-known-executable-resource-route"
                or blocker == "owned-raw-identity-unavailable" then missingMeans = true end
        end
        -- A current unmet private goal can prompt a request before immediate
        -- deprivation. Old plans, held usable stock, admitted work and body
        -- unavailability do not establish that someone else must provision it.
        if purpose and purpose.status == "blocked" and missingMeans
            and not purpose.admission and assessedAt and pressure and owned
            and pressure >= 0.2 and pressure <= 1 and owned == 0
            and now >= assessedAt and now - assessedAt <= 1 then
            if not selected or pressure > selected.pressure then
                selected = { purpose = purpose, category = category,
                    pressure = pressure, assessedAt = assessedAt, demand = demand }
            end
        end
    end
    if selected then
        local anticipated = {}
        for key, value in pairs(situation) do anticipated[key] = value end
        anticipated.resolved, anticipated.category = false, selected.category
        anticipated.pressure, anticipated.resourcePurposeId = selected.pressure, selected.purpose.id
        anticipated.observedAtHours = selected.assessedAt
        anticipated.needOwner = "SAO.ProceduralPlanning+SAO.Labor"
        anticipated.demandBasis = selected.demand.basis
        anticipated.uncertainty = selected.demand.uncertainty
        return anticipated
    end
    return situation
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
    situation = blockedResourceSituation(id, situation)
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
    if situation.resourcePurposeId then
        intentKey = intentKey .. ":purpose:" .. tostring(situation.resourcePurposeId)
    end
    local proposal = {
        intentKey = intentKey,
        requesterId = id,
        category = situation.category,
        quantity = 1,
        purpose = situation.resourcePurposeId and "help with an unmet private resource goal"
            or "provisioning under current personal need",
        resourcePurposeId = situation.resourcePurposeId,
        cooperative = true,
        responsePolicy = "procedure-completion",
        expiresAtHours = nowHours() + 72,
        destinationRequired = true,
        destination = destination,
        requiredCapabilities = {
            acquire = true, carry = true, deliver = true,
        },
        continuityOwner = true,
        procedure = materialDeliveryProcedure(situation.category),
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
        resourcePurposeId = situation.resourcePurposeId,
        demandBasis = situation.demandBasis,
        uncertainty = situation.uncertainty,
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

local function tacticalDestination(id, situation)
    local position, threat = situation and situation.position,
        situation and situation.threat
    local px, py = position and tonumber(position.x), position and tonumber(position.y)
    local tx, ty = threat and tonumber(threat.x), threat and tonumber(threat.y)
    if not (px and py and tx and ty) then return nil end
    -- [C95] Known cover, broken sight lines and familiar routes outrank a
    -- geometric retreat. The planning store is person-private, so another
    -- survivor's map cannot silently choose this person's ground.
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.chooseFallback then
        local known = SAO.ProceduralPlanning.chooseFallback(id, situation)
        if known then
            return { x = math.floor(known.x), y = math.floor(known.y),
                z = math.floor(tonumber(known.z) or 0),
                spatialFact = known.key, source = "private-spatial-knowledge" }
        end
    end
    local dx, dy = px - tx, py - ty
    local length = math.sqrt(dx * dx + dy * dy)
    if length < MIN_FALLBACK_VECTOR then dx, dy, length = 1, 0, 1 end
    local distance = 6 + math.min(6,
        math.max(1, math.floor(tonumber(situation.threatCount) or 1)))
    return { x = math.floor(px + dx / length * distance),
        y = math.floor(py + dy / length * distance),
        z = math.floor(tonumber(position.z) or 0) }
end

local function tacticalProcedure(id, situation, recipientCount, fallback)
    local threat = situation.threat
    fallback = fallback or tacticalDestination(id, situation)
    if not fallback then return nil end
    local threatTarget = { x = tonumber(threat.x), y = tonumber(threat.y),
        z = math.floor(tonumber(threat.z) or tonumber(situation.position.z) or 0) }
    local movers = math.max(1, math.min(2, recipientCount))
    return {
        { id = "watch-threat", verb = "watch", domain = "posture",
            role = "watch", capability = "watch", owner = "Posture",
            assignedTo = id, target = threatTarget, posture = "watch",
            durationSeconds = 3, completesOn = "posture:maintained" },
        { id = "move-fallback", verb = "move", domain = "movement",
            role = "withdraw", capability = "move", owner = "Locomotion",
            target = fallback, minActors = movers, maxActors = movers,
            completesOn = "route:travelling" },
        { id = "cover-movement", verb = "cover", domain = "posture",
            role = "cover", capability = "hold", owner = "Posture",
            target = threatTarget, posture = "cover", required = false,
            durationSeconds = 3, maxActors = 1,
            completesOn = "posture:maintained" },
    }, fallback
end

local function originateTacticalSituation(id, ownerLabel, contacts, situation)
    if type(situation) ~= "table" or type(situation.threat) ~= "table"
        or not (SAO.Organization and SAO.Organization.openMatter) then
        return nil, "no-current-tactical-pressure"
    end
    local recipients = nativeRecipients(id, contacts)
    if #recipients == 0 then return nil, "no-known-recipient" end
    local threat = situation.threat
    local function context(target, count)
        return table.concat({ "threat", tostring(math.floor((tonumber(target.x) or 0) / 4)),
            tostring(math.floor((tonumber(target.y) or 0) / 4)),
            tostring(math.floor(tonumber(target.z) or 0)),
            tostring(math.min(4, math.max(1, math.floor(tonumber(count) or 1)))) }, ":")
    end
    local situationKey = context(threat, situation.threatCount)
    local open = SAO.Organization.openMatter(id, "strategic-cooperation")
    local prior = open and currentProposal(open, id) or nil
    local candidate = tacticalDestination(id, situation)
    if not candidate then return nil, "fallback-unavailable" end
    local needsRevision = false
    local sameEvidence = true
    local outcomes = open and SAO.Organization.viewFor(id, open.id, true)
    for _, commitment in pairs(outcomes and outcomes.commitments or {}) do
        if commitment.work and (commitment.work.phase == "awaiting-revision"
            or commitment.work.phase == "step-failed") then
            needsRevision = true
        end
    end
    if prior and type(prior.procedure) == "table" then
        local watch, fallback
        for _, step in ipairs(prior.procedure) do
            if step.id == "watch-threat" then watch = step.target end
            if step.id == "move-fallback" then fallback = step.target end
        end
        local priorKey = watch and context(watch, prior.scope and prior.scope.threatCount)
        local dx = fallback and tonumber(fallback.x) and tonumber(threat.x)
            and fallback.x - tonumber(threat.x)
        local dy = fallback and tonumber(fallback.y) and tonumber(threat.y)
            and fallback.y - tonumber(threat.y)
        -- Actor motion does not revise already proposed ground. Changed private
        -- danger, floor or danger at that ground returns the matter to appraisal.
        sameEvidence = (prior.scope and prior.scope.spatialFact) == candidate.spatialFact
            and (prior.scope and prior.scope.fallbackSource) == (candidate.source or "geometric-emergency")
        if candidate.spatialFact and fallback then
            sameEvidence = sameEvidence and fallback.x == candidate.x
                and fallback.y == candidate.y and fallback.z == candidate.z
        end
        if not needsRevision and sameEvidence and priorKey == situationKey
            and dx and dy and dx * dx + dy * dy >= MIN_TACTICAL_FALLBACK_SEPARATION_SQUARED
            and tonumber(fallback.z) == math.floor(tonumber(situation.position and situation.position.z) or 0) then
            return open, "continuing"
        end
    end
    local procedure, fallback = tacticalProcedure(id, situation, #recipients, candidate)
    if not procedure then return nil, "fallback-unavailable" end
    local intentKey = table.concat({ situationKey,
        tostring(fallback.x), tostring(fallback.y), tostring(fallback.z),
        tostring(math.min(4, math.max(1,
            math.floor(tonumber(situation.threatCount) or 1)))) }, ":")
    local proposal = {
        intentKey = intentKey, cooperative = true,
        responsePolicy = "procedure-completion",
        objective = "watch a known threat while people move to fallback ground",
        expiresAtHours = nowHours() + 12,
        destinationRequired = true,
        destination = { minX = fallback.x - 2, minY = fallback.y - 2,
            maxX = fallback.x + 2, maxY = fallback.y + 2, z = fallback.z },
        originatorStepIds = { "watch-threat" },
        procedure = procedure,
        scope = { action = "tactical-withdrawal",
            threatCount = tonumber(situation.threatCount) or 1,
            spatialFact = fallback.spatialFact,
            fallbackSource = fallback.source or "geometric-emergency" },
    }
    local evidence = { source = "private-perceived-threat",
        owner = ownerLabel or "SAO.Coordination",
        threatSource = threat.source, threatAt = threat.at,
        threatDistance = threat.dist, threatCount = situation.threatCount,
        originatorCapabilities = { watch = SAO.Posture ~= nil },
        fallbackSource = fallback.source or "geometric-emergency",
        spatialFact = fallback.spatialFact, observedAtHours = nowHours() }
    if open then
        local prior = currentProposal(open, id) or {}
        if not needsRevision and sameEvidence and tostring(prior.intentKey or "") == intentKey then
            return open, "continuing"
        end
        return Coordination.reviseCooperation(id, open.id, proposal,
            recipients, evidence)
    end
    return Coordination.proposeCooperation(id, "strategic-cooperation",
        proposal, recipients, evidence)
end

-- Turn a person's own current situation into durable social intent.  Native
-- survivor need is read by its existing owner; an external person is handed
-- back to the registered behavioral owner with only private contacts and
-- common process context.  Neither branch infers reception or completion.
function Coordination.originatePrivateSituation(id, body, activity, ownerLabel,
        situation)
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
    local tactical, tacticalWhy = originateTacticalSituation(id, ownerLabel,
        contacts, situation)
    if tactical then return tactical, tacticalWhy end
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
    local aliveAndOwned = not executionUnavailable and not (rec and rec.dead)
    local capabilities = type(execution.capabilities) == "table"
        and execution.capabilities or {
            acquire = execution.canAcquire ~= false and aliveAndOwned,
            carry = execution.canCarry ~= false and aliveAndOwned,
            deliver = execution.canDeliver ~= false and aliveAndOwned,
            execute = execution.canExecute ~= false and aliveAndOwned,
            move = execution.canMove ~= false and aliveAndOwned,
            hold = execution.canHold ~= false and aliveAndOwned,
            watch = execution.canWatch ~= false and aliveAndOwned,
            escort = execution.canEscort ~= false and aliveAndOwned,
            withdraw = execution.canMove ~= false and aliveAndOwned,
            prepare = execution.canPrepare ~= false and aliveAndOwned
                and SAO.Cooking ~= nil,
        }
    local preferredRoles = {}
    if designation == "watch" then
        preferredRoles.watch, preferredRoles.cover,
            preferredRoles.patrol = true, true, true
    elseif designation == "forager" then
        preferredRoles.scout, preferredRoles.acquire,
            preferredRoles.carry = true, true, true
    elseif designation == "quartermaster" then
        preferredRoles.deliver, preferredRoles.prepare = true, true
    end
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
        capabilities = capabilities,
        preferredRoles = preferredRoles,
        maxProcedureSteps = proposal.continuityOwner == true and 4 or 1,
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
                    "contest", "ownNeed", "relationship", "capabilities",
                    "preferredRoles", "stepIds", "maxProcedureSteps",
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
    local view = SAO.Organization.viewFor(id, processId, false)
    if view and view.kind=="leisure-dance" then
        local selected
        context,selected=Coordination.danceAppraisal(id,body,view,context)
        local ok,response=pcall(SAO.Organization.respondDance,id,processId,selected,context.choice,context)
        if not ok then return nil,"source-dance-appraisal-unavailable" end
        return response,context
    end
    if view and view.kind=="leisure-duet" then
        local selected
        context,selected=Coordination.duetAppraisal(id,body,view,context)
        local ok,response=pcall(SAO.Organization.respondDuet,id,processId,selected,context.choice,context)
        if not ok then return nil,"source-duet-appraisal-unavailable" end
        return response,context
    end
    if view and view.kind == "leisure-participation" then
        context = Coordination.participationAppraisal(id, body, view, context)
        participationAuthority = { kind = "appraisal", id = id, processId = processId, value = context }
    end
    local ok, response = pcall(SAO.Organization.appraiseMatter, processId, id, context)
    participationAuthority = nil
    if not ok then return nil, "appraisal-unavailable" end
    return response, context
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

local function participationAvailable(id, body, allowOwnWork)
    local needs = SAO.Needs
    if not body or not needs or not needs.ownsRecoveryBody or not needs.ownsRecoveryBody(id, body) then return false, "body-unavailable" end
    if not allowOwnWork and not needs.workAvailable(body) then return false, "physical-work-in-progress" end
    local pressure = needs.read(body)
    if not pressure then return false, "bodily-pressure-unavailable" end
    for _, key in ipairs({ "hunger", "thirst", "fatigue" }) do
        if finite(pressure[key]) and pressure[key] >= 0.75 then return false, "bodily-need-needs-attention" end
    end
    local threat = SAO.Perception and SAO.Perception.nearestBelievedThreat
        and SAO.Perception.nearestBelievedThreat(id, SAO.Controller.tick(), body:getX(), body:getY())
    local concern = threat and SAO.Disposition and SAO.Disposition.fleeDistance and SAO.Disposition.fleeDistance(id, threat)
    if SAO.ConflictResponse and SAO.ConflictResponse.gesturePriority and SAO.ConflictResponse.gesturePriority(id, body)
        or threat and finite(threat.dist) and (not finite(concern) or threat.dist <= concern) then return false, "known-nearby-danger" end
    return true
end

function Coordination.duetAppraisal(id,body,view,context)
    local proposal=view.proposal and view.proposal.proposal or {}
    local terms=proposal.duet or {}
    local available,reason=participationAvailable(id,body)
    local M=SAO.LeisureMusic
    local compatible
    if available and terms.partnerId==id and finite(terms.expiresAtHours) and terms.expiresAtHours>=nowHours()
        and M and M.duetChoices then
        for _,choice in ipairs(M.duetChoices(id,body)) do
            if choice.actorId==id and choice.sourceId==terms.sourceId and choice.songId==terms.songId
                and choice.role==terms.partnerRole then
                for _,role in ipairs(choice.partnerRoles or {}) do
                    if role==terms.originatorRole then compatible=choice;break end
                end
            end
            if compatible then break end
        end
    end
    local interests=SAO.ProceduralPlanning.participationInterests(id,"music") or {}
    local obligations=false
    for _,commitment in ipairs(SAO.Organization.activeCommitments(id)) do
        if commitment.processId~=view.id and commitment.processId~=view.processId then obligations=true end
    end
    local traits=SAO.Disposition.traits(id) or {}
    local seeksCompany=finite(traits.talkativeness) and finite(traits.discipline)
        and traits.talkativeness>traits.discipline and context.relationship>0
    local recall=SAO.Controller and SAO.Controller.leisureReasons
        and SAO.Controller.leisureReasons(id,body,"music")
    local affinity=recall and recall.interest or 0
    local choice
    if context.contest or context.dead or context.incapable then
        choice,reason="decline","person-or-relationship-unavailable"
    elseif not available or obligations or interests.competing then
        choice,reason="defer",reason or "own-responsibility-needs-attention"
    elseif not compatible then choice,reason="decline","no-personally-supported-source-part"
    elseif affinity<0 then choice,reason="decline","retained-experience-disfavors-this-activity"
    elseif interests.related or seeksCompany or affinity>0 then
        choice,reason="accept","personally-supported-part-and-current-interest"
    else choice,reason="decline","prefers-to-retain-time-for-other-interests" end
    context.choice=choice;context.reconsider=view.response and view.response.response=="defer" or false
    context.interests={relatedIntention=interests.related==true,competingIntention=interests.competing==true,
        acceptedObligation=obligations,seeksCompany=seeksCompany,musicAffinity=affinity,
        episodeIds=recall and recall.episodeIds or {},sourceChoiceId=compatible and compatible.id,reason=reason,
        expectedEffect="may-perform-a-mutually-agreed-source-part",uncertainty="agreement-performance-and-enjoyment-remain-unobserved"}
    context.constraints.executionOwnerAvailable=available==true
    context.inputOwners.interests="SAO.LeisureMusic+SAO.ProceduralPlanning+SAO.Disposition+SAO.PersonalMemory"
    return context,compatible and compatible.id
end

function Coordination.proposeDuet(id,body,recipientId,choiceId,partnerRole)
    local available,reason=participationAvailable(id,body)
    if not available or not SAO.Communication.canConverse(id,recipientId) then return nil,reason or "transport-unavailable" end
    local known=false
    for _,contact in ipairs(Coordination.knownContacts(id))do
        if contact.id==recipientId and not contact.hostile then known=true;break end
    end
    if not known then return nil,"recipient-not-personally-known" end
    local prior=SAO.Organization.openMatter(id,"leisure-duet")
    if prior then
        local view=SAO.Organization.viewFor(id,prior.id,false)
        local proposal=view and view.proposal and view.proposal.proposal
        local expiry=proposal and proposal.duet and proposal.duet.expiresAtHours
        if not finite(expiry) or expiry>=nowHours() then return nil,"own-duet-invitation-still-open" end
        SAO.Organization.withdrawMatter(prior.id,id,"own-proposed-duet-window-ended")
    end
    local offer,why=SAO.Organization.proposeDuet(id,recipientId,choiceId,partnerRole,nowHours()+1)
    if not offer then return nil,why end
    local message=SAO.Communication.deliverProcessProposal(id,recipientId,offer.processId,"spoken")
    return offer,message and "received" or "unheard"
end

function Coordination.danceAppraisal(id,body,view,context)
    local proposal=view.proposal and view.proposal.proposal or {}
    local terms=proposal.dance or {};local available,reason=participationAvailable(id,body)
    local M=SAO.LeisureMusic;local compatible
    if available and terms.partnerId==id and finite(terms.expiresAtHours) and terms.expiresAtHours>=nowHours()
        and M and M.danceChoices then
        for _,candidate in ipairs(M.danceChoices(id,body))do
            local sameMusic=candidate.heardMusic and terms.heardMusic
            for field,value in pairs(terms.heardMusic or {})do
                if not candidate.heardMusic or candidate.heardMusic[field]~=value then sameMusic=false end
            end
            if candidate.actorId==id and candidate.sourceId==terms.sourceId and candidate.role==terms.partnerRole
                and sameMusic then compatible=candidate;break end
        end
    end
    local interests=SAO.ProceduralPlanning.participationInterests(id,"dance") or {}
    local obligations=false
    for _,commitment in ipairs(SAO.Organization.activeCommitments(id))do
        if commitment.processId~=view.id and commitment.processId~=view.processId then obligations=true end
    end
    local traits=SAO.Disposition.traits(id) or {}
    local seeksCompany=finite(traits.talkativeness) and finite(traits.discipline)
        and traits.talkativeness>traits.discipline and context.relationship>0
    local recall=SAO.Controller and SAO.Controller.leisureReasons and SAO.Controller.leisureReasons(id,body,"music")
    local affinity=recall and recall.interest or 0;local response
    if context.contest or context.dead or context.incapable then response,reason="decline","person-or-relationship-unavailable"
    elseif not available or obligations or interests.competing then response,reason="defer",reason or "own-responsibility-needs-attention"
    elseif not compatible then response,reason="decline","no-current-personally-heard-source-dance-part"
    elseif affinity<0 then response,reason="decline","retained-experience-disfavors-this-activity"
    elseif interests.related or seeksCompany or affinity>0 then response,reason="accept","personally-heard-source-and-current-interest"
    else response,reason="decline","prefers-to-retain-time-for-other-interests"end
    context.choice=response;context.reconsider=view.response and view.response.response=="defer" or false
    context.interests={relatedIntention=interests.related==true,competingIntention=interests.competing==true,
        acceptedObligation=obligations,seeksCompany=seeksCompany,musicAffinity=affinity,
        episodeIds=recall and recall.episodeIds or {},sourceChoiceId=compatible and compatible.id,reason=reason,
        expectedEffect="may-dance-together-to-the-currently-heard-source",uncertainty="agreement-participation-and-enjoyment-remain-unobserved"}
    context.constraints.executionOwnerAvailable=available==true
    context.inputOwners.interests="SAO.LeisureMusic+SAO.ProceduralPlanning+SAO.Disposition+SAO.PersonalMemory"
    return context,compatible and compatible.id
end
function Coordination.proposeDance(id,body,recipientId,choiceId,partnerRole)
    local available,reason=participationAvailable(id,body)
    if not available or not SAO.Communication.canConverse(id,recipientId)then return nil,reason or "transport-unavailable"end
    local known=false
    for _,contact in ipairs(Coordination.knownContacts(id))do
        if contact.id==recipientId and not contact.hostile then known=true;break end
    end
    if not known then return nil,"recipient-not-personally-known"end
    local prior=SAO.Organization.openMatter(id,"leisure-dance")
    if prior then
        local view=SAO.Organization.viewFor(id,prior.id,false)
        local proposal=view and view.proposal and view.proposal.proposal
        local expiry=proposal and proposal.dance and proposal.dance.expiresAtHours
        if not finite(expiry) or expiry>=nowHours()then return nil,"own-dance-invitation-still-open"end
        SAO.Organization.withdrawMatter(prior.id,id,"own-proposed-dance-window-ended")
    end
    local offer,why=SAO.Organization.proposeDance(id,recipientId,choiceId,partnerRole,nowHours()+1)
    if not offer then return nil,why end
    local message=SAO.Communication.deliverProcessProposal(id,recipientId,offer.processId,"spoken")
    return offer,message and "received" or "unheard"
end
function Coordination.participationAppraisal(id, body, view, context)
    local terms = view.proposal and view.proposal.proposal or {}
    local available, reason = participationAvailable(id, body)
    local interests = SAO.ProceduralPlanning and SAO.ProceduralPlanning.participationInterests(id, terms.activity) or {}
    local obligations = false
    for _, c in ipairs(SAO.Organization.activeCommitments(id)) do
        if c.processId ~= view.id and c.processId ~= view.processId then obligations = true end
    end
    local traits = SAO.Disposition and SAO.Disposition.traits and SAO.Disposition.traits(id) or {}
    local wantsCompany = finite(traits.talkativeness) and finite(traits.discipline)
        and traits.talkativeness > traits.discipline and context.relationship > 0
    local choice
    if context.contest then choice, reason = "decline", "unwilling-to-participate-with-hostile-person"
    elseif not available or obligations or interests.competing then
        choice, reason = "defer", reason or (obligations and "accepted-work-needs-attention" or "own-intention-needs-attention")
    elseif interests.related or wantsCompany then choice, reason = "accept", interests.related
        and "this-activity-matches-my-unfinished-interest" or "I-want-company-with-someone-I-trust"
    else choice, reason = "decline", "I-prefer-to-keep-my-time-for-other-interests" end
    context.choice, context.reconsider = choice, view.response and view.response.response == "defer" or false
    context.capabilities = { listen = available == true }
    context.stepIds, context.maxProcedureSteps = { "listen" }, 1
    context.terms = { reason = reason }
    context.interests = { relatedIntention = interests.related == true, competingIntention = interests.competing == true,
        acceptedObligation = obligations, seeksCompany = wantsCompany, reason = reason,
        expectedEffect = "may-hear-a-fresh-performance", uncertainty = "participation-and-enjoyment-remain-unobserved" }
    context.constraints.represented, context.constraints.executionOwnerAvailable = body ~= nil, available
    context.inputOwners.interests = "SAO.ProceduralPlanning+SAO.Disposition+SAO.Standing"
    return context
end

function Coordination.proposeLeisure(id, recipientId, sourcePurposeId)
    local body = SAO.Body and SAO.Body.get(id)
    local available, reason = participationAvailable(id, body)
    local source = available and SAO.ProceduralPlanning.participationSource(id, sourcePurposeId)
    if not source or id == recipientId then return nil, reason or "sharing-intention-unavailable" end
    if source.processId then
        local prior = SAO.Organization.viewFor(id, source.processId, false)
        if prior and prior.status == "open" then
            local terms = prior.proposal and prior.proposal.proposal
            if terms and finite(terms.expiresAtHours) and terms.expiresAtHours < nowHours() then
                SAO.Organization.withdrawMatter(source.processId, id, "participation-window-ended")
            else return nil, "participation-already-proposed" end
        end
    end
    local item = SAO.Needs.carriedInstrument(id, body, source.itemType)
    if not item or tostring(item:getID()) ~= source.itemId or not SAO.Needs.instrumentAvailable(id, body, item)
        or not SAO.Communication.canConverse(id, recipientId) then return nil, "proposal-transport-or-material-unavailable" end
    local terms = { cooperative = true, responsePolicy = "procedure-completion", activity = source.activity,
        performerId = id, listenerId = recipientId, sourcePurposeId = source.purposeId,
        itemId = source.itemId, itemType = source.itemType, minimumSequence = SAO.Gesture.nextInstrumentSequence(id),
        expiresAtHours = nowHours() + 1, -- bounded proposed encounter window, not evidence of success
        procedure = {
            { id = "perform", verb = "perform", role = "performer", domain = "leisure", capability = "instrument",
                owner = "SAO.Gesture", assignedTo = id, maxActors = 1, completesOn = "participation:performed" },
            { id = "listen", verb = "listen", role = "listener", domain = "leisure", capability = "listen",
                owner = "SAO.Perception", assignedTo = recipientId, maxActors = 1, completesOn = "participation:heard" } } }
    participationAuthority = { kind = "proposal", id = id, value = terms }
    local ok, process = pcall(SAO.Organization.raiseMatter, id, "leisure-participation", nil, terms, { recipientId },
        { source = "own-unfinished-sharing-purpose" })
    participationAuthority = nil
    if not ok or not process then return nil, "proposal-refused" end
    local c = SAO.Organization.commitOriginator(process.id, id, { stepIds = { "perform" }, capabilities = { instrument = true } })
    if not c or not SAO.ProceduralPlanning.bindParticipationSource(id, source.purposeId, process.id) then
        SAO.Organization.withdrawMatter(process.id, id, "source-purpose-unavailable"); return nil end
    local message = SAO.Communication.deliverProcessProposal(id, recipientId, process.id, "spoken")
    return { processId = process.id, revision = process.revision, commitmentId = c.id }, message and "received" or "unheard"
end

function Coordination.participationOffer(id, body, commitmentId)
    local commitments = SAO.Organization.activeCommitments(id)
    if commitmentId then local c = SAO.Organization.commitment(commitmentId); commitments = c and { c } or {} end
    local reason = "accepted-participation-unavailable"
    for _, c in ipairs(commitments) do
        local offer = SAO.Organization.participationOffer(id, c.id)
        if offer then
            local ownWork = offer.role == "perform" and SAO.Gesture.instrumentWork(id)
            local available, why = participationAvailable(id, body, ownWork and ownWork.workId == offer.workId)
            if available then return offer end
            reason = why
        end
    end
    return nil, reason
end

function Coordination.prepareParticipation(id, body, commitmentId)
    return SAO.ProceduralPlanning.planParticipation(id, commitmentId, body)
end

function Coordination.advanceParticipation(id, body, commitmentId)
    local offer = Coordination.participationOffer(id, body, commitmentId)
    if not offer or offer.role ~= "listen" or not offer.workId then return false, "awaiting-fresh-performance" end
    local heard = SAO.Perception.instrumentHearing(id, offer.performerId, offer.workId)
        or SAO.Perception.acquireInstrumentHearing(id, body, offer.performerId, offer.workId)
    if not heard or not SAO.Organization.consumeParticipationHearing(offer.processId, id) then return false, "not-heard" end
    local returned = SAO.Communication.deliverParticipation(id, offer.performerId, offer.processId, "acknowledgement")
    return true, returned and "hearing-acknowledged" or "heard-awaiting-return"
end

return Coordination
