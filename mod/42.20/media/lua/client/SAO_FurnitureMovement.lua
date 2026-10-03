-- Shared, loaded-singleplayer furniture movement over the installed physical owner.
-- Effort completion is not movement completion. The installed SP shove queue has
-- no cancellation token: keep its animation, and own only its bounded delay here.
-- Native pickup/place, item transfer and composed fixture callbacks remain native.
SAO = SAO or {}
SAO.FurnitureMovement = SAO.FurnitureMovement or {}
local M = SAO.FurnitureMovement
if M.install then M.reset("module-reload"); return M end

local MAX_PENDING, MAX_RESULTS, MAX_MEMBERS, MAX_ITEMS = 32, 64, 64, 4096
local MAX_PENDING_MS = 10000
local pending, results, sequence, generation = {}, {}, 0, 0
local installed, active, bathIso, bathFluid = nil, nil, nil, nil

local function singleplayer() return not isClient() and not isServer() end
local function clock() return getTimestampMs() end
local function coords(square) return square:getX(), square:getY(), square:getZ() end
local function finite(n) return type(n) == "number" and n == n and n > -math.huge and n < math.huge end
local function contains(square, object)
    local objects = square and square:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do if objects:get(i) == object then return true end end
    return false
end
local function sprite(object)
    local s = object and object:getSprite()
    return s and s:getName()
end
local function actorAvailable(character, cell)
    if not character or character:isDead() or character:isNpc() or character:getVehicle()
        or not character:isExistInTheWorld() or character:getCell() ~= cell then return false end
    local square = character:getSquare()
    return square and cell:getGridSquare(square:getX(), square:getY(), square:getZ()) == square
