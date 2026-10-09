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

ShooOther = ISBaseTimedAction:derive("ShooOther")

function ShooOther:isValid()
	return true
end

function ShooOther:waitToStart()
	self.character:faceLocation(self.tX, self.tY);
	return self.character:shouldBeTurning();
	end

function ShooOther:update()

end

function ShooOther:start()

	self:setOverrideHandModels(nil, nil)

	-- we get the moddata and voice tracks
	local characterData = self.character:getModData()
	local PlayerVoice = characterData.PlayerVoice

	local PlayerVoiceTracks = require("TimedActions/PlayerVoiceTracks")
	local AvailablePlayerVoiceTracks = {}
	
	-- we loop the voice tracks and select the ones that we want, making sure to only select the ones that match the player voice
	for k,v in pairs(PlayerVoiceTracks) do
		if v.Voice == PlayerVoice and
		v.Type == "Shooer" then
			table.insert(AvailablePlayerVoiceTracks, v)
		end
	end

				
	-- then we add a random factor to it
	local randomLine = ZombRand(#AvailablePlayerVoiceTracks) + 1
	local randomTrack = AvailablePlayerVoiceTracks[randomLine]
	local sound = randomTrack.sound
	
	if self.character:getDescriptor():isFemale() then
		
	sound = randomTrack.soundF
		
	end

	self:setActionAnim("Bob_ShooOther")
	
	local isPlaying = self.gameSound
		and self.gameSound ~= 0
		and self.character:getEmitter():isPlaying(self.gameSound)

	if not isPlaying then
		-- Some examples of radius and volume found in PZ code:
		-- Fishing (20,1)
		-- Remove Grass (10,5)
		-- Remove Glass (20,1)
		-- Destroy Stuff (20,10)
		-- Remove Bush (20,10)
		-- Move Sprite (10,5)
		local soundRadius = 8
		local volume = 5
		
		if self.character:isOutside() then
		soundRadius = 12
		volume = 5
		end

		self.gameSound = self.character:getEmitter():playSound(sound);
		
		addSound(self.character,
				 self.character:getX(),
				 self.character:getY(),
				 self.character:getZ(),
				 soundRadius,
				 volume)
		
	end
	
end

function ShooOther:stop()

	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

    ISBaseTimedAction.stop(self);
end

function ShooOther:perform()
	ISBaseTimedAction.perform(self);
end

function ShooOther:complete()

	return true
end

function ShooOther:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 150
end

function ShooOther:new(character, tX, tY)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.tX = tX
	o.tY = tY
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	return o;
end

return ShooOther;
