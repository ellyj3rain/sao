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

DiscoBallPlay = ISBaseTimedAction:derive("DiscoBallPlay");

--local isPlayingJukeSong = nil;

function DiscoBallPlay:isValid()
	return true;
end

function DiscoBallPlay:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.DiscoBall);
	return self.character:shouldBeTurning();
end

function DiscoBallPlay:update()


end

function DiscoBallPlay:start()
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

function DiscoBallPlay:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function DiscoBallPlay:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end

	local style = tostring(self.Mode)
	--self.DiscoBall:getModData().Mode = style

	--local playercommand = "start"
	--local DiscoBallReusableID = self.DiscoBall:getModData().DiscoBallID
	
	local x = self.DiscoBall:getX()
	local y = self.DiscoBall:getY()
	local z = self.DiscoBall:getZ()
	
	sendClientCommand("LS", "ChangeDiscoStyle", {style, x, y, z, self.isShuffle})
	--print("before transmit")
	--self.DiscoBall:transmitModData(Mode)

	--playerObj = self.character
	--DiscoBallID = (tostring(self.DiscoBall:getX()) .. "," .. tostring(self.DiscoBall:getY()) .. "," .. tostring(self.DiscoBall:getZ()))
	--sendClientCommand(playerObj, "LS", "IsTurningDiscoBallPlay", {DiscoBallID})
	--print("tried to send command")

	--isJukeSendSong(JukeReusableID, genre, x, y, z, playercommand)

	ISBaseTimedAction.perform(self);

end

function DiscoBallPlay:complete()
	return true
end

function DiscoBallPlay:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 30
end

function DiscoBallPlay:new(character, DiscoBall, soundFile, Mode, Shuffle)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.DiscoBall = DiscoBall
	o.soundFile = soundFile
	o.Mode = Mode
	o.isShuffle = Shuffle
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = false;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.deltaTabulated = 0
	return o;
end
