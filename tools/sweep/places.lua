-- The shipped map, served to the real SAO_Places.
--
-- `__BUILDINGS` is read out of the game's own .lotheader files by
-- world.py - thousands of buildings across every cell the shipped
-- towns occupy, with the rooms named as the map names them. An
-- earlier version of this served a lattice of invented buildings,
-- which fabricated the circumstances the simulation is supposed to be
-- judged against.
--
-- Only the six methods SAO_Places asks of IsoMetaGrid are answered:
--
--   grid:getBuildingAt(x, y)  -> def or nil
--   def:getID/getX/getY/getX2/getY2
--   def:getRooms() -> list with :size() and :get(i)
--   room:getName()
--
-- Lookup is bucketed into 64-tile squares so a probe does not walk
-- every building: SAO_Places.around probes eighty-one points per
-- person per choice, and a linear scan there dominates the run.

local BUCKET = 64
local buckets = {}
local defs = {}

local function keyOf(x, y)
    return math.floor(x / BUCKET) .. ":" .. math.floor(y / BUCKET)
end

local function defFor(b)
    if defs[b.id] then return defs[b.id] end
    local rooms = {}
    for i, name in ipairs(b.rooms) do
        rooms[i - 1] = { getName = function() return name end }
    end
    local n = #b.rooms
    local def = {
        getID = function() return b.id end,
        getX = function() return b.minX end,
        getY = function() return b.minY end,
        getX2 = function() return b.maxX end,
        getY2 = function() return b.maxY end,
        getRooms = function()
            return {
                size = function() return n end,
                get = function(self, i) return rooms[i] end,
            }
        end,
    }
    defs[b.id] = def
    return def
end

for _, b in ipairs(_G.__BUILDINGS or {}) do
    local cx = math.floor(b.minX / BUCKET)
    local cy = math.floor(b.minY / BUCKET)
    local cx2 = math.floor(b.maxX / BUCKET)
    local cy2 = math.floor(b.maxY / BUCKET)
    for gx = cx, cx2 do
        for gy = cy, cy2 do
            local k = gx .. ":" .. gy
            buckets[k] = buckets[k] or {}
            table.insert(buckets[k], b)
        end
    end
end

_G.__grid = {
    getBuildingAt = function(self, x, y)
        local list = buckets[keyOf(x, y)]
        if not list then return nil end
        for _, b in ipairs(list) do
            if x >= b.minX and x < b.maxX and y >= b.minY and y < b.maxY then
                return defFor(b)
            end
        end
        return nil
    end,
}

getWorld = function()
    return {
        -- The run's own save identity, which is what [C66] seeds the
        -- county's whole draw from. Hardcoding it here once made
        -- twelve counties produce byte-identical outcomes.
        getWorld = function() return _G.__world or "SweepSave" end,
        getMetaGrid = function() return _G.__grid end,
    }
end
