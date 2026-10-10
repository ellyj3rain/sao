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
local function availablePane(item)
    return item and item:getFullType() == PANE and item:getIsCraftingConsumed() ~= true
end
local NATIVE_WINDOW_INTERACTION_REACH = 2
local MAX_RESULTS = 32
local RESULT_FIELDS = { id=true, sequence=true, actorId=true, workId=true, purposeId=true,
    entryKey=true, itemId=true, fullType=true, world=true, bodyToken=true, x=true, y=true, z=true,
    windowIndex=true, north=true, startedAt=true, endedAt=true, status=true, reason=true,
    paneConsumed=true, nativeAttempted=true, smashedBefore=true, smashedAfter=true, glassRemovedAfter=true,
    nativeOwner=true, planningAcknowledged=true, learningAcknowledged=true,
    stepId=true, recoveryOnly=true, nativeObservability=true }
local WORK_FIELDS = { id=true, purposeId=true, entryKey=true, status=true, startedAt=true, itemId=true,
    actorId=true, stepId=true, nativeOwner=true, world=true, bodyToken=true, x=true, y=true, z=true,
    windowIndex=true, north=true, reason=true, resultSequence=true }
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function hours()
    local value = SAO.History and SAO.History.countyHours()
    return finite(value) and value or nil
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
local function preparationBinding(action)
    local getter = action and rawget(action, "_SAOWindowRepairPreparation")
    if type(getter) ~= "function" then return nil end
    local c = getter(BINDING_TOKEN)
    return type(c) == "table" and c.seal == BINDING_TOKEN and c.action == action and c or nil
end
local function preparationQueued(c)
    local q = c.binding.queue
    return q:indexOf(c.action) ~= -1 or q.current == c.action
end
local function preparationRefused() return false end
local function releasePreparation(c)
    c.action._SAOWindowRepairPreparation = false
    for _, name in ipairs({"isValidStart", "isValid", "complete", "perform", "stop", "forceCancel"}) do
        c.action[name] = preparationRefused
    end
end
local function currentAction(active)
    local c = active.preparation
    return c and not c.acknowledged and c.action or active.action
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
local function windowEntry(entry)
    if type(entry) ~= "string" then return false end
    local x, y, z, index, north = entry:match("^window:(%-?%d+):(%-?%d+):(%-?%d+):(%d+):(%a+)$")
    x, y, z, index = tonumber(x), tonumber(y), tonumber(z), tonumber(index)
    return finite(x) and finite(y) and finite(z) and integer(index)
        and (north == "true" or north == "false")
        and entry == "window:" .. x .. ":" .. y .. ":" .. z .. ":" .. index .. ":" .. north
