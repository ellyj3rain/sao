-- Full Controller + Locomotion, controlled native route verdict/geometry.
-- The corresponding loaded run supplies the actual Working -> Failed trace.
local checks = {}
local function check(name, value)
    if not value then error("HOME_ROUTE:" .. name) end
    checks[#checks + 1] = name
end
local hours, clock, inside, permitted, gear = 2, 20, false, true, false
local b = { x = 3391.89599609375, y = 10872.537109375, z = 0 }
function b:getX() return self.x end
function b:getY() return self.y end
function b:getZ() return self.z end
function b:getVehicle() return nil end
function b:getCurrentSquare() return { getBuildingDef = function()
    return inside and { getID = function() return 7 end } or nil end } end
GameTime = { getInstance = function() return { getTimeOfDay = function() return clock end } end }
SAO.History.countyHours = function() return hours end
SAO.Places = { at = function() return { id = 7 } end }
SAO.Perception.knownPlaces = function() return { [7] = { source = "lived", visits = 1 } } end
SAO.Standing.mayEnterBelieved = function() return permitted end
SAO.Standing.claimedByOther = function() return nil end
SAO.Standing.fallHasCome = function() return true end
SAO.Standing.claimOf = function() return nil end
SAO.Standing.claimFor = function() return nil end
SAO.Needs.needsAmmo = function() return false end
SAO.Needs.findGear = function() if gear then return 3394, 10873, 0, "known weapon" end end
SAO.Needs.approach = function(_, _, x, y, z) return x, y, z end
SAO.Needs.read = function() return { hunger = .1, thirst = .1 } end
SAO.Disposition.drinkAt = function() return .4 end
SAO.Needs.drinkCarried = function() __drinks = __drinks + 1; return true end
local records = {}
ModData = { getOrCreate = function(key)
    check("actual_identity_store_key", key == "SurvivorAwareness_Records")
    return { records = records, nextId = 2 }
end }
__bodies = { runner = b }; __forbidden = {}; __blockAll = false; __group = nil; __player = nil
local rec, a
local function agent(record)
    return { state = "IDLE", rec = record, nextDecisionAt = 0 }
end
local function fresh()
    hours, clock, inside, permitted, gear = 2, 20, false, true, false
    __starts, __cancels, __drinks, __injury = 0, 0, 0, 0
    __verdict = "Working"
    b.x, b.y, b.z = 3391.89599609375, 10872.537109375, 0
    rec = { id = "runner", homeX = 3426, homeY = 10910, homeZ = 0 }
    records.runner = rec
    a = agent(rec); SAO.Controller.agents = { runner = a }
    SAO.Locomotion.jobs = {}; SAO.SourceUse = nil; SAO.Cognition = nil
end
local function home()
    SAO.Controller.__homeRouteTick(math.floor((hours or 2) * 9000))
    return SAO.Controller.__homeRouteDecide("runner", a, b, math.floor((hours or 2) * 9000), rec)
end
local function terminal(result)
    __verdict = result
    return SAO.Controller.__homeRouteMovement("runner", a, b)
end
local function failed()
    check("initial_home_admitted", home() == true and a.state == "HOMEWARD")
    terminal("Working"); terminal("Failed")
    check("terminal_failure_closed", a.state == "IDLE" and SAO.Locomotion.jobs.runner == nil)
    check("receipt_retained", rec.homeRouteFailure and rec.homeRouteFailure.reason == "done:Failed")
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end

fresh(); failed()
local receipt = rec.homeRouteFailure
check("exact_target_and_approach", receipt.x == 3426 and receipt.y == 10910 and receipt.z == 0
    and receipt.fromX == b.x and receipt.fromY == b.y and receipt.fromZ == 0)
local fields = 0
for _, value in pairs(receipt) do
    fields = fields + 1
    check("receipt_contains_only_scalars", type(value) == "number" or type(value) == "string")
end
check("one_bounded_receipt", fields == 9 and receipt.attempts == 1 and receipt.atHours == 2)
for i = 1, 1000 do home() end
check("immediate_retry_suppressed", __starts == 1 and a.state == "IDLE")
hours = 2.24999; home()
check("cooldown_uses_county_clock", __starts == 1)
hours = 2.25; home()
check("retry_at_delay_allowed", __starts == 2 and a.state == "HOMEWARD")
terminal("Failed")
check("repeated_failure_extends_delay", rec.homeRouteFailure.attempts == 2)
hours = 2.5; home()
check("second_delay_not_first_delay", __starts == 2)
hours = 2.75; home(); terminal("Failed")
check("third_attempt_retained", rec.homeRouteFailure.attempts == 3)
for i = 1, 20 do
    local last = rec.homeRouteFailure
    hours = last.atHours + .25 * last.attempts
    check("later_reconsideration_allowed", home() == true)
    terminal("Failed")
    check("failure_count_capped", rec.homeRouteFailure.attempts <= 4)
end
check("one_hour_maximum_delay", rec.homeRouteFailure.attempts == 4)

fresh(); failed(); rec.homeX = rec.homeX + 1; home()
check("changed_target_allowed", __starts == 2 and __ordered.x == rec.homeX)
fresh(); failed(); rec.homeZ = 1; home()
check("changed_target_floor_allowed", __starts == 2 and __ordered.z == 1)
fresh(); failed(); b.x = b.x + 1.99; home()
check("small_motion_keeps_failure", __starts == 1)
b.x = b.x + .02; home()
check("changed_approach_allowed", __starts == 2)
fresh(); failed(); b.z = 1; home()
check("changed_approach_floor_allowed", __starts == 2)
fresh(); failed(); hours = 1; home()
check("rewound_clock_does_not_permanently_hold", __starts == 2 and rec.homeRouteFailure == nil)

fresh(); failed()
records = { runner = copy(rec) }
SAO.Identity.rebindWorld()
rec = SAO.Identity.get("runner")
a = agent(rec); SAO.Controller.agents = { runner = a }; SAO.Locomotion.jobs = {}
home()
check("readopted_saved_record_retains_delay", __starts == 1)
hours = 2.25; home()
check("readopted_saved_record_reconsiders", __starts == 2)
inside, b.x, b.y = true, 3426.5, 10910.5
terminal("Succeeded")
check("successful_arrival_clears_failure", rec.homeRouteFailure == nil and a.state == "IDLE")
home(); check("occupied_home_not_reissued", __starts == 2)
fresh(); failed(); inside, b.x, b.y = true, 3426.5, 10910.5; home()
check("actual_occupancy_clears_failure", rec.homeRouteFailure == nil and __starts == 1)

fresh(); check("working_route_admitted", home() == true)
for i = 1, 30 do terminal("Working"); home() end
check("working_route_retained", __starts == 1 and rec.homeRouteFailure == nil)
fresh(); home()
SAO.SourceUse = { beforeStateChange = function() return false end }
terminal("Failed"); home()
check("refused_reconciliation_keeps_owner", a.state == "HOMEWARD" and __starts == 1
    and rec.homeRouteFailure == nil and SAO.Locomotion.jobs.runner.done)
SAO.SourceUse.beforeStateChange = function() return true end
terminal("Failed"); home()
check("allowed_closure_records_once", a.state == "IDLE" and rec.homeRouteFailure.attempts == 1 and __starts == 1)

for _, result in ipairs({ "IDLE", "tick-fault", "stalled:Working", "FailedObstacle:FAILED_UNLOADED_NEXT_SQUARE",
    "FailedObstacle:FAILED_CROSSING_NOT_ENTERED", "FailedObstacle:FAILED_LOCKED_DOOR_EXTRA" }) do
    fresh(); home()
    local job = SAO.Locomotion.jobs.runner
    job.done, job.result = true, result
    SAO.Controller.__homeRouteMovement("runner", a, b)
    check("non_access_result_not_learned_" .. result, rec.homeRouteFailure == nil)
end
for _, result in ipairs({ "Failed", "stalled:ManualRoute", "FailedObstacle:FAILED_BLOCKED_DIAGONAL",
    "FailedObstacle:FAILED_LOCKED_DOOR", "FailedObstacle:FAILED_BARRICADED_DOOR",
    "FailedObstacle:FAILED_BARRICADED_WINDOW", "FailedObstacle:FAILED_BLOCKED_WINDOW",
    "FailedObstacle:FAILED_WINDOW_DECLINED", "FailedObstacle:FAILED_EDGE_COOLDOWN",
    "FailedObstacle:FAILED_UNSUPPORTED_Z_CHANGE" }) do
    fresh(); home()
    local job = SAO.Locomotion.jobs.runner
    job.done, job.result = true, result
    SAO.Controller.__homeRouteMovement("runner", a, b)
    check("exact_failure_retained_" .. result, rec.homeRouteFailure
        and rec.homeRouteFailure.reason == "done:" .. result)
end
fresh(); home(); SAO.Locomotion.jobs.runner.body = { getX = function() return 0 end,
    getY = function() return 0 end }
terminal("Failed")
check("foreign_job_body_not_learned", rec.homeRouteFailure == nil)
fresh(); home(); SAO.Locomotion.jobs.runner.goal.x = 1; terminal("Failed")
check("different_job_goal_not_learned", rec.homeRouteFailure == nil)
fresh(); home(); hours = nil; terminal("Failed")
check("unknown_clock_not_fabricated", rec.homeRouteFailure == nil)

fresh(); failed(); gear = true; home()
check("other_productive_decision_remains_available", a.state == "GEARWARD" and __starts == 2)
fresh(); failed()
SAO.Controller.__homeRouteNeeds("runner", a, b, 200, { thirst = .8, hunger = .1 })
check("existing_need_handler_remains_available", a.state == "DRINK" and __drinks == 1 and __starts == 1)
fresh(); failed()
SAO.Controller.__homeRouteThreat("runner", a, b, 200,
    { x = b.x - 5, y = b.y, dist = 5, source = "observed" }, 1)
check("current_threat_keeps_its_owner", a.state == "FLEE" and __starts == 2 and rec.homeRouteFailure ~= nil)
fresh(); failed(); permitted = false; hours = 9; home()
check("expired_retry_does_not_override_permission", __starts == 1 and a.state == "IDLE")

for _, invalid in ipairs({ { reason = "done:Failed" }, { x = "bad", reason = "done:Failed" },
    { x = 3426, y = 10910, z = 0, fromX = 0, fromY = 0, fromZ = 0, atHours = 2,
        attempts = 100000, reason = "done:Failed" } }) do
    fresh(); rec.homeRouteFailure = invalid; home()
    check("invalid_saved_receipt_does_not_hold", __starts == 1)
end
RESULT = "PASS home route " .. #checks
