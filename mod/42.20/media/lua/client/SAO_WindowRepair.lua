-- Actor-bound admission and measured completion over an optional installed action.
SAO = SAO or {}
SAO.WindowRepair = SAO.WindowRepair or {}
local W = SAO.WindowRepair
-- A reload must not replace the closure that still owns a native cancellation.
if W.runtimeCount then
    pcall(W.reset, "module-reload")
    return W
end
-- Installed Kahlua does not implement weak-key collection. Each action owns
-- its private binding closure; the module retains only admitted NPC runtime.
local BINDING_TOKEN = {}
local offers = {}
local offerCount = 0
local MAX_OFFERS = 128
local runtime = {}
local installed = nil
local cancellationOrder = {}
local MAX_CANCELLATIONS_PER_TICK = 32
local MAX_LEARNING_SCANS, MAX_LEARNING_OWNERS = 256, 32
local learningRecords, learningIterator = nil, nil
local PANE = "RepairableWindows.LargeGlassPane"
local NATIVE_WINDOW_INTERACTION_REACH = 2
local MAX_RESULTS = 32
local RESULT_FIELDS = { id=true, sequence=true, actorId=true, workId=true, purposeId=true,
    entryKey=true, itemId=true, fullType=true, world=true, bodyToken=true, x=true, y=true, z=true,
    windowIndex=true, north=true, startedAt=true, endedAt=true, status=true, reason=true,
    paneConsumed=true, nativeAttempted=true, smashedBefore=true, smashedAfter=true, glassRemovedAfter=true,
    nativeOwner=true, planningAcknowledged=true, learningAcknowledged=true }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function hours()
    local value = SAO.History and SAO.History.countyHours()
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value or nil
end
local function person(id) return SAO.Identity and SAO.Identity.get(id) end
local function binding(action)
    local getter = action and rawget(action, "_SAOWindowRepairBinding")
    if type(getter) ~= "function" then return nil end
    local b = getter(BINDING_TOKEN)
    return type(b) == "table" and b.seal == BINDING_TOKEN and b.action == action and b or nil
end
local function releaseBinding(action, b)
    if binding(action) ~= b then return false end
    -- The tombstone prevents any later validity/complete query from recapturing.
    action._SAOWindowRepairBinding = false
    return true
end
local function retireOffer(id)
    if offers[id] then offerCount = offerCount - 1 end
    offers[id] = nil
end
function W.expireOffers()
    -- Offers are decision-local: Controller consumes them without yielding.
    -- A tick boundary disposes all abandoned handles, bounded by MAX_OFFERS.
    offers = {}
    offerCount = 0
end
function W.offerCount() return offerCount end
local function integer(value) return type(value) == "number" and value == value and value >= 0 and value < 1000000000 and value % 1 == 0 end
local function ledger(rec, create)
    local s = rec and rec.windowRepair
    if s == nil and create then
        s = { schema = 1, nextWork = 0, nextResult = 0, outcomes = {}, order = {}, learningOmitted = 0 }
        rec.windowRepair = s
    end
    if type(s) ~= "table" or s.schema ~= 1 or type(s.outcomes) ~= "table" or type(s.order) ~= "table"
        or #s.order > MAX_RESULTS or type(s.nextWork) ~= "number" or s.nextWork < 0
        or s.nextWork % 1 ~= 0 or s.nextWork >= 1000000000
        or type(s.nextResult) ~= "number" or s.nextResult < 0 or s.nextResult % 1 ~= 0
        or s.nextResult >= 1000000000
        or (s.learningOmitted ~= nil and not integer(s.learningOmitted)) then return nil end
    local count, previous = 0, 0
    for key, sequence in pairs(s.order) do
        if not integer(key) or key < 1 or key > #s.order or not integer(sequence)
            or sequence < 1 or sequence > s.nextResult then return nil end
        count = count + 1
    end
    if count ~= #s.order then return nil end
    local seen = {}
    for _, sequence in ipairs(s.order) do
        if sequence <= previous or seen[tostring(sequence)] or type(s.outcomes[tostring(sequence)]) ~= "table" then return nil end
        previous, seen[tostring(sequence)] = sequence, true
    end
    for key in pairs(s.outcomes) do if not seen[key] then return nil end end
    return s
