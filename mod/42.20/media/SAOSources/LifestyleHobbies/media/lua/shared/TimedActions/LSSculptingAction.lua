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

LSSculptingAction = ISBaseTimedAction:derive("LSSculptingAction");

local function getRepeatSplashSpriteTable(sprite, alphaStage)
	local t = {
		LS_Sculptures_26 = {stage1="LS_Sculptures_32",stage2="LS_Sculptures_40",stage3="LS_Sculptures_48"},
		LS_Sculptures_27 = {stage1="LS_Sculptures_33",stage2="LS_Sculptures_41",stage3="LS_Sculptures_49"},
		LS_Sculptures_28 = {stage1="LS_Sculptures_34",stage2="LS_Sculptures_42",stage3="LS_Sculptures_50"},
		LS_Sculptures_29 = {stage1="LS_Sculptures_35",stage2="LS_Sculptures_43",stage3="LS_Sculptures_51"},
		LS_Sculptures_30 = {stage1="LS_Sculptures_36",stage2="LS_Sculptures_44",stage3="LS_Sculptures_52"},
		LS_Sculptures_31 = {stage1="LS_Sculptures_37",stage2="LS_Sculptures_45",stage3="LS_Sculptures_53"},
	}
	return t[sprite]['stage'..tostring(alphaStage)]
end

local function getSplashSpriteTable()
	return {"LS_Sculptures_26","LS_Sculptures_27","LS_Sculptures_28","LS_Sculptures_29","LS_Sculptures_30","LS_Sculptures_31"}
end

local function getNewSplashSprite(oldSprite)
	local t = getSplashSpriteTable()
	for n=1, #t do
		if t[n] == oldSprite then table.remove(t, n); break; end
	end
	return t[ZombRand(#t)+1]
end

local function getAndStopSound(character, sound, soundL)
	if sound and (sound ~= 0) and character:getEmitter():isPlaying(sound) then character:getEmitter():stopSound(sound); end
	if soundL and (soundL ~= 0) and character:getEmitter():isPlaying(soundL) then character:getEmitter():stopSound(soundL); end
end

local function adjustStats(character, artwork, xp)

	local PlayerArtLevel = character:getPerkLevel(Perks.Art)
	
	if artwork["size"] == "medium" then xp[1] = xp[1]*2; xp[2] = xp[2]*2;
	elseif artwork["size"] == "large" then xp[1] = xp[1]*3; xp[2] = xp[2]*3; end

	if artwork["level"] > 1 then xp[1] = xp[1]*artwork["level"]; xp[2] = xp[2]*artwork["level"]; end

	--DEFINES
	--local boredomChange, stressChange, unhappynessChange, neckPainChange, xpChange = adjustStatsGetChanges(Aversion, Buffer, varResult, currentPain, WasTaught, PlayerMeditationLevel)
	LSUtil.changeCharacterMood(character, "Boredom", -1, false, false)
	
	local xpChange = (ZombRand(xp[1],xp[2]))/10
	if (xpChange > 0) and (PlayerArtLevel < 10) then
		sendClientCommand(character, "LS", "AddXP", {"Art", xpChange})
		--character:getXp():AddXP(Perks.Art, xpChange)
	end
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

local function updateArtworkSprite(station, newSprite, stage, newProgress)
	station:getModData().stage = stage
	if stage < 4 then station:getModData().progress = newProgress; end
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{station:getX(),station:getY(),station:getZ(),station:getSprite():getName()}, newSprite})
		sendClientCommand("LS", "ModifyObjData", {{station:getX(),station:getY(),station:getZ(),station:getSprite():getName()}, false, station:getModData()})
	else
		station:setOverlaySprite(newSprite, true)
	end
end

local function shouldUpdateWork(station, artwork, currentDuration, jobProgress, stage)
	if stage == 4 then return; end
	local currentProgress = currentDuration - jobProgress
	local val = 0
	if currentProgress < 0 then
		val = 100
	elseif artwork and artwork.duration and currentProgress then
		local realProgress = artwork.duration - currentProgress
		val = LSUtil.getPercentage(artwork.duration,realProgress, 2, false)
	end
	
	if val < 5 then return; end
	
	if (val >= 25) and (stage == 0) then updateArtworkSprite(station, artwork["stage1"], 1, currentProgress);
	elseif (val >= 50) and (stage == 1) then updateArtworkSprite(station, artwork["stage2"], 2, currentProgress);
	elseif (val >= 75) and (stage == 2) then updateArtworkSprite(station, artwork["stage3"], 3, currentProgress);
	elseif (val >= 100) then updateArtworkSprite(station, artwork["result"], 4);
	end
