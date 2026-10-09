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
require "ISUI/ISInventoryPaneContextMenu"
MirrorContextMenu = {};

local function StringStartWith(String,Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

local function MirrorCheckForItemLoot(thisPlayer, ItemName)

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

local function MirrorCheckForItemDyeLoot(thisPlayer, DyeItemList)

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
			if v:getFluidContainer() and v:getFluidContainer():getPrimaryFluid() and StringStartWith(v:getFluidContainer():getPrimaryFluid():getFluidTypeString(), "HairDye") and v:getFluidContainer():getAmount() >= 0.5 then
				if #DyeItemList == 0 then
					table.insert(DyeItemList, v)
				elseif #DyeItemList == 1 then
					if DyeItemList[1]:getType() ~= v:getType() then table.insert(DyeItemList, v); end
				else
					local notIncluded = true
					for _, dyeItem in pairs(DyeItemList) do
						if dyeItem:getType() == v:getType() then
							notIncluded = false
							break
						end
					end
					if notIncluded then table.insert(DyeItemList, v); end
				end
			end
		end
	end

	return DyeItemList

end

local function MirrorCheckForItemsDye(thisPlayer)

    local inventory = thisPlayer:getInventory();
	local it = inventory:getItems();
	local DyeItemList = {}

	for j = 0, it:size()-1 do
		local item = it:get(j);
		if item:getFluidContainer() and item:getFluidContainer():getPrimaryFluid() and StringStartWith(item:getFluidContainer():getPrimaryFluid():getFluidTypeString(), "HairDye") and item:getFluidContainer():getAmount() >= 0.5 then
			if #DyeItemList == 0 then
				table.insert(DyeItemList, item)
			elseif #DyeItemList == 1 then
				if DyeItemList[1]:getType() ~= item:getType() then table.insert(DyeItemList, item); end
			else
				local notIncluded = true
				for _, dyeItem in pairs(DyeItemList) do
					if dyeItem:getType() == item:getType() then
						notIncluded = false
						break
					end
				end
				if notIncluded then table.insert(DyeItemList, item); end
			end
		end
	end

	DyeItemList = MirrorCheckForItemDyeLoot(thisPlayer, DyeItemList)
	if #DyeItemList == 0 then DyeItemList = false; end
	return DyeItemList

end

local function MirrorCheckForItems(thisPlayer)

    local inventory = thisPlayer:getInventory();
	local it = inventory:getItems();
	local itemNameList = {{id=false,name="Toothbrush"}, {id=false,name="Toothpaste"}, {id=false,name="Comb"}, {id=false,name="MakeupFoundation"}, {id=false,name="MakeupEyeshadow"},
	{id=false,name="Lipstick"}, {id=false,name="Scissors"}, {id=false,name="Razor"}, {id=false,name="Hairgel"},{id=false,name="FilledTattooNeedle"}, {id=false,name="AcidBrush"},
	{id=false,name="ToothpasteCurio"}}
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
			v.id = MirrorCheckForItemLoot(thisPlayer, v.name)
		end
	end
	local toothpaste = itemNameList[12].id or itemNameList[2].id
	return itemNameList[1].id, toothpaste, itemNameList[3].id, itemNameList[4].id, itemNameList[5].id, itemNameList[6].id, itemNameList[7].id, itemNameList[8].id, itemNameList[9].id, itemNameList[10].id, itemNameList[11].id

end

MirrorContextMenu.doMirrorOptionsHairDye = function(worldobjects, context, buildOptionDye, thisPlayer, Mirror, groupName, ItemsDye, ActionOption)
	--not used anymore
	local parentMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOptionDye, parentMenu)
	local subMenu = parentMenu:addOptionOnTop(getText("ContextMenu_H_"..ActionOption));
	subMenu.iconTexture = getTexture('media/ui/dyes/'..ActionOption..'.png')
	local subMenuA = parentMenu:getNew(parentMenu);
	context:addSubMenu(subMenu, subMenuA)	
	
	local dyeItem

	if #ItemsDye == 1 then
		dyeItem = ItemsDye[1]
		local doHairDyeOption = subMenuA:addOption(getText(dyeItem:getName()), worldobjects, MirrorContextMenu.onAction, thisPlayer, Mirror, groupName, ActionOption, dyeItem)
		doHairDyeOption.iconTexture = dyeItem:getTexture()
	else
		for _, Item in pairs(ItemsDye) do
			dyeItem = Item
			local doHairDyeOption = subMenuA:addOption(getText(dyeItem:getName()), worldobjects, MirrorContextMenu.onAction, thisPlayer, Mirror, groupName, ActionOption, dyeItem)
			--doHairDyeOption.iconTexture = dyeItem:getTexture()
			doHairDyeOption.iconTexture = getTexture('media/ui/dyes/'..dyeItem:getType()..'.png')
		end
	end

