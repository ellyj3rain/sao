local NMClientRegistrySyncState = require "sync/registry_sync/NMClientRegistrySyncState"

local NMClientRegistrySyncMovement = {}

function NMClientRegistrySyncMovement.samplePlayerPosition(player)
    local sq = player and player.getSquare and player:getSquare() or nil
    if not sq then
        return nil
    end
    return {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ()
    }
end

function NMClientRegistrySyncMovement.hasMoved(snapshot, sample, moveDist2)
    if not sample then
        return false
    end
    if snapshot.lastX == nil or snapshot.lastY == nil or snapshot.lastZ == nil then
        return true
    end
    local px = tonumber(sample.x) or 0
    local py = tonumber(sample.y) or 0
    local pz = tonumber(sample.z) or 0
    local dz = math.abs(pz - snapshot.lastZ)
    local dx = px - snapshot.lastX
    local dy = py - snapshot.lastY
    return dz > 0 or ((dx * dx) + (dy * dy)) >= moveDist2
end

function NMClientRegistrySyncMovement.updatePositionCache(state, sample)
    local target = NMClientRegistrySyncState.ensure(state)
    target.lastX = sample.x
    target.lastY = sample.y
    target.lastZ = sample.z
    return target
end

return NMClientRegistrySyncMovement