end
local function receipt(binding, status, reason, nativeReturn)
    sequence = sequence + 1
    local row = { sequence=sequence, status=status,
        reason=type(reason) == "string" and string.sub(reason, 1, 160) or "unspecified",
        nativeReturn=nativeReturn == true,
        observedAt=clock(), mode=binding and binding.mode or "unknown" }
    if binding then
        row.sourceX, row.sourceY, row.sourceZ = binding.x, binding.y, binding.z
        row.destinationX, row.destinationY, row.destinationZ = binding.dx, binding.dy, binding.dz
        row.members = #binding.members
    end
    results[#results + 1] = row
    if #results > MAX_RESULTS then table.remove(results, 1) end
end
function M.outcomes()
    local copy = {}
    for i, row in ipairs(results) do
        copy[i] = {}
        for k, v in pairs(row) do copy[i][k] = v end
    end
    return copy
end
function M.pendingCount() return #pending end

local function activated(id)
    return getActivatedMods and getActivatedMods():contains(id)
end
local function bathAllowed(object, square)
    if not activated("TakeABathAndShowerNew") then return true end
    if not bathIso or not bathFluid then
        local okIso, iso = pcall(require, "TABAS_Iso")
        local okFluid, fluid = pcall(require, "TubFluidContainer/TABAS_TubFluidContainerSystemUtils")
        if not okIso or not okFluid or type(iso) ~= "table" or type(fluid) ~= "table"
            or type(iso.isBathObject) ~= "function" or type(fluid.hasTfcData) ~= "function" then
            return false, "bath-owner-unavailable"
        end
        bathIso, bathFluid = iso, fluid
    end
    if bathIso.isBathObject(object) and bathFluid.hasTfcData(square) then return false, "bath-in-use" end
    return true
end

-- InventoryItem identity survives native relocation; IsoObject identity does not.
-- Include nested inventories so their contents cannot change unnoticed during delay.
local function inventorySnapshot(container, budget, depth)
    if depth > 16 then return nil end
    local snapshot = { container=container, items={} }
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if budget.seen[item] or budget.count >= MAX_ITEMS then return nil end
        budget.seen[item], budget.count = true, budget.count + 1
        local entry = { item=item }
        if instanceof(item, "InventoryContainer") then
            entry.nested = inventorySnapshot(item:getInventory(), budget, depth + 1)
            if not entry.nested then return nil end
        end
        snapshot.items[#snapshot.items + 1] = entry
    end
    return snapshot
end
local function inventoryMatches(snapshot, container, nested)
    if not container or (nested and snapshot.container ~= container) then return false end
    local items = container:getItems()
    if items:size() ~= #snapshot.items then return false end
    local seen = {}
    for i = 0, items:size() - 1 do seen[items:get(i)] = true end
    for _, entry in ipairs(snapshot.items) do
        if not seen[entry.item] or entry.item:getContainer() ~= container then return false end
        seen[entry.item] = nil
        if entry.nested and not inventoryMatches(entry.nested, entry.item:getInventory(), true) then return false end
    end
    return true
end
local function contentsMatch(member, object)
    if object:getContainerCount() ~= #member.containers then return false end
    for i, snapshot in ipairs(member.containers) do
        local container = object:getContainerByIndex(i - 1)
        if not inventoryMatches(snapshot, container, false) then return false end
    end
    return true
end

local function waterState(object)
    if not object:getFluidContainer() then return nil end
    local amount, capacity = object:getFluidAmount(), object:getFluidCapacity()
    if not finite(amount) or not finite(capacity) or amount ~= 0 or capacity <= 0 then return nil end
    return capacity
end
local function scalarCopy(row)
    if type(row) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(row) do
        local t = type(v)
        if type(k) ~= "string" or (t ~= "string" and t ~= "boolean" and not finite(v)) then return nil end
        copy[k] = v
    end
    return copy
end
local function sameScalars(left, right)
    if left == nil or right == nil then return left == right end
    for k, v in pairs(left) do if right[k] ~= v then return false end end
    for k, v in pairs(right) do if left[k] ~= v then return false end end
    return true
end
local function waterPreflight(binding)
    local water, sourceKeys = {}, {}
    for _, member in ipairs(binding.members) do
        if WPIso and WPIso.IsBarrel and WPIso.IsBarrel(member.object) then
            -- GetWaterStatus changes and transmits the fixture. Read only the
            -- supported empty native fluid component here; other shapes remain open.
            local capacity = waterState(member.object)
            if not capacity then return nil, "water-fixture-state" end
            if not WPServer or not WPServer.Commands or not WPServer.Commands.BarrelAdd
                or not WPServer.Commands.BarrelRemove or not WPUtils or not WPUtils.Coords2Id
                or not GetWPModData or not WPIso.GetBarrel then return nil, "water-authority-unavailable" end
            local data = GetWPModData()
            if not data or type(data.Barrels) ~= "table" then return nil, "water-authority-unavailable" end
            local x, y, z = coords(member.square)
            local k = WPUtils.Coords2Id(x, y, z)
            local old = data.Barrels[k]
            local saved = old and scalarCopy(old) or nil
            if sourceKeys[k] or WPIso.GetBarrel(member.square) ~= member.object
                or (old and (not saved or old.w ~= 0 or old.wmax ~= capacity * 100
                    or old.x ~= x or old.y ~= y or old.z ~= z)) then return nil, "water-fixture-state" end
            sourceKeys[k] = true
            water[#water + 1] = { member=member, capacity=capacity, registry=data.Barrels, old=saved, sourceKey=k }
        end
    end
    for _, state in ipairs(water) do
        local x, y, z = coords(state.member.target)
        local k = WPUtils.Coords2Id(x, y, z)
        if state.registry[k] and not sourceKeys[k] then return nil, "water-destination-registered" end
        state.destinationKey = k
        state.destinationOld = state.registry[k] and scalarCopy(state.registry[k]) or nil
    end
    return water
end

local function bind(character, object, destination, mode)
    if not actorAvailable(character, getCell()) or not object or not destination then return nil, "actor-unavailable" end
    local fpp = FurniturePushPull
    if not fpp.validateServerMove(character, object, mode, destination) then return nil, "move-not-valid" end
    local source = object:getSquare()
    if not contains(source, object) then return nil, "source-unavailable" end
    local props = fpp.getMoveableData(object)
    local members = props and fpp.getFurnitureMembers(object, props)
    if not members or #members < 1 or #members > MAX_MEMBERS then return nil, "footprint-unavailable" end
    local b = { character=character, object=object, destination=destination, cell=getCell(), generation=generation, mode=mode, members={} }
    b.x, b.y, b.z = coords(source)
    b.dx, b.dy, b.dz = coords(destination)
    local budget, seen = {count=0,seen={}}, {}
    for _, member in ipairs(members) do
        local obj, square = member.object, member.square
        if not obj or seen[obj] or obj:getSquare() ~= square or not contains(square, obj)
            or not sprite(obj) then return nil, "footprint-unavailable" end
        seen[obj] = true
        local allowed, why = bathAllowed(obj, square)
        if not allowed then return nil, why end
        local x, y, z = coords(square)
        local target = fpp.getSquare(x + b.dx - b.x, y + b.dy - b.y, z)
        if not target then return nil, "destination-unavailable" end
        local m = { object=obj, square=square, target=target, sprite=sprite(obj), containers={}, before={} }
        local objects = target:getObjects()
        for i = 0, objects:size() - 1 do m.before[objects:get(i)] = true end
        for i = 0, obj:getContainerCount() - 1 do
            local snapshot = inventorySnapshot(obj:getContainerByIndex(i), budget, 0)
            if not snapshot then return nil, "contents-unavailable" end
            m.containers[#m.containers + 1] = snapshot
        end
        b.members[#b.members + 1] = m
    end
    local water, reason = waterPreflight(b)
    if not water then return nil, reason end
    b.water = water
    return b
end

local function current(binding)
    if getCell() ~= binding.cell or generation ~= binding.generation then return false, "world-changed" end
    local actor = binding.character
    if not actorAvailable(actor, binding.cell) then return false, "actor-unavailable" end
    if not FurniturePushPull.validateServerMove(actor, binding.object, binding.mode, binding.destination) then
        return false, "move-not-valid"
    end
    local props = FurniturePushPull.getMoveableData(binding.object)
    local members = props and FurniturePushPull.getFurnitureMembers(binding.object, props)
    if not members or #members ~= #binding.members then return false, "footprint-changed" end
    local currentMembers = {}
    for _, m in ipairs(members) do currentMembers[m.object] = m.square end
    for _, m in ipairs(binding.members) do
        local x, y, z = coords(m.square)
        if FurniturePushPull.getSquare(x, y, z) ~= m.square or not contains(m.square, m.object)
            or m.object:getSquare() ~= m.square or sprite(m.object) ~= m.sprite
            or currentMembers[m.object] ~= m.square then return false, "source-changed" end
        x, y, z = coords(m.target)
        if FurniturePushPull.getSquare(x, y, z) ~= m.target then return false, "destination-changed" end
        local objects, count = m.target:getObjects(), 0
        for _ in pairs(m.before) do count = count + 1 end
        if objects:size() ~= count then return false, "destination-changed" end
        for i = 0, objects:size() - 1 do
            if not m.before[objects:get(i)] then return false, "destination-changed" end
        end
        if not contentsMatch(m, m.object) then return false, "contents-changed" end
        local allowed, reason = bathAllowed(m.object, m.square)
        if not allowed then return false, reason end
    end
    local water, reason = waterPreflight(binding)
    if not water then return false, reason end
    if #water ~= #binding.water then return false, "water-fixture-changed" end
    for i, row in ipairs(water) do
        if row.registry ~= binding.water[i].registry or row.sourceKey ~= binding.water[i].sourceKey
            or not sameScalars(row.old, binding.water[i].old)
            or not sameScalars(row.destinationOld, binding.water[i].destinationOld) then return false, "water-fixture-changed" end
    end
    return true
end

local function measure(binding)
    local changed, complete, used = false, true, {}
    for _, m in ipairs(binding.members) do
        if contains(m.square, m.object) then complete = false else changed = true end
        local found = nil
        local objects = m.target:getObjects()
        for i = 0, objects:size() - 1 do
            local candidate = objects:get(i)
            if not m.before[candidate] and sprite(candidate) == m.sprite then
                if found then complete = false end
                found = candidate
            end
        end
        if not found or used[found] or not contentsMatch(m, found) then complete = false end
        if found then used[found], changed = true, true end
        m.placed = found
    end
    return complete, changed
end

local function reconcileWater(binding)
    if #binding.water == 0 then return true end
    local data = GetWPModData()
    local destinations = {}
    -- Validate the whole result before changing either registry coordinate.
    for _, water in ipairs(binding.water) do
        local m = water.member
        if data.Barrels ~= water.registry or not m.placed or not WPIso.IsBarrel(m.placed)
            or WPIso.GetBarrel(m.target) ~= m.placed or waterState(m.placed) ~= water.capacity
            or not sameScalars(data.Barrels[water.sourceKey], water.old)
            or not sameScalars(data.Barrels[water.destinationKey], water.destinationOld) then return false end
        local x, y, z = coords(m.target)
        local k = WPUtils.Coords2Id(x, y, z)
        if destinations[k] then return false end
        local row = water.old and scalarCopy(water.old) or {w=0,wmax=water.capacity * 100}
        row.x, row.y, row.z, row.bid = x, y, z, nil
        destinations[k] = row
        local building = m.target:getBuilding()
        if building then destinations[k].bid = building:getDef():getIDString() end
    end
    for _, water in ipairs(binding.water) do
        local m = water.member
        local x, y, z = coords(m.square)
        local k = WPUtils.Coords2Id(x, y, z)
        if not destinations[k] and not WPIso.GetBarrel(m.square) then
            WPServer.Commands.BarrelRemove(binding.character, {x=x,y=y,z=z})
            if data.Barrels[k] ~= nil then return false end
        end
    end
    for k, args in pairs(destinations) do
        WPServer.Commands.BarrelAdd(binding.character, args)
        local registered = data.Barrels[k]
        if not registered or registered.w ~= 0 or registered.wmax ~= args.wmax
            or registered.x ~= args.x or registered.y ~= args.y or registered.z ~= args.z then return false end
    end
    return true
end

local function execute(binding, original)
    local okCurrent, valid, reason = pcall(current, binding)
    if not okCurrent or not valid then
        receipt(binding, "refused", okCurrent and reason or "preflight-error")
        return false
    end
    active = binding
    local ok, nativeResult = pcall(original, binding.character, binding.object, binding.destination)
    active = nil
    local measured, complete, changed = pcall(measure, binding)
    if ok and nativeResult == true and measured and complete
        and binding.cell == getCell() and binding.generation == generation then
        local waterOk, reconciled = pcall(reconcileWater, binding)
        if waterOk and reconciled then
            receipt(binding, "completed", "measured-relocation", true)
            return true
        end
        receipt(binding, "partial", "water-reconciliation", true)
        return false
    end
    receipt(binding, (not measured or changed) and "partial" or "failed",
        not ok and "native-error" or (not measured and "measurement-error" or "relocation-incomplete"), nativeResult)
    return false
end

local function guardedBind(character, object, destination, mode)
    local ok, binding, reason = pcall(bind, character, object, destination, mode)
    if not ok or not binding then
        receipt(nil, "refused", ok and reason or "preflight-error")
        return nil
    end
    return binding
end
function M.reset(reason)
    for _, binding in ipairs(pending) do receipt(binding, "cancelled", reason or "world-reset") end
    pending, active, bathIso, bathFluid = {}, nil, nil, nil
    generation = generation + 1
end
function M.tick()
    if not singleplayer() then M.reset("authority-changed"); return end
    local now = clock()
    for i = #pending, 1, -1 do
        local binding = pending[i]
        if binding and (now < binding.queuedAt or now > binding.expires) then
            table.remove(pending, i)
            receipt(binding, "expired", "delay-expired")
        elseif binding and now >= binding.due then
            table.remove(pending, i)
            if execute(binding, installed.serverMove) then
                FurniturePushPull.applyEndurance(binding.character, binding.endurance)
                FurniturePushPull.playMoveFeedback(binding.character, binding.members[1].square)
            end
        end
    end
end

function M.install()
    if installed then return true end
    local fpp, client = FurniturePushPull, FurniturePushPullClient
    if not fpp or not client or type(fpp.executeMove) ~= "function" or type(fpp.executeServerMove) ~= "function"
        or type(client.playOriginalPushShove) ~= "function" then return false end
    installed = {move=fpp.executeMove,serverMove=fpp.executeServerMove,shove=client.playOriginalPushShove}
    function fpp.executeMove(character, object, destination)
        if not singleplayer() then return installed.move(character, object, destination) end
        if active then return false end
        local b = guardedBind(character, object, destination, "pull")
        return b and execute(b, installed.move) or false
    end
    function fpp.executeServerMove(character, object, destination)
        if not singleplayer() then return installed.serverMove(character, object, destination) end
        if active and not active.delegated and active.character == character
            and active.object == object and active.destination == destination then
            active.delegated = true
            return installed.serverMove(character, object, destination)
        end
        -- SP pushes use our authenticated scheduler. No stale native callback
        -- or unbound direct invocation may turn into a fresh physical operation.
        receipt(nil, "refused", "unbound-relocation")
        return false
    end
    function client.playOriginalPushShove(character, sx, sy, sz, name, dx, dy, dz, queueMove)
        if not singleplayer() or not queueMove then
            return installed.shove(character, sx, sy, sz, name, dx, dy, dz, queueMove)
        end
        if #pending >= MAX_PENDING then receipt(nil, "refused", "pending-capacity"); return end
        for _, b in ipairs(pending) do
            if b.character == character then receipt(nil, "refused", "actor-pending"); return end
        end
        local object = fpp.findObject(sx, sy, sz, name)
        local destination = fpp.getSquare(dx, dy, dz)
        local b = guardedBind(character, object, destination, "push")
        if not b then return end
        local plan = fpp.validateServerMove(character, object, "push", destination)
        b.queuedAt = clock()
        b.due = b.queuedAt + fpp.PUSH_MOVE_DELAY_MS
        b.expires = b.queuedAt + MAX_PENDING_MS
        b.endurance = plan.enduranceCost
        -- Do not schedule the installed private coordinate-only callback too.
        local ok = pcall(installed.shove, character, sx, sy, sz, name, dx, dy, dz, false)
        if not ok then receipt(b, "refused", "shove-error"); return end
        pending[#pending + 1] = b
    end
    return true
end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(function() M.reset("world-reset") end) end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() M.reset("world-start"); M.install() end) end
if Events and Events.OnTick then Events.OnTick.Add(M.tick) end
return M
