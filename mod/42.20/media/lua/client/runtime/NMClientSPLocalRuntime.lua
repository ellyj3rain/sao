-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMClientSPLocalRuntime = NMClientSPLocalRuntime or {}

local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max

local function nearestPlayerDistanceSq(player, x, y, z, floorsLimit)
    if not player or not player.getSquare then
        return nil
    end
    local sq = player:getSquare()
    if not sq then
        return nil
    end
    local sourceZ = tonumber(z) or 0
    local dz = mathAbs((sq:getZ() or 0) - sourceZ)
    if dz > mathMax(0, tonumber(floorsLimit) or 0) then
        return nil
    end
    local sourceX = tonumber(x) or 0
    local sourceY = tonumber(y) or 0
    local dx = (sq:getX() or 0) - sourceX
    local dy = (sq:getY() or 0) - sourceY
    return (dx * dx) + (dy * dy)
end

local function notePulseDiag(state, name, delta)
    local token = tostring(name or "")
    if token == "" then
        return
    end
    local amount = tonumber(delta) or 1
    if state and state.countMemoryEvent then
        state.countMemoryEvent(token, amount)
    end
    if state and state.noteDiagCounter then
        state.noteDiagCounter(token, amount)
    end
end

function NMClientSPLocalRuntime.emitZombiePulses(player, pulseCandidates, state)
    local core = NMCore
    if not player or not pulseCandidates or core.isMultiplayerMode() or not addSound then
        return
    end
    local nowMs = state and state.nowMs and state.nowMs() or 0
    local pulseState = state and state.zombieAttractionPulseState or {}
    local gateMultiplier = NMRuntimeConfig and NMRuntimeConfig.getServerZombiePlayerGateMultiplier and NMRuntimeConfig.getServerZombiePlayerGateMultiplier() or 1.5
    local buildSourceSnapshot = NMZombieAttraction.buildSourceSnapshot
    local computePulseContract = NMZombieAttraction.computePulseContract
    local resolveEmitDecision = NMZombieAttraction.resolveEmitDecision
    local capturePulseEmitState = NMZombieAttraction.capturePulseEmitState
    local getWorldTrackingFloors = NMDeviceProfiles.getWorldTrackingFloors
    local debugEnabled = core.isSubsystemDebugEnabled and core.isSubsystemDebugEnabled("zombie_attraction")
    local memoryDiagPrefix = state and state.memoryDiagPrefix and tostring(state.memoryDiagPrefix or "") or ""
    local pulseDecisionOptionsByWindowSupport = {
        [true] = { allowWindowStateRepulse = true },
        [false] = { allowWindowStateRepulse = false }
    }

    for uuid, candidate in pairs(pulseCandidates) do
        local profile = candidate and candidate.profile or nil
        local runtimeState = candidate and candidate.state or nil
        local source = candidate and candidate.source or nil
        if profile and runtimeState and source and source.x and source.y and source.z then
            local sourceContext = tostring(source.context or source.mode or "placed")
            local sourceSnapshot = buildSourceSnapshot(source)
            local pulseContract = computePulseContract(profile, runtimeState, sourceContext, sourceSnapshot.windowsOpen)
            if pulseContract then
                if memoryDiagPrefix ~= "" then
                    notePulseDiag(state, memoryDiagPrefix .. "_contract", 1)
                end
                local key = type(uuid) == "string" and uuid or tostring(uuid or "")
                local floors = getWorldTrackingFloors(profile)
                local nearestD2 = nearestPlayerDistanceSq(player, sourceSnapshot.x, sourceSnapshot.y, sourceSnapshot.z, floors)
                local emitPulse, emitReason, gateRange = resolveEmitDecision(
                    nowMs,
                    pulseState[key],
                    pulseContract,
                    sourceSnapshot,
                    nearestD2,
                    gateMultiplier,
                    pulseDecisionOptionsByWindowSupport[sourceSnapshot.windowsOpen ~= nil]
                )
                if emitPulse then
                    if memoryDiagPrefix ~= "" then
                        notePulseDiag(state, memoryDiagPrefix .. "_emit", 1)
                        notePulseDiag(state, memoryDiagPrefix .. "_emit_" .. tostring(emitReason or "unknown"), 1)
                    end
                    pulseState[key] = capturePulseEmitState(nowMs, sourceSnapshot)
                    addSound(nil, sourceSnapshot.x, sourceSnapshot.y, sourceSnapshot.z, pulseContract.emitRange or mathFloor(pulseContract.range), pulseContract.loudness)
                    if debugEnabled then
                        core.logChannel(
                            "zombie_attraction",
                            "sp_local_pulse_emit",
                            string.format(
                                "uuid=%s ctx=%s emitDecision=%s x=%.2f y=%.2f z=%.2f range=%d loudness=%d gateRange=%d windowsOpen=%s",
                                key, sourceContext, tostring(emitReason or "unknown"), sourceSnapshot.x, sourceSnapshot.y, sourceSnapshot.z,
                                pulseContract.emitRange or mathFloor(pulseContract.range), pulseContract.loudness or mathFloor(tonumber(pulseContract.loudness) or 0), mathFloor(tonumber(gateRange) or 0), tostring(sourceSnapshot.windowsOpen == true)
                            )
                        )
                    end
                elseif memoryDiagPrefix ~= "" then
                    notePulseDiag(state, memoryDiagPrefix .. "_blocked", 1)
                    notePulseDiag(state, memoryDiagPrefix .. "_blocked_" .. tostring(emitReason or "unknown"), 1)
                end
            elseif memoryDiagPrefix ~= "" then
                notePulseDiag(state, memoryDiagPrefix .. "_no_contract", 1)
            end
        end
    end
end

