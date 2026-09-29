-- Controlled receipt attribution, executed in the installed Kahlua VM.
local messages, dead, hours, exited = {}, false, 2, false
local focusLossPaused, debugForceLaunch, worldMode, copiedMods = nil, nil, nil, nil
function print(message) messages[#messages + 1] = message end
function require() end
local function event()
    local callbacks = {}
    return {
        Add = function(callback) callbacks[#callbacks + 1] = callback end,
        fire = function(value) for _, callback in ipairs(callbacks) do callback(value) end end,
    }
end
Events = {}
for _, name in ipairs({ "OnGameBoot", "OnMainMenuEnter", "OnNewGame", "OnPlayerDeath", "OnGameStart", "OnTick", "OnTickEvenPaused" }) do
    Events[name] = event()
end
local character = {
    isDead = function() return dead end, getHealth = function() return dead and 0 or 1 end,
    getX = function() return 128 end, getY = function() return 129 end, getZ = function() return 0 end,
}
local unrelated = {
    isDead = function() return false end, getHealth = function() return 1 end,
    getX = function() return 999 end, getY = function() return 999 end, getZ = function() return 0 end,
}
local slot = character
function getSpecificPlayer(index) assert(index == 0); return slot end
function getPlayer() return unrelated end
local world = {
    getWorld = function() return "fixture" end,
    setGameMode = function(_, value) worldMode = value end,
}
function getWorld() return world end
function getGameTime() return { getWorldAgeHours = function() return hours end } end
local core = {
    quitToDesktop = function() exited = true end,
    setOptionPauseOnFocusloss = function(_, value) focusLossPaused = value end,
}
function getCore() return core end
function getDebugOptions()
    return { setBoolean = function(_, key, value)
        if key == "DebugScenario.ForceLaunch" then debugForceLaunch = value end
    end }
end
local mods = {
    currentGame = { copyFrom = function(_, value) copiedMods = value end },
    isolatedStudy = { id = "isolatedStudy" },
}
ActiveMods = { getById = function(id) return mods[id] end }
function CheckLaunchConfiguration()
    Events.OnGameBoot.fire()
    assert(debugScenarios.NativeStudy and debugScenarios.NativeStudy.forceLaunch,
        "native study scenario was not configured")
    assert(debugForceLaunch == true and focusLossPaused == false,
        "current engine launch options were not applied")
    debugScenarios.NativeStudy.setSandbox()
    assert(copiedMods == mods.isolatedStudy and worldMode == "Sandbox",
        "sealed study cohort was not retained for the save")
    return "PASS current engine study launch and sealed mod cohort"
end
function CheckLaunchReceipts()
    Events.OnNewGame.fire(character)
    Events.OnGameStart.fire()
    Events.OnPlayerDeath.fire(unrelated)
    dead = true
    Events.OnPlayerDeath.fire(character)
    slot = nil -- Native removal does not change the person being reported.
    hours = 2.31
    Events.OnTick.fire()
    local all = table.concat(messages, "\n")
    assert(exited, "normal native exit was not requested")
    assert(not all:find("x=999", 1, true), "receipt switched to another body")
    assert(all:find("event=horizon attempt=1 save=fixture hours=2.31 dead=true health=0 x=128", 1, true),
        "horizon lost the original character")
    local _, deaths = all:gsub("event=death", "")
    assert(deaths == 1, "unrelated character death was attributed to the launch slot")
    return "PASS launch receipts retain the original character through death and global-player changes"
end
function CheckLaunchWallLimit(paused)
    local timestamp = 1000
    RunConfig.watch = true
    RunConfig.wallDeadlineUnixMs = 2000
    function getTimestampMs() return timestamp end
    Events.OnGameStart.fire()
    Events.OnTick.fire()
    assert(not exited, "watch ended before its wall limit")
    timestamp = 2000
    local event = paused and Events.OnTickEvenPaused or Events.OnTick
    event.fire()
    event.fire()
    assert(exited, "watch escaped its wall limit")
    local all = table.concat(messages, "\n")
    local _, stops = all:gsub("wall%-limit attempt=1 save=fixture start=2 end=2", "")
    assert(stops == 1, "wall limit was not attributed exactly once at unchanged world time")
    return "PASS native launcher wall limit running and paused"
end
