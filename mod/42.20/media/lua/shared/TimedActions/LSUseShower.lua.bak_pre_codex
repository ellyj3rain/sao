
require "TimedActions/ISBaseTimedAction"
require "Hygiene/ShowerFunctions"

LSUseShower = ISBaseTimedAction:derive("LSUseShower");

--local isPlayingJukeSong = nil;

local function doPlayerStats(character, cleanVal, useSoap)
	-------------------------
	--------------DIRT/BLOOD
	local visual, bloodCleanVal, hasDirtOrBlood = character:getHumanVisual(), cleanVal-0.01, false

	for i = 1, BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i - 1)
		local dirt, blood = visual:getDirt(part), visual:getBlood(part)
		if dirt > 0 and (dirt-cleanVal >= 0) then visual:setDirt(part, dirt-cleanVal); elseif dirt ~= 0 then visual:setDirt(part, 0); end
		if blood > 0 and (blood-bloodCleanVal >= 0) then visual:setBlood(part, blood-bloodCleanVal); elseif blood ~= 0 then visual:setBlood(part, 0); end		
		if (dirt > 0) or (blood > 0) then hasDirtOrBlood = true; end
	end	
	-------------------------
	--------------ADJUST HYGIENE NEED
	local charData = character:getModData()
	if charData.hygieneNeed > 0 then
		local rate = (useSoap and 2.5) or (charData.hygieneNeed > 60 and 1.5) or 1
		charData.hygieneNeed = LSUtil.truncateToTwoDecimals(math.max(0,charData.hygieneNeed-rate))
	end
	-------------------------
	--------------WETNESS
	if LSUtil.getCharacterMood(character, "Wetness") < 70 then LSUtil.changeCharacterMood(character, "Wetness", 70, false, true); end
	
	return hasDirtOrBlood
end

