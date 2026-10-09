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
require "Helper/CheckPlayerHelper"
require "Properties/Objects/beauty"

LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerMin = LSMoodHandler.PerMin or {} -- accumulates per min mood gain/loss and is used each 10 min, reducing the number of client command calls
LS_DJBooth = LS_DJBooth or {}

local function getbeautyRGB(quality)
	if quality == "IGUI_PaintingQuality_Good" then return "<PUSHRGB:0,128,0>"; elseif quality == "IGUI_PaintingQuality_Excellent" then return "<PUSHRGB:0,0,255>"; elseif quality == "IGUI_PaintingQuality_Impressive" then return "<PUSHRGB:128,0,128>"; elseif quality == "IGUI_PaintingQuality_Wondrous" then return "<PUSHRGB:255,215,0>"; elseif quality == "IGUI_PaintingQuality_Masterpiece" then return "<PUSHRGB:255,128,0>";
	elseif quality == "IGUI_PaintingQuality_Awful" then return "<PUSHRGB:128,0,0>"; elseif quality == "IGUI_PaintingQuality_Poor" then return "<PUSHRGB:139,69,19>"; elseif quality == "IGUI_PaintingQuality_Shoddy" then return "<PUSHRGB:105,105,105>"; end
	return "<PUSHRGB:255,255,255>"
end

local function getCorrectData(object)
	if object:getModData().movableData and object:getModData().movableData['artAuthor'] and object:getModData().movableData['artBeauty'] then return object:getModData().movableData;
	elseif object:getModData().modData and object:getModData().modData.movableData and object:getModData().modData.movableData['artAuthor'] and object:getModData().modData.movableData['artBeauty'] then return object:getModData().modData.movableData; end
	return false
end

local function RefreshItemToolTip(thisPlayer)

	local containerList = ArrayList.new();
	local playerNum = thisPlayer and thisPlayer:getPlayerNum() or -1
	if not playerNum then return; end
    for i,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end

--	if #containerList > 0 then
--		for i,v in ipairs(containerList:getItems()) do
	for i=0,containerList:size()-1 do
		local container = containerList:get(i);
		for x=0,container:getItems():size() - 1 do
			local v = container:getItems():get(x);
			if (v:getFullType() == 'Lifestyle.SheetMusicBook') then
				if v:getModData() and v:getModData().InscribedSongs then
					local tooltipText = getText("Tooltip_SheetBook_ItemHeaderStart") .. #v:getModData().InscribedSongs .. getText("Tooltip_SheetBook_ItemHeaderEnd")
					v:setTooltip(tooltipText)
				end
			end
			if instanceof(v, "InventoryItem") and v:hasModData() then
				local data = getCorrectData(v)
				if data then
				--if v:getModData().movableData['artName'] then v:setName(tostring(v:getModData().movableData['artName'])); v:setCustomName(true); end
					v:setDisplayCategory("Art")
					local separator = " / "
					local artName = data['artName'] or "None"
					--if data['artName'] then artName = data['artName']; end
					if data['artSize'] and (data['artSize'] == "large") then separator = " (x2) / "; end
					if not data['artQuality'] then data['artQuality'] = "IGUI_PaintingQuality_Normal"; end
					v:setTooltip(getText("IGUI_PaintingCustomName")..": "..artName.." / "..getText("IGUI_PaintingBeauty")..": "..data['artBeauty'].." "..getText(data['artQuality'])..separator..getText("IGUI_PaintingStyle")..": "..getText("IGUI_PaintingStyle"..data['artStyle']).." / "..getText("IGUI_PaintingAuthor")..": "..data['artAuthor'])
				end
			end
		end
	end
end

local function getPlayerBedQuality(thisPlayer)
	local bedQuality, bed = "floor", false
	if thisPlayer:getVehicle() then return "averageBed"; end
	for x = thisPlayer:getX()-1,thisPlayer:getX()+1 do
		for y = thisPlayer:getY()-1,thisPlayer:getY()+1 do
			local square = getCell():getGridSquare(x,y,thisPlayer:getZ())
			if square and (thisPlayer:getSquare():isOutside() == square:isOutside()) and (square:getRoom() == thisPlayer:getSquare():getRoom()) then
				for i = 0,square:getObjects():size()-1 do------------------------------------
					local object = square:getObjects():get(i)
					if instanceof(object, "IsoObject") and object:getSprite() and object:getSprite():getProperties() and object:getSprite():getProperties():has(IsoFlagType.bed) then
						bed = object
						bedQuality = object:getSprite():getProperties():get("BedType")
						break
					end
				end
			end
		if bed then break; end
		end
	if bed then break; end
	end
	--print("LSPERMINUTE: getPlayerBedQuality - bedQuality is "..bedQuality)
	return bedQuality
