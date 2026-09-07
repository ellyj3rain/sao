-- SAO_Record - the shipped record on the county's calendar ([C36], DR-031).
-- ---------------------------------------------------------------------------
-- The game's own broadcasts are keyed to days since the save began, and
-- its newspapers to no calendar at all; the record itself carries the
-- dates - its day 0 is July 9, 1993, and every issue is named by its
-- July date. The operator ruled that a living start drives when each
-- part of that record reaches the county. So, once per save, every
-- vanilla channel's running script is re-keyed to begin on the save
-- day that July 9 falls on (the engine's own surface, the one its game
-- modes use; the county wire is left alone), and every paper a
-- container is filled with shows the newest issue printed by that day
-- - or is not on the shelf yet, and is taken off it.
--
-- The shipped default start IS July 9, so a default save keys to day 0
-- and nothing changes. A start on July 1 hears the record's first day
-- eight days in, with the county paper's July 1 to 6 issues on the
-- shelves meanwhile; a start after July 9 finds the record already
-- under way. The Java side does the arithmetic (checked off the game
-- by Border 110) and touches the engine; this file decides when.

if not SAO then SAO = {} end
SAO.Record = SAO.Record or {}
local R = SAO.Record

local function log(msg) SAO.Log.line("RECORD", msg) end

local function enabled()
    local ok, v = pcall(function() return SandboxVars.SurvivorAwareness.RecordOnCalendar end)
    return ok and v ~= false
end

local function store()
    local ok, s = pcall(function() return ModData.getOrCreate("SurvivorAwareness_Standing") end)
    if ok and type(s) == "table" then return s end
    return nil
end

-- Once per save: the flag is the save day the record was keyed to.
function R.rekey()
    if not SAOJavaBridge or not enabled() then return false end
    local s = store()
    if not s then return false end
    local okS, startDay = pcall(function() return SAOJavaBridge:recordStartDay() end)
    if not okS or type(startDay) ~= "number" then return false end
    if s.recordKeyedForStart == startDay then return true end
    local okR, keyed = pcall(function() return SAOJavaBridge:rekeyRecord(startDay) end)
    if okR and type(keyed) == "number" and keyed > 0 then
        s.recordKeyedForStart = startDay
        log("the record keyed to the county's calendar: its first day is save day "
            .. startDay .. " (" .. keyed .. " channels)")
        return true
    end
    -- The channels were not there yet, or the bridge could not reach
    -- them: the hourly retry below asks again.
    return false
end

-- Every container the world fills: the papers in it, dated.
local function onFillContainer(roomType, containerType, container)
    if not SAOJavaBridge or not enabled() or not container then return end
    pcall(function()
        local result = SAOJavaBridge:keyNewspapers(container)
        if type(result) == "string" and result ~= "" and result ~= "keyed=0 removed=0" then
            log("papers in a " .. tostring(containerType) .. ": " .. result)
        end
    end)
end

local function retry()
    if not enabled() then return end
    local s = store()
    if s and s.recordKeyedForStart ~= nil then return end
    pcall(R.rekey)
end

Events.OnLoadRadioScripts.Add(function() pcall(R.rekey) end)
Events.OnGameStart.Add(retry)
Events.EveryHours.Add(retry)
Events.OnFillContainer.Add(onFillContainer)

log("record module loaded (the shipped broadcasts and papers on the county's calendar)")

return R
