require = function() end
__ticks = {}
Events = { OnTick = { Add = function(fn) __ticks[#__ticks + 1] = fn end },
    OnGameStart = { Add = function() end, Remove = function() end } }
ISLogSystem = { logAction = function() end }
SAO = { Identity = {}, Body = { active = {}, foreign = {} }, Controller = { agents = {} },
    Log = { line = function() end }, Hash = { of = function() return 1 end },
    History = { countyHours = function() return 2 end },
    Standing = { adjustTrust = function() error("one blow grants no social effect") end } }
__records = {}
SAO.Identity.get = function(id) return __records[id] end
SAO.Body.get = function(id) return SAO.Body.active[id] end
SAO.Controller.tick = function() return 60 end
__results = {}
SAO.ProceduralPlanning = { recordResult = function(id, purpose, result)
    __results[#__results + 1] = result; return true end,
    admitInstrument = function(id, purpose, workId)
        local work = SAO.Gesture.instrumentWork(id)
        if __rejectAdmission or not work or work.workId ~= workId or work.status ~= "prepared" then return false end
        __admission = work
        return true
    end,
    consumeInstrumentOutcome = function(id, sequence)
        local result = SAO.Gesture.instrumentOutcome(id, sequence)
        __physical[#__physical + 1] = { result = result, admitted = __admission ~= nil }
    end }
SAO.Cognition = { instrumentOutcome = function(id, sequence)
    local result = SAO.Gesture.instrumentOutcome(id, sequence)
    __cognitive[#__cognitive + 1] = result
end }
SAO.ConflictResponse = { gesturePriority = function() return false end }
function check(name, fn)
    local ok, value = pcall(fn)
    print("CHECK " .. name .. "=" .. tostring(ok and value == true))
    if not ok then print("ERROR " .. name .. ": " .. tostring(value)) end
end
