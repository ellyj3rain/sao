
require "TimedActions/ISBaseTimedAction"
require "Hygiene/BathTubFunctions"

LSUseTub = ISBaseTimedAction:derive("LSUseTub");

--local isPlayingJukeSong = nil;

local function getDirtSprites(ThisSpriteName)

	local dirtSprite, dirtSprite2, dirtSprite3

	if (ThisSpriteName == "fixtures_bathroom_01_26") then
		dirtSprite = "LS_Misc_2_0"
		dirtSprite2 = "LS_Misc_2_8"
		dirtSprite3 = "LS_Misc_2_16"
	elseif (ThisSpriteName == "fixtures_bathroom_01_27") then
		dirtSprite = "LS_Misc_2_1"
		dirtSprite2 = "LS_Misc_2_9"
		dirtSprite3 = "LS_Misc_2_17"
	elseif (ThisSpriteName == "fixtures_bathroom_01_25") then
		dirtSprite = "LS_Misc_2_2"
		dirtSprite2 = "LS_Misc_2_10"
		dirtSprite3 = "LS_Misc_2_18"
	elseif (ThisSpriteName == "fixtures_bathroom_01_24") then
		dirtSprite = "LS_Misc_2_3"
		dirtSprite2 = "LS_Misc_2_11"
		dirtSprite3 = "LS_Misc_2_19"
	elseif (ThisSpriteName == "fixtures_bathroom_01_55") then
		dirtSprite = "LS_Misc_2_4"
		dirtSprite2 = "LS_Misc_2_12"
		dirtSprite3 = "LS_Misc_2_20"
	elseif (ThisSpriteName == "fixtures_bathroom_01_54") then
		dirtSprite = "LS_Misc_2_5"
		dirtSprite2 = "LS_Misc_2_13"
		dirtSprite3 = "LS_Misc_2_21"
	elseif (ThisSpriteName == "fixtures_bathroom_01_53") then
		dirtSprite = "LS_Misc_2_6"
		dirtSprite2 = "LS_Misc_2_14"
		dirtSprite3 = "LS_Misc_2_22"
	elseif (ThisSpriteName == "fixtures_bathroom_01_52") then
		dirtSprite = "LS_Misc_2_7"
		dirtSprite2 = "LS_Misc_2_15"
		dirtSprite3 = "LS_Misc_2_23"
	end

	return dirtSprite, dirtSprite2, dirtSprite3

end

local function getXYTexture(Facing, bubbleBath)

	if not Facing then return false, false, false, false, false, false; end
	local offSetX, offSetY, t1, t2, posX, posY, tileX, tileY = 1, 0, "LS_Fog_10", "LS_Fog_11", 0.2, 0, 0, 1
	if (bubbleBath > 0) then t1, t2 = "LS_Fog_14", "LS_Fog_15"; end

	if (Facing == "E") or (Facing == "W") then
		offSetX, offSetY, t1, t2, posX, posY, tileX, tileY = 1, 0, "LS_Fog_8", "LS_Fog_9", 0, 0.2, 0, 1
		if (bubbleBath > 0) then t1, t2 = "LS_Fog_12", "LS_Fog_13"; end
	end

	if Facing == "S" then
		posX, posY = 0.4, 0.35 -- 0.2, 0.35
	elseif Facing == "E" then
		posX, posY = 0.35, 0.4
	elseif Facing == "N" then
		posX, posY = 0.35, 0.4
	elseif Facing == "W" then
		posX, posY = 0.4, 0.35
	end

	return offSetX, offSetY, t1, t2, posX, posY, tileX, tileY

end

local function getTubEnterXY(Facing)

	if not Facing then return false, false; end

	if Facing == "S" then
		return 0.2, 0.35 -- 0.2, 0.35
	elseif Facing == "E" then
		return 0.35, 0.2
	elseif Facing == "N" then
		return 0.2, 0.35
	elseif Facing == "W" then
		return 0.35, 0.2
	end

	return false, false

end

local function getFacingLocation(Facing)

	if Facing == "N" then
		return 0, -1
	elseif Facing == "S" then
		return 0, 1
	elseif Facing == "E" then
		return 1, 0
	elseif Facing == "W" then
		return -1, 0
	end

	return 0, 0

end

