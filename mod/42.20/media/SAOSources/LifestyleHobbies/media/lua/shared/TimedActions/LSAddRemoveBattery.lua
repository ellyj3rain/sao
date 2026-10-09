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

LSAddRemoveBattery = ISBaseTimedAction:derive("LSAddRemoveBattery");

function LSAddRemoveBattery:isValid()
	return not self.data['isBroken']
end

function LSAddRemoveBattery:waitToStart()
	return false
end

function LSAddRemoveBattery:update()

    self.character:setMetabolicTarget(Metabolics.LightDomestic);
end

function LSAddRemoveBattery:start()
	self:setActionAnim(CharacterActionAnims.Disassemble)
	self.sound = self.character:playSound(self.data['fuelingSound'] or "Dismantle")
	self:setOverrideHandModelsString("Screwdriver", nil)
	if not self.data or not self.data['fuelConsumption'] or type(self.data['fuelConsumption']) ~= "number" or self.data['fuelConsumption'] == 0 then self:forceStop(); end
end

function LSAddRemoveBattery:stop()
	self:setOverrideHandModels(nil, nil)
	self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self);
end

function LSAddRemoveBattery:perform()
	self:setOverrideHandModels(nil, nil)
	self.character:stopOrTriggerSound(self.sound)
	if self.hasBattery then
		self.data['fuelUses'] = 0
		self.data['hasBattery'] = false
	else
		self.data['fuelUses'] = math.min(self.batteryPercent,100)
		self.data['hasBattery'] = true
	end

	if LSInv['OnRefuel'..self.name] then -- add/remove battery behavior
		LSInv['OnRefuel'..self.name](self.invention, self.invention:getModData().movableData, self.name)
	else
		LSInv.doDataTransmit(self.invention, self.data)
	end

	ISBaseTimedAction.perform(self);
end

function LSAddRemoveBattery:complete()
	local cont = self.character:getInventory()
	if self.batteryItem then -- delete item
		cont:Remove(self.batteryItem)
		sendRemoveItemFromContainer(cont, self.batteryItem)
	else -- create item
		local itemName = self.spentVersion or self.batteryName
		local newBattery = instanceItem(itemName)
		if newBattery then
			if newBattery.IsDrainable and newBattery:IsDrainable() then
				newBattery:setUsedDelta(self.batteryPercent)
			end
			cont:AddItem(newBattery)
			sendAddItemToContainer(cont, newBattery)
			sendItemStats(newBattery)
		end
	end
	return true
end

function LSAddRemoveBattery:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.data['fuelingBaseTime']
end

function LSAddRemoveBattery:new(character, invention, name, data, batteryItem, batteryName)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
    o.invention = invention
	o.name = name
	o.data = data
	o.batteryItem = batteryItem
	o.batteryName = batteryName
	local add
	if batteryItem then
		local isDrainable = batteryItem.IsDrainable and batteryItem:IsDrainable()
		add = (isDrainable and math.floor(batteryItem:getCurrentUsesFloat()*100)) or 100
		if add <= 1 then add = 0; elseif add >= 99 then add = 100; end
	else
		add = (data['fuelUses'] and math.floor(data['fuelUses']/100)) or 0
		if add < 0.011 then add = 0.011; elseif add > 0.95 then add = 1; end
	end
	o.batteryPercent = add
	o.spentVersion = data['fuelUses'] and data['fuelUses'] < data['fuelContainer'][1] and data['batterySpent']
	o.hasBattery = o.data['hasBattery']
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end