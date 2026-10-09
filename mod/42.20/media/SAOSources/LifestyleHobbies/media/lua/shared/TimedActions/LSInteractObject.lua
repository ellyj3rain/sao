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

LSInteractObject = ISBaseTimedAction:derive("LSInteractObject");

local function applyOverlay(obj, overlayName)
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(), obj:getY(), obj:getZ(), obj:getSprite():getName()}, overlayName})
	else
		obj:setOverlaySprite(overlayName, true)
		obj:transmitUpdatedSpriteToClients()
	end
end

function LSInteractObject:isValid()
	return true;
end

function LSInteractObject:waitToStart()
	self.action:setUseProgressBar(true)
	self.character:faceThisObject(self.obj)
	return self.character:shouldBeTurning()
end

function LSInteractObject:update()

	self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function LSInteractObject:start()
	if self.animName then
		self:setActionAnim(self.animName)
		if self.animVarName then self:setAnimVariable(self.animVarName, self.animVarParam); end
		self:setOverrideHandModels(self.handR, self.handL)
	end
	if self.soundName then self.sound = self.character:playSound(self.soundName); end
	
	if self.fluidArgs and (not self.fluidItem or not self.fluidItem:isInPlayerInventory() or (self.fluidAction ~= "Add" and not LSUtil.itemHasFluid(self.fluidItem, self.fluidName, self.fluidAmount, self.fluidPrimary))) then self:forceStop(); end
end

function LSInteractObject:stop()
	self:stopSound()
	ISBaseTimedAction.stop(self)
end

function LSInteractObject:perform()
	self:stopSound()
	if LSSync.isSingleplayer() then
		if self.dataArgs then
			local movData = self.obj:getModData().movableData
			for k, v in pairs(self.dataArgs) do
				movData[k] = v
			end
			if self.adjObj then
				local adjMovData = self.adjObj:getModData().movableData
				for k, v in pairs(self.dataArgs) do
					adjMovData[k] = v
				end
			end
		end
		if self.fluidItem then
			if self.fluidAction and self.fluidAction == "Remove" then
				self.fluidItem:getFluidContainer():removeFluid(self.fluidAmount, false)
				self.fluidItem:sendSyncEntity(nil)
			end
		end
	end
	ISBaseTimedAction.perform(self)
end

function LSInteractObject:complete()
	if isServer() then
		local ignoreData
		if self.fluidArgs then
			if self.fluidAction and self.fluidAction == "Remove" then
				if not self.fluidItem or self.fluidItem:getFluidContainer():isEmpty() then
					local playerInv = self.character:getInventory()
					local predicateItem = function(item)
						local id = item and item.getID and item:getID()
						return id and id == self.itemID
					end
					self.fluidItem = (self.itemID and playerInv:getFirstEvalRecurse(predicateItem)) or playerInv:getFirstAvailableFluidContainer(self.fluidName)
				end
				if self.fluidItem and not self.fluidItem:getFluidContainer():isEmpty() then
					self.fluidItem:getFluidContainer():removeFluid(self.fluidAmount, false)
					self.fluidItem:sendSyncEntity(nil)
				else
					ignoreData = true
				end
			end
		end
		if not ignoreData and self.dataArgs then
			local movData = self.obj:getModData().movableData
			for k, v in pairs(self.dataArgs) do
				movData[k] = v
			end
			self.obj:transmitModData()
			if self.adjObj then
				local adjMovData = self.adjObj:getModData().movableData
				for k, v in pairs(self.dataArgs) do
					adjMovData[k] = v
				end
				self.adjObj:transmitModData()
			end
		end
	end
	if self.itemList then LSUtil.consumeItemsOnChar(self.character, self.itemList); end
	if self.newObjSprite then
		if self.obj:getSprite():getProperties():has(IsoFlagType.WallOverlay) then
			self.obj:setSpriteFromName(self.newObjSprite)
		else
			self.obj:setSprite(self.newObjSprite)
		end
	end
	if self.newAdjObjSprite then
		if self.adjObj:getSprite():getProperties():has(IsoFlagType.WallOverlay) then -- use setSpriteFromName for wall objects (setSprite won't change properties in their case)
			self.adjObj:setSpriteFromName(self.newAdjObjSprite)
		else
			self.adjObj:setSprite(self.newAdjObjSprite)
		end
	end

	if self.newObjOverlay then applyOverlay(self.obj, self.newObjOverlay); end
	if self.newAdjObjOverlay then applyOverlay(self.adjObj, self.newAdjObjOverlay); end

	if self.newObjSprite then self.obj:transmitUpdatedSpriteToClients(); end
	if self.newAdjObjSprite then self.adjObj:transmitUpdatedSpriteToClients(); end
	return true
end

function LSInteractObject:stopSound()
	if self.sound and self.character:getEmitter():isPlaying(self.sound) then
		self.character:stopOrTriggerSound(self.sound);
	end
end

function LSInteractObject:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.duration
end

function LSInteractObject:new(character, obj, adjObj, args)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.obj = obj
	o.adjObj = adjObj
	o.args = args
	o.duration = args[1]
	o.itemList = args[2]
	o.animArgs = args[3]
	o.fluidArgs = args[4]
	o.spriteArgs = args[5]
	o.syncData = args[6]
	o.dataArgs = args[7]
	if o.syncData then
		o.obj:getModData().movableData = o.syncData
		if o.adjObj then o.adjObj:getModData().movableData = o.syncData; end
	end
	-- anim and sound
	if o.animArgs then
		o.animName = o.animArgs[1]
		o.animVarName = o.animArgs[2]
		o.animVarParam = o.animArgs[3]
		o.handR = o.animArgs[4]
		o.handL = o.animArgs[5]
		o.soundName = o.animArgs[6]
	end
	-- fluid
	if o.fluidArgs then
		o.fluidItem = o.fluidArgs[1]
		o.fluidName = o.fluidArgs[2]
		o.fluidAmount = o.fluidArgs[3]
		o.fluidAction = o.fluidArgs[4]
		o.fluidPrimary = o.fluidArgs[5]
		o.itemID = o.fluidArgs[6]
	end
	-- sprite
	if o.spriteArgs then
		o.newObjSprite = o.spriteArgs[1]
		o.newAdjObjSprite = o.spriteArgs[2]
		o.newObjOverlay = o.spriteArgs[3]
		o.newAdjObjOverlay = o.spriteArgs[4]
	end
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
	o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.caloriesModifier = 0.5
	return o;
end

return LSInteractObject