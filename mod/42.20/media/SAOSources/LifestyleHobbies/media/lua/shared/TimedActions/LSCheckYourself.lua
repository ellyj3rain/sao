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

LSCheckYourself = ISBaseTimedAction:derive("LSCheckYourself");

local function LSCYGetAnimSound(character, actionType)

	local animList

	if actionType == "GussyUp" then
		animList = {
			{name="Bob_PullAtCollar",animTime=45,soundType="IntriguedHmm",soundTime=0},
			{name="Bob_PullAtCollar2H",animTime=45,soundType="IntriguedHmm",soundTime=0},
			{name="Shave",animTime=60,soundType="IntriguedHmm",soundTime=0},
			{name="Bob_WipeHead",animTime=45,soundType="IntriguedHmm",soundTime=0},
		}
	elseif actionType == "PepTalk" then
		animList = {
			{name="Bob_Converse_Agreeing",animTime=100,soundType="Cheer",soundTime=0},
			{name="Bob_Converse_AgreeingHandGesture",animTime=100,soundType="Cheer",soundTime=0},
			{name="Bob_Converse_Listening01",animTime=120,soundType="Cheer",soundTime=0},
			{name="Bob_Converse_Acknowledging",animTime=100,soundType="Cheer",soundTime=0},
		}
	elseif actionType == "CalmDown" then
		animList = {
			{name="Bob_PainHead",animTime=45,soundType="Mutter",soundTime=0},
			{name="Bob_FeelFeint",animTime=45,soundType="Mutter",soundTime=0},
			{name="Bob_ChewNails",animTime=45,soundType="Mutter",soundTime=0},
			--{name="Bob_HeavyBreathing",animTime=45,soundType="Mutter",soundTime=0},
		}
	end

	return animList

end

local function doIdxVariation(idx, limit)

	local variation = ZombRand(2) + 1
	local newIdx

	if idx == limit then--last
		newIdx = idx-variation
	elseif idx == 1 then--first
		newIdx = idx+variation
	else
		if variation == 1 then
			newIdx = idx-1
		elseif variation == 2 then
			newIdx = idx+1
		end
	end

	return newIdx

end

