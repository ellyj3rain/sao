-- Native bodies, items, item definitions, world clock and serializers come from
-- the Java probe. Only offline networking, UI and event dispatch are fixtures.
print = __print
require = function() end
function event()
    local callbacks = {}
    return { Add = function(f) callbacks[#callbacks + 1] = f end,
        Remove = function(f) for i = #callbacks, 1, -1 do
            if callbacks[i] == f then table.remove(callbacks, i) end end end,
        fire = function(...) for _, f in ipairs(callbacks) do f(...) end end,
        count = function() return #callbacks end,
        at = function(i) return callbacks[i] end }
end
Events = { EveryOneMinute = event(), OnGameStart = event(), OnCreatePlayer = event(),
    OnPlayerUpdate = event(), OnServerCommand = event(), OnClientCommand = event(),
    OnRefreshInventoryWindowContainers = event(), OnFillInventoryObjectContextMenu = event() }
isClient = function() return __client == true end
isServer = function() return __server == true end
getSpecificPlayer = __slot
getNumActivePlayers = function() return 1 end
getTimestampMs = function() return 10000 end
getCell = function() return nil end -- no nearby-world/UI sweep in this carried-inventory proof
getWorld = __world
getClimateManager = function() return nil end -- installed default temperature, 20 C
getPlayerLoot = function() return nil end
getPlayerInventory = function() return nil end
getTextOrNull = function() return nil end
getText = function(s) return s end
instanceof = __instanceof
ZombRand = __random
sendItemStats = function() end
syncItemModData = function() end
syncItemFields = function() end
sendAddItemToContainer = function() end
sendRemoveItemFromContainer = function() end
SandboxVars = { FoodRotSpeed = 3, FridgeFactor = 3,
    TienCoolers = { ReworkedIce = false, RenameCoolers = true } }
SAO = { Body = { active = {}, foreign = {}, unloaded = {} }, Identity = {} }
local records = {}
SAO.Identity.get = function(id) return records[tostring(id)] end
function replaceRecord(id, rec) records[tostring(id)] = rec end
SAO.Body.get = function(id)
    id = tostring(id)
    if __transition == id then return nil end
    return SAO.Body.active[id] or SAO.Body.foreign[id]
end
function register(id, body, foreign)
    records[id] = { id = id }
    if foreign then
        records[id].bodyOwner = "ZAO" records[id].bodyOwnerToken = "foreign-token"
        body:getModData().SAOExternalOwner = "ZAO"
        body:getModData().SAOExternalToken = "foreign-token"
        SAO.Body.foreign[id] = body
    else SAO.Body.active[id] = body end
    return records[id]
end
register("cool-a", __a.body, false)
register("cool-b", __b.body, true)
register("player", __p.body, false)
__count = 0
function check(name, passed)
    print("CHECK " .. name .. "=" .. tostring(passed == true))
    if passed ~= true then error(name) end
    __count = __count + 1
end
function near(a, b) return type(a) == "number" and math.abs(a - b) < 0.000001 end
function plain(value, seen)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return true end
    if kind == "number" then return value == value and math.abs(value) ~= math.huge end
    if kind ~= "table" or getmetatable(value) ~= nil then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for k, v in pairs(value) do if not plain(k, seen) or not plain(v, seen) then return false end end
    seen[value] = nil
    return true
end
