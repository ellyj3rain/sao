if isClient and isClient() then return end

require "ComputerMod_Network"
require "ComputerMod_Sandbox"
require "ComputerMod_Debug"
require "ComputerMod_RelayRepair"
require "ComputerMod_ServerPlayers"

ComputerModNetworkServer = ComputerModNetworkServer or {}
ComputerModNetworkServer.generatorCache = ComputerModNetworkServer.generatorCache or setmetatable({}, {__mode = "v"})

ComputerModNetworkServer.terminalRadius = 5
ComputerModNetworkServer.terminalSprite = "appliances_com_01_72"
ComputerModNetworkServer.terminals = ComputerModNetwork.terminals
ComputerModNetworkServer.obsoleteTerminals = {
    {x = 10329, y = 9341, z = 0},
    {x = 6083, y = 5262, z = 0},
    {x = 8131, y = 11742, z = 0},
    {x = 11899, y = 6933, z = 0},
    {x = 11901, y = 6951, z = 0}
}
ComputerModNetworkServer.terminalCoordinateMigrationVersion = 1
ComputerModNetworkServer.terminalCoordinateMigrations = {
    {id = "muldraugh_mccoy", oldX = 10329, oldY = 9341, oldZ = 0},
    {id = "riverside_police", oldX = 6083, oldY = 5262, oldZ = 0},
    {id = "rosewood_fire", oldX = 8131, oldY = 11742, oldZ = 0},
    {id = "westpoint_police", oldX = 11899, oldY = 6933, oldZ = 0}
}
local function sandboxBool(key, fallback)
    if ComputerModSandbox and ComputerModSandbox.getBool then
        return ComputerModSandbox.getBool(key, fallback)
    end
    return fallback == true
end

local function getTerminalById(id)
    return ComputerModNetwork.getTerminalById(id)
end

local function getTerminalForSquare(square)
    if not square then return nil end
    local x = square.getX and square:getX() or 0
    local y = square.getY and square:getY() or 0
    local z = square.getZ and square:getZ() or 0
    for i = 1, #ComputerModNetworkServer.terminals do
        local terminal = ComputerModNetworkServer.terminals[i]
        if x == terminal.x and y == terminal.y and z == terminal.z then
            return terminal
        end
    end
    return nil
end

local function isExactTerminalSquare(square, terminal)
    if not square or not terminal then return false end
    return square:getX() == terminal.x and square:getY() == terminal.y and square:getZ() == terminal.z
end

local function getSpriteName(object)
    local sprite = object and object.getSprite and object:getSprite() or nil
    return sprite and sprite.getName and sprite:getName() or nil
end

local function isComputerSpriteName(spriteName)
    if not spriteName then return false end
    local value = tostring(spriteName)
    return value == ComputerModNetworkServer.terminalSprite
        or value == "appliances_com_01_73"
        or value == "appliances_com_01_74"
        or value == "appliances_com_01_75"
        or value == "appliances_com_01_76"
        or value == "appliances_com_01_77"
        or value == "appliances_com_01_78"
        or value == "appliances_com_01_79"
end

local function forceTerminalSprite(object)
    if not object then return end
    if getSpriteName(object) == ComputerModNetworkServer.terminalSprite then return end
    if object.setSpriteFromName then
        pcall(function() object:setSpriteFromName(ComputerModNetworkServer.terminalSprite) end)
    elseif object.setSprite and getSprite then
        local sprite = getSprite(ComputerModNetworkServer.terminalSprite)
        if sprite then
            pcall(function() object:setSprite(sprite) end)
        end
    end
    if object.transmitUpdatedSpriteToClients then
        pcall(function() object:transmitUpdatedSpriteToClients() end)
    end
end

local function hasSquarePower(square)
    if not square then return false end
    if IsoGenerator and IsoGenerator.updateGenerator then
        pcall(function() IsoGenerator.updateGenerator(square) end)
    end
    local okHave, haveElectricity = pcall(function() return square:haveElectricity() end)
    local okGrid, hasGridPower = pcall(function() return square:hasGridPower() end)
    local hasRoom = square.getRoom and square:getRoom() ~= nil
    if okHave and haveElectricity == true then return true end
    if okGrid and hasGridPower == true and hasRoom then return true end
    return false
end

local function getGeneratorTileRange()
    local value = SandboxVars and tonumber(SandboxVars.GeneratorTileRange) or nil
    return value or 20
end

local function getGeneratorVerticalRange()
    local value = SandboxVars and tonumber(SandboxVars.GeneratorVerticalPowerRange) or nil
    return value or 3
end

local function getGeneratorFuelConsumption()
    local value = SandboxVars and tonumber(SandboxVars.GeneratorFuelConsumption) or nil
    if value == nil then value = 0.1 end
    if value < 0 then value = 0 end
    return value
end

