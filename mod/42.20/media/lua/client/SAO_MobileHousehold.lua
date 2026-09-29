-- SAO_MobileHousehold.lua - native vehicles as moving places.
--
-- A camper is simultaneously a vehicle, a shelter, a store, a place people
-- can know, and (while occupied) a household.  None of those facts is granted
-- by a workshop id.  This owner derives them from the loaded vehicle, its
-- parts, its occupants, its towing edge and completed interior transitions.

SAO = SAO or {}
SAO.MobileHousehold = SAO.MobileHousehold or {}
local M = SAO.MobileHousehold

local STORE_KEY = "SurvivorAwareness_MobileHouseholds"
local MAX_TRANSITIONS, MAX_FAILURES = 32, 16
local MAX_MATERIAL_CONTAINERS = 512
local SCAN_INTERVAL = 30
local INTERIOR_ENTRY_REACH = 5
local nextScan = 0
-- A refresh cadence belongs to the loaded native vehicle, not its durable id.
-- Weak keys release the throttle as soon as the engine unloads that object.
local materialNext = setmetatable({}, { __mode = "k" })

local EXACT_KIND = {
    ["Base.RollingRefuge"] = "motorhome",
    ["Base.Trailer54FlyingCloud22"] = "camper",
    ["Base.Trailer61Airflyte"] = "camper",
    ["Base.Trailer61Astrodome"] = "camper",
    ["Base.Trailer61Bambi16"] = "camper",
    ["Base.Trailer87Scamp13"] = "camper",
    ["Base.Trailer87Scamp16"] = "camper",
    ["Base.TrailerKI5cargoLarge"] = "cargo-trailer",
    ["Base.TrailerKI5cargoMedium"] = "cargo-trailer",
    ["Base.TrailerKI5cargoSmall"] = "cargo-trailer",
    ["Base.TrailerKI5utilityLarge"] = "utility-trailer",
    ["Base.TrailerKI5utilityMedium"] = "utility-trailer",
    ["Base.TrailerKI5utilitySmall"] = "utility-trailer",
    ["Base.TrailerKI5livestock"] = "livestock-trailer",
}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function nowHours()
    local ok, value = pcall(function() return SAO.History.countyHours() end)
    return ok and finite(value) and value or 0
end

local function store()
    local ok, value = pcall(function() return ModData.getOrCreate(STORE_KEY) end)
    if not ok or type(value) ~= "table" then return nil end
    value.schema = 1
    value.nextVehicle = tonumber(value.nextVehicle) or 1
    value.vehicles = type(value.vehicles) == "table" and value.vehicles or {}
    value.aliases = type(value.aliases) == "table" and value.aliases or {}
    return value
end

local function scriptName(vehicle)
    local ok, value = pcall(function()
        local script = vehicle:getScript()
        return script and script:getFullName() or nil
    end)
    return ok and type(value) == "string" and value or nil
end

function M.classifyScript(name)
    name = tostring(name or "")
    if EXACT_KIND[name] then return EXACT_KIND[name] end
    local lower = string.lower(name)
    if lower:find("rollingrefuge", 1, true)
        or lower:find("winnebago", 1, true)
        or lower:find("motorhome", 1, true)
        or lower:find("bounder", 1, true)
        or lower:find("econolinerv", 1, true)
        or lower:find("campervan", 1, true) then return "motorhome" end
    if lower:find("camper", 1, true) or lower:find("caravan", 1, true)
        or lower:find("scamp", 1, true) or lower:find("bambi", 1, true)
        or lower:find("airflyte", 1, true)
        or lower:find("astrodome", 1, true)
        or lower:find("flyingcloud", 1, true) then return "camper" end
    if lower:find("livestock", 1, true) then return "livestock-trailer" end
    if lower:find("trailer", 1, true) and lower:find("cargo", 1, true) then
        return "cargo-trailer"
    end
    if lower:find("trailer", 1, true) and lower:find("utility", 1, true) then
        return "utility-trailer"
    end
    return nil
end

local function vehicleAlias(vehicle)
    local ok, value = pcall(function()
        local data = vehicle:getModData()
        return data and data.projectRV_uniqueId or nil
    end)
    return ok and value ~= nil and tostring(value) or nil
