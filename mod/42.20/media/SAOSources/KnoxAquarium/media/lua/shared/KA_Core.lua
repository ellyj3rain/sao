KnoxAquarium = KnoxAquarium or {}
local K = KnoxAquarium
require 'KA_FishRegistry'
K.capacity = 20 -- litres; intentionally modest for initial testing
K.maxFish = 4
-- The original tank's old 30 cm limit. NOT enforced since 0.13.0: the original
-- tank draws every resident as one of its own aquarium fish whatever the real
-- catch is, so a bigger fish has nothing it could fail to be drawn as. The
-- name stays for anything outside this mod that may still read it.
K.maxLength = 30 -- centimetres
-- These two have always described the one tank this mod has. They stay the
-- single source of truth for it; the tier table mirrors them so that adding
-- bigger tanks later cannot quietly change the tank players already own.
if K.tankTiers and K.tankTiers.standard then
    local standard = K.tankTiers.standard
    standard.capacity = K.capacity
    standard.maxFish = K.maxFish
end
function K.now() return getGameTime():getWorldAgeHours() end

-- ------------------------------------------------------- reading mod data
-- IsoObject.getModData() CREATES an empty table on any object that has none
-- and keeps it for the object's lifetime (B42.20 IsoObject.getModData). Every
-- scan of a square - a chunk loading, the once-a-minute refresh, the comfort
-- check - used to call it on walls, floors and trees, giving each one a table.
-- hasModData() answers without allocating. Test doubles and anything that is
-- not an IsoObject may lack it, so fall back to getModData() for those.
function K.modDataOf(obj)
    if not obj then return nil end
    if obj.hasModData and not obj:hasModData() then return nil end
    return obj:getModData()
end
function K.tankData(obj)
    local md = K.modDataOf(obj)
    return md and md.KnoxAquarium or nil
end
function K.partData(obj)
    local md = K.modDataOf(obj)
    local p = md and md.KnoxAquariumPart or nil
    return type(p) == 'table' and p or nil
end
-- How long a fish survives out of water, in GAME hours.
--
-- This used to be a flat 30-60 game minutes, which sounds generous and is not:
-- game time runs far faster than real time. At the default day length of one
-- real hour per game day, one game hour is 2.5 real minutes, so "30 game
-- minutes" gave the player about 75 SECONDS to carry a fish home. That is why
-- fish kept dying on the way to the tank.
--
-- The window is now expressed in the time the player actually experiences and
-- converted to game hours from the world's own day length, so it holds up
-- whatever that is set to: 10 real minutes at Fishing 0, rising to 20 at
-- Fishing 10.
-- Defaults match the flat constants this replaced; PLAYTEST 2026-09-16 made
-- them sandbox options (KnoxAquarium.FishSurviveMinMinutes/MaxMinutes) so a
-- server can loosen or tighten the window. K.sandbox reads live, so a value
-- read before SandboxVars is populated still falls back to the same number a
-- save made before the option existed would have used.
K.DRY_MINUTES_MIN = 10   -- real minutes, unskilled
K.DRY_MINUTES_MAX = 20   -- real minutes, Fishing 10

-- Real minutes in one game day. 60 is the game's default (a one-hour day).
function K.realMinutesPerDay()
    local ok, v = pcall(function() return getGameTime():getMinutesPerDay() end)
    if ok and type(v) == 'number' and v > 0 then return v end
    return 60
end

function K.dryHours(skill)
    local s = math.max(0, math.min(10, tonumber(skill) or 0))
    -- K.sandbox reads media/sandbox-options.txt values (KnoxAquarium.FishSurvive
    -- Min/MaxMinutes), defaulting to the original hardcoded constants above, so
    -- a save/server that never sets these behaves exactly as it always has.
    local lo = tonumber(K.sandbox('FishSurviveMinMinutes', K.DRY_MINUTES_MIN)) or K.DRY_MINUTES_MIN
    local hi = tonumber(K.sandbox('FishSurviveMaxMinutes', K.DRY_MINUTES_MAX)) or K.DRY_MINUTES_MAX
    if hi < lo then hi = lo end
    local minutes = lo + (hi - lo) * (s / 10)
    -- real minutes -> game hours
    return minutes * 24 / K.realMinutesPerDay()
