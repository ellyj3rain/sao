local rootBody, rootController, rootTransfer = SAO.Body, SAO.Controller, SAO.CrossedTransfer
local actualResume, actualDetach = rootTransfer.resumePending, SAO.Cooking.detach
local function joinFixture(foreign)
    newFixture()
    F.rec.x, F.rec.y, F.rec.z = 1, 2, 0
    F.captures, F.commits, F.removals, F.resumes = 0, 0, 0, 0
    SAO.Log = { line = function() end }
    SAO.Body, SAO.Controller, SAO.CrossedTransfer = rootBody, rootController, rootTransfer
    SAO.ZAOPersonTransfer = rootTransfer
    rootBody.active, rootBody.foreign = {}, {}
    rootBody.failedRestore, rootBody.discarding, rootBody.unloaded, rootBody.returning = {}, {}, {}, {}
    rootController.agents, rootController.pendingCorpses = {}, {}
    F.agent = { rec = F.rec, state = "COOK", stateSince = 0, nextDecisionAt = 0 }
    if foreign then
        F.rec.bodyOwner, F.rec.bodyOwnerToken = "ZAO", "token"
        rootBody.foreign[F.rec.id] = F.body ZAO.Controller.controlled[F.rec.id] = F.body
        F.body.data.SAOExternalOwner, F.body.data.SAOExternalToken, F.body.data.ZAOOwned = "ZAO", "token", true
    else
        rootBody.active[F.rec.id], rootController.agents[F.rec.id] = F.body, F.agent
    end
    SAO.Identity.all = function() return { [F.rec.id] = F.rec } end
    SAO.Identity.beliefKey = function(rec) return rec.id end
    SAO.Identity.markDead = function(rec) rec.dead = true return true end
    SAO.Identity.updatePosition = function() end
    SAO.BodySnapshot = {
        capture = function(rec, body)
            F.captures = F.captures + 1 F.captureSawCooking = rec.cookingWork ~= nil
            F.captureSawHeat = F.binding ~= nil
            return { facts = {}, hours = F.at }
        end,
        valid = function() return true end,
        commit = function() F.commits = F.commits + 1 return true end,
    }
    SAO.WorldSources.pendingActionFor = function()
        return F.rec.worldSourceReservation and { id = F.rec.worldSourceReservation, phase = "transferring" } or nil
    end
    SAO.SourceUse.detach = function() F.sourceDetached = true end
    SAO.Perception = { beliefs = {} }
    SAO.Disposition = {}
    SAOJavaBridge.canReleaseShell = function() return true end
    SAOJavaBridge.isInventoryOf = function() return false end
    SAOJavaBridge.removeShell = function()
        F.removals = F.removals + 1 F.removalSawCooking = F.rec.cookingWork ~= nil
        F.body.attached = false return true
    end
    SAOJavaBridge.getLastAttackerTag = function() return "" end
    SAOJavaBridge.getBleedingCount = function() return 0 end
    SAOJavaBridge.isShellUnloaded = function() return false end
    F.body.getX = function() return 1 end F.body.getY = function() return 2 end F.body.getZ = function() return 0 end
    F.body.getCharacterActions = function() return { size = function() return 0 end, isEmpty = function() return true end } end
    ISTimedActionQueue.clear = function(body)
        F.nativeStopped = true F.busy = false ISTimedActionQueue.queues[body].queue = {}
    end
    SAO.Cooking.detach = function(id, body, reason)
        F.detachedAfterSource = F.nativeStopped and F.sourceDetached and F.closeCalls > 0
        F.detachmentSawMappedBody = (rootBody.active[id] or rootBody.foreign[id]) == body
        return actualDetach(id, body, reason)
    end
    rootTransfer.resumePending = function()
        F.resumes = F.resumes + 1 F.resumeSawCooking = F.rec.cookingWork ~= nil
        return actualResume()
    end
    ZAO.Controller.acceptExternal = function(id, body, token, terminal)
        F.acceptedTerminal = terminal ZAO.Controller.controlled[id] = body return true
    end
    return F
