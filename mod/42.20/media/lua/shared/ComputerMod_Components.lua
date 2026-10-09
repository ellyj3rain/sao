-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_Sandbox"
require "ComputerMod_ComputerTypes"

ComputerModComponents = ComputerModComponents or {}

ComputerModComponents.version = 1
ComputerModComponents.parts = {
    {id = "motherboard", itemType = "ComputerMod.Motherboard486", nameKey = "ItemName_ComputerMod.Motherboard486", fallback = "486 Motherboard", wearPerHour = 0.025,
        repair = {level = 5, amount = 38, cap = 90, time = 520, xp = 12, materials = {{type = "Base.ElectronicsScrap", count = 2}, {type = "Base.ElectricWire", count = 1}}}},
    {id = "cpu", itemType = "ComputerMod.CPU486DX2", nameKey = "ItemName_ComputerMod.CPU486DX2", fallback = "486DX2 Processor", wearPerHour = 0.035,
        repair = {level = 7, amount = 32, cap = 85, time = 650, xp = 16, materials = {{type = "Base.ElectronicsScrap", count = 3}, {type = "Base.RadioReceiver", count = 1}}}},
    {id = "ram", itemType = "ComputerMod.RAM72Pin", nameKey = "ItemName_ComputerMod.RAM72Pin", fallback = "72-pin RAM", wearPerHour = 0.018,
        repair = {level = 4, amount = 50, cap = 95, time = 390, xp = 9, materials = {{type = "Base.ElectronicsScrap", count = 1}}}},
    {id = "gpu", itemType = "ComputerMod.GPUVLBSVGA", nameKey = "ItemName_ComputerMod.GPUVLBSVGA", fallback = "VLB SVGA Card", wearPerHour = 0.030,
        repair = {level = 6, amount = 38, cap = 90, time = 560, xp = 14, materials = {{type = "Base.ElectronicsScrap", count = 2}, {type = "Base.ElectricWire", count = 1}}}},
    {id = "hardDrive", itemType = "ComputerMod.HDDIDE340MB", nameKey = "ItemName_ComputerMod.HDDIDE340MB", fallback = "340 MB IDE Hard Drive", wearPerHour = 0.045,
        repair = {level = 5, amount = 35, cap = 85, time = 540, xp = 13, materials = {{type = "Base.ElectronicsScrap", count = 2}, {type = "Base.Screws", count = 2}}}}
}

ComputerModComponents.driveFields = {
    "ComputerModMetaInitialized",
    "ComputerModFactoryReset",
    "ComputerModOSInstalled",
    "ComputerModPasswordEnabled",
    "ComputerModPassword",
    "ComputerModSessionUnlocked",
    "ComputerModHackLockUntil",
    "ComputerModUsername",
    "ComputerModAvatar",
    "ComputerModBackgroundPalette",
    "ComputerModMuteMusic",
    "ComputerModUse24HourClock",
    "ComputerModMonthFirstDate",
    "ComputerModTextSize",
    "ComputerModUIScale",
    "ComputerModInterfaceScale",
    "ComputerModBrowserAddress",
    "ComputerModFolders",
    "ComputerModUserFolders",
    "ComputerModFolderContents",
    "ComputerModFolderContentVersion",
    "ComputerModInstalledGames",
    "ComputerModDownloadedInstallers",
    "ComputerModDownloadedMagazines",
    "ComputerModDesktopFiles",
    "ComputerModDesktopLayout",
    "ComputerModDesktopNotes",
    "ComputerModHiddenDesktopItems",
    "ComputerModTrashEntries",
    "ComputerModNotepadText",
    "ComputerModNotepadInitialized",
    "ComputerModNotepadSeedRepairV1",
    "ComputerModNotesRevision",
    "ComputerModCalculatorDisplay",
    "ComputerModPaintFiles",
    "ComputerModPaintSession",
    "ComputerModPaintSpawnInitialized",
    "ComputerModMailSpawnInitialized",
    "ComputerModMailAddress",
    "ComputerModMailPassword",
    "ComputerModMailLoggedIn",
    "ComputerModMailSessionAddress",
    "ComputerModMailPlayerCreated",
    "ComputerModMailMessages",
    "ComputerModChatUsername",
    "ComputerModChatPassword",
    "ComputerModChatLoggedIn",
    "ComputerModChatSessionUser",
    "ComputerModMarketSessionUser",
    "ComputerModMarketMoney",
    "ComputerModMarketPurchases",
    "ComputerModMarketCompletedJobs",
    "ComputerModLastView",
    "ComputerModLastFolderName",
    "ComputerModLastInstaller",
    "ComputerModWindowMinimized",
    "ComputerModMinimizedWindows",
    "ComputerModActiveDownloadGame",
    "ComputerModActiveDownloadProgress",
    "ComputerModActiveDownloadLastWorldAge",
    "ComputerModActiveVideoDownloadId",
    "ComputerModActiveVideoDownloadProgress",
    "ComputerModActiveVideoDownloadLastWorldAge"
}

