-- Week One bombardment enters the SAO world as a physical event. The
-- existing county supplies its people; this module never creates an actor.
-- Bandits Week One's BombDrop supplied this first impact idiom (CREDITS.md).
-- Flight paths, staged drops and aircraft remain a separate production slice.
SAO = SAO or {}
SAO.WeekOneEvents = SAO.WeekOneEvents or {}
local W = SAO.WeekOneEvents

local STORE = "SurvivorAwareness_WeekOneEvents"
local WEEK_HOURS = 168
local SCAN_LIMIT = 128
local CLUSTER_SIZE = 6
local MIN_CLUSTER = 5 -- BWOEvents.findBombSpot's observed target threshold.
local scanCursor = 0
local newWorldSignal = nil
local deferredCreator = nil

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function store()
    if not (ModData and ModData.getOrCreate) then return nil end
    local ok, row = pcall(ModData.getOrCreate, STORE)
    return ok and type(row) == "table" and row or nil
end

local function sameWorld(row)
    local ok, world, mode = pcall(function()
        local current = getWorld()
        return current:getWorld(), current:getGameMode()
    end)
    return ok and row.world == world and row.gameMode == mode
end

local function sourceActive()
    if not getActivatedMods then return nil end
    local ok, active = pcall(function()
        return getActivatedMods():contains("BanditsWeekOne")
    end)
    if not ok then return nil end
    return active == true
end

-- Installed BWO initializes this durable row under its singular key.
-- It remains in a save after the external mod is removed. Do not create it
-- during this read: an absent row is evidence for a native SAO-only start.
local function sourceFootprint()
    if not (ModData and ModData.get) then return nil end
    local ok, saved = pcall(ModData.get, "BanditWeekOne")
    if not ok then return nil end
    if type(saved) ~= "table" then return false end
    return type(saved.Variant) == "string" and saved.Variant ~= ""
        or type(saved.QueryCache) == "table"
            and type(saved.EventBuildings) == "table"
            and type(saved.PlaceEvents) == "table"
            and type(saved.Sandbox) == "table"
end

local function clocks()
    local ok, native, county = pcall(function()
        return GameTime.getInstance():getWorldAgeHours(),
            SAO.History.countyHours()
    end)
    if not ok or not finite(native) or native < 0
        or not finite(county) or county < 0 then return nil end
    return native, county
end

-- GlobalModData.init sends this native new-world flag after loading saved
-- tables and before OnGameStart. Only OnGameStart can commit an owner. A
-- reloaded old save without our row becomes terminal even on its first day.
function W.observeWorld(admit)
    -- Global ModData is not authoritative on a multiplayer client before
    -- the server's source footprint arrives. Leave this event unbound there.
    if isClient and isClient() then return nil end
    local row = store()
    if not row then return nil end
    if row.producer then return sameWorld(row) and row or nil end
    if admit ~= true or newWorldSignal == nil then return nil end
    local native, county = clocks()
    local active = sourceActive()
    local footprint = active == true and true or sourceFootprint()
    local ok, world, mode = pcall(function()
        local current = getWorld()
        return current:getWorld(), current:getGameMode()
    end)
    if not ok or type(world) ~= "string" or world == ""
        or type(mode) ~= "string" or mode == ""
        or not native or active == nil or footprint == nil then return nil end
    row.schema = "sao-week-one-events/1"
    row.world, row.gameMode = world, mode
    row.firstObservedNativeHours = native
    row.firstObservedCountyHours = county
    row.nativeNewWorld = newWorldSignal
    row.closeNativeHours = WEEK_HOURS
    row.closeCountyHours = WEEK_HOURS
    row.producer = (active or footprint) and "BanditsWeekOne"
        or (newWorldSignal == true and native < WEEK_HOURS
            and county < WEEK_HOURS and "SAO" or "none")
    row.sourceEvidence = active and "active-mod"
        or (footprint and "saved-moddata" or nil)
    row.status = row.producer == "SAO" and "watching"
        or (row.producer == "BanditsWeekOne" and "source-owned" or "expired")
    return row
end