local function getWorldAgeHours()
    if not getGameTime then return nil end
    local okTime, gameTime = pcall(getGameTime)
    if not okTime or not gameTime or not gameTime.getWorldAgeHours then return nil end
    local okAge, age = pcall(function() return gameTime:getWorldAgeHours() end)
    if not okAge or not age then return nil end
    return tonumber(age)
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

local function generatorCanReach(generator, x, y, z)
    local square = generator and generator.getSquare and generator:getSquare() or nil
    if not square then return false end
    local range = getGeneratorTileRange()
    local vertical = getGeneratorVerticalRange()
    local gx = square.getX and square:getX() or 0
    local gy = square.getY and square:getY() or 0
    local gz = square.getZ and square:getZ() or 0
    if math.abs(gx - x) > range or math.abs(gy - y) > range then return false end
    if math.abs(gz - z) > vertical then return false end
    return true
end

local function getGeneratorSnapshot(generator)
    if not generator then return nil end
    local okFuel, fuel = pcall(function() return generator:getFuel() end)
    if not okFuel then return nil end
    local square = generator.getSquare and generator:getSquare() or nil
    local age = getWorldAgeHours()
    local consumption = getGeneratorFuelConsumption()
    local snapshot = {
        fuel = tonumber(fuel or 0) or 0,
        checkedAgeHours = age,
        consumption = consumption
    }
    if square then
        snapshot.x = square.getX and square:getX() or nil
        snapshot.y = square.getY and square:getY() or nil
        snapshot.z = square.getZ and square:getZ() or nil
    end
    if age and consumption > 0 and snapshot.fuel > 0 then
        snapshot.emptyAtAgeHours = age + (snapshot.fuel / consumption)
    else
        snapshot.emptyAtAgeHours = nil
    end
    return snapshot
end

local function findPoweredGeneratorNear(x, y, z, terminalId)
    if not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local cached = terminalId and ComputerModNetworkServer.generatorCache[terminalId] or nil
    if cached and generatorCanReach(cached, x, y, z) and generatorIsActive(cached) then
        return cached
    end
    if terminalId then
        ComputerModNetworkServer.generatorCache[terminalId] = nil
    end
    local range = getGeneratorTileRange()
    local vertical = getGeneratorVerticalRange()
    for dz = -vertical, vertical do
        for dx = -range, range do
            for dy = -range, range do
                local square = cell:getGridSquare(x + dx, y + dy, z + dz)
                if square then
                    local objects = square.getObjects and square:getObjects() or nil
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local object = objects:get(i)
                            if isGeneratorObject(object) and generatorIsActive(object) and generatorCanReach(object, x, y, z) then
                                if terminalId then ComputerModNetworkServer.generatorCache[terminalId] = object end
                                return object
                            end
                        end
                    end
                    local specialObjects = square.getSpecialObjects and square:getSpecialObjects() or nil
                    if specialObjects then
                        for i = 0, specialObjects:size() - 1 do
                            local object = specialObjects:get(i)
                            if isGeneratorObject(object) and generatorIsActive(object) and generatorCanReach(object, x, y, z) then
                                if terminalId then ComputerModNetworkServer.generatorCache[terminalId] = object end
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

local function isWorldGridPowerAvailable()
    return ComputerModRelayRepair.isWorldGridPowerAvailable()
end

local getTerminalStore

local function markTerminalSpawned(terminal)
    local terminalStore = getTerminalStore(terminal)
    if not terminalStore then return end
    terminalStore.originalSpawned = true
    terminalStore.originalX = terminal.x
    terminalStore.originalY = terminal.y
    terminalStore.originalZ = terminal.z
    terminalStore.coordinateMigrationPending = nil
end

local function terminalWasSpawned(terminal)
    local terminalStore = getTerminalStore(terminal)
    return terminalStore and terminalStore.originalSpawned == true
end

local function getTerminalPosition(terminal)
    if not terminal then return nil, nil, nil end
    local terminalStore = getTerminalStore(terminal)
    local x = terminalStore and tonumber(terminalStore.currentX) or nil
    local y = terminalStore and tonumber(terminalStore.currentY) or nil
    local z = terminalStore and tonumber(terminalStore.currentZ) or nil
    if x ~= nil and y ~= nil and z ~= nil then
        return x, y, z
    end
    return terminal.x, terminal.y, terminal.z
end

local function terminalHasPower(terminal)
    if not sandboxBool("NetworkTerminalNeedsPower", true) then return true end
    if not terminal or not getCell then return nil end
    local cell = getCell()
    local x, y, z = getTerminalPosition(terminal)
    local square = cell and cell:getGridSquare(x, y, z) or nil
    if not square then return nil end
    return hasSquarePower(square)
end

