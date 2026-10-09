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

require "LSEffects/LSPerMinute"

LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerMin = LSMoodHandler.PerMin or {}

local function HNdoPlayerDataCheck(thisPlayer, playerData)
	playerData.hygieneNeedLimit = playerData.hygieneNeedLimit or 100
	playerData.lastBrushTeeth = playerData.lastBrushTeeth or 0
	if (playerData.lastBrushTeeth > 0) and (playerData.lastBrushTeeth + 6) <= thisPlayer:getHoursSurvived() then
		playerData.hygieneNeedLimit = playerData.hygieneNeedLimit + 10
		playerData.lastBrushTeeth = 0
	end
	if not playerData.hygieneNeed then playerData.hygieneNeed = 40; end	
	if thisPlayer:isGodMod() then playerData.hygieneNeed = 40; end	
end

local function HNgetBloodDirt(thisPlayer)
	local totalBlood, totalDirt, visual = 0, 0, thisPlayer:getHumanVisual()
	for i = 1, BloodBodyPartType.MAX:index() do
        local part = BloodBodyPartType.FromIndex(i - 1)
        local Blood = visual:getBlood(part)
        local Dirt = visual:getDirt(part)

		if Blood > 0 then
			totalBlood = totalBlood + Blood
		end
		if Dirt > 0 then
			totalDirt = totalDirt + Dirt
		end
    end
	return totalBlood, totalDirt
end

local function HNgetVariables(thisPlayer, playerData, totalBlood, totalDirt)
	local increaseRate, traitMultiplier, traitMultiplierNeg, invertRate = 0.07, 1, 1, false
	if thisPlayer:hasTrait(CharacterTrait.TIDY) then
		increaseRate = 0.05
	elseif thisPlayer:hasTrait(CharacterTrait.SLOPPY) then
		increaseRate = 0.1
		traitMultiplier = 0.5
		traitMultiplierNeg = 0.5
	elseif thisPlayer:hasTrait(CharacterTrait.CLEANFREAK) then
		traitMultiplier = 1.5
		traitMultiplierNeg = 2
	end
	--float goes from 0 to 17 (each body part can add up to 1)
	if totalBlood > 15 then
		increaseRate = increaseRate + 2
	elseif totalBlood > 10 or totalDirt > 15 then
		increaseRate = increaseRate + 0.5
	elseif totalBlood > 5 or totalDirt > 10 then
		increaseRate = increaseRate + 0.07
	elseif totalDirt > 5 then
		increaseRate = increaseRate + 0.03
	elseif (totalDirt < 2) and (totalBlood < 2) and (playerData.hygieneNeed > 50) then--hygiene won't decrease past neutral 50 unless player is visibly dirty and will increase back to 50 if visibly clean
		increaseRate = 0.5
		invertRate = true
	end
	if thisPlayer:isAsleep() then
		increaseRate = increaseRate - 0.04
	end
	if increaseRate < 0.01 then increaseRate = 0.01; end
	if increaseRate > 3 then increaseRate = 3; end
	if playerData.hygieneNeed <= 40 then--we do this so that while clean or better the need will increase slower, also makes passive recovery (visibly clean) slower after the negative moodles
		increaseRate = increaseRate * 0.6
	elseif playerData.hygieneNeed > 80 then--we do this so that each filth stage takes longer to reach the next, also makes passive recovery (visibly clean) faster at the worse negative moodles
		if invertRate then increaseRate = increaseRate * 3; else increaseRate = increaseRate * 0.2; end
	elseif (playerData.hygieneNeed > 60) then
		if invertRate then increaseRate = increaseRate * 2; else increaseRate = increaseRate * 0.4; end
	end
	if (playerData.hygieneNeed >= 50) and (not invertRate) then--sandbox option to multiply hygiene need rate past neutral
		increaseRate = increaseRate*SandboxVars.LSHygiene.HygieneNeedMultiplier
	end
	if playerData.IsDoingShower then increaseRate = 0; end
	return increaseRate, traitMultiplier, traitMultiplierNeg, invertRate
end

local function HNcorrectNeed(playerData)
	if playerData.hygieneNeed > 100 then
		playerData.hygieneNeed = 100
	elseif playerData.hygieneNeed < 0 then
		playerData.hygieneNeed = 0
	end
end

local function HNdoNeedAdjustment(playerData, increaseRate, invertRate)
	if (playerData.hygieneNeed < 100) and (increaseRate > 0) and not invertRate then
		playerData.hygieneNeed = playerData.hygieneNeed + increaseRate
	elseif (playerData.hygieneNeed > 50) and (increaseRate > 0) and invertRate then
		playerData.hygieneNeed = playerData.hygieneNeed - increaseRate
	end
	HNcorrectNeed(playerData)
end

local function getMoodPosValues(hygieneNeed)
	local hygieneGoodValue, multiplierValue = 0, 1

	if hygieneNeed < 10 then hygieneGoodValue = 0.8; multiplierValue = 3;
	elseif hygieneNeed < 20 then hygieneGoodValue = 0.6; multiplierValue = 2;
	elseif hygieneNeed < 30 then hygieneGoodValue = 0.4;
	elseif hygieneNeed < 40 then hygieneGoodValue = 0.2; end

	return hygieneGoodValue, multiplierValue
end

