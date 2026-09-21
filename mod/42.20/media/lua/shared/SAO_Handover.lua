-- SAO_Handover - the owner of a personal item handover.
--
-- A conversation may request a vanilla inventory transfer, but the request is
-- not the fact. This owner keeps the durable scalar record, retains the live
-- engine objects only for the current action, and publishes social effects
-- after the native action proves that the item reached the other inventory.
-- The saved side never contains an item, inventory, body, action, or closure.

SAO = SAO or {}
SAO.Handover = SAO.Handover or {}
local H = SAO.Handover

local STORE_KEY = "SurvivorAwareness_Handovers"
local SCHEMA = 1
local MAX_RECORDS = 512
local MAX_TERMS = 256
local MAX_DISTANCE = 6

local storeMemo = nil
local runtime = {}
local transferClass = nil
local terminal = nil
local lastReconcileAt = nil

local function log(message)
    if SAO.Log and SAO.Log.line then
        pcall(SAO.Log.line, "HANDOVER", tostring(message))
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
        value.terms = type(value.terms) == "table" and value.terms or {}
    elseif tonumber(value.schema) ~= SCHEMA then
        -- A future schema is not safe to reinterpret. Leave it untouched and
        -- refuse new work until its migration is explicit.
        return nil
    end
    storeMemo = value
    return value
end

local function mapCount(map)
    local count = 0
    for _ in pairs(map or {}) do count = count + 1 end
    return count
end

local function trim(map, limit, mayRemove)
    local count = mapCount(map)
    while count >= limit do
        local oldestKey, oldestAt = nil, nil
        for key, value in pairs(map or {}) do
            if mayRemove(value) then
                local at = tonumber(value.terminalAt or value.completedAt
                    or value.cancelledAt or value.createdAt
                    or value.acceptedAt) or 0
                if oldestKey == nil or at < oldestAt
                    or (at == oldestAt and tostring(key) < tostring(oldestKey)) then
                    oldestKey, oldestAt = key, at
                end
            end
        end
        if oldestKey == nil then return false end
        map[oldestKey] = nil
        runtime[tostring(oldestKey)] = nil
        count = count - 1
    end
    return true
end

local function trimRecords(s)
    return trim(s.records, MAX_RECORDS, function(value)
        return value and terminal(value.status)
    end)
end

local function trimTerms(s)
    return trim(s.terms, MAX_TERMS, function(value)
        return value and (value.status == "completed"
            or value.status == "partial" or value.status == "cancelled")
    end)
end

local function nextId(prefix, limit)
    local s = store()
    if not s then return nil end
    local count = 0
    if type(s.records) == "table" then
        for _ in pairs(s.records) do count = count + 1 end
    end
    if prefix == "T" then
        count = 0
        for _ in pairs(s.terms or {}) do count = count + 1 end
    end
    if count >= limit then return nil end
    s.nextSequence = (tonumber(s.nextSequence) or 0) + 1
    return prefix .. tostring(s.nextSequence)
end

local function identity(value)
    if value == nil then return nil end
    return tostring(value)
end

local function bodyIdentity(body)
    if body == nil then return nil end
    local ok, value = pcall(function()
        local data = body:getModData()
        return data and data.SAOPersonId or nil
    end)
    return ok and identity(value) or nil
end

local function inventories(body)
    if body == nil then return nil end
    local ok, value = pcall(function() return body:getInventory() end)
    return ok and value or nil
end

local function itemIdentity(item)
    if item == nil then return nil, nil end
    local okId, id = pcall(function() return item:getID() end)
    local okType, fullType = pcall(function() return item:getFullType() end)
    if not okType or fullType == nil then
        okType, fullType = pcall(function() return item:getType() end)
    end
    if not okId or id == nil or not okType or fullType == nil then
        return nil, nil
    end
    return tostring(id), tostring(fullType)
end

local function itemIn(item, inventory)
    if item == nil or inventory == nil then return false end
    local ok, container = pcall(function() return item:getContainer() end)
    return ok and container == inventory
end

local function closeEnough(actorBody, recipientBody)
    if actorBody == nil or recipientBody == nil then return false end
    local ok, ax, ay, az, bx, by, bz = pcall(function()
        return actorBody:getX(), actorBody:getY(), actorBody:getZ(),
            recipientBody:getX(), recipientBody:getY(), recipientBody:getZ()
    end)
    if not ok or not ax or not ay or not az or not bx or not by or not bz then
        return false
    end
    if tonumber(az) ~= tonumber(bz) then return false end
    local dx, dy = tonumber(ax) - tonumber(bx), tonumber(ay) - tonumber(by)
    return dx * dx + dy * dy <= MAX_DISTANCE * MAX_DISTANCE
