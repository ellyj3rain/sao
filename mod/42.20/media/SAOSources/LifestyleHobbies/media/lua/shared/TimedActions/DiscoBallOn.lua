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

DiscoBallOn = ISBaseTimedAction:derive("DiscoBallOn");

--local isPlayingJukeSong = nil;

function DiscoBallOn:isValid()
	return true;
end

function DiscoBallOn:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.DiscoBall);
	return self.character:shouldBeTurning();
end

function DiscoBallOn:update()


end

function DiscoBallOn:start()
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

function DiscoBallOn:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function DiscoBallOn:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end

	self.DiscoBall:getModData().OnOff = "on"
	self.DiscoBall:getModData().Shuffle = true
	self.DiscoBall:getModData().Mode = "shuffle"
	--local playercommand = "start"
	--local DiscoBallReusableID = self.DiscoBall:getModData().DiscoBallID
	local x = self.DiscoBall:getX()
	local y = self.DiscoBall:getY()
	local z = self.DiscoBall:getZ()
	
	--sendClientCommand(getPlayer(), "LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})
	--print("before transmit")
	sendClientCommand("LS", "ModifyObjData", {{x, y, z, self.DiscoBall:getSprite():getName()}, false, self.DiscoBall:getModData()})
	--self.DiscoBall:transmitModData()

	--playerObj = self.character
	--DiscoBallID = (tostring(self.DiscoBall:getX()) .. "," .. tostring(self.DiscoBall:getY()) .. "," .. tostring(self.DiscoBall:getZ()))
	--sendClientCommand(playerObj, "LS", "IsTurningDiscoBallOn", {DiscoBallID})
	--print("tried to send command")

	--isJukeSendSong(JukeReusableID, genre, x, y, z, playercommand)

	ISBaseTimedAction.perform(self);

end

function DiscoBallOn:complete()
	return true
end

function DiscoBallOn:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 60
end

function DiscoBallOn:new(character, DiscoBall, soundFile)
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