local function doMoodPos(traitMultiplier, stressLvl, unhappinessLvl, multiplierValue)
	local moodList = {
		["Unhappiness"] = {-(unhappinessLvl*multiplierValue)*traitMultiplier, false, false, true},
		["Stress"] = {-(stressLvl*multiplierValue)*traitMultiplier, false, false, true},
	}
	for k, v in pairs(moodList) do
		if not v[3] then -- refuses to add from isSet
			if not LSMoodHandler.PerMin[k] then
				LSMoodHandler.PerMin[k] = {v[1], v[2], v[3], v[4]}
			else
				LSMoodHandler.PerMin[k][1] = LSMoodHandler.PerMin[k][1]+v[1]
			end
		end
	end
end

local function HNdoMoodleAdjustmentPos(thisPlayer, playerData, traitMultiplier, stressLvl, unhappinessLvl)
	local hygieneGoodValue, multiplierValue = getMoodPosValues(playerData.hygieneNeed)

	if hygieneGoodValue == 0.2 then
		if traitMultiplier > 1 then traitMultiplier = 1; end
	end

	playerData.LSMoodles["HygieneGood"].Value = hygieneGoodValue
	if (hygieneGoodValue > 0) and (not thisPlayer:isAsleep()) then
		doMoodPos(traitMultiplier, stressLvl, unhappinessLvl, multiplierValue)
	end
	
end

local function doMoodNeg(traitMultiplierNeg, stressLvl, unhappinessLvl, multiplierValue)
	local moodList = {
		["Unhappiness"] = {(unhappinessLvl*multiplierValue)*traitMultiplierNeg, false, false, true},
		["Stress"] = {(stressLvl*multiplierValue)*traitMultiplierNeg, false, false, true},
	}
	for k, v in pairs(moodList) do
		if not v[3] then -- refuses to add from isSet
			if not LSMoodHandler.PerMin[k] then
				LSMoodHandler.PerMin[k] = {v[1], v[2], v[3], v[4]}
			else
				LSMoodHandler.PerMin[k][1] = LSMoodHandler.PerMin[k][1]+v[1]
			end
		end
	end
end

local function getMoodNegValues(hygieneNeed)
	local hygieneBadValue, multiplierValue = 0, 1

	if hygieneNeed > 90 then hygieneBadValue = 0.8; multiplierValue = 3;
	elseif hygieneNeed > 80 then hygieneBadValue = 0.6; multiplierValue = 2;
	elseif hygieneNeed > 70 then hygieneBadValue = 0.4;
	elseif hygieneNeed > 60 then hygieneBadValue = 0.2; multiplierValue = 0.5; end

	return hygieneBadValue, multiplierValue
end

local function HNdoMoodleAdjustmentNeg(thisPlayer, playerData, traitMultiplierNeg, stressLvl, unhappinessLvl)	
	local hygieneBadValue, multiplierValue = getMoodNegValues(playerData.hygieneNeed)
	
	if hygieneBadValue == 0.2 then
		if traitMultiplierNeg > 1 then traitMultiplierNeg = 1; end
	end
	
	if playerData.LSMoodles["SmellGood"] and (playerData.LSMoodles["SmellGood"].Value > 0) then
		if hygieneBadValue == 0.8 then hygieneBadValue = 0.4; elseif hygieneBadValue == 0.6 then hygieneBadValue = 0.2; else hygieneBadValue = 0 end
	end
	
	playerData.LSMoodles["HygieneBad"].Value = hygieneBadValue
	
	if (hygieneBadValue > 0) and (not thisPlayer:isAsleep()) then
		doMoodNeg(traitMultiplierNeg, stressLvl, unhappinessLvl, multiplierValue)
	end
end

local function HNgetDay(thisPlayer,playerData)
	local lsData = ModData.getOrCreate("LSDATA")
	if lsData and lsData["SO"] and lsData["SO"]["HNE"] then
		return lsData["SO"]["HNE"]
	else
		--print("HNgetDay FAILED - setting day to default 3")
		return 3
	end
end

local function HNcheckDaysSurvived(thisPlayer, playerData)
	if not playerData.hygieneNeedETime then playerData.hygieneNeedETime = HNgetDay(thisPlayer,playerData); end
	if (playerData.hygieneNeedETime) and (tonumber(thisPlayer:getHoursSurvived())/24 <= playerData.hygieneNeedETime) and (playerData.hygieneNeed > 60) then
		--print("HNcheckDaysSurvived hygieneNeedETime is.. "..playerData.hygieneNeedETime.." days")
		playerData.hygieneNeed = 50
	end
end

function AdjustHygieneNeed(thisPlayer, playerData)
	local totalBlood, totalDirt = HNgetBloodDirt(thisPlayer)
	----------------- 
	local stressLvl, unhappinessLvl = 0.005, 0.015
	----------------- 
	HNdoPlayerDataCheck(thisPlayer, playerData)
	-----------------
	local increaseRate, traitMultiplier, traitMultiplierNeg, invertRate = HNgetVariables(thisPlayer, playerData, totalBlood, totalDirt)
	-----------------
	HNdoNeedAdjustment(playerData, increaseRate, invertRate)
	-----------------
	HNcheckDaysSurvived(thisPlayer, playerData)
	-----------------
	if (playerData.hygieneNeed < 40) or (playerData.LSMoodles["HygieneGood"].Value > 0) then HNdoMoodleAdjustmentPos(thisPlayer, playerData, traitMultiplier, stressLvl, unhappinessLvl); end
	--------------
	if (playerData.hygieneNeed > 60) or (playerData.LSMoodles["HygieneBad"].Value > 0) then HNdoMoodleAdjustmentNeg(thisPlayer, playerData, traitMultiplierNeg, stressLvl, unhappinessLvl); end
	--------------
end

