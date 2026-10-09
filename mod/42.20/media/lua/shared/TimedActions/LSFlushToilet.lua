-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end

require "TimedActions/ISBaseTimedAction"

LSFlushToilet = ISBaseTimedAction:derive("LSFlushToilet");

function LSFlushToilet:isValid()
	return true;
end

function LSFlushToilet:waitToStart()
	if self.doInstant then return false; end
	self.action:setUseProgressBar(false)
	if isClient() then
		local cX = self.character:getX()
		local cY = self.character:getY()
		--self.character:setLy(cY)
		--self.character:setLx(cX)
		self.character:setY(cY)
		self.character:setX(cX)
	end

	self.character:faceThisObject(self.toiletObject)
	return self.character:shouldBeTurning()
end

function LSFlushToilet:update()
	if not self.doInstant then self.character:faceThisObject(self.toiletObject); end
end

local function isValid(character, obj)
	local spriteName = obj and obj.getSprite and obj:getSprite() and obj:getSprite():getName()
	return LSUtil.getValidCharacter(character) and LSUtil.isValidObj(obj, spriteName)
end

local function canFlush(obj, waterUse)
	return LSUtil.objHasWater(obj, waterUse) and
	obj:hasModData() and obj:getModData().movableData.needFlush
end

function LSFlushToilet:start()
	if not self.soundFlush then self.soundFlush = LSHygiene.TF.getFlushSound(self.toiletType); end
	--if not canFlush(self.toiletObject, self.waterUsage) then self:forceStop(); end
	if not self.doInstant then self:setActionAnim("Bob_IsFlushing"); end
end

function LSFlushToilet:stop()
    ISBaseTimedAction.stop(self);	
end

function LSFlushToilet:perform()

	if self.toiletObject:getModData().movableData.isClogged and self.toiletObject:getModData().movableData.isClogged >= 0 then

		self.character:getEmitter():playSound("Toilet_Flush_Clogged")
		
		--first we reset the toilet unclog work
		self.toiletObject:getModData().movableData.isClogged = 0
		
		if self.toiletObject:getModData().movableData.condition then
			self.toiletObject:getModData().movableData.condition = self.toiletObject:getModData().movableData.condition + 20
			if self.toiletObject:getModData().movableData.condition > 100 then
				self.toiletObject:getModData().movableData.condition = 100
			end
		else
			self.toiletObject:getModData().movableData.condition = 40
		end
		
		local thisDirtSprite

		if self.toiletObject:getModData().movableData.dirtyLevel then
			local dirtSprite, dirtSprite2, dirtSprite3 = LSHygiene.TF.getDirtySprites(self.toiletObject)
			if self.toiletObject:getModData().movableData.dirtyLevel == 0 and self.toiletObject:getModData().movableData.condition >= 30 then
				self.toiletObject:getModData().movableData.dirtyLevel = 1
				thisDirtSprite = dirtSprite
			elseif self.toiletObject:getModData().movableData.dirtyLevel == 1 and self.toiletObject:getModData().movableData.condition >= 60 then
				self.toiletObject:getModData().movableData.dirtyLevel = 2
				thisDirtSprite = dirtSprite2
			elseif self.toiletObject:getModData().movableData.dirtyLevel == 2 and self.toiletObject:getModData().movableData.condition >= 90 then
				self.toiletObject:getModData().movableData.dirtyLevel = 3
				thisDirtSprite = dirtSprite3
			end
		else
			self.toiletObject:getModData().movableData.dirtyLevel = 0
		end
		
		if isClient() and thisDirtSprite then
			sendClientCommand("LS", "ModifyOverlaySprite", {{self.toiletObject:getX(),self.toiletObject:getY(),self.toiletObject:getZ(),self.toiletObject:getSprite():getName()}, thisDirtSprite})
			--LSSync.transmit(self.toiletObject)
		elseif isClient() then
			--LSSync.transmit(self.toiletObject)
		elseif thisDirtSprite then
			self.toiletObject:setOverlaySprite(thisDirtSprite, false)
		end
		
		--do more dirt if not max and add brown puddles around the toilet
		LSHygiene.TF.doDirtPuddle(self.toiletObject:getSquare())
	else
		if self.soundFlush then self.character:getEmitter():playSound(self.soundFlush); end
		self.toiletObject:getModData().movableData.needFlush = false
		--self.toiletObject:setWaterAmount(self.toiletObject:getFluidAmount() - self.waterUsage)
	end

	if isClient() then
		LSSync.transmit(self.toiletObject)
	end

	ISBaseTimedAction.perform(self);

end

function LSFlushToilet:complete()
	LSUtil.useObjFluid(self.toiletObject, self.waterUsage)
	return true
end

function LSFlushToilet:getDuration()
	if self.character:isTimedActionInstant() or self.doInstant then
		return 1
	end
	return 40
end

function LSFlushToilet:new(character, toiletObject, toiletType, doInstant)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.toiletObject = toiletObject
	o.toiletType = toiletType
	o.doInstant = doInstant
	o.waterUsage = LSHygiene.TF.getWaterUsage(o.toiletType)
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o;
end