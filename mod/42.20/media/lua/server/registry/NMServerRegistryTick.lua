-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Server registry heartbeat tick for cleanup and periodic broadcast refresh.
NMServerRegistryTick = NMServerRegistryTick or {}

local function nowRealMinutes()
    local ms = nil
    if getTimestampMs then ms = tonumber(getTimestampMs()) end
    if ms == nil and getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then ms = ts * 1000 end
    end
    if ms == nil and os and os.time then
        local t = tonumber(os.time())
        if t then ms = t * 1000 end
    end
    if ms == nil then return 0 end
    return ms / 60000.0
end

local function getNearestPlayerDistanceSq(x, y, z, floorsLimit)
    local best = nil
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        local sq = p and p.getSquare and p:getSquare() or nil
        if sq then
            local dz = math.abs((sq:getZ() or 0) - (tonumber(z) or 0))
            if dz <= math.max(0, tonumber(floorsLimit) or 0) then
                local dx = (sq:getX() or 0) - (tonumber(x) or 0)
                local dy = (sq:getY() or 0) - (tonumber(y) or 0)
                local d2 = (dx * dx) + (dy * dy)
                if best == nil or d2 < best then best = d2 end
            end
        end
    end
    return best
end

local function broadcastSnapshot(entry, op)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players or not sendServerCommand then return end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            sendServerCommand(p, NMCore.NetModule, "registry_update", {
                op = tostring(op or "upsert"),
                payload = NMServerRegistryBroadcast.buildPayload(entry, entry.stateSnapshot),
                serverSessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
            })
        end
    end
end

local function broadcastUpsertIfChanged(worldRegistry, uuid, entry, tickNow)
    if not entry then
        return 0
    end
    local function recipients(applyFn)
        local players = getOnlinePlayers and getOnlinePlayers() or nil
        if not players then
            return
        end
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                applyFn(p)
            end
        end
    end
    return NMServerRegistryBroadcast.broadcastEntry(
        worldRegistry,
        tostring(uuid or ""),
        nil,
        entry.stateSnapshot,
        "upsert",
        recipients,
        {
            trigger = "heartbeat",
            heartbeatTick = tonumber(tickNow) or 0
        }
    )
end

local function resolveOnlinePlayerByOwner(entry)
    local ownerId = tostring(entry and (entry.ownerOnlineId or entry.ownerId) or "")
    local ownerName = tostring(entry and entry.ownerUsername or "")
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return nil
    end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local pid = p.getOnlineID and tostring(p:getOnlineID() or "") or ""
            local pname = p.getUsername and tostring(p:getUsername() or "") or ""
            if ownerId ~= "" and pid == ownerId then
                return p
            end
            if ownerName ~= "" and pname == ownerName then
                return p
            end
        end
    end
    return nil
end

local function shouldPurgePortableOwnerGhost(entry, profile)
    if not (entry and profile and NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile)) then
        return false
    end
    local sourceMode = tostring(entry.sourceMode or "")
    if sourceMode ~= "attached" and sourceMode ~= "stowed" then
        return false
    end
    local owner = resolveOnlinePlayerByOwner(entry)
    if not owner then
        return false
    end
    local inv = owner.getInventory and owner:getInventory() or nil
    if not inv then
        return false
    end
    local uuid = tostring(entry.uuid or "")
    if uuid == "" then
        return false
    end
    local item = NMInventoryHelpers and NMInventoryHelpers.findItemByUuid and NMInventoryHelpers.findItemByUuid(inv, uuid) or nil
    return item == nil
end

function NMServerRegistryTick.hasWorldSources()
    local worldRegistry = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(worldRegistry) ~= "table" then
        return false
    end
    for _ in pairs(worldRegistry) do
        return true
    end
    return false
end