end
local function claimKey(id, body, window)
    local S = SAO.Standing
    if not S or not S.fallHasCome() then return nil end
    local c, sq = S.claimOf(id), window:getSquare()
    if not c or not sq or not S.insideClaim(id, body:getX(), body:getY())
        or sq:getX() < c.minX or sq:getX() > c.maxX or sq:getY() < c.minY or sq:getY() > c.maxY
        or sq:getZ() ~= (c.z or 0) then return nil end
    return table.concat({tostring(c.minX), tostring(c.minY), tostring(c.maxX), tostring(c.maxY),
        tostring(c.z or 0), tostring(S.groupOf and S.groupOf(id) or "")}, ":")
end
local function ordinary(id, body)
    local r, md = person(id), body and body:getModData()
    return r and not r.dead and body and not body:isDead() and body:isExistInTheWorld()
        and not r.zaoTransferPending and not r.crossedTransferPending
        and r.bodyOwner == nil and SAO.Body and SAO.Body.get(id) == body
        and SAO.Body.active and SAO.Body.active[id] == body
        and not (SAO.Body.foreign and SAO.Body.foreign[id]) and md
        and tostring(md.SAOPersonId or "") == id and md.SAOExternalOwner == nil
        and md.SAOExternalToken == r.bodyOwnerToken and md.ZAOOwned ~= true
        and SAOJavaBridge and SAOJavaBridge:isShell(body) == true and r or nil
end
local function capture(action)
    local body, window = action.character, action.window
    if not body or not window or not instanceof(window, "IsoWindow") then return nil end
    local world, sq, cell = getWorld(), window:getSquare(), body:getCell()
    if not world or not sq or not cell or world:getCell() ~= cell or window:getObjectIndex() < 0 then return nil end
    local md = body:getModData()
    local id = md.SAOPersonId and tostring(md.SAOPersonId) or nil
    return { body = body, window = window, square = sq, index = window:getObjectIndex(),
        north = window:getNorth(), inventory = body:getInventory(), cell = cell,
        world = world:getWorld(), personId = id, record = id and person(id),
        owner = md.SAOExternalOwner, token = md.SAOExternalToken, spent = false }
end
local function geometry(b, sight)
    local body, sq, window, world = b.body, b.square, b.window, getWorld()
    local here = body:getCurrentSquare()
    local living = b.cell:getObjectList():contains(body) or b.cell:getAddList():contains(body)
    if not world or world:getWorld() ~= b.world or world:getCell() ~= b.cell
        or body:getCell() ~= b.cell or not living or not here or not body:isExistInTheWorld() or body:isDead()
        or b.cell:getGridSquare(here:getX(), here:getY(), here:getZ()) ~= here
        or b.cell:getGridSquare(sq:getX(), sq:getY(), sq:getZ()) ~= sq
        or window:getSquare() ~= sq or window:getObjectIndex() ~= b.index
        or window:getNorth() ~= b.north or not sq:getObjects():contains(window)
        or math.floor(body:getZ()) ~= sq:getZ() then return false end
    -- These are the two primary interaction tiles selected by the native window helper.
    local other
    if b.north then other = sq:getN() else other = sq:getW() end
    if here ~= sq and here ~= other then
        -- Existing player queues may use the installed helper's diagonal fallback.
        -- Autonomous offers/work stay on the two primary interaction tiles.
        if b.work or sight or not AdjacentFreeTileFinder
            or AdjacentFreeTileFinder.FindWindowOrDoor(sq, window, body) ~= here then return false end
    end
    if not here:canStand() then return false end
    local dx, dy = sq:getX() + 0.5 - body:getX(), sq:getY() + 0.5 - body:getY()
    if dx * dx + dy * dy > NATIVE_WINDOW_INTERACTION_REACH * NATIVE_WINDOW_INTERACTION_REACH then return false end
    if sight and (body:CanSee(window) ~= true
        or dx * body:getForwardDirectionX() + dy * body:getForwardDirectionY() < 0) then return false end
    return true