local function getTerminalPowerState(terminal)
    if not sandboxBool("NetworkTerminalNeedsPower", true) then return true, "disabled", nil end
    if not terminal or not getCell then return nil, nil, nil end
    local cell = getCell()
    local x, y, z = getTerminalPosition(terminal)
    local square = cell and cell:getGridSquare(x, y, z) or nil
    if not square then return nil, nil, nil end
    local okGrid, hasGridPower = pcall(function() return square:hasGridPower() end)
    local hasRoom = square.getRoom and square:getRoom() ~= nil
    if okGrid and hasGridPower == true and hasRoom then
        return true, "grid", nil
    end
    local generator = findPoweredGeneratorNear(x, y, z, terminal.id)
    if generator then
        return true, "generator", getGeneratorSnapshot(generator)
    end
    if hasSquarePower(square) then
        return true, "local", nil
    end
    return false, nil, nil
end

local function updateTerminalPowerStore(terminal, powered, source, snapshot)
    local terminalStore = getTerminalStore(terminal)
    if not terminalStore then return end
    terminalStore.lastPower = powered == true
    terminalStore.powerSource = source
    if snapshot then
        terminalStore.generatorFuel = snapshot.fuel
        terminalStore.generatorCheckedAgeHours = snapshot.checkedAgeHours
        terminalStore.generatorFuelConsumption = snapshot.consumption
        terminalStore.generatorEmptyAtAgeHours = snapshot.emptyAtAgeHours
        terminalStore.generatorX = snapshot.x
        terminalStore.generatorY = snapshot.y
        terminalStore.generatorZ = snapshot.z
    elseif source ~= "generator" then
        terminalStore.generatorFuel = nil
        terminalStore.generatorCheckedAgeHours = nil
        terminalStore.generatorFuelConsumption = nil
        terminalStore.generatorEmptyAtAgeHours = nil
        terminalStore.generatorX = nil
        terminalStore.generatorY = nil
        terminalStore.generatorZ = nil
    end
end

local function estimateTerminalStoredPower(terminal)
    local terminalStore = getTerminalStore(terminal)
    if not terminalStore then return nil end
    if terminalStore.powerSource ~= "generator" then return nil end
    if not terminalStore.generatorEmptyAtAgeHours then return nil end
    local age = getWorldAgeHours()
    if not age then return nil end
    if age >= tonumber(terminalStore.generatorEmptyAtAgeHours or 0) then
        terminalStore.lastPower = false
        return false
    end
    return true
end

local function playerNearTerminal(player, terminal)
    if not player or not terminal then return false end
    local terminalX, terminalY, terminalZ = getTerminalPosition(terminal)
    local z = player.getZ and player:getZ() or 0
    local x = player.getX and player:getX() or 0
    local y = player.getY and player:getY() or 0
    return z == terminalZ
        and math.abs(x - terminalX) <= ComputerModNetworkServer.terminalRadius + 3
        and math.abs(y - terminalY) <= ComputerModNetworkServer.terminalRadius + 3
end

getTerminalStore = function(terminal)
    if not terminal then return nil end
    return ComputerModNetwork.getTerminalStore(terminal.id)
end

local function rememberTerminalLocation(object, terminal)
    if not object or not terminal then return end
    local square = object.getSquare and object:getSquare() or nil
    if not square then return end
    local terminalStore = getTerminalStore(terminal)
    if not terminalStore then return end
    terminalStore.currentX = square:getX()
    terminalStore.currentY = square:getY()
    terminalStore.currentZ = square:getZ()
    terminalStore.relocated = terminalStore.currentX ~= terminal.x
        or terminalStore.currentY ~= terminal.y
        or terminalStore.currentZ ~= terminal.z
end

local function markNetworkTerminal(object, terminal)
    if not object or not object.getModData or not terminal then return end
    forceTerminalSprite(object)
    local terminalStore = getTerminalStore(terminal)
    markTerminalSpawned(terminal)
    rememberTerminalLocation(object, terminal)
    local data = object:getModData()
    data.ComputerModNetworkTerminal = true
    data.ComputerModNetworkTerminalId = terminal.id
    data.ComputerModNetworkTerminalLabel = terminal.label
    data.ComputerModMetaInitialized = true
    data.ComputerModMachineID = "NET-" .. tostring(terminal.x) .. "-" .. tostring(terminal.y) .. "-" .. tostring(terminal.z)
    data.ComputerModOSInstalled = true
    data.ComputerModFactoryReset = false
    data.ComputerModPasswordEnabled = false
    data.ComputerModPassword = nil
    data.ComputerModUsername = "Network Admin"
    data.ComputerModAvatar = data.ComputerModAvatar or 1
    data.ComputerModInstalledGames = {}
    data.ComputerModMountedCD = nil
    data.ComputerModMountedCDItem = nil
    data.ComputerModMountedCDLabel = nil
    data.ComputerModNetworkRepaired = terminalStore and terminalStore.repaired == true
    data.ComputerModNetworkRepairDeposits = ComputerModRelayRepair.copyProgress(terminalStore and terminalStore.repairDeposits or nil)
    if object.transmitModData then
        pcall(function() object:transmitModData() end)
    end
