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

DiscoBallOff = ISBaseTimedAction:derive("DiscoBallOff");

--local isPlayingJukeSong = nil;

function DiscoBallOff:isValid()
	return true;
end

function DiscoBallOff:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.DiscoBall);
	return self.character:shouldBeTurning();
end

function DiscoBallOff:update()


end

function DiscoBallOff:start()
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

function DiscoBallOff:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function DiscoBallOff:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end

	--self.DiscoBall:getModData().OnOff = "off"

	local playerDiscoCommand = "off"
	--local DiscoBallReusableID = self.DiscoBall:getModData().DiscoBallID
	local x = self.DiscoBall:getX()
	local y = self.DiscoBall:getY()
	local z = self.DiscoBall:getZ()
	
	sendClientCommand("LS", "TurnDiscoBallOff", {playerDiscoCommand, x, y, z})
	--sendClientCommand(getPlayer(), "LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})

	--self.DiscoBall:transmitModData()


	--isJukeSendSong(JukeReusableID, genre, x, y, z, playercommand)
	--playerObj = self.character
	--DiscoBallID = (tostring(self.DiscoBall:getX()) .. "," .. tostring(self.DiscoBall:getY()) .. "," .. tostring(self.DiscoBall:getZ()))
	--sendClientCommand(playerObj, "LS", "IsTurningDiscoBallOff", {DiscoBallID})
	--print("tried to send command")

	ISBaseTimedAction.perform(self);

end

function DiscoBallOff:complete()
	return true
end

function DiscoBallOff:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 60
end

function DiscoBallOff:new(character, DiscoBall, soundFile)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.DiscoBall = DiscoBall
	o.soundFile = soundFile
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = false;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.deltaTabulated = 0
	return o;
end
