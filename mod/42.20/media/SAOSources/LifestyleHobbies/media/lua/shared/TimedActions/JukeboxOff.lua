
require "TimedActions/ISBaseTimedAction"

JukeboxOff = ISBaseTimedAction:derive("JukeboxOff");

--local isPlayingJukeSong = nil;

function JukeboxOff:isValid()
	return true;
end

function JukeboxOff:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.Jukebox);
	return self.character:shouldBeTurning();
end

function JukeboxOff:update()


end

function JukeboxOff:start()
--this action only happens if jukebox is powered, later create action so this only works when the jukebox has power AND is toggled off
--rename soundend to soundstart and use it to play the click noise on the player
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")

--    if isPlayingJukeSong then
 --       getSoundManager():StopSound(isPlayingJukeSong);
--		isPlayingJukeSong = nil;
--	end

	self.sound = self.character:getEmitter():playSound(self.soundFile)
	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 5)

end

function JukeboxOff:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function JukeboxOff:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end

	getSoundManager():PlayWorldSound(self.soundEnd, self.Jukebox:getSquare(), 5, 75, 0.7, true);
	addSound(self.Jukebox, self.Jukebox:getX(), self.Jukebox:getY(), self.Jukebox:getZ(), 30, 10)

	--self.Jukebox:getModData().OnOff = "off"

    --if not self.Jukebox:getModData().isJukePlaying then
	--self.Jukebox:getModData().isJukePlaying = ("IsNotPlaying");
	--else
	--self.Jukebox:getModData().isJukePlaying = ("IsNotPlaying")
	--end

	local playercommand = "stopall"
	local JukeReusableID = self.Jukebox:getModData().JukeboxID
	local genre = self.Jukebox:getModData().genre
	local x = self.Jukebox:getX()
	local y = self.Jukebox:getY()
	local z = self.Jukebox:getZ()
	
	--sendClientCommand(getPlayer(), "LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})

	--self.Jukebox:transmitModData()
	if isClient() then
	sendClientCommand("LS", "TurnJukeboxOff", {x, y, z})
	else
	OnJukeboxTurnOff(x, y, z)
	end
	--isJukeSendSong(JukeReusableID, genre, x, y, z, playercommand)
	--playerObj = self.character
	--JukeboxID = (tostring(self.Jukebox:getX()) .. "," .. tostring(self.Jukebox:getY()) .. "," .. tostring(self.Jukebox:getZ()))
	--sendClientCommand(playerObj, "LS", "IsTurningJukeboxOff", {JukeboxID})
	--print("tried to send command")

	ISBaseTimedAction.perform(self);

end

function JukeboxOff:complete()
	--[[
	self.Jukebox:getModData().OnOff = "off"
	self.Jukebox:getModData().OnPlay = "nothing"
	self.Jukebox:transmitModData()
	]]--
	return true
end

function JukeboxOff:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 30
end

function JukeboxOff:new(character, Jukebox, soundFile, soundEnd)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.Jukebox = Jukebox
	o.soundFile = soundFile
	o.soundEnd = soundEnd
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = false;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.deltaTabulated = 0
	return o;
end
