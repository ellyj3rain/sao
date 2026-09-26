-- SAO_Places - the county's own map, read as places.
--
-- [B37]. The mod had a full social ontology and no material one. A
-- dormant survivor's whole day was:
--
--     rec.dayGoalX = rec.homeX + SAO.Rand.int(-24, 25)
--
-- a RANDOM COORDINATE inside a 48-tile box, walked at four tiles a
-- move, forever, under a daily dice roll that eventually kills them.
-- The operator, exactly right: that is not a living mechanic.
--
-- `IsoMetaGrid` describes fixed building geometry across the whole map
-- and is independent of which cells are loaded. It does not describe
-- current stock. Every geography accessor used here is a public method
-- on a class the game ships:
--
--     getWorld():getMetaGrid()          IsoWorld.getMetaGrid()
--     metaGrid:getBuildingAt(x, y)      -> BuildingDef
--     building:getRooms()               -> ArrayList<RoomDef>
--     building:getX/getY/getX2/getY2/getID
--     room:getName()                    -> String
--
-- `RoomDef:getName()` supplies exploration vocabulary. The map calls a room
-- `kitchen`, `bathroom`, `burgerkitchen`, `mechanic`, `barn` - and
-- the shipped Distributions.lua is keyed by exactly those names,
-- under a header that reads "Room List (A-Z)". That table is the
-- vocabulary; it says what might generate there, never what is present now.
--
-- This module owns only stable geography and resource possibility. Exact
-- native sources and their revisions live in SAO_WorldSources. What a given
-- survivor knows lives in SAO_Perception; what they do about it is the
-- population/controller's.

SAO = SAO or {}
SAO.Places = SAO.Places or {}
local Pl = SAO.Places

-- What a desperate person might go somewhere to LOOK FOR.
--
-- The operator set the frame: a person cannot know anything up
-- front beyond this being a house with things in it - it is the
-- perception and discretion of desperation. So this is coarse on
-- purpose. It is an INTERPRETATION of the map's vocabulary, which is
-- authored and meant to be - but every stem below matches at least
-- one room name the shipped map actually uses, and `places_test`
-- fails if any of them stops matching. No stem here is invented.
Pl.OFFERS = {
    water = { "bathroom", "laundry", "waterstorage", "pool" },
    food = { "kitchen", "grocery", "bakery", "dining", "cafe",
             "cafeteria", "restaurant", "butcher", "barn", "produce",
             "potato", "egg", "jerky", "candystore", "cornerstore",
             "conveniencestore", "gigamart", "icecream", "hotdogstand",
             "bar", "liquorstore", "brewery", "spiffo", "burger",
             "pizza", "donut", "sushi", "catfish", "fishchips",
             "jayschicken", "deepfry" },
    shelter = { "bedroom", "livingroom", "motelroom", "hall", "closet",
                "dorm", "church", "library", "lobby", "theatre" },
    tools = { "toolstore", "mechanic", "garage", "workshop", "shed",
              "warehouse", "carsupply", "construction", "welding",
              "blacksmith", "carpentry", "railroadrepair", "factory",
              "outdoorsupply", "camping", "hunting", "fishingstorage",
              "gardenstore", "generalstore", "hoarder" },
    medicine = { "medical", "pharmacy", "hospital", "dentist",
                 "laboratory", "morgue" },
    -- The five above are what a body needs. This one is what the mod
    -- already says survivors go looking for: the ErrandRadius option
-- promises "food, water, weapons, and ammunition". These remain search
-- hints; arrival must observe exact native stock before acquisition.
    weapons = { "gunstore", "armysurplus", "armystorage", "armytent",
                "policelocker", "evidenceroom", "pawnshop", "hunting",
                "sportstore", "oldarmy" },
    -- Where drink commonly generates. Native fluids decide whether any
    -- usable water exists now.
    drink = { "grocery", "conveniencestore", "cornerstore", "gigamart",
              "liquorstore", "bar", "cafe", "brewery", "cafeteria",
              "generalstore", "gasstore", "gas2go" },
}

