--[[ Knox Aquarium - the single world context menu.

    Reported: three separate aquarium entries cluttering the normal right-click
    menu, and aquarium options appearing on things that are not aquariums.

    This replaces all of that with ONE "Fish Tank" entry that only appears when
    it has something to say, following how Build 42 fills a world menu: the game
    hands you the objects under the cursor, you decide whether any of them are
    yours, and you add nothing at all if none are.

    Three cases, in priority order:

      * clicked an aquarium  -> actions for THAT aquarium. The game already
        knows which one was clicked, so it is never asked for again. The second
        tile of a two-tile tank counts as the tank.
      * clicked a spot a tank could go, holding a kit -> Place Aquarium.
      * clicked an empty floor it cannot go on YET (standing on it, out of
        reach) -> Place Aquarium greyed out, with the reason.
      * neither -> nothing is added. Sinks, doors, fridges and other mods are
        untouched.

    Beta Tools ride inside the same entry rather than adding a second top-level
    option, and only where they are allowed.
]]
require 'KA_Core'
local K = KnoxAquarium

-- TESTING SWITCH (Jay, 2026-09-11): during the beta the entry shows on EVERY
-- right-click, so it can never be hard to find. Where a tank cannot go, Place
-- is greyed out with the reason; nothing is ever placed that the full rule
-- (and the server) would refuse. Set false to go back to showing it only on
-- aquariums and on floors a tank could stand on.
K.menuAlwaysShown = true

-- The aquarium an object belongs to: the tank itself or, for the second tile of
-- a two-tile tank, the tank that tile belongs to. nil for anything else.
local function tankOf(obj)
    if not obj then return nil end
    local ok, md = pcall(K.modDataOf, obj)
    if not ok or type(md) ~= 'table' then return nil end
    if md.KnoxAquarium then return obj end
    if md.KnoxAquariumPart and K.masterOf then return K.masterOf(obj) end
    return nil
end

