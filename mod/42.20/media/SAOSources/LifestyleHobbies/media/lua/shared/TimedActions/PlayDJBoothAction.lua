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

LS_DJBooth = LS_DJBooth or {}

require "TimedActions/ISBaseTimedAction"

PlayDJBoothAction = ISBaseTimedAction:derive('PlayDJBoothAction');
local MusicDoTextHelperUnhappyness = 0
local MusicDoTextHelperBoredom = 0

local function adjustStats(character)

	local characterData = character:getModData()
	local PlayerMusicLevel = character:getPerkLevel(Perks.Music)

	local currentStress = LSUtil.getCharacterMood(character, "Stress")
	local currentExhaustion = LSUtil.getCharacterMood(character, "Endurance")
	local currentFatigue = LSUtil.getCharacterMood(character, "Fatigue")

	--SANDBOX
	local StrengthMultiplier = 1
	if SandboxVars.Music.StrengthMultiplier ~= nil then
		if SandboxVars.Music.StrengthMultiplier == 1 then
			StrengthMultiplier = 0.5
		elseif SandboxVars.Music.StrengthMultiplier == 2 then
			StrengthMultiplier = 1
		elseif SandboxVars.Music.StrengthMultiplier == 3 then
			StrengthMultiplier = 2
		elseif SandboxVars.Music.StrengthMultiplier == 4 then
			StrengthMultiplier = 4
		end
	end

	--VARIABLES
	local Audience = 0
	local Trait = 0
	local Level = 0
	local varMult = 1
	local reverseBuffs = 0
	--TRAIT
	if character:hasTrait(CharacterTrait.VIRTUOSO) then
		Trait = 2
	elseif character:hasTrait(CharacterTrait.KEEN_HEARING) then
		Trait = 1
	elseif character:hasTrait(CharacterTrait.HARD_OF_HEARING) then
		if varMult > 0.9 then
		varMult = 0.9
		end
	elseif character:hasTrait(CharacterTrait.TONEDEAF) then
		reverseBuffs = 1
	end
	--LEVEL
	Level = ((tonumber(PlayerMusicLevel))/2)

	--AUDIENCE
	if (characterData.LSMoodles["DJAudience"].Value == 0.6) then
		Audience = 4
	elseif (characterData.LSMoodles["DJAudience"].Value == 0.4) then
		Audience = 3
	elseif (characterData.LSMoodles["DJAudience"].Value == 0.2) then
		Audience = 2
	end

	--STRESS
	if currentStress >= 0.8 then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["PartyGood"].Value == 0.4) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["PartyGood"].Value == 0.2) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["PartyBad"].Value == 0.6) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif characterData.LSMoodles["PartyBad"].Value == 0.4 then
		if varMult > 0.15 then
		varMult = 0.15
		end
	elseif characterData.LSMoodles["PartyBad"].Value == 0.2 then
		if varMult > 0.3 then
		varMult = 0.3
		end
	end

	--EMBARRASSED
	if (characterData.LSMoodles["Embarrassed"].Value == 0.8) then
		if varMult > 0.01 then
		varMult = 0.01
		end
	elseif (characterData.LSMoodles["Embarrassed"].Value == 0.6) then
		if varMult > 0.15 then
		varMult = 0.15
		end
	elseif characterData.LSMoodles["Embarrassed"].Value == 0.4 then
		if varMult > 0.3 then
		varMult = 0.3
		end
	elseif characterData.LSMoodles["Embarrassed"].Value == 0.2 then
		if varMult > 0.5 then
		varMult = 0.5
		end
	end

	--FATIGUE
	if currentFatigue >= 0.8 then
		if varMult > 0.02 then
		varMult = 0.02
		end
	elseif currentFatigue >= 0.7 then
		if varMult > 0.2 then
		varMult = 0.2
		end
	elseif currentFatigue >= 0.5 then
		if varMult > 0.4 then
		varMult = 0.4
		end
	elseif currentFatigue >= 0.4 then
		if varMult > 0.6 then
		varMult = 0.6
		end
	end

	--EXHAUSTION
	if currentExhaustion <= 0.2 then
		if varMult > 0.02 then
		varMult = 0.02
		end
	elseif currentExhaustion <= 0.3 then
		if varMult > 0.2 then
		varMult = 0.2
		end
	elseif currentExhaustion <= 0.4 then
		if varMult > 0.4 then
		varMult = 0.4
		end
	elseif currentExhaustion <= 0.7 then
		if varMult > 0.6 then
		varMult = 0.6
		end
	end

	--RESULT
	local varAdd = Trait + Level + Audience + 1
	local varAddRev = Trait + Level + StrengthMultiplier + 1
	local varResult = varAdd * varMult * StrengthMultiplier
	
	if reverseBuffs == 1 then
		if varAddRev >= 6  then
			varAddRev = 5.9
		end
		varResult = (6 - varAddRev)/varMult
	end
	
	--DEFINES
	local moodList = {}
	--ENDURANCE
	moodList["Endurance"] = {-0.003, false, false, false}
	moodList["Fatigue"] = {0.001, false, false, true}
	--BOREDOM 0 - 100
	local boredomChange = 1 * varResult
	--STRESS 0 - 1
	local stressChange = 0.005 * varResult
	--UNHAPPYNESS 0 - 100
	local unhappynessChange = 0.5 * varResult

	--SET
	if reverseBuffs == 1 then
		varResult = varAdd * varMult * StrengthMultiplier * 0.5-- FOR XP
	else
		boredomChange, stressChange, unhappynessChange = -(boredomChange), -(stressChange), -(unhappynessChange)
	end

	moodList["Boredom"] = {boredomChange, boredomChange >= 5, false, true}
	moodList["Stress"] = {stressChange, stressChange >= 0.05, false, true}
	moodList["Unhappiness"] = {unhappynessChange, unhappynessChange >= 2 or unhappynessChange <= -2, false, true}
	
	LSUtil.changeCharacterMoodGroup(character, moodList)
	
	--XP
	local xpChange = varResult
	if PlayerMusicLevel == 10 then
		xpChange = 0
	end
	--character:getXp():AddXP(Perks.Music, xpChange)
	sendClientCommand(character, "LS", "AddXP", {"Music", xpChange})
	--HALOTEXT