-- A fresh confirmed creator result can strengthen the first-observed
-- binding. An older player receipt alone cannot select an event producer.
function W.bindCreatedWorld(receipt, pending)
    if type(pending) ~= "table" or pending.transitioned ~= true
        or type(pending.context) ~= "table"
        or pending.context.newWorld ~= true
        or type(pending.draft) ~= "table"
        or pending.draft.confirmed ~= true
        or type(receipt) ~= "table" or receipt.schema ~= "sao-created-player/1"
        or receipt.newWorld ~= true or type(receipt.world) ~= "string"
        or receipt.world == "" or type(receipt.gameMode) ~= "string"
        or receipt.gameMode == "" or type(receipt.decisionId) ~= "string"
        or type(receipt.characterId) ~= "string"
        or not receipt.characterId:match("^sao%-player%-%d+$")
        or not finite(receipt.appliedAtHours)
        or receipt.appliedAtHours < 0 or not sameWorld(receipt)
        or pending.context.world ~= receipt.world
        or pending.context.gameMode ~= receipt.gameMode then
        return false, "creator-receipt-invalid"
    end
    local active = sourceActive()
    if active == nil then return false, "source-activation-unavailable" end
    local row = store()
    if not row then return false, "world-store-unavailable" end
    if not row.producer then
        deferredCreator = {receipt = receipt, pending = pending}
        return false, "world-producer-pending"
    end
    if not sameWorld(row) then return false, "world-changed" end
    if row.producer ~= (active and "BanditsWeekOne" or "SAO") then
        return false, "world-producer-already-bound"
    end
    if row.decisionId and row.decisionId ~= receipt.decisionId then
        return false, "world-creator-already-bound"
    end
    row.decisionId = receipt.decisionId
    row.characterId = receipt.characterId
    row.boundAtHours = receipt.appliedAtHours
    return true, "bound"
end

function W.installCreatorBinding()
    if not SAO.Creator and type(require) == "function" then
        pcall(require, "SAO_PlayerCreator")
    end
    local creator = SAO.Creator
    if not creator or type(creator.onCreatePlayer) ~= "function" then
        return false end
    if creator.onCreatePlayer == W.creatorWrapper then return true end
    local prior = creator.onCreatePlayer
    local wrapped = function(...)
        local pending = creator.pending
        local accepted, receipt = prior(...)
        if accepted == true and type(receipt) == "table"
            and type(pending) == "table" and pending.transitioned == true
            and type(pending.context) == "table"
            and pending.context.newWorld == true
            and type(pending.draft) == "table"
            and pending.draft.confirmed == true then
            W.bindCreatedWorld(receipt, pending)
        end
        return accepted, receipt
    end
    W.creatorWrapper = wrapped
    creator.onCreatePlayer = wrapped
    return true
end

local function enabled(row)
    local options = SandboxVars and SandboxVars.BanditsWeekOne
    return row and row.producer == "SAO" and sameWorld(row)
        and sourceActive() == false
        and type(options) == "table" and options.EventBombing == true
end

