-- SAO_CoordinationInference.lua - guarded native coordination shadow.
--
-- Speakeasy owns the frozen bundle and reference inference.  This SAO owner
-- freezes the actual Organization decision horizon, submits only immutable
-- scalar text to Java, and re-reads the process plus registered execution
-- owner before retaining a result.  The result is observation only: it cannot
-- select, revise, deliver or withdraw a response and cannot create work.

SAO = SAO or {}
SAO.CoordinationInference = SAO.CoordinationInference or {}
local Inference = SAO.CoordinationInference

local BUNDLE_SHA256 =
    "02edcdc1caf7489f0871f63e35af2c2cc26966ec74c0cf30eb63d155b1acb33c"
local BUNDLE_ID = "r67-r66-coordination-fp32-v1"
local MAX_PENDING = 128
local MAX_OBSERVATIONS = 256
local MAX_JSON_DEPTH = 16
local MAX_INPUT_BYTES = 65536
local MAX_TABLE_ENTRIES = 512
local JSON_NULL = {}
local LEARNED = { accept=true, qualify=true, ["counter-propose"]=true,
    defer=true, contest=true }
local RESPONSE = { accept=true, qualify=true, ["counter-propose"]=true,
    decline=true, defer=true, contest=true, withdraw=true }
local HIDDEN = { currentForm=true, diagnosis=true, diet=true, dietKnown=true,
    pathogen=true, pathogenDiagnosis=true, terminalState=true,
    visibleForms=true }

