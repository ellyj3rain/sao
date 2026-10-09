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

LSCheckYourselfAP = ISBaseTimedAction:derive("LSCheckYourselfAP");

local function getItemContainer(player, itemA)

	local Cont = false

	if instanceof(itemA, "InventoryItem") then
		if luautils.haveToBeTransfered(player, itemA) then
			Cont = itemA:getContainer()
		end
	elseif instanceof(itemA, "ArrayList") then
		local items = itemA
		for i=1,items:size() do
			local item = items:get(i-1)
			if luautils.haveToBeTransfered(player, item) then
				Cont = item:getContainer()
			end
		end
	end

	return Cont
end

local function doPlayerStats(character)

	--------------ADJUST MOOD
	LSUtil.changeCharacterMood(character, "Boredom", -3, false, false)

end

local function LSCYGetAnimSound()

	return {
			{name="Bob_PullAtCollar",animTime=45,soundType="IntriguedHmm",soundTime=0},
			{name="Bob_PullAtCollar2H",animTime=45,soundType="IntriguedHmm",soundTime=0},
			{name="Shave",animTime=60,soundType="IntriguedHmm",soundTime=0},
			{name="Bob_WipeHead",animTime=45,soundType="IntriguedHmm",soundTime=0},
		}

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
		local newIdx = doIdxVariation(idxA, 4)
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

local function APgetMakeups(itemsList, tattoo)

	local makeupList = {}
	makeupList.eyes = {}
	makeupList.eyesshadow = {}
	makeupList.fullface = {}
	makeupList.lips = {}
	if tattoo then
		makeupList.tatFace = {}
		makeupList.tatUB = {}
		makeupList.tatLB = {}
		makeupList.tatLA = {}
		makeupList.tatRA = {}
		makeupList.tatLL = {}
		makeupList.tatRL = {}
		makeupList.tatBack = {}
	end

	for i,v in ipairs(MakeUpDefinitions.makeup) do
		if v.category == "Eyes" and itemsList.MakeupEye and v.makeuptypes[itemsList.MakeupEye:getMakeUpType()] then
			table.insert(makeupList.eyes, v)
		end
		if v.category == "EyesShadow" and itemsList.MakeupEye and v.makeuptypes[itemsList.MakeupEye:getMakeUpType()] then
			table.insert(makeupList.eyesshadow, v)
		end
		if ((v.category == "FullFace") or (v.category == "Eyes")) and itemsList.Makeup and v.makeuptypes[itemsList.Makeup:getMakeUpType()] and not v.makeuptypes["Eyes"] then
			table.insert(makeupList.fullface, v)
		end
		if v.category == "Lips" and itemsList.MakeupLipstick and v.makeuptypes[itemsList.MakeupLipstick:getMakeUpType()] then
			table.insert(makeupList.lips, v)
		end
		if tattoo and itemsList.MakeupTattooNeedle then
			if v.category == "Face_Tattoo" and makeupList.tatFace then
				table.insert(makeupList.tatFace, v)
			end
			if v.category == "UpperBody_Tattoo" and makeupList.tatUB then
				table.insert(makeupList.tatUB, v)
			end
			if v.category == "LowerBody_Tattoo" and makeupList.tatLB then
				table.insert(makeupList.tatLB, v)
			end
			if v.category == "LeftArm_Tattoo" and makeupList.tatLA then
				table.insert(makeupList.tatLA, v)
			end
			if v.category == "RightArm_Tattoo" and makeupList.tatRA then
				table.insert(makeupList.tatRA, v)
			end
			if v.category == "LeftLeg_Tattoo" and makeupList.tatLL then
				table.insert(makeupList.tatLL, v)
			end
			if v.category == "RightLeg_Tattoo" and makeupList.tatRL then
				table.insert(makeupList.tatRL, v)
			end		
			if v.category == "Back_Tattoo" and makeupList.tatBack then
				table.insert(makeupList.tatBack, v)
			end	
		end
	end

	return makeupList
end

local function APgetHairstylesBeard(player, itemsList)

	local beardList = {}

	if not player:isFemale() then
		local currentBeardStyle = getBeardStylesInstance():FindStyle(player:getHumanVisual():getBeardModel())
		if currentBeardStyle and (currentBeardStyle:getLevel() > 0) and itemsList and itemsList.Razor then
			local allBeard = getBeardStylesInstance():getAllStyles();
				table.insert(beardList, "")
			for i=0, allBeard:size()-1 do
				local beardStyle = allBeard:get(i);
				if beardStyle:getLevel() < currentBeardStyle:getLevel() and beardStyle:getName() ~= "" then
					table.insert(beardList, beardStyle)
				end
			end
			for i=0, currentBeardStyle:getTrimChoices():size()-1 do
				table.insert(beardList, getBeardStylesInstance():FindStyle(currentBeardStyle:getTrimChoices():get(i)))
			end
	
		end
	end

	return beardList
