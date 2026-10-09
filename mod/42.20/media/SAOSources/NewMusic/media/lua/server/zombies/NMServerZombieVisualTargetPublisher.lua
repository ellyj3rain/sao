NMServerZombieVisualTargetPublisher = NMServerZombieVisualTargetPublisher or {}
require "zombies/NMZombieDeviceVariantCatalog"
NMServerZombieVisualTargetPublisher._tick = NMServerZombieVisualTargetPublisher._tick or 0
NMServerZombieVisualTargetPublisher._playerState = NMServerZombieVisualTargetPublisher._playerState or {}
NMServerZombieVisualTargetPublisher._pendingRealizationChanges = NMServerZombieVisualTargetPublisher._pendingRealizationChanges or {}
NMServerZombieVisualTargetPublisher._diag = NMServerZombieVisualTargetPublisher._diag or {
    publishCalls = 0,
    snapshotsSent = 0,
    targetCandidates = 0,
    targetPublished = 0,
    assistedPublishes = 0,
    bootstrapPublishes = 0,
    cadencePublishes = 0,
    movementPublishes = 0,
    realizationPublishes = 0
}

local function shouldLog()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_visual") == true
end

local function logSummary(tag, detail)
    if not shouldLog() then
        return
    end
    print("[NewMusic] [ZombieProof] " .. tostring(tag or "") .. " " .. tostring(detail or ""))
end

local function canPublish()
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true then
        return false
    end
    if not (NMCore and NMCore.isMultiplayerMode and NMCore.isMultiplayerMode() == true) then
        return false
    end
    if isClient and isClient() == true then
        return false
    end
    if not (sendServerCommand and NMCore and NMCore.NetModule) then
        return false
    end
    return true
end

local function isAliveZombie(zombie)
    if not (zombie and instanceof and instanceof(zombie, "IsoZombie")) then
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

local function getPlayerId(player)
    if player and player.getOnlineID then
        return tostring(player:getOnlineID() or "")
    end
    return tostring(player or "")
end

