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

LSApplyPerfumeAction = ISBaseTimedAction:derive("LSApplyPerfumeAction")

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

local function LSPerfumeGetSoundIdx(character, category)
	if category == "utterance" then
		if character:isFemale() then
			return {"WomanLikeHMM01","WomanLikeHMM02","WomanLikeHMM03"}
		else
			return {"ManLikeHMM01","ManLikeHMM02","ManLikeHMM03"}
		end
	elseif category == "spray" then
		return {"Spray_Perfume01","Spray_Perfume02","Spray_Perfume03","Spray_Perfume04"}
	elseif category == "sniff" then
		return {"Smell_Sniff01","Smell_Sniff02"}
	end
end

local function LSPerfumeGetNewSoundByName(character, category, oldSound)
	local newSound = LSPerfumeGetSoundIdx(character, category)
	local idxS = ZombRand(#newSound) + 1

	if oldSound and (newSound[idxS] == oldSound) then
		local newIdx = doIdxVariation(idxS, #newSound)
		idxS = newIdx
	end	

	return newSound[idxS]
end

local function LSPerfumeGetSoundSimple()
	local sound, dice2 = "Smell_Sniff01", ZombRand(2)
	if dice2 == 0 then sound = "Smell_Sniff02"; end
	return sound
end

function LSApplyPerfumeAction:isValid()
	return true
end

function LSApplyPerfumeAction:update()

	if self.doSoundSniff >= 15 then self:forceComplete(); end

	if (self.doSoundInterval >= self.soundIntervalTotal) then
		self.doSoundInterval = 1
		self.doSoundSniff = self.doSoundSniff + 1
		if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
			self.character:getEmitter():stopSound(self.gameSound);
		end
		local category = "spray"
		if self.doSoundSniff > 3 then category = "sniff"; self.doSoundInterval = 0; end
		self.sound = LSPerfumeGetNewSoundByName(self.character, category, self.oldSound)
		self.gameSound = self.character:getEmitter():playSound(self.sound)
		self.oldSound = self.sound
	end
	
	if self.doSoundInterval ~= 0 then self.doSoundInterval = self.doSoundInterval + getGameTime():getGameWorldSecondsSinceLastUpdate(); end
	if self.doSoundInterval == 0 then self.doSoundSniff = self.doSoundSniff + getGameTime():getGameWorldSecondsSinceLastUpdate(); end
end

function LSApplyPerfumeAction:start()
	self.soundIntervalTotal = 15/GTLSCheck
	self:setActionAnim("Bob_Perfume")

	--self.sound = LSPerfumeGetNewSoundByName(self.character, "spray", false)
	--self.gameSound = self.character:getEmitter():playSound(self.sound)
	--self.oldSound = self.sound

	if self.item then self:setOverrideHandModels(self.item:getWorldStaticItem(), nil); end
end

function LSApplyPerfumeAction:stop()

	if self.gameSound and
	self.gameSound ~= 0 and
	self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

    ISBaseTimedAction.stop(self);
end

function LSApplyPerfumeAction:perform()
	if self.gameSound and
	self.gameSound ~= 0 and
	self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end
	local sound = LSPerfumeGetNewSoundByName(self.character, "utterance", false)
	self.character:getEmitter():playSound(sound)

	self:setOverrideHandModels(nil, nil)
	
	--if self.item then
	--	self.item:setUseDelta(self.useDelta)
	--	self.item:Use()
	--end
	self.character:getModData().LSMoodles["SmellGood"].Value = 1
	LSUtil.changeCharacterMood(self.character, "Unhappiness", -20, true, false, true)
	--------------HALO
	--HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Happyness"), true, 170, 255, 150)
	HaloTextHelper.addGoodText(self.character, getText("IGUI_HaloNote_SmellGood"))
	
	ISBaseTimedAction.perform(self);
end

function LSApplyPerfumeAction:complete()
	LSUtil.adjustFluid(self.item, self.useDelta, self.character)
	return true
end

function LSApplyPerfumeAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 600
end

function LSApplyPerfumeAction:new(character, item, useDelta)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.item = item
	o.stopOnAim = true
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	o.useDelta = useDelta
	o.sound = false
	o.oldSound = false
	o.doSoundInterval = 1
	o.doSoundSniff = 0
	return o;
end

return LSApplyPerfumeAction