end

local function compareHairStyle(a, b)
	if a:getName() == "Bald" then return true end
	if b:getName() == "Bald" then return false end
	local nameA = getText("IGUI_Hair_" .. a:getName())
	local nameB = getText("IGUI_Hair_" .. b:getName())
	return not string.sort(nameA, nameB)
end

local function predicateNotBroken(item)
	return not item:isBroken()
end

local function APgetHairstyles(player, itemsList)
	
	local currentHairStyle = getHairStylesInstance():FindMaleStyle(player:getHumanVisual():getHairModel())
	local hairStyles = getHairStylesInstance():getAllMaleStyles();
	if player:isFemale() then
		currentHairStyle = getHairStylesInstance():FindFemaleStyle(player:getHumanVisual():getHairModel())
		hairStyles = getHairStylesInstance():getAllFemaleStyles();
	end

	local hairList = {}
	local untieHair
	if (not currentHairStyle) or (currentHairStyle:getLevel() <= 0) then return hairList; end
	player:getVisual():setNonAttachedHair(nil);
	if currentHairStyle:isAttachedHair() then
		-- get the growReference of our current level, it'll become our nonAttachedHair, so if we decide to detach our hair (from a pony tail for ex.) we'll go back to this growReference
		for i=1,hairStyles:size() do
			local hairStyle = hairStyles:get(i-1)
			if hairStyle:getLevel() == currentHairStyle:getLevel() and hairStyle:isGrowReference() then
				player:getVisual():setNonAttachedHair(hairStyle:getName());
				untieHair = hairStyle
				break
			end
		end
	end

	if not player:getVisual():getNonAttachedHair() then
		for i=1,hairStyles:size() do
			local hairStyle = hairStyles:get(i-1)
			if currentHairStyle and (currentHairStyle:getLevel() > 0) then
				-- add tie hair options
				if hairStyle:getLevel() <= currentHairStyle:getLevel() and hairStyle:getName() ~= currentHairStyle:getName() and hairStyle:isAttachedHair() and hairStyle:getName() ~= "" then
					table.insert(hairList, hairStyles:get(i-1))
				elseif not hairStyle:isAttachedHair() and not hairStyle:isNoChoose() and hairStyle:getLevel() < currentHairStyle:getLevel() and hairStyle:getName() ~= "" then
					if ((hairStyle:getName():contains("Mohawk")) and (hairStyle:getName() ~= "MohawkFlat")) or (hairStyle:getName():contains("GreasedBack")) then
						if itemsList and itemsList.Hairgel then
							table.insert(hairList, hairStyles:get(i-1))
						end				
					else
						if itemsList and itemsList.Scissors then
							table.insert(hairList, hairStyles:get(i-1))
						end
					end
				end
			end
		end

		for i=1,currentHairStyle:getTrimChoices():size() do
			local styleId = currentHairStyle:getTrimChoices():get(i-1)
			local hairStyle = (player:isFemale() and getHairStylesInstance():FindFemaleStyle(styleId)) or getHairStylesInstance():FindMaleStyle(styleId)
			
			if hairStyle and (((hairStyle:getName():contains("Mohawk")) and (hairStyle:getName() ~= "MohawkFlat")) or (hairStyle:getName():contains("GreasedBack"))) then
				if itemsList and itemsList.Hairgel then
					table.insert(hairList, hairStyle)
				end	
			elseif hairStyle then
				if hairStyle and itemsList and itemsList.Scissors then
					table.insert(hairList, hairStyle)
				end
			end
		end

		table.sort(hairList, compareHairStyle)
	elseif untieHair then
		table.insert(hairList, untieHair)
	end

	return hairList

end

function LSCheckYourselfAP:isValid()

	return true
end

function LSCheckYourselfAP:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.mirrorObject)

	return self.character:shouldBeTurning()
end