local function getBubbleIdx(Facing, Part)

	if ((Facing == "E") or (Facing == "W")) and (Part == "M") then
	return {"LS_Bubbles_0","LS_Bubbles_8","LS_Bubbles_16","LS_Bubbles_24","LS_Bubbles_32","LS_Bubbles_40","LS_Bubbles_48","LS_Bubbles_56"}
	elseif ((Facing == "E") or (Facing == "W")) and (Part == "B") then
	return {"LS_Bubbles_1","LS_Bubbles_9","LS_Bubbles_17","LS_Bubbles_25","LS_Bubbles_33","LS_Bubbles_41","LS_Bubbles_49","LS_Bubbles_57"}
	elseif ((Facing == "S") or (Facing == "N")) and (Part == "M") then
	return {"LS_Bubbles_2","LS_Bubbles_10","LS_Bubbles_18","LS_Bubbles_26","LS_Bubbles_34","LS_Bubbles_42","LS_Bubbles_50","LS_Bubbles_58"}
	elseif ((Facing == "S") or (Facing == "N")) then
	return {"LS_Bubbles_3","LS_Bubbles_11","LS_Bubbles_19","LS_Bubbles_27","LS_Bubbles_35","LS_Bubbles_43","LS_Bubbles_51","LS_Bubbles_59"}
	end

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

