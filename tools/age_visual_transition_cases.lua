-- Isolated production-Kahlua age presentation cases. No game session is made.
local ages, hours, appearanceCalls, ageReads = {}, 0, {}, 0
local failures, checks = {}, 0

local function event()
    local e = { hooks = {} }
    function e.Add(fn) e.hooks[#e.hooks + 1] = fn end
    function e.Remove(fn)
        for i = #e.hooks, 1, -1 do
            if e.hooks[i] == fn then table.remove(e.hooks, i) end
        end
    end
    function e.fire()
        for _, fn in ipairs(e.hooks) do fn() end
    end
    return e
end

Events = { OnSave = event(), EveryTenMinutes = event() }
SAO = {
    Log = { line = function() end },
    Identity = { get = function(id) return nil end },
    History = {
        countyHours = function() return hours end,
        ageOf = function(id) ageReads = ageReads + 1; return ages[id] end,
        countyInstant = function()
            return tostring(1993 + math.floor(hours / (365 * 24)))
                .. "-07-09T00:00:00"
        end,
        stageOf = function(age) return age < 18 and "child"
            or age < 61 and "adult" or "elder" end,
        heightScaleOf = function(id) return ages[id] < 18 and 0.80 or 1.0 end,
        speedModOf = function(id) return ages[id] < 18 and 0.70
            or ages[id] > 68 and 0.90 or 1.0 end,
        calendarAgeOf = function(id)
            local age = ages[id]
            local year = 1993 + math.floor(hours / (365 * 24))
            return { status = "available", minimumAge = age - 1,
                maximumAge = age, birthYear = year - age,
                currentInstant = tostring(year) .. "-07-09T00:00:00" }
        end,
    },
    Appearance = { applyAge = function(rec, body)
        appearanceCalls[body] = (appearanceCalls[body] or 0) + 1
        return true
    end },
}
SAOJavaBridge = {
    getBodyScale = function(_, body)
        body.scaleReads = (body.scaleReads or 0) + 1
        return body.scale
    end,
    setBodyScale = function(_, body, scale)
        body.scale = scale
        return "scale=" .. tostring(scale)
    end,
}

local records = {}
SAO.Identity.get = function(id) return records[id] end

local function body()
    local b = { scale = 1.0, pace = 1.0, visual = {}, model = "native" }
    function b:getSpeedMod()
        self.paceReads = (self.paceReads or 0) + 1
        return self.pace
    end
    function b:setSpeedMod(value) self.pace = value end
    function b:getHumanVisual() return self.visual end
    return b
end

local function check(name, condition)
    checks = checks + 1
    if condition then print("PASS " .. name)
    else print("FAIL " .. name); failures[#failures + 1] = name end
end

function ageVisualTransitionCases()
    local V, B = SAO.AgeVisual, SAO.Body
    local rec = { id = "person-17", name = "Same Person" }
    records[rec.id], ages[rec.id] = rec, 17
    local first = body()
    B.active[rec.id] = first
    local resolved = V.resolve(rec)
    check("identity/stable-current-county", resolved and resolved.personId == rec.id
        and resolved.age == 17 and resolved.stage == "child"
        and resolved.asOfCountyHours == 0 and resolved.calendar.birthYear == 1976
        and V.resolve(rec).age == resolved.age)
    local original = resolved.modelCandidates
    check("source/five-authored-ages", #original == 5
        and original[1].id == "post-latent-baby-0"
        and original[1].sampleAgeYears == 0
        and original[2].id == "post-latent-child-8"
        and original[2].sampleAgeYears == 8
        and original[3].id == "post-latent-teen-15"
        and original[3].sampleAgeYears == 15
        and original[4].id == "post-latent-adult-31"
        and original[4].sampleAgeYears == 31
        and original[5].id == "post-latent-elder-72"
        and original[5].sampleAgeYears == 72)
    check("source/pinned-index-and-archive", original[1].sourceIndexSha256
        == "579ac9032e21e37ca3616876d181e443aeb0e74411a39e93d9032d8fd83cbdad"
        and original[1].archiveSha256
        == "b0404887136d1a178646becbc6e8debe155069a735fca0097db8b97ca646464a"
        and original[2].artifactSha256
        == "2e0b510f4582c28bc369eae6d8b2c5675dd0ecc0b1553e1313fc770aaf0aaca0"
        and original[3].artifactSha256
        == "7de10d43b59f46cef6b3a369b7f9dd1dcd905a914492c3edf844fb2ff46d1b57"
        and original[1].ageInputsSha256
        == "3c45e38d653d93ec86a15d329a70b280cf730887f6ecece882a09d22be72a66f")
    check("source/cases-and-manifests", original[1].sourceCase == "revised"
        and original[1].sourceManifestSha256
            == "896c39dfb953818d2bd6dc0915a1bcafd390ed57cce0c18db6366df484949b21"
        and original[2].sourceCase == "child_anatomy_revised"
        and original[2].sourceManifestSha256
            == "cc8de5a57cad10abc8dd5f69ac4b7d4f1feb120ee8436b62143f6bc4bc7901ed"
        and original[3].sourceCase == "teen_target_probe"
        and original[4].sourceCase == "adult_reference"
        and original[5].sourceCase == "elder_target_probe"
        and original[5].sourceManifestSha256
            == "b327de27269db6f24b51d428fe3e414cf759f8146ac9f74d7ba2d855f8c04788"
        and original[1].status == "source-indexed-native-unapplied"
        and original[5].periodScope == "anatomy-only")
    check("age/continuous-sample-position", resolved.modelSelection
        and resolved.modelSelection.lowerId == "post-latent-teen-15"
        and resolved.modelSelection.upperId == "post-latent-adult-31"
        and math.abs(resolved.modelSelection.agePosition - 0.125) < 0.00001
        and resolved.modelSelection.periodScope == "anatomy-only")
    check("body/native-model-authority", resolved.modelApplied == false
        and first.model == "native")
    B.refreshAge(rec, first)
    check("loaded/child-metrics", first.scale == 0.80 and first.pace == 0.70
        and appearanceCalls[first] == 1 and rec.id == "person-17")
    B.refreshAge(rec, first)
    check("loaded/same-age-idempotent", appearanceCalls[first] == 1
        and first.scale == 0.80 and first.pace == 0.70)

    local candidate = {}
    for key, value in pairs(original[3]) do candidate[key] = value end
    candidate.id = "fixture-1993-teen-15"
    candidate.periodFromYear, candidate.periodThroughYear = 1993, 1993
    local offered = V.registerCandidate(candidate)
    local pending = V.resolve(rec)
    check("period/source-bound-local-sample", offered == true
        and #pending.modelCandidates == 6
        and pending.modelCandidates[3].id == "fixture-1993-teen-15"
        and pending.modelCandidates[3].sampleAgeYears == 15
        and pending.modelSelection.lowerId == "post-latent-teen-15"
        and pending.modelSelection.upperId == "post-latent-adult-31"
        and pending.modelApplied == false and first.model == "native")
    ages[rec.id] = 15
    local exactPeriodSample = V.resolve(rec)
    check("period/exact-age-source-tie", exactPeriodSample
        and exactPeriodSample.modelSelection.lowerId == "fixture-1993-teen-15"
        and exactPeriodSample.modelSelection.upperId == "fixture-1993-teen-15"
        and exactPeriodSample.modelSelection.agePosition == 0)
    ages[rec.id] = 17
    candidate.artifactSha256 = string.rep("0", 64)
    check("source/registered-copy-stable", V.resolve(rec).modelCandidates[3]
        .artifactSha256 == original[3].artifactSha256)
    check("source/invalid-or-duplicate-refused", V.registerCandidate({}) == false
        and V.registerCandidate(candidate) == false)
    local calendarOf = SAO.History.calendarAgeOf
    SAO.History.calendarAgeOf = function()
        return { status = "unavailable", reason = "calendar-unavailable" }
    end
    local withoutCalendar = V.resolve(rec)
    check("calendar/unavailable-keeps-native-age", withoutCalendar
        and withoutCalendar.age == 17 and #withoutCalendar.modelCandidates == 0
        and withoutCalendar.modelSelection == nil
        and withoutCalendar.modelApplied == false)
    SAO.History.calendarAgeOf = function()
        return { status = "available", currentInstant = "1993-07-09T00:00:00",
            minimumAge = 18, maximumAge = 18 }
    end
    local conflict, conflictReason = V.resolve(rec)
    check("calendar/conflict-refused", conflict == nil
        and conflictReason == "calendar-age-conflict")
    SAO.History.calendarAgeOf = calendarOf

    hours = 365 * 24
    ages[rec.id] = 18
    SAO.History.calendarAgeOf = function()
        return { status = "available", currentInstant = "1994-07-09T00:00:00",
            minimumAge = 17, maximumAge = 17 }
    end
    Events.EveryTenMinutes.fire()
    check("calendar/retry-after-temporary-conflict", first.scale == 0.80
        and first.pace == 0.70 and appearanceCalls[first] == 1)
    SAO.History.calendarAgeOf = calendarOf
    Events.EveryTenMinutes.fire()
    check("growth/adult-reset", first.scale == 1.0 and first.pace == 1.0
        and appearanceCalls[first] == 2 and rec.id == "person-17"
        and rec.name == "Same Person")
    local afterYear = V.resolve(rec)
    check("period/model-not-carried-forward", #afterYear.modelCandidates == 5
        and afterYear.modelCandidates[4].id == "post-latent-adult-31"
        and afterYear.modelSelection.lowerId == "post-latent-teen-15"
        and afterYear.modelSelection.upperId == "post-latent-adult-31"
        and math.abs(afterYear.modelSelection.agePosition - 0.1875) < 0.00001)
    local reads, scaleReads, paceReads = ageReads, first.scaleReads, first.paceReads
    Events.EveryTenMinutes.fire()
    check("growth/event-idempotent", appearanceCalls[first] == 2
        and ageReads == reads and first.scaleReads == scaleReads
        and first.paceReads == paceReads)

    hours = 0
    ages[rec.id] = 17
    local backwards, reason = B.refreshAge(rec, first)
    check("clock/backward-refused", backwards == false
        and reason == "age-clock-rewound" and first.scale == 1.0
        and first.pace == 1.0 and appearanceCalls[first] == 2)

    hours = 2 * 365 * 24
    ages[rec.id] = 19
    local replacement = body()
    B.active[rec.id] = replacement
    B.refreshAge(rec, replacement)
    check("reload/current-person-no-old-shell", replacement.scale == 1.0
        and replacement.pace == 1.0 and appearanceCalls[replacement] == 1
        and rec.id == "person-17")

    local custom = { id = "person-custom" }
    records[custom.id], ages[custom.id] = custom, 12
    local chosen = body()
    B.active[custom.id] = chosen
    B.refreshAge(custom, chosen)
    chosen.scale, chosen.pace = 0.88, 0.81
    hours = 3 * 365 * 24
    ages[custom.id] = 13
    B.refreshAge(custom, chosen)
    check("choice/native-values-preserved", chosen.scale == 0.88
        and chosen.pace == 0.81 and appearanceCalls[chosen] == 2)

    local foreign = { id = "person-foreign" }
    records[foreign.id], ages[foreign.id] = foreign, 12
    local other = body()
    B.foreign[foreign.id] = other
    Events.EveryTenMinutes.fire()
    check("ownership/foreign-not-periodic", other.scale == 1.0
        and other.pace == 1.0 and appearanceCalls[other] == nil)

    -- The study ages are coordinates on continuous H.ageOf, not new stages.
    local sampleCases = {
        { 1, "post-latent-baby-0", "post-latent-child-8", 0.125, false },
        { 8, "post-latent-child-8", "post-latent-child-8", 0, false },
        { 15, "post-latent-teen-15", "post-latent-teen-15", 0, false },
        { 31, "post-latent-adult-31", "post-latent-adult-31", 0, false },
        { 72, "post-latent-elder-72", "post-latent-elder-72", 0, false },
        { 90, "post-latent-elder-72", "post-latent-elder-72", 0, true },
    }
    for _, sample in ipairs(sampleCases) do
        ages[rec.id] = sample[1]
        local view = V.resolve(rec)
        local selected = view and view.modelSelection
        check("age/sample-" .. tostring(sample[1]), selected
            and selected.lowerId == sample[2]
            and selected.upperId == sample[3]
            and math.abs(selected.agePosition - sample[4]) < 0.00001
            and selected.outsideSampleRange == sample[5]
            and view.modelApplied == false)
    end
    return tostring(checks) .. ":" .. table.concat(failures, ",")
end
