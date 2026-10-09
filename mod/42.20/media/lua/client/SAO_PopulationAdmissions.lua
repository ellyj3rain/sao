-- PopulationAdmissions - origins, genesis and later admissions.

SAO = SAO or {}
SAO.PopulationAdmissions = SAO.PopulationAdmissions or {}
local A = SAO.PopulationAdmissions
local function log(msg) SAO.Log.line("POP", msg) end
local function tally(kind) SAO.Log.tally("POP", kind) end
local function hoursNow()
    local ok, h = pcall(function() return SAO.History.countyHours() end)
    return ok and h or 0
end

local regionPoints = nil
local regionPointsByProfession = nil
local regionWorkPoints = nil
local lastHighwayLogAt = -9
local initialCohort = nil
local awarenessProviderBound = false
local memoryProviderBound = false
local memorySourcePins = nil
local function integer(v, low, high)
    return type(v) == "number" and v == v and v >= low and v <= high and v % 1 == 0
end
local function siteFor(point, sites)
    local nearest, distance = nil, 48 * 48
    for _, site in ipairs(sites) do
        if point.z == site.z then
            local dx, dy = point.x - site.x, point.y - site.y
            local candidate = dx * dx + dy * dy
            if candidate < distance then nearest, distance = site.id, candidate
            elseif candidate == distance then nearest = nil end
        end
    end
    return nearest
end
local function cohortCounts(cohort)
    local records, counts, seen = SAO.Identity.all(), {}, {}
    for _, site in ipairs(cohort.sites) do
        local ids = cohort.actualIds[site.id]
        if type(ids) ~= "table" then return nil, "initial-cohort-id-ledger-missing" end
        counts[site.id] = 0
        for _, id in ipairs(ids) do
            local rec = records[id]
            local origin = rec and rec.initialStudyOrigin
            if seen[id] or not origin or origin.definitionSha256 ~= cohort.definitionSha256
                or origin.saveName ~= cohort.saveName or origin.siteId ~= site.id
                or siteFor(origin, cohort.sites) ~= site.id then
                return nil, "initial-cohort-identity-provenance-differs"
            end
            seen[id], counts[site.id] = true, counts[site.id] + 1
        end
        if counts[site.id] > cohort.requested[site.id] then return nil, "initial-cohort-site-overflow" end
    end
    for id, rec in pairs(records) do
        local origin = rec.initialStudyOrigin
        if origin and origin.definitionSha256 == cohort.definitionSha256
            and origin.saveName == cohort.saveName and not seen[id] then
            return nil, "initial-cohort-identity-unregistered"
        end
    end
    return counts
