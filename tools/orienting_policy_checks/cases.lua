local P, O = SAO.Perception, SAO.Orienting
local results = {}
local originalClarity = SAO.Neuro.clarityOf
local originalSteadiness = SAO.Neuro.motorSteadiness
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function reset()
    O.reset()
    P.beliefs = {}
    __persisted = {}
    P.bindPersistentStore()
    __tick, __rows, __records, __requests, __clears = 100, "", {}, {}, 0
    __allow, __throw, __nativeConsumed, __policies = true, false, {}, 0
    SAO.Body.active, SAO.Body.foreign, SAO.Controller.agents = {}, {}, {}
    SAO.Controller.advanceExternalCoordination = nil
    SAO.Locomotion.jobs, ISTimedActionQueue.queues = {}, {}
    SAO.WorldSources.pendingActionFor = function() return nil end
    SAO.SourceUse = nil
    SAO.Neuro.clarityOf, SAO.Neuro.motorSteadiness = originalClarity, originalSteadiness
    SandboxVars.SurvivorAwareness.Neuroinflammation = true
    ZAO.Controller.controlled, ZAO.Mind, ZAO.StateStore, ZAO.Brain = {}, nil, nil, nil
    ZAO.Afflicted, ZAO.Crossed = nil, nil
end
local function person(id, owner)
    id = id or "a"
    local rec, b = { id = id }, __body(id)
    __records[id] = rec
    if owner == "ZAO" then
        rec.bodyOwner, rec.bodyOwnerToken = "ZAO", "living:1"
        b.data.SAOExternalOwner, b.data.SAOExternalToken, b.data.ZAOOwned = "ZAO", "living:1", true
        SAO.Body.foreign[id], ZAO.Controller.controlled[id] = b, b
    else
        SAO.Body.active[id] = b
        SAO.Controller.agents[id] = { rec = rec, state = "IDLE" }
    end
    return rec, b, { owner = owner or "SAO", bodyOwnerToken = rec.bodyOwnerToken,
        allowBodyTurn = true }
end
local function hear(id, body, rows, tick)
    __rows, __tick = rows, tick or __tick
    P.observe(id, body, __tick, false)
end
local function check(name, fn)
    reset()
    local ok, result = pcall(fn)
    if not ok then print("DETAIL " .. name .. ": " .. tostring(result)) end
    results[#results + 1] = name .. "=" .. tostring(ok and result == true)
end

check("private_fresh_sound_admitted", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1))
    local admitted = O.consider("a", b, ctx)
    local r = __requests[1]
    return admitted == true and #__requests == 1 and r.cueId == __token(1)
        and r.x == 12 and r.y == 20 and r.readiness == 1 and r.steadiness == 1
        and r.pivot == true and count(P.beliefs.a.zombies) == 0
        and count(P.beliefs.a.people) == 0 and P.beliefs.a.sounds["12,20"].source == "heard"
end)
check("timestamp_refresh_never_restarts", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1))
    assert(O.consider("a", b, ctx))
    hear("a", b, __sound(1), 120)
    return O.consider("a", b, ctx) == false and #__requests == 1
        and P.beliefs.a.sounds["12,20"].at == 120
        and P.soundCues("a", b, 120)[1].heardAt == 100
end)
check("new_pulse_same_tile_admitted", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1))
    assert(O.consider("a", b, ctx))
    hear("a", b, __sound(2), 120)
    return O.consider("a", b, ctx) == true and #__requests == 2
        and __requests[2].cueId == __token(2)
