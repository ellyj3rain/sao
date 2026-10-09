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

LSFixItemAction = ISBaseTimedAction:derive("LSFixItemAction");

function LSFixItemAction:isValid()
	return self.item:isInPlayerInventory() and self.item:isBroken()
end

function LSFixItemAction:waitToStart()
	return false
end

function LSFixItemAction:update()

    self.character:setMetabolicTarget(Metabolics.UsingTools);
end

function LSFixItemAction:start()
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	self.character:reportEvent("EventLootItem")
	self.sound = self.character:playSound("GeneratorRepair")
end

function LSFixItemAction:stop()
	self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self);
end

function LSFixItemAction:perform()
	self.character:stopOrTriggerSound(self.sound)

	LSUtil.doInvCooldown(self.item, self.data)
	if self.data['isBroken'] then self.data['isBroken'] = false; end
	self.data['repairList'] = false
	LSSync.syncItemVal(self.item, self.data, self.item:getType(), {['setBroken']={'isBroken',false},['Condition']=self.item:getConditionMax()})

    -- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self);

end

function LSFixItemAction:complete()
	addXp(self.character, Perks.Maintenance, 5)
	LSUtil.consumeItemsOnChar(self.character, self.itemList)
	return true
end

function LSFixItemAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.baseTime/(math.max(1,self.character:getPerkLevel(Perks.Maintenance))/10)
end

function LSFixItemAction:new(character, item, data, itemList, baseTime)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.item = item
	o.itemList = itemList
	o.baseTime = baseTime
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.data = data
	o.maxTime = o:getDuration()
    o.caloriesModifier = 4;
	return o;
end
