-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
if not isServer() then return end

require "ComputerMod_ComputerTypes"

ComputerModCDServer = ComputerModCDServer or {}

ComputerModCDServer.gameDiscItems = {
    os = "ComputerMod.SystemCDPZOS",
    pong = "ComputerMod.GameCDPong",
    snake = "ComputerMod.GameCDSnake",
    minesweeper = "ComputerMod.GameCDMinesweeper",
    tetris = "ComputerMod.GameCDTetris",
    space_invaders = "ComputerMod.GameCDSpaceInvaders",
    doom = "ComputerMod.GameCDDoom",
    racer = "ComputerMod.GameCDRacer",
    flappy = "ComputerMod.GameCDFlappy",
    breakout = "ComputerMod.GameCDBreakout",
    asteroids = "ComputerMod.GameCDAsteroids",
    frogger = "ComputerMod.GameCDFrogger",
    missile = "ComputerMod.GameCDMissile",
    lander = "ComputerMod.GameCDLander",
    circuit = "ComputerMod.GameCDCircuit",
    memory = "ComputerMod.GameCDMemory",
    starpilot = "ComputerMod.GameCDStarPilot",
    caverunner = "ComputerMod.GameCDCaveRunner",
    lightsout = "ComputerMod.GameCDLightsOut",
    signalmatch = "ComputerMod.GameCDSignalMatch",
    boxpush = "ComputerMod.GameCDBoxPush",
    tileslide = "ComputerMod.GameCDTileSlide",
    pipelink = "ComputerMod.GameCDPipeLink",
    codebreaker = "ComputerMod.GameCDCodeBreaker",
    outbreakops = "ComputerMod.GameCDOutbreakOps",
    blank = "ComputerMod.BlankCD",
    hack = "ComputerMod.PasswordHackCD"
}

ComputerModCDServer.discItems = {
    ["computermod.systemcdpzos"] = true,
    ["computermod.gamecdpong"] = true,
    ["computermod.gamecdsnake"] = true,
    ["computermod.gamecdminesweeper"] = true,
    ["computermod.gamecdtetris"] = true,
    ["computermod.gamecdspaceinvaders"] = true,
    ["computermod.gamecddoom"] = true,
    ["computermod.gamecdracer"] = true,
    ["computermod.gamecdflappy"] = true,
    ["computermod.gamecdbreakout"] = true,
    ["computermod.gamecdasteroids"] = true,
    ["computermod.gamecdfrogger"] = true,
    ["computermod.gamecdmissile"] = true,
    ["computermod.gamecdlander"] = true,
    ["computermod.gamecdcircuit"] = true,
    ["computermod.gamecdmemory"] = true,
    ["computermod.gamecdstarpilot"] = true,
    ["computermod.gamecdcaverunner"] = true,
    ["computermod.gamecdlightsout"] = true,
    ["computermod.gamecdsignalmatch"] = true,
    ["computermod.gamecdboxpush"] = true,
    ["computermod.gamecdtileslide"] = true,
    ["computermod.gamecdpipelink"] = true,
    ["computermod.gamecdcodebreaker"] = true,
    ["computermod.gamecdoutbreakops"] = true,
    ["computermod.blankcd"] = true,
    ["computermod.passwordhackcd"] = true
}

ComputerModCDServer.vanillaDiscItems = {
    ["base.cd"] = true
}

local function limitText(value, maxLength)
    local text = tostring(value or "")
    if string.len(text) > maxLength then
        return string.sub(text, 1, maxLength)
    end
    return text
end

