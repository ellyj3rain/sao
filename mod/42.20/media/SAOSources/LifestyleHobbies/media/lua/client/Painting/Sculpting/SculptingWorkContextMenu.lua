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

SculptingWorkContextMenu = {};

local function getPropaneUses(item)
	return item and item:getCurrentUsesFloat() > 0
end

local function getWorkItemsLoot(thisPlayer, ItemName)

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
			if not Item and ((v:getType() == ItemName) or (v:hasTag(ItemTag[string.upper(ItemName)]))) and ((ItemName ~= "BlowTorch") or (getPropaneUses(v))) then
				Item = v
				break
			end
		end
	end

	return Item

end

local function getItemsTable()
	return {
	{style="Hedge",item1="Saw",item2=false,clothing=false},
	{style="Wood",item1="Hammer",item2="CarpentryChisel",clothing=false},
	{style="Stone",item1="Hammer",item2="MasonsChisel",clothing=false},
	{style="Metal",item1="BlowTorch",item2="Hammer",clothing="WeldingMask"},
	{style="Ice",item1="Saw",item2=false,clothing=false},
	}
end

local function getItemList(Station)
	local style, itemNameList, t = Station:getModData().style or "Wood", {{id=false,name=false}, {id=false,name=false}, {id=false,name=false}}, getItemsTable()
	for k, v in pairs(t) do
		if style == v.style then
			itemNameList[1].name = v.item1
			itemNameList[2].name = v.item2
			itemNameList[3].name = v.clothing
			break
		end
	end
	return itemNameList
end

local function getWorkItems(thisPlayer, Station)
	local itemNameList = getItemList(Station)
	local it = thisPlayer:getInventory():getItems()
	local item

	for j = 0, it:size()-1 do
		item = it:get(j);
		for k, v in pairs(itemNameList) do
			if (not v.id) and v.name and ((v.name == item:getType()) or (item:hasTag(ItemTag[string.upper(v.name)]))) and ((v.name ~= "BlowTorch") or (getPropaneUses(item))) then
				v.id = item
				break
			end
		end
	end

	local missingItems = {}
	for k, v in pairs(itemNameList) do
		if v.name and (not v.id) then
			v.id = getWorkItemsLoot(thisPlayer, v.name)
			if not v.id then table.insert(missingItems, v.name); end
		end
	end

	return itemNameList[1].id, itemNameList[2].id, itemNameList[3].id, missingItems
end

local function canWork(thisPlayer, Station)
	if thisPlayer:getVehicle() or thisPlayer:hasTimedActions() or thisPlayer:getModData().IsSittingOnSeat or
	thisPlayer:isSitOnGround() then return false; end
	if Station:getModData().stage and (Station:getModData().stage >= 4) then return false; end
	--if Easel:getModData().author and (Easel:getModData().author ~= (thisPlayer:getDescriptor():getForename().." "..thisPlayer:getDescriptor():getSurname())) then return false; end

	return true
end

local function getWorkProgress(Progress, Artwork)
	local val = 0
	local rgbColor = " <RGB:1,0,0>"

	if Progress and Progress < 0 then
		val = 100
	elseif Artwork and Artwork.duration and Progress then
		local realProgress = Artwork.duration - Progress
		if realProgress > 0 then val = LSUtil.getPercentage(Artwork.duration,realProgress, 2, false); end
	end
	if (val >= 30) and (val < 60) then
		rgbColor = " <RGB:1,1,0>"
	elseif val >= 60 then
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

local function isAuthor(Station, thisPlayer)
	if (not Station:hasModData()) or (not Station:getModData().author) then return true; end
	if Station:getModData().author and (Station:getModData().author ~= (thisPlayer:getDescriptor():getForename().." "..thisPlayer:getDescriptor():getSurname())) then return false; end
	return true
end

local function disableOption(option, description, texture)
	option.notAvailable = true
	option.toolTip = getNewTooltip(description)
	option.iconTexture = getTexture('media/ui/'..texture..'.png')
end

