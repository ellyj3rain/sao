-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
--[[ Knox Aquarium - species registry and tank tiers.

    Every fish in Build 42, vanilla or modded, is registered by its author into
    the base game's own `Fishing.fishes` list as a Fishing.FishConfig. That list
    is the single source of truth for what a species IS: its maximum length, its
    maximum weight, where it lives. Reading it means the aquarium learns about
    new species by itself.

    Nothing here is hardcoded per species and nothing here names another mod.
    A fishing mod that registers 100 species the normal way is picked up whole,
    and so is the next version of it, without this file changing.

    Safety: this only ever READS the vanilla table. It never writes to it, never
    replaces a registration, and never patches a vanilla function. If Fishing is
    missing or empty the registry is simply empty and every caller falls back to
    the behaviour the mod had before this file existed.
]]
KnoxAquarium = KnoxAquarium or {}
local K = KnoxAquarium

-- Size classes, ordered. A tank tier stores the largest class it will take.
K.SIZE = {SMALL=1, MEDIUM=2, LARGE=3, XL=4}
K.SIZE_NAME = {[1]='Small', [2]='Medium', [3]='Large', [4]='Extra large'}

-- Boundaries in centimetres, by species maximum length. Chosen against the real
-- spread of B42 fishing content: vanilla panfish sit in Small, bass and walleye
-- in Medium, catfish and pike in Large, gar and arapaima in Extra large.
K.SIZE_BOUND = {30, 60, 120}

function K.sizeClassForLength(cm)
    if type(cm) ~= 'number' then return nil end
    for class, bound in ipairs(K.SIZE_BOUND) do
        if cm <= bound then return class end
    end
    return K.SIZE.XL
end

-- ---------------------------------------------------------------- the registry
K.fishRegistry = nil

function K.buildFishRegistry(force)
    if K.fishRegistry and not force then return K.fishRegistry end
    local registry, count, sources = {}, 0, {}
    local fishing = rawget(_G, 'Fishing')
    local list = type(fishing) == 'table' and fishing.fishes or nil
    if type(list) == 'table' then
        for _, config in ipairs(list) do
            local itemType = type(config) == 'table' and config.itemType or nil
            -- First registration wins, which is exactly how the base game's own
            -- Fishing.onCreateFish resolves a duplicate. Matching it means load
            -- order cannot make the aquarium disagree with the fishing system.
            if type(itemType) == 'string' and itemType ~= '' and not registry[itemType] then
                local maxLength = tonumber(config.maxLength)
                local module = string.match(itemType, '^([^.]+)') or '?'
                registry[itemType] = {
                    itemType   = itemType,
                    maxLength  = maxLength,
                    maxWeight  = tonumber(config.maxWeight),
                    class      = K.sizeClassForLength(maxLength),
                    module     = module,
                }
                sources[module] = (sources[module] or 0) + 1
                count = count + 1
            end
        end
    end
    K.fishRegistry = registry
    K.fishRegistryCount = count
    K.fishRegistrySources = sources
    return registry
end

-- Every species this game has, longest first. Data driven, so a fishing mod's
-- species appear in the ranking automatically.
function K.speciesByLength()
    local list = {}
    for _, info in pairs(K.buildFishRegistry()) do
        if info.maxLength then table.insert(list, info) end
    end
    table.sort(list, function(a, b)
        if a.maxLength == b.maxLength then return a.itemType < b.itemType end
        return a.maxLength > b.maxLength
    end)
    return list
end

-- Accepts an InventoryItem, a full type string, or a stored fish record.
function K.speciesOf(subject)
    if subject == nil then return nil end
    local itemType = nil
    if type(subject) == 'string' then
        itemType = subject
    else
        -- A stored fish record keeps the type under `type`; a live InventoryItem
        -- answers getFullType. Try both on anything else, in that order, so the
        -- same call works for records, items and item-shaped test doubles.
        if type(subject) == 'table' and type(subject.type) == 'string' then
            itemType = subject.type
        end
        if not itemType then
            local ok, full = pcall(function() return subject:getFullType() end)
            if ok and type(full) == 'string' then itemType = full end
        end
    end
    if type(itemType) ~= 'string' or itemType == '' then return nil end
    return K.buildFishRegistry()[itemType]
