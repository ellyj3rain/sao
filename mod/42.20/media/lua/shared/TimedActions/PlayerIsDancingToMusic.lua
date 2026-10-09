-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

PlayerIsDancingToMusic = ISBaseTimedAction:derive('PlayerIsDancingToMusic');

local styleList = {
	['disco']=true,
	['rbsoul']=true,
	['pop']=true,
	['metal']=true,
	['salsa']=true,
	['beach']=true,
	['classical']=true,
	['country']=true,
	['holiday']=true,
	['jazz']=true,
	['muzak']=true,
	['rap']=true,
	['reggae']=true,
	['rock']=true,
	['world']=true,
	['electronic']=true
}

local DancingDoTextHelperUnhappyness = 0
local DancingDoTextHelperBoredom = 0

local function adjustStats(character)

	local characterData = character:getModData()
	local PlayerDanceLevel = character:getPerkLevel(Perks.Dancing)

	local currentExhaustion = LSUtil.getCharacterMood(character, "Endurance")

	--SANDBOX
	local StrengthMultiplier = 1
	local sandboxDancingStrengthMultiplier = SandboxVars.Dancing.StrengthMultiplier or 2
	if sandboxDancingStrengthMultiplier ~= nil then
		if sandboxDancingStrengthMultiplier == 1 then
			StrengthMultiplier = 0.5
		elseif sandboxDancingStrengthMultiplier == 2 then
			StrengthMultiplier = 1
		elseif sandboxDancingStrengthMultiplier == 3 then
			StrengthMultiplier = 2
		elseif sandboxDancingStrengthMultiplier == 4 then
			StrengthMultiplier = 4
		end
	end

	--VARIABLES
	local Party = 0
	local Trait = 0
	local Level = 0
	local varMult = 1
	--TRAIT
	if character:hasTrait(CharacterTrait.PARTYANIMAL) then
		Trait = 2
	end
	--LEVEL
	Level = ((tonumber(PlayerDanceLevel))/4)

	--PARTY
	if (characterData.LSMoodles["PartyGood"].Value == 0.6) then
		Party = 4
	elseif (characterData.LSMoodles["PartyGood"].Value == 0.4) then
		Party = 3
	elseif (characterData.LSMoodles["PartyGood"].Value == 0.2) then
		Party = 2
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

	--EXHAUSTION
	if currentExhaustion < 0.2 then
		if varMult > 0.02 then
		varMult = 0.02
		end
	elseif currentExhaustion < 0.3 then
		if varMult > 0.2 then
		varMult = 0.2
		end
	elseif currentExhaustion < 0.4 then
		if varMult > 0.4 then
		varMult = 0.4
		end
	elseif currentExhaustion < 0.7 then
		if varMult > 0.6 then
		varMult = 0.6
		end
	end

	--RESULT
	local varAdd = Party + Trait + Level + 1
	local varResult = varAdd * varMult * StrengthMultiplier
	
	--DEFINES
	local moodList = {}
	--ENDURANCE
	moodList["Endurance"] = {-0.015, false, false, false}
	moodList["Fatigue"] = {0.001, false, false, true}

	--BOREDOM 0 - 100
	local boredomChange = 1 * varResult
	--STRESS 0 - 1
	local stressChange = 0.003 * varResult
	--UNHAPPYNESS 0 - 100
	local unhappynessChange = 0.4 * varResult

	moodList["Boredom"] = {-boredomChange, false, false, true}
	moodList["Stress"] = {-stressChange, false, false, true}
	moodList["Unhappiness"] = {-unhappynessChange, unhappynessChange >= 5, false, true}
	
	LSUtil.changeCharacterMoodGroup(character, moodList)

	--XP
	local xpChange = 0.4 * varResult
	if PlayerDanceLevel == 10 then
		xpChange = 0
	else
		--character:getXp():AddXP(Perks.Dancing, xpChange)
		sendClientCommand(character, "LS", "AddXP", {"Dancing", xpChange})
	end
	if character:getPerkLevel(Perks.Fitness) == 10 then

	else
		--character:getXp():AddXP(Perks.Fitness, xpChange)
		sendClientCommand(character, "LS", "AddXP", {"Fitness", xpChange})
	end


	--STIFFNESS
	
	if characterData.DidFitnessActivity ~= nil and characterData.FitnessActivityMuscles ~= nil then
		if character:getPerkLevel(Perks.Fitness) <= 8 and PlayerDanceLevel < 10 then
			if characterData.DidFitnessActivity == 0 then
				characterData.DidFitnessActivity = 1
			end
			if characterData.DidFitnessActivity < 12 then
				if PlayerDanceLevel >= 8 then
					characterData.FitnessActivityMuscles = characterData.FitnessActivityMuscles + 0.1
				elseif PlayerDanceLevel >= 6 then
					characterData.FitnessActivityMuscles = characterData.FitnessActivityMuscles + 0.3
				elseif PlayerDanceLevel >= 4 then
					characterData.FitnessActivityMuscles = characterData.FitnessActivityMuscles + 0.5
				elseif PlayerDanceLevel >= 2 then
					characterData.FitnessActivityMuscles = characterData.FitnessActivityMuscles + 1
				else
					characterData.FitnessActivityMuscles = characterData.FitnessActivityMuscles + 1.5
				end
			end
			if characterData.DidFitnessActivity > 13 then
				characterData.DidFitnessActivity = 13
			end
		end
	else
		characterData.FitnessActivityMuscles = 1
		characterData.DidFitnessActivity = 1
	end

	--HALOTEXT
