-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Server authoritative zombie pulse emission from world registry sources.
NMServerZombiePulseTick = NMServerZombiePulseTick or {}

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function nearestPlayerDistanceSq(x, y, z, floorsLimit)
    local sourceX = tonumber(x) or 0
    local sourceY = tonumber(y) or 0
    local sourceZ = tonumber(z) or 0
    local maxFloors = mathMax(0, tonumber(floorsLimit) or 0)
    local best = nil
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        local sq = p and p.getSquare and p:getSquare() or nil
        if sq then
            local dz = mathAbs((sq:getZ() or 0) - sourceZ)
            if dz <= maxFloors then
                local dx = (sq:getX() or 0) - sourceX
                local dy = (sq:getY() or 0) - sourceY
                local d2 = (dx * dx) + (dy * dy)
                if best == nil or d2 < best then best = d2 end
            end
        end
    end
    return best
end

function NMServerZombiePulseTick.hasActiveWork()
    local worldRegistry = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(worldRegistry) ~= "table" then
        return false
    end
    for _ in pairs(worldRegistry) do
        return true
    end
    return false
end

function NMServerZombiePulseTick.onTick()
    local core = NMCore
    if not core.isMPServerAuthority() or not addSound then
        return
    end

    local nowMs = nowRealMs()
    local gateMultiplier = NMRuntimeConfig and NMRuntimeConfig.getServerZombiePlayerGateMultiplier and NMRuntimeConfig.getServerZombiePlayerGateMultiplier() or 1.5
    local pulseState = NMServerRegistryState.zombieAttractionPulseState
    local worldRegistry = NMServerRegistryState.worldRegistry
    local computePulseContract = NMZombieAttraction.computePulseContract
    local buildSourceSnapshot = NMZombieAttraction.buildSourceSnapshot
    local resolveEmitDecision = NMZombieAttraction.resolveEmitDecision
    local capturePulseEmitState = NMZombieAttraction.capturePulseEmitState
    local getProfile = NMDeviceProfiles.getForFullType
    local getWorldTrackingFloors = NMDeviceProfiles.getWorldTrackingFloors
    local pulseDecisionOptions = { allowWindowStateRepulse = true }
    local debugEnabled = core and core.logChannel and core.isSubsystemDebugEnabled and core.isSubsystemDebugEnabled("zombie_attraction")
    local shouldLogEvery = debugEnabled and core.shouldLogEvery or nil

    for uuid, entry in pairs(worldRegistry) do
        local state = entry and entry.stateSnapshot or nil
        local profile = entry and entry.profileType and getProfile(entry.profileType) or nil
        if state and profile then
            local sourceSnapshot = buildSourceSnapshot(entry)
            local pulseContract = computePulseContract(profile, state, entry.sourceMode, sourceSnapshot.windowsOpen)
            if pulseContract then
                local key = type(uuid) == "string" and uuid or tostring(uuid or "")
                local floors = getWorldTrackingFloors(profile)
                local nearestD2 = nearestPlayerDistanceSq(sourceSnapshot.x, sourceSnapshot.y, sourceSnapshot.z, floors)
                local emitPulse, emitReason, gateRange = resolveEmitDecision(
                    nowMs,
                    pulseState[key],
                    pulseContract,
                    sourceSnapshot,
                    nearestD2,
                    gateMultiplier,
                    pulseDecisionOptions
                )
                if emitPulse then
                    pulseState[key] = capturePulseEmitState(nowMs, sourceSnapshot)
                    addSound(nil, sourceSnapshot.x, sourceSnapshot.y, sourceSnapshot.z, pulseContract.emitRange or mathFloor(pulseContract.range), pulseContract.loudness)
                    if debugEnabled then
                        local shouldLog = true
                        if shouldLogEvery then
                            shouldLog = shouldLogEvery("zombie_attraction.server_emit." .. key, nowMs, 15000)
                        end
                        if shouldLog then
                            core.logChannel(
                                "zombie_attraction",
                                "authoritative_pulse_emit",
                                string.format(
                                    "uuid=%s mode=%s emitDecision=%s x=%.2f y=%.2f z=%.2f range=%d loudness=%d gateRange=%d windowsOpen=%s",
                                    key,
                                    tostring(entry.sourceMode or "placed"),
                                    tostring(emitReason or "unknown"),
                                    sourceSnapshot.x,
                                    sourceSnapshot.y,
                                    sourceSnapshot.z,
                                    pulseContract.emitRange or mathFloor(tonumber(pulseContract.range) or 0),
                                    pulseContract.loudness or mathFloor(tonumber(pulseContract.loudness) or 0),
                                    mathFloor(tonumber(gateRange) or 0),
                                    tostring(sourceSnapshot.windowsOpen == true)
                                )
                            )
                        end
                    end
                end
            end
        end
    end
end