-- Rooms whose names LOOK like an offer and are not one. `kitchenwares`
-- sells pots; a starving person reading it as food from the road is a
-- believable mistake, but a mechanic reading `batfactory` as tools is
-- not - it makes baseball bats. Listed rather than hidden, so the
-- exceptions are visible and countable.
Pl.NOT_REALLY = {
    kitchenwares = true,
}

local function lower(s)
    return string.lower(tostring(s or ""))
end

-- ---------------------------------------------------------------
-- [B38/R10a] What a room can generate
-- ---------------------------------------------------------------
--
-- The stems above read a room's NAME. The distribution definitions say
-- what kinds of item can generate there. They do not open a container,
-- establish current quantity, or turn possibility into availability.
--
-- `SuburbsDistributions[room][container].procList` names procedural
-- lists, and `ProceduralDistributions.list[name].items` is a flat
-- array of item name and weight. Seventy-five of the operator's mods
-- write into those tables, and 1143 item script files ship among
-- them - so reading the merged table is how every one of their
-- additions reaches exploration without this mod knowing their names.
--
-- An item's offer is derived from WHAT IT DOES TO A BODY, not from
-- what it is called: `getHungerChange() < 0` is a possible food spawn,
-- whoever made it. A modded ration pack nobody has heard of can guide
-- a search because the engine says eating it helps; SAO_WorldSources
-- must still observe its exact native item before anybody can take it.
local MATERIAL = {
    food = true, water = true, drink = true,
    tools = true, weapons = true, medicine = true,
}

-- Raw script categories, not display strings. Anything unrecognised
-- contributes nothing rather than guessing.
local CATEGORY_OFFERS = {
    FirstAid = "medicine",
    Weapon = "weapons",
    Tool = "tools",
    Material = "tools",
}

Pl.contentCache = Pl.contentCache or {}

local function offersOfItem(name)
    -- [C18] The engine's item lookup takes a String and throws on a
    -- Double. `absorb` used to hand it every other entry of a table it
    -- assumed was name/weight interleaved; where that assumption was
    -- wrong it handed over a weight. Refusing a non-string here is the
    -- second half of that fix and costs nothing (F-048).
    if type(name) ~= "string" then return nil end
    local item = nil
    pcall(function()
        local sm = getScriptManager()
        -- procLists carry BARE names; scripts are namespaced.
        item = sm:getItem(name) or sm:getItem("Base." .. name)
    end)
    if not item then return nil end
    local out, any = {}, false
    pcall(function()
        if (item:getHungerChange() or 0) < 0 then
            out.food = true
            any = true
        end
        if (item:getThirstChange() or 0) < 0 then
            out.water = true
            out.drink = true
            any = true
        end
        local offer = CATEGORY_OFFERS[tostring(item:getDisplayCategory())]
        if offer then
            out[offer] = true
            any = true
        end
    end)
    if not any then return nil end
    return out
end

local function absorb(out, names)
    if type(names) ~= "table" then return false end
    local any = false
    -- [C18] Every STRING in the table, not every other entry.
    --
    -- This read "flat array of name, weight, name, weight" and stepped
    -- by two on that promise. The engine's own lists do not all have
    -- that shape: some are plain arrays of names, and some do not start
    -- on a name. So the stride skipped half the names in the first
    -- shape and handed a weight to getItem() in the second, which threw
    -- 276 times in the operator's first session on this build (F-048) -
    -- and every throw abandoned the rest of that room's contents, so
    -- what a place offers ([B38]) was being read half-blind.
    --
    -- Taking the strings is correct for both shapes and needs no
    -- assumption about the layout at all.
    for i = 1, #names do
        local entry = names[i]
        if type(entry) == "string" then
            local offers = offersOfItem(entry)
            if offers then
                for k in pairs(offers) do out[k] = true end
                any = true
            end
        end
    end
    return any
end