end
case("root_pending_zao_retires_cooking_route_before_handoff", function()
    joinFixture() F.applianceReachable = false beginCooking() assert(tickCooking() == "travelling")
    F.rec.zaoTransferPending = { token = "zao-token", atHours = 10, terminalState = "crossed" }
    rootController.__cookingFixtureUpdate(F.rec.id, F.agent)
    return F.resumes == 1 and F.resumeSawCooking == false and F.captures == 1 and not F.captureSawCooking
        and F.rec.cookingWork == nil and SAO.Locomotion.jobs[F.rec.id] == nil
        and F.rec.bodyOwner == "ZAO" and rootBody.foreign[F.rec.id] == F.body
        and rootBody.active[F.rec.id] == nil and rootController.agents[F.rec.id] == nil
        and ZAO.Controller.controlled[F.rec.id] == F.body and F.acceptedTerminal == "crossed"
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and lastOutcome().status == "interrupted"
end)
case("root_pending_zao_preserves_unresolved_cooking_transfer", function()
    joinFixture() beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation
    F.rec.zaoTransferPending = { token = "zao-token", atHours = 10, terminalState = "afflicted" }
    rootController.__cookingFixtureUpdate(F.rec.id, F.agent)
    return F.resumes == 0 and F.captures == 0 and F.rec.bodyOwner == nil
        and rootBody.active[F.rec.id] == F.body and F.rec.worldSourceReservation == reservation
        and F.rec.cookingWork.terminalStatus == "interrupted" and F.rec.cookingWork.detached ~= true
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] ~= nil
end)
case("root_prepare_handoff_quiesces_route_before_capture", function()
    joinFixture() F.applianceReachable = false beginCooking() tickCooking()
    local prepared = rootBody.prepareExternalTransfer(F.rec, F.body, "ZAO", "token")
    return prepared and F.captures == 1 and not F.captureSawCooking and F.rec.bodyTransfer ~= nil
        and F.rec.cookingWork == nil and SAO.Locomotion.jobs[F.rec.id] == nil
end)
case("root_foreign_unresolved_transfer_blocks_capture_and_removal", function()
    joinFixture(true) beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation
    local first, why = rootBody.hibernateExternal(F.rec, F.body, "ZAO", "token")
    local held = not first and why == "cooking-reconciliation-pending" and F.captures == 0
        and F.removals == 0 and rootBody.foreign[F.rec.id] == F.body
        and F.rec.worldSourceReservation == reservation and F.rec.cookingWork ~= nil
    F.closeAccept = true
    local second = rootBody.hibernateExternal(F.rec, F.body, "ZAO", "token")
    return held and second and F.captures == 1 and F.commits == 1 and F.removals == 1
        and not F.captureSawCooking and not F.removalSawCooking and rootBody.foreign[F.rec.id] == nil
        and F.rec.cookingWork == nil and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil
end)
case("root_foreign_readiness_honors_non_cooking_source_owner", function()
    joinFixture(true) F.rec.worldSourceReservation = "R:foreign"
    return not rootBody.canTransfer(F.body) and F.rec.worldSourceReservation == "R:foreign"
        and F.captures == 0 and F.removals == 0 and F.closeCalls == 0
end)
case("root_release_clears_heat_before_snapshot", function()
    joinFixture() heatSetup() local released, why = rootBody.release(F.rec)
    __joinDiagnostic = "release=" .. tostring(released) .. "/" .. tostring(why)
        .. ",capture=" .. tostring(F.captures) .. ",commit=" .. tostring(F.commits) .. ",remove=" .. tostring(F.removals)
        .. ",work=" .. tostring(F.captureSawCooking) .. ",heat=" .. tostring(F.captureSawHeat)
        .. ",binding=" .. tostring(F.binding) .. ",active=" .. tostring(rootBody.active[F.rec.id])
    return released and F.captures == 1 and F.commits == 1 and F.removals == 1
        and not F.captureSawCooking and not F.captureSawHeat and F.binding == nil
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and rootBody.active[F.rec.id] == nil
end)
case("root_remove_owned_refuses_unresolved_cooking", function()
    joinFixture(true) beginCooking() tickCooking() F.closeAccept = false
    return not rootBody.__cookingFixtureRemove(F.body) and F.removals == 0
        and F.rec.cookingWork ~= nil and rootBody.foreign[F.rec.id] == F.body
end)
case("root_captured_journal_refuses_new_cooking_owner", function()
    joinFixture() beginCooking()
    F.rec.bodyTransfer = { version = 1, owner = "ZAO", token = "token", phase = "captured", captured = {} }
    local committed, why = rootBody.commitExternalTransfer(F.rec)
    return not committed and why == "cooking-work-after-capture" and F.commits == 0
        and rootBody.active[F.rec.id] == F.body and F.rec.bodyOwner == nil and F.rec.cookingWork ~= nil
end)
case("root_ordinary_death_detaches_unresolved_cooking", function()
    joinFixture() beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation F.body.dead = true
    rootController.__cookingFixtureUpdate(F.rec.id, F.agent)
    return F.rec.dead and rootBody.active[F.rec.id] == nil and rootController.agents[F.rec.id] == nil
        and F.detachedAfterSource and F.detachmentSawMappedBody and F.rec.worldSourceReservation == reservation
        and F.rec.cookingWork and F.rec.cookingWork.detached and F.rec.cookingWork.terminalStatus == "interrupted"
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and lastOutcome() == nil
end)
case("root_external_death_detaches_unresolved_cooking", function()
    joinFixture(true) beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation F.body.dead = true
    local observed = rootController.observeExternalDeath(F.rec.id, F.body, "ZAO")
    return observed and F.rec.dead and rootBody.foreign[F.rec.id] == nil and F.rec.bodyOwner == nil
        and F.detachedAfterSource and F.detachmentSawMappedBody and F.rec.worldSourceReservation == reservation
        and F.rec.cookingWork and F.rec.cookingWork.detached and F.rec.cookingWork.terminalStatus == "interrupted"
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and lastOutcome() == nil
end)
case("root_passive_death_detaches_restored_cooking", function()
    joinFixture() beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation F.body.dead = true F.agent.passive = true
    rootController.__cookingFixtureUpdate(F.rec.id, F.agent)
    return F.rec.dead and rootBody.active[F.rec.id] == nil and rootController.agents[F.rec.id] == nil
        and F.detachedAfterSource and F.detachmentSawMappedBody and F.rec.worldSourceReservation == reservation
        and F.rec.cookingWork and F.rec.cookingWork.detached
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil and lastOutcome() == nil
end)
case("root_direct_drop_retires_idle_heat_runtime", function()
    joinFixture() heatSetup()
    local dropped = rootController.drop(F.rec.id)
    return dropped and rootController.agents[F.rec.id] == nil and F.binding == nil
        and F.rec.cookingWork == nil and SAO.Cooking.__fixtureRuntime()[F.rec.id] == nil
        and lastOutcome().status == "interrupted"
end)
case("root_direct_drop_preserves_unresolved_cooking_owner", function()
    joinFixture() beginCooking() tickCooking() F.closeAccept = false
    local reservation = F.rec.worldSourceReservation
    local dropped, why = rootController.drop(F.rec.id)
    return not dropped and why == "cooking-action-pending" and rootController.agents[F.rec.id] == F.agent
        and F.rec.worldSourceReservation == reservation and F.rec.cookingWork.terminalStatus == "interrupted"
        and SAO.Cooking.__fixtureRuntime()[F.rec.id] ~= nil
end)
__cookingResults = table.concat(__cookingCases, "\n") .. "\nDIAGNOSTIC " .. tostring(__joinDiagnostic)
