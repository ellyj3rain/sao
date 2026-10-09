require "ComputerMod_Components"
require "ComputerMod_ComputerTypes"

if not isServer() then return end

ComputerModComputerDataServer = ComputerModComputerDataServer or {}
ComputerModComputerDataServer.storeName = "ComputerModComputerDataDB"

local function limitText(value, maxCharacters)
    local text = tostring(value or "")
    local limit = math.max(0, tonumber(maxCharacters or 0) or 0)
    if limit <= 0 or text == "" then return limit <= 0 and "" or text end
    local index = 1
    local count = 0
    local lastIndex = 0
    local length = string.len(text)
    while index <= length and count < limit do
        local byte = string.byte(text, index)
        local width = 1
        if byte >= 240 then
            width = 4
        elseif byte >= 224 then
            width = 3
        elseif byte >= 192 then
            width = 2
        end
        if index + width - 1 > length then break end
        lastIndex = index + width - 1
        index = index + width
        count = count + 1
    end
    if index > length then return text end
    return string.sub(text, 1, lastIndex)
end

local function getStore()
    local store = ModData.getOrCreate(ComputerModComputerDataServer.storeName)
    if type(store.notes) ~= "table" then store.notes = {} end
    return store
end

local function sanitizeDesktopNotes(notes)
    local clean = {}
    if type(notes) ~= "table" then return clean end
    for i = 1, math.min(#notes, 64) do
        local note = notes[i]
        if type(note) == "table" then
            local key = limitText(note.key, 128)
            if key ~= "" then
                clean[#clean + 1] = {
                    key = key,
                    name = limitText(note.name or "Note", 80),
                    text = limitText(note.text, 8192)
                }
            end
        end
    end
    return clean
end

local function isComputerObject(object, machineId)
    if not ComputerModComputerTypes.isComputer(object) then return false end
    local data = ComputerModComputerTypes.getData(object)
    return not machineId or machineId == "" or tostring(data.ComputerModMachineID or "") == tostring(machineId)
end

local function findComputerObject(args)
    if not getCell or not args then return nil end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not x or not y or not z then return nil end
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil end
    return ComputerModComputerTypes.findOnSquare(square, tostring(args.machineId or ""), tostring(args.computerType or ""), true)
end

local function isPlayerNearComputer(player, object)
    if not player or not object or not player.getSquare or not object.getSquare then return false end
    if not player:getSquare() or not object:getSquare() then return false end
    if player:getZ() ~= object:getZ() then return false end
    return math.abs(player:getX() - object:getX()) <= 4 and math.abs(player:getY() - object:getY()) <= 4
end

local function findWorldItemForSave(args)
    if type(args) ~= "table" or not getCell then return nil end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    local itemId = tonumber(args.itemId)
    if not x or not y or not z or not itemId then return nil end
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil end
    local function inspect(objects)
        if not objects then return nil end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local definition = ComputerModComputerTypes.getDefinition(object)
            local item = ComputerModComputerTypes.getInventoryItem(object)
            if definition and definition.dataOnItem == true
                    and tostring(definition.id) == tostring(args.computerType or "")
                    and item and item.getID and tonumber(item:getID()) == itemId then
                return object
            end
        end
    end
    return inspect(square.getWorldObjects and square:getWorldObjects() or nil)
        or inspect(square.getObjects and square:getObjects() or nil)
        or inspect(square.getSpecialObjects and square:getSpecialObjects() or nil)
end

function ComputerModComputerDataServer.saveItemData(player, args)
    local object = findWorldItemForSave(args)
    if not object or not isPlayerNearComputer(player, object) then return end
    local snapshot = args and args.itemData or nil
    if type(snapshot) ~= "table" or snapshot.ComputerModNetworkTerminal == true then return end
    local definition = ComputerModComputerTypes.getDefinition(object)
    local data = ComputerModComputerTypes.getData(object)
    if not definition or not data then return end
    ComputerModComputerTypes.ensureIdentity(object, data, definition)
    if tostring(data.ComputerModMachineID or "") ~= tostring(args.machineId or "") then
        ComputerModComputerTypes.transmitData(object)
        return
    end
    if data.ComputerModMetaInitialized == true and snapshot.ComputerModMetaInitialized ~= true then
        ComputerModComputerTypes.transmitData(object)
        return
    end
    if type(data.ComputerModComponents) ~= "table" then
        ComputerModComponents.ensure(data, ComputerModComponents.getComputerSeed(data, object), false, ComputerModComponents.getWorldAgeHours())
    end
    ComputerModComponents.applyWear(data, ComputerModComponents.getWorldAgeHours())
    for key in pairs(data) do
        if type(key) == "string" and string.sub(key, 1, 11) == "ComputerMod"
                and not ComputerModComputerTypes.itemDataServerOwned[key] and snapshot[key] == nil then
            data[key] = nil
        end
    end
    for key, value in pairs(snapshot) do
        if type(key) == "string" and string.sub(key, 1, 11) == "ComputerMod"
                and not ComputerModComputerTypes.itemDataServerOwned[key] then
            data[key] = value
        end
    end
    ComputerModComponents.captureDriveData(data)
    ComputerModComputerTypes.transmitData(object)
end

local function applyNotesSnapshot(object, snapshot)
    if not object or type(snapshot) ~= "table" then return false end
    local data = ComputerModComputerTypes.getData(object)
    if not data then return false end
    local revision = tonumber(snapshot.revision or 1) or 1
    data.ComputerModNotepadText = limitText(snapshot.notepadText, 32768)
    data.ComputerModNotepadInitialized = snapshot.notepadInitialized == true
    data.ComputerModNotepadSeedRepairV1 = snapshot.notepadSeedRepairV1 == true
    data.ComputerModDesktopNotes = sanitizeDesktopNotes(snapshot.desktopNotes)
    data.ComputerModFactoryReset = snapshot.factoryReset == true
    data.ComputerModNotesRevision = revision
    return true
end

function ComputerModComputerDataServer.saveNotes(player, args)
    args = args or {}
    local machineId = limitText(args.machineId, 128)
    local object = findComputerObject(args)
    if not object or not isPlayerNearComputer(player, object) then return end
    local data = ComputerModComputerTypes.getData(object)
    local driveId = limitText(data.ComputerModDriveID or args.driveId, 128)
    local storageId = driveId ~= "" and driveId or machineId
    if storageId == "" then return end
    local store = getStore()
    local previous = store.notes[storageId]
    local previousRevision = type(previous) == "table" and (tonumber(previous.revision or 1) or 1) or 0
    store.notes[storageId] = {
        notepadText = limitText(args.notepadText, 32768),
        notepadInitialized = args.notepadInitialized == true,
        notepadSeedRepairV1 = args.notepadSeedRepairV1 == true,
        factoryReset = args.factoryReset == true,
        desktopNotes = sanitizeDesktopNotes(args.desktopNotes),
        revision = previousRevision + 1,
        savedAt = getTimestampMs and getTimestampMs() or 0
    }
    if applyNotesSnapshot(object, store.notes[storageId]) then
        ComputerModComponents.captureDriveData(data)
        ComputerModComputerTypes.transmitData(object)
    end
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModComputerDataServer.storeName)
    end