end

MirrorContextMenu.doMirrorOptionsMakeups = function(worldobjects, parentMenuMakeup, thisPlayer, Mirror, groupName, Item, ActionOption)

	local doMakeupOption = parentMenuMakeup:addOptionOnTop(getText("ContextMenu_H_"..ActionOption), worldobjects, MirrorContextMenu.onAction, thisPlayer, Mirror, groupName, "Makeup", Item);

	if not Item then
		doMakeupOption.notAvailable = true;
	else
		doMakeupOption.iconTexture = Item:getTexture()
	end
	--------------
end

MirrorContextMenu.doMirrorBrushTeethOption = function(worldobjects, context, thisPlayer, Mirror, groupName, Items, AttachedSink)
	--BRUSH TEETH
	local doBrushTeethOption = context:addOptionOnTop(getText("ContextMenu_H_BrushTeeth"),
	worldobjects,
	MirrorContextMenu.onAction,
	thisPlayer,
	Mirror,
	AttachedSink,
	"BrushTeeth",
	Items);
	
	local tooltipBT = ISToolTip:new();
	tooltipBT:initialise();
	tooltipBT:setVisible(false);

	if (thisPlayer:getModData().lastBrushTeeth > 0) and (thisPlayer:getModData().lastBrushTeeth + 6) >= thisPlayer:getHoursSurvived() then
		doBrushTeethOption.iconTexture = getTexture('media/ui/brushteethNO_icon.png')
		doBrushTeethOption.notAvailable = true;
		descriptionBT = " <RED>" .. getText("Tooltip_H_BrushTeethCooldown");
		tooltipBT.description = descriptionBT
		doBrushTeethOption.toolTip = tooltipBT
	elseif not Items.Toothpaste or not Items.Toothbrush then--disable the option
		doBrushTeethOption.iconTexture = getTexture('media/ui/brushteethNO_icon.png')
		doBrushTeethOption.notAvailable = true;
		descriptionBT = " <RED>" .. getText("Tooltip_H_BrushTeethNoItem");
		tooltipBT.description = descriptionBT
		doBrushTeethOption.toolTip = tooltipBT
	elseif not AttachedSink:hasWater() then
		doBrushTeethOption.iconTexture = getTexture('media/ui/brushteethNO_icon.png')
		doBrushTeethOption.notAvailable = true;
		descriptionBT = " <RED>" .. getText("Tooltip_H_BrushTeethNoWater");
		tooltipBT.description = descriptionBT
		doBrushTeethOption.toolTip = tooltipBT
	else
		doBrushTeethOption.iconTexture = getTexture('media/ui/brushteeth_icon.png')
	end
end

