-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "TimedActions/ISBaseTimedAction"

ISComputerModRepairComponent = ISBaseTimedAction:derive("ISComputerModRepairComponent")

function ISComputerModRepairComponent:isValid()
    if not self.character or not self.computer or not self.computer.getSquare or not self.computer:getSquare() then return false end
    local data = ComputerModComputerTypes and ComputerModComputerTypes.getData and ComputerModComputerTypes.getData(self.computer) or nil
    local state = data and type(data.ComputerModComponents) == "table" and data.ComputerModComponents[self.partId] or nil
    local part = ComputerModComponents and ComputerModComponents.getPart and ComputerModComponents.getPart(self.partId) or nil
    return data ~= nil and data.ComputerModPowerOn ~= true and ComputerModComponents.getRepairTarget(part, state, self.electricalLevel) ~= nil
end

function ISComputerModRepairComponent:waitToStart()
    self.character:faceThisObject(self.computer)
    return self.character:shouldBeTurning()
end

function ISComputerModRepairComponent:update()
    self.character:faceThisObject(self.computer)
    if Metabolics and Metabolics.UsingTools then self.character:setMetabolicTarget(Metabolics.UsingTools) end
end

function ISComputerModRepairComponent:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function ISComputerModRepairComponent:perform()
    ISBaseTimedAction.perform(self)
end

function ISComputerModRepairComponent:complete()
    if self.callback then self.callback(self.playerIndex, self.computer, self.partId) end
    return true
end

function ISComputerModRepairComponent:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    local base = tonumber(self.repairSpec and self.repairSpec.time) or 480
    return math.max(180, base - (tonumber(self.electricalLevel) or 0) * 18)
end

function ISComputerModRepairComponent:new(character, playerIndex, computer, partId, repairSpec, electricalLevel, callback)
    local o = ISBaseTimedAction.new(self, character)
    o.playerIndex = playerIndex
    o.computer = computer
    o.partId = partId
    o.repairSpec = repairSpec
    o.electricalLevel = electricalLevel
    o.callback = callback
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
