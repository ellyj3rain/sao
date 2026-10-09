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

ArtCardContextMenu = {};

local function predicateNotBroken(item)
	return not item:isBroken()
end

local function getSkillDesc(thisPlayer, frame, ghs, bhs)
	if thisPlayer:getPerkLevel(Perks.Woodwork) < frame.skill then
		return false, bhs .. getText("IGUI_perks_Carpentry") .. " " .. tostring(thisPlayer:getPerkLevel(Perks.Woodwork)) .. "/" .. tostring(frame.skill) .. " <LINE>";
	else
		return true, ghs .. getText("IGUI_perks_Carpentry") .. " " .. tostring(thisPlayer:getPerkLevel(Perks.Woodwork)) .. "/" .. tostring(frame.skill) .. " <LINE>";
	end
end

local function getMaterials(thisPlayer, frame, tooltip, option)

	local ghs = " <RGB:" .. getCore():getGoodHighlitedColor():getR() .. "," .. getCore():getGoodHighlitedColor():getG() .. "," .. getCore():getGoodHighlitedColor():getB() .. "> "
	local bhs = " <RGB:" .. getCore():getBadHighlitedColor():getR() .. "," .. getCore():getBadHighlitedColor():getG() .. "," .. getCore():getBadHighlitedColor():getB() .. "> "

	tooltip.description = tooltip.description .. "<LINE> <LINE>" .. getText("Tooltip_craft_Needs") .. ": <LINE>";

	for n=1, #frame.mats do
		if type(frame.mats[n]) == "string" then
			local mat = thisPlayer:getInventory():getItemCount(frame.mats[n], true);
			if (mat < frame.mats[n+1]) and (frame.mats[n+1] > 0) then
				tooltip.description = tooltip.description .. bhs .. getItemNameFromFullType(frame.mats[n]) .. " " .. mat .. "/" .. tostring(frame.mats[n+1]) .. " <LINE>";
				if not thisPlayer:isBuildCheat() then option.notAvailable = true; end
			elseif frame.mats[n+1] > 0 then
				tooltip.description = tooltip.description .. ghs .. getItemNameFromFullType(frame.mats[n]) .. " " .. mat .. "/" .. tostring(frame.mats[n+1]) .. " <LINE>";
			end
		end
	end

	local hasSkill, skillDesc = getSkillDesc(thisPlayer, frame, ghs, bhs)
	tooltip.description = tooltip.description .. skillDesc
	if (not hasSkill) and (not thisPlayer:isBuildCheat()) then option.notAvailable = true; end

	tooltip.description = tooltip.description .. " <TEXT> " .. "<LINE> <LINE>" .. getText("Tooltip_Painting_Frame_NoteA") .. " <LINE>";
	tooltip.description = tooltip.description .. getText("Tooltip_Painting_Frame_NoteB") .. " <LINE>";

	return tooltip
end

local function getNewTooltip(description, frame, arg)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	if frame then
		tooltip:setName(getText("ContextMenu_Painting_Frame_Cat"..tostring(arg[4])).." "..getText("ContextMenu_Painting_Frame_"..frame.name))
		tooltip:setTexture(frame['texture'..arg[1]])
		tooltip = getMaterials(arg[2], frame, tooltip, arg[3])
		tooltip.footNote = getText("Tooltip_Painting_Frame_FootNote")
	end
	return tooltip
end

local function disableOption(option, tooltipDescription, iconTexture)
	option.notAvailable = true
	option.toolTip = getNewTooltip(tooltipDescription, false, false)
	if iconTexture then option.iconTexture = getTexture(iconTexture); end
end