local function doPlayerSinging(character, oldSound, AvailablePlayerVoiceTracks)

	local chanceToSing, musicSkill, originalSound, newSound = 0, 0, oldSound, false
	if character:getPerkLevel(Perks.Music) > 0 then
		musicSkill = math.floor(tonumber(character:getPerkLevel(Perks.Music))/2)
	end
	if character:hasTrait(CharacterTrait.TONEDEAF) then
		chanceToSing = ZombRand(18)+1
	else
		chanceToSing = ZombRand(20)+1
	end
				
	if (chanceToSing + musicSkill) >= 18 then
		local randomLine = ZombRand(#AvailablePlayerVoiceTracks)+1
		local sound = AvailablePlayerVoiceTracks[randomLine].sound
	
		if character:getDescriptor():isFemale() then
			sound = AvailablePlayerVoiceTracks[randomLine].soundF
		end

		if (not originalSound) or (originalSound ~= sound) then
			originalSound = sound
			newSound = sound
		end
	end

	return originalSound, newSound
end

function LSUseShower:isValid()
	--local flushed = true
	
	--if self.showerObject:getModData().NeedsFlush then
		--flushed = false
	--end
	
	return true
end

function LSUseShower:waitToStart()
	self.action:setUseProgressBar(false)
	local cX = self.showerObject:getSquare():getX()
	local cY = self.showerObject:getSquare():getY()
	--self.character:setX(cY)
	--self.character:setY(cX)
	if isClient() then
		--self.character:setLy(cY)
		--self.character:setLx(cX)
		--self.character:setY(cY)
		--self.character:setX(cX)
	end

	--local wait = false

	--if self.showerType == "Hanging" then
	--	self.character:faceThisObject(self.showerObject)
	--	wait = self.character:shouldBeTurning()
	--end
	

	return false
end

local function getNewFog(oldFog, tileSqr)
	local newSprite = "LS_Fog_" .. tostring(ZombRand(8))
	if oldFog then tileSqr:RemoveTileObject(oldFog); end
	local fog = IsoObject.new(getCell(), tileSqr, newSprite)
	fog:setAlpha(0.1)
	tileSqr:AddSpecialObject(fog)
	return fog
end

function LSUseShower:update()

	if self.doAnim == 2 then

		self.character:getEmitter():playSound("Shower_Start")
		self.doAnim = 3
		self:setActionAnim("WashFace")

	elseif self.doAnim >= 5 then--20
		
		if self.gameSoundLoop == 0 then
			--if SandboxVars.LSHygiene.CleansMakeup and not self.removedMakeup then sendClientCommand(self.character, "LS", "RemoveMakeup", {false, true}); self.removedMakeup = true; end
			self.gameSoundLoop = self.character:getEmitter():playSound(self.soundWaterLoop);
		end

		if self.doAnim < 8 then
			self.doAnim = 8--30
			
			if self.isFacing then
				self.spriteNum = self.spriteNum + 1
				if self.spriteNum >= 8 then
					self.spriteNum = 0
				end
				if not self.waterObj then self.waterObj = getNewFog(self.waterObj, self.tileSqr);
				elseif self.spriteNum%2 == 0 then self.waterObj:setOverlaySprite("LS_Fog_" .. tostring(ZombRand(8)),1,1,1,0.6,false); end
			end
		elseif self.doAnim < 12 then--50
			self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		elseif self.doAnim >= 12 then
			self.doAnim = 7--29
		end

		if self.decreaseNeed >= self.decreaseNeedTotal then
			self.decreaseNeed = 0

			if self.depressed == 1 then

				self.depressed = 2
			elseif self.depressed == 2 then
				self.depressed = 3
				self:setActionAnim("Bob_ShowerSadStart")
			elseif self.depressed == 3 then
				if self.facing then
					--print("SHOWER IS FACING: " .. self.facing)
					if self.facing == "N" then
						self.character:faceLocation(self.character:getX(), self.character:getY()-1)
						self.character:faceLocationF(self.character:getX(), self.character:getY()-1)
					elseif self.facing == "S" then
						self.character:faceLocation(self.character:getX(), self.character:getY()+1)
						self.character:faceLocationF(self.character:getX(), self.character:getY()+1)
					elseif self.facing == "E" then
						self.character:faceLocation(self.character:getX()+1, self.character:getY())
						self.character:faceLocationF(self.character:getX()+1, self.character:getY())
					elseif self.facing == "W" then
						self.character:faceLocation(self.character:getX()-1, self.character:getY())
						self.character:faceLocationF(self.character:getX()-1, self.character:getY())
					end

				end
				self:setActionAnim("Bob_ShowerSad")
				self.depressed = 4
			elseif self.depressed >= 4 then
				self.depressed = self.depressed + 1
			end
		
			addSound(self.character,
				 self.character:getX(),
				 self.character:getY(),
				 self.character:getZ(),
				 6,
				 5)

			-------------------------
			--------------DO STATS
			local hasDirtOrBlood = doPlayerStats(self.character, self.showerCleanVal, self.useSoap)

			-------------------------
			--------------PERFORM CONDITIONS (no water / hygiene fulfilled and no dirt/blood)
			if (self.character:getModData().hygieneNeed < 40) and not hasDirtOrBlood and ((self.depressed == 0) or (self.depressedEnd >= 1))  then
				self.character:getEmitter():stopSound(self.gameSoundLoop)
				self.gameSoundLoop = 0
				if self.showerType == "Deluxe" then
					self.character:getEmitter():playSound("Faucet_Deluxe")
				else
					self.character:getEmitter():playSound("Faucet_Common")
				end
				self.character:getEmitter():playSound("Shower_End")
				self:forceComplete()
			elseif (self.character:getModData().hygieneNeed < 40) and not hasDirtOrBlood and self.depressed > 30 and self.depressedEnd == 0 then
				self:setActionAnim("Bob_ShowerSadEnd")
				self.depressedEnd = 1
			end

			-------------------------
			--------------EMBARRASSED
			if not SandboxVars.LSHygiene.NotEmbarrassed then 
				self.wasDisturbedBy = LSUtil.canSeeOtherPlayers(self.character, 8)
				if self.wasDisturbedBy then
					local characterData = self.character:getModData()
					if characterData.LSMoodles["Embarrassed"] and characterData.LSMoodles["Embarrassed"].Value then
						characterData.LSMoodles["Embarrassed"].Value = math.min(1, characterData.LSMoodles["Embarrassed"].Value+0.45)
					end
					HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Embarrassed"), true, 255, 120, 120)		
					self:forceComplete()
				end
			end	
			-------------------------
			--------------HALO
			HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Hygiene"), true, 170, 255, 150)
			--------------SINGING
			local isPlaying = self.gameSoundVoice and self.character:getEmitter():isPlaying(self.gameSoundVoice)
			
			if self.AvailablePlayerVoiceTracks and
			#self.AvailablePlayerVoiceTracks > 0 and not
			isPlaying then
				local oldSound, newSound = self.lastSound, false
				self.lastSound, newSound = doPlayerSinging(self.character, oldSound, self.AvailablePlayerVoiceTracks)
				if newSound then self.gameSoundVoice = self.character:getEmitter():playSound(newSound); end
			end
			
			--------------HEAT
			if self.showerHeat then
				if not ((SandboxVars.ElecShutModifier > -1 and
				GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
				self.showerObject:getSquare():haveElectricity()) then
					--print("no electricity for shower")
					--self.showerObject:getCell():removeHeatSource(self.showerHeat)
					self.showerHeat:destroy()
					self.showerHeat = nil
				end
			
			end
		else
			self.decreaseNeed = self.decreaseNeed + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		end

	else
		self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		--getAverageFSP()
		--getPerformance():getLockFPS()
		--(getGameTime():getMultiplier() * 60 / getAverageFSP())
	end

end

function LSUseShower:start()

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
	
	self:setOverrideHandModels(nil, nil)

	local characterData = self.character:getModData()
	local PlayerVoice = characterData.PlayerVoice

	local PlayerVoiceTracks = require("TimedActions/PlayerVoiceTracks")
	local PlayerVoiceHygieneTracks = require("Hygiene/Tracks/PlayerVoiceHygiene")
	self.AvailablePlayerVoiceTracks = {}

-----------DEPRESSED
	if LSUtil.getCharacterMood(self.character, "Unhappiness") > 30 then self.depressed = 1; end
-------------
	
	-- we loop the voice tracks and select the ones that we want, making sure to only select the ones that match the player voice
	if self.depressed == 0 then
		if (self.character:hasTrait(CharacterTrait.VIRTUOSO) or (self.character:getPerkLevel(Perks.Music) > 4)) and not self.character:hasTrait(CharacterTrait.TONEDEAF) then
			for k,v in pairs(PlayerVoiceTracks) do
				if v.Voice == PlayerVoice and
				v.Type == "SingGood" then--MAKE SURE TO CHANGE THIS LINE
					table.insert(self.AvailablePlayerVoiceTracks, v)
				end
			end
		end
		if self.character:hasTrait(CharacterTrait.TONEDEAF) then
			for k,v in pairs(PlayerVoiceHygieneTracks) do
				if v.Type == "bad" then--MAKE SURE TO CHANGE THIS LINE
					table.insert(self.AvailablePlayerVoiceTracks, v)
				end
			end
		else
			for k,v in pairs(PlayerVoiceHygieneTracks) do
				if v.Type == "hum" then--MAKE SURE TO CHANGE THIS LINE
					table.insert(self.AvailablePlayerVoiceTracks, v)
				end
			end
		end
	else
		for k,v in pairs(PlayerVoiceTracks) do
			if v.Voice == PlayerVoice and
			v.Type == "Depressed" then
				table.insert(self.AvailablePlayerVoiceTracks, v)
			end
		end			
	end

	if self.showerType == "Deluxe" then
		self.character:getEmitter():playSound("Faucet_Deluxe")
		self.showerCleanVal = 0.04
	else
		self.character:getEmitter():playSound("Faucet_Common")
	end
	self:setActionAnim("Loot")

	self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed or 0
	
	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit or 100
	
	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit - 65

----------------HEAT

	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	self.showerObject:getSquare():haveElectricity()) then
		--print("no electricity for shower")
	else
		local square = getSquare(self.showerObject:getX(), self.showerObject:getY(), self.showerObject:getZ())
		if square then
			self.showerHeat = HygieneHeatObject:new(self.showerObject:getSquare():getX(), self.showerObject:getSquare():getY(), self.showerObject:getSquare():getZ(), 3, 35)
			--self.showerHeat = HygieneHeatObject:new(self.character:getX(), self.character:getY(), self.character:getZ(), 15, 30)
		end
	end

-----------FACING
	local properties = self.showerObject:getSprite():getProperties()
	
	if properties:has("Facing") then
		self.facing = properties:get("Facing")
	end


end

function LSUseShower:stop()

	self.showerObject:setOverlaySprite(self.showerObjOverlay)

	local characterData = self.character:getModData()

	if self.showerHeat then--ADD NEG/POS MOODLES HERE
		--self.showerObject:getCell():removeHeatSource(self.showerHeat)
		self.showerHeat:destroy()
	elseif characterData.LSMoodles["BathCold"] and characterData.LSMoodles["BathCold"].Value then
		if characterData.LSMoodles["BathHot"] and characterData.LSMoodles["BathHot"].Value and characterData.LSMoodles["BathHot"].Value > 0 then
			characterData.LSMoodles["BathHot"].Value = 0
		end
			characterData.LSMoodles["BathCold"].Value = 0.2
	end

	--if self.waterObj then sledgeDestroy(self.waterObj); end
	if self.waterObj then self.tileSqr:RemoveTileObject(self.waterObj); end

	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit + 65
	LSUtil.changeCharacterMood(self.character, "Wetness", -30, false, false)

	self.character:getModData().lastBath = self.character:getHoursSurvived()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
	if self.gameSoundVoice then
		self.character:getEmitter():stopSound(self.gameSoundVoice)
	end
	if self.showerType == "Deluxe" then
		self.character:getEmitter():playSound("Faucet_Deluxe")
	else
		self.character:getEmitter():playSound("Faucet_Common")
	end
	self.character:getEmitter():playSound("Shower_End")

	--getSearchMode():setEnabled(self.character:getPlayerNum(), false)

	self.character:resetModelNextFrame();
	sendVisual(self.character);
	triggerEvent("OnClothingUpdated", self.character)

	local dice10 = ZombRand(10) + 1
	local addDirt = ZombRand(4) + 1
	
	if self.character:hasTrait(CharacterTrait.SLOPPY) then
		addDirt = 4
	elseif self.character:hasTrait(CharacterTrait.TIDY) then
		addDirt = 1
	end

	local thisDirtSprite

	self.showerObject:getModData().movableData = self.showerObject:getModData().movableData or {}

	if dice10 > 5 then--REENABLE THIS
		if self.showerObject:getModData().movableData.condition then
			self.showerObject:getModData().movableData.condition = self.showerObject:getModData().movableData.condition + addDirt
			if self.showerObject:getModData().movableData.condition > 100 then
				self.showerObject:getModData().movableData.condition = 100
			end
		else
			self.showerObject:getModData().movableData.condition = addDirt
		end

		if self.showerObject:getModData().movableData.dirtyLevel then
			if self.showerObject:getModData().movableData.dirtyLevel == 0 and self.showerObject:getModData().movableData.condition >= 30 then
				self.showerObject:getModData().movableData.dirtyLevel = 1
				thisDirtSprite = self.overlayDirtSprite
			elseif self.showerObject:getModData().movableData.dirtyLevel == 1 and self.showerObject:getModData().movableData.condition >= 60 then
				self.showerObject:getModData().movableData.dirtyLevel = 2
				thisDirtSprite = self.overlayDirtSprite2
			elseif self.showerObject:getModData().movableData.dirtyLevel == 2 and self.showerObject:getModData().movableData.condition >= 90 then
				self.showerObject:getModData().movableData.dirtyLevel = 3
				thisDirtSprite = self.overlayDirtSprite3
			end
		else
			self.showerObject:getModData().movableData.dirtyLevel = 0
		end
	end
	
	if self.showerObject:getModData().movableData.dirtyLevel == 1 then
		thisDirtSprite = self.overlayDirtSprite
	elseif self.showerObject:getModData().movableData.dirtyLevel == 2 then
		thisDirtSprite = self.overlayDirtSprite2
	elseif self.showerObject:getModData().movableData.dirtyLevel == 3 then
		thisDirtSprite = self.overlayDirtSprite3
	end
	
	----debug
		--self.character:Say("toilet condition is " .. tonumber(self.showerObject:getModData().movableData.condition) .. " and level is " .. tonumber(self.showerObject:getModData().movableData.dirtyLevel))
		--if thisDirtSprite then
		--	self.character:Say("sprite is " .. tostring(thisDirtSprite))
		--end
	----

	if isClient() and thisDirtSprite then
		sendClientCommand("LS", "ModifyOverlaySprite", {{self.showerObject:getX(),self.showerObject:getY(),self.showerObject:getZ(),self.showerObject:getSprite():getName()}, thisDirtSprite})
		LSSync.transmit(self.showerObject)
	elseif isClient() then
		LSSync.transmit(self.showerObject)
	elseif thisDirtSprite then
		self.showerObject:setOverlaySprite(thisDirtSprite, false)
	end

	if self.wearClothes then
		self.character:getEmitter():playSound("ChangeClothes")
		ClothesAboutToChange(self.character, self.showerObject, "isBathNoLaundryEnd")
	end

    ISBaseTimedAction.stop(self);		
end

function LSUseShower:perform()

	if self.waterObj then self.tileSqr:RemoveTileObject(self.waterObj); end

	self.showerObject:setOverlaySprite(self.showerObjOverlay)

	local characterData = self.character:getModData()

	if self.showerHeat then--ADD NEG/POS MOODLES HERE
		--self.showerObject:getCell():removeHeatSource(self.showerHeat)
		self.showerHeat:destroy()
		if characterData.LSMoodles["BathCold"] and characterData.LSMoodles["BathCold"].Value and characterData.LSMoodles["BathCold"].Value > 0 then
			characterData.LSMoodles["BathCold"].Value = 0
		end
		if characterData.LSMoodles["BathHot"] and characterData.LSMoodles["BathHot"].Value then
			characterData.LSMoodles["BathHot"].Value = 0.2
		end
	elseif characterData.LSMoodles["BathCold"] and characterData.LSMoodles["BathCold"].Value then
		if characterData.LSMoodles["BathHot"] and characterData.LSMoodles["BathHot"].Value and characterData.LSMoodles["BathHot"].Value > 0 then
			characterData.LSMoodles["BathHot"].Value = 0
		end
		characterData.LSMoodles["BathCold"].Value = 0.2
	end

	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit + 65
	LSUtil.changeCharacterMood(self.character, "Wetness", -30, false, false)

	self.character:getModData().lastBath = self.character:getHoursSurvived()

	if self.gameSoundLoop ~= 0 then
		self.character:getEmitter():stopSound(self.gameSoundLoop)
	end
	if self.gameSoundVoice then
		self.character:getEmitter():stopSound(self.gameSoundVoice)
	end
	if self.showerType == "Deluxe" then
		self.character:getEmitter():playSound("Faucet_Deluxe")
	else
		self.character:getEmitter():playSound("Faucet_Common")
	end
	self.character:getEmitter():playSound("Shower_End")
	--getSearchMode():setEnabled(self.character:getPlayerNum(), false)

	--self.character:getModData().bathroomNeed = 0

	self.character:resetModelNextFrame();
	sendVisual(self.character);
	triggerEvent("OnClothingUpdated", self.character)
	
	local dice20 = ZombRand(20) + 1
	local soundrandomiser = ZombRand(1, 100)
	local sound = "Zipper_CLOSE1"

	local dice10 = ZombRand(10) + 1
	local addDirt = ZombRand(4) + 1
	
	if self.character:hasTrait(CharacterTrait.SLOPPY) then
		addDirt = 4
	elseif self.character:hasTrait(CharacterTrait.TIDY) then
		addDirt = 1
	end

	local thisDirtSprite

	self.showerObject:getModData().movableData = self.showerObject:getModData().movableData or {}

	if dice10 > 5 then
		if self.showerObject:getModData().movableData.condition then
			self.showerObject:getModData().movableData.condition = self.showerObject:getModData().movableData.condition + addDirt
			if self.showerObject:getModData().movableData.condition > 100 then
				self.showerObject:getModData().movableData.condition = 100
			end
		else
			self.showerObject:getModData().movableData.condition = addDirt
		end

		if self.showerObject:getModData().movableData.dirtyLevel then
			if self.showerObject:getModData().movableData.dirtyLevel == 0 and self.showerObject:getModData().movableData.condition >= 30 then
				self.showerObject:getModData().movableData.dirtyLevel = 1
				thisDirtSprite = self.overlayDirtSprite
			elseif self.showerObject:getModData().movableData.dirtyLevel == 1 and self.showerObject:getModData().movableData.condition >= 60 then
				self.showerObject:getModData().movableData.dirtyLevel = 2
				thisDirtSprite = self.overlayDirtSprite2
			elseif self.showerObject:getModData().movableData.dirtyLevel == 2 and self.showerObject:getModData().movableData.condition >= 90 then
				self.showerObject:getModData().movableData.dirtyLevel = 3
				thisDirtSprite = self.overlayDirtSprite3
			end
		else
			self.showerObject:getModData().movableData.dirtyLevel = 0
		end
	end

	if self.showerObject:getModData().movableData.dirtyLevel == 1 then
		thisDirtSprite = self.overlayDirtSprite
	elseif self.showerObject:getModData().movableData.dirtyLevel == 2 then
		thisDirtSprite = self.overlayDirtSprite2
	elseif self.showerObject:getModData().movableData.dirtyLevel == 3 then
		thisDirtSprite = self.overlayDirtSprite3
	end

	if isClient() and thisDirtSprite then
		sendClientCommand("LS", "ModifyOverlaySprite", {{self.showerObject:getX(),self.showerObject:getY(),self.showerObject:getZ(),self.showerObject:getSprite():getName()}, thisDirtSprite})
		LSSync.transmit(self.showerObject)
	elseif isClient() then
		LSSync.transmit(self.showerObject)
	elseif thisDirtSprite then
		self.showerObject:setOverlaySprite(thisDirtSprite, false)
	end


	if self.wasDisturbedBy then
		local firstX, firstY
		for n=1,#self.wasDisturbedBy do
			local target = self.wasDisturbedBy[n]
			local id = target and target.getOnlineID and target:getOnlineID()
			if id then
				if not firstX then firstX = target:getX(); end; if not firstY then firstY = target:getY(); end
				sendClientCommand(self.character, "LS", "SendGetEmbarrassed", {id})
			end
		end
		if firstX and firstY then ShowerFunctions.DoActionDisturbed(self.character, firstX, firstY, self.showerObject, self.wearClothes); end
	elseif self.wearClothes then
		ShowerFunctions.DoAction(self.character, self.showerObject)
	end

	ISBaseTimedAction.perform(self);

end

function LSUseShower:washPart(visual, part)

	if visual:getBlood(part) + visual:getDirt(part) <= 0 then
		return false
	end
	if self.useSoap and visual:getBlood(part) > 0 then
        for i = 0, self.soaps:size() - 1 do
            local soap = self.soaps:get(i)
			if instanceof (soap, "DrainableComboItem") and soap:getCurrentUses() > 0 then
				soap:UseAndSync()
				break
			end
		end
	end
	visual:setBlood(part, 0)
	visual:setDirt(part, 0)
	return true
end

local makeup_locations = {"MAKE_UP_FULL_FACE","MAKE_UP_EYES","MAKE_UP_EYES_SHADOW","MAKE_UP_LIPS"}
function LSUseShower:removeAllMakeup()
	for n=1,#makeup_locations do
		local makeup = makeup_locations[n]
		local item = self.character:getWornItem(ItemBodyLocation[makeup])
		if item then
			self.character:removeWornItem(item)
			self.character:getInventory():Remove(item)
		end
	end
end

function LSUseShower:complete()
	local visual = self.character:getHumanVisual()
	local baseUse = self.waterUsage or 0
	local waterUsed = 0
	for i=1,BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i-1)
		if self:washPart(visual, part) then
			waterUsed = waterUsed + 1
			--if waterUsed >= self.showerObject:getFluidAmount() then
			--	break
			--end
		end
	end
	waterUsed = waterUsed+baseUse
	
	if SandboxVars.LSHygiene.CleansMakeup then self:removeAllMakeup(); end

	sendHumanVisual(self.character)

	if waterUsed > 0 then LSUtil.useObjFluid(self.showerObject, waterUsed); end

	return true
