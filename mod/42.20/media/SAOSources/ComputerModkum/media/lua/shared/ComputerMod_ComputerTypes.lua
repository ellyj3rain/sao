ComputerModComputerTypes = ComputerModComputerTypes or {}

local registry = ComputerModComputerTypes
registry.types = registry.types or {}
registry.order = registry.order or {}
registry.bySprite = registry.bySprite or {}
registry.byItemType = registry.byItemType or {}
registry.itemDataServerOwned = {
    ComputerModComputerType = true,
    ComputerModMachineID = true,
    ComputerModDriveID = true,
    ComputerModComponents = true,
    ComputerModComponentsInitialized = true,
    ComputerModComponentsVersion = true,
    ComputerModComponentsLastWearHour = true,
    ComputerModLaptopCharge = true,
    ComputerModLaptopPlugged = true,
    ComputerModLaptopEnergyHour = true,
    ComputerModLaptopLastSyncCharge = true,
    ComputerModNetworkTerminal = true
}

local function normalized(value)
    return string.lower(tostring(value or ""))
end

local function addLookup(target, values, typeId)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do
        local name = type(key) == "number" and value or key
        if name and name ~= "" then target[normalized(name)] = typeId end
    end
end

function registry.registerType(definition)
    if type(definition) ~= "table" or not definition.id or definition.id == "" then return nil end
    local id = tostring(definition.id)
    local existing = registry.types[id]
    if not existing then registry.order[#registry.order + 1] = id end
    registry.types[id] = definition
    addLookup(registry.bySprite, definition.spriteNames, id)
    addLookup(registry.byItemType, definition.itemTypes, id)
    return definition
end

function registry.getInventoryItem(object)
    if not object then return nil end
    if object.getItem then
        local ok, item = pcall(function() return object:getItem() end)
        if ok and item then return item end
    end
    if object.getFullType and object.getModData and not object.getSprite then return object end
    return nil
end

function registry.getRawData(object, definition)
    if not object then return nil end
    definition = definition or registry.getDefinition(object)
    if definition and definition.dataOnItem == true then
        local item = registry.getInventoryItem(object)
        return item and item.getModData and item:getModData() or nil
    end
    return object.getModData and object:getModData() or nil
end

function registry.getDefinition(object)
    if not object then return nil end
    local item = registry.getInventoryItem(object)
    local fullType = item and item.getFullType and item:getFullType() or nil
    local itemTypeId = fullType and registry.byItemType[normalized(fullType)] or nil
    if itemTypeId then return registry.types[itemTypeId] end

    local sprite = object.getSprite and object:getSprite() or nil
    local spriteName = sprite and sprite.getName and sprite:getName() or nil
    local spriteTypeId = spriteName and registry.bySprite[normalized(spriteName)] or nil
    if spriteTypeId then return registry.types[spriteTypeId] end

    local objectData = object.getModData and object:getModData() or nil
    local itemData = item and item.getModData and item:getModData() or nil
    local typeId = itemData and itemData.ComputerModComputerType or objectData and objectData.ComputerModComputerType
    return typeId and registry.types[tostring(typeId)] or nil
end

function registry.getData(object)
    local definition = registry.getDefinition(object)
    return registry.getRawData(object, definition)
end

function registry.isComputer(object)
    return registry.getDefinition(object) ~= nil
end

function registry.isType(data, typeId)
    return type(data) == "table" and tostring(data.ComputerModComputerType or "desktop") == tostring(typeId or "")
end

function registry.ensureIdentity(object, data, definition)
    data = data or registry.getData(object)
    definition = definition or registry.getDefinition(object)
    if type(data) ~= "table" or not definition then return data end
    data.ComputerModComputerType = definition.id
    if not data.ComputerModMachineID or data.ComputerModMachineID == "" then
        local item = registry.getInventoryItem(object)
        local itemId = item and item.getID and item:getID() or nil
        local square = object.getSquare and object:getSquare() or nil
        local suffix
        if itemId ~= nil then
            suffix = tostring(itemId)
        elseif square then
            suffix = tostring(square:getX()) .. "-" .. tostring(square:getY()) .. "-" .. tostring(square:getZ())
        else
            suffix = tostring(getTimestampMs and getTimestampMs() or ZombRand and ZombRand(1000000) or 0)
        end
        data.ComputerModMachineID = tostring(definition.machinePrefix or "PC") .. "-" .. suffix
    end
    return data
end

function registry.transmitData(object)
    if not object then return false end
    local definition = registry.getDefinition(object)
    if definition and definition.dataOnItem == true then
        if isClient and isClient() then
            local args = registry.getCommandArgs(object)
            local item = registry.getInventoryItem(object)
            local itemId = item and item.getID and item:getID() or nil
            if args and itemId and sendClientCommand then
                local square = object.getSquare and object:getSquare() or nil
                local player = nil
                local count = getNumActivePlayers and getNumActivePlayers() or 1
                for index = 0, math.max(0, count - 1) do
                    local candidate = getSpecificPlayer and getSpecificPlayer(index) or nil
                    if candidate and square and candidate:getZ() == square:getZ()
                            and math.abs(candidate:getX() - square:getX()) <= 4
                            and math.abs(candidate:getY() - square:getY()) <= 4 then
                        player = candidate
                        break
                    end
                end
                if player then
                    local data = registry.getData(object)
                    local snapshot = {}
                    for key, value in pairs(data) do
                        if type(key) == "string" and string.sub(key, 1, 11) == "ComputerMod"
                                and not registry.itemDataServerOwned[key] then
                            snapshot[key] = value
                        end
                    end
                    args.itemId = itemId
                    args.itemData = snapshot
                    sendClientCommand(player, "ComputerModComputerData", "SaveItemData", args)
                    return true
                end
            end
        elseif isServer and isServer() then
            local worldObject = object
            if object.getWorldItem then
                local okWorld, resolved = pcall(function() return object:getWorldItem() end)
                if okWorld and resolved then worldObject = resolved end
            end
            if worldObject and worldObject.flagForHotSave then
                pcall(function() worldObject:flagForHotSave() end)
            end
            -- SWAP_ITEM serializes the current inventory item into an object
            -- change. AddItemToMap would create a second world object.
            if worldObject and worldObject.sendObjectChange and IsoObjectChange and IsoObjectChange.SWAP_ITEM then
                local ok = pcall(function() worldObject:sendObjectChange(IsoObjectChange.SWAP_ITEM) end)
                if ok then return true end
            end
        else
            -- In single player the item is already the authoritative saved copy.
            return true
        end
        return false
    end
    if object.transmitModData then
        local ok = pcall(function() object:transmitModData() end)
        if ok then return true end
    end
    return false
end

function registry.getCommandArgs(object)
    local square = object and object.getSquare and object:getSquare() or nil
    local definition = registry.getDefinition(object)
    local data = registry.getData(object)
    if not square or not definition or not data then return nil end
    registry.ensureIdentity(object, data, definition)
    return {
        x = square:getX(), y = square:getY(), z = square:getZ(),
        machineId = tostring(data.ComputerModMachineID or ""),
        computerType = definition.id
    }
end

local function inspect(objects, machineId, typeId, allowTerminal)
    if not objects or not objects.size or not objects.get then return nil end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local definition = registry.getDefinition(object)
        local data = definition and registry.getData(object) or nil
        if definition and data then registry.ensureIdentity(object, data, definition) end
        if definition and data
                and (not typeId or typeId == "" or definition.id == typeId)
                and (allowTerminal == true or data.ComputerModNetworkTerminal ~= true)
                and (not machineId or machineId == "" or tostring(data.ComputerModMachineID or "") == machineId) then
            return object
        end
    end
    return nil
end

function registry.findOnSquare(square, machineId, typeId, allowTerminal)
    if not square then return nil end
    return inspect(square.getObjects and square:getObjects() or nil, machineId, typeId, allowTerminal)
        or inspect(square.getSpecialObjects and square:getSpecialObjects() or nil, machineId, typeId, allowTerminal)
        or inspect(square.getWorldObjects and square:getWorldObjects() or nil, machineId, typeId, allowTerminal)
end

function registry.findFromArgs(args, allowTerminal)
    if type(args) ~= "table" or not getCell then return nil end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z then return nil end
    local square = getCell():getGridSquare(x, y, z)
    return registry.findOnSquare(square, tostring(args.machineId or ""), tostring(args.computerType or ""), allowTerminal)
end

registry.registerType({
    id = "desktop",
    machinePrefix = "PC",
    dataOnItem = false,
    frameControls = {
        {id = "mute", x1 = 236, y1 = 466, x2 = 344, y2 = 501},
        {id = "power", x1 = 496, y1 = 476, x2 = 542, y2 = 526}
    },
    spriteNames = {
        "appliances_com_01_72", "appliances_com_01_73", "appliances_com_01_74", "appliances_com_01_75",
        "appliances_com_01_76", "appliances_com_01_77", "appliances_com_01_78", "appliances_com_01_79"
    }
})
