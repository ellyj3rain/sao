-- The builder supplies Config as a data-only local before this source.
-- Native lifecycle: OnPreMapLoad precedes WorldGenParams.load/CreateStep1;
-- OnInitWorld is already too late to define the meta-grid's bounds.
local Study = { active = false, error = nil }
local state = nil
local lastHours = nil
local newGame = false
local session = nil
local exportOwner, exportKey = nil, nil
local pendingLive, pendingArchive = nil, nil
local exportStopping = false
local originalRoads = nil
local arrayMeta = { studyArray = true }
local function array() return setmetatable({}, arrayMeta) end
local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
local function keys(t)
    local result = {}
    for key in pairs(t or {}) do result[#result + 1] = key end
    -- Native Kahlua's recursive comparator quicksort can exhaust its call stack
    -- on large observation arrays. Iterative merging has bounded stack use.
    local width = 1
    while width < #result do
        local merged = {}
        for first = 1, #result, width * 2 do
            local left, right = first, first + width
            local leftEnd, rightEnd = math.min(first + width - 1, #result), math.min(first + width * 2 - 1, #result)
            while left <= leftEnd or right <= rightEnd do
                if right > rightEnd or (left <= leftEnd and tostring(result[left]) <= tostring(result[right])) then
                    merged[#merged + 1] = result[left]
                    left = left + 1
                else
                    merged[#merged + 1] = result[right]
                    right = right + 1
                end
            end
        end
        result = merged
        width = width * 2
    end
    return result
end
local function charge(budget, bytes)
    if budget.bounded and bytes > budget.left then
        budget.exhausted = true
        return false
    end
    assert(bytes <= budget.left, "observation exceeds export byte budget")
    budget.left = budget.left - bytes
    return true
end
-- Kahlua stores Java UTF-16 strings; #s is not the UTF-8 byte count written by
-- the native file writer. Paired surrogates become one four-byte code point.
local function utf8Bytes(s)
    if not s:find('[^%z\1-\127]') then return #s end
    local bytes, i = 0, 1
    while i <= #s do
        local c = string.byte(s, i)
        if c < 128 then bytes = bytes + 1
        elseif c < 2048 then bytes = bytes + 2
        elseif c >= 55296 and c <= 56319 and i < #s
                and string.byte(s, i + 1) >= 56320 and string.byte(s, i + 1) <= 57343 then
            bytes, i = bytes + 4, i + 1
        else bytes = bytes + 3 end
        i = i + 1
    end
    return bytes
end
local function quotedBytes(s)
    s = tostring(s)
    local length = utf8Bytes(s) + 2
    -- Most observation strings need no JSON escaping. Keep native UTF-8
    -- accounting while avoiding three allocating substitution scans for them.
    if not s:find('[%z\1-\31\\"]') then return length, true end
    local _, simple = s:gsub('[\\"]', '')
    local _, controls = s:gsub('[%z\1-\31]', '')
    length = length + simple + controls * 5
    return length, false
end
local escapes = { ['"'] = '\\"', ['\\'] = '\\\\' }
for i = 0, 31 do escapes[string.char(i)] = string.format('\\u%04x', i) end
local function quote(s, budget)
    s = tostring(s)
    local length, plain = quotedBytes(s)
    if not charge(budget, length) then return nil end
    return '"' .. (plain and s or s:gsub('[%z\1-\31\\"]', escapes)) .. '"'
end
local function json(value, seen, budget)
    budget = budget or { left = 64 * 1024 * 1024 }
    local kind = type(value)
    if kind == "nil" then return charge(budget, 4) and "null" or nil end
    if kind == "boolean" then return charge(budget, value and 4 or 5) and (value and "true" or "false") or nil end
    if kind == "number" then
        assert(finite(value), "non-finite observation")
        local encoded = tostring(value)
        if not charge(budget, #encoded) then return nil end
        return encoded
    end
    if kind == "string" then return quote(value, budget) end
    assert(kind == "table", "unsupported observation value")
    seen = seen or {}
    assert(not seen[value], "cyclic observation")
    seen[value] = true
    if not charge(budget, 2) then seen[value] = nil; return nil end
    local parts = {}
    local isArray = getmetatable(value) == arrayMeta
    if not isArray then
        local length, members = #value, 0
        isArray = length > 0
        for key in pairs(value) do
            members = members + 1
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then isArray = false end
        end
        if members ~= length then isArray = false end
    end
    if isArray then
        for i = 1, #value do
            if i > 1 and not charge(budget, 1) then seen[value] = nil; return nil end
            local part = json(value[i], seen, budget)
            if part == nil then seen[value] = nil; return nil end
            parts[#parts + 1] = part
        end
    else
        for _, key in ipairs(keys(value)) do
            if not charge(budget, #parts > 0 and 2 or 1) then seen[value] = nil; return nil end
            local name = quote(key, budget)
            if name == nil then seen[value] = nil; return nil end
            local part = json(value[key], seen, budget)
            if part == nil then seen[value] = nil; return nil end
            parts[#parts + 1] = name .. ":" .. part
        end
    end
    seen[value] = nil
    return (isArray and "[" or "{") .. table.concat(parts, ",")
        .. (isArray and "]" or "}")
end
local function boundedJson(value, budget)
    -- Expected capacity exhaustion is a result. Native Kahlua requests its
    -- debugger even when an assertion is later caught by Lua pcall.
    budget.bounded, budget.exhausted = true, false
    local encoded = json(value, nil, budget)
    return not budget.exhausted, encoded
end
local function jsonFits(value, budget)
    if budget.left < 0 then return false end
    if SAO_StudyExport then
        local bytes = SAO_StudyExport:measure(value, arrayMeta, budget.left)
        if bytes < 0 then return false end
        budget.left = budget.left - bytes
        return true
    end
    return boundedJson(value, budget)
end
local function selected()
    return getWorld() and getWorld():getMap() == Config.mapName
end
local function stop(reason)
    Study.active, Study.error = false, tostring(reason)
    print("[StudyWorld] stopped: " .. Study.error)
end
local function boundsMatch()
    local e, grid = Config.extent, getWorld():getMetaGrid()
    return grid and grid:getMinX() == e.minCellX and grid:getMinY() == e.minCellY
        and grid:getMaxX() == e.minCellX + e.cellsX - 1
        and grid:getMaxY() == e.minCellY + e.cellsY - 1
        and WorldGenParams.INSTANCE:getSeedString() == Config.seed
end
function Study.prepare()
    Study.active, Study.error, state, lastHours, newGame = false, nil, nil, nil, false
    Study.archiveCapture = nil
    exportOwner, exportKey, pendingLive, pendingArchive, exportStopping = nil, nil, nil, nil, false
    Study.prepared, Study.configured = false, false
    if originalRoads and worldgen then worldgen.roads, originalRoads = originalRoads, nil end
    if not selected() then return false end
    assert(not isClient() and not isServer(), "study worlds currently require single-player")
    local e, params = Config.extent, WorldGenParams.INSTANCE
    params:setSeedString(Config.seed)
    params:setMinXCell(e.minCellX)
    params:setMinYCell(e.minCellY)
    params:setMaxXCell(e.minCellX + e.cellsX - 1)
    params:setMaxYCell(e.minCellY + e.cellsY - 1)
    assert(worldgen and worldgen.roads, "native generation definitions unavailable")
    local roads = {}
    for name, parameters in pairs(Config.generation.roads) do
        assert(worldgen.roads[name], "unknown native road type: " .. name)
        local road = {}
        for key, value in pairs(worldgen.roads[name]) do road[key] = value end
        road.p, road.filter_edge = parameters.p, parameters.filter_edge
        roads[name] = road
    end
    originalRoads, worldgen.roads = worldgen.roads, roads
    Study.prepared = true
    return true
end
function Study.options()
    if not selected() then return false end
    assert(not isClient() and not isServer(), "study worlds currently require single-player")
    local options = getSandboxOptions()
    for key, value in pairs(Config.sandbox) do
        local option = options:getOptionByName(key)
        assert(option, "unknown sandbox option: " .. key)
        local candidate = option:asConfigOption():makeCopy()
        assert(candidate:isValidString(tostring(value)), "invalid sandbox option: " .. key)
        candidate:setValueFromObject(value)
        assert(candidate:getValueAsObject() == value, "sandbox option type differs: " .. key)
    end
    for key, value in pairs(Config.sandbox) do options:set(key, value) end
    options:toLua()
    Study.configured = true
    -- SandboxOptions.load follows this event. New worlds consume SandboxVars;
    -- reopened worlds restore their saved options, which start() verifies.
    return true
end
local function settingsMatch()
    local options = getSandboxOptions()
    for key, value in pairs(Config.sandbox) do
        local option = options:getOptionByName(key)
        assert(option and option:asConfigOption():getValueAsObject() == value,
            "sandbox option differs: " .. key)
    end
end
local function beginExport()
    if exportOwner or not SAO_StudyExport or not state or not session then return end
    exportOwner = SAO_StudyExport
    exportKey = Config.definitionSha256 .. "/" .. getWorld():getWorld() .. "/" .. session
    exportOwner:begin(Config.definitionSha256, getWorld():getWorld(), session,
        Config.observerSha256, Config.engineJarSha256)
end
function Study.start()
    if not selected() then return false end
    assert(Study.prepared and Study.configured and not Study.error,
        "study initialization did not complete")
    assert(not isClient() and not isServer(), "study worlds currently require single-player")
    assert(boundsMatch(), "loaded native world bounds or seed differ from definition")
    state = ModData.getOrCreate("StudyWorld")
    assert(not state.definitionSha256 or state.definitionSha256 == Config.definitionSha256,
        "save belongs to a different study definition")
    assert(state.definitionSha256 or newGame, "existing save has no study provenance")
    assert(SAO and SAO.Identity and SAO.Body, "production people owners unavailable")
    settingsMatch()
    state.definitionSha256 = Config.definitionSha256
    state.sequence = tonumber(state.sequence) or 0
    session = tostring(getTimestampMs())
    beginExport()
    -- A saved study resumes its model budget; first launch enables equal participation.
    if SAO.Cognition and SAO.Cognition.settings and SAO.Cognition.configure then
        local settings = SAO.Cognition.settings()
        if not settings.enabled then assert(SAO.Cognition.configure(0.5, 12, 3), "cognition configuration refused") end
    end
    Study.active = true
    print("[StudyWorld] observation active save=" .. getWorld():getWorld())
    return true
end
local NEED_STATS = { hunger = "HUNGER", thirst = "THIRST", fatigue = "FATIGUE" }
local function applyInitialNeeds()
    local needs = Config.situation and Config.situation.initialNeeds
    local regional = Config.situation and Config.situation.initialNeedsBySite
    if not needs and not regional then return end
    assert(SAO.Hash and SAO.Hash.unit, "study situation requires deterministic hash owner")
    assert(CharacterStat, "native character statistics unavailable")
    state.initialNeedsApplied = state.initialNeedsApplied or {}
    for _, id in ipairs(keys(SAO.Identity.all())) do
        local rec = SAO.Identity.all()[id]
        if not rec.dead and not state.initialNeedsApplied[id] then
            local body = SAO.Body.get(id)
            if body then
                local actorNeeds, siteId = needs, nil
                if regional then
                    local distance = math.huge
                    for _, site in ipairs(Config.observation.sites or {}) do
                        local dx, dy = body:getX() - site.x, body:getY() - site.y
                        local candidate = dx * dx + dy * dy
                        if candidate < distance then distance, siteId = candidate, site.id end
                    end
                    actorNeeds = regional[siteId] or needs
                end
                local stats = assert(body:getStats(), "native character statistics unavailable")
                local applied = { appliedAtHours = getGameTime():getWorldAgeHours(), siteId = siteId }
                for _, name in ipairs(keys(actorNeeds or {})) do
                    local bounds = actorNeeds[name]
                    local unit = SAO.Hash.unit(id, "study:" .. Config.definitionSha256 .. ":" .. name)
                    local value = bounds.min + (bounds.max - bounds.min) * unit
                    stats:set(CharacterStat[NEED_STATS[name]], value)
                    applied[name] = value
                end
                state.initialNeedsApplied[id] = applied
                state.situationReceipt = state.situationReceipt or {}
                state.situationReceipt.initialNeedsApplied = state.initialNeedsApplied
            end
        end
    end
end
local function applyResourceObjectives()
    local objectives = Config.situation and Config.situation.resourceObjectives
    if not objectives then return end
    local planning = assert(SAO.ProceduralPlanning, "resource objective owner unavailable")
    state.situationReceipt = state.situationReceipt or {}
    state.resourceObjectives = state.resourceObjectives or {}
    state.situationReceipt.resourceObjectives = state.resourceObjectives
    local records = SAO.Identity.all()
    for _, spec in ipairs(objectives) do
        local receipt = state.resourceObjectives[spec.id]
        if not receipt then
            receipt = { id = spec.id, revision = spec.revision, siteId = spec.siteId,
                actorOrdinal = spec.actorOrdinal, sourceDefinition = Config.definitionSha256,
                authority = "OperatorDirect", issuer = "experimental-study:" .. Config.definitionSha256,
                treatment = "assigned-outcome-discovery", scope = "actor-owned-carried",
                category = spec.category, target = spec.target, unit = spec.unit,
                status = "waiting-for-native-regional-actor", datasetAdmission = "unreviewed" }
            state.resourceObjectives[spec.id] = receipt
        end
        -- Bind one actual represented living person near the declared site.
        -- Once bound, absence, death or a replacement body cannot select a
        -- different identity. Observation anchors are never candidate actors.
        if not receipt.actorId then
            local candidates = {}
            for _, id in ipairs(keys(records)) do
                local rec, body = records[id], SAO.Body.get(id)
                if not rec.dead and body then
                    local nearest, best = nil, 48 * 48
                    for _, site in ipairs(Config.observation.sites or {}) do
                        if body:getZ() == site.z then
                            local dx, dy = body:getX() - site.x, body:getY() - site.y
                            local distance = dx * dx + dy * dy
                            if distance < best then nearest, best = site.id, distance end
                        end
                    end
                    if nearest == spec.siteId then candidates[#candidates + 1] = id end
                end
            end
            receipt.actorId = candidates[spec.actorOrdinal]
            if receipt.actorId then receipt.boundAtWorldAgeHours = getGameTime():getWorldAgeHours() end
        end
        if receipt.actorId then
            local rec = records[receipt.actorId]
            if rec and rec.dead then
                planning.resourceOutcomeDemand(receipt.actorId)
                receipt.status, receipt.reason = "abandoned", "actor-dead"
            elseif not rec then
                receipt.status, receipt.reason = "actor-unavailable", "bound-identity-missing"
            elseif not receipt.purposeId then
                local purpose, reason = planning.admitResourceOutcome(receipt.actorId, {
                    id = spec.id, revision = spec.revision, category = spec.category,
                    target = spec.target, unit = spec.unit, deadlineAfterHours = spec.deadlineAfterHours,
                    issuer = receipt.issuer, sourceDefinition = Config.definitionSha256 })
                receipt.reason = reason
                if purpose then
                    receipt.purposeId, receipt.status = purpose.id, purpose.status
                    receipt.admittedAtCountyHours = purpose.resourceOutcome.admittedAt
                    receipt.deadlineAtCountyHours = purpose.resourceOutcome.deadlineAt
                else receipt.status = "admission-refused" end
            else
                planning.resourceOutcomeDemand(receipt.actorId)
                local purpose = rec.proceduralPlanning and rec.proceduralPlanning.purposes[receipt.purposeId]
                if not purpose then
                    local requests = rec.proceduralPlanning and rec.proceduralPlanning.resourceOutcomeRequests
                    local request = requests and requests[spec.id]
                    local retired = request and request.retired
                    if retired and retired.purposeId == receipt.purposeId
                        and request.purposeId == receipt.purposeId
                        and request.request.revision == spec.revision
                        and request.request.sourceDefinition == Config.definitionSha256
                        and (retired.status == "completed" or retired.status == "abandoned") then
                        purpose = retired
                    end
                end
                if purpose then
                    receipt.status, receipt.reason = purpose.status, purpose.resolution
                    receipt.resolvedAtCountyHours = purpose.resolvedAt
                    local progress = purpose.outcomeProgress
                    if progress then
                        receipt.held, receipt.stockObservedAtCountyHours = progress.held, progress.observedAtHours
                        receipt.stockCoverage = progress.coverage
                    end
                else receipt.status, receipt.reason = "unknown", "retained-purpose-missing" end
            end
        end
    end
end
local function existingHorse(id)
    if not id then return nil end
    if SAO and SAO.Animals and SAO.Animals.horseById then
        local horse = SAO.Animals.horseById(id)
        if horse then return horse end
    end
    local ok, animal = pcall(function() return getAnimal(tonumber(id)) end)
    return ok and animal or nil
end
local function applyHorseTravel()
    local spec = Config.situation and Config.situation.horseTravel
    if not spec then return end
    state.horseTravel = state.horseTravel or { phase = "spawn" }
    local receipt = state.horseTravel
    if receipt.phase == "arrived" or receipt.phase == "failed" then return end
    local horse = existingHorse(receipt.animalId)
    if not horse then
        if receipt.phase ~= "spawn" then
            receipt.missingTicks = (tonumber(receipt.missingTicks) or 0) + 1
            assert(receipt.missingTicks < 600, "study horse disappeared during travel")
            return
        end
        local definition = assert(AnimalDefinitions.getDef(spec.animalType),
            "study horse type unavailable")
        local breed = assert(definition:getBreedByName(spec.breed),
            "study horse breed unavailable")
        horse = assert(addAnimal(getCell(), spec.spawn.x, spec.spawn.y, spec.spawn.z,
            spec.animalType, breed, false), "native horse creation failed")
        horse:setAgeDebug(spec.ageDays)
        horse:addToWorld()
        receipt.animalId = horse:getAnimalID()
        receipt.phase = "rider"
        receipt.spawnedAtHours = getGameTime():getWorldAgeHours()
        print("[StudyWorld] horse=" .. tostring(receipt.animalId) .. " spawned")
        return
    end
    receipt.missingTicks = 0
    local riderId, body = receipt.riderId, receipt.riderId and SAO.Body.get(receipt.riderId) or nil
    if not body then
        for _, id in ipairs(keys(SAO.Identity.all())) do
            local rec, candidate = SAO.Identity.all()[id], SAO.Body.get(id)
            if not rec.dead and candidate then
                riderId, body = id, candidate
                rec.occupation = spec.riderOccupation
                receipt.riderId = id
                receipt.phase = "admit"
                break
            end
        end
    end
    if not body then return end
    if receipt.phase == "rider" or receipt.phase == "admit" then
        local dx, dy = horse:getX() - body:getX(), horse:getY() - body:getY()
        if dx * dx + dy * dy > 36 then
            body:setX(horse:getX() + 2)
            body:setY(horse:getY())
            body:setZ(horse:getZ())
        end
        local accepted = SAO.Animals and SAO.Animals.orderTravel and SAO.Animals.orderTravel(
            riderId, body, spec.destination.x, spec.destination.y, spec.destination.z,
            spec.running)
        if accepted then
            receipt.phase = "travelling"
            receipt.startedAtHours = getGameTime():getWorldAgeHours()
            print("[StudyWorld] horse travel rider=" .. tostring(riderId) .. " accepted")
        end
        return
    end
    if receipt.phase == "travelling" then
        local verdict = SAO.Animals.tickTravel(riderId)
        receipt.lastVerdict = verdict
        if verdict == "arrived" then
            receipt.phase = "arrived"
            receipt.completedAtHours = getGameTime():getWorldAgeHours()
            print("[StudyWorld] horse travel arrived rider=" .. tostring(riderId))
        elseif tostring(verdict):find("failed:", 1, true) == 1 then
            receipt.phase = "failed"
            receipt.failedAtHours = getGameTime():getWorldAgeHours()
            receipt.reason = verdict
            print("[StudyWorld] horse travel failed rider=" .. tostring(riderId)
                .. " reason=" .. tostring(verdict))
        end
    end
end
local function positionCharacter(body, point, attach)
    body:setX(point.x); body:setY(point.y); body:setZ(point.z)
    pcall(function() body:setLastX(point.x) end)
    pcall(function() body:setLastY(point.y) end)
    pcall(function() body:setLastZ(point.z) end)
    if attach then pcall(function() body:ensureOnTile() end) end
end
local function loadedMobileHousehold(receipt)
    local vehicles = getCell() and getCell():getVehicles()
    if not vehicles then return nil end
    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        local vehicle = iterator:next()
        local ok, id = pcall(function()
            return vehicle:getModData().SAOMobileHouseholdId
        end)
        if ok and id ~= nil and tostring(id) == tostring(receipt.vehicleId) then
            return vehicle
        end
    end
    return nil
end
local function mobileInteriorRow(body)
    local playerId = body:getModData().projectRV_playerId
    local external = playerId and ModData.get("modPROJECTRVInterior") or nil
    return playerId, type(external) == "table" and type(external.Players) == "table"
        and external.Players[tostring(playerId)] or nil
end
local function applyMobileHousehold()
    local spec = Config.situation and Config.situation.mobileHousehold
    if not spec then return end
    assert(SAO.MobileHousehold, "mobile household owner unavailable")
    state.situationReceipt = state.situationReceipt or {}
    local receipt = state.situationReceipt
    if not receipt.phase then
        receipt.schema, receipt.kind, receipt.phase = 1, "mobile-household-loaded", "spawn"
        receipt.script, receipt.result, receipt.datasetAdmission = spec.script, "running", "unreviewed"
    end
    if receipt.result == "completed" then return end
    receipt.waitTicks = (tonumber(receipt.waitTicks) or 0) + 1
    assert(receipt.waitTicks < 1800, "mobile household loaded transition timed out")
    local vehicle = loadedMobileHousehold(receipt)
    if receipt.phase == "spawn" then
        local square = getCell():getGridSquare(spec.spawn.x, spec.spawn.y, spec.spawn.z)
        if not square then return end
        vehicle = assert(addVehicle(spec.script, spec.spawn.x, spec.spawn.y, spec.spawn.z),
            "native mobile household creation failed")
        vehicle:getModData().projectRV_uniqueId = "study-" .. Config.definitionSha256:sub(1, 16)
        local record = assert(SAO.MobileHousehold.observeVehicle(vehicle, "loaded-study-spawn"),
            "spawned vehicle was not admitted as a mobile household")
        receipt.vehicleId, receipt.phase, receipt.waitTicks = record.id, "resident", 0
        receipt.spawnedAtHours = getGameTime():getWorldAgeHours()
        receipt.spawn = { x = vehicle:getX(), y = vehicle:getY(), z = vehicle:getZ() }
        print("[StudyWorld] mobile household=" .. tostring(record.id) .. " spawned")
        return
    end
    local personId = receipt.personId
    local body = personId and SAO.Body.get(personId) or nil
    if not body then
        for _, id in ipairs(keys(SAO.Identity.all())) do
            local person, candidate = SAO.Identity.all()[id], SAO.Body.get(id)
            if not person.dead and candidate then
                personId, body = id, candidate
                person.occupation = spec.residentOccupation
                receipt.personId = id
                break
            end
        end
    end
    if not body then return end
    if receipt.phase == "resident" then
        if not vehicle then return end
        positionCharacter(body, { x = vehicle:getX() + 2, y = vehicle:getY(), z = vehicle:getZ() }, true)
        local entered, verdict = SAO.MobileHousehold.enterInterior(
            personId, body, vehicle, "loaded-study-acceptance")
        assert(entered, "mobile household entry refused: " .. tostring(verdict))
        local playerId, row = mobileInteriorRow(body)
        assert(playerId and type(row) == "table" and type(row.ActualRoom) == "table",
            "Project RV interior receipt missing")
        receipt.interior = { x = row.ActualRoom.x, y = row.ActualRoom.y,
            z = row.ActualRoom.z or 0, bodyX = body:getX(), bodyY = body:getY(),
            roomType = tostring(row.RoomType) }
        vehicle:setX(spec.moved.x); vehicle:setY(spec.moved.y); vehicle:setZ(spec.moved.z)
        pcall(function() vehicle:setSquare(getCell():getGridSquare(
            spec.moved.x, spec.moved.y, spec.moved.z)) end)
        local moved = assert(SAO.MobileHousehold.observeVehicle(vehicle, "loaded-study-movement"),
            "moved mobile household became unavailable")
        assert(math.abs(moved.x - spec.moved.x) < 0.01
            and math.abs(moved.y - spec.moved.y) < 0.01,
            "moving exterior anchor was not observed")
        receipt.moved = { x = moved.x, y = moved.y, z = moved.z }
        receipt.enteredAtHours = getGameTime():getWorldAgeHours()
        receipt.phase, receipt.waitTicks = "load-interior", 0
        positionCharacter(assert(getSpecificPlayer(0), "observer anchor unavailable"),
            { x = receipt.interior.bodyX, y = receipt.interior.bodyY,
              z = receipt.interior.z }, false)
        print("[StudyWorld] mobile household entered person=" .. tostring(personId)
            .. " room=" .. tostring(receipt.interior.roomType))
        return
    end
    if receipt.phase == "load-interior" then
        local square = getCell():getGridSquare(receipt.interior.bodyX,
            receipt.interior.bodyY, receipt.interior.z)
        if not square then return end
        pcall(function() body:ensureOnTile() end)
        assert(square:TreatAsSolidFloor() and not square:isOutside(),
            "Project RV physical room did not load as an interior")
        if not SAO.MobileHousehold.isInterior(personId, body) then
            receipt.interior.identityWaitTicks =
                (tonumber(receipt.interior.identityWaitTicks) or 0) + 1
            return
        end
        receipt.interior.loaded = true
        receipt.interior.outside = square:isOutside()
        local floor = square:getFloor()
        receipt.interior.floorSprite = floor and floor:getSprite()
            and floor:getSprite():getName() or nil
        local exited, verdict = SAO.MobileHousehold.exitInterior(
            personId, body, "loaded-study-complete")
        assert(exited, "mobile household exit refused: " .. tostring(verdict))
        receipt.exitInitiatedAtHours = getGameTime():getWorldAgeHours()
        receipt.phase, receipt.waitTicks = "load-exterior", 0
        positionCharacter(assert(getSpecificPlayer(0), "observer anchor unavailable"),
            spec.moved, false)
        print("[StudyWorld] mobile household physical room loaded")
        return
    end
    if receipt.phase == "load-exterior" then
        local square = getCell():getGridSquare(spec.moved.x, spec.moved.y, spec.moved.z)
        if not square or not vehicle then return end
        pcall(function() body:ensureOnTile() end)
        local dx, dy = body:getX() - spec.moved.x, body:getY() - spec.moved.y
        assert(dx * dx + dy * dy <= 16 and not SAO.MobileHousehold.isInterior(personId, body),
            "resident did not return beside the moved exterior anchor")
        local households = ModData.getOrCreate("SurvivorAwareness_MobileHouseholds")
        local record = households.vehicles and households.vehicles[receipt.vehicleId]
        assert(record and #record.transitions >= 2,
            "mobile household transition history missing")
        receipt.transitionCount = #record.transitions
        receipt.materialRevision = record.materialRevision
        receipt.final = { x = body:getX(), y = body:getY(), z = body:getZ() }
        receipt.exitedAtHours = getGameTime():getWorldAgeHours()
        receipt.phase, receipt.result, receipt.waitTicks = "completed", "completed", 0
        print("[StudyWorld] mobile household exited person=" .. tostring(personId)
            .. " anchor=" .. tostring(receipt.vehicleId))
    end
end
local function omit(budget, path)
    if #budget.omitted < 256 then budget.omitted[#budget.omitted + 1] = path:sub(1, 512) end
    budget.omittedCount = budget.omittedCount + 1
end
local function copy(value, path, budget, seen, depth)
    local kind = type(value)
    budget.bytes = budget.bytes or 8 * 1024 * 1024
    if budget.left <= 0 or budget.bytes <= 0 or (kind == "string"
            and (#value > 32768 or #value + 2 > budget.bytes)) then
        omit(budget, path)
        return nil
    end
    local encoded = kind == "string" and quotedBytes(value)
        or kind == "number" and #tostring(value)
        or kind == "boolean" and (value and 4 or 5) or kind == "table" and 2 or 4
    if encoded > budget.bytes then
        omit(budget, path)
        return nil
    end
    budget.left = budget.left - 1
    if kind == "nil" or kind == "string" or kind == "boolean" or (kind == "number" and finite(value)) then
        budget.bytes = budget.bytes - encoded
        return value
    end
    if kind ~= "table" or depth > 16 or budget.left <= 0 or seen[value] then
        omit(budget, path)
        return nil
    end
    seen[value] = true
    local initialBytes = budget.bytes
    budget.bytes = budget.bytes - 2
    local result, members = {}, 0
    local isArray = getmetatable(value) == arrayMeta or #value > 0
    if isArray then
        local sourceMembers = 0
        for key in pairs(value) do
            sourceMembers = sourceMembers + 1
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #value then isArray = false; break end
        end
        if sourceMembers ~= #value then isArray = false end
    end
    if isArray then setmetatable(result, arrayMeta) end
    for _, key in ipairs(keys(value)) do
        if type(key) == "string" or type(key) == "number" then
            local excessiveKey = type(key) == "string" and #key > 32768
            local overhead = excessiveKey and budget.bytes + 1
                or (members > 0 and 1 or 0) + (isArray and 0 or quotedBytes(key) + 1)
            if excessiveKey or overhead > budget.bytes then
                omit(budget, path .. "." .. tostring(key))
                if isArray then
                    budget.bytes, seen[value] = initialBytes, nil
                    omit(budget, path)
                    return nil
                end
            else
                budget.bytes = budget.bytes - overhead
                local field = copy(value[key], path .. "." .. tostring(key), budget, seen, depth + 1)
                if field ~= nil then result[key], members = field, members + 1
                else
                    budget.bytes = budget.bytes + overhead
                    if isArray then
                        -- A missing indexed element would change the array's meaning.
                        budget.bytes, seen[value] = initialBytes, nil
                        omit(budget, path)
                        return nil
                    end
                end
            end
        end
    end
    seen[value] = nil
    return result
end
local function scalar(v)
    if type(v) == "string" or type(v) == "boolean" or finite(v) then return v end
    return nil
end
local INSPECTION_BYTES, LIVE_BYTES = 256 * 1024, 1024 * 1024
local function inspectionSnapshot(maxBytes)
    maxBytes = math.min(maxBytes or INSPECTION_BYTES, INSPECTION_BYTES)
    local read, snapshot = pcall(function() return SAO.Observation and SAO.Observation.snapshot() end)
    if not read or type(snapshot) ~= "table" then
        return { status = read and "unavailable" or "failed", message = "Person inspection is unavailable", people = {} }
    end
    local result = { people = {} }
    for _, key in ipairs({ "sequence", "capturedAtUnixMs", "worldHours", "status", "message",
            "omittedPeople", "omittedEvents", "selectedPersonId" }) do result[key] = scalar(snapshot[key]) end
    local omittedPeople, omittedSections, omittedRows, omittedEvents = 0, 0, 0, 0
    local projected, fits = pcall(function()
        -- Reserve header growth for the explicit omission counts/message. Each
        -- inserted value is measured once with the production JSON encoder.
        local budget = { left = maxBytes - 1024 }
        if not jsonFits(result, budget) then return false end
        local function take(value)
            local trial = { left = budget.left - 1 } -- member/array comma
            local ok = jsonFits(value, trial)
            if ok then budget.left = trial.left end
            return ok
        end
        local ids = keys(snapshot.people)
        if snapshot.selectedPersonId and snapshot.people[snapshot.selectedPersonId] then
            for i, id in ipairs(ids) do
                if id == snapshot.selectedPersonId then table.remove(ids, i); break end
            end
            table.insert(ids, 1, snapshot.selectedPersonId)
        end
        for _, id in ipairs(ids) do
            local detail = snapshot.people[id]
            local item = { sections = array(), events = array() }
            if take({ [id] = item }) then
                result.people[id] = item
                if detail.cognition then
                    local cognitionBudget = {left=12000,omitted={},omittedCount=0}
                    local cognition = copy(detail.cognition, "cognition", cognitionBudget, {}, 0)
                    if cognition and cognitionBudget.omittedCount == 0 and take({ cognition = cognition }) then item.cognition = cognition
                    else omittedSections = omittedSections + 1 end
                end
                for _, source in ipairs(detail.sections or {}) do
                    local section = { rows = array() }
                    for _, key in ipairs({ "id", "label", "source", "perspective", "status", "message" }) do
                        section[key] = scalar(source[key])
                    end
                    if take(section) then
                        item.sections[#item.sections + 1] = section
                        for _, row in ipairs(source.rows or {}) do
                            local value = { label = scalar(row.label), value = scalar(row.value) }
                            if take(value) then section.rows[#section.rows + 1] = value
                            else omittedRows = omittedRows + 1 end
                        end
                    else
                        omittedSections = omittedSections + 1
                        omittedRows = omittedRows + #(source.rows or {})
                    end
                end
                for _, event in ipairs(detail.events or {}) do
                    local value = {}
                    for key, field in pairs(event) do value[key] = scalar(field) end
                    if take(value) then item.events[#item.events + 1] = value
                    else omittedEvents = omittedEvents + 1 end
                end
            else
                omittedPeople, omittedEvents = omittedPeople + 1, omittedEvents + #(detail.events or {})
                for _, source in ipairs(detail.sections or {}) do
                    omittedSections, omittedRows = omittedSections + 1, omittedRows + #(source.rows or {})
                end
            end
        end
        result.omittedPeople = (result.omittedPeople or 0) + omittedPeople
        result.omittedEvents = (result.omittedEvents or 0) + omittedEvents
        if omittedPeople + omittedSections + omittedRows + omittedEvents > 0 then
            result.message = (result.message or ""):sub(1, 384) .. " Export byte budget: " .. omittedPeople
                .. " people, " .. omittedSections .. " sections, " .. omittedRows .. " rows and "
                .. omittedEvents .. " events omitted."
        end
        return jsonFits(result, { left = maxBytes })
    end)
    if not projected or not fits then
        -- Optional detail must not stop either producer. Keep the source's last
        -- successful observation clock; do not stamp an export failure as new knowledge.
        result.people, result.status = {}, "failed"
        result.message = "Person inspection export unavailable; detail omitted"
        local total, events = 0, 0
        for _, detail in pairs(type(snapshot.people) == "table" and snapshot.people or {}) do
            total = total + 1
            if type(detail) == "table" and type(detail.events) == "table" then events = events + #detail.events end
        end
        result.omittedPeople = total + (tonumber(snapshot.omittedPeople) or 0)
        result.omittedEvents = events + (tonumber(snapshot.omittedEvents) or 0)
    end
    return result
end
local function objectView(object)
    local sprite = object:getSprite()
    local result = { objectName = object:getObjectName(), sprite = sprite and sprite:getName() or nil }
    if instanceof(object, "IsoDoor") or instanceof(object, "IsoWindow") then
        result.open = object:IsOpen()
        result.north = object:getNorth()
    end
    return result
end
local function squareView(square, x, y, z)
    local objects = square:getObjects()
    local out = { x = x, y = y, z = z, outside = square:isOutside(),
        solid = square:isSolid(), solidTrans = square:isSolidTrans(),
        floor = square:TreatAsSolidFloor(), objects = array() }
    local floor = square:getFloor()
    out.floorSprite = floor and floor:getSprite() and floor:getSprite():getName() or nil
    for i = 0, objects:size() - 1 do out.objects[#out.objects + 1] = objectView(objects:get(i)) end
    return out
end
local function windowCoordinates(window)
    local xmin, ymin = window.x, window.y
    local xmax, ymax = xmin + window.width - 1, ymin + window.height - 1
    local cx, cy = math.floor((xmin + xmax) / 2), math.floor((ymin + ymax) / 2)
    -- A native site can be off-center in its authored observation rectangle.
    -- Prefer its actual location, then a lived origin, then the rectangle center.
    for _, candidates in ipairs({ Config.observation.sites or {}, Config.origins or {} }) do
        local found = false
        for _, point in ipairs(candidates) do
            if point.z == window.z and point.x >= xmin and point.x <= xmax
                    and point.y >= ymin and point.y <= ymax then
                cx, cy, found = math.floor(point.x), math.floor(point.y), true
                break
            end
        end
        if found then break end
    end
    local radius, offset = 0, 0
    local limit = math.max(cx - xmin, xmax - cx, cy - ymin, ymax - cy)
    -- Lazy clipped Chebyshev rings visit each bounded rectangle coordinate once.
    -- No full geometry list or sort is built before the shared copy ledger runs.
    return function()
        while radius <= limit do
            local x, y
            if radius == 0 then
                x, y = cx, cy
                radius = 1
            else
                local edge, along = math.floor(offset / (2 * radius)), offset % (2 * radius)
                if edge == 0 then x, y = cx - radius + along, cy - radius
                elseif edge == 1 then x, y = cx + radius, cy - radius + along
                elseif edge == 2 then x, y = cx + radius - along, cy + radius
                else x, y = cx - radius, cy + radius - along end
                offset = offset + 1
                if offset == 8 * radius then radius, offset = radius + 1, 0 end
            end
            if x >= xmin and x <= xmax and y >= ymin and y <= ymax then return x, y end
        end
    end
end
function Study.observe()
    assert(Study.active and state, "study is not active")
    assert(selected() and boundsMatch(), "native world changed after study startup")
    settingsMatch()
    local hours = getGameTime():getWorldAgeHours()
    assert(finite(hours), "world clock unavailable")
    local budget = { left = 100000, bytes = 8 * 1024 * 1024, omitted = array(), omittedCount = 0 }
    local frame = { schema = "sao-study-observation/1", definitionSha256 = Config.definitionSha256,
        packageEngineJarSha256 = Config.engineJarSha256, engineVersion = getCore():getVersion(),
        observerSha256 = Config.observerSha256,
        map = getWorld():getMap(), save = getWorld():getWorld(), sequence = state.sequence + 1,
        hours = hours, countyHours = SAO.History.countyHours(),
        session = session, datasetAdmission = "unreviewed", extent = Config.extent,
        sandbox = Config.sandbox, generation = Config.generation, situation = Config.situation or {},
        situationReceipt = copy(state.situationReceipt or {}, "situationReceipt",
            budget, {}, 0) or {},
        source = "loaded-native-world", mods = array(), windows = array(), people = array(),
        processes = array(), population = { total = 0, captured = 0, dead = 0,
            represented = 0, unrepresented = 0 },
        coverage = { requestedSquares = 0, loadedSquares = 0, unavailableSquares = 0, omittedSquares = 0,
            peopleComplete = true, processesComplete = true,
            physicalCoverage = "loaded-squares-only", observerMovesWorld = false } }
    local mods = getActivatedMods()
    if Config.observation.sites then frame.observationSites = Config.observation.sites end
    for i = 0, mods:size() - 1 do frame.mods[#frame.mods + 1] = mods:get(i) end
    local cell = getCell()
    assert(cell, "native cell unavailable")
    local function physicalWindows()
    local walkers = {}
    for _, window in ipairs(Config.observation.windows) do
        local result = { id = window.id, x = window.x, y = window.y, z = window.z,
            width = window.width, height = window.height, squares = array(), unavailable = 0, omitted = 0 }
        frame.windows[#frame.windows + 1] = result
        walkers[#walkers + 1] = { window = window, result = result, next = windowCoordinates(window) }
    end
    local pending = true
    while pending do
        pending = false
        for _, walker in ipairs(walkers) do
            local x, y = walker.next()
            if x then
                pending = true
                local window, result = walker.window, walker.result
                local square = cell:getGridSquare(x, y, window.z)
                frame.coverage.requestedSquares = frame.coverage.requestedSquares + 1
                if square then
                    local beforeBytes, beforeOmitted = budget.bytes, budget.omittedCount
                    local path = "windows." .. window.id .. ".squares." .. tostring(x) .. "." .. tostring(y)
                    local projected = copy(squareView(square, x, y, window.z), path, budget, {}, 0)
                    if projected and beforeOmitted == budget.omittedCount then
                        result.squares[#result.squares + 1] = projected
                        frame.coverage.loadedSquares = frame.coverage.loadedSquares + 1
                    else
                        -- Keep complete native square shapes; budget omission is not unloaded geometry.
                        budget.bytes = beforeBytes
                        result.omitted = result.omitted + 1
                        frame.coverage.omittedSquares = frame.coverage.omittedSquares + 1
                        omit(budget, path)
                    end
                else
                    result.unavailable = result.unavailable + 1
                    frame.coverage.unavailableSquares = frame.coverage.unavailableSquares + 1
                end
            end
        end
    end
    end
    local inspection = inspectionSnapshot()
    local records = SAO.Identity.all()
    local recordIds = keys(records)
    if inspection.selectedPersonId and records[inspection.selectedPersonId] then
        for i, id in ipairs(recordIds) do
            if id == inspection.selectedPersonId then table.remove(recordIds, i); break end
        end
        table.insert(recordIds, 1, inspection.selectedPersonId)
    end
    for _, id in ipairs(recordIds) do
        local rec = records[id]
        local body = SAO.Body.get(id)
        local represented = SAO.Body.hasRepresentation(id) == true
        frame.population.total = frame.population.total + 1
        if rec.dead then frame.population.dead = frame.population.dead + 1 end
        local category = represented and "represented" or "unrepresented"
        frame.population[category] = frame.population[category] + 1
        if #frame.people < Config.observation.maxPeople then
            local recordView = {}
            for key, value in pairs(rec) do if key ~= "cognition" then recordView[key] = value end end
            local person = { id = tostring(id), representation = category,
                record = copy(recordView, "people." .. tostring(id), budget, {}, 0) or {},
                positionSource = "durable-record", x = scalar(rec.x), y = scalar(rec.y), z = scalar(rec.z) }
            if body then
                person.x, person.y, person.z = body:getX(), body:getY(), body:getZ()
                person.positionSource = "native-body"
            end
            -- Read existing stores directly. Their get/ensure helpers may open
            -- a missing person's store, which an observer must never do.
            local controller = SAO.Controller and SAO.Controller.agents[id]
            local beliefs = SAO.Perception and SAO.Perception.beliefs[id]
            person.context = {
                controllerAvailable = controller ~= nil, perceptionAvailable = beliefs ~= nil,
                controller = controller and {
                    state = scalar(controller.state), stateSince = scalar(controller.stateSince),
                    nextDecisionAt = scalar(controller.nextDecisionAt), passive = scalar(controller.passive)
                } or {},
                beliefs = copy(beliefs or {}, "people." .. tostring(id) .. ".beliefs", budget, {}, 0) or {}
            }
            local detail = inspection.people[tostring(id)]
            if detail then
                local beforeBytes, beforeOmitted = budget.bytes, budget.omittedCount
                local path = "people." .. tostring(id) .. ".inspection"
                local projected = copy({ sequence = inspection.sequence,
                    capturedAtUnixMs = inspection.capturedAtUnixMs, worldHours = inspection.worldHours,
                    status = inspection.status, message = inspection.message,
                    sections = detail.sections, events = detail.events },
                    path, budget, {}, 0)
                if projected and beforeOmitted == budget.omittedCount then person.context.inspection = projected
                else budget.bytes = beforeBytes; omit(budget, path) end
            end
            frame.people[#frame.people + 1] = person
        end
    end
    frame.population.captured = #frame.people
    frame.coverage.peopleComplete = frame.population.total == #frame.people
    frame.coverage.organizationAvailable = SAO.Organization ~= nil
    local processes = SAO.Organization and SAO.Organization.processes or {}
    local processIds = keys(processes)
    frame.coverage.totalProcesses = #processIds
    for i = 1, math.min(#processIds, Config.observation.maxProcesses) do
        local id = processIds[i]
        frame.processes[#frame.processes + 1] = {
            id = tostring(id), record = copy(processes[id], "processes." .. tostring(id), budget, {}, 0) or {} }
    end
    frame.coverage.processesComplete = #processIds == #frame.processes
    physicalWindows()
    frame.coverage.omittedFields = budget.omitted
    frame.coverage.omittedFieldCount = budget.omittedCount
    if SAO.Cognition and SAO.Cognition.snapshot then
        -- Optional cognitive archives share the actual frame's remaining byte
        -- budget. Core capture survives unavailable or oversized model detail.
        local encoded = { left = 64 * 1024 * 1024 - 65536 }
        local fits = jsonFits(frame, encoded)
        local remaining = fits and math.min(4 * 1024 * 1024, encoded.left) or 0
        for _, person in ipairs(frame.people) do
            local accepted = false
            if remaining > 32 then
                local ok, cognition = pcall(SAO.Cognition.snapshot, person.id, true)
                if ok and type(cognition) == "table" then
                    local trial = { left = math.min(512 * 1024, remaining, budget.bytes) - 16 }
                    local start = trial.left
                    if jsonFits(cognition, trial) then
                        person.context.cognition = cognition
                        remaining = remaining - (start - trial.left + 16)
                        budget.bytes = budget.bytes - (start - trial.left + 16)
                        accepted = true
                    end
                end
            end
            if not accepted then
                budget.omittedCount = budget.omittedCount + 1
                if #budget.omitted < 256 then
                    budget.omitted[#budget.omitted + 1] = "people." .. person.id .. ".cognition"
                end
            end
        end
        frame.coverage.omittedFieldCount = budget.omittedCount
    end
    return frame
end
local lastLiveAt = 0
local function flushExports()
    if not exportOwner then return end
    if pendingLive then
        local pending = pendingLive
        local status = exportOwner:receiptStatus(pending.ticket)
        if status ~= "pending" then
            assert(exportOwner:receiptKey(pending.ticket) == pending.key, "live export receipt changed owner")
            assert(status == "published" or status == "deferred",
                exportOwner:receiptFailure(pending.ticket) or "live export failed")
            -- Publication time sets pacing; the frame retains its source capture time.
            lastLiveAt = exportOwner:receiptCompletedAt(pending.ticket)
            exportOwner:release(pending.ticket)
            pendingLive = nil
        end
    end
    if pendingArchive then
        local pending = pendingArchive
        local status = exportOwner:receiptStatus(pending.ticket)
        if status ~= "pending" then
            assert(exportOwner:receiptKey(pending.ticket) == pending.key, "archive export receipt changed owner")
            assert(exportOwner:receiptSequence(pending.ticket) == pending.sequence,
                "archive export receipt changed sequence")
            assert(status == "published" or status == "deferred",
                exportOwner:receiptFailure(pending.ticket) or "archive export failed")
            if status == "published" then
                assert(state.sequence + 1 == pending.sequence, "archive acknowledgement lost sequence ownership")
                state.sequence = pending.sequence
                Study.archiveCapture = pending.captured
                print("[StudyWorld] frame=" .. tostring(pending.sequence) .. " hours=" .. tostring(pending.hours)
                    .. " loaded=" .. tostring(pending.loaded) .. " people=" .. tostring(pending.people))
            else
                local reason = exportOwner:receiptReason(pending.ticket)
                assert(reason == "encoded-byte-budget" or reason == "detached-node-budget"
                    or reason == "detached-depth-budget", "archive deferral has no confirmed capacity reason")
                pending.deferred.reason = reason
                Study.archiveCapture = pending.deferred
                print("[StudyWorld] capture-deferred sequence=" .. tostring(pending.sequence)
                    .. " hours=" .. tostring(pending.hours) .. " reason=" .. reason)
            end
            lastHours = pending.hours
            exportOwner:release(pending.ticket)
            pendingArchive = nil
        end
    end
end
function Study.drainExports()
    exportStopping = true
    flushExports()
    return pendingLive == nil and pendingArchive == nil
end
-- The tool's native stop owner invokes this same acknowledgement path before save.
SAO_StudyWorld = Study
local function count(values)
    local n = 0
    for _ in pairs(values or {}) do n = n + 1 end
    return n
end
local function liveInspection(hours)
    local reference = getSpecificPlayer and getSpecificPlayer(0)
    if not reference or reference:getModData().SAO_ObserverStarted ~= true then return end
    local now = getTimestampMs()
    if pendingLive or exportStopping or now - lastLiveAt < 1000 then return end
    local ticket, key = nil, nil
    if exportOwner then
        key = exportKey .. "/live/" .. tostring(now)
        ticket = exportOwner:reserve("live", key)
        if ticket == 0 then return end
    end
    local frame = { schema = "sao-study-live/1", definitionSha256 = Config.definitionSha256,
        datasetAdmission = "unreviewed", save = getWorld():getWorld(), hours = hours,
        people = array(), population = { total = 0, captured = 0, represented = 0, dead = 0 } }
    for _, id in ipairs(keys(SAO.Identity.all())) do
        local rec = SAO.Identity.all()[id]
        local body = SAO.Body.get(id)
        frame.population.total = frame.population.total + 1
        if body then frame.population.represented = frame.population.represented + 1 end
        if rec.dead then frame.population.dead = frame.population.dead + 1 end
        if #frame.people < math.min(Config.observation.maxPeople, 2048) then
            local controller = SAO.Controller and SAO.Controller.agents[id]
            local beliefs = SAO.Perception and SAO.Perception.beliefs[id]
            frame.people[#frame.people + 1] = { id = tostring(id),
                positionSource = body and "native-body" or "durable-record",
                x = body and body:getX() or scalar(rec.x), y = body and body:getY() or scalar(rec.y),
                z = body and body:getZ() or scalar(rec.z),
                record = { forename = scalar(rec.forename), surname = scalar(rec.surname),
                    occupation = scalar(rec.occupation), dead = rec.dead == true },
                context = { controllerAvailable = controller ~= nil, perceptionAvailable = beliefs ~= nil,
                    controller = { state = controller and scalar(controller.state) or nil },
                    beliefCounts = { people = count(beliefs and beliefs.people),
                                     sounds = count(beliefs and beliefs.sounds),
                                     zombies = count(beliefs and beliefs.zombies) } } }
        end
    end
    frame.population.captured = #frame.people
    -- Core people remain complete rows. Their captured/total counts already
    -- disclose truncation, and leave room for an explicit inspection status.
    local coreBudget = { left = LIVE_BYTES - 2048 }
    local fits = jsonFits(frame, coreBudget)
    while not fits and #frame.people > 0 do
        -- At most logarithmically many whole-frame trials, even at the 2048-person cap.
        local retain = math.floor(#frame.people / 2)
        while #frame.people > retain do table.remove(frame.people) end
        frame.population.captured = #frame.people
        coreBudget = { left = LIVE_BYTES - 2048 }
        fits = jsonFits(frame, coreBudget)
    end
    assert(fits, "live observation core exceeds export byte budget")
    frame.inspection = inspectionSnapshot(math.min(INSPECTION_BYTES, coreBudget.left + 2048 - 32))
    if Study.archiveCapture and Study.archiveCapture.status == "deferred" then
        frame.archiveCapture = Study.archiveCapture
        local reason = Study.archiveCapture.reason
        local explanation = reason == "detached-node-budget" and "detached node budget exceeded."
            or reason == "detached-depth-budget" and "detached depth budget exceeded."
            or "encoded byte budget exceeded."
        frame.inspection.message = (frame.inspection.message or ""):sub(1, 380)
            .. " Archive capture deferred: " .. explanation
    end
    if exportOwner then
        assert(exportOwner:submitLive(ticket, frame, arrayMeta, LIVE_BYTES) == "accepted",
            "reserved live export was not accepted")
        pendingLive = { ticket = ticket, key = key }
        return
    end
    local text = json(frame, nil, { left = LIVE_BYTES })
    local writer = assert(getFileWriter("StudyWorldLive.json", true, false), "live inspection writer unavailable")
    writer:write(text)
    writer:close()
    -- Export is synchronous on the game thread. A slow export must still leave
    -- a full cooldown after its completed write before either tick can repeat it.
    lastLiveAt = getTimestampMs()
end
local function writeArchiveStatus()
    local receiptText = json(Study.archiveCapture)
    local receipt = assert(getFileWriter("StudyWorldArchiveStatus.json", true, false),
        "archive status writer unavailable")
    receipt:write(receiptText .. "\n"); receipt:close()
    local receiptReader = assert(getFileReader("StudyWorldArchiveStatus.json", false),
        "archive status read-back unavailable")
    local received, extra = receiptReader:readLine(), receiptReader:readLine()
    receiptReader:close()
    assert(received == receiptText and extra == nil, "archive status read-back differs")
end
function Study.tick()
    beginExport()
    flushExports()
    if not Study.active or exportStopping then return end
    applyInitialNeeds()
    applyResourceObjectives()
    applyHorseTravel()
    applyMobileHousehold()
    local hours = getGameTime():getWorldAgeHours()
    liveInspection(hours)
    if isGamePaused() then return end
    if pendingArchive then return end
    if lastHours and hours - lastHours < Config.observation.everyHours then return end
    local ticket, key = nil, nil
    if exportOwner then
        key = exportKey .. "/archive/" .. tostring(state.sequence + 1)
        ticket = exportOwner:reserve("archive", key)
        if ticket == 0 then return end
    end
    local capturedAtUnixMs = getTimestampMs()
    local frame = Study.observe()
    if exportOwner then
        local captured = { status = "captured", sequence = frame.sequence, worldHours = hours,
            definitionSha256 = frame.definitionSha256, save = frame.save, session = frame.session,
            observerSha256 = frame.observerSha256, packageEngineJarSha256 = frame.packageEngineJarSha256,
            datasetAdmission = "unreviewed" }
        local deferred = { status = "deferred", reason = "encoded-byte-budget",
            attemptedSequence = frame.sequence, worldHours = hours,
            capturedAtUnixMs = capturedAtUnixMs, datasetAdmission = "unreviewed",
            definitionSha256 = frame.definitionSha256, save = frame.save, session = frame.session,
            observerSha256 = frame.observerSha256, packageEngineJarSha256 = frame.packageEngineJarSha256 }
        local saveKey = tostring(frame.save):gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
        local name = "StudyWorld/" .. Config.definitionSha256 .. "/" .. saveKey .. "/" .. session
            .. "/" .. string.format("%016d", frame.sequence) .. ".json"
        assert(exportOwner:submitArchive(ticket, frame, arrayMeta, 64 * 1024 * 1024,
            name, captured, deferred) == "accepted", "reserved archive export was not accepted")
        pendingArchive = { ticket = ticket, key = key, sequence = frame.sequence,
            captured = captured, deferred = deferred, hours = hours,
            loaded = frame.coverage.loadedSquares, people = frame.population.total }
        return
    end
    local encoded, line = boundedJson(frame, { left = 64 * 1024 * 1024 })
    if not encoded then
        -- Optional archive projection is independent from cognition and live frames.
        -- Preserve an explicit receipt without advancing the archive acknowledgement.
        Study.archiveCapture = { status = "deferred", reason = "encoded-byte-budget",
            attemptedSequence = frame.sequence, worldHours = hours,
            capturedAtUnixMs = getTimestampMs(), datasetAdmission = "unreviewed",
            definitionSha256 = Config.definitionSha256, save = getWorld():getWorld(), session = session,
            observerSha256 = Config.observerSha256, packageEngineJarSha256 = Config.engineJarSha256 }
        writeArchiveStatus()
        lastHours = hours
        print("[StudyWorld] capture-deferred sequence=" .. tostring(frame.sequence)
            .. " hours=" .. tostring(hours) .. " reason=encoded-byte-budget")
        return
    end
    assert(#line <= 64 * 1024 * 1024, "observation exceeds export byte budget")
    -- Encode each byte of the save name, preserving distinct names and paths.
    local saveKey = tostring(frame.save):gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
    local name = "StudyWorld/" .. Config.definitionSha256 .. "/" .. saveKey .. "/" .. session
        .. "/" .. string.format("%016d", frame.sequence) .. ".json"
    local writer = getFileWriter(name, true, false)
    assert(writer, "observation writer unavailable")
    local ok, reason = pcall(function() writer:write(line .. "\n") end)
    writer:close()
    assert(ok, reason)
    -- The native LuaFileWriter wraps PrintWriter, which can suppress failures.
    -- Read-back proves the complete bytes are visible before acknowledging.
    local reader = getFileReader(name, false)
    assert(reader, "observation read-back unavailable")
    local received, extra = reader:readLine(), reader:readLine()
    reader:close()
    assert(received == line and extra == nil, "observation read-back differs")
    state.sequence = frame.sequence
    Study.archiveCapture = { status = "captured", sequence = frame.sequence, worldHours = hours,
        definitionSha256 = frame.definitionSha256, save = frame.save, session = frame.session,
        observerSha256 = frame.observerSha256, packageEngineJarSha256 = frame.packageEngineJarSha256,
        datasetAdmission = "unreviewed" }
    writeArchiveStatus()
    lastHours = hours
    print("[StudyWorld] frame=" .. tostring(frame.sequence) .. " hours=" .. tostring(hours)
        .. " loaded=" .. tostring(frame.coverage.loadedSquares) .. " people=" .. tostring(frame.population.total))
end
local function guarded(fn)
    return function()
        local ok, reason = pcall(fn)
        if not ok then stop(reason) end
    end
end
Events.OnPreMapLoad.Add(guarded(Study.prepare))
Events.OnInitWorld.Add(guarded(Study.options))
Events.OnInitGlobalModData.Add(function(isNewWorld)
    if selected() then newGame = isNewWorld == true end
end)
Events.OnGameStart.Add(guarded(Study.start))
Events.OnTick.Add(guarded(Study.tick))
Events.OnTickEvenPaused.Add(guarded(Study.tick))
Study.encode = function(value, maxBytes)
    return json(value, nil, { left = maxBytes or 64 * 1024 * 1024 })
end
return Study
