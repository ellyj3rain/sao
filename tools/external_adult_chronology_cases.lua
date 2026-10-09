-- Runs production History and Age in the installed game's Kahlua VM.
local checks = 0
local function check(name, value)
    if not value then error("EXTERNAL_ADULT_CHRONOLOGY:" .. name) end
    __step = name
    checks = checks + 1
end

local records, clock, calendarAvailable = {}, 108.0, true
SAO.Identity = {
    get = function(id) return records[id] end,
    all = function() return records end,
    markDead = function(rec, _, cause) rec.dead, rec.diedOf = true, cause end,
}
ModData = { getOrCreate = function() return { yearsAsked = false } end }
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return clock end,
    getTimeOfDay = function() return clock % 24 end,
    getStartYear = function() return 1993 end,
} end }
SAOJavaBridge = {
    daysBehindAtStart = function() return 0 end,
    countyInstant = function(_, hours)
        if not calendarAvailable then return nil end
        if hours >= 540 * 24 then return "1994-12-31T12:00:00" end
        if hours >= 365 * 24 then return "1994-07-09T12:00:00" end
        if hours >= 176 * 24 then return "1994-01-01T12:00:00" end
        return "1993-07-09T12:00:00"
    end,
    setXpScale = function() end,
}
SAO.Body = { active = {}, hasRepresentation = function() return false end }
SAO.Disposition = { fear = function() return 0 end }
SAO.Conditions = { learningScale = function() return 1 end,
    drift = function() return nil end }
SAO.Habits = { drift = function() return nil end }
CharacterStat = { ENDURANCE = "ENDURANCE", FATIGUE = "FATIGUE",
    PAIN = "PAIN", STRESS = "STRESS", PANIC = "PANIC" }
local drawState, drawCalls = 7, 0
ZombRand = function(limit)
    drawState = (drawState * 48271) % 2147483647
    drawCalls = drawCalls + 1
    return drawState % limit
end

local H, Age = SAO.History, SAO.Age
local before, child, elder = {}, nil, nil
for i = 1, 180 do
    local id = "sao-" .. i
    records[id] = { id = id }
    before[id] = H.ageOf(id)
    if before[id] < 18 and not child then child = id end
    if before[id] >= 60 and not elder then elder = id end
end
check("generated_child_and_elder_exist", child ~= nil and elder ~= nil)

local selected = nil
for i = 1, 180 do
    local id = "bwo-" .. i
    records[id] = { id = id }
    if H.ageOf(id) < 18 and not selected then selected = records[id] end
end
check("pre_admission_had_child_mismatch", selected ~= nil)
local originalHash = SAO.Hash.of
SAO.Hash.of = function(id, salt)
    if id == selected.id then error("forbidden-external-age-hash:" .. tostring(salt)) end
    return originalHash(id, salt)
end
local ok, why = H.admitExternalAdult(selected, {
    source = "BanditsWeekOne", sourceKey = "42@108", nativeDefaultScaleBody = true })
check("adult_admitted", ok == true and why == "admitted")
local chronology = selected.chronology
local age = H.ageOf(selected.id)
check("sao_authored_provenance", chronology.schema == "sao-external-adult-chronology/3"
    and chronology.ageAuthorship == "SAO"
    and chronology.evidence == "native-default-scale-source-proxy"
    and chronology.source == "BanditsWeekOne"
    and chronology.sourceKey == "42@108"
    and chronology.admittedAtHours == 108
    and chronology.ageTransitionPolicy == "admission-anniversary"
    and chronology.allocation.method == "SAO.History.adult-census-draw/1"
    and chronology.allocation.reason == "source-admission"
    and chronology.allocation.bandRoll >= 0
    and chronology.allocation.yearRoll >= 0 and drawCalls == 2)
check("adult_age_birth_year", age >= 18 and age <= 59
    and age == chronology.ageAtAdmission and chronology.birthYear == 1993 - age
    and chronology.admissionYear == 1993 and H.birthYearOf(selected.id) == 1993 - age)
check("adult_stage_body_and_pace", H.stageOf(age) ~= "child"
    and H.stageOf(age) ~= "elder" and H.heightScaleOf(selected.id) == 1
    and H.speedModOf(selected.id) == 1)
