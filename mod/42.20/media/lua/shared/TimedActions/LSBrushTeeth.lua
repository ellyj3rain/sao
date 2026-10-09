-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

LSBrushTeeth = ISBaseTimedAction:derive("LSBrushTeeth");
--[[
local function doIdxVariation(idx, limit)
	local variation = ZombRand(2) + 1
	local newIdx

	if idx == limit then--last
		newIdx = idx-variation
		if newIdx <= 0 then newIdx = 1; end
	elseif idx == 1 then--first
		newIdx = idx+variation
		if newIdx > limit then newIdx = limit; end
	else
		if variation == 1 then newIdx = idx-1; elseif variation == 2 then newIdx = idx+1; end
	end

	return newIdx
end

local function getSoundIdxEnd()
	return {"Brush_Teeth1","Brush_Teeth2","Brush_Teeth3","Brush_Teeth4"}
end

local function getNewSoundByName(oldSound)
	local newSound = getSoundIdxEnd()
	local idxS = ZombRand(#newSound) + 1
	if oldSound and (newSound[idxS] == oldSound) then
		local newIdx = doIdxVariation(idxS, #newSound)
		idxS = newIdx
	end

	return newSound[idxS]
end
]]--

function LSBrushTeeth:isValid()
	--local flushed = true
	
	--if self.showerObject:getModData().NeedsFlush then
		--flushed = false
	--end
	
	return true
end

function LSBrushTeeth:waitToStart()
	--self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.cabinetObject)

	return self.character:shouldBeTurning()
end

function LSBrushTeeth:update()

	if self.doAnim == 2 then

		self.character:getEmitter():playSound("Shower_Start")
		self.doAnim = 3
		

	elseif self.doAnim >= 4 and self.doAnim < 6 then--20 30
		if self.gameSoundLoop == 0 then
			self.gameSoundLoop = self.character:getEmitter():playSound("Shower_Common_Loop");
			--self:setActionAnim("WashFace")
		end

	elseif self.doAnim >= 6 then
		if not self.doActionAnim then
			self:setActionAnim("Bob_BrushTeeth")
			self.doActionAnim = true
		end
		
		if self.doAnim == 6 then
			--local actionSound = getNewSoundByName(self.lastSound)
			local sound = LSHygiene.Sounds.getRandom("BrushTeeth",self.lastSound)
			self.gameSoundLoop2 = self.character:getEmitter():playSound(sound);
			self.lastSound = sound
		end	
		
	end
	self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	
	if self.doAnim >= 28 then--140
		self.doAnim = 6
	end
	
end

function LSBrushTeeth:start()

	--if self.showerObject:getModData().NeedsFlush then
		--self:forceStop()
	--end
	--self:setActionAnim("Loot")
	--self.character:SetVariable("LootPosition", "Mid")

	--local sm = getSearchMode():getSearchModeForPlayer(self.character:getPlayerNum())
	--sm:getBlur():setTargets(1, 1);
	--sm:getDesat():setTargets(0.5, 0.5);
	--sm:getRadius():setTargets(0.5, 0.5);
	--sm:getRadius():set(2, 20, 2, 20);
	--sm:getDarkness():setTargets(0.5, 0.5);
	--sm:getGradientWidth():setTargets(1, 1);

	--getSearchMode():setEnabled(self.character:getPlayerNum(), true)
	
	self.toothbrushItem = self.itemsList.Toothbrush
	self.toothpasteItem = self.itemsList.Toothpaste
	
	self:setOverrideHandModels(self.toothbrushItem:getWorldStaticItem(), self.toothpasteItem:getWorldStaticItem())
	
	--if self.showerType == "Deluxe" then
	--	self.character:getEmitter():playSound("Faucet_Deluxe")
	--	self.showerCleanVal = 0.04
	--else
		self.character:getEmitter():playSound("Faucet_Common")
	--end
	self:setActionAnim("Loot")

	self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed or 0

end

function LSBrushTeeth:stop()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
	if self.gameSoundLoop2 then
		self.character:getEmitter():stopSound(self.gameSoundLoop2)
	end
	--if self.showerType == "Deluxe" then
	--	self.character:getEmitter():playSound("Faucet_Deluxe")
	--else
		self.character:getEmitter():playSound("Faucet_Common")
	--end
	self.character:getEmitter():playSound("Shower_End")

    ISBaseTimedAction.stop(self);
		
end

function LSBrushTeeth:perform()

	local cooldownAdd, note, moodle, moodleVal = 0, "MintFresh", "MintFresh", 0.2
	if self.pasteEffect then cooldownAdd, note, moodle, moodleVal = 8, "MintHyper", self.pasteEffect, 0.8; end
	-------------------------
	--------------HALO
	HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Hygiene"), true, 170, 255, 150)
	HaloTextHelper.addGoodText(self.character, getText("IGUI_HaloNote_"..note))

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
	if self.gameSoundLoop2 then
		self.character:getEmitter():stopSound(self.gameSoundLoop2)
	end
	--if self.showerType == "Deluxe" then
	--	self.character:getEmitter():playSound("Faucet_Deluxe")
	--else
		self.character:getEmitter():playSound("Faucet_Common")
	--end
	self.character:getEmitter():playSound("Shower_End")

	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit or 100
	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit - 10
	
	self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed - 10
	if self.character:getModData().hygieneNeed < 0 then
		self.character:getModData().hygieneNeed = 0
	end

	self.character:getModData().lastBrushTeeth = self.character:getHoursSurvived()+cooldownAdd

	if self.character:getModData().LSMoodles[moodle] and self.character:getModData().LSMoodles[moodle].Value then
		self.character:getModData().LSMoodles[moodle].Value = moodleVal
	end

	if self.pasteEffect and self.pasteEffect == "MintCurio" then
		self.character:getModData().mintCurioEffect = false
		local hungryMoodle = MoodleType["HUNGRY"]
		if hungryMoodle and not self.character:getMoodles():getMoodleLevel(hungryMoodle) ~= 0 then
			LSUtil.changeCharacterMood(self.character, "Hunger", 0, false, true, true)
		end
		LSUtil.useItem(self.itemsList.Toothpaste, self.character)
	end

	--------------ITEMTRANSFER
	if self.itemsList and (self.itemsList.Toothbrush or self.itemsList.Toothpaste) then
		if self.itemsList.Toothbrush and self.itemsList.ToothbrushCont and self.itemsList.ToothbrushCont:isItemAllowed(self.itemsList.Toothbrush) then
			if self.itemsList.ToothbrushCont:getType() == "floor" then
				TransferHelper.dropItem(self.itemsList.Toothbrush, self.character)
			else
				TransferHelper.onMoveItemsTo(self.itemsList.Toothbrush, self.itemsList.ToothbrushCont, self.character, true, self.character:getInventory())
			end
		end
		if self.itemsList.Toothpaste and self.itemsList.ToothpasteCont and self.itemsList.ToothpasteCont:isItemAllowed(self.itemsList.Toothpaste) then
			if self.itemsList.ToothpasteCont:getType() == "floor" then
				TransferHelper.dropItem(self.itemsList.Toothpaste, self.character)
			else
				TransferHelper.onMoveItemsTo(self.itemsList.Toothpaste, self.itemsList.ToothpasteCont, self.character, true, self.character:getInventory())
			end
		end
	end

	sendClientCommand(self.character, "LS", "RemoveMakeup", {"mouth", false})

	ISBaseTimedAction.perform(self);

end

function LSBrushTeeth:complete()
	--if SandboxVars.LSHygiene.CleansMakeup then self:removeAllMakeup(); end
	return true
end
--[[
function LSBrushTeeth:removeAllMakeup()
	local item = self.character:getWornItem("MakeUp_Lips");
	self:removeMakeup(item);
end

function LSBrushTeeth:removeMakeup(item)
	if item then
        sendRemoveItemFromContainer(self.character:getInventory(), item);	
		self.character:removeWornItem(item);
		self.character:getInventory():Remove(item);
	end
end
]]--
function LSBrushTeeth:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function LSBrushTeeth:new(character, cabinetObject, sinkObject, itemsList, pasteEffect, actionTime)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.cabinetObject = cabinetObject
	o.sinkObject = sinkObject
	o.itemsList = itemsList
	o.pasteEffect = pasteEffect
	o.actionTime = actionTime
	o.toothbrushItem = false
	o.toothpasteItem = false
	o.srcContainer = false
	o.gameSoundLoop = 0
	o.gameSoundLoop2 = false
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.doAnim = 2
	o.doActionAnim = false
	o.lastSound = false
	return o;
end

return LSBrushTeeth