end
-- Study authoring precedes this owner's ordinary identity/history genesis.
-- Durable actual IDs, rather than requested totals, establish generated counts.
function A.stageInitialPeople(definitionSha256, saveName, requested, sites, population)
    if type(definitionSha256) ~= "string" or #definitionSha256 ~= 64
        or definitionSha256:find("[^a-f0-9]") or type(saveName) ~= "string" or #saveName == 0
        or type(requested) ~= "table" or type(sites) ~= "table" or #sites < 1 or #sites > 4
        or not integer(population, 1, 500) then return false, "invalid-initial-cohort-binding" end
    local allSites, total, known = {}, 0, {}
    for _, site in ipairs(sites) do
        if type(site.id) ~= "string" or known[site.id]
            or not integer(site.x, -75000, 75299) or not integer(site.y, -75000, 75299)
            or not integer(site.z, -32, 31) then return false, "invalid-initial-cohort-site" end
        known[site.id] = true
        if requested[site.id] ~= nil then
            if not integer(requested[site.id], 1, 500) then return false, "invalid-initial-cohort-count" end
            total = total + requested[site.id]
        end
        allSites[#allSites + 1] = { id = site.id, x = site.x, y = site.y, z = site.z }
    end
    for id in pairs(requested) do if not known[id] then return false, "unknown-initial-cohort-site" end end
    if total ~= population then return false, "initial-cohort-population-differs" end
    local store = ModData.getOrCreate("SurvivorAwareness_Standing")
    local prior = store.initialStudyPeople
    if prior then
        if prior.definitionSha256 ~= definitionSha256 or prior.saveName ~= saveName
            or prior.target ~= population or #prior.sites ~= #allSites then
            return false, "initial-cohort-binding-differs"
        end
        for i, site in ipairs(allSites) do
            local previous = prior.sites[i]
            if previous.id ~= site.id or previous.x ~= site.x or previous.y ~= site.y
                or previous.z ~= site.z or prior.requested[site.id] ~= (requested[site.id] or 0) then
                return false, "initial-cohort-definition-differs"
            end
        end
        local counts, reason = cohortCounts(prior)
        if not counts then return false, reason end
        initialCohort = prior
        return true
    end
    local existingPeople = false
    for _ in pairs(SAO.Identity.all()) do existingPeople = true; break end
    if store.countySettled or existingPeople then return false, "initial-cohort-staged-after-genesis" end
    local cohort = { definitionSha256 = definitionSha256, saveName = saveName,
        target = population, requested = {}, sites = allSites, actualIds = {}, status = "staged" }
    for _, site in ipairs(allSites) do
        cohort.requested[site.id] = requested[site.id] or 0
        cohort.actualIds[site.id] = {}
    end
    store.initialStudyPeople, initialCohort = cohort, cohort
    return true
end
function A.initialPeopleSnapshot()
    if not initialCohort then return nil end
    local counts, reason = cohortCounts(initialCohort)
    assert(counts, reason)
    local result = { definitionSha256 = initialCohort.definitionSha256, saveName = initialCohort.saveName,
        target = initialCohort.target, status = initialCohort.status, reason = initialCohort.reason,
        generated = 0, represented = 0, sites = {} }
    for _, site in ipairs(initialCohort.sites) do
        local row = { requested = initialCohort.requested[site.id],
            generated = counts[site.id], represented = 0, actualIds = {}, placement = {} }
        for _, id in ipairs(initialCohort.actualIds[site.id]) do
            row.actualIds[#row.actualIds + 1] = id
            if SAO.Body.get(id) then row.represented = row.represented + 1 end
            local receipt = SAO.Identity.all()[id].initialStudyPlacement
            if receipt and receipt.definitionSha256 == initialCohort.definitionSha256
                and receipt.saveName == initialCohort.saveName and receipt.siteId == site.id then
                row.placement[id] = { status = receipt.status, reason = receipt.reason,
                    causeAvailable = receipt.causeAvailable, observedAtCountyHours = receipt.observedAtCountyHours }
            else
                row.placement[id] = { status = "unobserved", causeAvailable = false }
            end
        end
        result.generated = result.generated + row.generated
        result.represented = result.represented + row.represented
        result.sites[site.id] = row
    end
    return result
end
local function educationWorld(definitionSha256, saveName)
    if not initialCohort or initialCohort.definitionSha256 ~= definitionSha256
        or initialCohort.saveName ~= saveName then return nil, "education-world-definition-unavailable" end
    return ModData.getOrCreate("SurvivorAwareness_Standing")
end

-- The authored source package supplies independent current-world and source pins.
function A.stageEducationRegistry(raw, rawSha, definitionSha256, saveName, bankSha, archiveSha)
    local store, why = educationWorld(definitionSha256, saveName)
    if not store then return false, why end
    if not SAO.EducationRegistry or type(SAO.EducationRegistry.load) ~= "function"
        or not SAO.History or type(SAO.History.ticks) ~= "function" then return false, "education-owner-unavailable" end
    for _ in pairs(SAO.Identity.all()) do return false, "education-registry-staged-after-genesis" end
    return SAO.EducationRegistry.load(store, raw, rawSha, definitionSha256, bankSha, archiveSha, SAO.History.ticks())
end

function A.attachEducationRecord(rec)
    local registry = SAO.EducationRegistry
    if type(rec) ~= "table" then return false, "education-person-unavailable" end
    local bound, bindings = pcall(function()
        return registry and type(registry.currentBindings) == "function" and registry.currentBindings(rec.id)
    end)
    if not bound or not bindings then
        local reason = bound and "education-source-unavailable" or "education-reader-failed"
        rec.educationAdmission = { status = "unavailable", reason = reason }
        return false, reason
    end
    local ok, attached, why = pcall(function()
        return registry.attach(rec, SAO.History.ticks(), SAO.History.birthYearOf(rec.id))
    end)
    rec.educationAdmission = { status = ok and attached and "attached" or "unavailable",
        reason = ok and tostring(why or "education-import-unavailable") or "education-reader-failed" }
    return ok and attached == true, rec.educationAdmission.reason
end

function A.bindEducationRegistry(rawSha, definitionSha256, saveName, bankSha, archiveSha)
    local store, why = educationWorld(definitionSha256, saveName)
    if not store then return false, why end
    if not SAO.EducationRegistry or type(SAO.EducationRegistry.bind) ~= "function"
        or not SAO.History or type(SAO.History.ticks) ~= "function" then return false, "education-owner-unavailable" end
    local ok, reason = SAO.EducationRegistry.bind(store, rawSha, definitionSha256, bankSha, archiveSha, SAO.History.ticks())
    if not ok then return false, reason end
    for _, rec in pairs(SAO.Identity.all()) do A.attachEducationRecord(rec) end
    return true, reason
end
local function awarenessCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for key, item in pairs(value) do out[key] = awarenessCopy(item) end
    return out
end
local function awarenessEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not awarenessEqual(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function awarenessFields(value, names)
    if type(value) ~= "table" then return false end
    local allowed = {}; for _, name in ipairs(names) do allowed[name] = true; if value[name] == nil then return false end end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
local function awarenessArray(value, maximum)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do if not integer(key, 1, maximum) then return false end; count = count + 1 end
    return count == #value and count <= maximum
end
local function awarenessText(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and not value:find("[%c]")
end
local function awarenessTime(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
local function awarenessRowsValid(rows, now)
    if not initialCohort or not awarenessArray(rows, 128) or #rows < 1 then return false end
    local seen = {}
    for _, row in ipairs(rows) do
        if not awarenessFields(row, {"siteId", "actorOrdinal", "entries"})
            or type(row.siteId) ~= "string" or not initialCohort.requested[row.siteId]
            or not integer(row.actorOrdinal, 1, initialCohort.requested[row.siteId])
            or not awarenessArray(row.entries, 8) then return false end
        local key = row.siteId .. ":" .. row.actorOrdinal
        if seen[key] then return false end; seen[key] = true
        local ids = {}
        for _, entry in ipairs(row.entries) do
            if not awarenessFields(entry, {"id", "kind", "affirmed", "sourceId", "sourceAtHours", "receivedAtHours", "certainty"})
                or not awarenessText(entry.id) or ids[entry.id] or not awarenessText(entry.sourceId)
                or (entry.kind ~= "outbreak" and entry.kind ~= "turned") or type(entry.affirmed) ~= "boolean"
                or (entry.certainty ~= "reported" and entry.certainty ~= "witnessed")
                or not awarenessTime(entry.sourceAtHours) or not awarenessTime(entry.receivedAtHours)
                or entry.sourceAtHours > entry.receivedAtHours or entry.receivedAtHours > now then return false end
            ids[entry.id] = true
        end
    end
    return true
end
local function initialAwarenessFor(rec)
    if SAO.Identity.all()[rec.id] ~= rec then return {} end
    local origin = rec.initialStudyOrigin
    local store = ModData.get("SurvivorAwareness_Standing")
    local staged = store and store.initialStudyAwareness
    if not staged then return rec.personalAwareness ~= nil and {} or nil end
    if not initialCohort then return (rec.personalAwareness ~= nil or origin ~= nil) and {} or nil end
    local ordinal, targetSite, targetRow
    for siteId, ids in pairs(initialCohort.actualIds) do
        for index, id in ipairs(ids) do if id == rec.id then ordinal, targetSite = index, siteId end end
    end
    if origin and (not ordinal or not cohortCounts(initialCohort)) then return {} end
    for _, row in ipairs(staged.rows or {}) do
        if row.siteId == targetSite and row.actorOrdinal == ordinal then targetRow = row end
    end
    if not targetRow then return rec.personalAwareness ~= nil and {} or nil end
    if not origin or staged.definitionSha256 ~= initialCohort.definitionSha256
        or staged.saveName ~= initialCohort.saveName or origin.definitionSha256 ~= staged.definitionSha256
        or origin.saveName ~= staged.saveName or origin.siteId ~= targetSite
        or not awarenessTime(origin.admittedAtHours) or not awarenessTime(staged.stagedAtHours)
        or origin.admittedAtHours < staged.stagedAtHours
        or not awarenessRowsValid(staged.rows, staged.stagedAtHours)
        or not cohortCounts(initialCohort) then return {} end
    return {schema="sao-personal-awareness-initial/1", personId=rec.id,
        issuerId="initial-cohort:" .. staged.definitionSha256,
        sourceId="study-definition:" .. staged.definitionSha256,
        admissionKey=staged.definitionSha256 .. ":" .. rec.id .. ":" .. ordinal,
        admittedAtHours=origin.admittedAtHours, entries=awarenessCopy(targetRow.entries)}
end
function A.stageInitialAwareness(definitionSha256, saveName, rows)
    local store, why = educationWorld(definitionSha256, saveName)
    if not store then return false, why end
    local now = hoursNow()
    if not awarenessTime(now) or not awarenessRowsValid(rows, now) then return false, "invalid-initial-awareness" end
    local prior = store.initialStudyAwareness
    if prior then
        if prior.definitionSha256 ~= definitionSha256 or prior.saveName ~= saveName
            or not awarenessTime(prior.stagedAtHours) or prior.stagedAtHours > now
            or not awarenessRowsValid(prior.rows, prior.stagedAtHours)
            or not awarenessEqual(prior.rows, rows) then return false, "initial-awareness-binding-differs" end
    else
        for _ in pairs(SAO.Identity.all()) do return false, "initial-awareness-staged-after-genesis" end
        store.initialStudyAwareness = {definitionSha256=definitionSha256, saveName=saveName,
            stagedAtHours=now, rows=awarenessCopy(rows)}
    end
    local owner = SAO.PersonalAwareness
    if not owner or type(owner.bindInitialProvider) ~= "function" or type(owner.attachInitial) ~= "function" then
        return false, "personal-awareness-owner-unavailable"
    end
    if not awarenessProviderBound then
        if not owner.bindInitialProvider(A, initialAwarenessFor) then return false, "personal-awareness-provider-refused" end
        awarenessProviderBound = true
    end
    for _, rec in pairs(SAO.Identity.all()) do
        local ok, reason = owner.attachInitial(rec); if not ok then return false, reason end
    end
    return true
end
local function memoryReceipt(row, id, definitionSha256, saveName, admittedAtHours)
    local episodes = awarenessCopy(row.episodes)
    for _, episode in ipairs(episodes) do episode.ownerId = id end
    return {schema="sao-personal-memory-initial/1", personId=id,
        issuerId="initial-cohort:"..definitionSha256, sourceId="study-definition:"..definitionSha256,
        sourceSha256=definitionSha256, definitionSha256=definitionSha256, worldId=definitionSha256,
        saveId=saveName, admissionKey=definitionSha256..":"..id..":"..row.actorOrdinal,
        admittedAtHours=admittedAtHours, startDate=row.startDate, cutoffDate=row.startDate,
        birthYear=row.birthYear, episodes=episodes}
end
local function memoryRowsValid(rows, definitionSha256, saveName, startDate, now)
    local owner = SAO.PersonalMemory
    if not initialCohort or not owner or type(owner.validateInitial)~="function"
        or not awarenessArray(rows,128) or #rows<1 then return false end
    local seen = {}
    for _, row in ipairs(rows) do
        if not awarenessFields(row,{"siteId","actorOrdinal","startDate","birthYear","episodes"})
            or not initialCohort.requested[row.siteId]
            or not integer(row.actorOrdinal,1,initialCohort.requested[row.siteId])
            or row.startDate~=startDate or not awarenessArray(row.episodes,64) then return false end
        local key=row.siteId..":"..row.actorOrdinal
        if seen[key] then return false end; seen[key]=true
        for _,episode in ipairs(row.episodes) do
            if type(episode)~="table" or episode.ownerId~=nil then return false end
        end
        local id="initial-memory-validation"
        if not owner.validateInitial(memoryReceipt(row,id,definitionSha256,saveName,now),{id=id},now) then return false end
    end
    return true
end
local function initialMemoryFor(rec)
    if SAO.Identity.all()[rec.id]~=rec then return {} end
    local store=ModData.get("SurvivorAwareness_Standing")
    local staged=store and store.initialStudyLifeHistory
    local origin=rec.initialStudyOrigin
    local now=hoursNow()
    if not staged then return (rec.personalMemory~=nil or (origin and memorySourcePins)) and {} or nil end
    if not memorySourcePins or not initialCohort then return (origin or rec.personalMemory~=nil) and {} or nil end
    if staged.definitionSha256~=memorySourcePins.definitionSha256 or staged.saveName~=memorySourcePins.saveName
        or staged.startDate~=memorySourcePins.startDate
        or not awarenessEqual(staged.rows,memorySourcePins.rows)
        or initialCohort.definitionSha256~=staged.definitionSha256 or initialCohort.saveName~=staged.saveName
        or not awarenessTime(staged.stagedAtHours) or not awarenessTime(now)
        or not memoryRowsValid(staged.rows,staged.definitionSha256,staged.saveName,staged.startDate,now)
        or not cohortCounts(initialCohort) then return {} end
    local ordinal,siteId
    for site,ids in pairs(initialCohort.actualIds) do
        for index,id in ipairs(ids) do if id==rec.id then ordinal,siteId=index,site end end
    end
    if origin and not ordinal then return {} end
    local target
    for _,row in ipairs(staged.rows) do
        if row.siteId==siteId and row.actorOrdinal==ordinal then target=row end
    end
    if not target then return rec.personalMemory~=nil and {} or nil end
    if not origin or origin.definitionSha256~=staged.definitionSha256 or origin.saveName~=staged.saveName
        or origin.siteId~=siteId or not awarenessTime(origin.admittedAtHours)
        or origin.admittedAtHours>now then return {} end
    local ok,birth=pcall(function() return SAO.History.birthYearOf(rec.id) end)
    if not ok or birth~=target.birthYear then return {} end
    if SAO.EducationRegistry and type(SAO.EducationRegistry.profile)=="function" then
        local available,profile=pcall(SAO.EducationRegistry.profile,rec.id)
        if not available or (profile and profile.birthYear~=birth) then return {} end
    end
    return memoryReceipt(target,rec.id,staged.definitionSha256,staged.saveName,origin.admittedAtHours)
end
function A.stageInitialLifeHistory(definitionSha256,saveName,rows,actualStartDate)
    local store,why=educationWorld(definitionSha256,saveName)
    if not store then return false,why end
    local owner,now=SAO.PersonalMemory,hoursNow()
    if not owner or type(owner.bindInitialProvider)~="function" or type(owner.attachInitial)~="function"
        or type(owner.validateInitial)~="function" then return false,"personal-memory-owner-unavailable" end
    if not awarenessTime(now) or not memoryRowsValid(rows,definitionSha256,saveName,actualStartDate,now) then
        return false,"invalid-initial-life-history"
    end
    local prior=store.initialStudyLifeHistory
    if prior then
        if prior.definitionSha256~=definitionSha256 or prior.saveName~=saveName or prior.startDate~=actualStartDate
            or not awarenessTime(prior.stagedAtHours)
            or not memoryRowsValid(prior.rows,definitionSha256,saveName,actualStartDate,now)
            or not awarenessEqual(prior.rows,rows) then return false,"initial-life-history-binding-differs" end
    else
        for _ in pairs(SAO.Identity.all()) do return false,"initial-life-history-staged-after-genesis" end
    end
    if not memoryProviderBound then
        if not owner.bindInitialProvider(A,initialMemoryFor) then return false,"personal-memory-provider-refused" end
        memoryProviderBound=true
    end
    -- This configuration-phase stamp precedes the population replay rebase.
    -- The empty-identity staging check and source pins establish custody.
    if not prior then store.initialStudyLifeHistory={definitionSha256=definitionSha256,saveName=saveName,
        startDate=actualStartDate,stagedAtHours=now,rows=awarenessCopy(rows)} end
    memorySourcePins={definitionSha256=definitionSha256,saveName=saveName,startDate=actualStartDate,rows=awarenessCopy(rows)}
    for _,rec in pairs(SAO.Identity.all()) do
        local ok,reason=owner.attachInitial(rec); if not ok then return false,reason end
    end
    return true
end
local function registerInitialPerson(rec, siteId, origin)
    if not siteId then return end
    rec.initialStudyOrigin = { definitionSha256 = initialCohort.definitionSha256,
        saveName = initialCohort.saveName, siteId = siteId,
        x = origin.x, y = origin.y, z = origin.z, admittedAtHours = hoursNow() }
    local ids = initialCohort.actualIds[siteId]
    ids[#ids + 1] = rec.id
    if memoryProviderBound then
        local ok,reason=SAO.PersonalMemory.attachInitial(rec)
        rec.personalMemoryAdmission={status=ok and (rec.personalMemory and "attached" or "unconfigured") or "unavailable",reason=reason}
    end
    if awarenessProviderBound then
        local ok, reason = SAO.PersonalAwareness.attachInitial(rec)
        assert(ok, reason)
    end
end
local function loadRegionPoints()
    if regionPoints then return regionPoints end
    local flat = {}
    local ok, regions = pcall(function() return SpawnRegionMgr.getSpawnRegions() end)
    if not ok or type(regions) ~= "table" then
        log("spawn regions unavailable (" .. tostring(regions) .. "); genesis deferred")
        return nil
    end
    -- The engine's spawn points are keyed BY PROFESSION ([A18]): the
    -- vanilla spawnpoints tables are literally a per-profession map of
    -- where such a life would have been when it started. Keep the key.
    local byProfession, byWorkRegion = {}, {}
    for _, region in ipairs(regions) do
        if region.name and type(region.points) == "table" then
            for professionKey, list in pairs(region.points) do
                if type(list) == "table" then
                    for _, point in ipairs(list) do
                        if point.posX and point.posY then
                            local p = {
                                x = math.floor(point.posX),
                                y = math.floor(point.posY),
                                z = math.floor(point.posZ or 0),
                                region = tostring(region.name),
                                profession = tostring(professionKey),
                            }
                            flat[#flat + 1] = p
                            local key = p.profession
                            byProfession[key] = byProfession[key] or {}
                            table.insert(byProfession[key], p)
                            byWorkRegion[key] = byWorkRegion[key] or {}
                            byWorkRegion[key][p.region] = byWorkRegion[key][p.region] or {}
                            table.insert(byWorkRegion[key][p.region], p)
                        end
                    end
                end
            end
        end
    end
    regionPointsByProfession = byProfession
    regionWorkPoints = byWorkRegion
    if #flat == 0 then
        log("spawn regions carried no usable points; genesis deferred")
        return nil
    end
    regionPoints = flat
    log("world origins loaded: " .. #flat .. " spawn points across the map")
    return regionPoints
end

-- [B38] How people arrive: alone, or in twos and threes.
--
-- A county of two hundred solitary strangers is not a county. Most
-- people who lived through the first night lived through it with
-- somebody, and the ones who did not are the exception worth having.
--
-- These are shares of ORIGINATIONS, not of people: a unit of three
-- counts once here and thrice in the county, so the head count skews
-- larger than the size column reads. At 45/35/20 the average unit is
-- 1.75 people, which turns a county of 216 into about 123 parties.
local UNIT_SIZES = {
    { size = 1, weight = 45 },
    { size = 2, weight = 35 },
    { size = 3, weight = 20 },
}

-- What held them together. Recorded as a kind and nothing more - who
-- exactly they are to each other is derived from their ages, which
-- are already facts about them ([B37]).
-- The field is `bond`, not `kind`. `kind = "..."` is this tree's
-- spelling for a NEWS kind and border 10 sweeps every Lua file for
-- it, so reusing the identifier here made three unit kinds look like
-- three radio bulletins nothing rendered. The convention is
-- load-bearing; the rename respects it rather than dodging it.
local UNIT_KINDS = {
    { bond = "family", weight = 45 },
    { bond = "friends", weight = 35 },
    { bond = "mixed", weight = 20 },
}

-- People thrown together by the outbreak trust each other less than
-- people who chose each other, and both less than blood.
local UNIT_TRUST = {
    family = 0.85,
    friends = 0.70,
    mixed = 0.50,
}

local function pickWeighted(rows, field)
    local total = 0
    for _, row in ipairs(rows) do total = total + row.weight end
    local roll = SAO.Rand.int(total)
    local seen = 0
    for _, row in ipairs(rows) do
        seen = seen + row.weight
        if roll < seen then return row[field] end
    end
    return rows[1][field]
end

local function rollUnit()
    return pickWeighted(UNIT_SIZES, "size"),
        pickWeighted(UNIT_KINDS, "bond")
end

-- [B38] How many people the county holds, when the county is ASKED
-- rather than told.
--
-- A flat sixty was one number for every possible map. The operator
-- played it and read it correctly: "it is a little low... there
-- should definitely be more people in each city than it felt like
-- there was." Measured against their own install, sixty people spread
-- round-robin across TWELVE regions is five per town - and two of
-- those twelve came from map mods, which the flat number could not
-- know about.
--
-- The map already states where people were: `SpawnRegionMgr` returns
-- one region per place the game thinks a life could have started, and
-- a mod that adds a town adds a region. So the county sizes itself,
-- and installing more county gets more people without touching a
-- setting.
--
-- Deliberately per-REGION and not per spawn point. Points are filed
-- per profession ([A18]), so counting them would make the population
-- grow every time a mod adds an occupation, which is a fact about
-- jobs rather than about how many people live here.
local PER_REGION = 18
local DERIVED_FLOOR = 60
local DERIVED_CEILING = 360

local derivedTarget = nil

local function countRegions()
    local points = loadRegionPoints()
    if not points then return nil end
    local seen, n = {}, 0
    for _, p in ipairs(points) do
        if p.region and not seen[p.region] then
            seen[p.region] = true
            n = n + 1
        end
    end
    if n == 0 then return nil end
    return n
end

-- The sandbox number governs when it is set. Zero means "ask the
-- map", which is the shipped default for a new world; an existing
-- world keeps whatever number it stored.
local function resolveTarget(conf)
    if conf.population and conf.population > 0 then
        return conf.population
    end
    if derivedTarget then return derivedTarget end
    local n = countRegions()
    if not n then
        -- Regions are not loadable yet. Hold at the old default
        -- rather than founding a county of zero.
        return DERIVED_FLOOR
    end
    local target = n * PER_REGION
    if target < DERIVED_FLOOR then target = DERIVED_FLOOR end
    if target > DERIVED_CEILING then target = DERIVED_CEILING end
    derivedTarget = target
    log("the county sizes itself: " .. n .. " regions x " .. PER_REGION
        .. " a town = " .. target .. " people")
    return target
end

-- The ceiling arrivals may raise the county TO. This has to move with
-- the population or deriving one silently closes the road: arrivals
-- are gated on `newcomers > population`, and a derived county of 216
-- against the old flat ceiling of 180 would mean nobody ever walks in
-- again, with no error and no log line. Same three-to-one the shipped
-- defaults always had (60 and 180), so a bigger county is exactly as
-- open as a small one was.
local NEWCOMER_RATIO = 3
local NEWCOMER_CEILING = 500

local function resolveNewcomers(conf, target)
    if conf.newcomers and conf.newcomers > 0 then return conf.newcomers end
    local ceiling = target * NEWCOMER_RATIO
    if ceiling > NEWCOMER_CEILING then ceiling = NEWCOMER_CEILING end
    return ceiling
end

-- Where such a life would have been ([A18]): a point filed under this
-- profession's own engine path, anywhere in the county - the nurse
-- holed up at a clinic point, the deputy at a station point. Nil when
-- the county never filed one; the caller keeps its ordinary origin.
local function pickOriginFor(enginePath, siteId)
    if not enginePath then return nil end
    loadRegionPoints()
    local list = regionPointsByProfession
        and regionPointsByProfession[enginePath] or nil
    if not list or #list == 0 then return nil end
    if siteId then
        local localPoints = {}
        for _, point in ipairs(list) do
            if siteFor(point, initialCohort.sites) == siteId then localPoints[#localPoints + 1] = point end
        end
        list = localPoints
        if #list == 0 then return nil end
    end
    return list[SAO.Rand.int(#list) + 1]
end

-- A person's first ordinary workplace comes from their own saved origin
-- region and native profession points. The saved coordinate pair survives
-- reloads and source-table changes; a region without this trade has no work
-- destination to invent.
function A.workplaceFor(rec, enginePath)
    if type(rec) ~= "table" then return nil end
    if rec.workX ~= nil or rec.workY ~= nil then
        if type(rec.workX) == "number" and type(rec.workY) == "number"
            and rec.workX == rec.workX and rec.workY == rec.workY
            and rec.workX ~= math.huge and rec.workX ~= -math.huge
            and rec.workY ~= math.huge and rec.workY ~= -math.huge then
            return { x = rec.workX, y = rec.workY }
        end
        return nil
    end
    if type(enginePath) ~= "string" or enginePath == ""
        or type(rec.originRegion) ~= "string" or rec.originRegion == "" then
        return nil
    end
    loadRegionPoints()
    local byRegion = regionWorkPoints and regionWorkPoints[enginePath]
    local points = byRegion and byRegion[rec.originRegion]
    if not points or #points == 0 then return nil end
    local work = points[SAO.Rand.int(#points) + 1]
    rec.workX, rec.workY = work.x, work.y
    return work
end

local function pickInitialOrigin(siteId)
    local points, localPoints = loadRegionPoints(), {}
    if not points then return nil end
    for _, point in ipairs(points) do
        if siteFor(point, initialCohort.sites) == siteId then localPoints[#localPoints + 1] = point end
    end
    if #localPoints == 0 then return nil end
    return localPoints[SAO.Rand.int(#localPoints) + 1]
end

-- Region-balanced pick: choose a region uniformly first, then a point within
-- it, so one town's long table does not swallow the population.
local function pickOrigin()
    local points = loadRegionPoints()
    if not points then return nil end
    local byRegion = {}
    for _, p in ipairs(points) do
        byRegion[p.region] = byRegion[p.region] or {}
        table.insert(byRegion[p.region], p)
    end
    local names = {}
    for name in pairs(byRegion) do names[#names + 1] = name end
    if #names == 0 then return nil end
    local regionList = byRegion[names[SAO.Rand.int(#names) + 1]]
    return regionList[SAO.Rand.int(#regionList) + 1]
end

-- [B28] THREE WORDS, and they are not synonyms. The operator drew
-- the distinction and it is the same perspective principle the
-- provenance ladder runs on - one person, three registers:
--
--   newcomer     this record's own neutral term. Internal only.
--   stranger     what the COUNTY reports, on the wire. A fact about
--                acquaintance and nothing more.
--   interloper   what a HOUSE THAT HOLDS GROUND calls them. A
--                judgment, and it has to be EARNED by their claim -
--                see the objection in SAO_Controller ([A15]).
--
-- The word used here and on the wire until [B28] was one this genre
-- reserves for zombies, so the single term for an arriving survivor
-- meant the opposite of a survivor. It is gone.

-- [C41] How many a pass may settle once the county exists, and the
-- slack a unit is allowed so a family is never cut in half at the
-- budget's edge. Named, because a bare 6 and a bare 8 two hundred
-- lines apart were the same rule written twice.
local PACE_PER_PASS = 6
local PACE_MATES = 2

local function generatedBirthEligible(id)
    if not SAO.History or type(SAO.History.generatedPresentAtCountyTime) ~= "function" then
        return nil, "generated-birth-calendar-unavailable"
    end
    return SAO.History.generatedPresentAtCountyTime(id)
end

-- Has this save's county ever been settled? One flag, in the store
-- the county already keeps, written only once the target is
-- actually reached - so a run interrupted half way (the options
-- screen's target raised mid-save, a fault inside the loop) settles
-- the rest on the next pass rather than pacing a half-built county
-- for the rest of the save.
local function genesisSettled()
    local ok, s = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Standing")
    end)
    return ok and type(s) == "table" and s.countySettled == true
end

local function markGenesisSettled(reached, target)
    local ok, s = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Standing")
    end)
    if not (ok and type(s) == "table") then return false end
    s.countySettled = true
    s.countySettledSize = reached
    log("the county was generated before anyone was spawned: "
        .. reached .. " of " .. target .. " settled in one pass")
    return true
end

local function ensurePopulation(conf, tickCounter)
    -- [B28] THE ROAD. This runs BEFORE the refill clock and outside
    -- the death gate, because it is not about this county.
    --
    -- [B28] had it nested inside [A27]'s arrival branch, which only
    -- opens after first blood - so a county that had lost nobody
    -- would never see a newcomer no matter how long the sky had been
    -- quiet. That inverted the causation. Two questions were merged
    -- and they are separate:
    --
    --    who is on the road   the country beyond the county fell.
    --                         Nothing to do with us.
    --    who stops HERE       [A27]'s draw, which is entirely about
    --                         us, and which is untouched below.
    --
    -- The gate is the game's own lore read as engine state: GameTime
    -- knows the day the helicopter passes and the night count knows
    -- whether that day is behind us. Nobody has to be told the
    -- country fell. The sky went quiet, and people started walking.
    --
    -- One a month, flat. How many people are walking is not a fact
    -- about this county, so it is not read off our reputation.
    -- Admissions still land as pairs sometimes, because the existing
    -- "arrived together" bonding already does that - derived, rather
    -- than a second rate invented here.
    --
    -- Admission raises the CEILING and nothing else. Whether anyone
    -- actually settles is still the draw, the refill wait, and the
    -- roll further down.
    -- [B38] Resolved once per pass, before anything reads it, so
    -- every ceiling below is measured against the same number.
    conf.population = resolveTarget(conf)
    conf.newcomers = resolveNewcomers(conf, conf.population)
    if initialCohort then
        assert(conf.population == initialCohort.target, "initial-cohort-population-changed")
    end
    local capNow = conf.population
    do
        local s70 = nil
        pcall(function()
            s70 = ModData.getOrCreate("SurvivorAwareness_Standing")
        end)
        if type(s70) == "table" then
            local admitted = tonumber(s70.newcomersAdmitted) or 0
            if conf.newcomers > conf.population then
                local skyQuiet = false
                pcall(function()
                    local gt70 = GameTime.getInstance()
                    local day70 = gt70:getHelicopterDay()
                    local nights70 = gt70:getNightsSurvived()
                    -- No helicopter scheduled means no moment to wait
                    -- for: there was never a sound to stop.
                    if day70 == nil or day70 <= 0 then
                        skyQuiet = true
                    elseif nights70 ~= nil and nights70 > day70 then
                        skyQuiet = true
                    end
                end)
                if skyQuiet then
                    local lastAt = tonumber(s70.lastAdmitAtHours)
                    local nowH70 = hoursNow()
                    -- [B33] The moment the sky went quiet, kept so the
                    -- road can be read against it. A save from before
                    -- this anchors on its own last admission, which is
                    -- the best evidence it carries - never on the
                    -- epoch, which would date the collapse to the
                    -- beginning of time.
                    if s70.skyQuietAtHours == nil then
                        s70.skyQuietAtHours =
                            tonumber(s70.lastAdmitAtHours) or nowH70
                    end
                    -- [B33] The month is not a schedule, it is a rate,
                    -- and a rate that never moves says the country
                    -- stopped falling the day the helicopter left. It
                    -- did not. Each month the sky stays quiet, more of
                    -- what is out there is on the road - so the
                    -- interval is read off how long it HAS been quiet,
                    -- which is engine state and nobody's invention.
                    --
                    -- Root, not linear: the road thickens quickly at
                    -- first and then keeps thickening slowly, instead
                    -- of running away. RoadPressure is how hard the
                    -- country outside is pushing, and at 0 the whole
                    -- term vanishes and the month is exactly the month
                    -- it always was.
                    --
                    -- This is still only who is ON the road. Whether
                    -- any of them stop HERE is the draw, untouched.
                    local quietH = nowH70
                        - (tonumber(s70.skyQuietAtHours) or nowH70)
                    if quietH < 0 then quietH = 0 end
                    local accel = 1.0 + (conf.roadPressure or 0.0)
                        * math.sqrt(quietH / 720.0)
                    local wait = 720.0 / accel
                    -- A day is the floor. Below that the road stops
                    -- being a road and becomes a queue.
                    if wait < 24.0 then wait = 24.0 end
                    if lastAt == nil then
                        -- The first month runs from the day the sky
                        -- went quiet, not from the epoch.
                        s70.lastAdmitAtHours = nowH70
                    elseif nowH70 - lastAt >= wait
                        and conf.population + admitted < conf.newcomers then
                        -- [B29] A group, not a person. The road is as
                        -- busy as the player said it is; the month is
                        -- untouched, and the county's own draw still
                        -- decides whether any of them stop here.
                        local came = conf.roadTraffic or 1
                        if came < 1 then came = 1 end
                        local room = conf.newcomers
                            - (conf.population + admitted)
                        if came > room then came = room end
                        admitted = admitted + came
                        s70.newcomersAdmitted = admitted
                        s70.lastAdmitAtHours = nowH70
                        log((came == 1 and "someone else is walking"
                            or (came .. " more are walking"))
                            .. " (room for "
                            .. (conf.population + admitted) .. " now)")
                    end
                end
            end
            capNow = conf.population + admitted
            if capNow > conf.newcomers then capNow = conf.newcomers end
            if capNow < conf.population then capNow = conf.population end
        end
    end
    -- Durable death: refill waits the configured days after the newest loss.
    local newestDeathHours = -1
    for _, rec in pairs(SAO.Identity.all()) do
        if rec.dead and (rec.diedAtHours or 0) > newestDeathHours then
            newestDeathHours = rec.diedAtHours or 0
        end
    end
    if newestDeathHours >= 0
        and (hoursNow() - newestDeathHours) < conf.refillDays * 24.0 then
        return
    end
    -- The highway ([A27]): after first blood, refill is ARRIVAL, and
    -- the county's reputation is a migration force. Wars turn newcomers
    -- away, mercy houses draw them in, winter thins the road. Genesis
    -- (before any death) stays unshaped - the county starts full.
    local arriving = newestDeathHours >= 0
    if arriving then
        local chance = 100
        local seen87, feuds87, mercy87 = {}, 0, 0
        for _, r87 in pairs(SAO.Identity.all()) do
            if not r87.dead then
                local g87 = SAO.Standing.groupOf(r87.id)
                if g87 and not seen87[g87] then
                    seen87[g87] = true
                    local c87 = SAO.Standing.creedOf
                        and SAO.Standing.creedOf(g87) or nil
                    if c87 and c87.name == "mercy" then
                        mercy87 = mercy87 + 1
                    end
                    for g2 in pairs(seen87) do
                        if g2 ~= g87
                            and SAO.Standing.feudBetween(g87, g2) then
                            feuds87 = feuds87 + 1
                        end
                    end
                end
            end
        end
        chance = chance - feuds87 * 20 + mercy87 * 10
        pcall(function()
            local m87 = SAO.History.countyMonth()
            if m87 == 11 or m87 == 0 or m87 == 1
                or m87 == 10 or m87 == 2 then
                chance = math.floor(chance * 0.5)
            end
        end)
        chance = math.max(10, math.min(100, chance))
        if SAO.Rand.int(100) >= chance then
            if SAO.Identity.livingCount() < capNow
                and hoursNow() - lastHighwayLogAt >= 1 then
                lastHighwayLogAt = hoursNow()
                log("the highway carries them past ("
                    .. feuds87 .. " wars, " .. chance .. "% draw)")
            end
            return
        end
    end
    local count = SAO.Identity.livingCount()
    local bornThisPass = 0
    -- [C41] THE WORLD IS GENERATED BEFORE IT IS SPAWNED.
    --
    -- The pacing below was written for a county that grows while
    -- somebody plays, and that is what it did: six people per pass,
    -- so a sixty-person county took a minute of play to exist and the
    -- first survivors the player met had woken into a world with
    -- almost nobody in it. The county accreted around the player
    -- instead of being there first.
    --
    -- The operator named that as unbuilt (DR-036). So on a save that
    -- has never been settled the budget is the whole county: genesis
    -- runs to the target in one pass, and because this subsystem runs
    -- ahead of `band` in the tick rotation, it finishes before the
    -- first body is ever materialised. What the player walks into on
    -- day one is a county that already existed.
    --
    -- Afterwards the pacing stands unchanged, because afterwards it is
    -- refill and not creation - the road, the newcomer, the replaced
    -- dead - and those are events in a world that already exists.
    --
    -- The one-pass cost is paid where a pause is expected and cheap:
    -- the first tick of a new save. It is bounded by the target the
    -- options screen already sets, so it cannot run away.
    local settled = genesisSettled()
    local cohort = initialCohort and not settled and initialCohort or nil
    local counts
    if cohort then
        local reason
        counts, reason = cohortCounts(cohort)
        assert(counts, reason)
        capNow = cohort.target
    end
    local budget = settled and PACE_PER_PASS or capNow
    local wholeCounty = not settled
    local startedAt = count
    while count < capNow and bornThisPass < budget do
        -- County-scale genesis is PACED ([A16]) once the county
        -- exists: six identities per pass (240 county ticks, ~4s at
        -- 60fps frames on the default day).
        bornThisPass = bornThisPass + 1
        local siteId, remaining
        if cohort then
            for _, site in ipairs(cohort.sites) do
                local room = cohort.requested[site.id] - counts[site.id]
                if room > 0 then siteId, remaining = site.id, room; break end
            end
            if not siteId then
                cohort.status, cohort.reason = "generated", nil
                return
            end
        end
        local origin
        if siteId then origin = pickInitialOrigin(siteId) else origin = pickOrigin() end
        if not origin then
            if cohort then cohort.status, cohort.reason = "deferred", "native-origin-unavailable:" .. siteId end
            return
        end
        local rec, creationReason = SAO.Identity.create(nil, nil,
            origin.x, origin.y, origin.z, generatedBirthEligible)
        if not rec then
            if cohort then
                cohort.status, cohort.reason = "deferred",
                    "native-identity-creation-refused:" .. siteId
                        .. ":" .. tostring(creationReason or "unknown")
            end
            return
        end
        pcall(function() SAO.History.generate(rec.id, rec) end)
        A.attachEducationRecord(rec)
        -- Where the life was lived ([A18]): the id decided the trade
        -- (inside generate); if the county filed spawn points under
        -- that trade's own engine path, this survivor started THERE -
        -- the record moves before any body exists (unloaded-world
        -- mutation, sanctioned domain).
        local row = SAO.Census and rec.occupation
            and SAO.Census.rowOf(rec.occupation) or nil
        local anchored = row and pickOriginFor(row.enginePath, siteId) or nil
        if anchored then
            origin = anchored
            rec.x, rec.y, rec.z = anchored.x, anchored.y, anchored.z
            rec.originAnchored = true
        end
        rec.originRegion = origin.region
        rec.homeX, rec.homeY, rec.homeZ = origin.x, origin.y, origin.z
        registerInitialPerson(rec, siteId, origin)
        if siteId then counts[siteId] = counts[siteId] + 1 end
        -- [C74] Presence, not an origin label, is what can support lived
        -- county knowledge. Genesis starts on the record's first day; a later
        -- admission begins now and cannot inherit the county's past.
        pcall(function()
            SAO.WorldKnowledge.markCountyPresence(rec, not arriving)
        end)
        -- [B40] They know where they started.
        --
        -- `originAnchored` was written here and read NOWHERE in the
        -- tree - one mention in the whole mod. It records the thing
        -- [A18] built: a life that began at its own trade's ground,
        -- the nurse at a clinic point, the deputy at a station.
        --
        -- And underneath it was a plainer gap. Every survivor woke up
        -- SOMEWHERE, and [B37] gave the county a way to know places,
        -- and nobody knew the one place they had certainly been. The
        -- metagrid answers without a body, so genesis can ask.
        --
        -- Provenance `lived`, because they did not walk past it or
        -- hear about it - they were in it when the world ended
        -- ([B39]).
        local startedIn
        pcall(function()
            startedIn = SAO.Places.at(origin.x, origin.y)
            if startedIn then
                SAO.Perception.learnBuilding(rec.id, startedIn, 0, "lived")
                if rec.originAnchored then
                    rec.knowsTradeGround = true
                end
            end
        end)
        if arriving then
            -- An arrival is a FACT of the person and news on the air.
            rec.newcomer = true
            rec.arrivedAtHours = hoursNow()
            pcall(function()
                SAO.Standing.pushRadioNews({ kind = "stranger" })
            end)
        end
        -- [B47] Once per person at seeding: 129 lines in the
        -- operator's log. Someone ARRIVING up the road later is a
        -- real event and keeps its own line; the seeding of a county
        -- is one fact with a number on it.
        if arriving then
            log("someone came up the road into " .. origin.region
                .. (anchored and (" (at their " .. (row.label or "trade")
                    .. " ground)") or "")
                .. " (" .. (count + 1) .. "/" .. capNow .. ")")
        else
            tally("the world gained a survivor")
        end
        count = count + 1
        -- Together since day one ([A18]), and [B38] in twos and
        -- threes. The operator ruled that many should begin in twos
        -- and threes - family units, friend units, mixed units.
        --
        -- Before this, twenty percent of lives got a single bonded
        -- mate and everybody else started alone, so a county of two
        -- hundred was a hundred and seventy solitary people. Now a
        -- life originates as a UNIT, and what kind of unit it is is a
        -- fact about it - a BOND, never a pre-formed faction, so the
        -- 3+ perception gate for companies stays untouched.
        --
        -- The unit records only what kind it is. WHICH relation any
        -- two of them stand in is derived from their ages at read
        -- time, because their ages are already facts ([B37]) and
        -- choosing the relation and then choosing ages to match would
        -- be authoring the same thing twice.
        local size, kind = rollUnit()
        if siteId then size = math.min(size, remaining) end
        local unitId = (size > 1) and (rec.id .. "-u") or nil
        local mates = { rec }
        for _ = 2, size do
            if count >= capNow or bornThisPass >= budget + PACE_MATES then break end
            local mate = SAO.Identity.create(nil, nil,
                origin.x, origin.y, origin.z, generatedBirthEligible)
            if not mate then break end
            bornThisPass = bornThisPass + 1
            pcall(function() SAO.History.generate(mate.id, mate) end)
            A.attachEducationRecord(mate)
            if arriving then
                mate.newcomer = true
                mate.arrivedAtHours = hoursNow()
            end
            mate.originRegion = origin.region
            mate.homeX, mate.homeY, mate.homeZ = origin.x, origin.y, origin.z
            registerInitialPerson(mate, siteId, origin)
            if siteId then counts[siteId] = counts[siteId] + 1 end
            pcall(function()
                SAO.WorldKnowledge.markCountyPresence(mate, not arriving)
            end)
            -- The mate began at this same actual origin. Knowing the shared
            -- building does not anchor their own profession to its trade.
            if startedIn then
                pcall(function()
                    SAO.Perception.learnBuilding(mate.id, startedIn, 0, "lived")
                end)
            end
            mate.unitId, mate.unitKind = unitId, kind
            mates[#mates + 1] = mate
            count = count + 1
        end
        if #mates > 1 then
            -- The intended unit becomes a fact only after another person
            -- was actually admitted. An unavailable birth/calendar answer
            -- can defer a mate without making this person a false unit.
            rec.unitId, rec.unitKind = unitId, kind
            local trust = UNIT_TRUST[kind] or 0.6
            for a = 1, #mates do
                for b = a + 1, #mates do
                    pcall(function()
                        SAO.Standing.bond(mates[a].id, mates[b].id)
                        SAO.Standing.adjustTrust(mates[a].id, mates[b].id,
                            trust)
                        SAO.Standing.adjustTrust(mates[b].id, mates[a].id,
                            trust)
                        -- [C72] And they have seen each other. People
                        -- who come through the first night together
                        -- are standing on the same tile; a belief that
                        -- the other is somewhere is the plainest fact
                        -- the county has about them, and without it
                        -- the pairs that already trust each other most
                        -- have nowhere to go looking. `sawPerson` is
                        -- the same write a road meeting makes, at the
                        -- same provenance, because this is the same
                        -- kind of thing: they were both there.
                        -- [C87] The distance is stated from their own
                        -- positions rather than defaulted, so the two
                        -- spellings of one write cannot drift apart
                        -- if mates ever spawn apart.
                        local fdx = mates[a].x - mates[b].x
                        local fdy = mates[a].y - mates[b].y
                        local fdist = math.sqrt(fdx * fdx + fdy * fdy)
                        SAO.Perception.sawPerson(mates[a].id,
                            SAO.Identity.beliefKey(mates[b]),
                            mates[b].x, mates[b].y, tickCounter,
                            mates[b].id, fdist)
                        SAO.Perception.sawPerson(mates[b].id,
                            SAO.Identity.beliefKey(mates[a]),
                            mates[a].x, mates[a].y, tickCounter,
                            mates[a].id, fdist)
                    end)
                end
            end
            local who = {}
            for i = 2, #mates do who[#who + 1] = mates[i].id end
            log(table.concat(who, " and ") .. " came through the first "
                .. "night with " .. rec.id .. " (" .. kind .. " of "
                .. #mates .. ", " .. count .. "/" .. capNow .. ")")
        end
    end
    -- [C41] Settled only when the county actually reached its target,
    -- so this cannot mark a world that ran out of origins half way.
    if wholeCounty and count >= capNow then
        if cohort then
            local actual, reason = cohortCounts(cohort)
            assert(actual, reason)
            local generated = 0
            for _, site in ipairs(cohort.sites) do generated = generated + actual[site.id] end
            assert(generated == cohort.target, "initial-cohort-generated-count-differs")
            cohort.status, cohort.reason = "generated", nil
        end
        markGenesisSettled(count, capNow)
    elseif wholeCounty and count > startedAt then
        log("the county is still being generated: " .. count .. "/"
            .. capNow .. " - the next pass carries on before anyone spawns")
    end
end

function A.rebindWorld()
    if SAO.EducationRegistry and type(SAO.EducationRegistry.clear)=="function" then
        pcall(SAO.EducationRegistry.clear)
    end
    regionPoints, regionPointsByProfession, regionWorkPoints, derivedTarget = nil, nil, nil, nil
    initialCohort = nil
    memorySourcePins = nil
    lastHighwayLogAt = -9
end

A.ensurePopulation = ensurePopulation
A.genesisSettled = genesisSettled
A.resolveTarget = resolveTarget
A.loadRegionPoints = loadRegionPoints
A.tradeGroundFor = pickOriginFor
return A
