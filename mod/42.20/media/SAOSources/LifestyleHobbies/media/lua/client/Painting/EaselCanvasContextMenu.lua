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

EaselCanvasContextMenu = {};

local function getCanvasSize(spriteName)
	if (spriteName == "LS_Painting_50") or (spriteName == "LS_Painting_51") then return "large"; end
	if (spriteName == "LS_Painting_2") or (spriteName == "LS_Painting_3") then return "medium"; end
	if (spriteName == "LS_Painting_26") or (spriteName == "LS_Painting_27") then return "small"; end
	return false
end

local function getPaintItemsLoot(thisPlayer, ItemName)

	local Item
	local containerList = ArrayList.new();
	local playerNum = thisPlayer and thisPlayer:getPlayerNum() or -1
    for i,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end

	for i=0,containerList:size()-1 do
		local container = containerList:get(i);
		for x=0,container:getItems():size() - 1 do
			local v = container:getItems():get(x);
			if not Item and (v:getType() == ItemName) then
				Item = v
				break
			end
		end
	end

	return Item

end

local function getPaintItems(thisPlayer)

	local it = thisPlayer:getInventory():getItems()
	local itemNameList = {{id=false,name="oldPaintBrush"}, {id=false,name="paintPalette"}}
	local item

	for j = 0, it:size()-1 do
		item = it:get(j);
		for k, v in pairs(itemNameList) do
			if (not v.id) and (v.name == item:getType()) then
				v.id = item
				break
			end
		end
	end

	for k, v in pairs(itemNameList) do
		if not v.id then
			v.id = getPaintItemsLoot(thisPlayer, v.name)
		end
	end

	return itemNameList[1].id, itemNameList[2].id
end

local function canPaint(thisPlayer, Easel)
	if thisPlayer:getVehicle() or thisPlayer:hasTimedActions() or thisPlayer:getModData().IsSittingOnSeat or
	thisPlayer:isSitOnGround() then return false; end
	if Easel:getModData().stage and (Easel:getModData().stage >= 4) then return false; end
	--if Easel:getModData().author and (Easel:getModData().author ~= (thisPlayer:getDescriptor():getForename().." "..thisPlayer:getDescriptor():getSurname())) then return false; end

	return true
end

local function getPaintingProgress(Progress, Painting)
	local val = 0
	local rgbColor = " <RGB:1,0,0>"

	if Progress and Progress < 0 then
		val = 100
	elseif Painting and Painting.duration and Progress then -- Progress is the value of work that still has to be done, not the value of work that was done
		local realProgress = Painting.duration - Progress
		if realProgress > 0 then val = LSUtil.getPercentage(Painting.duration,realProgress, 2, false); end
	end

	if (val > 30) and (val < 60) then
		rgbColor = " <RGB:1,1,0>"
	elseif val > 60 then
		rgbColor = " <RGB:0,1,0>"
	end
	return rgbColor, val
end

local function getNewTooltip(description)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	return tooltip
end

local function isAuthor(Easel, thisPlayer)
	if (not Easel:hasModData()) or (not Easel:getModData().author) then return true; end
	if Easel:getModData().author and (Easel:getModData().author ~= (thisPlayer:getDescriptor():getForename().." "..thisPlayer:getDescriptor():getSurname())) then return false; end
	return true
end

local function disableOption(option, description, texture)
	option.notAvailable = true
	option.toolTip = getNewTooltip(description)
	option.iconTexture = getTexture('media/ui/'..texture..'.png')
end

local function isCanvasSizeUnavalaibleForPlayer(thisPlayer, spriteName, numbM, numbL)
	local size = getCanvasSize(spriteName)
	if not size then return true; end
	if size == "small" then return false;
	elseif (size ~= "small") and thisPlayer:getPerkLevel(Perks.Art) < numbM then return true;
	elseif (size == "large") and thisPlayer:getPerkLevel(Perks.Art) < numbL then return true; end
	return false
end

local function doPaintSimpleOption(context, worldobjects, Easel, thisPlayer, spriteName, paintItems)
	
	--if isCanvasSizeUnavalaibleForPlayer(thisPlayer, spriteName)
	
	local paintSimpleOption = context:addOptionOnTop(getText("ContextMenu_Painting_PaintSimple"),
	worldobjects,
	EaselCanvasContextMenu.onPaintAction,
	thisPlayer,
	Easel,
	spriteName,
	paintItems,
	"simple")

	paintSimpleOption.toolTip = getNewTooltip(getText("Tooltip_Painting_Simple"))
	paintSimpleOption.iconTexture = getTexture('media/ui/artpalette_icon.png')