--[[
	if boredomChange >= 10 then
		MusicDoTextHelperBoredom = 3
	elseif boredomChange >= 5 then
		MusicDoTextHelperBoredom = 2
	elseif boredomChange >= 1 then
		MusicDoTextHelperBoredom = 1
	end

	if unhappynessChange >= 5 then
		MusicDoTextHelperUnhappyness = 2
	elseif unhappynessChange >= 1 then
		MusicDoTextHelperUnhappyness = 1
	end
]]--
end

function PlayDJBoothAction:isValid()
   return true;
end


function PlayDJBoothAction:waitToStart()
	self.character:faceThisObject(self.DJBooth);
	return self.character:shouldBeTurning();
end

function PlayDJBoothAction:update()

	local characterData = self.character:getModData()
	local playerlevel = self.character:getPerkLevel(Perks.Music)	

	self.countstart = self.countstart + 1
	self.keyDelayStart = self.keyDelayStart + 1
	
	if isKeyDown(Keyboard.KEY_E) then
		self:forceStop()
	end
	if isKeyDown(Keyboard.KEY_C) then
		self:forceStop()
	end
	if isKeyDown(Keyboard.KEY_A) then
		self:forceStop()
	end
	if isKeyDown(Keyboard.KEY_S) then
		self:forceStop()
	end
	if isKeyDown(Keyboard.KEY_W) then
		self:forceStop()
	end
	if isKeyDown(Keyboard.KEY_D) then
		self:forceStop()
	end
	if self.character:isSneaking() then
		self:forceStop()
	end

	if self.Failstate == false then
			if self.keyPause == false then
				if isKeyDown(Keyboard.KEY_UP) or LS_DJBooth.keyUP then
					self.keyPause = true
					LS_DJBooth.keyUP = false
					if self.gameSound and
						self.gameSound ~= 0 and
						self.character:getEmitter():isPlaying(self.gameSound) then
						self.character:getEmitter():stopSound(self.gameSound);
					end
					if self.mode == "housemix" then
						self.mode = "slow"
						LS_DJBooth.speed = 1
					elseif self.mode == "slow" and playerlevel >= 3 then
						self.mode = "medium"
						LS_DJBooth.speed = 2
					elseif self.mode == "medium" and playerlevel >= 6 then
						self.mode = "fast"
						LS_DJBooth.speed = 3
					end----mode
					getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				elseif isKeyDown(Keyboard.KEY_DOWN) or LS_DJBooth.keyDOWN then
					self.keyPause = true
					LS_DJBooth.keyDOWN = false
					if self.gameSound and
						self.gameSound ~= 0 and
						self.character:getEmitter():isPlaying(self.gameSound) then
						self.character:getEmitter():stopSound(self.gameSound);
					end
					if self.mode == "fast" then
						self.mode = "medium"
						LS_DJBooth.speed = 2
					elseif self.mode == "medium" then
						self.mode = "slow"
						LS_DJBooth.speed = 1
					elseif self.mode == "slow" and self.housemix == 1 then
						self.mode = "housemix"
						LS_DJBooth.speed = 4
					end----mode
					getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				elseif isKeyDown(Keyboard.KEY_RIGHT) or isKeyDown(Keyboard.KEY_LEFT) or LS_DJBooth.keyLEFTRIGHT then
					self.keyPause = true
					LS_DJBooth.keyLEFTRIGHT = false
					if self.gameSound and
						self.gameSound ~= 0 and
						self.character:getEmitter():isPlaying(self.gameSound) then
						self.character:getEmitter():stopSound(self.gameSound);
					getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)	
					end
				end----keyDown
				else
				LS_DJBooth.keyUP = false
				LS_DJBooth.keyDOWN = false
				LS_DJBooth.keyLEFTRIGHT = false
			end----KeyPause
	end---CHANGE MODE OR SONG
	

	
	-- panic check
	if not self.character:hasTrait(CharacterTrait.DESENSITIZED) then
		if self.character:hasTrait(CharacterTrait.BRAVE) or self.character:hasTrait(CharacterTrait.DISCIPLINED) then
			if self.character:getMoodles():getMoodleLevel(MoodleType.PANIC) > 3 then
				self:forceStop()
			end
		elseif self.character:getMoodles():getMoodleLevel(MoodleType.PANIC) > 2 then
				self:forceStop()
		end
	end

	local isPlaying = self.gameSound
		and self.gameSound ~= 0
		and self.character:getEmitter():isPlaying(self.gameSound)
		-- update at every 0.05 delta milestone

	if self.countstart >= self.countend then
	self.countstart = 0
	
	if self.Failstate == true then
	
	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end
			
	end
	
	if not isPlaying or self.Failstate then
		--print("TRYING NEW DJ SONG")
		-- Some examples of radius and volume found in PZ code:
		-- Fishing (20,1)
		-- Remove Grass (10,5)
		-- Remove Glass (20,1)
		-- Destroy Stuff (20,10)
		-- Remove Bush (20,10)
		-- Move Sprite (10,5)
		local soundRadius = 30
		local volume = 5
		
		if self.character:isOutside() then
		soundRadius = 75
		volume = 10
		end

		
		
			if self.Failstate == true then
			LS_DJBooth.keyPress(41)
			getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				local soundrandomiser = ZombRand(1, 100)
	
				if soundrandomiser >= 67 then
					self.audio = "dj_booth_fail1"
				elseif soundrandomiser >=33 then
					self.audio = "dj_booth_fail2"
				else
					self.audio = "dj_booth_fail3"
				end
				self.AnimToplay = "Bob_PlayDJFail1"
				self:setActionAnim(self.AnimToplay)
				
				if characterData.LSMoodles["Embarrassed"].Value ~= nil then
					characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.25
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 75, 75)
				end
			
			elseif self.djboothloop == true then
				if self.keyPause == false then
				getSoundManager():PlayWorldSound("dj_booth_stations_switch", self.character:getSquare(), 1, 5, 1, false)
				end
				if self.mode == "slow" then
				
				local randomSlowNumber = ZombRand(#self.AvailableSlowTracks) + 1
				local randomSlowTrack = self.AvailableSlowTracks[randomSlowNumber]
	
				self.audio = tostring(randomSlowTrack.sound)
				
				elseif self.mode == "medium" then
				
				local randomMediumNumber = ZombRand(#self.AvailableMediumTracks) + 1
				local randomMediumTrack = self.AvailableMediumTracks[randomMediumNumber]
	
				self.audio = tostring(randomMediumTrack.sound)
				
				elseif self.mode == "fast" then
				
				local randomFastNumber = ZombRand(#self.AvailableFastTracks) + 1
				local randomFastTrack = self.AvailableFastTracks[randomFastNumber]
	
				self.audio = tostring(randomFastTrack.sound)
				--print("song chosen is" .. tostring(randomFastTrack.sound))
				
				elseif self.mode == "housemix" then
				
				local randomHouseMixNumber = ZombRand(#self.AvailableHouseMixTracks) + 1
				local randomHouseMixTrack = self.AvailableHouseMixTracks[randomHouseMixNumber]
	
				self.audio = tostring(randomHouseMixTrack.sound)
				--print("song chosen is" .. tostring(randomHouseMixTrack.sound))
				
				
				end
			else
			
			self.audio = self.soundFile
			
			end

		self.gameSound = self.character:getEmitter():playSound(self.audio);
		
		addSound(self.character,
				 self.character:getX(),
				 self.character:getY(),
				 self.character:getZ(),
				 soundRadius,
				 volume)
		
		
	self.djboothloop = true
	end
	
	
	if self.Failstate == false then
	if playerlevel <= 5 then

	-- stressCheck
	local randomchance = ZombRand(1, 200)
	if not self.character:hasTrait(CharacterTrait.DISCIPLINED) then
		local stressLevel = LSUtil.getCharacterMood(self.character, "Stress")
		if self.character:hasTrait(CharacterTrait.DEXTROUS) then
			if stressLevel > 0.8 then
					randomchance = ZombRand(22, 200)
			elseif stressLevel > 0.5 then
					randomchance = ZombRand(14, 200)
			elseif stressLevel > 0.2 then
					randomchance = ZombRand(6, 200)
			else
					randomchance = ZombRand(1, 200)
			end
		elseif self.character:hasTrait(CharacterTrait.CLUMSY) then
				if stressLevel > 0.8 then
				randomchance = ZombRand(48, 200)
				elseif stressLevel > 0.5 then
					randomchance = ZombRand(36, 200)
				elseif stressLevel > 0.2 then
					randomchance = ZombRand(24, 200)
				else
					randomchance = ZombRand(16, 100)
				end
		elseif stressLevel > 0.8 then
				randomchance = ZombRand(31, 200)
		elseif stressLevel > 0.5 then
				randomchance = ZombRand(21, 200)
		elseif stressLevel > 0.2 then
				randomchance = ZombRand(11, 200)
		else
				randomchance = ZombRand(1, 200)
		end
	elseif self.character:hasTrait(CharacterTrait.CLUMSY) then
	randomchance = ZombRand(16, 200)
	else
	randomchance = ZombRand(1, 200)
	end
		
			if randomchance >= 198 then
			self.Failstate = true
			end
	
	end
	
	end
	
	end

	self.actionCount = self.actionCount + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	if self.actionCount > self.actionTotal then
		self.actionCount = 0
		adjustStats(self.character)
		
		local soundRadius = 20
		local volume = 5
		
		if self.character:isOutside() then
		soundRadius = 60
		volume = 10
		end

		-- update for zombies as the character moves

		addSound(self.character,
				 self.character:getX(),
				 self.character:getY(),
				 self.character:getZ(),
				 soundRadius,
				 volume)
	
		local HappyOrBored = ZombRand(2)+1
		if self.Failstate == false and self.character:hasTrait(CharacterTrait.TONEDEAF) then
			if HappyOrBored == 1 then 
				if MusicDoTextHelperUnhappyness == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), false, 255, 75, 75)
				elseif MusicDoTextHelperUnhappyness == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), false, 255, 120, 120)
				end
			elseif HappyOrBored == 2 then
				if MusicDoTextHelperBoredom == 3 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 30, 30)
				elseif MusicDoTextHelperBoredom == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 75, 75)
				elseif MusicDoTextHelperBoredom == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), true, 255, 120, 120)
				end
			end
			MusicDoTextHelperUnhappyness = 0
			MusicDoTextHelperBoredom = 0
		elseif self.Failstate == false then
			if HappyOrBored == 1 then 
				if MusicDoTextHelperUnhappyness == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 70, 255, 50)
				elseif MusicDoTextHelperUnhappyness == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 170, 255, 150)
				end
			elseif HappyOrBored == 2 then
				if MusicDoTextHelperBoredom == 3 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 70, 255, 50)
				elseif MusicDoTextHelperBoredom == 2 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 170, 255, 150)
				elseif MusicDoTextHelperBoredom == 1 then
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 200, 255, 200)
				end
			end
			MusicDoTextHelperUnhappyness = 0
			MusicDoTextHelperBoredom = 0
		end
	
	--self:resetJobDelta()
	end

	if self.keyDelayStart >= self.keyDelayEnd then
	self.keyDelayStart = 0
	self.keyPause = false
	end

	if not LS_DJBooth.failstate and self.AnimToplay ~= "Bob_PlayDJFail1" then--change animations while not in a fail state
		self.AnimDelayStart = self.AnimDelayStart + 1
	
		if self.AnimDelayStart >= self.AnimDelayEnd then
			self.AnimDelayStart = 0
			
			self.idxDJAnim = ZombRand(#self.DJAnim) + 1
			self.AnimToplay = self.DJAnim[self.idxDJAnim]
			if self.pastAnim ~= 0 and self.pastAnim == self.AnimToplay then--not repeat animations in sequence
			local variation = ZombRand(2) + 1--will pick a number between 0 and (target number - 1)
				if self.idxDJAnim == 3 then--last anim
					self.AnimToplay = self.DJAnim[self.idxDJAnim - variation]
				elseif self.idxDJAnim == 1 then--first anim
					self.AnimToplay = self.DJAnim[self.idxDJAnim + variation]
				else
					if variation == 1 then
						self.AnimToplay = self.DJAnim[self.idxDJAnim - 1]
					elseif variation == 2 then
						self.AnimToplay = self.DJAnim[self.idxDJAnim + 1]
					end
				end
			end
			self:setActionAnim(self.AnimToplay)
			self.pastAnim = self.AnimToplay
	
		end
	end

	if (self.audio == "dj_booth_fail1") or (self.audio == "dj_booth_fail2") or (self.audio == "dj_booth_fail3") then
		self.Failstate = false
		self.keyPause = true
		LS_DJBooth.failstate = true
		self.AnimDelayStart = 0
	else
		if self.AnimToplay == "Bob_PlayDJFail1" then
			self.AnimToplay = "Bob_PlayDJDefault"
			self:setActionAnim(self.AnimToplay)
		end
		LS_DJBooth.failstate = false
		if characterData.LSMoodles["Embarrassed"].Value ~= nil and characterData.LSMoodles["Embarrassed"].Value >= 0.6 then
			self:forceStop()
		end
	end
end

function PlayDJBoothAction:start()
	
	--local properties = self.DJBooth:getSprite():getProperties()
	--local facing = nil
	--if properties:has("Facing") then
	--	facing = properties:get("Facing")
	--end
	--if facing == "W" then
	--	self.DJAnim = {"Bob_PlayDJScratchCDFlipped","Bob_PlayDJMixFlipped","Bob_PlayDJVibeFlipped"};
	--	self.AnimToplay = "Bob_PlayDJDefaultFlipped"
	--end
	
	--self.character:setLy(self.character:getY())
	--self.character:setLx(self.character:getX())
	self.character:setY(self.character:getY())
	self.character:setX(self.character:getX())

	getSoundManager():setMusicVolume(0)
	
	self.character:getEmitter():playSound("dj_booth_turnon")
	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 5)

	self:setActionAnim(self.AnimToplay)

	--self.character:SetVariable("LootPosition", "Mid")

	self:setOverrideHandModels(nil, nil)
	local PlayDJBoothTracks = require("TimedActions/PlayDJBoothTracks")
				for k,v in pairs(PlayDJBoothTracks) do
					if v.mode == "slow" then
						table.insert(self.AvailableSlowTracks, v)
					elseif v.mode == "medium" then
						table.insert(self.AvailableMediumTracks, v)
					elseif v.mode == "fast" then
						table.insert(self.AvailableFastTracks, v)
					elseif v.mode == "housemix" then
						table.insert(self.AvailableHouseMixTracks, v)
					end
				end
	
	if #self.AvailableHouseMixTracks > 0 then
		self.housemix = 1
	end
	
	local characterData = self.character:getModData()

	if characterData.PlayingInstrument ~= nil
	then
	characterData.PlayingInstrument = true
	else
	characterData.PlayingInstrument = true
	end

	LS_DJBooth.isPlaying = true
	if LS_DJBooth.failstate then LS_DJBooth.failstate = false; end

	if self.mode == "slow" then
		LS_DJBooth.speed = 1
	elseif self.mode == "medium" then
		LS_DJBooth.speed = 2
	elseif self.mode == "fast" then
		LS_DJBooth.speed = 3
	elseif self.mode == "housemix" then
		LS_DJBooth.speed = 4
	end
	
	self.action:setUseProgressBar(false)

    self.DJBoothOverlay = DJSoundboardOverlay:new(self.character, self.DJBooth);
    self.DJBoothOverlay:initialise();
    self.DJBoothOverlay:addToUIManager();

