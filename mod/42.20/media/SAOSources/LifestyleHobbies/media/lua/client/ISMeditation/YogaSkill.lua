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

-- DEPRECATED

--[[
local function getYogaVariable(playerData, arg)
	if not playerData then return false; end
	playerData.LSYoga = playerData.LSYoga or {}
	playerData.LSYoga[arg] = playerData.LSYoga[arg] or 0
	return playerData.LSYoga[arg]
end

local function getYogaLevelTable()
	return {
		{lvl=36000,trait=true,duration=260,effect=3.5},
		{lvl=36000,trait=false,duration=180,effect=3},
		{lvl=26000,trait=true,duration=180,effect=3.2},
		{lvl=26000,trait=false,duration=120,effect=2.8},
		{lvl=18000,trait=true,duration=120,effect=3},
		{lvl=18000,trait=false,duration=90,effect=2.4},
		{lvl=12000,trait=true,duration=90,effect=2.6},
		{lvl=12000,trait=false,duration=60,effect=2},
		{lvl=8000,trait=true,duration=60,effect=2.2},
		{lvl=8000,trait=false,duration=30,effect=1.8},
		{lvl=5000,trait=true,duration=40,effect=2},
		{lvl=5000,trait=false,duration=20,effect=1.6},
		{lvl=3000,trait=true,duration=28,effect=1.8},
		{lvl=3000,trait=false,duration=14,effect=1.4},
		{lvl=1500,trait=true,duration=20,effect=1.2},
		{lvl=1500,trait=false,duration=10,effect=1},
		{lvl=750,trait=true,duration=20,effect=1},
		{lvl=750,trait=false,duration=10,effect=0.8},		
		{lvl=200,trait=true,duration=20,effect=0.8},
		{lvl=200,trait=false,duration=10,effect=0.5},		
		{lvl=0,trait=true,duration=20,effect=0.5},
		{lvl=0,trait=false,duration=10,effect=0.1},		
	}
end

local function getStiffnessBPNames()
	return {'LowerLeg_L','UpperLeg_L','LowerLeg_R','UpperLeg_R','Torso_Lower'}
end

local function doStiffnessReduction(bodyParts, reduction)
	local yogaBP = getStiffnessBPNames()
	if (not yogaBP) or (not bodyParts) then return false; end
	for partName, bodyPartType in pairs(bodyParts) do
		local cS, yS = bodyDamage:getBodyPart(bodyPartType):getStiffness(), yogaBP[partName]
		if yS and (cS > 0) then
			local fS = cs-reduction
			if fs < 0 then fs = 0; end
			bodyDamage:getBodyPart(bodyPartType):setStiffness(fs)
		end
	end
end

local function getYogaLevelVariables(thisPlayer, durationMultiplier, effectMultiplier)
	local Duration, YogaStrengthFactor, hasTrait, level = 5, 1, false, getYogaVariable(thisPlayer:getModData(), 'XP')
	if not getYogaVariable then return false, false; end
	if thisPlayer:hasTrait(CharacterTrait.DISCIPLINED) then hasTrait = true; end
	for k, v in ipairs(getYogaLevelTable()) do
		if v.lvl and (level >= v.lvl) and (v.trait == hasTrait) then
			Duration = v.duration*durationMultiplier
			YogaStrengthFactor = v.effect*effectMultiplier
			break
		end
	end
	return Duration, YogaStrengthFactor
end

local function getYogaSandboxOptions(thisPlayer)
	local durationOption, effectOption, DurationMultiplier, EffectMultiplier = SandboxVars.Yoga.Duration or 2, SandboxVars.Yoga.Multiplier or 2, 1, 1
	if durationOption then
		if durationOption == 1 then DurationMultiplier = 0.5; elseif durationOption == 3 then DurationMultiplier = 2; end
	end
	if effectOption then
		if effectOption == 1 then EffectMultiplier = 0.5; elseif effectOption == 3 then EffectMultiplier = 2; end
	end
	return DurationMultiplier, EffectMultiplier
end

local function getNewYogaState(value)
	if (not value) or (value == 0) then return 0; end
	local newValue = value-0.2
	newValue = tonumber(string.format("%.1f", newValue))
	if newValue < 0.2 then return 0; end
	return newValue
end

local function doYogaDuration(thisPlayer, duration)
	local minutes = getYogaVariable(thisPlayer:getModData(), 'Minutes')
	if not minutes then return; end
	if minutes <= 0 then
		thisPlayer:getModData().LSMoodles["YogaState"].Value = getNewYogaState(thisPlayer:getModData().LSMoodles["YogaState"].Value)
		if thisPlayer:getModData().LSMoodles["YogaState"].Value < 0.2 then
			thisPlayer:getModData().LSMoodles["YogaState"].Value = 0
			thisPlayer:getModData().LSYoga['Minutes'] = 0
		else
			thisPlayer:getModData().LSYoga['Minutes'] = duration
		end
		thisPlayer:getModData().LSYoga['Last'] = thisPlayer:getModData().LSMoodles["YogaState"].Value
	elseif (minutes > 0) then
		thisPlayer:getModData().LSYoga['Minutes'] = minutes-1
		if (thisPlayer:getModData().LSMoodles["YogaState"].Value <= 0) and thisPlayer:getModData().LSYoga['Last'] then
			thisPlayer:getModData().LSMoodles["YogaState"].Value = thisPlayer:getModData().LSYoga['Last']
		end
	end
	if thisPlayer:getModData().LSYoga['Minutes'] < 0 then thisPlayer:getModData().LSYoga['Minutes'] = 0; end
end

function AdjustYogaStuff(thisPlayer)
	--SANDBOX
	local DurationMultiplier, EffectMultiplier = getYogaSandboxOptions(thisPlayer)
	--LEVEL VARIABLES
	local duration, effect = getYogaLevelVariables(thisPlayer, DurationMultiplier, EffectMultiplier)
	--EFFECTS
	doStiffnessReduction(thisPlayer:getBodyDamage():getBodyParts(), effect)
	--DURATION
	doYogaDuration(thisPlayer, duration)
end
]]--