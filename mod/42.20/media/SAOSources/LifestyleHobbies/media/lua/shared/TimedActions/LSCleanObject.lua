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

LSCleanObject = ISBaseTimedAction:derive("LSCleanObject");

local function predicateNotBroken(item)
	return not item:isBroken()
end

local function predicateNotEmpty(item)
	if not item then return false; end
	local fluidContainer = item:getFluidContainer()
	local primaryFluid = fluidContainer and fluidContainer:getPrimaryFluid()
	return fluidContainer and fluidContainer:getAmount() > 0 and primaryFluid and primaryFluid:getFluidTypeString() == "CleaningLiquid"
end

-- theres currently (42.19) a bug with getFirstAvailableFluidContainer for items that spawn with liquid and were never used
-- behavior - if the item is the only fluid container item - getFirstAvailableFluidContainer will fail
-- behavior - if theres another fluid container item - getFirstAvailableFluidContainer will return that container even if it doesn't contain the requested fluid or any fluid

function LSCleanObject:clean()
	--print("LSCleanObject:clean, start")
	--print("LSCleanObject:clean, isServer == "..tostring(isServer()))
	if not self.detergent or self.detergent:getFluidContainer():isEmpty() then
		local playerInv = self.character:getInventory()
		self.detergent = playerInv:getFirstTypeEvalRecurse("Base.CleaningLiquid2", predicateNotEmpty) or playerInv:getFirstAvailableFluidContainer("CleaningLiquid")
		if not self.detergent or self.detergent:getFluidContainer():isEmpty() then
			--print("LSCleanObject:clean, no detergent - ending action")
			if isServer() then
				self.netAction:forceComplete()
			else
				self:forceStop()
			end
			return
		end
	end
	self.detergent:getFluidContainer():removeFluid(self.drainRate, false)
	--sendItemStats(self.detergent)
	self.detergent:sendSyncEntity(nil)

	local movData = self.obj:getModData().movableData
	local conMovData
	movData['condition'] = math.max(0,movData['condition']-2)
	--print("LSCleanObject:clean, obj condition == "..tostring(movData['condition']))
	--print("LSCleanObject:clean, obj dirtyLevel == "..tostring(movData['dirtyLevel']))
	local changeLevel
	if movData['dirtyLevel'] == 1 and movData['condition'] < 30 then
		changeLevel = 0
	elseif movData['dirtyLevel'] == 2 and movData['condition'] < 60 then
		changeLevel = 1
	elseif movData['dirtyLevel'] == 3 and movData['condition'] < 90 then
		changeLevel = 2
	end
	local changeSprite, changeSpriteCon
	if changeLevel then
		self.CLevel = changeLevel*self.CRate
		movData['dirtyLevel'] = changeLevel
		self.lastDL = tostring(changeLevel)
		changeSprite, changeSpriteCon = "", ""
		if changeLevel == 1 then
			changeSprite, changeSpriteCon = self.dirtySprites[1], self.dirtySprites[4]
		elseif changeLevel == 2 then
			changeSprite, changeSpriteCon = self.dirtySprites[2], self.dirtySprites[5]
		end
		self.obj:setOverlaySprite(changeSprite, isServer())
		if isServer() then self.obj:transmitUpdatedSpriteToClients(); end
	end
	if self.connectedObj then
		local conObjData = self.connectedObj:getModData()
		if not conObjData.movableData then conObjData.movableData = {}; end
		conMovData = conObjData.movableData
		conMovData['condition'] = movData['condition']
		conMovData['dirtyLevel'] = movData['dirtyLevel']
		if changeSpriteCon then
			self.connectedObj:setOverlaySprite(changeSpriteCon, isServer())
			if isServer() then self.connectedObj:transmitUpdatedSpriteToClients(); end
		end
	end
	if isServer() then
		self.obj:transmitModData()
		if self.connectedObj then self.connectedObj:transmitModData(); end
	end
	if movData['condition'] == 0 and movData['dirtyLevel'] == 0 then
		if isServer() then
			self.netAction:forceComplete()
		else
			self:forceComplete()
		end
	end
end

function LSCleanObject:isValid()
	return true;
end

function LSCleanObject:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.obj)
	return self.character:shouldBeTurning()
