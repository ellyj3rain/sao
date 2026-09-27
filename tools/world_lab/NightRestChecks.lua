-- Executes the full Controller with controlled private memory/native geometry.
-- Native posture and recovery calls are observed here; rendered sleep is a
-- separate loaded-run check.
local failures, count = {}, 0
local function check(name, value)
    count = count + 1
    __nightStage = name
    if not value then failures[#failures + 1] = name end
end
local clock, hours, allowed, claim, present = 23, 23, true, false, 7
local cold, group, denyCurrent = 0, nil, false
local known = { [7] = { source = "lived", at = -1000, visits = 3 } }
local orders, sleeping, recovery = 0, false, 0
local rec = { id = "runner", homeX = 10, homeY = 10, homeZ = 0 }
local b = { x = 12, y = 10, z = 0, fatigue = .6 }
function b:getX() return self.x end
function b:getY() return self.y end
function b:getZ() return self.z end
function b:getCurrentSquare()
    return { getBuildingDef = function()
        return present and { getID = function() return present end } or nil
    end }
end
function b:setSitOnGround(value) self.seated = value end
GameTime = { getInstance = function() return {
    getTimeOfDay = function() return clock end, getHour = function() return clock end } end }
SAO.Places = { at = function(x) return { id = x == 20 and 8 or 7 } end }
SAO.Perception.knownPlaces = function() return known end
SAO.Perception.believedThreatCount = function() return 0 end
SAO.Standing.mayEnterBelieved = function(_, x, y)
    return allowed and not (denyCurrent and x == b.x and y == b.y)
end
SAO.Standing.insideClaim = function() return claim end
SAO.Standing.groupOf = function() return group end
SAO.Standing.leaderOf = function() return "leader" end
SAO.Standing.allPersonalClaims = function() return {} end
SAO.Standing.allGroupClaims = function() return {} end
SAO.Standing.claimOf = function() return nil end
SAO.Standing.onGroundOf = function() return nil end
SAO.Standing.fallHasCome = function() return true end
SAO.History.countyHours = function() return hours end
SAO.Identity = { get = function(id)
    if id == "leader" then return { id = id, homeX = 20, homeY = 20, homeZ = 0 } end
    return rec
end }
SAO.Body.get = function() return b end
SAO.Needs.cold = function() return cold end
SAO.Needs.read = function() return { fatigue = b.fatigue } end
SAO.Disposition.circle = function() return "loner" end
SAO.Disposition.roamRange = function() return 5 end
SAO.Gesture = { seat = function() end, standUp = function() end }
SAO.Locomotion = SAO.Locomotion or {}
SAO.Locomotion.order = function(_, _, x, y, z)
    orders = orders + 1
    check("route keeps the actual home", x == 10 and y == 10 and z == 0)
    return true
end
SAOJavaBridge.setShellAsleep = function(_, _, value) sleeping = value end
SAOJavaBridge.restRecoverTick = function(_, _, delta) recovery = recovery + delta end
local function agent() return { rec = rec, state = "IDLE" } end
local a = agent()
check("durable lived home admits rest", SAO.Controller.__nightProbe("runner", a, b, 100, rec) == true)
check("rest and sleep are actually requested", a.resting and a.sleeping and b.seated and sleeping)
hours = 24
SAO.Controller.__nightProbe("runner", a, b, 200, rec)
check("admitted sleep reaches recovery owner", recovery == 1)
check("memory was consumed without relearning", known[7].at == -1000 and known[7].visits == 3)
clock = 7
SAO.Controller.__nightProbe("runner", a, b, 300, rec)
check("morning wakes the same owner", not a.resting and not a.sleeping and not b.seated and not sleeping)
clock = 23
for _, case in ipairs({ { name = "outside", building = false, z = 0 },
    { name = "neighbor", building = 8, z = 0 }, { name = "other floor", building = 7, z = 1 } }) do
    present, b.z = case.building, case.z
    local before = orders
    local nextAgent = agent()
    local homeOk, homeResult = pcall(SAO.Controller.__homeProbe, "runner", nextAgent, b, 400, rec)
    check(case.name .. " inside ten tiles still routes home",
        homeOk and homeResult == true and orders == before + 1)
    check(case.name .. " does not manufacture rest",
        SAO.Controller.__nightProbe("runner", agent(), b, 400, rec) == false)
end
present, b.z = 7, 0
known = {}
check("unknown address grants no rest", SAO.Controller.__nightProbe("runner", agent(), b, 500, rec) == false)
local knowledgeCount = 0
for _ in pairs(known) do knowledgeCount = knowledgeCount + 1 end
check("home check grants no knowledge", knowledgeCount == 0)
known = { [7] = { source = "lived", at = -1000 } }
allowed = false
check("denied home grants no rest", SAO.Controller.__nightProbe("runner", agent(), b, 600, rec) == false)
check("no rest lets useful decisions continue", not SAO.Controller.__nightProbe("runner", agent(), b, 601, rec))
allowed, denyCurrent = true, true
check("occupied permission differs from address", not SAO.Controller.__nightProbe("runner", agent(), b, 610, rec))
local beforeDenied = orders
check("denied current tile still routes to permitted home",
    SAO.Controller.__homeProbe("runner", agent(), b, 611, rec) == true and orders == beforeDenied + 1)
denyCurrent = false
known = { ["7"] = { source = "lived", at = -1000 } }
check("persisted string building key admits rest", SAO.Controller.__nightProbe("runner", agent(), b, 620, rec) == true)
b.x = 40
local beforeLarge = orders
local largeOk = pcall(SAO.Controller.__homeProbe, "runner", agent(), b, 621, rec)
check("large occupied home supersedes distance", largeOk and orders == beforeLarge)
b.x, b.y, present, group = 21, 20, 8, "household"
known[8] = { source = "told", at = -900, visits = 1 }
check("shared known leader home admits rest", SAO.Controller.__nightProbe("runner", agent(), b, 625, rec) == true)
group, b.x, b.y, present = nil, 12, 10, 7
cold = 2
local chilled = agent()
chilled.resting, chilled.sleeping, chilled.nextScavengeAt = true, true, 99999
chilled.lastRestHours = hours
local coldHeld = SAO.Controller.__nightProbe("runner", chilled, b, 630, rec)
check("cold releases nighttime hold", coldHeld == false and not chilled.resting and not chilled.sleeping)
local hearthCalls = 0
SAO.Needs.findHearth = function()
    hearthCalls = hearthCalls + 1
    return b.x, b.y, b.z, 1, true
end
if not coldHeld then SAO.Controller.__resourceProbe("runner", chilled, b, 630, rec) end
check("cold reaches actual hearth decision", hearthCalls == 1 and chilled.state == "WARMING")
cold = 0
local beforeWarming = recovery
hours = hours + 2
chilled.state = "IDLE"
SAO.Controller.__nightProbe("runner", chilled, b, 640, rec)
check("warming time is not sleep recovery", recovery == beforeWarming)
hours = hours + 1
SAO.Controller.__nightProbe("runner", chilled, b, 641, rec)
check("resumed sleep charges its own interval", recovery == beforeWarming + 1)
allowed, claim, present = true, true, false
check("actual existing claim remains eligible", SAO.Controller.__nightProbe("runner", agent(), b, 650, rec) == true)
claim = false
local wanderer = agent()
local before = orders
check("generic leisure waits in darkness", SAO.Controller.__roamProbe("runner", wanderer, b, 700, 100, nil, rec) == true
    and orders == before and wanderer.pressure and wanderer.pressure.detail == "waits for daylight before a leisure walk")
check("daylight wait does not invent rest", not wanderer.resting and not wanderer.sleeping)
__result = #failures == 0 and ("PASS night continuity " .. count)
    or ("FAIL " .. table.concat(failures, "; "))
