--------------------------------------------------------------------------------------------------
--		----	  |			  |			|		 |				|    --    |      ----			--
--		----	  |			  |			|		 |				|    --	   |      ----			--
--		----	  |		-------	   -----|	 ---------		-----          -      ----	   -------
--		----	  |			---			|		 -----		------        --      ----			--
--		----	  |			---			|		 -----		-------	 	 ---      ----			--
--		----	  |		-------	   ----------	 -----		-------		 ---      ----	   -------
--			|	  |		-------			|		 -----		-------		 ---		  |			--
--			|	  |		-------			|	 	 -----		-------		 ---		  |			--
--------------------------------------------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"

LSAddFuelAction = ISBaseTimedAction:derive("LSAddFuelAction");

function LSAddFuelAction:isValid()
	return true
end

function LSAddFuelAction:waitToStart()
	return false
end

function LSAddFuelAction:update()

    self.character:setMetabolicTarget(Metabolics.HeavyDomestic);
end

function LSAddFuelAction:start()
	self:setActionAnim("refuelgascan")
	self:setOverrideHandModels(self.fuelItem:getStaticModel(), nil)
	self.sound = self.character:playSound(self.data['fuelingSound'] or "GeneratorAddFuel")
	
	if not self.data or not self.data['fuelConsumption'] or type(self.data['fuelConsumption']) ~= "number" or self.data['fuelConsumption'] == 0 then self:forceStop(); end
end

function LSAddFuelAction:stop()
	self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self);
end

function LSAddFuelAction:perform()
	self.character:stopOrTriggerSound(self.sound)
	self:setOverrideHandModels(nil, nil)

	if self.fuelAdded >= 1 then self.data['fuelUses'] = math.min(self.currentUses+self.fuelAdded,self.data['fuelContainer'][1]); end
	self.data['fuelDelta'] = self.newTankDelta
	if not isServer() or isClient() then
		local currentUses = self.data['fuelUses']
		if LSInv['OnRefuel'..self.name] and self.fuelAdded >= 1 then
			LSInv['OnRefuel'..self.name](self.invention, self.invention:getModData().movableData, self.name)
		else
			LSInv.doDataTransmit(self.invention, self.data)
		end
		if currentUses < self.tankTotal then
			local newFuelItem, lastAction = LSUtil.getItemAndEquip(self.character, self.data['fuelTag'], self.data['fuelItem'], true, false, self.isDrainable, self, self.fluidCont)
			if newFuelItem then
				ISTimedActionQueue.addAfter(lastAction, self:new(self.character, self.invention, self.name, self.data, currentUses, newFuelItem, self.actionTime))
			end
		end
	end

	ISBaseTimedAction.perform(self);
end

function LSAddFuelAction:complete()
	local removed
	if self.isDrainable then
		LSUtil.debugDiagnostics("/shared/TimedActions/LSAddFuelAction", "self:complete",{
		['self.fuelItem']=self.fuelItem,
		['self.fuelItem:getFullType()']=self.fuelItem and self.fuelItem.getFullType and self.fuelItem:getFullType(),
		['self.itemUses']=self.itemUses,
		})
		self.character:removeFromHands(self.fuelItem)
		LSUtil.consumeItemsOnChar(self.character, {[self.fuelItem:getFullType()]=self.itemUses})
	elseif self.fluidCont then
		self.fluidCont:adjustAmount(self.itemNewAmount)
	else
		local cont = self.character:getInventory()
		cont:Remove(self.fuelItem)
		sendRemoveItemFromContainer(cont, self.fuelItem)
		removed = true
	end

	if not removed then self.fuelItem:syncItemFields(); end
	return true

--[[
    local endFuel = 0;
    while self.petrol and self.petrol:getCurrentUsesFloat() > 0 and self.item:getCurrentUsesFloat() < 1 do
		self.item:setUsedDelta(math.min(self.item:getCurrentUsesFloat() + self.item:getUseDelta() * 5, 1));
        self.petrol:Use();
    end
	self.petrol:syncItemFields()
]]--
end

function LSAddFuelAction:getDuration()
	local currentFuel = self.currentUses
	
	self.itemStart = 1 -- if not isDrainable and not fluidCont then uses the whole item
	self.itemUseDelta = self.data['fuelUseDelta'] or 1 -- how much fuel delta each item use adds  
	
	self.tankTotal = self.data['fuelContainer'][1]
	self.tankTarget = math.floor(self.tankTotal-currentFuel)
	self.tankDelta = self.data['fuelDelta'] or 0 -- how much fuel delta is in the tank, when it reachs fuelConsumption adds 1 tankFuel and resets
	self.tankConsumption = self.data['fuelConsumption'] -- how much tankDelta is required to add 1 unit to tankFuel
	
	if self.isDrainable then
		self.itemStart = math.max(1, self.fuelItem:getCurrentUses())
	
	elseif self.fluidCont then
		self.itemStart = LSUtil.getItemFluidAmount(self.fuelItem, self.data['fuelLiquid'])
	end

	local totalItemDelta = self.itemStart*self.itemUseDelta
	local neededDelta = (self.tankTarget*self.tankConsumption)-self.tankDelta
	if neededDelta <= 0 then self.tankDelta = 0; neededDelta = (self.tankTarget*self.tankConsumption); end
	
	local deltaToApply = math.min(totalItemDelta, neededDelta)
	self.fuelAdded = math.floor((self.tankDelta+deltaToApply)/self.tankConsumption)
	self.newTankDelta = (self.tankDelta+deltaToApply)%self.tankConsumption
	
	local deltaUsed = self.fuelAdded * self.tankConsumption - self.tankDelta
	local itemUnitsUsed = deltaUsed / self.itemUseDelta
	self.itemNewAmount = math.floor(self.itemStart - itemUnitsUsed)
	self.itemUses = math.floor(itemUnitsUsed)
	if not self.fluidCont then self.itemUses = math.max(1, self.itemUses); end -- failsafe for drainables and whole items

	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function LSAddFuelAction:new(character, invention, name, data, currentUses, fuelItem, actionTime)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
    o.invention = invention
	o.name = name
	o.data = data
	o.currentUses = currentUses
	o.fuelItem = fuelItem
	o.isDrainable = not o.data['fuelLiquid'] and o.fuelItem.IsDrainable and o.fuelItem:IsDrainable()
	o.fluidCont = o.data['fuelLiquid'] and LSUtil.getFluidContainer(o.fuelItem)
	o.actionTime = actionTime
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end