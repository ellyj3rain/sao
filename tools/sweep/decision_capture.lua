-- Immutable decision-time evidence for tools/county_dump.py.
--
-- This instrument observes Standing elections and loaded SourceUse decisions.
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

function Capture.begin(context)
    if type(context) ~= "table" or type(context.runId) ~= "string"
            or type(context.county) ~= "string" then
        raise("decision capture requires runId and county")
    end
    if not (SAO and SAO.Standing and type(SAO.Standing.electLeader) == "function") then
        raise("decision capture requires Standing.electLeader")
    end

    local sourceCapture = Capture.beginSourceUse(context)

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
                .. ',"events":[' .. table.concat(events, ",") .. ']}'
        end,
    }
end
