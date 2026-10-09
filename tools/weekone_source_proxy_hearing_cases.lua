local W = SAO.WeekOneContinuity
local brain = __brain(84, "BanditsWeekOne")
local body = __body(84)
__source = body
BanditBrain = { Get = function(candidate)
    if candidate == body then return brain end
end }
BanditZombie.CacheLightB = { [84] = { brain = brain } }
local personId = W.observeBrain(brain, body)
assert(personId and W.sourceBodyFor(personId) == body,
    "exact source proxy did not enter the existing SAO person crosswalk")

local performer = { x = 82, y = 80,
    getX = function(self) return self.x end,
    getY = function(self) return self.y end }
local active = true
W.livePerformanceIds = function()
    return active and { "bwo-performer" } or {}
end
W.livePerformance = function(id)
    if active and id == "bwo-performer" then return performer, {} end
end
local acquired, scans, claims, lessons = false, 0, 0, 0
SAOJavaBridge.perceiveAudibleSounds = function(self, observer)
    if observer ~= body then error("foreign body scanner") end
    scans = scans + 1
    acquired = true
    return "S:82:80:2"
end
SAO.Perception.acquireWeekOnePerformanceHearing = function(id, observer, source)
    claims = claims + 1
    if id ~= personId or observer ~= body or source ~= "bwo-performer"
        or not acquired then return nil end
    if __records[id].heardPerformance then return nil end
    __records[id].heardPerformance = { sourceId = source,
        at = __clock, basis = "native-scanner-acquired-occurrence" }
    return __records[id].heardPerformance
end
SAO.Cognition.weekOnePerformanceHearings = function(id)
    if id == personId and __records[id].heardPerformance then
        lessons = lessons + 1
    end
end

__step = "first-source-proxy-callback"
W.onTick()
assert(scans == 1 and claims == 1 and lessons == 1
    and __records[personId].heardPerformance
    and __observations == 0,
    "first source-proxy callback missed native acquisition before personal claim")
__step = "repeated-callback"
W.onTick()
assert(scans == 2 and lessons == 1 and __observations == 0,
    "repeated callback replayed a retained performance or ran full cognition")
__step = "expired-performance"
active = false
W.onTick()
assert(scans == 2 and lessons == 1,
    "expired performance still caused source-proxy sound polling")

__step = "foreign-generation"
active = true
brain.born = 13.5
W.onTick()
assert(scans == 2 and lessons == 1,
    "changed source brain generation borrowed the person's hearing")
brain.born = 12.5
__step = "distant-source"
performer.x = 140
W.onTick()
assert(scans == 2 and lessons == 1,
    "distant performance triggered a source-proxy scanner claim")

__step = "bounded-cache-cursor"
performer.x = 82
local large = {}
for n = 1, 300 do large[n] = { brain = { id = n,
    saoWeekOneOrigin = "Bandits2" } } end
large[84] = { brain = brain }
BanditZombie.CacheLightB = large
local maximum = 0
__pollVisitHook = function(source, stream)
    if source == large and stream == "source-performance-hearers" then
        maximum = maximum + 1
    end
end
for i = 1, 4 do
    local before = maximum
    W.onTick()
    assert(maximum - before <= 128,
        "performance callback traversed more than 128 raw cache entries")
end
assert(maximum >= 300 and __observations == 0,
    "bounded source cache did not advance across callbacks")
return "PASS source proxy first-callback hearing"
