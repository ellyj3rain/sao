-- Evidence sweeps use explicit unavailable ground and the installed cell span.
-- The historical decision dump retains its own original prelude semantics.
SAO.Controller = { tick = function() return SAO.History.ticks() end }
getCell = function() return {
    getCellSizeInSquares = function() return SWEEP_CELL_SPAN end,
} end
-- There is no loaded chunk to survey. Do not manufacture doors or boards.
SAOJavaBridge.surveyClaim = function() return nil end

-- The game starts after the requested history. County hour zero is the
-- fixed record origin; this is SAORecord.countyMonth0's start-minus-behind
-- calendar, using exact Gregorian months rather than averaged month lengths.
local origin = { year = 1993, month = 7, day = 9 }
local cache = {}
local function leap(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end
local function daysInMonth(year, month)
    if month == 2 then return leap(year) and 29 or 28 end
    if month == 4 or month == 6 or month == 9 or month == 11 then return 30 end
    return 31
end
local function dateAt(offset)
    offset = math.floor(offset)
    if cache[offset] then return cache[offset] end
    local year, month, day = origin.year, origin.month, origin.day + offset
    while day > daysInMonth(year, month) do
        day = day - daysInMonth(year, month)
        month = month + 1
        if month > 12 then year, month = year + 1, 1 end
    end
    while day < 1 do
        month = month - 1
        if month < 1 then year, month = year - 1, 12 end
        day = day + daysInMonth(year, month)
    end
    local date = { year = year, month0 = month - 1, day0 = day - 1 }
    cache[offset] = date
    return date
end
local start = dateAt(_G.__owed)
local function today() return dateAt(_G.__owed + math.floor((_G.__hours or 0) / 24)) end
GameTime = { getInstance = function() return {
    getWorldAgeHours = function() return _G.__hours or 0 end,
    getStartYear = function() return start.year end,
    getStartMonth = function() return start.month0 end,
    getStartDay = function() return start.day0 end,
    getYear = function() return today().year end,
    getMonth = function() return today().month0 end,
    getDay = function() return today().day0 end,
    getTimeOfDay = function() return (_G.__hours or 0) % 24 end,
    getHelicopterDay = function() return 7 end,
    getNightsSurvived = function() return math.floor((_G.__hours or 0) / 24) end,
    getCalender = function() return {
        getTimeInMillis = function()
            return SWEEP_START_EPOCH_MS + (_G.__hours or 0) * 3600000
        end,
    } end,
} end }
getGameTime = function() return GameTime.getInstance() end
SAOJavaBridge.countyMonth = function(self, hours, asked)
    return dateAt(math.floor(hours / 24)).month0
end
SAOJavaBridge.recordDayToday = function(self)
    return _G.__owed + math.floor((_G.__hours or 0) / 24)
end
