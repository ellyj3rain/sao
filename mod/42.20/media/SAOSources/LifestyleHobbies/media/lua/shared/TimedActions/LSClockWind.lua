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

LSClockWind = ISBaseTimedAction:derive("LSClockWind");

function LSClockWind:isValid()
	return true;
end

function LSClockWind:waitToStart()
	self.action:setUseProgressBar(true)
	self.character:faceThisObject(self.clockObj);
	return self.character:shouldBeTurning();
end

function LSClockWind:update()
	if self.character:isSitOnGround() then self:forceStop(); end
	if self.jobProgress < (self.maxTime*0.35) then
		self.jobProgress = self:getJobDelta()*self.maxTime
	elseif not self.secondPhase then
		self.secondPhase = true
		self.sound = self.character:getEmitter():playSound("GFClock_Wind")
	end

end

function LSClockWind:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	self.character:getEmitter():playSound("PutItemInBag")
end

function LSClockWind:stop()
	if self.sound and self.sound ~= 0 and self.character:getEmitter():isPlaying(self.sound) then
		self.character:getEmitter():stopSound(self.sound);
	end
    ISBaseTimedAction.stop(self);		
end

function LSClockWind:perform()
	self.clockObj:getModData().movableData['active'] = true
	self.clockObj:getModData().movableData['lastWind'] = tonumber(getGameTime():getWorldAgeHours())
	if isClient() then sendClientCommand("LS", "ModifyObjData", {{self.clockObj:getX(),self.clockObj:getY(),self.clockObj:getZ(),self.clockObj:getSprite():getName()}, self.clockObj:getModData().movableData, false}); end
	getSoundManager():playUISound("UI_Painting_Complete")
	ISBaseTimedAction.perform(self);
end

function LSClockWind:complete()
	return true
end

function LSClockWind:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 80
end

function LSClockWind:new(character, clockObj)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.clockObj = clockObj
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = true;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.secondPhase = false
	o.sound = 0
	return o;
end
