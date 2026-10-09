-- Server minute tick for vehicle battery drain and forced-off behavior.
NMServerVehiclePowerTick = NMServerVehiclePowerTick or {}
NMServerVehiclePowerTick.lastDrainMs = NMServerVehiclePowerTick.lastDrainMs or {}

local function markAuthoritativeMutation(state)
    if not state then
        return
    end
    NMDeviceState.bumpRevision(state)
    state.sourceGeneration = (tonumber(state.sourceGeneration) or 0) + 1
end

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

local function drainVehicleBattery(vehicle, drainSeconds, deltaSeconds)
    if not vehicle then return 0.0 end
    local batteryPart = vehicle.getBattery and vehicle:getBattery() or nil
    local batteryItem = batteryPart and batteryPart.getInventoryItem and batteryPart:getInventoryItem() or nil
    if not batteryItem then return 0.0 end

    local current = NMCore.readDrainableFraction(batteryItem, 0.0)
    local nextValue = NMServerBatteryAuthority.computeNextCharge(current, deltaSeconds, drainSeconds)
    if nextValue ~= current then
        if batteryItem.setUsedDelta then
            batteryItem:setUsedDelta(nextValue)
        end
        if vehicle.transmitPartUsedDelta and batteryPart then
            vehicle:transmitPartUsedDelta(batteryPart)
        end
    end
    return nextValue
end

local function forceVehicleStateOff(vehicle, part, state, reason)
    if not vehicle or not part or not state then return false end
    local changed = NMServerBatteryAuthority.forceStateOff(state, reason or "vehicle_battery_empty")
    if not changed then return false end
    markAuthoritativeMutation(state)

    if vehicle.transmitPartModData then
        vehicle:transmitPartModData(part)
        vehicle:updateParts()
    end
    return true
end

function NMServerVehiclePowerTick.onEveryOneMinute()
    local cell = getCell and getCell() or nil
    local vehicles = cell and cell.getVehicles and cell:getVehicles() or nil
    if not vehicles then return end

    local count = 0
    if vehicles.size then
        count = tonumber(vehicles:size()) or 0
    elseif type(vehicles) == "table" then
        count = #vehicles
    else
        return
    end

    for i = 0, count - 1 do
        local vehicle = nil
        if vehicles.get then
            vehicle = vehicles:get(i)
        elseif type(vehicles) == "table" then
            vehicle = vehicles[i + 1] or vehicles[i]
        end
        if vehicle then
            local part = vehicle.getPartById and vehicle:getPartById("Radio") or nil
            local profile = part and NMDeviceProfiles.getVehicleProfile(part) or nil
            local state = part and profile and NMDeviceState.peek and NMDeviceState.peek(part) or nil
            if profile and state and profile.vehicleUsesCarBattery then
                local uuid = tostring(state.deviceUUID or "")
                local nowMsValue = nowRealMs()
                if not NMVehicleHelpers.vehicleHasPower(vehicle, part) then
                    if forceVehicleStateOff(vehicle, part, state, "vehicle_battery_empty") then
                        local token = string.format("%s:%s", tostring(tonumber(state.playbackEpoch) or -1), tostring(tonumber(state.trackIndex) or -1))
                        NMServerBatteryAuthority.logEmptyStop("vehicle", uuid, "vehicle_battery_empty", token)
                    end
                    NMServerVehiclePowerTick.lastDrainMs[uuid] = nowMsValue
                elseif state.isOn and (vehicle.isEngineRunning and (not vehicle:isEngineRunning())) then
                    if not (NMRuntimeConfig.getVehicleCustomDrainEnabled and NMRuntimeConfig.getVehicleCustomDrainEnabled()) then
                        NMServerVehiclePowerTick.lastDrainMs[uuid] = nowMsValue
                    else
                    local prevMs = tonumber(NMServerVehiclePowerTick.lastDrainMs[uuid])
                    if not prevMs then
                        NMServerVehiclePowerTick.lastDrainMs[uuid] = nowMsValue
                    else
                        local deltaSeconds = math.max(0, (nowMsValue - prevMs) / 1000.0)
                        NMServerVehiclePowerTick.lastDrainMs[uuid] = nowMsValue
                        local drainSeconds = tonumber(NMRuntimeConfig.getBatteryDrainSecondsVehicleEngineOff and NMRuntimeConfig.getBatteryDrainSecondsVehicleEngineOff() or 300) or 300
                        local batteryPart = vehicle.getBattery and vehicle:getBattery() or nil
                        local batteryItem = batteryPart and batteryPart.getInventoryItem and batteryPart:getInventoryItem() or nil
                        local currentCharge = NMCore.readDrainableFraction(batteryItem, 0.0)
                        local nextCharge = drainVehicleBattery(vehicle, drainSeconds, deltaSeconds)
                        NMServerBatteryAuthority.logBatteryTick("vehicle", uuid, nowMsValue, prevMs, currentCharge, nextCharge, drainSeconds, "engineOn=false")
                        if nextCharge <= 0 then
                            if forceVehicleStateOff(vehicle, part, state, "vehicle_battery_empty") then
                                local token = string.format("%s:%s", tostring(tonumber(state.playbackEpoch) or -1), tostring(tonumber(state.trackIndex) or -1))
                                NMServerBatteryAuthority.logEmptyStop("vehicle", uuid, "vehicle_battery_empty", token)
                            end
                        end
                    end
                    end
                else
                    NMServerVehiclePowerTick.lastDrainMs[uuid] = nowMsValue
                end

                local entry = NMServerRegistryState.worldRegistry[uuid]
                if entry then
                    entry.x = tonumber(vehicle:getX()) or entry.x
                    entry.y = tonumber(vehicle:getY()) or entry.y
                    entry.z = tonumber(vehicle:getZ()) or entry.z
                    entry.windowsOpen = NMVehicleHelpers.vehicleWindowsOpen(vehicle)
                    entry.stateSnapshot = NMDeviceState.export(state)
                    NMServerRegistryState.worldRegistry[uuid] = entry
                end
            end
        end
    end
end

