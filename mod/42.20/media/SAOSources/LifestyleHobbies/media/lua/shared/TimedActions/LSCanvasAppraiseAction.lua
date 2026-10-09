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
require "Helper/TransferHelper"

LSCanvasAppraiseAction = ISBaseTimedAction:derive("LSCanvasAppraiseAction");

local function cleanString(name)
	local cleanedString = name:gsub("[%(%)]", "")
	local capitalizedString = cleanedString:gsub("^%l", string.upper)
	return capitalizedString
end

local function getTextRGB(quality)
	if quality == "Bad" then return " <RGB:1,0.7,0.7>"; end
	if quality == "Neutral" then return " <RGB:0.7,0.7,1>"; end
	return " <RGB:0.7,1,0.7>"
end

local function doNote(character, texture, qualityGuess, qualityType)
	local qualityText = cleanString(getText(qualityGuess))
	local qualityRGB = getTextRGB(qualityType)
	local text = getText("IGUI_LSAmbitions_LSBrushmaster_Appraise").." <LINE>".."<CENTRE> "..qualityRGB..qualityText.." !"
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, false, texture, 4, false, false, false}) -- player, mainText, queueType, tex, time, closePerm, infoPanel, noSpam
end

local function getPaintingTex(easel, painting)
	return painting["stage"..tostring(easel:getModData().stage)]
end

local function getQualityRange()
	-- painting quality table from worst to best
	return {"IGUI_PaintingQuality_Awful","IGUI_PaintingQuality_Poor","IGUI_PaintingQuality_Shoddy","IGUI_PaintingQuality_Normal","IGUI_PaintingQuality_Good","IGUI_PaintingQuality_Excellent","IGUI_PaintingQuality_Impressive","IGUI_PaintingQuality_Wondrous","IGUI_PaintingQuality_Masterpiece"}
end

local function getQualityIndex(quality, qualityRange)
	local index
    for i, q in ipairs(qualityRange) do
        if q == quality then
            index = i
            break
        end
    end
	return index
end

