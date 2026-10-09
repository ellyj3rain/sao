-- Shared scan helpers for server zombie runtime strategies.
NMServerZombieScanHelpers = NMServerZombieScanHelpers or {}

function NMServerZombieScanHelpers.isIsoZombie(obj)
    return obj and instanceof and instanceof(obj, "IsoZombie")
end

function NMServerZombieScanHelpers.isAliveZombie(zombie)
    if not NMServerZombieScanHelpers.isIsoZombie(zombie) then
        return false
    end
    if zombie.isDead and zombie:isDead() then
        return false
    end
    if zombie.isOnDeathDone and zombie:isOnDeathDone() then
        return false
    end
    return true
end

function NMServerZombieScanHelpers.collectCandidatePlayers(options)
    local out = {}
    local seen = {}
    local playerLimit = math.max(1, tonumber(options and options.playerLimit) or 1)
    local includeSpecificPlayers = not (options and options.includeSpecificPlayers == false)
    local includeLocalPlayer = options and options.includeLocalPlayer == true

    local onlinePlayers = getOnlinePlayers and getOnlinePlayers() or nil
    if onlinePlayers and onlinePlayers.size then
        for i = 0, onlinePlayers:size() - 1 do
            local player = onlinePlayers:get(i)
            if player then
                out[#out + 1] = player
                seen[player] = true
                if #out >= playerLimit then
                    return out
                end
            end
        end
    end

    if includeSpecificPlayers then
        for i = 0, playerLimit - 1 do
            local player = getSpecificPlayer and getSpecificPlayer(i) or nil
            if player and not seen[player] then
                out[#out + 1] = player
                seen[player] = true
                if #out >= playerLimit then
                    return out
                end
            end
        end
    end

    if includeLocalPlayer then
        local localPlayer = getPlayer and getPlayer() or nil
        if localPlayer and not seen[localPlayer] then
            out[#out + 1] = localPlayer
        end
    end

    return out
end

function NMServerZombieScanHelpers.isZombieNearAnyPlayer(zombie, players, radiusSq)
    if not (zombie and zombie.getX and zombie.getY) then
        return false
    end
    local zx = tonumber(zombie:getX()) or 0
    local zy = tonumber(zombie:getY()) or 0
    local zz = tonumber(zombie.getZ and zombie:getZ() or 0) or 0
    local distanceLimit = math.max(0, tonumber(radiusSq) or 0)
    for i = 1, #players do
        local player = players[i]
        local square = player and player.getSquare and player:getSquare() or nil
        if square then
            local pz = tonumber(square:getZ()) or 0
            if math.abs(zz - pz) <= 2 then
                local dx = (tonumber(square:getX()) or 0) + 0.5 - zx
                local dy = (tonumber(square:getY()) or 0) + 0.5 - zy
                if ((dx * dx) + (dy * dy)) <= distanceLimit then
                    return true
                end
            end
        end
    end
    return false
end

function NMServerZombieScanHelpers.scanAroundCharacter(character, callback, radius, maxZombies)
    local square = character and character.getCurrentSquare and character:getCurrentSquare() or nil
    local cell = getCell and getCell() or nil
    if not (square and cell and cell.getGridSquare) then
        return 0
    end
    local seen = {}
    local processed = 0
    local scanRadius = math.max(0, tonumber(radius) or 0)
    local scanMax = math.max(0, tonumber(maxZombies) or 0)
    if scanMax <= 0 then
        return 0
    end
    local squareZ = tonumber(square:getZ()) or 0
    for x = square:getX() - scanRadius, square:getX() + scanRadius do
        for y = square:getY() - scanRadius, square:getY() + scanRadius do
            if processed >= scanMax then
                return processed
            end
            local gridSquare = cell:getGridSquare(x, y, squareZ)
            if gridSquare then
                local moving = gridSquare.getMovingObjects and gridSquare:getMovingObjects() or nil
                local movingSize = moving and moving.size and moving:size() or 0
                for i = 0, movingSize - 1 do
                    local zombie = moving:get(i)
                    local id = zombie and zombie.getObjectID and tostring(zombie:getObjectID() or "") or tostring(zombie)
                    if not seen[id] and NMServerZombieScanHelpers.isAliveZombie(zombie) then
                        seen[id] = true
                        if callback then
                            callback(zombie)
                        end
                        processed = processed + 1
                        if processed >= scanMax then
                            return processed
                        end
                    end
                end
            end
        end
    end
    return processed
end

function NMServerZombieScanHelpers.countZombiesWithModulo(zombies, startIndex, count, visitor)
    if not (zombies and zombies.size and visitor) then
        return 0
    end
    local total = zombies:size()
    if total <= 0 then
        return 0
    end
    local processed = 0
    for offset = 0, math.min(count, total) - 1 do
        local index = (startIndex + offset) % total
        visitor(zombies:get(index), index)
        processed = processed + 1
    end
    return processed
end

return NMServerZombieScanHelpers