end

local function sameBodyId(expected, body)
    local actual = bodyIdentity(body)
    return actual ~= nil and actual == identity(expected)
end

local function effectCopy(effect)
    if type(effect) ~= "table" then return {} end
    local out = { trust = {}, settle = nil, voice = nil, log = nil }
    if type(effect.trust) == "table" then
        for _, change in ipairs(effect.trust) do
            if type(change) == "table"
                and identity(change.from) and identity(change.to)
                and tonumber(change.delta) then
                out.trust[#out.trust + 1] = {
                    from = identity(change.from), to = identity(change.to),
                    delta = tonumber(change.delta),
                }
            end
        end
    end
    if type(effect.settle) == "table"
        and identity(effect.settle.creditor)
        and identity(effect.settle.debtor)
        and tonumber(effect.settle.amount) then
        out.settle = {
            creditor = identity(effect.settle.creditor),
            debtor = identity(effect.settle.debtor),
            amount = tonumber(effect.settle.amount),
        }
    end
    if type(effect.voice) == "table" and identity(effect.voice.actor)
        and type(effect.voice.kind) == "string" then
        out.voice = { actor = identity(effect.voice.actor),
            kind = effect.voice.kind, at = tonumber(effect.voice.at) or now() }
    end
    if type(effect.log) == "string" then out.log = effect.log end
    if type(effect.aid) == "table" and identity(effect.aid.recipient) then
        out.aid = {
            recipient = identity(effect.aid.recipient),
            actor = identity(effect.aid.actor),
            at = tonumber(effect.aid.at) or now(),
            xp = tonumber(effect.aid.xp),
        }
    end
    return out
end

terminal = function(status)
    return status == "completed" or status == "released"
        or status == "interrupted" or status == "conflict"
end

local function record(id)
    local s = store()
    return s and s.records and s.records[tostring(id)] or nil
end

local function term(id)
    local s = store()
    return s and s.terms and s.terms[tostring(id)] or nil
end

local function applyEffect(effect)
    if type(effect) ~= "table" then return end
    if type(effect.trust) == "table" and SAO.Standing
        and SAO.Standing.adjustTrust then
        for _, change in ipairs(effect.trust) do
            pcall(SAO.Standing.adjustTrust, change.from, change.to,
                change.delta)
        end
    end
    if effect.settle and SAO.Standing and SAO.Standing.settleDebt then
        pcall(SAO.Standing.settleDebt, effect.settle.creditor,
            effect.settle.debtor, effect.settle.amount)
    end
    if effect.voice and SAO.Voice and SAO.Voice.onEvent then
        pcall(SAO.Voice.onEvent, effect.voice.actor, effect.voice.kind,
            effect.voice.at)
    end
    if effect.aid then
        local agent = SAO.Controller and SAO.Controller.agents
            and SAO.Controller.agents[effect.aid.recipient] or nil
        if agent then agent.aidedAt = effect.aid.at end
        if effect.aid.actor and effect.aid.xp and SAO.Body
            and SAO.Body.get and SAOJavaBridge then
            pcall(function()
                local body = SAO.Body.get(effect.aid.actor)
                if body then SAOJavaBridge:grantXP(body, "Doctor",
                    effect.aid.xp) end
            end)
        end
    end
    if effect.log then log(effect.log) end
end

local function applyRecordEffect(rec)
    if rec.effectApplied then return end
    applyEffect(rec.effect)
    rec.effectApplied = true
end

local function finalizeTerm(termId)
    local t = term(termId)
    if not t or t.status == "proposed" or t.status == "cancelled" then
        return
    end
    local first, second = t.legs and t.legs.first, t.legs and t.legs.second
    if not first or not second then return end
    if not terminal(first.status) or not terminal(second.status) then return end
    if first.status == "completed" and second.status == "completed" then
        t.status = "completed"
        t.completedAt = t.completedAt or now()
        if not t.effectApplied then
            applyEffect(t.effect)
            t.effectApplied = true
        end
        return
    end
    local completed = first.status == "completed" and first
        or second.status == "completed" and second or nil
    if not completed then
        t.status = "cancelled"
        t.cancelledAt = t.cancelledAt or now()
        return
    end
    t.status = "partial"
    t.completedAt = t.completedAt or now()
    if completed and not t.debtApplied and SAO.Standing
        and SAO.Standing.addDebt then
        local okDebt = pcall(SAO.Standing.addDebt, completed.actorId,
            completed.recipientId, 1)
        if okDebt then
            t.debtApplied = true
            log(completed.recipientId .. " owes " .. completed.actorId
                .. " one (partial " .. tostring(t.offeredKind) .. "/"
                .. tostring(t.requestedKind) .. " handover)")
        else
            log("partial handover debt could not be applied for "
                .. tostring(t.id))
        end
    end