end

function PlayDJBoothAction:stop()

	LS_DJBooth.keyPress(41)
	
	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

	self.Failstate = false
	self.character:getEmitter():playSound("dj_booth_turnoff")
	addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 5)

	local characterData = self.character:getModData()
	characterData.PlayingInstrument = false
	LS_DJBooth.isPlaying = false
	LS_DJBooth.failstate = false
	LS_DJBooth.stop = true
	
	self.DJBoothOverlay:destroy()
	
	getSoundManager():setMusicVolume(self.musicOriginalVolume)
	
	ISBaseTimedAction.stop(self);
end

function PlayDJBoothAction:perform()

	LS_DJBooth.keyPress(41)

	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

	adjustStats(self.character)

	local characterData = self.character:getModData()
	characterData.PlayingInstrument = false
	LS_DJBooth.isPlaying = false
	LS_DJBooth.failstate = false
	LS_DJBooth.stop = true

	self.DJBoothOverlay:destroy()

	getSoundManager():setMusicVolume(self.musicOriginalVolume)

    ISBaseTimedAction.perform(self);
end

function PlayDJBoothAction:complete()

	return true
end

function PlayDJBoothAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function PlayDJBoothAction:new(character, DJBooth, soundFile, mode, length, xp, boredomReduction, stressReduction, actionType, isFail)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.DJBooth = DJBooth;
	o.soundFile = soundFile
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.ignoreDynamicTime = true;
	o.length = length
	o.maxTime = o:getDuration()
	o.gameSound = 0
	o.audio = 0
	o.mode = mode
	o.xp = xp
	o.boredomReduction = boredomReduction
	o.stressReduction = stressReduction
	o.actionType = actionType
	o.isFail = isFail
	o.musicOriginalVolume = tonumber(getSoundManager():getMusicVolume())
	o.pastAnim = 0
	o.AnimToplay = "Bob_PlayDJDefault"
	o.AnimDelayStart = 0
	o.AnimDelayEnd = 1200
	o.DJAnim = {"Bob_PlayDJScratchCD","Bob_PlayDJMix","Bob_PlayDJVibe"};
	o.idxDJAnim = 0
	o.housemix = 0
	o.actionCount = 0
	o.actionTotal = 120--600
	o.Failstate = false
	o.djboothloop = false
	o.AvailableSlowTracks = {}
	o.AvailableMediumTracks = {}
	o.AvailableFastTracks = {}
	o.AvailableHouseMixTracks = {}
	o.countstart = 0
	o.countend = 100
	o.keyPause = true
	o.keyDelayStart = 0
	o.keyDelayEnd = 300
	o.DJBoothOverlay = 0
    return o;
end

return PlayDJBoothAction;