check("adult_physiology", H.oldAgeRiskPerDay(age) == 0
    and H.fearFloorOf(age) == 0 and H.perkFloorsOf(age) == nil
    and H.kitOf(selected.id) == nil
    and Age.growthSpurt(selected, nil, 0) == false
    and Age.dailyRoll(selected, 0, 0) == false
    and selected.dead == nil and selected.dyingOfOldAge == nil)
local projection = H.calendarAgeOf(selected.id)
check("calendar_projection", projection.status == "available"
    and projection.birthYear == chronology.birthYear
    and projection.baselineAge == age and projection.nominalAge == age
    and projection.simulationAgePolicy == "admission-anniversary")
SAO.Hash.of = originalHash

local savedSource = __nativeRoundtrip({["bwo-saved"] = {
    id = "bwo-saved", epistemicMonths = 6,
    weekOne = { source = "BanditsWeekOne", brainId = 901, born = 12.5,
        status = "dormant", sourceSpawn = { eventRef = "saved-selected-event" } },
}})
records["bwo-saved"] = savedSource["bwo-saved"]
SAO.Hash.of = function(id, salt)
    if id == "bwo-saved" then
        error("forbidden-saved-weekone-age-hash:" .. tostring(salt))
    end
    return originalHash(id, salt)
end
local savedAge = H.ageOf("bwo-saved")
SAO.Hash.of = originalHash
check("saved_weekone_migrated_before_body_observation", savedAge >= 18
    and savedAge <= 59 and records["bwo-saved"].chronology.schema
        == "sao-external-adult-chronology/3"
    and records["bwo-saved"].chronology.sourceKey == "901@12.5"
    and records["bwo-saved"].chronology.evidence == "saved-weekone-person"
    and records["bwo-saved"].chronology.allocation.reason
        == "saved-weekone-migration"
    and records["bwo-saved"].epistemicMonths == 6
    and records["bwo-saved"].weekOne.sourceSpawn.eventRef
        == "saved-selected-event")
check("saved_weekone_migration_is_stable", H.ageOf("bwo-saved") == savedAge
    and H.birthYearOf("bwo-saved") == 1993 - savedAge)

local priorEducation = { owner = "SAO.Education", retained = true }
records["bwo-prior"] = { id = "bwo-prior", education = priorEducation,
    personalMemory = { retained = true }, epistemicMonths = 18,
    weekOne = { source = "BanditsWeekOne", brainId = 903, born = 12.5 } }
SAO.EducationRegistry = { profile = function(id)
    if id == "bwo-prior" then
        return { personId = id, birthYear = 1960 } end
    return nil
end }
local drawsBeforePrior = drawCalls
local priorAge = H.ageOf("bwo-prior")
local prior = records["bwo-prior"]
check("saved_weekone_retains_education_birth_prior",
    priorAge == 33 and H.birthYearOf(prior.id) == 1960
    and prior.chronology.schema == "sao-saved-person-chronology/1"
    and prior.chronology.allocation.reason == "saved-birth-prior"
    and prior.education == priorEducation and prior.personalMemory.retained
    and prior.epistemicMonths == 18 and drawCalls == drawsBeforePrior
    and H.calendarAgeOf(prior.id).status == "available")
local savedMemory = { id = "bwo-memory", personalMemory = { retained = true } }
records[savedMemory.id] = savedMemory
local originalMemoryAge = H.ageOf(savedMemory.id)
local originalMemoryBirth = H.birthYearOf(savedMemory.id)
savedMemory.weekOne = { source = "BanditsWeekOne", brainId = 904, born = 12.5 }
check("saved_weekone_retains_generated_person_age",
    H.ageOf(savedMemory.id) == originalMemoryAge
    and H.birthYearOf(savedMemory.id) == originalMemoryBirth
    and savedMemory.chronology.allocation.reason == "saved-generated-prior"
    and drawCalls == drawsBeforePrior)
local deferred = { id = "bwo-education-deferred", education = { retained = true },
    weekOne = { source = "BanditsWeekOne", brainId = 905, born = 12.5 } }
records[deferred.id] = deferred
local deferredOk, deferredWhy = H.admitExternalAdult(deferred, {
    source = "BanditsWeekOne", sourceKey = "905@12.5", savedWeekOnePerson = true })
check("saved_education_without_profile_is_not_redrawn",
    deferredOk == false and deferredWhy == "saved-education-profile-unavailable"
    and deferred.chronology == nil and drawCalls == drawsBeforePrior)
SAO.EducationRegistry = nil

