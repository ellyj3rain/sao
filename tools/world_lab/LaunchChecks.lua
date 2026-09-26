-- Controlled receipt attribution, executed in the installed Kahlua VM.
local messages, dead, hours, exited = {}, false, 2, false
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
for _, name in ipairs({ "OnGameBoot", "OnMainMenuEnter", "OnNewGame", "OnPlayerDeath", "OnGameStart", "OnTick" }) do
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
function getWorld() return { getWorld = function() return "fixture" end } end
function getGameTime() return { getWorldAgeHours = function() return hours end } end
function getCore() return { quitToDesktop = function() exited = true end } end
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
