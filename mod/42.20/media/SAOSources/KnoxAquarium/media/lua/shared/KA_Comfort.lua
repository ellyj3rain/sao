--[[ Knox Aquarium - the comfort a stocked tank gives the person watching it.

    Asked for on the Workshop: "gain happiness when near a fish tank with fish
    in it". Aquariums are a real-world stress reliever and Project Zomboid has
    exactly the stats for it.

    Deliberately small:

      * It never makes a stat WORSE. Walking away simply stops the benefit.
      * It cannot stack: the same tank counts once, and the total is capped, so
        a room lined with aquariums is not an unhappiness cheat.
      * A tank with no fish does nothing. It is the fish that are calming.

    WHO applies it (this file is shared since 0.13 so the server has it):

      * single player  - the game itself, for every local player
      * multiplayer    - the SERVER, for every online player, then it pushes the
                         three stats to that player with syncPlayerStats. In
                         B42.20 mood is the server's: a client may only send its
                         own stats with the CanModifyBodyStats capability, and the
                         server's SyncPlayerStats overwrites anything else. This
                         used to run on the client in multiplayer too, where it
                         did nothing a server would keep. It is the same place
                         vanilla relieves mood when you pick flowers
                         (server/Farming/SFarmingSystem.lua).
      * a multiplayer client does nothing here, so nothing is applied twice.
]]
require 'KA_Core'
local K = KnoxAquarium

-- Tuning. Applied per game minute while the player is near occupied water.
-- The three stats are the same ones vanilla relieves when you pick flowers
-- (SFarmingSystem.lua), and the amounts are deliberately smaller than that: an
-- aquarium is pleasant, not a mood cure.
--
-- PLAYTEST 2026-09-16: range and maxTanks are now sandbox options
-- (KnoxAquarium.ComfortRange / ComfortMaxTanks, read live via K.sandbox below)
-- so a server can retune them; the numbers here are both the ORIGINAL
-- hardcoded values and the options' shipped defaults, so nothing changes for
-- a save/server that never touches the sandbox page. The stat amounts and
-- minFish stay plain constants - the ask was a range/cap knob and an on/off
-- switch, not a full tuning page, and the smaller the surface the less that
-- can drift from what was actually tested.
K.comfort = {
    range        = 6,      -- tiles; roughly "in the same room as it" (default only; see K.comfortRange())
    unhappiness  = 1.5,
    boredom      = 1.0,
    stress       = 0.6,
    maxTanks     = 3,      -- more tanks than this add nothing (default only; see K.comfortMaxTanks())
    minFish      = 1,
}

-- Whether the whole feature is switched on at all (KnoxAquarium.ComfortEnabled,
-- default true - the mod's behaviour before this option existed).
function K.comfortEnabled()
    return K.sandbox('ComfortEnabled', true) ~= false
end
function K.comfortRange()
    local v = tonumber(K.sandbox('ComfortRange', K.comfort.range))
    return (v and v > 0) and v or K.comfort.range
end
function K.comfortMaxTanks()
    local v = tonumber(K.sandbox('ComfortMaxTanks', K.comfort.maxTanks))
    return (v and v >= 1) and math.floor(v) or K.comfort.maxTanks
end

-- How many stocked, watered tanks the player is standing near.
function K.comfortTanksNear(player)
    if not player then return 0 end
    local cfg = K.comfort
    local range, maxTanks = K.comfortRange(), K.comfortMaxTanks()
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local cell = getCell()
    if not cell then return 0 end
    local found = 0
    for x = math.floor(px - range), math.floor(px + range) do
        for y = math.floor(py - range), math.floor(py + range) do
            local sq = cell:getGridSquare(x, y, pz)
            if sq then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    -- once a minute around every online player: read without
                    -- giving every nearby wall a mod data table (K.tankData)
                    local d = K.tankData(objects:get(i))
                    -- Fish in water. A dry habitat with a rat in it is charming
                    -- but this was asked for as a FISH tank benefit, and an
                    -- empty tank is just furniture.
                    if d and not K.isDry(d) and #(d.fish or {}) >= cfg.minFish
                       and (tonumber(d.water) or 0) > 0 then
                        found = found + 1
                        if found >= maxTanks then return found end
                    end
                end
            end
        end
    end
    return found
end

-- Stats:remove() is the call vanilla itself uses, and it clamps at zero, so a
-- calm character cannot be pushed negative. BodyDamage has NO unhappiness
-- method in this build - an earlier draft of this file called one that does not
-- exist, which would have thrown straight through the pcall around it.
function K.applyComfort(player)
    if not player or player:isDead() then return 0 end
    if not K.comfortEnabled() then return 0 end
    local tanks = K.comfortTanksNear(player)
    if tanks < 1 then return 0 end
    local stats = player:getStats()
    if not stats then return 0 end
    local scale = tanks / K.comfortMaxTanks()
    if scale > 1 then scale = 1 end
    pcall(function()
        stats:remove(CharacterStat.UNHAPPINESS, K.comfort.unhappiness * scale)
        stats:remove(CharacterStat.BOREDOM,     K.comfort.boredom     * scale)
        stats:remove(CharacterStat.STRESS,      K.comfort.stress      * scale)
    end)
    return tanks
end

-- Which stats syncPlayerStats should push: the game's own bit for each, asked
-- of SyncPlayerStatsPacket so a future reordering cannot break it; failing
-- that, the B42.20 bits (CharacterStat.ORDERED_STATS: BOREDOM is index 1,
-- STRESS 17, UNHAPPINESS 20 - read out of the jar).
function K.comfortStatMask()
    local ok, mask = pcall(function()
        local bit = SyncPlayerStatsPacket.getBitMaskForStat
        return bit(CharacterStat.UNHAPPINESS) + bit(CharacterStat.BOREDOM) + bit(CharacterStat.STRESS)
    end)
    if ok and type(mask) == 'number' and mask > 0 then return mask end
    return 0x100000 + 0x20000 + 0x2
end

Events.EveryOneMinute.Add(function()
    -- a multiplayer client: the server does it (see the header)
    if isClient() then return end
    if isServer() then
        local ok, players = pcall(getOnlinePlayers)
        if not ok or not players then return end
        local mask
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            local done, tanks = pcall(K.applyComfort, p)
            if done and type(tanks) == 'number' and tanks > 0 then
                mask = mask or K.comfortStatMask()
                pcall(syncPlayerStats, p, mask)
            end
        end
        return
    end
    -- single player: every local player, so split screen is covered too
    for n = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(n)
        if p then pcall(K.applyComfort, p) end
    end
end)
