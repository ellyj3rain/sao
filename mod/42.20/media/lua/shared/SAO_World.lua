-- SAO_World.lua - what THIS world contains ([B21]).
--
-- The operator's directive: build the substrate, so the county can
-- recall that "this exists and this exists and this exists" across a
-- mod load that is theirs, not ours, and that will change.
--
-- The doctrine already existed and stopped at one place. SAO_Census
-- ingests the engine's own profession registry, so any profession mod
-- that registers properly enters the population automatically at an
-- honest rarity - first-principles mod compatibility, already shipped.
-- This extends exactly that idea to the rest of the world: items and
-- vehicles.
--
-- THE RULE THIS FILE OBEYS: never name a mod, never name an item.
-- Everything is discovered from the live script registry and grouped
-- by the categories content uses to describe ITSELF. A modded
-- instrument, a modded camper and a modded crop announce themselves
-- the same way vanilla ones do, so a changed load needs no code
-- change here.
--
-- This is a READ of what is REGISTERED, not what is lying on the
-- ground. What is actually within reach is the perception layer's
-- question and stays there.

SAO = SAO or {}
SAO.World = SAO.World or {}

local W = SAO.World

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("WORLD", msg) end

-- Surveyed once. The registry does not change mid-session, so asking
-- twice would be pure cost - the same discipline the [B5] audit
-- applied to per-frame scans.
local surveyed = false
local items = { modules = 0, total = 0, byCategory = {} }
local vehicles = { count = 0, seatsMax = 0, seatsBig = 0,
                   storeMax = 0, quietest = 0, loudest = 0 }

-- A vehicle that carries this many is a different proposition from a
-- sedan: a household moves in it. The county never learns the word
-- "RV" - it learns that something here holds six.
local BIG_SEATS = 6

local function parseFields(line, into, numeric)
    for chunk in string.gmatch(tostring(line or ""), "[^|]+") do
        local key, value = string.match(chunk, "^([^=]+)=(.*)$")
        if key then
            if string.sub(key, 1, 4) == "cat:" then
                into.byCategory[string.sub(key, 5)] = tonumber(value) or 0
            elseif numeric[key] ~= nil then
                numeric[key] = tonumber(value) or 0
            end
        end
    end
end

function W.survey()
    if surveyed then return end
    surveyed = true
    if not SAOJavaBridge then return end
    local okI, itemLine = pcall(function()
        return SAOJavaBridge:surveyItems(24)
    end)
    if okI and type(itemLine) == "string" and itemLine ~= "" then
        local counts = { modules = 0, items = 0 }
        parseFields(itemLine, items, counts)
        items.modules, items.total = counts.modules, counts.items
    end
    local okV, vehLine = pcall(function()
        return SAOJavaBridge:surveyVehicles(BIG_SEATS)
    end)
    if okV and type(vehLine) == "string" and vehLine ~= "" then
        local counts = { veh = 0, seatsMax = 0, seatsBig = 0,
                         storeMax = 0, quietest = 0, loudest = 0 }
        parseFields(vehLine, { byCategory = {} }, counts)
        vehicles.count, vehicles.seatsMax = counts.veh, counts.seatsMax
        vehicles.seatsBig, vehicles.storeMax = counts.seatsBig, counts.storeMax
        vehicles.quietest, vehicles.loudest = counts.quietest, counts.loudest
    end
    log("this world holds " .. items.total .. " items from "
        .. items.modules .. " modules, and " .. vehicles.count
        .. " vehicles (largest seats " .. vehicles.seatsMax .. ", "
        .. vehicles.seatsBig .. " of them hold " .. BIG_SEATS .. "+)")
end

-- Does this world contain anything of a given self-described
-- category? The caller asks by the category CONTENT uses, never by a
-- mod's name.
function W.hasCategory(name)
    W.survey()
    return (items.byCategory[tostring(name)] or 0) > 0
end

function W.categoryCount(name)
    W.survey()
    return items.byCategory[tostring(name)] or 0
end

-- What this world can drive, by capability. "Is there something here
-- a household could move in" is a real question with a real answer,
-- and it never needs the word for it.
function W.vehicles()
    W.survey()
    return vehicles
end

function W.carriesAHousehold()
    W.survey()
    return vehicles.seatsBig > 0
end

function W.moduleCount()
    W.survey()
    return items.modules
end

-- For the debug surface: the categories this world actually has most
-- of, biggest first. Rendered at read time, never stored as prose.
function W.topCategories(limit)
    W.survey()
    local ranked = {}
    for name, count in pairs(items.byCategory) do
        ranked[#ranked + 1] = { name = name, count = count }
    end
    table.sort(ranked, function(a, b)
        if a.count == b.count then return a.name < b.name end
        return a.count > b.count
    end)
    local out = {}
    for i = 1, math.min(limit or 8, #ranked) do out[i] = ranked[i] end
    return out
end

return SAO.World
