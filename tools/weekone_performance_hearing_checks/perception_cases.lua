local P = SAO.Perception
local observer = {}
local performerBody = {}
local listener = { id = "listener" }
local performer = { id = "bwo-73", weekOne = {
    source = "BanditsWeekOne", status = "external", brainId = 73, born = 12.5 } }
local epoch = "01234567-89ab-cdef-0123-456789abcdef"
local pulse = epoch .. "-1"
local occurrence = { schema = "sao.weekone-performance-occurrence/1",
    actorId = "bwo-73", brainId = 73, born = 12.5,
    clock = "native-world-age-hours", soundId = "BWOInstrumentBassGuitar1",
    soundHandle = 1, pulseId = pulse, epoch = epoch, sequence = 1,
    emittedAtHours = 11.9 }
local row = { schema = "sao.weekone-performance-hearing/1",
    observerId = "listener", actorId = "bwo-73", brainId = 73, born = 12.5,
    clock = "native-world-age-hours", basis = "native-scanner-acquired-occurrence",
    soundId = occurrence.soundId, soundHandle = 1, pulseId = pulse,
    epoch = epoch, sequence = 1, emittedAtHours = 11.9,
    heardAtHours = 11.91, witnessedAtHours = 11.92, atHours = 11.93 }
local current = true
local owned = true
local nativeNow = 12
SAO.Identity.get = function(id)
    if id == "listener" then return listener end
    if id == "bwo-73" then return performer end
end
SAO.Claims = { heldBy = function(rec)
    return rec == performer and "BanditsWeekOne" or nil end }
SAO.Needs = { ownsRecoveryBody = function(id, body)
    return owned and id == "listener" and body == observer end }
SAO.WeekOneContinuity = {
    livePerformance = function(id)
        if current and id == "bwo-73" then return performerBody, occurrence end
    end,
}
SAOJavaBridge = { claimWeekOnePerformanceHearing = function(self, body, source,
        actorId, brainId, born, pulseId)
    if body ~= observer or source ~= performerBody or actorId ~= "bwo-73"
        or brainId ~= 73 or born ~= 12.5 or pulseId ~= pulse then return nil end
    local out = {}
    for key, value in pairs(row) do out[key] = value end
    return out
end }
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return nativeNow end } end }
SAO.History.countyHours = function() return 24 end

local heard = P.acquireWeekOnePerformanceHearing("listener", observer, "bwo-73")
assert(heard and heard.pulseId == pulse and heard.observerId == "listener"
    and heard.acquiredAtCountyHours == 24,
    "exact native hearing was not retained for this person")
heard.soundId = "changed-by-caller"
assert(#P.weekOnePerformanceHearings("listener") == 1
    and P.weekOnePerformanceHearings("listener")[1].soundId == occurrence.soundId
    and P.acquireWeekOnePerformanceHearing("listener", observer, "bwo-73") == nil,
    "returned hearing mutated private history or replayed")
assert(performer.weekOnePerformanceHearings == nil,
    "performer borrowed the listener's private sound")

local function refuses(label, change)
    listener.weekOnePerformanceHearings = nil
    change()
    assert(P.acquireWeekOnePerformanceHearing("listener", observer, "bwo-73") == nil
        and listener.weekOnePerformanceHearings == nil, label)
end
refuses("future native receipt entered private hearing", function()
    row.atHours = nativeNow + 1 end)
row.atHours = 11.93
refuses("wrong source brain entered private hearing", function()
    occurrence.brainId = 74 end)
occurrence.brainId = 73
refuses("changed source body entered private hearing", function()
    current = false end)
current = true
refuses("foreign observer body entered private hearing", function()
    owned = false end)
owned = true
refuses("source receipt sound mismatch entered private hearing", function()
    row.soundId = "wrong-sound" end)
row.soundId = occurrence.soundId
refuses("source receipt handle mismatch entered private hearing", function()
    row.soundHandle = 99 end)
row.soundHandle = 1
refuses("wrong native occurrence entered private hearing", function()
    row.pulseId = epoch .. "-2" end)
row.pulseId = pulse
refuses("changed performer generation entered private hearing", function()
    performer.weekOne.born = 13.5 end)
performer.weekOne.born = 12.5
assert(P.acquireWeekOnePerformanceHearing("listener", observer, "bwo-73") ~= nil,
    "valid hearing did not recover after refusals")
current = false
assert(#P.weekOnePerformanceHearings("listener") == 1,
    "saved hearing vanished when source performance ended")
listener.weekOnePerformanceHearings[1].atHours = nativeNow + 1
assert(#P.weekOnePerformanceHearings("listener") == 0,
    "future saved receipt was treated as valid memory")
listener.weekOnePerformanceHearings = nil
current = true
observer.getX = function() return 11 end
observer.getY = function() return 20 end
observer.getZ = function() return 0 end
SAO.WeekOneContinuity.livePerformanceIds = function() return { "bwo-73" } end
SAOJavaBridge.perceive = function() return "" end
P.observe("listener", observer, 200, false)
assert(#P.weekOnePerformanceHearings("listener") == 1,
    "normal observer scan did not acquire a current Week One sound")
