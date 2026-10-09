-- Installed Kahlua runs the production Body, Locomotion, Communication,
-- CrossedTransfer and companion functions against controlled native handles.
local people, reservations, terminalStates = {}, {}, {}
local captureSequence = 0
local clockTick = 1
local horseCalls, cancelCalls, cancelAfterTerminal = 0, 0, false
local sourceCloseCalls, queueClearCalls, deathCalls, zaoAccepts = 0, 0, 0, 0
local player = { dead = false }
local secondPlayer
function player:isDead() return self.dead end
function player:getCurrentSquare() return {} end
local events = function() return { Add = function() end, Remove = function() end } end
Events = { OnSave = events(), OnGameStart = events(), OnTick = events() }
ISTimedActionQueue = { queues = {}, clear = function() queueClearCalls = queueClearCalls + 1 end }
SAO = {
    Log = { line = function() end },
    History = { ticks = function() return clockTick end },
    Identity = { get = function(id) return people[tostring(id)] end,
        all = function() return people end },
    Participants = { player = function(slot) if slot == 0 then return player end end },
    Standing = { playerKey = function(p) if p == player then return "player:operator" end end },
    WorldSources = { pendingActionFor = function(id) return reservations[id] end },
    BodySnapshot = {
        capture = function(rec, body)
            captureSequence = captureSequence + 1
            return { version = 4, hours = 1, facts = {}, marker = body.id,
                sequence = captureSequence }
        end,
        valid = function(captured) return type(captured) == "table" end,
        commit = function(rec, captured)
            rec.hibernation = captured
            rec.bodyCheckpointFailure = nil
        end,
    },
    Pharmacology = { enterDormancy = function() return true end },
    Controller = { agents = {}, drop = function(id) SAO.Controller.agents[id] = nil end,
        observeExternalDeath = function(id, body, owner)
            local rec = people[id]
            if not rec or not body.dead or rec.bodyOwner ~= owner
                or SAO.Body.foreign[id] ~= body then return false end
            deathCalls = deathCalls + 1
            rec.dead = true
            SAO.Body.foreign[id] = nil
            rec.bodyOwner, rec.bodyOwnerToken = nil, nil
            return true
        end },
    Animals = { orderTravel = function()
        horseCalls = horseCalls + 1
        return true
    end, cancelTravel = function() end },
    SourceUse = { closeForOwnershipTransfer = function()
        sourceCloseCalls = sourceCloseCalls + 1
        return true
    end },
}
ZAO = { StateStore = { read = function(id) return terminalStates[id] end },
    Controller = { acceptExternal = function(id, body, token, terminal)
        local rec = people[id]
        if rec and rec.bodyOwner == "ZAO" and rec.bodyOwnerToken == token
            and (terminal == "crossed" or terminal == "afflicted") then
            zaoAccepts = zaoAccepts + 1
            return true
        end
        return false
    end } }
SAOJavaBridge = {
    isShell = function(_, body) return body.shell == true end,
    isShellUnloaded = function(_, body) return body.unloaded == true end,
    canReleaseShell = function(_, body)
        return body.vehicle == nil and body.nativeCount == 0
    end,
    isInventoryOf = function() return false end,
    removeShell = function(_, body) body.removed = true return true end,
    validateHibernation = function(_, saved) return saved and saved.version == 4 end,
    moveTo = function(_, body)
        body.moveStarted = (body.moveStarted or 0) + 1
        return "MOVE_STARTED route=" .. tostring(body.moveStarted)
    end,
    moveToPaced = function(self, body) return self:moveTo(body) end,
    tickMove = function() return "MOVING" end,
    moveProgress = function() return "MOVE_PROGRESS@1@5@5@0" end,
    cancelMove = function(_, body)
        cancelCalls = cancelCalls + 1
        if body.expectResult and SAO.CompanionExecution
            and SAO.CompanionExecution._fixture then
            local row = SAO.CompanionExecution._fixture.result(body.expectResult.grant,
                body.expectResult.request)
            if row and row.status == "interrupted" then
                cancelAfterTerminal = true
            end
        end
    end,
}
function getSpecificPlayer(slot)
    if slot == 0 then return player end
    if slot == 1 then return secondPlayer end
end

