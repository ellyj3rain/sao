-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Shared inventory and world-item helper utilities.
NMInventoryHelpers = NMInventoryHelpers or {}

local function logVehicleSlotTrace(stage, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot")) then
        return
    end
    NMCore.logChannel("slot", tostring(stage or "vehicle_slot_trace"), tostring(detail or ""))
end

local function shouldTraceVehicleSlot(context)
    return type(context) == "table" and tostring(context.host or "") == "vehicle"
end

function NMInventoryHelpers.collectItemsRecursive(container, out)
    if not container or not container.getItems then return end
    local items = container:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        out[#out + 1] = item
        if item and item.IsInventoryContainer and item:IsInventoryContainer() then
            local sub = item:getInventory()
            if sub then
                NMInventoryHelpers.collectItemsRecursive(sub, out)
            end
        end
    end
end

function NMInventoryHelpers.findItemById(container, itemId)
    if not container or not itemId then return nil end
    local items = container:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getID and tostring(item:getID()) == tostring(itemId) then
            return item
        end
        if item and item.IsInventoryContainer and item:IsInventoryContainer() then
            local found = NMInventoryHelpers.findItemById(item:getInventory(), itemId)
            if found then return found end
        end
    end
    return nil
end

function NMInventoryHelpers.isItemWithinInventoryTree(rootInventory, item)
    if not (rootInventory and item and item.getID) then
        return false
    end
    local targetId = tostring(item:getID() or "")
    if targetId == "" then
        return false
    end
    local found = NMInventoryHelpers.findItemById(rootInventory, targetId)
    return found ~= nil
end

function NMInventoryHelpers.findDirectItemById(container, itemId)
    if not container or not itemId then return nil end
    local items = container.getItems and container:getItems() or nil
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getID and tostring(item:getID()) == tostring(itemId) then
            return item
        end
    end
    return nil
end

function NMInventoryHelpers.getProfileRuntimeNumber(key, defaultValue)
    local getter = NMDeviceProfiles and NMDeviceProfiles[key] or nil
    if type(getter) ~= "function" then return defaultValue end
    local ok, value = pcall(getter)
    if not ok then return defaultValue end
    local num = tonumber(value)
    if num == nil then return defaultValue end
    return num
end

function NMInventoryHelpers.getItemIdString(item)
    if not item or not item.getID then return "" end
    return tostring(item:getID() or "")
end

function NMInventoryHelpers.getItemUuidString(item)
    if not item then return "" end
    if NMDeviceRegistry and NMDeviceRegistry.get then
        local ok, uuid = pcall(NMDeviceRegistry.get, item)
        if ok and uuid ~= nil and tostring(uuid) ~= "" then
            return tostring(uuid)
        end
    end
    return ""
end

function NMInventoryHelpers.getItemStateUuid(item)
    if not (item and item.getModData and NMCore and NMCore.StateKey) then
        return ""
    end
    local md = item:getModData()
    local state = md and md[NMCore.StateKey] or nil
    local uuid = state and state.deviceUUID or nil
    if uuid ~= nil and tostring(uuid) ~= "" then
        return tostring(uuid)
    end
    return NMInventoryHelpers.getItemUuidString(item)
end

local function readContainerType(container)
    if not (container and container.getType) then
        return ""
    end
    return tostring(container:getType() or "")
end

local function resolveVehicleFromSquare(square)
    if not square then
        return nil
    end
    local vehicle = square.getVehicleContainer and square:getVehicleContainer() or nil
    if vehicle then
        return vehicle
    end
    return square.getVehicle and square:getVehicle() or nil
end

local function getGridSquareKey(square)
    if not square then
        return nil
    end
    return table.concat({
        tostring(square:getX() or ""),
        tostring(square:getY() or ""),
        tostring(square:getZ() or "")
    }, ":")
end

local function getExactSquare(player, x, y, z)
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end
    local sx = tonumber(x)
    local sy = tonumber(y)
    local sz = tonumber(z)
    if sx == nil or sy == nil or sz == nil then
        return nil
    end
    return cell:getGridSquare(sx, sy, sz)
end

local function resolveWorldItemSquare(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    return worldItem and worldItem.getSquare and worldItem:getSquare() or nil
end

local function isIsoDeadBody(obj)
    return obj and instanceof and instanceof(obj, "IsoDeadBody")
end

function NMInventoryHelpers.squareHasGridOrGeneratorPower(square)
    if not square then return false end
    if square.haveElectricity and square:haveElectricity() then return true end
    if square.hasGridPower and square:hasGridPower() and square.getRoom and square:getRoom() then
        return true
    end
    return false
end

function NMInventoryHelpers.resolveExternalPowerAvailable(player, item, profile)
    if not NMDeviceProfiles.requiresExternalPower(profile) then
        return true
    end
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    if not square then return false end
    return NMInventoryHelpers.squareHasGridOrGeneratorPower(square)
end

local function shouldLogBasementWorldLookup()
    return NMCore
        and NMCore.logChannel
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled("runtime")
end

local function logBasementWorldLookup(tag, detail)
    if shouldLogBasementWorldLookup() then
        NMCore.logChannel("runtime", tostring(tag or "world_lookup"), tostring(detail or ""))
    end
end

local function resolveWorldLookupZBounds(pz, floors)
    local minZ = pz - floors
    local maxZ = pz + floors
    if getMaximumWorldLevel then
        local worldMax = tonumber(getMaximumWorldLevel())
        if worldMax ~= nil and maxZ > worldMax then
            maxZ = worldMax
        end
    end
    return minZ, maxZ
end

local function logBasementLookupBounds(kind, target, px, py, pz, radius, floors, minZ, maxZ)
    if tonumber(pz) == nil or tonumber(pz) >= 0 then
        return
    end
    logBasementWorldLookup(
        "world_lookup_basement_bounds",
        string.format(
            "kind=%s target=%s px=%s py=%s pz=%s radius=%s floors=%s minZ=%s maxZ=%s",
            tostring(kind or "unknown"),
            tostring(target or ""),
            tostring(px),
            tostring(py),
            tostring(pz),
            tostring(radius),
            tostring(floors),
            tostring(minZ),
            tostring(maxZ)
        )
    )
end

local function logBasementLookupResult(kind, target, pz, found, x, y, z)
    if tonumber(pz) == nil or tonumber(pz) >= 0 then
        return
    end
    local tag = found and "world_lookup_basement_hit" or "world_lookup_basement_miss"
    logBasementWorldLookup(
        tag,
        string.format(
            "kind=%s target=%s playerZ=%s found=%s x=%s y=%s z=%s",
            tostring(kind or "unknown"),
            tostring(target or ""),
            tostring(pz),
            tostring(found == true),
            tostring(x or "nil"),
            tostring(y or "nil"),
            tostring(z or "nil")
        )
    )
end

function NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, radius, floors)
    if not player or not itemId then return nil end
    local sq = player.getSquare and player:getSquare() or nil
    if not sq then return nil end
    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local r = radius or 4
    local f = math.max(0, math.floor(tonumber(floors) or 0))
    local minZ, maxZ = resolveWorldLookupZBounds(pz, f)
    logBasementLookupBounds("id", itemId, px, py, pz, r, f, minZ, maxZ)

    for x = px - r, px + r do
        for y = py - r, py + r do
            for z = minZ, maxZ do
                local grid = cell:getGridSquare(x, y, z)
                if grid and grid.getWorldObjects then
                    local objs = grid:getWorldObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            local item = obj and obj.getItem and obj:getItem() or nil
                            if item and item.getID and tostring(item:getID()) == tostring(itemId) then
                                logBasementLookupResult("id", itemId, pz, true, x, y, z)
                                return item
                            end
                        end
                    end
                end
            end
        end
    end
    logBasementLookupResult("id", itemId, pz, false)
    return nil
end

function NMInventoryHelpers.findItemByUuid(container, uuid)
    local target = tostring(uuid or "")
    if not container or target == "" then return nil end
    local items = container:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local itemUuid = NMInventoryHelpers.getItemStateUuid(item)
            if itemUuid ~= "" and itemUuid == target then
                return item
            end
        end
        if item and item.IsInventoryContainer and item:IsInventoryContainer() then
            local found = NMInventoryHelpers.findItemByUuid(item:getInventory(), target)
            if found then return found end
        end
    end
    return nil
end

function NMInventoryHelpers.findDirectItemByUuid(container, uuid)
    local target = tostring(uuid or "")
    if not container or target == "" then return nil end
    local items = container.getItems and container:getItems() or nil
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local itemUuid = NMInventoryHelpers.getItemStateUuid(item)
            if itemUuid ~= "" and itemUuid == target then
                return item
            end
        end
    end
    return nil
end

function NMInventoryHelpers.resolveItemByIdOrUuid(container, itemId, uuid)
    local targetUuid = tostring(uuid or "")
    local targetId = tostring(itemId or "")
    if targetUuid ~= "" then
        local byUuid = NMInventoryHelpers.findItemByUuid(container, targetUuid)
        if byUuid then
            return byUuid
        end
    end
    if targetId ~= "" then
        return NMInventoryHelpers.findItemById(container, targetId)
    end
    return nil
end

local function addInventoryCandidate(out, seen, inventory)
    if not inventory or type(out) ~= "table" or type(seen) ~= "table" then
        return
    end
    if seen[inventory] == true then
        return
    end
    seen[inventory] = true
    out[#out + 1] = inventory
end

local function collectClientOpenLootInventories(player, out, seen)
    if not (player and getPlayerLoot) then
        return
    end
    local playerNum = player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    if playerNum == nil then
        return
    end
    local lootPage = getPlayerLoot(playerNum)
    if not lootPage then
        return
    end
    local backpacks = type(lootPage.backpacks) == "table" and lootPage.backpacks or nil
    if not backpacks then
        return
    end
    for i = 1, #backpacks do
        local button = backpacks[i]
        local inventory = button and button.inventory or nil
        addInventoryCandidate(out, seen, inventory)
    end
end

local function isOpenLootInventory(player, inventory)
    if not (player and inventory and getPlayerLoot) then
        return false
    end
    local playerNum = player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    if playerNum == nil then
        return false
    end
    local lootPage = getPlayerLoot(playerNum)
    local backpacks = lootPage and type(lootPage.backpacks) == "table" and lootPage.backpacks or nil
    if not backpacks then
        return false
    end
    for i = 1, #backpacks do
        local button = backpacks[i]
        if button and button.inventory == inventory then
            return true
        end
    end
    return false
end

local function collectNearbyVehicleInventories(player, out, seen)
    if not (player and NMVehiclePoolAccessor and NMVehiclePoolAccessor.collect) then
        return
    end
    local sq = player.getSquare and player:getSquare() or nil
    if not sq then
        return
    end
    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local probe = NMVehiclePoolAccessor.collect(128, {})
    local vehicles = probe and probe._vehicles or nil
    if type(vehicles) ~= "table" then
        return
    end
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle and vehicle.getX and vehicle.getY and vehicle.getZ then
            local vx = tonumber(vehicle:getX()) or px
            local vy = tonumber(vehicle:getY()) or py
            local vz = tonumber(vehicle:getZ()) or pz
            local dx = vx - px
            local dy = vy - py
            local dz = math.abs(vz - pz)
            if ((dx * dx) + (dy * dy)) <= 25 and dz <= 2 then
                local partCount = vehicle.getPartCount and tonumber(vehicle:getPartCount()) or 0
                for partIndex = 0, partCount - 1 do
                    local part = vehicle.getPartByIndex and vehicle:getPartByIndex(partIndex) or nil
                    local inventory = part and part.getItemContainer and part:getItemContainer() or nil
                    addInventoryCandidate(out, seen, inventory)
                end
            end
        end
    end
end

local function resolveVehiclePartByTypeOnVehicle(vehicle, containerType, container)
    if not vehicle then
        return nil
    end
    local targetType = tostring(containerType or readContainerType(container) or "")
    local exactPart = nil
    local fallbackPart = nil
    local partCount = vehicle.getPartCount and tonumber(vehicle:getPartCount()) or 0
    for partIndex = 0, partCount - 1 do
        local part = vehicle.getPartByIndex and vehicle:getPartByIndex(partIndex) or nil
        local partInventory = part and part.getItemContainer and part:getItemContainer() or nil
        if partInventory then
            if partInventory == container then
                return part
            end
            if targetType ~= "" and readContainerType(partInventory) == targetType then
                if fallbackPart then
                    return nil
                end
                fallbackPart = part
            end
        end
    end
    return exactPart or fallbackPart
end

local function resolveExactVehiclePartOnVehicle(vehicle, container)
    if not vehicle then
        return nil
    end
    local partCount = vehicle.getPartCount and tonumber(vehicle:getPartCount()) or 0
    for partIndex = 0, partCount - 1 do
        local part = vehicle.getPartByIndex and vehicle:getPartByIndex(partIndex) or nil
        local partInventory = part and part.getItemContainer and part:getItemContainer() or nil
        if partInventory == container then
            return part
        end
    end
    return nil
end

local function resolveVehiclePartByTypeOnNearbyVehicles(player, container)
    if not (player and container and NMVehiclePoolAccessor and NMVehiclePoolAccessor.collect) then
        return nil, nil
    end
    local probe = NMVehiclePoolAccessor.collect(128, {})
    local vehicles = probe and probe._vehicles or nil
    if type(vehicles) ~= "table" then
        return nil, nil
    end
    local fallbackVehicle = nil
    local fallbackPart = nil
    local targetType = readContainerType(container)
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local matchedPart = resolveVehiclePartByTypeOnVehicle(vehicle, targetType, container)
        if matchedPart then
            if matchedPart.getItemContainer and matchedPart:getItemContainer() == container then
                return vehicle, matchedPart
            end
            if fallbackPart then
                return nil, nil
            end
            fallbackVehicle = vehicle
            fallbackPart = matchedPart
        end
    end
    return fallbackVehicle, fallbackPart
end

local function resolveOpenLootVehiclePartByContainer(player, container, opts)
    if not (player and container and getPlayerLoot) then
        return nil, nil
    end
    local playerNum = player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    if playerNum == nil then
        return nil, nil
    end
    local lootPage = getPlayerLoot(playerNum)
    local backpacks = lootPage and type(lootPage.backpacks) == "table" and lootPage.backpacks or nil
    if not backpacks then
        return nil, nil
    end
    for i = 1, #backpacks do
        local button = backpacks[i]
        if button and button.inventory == container then
            local part = button.vehiclePart or button.part or nil
            local vehicle = button.vehicle or nil
            if not vehicle and part and part.getVehicle then
                vehicle = part:getVehicle()
            end
            if part then
                return vehicle, part
            end
            if vehicle and opts and opts.allowTypeFallback == true then
                local matchedPart = resolveVehiclePartByTypeOnVehicle(vehicle, readContainerType(container), container)
                if matchedPart then
                    return vehicle, matchedPart
                end
            end
            return nil, nil
        end
    end
    return nil, nil
end

local function collectNearbyWorldInventories(player, out, seen)
    local sq = player and player.getSquare and player:getSquare() or nil
    local cell = getCell and getCell() or nil
    if not (sq and cell) then
        return
    end
    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local radius = 3
    for x = px - radius, px + radius do
        for y = py - radius, py + radius do
            for z = pz - 1, pz + 1 do
                local grid = cell:getGridSquare(x, y, z)
                if grid then
                    local objects = grid.getObjects and grid:getObjects() or nil
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            local inventory = obj and obj.getContainer and obj:getContainer() or nil
                            addInventoryCandidate(out, seen, inventory)
                        end
                    end
                    local worldObjects = grid.getWorldObjects and grid:getWorldObjects() or nil
                    if worldObjects then
                        for i = 0, worldObjects:size() - 1 do
                            local worldObj = worldObjects:get(i)
                            local item = worldObj and worldObj.getItem and worldObj:getItem() or nil
                            local inventory = item and item.IsInventoryContainer and item:IsInventoryContainer() and item:getInventory() or nil
                            addInventoryCandidate(out, seen, inventory)
                        end
                    end
                    local deadBodies = grid.getDeadBodys and grid:getDeadBodys() or nil
                    if deadBodies then
                        for i = 0, deadBodies:size() - 1 do
                            local body = deadBodies:get(i)
                            local inventory = body and body.getContainer and body:getContainer() or nil
                            addInventoryCandidate(out, seen, inventory)
                        end
                    end
                end
            end
        end
    end
end

function NMInventoryHelpers.collectAccessibleSourceInventories(player)
    local out, seen = {}, {}
    local inv = player and player.getInventory and player:getInventory() or nil
    addInventoryCandidate(out, seen, inv)
    collectClientOpenLootInventories(player, out, seen)
    collectNearbyVehicleInventories(player, out, seen)
    collectNearbyWorldInventories(player, out, seen)
    return out
end

function NMInventoryHelpers.collectVisibleUiSourceInventories(player)
    local out, seen = {}, {}
    local inv = player and player.getInventory and player:getInventory() or nil
    addInventoryCandidate(out, seen, inv)
    collectClientOpenLootInventories(player, out, seen)
    return out
end

local function resolveVehiclePartByContainer(player, container, opts)
    if not (player and container and NMVehiclePoolAccessor and NMVehiclePoolAccessor.collect) then
        return nil, nil
    end
    opts = opts or {}
    local allowTypeFallback = opts.allowTypeFallback == true

    local openLootVehicle, openLootPart = resolveOpenLootVehiclePartByContainer(player, container, opts)
    if openLootVehicle and openLootPart then
        return openLootVehicle, openLootPart
    end

    local parent = container.getParent and container:getParent() or nil
    local parentSquare = parent and parent.getSquare and parent:getSquare() or nil
    local squareVehicle = resolveVehicleFromSquare(parentSquare)
    if squareVehicle then
        local matchedPart = resolveExactVehiclePartOnVehicle(squareVehicle, container)
        if not matchedPart and allowTypeFallback then
            matchedPart = resolveVehiclePartByTypeOnVehicle(squareVehicle, readContainerType(container), container)
        end
        if matchedPart then
            return squareVehicle, matchedPart
        end
    end

    local exactVehicle, exactPart = resolveVehiclePartByTypeOnNearbyVehicles(player, container)
    if exactVehicle and exactPart and exactPart.getItemContainer and exactPart:getItemContainer() == container then
        return exactVehicle, exactPart
    end
    if allowTypeFallback then
        return exactVehicle, exactPart
    end
    return nil, nil
end

function NMInventoryHelpers.resolveVehiclePartByContainer(player, container, opts)
    return resolveVehiclePartByContainer(player, container, opts)
end

local function findObjectIndexForContainer(square, container)
    local objects = square and square.getObjects and square:getObjects() or nil
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getContainer and obj:getContainer() == container then
            return i
        end
    end
    return nil
end

local function findDeadBodyIndexForContainer(square, container)
    local deadBodies = square and square.getDeadBodys and square:getDeadBodys() or nil
    if not deadBodies then
        return nil
    end
    for i = 0, deadBodies:size() - 1 do
        local body = deadBodies:get(i)
        if body and body.getContainer and body:getContainer() == container then
            return i
        end
    end
    return nil
end

function NMInventoryHelpers.writeSourceDescriptorToArgs(args, prefix, descriptor)
    if type(args) ~= "table" or type(descriptor) ~= "table" then
        return
    end
    local base = tostring(prefix or "mediaSource")
    args[base .. "Kind"] = tostring(descriptor.kind or "")
    args[base .. "UiRole"] = tostring(descriptor.uiRole or "")
    args[base .. "ContainerType"] = tostring(descriptor.containerType or "")
    args[base .. "ItemId"] = tostring(descriptor.itemId or "")
    args[base .. "ItemUuid"] = tostring(descriptor.itemUuid or "")
    args[base .. "VehicleId"] = tostring(descriptor.vehicleId or "")
    args[base .. "PartId"] = tostring(descriptor.partId or "")
    args[base .. "ParentItemId"] = tostring(descriptor.parentItemId or "")
    args[base .. "ParentItemUuid"] = tostring(descriptor.parentItemUuid or "")
    args[base .. "SquareX"] = descriptor.squareX
    args[base .. "SquareY"] = descriptor.squareY
    args[base .. "SquareZ"] = descriptor.squareZ
    args[base .. "ObjectIndex"] = descriptor.objectIndex
    args[base .. "DeadBodyIndex"] = descriptor.deadBodyIndex
end

function NMInventoryHelpers.readSourceDescriptorFromArgs(args, prefix)
    if type(args) ~= "table" then
        return nil
    end
    local base = tostring(prefix or "mediaSource")
    local kind = tostring(args[base .. "Kind"] or "")
    if kind == "" then
        return nil
    end
    return {
        kind = kind,
        uiRole = tostring(args[base .. "UiRole"] or ""),
        containerType = tostring(args[base .. "ContainerType"] or ""),
        itemId = tostring(args[base .. "ItemId"] or ""),
        itemUuid = tostring(args[base .. "ItemUuid"] or ""),
        vehicleId = tostring(args[base .. "VehicleId"] or ""),
        partId = tostring(args[base .. "PartId"] or ""),
        parentItemId = tostring(args[base .. "ParentItemId"] or ""),
        parentItemUuid = tostring(args[base .. "ParentItemUuid"] or ""),
        squareX = args[base .. "SquareX"],
        squareY = args[base .. "SquareY"],
        squareZ = args[base .. "SquareZ"],
        objectIndex = args[base .. "ObjectIndex"],
        deadBodyIndex = args[base .. "DeadBodyIndex"]
    }
end

function NMInventoryHelpers.describeAccessibleItemSource(player, item, traceContext)
    local container = item and item.getContainer and item:getContainer() or nil
    local inv = player and player.getInventory and player:getInventory() or nil
    if not (item and container and inv) then
        if shouldTraceVehicleSlot(traceContext) then
            logVehicleSlotTrace(
                "vehicle_slot_descriptor_build",
                string.format(
                    "trace=%s stage=descriptor_build result=reject reason=missing_source_context itemId=%s itemUuid=%s",
                    tostring(traceContext and traceContext.slotTraceId or ""),
                    tostring(item and NMInventoryHelpers.getItemIdString and NMInventoryHelpers.getItemIdString(item) or ""),
                    tostring(item and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or "")
                )
            )
        end
        return nil, "missing_source_context"
    end

    local descriptor = {
        itemId = NMInventoryHelpers.getItemIdString(item),
        itemUuid = NMInventoryHelpers.getItemStateUuid(item),
        containerType = readContainerType(container),
        uiRole = isOpenLootInventory(player, container) and "loot_inventory" or ""
    }

    if container == inv then
        descriptor.kind = "player_inventory"
        if descriptor.uiRole == "" then
            descriptor.uiRole = "player_inventory"
        end
        return descriptor
    end

    local vehicle, part = resolveVehiclePartByContainer(player, container, {
        allowTypeFallback = false
    })
    if vehicle and part then
        descriptor.kind = "vehicle_part_container"
        descriptor.vehicleId = tostring(vehicle.getId and vehicle:getId() or "")
        descriptor.partId = tostring(part.getId and part:getId() or "")
        return descriptor
    end

    local containingItem = container.getContainingItem and container:getContainingItem() or nil
    if containingItem and containingItem.getID then
        descriptor.kind = "inventory_container_item"
        descriptor.parentItemId = NMInventoryHelpers.getItemIdString(containingItem)
        descriptor.parentItemUuid = NMInventoryHelpers.getItemStateUuid(containingItem)
        local square = resolveWorldItemSquare(containingItem)
        if square then
            descriptor.squareX = square:getX()
            descriptor.squareY = square:getY()
            descriptor.squareZ = square:getZ()
        end
        return descriptor
    end

    local parent = container.getParent and container:getParent() or nil
    local square = parent and parent.getSquare and parent:getSquare() or nil
    if isIsoDeadBody(parent) and square then
        descriptor.kind = "corpse_container"
        descriptor.squareX = square:getX()
        descriptor.squareY = square:getY()
        descriptor.squareZ = square:getZ()
        descriptor.deadBodyIndex = findDeadBodyIndexForContainer(square, container)
        return descriptor
    end

    if parent and square then
        descriptor.kind = "world_object_container"
        descriptor.squareX = square:getX()
        descriptor.squareY = square:getY()
        descriptor.squareZ = square:getZ()
        descriptor.objectIndex = findObjectIndexForContainer(square, container)
        return descriptor
    end

    descriptor.kind = "loot_inventory"
    return descriptor
end

local function findWorldObjectItemOnSquare(square, itemId, uuid)
    local targetItemId = tostring(itemId or "")
    local targetUuid = tostring(uuid or "")
    local worldObjects = square and square.getWorldObjects and square:getWorldObjects() or nil
    if not worldObjects then
        return nil
    end
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        local item = worldObj and worldObj.getItem and worldObj:getItem() or nil
        if item then
            local itemUuid = NMInventoryHelpers.getItemStateUuid(item)
            if targetUuid ~= "" and itemUuid == targetUuid then
                return item
            end
            if targetItemId ~= "" and tostring(item.getID and item:getID() or "") == targetItemId then
                return item
            end
        end
    end
    return nil
end

local function resolveInventoryContainerParentFromDescriptor(player, descriptor)
    local parent = NMInventoryHelpers.findAccessibleItemByIdOrUuid(player, descriptor.parentItemId, descriptor.parentItemUuid)
    if parent and parent.IsInventoryContainer and parent:IsInventoryContainer() then
        return parent
    end
    local square = getExactSquare(player, descriptor.squareX, descriptor.squareY, descriptor.squareZ)
    if square then
        local worldParent = findWorldObjectItemOnSquare(square, descriptor.parentItemId, descriptor.parentItemUuid)
        if worldParent and worldParent.IsInventoryContainer and worldParent:IsInventoryContainer() then
            return worldParent
        end
    end
    return nil
end

function NMInventoryHelpers.resolveAccessibleItemFromSourceDescriptor(player, descriptor, traceContext)
    local source = type(descriptor) == "table" and descriptor or nil
    if not (player and source) then
        if shouldTraceVehicleSlot(traceContext) then
            logVehicleSlotTrace(
                "vehicle_slot_source_resolve",
                string.format(
                    "trace=%s stage=source_resolve result=reject reason=missing_source_descriptor",
                    tostring(traceContext and traceContext.slotTraceId or "")
                )
            )
        end
        return nil, nil, "missing_source_descriptor"
    end

    local sourceContainer = nil
    local kind = tostring(source.kind or "")
    if kind == "player_inventory" then
        sourceContainer = player.getInventory and player:getInventory() or nil
    elseif kind == "vehicle_part_container" then
        local vehicleId = tonumber(source.vehicleId)
        local vehicle = vehicleId ~= nil and getVehicleById and getVehicleById(vehicleId) or nil
        local part = vehicle and vehicle.getPartById and vehicle:getPartById(tostring(source.partId or "")) or nil
        sourceContainer = part and part.getItemContainer and part:getItemContainer() or nil
    elseif kind == "world_object_container" then
        local square = getExactSquare(player, source.squareX, source.squareY, source.squareZ)
        local index = tonumber(source.objectIndex)
        local objects = square and square.getObjects and square:getObjects() or nil
        local obj = objects and index ~= nil and index >= 0 and index < objects:size() and objects:get(index) or nil
        sourceContainer = obj and obj.getContainer and obj:getContainer() or nil
    elseif kind == "corpse_container" then
        local square = getExactSquare(player, source.squareX, source.squareY, source.squareZ)
        local index = tonumber(source.deadBodyIndex)
        local deadBodies = square and square.getDeadBodys and square:getDeadBodys() or nil
        local body = deadBodies and index ~= nil and index >= 0 and index < deadBodies:size() and deadBodies:get(index) or nil
        sourceContainer = body and body.getContainer and body:getContainer() or nil
    elseif kind == "inventory_container_item" then
        local parent = resolveInventoryContainerParentFromDescriptor(player, source)
        sourceContainer = parent and parent.getInventory and parent:getInventory() or nil
    end

    if not sourceContainer then
        if shouldTraceVehicleSlot(traceContext) then
            logVehicleSlotTrace(
                "vehicle_slot_source_resolve",
                string.format(
                    "trace=%s stage=source_resolve result=reject kind=%s reason=source_container_unresolved vehicleId=%s partId=%s containerType=%s itemId=%s itemUuid=%s",
                    tostring(traceContext and traceContext.slotTraceId or ""),
                    tostring(kind or ""),
                    tostring(source.vehicleId or ""),
                    tostring(source.partId or ""),
                    tostring(source.containerType or ""),
                    tostring(source.itemId or ""),
                    tostring(source.itemUuid or "")
                )
            )
        end
        return nil, nil, "source_container_unresolved"
    end

    local item = NMInventoryHelpers.resolveItemByIdOrUuid(sourceContainer, source.itemId, source.itemUuid)
    if not item then
        if shouldTraceVehicleSlot(traceContext) then
            logVehicleSlotTrace(
                "vehicle_slot_source_resolve",
                string.format(
                    "trace=%s stage=source_resolve result=reject kind=%s reason=source_item_missing vehicleId=%s partId=%s containerType=%s itemId=%s itemUuid=%s",
                    tostring(traceContext and traceContext.slotTraceId or ""),
                    tostring(kind or ""),
                    tostring(source.vehicleId or ""),
                    tostring(source.partId or ""),
                    tostring(source.containerType or ""),
                    tostring(source.itemId or ""),
                    tostring(source.itemUuid or "")
                )
            )
        end
        return nil, sourceContainer, "source_item_missing"
    end

    if shouldTraceVehicleSlot(traceContext) then
        logVehicleSlotTrace(
            "vehicle_slot_source_resolve",
            string.format(
                "trace=%s stage=source_resolve result=ok kind=%s vehicleId=%s partId=%s containerType=%s itemId=%s itemUuid=%s liveItemId=%s liveItemUuid=%s fullType=%s",
                tostring(traceContext and traceContext.slotTraceId or ""),
                tostring(kind or ""),
                tostring(source.vehicleId or ""),
                tostring(source.partId or ""),
                tostring(source.containerType or ""),
                tostring(source.itemId or ""),
                tostring(source.itemUuid or ""),
                tostring(NMInventoryHelpers.getItemIdString(item) or ""),
                tostring(NMInventoryHelpers.getItemStateUuid(item) or ""),
                tostring(item and item.getFullType and item:getFullType() or "")
            )
        )
    end
    return item, sourceContainer, nil
end

function NMInventoryHelpers.findAccessibleItemByIdOrUuid(player, itemId, uuid, liveItem)
    if liveItem and liveItem.getID then
        return liveItem
    end
    local inventories = NMInventoryHelpers.collectAccessibleSourceInventories(player)
    local targetUuid = tostring(uuid or "")
    local targetId = tostring(itemId or "")
    for i = 1, #inventories do
        local inventory = inventories[i]
        local found = NMInventoryHelpers.resolveItemByIdOrUuid(inventory, targetId, targetUuid)
        if found then
            return found
        end
    end
    return nil
end

local function moveResolvedItemToMainInventory(player, inventory, item)
    if not (player and inventory and item) then
        return nil, "missing_move_args", nil
    end
    if NMInventoryHelpers.isItemInRootInventory(inventory, item) then
        return item, nil, {
            moved = false,
            deferred = false,
            inventory = inventory,
            sourceContainer = inventory,
            targetContainer = inventory,
            sourceItem = item,
            targetItem = item,
            itemId = NMInventoryHelpers.getItemIdString(item),
            uuid = NMInventoryHelpers.getItemStateUuid(item)
        }
    end

    local sourceContainer = item.getContainer and item:getContainer() or nil
    if not (sourceContainer and sourceContainer.DoRemoveItem and inventory.AddItem) then
        return nil, "source_container_unsupported", nil
    end

    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() then
        return item, nil, {
            moved = false,
            deferred = true,
            inventory = inventory,
            sourceContainer = sourceContainer,
            targetContainer = inventory,
            sourceItem = item,
            targetItem = item,
            itemId = NMInventoryHelpers.getItemIdString(item),
            uuid = NMInventoryHelpers.getItemStateUuid(item)
        }
    end

    local targetId = NMInventoryHelpers.getItemIdString(item)
    local targetUuid = NMInventoryHelpers.getItemStateUuid(item)
    local removedOk = pcall(sourceContainer.DoRemoveItem, sourceContainer, item)
    if not removedOk then
        return nil, "source_remove_failed", nil
    end

    local addOk, addResult = pcall(inventory.AddItem, inventory, item)
    if not addOk then
        if sourceContainer.AddItem then
            pcall(sourceContainer.AddItem, sourceContainer, item)
        end
        return nil, "target_add_failed", nil
    end

    local liveItem = nil
    if addResult and addResult.getID then
        liveItem = addResult
    end
    if not liveItem then
        liveItem = NMInventoryHelpers.findDirectItemByUuid(inventory, targetUuid)
            or NMInventoryHelpers.findDirectItemById(inventory, targetId)
    end
    if not liveItem and NMInventoryHelpers.isItemInRootInventory(inventory, item) then
        liveItem = item
    end
    if not liveItem then
        return nil, "target_lookup_failed", nil
    end

    NMInventoryHelpers.refreshInventoryPagesForPlayer(player)
    return liveItem, nil, {
        moved = true,
        deferred = false,
        inventory = inventory,
        sourceContainer = sourceContainer,
        targetContainer = inventory,
        sourceItem = item,
        targetItem = liveItem,
        itemId = NMInventoryHelpers.getItemIdString(liveItem),
        uuid = NMInventoryHelpers.getItemStateUuid(liveItem)
    }
end

function NMInventoryHelpers.normalizeExplicitItemToMainInventory(player, item)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then
        return nil, "missing_inventory", nil
    end
    if not item then
        return nil, "source_item_not_found", nil
    end
    return moveResolvedItemToMainInventory(player, inventory, item)
end

function NMInventoryHelpers.isItemInRootInventory(inventory, item)
    if not (inventory and item) then return false end
    local container = item.getContainer and item:getContainer() or nil
    return container == inventory
end

function NMInventoryHelpers.refreshInventoryPagesForPlayer(player)
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    if playerNum == nil then
        return
    end
    if getPlayerInventory then
        local invPage = getPlayerInventory(playerNum)
        if invPage and invPage.refreshBackpacks then
            pcall(invPage.refreshBackpacks, invPage)
        end
    end
    if getPlayerLoot then
        local lootPage = getPlayerLoot(playerNum)
        if lootPage and lootPage.refreshBackpacks then
            pcall(lootPage.refreshBackpacks, lootPage)
        end
    end
    if ISInventoryPage then
        ISInventoryPage.renderDirty = true
    end
end

function NMInventoryHelpers.normalizeItemToMainInventory(player, itemId, uuid, liveItem)
    local inv = player and player.getInventory and player:getInventory() or nil
    local targetId = tostring(itemId or "")
    local targetUuid = tostring(uuid or "")
    if not inv then
        return nil, "missing_inventory", nil
    end

    local item = NMInventoryHelpers.findAccessibleItemByIdOrUuid(player, targetId, targetUuid, liveItem)
    if not item then
        return nil, "source_item_not_found", nil
    end
    return moveResolvedItemToMainInventory(player, inv, item)
end

function NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, radius, floors)
    local target = tostring(uuid or "")
    if not player or target == "" then return nil end
    local sq = player.getSquare and player:getSquare() or nil
    if not sq then return nil end
    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local r = radius or 4
    local f = math.max(0, math.floor(tonumber(floors) or 0))
    local minZ, maxZ = resolveWorldLookupZBounds(pz, f)
    logBasementLookupBounds("uuid", target, px, py, pz, r, f, minZ, maxZ)

    for x = px - r, px + r do
        for y = py - r, py + r do
            for z = minZ, maxZ do
                local grid = cell:getGridSquare(x, y, z)
                if grid and grid.getWorldObjects then
                    local objs = grid:getWorldObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            local item = obj and obj.getItem and obj:getItem() or nil
                            if item then
                                local itemUuid = NMInventoryHelpers.getItemStateUuid(item)
                                if itemUuid ~= "" and itemUuid == target then
                                    logBasementLookupResult("uuid", target, pz, true, x, y, z)
                                    return item
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    logBasementLookupResult("uuid", target, pz, false)
    return nil
end

