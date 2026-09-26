-- The builder supplies Config as a data-only local before this source.
-- Native lifecycle: OnPreMapLoad precedes WorldGenParams.load/CreateStep1;
-- OnInitWorld is already too late to define the meta-grid's bounds.
local Study = { active = false, error = nil }
local state = nil
local lastHours = nil
local newGame = false
local session = nil
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
    assert(bytes <= budget.left, "observation exceeds export byte budget")
    budget.left = budget.left - bytes
end
local function quote(s, budget)
    s = tostring(s)
    local length = #s + 2
    for c in s:gmatch('[%z\1-\31\\"]') do
        length = length + ((c == '"' or c == '\\') and 1 or 5)
    end
    charge(budget, length)
    return '"' .. tostring(s):gsub('[%z\1-\31\\"]', function(c)
        if c == '"' then return '\\"' end
        if c == '\\' then return '\\\\' end
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end
local function json(value, seen, budget)
    budget = budget or { left = 64 * 1024 * 1024 }
    local kind = type(value)
    if kind == "nil" then charge(budget, 4); return "null" end
    if kind == "boolean" then charge(budget, value and 4 or 5); return value and "true" or "false" end
    if kind == "number" then
        assert(finite(value), "non-finite observation")
        local encoded = tostring(value)
        charge(budget, #encoded)
        return encoded
    end
    if kind == "string" then return quote(value, budget) end
    assert(kind == "table", "unsupported observation value")
    seen = seen or {}
    assert(not seen[value], "cyclic observation")
    seen[value] = true
    charge(budget, 2)
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
            if i > 1 then charge(budget, 1) end
            parts[#parts + 1] = json(value[i], seen, budget)
        end
    else
        for _, key in ipairs(keys(value)) do
            charge(budget, #parts > 0 and 2 or 1)
            parts[#parts + 1] = quote(key, budget) .. ":" .. json(value[key], seen, budget)
        end
    end
    seen[value] = nil
    return (isArray and "[" or "{") .. table.concat(parts, ",")
        .. (isArray and "]" or "}")
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
    Study.active = true
    print("[StudyWorld] observation active save=" .. getWorld():getWorld())
    return true
end
local function copy(value, path, budget, seen, depth)
    local kind = type(value)
    if budget.left <= 0 or (kind == "string" and #value > 32768) then
        if #budget.omitted < 256 then budget.omitted[#budget.omitted + 1] = path end
        budget.omittedCount = budget.omittedCount + 1
        return nil
    end
    budget.left = budget.left - 1
    if kind == "nil" or kind == "string" or kind == "boolean" then return value end
    if kind == "number" and finite(value) then return value end
    if kind ~= "table" or depth > 16 or budget.left <= 0 or seen[value] then
        if #budget.omitted < 256 then budget.omitted[#budget.omitted + 1] = path end
        budget.omittedCount = budget.omittedCount + 1
        return nil
    end
    seen[value] = true
    local result = {}
    for _, key in ipairs(keys(value)) do
        if type(key) == "string" or type(key) == "number" then
            result[key] = copy(value[key], path .. "." .. tostring(key), budget, seen, depth + 1)
        end
    end
    seen[value] = nil
    return result
end
local function scalar(v)
    if type(v) == "string" or type(v) == "boolean" or finite(v) then return v end
    return nil
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
function Study.observe()
    assert(Study.active and state, "study is not active")
    assert(selected() and boundsMatch(), "native world changed after study startup")
    settingsMatch()
    local hours = getGameTime():getWorldAgeHours()
    assert(finite(hours), "world clock unavailable")
    local frame = { schema = "sao-study-observation/1", definitionSha256 = Config.definitionSha256,
        packageEngineJarSha256 = Config.engineJarSha256, engineVersion = getCore():getVersion(),
        observerSha256 = Config.observerSha256,
        map = getWorld():getMap(), save = getWorld():getWorld(), sequence = state.sequence + 1,
        hours = hours, session = session, datasetAdmission = "unreviewed", extent = Config.extent,
        sandbox = Config.sandbox, generation = Config.generation,
        source = "loaded-native-world", mods = array(), windows = array(), people = array(),
        processes = array(), population = { total = 0, captured = 0, dead = 0,
            represented = 0, unrepresented = 0 },
        coverage = { requestedSquares = 0, loadedSquares = 0, unavailableSquares = 0,
            peopleComplete = true, processesComplete = true,
            physicalCoverage = "loaded-squares-only", observerMovesWorld = false } }
    local mods = getActivatedMods()
    for i = 0, mods:size() - 1 do frame.mods[#frame.mods + 1] = mods:get(i) end
    local cell = getCell()
    assert(cell, "native cell unavailable")
    for _, window in ipairs(Config.observation.windows) do
        local result = { id = window.id, x = window.x, y = window.y, z = window.z,
            width = window.width, height = window.height, squares = array(), unavailable = 0 }
        for y = window.y, window.y + window.height - 1 do
            for x = window.x, window.x + window.width - 1 do
                local square = cell:getGridSquare(x, y, window.z)
                frame.coverage.requestedSquares = frame.coverage.requestedSquares + 1
                if square then
                    result.squares[#result.squares + 1] = squareView(square, x, y, window.z)
                    frame.coverage.loadedSquares = frame.coverage.loadedSquares + 1
                else
                    result.unavailable = result.unavailable + 1
                    frame.coverage.unavailableSquares = frame.coverage.unavailableSquares + 1
                end
            end
        end
        frame.windows[#frame.windows + 1] = result
    end
    local budget = { left = 100000, omitted = array(), omittedCount = 0 }
    local records = SAO.Identity.all()
    for _, id in ipairs(keys(records)) do
        local rec = records[id]
        local body = SAO.Body.get(id)
        local represented = SAO.Body.hasRepresentation(id) == true
        frame.population.total = frame.population.total + 1
        if rec.dead then frame.population.dead = frame.population.dead + 1 end
        local category = represented and "represented" or "unrepresented"
        frame.population[category] = frame.population[category] + 1
        if #frame.people < Config.observation.maxPeople then
            local person = { id = tostring(id), representation = category,
                record = copy(rec, "people." .. tostring(id), budget, {}, 0) or {},
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
    frame.coverage.omittedFields = budget.omitted
    frame.coverage.omittedFieldCount = budget.omittedCount
    return frame
end
local lastLiveAt = 0
local function count(values)
    local n = 0
    for _ in pairs(values or {}) do n = n + 1 end
    return n
end
local function liveInspection(hours)
    local reference = getSpecificPlayer and getSpecificPlayer(0)
    if not reference or reference:getModData().SAO_ObserverStarted ~= true then return end
    local now = getTimestampMs()
    if now - lastLiveAt < 1000 then return end
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
    local text = json(frame, nil, { left = 1024 * 1024 })
    local writer = assert(getFileWriter("StudyWorldLive.json", true, false), "live inspection writer unavailable")
    writer:write(text)
    writer:close()
    lastLiveAt = now
end
function Study.tick()
    if not Study.active or isGamePaused() then return end
    local hours = getGameTime():getWorldAgeHours()
    liveInspection(hours)
    if lastHours and hours - lastHours < Config.observation.everyHours then return end
    local frame = Study.observe()
    local line = json(frame)
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
Study.encode = function(value, maxBytes)
    return json(value, nil, { left = maxBytes or 64 * 1024 * 1024 })
end
return Study