end

local function getBedQualityTypes()
	return {
		{name="Good",bad=0,comf=0.9},
		{name="goodBed",bad=0,comf=0.9},
		{name="Average",bad=0.2,comf=0.8},
		{name="averageBed",bad=0.2,comf=0.8},
		{name="Bad",bad=0.3,comf=0.5},
		{name="badBed",bad=0.3,comf=0.5},
	}
end

local function getSleepingVals(thisPlayer)
	local bedPenalty, comfVal = 0.4, 0
	if not thisPlayer:getModData().CurrentBedQuality then
		thisPlayer:getModData().CurrentBedQuality = getPlayerBedQuality(thisPlayer)
	end
	--getBedType() seems to be returning averageBed regardless of bed quality
	--getBed() seems to be returning nil
	--print("LSPERMINUTE: getSleepingVals - start")
	if thisPlayer:getModData().CurrentBedQuality and (thisPlayer:getModData().CurrentBedQuality ~= "floor") then
		--print("LSPERMINUTE: getSleepingVals - bedType is "..thisPlayer:getModData().CurrentBedQuality)
		for k, v in ipairs(getBedQualityTypes()) do
			if string.find(thisPlayer:getModData().CurrentBedQuality, v.name) then
				--print("LSPERMINUTE: getSleepingVals - getBedQualityType is "..v.name)
				bedPenalty = v.bad
				comfVal = v.comf
				break
			end
		end
	end
	return bedPenalty, comfVal
end

local function getMoodTraitMultipliers(character)
	local multipliers = {1, 1, 1, 1} -- {"Comfort", "Uncomfortable"}, {"MusicGood", "MusicBad","DJAudience"}, {"PartyGood", "PartyBad"}, {"Eureka"}
	local traits = {
		['DISCIPLINED'] = {-0.5, -0.2, -0.2, 0},
		['COUCHPOTATO'] = {1, 0, -0.5, 0},
		['VIRTUOSO'] = {0, 1, 0, 0},
		['TONEDEAF'] = {0, 2, 0, 0},
		['HARD_OF_HEARING'] = {0, -0.3, 0, 0},
		['PARTYANIMAL'] = {0, 0, 1, 0},
		['KILLJOY'] = {0, 0, 1, 0},
		['INVENTIVE'] = {0, 0, 0, 1},
	}
	
	for k, v in pairs(traits) do
		if CharacterTrait[k] and character:hasTrait(CharacterTrait[k]) then
			for n=1,#v do
				local mult = v[n]
				if mult and mult ~= 0 then
					multipliers[n] = math.max(0.1, multipliers[n]+mult)
				end
			end
		end
	end
	
	return multipliers
end

local function adjustMintCurio(character)
	local hungryMoodle = MoodleType["HUNGRY"]
	if hungryMoodle and not character:getMoodles():getMoodleLevel(hungryMoodle) ~= 0 then
		if not LSMoodHandler.PerMin["Hunger"] then
			LSMoodHandler.PerMin["Hunger"] = {-0.05, false, false, true}
		else
			LSMoodHandler.PerMin["Hunger"][1] = LSMoodHandler.PerMin["Hunger"][1]-0.05
		end
	end
	if ZombRand(4)==1 then
		if not LSMoodHandler.PerMin["Thirst"] then
			LSMoodHandler.PerMin["Thirst"] = {0.05, false, false, true}
		else
			LSMoodHandler.PerMin["Thirst"][1] = LSMoodHandler.PerMin["Thirst"][1]+0.025
		end
	end
end