end

function K.deadline(now, skill) return now + K.dryHours(skill) end
function K.alive(item, now)
    local d = item:getModData().KnoxAquariumFish
    return d ~= nil and type(d.expires) == 'number' and now < d.expires
        and not item:isCooked() and not item:isBurnt() and not item:isRotten()
end
function K.canAdd(d, item, now)
    if not K.alive(item, now) then return false, 'This fish is no longer alive.' end
    local tier = K.tierOf(d)
    local length = item:getModData().fishing_FishSize
    -- Every rod catch is measured by the base game. A fish with no length is not
    -- one this mod marked on the rod, whatever else it is.
    if type(length) ~= 'number' then
        return false, 'That fish was never measured on the rod, so it cannot go in a tank.'
    end
    -- A tier MAY cap individual size. The original tank does not (nil): it always
    -- shows a resident, drawn as one of its own aquarium fish, whatever the catch.
    local cap = tier.maxIndividualLength
    if cap and length > cap then
        -- Name the fish and its measurement rather than a bare limit.
        local species = K.speciesOf(item)
        local who = species and K.speciesLabel(species) or nil
        if who then
            return false, who..' is '..math.floor(length)..' cm - this tank accepts fish up to '..cap..' cm.'
        end
        return false, 'This tank accepts fish up to '..cap..' cm.'
    end
    -- Species gate. A fish can measure small today and still belong to a species
    -- that outgrows the tank. On the standard tank this passes everything, so
    -- nothing a player could add before is refused now; it exists so a large
    -- aquarium can be the thing that unlocks the big species.
    local class, species = K.fishClass(item, length)
    if class and (tier.maxSpeciesClass or K.SIZE.XL) < class then
        local needed = K.tierForClass(class)
        return false, (species and K.speciesLabel(species) or 'That species')
            ..' grows too large for this tank'
            ..(needed and (' - it needs a '..needed.label..'.') or ' and has nowhere to go yet.')
    end
    local itemType
    local gotType, full = pcall(function() return item:getFullType() end)
    if gotType and type(full) == 'string' then itemType = full end
    local allowed, why = K.speciesAllowed(d, itemType)
    if not allowed then return false, why end
    if d.water < tier.capacity - 0.001 then
        return false, 'Fill the aquarium to '..tier.capacity..' litres first.'
    end
    if #d.fish >= tier.maxFish then return false, 'The aquarium is full ('..tier.maxFish..' fish).' end
    return true
end

-- A readable species name for messages: the item's display name where the game
-- can give one, the bare type as a last resort.
function K.speciesLabel(species)
    if type(species) ~= 'table' or type(species.itemType) ~= 'string' then return nil end
    if species.label then return species.label end
    local label = string.match(species.itemType, '%.(.+)$') or species.itemType
    pcall(function()
        local script = getScriptManager():FindItem(species.itemType)
        if script then
            local display = script:getDisplayName()
            if type(display) == 'string' and display ~= '' then label = display end
        end
    end)
    species.label = label
    return label
end
-- How far from the player a tank may be placed. Two tiles was cramped enough
-- that players reported placement as finnicky.
K.placeRange = 4