local function artCardLoadFrameSubOptions(worldobjects, thisPlayer, context, Art, facing, subMenu, newCat, index, hammerItem)
	local frameCat = subMenu:addOption(getText("ContextMenu_Painting_Frame_Cat"..tostring(index)))
	local catSubMenu = subMenu:getNew(subMenu);
	context:addSubMenu(frameCat, catSubMenu)

	local disable = true

	for k, frame in ipairs(newCat) do
		if Art:getModData().movableData['artSize'] == frame.size then
			local applyFrameOption = catSubMenu:addOption(getText("ContextMenu_Painting_Frame_"..frame.name),
			worldobjects,
			ArtCardContextMenu.onApplyFrame,
			thisPlayer,
			Art,
			frame['texture'..facing],
			frame['texture'..facing..'2'],
			frame,
			hammerItem,
			facing)
			applyFrameOption.toolTip = getNewTooltip(getText("Tooltip_Painting_Frame_"..frame.desc).." ", frame, {facing, thisPlayer, applyFrameOption, index})
			disable = false
		end
	end
	if disable then disableOption(frameCat, getText("Tooltip_Painting_Frame_CatNotAvailable"), false); end
end

local function getFacing(obj)
	local facing
	local properties = obj:getSprite():getProperties()
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	return facing
end

