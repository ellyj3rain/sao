-- SAO_Treatment - the owner of an open-wound bandaging action.
--
-- Queue admission says only that a doctor started. This owner binds that
-- request to the actor, patient, exact body part and exact dressing, then lets
-- vanilla ISApplyBandage perform the physical mutation. Patient response,
-- voice and the mod's care experience are consumed once only after vanilla
-- leaves an effective dressing. Live bodies, parts, items and actions never
-- enter ModData.

SAO = SAO or {}
SAO.Treatment = SAO.Treatment or {}
local T = SAO.Treatment

local STORE_KEY = "SurvivorAwareness_Treatments"
local SCHEMA = 1
local MAX_RECORDS = 512
local MAX_DISTANCE = 6

local storeMemo = nil
local runtime = {}
local restoredPending = {}
local bandageClass = nil
local lastReconcileAt = nil

local function log(message)
    if SAO.Log and SAO.Log.line then
        pcall(SAO.Log.line, "TREATMENT", tostring(message))
    end
end

local function now()
    local ok, value = pcall(function()
        if SAO.History and SAO.History.ticks then
            return SAO.History.ticks()
        end
        if SAO.History and SAO.History.countyHours then
            return SAO.History.countyHours()
        end
        return 0
    end)
    return ok and tonumber(value) or 0
end

local function identity(value)
    if value == nil then return nil end
    return tostring(value)
end

local function terminal(status)
    return status == "completed" or status == "ineffective"
        or status == "interrupted" or status == "released"
        or status == "conflict"
end

local function store()
    if storeMemo ~= nil then
        return tonumber(storeMemo.schema) == SCHEMA and storeMemo or nil
    end
    local ok, value = pcall(function()
        return ModData.getOrCreate(STORE_KEY)
    end)
    if not ok or type(value) ~= "table" then return nil end
    if value.schema == nil then
        value.schema = SCHEMA
        value.nextSequence = tonumber(value.nextSequence) or 0
        value.records = type(value.records) == "table" and value.records or {}
    elseif tonumber(value.schema) ~= SCHEMA then
        return nil
    end
    storeMemo = value
    for id, rec in pairs(value.records or {}) do
        if rec.status == "pending" then restoredPending[tostring(id)] = true end
    end
    return value
end

local function record(id)
    local s = store()
    return s and s.records and s.records[tostring(id)] or nil
end

local function trimRecords(s)
    local count = 0
    for _ in pairs(s.records or {}) do count = count + 1 end
    while count >= MAX_RECORDS do
        local oldestId, oldestAt = nil, nil
        for id, rec in pairs(s.records or {}) do
            if rec and terminal(rec.status)
                and (rec.status ~= "completed" or rec.effectApplied) then
                local at = tonumber(rec.terminalAt or rec.completedAt
                    or rec.createdAt) or 0
                if oldestId == nil or at < oldestAt
                    or (at == oldestAt and tostring(id) < tostring(oldestId)) then
                    oldestId, oldestAt = tostring(id), at
                end
            end
        end
        if oldestId == nil then return false end
        s.records[oldestId] = nil
        runtime[oldestId] = nil
        restoredPending[oldestId] = nil
        count = count - 1
    end
    return true
end

local function nextId()
    local s = store()
    if not s or not trimRecords(s) then return nil end
    s.nextSequence = (tonumber(s.nextSequence) or 0) + 1
    return "R" .. tostring(s.nextSequence)
end

local function bodyIdentity(body)
    if body == nil then return nil end
    local ok, value = pcall(function()
        local data = body:getModData()
        return data and data.SAOPersonId or nil
    end)
    if ok and value ~= nil then return identity(value) end
    local expected = nil
    pcall(function()
        if SAO.Standing and SAO.Standing.playerKey then
            expected = SAO.Standing.playerKey(body)
        end
    end)
    return identity(expected)
end

local function bodyMatches(expected, body)
    return identity(expected) ~= nil
        and bodyIdentity(body) == identity(expected)
end