-- The aquarium the player actually clicked, or nil.
local function clickedTank(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        local tank = tankOf(obj)
        if tank then return tank, tank:getSquare() end
    end
    -- A click frequently returns a different object on the same tile, so look
    -- across the square the click landed on before giving up.
    for _, obj in ipairs(worldobjects or {}) do
        local sq = obj:getSquare()
        if sq then
            local objects = sq:getObjects()
            for i = 0, objects:size() - 1 do
                local tank = tankOf(objects:get(i))
                if tank then return tank, tank:getSquare() end
            end
        end
    end
    return nil, nil
end

local function firstSquare(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        local sq = obj:getSquare()
        if sq then return sq end
    end
    return nil
end

-- Which tank kits the player is actually carrying, in tier order.
local function kitsCarried(player)
    local found = {}
    local ok = pcall(function()
        local inv = player:getInventory():getItems()
        for i = 0, inv:size() - 1 do
            local item = inv:get(i)
            local full = item:getFullType()
            for id, tier in pairs(K.tankTiers) do
                if tier.item and full == tier.item and not found[id] then
                    found[id] = item
                end
            end
        end
    end)
    if not ok then return {} end
    local order = {}
    for _, id in ipairs({'standard', 'large', 'display'}) do
        if found[id] then table.insert(order, {id = id, item = found[id]}) end
    end
    for id, item in pairs(found) do
        local listed = false
        for _, e in ipairs(order) do if e.id == id then listed = true end end
        if not listed then table.insert(order, {id = id, item = item}) end
    end
    return order
end



-- Free placement: K.freePlacementAllowed lives in KA_Core (shared) and reads
-- the "Free tanks" sandbox option - Everyone by default, exactly as the beta
-- has always offered it; server owners can make it Admins only or turn it off.
-- The server enforces the same function on every placement, so this menu can
-- never offer something the server would refuse. Crafting replaces it when the
-- beta ends.

-- Actions for the aquarium that was clicked.
local function addTankActions(menu, player, tank)
    local d = tank:getModData().KnoxAquarium
    local sq = tank:getSquare()
    local tier = K.tierOf(d)
    local dry = K.isDry(d)

    menu:addOption('Open ' .. string.lower(tier.label) .. ' menu', player, function(p)
        K.showWheel(p, tank)
    end)

    local summary
    if dry then
        summary = string.format('Dry habitat - %d of %d animals', #K.animals(d), K.maxAnimals)
    else
        summary = string.format('%.0f of %.0f litres - %d of %d fish',
            tonumber(d.water) or 0, tier.capacity, #(d.fish or {}), tier.maxFish)
    end
    local info = menu:addOption(summary, player, nil)
    info.notAvailable = true

    -- Inspect opens the inspection window itself. It used to hand the wheel a
    -- page called 'inspect', which the wheel does not have, so it quietly fell
    -- back to the main wheel instead.
    menu:addOption('Inspect', player, function(p)
        if K.showInspection then K.showInspection(p, tank) else K.showWheel(p, tank) end
    end)
    if not dry then
        menu:addOption('Add water', player, function(p) K.showWheel(p, tank, 'water') end)
        menu:addOption('Add a fish', player, function(p) K.showWheel(p, tank, 'fish') end)
        if #(d.fish or {}) > 0 then
            -- the wheel's resident list is the page called 'residents'
            menu:addOption('Manage fish', player, function(p) K.showWheel(p, tank, 'residents') end)
        end
    else
        menu:addOption('Add an animal', player, function(p) K.showWheel(p, tank, 'animalsAdd') end)
        if #K.animals(d) > 0 then
            menu:addOption('Manage animals', player, function(p) K.showWheel(p, tank, 'residentAnimals') end)
        end
    end
    menu:addOption('Rotate', player, function(p) K.send(p, 'rotate', sq) end)

    -- Pick up needs the tank fully empty: no fish/animals AND no water.
    -- 2026-09-15 per Jay, after a live MP test: water blocks Pick up the same
    -- way fish do now (see K.tankEmpty and the server pack comment for why
    -- this rule has flipped back and forth before).
    local empty = K.tankEmpty(d)
    -- Anything a player put in the tank's storage (every tank has carried a
    -- vanilla desk container since 0.7.0). The server refuses to pack a tank
    -- with something in it; the menu says so up front rather than after.
    local stored = 0
    pcall(function()
        local c = tank:getContainer()
        if c then stored = c:getItems():size() end
    end)
    local pack = menu:addOption('Pick up', player, function(p)
        if empty then K.send(p, 'pack', sq) end
    end)
    if not empty then
        pack.notAvailable = true
        pack.toolTip = ISWorldObjectContextMenu.addToolTip()
        pack.toolTip.description = K.occupied(d) and 'Take any fish or animal out first.'
            or 'Drain the tank before picking it up.'
    elseif stored > 0 then
        -- Stored items no longer block Pick up: the server hands them over.
        pack.toolTip = ISWorldObjectContextMenu.addToolTip()
        pack.toolTip.description = 'Anything stored in it goes to your inventory.'
    end
end

-- Placing a new tank: from a kit the player is carrying, and - while this is a
-- beta - a free one of each for testing. Both live in the same submenu instead
-- of the three separate top-level options this replaces.
local function addPlacement(menu, player, kits, sq, free)
    local root = menu:addOption('Place aquarium')
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, sub)
    for _, entry in ipairs(kits) do
        local tier = K.tankTiers[entry.id]
        local id, item = entry.id, entry.item
        sub:addOption(tier.label .. '  (' .. K.rotateKeyName() .. ' to rotate)', player, function(p)
            K.startPlacement(p, item, id)
        end)
    end
    if not free then return end
    local freeRoot = sub:addOption('Beta: free tank')
    local free = ISContextMenu:getNew(sub)
    sub:addSubMenu(freeRoot, free)
    for _, id in ipairs({'standard', 'large', 'display'}) do
        local tier = K.tankTiers[id]
        if tier and K.tierAvailable(tier) then
            free:addOption(tier.label, player, function(p) K.startPlacement(p, nil, id) end)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(function(index, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(index)
    if not player then return end

    local tank, tankSq = clickedTank(worldobjects)
    local sq = tankSq or firstSquare(worldobjects)
    if not sq then return end

    local kits = kitsCarried(player)
    local beta = K.betaToolsAllowed(player)
    local free = K.freePlacementAllowed(player)
    local okHere, whyNot = false, nil
    if not tank then okHere, whyNot = K.canPlaceOn(sq, player) end
    local placeable = (not tank) and okHere and true or false
    -- A plain floor that cannot take a tank RIGHT NOW - the player is standing
    -- on it, it is out of reach, a wall is in between - still gets the entry,
    -- with Place greyed out and the reason on it. RC1 hid the whole menu
    -- instead, so right-clicking your own tile showed nothing and the mod looked
    -- uninstalled. With K.menuAlwaysShown off, sinks, fridges and counters get
    -- nothing: isPlaceableFloor only passes an empty, walkable floor. With it on
    -- (the beta default) every right-click gets the entry.
    -- "Everywhere" is the player's own Options > Mods setting (KA_Options),
    -- falling back to K.menuAlwaysShown where the options API is not there.
    local everywhere
    if K.menuShownEverywhere then everywhere = K.menuShownEverywhere()
    else everywhere = K.menuAlwaysShown == true end
    local floorHere = (not tank)
        and (placeable or everywhere or K.isPlaceableFloor(sq)) or false
    -- Somewhere a tank could actually go, and either a kit to put there or the
    -- beta's free ones. Beta tools alone are never a reason to appear on
    -- somebody's fridge: this menu has to have been justified by a tank or by a
    -- floor a tank could stand on first.
    local hasOption = #kits > 0 or free
    local canPlace = placeable and hasOption
    local notNow = floorHere and not placeable and hasOption
    -- 2026-09-15, found live: a floor that could take a tank, but this player
    -- has neither a kit nor free placement (e.g. FreeTanks=Admins for a
    -- non-admin), used to fall through every case above and vanish the whole
    -- entry - the same "mod looks uninstalled" failure this menu already
    -- guards against elsewhere, reached through a new door. Grey it out with
    -- a reason instead of hiding it.
    local noOptions = floorHere and not hasOption
    local betaHere = beta and (tank ~= nil or floorHere)
    if not tank and not canPlace and not notNow and not noOptions and not betaHere then return end
    if notNow then
        -- The commonest case by far is right-clicking the tile under your own
        -- feet, and "Someone or something is standing there" reads as if a
        -- zombie were in the way.
        local mine = false
        pcall(function() mine = player:getSquare() == sq end)
        if mine then whyNot = 'You are standing there. Step off the tile first.' end
    end

    local rootLabel = tank and (K.tierOf(tank:getModData().KnoxAquarium).label) or 'Fish Tank'
    local root = context:addOption(rootLabel)
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    if tank then
        addTankActions(menu, player, tank)
    elseif canPlace then
        addPlacement(menu, player, kits, sq, free)
    elseif notNow then
        -- This opens a cursor; only the final chosen square must be valid.
        addPlacement(menu, player, kits, sq, free)
    elseif noOptions then
        local root = menu:addOption('Place aquarium')
        root.notAvailable = true
        root.toolTip = ISWorldObjectContextMenu.addToolTip()
        root.toolTip.description = 'You need a tank kit to place one here.'
    end

    if betaHere and K.addBetaTools then
        -- Tools that only spawn items act on the player's own tile: the server
        -- ignores a command aimed at a square beyond placeRange.
        local here = sq
        if not tank then
            local ok, own = pcall(function() return player:getSquare() end)
            if ok and own then here = own end
        end
        K.addBetaTools(menu, player, here, tank)
    end
end)
