-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
ComputerModRelayRepair = ComputerModRelayRepair or {}

ComputerModRelayRepair.requiredElectricalLevel = 2
ComputerModRelayRepair.parts = {
    {key = "wire", fullType = "Base.ElectricWire", count = 4},
    {key = "electronics", fullType = "Base.ElectronicsScrap", count = 6},
    {key = "receiver", fullType = "Base.RadioReceiver", count = 1},
    {key = "transmitter", fullType = "Base.RadioTransmitter", count = 1},
    {key = "amplifier", fullType = "Base.Amplifier", count = 1},
    {key = "battery", fullType = "Base.Battery", count = 2},
    {key = "duct_tape", fullType = "Base.DuctTape", count = 1}
}

function ComputerModRelayRepair.getPart(key)
    for i = 1, #ComputerModRelayRepair.parts do
        local part = ComputerModRelayRepair.parts[i]
        if part.key == key then return part end
    end
    return nil
end

function ComputerModRelayRepair.normalizeProgress(progress)
    local result = {}
    for i = 1, #ComputerModRelayRepair.parts do
        local part = ComputerModRelayRepair.parts[i]
        local count = type(progress) == "table" and tonumber(progress[part.key] or 0) or 0
        count = math.max(0, math.min(part.count, math.floor(count or 0)))
        result[part.key] = count
    end
    return result
end

function ComputerModRelayRepair.copyProgress(progress)
    local normalized = ComputerModRelayRepair.normalizeProgress(progress)
    local result = {}
    for key, count in pairs(normalized) do
        result[key] = count
    end
    return result
end

function ComputerModRelayRepair.isComplete(progress)
    local normalized = ComputerModRelayRepair.normalizeProgress(progress)
    for i = 1, #ComputerModRelayRepair.parts do
        local part = ComputerModRelayRepair.parts[i]
        if normalized[part.key] < part.count then return false end
    end
    return true
end

function ComputerModRelayRepair.isWorldGridPowerAvailable()
    if not getGameTime then return nil end
    local okTime, gameTime = pcall(getGameTime)
    if not okTime or not gameTime or not gameTime.getWorldAgeHours then return nil end
    local okAge, age = pcall(function() return gameTime:getWorldAgeHours() end)
    if not okAge or not age then return nil end
    local days = tonumber(age)
    if not days then return nil end
    days = days / 24
    if getSandboxOptions then
        local okOptions, options = pcall(getSandboxOptions)
        if okOptions and options and options.getTimeSinceApo then
            local okSince, since = pcall(function() return options:getTimeSinceApo() end)
            if okSince and tonumber(since) then
                days = days + (tonumber(since) - 1) * 30
            end
        end
    end
    local shutModifier = nil
    if getSandboxOptions then
        local okOptions, options = pcall(getSandboxOptions)
        if okOptions and options and options.getElecShutModifier then
            local okValue, value = pcall(function() return options:getElecShutModifier() end)
            if okValue and tonumber(value) then shutModifier = tonumber(value) end
        end
    end
    if shutModifier == nil and SandboxVars and tonumber(SandboxVars.ElecShutModifier) then
        shutModifier = tonumber(SandboxVars.ElecShutModifier)
    end
    if shutModifier == nil then return nil end
    if shutModifier < 0 then return false end
    return days < shutModifier
end