local function closeEnough(actorBody, patientBody)
    if actorBody == nil or patientBody == nil then return false end
    local ok, ax, ay, az, bx, by, bz = pcall(function()
        return actorBody:getX(), actorBody:getY(), actorBody:getZ(),
            patientBody:getX(), patientBody:getY(), patientBody:getZ()
    end)
    if not ok or ax == nil or ay == nil or az == nil
        or bx == nil or by == nil or bz == nil
        or tonumber(az) ~= tonumber(bz) then return false end
    local dx, dy = tonumber(ax) - tonumber(bx), tonumber(ay) - tonumber(by)
    return dx * dx + dy * dy <= MAX_DISTANCE * MAX_DISTANCE
end

local function inventory(body)
    local value = nil
    if body ~= nil then
        pcall(function() value = body:getInventory() end)
    end
    return value
end

local function itemIdentity(item)
    if item == nil then return nil, nil end
    local id, fullType = nil, nil
    pcall(function()
        id, fullType = item:getID(), item:getFullType()
    end)
    if fullType == nil then
        pcall(function() fullType = item:getType() end)
    end
    if id == nil or fullType == nil then return nil, nil end
    return tostring(id), tostring(fullType)
end

local function itemIn(item, holder)
    if item == nil or holder == nil then return false end
    local ok, container = pcall(function() return item:getContainer() end)
    if ok then return container == holder end
    local okContains, contains = pcall(function() return holder:contains(item) end)
    return okContains and contains == true
end

local function partIndex(part)
    if part == nil then return nil end
    local ok, value = pcall(function() return part:getIndex() end)
    return ok and tonumber(value) or nil
end

local function partBelongs(patientBody, part, expectedIndex)
    if patientBody == nil or part == nil or expectedIndex == nil then
        return false
    end
    local found = false
    pcall(function()
        local parts = patientBody:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local candidate = parts:get(i)
            if candidate == part and partIndex(candidate) == expectedIndex then
                found = true
                return
            end
        end
    end)
    return found
end

local function openWound(part)
    local ok, value = pcall(function()
        return part:bleeding() == true and part:bandaged() ~= true
    end)
    return ok and value == true
end

local function effectiveDressing(part, item, actorInventory)
    local ok, bandaged, life = pcall(function()
        return part:bandaged() == true, tonumber(part:getBandageLife()) or 0
    end)
    return ok and bandaged == true and life > 0
        and not itemIn(item, actorInventory)
end

local function effectCopy(effect, actorId, patientId)
    effect = type(effect) == "table" and effect or {}
    local out = { trust = {} }
    if type(effect.trust) == "table" then
        for _, change in ipairs(effect.trust) do
            if type(change) == "table" and identity(change.from)
                and identity(change.to) and tonumber(change.delta) then
                out.trust[#out.trust + 1] = {
                    from = identity(change.from), to = identity(change.to),
                    delta = tonumber(change.delta),
                }
            end
        end
    end
    if type(effect.voice) == "table" and type(effect.voice.kind) == "string" then
        out.voice = {
            actor = identity(effect.voice.actor) or identity(actorId),
            kind = effect.voice.kind,
            at = tonumber(effect.voice.at) or now(),
        }
    end
    if type(effect.aid) == "table" then
        out.aid = {
            actor = identity(actorId), patient = identity(patientId),
            at = tonumber(effect.aid.at) or now(),
            xp = tonumber(effect.aid.xp),
        }
    end
    if effect.gesture == "cpr-if-critical" then
        out.gesture = "cpr-if-critical"
    end
    if type(effect.log) == "string" then out.log = effect.log end
    return out
end

local function bodyFor(id, live, field)
    local body = live and live[field] or nil
    if bodyMatches(id, body) then return body end
    if SAO.Body and SAO.Body.get then
        local ok, value = pcall(SAO.Body.get, id)
        if ok and bodyMatches(id, value) then return value end
    end
    if SAO.Standing and SAO.Standing.isPlayerKey
        and SAO.Standing.isPlayerKey(id) and getSpecificPlayer then
        local ok, value = pcall(SAO.Participants and SAO.Participants.player or getSpecificPlayer, 0)
        if ok and bodyMatches(id, value) then return value end
    end
    return nil