-- How far away the placement CURSOR may pick a tile (Playtest 2026-09-15, Jay:
-- "spawning a tank from farther away effectively requires me to walk next to it
-- before I can place it"). Past K.placeRange the player walks over first, the
-- way vanilla furniture placement does (ISBuildingObject.tryBuild -> walkTo ->
-- luautils.walkAdj), and the full rule is checked again on arrival. K.placeRange
-- is still the only range the SERVER acts in, so nothing about who may do what,
-- or from where, changes in multiplayer. Kept to a room or two, not the map.
K.placeWalkRange = 12

-- The one rule both the placement preview and the server use. It follows what
-- the base game asks of its own movable furniture - a floor, not water, not
-- inside a vehicle - rather than demanding a completely empty square. Requiring
-- an empty square is what made this feel fussy: a stray fork or a rug was enough
-- to refuse a perfectly good spot.
-- `ignore` (optional) is a character whose own presence on the tile does not
-- count: the player who is about to walk off it to put a tank there. The server
-- never passes it.
function K.canPlaceOn(square, player, ignore)
    if not square then return false, 'No tile there.' end
    local ok, floor = pcall(function() return square:getFloor() end)
    if not ok or not floor then return false, 'That spot has no floor.' end
    local solid = false
    pcall(function() solid = square:isSolid() end)
    if solid then return false, 'That tile is solid.' end
    local water = false
    pcall(function() water = square:has(IsoFlagType.water) end)
    if water then return false, 'The aquarium cannot go in water.' end
    local vehicle = false
    pcall(function() vehicle = square:isVehicleIntersecting() end)
    if vehicle then return false, 'A vehicle is in the way.' end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local md = K.modDataOf(objects:get(i))
        if md and (md.KnoxAquarium or md.KnoxAquariumPart) then
            return false, 'There is already an aquarium on that tile.'
        end
    end
    -- Furniture already standing there - a counter, a table, a fridge - carries
    -- the flag vanilla uses to stop you walking into it. A tank drawn into the
    -- middle of a counter is not a placement anybody wants, and two solid
    -- things on one tile make the collision meaningless. A rug, a fork or a
    -- dropped bag is not solid and still does not get in the way.
    local occupied = false
    pcall(function() occupied = square:isSolidTrans() end)
    if occupied then return false, 'Something is already standing there.' end
    -- Never put a solid tank on top of somebody - the placer, another player, a
    -- zombie, an animal: they would be shut inside the tile. Vanilla's own
    -- furniture placement refuses a tile with a character on it for the same
    -- reason (ISBuildingObject, isFreeOrMidair(blockedByCharacters)).
    local someone = false
    pcall(function()
        local movers = square:getMovingObjects()
        for i = 0, movers:size() - 1 do
            if ignore == nil or movers:get(i) ~= ignore then someone = true; break end
        end
    end)
    if someone then return false, 'Someone or something is standing there.' end
    if player then
        local psq = player:getSquare()
        if square:getZ() ~= player:getZ() then return false, 'Choose a tile on your own floor.' end
        if math.abs(square:getX() - player:getX()) > K.placeRange
        or math.abs(square:getY() - player:getY()) > K.placeRange then
            return false, 'Stand closer to where you want it.'
        end
        if psq and square:isBlockedTo(psq) then return false, 'Something is between you and that tile.' end
    end
    return true
end

-- Is this a tile a tank could EVER stand on - a real floor with nothing solid,
-- no water, no furniture and no aquarium on it? This is only the half of
-- canPlaceOn that describes the tile itself. The other half - someone standing
-- on it, too far away, a wall in between, a car in the way - describes the
-- moment, and the player can fix it by moving.
--
-- The world menu uses this to decide whether to APPEAR, and canPlaceOn to
-- decide whether Place is clickable. 0.13 RC1 used canPlaceOn for both, so
-- right-clicking the tile you were standing on - in a new save, the obvious
-- first thing to try - showed no aquarium entry at all and the mod looked
-- uninstalled. canPlaceOn itself is unchanged: the server still validates every
-- placement with the full rule.
function K.isPlaceableFloor(square)
    if not square then return false end
    local ok, floor = pcall(function() return square:getFloor() end)
    if not ok or not floor then return false end
    local solid, water, occupied = false, false, false
    pcall(function() solid = square:isSolid() end)
    if solid then return false end
    pcall(function() water = square:has(IsoFlagType.water) end)
    if water then return false end
    pcall(function() occupied = square:isSolidTrans() end)
    if occupied then return false end
    local mine = false
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local md = K.modDataOf(objects:get(i))
            if md and (md.KnoxAquarium or md.KnoxAquariumPart) then mine = true end
        end
    end)
    return not mine
end

-- ------------------------------------------------------ two-tile tanks
-- The vanilla sprite a display tank's second-tile PART is created from. It is
-- solidtrans and nothing else: no container, not movable, not scrappable - so
-- on the server it blocks its tile exactly as the tank's own sprite blocks the
-- tank's, and it can never grow a container of its own the way the tank's
-- table sprite does. Clients draw it as nothing (KA_Client).
K.PART_SPRITE = 'industry_02_304'