end

local function doPaintOption(context, worldobjects, Easel, thisPlayer, spriteName, paintItems)

	local paintOptionText = "ContextMenu_Painting_Paint"
	if thisPlayer:getPerkLevel(Perks.Art) < 2 then paintOptionText = "ContextMenu_Painting_PracticePaint"; end
	
	local canPaint = true
	
	local paintOption = context:addOptionOnTop(getText(paintOptionText),
	worldobjects,
	EaselCanvasContextMenu.onPaintAction,
	thisPlayer,
	Easel,
	spriteName,
	paintItems,
	"normal")

	local progressRGB, progressVal = getPaintingProgress(Easel:getModData().progress, Easel:getModData().painting)
	paintOption.toolTip = getNewTooltip(getText("Tooltip_Painting_Progress").." <SPACE>"..progressRGB..progressVal.." <RGB:1,1,1>".."<SPACE>"..getText(" / 100 %%"))
	paintOption.iconTexture = getTexture('media/ui/artpalette_icon.png')

	if (not isAuthor(Easel, thisPlayer)) then
		disableOption(paintOption, getText("Tooltip_Painting_Disable_Author")..": "..Easel:getModData().author, "artpaletteNo_icon")
		canPaint = false
	elseif (not paintItems) or (paintItems and ((not paintItems.brush) or (not paintItems.palette))) then
		disableOption(paintOption, getText("Tooltip_Painting_Disable_Item"), "artpaletteNo_icon")
		canPaint = false
	elseif isCanvasSizeUnavalaibleForPlayer(thisPlayer, spriteName, 2, 5) then
		disableOption(paintOption, getText("Tooltip_Painting_Disable_Size"), "artpaletteNo_icon")
		canPaint = false
	end
	
	if canPaint and (not Easel:getModData().painting) and (thisPlayer:getPerkLevel(Perks.Art) >= 7) and (not isCanvasSizeUnavalaibleForPlayer(thisPlayer, spriteName, 2, 9)) then
		doPaintSimpleOption(context, worldobjects, Easel, thisPlayer, spriteName, paintItems)
	end

end

local function doAppraiseOption(context, worldobjects, Easel, thisPlayer)
	local appraiseOptionText, precision = "ContextMenu_Painting_Appraise", "low"
	local progressRGB, progressVal = getPaintingProgress(Easel:getModData().progress, Easel:getModData().painting)
	if progressVal > 75 then precision = "high"; elseif progressVal > 50 then precision = "medium"; end
	
	local appraiseOption = context:addOptionOnTop(getText(appraiseOptionText),
	worldobjects,
	EaselCanvasContextMenu.onAppraiseAction,
	thisPlayer,
	Easel,
	precision)
	
	local cooldown = thisPlayer:getModData().LSCooldowns['brushmaster']
	if cooldown and (cooldown > 0) then disableOption(appraiseOption, getText("Tooltip_Action_Cooldown").." <SPACE>".." <RGB:1,1,0>"..cooldown.." <SPACE>"..getText("IGUI_Gametime_hours"), "LSBrushmasterNo_icon"); return; end
	if progressVal < 25 then disableOption(appraiseOption, getText("Tooltip_Painting_Appraise_No"), "LSBrushmasterNo_icon"); return; end
	if progressVal >= 100 then disableOption(appraiseOption, getText("Tooltip_Painting_Appraise_No_Complete"), "LSBrushmasterNo_icon"); return; end
	appraiseOption.toolTip = getNewTooltip(getText("Tooltip_Painting_Progress").." <SPACE>"..progressRGB..progressVal.." <RGB:1,1,1>".."<SPACE>"..getText(" / 100 %%").." <LINE>".." <LINE>"
	.." <RGB:1,1,1>"..getText("Tooltip_Painting_Appraise")..":"..progressRGB.." <SPACE>"..getText("Tooltip_Painting_Appraise_"..precision))
	appraiseOption.iconTexture = getTexture('media/ui/LSBrushmaster_icon.png')
	--write the action call function, use gussy up as a base for timed action
end