end

local function findTerminalObject(square, terminal)
    if not square or not terminal then return nil end
    local function inspect(objects)
        if not objects then return nil end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local data = object and object.getModData and object:getModData() or nil
            if data and data.ComputerModNetworkTerminal == true then
                if not data.ComputerModNetworkTerminalId or data.ComputerModNetworkTerminalId == terminal.id then
                    markNetworkTerminal(object, terminal)
                    return object
                end
            end
            local spriteName = getSpriteName(object)
            if isComputerSpriteName(spriteName) and isExactTerminalSquare(square, terminal) then
                markNetworkTerminal(object, terminal)
                return object
            end
        end
        return nil
    end
    local object = inspect(square.getObjects and square:getObjects() or nil)
    if object then return object end
    return inspect(square.getSpecialObjects and square:getSpecialObjects() or nil)
end

local function findMarkedTerminalObject(square, terminal)
    if not square or not terminal then return nil end
    local function inspect(objects)
        if not objects then return nil end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local data = object and object.getModData and object:getModData() or nil
            if data and data.ComputerModNetworkTerminal == true and data.ComputerModNetworkTerminalId == terminal.id then
                markNetworkTerminal(object, terminal)
                return object
            end
        end
        return nil
    end
    local object = inspect(square.getObjects and square:getObjects() or nil)
    if object then return object end
    return inspect(square.getSpecialObjects and square:getSpecialObjects() or nil)
end

local function registerMovedTerminalsOnSquare(square)
    if not square then return end
    local seen = {}
    local function inspect(objects)
        if not objects then return end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object and not seen[object] then
                seen[object] = true
                local data = object.getModData and object:getModData() or nil
                local terminal = data and data.ComputerModNetworkTerminal == true and getTerminalById(data.ComputerModNetworkTerminalId) or nil
                if terminal then
                    markNetworkTerminal(object, terminal)
                end
            end
        end
    end
    inspect(square.getObjects and square:getObjects() or nil)
    inspect(square.getSpecialObjects and square:getSpecialObjects() or nil)
end

local function findRequestedTerminalObject(args, terminal)
    if not terminal or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local x = tonumber(args and args.x)
    local y = tonumber(args and args.y)
    local z = tonumber(args and args.z)
    if x ~= nil and y ~= nil and z ~= nil then
        local requestedSquare = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
        local requestedObject = findMarkedTerminalObject(requestedSquare, terminal)
        if requestedObject then return requestedObject end
    end
    local terminalX, terminalY, terminalZ = getTerminalPosition(terminal)
    local storedSquare = cell:getGridSquare(terminalX, terminalY, terminalZ)
    return findTerminalObject(storedSquare, terminal)
end

local function playerNearTerminalObject(player, object, terminal)
    local square = object and object.getSquare and object:getSquare() or nil
    if not player or not square then return playerNearTerminal(player, terminal) end
    local z = player.getZ and player:getZ() or 0
    local x = player.getX and player:getX() or 0
    local y = player.getY and player:getY() or 0
    return z == square:getZ()
        and math.abs(x - square:getX()) <= ComputerModNetworkServer.terminalRadius + 3
        and math.abs(y - square:getY()) <= ComputerModNetworkServer.terminalRadius + 3
end

local function hasTerminalNearby(terminal)
    if not terminal or not getCell then return false end
    local cell = getCell()
    if not cell then return false end
    for dx = -ComputerModNetworkServer.terminalRadius, ComputerModNetworkServer.terminalRadius do
        for dy = -ComputerModNetworkServer.terminalRadius, ComputerModNetworkServer.terminalRadius do
            local check = cell:getGridSquare(terminal.x + dx, terminal.y + dy, terminal.z)
            if findTerminalObject(check, terminal) then
                return true
            end
        end
    end
    return false
end

local function isObsoleteSquare(square)
    if not square then return false end
    local x = square.getX and square:getX() or 0
    local y = square.getY and square:getY() or 0
    local z = square.getZ and square:getZ() or 0
    for i = 1, #ComputerModNetworkServer.obsoleteTerminals do
        local terminal = ComputerModNetworkServer.obsoleteTerminals[i]
        if x == terminal.x and y == terminal.y and z == terminal.z then
            return true
        end
    end
    return false
end

local function removeObsoleteTerminal(square)
    if not square or not isObsoleteSquare(square) or not square.getObjects then return end
    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        local object = objects:get(i)
        local data = object and object.getModData and object:getModData() or nil
        if data and data.ComputerModNetworkTerminal == true then
            if square.transmitRemoveItemFromSquare then
                pcall(function() square:transmitRemoveItemFromSquare(object) end)
            end
            if square.RemoveTileObject then
                pcall(function() square:RemoveTileObject(object) end)
            end
        end
    end