MirrorContextMenu.doMirrorOptions = function(worldobjects, context, thisPlayer, Mirror, groupName, Items, ItemsDye)

	local currentEmbarrassment = thisPlayer:getModData().LSMoodles["Embarrassed"].Value
	if not thisPlayer:getModData().LSCooldowns then thisPlayer:getModData().LSCooldowns = {}; end	
	if not thisPlayer:getModData().LSCooldowns["mirrorPT"] then thisPlayer:getModData().LSCooldowns["mirrorPT"] = 0; end
	if not thisPlayer:getModData().LSCooldowns["mirrorCD"] then thisPlayer:getModData().LSCooldowns["mirrorCD"] = 0; end
	--------------
	--Calm Down
	if (not thisPlayer:hasTrait(CharacterTrait.DEAF)) and LSUtil.getCharacterMood(thisPlayer, "Stress") > 0.4 and thisPlayer:hasTrait(CharacterTrait.DISCIPLINED) and not (thisPlayer:getModData().LSCooldowns["mirrorCD"] > 0) then
		local doCalmDownOption = context:addOptionOnTop(getText("ContextMenu_H_CalmDown"),
			worldobjects,
			MirrorContextMenu.onAction,
			thisPlayer,
			Mirror,
			groupName,
			"CalmDown",
			false);

		local tooltipCD = ISToolTip:new();
			tooltipCD:initialise();
			tooltipCD:setVisible(false);
			tooltipCD.description = getText("Tooltip_H_CalmDown") .. " <RGB:1,1,0>" .. getText("IGUI_HaloNote_Stress")
			doCalmDownOption.toolTip = tooltipCD
			doCalmDownOption.iconTexture = getTexture('media/ui/SKmeditation_icon.png')
		--------------
	end
	--------------
	--PepTalk
	if (not thisPlayer:hasTrait(CharacterTrait.DEAF)) and ((currentEmbarrassment and (currentEmbarrassment > 0.4)) or LSUtil.getCharacterMood(thisPlayer, "Unhappiness") > 40) and not (thisPlayer:getModData().LSCooldowns["mirrorPT"] > 0) then
		local doPepTalkOption = context:addOptionOnTop(getText("ContextMenu_H_PepTalk"),
			worldobjects,
			MirrorContextMenu.onAction,
			thisPlayer,
			Mirror,
			groupName,
			"PepTalk",
			false);

		local tooltipPT = ISToolTip:new();
			tooltipPT:initialise();
			tooltipPT:setVisible(false);
			tooltipPT.description = getText("Tooltip_H_PepTalk") .. " <RGB:1,1,0>" .. getText("IGUI_HaloNote_Unhappyness")
			doPepTalkOption.toolTip = tooltipPT
			doPepTalkOption.iconTexture = getTexture('media/ui/talkto_icon.png')
		--------------
	end
	--------------
	--HairDye
	--if ItemsDye then
	--	local buildOptionDye = context:addOptionOnTop(getText("ContextMenu_H_Dyes"));
	--	buildOptionDye.iconTexture = getTexture('media/ui/piano_icon.png')
	--	if thisPlayer:getHumanVisual():getHairModel() and thisPlayer:getHumanVisual():getHairModel() ~= "Bald" then
	--		MirrorContextMenu.doMirrorOptionsHairDye(worldobjects, context, buildOptionDye, thisPlayer, Mirror, groupName, ItemsDye, "HairDye")
	--	end
	--	if thisPlayer:getHumanVisual():getBeardModel() and thisPlayer:getHumanVisual():getBeardModel() ~= "" then
	--		MirrorContextMenu.doMirrorOptionsHairDye(worldobjects, context, buildOptionDye, thisPlayer, Mirror, groupName, ItemsDye, "HairDyeBeard")
	--	end
		--------------
	--end
	--------------
	--Makeups
	--if Items.MakeupEye or Items.Makeup or Items.MakeupLipstick then
	--	local buildOptionMakeup = context:addOptionOnTop(getText("ContextMenu_H_Makeups"));
	--	buildOptionMakeup.iconTexture = getTexture('media/ui/piano_icon.png')
	--	local parentMenuMakeup = ISContextMenu:getNew(context);
	--	context:addSubMenu(buildOptionMakeup, parentMenuMakeup)
	--	MirrorContextMenu.doMirrorOptionsMakeups(worldobjects, parentMenuMakeup, thisPlayer, Mirror, groupName, Items.Makeup, "MakeupFoundation")
	--	MirrorContextMenu.doMirrorOptionsMakeups(worldobjects, parentMenuMakeup, thisPlayer, Mirror, groupName, Items.MakeupEye, "MakeupEye")
	--	MirrorContextMenu.doMirrorOptionsMakeups(worldobjects, parentMenuMakeup, thisPlayer, Mirror, groupName, Items.MakeupLipstick, "Lipstick")
	--end
	--------------
	if SandboxVars.Text.DividerHygiene then
	--Gussy Up
		if thisPlayer:getModData().LSMoodles["Attractive"] and not (thisPlayer:getModData().LSMoodles["Attractive"].Value > 0) then
			local doCheckYourselfOption = context:addOptionOnTop(getText("ContextMenu_H_GussyUp"),
				worldobjects,
				MirrorContextMenu.onAction,
				thisPlayer,
				Mirror,
				groupName,
				"GussyUp",
				Items.Comb);

			local tooltipCY = ISToolTip:new();
				tooltipCY:initialise();
				tooltipCY:setVisible(false);
			if not Items.Comb then
				doCheckYourselfOption.iconTexture = getTexture('media/ui/combNO_icon.png')
				doCheckYourselfOption.notAvailable = true;
				tooltipCY.description = " <RED>" .. getText("Tooltip_H_GUNoComb")
				doCheckYourselfOption.toolTip = tooltipCY
			else
				tooltipCY.description = getText("Tooltip_H_GussyUp") .. " <RGB:1,1,0>" .. getText("IGUI_HaloNote_Hygiene")
				doCheckYourselfOption.toolTip = tooltipCY
				doCheckYourselfOption.iconTexture = getTexture('media/ui/comb_icon.png')
			end
		end
	end
	--------------
	--Appearance
		local doAppearanceOption = context:addOptionOnTop(getText("ContextMenu_H_Appearance"),
			worldobjects,
			MirrorContextMenu.onAction,
			thisPlayer,
			Mirror,
			Items,
			"Appearance",
			ItemsDye);

		local tooltipA = ISToolTip:new();
			tooltipA:initialise();
			tooltipA:setVisible(false);
			tooltipA.description = getText("Tooltip_H_ChangeAPStart") .. " <RGB:1,1,0>" .. getText("IGUI_HaloNote_ChangeAPEnd")
			doAppearanceOption.toolTip = tooltipA
			doAppearanceOption.iconTexture = getTexture('media/ui/appearance_icon.png')
		--------------
