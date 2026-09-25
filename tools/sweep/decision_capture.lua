-- Immutable decision-time evidence for tools/county_dump.py.
--
-- This instrument observes Standing elections, loaded SourceUse decisions and
-- enacted Organization appraisals.
-- Person, situation and offered options are encoded before the real choice;
-- selection and the observed result stay separate. Runtime choices remain
-- unratified, and an absent source executor is explicit coverage information.

SAODecisionCapture = SAODecisionCapture or {}
local Capture = SAODecisionCapture

local MAX_DEPTH = 24
local pendingFailure = nil

-- Kahlua's pcall value for a Java-backed Lua error is not safely printable in
-- the headless runner. Keep the owned diagnostic before raising so a caught
-- failure retains the exact reader or serialization boundary.
local function raise(message)
    pendingFailure = message
    error(message)
end

local function escape(value)
    local text = tostring(value)
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, '"', '\\"')
    text = string.gsub(text, "[%z\1-\31]", function(character)
        return string.format("\\u%04x", string.byte(character))
    end)
    return text
end

local function encode(value)
    local active = {}

    local function walk(item, depth)
        if item == nil then return "null" end
        local kind = type(item)
        if kind == "boolean" then return item and "true" or "false" end
        if kind == "number" then
            if item ~= item or item == math.huge or item == -math.huge then
                raise("decision capture cannot encode a non-finite number")
            end
            if item == math.floor(item) and math.abs(item) < 1e15 then
                return string.format("%.0f", item)
            end
            return tostring(item)
        end
        if kind == "string" then return '"' .. escape(item) .. '"' end
        if kind ~= "table" then
            raise("decision capture cannot encode " .. kind)
        end
        if depth > MAX_DEPTH then
            raise("decision capture exceeded maximum nesting depth")
        end
        if active[item] then raise("decision capture found a table cycle") end
        active[item] = true

        local count, greatest, array = 0, 0, true
        for key in pairs(item) do
            count = count + 1
            if type(key) == "number" and key >= 1
                    and key == math.floor(key) then
                greatest = math.max(greatest, key)
            else
                array = false
            end
        end

        local rendered
        if array and count > 0 and greatest == count then
            local values = {}
            for index = 1, count do
                values[index] = walk(item[index], depth + 1)
            end
            rendered = "[" .. table.concat(values, ",") .. "]"
        else
            local fields, names = {}, {}
            for key, child in pairs(item) do
                local keyKind = type(key)
                if keyKind ~= "string" and keyKind ~= "number" then
                    raise("decision capture map key is " .. keyKind)
                end
                if keyKind == "number"
                        and (key ~= key or key == math.huge or key == -math.huge) then
                    raise("decision capture map key is non-finite")
                end
                local name = tostring(key)
                if names[name] then
                    raise("decision capture map has duplicate JSON key " .. name)
                end
                names[name] = true
                fields[#fields + 1] = {
                    name = name,
                    value = walk(child, depth + 1),
                }
            end
            table.sort(fields, function(left, right)
                return left.name < right.name
            end)
            local values = {}
            for index, field in ipairs(fields) do
                values[index] = '"' .. escape(field.name) .. '":' .. field.value
            end
            rendered = "{" .. table.concat(values, ",") .. "}"
        end

        active[item] = nil
        return rendered
    end

    return walk(value, 0)
end

Capture.encode = encode

local function required(label, reader)
    local ok, value = pcall(reader)
    if not ok then
        raise("required reader failed [" .. label .. "]")
    end
    return value
end

local function randomState()
    local ok, seed, draws = pcall(function() return SAO.Rand.state() end)
    if not ok then
        raise("required reader failed [Rand.state]")
    end
    return { seed = seed, draws = draws }
end

local function memberSnapshot(id)
    local record = required("Identity.get", function()
        return SAO.Identity.get(id)
    end)
    if type(record) ~= "table" then
        raise("required reader failed [Identity.get]: record absent for "
            .. tostring(id))
    end
    local snapshot = {
        id = id,
        name = required("Identity.name", function()
            return record.forename .. " " .. record.surname
        end),
        displayName = required("Identity.displayName", function()
            return plainNameOf(record.forename, record.surname)
        end),
        record = record,
        age = required("History.ageOf", function()
            return SAO.History.ageOf(id)
        end),
        circle = required("Disposition.circle", function()
            return SAO.Disposition.circle(id)
        end),
        traits = required("Disposition.traits", function()
            return SAO.Disposition.traits(id)
        end),
        conditions = required("Conditions.of", function()
            return SAO.Conditions.of(id)
        end),
        habits = required("Habits.of", function()
            return SAO.Habits.of(id)
        end),
        lessons = required("Lessons.renderClaims", function()
            return SAO.Lessons.renderClaims(id)
        end),
        occupationClass = required("Census.classOf", function()
            return SAO.Census.classOf(record.occupation)
        end),
        designationBefore = record.designation,
        designatedByBefore = record.designatedBy,
    }
    snapshot.skills = required("Census.skillOf", function()
        local skills = {}
        for job, perk in pairs(SAO.Census.JOB_PERK or {}) do
            skills[job] = SAO.Census.skillOf(id, perk) or 0
        end
        return skills
    end)
    snapshot.beliefs = required("Perception.beliefs", function()
        return (SAO.Perception.beliefs or {})[id] or {}
    end)
    return snapshot