local function artCardDoFrameSubOptions(worldobjects, thisPlayer, context, Art, frameOption, hammerItem)

	local facing = getFacing(Art)
	if not facing then return; end

	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(frameOption, subMenu)

	for n=1, 3 do--number of frame cats
		local newCat = require("Painting/lib/FrameCat"..tostring(n))
		if newCat and (#newCat > 0) then
			artCardLoadFrameSubOptions(worldobjects, thisPlayer, context, Art, facing, subMenu, newCat, n, hammerItem)
		end
	end

end

local function checkInvForItem(player)
	local item
	local playerInv = player:getInventory()
	item = playerInv:getFirstTagEvalRecurse(ItemTag.HAMMER, predicateNotBroken)
	return item
end

local function debugIceAboutToMelt(worldobjects, IceObj)
	local movData = IceObj:getModData().movableData
	if not movData['meltStartTime'] or movData['meltStartTime'] < 50 then return; end
	movData['meltStartTime'] = 10
	LSSync.transmit(IceObj)
end

local function iceObjDebugOption(context, DebugBuildOption, Art)
	local debugMenu = DebugBuildOption:addOptionOnTop(getText("ContextMenu_LSDebug_Ice"))
	local subMenu = DebugBuildOption:getNew(DebugBuildOption)
	context:addSubMenu(debugMenu, subMenu)
	local meltTime
	if not Art:getModData().movableData['meltStartTime'] then meltTime = "ERROR: No melt time found for obj"; end
	if not meltTime then meltTime = tostring(Art:getModData().movableData['meltStartTime']); end
	local option = subMenu:addOption(getText("ContextMenu_LSDebug_IceDisplay")..":   "..meltTime)
	local optionSet = subMenu:addOption(getText("ContextMenu_LSDebug_IceMelt"), worldobjects, debugIceAboutToMelt, Art)
end

ArtCardContextMenu.doBuildMenu = function(player, context, worldobjects, Art, spriteName, customName, groupName, DebugBuildOption)
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    if thisPlayer:getVehicle() then return; end
	
	if not Art then return; end

	if (not Art) or (not Art:hasModData()) or (not Art:getModData().movableData) or (not Art:getModData().movableData['artBeauty']) then return; end

	local checkArtCardOption = context:addOptionOnTop(getText("ContextMenu_Painting_CheckArtInfo"),
	worldobjects,
	ArtCardContextMenu.onAction,
	thisPlayer,
	Art,
	spriteName)
	--checkArtCardOption.toolTip = getNewTooltip(getText("Tooltip_Painting_DiscardCanvas").." - ".." <RGB:1,0,0>"..getText("Tooltip_Painting_DiscardWarning"), false, false)
	checkArtCardOption.iconTexture = getTexture('media/ui/artinfo_icon.png')

	if LSUtil.hasAdminRights() and customName and (customName == "Sculpture Ice") then iceObjDebugOption(context, DebugBuildOption, Art); end

	if luautils.stringStarts(customName, "Sculpture") then return; end

	local hammerItem = checkInvForItem(thisPlayer)
	local frameOption = context:addOptionOnTop(getText("ContextMenu_Painting_SetFrame"))
	frameOption.iconTexture = getTexture('media/ui/artframe_icon.png')
	frameOption.toolTip = getNewTooltip(getText("Tooltip_Painting_SetFrame"), false, false)
	
	if not hammerItem then
		disableOption(frameOption, getText("Tooltip_Painting_Frame_HammerMissing"), false)
	else
		artCardDoFrameSubOptions(worldobjects, thisPlayer, context, Art, frameOption, hammerItem)
	end
end

ArtCardContextMenu.walkToFront = function(thisPlayer, thisObject)

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


ArtCardContextMenu.onAction = function(worldobjects, player, Art, spriteName)
	local ArtMenuOverlay = LSArtMenu:new(getCore():getScreenWidth()/2-500,getCore():getScreenHeight()/2-350,440,590,player:getPlayerNum(),Art,spriteName,false)
	ArtMenuOverlay:initialise()
	ArtMenuOverlay:addToUIManager()
end

local function getFullArt(worldobjects, Art, facing)
	local conObj, conSqrA, conSqrB
	if (facing == "E") then
		conSqrA = Art:getSquare():getAdjacentSquare(IsoDirections.N)
		conSqrB = Art:getSquare():getAdjacentSquare(IsoDirections.S)
	elseif (facing == "S") then
		conSqrA = Art:getSquare():getAdjacentSquare(IsoDirections.E)
		conSqrB = Art:getSquare():getAdjacentSquare(IsoDirections.W)
	end
	if (not conSqrA) and (not conSqrB) then return false; end

	--for _,object in ipairs(worldobjects) do
		if conSqrA then
			for i=1,conSqrA:getObjects():size() do
				local thisObject = conSqrA:getObjects():get(i-1)
				if thisObject and instanceof(thisObject, "IsoObject") and thisObject:hasModData() and thisObject:getModData().movableData and thisObject:getModData().movableData['artName'] then
					if (thisObject:getModData().movableData['artName'] == Art:getModData().movableData['artName']) and (thisObject:getModData().movableData['artAuthor'] == Art:getModData().movableData['artAuthor']) and
					(thisObject:getModData().movableData['artBeauty'] == Art:getModData().movableData['artBeauty']) then
						conObj = thisObject; break
					end
				end
			end
		end
		if conSqrB and (not conObj) then
			for i=1,conSqrB:getObjects():size() do
				local thisObject = conSqrB:getObjects():get(i-1)
				if thisObject and instanceof(thisObject, "IsoObject") and thisObject:hasModData() and thisObject:getModData().movableData and thisObject:getModData().movableData['artName'] then
					if (thisObject:getModData().movableData['artName'] == Art:getModData().movableData['artName']) and (thisObject:getModData().movableData['artAuthor'] == Art:getModData().movableData['artAuthor']) and
					(thisObject:getModData().movableData['artBeauty'] == Art:getModData().movableData['artBeauty']) then
						conObj = thisObject; break
					end
				end
			end
		end
	--end

	return conObj
end

local function getItemContDoTransfer(player, itemA)
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

ArtCardContextMenu.onApplyFrame = function(worldobjects, player, Art, spriteName, attachedSpriteName, frame, hammerItem, facing)
	if (not hammerItem) or (not checkInvForItem(player)) then return; end
	ISTimedActionQueue.clear(player);
	local attachedObj
	if frame.size == "large" then
		attachedObj = getFullArt(worldobjects, Art, facing)
		if not attachedObj then return; end
	end
--	if ArtCardContextMenu.walkToFront(player, Art) then
	local isValid
	--if luautils.walkToObject(player, Art, true) then
	if AdjacentFreeTileFinder.privTrySquare(player:getCurrentSquare(), Art:getSquare()) then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(player, Art:getSquare()))
		isValid = true
	end
	if (not isValid) and (ArtCardContextMenu.walkToFront(player, Art)) then isValid = true; end
	if isValid then
		local itemCont = getItemContDoTransfer(player, hammerItem)
		if not hammerItem:isEquipped() then
			ISTimedActionQueue.add(ISEquipWeaponAction:new(player, hammerItem, 50, true, false))
		end
		ISTimedActionQueue.add(LSApplyFrame:new(player, Art, spriteName, attachedSpriteName, frame, attachedObj, hammerItem, itemCont))
	end
end