local deltas = {}
local stats = { add = function(_, name, delta)
        deltas[name] = (deltas[name] or 0) + delta
    end, remove = function(_, name, delta)
        deltas[name] = (deltas[name] or 0) - delta
    end }
local body = { getStats = function() return stats end }
SAO.Hash.of = function(id, salt)
    if type(salt) == "string"
        and string.find(salt, "age-drift:", 1, true) == 1 then return 0 end
    return originalHash(id, salt)
end
Age.drift(selected, body, 1)
SAO.Hash.of = originalHash
local stage = H.stageOf(age)
local deltaCount = 0
for _ in pairs(deltas) do deltaCount = deltaCount + 1 end
check("age_module_uses_admitted_stage",
    stage == "young" and deltas.ENDURANCE == 0.015
        and deltas.FATIGUE == -0.015
    or stage == "adult" and deltaCount == 0
    or stage == "middle" and deltas.ENDURANCE == -0.010
        and deltas.FATIGUE == 0.010)

local ages = {}
for i = 181, 308 do
    local rec = { id = "bwo-" .. i }
    records[rec.id] = rec
    local admitted = H.admitExternalAdult(rec, {
        source = "BanditsWeekOne", sourceKey = tostring(i) .. "@108",
        nativeDefaultScaleBody = true })
    check("sample_admission_" .. i, admitted == true)
    local sampled = H.ageOf(rec.id)
    check("sample_adult_" .. i, sampled >= 18 and sampled <= 59)
    ages[sampled] = true
end
local spread = 0
for _ in pairs(ages) do spread = spread + 1 end
check("adult_band_spread", spread >= 20)
check("two_native_draws_per_admission", drawCalls == 2 * (130))
local adultEdge = { id = "bwo-adult-edge" }
records[adultEdge.id] = adultEdge
local bands, edgeRoll = H.bands(), 0
for i = 3, 6 do edgeRoll = edgeRoll + bands[i].weight end
local ordinaryDraw, edgeDraws = ZombRand, 0
ZombRand = function()
    edgeDraws = edgeDraws + 1
    return edgeDraws == 1 and edgeRoll or 9
end
ok, why = H.admitExternalAdult(adultEdge, {
    source = "BanditsWeekOne", sourceKey = "adult-edge@108",
    nativeDefaultScaleBody = true })
ZombRand = ordinaryDraw
check("age_59_physio_boundary_allocated", ok == true and why == "admitted"
    and edgeDraws == 2 and H.ageOf(adultEdge.id) == 59
    and H.oldAgeRiskPerDay(H.ageOf(adultEdge.id)) == 0)
local becomingAdult, reachingRisk = nil, nil
for i = 1, 600 do
    local id = "sao-transition-" .. i
    local startingAge = H.ageOf(id)
    if startingAge == 17 and not becomingAdult then becomingAdult = id end
    if startingAge == 59 and not reachingRisk then reachingRisk = id end
end
check("generated_stage_boundaries_available",
    becomingAdult ~= nil and reachingRisk ~= nil)
for id, prior in pairs(before) do
    check("generated_age_unchanged_" .. id, H.ageOf(id) == prior)
end
check("generated_child_stays_child", H.stageOf(H.ageOf(child)) == "child"
    and H.heightScaleOf(child) < 1)
SAO.Hash.of = function(id, salt)
    if type(salt) == "string"
        and string.find(salt, "old-age:", 1, true) == 1 then return 0 end
    return originalHash(id, salt)
end
check("generated_elder_risk_still_runs", Age.dailyRoll(records[elder], 0, 0) == true
    and records[elder].diedOf == "old age")
SAO.Hash.of = originalHash

clock = 176 * 24
check("unknown_birthday_does_not_age_on_january_first",
    H.ageOf(selected.id) == age
    and H.calendarAgeOf(selected.id).nominalAge == age + 1
    and H.ageOf(adultEdge.id) == 59
    and H.oldAgeRiskPerDay(H.ageOf(adultEdge.id)) == 0)
clock = 365 * 24 + 108
ok, why = H.admitExternalAdult(selected, {
    source = "BanditsWeekOne", sourceKey = "42@108", nativeDefaultScaleBody = true })
check("repeat_does_not_reage", ok == true and why == "already-admitted"
    and selected.chronology == chronology and H.ageOf(selected.id) == age + 1
    and H.birthYearOf(selected.id) == 1993 - age)