listener.weekOnePerformanceHearings = nil
local available = false
SAO.WeekOneContinuity.livePerformanceIds = function()
    return available and { "bwo-73" } or {}
end
P.observe("listener", observer, 220, false)
assert(listener.weekOnePerformanceHearings == nil,
    "a performance was heard before its physical action began")
available = true
-- A real native claim consumes a scanner-acquired pulse. Require the very
-- first callback after this action begins to scan before trying the claim;
-- there may be no second callback before the native WorldSound expires.
local acquired = false
local scans = 0
SAOJavaBridge.perceiveAudibleSounds = function(self, body)
    if body == observer then acquired = true; scans = scans + 1 end
    return ""
end
local priorClaim = SAOJavaBridge.claimWeekOnePerformanceHearing
local claims = 0
SAOJavaBridge.claimWeekOnePerformanceHearing = function(...)
    claims = claims + 1
    if not acquired then return nil end
    return priorClaim(...)
end
P.observe("listener", observer, 221, false)
assert(scans == 1 and claims == 1
    and #P.weekOnePerformanceHearings("listener") == 1,
    "first live callback claimed performance before personal sound acquisition")
available = false
current = false
P.observe("listener", observer, 222, false)
assert(claims == 1 and #P.weekOnePerformanceHearings("listener") == 1,
    "expired performance replayed an already heard physical occurrence")
listener.weekOnePerformanceHearings = nil
P.observe("listener", observer, 400, true)
assert(listener.weekOnePerformanceHearings == nil,
    "sleeping listener received a performance hearing")
owned = false
P.observe("listener", observer, 600, false)
assert(listener.weekOnePerformanceHearings == nil,
    "unowned body received a performance hearing through observation")
current = true

-- A stamped Week One listener hears through its own live source proxy without
-- becoming an SAO recovery-body owner. Native custody must name its generation.
local proxyBody = {}
local proxyBrain = { id = 84, born = 44.5 }
local proxy = { id = "bwo-listener", weekOne = {
    source = "BanditsWeekOne", status = "external", brainId = 84, born = 44.5 } }
local proxyCurrent, proxyClaim, proxyReceiptBorn = true, true, 44.5
SAO.Identity.get = function(id)
    if id == "listener" then return listener end
    if id == "bwo-73" then return performer end
    if id == "bwo-listener" then return proxy end
end
SAO.Claims.heldBy = function(rec)
    if rec == performer then return "BanditsWeekOne" end
    if rec == proxy and proxyClaim then return "BanditsWeekOne" end
end
SAO.WeekOneContinuity.sourceBodyFor = function(id)
    if id == "bwo-listener" and proxyCurrent then return proxyBody, proxyBrain end
end
SAOJavaBridge.claimWeekOnePerformanceHearing = function(self, body, source,
        actorId, brainId, born, pulseId)
    if source ~= performerBody or actorId ~= "bwo-73"
        or brainId ~= 73 or born ~= 12.5 or pulseId ~= pulse then return nil end
    local out = {}
    for key, value in pairs(row) do out[key] = value end
    if body == proxyBody then
        out.observerId = "bwo-listener"
        out.observerBrainId, out.observerBorn = 84, proxyReceiptBorn
    elseif body ~= observer then return nil end
    return out
end
local proxyHearing = P.acquireWeekOnePerformanceHearing("bwo-listener",
    proxyBody, "bwo-73")
assert(proxyHearing and proxyHearing.observerBrainId == 84
    and proxyHearing.observerBorn == 44.5
    and #P.weekOnePerformanceHearings("bwo-listener") == 1,
    "source-owned proxy did not retain its own exact-generation hearing")
proxy.weekOnePerformanceHearings = nil
local function proxyRefuses(label, change, restore)
    change()
    assert(P.acquireWeekOnePerformanceHearing("bwo-listener", proxyBody,
        "bwo-73") == nil and proxy.weekOnePerformanceHearings == nil, label)
    restore()
end
proxyRefuses("unresolved source proxy borrowed native hearing",
    function() proxyCurrent = false end, function() proxyCurrent = true end)
proxyRefuses("revoked source claim borrowed native hearing",
    function() proxyClaim = false end, function() proxyClaim = true end)
proxyRefuses("reused source-brain generation borrowed native hearing",
    function() proxyBrain.born = 45.5 end,
    function() proxyBrain.born = 44.5 end)
proxyRefuses("wrong native observer generation entered private history",
    function() proxyReceiptBorn = 45.5 end,
    function() proxyReceiptBorn = 44.5 end)
proxyBody.getX = function() return 11 end
proxyBody.getY = function() return 20 end
proxyBody.getZ = function() return 0 end
available = true
P.observe("bwo-listener", proxyBody, 800, false)
assert(#P.weekOnePerformanceHearings("bwo-listener") == 1,
    "normal source-proxy scan did not acquire its own native hearing")
return "PASS Week One private performance hearing"