end

local function setTerminal(rec, status, reason)
    if not rec or not terminal(status) then return false end
    if terminal(rec.status) then return rec.status == status end
    rec.status = status
    rec.terminalAt = now()
    log(tostring(rec.id) .. " became " .. status .. " ("
        .. tostring(reason or status) .. ")")
    local t = rec.termsId and term(rec.termsId) or nil
    if t and t.legs and t.legs[rec.termLeg] then
        t.legs[rec.termLeg].status = status
        finalizeTerm(rec.termsId)
    end
    runtime[tostring(rec.id)] = nil
    return true
end

local function runtimeValid(rec, live)
    return rec and live and rec.status == "pending"
        and live.item ~= nil and live.actorBody ~= nil
        and live.recipientBody ~= nil
        and sameBodyId(rec.actorId, live.actorBody)
        and sameBodyId(rec.recipientId, live.recipientBody)
        and closeEnough(live.actorBody, live.recipientBody)
        and itemIn(live.item, live.sourceInventory)
end

local function ensureTransferClass()
    if transferClass ~= nil then return transferClass end
    if not ISInventoryTransferAction
        or not ISInventoryTransferAction.derive then return nil end
    local ok, class = pcall(function()
        return ISInventoryTransferAction:derive("SAOHandoverTransferAction")
    end)
    if not ok or class == nil then return nil end
    transferClass = class

    function transferClass:isValid()
        local rec = record(self.saoHandoverId)
        local live = rec and runtime[self.saoHandoverId] or nil
        if not rec or not live or rec.status ~= "pending" then return false end
        local okBase, base = pcall(ISInventoryTransferAction.isValid, self)
        if not okBase or base ~= true then return false end
        return runtimeValid(rec, live)
    end

    function transferClass:transferItem(item)
        local rec = record(self.saoHandoverId)
        local live = rec and runtime[self.saoHandoverId] or nil
        if not rec or not live or not self:isValid() then
            self.dontAdd = true
            if rec and rec.status == "pending" then
                setTerminal(rec, "interrupted", "invalid-before-transfer")
            end
            return false
        end
        local okBase, result = pcall(ISInventoryTransferAction.transferItem,
            self, item)
        if not okBase then
            setTerminal(rec, "conflict", "native-transfer-threw")
            return false
        end
        if itemIn(live.item, live.destinationInventory)
            and not itemIn(live.item, live.sourceInventory) then
            rec.status = "completed"
            rec.completedAt = now()
            local t = rec.termsId and term(rec.termsId) or nil
            if t and t.legs and t.legs[rec.termLeg] then
                t.legs[rec.termLeg].status = "completed"
                finalizeTerm(rec.termsId)
            else
                applyRecordEffect(rec)
            end
            runtime[tostring(rec.id)] = nil
            return result
        end
        setTerminal(rec, "conflict", "holder-mismatch")
        return false
    end

    function transferClass:stop()
        local rec = record(self.saoHandoverId)
        local okBase, result = pcall(ISInventoryTransferAction.stop, self)
        if rec and rec.status == "pending" then
            setTerminal(rec, "interrupted", "action-stopped")
        end
        return okBase and result or nil
    end

    function transferClass:new(character, item, sourceInventory,
            destinationInventory, handoverId)
        local ok, action = pcall(ISInventoryTransferAction.new, self,
            character, item, sourceInventory, destinationInventory)
        if not ok or action == nil then return nil end
        action.saoHandoverId = tostring(handoverId)
        return action
    end
    return transferClass
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

local function termLeg(termId, leg)
    local t = term(termId)
    local value = t and t.legs and t.legs[leg] or nil
    return t, value
end