local function getSkillRequirements()
	return {
	{name="Hedge", skills={Perks.Art,3,Perks.Farming,6}},
	{name="Wood", skills={Perks.Art,4,Perks.Woodwork,4}},
	{name="Metal", skills={Perks.Art,6,Perks.MetalWelding,4}},
	{name="Stone", skills={Perks.Art,8}},
	{name="Ice", skills={Perks.Art,10}},
	}
end

local function isWorkTypeUnavalaibleForPlayer(thisPlayer, Station)
	local missingSkills, style, t = false, Station:getModData().style or "Wood", getSkillRequirements()
	for k, v in pairs(t) do
		if style == v.name then
			for n=1, #v.skills do
				if type(v.skills[n]) ~= "number" then
					if thisPlayer:getPerkLevel(v.skills[n]) < v.skills[n+1] then
						--local perkName = PerkFactory.getPerkName(v.skills[n])
						missingSkills = true
						break
					end
				end
			end
			break
		end
	end
	return missingSkills
end

local function getNewTooltip(description, texture, name)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	if texture then
		tooltip:setName(name)
		tooltip:setTexture(texture)
		tooltip.footNote = getText("Tooltip_Sculpting_FootNote")
	end
	return tooltip
end

local function getArtworkTable(artLevel, station, list, knownList)
	local style = station:getModData().style or "Wood"
	local t = require("Painting/Sculpting/lib/Sculpture_"..style)
	local newTable = {}
	for k, v in ipairs(t) do
		if (list or not v.parent) and v.level <= artLevel then
			table.insert(newTable, v)
			if knownList and not knownList[v.result] then
				table.insert(newTable, v)
			end
		end
	end
	return newTable
end

local function getMoveableDisplayName(spriteName)
    if (not spriteName) or (not getSprite(spriteName)) then return nil end
    local props = getSprite(spriteName):getProperties()
    if props:has("CustomName") then
        local name = props:get("CustomName")
        if props:has("GroupName") then
            name = props:get("GroupName") .. " " .. name
        end
        return Translator.getMoveableDisplayName(name)
    end
    return nil
end

local function doArtworkSubListOption(list, subMenu, worldobjects, Station, thisPlayer, workItems, parentArtwork)
	for k, v in pairs(list) do
		if (v.isparent and v.result == parentArtwork.result) or (v.parent and v.parent == parentArtwork.result) then
			local artName = getMoveableDisplayName(v.result)
			if artName then
				local option = subMenu:addOption(v.name,worldobjects,SculptingWorkContextMenu.onWorkAction,thisPlayer,Station,workItems,v.result, true)
				option.toolTip = getNewTooltip(getText("Tooltip_Sculpting_"..parentArtwork.result).." <RGB:0,1,0>".." <LINE><LINE>"..getText("Tooltip_Sculpting_B_"..parentArtwork.result), v.result, artName)
				local texture = getSprite(v.result):getTextureForCurrentFrame(IsoDirections.E)
				option.iconTexture = texture
			end
		end
	end
end

local function doArtworkListOption(context, worldobjects, Station, thisPlayer, workItems)
	
	local buildOption = context:addOptionOnTop(getText("ContextMenu_Sculpting_KnownList"))
	buildOption.iconTexture = getTexture('media/ui/artpalette_icon.png')
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)
	local hasArtwork

	local t = getArtworkTable(thisPlayer:getPerkLevel(Perks.Art), Station, true, false)
	for k, v in pairs(t) do
		if thisPlayer:getModData()['KnownArtworkList'][v.result] then
			hasArtwork = true
			local artName = getMoveableDisplayName(v.result)
			if artName then
				if v.isparent then
					local parentOption = subMenu:addOption(artName)
					local texture = getSprite(v.result):getTextureForCurrentFrame(IsoDirections.E)
					parentOption.iconTexture = texture
					local parentSubMenu = subMenu:getNew(subMenu);
					context:addSubMenu(parentOption, parentSubMenu)
					doArtworkSubListOption(t, parentSubMenu, worldobjects, Station, thisPlayer, workItems, v)
				elseif not v.parent then
					local option = subMenu:addOption(artName,worldobjects,SculptingWorkContextMenu.onWorkAction,thisPlayer,Station,workItems,v.result,false)
					option.toolTip = getNewTooltip(getText("Tooltip_Sculpting_"..v.result).." <RGB:0,1,0>".." <LINE><LINE>"..getText("Tooltip_Sculpting_B_"..v.result), v.result, artName)
					local texture = getSprite(v.result):getTextureForCurrentFrame(IsoDirections.E)
					option.iconTexture = texture
				end
			end
		end
	end

	if not hasArtwork then disableOption(buildOption, getText("Tooltip_ArtworkList_Empty"), "artpaletteNo_icon"); end