end

-- The class the aquarium should judge a fish by. Species class where the
-- registry knows the species; otherwise fall back to the individual fish's own
-- measured length, which is what the mod used before any registry existed.
function K.fishClass(item, measuredLength)
    local species = K.speciesOf(item)
    if species and species.class then return species.class, species end
    return K.sizeClassForLength(measuredLength), nil
end

-- Display tanks use sprites rendered from gadinho's authorised source meshes.
-- The largest resident chooses the family, so a gar or arapaima remains visible
-- when smaller fish share its tank.  Unknown and vanilla types use `school`, a
-- real small-fish render; every possible record therefore has valid art.
local displayVariantWords = {
    arapaima={'arapaima','pirarucu'}, shrimp={'camarao','shrimp'}, squid={'lula','squid'},
    gar={'gar'}, catfish={'catfish','bullhead','cascudo'},
    bluegill={'bluegill','tilapia','piranha','carp','bream','cichlid','sunfish'},
}
function K.displayFishVariant(record)
    local name=string.lower((type(record)=='table' and record.type) or '')
    for variant,words in pairs(displayVariantWords) do
        for _,word in ipairs(words) do if string.find(name,word,1,true) then return variant end end
    end
    return 'school'
end
function K.displayTankVariant(d)
    local chosen,longest='school',-1
    for _,fish in ipairs((d and d.fish) or {}) do
        local info=K.speciesOf(fish)
        local length=(type(fish)=='table' and tonumber(fish.length)) or (info and tonumber(info.maxLength)) or 0
        if length>longest then chosen=K.displayFishVariant(fish);longest=length end
    end
    return chosen
end

