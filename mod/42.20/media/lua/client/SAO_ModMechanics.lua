-- Installed mechanics run on the person's actual carried inventory. TienCoolers
-- owns cooling, ice, meltwater, food age and its item timestamps; this module
-- supplies the off-slot living bodies its player-slot callback cannot visit.
-- Load order is optional: look up the shared API on each pass, never load a
-- missing Workshop mod or replace its player/server callbacks.
SAO = SAO or {}
SAO.ModMechanics = SAO.ModMechanics or {}
local M = SAO.ModMechanics
local runtime = {}
local lastFailures = {}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function coolerFailure(id)
    local rec = SAO.Identity and SAO.Identity.get(tostring(id))
    local state = rec and rec.inventoryMechanics
    return type(state) == "table" and state.coolerFailure or nil
end

local function actor(id, body, snapshotRec)
    if not SAO.Identity or not SAO.Body or not SAO.Body.get then
        return nil, "body-registry-unavailable"
    end
    local rec = SAO.Identity.get(id)
    if not rec or tostring(rec.id or "") ~= id or rec.dead or not body then
        return nil, "body-unavailable"
    end
    if snapshotRec ~= nil and snapshotRec ~= rec then return nil, "body-record-mismatch" end
    local resolved = SAO.Body.get(id)
    -- Body's authenticated capture caller may retain a living body while its
    -- transition journal hides Body.get. It must still be the exact registered
    -- active/foreign handle, never a replacement or an arbitrary supplied actor.
    if resolved ~= body and (resolved ~= nil or snapshotRec ~= rec) then
        return nil, "body-unavailable"
    end
    local active = SAO.Body.active and SAO.Body.active[id]
    local foreign = SAO.Body.foreign and SAO.Body.foreign[id]
    if active == body and foreign ~= nil or foreign == body and active ~= nil then
        return nil, "ambiguous-body-owner"
    end
    local data = body:getModData()
    if tostring(data.SAOPersonId or "") ~= id
        or data.SAOExternalOwner ~= rec.bodyOwner
        or data.SAOExternalToken ~= rec.bodyOwnerToken then
        return nil, "body-identity-mismatch"
    end
    if rec.bodyOwner == nil then
        if active ~= body then return nil, "body-owner-mismatch" end
    elseif foreign ~= body or type(rec.bodyOwner) ~= "string"
        or type(rec.bodyOwnerToken) ~= "string" or rec.bodyOwnerToken == "" then
        return nil, "body-owner-mismatch"
    end
    -- Native chunk removal can precede the owner's final checkpoint. Only
    -- Body's exact registered unload journal permits this retained inventory;
    -- ordinary minute processing still requires a loaded living actor.
    local checkpointUnloaded = snapshotRec == rec and SAO.Body.unloaded
        and SAO.Body.unloaded[id] == true
    if body:isDead() or (not checkpointUnloaded
        and (not body:isExistInTheWorld() or not body:getCurrentSquare())) then
        return nil, "body-not-living-loaded"
    end
    if not checkpointUnloaded then
        local world = type(getWorld) == "function" and getWorld() or nil
        local cell = world and world:getCell()
        if not cell or (not cell:getObjectList():contains(body)
            and not cell:getAddList():contains(body)) then return nil, "body-world-mismatch" end
    end
    -- IsoPlayer's four native player slots remain the installed mod's authority.
    if type(getSpecificPlayer) ~= "function" then return nil, "player-slots-unavailable" end
    for slot = 0, 3 do
        if getSpecificPlayer(slot) == body then return nil, "native-player-owned" end
    end
    local inventory = body:getInventory()
    if not inventory or inventory:getParent() ~= body or inventory:getContainingItem() ~= nil then
        return nil, "body-inventory-mismatch"
    end
    return inventory, nil, rec
end

local function process(id, body, snapshotRec)
    local CF = TienCoolers
    if CF == nil then return true, "mod-absent" end
    if type(CF) ~= "table" or type(CF.processTopLevel) ~= "function"
        or type(CF.worldHours) ~= "function" or type(CF.ownsContainer) ~= "function" then
        return false, "cooler-api-incomplete"
    end
    if type(isClient) ~= "function" or type(isServer) ~= "function" then
        return false, "network-authority-unavailable"
    end
    -- Carried-cooler multiplayer reconciliation names an owning player/client.
    -- SAO has no NPC inventory report protocol; neither endpoint may infer it.
    if isClient() or isServer() then return true, "multiplayer-unowned" end
    if CF.syncPlayer ~= nil or CF.leaveCoolers then return false, "cooler-context-busy" end
    local inventory, reason, rec = actor(id, body, snapshotRec)
    if not inventory then return false, reason end
    if CF.ownsContainer(inventory) ~= true then return false, "cooler-inventory-unowned" end
    local now = CF.worldHours()
    if not finite(now) or now < 0 then return false, "cooler-clock-unavailable" end
    if rec.inventoryMechanics ~= nil and (type(rec.inventoryMechanics) ~= "table"
        or rec.inventoryMechanics.schema ~= 1) then return false, "inventory-mechanics-state-invalid" end
    local completed, found = pcall(CF.processTopLevel, inventory)
    -- Handles stay in this runtime table. Observers receive detached scalar data;
    -- native item ModData (tcLast/tcAge/tcCharge) is the durable physical state.
    local previous = runtime[id]
    local passes = previous and previous.body == body and previous.passes or 0
    if not completed then
        -- The installed source advances item clocks before all physics finish.
        -- A successful later pass cannot prove the lost interval was applied.
        -- Keep the failure with the person across runtime reset and reload;
        -- resetting clocks would bill already-consumed ice a second time.
        rec.inventoryMechanics = rec.inventoryMechanics or { schema = 1 }
        local state = rec.inventoryMechanics
        if state.coolerFailure == nil then
            state.coolerFailure = { atWorldHours = now,
                lastVerifiedWorldHours = previous and previous.lastWorldHours or nil,
                sourceVersion = string.sub(tostring(CF.VERSION or "unknown"), 1, 160),
                error = string.sub(string.gsub(tostring(found), "[\r\n]", " "), 1, 500) }
        end
        runtime[id] = { body = body, passes = passes, actorId = id,
            lastWorldHours = previous and previous.lastWorldHours or nil,
            sourceVersion = string.sub(tostring(CF.VERSION or "unknown"), 1, 160),
            scope = "loaded-inventory", status = "cooler-update-error", lastError = state.coolerFailure.error }
        return false, "cooler-update-error"
    end
    runtime[id] = { body = body, passes = passes + 1, actorId = id,
        lastWorldHours = now, sourceVersion = tostring(CF.VERSION or "unknown"),
        scope = "loaded-inventory", status = found and "processed" or "no-cooler-work" }
    if coolerFailure(id) then
        runtime[id].status = "cooler-reconciliation-required"
        runtime[id].lastError = coolerFailure(id).error
        return false, "cooler-reconciliation-required"
    end
    return true, runtime[id].status
