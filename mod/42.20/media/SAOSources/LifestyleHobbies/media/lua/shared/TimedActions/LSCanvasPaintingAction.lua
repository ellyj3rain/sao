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

LSCanvasPaintingAction = ISBaseTimedAction:derive("LSCanvasPaintingAction");

local function adjustStats(character, painting, xp)

	local PlayerArtLevel = character:getPerkLevel(Perks.Art)

	if painting["size"] == "medium" then xp[1] = xp[1]*2; xp[2] = xp[2]*2;
	elseif painting["size"] == "large" then xp[1] = xp[1]*3; xp[2] = xp[2]*3; end

	if painting["level"] > 1 then xp[1] = xp[1]*painting["level"]; xp[2] = xp[2]*painting["level"]; end

	--DEFINES
	LSUtil.changeCharacterMood(character, "Boredom", -1, false, false)
	
	local xpChange = (ZombRand(xp[1],xp[2]))/10
	if (xpChange > 0) and (PlayerArtLevel < 10) then
		sendClientCommand(character, "LS", "AddXP", {"Art", xpChange})
		--character:getXp():AddXP(Perks.Art, xpChange)
	end
end

local function getNewPalette(thisPlayer)
	local it = thisPlayer:getInventory():getItems()
	local item, newPalette
	for j = 0, it:size()-1 do
		item = it:get(j);
		if item and (item:getType()) and (item:getType() == "paintPalette") then newPalette = item; break; end
	end
	return newPalette
end

local function shouldChangePaintSound(character, sound)
	if sound and sound ~= 0 then
		if character:getEmitter():isPlaying(sound) then return false; end
	end
	return true
end

local function getSoundTable(state)
	if state == "Paint" then
		return {"Easel_Paint1","Easel_Paint2","Easel_Paint3","Easel_Paint4","Easel_Paint5"}
	end

	return {"Easel_Brush1","Easel_Brush2","Easel_Brush3","Easel_Brush4","Easel_Brush5"}
end