local function getNextRoutine(animList, oldAnim)

	local idxA = ZombRand(#animList) + 1

	if oldAnim and animList[idxA].name == oldAnim then
		local newIdx = doIdxVariation(idxA, #animList)
		idxA = newIdx
	end

	return animList[idxA].name, animList[idxA].animTime, animList[idxA].soundType, animList[idxA].soundTime
	--anim name, anim time, sound type, sound time
end

local function getSoundIdx(sound, isFemale)

	if (sound == "IntriguedHmm") and isFemale then
		return {"WomanIntriguedHMM01","WomanIntriguedHMM02","WomanIntriguedHMM03","WomanIntriguedHMM04","WomanIntriguedHMM05","WomanIntriguedHMM06","WomanIntriguedHMM07","WomanIntriguedHMM08","WomanIntriguedHMM09"}
	elseif sound == "IntriguedHmm" then
		return {"ManIntriguedHMM01","ManIntriguedHMM02","ManIntriguedHMM03","ManIntriguedHMM04","ManIntriguedHMM05","ManIntriguedHMM06","ManIntriguedHMM07","ManIntriguedHMM08","ManIntriguedHMM09"}
	elseif (sound == "Cheer") and isFemale then
		return {"WomanCheer03","WomanCheer04"}
	elseif sound == "Cheer" then
		return {"ManCheer01","ManCheer02"}
	elseif (sound == "Mutter") and isFemale then
		return {"WomanMutter01","WomanMutter02","WomanMutter03","WomanMutter04"}
	elseif (sound == "Mutter") then
		return {"ManMutter01","ManMutter02","ManMutter03","ManMutter04","ManMutter05","ManMutter06"}
	end

end

local function getSoundIdxEnd(sound, isFemale)

	if (sound == "UhuhGood") and isFemale then
		return {"WomanAgreeableUHU01","WomanAgreeableUHU02","WomanAgreeableUHU03"}
	elseif sound == "UhuhGood" then
		return {"ManAgreeableUHU01","ManAgreeableUHU02","ManAgreeableUHU03"}
	elseif (sound == "CheerFail") and isFemale then
		return {"WomanCheereeCry01","WomanCheereeCry02"}
	elseif sound == "CheerFail" then
		return {"ManCheereeCry01","ManCheereeCry02"}
	elseif (sound == "CheerSuccess") and isFemale then
		return {"WomanCheer01","WomanCheer02"}
	elseif (sound == "CheerSuccess") then
		return {"ManCheer03","ManCheer04"}
	elseif (sound == "CalmDownTantrum") and isFemale then
		return {"WomanFrustrated01","WomanFrustrated02","WomanFrustrated03"}
	elseif sound == "CalmDownTantrum" then
		return {"ManFrustrated01","ManFrustrated02","ManFrustrated03"}
	elseif (sound == "CalmDownSuccess") and isFemale then
		return {"WomanBored01","WomanBored02"}
	elseif (sound == "CalmDownSuccess") then
		return {"ManBored01","ManBored02"}
	end

end

local function getNewSoundByName(soundType, oldSound, isFemale, isEnd)

	local newSound
	if isEnd then
		newSound = getSoundIdxEnd(soundType, isFemale)
	else
		newSound = getSoundIdx(soundType, isFemale)
	end

	local idxS = ZombRand(#newSound) + 1

	if oldSound and (newSound[idxS] == oldSound) then
		local newIdx = doIdxVariation(idxS, #newSound)
		idxS = newIdx
	end

	return newSound[idxS]

end

function LSCheckYourself:isValid()

	return true
end

function LSCheckYourself:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.mirrorObject)

	return self.character:shouldBeTurning()
end

function LSCheckYourself:update()

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

function LSCheckYourself:start()

	if self.actionType == "GussyUp" then
		self:setOverrideHandModels(self.combItem:getWorldStaticItem(), nil)
	else
		self:setOverrideHandModels(nil, nil)
	end

	self.animList = LSCYGetAnimSound(self.character, self.actionType)

	self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed or 0

	if self.character:hasTrait(CharacterTrait.DEAF) then self.canTalk = false; end

end

function LSCheckYourself:stop()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end

    ISBaseTimedAction.stop(self);
		
end

function LSCheckYourself:perform()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end

	local haloName, haloArrow, haloR, haloG, haloB, soundType, moodle, d20 = "IGUI_HaloNote_Hygiene", true, 170, 255, 150, "UhuhGood", "Attractive", ZombRand(20)+1
	local currentEmbarrassment = self.character:getModData().LSMoodles["Embarrassed"].Value

	if self.actionType == "GussyUp" then
		self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed - 5
		if (self.character:getModData().hygieneNeed < 0) then self.character:getModData().hygieneNeed = 0; end
	elseif self.actionType == "PepTalk" then
		if (d20 >= 18) then
			haloName, haloArrow, haloR, haloG, haloB, soundType, moodle = "IGUI_HaloNote_Happyness", false, 255, 120, 120, "CheerFail", false
			LSUtil.changeCharacterMood(self.character, "Unhappiness", 20, false, false, true)
		else
			haloName, soundType, moodle = "IGUI_HaloNote_Happyness", "CheerSuccess", false
			LSUtil.changeCharacterMood(self.character, "Unhappiness", -60, false, false, true)
			if currentEmbarrassment and (currentEmbarrassment > 0) then
				HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 180, 255, 180)
				self.character:getModData().LSMoodles["Embarrassed"].Value = currentEmbarrassment - 0.4
				if (self.character:getModData().LSMoodles["Embarrassed"].Value < 0) then
					self.character:getModData().LSMoodles["Embarrassed"].Value = 0
				end
			end
		end
		if not self.character:getModData().LSCooldowns then self.character:getModData().LSCooldowns = {}; end
		self.character:getModData().LSCooldowns["mirrorPT"] = 3
	elseif self.actionType == "CalmDown" then
		if (d20 >= 18) then
			haloName, haloArrow, haloR, haloG, haloB, soundType, moodle = "IGUI_HaloNote_Stress", false, 255, 120, 120, "CalmDownTantrum", false
			LSUtil.changeCharacterMood(self.character, "Stress", 0.2, false, false, true)
		else
			haloName, soundType, moodle = "IGUI_HaloNote_Stress", "CalmDownSuccess", false
			LSUtil.changeCharacterMood(self.character, "Stress", -0.6, false, false, true)
		end
		self.character:getModData().LSCooldowns["mirrorCD"] = 3
	end

	-------------------------
	--------------SOUND
	if self.canTalk then
		local sound = getNewSoundByName(soundType, false, self.character:isFemale(), true)
		self.character:getEmitter():playSound(sound)
	end
	-------------------------
	--------------HALO
	HaloTextHelper.addTextWithArrow(self.character, getText(haloName), haloArrow, haloR, haloG, haloB)
	-------------------------
	--------------MOODLE
	if moodle and (self.character:getModData().LSMoodles[moodle]) and (self.character:getModData().LSMoodles[moodle].Value) then
		HaloTextHelper.addGoodText(self.character, getText("IGUI_HaloNote_"..moodle))
		self.character:getModData().LSMoodles[moodle].Value = 0.6
	end
	-------------------------
	--------------ITEMTRANSFER
	if self.srcContainer and self.combItem then
		if not self.srcContainer:isItemAllowed(self.combItem) then
			-- 
		elseif self.srcContainer:getType() == "floor" then
			TransferHelper.dropItem(self.combItem, self.character)
		else
			TransferHelper.onMoveItemsTo(self.combItem, self.srcContainer, self.character, true, self.character:getInventory())
		end	
	end


	ISBaseTimedAction.perform(self);
end

function LSCheckYourself:complete()
	return true
end

function LSCheckYourself:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function LSCheckYourself:new(character, mirrorObject, combItem, srcContainer, actionType, actionTime)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.mirrorObject = mirrorObject
	o.combItem = combItem
	o.srcContainer = srcContainer
	o.actionType = actionType
	o.actionTime = actionTime
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

return LSCheckYourself