end)
check("legacy_memory_has_no_pulse", function()
    local rec, b, ctx = person()
    hear("a", b, "S:12:20:2")
    return O.consider("a", b, ctx) == false and #__requests == 0
        and P.beliefs.a.sounds["12,20"] ~= nil
end)
check("malformed_occurrences_refused", function()
    local rec, b, ctx = person()
    local rows = {
        "S:12:20:2:cue:fake", "S:12:20:2:cue:" .. __token(0),
        "S:12:20:2:cue::" .. __token(1), "S:12:20:2:cue:" .. __token(1) .. ":extra",
        "S:12:20:-1:cue:" .. __token(1), "S:12:20:1e999:cue:" .. __token(1),
        "S:12:20:2:other:" .. __token(1),
        "S:12:20:2:cue:" .. __token(1) .. "0000000000000000000000",
    }
    for i, row in ipairs(rows) do
        hear("a", b, row, 100 + (i - 1) * 20)
        if O.consider("a", b, ctx) ~= false then return false end
    end
    return #__requests == 0
end)
check("stale_acquisition_refused", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) __tick = 221
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("native_refusal_remains_retryable", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) __allow = false
    local admitted, reason = O.consider("a", b, ctx)
    if admitted ~= false or reason ~= "native-refused" then return false end
    __allow, __tick = true, 120
    return O.consider("a", b, ctx) == true and #__requests == 2
        and O.consider("a", b, ctx) == false and #__requests == 2
end)
check("native_refusal_expires_despite_refresh", function()
    local rec, b, ctx = person()
    __allow = false hear("a", b, __sound(1))
    assert(O.consider("a", b, ctx) == false)
    hear("a", b, __sound(1), 180) O.consider("a", b, ctx)
    __allow = true hear("a", b, __sound(1), 221)
    return O.consider("a", b, ctx) == false and #__requests == 2
end)
check("native_throw_never_consumes", function()
    local rec, b, ctx = person()
    __throw = true hear("a", b, __sound(1))
    assert(O.consider("a", b, ctx) == false)
    __throw = false __tick = 120
    return O.consider("a", b, ctx) == true and #__requests == 2
end)
check("nonboolean_admission_refused", function()
    local rec, b, ctx = person()
    __allow = "true" hear("a", b, __sound(1))
    return O.consider("a", b, ctx) == false and #__requests == 1
end)
check("bind_clears_runtime_authority", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1))
    P.bindPersistentStore()
    return #P.soundCues("a", b, 100) == 0 and O.consider("a", b, ctx) == false
        and #__requests == 0 and P.beliefs.a.sounds["12,20"].at == 100
end)
check("restored_sound_cannot_mint_authority", function()
    local rec, b, ctx = person()
    P.beliefs = {}
    __persisted = { a = { zombies = {}, people = {}, places = {}, factions = {},
        sounds = { ["12,20"] = { x = 12, y = 20, dist = 2, at = 100,
            source = "heard", kind = "unknown", cueId = __token(1), heardAt = 100 } },
        lastScanAt = 100, scanCount = 1 } }
    P.bindPersistentStore()
    return O.consider("a", b, ctx) == false and #__requests == 0
        and P.beliefs.a.sounds["12,20"] ~= nil
end)
check("exact_body_required", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1))
    local replacement = __body("a")
    SAO.Body.active.a = replacement
    return O.consider("a", b, ctx) == false
        and O.consider("a", replacement, ctx) == false and #__requests == 0
        and #P.soundCues("a", replacement, 100) == 0