function NMClientSPLocalRuntime.applyVehiclePowerGuard(profile, runtimeState, source, uuid, state)
    if NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() then
        return
    end
    if not profile or not runtimeState or profile.vehicleUsesCarBattery ~= true or not source then
        return
    end

    local vehicle = source.vehicle
    if (not vehicle) then
        local vehicleId = tostring(source.vehicleId or "")
        if vehicleId ~= "" and getVehicleById then
            vehicle = getVehicleById(tonumber(vehicleId))
        end
    end
    if not vehicle then
        return
    end
    local part = vehicle.getPartById and vehicle:getPartById("Radio") or nil
    if not part then
        return
    end

    local key = tostring(uuid or runtimeState.deviceUUID or "")
    local nowMsValue = state and state.nowMs and state.nowMs() or 0
    local vehiclePowerTickMs = state and state.vehiclePowerTickMs or {}

    if runtimeState.isOn ~= true then
        if key ~= "" then
            vehiclePowerTickMs[key] = nowMsValue
        end
        return
    end

    if not NMVehicleHelpers.vehicleHasPower(vehicle, part) then
        runtimeState.isOn = false
        runtimeState.desiredIsOn = false
        runtimeState.isPlaying = false
        runtimeState.desiredIsPlaying = false
        runtimeState.lastStopReason = "vehicle_battery_empty"
        NMDeviceState.bumpPlaybackEpoch(runtimeState)
        NMDeviceState.bumpRevision(runtimeState)
        local keep = NMRegistryPolicy.shouldKeepWorldSourceState(runtimeState)
        local vehicleRuntimeId = vehicle and NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and NMVehicleHelpers.getVehicleIdString(vehicle)
            or vehicle and tostring(vehicle:getId()) or tostring(source and source.vehicleId or "")
        local vehicleSqlId = vehicle and NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle)
            or tostring(source and (source.vehicleSqlId or source.vehicleSqlIdHint) or "")
        if keep and key ~= "" then
            NMWorldRegistrySnapshot.upsertSP({
                kind = "vehicle", uuid = key, profileType = "vehicle_radio", sourceMode = "vehicle",
                sourceEpoch = tonumber(runtimeState.sourceGeneration) or 0,
                x = source and tonumber(source.x) or tonumber(vehicle:getX()) or 0,
                y = source and tonumber(source.y) or tonumber(vehicle:getY()) or 0,
                z = source and tonumber(source.z) or tonumber(vehicle:getZ()) or 0,
                vehicleId = vehicleRuntimeId,
                vehicleIdHint = vehicleRuntimeId,
                vehicleSqlId = vehicleSqlId,
                vehicleSqlIdHint = vehicleSqlId,
                partId = part and tostring(part:getId()) or "Radio",
                windowsOpen = NMVehicleHelpers.vehicleWindowsOpen(vehicle),
                state = NMDeviceState.export(runtimeState),
                revision = tonumber(runtimeState.revision) or 0,
                playbackEpoch = tonumber(runtimeState.playbackEpoch) or 0
            })
        elseif key ~= "" then
            NMWorldRegistrySnapshot.removeSP(key)
        end
        return
    end

    if (vehicle.isEngineRunning and vehicle:isEngineRunning()) then
        if key ~= "" then
            vehiclePowerTickMs[key] = nowMsValue
        end
        return
    end
    if not (NMRuntimeConfig.getVehicleCustomDrainEnabled and NMRuntimeConfig.getVehicleCustomDrainEnabled()) then
        vehiclePowerTickMs[key] = nowMsValue
        return
    end
    if key == "" then
        return
    end
    local prev = tonumber(vehiclePowerTickMs[key])
    if prev == nil then
        vehiclePowerTickMs[key] = nowMsValue
        return
    end
    local deltaSeconds = mathMax(0, (nowMsValue - prev) / 1000.0)
    vehiclePowerTickMs[key] = nowMsValue
    if deltaSeconds <= 0 then
        return
    end

    local drainSeconds = tonumber(NMRuntimeConfig.getBatteryDrainSecondsVehicleEngineOff and NMRuntimeConfig.getBatteryDrainSecondsVehicleEngineOff() or 300) or 300
    if drainSeconds <= 0 then
        return
    end
    local batteryPart = vehicle.getBattery and vehicle:getBattery() or nil
    local batteryItem = batteryPart and batteryPart.getInventoryItem and batteryPart:getInventoryItem() or nil
    if not batteryItem then
        return
    end
    local current = NMCore.readDrainableFraction(batteryItem, 0.0)
    local nextValue = NMCore.clamp(current - (deltaSeconds / drainSeconds), 0.0, 1.0)
    if nextValue ~= current and batteryItem.setUsedDelta then
        batteryItem:setUsedDelta(nextValue)
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
        local logKey = "runtimeProbe.batteryDrain.vehicle.sp." .. tostring(key)
        if NMCore.shouldLogEvery(logKey, nowMsValue, 5000) then
            NMCore.logChannel(
                "runtime",
                "battery_drain_tick",
                string.format(
                    "uuid=%s type=vehicle engineOn=false deltaMs=%d old=%.3f new=%.3f targetSeconds=%.0f",
                    tostring(key), mathFloor(mathMax(0, nowMsValue - prev)), current, nextValue, drainSeconds
                )
            )
        end
    end
    if nextValue <= 0 then
        runtimeState.isOn = false
        runtimeState.desiredIsOn = false
        runtimeState.isPlaying = false
        runtimeState.desiredIsPlaying = false
        runtimeState.lastStopReason = "vehicle_battery_empty"
        NMDeviceState.bumpPlaybackEpoch(runtimeState)
        NMDeviceState.bumpRevision(runtimeState)
    end
end

return NMClientSPLocalRuntime