-- What the game says may generate in a room of this name. `false` when
-- the distribution tables have nothing to say, so the stems still guide
-- exploration.
function Pl.contentOffers(roomName)
    local name = lower(roomName)
    if Pl.contentCache[name] ~= nil then return Pl.contentCache[name] end

    local out, any = {}, false
    pcall(function()
        local rooms = SuburbsDistributions
        local room = rooms and rooms[name]
        if type(room) ~= "table" then return end
        for _, container in pairs(room) do
            if type(container) == "table" then
                if absorb(out, container.items) then any = true end
                if type(container.procList) == "table" then
                    for _, entry in ipairs(container.procList) do
                        local lists = ProceduralDistributions
                            and ProceduralDistributions.list
                        local list = lists and entry and entry.name
                            and lists[entry.name]
                        if list and absorb(out, list.items) then
                            any = true
                        end
                    end
                end
            end
        end
    end)

    Pl.contentCache[name] = any and out or false
    return Pl.contentCache[name]
end

-- Which possibilities a room suggests. A name may suggest more than
-- one (`hospitalhallway` is medicine and shelter) and that is the
-- point - places are not single-purpose.
--
-- [B38/R10a] Distribution-derived possibility wins where the game has an
-- answer. Shelter comes from the name either way: no item can express
-- being indoors. None of these flags assert current material stock.
function Pl.offersOf(roomName)
    local stems = Pl.stemOffersOf(roomName)
    local content = Pl.contentOffers(roomName)
    if not content then return stems end

    local out = {}
    if stems then
        for k in pairs(stems) do
            if not MATERIAL[k] then out[k] = true end
        end
    end
    local any = false
    for k in pairs(content) do out[k] = true; any = true end
    -- [B44] `next` is not callable here. The engine's Lua is Kahlua,
    -- and this threw "Object tried to call nil" on every dormant tick -
    -- inside the pcall in `Pl.at`, so it was caught and the county went
    -- on choosing places with no contents resolved while the console
    -- filled. A one-line emptiness test cost the whole of [B38]'s work
    -- reading what a room actually holds.
    --
    -- `pairs` is what the rest of this file uses and demonstrably
    -- works; emptiness is now decided by whether anything was written,
    -- which needs no library function at all.
    if not any then
        for _ in pairs(out) do any = true; break end
    end
    if not any then return nil end
    return out
end

function Pl.stemOffersOf(roomName)
    local name = lower(roomName)
    if name == "" or Pl.NOT_REALLY[name] then return nil end
    local out, any = {}, false
    for offer, stems in pairs(Pl.OFFERS) do
        for _, stem in ipairs(stems) do
            if string.find(name, stem, 1, true) then
                out[offer] = true
                any = true
                break
            end
        end
    end
    if not any then return nil end
    return out
end

-- ---------------------------------------------------------------
-- The map itself
-- ---------------------------------------------------------------

-- Buildings never change their rooms, so a building read once is a
-- building read forever. Keyed by BuildingDef id.
Pl.cache = Pl.cache or {}

-- One grid for the life of the world. `Pl.around` probes eighty-one
-- points, and fetching the grid inside each of them would be eighty
-- needless calls through pcall for an object that never changes.
local gridCache = nil

local function metaGrid()
    if gridCache then return gridCache end
    pcall(function() gridCache = getWorld():getMetaGrid() end)
    return gridCache
end

-- Read one building into a plain Lua record. Returns nil when the
-- coordinate holds no building, which is most of the map.
function Pl.at(x, y)
    local grid = metaGrid()
    if not grid then return nil end

    local def = nil
    pcall(function() def = grid:getBuildingAt(math.floor(x), math.floor(y)) end)
    if not def then return nil end

    local id = nil
    pcall(function() id = def:getID() end)
    if not id then return nil end
    if Pl.cache[id] then return Pl.cache[id] end

    -- `offers` is retained as the established public field name, but it is
    -- possibility only. Current quantity belongs exclusively to WorldSources.
    local place = { id = id, offers = {}, roomCount = 0 }
    local ok = pcall(function()
        place.minX, place.minY = def:getX(), def:getY()
        place.maxX, place.maxY = def:getX2(), def:getY2()
        local rooms = def:getRooms()
        local n = rooms and rooms:size() or 0
        place.roomCount = n
        for i = 0, n - 1 do
            local room = rooms:get(i)
            local offers = room and Pl.offersOf(room:getName())
            if offers then
                for offer in pairs(offers) do place.offers[offer] = true end
            end
        end
    end)
    if not ok or not place.minX then return nil end

    place.cx = math.floor((place.minX + place.maxX) / 2)
    place.cy = math.floor((place.minY + place.maxY) / 2)
    Pl.cache[id] = place
    return place
