-- Source-linked age samples are read against the person's current county age.
-- The native body owner keeps its appearance, scale, and model authority.

SAO = SAO or {}
SAO.AgeVisual = SAO.AgeVisual or {}
local V = SAO.AgeVisual

V.SCHEMA = "sao-age-visual/2"
V.MODEL_SCHEMA = "sao-age-model-candidate/2"
local candidates = {}

local function finite(n)
    return type(n) == "number" and n == n
        and n ~= math.huge and n ~= -math.huge
end

local function whole(n, lo, hi)
    return finite(n) and n == math.floor(n) and n >= lo and n <= hi
end

local function nonempty(s)
    return type(s) == "string" and s ~= ""
end

local function sha256(s)
    return type(s) == "string" and #s == 64
        and s:match("^[0-9a-fA-F]+$") ~= nil
end

-- One point in an authored source set. Samples do not change H.ageOf.
function V.registerCandidate(spec)
    if type(spec) ~= "table" or spec.schema ~= V.MODEL_SCHEMA
        or not nonempty(spec.id) or not spec.id:match("^[%w%._%-]+$")
        or not nonempty(spec.artifactRef) or not sha256(spec.artifactSha256)
        or not nonempty(spec.archiveRef) or not sha256(spec.archiveSha256)
        or not nonempty(spec.sourceIndexRef) or not sha256(spec.sourceIndexSha256)
        or not nonempty(spec.sourceManifestRef)
        or not sha256(spec.sourceManifestSha256)
        or not nonempty(spec.ageInputsRef)
        or not sha256(spec.ageInputsSha256)
        or not nonempty(spec.sourceCase)
        or not whole(spec.sampleAgeYears, 0, 120)
        or not whole(spec.periodFromYear, 1, 9999)
        or not whole(spec.periodThroughYear, spec.periodFromYear, 9999)
        or spec.periodScope ~= "anatomy-only" then
        return false, "invalid-model-candidate"
    end
    if candidates[spec.id] then return false, "candidate-already-registered" end
    candidates[spec.id] = {
        schema = V.MODEL_SCHEMA, id = spec.id,
        artifactRef = spec.artifactRef, artifactSha256 = spec.artifactSha256,
        archiveRef = spec.archiveRef, archiveSha256 = spec.archiveSha256,
        sourceIndexRef = spec.sourceIndexRef,
        sourceIndexSha256 = spec.sourceIndexSha256,
        sourceManifestRef = spec.sourceManifestRef,
        sourceManifestSha256 = spec.sourceManifestSha256,
        ageInputsRef = spec.ageInputsRef,
        ageInputsSha256 = spec.ageInputsSha256,
        sourceCase = spec.sourceCase,
        sampleAgeYears = spec.sampleAgeYears,
        periodFromYear = spec.periodFromYear,
        periodThroughYear = spec.periodThroughYear,
        periodScope = spec.periodScope,
    }
    return true
end

-- These archived Blender scenes are indexed in Post-Latent's private local
-- appearance scratch. Generation inputs give illustrative ages 0, 8, 15, 31,
-- and 72; they are source samples, not SAO stage boundaries. The MPFB study
-- explicitly reports no native B42 runtime test.
local INDEX = "appearance-scratch/storage-repack-v1/index.json"
local INDEX_SHA = "579ac9032e21e37ca3616876d181e443aeb0e74411a39e93d9032d8fd83cbdad"
local INPUTS = "appearance-scratch/advanced-character/generation-inputs.json"
local INPUTS_SHA = "3c45e38d653d93ec86a15d329a70b280cf730887f6ecece882a09d22be72a66f"
local ARCHIVE = "appearance-scratch/storage-repack-v1/batches/batch-021688627092.tar.zst"
local ARCHIVE_SHA = "b0404887136d1a178646becbc6e8debe155069a735fca0097db8b97ca646464a"
local STUDY = "appearance-scratch/advanced-character/mpfb-study/same_person_proportion_study.blend"
local STUDY_SHA = "7de10d43b59f46cef6b3a369b7f9dd1dcd905a914492c3edf844fb2ff46d1b57"
local STUDY_MANIFEST = "appearance-scratch/advanced-character/mpfb-study/manifest.json"
local STUDY_MANIFEST_SHA = "b327de27269db6f24b51d428fe3e414cf759f8146ac9f74d7ba2d855f8c04788"

local function sourceSample(id, age, artifact, artifactSha, sourceCase,
        manifest, manifestSha)
    local ok = V.registerCandidate({
        schema = V.MODEL_SCHEMA, id = id,
        artifactRef = artifact, artifactSha256 = artifactSha,
        archiveRef = ARCHIVE, archiveSha256 = ARCHIVE_SHA,
        sourceIndexRef = INDEX, sourceIndexSha256 = INDEX_SHA,
        sourceManifestRef = manifest, sourceManifestSha256 = manifestSha,
        ageInputsRef = INPUTS, ageInputsSha256 = INPUTS_SHA,
        sourceCase = sourceCase, sampleAgeYears = age,
        -- Only anatomy is shared across calendar periods. Native dress and
        -- surface appearance retain their own source and body ownership.
        periodFromYear = 1, periodThroughYear = 9999,
        periodScope = "anatomy-only",
    })
    assert(ok, "invalid age source sample: " .. id)
