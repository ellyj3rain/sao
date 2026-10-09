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

LSPlushiesTalk = ISBaseTimedAction:derive("LSPlushiesTalk");

function LSPlushiesTalk:isValid()
	return true;
end

function LSPlushiesTalk:waitToStart()
	self.action:setUseProgressBar(false)
	return false
end

local function getBonus(uses, ambt)
	local bonus = 60
	if ambt then bonus = 120; end
	if uses['plushiesTalk'] == 1 then
		bonus = bonus/2
	elseif uses['plushiesTalk'] > 1 then
		bonus = math.floor(bonus/uses['plushiesTalk'])
	end
	return bonus
end

local function doMoodChange(character, uses, ambt)
	local bonus = getBonus(uses, ambt)
	if bonus < 5 then return; end
	local otherColors, greenColor = math.max(70, 150-bonus), math.min(255, 200+bonus)
	LSUtil.changeCharacterMood(character, "Unhappiness", -bonus, false, false)
	HaloTextHelper.addTextWithArrow(character, getText("IGUI_HaloNote_Unhappiness").." -"..tostring(bonus), false, otherColors, greenColor, otherColors)
	getSoundManager():playUISound("UI_Painting_Complete")
end

local function getNewParam(oldParam, paramTable)
	local t = paramTable
	if oldParam then
		t = {}
		for n=1, #paramTable do
			if paramTable[n] ~= oldParam then table.insert(t, paramTable[n]); end
		end
	end

	return t[ZombRand(#t)+1]
end

local function stopSound(character, sound)
	if sound and sound ~= 0 and character:getEmitter():isPlaying(sound) then
		character:getEmitter():stopSound(sound)
	end
end

local function stopUISound(soundUI)
	if soundUI and soundUI ~= 0 and getSoundManager():isPlayingUISound(soundUI) then
		getSoundManager():stopUISound(soundUI)
	end
end

function LSPlushiesTalk:update()
	if self.character:isSitOnGround() then self:forceStop(); end
	self.jobProgress = self:getJobDelta() * self.maxTime
	

	for _, phase in ipairs(self.phases) do
		if (not self.phaseStates[phase.name]) and self.jobProgress > (self.maxTime * phase.threshold) then
			self.phaseStates[phase.name] = true
			self[phase.handler](self)
			break
		end
	end

	--local timeTick = getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck -- do not use it here


	if not self.silenceDoll then
		self.squeakCount = self.squeakCount+(getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		if self.squeakCount >= self.squeakCountTotal then
			self.squeakCountTotal = ZombRand(30)+30
			self.squeakCount = 0
			self.soundNameDoll = getNewParam(self.soundNameDoll, self.soundTableDoll)
			self.character:getEmitter():playSound(self.soundNameDoll)
		end
	elseif self.squeakCountTotal ~= 10 then
		self.squeakCountTotal = 10
	end
	
	if self.actionCountTotal then
		self.actionCount = self.actionCount+(getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		if self.actionCount >= self.actionCountTotal then
			self.actionCount = 0
			stopSound(self.character, self.sound)
			self.soundName = getNewParam(self.soundName, self.soundTable[self.soundGroup])
			self.sound = self.character:getEmitter():playSound(self.soundName)
		end
	end
end

function LSPlushiesTalk:showToy()
	self:setOverrideHandModels(self.plushy:getWorldStaticItem(), nil)
end

function LSPlushiesTalk:stopAndHold()
	stopSound(self.character, self.sound)
	stopUISound(self.soundUI)
	self:setActionAnim("Bob_"..self.animPlushy.."_Hold")
	self.actionCountTotal = false
end

function LSPlushiesTalk:endInteraction()
	stopSound(self.character, self.sound)
	stopUISound(self.soundUI)
	self:setActionAnim(self.animEnd)
	self.actionCountTotal = false
end

local function getNewSoundTable(sex, group)
	local t = {
		Cheer = {sex.."Cheer01",sex.."Cheer02",sex.."Cheer03",sex.."Cheer04"},
		Listen = {sex.."ListenAttentive01",sex.."ListenAttentive02",sex.."ListenAttentive03",sex.."ListenAttentive04"},
		Hug = {sex.."_Hug_Good1",sex.."_Hug_Good2",sex.."_Hug_Good3"}
	}
	return t
end

local function getInteractionArgs(action, group)
	local t = {
		HoldFar = {anim="Bob_"..group.."_HoldFar",sound="Cheer",count=35},
		Cuddle = {anim="Bob_"..group.."_Cuddle",sound="Hug",count=90},
		Whisper = {anim="Bob_"..group.."_Whisper",sound="Listen",count=40}
	}
	return t[action].anim, t[action].sound, t[action].count
end

function LSPlushiesTalk:doInteraction()
	stopSound(self.character, self.sound)
	stopUISound(self.soundUI)
	self.actionCount = 0
	
	self.currentAction = getNewParam(self.currentAction, self.actionTable)
	self.anim, self.soundGroup, self.actionCountTotal = getInteractionArgs(self.currentAction, self.animPlushy)
	
	if self.soundGroup == "Listen" and ZombRand(100) <= self.demonicChance then
		self.actionCountTotal, self.silenceDoll, self.soundName = false, true, "Toy_Mutter1"
		self.soundUI = getSoundManager():playUISound(self.soundName)
	else
		self.soundName = getNewParam(self.soundName, self.soundTable[self.soundGroup])
		self.silenceDoll = false
		self.sound = self.character:getEmitter():playSound(self.soundName)
	end
	
	self:setActionAnim(self.anim)
end

local function minMult(value)
	local val, thresholds = 0, {
		{80, 10},
		{60, 5},
		{30, 2}
	}
	for _, t in ipairs(thresholds) do
		if value >= t[1] then val = t[2] break; end
	end
	return val
end

local function getDemonWhisperChance(character)
	local chance = 1
	if CharacterTrait.KOOK and character:hasTrait(CharacterTrait.KOOK) then chance = chance+25; end
	chance = chance+minMult(LSUtil.getCharacterMood(character, "Unhappiness"))
	return chance
end

function LSPlushiesTalk:start()
	self.demonicChance = getDemonWhisperChance(self.character)
	self.hasAmbt = LSAmbtMng.hasCompleted(self.character,"LSPlushies")

	self:setOverrideHandModels(nil, nil)
	self:setActionAnim(self.anim)
	self.character:getEmitter():playSound("PutItemInBag")
	
	self.phases = {
		{name="a",threshold=0.01,handler="showToy"},
		{name="b",threshold=0.05,handler="doInteraction"},
		{name="c",threshold=0.35,handler="stopAndHold"},
		{name="d",threshold=0.40,handler="doInteraction"},
		{name="e",threshold=0.70,handler="stopAndHold"},
		{name="f",threshold=0.75,handler="doInteraction"},
		{name="g",threshold=0.95,handler="endInteraction"},
	}
	
	self.soundTable = getNewSoundTable(self.sex)
	if not self.usesData['plushiesTalk'] then self.usesData['plushiesTalk'] = 0; end
	
	if self.ogCont and self.ogCont ~= self.character:getInventory() then
		self:addAfter(ISInventoryTransferAction:new(self.character, self.plushy, self.plushy:getContainer(), self.ogCont))
	end

end

function LSPlushiesTalk:stop()
	stopSound(self.character, self.sound)
	stopUISound(self.soundUI)

    ISBaseTimedAction.stop(self);		
end

function LSPlushiesTalk:perform()
	stopSound(self.character, self.sound)
	stopUISound(self.soundUI)

	--self.character:getModData().LSCooldowns["FortuneTeller"] = 8
	doMoodChange(self.character, self.usesData, self.hasAmbt)
	
	local addTime = 3
	if self.hasAmbt then addTime = 2; end
	self.usesData['plushiesTalk'] = math.min(15, self.usesData['plushiesTalk']+addTime)

	ISBaseTimedAction.perform(self);
end

function LSPlushiesTalk:complete()
	return true
end

function LSPlushiesTalk:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 1600
end

function LSPlushiesTalk:new(character, plushy, usesData, sex, animPlushy, startStr, endStr, ogCont)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.plushy = plushy
	o.usesData = usesData
	o.sex = sex
	o.ogCont = ogCont
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.phases = {}
	o.phaseStates = {}
	o.actionTable = {"HoldFar","Cuddle","Whisper"}
	o.currentAction = false
	o.silenceDoll = false
	o.actionCount = 0
	o.actionCountTotal = false
	o.animPlushy = animPlushy
	o.startStr = startStr
	o.endStr = endStr
	o.anim = "Bob_"..animPlushy..startStr
	o.animEnd = "Bob_"..animPlushy..endStr
	o.squeakCount = 0
	o.squeakCountTotal = ZombRand(15)+5
	o.sound = 0
	o.soundUI = 0
	o.soundTable = false
	o.soundName = "none"
	o.soundTableDoll = {"Toy_Squeak1","Toy_Squeak2","Toy_Squeak3","Toy_Squeak4","Toy_Squeak5","Toy_Squeak6"}
	o.soundNameDoll = "none"
	return o;
end

return LSPlushiesTalk