end)
check("owner_token_mismatch_refused", function()
    local rec, b, ctx = person("a", "ZAO")
    hear("a", b, __sound(1)) ctx.bodyOwnerToken = "living:old"
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("native_owner_mark_mismatch_refused", function()
    local rec, b, ctx = person("a", "ZAO")
    hear("a", b, __sound(1)) b.data.SAOExternalToken = "living:old"
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("external_owner_excludes_survivor", function()
    local rec, b, ctx = person("a", "ZAO")
    hear("a", b, __sound(1))
    local wrong = { owner = "SAO", bodyOwnerToken = rec.bodyOwnerToken, allowBodyTurn = true }
    return O.consider("a", b, wrong) == false and #__requests == 0
        and O.consider("a", b, ctx) == true
end)
check("double_controller_refused", function()
    local rec, b, ctx = person("a", "ZAO")
    hear("a", b, __sound(1)) SAO.Controller.agents.a = { rec = rec, state = "IDLE" }
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("person_private_acquisition", function()
    local rec, b, ctx = person("a")
    local other, body, otherCtx = person("b")
    hear("a", b, __sound(1))
    return O.consider("b", body, otherCtx) == false and #__requests == 0
end)
for _, field in ipairs({ "sleeping", "dead", "attack", "aim", "climb", "rope" }) do
    check("native_" .. field .. "_refused", function()
        local rec, b, ctx = person()
        hear("a", b, __sound(1)) b[field] = true
        return O.consider("a", b, ctx) == false and #__requests == 0
    end)
end
check("detached_native_body_refused", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) b.attached = false
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("missing_square_refused", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) b.square = nil
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("native_vehicle_refused", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) b.vehicle = {}
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("nonshell_body_refused", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) b.shell = false
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("source_owner_read_is_nonmutating", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) rec.worldSourceReservation = "reserved:1"
    SAO.WorldSources.pendingActionFor = function() error("query repaired state") end
    return O.consider("a", b, ctx) == false and #__requests == 0
        and rec.worldSourceReservation == "reserved:1"
end)
check("queued_work_yields_and_clears", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) assert(O.consider("a", b, ctx))
    ISTimedActionQueue.queues[b] = { queue = { "native-transfer" } }
    hear("a", b, __sound(2), 120)
    return O.consider("a", b, ctx) == false and #__requests == 1 and __clears == 1
        and ISTimedActionQueue.queues[b].queue[1] == "native-transfer"
end)
check("route_only_admits_head_without_mutation", function()
    local rec, b, ctx = person()
    local job = { body = b, goal = { x = 88, y = 99, z = 0 }, done = false, lastVerdict = "Working" }
    SAO.Locomotion.jobs.a = job
    hear("a", b, __sound(1))
    return O.consider("a", b, ctx) == true and __requests[1].pivot == false
        and SAO.Locomotion.jobs.a == job and job.goal.x == 88 and job.goal.y == 99
        and job.done == false and job.lastVerdict == "Working"
end)
check("neuro_state_shapes_response", function()
    local rec, b, ctx = person()
    rec.neuroinflammation = 0.8
    hear("a", b, __sound(1)) assert(O.consider("a", b, ctx))
    local first = __requests[1]
    rec.neuroinflammation = 0.2
    hear("a", b, __sound(2), 120) assert(O.consider("a", b, ctx))
    return math.abs(first.readiness - 0.2) < 0.00001
        and math.abs(first.steadiness - 0.44) < 0.00001
        and __requests[2].readiness > first.readiness
        and __requests[2].steadiness > first.steadiness
end)
check("neuro_disabled_uses_existing_projection", function()
    local rec, b, ctx = person()
    rec.neuroinflammation = 0.8
    SandboxVars.SurvivorAwareness.Neuroinflammation = false
    hear("a", b, __sound(1)) assert(O.consider("a", b, ctx))
    return __requests[1].readiness == 1 and __requests[1].steadiness == 1
end)
check("invalid_projection_refused", function()
    local rec, b, ctx = person()
    SAO.Neuro.motorSteadiness = function() return 0 / 0 end
    hear("a", b, __sound(1))
    return O.consider("a", b, ctx) == false and #__requests == 0
end)
check("private_cue_query_detached", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1))
    local copy = P.soundCues("a", b, 100)
    copy[1].x, copy[1].heardAt = 999, 0
    return O.consider("a", b, ctx) == true and __requests[1].x == 12
        and P.beliefs.a.sounds["12,20"].cueId == nil
end)
check("cue_retention_bounded", function()
    local rec, b, ctx = person()
    local rows = {}
    for index = 1, 100 do rows[index] = __sound(index, 10 + index) end
    hear("a", b, table.concat(rows, "|"))
    return #P.soundCues("a", b, 100) == 64
end)
check("pending_cue_keeps_original_coordinates", function()
    local rec, b, ctx = person()
    __allow = false hear("a", b, __sound(1)) O.consider("a", b, ctx)
    __allow = true hear("a", b, __sound(1, 99), 120)
    return O.consider("a", b, ctx) == true and __requests[2].x == 12
end)
check("forget_preserves_native_consumption", function()
    local rec, b, ctx = person()
    hear("a", b, __sound(1)) assert(O.consider("a", b, ctx))
    O.forget("a", b)
    return O.consider("a", b, ctx) == false and #__requests == 2
        and __clears == 1
end)