--[[
	if boredomChange >= 10 then
		DancingDoTextHelperBoredom = 3
	elseif boredomChange >= 5 then
		DancingDoTextHelperBoredom = 2
	elseif boredomChange >= 1 then
		DancingDoTextHelperBoredom = 1
	end

	if unhappynessChange >= 5 then
		DancingDoTextHelperUnhappyness = 2
	elseif unhappynessChange >= 1 then
		DancingDoTextHelperUnhappyness = 1
	end
]]--
end

function PlayerIsDancingToMusic:isValid()
   return true;
end


function PlayerIsDancingToMusic:waitToStart()
	return false;
	end

function PlayerIsDancingToMusic:update()

	if self.actionType ~= 0 then
		self.AnimDelayEnd = 40--200
	elseif self.AnimTime ~= 0 then
		self.AnimDelayEnd = self.AnimTime
	--elseif self.AnimToplay == "Bob_DancingMoveAround" or self.AnimToplay == "Bob_DancingClubRotateInPlace" or self.AnimToplay == "Bob_DancingClubSidestep" then
		--self.AnimDelayEnd = 630
	--elseif self.AnimToplay == "Bob_DancingWaveHands" or self.AnimToplay == "Bob_DancingDiscoBeachBasicA" then
		--self.AnimDelayEnd = 900
	else
		self.AnimDelayEnd = 120--600
	end

	local characterData = self.character:getModData()
	--local currentDelta = self:getJobDelta()
	--local deltaIncrease = currentDelta - self.deltaTabulated
	local PlayerDanceLevel = self.character:getPerkLevel(Perks.Dancing)
	local DanceStyleAnim = "default"
	local AnimDelayEndDefinitive = self.AnimDelayEnd
	--local currentBodyTemp = self.character:getBodyDamage():getTemperature()

	self.AnimDelayStart = self.AnimDelayStart + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)

	if self.criticalFailure == 2 then
		AnimDelayEndDefinitive = self.AnimDelayEndFailCrit

	elseif self.criticalFailure == 1 then
		AnimDelayEndDefinitive = self.AnimDelayEndFail
	end

	if self.AnimDelayStart >= 2 and self.criticalFailure == 2 and self.fallSoundScream == 0 then--40
		local newsoundrandomiser = ZombRand(3) + 1
		
		if self.character:getDescriptor():isFemale() then
			if newsoundrandomiser == 1 then
				self.fallSoundScream = "WomanFall01"
			elseif newsoundrandomiser == 2 then
				self.fallSoundScream = "WomanFall02"
			else
				self.fallSoundScream = "WomanFall03"
			end
		else
			if newsoundrandomiser == 1 then
				self.fallSoundScream = "ManFall01"
			elseif newsoundrandomiser == 2 then
				self.fallSoundScream = "ManFall02"
			else
				self.fallSoundScream = "ManFall03"
			end
		end
		
		if self.canTalk then self.character:getEmitter():playSound(self.fallSoundScream); end
		
	elseif self.AnimDelayStart >= 12 and self.criticalFailure == 2 and self.fallSound == 0 then--75
		local newsoundrandomiser = ZombRand(1, 100)
		if newsoundrandomiser >=75 then
			self.fallSound = "Body_Falling4"
		elseif newsoundrandomiser >=50 then
			self.fallSound = "Body_Falling3"
		elseif newsoundrandomiser >=25 then
			self.fallSound = "Body_Falling2"
		else
			self.fallSound = "Body_Falling1"
		end
		self.character:getEmitter():playSound(self.fallSound);
	end

	if characterData.PartnerStopped == true then
	self:forceStop()
	end

	local listening = (characterData.IsListeningToDJ and "electronic") or characterData.IsListeningToMusicStyle
	DanceStyleAnim = (listening and not type(listening) ~= "string" and (styleList[listening] or styleList[string.sub(listening, 2)]) and listening) or "disco"

	if characterData.IsDancingFull == true and
	characterData.IsDancingPartner ~= "none" then

		if DanceStyleAnim == "disco" or DanceStyleAnim == "cdisco" then

			if characterData.IsDancingPartner == "source" then 
			self:setActionAnim("Bob_DancingDiscoSourceDefault")
			else
			self:setActionAnim("Bob_DancingDiscoTargetDefault")
			end
		
		elseif DanceStyleAnim == "metal" then
		
		--keep adding more, randomize with zombrand
		end

		--DanceStyleAnim = DanceAnim

		--self:setActionAnim(DanceAnim)
		
		--its done this way because isdancingpartner must sync between partners so it cant be random, but can change based on proposing player skill using commands when asking and accepting dance

	elseif characterData.IsDancingFull == true and
	self.AnimDelayStart >= AnimDelayEndDefinitive then

		if (not characterData.IsListeningToDJ) and (not characterData.IsListeningToJukebox) and (not characterData.IsListeningToMusicStyle) then
			if self.endAction == 1 then self:forceStop(); else self.endAction = 1; end
		else
			self.endAction = 0
		end


		self.AnimDelayStart = 0
		
		self.variableFactors = 0
		
		local currentStress = LSUtil.getCharacterMood(self.character, "Stress")
		local currentExhaustion = LSUtil.getCharacterMood(self.character, "Endurance")
		local currentFatigue = LSUtil.getCharacterMood(self.character, "Fatigue")
		
		if currentStress > 0.7 then
			self.variableFactors = self.variableFactors + 5
		elseif currentStress > 0.3 then
			self.variableFactors = self.variableFactors + 2
		end
		if currentExhaustion < 0.2 then
			self:forceStop()
		elseif currentExhaustion < 0.3 then
			self.variableFactors = self.variableFactors + 10
		elseif currentExhaustion < 0.4 then
			self.variableFactors = self.variableFactors + 5
		elseif currentExhaustion < 0.7 then
			self.variableFactors = self.variableFactors + 2
		end
		if currentFatigue > 0.7 then
			self.variableFactors = self.variableFactors + 10
		elseif currentFatigue > 0.4 then
			self.variableFactors = self.variableFactors + 5
		end
		
		self.DanceFail = ZombRand(100) + 1 + self.variableFactors
		
		if self.criticalFailure == 2 then
		--	self.criticalFailure = 0
		--	if characterData.LSMoodles["Embarrassed"].Value ~= nil then
		--		characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.25
		--	end
			--self.character:getStats():setStress(currentStress + 0.1);
			HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 75, 75)
			self:forceStop()
		elseif self.criticalFailure == 1 then
			--self.character:getStats():setStress(currentStress + 0.05);
			if characterData.LSMoodles["Embarrassed"].Value ~= nil then
				characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.1
			end
			HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)
			self.criticalFailure = 0
		end
		
		if characterData.LSMoodles["Embarrassed"].Value ~= nil and characterData.LSMoodles["Embarrassed"].Value >= 0.6 then
			self:forceStop()
		end
		
			-- then we add a random factor to it
		local randomLine = ZombRand(#self.AvailablePlayerVoiceTracks) + 1
		local randomTrack = self.AvailablePlayerVoiceTracks[randomLine]
		local voiceSound = randomTrack.happy--you can change this below for different genres as the sound is only played after a genre is known
		local voiceSoundF = randomTrack.happyF
		
		local RandomAnimPicker = ZombRand(30) + PlayerDanceLevel + 1
		local AnimPickerResult = 0
		local AnimPickerLevel = ZombRand(20) + PlayerDanceLevel + 1
		
		if RandomAnimPicker >= 20 and self.biasgenre < (2 + PlayerDanceLevel) then
			self.biasgenre = self.biasgenre + 2
			AnimPickerResult = 1
		else--common option
			self.biasgenre = self.biasgenre - 1
			AnimPickerResult = 2
		end
		if self.biasgenre < 0 then
			self.biasgenre = 0		
		end

		if (AnimPickerLevel >= 15) and (PlayerDanceLevel > 7) and self.biasadvanced < 2 then
			self.biasadvanced = self.biasadvanced + 2
			self.biasintermediate = self.biasintermediate - 1
			if AnimPickerResult == 1 then
				self.pickerAnim = "genreAdvanced"
			else
				self.pickerAnim = self.commonAnimAdvanced
			end
		elseif (AnimPickerLevel >= 9) and (PlayerDanceLevel > 3) and self.biasintermediate < 4 then
			self.biasadvanced = self.biasadvanced - 1
			self.biasintermediate = self.biasintermediate + 2
			if AnimPickerResult == 1 then
				self.pickerAnim = "genreIntermediate"
			else
				self.pickerAnim = self.commonAnimIntermediate
			end
		else
			self.biasadvanced = self.biasadvanced - 1
			self.biasintermediate = self.biasintermediate - 1
			if AnimPickerResult == 1 then
				self.pickerAnim = "genreBasic"
			else
				self.pickerAnim = self.commonAnimBasic
			end
		end
		if self.biasadvanced < 0 then
			self.biasadvanced = 0		
		end
		if self.biasintermediate < 0 then
			self.biasintermediate = 0		
		end
	if self.criticalFailure ~= 2 then
		if ((PlayerDanceLevel < 2) and (self.DanceFail > 90)) or ((PlayerDanceLevel < 4) and (self.DanceFail > 95)) or ((PlayerDanceLevel < 6) and (self.DanceFail > 98)) and self.criticalFailure == 0 then
		
		self.idxFailAnim = ZombRand(#self.FailAnim) + 1
		self.AnimToplay = self.FailAnim[self.idxFailAnim]
		self:setActionAnim(self.AnimToplay)
		
			if self.AnimToplay == "Bob_DancingUnskilledB" then
				self.criticalFailure = 2
			else
				self.criticalFailure = 1
			end
		
		elseif DanceStyleAnim == "disco" or DanceStyleAnim == "cdisco" then
		
			if self.pickerAnim == "genreAdvanced" then
				self.idxAnim = ZombRand(#self.discoAnimAdvanced) + 1
				self.AnimToplay = self.discoAnimAdvanced[self.idxAnim].Anim
				self.AnimTime = self.discoAnimAdvanced[self.idxAnim].Time
			elseif self.pickerAnim == "genreIntermediate" then
				self.idxAnim = ZombRand(#self.discoAnimIntermediate) + 1
				self.AnimToplay = self.discoAnimIntermediate[self.idxAnim].Anim
				self.AnimTime = self.discoAnimIntermediate[self.idxAnim].Time
			elseif self.pickerAnim == "genreBasic" then
				self.idxAnim = ZombRand(#self.discoAnimBasic) + 1
				self.AnimToplay = self.discoAnimBasic[self.idxAnim].Anim
				self.AnimTime = self.discoAnimBasic[self.idxAnim].Time
			else
				self.idxAnim = ZombRand(#self.pickerAnim) + 1
				self.AnimToplay = self.pickerAnim[self.idxAnim].Anim
				self.AnimTime = self.pickerAnim[self.idxAnim].Time
			end
			self:setActionAnim(self.AnimToplay)
		
		elseif DanceStyleAnim == "salsa" or DanceStyleAnim == "csalsa" or DanceStyleAnim == "beach" or DanceStyleAnim == "cbeach" or DanceStyleAnim == "reggae" or DanceStyleAnim == "creggae" or DanceStyleAnim == "rbsoul" or DanceStyleAnim == "crbsoul" then
		
			if self.pickerAnim == "genreAdvanced" then
				self.idxAnim = ZombRand(#self.salsaAnimAdvanced) + 1
				self.AnimToplay = self.salsaAnimAdvanced[self.idxAnim].Anim
				self.AnimTime = self.salsaAnimAdvanced[self.idxAnim].Time
			elseif self.pickerAnim == "genreIntermediate" then
				self.idxAnim = ZombRand(#self.salsaAnimIntermediate) + 1
				self.AnimToplay = self.salsaAnimIntermediate[self.idxAnim].Anim
				self.AnimTime = self.salsaAnimIntermediate[self.idxAnim].Time
			elseif self.pickerAnim == "genreBasic" then
				self.idxAnim = ZombRand(#self.salsaAnimBasic) + 1
				self.AnimToplay = self.salsaAnimBasic[self.idxAnim].Anim
				self.AnimTime = self.salsaAnimBasic[self.idxAnim].Time
			else
				self.idxAnim = ZombRand(#self.pickerAnim) + 1
				self.AnimToplay = self.pickerAnim[self.idxAnim].Anim
				self.AnimTime = self.pickerAnim[self.idxAnim].Time
			end
			self:setActionAnim(self.AnimToplay)
			
		elseif DanceStyleAnim == "rock" or DanceStyleAnim == "metal" or DanceStyleAnim == "electronic" or DanceStyleAnim == "rap" or DanceStyleAnim == "crock" or DanceStyleAnim == "cmetal" or DanceStyleAnim == "celectronic" or DanceStyleAnim == "crap" then
		
			if self.pickerAnim == "genreAdvanced" then
				self.idxAnim = ZombRand(#self.clubAnimAdvanced) + 1
				self.AnimToplay = self.clubAnimAdvanced[self.idxAnim].Anim
				self.AnimTime = self.clubAnimAdvanced[self.idxAnim].Time
			elseif self.pickerAnim == "genreIntermediate" then
				self.idxAnim = ZombRand(#self.clubAnimIntermediate) + 1
				self.AnimToplay = self.clubAnimIntermediate[self.idxAnim].Anim
				self.AnimTime = self.clubAnimIntermediate[self.idxAnim].Time
			elseif self.pickerAnim == "genreBasic" then
				self.idxAnim = ZombRand(#self.clubAnimBasic) + 1
				self.AnimToplay = self.clubAnimBasic[self.idxAnim].Anim
				self.AnimTime = self.clubAnimBasic[self.idxAnim].Time
			else
				self.idxAnim = ZombRand(#self.pickerAnim) + 1
				self.AnimToplay = self.pickerAnim[self.idxAnim].Anim
				self.AnimTime = self.pickerAnim[self.idxAnim].Time
			end
			self:setActionAnim(self.AnimToplay)
		
		elseif DanceStyleAnim == "pop" or DanceStyleAnim == "tm" or DanceStyleAnim == "customPlaylist" or DanceStyleAnim == "holiday" or DanceStyleAnim == "muzak" or DanceStyleAnim == "country" or DanceStyleAnim == "classical" or DanceStyleAnim == "world" or DanceStyleAnim == "jazz" or DanceStyleAnim == "cpop" or DanceStyleAnim == "choliday" or DanceStyleAnim == "cmuzak" or DanceStyleAnim == "ccountry" or DanceStyleAnim == "cclassical" or DanceStyleAnim == "cworld" or DanceStyleAnim == "cjazz" then
		
			if self.pickerAnim == "genreAdvanced" then
				self.idxAnim = ZombRand(#self.commonAnimAdvanced) + 1
				self.AnimToplay = self.commonAnimAdvanced[self.idxAnim].Anim
				self.AnimTime = self.commonAnimAdvanced[self.idxAnim].Time
			elseif self.pickerAnim == "genreIntermediate" then
				self.idxAnim = ZombRand(#self.commonAnimIntermediate) + 1
				self.AnimToplay = self.commonAnimIntermediate[self.idxAnim].Anim
				self.AnimTime = self.commonAnimIntermediate[self.idxAnim].Time
			elseif self.pickerAnim == "genreBasic" then
				self.idxAnim = ZombRand(#self.commonAnimBasic) + 1
				self.AnimToplay = self.commonAnimBasic[self.idxAnim].Anim
				self.AnimTime = self.commonAnimBasic[self.idxAnim].Time
			else
				self.idxAnim = ZombRand(#self.pickerAnim) + 1
				self.AnimToplay = self.pickerAnim[self.idxAnim].Anim
				self.AnimTime = self.pickerAnim[self.idxAnim].Time
			end
			self:setActionAnim(self.AnimToplay)
		end
		
		local dice20 = ZombRand(20) + 1
		if self.criticalFailure == 0 and self.voiceCooldown == 0 and dice20 >= 15 then
			self.voiceCooldown = 1
			if self.character:getDescriptor():isFemale() and self.canTalk then
				self.character:getEmitter():playSound(voiceSoundF);
			elseif self.canTalk then
				self.character:getEmitter():playSound(voiceSound);
			end
		elseif self.criticalFailure == 0 and self.voiceCooldown ~= 0 then
			self.voiceCooldown = 0
		end
		
		if self.criticalFailure == 0 and dice20 >= 10 then
			if DancingDoTextHelperUnhappyness == 2 then
				HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 70, 255, 50)
			elseif DancingDoTextHelperUnhappyness == 1 then
				HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 170, 255, 150)
			end
			DancingDoTextHelperUnhappyness = 0
		elseif self.criticalFailure == 0 and dice20 <= 10 then
			if DancingDoTextHelperBoredom == 3 then
				HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 70, 255, 50)
			elseif DancingDoTextHelperBoredom == 2 then
				HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 170, 255, 150)
			elseif DancingDoTextHelperBoredom == 1 then
				HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Boredom"), false, 200, 255, 200)
			end
			DancingDoTextHelperBoredom = 0
		end
	local sandboxDanceAnim = SandboxVars.Debug.DanceAnim or false
	if sandboxDanceAnim ~= nil then
		if sandboxDanceAnim == true then
			self.character:Say(tostring(self.AnimToplay))
		end
	end
		--self.character:Say(tostring(self.AnimToplay))------------------------------------------DEBUGDANCES
		
		self.actionType = 0
		adjustStats(self.character)
		--self:resetJobDelta()
		--self:setCurrentTime(0)
	end

	end
	--if deltaIncrease > 0.05 then

	--self.deltaTabulated = currentDelta
		
	--self:resetJobDelta()
	--end
	self.character:setMetabolicTarget(Metabolics.Fitness)
end

local function doNote(character, texture)
	local text = " <CENTRE> "..getText("IGUI_T_Dancing_Note")
	local infoText = " <LINE><H1> "..getText("IGUI_T_Dancing_Title").." <LINE> ".."<IMAGECENTRE:media/ui/tutorial/Dancing_01.png> <LINE><LINE><TEXT> "..getText("IGUI_T_Dancing_Body").." <LINE><LINE> "..getText("IGUI_T_Dancing_Body2").." <LINE><LINE> "..getText("IGUI_T_Dancing_Body3").." <LINE><LINE> "..getText("IGUI_T_Dancing_Body4").." <LINE><LINE> "..getText("IGUI_T_Dancing_Body5").." <LINE><LINE> "..getText("IGUI_T_Dancing_Body6")
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, "noteDance", texture, 4, "noteDance", infoText, true}) -- player, mainText, queueType, tex, time, closePerm, infoPanel, noSpam
end

function PlayerIsDancingToMusic:start()
	local characterData = self.character:getModData()
	
    if self.character:getPrimaryHandItem() then
		self.handItemP = self.character:getPrimaryHandItem()
	end
    if self.character:getSecondaryHandItem() and not self.character:isItemInBothHands(self.handItemP) then
		self.handItemS = self.character:getSecondaryHandItem()
	end

	self:setOverrideHandModels(nil, nil)
	
	local PlayerVoice = characterData.PlayerVoice

	local PlayerVoiceTracks = require("TimedActions/PlayerVoiceTracks")
	self.AvailablePlayerVoiceTracks = {}
	
	-- we loop the voice tracks and select the ones that we want, making sure to only select the ones that match the player voice
	for k,v in pairs(PlayerVoiceTracks) do
		if v.Voice == PlayerVoice and
		v.Type == "Dancing" then--MAKE SURE TO CHANGE THIS LINE
			table.insert(self.AvailablePlayerVoiceTracks, v)
		end
	end
	
	local PlayerDanceMoves = require("TimedActions/PlayerDanceMoves")
	self.commonAnimBasic = {}
	self.commonAnimIntermediate = {}
	self.commonAnimAdvanced = {}
	self.discoAnimBasic = {}
	self.discoAnimIntermediate = {}
	self.discoAnimAdvanced = {}
	self.salsaAnimBasic = {}
	self.salsaAnimIntermediate = {}
	self.salsaAnimAdvanced = {}
	self.clubAnimBasic = {}
	self.clubAnimIntermediate = {}
	self.clubAnimAdvanced = {}
	
	-- loop to catch player dance moves
	for k,v in pairs(PlayerDanceMoves) do
		if v.Type == "common" and v.Skill == "basic" then--MAKE SURE TO CHANGE THIS LINE
			table.insert(self.commonAnimBasic, v)
		elseif v.Type == "common" and v.Skill == "intermediate" then
			table.insert(self.commonAnimIntermediate, v)
		elseif v.Type == "common" and v.Skill == "advanced" then
			table.insert(self.commonAnimAdvanced, v)
		end
		if v.Type == "disco" and v.Skill == "basic" then--MAKE SURE TO CHANGE THIS LINE
			table.insert(self.discoAnimBasic, v)
		elseif v.Type == "disco" and v.Skill == "intermediate" then
			table.insert(self.discoAnimIntermediate, v)
		elseif v.Type == "disco" and v.Skill == "advanced" then
			table.insert(self.discoAnimAdvanced, v)
		end
		if v.Type == "salsa" and v.Skill == "basic" then--MAKE SURE TO CHANGE THIS LINE
			table.insert(self.salsaAnimBasic, v)
		elseif v.Type == "salsa" and v.Skill == "intermediate" then
			table.insert(self.salsaAnimIntermediate, v)
		elseif v.Type == "salsa" and v.Skill == "advanced" then
			table.insert(self.salsaAnimAdvanced, v)
		end
		if v.Type == "club" and v.Skill == "basic" then--MAKE SURE TO CHANGE THIS LINE
			table.insert(self.clubAnimBasic, v)
		elseif v.Type == "club" and v.Skill == "intermediate" then
			table.insert(self.clubAnimIntermediate, v)
		elseif v.Type == "club" and v.Skill == "advanced" then
			table.insert(self.clubAnimAdvanced, v)
		end
	end
	
	local actionType = self.actionType
	--print("action " .. actionType)

	self:setActionAnim(actionType)

	self:setOverrideHandModels(nil, nil)

	self.action:setUseProgressBar(false)

	if not characterData.IsListeningToJukebox then
		characterData.IsListeningToJukebox = false
	end
	if not characterData.IsListeningToDJ then
		characterData.IsListeningToDJ = false
	end

	characterData.IsDancingFull = true
	characterData.IsDancingInit = true
	characterData.IsDancingPartner = "none"
	characterData.DancingPartner = "none"
	characterData.PartnerStopped = false
	
	self.criticalFailure = 0

	if self.character:hasTrait(CharacterTrait.DEAF) then self.canTalk = false; end

	doNote(self.character, "recreational_01_1")

end

function PlayerIsDancingToMusic:stop()

	self.AnimDelayStart = 0
	--local currentDelta = self:getJobDelta()
	--local deltaIncrease = currentDelta - self.deltaTabulated

	--self.deltaTabulated = currentDelta

	if self.handItemP ~= 0 and self.character:isItemInBothHands(self.handItemP) then
		self.character:setPrimaryHandItem(self.handItemP)
		self.character:setSecondaryHandItem(self.handItemP)
    elseif self.handItemP ~= 0 then
		self.character:setPrimaryHandItem(self.handItemP)
    elseif self.handItemS ~= 0 then
		self.character:setSecondaryHandItem(self.handItemS)
    end

	local characterData = self.character:getModData()
	
	if self.criticalFailure == 2 then
		HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 75, 75)
		if characterData.LSMoodles["Embarrassed"].Value ~= nil then
			characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.25
		end
		if LSUtil.getCharacterMood(self.character, "Pain") <= 60 then
			LSUtil.changeCharacterMood(self.character, "Pain", 40, true, false, true)
		end
	elseif self.criticalFailure == 1 then
		if characterData.LSMoodles["Embarrassed"].Value ~= nil then
			characterData.LSMoodles["Embarrassed"].Value = characterData.LSMoodles["Embarrassed"].Value + 0.1
		end
		HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)
	end

	if characterData.DancingPartner ~= "none" then
	local DancePartner = characterData.DancingPartner

    for playerIndex = 0, getNumActivePlayers()-1 do
        local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		if (playerObj ~= nil) then
			for x = playerObj:getX()-1,playerObj:getX()+1 do
                for y = playerObj:getY()-1,playerObj:getY()+1 do
                    local square = getCell():getGridSquare(x,y,playerObj:getZ());
                    if square then
                        for i = 0,square:getMovingObjects():size()-1 do
                            local moving = square:getMovingObjects():get(i);
                            if instanceof(moving, "IsoPlayer") then
                                table.insert(playersList, moving);
                            end
                        end
                    end
                end
            end
		end
	
        if #playersList > 0 then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == DancePartner then
					sendClientCommand(playerObj, "LS", "StopDance", {v:getOnlineID()})
					--print("sending command to stop.. " .. tostring(v:getUsername()) .. " from dancing")
				end
			end
        end			
    end
	
	end

	characterData.IsDancingInit = false
	characterData.IsDancingFull = false
	characterData.IsDancingFullPartner = false
	characterData.IsDancingPartner = "none"
	characterData.DancingPartner = "none"
	characterData.PartnerStopped = false
	
	self.criticalFailure = 0

	self.character:setVariable("ExerciseStarted", false);
	self.character:setVariable("ExerciseEnded", true);

	ISBaseTimedAction.stop(self);	
end

function PlayerIsDancingToMusic:perform()

	self.AnimDelayStart = 0
	--local currentDelta = self:getJobDelta()
	--local deltaIncrease = currentDelta - self.deltaTabulated

	--self.deltaTabulated = currentDelta

	if self.handItemP ~= 0 and self.character:isItemInBothHands(self.handItemP) then
		self.character:setPrimaryHandItem(self.handItemP)
		self.character:setSecondaryHandItem(self.handItemP)
    elseif self.handItemP ~= 0 then
		self.character:setPrimaryHandItem(self.handItemP)
    elseif self.handItemS ~= 0 then
		self.character:setSecondaryHandItem(self.handItemS)
    end

	local characterData = self.character:getModData()
	characterData.IsDancingInit = false
	characterData.IsDancingFull = false
	characterData.IsDancingFullPartner = false
	characterData.IsDancingPartner = "none"
	characterData.DancingPartner = "none"
	characterData.PartnerStopped = false

	self.character:setVariable("ExerciseStarted", false);
	self.character:setVariable("ExerciseEnded", true);

    ISBaseTimedAction.perform(self);
end

function PlayerIsDancingToMusic:complete()

	return true
end

function PlayerIsDancingToMusic:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function PlayerIsDancingToMusic:new(character, actionType)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.ignoreDynamicTime = true;
	o.maxTime = o:getDuration()
	o.caloriesModifier = 3
	--o.deltaTabulated = 0
	o.actionType = actionType
	o.criticalFailure = 0
	o.fallSound = 0
	o.variableFactors = 0
	o.DanceFail = 0
	o.AnimToplay = "Loot"
	o.AnimDelayStart = 0
	o.AnimDelayEnd = 120--600
	o.AnimDelayEndFail = 62--310
	o.AnimDelayEndFailCrit = 72--360
	o.idxAnim = 0
	o.pickerAnim = "commonBasic"
	o.biasgenre = 0
	o.biasadvanced = 0
	o.biasintermediate = 0
	o.FailAnim = {"Bob_DancingUnskilledA","Bob_DancingUnskilledB"};
	o.AnimTime = 0
	o.commonAnimBasic = 0
	--o.commonAnimBasic = {"Bob_DancingSillyA","Bob_DancingChicken","Bob_DancingWaveHands","Bob_DancingSideStepLarge","Bob_DancingRotatingA","Bob_DancingHokeyPokey","Bob_DancingMoveAround","Bob_DancingSideStepArmSwing","Bob_DancingFootSwitch","Bob_DancingCookingCauldron","Bob_DancingSideToSide","Bob_DancingFreestyleD","Bob_DancingHandWave","Bob_DancingSidestepSimple","Bob_DancingSidestepLarge2","Bob_DancingFreestyleG","Bob_DancingClubSidestep","Bob_DancingClubFreestyleB","Bob_DancingClubSideStepEnergetic","Bob_DancingClubVibing","Bob_DancingHandsInAir","Bob_DancingRotatingC","Bob_DancingToAndFrom2"};--pop, holiday and muzak don't have a specific genre; classical, jazz and country and world don't have a specific for now
	o.commonAnimIntermediate = 0
	--o.commonAnimIntermediate = {"Bob_DancingSideStep","Bob_DancingUprockA","Bob_DancingGangnam","Bob_DancingHouseB","Bob_DancingHouseC","Bob_DancingMoveAroundAndSpin","Bob_DancingSpinInPlace","Bob_DancingFreestyleA","Bob_DancingFreestyleB","Bob_DancingFreestyleC","Bob_DancingFreestyleE","Bob_DancingWave","Bob_DancingLegTurnUp2","Bob_DancingFreestyleH","Bob_DancingFreestyleI","Bob_DancingRotatingB","Bob_DancingClubMoveAround","Bob_DancingSalsaFreestyleD","Bob_DancingSalsaFreestyleH"};
	o.commonAnimAdvanced = 0
	--o.commonAnimAdvanced = {"Bob_DancingSideStepEnergetic","Bob_DancingAdvancedA","Bob_DancingSpinInPlaceAdvanced","Bob_DancingClubFreestyleA"};
	--o.discoAnimBasic = {"Bob_DancingDiscoDefault","Bob_DancingDiscoDefaultB","Bob_DancingDiscoDefaultC","Bob_DancingDiscoBeachBasicA","Bob_DancingSideToSide","Bob_DancingYMCA","Bob_DancingClubToAndFrom","Bob_DancingHandDown","Bob_DancingKick","Bob_DancingSideStepWave"};--DISCO
	o.discoAnimBasic = 0
	o.discoAnimIntermediate = 0
	o.discoAnimAdvanced = 0
	o.salsaAnimBasic = 0
	o.salsaAnimIntermediate = 0
	o.salsaAnimAdvanced = 0
	o.clubAnimBasic = 0
	o.clubAnimIntermediate = 0
	o.clubAnimAdvanced = 0
	--o.discoAnimIntermediate = {"Bob_DancingDiscoIntermediateA","Bob_DancingDiscoIntermediateB","Bob_DancingRunningMan","Bob_DancingArmSwingUp","Bob_DancingLegSweepLowMany","Bob_DancingTipToeHeadUp","Bob_DancingFreestyleA","Bob_DancingRobotB","Bob_DancingClubWobble","Bob_DancingShake","Bob_DancingFreestyleShake","Bob_DancingDiscoWave2","Bob_DancingHeadShake","Bob_DancingSalsaFreestyleC"};
	--o.discoAnimAdvanced = {"Bob_DancingHouseA","Bob_DancingRobotA","Bob_DancingSlide","Bob_DancingThrillerB","Bob_DancingRobotC","Bob_DancingMoonwalk"};
	--o.salsaAnimBasic = {"Bob_DancingDiscoBeachBasicA","Bob_DancingCanCan","Bob_DancingMacarena","Bob_DancingClubWave","Bob_DancingClubRotateInPlace","Bob_DancingSideStepWave","Bob_DancingRotatingC","Bob_DancingToAndFrom2","Bob_DancingGraciously","Bob_DancingGraciously2","Bob_DancingBooty"};--salsa is also for reggae, beach and rb
	--o.salsaAnimIntermediate = {"Bob_DancingTwerk","Bob_DancingWave","Bob_DancingDiscoWave2","Bob_DancingSalsaFreestyleB","Bob_DancingSalsaFreestyleC","Bob_DancingWaveEnergetic","Bob_DancingClubMoveAround","Bob_DancingSalsaFreestyleD","Bob_DancingSalsaFreestyleE","Bob_DancingSalsaFreestyleH","Bob_DancingSalsaWave","Bob_DancingSalsaWaveMovingAround"};
	--o.salsaAnimAdvanced = {"Bob_DancingBellyDancer","Bob_DancingTwerkSnake","Bob_DancingSalsaFreestyleF","Bob_DancingSalsaFreestyleG","Bob_DancingSalsaWaveFreestyle"};
	--o.clubAnimBasic = {"Bob_DancingArmSwingUp","Bob_DancingMacarena","Bob_DancingMoveAroundAndSpin2","Bob_DancingOrangutan","Bob_DancingYMCA","Bob_DancingFreestyleG","Bob_DancingClubSidestep","Bob_DancingClubWave","Bob_DancingClubToAndFrom","Bob_DancingClubFreestyleB","Bob_DancingClubSideStepEnergetic","Bob_DancingClubRotateInPlace","Bob_DancingHandDown","Bob_DancingClubVibing","Bob_DancingClubMoveAroundAxis"};--rock, metal and hiphop/rap use the same as electronic (for now)
	--o.clubAnimIntermediate = {"Bob_DancingHipHopIntermediateA","Bob_DancingRunningMan","Bob_DancingBreakDanceA","Bob_DancingBreakDanceB","Bob_DancingBreakDanceC","Bob_DancingBreakDanceD","Bob_DancingLegSweepUp","Bob_DancingLegSweepLowMany","Bob_DancingRobotB","Bob_DancingFreestyleF","Bob_DancingFreestyleH","Bob_DancingClubWobble","Bob_DancingShake","Bob_DancingFreestyleShake","Bob_DancingDiscoWave2","Bob_DancingHeadShake","Bob_DancingSalsaFreestyleB"};
	--o.clubAnimAdvanced = {"Bob_DancingHeadspin","Bob_DancingHouseA","Bob_DancingRobotA","Bob_DancingSlide","Bob_DancingThrillerB","Bob_DancingRobotC","Bob_DancingClubFreestyleA"};
	o.AvailablePlayerVoiceTracks = 0
	o.voiceCooldown = 1
	o.fallSoundScream = 0
	o.handItemP = 0
	o.handItemS = 0
	o.canTalk = true
	o.endAction = 0
    return o;
end