local function makeBody(id)
    local b = { id = id, shell = true, nativeCount = 0,
        data = { SAOPersonId = id }, inventory = {}, dead = false }
    function b:isDead() return self.dead end
    function b:getCurrentSquare() return {} end
    function b:getInventory() return self.inventory end
    function b:getModData() return self.data end
    function b:getCharacterActions()
        local owner = self
        return { size = function() return owner.nativeCount end,
            isEmpty = function() return owner.nativeCount == 0 end }
    end
    function b:getVehicle() return self.vehicle end
    function b:getX() return 0 end
    function b:getY() return 0 end
    function b:getZ() return 0 end
    function b:removeFromWorld() self.removed = true end
    function b:removeFromSquare() self.removed = true end
    return b
end

local function person(id)
    local rec, body = { id = id, dead = false }, makeBody(id)
    people[id] = rec
    SAO.Body.active[id] = body
    SAO.Controller.agents[id] = { rec = rec, companioning = true }
    return rec, body
end

local function principal()
    return { verified = true, peerId = "namedpeer", actorId = "actor1",
        bindingId = "binding1", sessionId = "session1", bindingEpoch = 4,
        playerKey = "player:operator", expiresAtTick = 1000 }
end

local passed, failed = 0, {}
local function check(name, value)
    if value then passed = passed + 1; print("PASS " .. name)
    else failed[#failed + 1] = name; print("FAIL " .. name) end
end

function companionExecutionCases()
    local C, Body, T, L, Comm = SAO.CompanionExecution, SAO.Body,
        SAO.CrossedTransfer, SAO.Locomotion, SAO.Communication
    local fixture = C._fixture
    local p = principal()

    local denied, reason = C.requestGrant({ namedPeer = "namedpeer" })
    check("live_grant_peer_auth_closed", denied == false and reason == "peer-auth-unavailable")
    denied, reason = C.requestAttempt({ grantId = "invented" })
    check("live_attempt_peer_auth_closed", denied == false and reason == "peer-auth-unavailable")
    denied, reason = C.requestRevoke({ grantId = "invented" })
    check("live_revoke_peer_auth_closed", denied == false and reason == "peer-auth-unavailable")
    denied, reason = C.commandResult("invented", "request")
    check("live_result_peer_auth_closed", denied == false and reason == "peer-auth-unavailable")
    local invalidRec = person("person-invalid-request")
    denied, reason = fixture.rawClaim(p, { grantId = "grant-invalid",
        personId = invalidRec.id })
    check("claim_requires_exact_request_id", denied == false and reason == "invalid-grant")

    local hrec, hbody = person("horse-control")
    check("ordinary_locomotion_still_uses_horse", L.order(hrec.id, hbody, 5, 5, 0, false)
        and L.jobs[hrec.id].mode == "horse" and horseCalls == 1)
    L.cancel(hrec.id)
    local slotRec, slotBody = person("person-local-slot")
    secondPlayer = slotBody
    denied, reason = fixture.claim(p, { grantId = "grant-local-slot", personId = slotRec.id })
    check("native_local_slot_cannot_be_companion_body", denied == false
        and reason == "separate-body-unavailable" and slotRec.bodyOwner == nil)
    secondPlayer = nil
    local stampRec, stampBody = person("person-wrong-stamp")
    stampBody.data.SAOPersonId = "someone-else"
    denied, reason = fixture.claim(p, { grantId = "grant-wrong-stamp", personId = stampRec.id })
    check("native_person_stamp_required", denied == false
        and reason == "living-native-body-unavailable" and stampRec.bodyOwner == nil)
    local rec, body = person("person-one")
    local ok, receipt = fixture.claim(p, { grantId = "grant-one", personId = rec.id,
        requestId = "claim-one" })
    check("separate_native_body_claimed", ok and rec.bodyOwner == "companion:grant-one"
        and Body.active[rec.id] == nil and Body.foreign[rec.id] == body
        and body ~= player and Comm.executionOwners[rec.bodyOwner] ~= nil)
    check("claim_receipt_omits_custody_token", type(receipt) == "table"
        and receipt.status == "claimed" and receipt.token == nil
        and receipt.bodyOwnerToken == nil and receipt.grantId == "grant-one")
    denied, reason = Body.returnExternal(rec, rec.bodyOwner, rec.bodyOwnerToken)
    check("live_lease_cannot_return_early", denied == false
        and reason == "return-not-requested" and Body.foreign[rec.id] == body)
    local adapter = Comm.executionOwners[rec.bodyOwner]
    check("companion_adapter_replacement_refused",
        Comm.registerExecutionOwner(rec.bodyOwner, { bodyFor = function() end }) == false
            and Comm.executionOwners[rec.bodyOwner] == adapter)
    local zaoA, zaoB = { bodyFor = function() end }, { bodyFor = function() end }
    check("zao_registration_unchanged", Comm.registerExecutionOwner("ZAO", zaoA)
        and Comm.registerExecutionOwner("ZAO", zaoB)
        and Comm.executionOwners.ZAO == zaoB)
    local bad = principal(); bad.sessionId = "other-session"
    denied, reason = fixture.attempt(bad, "grant-one", "move-one",
        { x = 5, y = 5, z = 0 })
    check("session_binding_exact", denied == false and reason == "session-binding-mismatch")
    local horsesBefore = horseCalls
    ok, receipt = fixture.attempt(p, "grant-one", "move-one", { x = 5, y = 5, z = 0 })
    check("foot_route_excludes_horse", ok and receipt.status == "running"
        and horseCalls == horsesBefore and L.jobs[rec.id].mode == nil
        and body.moveStarted == 1)
    body.expectResult = { grant = "grant-one", request = "move-one" }
    ok, receipt = fixture.revoke(p, "grant-one", "grant-expired")
    local terminal = fixture.result("grant-one", "move-one")
    check("terminal_written_before_exact_route_cancel", ok and terminal
        and terminal.status == "interrupted"
        and cancelAfterTerminal and L.jobs[rec.id] == nil and cancelCalls >= 2)
    denied, reason = fixture.attempt(p, "grant-one", "late-move", { x = 5, y = 5, z = 0 })
    check("expired_grant_cannot_attempt", denied == false and reason == "grant-expired")
    ok, receipt = fixture.revoke(p, "grant-one", "duplicate-revoke")
    check("repeated_revoke_keeps_terminal_receipt", ok and receipt
        and receipt.status == "return-pending" and receipt.reason == "grant-expired")
    C.onTick()
    check("ready_return_checkpointed_and_readoptable", rec.bodyOwner == nil
        and rec.bodyOwnerToken == nil and Body.foreign[rec.id] == nil
        and body.removed == true and rec.hibernation.marker == rec.id
        and rec.companionReturn == nil)

    local qrec, qbody = person("person-queue")
    check("queue_person_claimed", fixture.claim(p, { grantId = "grant-queue",
        personId = qrec.id, requestId = "claim-queue" }) == true)
    ISTimedActionQueue.queues[qbody] = { queue = { { Type = "Unrelated" } } }
    fixture.revoke(p, "grant-queue", "grant-expired")
    for _ = 1, 91 do C.onTick() end
    local blockedResult = fixture.result("grant-queue", "returnResult")
    check("unrelated_queue_blocks_without_cancellation", qrec.bodyOwner == "companion:grant-queue"
        and qrec.companionReturn.status == "return-blocked"
        and Comm.executionOwners["companion:grant-queue"] ~= nil
        and blockedResult and blockedResult.status == "return-blocked"
        and blockedResult.bodyOwnerToken == nil and blockedResult.token == nil
        and #ISTimedActionQueue.queues[qbody].queue == 1
        and queueClearCalls == 0 and qbody.removed ~= true)
    ISTimedActionQueue.queues[qbody] = nil
    C.onTick()
    check("blocked_return_retries_after_readiness", qrec.bodyOwner == nil
        and qrec.hibernation ~= nil and qbody.removed == true)

    local srec, sbody = person("person-source")
    fixture.claim(p, { grantId = "grant-source", personId = srec.id })
    reservations[srec.id] = "unrelated-reservation"
    fixture.revoke(p, "grant-source", "grant-expired")
    C.onTick()
    check("source_reservation_blocks_without_closing", srec.bodyOwner == "companion:grant-source"
        and sourceCloseCalls == 0 and reservations[srec.id] == "unrelated-reservation")
    reservations[srec.id] = nil
    sbody.vehicle = {}
    C.onTick()
    check("vehicle_blocks_without_ejection", srec.bodyOwner == "companion:grant-source"
        and sbody.vehicle ~= nil and sbody.removed ~= true)
    sbody.vehicle = nil
    C.onTick()
    check("source_and_vehicle_release_after_clear", srec.bodyOwner == nil
        and sbody.removed == true)

    local zrec, zbody = person("person-zao")
    fixture.claim(p, { grantId = "grant-zao", personId = zrec.id })
    terminalStates[zrec.id] = { terminalState = "crossed" }
    local held, why = T.begin(zrec.id, zbody, "zao-token", 3, "crossed")
    local journal = zrec.zaoTransferPending
    check("terminal_transition_held_under_companion", held == false
        and why == "companion-release-pending" and journal.token == "zao-token"
        and zrec.bodyOwner == "companion:grant-zao")
    held, why = T.begin(zrec.id, zbody, "zao-token", 3, "crossed")
    check("repeated_pathogen_notice_same_journal", held == false
        and why == "companion-release-pending" and zrec.zaoTransferPending == journal)
    held, why = T.begin(zrec.id, zbody, "different-token", 3, "crossed")
    check("conflicting_pathogen_token_refused", held == false
        and why == "another-transfer-pending" and zrec.zaoTransferPending == journal)
    C.onTick()
    check("companion_released_then_zao_owns_same_person", zrec.bodyOwner == "ZAO"
        and zrec.bodyOwnerToken == "zao-token" and zrec.zaoTransferPending == nil
        and zrec.hibernation.marker == zrec.id and zaoAccepts == 1)
    T.resumePending()
    check("zao_resume_idempotent", zrec.bodyOwner == "ZAO" and zaoAccepts == 1)

    local rrec, rbody = person("person-reload")
    fixture.claim(p, { grantId = "grant-reload", personId = rrec.id })
    ISTimedActionQueue.queues[rbody] = { queue = { { Type = "OtherAction" } } }
    terminalStates[rrec.id] = { terminalState = "afflicted" }
    T.begin(rrec.id, rbody, "zao-reload-token", 4, "afflicted")
    local beforeReloadCancels = cancelCalls
    C.onGameStart()
    check("reload_only_queues_readiness", rrec.bodyOwner == "companion:grant-reload"
        and rrec.zaoTransferPending ~= nil and cancelCalls == beforeReloadCancels
        and rrec.companionReturn ~= nil and rrec.companionReturn.attempts == 0)
    C.onTick()
    check("reload_blocked_keeps_current_person", rrec.bodyOwner == "companion:grant-reload"
        and rrec.dead == false and rbody.removed ~= true)
    ISTimedActionQueue.queues[rbody] = nil
    C.onTick()
    check("reload_resume_uses_checkpoint_then_zao", rrec.bodyOwner == "ZAO"
        and rrec.zaoTransferPending == nil and rrec.hibernation.marker == rrec.id)

    local dre, dbo = person("person-dormant-reload")
    fixture.claim(p, { grantId = "grant-dormant-reload", personId = dre.id })
    terminalStates[dre.id] = { terminalState = "crossed" }
    T.begin(dre.id, dbo, "zao-dormant-token", 5, "crossed")
    Body.checkpointActive()
    local savedSequence = dre.hibernation.sequence
    Body.foreign[dre.id] = nil -- native off-slot shell does not survive a reload
    C.onGameStart()
    C.onTick()
    check("bodyless_reload_hands_checkpoint_to_zao", dre.bodyOwner == "ZAO"
        and dre.zaoTransferPending == nil and dre.hibernation.sequence == savedSequence
        and dre.bodyOwnerToken == "zao-dormant-token")

    local drec, dbody = person("person-death")
    fixture.claim(p, { grantId = "grant-death", personId = drec.id })
    dbody.dead = true
    C.onTick()
    check("companion_death_uses_external_death", deathCalls == 1
        and drec.dead == true and drec.bodyOwner == nil and dbody.removed ~= true
        and Comm.executionOwners["companion:grant-death"] == nil
        and drec.companionReturn == nil)
    C.onTick()
    check("duplicate_death_keeps_adapter_retired",
        Comm.executionOwners["companion:grant-death"] == nil and deathCalls == 1)

    local pdrec, pdbody = person("person-pending-death")
    fixture.claim(p, { grantId = "grant-pending-death", personId = pdrec.id })
    fixture.revoke(p, "grant-pending-death", "pending-death-revoke")
    pdbody.dead = true
    C.onTick()
    check("pending_return_death_clears_exact_adapter",
        pdrec.dead == true and pdrec.companionReturn == nil
        and Comm.executionOwners["companion:grant-pending-death"] == nil)

    local brec, bbody = person("person-busy")
    ISTimedActionQueue.queues[bbody] = { queue = { { Type = "OtherAction" } } }
    local beforeBusyCancels = cancelCalls
    denied, reason = fixture.claim(p, { grantId = "grant-busy", personId = brec.id })
    check("busy_claim_refuses_without_cancel", denied == false
        and cancelCalls == beforeBusyCancels and Body.active[brec.id] == bbody
        and brec.bodyOwner == nil)
    ISTimedActionQueue.queues[bbody] = nil
    local wrec = person("person-work")
    wrec.studyWork = { status = "reading" }
    denied, reason = fixture.claim(p, { grantId = "grant-work", personId = wrec.id })
    check("study_claim_refuses_without_interrupt", denied == false
        and reason == "work-pending" and wrec.studyWork.status == "reading")
    local orec = person("person-owned")
    orec.bodyOwner = "other-owner"
    denied = fixture.claim(p, { grantId = "grant-owned", personId = orec.id })
    check("owned_claim_refused", denied == false and orec.bodyOwner == "other-owner")
    local deadRec = person("person-already-dead")
    deadRec.dead = true
    denied, reason = fixture.claim(p, { grantId = "grant-dead", personId = deadRec.id })
    check("dead_claim_refused", denied == false and reason == "person-dead")
    local jrec = person("person-journal")
    jrec.zaoTransferPending = { token = "zao-existing", terminalState = "crossed" }
    denied = fixture.claim(p, { grantId = "grant-journal", personId = jrec.id })
    check("journal_claim_refused", denied == false and jrec.bodyOwner == nil)
    local trec = person("person-terminal")
    terminalStates[trec.id] = { terminalState = "crossed" }
    denied, reason = fixture.claim(p, { grantId = "grant-terminal", personId = trec.id })
    check("zao_person_claim_refused", denied == false and reason == "zao-terminal")

    local urec, ubody = person("person-unloaded")
    fixture.claim(p, { grantId = "grant-unloaded", personId = urec.id })
    Body.unloaded[urec.id], ubody.unloaded = true, true
    ISTimedActionQueue.queues[ubody] = { queue = { { Type = "StillOwned" } } }
    local recovered = Body.recover(urec)
    check("unload_preserves_foreign_queue", recovered == false
        and Body.foreign[urec.id] == ubody and queueClearCalls == 0
        and sourceCloseCalls == 0)
    ISTimedActionQueue.queues[ubody] = nil
    recovered = Body.recover(urec)
    check("unload_checkpoints_when_ready", recovered == true
        and Body.foreign[urec.id] == nil and urec.hibernation ~= nil)
    C.onTick()
    check("unloaded_companion_returns_from_checkpoint", urec.bodyOwner == nil)

    local arec, abody = person("person-auto-unload")
    fixture.claim(p, { grantId = "grant-auto-unload", personId = arec.id })
    Body.unloaded[arec.id], abody.unloaded = true, true
    C.terminalPending(arec.id)
    fixture.revoke(p, "grant-auto-unload", "grant-expired")
    C.onTick()
    check("unloaded_return_reconciles_without_broad_cancel", arec.bodyOwner == nil
        and abody.removed == true and queueClearCalls == 0
        and sourceCloseCalls == 0)

    local cprec = person("person-checkpoint")
    fixture.claim(p, { grantId = "grant-checkpoint", personId = cprec.id })
    local checkpointBefore = cprec.hibernation.sequence
    local report = Body.checkpointActive()
    check("companion_foreign_body_save_checkpoint", report.saved >= 1
        and cprec.hibernation.marker == cprec.id
        and cprec.hibernation.sequence > checkpointBefore)

    local erec, ebody = person("person-expiry")
    local short = principal(); short.expiresAtTick = clockTick + 1
    fixture.claim(short, { grantId = "grant-expiry", personId = erec.id })
    fixture.attempt(short, "grant-expiry", "move-expiry", { x = 5, y = 5, z = 0 })
    clockTick = clockTick + 2
    C.onTick()
    local expired = fixture.result("grant-expiry", "move-expiry")
    check("tick_expiry_interrupts_owned_route", expired and expired.status == "interrupted"
        and SAO.Locomotion.jobs[erec.id] == nil and erec.bodyOwner == nil
        and ebody.removed == true)

    local pending = person("person-materialize-pending")
    pending.zaoTransferPending = { token = "z", terminalState = "crossed" }
    local created, creationReason = Body.materialize(pending)
    check("pending_zao_blocks_sao_materialization", created == nil
        and creationReason == "zao-transfer-pending")

    check("no_broad_source_or_queue_cancellation", sourceCloseCalls == 0
        and queueClearCalls == 0)
    return tostring(passed) .. ":" .. table.concat(failed, ",")
end
