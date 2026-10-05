-- Person-owned educational provenance and detached conceptual conditioning.
-- Java validates the complete source export before this owner publishes it.
SAO = SAO or {}
SAO.Education = SAO.Education or {}
local E = SAO.Education
local bindingsProvider = nil
local MAX_BYTES = 2 * 1024 * 1024
local TICKS_PER_DAY = 216000
local BINDINGS = { "worldSha256", "profileSha256", "sourceBankSha256",
    "backgroundsSha256", "personEducationSha256", "educationalExposuresSha256",
    "sourceArchiveSha256" }
local AUTHORITIES = { "nativeSkillAuthority", "recipeAuthority", "currentWorldAuthority",
    "peerAssentAuthority", "modelTrainingAuthority", "runtimeIntegration" }

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
local function integer(v, maximum)
    return finite(v) and v >= 0 and v <= maximum and v == math.floor(v)
end
local function hash(v)
    return type(v) == "string" and #v == 64 and not string.find(v, "[^a-f0-9]")
end
local function plainCopy(v, seen, depth)
    if type(v) ~= "table" then return v end
    seen, depth = seen or {}, depth or 0
    if seen[v] or depth > 8 then return nil end
    seen[v] = true
    local out = {}
    for key, value in pairs(v) do
        local child = plainCopy(value, seen, depth + 1)
        if child == nil and value ~= nil then return nil end
        out[key] = child
    end
    seen[v] = nil
    return out
end
local function recordOf(person)
    if type(person) == "table" then return person end
    if SAO.Identity and type(SAO.Identity.get) == "function" then return SAO.Identity.get(person) end
    return nil
end
local function bindingValid(bindings)
    if type(bindings) ~= "table" then return false end
    local count = 0
    for _, key in ipairs(BINDINGS) do if not hash(bindings[key]) then return false end end
    for key in pairs(bindings) do
        local allowed = false
        for _, candidate in ipairs(BINDINGS) do if key == candidate then allowed = true end end
        if not allowed then return false end
        count = count + 1
    end
    return count == #BINDINGS
end
local function bindingMatches(left, right)
    if not bindingValid(left) or not bindingValid(right) then return false end
    for _, key in ipairs(BINDINGS) do if left[key] ~= right[key] then return false end end
    return true
end
local function clockValid(tick)
    return finite(tick) and tick >= 0 and tick <= 1e12 and SAO.History
        and SAO.History.TICKS_PER_DAY == TICKS_PER_DAY
