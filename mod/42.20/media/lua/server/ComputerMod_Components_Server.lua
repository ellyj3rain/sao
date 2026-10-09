-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_Components"
require "ComputerMod_Debug"
require "ComputerMod_ComputerTypes"

if not isServer() then return end

ComputerModComponentsServer = ComputerModComponentsServer or {}

local function findComputer(args)
    return ComputerModComputerTypes.findFromArgs(args, false)
end

local function near(player, object)
    return player and object and player:getZ() == object:getZ() and math.abs(player:getX() - object:getX()) <= 3 and math.abs(player:getY() - object:getY()) <= 3
end

local function eachInventoryItem(container, callback)
    if not container or not container.getItems then return nil end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if callback(item) then return item end
        local nested = item and item.getInventory and item:getInventory() or nil
        local match = nested and eachInventoryItem(nested, callback) or nil
        if match then return match end
    end
    return nil
end

local function hasScrewdriver(player)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then return false end
    if inventory.containsTagEvalRecurse and ItemTag and ItemTag.SCREWDRIVER then
        return inventory:containsTagEvalRecurse(ItemTag.SCREWDRIVER, function(item)
            return item ~= nil and (not item.isBroken or item:isBroken() ~= true)
        end)
    end
    return eachInventoryItem(inventory, function(item)
        local fullType = item and item.getFullType and string.lower(tostring(item:getFullType())) or ""
        return fullType == "base.screwdriver"
            or fullType == "base.screwdriver_old"
            or fullType == "base.screwdriver_improvised"
    end) ~= nil
end

local function hasPliers(player)
    local inventory = player and player.getInventory and player:getInventory() or nil
    return eachInventoryItem(inventory, function(item)
        local fullType = item and item.getFullType and string.lower(tostring(item:getFullType())) or ""
        return fullType == "base.pliers" and (not item.isBroken or item:isBroken() ~= true)
    end) ~= nil
end

local function electricalLevel(player)
    if not player or not player.getPerkLevel or not Perks or not Perks.Electricity then return 0 end
    return tonumber(player:getPerkLevel(Perks.Electricity) or 0) or 0
end

local function awardElectricalXp(player, amount)
    local xp = player and player.getXp and player:getXp() or nil
    if xp and xp.AddXP and Perks and Perks.Electricity then
        xp:AddXP(Perks.Electricity, tonumber(amount) or 0)
    end
end