function K.isPart(obj)
    local ok, p = pcall(K.partData, obj)
    return ok and p ~= nil
end

-- The tank a part belongs to, or nil when it has none (or is not loaded).
function K.masterOf(part)
    local ok, p = pcall(K.partData, part)
    if not ok or not p then return nil end
    local cell = getCell and getCell()
    local sq = cell and cell:getGridSquare(p.x, p.y, p.z)
    if not sq then return nil end
    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local o = objects:get(i)
        if K.tankData(o) then return o end
    end
    return nil
end

-- The part on `sq` that belongs to the tank standing at x,y,z, or nil.
function K.partOn(sq, x, y, z)
    if not sq then return nil end
    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local o = objects:get(i)
        local p = K.partData(o)
        if p and p.x == x and p.y == y and p.z == z then return o end
    end
    return nil
end

-- The square a tank's second tile is on, or nil for a one-tile tank.
function K.partSquare(d, sq)
    if not sq then return nil end
    local dx, dy = K.partDelta(d)
    if not dx then return nil end
    local cell = getCell and getCell()
    if not cell then return nil end
    return cell:getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
end

-- The placement rule for a WHOLE tank: its own tile and, for a two-tile tank,
-- the second tile too, with no wall, window or door between the two. The
-- preview and the server both ask this, so they can never disagree.
function K.canPlaceTank(square, player, tierId, rotation, ignore)
    local ok, why = K.canPlaceOn(square, player, ignore)
    if not ok then return ok, why end
    local probe = {tier = tierId, rotation = rotation}
    local second = K.partSquare(probe, square)
    if not K.partDelta(probe) then return true end
    if not second then return false, 'There is not room for a tank this long here.' end
    local ok2, why2 = K.canPlaceOn(second, nil, ignore)
    if not ok2 then
        return false, 'This tank stands on two tiles and the second is not free. '..(why2 or '')
    end
    local walled = false
    pcall(function() walled = square:isBlockedTo(second) end)
    if walled then return false, 'A wall or door is in the way of the second tile.' end
    return true
end

-- The rule for the placement CURSOR: a tile the player can walk over to. It is
-- everything canPlaceTank asks of the tiles themselves, on the player's own
-- floor, within K.placeWalkRange - but not the "stand closer" or "something in
-- between" parts, which walking fixes, and the placer's own body on the tile
-- does not count (they walk off it). When the player arrives the full
-- canPlaceTank is asked again, and the server asks it too.
function K.canPlaceTankFrom(square, player, tierId, rotation)
    if not square then return false, 'No tile there.' end
    if player then
        if square:getZ() ~= player:getZ() then return false, 'Choose a tile on your own floor.' end
        if math.abs(square:getX() - player:getX()) > K.placeWalkRange
        or math.abs(square:getY() - player:getY()) > K.placeWalkRange then
            return false, 'That is too far away.'
        end
    end
    return K.canPlaceTank(square, nil, tierId, rotation, player)
end

function K.waterSource(item)
    local f = item:getFluidContainer()
    return f and f:getAmount()>0 and f:getSpecificFluidAmount(Fluid.Water)+f:getSpecificFluidAmount(Fluid.TaintedWater)>=f:getAmount()-0.0001
end

function K.appearance(d)
    local cap=K.cap(d)
    if #d.fish>0 then return d.water>=cap-0.001 and 'occupied' or 'occupied_low' end
    if d.water<=0 then return 'empty' end
    return d.water>=cap-0.001 and 'water' or 'low'
end