end

local function applyRecordEffect(rec, live)
    if rec.effectApplied or rec.status ~= "completed" then return false end
    local effect = type(rec.effect) == "table" and rec.effect or {}
    rec.consumed = type(rec.consumed) == "table" and rec.consumed or {}
    local consumed, changed = rec.consumed, false
    if type(effect.trust) == "table" and #effect.trust > 0
        and not consumed.response and SAO.Standing
        and SAO.Standing.adjustTrust then
        for _, change in ipairs(effect.trust) do
            pcall(SAO.Standing.adjustTrust, change.from, change.to,
                change.delta)
        end
        consumed.response, changed = true, true
    end
    if effect.aid then
        if not consumed.aidStamp then
            local agent = SAO.Controller and SAO.Controller.agents
                and SAO.Controller.agents[effect.aid.patient] or nil
            if agent then
                agent.aidedAt = effect.aid.at
                consumed.aidStamp, changed = true, true
            end
        end
        if not consumed.skill and effect.aid.xp and SAOJavaBridge then
            local actorBody = bodyFor(effect.aid.actor, live, "actorBody")
            if actorBody then
                local ok, granted = pcall(function()
                    return SAOJavaBridge:grantXP(actorBody, "Doctor",
                        effect.aid.xp)
                end)
                if ok and granted ~= false then
                    consumed.skill, changed = true, true
                end
            end
        elseif effect.aid.xp == nil then
            consumed.skill = true
        end
    end
    if effect.voice and not consumed.voice and SAO.Voice
        and SAO.Voice.onEvent then
        local ok = pcall(SAO.Voice.onEvent, effect.voice.actor,
            effect.voice.kind, effect.voice.at)
        if ok then consumed.voice, changed = true, true end
    end
    if effect.gesture == "cpr-if-critical" and not consumed.gesture
        and SAO.Gesture
        and SAO.Gesture.cpr then
        local actorBody = bodyFor(rec.actorId, live, "actorBody")
        local patientBody = bodyFor(rec.patientId, live, "patientBody")
        if actorBody and patientBody then
            local low = false
            pcall(function()
                low = patientBody:isKnockedDown()
                    or patientBody:getHealth() < 0.3
            end)
            if low then pcall(SAO.Gesture.cpr, rec.actorId, actorBody) end
            consumed.gesture, changed = true, true
        end
    end
    if effect.log and not consumed.log and SAO.Log and SAO.Log.line then
        log(effect.log)
        consumed.log, changed = true, true
    end
    local done = true
    if type(effect.trust) == "table" and #effect.trust > 0
        and not consumed.response then done = false end
    if effect.aid and (not consumed.aidStamp or not consumed.skill) then
        done = false
    end
    if effect.voice and not consumed.voice then done = false end
    if effect.gesture and not consumed.gesture then done = false end
    if effect.log and not consumed.log then done = false end
    if done then
        rec.effectApplied = true
        changed = true
    end
    return changed
end

local function setTerminal(rec, status, reason, live)
    if not rec or rec.status ~= "pending" then return false end
    -- Unload cancellation acknowledges only after both native and Lua queues
    -- release the exact action. Its stop callback alone is not that witness.
    if live and (live.unloadInterrupt or live.unloadBlocked) then return false end
    rec.status = status
    rec.terminalAt = now()
    rec.reason = tostring(reason or status)
    if status == "completed" then
        rec.completedAt = rec.terminalAt
        applyRecordEffect(rec, live)
    end
    runtime[tostring(rec.id)] = nil
    restoredPending[tostring(rec.id)] = nil
    return true
end

local function bindingValid(rec, live)
    if not rec or not live then return false end
    if not bodyMatches(rec.actorId, live.actorBody)
        or not bodyMatches(rec.patientId, live.patientBody)
        or not closeEnough(live.actorBody, live.patientBody)
        or not partBelongs(live.patientBody, live.part, rec.bodyPartIndex)
        or not itemIn(live.item, live.actorInventory) then
        return false
    end
    local id, kind = itemIdentity(live.item)
    return id == rec.itemId and kind == rec.itemType