end

function ComputerModComputerDataServer.restoreNotesOnSquare(square)
    if not square then return end
    local store = getStore()
    local seen = {}
    local function inspect(objects)
        if not objects then return end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object and not seen[object] and isComputerObject(object) then
                seen[object] = true
                local data = ComputerModComputerTypes.getData(object)
                local machineId = tostring(data.ComputerModMachineID or "")
                local driveId = tostring(data.ComputerModDriveID or "")
                local snapshot = driveId ~= "" and store.notes[driveId] or nil
                if not snapshot and machineId ~= "" then
                    snapshot = store.notes[machineId]
                    if snapshot and driveId ~= "" then store.notes[driveId] = snapshot end
                end
                local snapshotRevision = type(snapshot) == "table" and (tonumber(snapshot.revision or 1) or 1) or 0
                local objectRevision = tonumber(data.ComputerModNotesRevision or 0) or 0
                if snapshotRevision > objectRevision and applyNotesSnapshot(object, snapshot) then
                    ComputerModComponents.captureDriveData(data)
                    ComputerModComputerTypes.transmitData(object)
                end
            end
        end
    end
    inspect(square.getObjects and square:getObjects() or nil)
    inspect(square.getSpecialObjects and square:getSpecialObjects() or nil)
    inspect(square.getWorldObjects and square:getWorldObjects() or nil)
end