function LSCheckYourselfAP:update()

	if not self.character:getModData().LSMirrorMenuOverlayPanel then self:forceComplete(); end
	if self.character:getModData().LSMirrorMenuOverlayPanel and (self.character:getModData().LSMirrorMenuOverlayPanel == "changeSkin") then
		--if self.skinDelay >= 20 then
			--self.skinDelay = 0
			self.character:getModData().LSMirrorMenuOverlayPanel = true
			local thisplayer = getPlayer():getPlayerNum()
			self.LSMirrorMenuOverlay = LSMirrorMenu:new(getCore():getScreenWidth()/2-550,getCore():getScreenHeight()/2-350,450,600,thisplayer,self.itemsList,self.itemsDyeList,self.hairStyles,self.hairStylesBeard, self.makeupTypes);
			self.LSMirrorMenuOverlay:initialise();
			self.LSMirrorMenuOverlay:addToUIManager();
		--else
			--self.skinDelay = self.skinDelay+1
		--end
	end

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
		doPlayerStats(self.character)
	end

	if self.soundTimeInterval and (self.soundTime ~= 0) and (self.doAnim >= self.soundTimeInterval) then
		self.soundTimeInterval = self.soundTime+self.doAnim
		if self.gameSoundLoop ~= 0 then
			self.character:getEmitter():stopSound(self.gameSoundLoop)
		end
		local newSound
		newSound = getNewSoundByName(self.soundType, self.soundName, self.character:isFemale(), false)
		self.soundName = newSound
		if self.canTalk then self.gameSoundLoop = self.character:getEmitter():playSound(self.soundName); end
	
	end

	self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	--self:resetJobDelta()
end

function LSCheckYourselfAP:start()

	self:setOverrideHandModels(nil, nil)

	self.animList = LSCYGetAnimSound()
	self.hairStyles = APgetHairstyles(self.character, self.itemsList)
	self.hairStylesBeard = APgetHairstylesBeard(self.character, self.itemsList)
	self.makeupTypes = APgetMakeups(self.itemsList)
	if LS_AMcache and LS_AMcache['tattoo'] then
		self.makeupTypes = APgetMakeups(self.itemsList, true)
	else
		self.makeupTypes = APgetMakeups(self.itemsList, false)
	end

	self.oldHairstyle = getHairStylesInstance():FindFemaleStyle(self.character:getHumanVisual():getHairModel())
	if not self.character:isFemale() then
		self.oldHairstyle = getHairStylesInstance():FindMaleStyle(self.character:getHumanVisual():getHairModel())
		self.oldBeardstyle = getBeardStylesInstance():FindStyle(self.character:getHumanVisual():getBeardModel())
	end

	if self.character:hasTrait(CharacterTrait.DEAF) then self.canTalk = false; end

	self.character:getModData().LSMirrorMenuOverlayPanel = true
	local thisplayer = getPlayer():getPlayerNum()
    self.LSMirrorMenuOverlay = LSMirrorMenu:new(getCore():getScreenWidth()/2-550,getCore():getScreenHeight()/2-350,450,600,thisplayer,self.itemsList,self.itemsDyeList,self.hairStyles,self.hairStylesBeard, self.makeupTypes);
    self.LSMirrorMenuOverlay:initialise();
    self.LSMirrorMenuOverlay:addToUIManager();

end

function LSCheckYourselfAP:stop()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end

	-------------------------
	--------------HAIRSTUFF
	local newHairStyle = getHairStylesInstance():FindFemaleStyle(self.character:getHumanVisual():getHairModel())
	if not self.character:isFemale() then
		newHairStyle = getHairStylesInstance():FindMaleStyle(self.character:getHumanVisual():getHairModel())
		self.character:resetBeardGrowingTime();
		local currentBeardStyle = getBeardStylesInstance():FindStyle(self.character:getHumanVisual():getBeardModel())
		if currentBeardStyle == "" then
			self.character:getHumanVisual():setBeardColor(self.character:getHumanVisual():getNaturalBeardColor())
		end
	end
	-- if we're attaching our hair we need to set the non attached model, or if we untie, we reset our model
	if newHairStyle:isAttachedHair() and not self.character:getHumanVisual():getNonAttachedHair() then
		self.character:getHumanVisual():setNonAttachedHair(self.character:getHumanVisual():getHairModel());
	end
	if self.character:getHumanVisual():getNonAttachedHair() and not newHairStyle:isAttachedHair() then
		self.character:getHumanVisual():setNonAttachedHair(nil);
	end

	self.character:getModData().LSMirrorMenuOverlayPanel = false
	self.LSMirrorMenuOverlay:close()
    ISBaseTimedAction.stop(self);
		
end

