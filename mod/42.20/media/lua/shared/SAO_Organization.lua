-- SAO_Organization.lua - durable organizations and enacted shared work.
--
-- A roster, an office, or a delivered message is not assent. This owner
-- records the proposal a person made, who actually acquired it, each person's
-- revision-bound response, the commitments created by delivered acceptance,
-- and the native work receipts that later fulfilled or interrupted it.

SAO = SAO or {}
SAO.Organization = SAO.Organization or {}
local Org = SAO.Organization

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
                         addressedIds, privateEvidence)
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
function Org.appraiseMatter(processId, personId, context)
    local process = processOf(processId)
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
    })
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

function Org.respond(processId, personId, response, terms, privateEvidence)
    local process = processOf(processId)
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
function Org.commitOriginator(processId, personId, context)
    local process = processOf(processId)
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

function Org.noteWorkAdmission(commitmentId, ownerKind, receiptId, detail)
    local commitment, process = Org.commitment(commitmentId)
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

-- Registered native action owners use this boundary for procedure verbs that
-- are not SourceUse or Handover. Admission and result identity are exact; a
-- narration, state label or elapsed timer cannot complete a step.
function Org.consumeProcedureResult(result)
    if type(result) ~= "table" then return false, "invalid-result" end
    local commitment, process = Org.commitment(result.commitmentId)
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
    local commitment = Org.commitment(commitmentId)
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

return Org
