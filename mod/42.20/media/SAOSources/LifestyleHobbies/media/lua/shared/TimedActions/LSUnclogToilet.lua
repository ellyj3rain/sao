
require "TimedActions/ISBaseTimedAction"

LSUnclogToilet = ISBaseTimedAction:derive("LSUnclogToilet");

local function AddCleaningXP(character)

	local xpChange = 300
	local skillLevel = character:getPerkLevel(Perks.Cleaning)

	if skillLevel == 10 then return; end

	if skillLevel == 0 then skillLevel = 1; end

	if character:hasTrait(CharacterTrait.SLOPPY) then
		xpChange = xpChange*0.5
	end

	xpChange = xpChange*skillLevel

	--character:getXp():AddXP(Perks.Cleaning, xpChange)
	sendClientCommand(character, "LS", "AddXP", {"Cleaning", xpChange})
	
	HaloTextHelper.addTextWithArrow(character, getText("IGUI_HaloNote_XP"), true, 170, 255, 150)

end

function LSUnclogToilet:isValid()
	return true;
end

function LSUnclogToilet:waitToStart()
	self.action:setUseProgressBar(true)
	if isClient() then
		local cX = self.character:getX()
		local cY = self.character:getY()
		--self.character:setLy(cY)
		--self.character:setLx(cX)
		self.character:setY(cY)
		self.character:setX(cX)
	end
	self.character:faceThisObject(self.toiletObject);
	return self.character:shouldBeTurning();
end

function LSUnclogToilet:update()

	self.character:faceThisObject(self.toiletObject)

	if self.count >= self.countTotal then
		self.count = 0
	local soundrandomiser = ZombRand(1, 100)
	local sound = "Broom_Sweep1"
		if self.maxTime <= 500 or (self.maxTime <= 1000 and (self:getJobDelta()*self.maxTime >= self.maxTime/1.5)) or (self.maxTime > 1000 and (self:getJobDelta()*self.maxTime >= self.maxTime/1.2)) then
			if soundrandomiser >=75 then
				sound = "Toilet_Unclog_1"
			elseif soundrandomiser >=50 then
				sound = "Toilet_Unclog_2"
			elseif soundrandomiser >=25 then
				sound = "Toilet_Unclog_3"
			else
				sound = "Toilet_Unclog_4"
			end
		else
			if soundrandomiser >=80 then
				sound = "Toilet_UnclogFull_1"
			elseif soundrandomiser >=64 then
				sound = "Toilet_UnclogFull_2"
			elseif soundrandomiser >=48 then
				sound = "Toilet_UnclogFull_3"
			elseif soundrandomiser >=32 then
				sound = "Toilet_UnclogFull_4"
			elseif soundrandomiser >=16 then
				sound = "Toilet_UnclogFull_5"
			else
				sound = "Toilet_UnclogFull_6"
			end
		end
		self.character:getEmitter():playSound(sound);
	elseif self.maxTime <= 500 or (self.maxTime <= 1000 and (self:getJobDelta()*self.maxTime >= self.maxTime/1.5)) or (self.maxTime > 1000 and (self:getJobDelta()*self.maxTime >= self.maxTime/1.2)) then
		self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)*1.5
	else
		self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	end
	
	self.jobProgress = self:getJobDelta()*self.maxTime
    self.character:setMetabolicTarget(Metabolics.LightWork)

end

function LSUnclogToilet:start()
	self:setActionAnim("Bob_UncloggingToilet")

end

function LSUnclogToilet:stop()

	self.toiletObject:getModData().movableData.isClogged = (self.maxTime - self.jobProgress)

	----debug
		--self.character:Say("toilet unclog progress is " .. tonumber(self.toiletObject:getModData().movableData.isClogged) .. " from a jobdelta of " .. tonumber(self.jobProgress) .. " and maxtime of " .. tonumber(self.maxTime))
	----

	if self.toiletObject:getModData().movableData.isClogged < 0 then self.toiletObject:getModData().movableData.isClogged = false; end

	if isClient() then
		LSSync.transmit(self.toiletObject)
	end

    ISBaseTimedAction.stop(self);
		
end

function LSUnclogToilet:perform()

	self.toiletObject:getModData().movableData.isClogged = false
	LSSync.transmit(self.toiletObject)
	--self.toiletObject:getModData().movableData.isClogged = false
	--if isClient() then
	--	self.toiletObject:transmitModData()
		--self.toiletObject:setOverlaySprite(nil, true)--toilets also get dirty (overlay changes based on a treshold), unclogging shouldn't automatically clean the toilet so don't change the overlay sprite
	--else
		--self.toiletObject:setOverlaySprite(nil, false)
	--end
	--if (self.toiletObject:hasWater() and self.toiletObject:getFluidAmount() >= self.waterUsage) and self.toiletObject:getModData().NeedsFlush then
	LSHygiene.TF.doFlush(self.character, self.toiletObject, self.toiletType, false, true)
		--ToiletFunctions.DoActionFlush(self.character, self.toiletObject, self.toiletType, self.waterUsage)
	--end
	
	AddCleaningXP(self.character)
	
	ISBaseTimedAction.perform(self);

end

function LSUnclogToilet:complete()
	return true
end

function LSUnclogToilet:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function LSUnclogToilet:new(character, toiletObject, toiletType, plungerItem, actionTime)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.toiletObject = toiletObject
	o.toiletType = toiletType
	o.plungerItem = plungerItem
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
	o.actionTime = actionTime
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.count = 0
	o.countTotal = 12--60
	return o;
end

return LSUnclogToilet