end

local function ensureBandageClass()
    if bandageClass then return bandageClass end
    if not ISApplyBandage or not ISApplyBandage.derive then return nil end
    bandageClass = ISApplyBandage:derive("SAOTreatmentBandageAction")

    function bandageClass:complete()
        local rec = record(self.saoTreatmentId)
        local live = rec and runtime[tostring(rec.id)] or nil
        if live and live.unloadBlocked then return false end
        if not rec or rec.status ~= "pending" or not bindingValid(rec, live) then
            if rec and rec.status == "pending" then
                setTerminal(rec, "ineffective", "binding-changed", live)
            end
            return false
        end
        local ok, result = pcall(ISApplyBandage.complete, self)
        if not ok or result ~= true then
            setTerminal(rec, "ineffective",
                ok and "native-refused" or "native-error", live)
            return false
        end
        if effectiveDressing(live.part, live.item, live.actorInventory) then
            setTerminal(rec, "completed", "effective-dressing", live)
        else
            setTerminal(rec, "ineffective", "dressing-did-not-hold", live)
        end
        return true
    end

    function bandageClass:stop()
        local rec = record(self.saoTreatmentId)
        local live = rec and runtime[tostring(rec.id)] or nil
        local ok, result = pcall(ISApplyBandage.stop, self)
        if live and live.unloadInterrupt and (not ok or result == false) then
            live.unloadCancelFailed = true
        end
        if ok and result ~= false and rec and rec.status == "pending" then
            setTerminal(rec, "interrupted", "action-stopped",
                live)
        end
        return ok and result or nil
    end

    function bandageClass:forceCancel()
        local rec = record(self.saoTreatmentId)
        local live = rec and runtime[tostring(rec.id)] or nil
        local ok, result = true, nil
        if ISApplyBandage.forceCancel then
            ok, result = pcall(ISApplyBandage.forceCancel, self)
        end
        if live and live.unloadInterrupt and (not ok or result == false) then
            live.unloadCancelFailed = true
        end
        if ok and result ~= false and rec and rec.status == "pending" then
            setTerminal(rec, "interrupted", "action-cancelled",
                live)
        end
        return ok and result or nil
    end

    function bandageClass:new(character, patient, item, part, treatmentId)
        local ok, action = pcall(ISApplyBandage.new, self, character,
            patient, item, part, true)
        if not ok or action == nil then return nil end
        action.saoTreatmentId = tostring(treatmentId)
        return action
    end
    return bandageClass
end

local function queue(action)
    if action == nil then return false end
    local ok, accepted = pcall(function()
        if SAO.Needs and SAO.Needs.queueVerified then
            return SAO.Needs.queueVerified(action)
        end
        ISTimedActionQueue.add(action)
        return ISTimedActionQueue.hasAction(action) == true
    end)
    return ok and accepted == true
end

-- Request one native dressing. The returned record is an admitted request,
-- never evidence that treatment happened.
function T.begin(actorId, actorBody, patientId, patientBody, item, part, options)
    local s = store()
    local actor, patient = identity(actorId), identity(patientId)
    options = type(options) == "table" and options or {}
    if not s or not actor or not patient or actorBody == nil
        or patientBody == nil or item == nil or part == nil
        or not bodyMatches(actor, actorBody)
        or not bodyMatches(patient, patientBody)
        or not closeEnough(actorBody, patientBody)
        or not openWound(part) then
        return nil, "treatment-access-refused"
    end
    local index = partIndex(part)
    if index == nil or not partBelongs(patientBody, part, index) then
        return nil, "patient-part-refused"
    end
    local actorInventory = inventory(actorBody)
    if actorInventory == nil or not itemIn(item, actorInventory) then
        return nil, "bandage-not-held"
    end
    local itemId, itemType = itemIdentity(item)
    if itemId == nil or itemType == nil then
        return nil, "bandage-identity-unavailable"
    end
    for _, existing in pairs(s.records or {}) do
        if existing and existing.status == "pending"
            and ((existing.actorId == actor and existing.itemId == itemId
                    and existing.itemType == itemType)
                or (existing.patientId == patient
                    and existing.bodyPartIndex == index)) then
            return nil, "treatment-reserved"
        end
    end
    local id = nextId()
    if not id then return nil, "treatment-capacity" end
    local rec = {
        schema = SCHEMA, id = id, actorId = actor, patientId = patient,
        itemId = itemId, itemType = itemType, bodyPartIndex = index,
        createdAt = now(), status = "pending",
        effect = effectCopy(options.effect, actor, patient),
        effectApplied = false,
    }
    s.records[id] = rec
    runtime[id] = {
        actorBody = actorBody, patientBody = patientBody, item = item,
        part = part, actorInventory = actorInventory,
    }
    local class = ensureBandageClass()
    local action = class and class.new(class, actorBody, patientBody, item,
        part, id) or nil
    if not action or not queue(action) then
        setTerminal(rec, "released", "queue-refused", runtime[id])
        return nil, "queue-refused"
    end
    runtime[id].action = action
    log(actor .. " began treating " .. patient .. " as " .. id)
    return rec
