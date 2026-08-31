-- SAO_Places - the county's own map, read as places.
--
-- [B37]. The mod had a full social ontology and no material one. A
-- dormant survivor's whole day was:
--
--     rec.dayGoalX = rec.homeX + ZombRand(-24, 25)
--
-- a RANDOM COORDINATE inside a 48-tile box, walked at four tiles a
-- move, forever, under a daily dice roll that eventually kills them.
-- The operator, exactly right: that is not a living mechanic.
--
-- The county already knows where everything is. `IsoMetaGrid` is
-- built for the WHOLE map at world start and is independent of which
-- cells are loaded - it is what the map screen and the spawn regions
-- read. Every accessor used here is a public method on a class the
-- game ships:
--
--     getWorld():getMetaGrid()          IsoWorld.getMetaGrid()
--     metaGrid:getBuildingAt(x, y)      -> BuildingDef
--     building:getRooms()               -> ArrayList<RoomDef>
--     building:getX/getY/getX2/getY2/getID
--     room:getName()                    -> String
--
-- `RoomDef:getName()` is the ontology. The map itself calls a room
-- `kitchen`, `bathroom`, `burgerkitchen`, `mechanic`, `barn` - and
-- the shipped Distributions.lua is keyed by exactly those names,
-- under a header that reads "Room List (A-Z)". That table is the
-- vocabulary; it is not a guess about one.
--
-- This module holds only what is TRUE of the map. What a given
-- survivor knows about a place is belief and lives in SAO_Perception;
-- what they do about it is SAO_Population's.

SAO = SAO or {}
SAO.Places = SAO.Places or {}
local Pl = SAO.Places

-- What a desperate person would go somewhere FOR.
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
    -- promises "food, water, weapons, and ammunition", and until now
    -- the county had nowhere that meant any of it.
    weapons = { "gunstore", "armysurplus", "armystorage", "armytent",
                "policelocker", "evidenceroom", "pawnshop", "hunting",
                "sportstore", "oldarmy" },
    -- [B37] Where drink is kept in QUANTITY, as against a house
    -- kitchen with a bottle or two in it. This is what water means
    -- once the county has lost pressure, so it is deliberately narrow:
    -- a shop, a bar, a brewery, a cafeteria - not every room that has
    -- ever held food.
    drink = { "grocery", "conveniencestore", "cornerstore", "gigamart",
              "liquorstore", "bar", "cafe", "brewery", "cafeteria",
              "generalstore", "gasstore", "gas2go" },
}

-- [B37] Which water depends on the mains.
--
-- A bathroom is only a water source while Knox County still has
-- pressure. The engine decides when that ends and the mod does not
-- get a say: `SandboxOptions.randomWaterShut()` rolls a day count out
-- of the WaterShut setting and `getWaterShutModifier()` returns it,
-- both javap-verified. A pool and a water tank do not care.
Pl.MAINS_WATER = { bathroom = true, laundry = true }

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
-- [B38] What a room actually CONTAINS
-- ---------------------------------------------------------------
--
-- The stems above read a room's NAME. The game knows what is in it.
--
-- `SuburbsDistributions[room][container].procList` names procedural
-- lists, and `ProceduralDistributions.list[name].items` is a flat
-- array of item name and weight. Seventy-five of the operator's mods
-- write into those tables, and 1143 item script files ship among
-- them - so reading the merged table is how every one of their
-- additions reaches the county without this mod knowing any of their
-- names.
--
-- An item's offer is derived from WHAT IT DOES TO A BODY, not from
-- what it is called: `getHungerChange() < 0` is food, whoever made
-- it. That is the whole reason this beats the stems - a modded
-- ration pack nobody has ever heard of is food because the engine
-- says eating it helps.
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
    -- Flat array of name, weight, name, weight.
    for i = 1, #names, 2 do
        local offers = offersOfItem(names[i])
        if offers then
            for k in pairs(offers) do out[k] = true end
            any = true
        end
    end
    return any
end

-- What the game says is in a room of this name. `false` when the
-- distribution tables have nothing to say, so the stems still answer.
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

-- Which of the offers a room provides. A name may offer more than
-- one (`hospitalhallway` is medicine and shelter) and that is the
-- point - places are not single-purpose.
--
-- [B38] Contents win where the game has an answer, because the game
-- knows and a stem only guesses. Shelter is the exception and comes
-- from the name either way: no item can express being indoors.
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
    -- The mains question is about plumbing, which is a fact about the
    -- room rather than about anything sitting in it.
    if out.water and not (stems and stems.water) then
        out.storedWater = true
    elseif out.water and stems and stems.storedWater then
        out.storedWater = true
    end
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
    -- [B37] Water that does not come out of a tap survives the
    -- county losing pressure. Marked here, on the room, because it is
    -- a fact about the room rather than about today.
    if out.water then
        local mains = false
        for stem in pairs(Pl.MAINS_WATER) do
            if string.find(name, stem, 1, true) then
                mains = true
                break
            end
        end
        if not mains then out.storedWater = true end
    end
    return out
end

-- ---------------------------------------------------------------
-- What is true of the county TODAY
-- ---------------------------------------------------------------

-- Has Knox County still got water pressure? The engine decides the
-- day and the mod reads it: `randomWaterShut()` rolls a day count out
-- of the WaterShut sandbox setting into `waterShutModifier`, and
-- `getWaterShutModifier()` returns it. A setting of Disabled leaves a
-- value at or below zero, which means it never happens.
function Pl.waterIsOn()
    local shutDay = nil
    pcall(function()
        shutDay = getSandboxOptions():getWaterShutModifier()
    end)
    if not shutDay or shutDay <= 0 then return true end
    local days = 0
    pcall(function()
        days = GameTime.getInstance():getWorldAgeHours() / 24.0
    end)
    return days < shutDay