local function computerContainsMagazine(object, fullType)
    if not object then return false end
    local data = ComputerModComputerTypes.getData(object)
    if not data then return false end
    local seen = {}
    local scanned = 0
    local function inspect(value, depth)
        if type(value) ~= "table" or seen[value] or depth > 8 or scanned >= 2048 then return false end
        seen[value] = true
        scanned = scanned + 1
        if value.type == "magazine" and tostring(value.id or "") == fullType then
            return true
        end
        for _, nested in pairs(value) do
            if type(nested) == "table" and inspect(nested, depth + 1) then
                return true
            end
        end
        return false
    end
    local fieldNames = {
        "ComputerModDownloadedMagazines",
        "ComputerModFolderContents",
        "ComputerModDesktopFiles",
        "ComputerModTrashEntries",
        "ComputerModMountedCDContents"
    }
    for i = 1, #fieldNames do
        if inspect(data[fieldNames[i]], 1) then return true end
    end
    return false
end

function ComputerModComputerDataServer.markMagazineRead(player, args)
    args = args or {}
    if not player then return end
    local fullType = tostring(args.fullType or "")
    if fullType == "" or string.len(fullType) > 128 then return end
    local object = findComputerObject(args)
    if not object or not isPlayerNearComputer(player, object) or not computerContainsMagazine(object, fullType) then return end
    if not InventoryItemFactory then return end
    local ok, item = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
    if not ok or not item or not item.getLearnedRecipes then return end
    local okRecipes, recipes = pcall(function() return item:getLearnedRecipes() end)
    if not okRecipes or not recipes or not recipes.size or not recipes.get then return end
    for i = 0, math.min(recipes:size(), 128) - 1 do
        local recipe = tostring(recipes:get(i) or "")
        if recipe ~= "" and string.len(recipe) <= 128 and player.learnRecipe then
            pcall(function() player:learnRecipe(recipe) end)
        end
        if recipe ~= "" and string.len(recipe) <= 128 and player.getKnownRecipes then
            pcall(function() player:getKnownRecipes():add(recipe) end)
        end
    end
    local pages = 0
    if item.getNumberOfPages then
        local okPages, value = pcall(function() return item:getNumberOfPages() end)
        if okPages then pages = tonumber(value or 0) or 0 end
    end
    if pages > 0 and player.setAlreadyReadPages then
        pcall(function() player:setAlreadyReadPages(fullType, pages) end)
    end
    if player.getAlreadyReadBook then
        pcall(function() player:getAlreadyReadBook():add(fullType) end)
    end
    if player.ReadLiterature and (not instanceof or instanceof(item, "Literature")) then
        pcall(function() player:ReadLiterature(item) end)
    end
    if sendSyncPlayerFields then
        pcall(function() sendSyncPlayerFields(player, 0x00000007) end)
    end
end

local factoryResetFields = {
    "ComputerModFolders",
    "ComputerModInstalledGames",
    "ComputerModMountedCD",
    "ComputerModMountedCDItem",
    "ComputerModMountedCDLabel",
    "ComputerModMountedCDContents",
    "ComputerModOSInstalled",
    "ComputerModPowerOn",
    "ComputerModLastView",
    "ComputerModLastFolderName",
    "ComputerModPasswordEnabled",
    "ComputerModPassword",
    "ComputerModNotepadText",
    "ComputerModNotepadInitialized",
    "ComputerModNotepadSeedRepairV1",
    "ComputerModCalculatorDisplay",
    "ComputerModDownloadedInstallers",
    "ComputerModDownloadedMagazines",
    "ComputerModTrashEntries",
    "ComputerModFolderContents",
    "ComputerModFolderContentVersion",
    "ComputerModUserFolders",
    "ComputerModDesktopNotes",
    "ComputerModPaintFiles",
    "ComputerModPaintSpawnInitialized",
    "ComputerModDesktopFiles",
    "ComputerModPaintSession",
    "ComputerModHiddenDesktopItems",
    "ComputerModActiveDownloadGame",
    "ComputerModActiveDownloadProgress",
    "ComputerModActiveDownloadLastWorldAge",
    "ComputerModMailLoggedIn",
    "ComputerModMailSessionAddress",
    "ComputerModMailAddress",
    "ComputerModMailPassword",
    "ComputerModMailMessages",
    "ComputerModChatLoggedIn",
    "ComputerModChatSessionUser",
    "ComputerModChatUsername",
    "ComputerModChatPassword",
    "ComputerModMarketSessionUser",
    "ComputerModMarketMoney",
    "ComputerModMarketPurchases",
    "ComputerModMarketCompletedJobs",
    "ComputerModMuteMusic",
    "ComputerModUse24HourClock",
    "ComputerModMonthFirstDate",
    "ComputerModTextSize",
    "ComputerModUsername",
    "ComputerModAvatar",
    "ComputerModBackgroundPalette",
    "ComputerModBrowserAddress",
    "ComputerModSessionUnlocked",
    "ComputerModHackLockUntil"
}

