-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Shared zombie attraction policy and pulse scheduling with occlusion shaping.
NMZombieAttraction = NMZombieAttraction or {}

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local initialEmitBaselineMs = -1000000000

local function normalizePulseMemory(state)
    if type(state) ~= "table" then
        return nil
    end
    return state
end

local function normalizeWindowsOpen(windowsOpen)
    if windowsOpen == nil then
        return nil
    end
    return windowsOpen == true
end

local function shouldAttract(profile, state, sourceContext)
    if not profile or not state then
        return false
    end
    if state.isPlaying ~= true or state.desiredIsPlaying ~= true then
        return false
    end
    if state.isMuted == true then
        return false
    end
    if (tonumber(state.volume) or 0) <= 0 then
        return false
    end

    local deviceType = tostring(profile.deviceType or "")
    if deviceType == "walkman" or deviceType == "cdplayer" then
        return false
    end
    if deviceType == "vehicle_radio" and tostring(sourceContext or "") == "vehicle" then
        return true
    end

    local outputMode = NMDeviceProfiles.resolveOutputMode(profile, state, sourceContext, false)
    return outputMode == "world"
end
NMZombieAttraction.shouldAttract = shouldAttract

local function buildPulseContract(profile, state, sourceContext, windowsOpen)
    if not profile or not state then
        return nil
    end
    if not shouldAttract(profile, state, sourceContext) then
        return nil
    end
    local volume01 = NMCore.clamp(tonumber(state.volume) or 0.0, 0.0, 1.0)
    if volume01 <= 0.0 then
        return nil
    end

    local range = NMDeviceProfiles.computeZombieRange(profile, volume01)
    local loudness = mathFloor((volume01 * 100) + 0.5)

    if tostring(sourceContext or "") == "vehicle"
        and profile.vehicleWindowOcclusion
        and windowsOpen ~= true then
        local expMult = NMOcclusionMath.resolveClosedZombieExponentMultiplier(profile)
        range = NMDeviceProfiles.computeZombieRange(profile, volume01, expMult)
        local mult = NMOcclusionMath.resolveClosedZombieRangeMultiplier(profile)
        range = range * mult
        loudness = mathFloor((loudness * mult) + 0.5)
    end

    if range <= 0 or loudness <= 0 then
        return nil
    end

    local pulseMs = NMDeviceProfiles.getZombiePulseIntervalMs(profile)
    if pulseMs < 100 then
        pulseMs = 100
    end
    local gateBaseRange = NMDeviceProfiles.getZombiePlayerGateRange(profile)

    return {
        range = range,
        emitRange = mathFloor(range),
        loudness = loudness,
        intervalMs = pulseMs,
        gateBaseRange = gateBaseRange
    }
end
NMZombieAttraction.computePulseContract = buildPulseContract

local function computeGateRange(pulseContract, gateMultiplier)
    if not pulseContract then
        return 0
    end
    local mult = tonumber(gateMultiplier) or 1.5
    if mult < 0.1 then
        mult = 0.1
    end
    local gateRange = mathMax(tonumber(pulseContract.range) or 0, tonumber(pulseContract.gateBaseRange) or 0)
    return gateRange * mult
end
local function shouldEmitForNearestPlayer(nearestDistanceSq, gateRange)
    if nearestDistanceSq == nil then
        return false
    end
    local g = tonumber(gateRange) or 0
    if g <= 0 then
        return false
    end
    return nearestDistanceSq <= (g * g)
end

local function buildSourceSnapshot(sourceLike)
    local source = type(sourceLike) == "table" and sourceLike or {}
    if source._nmZombieAttractionSnapshot == true then
        return source
    end
    return {
        _nmZombieAttractionSnapshot = true,
        x = tonumber(source.x) or 0,
        y = tonumber(source.y) or 0,
        z = tonumber(source.z) or 0,
        windowsOpen = normalizeWindowsOpen(source.windowsOpen)
    }
end
NMZombieAttraction.buildSourceSnapshot = buildSourceSnapshot

function NMZombieAttraction.shouldEmitForNearestPlayerGate(nearestDistanceSq, pulseContract, gateMultiplier)
    local gateRange = computeGateRange(pulseContract, gateMultiplier)
    return shouldEmitForNearestPlayer(nearestDistanceSq, gateRange), gateRange
end

function NMZombieAttraction.shouldEmitPulse(nowMs, lastEmitState, pulseContract, sourceSnapshot, options)
    local pulseMemory = normalizePulseMemory(lastEmitState) or {}
    local currentSource = buildSourceSnapshot(sourceSnapshot)
    local pulse = type(pulseContract) == "table" and pulseContract or {}
    local settings = type(options) == "table" and options or {}

    local elapsed = tonumber(nowMs) or 0
    elapsed = elapsed - (tonumber(pulseMemory.lastEmitMs) or initialEmitBaselineMs)
    local intervalMs = mathMax(100, tonumber(pulse.intervalMs) or 1000)
    if elapsed >= intervalMs then
        return true, "repulse_interval"
    end

    local allowWindowStateRepulse = settings.allowWindowStateRepulse ~= false
    local windowStateRepulseMs = mathMax(0, tonumber(settings.windowStateRepulseMs) or 500)
    local previousWindowsOpen = normalizeWindowsOpen(pulseMemory.windowsOpen)
    local currentWindowsOpen = currentSource.windowsOpen
    if allowWindowStateRepulse
        and previousWindowsOpen ~= nil
        and currentWindowsOpen ~= nil
        and previousWindowsOpen ~= currentWindowsOpen
        and elapsed >= windowStateRepulseMs then
        return true, "window_state_repulse"
    end

    local movementRepulseMs = mathMax(0, tonumber(settings.movementRepulseMs) or 2500)
    if elapsed < movementRepulseMs then
        return false, "movement_repulse_blocked"
    end

    local lastPos = type(pulseMemory.position) == "table" and pulseMemory.position or nil
    if not lastPos then
        return false, "movement_repulse_blocked"
    end

    local dx = (tonumber(currentSource.x) or 0) - (tonumber(lastPos.x) or 0)
    local dy = (tonumber(currentSource.y) or 0) - (tonumber(lastPos.y) or 0)
    local moveDistanceSq = tonumber(settings.movementDistanceSq) or 4.0
    if ((dx * dx) + (dy * dy)) >= moveDistanceSq then
        return true, "movement_repulse"
    end
    return false, "movement_repulse_blocked"
end

function NMZombieAttraction.resolveEmitDecision(nowMs, lastEmitState, pulseContract, sourceSnapshot, nearestDistanceSq, gateMultiplier, options)
    local emitForNearestPlayer, gateRange = NMZombieAttraction.shouldEmitForNearestPlayerGate(nearestDistanceSq, pulseContract, gateMultiplier)
    if not emitForNearestPlayer then
        return false, "nearest_player_gate_blocked", gateRange
    end
    local emitPulse, emitDecision = NMZombieAttraction.shouldEmitPulse(nowMs, lastEmitState, pulseContract, sourceSnapshot, options)
    return emitPulse, emitDecision, gateRange
end

function NMZombieAttraction.capturePulseEmitState(nowMs, sourceSnapshot)
    local source = buildSourceSnapshot(sourceSnapshot)
    return {
        lastEmitMs = tonumber(nowMs) or 0,
        position = {
            x = source.x,
            y = source.y,
            z = source.z
        },
        windowsOpen = source.windowsOpen
    }
end