local function collectMaterials(container, fullType, result)
    if not container or not container.getItems then return end
    local wanted = string.lower(tostring(fullType or ""))
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and string.lower(tostring(item:getFullType())) == wanted then result[#result + 1] = item end
        local nested = item and item.getInventory and item:getInventory() or nil
        if nested then collectMaterials(nested, fullType, result) end
    end
end

local function repairMaterialItems(player, spec)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory or not spec then return nil end
    local selected = {}
    for i = 1, #(spec.materials or {}) do
        local requirement = spec.materials[i]
        local matches = {}
        collectMaterials(inventory, requirement.type, matches)
        if #matches < (tonumber(requirement.count) or 1) then return nil end
        for index = 1, (tonumber(requirement.count) or 1) do selected[#selected + 1] = matches[index] end
    end
    return selected
end

local function findItem(player, fullType, itemId)
    local wantedType = string.lower(tostring(fullType or ""))
    local wantedId = tostring(itemId or "")
    return eachInventoryItem(player and player:getInventory() or nil, function(item)
        if not item or not item.getFullType or string.lower(tostring(item:getFullType())) ~= wantedType then return false end
        if wantedId == "" then return true end
        return item.getID and tostring(item:getID()) == wantedId
    end)
end

local function removeItem(item)
    local container = item and item.getContainer and item:getContainer() or nil
    if not container or not container.Remove then return false end
    container:Remove(item)
    if sendRemoveItemFromContainer then sendRemoveItemFromContainer(container, item) end
    return true
end

local function addStateItem(player, part, state)
    local inventory = player and player.getInventory and player:getInventory() or nil
    local item = inventory and inventory.AddItem and inventory:AddItem(part.itemType) or nil
    if not item then return nil end
    ComputerModComponents.writeStateToItem(item, part.id, state)
    if sendAddItemToContainer then sendAddItemToContainer(inventory, item) end
    return item
end

local function result(player, action, success, reason, object)
    local data = ComputerModComputerTypes.getData(object)
    sendServerCommand(player, "ComputerModComponents", "ActionResult", {
        action = action,
        success = success == true,
        reason = reason or "",
        components = data and ComputerModComponents.copyValue(data.ComputerModComponents) or {},
        driveId = data and data.ComputerModDriveID or nil
    })
end

local function validate(player, args, needsTool)
    local object = findComputer(args)
    if not object then return nil, "invalid_computer" end
    if not near(player, object) then return object, "too_far" end
    local data = ComputerModComputerTypes.getData(object)
    local wasActivated = data.ComputerModMetaInitialized == true
    ComputerModComputerTypes.ensureIdentity(object, data)
    ComputerModComponents.ensure(data, ComputerModComponents.getComputerSeed(data, object), wasActivated, ComputerModComponents.getWorldAgeHours())
    if data.ComputerModPowerOn == true then return object, "powered_on" end
    if needsTool and not hasScrewdriver(player) then return object, "screwdriver" end
    return object, nil
end

function ComputerModComponentsServer.install(player, args)
    local object, reason = validate(player, args, true)
    if reason then result(player, "install", false, reason, object); return end
    local data = ComputerModComputerTypes.getData(object)
    local part = ComputerModComponents.getPart(args.partId)
    if not part or not ComputerModComponents.isPartCompatible(part, data) or tostring(args.itemType or "") ~= part.itemType then result(player, "install", false, "invalid_part", object); return end
    if data.ComputerModComponents[part.id] ~= nil then result(player, "install", false, "occupied", object); return end
    local item = findItem(player, part.itemType, args.itemId)
    if not item then result(player, "install", false, "missing_part", object); return end
    local state = ComputerModComponents.readStateFromItem(item, part.id)
    if not state or not removeItem(item) or not ComputerModComponents.attachPart(data, part.id, state) then result(player, "install", false, "inventory_error", object); return end
    ComputerModComputerTypes.transmitData(object)
    result(player, "install", true, nil, object)
end

function ComputerModComponentsServer.remove(player, args)
    local object, reason = validate(player, args, true)
    if reason then result(player, "remove", false, reason, object); return end
    local data = ComputerModComputerTypes.getData(object)
    local part = ComputerModComponents.getPart(args.partId)
    local state = part and data.ComputerModComponents[part.id] or nil
    if not part or not ComputerModComponents.isPartCompatible(part, data) or type(state) ~= "table" then result(player, "remove", false, "missing_part", object); return end
    state = ComputerModComponents.detachPart(data, part.id)
    if not addStateItem(player, part, state) then
        ComputerModComponents.attachPart(data, part.id, state)
        result(player, "remove", false, "inventory_error", object)
        return
    end
    ComputerModComputerTypes.transmitData(object)
    result(player, "remove", true, nil, object)
end

function ComputerModComponentsServer.repair(player, args)
    local object, reason = validate(player, args, true)
    if reason then result(player, "repair", false, reason, object); return end
    if not hasPliers(player) then result(player, "repair", false, "pliers", object); return end
    local data = ComputerModComputerTypes.getData(object)
    local part = ComputerModComponents.getPart(args.partId)
    local state = part and data.ComputerModComponents[part.id] or nil
    local spec = ComputerModComponents.getRepairSpec(part)
    local level = electricalLevel(player)
    if not part or not ComputerModComponents.isPartCompatible(part, data) or type(state) ~= "table" or not spec then result(player, "repair", false, "missing_part", object); return end
    if level < (tonumber(spec.level) or 0) then result(player, "repair", false, "skill", object); return end
    if not ComputerModComponents.getRepairTarget(part, state, level) then result(player, "repair", false, "not_repairable", object); return end
    local materials = repairMaterialItems(player, spec)
    if not materials then result(player, "repair", false, "materials", object); return end
    for i = 1, #materials do
        if not removeItem(materials[i]) then result(player, "repair", false, "inventory_error", object); return end
    end
    if not ComputerModComponents.repair(data, part.id, level) then result(player, "repair", false, "not_repairable", object); return end
    awardElectricalXp(player, tonumber(spec.xp) or 8)
    ComputerModComputerTypes.transmitData(object)
    result(player, "repair", true, nil, object)
end

function ComputerModComponentsServer.setCondition(player, args)
    local object, reason = validate(player, args, false)
    if reason and reason ~= "powered_on" then result(player, "condition", false, reason, object); return end
    if not ComputerModDebug.isEnabled(player) then result(player, "condition", false, "not_authorized", object); return end
    local data = ComputerModComputerTypes.getData(object)
    if not ComputerModComponents.setCondition(data, args.partId, args.condition) then result(player, "condition", false, "missing_part", object); return end
    ComputerModComponents.captureDriveData(data)
    ComputerModComputerTypes.transmitData(object)
    result(player, "condition", true, nil, object)
end

function ComputerModComponentsServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModComponents" then return end
    if command == "Install" then ComputerModComponentsServer.install(player, args)
    elseif command == "Remove" then ComputerModComponentsServer.remove(player, args)
    elseif command == "Repair" then ComputerModComponentsServer.repair(player, args)
    elseif command == "SetCondition" then ComputerModComponentsServer.setCondition(player, args) end
end

Events.OnClientCommand.Add(ComputerModComponentsServer.onClientCommand)
