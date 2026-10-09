
require "TimedActions/ISBaseTimedAction"

JukeboxOn = ISBaseTimedAction:derive("JukeboxOn");

--local isPlayingJukeSong = nil;

function JukeboxOn:isValid()
	return true;
end

function JukeboxOn:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.Jukebox);
	return self.character:shouldBeTurning();
end

function JukeboxOn:update()


end

function JukeboxOn:start()
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

function JukeboxOn:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function JukeboxOn:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end

	getSoundManager():PlayWorldSound(self.soundEnd, self.Jukebox:getSquare(), 5, 75, 0.7, true);
	addSound(self.Jukebox, self.Jukebox:getX(), self.Jukebox:getY(), self.Jukebox:getZ(), 30, 10)

	self.Jukebox:getModData().OnOff = "on"
	self.Jukebox:getModData().genre = "nothing"
	self.Jukebox:getModData().OnPlay = "nothing"

	local playercommand = "start"
	local JukeReusableID = self.Jukebox:getModData().JukeboxID
	local genre = self.Jukebox:getModData().genre
	local x = self.Jukebox:getX()
	local y = self.Jukebox:getY()
	local z = self.Jukebox:getZ()
	--local playerObj = self.character
	
	--sendClientCommand(playerObj, "LS", "JukeTurnedOn", {genre, x, y, z, JukeReusableID, playercommand})
	--print("before transmit")
	--self.Jukebox:transmitModData()
	
	if isClient() then
	sendClientCommand("LS", "ModifyObjData", {{x, y, z, self.Jukebox:getSprite():getName()}, false, self.Jukebox:getModData()})
	sendClientCommand("LS", "JukeboxStart", {x, y, z})
	else
	OnJukeboxStart(x, y, z)
	end
	--playerObj = self.character
	--JukeboxID = (tostring(self.Jukebox:getX()) .. "," .. tostring(self.Jukebox:getY()) .. "," .. tostring(self.Jukebox:getZ()))
	--sendClientCommand(playerObj, "LS", "IsTurningJukeboxOn", {JukeboxID})
	--print("tried to send command")

	--isJukeSendSong(JukeReusableID, genre, x, y, z, playercommand)

	ISBaseTimedAction.perform(self);

end

function JukeboxOn:complete()
	--[[
	self.Jukebox:getModData().OnOff = "on"
	self.Jukebox:getModData().genre = "nothing"
	self.Jukebox:getModData().OnPlay = "nothing"
	self.Jukebox:transmitModData()
	]]--
	--local playercommand = "start"
	--local JukeReusableID = self.Jukebox:getModData().JukeboxID
	--local genre = self.Jukebox:getModData().genre
	--local x = self.Jukebox:getX()
	--local y = self.Jukebox:getY()
	--local z = self.Jukebox:getZ()
	--self.Jukebox:transmitModData()
	--sendServerCommand("LS", "JukeboxStart", {x, y, z})
	return true
end

function JukeboxOn:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 20
end

function JukeboxOn:new(character, Jukebox, soundFile, soundEnd)
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
