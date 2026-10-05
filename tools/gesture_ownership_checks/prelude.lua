require = function() end
__fixtureTicks = {}
Events = { OnTick = { Add = function(fn) __fixtureTicks[#__fixtureTicks+1] = fn end }, OnGameStart = { Add = function() end } }
ISLogSystem = { logAction = function() end }
print = __nativePrint
SAO = {}
local records = { cook = { id = "cook" }, speaker = { id = "speaker" } }
SAO.Log = { line = function() end }
SAO.Hash = { of = function() return 1 end }
SAO.Identity = { get = function(id) return records[id] end }
SAO.Body = { active = { cook = __cook, speaker = __speaker }, foreign = {},
    get = function(id) return SAO.Body.active[id] or SAO.Body.foreign[id] end }
SAO.Controller = { agents = { cook = { rec = records.cook, state = "IDLE" },
    speaker = { rec = records.speaker, state = "IDLE" } }, tick = function() return 46 end }
SAO.History = { countyHours = function() return 2.1 end }
SAO.Observation = { record = function() end }
SAO.Standing = { mayTakeCurrent = function() return true end, mayEnterBelieved = function() return true end,
    sameGroup = function() return false end, groupOf = function() return nil end,
    politick = function() return "neutral" end, debt = function() return 0 end,
    isHostileTo = function() return false end, tellCredits = function() return 0 end,
    tellGrudges = function() return 0 end, companyStanding = function() return 0 end }
SAO.Locomotion = { jobs = {}, cancel = function(id) SAO.Locomotion.jobs[id] = nil end }
SAO.WorldSources = { inspectionCandidate = function() return {} end,
    inspectContainer = function() return true end }
-- Native queue admission and native stack read are the real production owners.
SAOJavaBridge = __realBridge
SAO.Needs = { busy = function(body) return SAOJavaBridge:hasPendingActions(body) end,
    queueVerified = function(action) ISTimedActionQueue.add(action) return true end }
SAO.Disposition = { wouldGiveToStranger = function() return false end,
    isSmoker = function() return false end }
SAO.Lessons = { tellOne = function() return nil end }
SAO.Needs.read = function() return nil end
local transfers = 0
SAO.SourceUse = { beginTransfer = function(id, body)
    transfers = transfers + 1
    records[id].worldSourceReservation = "fixture-transfer"
    return true, { id = "fixture-transfer" }
end, closeForOwnershipTransfer = function(id) records[id].worldSourceReservation = nil return true end }
function transferCount() return transfers end
function fresh()
    if SAO.Cooking then SAO.Cooking.reset() end
    ISTimedActionQueue.clear(__cook); ISTimedActionQueue.clear(__speaker)
    __cook:getCharacterActions():clear(); __speaker:getCharacterActions():clear()
    records.cook = { id = "cook" }; records.speaker = { id = "speaker" }
    SAO.Controller.agents.cook = { rec = records.cook, state = "IDLE" }
    SAO.Controller.agents.speaker = { rec = records.speaker, state = "IDLE" }
    __cook:getModData().SAOExternalOwner = nil; __cook:getModData().ZAOOwned = nil
    SAO.Body.active.cook = __cook; SAO.Body.foreign.cook = nil
    __cook:setAsleep(false); transfers = 0
    return records.cook
end
function check(name, fn)
    local ok, result = pcall(fn)
    print("CHECK " .. name .. "=" .. tostring(ok and result == true))
    if not ok then print("ERROR " .. name .. ": " .. tostring(result)) end
end