end

local function safelyProcess(id, body, snapshotRec)
    if id == nil then return false, "actor-id-unavailable" end
    id = tostring(id)
    local ok, updated, status = pcall(process, id, body, snapshotRec)
    if not ok then
        -- A partially executed native pass is not a successful checkpoint. Do
        -- not change source flags, replace items or manufacture rollback physics.
        local previous = runtime[id]
        if not previous or previous.body ~= body then
            previous = { body = body, actorId = id, passes = 0, scope = "loaded-inventory" }
            runtime[id] = previous
        end
        previous.status = "cooler-update-error"
        previous.lastError = string.sub(string.gsub(tostring(updated), "[\r\n]", " "), 1, 500)
        return false, "cooler-update-error"
    end
    return updated, status
end

function M.processCoolers(id, body) return safelyProcess(id, body) end

-- Body's transaction/checkpoint owner calls this before its fresh native capture.
-- Registering a later OnSave callback would capture the old inventory first.
function M.beforeSnapshot(rec, body)
    if not rec or rec.id == nil then return false, "actor-id-unavailable" end
    if coolerFailure(rec.id) then return false, "cooler-reconciliation-required" end
    return safelyProcess(rec.id, body, rec)
end

function M.coolerStatus(id)
    local state = runtime[tostring(id)]
    local failure = coolerFailure(id)
    if not state then
        if not failure then return nil end
        return { actorId = tostring(id), passes = 0, scope = "loaded-inventory",
            status = "cooler-reconciliation-required", sourceVersion = failure.sourceVersion,
            failedAtWorldHours = failure.atWorldHours, lastError = failure.error }
    end
    return { actorId = state.actorId, passes = state.passes,
        lastWorldHours = state.lastWorldHours, sourceVersion = state.sourceVersion,
        scope = state.scope, status = state.status, lastError = state.lastError,
        failedAtWorldHours = failure and failure.atWorldHours or nil }
end

function M.tickCoolers()
    local report = { processed = 0, skipped = 0, failed = 0, failures = {} }
    if not SAO.Body or not SAO.Body.get then return report end
    local ids = {}
    for id in pairs(SAO.Body.active or {}) do ids[tostring(id)] = true end
    for id in pairs(SAO.Body.foreign or {}) do ids[tostring(id)] = true end
    for id in pairs(runtime) do if not ids[id] then runtime[id], lastFailures[id] = nil, nil end end
    for id in pairs(ids) do
        local body = SAO.Body.get(id)
        if not body then
            runtime[id] = nil
            report.skipped = report.skipped + 1
        else
            local ok, status = M.processCoolers(id, body)
            if ok and (status == "processed" or status == "no-cooler-work") then
                lastFailures[id] = nil
                report.processed = report.processed + 1
            elseif ok then report.skipped = report.skipped + 1
            else
                report.failed = report.failed + 1
                report.failures[id] = status
                if lastFailures[id] ~= status and SAO.Log and SAO.Log.line then
                    local state = runtime[id]
                    pcall(SAO.Log.line, "MODMECHANICS", id .. " cooler update refused: " .. status
                        .. (state and state.lastError and ("; " .. state.lastError) or ""))
                end
                lastFailures[id] = status
            end
        end
    end
    return report
end

function M.detach(id, body)
    id = tostring(id)
    if runtime[id] and runtime[id].body ~= body then return false, "body-mismatch" end
    runtime[id] = nil
    lastFailures[id] = nil
    return true
end

-- Death ends living inventory observation; the engine retains the corpse's
-- possessions and the record retains unresolved physical intervals.
function M.forget(id)
    id = tostring(id)
    local rec = SAO.Identity and SAO.Identity.get(id)
    if not rec or rec.dead ~= true then return false, "actor-not-dead" end
    runtime[id] = nil
    lastFailures[id] = nil
    return true
end

function M.reset() runtime, lastFailures = {}, {} end

-- Reload replaces only this module's callbacks. Installed mod handlers retain
-- their ordering and authority; same-world-time duplicates use its item guard.
if Events and Events.EveryOneMinute then
    if M.onCoolerMinute then Events.EveryOneMinute.Remove(M.onCoolerMinute) end
    M.onCoolerMinute = function() M.tickCoolers() end
    Events.EveryOneMinute.Add(M.onCoolerMinute)
end
if Events and Events.OnGameStart then
    if M.onWorldStart then Events.OnGameStart.Remove(M.onWorldStart) end
    M.onWorldStart = function() M.reset() end
    Events.OnGameStart.Add(M.onWorldStart)
end
return M