local function collectPlayers()
    local out = {}
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not (players and players.size) then
        return out
    end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            out[#out + 1] = player
        end
    end
    return out
end

local function getNearbyRadiusSq()
    return (tonumber(NMZombieVisualTargetContract and NMZombieVisualTargetContract.NearbyRadius) or 30) ^ 2
end

local function getPublishIntervalTicks()
    return tonumber(NMZombieVisualTargetContract and NMZombieVisualTargetContract.PublishIntervalTicks) or 90
end

local function getRepublishIntervalTicks()
    return tonumber(NMZombieVisualTargetContract and NMZombieVisualTargetContract.RepublishIntervalTicks) or 180
end

local function getMovementPublishCooldownTicks()
    local publishInterval = math.max(1, getPublishIntervalTicks())
    return math.max(15, math.floor(publishInterval / 3))
end

local function getClientCacheTtlTicks()
    return tonumber(NMZombieVisualTargetContract and NMZombieVisualTargetContract.ClientCacheTtlTicks) or 0
end

local function getMaxTargetsPerPlayer()
    return tonumber(NMZombieVisualTargetContract and NMZombieVisualTargetContract.MaxTargetsPerPlayer) or 96
end

local function getPlayerSquarePosition(player)
    local square = player and player.getSquare and player:getSquare() or nil
    if not square then
        return nil
    end
    return {
        x = tonumber(square:getX()) or 0,
        y = tonumber(square:getY()) or 0,
        z = tonumber(square:getZ()) or 0
    }
end

local function getActiveVisualStrategy()
    return NMZombieLiveStrategy and NMZombieLiveStrategy.getLiveVisualStrategy and NMZombieLiveStrategy.getLiveVisualStrategy() or "mp_assignment_flow"
end

local function makeNearbyZombieCheck(player)
    local square = player and player.getSquare and player:getSquare() or nil
    if not square then
        return nil
    end
    local px = (tonumber(square:getX()) or 0) + 0.5
    local py = (tonumber(square:getY()) or 0) + 0.5
    local pz = tonumber(square:getZ()) or 0
    local radiusSq = getNearbyRadiusSq()
    return function(zombie)
        if not (zombie and zombie.getX and zombie.getY) then
            return false
        end
        local zz = tonumber(zombie.getZ and zombie:getZ() or 0) or 0
        if math.abs(zz - pz) > 2 then
            return false
        end
        local dx = px - (tonumber(zombie:getX()) or 0)
        local dy = py - (tonumber(zombie:getY()) or 0)
        return ((dx * dx) + (dy * dy)) <= radiusSq
    end
end

local function buildTargetSnapshotRecord(zombie, activeStrategy)
    local zombieId = NMZombieVisualTargetContract and NMZombieVisualTargetContract.getZombieId and NMZombieVisualTargetContract.getZombieId(zombie) or tostring(zombie or "")
    if zombieId == "" then
        return nil
    end
    local selection = NMZombieVisualTargetLedger and NMZombieVisualTargetLedger.getOrAssignZombieSelection and NMZombieVisualTargetLedger.getOrAssignZombieSelection(zombie, activeStrategy) or nil
    if not (selection and NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.shouldRealizeSelection) then
        return nil
    end
    if NMZombieDeviceVariantCatalog.shouldRealizeSelection(selection) ~= true then
        return nil
    end
    local spec = NMZombieDeviceVariantCatalog.resolveRealization and NMZombieDeviceVariantCatalog.resolveRealization(selection, zombieId) or nil
    if not spec then
        return nil
    end
    return {
        zombieId = zombieId,
        variantId = tostring(spec.variantId or ""),
        fullType = tostring(spec.fullType or ""),
        attachmentLocation = tostring(spec.attachmentLocation or ""),
        modelAttachmentName = tostring(spec.modelAttachmentName or "")
    }
end

local function trackRealizationChange(zombie)
    local zombieId = NMZombieVisualTargetContract and NMZombieVisualTargetContract.getZombieId and NMZombieVisualTargetContract.getZombieId(zombie) or tostring(zombie or "")
    if zombieId == "" then
        return
    end
    NMServerZombieVisualTargetPublisher._pendingRealizationChanges[tostring(zombieId)] = {
        zombie = zombie,
        changedTick = tonumber(NMServerZombieVisualTargetPublisher._tick) or 0
    }
end

function NMServerZombieVisualTargetPublisher.noteRealizationChanged(zombie, realization)
    if not zombie then
        return false
    end
    if not (type(realization) == "table" and realization.needsVisualRefresh == true) then
        return false
    end
    trackRealizationChange(zombie)
    logSummary(
        "target_realization_change",
        string.format(
            "zombie=%s status=%s variant=%s fullType=%s proof=%s attachment=%s companion=%s",
            tostring(realization.zombieId or ""),
            tostring(realization.selectionStatus or ""),
            tostring(realization.variantId or ""),
            tostring(realization.fullType or ""),
            tostring(realization.proofItemStatus or ""),
            tostring(realization.attachmentStatus or ""),
            tostring(realization.companionCaseStatus or "")
        )
    )
    return true
end

local function collectTargetSnapshotForPlayer(player, zombies, activeStrategy)
    local allowZombie = makeNearbyZombieCheck(player)
    local result = {
        records = {},
        targetCandidates = 0,
        targetPublished = 0
    }
    if not allowZombie then
        return result
    end
    if not (zombies and zombies.size) then
        return result
    end
    local seen = {}
    local maxTargets = getMaxTargetsPerPlayer()
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if isAliveZombie(zombie) and allowZombie(zombie) then
            local zombieId = NMZombieVisualTargetContract and NMZombieVisualTargetContract.getZombieId and NMZombieVisualTargetContract.getZombieId(zombie) or tostring(zombie or "")
            if not seen[zombieId] then
                seen[zombieId] = true
                result.targetCandidates = result.targetCandidates + 1
                local snapshotRecord = buildTargetSnapshotRecord(zombie, activeStrategy)
                if snapshotRecord then
                    result.targetPublished = result.targetPublished + 1
                    result.records[#result.records + 1] = snapshotRecord
                    if #result.records >= maxTargets then
                        break
                    end
                end
            end
        end
    end
    table.sort(result.records, function(a, b)
        return tostring(a and a.zombieId or "") < tostring(b and b.zombieId or "")
    end)
    return result
end

local function shouldRepublishSnapshot(state, publishSignature)
    local republishInterval = getRepublishIntervalTicks()
    local ticksSinceSend = (tonumber(NMServerZombieVisualTargetPublisher._tick) or 0) - (tonumber(state.lastSentTick) or 0)
    return publishSignature ~= state.signature or ticksSinceSend >= republishInterval
end

local function hasPendingNearbyRealizationChange(player, pruneDead)
    local allowZombie = makeNearbyZombieCheck(player)
    if not allowZombie then
        return false
    end
    for zombieId, entry in pairs(NMServerZombieVisualTargetPublisher._pendingRealizationChanges) do
        local zombie = entry and entry.zombie or nil
        if zombie and isAliveZombie(zombie) and allowZombie(zombie) then
            return true
        end
        if pruneDead == true and (not zombie or not isAliveZombie(zombie)) then
            NMServerZombieVisualTargetPublisher._pendingRealizationChanges[zombieId] = nil
        end
    end
    return false
end

local function needsBootstrapSnapshot(state, player)
    if type(state) ~= "table" then
        return true
    end
    if state.signature == nil then
        return true
    end
    if state.playerRef ~= player then
        return true
    end
    if (tonumber(state.lastSeenTick) or 0) <= 0 then
        return true
    end
    return false
end

local function hasMovedEnoughForNearbyRefresh(state, player)
    if type(state) ~= "table" then
        return false
    end
    local squarePos = getPlayerSquarePosition(player)
    if not squarePos then
        return false
    end
    if state.lastPublishedSquareX == nil or state.lastPublishedSquareY == nil or state.lastPublishedSquareZ == nil then
        return false
    end
    local dx = math.abs(squarePos.x - (tonumber(state.lastPublishedSquareX) or squarePos.x))
    local dy = math.abs(squarePos.y - (tonumber(state.lastPublishedSquareY) or squarePos.y))
    local dz = math.abs(squarePos.z - (tonumber(state.lastPublishedSquareZ) or squarePos.z))
    if dz > 0 then
        return true
    end
    return dx >= 2 or dy >= 2
end

local function canMovementRepublishAtTick(state, tick)
    if type(state) ~= "table" then
        return false
    end
    local lastMovementPublishTick = tonumber(state.lastMovementPublishTick) or 0
    return ((tonumber(tick) or 0) - lastMovementPublishTick) >= getMovementPublishCooldownTicks()
end

local function hasTrackedPlayerState()
    for _ in pairs(NMServerZombieVisualTargetPublisher._playerState) do
        return true
    end
    return false
end

local function pruneExpiredPendingRealizationChanges()
    local nowTick = tonumber(NMServerZombieVisualTargetPublisher._tick) or 0
    local publishInterval = math.max(1, getPublishIntervalTicks())
    for zombieId, entry in pairs(NMServerZombieVisualTargetPublisher._pendingRealizationChanges) do
        local changedTick = tonumber(entry and entry.changedTick) or 0
        if changedTick <= 0 or (nowTick - changedTick) >= publishInterval then
            NMServerZombieVisualTargetPublisher._pendingRealizationChanges[zombieId] = nil
        end
    end
end

local function buildPublishPlan(players, options)
    local tick = tonumber(options and options.tick) or tonumber(NMServerZombieVisualTargetPublisher._tick) or 0
    local pruneDead = options and options.pruneDead == true
    local plans = {}
    local summary = {
        bootstrap = false,
        movement = false,
        realization = false
    }

    for i = 1, #players do
        local player = players[i]
        local playerId = getPlayerId(player)
        if playerId ~= "" then
            local state = NMServerZombieVisualTargetPublisher._playerState[playerId]
            local bootstrapNeeded = needsBootstrapSnapshot(state, player)
            local movementNeeded = hasMovedEnoughForNearbyRefresh(state, player) and canMovementRepublishAtTick(state, tick)
            local nearbyChangePending = hasPendingNearbyRealizationChange(player, pruneDead)
            plans[#plans + 1] = {
                player = player,
                playerId = playerId,
                state = state,
                bootstrapNeeded = bootstrapNeeded,
                movementNeeded = movementNeeded,
                nearbyChangePending = nearbyChangePending
            }
            summary.bootstrap = summary.bootstrap or bootstrapNeeded
            summary.movement = summary.movement or movementNeeded
            summary.realization = summary.realization or nearbyChangePending
        end
    end

    if pruneDead == true then
        pruneExpiredPendingRealizationChanges()
    end

    return plans, summary
end

local function publishSnapshot(player, state, snapshot, publishReason)
    state.revision = (tonumber(state.revision) or 0) + 1
    state.lastSentTick = tonumber(NMServerZombieVisualTargetPublisher._tick) or 0
    local squarePos = getPlayerSquarePosition(player)
    if squarePos then
        state.lastPublishedSquareX = squarePos.x
        state.lastPublishedSquareY = squarePos.y
        state.lastPublishedSquareZ = squarePos.z
    end
    if publishReason == "movement" then
        state.lastMovementPublishTick = state.lastSentTick
    end
    sendServerCommand(player, NMCore.NetModule, NMZombieVisualTargetContract.NetCommand, {
        revision = state.revision,
        ttlTicks = getClientCacheTtlTicks(),
        targetRecords = snapshot.records,
        targetCandidates = snapshot.targetCandidates,
        targetPublished = snapshot.targetPublished
    })
    NMServerZombieVisualTargetPublisher._diag.snapshotsSent = (NMServerZombieVisualTargetPublisher._diag.snapshotsSent or 0) + 1
    if publishReason == "bootstrap" then
        NMServerZombieVisualTargetPublisher._diag.bootstrapPublishes = (NMServerZombieVisualTargetPublisher._diag.bootstrapPublishes or 0) + 1
    elseif publishReason == "movement" then
        NMServerZombieVisualTargetPublisher._diag.movementPublishes = (NMServerZombieVisualTargetPublisher._diag.movementPublishes or 0) + 1
        NMServerZombieVisualTargetPublisher._diag.assistedPublishes = (NMServerZombieVisualTargetPublisher._diag.assistedPublishes or 0) + 1
    elseif publishReason == "realization" then
        NMServerZombieVisualTargetPublisher._diag.realizationPublishes = (NMServerZombieVisualTargetPublisher._diag.realizationPublishes or 0) + 1
        NMServerZombieVisualTargetPublisher._diag.assistedPublishes = (NMServerZombieVisualTargetPublisher._diag.assistedPublishes or 0) + 1
    else
        NMServerZombieVisualTargetPublisher._diag.cadencePublishes = (NMServerZombieVisualTargetPublisher._diag.cadencePublishes or 0) + 1
    end
    logSummary(
        "target_publish_reason",
        string.format(
            "player=%s reason=%s revision=%s records=%s candidates=%s published=%s tick=%s",
            tostring(getPlayerId(player)),
            tostring(publishReason or "cadence"),
            tostring(state.revision or 0),
            tostring(snapshot and #snapshot.records or 0),
            tostring(snapshot and snapshot.targetCandidates or 0),
            tostring(snapshot and snapshot.targetPublished or 0),
            tostring(NMServerZombieVisualTargetPublisher._tick or 0)
        )
    )
end

function NMServerZombieVisualTargetPublisher.onTick(tickStep, absoluteTick)
    if not canPublish() then
        return
    end
    if tonumber(absoluteTick) then
        NMServerZombieVisualTargetPublisher._tick = tonumber(absoluteTick) or 0
    else
        NMServerZombieVisualTargetPublisher._tick = (tonumber(NMServerZombieVisualTargetPublisher._tick) or 0) + math.max(1, tonumber(tickStep) or 1)
    end
    local players = collectPlayers()
    local publishIntervalDue = (NMServerZombieVisualTargetPublisher._tick % getPublishIntervalTicks()) == 0
    local plans, summary = buildPublishPlan(players, { tick = NMServerZombieVisualTargetPublisher._tick, pruneDead = true })
    if not publishIntervalDue and summary.bootstrap ~= true and summary.realization ~= true and summary.movement ~= true and hasTrackedPlayerState() ~= true then
        return
    end
    local needsSnapshot = publishIntervalDue or summary.bootstrap == true or summary.realization == true or summary.movement == true
    if needsSnapshot ~= true then
        local activePlayers = {}
        for i = 1, #plans do
            activePlayers[plans[i].playerId] = true
        end
        for playerId, _ in pairs(NMServerZombieVisualTargetPublisher._playerState) do
            if activePlayers[playerId] ~= true then
                NMServerZombieVisualTargetPublisher._playerState[playerId] = nil
            end
        end
        return
    end
    local zombies = needsSnapshot and getCell() and getCell():getZombieList() or nil
    local activeStrategy = getActiveVisualStrategy()
    local activePlayers = {}
    NMServerZombieVisualTargetPublisher._diag.publishCalls = (NMServerZombieVisualTargetPublisher._diag.publishCalls or 0) + 1
    for i = 1, #plans do
        local plan = plans[i]
        local player = plan.player
        local playerId = plan.playerId
        if playerId ~= "" then
            activePlayers[playerId] = true
            local state = plan.state or { revision = 0, signature = nil, lastSentTick = 0 }
            local snapshot = collectTargetSnapshotForPlayer(player, zombies, activeStrategy)
            local signature = NMZombieVisualTargetContract and NMZombieVisualTargetContract.getTargetSnapshotSignature and NMZombieVisualTargetContract.getTargetSnapshotSignature(snapshot.records) or ""
            NMServerZombieVisualTargetPublisher._diag.targetCandidates = (NMServerZombieVisualTargetPublisher._diag.targetCandidates or 0) + snapshot.targetCandidates
            NMServerZombieVisualTargetPublisher._diag.targetPublished = (NMServerZombieVisualTargetPublisher._diag.targetPublished or 0) + snapshot.targetPublished
            local publishReason = nil
            if plan.bootstrapNeeded then
                publishReason = "bootstrap"
            elseif plan.nearbyChangePending then
                publishReason = "realization"
            elseif plan.movementNeeded and signature ~= state.signature then
                publishReason = "movement"
            elseif shouldRepublishSnapshot(state, signature) then
                publishReason = "cadence"
            end
            if publishReason ~= nil then
                publishSnapshot(player, state, snapshot, publishReason)
                state.signature = signature
            end
            state.lastSeenTick = NMServerZombieVisualTargetPublisher._tick
            state.playerRef = player
            NMServerZombieVisualTargetPublisher._playerState[playerId] = state
        end
    end
    for playerId, _ in pairs(NMServerZombieVisualTargetPublisher._playerState) do
        if activePlayers[playerId] ~= true then
            NMServerZombieVisualTargetPublisher._playerState[playerId] = nil
        end
    end
    logSummary(
        "target_publish",
        string.format(
            "players=%s publishCalls=%s snapshotsSent=%s assisted=%s bootstrap=%s movement=%s realization=%s cadence=%s candidates=%s published=%s",
            tostring(#players),
            tostring(NMServerZombieVisualTargetPublisher._diag.publishCalls or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.snapshotsSent or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.assistedPublishes or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.bootstrapPublishes or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.movementPublishes or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.realizationPublishes or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.cadencePublishes or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.targetCandidates or 0),
            tostring(NMServerZombieVisualTargetPublisher._diag.targetPublished or 0)
        )
    )
    if NMServerZombieVisualTargetLedger and NMServerZombieVisualTargetLedger.logDiag then
        NMServerZombieVisualTargetLedger.logDiag("target_ledger")
    end
end

function NMServerZombieVisualTargetPublisher.hasPublishWork(currentTick)
    if not canPublish() then
        return false
    end
    local nextTick = tonumber(currentTick) or ((tonumber(NMServerZombieVisualTargetPublisher._tick) or 0) + 1)
    local players = collectPlayers()
    if #players <= 0 then
        return hasTrackedPlayerState() == true
    end
    local publishIntervalDue = (nextTick % getPublishIntervalTicks()) == 0
    if publishIntervalDue == true then
        return true
    end
    local _plans, summary = buildPublishPlan(players, { tick = nextTick, pruneDead = false })
    return summary.bootstrap == true or summary.realization == true or summary.movement == true
end

return NMServerZombieVisualTargetPublisher