end
local function ledger(rec, create)
    local s = rec and rec.windowRepair
    if s == nil and create then
        s = { schema = 1, nextWork = 0, nextResult = 0, outcomes = {}, order = {}, learningOmitted = 0 }
        rec.windowRepair = s
    end
    if type(s) ~= "table" or getmetatable(s) or s.schema ~= 1
        or type(s.outcomes) ~= "table" or getmetatable(s.outcomes)
        or type(s.order) ~= "table" or getmetatable(s.order)
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
    local side = here == sq and -1 or 1
    local facingX, facingY = b.north and 0 or side, b.north and side or 0
    if sight and (body:CanSee(window) ~= true
        or facingX * body:getForwardDirectionX() + facingY * body:getForwardDirectionY() < 0) then return false end
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
    if b.purpose then
        local state = b.record.proceduralPlanning
        local p = state and state.purposes and state.purposes[b.purposeId]
        local step = p and p.steps and p.steps[p.cursor]
        local admission = p and p.admission
        if p ~= b.purpose or step ~= b.step or not admission
            or admission.owner ~= "SAO.WindowRepair" or admission.correlationId ~= b.workId
            or admission.stepId ~= step.id or step.owner ~= "SAO.WindowRepair"
            or step.target ~= b.entryKey or step.token ~= "construction:window-repaired" then return false end
    end
    if material then
        if not b.pane or tostring(b.pane:getID()) ~= b.itemId or not availablePane(b.pane) then return false end
        if b.preparing then
            local source = b.preparationSource
            if not source or source == b.inventory or b.pane:getContainer() ~= source
                or source:getOutermostContainer() ~= b.inventory or not source:contains(b.pane) then return false end
        elseif b.pane:getContainer() ~= b.inventory or not b.inventory:contains(b.pane)
            or b.inventory:getFirstType(PANE) ~= b.pane then return false end
    end
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
    local c = active.preparation
    if c and (preparationQueued(c) or c.action.action and not c.acknowledged) then return false end
    -- Removing a Lua queue entry is not acknowledgement from a started native action.
    if queued(action) or (b.cancelled and action.action and not b.stopAcknowledged) then return false end
    runtime[id] = nil
    releaseBinding(action, b)
    if c then releasePreparation(c) end
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
        or row.fullType ~= PANE or type(row.itemId) ~= "string" or not windowEntry(row.entryKey)
        or not finite(row.startedAt) or not finite(row.endedAt) or row.endedAt < row.startedAt
        or type(row.reason) ~= "string" or (row.bodyToken ~= nil and type(row.bodyToken) ~= "string")
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
        or row.workId ~= id .. "/window-work/" .. tostring(workSequence) then return nil end
    if row.recoveryOnly == true then
        -- Lost runtime establishes interrupted execution, never a material/window poststate.
        if row.status ~= "interrupted" or row.reason ~= "window-runtime-unavailable"
            or row.nativeOwner ~= "SAO.WindowRepair.reconcileSaved" or row.nativeObservability ~= "runtime-unavailable"
            or type(row.stepId) ~= "string" or row.stepId == ""
            or row.paneConsumed ~= nil or row.nativeAttempted ~= nil or row.smashedBefore ~= nil
            or row.smashedAfter ~= nil or row.glassRemovedAfter ~= nil or row.learningAcknowledged ~= nil then return nil end
        if row.world ~= nil then
            if type(row.world) ~= "string" or not finite(row.x) or not finite(row.y) or not finite(row.z)
                or row.x % 1 ~= 0 or row.y % 1 ~= 0 or row.z % 1 ~= 0
                or not integer(row.windowIndex) or type(row.north) ~= "boolean"
                or row.entryKey ~= "window:" .. row.x .. ":" .. row.y .. ":" .. row.z .. ":" .. row.windowIndex .. ":" .. tostring(row.north) then return nil end
        elseif row.x ~= nil or row.y ~= nil or row.z ~= nil or row.windowIndex ~= nil or row.north ~= nil or row.bodyToken ~= nil then return nil end
        return copy(row)
    end
    if row.recoveryOnly ~= nil or row.nativeObservability ~= nil or type(row.world) ~= "string"
        or row.nativeOwner ~= "AddWindowAction.complete" or type(row.paneConsumed) ~= "boolean" or type(row.nativeAttempted) ~= "boolean"
        or type(row.smashedAfter) ~= "boolean" or type(row.glassRemovedAfter) ~= "boolean"
        or (row.status == "completed" and (not row.nativeAttempted or not row.paneConsumed or row.smashedBefore ~= true
            or row.smashedAfter or row.glassRemovedAfter))
        or (row.paneConsumed and not row.nativeAttempted)
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
        actorId = b.personId, workId = work.id, purposeId = work.purposeId, stepId = work.stepId, entryKey = work.entryKey,
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
    if b.pane then return availablePane(b.pane) and true or false end
    local pane = b.inventory:getFirstTypeEval(PANE, availablePane)
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
        return b and not b.preparing and self.character == b.body and self.window == b.window and not b.spent and not b.cancelled and freezePane(b)
            and bound(b, true, false) and self.window:isSmashed() and nativeStart(self) == true or false
    end
    function base:isValid()
        local b = binding(self)
        return b and not b.preparing and self.character == b.body and self.window == b.window and not b.spent and not b.cancelled
            and freezePane(b) and bound(b, true, false) and nativeValid(self) and true or false
    end
    function base:complete()
        local b = binding(self)
        if not b or b.preparing or self.character ~= b.body or self.window ~= b.window or b.spent or b.cancelled or not bound(b, true, false) or not self.window:isSmashed() then
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
local function preparePane(active)
    local b = active.binding
    local action = ISInventoryTransferAction:new(b.body, b.pane, b.preparationSource, b.inventory)
    local c = { seal = BINDING_TOKEN, action = action, binding = b, item = b.pane,
        source = b.preparationSource, purpose = b.purpose, step = b.step }
    action._SAOWindowRepairPreparation = function(token) if token == BINDING_TOKEN then return c end end
    action.canMergeAction = function() return false end
    active.preparation = c
    local nativeValid, nativePerform = action.isValid, action.perform
    local function exact()
        return preparationBinding(action) == c and action.character == b.body and action.item == c.item
            and action.srcContainer == c.source and action.destContainer == b.inventory
    end
    local function purposeOwned()
        local state = b.record.proceduralPlanning
        local p = state and state.purposes and state.purposes[b.purposeId]
        local step = p and p.steps and p.steps[p.cursor]
        local admission = p and p.admission
        return p == c.purpose and step == c.step and admission
            and admission.owner == "SAO.WindowRepair" and admission.correlationId == b.workId
            and admission.stepId == step.id and step.owner == "SAO.WindowRepair"
            and step.target == b.entryKey and step.token == "construction:window-repaired"
    end
    local function ownsQueue()
        return exact() and ISTimedActionQueue.getTimedActionQueue(b.body) == b.queue
            and b.queue.current == action and b.queue:indexOf(action) == 1
    end
    local function valid()
        return exact() and not c.done and not active.closed and not b.cancelled and b.preparing
            and purposeOwned() and bound(b, true, false)
            and ISTimedActionQueue.getTimedActionQueue(b.body) == b.queue
    end
    c.valid = valid
    local function nativeEnded()
        local ok, ended = pcall(function()
            return action.action and action.action:isStarted()
                and (action.action:finished() or action.action:isForceComplete())
        end)
        return ok and ended == true
    end
    function action:isValidStart() return valid() and nativeValid(self) == true or false end
    function action:isValid() return valid() and nativeValid(self) == true or false end
    function action:complete() return false end
    function action:perform()
        local ql = self.queueList
        if c.performed or not ownsQueue() or not nativeEnded() or not valid() or type(ql) ~= "table" or #ql ~= 1
            or type(ql[1].items) ~= "table" or #ql[1].items ~= 1 or ql[1].items[1] ~= c.item then
            refuse(b, "window-pane-preparation-owner-changed")
            W.interrupt(b.personId, b.body, "window-pane-preparation-owner-changed")
            return false
        end
        c.performed = true
        local ok = pcall(nativePerform, self)
        c.done = true
        c.acknowledged = ok and not preparationQueued(c)
        b.preparing = false
        local measured = ok and exact() and purposeOwned() and not active.closed and not b.cancelled
            and bound(b, true, false) and c.item:getContainer() == b.inventory
            and not c.source:contains(c.item) and not preparationQueued(c)
            and ISTimedActionQueue.getTimedActionQueue(b.body) == b.queue
            and b.queue.current == nil and #b.queue.queue == 0
        if not measured or not SAO.Needs.queueVerified(active.action) then
            refuse(b, "native-window-pane-preparation-unconfirmed")
            W.interrupt(b.personId, b.body, "native-window-pane-preparation-unconfirmed")
            return false
        end
        releasePreparation(c)
        return true
    end
    function action:stop()
        if c.acknowledged or preparationBinding(self) ~= c then return false end
        local current = ownsQueue()
        refuse(b, "native-window-pane-preparation-stopped")
        c.acknowledged = true
        if current then
            pcall(function()
                self:playSourceContainerCloseSound()
                self:playDestContainerCloseSound()
                self:stopLoopingSound()
                c.item:setJobDelta(0)
                if self.action then self.action:setLoopedAction(false) end
                self.started = false
            end)
            b.queue:onCompleted(self)
        else
            b.queue:removeFromQueue(self)
            if b.queue.current == self then b.queue.current = nil end
        end
        return retireAcknowledged(b.personId, active)
    end
    function action:forceCancel()
        if c.acknowledged or preparationBinding(self) ~= c then return false end
        refuse(b, "native-window-pane-preparation-force-cancel")
        scheduleCancellation(active)
        if not self.action then c.acknowledged = true end
        return false
    end
    return action