local function doMoodlesCalc(character, moodleData)
	local addStress, addUnhappiness, addBoredom, addDiscomfort = 0, 0, 0, 0
	local moodles = {"Comfort", "Uncomfortable", "Embarrassed", "PartyGood", "PartyBad", "MusicGood", "MusicBad","DJAudience","MintFresh", "MintCurio","BathHot", "BathCold", "Eureka", "Gloomy"}
	local mult = getMoodTraitMultipliers(character)
	--params -> reduce moodle value, stress, unhappiness, boredom, trait exclude
	local t = {
		[0.8] = {
					Comfort={false, -0.03*mult[1], -1.6*mult[1]},
					Gloomy={false, false, 3},
					Eureka={false, false, -3*mult[4]},
				},
		[0.6] = {
					Comfort={false, -0.02*mult[1], -1*mult[1]},
					PartyGood={false, -0.03*mult[3], -2*mult[3], -2*mult[3]},
					PartyBad={false, 0.05*mult[3], 3*mult[3], 3*mult[3]},
					DJAudience={false, -0.03*mult[2], -2*mult[2], -2*mult[2]},
					Gloomy={false, false, 1.5},
					Eureka={false, false, -2*mult[4]},
				},
		[0.4] = {
					Comfort={false, -0.01*mult[1], -0.7*mult[1]},
					Embarrassed={0.02, 0.03, 1},
					PartyGood={false, -0.01*mult[3], -1*mult[3], -1*mult[3]},
					PartyBad={false, 0.03*mult[3], 1.5*mult[3], 2*mult[3]},
					MusicGood={false, -0.02*mult[2], -1*mult[2], -1*mult[2], "DEAF"},
					MusicBad={false, 0.05*mult[2], 2*mult[2], 2*mult[2], "DEAF"},
					DJAudience={false, -0.01*mult[2], -1*mult[2], -1*mult[2]},
					Gloomy={false, false, 1},
					Eureka={false, false, -1*mult[4]},
				},
		[0.2] = {
					Comfort={false, -0.005*mult[1], -0.4*mult[1]},
					Uncomfortable={false, 0.001*mult[1], 0.01*mult[1]},
					Embarrassed={0.01, 0.015, 0.5},
					PartyGood={false, -0.003*mult[3], -0.5*mult[3], -1*mult[3]},
					PartyBad={false, 0.01*mult[3], 0.7*mult[3], 1*mult[3]},
					MusicGood={false, -0.002*mult[2], -0.5*mult[2], -0.5*mult[2], "DEAF"},
					MusicBad={false, 0.005*mult[2], 0.7*mult[2], 1*mult[2], "DEAF"},
					MintFresh={false, -0.003, -0.2},
					MintCurio={false, -0.003, -0.2},
					BathHot={false, -0.005, -0.5},
					BathCold={false, 0.007, 0.6},
					DJAudience={false, -0.003*mult[2], -0.5*mult[2], -1*mult[2]},
					Gloomy={false, false, 0.5},
					Eureka={false, false, -0.5*mult[4]},
				},
		[0] = {
					Embarrassed={0.005},
				},
	}
	
	local thresholds = {0.8,0.6,0.4,0.2,0}
	for n=1, #moodles do
		local moodle = moodles[n]
		local moodleVal = moodleData[moodle] and moodleData[moodle].Value
		local newVal = moodleVal
		for j=1, #thresholds do
			local params = t[thresholds[j]] and t[thresholds[j]][moodle]
			if moodleVal >= thresholds[j] and params and (not params[5] or not CharacterTrait[params[5]] or not character:hasTrait(CharacterTrait[params[5]])) then
				if params[1] then newVal = newVal-params[1]; end
				if params[2] then addStress = addStress+params[2]; end
				if params[3] then
					addUnhappiness = addUnhappiness+params[3]
					if (moodle == "Comfort" or moodle == "Uncomfortable") and not SandboxVars.LSComfort.ComfortNoImpact then
						addDiscomfort = addDiscomfort+params[3]
					end
				end
				if params[4] then addBoredom = addBoredom+params[4]; end
				if moodle == "MintCurio" then adjustMintCurio(character); end
				break
			end
		end
		newVal = math.max(0, math.min(1, newVal))
		if newVal ~= moodleVal then moodleData[moodle].Value = newVal; end
	end
	return addStress, addUnhappiness, addBoredom, addDiscomfort
end

local function doComfortCalc(moodleVal, moodle, comfortNeed)
	local t = {
		{k=0.9,  Comfort=0.8, Uncomfortable=0},
		{k=0.8,  Comfort=0.6, Uncomfortable=0},
		{k=0.7,  Comfort=0.4, Uncomfortable=0},
		{k=0.6,  Comfort=0.2, Uncomfortable=0},
		{k=0.11, Comfort=0,   Uncomfortable=0},
		{k=0.0,  Comfort=0,   Uncomfortable=0.2},
	}

	local newVal = moodleVal
	local lastK = 1
	for i=1,#t do
		local v = t[i]
		if comfortNeed >= v.k then
			if moodleVal < v[moodle] and comfortNeed-0.025 > v.k then
				newVal = math.min(v[moodle], newVal+0.2)
			elseif moodleVal > v[moodle] and comfortNeed+0.05 < lastK then
				newVal = math.max(v[moodle], newVal-0.2)
			end
			break
		end
		lastK = v.k
	end

	if newVal ~= moodleVal then LSMoodleManager.setValue(moodle, newVal); end

end