function NMServerRegistryTick.onTick()
    if not NMCore.isMPServerAuthority() then return end

    NMServerRegistryState.registryTick = (tonumber(NMServerRegistryState.registryTick) or 0) + 1
    local tickNow = NMServerRegistryState.registryTick

    local heartbeatEvery = math.max(1, tonumber(NMRuntimeConfig.getRegistryHeartbeatIntervalTicks and NMRuntimeConfig.getRegistryHeartbeatIntervalTicks() or 120) or 120)
    if (tickNow % heartbeatEvery) ~= 0 then
        return
    end

    local nowMin = nowRealMinutes()
    local active = {}

    for uuid, entry in pairs(NMServerRegistryState.worldRegistry) do
        local state = entry and entry.stateSnapshot or nil
        local profileType = entry and entry.profileType or nil
        local profile = NMDeviceProfiles and profileType and NMDeviceProfiles.getForFullType(profileType) or nil
        local shouldKeep = NMRegistryPolicy.shouldKeepWorldSourceState(state)

        if not shouldKeep then
            NMServerRegistryState.worldRegistry[uuid] = nil
            NMServerRegistryState.dormancySinceMinutes[uuid] = nil
            NMServerRegistryState.unresolvedNearSinceMinutes[uuid] = nil
            broadcastSnapshot(entry, "remove")
        elseif shouldPurgePortableOwnerGhost(entry, profile) then
            NMServerRegistryState.worldRegistry[uuid] = nil
            NMServerRegistryState.dormancySinceMinutes[uuid] = nil
            NMServerRegistryState.unresolvedNearSinceMinutes[uuid] = nil
            broadcastSnapshot(entry, "remove")
        else
            local trackingRange = NMDeviceProfiles and NMDeviceProfiles.getWorldTrackingRange and NMDeviceProfiles.getWorldTrackingRange(profile) or 0
            local trackingFloors = NMDeviceProfiles and NMDeviceProfiles.getWorldTrackingFloors and NMDeviceProfiles.getWorldTrackingFloors(profile) or 0
            local nearestD2 = getNearestPlayerDistanceSq(entry.x, entry.y, entry.z, trackingFloors)
            local inRange = nearestD2 ~= nil and (trackingRange <= 0 or nearestD2 <= (trackingRange * trackingRange))

            if inRange then
                entry.lastSeenAtRealMinutes = nowMin
                NMServerRegistryState.dormancySinceMinutes[uuid] = nil
            else
                if entry.lastSeenAtRealMinutes == nil then
                    entry.lastSeenAtRealMinutes = nowMin
                end
                if NMRegistryPolicy.shouldKillUnseen(entry.lastSeenAtRealMinutes, nowMin) then
                    NMRegistryPolicy.markTombstone(state, profile)
                    NMServerRegistryState.dormancyTombstones[uuid] = nowMin
                    NMServerRegistryState.worldRegistry[uuid] = nil
                    NMServerRegistryState.dormancySinceMinutes[uuid] = nil
                    broadcastSnapshot(entry, "remove")
                end

                local started = tonumber(NMServerRegistryState.dormancySinceMinutes[uuid])
                if NMServerRegistryState.worldRegistry[uuid] ~= nil then
                    if started == nil then
                        NMServerRegistryState.dormancySinceMinutes[uuid] = nowMin
                    elseif NMRegistryPolicy.shouldKillDormant(started, nowMin) then
                        NMRegistryPolicy.markTombstone(state, profile)
                        NMServerRegistryState.dormancyTombstones[uuid] = nowMin
                        NMServerRegistryState.worldRegistry[uuid] = nil
                        NMServerRegistryState.dormancySinceMinutes[uuid] = nil
                        broadcastSnapshot(entry, "remove")
                    end
                end
            end

            if NMServerRegistryState.worldRegistry[uuid] ~= nil then
                active[uuid] = true
                broadcastUpsertIfChanged(NMServerRegistryState.worldRegistry, uuid, entry, tickNow)
            end
        end
    end

    NMServerRegistryBroadcast.cleanupSignatureCache(active)
end

