-- Actual SAO_WeekOneEvents.lua loads after these engine-port fixtures.
local state = {}
local worldName, mode = "Impact Test", "Sandbox"
local nativeAge, countyAge = 0, 0
local sourceInstalled = false
local sourceSaved, multiplayerClient = nil, false
local playerHours = 0
local chronicle, drawValue, drawCalls = {}, 0, 0
local zombies, inspected = {}, 0
local explosions, trapBuilds, throwTrigger = 0, 0, false
local receipt = {schema = "sao-created-player/1", newWorld = true,
    decisionId = "Impact Test|Sandbox|1", world = "Impact Test",
    gameMode = "Sandbox", characterId = "sao-player-1",
    appliedAtHours = 0}

SAO = {History = {countyHours = function() return countyAge end},
    Standing = {chronicle = function() return chronicle end},
    Rand = {int = function(low, high)
        if low ~= 0 or high ~= 100 then error("unexpected draw bounds") end
        drawCalls = drawCalls + 1
        return drawValue
    end},
    Creator = {onCreatePlayer = function()
        if not SAO.Creator.pending then return true, "already-applied" end
        SAO.Creator.pending = nil
        return true, receipt
    end}}
SandboxVars = {BanditsWeekOne = {EventBombing = true}}
ModData = {getOrCreate = function(key)
    if key ~= "SurvivorAwareness_WeekOneEvents" then
        error("event created an unrelated ModData row")
    end
    return state
end,
    get = function(key)
        if key ~= "BanditWeekOne" then error("unexpected ModData read") end
        return sourceSaved
    end}
GameTime = {getInstance = function()
    return {getWorldAgeHours = function() return nativeAge end}
end}
Events = {
    OnInitGlobalModData = {Add = function(fn)
        Events.OnInitGlobalModData.callback = fn
    end},
    OnGameStart = {Add = function(fn)
        Events.OnGameStart.callback = fn
    end},
}
function getWorld()
    return {getWorld = function() return worldName end,
        getGameMode = function() return mode end}
end
function getActivatedMods()
    return {contains = function(_, id)
        return id == "BanditsWeekOne" and sourceInstalled
    end}
end
function isClient() return multiplayerClient end
local nativePlayer = {getHoursSurvived = function() return playerHours end}
function getSpecificPlayer(index)
    if index ~= 0 then error("unexpected player slot") end
    return nativePlayer
end
local list = {size = function() return #zombies end,
    get = function(_, index)
        inspected = inspected + 1
        return zombies[index + 1]
    end}
local cell = {getZombieList = function() return list end}
function getCell() return cell end
function instanceItem(id)
    if id ~= "Base.PipeBomb" then error("unexpected item") end
    return {setExplosionPower = function(_, power)
            if power ~= 10 then error("unexpected power") end
        end,
        setTriggerExplosionTimer = function(_, timer)
            if timer ~= 0 then error("unexpected timer") end
        end,
        setAttackTargetSquare = function(_, square)
            if not square then error("missing target square") end
        end}
end
IsoTrap = {new = function(_, selectedCell, square)
    if selectedCell ~= cell or not square then error("invalid trap port") end
    trapBuilds = trapBuilds + 1
    return {triggerExplosion = function(_, force)
        if force ~= false then error("unexpected trigger mode") end
        explosions = explosions + 1
        if throwTrigger then error("post-effect native failure") end
    end}
end}

local function addZombie(x, y, alive, outside, loaded)
    local square = {getX = function() return x end,
        getY = function() return y end,
        getZ = function() return 0 end,
        isOutside = function() return outside ~= false end,
        getChunk = function()
            return loaded ~= false and {} or nil
        end}
    zombies[#zombies + 1] = {getX = function() return x end,
        getY = function() return y end,
        getZ = function() return 0 end,
        getCurrentSquare = function() return square end,
        isAlive = function() return alive ~= false end}
end