end

function LSUseShower.GetRequiredSoap(character)
	local units = 0
	local visual = character:getHumanVisual()
	for i=1,BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i-1)
		-- Soap is used for blood but not for dirt.
		if visual:getBlood(part) > 0 then
			units = units + 1
		end
	end
	return units
end

function LSUseShower.GetSoapRemaining(soaps)
    local total = 0
    if soaps and soaps.size then
        for i=0, soaps:size()-1 do
            local soap = soaps:get(i)
            if instanceof(soap, "DrainableComboItem") then
                total = total + soap:getCurrentUses()
            end
        end
    end
    return total
end

function LSUseShower:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 6000
end

function LSUseShower:new(character, showerObject, showerType, waterUsage, soundFaucet, soundWaterLoop, isFacing, overlayDirtSprite, overlayDirtSprite2, overlayDirtSprite3, wearClothes)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.showerObject = showerObject
	o.soaps = character:getInventory():getSoapList(nil, false)
	o.useSoap = (LSUseShower.GetRequiredSoap(character) <= LSUseShower.GetSoapRemaining(o.soaps))
	o.showerType = showerType
	o.waterUsage = waterUsage
	o.soundFaucet = soundFaucet
	o.soundWaterLoop = soundWaterLoop
	o.isFacing = isFacing
	o.wearClothes = wearClothes
	o.gameSoundLoop = 0
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.doAnim = 2
	o.decreaseNeed = 0
	o.decreaseNeedTotal = 14--70
	o.showerCleanVal = 0.03
	o.overlayDirtSprite = overlayDirtSprite
	o.overlayDirtSprite2 = overlayDirtSprite2
	o.overlayDirtSprite3 = overlayDirtSprite3
	o.wasDisturbedBy = false
	o.waterObj = false
	o.waterObjClone = false
	o.spriteNum = 0
	o.spriteNumClone = 0
	o.tileSqr = o.showerObject:getSquare()
	o.tileSqrClone = false
	o.AvailablePlayerVoiceTracks = false
	o.gameSoundVoice = false
	o.lastSound = false
	o.showerHeat = false
	o.depressed = 0
	o.depressedEnd = 0
	o.facing = false
	if showerObject:getOverlaySprite() then o.showerObjOverlay = showerObject:getOverlaySprite():getName(); else o.showerObjOverlay = nil; end
	return o;
end

return LSUseShower