local function copyDiscContents(contents)
    local copy = {}
    if type(contents) ~= "table" then return copy end
    for i = 1, math.min(#contents, 128) do
        local entry = contents[i]
        if type(entry) == "table" then
            local entryCopy = {}
            for k, v in pairs(entry) do
                if type(k) == "string" or type(k) == "number" then
                    if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                        entryCopy[k] = v
                    elseif type(v) == "table" then
                        local nested = {}
                        for nk, nv in pairs(v) do
                            if (type(nk) == "string" or type(nk) == "number") and (type(nv) == "string" or type(nv) == "number" or type(nv) == "boolean") then
                                nested[nk] = nv
                            end
                        end
                        entryCopy[k] = nested
                    end
                end
            end
            copy[#copy + 1] = entryCopy
        end
    end
    return copy
end

local function isDiscType(fullType)
    if not fullType or fullType == "" then return false end
    local normalized = string.lower(tostring(fullType))
    return ComputerModCDServer.discItems[normalized] == true or ComputerModCDServer.vanillaDiscItems[normalized] == true
end

local function resolveMountedDisc(data)
    if not data or not data.ComputerModMountedCD then return nil, nil end
    local mountedGame = tostring(data.ComputerModMountedCD)
    local fullType = tostring(data.ComputerModMountedCDItem or "")
    if ComputerModCDServer.gameDiscItems[mountedGame] then
        fullType = fullType ~= "" and fullType or ComputerModCDServer.gameDiscItems[mountedGame]
        data.ComputerModMountedCDItem = fullType
        return mountedGame, fullType
    end
    local normalizedType = string.lower(fullType ~= "" and fullType or mountedGame)
    for gameId, mappedType in pairs(ComputerModCDServer.gameDiscItems) do
        if string.lower(mappedType) == normalizedType then
            data.ComputerModMountedCD = gameId
            data.ComputerModMountedCDItem = mappedType
            return gameId, mappedType
        end
    end
    if fullType == "" and isDiscType(mountedGame) then
        fullType = mountedGame
        data.ComputerModMountedCDItem = fullType
    end
    return mountedGame, fullType
end

local function isComputerObject(object, machineId)
    if not ComputerModComputerTypes.isComputer(object) then return false end
    local data = ComputerModComputerTypes.getData(object)
    if data.ComputerModNetworkTerminal == true then return false end
    return not machineId or machineId == "" or tostring(data.ComputerModMachineID or "") == machineId
end

local function findComputerObject(args)
    if not getCell or type(args) ~= "table" then return nil end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not x or not y or not z then return nil end
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil end
    return ComputerModComputerTypes.findOnSquare(square, limitText(args.machineId, 128), tostring(args.computerType or ""), false)
end

local function isPlayerNearComputer(player, object)
    if not player or not object or not player.getSquare or not object.getSquare then return false end
    if not player:getSquare() or not object:getSquare() then return false end
    if player:getZ() ~= object:getZ() then return false end
    return math.abs(player:getX() - object:getX()) <= 4 and math.abs(player:getY() - object:getY()) <= 4
end

local function getItemId(item)
    if not item or not item.getID then return "" end
    local ok, value = pcall(function() return item:getID() end)
    if not ok or value == nil then return "" end
    return tostring(value)
end

local function getItemLabel(item)
    if not item then return "" end
    local data = item.getModData and item:getModData() or nil
    if data and data.ComputerModDiscLabel and tostring(data.ComputerModDiscLabel) ~= "" then
        return limitText(data.ComputerModDiscLabel, 80)
    end
    if item.getDisplayName then
        local ok, value = pcall(function() return item:getDisplayName() end)
        if ok and value then return limitText(value, 80) end
    end
    return ""
end

local function findInventoryDisc(inventory, fullType, requestedId, requestedLabel)
    if not inventory or not fullType then return nil end
    if requestedId ~= nil and requestedId ~= "" and inventory.getItemWithID then
        local ok, item = pcall(function() return inventory:getItemWithID(requestedId) end)
        if ok and item and item.getFullType and string.lower(tostring(item:getFullType())) == string.lower(fullType) then
            return item
        end
    end
    local requestedIdText = requestedId ~= nil and tostring(requestedId) or ""
    local matches = nil
    if inventory.getAllTypeRecurse then
        local ok, result = pcall(function() return inventory:getAllTypeRecurse(fullType) end)
        if ok then matches = result end
    end
    local fallback = nil
    local labelMatch = nil
    local function inspect(item)
        if not item or not item.getFullType or string.lower(tostring(item:getFullType())) ~= string.lower(fullType) then return nil end
        fallback = fallback or item
        if requestedIdText ~= "" and getItemId(item) == requestedIdText then return item end
        if requestedLabel ~= "" and getItemLabel(item) == requestedLabel then labelMatch = labelMatch or item end
        return nil
    end
    if matches and matches.size and matches.get then
        for i = 0, matches:size() - 1 do
            local exact = inspect(matches:get(i))
            if exact then return exact end
        end
    elseif inventory.getItems then
        local items = inventory:getItems()
        for i = 0, items:size() - 1 do
            local exact = inspect(items:get(i))
            if exact then return exact end
        end
    end
    return labelMatch or fallback
end

local function removeInventoryItem(item)
    local container = item and item.getContainer and item:getContainer() or nil
    if not item or not container or not container.Remove then return false end
    local ok = pcall(function() container:Remove(item) end)
    if not ok then return false end
    if container.setDrawDirty then
        pcall(function() container:setDrawDirty(true) end)
    end
    if sendRemoveItemFromContainer then
        pcall(function() sendRemoveItemFromContainer(container, item) end)
    end
    return true
end

local function addItemWithSavedData(inventory, fullType, savedName, contents)
    if not inventory or not inventory.AddItem or not fullType then return nil end
    local item = nil
    if instanceItem then
        local okCreate, created = pcall(function() return instanceItem(fullType) end)
        if okCreate then item = created end
    end
    local ok = false
    if item then
        ok = pcall(function() inventory:AddItem(item) end)
    else
        ok, item = pcall(function() return inventory:AddItem(fullType) end)
    end
    if not ok or not item then return nil end
    local label = limitText(savedName, 80)
    if label ~= "" and item.setName then
        pcall(function() item:setName(label) end)
    end
    if item.getModData then
        local data = item:getModData()
        if label ~= "" then data.ComputerModDiscLabel = label end
        data.ComputerModDiscContents = copyDiscContents(contents)
    end
    if inventory.setDrawDirty then
        pcall(function() inventory:setDrawDirty(true) end)
    end
    if sendAddItemToContainer then
        pcall(function() sendAddItemToContainer(inventory, item) end)
    end
    return item
end

local function sendResult(player, action, success, reason, purpose, object)
    if not player or not sendServerCommand then return end
    local data = ComputerModComputerTypes.getData(object)
    sendServerCommand(player, "ComputerModCD", "ActionResult", {
        action = action,
        success = success == true,
        reason = reason or "",
        purpose = purpose == "reset" and "reset" or "",
        machineId = data and tostring(data.ComputerModMachineID or "") or "",
        mountedCD = data and data.ComputerModMountedCD or nil,
        mountedCDItem = data and data.ComputerModMountedCDItem or nil,
        mountedCDLabel = data and data.ComputerModMountedCDLabel or nil,
        mountedCDContents = data and copyDiscContents(data.ComputerModMountedCDContents) or {}
    })
end

function ComputerModCDServer.insertDisc(player, args)
    args = args or {}
    local object = findComputerObject(args)
    if not object then
        sendResult(player, "insert", false, "invalid_computer")
        return
    end
    if not isPlayerNearComputer(player, object) then
        sendResult(player, "insert", false, "too_far")
        return
    end
    local data = ComputerModComputerTypes.getData(object)
    if data.ComputerModMountedCD then
        resolveMountedDisc(data)
        ComputerModComputerTypes.transmitData(object)
        sendResult(player, "insert", false, "occupied")
        return
    end
    local gameId = limitText(args.gameId, 64)
    local fullType = ComputerModCDServer.gameDiscItems[gameId]
    if not fullType then
        sendResult(player, "insert", false, "invalid_disc")
        return
    end
    local inventory = player and player.getInventory and player:getInventory() or nil
    local item = findInventoryDisc(inventory, fullType, args.itemId, limitText(args.label, 80))
    if not item then
        sendResult(player, "insert", false, "missing_disc")
        return
    end
    local itemFullType = item.getFullType and item:getFullType() or fullType
    local label = getItemLabel(item)
    local itemData = item.getModData and item:getModData() or nil
    local contents = copyDiscContents(itemData and itemData.ComputerModDiscContents or nil)
    if not removeInventoryItem(item) then
        sendResult(player, "insert", false, "inventory_error")
        return
    end
    data.ComputerModMountedCD = gameId
    data.ComputerModMountedCDItem = itemFullType
    data.ComputerModMountedCDLabel = label ~= "" and label or gameId
    data.ComputerModMountedCDContents = contents
    ComputerModComputerTypes.transmitData(object)
    sendResult(player, "insert", true, nil, nil, object)
end

function ComputerModCDServer.ejectDisc(player, args)
    args = args or {}
    local purpose = args.purpose == "reset" and "reset" or ""
    local object = findComputerObject(args)
    if not object then
        sendResult(player, "eject", false, "invalid_computer", purpose)
        return
    end
    if not isPlayerNearComputer(player, object) then
        sendResult(player, "eject", false, "too_far", purpose)
        return
    end
    local data = ComputerModComputerTypes.getData(object)
    if not data.ComputerModMountedCD then
        sendResult(player, "eject", false, "empty", purpose)
        return
    end
    local _, fullType = resolveMountedDisc(data)
    fullType = tostring(fullType or "")
    if not isDiscType(fullType) then
        sendResult(player, "eject", false, "invalid_disc", purpose)
        return
    end
    local inventory = player and player.getInventory and player:getInventory() or nil
    local item = addItemWithSavedData(inventory, fullType, data.ComputerModMountedCDLabel, data.ComputerModMountedCDContents)
    if not item then
        sendResult(player, "eject", false, "inventory_error", purpose)
        return
    end
    data.ComputerModMountedCD = nil
    data.ComputerModMountedCDItem = nil
    data.ComputerModMountedCDLabel = nil
    data.ComputerModMountedCDContents = nil
    ComputerModComputerTypes.transmitData(object)
    sendResult(player, "eject", true, nil, purpose, object)
end

function ComputerModCDServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModCD" then return end
    if command == "InsertDisc" then
        ComputerModCDServer.insertDisc(player, args)
    elseif command == "EjectDisc" then
        ComputerModCDServer.ejectDisc(player, args)
    end
end

Events.OnClientCommand.Add(ComputerModCDServer.onClientCommand)