-- Propose bilateral terms before either item is queued. This creates durable
-- leg slots but no agreement, debt, trust, or voice.
function H.proposeTerms(initiatorId, recipientId, offeredKind, requestedKind,
        effect, at)
    local s = store()
    local a, b = identity(initiatorId), identity(recipientId)
    if not s or not a or not b or a == b
        or type(offeredKind) ~= "string" or offeredKind == ""
        or type(requestedKind) ~= "string" or requestedKind == "" then
        return nil, "invalid-terms"
    end
    if not trimTerms(s) then return nil, "terms-capacity" end
    local id = nextId("T", MAX_TERMS)
    if not id then return nil, "terms-capacity" end
    s.terms[id] = {
        schema = SCHEMA, id = id, initiatorId = a, recipientId = b,
        offeredKind = offeredKind, requestedKind = requestedKind,
        proposedAt = tonumber(at) or now(), status = "proposed",
        legs = {
            first = { actorId = a, recipientId = b, kind = offeredKind,
                status = "not-started" },
            second = { actorId = b, recipientId = a, kind = requestedKind,
                status = "not-started" },
        }, effect = effectCopy(effect),
    }
    return id
end

-- Acceptance exists only after both native actions have independently entered
-- their queues. Later interruption can then create a real partial exchange.
function H.acceptTerms(termId, at)
    local t = term(termId)
    local first, second = t and t.legs and t.legs.first,
        t and t.legs and t.legs.second
    if not t or t.status ~= "proposed" or not first or not second
        or first.status ~= "pending" or second.status ~= "pending" then
        return false
    end
    t.status = "accepted"
    t.acceptedAt = tonumber(at) or now()
    return true
end

function H.cancelTerms(termId, reason)
    local t = term(termId)
    if not t or t.status == "completed" or t.status == "partial"
        or t.status == "cancelled" then return false end
    for _, legName in ipairs({ "first", "second" }) do
        local leg = t.legs and t.legs[legName] or nil
        if leg and leg.status == "not-started" then
            leg.status = "released"
        elseif leg and leg.handoverId then
            local rec = record(leg.handoverId)
            if rec and rec.status == "pending" then
                setTerminal(rec, "released", reason or "terms-cancelled")
            end
        end
    end
    finalizeTerm(termId)
    if t.status == "proposed" or t.status == "accepted" then
        t.status = "cancelled"
        t.cancelledAt = now()
        t.cancelReason = tostring(reason or "terms-cancelled")
    end
    return true
end

function H.cancelTermLeg(termId, legName, reason)
    local t, leg = termLeg(termId, legName)
    if not t or not leg or terminal(leg.status) then return false end
    if t.status == "proposed" then
        return H.cancelTerms(termId, reason or "term-leg-cancelled")
    end
    if leg.handoverId then
        local rec = record(leg.handoverId)
        if rec and rec.status == "pending" then
            setTerminal(rec, "released", reason or "term-leg-cancelled")
            return true
        end
    end
    leg.status = "released"
    finalizeTerm(termId)
    return true
end

-- Reserve one native item and queue the action. The returned record is a
-- reservation receipt; it is not completion evidence.
function H.begin(actorId, actorBody, recipientId, recipientBody, item, kind,
        options)
    local s = store()
    local a, b = identity(actorId), identity(recipientId)
    options = type(options) == "table" and options or {}
    if not s or not a or not b or a == b or actorBody == nil
        or recipientBody == nil or item == nil or type(kind) ~= "string"
        or kind == "" or not sameBodyId(a, actorBody)
        or not sameBodyId(b, recipientBody) or not closeEnough(actorBody,
            recipientBody) then
        return nil, "handover-access-refused"
    end
    local sourceInventory, destinationInventory = inventories(actorBody),
        inventories(recipientBody)
    if sourceInventory == nil or destinationInventory == nil
        or sourceInventory == destinationInventory or not itemIn(item,
            sourceInventory) then
        return nil, "item-not-held"
    end
    local itemId, itemType = itemIdentity(item)
    if itemId == nil or itemType == nil then
        return nil, "item-identity-unavailable"
    end
    for _, existing in pairs(s.records or {}) do
        if existing and existing.status == "pending"
            and existing.actorId == a and existing.itemId == itemId
            and existing.itemType == itemType then
            return nil, "item-reserved"
        end
    end
    local termsId, legName = identity(options.termsId), options.leg
    local t, leg = nil, nil
    if termsId then
        if legName ~= "first" and legName ~= "second" then
            return nil, "term-leg-invalid"
        end
        t, leg = termLeg(termsId, legName)
        if not t or t.status ~= "proposed" or not leg
            or leg.status ~= "not-started" or leg.actorId ~= a
            or leg.recipientId ~= b or leg.kind ~= kind then
            return nil, "term-not-available"
        end
    end
    if not trimRecords(s) then return nil, "handover-capacity" end
    local id = nextId("H", MAX_RECORDS)
    if not id then return nil, "handover-capacity" end
    local rec = {
        schema = SCHEMA, id = id, actorId = a, recipientId = b, kind = kind,
        itemId = itemId, itemType = itemType,
        createdAt = now(), status = "pending",
        termsId = termsId, termLeg = legName,
        effect = termsId and {} or effectCopy(options.effect),
    }
    s.records[id] = rec
    runtime[id] = { item = item, actorBody = actorBody,
        recipientBody = recipientBody, sourceInventory = sourceInventory,
        destinationInventory = destinationInventory }
    local class = ensureTransferClass()
    local action = class and class.new(class, actorBody, item, sourceInventory,
        destinationInventory, id) or nil
    if not action or not queue(action) then
        runtime[id] = nil
        setTerminal(rec, "released", "queue-refused")
        if t and leg then leg.handoverId = id end
        return nil, "queue-refused"
    end
    runtime[id].action = action
    if t and leg then
        leg.handoverId = id
        leg.status = "pending"
    end
    log(a .. " queued " .. kind .. " for " .. b .. " as " .. id)
    return rec