check("calendar_year_advances", H.calendarAgeOf(selected.id).nominalAge == age + 1
    and H.calendarAgeOf(selected.id).baselineAge == age
    and H.stageOf(H.ageOf(selected.id)) == H.stageOf(age + 1))
check("admission_anniversary_opens_age_risk", H.ageOf(adultEdge.id) == 60
    and H.oldAgeRiskPerDay(H.ageOf(adultEdge.id)) > 0)
clock = 540 * 24
check("generated_residents_age_during_midgame", H.ageOf(child) == before[child] + 1
    and H.birthYearOf(child) == 1993 - before[child]
    and H.calendarAgeOf(child).baselineAge == before[child])
check("generated_stage_and_risk_advance", H.ageOf(becomingAdult) == 18
    and H.stageOf(H.ageOf(becomingAdult)) == "young"
    and H.ageOf(reachingRisk) == 60
    and H.oldAgeRiskPerDay(H.ageOf(reachingRisk)) > 0)
clock = 365 * 24 + 108
clock = 0
check("before_admission_cannot_regress_to_child", pcall(H.ageOf, selected.id) == false)
clock = 365 * 24 + 108
ok, why = H.admitExternalAdult(selected, {
    source = "BanditsWeekOne", sourceKey = "different-source-body", nativeDefaultScaleBody = true })
check("source_conflict_refused", ok == false and why == "chronology-conflict")

local history = { id = "bwo-existing", epistemicMonths = 6 }
records[history.id] = history
ok, why = H.admitExternalAdult(history, {
    source = "BanditsWeekOne", sourceKey = "existing@108", nativeDefaultScaleBody = true })
check("existing_history_refused", ok == false and why == "existing-life-history"
    and history.chronology == nil)
local missing = { id = "bwo-missing" }
records[missing.id] = missing
ok, why = H.admitExternalAdult(missing, {
    source = "BanditsWeekOne", sourceKey = "missing@108" })
check("adult_body_evidence_required", ok == false
    and why == "adult-source-evidence-unavailable" and missing.chronology == nil)
ok, why = H.admitExternalAdult({ id = selected.id }, {
    source = "BanditsWeekOne", sourceKey = "42@108", nativeDefaultScaleBody = true })
check("record_identity_required", ok == false and why == "person-unavailable")
local incomplete = { id = "bwo-incomplete",
    weekOne = { source = "BanditsWeekOne" } }
records[incomplete.id] = incomplete
check("unadmitted_source_never_hashes_an_age", pcall(H.ageOf, incomplete.id) == false
    and H.calendarAgeOf(incomplete.id).status == "unavailable")
calendarAvailable = false
ok, why = H.admitExternalAdult(missing, {
    source = "BanditsWeekOne", sourceKey = "missing@108", nativeDefaultScaleBody = true })
check("calendar_required", ok == false and why == "county-calendar-unavailable"
    and missing.chronology == nil)
local currentAgeAvailable = pcall(H.ageOf, selected.id)
check("missing_calendar_never_hashes_imported_person", currentAgeAvailable == false
    and H.birthYearOf(selected.id) == 1993 - age)
calendarAvailable = true

local unavailable = { id = "bwo-no-draw" }
records[unavailable.id] = unavailable
local savedDraw = ZombRand
ZombRand = nil
ok, why = H.admitExternalAdult(unavailable, {
    source = "BanditsWeekOne", sourceKey = "no-draw@108",
    nativeDefaultScaleBody = true })
check("missing_draw_refuses_without_chronology", ok == false
    and why == "adult-age-allocation-unavailable" and unavailable.chronology == nil)
ZombRand = function() return -1 end
ok, why = H.admitExternalAdult(unavailable, {
    source = "BanditsWeekOne", sourceKey = "bad-draw@108",
    nativeDefaultScaleBody = true })
check("invalid_draw_refuses_without_chronology", ok == false
    and why == "adult-age-allocation-unavailable" and unavailable.chronology == nil)
local partialDraws = 0
ZombRand = function()
    partialDraws = partialDraws + 1
    return partialDraws == 1 and 0 or -1
end
ok, why = H.admitExternalAdult(unavailable, {
    source = "BanditsWeekOne", sourceKey = "bad-second-draw@108",
    nativeDefaultScaleBody = true })