-- Wrap a frame number into 0..31.
--
-- This does NOT use the % operator. Lua 5.2+ defines a % b to take the sign of
-- the DIVISOR, so -11 % 32 is 21; Kahlua, the interpreter the game actually
-- runs, follows C fmod and keeps the sign of the DIVIDEND, so the same
-- expression is -11. The frame number is built from the tank's world position,
-- and west/north of the origin those coordinates are negative - so a tank at
-- x=-10911 y=-13045 asked for a sprite called "full_2_-11", which does not
-- exist, requestTexture refused it, and the tank froze on the last frame it had
-- managed to load. It reproduced nowhere in the test suite because the tests run
-- under Lua 5.4, where the same arithmetic is silently correct.
--
-- Floored division is the same in both, so it is used instead.
function K.frameIndex(frame)
    local n = math.floor(tonumber(frame) or 0)
    return n - math.floor(n / 32) * 32
end

-- Which colour arrangement the original tank's four fish wear.
--
-- The original tank draws every resident as one of its own aquarium fish,
-- whatever the real catch. Up to 30 cm - every fish a released build could ever
-- hold - it draws exactly the art it always has (0). A tank holding a bigger
-- fish, possible since 0.13.0, wears one of the arrangements picked from that
-- fish's species, so a big catfish and a big pike do not look identical. Same
-- fish, same paths, same scale: only which colour each fish wears.
--
-- Worked out from the tank's synced data alone, with a plain string hash, so
-- every client in multiplayer picks the same one and nothing is saved.
function K.fallbackPalette(d)
    local variants = math.floor(tonumber(K.tierOf(d).paletteVariants) or 0)
    if variants < 1 or type(d) ~= 'table' or type(d.fish) ~= 'table' then return 0 end
    local best, bestLen
    for _, fish in ipairs(d.fish) do
        local len = type(fish) == 'table' and tonumber(fish.length) or nil
        if len and (not bestLen or len > bestLen) then best, bestLen = fish, len end
    end
    if not best or bestLen <= K.maxLength then return 0 end
    local name = tostring(best.type or '')
    local h = 0
    for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 1000003 end
    -- floored, not %: see frameIndex below
    return h - math.floor(h / (variants + 1)) * (variants + 1)
end