Inference.pending = Inference.pending or {}
Inference.observations = Inference.observations or {}
Inference.sequence = tonumber(Inference.sequence) or 0
Inference.counters = Inference.counters or {
    submitted=0, observed=0, withheld=0, refused=0 }

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function identity(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

local function count(value)
    local total = 0
    for _ in pairs(value or {}) do total = total + 1 end
    return total
end

local function splitTabs(value)
    local fields = {}
    local subject = tostring(value or "") .. "\t"
    for field in string.gmatch(subject, "(.-)\t") do
        fields[#fields + 1] = field
    end
    return fields
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

-- Python's decision authoring uses sorted, compact, UTF-8 JSON.  Kahlua has no
-- JSON library, so this bounded encoder reproduces that byte contract over the
-- same scalar trees Organization already permits in ModData.
local function canonical(value)
    local active = {}
    local function walk(item, depth)
        if item == JSON_NULL or item == nil then return "null" end
        local kind = type(item)
        if kind == "boolean" then return item and "true" or "false" end
        if kind == "number" then
            if not finite(item) then error("coordination JSON number is non-finite") end
            if item == math.floor(item) and math.abs(item) < 1e15 then
                return string.format("%.0f", item)
            end
            return tostring(item)
        end
        if kind == "string" then return '"' .. escape(item) .. '"' end
        if kind ~= "table" then
            error("coordination JSON cannot encode " .. kind)
        end
        if depth > MAX_JSON_DEPTH then
            error("coordination JSON exceeded maximum depth")
        end
        if active[item] then error("coordination JSON found a table cycle") end
        active[item] = true
        local size, greatest, array = 0, 0, true
        for key in pairs(item) do
            size = size + 1
            if size > MAX_TABLE_ENTRIES then
                error("coordination JSON table exceeded entry bound")
            end
            if type(key) == "number" and key >= 1
                and key == math.floor(key) then
                greatest = math.max(greatest, key)
            else
                array = false
            end
        end
        local rendered
        if array and size > 0 and greatest == size then
            local values = {}
            for index = 1, size do values[index] = walk(item[index], depth + 1) end
            rendered = "[" .. table.concat(values, ",") .. "]"
        else
            local fields, names = {}, {}
            for key, child in pairs(item) do
                local keyKind = type(key)
                if keyKind ~= "string" and keyKind ~= "number" then
                    error("coordination JSON map key is " .. keyKind)
                end
                local name = tostring(key)
                if names[name] then
                    error("coordination JSON has duplicate key " .. name)
                end
                names[name] = true
                fields[#fields + 1] = { name=name,
                    value=walk(child, depth + 1) }
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
    local result = walk(value, 0)
    if #result > MAX_INPUT_BYTES then
        error("coordination JSON exceeded maximum bytes")
    end
    return result
end

Inference.canonical = canonical

local function containsHidden(value, depth)
    if type(value) ~= "table" then return false end
    depth = depth or 0
    if depth > MAX_JSON_DEPTH then return true end
    for key, child in pairs(value) do
        if type(key) == "string" and HIDDEN[key] then return true end
        if containsHidden(child, depth + 1) then return true end
    end
    return false
end

local function optionsOf(value)
    if type(value) ~= "table" then return nil, "feasible-options-absent" end
    local options, seen, supported = {}, {}, false
    for index, option in ipairs(value) do
        option = identity(option)
        if not option or not RESPONSE[option] or seen[option] then
            return nil, "feasible-options-invalid"
        end
        seen[option] = true
        supported = supported or LEARNED[option] == true
        options[index] = option
    end
    if #options == 0 then return nil, "feasible-options-empty" end
    if not supported then return nil, "learned-feasible-options-empty" end
    return options
end

local function featureText(value)
    if not finite(value) then error("coordination feature is non-finite") end
    return string.format("%.9g", value)
end

local function boolNumber(value) return value == true and 1 or 0 end

local function decisionSnapshot(processId, personId, responseRevision)
    local organization = SAO.Organization
    if not (organization and type(organization.viewFor) == "function") then
        return nil, "organization-unavailable"
    end
    local view = organization.viewFor(personId, processId, false)
    if type(view) ~= "table" then return nil, "process-view-unavailable" end
    local revision = math.floor(tonumber(view.revision) or 0)
    if revision < 1 or tonumber(view.currentRevision) ~= revision then
        return nil, "process-revision-stale"
    end
    local response, private = view.response, view.privateInputs
    if type(response) ~= "table" or type(private) ~= "table"
        or tonumber(response.responseRevision) ~= tonumber(responseRevision) then
        return nil, "response-revision-stale"
    end
    local proposalRecord, reception = view.proposal, view.reception
    if type(proposalRecord) ~= "table"
        or type(proposalRecord.proposal) ~= "table"
        or type(reception) ~= "table" then
        return nil, "decision-evidence-incomplete"
    end
    -- Condition-private truth must not enter through a less obvious container.
    -- The task contract forbids these fields everywhere in model input, not
    -- only in the controller's constraint map.
    if containsHidden(proposalRecord.proposal)
        or containsHidden(reception.evidence)
        or containsHidden(private.capabilities)
        or containsHidden(private.constraints)
        or containsHidden(private.interests)
        or containsHidden(private.inputOwners) then
        return nil, "hidden-condition-field"
    end
    local executor = identity(private.executor)
    local bodyOwner = identity(private.bodyOwner)
    local activity = identity(private.currentActivity)
    local owners = private.inputOwners
    local capabilities = private.capabilities
    local constraints = private.constraints
    if not executor or not bodyOwner or not activity
        or type(owners) ~= "table" or type(capabilities) ~= "table"
        or type(constraints) ~= "table" or type(private.interests) ~= "table"
        or not finite(tonumber(private.relationship))
        or not finite(tonumber(private.ownNeed)) then
        return nil, "decision-input-incomplete"
    end
    for _, name in ipairs({ "currentActivity", "capabilities", "ownNeed",
            "relationship", "interests", "constraints" }) do
        if not identity(owners[name]) then return nil, "input-owner-absent" end
    end
    for _, name in ipairs({ "acquire", "carry", "deliver", "execute" }) do
        if type(capabilities[name]) ~= "boolean" then
            return nil, "capability-invalid"
        end
    end
    for _, name in ipairs({ "represented", "executionOwnerAvailable",
            "ownNeedAvailable" }) do
        if type(constraints[name]) ~= "boolean" then
            return nil, "constraint-availability-invalid"
        end
    end
    if tostring(constraints.currentActivity or "") ~= activity then
        return nil, "constraint-activity-differs"
    end
    local options, why = optionsOf(private.feasibleOptions)
    if not options then return nil, why end
    if not RESPONSE[tostring(response.response or "")] then
        return nil, "actual-response-invalid"
    end

    local receptionInput = { channel=tostring(reception.channel or "") }
    if type(reception.evidence) == "table" then
        receptionInput.evidence = reception.evidence
    end
    local pressureAvailable = constraints.ownNeedAvailable == true
    local proposal = proposalRecord.proposal
    local input = {
        schema="speakeasy-coordination-response-input", schemaVersion=1,
        route="coordination-response", process={ kind=tostring(view.kind or "") },
        actor={ executor=executor, bodyOwner=bodyOwner },
        decisionTime={
            proposal=proposal,
            reception=receptionInput,
            currentWork={ activity=activity,
                owner=owners.currentActivity },
            competingPriorities={
                competingPressure={
                    value=pressureAvailable and tonumber(private.ownNeed)
                        or JSON_NULL,
                    available=pressureAvailable, owner=owners.ownNeed },
                relationship=tonumber(private.relationship),
                interests=private.interests, constraints=constraints,
                owners={ ownNeed=owners.ownNeed,
                    relationship=owners.relationship,
                    interests=owners.interests,
                    constraints=owners.constraints },
            },
            capabilities={ values=capabilities, owner=owners.capabilities,
                availability=constraints.executionOwnerAvailable
                    and "available" or "unavailable" },
            feasibleOptions=options,
        },
    }
    local ok, encoded = pcall(canonical, input)
    if not ok then return nil, "canonical-input-refused" end
    local relationship = tonumber(private.relationship)
    local ownNeed = pressureAvailable and tonumber(private.ownNeed) or 0
    local features = {
        relationship, math.abs(relationship), ownNeed,
        boolNumber(pressureAvailable), boolNumber(activity == "idle"),
        boolNumber(constraints.contest), boolNumber(constraints.represented),
        boolNumber(constraints.executionOwnerAvailable),
        boolNumber(constraints.ownNeedAvailable),
        boolNumber(proposal.destination ~= nil),
        boolNumber(executor == "ZAO.Driver"), boolNumber(bodyOwner == "ZAO"),
        boolNumber(capabilities.acquire), boolNumber(capabilities.carry),
        boolNumber(capabilities.deliver), boolNumber(capabilities.execute),
    }
    local featureFields = {}
    for index, value in ipairs(features) do
        local featureOk, rendered = pcall(featureText, value)
        if not featureOk then return nil, "typed-feature-refused" end
        featureFields[index] = rendered
    end
    return {
        processId=tostring(processId), personId=tostring(personId),
        processRevision=revision,
        responseRevision=math.floor(tonumber(response.responseRevision) or 0),
        actualResponse=tostring(response.response), canonical=encoded,
        features=table.concat(featureFields, ","),
        options=table.concat(options, ","), optionSet=(function()
            local result = {}; for _, option in ipairs(options) do result[option]=true end
            return result
        end)(),
        bodyOwner=bodyOwner, executor=executor, currentActivity=activity,
    }
end

local function ownerSignature(personId, snapshot)
    local record = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(personId) or nil
    local durableOwner = type(record) == "table" and record.bodyOwner or nil
    durableOwner = identity(durableOwner) or "SAO"
    if durableOwner ~= snapshot.bodyOwner then
        return nil, "body-owner-changed"
    end
    local current, reason
    if SAO.Communication and type(SAO.Communication.actorSnapshot) == "function" then
        local ok
        ok, current, reason = pcall(SAO.Communication.actorSnapshot, personId)
        if not ok then current, reason = nil, "execution-owner-exception" end
    end
    if snapshot.bodyOwner ~= "SAO" and type(current) ~= "table" then
        return nil, reason or "execution-owner-unavailable"
    end
    current = type(current) == "table" and current or {}
    local signature = {
        bodyOwner=durableOwner,
        currentActivity=string.lower(tostring(current.currentActivity
            or snapshot.currentActivity)),
        represented=current.represented == true,
    }
    if identity(current.executor) then signature.executor = current.executor end
    for _, name in ipairs({ "canAcquire", "canCarry", "canDeliver",
            "canExecute" }) do
        if type(current[name]) == "boolean" then signature[name] = current[name] end
    end
    if current.competingPressureAvailable ~= nil then
        signature.competingPressureAvailable =
            current.competingPressureAvailable == true
    end
    if tonumber(current.competingPressure) then
        signature.competingPressure = tonumber(current.competingPressure)
    end
    local ok, encoded = pcall(canonical, signature)
    if not ok then return nil, "execution-owner-state-refused" end
    return encoded
end

local function bridgeStanding()
    if not SAOJavaBridge then return nil, "bridge-unavailable" end
    local ok, value = pcall(function()
        return SAOJavaBridge:coordinationBundleStatus()
    end)
    if not ok or type(value) ~= "string" then
        return nil, "bundle-status-unavailable"
    end
    local fields = splitTabs(value)
    if fields[1] ~= "READY" or fields[2] ~= BUNDLE_SHA256
        or fields[3] ~= BUNDLE_ID then
        return nil, "bundle-identity-refused"
    end
    return value
end

local function observe(value)
    Inference.observations[#Inference.observations + 1] = value
    while #Inference.observations > MAX_OBSERVATIONS do
        table.remove(Inference.observations, 1)
    end
    return value
end

local function withheld(snapshot, reason)
    Inference.counters.withheld = Inference.counters.withheld + 1
    return observe({ status="withheld", reason=tostring(reason or "refused"),
        requestId=snapshot.requestId, processId=snapshot.processId,
        personId=snapshot.personId, processRevision=snapshot.processRevision,
        responseRevision=snapshot.responseRevision,
        actualResponse=snapshot.actualResponse, bundleSha256=BUNDLE_SHA256 })
end

function Inference.submit(processId, personId, responseRevision)
    if count(Inference.pending) >= MAX_PENDING then
        Inference.counters.refused = Inference.counters.refused + 1
        return false, "pending-capacity"
    end
    local standing, why = bridgeStanding()
    if not standing then
        Inference.counters.refused = Inference.counters.refused + 1
        return false, why
    end
    local snapshot
    snapshot, why = decisionSnapshot(processId, personId, responseRevision)
    if not snapshot then
        Inference.counters.refused = Inference.counters.refused + 1
        return false, why
    end
    snapshot.ownerSignature, why = ownerSignature(personId, snapshot)
    if not snapshot.ownerSignature then
        Inference.counters.refused = Inference.counters.refused + 1
        return false, why
    end
    Inference.sequence = Inference.sequence + 1
    local requestId = "sao-coordination-shadow-" .. tostring(Inference.sequence)
    local ok, result = pcall(function()
        return SAOJavaBridge:submitCoordinationShadow(requestId,
            snapshot.canonical, snapshot.features, snapshot.options)
    end)
    local fields = ok and splitTabs(result) or {}
    if fields[1] ~= "QUEUED" or fields[2] ~= requestId
        or not identity(fields[3]) then
        Inference.counters.refused = Inference.counters.refused + 1
        return false, "worker-submission-refused"
    end
    snapshot.requestId, snapshot.inputSha256 = requestId, fields[3]
    Inference.pending[requestId] = snapshot
    Inference.counters.submitted = Inference.counters.submitted + 1
    return true, requestId
end

local function validateProbabilities(value, snapshot, predicted)
    local probabilities, total = {}, 0
    local subject = tostring(value or "") .. ","
    for field in string.gmatch(subject, "(.-),") do
        local label, number = string.match(field, "^([^=]+)=([^=]+)$")
        number = tonumber(number)
        if not label or not LEARNED[label] or not snapshot.optionSet[label]
            or probabilities[label] ~= nil or not finite(number)
            or number < 0 or number > 1 then
            return nil
        end
        probabilities[label], total = number, total + number
    end
    if not probabilities[predicted] or math.abs(total - 1) > 0.0001 then
        return nil
    end
    return probabilities
end

local function complete(snapshot, fields)
    if #fields ~= 7 or fields[1] ~= "READY"
        or fields[2] ~= BUNDLE_SHA256
        or fields[3] ~= snapshot.inputSha256 then
        return withheld(snapshot, "foreign-or-malformed-result")
    end
    local predicted = fields[4]
    local probabilities = validateProbabilities(fields[5], snapshot, predicted)
    local tokenCount, latencyNanos = tonumber(fields[6]), tonumber(fields[7])
    if not LEARNED[predicted] or not snapshot.optionSet[predicted]
        or not probabilities or not finite(tokenCount) or tokenCount < 4
        or not finite(latencyNanos) or latencyNanos < 0 then
        return withheld(snapshot, "invalid-model-output")
    end
    local current, why = decisionSnapshot(snapshot.processId, snapshot.personId,
        snapshot.responseRevision)
    if not current then return withheld(snapshot, why) end
    if current.processRevision ~= snapshot.processRevision
        or current.canonical ~= snapshot.canonical
        or current.features ~= snapshot.features
        or current.options ~= snapshot.options then
        return withheld(snapshot, "decision-snapshot-changed")
    end
    local signature
    signature, why = ownerSignature(snapshot.personId, snapshot)
    if not signature then return withheld(snapshot, why) end
    if signature ~= snapshot.ownerSignature then
        return withheld(snapshot, "execution-owner-state-changed")
    end
    Inference.counters.observed = Inference.counters.observed + 1
    return observe({ status="observed", requestId=snapshot.requestId,
        processId=snapshot.processId, personId=snapshot.personId,
        processRevision=snapshot.processRevision,
        responseRevision=snapshot.responseRevision,
        actualResponse=snapshot.actualResponse, predictedResponse=predicted,
        probabilities=probabilities, tokenCount=math.floor(tokenCount),
        latencyNanos=math.floor(latencyNanos), bundleSha256=BUNDLE_SHA256,
        authoritative=false })
end

function Inference.poll()
    if not SAOJavaBridge then return 0 end
    local completed = 0
    local ids = {}
    for requestId in pairs(Inference.pending) do ids[#ids + 1] = requestId end
    table.sort(ids)
    for _, requestId in ipairs(ids) do
        local snapshot = Inference.pending[requestId]
        local ok, value = pcall(function()
            return SAOJavaBridge:pollCoordinationShadow(requestId)
        end)
        local fields = ok and splitTabs(value) or {}
        if fields[1] ~= "PENDING" then
            Inference.pending[requestId] = nil
            completed = completed + 1
            if fields[1] == "READY" then
                complete(snapshot, fields)
            elseif fields[1] == "MISSING" then
                withheld(snapshot, "worker-result-missing")
            else
                withheld(snapshot, "worker-result-failed")
            end
        end
    end
    return completed
end

-- A request is keyed by its immutable request id but owns one living person's
-- decision snapshot. Death must drop both the Lua hold and the matching Java
-- task; otherwise completed-but-unpolled requests consume the bounded worker
-- map for the rest of the world session.
function Inference.forgetPerson(personId)
    personId = tostring(personId or "")
    if personId == "" then return 0 end
    local removed = 0
    for requestId, snapshot in pairs(Inference.pending) do
        if snapshot.personId == personId then
            Inference.pending[requestId] = nil
            removed = removed + 1
            if SAOJavaBridge then
                pcall(function()
                    SAOJavaBridge:cancelCoordinationShadow(requestId)
                end)
            end
        end
    end
    for index = #Inference.observations, 1, -1 do
        if Inference.observations[index].personId == personId then
            table.remove(Inference.observations, index)
        end
    end
    return removed
end

function Inference.reset()
    Inference.pending = {}
    Inference.observations = {}
    Inference.sequence = 0
    Inference.counters = { submitted=0, observed=0, withheld=0, refused=0 }
end

function Inference.status()
    return { pending=count(Inference.pending), observations=#Inference.observations,
        submitted=Inference.counters.submitted,
        observed=Inference.counters.observed,
        withheld=Inference.counters.withheld,
        refused=Inference.counters.refused,
        bundleSha256=BUNDLE_SHA256, authoritative=false }
end

return Inference