end

function LSCleanObject:adjustXP()
	if self.xpGain == 0 then return; end
	LSUtil.giveXP(self.character, "Cleaning", self.xpGain)
end

function LSCleanObject:adjustMood()
	if self.character:hasTrait(CharacterTrait.SLOPPY) then
		LSUtil.changeCharacterMood(self.character, "Stress", 0.01, not isServer(), false, true)
	elseif self.character:hasTrait(CharacterTrait.COUCHPOTATO) then
		LSUtil.changeCharacterMood(self.character, "Boredom", 1, not isServer(), false, true)
	elseif self.character:hasTrait(CharacterTrait.TIDY) then
		LSUtil.changeCharacterMoodGroup(self.character, {
			["Boredom"] = {-1, false, false, true},
			["Stress"] = {-0.005, not isServer(), false, true},
		})
	end
end

function LSCleanObject:MoodHalo()
	if not isClient() then return; end
	self.delay = (self.delay and self.delay+1) or 1
	if self.delay < 3 then return; end
	self.delay = 0
	LSUtil.doSimpleArrowHalo(self.character, getText("IGUI_HaloNote_"..self.haloNote[1]), self.haloNote[2])
end

function LSCleanObject:update()
	self.moodTimer = self.moodTimer + getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck
	if self.moodTimer > 20 then
		self.moodTimer = 0
		if not isClient() then
			self:adjustXP()
			self:adjustMood()
		elseif self.haloNote then
			self:MoodHalo()
		end
		local rdmNum = LSUtil.rdm_inst:random(self.numSounds)
		self.gameSound = self.character:getEmitter():playSound("Clean_"..self.cleanSound..tostring(rdmNum))
	end
	if not isClient() then
		self.timer = self.timer + getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck
		if self.timer > self.cleanRate+(self.CRate*self.CLevel) then
			self.timer = 0
			self:clean()
		end
	end
	self.character:setMetabolicTarget(Metabolics.LightDomestic);
end

local function getHaloNote(character)
	local note
	if character:hasTrait(CharacterTrait.SLOPPY) then
		note = {"Stress", false}
	elseif character:hasTrait(CharacterTrait.COUCHPOTATO) then
		note = {"Boredom", false}
	elseif character:hasTrait(CharacterTrait.TIDY) then
		note = {"Stress", true}
	end
	return note
end

function LSCleanObject:start()
	if self.actionAnim then
		self:setActionAnim(self.actionAnim)
	else
		self:setActionAnim("Loot")
		self.character:SetVariable("LootPosition", "Mid")
	end
	local itemLModel = self.itemLHand and self.itemLHand:getWorldStaticItem()
	local itemRModel = self.itemRHand and self.itemRHand:getWorldStaticItem()
	self:setOverrideHandModels(itemRModel, itemLModel)

	self.cleanSound = (LSHygiene.DS.Bathtubs[self.objectSpriteName] and "Tub") or "Sponge"
	self.numSounds = ("Tub" and 3) or 6

	if not self.dirtySprites then self:forceStop(); end

	if isClient() then self.haloNote = getHaloNote(self.character); end
end

function LSCleanObject:stop()
	if self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound) then self.character:getEmitter():stopSound(self.gameSound); end
	ISBaseTimedAction.stop(self)
end

function LSCleanObject:perform()
	if self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound) then self.character:getEmitter():stopSound(self.gameSound); end
	local movData = self.obj:getModData().movableData
	if movData['condition'] <= 1 then
		getSoundManager():playUISound("UI_CleanObject_Perform")
		if LSSync.isSingleplayer() and movData['condition'] > 0 then
			movData['condition'] = 0
			movData['dirtyLevel'] = 0
			if self.connectedObj then
				local conMovData = self.connectedObj:getModData().movableData
				conMovData['condition'] = 0
				conMovData['dirtyLevel'] = 0
			end
		end
	end	
	ISBaseTimedAction.perform(self)
end

