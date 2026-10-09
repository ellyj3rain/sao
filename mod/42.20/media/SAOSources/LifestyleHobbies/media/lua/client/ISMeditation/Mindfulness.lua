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

LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerMin = LSMoodHandler.PerMin or {}

local function getMeditationLevelTable()
	return {
		{lvl=10,trait="disciplined",duration=260,effect=3.5},
		{lvl=10,trait="none",duration=180,effect=3},
		{lvl=9,trait="disciplined",duration=180,effect=3.2},
		{lvl=9,trait="none",duration=120,effect=2.8},
		{lvl=8,trait="disciplined",duration=120,effect=3},
		{lvl=8,trait="none",duration=90,effect=2.4},
		{lvl=7,trait="disciplined",duration=90,effect=2.6},
		{lvl=7,trait="none",duration=60,effect=2},
		{lvl=6,trait="disciplined",duration=60,effect=2.2},
		{lvl=6,trait="none",duration=30,effect=1.8},
		{lvl=5,trait="disciplined",duration=40,effect=2},
		{lvl=5,trait="none",duration=20,effect=1.6},
		{lvl=4,trait="disciplined",duration=28,effect=1.8},
		{lvl=4,trait="none",duration=14,effect=1.4},
		{lvl=3,trait="disciplined",duration=20,effect=1.2},
		{lvl=3,trait="none",duration=10,effect=1},		
	}
end

local function getMeditationLevelVariables(thisPlayer, MindfulDurationMultiplier, EffectMultiplier)
	local MindfulDuration, MeditationStrengthFactor, hasTrait, level = 5, 1, "none", thisPlayer:getPerkLevel(Perks.Meditation)
	if thisPlayer:hasTrait(CharacterTrait.DISCIPLINED) then hasTrait = "disciplined"; end

	for k, v in ipairs(getMeditationLevelTable()) do
		if v.lvl and (v.lvl == level) and (v.trait == hasTrait) then
			MindfulDuration = v.duration*MindfulDurationMultiplier
			MeditationStrengthFactor = v.effect*EffectMultiplier
			break
		end
	end

	return MindfulDuration, MeditationStrengthFactor
end

local function getMeditationSandboxOptions(thisPlayer)
	local MindfulDurationMultiplier, EffectMultiplier, HealPercentage = 1, 1, 2
	local durationSO = SandboxVars.Meditation.MindfulnessDuration or 2
	if durationSO then
		if durationSO == 1 then
			MindfulDurationMultiplier = 0.5
		elseif durationSO == 3 then
			MindfulDurationMultiplier = 2
		end
	end
	local effectSO = SandboxVars.Meditation.EffectMultiplier or 2
	if effectSO then
		if effectSO == 1 then
			EffectMultiplier = 0.5
		elseif effectSO == 3 then
			EffectMultiplier = 2
		end
	end
	HealPercentage = (SandboxVars.Meditation.HealFactor or 2)
	if (thisPlayer:getPerkLevel(Perks.Meditation) == 10) and thisPlayer:hasTrait(CharacterTrait.DISCIPLINED) then
		HealPercentage = HealPercentage*6
	elseif thisPlayer:getPerkLevel(Perks.Meditation) == 10 then
		HealPercentage = HealPercentage*4
	end
	return MindfulDurationMultiplier, EffectMultiplier, HealPercentage
end

local function doMindfulnessStressPanicReduction(thisPlayer, MeditationStrengthFactor, moodList)
	--STRESS
	moodList["Nicotine_Withdrawal"] = {-0.05*MeditationStrengthFactor, false, false, true}
	moodList["Stress"] = {-0.05*MeditationStrengthFactor, false, false, true}
	--PANIC
	moodList["Panic"] = {-5*MeditationStrengthFactor, false, false, true}
	return moodList
end

local function doMindfulnessPainHungerReduction(thisPlayer, MeditationStrengthFactor, moodList)
	--PAIN
	moodList["Pain"] = {-5*MeditationStrengthFactor, false, false, true}
	--HUNGER
	moodList["Hunger"] = {LSUtil.round(-0.004*MeditationStrengthFactor,4), false, false, true} -- -0.002
	
	return moodList