end

function T.result(id)
    return record(id)
end

function T.reconcile(force)
    local s = store()
    if not s or type(s.records) ~= "table" then return 0 end
    local stamp = now()
    if not force and lastReconcileAt == stamp then return 0 end
    lastReconcileAt = stamp
    local changed = 0
    for id, rec in pairs(s.records) do
        if rec and rec.status == "completed" and not rec.effectApplied then
            if applyRecordEffect(rec, runtime[tostring(id)]) then
                changed = changed + 1
            end
        elseif rec and rec.status == "pending" then
            local live = runtime[tostring(id)]
            if live and live.action and not live.unloadBlocked and ISTimedActionQueue
                and ISTimedActionQueue.hasAction then
                local present = false
                local ok = pcall(function()
                    present = ISTimedActionQueue.hasAction(live.action) == true
                end)
                if ok and not present then
                    setTerminal(rec, "interrupted", "queue-ended", live)
                    changed = changed + 1
                end
            end
            -- No runtime handle after reload means no native witness. The
            -- durable request stays pending and reserves its item and wound.
        end
    end
    return changed
end

local function unloadQueueEvidence(live)
    local ok, present, nativePresent, owner = pcall(function()
        local action = live.action
        if not ISTimedActionQueue or not ISTimedActionQueue.hasAction
            or not ISTimedActionQueue.getTimedActionQueue
            or action.character ~= live.actorBody
            or action.otherPlayer ~= live.patientBody then return nil end
        local queueOwner = ISTimedActionQueue.getTimedActionQueue(live.actorBody)
        if not queueOwner or queueOwner.character ~= live.actorBody then
            return nil
        end
        local inLua = ISTimedActionQueue.hasAction(action)
        if type(inLua) ~= "boolean" then return nil end
        local native = action.action
        if queueOwner.current == action and native == nil then return nil end
        local actions = live.actorBody:getCharacterActions()
        local inNative = false
        for i = 0, actions:size() - 1 do
            if native ~= nil and actions:get(i) == native then inNative = true end
        end
        return inLua, inNative, queueOwner
    end)
    if not ok then return nil end
    return present, nativePresent, owner
end

