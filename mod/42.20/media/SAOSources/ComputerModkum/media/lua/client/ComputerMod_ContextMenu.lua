require "ISUI/ISContextMenu"
require "ISUI/ISWorldObjectContextMenu"
require "ComputerMod_Sandbox"
require "ComputerMod_ScreenGlow"
require "ComputerMod_Power"
require "ComputerMod_Network"
require "ComputerMod_Debug"
require "ComputerMod_RelayRepair"
require "ComputerMod_RelayRepairUI"
require "ComputerMod_Components"
require "ComputerMod_Components_Client"
require "ComputerMod_ComputerTypes"
require "ComputerMod_ComponentRepairAction"
require "TimedActions/ISTimedActionQueue"

ComputerModContextMenu = ComputerModContextMenu or {}
local ComputerContextMenu = ComputerModContextMenu
_G.ComputerContextMenu = ComputerModContextMenu
local computerMenuTexture = getTexture("media/textures/files.PNG")

local gameDiscItems = {
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

local gameDiscLabels = {
    os = "PZ OS 3.1 CD",
    pong = "Pong CD",
    snake = "Snake CD",
    minesweeper = "Minesweeper CD",
    tetris = "Tetris CD",
    space_invaders = "Invaders CD",
    doom = "Doom CD",
    racer = "Road Race CD",
    flappy = "Flappy Bird CD",
    breakout = "Breakout CD",
    asteroids = "Asteroids CD",
    frogger = "Frogger CD",
    missile = "Missile Command CD",
    lander = "Lunar Lander CD",
    circuit = "Circuit Runner CD",
    memory = "Memory Match CD",
    starpilot = "Star Pilot CD",
    caverunner = "Cave Runner CD",
    lightsout = "Lights Out CD",
    signalmatch = "Signal Match CD",
    boxpush = "Box Push CD",
    tileslide = "Tile Slide CD",
    pipelink = "Pipe Link CD",
    codebreaker = "Code Breaker CD",
    outbreakops = "Outbreak Ops CD",
    blank = "Blank CD",
    hack = "Password Hack CD"
}

local function normalizeDiscType(fullType)
    if not fullType then return nil end
    return string.lower(tostring(fullType))
end

local function getMountedDiscGame(data)
    if not data or not data.ComputerModMountedCD then return nil end
    local mountedGame = tostring(data.ComputerModMountedCD)
    if gameDiscItems[mountedGame] then return mountedGame end
    local mountedType = normalizeDiscType(data.ComputerModMountedCDItem or mountedGame)
    if mountedType then
        for gameId, fullType in pairs(gameDiscItems) do
            if normalizeDiscType(fullType) == mountedType then
                return gameId
            end
        end
    end
    return mountedGame
end

local function cmText(key, fallback)
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return value end
    end
    return fallback
end

local function getDiscEntryFromItem(item)
    if not item or not item.getFullType then return nil end
    local fullType = item:getFullType()
    local normalized = normalizeDiscType(fullType)
    if not normalized then return nil end
    local itemData = item.getModData and item:getModData() or nil
    local savedDiscLabel = itemData and itemData.ComputerModDiscLabel or nil
    local displayName = savedDiscLabel and tostring(savedDiscLabel) or (item.getDisplayName and tostring(item:getDisplayName() or "") or "")

    for gameId, mappedType in pairs(gameDiscItems) do
        if normalized == normalizeDiscType(mappedType) then
            local label = displayName ~= "" and displayName or gameDiscLabels[gameId] or gameId
            return {gameId = gameId, label = label, fullType = fullType}
        end
    end

    return nil
end

local function addItemWithSavedName(inventory, fullType, savedName)
    if not inventory or not inventory.AddItem or not fullType then return end
    local item = nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local okCreate, created = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
        if okCreate and created then
            local okAdd = pcall(function() inventory:AddItem(created) end)
            if okAdd then item = created end
        end
    end
    if not item then
        local okAdd, added = pcall(function() return inventory:AddItem(fullType) end)
        if okAdd then item = added end
    end
    if item and savedName and savedName ~= "" and item.setName then
        pcall(function() item:setName(savedName) end)
    end
    if item and item.getModData and savedName and savedName ~= "" then
        item:getModData().ComputerModDiscLabel = savedName
    end
    return item
end

local function syncInventoryItem(inventory, item, added)
    if inventory and inventory.setDrawDirty then
        pcall(function() inventory:setDrawDirty(true) end)
    end
    if not inventory or not item then return end
    if isClient and isClient() then
        if added and sendAddItemToContainer then
            pcall(function() sendAddItemToContainer(inventory, item) end)
        elseif not added and sendRemoveItemFromContainer then
            pcall(function() sendRemoveItemFromContainer(inventory, item) end)
        end
    end
end

local function cloneDiscContents(contents)
    local copy = {}
    if type(contents) ~= "table" then return copy end
    for i = 1, #contents do
        local entry = contents[i]
        if type(entry) == "table" then
            local entryCopy = {}
            for k, v in pairs(entry) do
                if type(v) == "table" then
                    local nested = {}
                    for nk, nv in pairs(v) do
                        nested[nk] = nv
                    end
                    entryCopy[k] = nested
                else
                    entryCopy[k] = v
                end
            end
            copy[#copy + 1] = entryCopy
        end
    end
    return copy
end

local function returnDiscToPlayer(playerObj, inventory, fullType, label, contents)
    if not inventory or not fullType then return nil end
    local savedContents = cloneDiscContents(contents)
    if isClient and isClient() then return nil end
    local item = addItemWithSavedName(inventory, fullType, label)
    if item and item.getModData and type(savedContents) == "table" then
        item:getModData().ComputerModDiscContents = savedContents
    end
    syncInventoryItem(inventory, item, true)
    return item
end

local function playComputerUISound(soundName, playerObj)
    if not soundName or soundName == "" then return end
    if getSoundManager then
        pcall(function() getSoundManager():playUISound(soundName) end)
    end
    if playerObj and playerObj.getEmitter then
        pcall(function() playerObj:getEmitter():playSound(soundName) end)
    end
end

local function getComputerCommandArgs(computer)
    return ComputerModComputerTypes.getCommandArgs(computer)
end

local function isPlayerNearComputer(playerObj, computer)
    if not playerObj or not computer or not playerObj:getSquare() or not computer:getSquare() then return false end
    if playerObj:getZ() ~= computer:getZ() then return false end
    return math.abs(playerObj:getX() - computer:getX()) <= 2.6 and math.abs(playerObj:getY() - computer:getY()) <= 2.6
end

local function hasComputerPower(computer)
    return ComputerModPower and ComputerModPower.hasComputerPower and ComputerModPower.hasComputerPower(computer) or false
end

local function isNetworkTerminalRepaired(data)
    if not data or data.ComputerModNetworkTerminal ~= true then return false end
    if data.ComputerModNetworkRepaired == true then return true end
    local terminalId = data.ComputerModNetworkTerminalId
    local store = ComputerModNetwork and ComputerModNetwork.getStore and ComputerModNetwork.getStore() or nil
    local terminalStore = store and store.terminals and terminalId and store.terminals[terminalId] or nil
    return terminalStore and terminalStore.repaired == true
end

local function getRelayRepairUnavailableReason(playerObj)
    if ComputerModDebug and ComputerModDebug.isEnabled and ComputerModDebug.isEnabled(playerObj) then return nil end
    local internetEnabled = true
    if ComputerModNetwork and ComputerModNetwork.isInternetEnabled then
        internetEnabled = ComputerModNetwork.isInternetEnabled() ~= false
    end
    local gridPowerAvailable = ComputerModRelayRepair.isWorldGridPowerAvailable()
    if internetEnabled ~= false then
        return cmText("IGUI_ComputerMod_UI_Network_is_already_online", "Network is already online.")
    end
    if gridPowerAvailable == true then
        return cmText("IGUI_ComputerMod_UI_Relay_repair_waits_for_grid_failure", "Relay repair becomes available after the power grid fails.")
    end
    if gridPowerAvailable == nil then
        return cmText("IGUI_ComputerMod_UI_Relay_repair_waiting_for_grid_state", "The power-grid state is not ready yet. Try again shortly.")
    end
    return nil
end

local function addRelayRepairTooltip(option, unavailableReason)
    if not option or not ISWorldObjectContextMenu or not ISWorldObjectContextMenu.addToolTip then return end
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    local requirements = cmText("IGUI_ComputerMod_UI_Relay_repair_requirements", "Requires a locally powered relay, Electrical 2 and the listed service parts.")
    if unavailableReason and unavailableReason ~= "" then
        tooltip.description = "<RGB:1,0.25,0.2>" .. unavailableReason .. " <LINE> <RGB:0.85,0.85,0.8>" .. requirements
    else
        tooltip.description = "<RGB:0.3,1,0.35>" .. cmText("IGUI_ComputerMod_UI_Relay_repair_available", "Repair access is available.") .. " <LINE> <RGB:0.85,0.85,0.8>" .. requirements
    end
    option.toolTip = tooltip
end

local function forEachInventoryItem(container, callback)
    if not container or not container.getItems then return nil end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if callback(item) == true then return item end
        local nested = item and item.getInventory and item:getInventory() or nil
        local found = nested and forEachInventoryItem(nested, callback) or nil
        if found then return found end
    end
    return nil
end

local function playerHasScrewdriver(playerObj)
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then return false end
    if inventory.containsTagEvalRecurse and ItemTag and ItemTag.SCREWDRIVER then
        return inventory:containsTagEvalRecurse(ItemTag.SCREWDRIVER, function(item)
            return item ~= nil and (not item.isBroken or item:isBroken() ~= true)
        end)
    end
    return forEachInventoryItem(inventory, function(item)
        local fullType = item and item.getFullType and string.lower(tostring(item:getFullType())) or ""
        return fullType == "base.screwdriver"
            or fullType == "base.screwdriver_old"
            or fullType == "base.screwdriver_improvised"
    end) ~= nil
end

local function playerHasPliers(playerObj)
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    return forEachInventoryItem(inventory, function(item)
        local fullType = item and item.getFullType and string.lower(tostring(item:getFullType())) or ""
        return fullType == "base.pliers" and (not item.isBroken or item:isBroken() ~= true)
    end) ~= nil
end

local function getElectricalLevel(playerObj)
    if not playerObj or not playerObj.getPerkLevel or not Perks or not Perks.Electricity then return 0 end
    return tonumber(playerObj:getPerkLevel(Perks.Electricity) or 0) or 0
end

local function awardElectricalXp(playerObj, amount)
    local xp = playerObj and playerObj.getXp and playerObj:getXp() or nil
    if xp and xp.AddXP and Perks and Perks.Electricity then
        xp:AddXP(Perks.Electricity, tonumber(amount) or 0)
    end
end

local function collectInventoryType(container, fullType, result)
    if not container or not container.getItems then return end
    local wanted = string.lower(tostring(fullType or ""))
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and string.lower(tostring(item:getFullType())) == wanted then result[#result + 1] = item end
        local nested = item and item.getInventory and item:getInventory() or nil
        if nested then collectInventoryType(nested, fullType, result) end
    end
end

local function repairMaterials(playerObj, spec)
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory or not spec then return nil end
    local selected = {}
    for i = 1, #(spec.materials or {}) do
        local requirement = spec.materials[i]
        local matches = {}
        collectInventoryType(inventory, requirement.type, matches)
        if #matches < (tonumber(requirement.count) or 1) then return nil end
        for index = 1, (tonumber(requirement.count) or 1) do selected[#selected + 1] = matches[index] end
    end
    return selected
end

local function repairMaterialName(fullType)
    local key = "ItemName_" .. tostring(fullType or "")
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return value end
    end
    return tostring(fullType or ""):gsub("^Base%.", "")
end

local function repairMaterialText(spec)
    local labels = {}
    for i = 1, #(spec and spec.materials or {}) do
        local material = spec.materials[i]
        labels[#labels + 1] = repairMaterialName(material.type) .. " x" .. tostring(material.count or 1)
    end
    return table.concat(labels, ", ")
end

local componentUnavailableReason

local function repairUnavailableReason(data, playerObj, part, state)
    local common = componentUnavailableReason(data, playerHasScrewdriver(playerObj))
    if common then return common end
    if not playerHasPliers(playerObj) then return cmText("IGUI_ComputerMod_ComponentNeedPliers", "I need pliers.") end
    local spec = ComputerModComponents.getRepairSpec(part)
    local level = getElectricalLevel(playerObj)
    if not spec or not ComputerModComponents.getRepairTarget(part, state, level) then return cmText("IGUI_ComputerMod_ComponentAlreadyServiced", "This component cannot be repaired further.") end
    if level < (tonumber(spec.level) or 0) then return cmText("IGUI_ComputerMod_ComponentNeedElectricalSkill", "Electrical skill is too low.") end
    if not repairMaterials(playerObj, spec) then return cmText("IGUI_ComputerMod_ComponentNeedRepairMaterials", "Required repair materials are missing.") end
    return nil
end

local function componentRepairTooltip(option, part, state, playerObj, unavailableReason)
    if not option or not ISWorldObjectContextMenu or not ISWorldObjectContextMenu.addToolTip then return end
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    local spec = ComputerModComponents.getRepairSpec(part) or {}
    local condition = math.floor(math.max(0, math.min(100, tonumber(state and state.condition or 0) or 0)) + 0.5)
    local target = ComputerModComponents.getRepairTarget(part, state, getElectricalLevel(playerObj)) or condition
    target = math.floor(target + 0.5)
    local lines = {
        "<RGB:0.85,0.85,0.8>" .. cmText("IGUI_ComputerMod_ComponentCondition", "Condition") .. ": " .. tostring(condition) .. "%",
        "<RGB:0.85,0.85,0.8>" .. cmText("IGUI_ComputerMod_ComponentRepairSkill", "Electrical") .. " " .. tostring(spec.level or 0),
        "<RGB:0.85,0.85,0.8>" .. repairMaterialText(spec),
        "<RGB:0.85,0.85,0.8>" .. cmText("IGUI_ComputerMod_ComponentRepairEffect", "Result / maximum") .. ": " .. tostring(target) .. "% / " .. tostring(spec.cap or 100) .. "%",
        "<RGB:0.85,0.85,0.8>" .. cmText("IGUI_ComputerMod_ComponentRepairTools", "Screwdriver and pliers required.")
    }
    if unavailableReason then table.insert(lines, 1, "<RGB:1,0.25,0.2>" .. unavailableReason) end
    tooltip.description = table.concat(lines, " <LINE> ")
    option.toolTip = tooltip
end

local function getComponentInventoryItems(playerObj)
    local result = {}
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    forEachInventoryItem(inventory, function(item)
        local part = item and item.getFullType and ComputerModComponents.getPartByItemType(item:getFullType()) or nil
        if part then result[#result + 1] = {item = item, part = part} end
        return false
    end)
    return result
end

local function componentTooltip(option, state, unavailableReason)
    if not option or not ISWorldObjectContextMenu or not ISWorldObjectContextMenu.addToolTip then return end
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    local lines = {}
    if state then
        local condition = math.floor(math.max(0, math.min(100, tonumber(state.condition or 0) or 0)) + 0.5)
        lines[#lines + 1] = "<RGB:0.85,0.85,0.8>" .. cmText("IGUI_ComputerMod_ComponentCondition", "Condition") .. ": " .. tostring(condition) .. "%"
    end
    if unavailableReason then lines[#lines + 1] = "<RGB:1,0.25,0.2>" .. unavailableReason end
    lines[#lines + 1] = "<RGB:0.85,0.85,0.8>" .. cmText("IGUI_ComputerMod_ComponentScrewdriverRequired", "Screwdriver required.")
    tooltip.description = table.concat(lines, " <LINE> ")
    option.toolTip = tooltip
end

componentUnavailableReason = function(data, hasScrewdriver)
    if data and data.ComputerModPowerOn == true then return cmText("IGUI_ComputerMod_ComponentTurnOff", "Turn off the computer first.") end
    if not hasScrewdriver then return cmText("IGUI_ComputerMod_ComponentNeedScrewdriver", "I need a screwdriver.") end
    return nil
end

local function ensureComputerComponents(computer)
    local definition = ComputerModComputerTypes.getDefinition(computer)
    local data = ComputerModComputerTypes.getData(computer)
    if not data or data.ComputerModNetworkTerminal == true then return data end
    ComputerModComputerTypes.ensureIdentity(computer, data, definition)
    local wasActivated = data.ComputerModMetaInitialized == true
    if ComputerModComponents.ensure(data, ComputerModComponents.getComputerSeed(data, computer), wasActivated, ComputerModComponents.getWorldAgeHours()) then
        ComputerModComputerTypes.transmitData(computer)
    end
    return data
end

local function addDisabledComponentEntry(menu, text)
    local option = menu:addOption(text)
    option.notAvailable = true
    return option
end

local function addComponentMenus(subMenu, worldobjects, player, computer, data)
    local playerObj = getSpecificPlayer(player)
    local hasScrewdriver = playerHasScrewdriver(playerObj)
    local unavailableReason = componentUnavailableReason(data, hasScrewdriver)
    local componentsOption = subMenu:addOption(cmText("ContextMenu_ComputerMod_Components", "Components"))
    local componentsMenu = ISContextMenu:getNew(subMenu)
    subMenu:addSubMenu(componentsOption, componentsMenu)

    local installRoot = componentsMenu:addOption(cmText("ContextMenu_ComputerMod_InstallComponent", "Install"))
    local installMenu = ISContextMenu:getNew(componentsMenu)
    componentsMenu:addSubMenu(installRoot, installMenu)
    local inventoryParts = getComponentInventoryItems(playerObj)
    local installCount = 0
    for i = 1, #inventoryParts do
        local entry = inventoryParts[i]
        if ComputerModComponents.isPartCompatible(entry.part, data) and data.ComputerModComponents[entry.part.id] == nil then
            local state = ComputerModComponents.readStateFromItem(entry.item, entry.part.id)
            local label = ComputerModComponents.getPartName(entry.part)
            if state then label = label .. " (" .. tostring(math.floor((state.condition or 0) + 0.5)) .. "%)" end
            local option = installMenu:addOption(label, worldobjects, ComputerContextMenu.installComponent, player, computer, entry.part.id, entry.item)
            if unavailableReason then option.notAvailable = true end
            componentTooltip(option, state, unavailableReason)
            installCount = installCount + 1
        end
    end
    if installCount == 0 then addDisabledComponentEntry(installMenu, cmText("IGUI_ComputerMod_NoComponentsToInstall", "No compatible parts in inventory.")) end

    local repairRoot = componentsMenu:addOption(cmText("ContextMenu_ComputerMod_RepairComponent", "Repair"))
    local repairMenu = ISContextMenu:getNew(componentsMenu)
    componentsMenu:addSubMenu(repairRoot, repairMenu)
    local repairCount = 0
    for i = 1, #ComputerModComponents.parts do
        local part = ComputerModComponents.parts[i]
        local state = data.ComputerModComponents[part.id]
        local spec = ComputerModComponents.getRepairSpec(part)
        if spec and ComputerModComponents.isPartCompatible(part, data) and type(state) == "table" and (tonumber(state.condition) or 0) < (tonumber(spec.cap) or 100) then
            local label = ComputerModComponents.getPartName(part) .. " (" .. tostring(math.floor((state.condition or 0) + 0.5)) .. "%)"
            local reason = repairUnavailableReason(data, playerObj, part, state)
            local option = repairMenu:addOption(label, worldobjects, ComputerContextMenu.repairComponent, player, computer, part.id)
            if reason then option.notAvailable = true end
            componentRepairTooltip(option, part, state, playerObj, reason)
            repairCount = repairCount + 1
        end
    end
    if repairCount == 0 then addDisabledComponentEntry(repairMenu, cmText("IGUI_ComputerMod_NoComponentsToRepair", "No components need service.")) end

    local removeRoot = componentsMenu:addOption(cmText("ContextMenu_ComputerMod_RemoveComponent", "Remove"))
    local removeMenu = ISContextMenu:getNew(componentsMenu)
    componentsMenu:addSubMenu(removeRoot, removeMenu)
    local removeCount = 0
    for i = 1, #ComputerModComponents.parts do
        local part = ComputerModComponents.parts[i]
        local state = data.ComputerModComponents[part.id]
        if ComputerModComponents.isPartCompatible(part, data) and type(state) == "table" then
            local label = ComputerModComponents.getPartName(part) .. " (" .. tostring(math.floor((state.condition or 0) + 0.5)) .. "%)"
            local option = removeMenu:addOption(label, worldobjects, ComputerContextMenu.removeComponent, player, computer, part.id)
            if unavailableReason then option.notAvailable = true end
            componentTooltip(option, state, unavailableReason)
            removeCount = removeCount + 1
        end
    end
    if removeCount == 0 then addDisabledComponentEntry(removeMenu, cmText("IGUI_ComputerMod_NoComponentsInstalled", "No components installed.")) end
end

local function isComputerSpriteName(spriteName)
    local value = spriteName and string.lower(tostring(spriteName)) or ""
    return value == "appliances_com_01_72"
        or value == "appliances_com_01_73"
        or value == "appliances_com_01_74"
        or value == "appliances_com_01_75"
        or value == "appliances_com_01_76"
        or value == "appliances_com_01_77"
        or value == "appliances_com_01_78"
        or value == "appliances_com_01_79"
end

local computerScreenOnSprites = {
    appliances_com_01_72 = "appliances_com_01_76",
    appliances_com_01_73 = "appliances_com_01_77",
    appliances_com_01_74 = "appliances_com_01_78",
    appliances_com_01_75 = "appliances_com_01_79"
}

local computerScreenOffSprites = {
    appliances_com_01_76 = "appliances_com_01_72",
    appliances_com_01_77 = "appliances_com_01_73",
    appliances_com_01_78 = "appliances_com_01_74",
    appliances_com_01_79 = "appliances_com_01_75"
}

local function getComputerSpriteName(object)
    local sprite = object and object.getSprite and object:getSprite() or nil
    return sprite and sprite.getName and sprite:getName() or nil
end

local function isComputerObject(object)
    return ComputerModComputerTypes.isComputer(object)
end

local function hydrateNetworkTerminal(object)
    if not object or not object.getModData or not ComputerModNetwork or not ComputerModNetwork.getTerminalForObject then return nil end
    local definition = ComputerModComputerTypes.getDefinition(object)
    if not definition or definition.id ~= "desktop" then return nil end
    local terminal = ComputerModNetwork.getTerminalForObject(object)
    if not terminal then return nil end
    local data = object:getModData()
    if not data then return nil end
    local store = ComputerModNetwork.getStore and ComputerModNetwork.getStore() or nil
    local terminalStore = store and store.terminals and store.terminals[terminal.id] or nil
    data.ComputerModNetworkTerminal = true
    data.ComputerModNetworkTerminalId = terminal.id
    data.ComputerModNetworkTerminalLabel = terminal.label
    data.ComputerModNetworkRepaired = terminalStore and terminalStore.repaired == true or false
    data.ComputerModMetaInitialized = true
    data.ComputerModOSInstalled = true
    data.ComputerModFactoryReset = false
    data.ComputerModPasswordEnabled = false
    data.ComputerModUsername = data.ComputerModUsername or "Network Admin"
    return terminal
end

local function forEachWorldObject(objects, callback)
    if not objects or not callback then return end
    if type(objects) == "table" then
        for _, object in pairs(objects) do
            if object and callback(object) == true then return true end
        end
        return false
    end
    if objects.size and objects.get then
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object and callback(object) == true then return true end
        end
    end
    return false
end

local function addComputerCandidates(objects, candidates, seen)
    if not objects or not objects.size or not objects.get then return end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object and not seen[object] and isComputerObject(object) then
            hydrateNetworkTerminal(object)
            seen[object] = true
            candidates[#candidates + 1] = object
        end
    end
end

local function findClickedOrNearbyComputer(worldobjects, playerObj)
    local anchorSquare = nil
    local directComputer = nil
    forEachWorldObject(worldobjects, function(object)
        if isComputerObject(object) then
            hydrateNetworkTerminal(object)
            directComputer = object
            return true
        end
        if not anchorSquare and object.getSquare then anchorSquare = object:getSquare() end
        return false
    end)
    if directComputer then return directComputer end
    if not anchorSquare and playerObj and playerObj.getSquare then anchorSquare = playerObj:getSquare() end
    if not anchorSquare or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end

    local candidates = {}
    local seen = {}
    local anchorX = anchorSquare:getX()
    local anchorY = anchorSquare:getY()
    local anchorZ = anchorSquare:getZ()
    for dx = -2, 2 do
        for dy = -2, 2 do
            local square = cell:getGridSquare(anchorX + dx, anchorY + dy, anchorZ)
            if square then
                if square.getObjects then
                    addComputerCandidates(square:getObjects(), candidates, seen)
                end
                if square.getSpecialObjects then
                    addComputerCandidates(square:getSpecialObjects(), candidates, seen)
                end
                if square.getWorldObjects then
                    addComputerCandidates(square:getWorldObjects(), candidates, seen)
                end
            end
        end
    end

    local bestComputer = nil
    local bestScore = nil
    for i = 1, #candidates do
        local computer = candidates[i]
        if isPlayerNearComputer(playerObj, computer) then
            local clickDX = computer:getX() - anchorX
            local clickDY = computer:getY() - anchorY
            local playerDX = playerObj:getX() - computer:getX()
            local playerDY = playerObj:getY() - computer:getY()
            local score = (clickDX * clickDX + clickDY * clickDY) * 100 + playerDX * playerDX + playerDY * playerDY
            if not bestScore or score < bestScore then
                bestComputer = computer
                bestScore = score
            end
        end
    end
    return bestComputer
end

local function syncComputerWorldScreen(object, powerOn)
    if not object then return end
    local spriteName = getComputerSpriteName(object)
    if not spriteName then
        if ComputerModScreenGlow and ComputerModScreenGlow.syncObject then
            ComputerModScreenGlow.syncObject(object, powerOn)
        end
        return
    end
    local value = string.lower(tostring(spriteName))
    local nextSpriteName = nil
    if powerOn then
        nextSpriteName = computerScreenOnSprites[value]
    else
        nextSpriteName = computerScreenOffSprites[value]
    end
    if not nextSpriteName or nextSpriteName == spriteName then
        if ComputerModScreenGlow and ComputerModScreenGlow.syncObject then
            ComputerModScreenGlow.syncObject(object, powerOn)
        end
        return
    end
    local changed = false
    if object.setSpriteFromName then
        changed = pcall(function() object:setSpriteFromName(nextSpriteName) end)
    elseif object.setSprite and getSprite then
        local sprite = getSprite(nextSpriteName)
        if sprite then
            changed = pcall(function() object:setSprite(sprite) end)
        end
    end
    if changed and object.transmitUpdatedSpriteToClients then
        pcall(function() object:transmitUpdatedSpriteToClients() end)
    end
    if ComputerModScreenGlow and ComputerModScreenGlow.syncObject then
        ComputerModScreenGlow.syncObject(object, powerOn)
    end
end

function ComputerContextMenu.doMenu(player, context, worldobjects, test)
    if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance:isVisible() then return end

    local clickedComputer = findClickedOrNearbyComputer(worldobjects, getSpecificPlayer(player))

    if clickedComputer then
        local definition = ComputerModComputerTypes.getDefinition(clickedComputer)
        local data = ComputerModComputerTypes.getData(clickedComputer)
        hydrateNetworkTerminal(clickedComputer)
        data = ComputerModComputerTypes.getData(clickedComputer) or data
        ComputerModComputerTypes.ensureIdentity(clickedComputer, data, definition)
        if not data or data.ComputerModNetworkTerminal ~= true then
            syncComputerWorldScreen(clickedComputer, data and data.ComputerModPowerOn == true)
        end
        local rootLabel = data and data.ComputerModNetworkTerminal == true and cmText("ContextMenu_ComputerMod_NetworkTerminal", "Network Terminal")
            or definition and cmText(definition.contextNameKey or "ContextMenu_ComputerMod_Computer", definition.contextName or "Computer")
            or cmText("ContextMenu_ComputerMod_Computer", "Computer")
        local rootOption = context:addOption(rootLabel)
        if rootOption then
            rootOption.iconTexture = computerMenuTexture
        end
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(rootOption, subMenu)
        local isTerminal = data and data.ComputerModNetworkTerminal == true
        if not isTerminal then data = ensureComputerComponents(clickedComputer) end
        local terminalRepaired = isTerminal and isNetworkTerminalRepaired(data)
        if data and data.ComputerModPowerOn then
            subMenu:addOption(cmText("ContextMenu_ComputerMod_ResumeSession", "Resume Session"), worldobjects, ComputerContextMenu.openComputerUI, player, clickedComputer)
        else
            subMenu:addOption(cmText("ContextMenu_ComputerMod_TurnOn", "Turn On"), worldobjects, ComputerContextMenu.openComputerUI, player, clickedComputer)
        end
        if isTerminal and not terminalRepaired then
            local repairOption = subMenu:addOption(cmText("IGUI_ComputerMod_UI_Repair_Relay", "Repair Relay"), worldobjects, ComputerContextMenu.openRelayRepairUI, player, clickedComputer)
            local unavailableReason = getRelayRepairUnavailableReason(getSpecificPlayer(player))
            if unavailableReason then
                repairOption.notAvailable = true
            end
            addRelayRepairTooltip(repairOption, unavailableReason)
        end
        local mountedGame = getMountedDiscGame(data)
        local mountedLabel = data and data.ComputerModMountedCDLabel or nil
        local playerObj = getSpecificPlayer(player)
        if isTerminal then
            return
        end
        addComponentMenus(subMenu, worldobjects, player, clickedComputer, data)
        if definition and type(definition.addContextMenu) == "function" then
            pcall(definition.addContextMenu, subMenu, worldobjects, player, clickedComputer, data)
        end
        if mountedGame then
            subMenu:addOption(cmText("ContextMenu_ComputerMod_RemoveCD", "Remove CD") .. ": " .. (mountedLabel or gameDiscLabels[mountedGame] or "CD"), worldobjects, ComputerContextMenu.removeGameCD, player, clickedComputer, mountedGame)
        else
            local discs = ComputerContextMenu.getPlayerGameDiscs(playerObj)
            for i = 1, #discs do
                local disc = discs[i]
                subMenu:addOption(cmText("ContextMenu_ComputerMod_InsertCD", "Insert CD") .. ": " .. disc.label, worldobjects, ComputerContextMenu.insertGameCD, player, clickedComputer, disc.gameId, disc.fullType, disc.label)
            end
        end
    end
end

function ComputerContextMenu.installComponent(worldobjects, player, computer, partId, item)
    local playerObj = getSpecificPlayer(player)
    local data = ComputerModComputerTypes.getData(computer)
    if not data or data.ComputerModNetworkTerminal == true or data.ComputerModPowerOn == true or not playerHasScrewdriver(playerObj) then return end
    if isClient and isClient() then
        ComputerModComponentsClient.requestInstall(playerObj, computer, partId, item)
        return
    end
    local state = ComputerModComponents.readStateFromItem(item, partId)
    local container = item and item.getContainer and item:getContainer() or nil
    if not state or not container or data.ComputerModComponents[partId] ~= nil then return end
    container:Remove(item)
    ComputerModComponents.attachPart(data, partId, state)
    ComputerModComputerTypes.transmitData(computer)
    if playerObj and playerObj.Say then playerObj:Say(cmText("IGUI_ComputerMod_ComponentInstalled", "Component installed.")) end
end

function ComputerContextMenu.removeComponent(worldobjects, player, computer, partId)
    local playerObj = getSpecificPlayer(player)
    local data = ComputerModComputerTypes.getData(computer)
    if not data or data.ComputerModNetworkTerminal == true or data.ComputerModPowerOn == true or not playerHasScrewdriver(playerObj) then return end
    if isClient and isClient() then
        ComputerModComponentsClient.requestRemove(playerObj, computer, partId)
        return
    end
    local part = ComputerModComponents.getPart(partId)
    local state = part and ComputerModComponents.detachPart(data, partId) or nil
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    local item = state and inventory and inventory:AddItem(part.itemType) or nil
    if not item then
        if state then ComputerModComponents.attachPart(data, partId, state) end
        return
    end
    ComputerModComponents.writeStateToItem(item, partId, state)
    ComputerModComputerTypes.transmitData(computer)
    if playerObj and playerObj.Say then playerObj:Say(cmText("IGUI_ComputerMod_ComponentRemoved", "Component removed.")) end
end

function ComputerContextMenu.repairComponent(worldobjects, player, computer, partId)
    local playerObj = getSpecificPlayer(player)
    local data = ComputerModComputerTypes.getData(computer)
    local part = ComputerModComponents.getPart(partId)
    local state = data and type(data.ComputerModComponents) == "table" and data.ComputerModComponents[partId] or nil
    local spec = ComputerModComponents.getRepairSpec(part)
    if not playerObj or not data or data.ComputerModNetworkTerminal == true or repairUnavailableReason(data, playerObj, part, state) or not spec then return end
    ISTimedActionQueue.add(ISComputerModRepairComponent:new(playerObj, player, computer, partId, spec, getElectricalLevel(playerObj), ComputerContextMenu.finishComponentRepair))
end

function ComputerContextMenu.finishComponentRepair(player, computer, partId)
    local playerObj = getSpecificPlayer(player)
    local data = ComputerModComputerTypes.getData(computer)
    local part = ComputerModComponents.getPart(partId)
    local state = data and type(data.ComputerModComponents) == "table" and data.ComputerModComponents[partId] or nil
    local spec = ComputerModComponents.getRepairSpec(part)
    if not playerObj or not data or repairUnavailableReason(data, playerObj, part, state) or not spec then return end
    if isClient and isClient() then
        ComputerModComponentsClient.requestRepair(playerObj, computer, partId)
        return
    end
    local materials = repairMaterials(playerObj, spec)
    if not materials then return end
    for i = 1, #materials do
        local container = materials[i] and materials[i].getContainer and materials[i]:getContainer() or nil
        if container and container.Remove then container:Remove(materials[i]) end
    end
    if ComputerModComponents.repair(data, partId, getElectricalLevel(playerObj)) then
        awardElectricalXp(playerObj, tonumber(spec.xp) or 8)
        ComputerModComputerTypes.transmitData(computer)
        if playerObj.Say then playerObj:Say(cmText("IGUI_ComputerMod_ComponentRepaired", "Component repaired.")) end
    end
end

function ComputerContextMenu.openRelayRepairUI(worldobjects, player, computer)
    local playerObj = getSpecificPlayer(player)
    if not isPlayerNearComputer(playerObj, computer) then
        ComputerModRelayRepairUI.showWarning(player, cmText("IGUI_ComputerMod_Closer", "I need to get closer."))
        return
    end
    local data = computer and computer.getModData and computer:getModData() or nil
    if not data or data.ComputerModNetworkTerminal ~= true or isNetworkTerminalRepaired(data) then return end
    local unavailableReason = getRelayRepairUnavailableReason(playerObj)
    if unavailableReason then
        ComputerModRelayRepairUI.showWarning(player, unavailableReason)
        return
    end
    if not hasComputerPower(computer) then
        ComputerModRelayRepairUI.showWarning(player, cmText("IGUI_ComputerMod_NoPower", "No power."))
        return
    end
    ComputerModRelayRepairUI.open(player, computer)
end

function ComputerContextMenu.getPlayerGameDiscs(playerObj)
    local discs = {}
    if not playerObj or not playerObj.getInventory then return discs end
    local inventory = playerObj:getInventory()
    if not inventory or not inventory.getItems then return discs end
    local items = inventory:getItems()
    local seen = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local disc = getDiscEntryFromItem(item)
        if disc then
            local key = tostring(disc.gameId) .. "::" .. tostring(disc.fullType) .. "::" .. tostring(disc.label)
            if not seen[key] then
                discs[#discs + 1] = disc
                seen[key] = true
            end
        end
    end
    return discs
end

function ComputerContextMenu.openComputerUI(worldobjects, player, computer)
    local playerObj = getSpecificPlayer(player)
    if not isPlayerNearComputer(playerObj, computer) then
        playerObj:Say(cmText("IGUI_ComputerMod_Closer", "I need to get closer."))
        return
    end
    hydrateNetworkTerminal(computer)
    local data = ComputerModComputerTypes.getData(computer)
    if not hasComputerPower(computer) then
        if playerObj and playerObj.Say then
            playerObj:Say(cmText("IGUI_ComputerMod_NoPower", "No power."))
        end
        return
    end

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local uiW = 649
    local uiH = 560
    if ComputerScreenUI and ComputerScreenUI.getDisplayProfile then
        local profile = ComputerScreenUI.getDisplayProfile(screenW, screenH, data and data.ComputerModUIScale or nil)
        uiW = profile and profile.uiW or uiW
        uiH = profile and profile.uiH or uiH
    elseif ComputerScreenUI and ComputerScreenUI.getRecommendedScale then
        local uiScale = ComputerScreenUI.getRecommendedScale(screenW, screenH)
        uiW = math.floor(649 * uiScale + 0.5)
        uiH = math.floor(560 * uiScale + 0.5)
    end
    local x = math.floor((screenW - uiW) / 2)
    local y = math.floor((screenH - uiH) / 2)
    x = math.max(0, math.min(x, math.max(0, screenW - uiW)))
    y = math.max(0, math.min(y, math.max(0, screenH - uiH)))
    local ui = ComputerScreenUI:new(x, y, player, computer)
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    ui:setVisible(true)
    if ui.claimComputerJoypadFocus then
        ui:claimComputerJoypadFocus()
    end
    if ui.disableComputerSpaceShove then
        ui:disableComputerSpaceShove()
    end
end

function ComputerContextMenu.insertGameCD(worldobjects, player, computer, gameId, itemFullType, discLabel)
    local playerObj = getSpecificPlayer(player)
    if not isPlayerNearComputer(playerObj, computer) then
        playerObj:Say(cmText("IGUI_ComputerMod_Closer", "I need to get closer."))
        return
    end
    if not computer then return end
    local data = ComputerModComputerTypes.getData(computer)
    if data and data.ComputerModNetworkTerminal == true then return end
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    local targetItem = nil
    if inventory and inventory.getItems then
        local items = inventory:getItems()
        local fallbackItem = nil
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local itemType = item and item.getFullType and item:getFullType() or nil
            local targetType = itemFullType or gameDiscItems[gameId]
            if itemType and targetType and string.lower(itemType) == string.lower(targetType) then
                local itemData = item.getModData and item:getModData() or nil
                local itemLabel = itemData and itemData.ComputerModDiscLabel and tostring(itemData.ComputerModDiscLabel) or (item.getDisplayName and tostring(item:getDisplayName() or "") or "")
                fallbackItem = fallbackItem or item
                if not discLabel or discLabel == "" or itemLabel == discLabel then
                    targetItem = item
                    break
                end
            end
        end
        targetItem = targetItem or fallbackItem
    end
    if not targetItem then
        if playerObj and playerObj.Say then
            playerObj:Say(cmText("IGUI_ComputerMod_NeedDisc", "I need the disc first."))
        end
        return
    end
    data = ComputerModComputerTypes.getData(computer)
    if data.ComputerModMountedCD then
        if playerObj and playerObj.Say then
            playerObj:Say(cmText("IGUI_ComputerMod_DiscInsertedAlready", "A disc is already inserted."))
        end
        return
    end
    if isClient and isClient() and sendClientCommand then
        local args = getComputerCommandArgs(computer)
        if not args then return end
        args.gameId = gameId
        args.label = discLabel or ""
        if targetItem and targetItem.getID then
            local ok, itemId = pcall(function() return targetItem:getID() end)
            if ok and itemId ~= nil then args.itemId = itemId end
        end
        sendClientCommand(playerObj, "ComputerModCD", "InsertDisc", args)
        return
    end
    data.ComputerModMountedCD = gameId
    data.ComputerModMountedCDItem = targetItem and targetItem.getFullType and targetItem:getFullType() or itemFullType or gameDiscItems[gameId]
    local targetData = targetItem and targetItem.getModData and targetItem:getModData() or nil
    data.ComputerModMountedCDLabel = (targetData and targetData.ComputerModDiscLabel) or (targetItem and targetItem.getDisplayName and targetItem:getDisplayName()) or discLabel or gameDiscLabels[gameId] or "CD"
    data.ComputerModMountedCDContents = {}
    if targetItem and targetItem.getModData then
        local itemData = targetItem:getModData()
        if itemData and type(itemData.ComputerModDiscContents) == "table" then
            data.ComputerModMountedCDContents = cloneDiscContents(itemData.ComputerModDiscContents)
        end
    end
    if inventory and inventory.Remove then
        inventory:Remove(targetItem)
        syncInventoryItem(inventory, targetItem, false)
        if inventory.setDrawDirty then
            pcall(function() inventory:setDrawDirty(true) end)
        end
    end
    playComputerUISound("ComputerCDEject", playerObj)
    ComputerModComputerTypes.transmitData(computer)
    if playerObj and playerObj.Say then
        playerObj:Say(cmText("IGUI_ComputerMod_CDInserted", "CD inserted."))
    end
end

function ComputerContextMenu.removeGameCD(worldobjects, player, computer, gameId)
    local playerObj = getSpecificPlayer(player)
    if not isPlayerNearComputer(playerObj, computer) then
        playerObj:Say(cmText("IGUI_ComputerMod_Closer", "I need to get closer."))
        return
    end
    if not computer then return end
    local data = ComputerModComputerTypes.getData(computer)
    if data and data.ComputerModNetworkTerminal == true then return end
    local mountedGame = getMountedDiscGame(data)
    if not mountedGame or (mountedGame ~= gameId and data.ComputerModMountedCD ~= gameId) then
        return
    end
    if isClient and isClient() and sendClientCommand then
        local args = getComputerCommandArgs(computer)
        if not args then return end
        sendClientCommand(playerObj, "ComputerModCD", "EjectDisc", args)
        return
    end
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    local returnedDisc = nil
    if inventory and inventory.AddItem then
        returnedDisc = returnDiscToPlayer(playerObj, inventory, data.ComputerModMountedCDItem or gameDiscItems[mountedGame], data.ComputerModMountedCDLabel, data.ComputerModMountedCDContents)
    end
    if not returnedDisc then
        if playerObj and playerObj.Say then
            playerObj:Say(cmText("IGUI_ComputerMod_CDActionFailed", "The CD drive operation failed."))
        end
        return
    end
    data.ComputerModMountedCD = nil
    data.ComputerModMountedCDItem = nil
    data.ComputerModMountedCDLabel = nil
    data.ComputerModMountedCDContents = nil
    playComputerUISound("ComputerCDEject", playerObj)
    ComputerModComputerTypes.transmitData(computer)
    if playerObj and playerObj.Say then
        playerObj:Say(cmText("IGUI_ComputerMod_CDRemoved", "CD removed."))
    end
end

Events.OnFillWorldObjectContextMenu.Add(ComputerContextMenu.doMenu)