local function doGetPaintOption(context, worldobjects, Easel, thisPlayer, spriteName)

	local getPaintingOption = context:addOptionOnTop(getText("ContextMenu_Painting_GetPainting"),
	worldobjects,
	EaselCanvasContextMenu.onRemoveCanvas,
	thisPlayer,
	Easel,
	spriteName,
	true)
	getPaintingOption.toolTip = getNewTooltip(getText("Tooltip_Painting_GetFinishedWork"))
	getPaintingOption.iconTexture = getTexture('media/ui/arttake_icon.png')

end

local function canAppraise(thisPlayer, Easel)
	local brushmaster = (LSAmbtMng and LSAmbtMng.hasCompleted(thisPlayer, "LSBrushmaster"))
	if brushmaster and Easel:getModData().progress and Easel:getModData().painting then return true; end
	return false
end

EaselCanvasContextMenu.doBuildMenu = function(player, context, worldobjects, Easel, spriteName, customName, groupName, DebugBuildOption)
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    if (thisPlayer:getVehicle()) or (thisPlayer:hasTimedActions()) then return; end
	
	if not Easel then return; end

	local removeCanvasOption = context:addOptionOnTop(getText("ContextMenu_Painting_RemoveCanvas"),
	worldobjects,
	EaselCanvasContextMenu.onRemoveCanvas,
	thisPlayer,
	Easel,
	spriteName,
	false)
	removeCanvasOption.toolTip = getNewTooltip(getText("Tooltip_Painting_DiscardCanvas").." - ".." <RGB:1,0,0>"..getText("Tooltip_Painting_DiscardWarning"))
	removeCanvasOption.iconTexture = getTexture('media/ui/artdiscard_icon.png')

	if canAppraise(thisPlayer, Easel) then
		doAppraiseOption(context, worldobjects, Easel, thisPlayer)
	end
	

	if Easel:getModData().stage and (Easel:getModData().stage >= 4) then doGetPaintOption(context, worldobjects, Easel, thisPlayer, spriteName);
	elseif canPaint(thisPlayer, Easel) then
		local paintItems = {}
		paintItems.brush, paintItems.palette = getPaintItems(thisPlayer)
		doPaintOption(context, worldobjects, Easel, thisPlayer, spriteName, paintItems)
	end

end

EaselCanvasContextMenu.walkToFront = function(thisPlayer, thisObject)

	local frontSquare = nil
	local controllerSquare = nil
	local spriteName = thisObject:getSprite():getName()
	if not spriteName then
		return false
	end

	local properties = thisObject:getSprite():getProperties()
	
	local facing = nil
	if properties:has("Facing") then
		facing = properties:get("Facing")
	else
		return
	end
	
	if facing == "S" then
		frontSquare = thisObject:getSquare():getS()
	elseif facing == "E" then
		frontSquare = thisObject:getSquare():getE()
	elseif facing == "W" then
		frontSquare = thisObject:getSquare():getW()
	elseif facing == "N" then
		frontSquare = thisObject:getSquare():getN()
	end
	
	if not frontSquare then
		return false
	end
	
	if not controllerSquare then
		controllerSquare = thisObject:getSquare()
	end

	if AdjacentFreeTileFinder.privTrySquare(controllerSquare, frontSquare) then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
		return true
	end
	return false
end

local function getNewSpriteName(spriteName)
	if (spriteName == "LS_Painting_2") or (spriteName == "LS_Painting_26") or (spriteName == "LS_Painting_50") then return "LS_Painting_0"; end
	if (spriteName == "LS_Painting_3") or (spriteName == "LS_Painting_27") or (spriteName == "LS_Painting_51") then return "LS_Painting_1"; end
	return false
end

EaselCanvasContextMenu.onRemoveCanvas = function(worldobjects, player, Easel, spriteName, getPainting)
	if EaselCanvasContextMenu.walkToFront(player, Easel) then
		local newEasel = getNewSpriteName(spriteName)
		if not newEasel then return; end
		ISTimedActionQueue.add(LSCanvasAction:new(player, Easel, newEasel, getPainting))
	end
end

local function getEaselFacing(easel)
	local facing
	local properties = easel:getSprite():getProperties()
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	return facing
end

local function getRandomLevelChance(minNumb, maxNumb)
	--here we get a table based on artlevel to randomize in another function
	--each level adds their values, repeating by their level - so level 1 is included once, level 2 is included twice and so forth...
	--increases the odds of getting a painting your level (or closer to your level)
	local randomNumbers = {}
	if minNumb == 0 then table.insert(randomNumbers, 0); end
	for n=1, maxNumb do
		if n >= minNumb then
			for j=1, n do
				table.insert(randomNumbers, n)
			end
		end
	end
	return randomNumbers