function LSCheckYourselfAP:perform()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end

	if self.character:getModData().LSMirrorMenuOverlayPanel then
		self.LSMirrorMenuOverlay:close()
		self.character:getModData().LSMirrorMenuOverlayPanel = false
	end

	-------------------------
	--------------SOUND
	if self.canTalk then
		local sound = getNewSoundByName("UhuhGood", false, self.character:isFemale(), true)
		self.character:getEmitter():playSound(sound)
	end
	-------------------------
	--------------HAIRSTUFF
	local newHairStyle = getHairStylesInstance():FindFemaleStyle(self.character:getHumanVisual():getHairModel())
	local currentBeardStyle
	if not self.character:isFemale() then
		newHairStyle = getHairStylesInstance():FindMaleStyle(self.character:getHumanVisual():getHairModel())
		currentBeardStyle = getBeardStylesInstance():FindStyle(self.character:getHumanVisual():getBeardModel())
		if currentBeardStyle == "" then
			self.character:getHumanVisual():setBeardColor(self.character:getHumanVisual():getNaturalBeardColor())
			currentBeardStyle = false
		end
	end

	if (not newHairStyle) or ((newHairStyle:getLevel() <= 0) and newHairStyle:getName():contains("Bald")) then
		self.character:getHumanVisual():setHairColor(self.character:getHumanVisual():getNaturalHairColor())
	end



	-- if we're attaching our hair we need to set the non attached model, or if we untie, we reset our model
	if newHairStyle:isAttachedHair() and not self.character:getHumanVisual():getNonAttachedHair() then
		self.character:getHumanVisual():setNonAttachedHair(self.character:getHumanVisual():getHairModel());
	end
	if self.character:getHumanVisual():getNonAttachedHair() and not newHairStyle:isAttachedHair() then
		self.character:getHumanVisual():setNonAttachedHair(nil);
	end
	self.character:resetModel();

	-------------------------
	--------------RESETGROWINGTIME
	if self.oldHairstyle and not newHairStyle then
		self.character:resetHairGrowingTime();
	elseif self.oldHairstyle and (self.oldHairstyle:getName() ~= newHairStyle:getName()) then
		self.character:resetHairGrowingTime();
	end
	if self.oldBeardstyle and (self.oldBeardstyle ~= "") and not currentBeardStyle then
		self.character:resetBeardGrowingTime();
	elseif self.oldBeardstyle and (self.oldBeardstyle ~= "") and (self.oldBeardstyle:getName() ~= currentBeardStyle:getName()) then
		self.character:resetBeardGrowingTime();
	end
	-- reduce hairgel for mohawk
	--if newHairStyle:getName():contains("Mohawk") and newHairStyle:getName() ~= "MohawkFlat" then
	--	local hairgel = self.character:getInventory():getItemFromType("Hairgel", true, true);
	--	if hairgel then
	--		hairgel:Use();
	--	end
	--end
	triggerEvent("OnClothingUpdated", self.character)
	
	-------------------------
	--------------ITEMTRANSFER
	if self.itemsList and (self.itemsList.Scissors or self.itemsList.Razor) then
		if self.itemsList.Scissors and self.itemsList.ScissorsCont and self.itemsList.ScissorsCont:isItemAllowed(self.itemsList.Scissors) then
			if self.itemsList.ScissorsCont:getType() == "floor" then
				TransferHelper.dropItem(self.itemsList.Scissors, self.character)
			else
				TransferHelper.onMoveItemsTo(self.itemsList.Scissors, self.itemsList.ScissorsCont, self.character, true)
			end
		end
		if self.itemsList.Razor and self.itemsList.RazorCont and self.itemsList.RazorCont:isItemAllowed(self.itemsList.Razor) then
			if self.itemsList.RazorCont:getType() == "floor" then
				TransferHelper.dropItem(self.itemsList.Razor, self.character)
			else
				TransferHelper.onMoveItemsTo(self.itemsList.Razor, self.itemsList.RazorCont, self.character, true)
			end
		end
	end
	ISBaseTimedAction.perform(self);
end

function LSCheckYourselfAP:complete()
	return true
end

function LSCheckYourselfAP:getDuration()
	return -1
end

function LSCheckYourselfAP:new(character, mirrorObject, itemsList, itemsDyeList)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.mirrorObject = mirrorObject
	o.itemsList = itemsList
	o.itemsDyeList = itemsDyeList
	o.hairStyles = {}
	o.hairStylesBeard = {}
	o.makeupTypes = false
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
	o.LSMirrorMenuOverlay = false
	o.skinDelay = 0
	o.oldHairstyle = false
	o.oldBeardstyle = false
	o.canTalk = true
	return o;
end

return LSCheckYourselfAP