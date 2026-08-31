-- Border 65's driver. A stubbed world clock and store, so the county's
-- feelings can be aged a day at a time; everything about the decay
-- itself is the real `SAO_Standing`.
--
-- [B8] says time softens. Nobody had ever watched it do so - a decay
-- that is too slow makes every grudge permanent, one that is too fast
-- means nobody ever holds anything against anybody, and from inside a
-- game either reads as "the county is like that".

SAO = SAO or {}

local WORLD = { hours = 0 }
local STORE = {}

ModData = {
    getOrCreate = function(name)
        STORE[name] = STORE[name] or {}
        return STORE[name]
    end,
}

GameTime = {
    getInstance = function()
        return { getWorldAgeHours = function() return WORLD.hours end }
    end,
}

local function fresh()
    WORLD.hours = 0
    STORE["SurvivorAwareness_Standing"] = nil
end

-- Enmity at `startTrust`, aged one day at a time. Returns the day
-- hostility ended and the day the feeling ran out, or -1 for never.
function PROBE_FEUD(startTrust, days)
    fresh()
    SAO.Standing.adjustTrust("a", "b", startTrust)
    SAO.Standing.setHostile("a", "b", true)
    local clearedAt, spentAt = -1, -1
    for d = 1, days do
        WORLD.hours = d * 24
        SAO.Standing.driftStandings()
        if clearedAt < 0 and not SAO.Standing.isHostileTo("a", "b") then
            clearedAt = d
        end
        if spentAt < 0
            and math.abs(SAO.Standing.trust("a", "b")) <= 0.011 then
            spentAt = d
        end
    end
    return clearedAt .. "," .. spentAt
end

-- A bond is meant to be exempt from time entirely.
function PROBE_BOND(days)
    fresh()
    SAO.Standing.adjustTrust("a", "b", 0.9)
    local s = ModData.getOrCreate("SurvivorAwareness_Standing")
    s.relations["a"]["b"].bonded = true
    for d = 1, days do
        WORLD.hours = d * 24
        SAO.Standing.driftStandings()
    end
    return SAO.Standing.trust("a", "b")
end

-- Nothing may move inside the grace period. A feeling a fortnight old
-- is still current.
function PROBE_GRACE(days)
    fresh()
    SAO.Standing.adjustTrust("a", "b", 0.5)
    for d = 1, days do
        WORLD.hours = d * 24
        SAO.Standing.driftStandings()
    end
    return SAO.Standing.trust("a", "b")
end