function ComputerModComputerDataServer.factoryReset(player, args)
    args = args or {}
    local object = findComputerObject(args)
    if not object or not isPlayerNearComputer(player, object) then return end
    local data = ComputerModComputerTypes.getData(object)
    for i = 1, #factoryResetFields do
        data[factoryResetFields[i]] = nil
    end
    for i = 1, #ComputerModComponents.driveFields do
        data[ComputerModComponents.driveFields[i]] = nil
    end
    data.ComputerModMetaInitialized = true
    data.ComputerModFolders = {}
    data.ComputerModInstalledGames = {}
    data.ComputerModOSInstalled = false
    data.ComputerModPowerOn = false
    data.ComputerModPasswordEnabled = false
    data.ComputerModNotepadText = ""
    data.ComputerModNotepadInitialized = true
    data.ComputerModNotepadSeedRepairV1 = true
    data.ComputerModCalculatorDisplay = "0"
    data.ComputerModDownloadedInstallers = {}
    data.ComputerModDownloadedMagazines = {}
    data.ComputerModTrashEntries = {}
    data.ComputerModFolderContents = {}
    data.ComputerModFolderContentVersion = 3
    data.ComputerModUserFolders = {}
    data.ComputerModDesktopNotes = {}
    data.ComputerModPaintFiles = {}
    data.ComputerModPaintSpawnInitialized = true
    data.ComputerModDesktopFiles = {}
    data.ComputerModHiddenDesktopItems = {}
    data.ComputerModFactoryReset = true
    data.ComputerModMuteMusic = false
    data.ComputerModUse24HourClock = false
    data.ComputerModMonthFirstDate = false
    data.ComputerModTextSize = 2
    data.ComputerModUsername = "User"
    data.ComputerModAvatar = 1
    data.ComputerModBackgroundPalette = 1
    data.ComputerModBrowserAddress = "knox-weather.net"

    local storageId = tostring(data.ComputerModDriveID or data.ComputerModMachineID or "")
    if storageId ~= "" then
        local store = getStore()
        local previous = store.notes[storageId]
        local revision = type(previous) == "table" and (tonumber(previous.revision or 1) or 1) + 1 or 1
        store.notes[storageId] = {
            notepadText = "",
            notepadInitialized = true,
            notepadSeedRepairV1 = true,
            factoryReset = true,
            desktopNotes = {},
            revision = revision,
            savedAt = getTimestampMs and getTimestampMs() or 0
        }
        data.ComputerModNotesRevision = revision
        if ModData and ModData.transmit then
            ModData.transmit(ComputerModComputerDataServer.storeName)
        end
    end
    ComputerModComponents.captureDriveData(data)
    ComputerModComputerTypes.transmitData(object)
end

function ComputerModComputerDataServer.onInitGlobalModData()
    getStore()
end

function ComputerModComputerDataServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModComputerData" then return end
    if command == "SaveNotes" then
        ComputerModComputerDataServer.saveNotes(player, args)
    elseif command == "SaveItemData" then
        ComputerModComputerDataServer.saveItemData(player, args)
    elseif command == "MarkMagazineRead" then
        ComputerModComputerDataServer.markMagazineRead(player, args)
    elseif command == "FactoryReset" then
        ComputerModComputerDataServer.factoryReset(player, args)
    end
end

Events.OnInitGlobalModData.Add(ComputerModComputerDataServer.onInitGlobalModData)
Events.OnClientCommand.Add(ComputerModComputerDataServer.onClientCommand)
if Events.LoadGridsquare then
    Events.LoadGridsquare.Add(ComputerModComputerDataServer.restoreNotesOnSquare)
end