local function driverPerson(terminal, options, execute)
    local rec, b, ctx = person("a", "ZAO")
    local provider = {
        options = function() return options or {} end,
        execute = execute or function(option)
            __policies = __policies + 1
            return false, option and option.activity or "idle"
        end,
    }
    if terminal == "afflicted" then ZAO.Afflicted = provider else ZAO.Crossed = provider end
    local state = { terminalState = terminal }
    hear("a", b, __sound(1))
    return rec, b, state, { execution = { canMove = true } }
end
for _, terminal in ipairs({ "afflicted", "crossed" }) do
    check(terminal .. "_driver_admits_after_own_policy", function()
        local rec, b, state, mind = driverPerson(terminal)
        local committed, performed = ZAO.Driver.step("a", b, state, mind, 100, 100 / 9000)
        return committed == false and performed == "idle" and __policies == 1
            and #__requests == 1 and __requests[1].pivot == true
            and SAO.Controller.agents.a == nil and SAO.Body.foreign.a == b
    end)
end
check("driver_queue_precedes_orientation", function()
    local rec, b, state, mind = driverPerson("crossed")
    ISTimedActionQueue.queues[b] = { queue = { "transfer" } }
    local committed, performed = ZAO.Driver.step("a", b, state, mind, 100, 100 / 9000)
    return committed == true and performed == "idle" and __policies == 0
        and #__requests == 0 and #ISTimedActionQueue.queues[b].queue == 1
end)
check("driver_source_precedes_orientation", function()
    local rec, b, state, mind = driverPerson("afflicted")
    local reservation = { id = "source:1", phase = "transferring", nativeUseOwner = "ZAO.Diet" }
    rec.worldSourceReservation = reservation.id
    SAO.WorldSources.pendingActionFor = function() return reservation end
    local advances = 0
    SAO.SourceUse = { tick = function() advances = advances + 1 return "pending" end }
    local committed, performed = ZAO.Driver.step("a", b, state, mind, 100, 100 / 9000)
    return committed == true and performed == "acquiring-food" and advances == 1
        and __policies == 0 and #__requests == 0 and rec.worldSourceReservation == "source:1"
end)
check("driver_route_admits_only_head", function()
    local option = { id = "route", kind = "route", activity = "returning-home", score = 30 }
    local rec, b, state, mind = driverPerson("crossed", { option })
    local route = { kind = "home", x = 50, y = 60 }
    state.driver = { route = route, currentActivity = "returning-home", revision = 0 }
    local job = { body = b, done = false, goal = { x = 50, y = 60 } }
    SAO.Locomotion.jobs.a = job
    ZAO.Driver.step("a", b, state, mind, 100, 100 / 9000)
    return #__requests == 1 and __requests[1].pivot == false and state.driver.route == route
        and SAO.Locomotion.jobs.a == job and job.goal.x == 50
end)
check("driver_combat_yields_orientation", function()
    local option = { id = "combat", kind = "combat", activity = "combat", score = 990, interruptsWork = true }
    local rec, b, state, mind = driverPerson("crossed", { option })
    assert(O.consider("a", b, { owner = "ZAO", bodyOwnerToken = rec.bodyOwnerToken, allowBodyTurn = true }))
    ZAO.Driver.step("a", b, state, mind, 100, 100 / 9000)
    return #__requests == 1 and __clears == 1 and __policies == 1
        and state.driver.currentActivity == "combat"
end)
check("driver_new_timed_action_prevents_glance", function()
    local option = { id = "gather", kind = "gather", activity = "gather", score = 30 }
    local rec, b, state, mind = driverPerson("afflicted", { option }, function()
        ISTimedActionQueue.queues[SAO.Body.foreign.a] = { queue = { "new-work" } }
        return true, "gather"
    end)
    ZAO.Driver.step("a", b, state, mind, 100, 100 / 9000)
    return #__requests == 0 and #ISTimedActionQueue.queues[b].queue == 1
end)
__orientingResults = table.concat(results, "\n")