end

function LSSculptingAction:isValid()
	return true;
end

function LSSculptingAction:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.station);
	return self.character:shouldBeTurning();
end

local function getMetalSwitch(soundLoopName, workItems)
	local anim, sound, item1, item2 = "Bob_Sculpt_Metal_", "BlowTorch", workItems['item1'], workItems['item2']
	if soundLoopName == sound then anim, sound, item1, item2 = "Bob_Sculpt_MetalB_", "Hammering_METAL", workItems['item2'], false; end
	return anim, sound, item1, item2
end

local function getPropaneUses(item)
	return item and item:getCurrentUsesFloat() > 0
end

function LSSculptingAction:update()

	if not self.station:getModData().style then self:forceStop(); end -- Ice Melt
	if self.station:getModData().stage == 4 then self:forceComplete(); end
	self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)

	if self.animChangeCount > self.animChangeTotal then
		self.animChangeCount = 0
		if self.currentState == "Wait" then self.currentState = "Action"; self.animChangeTotal = 15+ZombRand(10); self.countS = self.countTotalS;
		elseif self.currentState == "Action" then
			self.currentState = "Wait"; self.animChangeTotal = 2+ZombRand(3);
		end
		if self.isMetal and (self.currentState == "Action") then
			self.animName, self.soundLoopName, self.handItem1, self.handItem2 = getMetalSwitch(self.soundLoopName, self.workItems)
		elseif self.isMetal and (self.currentState == "Wait") then
			getAndStopSound(self.character, self.sound, false)
		end
	end

	if self.count >= self.countTotal then
		if self.character:isSitOnGround() then self:forceStop(); end
		self.count = 0
		if self.isMetal and (self.currentState == "Action") and (self.animChangeCount == 0) then
			self:setOverrideHandModels(self.handItem1, self.handItem2)
			if self.soundLoopName == "BlowTorch" then
				if not getPropaneUses(self.item) then self:forceStop(); end
				self.sound = self.character:getEmitter():playSound(self.soundLoopName)
				LSUtil.useItem(self.item, self.character, self.chance)
			end
		end
		self.animChangeCount = self.animChangeCount+1
		self:setActionAnim(self.animName..self.currentState)
		self.countS = self.countS+1
		if self.countS >= self.countTotalS then
			self.countS = 0
			if self.soundTable and (self.currentState ~= "Wait") then
				if self.isMetal then
					if self.soundLoopName == "Hammering_METAL" then self.sound = self.character:getEmitter():playSound(self.soundLoopName); end
				else
					self.soundName = getNewSound(self.soundName, self.soundTable)
					self.sound = self.character:getEmitter():playSound(self.soundName)
				end
			end
		end
		if self.currentState == "Action" then shouldUpdateWork(self.station, self.artwork, self.maxTime, self.jobProgress, self.station:getModData().stage); 
		else getAndStopSound(self.character, self.sound, false); end
		
		adjustStats(self.character, self.artwork, {0,4})

		self.objAlpha = math.floor(self.objAlpha+1)

		if self.objAlpha < 4 then
			--self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],self.objAlpha)
			local repeatSprite = getRepeatSplashSpriteTable(self.splashSprite, self.objAlpha)
			self.splashObj:setSprite(repeatSprite)
			self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],1)
		elseif self.currentState == "Action" then
			self.splashSprite = getNewSplashSprite(self.splashSprite)
			self.splashObj:setSprite(self.splashSprite)
			self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],1)
			self.objAlpha = 0
		end

	end
	
	self.jobProgress = self:getJobDelta()*self.maxTime
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

