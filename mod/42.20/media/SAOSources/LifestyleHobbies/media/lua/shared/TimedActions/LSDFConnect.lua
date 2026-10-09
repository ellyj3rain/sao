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

LSDFConnect = ISBaseTimedAction:derive("LSDFConnect");

--local isPlayingJukeSong = nil;

function LSDFConnect:isValid()
	return true;
end

function LSDFConnect:waitToStart()
	--self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.DiscoBall);
	return self.character:shouldBeTurning();
end

function LSDFConnect:update()


end

function LSDFConnect:start()
--this action only happens if jukebox is powered, later create action so this only works when the jukebox has power AND is toggled off
--rename soundend to soundstart and use it to play the click noise on the player
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Low")

--    if isPlayingJukeSong then
 --       getSoundManager():StopSound(isPlayingJukeSong);
--		isPlayingJukeSong = nil;
--	end

	self.sound = self.character:getEmitter():playSound(self.soundFile)
	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 5)

end

function LSDFConnect:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function LSDFConnect:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end

	local x, y
	if self.mainDF then
		x, y = tonumber(self.mainDF:getX()), tonumber(self.mainDF:getY())
	else
		x, y = tonumber(self.DiscoBall:getX()), tonumber(self.DiscoBall:getY())
		self.DiscoBall:getModData().IsMainDF = true
	end
	self.DiscoBall:getModData().Connected = {x, y}
	sendClientCommand("LS", "ModifyObjData", {{self.DiscoBall:getX(),self.DiscoBall:getY(),self.DiscoBall:getZ(),self.DiscoBall:getSprite():getName()}, false, self.DiscoBall:getModData()})

	ISBaseTimedAction.perform(self);

end

function LSDFConnect:complete()
	return true
end

function LSDFConnect:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 120
end

function LSDFConnect:new(character, DiscoBall, mainDF)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.DiscoBall = DiscoBall
	o.soundFile = "GeneratorConnect"
	o.mainDF = mainDF
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = false;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.deltaTabulated = 0
	return o;
end
