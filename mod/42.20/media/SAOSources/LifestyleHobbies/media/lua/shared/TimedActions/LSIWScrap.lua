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

LSIWScrap = ISBaseTimedAction:derive("LSIWScrap");

function LSIWScrap:isValid()
	return true
end

function LSIWScrap:waitToStart()
	self.action:setUseProgressBar(true)
	self.character:faceThisObject(self.obj);
	return self.character:shouldBeTurning();
end

function LSIWScrap:update()
	if self.character:isSitOnGround() then self:forceStop(); end

end

function LSIWScrap:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	self.character:getEmitter():playSound("PutItemInBag")
end

function LSIWScrap:stop()
    ISBaseTimedAction.stop(self);		
end

function LSIWScrap:perform()
	if self.oldID and LSSync.isNotServer() then
		local charData = self.character:getModData()
		charData['invData'] = charData['invData'] or {}
		if charData['invData']['lsWkID'] and charData['invData']['lsWkID'] == self.oldID then
			charData['invData']['lsWkID'] = false
			LSSync.updateClientData(self.character, charData)
		end
	end
	if self.shouldGet then self.character:getInventory():setDrawDirty(true); end
	ISBaseTimedAction.perform(self);
end

function LSIWScrap:complete()
	if self.shouldGet then
		local newItem
		local scriptArgs = self.data['resultType'] == "invItem" and LSInventionDefs.ItemScript[self.data['invName']]
		if self.data['resultType'] == "invObj" or self.data['resultType'] == "obj" then
			newItem = self.character:getInventory():AddItem('Moveables.Moveable')
			newItem:ReadFromWorldSprite(self.data['result'])
		else
			newItem = self.character:getInventory():AddItem(self.data['result'])
			local clothingItem = newItem and newItem:getClothingItem()
			local textureChoices = clothingItem and (clothingItem:hasModel() and clothingItem:getTextureChoices() or clothingItem:getBaseTextures())
			if textureChoices and textureChoices:size() > 1 then
				LSUtil.changeTexture_Item(self.character, newItem, 0)
			end
		end
		
		local moddata = newItem:getModData()
		moddata.movableData = moddata.movableData or {}
		local invData = moddata.movableData
		invData['author'] = self.data['author']
		local customName = self.data['itemCustomName']
		if customName then invData['customName'] = customName; newItem:setName(customName) end
		
		if LSUtil.StringStartWith(self.data['resultType'],"inv") then
			local charData = self.character:getModData()['invData'][self.data['invName']]
			invData['improvementData'] = LSUtil.deepCopy(charData['improvementData'])
			invData['inventionData'] = LSUtil.deepCopy(charData['inventionData'])
		end

		sendAddItemToContainer(self.character:getInventory(), newItem)
		if scriptArgs then
			LSSync.syncItemVal(newItem, invData['inventionData'], self.data['invName'], false, true)
		else
			newItem:syncItemFields()
		end
	end

	if LSUtil.isValidObj(self.obj, "Inv Workbench") and LSUtil.isObjOnSqr(self.obj) then
		local keys = {'lsWkID','author','workType','workPhase','workCost','costFail','isRuined','invName','resultType','result','duration','progress','events','itemCustomName'}
		for n=1, #keys do
			self.data[keys[n]] = false
		end
		LSSync.rewriteData(self.obj, self.data)
		self.obj:setOverlaySprite("", true)
		self.obj:setSprite(self.newSprite)
		self.obj:transmitUpdatedSpriteToClients()
		self.obj:transmitModData()
	end
	return true
end

function LSIWScrap:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 100
end

function LSIWScrap:new(character, obj, oldID, newSprite, shouldGet)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.obj = obj
	o.oldID = oldID
	o.data = o.obj:getModData()
	o.newSprite = newSprite
	o.shouldGet = shouldGet
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.stopOnAim         = true
	o.maxTime = o:getDuration()
	return o;
end