-- ------------------------------------------------------------------ tank tiers
-- A tier describes what a physical tank can hold. `standard` reproduces the
-- numbers this mod has always used, exactly, so adding tiers changes nothing
-- about the aquarium players already have.
K.tankTiers = {
    standard = {
        id = 'standard', label = 'Aquarium',
        capacity = 20, maxFish = 4,
        -- No size limit, no species limit (0.13.0). This tank never drew the
        -- real species: every resident is one of its own four aquarium fish,
        -- so any catch it is given always shows. The fish itself is stored
        -- untouched and comes back out as exactly the same catch. The bigger
        -- tanks keep their own rules; this one is the forgiving tank.
        maxIndividualLength = nil,
        maxSpeciesClass = K.SIZE.XL,
        art = 'KA_', swim = 'KA_swim/', swimLevels = 2, fps = 8,
        -- Three extra colour arrangements of the same four fish (KA_swim_p1..3/),
        -- worn only by a tank holding a fish over the old 30 cm limit. See
        -- K.fallbackPalette: every tank a released build could hold draws the
        -- released art, unchanged.
        paletteVariants = 3,
        allowsDry = true,
        item = 'KnoxAquarium.TankKit',
        spriteWidth = 128,
        -- Sprite anchor, measured by projecting this tank's own footprint centre
        -- in its own render. See offsetsFor() below. 149 since the Playtest
        -- re-render with Project Zomboid's own camera (2026-09-15); the old
        -- camera measured 148.
        offsetX = 64, offsetY = 149,
    },
    display = {
        id = 'display', label = 'Display Aquarium',
        capacity = 400, maxFish = 4,
        maxIndividualLength = 250,
        maxSpeciesClass = K.SIZE.XL,
        -- A long tank read as frantic at the standard rate: the fish crossed
        -- the whole tank in four seconds. Half speed suits its size.
        art = 'KA_dp_', swim = 'KA_dp/', swimLevels = 1, fps = 6,
        overlayDir = 'KA_dp_ov/',
        -- A dry habitat too (0.13.0): the same rats as the original tank,
        -- drawn as an overlay over this tank's own empty art (KA_dp_dry/).
        allowsDry = true,
        dryOverlayDir = 'KA_dp_dry/',
        item = 'KnoxAquarium.DisplayTankKit',
        overlayGroupMax = 4,   -- group artwork exists for this tier
        -- the tank's own fish, drawn starting at seat 1 so they never share a
        -- path with a species overlay in seat 0 (seat1_1..seat1_3)
        seatArt = {[1] = 3},
        model = 'KA_dp_empty',
        -- this one is rendered on a wider canvas, so its sprite is centred at
        -- half of 256 rather than half of 128
        spriteWidth = 256,
        -- centre anchor of the camera-corrected 0.13.0 render; per-facing
        -- flush anchors are in K.facingOffsets
        offsetX = 128, offsetY = 152,
        -- 1.96 tiles long, so it fits inside the two tiles it stands on (see
        -- K.partDelta and the display row of K.facingOffsets)
        footprint = 2,
        -- BUILD 42 DEPTH (Playtest, 2026-09-15; Jay: "only display tank is
        -- missing corner" - right while placing, clipped once placed). B42 depth
        -- tests every object sprite, and a runtime sprite has no depth map of its
        -- own, so the game gives it a ONE-tile box (IsoSprite.setupTileDepth ->
        -- the 'whole_tile' default) stretched over this tank's two-tile canvas.
        -- The floor of the second tile then wins over the bottom corner of the
        -- near end. The placement ghost has no depth pass, so it never showed.
        -- Fix: the near section of the art (KA_split_near/, cut by
        -- development/split_display_depth.py) is drawn by the part object on the
        -- second tile, which takes that tile's depth; the rest (KA_split_far/)
        -- stays on the tank. Each nudges its depth with IsoObject.renderYOffset
        -- (+renderYOffset/96 levels nearer; KA_Client takes the same amount back
        -- off offsetY so nothing moves on screen). Numbers per facing, chosen with
        -- a model of the depth test (floor + a character in front of the tank).
        -- Missing split art or a part not loaded yet = the whole sprite, lifted
        -- by wholeLift, exactly as before otherwise.
        depthSplit = {
            far = 'KA_split_far/', near = 'KA_split_near/',
            [0] = {far = -24, near = -16}, [1] = {far = -16, near = 8},
            [2] = {far = -16, near = 8},   [3] = {far = -24, near = -16},
        },
        wholeLift = {[0] = 32, [1] = 0, [2] = 0, [3] = 32},
    },
    large = {
        id = 'large', label = 'Large Aquarium',
        capacity = 200, maxFish = 2,
        maxIndividualLength = 250,
        maxSpeciesClass = K.SIZE.XL,
        art = 'KA_lg_', swim = 'KA_lg/', swimLevels = 1, fps = 6,
        overlayDir = 'KA_lg_ov/',
        -- Pairs (Playtest 2026-09-15): two fish of one species are both drawn
        -- as that species (KA_lg_ov/<variant>_2_<frame>). Until then this tier
        -- drew singles only - one real fish plus one of the tank's own generic
        -- fish - because a rendered pair per species was not worth the render
        -- time; it turned out to be about half an hour for all 97.
        overlayGroupMax = 2,
        -- A dry habitat too (0.13.0): rats on the planted floor, drawn as an
        -- overlay over this tank's own empty art (KA_lg_dry/).
        allowsDry = true,
        dryOverlayDir = 'KA_lg_dry/',
        item = 'KnoxAquarium.LargeTankKit',
        -- the tank's own second fish, drawn at seat 1 beside a seat-0 overlay
        seatArt = {[1] = 1},
        model = 'KA_lg_empty',
        spriteWidth = 128,
        -- centre anchor of the camera-corrected 0.13.0 render (zoom 1.70);
        -- per-facing flush anchors are in K.facingOffsets
        offsetX = 64, offsetY = 161,
    },
}


-- ------------------------------------------------------------ sprite anchor
-- Where a tank's sprite sits relative to the tile it stands on.
--
-- Every tank used to share the ORIGINAL tank's numbers: offsetX = half the
-- canvas, offsetY = 148. Those came from render_assets.py, which derives them
-- properly by projecting the tank's footprint centre at floor level through its
-- own camera (IsoObject's origin is the back tile corner, 32px above the tile
-- centre at 2x). The newer tanks were rendered with their own cameras at their
-- own zooms, so that number was never theirs: the large tank was drawing 32
-- pixels - half a tile - out of position, which is why it would not sit against
-- a wall.
--
-- Each tier carries the CENTRE anchor its own render produced (offsetX/Y): the
-- point that puts the middle of the tank on the middle of its tile.
--
-- 0.13.0: centred is not where furniture belongs. A tank shallower than a tile
-- sat in the middle of it with a gap behind - the "won't sit against a wall"
-- reports - and the display tank, 2.18 tiles long, hung over both neighbours.
-- So at every facing each tank is moved back by half its spare depth, toward
-- the side its back faces, and the display tank also moves half a tile along
-- its length onto the middle of the TWO tiles it now stands on:
--
--   back shift = (1 - depth) / 2 tiles toward that facing's back side
--   PZ at 2x:   +1 tile east = (+64,+32) px,  +1 tile south = (-64,+32) px
--
-- Which side is the back was read off every facing's own render (the side you
-- cannot see into; for the original tank, the side opposite its cabinet doors)
-- and cross-checked against each camera's geometry. It is data, not a rule,
-- because each model faces a different way at facing 0.
--
-- The large and display values belong to their camera-corrected 0.13.0 art.
-- PLAYTEST 2026-09-15: the ORIGINAL tank's art is now camera-corrected too. It was
-- the one tank still drawn through the old (8,-10,8) camera, whose ground axes
-- run at slopes 0.424 and 0.662 instead of PZ's 0.500, so its base never ran
-- parallel to a wall and no anchor could put it flush (Jay: "the original tank
-- currently does not line up against walls correctly"). It was re-rendered with
-- KA_VIEW=pz and NOTHING else changed - same scene, fish paths, colours,
-- palettes and dry habitat (the old recipe was first proven to reproduce the
-- shipped art pixel for pixel). To revert, take the KA_swim*, KA_dry and
-- KA_rot1..3 textures and this file's K.facingOffsets.standard from any build
-- of this mod older than 0.13.2 - the pre-merge backup kept beside the release
-- is one. Nothing outside this mod is needed to do it.
K.facingOffsets = {
    -- centre (64,149) at every facing - one camera height, so no 3 px
    -- ground-line correction any more (the old art redrew facings 1 and 3 3 px
    -- lower and used {76,154},{52,157},{52,142},{76,145}). Depth 0.63 tiles,
    -- length 1.26. Back at facing 0..3: W, N, E, S. Verified by projecting the
    -- flush footprint with these numbers onto each facing's silhouette: within
    -- 1 px on both sides and the base line.
    standard = {[0]={76,155}, [1]={52,155}, [2]={52,143}, [3]={76,143}},
    -- centre (64,161). Depth 0.81. Back: S, W, N, E.
    large    = {[0]={70,158}, [1]={70,164}, [2]={58,164}, [3]={58,158}},
    -- centre (128,152). Depth 0.51, length 1.96 on two tiles: the second tile
    -- is east at facings 0/2 and south at 1/3 (see K.partDelta). Back: N, E, S, W.
    -- Until 2026-09-11 this tank was 2.18 tiles long and 0.57 deep (anchors
    -- 82,143 / 146,129 / 110,129 / 174,143): 0.09 of a tile hung past each end,
    -- and the square beyond the viewer's end - drawn after the tank - painted
    -- its floor over that end ("bottom corner cut off"). All of its art was
    -- scaled x0.90 about the footprint centre (development/rescale_display.py),
    -- so it now fits inside its two tiles; only the depth-driven shift changed.
    display  = {[0]={80,144}, [1]={144,128}, [2]={112,128}, [3]={176,144}},
}

function K.offsetsFor(d)
    local tier = K.tierOf(d)
    local facing = K.facingOffsets[tier.id]
    local rot = 0
    if type(d) == 'table' and K.rotation then rot = K.rotation(d) end
    local pair = facing and facing[rot]
    if pair then return pair[1], pair[2] end
    local x = tonumber(tier.offsetX) or ((tier.spriteWidth or 128) / 2)
    local y = tonumber(tier.offsetY) or 148
    return x, y
end

-- A tier that stands on two tiles names its second tile relative to the first:
-- along the tank's length, on the viewer's side - east when the tank runs
-- east-west (facings 0/2), south when it runs north-south (facings 1/3).
-- nil for a one-tile tank. The second tile carries an invisible part object
-- (see KA_Server) so both tiles are solid, on both sides of a network.
function K.partDelta(d)
    local tier = K.tierOf(d)
    if (tonumber(tier.footprint) or 1) < 2 then return nil end
    local rot = K.rotation and K.rotation(d) or 0
    if rot == 0 or rot == 2 then return 1, 0 end
    return 0, 1
end

-- The same anchor expressed for the PLACEMENT GHOST, which takes its offsets in
-- a different frame: IsoSprite.RenderGhostTileColor hands the renderer
-- (32*tileScale + offX, 96*tileScale + offY), where a placed IsoObject hands it
-- (offsetX, offsetY) directly. At 2x that is (64 + offX, 192 + offY) - and the
-- original tank's long-standing ghost values of (0, -44) resolve to (64, 148),
-- exactly its object anchor. So the conversion is not a guess, and the preview
-- now lands where the tank will actually be.
function K.ghostOffsetsFor(d)
    local x, y = K.offsetsFor(d)
    -- getTileScale is STATIC on zombie.core.Core, so Lua reaches it through
    -- the class, the way vanilla does: Core.getTileScale(). The instance that
    -- getCore() returns has no such method, and calling it there is "Tried to
    -- call nil". A pcall hid that in a normal game, but a game started with
    -- -debug breaks on every error, caught or not - so RC1 threw an error
    -- screen on every frame the placement ghost was drawn. No pcall here: check
    -- the method exists, then call it.
    local scale = 2
    local s = Core and Core.getTileScale and Core.getTileScale()
    if type(s) == 'number' and s > 0 then scale = s end
    return x - 32 * scale, y - 96 * scale
end

-- ------------------------------------------------------- species overlays
-- A tank sprite is expensive: it carries the whole cabinet, glass, planting and
-- water. Baking a species into it means storing all of that again per species.
-- Instead the tank is drawn once and the fish are a separate transparent sprite
-- laid over it, so a species costs only its own fish - about a tenth as much.
--
-- Populated by whatever overlay art actually shipped; a species with no overlay
-- simply falls back to the tank's built-in fish, so this can grow one species at
-- a time without touching anything else.
-- `or {}`, not `= {}`: KA_Compat_PeixesBR registers into this at LOAD time (so a
-- dedicated server has it too), and a second run of this file must never wipe it.
K.overlaySpecies = K.overlaySpecies or {}

-- How many fish a variant has artwork for. One overlay sprite depicts a fixed
-- NUMBER of fish as well as a fixed species, so asking for a group of four when
-- only the single was rendered resolves to a texture that does not exist - and
-- the tank then falls back to its generic art and shows NONE of that species,
-- which is worse than showing one of them properly. Defaults to 1.
K.overlayMaxCount = K.overlayMaxCount or {}

function K.registerOverlaySpecies(itemType, variant, maxCount)
    if type(itemType) == 'string' and type(variant) == 'string' then
        K.overlaySpecies[itemType] = variant
        local n = math.floor(tonumber(maxCount) or 1)
        if n < 1 then n = 1 end
        -- a variant may be registered by more than one item; keep the largest
        if not K.overlayMaxCount[variant] or K.overlayMaxCount[variant] < n then
            K.overlayMaxCount[variant] = n
        end
    end
end

-- The most fish this variant can be drawn as.
function K.overlayCountFor(variant, tier)
    local n = K.overlayMaxCount[variant] or 1
    -- a tier can only draw a group if ITS art was rendered that way
    local cap = tier and tier.overlayGroupMax or 1
    if n > cap then n = cap end
    return n
end

-- Which overlay a tank should draw: the species of its LARGEST occupant, so a
-- tank holding one big fish and three small ones reads as the big one.
function K.overlayVariantFor(d)
    if type(d) ~= 'table' or type(d.fish) ~= 'table' then return nil end
    local best, bestLen
    for _, fish in ipairs(d.fish) do
        local variant = fish.type and K.overlaySpecies[fish.type]
        if variant then
            local len = tonumber(fish.length) or 0
            if not bestLen or len > bestLen then best, bestLen = variant, len end
        end
    end
    return best
end

-- ------------------------------------------------------- species tanks
-- A tank can be SET TO A SPECIES. Only that species may then be added, and in
-- return every fish in it is drawn correctly, because one overlay sprite can
-- depict one species. Leave it unset and the tank is a community tank: the
-- largest occupant is drawn as itself and the rest as ordinary fish.
--
-- The engine gives an object exactly one overlay sprite, and the field that
-- takes a list is written into the save file - so this is the honest way to
-- offer a correct picture without touching anybody's save.
function K.tankSpecies(d)
    return type(d) == 'table' and type(d.species) == 'string' and d.species or nil
end

function K.canSetSpecies(d, itemType)
    if type(d) ~= 'table' then return false, 'No tank there.' end
    if itemType == nil then
        if not K.tankSpecies(d) then return false, 'This tank is already a community tank.' end
        return true
    end
    if not K.overlaySpecies[itemType] then
        return false, 'That species has no artwork of its own, so a species tank would not look any different.'
    end
    for _, fish in ipairs(d.fish or {}) do
        if fish.type ~= itemType then
            return false, 'Take the other fish out first: a species tank holds one species.'
        end
    end
    return true
end

-- The name to show a player for a species. The overlay variant is a FOLDER name
-- generated from the item id - "lula", "peixesbrpiranha" - and putting that in
-- front of somebody is not acceptable, so ask the game for the item's real
-- display name and keep the id as a last resort.
function K.speciesName(itemType)
    if type(itemType) ~= 'string' then return '?' end
    local ok, name = pcall(function()
        local script = getScriptManager():getItem(itemType)
        return script and script:getDisplayName() or nil
    end)
    if ok and type(name) == 'string' and name ~= '' then return name end
    return (string.match(itemType, '[^.]+$') or itemType)
end

-- What a tank will accept, given how it is set up.
function K.speciesAllowed(d, itemType)
    local locked = K.tankSpecies(d)
    if not locked or locked == itemType then return true end
    return false, 'This tank is set up for '..K.speciesName(locked)
        ..'. Change it under Tank options, or use another tank.'
end

-- How many fish the overlay carries, and as what.
--
-- One IsoObject gets exactly ONE overlay sprite, so the overlay can only ever
-- depict a single species at a time. When every occupant IS that species there
-- is nothing to compromise on and all of them are drawn properly; a mixed tank
-- falls back to one correct showpiece with the rest left to the tank art.
--
-- overlayKey and tankKeyUnderOverlay both read this, so the overlay and the
-- tank underneath it can never disagree about who has been drawn.
function K.overlayPlan(d)
    local tier = K.tierOf(d)
    local fish = (type(d) == 'table' and d.fish) or {}
    local count = math.min(tier.maxFish, #fish)
    if count < 1 then return nil, 0 end

    local locked = K.tankSpecies(d)
    if locked and K.overlaySpecies[locked] then
        -- a species tank: only this species may be added, so draw as many as
        -- there is artwork for and leave the rest to the tank
        local v = K.overlaySpecies[locked]
        return v, math.min(count, K.overlayCountFor(v, tier))
    end

    -- A community tank that happens to hold one species is a species tank in
    -- everything but the label, and the artwork for a group of them already
    -- exists, so there is no reason to draw the rest as anonymous fish.
    local uniform
    for index = 1, count do
        local variant = fish[index] and fish[index].type and K.overlaySpecies[fish[index].type]
        if not variant then uniform = nil; break end
        if uniform and uniform ~= variant then uniform = nil; break end
        uniform = variant
    end
    if uniform then return uniform, math.min(count, K.overlayCountFor(uniform, tier)) end

    -- genuinely mixed: one real showpiece species. PLAYTEST 2026-09-16 audit:
    -- this used to hardcode a count of 1 even when the showpiece species
    -- itself had two or more occupants and group art for that many exists -
    -- e.g. species A,A,B,C drew only one A and folded the SECOND A in with
    -- B and C as anonymous tank-art fish, though A's own pair art exists.
    --
    -- The engine still allows only ONE overlay sprite per tank, so B and C
    -- (genuinely different species) can never get their own art in the same
    -- tank - that is an engine/asset limit (one overlay = one species = one
    -- count; see project memory knox-aquarium-overlay-architecture), not
    -- something this function can fix. What it CAN fix is not undercounting
    -- the species that does get the overlay.
    --
    -- Drawing more of the showpiece only helps if the leftover fish can still
    -- be drawn without swimming on top of it. The tank's own art has seat-
    -- shifted room for a leftover group only at the exact seats tier.seatArt
    -- declares (rendered once, for the overlay counts that actually ship).
    -- Asking for a seat that was never rendered falls back to unseated
    -- 'full_' art for the leftover group - drawn at seat 0, the SAME path the
    -- overlay uses - which is the swim-locked-together bug seat art exists to
    -- avoid (see K.seatKey / K.hasSeatArt below). So this only raises the
    -- count when the resulting leftover count is one the tank was actually
    -- rendered to seat; otherwise it keeps the historical, art-safe count 1.
    local showpiece = K.overlayVariantFor(d)
    if not showpiece then return nil, 0 end
    local matching = 0
    for _, f in ipairs(fish) do
        if f.type and K.overlaySpecies[f.type] == showpiece then matching = matching + 1 end
    end
    if matching < 1 then matching = 1 end -- overlayVariantFor found it, so this never hits in practice
    local drawn = math.min(count, matching, K.overlayCountFor(showpiece, tier))
    while drawn > 1 do
        local leftover = count - drawn
        if leftover == 0 or K.hasSeatArt(tier, drawn, leftover) then break end
        drawn = drawn - 1
    end
    return showpiece, drawn
end

-- The overlay sprite for a tank, or nil when there is nothing to draw over it.
function K.overlayKey(d, frame)
    if type(d) ~= 'table' then return nil end
    local tier = K.tierOf(d)
    local rotation = K.rotation(d)
    if K.isDry(d) then
        -- A dry habitat's rats ride the same overlay a species fish does, over
        -- the tank's empty art. The original tank has no dry overlay: its rats
        -- are baked into its own dry art, exactly as they always were.
        if not tier.dryOverlayDir then return nil end
        local living = math.min(K.maxAnimals, #K.animals(d))
        if living < 1 then return nil end
        return (rotation == 0 and '' or ('KA_rot' .. rotation .. '/'))
            .. tier.dryOverlayDir .. living .. '_' .. K.frameIndex(frame)
    end
    if not tier.overlayDir then return nil end
    local fish = d.fish or {}
    local count = math.min(tier.maxFish, #fish)
    if count < 1 then return nil end
    -- Fish only go into a full tank and a tank cannot be drained with fish in
    -- it, so a part-filled tank holding fish is not reachable in play - only the
    -- debug menu makes one. Draw nothing rather than float fish over a low
    -- waterline, and leave the tank to its own art.
    if (tonumber(d.water) or 0) < tier.capacity - 0.001 then return nil end
    local variant, drawn = K.overlayPlan(d)
    if not variant then return nil end
    local rotation = K.rotation(d)
    return (rotation == 0 and '' or ('KA_rot' .. rotation .. '/'))
        .. tier.overlayDir .. variant .. '_' .. drawn .. '_' .. K.frameIndex(frame)
end

-- The TANK sprite to draw under an overlay. A species tank needs no fish of its
-- own because the overlay carries them all; a community tank still draws the
-- occupants the showpiece does not cover.
--
-- Those leftover fish must not be drawn in the seats the overlay is already
-- using. Every fish in every render is placed by its seat number, and BOTH the
-- overlay and the tank art used to start at seat 0 - so a tank showing one
-- species fish plus one plain one drew them on the same path, and they swam
-- locked together on top of each other. Measured on the shipped large tank the
-- two were within 8 px twice per loop and never more than 32 px apart.
--
-- The tank art is therefore asked for its fish starting at seat N, where N is
-- however many the overlay took. 'full_' art starts at seat 0 and is what a tank
-- with no overlay has always used, so tanks that never had this problem keep
-- exactly the art they had.
-- Seat-offset art only exists where it was actually rendered. Asking for a
-- texture that was never made is not a cosmetic miss: the loader never reports
-- it ready, applyAppearance returns before it sets a sprite, and the tank sits
-- frozen on its last frame. So a tier declares what it has and anything else
-- falls back to the seat-0 art that has always shipped.
--   tier.seatArt[startSeat] = the largest 'others' count rendered at that seat
function K.hasSeatArt(tier, startSeat, others)
    local avail = tier and tier.seatArt and tier.seatArt[startSeat]
    return type(avail) == 'number' and others <= avail
end

function K.seatKey(tier, startSeat, others, frame)
    startSeat = startSeat or 0
    local prefix = 'full_'
    if startSeat > 0 and K.hasSeatArt(tier, startSeat, others) then
        prefix = 'seat' .. startSeat .. '_'
    end
    return tier.swim .. prefix .. others .. '_' .. K.frameIndex(frame)
end

function K.tankKeyUnderOverlay(d, frame)
    local tier = K.tierOf(d)
    -- under a rat overlay the tank is simply empty: no water, no fish
    if type(d) == 'table' and K.isDry(d) then return tier.art .. 'empty' end
    local full = (tonumber(d.water) or 0) >= tier.capacity - 0.001
    local _, drawn = K.overlayPlan(d)
    local others = math.min(tier.maxFish, #(d.fish or {})) - (drawn or 0)
    if others < 1 then return tier.art .. (full and 'water' or 'low') end
    return K.seatKey(tier, drawn or 0, others, frame)
end

-- Capacity and fish limit for a given tank, by its tier. Callers that have a
-- tank in hand must use these rather than K.capacity / K.maxFish, which describe
-- the standard tank only.
function K.cap(d) return K.tierOf(d).capacity end
function K.fishCap(d) return K.tierOf(d).maxFish end

-- The fastest animation rate any tier asks for. The client ticks at this rate
-- and each tank picks its own frame from it, so a slow tank still updates.
function K.maxFpsOf()
    local fastest = 8
    for _, tier in pairs(K.tankTiers) do
        if (tier.fps or 8) > fastest then fastest = tier.fps end
    end
    return fastest
end
K.maxFps = 8

function K.tierOf(d)
    local id = type(d) == 'table' and d.tier or nil
    return K.tankTiers[id] or K.tankTiers.standard
end

-- A tier is only offered to players once it has art to render.
K.maxFps = K.maxFpsOf()

function K.tierAvailable(tier)
    if type(tier) == 'string' then tier = K.tankTiers[tier] end
    if not tier then return false end
    return tier.id == 'standard' or tier.model ~= nil
end

-- Which tier, if any, would take this fish. Used for the "you need a bigger
-- tank" message so it names a real destination rather than a vague refusal.
function K.tierForClass(class)
    if not class then return nil end
    local best
    for _, tier in pairs(K.tankTiers) do
        if K.tierAvailable(tier) and (tier.maxSpeciesClass or K.SIZE.XL) >= class then
            if not best or (tier.capacity or 0) < (best.capacity or 0) then best = tier end
        end
    end
    return best
end

if Events and Events.OnGameStart then Events.OnGameStart.Add(function()
    K.buildFishRegistry(true)
    local parts = {}
    for module, n in pairs(K.fishRegistrySources or {}) do table.insert(parts, module..'='..n) end
    table.sort(parts)
    print('[KnoxAquarium] fish registry: '..tostring(K.fishRegistryCount or 0)
        ..' species ('..(#parts > 0 and table.concat(parts, ' ') or 'none')..')')
end) end
