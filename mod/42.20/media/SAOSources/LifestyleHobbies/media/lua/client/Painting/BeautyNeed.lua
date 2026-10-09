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

-- Beauty need:
-- range: 0 to 100
-- < 10 vvv bad / < 20 vv bad / < 30 v bad / < 40 bad / <= 60 neutral / > 60 good / > 70 v good / > 80 vv good / > 90 vvv good
--
-- slowly decreases in bad indoor environments and increases in nice areas or while outdoors
-- rate is defined by positive or negative push
-- p
-- by default, need slowly increases while outdoors - can be changed in sandbox options
-- will never increase beyond 50 (neutral) while outdoors if there's no positive push
local function getDecayRate(option)
	local t = {
		K1 = 0.1,
		K2 = 0.2,
		K3 = 0.4,
		K4 = 0.6,
		K5 = 0.9,
	}

	return t[option] or 0.4
end

local function getNewBeautyNeed(beautyNeed, push, scale, multiRatePos, multiRateNeg)

    beautyNeed = math.max(0, math.min(100, beautyNeed))
    push = math.max(-300, math.min(300, push))

    -- Special drift toward 50 when push is mildly positive
    if push >= 0 and push <= 50 then
        if beautyNeed == 50 then
            return beautyNeed
        end
        local delta = 50 - beautyNeed
        local rate = math.abs(delta) / 100
        rate = rate * (1 - (math.abs(push) / 50)) -- slower as push → 50
		if delta < 0 then
			beautyNeed = beautyNeed-rate*scale*0.5
		else
			beautyNeed = beautyNeed+rate*scale
		end
        return math.max(0, math.min(100, beautyNeed))
    end

    local delta = push - beautyNeed
    if delta == 0 then return beautyNeed; end

    local rate = math.abs(delta) / 100
    rate = rate * (math.abs(push) / 300)

    local distanceFrom50 = math.abs(beautyNeed - 50)
    if (delta < 0 and beautyNeed >= 50) or (delta > 0 and beautyNeed < 50) then
        rate = rate * (1 - (distanceFrom50 / 50))
    end

    if delta < 0 then
		rate = (rate*multiRateNeg)*(beautyNeed / 100)
		scale = getDecayRate("K"..tostring(SandboxVars.LSArt.BeautyNeedDecayRate))
		beautyNeed = beautyNeed-rate*scale
	else
		rate = (rate*multiRatePos)*((100 - beautyNeed) / 100)
		beautyNeed = beautyNeed+rate*scale
    end

    return math.max(0, math.min(100, beautyNeed))
end

local function doPlayerDataCheck(thisPlayer, playerData)
	playerData.BeautyNeed = playerData.BeautyNeed or 50
	if thisPlayer:isGodMod() and playerData.BeautyNeed < 50 then playerData.BeautyNeed = 50; end	
end

local function CNgetDay(thisPlayer,playerData)
	local lsData = ModData.getOrCreate("LSDATA")
	if lsData and lsData["SO"] and lsData["SO"]["CNE"] then
		return lsData["SO"]["CNE"]
	else
		--print("HNgetDay FAILED - setting day to default 3")
		return 3
	end
end

local function CNcheckDaysSurvived(thisPlayer, playerData)
	if not playerData.cleaningETime then playerData.cleaningETime = CNgetDay(thisPlayer,playerData); end
	if (playerData.cleaningETime) and (tonumber(thisPlayer:getHoursSurvived())/24 >= playerData.cleaningETime) then
		return true
	end
	return false
end

local function getTraitValues(thisPlayer, trash, art)
	local t = {
		{trait="SLOPPY",ratePos=1,rateNeg=0.1,multiPos=1,multiNeg=0.5,trashLimit=200,artLimit=0},
		{trait="CLEANFREAK",ratePos=1,rateNeg=1.5,multiPos=1,multiNeg=2,trashLimit=300,artLimit=0}, -- no compatibility between Sloppy and CleanFreak so order doesn't matter
		{trait="ARTISTIC",ratePos=1.5,rateNeg=0.5,multiPos=2,multiNeg=1,trashLimit=0,artLimit=50}, -- no HatesArt since it's already accounted for in addArtValue, Artistic goes above Tidy since it has better effects
		{trait="TIDY",ratePos=1,rateNeg=0.4,multiPos=1,multiNeg=0.8,trashLimit=200,artLimit=0}, -- In case player has both traits, applies only when not enough art is present
	}
	for k, v in pairs(t) do
		if thisPlayer:hasTrait(CharacterTrait[v.trait]) and trash >= v.trashLimit and art >= v.artLimit then
			return v.ratePos, v.rateNeg, v.multiPos, v.multiNeg
		end
	end
	return 1, 0.5, 1, 1
end

local function getVariables(thisPlayer, trash, art)
	return getTraitValues(thisPlayer, trash, art) -- rate is affected by trait multipliers ONLY if trash is significant or if there's player made art nearby
end