end
function W.offer(id, body, entryKey)
    id = tostring(id)
    retireOffer(id)
    if offerCount >= MAX_OFFERS then return nil end
    if not W.install() or not ordinary(id, body) or not hours() or runtime[id] then return nil end
    if SAOJavaBridge:hasPendingActions(body) then return nil end
    local inv, here = body:getInventory(), body:getCurrentSquare()
    local pane = inv and inv:getFirstTypeEval(PANE, availablePane)
    if not here then return nil end
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
                        if entryKey == nil or entryKey == key then
                        local offer = { entryKey = key }
                        b.pane, b.itemId, b.claim, b.entryKey = pane, pane and tostring(pane:getID()), claimKey(id, body, window), key
                        offers[id] = { offer = offer, binding = b }
                        offerCount = offerCount + 1
                        return offer
                        end
                    end
                end
            end
        end
    end
end
function W.destination(id, body, offer)
    id = tostring(id)
    local slot = offers[id]
    local b = slot and slot.offer == offer and slot.binding
    if not b or not ordinary(id, body) or b.body ~= body or offer.entryKey ~= b.entryKey
        or not bound(b, false, true) or claimKey(id, body, b.window) ~= b.claim then return nil end
    return { key = b.entryKey, x = math.floor(body:getX()), y = math.floor(body:getY()),
        z = math.floor(body:getZ()) }