end

-- ---------------------------------------------------------------
-- [B39] The shelves are not infinite
-- ---------------------------------------------------------------
--
-- [B37] closed on what it could not do: "they cannot fail to find
-- water." [B37] answered that for water, by taking the mains away on
-- the engine's own clock. Food had no equivalent - a kitchen fed
-- everybody who ever walked into it, forever, and two hundred people
-- could live off one grocery.
--
-- A place is spent by being VISITED. That is derived from what the
-- county actually does rather than from a stock number invented per
-- building, and it is what makes places compete: a shop everyone
-- raids is empty, and the survivor who gets there second has to walk
-- further.
--
-- How much a place holds comes from how big it is - `getRoomsNumber`
-- on the BuildingDef, which the map already answers. And it refills
-- on the game's OWN loot clock: `SandboxVars.LootRespawn` decides
-- whether it ever does, `HoursForLootRespawn` says how often. The
-- shipped default is no respawn at all, so by default the county
-- empties permanently - which is the game's own answer to this
-- question and not mine.
--
-- The player's looting is NOT counted. There is no cheap way to know
-- what they emptied, so a shop the player stripped still reads full
-- to the county. Said plainly rather than left to be discovered.
local TAKES_PER_ROOM = 3
local MIN_CAPACITY = 4
local MAX_CAPACITY = 60

Pl.taken = Pl.taken or {}

local function stockStore()
    local store = nil
    pcall(function()
        store = ModData.getOrCreate("SurvivorAwareness_Places")
    end)
    if type(store) ~= "table" then return nil end
    store.taken = store.taken or {}
    return store
end

function Pl.capacityOf(place)
    local rooms = (place and place.roomCount) or 1
    local cap = rooms * TAKES_PER_ROOM
    if cap < MIN_CAPACITY then cap = MIN_CAPACITY end
    if cap > MAX_CAPACITY then cap = MAX_CAPACITY end
    return cap
end

-- The game's own refill clock. Nil when loot never respawns, which is
-- the shipped default.
function Pl.refillHours()
    local on, hours = nil, nil
    pcall(function()
        on = SandboxVars and SandboxVars.LootRespawn
        hours = SandboxVars and tonumber(SandboxVars.HoursForLootRespawn)
    end)
    -- Option 1 is "None"; anything else is a real cadence.
    if not on or on == 1 then return nil end
    if not hours or hours <= 0 then return nil end
    return hours
end

local function nowHours()
    local h = 0
    pcall(function()
        h = GameTime.getInstance():getWorldAgeHours()
    end)
    return h
end

-- How many takes a place has had, after letting the loot clock give
-- some back.
function Pl.takesAt(placeId)
    local store = stockStore()
    local row = store and store.taken and store.taken[tostring(placeId)]
    if not row then return 0 end
    local taken = tonumber(row.n) or 0
    local refill = Pl.refillHours()
    if refill then
        local elapsed = nowHours() - (tonumber(row.at) or 0)
        local back = math.floor(elapsed / refill)
        if back > 0 then taken = taken - back end
    end
    if taken < 0 then taken = 0 end
    return taken
end

-- Somebody took something. Recorded against the place, not the person.
function Pl.take(place)
    if not place or not place.id then return end
    local store = stockStore()
    if not store then return end
    local key = tostring(place.id)
    local row = store.taken[key] or { n = 0, at = 0 }
    row.n = Pl.takesAt(place.id) + 1
    row.at = nowHours()
    store.taken[key] = row
end

-- Is there anything left here?
function Pl.isSpent(place)
    if not place or not place.id then return false end
    return Pl.takesAt(place.id) >= Pl.capacityOf(place)
end

-- What a place offers RIGHT NOW, as opposed to what its rooms are.
-- The difference is the whole point: a survivor remembers a bathroom
-- with water in it, walks back to it after the mains have gone, and
-- finds a dry tap. Belief is allowed to be wrong about the world;
-- that is what makes it belief.
function Pl.offersNow(place)
    if not place then return nil end
    local out = {}
    for k in pairs(place.offers) do out[k] = true end
    out.storedWater = nil
    if not Pl.waterIsOn() then
        -- The taps are dry. What is left is what was standing or
        -- stacked: a tank, a pool, or somewhere that kept drink by
        -- the pallet. A house kitchen with a bottle in it is not a
        -- water source for a day, so houses genuinely lose theirs -
        -- which is the whole change, and it does not show in a count
        -- of room NAMES because `bathroom` is one name in nearly
        -- every building on the map.
        if place.offers.storedWater or place.offers.drink then
            out.water = true
        else
            out.water = nil
        end
    end
    -- [B39] Emptied. A building that has been picked over is still a
    -- building - it shelters, and it is still somewhere they know -
    -- but there is nothing left in it to go there FOR.
    if Pl.isSpent(place) then
        for k in pairs(MATERIAL) do out[k] = nil end
    end
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

-- Does this place offer anything at all? A building of rooms none of
-- which read as an offer is still a building - it is shelter by being
-- indoors - but it is not somewhere to GO for a thing.
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

-- Forget the map. Only for a world change - the cache is keyed by
-- building id and origin, both of which belong to one world.
function Pl.reset()
    Pl.cache = {}
    Pl.around_cache = {}
    Pl.contentCache = {}
    gridCache = nil
end

return Pl
