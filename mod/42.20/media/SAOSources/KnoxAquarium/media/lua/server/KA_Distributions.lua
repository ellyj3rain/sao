-- Where an Empty Aquarium can be found in the world.
--
-- The tank is also placeable free from the right-click menu during the beta, so
-- these are a survival route rather than the only route. Weights are deliberately
-- low in homes: LivingRoomShelf alone appears in six room types, and an aquarium
-- in every living room would be absurd.
--
-- ProceduralDistributions is a global owned by the base game and is not loaded
-- while mods are being read, so this is done on the event rather than at require
-- time. OnPreDistributionMerge runs before the tables are compiled for the world.
local K = KnoxAquarium or {}
KnoxAquarium = K

-- The large tank is a rarer find than the standard one, and only where a big
-- display tank plausibly lived.
K.largeLootPlaces = {
    {'PetShopShelf', 2},
    {'CrateFishing', 0.8},
}

K.displayLootPlaces = {
    {'PetShopShelf', 1},
}

K.lootPlaces = {
    {'PetShopShelf', 8},         -- pet shops: the obvious home, and a rare building
    {'CrateFishing', 3},         -- fishing supplies, for someone already fishing
    {'ClosetShelfGeneric', 0.8}, -- packed away in a closet
    {'LivingRoomShelf', 0.6},    -- somebody's front room, uncommon on purpose
    {'ShelfGeneric', 0.5},       -- the occasional lucky shelf
}

function K.addLoot(list)
    local added, skipped = 0, 0
    local wanted = {}
    for _, p in ipairs(K.lootPlaces) do table.insert(wanted, {p[1], p[2], 'KnoxAquarium.TankKit'}) end
    for _, p in ipairs(K.largeLootPlaces) do table.insert(wanted, {p[1], p[2], 'KnoxAquarium.LargeTankKit'}) end
    for _, p in ipairs(K.displayLootPlaces) do table.insert(wanted, {p[1], p[2], 'KnoxAquarium.DisplayTankKit'}) end
    for _, place in ipairs(wanted) do
        local table_ = list and list[place[1]]
        if type(table_) == 'table' and type(table_.items) == 'table' then
            -- The merge event can fire more than once in a session; never stack
            -- duplicate entries, which would quietly multiply the spawn rate.
            local present = false
            for i = 1, #table_.items, 2 do
                if table_.items[i] == place[3] then present = true; break end
            end
            if not present then
                table.insert(table_.items, place[3])
                table.insert(table_.items, place[2])
                added = added + 1
            end
        else
            -- A base-game table that has been renamed or removed by another mod.
            skipped = skipped + 1
        end
    end
    return added, skipped
end

Events.OnPreDistributionMerge.Add(function()
    local added, skipped = K.addLoot(ProceduralDistributions and ProceduralDistributions.list)
    print('[KnoxAquarium] aquarium loot added to ' .. added .. ' distribution tables'
        .. (skipped > 0 and (', ' .. skipped .. ' unavailable') or ''))
end)