local function getBubbleTexture(Facing, TM, TB)

	if not Facing then return false, false; end

	local bubbleTexturesM = getBubbleIdx(Facing, "M")
	local bubbleTexturesB = getBubbleIdx(Facing, "B")

	local idxBTM = ZombRand(#bubbleTexturesM) + 1
	local idxBTB = ZombRand(#bubbleTexturesB) + 1

	

	if TM and bubbleTexturesM[idxBTM] == TM then
		local newIdx = doIdxVariation(idxBTM, 8)
		idxBTM = newIdx
	end
	if TB and bubbleTexturesB[idxBTB] == TB then
		local newIdx = doIdxVariation(idxBTB, 8)
		idxBTB = newIdx
	end

	return bubbleTexturesM[idxBTM], bubbleTexturesB[idxBTB]

end

local function getSoundIdx(sound, isFemale)

	if sound == "WashBody" then
	return {"Tub_BodyClean1","Tub_BodyClean2","Tub_BodyClean3","Tub_BodyClean4"}
	elseif sound == "WaterSplash" then
	return {"Tub_Splash1","Tub_Splash2","Tub_Splash3","Tub_Splash4"}
	elseif (sound == "Voice_Yawn") and isFemale then
	return {"WomanBored01","WomanBored02","WomanYawn01","WomanYawn02"}
	elseif (sound == "Voice_Yawn") then
	return {"ManBored01","ManBored02","ManYawn01","ManYawn02"}
	end

end

local function getAnimSoundVariation(sound, oldSound, isFemale)

	local newSound = getSoundIdx(sound, isFemale)

	local idxS = ZombRand(#newSound) + 1

	if oldSound and newSound[idxS] == oldSound then
		local newIdx = doIdxVariation(idxS, 4)
		idxS = newIdx
	end

	return newSound[idxS]

end

local function doAnimRoutine(oldAnim)
	
	TubAnimList = {
		{name="Bob_Tub_WashArms",animTime=300,soundType="WashBody",soundTime=25,isSingle=false},
		{name="Bob_Tub_Rest",animTime=450,soundType="Voice_Yawn",soundTime=10,isSingle=true},
		{name="Bob_Tub_WashFace",animTime=300,soundType="WashBody",soundTime=25,isSingle=false},
		{name="Bob_Tub_WashArms",animTime=300,soundType="WashBody",soundTime=25,isSingle=false},
	}

	local idxA = ZombRand(#TubAnimList) + 1

	if oldAnim and TubAnimList[idxA].name == oldAnim then
		local newIdx = doIdxVariation(idxA, 4)
		idxA = newIdx
	end

	return TubAnimList[idxA].name, TubAnimList[idxA].animTime, TubAnimList[idxA].soundType, TubAnimList[idxA].soundTime, TubAnimList[idxA].isSingle
	--anim, sound type, sound time
end

local function doPlayerStats(character, cleanVal, bubbleBath, useSoap)

	-------------------------
	--------------DIRT/BLOOD
	local visual = character:getHumanVisual()
	local bloodCleanVal = cleanVal-0.01
	local hasDirtOrBlood = false
	local isBubbleBath = bubbleBath > 0

	for i = 1, BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i - 1)
		local dirt = visual:getDirt(part)
		local blood = visual:getBlood(part)
				
		if dirt > 0 and (dirt-cleanVal >= 0) then
			visual:setDirt(part, dirt-cleanVal)
		elseif dirt > 0 or dirt < 0 then
			visual:setDirt(part, 0)
			--visual:removeDirt()
		end
		if blood > 0 and (blood-bloodCleanVal >= 0) then
			visual:setBlood(part, blood-bloodCleanVal)
		elseif blood > 0 or blood < 0 then
			visual:setBlood(part, 0)
			--visual:removeBlood()
		end
				
		if (visual:getDirt(part) > 0) or (visual:getBlood(part) > 0) then
			hasDirtOrBlood = true
		end
	end
		
	-------------------------
	--------------ADJUST HYGIENE NEED
	local charData = character:getModData()
	if charData.hygieneNeed > 0 then
		local baseRate = (isBubbleBath and 0.5) or 1
		local rate = (useSoap and 1) or (charData.hygieneNeed > 60 and 0.5) or 0
		rate = baseRate+rate
		charData.hygieneNeed = LSUtil.truncateToTwoDecimals(math.max(0,charData.hygieneNeed-rate))
	end
	--character:Say("Hygiene need is now " .. character:getModData().hygieneNeed)

	-------------------------
	--------------ADJUST MOOD
	local moodList = {}
	moodList["Boredom"] = {-3, false, false, true}
	moodList["Stress"] = {-0.02, false, false, true}
	if isBubbleBath then
		moodList["Unhappiness"] = {-2, true, false, true}
	end
	if LSUtil.getCharacterMood(character, "Wetness") < 70 then moodList["Wetness"] = {70, false, true, true}; end
	LSUtil.changeCharacterMoodGroup(character, moodList)

	return hasDirtOrBlood

end

function LSUseTub:isValid()
	--local flushed = true
	
	--if self.mainTubObj:getModData().NeedsFlush then
		--flushed = false
	--end
	
	return true
end

function LSUseTub:waitToStart()
	self.action:setUseProgressBar(false)

	self.character:faceThisObject(self.mainTubObj)

	--local wait = false

	--if self.showerType == "Hanging" then
	--	self.character:faceThisObject(self.mainTubObj)
	--	wait = self.character:shouldBeTurning()
	--end
	

	return self.character:shouldBeTurning()
end

function LSUseTub:update()

	if (self.doAnim >= 110) then
		if (self.doAnim >= self.doStatsRate) then
			local hasDirtOrBlood = doPlayerStats(self.character, 0.03, self.isBubbleBath, self.useSoap)
			HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_HaloNote_Hygiene"), true, 170, 255, 150)
			
			-------------------------
			--------------PERFORM CONDITIONS (no water / hygiene fulfilled and no dirt/blood)
			if (((self.character:getModData().hygieneNeed <= 25) and (self.isBubbleBath == 0) and (self.doAnim >= 1500)) or ((self.character:getModData().hygieneNeed <= 15) and (self.doAnim >= 2500))) and not hasDirtOrBlood then
				self:forceComplete()
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
			--------------DEBUG
			--self.character:Say("doAnim value is: "..self.doAnim)
			---------------
			self.doStatsRate = (self.doAnim+50)
		end
		if (self.doAnim >= self.doAnimInterval) then
			local doActionAnim, doActionAnimInterval
			doActionAnim, doActionAnimInterval, self.actionAnimSound, self.actionAnimSoundTime, self.actionAnimSoundSingle = doAnimRoutine(self.actionAnim)
			self.actionAnimSoundTimeFinal = (self.actionAnimSoundTime+self.doAnim)
		
			self.actionAnim = doActionAnim
			self:setActionAnim(self.actionAnim)
	
			local sound = getAnimSoundVariation("WaterSplash", false, false)
			self.character:getEmitter():playSound(sound)
	
			self.doAnimInterval = (self.doAnim+doActionAnimInterval)
		end
	end

	if (self.doAnim >= 80) and not (self.doAnim >= 90) then
		
		local facingX, facingY = getFacingLocation(self.isFacing)
		self.character:faceLocation(self.character:getX()+facingX, self.character:getY()+facingY)
		self.character:faceLocationF(self.character:getX()+facingX, self.character:getY()+facingY)

		self.character:setX(self.mainTubObj:getSquare():getX()+self.posX)
		self.character:setY(self.mainTubObj:getSquare():getY()+self.posY)
		--if isClient() then
			--self.character:setLx(self.mainTubObj:getSquare():getX()+self.posX)
			--self.character:setLy(self.mainTubObj:getSquare():getY()+self.posY)
			--self.character:setX(self.mainTubObj:getSquare():getX()+self.posX)
			--self.character:setY(self.mainTubObj:getSquare():getY()+self.posY)
		--end

		self.doAnim = 90
		self:setActionAnim("Bob_ShowerSadStart")
		self.doSound = getAnimSoundVariation("WaterSplash", self.doSound2, false)
		self.character:getEmitter():playSound(self.doSound)

	elseif (self.doAnim >= 100) and not (self.doAnim >= 110) then
		self.doAnim = 110
		self:setActionAnim("Bob_Tub_Base")
		self.doSound2 = getAnimSoundVariation("WaterSplash", self.doSound, false)
		self.character:getEmitter():playSound(self.doSound2)
		self.doSound = false
		self.character:getModData().IsSittingOnSeat = true
		self.character:getModData().ComfortVal = 0.75
		if self.isBubbleBath > 0 then self.character:getModData().ComfortVal = 0.95 end
	else
		self.doAnim = self.doAnim + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	end

	-----------------------SOUNDS

	if self.actionAnimSoundTimeFinal and self.actionAnimSound and (self.doAnim >= self.actionAnimSoundTimeFinal) then
	
		if self.doSound then
			self.doSound2 = getAnimSoundVariation(self.actionAnimSound, self.doSound, self.character:isFemale())
			self.character:getEmitter():playSound(self.doSound2)
			self.doSound = false
		else
			self.doSound = getAnimSoundVariation(self.actionAnimSound, self.doSound2, self.character:isFemale())
			self.character:getEmitter():playSound(self.doSound)
			self.doSound2 = false
		end
	
		if self.actionAnimSoundSingle then
			self.actionAnimSoundTimeFinal = false
		else
			self.actionAnimSoundTimeFinal = (self.actionAnimSoundTime+self.doAnim)
		end
	end

	if (self.doAnim >= 43) and (self.doAnim < 50) and not self.doSound then
		self.doSound = getAnimSoundVariation("WaterSplash", false, false)
		self.character:getEmitter():playSound(self.doSound)
	elseif (self.doAnim >= 67) and (self.doAnim < 80) and not self.doSound2 then
		self.doSound2 = getAnimSoundVariation("WaterSplash", self.doSound, false)
		self.character:getEmitter():playSound(self.doSound2)
	end

			--------------HEAT
			if self.showerHeat then
				if not ((SandboxVars.ElecShutModifier > -1 and
				GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
				self.mainTubObj:getSquare():haveElectricity()) then
					--print("no electricity for shower")
					--self.mainTubObj:getCell():removeHeatSource(self.showerHeat)
					self.showerHeat:destroy()
					self.showerHeat = nil
				end
			
			end

	if self.doAnim > self.bubbleIntervalM then
		local BTM, BTB = getBubbleTexture(self.isFacing, self.bTM, self.bTB)

		self.bubbleObj:setSprite(BTM)
		self.bTM = BTM
		self.bubbleIntervalM = (self.doAnim+ZombRand(40)+15)
	end
	if self.doAnim > self.bubbleIntervalB then
		local BTM, BTB = getBubbleTexture(self.isFacing, self.bTM, self.bTB)
		self.bubbleObjClone:setSprite(BTB)
		self.bTB = BTB
		self.bubbleIntervalB = (self.doAnim+ZombRand(40)+15)
	end
	if self.bTM2 and (self.doAnim > self.bubbleIntervalM2) then
		local BTM, BTB = getBubbleTexture(self.isFacing, self.bTM, self.bTB)

		self.bubbleObj2:setSprite(BTM)
		self.bTM2 = BTM
		self.bubbleIntervalM2 = (self.doAnim+ZombRand(40)+15)
	end
	if self.bTB2 and (self.doAnim > self.bubbleIntervalB2) then
		local BTM, BTB = getBubbleTexture(self.isFacing, self.bTM, self.bTB)
		self.bubbleObjClone2:setSprite(BTB)
		self.bTB2 = BTB
		self.bubbleIntervalB2 = (self.doAnim+ZombRand(40)+15)
	end

	--self:resetJobDelta()

end

function LSUseTub:start()
	
	self:setOverrideHandModels(nil, nil)

	if self.isBubbleBath > 0 then self.hNL = 85 end
	self.character:getModData().hygieneNeed = self.character:getModData().hygieneNeed or 0	
	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit or 100
	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit - self.hNL
	self.character:getModData().IsDoingShower = true
----------------HEAT

	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	self.mainTubObj:getSquare():haveElectricity()) then
		--print("no electricity for shower")
	else
		local square = getSquare(self.mainTubObj:getX(), self.mainTubObj:getY(), self.mainTubObj:getZ())
		if square then
			self.showerHeat = HygieneHeatObject:new(self.mainTubObj:getSquare():getX(), self.mainTubObj:getSquare():getY(), self.mainTubObj:getSquare():getZ(), 3, 35)
			--self.showerHeat = HygieneHeatObject:new(self.character:getX(), self.character:getY(), self.character:getZ(), 15, 30)
		end
	end

---------DIRT

	self.overlayDirtSprite, self.overlayDirtSprite2, self.overlayDirtSprite3 = getDirtSprites(self.mainSpriteName)
	self.overlayDirtSpriteSub, self.overlayDirtSpriteSub2, self.overlayDirtSpriteSub3 = getDirtSprites(self.subSpriteName)

-------WATER BUBBLES

	if not self.bubbleObj then
		local offSetX, offSetY, textureM, textureS, tileX, tileY
		offSetX, offSetY, textureM, textureS, self.posX, self.posY, tileX, tileY = getXYTexture(self.isFacing, self.isBubbleBath)
		self.bTM, self.bTB = getBubbleTexture(self.isFacing, false, false)
		if self.isBubbleBath > 0 then self.bTM2, self.bTB2 = getBubbleTexture(self.isFacing, self.bTM, self.bTB); end
		
		if not offSetX then self:forceComplete(); end

		self.tileSqr = getCell():getGridSquare(self.mainTubObj:getX(), self.mainTubObj:getY(), self.mainTubObj:getZ())
		self.tileSqrClone = getCell():getGridSquare(self.subTubObj:getX(), self.subTubObj:getY(), self.subTubObj:getZ())
		--self.waterObj = IsoObject.new(self.tileSqr, "LS_Shower_" .. self.isFacing .. "_0")
		--self.waterObj = IsoObject.new(self.tileSqr, textureM)
		--self.waterObjClone = IsoObject.new(self.tileSqrClone, textureS)
		self.mainTubObj:setOverlaySprite(textureM, 1, 1, 1, 1)
		self.subTubObj:setOverlaySprite(textureS, 1, 1, 1, 1)
		self.bubbleObj = IsoObject.new(self.tileSqr, self.bTM)
		self.bubbleObjClone = IsoObject.new(self.tileSqrClone, self.bTB)
		--self.waterObj:setCustomColor(1, 1, 1, 1)
		--self.waterObj:renderlast()
		--if offSetX ~= 0 then
		--	self.waterObj:setOffsetX(offSetX)
		--	self.bubbleObj:setOffsetX(offSetX)
		--end
		--if offSetY ~= 0 then
		--	self.waterObj:setOffsetY(offSetY)
		--	self.bubbleObj:setOffsetY(offSetY)
		--end
		--self.waterObjClone:setOffsetX(offSetX)
		--self.waterObjClone:setOffsetY(offSetY)

		--self.waterObj:setAlpha(0.3)
		--self.waterObjClone:setAlpha(0.3)
		--self.tileSqr:AddTileObject(self.waterObj)	
		--self.tileSqrClone:AddTileObject(self.waterObjClone)	
		self.bubbleObj:setAlpha(0.6)
		self.bubbleObjClone:setAlpha(0.6)
		self.tileSqr:AddTileObject(self.bubbleObj)	
		self.tileSqrClone:AddTileObject(self.bubbleObjClone)
		if self.bTM2 then self.bubbleObj2 = IsoObject.new(self.tileSqr, self.bTM2); self.bubbleObjClone2 = IsoObject.new(self.tileSqrClone, self.bTB2); self.bubbleObj2:setAlpha(0.6);
		self.bubbleObjClone2:setAlpha(0.6); self.tileSqr:AddTileObject(self.bubbleObj2); self.tileSqrClone:AddTileObject(self.bubbleObjClone2); end
		--self.waterObj:transmitModData()
		--self.waterObj:transmitCompleteItemToServer()
		--self.waterObjClone:transmitCompleteItemToServer()
	end

	self:setActionAnim("Bob_Tub_Enter")
	self.startX = self.character:getX()
	self.startY = self.character:getY()

	local tubEnterX, tubEnterY = getTubEnterXY(self.isFacing)

	self.character:setX(self.mainTubObj:getSquare():getX()+tubEnterX)
	self.character:setY(self.mainTubObj:getSquare():getY()+tubEnterY)
	--if isClient() then
		--self.character:setLx(self.mainTubObj:getSquare():getX()+tubEnterX)
		--self.character:setLy(self.mainTubObj:getSquare():getY()+tubEnterY)
	--end

end

function LSUseTub:stop()

	local characterData = self.character:getModData()

	self.mainTubObj:setOverlaySprite(self.mainTubOverlay)
	self.subTubObj:setOverlaySprite(self.subTubOverlay)

	if self.showerHeat then--ADD NEG/POS MOODLES HERE
		--self.mainTubObj:getCell():removeHeatSource(self.showerHeat)
		self.showerHeat:destroy()
	elseif characterData.LSMoodles["BathCold"] and characterData.LSMoodles["BathCold"].Value then
		if characterData.LSMoodles["BathHot"] and characterData.LSMoodles["BathHot"].Value and characterData.LSMoodles["BathHot"].Value > 0 then
			characterData.LSMoodles["BathHot"].Value = 0
		end
			characterData.LSMoodles["BathCold"].Value = 0.2
	end

	if self.tileSqr then
		if not isClient() then
			self.tileSqr:transmitRemoveItemFromSquare(self.bubbleObj)
			if self.tileSqrClone then self.tileSqrClone:transmitRemoveItemFromSquare(self.bubbleObjClone); end
			if self.bTB2 then
				self.tileSqr:transmitRemoveItemFromSquare(self.bubbleObj2)
				if self.tileSqrClone then self.tileSqrClone:transmitRemoveItemFromSquare(self.bubbleObjClone2); end
			end
		end
		self.tileSqr:RemoveTileObject(self.bubbleObj)
		if self.tileSqrClone then self.tileSqrClone:RemoveTileObject(self.bubbleObjClone); end
		if self.bTB2 then
			self.tileSqr:RemoveTileObject(self.bubbleObj2)
			if self.tileSqrClone then self.tileSqrClone:RemoveTileObject(self.bubbleObjClone2); end
		end
	end

	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit + self.hNL
	LSUtil.changeCharacterMood(self.character, "Wetness", -30, false, false)

	self.character:getModData().lastBath = self.character:getHoursSurvived()
	self.character:getModData().IsSittingOnSeat = false
	self.character:getModData().IsDoingShower = false

	self.character:getEmitter():playSound("Tub_End")

	--getSearchMode():setEnabled(self.character:getPlayerNum(), false)

	self.character:resetModelNextFrame();
	sendVisual(self.character);
	triggerEvent("OnClothingUpdated", self.character)

	--if SandboxVars.LSHygiene.CleansMakeup and not self.removedMakeup then sendClientCommand(self.character, "LS", "RemoveMakeup", {false, true}); self.removedMakeup = true; end

	local dice10 = ZombRand(10) + 1
	local addDirt = ZombRand(4) + 1
	
	if self.character:hasTrait(CharacterTrait.SLOPPY) then
		addDirt = 4
	elseif self.character:hasTrait(CharacterTrait.TIDY) then
		addDirt = 1
	end

	local thisDirtSprite, thisDirtSpriteConnected

	self.mainTubObj:getModData().movableData = self.mainTubObj:getModData().movableData or {}
	self.subTubObj:getModData().movableData = self.subTubObj:getModData().movableData or {}

	if dice10 > 5 then
		if self.mainTubObj:getModData().movableData.condition then
			self.mainTubObj:getModData().movableData.condition = self.mainTubObj:getModData().movableData.condition + addDirt
			if self.mainTubObj:getModData().movableData.condition > 100 then
				self.mainTubObj:getModData().movableData.condition = 100
			end
		else
			self.mainTubObj:getModData().movableData.condition = addDirt
		end

		self.subTubObj:getModData().movableData.condition = self.mainTubObj:getModData().movableData.condition

		if self.mainTubObj:getModData().movableData.dirtyLevel then
			if self.mainTubObj:getModData().movableData.dirtyLevel == 0 and self.mainTubObj:getModData().movableData.condition >= 30 then
				self.mainTubObj:getModData().movableData.dirtyLevel = 1
				thisDirtSprite = self.overlayDirtSprite
				thisDirtSpriteConnected = self.overlayDirtSpriteSub
			elseif self.mainTubObj:getModData().movableData.dirtyLevel == 1 and self.mainTubObj:getModData().movableData.condition >= 60 then
				self.mainTubObj:getModData().movableData.dirtyLevel = 2
				thisDirtSprite = self.overlayDirtSprite2
				thisDirtSpriteConnected = self.overlayDirtSpriteSub2
			elseif self.mainTubObj:getModData().movableData.dirtyLevel == 2 and self.mainTubObj:getModData().movableData.condition >= 90 then
				self.mainTubObj:getModData().movableData.dirtyLevel = 3
				thisDirtSprite = self.overlayDirtSprite3
				thisDirtSpriteConnected = self.overlayDirtSpriteSub3
			end
		else
			self.mainTubObj:getModData().movableData.dirtyLevel = 0
		end
		
		self.subTubObj:getModData().movableData.dirtyLevel = self.mainTubObj:getModData().movableData.dirtyLevel
		
	end

	if isClient() and thisDirtSprite then
		sendClientCommand("LS", "ModifyOverlaySprite", {{self.mainTubObj:getX(),self.mainTubObj:getY(),self.mainTubObj:getZ(),self.mainTubObj:getSprite():getName()}, thisDirtSprite})
		sendClientCommand("LS", "ModifyOverlaySprite", {{self.subTubObj:getX(),self.subTubObj:getY(),self.subTubObj:getZ(),self.subTubObj:getSprite():getName()}, thisDirtSpriteConnected})
		LSSync.transmit(self.mainTubObj)
		LSSync.transmit(self.subTubObj)
	elseif isClient() then
		LSSync.transmit(self.mainTubObj)
		LSSync.transmit(self.subTubObj)
	elseif thisDirtSprite then
		self.mainTubObj:setOverlaySprite(thisDirtSprite, false)
		self.subTubObj:setOverlaySprite(thisDirtSpriteConnected, false)
	end

	if self.wearClothes then 
		self.character:getEmitter():playSound("ChangeClothes")
		ClothesAboutToChange(self.character, self.mainTubObj, "isBathNoLaundryEnd")
	end

    ISBaseTimedAction.stop(self);	
end

function LSUseTub:perform()

	local characterData = self.character:getModData()
	
	self.mainTubObj:setOverlaySprite(self.mainTubOverlay)
	self.subTubObj:setOverlaySprite(self.subTubOverlay)

	--if self.tileSqr and self.waterObj then
		--self.tileSqr:RemoveTileObject(self.waterObj)
		--self.tileSqr:transmitRemoveItemFromSquare(self.waterObj)
		--self.tileSqr:transmitRemoveItemFromSquareOnServer(self.waterObj)
		--self.tileSqr:RemoveTileObject(self.waterObj)
		--self.waterObj:transmitCompleteItemToServer()
	--end

	--if isClient() and self.tileSqr and self.waterObj then
	--	sledgeDestroy(self.waterObj);
	--elseif self.tileSqr and self.waterObj then
		--self.tileSqr:transmitRemoveItemFromSquare(self.waterObj)
		--self.tileSqr:RemoveTileObject(self.waterObj)
		--self.waterObj:transmitCompleteItemToServer()
	--end

	if self.showerHeat then--ADD NEG/POS MOODLES HERE
		--self.mainTubObj:getCell():removeHeatSource(self.showerHeat)
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

	if self.tileSqr then
		if not isClient() then
			self.tileSqr:transmitRemoveItemFromSquare(self.bubbleObj)
			if self.tileSqrClone then self.tileSqrClone:transmitRemoveItemFromSquare(self.bubbleObjClone); end
			if self.bTB2 then
				self.tileSqr:transmitRemoveItemFromSquare(self.bubbleObj2)
				if self.tileSqrClone then self.tileSqrClone:transmitRemoveItemFromSquare(self.bubbleObjClone2); end
			end
		end
		self.tileSqr:RemoveTileObject(self.bubbleObj)
		if self.tileSqrClone then self.tileSqrClone:RemoveTileObject(self.bubbleObjClone); end
		if self.bTB2 then
			self.tileSqr:RemoveTileObject(self.bubbleObj2)
			if self.tileSqrClone then self.tileSqrClone:RemoveTileObject(self.bubbleObjClone2); end
		end
	end

	self.character:getModData().hygieneNeedLimit = self.character:getModData().hygieneNeedLimit + self.hNL
	LSUtil.changeCharacterMood(self.character, "Wetness", -30, false, false)

	self.character:getModData().lastBath = self.character:getHoursSurvived()
	self.character:getModData().IsSittingOnSeat = false
	self.character:getModData().IsDoingShower = false

	self.character:getEmitter():playSound("Tub_End")

	self.character:resetModelNextFrame();
	sendVisual(self.character);
	triggerEvent("OnClothingUpdated", self.character)

	--if SandboxVars.LSHygiene.CleansMakeup and not self.removedMakeup then sendClientCommand(self.character, "LS", "RemoveMakeup", {false, true}); self.removedMakeup = true; end

	local dice10 = ZombRand(10) + 1
	local addDirt = ZombRand(4) + 1
	
	if self.character:hasTrait(CharacterTrait.SLOPPY) then
		addDirt = 4
	elseif self.character:hasTrait(CharacterTrait.TIDY) then
		addDirt = 1
	end

	local thisDirtSprite, thisDirtSpriteConnected

	self.mainTubObj:getModData().movableData = self.mainTubObj:getModData().movableData or {}
	self.subTubObj:getModData().movableData = self.subTubObj:getModData().movableData or {}

	if dice10 > 5 then
		if self.mainTubObj:getModData().movableData.condition then
			self.mainTubObj:getModData().movableData.condition = self.mainTubObj:getModData().movableData.condition + addDirt
			if self.mainTubObj:getModData().movableData.condition > 100 then
				self.mainTubObj:getModData().movableData.condition = 100
			end
		else
			self.mainTubObj:getModData().movableData.condition = addDirt
		end

		self.subTubObj:getModData().movableData.condition = self.mainTubObj:getModData().movableData.condition

		if self.mainTubObj:getModData().movableData.dirtyLevel then
			if self.mainTubObj:getModData().movableData.dirtyLevel == 0 and self.mainTubObj:getModData().movableData.condition >= 30 then
				self.mainTubObj:getModData().movableData.dirtyLevel = 1
				thisDirtSprite = self.overlayDirtSprite
				thisDirtSpriteConnected = self.overlayDirtSpriteSub
			elseif self.mainTubObj:getModData().movableData.dirtyLevel == 1 and self.mainTubObj:getModData().movableData.condition >= 60 then
				self.mainTubObj:getModData().movableData.dirtyLevel = 2
				thisDirtSprite = self.overlayDirtSprite2
				thisDirtSpriteConnected = self.overlayDirtSpriteSub2
			elseif self.mainTubObj:getModData().movableData.dirtyLevel == 2 and self.mainTubObj:getModData().movableData.condition >= 90 then
				self.mainTubObj:getModData().movableData.dirtyLevel = 3
				thisDirtSprite = self.overlayDirtSprite3
				thisDirtSpriteConnected = self.overlayDirtSpriteSub3
			end
		else
			self.mainTubObj:getModData().movableData.dirtyLevel = 0
		end
		
		self.subTubObj:getModData().movableData.dirtyLevel = self.mainTubObj:getModData().movableData.dirtyLevel
		
	end

	if isClient() and thisDirtSprite then
		sendClientCommand("LS", "ModifyOverlaySprite", {{self.mainTubObj:getX(),self.mainTubObj:getY(),self.mainTubObj:getZ(),self.mainTubObj:getSprite():getName()}, thisDirtSprite})
		sendClientCommand("LS", "ModifyOverlaySprite", {{self.subTubObj:getX(),self.subTubObj:getY(),self.subTubObj:getZ(),self.subTubObj:getSprite():getName()}, thisDirtSpriteConnected})
		LSSync.transmit(self.mainTubObj)
		LSSync.transmit(self.subTubObj)
	elseif isClient() then
		LSSync.transmit(self.mainTubObj)
		LSSync.transmit(self.subTubObj)
	elseif thisDirtSprite then
		self.mainTubObj:setOverlaySprite(thisDirtSprite, false)
		self.subTubObj:setOverlaySprite(thisDirtSpriteConnected, false)
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
		if firstX and firstY then BathTubFunctions.DoActionDisturbed(self.character, firstX, firstY, self.mainTubObj, self.startX, self.startY, self.wearClothes); end
	else
		BathTubFunctions.DoAction(self.character, self.mainTubObj, self.startX, self.startY, self.wearClothes)
	end

	ISBaseTimedAction.perform(self);

end

function LSUseTub:washPart(visual, part)

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
function LSUseTub:removeAllMakeup()
	for n=1,#makeup_locations do
		local makeup = makeup_locations[n]
		local item = self.character:getWornItem(ItemBodyLocation[makeup])
		if item then
			self.character:removeWornItem(item)
			self.character:getInventory():Remove(item)
		end
	end
end

function LSUseTub.GetRequiredSoap(character)
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

function LSUseTub.GetSoapRemaining(soaps)
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

function LSUseTub:complete()
	local visual = self.character:getHumanVisual()
	local baseUse = 4
	local waterUsed = 0
	for i=1,BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i-1)
		if self:washPart(visual, part) then
			waterUsed = waterUsed + 1
			--if waterUsed >= self.mainTubObj:getFluidAmount() then
			--	break
			--end
		end
	end
	waterUsed = waterUsed+baseUse
	
	if SandboxVars.LSHygiene.CleansMakeup then self:removeAllMakeup(); end

	sendHumanVisual(self.character)

	if waterUsed > 0 then LSUtil.useObjFluid(self.mainTubObj, waterUsed); end

	return true
end

function LSUseTub:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function LSUseTub:new(character, mainTubObj, subTubObj, mainSpriteName, subSpriteName, isFacing, wearClothes, isBubbleBath)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.mainTubObj = mainTubObj
	o.soaps = character:getInventory():getSoapList(nil, false)
	o.useSoap = (LSUseTub.GetRequiredSoap(character) <= LSUseTub.GetSoapRemaining(o.soaps))
	o.subTubObj = subTubObj
	o.mainSpriteName = mainSpriteName
	o.subSpriteName = subSpriteName
	o.isFacing = isFacing
	o.wearClothes = wearClothes
	o.ignoreDynamicTime = true
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
	o.maxTime = o:getDuration()
	o.doAnim = 0
	o.doAnimInterval = 150
	o.overlayDirtSprite = false
	o.overlayDirtSprite2 = false
	o.overlayDirtSprite3 = false
	o.overlayDirtSpriteSub = false
	overlayDirtSpriteSub2 = false
	overlayDirtSpriteSub3 = false
	o.wasDisturbedBy = false
	o.waterObj = false
	o.waterObjClone = false
	o.bubbleObj = false
	o.bubbleObjClone = false
	o.spriteNum = 0
	o.spriteNumClone = 0
	o.tileSqr = false
	o.tileSqrClone = false
	o.gameSoundVoice = false
	o.lastSound = false
	o.showerHeat = false
	o.posX = 0
	o.posY = 0
	o.doSound = false
	o.doSound2 = false
	o.bubbleIntervalM = 15
	o.bubbleIntervalB = 30
	o.bubbleIntervalM2 = 45
	o.bubbleIntervalB2 = 60
	o.bTM = false
	o.bTB = false
	o.actionAnim = false
	o.actionAnimSound = false
	o.actionAnimSoundTime = false
	o.actionAnimSoundSingle = false
	o.actionAnimSoundTimeFinal = false
	o.startX = false
	o.startY = false
	o.doStatsRate = 50
	o.isBubbleBath = isBubbleBath
	o.hNL = 75
	o.bTM2 = false
	o.bTB2 = false
	o.bubbleObj2 = false
	o.bubbleObjClone2 = false
	if mainTubObj:getOverlaySprite() then o.mainTubOverlay = mainTubObj:getOverlaySprite():getName(); else o.mainTubOverlay = nil; end
	if subTubObj:getOverlaySprite() then o.subTubOverlay = subTubObj:getOverlaySprite():getName(); else o.subTubOverlay = nil; end
	return o;
end

return LSUseTub