end

local function appendBounded(rows, value, maximum)
    rows[#rows + 1] = value
    while #rows > maximum do table.remove(rows, 1) end
end

local function transition(rec, personId, from, to, reason, at)
    if from == to then return end
    rec.transitions = rec.transitions or {}
    appendBounded(rec.transitions, { atHours = at, personId = personId,
        from = from or "outside", to = to or "outside",
        reason = tostring(reason or "native-state-change") }, MAX_TRANSITIONS)
end

local function vehicleId(vehicle, create)
    local s = store()
    if not s or not vehicle then return nil end
    local ok, data = pcall(function() return vehicle:getModData() end)
    if not ok or type(data) ~= "table" then return nil end
    local id = data.SAOMobileHouseholdId
    if id ~= nil and s.vehicles[tostring(id)] then return tostring(id) end
    local alias = vehicleAlias(vehicle)
    if alias and s.aliases[alias] and s.vehicles[s.aliases[alias]] then
        id = s.aliases[alias]
        data.SAOMobileHouseholdId = id
        return id
    end
    if not create then return nil end
    id = "mobile/" .. tostring(s.nextVehicle)
    s.nextVehicle = s.nextVehicle + 1
    data.SAOMobileHouseholdId = id
    s.vehicles[id] = { schema = 1, id = id, occupants = {}, members = {},
        transitions = {}, failures = {}, material = {}, materialRevision = 0 }
    if alias then s.aliases[alias] = id end
    return id
end

local function countContainer(container)
    if not container then return 0, 0 end
    local ok, count, weight = pcall(function()
        local items, total = container:getItems(), 0
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            total = total + (tonumber(item:getActualWeight()) or 0)
        end
        return items:size(), total
    end)
    return ok and tonumber(count) or 0, ok and tonumber(weight) or 0
end

local function materialSnapshot(vehicle)
    local rows, itemCount, weight, overflow = {}, 0, 0, 0
    local ok = pcall(function()
        for index = 0, vehicle:getPartCount() - 1 do
            local part = vehicle:getPartByIndex(index)
            local container = part and part:getItemContainer() or nil
            if container then
                local count, partWeight = countContainer(container)
                if #rows < MAX_MATERIAL_CONTAINERS then
                    rows[#rows + 1] = { part = tostring(part:getId()),
                        count = count, weight = partWeight,
                        capacity = tonumber(container:getCapacity()) or 0 }
                else
                    overflow = overflow + 1
                end
                itemCount, weight = itemCount + count, weight + partWeight
            end
        end
    end)
    if not ok then return nil end
    table.sort(rows, function(a, b) return a.part < b.part end)
    return { containers = rows, containerOverflow = overflow,
        itemCount = itemCount, weight = weight }
end

local function personIdOf(body)
    local ok, id = pcall(function() return body:getModData().SAOPersonId end)
    return ok and id ~= nil and tostring(id) or nil
end

local function towingId(vehicle, method)
    local ok, other = pcall(function() return vehicle[method](vehicle) end)
    if not ok or not other then return nil end
    return vehicleId(other, M.classifyScript(scriptName(other)) ~= nil)
end

function M.observeVehicle(vehicle, source)
    local name, kind = scriptName(vehicle), nil
    if name then kind = M.classifyScript(name) end
    if not kind then return nil end
    local id, s = vehicleId(vehicle, true), store()
    local rec = id and s and s.vehicles[id] or nil
    if not rec then return nil end
    local at = nowHours()
    rec.script, rec.kind = name, kind
    rec.source = tostring(source or "observed")
    rec.lastObservedAtHours = at
    rec.x, rec.y, rec.z = vehicle:getX(), vehicle:getY(), vehicle:getZ()
    local okSpeed, speed = pcall(function()
        return math.abs(vehicle:getCurrentSpeedKmHour())
    end)
    rec.speedKmh = okSpeed and tonumber(speed) or 0
    rec.motion = rec.speedKmh > 0.5 and "moving" or "stationary"
    rec.towing = towingId(vehicle, "getVehicleTowing")
    rec.towedBy = towingId(vehicle, "getVehicleTowedBy")
    if rec.towing and s.vehicles[rec.towing] then
        s.vehicles[rec.towing].towedBy = id
    end
    if rec.towedBy and s.vehicles[rec.towedBy] then
        s.vehicles[rec.towedBy].towing = id
    end
    local alias = vehicleAlias(vehicle)
    if alias then
        rec.externalInteriorId, s.aliases[alias] = alias, id
        local okExternal, external = pcall(function()
            return ModData.getOrCreate("modPROJECTRVInterior")
        end)
        if okExternal and type(external) == "table" then
            external.Vehicles = type(external.Vehicles) == "table"
                and external.Vehicles or {}
            external.Vehicles[alias] = { x = rec.x, y = rec.y, z = rec.z }
        end
    end

    local nowMs = getTimestampMs and getTimestampMs() or 0
    local material = nil
    if not materialNext[vehicle] or nowMs >= materialNext[vehicle] then
        materialNext[vehicle] = nowMs + 2000
        material = materialSnapshot(vehicle)
    end
    if material then
        local signature = tostring(material.itemCount) .. ":"
            .. string.format("%.3f", material.weight)
        if signature ~= rec.materialSignature then
            rec.materialRevision = (tonumber(rec.materialRevision) or 0) + 1
            rec.materialSignature, rec.material = signature, material
            rec.materialObservedAtHours = at
        end
    end

    local present = {}
    pcall(function()
        for seat = 0, vehicle:getMaxPassengers() - 1 do
            local body = vehicle:getCharacter(seat)
            local personId = body and personIdOf(body) or nil
            if personId then
                present[personId] = true
                local prior = rec.occupants[personId] and rec.occupants[personId].state
                transition(rec, personId, prior, "seated", "native-seat", at)
                rec.occupants[personId] = { state = "seated", seat = seat,
                    observedAtHours = at }
                rec.members[personId] = { firstObservedAtHours =
                    rec.members[personId] and rec.members[personId].firstObservedAtHours or at,
                    lastObservedAtHours = at }
            end
        end
    end)
    for personId, occupant in pairs(rec.occupants) do
        if occupant.state == "seated" and not present[personId] then
            transition(rec, personId, "seated", "outside", "seat-released", at)
            rec.occupants[personId] = nil
        else
            local person = SAO.Identity and SAO.Identity.get(personId)
            if person then
                person.mobileHouseholdAnchor = { x = rec.x, y = rec.y,
                    z = rec.z, observedAtHours = at }
                person.x, person.y, person.z = rec.x, rec.y, rec.z
            end
        end
    end
    return rec
end

local function externalInterior(body)
    local ok, playerId = pcall(function()
        return body:getModData().projectRV_playerId
    end)
    if not ok or playerId == nil then return nil end
    local okStore, external = pcall(function()
        return ModData.get("modPROJECTRVInterior")
    end)
    local row = okStore and type(external) == "table"
        and type(external.Players) == "table"
        and external.Players[tostring(playerId)] or nil
    if type(row) ~= "table" or row.VehicleId == nil or row.ActualRoom == nil then
        return nil
    end
    return tostring(row.VehicleId), row
end

local function rvDefinitions()
    local ok, provider = pcall(require, "RVVehicleTypes")
    if not ok or type(provider) ~= "table"
        or type(provider.VehicleTypes) ~= "table" then return nil end
    return provider.VehicleTypes
end

local function interiorType(vehicle, definitions)
    local name = scriptName(vehicle)
    if not name then return nil end
    for key, definition in pairs(definitions or {}) do
        for _, candidate in ipairs(type(definition) == "table"
            and definition.scripts or {}) do
            if candidate == name then return key, definition end
        end
    end
    return nil
end

local function assignedRoom(vehicleIdValue, typeKey, definition)
    local external = ModData.getOrCreate("modPROJECTRVInterior")
    local assignedKey = typeKey == "normal" and "AssignedRooms"
        or ("AssignedRooms" .. tostring(typeKey))
    external[assignedKey] = type(external[assignedKey]) == "table"
        and external[assignedKey] or {}
    local room = external[assignedKey][vehicleIdValue]
    if room then return external, room end
    local occupied = {}
    for _, existing in pairs(external[assignedKey]) do
        if type(existing) == "table" then
            occupied[tostring(existing.x) .. ":" .. tostring(existing.y)
                .. ":" .. tostring(existing.z or 0)] = true
        end
    end
    for _, candidate in ipairs(definition.rooms or {}) do
        local key = tostring(candidate.x) .. ":" .. tostring(candidate.y)
            .. ":" .. tostring(candidate.z or 0)
        if not occupied[key] then
            room = { x = candidate.x, y = candidate.y, z = candidate.z or 0 }
            external[assignedKey][vehicleIdValue] = room
            return external, room
        end
    end
    return external, nil
end

local function placeBody(body, x, y, z)
    body:setX(x); body:setY(y); body:setZ(z)
    pcall(function() body:setLastX(x) end)
    pcall(function() body:setLastY(y) end)
    pcall(function() body:setLastZ(z) end)
    pcall(function() body:ensureOnTile() end)
end

function M.enterInterior(personId, body, vehicle, reason)
    if not body or not vehicle then return false, "missing-body-or-vehicle" end
    local rec = M.observeVehicle(vehicle, "interior-entry")
    if not rec then return false, "not-a-mobile-place" end
    local definitions = rvDefinitions()
    local typeKey, definition = interiorType(vehicle, definitions)
    if not typeKey then return false, "physical-interior-unavailable" end
    local dx, dy = vehicle:getX() - body:getX(), vehicle:getY() - body:getY()
    if dx * dx + dy * dy > INTERIOR_ENTRY_REACH * INTERIOR_ENTRY_REACH then
        return false, "entry-out-of-reach"
    end
    local externalId = vehicleAlias(vehicle)
    if not externalId then
        externalId = "sao-" .. tostring(rec.id)
        vehicle:getModData().projectRV_uniqueId = externalId
        rec.externalInteriorId = externalId
        local s = store(); if s then s.aliases[externalId] = rec.id end
    end
    local external, room = assignedRoom(externalId, typeKey, definition)
    if not room then return false, "no-interior-room" end
    local seat = -1
    pcall(function() seat = vehicle:getSeat(body) end)
    if body:getVehicle() then
        local ok, left = pcall(function()
            return SAOJavaBridge and SAOJavaBridge:unseatFromVehicle(body)
        end)
        if not ok or not left then return false, "native-exit-refused" end
    end
    local playerId = "sao-mobile:" .. tostring(personId)
    local offset = definition.offset or { x = 1, y = 1 }
    external.Players = type(external.Players) == "table" and external.Players or {}
    external.Vehicles = type(external.Vehicles) == "table" and external.Vehicles or {}
    external.Players[playerId] = { ActualRoom = room, VehicleId = externalId,
        Seat = seat, RoomType = typeKey, SAOOwner = true }
    external.Vehicles[externalId] = { x = rec.x, y = rec.y, z = rec.z }
    body:getModData().projectRV_playerId = playerId
    placeBody(body, room.x + (offset.x or 1), room.y + (offset.y or 1), room.z)
    local person = SAO.Identity and SAO.Identity.get(personId)
    if person then
        person.mobileHouseholdUse = { reason = reason or "interior-use",
            state = "interior", vehicleId = rec.id, roomType = typeKey,
            enteredAtHours = nowHours(), lastRestAtHours = nowHours() }
        person.mobileHouseholdInterior = {
            room = { x = room.x, y = room.y, z = room.z or 0 },
            body = { x = room.x + (offset.x or 1),
                y = room.y + (offset.y or 1), z = room.z or 0 },
            externalId = externalId, playerId = playerId,
            roomType = typeKey, seat = seat,
        }
    end
    M.syncPerson(personId, body)
    return true, "entered-interior"
end

local function loadedVehicle(id)
    local ok, vehicles = pcall(function() return getCell():getVehicles() end)
    if not ok or not vehicles then return nil end
    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        local vehicle = iterator:next()
        if vehicleId(vehicle, false) == id then return vehicle end
    end
    return nil
end

function M.exitInterior(personId, body, reason)
    local alias, row = externalInterior(body)
    if not alias or not row then return false, "not-in-interior" end
    local s = store()
    local rec = s and s.aliases[alias] and s.vehicles[s.aliases[alias]] or nil
    if not rec or not finite(rec.x) or not finite(rec.y) then
        return false, "exterior-anchor-unavailable"
    end
    local external = ModData.getOrCreate("modPROJECTRVInterior")
    local playerId = body:getModData().projectRV_playerId
    if external.Players then external.Players[tostring(playerId)] = nil end
    body:getModData().projectRV_playerId = nil
    local vehicle = loadedVehicle(rec.id)
    local physicallyExited = false
    if vehicle then
        placeBody(body, rec.x, rec.y, rec.z or 0)
        local seat = tonumber(row.Seat) or -1
        local okSeat, entered = pcall(function()
            return seat >= 0 and vehicle:isSeatInstalled(seat)
                and not vehicle:isSeatOccupied(seat) and vehicle:enter(seat, body)
        end)
        if okSeat and entered then
            local positioned = pcall(function()
                vehicle:setCharacterPosition(body, seat, "inside")
                vehicle:playPassengerAnim(seat, "idle")
            end)
            if positioned then
                local okOut, left = pcall(function()
                    return SAOJavaBridge:unseatFromVehicle(body)
                end)
                physicallyExited = okOut and left == true
            else
                pcall(function() vehicle:exit(body) end)
            end
        end
    end
    if not physicallyExited then
        -- Towable interiors can have no passenger mesh. Keep the person next
        -- to the exterior anchor rather than inside the vehicle's collision.
        placeBody(body, rec.x + 2, rec.y, rec.z or 0)
    end
    local person = SAO.Identity and SAO.Identity.get(personId)
    if person then
        person.mobileHouseholdUse = nil
        person.mobileHouseholdInterior = nil
        person.x, person.y, person.z = rec.x, rec.y, rec.z or 0
    end
    transition(rec, personId, "interior", "outside",
        reason or "completed-interior-exit", nowHours())
    if rec.occupants then rec.occupants[personId] = nil end
    M.syncPerson(personId, body)
    return true, "exited-interior"
end

function M.isInterior(personId, body)
    local alias = externalInterior(body)
    if not alias then return false end
    local person = SAO.Identity and SAO.Identity.get(personId)
    return person ~= nil and person.mobileHouseholdId ~= nil
end

function M.representationPosition(personId, body)
    local person = SAO.Identity and SAO.Identity.get(personId)
    if not person then return nil end
    if person.mobileHouseholdState == "interior" then
        if body then
            local ok, x, y, z = pcall(function()
                return body:getX(), body:getY(), body:getZ()
            end)
            if ok and finite(x) and finite(y) and finite(z) then
                return { x = x, y = y, z = z, physicalInterior = true }
            end
        end
        local interior = person.mobileHouseholdInterior
        local point = type(interior) == "table" and interior.body or nil
        if type(point) == "table" and finite(point.x) and finite(point.y)
            and finite(point.z) then
            return { x = point.x, y = point.y, z = point.z,
                physicalInterior = true }
        end
    end
    if finite(person.x) and finite(person.y) and finite(person.z) then
        return { x = person.x, y = person.y, z = person.z }
    end
    return nil
end

function M.restoreInterior(personId, body)
    local person = SAO.Identity and SAO.Identity.get(personId)
    local interior = person and person.mobileHouseholdInterior or nil
    local room = type(interior) == "table" and interior.room or nil
    local point = type(interior) == "table" and interior.body or nil
    local s = store()
    local rec = s and person and person.mobileHouseholdId
        and s.vehicles[person.mobileHouseholdId] or nil
    if not body or not rec or person.mobileHouseholdState ~= "interior"
        or type(room) ~= "table" or type(point) ~= "table"
        or not finite(room.x) or not finite(room.y) or not finite(room.z)
        or not finite(point.x) or not finite(point.y) or not finite(point.z) then
        return false
    end
    local externalId = tostring(interior.externalId or rec.externalInteriorId or "")
    local playerId = tostring(interior.playerId or ("sao-mobile:" .. personId))
    if externalId == "" then return false end
    local external = ModData.getOrCreate("modPROJECTRVInterior")
    external.Players = type(external.Players) == "table" and external.Players or {}
    external.Vehicles = type(external.Vehicles) == "table" and external.Vehicles or {}
    external.Players[playerId] = { ActualRoom = { x = room.x, y = room.y, z = room.z },
        VehicleId = externalId, Seat = tonumber(interior.seat) or -1,
        RoomType = tostring(interior.roomType or "unknown"), SAOOwner = true }
    external.Vehicles[externalId] = { x = rec.x, y = rec.y, z = rec.z }
    body:getModData().projectRV_playerId = playerId
    placeBody(body, point.x, point.y, point.z)
    rec.occupants[personId] = { state = "interior",
        roomType = tostring(interior.roomType or "unknown"),
        observedAtHours = nowHours() }
    rec.members[personId] = rec.members[personId]
        or { firstObservedAtHours = nowHours() }
    rec.members[personId].lastObservedAtHours = nowHours()
    s.aliases[externalId] = rec.id
    return M.syncPerson(personId, body) ~= nil
end

function M.syncPerson(personId, body)
    if type(personId) ~= "string" or not body then return nil end
    local at, current = nowHours(), nil
    local okVehicle, vehicle = pcall(function() return body:getVehicle() end)
    if okVehicle and vehicle then
        current = M.observeVehicle(vehicle, "native-occupancy")
    else
        local alias, interior = externalInterior(body)
        local s = alias and store() or nil
        local id = s and s.aliases[alias] or nil
        current = id and s.vehicles[id] or nil
        if current then
            local prior = current.occupants[personId]
                and current.occupants[personId].state or nil
            transition(current, personId, prior, "interior",
                "completed-interior-transition", at)
            current.occupants[personId] = { state = "interior",
                roomType = tostring(interior.RoomType or "unknown"),
                observedAtHours = at }
            current.members[personId] = current.members[personId]
                or { firstObservedAtHours = at }
            current.members[personId].lastObservedAtHours = at
        end
    end
    local person = SAO.Identity and SAO.Identity.get and SAO.Identity.get(personId)
    local priorId = person and person.mobileHouseholdId or nil
    if priorId and (not current or current.id ~= priorId) then
        local s, prior = store(), nil
        if s then prior = s.vehicles[priorId] end
        if prior and prior.occupants[personId] then
            transition(prior, personId, prior.occupants[personId].state,
                "outside", "physical-separation", at)
            prior.occupants[personId] = nil
        end
    end
    if person then
        person.mobileHouseholdId = current and current.id or nil
        person.mobileHouseholdState = current and current.occupants[personId]
            and current.occupants[personId].state or nil
        if current then
            person.mobileHouseholdAnchor = { x = current.x, y = current.y,
                z = current.z, observedAtHours = at }
            person.x, person.y, person.z = current.x, current.y, current.z
            if SAO.ProceduralPlanning and SAO.ProceduralPlanning.rememberSpatial then
                SAO.ProceduralPlanning.rememberSpatial(personId, {
                    key = current.id, kind = "mobile-household",
                    x = current.x, y = current.y, z = current.z,
                    source = "occupied", confidence = 1, familiarity = 0.8,
                    routeKnown = true, owned = current.members[personId] ~= nil,
                    usable = true, tags = { "vehicle", current.kind, "shelter",
                        "storage", "moving-place" },
                })
                local purpose = SAO.ProceduralPlanning.planMobileHousehold
                    and SAO.ProceduralPlanning.planMobileHousehold(personId, {
                        vehicleId = current.id, vehicleKind = current.kind,
                        known = true, loaded = true, accessible = true,
                        occupied = true, materialKnown = current.material ~= nil,
                        materialRevision = current.materialRevision,
                        occupantCount = (function()
                            local count = 0
                            for _ in pairs(current.occupants or {}) do count = count + 1 end
                            return count
                        end)(),
                    }) or nil
                if purpose then
                    SAO.ProceduralPlanning.recordResult(personId, purpose.id, {
                        owner = "MobileHousehold", token = "mobile:reconciled",
                        status = "completed", atHours = at,
                    })
                end
            end
        end
    end
    return current
end

function M.recordFailure(personId, vehicle, reason)
    local rec = M.observeVehicle(vehicle, "attempted-use")
    if not rec then return false end
    rec.failures = rec.failures or {}
    appendBounded(rec.failures, { atHours = nowHours(), personId = personId,
        reason = tostring(reason or "unknown") }, MAX_FAILURES)
    return true
end

function M.forgetPerson(personId, reason)
    local s, at = store(), nowHours()
    if not s then return false end
    for _, rec in pairs(s.vehicles) do
        local occupant = rec.occupants and rec.occupants[personId] or nil
        if occupant then
            transition(rec, personId, occupant.state, "outside",
                reason or "person-unavailable", at)
            rec.occupants[personId] = nil
        end
    end
    return true
end

function M.snapshot(personId)
    local person = SAO.Identity and SAO.Identity.get and SAO.Identity.get(personId)
    local s, id = store(), person and person.mobileHouseholdId or nil
    local rec = s and id and s.vehicles[id] or nil
    if not rec then return nil end
    local occupants = 0
    for _ in pairs(rec.occupants or {}) do occupants = occupants + 1 end
    return { id = rec.id, script = rec.script, kind = rec.kind,
        state = person.mobileHouseholdState, x = rec.x, y = rec.y, z = rec.z,
        motion = rec.motion, speedKmh = rec.speedKmh,
        towing = rec.towing, towedBy = rec.towedBy, occupants = occupants,
        materialRevision = rec.materialRevision,
        lastObservedAtHours = rec.lastObservedAtHours,
        materialObservedAtHours = rec.materialObservedAtHours,
        itemCount = rec.material and rec.material.itemCount or 0,
        materialWeight = rec.material and rec.material.weight or 0,
        transitions = #(rec.transitions or {}), failures = #(rec.failures or {}) }
end

function M.all()
    local s = store()
    return s and s.vehicles or {}
end

local function nearbyVehicle(personId, body, radius)
    local cell = body and body:getCell() or nil
    if not cell then return nil end
    local best, bestDistance = nil, radius * radius
    local iterator = cell:getVehicles():iterator()
    while iterator:hasNext() do
        local vehicle = iterator:next()
        local kind = vehicle and M.classifyScript(scriptName(vehicle)) or nil
        if kind == "motorhome" or kind == "camper" then
            local dx, dy = vehicle:getX() - body:getX(), vehicle:getY() - body:getY()
            local distance = dx * dx + dy * dy
            if distance <= bestDistance then
                local allowed = SAO.Standing and SAO.Standing.insideClaim
                    and SAO.Standing.insideClaim(personId,
                        vehicle:getX(), vehicle:getY())
                if allowed then best, bestDistance = vehicle, distance end
            end
        end
    end
    return best
end

function M.seekNightShelter(personId, body, radius)
    if not SAOJavaBridge or not body then return false end
    local vehicle = nearbyVehicle(personId, body,
        math.min(4, tonumber(radius) or 4))
    if not vehicle then return false end
    local rec = M.observeVehicle(vehicle, "shelter-appraisal")
    if not rec then return false end
    local purpose = SAO.ProceduralPlanning and SAO.ProceduralPlanning.planMobileHousehold
        and SAO.ProceduralPlanning.planMobileHousehold(personId, {
            vehicleId = rec.id, vehicleKind = rec.kind, known = true,
            loaded = true, accessible = true, occupied = false,
            materialKnown = rec.material ~= nil,
            materialRevision = rec.materialRevision,
            objective = "sleep inside a known mobile shelter on held ground",
            pressure = 0.8,
        }) or nil
    if purpose then
        SAO.ProceduralPlanning.recordResult(personId, purpose.id, {
            owner = "MobileHousehold", token = "mobile:identified",
            status = "completed" })
    end
    local ok, seat = pcall(function()
        return SAOJavaBridge:seatInNearestVehicle(body,
            vehicle:getX(), vehicle:getY())
    end)
    if not ok or tonumber(seat) == nil or seat < 0 or body:getVehicle() ~= vehicle then
        if body:getVehicle() and body:getVehicle() ~= vehicle then
            pcall(function() SAOJavaBridge:unseatFromVehicle(body) end)
        end
        M.recordFailure(personId, vehicle, "native-entry-refused")
        return false
    end
    local person = SAO.Identity and SAO.Identity.get(personId)
    if person then
        person.mobileHouseholdUse = { reason = "night-rest",
            vehicleId = rec.id, enteredAtHours = nowHours(),
            lastRestAtHours = nowHours() }
    end
    local enteredInterior = M.enterInterior(personId, body, vehicle, "night-rest")
    if enteredInterior then return true end
    M.syncPerson(personId, body)
    return true
end

function M.tickOccupiedRest(personId, body, agent)
    local person = SAO.Identity and SAO.Identity.get(personId)
    local use = person and person.mobileHouseholdUse or nil
    if type(use) ~= "table" or use.reason ~= "night-rest" then return false end
    local interior = M.isInterior(personId, body)
    local okHour, hour = pcall(function()
        return GameTime.getInstance():getTimeOfDay()
    end)
    if interior then
        if not okHour then return true end
        if hour >= 6.0 and hour < 22.0 then
            pcall(function() SAOJavaBridge:setShellAsleep(body, false) end)
            local left = M.exitInterior(personId, body, "morning-departure")
            if left and agent then
                agent.riding, agent.sleeping, agent.lastRestHours = nil, nil, nil
            end
            return not left
        end
        local mobile = M.snapshot(personId)
        if mobile and mobile.motion == "moving" then return true end
        local needs = SAO.Needs and SAO.Needs.read and SAO.Needs.read(body) or nil
        if needs and tonumber(needs.fatigue) and needs.fatigue > 0.000001 then
            pcall(function() SAOJavaBridge:setShellAsleep(body, true) end)
            if agent then agent.sleeping = true end
            local at = nowHours()
            local delta = math.max(0, at - (use.lastRestAtHours or at))
            use.lastRestAtHours = at
            if delta > 0 then
                pcall(function() SAOJavaBridge:restRecoverTick(body, delta) end)
            end
        end
        M.syncPerson(personId, body)
        return true
    end
    local okVehicle, vehicle = pcall(function() return body:getVehicle() end)
    if not okVehicle or not vehicle then
        person.mobileHouseholdUse = nil
        return false
    end
    if not okHour then return true end
    local night = hour >= 22.0 or hour < 6.0
    local okSpeed, speed = pcall(function()
        return math.abs(vehicle:getCurrentSpeedKmHour())
    end)
    if not night then
        pcall(function() SAOJavaBridge:setShellAsleep(body, false) end)
        local okOut, left = pcall(function()
            return SAOJavaBridge:unseatFromVehicle(body)
        end)
        if okOut and left then
            person.mobileHouseholdUse = nil
            if agent then
                agent.riding, agent.sleeping, agent.lastRestHours = nil, nil, nil
            end
            M.syncPerson(personId, body)
            return false
        end
        return true
    end
    if not okSpeed or speed > 0.5 then return true end
    local needs = SAO.Needs and SAO.Needs.read and SAO.Needs.read(body) or nil
    if needs and tonumber(needs.fatigue) and needs.fatigue > 0.000001 then
        pcall(function() SAOJavaBridge:setShellAsleep(body, true) end)
        if agent then agent.sleeping = true end
        local at = nowHours()
        local delta = math.max(0, at - (use.lastRestAtHours or at))
        use.lastRestAtHours = at
        if delta > 0 then
            pcall(function() SAOJavaBridge:restRecoverTick(body, delta) end)
        end
    else
        pcall(function() SAOJavaBridge:setShellAsleep(body, false) end)
        if agent then agent.sleeping = nil end
    end
    M.syncPerson(personId, body)
    return true
end

local function sample()
    local tick = getTimestampMs and getTimestampMs() or 0
    if tick < nextScan then return end
    nextScan = tick + SCAN_INTERVAL * 50
    if not (SAO.Body and SAO.Body.active) then return end
    pcall(function()
        local vehicles = getCell():getVehicles()
        local iterator = vehicles:iterator()
        while iterator:hasNext() do
            local vehicle = iterator:next()
            if vehicle and M.classifyScript(scriptName(vehicle)) then
                M.observeVehicle(vehicle, "native-world-refresh")
            end
        end
    end)
    for id, body in pairs(SAO.Body.active) do
        local ok, err = pcall(M.syncPerson, id, body)
        if not ok and SAO.Log and SAO.Log.line then
            SAO.Log.line("MOBILE", tostring(id) .. " sync fault: " .. tostring(err))
        end
    end
end

if Events and Events.OnTick then Events.OnTick.Add(sample) end
return M
