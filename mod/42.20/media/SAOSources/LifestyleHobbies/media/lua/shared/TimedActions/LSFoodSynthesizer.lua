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

LSFoodSynthesizer = ISBaseTimedAction:derive("LSFoodSynthesizer");

function LSFoodSynthesizer:isValid()
	return true
end

function LSFoodSynthesizer:waitToStart()
	self.action:setUseProgressBar(true)
	self.character:faceThisObject(self.obj);
	return self.character:shouldBeTurning();
end

function LSFoodSynthesizer:update()
	if self.character:isSitOnGround() then self:forceStop(); end
	self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function LSFoodSynthesizer:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	local sound = (self.command == "run" and "BEEP_short") or "MACHINE_OPEN"
	self.character:playSound(sound)
end

function LSFoodSynthesizer:stop()
    ISBaseTimedAction.stop(self);
	if self.command ~= "run" then self.character:playSound("MACHINE_CLOSE"); end
end

local function getFoodItems(character, itemList, foodQuality)
	local playerInv = character:getInventory()
	if itemList[2] ~= "Lifestyle.PasteGrub" then
		local items = playerInv:AddItems(itemList[2], itemList[1])
		sendAddItemsToContainer(playerInv, items)
		return
	end
	local poisonPower
	if foodQuality[3] > 0 then
		local poisonChance = ZombRand(foodQuality[3])+1
		if poisonChance <= foodQuality[3] then
			poisonPower = 5+ZombRand(15)
		end
	end
	for n=1, itemList[1] do
		local item = instanceItem(itemList[2])
		item:setHungChange(foodQuality[1])
		item:setUnhappyChange(foodQuality[2])
		if poisonPower then item:setFoodSicknessChange(poisonPower); end
		playerInv:AddItem(item)
		playerInv:setDrawDirty(true)
		sendAddItemToContainer(playerInv, item)
		sendItemStats(item)
	end
end

local function consumeItems(itemList, target)
	local consumed = 0
	for x=0,itemList:size() - 1 do
		local item = itemList:get(x)
		local itemCont = item and item:getContainer()
		if itemCont then
			consumed = consumed+item:getActualWeight()
			itemCont:Remove(item)
			itemCont:setDrawDirty(true)
			sendRemoveItemFromContainer(itemCont, item)
			if consumed >= target then break; end
		end
	end
	return consumed
end

function LSFoodSynthesizer:perform()
	if LSSync.isNotServer() then
		local sound = (self.command == "run" and "BEEP_long") or "MACHINE_CLOSE"
		self.character:playSound(sound)
		--[[
		if self.command == "getFood" and self.invData['foodReady'][2] == "Lifestyle.PasteRuined" then
			local delay = 0
			while delay < 20 do
				delay = delay+1
			end
			local txt, num = "Man", 8
			if self.character:isFemale() then txt, num = "Woman", 10; end
			LSUtil.playSoundCharacter(self.character, "_Yuck0", nil, nil, nil, nil, nil, nil)
		end
		]]--
	end
	ISBaseTimedAction.perform(self);
end

local function getObjOverlayNew(key)
	local t = {
		["LS_Inventions_16"] = "LS_Inventions_18",
		["LS_Inventions_17"] = "LS_Inventions_19",
	}
	return t[key]
end

function LSFoodSynthesizer:complete()
	local objData = self.obj:getModData().movableData
	objData['inventionData'] = self.invData
	if self.command == "addFood" then
		objData['inventionData']['storedWeight'] = math.min(self.invData['foodContainer'],LSUtil.round(self.invData['storedWeight']+consumeItems(LSInv.getSynthesizerFoodItems(self.character:getInventory(), self.invData['acceptRotten']),self.invData['foodContainer']-self.invData['storedWeight']),2))
	elseif self.command == "getFood" then
		getFoodItems(self.character, self.invData['foodReady'], self.invData['foodQuality'])
		objData['inventionData']['foodReady'] = false
		self.obj:setOverlaySprite(nil, true)
		self.obj:transmitUpdatedSpriteToClients()
	else
		objData['inventionData']['storedWeight'] = math.max(0, LSUtil.round(self.invData['storedWeight']-self.invData['foodUsage'],2))
		objData['inventionData']['running'] = true
		local runTime = ZombRand(20)+10
		objData['inventionData']['foodTime'] = runTime+getGameTime():getMinutesStamp()
		local overlay = getObjOverlayNew(self.spriteName)
		self.obj:setOverlaySprite(overlay, true)
		self.obj:transmitUpdatedSpriteToClients()
	end

	self.obj:transmitModData()
	
	return true
end

function LSFoodSynthesizer:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return (self.command == "run" and 30) or 60
end

function LSFoodSynthesizer:new(character, obj, spriteName, invData, command)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.obj = obj
	o.spriteName = spriteName
	o.invData = invData
	o.command = command
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = true;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	return o;
end