end

local function countInventoryItems(inventory, fullType)
    if not inventory or not fullType then return 0 end
    if inventory.getCountTypeRecurse then
        local ok, count = pcall(function() return inventory:getCountTypeRecurse(fullType) end)
        if ok then return tonumber(count or 0) or 0 end
    end
    if not inventory.getItems then return 0 end
    local count = 0
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == fullType then count = count + 1 end
    end
    return count
end

local function removeInventoryItems(inventory, fullType, count)
    if not inventory or not fullType or count <= 0 then return false end
    local removed = 0
    local matches = nil
    if inventory.getAllTypeRecurse then
        local ok, items = pcall(function() return inventory:getAllTypeRecurse(fullType) end)
        if ok then matches = items end
    end
    if matches and matches.size and matches.get then
        for i = matches:size() - 1, 0, -1 do
            local item = matches:get(i)
            local container = item and item.getContainer and item:getContainer() or inventory
            local okRemove = item and container and container.Remove and pcall(function() container:Remove(item) end) or false
            if okRemove and sendRemoveItemFromContainer then
                pcall(function() sendRemoveItemFromContainer(container, item) end)
            end
            if okRemove then
                removed = removed + 1
                if removed >= count then return true end
            end
        end
    elseif inventory.getItems then
        local items = inventory:getItems()
        for i = items:size() - 1, 0, -1 do
            local item = items:get(i)
            if item and item.getFullType and item:getFullType() == fullType then
                local okRemove = inventory.Remove and pcall(function() inventory:Remove(item) end) or false
                if okRemove and sendRemoveItemFromContainer then
                    pcall(function() sendRemoveItemFromContainer(inventory, item) end)
                end
                if okRemove then
                    removed = removed + 1
                    if removed >= count then return true end
                end
            end
        end
    end
    return removed >= count
end

local function syncInventory(inventory)
    if inventory and inventory.setDrawDirty then
        pcall(function() inventory:setDrawDirty(true) end)
    end
end

local function sendRepairResult(player, result)
    if isServer and isServer() and sendServerCommand then
        sendServerCommand(player, "ComputerModNetwork", "RepairResult", result)
    elseif ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handleNetworkRepairResult then
        ComputerScreenUI.instance:handleNetworkRepairResult(result)
    end
end

local function getSyncPayload(player)
    local store = ComputerModNetwork.getStore()
    return {
        enabled = ComputerModNetwork.isInternetEnabled(),
        activeTerminalId = store.activeTerminalId or false,
        terminals = store.terminals,
        debugEnabled = player and ComputerModDebug.isEnabled(player) or false
    }
end

function ComputerModNetworkServer.sync(player)
    if player then
        sendServerCommand(player, "ComputerModNetwork", "Sync", getSyncPayload(player))
    else
        ModData.transmit(ComputerModNetwork.storeName)
        local players = ComputerModServerPlayers.get()
        if players then
            for i = 0, players:size() - 1 do
                local onlinePlayer = players:get(i)
                sendServerCommand(onlinePlayer, "ComputerModNetwork", "Sync", getSyncPayload(onlinePlayer))
            end
        end
    end
end

local function setTerminalRepaired(terminal, repaired, terminalObject)
    local terminalStore = getTerminalStore(terminal)
    if terminalStore then
        terminalStore.repaired = repaired == true
        local powered, source, snapshot = getTerminalPowerState(terminal)
        updateTerminalPowerStore(terminal, powered == true, source, snapshot)
    end
    local object = terminalObject
    if not object and getCell then
        local cell = getCell()
        local x, y, z = getTerminalPosition(terminal)
        local square = cell and cell:getGridSquare(x, y, z) or nil
        object = findTerminalObject(square, terminal)
    end
    local data = object and object.getModData and object:getModData() or nil
    if data then
        data.ComputerModNetworkRepaired = repaired == true
        data.ComputerModNetworkRepairDeposits = ComputerModRelayRepair.copyProgress(terminalStore and terminalStore.repairDeposits or nil)
        if object.transmitModData then
            pcall(function() object:transmitModData() end)
        end
    end
end

local function getElectricalLevel(player)
    if not player or not player.getPerkLevel or not Perks or not Perks.Electricity then return 0 end
    return tonumber(player:getPerkLevel(Perks.Electricity) or 0) or 0
end

local function getRepairProgress(terminal)
    local terminalStore = getTerminalStore(terminal)
    if not terminalStore then return ComputerModRelayRepair.normalizeProgress(nil), nil end
    terminalStore.repairDeposits = ComputerModRelayRepair.normalizeProgress(terminalStore.repairDeposits)
    return terminalStore.repairDeposits, terminalStore
end

