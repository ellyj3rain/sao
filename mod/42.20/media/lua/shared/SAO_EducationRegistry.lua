-- Explicit source-produced profiles and education priors for one current world.
-- Staging validates every row before publishing; attachment requires a real person ID.
SAO = SAO or {}
SAO.EducationRegistry = SAO.EducationRegistry or {}
local R = SAO.EducationRegistry
local current = nil
local MAX_BYTES = 16 * 1024 * 1024
local MAX_ROWS = 128

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
local function hash(v)
    return type(v) == "string" and #v == 64 and not string.find(v, "[^a-f0-9]")
end
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}; for k, child in pairs(v) do out[k] = copy(child) end; return out
end
local function fields(line)
    local out = {}; for v in string.gmatch(line .. "\t", "(.-)\t") do out[#out + 1] = v end; return out
end
local function decoded(value)
    local ok, result = pcall(function() return SAOJavaBridge:educationRegistryDecode(value) end)
    return ok and type(result) == "string" and result or nil
end
local function boundInputs(rawSha, worldSha, bankSha, archiveSha, tick)
    return hash(rawSha) and hash(worldSha) and hash(bankSha) and hash(archiveSha)
        and finite(tick) and tick >= 0 and tick <= 1e12
        and SAO.History and SAO.History.TICKS_PER_DAY == 216000
end
local function backgroundRows(wire,id,profileSha,rowSha,authored)
    local rows={}
    if wire=="" then return rows end
    if type(wire)~="string" or #wire>262144 then return nil end
    for line in string.gmatch(wire.."\n","(.-)\n") do
        local columns=fields(line)
        if (#columns~=18 and not (authored and #columns==24)) or #rows>=32 then return nil end
        local f={}
        for index,value in ipairs(columns) do
            f[index]=decoded(value)
            if not f[index] or f[index]=="" then return nil end
        end
        local start,ended,admitted=tonumber(f[12]),tonumber(f[13]),tonumber(f[17])
        if not finite(start) or not finite(ended) or not finite(admitted) then return nil end
        local edge={id="education-background/"..f[1],actorId=id,
            from=f[2],relation=f[3],into=f[4],affirmed=true,modal=true,
            basis="generated-schooling-exposure",sourceId=f[5],sourceVersion=f[6],
            sourcePath=f[7],sourceExcerptSha256=f[8],sourceUnitId=f[9],curriculumSha256=f[10],
            exposureReceiptSha256=f[11],exposureStartYear=start,exposureEndYear=ended,
            sourceRegionId=f[14],sourceCohortId=f[15],sourceInstitutionId=f[16],
            admittedAtTick=admitted,statementSha256=f[18],profileSha256=profileSha,registryRowSha256=rowSha,
            conditions={"suitable-food","usable-heating-means","permission"},
            retention="unassessed",origin="source-bound-generated-person-history"}
        if #columns==24 then
            if f[19]~="authored-work-training-exposure" and f[19]~="authored-community-literary-exposure" then return nil end
            if f[21]~="descriptive-possibility" and f[21]~="reported-norm" then return nil end
            if not hash(f[23]) then return nil end
            edge.basis,edge.conditions,edge.contentRole=f[19],{},f[21]
            for condition in string.gmatch(f[20],"[^;]+") do edge.conditions[#edge.conditions+1]=condition end
            edge.exposureEventId,edge.contentExposureHistorySha256,edge.acquisitionChannel=f[22],f[23],f[24]
            edge.carrierId=f[16]
            edge.sourceCohortId,edge.sourceInstitutionId=nil,nil
            edge.assent="not-established"
            edge.origin="source-bound-authored-person-history"
        end
        rows[#rows+1]=edge
    end
    return rows
end
local function parse(wire, rawSha, worldSha, bankSha, archiveSha)
    if type(wire) ~= "string" or #wire > 3 * MAX_BYTES then return nil, "education-registry-unavailable" end
    local lines = {}; for line in string.gmatch(wire .. "\n", "(.-)\n") do lines[#lines + 1] = line end
    local head = fields(lines[1] or "")
    local count = tonumber(head[7])
    local authored=head[1]=="SAO_EDUCATION_REGISTRY_3"
    local background=authored or head[1]=="SAO_EDUCATION_REGISTRY_2"
    if #head ~= 8 or not (background or head[1] == "SAO_EDUCATION_REGISTRY_1") or head[2] ~= rawSha or not hash(head[3])
        or head[4] ~= worldSha or head[5] ~= bankSha or head[6] ~= archiveSha
        or not finite(count) or count < 1 or count > MAX_ROWS or count ~= math.floor(count) or #lines ~= count + 1 then
        return nil, "education-registry-binding"
    end
    local owner = decoded(head[8]); if not owner or owner == "" then return nil, "education-registry-owner" end
    local state = { schemaVersion = 1, rawSha256 = rawSha, contentSha256 = head[3], worldDefinitionSha256 = worldSha,
        sourceBankSha256 = bankSha, sourceArchiveSha256 = archiveSha, worldOwnerJson = owner, rows = {} }
    for index = 2, #lines do
        local row = fields(lines[index])
        if #row ~= (background and 14 or 13) then return nil, "education-registry-row" end
        local id, profile, raw = decoded(row[1]), decoded(row[8]), decoded(row[10])
        local birth, asOfYear = tonumber(row[4]), tonumber(row[5])
        local birthRegion, currentRegion = decoded(row[6]), decoded(row[7])
        if not id or id == "" or #id > 32768 or state.rows[id] or not profile or not raw or #raw > 2 * 1024 * 1024
            or not finite(birth) or birth ~= math.floor(birth) or birth < 1700 or birth > 1993
            or not finite(asOfYear) or asOfYear ~= math.floor(asOfYear) or asOfYear < birth or asOfYear > 1993
            or not birthRegion or birthRegion == "" or not currentRegion or currentRegion == "" then
            return nil, "education-registry-profile"
        end
        for _, offset in ipairs({ 2, 3, 9, 11, 12, 13 }) do if not hash(row[offset]) then return nil, "education-registry-row-hash" end end
        local roots=backgroundRows(background and decoded(row[14]) or "",id,row[3],row[2],authored)
        if not roots then return nil,"education-registry-background" end
        state.rows[id] = { personId = id, rowSha256 = row[2], profileSha256 = row[3], birthYear = birth,
            asOfYear = asOfYear, birthRegionId = birthRegion, currentRegionId = currentRegion,
            sourceProfileJson = profile, rawPriorSha256 = row[9], rawPriorJson = raw, backgroundRelations=roots,
            bindings = { worldSha256 = worldSha, profileSha256 = row[3], sourceBankSha256 = bankSha,
                backgroundsSha256 = row[11], personEducationSha256 = row[12], educationalExposuresSha256 = row[13],
                sourceArchiveSha256 = archiveSha } }
    end
    return state
end
local function checked(raw, rawSha, worldSha, bankSha, archiveSha, tick)
    if type(raw) ~= "string" or #raw == 0 or #raw > MAX_BYTES or not boundInputs(rawSha, worldSha, bankSha, archiveSha, tick) then
        return nil, "education-registry-input"
    end
    local ok, wire = pcall(function()
        return SAOJavaBridge:educationCheckedRegistry(raw, rawSha, worldSha, bankSha, archiveSha, tick)
    end)
    if not ok then return nil, "education-registry-validator-unavailable" end
    return parse(wire, rawSha, worldSha, bankSha, archiveSha)
end
local function sameCurrent(rawSha, worldSha, bankSha, archiveSha)
    return not current or (current.rawSha256 == rawSha and current.worldDefinitionSha256 == worldSha
        and current.sourceBankSha256 == bankSha and current.sourceArchiveSha256 == archiveSha)
end
local function registered(provider)
    local education = SAO.Education
    if type(education) ~= "table" or type(education.registerBindingsProvider) ~= "function" then
        return false, "education-registry-provider-unavailable"
    end
    local ok, accepted = pcall(education.registerBindingsProvider, provider)
    if not ok or accepted ~= true then return false, "education-registry-provider-refused" end
    return true
end
local function publish(state)
    local ok, why = registered(function(id) return R.currentBindings(id) end)
    if not ok then return false, why end
    current = state
    return true
end
local function persistedValid(state, rawSha, worldSha, bankSha, archiveSha)
    if type(state) ~= "table" or state.schemaVersion ~= 1 or state.owner ~= "SAO.EducationRegistry"
        or state.rawSha256 ~= rawSha or state.worldDefinitionSha256 ~= worldSha or state.sourceBankSha256 ~= bankSha
        or state.sourceArchiveSha256 ~= archiveSha or not hash(state.contentSha256)
        or not finite(state.revision) or state.revision ~= math.floor(state.revision) or state.revision ~= 1 then return false end
    local allowed = { schemaVersion = true, owner = true, rawSha256 = true, contentSha256 = true,
        worldDefinitionSha256 = true, sourceBankSha256 = true, sourceArchiveSha256 = true,
        rawPayload = true, revision = true }
    local count = 0; for key in pairs(state) do if not allowed[key] then return false end; count = count + 1 end
    return count == 9
end
local function unpacked(payload)
    local ok, raw = pcall(function() return SAOJavaBridge:educationRegistryUnpack(payload) end)
    return ok and type(raw) == "string" and #raw <= MAX_BYTES and raw or nil
end

function R.load(worldRecord, raw, rawSha, worldSha, bankSha, archiveSha, tick)
    if type(worldRecord) ~= "table" or not sameCurrent(rawSha, worldSha, bankSha, archiveSha) then
        return false, "education-registry-world-conflict"
    end
    local candidate, why = checked(raw, rawSha, worldSha, bankSha, archiveSha, tick)
    if not candidate then return false, why end
    local previous = worldRecord.educationRegistry
    if previous ~= nil then
        if not persistedValid(previous, rawSha, worldSha, bankSha, archiveSha) or previous.contentSha256 ~= candidate.contentSha256
            or unpacked(previous.rawPayload) ~= raw then return false, "education-registry-saved-conflict" end
        local ok, why = publish(candidate)
        if not ok then return false, why end
        return true, "unchanged"
    end
    local ok, packed = pcall(function() return SAOJavaBridge:educationRegistryPack(raw) end)
    if not ok or packed == nil or unpacked(packed) ~= raw then return false, "education-registry-persistence-unavailable" end
    local saved = { schemaVersion = 1, owner = "SAO.EducationRegistry", rawSha256 = rawSha,
        contentSha256 = candidate.contentSha256, worldDefinitionSha256 = worldSha, sourceBankSha256 = bankSha,
        sourceArchiveSha256 = archiveSha, rawPayload = packed, revision = 1 }
    local accepted, why = publish(candidate)
    if not accepted then return false, why end
    worldRecord.educationRegistry = saved
    return true, "staged"
end

-- Restore needs the current source owner's expected hashes, independently from the saved envelope.
function R.bind(worldRecord, expectedRegistrySha, worldSha, bankSha, archiveSha, tick)
    if type(worldRecord) ~= "table" or not boundInputs(expectedRegistrySha, worldSha, bankSha, archiveSha, tick)
        or not persistedValid(worldRecord.educationRegistry, expectedRegistrySha, worldSha, bankSha, archiveSha)
        or not sameCurrent(expectedRegistrySha, worldSha, bankSha, archiveSha) then return false, "education-registry-saved-binding" end
    local raw = unpacked(worldRecord.educationRegistry.rawPayload)
    local candidate, why = checked(raw, expectedRegistrySha, worldSha, bankSha, archiveSha, tick)
    if not candidate or candidate.contentSha256 ~= worldRecord.educationRegistry.contentSha256 then
        return false, why or "education-registry-saved-provenance"
    end
    local ok, why = publish(candidate)
    if not ok then return false, why end
    return true, "bound"
end

function R.clear()
    current = nil
    registered(nil)
end

function R.currentBindings(id)
    local row = current and current.rows[id]
    return row and copy(row.bindings) or nil
end
-- A current registry alone is insufficient: Education validates the retained
-- exact person's imported prior before exposing these generated-history roots.
function R.backgroundRelations(id,tick)
    local row=current and current.rows[id]
    if not row or not finite(tick) then return nil end
    local roots={}
    for _,edge in ipairs(row.backgroundRelations) do
        if edge.admittedAtTick>tick then return nil end
        local result=copy(edge)
        result.worldSha256=current.worldDefinitionSha256
        result.sourceArchiveSha256=current.sourceArchiveSha256
        roots[#roots+1]=result
    end
    return roots
end

function R.profile(id)
    local row = current and current.rows[id]
    if not row then return nil end
    return { personId = row.personId, profileSha256 = row.profileSha256, birthYear = row.birthYear,
        asOfYear = row.asOfYear, birthRegionId = row.birthRegionId, currentRegionId = row.currentRegionId,
        sourceProfileJson = row.sourceProfileJson, rowSha256 = row.rowSha256 }
end

function R.attach(person, tick, nativeBirthYear)
    local rec = type(person) == "table" and person or (SAO.Identity and SAO.Identity.get and SAO.Identity.get(person))
    if type(rec) ~= "table" or type(rec.id) ~= "string" then return false, "education-registry-person-unavailable" end
    local row = current and current.rows[rec.id]
    if not row then return false, "education-registry-person-unknown" end
    if not finite(nativeBirthYear) or nativeBirthYear ~= math.floor(nativeBirthYear) or nativeBirthYear ~= row.birthYear then
        return false, "education-registry-birth-mismatch"
    end
    if rec.education ~= nil then
        local view = SAO.Education.query(rec, copy(row.bindings), tick)
        if not view then return false, "education-registry-existing-person-prior-refused" end
        return true, "retained-person-prior"
    end
    return SAO.Education.import(rec, row.rawPriorJson, row.rawPriorSha256, copy(row.bindings), tick)
end