end
local function bound(b, material, sight)
    local md = b.body:getModData()
    if tostring(md.SAOPersonId or "") ~= tostring(b.personId or "")
        or md.SAOExternalOwner ~= b.owner or md.SAOExternalToken ~= b.token
        or b.body:getInventory() ~= b.inventory or not geometry(b, sight) then return false end
    if b.personId and (person(b.personId) ~= b.record or not b.record or b.record.dead
        or b.record.zaoTransferPending or b.record.crossedTransferPending
        or not SAO.Body or SAO.Body.get(b.personId) ~= b.body) then return false end
    if b.work and (ordinary(b.personId, b.body) ~= b.record
        or b.record.windowRepairWork ~= b.work or b.work.status ~= "repairing"
        or ledger(b.record) ~= b.state or b.work.id ~= b.workId or b.work.purposeId ~= b.purposeId
        or b.work.entryKey ~= b.entryKey or b.work.itemId ~= b.itemId
        or b.work.startedAt ~= b.startedAt or not hours() or hours() < b.startedAt
        or claimKey(b.personId, b.body, b.window) ~= b.claim) then return false end
    if material and (not b.pane or tostring(b.pane:getID()) ~= b.itemId
        or b.pane:getFullType() ~= PANE or b.pane:getContainer() ~= b.inventory
        or not b.inventory:contains(b.pane) or b.inventory:getFirstType(PANE) ~= b.pane) then return false end
    return true
end
local function queued(action)
    local b = binding(action)
    local q = b and b.queue
    if q then return q:indexOf(action) ~= -1 or q.current == action end
    return ISTimedActionQueue and ISTimedActionQueue.hasAction(action) == true