end

local function doMindfulnessHealing(thisPlayer, HealPercentage)
	LSUtil.addGeneralHealth(thisPlayer, HealPercentage, false)
end

local function getNewMindfulnessState(value)
	if (not value) or (value == 0) then return 0; end
	local newValue = value-0.2
	newValue = tonumber(string.format("%.1f", newValue))
	if newValue < 0.2 then return 0; end
	return newValue
end

local function doMindfulnessDuration(thisPlayer, MindfulDuration)
	if not thisPlayer:hasTimedActions() then thisPlayer:getModData().IsMeditating = false; end
	if not thisPlayer:getModData().MindfulnessMinutes then thisPlayer:getModData().MindfulnessMinutes = MindfulDuration; return; end
	if thisPlayer:getModData().MindfulnessMinutes <= 0 then
		thisPlayer:getModData().LSMoodles["MindfulState"].Value = getNewMindfulnessState(thisPlayer:getModData().LSMoodles["MindfulState"].Value)
		if thisPlayer:getModData().LSMoodles["MindfulState"].Value < 0.2 then
			thisPlayer:getModData().LSMoodles["MindfulState"].Value = 0
			thisPlayer:getModData().MindfulnessMinutes = 0
		else
			thisPlayer:getModData().MindfulnessMinutes = MindfulDuration
		end
		thisPlayer:getModData().MindfulnessLast = thisPlayer:getModData().LSMoodles["MindfulState"].Value
	elseif (thisPlayer:getModData().MindfulnessMinutes > 0) and (thisPlayer:getModData().LSMoodles["MindfulState"].Value <= 0) and thisPlayer:getModData().MindfulnessLast then
		thisPlayer:getModData().LSMoodles["MindfulState"].Value = thisPlayer:getModData().MindfulnessLast
	end
	thisPlayer:getModData().MindfulnessMinutes = thisPlayer:getModData().MindfulnessMinutes-1
	if thisPlayer:getModData().MindfulnessMinutes < 0 then thisPlayer:getModData().MindfulnessMinutes = 0; end
end

function AdjustPlayerMindfulness(thisPlayer)

	if thisPlayer:getPerkLevel(Perks.Meditation) < 3 then thisPlayer:getModData().LSMoodles["MindfulState"].Value = 0; return; end

	--SANDBOX
	local MindfulDurationMultiplier, EffectMultiplier, HealPercentage = getMeditationSandboxOptions(thisPlayer)
	
	--LEVEL VARIABLES
	local MindfulDuration, MeditationStrengthFactor = getMeditationLevelVariables(thisPlayer, MindfulDurationMultiplier, EffectMultiplier)

	--MOOD TABLE
	local moodList = {}

	--STRESSPANIC
	if thisPlayer:getModData().LSMoodles["MindfulState"].Value >= 0.2 then moodList = doMindfulnessStressPanicReduction(thisPlayer, MeditationStrengthFactor, moodList); end

	--PAINHUNGER
	if thisPlayer:getModData().LSMoodles["MindfulState"].Value >= 0.4 then moodList = doMindfulnessPainHungerReduction(thisPlayer, MeditationStrengthFactor, moodList); end

	--HEAL
	if thisPlayer:getModData().LSMoodles["MindfulState"].Value >= 0.6 then doMindfulnessHealing(thisPlayer, HealPercentage); end

	--SET
	for k, v in pairs(moodList) do
		if not v[3] then -- refuses to add from isSet
			if not LSMoodHandler.PerMin[k] then
				LSMoodHandler.PerMin[k] = {v[1], v[2], v[3], v[4]}
			else
				LSMoodHandler.PerMin[k][1] = LSMoodHandler.PerMin[k][1]+v[1]
			end
		end
	end
	--DURATION
	doMindfulnessDuration(thisPlayer, MindfulDuration)

end
