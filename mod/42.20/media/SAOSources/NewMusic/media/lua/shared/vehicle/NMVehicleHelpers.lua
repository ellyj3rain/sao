-- Shared vehicle radio, window, and power helper utilities.
NMVehicleHelpers = NMVehicleHelpers or {}

NMVehicleHelpers.windowPartIds = {
    "WindowFrontLeft",
    "WindowFrontRight",
    "WindowMiddleLeft",
    "WindowMiddleRight",
    "WindowRearLeft",
    "WindowRearRight",
    "Windshield",
    "WindshieldRear"
}

function NMVehicleHelpers.resolveVehicleRadioPart(vehicle)
    if not vehicle then return nil end
    local part = vehicle:getPartById("Radio")
    if not part then return nil end
    if not (NMDeviceProfiles and NMDeviceProfiles.getVehicleProfile) then
        return part, nil
    end
    local profile = NMDeviceProfiles.getVehicleProfile(part)
    if not profile then return nil end
    return part, profile
end

function NMVehicleHelpers.vehicleWindowsOpen(vehicle)
    if not vehicle then return true end
    if vehicle.windowsOpen then
        local count = tonumber(vehicle:windowsOpen()) or 0
        if count > 0 then return true end
    end
    for i = 1, #NMVehicleHelpers.windowPartIds do
        local part = vehicle:getPartById(NMVehicleHelpers.windowPartIds[i])
        if part and (not part:getInventoryItem() or (part:getWindow() and part:getWindow():isOpen())) then
            return true
        end
    end
    return false
end

function NMVehicleHelpers.getVehicleBatteryCharge(vehicle)
    if not vehicle then return 0.0 end
    local charge = tonumber(vehicle.getBatteryCharge and vehicle:getBatteryCharge() or 0.0) or 0.0
    return NMCore.clamp(charge, 0.0, 1.0)
end

function NMVehicleHelpers.vehicleHasPower(vehicle, part)
    if not vehicle or not part then return false end
    if not part.getInventoryItem or not part:getInventoryItem() then
        return false
    end
    return NMVehicleHelpers.getVehicleBatteryCharge(vehicle) > 0.0
end

function NMVehicleHelpers.vehicleHasUsableBatteryPower(vehicle, part)
    return NMVehicleHelpers.vehicleHasPower(vehicle, part)
end

function NMVehicleHelpers.getVehicleIdString(vehicle)
    if not vehicle then return "" end
    if not vehicle.getId then return "" end
    local ok, value = pcall(function()
        return vehicle:getId()
    end)
    if not ok then
        return ""
    end
    return tostring(value or "")
end

function NMVehicleHelpers.getVehicleSqlIdString(vehicle)
    if not vehicle then return "" end
    if not vehicle.getSqlId then return "" end
    local ok, value = pcall(function()
        return vehicle:getSqlId()
    end)
    if not ok then
        return ""
    end
    return tostring(value or "")
end

function NMVehicleHelpers.getVehicleScriptName(vehicle)
    if not vehicle then return "" end
    if vehicle.getScriptName then
        local okName, scriptName = pcall(function()
            return vehicle:getScriptName()
        end)
        if okName and scriptName ~= nil then
            return tostring(scriptName or "")
        end
    end
    if vehicle.getScript then
        local okScript, script = pcall(function()
            return vehicle:getScript()
        end)
        if okScript and script and script.getName then
            local okScriptName, name = pcall(function()
                return script:getName()
            end)
            if okScriptName and name ~= nil then
                return tostring(name or "")
            end
        end
    end
    return ""
end