-- The county's public chronicle supplies the event pressure. A saved draw
-- decides whether an external impact opportunity exists at all. This fact
-- does not attribute an aircraft or tell an NPC anything they cannot sense.
local function decideOpportunity(row, native, county)
    if row.opportunity then return row.opportunity.selected == true end
    if not (SAO.Standing and SAO.Standing.chronicle
        and SAO.Rand and SAO.Rand.int) then return false end
    local heard, chronicle = pcall(SAO.Standing.chronicle)
    if not heard or type(chronicle) ~= "table" then return false end
    local evidence = {}
    for _, field in ipairs({"outbreakAtHours", "firstTurnedAtHours",
        "tapsDryAtHours"}) do
        local stamp = chronicle[field]
        if finite(stamp) and stamp >= 0 and stamp <= county then
            evidence[#evidence + 1] = field
        end
    end
    if #evidence == 0 then return false end
    local got, roll = pcall(SAO.Rand.int, 0, 100)
    if not got or not finite(roll) or roll < 0 or roll >= 100
        or roll ~= math.floor(roll) then return false end
    local threshold = #evidence * 25
    local selected = roll < threshold
    row.opportunity = {basis = "SAO.Standing.chronicle",
        evidence = evidence, thresholdPercent = threshold, draw = roll,
        selected = selected, atNativeHours = native,
        atCountyHours = county}
    if not selected then row.status = "not-selected" end
    return selected
end

-- The saved first-week opportunity uses the native and county clocks. It
-- does not import variant-specific timetables or schedule a specific target.
function W.onDay(day)
    local row = W.observeWorld()
    if not row or row.producer ~= "SAO"
        or row.status ~= "watching" then return false end
    if sourceActive() == true or sourceFootprint() == true then
        row.status = "source-overlap"
        return false
    end
    local native, county = clocks()
    if not native or not finite(day)
        or math.floor(county / 24) ~= day then return false end
    if native >= row.closeNativeHours
        or county >= row.closeCountyHours then
        row.status = "expired"
        return false
    end
    return enabled(row) and decideOpportunity(row, native, county)
end

local function loadedCluster()
    if not getCell then return nil, 0 end
    local ok, cell, list, count = pcall(function()
        local current = getCell()
        local zombies = current and current:getZombieList()
        return current, zombies, zombies and zombies:size() or 0
    end)
    if not ok or not cell or not list or not finite(count)
        or count < 1 then return nil, 0 end
    local visited = math.min(count, SCAN_LIMIT)
    local bins = {}
    for step = 0, visited - 1 do
        local index = (scanCursor + step) % count
        local got, x, y, z, square, alive = pcall(function()
            local zombie = list:get(index)
            if not zombie then return nil end
            return zombie:getX(), zombie:getY(), zombie:getZ(),
                zombie:getCurrentSquare(), zombie:isAlive()
        end)
        if got and alive == true and finite(x) and finite(y)
            and z == 0 and square then
            local usable, outside = pcall(function()
                return square:getChunk() ~= nil and square:isOutside()
            end)
            if usable and outside == true then
                local bx, by = math.floor(x / CLUSTER_SIZE),
                    math.floor(y / CLUSTER_SIZE)
                local key = tostring(bx) .. ":" .. tostring(by)
                local bin = bins[key]
                if not bin then
                    bin = { count = 0, square = square, key = key }
                    bins[key] = bin
                end
                bin.count = bin.count + 1
            end
        end
    end
    scanCursor = (scanCursor + visited) % count
    local best
    for _, bin in pairs(bins) do
        if bin.count >= MIN_CLUSTER and (not best
            or bin.count > best.count
            or bin.count == best.count and bin.key < best.key) then
            best = bin
        end
    end
    W.lastScan = { visited = visited, available = count,
        candidateCount = best and best.count or 0 }
    return best and best.square or nil, best and best.count or 0
end

-- The engine trap supplies physical damage and WorldSound to everyone in
-- range. Existing SAO people may hear, be injured, move or ignore it through
-- their ordinary perception, needs, decisions and body ownership paths.
function W.pollLoadedImpact()
    local row = W.observeWorld()
    if not row or row.status ~= "watching" then return false end
    if sourceActive() == true or sourceFootprint() == true then
        row.status = "source-overlap"
        return false
    end
    local native, county = clocks()
    if not native then return false end
    if native >= row.closeNativeHours
        or county >= row.closeCountyHours then
        row.status = "expired"
        return false
    end
    if not enabled(row) or not decideOpportunity(row, native, county) then
        return false end
    local square, density = loadedCluster()
    if not square then return false end
    local ready, cell, item, trap = pcall(function()
        local current = getCell()
        local bomb = instanceItem("Base.PipeBomb")
        if not bomb then return nil end
        bomb:setExplosionPower(10)
        bomb:setTriggerExplosionTimer(0)
        bomb:setAttackTargetSquare(square)
        return current, bomb, IsoTrap.new(bomb, current, square)
    end)
    if not ready or not cell or not item or not trap then return false end
    local position, x, y, z = pcall(function()
        return square:getX(), square:getY(), square:getZ()
    end)
    if not position or not finite(x) or not finite(y) or z ~= 0 then
        return false end
    row.impact = {x = x, y = y, z = z, atCountyHours = county,
        atNativeHours = native,
        sampledZombies = density,
        source = "BanditsWeekOne/BWOEvents.BombDrop",
        physical = "IsoTrap.triggerExplosion"}
    -- Do not repeat an explosion if the native call partially succeeds and
    -- then throws, or a routine reload sees a dispatch in progress.
    row.status = "dispatching"
    local fired = pcall(function() trap:triggerExplosion(false) end)
    row.status = fired and "completed" or "indeterminate"
    return fired
end

function W.rebindWorld(isNewWorld)
    scanCursor = 0
    W.lastScan = nil
    deferredCreator = nil
    if type(isNewWorld) == "boolean" then
        newWorldSignal = isNewWorld
    else
        newWorldSignal = nil
    end
end

if Events then
    if Events.OnInitGlobalModData then
        if W.onWorldData and Events.OnInitGlobalModData.Remove then
            Events.OnInitGlobalModData.Remove(W.onWorldData)
        end
        W.onWorldData = W.rebindWorld
        Events.OnInitGlobalModData.Add(W.onWorldData)
    end
    if Events.OnGameStart then
        if W.onStart and Events.OnGameStart.Remove then
            Events.OnGameStart.Remove(W.onStart)
        end
        W.onStart = function()
            W.installCreatorBinding()
            W.observeWorld(true)
            if deferredCreator then
                local held = deferredCreator
                deferredCreator = nil
                W.bindCreatedWorld(held.receipt, held.pending)
            end
        end
        Events.OnGameStart.Add(W.onStart)
    end
end
W.installCreatorBinding()
return W