end

function H.result(id)
    return record(id)
end

function H.reconcile(force)
    local s = store()
    if not s or type(s.records) ~= "table" then return 0 end
    local stamp = now()
    if not force and lastReconcileAt == stamp then return 0 end
    lastReconcileAt = stamp
    local changed = 0
    for id, rec in pairs(s.records) do
        if rec and rec.status == "pending" then
            local live = runtime[tostring(id)]
            if live then
                local actionPresent = false
                local hasQueue = false
                if ISTimedActionQueue and ISTimedActionQueue.hasAction then
                    local okQueue = pcall(function()
                        actionPresent = ISTimedActionQueue.hasAction(live.action)
                            == true
                    end)
                    hasQueue = okQueue
                end
                if itemIn(live.item, live.destinationInventory)
                    and not itemIn(live.item, live.sourceInventory) then
                    rec.status, rec.completedAt = "completed", now()
                    local t = rec.termsId and term(rec.termsId) or nil
                    if t and t.legs and t.legs[rec.termLeg] then
                        t.legs[rec.termLeg].status = "completed"
                        finalizeTerm(rec.termsId)
                    else
                        applyRecordEffect(rec)
                    end
                    runtime[tostring(rec.id)] = nil
                    changed = changed + 1
                elseif hasQueue and not actionPresent then
                    if itemIn(live.item, live.sourceInventory) then
                        setTerminal(rec, "interrupted", "queue-ended")
                    else
                        setTerminal(rec, "conflict", "holder-mismatch")
                    end
                    changed = changed + 1
                end
            end
            -- A pending record without a live action is deliberately left
            -- pending on reload. No runtime handle means no native witness.
        end
    end
    return changed
end

-- Death retains the person and completed history, but no live action can keep
-- either participant's engine handles. Accepted partial terms still finalize
-- through their ordinary terminal-leg rule.
function H.forgetPerson(personId)
    local target, s = identity(personId), store()
    if not target or not s then return 0 end
    local changed = 0
    for termId, value in pairs(s.terms or {}) do
        if value and (value.status == "proposed" or value.status == "accepted")
            and (value.initiatorId == target or value.recipientId == target)
            and H.cancelTerms(termId, "participant-unavailable") then
            changed = changed + 1
        end
    end
    for _, rec in pairs(s.records or {}) do
        if rec and rec.status == "pending" and not rec.termsId
            and (rec.actorId == target or rec.recipientId == target)
            and setTerminal(rec, "released", "participant-unavailable") then
            changed = changed + 1
        end
    end
    return changed
end

function H.pending(id)
    local rec = record(id)
    return rec and rec.status == "pending" or false
end

H._runtime = runtime

function H.rebindWorld()
    storeMemo = nil
    lastReconcileAt = nil
    for key in pairs(runtime) do runtime[key] = nil end
    return store() ~= nil
end

if Events and Events.OnInitGlobalModData then
    if H.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(H.onInitGlobalModData)
    end
    H.onInitGlobalModData = function() H.rebindWorld() end
    Events.OnInitGlobalModData.Add(H.onInitGlobalModData)
end