local function syncRepairProgressToObject(terminalObject, progress)
    local data = terminalObject and terminalObject.getModData and terminalObject:getModData() or nil
    if not data then return end
    data.ComputerModNetworkRepairDeposits = ComputerModRelayRepair.copyProgress(progress)
    if terminalObject.transmitModData then
        pcall(function() terminalObject:transmitModData() end)
    end
end

local function getRepairProgressPayload(terminal, player, success, reason)
    local progress, terminalStore = getRepairProgress(terminal)
    local repaired = terminalStore and terminalStore.repaired == true or false
    return {
        success = success == true,
        reason = reason,
        terminalId = terminal and terminal.id or false,
        progress = ComputerModRelayRepair.copyProgress(progress),
        electricalLevel = getElectricalLevel(player),
        requiredElectricalLevel = ComputerModRelayRepair.requiredElectricalLevel,
        repaired = repaired,
        complete = repaired
    }
end

local function sendRepairProgress(player, payload)
    if isServer and isServer() and sendServerCommand then
        sendServerCommand(player, "ComputerModNetwork", "RepairProgress", payload)
    elseif ComputerModRelayRepairUI and ComputerModRelayRepairUI.instance and ComputerModRelayRepairUI.instance.handleServerProgress then
        ComputerModRelayRepairUI.instance:handleServerProgress(payload)
    end
end

local function resolveRepairTerminal(player, args)
    local terminal = getTerminalById(args and args.terminalId) or nil
    if not terminal then return nil, nil, "terminal" end
    local terminalObject = findRequestedTerminalObject(args, terminal)
    if not terminalObject then return terminal, nil, "terminal" end
    if not playerNearTerminalObject(player, terminalObject, terminal) then
        return terminal, terminalObject, "distance"
    end
    return terminal, terminalObject, nil
end

local function getRepairAccessFailure(player, terminal)
    if not ComputerModDebug.isEnabled(player) then
        if ComputerModNetwork.isInternetEnabled() then
            return "network"
        end
        if isWorldGridPowerAvailable() ~= false then
            return "grid"
        end
    end
    local powered = getTerminalPowerState(terminal)
    if sandboxBool("NetworkTerminalNeedsPower", true) and powered ~= true then
        return "power"
    end
    return nil
end

local function tryCompleteRepair(player, terminal, terminalObject, progress)
    local terminalStore = getTerminalStore(terminal)
    if terminalStore and terminalStore.repaired == true then return true end
    if not ComputerModRelayRepair.isComplete(progress) then return false end
    if getElectricalLevel(player) < ComputerModRelayRepair.requiredElectricalLevel then return false end
    setTerminalRepaired(terminal, true, terminalObject)
    return true
end

local function requestRepairProgress(player, args)
    local terminal, terminalObject, reason = resolveRepairTerminal(player, args)
    if reason then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, false, reason))
        return
    end
    local progress, terminalStore = getRepairProgress(terminal)
    if terminalStore and terminalStore.repaired == true then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, true, nil))
        return
    end
    reason = getRepairAccessFailure(player, terminal)
    if reason then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, false, reason))
        return
    end
    if tryCompleteRepair(player, terminal, terminalObject, progress) then
        ComputerModNetworkServer.sync()
    end
    sendRepairProgress(player, getRepairProgressPayload(terminal, player, true, nil))
end

local function depositRepairItem(player, args)
    local terminal, terminalObject, reason = resolveRepairTerminal(player, args)
    if reason then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, false, reason))
        return
    end
    local progress, terminalStore = getRepairProgress(terminal)
    if terminalStore and terminalStore.repaired == true then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, true, nil))
        return
    end
    reason = getRepairAccessFailure(player, terminal)
    if reason then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, false, reason))
        return
    end
    local part = ComputerModRelayRepair.getPart(args and args.requirementKey)
    if not part then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, false, "item"))
        return
    end
    local missing = math.max(0, part.count - tonumber(progress[part.key] or 0))
    local requested = math.max(0, math.floor(tonumber(args and args.count or 0) or 0))
    requested = math.min(missing, requested)
    local inventory = player and player.getInventory and player:getInventory() or nil
    local available = countInventoryItems(inventory, part.fullType)
    local amount = math.min(requested, available)
    if amount <= 0 or not removeInventoryItems(inventory, part.fullType, amount) then
        sendRepairProgress(player, getRepairProgressPayload(terminal, player, false, "item"))
        return
    end
    progress[part.key] = math.min(part.count, tonumber(progress[part.key] or 0) + amount)
    terminalStore.repairDeposits = ComputerModRelayRepair.copyProgress(progress)
    syncInventory(inventory)
    syncRepairProgressToObject(terminalObject, terminalStore.repairDeposits)
    tryCompleteRepair(player, terminal, terminalObject, terminalStore.repairDeposits)
    ComputerModNetworkServer.sync()
    sendRepairProgress(player, getRepairProgressPayload(terminal, player, true, nil))