function LSCleanObject:complete()
	if isServer() then
		local movData = self.obj:getModData().movableData
		if movData['condition'] > 0 and movData['condition'] <= 1 then
			movData['condition'] = 0
			movData['dirtyLevel'] = 0
			self.obj:transmitModData()
			if self.connectedObj then
				local conMovData = self.connectedObj:getModData().movableData
				conMovData['condition'] = 0
				conMovData['dirtyLevel'] = 0
				self.connectedObj:transmitModData()
			end
		end
	end
	return true
end

function LSCleanObject:animEvent(event, parameter)
	if isServer() then
		if event == "updateMood" then
			--print("LSCleanObject:animEvent, update event - mood and xp")
			self:adjustXP()
			self:adjustMood()
		end
		if event == "update"..self.lastDL and self.lastDL == parameter then
			--print("LSCleanObject:animEvent, update event - clean level "..self.lastDL)
			self:clean()
		end
	end
end

function LSCleanObject:serverStart()
	--local period = self.cleanRate*100
	emulateAnimEvent(self.netAction, self.cleanRate*50, "update0", "0")
	emulateAnimEvent(self.netAction, self.cleanRate*100, "update1", "1")
	emulateAnimEvent(self.netAction, self.cleanRate*200, "update2", "2")
	emulateAnimEvent(self.netAction, self.cleanRate*300, "update3", "3")
	emulateAnimEvent(self.netAction, 2000, "updateMood", nil)
end

function LSCleanObject:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function LSCleanObject:calcXP()
	if self.cleaningLevel == 10 then return 0; end
	local level = math.max(1,self.cleaningLevel)
	local xpChange = (self.character:hasTrait(CharacterTrait.SLOPPY) and 5) or 10
	return xpChange*level
end

function LSCleanObject:calcConsumption()
	local consumption = 0.008-0.0004*self.cleaningLevel
	local mult = 1
	if self.character:hasTrait(CharacterTrait.CLEANFREAK) or self.character:hasTrait(CharacterTrait.SLOPPY) then mult = mult+1; end
	if self.character:hasTrait(CharacterTrait.TIDY) then mult = mult/2; end
	return consumption*mult
end

function LSCleanObject:calcCRate()
	local baseRate = (self.character:hasTrait(CharacterTrait.SLOPPY) and 10) or 5
	local skillBuff = math.max(1, self.cleaningLevel)/2
	return math.max(0,math.floor(baseRate-skillBuff))
end

-- theres currently (42.19) a bug with getFirstAvailableFluidContainer for items that spawn with liquid and were never used
-- behavior - if the item is the only fluid container item - getFirstAvailableFluidContainer will fail
-- behavior - if theres another fluid container item - getFirstAvailableFluidContainer will return that container even if it doesn't contain the requested fluid or any fluid

function LSCleanObject:new(character, obj, connectedObj, objectSpriteName, cleanRateBase, syncData, itemRHand, itemLHand)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.obj = obj
	o.syncData = syncData
	o.obj:getModData().movableData = o.syncData
	o.lastDL = tostring(o.syncData['dirtyLevel'])
	o.connectedObj = connectedObj
	o.cleanRateBase = cleanRateBase
	o.cleanRate = math.min(80, math.max(5, o.cleanRateBase))
	o.timer = 0
	o.moodTimer = 0
	o.actionAnim = "Bob_Cleaning_Low"
	local playerInv = o.character:getInventory()
    o.sponge = playerInv:getFirstTypeEvalRecurse("Base.Sponge", predicateNotBroken)
    o.detergent = playerInv:getFirstTypeEvalRecurse("Base.CleaningLiquid2", predicateNotEmpty) or playerInv:getFirstAvailableFluidContainer("CleaningLiquid")
	o.itemRHand = itemRHand or o.sponge
	o.itemLHand = itemLHand or o.detergent
	o.objectSpriteName = objectSpriteName
	o.cleaningLevel = o.character:getPerkLevel(Perks.Cleaning)
	o.CLevel = o.syncData['dirtyLevel'] or 0
	o.CRate = o:calcCRate()
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
	o.stopOnAim = true
	o.xpGain = o:calcXP()
	o.drainRate = o:calcConsumption()
	o.maxTime = o:getDuration()
	o.caloriesModifier = 0.5
	o.dirtySprites = LSHygiene.DS.getFromSpriteName(o.objectSpriteName)
	o.gameSound = 0
	return o;
end

return LSCleanObject