end

-- Does this place suggest anything worth searching for? A building of rooms
-- without a material hint is still a building, but not a directed errand.
function Pl.offersAnything(place)
    if not place then return false end
    for _ in pairs(place.offers) do return true end
    return false
end

-- ---------------------------------------------------------------
-- Places within reach of a point
-- ---------------------------------------------------------------

-- Probing every tile in a 48-tile box is 2,304 Java calls. Buildings
-- are far larger than the stride, so a lattice finds them at a
-- fraction of the cost - and the answer is cached per origin because
-- a survivor's home does not move.
local PROBE_STRIDE = 6

Pl.around_cache = Pl.around_cache or {}

function Pl.around(x, y, reach)
    x, y = math.floor(x), math.floor(y)
    local key = x .. ":" .. y .. ":" .. reach
    if Pl.around_cache[key] then return Pl.around_cache[key] end

    local seen, out = {}, {}
    local px = -reach
    while px <= reach do
        local py = -reach
        while py <= reach do
            local place = Pl.at(x + px, y + py)
            if place and not seen[place.id] then
                seen[place.id] = true
                out[#out + 1] = place
            end
            py = py + PROBE_STRIDE
        end
        px = px + PROBE_STRIDE
    end

    Pl.around_cache[key] = out
    return out
end

-- ---------------------------------------------------------------
-- What they KNOW ([C25], DR-027)
-- ---------------------------------------------------------------
--
-- The operator's ruling: people operate off social structures and
-- social incentives and personal desires and understanding and
-- awareness - never a permitted radius.
-- The probe is what a person NOTICES around them; this is what they
-- KNOW - their own observed places - and how far knowledge reaches is
-- not a dial. The horizon derives from the engine's own neighborhood
-- quantum (the cell), and it moves with the asker: knowledge anchors
-- to where you live and where you stand, not to a sandbox number.

-- The native Lua global exposes IsoCell's static cell-size method. Calling
-- that static method on a cell instance fails in the actual Lua binding.
-- The fallback is the installed B42.20 format for bodyless execution.
local cellSpanCache = nil
function Pl.cellSpan()
    if cellSpanCache then return cellSpanCache end
    local span = nil
    if getCellSizeInSquares then span = getCellSizeInSquares() end
    cellSpanCache = (type(span) == "number" and span > 0) and span or 256
    return cellSpanCache
end

-- The two horizons, both DERIVED. Your part of town is half a cell
-- out from where you anchor; commitment past that - a person in real
-- need crossing town - reaches a cell and a half. Nothing here is a
-- sandbox option, and that is the point.
function Pl.comfortHorizon() return math.floor(Pl.cellSpan() / 2) end
function Pl.commitHorizon() return math.floor(Pl.cellSpan() * 1.5) end

-- Forget the map. Only for a world change - the cache is keyed by
-- building id and origin, both of which belong to one world.
function Pl.reset()
    Pl.cache = {}
    Pl.around_cache = {}
    Pl.contentCache = {}
    gridCache = nil
    cellSpanCache = nil
end

if Events and Events.OnInitGlobalModData then
    if Pl.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(Pl.onInitGlobalModData)
    end
    Pl.onInitGlobalModData = function() Pl.reset() end
    Events.OnInitGlobalModData.Add(Pl.onInitGlobalModData)
end

return Pl
