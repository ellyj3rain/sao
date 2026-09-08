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

-- [C43] WHERE THE RECORD'S TIMELINE SITS AGAINST THIS SAVE.
--
-- Anchored, which is the shipped calendar and what [C36] built, the
-- Knox Event happens on the dates it carries: begin on July 9 and it
-- is already here, begin on July 1 and it arrives in eight days
-- because that is when it arrived.
--
-- Shifted, the whole record is re-based onto the game being played.
-- The outbreak lands the player's own number of days into the save
-- and everything the record carries keeps its order and spacing
-- around that point, so a world beginning anywhere in 1993 gets its
-- ordinary county first, then the fall, then the record in its
-- shipped order, with the ordinary county it already carries - its
-- own eight days from the July 1 issues to the outbreak - played out
-- first. That number is the record's, not a setting.
--
-- WHICH OF THE TWO a save gets is the Day Zero switch and the start
-- date, and nothing else. The switch is the one that already means
-- "this county starts before the outbreak"; a player who leaves it
-- off is playing the shipped 1993 and their record must not move
-- under them. The date is the Java side's refusal: only a 1993 start
-- may be shifted, because 1993 is the year the record is canonically
-- in. A 1994 or 2000 start is owed the years between simulated
-- forward instead, and moving the lore onto it would erase exactly
-- the history it came for.
local function placeTimeline()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if not (sv and sv.DayZero == true) then
        pcall(function() SAOJavaBridge:anchorRecord() end)
        return nil
    end
    local shift = nil
    pcall(function() shift = SAOJavaBridge:shiftRecord() end)
    if not shift or shift == 0 then
        -- Refused, or nothing to move: not a 1993 start, or a start
        -- already sitting on the record's own first day.
        return nil
    end
    return true, shift
end

-- Once per save: the flag is the save day the record was keyed to.
function R.rekey()
    if not SAOJavaBridge or not enabled() then return false end
    local s = store()
    if not s then return false end
    -- Placed before it is keyed, and on every retry, because the
    -- start day the keying uses comes out of where the timeline sits.
    local moved, shift = placeTimeline()
    local okS, startDay = pcall(function() return SAOJavaBridge:recordStartDay() end)
    if not okS or type(startDay) ~= "number" then return false end
    if s.recordKeyedForStart == startDay then return true end
    local okR, keyed = pcall(function() return SAOJavaBridge:rekeyRecord(startDay) end)
    if okR and type(keyed) == "number" and keyed > 0 then
        s.recordKeyedForStart = startDay
        log("the record keyed to the county's calendar: its first day is save day "
            .. startDay .. " (" .. keyed .. " channels"
            .. (moved and (", timeline shifted " .. tostring(shift)
                .. " days onto this save")
                or ", shipped calendar") .. ")")
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
