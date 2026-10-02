-- Surrounding owners are controlled; Body, BodySnapshot, installed cooler Lua,
-- native bodies/inventories and strict capture/validation/wake execute unchanged.
local installedCooler = TienCoolers
Events.OnSave = event()
SAO.Log = { line = function(_, message)
    if __bodyContext then
        __bodyContext.lastLog = message
        __bodyContext.coolerLogs = (__bodyContext.coolerLogs or 0) + 1
    end
end }
SAO.History = { countyHours = function() return installedCooler.worldHours() end }
SAO.Controller = { drop = function(id)
    __bodyContext.dropped = __bodyContext.dropped + 1
end }
SAO.Population = {
    captureBodyFacts = function(rec, body, now)
        return { radioState = __radioCapture(body), newInfection = false }
    end,
    commitBodyFacts = function(rec, facts, now)
        rec.fixtureRadioState = facts.radioState
    end,
}
ISTimedActionQueue = { queues = {} }
SAOJavaBridge = {
    isShell = function(_, body) return instanceof(body, "SAOIsoPlayerShell") end,
    canReleaseShell = function(_, body) return __releaseReady(body) end,
    removeShell = function(_, body)
        __bodyContext.removed = __bodyContext.removed + 1
        return __bodyRemove(body)
    end,
    hibernate = function(_, body)
        local c = __bodyContext
        c.events[#c.events + 1] = "capture"
        c.captures = c.captures + 1
        c.capturedClock = c.set.cooler:getModData().tcLast
        c.capturedCharge = installedCooler.getCharge(c.set.ice)
        c.capturedAge = c.set.food:getAge()
        return __capture(body)
    end,
    validateHibernation = function(_, packed) return __snapshotValid(packed) end,
    hibernationVersion = function(_, packed) return __snapshotVersion(packed) end,
    hibernationRestState = function(_, packed) return __snapshotRest(packed) end,
    validateRadioState = function(_, value) return __radioValid(value) end,
}

local checkpoint = SAO.ModMechanics.beforeSnapshot
SAO.ModMechanics.beforeSnapshot = function(rec, body)
    local c = __bodyContext
    c.events[#c.events + 1] = "cooler"
    return checkpoint(rec, body)
end

local serial = 0
function bodyCase(foreign)
    serial = serial + 1
    local Body, M, CF = SAO.Body, SAO.ModMechanics, TienCoolers
    M.reset()
    Body.active, Body.foreign, Body.unloaded, Body.returning = {}, {}, {}, {}
    Body.failedRestore, Body.discarding = {}, {}
    local id = "caller-" .. tostring(serial)
    local set = __bodySet(id, 4400 + serial * 10)
    local rec = register(id, set.body, foreign)
    rec.hibernation = __capture(set.body)
    rec.releasedAtHours = 1
    __time(20 + serial / 8)
    CF.storeCharge(set.ice, 1)
    assert(M.processCoolers(id, set.body) == true, "native fixture baseline failed")
    local c = { id = id, rec = rec, set = set, oldPacked = rec.hibernation,
        oldReleaseTime = rec.releasedAtHours, owner = rec.bodyOwner, token = rec.bodyOwnerToken,
        oldClock = set.cooler:getModData().tcLast,
        events = {}, captures = 0, removed = 0, dropped = 0 }
    __bodyContext = c
    __time(20 + serial / 8 + 1 / 16)
    c.now = CF.worldHours()
    c.expectedCharge = 1 - (c.now - c.oldClock) / 48
    return c
end

function bodyInvoke(c, path)
    local Body = SAO.Body
    if path == "active-save" then
        Events.OnSave.fire()
        return Body.lastCheckpointReport.saved == 1, Body.lastCheckpointReport
    elseif path == "foreign-save" then
        local report = Body.checkpointActive()
        return report.saved == 1, report
    elseif path == "transfer" then
        return Body.prepareExternalTransfer(c.rec, c.set.body, "ZAO", "transfer-token")
    elseif path == "release" then
        return Body.release(c.rec)
    elseif path == "foreign-hibernate" then
        return Body.hibernateExternal(c.rec, c.set.body, "ZAO", "foreign-token")
    end
    error("unknown Body caller fixture")
end

function bodyOrdered(c, path)
    local accepted, reason = bodyInvoke(c, path)
    local packed = c.rec.bodyTransfer and c.rec.bodyTransfer.captured.packed or c.rec.hibernation
    local restored = __newBody("roundtrip/" .. c.id)
    local journal = __wake(restored, packed, 0)
    local bag = restored:getInventory():getItems():get(0)
    local cooler = bag:getInventory():getItems():get(0)
    local contents, ice, food = cooler:getInventory():getItems(), nil, nil
    for i = 0, contents:size() - 1 do
        local item = contents:get(i)
        if item:getID() == c.set.ice:getID() then ice = item end
        if item:getID() == c.set.food:getID() then food = item end
    end
    print("MEASURE body_caller=" .. path .. " accepted=" .. tostring(accepted)
        .. " reason=" .. tostring(reason) .. " captures=" .. c.captures
        .. " observed_clock=" .. tostring(c.capturedClock) .. " expected_clock=" .. c.now
        .. " log=" .. tostring(c.lastLog))
    return accepted == true and c.captures == 1
        and #c.events == 2 and c.events[1] == "cooler" and c.events[2] == "capture"
        and near(c.capturedClock, c.now) and near(c.capturedCharge, c.expectedCharge)
        and string.sub(journal, 1, 9) == "AWAKENED "
        and cooler:getID() == c.set.cooler:getID() and ice ~= nil and food ~= nil
        and near(cooler:getModData().tcLast, c.now) and near(TienCoolers.getCharge(ice), c.expectedCharge)
        and near(food:getAge(), c.capturedAge) and contents:size() == 2
end

function bodyRefused(c, path)
    local CF, updateName = TienCoolers, TienCoolers.updateCoolerName
    CF.updateCoolerName = function() error("controlled Body checkpoint midpass fault") end
    local ok, accepted = pcall(bodyInvoke, c, path)
    CF.updateCoolerName = updateName
    local durable = c.rec.inventoryMechanics and c.rec.inventoryMechanics.coolerFailure
    local retained = ok and accepted == false and c.captures == 0 and c.removed == 0 and c.dropped == 0
        and c.rec.hibernation == c.oldPacked and c.rec.releasedAtHours == c.oldReleaseTime
        and SAO.Body.get(c.id) == c.set.body and c.rec.bodyOwner == c.owner and c.rec.bodyOwnerToken == c.token
        and c.rec.bodyTransfer == nil and c.rec.bodyRelease == nil
        and c.set.body:getModData().SAOExternalOwner == c.owner
        and c.set.body:getModData().SAOExternalToken == c.token
        and durable ~= nil and c.set.cooler:getModData().tcLast == c.now
    -- A successful clock-only retry cannot replace the previous native envelope.
    local retry = bodyInvoke(c, path)
    return retained and retry == false and c.captures == 0 and c.removed == 0 and c.dropped == 0
        and c.rec.hibernation == c.oldPacked and SAO.Body.get(c.id) == c.set.body
        and c.rec.inventoryMechanics.coolerFailure == durable
end
