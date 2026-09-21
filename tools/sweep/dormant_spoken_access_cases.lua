local checks = {}
local function check(name, value)
    checks[name] = value == true
end
local function close(a, b, tolerance)
    return math.abs(a - b) <= tolerance
end
local function person(id, fatigue, endurance, sleepNeed, atHours)
    return {
        id = id, x = 0, y = 0, z = 0, homeX = 0, homeY = 0,
        nextDormantMoveAt = __tick + 3000,
        speechAccessOrigin = "generated-empty-traits",
        dormantPhysiologyOrigin = "generated-default",
        dormantFatigue = fatigue, dormantEndurance = endurance,
        dormantSleepNeed = sleepNeed, dormantPhysiologyAtHours = atHours,
        dormantSleeping = false,
    }
end

__records = {
    a = person("a", 0.8, 1.0, 1.0, 21.9),
    b = person("b", 0.0, 1.0, 1.0, 21.9),
}
__now = 22.0
SAO.DormantPopulation.dormantLife({}, __tick)
check("sleep_transition_at_22", __records.a.dormantSleeping == true
    and __records.a.dormantResting == true)
check("sleeping_movement_holds", __records.a.x == 0 and __records.a.y == 0
    and __records.a.nextDormantMoveAt == __tick + 3000)
local heard, why = SAO.Communication.canConverse("a", "b", "dormant-encounter")
check("sleep_transition_blocks_encounter", heard == false and why == "asleep")

__now = 30.0
SAO.DormantPopulation.dormantLife({}, __tick + 240)
check("morning_wake_is_produced", __records.a.dormantSleeping == false
    and __records.a.dormantResting == nil and __records.a.dormantFatigue < 0.05)
heard = SAO.Communication.canConverse("a", "b", "dormant-encounter")
check("morning_wake_admits_encounter", heard == true)

__records = {
    legacy = { id = "legacy", x = 0, y = 0, z = 0,
        homeX = 0, homeY = 0, nextDormantMoveAt = __tick + 3000,
        speechAccessOrigin = "generated-empty-traits" },
    b = person("b", 0.0, 1.0, 1.0, 21.9),
}
__now = 22.0
SAO.DormantPopulation.dormantLife({}, __tick)
check("legacy_unknown_not_defaulted", __records.legacy.dormantSleeping == nil
    and __records.legacy.dormantPhysiologyOrigin == nil
    and __records.legacy.dormantPhysiologyAtHours == nil)
heard, why = SAO.Communication.canConverse(
    "legacy", "b", "dormant-encounter")
check("legacy_unknown_blocks_encounter", heard == false
    and why == "sleep-unobserved")

__records = {
    native = { id = "native", x = 0, y = 0, z = 0,
        homeX = 0, homeY = 0, nextDormantMoveAt = __tick + 3000,
        hibernation = "native-pack", dormantSleeping = false },
}
__now = 10.0
SAO.DormantPopulation.dormantLife({}, __tick)
check("native_state_is_acquired", __records.native.dormantPhysiologyOrigin
    == "native-snapshot" and close(__records.native.dormantFatigue, 0.6, 0.000001)
    and close(__records.native.dormantEndurance, 0.4, 0.000001)
    and close(__records.native.dormantSleepNeed, 0.7, 0.000001))
__now = 11.0
SAO.DormantPopulation.dormantLife({}, __tick + 240)
check("native_awake_law_advances", close(
    __records.native.dormantFatigue, 0.652164, 0.00001))

__records = {
    less = person("less", 0.0, 1.0, 0.7, 10.0),
    more = person("more", 0.0, 1.0, 1.3, 10.0),
}
__now = 11.0
SAO.DormantPopulation.dormantLife({}, __tick)
check("saved_sleep_traits_change_fatigue", close(
    __records.less.dormantFatigue, 0.026082, 0.00001)
    and close(__records.more.dormantFatigue, 0.048438, 0.00001)
    and __records.more.dormantFatigue > __records.less.dormantFatigue)

local rows = {}
for name, value in pairs(checks) do
    rows[#rows + 1] = name .. "=" .. tostring(value)
end
table.sort(rows)
return table.concat(rows, ";")