end
function W.begin(id, body, offer)
    id = tostring(id)
    local slot = offers[id]
    local observed = slot and slot.offer == offer and slot.binding
    retireOffer(id)
    local r = ordinary(id, body)
    if not observed or not r or observed.body ~= body or offer.entryKey ~= observed.entryKey or not bound(observed, false, true)
        or claimKey(id, body, observed.window) ~= observed.claim or SAOJavaBridge:hasPendingActions(body)
        or not SAO.ProceduralPlanning or runtime[id] then return false end
    if not observed.pane then
        observed.pane = observed.inventory:getFirstTypeEval(PANE, availablePane)
        if not observed.pane then
            local ok, pane = pcall(function() return observed.inventory:getFirstTypeEvalRecurse(PANE, availablePane) end)
            if ok then observed.pane = pane end
        end
        observed.itemId = observed.pane and tostring(observed.pane:getID())
    end
    if not observed.pane then return false end
    observed.preparationSource = observed.pane:getContainer()
    observed.preparing = observed.preparationSource ~= observed.inventory
    if not bound(observed, true, true) then return false end
    if observed.preparing then
        if isClient() or isServer() then return false end
        local ok = pcall(require, "TimedActions/ISInventoryTransferAction")
        if not ok or type(ISInventoryTransferAction) ~= "table" or type(ISInventoryTransferAction.new) ~= "function"
            or type(ISInventoryTransferAction.perform) ~= "function" then return false end
    end
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
        status = "repairing", startedAt = at, itemId = observed.itemId,
        actorId = id, stepId = purpose.steps[purpose.cursor].id, nativeOwner = "AddWindowAction.complete",
        world = observed.world, bodyToken = observed.token, x = observed.square:getX(), y = observed.square:getY(),
        z = observed.square:getZ(), windowIndex = observed.index, north = observed.north }
    local action = installed:new(body, observed.window)
    local b = binding(action)
    if not b then return false end
    b.pane, b.itemId, b.claim, b.work = observed.pane, observed.itemId, observed.claim, work
    b.state, b.workId, b.purposeId, b.entryKey, b.startedAt = s, work.id, work.purposeId, work.entryKey, at
    b.preparing, b.preparationSource = observed.preparing, observed.preparationSource
    b.purpose, b.step = purpose, purpose.steps[purpose.cursor]
    b.queue = ISTimedActionQueue.getTimedActionQueue(body)
    local active = { action = action, binding = b }
    r.windowRepairWork, runtime[id] = work, active
    local admitted = SAO.ProceduralPlanning.noteAdmission(id, purpose.id, "SAO.WindowRepair", work.id)
    local queuedAction = action
    if admitted and b.preparing then
        local ok, prepared = pcall(preparePane, active)
        if ok then queuedAction = prepared else admitted = false end
    end
    if not admitted or not SAO.Needs.queueVerified(queuedAction) then
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
    local action, b = currentAction(active), active.binding
    if active.closed and b.work.status == "completed" and not queued(active.action) then
        return retireAcknowledged(id, active)
    end
    refuse(b, reason or "window-repair-interrupted")
    scheduleCancellation(active)
    pcall(function()
        local q = b.queue
        local c = active.preparation
        local acknowledged = c and action == c.action and c.acknowledged or b.stopAcknowledged
        if action.action and not acknowledged then
            action.action:forceStop()
        elseif q.current == action then
            if c and action == c.action then c.acknowledged = true end
            q:onCompleted(action)
        else
            q:removeFromQueue(action)
            if c and action == c.action and not action.action then c.acknowledged = true end
        end
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
        return not W.reconcileSaved(id, body)
    end
    if active.closed or active.binding.body ~= body or not bound(active.binding, true, false)
        or (active.preparation and not active.preparation.acknowledged
            and (not active.preparation.valid() or not preparationQueued(active.preparation)))
        or (not active.preparation or active.preparation.acknowledged) and not queued(active.action) then
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
function W.reconcileSaved(id, body)
    id = tostring(id)
    -- Authentic terminal evidence is replayed before considering a lost owner.
    W.flush(id)
    if runtime[id] then return W.interrupt(id, body, "window-adoption-reconciliation") end
    local r = person(id)
    local work = r and r.windowRepairWork
    if work == nil then return true end
    if type(work) ~= "table" then return false end
    local ps = r.proceduralPlanning
    local p = ps and ps.purposes and ps.purposes[work.purposeId]
    local admission = p and p.admission
    local pinned = admission and admission.owner == "SAO.WindowRepair" and admission.correlationId == work.id
    if work.status ~= "repairing" and work.status ~= "interrupted" then return not pinned end
    if not pinned then return work.status == "interrupted" or work.resultSequence ~= nil end
    local s, at = ledger(r), hours()
    local step = p.steps and p.steps[p.cursor]
    local n = type(work.id) == "string" and tonumber(work.id:match("/window%-work/(%d+)$"))
    if ordinary(id, body) ~= r or r.id ~= id or getmetatable(work) or not s or not at or s.nextResult >= 999999999
        or not integer(n) or n < 1 or n ~= s.nextWork or work.id ~= id .. "/window-work/" .. n
        or type(work.purposeId) ~= "string" or type(work.itemId) ~= "string" or work.itemId == ""
        or not windowEntry(work.entryKey) or not finite(work.startedAt) or work.startedAt > at
        or p.id ~= work.purposeId or p.status == "completed" or p.status == "abandoned" or not p.windowRepair
        or not step or step.owner ~= "SAO.WindowRepair" or step.token ~= "construction:window-repaired"
        or step.target ~= work.entryKey or step.status == "completed"
        or admission.stepId ~= step.id or admission.target ~= work.entryKey or admission.token ~= step.token
        or not finite(admission.at) or admission.at ~= work.startedAt or work.resultSequence ~= nil then return false end
    for key, value in pairs(work) do
        local kind = type(value)
        if not WORK_FIELDS[key] or (kind ~= "string" and kind ~= "number" and kind ~= "boolean")
            or (kind == "number" and not finite(value)) or (kind == "string" and #value > 512) then return false end
    end
    -- Original schema-1 work has only the six admission scalars above. New
    -- work also preserves detached native anchors, whose complete shape is checked.
    if work.actorId ~= nil or work.world ~= nil or work.nativeOwner ~= nil or work.stepId ~= nil then
        if work.actorId ~= id or work.stepId ~= step.id or work.nativeOwner ~= "AddWindowAction.complete"
            or type(work.world) ~= "string" or work.world ~= getWorld():getWorld()
            or work.bodyToken ~= nil and type(work.bodyToken) ~= "string"
            or not finite(work.x) or not finite(work.y) or not finite(work.z)
            or work.x % 1 ~= 0 or work.y % 1 ~= 0 or work.z % 1 ~= 0
            or not integer(work.windowIndex) or type(work.north) ~= "boolean"
            or work.entryKey ~= "window:" .. work.x .. ":" .. work.y .. ":" .. work.z .. ":" .. work.windowIndex .. ":" .. tostring(work.north) then return false end
    elseif work.bodyToken ~= nil or work.x ~= nil or work.y ~= nil or work.z ~= nil or work.windowIndex ~= nil or work.north ~= nil then return false end
    local ok, pending = pcall(function() return SAOJavaBridge:hasPendingActions(body) end)
    if not ok or pending ~= false then return false end
    local q = ISTimedActionQueue.getTimedActionQueue(body)
    if q.current or #q.queue > 0 then return false end
    for _, sequence in ipairs(s.order) do
        local row = W.outcome(id, sequence)
        if not row or row.workId == work.id then return false end
    end
    while #s.order >= MAX_RESULTS do
        local first = s.outcomes[tostring(s.order[1])]
        if first.planningAcknowledged ~= true then return false end
        if first.status == "completed" and first.learningAcknowledged ~= true then
            s.learningOmitted = math.min(999999999, (s.learningOmitted or 0) + 1)
        end
        s.outcomes[tostring(table.remove(s.order, 1))] = nil
    end
    s.nextResult = s.nextResult + 1
    local row = { id = id .. "/window-result/" .. s.nextResult, sequence = s.nextResult, actorId = id,
        workId = work.id, purposeId = work.purposeId, stepId = step.id, entryKey = work.entryKey,
        itemId = work.itemId, fullType = PANE, status = "interrupted", reason = "window-runtime-unavailable",
        startedAt = work.startedAt, endedAt = at, recoveryOnly = true,
        nativeOwner = "SAO.WindowRepair.reconcileSaved", nativeObservability = "runtime-unavailable",
        world = work.world, bodyToken = work.bodyToken, x = work.x, y = work.y, z = work.z,
        windowIndex = work.windowIndex, north = work.north }
    s.outcomes[tostring(s.nextResult)] = row
    s.order[#s.order + 1] = s.nextResult
    work.status, work.reason, work.resultSequence = "interrupted", row.reason, s.nextResult
    W.flush(id)
    return row.planningAcknowledged == true and p.admission == nil
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
