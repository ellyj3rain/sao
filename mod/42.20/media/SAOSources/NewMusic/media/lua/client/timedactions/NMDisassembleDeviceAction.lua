require "TimedActions/ISBaseTimedAction"
require "ISUI/ISInventoryPaneContextMenu"
NMDisassembleDeviceAction = ISBaseTimedAction:derive("NMDisassembleDeviceAction")

local function stopSound(action)
    if not (action and action.sound) then
        return
    end
    if action.character and action.character.stopOrTriggerSound then
        pcall(action.character.stopOrTriggerSound, action.character, action.sound)
    elseif action.character and action.character.getEmitter then
        local emitter = action.character:getEmitter()
        if emitter and emitter.stopOrTriggerSound then
            pcall(emitter.stopOrTriggerSound, emitter, action.sound)
        end
    end
    action.sound = nil
end

local function closeDeviceUIForAction(action)
    if not (action and action.player and action.item and NMDeviceUI and NMDeviceUI.closeForItem) then
        return
    end
    local playerNum = action.player.getPlayerNum and action.player:getPlayerNum() or 0
    local itemId = NMCore and NMCore.itemId and NMCore.itemId(action.item) or nil
    local profile = NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(action.item) or nil
    local state = profile and NMDeviceState.peek and NMDeviceState.peek(action.item) or nil
    local uuid = state and state.deviceUUID or nil
    NMDeviceUI.closeForItem(playerNum, itemId, uuid)
end

local function removeWorldItem(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    if square and square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(worldItem)
        return true
    end
    return false
end

local function removeInventoryItem(player, item)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then
        return false
    end
    local container = item and item.getContainer and item:getContainer() or nil
    if container and container.DoRemoveItem then
        container:DoRemoveItem(item)
        return true
    end
    if inv.Remove then
        inv:Remove(item)
        return true
    end
    return false
end

local function hasActionScrewdriver(player)
    return NMDeviceDisassembly
        and NMDeviceDisassembly.findScrewdriverInInventory
        and NMDeviceDisassembly.findScrewdriverInInventory(player) ~= nil
end

local function performSP(player, item)
    local profile = item and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    if not (item and profile and NMDeviceDisassembly.canDisassembleItem(item, profile) and hasActionScrewdriver(player)) then
        return
    end
    local state = NMDeviceState.ensure(item, profile)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then
        return
    end
    local plan = NMDeviceDisassembly.buildPlan(player, item, profile, state)
    if not plan then
        return
    end
    if state then
        local uuid = tostring(state.deviceUUID or "")
        if uuid ~= "" and NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
            pcall(NMPlaybackRuntime.forceStop, player, uuid, "device_disassembled")
        end
        if NMTransitionCommon and NMTransitionCommon.setStopped then
            NMTransitionCommon.setStopped(state, "device_disassembled")
        end
        state.isOn = false
        state.desiredIsOn = false
        state.mediaFullType = nil
        state.mediaEjectFullType = nil
        state.mediaRecordedMediaIndex = nil
        state.headphoneItemFullType = nil
        state.batteryPresent = false
        state.batteryCharge = 0.0
    end
    NMDeviceDisassembly.applyPlanToInventory(player, inv, plan)
    if not removeWorldItem(item) then
        removeInventoryItem(player, item)
    end
end

function NMDisassembleDeviceAction:isValid()
    if not (self.player and self.item) then
        return false
    end
    local profile = NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(self.item) or nil
    return NMDeviceDisassembly.canDisassembleItem(self.item, profile) and hasActionScrewdriver(self.player)
end

function NMDisassembleDeviceAction:update()
    -- No per-tick target tracking needed for inventory/world item dismantle.
end

function NMDisassembleDeviceAction:start()
    self.screwdriver = NMDeviceDisassembly.resolveScrewdriver and NMDeviceDisassembly.resolveScrewdriver(self.player) or nil
    self:setActionAnim("disassembleElectrical")
    self:setOverrideHandModels("Screwdriver", nil)
    self.sound = self.character:playSound("Dismantle")
end

function NMDisassembleDeviceAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function NMDisassembleDeviceAction:perform()
    stopSound(self)
    closeDeviceUIForAction(self)
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() and sendClientCommand then
        local profile = NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(self.item) or nil
        local state = profile and NMDeviceState.ensure(self.item, profile) or nil
        sendClientCommand(self.character, NMCore.NetModule, "device_disassemble", {
            itemId = NMCore.itemId and NMCore.itemId(self.item) or nil,
            uuid = state and state.deviceUUID or nil,
            itemFullType = self.item and self.item.getFullType and self.item:getFullType() or nil
        })
    else
        performSP(self.character, self.item)
    end
    ISBaseTimedAction.perform(self)
end

function NMDisassembleDeviceAction:new(player, item, time)
    local o = ISBaseTimedAction.new(self, player)
    o.player = player
    o.character = player
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = tonumber(time) or 120
    if player and player:isTimedActionInstant() then
        o.maxTime = 1
    end
    o.sound = nil
    o.screwdriver = nil
    return o
end
