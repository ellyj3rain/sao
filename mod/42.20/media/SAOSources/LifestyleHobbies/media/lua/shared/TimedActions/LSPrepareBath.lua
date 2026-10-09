require "TimedActions/ISBaseTimedAction"

LSPrepareBath = ISBaseTimedAction:derive("LSPrepareBath");

local function getXYTexture(Facing, bubbleBath)

	if not Facing then return false, false, false, false; end

	if (Facing == "S") and (bubbleBath > 0) then
		return -1, 1, "LS_Fog_14", "LS_Fog_15"
	elseif Facing == "S" then
		return -1, 1, "LS_Fog_10", "LS_Fog_11"
	elseif (Facing == "E") and (bubbleBath > 0) then
		return -1, 1, "LS_Fog_12", "LS_Fog_13"
	elseif Facing == "E" then
		return -1, 1, "LS_Fog_8", "LS_Fog_9"
	elseif (Facing == "N") and (bubbleBath > 0) then
		return -1, 1, "LS_Fog_14", "LS_Fog_15"
	elseif Facing == "N" then
		return -1, 1, "LS_Fog_10", "LS_Fog_11"
	elseif (Facing == "W") and (bubbleBath > 0) then
		return -1, 1, "LS_Fog_12", "LS_Fog_13"
	elseif Facing == "W" then
		return -1, 1, "LS_Fog_8", "LS_Fog_9"
	end

	return false, false, false, false

end

function LSPrepareBath:isValid()
	--local flushed = true
	
	--if self.showerObject:getModData().NeedsFlush then
		--flushed = false
	--end
	
	return true
end

function LSPrepareBath:waitToStart()
	--self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.bathObject)

	return self.character:shouldBeTurning()
end

function LSPrepareBath:update()

	
	if (self.doSoundInt >= 2) and (self.doSoundInt < 3) then

		if self.gameSoundLoop == 0 then
			self.gameSoundLoop = self.character:getEmitter():playSound("Tub_Common_Fill");
			--self:setActionAnim("WashFace")
		end
		self.doSoundInt = 3
	elseif self.doSoundInt < 2 then
		self.doSoundInt = self.doSoundInt + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	end


	if (self.count >= 40) and not (self.count >= 50) then
		self.count = 50

-------WATER

	if not self.waterObj then
		local offSetX, offSetY, textureM, textureS
		offSetX, offSetY, textureM, textureS = getXYTexture(self.isFacing, self.isBubbleBath)
		
		if not offSetX then self:forceComplete(); end

		self.tileSqr = getCell():getGridSquare(self.bathObject:getX(), self.bathObject:getY(), self.bathObject:getZ())
		self.tileSqrClone = getCell():getGridSquare(self.bathBottomObj:getX(), self.bathBottomObj:getY(), self.bathBottomObj:getZ())
		--self.waterObj = IsoObject.new(self.tileSqr, "LS_Shower_" .. self.isFacing .. "_0")
		--self.waterObj = IsoObject.new(self.tileSqr, textureM)
		--self.waterObjClone = IsoObject.new(self.tileSqrClone, textureS)
		self.bathObject:setOverlaySprite(textureM, 1, 1, 1, 1)
		self.bathBottomObj:setOverlaySprite(textureS, 1, 1, 1, 1)
		--self.waterObj:setCustomColor(1, 1, 1, 1)
		--self.waterObj:renderlast()
		--self.waterObj:setOffsetX(offSetX)
		--self.waterObj:setOffsetY(offSetY)
		--self.waterObjClone:setOffsetX(offSetX)
		--self.waterObjClone:setOffsetY(offSetY)

		--self.waterObj:setAlpha(0.3)
		--self.waterObjClone:setAlpha(0.3)
		--self.tileSqr:AddTileObject(self.waterObj)	
		--self.tileSqrClone:AddTileObject(self.waterObjClone)	
		--self.waterObj:transmitModData()
		--self.waterObj:transmitCompleteItemToServer()
		--self.waterObjClone:transmitCompleteItemToServer()
		
		self.waterObj = true
	end

	else

		self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)

	end

	

