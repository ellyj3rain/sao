-- Controlled lifecycle fixtures. Native persistence is tested separately in
-- NativeStudyProbe; these fixtures do not claim to be a loaded game.
Events = {}
local messages = {}
print = function(message) messages[#messages + 1] = tostring(message) end
for _, name in ipairs({"OnPreMapLoad", "OnInitWorld", "OnInitGlobalModData", "OnNewGame", "OnGameStart", "OnTick"}) do
    local callbacks = {}
    Events[name] = { Add = function(fn) callbacks[#callbacks + 1] = fn end,
        fire = function(value) for _, fn in ipairs(callbacks) do fn(value) end end }
end
local currentMap, currentSave, hour, persisted = "OtherMap", "StudySave", 12, {}
local values, writes, files = {}, {}, {}
local discardWrite = false
local options = {}
worldgen = { roads = { small_road = { p = 0.0005, filter_edge = 5e8 } } }
local function option(value)
    return { value = value,
        asConfigOption = function(self) return self end,
        makeCopy = function(self) return option(self.value) end,
        isValidString = function(self, v) return v ~= "100001" end,
        setValueFromObject = function(self, v) self.value = v end,
        getValueAsObject = function(self) return self.value end }
end
for key, value in pairs(Config.sandbox) do options[key] = option(value) end
getSandboxOptions = function()
    return { getOptionByName = function(self, key) return options[key] end,
        set = function(self, key, value) options[key].value = value end,
        toLua = function() end }
end
WorldGenParams = { INSTANCE = {
    setSeedString = function(self, v) values.seed = v end,
    getSeedString = function(self) return values.seed end,
    setMinXCell = function(self, v) values.minX = v end,
    setMinYCell = function(self, v) values.minY = v end,
    setMaxXCell = function(self, v) values.maxX = v end,
    setMaxYCell = function(self, v) values.maxY = v end } }
local grid = { getMinX = function() return values.minX end,
    getMinY = function() return values.minY end,
    getMaxX = function() return values.maxX end,
    getMaxY = function() return values.maxY end }
getWorld = function() return {
    getMap = function() return currentMap end,
    getWorld = function() return currentSave end,
    getMetaGrid = function() return grid end } end
getCore = function() return { getVersion = function() return "controlled-fixture" end } end
getGameTime = function() return { getWorldAgeHours = function() return hour end } end
getTimestampMs = function() return 123456789 end
isGamePaused = function() return false end
isClient = function() return false end
isServer = function() return false end
ModData = { getOrCreate = function() return persisted end }
local function list(value)
    return { size = function() return #value end, get = function(self, i) return value[i + 1] end }
end
getActivatedMods = function() return list({"StudyDependency"}) end
local doorOpen = false
local door = { getObjectName = function() return "IsoDoor" end,
    getSprite = function() return { getName = function() return "fixture-door" end } end,
    IsOpen = function() return doorOpen end, getNorth = function() return true end }
instanceof = function(value, name) return value == door and name == "IsoDoor" end
local square = { getObjects = function() return list({door}) end,
    isOutside = function() return true end, isSolid = function() return false end,
    isSolidTrans = function() return false end, TreatAsSolidFloor = function() return true end,
    getFloor = function() return nil end }
getCell = function() return { getGridSquare = function(self, x, y, z)
    local w = Config.observation.windows[1]
    if x == w.x and y == w.y and z == w.z then return square end
    return nil
end } end
local people = { p1 = { id = "p1", x = 10, y = 20, z = 0, belief = "private", dead = false },
    p2 = { id = "p2", x = 30, y = 40, z = 0, dead = true } }
local body = { getX = function() return 11 end, getY = function() return 21 end,
    getZ = function() return 0 end }
SAO = { Identity = { all = function() return people end },
    Controller = { agents = { p1 = { state = "ROAM", stateSince = 4 } } },
    Perception = { beliefs = { p1 = { people = { acquaintance = { src = "observed" } } } } },
    Body = { get = function(id) return id == "p1" and body or nil end,
        hasRepresentation = function(id) return id == "p1" end },
    Organization = { processes = { m1 = { id = "m1", state = "open" } } } }
getFileWriter = function(name)
    assert(name:match("%.json$"), "native writer disallows extension")
    return { write = function(self, line)
        writes[#writes + 1] = { name = name, line = line }
        if not discardWrite then files[name] = line end
    end,
        close = function() end }
end
getFileReader = function(name)
    local read = false
    return { readLine = function()
        if read then return nil end
        read = true
        return files[name] and files[name]:sub(1, -2) or nil
    end, close = function() end }
end
function RunStudyChecks(Study)
    assert(Study.encode({ x = "abc" }, 11) == '{"x":"abc"}', "encoded byte accounting differs")
    assert(not pcall(function() Study.encode({ x = "abc" }, 10) end), "encoded byte limit ignored")
    assert(not pcall(function() Study.encode({ x = "\n\n" }, 12) end), "escaped byte limit ignored")
    assert(not Study.prepare() and values.seed == nil, "other-world isolation failed")
    currentMap = Config.mapName
    Events.OnPreMapLoad.fire()
    assert(worldgen.roads.small_road == nil, "unrequested native roads retained")
    Events.OnInitWorld.fire()
    Events.OnInitGlobalModData.fire(true)
    Events.OnNewGame.fire()
    Events.OnGameStart.fire()
    assert(Study.active, Study.error or "native lifecycle did not arm")
    assert(values.maxX == Config.extent.minCellX + Config.extent.cellsX - 1,
        "inclusive extent changed")
    local largeArray, largeMap = {}, {}
    for i = 1, 8192 do largeArray[i] = i; largeMap["key-" .. tostring(i)] = i end
    local largeText = Study.encode(largeArray)
    assert(largeText:sub(1, 5) == "[1,2," and largeText:sub(-5) == "8192]", "large array order changed")
    assert(#Study.encode(largeMap) > 8192, "large object keys lost")
    local before = Study.encode(people)
    local beliefsBefore = Study.encode(SAO.Perception.beliefs)
    local frame = Study.observe()
    assert(frame.coverage.loadedSquares == 1, "loaded square count differs")
    assert(frame.coverage.unavailableSquares == frame.coverage.requestedSquares - 1,
        "unloaded geometry was claimed observed")
    assert(frame.people[1].x == 11 and frame.people[1].positionSource == "native-body",
        "live position not from native body")
    assert(frame.people[2].positionSource == "durable-record", "dormant position mislabeled")
    assert(frame.population.total == 2 and frame.population.dead == 1, "population count differs")
    assert(frame.windows[1].squares[1].objects[1].open == false, "closed door not captured")
    doorOpen = true
    assert(Study.observe().windows[1].squares[1].objects[1].open == true, "native door change lost")
    assert(before == Study.encode(people), "observation mutated people")
    assert(beliefsBefore == Study.encode(SAO.Perception.beliefs), "observation mutated beliefs")
    assert(frame.people[1].context.controller.state == "ROAM", "controller state missing")
    assert(frame.people[1].context.beliefs.people.acquaintance.src == "observed", "private belief missing")
    assert(not frame.people[2].context.perceptionAvailable and not SAO.Perception.beliefs.p2,
        "observer opened missing beliefs")
    assert(frame.datasetAdmission == "unreviewed", "observation ratified itself")
    RESULT_FRAME = Study.encode(frame)
    Study.tick()
    Study.tick()
    assert(#writes == 1 and persisted.sequence == 1, "cadence duplicated frame")
    hour = hour + Config.observation.everyHours
    Study.tick()
    assert(#writes == 2 and persisted.sequence == 2, "elapsed frame missing")
    hour = hour + Config.observation.everyHours
    discardWrite = true
    assert(not pcall(Study.tick) and persisted.sequence == 2, "failed write acknowledged")
    discardWrite = false
    assert(writes[1].line:find('"schema":"sao%-study%-observation/1"'), "writer emitted invalid frame")
    local period = Config.observation.maxPeople
    Config.observation.maxPeople = 1
    assert(not Study.observe().coverage.peopleComplete, "truncated population claimed complete")
    Config.observation.maxPeople = period
    Events.OnPreMapLoad.fire()
    Events.OnInitWorld.fire()
    Events.OnInitGlobalModData.fire(false)
    Events.OnGameStart.fire()
    assert(Study.active and persisted.sequence == 2, "reopen lost observation sequence")
    values.maxX = values.maxX + 1
    assert(not pcall(Study.observe), "changed bounds accepted")
    Events.OnPreMapLoad.fire()
    Events.OnInitWorld.fire()
    persisted.definitionSha256 = "different"
    assert(not pcall(Study.start), "foreign save admitted")
    persisted = {}
    Events.OnNewGame.fire()
    assert(not pcall(Study.start), "unbound reopened save admitted")
    currentMap = "OtherMap"
    local prior = values.seed
    assert(not Study.prepare() and values.seed == prior, "later other-world isolation failed")
    currentMap = Config.mapName
    Events.OnGameStart.fire()
    assert(not Study.active and Study.error, "guarded late failure remained active")
    RESULT_FAILURE_LOG = table.concat(messages, "\n")
    return "PASS study runtime: isolation, native coverage, lifecycle, cadence, reload, review boundary"
end