end

local function disableInternetForPowerLoss(terminal)
    ComputerModNetwork.setInternetEnabled(false)
    ComputerModNetwork.setActiveTerminal(nil)
    ComputerModNetworkServer.sync()
end

local function updateActiveTerminalPower()
    if not sandboxBool("NetworkOutageOnPowerLoss", true) then return end
    if not sandboxBool("NetworkTerminalNeedsPower", true) then return end
    if not ComputerModNetwork.isInternetEnabled() then return end
    local store = ComputerModNetwork.getStore()
    local activeTerminal = getTerminalById(store.activeTerminalId)
    if activeTerminal then
        local powered, source, snapshot = getTerminalPowerState(activeTerminal)
        if powered == false then
            updateTerminalPowerStore(activeTerminal, false, source, snapshot)
            disableInternetForPowerLoss(activeTerminal)
            return
        end
        if powered == true then
            updateTerminalPowerStore(activeTerminal, true, source, snapshot)
            return
        end
        local estimated = estimateTerminalStoredPower(activeTerminal)
        if estimated == false then
            disableInternetForPowerLoss(activeTerminal)
            return
        end
        return
    end
    if isWorldGridPowerAvailable() == false then
        disableInternetForPowerLoss(activeTerminal)
    end
end

local powerCheckTick = 0
local lastPowerCheckMs = 0
local powerCheckIntervalMs = 5000

local function updateActiveTerminalPowerThrottled(force)
    local now = getTimestampMs and getTimestampMs() or 0
    if force ~= true and now > 0 and lastPowerCheckMs > 0 and now - lastPowerCheckMs < powerCheckIntervalMs then return end
    lastPowerCheckMs = now
    updateActiveTerminalPower()
end

local function updateActiveTerminalPowerTick()
    powerCheckTick = powerCheckTick + 1
    if powerCheckTick < (getTimestampMs and 60 or 300) then return end
    powerCheckTick = 0
    updateActiveTerminalPowerThrottled(false)
end

local function migrateTerminalSpawnState(store)
    if not store or type(store.terminals) ~= "table" then return end
    for i = 1, #ComputerModNetworkServer.terminals do
        local terminal = ComputerModNetworkServer.terminals[i]
        local terminalStore = store.terminals[terminal.id]
        if terminalStore and terminalStore.coordinateMigrationPending ~= true and terminalStore.originalSpawned ~= true then
            if terminalStore.repaired == true or terminalStore.lastPower ~= nil or terminalStore.powerSource ~= nil or store.activeTerminalId == terminal.id then
                terminalStore.originalSpawned = true
                terminalStore.originalX = terminal.x
                terminalStore.originalY = terminal.y
                terminalStore.originalZ = terminal.z
            end
        end
    end
end

local function migrateTerminalCoordinates(store)
    if not store or type(store.terminals) ~= "table" then return end
    local version = tonumber(store.terminalCoordinateMigrationVersion or 0) or 0
    if version >= ComputerModNetworkServer.terminalCoordinateMigrationVersion then return end
    for i = 1, #ComputerModNetworkServer.terminalCoordinateMigrations do
        local migration = ComputerModNetworkServer.terminalCoordinateMigrations[i]
        local terminal = getTerminalById(migration.id)
        local terminalStore = terminal and store.terminals[migration.id] or nil
        if terminalStore then
            local currentX = tonumber(terminalStore.currentX)
            local currentY = tonumber(terminalStore.currentY)
            local currentZ = tonumber(terminalStore.currentZ)
            local originalX = tonumber(terminalStore.originalX)
            local originalY = tonumber(terminalStore.originalY)
            local originalZ = tonumber(terminalStore.originalZ)
            local hasCurrent = currentX ~= nil and currentY ~= nil and currentZ ~= nil
            local currentAtOld = currentX == migration.oldX and currentY == migration.oldY and currentZ == migration.oldZ
            local originalAtOld = originalX == migration.oldX and originalY == migration.oldY and originalZ == migration.oldZ
            local playerRelocated = terminalStore.relocated == true and hasCurrent and not currentAtOld
            if not playerRelocated and (currentAtOld or originalAtOld or not hasCurrent) then
                terminalStore.currentX = terminal.x
                terminalStore.currentY = terminal.y
                terminalStore.currentZ = terminal.z
                terminalStore.originalX = terminal.x
                terminalStore.originalY = terminal.y
                terminalStore.originalZ = terminal.z
                terminalStore.originalSpawned = false
                terminalStore.relocated = false
                terminalStore.coordinateMigrationPending = true
                ComputerModNetworkServer.generatorCache[terminal.id] = nil
            end
        end
    end
    store.terminalCoordinateMigrationVersion = ComputerModNetworkServer.terminalCoordinateMigrationVersion
end