local function getNewSound(state, oldSound)
	local audioTable = getSoundTable(state)
	if oldSound then
		for n=1, #audioTable do
			if audioTable[n] == oldSound then table.remove(audioTable, n); break; end
		end
	end

	return audioTable[ZombRand(#audioTable)+1]
end

local function getEaselFacing(easel)
	local facing
	local properties = easel:getSprite():getProperties()
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	return facing
end

local function getMarkingSpriteName(easel, size)
	local facing = getEaselFacing(easel)
	local t = LSArt.Markings[facing]
	local newTable
	for k, v in ipairs(t) do
		if v.size == size then
			newTable = v.sprites
		end
	end
	return newTable[ZombRand(#newTable)+1]
end

local function updateCanvasSprite(easel, newSprite, stage, newProgress)
	if stage == 0.5 then newSprite = getMarkingSpriteName(easel, newSprite); end
	easel:getModData().stage = stage
	if stage < 4 then easel:getModData().progress = newProgress; end
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{easel:getX(),easel:getY(),easel:getZ(),easel:getSprite():getName()}, newSprite})
		sendClientCommand("LS", "ModifyObjData", {{easel:getX(),easel:getY(),easel:getZ(),easel:getSprite():getName()}, false, easel:getModData()})
	else
		easel:setOverlaySprite(newSprite, isClient())
	end
end

local function shouldUpdateCanvas(easel, painting, currentDuration, jobProgress, stage)
	if stage == 4 then return; end
	local val = 0
	local currentProgress = currentDuration - jobProgress
	if currentProgress < 0 then
		val = 100
	elseif painting and painting.duration and currentProgress then
		local realProgress = painting.duration - currentProgress
		val = LSUtil.getPercentage(painting.duration,realProgress, 2, false)
	end

	if val < 5 then return; end
	
	if (val >= 1) and (stage == 0) then updateCanvasSprite(easel, painting["size"], 0.5, currentProgress);
	elseif (val >= 25) and (stage == 0.5) then updateCanvasSprite(easel, painting["stage1"], 1, currentProgress);
	elseif (val >= 50) and (stage == 1) then updateCanvasSprite(easel, painting["stage2"], 2, currentProgress);
	elseif (val >= 75) and (stage == 2) then updateCanvasSprite(easel, painting["stage3"], 3, currentProgress);
	elseif (val >= 100) then updateCanvasSprite(easel, painting["stage4"], 4);
	end
end

function LSCanvasPaintingAction:isValid()
	return true;
end

function LSCanvasPaintingAction:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.easel);
	return self.character:shouldBeTurning();
end

local function paintPaletteHasUses(palette)
	--if palette:getCurrentUses() and (palette:getCurrentUses() > 0) then return true; end
	if palette:isInPlayerInventory() then return true; end
	return false
end

function LSCanvasPaintingAction:update()

	if self.easel:getModData().stage == 4 then self:forceComplete(); end
	self.count = self.count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	
	if self.animChangeCount > self.animChangeTotal then
		self.animChangeCount = 0
		if self.currentState == "Paint" then self.currentState = "Brush"; self.animChangeTotal = 15+ZombRand(10);
		elseif self.currentState == "Brush" then
			if not paintPaletteHasUses(self.paintItems.palette) then
				self.paintItems.palette = getNewPalette(self.character)
				if not self.paintItems.palette then self:forceStop(); end
			end
			self.currentState = "Paint"; self.animChangeTotal = 2+ZombRand(3);
		end
	end

	if self.count >= self.countTotal then
		if self.character:isSitOnGround() then self:forceStop(); end
		self.count = 0
		self.animChangeCount = self.animChangeCount+1
		
		self.soundName = getNewSound(self.currentState, self.soundName)
		self.sound = self.character:getEmitter():playSound(self.soundName)
		self:setActionAnim("Bob_Easel_"..self.currentState)

		if self.currentState == "Brush" then shouldUpdateCanvas(self.easel, self.painting, self.maxTime, self.jobProgress, self.easel:getModData().stage);
		else LSUtil.useItem(self.paintItems.palette, self.character, self.chance);
		end
		
		adjustStats(self.character, self.painting, {0,4})
	end
	self.jobProgress = self:getJobDelta()*self.maxTime
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function LSCanvasPaintingAction:start()
	self:setOverrideHandModels(self.paintItems.brush, self.paintItems.palette)
	self:setActionAnim("Bob_Easel_Paint")
	self.chance = LSArt.getUseChance(self.character, 20)
end

function LSCanvasPaintingAction:stop()
	self.easel:getModData().progress = (self.maxTime - self.jobProgress)
	if isClient() then sendClientCommand("LS", "ModifyObjData", {{self.easel:getX(),self.easel:getY(),self.easel:getZ(),self.easel:getSprite():getName()}, false, self.easel:getModData()}); end

    ISBaseTimedAction.stop(self);		
end

local function getPerformSound(quality)
	local sound = "UI_Painting_Complete"
	if quality == "IGUI_PaintingQuality_Masterpiece" then
		local soundTable = {"UI_Masterpiece1","UI_Masterpiece2","UI_Masterpiece3"}
		sound = soundTable[ZombRand(#soundTable)+1]
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

local function doNote(character, quality, paintingTexture)
	local qualityText = cleanString(getText(quality))
	local qualityRGB = getTextRGB(qualityText)
	local noteText = "_NoteText"
	if ZombRand(2)+1 == 2 then noteText = "_NoteText_Alt"; end
	local text = getText(quality..noteText).." <LINE>".."<CENTRE> "..getText("IGUI_PaintingQuality")..": ".." <SPACE>"..qualityRGB..qualityText
	--local notePanel = LSNote:new(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, "painting", paintingTexture, 5, false})
	--notePanel:initialise()
	--notePanel:addToUIManager()
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, false, paintingTexture, 5, false})
end

local function getPaintingTex(easel, painting)
	return painting["stage"..tostring(easel:getModData().stage)]
end

function LSCanvasPaintingAction:perform()
	updateCanvasSprite(self.easel, self.painting["stage4"], 4)
	adjustStats(self.character, self.painting, {50,150})
	local soundName = getPerformSound(self.painting["quality"])
	getSoundManager():playUISound(soundName)

	local paintingTexture = getPaintingTex(self.easel, self.painting)
	doNote(self.character, self.painting["quality"], paintingTexture)

	ISBaseTimedAction.perform(self);
end

function LSCanvasPaintingAction:complete()

	return true
end

function LSCanvasPaintingAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.actionTime
end

function LSCanvasPaintingAction:new(character, easel, painting, actionTime, paintItems)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.easel = easel
	o.painting = painting
	o.paintItems = paintItems
	o.actionTime = actionTime
	o.ignoreDynamicTime = true;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.count = 0
	o.countTotal = 15
	o.animChangeCount = 0
	o.animChangeTotal = 3
	o.currentState = "Paint"
	o.sound = 0
	o.soundName = false
	return o;
end