end
local function fields(line)
    local out = {}
    for item in string.gmatch(line .. "\t", "(.-)\t") do out[#out + 1] = item end
    return out
end
local function decode(value)
    if type(value) ~= "string" or #value > 262144 then return nil end
    local ok, decoded = pcall(function() return SAOJavaBridge:educationDecode(value) end)
    if not ok or type(decoded) ~= "string" then return nil end
    return decoded
end
local function parseWire(wire, rawSha, tick)
    if type(wire) ~= "string" or #wire > 3 * MAX_BYTES then return nil, "education-wire-unavailable" end
    local lines = {}
    for line in string.gmatch(wire .. "\n", "(.-)\n") do lines[#lines + 1] = line end
    local head = fields(lines[1] or "")
    if head[1] == "SAO_EDUCATION_REFUSED_2" then return nil, "education-prior-refused" end
    if #head ~= 9 or head[1] ~= "SAO_EDUCATION_VIEW_2" or head[2] ~= rawSha
        or not hash(head[3]) or not hash(head[4]) or not hash(head[9]) then return nil, "education-wire-binding" end
    local asOf, observed, omitted, count = tonumber(head[5]), tonumber(head[6]), tonumber(head[7]), tonumber(head[8])
    if not finite(asOf) or asOf < 0 or asOf > tick or observed ~= tick
        or not integer(omitted, 1000000) or not integer(count, 128) or #lines ~= count + 1 then
        return nil, "education-wire-time-or-bound"
    end
    local result = { schemaVersion = 2, contentSha256 = head[3], ledgerSha256 = head[4],
        rawSha256 = rawSha, policySha256 = head[9], asOfCountyTick = asOf,
        observedCountyTick = observed, omittedConcepts = omitted, concepts = {},
        standing = "source-reconstructed-conceptual-conditioning", coverage = "bounded-imported-concepts" }
    for _, key in ipairs(AUTHORITIES) do result[key] = false end
    local ids = {}
    for i = 2, #lines do
        local row = fields(lines[i])
        if #row ~= 19 then return nil, "education-wire-row" end
        local concept = { id = decode(row[1]), sourceId = decode(row[2]), sourceVersion = decode(row[3]),
            sourcePath = decode(row[4]), sourceSha256 = row[5], exerciseId = decode(row[6]),
            conceptRefJson = decode(row[7]), courseUnitsJson = decode(row[8]),
            familiarity = tonumber(row[9]), retention = tonumber(row[10]), priming = tonumber(row[11]),
            calibration = { estimatedCorrectness = tonumber(row[12]), correct = tonumber(row[13]),
                incorrect = tonumber(row[14]), unknown = tonumber(row[15]) },
            independentSuccesses = tonumber(row[16]), assistedSuccesses = tonumber(row[17]),
            usageCount = tonumber(row[18]), lastDay = tonumber(row[19]) }
        for _, key in ipairs({ "id", "sourceId", "sourceVersion", "sourcePath", "exerciseId", "conceptRefJson", "courseUnitsJson" }) do
            if type(concept[key]) ~= "string" or concept[key] == "" then return nil, "education-wire-text" end
        end
        if ids[concept.id] or not hash(concept.sourceSha256) then return nil, "education-wire-source" end
        ids[concept.id] = true
        for j = 9, 12 do
            local v = tonumber(row[j])
            if not finite(v) or v < 0 or v > 1 then return nil, "education-wire-probability" end
        end
        for j = 13, 18 do
            local v = tonumber(row[j])
            if not integer(v, 4096) then return nil, "education-wire-counter" end
        end
        if not finite(concept.lastDay) or concept.lastDay ~= tick / TICKS_PER_DAY then return nil, "education-wire-event-time" end
        result.concepts[#result.concepts + 1] = concept
    end
    return result
end
local function validate(rec, rawJson, rawSha, bindings, tick, query)
    if type(rec) ~= "table" or type(rec.id) ~= "string" or rec.id == "" then return nil, "education-person-unavailable" end
    if type(rawJson) ~= "string" or #rawJson == 0 or #rawJson > MAX_BYTES or not hash(rawSha)
        or not bindingValid(bindings) or not clockValid(tick) then return nil, "education-input-binding" end
    local ok, wire = pcall(function()
        if query then
            return SAOJavaBridge:educationQuery(rawJson, rawSha, rec.id, bindings.profileSha256,
                bindings.sourceBankSha256, bindings.backgroundsSha256, bindings.personEducationSha256,
                bindings.educationalExposuresSha256, bindings.sourceArchiveSha256, tick)
        end
        return SAOJavaBridge:educationValidate(rawJson, rawSha, rec.id, bindings.profileSha256,
            bindings.sourceBankSha256, bindings.backgroundsSha256, bindings.personEducationSha256,
            bindings.educationalExposuresSha256, bindings.sourceArchiveSha256, tick)
    end)
    if not ok then return nil, "education-validator-unavailable" end
    return parseWire(wire, rawSha, tick)
end
local function savedValid(state)
    if type(state) ~= "table" or state.schemaVersion ~= 2 or state.owner ~= "SAO.Education"
        or type(state.personId) ~= "string" or not integer(state.revision, 2147483647)
        or state.revision < 1 or not bindingValid(state.bindings) or not hash(state.rawSha256)
        or not hash(state.contentSha256) or not hash(state.ledgerSha256) or not hash(state.policySha256)
        or (type(state.rawPayload) ~= "string" and type(state.rawPayload) ~= "table")
        or not finite(state.asOfCountyTick) or not finite(state.importedAtCountyTick)
        or state.importedAtCountyTick < state.asOfCountyTick then return false end
    local allowed = { schemaVersion = true, owner = true, personId = true, revision = true, bindings = true,
        rawPayload = true, rawSha256 = true, contentSha256 = true, ledgerSha256 = true, policySha256 = true,
        asOfCountyTick = true, importedAtCountyTick = true }
    local count = 0
    for key in pairs(state) do if not allowed[key] then return false end; count = count + 1 end
    return count == 12
end
local function unpackPayload(state)
    local ok, raw = pcall(function() return SAOJavaBridge:educationUnpack(state.rawPayload) end)
    if not ok or type(raw) ~= "string" or #raw == 0 or #raw > MAX_BYTES then return nil end
    return raw
end

-- Expected bindings come from the current world/person/source owners, separately from the payload.
function E.import(person, rawJson, rawSha, bindings, tick)
    local rec = recordOf(person)
    local candidate, why = validate(rec, rawJson, rawSha, bindings, tick, false)
    if not candidate then return false, why end
    local previous, revision = rec.education, 1
    if previous ~= nil then
        if not savedValid(previous) or previous.personId ~= rec.id or not bindingMatches(previous.bindings, bindings)
            then return false, "education-saved-binding" end
        local previousRaw = unpackPayload(previous)
        local older = validate(rec, previousRaw, previous.rawSha256, bindings, tick, true)
        if not older or older.contentSha256 ~= previous.contentSha256 or older.ledgerSha256 ~= previous.ledgerSha256
            or older.policySha256 ~= previous.policySha256 or older.asOfCountyTick ~= previous.asOfCountyTick
            then return false, "education-saved-provenance" end
        if previous.rawSha256 == rawSha and previousRaw == rawJson then return true, "unchanged", previous.revision end
        if candidate.asOfCountyTick <= previous.asOfCountyTick then return false, "education-replayed-time" end
        if previous.revision >= 2147483647 then return false, "education-revision-bound" end
        revision = previous.revision + 1
    end
    local packedOk, packed = pcall(function() return SAOJavaBridge:educationPack(rawJson) end)
    if not packedOk or (type(packed) ~= "string" and type(packed) ~= "table") then return false, "education-persistence-unavailable" end
    local roundtrip = unpackPayload({ rawPayload = packed })
    if roundtrip ~= rawJson then return false, "education-persistence-differs" end
    local state = { schemaVersion = 2, owner = "SAO.Education", personId = rec.id, revision = revision,
        bindings = plainCopy(bindings), rawPayload = packed, rawSha256 = rawSha,
        contentSha256 = candidate.contentSha256, ledgerSha256 = candidate.ledgerSha256,
        policySha256 = candidate.policySha256, asOfCountyTick = candidate.asOfCountyTick,
        importedAtCountyTick = tick }
    rec.education = state
    return true, "imported", revision
end

-- A read never creates a record, ages a saved state, or credits use/learning.
function E.query(person, bindings, tick)
    local rec = recordOf(person)
    if not rec then return nil, "education-person-unavailable" end
    if rec.education == nil then return nil, "education-prior-unknown" end
    local state = rec.education
    if not savedValid(state) or state.personId ~= rec.id or not bindingMatches(state.bindings, bindings)
        or not clockValid(tick) or tick < state.importedAtCountyTick then return nil, "education-saved-binding" end
    local raw = unpackPayload(state)
    local result, why = validate(rec, raw, state.rawSha256, bindings, tick, true)
    if not result then return nil, why end
    if result.contentSha256 ~= state.contentSha256 or result.ledgerSha256 ~= state.ledgerSha256
        or result.policySha256 ~= state.policySha256 or result.asOfCountyTick ~= state.asOfCountyTick
        then return nil, "education-saved-provenance" end
    result.personId = rec.id; result.importRevision = state.revision
    result.contextRefs = plainCopy(bindings)
    return result
end

function E.snapshot(person)
    local rec = recordOf(person)
    if not rec or not savedValid(rec.education) or rec.education.personId ~= rec.id or not unpackPayload(rec.education) then return nil end
    return plainCopy(rec.education)
end

-- Lifecycle owner supplies a fresh provider for the current world; the callback is never saved.
function E.registerBindingsProvider(provider)
    if provider ~= nil and type(provider) ~= "function" then return false end
    bindingsProvider = provider
    return true
end

function E.conditioning(person, tick)
    local rec = recordOf(person)
    if not rec or type(rec.id) ~= "string" then return nil, "education-person-unavailable" end
    if not bindingsProvider then return nil, "education-bindings-unavailable" end
    local ok, bindings = pcall(bindingsProvider, rec.id)
    if not ok or not bindingValid(bindings) then return nil, "education-bindings-unavailable" end
    return E.query(rec, bindings, tick)
end

-- A schooling exposure is a defeasible background premise. It has no assessed
-- retention, native skill or current-world authority. Reads never learn it anew.
function E.backgroundRelations(id)
    local rec=type(id)=="string" and SAO.Identity and SAO.Identity.get(id)
    local registry=SAO.EducationRegistry
    if not rec or rec.id~=id or rec.dead or not registry or not registry.backgroundRelations
        or not SAO.History or type(SAO.History.ticks)~="function" then return nil end
    if type(registry.profile)~="function" or type(SAO.History.birthYearOf)~="function" then return nil end
    local known,profile,birth=pcall(function() return registry.profile(id),SAO.History.birthYearOf(id) end)
    if not known or not profile or not finite(birth) or birth~=profile.birthYear then return nil end
    local tick=SAO.History.ticks()
    if not E.conditioning(id,tick) then return nil end
    return registry.backgroundRelations(id,tick)
end

local function exactFields(value, allowed)
    if type(value) ~= "table" then return false end
    local expected, actual = 0, 0
    for key in pairs(allowed) do expected = expected + 1; if value[key] == nil then return false end end
    for key in pairs(value) do if not allowed[key] then return false end; actual = actual + 1 end
    return expected == actual
end

-- This checks a detached view's shape and reference integrity. Its caller still acquires
-- the view through conditioning's current owner, rather than trusting an arbitrary table.
function E.copyConditioning(view)
    local allowed = { schemaVersion = true, contentSha256 = true, ledgerSha256 = true, rawSha256 = true,
        policySha256 = true, asOfCountyTick = true, observedCountyTick = true, omittedConcepts = true,
        concepts = true, standing = true, coverage = true, personId = true, importRevision = true, contextRefs = true }
    for _, key in ipairs(AUTHORITIES) do allowed[key] = true end
    if not exactFields(view, allowed) or view.schemaVersion ~= 2
        or view.standing ~= "source-reconstructed-conceptual-conditioning"
        or view.coverage ~= "bounded-imported-concepts" or type(view.personId) ~= "string" or view.personId == ""
        or #view.personId > 32768 or not integer(view.importRevision, 2147483647) or view.importRevision < 1
        or not bindingValid(view.contextRefs) or not clockValid(view.observedCountyTick)
        or not finite(view.asOfCountyTick) or view.asOfCountyTick < 0 or view.asOfCountyTick > view.observedCountyTick
        or not integer(view.omittedConcepts, 1000000) or type(view.concepts) ~= "table" or #view.concepts > 128 then return nil end
    for _, key in ipairs({ "contentSha256", "ledgerSha256", "rawSha256", "policySha256" }) do if not hash(view[key]) then return nil end end
    for _, key in ipairs(AUTHORITIES) do if view[key] ~= false then return nil end end
    local count = 0
    for key in pairs(view.concepts) do
        if not integer(key, 128) or key < 1 or key > #view.concepts then return nil end
        count = count + 1
    end
    if count ~= #view.concepts then return nil end
    local ids = {}
    local conceptFields = { id = true, sourceId = true, sourceVersion = true, sourcePath = true, sourceSha256 = true,
        exerciseId = true, conceptRefJson = true, courseUnitsJson = true, familiarity = true, retention = true,
        priming = true, calibration = true, independentSuccesses = true, assistedSuccesses = true, usageCount = true, lastDay = true }
    for _, concept in ipairs(view.concepts) do
        if not exactFields(concept, conceptFields) or not exactFields(concept.calibration,
            { estimatedCorrectness = true, correct = true, incorrect = true, unknown = true }) then return nil end
        for _, key in ipairs({ "id", "sourceId", "sourceVersion", "sourcePath", "exerciseId", "conceptRefJson", "courseUnitsJson" }) do
            if type(concept[key]) ~= "string" or concept[key] == "" or #concept[key] > 262144 then return nil end
        end
        if string.sub(concept.id, 1, 16) ~= "source-exercise:" or not hash(string.sub(concept.id, 17))
            or ids[concept.id] or not hash(concept.sourceSha256) then return nil end
        ids[concept.id] = true
        for _, key in ipairs({ "familiarity", "retention", "priming" }) do
            if not finite(concept[key]) or concept[key] < 0 or concept[key] > 1 then return nil end
        end
        local calibration = concept.calibration
        if not finite(calibration.estimatedCorrectness) or calibration.estimatedCorrectness < 0 or calibration.estimatedCorrectness > 1
            or not integer(calibration.correct, 4096) or not integer(calibration.incorrect, 4096)
            or not integer(calibration.unknown, 4096) or not integer(concept.independentSuccesses, 4096)
            or not integer(concept.assistedSuccesses, 4096) or not integer(concept.usageCount, 4096)
            or concept.independentSuccesses > calibration.correct
            or (concept.usageCount > 0 and concept.independentSuccesses == 0)
            or math.abs(calibration.estimatedCorrectness - (1 + calibration.correct) / (2 + calibration.correct + calibration.incorrect)) > 1e-14
            or not finite(concept.lastDay) or concept.lastDay ~= view.observedCountyTick / TICKS_PER_DAY then return nil end
        local ok, consistent = pcall(function()
            return SAOJavaBridge:educationCheckConcept(concept.conceptRefJson, concept.courseUnitsJson,
                concept.id, concept.sourceId, concept.sourceVersion, concept.sourcePath, concept.sourceSha256, concept.exerciseId)
        end)
        if not ok or consistent ~= true then return nil end
    end
    return plainCopy(view)
end

-- The feedback producer names the prior it consumed. The caller supplies the
-- current bindings and clock independently, before acknowledging its receipt.
function E.applyFeedbackPrior(person, rawJson, rawSha, request, bindings, tick)
    local allowed = { owner = true, personId = true, bindings = true,
        expectedPreviousRevision = true, expectedPreviousRawSha256 = true,
        expectedPreviousLedgerSha256 = true, proposedRevision = true,
        asOfCountyTick = true, importedAtCountyTick = true, rawPriorSha256 = true,
        contentSha256 = true, ledgerSha256 = true, policySha256 = true }
    local rec = recordOf(person)
    if not exactFields(request, allowed) or not rec or request.owner ~= "SAO.Education"
        or request.personId ~= rec.id or not bindingMatches(request.bindings, bindings)
        or not clockValid(tick) or not finite(request.asOfCountyTick) or request.asOfCountyTick < 0
        or request.asOfCountyTick > tick or request.importedAtCountyTick ~= request.asOfCountyTick
        or not integer(request.expectedPreviousRevision, 2147483646) or request.expectedPreviousRevision < 1
        or request.proposedRevision ~= request.expectedPreviousRevision + 1
        or request.rawPriorSha256 ~= rawSha then return false, "education-feedback-request" end
    for _, key in ipairs({ "expectedPreviousRawSha256", "expectedPreviousLedgerSha256",
        "rawPriorSha256", "contentSha256", "ledgerSha256", "policySha256" }) do
        if not hash(request[key]) then return false, "education-feedback-request" end
    end
    local candidate, why = validate(rec, rawJson, rawSha, bindings, tick, false)
    if not candidate then return false, why end
    if candidate.contentSha256 ~= request.contentSha256 or candidate.ledgerSha256 ~= request.ledgerSha256
        or candidate.policySha256 ~= request.policySha256 or candidate.asOfCountyTick ~= request.asOfCountyTick
        then return false, "education-feedback-payload" end
    local previous = E.query(rec, bindings, tick)
    if not previous then return false, "education-feedback-previous-unavailable" end
    if previous.importRevision == request.proposedRevision and previous.rawSha256 == rawSha
        and previous.contentSha256 == request.contentSha256 and previous.ledgerSha256 == request.ledgerSha256
        and previous.policySha256 == request.policySha256 and previous.asOfCountyTick == request.asOfCountyTick
        then return true, "unchanged", previous.importRevision end
    if request.importedAtCountyTick ~= tick then return false, "education-feedback-stale-clock" end
    if previous.importRevision ~= request.expectedPreviousRevision
        or previous.rawSha256 ~= request.expectedPreviousRawSha256
        or previous.ledgerSha256 ~= request.expectedPreviousLedgerSha256
        then return false, "education-feedback-stale-previous" end
    return E.import(rec, rawJson, rawSha, bindings, tick)
end