local function adjustComfortNeed(thisPlayer, playerData)
	local addComf = 0
	local mult = 1
	-------------COMFORT
	local decreaseRate = 0.0025
	local increaseRate = 0.015

	if thisPlayer:hasTrait(CharacterTrait.DISCIPLINED) then
		decreaseRate = 0.0010
		increaseRate = 0.005
	elseif thisPlayer:hasTrait(CharacterTrait.COUCHPOTATO) then
		decreaseRate = 0.005
		increaseRate = 0.02
	end

	if playerData.LSMoodles["Comfort"].Value <= 0 then--we do this so that comfort decreases faster while comfortable and slower while not
		decreaseRate = decreaseRate * 0.2
	end

	if not playerData.ComfortNeed or thisPlayer:isGodMod() then playerData.ComfortNeed = 0.5; end
	if not playerData.ComfortVal then playerData.ComfortVal = 0.35; end
	local comfortMultiplierSO = SandboxVars.LSComfort.ComfortNeedMultiplier or 1
	if comfortMultiplierSO > 0 or playerData.ComfortNeed < 0.2 then decreaseRate = decreaseRate*comfortMultiplierSO; end
	
	if not playerData.IsSittingOnSeat and not playerData.IsOnBed and not thisPlayer:isSitOnGround() and not thisPlayer:isDriving() and not thisPlayer:isSeatedInVehicle() and not thisPlayer:isAsleep() and not thisPlayer:isSittingOnFurniture() then
		playerData.ComfortVal = 0
		addComf = addComf-decreaseRate
	else
		local sleepingPenalty = 0
		if thisPlayer:isSittingOnFurniture() or thisPlayer:getVariableBoolean("sittingonfurniture") or thisPlayer:getVariableBoolean("onbed") then
			playerData.ComfortVal = 0.7
		elseif thisPlayer:isAsleep() and not playerData.IsOnBed then
			sleepingPenalty, playerData.ComfortVal = getSleepingVals(thisPlayer)
		elseif not playerData.IsSittingOnSeat then
			playerData.ComfortVal = 0.25
		end
		local totalComfort = playerData.ComfortVal-sleepingPenalty
		if playerData.ComfortNeed > totalComfort then
			addComf = addComf - decreaseRate
		elseif playerData.ComfortNeed <= totalComfort then
			if playerData.ComfortNeed >= totalComfort-increaseRate then
				addComf = totalComfort
			elseif playerData.ComfortNeed*2 < totalComfort and playerData.ComfortNeed < totalComfort-increaseRate*3 then
				addComf = addComf+increaseRate*3
				mult = 3
			elseif playerData.ComfortNeed*1.5 < totalComfort and playerData.ComfortNeed < totalComfort-increaseRate*2 then
				addComf = addComf+increaseRate*2
				mult = 2
			else
				addComf = addComf+increaseRate
			end
		end
	end
	
	addComf = math.max(-decreaseRate*2,math.min(increaseRate*2,addComf))
	local comfNeedMax = 1
	if SandboxVars.LSComfort.ComfortPositive then comfNeedMax = 0.5; end
	playerData.ComfortNeed = math.max(0, math.min(comfNeedMax, playerData.ComfortNeed+addComf))
	local moodle = "Comfort"
	if playerData.LSMoodles["Uncomfortable"].Value > 0 then moodle = "Uncomfortable"; end
	doComfortCalc(playerData.LSMoodles[moodle].Value, moodle, playerData.ComfortNeed, increaseRate, decreaseRate)
end

local function AdjustGeneralLSMoodles(thisPlayer, playerData)

	adjustComfortNeed(thisPlayer, playerData)

	local moodleData = playerData.LSMoodles

	local addStress, addUnhappiness, addBoredom, addDiscomfort = doMoodlesCalc(thisPlayer, moodleData)
	local moodList = {}
	if addBoredom ~= 0 then moodList["Boredom"] = {addBoredom, addBoredom < -4 or addBoredom > 4, false, true}; end
	if addUnhappiness ~= 0 then moodList["Unhappiness"] = {addUnhappiness, addUnhappiness < -4 or addUnhappiness > 4, false, true}; end
	if addStress ~= 0 then moodList["Stress"] = {addStress, addStress < -0.015 or addStress > 0.015, false, true}; end
	if addDiscomfort ~= 0 then moodList["Discomfort"] = {addDiscomfort, false, false, true}; end
	
	for k, v in pairs(moodList) do
		if not v[3] then -- refuses to add from isSet
			if not LSMoodHandler.PerMin[k] then
				LSMoodHandler.PerMin[k] = {v[1], v[2], v[3], v[4]}
				--LSUtil.debugPrint("AdjustGeneralLSMoodles, creating "..tostring(k).." with value "..tostring(v[1]))
			else
				LSMoodHandler.PerMin[k][1] = LSMoodHandler.PerMin[k][1]+v[1]
				--LSUtil.debugPrint("AdjustGeneralLSMoodles, adding to "..tostring(k).." with value "..tostring(v[1]))
			end
		end
	end
	
	--LSUtil.changeCharacterMoodGroup(thisPlayer, moodList)