function ComputerModNetworkServer.onInitGlobalModData(isNewGame)
    local store = ComputerModNetwork.getStore()
    store.terminals = store.terminals or {}
    migrateTerminalCoordinates(store)
    migrateTerminalSpawnState(store)
    if isNewGame or store.terminalSpawnAllowed == nil then
        store.terminalSpawnAllowed = true
    end
end

function ComputerModNetworkServer.spawnTerminalOnSquare(square)
    removeObsoleteTerminal(square)
    registerMovedTerminalsOnSquare(square)
    local terminal = getTerminalForSquare(square)
    if not terminal then return end
    local store = ComputerModNetwork.getStore()
    if store.terminalSpawnAllowed ~= true then return end
    if hasTerminalNearby(terminal) then
        updateActiveTerminalPowerThrottled(false)
        return
    end
    if terminalWasSpawned(terminal) then
        return
    end
    local object = nil
    if IsoObject and IsoObject.new then
        local ok, created = pcall(function() return IsoObject.new(square, ComputerModNetworkServer.terminalSprite, "Network Terminal", false) end)
        if not ok or not created then
            ok, created = pcall(function() return IsoObject.new(getCell(), square, ComputerModNetworkServer.terminalSprite, false) end)
        end
        if not ok or not created then
            ok, created = pcall(function() return IsoObject.new(square, ComputerModNetworkServer.terminalSprite, false) end)
        end
        if ok then object = created end
    end
    if object and square.AddTileObject then
        local okAdd = pcall(function() square:AddTileObject(object) end)
        if not okAdd and square.AddSpecialObject then
            okAdd = pcall(function() square:AddSpecialObject(object) end)
        end
        if okAdd then
            markNetworkTerminal(object, terminal)
            if object.transmitCompleteItemToClients then
                pcall(function() object:transmitCompleteItemToClients() end)
            end
        end
    end
end

function ComputerModNetworkServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModNetwork" then return end
    if ComputerModServerPlayers and ComputerModServerPlayers.markReady then ComputerModServerPlayers.markReady() end
    args = args or {}
    if command == "RequestSync" then
        ComputerModNetworkServer.sync(player)
    elseif command == "SetPlayerDebug" then
        local enabled = args.enabled == true
        local success = ComputerModDebug.setEnabled(player, enabled)
        sendServerCommand(player, "ComputerModNetwork", "DebugModeResult", {
            success = success == true,
            enabled = success == true and enabled or false
        })
    elseif command == "SetInternet" then
        if ComputerModDebug.isEnabled(player) then
            ComputerModNetwork.setInternetEnabled(args.enabled == true)
            if args.enabled ~= true then
                ComputerModNetwork.setActiveTerminal(nil)
            end
            ComputerModNetworkServer.sync()
        end
    elseif command == "RequestRepairProgress" then
        requestRepairProgress(player, args)
    elseif command == "DepositRepairItem" then
        depositRepairItem(player, args)
    elseif command == "RepairInternet" then
        local terminal = getTerminalById(args.terminalId) or nil
        if not terminal then
            sendRepairResult(player, {success = false, message = "Relay not found."})
            return
        end
        if ComputerModNetwork.isInternetEnabled() then
            sendRepairResult(player, {success = false, message = "Network is already online."})
            return
        end
        local terminalObject = findRequestedTerminalObject(args, terminal)
        if not terminalObject then
            sendRepairResult(player, {success = false, message = "Relay terminal object not found."})
            return
        end
        if not playerNearTerminalObject(player, terminalObject, terminal) then
            sendRepairResult(player, {success = false, message = "Move closer to the relay."})
            return
        end
        local powered, source, snapshot = getTerminalPowerState(terminal)
        if sandboxBool("NetworkTerminalNeedsPower", true) and powered ~= true then
            sendRepairResult(player, {success = false, message = "No power at relay terminal."})
            return
        end
        local terminalStore = getTerminalStore(terminal)
        if not terminalStore or terminalStore.repaired ~= true then
            sendRepairResult(player, {success = false, message = "Relay service incomplete."})
            return
        end
        setTerminalRepaired(terminal, true, terminalObject)
        updateTerminalPowerStore(terminal, true, source, snapshot)
        ComputerModNetwork.setActiveTerminal(terminal.id)
        ComputerModNetwork.setInternetEnabled(true)
        ComputerModNetworkServer.sync()
        sendRepairResult(player, {success = true, terminalId = terminal.id, message = "Internet backbone online."})
    end
end

Events.OnInitGlobalModData.Add(ComputerModNetworkServer.onInitGlobalModData)
Events.OnClientCommand.Add(ComputerModNetworkServer.onClientCommand)
if Events.LoadGridsquare then
    Events.LoadGridsquare.Add(ComputerModNetworkServer.spawnTerminalOnSquare)
end
if Events.OnTick then
    Events.OnTick.Add(updateActiveTerminalPowerTick)
end
