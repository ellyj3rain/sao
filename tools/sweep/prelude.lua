-- What the engine gives the mod, for a county run outside the game.
--
-- Every global here is one the engine defines and the mod calls. None
-- of them decides anything about the county: they answer the questions
-- the shipped code asks of its host, and the county's own modules do
-- the rest. Where a stub would have to CHOOSE, it does not exist -
-- the sweep loads the real module instead.
--
-- Two of these were absent once and each invalidated a whole set of
-- conclusions before anyone noticed:
--
--   `SpawnRegionMgr` (served from the map's own spawnpoints.lua, see
--   world.py). Without it `loadRegionPoints` returns nil, genesis is
--   deferred forever, and every county measured is one with genesis
--   switched off - reported as if it were a county.
--
--   `mergeTable`, which the map files call. It is a Java-side global,
--   not Lua source, so nothing in the tree defines it.

SAO = SAO or {}
_G.__hours = 0
_G.__md = {}
_G.__out = {}

ModData = {
    getOrCreate = function(k)
        __md[k] = __md[k] or {}
        return __md[k]
    end,
}

GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return _G.__hours end,
    getStartYear = function() return 1996 end,
    getStartMonth = function() return 6 end,
    getStartDay = function() return 8 end,
    getMonth = function() return 6 end,
    getDay = function() return 8 end,
    getYear = function() return 1996 end,
    getTimeOfDay = function() return 12.0 end,
    -- Arrivals wait for the sky to go quiet: no newcomer walks in
    -- while the helicopter is still overhead. Nights survived is the
    -- county's own day, so a span passes that point on its seventh
    -- simulated day and arrivals become possible after it.
    getHelicopterDay = function() return 7 end,
    getNightsSurvived = function()
        return math.floor((_G.__hours or 0) / 24)
    end,
    getCalender = function() return {
        getTimeInMillis = function() return 8640000000 end } end,
} end }
getGameTime = function() return GameTime.getInstance() end
getTimestampMs = function() _G.__ms = (_G.__ms or 0) + 1 return _G.__ms end

-- The engine's own draw, reached only where the county has no save to
-- seed from ([C66]). Constant on purpose: if a sweep result ever moves
-- because of this, something is drawing outside SAO.Rand.
ZombRand = function(a, b) if b == nil then return 0 end return a end

getSpecificPlayer = function() return nil end
getSandboxOptions = function()
    return { getWaterShutModifier = function() return 30 end }
end
getScriptManager = function() return { getItem = function() return nil end } end

-- Concatenates lists. The shipped spawnpoints.lua files call it.
mergeTable = function(...)
    local out = {}
    for _, t in ipairs({...}) do
        if type(t) == "table" then
            for _, v in ipairs(t) do out[#out + 1] = v end
        end
    end
    return out
end

getFileWriter = function()
    return {
        write = function(self, l) _G.__out[#_G.__out + 1] = l end,
        close = function() end,
    }
end

-- The tick handler the mod registers is captured rather than replaced,
-- so the sweep drives the county's REAL cadence and the mod needs no
-- test hook of its own.
Events = setmetatable({}, { __index = function(t, k)
    local slot = {
        Add = function(fn)
            _G.__handlers = _G.__handlers or {}
            _G.__handlers[k] = fn
        end,
        Remove = function() end,
    }
    rawset(t, k, slot)
    return slot
end })

SandboxVars = {
    SurvivorAwareness = {
        Enable = true, Telemetry = true,
        PopulationGoverned = false, Population = 216,
        NewcomersGoverned = false, Newcomers = 500,
        RoadTraffic = 2, RefillDays = 2.0, Desperation = 0.7,
        TrustToCompany = 0.5, DormantRisk = 1.0, DayZero = false,
        MaterializeRadius = 45, HibernateRadius = 70,
    },
    ZombieLore = { Transmission = 1 },
}

-- Nobody is materialised: a sweep is the dormant county, which is the
-- half that runs when the player is not looking and the half nearly
-- every death happens in.
SAO.Body = { active = {}, get = function() return nil end }

_G.__owed = 1096

-- [C86] The real bridge, when the harness exposed one (LuaRun's
-- --engine mode). The stub below answers what only the harness can
-- know - the county clock, the survey's claim - and forwards to the
-- engine everything the engine owns: the name pools, the profession
-- boosts, the profession list the catalog grows from.
--
-- With no bridge behind it - a border run, or a county that did not
-- ask for engine data - the forwards answer nil and the shipped code
-- keeps its own sentinels, exactly as it did before this existed.
-- Those callers are pcall-wrapped and type-check what comes back, so
-- nil is the missing answer, not a crash; and the county draw is
-- taken only after a count comes back, so a nil here consumes no
-- draw and a plain run's sequence is unchanged.
local __engineBridge = SAOJavaBridge

local function __forward(method)
    return function(self, ...)
        if not __engineBridge then return nil end
        local fn = __engineBridge[method]
        if not fn then return nil end
        return fn(__engineBridge, ...)
    end
end

SAOJavaBridge = {
    daysBehindAtStart = function(self, asked) return _G.__owed end,
    recordDayToday = function(self) return _G.__owed end,
    countyMonth = function(self, hours, asked)
        return math.floor((math.floor(hours / 24) % 365) / 30.4) % 12
    end,
    surveyClaim = function(self, a, b, c, d, e)
        return "ways=6 boarded=0 rooms=4"
    end,
    listKnoxHumans = function() return "" end,
    isCombatPatchReady = function() return false end,
    forenameCount = __forward("forenameCount"),
    forenameAt = __forward("forenameAt"),
    surnameCount = __forward("surnameCount"),
    surnameAt = __forward("surnameAt"),
    professionBoost = __forward("professionBoost"),
    listProfessions = __forward("listProfessions"),
}

-- [C87] The plain reading of an engine name, for the display layer.
-- The engine stores a person's name as its own translation key
-- (`SurvivorName_Elliot`) and its own English rendering of that key is
-- the key's own suffix - every entry of the engine's SurvivorNames
-- table answers exactly that, measured entry for entry. A row reads
-- the plain form; the key stays beside it, because the key is what
-- the engine itself holds in play. A name that is not a key - the
-- plain county's sentinels - reads as itself, unchanged.
plainNameOf = function(forename, surname)
    if type(forename) ~= "string" or type(surname) ~= "string" then
        return nil
    end
    local f = forename:gsub("^SurvivorName_", "")
    local s = surname:gsub("^SurvivorSurname_", "")
    return f .. " " .. s
end
