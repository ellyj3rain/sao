-- SAO_Organization.lua - durable organizations and enacted shared work.
--
-- A roster, an office, or a delivered message is not assent. This owner
-- records the proposal a person made, who actually acquired it, each person's
-- revision-bound response, the commitments created by delivered acceptance,
-- and the native work receipts that later fulfilled or interrupted it.

SAO = SAO or {}
SAO.Organization = SAO.Organization or {}
local Org = SAO.Organization
local PARTICIPATION = {}
local DUET = {}
local DANCE = {}
local function participationTransport(processId, fromId, toId, kind)
    return SAO.Communication and SAO.Communication.participationTransport
        and SAO.Communication.participationTransport(processId, fromId, toId, kind) == true
end

Org.organizations = Org.organizations or {}
Org.offices = Org.offices or {}
Org.claims = Org.claims or {}
Org.decisions = Org.decisions or {}
Org.claimHistory = Org.claimHistory or {}
Org.decisionHistory = Org.decisionHistory or {}
Org.processes = Org.processes or {}
Org.processOrder = Org.processOrder or {}
Org.processMeta = Org.processMeta or { sequence = 0 }
Org.workReceipts = Org.workReceipts or {}

local MAX_PROCESSES = 1024
local MAX_EVENTS = 256
local MAX_PROCEDURE_STEPS = 24
local MAX_STEP_ACTORS = 16
local MAX_ORGANIZATIONS = 512
local RESPONSE = {
    accept = true, qualify = true, ["counter-propose"] = true,
    decline = true, defer = true, contest = true, withdraw = true,
}
local TERMINAL_WORK = {
    completed = true, failed = true, interrupted = true,
    withdrawn = true, superseded = true,
}
local TERMINAL_PROCESS = {
    closed = true, expired = true, withdrawn = true, superseded = true,
}
local GOVERNANCE = {
    unsettled = "unsettled", democratic = "democratic",
    despotic = "despotic", localist = "localist",
    federated = "federated", communal = "communal",
}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function nowHours()
    local ok, value = pcall(function()
        return SAO.History and SAO.History.countyHours
            and SAO.History.countyHours() or 0
    end)
    return ok and finite(value) and value or 0
end

