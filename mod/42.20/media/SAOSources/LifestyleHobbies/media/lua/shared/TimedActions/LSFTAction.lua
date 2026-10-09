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

LSFTAction = ISBaseTimedAction:derive("LSFTAction");

function LSFTAction:isValid()
	return true;
end

function LSFTAction:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.teller);
	return self.character:shouldBeTurning();
end

local function doMoodChange(character, isPositive)
	if not isPositive then
		if character:getModData().LSMoodles["FTBad"] and character:getModData().LSMoodles["FTBad"].Value then character:getModData().LSMoodles["FTBad"].Value = 1; end
		LSUtil.changeCharacterMood(character, "Unhappiness", 80, true, false, true)
		--HaloTextHelper.addTextWithArrow(character, getText("IGUI_HaloNote_Unhappiness"), true, 255, 75, 75)
		return
	end
	if character:getModData().LSMoodles["FTGood"] and character:getModData().LSMoodles["FTGood"].Value then character:getModData().LSMoodles["FTGood"].Value = 1; end
	LSUtil.changeCharacterMood(character, "Unhappiness", -80, true, false, true)
	--HaloTextHelper.addTextWithArrow(character, getText("IGUI_HaloNote_Unhappiness"), false, 70, 255, 50)
end

local function doChangeOverlay(teller, newSprite, stage)
	teller:setOverlaySprite(newSprite, false)
end

local function getOverlayTable(spriteName)
	local t = {
		LS_Sculptures3_51 = {on="LS_Sculptures3_52",pos="LS_Sculptures3_54",bad="LS_Sculptures3_53"}
	}
	return t[spriteName] or false
end

local function getNewSound(oldSound, soundTable)
	local t = soundTable
	if oldSound then
		t = {}
		for n=1, #soundTable do
			if soundTable[n] ~= oldSound then table.insert(t, soundTable[n]); end
		end
	end

	return t[ZombRand(#t)+1]
end

local function doThirdPhase(character, teller, oT)
	local isPositive
	if (not character:getModData().LSFTForceNeg) and ZombRand(101) <= 60 then isPositive = true; end
	local anim, outcomeOverlay, r, g, b = "Bob_Converse_Agreeing", oT['pos'], 0.41, 1, 0.41
	if not isPositive then anim, outcomeOverlay, r, g, b = "Bob_Converse_Agony", oT['bad'], 0.784, 0, 0.235; end
	doChangeOverlay(teller, outcomeOverlay)
	local light = IsoLightSource.new(teller:getX(), teller:getY(), teller:getZ(), r, g, b, 1)
	local sound = character:getEmitter():playSound("FortuneTeller_Talk1")
	character:getModData().LSFTForceNeg = true
	return isPositive, sound, anim, light
end

local function doSecondPhase(character, teller, oT)
	local sound = character:getEmitter():playSound("FortuneTeller_PowerOn")
	local soundLoop = character:getEmitter():playSound("FortuneTeller_LOOP")
	doChangeOverlay(teller, oT['on'])
	local light = IsoLightSource.new(teller:getX(), teller:getY(), teller:getZ(), 1, 0.84, 0, 1)
	return sound, soundLoop, light
end

local function doFirstPhase(character)
	local sound = character:getEmitter():playSound("FortuneTeller_Typing1")


	return sound
end

local function stopSound(character, sound)
	if sound and sound ~= 0 and character:getEmitter():isPlaying(sound) then
		character:getEmitter():stopSound(sound)
	end
end

function LSFTAction:update()
	if self.character:isSitOnGround() then self:forceStop(); end
	if (not self.firstPhase) and self.jobProgress > (self.maxTime*0.05) then
		self.firstPhase = true
		self.sound = doFirstPhase(self.character)
	elseif (not self.secondPhase) and self.jobProgress > (self.maxTime*0.30) then
		self.secondPhase = true
		self.count = 0
		stopSound(self.character, self.sound)
		self.sound, self.soundLoop, self.light = doSecondPhase(self.character, self.teller, self.overlayTable)
		if self.light then self.lightCell:addLamppost(self.light); end
		self:setActionAnim("Bob_Converse_Listening01")
	elseif (not self.thirdPhase) and self.jobProgress > (self.maxTime*0.60) then
		self.thirdPhase = true
		self.countTotal = 30
		self.soundTable = {"FortuneTeller_Talk1","FortuneTeller_Talk2","FortuneTeller_Talk3"}
		self.soundName = "FortuneTeller_Talk1"
		stopSound(self.character, self.sound)
		local anim
		if self.light then self.lightCell:removeLamppost(self.light); end
		self.isPositive, self.sound, anim, self.light = doThirdPhase(self.character, self.teller, self.overlayTable)
		if self.light then self.lightCell:addLamppost(self.light); end
		self:setActionAnim(anim)
	end


	if self.thirdPhase or (self.firstPhase and (not self.secondPhase)) then
		self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		if self.count >= self.countTotal then
			self.count = 0
			stopSound(self.character, self.sound)
			self.soundName = getNewSound(self.soundName, self.soundTable)
			self.sound = self.character:getEmitter():playSound(self.soundName)
		end
	end


	self.jobProgress = self:getJobDelta()*self.maxTime
end

function LSFTAction:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	self.character:getEmitter():playSound("PutItemInBag")
	self.overlayTable = getOverlayTable(self.spriteName)
end

local function doNote(character, texture, isPositive)
	local outcomeText = "IGUI_Teller_Good"
	if not isPositive then outcomeText = "IGUI_Teller_Bad"; end
	outcomeText = outcomeText..tostring(ZombRand(5)+1)
	local text = " <CENTRE> "..getText(outcomeText)
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, false, texture, 7, false})
end

