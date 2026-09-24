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

local function hasLiveCommitment(process)
    for _, commitment in pairs(process and process.commitments or {}) do
        if not TERMINAL_WORK[commitment.status] then return true end
    end
    return false
end

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
            process.status = "expired"
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

local function responseAt(process, personId, revision)
    local row = process.participants
        and process.participants[tostring(personId or "")] or nil
    return row and row.responses
        and row.responses[revisionKey(revision or process.revision)] or nil
end

local activeCommitmentFor
local endCommitment

local function refreshProcessStatus(process)
    if not process or TERMINAL_PROCESS[process.status] then return end
    local revision = proposalAt(process)
    local proposal = revision and revision.proposal or {}
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
        process.status = "closed"
        process.closedAt = nowHours()
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
    local id, at = nextProcessId(originatorId), nowHours()
    local process = { id = id, kind = kind,
        organizationId = identity(organizationId),
        originatorId = originatorId, createdAt = at, revisedAt = at,
        revision = 1, status = "open", revisions = {}, participants = {},
        commitments = {}, commitmentSequence = 0, privateInputs = {},
        events = {} }
    process.revisions["1"] = { revision = 1, proposedAt = at,
        proposedBy = originatorId, proposal = dataCopy(proposal) or {} }
    process.privateInputs[originatorId] = {
        ["1"] = dataCopy(privateEvidence or {}) or {} }
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

function Org.reviseMatter(processId, originatorId, proposal, privateEvidence)
    local process = processOf(processId)
    if not process or process.originatorId ~= originatorId
        or type(proposal) ~= "table" or process.status ~= "open" then
        return nil
    end
    local priorRevision = process.revision
    process.revision = priorRevision + 1
    process.revisedAt = nowHours()
    process.revisions[revisionKey(process.revision)] = {
        revision = process.revision, proposedAt = process.revisedAt,
        proposedBy = originatorId, proposal = dataCopy(proposal) or {} }
    process.privateInputs[originatorId] = process.privateInputs[originatorId] or {}
    process.privateInputs[originatorId][revisionKey(process.revision)] =
        dataCopy(privateEvidence or {}) or {}
    for _, commitment in pairs(process.commitments or {}) do
        endCommitment(process, commitment, "superseded",
            "proposal-revised", process.revisedAt)
    end
    event(process, "proposal-revised", originatorId,
        { priorRevision = priorRevision }, process.revisedAt)
    return process
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
    process.status = "closed"
    process.closedAt = nowHours()
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
    if not process or TERMINAL_PROCESS[process.status]
        or not personId or revision < 1
        or not proposalAt(process, revision) then return false end
    local row = participant(process, personId, true)
    local key = revisionKey(revision)
    if row.receptions[key] then return true end
    row.receptions[key] = { at = nowHours(),
        channel = tostring(channel or "communication"),
        fromId = identity(fromId), evidence = dataCopy(evidence or {}) }
    event(process, "proposal-received", personId,
        { channel = channel, fromId = fromId }, row.receptions[key].at)
    return true
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
    local available = {
        acquire = context.canAcquire,
        carry = context.canCarry,
        deliver = context.canDeliver,
        execute = context.canExecute,
    }
    local capable = context.dead ~= true and context.incapable ~= true
    for capability, needed in pairs(required) do
        if needed == true and available[capability] ~= true then
            capable = false
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
    local capabilities = { acquire = context.canAcquire ~= false,
        carry = context.canCarry ~= false,
        deliver = context.canDeliver ~= false,
        execute = context.canExecute ~= false }
    local constraints = dataCopy(context.constraints or {}) or {}
    if type(constraints.represented) ~= "boolean" then
        constraints.represented = context.represented == true
    end
    constraints.currentActivity = activity
    if type(constraints.executionOwnerAvailable) ~= "boolean" then
        constraints.executionOwnerAvailable = context.executionOwnerAvailable ~= false
    end
    constraints.dead = context.dead == true
    constraints.incapable = context.incapable == true
    constraints.contest = context.contest == true
    if constraints.executionOwnerAvailable ~= true then
        capabilities = { acquire = false, carry = false,
            deliver = false, execute = false }
    end
    local suppliedOwners = type(context.inputOwners) == "table"
        and context.inputOwners or {}
    local function inputOwner(name, fallback)
        return identity(suppliedOwners[name]) or fallback
    end
    local inputOwners = {
        currentActivity = inputOwner("currentActivity", executor),
        capabilities = inputOwner("capabilities", executor),
        ownNeed = inputOwner("ownNeed", owner),
        relationship = inputOwner("relationship", "SAO.Standing"),
        interests = inputOwner("interests", owner),
        constraints = inputOwner("constraints", owner),
    }
    return Org.respond(processId, personId, selected, terms, {
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

function Org.workPlan(commitmentId)
    local commitment, process = Org.commitment(commitmentId)
    if not commitment or not process then return nil end
    local proposal = proposalAt(process, commitment.revision)
    return {
        processId = process.id,
        processRevision = commitment.revision,
        commitmentId = commitment.id,
        actorId = commitment.actorId,
        requesterId = process.originatorId,
        organizationId = process.organizationId,
        kind = process.kind,
        proposal = dataCopy(proposal and proposal.proposal or {}),
        phase = commitment.work and commitment.work.phase,
        status = commitment.status,
    }
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
    local commitment = Org.commitment(commitmentId)
    receiptId = identity(receiptId)
    if not commitment or TERMINAL_WORK[commitment.status] or not receiptId
        or (commitment.work.pendingReceiptId
            and commitment.work.pendingReceiptId ~= receiptId) then return false end
    commitment.status = "in-progress"
    commitment.work.nativeOwner = tostring(ownerKind or "native")
    commitment.work.pendingReceiptId = receiptId
    workEvent(commitment, "admitted", { owner = ownerKind,
        receiptId = receiptId, detail = detail })
    return true
end

function Org.noteRoute(commitmentId, owner, x, y, z, phase)
    local commitment = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status] then return false end
    phase = phase == "acquiring" and "acquiring" or "carrying"
    local attempt = { owner = tostring(owner or "Locomotion"), phase = phase,
        x = tonumber(x), y = tonumber(y), z = tonumber(z),
        startedAt = nowHours(), status = "pending" }
    appendBounded(commitment.work.routeAttempts, attempt, 64)
    workEvent(commitment, phase, { route = attempt })
    return true
end

function Org.routeOutcome(commitmentId, status, detail)
    local commitment = Org.commitment(commitmentId)
    if not commitment or TERMINAL_WORK[commitment.status] then return false end
    local routes = commitment.work.routeAttempts or {}
    local route = routes[#routes]
    if route and route.status == "pending" then
        route.status = tostring(status or "interrupted")
        route.endedAt = nowHours()
        route.detail = tostring(detail or status or "")
    end
    if status == "arrived" then
        workEvent(commitment, route and route.phase == "acquiring"
            and "acquiring" or "delivery-ready", { detail = detail })
    else
        commitment.status = commitment.work.acquiredAt
            and "interrupted" or "failed"
        workEvent(commitment, commitment.status, { detail = detail })
        commitment.work.endedAt = nowHours()
    end
    return true
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
    elseif receipt.status == "completed" and receipt.operation == "store" then
        commitment.status = "completed"
        commitment.work.deliveryReceiptId = receiptId
        commitment.work.completedAt = receipt.at or nowHours()
        commitment.work.endedAt = commitment.work.completedAt
        workEvent(commitment, "completed", { receiptId = receiptId })
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
