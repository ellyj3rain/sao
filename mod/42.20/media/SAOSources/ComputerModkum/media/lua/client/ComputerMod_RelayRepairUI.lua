require "ISUI/ISCollapsableWindow"
require "ISUI/ISContextMenu"
require "ISUI/ISInventoryItem"
require "ISUI/ISInventoryPane"
require "ISUI/ISModalDialog"
require "Entity/ISUI/Controls/ISItemSlot"
require "ComputerMod_RelayRepair"

ComputerModRelayRepairUI = ISCollapsableWindow:derive("ComputerModRelayRepairUI")
ComputerModRelayRepairUI.instance = nil

local previewItems = {}
local scriptItems = {}

local function text(key, fallback)
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return value end
    end
    return fallback or key
end

local function itemCount(inventory, fullType)
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
        if item and item.getFullType and item:getFullType() == fullType then
            count = count + 1
        end
    end
    return count
end

local function getPreviewItem(fullType)
    if previewItems[fullType] ~= nil then
        return previewItems[fullType] or nil
    end
    local item = nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, created = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
        if ok then item = created end
    end
    previewItems[fullType] = item or false
    return item
end

local function getScriptItem(fullType)
    if scriptItems[fullType] ~= nil then
        return scriptItems[fullType] or nil
    end
    local item = nil
    if ScriptManager and ScriptManager.instance and ScriptManager.instance.getItem then
        local ok, created = pcall(function() return ScriptManager.instance:getItem(fullType) end)
        if ok then item = created end
    end
    scriptItems[fullType] = item or false
    return item
end

local function getItemName(fullType)
    local scriptItem = getScriptItem(fullType)
    if scriptItem and scriptItem.getDisplayName then
        local ok, name = pcall(function() return scriptItem:getDisplayName() end)
        if ok and name and name ~= "" then return tostring(name) end
    end
    local item = getPreviewItem(fullType)
    if item and item.getDisplayName then
        local ok, name = pcall(function() return item:getDisplayName() end)
        if ok and name and name ~= "" then return tostring(name) end
    end
    return tostring(fullType or ""):gsub("^Base%.", "")
end

local function fitText(value, maxWidth)
    local result = tostring(value or "")
    if not getTextManager then return result end
    local manager = getTextManager()
    if manager:MeasureStringX(UIFont.Small, result) <= maxWidth then return result end
    while string.len(result) > 1 and manager:MeasureStringX(UIFont.Small, result .. "...") > maxWidth do
        local index = string.len(result)
        while index > 1 do
            local byte = string.byte(result, index)
            if not byte or byte < 128 or byte >= 192 then break end
            index = index - 1
        end
        result = string.sub(result, 1, index - 1)
    end
    return result .. "..."
end

function ComputerModRelayRepairUI.showWarning(playerNum, message)
    local width = 340
    local height = 120
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local modal = ISModalDialog:new(math.floor((screenWidth - width) / 2), math.floor((screenHeight - height) / 2), width, height, tostring(message or ""), false, nil, nil, playerNum)
    modal:initialise()
    modal:addToUIManager()
    modal:bringToTop()
end

function ComputerModRelayRepairUI:initialise()
    ISCollapsableWindow.initialise(self)
end

function ComputerModRelayRepairUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.slots = {}
    local titleHeight = self:titleBarHeight()
    local startX = 28
    local startY = titleHeight + 68
    local cellWidth = 128
    local rowHeight = 132
    local slotSize = 72
    for i = 1, #ComputerModRelayRepair.parts do
        local part = ComputerModRelayRepair.parts[i]
        local column = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local slot = ISItemSlot:new(
            startX + column * cellWidth,
            startY + row * rowHeight,
            slotSize,
            slotSize,
            nil,
            self,
            ComputerModRelayRepairUI.onSlotItemsDropped,
            nil,
            ComputerModRelayRepairUI.verifySlotItem,
            ComputerModRelayRepairUI.onSlotClicked,
            nil
        )
        slot.requirement = part
        slot.requirementKey = part.key
        slot:initialise()
        slot:instantiate()
        slot:setCharacter(self.playerObj)
        local scriptItem = getScriptItem(part.fullType)
        if scriptItem then
            slot:setStoredScriptItem(scriptItem)
        else
            slot:setStoredItem(getPreviewItem(part.fullType))
        end
        slot.allowDrop = true
        self:addChild(slot)
        self.slots[#self.slots + 1] = slot
    end
    self:updateSlotState()
end

function ComputerModRelayRepairUI:getInventory()
    return self.playerObj and self.playerObj.getInventory and self.playerObj:getInventory() or nil
end

function ComputerModRelayRepairUI:getInventoryCount(fullType)
    return itemCount(self:getInventory(), fullType)
end

function ComputerModRelayRepairUI:getPartProgress(key)
    return tonumber(self.progress and self.progress[key] or 0) or 0
end

function ComputerModRelayRepairUI:getPartMissing(key)
    local part = ComputerModRelayRepair.getPart(key)
    if not part then return 0 end
    return math.max(0, part.count - self:getPartProgress(key))
end

function ComputerModRelayRepairUI:getElectricalLevel()
    if self.playerObj and self.playerObj.getPerkLevel and Perks and Perks.Electricity then
        return tonumber(self.playerObj:getPerkLevel(Perks.Electricity) or 0) or 0
    end
    if self.serverElectricalLevel ~= nil then
        return tonumber(self.serverElectricalLevel or 0) or 0
    end
    return 0
end

function ComputerModRelayRepairUI:getTerminalArgs()
    local data = self.computer and self.computer.getModData and self.computer:getModData() or nil
    local args = {terminalId = data and data.ComputerModNetworkTerminalId or nil}
    local square = self.computer and self.computer.getSquare and self.computer:getSquare() or nil
    if square then
        args.x = square:getX()
        args.y = square:getY()
        args.z = square:getZ()
    end
    return args
end

function ComputerModRelayRepairUI:sendCommand(command, args)
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModNetwork", command, args or {})
        return true
    end
    if ComputerModNetworkServer and ComputerModNetworkServer.onClientCommand then
        ComputerModNetworkServer.onClientCommand("ComputerModNetwork", command, self.playerObj or getPlayer(), args or {})
        return true
    end
    return false
end

function ComputerModRelayRepairUI:requestProgress()
    self.pending = true
    if not self:sendCommand("RequestRepairProgress", self:getTerminalArgs()) then
        self.pending = false
        ComputerModRelayRepairUI.showWarning(self.playerNum, text("IGUI_ComputerMod_UI_Network_relay_refused_the_request", "Network relay refused the request."))
    end
end

function ComputerModRelayRepairUI:depositRequirement(key, count)
    if self.pending then return end
    local missing = self:getPartMissing(key)
    local amount = math.min(missing, math.max(0, math.floor(tonumber(count or 0) or 0)))
    if amount <= 0 then return end
    local args = self:getTerminalArgs()
    args.requirementKey = key
    args.count = amount
    self.pending = true
    if not self:sendCommand("DepositRepairItem", args) then
        self.pending = false
        ComputerModRelayRepairUI.showWarning(self.playerNum, text("IGUI_ComputerMod_UI_Network_relay_refused_the_request", "Network relay refused the request."))
    end
end

function ComputerModRelayRepairUI.verifySlotItem(target, slot, item)
    if not target or not slot or not slot.requirement or target.pending then return false end
    if target:getPartMissing(slot.requirement.key) <= 0 then return false end
    return item and item.getFullType and item:getFullType() == slot.requirement.fullType
end

function ComputerModRelayRepairUI.onSlotItemsDropped(target, slot, items)
    if not target or not slot or not slot.requirement then return end
    local count = 0
    for i = 1, #(items or {}) do
        local item = items[i]
        if item and item.getFullType and item:getFullType() == slot.requirement.fullType then
            count = count + 1
        end
    end
    target:depositRequirement(slot.requirement.key, count)
end

function ComputerModRelayRepairUI.onSlotClicked(target, slot, isRightClick, isShift)
    if not target or not slot or not slot.requirement or not isRightClick then return end
    local context = ISContextMenu.get(target.playerNum, getMouseX(), getMouseY())
    local missing = target:getPartMissing(slot.requirement.key)
    local available = target:getInventoryCount(slot.requirement.fullType)
    local option = context:addOption(getText("ContextMenu_AddAll"), target, ComputerModRelayRepairUI.depositFromContext, slot.requirement.key)
    if missing <= 0 or available <= 0 or target.pending then
        option.notAvailable = true
    end
end

function ComputerModRelayRepairUI.depositFromContext(target, key)
    if not target then return end
    target:depositRequirement(key, target:getPartMissing(key))
end

function ComputerModRelayRepairUI:updateSlotState()
    if not self.slots then return end
    for i = 1, #self.slots do
        local slot = self.slots[i]
        local part = slot.requirement
        local current = self:getPartProgress(part.key)
        local complete = current >= part.count
        slot.overrideItemCount = tostring(current) .. "/" .. tostring(part.count)
        slot.countColor = complete and {r=0.3, g=1, b=0.35, a=1} or {r=1, g=1, b=1, a=1}
        slot.borderColor = complete and {r=0.15, g=0.75, b=0.2, a=1} or slot.borderColorOrig
        local tooltip = getItemName(part.fullType) .. " " .. slot.overrideItemCount
        slot.toolTipText = tooltip
        slot.toolTipTextItem = tooltip
    end
end

function ComputerModRelayRepairUI:getReasonText(reason)
    if reason == "power" then
        return text("IGUI_ComputerMod_NoPower", "No power.")
    end
    if reason == "distance" then
        return text("IGUI_ComputerMod_Closer", "I need to get closer.")
    end
    if reason == "item" then
        return text("IGUI_ComputerMod_UI_Required_items_missing", "Required items missing.")
    end
    if reason == "network" then
        return text("IGUI_ComputerMod_UI_Network_is_already_online", "Network is already online.")
    end
    return text("IGUI_ComputerMod_UI_Network_relay_refused_the_request", "Network relay refused the request.")
end

function ComputerModRelayRepairUI:handleServerProgress(args)
    args = args or {}
    self.pending = false
    if type(args.progress) == "table" then
        self.progress = ComputerModRelayRepair.normalizeProgress(args.progress)
        self:updateSlotState()
    end
    if args.electricalLevel ~= nil then
        self.serverElectricalLevel = tonumber(args.electricalLevel or 0) or 0
    end
    if args.success == false then
        ComputerModRelayRepairUI.showWarning(self.playerNum, self:getReasonText(args.reason))
        if args.reason == "terminal" or args.reason == "distance" or args.reason == "repaired" or args.reason == "grid" or args.reason == "network" then
            self:close()
        end
        return
    end
    if args.complete == true or args.repaired == true then
        self:close()
    end
end

function ComputerModRelayRepairUI:prerender()
    ISCollapsableWindow.prerender(self)
    local titleHeight = self:titleBarHeight()
    local electrical = self:getElectricalLevel()
    local required = ComputerModRelayRepair.requiredElectricalLevel
    local skillReady = electrical >= required
    local skillColor = skillReady and {r=0.3, g=1, b=0.35} or {r=1, g=0.3, b=0.2}
    self:drawText(text("IGUI_ComputerMod_UI_Electrical", "Electrical") .. " " .. tostring(electrical) .. "/" .. tostring(required), 18, titleHeight + 14, skillColor.r, skillColor.g, skillColor.b, 1, UIFont.Small)
    self:drawText(text("IGUI_ComputerMod_UI_Required_service_parts", "Required service parts:"), 18, titleHeight + 42, 0.86, 0.86, 0.8, 1, UIFont.Small)
    local cellWidth = 128
    local startX = 28
    local startY = titleHeight + 68
    local rowHeight = 132
    local slotSize = 72
    for i = 1, #ComputerModRelayRepair.parts do
        local part = ComputerModRelayRepair.parts[i]
        local column = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local label = fitText(getItemName(part.fullType), cellWidth - 8)
        self:drawTextCentre(label, startX + column * cellWidth + math.floor(slotSize / 2), startY + row * rowHeight + slotSize + 6, 0.78, 0.78, 0.74, 1, UIFont.Small)
    end
    self:drawText("Drag & Drop  |  RMB: " .. getText("ContextMenu_AddAll"), 18, self.height - 28, 0.7, 0.7, 0.66, 1, UIFont.Small)
    if self.pending then
        self:drawTextRight("...", self.width - 18, self.height - 28, 0.95, 0.78, 0.3, 1, UIFont.Small)
    end
end

function ComputerModRelayRepairUI:update()
    ISCollapsableWindow.update(self)
    self:updateSlotState()
    local square = self.computer and self.computer.getSquare and self.computer:getSquare() or nil
    if not square or not self.playerObj or not self.playerObj.getX then
        self:close()
        return
    end
    if self.playerObj:getZ() ~= square:getZ()
        or math.abs(self.playerObj:getX() - square:getX()) > 4
        or math.abs(self.playerObj:getY() - square:getY()) > 4
    then
        self:close()
    end
end

function ComputerModRelayRepairUI:onKeyPress(key)
    if key == Keyboard.KEY_ESCAPE then
        self:close()
        return true
    end
    if ISCollapsableWindow.onKeyPress then
        return ISCollapsableWindow.onKeyPress(self, key)
    end
    return false
end

function ComputerModRelayRepairUI:close()
    if self.slots then
        for i = 1, #self.slots do
            if self.slots[i].deactivateToolTip then
                self.slots[i]:deactivateToolTip()
            end
        end
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if ComputerModRelayRepairUI.instance == self then
        ComputerModRelayRepairUI.instance = nil
    end
end

function ComputerModRelayRepairUI:new(x, y, playerNum, computer)
    local width = 540
    local height = 390
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.playerObj = getSpecificPlayer(playerNum)
    o.computer = computer
    o.progress = {}
    o.pending = false
    o.title = text("IGUI_ComputerMod_UI_Repair_Relay", "Repair Relay")
    o.resizable = false
    o.pin = true
    if o.setWantKeyEvents then o:setWantKeyEvents(true) end
    return o
end

function ComputerModRelayRepairUI.open(playerNum, computer)
    if ComputerModRelayRepairUI.instance then
        ComputerModRelayRepairUI.instance:close()
    end
    local width = 540
    local height = 390
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local ui = ComputerModRelayRepairUI:new(math.floor((screenWidth - width) / 2), math.floor((screenHeight - height) / 2), playerNum, computer)
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    ui:bringToTop()
    ComputerModRelayRepairUI.instance = ui
    ui:requestProgress()
    return ui
end
