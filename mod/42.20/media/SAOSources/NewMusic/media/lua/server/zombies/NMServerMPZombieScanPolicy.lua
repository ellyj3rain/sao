require "zombies/NMServerZombieScanHelpers"

NMServerMPZombieScanPolicy = NMServerMPZombieScanPolicy or {}

function NMServerMPZombieScanPolicy.shouldRunNaturalIntakeScan(ticks, interval)
    local scanInterval = tonumber(interval) or 0
    local nowTicks = tonumber(ticks) or 0
    return scanInterval > 0 and (nowTicks % scanInterval) == 0
end

function NMServerMPZombieScanPolicy.shouldRunFallbackScan(ticks, tickInterval)
    local interval = tonumber(tickInterval) or 0
    local nowTicks = tonumber(ticks) or 0
    return interval > 0 and (nowTicks % interval) == 0
end

function NMServerMPZombieScanPolicy.scanAroundCharacter(character, callback, radius, maxZombies)
    return NMServerZombieScanHelpers.scanAroundCharacter(character, callback, radius, maxZombies)
end

local function visitPlayers(players, visitor)
    if players and players.size then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player then
                visitor(player)
            end
        end
        return true
    end
    return false
end

function NMServerMPZombieScanPolicy.observeNaturalCandidates(players, fallbackPlayer, enqueueFn, diag, options)
    local scanned = 0
    local scanSource = options and options.source or "first_seen_scan"
    local radius = options and options.radius or 0
    local maxZombies = options and options.maxZombies or 0
    local callback = function(zombie)
        if enqueueFn then
            enqueueFn(zombie, scanSource)
        end
    end

    local visitedPlayers = visitPlayers(players, function(player)
        scanned = scanned + NMServerMPZombieScanPolicy.scanAroundCharacter(player, callback, radius, maxZombies)
    end)

    if not visitedPlayers and fallbackPlayer then
        scanned = scanned + NMServerMPZombieScanPolicy.scanAroundCharacter(fallbackPlayer, callback, radius, maxZombies)
    end

    if diag then
        diag.queueScanned = (diag.queueScanned or 0) + scanned
    end
    return scanned
end

function NMServerMPZombieScanPolicy.runFallback(players, fallbackPlayer, applyFn, options)
    local applied = 0
    local source = options and options.source or "fallback_scan"
    local radius = options and options.radius or 0
    local maxZombies = options and options.maxZombies or 0
    local callback = function(zombie)
        if applyFn and applyFn(zombie, source) == true then
            applied = applied + 1
        end
    end

    local visitedPlayers = visitPlayers(players, function(player)
        NMServerMPZombieScanPolicy.scanAroundCharacter(player, callback, radius, maxZombies)
    end)

    if not visitedPlayers and fallbackPlayer then
        NMServerMPZombieScanPolicy.scanAroundCharacter(fallbackPlayer, callback, radius, maxZombies)
    end

    return applied
end

return NMServerMPZombieScanPolicy