ComputerModComponents.byId = {}
ComputerModComponents.byItemType = {}
local function indexPart(part, index)
    part.index = index
    ComputerModComponents.byId[part.id] = part
    ComputerModComponents.byItemType[string.lower(part.itemType)] = part
end
for i = 1, #ComputerModComponents.parts do
    local part = ComputerModComponents.parts[i]
    indexPart(part, i)
end

local function copyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, nested in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" or keyType == "boolean" then
            local copy = copyValue(nested, seen)
            local copyType = type(copy)
            if copyType ~= "function" and copyType ~= "thread" and copyType ~= "userdata" then
                result[key] = copy
            end
        end
    end
    return result
end

local function hashText(value)
    local hash = 1469598103
    local text = tostring(value or "")
    for i = 1, string.len(text) do
        hash = (hash * 131 + string.byte(text, i)) % 2147483647
    end
    return hash
end

local function seededPercent(seed, salt)
    return hashText(tostring(seed or "computer") .. ":" .. tostring(salt or 0)) % 100
end

local function seededRange(seed, salt, minimum, maximum)
    local span = math.max(1, maximum - minimum + 1)
    return minimum + (hashText(tostring(seed or "computer") .. ":" .. tostring(salt or 0)) % span)
end

local function clampCondition(value)
    return math.max(0, math.min(100, tonumber(value or 0) or 0))
end

function ComputerModComponents.copyValue(value)
    return copyValue(value)
end

function ComputerModComponents.getPart(partId)
    return ComputerModComponents.byId[tostring(partId or "")]
end

function ComputerModComponents.getPartByItemType(fullType)
    return ComputerModComponents.byItemType[string.lower(tostring(fullType or ""))]
end