local function getStyleParams(style)
	local styleParams = {
		Hedge = {anim = "Bob_Sculpt_Hedge_", soundTime = 4, splashColor = {0, 0.4, 0.1}, soundLoop = "Chainsaw_LOOP", soundTable = {"Chainsaw_Cut1","Chainsaw_Cut2","Chainsaw_Cut3","Chainsaw_Cut4","Chainsaw_Cut5"}},
		Wood  = {anim = "Bob_Sculpt_Wood_", soundTime = 3, splashColor = {1, 0.8, 0.5}, soundLoop = false, soundTable = {"Chisel_WOOD1","Chisel_WOOD2","Chisel_WOOD3","Chisel_WOOD4","Chisel_WOOD5","Chisel_WOOD6"}},
		Metal = {anim = "Bob_Sculpt_Metal_", soundTime = 3, splashColor = {0.6, 0.6, 0.6}, soundLoop = "BlowTorch", soundTable = "Hammering_METAL"},
		Ice   = {anim = "Bob_Sculpt_Hedge_", soundTime = 4, splashColor = {0.9, 0.96, 1}, soundLoop = "Chainsaw_LOOP", soundTable = {"Chainsaw_Cut1","Chainsaw_Cut2","Chainsaw_Cut3","Chainsaw_Cut4","Chainsaw_Cut5"}},
		Stone = {anim = "Bob_Sculpt_Wood_", soundTime = 3, splashColor = {0.8, 0.8, 0.8}, soundLoop = false, soundTable = {"Chisel_STONE1","Chisel_STONE2","Chisel_STONE3","Chisel_STONE4","Chisel_STONE5","Chisel_STONE6","Chisel_STONE7","Chisel_STONE8"}},
	}
	local params = styleParams[style] or {}
	return params.anim or "Bob_Sculpt_Wood_", params.soundTime or 15, params.splashColor or {1, 1, 1}, params.soundLoop or false, params.soundTable
end

local function getPropItem()
	local prop
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and item:getFullName() and ((item:getFullName() == "Chainsaw") or (item:getFullName() == "Lifestyle.Chainsaw")) then
			prop = item:InstanceItem(item:getFullName())
			break
        end
    end
	return prop
end

local function getSpecialItem(style)
	local hasSI = {Hedge=1,Ice=1}
	return hasSI[style] or false
end

local function getHandItems(artwork, workItems)
	local h1, h2, specialItem = workItems['item1'], workItems['item2'], getSpecialItem(artwork.style)
	if specialItem then h1, h2 = getPropItem(), false; end
	return h1, h2
end

function LSSculptingAction:start()
	self.handItem1, self.handItem2 = getHandItems(self.artwork, self.workItems)
	self.isMetal = self.artwork.style and self.artwork.style == "Metal"
	self.animName, self.countTotalS, self.splashColor, self.soundLoopName, self.soundTable = getStyleParams(self.artwork.style)
	self.countS = self.countTotalS
	if self.isMetal then self.item = self.workItems['item1']; self.chance = LSArt.getUseChance(self.character, 30); end
	if self.soundLoopName and (not self.isMetal) then self.soundLoop = self.character:getEmitter():playSound(self.soundLoopName); end
	self:setOverrideHandModels(self.handItem1, self.handItem2)
	self:setActionAnim(self.animName.."Action")
	
	self.splashObj = IsoObject.new(self.tileSqr, self.splashSprite)
	self.splashObj:setCustomColor(self.splashColor[1],self.splashColor[2],self.splashColor[3],1)
	self.tileSqr:AddTileObject(self.splashObj)
	--self.useDelta = getUseDelta(self.character)
end

function LSSculptingAction:stop()
	self.station:getModData().progress = (self.maxTime - self.jobProgress)
	if isClient() then
		sendClientCommand("LS", "ModifyObjData", {{self.station:getX(),self.station:getY(),self.station:getZ(),self.station:getSprite():getName()}, false, self.station:getModData()})
	else
		self.tileSqr:transmitRemoveItemFromSquare(self.splashObj)
	end
	self.tileSqr:RemoveTileObject(self.splashObj)
	
	getAndStopSound(self.character, self.sound, self.soundLoop)
	
    ISBaseTimedAction.stop(self);		
end

