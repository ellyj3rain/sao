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

LSFixAction = ISBaseTimedAction:derive("LSFixAction");

function LSFixAction:isValid()
	return self.obj and self.obj:getObjectIndex() ~= -1
end

function LSFixAction:waitToStart()
	self.character:faceThisObject(self.obj)
	return self.character:shouldBeTurning()
end

function LSFixAction:update()
	self.character:faceThisObject(self.obj)

    self.character:setMetabolicTarget(Metabolics.UsingTools);
end

function LSFixAction:start()
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Low")
	self.character:reportEvent("EventLootItem")
	self.sound = self.character:playSound("GeneratorRepair")
end

function LSFixAction:stop()
	self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self);
end

function LSFixAction:perform()
	self.character:stopOrTriggerSound(self.sound)

	if self.data['isBroken'] then self.data['isBroken'] = false; end
	self.data['repairList'] = false
	LSUtil.doInvCooldown(self.obj, self.data)
	LSSync.transmit(self.obj)
	LSUtil.giveXP(self.character, "Maintenance", 5, nil)

	ISBaseTimedAction.perform(self)
end

function LSFixAction:complete()
	LSUtil.consumeItemsOnChar(self.character, self.itemList)
	return true
end

function LSFixAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.baseTime/(math.max(1,self.character:getPerkLevel(Perks.Maintenance))/10)
end

function LSFixAction:new(character, obj, data, itemList, baseTime)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character;
	o.obj = obj;
	o.itemList = itemList
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.baseTime = baseTime
	o.data = data
	o.maxTime = o:getDuration()
    o.caloriesModifier = 4;
	return o;
end