end

MirrorContextMenu.doBuildMenu = function(player, context, worldobjects, Mirror, spriteName, customName, groupName, DebugBuildOption, AttachedSink)
 
	--if AttachedSink then print("MirrorContextMenu - has AttachedSink"); end
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    if thisPlayer:getVehicle() then return; end
	if thisPlayer:isSitOnGround() then return; end
	if thisPlayer:isSneaking() then return; end
	
	local playerdata
	
	if thisPlayer:hasModData() then
		playerdata = thisPlayer:getModData()
	else
	return; end

	if not Mirror then return; end

	local beautyVal = 0.1

	if not playerdata.hygieneNeed then
		playerdata.hygieneNeed = 50
	end
	if not playerdata.lastBrushTeeth then
		playerdata.lastBrushTeeth = 0
	end

	local Items = {}
	Items.Toothbrush, Items.Toothpaste, Items.Comb, Items.Makeup, Items.MakeupEye, Items.MakeupLipstick, Items.Scissors, Items.Razor, Items.Hairgel, Items.MakeupTattooNeedle, Items.MakeupTattooBrush = MirrorCheckForItems(thisPlayer)
	local ItemsDye = MirrorCheckForItemsDye(thisPlayer)

-----------INFO

	local InfoOption = context:addOptionOnTop(getText("ContextMenu_Info"));

	local tooltip = ISToolTip:new();
		tooltip:initialise();
		tooltip:setVisible(false);
		description = getText("Tooltip_Sit_Beauty") .. " <RGB:1,1,0>" .. beautyVal;
		tooltip.description = description
		InfoOption.toolTip = tooltip

	if not thisPlayer:hasTimedActions() then 

		MirrorContextMenu.doMirrorOptions(worldobjects, context, thisPlayer, Mirror, groupName, Items, ItemsDye)
		if AttachedSink and SandboxVars.Text.DividerHygiene then MirrorContextMenu.doMirrorBrushTeethOption(worldobjects, context, thisPlayer, Mirror, groupName, Items, AttachedSink); end
-------
	end--hasTimedActions
------

end