check("invalid_second_draw_keeps_record_unallocated", ok == false
    and why == "adult-age-allocation-unavailable"
    and partialDraws == 2 and unavailable.chronology == nil)
ZombRand = savedDraw

local retrySaved = { id = "bwo-retry",
    weekOne = { source = "BanditsWeekOne", brainId = 902, born = 12.5 } }
records[retrySaved.id] = retrySaved
ZombRand = nil
check("saved_person_missing_draw_keeps_identity_and_no_fake_age",
    pcall(H.ageOf, retrySaved.id) == false
    and records[retrySaved.id] == retrySaved
    and retrySaved.chronology == nil)
ZombRand = savedDraw
check("saved_person_retries_without_rekey", H.ageOf(retrySaved.id) >= 18
    and records[retrySaved.id] == retrySaved
    and retrySaved.chronology.sourceKey == "902@12.5")

local legacy = { id = "bwo-legacy", chronology = {} }
records[legacy.id] = legacy
for key, value in pairs(selected.chronology) do
    if key ~= "allocation" and key ~= "ageTransitionPolicy" then
        legacy.chronology[key] = value end
end
legacy.chronology.schema = "sao-external-adult-chronology/1"
legacy.chronology.sourceKey = "legacy@108"
local drawsBeforeLegacy = drawCalls
ok, why = H.admitExternalAdult(legacy, {
    source = "BanditsWeekOne", sourceKey = "legacy@108",
    nativeDefaultScaleBody = true })
check("saved_v1_chronology_retained", ok == true and why == "already-admitted"
    and H.ageOf(legacy.id) == age + 1 and drawCalls == drawsBeforeLegacy)
local prior = { id = "bwo-v2", chronology = {} }
records[prior.id] = prior
for key, value in pairs(selected.chronology) do
    if key ~= "ageTransitionPolicy" then prior.chronology[key] = value end
end
prior.chronology.schema = "sao-external-adult-chronology/2"
prior.chronology.sourceKey = "prior-v2@108"
prior.chronology.allocation = {
    method = selected.chronology.allocation.method,
    bandRoll = selected.chronology.allocation.bandRoll,
    yearRoll = selected.chronology.allocation.yearRoll,
}
ok, why = H.admitExternalAdult(prior, {
    source = "BanditsWeekOne", sourceKey = "prior-v2@108",
    nativeDefaultScaleBody = true })
check("saved_v2_chronology_retained", ok == true and why == "already-admitted"
    and H.ageOf(prior.id) == age + 1 and drawCalls == drawsBeforeLegacy)

local childAgeBeforeSave = H.ageOf(child)
local saved = __nativeRoundtrip(records)
records = saved
H.rebindWorld()
local loaded = records[selected.id]
local legacyLoaded = records[legacy.id]
local priorLoaded = records[prior.id]
check("generated_age_survives_native_reload", H.ageOf(child) == childAgeBeforeSave
    and H.birthYearOf(child) == 1993 - before[child])
check("native_save_reload_v1_preserved", legacyLoaded ~= legacy
    and legacyLoaded.chronology.schema == "sao-external-adult-chronology/1"
    and legacyLoaded.chronology.allocation == nil
    and H.ageOf(legacyLoaded.id) == age + 1)
check("native_save_reload_v2_preserved", priorLoaded ~= prior
    and priorLoaded.chronology.schema == "sao-external-adult-chronology/2"
    and priorLoaded.chronology.ageTransitionPolicy == nil
    and H.ageOf(priorLoaded.id) == age + 1)
check("native_save_reload_age", loaded ~= selected
    and H.ageOf(loaded.id) == age + 1 and H.birthYearOf(loaded.id) == 1993 - age
    and H.heightScaleOf(loaded.id) == 1
    and loaded.chronology.sourceKey == "42@108"
    and loaded.chronology.admittedAtHours == 108
    and loaded.chronology.allocation.method == "SAO.History.adult-census-draw/1")
loaded.chronology.ageTransitionPolicy = "source-birthday"
check("source_birthday_policy_refused", pcall(H.ageOf, loaded.id) == false)
loaded.chronology.ageTransitionPolicy = "admission-anniversary"
loaded.chronology.allocation.yearRoll = loaded.chronology.allocation.yearRoll + 1
local valid = pcall(H.ageOf, loaded.id)
check("corrupt_chronology_refused", valid == false)

__result = "PASS external adult chronology: " .. checks .. " assertions"