end

function LSPrepareBath:start()
	
	self:setOverrideHandModels(nil, nil)
	
	--if self.showerType == "Deluxe" then
	--	self.character:getEmitter():playSound("Faucet_Deluxe")
	--	self.showerCleanVal = 0.04
	--else
	self.character:getEmitter():playSound("Faucet_Deluxe")
	--end
	self:setActionAnim("Loot")

	--self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed or 0


end

function LSPrepareBath:stop()
	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
		self.character:getEmitter():playSound("Faucet_Deluxe")
	end
	if self.waterObj then
		self.bathObject:setOverlaySprite(self.mainTubOverlay)
		self.bathBottomObj:setOverlaySprite(self.subTubOverlay)
	end
	--[[
	if isClient() and self.tileSqr and self.waterObj then
		sledgeDestroy(self.waterObj);
		sledgeDestroy(self.waterObjClone);
		--self.tileSqr:transmitRemoveItemFromSquare(self.waterObj)
		--self.tileSqr:RemoveTileObject(self.waterObj)
	elseif self.tileSqr and self.waterObj then
		self.tileSqr:transmitRemoveItemFromSquare(self.waterObj)
		self.tileSqr:RemoveTileObject(self.waterObj)
		self.tileSqrClone:transmitRemoveItemFromSquare(self.waterObjClone)
		self.tileSqrClone:RemoveTileObject(self.waterObjClone)
		--self.waterObj:transmitCompleteItemToServer()
	end
	]]--
	--if self.showerType == "Deluxe" then
	--	self.character:getEmitter():playSound("Faucet_Deluxe")
	--else
		
	--end
	self.character:getEmitter():playSound("Tub_End")

    ISBaseTimedAction.stop(self);
		
end

function LSPrepareBath:perform()
	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
		self.character:getEmitter():playSound("Faucet_Deluxe")
	end
	if self.waterObj then
		self.bathObject:setOverlaySprite(self.mainTubOverlay)
		self.bathBottomObj:setOverlaySprite(self.subTubOverlay)
	end
	--[[
	if isClient() and self.tileSqr and self.waterObj then
		sledgeDestroy(self.waterObj);
		sledgeDestroy(self.waterObjClone);
		--self.tileSqr:transmitRemoveItemFromSquare(self.waterObj)
		--self.tileSqr:RemoveTileObject(self.waterObj)
	elseif self.tileSqr and self.waterObj then
		self.tileSqr:transmitRemoveItemFromSquare(self.waterObj)
		self.tileSqr:RemoveTileObject(self.waterObj)
		self.tileSqrClone:transmitRemoveItemFromSquare(self.waterObjClone)
		self.tileSqrClone:RemoveTileObject(self.waterObjClone)
		--self.waterObj:transmitCompleteItemToServer()
	end
	]]--
	ISBaseTimedAction.perform(self);

end

function LSPrepareBath:complete()
	return true
end

function LSPrepareBath:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 300
end

function LSPrepareBath:new(character, bathObject, bathBottomObj, waterConsumption, isFacing, isBubbleBath)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.bathObject = bathObject
	o.bathBottomObj = bathBottomObj
	o.waterConsumption = waterConsumption
	o.gameSoundLoop = 0
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.doSoundInt = 0
	o.doActionAnim = false
	o.count = 0
	o.waterObj = false
	o.isFacing = isFacing
	o.tileSqr = false
	o.tileSqrClone = false
	o.waterObjClone = false
	o.isBubbleBath = isBubbleBath
	if bathObject:getOverlaySprite() then o.mainTubOverlay = bathObject:getOverlaySprite():getName(); else o.mainTubOverlay = nil; end
	if bathBottomObj:getOverlaySprite() then o.subTubOverlay = bathBottomObj:getOverlaySprite():getName(); else o.subTubOverlay = nil; end
	return o;
end

return LSPrepareBath