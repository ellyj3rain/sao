
require "TimedActions/ISBaseTimedAction"

JukeboxPlay = ISBaseTimedAction:derive("JukeboxPlay");

--local isPlayingJukeSong = nil;

function JukeboxPlay:isValid()
	return true;
end

function JukeboxPlay:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.Jukebox);
	return self.character:shouldBeTurning();
end

function JukeboxPlay:update()


end

function JukeboxPlay:start()
--this action only happens if jukebox is powered, later create action so this only actions when the jukebox has power AND is toggled on
--rename soundend to soundstart and use it to play the click noise on the player
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")

	self.Jukebox:getModData().isJukePlaying = ("IsNotPlaying")

--    if isPlayingJukeSong then
--        getSoundManager():StopSound(isPlayingJukeSong);
--		isPlayingJukeSong = nil;
--	end

	self.sound = self.character:getEmitter():playSound(self.soundFile)
	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 5)
	local x = self.Jukebox:getX()
	local y = self.Jukebox:getY()
	local z = self.Jukebox:getZ()
	if isClient() then
	sendClientCommand("LS", "StopJukeSong", {x, y, z})
	else
	OnJukeSongStop(x, y, z)
	end

end

function JukeboxPlay:stop()
		--ISBaseTimedAction.stop(self);
    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
    ISBaseTimedAction.stop(self);
		
end

function JukeboxPlay:perform()

    if self.sound then
        self.character:stopOrTriggerSound(self.sound);
    end
	--self.character:getEmitter():playSound("JukeboxAfterTurnOn")

    --if not self.Jukebox:getModData().isJukePlaying then
	--self.Jukebox:getModData().isJukePlaying = ("IsPlaying");
	--else
	--self.Jukebox:getModData().isJukePlaying = ("IsPlaying")
	--end
	--self.Jukebox:getModData().genre = self.soundEnd
	--isPlayingJukeSong = getSoundManager():PlayWorldSound(self.soundEnd, self.Jukebox:getSquare(), 5, 75, 0.7, true);
	--addSound(self.Jukebox, self.Jukebox:getX(), self.Jukebox:getY(), self.Jukebox:getZ(), 30, 10)
	--self.Jukebox:getModData().Length = self.Length
	--self.Jukebox:getModData().Style = self.Style
	--local playercommand = "play"
	--local JukeReusableID = self.Jukebox:getModData().JukeboxID
	local genre = tostring(self.soundEnd)
	local style = tostring(self.Style)
	local length = tonumber(self.Length)
	local x = self.Jukebox:getX()
	local y = self.Jukebox:getY()
	local z = self.Jukebox:getZ()

	--self.Jukebox:transmitModData()
	if isClient() then
		if style == "customPlaylist" then
			local customPlaylist = self.Jukebox:getModData().customPlaylist
			sendClientCommand("LS", "JukeboxStyleChangePlayerPlaylist", {x, y, z, style, length, genre, customPlaylist})
		else
			sendClientCommand("LS", "JukeboxStyleChange", {x, y, z, style, length, genre})
		end
	else
	OnJukeboxStyleChange(x, y, z, style, length, genre)
	end
	--sendClientCommand("LS", "isPlayingJuke", {JukeReusableID, genre, x, y, z, playercommand})

	--local playercommand = "waiting"

	--isJukeSendSong(JukeReusableID, genre, x, y, z, playercommand)

	ISBaseTimedAction.perform(self);
end

function JukeboxPlay:complete()
	--[[
	self.Jukebox:getModData().OnPlay = "playing"
	self.Jukebox:getModData().Style = self.Style
	local playlistData
	if self.Style == "customPlaylist" then playlistData = self.customPlaylist; end
	self.Jukebox:getModData().customPlaylist = playlistData
	self.Jukebox:transmitModData()
	]]--
	return true
end

function JukeboxPlay:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 30
end

function JukeboxPlay:new(character, Jukebox, soundFile, soundEnd, Length, Style, customPlaylist)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.Jukebox = Jukebox
	o.soundFile = soundFile
	o.soundEnd = soundEnd
	o.Length = Length
	o.Style = Style
	o.customPlaylist = customPlaylist
	o.ignoreDynamicTime = true;
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.deltaTabulated = 0
	return o;
end