end

local function getItemDesc(thisPlayer, workItems, missingItems, bhs, ghs)
	local newLine = " "
	if workItems then
		for n=1, 3 do
			if workItems['item'..n] then
				newLine = newLine .. "<IMAGE:"..workItems['item'..n]:getTexture():getName()..",16,16>" .. ghs .. workItems['item'..n]:getName() .. " <LINE>";
			end
		end
	end
	if missingItems and (#missingItems > 0) then
		for n=1, #missingItems do
			local itemTex = LSUtil.getTexIcon(missingItems[n])
			newLine = newLine .. itemTex .. bhs .. Translator.getItemNameFromFullType("Base."..missingItems[n]) .. " <LINE>";
		end
	end
	return newLine
end

local function getSkillIconsTable(key)
	local t = {
		Art = "artpalette_icon",
		Farming = "naked_icon",
		Carpentry = "woodwork_icon",
		Metalworking = "metalwork_icon",
	}
	return t[key]
end

local function getSkillIcon(skillName)
	local icon = getSkillIconsTable(skillName)
	if not icon then return ""; end
	return "<IMAGE:media/ui/"..icon..".png,16,16>"
end

local function getSkillDesc(thisPlayer, style, bhs, ghs)
	local t = getSkillRequirements()
	local newLine = " "
	for k, v in pairs(t) do
		if style == v.name then
			for n=1, #v.skills do
				if type(v.skills[n]) ~= "number" then
					local perkName = PerkFactory.getPerkName(v.skills[n])
					local skillFullName = tostring(v.skills[n])
					local skillGlobalName = skillFullName:gsub("^Perks%.", "")
					local skillTex = getSkillIcon(skillGlobalName) or ""
					local color = ghs
					if thisPlayer:getPerkLevel(v.skills[n]) < v.skills[n+1] then color = bhs; end
					newLine = newLine .. skillTex .. color .. perkName .. " " .. tostring(thisPlayer:getPerkLevel(v.skills[n])) .. "/" .. tostring(v.skills[n+1]) .. " <LINE>";
				end
			end
			break
		end
	end
	return newLine
end

local function isMissingRequirements(thisPlayer, option, Station, workItems, missingItems)
	local style = Station:getModData().style or "Wood"
	local bhs = " <RGB:" .. getCore():getBadHighlitedColor():getR() .. "," .. getCore():getBadHighlitedColor():getG() .. "," .. getCore():getBadHighlitedColor():getB() .. "> "
	local ghs = " <RGB:" .. getCore():getGoodHighlitedColor():getR() .. "," .. getCore():getGoodHighlitedColor():getG() .. "," .. getCore():getGoodHighlitedColor():getB() .. "> "
	local tooltipDesc = getSkillDesc(thisPlayer, style, bhs, ghs)
	tooltipDesc = tooltipDesc .. getItemDesc(thisPlayer, workItems, missingItems, bhs, ghs)
	return tooltipDesc
end

local function doWorkOption(context, worldobjects, Station, thisPlayer, workItems, missingItems)


	local canWork = true
	
	local option = context:addOptionOnTop(getText("ContextMenu_Sculpting_Work"),
	worldobjects,
	SculptingWorkContextMenu.onWorkAction,
	thisPlayer,
	Station,
	workItems,
	"normal",
	false)

	local progressRGB, progressVal = getWorkProgress(Station:getModData().progress, Station:getModData().sculpture)
	option.toolTip = getNewTooltip(getText("Tooltip_Painting_Progress").." <SPACE>"..progressRGB..progressVal.." <RGB:1,1,1>".."<SPACE>"..getText(" / 100 %%"))
	option.iconTexture = getTexture('media/ui/artpalette_icon.png')

	if (not isAuthor(Station, thisPlayer)) then
		disableOption(option, getText("Tooltip_Painting_Disable_Author")..": "..Station:getModData().author, "artpaletteNo_icon")
		canWork = false
	elseif ((not workItems) or (workItems and (#missingItems > 0))) or isWorkTypeUnavalaibleForPlayer(thisPlayer, Station) then
		local tooltipDesc = isMissingRequirements(thisPlayer, option, Station, workItems, missingItems)
		disableOption(option, getText("Tooltip_craft_Needs") .. ": <LINE>" .. tooltipDesc, "artpaletteNo_icon")
		canWork = false
	end
	
	if canWork and thisPlayer:getModData()['KnownArtworkList'] and (not Station:getModData().sculpture) then
		doArtworkListOption(context, worldobjects, Station, thisPlayer, workItems)
	end
end

local function doAppraiseOption(context, worldobjects, Easel, thisPlayer)
	local appraiseOptionText, precision = "ContextMenu_Painting_Appraise", "low"
	local progressRGB, progressVal = getWorkProgress(Easel:getModData().progress, Easel:getModData().sculpture)
	if progressVal > 75 then precision = "high"; elseif progressVal > 50 then precision = "medium"; end
	
	local appraiseOption = context:addOptionOnTop(getText(appraiseOptionText),
	worldobjects,
	SculptingWorkContextMenu.onAppraiseAction,
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

local function doGetArtworkOption(context, worldobjects, Station, thisPlayer)

	local getArtworkOption = context:addOptionOnTop(getText("ContextMenu_Painting_GetPainting"),
	worldobjects,
	SculptingWorkContextMenu.onRemoveSculpture,
	thisPlayer,
	Station,
	true)
	getArtworkOption.toolTip = getNewTooltip(getText("Tooltip_Painting_GetFinishedWork"))
	getArtworkOption.iconTexture = getTexture('media/ui/arttake_icon.png')

end

local function canAppraise(thisPlayer, Easel)
	local brushmaster = (LSAmbtMng and LSAmbtMng.hasCompleted(thisPlayer, "LSBrushmaster"))
	if brushmaster and Easel:getModData().progress and Easel:getModData().painting then return true; end
	return false
end

SculptingWorkContextMenu.doBuildMenu = function(player, context, worldobjects, Station, spriteName, customName, groupName, DebugBuildOption)
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    if (thisPlayer:getVehicle()) or (thisPlayer:hasTimedActions()) then return; end
	
	if not Station then return; end

	local removeOption = context:addOptionOnTop(getText("ContextMenu_Artwork_Remove"),
	worldobjects,
	SculptingWorkContextMenu.onRemoveSculpture,
	thisPlayer,
	Station,
	false)
	removeOption.toolTip = getNewTooltip(getText("Tooltip_Artwork_Discard").." - ".." <RGB:1,0,0>"..getText("Tooltip_Painting_DiscardWarning"))
	removeOption.iconTexture = getTexture('media/ui/artdiscard_icon.png')

	if not Station:getModData().style then return; end -- Ice Melt

	--[[
	if canAppraise(thisPlayer, Station) then
		doAppraiseOption(context, worldobjects, Station, thisPlayer)
	end
	]]--


	if Station:getModData().stage and (Station:getModData().stage >= 4) then doGetArtworkOption(context, worldobjects, Station, thisPlayer);
	elseif canWork(thisPlayer, Station) then
		local workItems = {}
		workItems.item1, workItems.item2, workItems.item3, missingItems = getWorkItems(thisPlayer, Station)
		doWorkOption(context, worldobjects, Station, thisPlayer, workItems, missingItems)
	end
	
end

SculptingWorkContextMenu.walkToFront = function(thisPlayer, thisObject)
	if not thisObject then return false; end
	local controllerSquare = thisObject:getSquare()
	if not controllerSquare then return false; end
	local frontSquare = thisObject:getSquare():getS() or thisObject:getSquare():getE()
	if not frontSquare then return false; end
	if AdjacentFreeTileFinder.privTrySquare(controllerSquare, frontSquare) then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
		return true
	end
	return false
end

SculptingWorkContextMenu.onRemoveSculpture = function(worldobjects, player, Station, getArtwork)
	if SculptingWorkContextMenu.walkToFront(player, Station) then
		ISTimedActionQueue.add(LSSculptingNewAction:new(player, Station, 'LS_Sculptures_0', nil, false, false, getArtwork))
	end
end

local function getSizeMultiplier(size)
	local sizeMultipliers = {small=1,medium=6,large=12}
	return sizeMultipliers[size] or 1
end

local function getStyleDurationPenalty(style)
	local styleMultipliers = {Hedge=1,Wood=2,Metal=4,Ice=6,Stone=12}
	return styleMultipliers[style] or 1
end

local function getNewArtworkDuration(characterLevel, character, artworkLevel, size, style)
	local sizeMult = getSizeMultiplier(size)
	local brushmaster = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSBrushmaster"))
	local playerLevel = math.floor(characterLevel/2)
	local artworkStyle = getStyleDurationPenalty(style)
	if brushmaster then playerLevel = math.ceil(playerLevel*1.5); end
	return (((10000*sizeMult)+(artworkLevel*12000)+(artworkStyle*5000))-(playerLevel*1000*(sizeMult/2)))
end

local function getQualityFromRandomNumb(randomNumb)
	if randomNumb == 1.2 then return "IGUI_PaintingQuality_Good"; elseif randomNumb == 1.5 then return "IGUI_PaintingQuality_Excellent"; elseif randomNumb == 1.8 then return "IGUI_PaintingQuality_Impressive"; elseif randomNumb == 2.2 then return "IGUI_PaintingQuality_Wondrous"; elseif randomNumb == 3 then return "IGUI_PaintingQuality_Masterpiece";
	elseif randomNumb == 0.6 then return "IGUI_PaintingQuality_Awful"; elseif randomNumb == 0.7 then return "IGUI_PaintingQuality_Poor"; elseif randomNumb == 0.8 then return "IGUI_PaintingQuality_Shoddy"; end
	return "IGUI_PaintingQuality_Normal"
end

local function getBaseRandomNumbersFromStyle(style)
	local randomNumbers, n, multi = {}, 20, 1
	if (style == "Wood") or (style == "Hedge") then n = n*3; multi = 3; elseif (style == "Metal") then n = n*2; multi = 2; end
	for i=1, n do table.insert(randomNumbers, 1); end
	return randomNumbers, multi
end

local function getRandomNumbersChance(character, characterLevel, artworkLevel, style)
	--local randomNumbers = {0.7, 0.8, 0.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.1, 1.2, 1.3, 1.4, 1.5}
	--local randomNumbers = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	local randomNumbers, n = getBaseRandomNumbersFromStyle(style)
	local masterpainter = (LSAmbtMng and LSAmbtMng.hasActiveCompleted(character, "LSMasterPainter"))
	local t = require("Painting/Quality")
	for k, v in ipairs(t) do
		if (v.level == characterLevel) and ((artworkLevel >= 8) or (v.numb ~= 3)) then--Masterpieces can't occur if option is simple and artworkLevel is lesser than 8
			local repeatChance = v.chance
			if masterpainter and (v.numb >= 2.2) then repeatChance = 3;
			elseif repeatChance > 1 then repeatChance = repeatChance*n; end
			for i=1, repeatChance do table.insert(randomNumbers, v.numb); end
			
		end
	end
	return randomNumbers
end

local function getBeautyRandomVar(character, characterLevel, artworkLevel, style)
	if characterLevel == 0 then return 0.6; elseif characterLevel == 1 then return 0.7; end
	local randomNumbers = getRandomNumbersChance(character, characterLevel, artworkLevel, style)
	return randomNumbers[ZombRand(#randomNumbers)+1]
end

local function getArtworkBeauty(beautyQualityNumb, artwork)
	local beauty, quality = 0, "IGUI_PaintingQuality_Awful"
	if artwork.level == 0 then return beauty, quality; elseif artwork.level == 1 then return 1, "IGUI_PaintingQuality_Poor"; end
	if artwork.size == "small" then beauty = 2*artwork.level; elseif artwork.size == "medium" then beauty = 4*artwork.level; elseif artwork.size == "large" then beauty = 6*artwork.level; end
	if artwork.style == "Masterpiece" then beauty = beauty*3; quality = "IGUI_PaintingQuality_Masterpiece";
	elseif beautyQualityNumb == 1 then return beauty, "IGUI_PaintingQuality_Normal";
	elseif artwork.level >= 2 then if beautyQualityNumb > 1 then beauty = math.ceil(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); elseif beautyQualityNumb < 1 then beauty = math.floor(beauty*beautyQualityNumb); quality = getQualityFromRandomNumb(beautyQualityNumb); end; end;
	return beauty, quality
end

local function getArtworkFromList(artworkList, workOption)
	if workOption ~= "normal" then
		local artwork
		for n=1, #artworkList do
			if artworkList[n] and artworkList[n].result and (artworkList[n].result == workOption) then artwork = artworkList[n]; break; end
		end
		if artwork then return artwork; end
	end
	return artworkList[ZombRand(#artworkList)+1]
end

local function getNewArtwork(character, station, workOption, fullList)
	local sculptureLib = getArtworkTable(character:getPerkLevel(Perks.Art), station, fullList, character:getModData()['KnownArtworkList'])
	local newArtwork = getArtworkFromList(sculptureLib, workOption)
	local beautyQualityNumb = getBeautyRandomVar(character, character:getPerkLevel(Perks.Art), newArtwork.level, newArtwork.style)
	newArtwork.beauty, newArtwork.quality = getArtworkBeauty(beautyQualityNumb, newArtwork)
	newArtwork.duration = getNewArtworkDuration(character:getPerkLevel(Perks.Art), character, newArtwork.level, newArtwork.size, newArtwork.style)
	return newArtwork, 0, newArtwork.duration, character:getDescriptor():getForename().." "..character:getDescriptor():getSurname()
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

SculptingWorkContextMenu.onWorkAction = function(worldobjects, player, Station, workItems, workOption, fullList)
	if player:hasTimedActions() then return; end
	if SculptingWorkContextMenu.walkToFront(player, Station) then
		if not Station:getModData().sculpture then
			Station:getModData().sculpture, Station:getModData().stage, Station:getModData().progress, Station:getModData().author = getNewArtwork(player, Station, workOption, fullList)
			if isClient() then sendClientCommand("LS", "ModifyObjData", {{Station:getX(),Station:getY(),Station:getZ(),Station:getSprite():getName()}, false, Station:getModData()}); end
		end
		for n=1, 3 do
			if workItems['item'..n] then
				workItems['cont'..n] = doTransferItem(player, workItems['item'..n])
			end
		end
		if workItems['item3'] and (workItems['item3']:getCategory() == "Clothing") then
			ISTimedActionQueue.add(ISWearClothing:new(player, workItems['item3'], 50))
		end
		ISTimedActionQueue.add(LSSculptingAction:new(player, Station, Station:getModData().sculpture, Station:getModData().progress, workItems))
	end
end

SculptingWorkContextMenu.onAppraiseAction = function(worldobjects, player, Station, precision)
	if SculptingWorkContextMenu.walkToFront(player, Station) then
		ISTimedActionQueue.add(LSCanvasAppraiseAction:new(player, Station, Station:getModData().sculpture, precision))
	end
end