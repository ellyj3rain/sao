__tick = 100
__persisted = {}
__rows = ""
__records = {}
__requests = {}
__clears = 0
__allow = true
__throw = false
__nativeConsumed = {}
__policies = 0
Events = { OnGameStart = { Add = function() end } }
ModData = { getOrCreate = function() return __persisted end }
ISTimedActionQueue = { queues = {} }
SandboxVars = { SurvivorAwareness = { Neuroinflammation = true } }
SAO = {
    Log = { line = function() end },
    History = { ticks = function() return __tick end,
        countyHours = function() return __tick / 9000 end },
    Identity = { get = function(id) return __records[tostring(id)] end,
        resolveBodyTag = function() return nil end },
    Conditions = { memoryFactor = function() return 1 end },
    Standing = { groupOf = function() return nil end,
        claimOf = function() return nil end },
    Body = { active = {}, foreign = {}, get = function(id)
        return SAO.Body.active[id] or SAO.Body.foreign[id]
    end },
    Controller = { agents = {} },
    Locomotion = { jobs = {}, order = function() error("orienting routed") end,
        cancel = function() error("orienting cancelled") end },
    WorldSources = { pendingActionFor = function() return nil end },
}
ZAO = { Controller = { controlled = {} } }
SAOJavaBridge = {
    perceive = function() return __rows end,
    isShell = function(self, body) return body.shell == true end,
    clearOrientation = function(self, body) __clears = __clears + 1 end,
    requestOrientation = function(self, body, cueId, x, y, ready, steady, pivot)
        __requests[#__requests + 1] = { body = body, cueId = cueId, x = x, y = y,
            readiness = ready, steadiness = steady, pivot = pivot }
        if __throw then error("native refusal") end
        if __allow ~= true then return __allow end
        if __nativeConsumed[cueId] then return false end
        __nativeConsumed[cueId] = true
        return true
    end,
}

function __body(id)
    local b = { data = { SAOPersonId = id }, shell = true, dead = false,
        sleeping = false, attached = true, square = {}, attack = false,
        aim = false, climb = false, rope = false, vehicle = nil }
    function b:getX() return 10 end
    function b:getY() return 20 end
    function b:getZ() return 0 end
    function b:getModData() return self.data end
    function b:isDead() return self.dead end
    function b:isAsleep() return self.sleeping end
    function b:isExistInTheWorld() return self.attached end
    function b:getCurrentSquare() return self.square end
    function b:isAttacking() return self.attack end
    function b:isAiming() return self.aim end
    function b:isClimbing() return self.climb end
    function b:isClimbingRope() return self.rope end
    function b:getVehicle() return self.vehicle end
    return b
end

function __token(index)
    return "01234567-89ab-cdef-0123-456789abcdef-" .. tostring(index)
end

function __sound(index, x, y, distance)
    return "S:" .. tostring(x or 12) .. ":" .. tostring(y or 20)
        .. ":" .. tostring(distance or 2) .. ":cue:" .. __token(index)
end