local function restoredActionAbsent(rec)
    local ok, absent = pcall(function()
        if not SAO.Body or type(SAO.Body.active) ~= "table"
            or type(SAO.Body.foreign) ~= "table" then return false end
        -- Body.get deliberately hides transitioning bodies. Their raw owner
        -- reference can still carry the doctor's native treatment action.
        local body = SAO.Body.active[rec.actorId] or SAO.Body.foreign[rec.actorId]
        local player = SAO.Standing and SAO.Standing.isPlayerKey
            and SAO.Standing.isPlayerKey(rec.actorId)
        if player then body = bodyFor(rec.actorId, nil, "actorBody") end
        if body == nil then
            if player then return false end
            for _, key in ipairs({ "returning", "failedRestore", "discarding", "unloaded" }) do
                if SAO.Body[key] and SAO.Body[key][rec.actorId] then return false end
            end
            return true
        end
        if not bodyMatches(rec.actorId, body) or not ISTimedActionQueue
            or type(ISTimedActionQueue.queues) ~= "table" then return false end
        local owner = ISTimedActionQueue.queues[body]
        if owner then
            if owner.character ~= body or type(owner.queue) ~= "table" then return false end
            for _, action in ipairs(owner.queue) do
                if tostring(action.saoTreatmentId) == tostring(rec.id) then return false end
            end
        end
        local actions = body:getCharacterActions()
        for i = 0, actions:size() - 1 do
            local action = actions:get(i)
            if not instanceof then return false end
            if instanceof(action, "LuaTimedActionNew") then
                local lua = action:getTable()
                if not lua or tostring(lua.saoTreatmentId) == tostring(rec.id) then return false end
            end
        end
        return true
    end)
    return ok and absent == true
end

-- A patient's unloaded body can still be held by somebody else's treatment.
-- Cancel through the action owner before releasing that cross-person handle.
function T.interruptForBodyUnload(personId, reason)
    local target, s = identity(personId), store()
    if not target or not s or type(s.records) ~= "table" then return false end
    for _, rec in pairs(s.records) do
        if rec and rec.status == "pending"
            and (rec.actorId == target or rec.patientId == target) then
            local live = runtime[tostring(rec.id)]
            if not live or not live.action then
                if live or not restoredPending[tostring(rec.id)]
                    or not restoredActionAbsent(rec) then return false end
                setTerminal(rec, "interrupted", reason or "body-unloaded", nil)
            else
                live.unloadBlocked = true
                if not bodyMatches(rec.actorId, live.actorBody) then return false end
                local present, nativePresent, owner = unloadQueueEvidence(live)
                if present == nil or nativePresent == nil then return false end
                local action = live.action
                live.unloadInterrupt, live.unloadCancelFailed = true, false
                local ok, result = pcall(function()
                    if nativePresent or owner.current == action then
                        if not ISTimedActionQueue.clear then return false end
                        return ISTimedActionQueue.clear(live.actorBody)
                    elseif present then
                        if not action.isStarted or not action.forceCancel
                            or not owner.removeFromQueue then return false end
                        local started = action:isStarted()
                        if started == true or (started ~= false
                            and action.action ~= nil) then return false end
                        local cancelled = action:forceCancel()
                        if cancelled == false or live.unloadCancelFailed then
                            return false
                        end
                        return owner:removeFromQueue(action)
                    end
                end)
                live.unloadInterrupt = nil
                if not ok or result == false or live.unloadCancelFailed then
                    return false
                end
                present, nativePresent, owner = unloadQueueEvidence(live)
                -- Vanilla clearQueue may retain its current pointer after wiping
                -- entries. Exact Lua membership and the native handle are decisive.
                if present ~= false or nativePresent ~= false then return false end
                live.unloadBlocked = nil
                setTerminal(rec, "interrupted", reason or "body-unloaded", live)
            end
        end
    end
    return true
end

function T.releasePerson(personId, reason)
    local target, s = identity(personId), store()
    if not target or not s then return 0 end
    local changed = 0
    for _, rec in pairs(s.records or {}) do
        if rec and rec.status == "pending"
            and (rec.actorId == target or rec.patientId == target)
            and setTerminal(rec, "released",
                reason or "participant-unavailable", runtime[tostring(rec.id)]) then
            changed = changed + 1
        end
    end
    return changed
end

function T.forgetPerson(personId)
    return T.releasePerson(personId, "participant-unavailable")
end

T._runtime = runtime

function T.rebindWorld()
    storeMemo = nil
    lastReconcileAt = nil
    for key in pairs(runtime) do runtime[key] = nil end
    for key in pairs(restoredPending) do restoredPending[key] = nil end
    return store() ~= nil
end

if Events and Events.OnInitGlobalModData then
    if T.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(T.onInitGlobalModData)
    end
    T.onInitGlobalModData = function() T.rebindWorld() end
    Events.OnInitGlobalModData.Add(T.onInitGlobalModData)
end
