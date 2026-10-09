-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
--[[ Knox Aquarium - rotate a PLACED tank with the ordinary rotate key.

    Reported on the Workshop: people expect the normal furniture rotate key to
    turn an aquarium and it does nothing, so they have to find the radial menu.

    Why the vanilla tool cannot already do it: a tank is an IsoObject whose
    sprite is built at runtime by KA_Client, so it carries none of the tile
    properties the moveables cursor looks for. Giving it those properties would
    let vanilla pick the tank up as generic furniture and lose the fish inside,
    so instead this listens for the SAME key the player has bound for "Rotate
    building" and rotates the tank under the mouse through the mod's own,
    already-safe rotate command - the one the radial menu uses, which keeps the
    contents and is server-authoritative in multiplayer.

    It never consumes the key: vanilla's own handler runs as usual, so placing
    furniture, painting and every other cursor behave exactly as before.
]]
require 'KA_Core'
local K = KnoxAquarium

-- The tank under the mouse, or nil. Walks down through floors the way vanilla's
-- own square-under-cursor helper does, so a tank on a lower level still counts.
function K.tankUnderMouse(player)
    if not player then return nil end
    local ok, result = pcall(function()
        local mx, my = getMouseX(), getMouseY()
        local z = player:getZ()
        while z >= 0 do
            local wx, wy = ISCoordConversion.ToWorld(mx, my, z)
            local sq = getCell():getGridSquare(wx, wy, z)
            if sq then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    local md = K.modDataOf(obj) or {}
                    if md.KnoxAquarium then return obj, sq end
                    -- the second tile of a two-tile tank turns the whole tank
                    if md.KnoxAquariumPart and K.masterOf then
                        local tank = K.masterOf(obj)
                        if tank then return tank, tank:getSquare() end
                    end
                end
                if sq:TreatAsSolidFloor() then return nil end
            end
            z = z - 1
        end
        return nil
    end)
    if ok then return result end
    return nil
end

Events.OnKeyPressed.Add(function(key)
    local ok = pcall(function()
        if not getCore():isKey('Rotate building', key) then return end
        local player = getSpecificPlayer(0)
        if not player or player:isDead() then return end
        -- Something is already being placed: that drag owns the key, and
        -- KAPlacement/ISBuildingObject will handle it.
        local cell = getCell()
        if cell and cell:getDrag(0) then return end
        local obj = K.tankUnderMouse(player)
        if not obj then return end
        local sq = obj:getSquare()
        if not sq then return end
        -- Same reach rule as every other tank interaction.
        if math.abs(player:getX() - sq:getX()) > K.placeRange
           or math.abs(player:getY() - sq:getY()) > K.placeRange
           or player:getZ() ~= sq:getZ() then
            player:Say('Too far from the aquarium to turn it.')
            return
        end
        -- The mod's own rotate: keeps water, fish and animals, and in
        -- multiplayer the server performs it.
        K.send(player, 'rotate', sq)
    end)
    if not ok then return end
end)