local function baseRenderKey(d,frame)
    -- A dry habitat has its own art: the waterless tank, with its occupants
    -- scurrying about on the sand. An empty one falls back to the plain tank.
    if K.isDry(d) then
        local tier=K.tierOf(d)
        -- The original tank has its rats baked into its own dry art. A bigger
        -- tank draws its waterless art here and carries its rats in an overlay
        -- (tier.dryOverlayDir, see K.overlayKey), the way species fish are drawn.
        -- Either way an empty habitat is that tank's own empty art - never the
        -- original tank's, which is what every tier used to fall back to.
        local living=math.min(K.maxAnimals,#K.animals(d))
        if living>0 and not tier.dryOverlayDir then return 'KA_dry/'..living..'_'..K.frameIndex(frame) end
        return tier.art..'empty'
    end
    local tier=K.tierOf(d)
    local count=math.min(tier.maxFish,#d.fish)
    if count>0 then
        -- A tier with one water level has no part-filled swim art. It cannot be
        -- reached anyway - fish need a full tank to go in, and draining needs an
        -- empty one - but asking for art that was never rendered would leave the
        -- tank frozen on its last frame, so pin it to the level that exists.
        local level=(tier.swimLevels==1 or d.water>=tier.capacity-0.001) and 'full_' or 'low_'
        -- Only activate variants when the tier declares a complete, audited set.
        -- An unfinished art export must never make an existing tank disappear.
        local variant=tier.fishVariants and ('_'..K.displayTankVariant(d)) or ''
        local swim=tier.swim
        local palette=K.fallbackPalette(d)
        if palette>0 then swim=string.gsub(swim,'/$','')..'_p'..palette..'/' end
        return swim..level..count..variant..'_'..K.frameIndex(frame)
    end
    return tier.art..K.appearance(d)
end

-- Placement rotation uses the rebindable "Rotate building" action, not a fixed
-- key, so never tell the player to press R: report whatever they actually bound.
function K.rotateKeyName()
    local ok,name=pcall(function() return Keyboard.getKeyName(getCore():getKey('Rotate building')) end)
    if ok and type(name)=='string' and name~='' then return name end
    return 'the Rotate building key'
end

K.version='0.14.2'
function K.fishId(fish,index) return fish.id or ('legacy:'..index) end
function K.migrate(d)
    d.water=math.max(0,math.min(K.cap(d),tonumber(d.water) or 0))
    d.fish=d.fish or {};d.nextFishId=d.nextFishId or 0
    d.animals=d.animals or {};d.mode=K.mode(d)
    for i,fish in ipairs(d.fish) do fish.id=K.fishId(fish,i) end
    d.schema=2
    return d
end
function K.findFish(d,id)
    for i,fish in ipairs(d.fish) do if K.fishId(fish,i)==id then return fish,i end end
end

-- ---------------------------------------------------------------- dry tanks
-- A tank is either a WATER tank (fish, 20 litres) or a DRY tank (a terrarium for
-- a small live animal). The mode only changes on a completely empty tank, so the
-- two sets of rules never overlap and nothing can be stranded in the wrong one.
K.maxAnimals = 2
-- Matched case-insensitively against the animal's own type name. Kept as data so
-- adding a species later is a one-line change, and so a refusal can name the type
-- it actually saw rather than failing silently.
K.dryOccupants = {
    rat=true, ratfemale=true, ratbaby=true,
    mouse=true, mousefemale=true, mousepups=true,
}

-- Is this a networked game? true on a multiplayer client, on a dedicated
-- server and on the background server of a hosted game; false in single
-- player; nil when none of the probes exist (an unknown context).
function K.networked()
    local known = false
    for _, name in ipairs({'isClient', 'isServer', 'isMultiplayer'}) do
        local probe = _G[name]
        if type(probe) == 'function' then
            local ok, value = pcall(probe)
            if not ok then return nil end
            known = true
            if value then return true end
        end
    end
    if not known then return nil end
    return false
end

-- ------------------------------------------------------------ co-op host
-- B42.20 gives nobody in a Steam-hosted game a real role: LoginPacket hands
-- every connection that joins a co-op server - the host's own included - the
-- default "user" role and never reads the server's database. Vanilla treats the
-- host as admin only for commands typed in chat. So the player hosting the game
-- failed every admin check, and the Test tools stayed missing from the V wheel
-- even after the isAdmin() fix below (Jay, 2026-09-14).
--
-- The host's own game knows it is the host (global isCoopHost()), but the
-- server's Lua cannot tell who the host is: nothing that knows (CoopSlave, the
-- connection's isCoopHost flag) is exposed to Lua. And a client's word alone is
-- not enough, because any player could claim it. What only the host has is the
-- disk: a co-op server runs on the host's machine, in the same Zomboid folder.
-- So the server writes a random code to Zomboid/Lua when it starts, the host's
-- game reads it and sends it with its commands, and the server treats whoever
-- sends the right code as the host for the rest of that session. A player on
-- another machine cannot read the file. The server never sends the code out.
K.HOST_TOKEN_FILE = 'KnoxAquarium_host_code.txt'
K.verifiedHosts = K.verifiedHosts or {}

function K.makeHostToken()
    if type(getRandomUUID) == 'function' then
        local ok, a = pcall(getRandomUUID)
        local ok2, b = pcall(getRandomUUID)
        if ok and ok2 and type(a) == 'string' and type(b) == 'string' and #a >= 32 then return a .. b end
    end
    return nil
end

-- SERVER, at load. Returns the code, or nil if it could not be written (then
-- the host needs a real admin role, exactly as before this existed).
function K.publishHostToken()
    K.hostToken = nil
    if type(getFileWriter) ~= 'function' then return nil end
    local token = K.makeHostToken()
    if not token then return nil end
    -- 0.14.1: getFileWriter is a Java call and can THROW, not just return nil
    -- (a read-only or unusual Zomboid folder, a sandboxed host). This runs at
    -- file load on the server, so an uncaught throw here stops KA_Server.lua
    -- loading at all and the server dies during launch. Never let that happen:
    -- the token is a convenience for the co-op host, not something the mod
    -- needs to run. Failing it just means the host needs a real admin role.
    local writer = nil
    local gotWriter = pcall(function() writer = getFileWriter(K.HOST_TOKEN_FILE, true, false) end)
    if not gotWriter or not writer then return nil end
    local ok = pcall(function() writer:write(token); writer:close() end)
    if not ok then return nil end
    K.hostToken = token
    return token
end

-- CLIENT: the code the local server wrote, or nil when there is no such file.
function K.readHostToken()
    if type(getFileReader) ~= 'function' then return nil end
    -- same reasoning as publishHostToken: this Java call can throw.
    local reader = nil
    local gotReader = pcall(function() reader = getFileReader(K.HOST_TOKEN_FILE, false) end)
    if not gotReader or not reader then return nil end
    local ok, line = pcall(function() return reader:readLine() end)
    pcall(function() reader:close() end)
    if not ok or type(line) ~= 'string' then return nil end
    line = line:match('^%s*(.-)%s*$')
    if line == '' then return nil end
    return line
end

function K.isCoopHostClient()
    if type(isClient) ~= 'function' or not isClient() then return false end
    if type(isCoopHost) ~= 'function' then return false end
    local ok, host = pcall(isCoopHost)
    return ok and host == true
end

-- SERVER: a command carrying the right code marks its sender as the host.
function K.acceptHostToken(player, args)
    if not player or type(args) ~= 'table' then return false end
    local sent = args.hostToken
    if type(sent) ~= 'string' or type(K.hostToken) ~= 'string' or sent ~= K.hostToken then return false end
    local ok, name = pcall(function() return player:getUsername() end)
    if not ok or type(name) ~= 'string' or name == '' then return false end
    K.verifiedHosts[name] = true
    return true
end

function K.isVerifiedHost(player)
    local ok, name = pcall(function() return player:getUsername() end)
    return ok and type(name) == 'string' and K.verifiedHosts[name] == true
end

-- Check both network roles: isMultiplayer alone is not a reliable guard in
-- every dedicated/co-op execution context. All test entry points share this.
-- Single player counts as admin; in multiplayer the admin role or the host.
function K.betaToolsAllowed(player)
    if not player then return false end
    local networked = K.networked()
    if networked == nil then return false end
    if not networked then return true end
    -- A MULTIPLAYER CLIENT asks the game the way vanilla's own admin menus do:
    -- the global isAdmin() / getAccessLevel(), which read the role on the
    -- client's network connection (B42.20 LuaManager.GlobalObject). The local
    -- IsoPlayer's getAccessLevel() reads a role field the client's own player
    -- does not carry, so it said "none" even for an admin. Only called on a
    -- client: both globals need its connection.
    if type(isClient) == 'function' and isClient() then
        if type(isAdmin) == 'function' then
            local ok, admin = pcall(isAdmin)
            if ok and admin == true then return true end
        end
        if type(getAccessLevel) == 'function' then
            local ok, level = pcall(getAccessLevel)
            if ok and type(level) == 'string' and string.lower(level) == 'admin' then return true end
        end
        -- The host of the game (see the co-op host block above). This only
        -- decides what the menus show; the server checks the code.
        if K.isCoopHostClient() then return true end
    end
    -- The SERVER checks the requesting player's own role, which it does hold,
    -- or that this player proved to be the co-op host.
    local ok, level = pcall(function() return player:getAccessLevel() end)
    if ok and type(level) == 'string' and string.lower(level) == 'admin' then return true end
    return K.isVerifiedHost(player)
end

-- ------------------------------------------------------------ sandbox options
-- media/sandbox-options.txt. A save made before an option existed simply has
-- no value for it, so every read falls back to the default the option ships
-- with - existing worlds behave exactly as they did.
function K.sandbox(name, default)
    local vars = rawget(_G, 'SandboxVars')
    local mine = type(vars) == 'table' and vars.KnoxAquarium or nil
    if type(mine) ~= 'table' then return default end
    -- PLAYTEST 2026-09-16, found while adding the first BOOLEAN option
    -- (ComfortEnabled): the old `mine[name] or nil` idiom throws away an
    -- explicit `false` - Lua's `a and false or c` always evaluates to `c` -
    -- so a server setting a boolean option to false silently got the default
    -- instead. FreeTanks (an enum, never false) never hit this; a tickbox
    -- option always would have. Read the field directly and only treat an
    -- ACTUAL nil (unset) as "use the default".
    local value = mine[name]
    if value == nil then return default end
    return value
end

-- Who may place a free tank from the right-click menu (no kit item).
--   1 Everyone (default - the beta as released: the Workshop page promises it)
--   2 Admins only (single player counts as admin)
--   3 Nobody (kits found as loot only)
-- Reported by server owners: every player could spam free, solid tanks.
-- The SERVER checks this on every placement; the menu only mirrors it.
K.FREE_TANKS_EVERYONE, K.FREE_TANKS_ADMINS, K.FREE_TANKS_NOBODY = 1, 2, 3
function K.freeTankPolicy()
    local v = math.floor(tonumber(K.sandbox('FreeTanks', K.FREE_TANKS_EVERYONE)) or K.FREE_TANKS_EVERYONE)
    if v < 1 or v > 3 then v = K.FREE_TANKS_EVERYONE end
    return v
end
function K.freePlacementAllowed(player)
    if not player then return false end
    local policy = K.freeTankPolicy()
    if policy == K.FREE_TANKS_NOBODY then return false end
    if policy == K.FREE_TANKS_ADMINS then return K.betaToolsAllowed(player) end
    return true
end

function K.mode(d) return d.mode=='dry' and 'dry' or 'water' end
function K.isDry(d) return K.mode(d)=='dry' end
function K.animals(d) d.animals=d.animals or {}; return d.animals end
function K.occupied(d) return #(d.fish or {})>0 or #K.animals(d)>0 end
function K.tankEmpty(d) return not K.occupied(d) and (tonumber(d.water) or 0)<=0 end

function K.animalType(item)
    local ok,kind=pcall(function() return item:getAnimal():getAnimalType() end)
    if ok and type(kind)=='string' then return kind end
end

function K.animalName(item)
    local ok,name=pcall(function()
        local animal=item:getAnimal()
        return animal:getCustomName() or animal:getFullName()
    end)
    if ok and type(name)=='string' and name~='' then return name end
    return K.animalType(item) or 'Animal'
end

function K.isLiveAnimal(item)
    if not item then return false end
    local ok,result=pcall(function() return instanceof(item,'AnimalInventoryItem') end)
    return ok and result==true
end

-- Returns true, or false plus the reason to show the player.
function K.canAddAnimal(d, item)
    if not K.isDry(d) then return false, 'Switch this tank to a dry habitat first. Tank options, Habitat mode.' end
    if not K.isLiveAnimal(item) then return false, 'That is not a live animal.' end
    local kind=K.animalType(item)
    if not kind or not K.dryOccupants[string.lower(kind)] then
        -- Name it the way the player sees it. The internal type is things like
        -- "rabdoe" and "mousepups", which mean nothing to anybody.
        return false, K.animalName(item)..' is too big for this tank. It takes small animals: a rat or a mouse.'
    end
    if (tonumber(d.water) or 0)>0 then return false, 'Drain the water before keeping an animal in here.' end
    if #K.animals(d)>=K.maxAnimals then return false, 'This habitat is full ('..K.maxAnimals..' animals).' end
    return true
end

function K.canSetMode(d, mode)
    if K.mode(d)==mode then return false, 'The tank is already in that mode.' end
    if mode=='dry' and K.tierOf(d).allowsDry==false then
        return false, 'A '..K.tierOf(d).label..' cannot be run as a dry habitat.'
    end
    if not K.tankEmpty(d) then return false, 'Empty the tank of water and occupants before changing its mode.' end
    return true
end

-- Floored, not %: Kahlua's % keeps the sign of the dividend, so a corrupt
-- negative rotation would come out negative and miss every per-facing table.
-- See frameIndex above for the same trap.
function K.rotation(d)
    local n = math.floor(tonumber(type(d) == 'table' and d.rotation or 0) or 0)
    return n - math.floor(n / 4) * 4
end
function K.renderKey(d,frame)
    local rotation=K.rotation(d)
    return (rotation==0 and '' or ('KA_rot'..rotation..'/'))..baseRenderKey(d,frame)
end