MirrorContextMenu.walkToFront = function(thisPlayer, thisObject)
	local frontSquare = nil
	local controllerSquare = nil
	local spriteName = thisObject:getSprite():getName()
	if not spriteName then
		return false
	end
	local thisSquare = thisObject:getSquare()
	if not thisSquare then
		return false
	end
	local properties = thisObject:getSprite():getProperties()
	
	local facing = nil
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	
	if facing then
		if facing == "S" then
			frontSquare = thisObject:getSquare():getS()
		elseif facing == "E" then
			frontSquare = thisObject:getSquare():getE()
		elseif facing == "W" then
			frontSquare = thisObject:getSquare():getW()
		elseif facing == "N" then
			frontSquare = thisObject:getSquare():getN()
		end
	end
	
	if frontSquare then
		if AdjacentFreeTileFinder.privTrySquare(thisSquare, frontSquare) then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
			return true
		end
	end

	local freeSquare = (thisSquare:getS() or thisSquare:getE() or thisSquare:getW() or thisSquare:getN())

	if not freeSquare then
		if luautils.walkAdj(thisPlayer, thisSquare, true) then
		return true
		else
		return false
		end
	end

	--sometimes showers are blocked from one or more sides, so we find and move the player to the closes available free tile
	local N
	local S
	local E
	local W

	if thisSquare:getS() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getS()) then
		if thisPlayer:getY() >= thisSquare:getS():getY() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getS()))
			return true
		else
			S = 1
		end
	end
	
	if thisSquare:getN() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getN()) then
		if thisPlayer:getY() <= thisSquare:getN():getY() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getN()))
			return true
		else
			N = 1
		end
	end

	if thisSquare:getE() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getE()) then
		if thisPlayer:getX() >= thisSquare:getE():getX() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getE()))
			return true
		else
			E = 1
		end
	end

	if thisSquare:getW() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getW()) then
		if thisPlayer:getX() >= thisSquare:getW():getX() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getW()))
			return true
		else
			W = 1
		end
	end

	if S then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getS()))
		return true
	elseif N then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getN()))
		return true
	elseif W then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getW()))
		return true
	elseif E then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getE()))
		return true
	end
	
	return false
end


local function CabinetTransferItem(player, itemA)

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

MirrorContextMenu.onAction = function(worldobjects, player, Mirror, Type, ActionType, item)
	local LSBrushTeeth = require "TimedActions/LSBrushTeeth"
	local LSCheckYourself = require "TimedActions/LSCheckYourself"
	local LSCheckYourselfAP = require "TimedActions/LSCheckYourselfAP"
	local actionTime, pasteEffect
	if MirrorContextMenu.walkToFront(player, Mirror) then
		local getItemCont, destContainer = false, Mirror:getContainer()
		
		if ActionType == "Appearance" then
		--Items.Makeup, Items.MakeupEye, Items.MakeupLipstick
			if Type and (Type.Scissors or Type.Razor or Type.Hairgel) then
				if Type.Scissors then Type.ScissorsCont = CabinetTransferItem(player, Type.Scissors); end
				if Type.Razor then Type.RazorCont = CabinetTransferItem(player, Type.Razor); end
				--if Type.Hairgel then Type.HairgelCont = CabinetTransferItem(player, Type.Hairgel); end
			end
			ISTimedActionQueue.add(LSCheckYourselfAP:new(player, Mirror, Type, item))
		elseif ActionType == "BrushTeeth" then
			if item and item.Toothbrush and item.Toothpaste then
				if item.Toothbrush then item.ToothbrushCont = CabinetTransferItem(player, item.Toothbrush); end
				if item.Toothpaste then
					item.ToothpasteCont = CabinetTransferItem(player, item.Toothpaste)
					if item.Toothpaste:getType() == "ToothpasteCurio" then pasteEffect = "MintCurio"; end
				end
				actionTime = 500
				if player:hasTrait(CharacterTrait.CLEANFREAK) then actionTime = 900; end
				ISTimedActionQueue.add(LSBrushTeeth:new(player, Mirror, Type, item, pasteEffect, actionTime))
			end
		elseif item then
			getItemCont = CabinetTransferItem(player, item)
			if ActionType == "GussyUp" then
				actionTime = 750
				if player:hasTrait(CharacterTrait.CLEANFREAK) then actionTime = 1100; end
				--ISTimedActionQueue.add(ISWalkToTimedAction:new(player, Mirror:getSquare()))
				ISTimedActionQueue.add(LSCheckYourself:new(player, Mirror, item, getItemCont, ActionType, actionTime))
			elseif ActionType == "Makeup" then
				ISInventoryPaneContextMenu.onMakeUp(item, player)
			elseif ActionType == "HairDye" then
				ISInventoryPaneContextMenu.onDyeHair(item, player, false)
			elseif ActionType == "HairDyeBeard" then
				ISInventoryPaneContextMenu.onDyeHair(item, player, true)
			end
		else
			if ActionType == "CalmDown" then
				ISTimedActionQueue.add(LSCheckYourself:new(player, Mirror, false, false, ActionType, 900))
			elseif ActionType == "PepTalk" then
				ISTimedActionQueue.add(LSCheckYourself:new(player, Mirror, false, false, ActionType, 900))
			end
		end
	end
end


--Events.OnFillWorldObjectContextMenu.Add(MirrorContextMenu.doBuildMenu);