function ComputerModComponents.registerPart(part)
    if type(part) ~= "table" or not part.id or not part.itemType or ComputerModComponents.byId[part.id] then return nil end
    ComputerModComponents.parts[#ComputerModComponents.parts + 1] = part
    indexPart(part, #ComputerModComponents.parts)
    ComputerModComponents.version = ComputerModComponents.version + 1
    return part
end

function ComputerModComponents.isPartCompatible(part, data)
    part = type(part) == "table" and part or ComputerModComponents.getPart(part)
    if not part then return false end
    if type(part.computerTypes) ~= "table" then return true end
    local computerType = type(data) == "table" and tostring(data.ComputerModComputerType or "desktop") or "desktop"
    return part.computerTypes[computerType] == true
end

function ComputerModComponents.isPartRequired(part, data)
    part = type(part) == "table" and part or ComputerModComponents.getPart(part)
    return part ~= nil and part.required ~= false and ComputerModComponents.isPartCompatible(part, data)
end

function ComputerModComponents.getPartsForData(data)
    local result = {}
    for i = 1, #ComputerModComponents.parts do
        local part = ComputerModComponents.parts[i]
        if ComputerModComponents.isPartCompatible(part, data) then result[#result + 1] = part end
    end
    return result
end

function ComputerModComponents.getPartName(part)
    part = type(part) == "table" and part or ComputerModComponents.getPart(part)
    if not part then return "Computer part" end
    if getText then
        local ok, value = pcall(getText, part.nameKey)
        if ok and value and value ~= part.nameKey then return value end
    end
    return part.fallback
end

function ComputerModComponents.getWorldAgeHours()
    if not getGameTime then return 0 end
    local okTime, gameTime = pcall(getGameTime)
    if not okTime or not gameTime or not gameTime.getWorldAgeHours then return 0 end
    local okAge, age = pcall(function() return gameTime:getWorldAgeHours() end)
    return okAge and (tonumber(age or 0) or 0) or 0
end

function ComputerModComponents.makeDriveId(seed)
    local stamp = getTimestampMs and getTimestampMs() or 0
    local random = ZombRand and ZombRand(1000000) or hashText(seed)
    return "IDE-" .. tostring(hashText(tostring(seed or "drive") .. ":" .. tostring(stamp) .. ":" .. tostring(random)))
end

function ComputerModComponents.getComputerSeed(data, object)
    local machineId = data and tostring(data.ComputerModMachineID or "") or ""
    if machineId ~= "" then return machineId end
    local square = object and object.getSquare and object:getSquare() or nil
    if square then
        return tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
    end
    return "computer"
end

function ComputerModComponents.randomCondition(seed, partId)
    local part = ComputerModComponents.getPart(partId)
    local salt = part and part.index or 1
    local brokenChance = ComputerModSandbox.getPercent("FoundComputerBrokenPartChance")
    local badChance = ComputerModSandbox.getPercent("FoundComputerBadPartChance")
    if seededPercent(seed, salt * 17) < brokenChance then return 0 end
    if seededPercent(seed, salt * 29) < badChance then
        return seededRange(seed, salt * 43, 28, 64)
    end
    return seededRange(seed, salt * 61, 72, 100)
end

function ComputerModComponents.newPartState(partId, condition, seed)
    local part = ComputerModComponents.getPart(partId)
    if not part then return nil end
    local state = {
        itemType = part.itemType,
        condition = clampCondition(condition),
        wearRemainder = 0
    }
    if part.id == "hardDrive" then
        state.driveId = ComputerModComponents.makeDriveId(seed)
        state.driveData = nil
        state.fresh = true
    end
    if type(part.initializeState) == "function" then pcall(part.initializeState, state, seed) end
    return state
end

function ComputerModComponents.captureDriveData(data)
    if type(data) ~= "table" or data.ComputerModNetworkTerminal == true then return nil end
    local components = type(data.ComputerModComponents) == "table" and data.ComputerModComponents or nil
    local hardDrive = components and components.hardDrive or nil
    if type(hardDrive) ~= "table" then return nil end
    if not hardDrive.driveId or hardDrive.driveId == "" then
        hardDrive.driveId = ComputerModComponents.makeDriveId(data.ComputerModMachineID)
    end
    local snapshot = {}
    for i = 1, #ComputerModComponents.driveFields do
        local key = ComputerModComponents.driveFields[i]
        if data[key] ~= nil then snapshot[key] = copyValue(data[key]) end
    end
    hardDrive.driveData = snapshot
    hardDrive.fresh = false
    data.ComputerModDriveID = hardDrive.driveId
    return snapshot
end

function ComputerModComponents.clearDriveData(data)
    if type(data) ~= "table" then return end
    for i = 1, #ComputerModComponents.driveFields do
        data[ComputerModComponents.driveFields[i]] = nil
    end
    data.ComputerModDriveID = nil
end

function ComputerModComponents.applyHardDriveData(data, hardDrive)
    if type(data) ~= "table" then return end
    ComputerModComponents.clearDriveData(data)
    if type(hardDrive) ~= "table" then return end
    if not hardDrive.driveId or hardDrive.driveId == "" then
        hardDrive.driveId = ComputerModComponents.makeDriveId(data.ComputerModMachineID)
    end
    data.ComputerModDriveID = hardDrive.driveId
    if hardDrive.fresh == true or type(hardDrive.driveData) ~= "table" then
        data.ComputerModMetaInitialized = nil
        return
    end
    for i = 1, #ComputerModComponents.driveFields do
        local key = ComputerModComponents.driveFields[i]
        if hardDrive.driveData[key] ~= nil then data[key] = copyValue(hardDrive.driveData[key]) end
    end
    data.ComputerModMetaInitialized = data.ComputerModMetaInitialized == true
end

function ComputerModComponents.ensure(data, seed, wasPreviouslyActivated, worldAgeHours)
    if type(data) ~= "table" or data.ComputerModNetworkTerminal == true then return false end
    local changed = false
    if type(data.ComputerModComponents) ~= "table" then
        data.ComputerModComponents = {}
        changed = true
    end
    local components = data.ComputerModComponents
    if data.ComputerModComponentsInitialized ~= true then
        for i = 1, #ComputerModComponents.parts do
            local part = ComputerModComponents.parts[i]
            if ComputerModComponents.isPartCompatible(part, data) then
                local condition = wasPreviouslyActivated == true and 100 or ComputerModComponents.randomCondition(seed, part.id)
                components[part.id] = ComputerModComponents.newPartState(part.id, condition, tostring(seed) .. ":" .. part.id)
            end
        end
        data.ComputerModComponentsInitialized = true
        data.ComputerModComponentsVersion = ComputerModComponents.version
        data.ComputerModComponentsLastWearHour = tonumber(worldAgeHours or 0) or 0
        changed = true
        if wasPreviouslyActivated == true then
            ComputerModComponents.captureDriveData(data)
        end
    else
        for i = 1, #ComputerModComponents.parts do
            local part = ComputerModComponents.parts[i]
            local state = ComputerModComponents.isPartCompatible(part, data) and components[part.id] or nil
            if type(state) == "table" then
                state.itemType = part.itemType
                state.condition = clampCondition(state.condition == nil and 100 or state.condition)
                state.wearRemainder = tonumber(state.wearRemainder or 0) or 0
                if part.id == "hardDrive" then
                    if not state.driveId or state.driveId == "" then
                        state.driveId = ComputerModComponents.makeDriveId(tostring(seed) .. ":hardDrive")
                        changed = true
                    end
                    data.ComputerModDriveID = state.driveId
                end
            end
        end
        data.ComputerModComponentsVersion = ComputerModComponents.version
        if data.ComputerModComponentsLastWearHour == nil then
            data.ComputerModComponentsLastWearHour = tonumber(worldAgeHours or 0) or 0
            changed = true
        end
    end
    return changed
end

function ComputerModComponents.applyWear(data, worldAgeHours)
    if type(data) ~= "table" or data.ComputerModNetworkTerminal == true then return false end
    if data.ComputerModComponentsInitialized ~= true or type(data.ComputerModComponents) ~= "table" then return false end
    local now = tonumber(worldAgeHours or 0) or 0
    local previous = tonumber(data.ComputerModComponentsLastWearHour or now) or now
    data.ComputerModComponentsLastWearHour = now
    if data.ComputerModPowerOn ~= true or now <= previous then return false end
    local elapsed = math.min(240, now - previous)
    local wearRate = math.max(0, math.min(300, ComputerModSandbox.getNumber("ComponentWearRate", 100))) / 100
    if wearRate <= 0 or elapsed <= 0 then return false end
    local changed = false
    for i = 1, #ComputerModComponents.parts do
        local part = ComputerModComponents.parts[i]
        local state = data.ComputerModComponents[part.id]
        if ComputerModComponents.isPartCompatible(part, data) and type(state) == "table" and clampCondition(state.condition) > 0 then
            local nextCondition = clampCondition(state.condition - elapsed * part.wearPerHour * wearRate)
            if math.abs(nextCondition - state.condition) >= 0.0001 then
                state.condition = nextCondition
                changed = true
            end
        end
    end
    return changed
end

function ComputerModComponents.getBootFailure(data)
    if type(data) ~= "table" or data.ComputerModNetworkTerminal == true then return nil end
    local components = type(data.ComputerModComponents) == "table" and data.ComputerModComponents or {}
    for i = 1, #ComputerModComponents.parts do
        local part = ComputerModComponents.parts[i]
        if ComputerModComponents.isPartRequired(part, data) then
            local state = components[part.id]
            if type(state) ~= "table" then return {part = part, reason = "missing"} end
            if clampCondition(state.condition) <= 0 then return {part = part, reason = "broken"} end
        end
    end
    return nil
end

function ComputerModComponents.detachPart(data, partId)
    if type(data) ~= "table" or data.ComputerModNetworkTerminal == true then return nil end
    local components = type(data.ComputerModComponents) == "table" and data.ComputerModComponents or nil
    local state = components and components[partId] or nil
    if type(state) ~= "table" then return nil end
    if partId == "hardDrive" then ComputerModComponents.captureDriveData(data) end
    local detached = copyValue(state)
    local part = ComputerModComponents.getPart(partId)
    if part and type(part.onDetach) == "function" then pcall(part.onDetach, data, detached) end
    components[partId] = nil
    if partId == "hardDrive" then ComputerModComponents.clearDriveData(data) end
    data.ComputerModPowerOn = false
    return detached
end

function ComputerModComponents.attachPart(data, partId, state)
    if type(data) ~= "table" or data.ComputerModNetworkTerminal == true then return false end
    local part = ComputerModComponents.getPart(partId)
    if not part or type(state) ~= "table" then return false end
    if type(data.ComputerModComponents) ~= "table" then data.ComputerModComponents = {} end
    if data.ComputerModComponents[partId] ~= nil then return false end
    local installed = copyValue(state)
    installed.itemType = part.itemType
    installed.condition = clampCondition(installed.condition)
    data.ComputerModComponents[partId] = installed
    data.ComputerModComponentsInitialized = true
    data.ComputerModComponentsVersion = ComputerModComponents.version
    data.ComputerModComponentsLastWearHour = ComputerModComponents.getWorldAgeHours()
    data.ComputerModPowerOn = false
    if partId == "hardDrive" then ComputerModComponents.applyHardDriveData(data, installed) end
    if type(part.onAttach) == "function" then pcall(part.onAttach, data, installed) end
    return true
end

function ComputerModComponents.writeStateToItem(item, partId, state)
    if not item or type(state) ~= "table" then return end
    local condition = math.floor(clampCondition(state.condition) + 0.5)
    if item.setCondition then pcall(function() item:setCondition(condition) end) end
    if not item.getModData then return end
    local itemData = item:getModData()
    itemData.ComputerModComponentId = partId
    itemData.ComputerModComponentCondition = condition
    if partId == "hardDrive" then
        itemData.ComputerModHardDriveID = state.driveId or ComputerModComponents.makeDriveId("inventory")
        itemData.ComputerModHardDriveData = copyValue(state.driveData)
        itemData.ComputerModHardDriveFresh = state.fresh == true
    end
    local part = ComputerModComponents.getPart(partId)
    if part and type(part.writeStateToItem) == "function" then pcall(part.writeStateToItem, item, itemData, state) end
end

function ComputerModComponents.readStateFromItem(item, expectedPartId)
    if not item or not item.getFullType then return nil end
    local part = ComputerModComponents.getPartByItemType(item:getFullType())
    if not part or (expectedPartId and part.id ~= expectedPartId) then return nil end
    local condition = 100
    if item.getCondition then
        local ok, value = pcall(function() return item:getCondition() end)
        if ok and tonumber(value) then condition = tonumber(value) end
    end
    local state = ComputerModComponents.newPartState(part.id, condition, tostring(item.getID and item:getID() or "item"))
    local itemData = item.getModData and item:getModData() or nil
    if itemData and tonumber(itemData.ComputerModComponentCondition) then
        state.condition = clampCondition(itemData.ComputerModComponentCondition)
    end
    if part.id == "hardDrive" and itemData then
        state.driveId = tostring(itemData.ComputerModHardDriveID or state.driveId)
        state.driveData = copyValue(itemData.ComputerModHardDriveData)
        state.fresh = itemData.ComputerModHardDriveFresh == true or type(state.driveData) ~= "table"
    end
    if type(part.readStateFromItem) == "function" then pcall(part.readStateFromItem, item, itemData, state) end
    return state, part
end

function ComputerModComponents.getConditionLabel(condition)
    local value = clampCondition(condition)
    if value <= 0 then return "Broken" end
    if value < 25 then return "Critical" end
    if value < 60 then return "Worn" end
    if value < 85 then return "Good" end
    return "Excellent"
end

function ComputerModComponents.getRepairSpec(part)
    part = type(part) == "table" and part or ComputerModComponents.getPart(part)
    return part and type(part.repair) == "table" and part.repair or nil
end

function ComputerModComponents.getRepairTarget(part, state, electricalLevel)
    local spec = ComputerModComponents.getRepairSpec(part)
    if not spec or type(state) ~= "table" then return nil end
    local current = clampCondition(state.condition)
    local cap = clampCondition(spec.cap or 100)
    if current >= cap then return nil end
    local skillBonus = math.max(0, (tonumber(electricalLevel) or 0) - (tonumber(spec.level) or 0)) * 2
    return math.min(cap, current + math.max(1, tonumber(spec.amount) or 1) + skillBonus)
end

function ComputerModComponents.repair(data, partId, electricalLevel)
    local part = ComputerModComponents.getPart(partId)
    local spec = ComputerModComponents.getRepairSpec(part)
    if not spec or (tonumber(electricalLevel) or 0) < (tonumber(spec.level) or 0) then return false end
    local state = type(data) == "table" and type(data.ComputerModComponents) == "table" and data.ComputerModComponents[partId] or nil
    local target = ComputerModComponents.getRepairTarget(part, state, electricalLevel)
    if not target then return false end
    state.condition = target
    state.wearRemainder = 0
    return true, target
end

function ComputerModComponents.setCondition(data, partId, condition)
    local state = type(data) == "table" and type(data.ComputerModComponents) == "table" and data.ComputerModComponents[partId] or nil
    if type(state) ~= "table" then return false end
    state.condition = clampCondition(condition)
    return true
end