end

local function getMinMaxNumb(artLevel, paintingOption)
	if not paintingOption then return 0, artLevel; end
	if paintingOption == "simple" then return 2, math.floor(artLevel-4);----------simple option is available starting from level 7
	elseif paintingOption == "normal" then
		local minNumb = math.floor(artLevel-3)
		if minNumb < 0 then minNumb = 0; end
		return minNumb, artLevel; 
	end
	return 0, artLevel
end

local function getPaintingLevel(artLevel, paintingOption, size)
	if artLevel == 0 then return 0; end
	local minNumb, maxNumb = getMinMaxNumb(artLevel, paintingOption)
	if (size == "medium") and (minNumb < 2) then minNumb = 2; elseif (size == "large") and (minNumb < 5) then minNumb = 5; end
	local randomNumbers = getRandomLevelChance(minNumb, maxNumb)
	return randomNumbers[ZombRand(#randomNumbers)+1]
end

local function getPaintingsTable(artLevel, facing, size, qualityNumb, paintingLevel)
	--local paintingLevel = getPaintingLevel(artLevel, paintingOption)
	local t = require("Painting/lib/PaintingLibrary"..tostring(paintingLevel)..facing)
	local newTable = {}
	for k, v in ipairs(t) do
		if (v.level == paintingLevel) and (v.size == size) and ((v.style ~= "Masterpiece") or (qualityNumb == 3)) then
			table.insert(newTable, v)
		end
	end
	return newTable
end

local function getSizeMultiplier(size)
	local sizeMultipliers = {small=1,medium=6,large=12}
	return sizeMultipliers[size] or 1
end

local function getNewPaintingDuration(characterLevel, character, paintingLevel, size)
	local sizeMult = getSizeMultiplier(size)
	local brushmaster = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSBrushmaster"))
	local playerLevel = math.floor(characterLevel/2)
	if brushmaster then playerLevel = math.ceil(playerLevel*1.5); end
	return (((10000*sizeMult)+(paintingLevel*12000))-(playerLevel*1000*(sizeMult/2)))
end

local function getQualityFromRandomNumb(randomNumb)
	if randomNumb == 1.2 then return "IGUI_PaintingQuality_Good"; elseif randomNumb == 1.5 then return "IGUI_PaintingQuality_Excellent"; elseif randomNumb == 1.8 then return "IGUI_PaintingQuality_Impressive"; elseif randomNumb == 2.2 then return "IGUI_PaintingQuality_Wondrous"; elseif randomNumb == 3 then return "IGUI_PaintingQuality_Masterpiece";
	elseif randomNumb == 0.6 then return "IGUI_PaintingQuality_Awful"; elseif randomNumb == 0.7 then return "IGUI_PaintingQuality_Poor"; elseif randomNumb == 0.8 then return "IGUI_PaintingQuality_Shoddy"; end
	return "IGUI_PaintingQuality_Normal"
end

local function getBaseRandomNumbersFromSize(size)
	local randomNumbers, n = {}, 20
	if size == "small" then n = n*3; elseif size == "medium" then n = n*2; end
	for i=1, n do table.insert(randomNumbers, 1); end
	return randomNumbers
end

local function getRandomNumbersChance(character, characterLevel, paintingLevel, paintingOption, paintingSize)
	--local randomNumbers = {0.7, 0.8, 0.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.1, 1.2, 1.3, 1.4, 1.5}
	--local randomNumbers = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	local randomNumbers = getBaseRandomNumbersFromSize(paintingSize)
	local n = 1
	if paintingSize == "small" then n = 3; elseif paintingSize == "medium" then n = 2; end--small and medium canvas are less likely to produce masterpieces
	local masterpainter = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSMasterPainter"))
	local t = require("Painting/Quality")
	for k, v in ipairs(t) do
		if (v.level == characterLevel) and (((paintingOption == "normal") and (paintingLevel >= 8)) or (v.numb ~= 3)) then--Masterpieces can't occur if option is simple and paintingLevel is lesser than 8
			local repeatChance = v.chance
			if masterpainter and (v.numb >= 2.2) then repeatChance = 3;
			elseif repeatChance > 1 then repeatChance = repeatChance*n; end
			for i=1, repeatChance do table.insert(randomNumbers, v.numb); end
			
		end
	end
	
	return randomNumbers
end

local function getBeautyRandomVar(character, characterLevel, paintingLevel, paintingOption, paintingSize)
	if characterLevel == 0 then return 0.6; elseif characterLevel == 1 then return 0.7; end
	local randomNumbers = getRandomNumbersChance(character, characterLevel, paintingLevel, paintingOption, paintingSize)
	return randomNumbers[ZombRand(#randomNumbers)+1]
end

local function getPaintingBeauty(beautyQualityNumb, painting)
	local beauty, quality = 0, "IGUI_PaintingQuality_Awful"
	if painting.level == 0 then return beauty, quality; elseif painting.level == 1 then return 1, "IGUI_PaintingQuality_Poor"; end
	if painting.size == "small" then beauty = 2*painting.level; elseif painting.size == "medium" then beauty = 4*painting.level; elseif painting.size == "large" then beauty = 6*painting.level; end
	if painting.style == "Masterpiece" then beauty = beauty*3; quality = "IGUI_PaintingQuality_Masterpiece";
	elseif beautyQualityNumb == 1 then return beauty, "IGUI_PaintingQuality_Normal";
	elseif painting.level >= 2 then if beautyQualityNumb > 1 then beauty = math.ceil(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); elseif beautyQualityNumb < 1 then beauty = math.floor(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); end; end;

	return beauty, quality
end

local function getNewPainting(character, easel, spriteName, paintingOption)
	--local paintingLib = getPaintingsTable(character, character:getPerkLevel(Perks.Art))
	local facing = getEaselFacing(easel)
	local size = getCanvasSize(spriteName)
	local paintingLevel = getPaintingLevel(character:getPerkLevel(Perks.Art), paintingOption, size)
	local beautyQualityNumb = getBeautyRandomVar(character, character:getPerkLevel(Perks.Art), paintingLevel, paintingOption, size)
	local paintingLib = getPaintingsTable(character:getPerkLevel(Perks.Art), facing, size, beautyQualityNumb, paintingLevel)
	local newPainting = paintingLib[ZombRand(#paintingLib)+1]
	newPainting.beauty, newPainting.quality = getPaintingBeauty(beautyQualityNumb, newPainting)
	newPainting.duration = getNewPaintingDuration(character:getPerkLevel(Perks.Art), character, newPainting.level, size)
	return newPainting, 0, newPainting.duration, character:getDescriptor():getForename().." "..character:getDescriptor():getSurname()
end

local function doTransferItem(player, itemA)

	local Cont = false

	if instanceof(itemA, "InventoryItem") then
		if luautils.haveToBeTransfered(player, itemA) then
			Cont = itemA:getContainer()
			ISTimedActionQueue.add(ISInventoryTransferAction:new(player, itemA, itemA:getContainer(), player:getInventory()))
		end
	elseif instanceof(itemA, "ArrayList") then
		local items = itemA
		for i=1,items:size() do
			local item = items:get(i-1)
			if luautils.haveToBeTransfered(player, item) then
				Cont = item:getContainer()
				ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), player:getInventory()))
			end
		end
	end

	return Cont
end

EaselCanvasContextMenu.onPaintAction = function(worldobjects, player, Easel, spriteName, paintItems, paintingOption)
	if EaselCanvasContextMenu.walkToFront(player, Easel) then
		if not Easel:getModData().painting then
			Easel:getModData().painting, Easel:getModData().stage, Easel:getModData().progress, Easel:getModData().author = getNewPainting(player, Easel, spriteName, paintingOption)
			if isClient() then sendClientCommand("LS", "ModifyObjData", {{Easel:getX(),Easel:getY(),Easel:getZ(),Easel:getSprite():getName()}, false, Easel:getModData()}); end
		end
		paintItems.brushCont = doTransferItem(player, paintItems.brush)
		paintItems.paletteCont = doTransferItem(player, paintItems.palette)
		ISTimedActionQueue.add(LSCanvasPaintingAction:new(player, Easel, Easel:getModData().painting, Easel:getModData().progress, paintItems))
	end
end

EaselCanvasContextMenu.onAppraiseAction = function(worldobjects, player, Easel, precision)
	if EaselCanvasContextMenu.walkToFront(player, Easel) then
		ISTimedActionQueue.add(LSCanvasAppraiseAction:new(player, Easel, Easel:getModData().painting, precision))
	end
end