local function identity(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

-- ModData may contain only bounded scalar trees. Private decision evidence
-- uses this same copier so engine objects cannot leak into a save.
local function dataCopy(value, depth, seen)
    depth = depth or 0
    if depth > 5 then return nil end
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then return finite(value) and value or nil end
    if kind ~= "table" then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out, count = {}, 0
    for key, item in pairs(value) do
        local keyKind = type(key)
        if keyKind == "string" or (keyKind == "number" and finite(key)) then
            local copied = dataCopy(item, depth + 1, seen)
            if copied ~= nil then
                out[key] = copied
                count = count + 1
                if count >= 96 then break end
            end
        end
    end
    seen[value] = nil
    return out
end

local function appendBounded(list, value, limit)
    list[#list + 1] = value
    while #list > (limit or MAX_EVENTS) do table.remove(list, 1) end
    return value
end

local function hasAny(value)
    for _ in pairs(value or {}) do return true end
    return false
end

local function processOf(processId)
    return Org.processes[tostring(processId or "")]
end

local function revisionKey(revision)
    return tostring(math.max(1, math.floor(tonumber(revision) or 1)))
end

local function event(process, kind, actorId, detail, at)
    process.events = process.events or {}
    return appendBounded(process.events, {
        kind = tostring(kind or "event"), actorId = identity(actorId),
        at = finite(at) and at or nowHours(),
        revision = tonumber(process.revision) or 1,
        detail = dataCopy(detail or {}),
    })
end

local CONTACT_TERMINAL = {
    -- `arrived` remains terminal for pre-C85 saves. New attempts record
    -- arrival separately and wait for an actual reception or an unanswered
    -- end, because reaching an address and reaching a person are different
    -- events.
    arrived = true, unanswered = true,
    failed = true, interrupted = true, superseded = true,
    received = true, expired = true, withdrawn = true, closed = true,
}

local function endContactAttempt(process, attempt, outcome, evidence, at)
    if type(attempt) ~= "table" or CONTACT_TERMINAL[attempt.status] then
        return false
    end
    outcome = CONTACT_TERMINAL[tostring(outcome or "")] and tostring(outcome)
        or "interrupted"
    attempt.status = outcome
    attempt.endedAt = finite(at) and at or nowHours()
    attempt.outcomeEvidence = dataCopy(evidence or {}) or {}
    event(process, "contact-ended", attempt.actorId, {
        contactAttemptId = attempt.id,
        recipientId = attempt.recipientId,
        outcome = outcome,
    }, attempt.endedAt)
    return true
end

local function endOpenContacts(process, outcome, recipientId, evidence, at)
    local ended = 0
    for _, attempt in ipairs(process and process.contactAttempts or {}) do
        if not CONTACT_TERMINAL[attempt.status]
            and (recipientId == nil
                or attempt.recipientId == tostring(recipientId)) then
            if endContactAttempt(process, attempt, outcome, evidence, at) then
                ended = ended + 1
            end
        end
    end
    return ended
end

local function hasLiveCommitment(process)
    for _, commitment in pairs(process and process.commitments or {}) do
        if not TERMINAL_WORK[commitment.status] then return true end
    end
    return false
end

local activeCommitmentFor
local endCommitment
local refreshProcessStatus

local function trimProcesses()
    local at = nowHours()
    for _, processId in ipairs(Org.processOrder) do
        local process = Org.processes[processId]
        local revision = process and process.revisions
            and process.revisions[revisionKey(process.revision)] or nil
        local proposal = revision and revision.proposal or nil
        local expiresAt = proposal and tonumber(proposal.expiresAtHours) or nil
        if process and process.status == "open" and expiresAt
            and expiresAt <= at then
            for _, commitment in pairs(process.commitments or {}) do
                endCommitment(process, commitment, nil,
                    "proposal-expired", at)
            end
            process.status = "expired"
            endOpenContacts(process, "expired", nil,
                { expiresAtHours = expiresAt }, at)
            process.closedAt = at
            process.closureReason = "proposal-expired"
            event(process, "process-expired", process.originatorId,
                { expiresAtHours = expiresAt }, at)
        end
    end
    while #Org.processOrder >= MAX_PROCESSES do
        local removeAt = nil
        for index, processId in ipairs(Org.processOrder) do
            local process = Org.processes[processId]
            if not process or (TERMINAL_PROCESS[process.status]
                and not hasLiveCommitment(process)) then
                removeAt = index
                break
            end
        end
        if not removeAt then return false end
        local processId = table.remove(Org.processOrder, removeAt)
        Org.processes[processId] = nil
    end
    return true
end

local function nextProcessId(originator)
    Org.processMeta = type(Org.processMeta) == "table"
        and Org.processMeta or { sequence = 0 }
    Org.processMeta.sequence = math.max(0,
        math.floor(tonumber(Org.processMeta.sequence) or 0)) + 1
    return "matter:" .. tostring(Org.processMeta.sequence)
        .. ":" .. tostring(originator)
end

local function participant(process, personId, addressed)
    personId = identity(personId)
    if not personId then return nil end
    process.participants = process.participants or {}
    local row = process.participants[personId]
    if not row then
        row = { personId = personId, addressed = addressed == true,
            joinedAt = nowHours(), receptions = {}, responses = {},
            responseHistory = {} }
        process.participants[personId] = row
    elseif addressed == true then
        row.addressed = true
    end
    return row
end

local function proposalAt(process, revision)
    return process.revisions
        and process.revisions[revisionKey(revision or process.revision)] or nil
end

local function procedureAt(process, revision)
    return process.procedures
        and process.procedures[revisionKey(revision or process.revision)] or nil
end

local function privatePlanAt(process, personId, revision)
    local plans = process.privatePlans
        and process.privatePlans[tostring(personId or "")] or nil
    return plans and plans[revisionKey(revision or process.revision)] or nil
end

local function completionTokens(value)
    local tokens = {}
    if type(value) == "string" and value ~= "" then
        tokens[value] = true
    elseif type(value) == "table" then
        for _, token in ipairs(value) do
            if type(token) == "string" and token ~= "" then
                tokens[token] = true
            end
        end
    end
    return tokens
end

local function boundedCount(value, fallback, minimum)
    local count = math.floor(tonumber(value) or fallback)
    return math.max(minimum or 1, math.min(MAX_STEP_ACTORS, count))
end

local function contextCapabilities(context)
    context = type(context) == "table" and context or {}
    local capabilities = dataCopy(context.capabilities or {}) or {}
    local legacy = {
        acquire = context.canAcquire, carry = context.canCarry,
        deliver = context.canDeliver, execute = context.canExecute,
    }
    for name, value in pairs(legacy) do
        if value ~= nil then capabilities[name] = value == true end
    end
    return capabilities
end

local function activeClaimCount(step)
    local count = 0
    for _, claim in pairs(step and step.claims or {}) do
        if claim.status == "claimed" or claim.status == "attempting"
            or claim.status == "completed" then count = count + 1 end
    end
    return count
end

local function refreshProcedure(procedure, at)
    if type(procedure) ~= "table" then return end
    local requiredComplete = true
    for _, stepId in ipairs(procedure.order or {}) do
        local step = procedure.steps and procedure.steps[stepId] or nil
        if step and step.status ~= "completed" and step.status ~= "not-needed" then
            local ready = true
            for _, dependencyId in ipairs(step.dependsOn or {}) do
                local dependency = procedure.steps[dependencyId]
                if not dependency or dependency.status ~= "completed" then
                    ready = false
                    break
                end
            end
            step.status = ready and "available" or "blocked"
        end
        if step and step.required ~= false and step.status ~= "completed" then
            requiredComplete = false
        end
    end
    if requiredComplete and #(procedure.order or {}) > 0 then
        procedure.status = "completed"
        procedure.completedAt = finite(at) and at or nowHours()
        for _, stepId in ipairs(procedure.order) do
            local step = procedure.steps[stepId]
            if step and step.required == false and step.status ~= "completed" then
                step.status = "not-needed"
            end
        end
    else
        procedure.status = "active"
    end
end

local function procedureFromProposal(proposal, revision, at)
    local spec = type(proposal) == "table" and proposal.procedure or nil
    if spec == nil then return nil end
    if type(spec) ~= "table" then return false, "invalid-procedure" end
    local procedure = { revision = revision, status = "active",
        cooperative = proposal.cooperative == true,
        objective = identity(proposal.objective),
        createdAt = at, steps = {}, order = {}, events = {} }
    for _, raw in ipairs(spec) do
        if #procedure.order >= MAX_PROCEDURE_STEPS or type(raw) ~= "table" then
            return false, "invalid-procedure"
        end
        local stepId = identity(raw.id)
        local verb = identity(raw.verb)
        local completion = completionTokens(raw.completesOn)
        if not stepId or not verb or procedure.steps[stepId] or not hasAny(completion) then
            return false, "invalid-procedure"
        end
        local dependencies = {}
        local seenDependencies = {}
        for _, dependencyId in ipairs(type(raw.dependsOn) == "table"
                and raw.dependsOn or {}) do
            dependencyId = identity(dependencyId)
            if not dependencyId or dependencyId == stepId
                or seenDependencies[dependencyId] then
                return false, "invalid-procedure"
            end
            seenDependencies[dependencyId] = true
            dependencies[#dependencies + 1] = dependencyId
        end
        local minActors = boundedCount(raw.minActors, 1, 1)
        local maxActors = boundedCount(raw.maxActors, minActors, minActors)
        local step = { id = stepId, verb = verb,
            capability = identity(raw.capability) or verb,
            owner = identity(raw.owner) or "actor",
            domain = identity(raw.domain) or "action",
            role = identity(raw.role) or verb,
            assignedTo = identity(raw.assignedTo),
            sameActorAs = identity(raw.sameActorAs),
            target = dataCopy(raw.target or {}),
            posture = identity(raw.posture),
            durationSeconds = math.max(0.5, math.min(30,
                tonumber(raw.durationSeconds) or 3)),
            minActors = minActors, maxActors = maxActors,
            required = raw.required ~= false,
            dependsOn = dependencies, completesOn = completion,
            status = "blocked", claims = {}, contributions = {} }
        procedure.steps[stepId] = step
        procedure.order[#procedure.order + 1] = stepId
    end
    if #procedure.order == 0 then return false, "invalid-procedure" end
    for _, stepId in ipairs(procedure.order) do
        for _, dependencyId in ipairs(procedure.steps[stepId].dependsOn) do
            if not procedure.steps[dependencyId] then
                return false, "invalid-procedure"
            end
        end
        local sameActorAs = procedure.steps[stepId].sameActorAs
        if sameActorAs and (sameActorAs == stepId
            or not procedure.steps[sameActorAs]) then
            return false, "invalid-procedure"
        end
    end
    local visiting, visited = {}, {}
    local function visit(stepId)
        if visiting[stepId] then return false end
        if visited[stepId] then return true end
        visiting[stepId] = true
        for _, dependencyId in ipairs(procedure.steps[stepId].dependsOn) do
            if not visit(dependencyId) then return false end
        end
        visiting[stepId], visited[stepId] = nil, true
        return true
    end
    for _, stepId in ipairs(procedure.order) do
        if not visit(stepId) then return false, "cyclic-procedure" end
    end
    refreshProcedure(procedure, at)
    return procedure
end

local function firstProjectedStep(procedure, beliefs)
    for _, stepId in ipairs(procedure and procedure.order or {}) do
        local step = procedure.steps[stepId]
        local belief = beliefs and beliefs[stepId] or nil
        if step and step.required ~= false
            and (not belief or belief.status ~= "completed") then
            local ready = true
            for _, dependencyId in ipairs(step.dependsOn or {}) do
                local dependency = beliefs and beliefs[dependencyId] or nil
                if not dependency or dependency.status ~= "completed" then
                    ready = false
                    break
                end
            end
            if ready then return stepId end
        end
    end
    return nil
end

local function createPrivatePlan(process, personId, revision, source, at)
    local procedure = procedureAt(process, revision)
    if not procedure then return nil end
    personId = identity(personId)
    if not personId then return nil end
    process.privatePlans = process.privatePlans or {}
    process.privatePlans[personId] = process.privatePlans[personId] or {}
    local key = revisionKey(revision)
    local existing = process.privatePlans[personId][key]
    if existing then return existing end
    local beliefs = {}
    for _, stepId in ipairs(procedure.order) do
        local step = procedure.steps[stepId]
        beliefs[stepId] = { id = step.id, verb = step.verb,
            capability = step.capability, owner = step.owner,
            domain = step.domain, role = step.role,
            assignedTo = step.assignedTo, target = dataCopy(step.target),
            sameActorAs = step.sameActorAs,
            posture = step.posture, minActors = step.minActors,
            durationSeconds = step.durationSeconds,
            maxActors = step.maxActors,
            required = step.required, dependsOn = dataCopy(step.dependsOn) or {},
            status = "planned" }
    end
    local plan = { processId = process.id, revision = revision,
        personId = personId, acquiredBy = tostring(source or "communication"),
        acquiredAt = finite(at) and at or nowHours(),
        updatedAt = finite(at) and at or nowHours(), beliefs = beliefs,
        events = {} }
    plan.intendedStepId = firstProjectedStep(procedure, beliefs)
    process.privatePlans[personId][key] = plan
    return plan
end

local function updatePrivatePlan(process, personId, revision, stepId, status,
        basis, at)
    local plan = privatePlanAt(process, personId, revision)
    local belief = plan and plan.beliefs and plan.beliefs[stepId] or nil
    if not plan or not belief then return false end
    belief.status = tostring(status or belief.status)
    belief.updatedAt = finite(at) and at or nowHours()
    belief.basis = dataCopy(basis or {}) or {}
    plan.updatedAt = belief.updatedAt
    local procedure = procedureAt(process, revision)
    plan.intendedStepId = firstProjectedStep(procedure, plan.beliefs)
    appendBounded(plan.events, { stepId = stepId, status = belief.status,
        at = belief.updatedAt, basis = dataCopy(basis or {}) }, 96)
    return true
end

local function assignedWorkComplete(procedure, commitment)
    local found = false
    for stepId in pairs(commitment and commitment.stepIds or {}) do
        found = true
        local step = procedure and procedure.steps and procedure.steps[stepId]
        local claim = step and step.claims
            and step.claims[commitment.actorId] or nil
        if not claim or claim.status ~= "completed" then return false end
    end
    return found
end

local function completeProcedureToken(commitment, token, receiptId, witnesses,
        evidence, at)
    local process = commitment and processOf(commitment.processId) or nil
    local procedure = process and procedureAt(process, commitment.revision) or nil
    if not procedure then return true, "no-procedure" end
    at = finite(at) and at or nowHours()
    local matched = 0
    for _, stepId in ipairs(procedure.order) do
        local step = procedure.steps[stepId]
        if step.completesOn[token] then
            local ready = true
            for _, dependencyId in ipairs(step.dependsOn) do
                if procedure.steps[dependencyId].status ~= "completed" then
                    ready = false
                    break
                end
            end
            local claim = step.claims and step.claims[commitment.actorId] or nil
            local allocated = not procedure.cooperative or claim
                and claim.commitmentId == commitment.id
                and claim.status ~= "released" and claim.status ~= "failed"
            if allocated and (ready or step.status == "completed") then
                local contribution = step.contributions
                    and step.contributions[commitment.actorId] or nil
                if not contribution then
                    matched = matched + 1
                    step.contributions = step.contributions or {}
                    step.contributions[commitment.actorId] = {
                        actorId = commitment.actorId, receiptId = receiptId,
                        token = token, at = at,
                        evidence = dataCopy(evidence or {}) or {} }
                    if claim then
                        claim.status, claim.completedAt = "completed", at
                        claim.receiptId = receiptId
                    end
                    appendBounded(procedure.events, { kind = "step-contribution",
                        stepId = stepId, actorId = commitment.actorId,
                        token = token, receiptId = receiptId, at = at }, 128)
                end
                local contributions = 0
                for _ in pairs(step.contributions or {}) do
                    contributions = contributions + 1
                end
                local newlyCompleted = step.status ~= "completed"
                    and contributions >= (step.minActors or 1)
                if newlyCompleted then
                    step.status, step.completedAt = "completed", at
                    step.receiptId, step.completionToken = receiptId, token
                    step.evidence = dataCopy(evidence or {}) or {}
                    appendBounded(procedure.events, { kind = "step-completed",
                        stepId = stepId, token = token, receiptId = receiptId,
                        contributions = contributions, at = at }, 128)
                end
                if newlyCompleted or step.status == "completed" then
                    local seen = {}
                    for _, personId in ipairs(witnesses or {}) do
                        personId = identity(personId)
                        if personId and not seen[personId] then
                            seen[personId] = true
                            updatePrivatePlan(process, personId,
                                commitment.revision, stepId, "completed",
                                { kind = "receipt", token = token,
                                    receiptId = receiptId }, at)
                        end
                    end
                end
            end
        end
    end
    refreshProcedure(procedure, at)
    if procedure.cooperative and assignedWorkComplete(procedure, commitment)
        and not TERMINAL_WORK[commitment.status] then
        commitment.status = "completed"
        commitment.work.phase = "completed"
        commitment.work.completedAt = at
        commitment.work.endedAt = at
    end
    if refreshProcessStatus then refreshProcessStatus(process) end
    return matched > 0, matched > 0 and "completed" or "no-matching-step"
end

local function responseAt(process, personId, revision)
    local row = process.participants
        and process.participants[tostring(personId or "")] or nil
    return row and row.responses
        and row.responses[revisionKey(revision or process.revision)] or nil
end

refreshProcessStatus = function(process)
    if not process or TERMINAL_PROCESS[process.status] then return end
    local revision = proposalAt(process)
    local proposal = revision and revision.proposal or {}
    if proposal.responsePolicy == "procedure-completion" then
        local procedure = procedureAt(process)
        if procedure and procedure.status == "completed" then
            local closedAt = procedure.completedAt or nowHours()
            endOpenContacts(process, "closed", nil,
                { reason = "procedure-completion" }, closedAt)
            process.status = "closed"
            process.closedAt = closedAt
            process.closureReason = "procedure-completion"
            event(process, "process-closed", process.originatorId,
                { reason = process.closureReason }, closedAt)
        end
        return
    end
    if proposal.responsePolicy == "first-completion" then
        for _, commitment in pairs(process.commitments or {}) do
            if commitment.status == "completed" then
                local closedAt = nowHours()
                for _, other in pairs(process.commitments or {}) do
                    if other.id ~= commitment.id then
                        endCommitment(process, other, nil,
                            "fulfilled-by-another-participant", closedAt)
                    end
                end
                endOpenContacts(process, "closed", nil,
                    { reason = "first-completion",
                        commitmentId = commitment.id }, closedAt)
                process.status = "closed"
                process.closedAt = closedAt
                process.closureReason = "first-completion"
                event(process, "process-closed", commitment.actorId,
                    { commitmentId = commitment.id,
                        reason = process.closureReason }, process.closedAt)
                return
            end
        end
        return
    end
    local addressed, unresolved = 0, false
    for personId, row in pairs(process.participants or {}) do
        if personId ~= process.originatorId and row.addressed then
            addressed = addressed + 1
            local response = responseAt(process, personId)
            if not response or response.delivered ~= true
                or response.response == "defer"
                or response.response == "qualify"
                or response.response == "counter-propose"
                or response.response == "contest" then
                unresolved = true
            elseif response.response == "accept" then
                local commitment = activeCommitmentFor(process, personId)
                if commitment then unresolved = true end
            end
        end
    end
    if addressed > 0 and not unresolved then
        local closedAt = nowHours()
        endOpenContacts(process, "closed", nil,
            { reason = "all-addressed-resolved" }, closedAt)
        process.status = "closed"
        process.closedAt = closedAt
        process.closureReason = "all-addressed-resolved"
        event(process, "process-closed", process.originatorId,
            { reason = process.closureReason }, process.closedAt)
    end
end

activeCommitmentFor = function(process, actorId)
    for _, commitment in pairs(process.commitments or {}) do
        if commitment.actorId == actorId
            and not TERMINAL_WORK[commitment.status]
            and commitment.status ~= "contested" then return commitment end
    end
    return nil
end

local function compatibleProcedureSteps(process, personId, context)
    local procedure = procedureAt(process)
    local plan = privatePlanAt(process, personId, process and process.revision)
    if not procedure or not procedure.cooperative or not plan then return {} end
    local capabilities = contextCapabilities(context)
    local preferredRoles = type(context and context.preferredRoles) == "table"
        and context.preferredRoles or {}
    local ranked = {}
    for index, stepId in ipairs(procedure.order or {}) do
        local step = procedure.steps[stepId]
        local claim = step and step.claims and step.claims[personId] or nil
        local capacity = step and activeClaimCount(step) < (step.maxActors or 1)
        local actorAllowed = step and (not step.assignedTo
            or step.assignedTo == personId)
        local continuityAllowed = true
        if step and step.sameActorAs then
            local anchor = procedure.steps[step.sameActorAs]
            local anchorOwner = nil
            for actorId, anchorClaim in pairs(anchor and anchor.claims or {}) do
                if anchorClaim.status == "claimed"
                    or anchorClaim.status == "attempting"
                    or anchorClaim.status == "completed" then
                    anchorOwner = actorId
                    break
                end
            end
            continuityAllowed = anchorOwner == nil or anchorOwner == personId
        end
        if step and step.status ~= "completed" and actorAllowed and capacity
            and continuityAllowed and not claim
            and capabilities[step.capability] == true then
            local preferred = preferredRoles[step.role] == true
                or preferredRoles[stepId] == true
            ranked[#ranked + 1] = { id = stepId, index = index,
                preferred = preferred,
                available = step.status == "available" }
        end
    end
    table.sort(ranked, function(a, b)
        if a.preferred ~= b.preferred then return a.preferred end
        if a.available ~= b.available then return a.available end
        return a.index < b.index
    end)
    local out = {}
    for _, row in ipairs(ranked) do out[#out + 1] = row.id end
    return out
end

local function claimStepForCommitment(process, commitment, stepId, evidence, at)
    local procedure = process and procedureAt(process, commitment.revision)
    local step = procedure and procedure.steps
        and procedure.steps[tostring(stepId or "")] or nil
    if not procedure or not procedure.cooperative or not step
        or step.status == "completed" then return false, "step-unavailable" end
    local actorId = commitment.actorId
    if step.assignedTo and step.assignedTo ~= actorId then
        return false, "step-assigned-elsewhere"
    end
    if step.sameActorAs then
        local anchor = procedure.steps[step.sameActorAs]
        local anchorClaim = anchor and anchor.claims
            and anchor.claims[actorId] or nil
        if not anchorClaim or (anchorClaim.status ~= "claimed"
            and anchorClaim.status ~= "attempting"
            and anchorClaim.status ~= "completed") then
            return false, "same-actor-anchor-unclaimed"
        end
    end
    step.claims = step.claims or {}
    local existing = step.claims[actorId]
    if existing and (existing.status == "claimed"
        or existing.status == "attempting" or existing.status == "completed") then
        return true, "duplicate"
    end
    if activeClaimCount(step) >= (step.maxActors or 1) then
        return false, "step-capacity-filled"
    end
    at = finite(at) and at or nowHours()
    local claim = { actorId = actorId, commitmentId = commitment.id,
        status = "claimed", claimedAt = at,
        evidence = dataCopy(evidence or {}) or {} }
    step.claims[actorId] = claim
    commitment.stepIds = commitment.stepIds or {}
    commitment.stepIds[step.id] = true
    appendBounded(procedure.events, { kind = "step-claimed",
        stepId = step.id, actorId = actorId,
        commitmentId = commitment.id, at = at }, 128)
    updatePrivatePlan(process, actorId, commitment.revision, step.id,
        "possible", { kind = "communication", claim = true,
            commitmentId = commitment.id }, at)
    return true, claim
end

local function scopeCopy(process, response)
    local proposal = proposalAt(process)
    local scope = dataCopy(proposal and proposal.proposal
        and proposal.proposal.scope or {}) or {}
    if response and type(response.terms) == "table" then
        scope.qualifications = dataCopy(response.terms)
    end
    return scope
end

local function establishCommitment(process, response)
    if response.response ~= "accept" or response.delivered ~= true then
        return nil
    end
    local existing = activeCommitmentFor(process, response.personId)
    if existing and existing.revision == response.revision then return existing end
    process.commitmentSequence = math.max(0,
        math.floor(tonumber(process.commitmentSequence) or 0)) + 1
    local id = process.id .. ":commitment:"
        .. tostring(process.commitmentSequence)
    local commitment = {
        id = id, processId = process.id, revision = response.revision,
        actorId = response.personId, beneficiaryId = process.originatorId,
        organizationId = process.organizationId, matter = process.kind,
        scope = scopeCopy(process, response),
        acceptedAt = response.deliveredAt or nowHours(), status = "accepted",
        work = { phase = "accepted",
            acceptedAt = response.deliveredAt or nowHours(),
            sourceReceipts = {}, handoverReceipts = {},
            routeAttempts = {}, outcomes = {} },
    }
    process.commitments = process.commitments or {}
    process.commitments[id] = commitment
    local plan = createPrivatePlan(process, response.personId,
        response.revision, "accepted-proposal", commitment.acceptedAt)
    if plan then
        plan.commitmentId = id
        plan.updatedAt = commitment.acceptedAt
    end
    local procedure = procedureAt(process, response.revision)
    if procedure and procedure.cooperative then
        local requested = type(response.terms) == "table"
            and type(response.terms.stepIds) == "table"
            and response.terms.stepIds or {}
        local claimed = 0
        for _, stepId in ipairs(requested) do
            local accepted = claimStepForCommitment(process, commitment,
                stepId, { source = "accepted-response",
                    responseRevision = response.responseRevision },
                commitment.acceptedAt)
            if accepted then claimed = claimed + 1 end
        end
        if claimed == 0 then
            commitment.status = "paused"
            commitment.work.phase = "awaiting-allocation"
            commitment.work.pauseReason = "no-step-claimed"
        end
    end
    event(process, "commitment-accepted", response.personId, {
        commitmentId = id, scope = commitment.scope,
    }, commitment.acceptedAt)
    return commitment
end

function Org.createOrganization(id, boundary, governance)
    if type(id) ~= "string" or id == "" then return nil end
    if not Org.organizations[id] then
        local count = 0
        for _ in pairs(Org.organizations) do count = count + 1 end
        -- Organizations originate from county groups, whose population dial
        -- caps the live domain at 500. Keep a small compatibility margin but
        -- never hand Kahlua's order-sensitive quicksort an unbounded list.
        if count >= MAX_ORGANIZATIONS then return nil end
    end
    local organization = { id = id, boundary = dataCopy(boundary or {}) or {},
        governance = GOVERNANCE[governance] or GOVERNANCE.unsettled,
        members = {}, offices = {}, customs = {}, createdAt = nowHours() }
    Org.organizations[id] = organization
    return organization
end

function Org.join(organizationId, personId)
    local organization = Org.organizations[organizationId]
    if not organization or type(personId) ~= "string" then return false end
    organization.members[personId] = { person = personId,
        joinedAt = nowHours(), obligations = {} }
    return true
end

function Org.leave(organizationId, personId)
    local organization = Org.organizations[organizationId]
    local changed = false
    if organization and organization.members[personId] then
        organization.members[personId] = nil
        changed = true
    end
    for _, office in pairs(Org.offices) do
        if office.organization == organizationId then
            if office.holders[personId] then changed = true end
            office.holders[personId] = nil
            local holderCount = 0
            for _ in pairs(office.holders) do holderCount = holderCount + 1 end
            office.vacant = holderCount == 0
        end
    end
    return changed
end

endCommitment = function(process, commitment, status, reason, at)
    if TERMINAL_WORK[commitment.status] then return false end
    at = finite(at) and at or nowHours()
    local acquired = commitment.work and commitment.work.acquiredAt ~= nil
    commitment.status = status or (acquired and "interrupted" or "withdrawn")
    commitment.work = commitment.work or { outcomes = {} }
    commitment.work.outcomes = commitment.work.outcomes or {}
    commitment.work.phase = acquired and "partial" or commitment.status
    commitment.work.endedAt = at
    appendBounded(commitment.work.outcomes, {
        phase = commitment.work.phase, at = at,
        detail = { reason = tostring(reason or "lifecycle-ended") },
    }, 128)
    event(process, "work-" .. commitment.work.phase, commitment.actorId, {
        commitmentId = commitment.id,
        reason = tostring(reason or "lifecycle-ended"),
    }, at)
    return true
end

-- Death ends this person's current responsibilities without erasing their
-- responses, dissent, private decision evidence or physical-work receipts.
-- Acquired work remains explicitly partial; unstarted work is withdrawn.
function Org.releaseActor(personId, reason)
    personId = identity(personId)
    if not personId then return false end
    local at, changed = nowHours(), false
    for organizationId in pairs(Org.organizations) do
        if Org.leave(organizationId, personId) then changed = true end
    end
    for _, process in pairs(Org.processes) do
        for _, commitment in pairs(process.commitments or {}) do
            if commitment.actorId == personId
                and endCommitment(process, commitment, nil,
                    reason or "actor-unavailable", at) then
                changed = true
            end
        end
        if process.originatorId == personId
            and not TERMINAL_PROCESS[process.status] then
            for _, commitment in pairs(process.commitments or {}) do
                if endCommitment(process, commitment, nil,
                    reason or "originator-unavailable", at) then
                    changed = true
                end
            end
            endOpenContacts(process, "withdrawn", nil,
                { reason = tostring(reason or "originator-unavailable") }, at)
            process.status = "withdrawn"
            process.closedAt = at
            process.closureReason = tostring(reason or "originator-unavailable")
            event(process, "process-withdrawn", personId,
                { reason = process.closureReason }, at)
            changed = true
        else
            refreshProcessStatus(process)
        end
    end
    return changed
end

-- Empty-house cleanup retires every live projection owned by that house while
-- retaining process history, claims, decisions and exact-once work receipts.
function Org.retireOrganization(organizationId, reason)
    organizationId = identity(organizationId)
    if not organizationId then return false end
    local at, changed = nowHours(), false
    if Org.organizations[organizationId] then
        Org.organizations[organizationId] = nil
        changed = true
    end
    for key, office in pairs(Org.offices) do
        if office.organization == organizationId then
            Org.offices[key] = nil
            changed = true
        end
    end
    for _, process in pairs(Org.processes) do
        if process.organizationId == organizationId
            and not TERMINAL_PROCESS[process.status] then
            for _, commitment in pairs(process.commitments or {}) do
                if endCommitment(process, commitment, nil,
                    reason or "organization-retired", at) then
                    changed = true
                end
            end
            endOpenContacts(process, "withdrawn", nil,
                { reason = tostring(reason or "organization-retired") }, at)
            process.status = "withdrawn"
            process.closedAt = at
            process.closureReason = tostring(reason or "organization-retired")
            event(process, "process-withdrawn", organizationId,
                { reason = process.closureReason }, at)
            changed = true
        end
    end
    for _, claim in pairs(Org.claims) do
        if claim.organization == organizationId and not claim.lapsedAt then
            claim.lapsedAt = at
            claim.lapseReason = tostring(reason or "organization-retired")
            changed = true
        end
    end
    for _, decision in pairs(Org.decisions) do
        if decision.organization == organizationId and not decision.lapsedAt then
            decision.lapsedAt = at
            decision.lapseReason = tostring(reason or "organization-retired")
            changed = true
        end
    end
    return changed
end

function Org.members(organizationId)
    local organization = Org.organizations[organizationId]
    if not organization then return {} end
    local members = {}
    for personId in pairs(organization.members) do
        members[#members + 1] = personId
    end
    table.sort(members)
    return members
end

function Org.organizationsOf(personId)
    local organizations = {}
    for organizationId, organization in pairs(Org.organizations) do
        if organization.members[personId] then
            organizations[#organizations + 1] = organizationId
        end
    end
    table.sort(organizations)
    return organizations
end

function Org.createOffice(organizationId, officeId, jurisdiction,
                          legitimacy, succession)
    local organization = Org.organizations[organizationId]
    if not organization or type(officeId) ~= "string" then return nil end
    local key = organizationId .. ":" .. officeId
    local office = { id = officeId, organization = organizationId,
        jurisdiction = dataCopy(jurisdiction or {}) or {},
        legitimacy = legitimacy or "consent",
        succession = succession or "consent",
        holders = {}, decisions = {}, vacant = true }
    Org.offices[key] = office
    organization.offices[officeId] = office
    return office
end

-- Office changes are projections of an explicit accepted process. The legacy
-- three-argument call is refused rather than manufacturing consent.
function Org.appoint(organizationId, officeId, personId, commitmentId)
    local office = Org.offices[organizationId .. ":" .. officeId]
    local commitment, process = Org.commitment(commitmentId)
    local revision = process and commitment
        and proposalAt(process, commitment.revision) or nil
    local proposal = revision and revision.proposal or nil
    if not office or type(personId) ~= "string" or not commitment
        or commitment.actorId ~= personId
        or commitment.organizationId ~= organizationId
        or commitment.status ~= "accepted"
        or process.kind ~= "office:" .. tostring(officeId)
        or type(proposal) ~= "table"
        or tostring(proposal.officeId or "") ~= tostring(officeId)
        or tostring(proposal.holderId or "") ~= personId then return false end
    office.holders[personId] = { commitmentId = commitment.id,
        revision = commitment.revision, since = nowHours() }
    office.vacant = false
    return true
end

function Org.vacate(organizationId, officeId, personId)
    local office = Org.offices[organizationId .. ":" .. officeId]
    if not office then return false end
    office.holders[personId] = nil
    local holderCount = 0
    for _ in pairs(office.holders) do holderCount = holderCount + 1 end
    office.vacant = holderCount == 0
    return true
end

function Org.officeAuthority(organizationId, officeId, personId, matter)
    local office = Org.offices[tostring(organizationId) .. ":"
        .. tostring(officeId)]
    local held = office and office.holders
        and office.holders[tostring(personId)] or nil
    if type(held) ~= "table" or not held.commitmentId then return false end
    local commitment = Org.commitment(held.commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status]
        or commitment.status == "contested" then return false end
    if matter == nil then return true end
    local jurisdiction = office.jurisdiction or {}
    return jurisdiction[tostring(matter)] == true
end

local function claimKey(claimant, kind, target)
    return tostring(claimant) .. ":" .. tostring(kind)
        .. ":" .. tostring(target)
end

function Org.recordClaim(claimant, kind, target, organizationId, evidence)
    if type(claimant) ~= "string" or type(kind) ~= "string" then return nil end
    local key = claimKey(claimant, kind, target)
    local previous = Org.claims[key]
    local revision = previous and (tonumber(previous.revision) or 1) + 1 or 1
    local claim = { id = key .. ":r" .. tostring(revision), key = key,
        revision = revision, claimant = claimant, kind = kind,
        target = target, organization = organizationId,
        recognizers = {}, dissenters = {}, response = "unanswered",
        evidence = dataCopy(evidence or {}), recordedAt = nowHours() }
    Org.claimHistory[key] = Org.claimHistory[key] or {}
    appendBounded(Org.claimHistory[key], claim, 64)
    Org.claims[key] = claim
    return claim
end

function Org.recognize(claimant, kind, target, recognizer, processId)
    local claim = Org.claims[claimKey(claimant, kind, target)]
    local process = processOf(processId)
    local response = process and responseAt(process, recognizer) or nil
    if not claim or type(recognizer) ~= "string" or not response
        or response.response ~= "accept" or response.delivered ~= true then
        return false
    end
    claim.recognizers[recognizer] = { processId = process.id,
        revision = response.revision, at = response.deliveredAt }
    claim.dissenters[recognizer] = nil
    return true
end

function Org.dissent(claimant, kind, target, dissenter, response, processId)
    local claim = Org.claims[claimKey(claimant, kind, target)]
    local process = processOf(processId)
    local recorded = process and responseAt(process, dissenter) or nil
    if not claim or type(dissenter) ~= "string" or not recorded
        or recorded.delivered ~= true
        or (recorded.response ~= "contest"
            and recorded.response ~= "decline") then return false end
    claim.dissenters[dissenter] = response or "contest"
    claim.recognizers[dissenter] = nil
    return true
end

function Org.recordDecision(organizationId, officeId, holder, matter,
                            decision, basis, processId)
    local key = tostring(organizationId) .. ":" .. tostring(officeId)
        .. ":" .. tostring(matter)
    local process = processOf(processId)
    local office = Org.offices[tostring(organizationId) .. ":"
        .. tostring(officeId)]
    local held = office and office.holders and office.holders[holder] or nil
    local commitment = held and Org.commitment(held.commitmentId) or nil
    if not process or not commitment
        or commitment.organizationId ~= organizationId
        or not Org.officeAuthority(organizationId, officeId, holder, matter) then
        return nil, "accepted-commitment-required"
    end
    local prior = Org.decisions[key]
    local revision = prior and (tonumber(prior.revision) or 1) + 1 or 1
    local record = { id = key .. ":r" .. tostring(revision),
        revision = revision, organization = organizationId,
        office = officeId, holder = holder, matter = matter,
        decision = dataCopy(decision), basis = dataCopy(basis or {}),
        processId = process.id, commitmentId = commitment.id,
        recordedAt = nowHours() }
    Org.decisions[key] = record
    Org.decisionHistory[key] = Org.decisionHistory[key] or {}
    appendBounded(Org.decisionHistory[key], record, 64)
    if office then office.decisions[#office.decisions + 1] = record end
    return record
end

function Org.succeed(organizationId, officeId, method)
    local office = Org.offices[organizationId .. ":" .. officeId]
    if not office then return nil end
    office.succession = method or office.succession
    if office.succession == "vacancy" then
        office.holders = {}
        office.vacant = true
    end
    return office
end

function Org.raiseMatter(originatorId, kind, organizationId, proposal,
                         addressedIds, privateEvidence, authority)
    if kind=="leisure-duet" and authority~=DUET then return nil end
    if kind=="leisure-dance" and authority~=DANCE then return nil end
    if kind == "leisure-participation" and not (SAO.Coordination and SAO.Coordination.participationAuthority
        and SAO.Coordination.participationAuthority("proposal", originatorId, nil, proposal)) then return nil end
    originatorId, kind = identity(originatorId), identity(kind)
    if not originatorId or not kind or type(proposal) ~= "table"
        or not trimProcesses() then return nil end
    local at = nowHours()
    local procedure, procedureWhy = procedureFromProposal(proposal, 1, at)
    if procedure == false then return nil, procedureWhy end
    local id = nextProcessId(originatorId)
    local process = { id = id, kind = kind,
        organizationId = identity(organizationId),
        originatorId = originatorId, createdAt = at, revisedAt = at,
        revision = 1, status = "open", revisions = {}, participants = {},
        commitments = {}, commitmentSequence = 0, privateInputs = {},
        procedures = {}, privatePlans = {},
        contactAttempts = {}, contactSequence = 0,
        events = {} }
    process.revisions["1"] = { revision = 1, proposedAt = at,
        proposedBy = originatorId, proposal = dataCopy(proposal) or {} }
    process.privateInputs[originatorId] = {
        ["1"] = dataCopy(privateEvidence or {}) or {} }
    if procedure then
        process.procedures["1"] = procedure
        createPrivatePlan(process, originatorId, 1, "authored", at)
    end
    local originator = participant(process, originatorId, true)
    originator.receptions["1"] = { at = at, channel = "authored",
        fromId = originatorId }
    for _, personId in ipairs(addressedIds or {}) do
        participant(process, personId, true)
    end
    Org.processes[id] = process
    Org.processOrder[#Org.processOrder + 1] = id
    event(process, "proposal-raised", originatorId, {
        addressedIds = dataCopy(addressedIds or {}) }, at)
    return process
end

-- A state policy may keep one continuing matter open without keeping a second
-- social-process registry.  The newest matching open process is authoritative;
-- terminal history remains addressable in processOrder.
function Org.openMatter(originatorId, kind)
    originatorId, kind = identity(originatorId), identity(kind)
    if not originatorId or not kind then return nil end
    trimProcesses()
    for index = #Org.processOrder, 1, -1 do
        local process = Org.processes[Org.processOrder[index]]
        if process and process.status == "open"
            and process.originatorId == originatorId
            and process.kind == kind then return process end
    end
    return nil
end

function Org.latestMatter(originatorId, kind)
    originatorId, kind = identity(originatorId), identity(kind)
    if not originatorId or not kind then return nil end
    trimProcesses()
    for index = #Org.processOrder, 1, -1 do
        local process = Org.processes[Org.processOrder[index]]
        if process and process.originatorId == originatorId
            and process.kind == kind then return process end
    end
    return nil
end

-- Addressing someone records only that the proposal names them.  Reception is
-- a later transport fact and remains absent until Communication proves it.
function Org.addressMatter(processId, originatorId, addressedIds)
    local process = processOf(processId)
    originatorId = identity(originatorId)
    if not process or process.status ~= "open"
        or process.originatorId ~= originatorId then return false end
    local added = {}
    for _, personId in ipairs(type(addressedIds) == "table" and addressedIds or {}) do
        personId = identity(personId)
        if personId and personId ~= originatorId then
            local row = process.participants and process.participants[personId]
            if not row or row.addressed ~= true then
                participant(process, personId, true)
                added[#added + 1] = personId
            end
        end
    end
    if #added > 0 then
        event(process, "participants-addressed", originatorId,
            { addressedIds = added })
    end
    return true
end

-- Communication asks this owner for the exact current envelope.  A caller
-- cannot turn an arbitrary process id into reception for an unaddressed person.
function Org.transportRevision(processId, fromId, toId)
    local process = processOf(processId)
    fromId, toId = identity(fromId), identity(toId)
    local row = process and process.participants
        and process.participants[toId] or nil
    if not process or process.status ~= "open"
        or process.originatorId ~= fromId or not row or row.addressed ~= true
        or toId == fromId then return nil, "not-addressed" end
    return tonumber(process.revision), process.kind
end

-- Current addressed revisions that still need an actual transport.  This is
-- intentionally narrower than "messages for a person": it exposes no private
-- evidence or other participant response, and an addressed row remains
-- unheard until Communication proves a channel and records reception.
function Org.pendingProposals(fromId, toId)
    fromId, toId = identity(fromId), identity(toId)
    if not fromId or not toId or fromId == toId then return {} end
    trimProcesses()
    local out = {}
    for _, processId in ipairs(Org.processOrder) do
        local process = Org.processes[processId]
        local row = process and process.participants
            and process.participants[toId] or nil
        local key = process and revisionKey(process.revision) or nil
        if process and process.status == "open"
            and process.originatorId == fromId and row
            and row.addressed == true
            and not (row.receptions and row.receptions[key]) then
            out[#out + 1] = {
                processId = process.id,
                processRevision = tonumber(process.revision),
                kind = process.kind,
            }
        end
    end
    return out
end

-- A contact attempt is movement toward a privately known address for one
-- current addressed revision.  It is durable evidence of trying to convene,
-- not evidence that the recipient was there or heard anything.
local MAX_CONTACT_ROUTE_FAILURES = 3
local CONTACT_ROUTE_RETRY_HOURS = 1 / 60
local CONTACT_APPROACH_CHANGE_DISTANCE = 2

-- The originator can reconsider only their own physically failed approach.
-- A refreshed timestamp at the same address is not changed route evidence.
function Org.contactRouteMayStart(processId, originatorId, recipientId, evidence)
    local process = processOf(processId)
    originatorId, recipientId = identity(originatorId), identity(recipientId)
    if not process or process.originatorId ~= originatorId
        or not recipientId or type(evidence) ~= "table"
        or not finite(evidence.x) or not finite(evidence.y) or not finite(evidence.z)
        or not finite(evidence.fromX) or not finite(evidence.fromY)
        or not finite(evidence.fromZ) then return false, "contact-route-evidence-unavailable" end
    local count, latest = 0, nil
    for index = #(process.contactAttempts or {}), 1, -1 do
        local attempt = process.contactAttempts[index]
        if attempt.actorId == originatorId and attempt.recipientId == recipientId then
            if attempt.arrivedAt or attempt.status == "received" then break end
            local prior = attempt.evidence or {}
            local outcome = attempt.outcomeEvidence or {}
            local physicalFailure = attempt.status == "failed" and prior.owner == "SAO.Controller"
                and prior.representation == "loaded" and finite(prior.x) and finite(prior.y)
                and finite(prior.z) and finite(prior.fromX) and finite(prior.fromY)
                and finite(prior.fromZ) and finite(attempt.endedAt)
                and outcome.reason == "native-route-did-not-arrive"
                and type(outcome.locomotionStatus) == "string"
                and outcome.locomotionStatus:sub(1, 5) == "done:"
                and not outcome.locomotionStatus:find("arrived", 1, true)
            local changedAddress = finite(prior.x) and finite(prior.y)
                and (math.floor(prior.x) ~= math.floor(evidence.x)
                    or math.floor(prior.y) ~= math.floor(evidence.y)
                    or finite(prior.z) and math.floor(prior.z) ~= math.floor(evidence.z))
                and evidence.source == "observed"
                and finite(evidence.observedAt) and finite(prior.observedAt)
                and evidence.observedAt > prior.observedAt
            local changedApproach = finite(prior.fromX) and finite(prior.fromY)
                and finite(prior.fromZ)
                and ((prior.fromX - evidence.fromX) ^ 2 + (prior.fromY - evidence.fromY) ^ 2
                    >= CONTACT_APPROACH_CHANGE_DISTANCE * CONTACT_APPROACH_CHANGE_DISTANCE
                    or math.floor(prior.fromZ) ~= math.floor(evidence.fromZ))
            if physicalFailure then
                if changedAddress or changedApproach then break end
                count, latest = count + 1, latest or attempt
            end
        end
    end
    if latest and nowHours() < (tonumber(latest.endedAt) or nowHours())
        + CONTACT_ROUTE_RETRY_HOURS * math.min(4, 2 ^ math.max(0, count - 1)) then
        return false, "contact-route-backoff"
    end
    if count >= MAX_CONTACT_ROUTE_FAILURES then return false, "contact-route-awaits-changed-evidence" end
    return true
end

function Org.beginContact(processId, originatorId, recipientId, evidence)
    local process = processOf(processId)
    originatorId, recipientId = identity(originatorId), identity(recipientId)
    local row = process and process.participants
        and process.participants[recipientId] or nil
    local key = process and revisionKey(process.revision) or nil
    if not process or process.status ~= "open"
        or process.originatorId ~= originatorId or not recipientId
        or recipientId == originatorId or not row or row.addressed ~= true
        or row.receptions and row.receptions[key] then
        return nil, "contact-not-pending"
    end
    process.contactAttempts = process.contactAttempts or {}
    for index = #process.contactAttempts, 1, -1 do
        local existing = process.contactAttempts[index]
        if existing.actorId == originatorId
            and existing.recipientId == recipientId
            and tonumber(existing.revision) == tonumber(process.revision)
            and not CONTACT_TERMINAL[existing.status] then
            return existing, "existing"
        end
    end
    process.contactSequence = math.max(0,
        math.floor(tonumber(process.contactSequence) or 0)) + 1
    local attempt = {
        id = process.id .. ":contact:" .. tostring(process.contactSequence),
        processId = process.id, revision = process.revision,
        actorId = originatorId, recipientId = recipientId,
        status = "travelling", startedAt = nowHours(),
        evidence = dataCopy(evidence or {}) or {},
    }
    appendBounded(process.contactAttempts, attempt, 64)
    event(process, "contact-started", originatorId, {
        contactAttemptId = attempt.id, recipientId = recipientId,
    }, attempt.startedAt)
    return attempt, "started"
end

-- Reaching the retained address establishes presence there; it does not prove
-- that the named recipient was present or acquired the proposal. The actor
-- remains available to the ordinary encounter transport for one complete
-- county day (or until the proposal expires), after which the attempt can end
-- unanswered. `arrivedAt` remains on every eventual outcome so observers do
-- not have to collapse arrival and reception into one status.
function Org.arriveContact(processId, contactAttemptId, originatorId, evidence)
    local process = processOf(processId)
    originatorId, contactAttemptId = identity(originatorId),
        identity(contactAttemptId)
    if not process or process.originatorId ~= originatorId
        or not contactAttemptId then return nil, "contact-not-owned" end
    for _, attempt in ipairs(process.contactAttempts or {}) do
        if attempt.id == contactAttemptId then
            if CONTACT_TERMINAL[attempt.status] then
                return nil, "contact-already-ended"
            end
            if attempt.status == "waiting" and finite(attempt.arrivedAt)
                and finite(attempt.waitUntilAt) then
                return attempt, "already-waiting"
            end
            local at = nowHours()
            local current = proposalAt(process, process.revision)
            local expiresAt = current and current.proposal
                and tonumber(current.proposal.expiresAtHours) or nil
            local waitUntil = at + 24
            if finite(expiresAt) then waitUntil = math.min(waitUntil, expiresAt) end
            attempt.status = "waiting"
            attempt.arrivedAt = at
            attempt.waitUntilAt = math.max(at, waitUntil)
            attempt.arrivalEvidence = dataCopy(evidence or {}) or {}
            event(process, "contact-arrived", originatorId, {
                contactAttemptId = attempt.id,
                recipientId = attempt.recipientId,
                waitUntilAt = attempt.waitUntilAt,
            }, at)
            return attempt, "waiting"
        end
    end
    return nil, "contact-not-found"
end

function Org.finishContact(processId, contactAttemptId, originatorId,
        outcome, evidence)
    local process = processOf(processId)
    originatorId, contactAttemptId = identity(originatorId),
        identity(contactAttemptId)
    if not process or process.originatorId ~= originatorId
        or not contactAttemptId then return false, "contact-not-owned" end
    for _, attempt in ipairs(process.contactAttempts or {}) do
        if attempt.id == contactAttemptId then
            if CONTACT_TERMINAL[attempt.status] then return true, "duplicate" end
            return endContactAttempt(process, attempt, outcome, evidence),
                tostring(outcome or "interrupted")
        end
    end
    return false, "contact-not-found"
end

function Org.activeContact(processId, originatorId, recipientId)
    local process = processOf(processId)
    originatorId, recipientId = identity(originatorId), identity(recipientId)
    if not process or process.originatorId ~= originatorId then return nil end
    for index = #(process.contactAttempts or {}), 1, -1 do
        local attempt = process.contactAttempts[index]
        if attempt.recipientId == recipientId
            and tonumber(attempt.revision) == tonumber(process.revision)
            and not CONTACT_TERMINAL[attempt.status] then return attempt end
    end
    return nil
end

function Org.reviseMatter(processId, originatorId, proposal, privateEvidence)
    local process = processOf(processId)
    if process and process.kind=="leisure-dance" then return nil,"fresh-dance-proposal-required"end
    -- A new participation occurrence needs a new personal offer and assent.
    if process and process.kind == "leisure-participation" then return nil, "fresh-participation-proposal-required" end
    if not process or process.originatorId ~= originatorId
        or type(proposal) ~= "table" or process.status ~= "open" then
        return nil
    end
    local priorRevision = process.revision
    local nextRevision = priorRevision + 1
    local procedure, procedureWhy = procedureFromProposal(proposal,
        nextRevision, nowHours())
    if procedure == false then return nil, procedureWhy end
    endOpenContacts(process, "superseded", nil,
        { priorRevision = priorRevision }, nowHours())
    process.revision = priorRevision + 1
    process.revisedAt = nowHours()
    process.revisions[revisionKey(process.revision)] = {
        revision = process.revision, proposedAt = process.revisedAt,
        proposedBy = originatorId, proposal = dataCopy(proposal) or {} }
    process.privateInputs[originatorId] = process.privateInputs[originatorId] or {}
    process.privateInputs[originatorId][revisionKey(process.revision)] =
        dataCopy(privateEvidence or {}) or {}
    process.procedures = process.procedures or {}
    process.privatePlans = process.privatePlans or {}
    if procedure then
        process.procedures[revisionKey(process.revision)] = procedure
        createPrivatePlan(process, originatorId, process.revision,
            "authored-revision", process.revisedAt)
    end
    for _, commitment in pairs(process.commitments or {}) do
        endCommitment(process, commitment, "superseded",
            "proposal-revised", process.revisedAt)
    end
    event(process, "proposal-revised", originatorId,
        { priorRevision = priorRevision }, process.revisedAt)
    return process
end

-- An originator may abandon an open proposal.  Existing responsibility ends
-- explicitly as withdrawal/partial work; neither silence nor deletion is used
-- to manufacture a clean outcome.
function Org.withdrawMatter(processId, originatorId, reason, evidence)
    local process = processOf(processId)
    originatorId = identity(originatorId)
    if not process or process.status ~= "open"
        or process.originatorId ~= originatorId then return false end
    local at = nowHours()
    endOpenContacts(process, "withdrawn", nil,
        { reason = tostring(reason or "proposal-withdrawn") }, at)
    for _, commitment in pairs(process.commitments or {}) do
        endCommitment(process, commitment, nil,
            reason or "proposal-withdrawn", at)
    end
    process.status = "withdrawn"
    process.closedAt = at
    process.closureReason = tostring(reason or "proposal-withdrawn")
    event(process, "process-withdrawn", originatorId, {
        reason = process.closureReason,
        evidence = dataCopy(evidence or {}),
    }, at)
    return true
end

-- Close an originator-owned matter after the owning domain has performed the
-- one-shot act it proposed (for example, a voluntary membership withdrawal).
-- This does not answer for any addressed participant and cannot erase an
-- accepted responsibility; their missing response remains visibly unanswered.
function Org.closeMatter(processId, originatorId, reason, evidence)
    local process = processOf(processId)
    originatorId = identity(originatorId)
    if not process or process.status ~= "open"
        or process.originatorId ~= originatorId then return false end
    for _, commitment in pairs(process.commitments or {}) do
        if not TERMINAL_WORK[commitment.status] then
            return false
        end
    end
    local at = nowHours()
    endOpenContacts(process, "closed", nil,
        { reason = tostring(reason or "originator-completed") }, at)
    process.status = "closed"
    process.closedAt = at
    process.closureReason = tostring(reason or "originator-completed")
    event(process, "process-closed", originatorId, {
        reason = process.closureReason,
        evidence = dataCopy(evidence or {}),
    }, process.closedAt)
    return true
end

-- Called only by a proved transport. Acquisition is not assent.
function Org.recordReception(processId, personId, revision, channel,
                             fromId, evidence)
    local process = processOf(processId)
    if process and (process.kind == "leisure-participation" or process.kind=="leisure-duet" or process.kind=="leisure-dance")
        and not participationTransport(processId, fromId, personId, "proposal") then return false end
    personId = identity(personId)
    revision = math.floor(tonumber(revision) or 0)
    local addressed = process and process.participants
        and process.participants[personId] or nil
    if not process or TERMINAL_PROCESS[process.status]
        or not personId or revision < 1
        or not addressed or addressed.addressed ~= true
        or not proposalAt(process, revision) then return false end
    local row = addressed
    local key = revisionKey(revision)
    if row.receptions[key] then return true end
    row.receptions[key] = { at = nowHours(),
        channel = tostring(channel or "communication"),
        fromId = identity(fromId), evidence = dataCopy(evidence or {}) }
    event(process, "proposal-received", personId,
        { channel = channel, fromId = fromId }, row.receptions[key].at)
    createPrivatePlan(process, personId, revision, channel,
        row.receptions[key].at)
    endOpenContacts(process, "received", personId, {
        channel = tostring(channel or "communication"),
        receptionRevision = revision,
    }, row.receptions[key].at)
    return true
end

-- Broadcast and person-to-person request transports discover their exact
-- recipients only when the native communication owner proves reception.  This
-- atomically names that proved recipient and records acquisition; callers that
-- merely possess a process id must continue to use recordReception and are
-- refused unless the person was already addressed.
function Org.recordTransportReception(processId, originatorId, personId,
        revision, channel, fromId, evidence)
    local process = processOf(processId)
    originatorId, personId, fromId = identity(originatorId),
        identity(personId), identity(fromId)
    revision = math.floor(tonumber(revision) or 0)
    if not process or process.status ~= "open"
        or process.originatorId ~= originatorId
        or not personId or not fromId or personId == originatorId
        or revision ~= math.floor(tonumber(process.revision) or 0)
        or not proposalAt(process, revision) then return false end
    local row = process.participants and process.participants[personId] or nil
    if not row or row.addressed ~= true then
        row = participant(process, personId, true)
        event(process, "participant-addressed-by-transport", originatorId, {
            personId = personId, channel = tostring(channel or "communication"),
            fromId = fromId,
        })
    end
    return Org.recordReception(processId, personId, revision, channel,
        fromId, evidence)
end

-- Every row returned here was acquired at the current revision.  An
-- undelivered answer remains present so its real return channel can retry;
-- delivered deferral remains revisable when the actor's current state changes.
function Org.pendingAppraisals(personId)
    personId = identity(personId)
    if not personId then return {} end
    trimProcesses()
    local out = {}
    for _, processId in ipairs(Org.processOrder) do
        local process = Org.processes[processId]
        local row = process and process.participants
            and process.participants[personId] or nil
        local key = process and revisionKey(process.revision) or nil
        local reception = row and row.receptions and row.receptions[key] or nil
        local response = row and row.responses and row.responses[key] or nil
        if process and process.status == "open"
            and process.originatorId ~= personId and row and row.addressed
            and reception and (not response or response.delivered ~= true
                or response.response == "defer") then
            out[#out + 1] = {
                processId = process.id,
                processRevision = process.revision,
                kind = process.kind,
                originatorId = process.originatorId,
                receivedAt = reception.at,
                response = response and response.response or nil,
                responseDelivered = response and response.delivered == true or false,
            }
        end
    end
    return out
end

function Org.responseOptions(processId, personId, context)
    local process = processOf(processId)
    local row = process and process.participants
        and process.participants[tostring(personId or "")] or nil
    if not process or TERMINAL_PROCESS[process.status] or not row
        or not row.receptions[revisionKey(process.revision)] then return {} end
    context = type(context) == "table" and context or {}
    local options = { "decline", "defer", "contest" }
    local revision = proposalAt(process)
    local proposal = revision and revision.proposal or {}
    local required = type(proposal.requiredCapabilities) == "table"
        and proposal.requiredCapabilities or {}
    local available = contextCapabilities(context)
    local capable = context.dead ~= true and context.incapable ~= true
    if proposal.cooperative == true and procedureAt(process) then
        capable = capable
            and #compatibleProcedureSteps(process, tostring(personId), context) > 0
    else
        for capability, needed in pairs(required) do
            if needed == true and available[capability] ~= true then
                capable = false
            end
        end
    end
    if capable then
        table.insert(options, 1, "counter-propose")
        table.insert(options, 1, "qualify")
        table.insert(options, 1, "accept")
    end
    if responseAt(process, personId)
        or activeCommitmentFor(process, tostring(personId)) then
        options[#options + 1] = "withdraw"
    end
    return options
end

local function optionPresent(options, wanted)
    for _, option in ipairs(options or {}) do
        if option == wanted then return true end
    end
    return false
end

-- The caller supplies an actor-private snapshot. Feasible options and choice
-- are frozen together; later outcomes remain a separate horizon.
function Org.appraiseMatter(processId, personId, context, authority)
    local process = processOf(processId)
    if process and process.kind=="leisure-duet" and authority~=DUET then return nil end
    if process and process.kind=="leisure-dance" and authority~=DANCE then return nil end
    if process and process.kind == "leisure-participation" and not (SAO.Coordination
        and SAO.Coordination.participationAuthority
        and SAO.Coordination.participationAuthority("appraisal", personId, processId, context)) then return nil end
    personId = identity(personId)
    context = type(context) == "table" and context or {}
    if not process or not personId or personId == process.originatorId then
        return nil, "not-a-recipient"
    end
    local priorResponse = responseAt(process, personId)
    local proposalRevision = proposalAt(process)
    local proposal = proposalRevision and proposalRevision.proposal or {}
    if priorResponse and context.reconsider ~= true
        and context.choice ~= "withdraw" then
        return nil, "already-answered"
    end
    local options = Org.responseOptions(processId, personId, context)
    if #options == 0 then return nil, "proposal-not-acquired" end
    local selected = identity(context.choice)
    if not selected or not optionPresent(options, selected) then
        local relationship = tonumber(context.relationship) or 0
        local activity = tostring(context.currentActivity or "idle")
        local ownNeed = tonumber(context.ownNeed) or 0
        if context.dead == true or context.incapable == true then
            selected = optionPresent(options, "withdraw")
                and "withdraw" or "decline"
        elseif context.contest == true or relationship <= -0.35 then
            selected = "contest"
        elseif activity ~= "idle" and activity ~= "dormant" then
            selected = "defer"
        elseif not optionPresent(options, "accept") then
            selected = "decline"
        elseif proposal.destinationRequired == true
            and context.destinationKnown == false then
            selected = "counter-propose"
        elseif ownNeed >= 0.75 then
            selected = "qualify"
        elseif relationship < 0.15 then
            selected = "counter-propose"
        else
            selected = "accept"
        end
    end
    local terms = dataCopy(context.terms or {}) or {}
    if selected == "accept" and proposal.cooperative == true then
        local compatible = compatibleProcedureSteps(process, personId, context)
        local allowed = {}
        for _, stepId in ipairs(compatible) do allowed[stepId] = true end
        local requested = type(context.stepIds) == "table"
            and context.stepIds or terms.stepIds
        local chosen = {}
        local maximum = math.max(1, math.min(8,
            math.floor(tonumber(context.maxProcedureSteps) or 1)))
        if type(requested) == "table" then
            for _, stepId in ipairs(requested) do
                stepId = tostring(stepId or "")
                if allowed[stepId] and #chosen < maximum then
                    chosen[#chosen + 1] = stepId
                    allowed[stepId] = nil
                end
            end
        else
            for _, stepId in ipairs(compatible) do
                if #chosen >= maximum then break end
                chosen[#chosen + 1] = stepId
            end
        end
        terms.stepIds = chosen
    end
    if selected == "qualify" and not hasAny(terms) then
        terms.quantity = 1
        terms.afterOwnNeed = true
    elseif selected == "counter-propose" and not hasAny(terms) then
        terms.requireDestination = true
        terms.quantity = 1
    end
    -- Every caller contributes different domain facts, but the retained causal
    -- envelope is uniform.  This is evidence normalization only: the choice
    -- above was already made from the caller's private context.  Defaults name
    -- the caller as owner instead of inventing a new planner or hiding missing
    -- provenance behind an empty table.
    local owner = identity(context.owner) or "Organization.appraiseMatter"
    local executor = identity(context.executor) or owner
    local activity = tostring(context.currentActivity or "idle")
    local bodyOwner = identity(context.bodyOwner)
        or (executor == "player" and "player" or "SAO")
    local capabilities = contextCapabilities(context)
    for _, capability in ipairs({ "acquire", "carry", "deliver", "execute" }) do
        if capabilities[capability] == nil then capabilities[capability] = true end
    end
    local constraints = dataCopy(context.constraints or {}) or {}
    if type(constraints.represented) ~= "boolean" then
        constraints.represented = context.represented == true
    end
    constraints.currentActivity = activity
    if type(constraints.executionOwnerAvailable) ~= "boolean" then
        constraints.executionOwnerAvailable = context.executionOwnerAvailable ~= false
    end
    if type(constraints.ownNeedAvailable) ~= "boolean" then
        if type(context.ownNeedAvailable) == "boolean" then
            constraints.ownNeedAvailable = context.ownNeedAvailable
        else
            constraints.ownNeedAvailable = tonumber(context.ownNeed) ~= nil
        end
    end
    constraints.dead = context.dead == true
    constraints.incapable = context.incapable == true
    constraints.contest = context.contest == true
    if constraints.executionOwnerAvailable ~= true then
        for capability in pairs(capabilities) do capabilities[capability] = false end
    end
    local suppliedOwners = type(context.inputOwners) == "table"
        and context.inputOwners or {}
    local function inputOwner(name, fallback)
        return identity(suppliedOwners[name]) or fallback
    end
    local inputOwners = {
        currentActivity = inputOwner("currentActivity", executor),
        capabilities = inputOwner("capabilities", executor),
        ownNeed = inputOwner("ownNeed",
            constraints.ownNeedAvailable and owner or "unavailable"),
        relationship = inputOwner("relationship", "SAO.Standing"),
        interests = inputOwner("interests", owner),
        constraints = inputOwner("constraints", owner),
    }
    local response = Org.respond(processId, personId, selected, terms, {
        owner = owner, bodyOwner = bodyOwner, currentActivity = activity,
        capabilities = capabilities, constraints = constraints,
        interests = dataCopy(context.interests or {}) or {},
        inputOwners = inputOwners,
        relationship = tonumber(context.relationship) or 0,
        ownNeed = tonumber(context.ownNeed) or 0,
        destinationKnown = context.destinationKnown == true,
        feasibleOptions = options, choice = selected,
        reconsider = context.reconsider == true, executor = executor,
    },authority)
    -- [C82] The production rule above remains authoritative.  The learned
    -- candidate sees the same frozen private horizon only after that response
    -- exists, and any bridge/model failure is observationally inert.
    if response and SAO.CoordinationInference
        and type(SAO.CoordinationInference.submit) == "function" then
        pcall(SAO.CoordinationInference.submit, processId, personId,
            response.responseRevision)
    end
    return response
end

function Org.respond(processId, personId, response, terms, privateEvidence, authority)
    local process = processOf(processId)
    if process and process.kind=="leisure-duet" and authority~=DUET then return nil end
    if process and process.kind=="leisure-dance" and authority~=DANCE then return nil end
    if process and process.kind == "leisure-participation" and not (SAO.Coordination
        and SAO.Coordination.participationAuthority
        and SAO.Coordination.participationAuthority("appraisal", personId, processId)) then return nil end
    personId, response = identity(personId), identity(response)
    if not process or TERMINAL_PROCESS[process.status]
        or not personId or not RESPONSE[response]
        or personId == process.originatorId then return nil end
    local row = participant(process, personId, true)
    local key = revisionKey(process.revision)
    if not row.receptions[key] then return nil end
    local prior = row.responses[key]
    if prior and prior.response == "accept" and response ~= "withdraw" then
        return nil
    end
    row.responseHistory = row.responseHistory or {}
    row.responseHistory[key] = row.responseHistory[key] or {}
    if prior then
        appendBounded(row.responseHistory[key], dataCopy(prior), 32)
    end
    local at = nowHours()
    local record = { personId = personId, revision = process.revision,
        response = response, terms = dataCopy(terms or {}) or {},
        responseRevision = prior
            and (tonumber(prior.responseRevision) or 1) + 1 or 1,
        formedAt = at, delivered = false }
    row.responses[key] = record
    process.privateInputs[personId] = process.privateInputs[personId] or {}
    process.privateInputs[personId][key] = dataCopy(privateEvidence or {}) or {}
    event(process, "response-formed", personId,
        { response = response, terms = record.terms }, at)
    return record
end

-- A response changes shared responsibility only when it reaches the proposal's
-- originator over an admitted return channel. Replaying delivery is safe.
function Org.deliverResponse(processId, personId, toId, channel, evidence)
    local process = processOf(processId)
    if process and (process.kind == "leisure-participation" or process.kind=="leisure-duet" or process.kind=="leisure-dance")
        and not participationTransport(processId, personId, toId, "response") then return false end
    personId, toId = identity(personId), identity(toId)
    if not process or TERMINAL_PROCESS[process.status]
        or not personId or toId ~= process.originatorId then
        return false
    end
    local response = responseAt(process, personId)
    if not response then return false end
    if response.delivered then return true end
    response.delivered = true
    response.deliveredAt = nowHours()
    response.channel = tostring(channel or "communication")
    response.deliveryEvidence = dataCopy(evidence or {})
    local commitment = establishCommitment(process, response)
    if response.response == "withdraw" then
        local existing = activeCommitmentFor(process, personId)
        if existing then
            existing.status = "withdrawn"
            existing.work.phase = "withdrawn"
            existing.work.endedAt = response.deliveredAt
        end
    elseif response.response == "contest" then
        process.contested = true
    end
    event(process, "response-delivered", personId, {
        response = response.response, channel = response.channel,
        commitmentId = commitment and commitment.id or nil,
    }, response.deliveredAt)
    refreshProcessStatus(process)
    return true
end

-- An author may publicly bind themself to named steps while raising a
-- cooperative proposal.  This is not a reply to their own message: it is the
-- work they offered to perform, checked against the same private capability
-- envelope and the same role capacity used for every recipient.  No other
-- actor is assigned here.
function Org.commitOriginator(processId, personId, context, authority)
    local process = processOf(processId)
    if process and process.kind=="leisure-dance" and authority~=DANCE then return nil,"typed-dance-originator-required"end
    personId = identity(personId)
    context = type(context) == "table" and context or {}
    if not process or process.status ~= "open" or not personId
        or process.originatorId ~= personId then
        return nil, "not-the-originator"
    end
    local procedure = procedureAt(process)
    if not procedure or procedure.cooperative ~= true then
        return nil, "cooperative-procedure-required"
    end
    local existing = activeCommitmentFor(process, personId)
    if existing and existing.revision == process.revision then
        return existing, "duplicate"
    end
    local compatible = compatibleProcedureSteps(process, personId, context)
    local allowed = {}
    for _, stepId in ipairs(compatible) do allowed[stepId] = true end
    local requested = type(context.stepIds) == "table"
        and context.stepIds or {}
    local maximum = math.max(1, math.min(8,
        math.floor(tonumber(context.maxProcedureSteps) or 1)))
    local chosen = {}
    for _, stepId in ipairs(requested) do
        stepId = tostring(stepId or "")
        if allowed[stepId] and #chosen < maximum then
            chosen[#chosen + 1] = stepId
            allowed[stepId] = nil
        end
    end
    if #chosen == 0 then return nil, "no-compatible-authored-step" end
    local at = nowHours()
    local commitment = establishCommitment(process, {
        personId = personId,
        revision = process.revision,
        response = "accept",
        responseRevision = 1,
        delivered = true,
        deliveredAt = at,
        terms = { stepIds = chosen, authored = true },
    })
    if not commitment then return nil, "commitment-refused" end
    local key = revisionKey(process.revision)
    process.privateInputs[personId] = process.privateInputs[personId] or {}
    local input = process.privateInputs[personId][key] or {}
    input.authoredCommitment = dataCopy(context.evidence or {}) or {}
    input.authoredCapabilities = contextCapabilities(context)
    process.privateInputs[personId][key] = input
    event(process, "originator-committed", personId, {
        commitmentId = commitment.id, stepIds = chosen,
    }, at)
    return commitment, "committed"
end

function Org.pendingResponses(fromId, toId)
    local out = {}
    for _, processId in ipairs(Org.processOrder) do
        local process = Org.processes[processId]
        if process and process.originatorId == toId then
            local response = responseAt(process, fromId)
            if response and response.delivered ~= true then
                out[#out + 1] = { processId = processId,
                    revision = response.revision, response = response.response }
            end
        end
    end
    return out
end

function Org.commitment(commitmentId)
    commitmentId = tostring(commitmentId or "")
    for _, process in pairs(Org.processes) do
        local commitment = process.commitments
            and process.commitments[commitmentId] or nil
        if commitment then return commitment, process end
    end
    return nil
end

function Org.activeCommitment(personId, matter)
    personId = tostring(personId or "")
    for _, processId in ipairs(Org.processOrder) do
        local process = Org.processes[processId]
        if process and (matter == nil or process.kind == matter) then
            local commitment = activeCommitmentFor(process, personId)
            if commitment then return commitment, process end
        end
    end
    return nil
end

function Org.activeCommitments(personId)
    personId = tostring(personId or "")
    local out = {}
    for _, processId in ipairs(Org.processOrder) do
        local process = Org.processes[processId]
        local commitment = process and activeCommitmentFor(process, personId)
            or nil
        if commitment then out[#out + 1] = commitment end
    end
    return out
end

function Org.workPlan(commitmentId, personId)
    local commitment, process = Org.commitment(commitmentId)
    personId = identity(personId)
    if not commitment or not process or personId ~= commitment.actorId then
        return nil
    end
    local proposal = proposalAt(process, commitment.revision)
    local privatePlan = privatePlanAt(process, personId, commitment.revision)
    local procedure = procedureAt(process, commitment.revision)
    local assigned, current = {}, nil
    for _, stepId in ipairs(procedure and procedure.order or {}) do
        if commitment.stepIds and commitment.stepIds[stepId] then
            assigned[#assigned + 1] = stepId
            local claim = procedure.steps[stepId].claims
                and procedure.steps[stepId].claims[personId] or nil
            if not current and claim and claim.status ~= "completed"
                and claim.status ~= "released" and claim.status ~= "failed" then
                local belief = privatePlan and privatePlan.beliefs
                    and privatePlan.beliefs[stepId] or nil
                local ready = true
                for _, dependencyId in ipairs(procedure.steps[stepId].dependsOn
                    or {}) do
                    local dependency = privatePlan and privatePlan.beliefs
                        and privatePlan.beliefs[dependencyId] or nil
                    if not dependency or dependency.status ~= "completed" then
                        ready = false
                        break
                    end
                end
                if belief and ready then current = stepId end
            end
        end
    end
    return {
        processId = process.id,
        processRevision = commitment.revision,
        commitmentId = commitment.id,
        actorId = commitment.actorId,
        requesterId = process.originatorId,
        organizationId = process.organizationId,
        kind = process.kind,
        proposal = dataCopy(proposal and proposal.proposal or {}),
        privateProcedure = dataCopy(privatePlan),
        assignedStepIds = assigned,
        intendedStepId = procedure and procedure.cooperative and current
            or (not (procedure and procedure.cooperative)
                and privatePlan and privatePlan.intendedStepId or nil),
        phase = commitment.work and commitment.work.phase,
        status = commitment.status,
    }
end

function Org.procedureOpportunities(processId, personId, context)
    local process = processOf(processId)
    personId = identity(personId)
    if not process or not personId then return {} end
    return dataCopy(compatibleProcedureSteps(process, personId, context)) or {}
end

function Org.claimProcedureStep(commitmentId, stepId, context)
    local commitment, process = Org.commitment(commitmentId)
    if not commitment or not process or TERMINAL_WORK[commitment.status] then
        return false, "commitment-unavailable"
    end
    context = type(context) == "table" and context or {}
    local compatible = compatibleProcedureSteps(process, commitment.actorId,
        context)
    local admitted = false
    for _, candidate in ipairs(compatible) do
        if candidate == stepId then admitted = true break end
    end
    if not admitted then return false, "step-not-compatible" end
    local claimed, result = claimStepForCommitment(process, commitment,
        stepId, context.evidence or { source = "reallocation" })
    if claimed and commitment.status == "paused"
        and commitment.work.pauseReason == "no-step-claimed" then
        commitment.status = "accepted"
        commitment.work.phase = "accepted"
        commitment.work.pauseReason = nil
    end
    return claimed, result
end

function Org.releaseProcedureStep(commitmentId, stepId, reason, evidence)
    local commitment, process = Org.commitment(commitmentId)
    local procedure = process and procedureAt(process, commitment.revision)
    local step = procedure and procedure.steps
        and procedure.steps[tostring(stepId or "")] or nil
    local claim = step and step.claims
        and step.claims[commitment.actorId] or nil
    if not claim or claim.commitmentId ~= commitment.id
        or claim.status == "completed" or claim.status == "released" then
        return false, "claim-unavailable"
    end
    local at = nowHours()
    claim.status, claim.releasedAt = "released", at
    claim.reason = tostring(reason or "reconsidered")
    claim.evidence = dataCopy(evidence or {}) or claim.evidence
    commitment.stepIds[step.id] = nil
    procedure.revisionNeeded = { stepId = step.id,
        actorId = commitment.actorId, reason = claim.reason, at = at }
    appendBounded(procedure.events, { kind = "step-released",
        stepId = step.id, actorId = commitment.actorId,
        commitmentId = commitment.id, reason = claim.reason, at = at }, 128)
    updatePrivatePlan(process, commitment.actorId, commitment.revision,
        step.id, "blocked", { kind = "disagreement",
            reason = claim.reason }, at)
    commitment.status = "paused"
    commitment.work.phase = "awaiting-revision"
    commitment.work.pauseReason = claim.reason
    return true, claim
end

-- Person-owned procedure state. This is a cognitive projection, not the
-- enacted process. A participant acquires it by authorship or proved proposal
-- reception and can revise it without changing material truth for anyone else.
function Org.privateProcedure(personId, processId, requestedRevision)
    local process = processOf(processId)
    personId = identity(personId)
    if not process or not personId then return nil end
    return dataCopy(privatePlanAt(process, personId,
        requestedRevision or process.revision))
end

function Org.revisePrivateProcedure(processId, personId, requestedRevision,
        update, basis)
    local process = processOf(processId)
    personId = identity(personId)
    local revision = math.floor(tonumber(requestedRevision) or 0)
    local plan = process and privatePlanAt(process, personId, revision) or nil
    update = type(update) == "table" and update or {}
    basis = type(basis) == "table" and basis or {}
    local basisKind = tostring(basis.kind or "")
    local admitted = { reasoning = true, disagreement = true,
        perception = true, communication = true, receipt = true }
    if not plan or not admitted[basisKind] then return false end
    local intended = update.intendedStepId
    if intended ~= nil then
        intended = identity(intended)
        if not intended or not plan.beliefs[intended] then return false end
        plan.intendedStepId = intended
    end
    for stepId, status in pairs(type(update.beliefs) == "table"
            and update.beliefs or {}) do
        if not plan.beliefs[stepId] then return false end
        status = tostring(status or "")
        if status ~= "planned" and status ~= "possible"
            and status ~= "attempting" and status ~= "blocked"
            and status ~= "completed" and status ~= "falsified" then
            return false
        end
        plan.beliefs[stepId].status = status
        plan.beliefs[stepId].basis = dataCopy(basis)
        plan.beliefs[stepId].updatedAt = nowHours()
    end
    plan.updatedAt = nowHours()
    appendBounded(plan.events, { kind = "private-revision",
        intendedStepId = plan.intendedStepId, update = dataCopy(update),
        basis = dataCopy(basis), at = plan.updatedAt }, 96)
    return true
end

-- God-mode/operator evidence for what materially happened. Participant code
-- must use privateProcedure or workPlan and never receives this surface.
function Org.enactedProcedure(processId, requestedRevision)
    local process = processOf(processId)
    if not process then return nil end
    return dataCopy(procedureAt(process,
        requestedRevision or process.revision))
end

function Org.authorityFor(personId, organizationId, matter)
    local scopes = {}
    for _, process in pairs(Org.processes) do
        for _, commitment in pairs(process.commitments or {}) do
            if commitment.actorId == personId
                and (organizationId == nil
                    or commitment.organizationId == organizationId)
                and (matter == nil or commitment.matter == matter)
                and not TERMINAL_WORK[commitment.status]
                and commitment.status ~= "contested" then
                scopes[#scopes + 1] = { processId = process.id,
                    commitmentId = commitment.id,
                    revision = commitment.revision, matter = commitment.matter,
                    scope = dataCopy(commitment.scope) }
            end
        end
    end
    return scopes
end

local function workEvent(commitment, phase, detail, at)
    local process = processOf(commitment.processId)
    local work = commitment.work
    work.phase = phase
    work.updatedAt = finite(at) and at or nowHours()
    appendBounded(work.outcomes, { phase = phase, at = work.updatedAt,
        detail = dataCopy(detail or {}) }, 128)
    event(process, "work-" .. tostring(phase), commitment.actorId, {
        commitmentId = commitment.id, detail = detail }, work.updatedAt)
    refreshProcessStatus(process)
    return commitment
end

function Org.startWork(commitmentId, owner, activity)
    local commitment = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status]
        or commitment.status == "contested" then return false end
    commitment.status = "in-progress"
    commitment.work.owner = tostring(owner or "SAO")
    commitment.work.currentActivity = tostring(activity or "acquiring")
    workEvent(commitment, activity or "acquiring",
        { owner = commitment.work.owner })
    return true
end

-- A present competing pressure can pause useful work without pretending the
-- responsibility vanished or that partial physical work completed. The same
-- commitment may resume after its execution owner revalidates current access.
function Org.pauseWork(commitmentId, reason, evidence)
    local commitment, process = Org.commitment(commitmentId)
    if not commitment or not process or TERMINAL_WORK[commitment.status]
        or commitment.status == "contested" then return false end
    local at = nowHours()
    local routes = commitment.work and commitment.work.routeAttempts or {}
    local route = routes[#routes]
    if route and route.status == "pending" then
        route.status = "paused"
        route.endedAt = at
        route.detail = tostring(reason or "competing-pressure")
        if route.id then
            Org.workReceipts["route:" .. route.id] =
                Org.workReceipts["route:" .. route.id] or {
                    kind = "route", receiptId = route.id,
                    commitmentId = commitment.id, status = route.status,
                    at = route.endedAt,
                }
        end
    end
    commitment.work.pausedFrom = commitment.work.phase
    commitment.work.pauseReason = tostring(reason or "competing-pressure")
    commitment.status = "paused"
    workEvent(commitment, "paused", {
        reason = commitment.work.pauseReason,
        evidence = dataCopy(evidence or {}),
    }, at)
    return true
end

function Org.resumeWork(commitmentId, owner, activity, evidence)
    local commitment = Org.commitment(commitmentId)
    if not commitment or commitment.status ~= "paused" then return false end
    commitment.status = "in-progress"
    commitment.work.owner = tostring(owner or commitment.work.owner or "SAO")
    commitment.work.currentActivity = tostring(activity
        or commitment.work.pausedFrom or "acquiring")
    commitment.work.pauseReason = nil
    workEvent(commitment, "resumed", {
        owner = commitment.work.owner,
        activity = commitment.work.currentActivity,
        evidence = dataCopy(evidence or {}),
    })
    return true
end

function Org.noteWorkAdmission(commitmentId, ownerKind, receiptId, detail, authority)
    local commitment, process = Org.commitment(commitmentId)
    if process and process.kind == "leisure-participation" and authority ~= PARTICIPATION then return false end
    if process and process.kind == "leisure-duet" and authority ~= DUET then return false end
    if process and process.kind == "leisure-dance" and authority ~= DANCE then return false end
    receiptId = identity(receiptId)
    if not commitment or TERMINAL_WORK[commitment.status] or not receiptId
        or (commitment.work.pendingReceiptId
            and commitment.work.pendingReceiptId ~= receiptId) then return false end
    commitment.status = "in-progress"
    commitment.work.nativeOwner = tostring(ownerKind or "native")
    commitment.work.pendingReceiptId = receiptId
    workEvent(commitment, "admitted", { owner = ownerKind,
        receiptId = receiptId, detail = detail })
    local plan = process and privatePlanAt(process, commitment.actorId,
        commitment.revision) or nil
    local intendedStepId = type(detail) == "table"
        and identity(detail.stepId) or nil
    if not intendedStepId then
        local actorWork = Org.workPlan(commitment.id, commitment.actorId)
        intendedStepId = actorWork and actorWork.intendedStepId or nil
    end
    if plan and intendedStepId and plan.beliefs[intendedStepId] then
        local procedure = procedureAt(process, commitment.revision)
        local step = procedure and procedure.steps[intendedStepId] or nil
        local claim = step and step.claims
            and step.claims[commitment.actorId] or nil
        if claim and claim.commitmentId == commitment.id then
            claim.status = "attempting"
            claim.attemptedAt = nowHours()
            claim.receiptId = receiptId
        end
        updatePrivatePlan(process, commitment.actorId, commitment.revision,
            intendedStepId, "attempting", { kind = "receipt",
                owner = tostring(ownerKind or "native"),
                receiptId = receiptId, phase = "admitted" })
    end
    return true
end

-- A person's accepted work can teach only its native measured contribution.
-- Travel, assent and the shared procedure's aggregate status are not outcomes.
local function rememberFulfilledWork(commitment,kind,receiptId,native)
    local at=nowHours()
    if not native or native.actorId~=commitment.actorId or native.commitmentId~=commitment.id
        or native.status~="completed" or not finite(commitment.acceptedAt)
        or commitment.acceptedAt<0 or commitment.acceptedAt>at then return false end
    if kind=="prepare" and (native.id~=receiptId or native.detail~="native-food-cooked-and-retrieved"
        or native.nativeCredit~=receiptId or native.retrieved~=true or native.heatObserved~=true) then return false end
    if kind=="deliver" and native.operation and (native.operation~="store"
        or native.measurement~="native-item-transfer" or not finite(native.observedQuantity) or native.observedQuantity<=0) then return false end
    local person=SAO.Identity and SAO.Identity.get(commitment.actorId)
    if not person then return false end
    local occurred=native.atHours or native.at
    if native.completedAt~=nil then
        if SAO.History and SAO.History.ticks then
            local rate=SAO.History.TICKS_PER_HOUR
            if not finite(rate) or rate<=0 or not finite(native.completedAt)
                or native.completedAt<math.floor(commitment.acceptedAt*rate)
                or native.completedAt>SAO.History.ticks() then return false end
            -- Handover stores whole county ticks; assent stores hours. Their
            -- shared tick may contain assent before the measured completion.
            occurred=math.max(commitment.acceptedAt,native.completedAt/rate)
        else occurred=native.completedAt end
    end
    if not finite(occurred) or occurred<commitment.acceptedAt or occurred>at then return false end
    person.fulfilledWorkSequence=(person.fulfilledWorkSequence or 0)+1
    local row={actorId=commitment.actorId,sequence=person.fulfilledWorkSequence,
        commitmentId=commitment.id,workKind=kind,nativeReceiptId=receiptId,
        acceptedAt=commitment.acceptedAt,atHours=occurred,status="completed"}
    person.fulfilledWorkOutcomes=person.fulfilledWorkOutcomes or {}
    person.fulfilledWorkOutcomes[#person.fulfilledWorkOutcomes+1]=row
    if #person.fulfilledWorkOutcomes>32 then table.remove(person.fulfilledWorkOutcomes,1) end
    if SAO.Cognition and SAO.Cognition.commitmentOutcome then SAO.Cognition.commitmentOutcome(commitment.actorId,row) end
    return true
end
function Org.fulfilledWorkOutcome(id,sequence)
    local person=SAO.Identity and SAO.Identity.get(id)
    for _,row in ipairs(person and person.fulfilledWorkOutcomes or {}) do
        if row.actorId==id and row.sequence==sequence then return dataCopy(row) end
    end
end

local function objectiveWorkReceipts(commitment, process)
    if not commitment or not process or process.kind ~= "cooperative-action"
        or commitment.status ~= "completed" then return nil end
    local proposalRow = proposalAt(process, commitment.revision)
    local proposal = proposalRow and proposalRow.proposal
    local scope = proposal and proposal.scope
    if not proposal or proposal.objective ~= "player-marked-watch-return"
        or not scope or scope.recipientId ~= commitment.actorId then return nil end
    local procedure = procedureAt(process, commitment.revision)
    if not procedure or procedure.status ~= "completed" then return nil end
    local receipts = {}
    for _, stepId in ipairs({ "outbound", "watch", "return" }) do
        local step = procedure.steps and procedure.steps[stepId]
        local contribution = step and step.contributions
            and step.contributions[commitment.actorId]
        local receiptId = contribution and identity(contribution.receiptId)
        if not step or step.status ~= "completed" or not receiptId then return nil end
        local kind = stepId == "watch" and "procedure:" or "route:"
        local receipt = Org.workReceipts[kind .. receiptId]
        if not receipt or receipt.receiptId ~= receiptId
            or receipt.commitmentId ~= commitment.id
            or receipt.status ~= "completed" and receipt.status ~= "arrived"
            or stepId == "watch" and (receipt.kind ~= "procedure"
                or receipt.token ~= "posture:maintained"
                or receipt.owner ~= "Posture" or receipt.status ~= "completed")
            or stepId ~= "watch" and (receipt.kind ~= "route"
                or receipt.status ~= "arrived") then return nil end
        receipts[stepId] = receiptId
    end
    local routes = {}
    for _, route in ipairs(commitment.work and commitment.work.routeAttempts or {}) do
        if route.id == receipts.outbound or route.id == receipts["return"] then
            routes[route.id] = route
        end
    end
    local out, back = routes[receipts.outbound], routes[receipts["return"]]
    local dest = proposal.destination
    if not out or not back or not dest or out.phase ~= "travelling"
        or back.phase ~= "travelling" or out.status ~= "arrived"
        or back.status ~= "arrived" or out.x ~= dest.minX
        or out.x ~= dest.maxX or out.y ~= dest.minY
        or out.y ~= dest.maxY or out.z ~= dest.z
        or back.x ~= scope.returnX or back.y ~= scope.returnY
        or back.z ~= scope.returnZ then return nil end
    return receipts, back.endedAt
end

local function rememberObjectiveWork(commitment, process)
    if commitment.work.objectiveExperienceReceiptId then return true end
    local receipts, at = objectiveWorkReceipts(commitment, process)
    local person = receipts and SAO.Identity and SAO.Identity.get(commitment.actorId)
    if not person or not finite(commitment.acceptedAt) or not finite(at)
        or at < commitment.acceptedAt or at > nowHours() then return false end
    person.fulfilledWorkSequence = (person.fulfilledWorkSequence or 0) + 1
    local row = { actorId = commitment.actorId,
        sequence = person.fulfilledWorkSequence,
        commitmentId = commitment.id, workKind = "watch-return",
        nativeReceiptId = receipts["return"],
        acceptedAt = commitment.acceptedAt, atHours = at,
        status = "completed" }
    person.fulfilledWorkOutcomes = person.fulfilledWorkOutcomes or {}
    person.fulfilledWorkOutcomes[#person.fulfilledWorkOutcomes + 1] = row
    if #person.fulfilledWorkOutcomes > 32 then
        table.remove(person.fulfilledWorkOutcomes, 1)
    end
    commitment.work.objectiveExperienceReceiptId = receipts["return"]
    if SAO.Cognition and SAO.Cognition.commitmentOutcome then
        SAO.Cognition.commitmentOutcome(commitment.actorId, row)
    end
    return true
end

local function objectiveCommitment(process, actorId)
    if not process or process.kind ~= "cooperative-action" then return nil end
    for _, commitment in pairs(process.commitments or {}) do
        if commitment.actorId == actorId
            and commitment.revision == process.revision then
            return commitment
        end
    end
end

local function objectiveReviewScope(process, actorId, playerId)
    if not process or process.originatorId ~= playerId then return nil end
    local commitment = objectiveCommitment(process, actorId)
    local proposalRow = commitment and proposalAt(process, commitment.revision)
    local proposal = proposalRow and proposalRow.proposal
    local scope = proposal and proposal.scope
    if not proposal or proposal.objective ~= "player-marked-watch-return"
        or type(scope) ~= "table"
        or scope.recipientId ~= actorId then return nil end
    return commitment, proposal, scope
end

-- An originator who meets the helper can inspect the attempts belonging to
-- this exact commitment. Terminal routes need their native route receipt;
-- a pending route is only an admitted attempt, never a completed result.
function Org.objectiveAttemptEvidence(processId, actorId, playerId)
    local process = processOf(processId)
    local commitment, proposal, scope = objectiveReviewScope(process,
        actorId, playerId)
    if not commitment then return nil end
    local destination = type(proposal.destination) == "table"
        and proposal.destination or {}
    local attempts, failed = {}, false
    for _, route in ipairs(commitment.work
            and commitment.work.routeAttempts or {}) do
        local stepId = nil
        if route.phase == "travelling" then
            if route.x == destination.minX and route.x == destination.maxX
                and route.y == destination.minY
                and route.y == destination.maxY and route.z == destination.z then
                stepId = "outbound"
            elseif route.x == scope.returnX and route.y == scope.returnY
                and route.z == scope.returnZ then
                stepId = "return"
            end
        end
        local status = tostring(route.status or "")
        local receipt = route.id and Org.workReceipts["route:" .. route.id]
        local proved = status == "pending" and receipt == nil
            and finite(route.startedAt) or receipt
            and receipt.kind == "route" and receipt.receiptId == route.id
            and receipt.commitmentId == commitment.id
            and receipt.status == status and finite(route.startedAt)
            and finite(route.endedAt)
            and route.endedAt >= route.startedAt
        if stepId and identity(route.id) and proved
            and (status == "pending" or status == "arrived"
                or status == "failed" or status == "interrupted") then
            attempts[#attempts + 1] = { id = route.id,
                stepId = stepId, owner = tostring(route.owner or ""),
                status = status, x = route.x, y = route.y, z = route.z,
                startedAt = route.startedAt, endedAt = route.endedAt }
            failed = failed or status == "failed" or status == "interrupted"
        end
    end
    local procedure = procedureAt(process, commitment.revision)
    local watch = procedure and procedure.steps and procedure.steps.watch
    local contribution = watch and watch.contributions
        and watch.contributions[actorId]
    local watchReceiptId = contribution and identity(contribution.receiptId)
    local watchReceipt = watchReceiptId
        and Org.workReceipts["procedure:" .. watchReceiptId]
    local watchCompleted = watch and watch.status == "completed"
        and watchReceipt and watchReceipt.kind == "procedure"
        and watchReceipt.commitmentId == commitment.id
        and watchReceipt.receiptId == watchReceiptId
        and watchReceipt.token == "posture:maintained"
        and watchReceipt.owner == "Posture"
        and watchReceipt.status == "completed" or false
    local receipts = objectiveWorkReceipts(commitment, process)
    local partial = watchCompleted
    if not partial then
        local outbound = procedure and procedure.steps
            and procedure.steps.outbound
        local outboundContribution = outbound and outbound.contributions
            and outbound.contributions[actorId]
        local outboundId = outboundContribution
            and identity(outboundContribution.receiptId)
        local outboundReceipt = outboundId
            and Org.workReceipts["route:" .. outboundId]
        partial = outbound and outbound.status == "completed"
            and outboundReceipt and outboundReceipt.kind == "route"
            and outboundReceipt.receiptId == outboundId
            and outboundReceipt.commitmentId == commitment.id
            and outboundReceipt.status == "arrived" or false
    end
    local outcome = receipts and "completed"
        or partial and "partial"
        or failed and "failed-attempt"
        or #attempts > 0 and "in-progress" or "not-started"
    return { processId = process.id, revision = commitment.revision,
        actorId = actorId, playerId = playerId,
        commitmentId = commitment.id,
        commitmentStatus = commitment.status,
        workOutcome = outcome, watchStatus = watchCompleted
            and "completed" or nil,
        watchReceiptId = watchCompleted and watchReceiptId or nil,
        attempts = attempts }
end

function Org.objectiveWorkReady(processId, actorId, recipientId)
    local process = processOf(processId)
    if not process or process.originatorId ~= recipientId then return false end
    local commitment = objectiveCommitment(process, actorId)
    return objectiveWorkReceipts(commitment, process) ~= nil
end

local function boundObjectiveReport(process, actorId, recipientId)
    local commitment = objectiveReviewScope(process, actorId, recipientId)
    local receipts = objectiveWorkReceipts(commitment, process)
    local key = commitment and actorId .. ":"
        .. tostring(commitment.revision)
    local report = key and type(process.objectiveWorkReports) == "table"
        and process.objectiveWorkReports[key]
    if not report or not receipts
        or report.processId ~= process.id
        or report.revision ~= commitment.revision
        or report.actorId ~= actorId
        or report.recipientId ~= recipientId
        or report.status ~= "completed"
        or report.channel ~= "spoken"
        or report.outboundReceiptId ~= receipts.outbound
        or report.watchReceiptId ~= receipts.watch
        or report.returnReceiptId ~= receipts["return"]
        or not finite(report.deliveredAt)
        or not finite(commitment.acceptedAt)
        or report.deliveredAt < commitment.acceptedAt
        or report.deliveredAt > nowHours() then return nil end
    return report, commitment, receipts
end

function Org.objectiveReportFor(processId, actorId, recipientId)
    local process = processOf(processId)
    local report = boundObjectiveReport(process, actorId, recipientId)
    return report and dataCopy(report) or nil
end

function Org.recordObjectiveWorkReport(processId, actorId, recipientId)
    if not (SAO.Communication and SAO.Communication.objectiveReportTransport
        and SAO.Communication.objectiveReportTransport(processId, actorId,
            recipientId) == true) then return nil, "report-transport-unavailable" end
    local process = processOf(processId)
    if not process or process.originatorId ~= recipientId then
        return nil, "report-recipient-mismatch"
    end
    local commitment = objectiveCommitment(process, actorId)
    local receipts = objectiveWorkReceipts(commitment, process)
    if not receipts then return nil, "work-not-complete" end
    local key = actorId .. ":" .. tostring(commitment.revision)
    process.objectiveWorkReports = process.objectiveWorkReports or {}
    local prior = process.objectiveWorkReports[key]
    if prior then
        if boundObjectiveReport(process, actorId, recipientId) == prior then
            return dataCopy(prior), "duplicate"
        end
        return nil, "report-receipt-conflict"
    end
    local at = nowHours()
    local report = { processId = process.id,
        revision = commitment.revision, actorId = actorId,
        recipientId = recipientId, status = "completed",
        outboundReceiptId = receipts.outbound,
        watchReceiptId = receipts.watch,
        returnReceiptId = receipts["return"],
        channel = "spoken", deliveredAt = at }
    process.objectiveWorkReports[key] = report
    appendBounded(process.events, { kind = "objective-work-report",
        actorId = actorId, recipientId = recipientId,
        receiptId = receipts["return"], at = at }, MAX_EVENTS)
    return dataCopy(report), "delivered"
end

-- A player inspection is a durable source-bound fact in the same process as
-- the helper's report. It does not create a training candidate or another
-- person's experience. The native menu owner supplies the current player body.
function Org.objectivePlayerReviewFor(processId, actorId, playerId)
    local process = processOf(processId)
    local report, commitment = boundObjectiveReport(process,
        actorId, playerId)
    local key = commitment and actorId .. ":"
        .. tostring(commitment.revision)
    local review = key and type(process.objectivePlayerReviews) == "table"
        and process.objectivePlayerReviews[key]
    if not report or not review
        or review.processId ~= process.id
        or review.revision ~= commitment.revision
        or review.actorId ~= actorId or review.playerId ~= playerId
        or review.commitmentId ~= commitment.id
        or review.outboundReceiptId ~= report.outboundReceiptId
        or review.watchReceiptId ~= report.watchReceiptId
        or review.returnReceiptId ~= report.returnReceiptId
        or review.reportDeliveredAt ~= report.deliveredAt
        or not finite(review.reviewedAt)
        or review.reviewedAt < report.deliveredAt
        or review.reviewedAt > nowHours()
        or review.status ~= "inspected"
        or type(review.attempts) ~= "table" then return nil end
    local current = Org.objectiveAttemptEvidence(processId,
        actorId, playerId)
    if not current or current.workOutcome ~= "completed"
        or #current.attempts ~= #review.attempts then return nil end
    for index, attempt in ipairs(current.attempts) do
        local recorded = review.attempts[index]
        if type(recorded) ~= "table" then return nil end
        for _, field in ipairs({ "id", "stepId", "owner", "status",
                "x", "y", "z", "startedAt", "endedAt" }) do
            if attempt[field] ~= recorded[field] then return nil end
        end
    end
    return dataCopy(review)
end

function Org.recordObjectivePlayerReview(processId, actorId, playerId,
                                         returnReceiptId, playerObj)
    if not playerObj or not (SAO.Standing and SAO.Standing.playerKey
        and SAO.Communication and SAO.Communication.bodyFor
        and SAO.Communication.canConverse) then
        return nil, "review-player-unavailable"
    end
    local keyOk, key = pcall(SAO.Standing.playerKey, playerObj)
    local bodyOk, body = pcall(SAO.Communication.bodyFor, playerId)
    local hearingOk, canHear = pcall(SAO.Communication.canConverse,
        playerId, actorId)
    if not keyOk or key ~= playerId or not bodyOk or body ~= playerObj
        or not hearingOk or canHear ~= true then
        return nil, "review-conversation-unavailable"
    end
    local process = processOf(processId)
    local report, commitment = boundObjectiveReport(process,
        actorId, playerId)
    if not report or identity(returnReceiptId) ~= report.returnReceiptId then
        return nil, "review-report-unavailable"
    end
    process.objectivePlayerReviews = process.objectivePlayerReviews or {}
    local reviewKey = actorId .. ":" .. tostring(commitment.revision)
    if process.objectivePlayerReviews[reviewKey] then
        local prior = Org.objectivePlayerReviewFor(processId,
            actorId, playerId)
        if prior then return prior, "duplicate" end
        return nil, "review-binding-conflict"
    end
    local evidence = Org.objectiveAttemptEvidence(processId,
        actorId, playerId)
    if not evidence or evidence.workOutcome ~= "completed" then
        return nil, "review-evidence-unavailable"
    end
    local at = nowHours()
    local review = { processId = process.id,
        revision = commitment.revision, actorId = actorId,
        playerId = playerId, commitmentId = commitment.id,
        outboundReceiptId = report.outboundReceiptId,
        watchReceiptId = report.watchReceiptId,
        returnReceiptId = report.returnReceiptId,
        reportDeliveredAt = report.deliveredAt,
        reviewedAt = at, status = "inspected",
        attempts = dataCopy(evidence.attempts) }
    process.objectivePlayerReviews[reviewKey] = review
    event(process, "objective-player-reviewed", playerId, {
        actorId = actorId, commitmentId = commitment.id,
        returnReceiptId = report.returnReceiptId }, at)
    return dataCopy(review), "recorded"
end

-- Registered native action owners use this boundary for procedure verbs that
-- are not SourceUse or Handover. Admission and result identity are exact; a
-- narration, state label or elapsed timer cannot complete a step.
function Org.consumeProcedureResult(result, authority)
    if type(result) ~= "table" then return false, "invalid-result" end
    local commitment, process = Org.commitment(result.commitmentId)
    if process and process.kind == "leisure-participation" and authority ~= PARTICIPATION then return false end
    if process and process.kind == "leisure-duet" and authority ~= DUET then return false end
    if process and process.kind == "leisure-dance" and authority ~= DANCE then return false end
    local receiptId = identity(result.id)
    local token = identity(result.token)
    local status = tostring(result.status or "")
    if not commitment or not process or not receiptId or not token
        or result.actorId ~= commitment.actorId
        or commitment.work.pendingReceiptId ~= receiptId
        or (status ~= "completed" and status ~= "failed"
            and status ~= "interrupted") then
        return false, "result-not-admitted"
    end
    local key = "procedure:" .. receiptId
    local prior = Org.workReceipts[key]
    if prior then
        if prior.commitmentId == commitment.id then return true, "duplicate" end
        return false, "receipt-conflict"
    end
    local procedure = procedureAt(process, commitment.revision)
    local stepId = identity(result.stepId)
        or (privatePlanAt(process, commitment.actorId, commitment.revision)
            or {}).intendedStepId
    local step = procedure and procedure.steps and procedure.steps[stepId] or nil
    local claim = step and step.claims
        and step.claims[commitment.actorId] or nil
    if procedure and procedure.cooperative
        and (not claim or claim.commitmentId ~= commitment.id) then
        return false, "step-not-claimed"
    end
    Org.workReceipts[key] = { kind = "procedure", receiptId = receiptId,
        commitmentId = commitment.id, owner = tostring(result.owner or "native"),
        token = token, status = status, at = nowHours() }
    commitment.work.pendingReceiptId = nil
    if status == "completed" then
        local witnesses = { commitment.actorId }
        for _, witness in ipairs(type(result.witnesses) == "table"
            and result.witnesses or {}) do witnesses[#witnesses + 1] = witness end
        local completed, why = completeProcedureToken(commitment, token,
            receiptId, witnesses, result.evidence or {
                owner = result.owner, status = status }, result.at)
        if not completed then return false, why end
        if result.owner=="Cooking" and token=="cooking:prepared" then
            local sequence=tonumber(receiptId:match("/(%d+)$"))
            local native=SAO.Cooking and SAO.Cooking.outcome and SAO.Cooking.outcome(commitment.actorId,sequence)
            rememberFulfilledWork(commitment,"prepare",receiptId,native)
        end
        workEvent(commitment, commitment.status == "completed"
            and "completed" or "step-completed", {
                stepId = stepId, token = token, receiptId = receiptId })
        return true, "completed"
    end
    local at = finite(result.at) and result.at or nowHours()
    if claim then
        claim.status = "failed"
        claim.failedAt = at
        claim.reason = tostring(result.reason or status)
    end
    if procedure then
        procedure.revisionNeeded = { stepId = stepId,
            actorId = commitment.actorId,
            reason = tostring(result.reason or status), at = at }
        appendBounded(procedure.events, { kind = "step-failed",
            stepId = stepId, actorId = commitment.actorId,
            receiptId = receiptId, status = status,
            reason = tostring(result.reason or status), at = at }, 128)
    end
    updatePrivatePlan(process, commitment.actorId, commitment.revision,
        stepId, "blocked", { kind = "receipt", token = token,
            receiptId = receiptId, status = status }, at)
    commitment.status = "paused"
    commitment.work.phase = "awaiting-revision"
    commitment.work.pauseReason = tostring(result.reason or status)
    workEvent(commitment, "step-failed", { stepId = stepId,
        receiptId = receiptId, reason = commitment.work.pauseReason }, at)
    return true, status
end

local MAX_EQUIVALENT_ROUTE_FAILURES = 3
local ROUTE_RETRY_HOURS = 1 / 60

local function sameRouteEvidence(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    return left.fromX == right.fromX and left.fromY == right.fromY
        and left.fromZ == right.fromZ and left.sourceX == right.sourceX
        and left.sourceY == right.sourceY and left.sourceZ == right.sourceZ
        and left.knownSources == right.knownSources
end

local function equivalentRouteFailures(commitment, x, y, z, phase, evidence)
    local count = 0
    for _, route in ipairs(commitment.work.routeAttempts or {}) do
        if finite(route.x) and finite(route.y) and finite(route.z)
            and finite(x) and finite(y) and finite(z)
            and math.floor(route.x) == math.floor(x)
            and math.floor(route.y) == math.floor(y)
            and math.floor(route.z) == math.floor(z)
            and route.phase == phase
            and sameRouteEvidence(route.retryEvidence, evidence) then
            if route.status == "arrived" then count = 0
            elseif route.status == "failed" or route.status == "interrupted" then
                count = count + 1
            end
        end
    end
    return count
end

function Org.routeRetryReady(commitmentId)
    local commitment = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status]
        or commitment.status == "contested" then return false, "work-ended" end
    if nowHours() < (tonumber(commitment.work.routeRetryAt) or 0) then
        return false, "route-backoff"
    end
    return true
end

-- This guard describes failed attempts, not permission or source truth.
-- Execution supplies its current private evidence and revalidates access.
function Org.routeMayStart(commitmentId, x, y, z, phase, evidence)
    if not finite(x) or not finite(y) or not finite(z) then
        return false, "route-destination-unavailable"
    end
    local ready, reason = Org.routeRetryReady(commitmentId)
    if not ready then return false, reason end
    local commitment = Org.commitment(commitmentId)
    if equivalentRouteFailures(commitment, x, y, z, phase, evidence)
        >= MAX_EQUIVALENT_ROUTE_FAILURES then
        return false, "route-awaits-changed-evidence"
    end
    return true
end

function Org.noteRoute(commitmentId, owner, x, y, z, phase, evidence)
    local commitment = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status] then return false end
    phase = phase == "acquiring" and "acquiring"
        or phase == "travelling" and "travelling" or "carrying"
    local allowed, reason = Org.routeMayStart(commitmentId, x, y, z, phase, evidence)
    if not allowed then return false, reason end
    if commitment.status == "paused" then
        Org.resumeWork(commitmentId, commitment.work.owner or owner, phase,
            { routeEvidence = evidence })
    end
    commitment.work.routeSequence = math.max(0,
        math.floor(tonumber(commitment.work.routeSequence) or 0)) + 1
    local attempt = { id = commitment.id .. ":route:"
            .. tostring(commitment.work.routeSequence),
        owner = tostring(owner or "Locomotion"), phase = phase,
        x = tonumber(x), y = tonumber(y), z = tonumber(z),
        startedAt = nowHours(), status = "pending",
        retryEvidence = dataCopy(evidence) }
    commitment.status = "in-progress"
    appendBounded(commitment.work.routeAttempts, attempt, 64)
    workEvent(commitment, phase, { route = attempt })
    return attempt
end

function Org.routeOutcome(commitmentId, status, detail)
    local commitment, process = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status] then return false end
    local routes = commitment.work.routeAttempts or {}
    local route = routes[#routes]
    if not route or route.status ~= "pending" then
        return false, "no-pending-route"
    end
    route.status = tostring(status or "interrupted")
    route.endedAt = nowHours()
    route.detail = tostring(detail or status or "")
    local routeKey = route.id and "route:" .. route.id or nil
    if routeKey then
        Org.workReceipts[routeKey] = Org.workReceipts[routeKey] or {
            kind = "route", receiptId = route.id,
            commitmentId = commitment.id, status = route.status,
            at = route.endedAt,
        }
    end
    if status == "arrived" then
        commitment.work.routeRetryAt = nil
        local arrivedPhase = route.phase == "acquiring" and "acquiring"
            or route.phase == "travelling" and "arrival-ready"
            or "delivery-ready"
        workEvent(commitment, arrivedPhase,
            { detail = detail, routeId = route.id })
        completeProcedureToken(commitment, "route:" .. route.phase,
            route.id, { commitment.actorId }, {
                owner = route.owner, status = route.status,
                x = route.x, y = route.y, z = route.z })
        if process then rememberObjectiveWork(commitment, process) end
    else
        local failures = equivalentRouteFailures(commitment,
            route.x, route.y, route.z, route.phase, route.retryEvidence)
        commitment.work.routeRetryAt = nowHours()
            + ROUTE_RETRY_HOURS * math.min(4, 2 ^ math.max(0, failures - 1))
        Org.pauseWork(commitmentId, "route-" .. route.status, {
            detail = detail, routeId = route.id,
            retryAt = commitment.work.routeRetryAt,
        })
    end
    return true, route
end

-- Locomotion's arrived result is necessary but not, by itself, a social
-- outcome.  This consumes that exact route once and records only the bounded
-- holding activity promised by the proposal; downstream combat, exposure,
-- settlement or affiliation remains owned elsewhere.
function Org.completeArrival(commitmentId, routeId, activity, evidence)
    local commitment, process = Org.commitment(commitmentId)
    routeId = identity(routeId)
    if not commitment or not process or not routeId then
        return false, "arrival-not-admitted"
    end
    local key = "arrival:" .. routeId
    local prior = Org.workReceipts[key]
    if prior then
        if prior.commitmentId == commitment.id then return true, "duplicate" end
        return false, "receipt-conflict"
    end
    if TERMINAL_WORK[commitment.status]
        or process.kind ~= "rendezvous-holding" then
        return false, "arrival-not-admitted"
    end
    local matched = nil
    for _, route in ipairs(commitment.work.routeAttempts or {}) do
        if route.id == routeId then matched = route break end
    end
    if not matched or matched.status ~= "arrived"
        or matched.phase ~= "travelling" then
        return false, "arrival-not-admitted"
    end
    local proposalRevision = proposalAt(process, commitment.revision)
    local proposal = proposalRevision and proposalRevision.proposal or {}
    local scope = type(proposal.scope) == "table" and proposal.scope or {}
    local promisedActivity = identity(scope.arrivalActivity
        or proposal.arrivalActivity) or "holding-place"
    activity = identity(activity) or promisedActivity
    if activity ~= promisedActivity then return false, "arrival-scope-mismatch" end
    local destination = type(proposal.destination) == "table"
        and proposal.destination or nil
    if not destination or not finite(matched.x) or not finite(matched.y)
        or not finite(matched.z)
        or not finite(destination.minX) or not finite(destination.minY)
        or not finite(destination.maxX) or not finite(destination.maxY)
        or matched.x < destination.minX or matched.x > destination.maxX
        or matched.y < destination.minY or matched.y > destination.maxY
        or (finite(destination.z) and matched.z ~= destination.z) then
        return false, "arrival-route-mismatch"
    end
    Org.workReceipts[key] = { kind = "arrival", receiptId = routeId,
        commitmentId = commitment.id, activity = activity, at = nowHours() }
    commitment.status = "completed"
    commitment.work.arrivalReceiptId = routeId
    commitment.work.arrivalActivity = activity
    commitment.work.completedAt = nowHours()
    commitment.work.endedAt = commitment.work.completedAt
    workEvent(commitment, "completed", { routeId = routeId,
        activity = activity, evidence = dataCopy(evidence or {}) },
        commitment.work.completedAt)
    completeProcedureToken(commitment, "arrival:" .. activity, routeId,
        { commitment.actorId }, evidence, commitment.work.completedAt)
    return true, "completed"
end

function Org.interruptWork(commitmentId, reason, partial)
    local commitment = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status] then return false end
    local isPartial = partial == true or commitment.work.acquiredAt ~= nil
    commitment.status = isPartial and "interrupted" or "failed"
    workEvent(commitment, isPartial and "partial" or "failed",
        { reason = tostring(reason or "interrupted") })
    commitment.work.endedAt = nowHours()
    return true
end

local function receiptIdentity(receipt, kind)
    if kind == "source" then
        return identity(receipt and receipt.reservationId)
    end
    return identity(receipt and receipt.id)
end

local function receiptBound(commitment, receipt, receiptId)
    return receipt.processId == commitment.processId
        and tonumber(receipt.processRevision) == tonumber(commitment.revision)
        and receipt.actorId == commitment.actorId
        and commitment.work.pendingReceiptId == receiptId
end

function Org.consumeSourceResult(receipt)
    if type(receipt) ~= "table" or not identity(receipt.commitmentId) then
        return false, "not-coordinated"
    end
    local receiptId = receiptIdentity(receipt, "source")
    local receiptKey = receiptId and "source:" .. receiptId or nil
    local prior = receiptKey and Org.workReceipts[receiptKey] or nil
    if prior then
        if prior.commitmentId == receipt.commitmentId then return true, "duplicate" end
        return false, "receipt-conflict"
    end
    local commitment = Org.commitment(receipt.commitmentId)
    if not receiptId or not commitment
        or TERMINAL_WORK[commitment.status]
        or not receiptBound(commitment, receipt, receiptId)
        or (receipt.operation ~= "acquire" and receipt.operation ~= "store")
        or receipt.status == "pending" or receipt.status == "reserved" then
        return false, "receipt-not-admitted"
    end
    Org.workReceipts["source:" .. receiptId] = { kind = "source",
        receiptId = receiptId, commitmentId = commitment.id, at = nowHours() }
    commitment.work.sourceReceipts[receiptId] = {
        owner = "SourceUse",
        operation = receipt.operation, status = receipt.status,
        detail = receipt.detail, at = receipt.at,
        observed = receipt.transferObservation ~= nil }
    commitment.work.pendingReceiptId = nil
    if receipt.status == "completed" and receipt.operation == "acquire" then
        commitment.status = "in-progress"
        commitment.work.acquiredAt = receipt.at or nowHours()
        commitment.work.acquisitionReceiptId = receiptId
        workEvent(commitment, "carrying", { receiptId = receiptId })
        completeProcedureToken(commitment, "source:acquire", receiptId,
            { commitment.actorId }, { owner = "SourceUse",
                status = receipt.status, operation = receipt.operation },
            commitment.work.acquiredAt)
    elseif receipt.status == "completed" and receipt.operation == "store" then
        commitment.status = "completed"
        commitment.work.deliveryReceiptId = receiptId
        commitment.work.completedAt = receipt.at or nowHours()
        commitment.work.endedAt = commitment.work.completedAt
        workEvent(commitment, "completed", { receiptId = receiptId })
        local native=SAO.WorldSources and SAO.WorldSources.actionOutcome and SAO.WorldSources.actionOutcome(receiptId,commitment.actorId)
        if native and native.reservationId==receiptId and native.operation=="store" then
            rememberFulfilledWork(commitment,"deliver",receiptId,native)
        end
        completeProcedureToken(commitment, "source:store", receiptId,
            { commitment.actorId }, { owner = "SourceUse",
                status = receipt.status, operation = receipt.operation },
            commitment.work.completedAt)
    else
        local partial = commitment.work.acquiredAt ~= nil
            or receipt.transferObservation ~= nil
        commitment.status = partial and "interrupted" or "failed"
        workEvent(commitment, partial and "partial" or "failed", {
            receiptId = receiptId, status = receipt.status,
            detail = receipt.detail })
        commitment.work.endedAt = nowHours()
    end
    return true
end

function Org.consumeHandoverResult(receipt)
    if type(receipt) ~= "table" or not identity(receipt.commitmentId) then
        return false, "not-coordinated"
    end
    local receiptId = receiptIdentity(receipt, "handover")
    local receiptKey = receiptId and "handover:" .. receiptId or nil
    local prior = receiptKey and Org.workReceipts[receiptKey] or nil
    if prior then
        if prior.commitmentId == receipt.commitmentId then return true, "duplicate" end
        return false, "receipt-conflict"
    end
    local commitment = Org.commitment(receipt.commitmentId)
    if not receiptId or not commitment or TERMINAL_WORK[commitment.status]
        or not receiptBound(commitment, receipt, receiptId)
        or (receipt.recipientId ~= nil
            and receipt.recipientId ~= commitment.beneficiaryId)
        or receipt.status == "pending" then return false, "receipt-not-admitted" end
    Org.workReceipts["handover:" .. receiptId] = { kind = "handover",
        receiptId = receiptId, commitmentId = commitment.id, at = nowHours() }
    commitment.work.handoverReceipts[receiptId] = {
        owner = "Handover",
        status = receipt.status, reason = receipt.reason,
        completedAt = receipt.completedAt }
    commitment.work.pendingReceiptId = nil
    if receipt.status == "completed" then
        commitment.status = "completed"
        commitment.work.deliveryReceiptId = receiptId
        commitment.work.completedAt = receipt.completedAt or nowHours()
        commitment.work.endedAt = commitment.work.completedAt
        workEvent(commitment, "completed", { receiptId = receiptId })
        local native=SAO.Handover and SAO.Handover.result and SAO.Handover.result(receiptId)
        if native and native.id==receiptId and native.recipientId==commitment.beneficiaryId then
            rememberFulfilledWork(commitment,"deliver",receiptId,native)
        end
        completeProcedureToken(commitment, "handover:completed", receiptId,
            { commitment.actorId, commitment.beneficiaryId }, {
                owner = "Handover", status = receipt.status,
                recipientId = receipt.recipientId },
            commitment.work.completedAt)
    else
        local partial = commitment.work.acquiredAt ~= nil
        commitment.status = partial and "interrupted" or "failed"
        workEvent(commitment, partial and "partial" or "failed", {
            receiptId = receiptId, status = receipt.status,
            reason = receipt.reason })
        commitment.work.endedAt = nowHours()
    end
    return true
end

-- Private decision-time view. Other recipients' unreturned answers and
-- everybody else's private inputs are absent.
function Org.viewFor(personId, processId, includeOutcomes, requestedRevision)
    local process = processOf(processId)
    personId = identity(personId)
    local row = process and process.participants
        and process.participants[personId] or nil
    if not process or not personId or not row then return nil end
    local selectedRevision = math.floor(tonumber(requestedRevision)
        or tonumber(process.revision) or 1)
    local selectedKey = revisionKey(selectedRevision)
    local selectedProposal = proposalAt(process, selectedRevision)
    if not selectedProposal then return nil end
    local currentReception = row.receptions[selectedKey]
    local acquired = personId == process.originatorId
        or currentReception ~= nil
    local view = { id = process.id, kind = process.kind,
        organizationId = process.organizationId,
        originatorId = process.originatorId, createdAt = process.createdAt,
        revisedAt = selectedProposal.proposedAt, revision = selectedRevision,
        currentRevision = process.revision,
        status = process.status,
        proposal = acquired and dataCopy(selectedProposal) or nil,
        reception = dataCopy(currentReception),
        response = dataCopy(responseAt(process, personId, selectedRevision)),
        responseHistory = dataCopy(row.responseHistory
            and row.responseHistory[selectedKey] or {}),
        privateInputs = dataCopy(process.privateInputs[personId]
            and process.privateInputs[personId][selectedKey]),
        privateProcedure = dataCopy(privatePlanAt(process, personId,
            selectedRevision)),
        responses = {}, commitments = {} }
    if personId == process.originatorId then
        for responderId, participantRow in pairs(process.participants or {}) do
            local response = participantRow.responses
                and participantRow.responses[selectedKey] or nil
            if response and response.delivered then
                view.responses[responderId] = dataCopy(response)
            elseif responderId ~= personId and participantRow.addressed then
                view.responses[responderId] = { response = "unanswered" }
            end
        end
    end
    -- A commitment exists only after the actor's response has returned to the
    -- originator, and every route/native receipt is later still. None belongs
    -- in the decision-time feature horizon. Outcome views expose the durable
    -- commitment and work record to the two people who own that relationship.
    if includeOutcomes == true then
        for commitmentId, commitment in pairs(process.commitments or {}) do
            if personId == process.originatorId
                or personId == commitment.actorId then
                if tonumber(commitment.revision) == selectedRevision then
                    view.commitments[commitmentId] = dataCopy(commitment)
                end
            end
        end
    end
    return view
end

function Org.decisionEvidence(processId, personId, requestedRevision)
    local process = processOf(processId)
    local revision = math.floor(tonumber(requestedRevision)
        or (process and tonumber(process.revision)) or 0)
    local decision = Org.viewFor(personId, processId, false, revision)
    local outcome = Org.viewFor(personId, processId, true, revision)
    if not decision then return nil end
    local formedAt = decision.response and decision.response.formedAt
        or decision.proposal and decision.proposal.proposedAt
    if not finite(formedAt) then return nil end
    -- A response object is updated when its return channel later succeeds.
    -- Reconstruct the earlier choice horizon rather than exporting those
    -- delivery fields as if the actor knew their future at decision time.
    if decision.response then
        decision.response.delivered = false
        decision.response.deliveredAt = nil
        decision.response.channel = nil
        decision.response.deliveryEvidence = nil
    end
    decision.status = "open"
    decision.currentRevision = revision
    decision.asOfHour = formedAt
    decision.commitments = {}
    decision.privateProcedure = nil
    if outcome then
        outcome.asOfHour = nowHours()
        outcome.privateInputs = nil
        outcome.responses = nil
        outcome.proposal = nil
        outcome.reception = nil
        outcome.responseHistory = nil
    end
    return { schema = 1, processId = processId,
        processRevision = revision, actorId = personId,
        decisionTime = decision, laterOutcome = outcome }
end

-- Compatibility readers now consult explicit process state. No trust score,
-- roster size, or office label can manufacture deference.
function Org.deference(personId, organizationId, _officeId, matter)
    for _, process in pairs(Org.processes) do
        if process.organizationId == organizationId and process.kind == matter then
            local response = responseAt(process, personId)
            if response and response.delivered then return response.response end
        end
    end
    return "unanswered"
end

function Org.playerAction(personId, organizationId, action, target, addressedIds)
    if type(personId) ~= "string" or type(action) ~= "string" then return nil end
    local addressed = type(addressedIds) == "table" and addressedIds or {}
    local process = Org.raiseMatter(personId, action, organizationId, {
        action = action, target = target,
        scope = { action = action, target = target },
    }, addressed, { source = "player-action" })
    if not process then return nil end
    local claim = Org.recordClaim(personId, action, target, organizationId,
        { processId = process.id, revision = process.revision })
    if claim then
        claim.processId = process.id
        claim.processRevision = process.revision
    end
    return claim
end

-- Participation is a procedure, with private knowledge in the existing
-- per-person/revision inputs. Hearing and the reported hearing are separate.
local function participation(processId)
    local process = processOf(processId)
    local revision = process and proposalAt(process)
    local terms = revision and revision.proposal
    if not process or process.kind ~= "leisure-participation" or not terms
        or not finite(terms.expiresAtHours) or terms.expiresAtHours < nowHours()
        or process.status == "withdrawn" or process.status == "superseded" or process.status == "expired"
        or terms.performerId ~= process.originatorId or type(terms.listenerId) ~= "string" then return nil end
    return process, terms
end

local function participationPrivate(process, id, create)
    local all = process.privateInputs[id]
    if not all and create then all = {}; process.privateInputs[id] = all end
    local key = revisionKey(process.revision)
    if all and not all[key] and create then all[key] = {} end
    local input = all and all[key]
    if input and not input.participation and create then input.participation = {} end
    return input and input.participation
end

local function participationCommitment(process, id)
    for _, c in pairs(process.commitments or {}) do
        if c.actorId == id and c.revision == process.revision
            and (c.status == "accepted" or c.status == "in-progress" or c.status == "completed") then return c end
    end
end

function Org.participationOffer(id, commitmentId)
    local c, raw = Org.commitment(commitmentId)
    local process, terms = participation(raw and raw.id)
    if not process or not c or c.actorId ~= id or c.revision ~= process.revision
        or (c.status ~= "accepted" and c.status ~= "in-progress") then return nil end
    local response = responseAt(process, terms.listenerId)
    if not response or response.response ~= "accept" or not response.delivered
        or not finite(response.deliveredAt) or response.deliveredAt > nowHours()
        or not participationCommitment(process, terms.listenerId) then return nil end
    local own = participationPrivate(process, id)
    return { processId = process.id, revision = process.revision, commitmentId = c.id,
        actorId = id, role = id == terms.performerId and "perform" or "listen",
        performerId = terms.performerId, listenerId = terms.listenerId, activity = terms.activity,
        sourcePurposeId = terms.sourcePurposeId, itemId = terms.itemId, itemType = terms.itemType,
        acceptedAt = response.deliveredAt, workId = own and own.workId,
        announcedAt = own and own.announcedAt, purposeId = own and own.purposeId }
end

function Org.admitParticipation(processId, id, purposeId, workId)
    local process, terms = participation(processId)
    local c = process and participationCommitment(process, id)
    local offer = c and Org.participationOffer(id, c.id)
    if offer and not SAO.Coordination.participationOffer(id, SAO.Body.get(id), c.id) then return false end
    local work = SAO.Gesture and SAO.Gesture.instrumentWork and SAO.Gesture.instrumentWork(id)
    local binding = SAO.ProceduralPlanning and SAO.ProceduralPlanning.participationBinding
        and SAO.ProceduralPlanning.participationBinding(id, purposeId)
    if not offer or offer.role ~= "perform" or not work or not binding
        or binding.processId ~= processId or binding.revision ~= process.revision
        or binding.commitmentId ~= c.id or binding.sourcePurposeId ~= terms.sourcePurposeId
        or work.workId ~= workId or work.status ~= "prepared" or work.itemId ~= terms.itemId
        or work.itemType ~= terms.itemType or work.verb ~= "blow-harmonica"
        or not finite(work.admittedAtHours) or work.admittedAtHours < offer.acceptedAt
        or work.admittedAtHours > nowHours() or work.sequence < terms.minimumSequence then return false end
    local own = participationPrivate(process, id, true)
    if own.workId then return own.workId == workId and own.purposeId == purposeId end
    own.workId, own.purposeId, own.preparedAt = workId, purposeId, work.admittedAtHours
    if not SAO.Communication.deliverParticipation(id, terms.listenerId, processId, "announcement") then
        own.workId, own.purposeId, own.preparedAt = nil, nil, nil
        return false
    end
    return Org.noteWorkAdmission(c.id, "SAO.Gesture", workId, { stepId = "perform" }, PARTICIPATION)
end

function Org.consumeParticipationPerformance(processId, id, workId)
    local process, terms = participation(processId)
    local own = process and participationPrivate(process, id)
    local c = process and participationCommitment(process, id)
    local result = SAO.Gesture and SAO.Gesture.instrumentOutcome and SAO.Gesture.instrumentOutcome(id, workId)
    local binding = own and SAO.ProceduralPlanning.participationBinding(id, own.purposeId)
    if not process or id ~= terms.performerId or not own or own.workId ~= workId or not c
        or not binding or not binding.physicalResult or binding.physicalResult.workId ~= workId
        or not result or result.workId ~= workId or result.actorId ~= id
        or result.itemId ~= terms.itemId or result.itemType ~= terms.itemType
        or not finite(result.atHours) or result.atHours < own.preparedAt or result.atHours > nowHours() then return false end
    if own.performance then return own.performance.workId == workId end
    if not Org.consumeProcedureResult({ commitmentId = c.id, actorId = id, id = workId,
        token = "participation:performed", stepId = "perform", owner = "SAO.Gesture",
        status = result.status, at = result.atHours, reason = "native-instrument-interrupted" }, PARTICIPATION) then return false end
    own.performance = { workId = workId, status = result.status, atHours = result.atHours }
    if own.acknowledgement then SAO.ProceduralPlanning.consumeParticipation(id, processId) end
    return true
end

function Org.consumeParticipationHearing(processId, id)
    local process, terms = participation(processId)
    local own = process and participationPrivate(process, id)
    local c = process and participationCommitment(process, id)
    local heard = own and own.workId and SAO.Perception.instrumentHearing(id, terms.performerId, own.workId)
    if not process or id ~= terms.listenerId or not c or not heard or not own.announcedAt
        or heard.acquiredAtCountyHours < own.announcedAt or heard.acquiredAtCountyHours > nowHours()
        or heard.workId ~= own.workId or heard.observerId ~= id or heard.actorId ~= terms.performerId then return false end
    if own.hearing then return own.hearing.pulseId == heard.pulseId end
    if not Org.noteWorkAdmission(c.id, "SAO.Perception", heard.pulseId, { stepId = "listen" }, PARTICIPATION)
        or not Org.consumeProcedureResult({ commitmentId = c.id, actorId = id, id = heard.pulseId,
            token = "participation:heard", stepId = "listen", owner = "SAO.Perception", status = "completed",
            at = heard.acquiredAtCountyHours }, PARTICIPATION) then return false end
    own.hearing = dataCopy(heard)
    return true
end

function Org.receiveParticipation(processId, fromId, toId, kind)
    local process, terms = participation(processId)
    if not process or not participationTransport(processId, fromId, toId, kind) then return false end
    if kind == "announcement" then
        local speaker = participationPrivate(process, fromId)
        local c = participationCommitment(process, fromId)
        if fromId ~= terms.performerId or toId ~= terms.listenerId or not speaker or not speaker.workId
            or not c or not Org.participationOffer(fromId, c.id) then return false end
        local work = SAO.Gesture.instrumentWork(fromId)
        if not work or work.workId ~= speaker.workId or work.status ~= "prepared" then return false end
        local listener = participationPrivate(process, toId, true)
        listener.workId, listener.announcedAt = work.workId, nowHours()
        return true
    end
    if kind ~= "acknowledgement" or fromId ~= terms.listenerId or toId ~= terms.performerId then return false end
    local listener, performer = participationPrivate(process, fromId), participationPrivate(process, toId)
    local hearing = listener and listener.hearing
    local retained = hearing and SAO.Perception.instrumentHearing(fromId, toId, hearing.workId)
    if not performer or not hearing or not retained or retained.pulseId ~= hearing.pulseId
        or retained.workId ~= performer.workId or retained.acquiredAtCountyHours ~= hearing.acquiredAtCountyHours
        or not finite(hearing.acquiredAtCountyHours) or hearing.acquiredAtCountyHours > nowHours() then return false end
    performer.acknowledgement = { fromId = fromId, workId = hearing.workId, pulseId = hearing.pulseId,
        heardAtHours = hearing.heardAtHours, acquiredAtCountyHours = hearing.acquiredAtCountyHours,
        deliveredAt = nowHours(), channel = "spoken" }
    listener.acknowledgedAt = nowHours()
    SAO.ProceduralPlanning.consumeParticipation(toId, processId)
    return true
end

function Org.participationAcknowledgements(fromId, toId)
    local out = {}
    for _, processId in ipairs(Org.processOrder) do
        local process, terms = participation(processId)
        local own = process and participationPrivate(process, fromId)
        if process and terms.listenerId == fromId and terms.performerId == toId
            and own and own.hearing and not own.acknowledgedAt then out[#out + 1] = { processId = processId } end
        if #out >= 8 then break end
    end
    return out
end

function Org.participationOutcome(id, processId)
    local process, terms = participation(processId)
    local own = process and participationPrivate(process, id)
    local a, p = own and own.acknowledgement, own and own.performance
    if not process or id ~= terms.performerId or not a or not p or p.status ~= "completed"
        or p.workId ~= a.workId or not finite(a.deliveredAt) or a.deliveredAt > nowHours()
        or not finite(p.atHours) or p.atHours > nowHours() then return nil end
    return { actorId = id, processId = processId, revision = process.revision,
        sourcePurposeId = terms.sourcePurposeId, purposeId = own.purposeId, workId = p.workId,
        itemId = terms.itemId, pulseId = a.pulseId, listenerId = a.fromId,
        atHours = math.max(p.atHours, a.deliveredAt), basis = "native-sound-and-delivered-hearing-acknowledgement" }
end

function Org.reconcileParticipation(processId, id, purposeId)
    local process = processOf(processId)
    local own = process and participationPrivate(process, id)
    local binding = SAO.ProceduralPlanning.participationBinding(id, purposeId)
    local c = process and participationCommitment(process, id)
    if not process or process.kind ~= "leisure-participation" or process.originatorId ~= id
        or not own or own.purposeId ~= purposeId or not c or not binding
        or not binding.physicalResult or binding.physicalResult.workId ~= own.workId
        or binding.physicalResult.status ~= "unobservable" or SAO.Gesture.instrumentWork(id)
        or SAO.Gesture.instrumentOutcome(id, own.workId) then return false end
    c.status, c.work.phase, c.work.pauseReason = "paused", "awaiting-revision", "native-performance-owner-lost"
    own.performance = { workId = own.workId, status = "unobservable", atHours = nowHours() }
    workEvent(c, "paused", { reason = "native-performance-owner-lost" })
    return true
end

-- Duets retain exact source parts within the existing proposal/reception/
-- response/claimed-commitment process. An invitation assigns no other actor.
local DUET_CHOICE_FIELDS={"id","actorId","sourceId","revision","catalogueRevision","activity",
    "instrumentType","itemKey","sound","length","trackLevel","songId","role","bodyToken"}
local function duetChoiceEqual(a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    for _,field in ipairs(DUET_CHOICE_FIELDS) do if a[field]~=b[field] then return false end end
    return true
end
local function duetChoiceFor(id,choiceId)
    local M=SAO.LeisureMusic;local body=SAO.Body and SAO.Body.get(id)
    return body and M and M.duetChoice and M.duetChoice(id,body,choiceId)
end
local function duetRoleAllowed(choice,role)
    for _,value in ipairs(choice and choice.partnerRoles or {}) do if value==role then return true end end
    return false
end
local function duetTerms(processId)
    local process=processOf(processId);local revision=process and proposalAt(process)
    local proposal=revision and revision.proposal;local terms=proposal and proposal.duet
    if not process or process.kind~="leisure-duet" or TERMINAL_PROCESS[process.status]
        or not terms or proposal.cooperative~=true or terms.sourceId~="LifestyleHobbies"
        or terms.originatorId~=process.originatorId or not identity(terms.partnerId)
        or terms.partnerId==terms.originatorId or not identity(terms.songId)
        or not finite(terms.expiresAtHours) or terms.expiresAtHours<nowHours() then return nil end
    return process,terms
end
function Org.proposeDuet(id,partnerId,choiceId,partnerRole,expiresAtHours)
    id,partnerId=identity(id),identity(partnerId)
    local choice=id and duetChoiceFor(id,choiceId)
    if not choice or not partnerId or partnerId==id or not duetRoleAllowed(choice,partnerRole)
        or not finite(expiresAtHours) or expiresAtHours<=nowHours() or expiresAtHours>nowHours()+24 then return nil,"invalid-source-duet-invitation" end
    local terms={sourceId=choice.sourceId,songId=choice.songId,originatorId=id,partnerId=partnerId,
        originatorRole=choice.role,partnerRole=partnerRole,originatorChoice=dataCopy(choice),expiresAtHours=expiresAtHours}
    local process,why=Org.raiseMatter(id,"leisure-duet",nil,{cooperative=true,
        objective="perform-source-duet",responsePolicy="procedure-completion",duet=terms,
        procedure={{id="perform-originator",verb="perform-duet",capability="perform-duet",owner="SAO.LeisureMusic",
            role=choice.role,assignedTo=id,completesOn={"duet:performed"}},
            {id="perform-partner",verb="perform-duet",capability="perform-duet",owner="SAO.LeisureMusic",
            role=partnerRole,assignedTo=partnerId,completesOn={"duet:performed"}}}}, {partnerId},
        {basis="personally-supported-source-part",choice=dataCopy(choice)},DUET)
    if not process then return nil,why end
    local commitment=Org.commitOriginator(process.id,id,{capabilities={["perform-duet"]=true},
        stepIds={"perform-originator"},evidence={sourceChoiceId=choice.id,songId=choice.songId,role=choice.role}})
    if not commitment then Org.withdrawMatter(process.id,id,"originator-part-not-claimed");return nil,"originator-part-not-claimed" end
    return {processId=process.id,revision=process.revision,choiceId=choice.id,partnerId=partnerId,
        role=choice.role,partnerRole=partnerRole,songId=choice.songId,expiresAtHours=expiresAtHours}
end
function Org.respondDuet(id,processId,choiceId,response,context)
    local process,terms=duetTerms(processId)
    if not process or id~=terms.partnerId then return nil,"not-invited-duet-performer" end
    local acquired=Org.viewFor(id,processId,false)
    if not acquired or not acquired.proposal or acquired.currentRevision~=process.revision then return nil,"duet-proposal-not-acquired" end
    context=dataCopy(context or {}) or {};context.choice=response
    if response=="accept" then
        local choice=duetChoiceFor(id,choiceId);local author=duetChoiceFor(terms.originatorId,terms.originatorChoice.id)
        if not choice or not duetChoiceEqual(author,terms.originatorChoice) or choice.sourceId~=terms.sourceId
            or choice.songId~=terms.songId or choice.role~=terms.partnerRole
            or not duetRoleAllowed(choice,terms.originatorRole) then return nil,"source-duet-part-incompatible" end
        context.capabilities={["perform-duet"]=true};context.stepIds={"perform-partner"}
        context.terms={stepIds={"perform-partner"},duetChoice=dataCopy(choice)}
    end
    return Org.appraiseMatter(processId,id,context,DUET)
end
local function duetCommitted(process,id,stepId)
    local procedure=procedureAt(process);local step=procedure and procedure.steps[stepId]
    for _,commitment in pairs(process.commitments or {}) do
        local claim=step and step.claims and step.claims[id]
        if commitment.actorId==id and commitment.revision==process.revision
            and (commitment.status=="accepted" or commitment.status=="in-progress" or commitment.status=="completed")
            and commitment.stepIds and commitment.stepIds[stepId] and claim and claim.commitmentId==commitment.id
            and (claim.status=="claimed" or claim.status=="attempting" or claim.status=="completed")
            and step.owner=="SAO.LeisureMusic" and step.assignedTo==id then return commitment end
    end
end
function Org.duetOffer(id,processId)
    local process,terms=duetTerms(processId)
    if not process or (id~=terms.originatorId and id~=terms.partnerId) then return nil end
    local view=Org.viewFor(id,processId,true)
    if not view or not view.proposal or view.currentRevision~=process.revision then return nil end
    local response=responseAt(process,terms.partnerId)
    if not response or response.response~="accept" or response.delivered~=true
        or response.revision~=process.revision or not finite(response.deliveredAt)
        or response.deliveredAt>nowHours() then return nil end
    local a=duetCommitted(process,terms.originatorId,"perform-originator")
    local b=duetCommitted(process,terms.partnerId,"perform-partner")
    local choiceA=duetChoiceFor(terms.originatorId,terms.originatorChoice.id)
    local agreed=response.terms and response.terms.duetChoice
    local choiceB=agreed and duetChoiceFor(terms.partnerId,agreed.id)
    if not a or not b or not duetChoiceEqual(choiceA,terms.originatorChoice) or not duetChoiceEqual(choiceB,agreed)
        or choiceB.songId~=terms.songId or choiceB.role~=terms.partnerRole
        or not duetRoleAllowed(choiceA,choiceB.role) or not duetRoleAllowed(choiceB,choiceA.role) then return nil end
    local own=id==terms.originatorId and a or b;local choice=id==terms.originatorId and choiceA or choiceB
    return {actorId=id,processId=process.id,revision=process.revision,commitmentId=own.id,
        partnerId=id==terms.originatorId and terms.partnerId or terms.originatorId,
        role=choice.role,songId=terms.songId,sourceId=terms.sourceId,choiceId=choice.id,
        choice=dataCopy(choice),acceptedAtHours=response.deliveredAt,expiresAtHours=terms.expiresAtHours}
end
function Org.duetOffers(id)
    local out={}
    for _,commitment in ipairs(Org.activeCommitments(id)) do
        if commitment.matter=="leisure-duet" and commitment.status~="completed" then
            local offer=Org.duetOffer(id,commitment.processId);if offer then out[#out+1]=offer end
        end
        if #out>=8 then break end
    end
    return out
end
local function duetWorkMatches(offer,work)
    local bind=work and work.sourceOffer and work.sourceOffer.duet
    return work and offer and bind and work.actorId==offer.actorId and work.sourceId==offer.sourceId
        and work.sourceOffer.id==offer.choiceId and work.sourceOffer.songId==offer.songId
        and bind.processId==offer.processId and bind.revision==offer.revision and bind.commitmentId==offer.commitmentId
        and bind.partnerId==offer.partnerId and bind.role==offer.role and bind.songId==offer.songId
        and work.admittedAtHours>=offer.acceptedAtHours and work.admittedAtHours<=nowHours()
end
function Org.admitDuet(id,processId,sequence)
    local offer=Org.duetOffer(id,processId);local M=SAO.LeisureMusic
    local work=M and M.work and M.work(id);local c=offer and Org.commitment(offer.commitmentId)
    if not c or c.status=="completed" or not duetWorkMatches(offer,work) or work.sequence~=sequence
        or work.status~="active" or not SAO.ProceduralPlanning.hobbyAdmission(id,work.purposeId,work.workId) then return false end
    local process=processOf(processId);local key=revisionKey(process.revision)
    process.privateInputs[id]=process.privateInputs[id] or {};local input=process.privateInputs[id][key] or {}
    process.privateInputs[id][key]=input
    if input.duetWork then return input.duetWork.workId==work.workId and input.duetWork.sequence==sequence end
    local stepId=id==process.originatorId and "perform-originator" or "perform-partner"
    if not Org.noteWorkAdmission(c.id,"SAO.LeisureMusic",work.workId,{stepId=stepId},DUET) then return false end
    input.duetWork={actorId=id,workId=work.workId,sequence=sequence,purposeId=work.purposeId,
        admittedAtHours=work.admittedAtHours,revision=process.revision,stepId=stepId,commitmentId=c.id}
    return true
end
function Org.duetReady(id,processId)
    local offer=Org.duetOffer(id,processId);local peer=offer and Org.duetOffer(offer.partnerId,processId)
    if not offer or not peer then return nil end
    local process=processOf(processId);local key=revisionKey(process.revision)
    for _,binding in ipairs({offer,peer}) do
        local input=process.privateInputs[binding.actorId] and process.privateInputs[binding.actorId][key]
        local own=input and input.duetWork;local work=SAO.LeisureMusic.work(binding.actorId)
        local admission=own and work and SAO.ProceduralPlanning.hobbyAdmission(binding.actorId,own.purposeId,own.workId)
        if not own or not work or own.sequence~=work.sequence or not duetWorkMatches(binding,work) or work.status~="active"
            or work.workId~=own.workId or not work.nativeProgress.started or not admission
            or admission.ownerName~="SAO.LeisureMusic" or admission.sequence~=work.sequence then return nil end
    end
    return offer
end
local DUET_MEASURES={"Boredom","Stress","Unhappiness","Endurance","Fatigue","Pain"}
local function duetMeasuredInterval(result)
    if type(result.before)~="table" or type(result.after)~="table" then return nil end
    local before,after,measured={},{},false
    for _,name in ipairs(DUET_MEASURES) do
        if finite(result.before[name]) and finite(result.after[name]) then
            before[name],after[name]=result.before[name],result.after[name]
            measured=true
        end
    end
    if not measured then return nil end
    return before,after
end
local function completedDuetPart(process,terms,id,partnerId,choice,stepId)
    local key=revisionKey(process.revision)
    local input=process.privateInputs[id] and process.privateInputs[id][key]
    local own=input and input.duetWork
    local stored=own and own.result
    local commitment=own and Org.commitment(own.commitmentId)
    local receipt=own and Org.workReceipts["procedure:"..own.workId]
    local result=own and SAO.LeisureMusic and SAO.LeisureMusic.outcome
        and SAO.LeisureMusic.outcome(id,own.sequence)
    local bind=result and result.sourceOffer and result.sourceOffer.duet
    local native=result and result.nativeProgress
    local release=native and native.duetRelease
    if not own or not stored or not result or not commitment or not receipt or not bind or not release
        or own.actorId~=id or own.revision~=process.revision or own.stepId~=stepId
        or commitment.processId~=process.id or commitment.actorId~=id
        or commitment.revision~=process.revision or commitment.status~="completed"
        or not commitment.stepIds or not commitment.stepIds[stepId]
        or receipt.receiptId~=own.workId or receipt.commitmentId~=own.commitmentId
        or receipt.owner~="SAO.LeisureMusic" or receipt.token~="duet:performed" or receipt.status~="completed"
        or stored.actorId~=id or stored.workId~=own.workId or stored.sequence~=own.sequence
        or stored.status~="completed" or stored.atHours~=result.atHours
        or result.actorId~=id or result.workId~=own.workId or result.sequence~=own.sequence
        or result.purposeId~=own.purposeId or result.status~="completed" or result.token~="leisure:performed"
        or result.sourceId~=terms.sourceId or not duetChoiceEqual(result.sourceOffer,choice)
        or bind.processId~=process.id or bind.revision~=process.revision
        or bind.commitmentId~=own.commitmentId or bind.partnerId~=partnerId
        or bind.role~=choice.role or bind.songId~=terms.songId
        or result.admittedAtHours~=own.admittedAtHours
        or not finite(result.atHours) or result.atHours<own.admittedAtHours
        or result.atHours>terms.expiresAtHours or result.atHours>nowHours()
        or result.afterCurrent~=true or result.cleanupSucceeded~=true
        or result.measurementAuthority~="actual-source-interval; concurrent-effects-not-isolated"
        or native.started~=true or not finite(native.observedUpdates) or native.observedUpdates<1
        or native.duetReleased~=true or native.soundObserved~=true or native.sound~=choice.sound
        or native.sourceSoundEnded~=true or native.sourcePerformReturned~=true
        or release.processId~=process.id or release.revision~=process.revision
        or release.partnerId~=partnerId or not finite(release.atHours)
        or release.atHours<own.admittedAtHours or release.atHours>result.atHours then return nil end
    local before,after=duetMeasuredInterval(result)
    if not before then return nil end
    return {input=input,work=own,result=result,release=release,choice=choice,before=before,after=after}
end
local function storedDuetParticipation(process,terms,id)
    local partnerId=id==terms.originatorId and terms.partnerId or terms.originatorId
    if id~=terms.originatorId and id~=terms.partnerId then return nil end
    local key=revisionKey(process.revision)
    local own=process.privateInputs[id] and process.privateInputs[id][key]
    local peer=process.privateInputs[partnerId] and process.privateInputs[partnerId][key]
    local row=own and own.duetParticipation
    local other=peer and peer.duetParticipation
    local ownResult=own and own.duetWork and own.duetWork.result
    local peerResult=peer and peer.duetWork and peer.duetWork.result
    if not row or not other or not ownResult or not peerResult
        or ownResult.status~="completed" or peerResult.status~="completed"
        or row.id~="duet:"..process.id..":"..process.revision..":"..id
        or row.actorId~=id or row.processId~=process.id or row.revision~=process.revision
        or row.partnerId~=partnerId or row.sourceId~=terms.sourceId or row.songId~=terms.songId
        or row.workId~=ownResult.workId or row.sequence~=ownResult.sequence
        or other.actorId~=partnerId or other.partnerId~=id or other.processId~=process.id
        or other.revision~=process.revision or other.workId~=peerResult.workId
        or type(row.coPerformance)~="table" or row.coPerformance.status~="completed"
        or row.coPerformance.ownResultId~=ownResult.workId
        or row.coPerformance.partnerResultId~=peerResult.workId then return nil end
    return row
end
local function freezeDuetParticipation(processId)
    local process=processOf(processId)
    local proposal=process and proposalAt(process)
    local terms=proposal and proposal.proposal and proposal.proposal.duet
    if not process or process.kind~="leisure-duet" or not terms
        or terms.originatorId~=process.originatorId or not identity(terms.partnerId)
        or terms.partnerId==terms.originatorId or terms.sourceId~="LifestyleHobbies" then return false end
    if storedDuetParticipation(process,terms,terms.originatorId)
        and storedDuetParticipation(process,terms,terms.partnerId) then return true end
    local response=responseAt(process,terms.partnerId)
    local originChoice=terms.originatorChoice
    local partnerChoice=response and response.terms and response.terms.duetChoice
    if not response or response.response~="accept" or response.delivered~=true
        or response.revision~=process.revision or not finite(response.deliveredAt)
        or response.deliveredAt>nowHours() or not originChoice or not partnerChoice
        or originChoice.actorId~=terms.originatorId or partnerChoice.actorId~=terms.partnerId
        or originChoice.songId~=terms.songId or partnerChoice.songId~=terms.songId
        or originChoice.role~=terms.originatorRole or partnerChoice.role~=terms.partnerRole then return false end
    local a=completedDuetPart(process,terms,terms.originatorId,terms.partnerId,originChoice,"perform-originator")
    local b=completedDuetPart(process,terms,terms.partnerId,terms.originatorId,partnerChoice,"perform-partner")
    if not a or not b or a.release.partnerWorkId~=b.work.workId
        or b.release.partnerWorkId~=a.work.workId or a.release.atHours~=b.release.atHours then return false end
    -- Both source parts were admitted before the shared native release.
    if a.work.admittedAtHours<response.deliveredAt or b.work.admittedAtHours<response.deliveredAt
        or a.work.admittedAtHours>b.release.atHours or b.work.admittedAtHours>a.release.atHours then return false end
    local function privateReceipt(part,other,id,partnerId)
        return {id="duet:"..process.id..":"..process.revision..":"..id,
            actorId=id,processId=process.id,revision=process.revision,partnerId=partnerId,
            sourceId=terms.sourceId,songId=terms.songId,role=part.choice.role,
            purposeId=part.work.purposeId,workId=part.work.workId,sequence=part.work.sequence,
            atHours=math.max(part.result.atHours,other.result.atHours),
            before=part.before,after=part.after,
            measurementAuthority=part.result.measurementAuthority,
            coPerformance={status="completed",basis="two-committed-native-source-duet-results",
                ownResultId=part.work.workId,partnerResultId=other.work.workId}}
    end
    if a.input.duetParticipation or b.input.duetParticipation then return false end
    a.input.duetParticipation=privateReceipt(a,b,terms.originatorId,terms.partnerId)
    b.input.duetParticipation=privateReceipt(b,a,terms.partnerId,terms.originatorId)
    return true
end
function Org.duetParticipationFor(id,processId)
    local process=processOf(processId)
    local proposal=process and proposalAt(process)
    local terms=proposal and proposal.proposal and proposal.proposal.duet
    if not process or process.kind~="leisure-duet" or not terms then return nil end
    return dataCopy(storedDuetParticipation(process,terms,id))
end
local function deliverDuetParticipation(processId)
    local process=processOf(processId)
    local proposal=process and proposalAt(process)
    local terms=proposal and proposal.proposal and proposal.proposal.duet
    local cognition=SAO.Cognition and SAO.Cognition.duetOutcome
    if not terms or not cognition then return end
    for _,id in ipairs({terms.originatorId,terms.partnerId}) do
        if Org.duetParticipationFor(id,processId) then pcall(cognition,id,processId) end
    end
end
function Org.consumeDuet(id,processId,sequence)
    local process=processOf(processId);local key=process and revisionKey(process.revision)
    local input=process and process.privateInputs[id] and process.privateInputs[id][key]
    local own=input and input.duetWork;local result=own and SAO.LeisureMusic.outcome(id,sequence)
    if not process or process.kind~="leisure-duet" or not own or own.sequence~=sequence or not result
        or result.actorId~=id or result.workId~=own.workId or result.purposeId~=own.purposeId
        or not result.sourceOffer.duet or result.sourceOffer.duet.processId~=processId
        or result.sourceOffer.duet.revision~=own.revision or result.atHours<own.admittedAtHours
        or result.atHours>nowHours() then return false end
    if own.result then
        local duplicate=own.result.workId==result.workId and own.result.sequence==sequence
            and own.result.status==result.status and own.result.atHours==result.atHours
        if duplicate and freezeDuetParticipation(processId) then deliverDuetParticipation(processId) end
        return duplicate
    end
    local terms=proposalAt(process).proposal.duet
    if result.status=="completed" and (not result.nativeProgress.duetReleased
        or not result.nativeProgress.soundObserved or result.atHours>terms.expiresAtHours) then return false end
    if not Org.consumeProcedureResult({commitmentId=own.commitmentId,actorId=id,id=own.workId,
        token="duet:performed",stepId=own.stepId,owner="SAO.LeisureMusic",status=result.status,at=result.atHours},DUET) then return false end
    own.result={actorId=id,workId=own.workId,sequence=sequence,status=result.status,atHours=result.atHours}
    if freezeDuetParticipation(processId) then deliverDuetParticipation(processId) end
    return true
end

-- Personally heard-source dance consent has its own typed authority.
local DANCE_CHOICE_FIELDS={"id","actorId","sourceId","revision","danceEffectsRevision","activity",
    "itemKey","musicKey","role","bodyToken"}
local function danceChoiceEqual(a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    for _,field in ipairs(DANCE_CHOICE_FIELDS) do if a[field]~=b[field] then return false end end
    for field,value in pairs(a.heardMusic or {})do if not b.heardMusic or b.heardMusic[field]~=value then return false end end
    for field,value in pairs(b.heardMusic or {})do if not a.heardMusic or a.heardMusic[field]~=value then return false end end
    return a.heardMusic~=nil and b.heardMusic~=nil
end
local function danceSameMusic(a,b)
    if type(a)~="table"or type(b)~="table"then return false end
    for field,value in pairs(a)do if b[field]~=value then return false end end
    for field,value in pairs(b)do if a[field]~=value then return false end end
    return true
end
local function danceChoiceFor(id,choiceId)
    local M=SAO.LeisureMusic;local body=SAO.Body and SAO.Body.get(id)
    return body and M and M.danceChoice and M.danceChoice(id,body,choiceId)
end
local function danceRoleAllowed(choice,role)
    for _,value in ipairs(choice and choice.partnerRoles or {}) do if value==role then return true end end
    return false
end
local function danceTerms(processId)
    local process=processOf(processId);local revision=process and proposalAt(process)
    local proposal=revision and revision.proposal;local terms=proposal and proposal.dance
    if not process or process.kind~="leisure-dance" or TERMINAL_PROCESS[process.status]
        or not terms or proposal.cooperative~=true or terms.sourceId~="LifestyleHobbies"
        or terms.originatorId~=process.originatorId or not identity(terms.partnerId)
        or terms.partnerId==terms.originatorId or not identity(terms.musicKey)
        or not finite(terms.expiresAtHours) or terms.expiresAtHours<nowHours() then return nil end
    return process,terms
end
function Org.proposeDance(id,partnerId,choiceId,partnerRole,expiresAtHours)
    id,partnerId=identity(id),identity(partnerId)
    local choice=id and danceChoiceFor(id,choiceId)
    if not choice or not partnerId or partnerId==id or not danceRoleAllowed(choice,partnerRole)
        or not finite(expiresAtHours) or expiresAtHours<=nowHours() or expiresAtHours>nowHours()+24 then return nil,"invalid-source-dance-invitation" end
    local terms={sourceId=choice.sourceId,musicKey=choice.musicKey,originatorId=id,partnerId=partnerId,
        originatorRole=choice.role,partnerRole=partnerRole,originatorChoice=dataCopy(choice),heardMusic=dataCopy(choice.heardMusic),expiresAtHours=expiresAtHours}
    local process,why=Org.raiseMatter(id,"leisure-dance",nil,{cooperative=true,
        objective="perform-source-dance",responsePolicy="procedure-completion",dance=terms,
        procedure={{id="perform-originator",verb="perform-dance",capability="perform-dance",owner="SAO.LeisureMusic",
            role=choice.role,assignedTo=id,completesOn={"dance:performed"}},
            {id="perform-partner",verb="perform-dance",capability="perform-dance",owner="SAO.LeisureMusic",
            role=partnerRole,assignedTo=partnerId,completesOn={"dance:performed"}}}}, {partnerId},
        {basis="personally-supported-source-part",choice=dataCopy(choice)},DANCE)
    if not process then return nil,why end
    local commitment=Org.commitOriginator(process.id,id,{capabilities={["perform-dance"]=true},
        stepIds={"perform-originator"},evidence={sourceChoiceId=choice.id,musicKey=choice.musicKey,role=choice.role}},DANCE)
    if not commitment then Org.withdrawMatter(process.id,id,"originator-part-not-claimed");return nil,"originator-part-not-claimed" end
    return {processId=process.id,revision=process.revision,choiceId=choice.id,partnerId=partnerId,
        role=choice.role,partnerRole=partnerRole,musicKey=choice.musicKey,expiresAtHours=expiresAtHours}
end
function Org.respondDance(id,processId,choiceId,response,context)
    local process,terms=danceTerms(processId)
    if not process or id~=terms.partnerId then return nil,"not-invited-dance-performer" end
    local acquired=Org.viewFor(id,processId,false)
    if not acquired or not acquired.proposal or acquired.currentRevision~=process.revision then return nil,"dance-proposal-not-acquired" end
    context=dataCopy(context or {}) or {};context.choice=response
    if response=="accept" then
        local choice=danceChoiceFor(id,choiceId);local author=danceChoiceFor(terms.originatorId,terms.originatorChoice.id)
        if not choice or not danceChoiceEqual(author,terms.originatorChoice) or choice.sourceId~=terms.sourceId
            or choice.musicKey~=terms.musicKey or choice.role~=terms.partnerRole
            or not danceSameMusic(choice.heardMusic,terms.heardMusic)
            or not danceRoleAllowed(choice,terms.originatorRole) then return nil,"source-dance-part-incompatible" end
        context.capabilities={["perform-dance"]=true};context.stepIds={"perform-partner"}
        context.terms={stepIds={"perform-partner"},danceChoice=dataCopy(choice)}
    end
    return Org.appraiseMatter(processId,id,context,DANCE)
end
local function danceCommitted(process,id,stepId)
    local procedure=procedureAt(process);local step=procedure and procedure.steps[stepId]
    for _,commitment in pairs(process.commitments or {}) do
        local claim=step and step.claims and step.claims[id]
        if commitment.actorId==id and commitment.revision==process.revision
            and (commitment.status=="accepted" or commitment.status=="in-progress" or commitment.status=="completed")
            and commitment.stepIds and commitment.stepIds[stepId] and claim and claim.commitmentId==commitment.id
            and (claim.status=="claimed" or claim.status=="attempting" or claim.status=="completed")
            and step.owner=="SAO.LeisureMusic" and step.assignedTo==id then return commitment end
    end
end
function Org.danceOffer(id,processId)
    local process,terms=danceTerms(processId)
    if not process or (id~=terms.originatorId and id~=terms.partnerId) then return nil end
    local view=Org.viewFor(id,processId,true)
    if not view or not view.proposal or view.currentRevision~=process.revision then return nil end
    local response=responseAt(process,terms.partnerId)
    if not response or response.response~="accept" or response.delivered~=true
        or response.revision~=process.revision or not finite(response.deliveredAt)
        or response.deliveredAt>nowHours() then return nil end
    local a=danceCommitted(process,terms.originatorId,"perform-originator")
    local b=danceCommitted(process,terms.partnerId,"perform-partner")
    local choiceA=danceChoiceFor(terms.originatorId,terms.originatorChoice.id)
    local agreed=response.terms and response.terms.danceChoice
    local choiceB=agreed and danceChoiceFor(terms.partnerId,agreed.id)
    if not a or not b or not danceChoiceEqual(choiceA,terms.originatorChoice) or not danceChoiceEqual(choiceB,agreed)
        or choiceB.musicKey~=terms.musicKey or choiceB.role~=terms.partnerRole
        or not danceSameMusic(choiceA.heardMusic,choiceB.heardMusic)
        or not danceRoleAllowed(choiceA,choiceB.role) or not danceRoleAllowed(choiceB,choiceA.role) then return nil end
    local own=id==terms.originatorId and a or b;local choice=id==terms.originatorId and choiceA or choiceB
    return {actorId=id,processId=process.id,revision=process.revision,commitmentId=own.id,
        partnerId=id==terms.originatorId and terms.partnerId or terms.originatorId,
        role=choice.role,musicKey=terms.musicKey,sourceId=terms.sourceId,choiceId=choice.id,
        choice=dataCopy(choice),acceptedAtHours=response.deliveredAt,expiresAtHours=terms.expiresAtHours}
end
function Org.danceOffers(id)
    local out={}
    for _,commitment in ipairs(Org.activeCommitments(id)) do
        if commitment.matter=="leisure-dance" and commitment.status~="completed" then
            local offer=Org.danceOffer(id,commitment.processId);if offer then out[#out+1]=offer end
        end
        if #out>=8 then break end
    end
    return out
end
local function danceWorkMatches(offer,work)
    local bind=work and work.sourceOffer and work.sourceOffer.dance
    return work and offer and bind and work.actorId==offer.actorId and work.sourceId==offer.sourceId
        and work.sourceOffer.id==offer.choiceId and work.sourceOffer.musicKey==offer.musicKey
        and bind.processId==offer.processId and bind.revision==offer.revision and bind.commitmentId==offer.commitmentId
        and bind.partnerId==offer.partnerId and bind.role==offer.role and bind.musicKey==offer.musicKey
        and work.admittedAtHours>=offer.acceptedAtHours and work.admittedAtHours<=nowHours()
end
function Org.admitDance(id,processId,sequence)
    local offer=Org.danceOffer(id,processId);local M=SAO.LeisureMusic
    local work=M and M.work and M.work(id);local c=offer and Org.commitment(offer.commitmentId)
    if not c or c.status=="completed" or not danceWorkMatches(offer,work) or work.sequence~=sequence
        or work.status~="active" or not SAO.ProceduralPlanning.hobbyAdmission(id,work.purposeId,work.workId) then return false end
    local process=processOf(processId);local key=revisionKey(process.revision)
    process.privateInputs[id]=process.privateInputs[id] or {};local input=process.privateInputs[id][key] or {}
    process.privateInputs[id][key]=input
    if input.danceWork then return input.danceWork.workId==work.workId and input.danceWork.sequence==sequence end
    local stepId=id==process.originatorId and "perform-originator" or "perform-partner"
    if not Org.noteWorkAdmission(c.id,"SAO.LeisureMusic",work.workId,{stepId=stepId},DANCE) then return false end
    input.danceWork={actorId=id,workId=work.workId,sequence=sequence,purposeId=work.purposeId,
        admittedAtHours=work.admittedAtHours,revision=process.revision,stepId=stepId,commitmentId=c.id}
    return true
end
function Org.danceReady(id,processId)
    local offer=Org.danceOffer(id,processId);local peer=offer and Org.danceOffer(offer.partnerId,processId)
    if not offer or not peer then return nil end
    local process=processOf(processId);local key=revisionKey(process.revision)
    for _,binding in ipairs({offer,peer}) do
        local input=process.privateInputs[binding.actorId] and process.privateInputs[binding.actorId][key]
        local own=input and input.danceWork;local work=SAO.LeisureMusic.work(binding.actorId)
        local admission=own and work and SAO.ProceduralPlanning.hobbyAdmission(binding.actorId,own.purposeId,own.workId)
        if not own or not work or own.sequence~=work.sequence or not danceWorkMatches(binding,work) or work.status~="active"
            or work.workId~=own.workId or not work.nativeProgress.started or not admission
            or admission.ownerName~="SAO.LeisureMusic" or admission.sequence~=work.sequence then return nil end
    end
    return offer
end
local DANCE_MEASURES={"Boredom","Stress","Unhappiness","Endurance","Fatigue","Pain"}
local function danceMeasuredInterval(result)
    if type(result.before)~="table" or type(result.after)~="table" then return nil end
    local before,after,measured={},{},false
    for _,name in ipairs(DANCE_MEASURES) do
        if finite(result.before[name]) and finite(result.after[name]) then
            before[name],after[name]=result.before[name],result.after[name]
            measured=true
        end
    end
    if not measured then return nil end
    return before,after
end
local function completedDancePart(process,terms,id,partnerId,choice,stepId)
    local key=revisionKey(process.revision)
    local input=process.privateInputs[id] and process.privateInputs[id][key]
    local own=input and input.danceWork
    local stored=own and own.result
    local commitment=own and Org.commitment(own.commitmentId)
    local receipt=own and Org.workReceipts["procedure:"..own.workId]
    local result=own and SAO.LeisureMusic and SAO.LeisureMusic.outcome
        and SAO.LeisureMusic.outcome(id,own.sequence)
    local bind=result and result.sourceOffer and result.sourceOffer.dance
    local native=result and result.nativeProgress
    local setup=native and native.sourcePartnerSetup
    local cycle=native and native.sourcePartnerCycle
    local cleanup=native and native.sourcePartnerCleanup
    if not own or not stored or not result or not commitment or not receipt or not bind
        or not setup or not cycle or not cleanup
        or own.actorId~=id or own.revision~=process.revision or own.stepId~=stepId
        or commitment.processId~=process.id or commitment.actorId~=id
        or commitment.revision~=process.revision or commitment.status~="completed"
        or not commitment.stepIds or not commitment.stepIds[stepId]
        or receipt.receiptId~=own.workId or receipt.commitmentId~=own.commitmentId
        or receipt.owner~="SAO.LeisureMusic" or receipt.token~="dance:performed" or receipt.status~="completed"
        or stored.actorId~=id or stored.workId~=own.workId or stored.sequence~=own.sequence
        or stored.status~="completed" or stored.atHours~=result.atHours
        or result.actorId~=id or result.workId~=own.workId or result.sequence~=own.sequence
        or result.purposeId~=own.purposeId or result.status~="completed" or result.token~="leisure:performed"
        or result.sourceId~=terms.sourceId or not danceChoiceEqual(result.sourceOffer,choice)
        or result.bodyToken~=choice.bodyToken or bind.processId~=process.id
        or bind.revision~=process.revision or bind.commitmentId~=own.commitmentId
        or bind.partnerId~=partnerId or bind.role~=choice.role or bind.musicKey~=terms.musicKey
        or result.admittedAtHours~=own.admittedAtHours
        or not finite(result.atHours) or result.atHours<own.admittedAtHours
        or result.atHours>terms.expiresAtHours or result.atHours>nowHours()
        or result.afterCurrent~=true or result.cleanupSucceeded~=true
        or result.measurementAuthority~="actual-source-interval; concurrent-effects-not-isolated"
        or native.started~=true or not finite(native.observedUpdates) or native.observedUpdates<1
        or native.danceReleased~=true or native.sourcePerformReturned~=true
        or setup.sourceId~="LifestyleHobbies" or setup.processId~=process.id
        or setup.role~=choice.role or setup.partnerId~=partnerId
        or setup.revision~=choice.danceEffectsRevision
        or setup.choiceProducerRevision~=choice.choiceProducerRevision
        or not finite(setup.atHours) or setup.atHours<own.admittedAtHours
        or setup.atHours>result.atHours or type(setup.before)~="table"
        or cycle.actorId~=id or cycle.bodyToken~=result.bodyToken
        or cycle.workId~=own.workId or cycle.clip~=choice.roleAnimation
        or cycle.authority~="native-current-owned-source-animation-loop"
        or not finite(cycle.sequence) or cycle.sequence<1 or cycle.sequence%1~=0
        or not finite(cycle.engineAtHours) or not finite(cycle.observedAtCountyHours)
        or cycle.observedAtCountyHours<setup.atHours or cycle.observedAtCountyHours>result.atHours
        or cleanup.succeeded~=true or cleanup.nativeListenerRetirement~="confirmed" then return nil end
    local before,after=danceMeasuredInterval(result)
    if not before then return nil end
    return {input=input,work=own,result=result,setup=setup,choice=choice,before=before,after=after}
end
local function storedDanceParticipation(process,terms,id)
    local partnerId=id==terms.originatorId and terms.partnerId or terms.originatorId
    if id~=terms.originatorId and id~=terms.partnerId then return nil end
    local key=revisionKey(process.revision)
    local own=process.privateInputs[id] and process.privateInputs[id][key]
    local peer=process.privateInputs[partnerId] and process.privateInputs[partnerId][key]
    local row=own and own.danceParticipation
    local other=peer and peer.danceParticipation
    local ownResult=own and own.danceWork and own.danceWork.result
    local peerResult=peer and peer.danceWork and peer.danceWork.result
    if not row or not other or not ownResult or not peerResult
        or ownResult.status~="completed" or peerResult.status~="completed"
        or row.id~="dance:"..process.id..":"..process.revision..":"..id
        or row.actorId~=id or row.processId~=process.id or row.revision~=process.revision
        or row.partnerId~=partnerId or row.sourceId~=terms.sourceId or row.musicKey~=terms.musicKey
        or row.workId~=ownResult.workId or row.sequence~=ownResult.sequence
        or row.purposeId~=own.danceWork.purposeId
        or row.role~=(id==terms.originatorId and terms.originatorRole or terms.partnerRole)
        or row.atHours~=math.max(ownResult.atHours,peerResult.atHours)
        or row.measurementAuthority~="actual-source-interval; concurrent-effects-not-isolated"
        or other.actorId~=partnerId or other.partnerId~=id or other.processId~=process.id
        or other.revision~=process.revision or other.workId~=peerResult.workId
        or type(row.coPerformance)~="table" or row.coPerformance.status~="completed"
        or row.coPerformance.basis~="two-committed-native-source-dance-results"
        or row.coPerformance.ownResultId~=ownResult.workId
        or row.coPerformance.partnerResultId~=peerResult.workId then return nil end
    return row
end
local function sameDancePairStart(left,right)
    if type(left)~="table" or type(right)~="table" then return false end
    for _,role in ipairs({"source","target"}) do
        local a,b=left[role],right[role]
        if type(a)~="table" or type(b)~="table"
            or not finite(a.x) or not finite(a.y) or not finite(a.z)
            or a.x~=b.x or a.y~=b.y or a.z~=b.z then return false end
    end
    return true
end
local function freezeDanceParticipation(processId)
    local process=processOf(processId)
    local proposal=process and proposalAt(process)
    local terms=proposal and proposal.proposal and proposal.proposal.dance
    if not process or process.kind~="leisure-dance" or not terms
        or terms.originatorId~=process.originatorId or not identity(terms.partnerId)
        or terms.partnerId==terms.originatorId or terms.sourceId~="LifestyleHobbies" then return false end
    if storedDanceParticipation(process,terms,terms.originatorId)
        and storedDanceParticipation(process,terms,terms.partnerId) then return true end
    local response=responseAt(process,terms.partnerId)
    local originChoice=terms.originatorChoice
    local partnerChoice=response and response.terms and response.terms.danceChoice
    if not response or response.response~="accept" or response.delivered~=true
        or response.revision~=process.revision or not finite(response.deliveredAt)
        or response.deliveredAt>nowHours() or not originChoice or not partnerChoice
        or originChoice.actorId~=terms.originatorId or partnerChoice.actorId~=terms.partnerId
        or originChoice.musicKey~=terms.musicKey or partnerChoice.musicKey~=terms.musicKey
        or originChoice.role~=terms.originatorRole or partnerChoice.role~=terms.partnerRole
        or not danceSameMusic(originChoice.heardMusic,partnerChoice.heardMusic) then return false end
    local a=completedDancePart(process,terms,terms.originatorId,terms.partnerId,originChoice,"perform-originator")
    local b=completedDancePart(process,terms,terms.partnerId,terms.originatorId,partnerChoice,"perform-partner")
    if not a or not b or not sameDancePairStart(a.setup.before,b.setup.before) then return false end
    if a.work.admittedAtHours<response.deliveredAt or b.work.admittedAtHours<response.deliveredAt
        or a.work.admittedAtHours>b.setup.atHours or b.work.admittedAtHours>a.setup.atHours then return false end
    local function privateReceipt(part,other,id,partnerId)
        return {id="dance:"..process.id..":"..process.revision..":"..id,
            actorId=id,processId=process.id,revision=process.revision,partnerId=partnerId,
            sourceId=terms.sourceId,musicKey=terms.musicKey,role=part.choice.role,
            purposeId=part.work.purposeId,workId=part.work.workId,sequence=part.work.sequence,
            atHours=math.max(part.result.atHours,other.result.atHours),
            before=part.before,after=part.after,
            measurementAuthority=part.result.measurementAuthority,
            coPerformance={status="completed",basis="two-committed-native-source-dance-results",
                ownResultId=part.work.workId,partnerResultId=other.work.workId}}
    end
    if a.input.danceParticipation or b.input.danceParticipation then return false end
    a.input.danceParticipation=privateReceipt(a,b,terms.originatorId,terms.partnerId)
    b.input.danceParticipation=privateReceipt(b,a,terms.partnerId,terms.originatorId)
    return true
end
function Org.danceParticipationFor(id,processId)
    local process=processOf(processId)
    local proposal=process and proposalAt(process)
    local terms=proposal and proposal.proposal and proposal.proposal.dance
    if not process or process.kind~="leisure-dance" or not terms then return nil end
    return dataCopy(storedDanceParticipation(process,terms,id))
end
local function deliverDanceParticipation(processId)
    local process=processOf(processId)
    local proposal=process and proposalAt(process)
    local terms=proposal and proposal.proposal and proposal.proposal.dance
    local cognition=SAO.Cognition and SAO.Cognition.danceOutcome
    if not terms or not cognition then return end
    for _,id in ipairs({terms.originatorId,terms.partnerId}) do
        if Org.danceParticipationFor(id,processId) then pcall(cognition,id,processId) end
    end
end
function Org.consumeDance(id,processId,sequence)
    local process=processOf(processId);local key=process and revisionKey(process.revision)
    local input=process and process.privateInputs[id] and process.privateInputs[id][key]
    local own=input and input.danceWork;local result=own and SAO.LeisureMusic.outcome(id,sequence)
    if own and own.result and own.sequence==sequence and not result then
        local proposal=proposalAt(process)
        local terms=proposal and proposal.proposal and proposal.proposal.dance
        if terms and storedDanceParticipation(process,terms,id) then
            deliverDanceParticipation(processId);return true
        end
        return false
    end
    if not process or process.kind~="leisure-dance" or not own or own.sequence~=sequence or not result
        or result.actorId~=id or result.workId~=own.workId or result.purposeId~=own.purposeId
        or not result.sourceOffer or not result.sourceOffer.dance or result.sourceOffer.dance.processId~=processId
        or result.sourceOffer.dance.revision~=own.revision or result.atHours<own.admittedAtHours
        or result.atHours>nowHours() then return false end
    if own.result then
        local duplicate=own.result.workId==result.workId and own.result.sequence==sequence
            and own.result.status==result.status and own.result.atHours==result.atHours
        if duplicate and freezeDanceParticipation(processId) then deliverDanceParticipation(processId) end
        return duplicate
    end
    local terms=proposalAt(process).proposal.dance
    if result.status=="completed" and (not result.nativeProgress.danceReleased
        or not result.nativeProgress.sourcePartnerCycle or result.atHours>terms.expiresAtHours) then return false end
    if not Org.consumeProcedureResult({commitmentId=own.commitmentId,actorId=id,id=own.workId,
        token="dance:performed",stepId=own.stepId,owner="SAO.LeisureMusic",status=result.status,at=result.atHours},DANCE) then return false end
    own.result={actorId=id,workId=own.workId,sequence=sequence,status=result.status,atHours=result.atHours}
    if freezeDanceParticipation(processId) then deliverDanceParticipation(processId) end
    return true
end

return Org