end

sourceSample("post-latent-baby-0", 0,
    "appearance-scratch/advanced-character/baby-anatomy/baby_anatomy_probe.blend",
    "23c8ed6622fd5b3f768c7d26fb0fa70c35085e8ea19282a5ef8719b5b42433f8",
    "revised",
    "appearance-scratch/advanced-character/baby-anatomy/manifest.json",
    "896c39dfb953818d2bd6dc0915a1bcafd390ed57cce0c18db6366df484949b21")
sourceSample("post-latent-child-8", 8,
    "appearance-scratch/advanced-character/child-anatomy/child_anatomy_revised.blend",
    "2e0b510f4582c28bc369eae6d8b2c5675dd0ecc0b1553e1313fc770aaf0aaca0",
    "child_anatomy_revised",
    "appearance-scratch/advanced-character/child-anatomy/manifest.json",
    "cc8de5a57cad10abc8dd5f69ac4b7d4f1feb120ee8436b62143f6bc4bc7901ed")
sourceSample("post-latent-teen-15", 15, STUDY, STUDY_SHA,
    "teen_target_probe", STUDY_MANIFEST, STUDY_MANIFEST_SHA)
sourceSample("post-latent-adult-31", 31, STUDY, STUDY_SHA,
    "adult_reference", STUDY_MANIFEST, STUDY_MANIFEST_SHA)
sourceSample("post-latent-elder-72", 72, STUDY, STUDY_SHA,
    "elder_target_probe", STUDY_MANIFEST, STUDY_MANIFEST_SHA)

local function modelCandidates(calendar)
    local matches = {}
    if type(calendar) ~= "table" or calendar.status ~= "available"
        or type(calendar.currentInstant) ~= "string" then return matches end
    local year = tonumber(calendar.currentInstant:match(
        "^([0-9][0-9][0-9][0-9])%-"))
    if not whole(year, 1, 9999) then return matches end
    for _, model in pairs(candidates) do
        if year >= model.periodFromYear and year <= model.periodThroughYear then
            local detached = {}
            for key, value in pairs(model) do detached[key] = value end
            detached.status = "source-indexed-native-unapplied"
            matches[#matches + 1] = detached
        end
    end
    table.sort(matches, function(a, b)
        if a.sampleAgeYears ~= b.sampleAgeYears then
            return a.sampleAgeYears < b.sampleAgeYears
        end
        return a.id < b.id
    end)
    return matches
end

-- This is a coordinate between authored source samples. No mesh interpolation
-- or native model replacement is performed by the projection.
local function modelSelection(age, matches)
    if #matches == 0 then return nil end
    local lower, upper = matches[1], matches[#matches]
    for i = 1, #matches do
        local model = matches[i]
        if model.sampleAgeYears == age then
            lower, upper = model, model
            break
        end
        if model.sampleAgeYears < age then lower = model end
        if model.sampleAgeYears > age then upper = model; break end
    end
    local span = upper.sampleAgeYears - lower.sampleAgeYears
    return {
        status = "source-linked-native-unapplied",
        lowerId = lower.id, upperId = upper.id,
        lowerSampleAgeYears = lower.sampleAgeYears,
        upperSampleAgeYears = upper.sampleAgeYears,
        agePosition = span > 0 and (age - lower.sampleAgeYears) / span or 0,
        outsideSampleRange = age < matches[1].sampleAgeYears
            or age > matches[#matches].sampleAgeYears,
        periodScope = "anatomy-only",
    }
end

function V.resolve(rec)
    if type(rec) ~= "table" or not nonempty(rec.id)
        or not SAO.History then return nil, "person-unavailable" end
    local H = SAO.History
    local ok, hours, age, stage, scale, pace, calendar = pcall(function()
        local currentAge = H.ageOf(rec.id)
        return H.countyHours(), currentAge, H.stageOf(currentAge),
            H.heightScaleOf(rec.id), H.speedModOf(rec.id),
            H.calendarAgeOf and H.calendarAgeOf(rec.id) or nil
    end)
    if not ok or not finite(hours) or not whole(age, 0, math.huge)
        or type(stage) ~= "string" or not finite(scale) or scale < 0.5
        or scale > 1.5 or not finite(pace) or pace < 0.5 or pace > 1.5 then
        return nil, "age-projection-unavailable"
    end
    if type(calendar) == "table" and calendar.status == "available" then
        if not whole(calendar.minimumAge, 0, math.huge)
            or not whole(calendar.maximumAge, calendar.minimumAge, math.huge)
            or age < calendar.minimumAge or age > calendar.maximumAge then
            return nil, "calendar-age-conflict"
        end
    end
    local matches = modelCandidates(calendar)
    return {
        schema = V.SCHEMA, personId = rec.id, asOfCountyHours = hours,
        age = age, stage = stage, scale = scale, pace = pace,
        calendar = calendar,
        modelCandidates = matches,
        modelSelection = modelSelection(age, matches),
        modelApplied = false,
    }
end

return V
