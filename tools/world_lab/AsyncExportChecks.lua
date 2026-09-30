-- Execute the real Lua producer against a controlled asynchronous receipt seam.
-- The independent native worker probe owns encoding, threading and filesystem proof.
function RunAsyncExportChecks(Study, treatment)
    currentMap, currentSave, persisted = Config.mapName, "AsyncSave", {}
    hour = 12
    local clock, paused = 1000000, false
    getTimestampMs = function() return clock end
    isGamePaused = function() return paused end
    getSpecificPlayer = function() return {
        getModData = function() return { SAO_ObserverStarted = true } end
    } end
    SAO.Observation = { snapshot = function() return {
        status = "available", people = {}, sequence = 1,
        capturedAtUnixMs = 777, worldHours = hour
    } end }
    local tickets, channels, reservations, releases, measurements = {}, {}, 0, 0, 0
    local owner = {}
    function owner:begin(definition, save, runSession, observer, engine)
        assert(definition == Config.definitionSha256 and save == currentSave
            and observer == Config.observerSha256 and engine == Config.engineJarSha256,
            "export begin lost source provenance")
    end
    function owner:measure(value, marker, maxBytes)
        measurements = measurements + 1
        local bytes = #Study.encode(value)
        return bytes <= maxBytes and bytes or -1
    end
    function owner:reserve(kind, key)
        if channels[kind] then return 0 end
        reservations = reservations + 1
        local job = { ticket = reservations, kind = kind, key = key, status = "pending" }
        tickets[job.ticket], channels[kind] = job, job
        return job.ticket
    end
    function owner:submitLive(ticket, frame, marker, limit)
        local job = assert(tickets[ticket], "unreserved live snapshot submitted")
        job.text, job.sequence = Study.encode(frame), 0
        return "accepted"
    end
    function owner:submitArchive(ticket, frame, marker, limit, name, captured, deferred)
        local job = assert(tickets[ticket], "unreserved archive snapshot submitted")
        job.text, job.sequence, job.name = Study.encode(frame), frame.sequence, name
        job.captured, job.deferred = captured, deferred
        assert(name:find("/" .. string.format("%016d", frame.sequence) .. ".json", 1, true),
            "archive path lost exact sequence")
        return "accepted"
    end
    function owner:receiptStatus(ticket) return assert(tickets[ticket]).status end
    function owner:receiptKey(ticket) return assert(tickets[ticket]).key end
    function owner:receiptSequence(ticket) return assert(tickets[ticket]).sequence end
    function owner:receiptCompletedAt(ticket) return assert(tickets[ticket]).finished end
    function owner:receiptFailure(ticket) return "controlled export failure" end
    function owner:receiptReason(ticket) return assert(tickets[ticket]).reason or "encoded-byte-budget" end
    function owner:release(ticket)
        local job = assert(tickets[ticket], "duplicate receipt release")
        assert(job.status ~= "pending", "accepted export released before completion")
        channels[job.kind], tickets[ticket] = nil, nil
        releases = releases + 1
    end
    SAO_StudyExport = owner
    assert(Study.prepare() and Study.options())
    Events.OnInitGlobalModData.fire(true)
    assert(Study.start())
    local priorSituation = Config.situation
    local cohortSnapshots, unadmittedCohort = 0, false
    local initialPeople = { fixture = Config.sandbox["SurvivorAwareness.Population"] }
    SAO.PopulationAdmissions = { initialPeopleSnapshot = function()
        if not channels.archive or channels.archive.text ~= nil then unadmittedCohort = true end
        cohortSnapshots = cohortSnapshots + 1
        return { source = "controlled-admitted-cohort", generated = 0 }
    end }
    local needsReceipt, goalsReceipt = { existing = true }, { retained = true }
    persisted.situationReceipt = { initialNeedsApplied = needsReceipt, resourceObjectives = goalsReceipt }
    Config.situation = { initialPeopleBySite = initialPeople,
        mobileHousehold = { script = "fixture-mobile", spawn = { x = -1, y = -1, z = 0 } } }
    SAO.MobileHousehold = {}
    local priorCell = getCell
    getCell = function()
        local cell = priorCell()
        cell.getVehicles = function() return nil end
        return cell
    end
    Study.tick()
    assert(not unadmittedCohort, "cohort snapshot acquired without archive admission")
    assert(persisted.situationReceipt.phase == "spawn" and persisted.situationReceipt.script == "fixture-mobile"
        and persisted.situationReceipt.initialNeedsApplied == needsReceipt
        and persisted.situationReceipt.resourceObjectives == goalsReceipt,
        "mobile composition lost phase or retained situation receipts")
    Config.situation, getCell = { initialPeopleBySite = initialPeople }, priorCell
    assert(cohortSnapshots == 1, "admitted archive omitted the cohort snapshot")
    assert(reservations == 2 and persisted.sequence == 0, "pending archive was acknowledged")
    local archive, live = channels.archive, channels.live
    assert(archive and live and archive.text:find('"hours":12', 1, true), "source snapshot missing")
    local before = measurements
    clock, hour = clock + 5000, hour + 1
    Study.tick()
    Events.OnTickEvenPaused.fire()
    assert(reservations == 2 and measurements == before, "pending export reacquired live state")
    assert(cohortSnapshots == 1, "pending export reacquired initial people")
    paused = true
    live.status, live.finished = "published", clock
    if treatment == "foreign-live" then
        live.key = "other-session"
        assert(not pcall(Study.tick), "foreign live receipt accepted")
        return "PASS foreign live receipt refused"
    end
    Study.tick()
    assert(reservations == 2 and releases == 1, "live completion bypassed post-publication cooldown")
    assert(persisted.sequence == 0, "live completion acknowledged archive")
    clock = clock + 999
    Study.tick()
    assert(reservations == 2, "live cooldown shorter than one second")
    clock = clock + 1
    Study.tick()
    assert(reservations == 3 and channels.live, "live cooldown did not resume")
    assert(cohortSnapshots == 1, "paused live export reacquired initial people")
    if treatment == "foreign-archive" then
        archive.status, archive.finished, archive.sequence = "published", clock, 99
        assert(not pcall(Study.tick), "foreign archive sequence accepted")
        assert(persisted.sequence == 0, "foreign sequence advanced persisted acknowledgement")
        return "PASS foreign archive sequence refused"
    end
    if treatment == "failed-archive" then
        archive.status, archive.finished = "failed", clock
        assert(not pcall(Study.tick), "failed archive acknowledged")
        assert(persisted.sequence == 0, "failed archive advanced persisted acknowledgement")
        return "PASS failed archive remains unacknowledged"
    end
    archive.status, archive.finished = "published", clock
    Study.tick()
    assert(persisted.sequence == 1, "archive acknowledged wrong sequence")
    assert(Study.archiveCapture.worldHours == 12, "completion time changed captured world clock")
    Study.tick()
    assert(persisted.sequence == 1 and releases == 2, "archive completion replayed")
    channels.live.status, channels.live.finished = "published", clock
    paused = false
    Study.tick()
    assert(channels.archive and channels.archive.sequence == 2, "later archive did not retain next sequence")
    assert(cohortSnapshots == 2, "later archive omitted its cohort snapshot")
    channels.archive.status, channels.archive.finished = "deferred", clock
    paused = true
    Study.tick()
    assert(persisted.sequence == 1 and Study.archiveCapture.status == "deferred",
        "deferred archive minted acknowledgement")
    hour, clock = hour + 1, clock + 1000
    paused = false
    Study.tick()
    assert(channels.archive and channels.archive.sequence == 2, "deferred archive skipped sequence")
    assert(cohortSnapshots == 3, "archive retry omitted its cohort snapshot")
    assert(not Study.drainExports(), "stop completed with accepted archive pending")
    local afterStop = reservations
    channels.archive.status, channels.archive.finished = "published", clock
    channels.live.status, channels.live.finished = "published", clock
    assert(Study.drainExports() and persisted.sequence == 2, "stop did not acknowledge completed archive")
    clock, hour = clock + 5000, hour + 1
    Study.tick()
    assert(reservations == afterStop, "draining producer admitted new exports")
    assert(cohortSnapshots == 3, "draining producer reacquired initial people")
    assert(Study.archiveCapture.worldHours == hour - 1, "drain relabeled source world clock")
    Config.situation = priorSituation
    return "PASS async producer: admitted cohort capture, pending isolation, cooldown, exact acknowledgement, deferred recovery and stop"
end