local function setMood(thisPlayer, unhappyVal, stressVal)
	local moodList = {
		["Stress"] = {stressVal, false, false, true},
		["Unhappiness"] = {unhappyVal, false, false, true},
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

local function getMoodPosValue(beauty)
	local t = {
		{threshold=90,moodle=0.8,multi=3},
		{threshold=80,moodle=0.6,multi=2},
		{threshold=70,moodle=0.4,multi=1},
		{threshold=60,moodle=0.2,multi=0.5},
	}
	for k, v in pairs(t) do
		if beauty > v.threshold then
			return v.moodle, v.multi
		end
	end
	return 0, 1
end

local function getMoodPos(traitMultiplier, stressLvl, unhappinessLvl, multiplierValue)
	local unhappyVal = 0-((unhappinessLvl*multiplierValue)*traitMultiplier)
	local stressVal = 0-((stressLvl*multiplierValue)*traitMultiplier)
	return unhappyVal, stressVal
end

local function doMoodleAdjustmentPos(thisPlayer, playerData, traitMultiplier, stressLvl, unhappinessLvl)
	local beautyVal, multiVal = getMoodPosValue(playerData.BeautyNeed)
	if not SandboxVars.Text.DividerArt then beautyVal = 0; end
	playerData.LSMoodles["BeautyGood"].Value = beautyVal
	if (beautyVal > 0) and (not thisPlayer:isAsleep()) then
		local unhappyVal, stressVal = getMoodPos(traitMultiplier, stressLvl, unhappinessLvl, multiVal)
		setMood(thisPlayer, unhappyVal, stressVal)
	end
	
end

local function getMoodNeg(traitMultiplierNeg, stressLvl, unhappinessLvl, multiplierValue)
	local unhappyVal = (unhappinessLvl*multiplierValue)*traitMultiplierNeg
	local stressVal = (stressLvl*multiplierValue)*traitMultiplierNeg
	return unhappyVal, stressVal
end

local function getMoodNegValue(beauty)
	local t = {
		{threshold=10,moodle=0.8,multi=3},
		{threshold=20,moodle=0.6,multi=2},
		{threshold=30,moodle=0.4,multi=1},
		{threshold=40,moodle=0.2,multi=0.5},
	}
	for k, v in pairs(t) do
		if beauty < v.threshold then
			return v.moodle, v.multi
		end
	end
	return 0, 1
end

local function doMoodleAdjustmentNeg(thisPlayer, playerData, traitMultiplierNeg, stressLvl, unhappinessLvl)
	local beautyVal, multiVal = getMoodNegValue(playerData.BeautyNeed)	
	playerData.LSMoodles["BeautyNeg"].Value = beautyVal
	if (beautyVal > 0) and (not thisPlayer:isAsleep()) then
		local unhappyVal, stressVal = getMoodNeg(traitMultiplierNeg, stressLvl, unhappinessLvl, multiVal)
		setMood(thisPlayer, unhappyVal, stressVal)
	end
end

local function getBaseMoodLvls(level)
	local t = {
		L1 = {0.00015, 0.0005},
		L2 = {0.0005, 0.0015},
		L3 = {0.0015, 0.005},
		L4 = {0.003, 0.01},
		L5 = {0.006, 0.02},
	}
	if not t[level] then return 0.0015, 0.005; end
	return t[level][1] or 0.0015, t[level][2] or 0.005
end

function adjustBeautyNeed(thisPlayer, playerData, push, trash, art)
	----------------- 
	local stressLvl, unhappinessLvl = getBaseMoodLvls("L"..tostring(SandboxVars.LSArt.BeautyNeedStrength))
	----------------- 
	doPlayerDataCheck(thisPlayer, playerData)
	-----------------
	local multiRatePos, multiRateNeg, traitMultiplier, traitMultiplierNeg = getVariables(thisPlayer, trash, art)
	-----------------
	if not SandboxVars.LSArt.BeautyOutdoors and thisPlayer:isOutside() and push < 0 then push = 0; end
	-----------------
	local newBeauty = math.max(0, math.min(100, getNewBeautyNeed(playerData.BeautyNeed, push, 0.8, multiRatePos, multiRateNeg)))
	-----------------
	--thisPlayer:Say("Push is "..tostring(push)); thisPlayer:Say("BN is "..tostring(playerData.BeautyNeed))
	-----------------
	if not CNcheckDaysSurvived(thisPlayer,playerData) then newBeauty = math.max(40, newBeauty); end
	-----------------
	if not SandboxVars.Text.DividerArt then newBeauty = math.min(60, newBeauty); end
	-----------------
	playerData.BeautyNeed = newBeauty
	-----------------
	if (newBeauty > 60) or (playerData.LSMoodles["BeautyGood"].Value > 0) then doMoodleAdjustmentPos(thisPlayer, playerData, traitMultiplier, stressLvl, unhappinessLvl); end
	--------------
	if (newBeauty < 40) or (playerData.LSMoodles["BeautyNeg"].Value > 0) then doMoodleAdjustmentNeg(thisPlayer, playerData, traitMultiplierNeg, stressLvl, unhappinessLvl); end
	--------------
end