local failed, total = {}, 0
local function check(name, condition)
    total = total + 1
    if condition then print("PASS " .. name)
    else
        failed[#failed + 1] = name
        print("FAIL " .. name)
    end
end
local function reset(signal)
    state = {}
    worldName, mode = "Impact Test", "Sandbox"
    nativeAge, countyAge = 0, 0
    sourceInstalled = false
    sourceSaved, multiplayerClient = nil, false
    playerHours = 0
    chronicle, drawValue, drawCalls = {}, 0, 0
    SandboxVars.BanditsWeekOne.EventBombing = true
    zombies, inspected = {}, 0
    explosions, trapBuilds, throwTrigger = 0, 0, false
    SAO.Creator.pending = nil
    if signal == "missing" then Events.OnInitGlobalModData.callback()
    else Events.OnInitGlobalModData.callback(signal ~= false) end
end
local function cluster(n)
    for i = 1, n do addZombie(60 + i / 10, 60 + i / 10) end
end

function fixtureCases()
    local W = SAO.WeekOneEvents
    reset()
    nativeAge, countyAge = 2, 2
    Events.OnGameStart.callback()
    check("on-game-start/native-age-two-fresh-world-observation",
        state.producer == "SAO" and state.status == "watching"
            and state.firstObservedNativeHours == 2)
    check("native-start/binds-without-creator",
        W.onDay(0) == false and state.producer == "SAO"
            and state.status == "watching"
            and state.firstObservedNativeHours == 2)
    check("no-county-evidence/no-actor-or-impact",
        W.pollLoadedImpact() == false and explosions == 0
            and state.impact == nil and state.opportunity == nil
            and drawCalls == 0)
    chronicle = {outbreakAtHours = 0}
    cluster(4)
    check("low-density/no-strike", W.pollLoadedImpact() == false
        and explosions == 0 and W.lastScan
        and W.lastScan.candidateCount == 0
        and state.opportunity and state.opportunity.selected == true
        and drawCalls == 1)
    cluster(1)
    check("loaded-density/one-physical-impact",
        W.pollLoadedImpact() == true and explosions == 1
            and trapBuilds == 1 and state.status == "completed"
            and state.impact.sampledZombies == 5
            and state.impact.x >= 60 and state.impact.z == 0
            and drawCalls == 1)
    check("reload/terminal-impact-not-repeated",
        W.onWorldData(false) == nil and W.onStart() == nil
            and W.pollLoadedImpact() == false
            and explosions == 1)

    reset()
    nativeAge, countyAge = 2, 2
    W.onStart()
    W.onWorldData(false)
    nativeAge, countyAge = 40, 40
    W.onStart()
    chronicle = {outbreakAtHours = 30}
    cluster(5)
    check("reload-with-saved-owner/first-week-impact-remains-eligible",
        state.producer == "SAO" and state.nativeNewWorld == true
            and W.pollLoadedImpact() == true and explosions == 1)

    reset("missing")
    nativeAge, countyAge = 2, 2
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    W.onStart()
    check("missing-native-world-signal/fails-closed",
        state.producer == nil and W.onDay(0) == false
            and W.pollLoadedImpact() == false and explosions == 0)

    reset()
    nativeAge, countyAge = 2, 2
    check("before-on-game-start/no-owner-committed",
        W.onDay(0) == false and state.producer == nil)

    reset()
    nativeAge, countyAge = 192, 192
    cluster(5)
    W.onStart()
    check("midgame-first-seen/expires-without-retroactive-impact",
        W.onDay(8) == false and state.producer == "none"
            and state.status == "expired"
            and W.pollLoadedImpact() == false and explosions == 0)
    nativeAge, countyAge = 24, 24
    check("late-save-clock-rewind/does-not-reactivate",
        W.pollLoadedImpact() == false and explosions == 0)

    reset(false)
    nativeAge, countyAge = 24, 24
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    W.onStart()
    check("preexisting-midweek-save/no-new-owner",
        W.onDay(1) == false and state.producer == "none"
            and W.pollLoadedImpact() == false and explosions == 0)

    reset(false)
    nativeAge, countyAge, playerHours = 2, 2, 0.05
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    W.onStart()
    check("preexisting-first-day-player/no-new-owner",
        W.onDay(0) == false and state.producer == "none"
            and W.pollLoadedImpact() == false and explosions == 0)

    reset(false)
    nativeAge, countyAge, playerHours = 10, 10, 0
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    W.onStart()
    check("first-day-respawn/no-new-owner",
        W.onDay(0) == false and state.producer == "none"
            and W.pollLoadedImpact() == false and explosions == 0)

    reset()
    countyAge = 240
    cluster(5)
    W.onStart()
    check("mature-county-native-day-zero/no-retroactive-impact",
        W.onDay(10) == false and state.producer == "none"
            and W.pollLoadedImpact() == false and explosions == 0)

    reset()
    sourceInstalled = true
    cluster(5)
    W.onStart()
    check("source-active/source-owned-no-duplicate",
        W.onDay(0) == false and state.producer == "BanditsWeekOne"
            and state.status == "source-owned"
            and W.pollLoadedImpact() == false and explosions == 0)
    sourceInstalled = false
    check("source-uninstalled/source-ownership-persists",
        W.pollLoadedImpact() == false and explosions == 0)

    reset(false)
    sourceSaved = {Variant = "original", QueryCache = {},
        EventBuildings = {}, PlaceEvents = {}, Sandbox = {}}
    cluster(5)
    chronicle = {outbreakAtHours = 0}
    W.onStart()
    check("saved-bwo-then-uninstalled/source-ownership-preserved",
        W.onDay(0) == false and state.producer == "BanditsWeekOne"
            and state.sourceEvidence == "saved-moddata"
            and W.pollLoadedImpact() == false and explosions == 0)

    reset(false)
    sourceSaved = {QueryCache = {}, EventBuildings = {},
        PlaceEvents = {}, Sandbox = {}}
    W.onStart()
    check("saved-bwo-initialized-without-variant/source-owned",
        W.onDay(0) == false and state.producer == "BanditsWeekOne"
            and state.sourceEvidence == "saved-moddata")

    reset()
    sourceSaved = {unrelated = true}
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    W.onStart()
    check("unrelated-row/native-start-remains-eligible",
        W.onDay(0) == true and state.producer == "SAO"
            and W.pollLoadedImpact() == true and explosions == 1)

    reset()
    multiplayerClient = true
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    W.onStart()
    check("client-source-state-unavailable/no-local-admission",
        W.onDay(0) == false and state.producer == nil
            and W.pollLoadedImpact() == false and explosions == 0)

    reset()
    cluster(5)
    chronicle = {outbreakAtHours = 0}
    SandboxVars.BanditsWeekOne.EventBombing = false
    W.onStart()
    check("bombing-option-off/no-impact",
        W.onDay(0) == false and state.producer == "SAO"
            and W.pollLoadedImpact() == false and explosions == 0
            and drawCalls == 0)
    SandboxVars.BanditsWeekOne.EventBombing = true
    check("bombing-option-on/own-physical-effect",
        W.pollLoadedImpact() == true and explosions == 1)

    reset()
    chronicle = {outbreakAtHours = 0}
    W.onStart()
    W.onDay(0)
    sourceInstalled = true
    cluster(5)
    check("source-added-to-sao-world/terminal-overlap",
        W.pollLoadedImpact() == false and state.status == "source-overlap"
            and explosions == 0)
    sourceInstalled = false
    check("source-overlap-removal/no-resumed-impact",
        W.pollLoadedImpact() == false and explosions == 0)

    reset()
    W.onStart()
    nativeAge, countyAge = 167, 167
    cluster(5)
    chronicle = {firstTurnedAtHours = 100}
    check("last-first-week-hour/eligible",
        W.onDay(6) == true and W.pollLoadedImpact() == true
            and explosions == 1)
    reset()
    nativeAge, countyAge = 168, 168
    cluster(5)
    W.onStart()
    check("first-week-boundary/expires",
        W.onDay(7) == false and state.producer == "none"
            and W.pollLoadedImpact() == false and explosions == 0)

    reset()
    nativeAge, countyAge = 168, 100
    cluster(5)
    W.onStart()
    check("native-week-boundary/county-still-first-week",
        state.producer == "none" and W.pollLoadedImpact() == false
            and explosions == 0)

    reset()
    W.onStart()
    W.onDay(0)
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    worldName = "Other World"
    check("save-world-binding/refuses-foreign-world",
        W.pollLoadedImpact() == false and explosions == 0)

    reset()
    W.onStart()
    W.onDay(0)
    chronicle = {outbreakAtHours = 0}
    cluster(5)
    throwTrigger = true
    check("native-throw/indeterminate-and-no-replay",
        W.pollLoadedImpact() == false and explosions == 1
            and state.status == "indeterminate"
            and W.pollLoadedImpact() == false and explosions == 1)

    reset()
    for i = 1, 256 do addZombie(1000 + i * 6, 60) end
    for i = 129, 133 do zombies[i] = zombies[129] end
    W.onStart()
    W.onDay(0)
    chronicle = {outbreakAtHours = 0}
    check("bounded-scan/first-pass-at-most-128",
        W.pollLoadedImpact() == false and inspected == 128
            and W.lastScan.visited == 128)
    check("bounded-scan/cursor-finds-later-loaded-pressure",
        W.pollLoadedImpact() == true and inspected == 256
            and explosions == 1)

    reset()
    chronicle = {outbreakAtHours = 0}
    drawValue = 99
    cluster(5)
    W.onStart()
    check("county-evidence/draw-can-refuse-impact",
        W.onDay(0) == false and state.opportunity.selected == false
            and state.status == "not-selected"
            and W.pollLoadedImpact() == false and explosions == 0
            and drawCalls == 1)
    chronicle.firstTurnedAtHours = 0
    drawValue = 0
    check("saved-negative-draw/no-later-reroll",
        W.pollLoadedImpact() == false and explosions == 0
            and drawCalls == 1)

    reset()
    local pending = {transitioned = true,
        context = {newWorld = true, world = "Impact Test",
            gameMode = "Sandbox"},
        draft = {confirmed = true}}
    SAO.Creator.pending = pending
    local created = SAO.Creator.onCreatePlayer(0, nativePlayer)
    local beforeStart = state.producer
    W.onStart()
    check("confirmed-creator/enriches-native-binding",
        created == true and beforeStart == nil
            and state.producer == "SAO"
            and state.decisionId == receipt.decisionId
            and state.characterId == receipt.characterId)
    reset(false)
    W.onStart()
    SAO.Creator.pending = pending
    SAO.Creator.onCreatePlayer(0, nativePlayer)
    check("creator-cannot-admit-saved-first-day-world",
        state.producer == "none" and state.decisionId == nil)
    reset("missing")
    check("old-creator-receipt/cannot-select-producer",
        W.bindCreatedWorld(receipt, nil) == false
            and state.producer == nil)

    check("suite", #failed == 0)
    return tostring(total) .. ":" .. table.concat(failed, ",")
end
