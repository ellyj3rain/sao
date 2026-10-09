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

LSWaitForInteraction = ISBaseTimedAction:derive("LSWaitForInteraction")

function LSWaitForInteraction:waitToStart()

	return false
end

function LSWaitForInteraction:isValid()
	return true
end

function LSWaitForInteraction:update()

	self.character:nullifyAiming()
	if self.character:getModData().LSInteractionState == "none" then
		--print("TA-LSWaitForInteraction force stop")
		self:forceStop()
	elseif self.character:getModData().LSInteractionState == "doAction" then
		--print("TA-LSWaitForInteraction force complete")
		self:forceComplete()
	elseif (self.character:pressedMovement(true)) and (isKeyDown(Keyboard.KEY_LSHIFT)) then
		--print("TA-LSWaitForInteraction force stop")
		self:forceStop()
	end

end

function LSWaitForInteraction:start()

	self.character:getModData().LSInteractionState = "waiting"

	self:setOverrideHandModels(nil, nil)

	self.character:setBlockMovement(true)
	
	-- we get the moddata and voice tracks

	local PlayerVoiceTracks = require("MPSocial/Vox/BaseInteractions")
	local AvailablePlayerVoiceTracks = {}
	
	-- we loop the voice tracks and select the ones that we want, making sure to only select the ones that match the player voice
	for k,v in pairs(PlayerVoiceTracks) do
		if v.Voice == self.character:getModData().PlayerVoice and
		v.Type == "Hey" then--MAKE SURE TO CHANGE THIS LINE
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

	self:setActionAnim("Bob_Waving")
	
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

function LSWaitForInteraction:stop()

	self.character:setBlockMovement(false)

	if self.character:getModData().LSInteractionState == "waiting" then
		--print("TA-LSWaitForInteraction stopped while waiting, sending StopOrStartInteraction command with sourceStoppedWaiting")
		sendClientCommand(self.character, "LS", "StopOrStartInteraction", {self.otherPlayer:getOnlineID(), "sourceStoppedWaiting"})
	end

	self.character:getModData().LSInteractionState = "none"

	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

    ISBaseTimedAction.stop(self);
end

function LSWaitForInteraction:perform()

	if self.character:getModData().LSInteractionState == "waiting" then
		--print("TA-LSWaitForInteraction waited too much")
		self.character:getModData().LSInteractionState = "none"
		self.character:setBlockMovement(false)
	elseif self.character:getModData().LSInteractionState == "doAction" then
		--print("TA-LSWaitForInteraction interaction about to start")
		StartInteractionSource(self.character, self.otherPlayer, self.interaction, self.args)
	end

	ISBaseTimedAction.perform(self);
end

function LSWaitForInteraction:complete()

	return true
end

function LSWaitForInteraction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 600
end

function LSWaitForInteraction:new(character, otherPlayer, interaction, args)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
	o.otherPlayer = otherPlayer
	o.interaction = interaction
	o.args = args
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	return o;
end

return LSWaitForInteraction