function LSFTAction:stop()
	stopSound(self.character, self.sound)
	stopSound(self.character, self.soundLoop)
	doChangeOverlay(self.teller, nil)
	if self.secondPhase then self.character:getEmitter():playSound("FortuneTeller_PowerDown"); end
	if self.light then self.lightCell:removeLamppost(self.light); end
	if self.thirdPhase then
		self.character:getModData().LSCooldowns["FortuneTeller"] = 8
		self.character:getModData().LSFTForceNeg = false
		if not self.isPositive then
			getSoundManager():playUISound("UI_sting_mystical_bad1")
			doMoodChange(self.character, false)
			doNote(self.character, self.spriteName, self.isPositive)
		end
		if isClient() then sendClientCommand(self.character, "LS", "SavePlayerData", {self.character:getModData()}); end
	end
    ISBaseTimedAction.stop(self);		
end

function LSFTAction:perform()
	stopSound(self.character, self.sound)
	stopSound(self.character, self.soundLoop)
	doChangeOverlay(self.teller, nil)
	self.character:getModData().LSCooldowns["FortuneTeller"] = 8
	self.character:getModData().LSFTForceNeg = false
	self.character:getEmitter():playSound("FortuneTeller_PowerDown")
	if self.light then self.lightCell:removeLamppost(self.light); end
	local outcomeSound = "UI_sting_mystical_good1"
	if not self.isPositive then outcomeSound = "UI_sting_mystical_bad1"; end
	doMoodChange(self.character, self.isPositive)
	getSoundManager():playUISound(outcomeSound)
	doNote(self.character, self.spriteName, self.isPositive)
	if isClient() then sendClientCommand(self.character, "LS", "SavePlayerData", {self.character:getModData()}); end
	ISBaseTimedAction.perform(self);
end

function LSFTAction:complete()
	return true
end

function LSFTAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 800
end

function LSFTAction:new(character, teller, spriteName)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.teller = teller
	o.spriteName = spriteName
	o.overlayTable = false
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.firstPhase = false -- typing
	o.secondPhase = false -- waiting
	o.thirdPhase = false -- outcome
	o.sound = 0
	o.soundLoop = 0
	o.soundTable = {"FortuneTeller_Typing1","FortuneTeller_Typing2","FortuneTeller_Typing3"}
	o.soundName = "FortuneTeller_Typing1"
	o.count = 0
	o.countTotal = 15
	o.lightCell = teller:getCell()
	o.light = false
	return o;
end