end

local changeAnimRollWait = 0

local function ChangeSitOrLieAnimation(thisPlayer, playerData)

	if true then return; end -- disabling this for now

	if thisPlayer:hasTimedActions() then return; end

	if not playerData.IsSittingOnSeat then playerData.IsSittingOnSeatSouth = false; return; end

	local currentBoredom = LSUtil.getCharacterMood(thisPlayer, "Boredom")
	local currentUnhappiness = LSUtil.getCharacterMood(thisPlayer, "Unhappiness")
	local currentStress = LSUtil.getCharacterMood(thisPlayer, "Stress")
	local currentExhaustion = LSUtil.getCharacterMood(thisPlayer, "Endurance")
	local currentFatigue = LSUtil.getCharacterMood(thisPlayer, "Fatigue")

	--local ListSitAnim = {"N","IsLegAbove","IsACLegAbove","IsLeanForward","IsACCrossLegForward","IsACCrossLegBehind","IsArmsCrossed"}
	--local ListSitAnimStressed = {}
	--local ListSitAnimBored = {}
	--local ListSitAnimDepressed = {}
	--local ListSitAnimEmbarrassed = {}
	--local idxSitAnim = ZombRand(7) + 1
	
	local changeAnimRoll = ZombRand(100) + 1
	
	if changeAnimRoll > 40 then
		if changeAnimRollWait >= 1 then
			changeAnimRollWait = changeAnimRollWait - 1
		else
		
			local SitAnimations = require("Properties/Anim/SitAnimations")
	
			local ListSitAnim = {}

				for k,v in pairs(SitAnimations) do
					if v.range == "full" and v.common == 1 then
						table.insert(ListSitAnim, v)
					end
					if v.range == "full" and v.common == 0 and v.bored == 1 and currentBoredom > 30 then
						table.insert(ListSitAnim, v)
					end
					if v.range == "full" and v.common == 0 and v.depressed == 1 and currentUnhappiness > 30 then
						table.insert(ListSitAnim, v)
					end
					if v.range == "full" and v.common == 0 and v.exhausted == 1 and currentExhaustion < 0.6 then
						table.insert(ListSitAnim, v)
					end
					if v.range == "full" and v.common == 0 and v.stressed == 1 and currentStress > 0.4 then
						table.insert(ListSitAnim, v)
					end
					if v.range == "full" and v.common == 0 and v.tired == 1 and currentFatigue > 0.4 then
						table.insert(ListSitAnim, v)
					end
					if v.range == "full" and v.common == 0 and v.embarrassed == 1 and playerData.LSMoodles["Embarrassed"].Value >= 0.2 then
						table.insert(ListSitAnim, v)
					end
				end

			local idxSitAnim = ZombRand(#ListSitAnim) + 1
			local sitAnim
			if playerData.IsSittingOnSeatSouth then
				sitAnim = ListSitAnim[idxSitAnim].animS
			else
				sitAnim = ListSitAnim[idxSitAnim].anim
			end
			
			thisPlayer:setVariable("SittingToggleLoop", sitAnim)
			if isClient() then
				ScanForPlayers("ChangeAnimVar", {"SittingToggleLoop", sitAnim})
				--sendClientCommand("LS", "ChangeAnimVar", {thisPlayer:getDisplayName(), "SittingToggleLoop", sitAnim})
			end
			--if ListSitAnim[idxSitAnim].common == 0 then

			local emotion = "none"

			if ListSitAnim[idxSitAnim].bored == 1 and currentBoredom > 30 then
				emotion = "Bored"
			elseif ListSitAnim[idxSitAnim].depressed == 1 and currentUnhappiness > 30 then
				emotion = "Depressed"
			elseif ListSitAnim[idxSitAnim].embarrassed == 1 and playerData.LSMoodles["Embarrassed"].Value > 0.4 then
				emotion = "Embarrassed"
			elseif ListSitAnim[idxSitAnim].tired == 1 and currentFatigue > 0.4 then
				emotion = "Tired"
			end

			if emotion ~= "none" then

				local PlayerVoice = playerData.PlayerVoice
				local PlayerVoiceTracks = require("TimedActions/PlayerVoiceTracks")

				local AvailablePlayerVoiceTracks = {}

				-- we loop the voice tracks and select the ones that we want, making sure to only select the ones that match the player voice
				for k,v in pairs(PlayerVoiceTracks) do
					if v.Voice == PlayerVoice and
					v.Type == emotion then
						table.insert(AvailablePlayerVoiceTracks, v)
					end
				end			

				local randomLine = ZombRand(#AvailablePlayerVoiceTracks) + 1
				local randomTrack = AvailablePlayerVoiceTracks[randomLine]
				local voiceSound = randomTrack.sound
				local voiceSoundF = randomTrack.soundF

				local dice20 = ZombRand(20) + 1
				if dice20 >= 6 then
					if thisPlayer:getDescriptor():isFemale() then
						thisPlayer:getEmitter():playSound(voiceSoundF);
					else
						thisPlayer:getEmitter():playSound(voiceSound);
					end
				end
			end
			--end
			changeAnimRollWait = 3
		end
	end

end

local function PlayerCreateDirt(thisPlayer, playerData)

	if thisPlayer and not thisPlayer:isPlayerMoving() and
	((not thisPlayer:hasTimedActions()) or (thisPlayer:isReading())) then
	return; end

	local hasDirt
	local hasBlood
	local totalDirt = 0
	local totalBlood = 0
	local visual = thisPlayer:getHumanVisual()
	for i = 1, BloodBodyPartType.MAX:index() do
        local part = BloodBodyPartType.FromIndex(i - 1)
        local Blood = visual:getBlood(part)
        local Dirt = visual:getDirt(part)

		if Blood > 0 then
			--hasBlood = true
			totalBlood = totalBlood + Blood
		end
		if Dirt > 0 then
			--hasDirt = true
			totalDirt = totalDirt + Dirt
		end
    end

	--float goes from 0 to 17 (each body part can add up to 1)
	if totalBlood > 5 then--blood gets priority over dirt
		hasBlood = true
	elseif totalDirt > 3 then--dirt has a lower threshold than blood as it's easier to clean and won't consume resources besides water/soap
		hasDirt = true
	end
			
	local MainLitterList = require("Properties/LitterTypes")
	local thisCategory = "grime"

	local dirtChance = 2
	local dirtSprite = "overlay_grime_floor_01_15"--backup option
	local dirtSolid = 2---1 is solid, 2 is overlay

	if hasBlood then
		dirtChance = 4
		thisCategory = "blood"
	elseif hasDirt then
		dirtChance = 4
	end

	if thisPlayer:isDriving() then
		dirtChance = 30
		thisCategory = "grime"
	elseif thisPlayer:isSprinting() then
		dirtChance = dirtChance + 4

	elseif thisPlayer:isRunning() then
		dirtChance = dirtChance + 2

	end

	if thisPlayer:hasTrait(CharacterTrait.SLOPPY) then
		dirtChance = dirtChance + 2
	elseif thisPlayer:hasTrait(CharacterTrait.TIDY) then
		dirtChance = dirtChance - 2
	end

	if (thisPlayer:isReading() or (playerData.PlayingInstrument and thisPlayer:isSitOnGround()) or playerData.IsMeditating or LS_DJBooth.isPlaying) and not thisPlayer:isDriving() then
		dirtChance = 0
	end

	local dirtRoll = ZombRand(180) + 1

	if dirtRoll <= dirtChance then

		local LitterList = {}

		for k,v in pairs(MainLitterList) do
			if v.category == thisCategory then
				table.insert(LitterList, v)
			end
		end

		local randomNumber = ZombRand(#LitterList) + 1
		local randomSprite = LitterList[randomNumber]
		dirtSprite = randomSprite.name

		local x = thisPlayer:getX()
		local y = thisPlayer:getY()
		local z = thisPlayer:getZ()
		if isClient() then
			sendClientCommand("LS", "DebugAddLitter", {x, y, z, dirtSolid, dirtSprite})
		else
			LSAddLitter(x, y, z, dirtSolid, dirtSprite)
		end
	end
end

local function doArtValueCalc(thisPlayer, artVal, beautyValue)
	if artVal == 0 or not SandboxVars.Text.DividerArt then return beautyValue; end
	local multiplier = SandboxVars.LSArt.ArtworkBeautyMultiplier or 1 -- sandbox option
	--if thisPlayer:hasTrait(CharacterTrait.HATESART) then return beautyValue-((artVal/4)*multiplier); 
	if thisPlayer:hasTrait(CharacterTrait.ARTISTIC) then return beautyValue+((artVal*1.5)*multiplier); end
	return beautyValue+(artVal*multiplier)
end

local function doTrashValueCalc(thisPlayer, val)
	if val == 0 or not SandboxVars.Text.DividerHygiene then return val; end
	if thisPlayer:hasTrait(CharacterTrait.SLOPPY)then val = val*0.5; elseif thisPlayer:hasTrait(CharacterTrait.CLEANFREAK) then val = val*3; end
	return val
end

local function doFlyBuzzSound(thisPlayer, playerData, val)
	if thisPlayer:isOutside() or val < 500 or ZombRand(20) ~= 1 then return; end
	playerData.doFliesSound = playerData.doFliesSound or 0
	if playerData.doFliesSound > 0 then playerData.doFliesSound = playerData.doFliesSound-1; return; end
	getSoundManager():playUISound("UI_FliesBuzz"); playerData.doFliesSound = 7
end

local function getArtValue(Art, baseValue)
	if (not Art) or (not instanceof(Art, "IsoObject")) or (not Art:hasModData()) or (not Art:getModData().movableData) or (not Art:getModData().movableData['artBeauty']) then return baseValue; end
	--[[
	local facing = getFacing(Art)
	local attachedObj = getFullArt(Art, facing)
	local beautyVal = Art:getModData().movableData['artBeauty']
	if beautyVal ~= 0 and attachedObj then beautyVal = beautyVal/2; end
	return beautyVal
	]]--
	return Art:getModData().movableData['artBeauty']
end

local function getBeautyValue(square, beautyValue, trashValue, artValue)
	for i = 0,square:getObjects():size()-1 do
		local object = square:getObjects():get(i)
		if object then
			local attachedsprite, objName, overlayName = object:getAttachedAnimSprite(), false, false		
			objName = object:getTextureName()
			if object:getOverlaySprite() then overlayName = object:getOverlaySprite():getName(); end
			if attachedsprite then
				for n=1,attachedsprite:size() do
					local sprite = attachedsprite:get(n-1)
					if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() then
						local newValue, isTrash, isArt = getBeautyProperty(sprite:getParentSprite():getName(), true)
						if isTrash then trashValue = trashValue+newValue;
						elseif not isArt then beautyValue = beautyValue+newValue; end
					end
				end
			end
			if objName then
				local newValue, isTrash, isArt = getBeautyProperty(objName, false)
				if isTrash then trashValue = trashValue+newValue;
				elseif isArt then artValue = artValue+getArtValue(object, newValue); 
				else beautyValue = beautyValue+newValue; end
			end
			if overlayName then
				local newValue, isTrash, isArt = getBeautyProperty(overlayName, true)
				if isTrash then trashValue = trashValue+newValue;
				elseif not isArt then beautyValue = beautyValue+newValue; end
			end
		end
	end
	return trashValue, beautyValue, artValue
end

local function PlayerDoBeautyCheck(thisPlayer, playerData)

	--local howDirty = 0-----0 for not dirty; 1 for dirty; 2 for very dirty -- old system
	local beautyValue, trashValue, artValue = 0, 0, 0 -- goes from 0 to +200 (higher values change beauty need faster)  -- calc for trash, add to beautyValue later / calc for art - separate for trait stuff
	local mult = SandboxVars.LSArt.GeneralBeautyMultiplier or 1
	local sourceSquare = getCell():getGridSquare(thisPlayer:getX(),thisPlayer:getY(),thisPlayer:getZ())
	if not sourceSquare then return; end
	for x = thisPlayer:getX()-8,thisPlayer:getX()+8 do
		for y = thisPlayer:getY()-8,thisPlayer:getY()+8 do
			local square = getCell():getGridSquare(x,y,thisPlayer:getZ())
			if square and square:IsOnScreen() and (sourceSquare:isOutside() == square:isOutside()) and square:getRoom() == sourceSquare:getRoom() then
				if square:haveBlood() and (thisPlayer:isOutside() == square:isOutside()) then trashValue = trashValue-(math.ceil(20*mult)); end
				if square:getDeadBody() and (thisPlayer:isOutside() == square:isOutside()) then trashValue = trashValue-(math.ceil(80*mult)); end
				trashValue, beautyValue, artValue = getBeautyValue(square, beautyValue, trashValue, artValue)
				
				--[[for i = 0,square:getObjects():size()-1 do------------------------------------
					local object = square:getObjects():get(i)
					if object and (thisPlayer:isOutside() == object:getSquare():isOutside()) then
						local attachedsprite, objName = object:getAttachedAnimSprite(), false								
						if object:getTextureName() then objName = object:getTextureName();
						elseif object:getOverlaySprite() and object:getOverlaySprite():getName() then objName = object:getOverlaySprite():getName();
						elseif attachedsprite then
							for n=1,attachedsprite:size() do
								local sprite = attachedsprite:get(n-1)
								if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() then objName = sprite:getParentSprite():getName(); end
							end
						end
						if objName then
							local newValue, isTrash, isArt = getBeautyProperty(objName)
							if isTrash then trashValue = trashValue+newValue;
							elseif isArt then artValue = artValue+getArtValue(object); 
							else beautyValue = beautyValue+newValue; end
						end
					end
				end]]--
			end
		end
	end
	trashValue = doTrashValueCalc(thisPlayer, trashValue)
	doFlyBuzzSound(thisPlayer, playerData, trashValue)
	beautyValue = doArtValueCalc(thisPlayer, artValue, beautyValue)
	beautyValue = math.ceil(beautyValue+trashValue)
	adjustBeautyNeed(thisPlayer, playerData, beautyValue, trashValue, artValue)
	--AdjustDirtLSMoodle(thisPlayer, playerData, bodyDamage, stats, currentBoredom, currentUnhappiness, currentStress, howDirty)
	
end

local function couchPotatoLogic(character, charData)
	if character:hasTrait(CharacterTrait["DISCIPLINED"]) then return; end
	charData.LSDLT = charData.LSDLT or {}
	charData.LSDLT['CouchPotato'] = charData.LSDLT['CouchPotato'] or {}
	local potatoData = charData.LSDLT['CouchPotato']
	potatoData.outHours = potatoData.outHours or 0
	local num = 1/60
	if not character:isOutside() then num = -num; elseif not character:isPlayerMoving() then num = 1/120; end
	potatoData.outHours = math.max(-1500,math.min(700,potatoData.outHours+num))
end

function LSEveryMinute()
	local character = LSUtil.getValidCharacter(getPlayer())
	if not character or not character:hasModData() then return; end
	local playerData = character:getModData()
	if not playerData then return; end
	local updateData
	if not playerData.LSMoodles then updateData = true; LSMoodleManager.init(character); end
	if not playerData.Ambitions then updateData = true; LSAmbtMng.onCreatePlayer(character:getPlayerNum(), character); end
	if not playerData.LSClothes then updateData = true; LSWardrobeContextMenu.getWardrobeData(); end

	if isClient() and updateData then sendClientCommand(character, "LS", "SavePlayerData", {playerData}); end

	local bodyDamage = character:getBodyDamage()

	---functions that play regardless of player asleep state
	AdjustGeneralLSMoodles(character, playerData)
	if SandboxVars.Text.DividerHygiene then--HYGIENE
		AdjustBladderNeed(character, playerData, bodyDamage)
		AdjustHygieneNeed(character, playerData)
	end
	if SandboxVars.Text.DividerMeditationNew and (playerData.LSMoodles["MindfulState"].Value > 0 or (playerData.MindfulnessMinutes and playerData.MindfulnessMinutes > 0)) then--MEDITATION MINDFULNESS
		AdjustPlayerMindfulness(character)
	end
	---
	--- when player is asleep following functions won't play
	if character:isAsleep() then return; end

	LS_NeuralHat.check(character, playerData)

	ChangeSitOrLieAnimation(character, playerData)
	if SandboxVars.Text.DividerMusicNew then
		RefreshItemToolTip(character)
	end

	if SandboxVars.Text.DividerHygiene or SandboxVars.Text.DividerArt then
		PlayerDoBeautyCheck(character, playerData)
	elseif (playerData.LSMoodles["BeautyGood"] and playerData.LSMoodles["BeautyGood"].Value > 0) or (playerData.LSMoodles["BeautyNeg"] and playerData.LSMoodles["BeautyNeg"].Value > 0) then
		playerData.BeautyNeed = 50; playerData.LSMoodles["BeautyGood"].Value = 0; playerData.LSMoodles["BeautyNeg"].Value = 0
	end

	--- when player is moving inside
	if not character:isOutside() and not character:isInvisible() and (character:isPlayerMoving() or character:isRunning() or character:isSprinting()) then
		if SandboxVars.Text.DividerHygiene then
			PlayerCreateDirt(character, playerData)
		end
	end
					
	if SandboxVars.LS.DynamicTraits then
		couchPotatoLogic(character, playerData)
	end

	if ls_PerkUpdate and ls_PerkUpdate.str_cache then
		local perkName = ls_PerkUpdate.str_cache
		local cached = ls_PerkUpdate.perk_cache[perkName]
		if not cached then
			ls_PerkUpdate.str_cache = nil
		else
			local count = math.floor(cached[1]-1)
			ls_PerkUpdate.perk_cache[perkName][1] = count
			if count == 3 then
				if ls_PerkUpdate['onLvlUp_'..perkName] then
					ls_PerkUpdate['onLvlUp_'..perkName](character, cached[2])
				else
					ls_PerkUpdate['onLvlUp_General'](character, cached[2], perkName)
				end
			elseif count <= 0 then
				ls_PerkUpdate.str_cache = nil
			end
		end
	end

	--if isClient() then sendClientCommand(character, "LS", "SavePlayerData", {character:getModData()}); end
end

Events.EveryOneMinute.Add(LSEveryMinute);