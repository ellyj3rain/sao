-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_ComputerTypes"

ComputerModPower = ComputerModPower or {}
ComputerModPower.cache = ComputerModPower.cache or setmetatable({}, {__mode = "k"})
ComputerModPower.cacheDurationMs = 1500

local function nowMs()
    if getTimestampMs then
        local ok, value = pcall(getTimestampMs)
        if ok and value then return tonumber(value) or 0 end
    end
    return 0
end

local function getGeneratorTileRange()
    local value = SandboxVars and tonumber(SandboxVars.GeneratorTileRange) or nil
    return value or 20
end

local function getGeneratorVerticalRange()
    local value = SandboxVars and tonumber(SandboxVars.GeneratorVerticalPowerRange) or nil
    return value or 3
end

local function isGeneratorObject(object)
    if not object then return false end
    if instanceof and instanceof(object, "IsoGenerator") then return true end
    return object.getFuel and object.isActivated and object.getCondition and object.getSquare
end

local function generatorIsActive(generator)
    if not generator then return false end
    local square = generator.getSquare and generator:getSquare() or nil
    if square and IsoGenerator and IsoGenerator.updateGenerator then
        pcall(function() IsoGenerator.updateGenerator(square) end)
    end
    local okActive, active = pcall(function() return generator:isActivated() end)
    if not okActive or active ~= true then return false end
    local okFuel, fuel = pcall(function() return generator:getFuel() end)
    if not okFuel or tonumber(fuel or 0) <= 0 then return false end
    local okCondition, condition = pcall(function() return generator:getCondition() end)
    if okCondition and tonumber(condition or 0) <= 0 then return false end
    return true
end

local function generatorCanReach(generator, targetSquare)
    if not generator or not targetSquare then return false end
    local square = generator.getSquare and generator:getSquare() or nil
    if not square then return false end
    local range = getGeneratorTileRange()
    local vertical = getGeneratorVerticalRange()
    if math.abs(square:getX() - targetSquare:getX()) > range or math.abs(square:getY() - targetSquare:getY()) > range then return false end
    if math.abs(square:getZ() - targetSquare:getZ()) > vertical then return false end
    return true
end

local function findPoweredGeneratorNear(square)
    if not square or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local range = getGeneratorTileRange()
    local vertical = getGeneratorVerticalRange()
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    for dz = -vertical, vertical do
        for dx = -range, range do
            for dy = -range, range do
                local check = cell:getGridSquare(x + dx, y + dy, z + dz)
                if check then
                    local objects = check.getObjects and check:getObjects() or nil
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local object = objects:get(i)
                            if isGeneratorObject(object) and generatorCanReach(object, square) and generatorIsActive(object) then
                                return object
                            end
                        end
                    end
                    local specialObjects = check.getSpecialObjects and check:getSpecialObjects() or nil
                    if specialObjects then
                        for i = 0, specialObjects:size() - 1 do
                            local object = specialObjects:get(i)
                            if isGeneratorObject(object) and generatorCanReach(object, square) and generatorIsActive(object) then
                                return object
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function saveResult(computer, entry, square, result, generator, checkedAt)
    entry.x = square:getX()
    entry.y = square:getY()
    entry.z = square:getZ()
    entry.result = result == true
    entry.generator = generator
    entry.checkedAt = checkedAt
    ComputerModPower.cache[computer] = entry
    return entry.result
end

function ComputerModPower.invalidate(computer)
    if computer then
        ComputerModPower.cache[computer] = nil
    else
        ComputerModPower.cache = setmetatable({}, {__mode = "k"})
    end
end

function ComputerModPower.hasGridPower(computer)
    if not computer or not computer.getSquare then return false end
    local square = computer:getSquare()
    if not square then return false end
    local checkedAt = nowMs()
    local entry = ComputerModPower.cache[computer] or {}
    local sameSquare = entry.x == square:getX() and entry.y == square:getY() and entry.z == square:getZ()
    if checkedAt > 0 and sameSquare and entry.checkedAt and checkedAt - entry.checkedAt >= 0 and checkedAt - entry.checkedAt < ComputerModPower.cacheDurationMs then
        return entry.result == true
    end
    if IsoGenerator and IsoGenerator.updateGenerator then
        pcall(function() IsoGenerator.updateGenerator(square) end)
    end
    local okHave, haveElectricity = pcall(function() return square:haveElectricity() end)
    local okGrid, hasGridPower = pcall(function() return square:hasGridPower() end)
    local hasRoom = square.getRoom and square:getRoom() ~= nil
    if okHave and haveElectricity == true then
        return saveResult(computer, entry, square, true, nil, checkedAt)
    end
    if okGrid and hasGridPower == true and hasRoom then
        return saveResult(computer, entry, square, true, nil, checkedAt)
    end
    if sameSquare and entry.generator and generatorCanReach(entry.generator, square) and generatorIsActive(entry.generator) then
        return saveResult(computer, entry, square, true, entry.generator, checkedAt)
    end
    local generator = findPoweredGeneratorNear(square)
    return saveResult(computer, entry, square, generator ~= nil, generator, checkedAt)
end

function ComputerModPower.hasComputerPower(computer)
    local data = ComputerModComputerTypes and ComputerModComputerTypes.getData and ComputerModComputerTypes.getData(computer) or computer and computer.getModData and computer:getModData() or nil
    if data and data.ComputerModNetworkTerminal == true and ComputerModSandbox and ComputerModSandbox.getBool and not ComputerModSandbox.getBool("NetworkTerminalNeedsPower", true) then
        return true
    end
    local gridPower = ComputerModPower.hasGridPower(computer)
    local definition = ComputerModComputerTypes and ComputerModComputerTypes.getDefinition and ComputerModComputerTypes.getDefinition(computer) or nil
    if definition and type(definition.resolvePower) == "function" then
        local ok, result = pcall(definition.resolvePower, computer, data, gridPower)
        if ok then return result == true end
    end
    return gridPower
end