local function getMarginBounds(qualityRange, precision, index)
	local lowerBound, upperBound
	local num = 3
	if precision == "medium" then num = 2; elseif precision == "high" then num = 1; end

	lowerBound = math.max(index-num, 1) -- highest number
	upperBound = math.min(index+num, #qualityRange) -- lowest number

	return lowerBound, upperBound
end

local function getQualityType(val)
	if val < 3 then return "Bad"; end
	if val > 5 then return "Good"; end
	return "Neutral"
end

local function getMargin(quality, precision)
	local qualityRange = getQualityRange()
	local index = getQualityIndex(quality, qualityRange)
	local lowerBound, upperBound = getMarginBounds(qualityRange, precision, index)
	local randomIndex = ZombRand(lowerBound, upperBound + 1)
	local qualityType = getQualityType(randomIndex)
	return qualityRange[randomIndex], qualityType
end

local function LSCYGetAnimSound()
	return {
		{name="Bob_Converse_Agreeing",animTime=100,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_Converse_AgreeingHandGesture",animTime=100,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_Converse_Listening01",animTime=120,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_Converse_Acknowledging",animTime=100,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_PullAtCollar",animTime=45,soundType="IntriguedHmm",soundTime=0},
		{name="Bob_PullAtCollar2H",animTime=45,soundType="IntriguedHmm",soundTime=0},
	}
end

local function doIdxVariation(idx, limit)
	local variation = ZombRand(2) == 0 and -1 or 1
	local newIdx = idx+variation
	if newIdx > limit then
		newIdx = 1
	elseif newIdx < 1 then
		newIdx = limit
	end
	return newIdx
end

local function getNextRoutine(animList, oldAnim)
	local idxA = ZombRand(#animList) + 1
	if oldAnim and animList[idxA].name == oldAnim then idxA = doIdxVariation(idxA, #animList); end
	return animList[idxA].name, animList[idxA].animTime, animList[idxA].soundType, animList[idxA].soundTime
	--anim name, anim time, sound type, sound time
end

local function getSoundIdx(sound)
	if (sound == "IntriguedHmm") then
		return {"IntriguedHMM01","IntriguedHMM02","IntriguedHMM03","IntriguedHMM04","IntriguedHMM05","IntriguedHMM06","IntriguedHMM07","IntriguedHMM08","IntriguedHMM09"}
	end
end

local function getSoundIdxEnd(sound)
	if (sound == "Good") then
		return {"AgreeableUHU01","AgreeableUHU02","AgreeableUHU03","LikeHMM01","LikeHMM02","LikeHMM03"}
	elseif (sound == "Bad") then
		return {"NoUHUH01","NoUHUH02","ListenBlowOff01","ListenBlowOff02","ListenBlowOff03"}
	elseif (sound == "Neutral") then
		return {"Bored01","Bored02","IndifferentHMM01","IndifferentHMM02","IndifferentHMM03","IndifferentHMM04","IndifferentHMM05"}
	end
end

local function getNewSoundByName(soundType, oldSound, isFemale, isEnd)
	local newSound, gender = false, "Man"
	if isFemale then gender = "Woman"; end
	if isEnd then newSound = getSoundIdxEnd(soundType); end
	if not newSound then newSound = getSoundIdx(soundType); end
	local idxS = ZombRand(#newSound)+1
	if oldSound and (gender..newSound[idxS] == oldSound) then idxS = doIdxVariation(idxS, #newSound); end
	return gender..newSound[idxS]
end

function LSCanvasAppraiseAction:isValid()
	return true
end

function LSCanvasAppraiseAction:waitToStart()
	--self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.easel)
	return self.character:shouldBeTurning()
end

function LSCanvasAppraiseAction:update()
	if not self.animName then
		self.animName, self.animTime, self.soundType, self.soundTime = getNextRoutine(self.animList, false)
		self.animTime = self.animTime+self.doAnim
		if (self.soundTime ~= 0) then self.soundTimeInterval = self.soundTime+self.doAnim; end
		
		self:setActionAnim(self.animName)
		self.soundName = getNewSoundByName(self.soundType, false, self.character:isFemale(), false)
	
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end

	elseif self.doAnim >= self.animTime then

		local newAnim, newSound
		newAnim, self.animTime, self.soundType, self.soundTime = getNextRoutine(self.animList, self.animName)
		self.animName = newAnim
		self.animTime = self.animTime+self.doAnim
		if (self.soundTime ~= 0) then self.soundTimeInterval = self.soundTime+self.doAnim; end
		
		self:setActionAnim(self.animName)
		if self.gameSoundLoop ~= 0 then
			self.character:getEmitter():stopSound(self.gameSoundLoop)
		end
		newSound = getNewSoundByName(self.soundType, self.soundName, self.character:isFemale(), false)
		self.soundName = newSound
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end
		
	end

	if self.soundTimeInterval and (self.soundTime ~= 0) and (self.doAnim >= self.soundTimeInterval) then
		soundTimeInterval = self.soundTime+self.doAnim
		if self.gameSoundLoop ~= 0 then
			self.character:getEmitter():stopSound(self.gameSoundLoop)
		end
		local newSound
		newSound = getNewSoundByName(self.soundType, self.soundName, self.character:isFemale(), false)
		self.soundName = newSound
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end
	
	end

	self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)

end

function LSCanvasAppraiseAction:start()
	self:setOverrideHandModels(nil, nil)
	self.animList = LSCYGetAnimSound()
	if self.character:hasTrait(CharacterTrait.DEAF) then self.canTalk = false; end
end

function LSCanvasAppraiseAction:stop()
	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
    ISBaseTimedAction.stop(self);	
end

function LSCanvasAppraiseAction:perform()
	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
	local qualityGuess, qualityType = getMargin(self.quality, self.precision)
	local paintingTexture = getPaintingTex(self.easel, self.painting)
	-------------------------
	--------------SOUND
	if self.canTalk then
		local sound = getNewSoundByName(qualityType, false, self.character:isFemale(), true)
		self.character:getEmitter():playSound(sound)
	end
	
	doNote(self.character, paintingTexture, qualityGuess, qualityType)
	self.character:getModData().LSCooldowns['brushmaster'] = 6

	ISBaseTimedAction.perform(self);
end

function LSCanvasAppraiseAction:complete()
	return true
end

function LSCanvasAppraiseAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 800
end

function LSCanvasAppraiseAction:new(character, easel, painting, precision)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.easel = easel
	o.painting = painting
	o.precision = precision
	o.quality = painting.quality
	o.gameSoundLoop = 0
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.animList = false
	o.doAnim = 0
	o.animName = false
	o.animTime = false
	o.soundType = false
	o.soundTime = 0
	o.soundTimeInterval = false
	o.canTalk = true
	return o;
end

return LSCanvasAppraiseAction