local function getPerformSound(quality, isKnownArtwork)
	local sound = "UI_Painting_Complete"
	if quality == "IGUI_PaintingQuality_Masterpiece" then
		local soundTable = {"UI_Masterpiece1","UI_Masterpiece2","UI_Masterpiece3"}
		sound = soundTable[ZombRand(#soundTable)+1]
	elseif not isKnownArtwork then
		sound = "UI_Artwork_New"
	end
	return sound
end

local function cleanString(name)
	local cleanedString = name:gsub("[%(%)]", "")
	local capitalizedString = cleanedString:gsub("^%l", string.upper)
	return capitalizedString
end

local function getTextRGB(quality)
	-- quality is the part after IGUI_PaintingQuality_, eg: quality from "IGUI_PaintingQuality_Awful" is "Awful"
	local qualityRGBS = {
		Awful = " <RGB:0.5,0.2,0.2>",  -- Dull red to represent poor effort or outcome
		Poor = " <RGB:1,0.7,0.7>",    -- Pale red, indicating slight improvement but still lackluster
		Shoddy = " <RGB:0.9,0.6,0.3>",-- Rusty orange, conveying mediocrity with effort
		Normal = " <RGB:0.7,0.7,1>",  -- Soft blue, average and calming
		Good = " <RGB:0.5,0.9,0.5>",  -- Bright green, suggesting decent quality and satisfaction
		Excellent = " <RGB:0.3,0.8,1>", -- Vibrant cyan, showing high quality and appeal
		Impressive = " <RGB:0.6,0.4,1>", -- Deep violet, evoking awe and admiration
		Wondrous = " <RGB:1,0.8,0.2>", -- Golden yellow, symbolizing rarity and brilliance
		Masterpiece = " <RGB:1,1,0.5>"  -- Radiant light yellow, glowing with perfection
    }
	return qualityRGBS[quality] or " <RGB:0.7,1,0.7>"
end

local function doNote(character, quality, artworkTexture, isKnownArtwork)
	local qualityText = cleanString(getText(quality))
	local qualityRGB = getTextRGB(qualityText)
	local newText = " "
	if not isKnownArtwork then newText = getText("IGUI_Artwork_New").." - "; end
	local noteText = "_NoteText"
	if ZombRand(2)+1 == 2 then noteText = "_NoteText_Alt"; end
	local text = newText..getText(quality..noteText).." <LINE>".."<CENTRE> "..getText("IGUI_PaintingQuality")..": ".." <SPACE>"..qualityRGB..qualityText
	--local notePanel = LSNote:new(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, "artwork", artworkTexture, 5, false})
	--notePanel:initialise()
	--notePanel:addToUIManager()
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, false, artworkTexture, 5, false})
end

function LSSculptingAction:perform()
	local resultSpriteName = self.artwork["result"]
	updateArtworkSprite(self.station, resultSpriteName, 4)
	adjustStats(self.character, self.artwork, {50,150})
	getAndStopSound(self.character, self.sound, self.soundLoop)
	if not self.character:getModData()['KnownArtworkList'] then self.character:getModData()['KnownArtworkList'] = {}; end
	local isKnownArtwork = self.character:getModData()['KnownArtworkList'][resultSpriteName]
	local soundName = getPerformSound(self.artwork["quality"], isKnownArtwork)
	getSoundManager():playUISound(soundName)

	if not isKnownArtwork then
		self.character:getModData()['KnownArtworkList'][resultSpriteName] = true
		LSSync.updateClientData(self.character, self.character:getModData())
	end

	if not isClient() then self.tileSqr:transmitRemoveItemFromSquare(self.splashObj); end
	self.tileSqr:RemoveTileObject(self.splashObj)

	doNote(self.character, self.artwork["quality"], resultSpriteName, isKnownArtwork)

	ISBaseTimedAction.perform(self);
end

function LSSculptingAction:complete()

	return true
end

function LSSculptingAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function LSSculptingAction:new(character, station, artwork, actionTime, workItems)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.station = station
	o.artwork = artwork
	o.actionTime = actionTime
	o.workItems = workItems
	o.ignoreDynamicTime = true;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.count = 0
	o.countTotal = 15
	o.countS = 0
	o.countTotalS = 15
	o.animChangeCount = 0
	o.animChangeTotal = 3
	o.currentState = "Action"
	o.animName = "Bob_Sculpt_Wood_"
	o.sound = 0
	o.soundLoop = 0
	o.soundTable = false
	o.soundName = false
	o.splashObj = false
	o.splashColor = false
	o.splashSprite = "LS_Sculptures_26"
	o.tileSqr = o.station:getSquare()
	o.objAlpha = 0
	o.isMetal = false
	o.soundLoopName = false
	o.handItem1 = false
	o.handItem2 = false
	o.item = false
	o.useDelta = 3
	o.oldUseDelta = false
	return o;
end