end

local function relationsFor(members)
    local relations = {}
    for _, source in ipairs(members) do
        local row = {}
        for _, target in ipairs(members) do
            if source ~= target then
                row[target] = {
                    trust = required("Standing.trust", function()
                        return SAO.Standing.trust(source, target)
                    end),
                    hostile = required("Standing.isHostileTo", function()
                        return SAO.Standing.isHostileTo(source, target)
                    end) == true,
                }
            end
        end
        relations[source] = row
    end
    return relations
end

-- Observe the actual source-selection boundary without changing its policy.
-- The full option/person view freezes before selection, and the separate
-- choice binds to the reservation the real executor returns. This owner exists
-- only for the capture invocation; durable action authority remains in WS.
function Capture.beginSourceUse(context)
    if type(context) ~= "table" or type(context.runId) ~= "string"
        or context.runId == "" or type(context.county) ~= "string"
        or context.county == "" then raise("source capture requires runId and county") end
    if Capture.sourceOwner then raise("source capture is already active") end
    local sourceUse, world = SAO and SAO.SourceUse, SAO and SAO.WorldSources
    if not (sourceUse and type(sourceUse.chooseOption) == "function"
        and world and type(world.beginAction) == "function"
        and type(world.actionOutcome) == "function") then
        return { finish = function()
            return '{"schema":"sao-source-decision-capture","schemaVersion":1'
                .. ',"status":"unavailable","reason":"source-executor-not-loaded"'
                .. ',"attemptedEvents":0,"eventCount":0,"captureFailureCount":0'
                .. ',"failures":[],"events":[]}'
        end }
    end
    local runId, county = context.runId, context.county
    local selectOriginal, beginOriginal = sourceUse.chooseOption, world.beginAction
    local transferOriginal = world.beginTransfer
    local events, failures, selectedEvents = {}, {}, {}
    local attempted, overflow, closed = 0, false, false
    local selectWrapped, beginWrapped, transferWrapped, owner
    local function failure(eventId, stage, detail)
        failures[#failures + 1] = { eventId = eventId, stage = stage,
            detail = detail or pendingFailure or "source capture reader failed" }
    end
    selectWrapped = function(offered)
        attempted = attempted + 1
        if attempted > 2048 then
            if not overflow then failure(runId, "bound", "source capture exceeded 2048 events") end
            overflow = true
            return selectOriginal(offered)
        end
        local event = { id = runId .. "/source-use/" .. tostring(attempted),
            actorId = offered.actorId, hour = offered.atHours }
        local offeredBytes = {}
        pendingFailure = nil
        local captured = pcall(function()
            event.decision = encode({ eventType = "source-use", eventId = event.id,
                runId = runId, county = county, hours = offered.atHours,
                person = memberSnapshot(offered.actorId),
                situation = { county = county, hour = offered.atHours,
                    sourceOffer = offered }, random = randomState() })
            for _, option in ipairs(offered.options) do
                offeredBytes[option] = encode(option)
            end
        end)
        -- Observation failure must never suppress the real choice/action.
        local selected = selectOriginal(offered)
        if not captured then
            failure(event.id, "decision")
            return selected
        end
        pendingFailure = nil
        local choiceCaptured = pcall(function()
            if selected == nil then
                event.choice = encode({ status = "declined", owner = "SAO.SourceUse.chooseOption" })
                event.refusal = "no-option-selected"
            else
                if not offeredBytes[selected] or offeredBytes[selected] ~= encode(selected) then
                    raise("selected source option changed or was not offered")
                end
                event.choice = encode({ status = "selected", optionId = selected.id,
                    owner = "SAO.SourceUse.chooseOption", authorship = "runtime-policy",
                    ratified = false })
                selectedEvents[selected] = event
            end
        end)
        if not choiceCaptured then
            failure(event.id, "choice")
        else
            events[#events + 1] = event
        end
        return selected
    end
    beginWrapped = function(place, category, actorId, body, quantity, admission, selected)
        local event = selected and selectedEvents[selected] or nil
        if selected then selectedEvents[selected] = nil end
        local reservation, why = beginOriginal(place, category, actorId, body,
            quantity, admission, selected)
        if event then
            if reservation then
                event.reservationId = reservation.id
            else
                event.refusal = tostring(why or "reservation-refused")
            end
        end
        return reservation, why
    end
    if type(transferOriginal) == "function" then
        transferWrapped = function(actorId, body, category, admission, item,
                                   container, operation, selected)
            local event = selected and selectedEvents[selected] or nil
            if selected then selectedEvents[selected] = nil end
            local reservation, why = transferOriginal(actorId, body, category,
                admission, item, container, operation, selected)
            if event then
                if reservation then event.reservationId = reservation.id
                else event.refusal = tostring(why or "reservation-refused") end
            end
            return reservation, why
        end
        world.beginTransfer = transferWrapped
    end
    owner = { finish = function()
        if closed then raise("source capture already finished") end
        closed = true
        if sourceUse.chooseOption ~= selectWrapped or world.beginAction ~= beginWrapped
            or (transferWrapped and world.beginTransfer ~= transferWrapped) then
            failure(runId, "ownership", "source selection owner changed during capture")
        end
        if sourceUse.chooseOption == selectWrapped then sourceUse.chooseOption = selectOriginal end
        if world.beginAction == beginWrapped then world.beginAction = beginOriginal end
        if transferWrapped and world.beginTransfer == transferWrapped then
            world.beginTransfer = transferOriginal
        end
        Capture.sourceOwner = nil
        local rendered = {}
        for _, event in ipairs(events) do
            pendingFailure = nil
            local ok, text = pcall(function()
                local observedAt = required("History.countyHours.source-result", function()
                    return SAO.History.countyHours()
                end)
                if type(observedAt) ~= "number" or type(event.hour) ~= "number"
                    or observedAt < event.hour then raise("source capture clock moved backwards") end
                local result, why
                if event.reservationId then
                    result, why = world.actionOutcome(event.reservationId, event.actorId)
                    if result == nil and why ~= "result-not-retained" then
                        raise("required reader failed [WorldSources.actionOutcome]: " .. tostring(why))
                    end
                elseif event.refusal then
                    result = { status = "refused", detail = event.refusal }
                end
                result = result or { status = "censored", detail = why or "action-not-bound" }
                if result.at and (result.at < event.hour or result.at > observedAt) then
                    raise("source result lies outside the observed interval")
                end
                return '{"schema":"sao-source-decision-event","schemaVersion":1'
                    .. ',"runId":' .. encode(runId) .. ',"county":' .. encode(county)
                    .. ',"eventId":' .. encode(event.id) .. ',"decision":' .. event.decision
                    .. ',"choice":' .. event.choice .. ',"result":' .. encode(result)
                    .. ',"observation":' .. encode({ atHours = observedAt,
                        decisionHours = event.hour,
                        horizon = "source-action-terminal-or-capture-end",
                        laterConsequences = "not-observed" })
                    .. ',"conditioning":{"status":"ineligible","reasons":'
                    .. '["runtime-choice-not-ratified","person-knowledge-not-reconstructed",'
                    .. '"later-consequences-not-observed"]}}'
            end)
            if ok then rendered[#rendered + 1] = text else failure(event.id, "result") end
        end
        return '{"schema":"sao-source-decision-capture","schemaVersion":1'
            .. ',"status":"observed","attemptedEvents":' .. tostring(attempted)
            .. ',"eventCount":' .. tostring(#rendered)
            .. ',"captureFailureCount":' .. tostring(#failures)
            .. ',"failures":' .. encode(failures)
            .. ',"events":[' .. table.concat(rendered, ",") .. ']}'
    end }
    sourceUse.chooseOption, world.beginAction = selectWrapped, beginWrapped
    Capture.sourceOwner = owner
    return owner
end

-- Observe the actual Organization appraisal boundary.  The decision-time half
-- is encoded before the caller can deliver the response; later process/work
-- state is refreshed independently and can never rewrite those bytes.  The
-- raise wrapper takes a last read before bounded process retention may evict a
-- terminal record, so long county runs retain the latest outcome they really
-- observed without changing Organization's retention policy.
function Capture.beginCoordination(context)
    if type(context) ~= "table" or type(context.runId) ~= "string"
        or context.runId == "" or type(context.county) ~= "string"
        or context.county == "" then
        raise("coordination capture requires runId and county")
    end
    if Capture.coordinationOwner then
        raise("coordination capture is already active")
    end
    local organization = SAO and SAO.Organization
    if not (organization and type(organization.appraiseMatter) == "function"
        and type(organization.raiseMatter) == "function"
        and type(organization.decisionEvidence) == "function") then
        return { finish = function()
            return '{"schema":"sao-coordination-decision-capture"'
                .. ',"schemaVersion":1,"status":"unavailable"'
                .. ',"reason":"organization-evidence-owner-not-loaded"'
                .. ',"attemptedEvents":0,"eventCount":0'
                .. ',"captureFailureCount":0,"failures":[],"events":[]}'
        end }
    end

    local runId, county = context.runId, context.county
    local appraiseOriginal, raiseOriginal = organization.appraiseMatter,
        organization.raiseMatter
    local events, eventIndexes, processIndexes, failures = {}, {}, {}, {}
    local observedProcesses, observedProcessOrder = {}, {}
    local attempted, sequence, closed, overflow = 0, 0, false, false
    local appraiseWrapped, raiseWrapped, owner

    local function pack(...)
        return { count = select("#", ...), ... }
    end

    local function failure(identity, stage, detail)
        failures[#failures + 1] = { eventId = identity, stage = stage,
            detail = detail or pendingFailure
                or "coordination capture reader failed" }
    end

    local function countKeys(values)
        local count = 0
        for _ in pairs(values or {}) do count = count + 1 end
        return count
    end

    -- Public causal topology only. Private inputs remain in Organization and
    -- decision rows; this observation distinguishes addressed-but-unheard,
    -- heard-but-unanswered, returned responses and physical work without
    -- manufacturing a decision event for any of them.
    local function observeProcess(process)
        if type(process) ~= "table" or type(process.id) ~= "string" then return end
        local currentKey = tostring(math.max(1,
            math.floor(tonumber(process.revision) or 1)))
        local addressed, currentReceived, currentResponded = 0, 0, 0
        local receptionCount, responseCount, returnedCount = 0, 0, 0
        local responses, commitments, workOutcomes = {}, {}, {}
        local contactOutcomes, contactOwners = {}, {}
        local contactAttemptCount, contactArrivalCount = 0, 0
        local activeContactAttemptCount = 0
        for personId, participant in pairs(process.participants or {}) do
            if personId ~= process.originatorId and participant.addressed then
                addressed = addressed + 1
                if participant.receptions
                    and participant.receptions[currentKey] then
                    currentReceived = currentReceived + 1
                end
                if participant.responses and participant.responses[currentKey] then
                    currentResponded = currentResponded + 1
                end
                for _ in pairs(participant.receptions or {}) do
                    receptionCount = receptionCount + 1
                end
                for _, response in pairs(participant.responses or {}) do
                    responseCount = responseCount + 1
                    local choice = tostring(response.response or "unknown")
                    responses[choice] = (responses[choice] or 0) + 1
                    if response.delivered == true then
                        returnedCount = returnedCount + 1
                    end
                end
            end
        end
        for _, commitment in pairs(process.commitments or {}) do
            local status = tostring(commitment.status or "unknown")
            commitments[status] = (commitments[status] or 0) + 1
            for _, outcome in ipairs(commitment.work
                    and commitment.work.outcomes or {}) do
                local result = tostring(outcome.status or outcome.outcome
                    or outcome.phase or "observed")
                workOutcomes[result] = (workOutcomes[result] or 0) + 1
            end
        end
        for _, attempt in ipairs(process.contactAttempts or {}) do
            contactAttemptCount = contactAttemptCount + 1
            local status = tostring(attempt.status or "unknown")
            contactOutcomes[status] = (contactOutcomes[status] or 0) + 1
            if tonumber(attempt.arrivedAt) then
                contactArrivalCount = contactArrivalCount + 1
            end
            if status == "travelling" or status == "waiting" then
                activeContactAttemptCount = activeContactAttemptCount + 1
            end
            local owner = attempt.evidence and attempt.evidence.owner
                or "unknown"
            owner = tostring(owner)
            contactOwners[owner] = (contactOwners[owner] or 0) + 1
        end
        local origin = SAO.Identity and SAO.Identity.get
            and SAO.Identity.get(process.originatorId) or nil
        local summary = {
            processId = process.id,
            kind = process.kind,
            originatorId = process.originatorId,
            originatorBodyOwner = origin and origin.bodyOwner or "SAO",
            organizationId = process.organizationId,
            status = process.status,
            revision = tonumber(process.revision) or 1,
            revisionCount = countKeys(process.revisions),
            createdAt = process.createdAt,
            revisedAt = process.revisedAt,
            closedAt = process.closedAt,
            closureReason = process.closureReason,
            addressedCount = addressed,
            currentReceivedCount = currentReceived,
            currentRespondedCount = currentResponded,
            currentUnheardCount = math.max(0, addressed - currentReceived),
            currentUnansweredCount = math.max(0,
                currentReceived - currentResponded),
            receptionCount = receptionCount,
            responseCount = responseCount,
            returnedResponseCount = returnedCount,
            responses = responses,
            commitments = commitments,
            workOutcomes = workOutcomes,
            contactAttemptCount = contactAttemptCount,
            contactArrivalCount = contactArrivalCount,
            activeContactAttemptCount = activeContactAttemptCount,
            contactOutcomes = contactOutcomes,
            contactOwners = contactOwners,
            eventCount = #(process.events or {}),
        }
        if not observedProcesses[process.id] then
            observedProcessOrder[#observedProcessOrder + 1] = process.id
        end
        observedProcesses[process.id] = summary
    end

    local function observeAllProcesses()
        for _, processId in ipairs(organization.processOrder or {}) do
            observeProcess(organization.processes
                and organization.processes[processId] or nil)
        end
    end

    local function refresh(event)
        pendingFailure = nil
        local evidence = required("Organization.decisionEvidence.outcome", function()
            return organization.decisionEvidence(event.processId, event.actorId,
                event.processRevision)
        end)
        if type(evidence) ~= "table" or evidence.processId ~= event.processId
            or tonumber(evidence.processRevision) ~= event.processRevision
            or evidence.actorId ~= event.actorId
            or type(evidence.laterOutcome) ~= "table" then
            raise("coordination outcome differs from captured actor/process/revision")
        end
        event.outcome = encode(evidence.laterOutcome)
    end

    local function refreshAll()
        for _, event in ipairs(events) do
            if not event.failed then
                local ok = pcall(function() refresh(event) end)
                if not ok then
                    event.failed = true
                    failure(event.id, "outcome")
                end
            end
        end
    end

    local function refreshBeforeRetention()
        if #(organization.processOrder or {}) < 1024 then return end
        local now = required("History.countyHours.coordination-retention", function()
            return SAO.History.countyHours()
        end)
        for _, processId in ipairs(organization.processOrder or {}) do
            local process = organization.processes
                and organization.processes[processId] or nil
            local revision = process and process.revisions
                and process.revisions[tostring(process.revision or 1)] or nil
            local expiresAt = revision and revision.proposal
                and tonumber(revision.proposal.expiresAtHours) or nil
            local terminal = not process or process.status == "closed"
                or process.status == "expired" or process.status == "withdrawn"
                or process.status == "superseded"
                or (process.status == "open" and expiresAt and expiresAt <= now)
            local live = false
            for _, commitment in pairs(process and process.commitments or {}) do
                local status = commitment.status
                if status ~= "completed" and status ~= "failed"
                    and status ~= "interrupted" and status ~= "withdrawn"
                    and status ~= "superseded" then live = true; break end
            end
            if terminal and not live then
                observeProcess(process)
                for index in pairs(processIndexes[tostring(processId)] or {}) do
                    local event = events[index]
                    if event and not event.failed then
                        local ok = pcall(function() refresh(event) end)
                        if not ok then
                            event.failed = true
                            failure(event.id, "outcome")
                        end
                    end
                end
                return
            end
        end
    end

    appraiseWrapped = function(processId, personId, appraisal)
        attempted = attempted + 1
        local returned = pack(appraiseOriginal(processId, personId, appraisal))
        local response = returned[1]
        if response == nil then return unpack(returned, 1, returned.count) end
        if attempted > 16384 then
            if not overflow then
                overflow = true
                failure(runId, "bound", "coordination capture exceeded 16384 appraisals")
            end
            return unpack(returned, 1, returned.count)
        end

        sequence = sequence + 1
        local identity = runId .. "/coordination/" .. tostring(sequence)
        pendingFailure = nil
        local ok = pcall(function()
            local actorId = tostring(personId or "")
            local revision = math.floor(tonumber(response.revision) or 0)
            local evidence = required("Organization.decisionEvidence.decision", function()
                return organization.decisionEvidence(processId, actorId, revision)
            end)
            if actorId == "" or revision < 1 or type(evidence) ~= "table"
                or evidence.processId ~= tostring(processId)
                or tonumber(evidence.processRevision) ~= revision
                or evidence.actorId ~= actorId
                or type(evidence.decisionTime) ~= "table"
                or type(evidence.decisionTime.privateInputs) ~= "table"
                or type(evidence.decisionTime.response) ~= "table" then
                raise("coordination decision lacks exact actor/process/revision evidence")
            end
            local hour = evidence.decisionTime.asOfHour
            if type(hour) ~= "number" or hour ~= hour
                or hour == math.huge or hour == -math.huge then
                raise("coordination decision hour is not finite")
            end
            local private = evidence.decisionTime.privateInputs
            local feasible = private.feasibleOptions
            if type(feasible) ~= "table" or #feasible == 0
                or type(private.choice) ~= "string" then
                raise("coordination decision lacks feasible options or choice")
            end
            local options, chosen = {}, false
            for _, responseName in ipairs(feasible) do
                if type(responseName) ~= "string" or responseName == "" then
                    raise("coordination feasible option is not named")
                end
                if responseName == private.choice then chosen = true end
                options[#options + 1] = {
                    id = "coordination:" .. responseName,
                    owner = "SAO.Organization.respond",
                    parameters = { actorId = actorId,
                        processId = tostring(processId),
                        processRevision = revision, response = responseName },
                    eligibility = { status = "eligible", evidence = {
                        { kind = "actor-private-appraisal", actorId = actorId,
                            processRevision = revision },
                    } },
                }
            end
            if not chosen or evidence.decisionTime.response.response ~= private.choice then
                raise("coordination choice differs from its private appraisal")
            end
            local namespace = { runId = runId, county = county,
                personId = actorId, eventId = identity, hour = hour }
            local rowPrefix = '{"schema":"speakeasy-decision-row"'
                .. ',"schemaVersion":3,"namespace":' .. encode(namespace)
                .. ',"person":' .. encode(memberSnapshot(actorId))
                .. ',"situation":' .. encode({ county = county, hour = hour,
                    kind = evidence.decisionTime.kind,
                    processId = tostring(processId), processRevision = revision })
                .. ',"options":' .. encode(options)
                .. ',"choice":' .. encode({
                    optionId = "coordination:" .. private.choice })
                .. ',"citation":' .. encode({ county = county,
                    person = actorId, hour = hour,
                    source = "SAO.Organization.decisionEvidence" })
                .. ',"conditioning":' .. encode({ status = "ineligible",
                    decisionHour = hour, latestEvidenceHour = hour,
                    exclusions = { "independent-task-review-not-recorded",
                        "learned-runtime-not-integrated" } })
                .. ',"enactedProcess":{"schema":1,"processId":'
                .. encode(tostring(processId))
                .. ',"processRevision":' .. tostring(revision)
                .. ',"actorId":' .. encode(actorId)
                .. ',"decisionTime":' .. encode(evidence.decisionTime)
            local event = { id = identity, processId = tostring(processId),
                processRevision = revision, actorId = actorId,
                prefix = rowPrefix, outcome = encode(evidence.laterOutcome) }
            local key = event.processId .. string.char(31) .. tostring(revision)
                .. string.char(31) .. actorId
            local existing = eventIndexes[key]
            if existing then events[existing] = event
            else
                events[#events + 1] = event
                eventIndexes[key] = #events
                processIndexes[event.processId] = processIndexes[event.processId] or {}
                processIndexes[event.processId][#events] = true
            end
        end)
        if not ok then failure(identity, "decision") end
        return unpack(returned, 1, returned.count)
    end

    raiseWrapped = function(...)
        local ok = pcall(refreshBeforeRetention)
        if not ok then failure(runId, "retention") end
        local returned = pack(raiseOriginal(...))
        observeProcess(returned[1])
        return unpack(returned, 1, returned.count)
    end

    owner = { finish = function()
        if closed then raise("coordination capture already finished") end
        closed = true
        refreshAll()
        observeAllProcesses()
        if organization.appraiseMatter ~= appraiseWrapped
            or organization.raiseMatter ~= raiseWrapped then
            failure(runId, "ownership",
                "Organization appraisal owner changed during capture")
        end
        if organization.appraiseMatter == appraiseWrapped then
            organization.appraiseMatter = appraiseOriginal
        end
        if organization.raiseMatter == raiseWrapped then
            organization.raiseMatter = raiseOriginal
        end
        Capture.coordinationOwner = nil
        local rendered = {}
        for _, event in ipairs(events) do
            if not event.failed and event.outcome then
                rendered[#rendered + 1] = event.prefix
                    .. ',"laterOutcome":' .. event.outcome .. '}}'
            end
        end
        local processRows = {}
        local processKinds, processStatuses, responseChoices = {}, {}, {}
        local contactOutcomes, contactOwners = {}, {}
        local addressed, receptions, responses, returned = 0, 0, 0, 0
        local unheard, unanswered = 0, 0
        local contactAttempts, contactArrivals, activeContacts = 0, 0, 0
        for _, processId in ipairs(observedProcessOrder) do
            local process = observedProcesses[processId]
            if process then
                processRows[#processRows + 1] = process
                processKinds[tostring(process.kind or "unknown")] =
                    (processKinds[tostring(process.kind or "unknown")] or 0) + 1
                processStatuses[tostring(process.status or "unknown")] =
                    (processStatuses[tostring(process.status or "unknown")] or 0) + 1
                addressed = addressed + (tonumber(process.addressedCount) or 0)
                receptions = receptions + (tonumber(process.receptionCount) or 0)
                responses = responses + (tonumber(process.responseCount) or 0)
                returned = returned
                    + (tonumber(process.returnedResponseCount) or 0)
                unheard = unheard
                    + (tonumber(process.currentUnheardCount) or 0)
                unanswered = unanswered
                    + (tonumber(process.currentUnansweredCount) or 0)
                contactAttempts = contactAttempts
                    + (tonumber(process.contactAttemptCount) or 0)
                contactArrivals = contactArrivals
                    + (tonumber(process.contactArrivalCount) or 0)
                activeContacts = activeContacts
                    + (tonumber(process.activeContactAttemptCount) or 0)
                for choice, count in pairs(process.responses or {}) do
                    responseChoices[choice] = (responseChoices[choice] or 0)
                        + (tonumber(count) or 0)
                end
                for outcome, count in pairs(process.contactOutcomes or {}) do
                    contactOutcomes[outcome] = (contactOutcomes[outcome] or 0)
                        + (tonumber(count) or 0)
                end
                for contactOwner, count in pairs(process.contactOwners or {}) do
                    contactOwners[contactOwner] = (contactOwners[contactOwner] or 0)
                        + (tonumber(count) or 0)
                end
            end
        end
        local processObservation = {
            schema = "sao-shared-process-observation", schemaVersion = 1,
            processCount = #processRows, kindCounts = processKinds,
            statusCounts = processStatuses, addressedCount = addressed,
            receptionCount = receptions, responseCount = responses,
            returnedResponseCount = returned,
            currentUnheardCount = unheard,
            currentUnansweredCount = unanswered,
            contactAttemptCount = contactAttempts,
            contactArrivalCount = contactArrivals,
            activeContactAttemptCount = activeContacts,
            contactOutcomeCounts = contactOutcomes,
            contactOwnerCounts = contactOwners,
            responseCounts = responseChoices, processes = processRows,
        }
        return '{"schema":"sao-coordination-decision-capture"'
            .. ',"schemaVersion":1,"status":"observed"'
            .. ',"attemptedEvents":' .. tostring(attempted)
            .. ',"eventCount":' .. tostring(#rendered)
            .. ',"captureFailureCount":' .. tostring(#failures)
            .. ',"failures":' .. encode(failures)
            .. ',"events":[' .. table.concat(rendered, ",") .. ']'
            .. ',"processObservation":' .. encode(processObservation) .. '}'
    end }
    organization.appraiseMatter, organization.raiseMatter = appraiseWrapped,
        raiseWrapped
    Capture.coordinationOwner = owner
    return owner
end

function Capture.begin(context)
    if type(context) ~= "table" or type(context.runId) ~= "string"
            or type(context.county) ~= "string" then
        raise("decision capture requires runId and county")
    end
    if not (SAO and SAO.Standing and type(SAO.Standing.electLeader) == "function") then
        raise("decision capture requires Standing.electLeader")
    end

    local sourceCapture = Capture.beginSourceUse(context)
    local coordinationCapture = Capture.beginCoordination(context)

    local standing = ModData.getOrCreate("SurvivorAwareness_Standing")
    local original = SAO.Standing.electLeader
    local events, failures = {}, {}
    local attempted, sequence = 0, 0
    local wrapped

    local function eventId()
        sequence = sequence + 1
        return context.runId .. "/standing-election/" .. tostring(sequence)
    end

    local function decisionFor(groupName, identity)
        groupName = tostring(groupName)
        local members = {}
        for id, group in pairs(standing.groups or {}) do
            if group == groupName then
                local record = required("Identity.get.roster", function()
                    return SAO.Identity.get(id)
                end)
                if not (record and record.dead) then members[#members + 1] = id end
            end
        end
        if #members < 2 then return nil, members end
        table.sort(members)

        local creed = required("Standing.creedOf", function()
            local value = SAO.Standing.creedOf(groupName)
            return value and value.name or nil
        end)
        local feuds = required("Standing.feudBetween", function()
            local values = {}
            for other in pairs(standing.groupClaims or {}) do
                if other ~= groupName then
                    values[other] = SAO.Standing.feudBetween(groupName, other) == true
                end
            end
            return values
        end)
        local decision = {
            eventType = "standing-election",
            eventId = identity,
            runId = context.runId,
            county = context.county,
            hours = required("History.countyHours", function()
                return SAO.History.countyHours()
            end),
            random = randomState(),
            source = {
                kind = "instrumented-shipped-modules",
                confidence = "direct-runtime",
            },
            group = groupName,
            size = #members,
            creed = creed,
            claim = (standing.groupClaims or {})[groupName],
            relations = relationsFor(members),
            need = {
                larder = required("Standing.larderOf", function()
                    return SAO.Standing.larderOf(groupName)
                end),
                water = required("Standing.waterStoreOf", function()
                    return SAO.Standing.waterStoreOf(groupName)
                end),
                hearth = required("Standing.hearthOf", function()
                    return SAO.Standing.hearthOf(groupName)
                end),
                feuds = feuds,
            },
            roster = {},
        }
        for _, id in ipairs(members) do
            decision.roster[#decision.roster + 1] = memberSnapshot(id)
        end
        return decision, members
    end

    local function resultFor(groupName, identity, members)
        local roster = {}
        for _, id in ipairs(members) do
            local record = required("Identity.get.result", function()
                return SAO.Identity.get(id)
            end)
            roster[#roster + 1] = {
                id = id,
                designationAfter = record and record.designation or nil,
                designatedByAfter = record and record.designatedBy or nil,
            }
        end
        local metadata = standing.groupMeta
            and standing.groupMeta[tostring(groupName)] or nil
        return {
            eventType = "standing-election-result",
            eventId = identity,
            observedHours = required("History.countyHours.result", function()
                return SAO.History.countyHours()
            end),
            leaderAfter = metadata and metadata.leaderId or nil,
            roster = roster,
        }
    end

    local function failure(identity, stage, detail)
        failures[#failures + 1] = {
            eventId = identity,
            stage = stage,
            detail = tostring(detail),
        }
    end

    local function pack(...)
        return { count = select("#", ...), ... }
    end

    wrapped = function(groupName)
        attempted = attempted + 1
        local identity = eventId()
        local decision, members, frozenDecision
        pendingFailure = nil
        local okDecision, whyDecision = pcall(function()
            decision, members = decisionFor(groupName, identity)
            if decision then frozenDecision = encode(decision) end
        end)

        local returned = pack(original(groupName))

        if not okDecision then
            failure(identity, "decision",
                pendingFailure or "unclassified decision capture failure")
        elseif decision then
            local frozenResult
            pendingFailure = nil
            local okResult, whyResult = pcall(function()
                frozenResult = encode(resultFor(groupName, identity, members))
            end)
            if not okResult then
                failure(identity, "result",
                    pendingFailure or "unclassified result capture failure")
            else
                events[#events + 1] = '{"schema":"sao-decision-event"'
                    .. ',"schemaVersion":1'
                    .. ',"runId":' .. encode(context.runId)
                    .. ',"county":' .. encode(context.county)
                    .. ',"eventId":' .. encode(identity)
                    .. ',"decision":' .. frozenDecision
                    .. ',"options":{"status":"not-captured","executable":[]}'
                    .. ',"choice":{"status":"not-captured"}'
                    .. ',"result":' .. frozenResult
                    .. ',"consequences":{"status":"not-observed"'
                    .. ',"observationHorizon":{"status":"not-defined"'
                    .. ',"hours":null}}'
                    .. ',"conditioning":{"status":"ineligible"'
                    .. ',"reasons":["executable-options-not-captured"'
                    .. ',"choice-not-captured"'
                    .. ',"action-consequences-not-observed"]}}'
            end
        end
        return unpack(returned, 1, returned.count)
    end
    SAO.Standing.electLeader = wrapped

    return {
        finish = function()
            local sourceCaptured = sourceCapture.finish()
            local coordinationCaptured = coordinationCapture.finish()
            if SAO.Standing.electLeader ~= wrapped then
                failure(context.runId .. "/capture-owner", "ownership",
                    "Standing.electLeader changed while capture was active")
            else
                SAO.Standing.electLeader = original
            end
            return '{"schema":"sao-decision-capture"'
                .. ',"schemaVersion":1'
                .. ',"attemptedEvents":' .. tostring(attempted)
                .. ',"eventCount":' .. tostring(#events)
                .. ',"captureFailureCount":' .. tostring(#failures)
                .. ',"failures":' .. encode(failures)
                .. ',"sourceActions":' .. sourceCaptured
                .. ',"coordinationActions":' .. coordinationCaptured
                .. ',"events":[' .. table.concat(events, ",") .. ']}'
        end,
    }
end