end
local function scheduleCancellation(active)
    if active.retryQueued then return end
    active.retryQueued = true
    cancellationOrder[#cancellationOrder + 1] = active
end
local function retireAcknowledged(id, active)
    if runtime[id] ~= active then return runtime[id] == nil end
    local b, action = active.binding, active.action
    -- Removing a Lua queue entry is not acknowledgement from a started native action.
    if queued(action) or (b.cancelled and action.action and not b.stopAcknowledged) then return false end
    runtime[id] = nil
    releaseBinding(action, b)
    active.retryQueued = false
    for i = #cancellationOrder, 1, -1 do
        if cancellationOrder[i] == active then table.remove(cancellationOrder, i) end
    end
    return true
end

function W.outcome(id, sequence)
    local s = ledger(person(id))
    local row = s and s.outcomes[tostring(sequence)]
    if not row or row.actorId ~= id or row.sequence ~= sequence or row.id ~= id .. "/window-result/" .. tostring(sequence)
        or (row.status ~= "completed" and row.status ~= "interrupted")
        or type(row.workId) ~= "string" or type(row.purposeId) ~= "string"
        or not integer(sequence) or sequence < 1 or type(row.entryKey) ~= "string"
        or row.fullType ~= PANE or type(row.itemId) ~= "string" or type(row.world) ~= "string"
        or type(row.startedAt) ~= "number" or type(row.endedAt) ~= "number"
        or row.startedAt ~= row.startedAt or row.endedAt ~= row.endedAt
        or row.endedAt == math.huge or row.startedAt == -math.huge or row.endedAt < row.startedAt
        or row.nativeOwner ~= "AddWindowAction.complete" or type(row.paneConsumed) ~= "boolean" or type(row.nativeAttempted) ~= "boolean"
        or type(row.smashedAfter) ~= "boolean" or type(row.glassRemovedAfter) ~= "boolean"
        or (row.status == "completed" and (not row.nativeAttempted or not row.paneConsumed or row.smashedBefore ~= true
            or row.smashedAfter or row.glassRemovedAfter))
        or (row.paneConsumed and not row.nativeAttempted)
        or (row.planningAcknowledged ~= nil and type(row.planningAcknowledged) ~= "boolean")
        or (row.learningAcknowledged ~= nil and type(row.learningAcknowledged) ~= "boolean") then return nil end
    if getmetatable(row) then return nil end
    for key, value in pairs(row) do
        local kind = type(value)
        if not RESULT_FIELDS[key] or (kind ~= "string" and kind ~= "number" and kind ~= "boolean")
            or (kind == "number" and (value ~= value or value == math.huge or value == -math.huge))
            or (kind == "string" and #value > 512) then return nil end
    end
    local workSequence = tonumber(row.workId:match("/window%-work/(%d+)$"))
    if not integer(workSequence) or workSequence < 1 or workSequence > s.nextWork
        or row.workId ~= id .. "/window-work/" .. tostring(workSequence)
        or type(row.x) ~= "number" or type(row.y) ~= "number" or type(row.z) ~= "number"
        or row.x % 1 ~= 0 or row.y % 1 ~= 0 or row.z % 1 ~= 0
        or not integer(row.windowIndex) or type(row.north) ~= "boolean" or row.smashedBefore ~= true
        or type(row.reason) ~= "string" or (row.bodyToken ~= nil and type(row.bodyToken) ~= "string")
        or row.entryKey ~= "window:" .. row.x .. ":" .. row.y .. ":" .. row.z .. ":" .. row.windowIndex .. ":" .. tostring(row.north) then return nil end
    return copy(row)
end
function W.acknowledge(id, sequence)
    local s, row = ledger(person(id)), W.outcome(id, sequence)
    if not s or not row then return false end
    s.outcomes[tostring(sequence)].planningAcknowledged = true
    return true
end
function W.deliverLearning(id)
    id = tostring(id)
    local r, cognition = person(id), SAO.Cognition
    local s = ledger(r)
    if not r or r.dead or not s or not cognition or type(cognition.windowRepairOutcome) ~= "function" then return 0 end
    local delivered = 0
    for _, sequence in ipairs(s.order) do
        local row, stored = W.outcome(id, sequence), s.outcomes[tostring(sequence)]
        if row and row.status == "completed" and row.learningAcknowledged ~= true then
            local ok, accepted = pcall(cognition.windowRepairOutcome, id, row)
            if ok and accepted == true and person(id) == r and ledger(r) == s
                and s.outcomes[tostring(sequence)] == stored then
                local current, same = W.outcome(id, sequence), true
                for key, value in pairs(row) do if not current or current[key] ~= value then same = false end end
                for key, value in pairs(current or {}) do if row[key] ~= value then same = false end end
                if same then
                    stored.learningAcknowledged = true
                    delivered = delivered + 1
                end
            end
        end
    end
    return delivered
end
local function close(b, status, reason)
    local work, r = b.work, b.record
    if not work or work.status ~= "repairing" or r.windowRepairWork ~= work then return false end
    local s, at = ledger(r), hours()
    if not s or not at or at < work.startedAt then
        work.status, work.reason = "interrupted", "window-result-clock-or-ledger-unavailable"
        local active = runtime[b.personId]
        if active and active.binding == b then active.closed = true end
        return false
    end
    s.nextResult = s.nextResult + 1
    local row = { id = b.personId .. "/window-result/" .. tostring(s.nextResult), sequence = s.nextResult,
        actorId = b.personId, workId = work.id, purposeId = work.purposeId, entryKey = work.entryKey,
        itemId = b.itemId, fullType = PANE, world = b.world, bodyToken = b.token,
        x = b.square:getX(), y = b.square:getY(), z = b.square:getZ(), windowIndex = b.index, north = b.north,
        startedAt = work.startedAt, endedAt = at, status = status, reason = reason,
        paneConsumed = b.paneConsumed == true, nativeAttempted = b.nativeAttempted == true,
        smashedBefore = true, smashedAfter = b.window:isSmashed(),
        glassRemovedAfter = b.window:isGlassRemoved(), nativeOwner = "AddWindowAction.complete" }
    work.status, work.reason, work.resultSequence = status, reason, s.nextResult
    s.outcomes[tostring(s.nextResult)] = row
    s.order[#s.order + 1] = s.nextResult
    local active = runtime[b.personId]
    if active and active.binding == b then active.closed = true end
    if person(b.personId) == r and SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeWindowRepairOutcome then
        SAO.ProceduralPlanning.consumeWindowRepairOutcome(b.personId, s.nextResult)
    end
    if person(b.personId) == r then W.deliverLearning(b.personId) end
    return true
end
local function refuse(b, reason)
    if b and not (b.work and b.work.status == "completed") then
        b.cancelled = true
        close(b, "interrupted", reason)
    end
    return false
end
local function freezePane(b)
    if b.pane then return true end
    local pane = b.inventory:getFirstType(PANE)
    if not pane then return false end
    b.pane, b.itemId = pane, tostring(pane:getID())
    return true
end
function W.install()
    if installed then return true end
    if type(require) ~= "function" then return false end
    local ok, base = pcall(require, "RepairableWindows/AddWindowAction")
    if not ok or type(base) ~= "table" or type(base.new) ~= "function"
        or type(base.complete) ~= "function" or type(base.isValid) ~= "function"
        or type(base.isValidStart) ~= "function" or type(base.stop) ~= "function" then return false end
    local nativeNew, nativeComplete, nativeValid, nativeStart, nativeStop, nativePerform, nativeCancel =
        base.new, base.complete, base.isValid, base.isValidStart, base.stop, base.perform, base.forceCancel
    function base:new(character, window)
        -- NetTimedAction projects these exact native constructor argument names.
        local action = nativeNew(self, character, window)
        local b = capture(action)
        if b then
            b.seal, b.action = BINDING_TOKEN, action
            b.queue = ISTimedActionQueue.getTimedActionQueue(character)
            action._SAOWindowRepairBinding = function(token) if token == BINDING_TOKEN then return b end end
        else action._SAOWindowRepairBinding = false end
        return action
    end
    function base:isValidStart()
        local b = binding(self)
        return b and self.character == b.body and self.window == b.window and not b.spent and not b.cancelled and freezePane(b)
            and bound(b, true, false) and self.window:isSmashed() and nativeStart(self) == true or false
    end
    function base:isValid()
        local b = binding(self)
        return b and self.character == b.body and self.window == b.window and not b.spent and not b.cancelled
            and freezePane(b) and bound(b, true, false) and nativeValid(self) and true or false
    end
    function base:complete()
        local b = binding(self)
        if not b or self.character ~= b.body or self.window ~= b.window or b.spent or b.cancelled or not bound(b, true, false) or not self.window:isSmashed() then
            refuse(b, "window-material-or-owner-changed")
            return false
        end
        b.spent = true -- A second completion cannot consume another pane or issue another outcome.
        b.nativeAttempted = true
        local okComplete, result = pcall(nativeComplete, self)
        b.paneConsumed = not b.inventory:contains(b.pane)
        local measured = bound(b, false, false) and b.paneConsumed
            and not b.window:isSmashed() and not b.window:isGlassRemoved()
        if not okComplete or result ~= true or not measured then
            close(b, "interrupted", "native-window-effect-unconfirmed")
            return false
        end
        close(b, "completed", "native-window-and-pane-measured")
        return true
    end
    function base:stop()
        local b = binding(self)
        if not b then return false end
        if not b.work and (self.character ~= b.body or self.window ~= b.window) then return false end
        local q = b.queue
        local ownsCurrent = q.current == self and q:indexOf(self) == 1
            and self.character == b.body and self.window == b.window
            and ISTimedActionQueue.getTimedActionQueue(b.body) == q
        if not b.work then
            refuse(b, "native-window-repair-stopped")
            if not ownsCurrent then
                q:removeFromQueue(self)
                if q.current == self then q.current = nil end
                releaseBinding(self, b)
                return false
            end
            local okStop, result = pcall(nativeStop, self)
            releaseBinding(self, b)
            if not okStop then error(result) end
            return result
        end
        refuse(b, "native-window-repair-stopped")
        -- Preserve unrelated queued native work when retiring this exact owned action.
        b.stopAcknowledged = true
        if ownsCurrent then
            b.body:setIsFarming(false)
            q:onCompleted(self)
        else
            -- The old native owner has acknowledged stop. Retire only its old
            -- entry; starting another action or clearing shared flags belongs
            -- to the body's current queue, which may already have advanced.
            q:removeFromQueue(self)
            if q.current == self then q.current = nil end
        end
        local active = runtime[b.personId]
        if active and active.binding == b then retireAcknowledged(b.personId, active) end
    end
    function base:perform()
        local b = binding(self)
        -- A released action is a terminal tombstone, never another queue owner.
        if not b or self.character ~= b.body or self.window ~= b.window then return false end
        if not queued(self) then
            if not b.work then releaseBinding(self, b)
            else
                local active = runtime[b.personId]
                if active and active.binding == b and active.closed then retireAcknowledged(b.personId, active) end
            end
            return false
        end
        -- Native perform resolves its queue through the body. It may execute
        -- only while that lookup still names our originally captured queue.
        if ISTimedActionQueue.getTimedActionQueue(b.body) ~= b.queue
            or b.queue.current ~= self or b.queue:indexOf(self) ~= 1 then return false end
        local okPerform, result = pcall(nativePerform, self)
        if not b.work and not queued(self) then releaseBinding(self, b)
        elseif b.work then
            local active = runtime[b.personId]
            if active and active.binding == b and active.closed then retireAcknowledged(b.personId, active) end
        end
        if not okPerform then error(result) end
        return result
    end
    function base:forceCancel()
        local b = binding(self)
        if not b or self.character ~= b.body or self.window ~= b.window then return false end
        if b and b.work then
            -- The native queue is iterating while it calls forceCancel. Keep
            -- the exact owner for the independent retry after that iteration.
            refuse(b, "native-window-force-cancel")
            local active = runtime[b.personId]
            if active and active.binding == b then scheduleCancellation(active) end
            return nativeCancel(self)
        end
        if b then
            local okCancel, result = pcall(nativeCancel, self)
            releaseBinding(self, b)
            if not okCancel then error(result) end
            return result
        end
        return false
    end
    installed = base
    return true
end
function W.offer(id, body)
    id = tostring(id)
    retireOffer(id)
    if offerCount >= MAX_OFFERS then return nil end
    if not W.install() or not ordinary(id, body) or not hours() or runtime[id] then return nil end
    if SAOJavaBridge:hasPendingActions(body) then return nil end
    local inv, here = body:getInventory(), body:getCurrentSquare()
    local pane = inv and inv:getFirstType(PANE)
    if not pane or not here then return nil end
    -- Three loaded tiles contain the apertures whose primary interaction side is this tile.
    for _, offset in ipairs({{0,0}, {0,1}, {1,0}}) do
        local sq = body:getCell():getGridSquare(here:getX()+offset[1], here:getY()+offset[2], here:getZ())
        if sq then
            local objects = sq:getObjects()
            for i = 0, math.min(objects:size(), 128) - 1 do
                local window = objects:get(i)
                if instanceof(window, "IsoWindow") and window:isSmashed() then
                    local b = capture({ character = body, window = window })
                    if b and geometry(b, true) and claimKey(id, body, window) then
                        local key = "window:" .. sq:getX() .. ":" .. sq:getY() .. ":" .. sq:getZ()
                            .. ":" .. b.index .. ":" .. tostring(b.north)
                        local offer = { entryKey = key }
                        b.pane, b.itemId, b.claim, b.entryKey = pane, tostring(pane:getID()), claimKey(id, body, window), key
                        offers[id] = { offer = offer, binding = b }
                        offerCount = offerCount + 1
                        return offer
                    end
                end
            end
        end
    end
end
function W.begin(id, body, offer)
    id = tostring(id)
    local slot = offers[id]
    local observed = slot and slot.offer == offer and slot.binding
    retireOffer(id)
    local r = ordinary(id, body)
    if not observed or not r or observed.body ~= body or offer.entryKey ~= observed.entryKey or not bound(observed, true, true)
        or claimKey(id, body, observed.window) ~= observed.claim or SAOJavaBridge:hasPendingActions(body)
        or not SAO.ProceduralPlanning or runtime[id] then return false end
    local at = hours()
    if not at then return false end
    local s = ledger(r, true)
    if not s then return false end
    while #s.order >= MAX_RESULTS do
        local first = s.outcomes[tostring(s.order[1])]
        if not first or first.planningAcknowledged ~= true then return false end
        if first.status == "completed" and first.learningAcknowledged ~= true then
            s.learningOmitted = math.min(999999999, (s.learningOmitted or 0) + 1)
        end
        s.outcomes[tostring(table.remove(s.order, 1))] = nil
    end
    local purpose = SAO.ProceduralPlanning.planFortification(id, { operation = "repair", entryKey = offer.entryKey,
        insideOwnedGround = true, knownGround = true, hasPane = true })
    if not purpose then return false end
    s.nextWork = s.nextWork + 1
    local work = { id = id .. "/window-work/" .. s.nextWork, purposeId = purpose.id, entryKey = offer.entryKey,
        status = "repairing", startedAt = at, itemId = observed.itemId }
    local action = installed:new(body, observed.window)
    local b = binding(action)
    if not b then return false end
    b.pane, b.itemId, b.claim, b.work = observed.pane, observed.itemId, observed.claim, work
    b.state, b.workId, b.purposeId, b.entryKey, b.startedAt = s, work.id, work.purposeId, work.entryKey, at
    b.queue = ISTimedActionQueue.getTimedActionQueue(body)
    r.windowRepairWork, runtime[id] = work, { action = action, binding = b }
    if not SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAO.WindowRepair", work.id)
        or not SAO.Needs.queueVerified(action) then
        refuse(b, "native-window-queue-refused")
        W.interrupt(id, body, "native-window-queue-refused")
        return false
    end
    return true
end
function W.interrupt(id, body, reason)
    id = tostring(id)
    local active = runtime[id]
    if not active then return true end
    local action, b = active.action, active.binding
    if active.closed and b.work.status == "completed" and not queued(action) then
        return retireAcknowledged(id, active)
    end
    refuse(b, reason or "window-repair-interrupted")
    scheduleCancellation(active)
    pcall(function()
        local q = b.queue
        if action.action and not b.stopAcknowledged then
            action.action:forceStop()
        elseif q.current == action then q:onCompleted(action)
        else q:removeFromQueue(action) end
    end)
    return retireAcknowledged(id, active)
end
function W.forget(id)
    id = tostring(id)
    retireOffer(id)
    local active = runtime[id]
    return W.interrupt(id, active and active.binding.body, "controller-forget")
end
function W.runtimeCount()
    local count = 0
    for _ in pairs(runtime) do count = count + 1 end
    return count
end
function W.retryCancellations()
    -- Visit each retained owner once in this bounded batch; a refused stop cannot starve another id.
    local count = math.min(#cancellationOrder, MAX_CANCELLATIONS_PER_TICK)
    for _ = 1, count do
        local active = table.remove(cancellationOrder, 1)
        if not active then break end
        active.retryQueued = false
        local b = active.binding
        if runtime[b.personId] == active then W.interrupt(b.personId, b.body, "window-cancellation-retry") end
    end
end
function W.active(id, body)
    id = tostring(id)
    local active = runtime[id]
    if not active then
        local r = person(id)
        if r and r.windowRepairWork and r.windowRepairWork.status == "repairing" then
            r.windowRepairWork.status, r.windowRepairWork.reason = "interrupted", "window-runtime-unavailable"
            SAO.ProceduralPlanning.interrupt(id, r.windowRepairWork.purposeId, "window-runtime-unavailable", hours())
        end
        return false
    end
    if active.closed or active.binding.body ~= body or not bound(active.binding, true, false)
        or not queued(active.action) then
        return not W.interrupt(id, body, "window-owner-or-queue-changed")
    end
    return true
end
function W.flush(id)
    id = tostring(id)
    local s = ledger(person(id))
    if not s then return end
    for _, sequence in ipairs(s.order) do
        local row = W.outcome(id, sequence)
        if row and row.planningAcknowledged ~= true and SAO.ProceduralPlanning
            and SAO.ProceduralPlanning.consumeWindowRepairOutcome then
            SAO.ProceduralPlanning.consumeWindowRepairOutcome(id, sequence)
        end
    end
    W.deliverLearning(id)
end
function W.retryLearning()
    local cognition, identity = SAO.Cognition, SAO.Identity
    if not cognition or type(cognition.settings) ~= "function" or not identity
        or type(identity.all) ~= "function" then return 0, 0, 0 end
    local ok, settings = pcall(cognition.settings)
    if not ok or not settings or settings.enabled ~= true then return 0, 0, 0 end
    local records = identity.all()
    if type(records) ~= "table" then return 0, 0, 0 end
    if learningRecords ~= records or not learningIterator then
        -- Installed Kahlua snapshots keys for pairs; next is not an installed global.
        learningRecords, learningIterator = records, pairs(records)
    end
    local delivered, visited, owners = 0, 0, 0
    while visited < MAX_LEARNING_SCANS and owners < MAX_LEARNING_OWNERS do
        local id, rec = learningIterator()
        if id == nil then
            learningRecords, learningIterator = nil, nil
            break
        end
        visited = visited + 1
        if type(rec) == "table" and not rec.dead and rec.windowRepair then
            owners = owners + 1
            delivered = delivered + W.deliverLearning(tostring(id))
        end
    end
    return delivered, visited, owners
end
function W.reset(reason)
    for id, active in pairs(runtime) do W.interrupt(id, active.binding.body, reason or "window-world-reset") end
    W.expireOffers()
    learningRecords, learningIterator = nil, nil
end
if Events and Events.OnTick then Events.OnTick.Add(W.retryCancellations); Events.OnTick.Add(W.expireOffers) end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(W.reset) end
if Events and Events.EveryOneMinute then Events.EveryOneMinute.Add(W.retryLearning) end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() W.reset("world-reset"); W.install(); W.retryLearning() end) end
return W
