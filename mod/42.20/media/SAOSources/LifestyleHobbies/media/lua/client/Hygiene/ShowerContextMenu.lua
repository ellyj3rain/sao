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

require "Properties/Player/CleaningSkill"
require "Helper/ContextHelper"

ShowerContextMenu = {};

local function StringStartWith(String,Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

local function ItemHasCleaningLiquid(item)
	if not item then return false; end
	if item:getFluidContainer() and item:getFluidContainer():getPrimaryFluid() and
	(StringStartWith(item:getFluidContainer():getPrimaryFluid():getFluidTypeString(), "CleaningLiquid") or StringStartWith(item:getFluidContainer():getPrimaryFluid():getFluidTypeString(), "CleaningLiquid2"))
	and item:getFluidContainer():getAmount() > 0 then return true; end
	return false
end

ShowerContextMenu.doBuildMenu = function(player, context, worldobjects, Shower, spriteName, customName, groupName, DebugBuildOption)
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    if thisPlayer:getVehicle() then return; end
	--if not thisPlayer:isSitOnGround() then return; end
	if thisPlayer:isSneaking() then return; end
	
	local playerdata
	
	if thisPlayer:hasModData() then
		playerdata = thisPlayer:getModData()
	else
	return; end
	
	local Type

	if customName == "Shower" and groupName == "Deluxe" then
		Type = "Deluxe"
	elseif customName == "Shower" then
		Type = "Common"
	end

	--Shower, Type = ScanForTileObject(player, worldobjects)

	if not Shower then return; end

	local waterUsage = 4
	local beautyVal = 0.5

	if Type == "Deluxe" then
		waterUsage = 3
		beautyVal = 1
	end

	local sData = Shower:getModData()
	sData.movableData = sData.movableData or {}
	local showerData = sData.movableData

	if not playerdata.hygieneNeed then
		playerdata.hygieneNeed = 40
	end

	if not LSUtil.objHasWater(Shower, waterUsage*2) then 
	
	--thisPlayer:Say("not enough water in Shower")
	
	local RefuseOption = context:addOption(getText("ContextMenu_Shower_NoWater"));

	local tooltip = ISToolTip:new();
		tooltip:initialise();
		tooltip:setVisible(false);
		

		RefuseOption.notAvailable = true;
		description = " <RED>" .. getText("Tooltip_Shower_NoWater",Shower:getFluidAmount(),waterUsage*2);
		tooltip.description = description
		RefuseOption.toolTip = tooltip
		RefuseOption.iconTexture = getTexture('media/ui/showerNO_icon.png')

	elseif not thisPlayer:hasTimedActions() and not thisPlayer:isSitOnGround() then

	--------------DIRT/BLOOD
	local visual = thisPlayer:getHumanVisual()
	local hasDirtOrBlood = false

	for i = 1, BloodBodyPartType.MAX:index() do
		local part = BloodBodyPartType.FromIndex(i - 1)
		local dirt = visual:getDirt(part)
		local blood = visual:getBlood(part)
		if (dirt > 0) or (blood > 0) then
			hasDirtOrBlood = true
			break
		end
	end
	-------------------------

	local thisDirtSprite

	if not showerData.condition then
		showerData.condition = 0
	end

	if showerData.dirtyLevel then

		local dirtSprite
		local dirtSprite2
		local dirtSprite3
		if Type == "Deluxe" then
			if Shower:getSprite():getProperties():get("Facing") == "S" then
				dirtSprite = "LS_Misc_1_4"
				dirtSprite2 = "LS_Misc_1_12"
				dirtSprite3 = "LS_Misc_1_20"
			elseif Shower:getSprite():getProperties():get("Facing") == "E" then
				dirtSprite = "LS_Misc_1_5"
				dirtSprite2 = "LS_Misc_1_13"
				dirtSprite3 = "LS_Misc_1_21"
			elseif Shower:getSprite():getProperties():get("Facing") == "W" then
				dirtSprite = "LS_Misc_1_2"
				dirtSprite2 = "LS_Misc_1_10"
				dirtSprite3 = "LS_Misc_1_18"
			elseif Shower:getSprite():getProperties():get("Facing") == "N" then
				dirtSprite = "LS_Misc_1_3"
				dirtSprite2 = "LS_Misc_1_11"
				dirtSprite3 = "LS_Misc_1_19"
			end
		else
			if Shower:getSprite():getProperties():get("Facing") == "S" then
				dirtSprite = "LS_Misc_1_2"
				dirtSprite2 = "LS_Misc_1_10"
				dirtSprite3 = "LS_Misc_1_18"
			elseif Shower:getSprite():getProperties():get("Facing") == "E" then
				dirtSprite = "LS_Misc_1_3"
				dirtSprite2 = "LS_Misc_1_11"
				dirtSprite3 = "LS_Misc_1_19"
			elseif Shower:getSprite():getProperties():get("Facing") == "W" then
				dirtSprite = "LS_Misc_1_1"
				dirtSprite2 = "LS_Misc_1_9"
				dirtSprite3 = "LS_Misc_1_17"
			elseif Shower:getSprite():getProperties():get("Facing") == "N" then
				dirtSprite = "LS_Misc_1_0"
				dirtSprite2 = "LS_Misc_1_8"
				dirtSprite3 = "LS_Misc_1_16"
			end
		end

		if showerData.dirtyLevel == 1 and showerData.condition >= 30 then
			thisDirtSprite = dirtSprite
		elseif showerData.dirtyLevel == 2 and showerData.condition >= 60 then
			thisDirtSprite = dirtSprite2
		elseif showerData.dirtyLevel == 3 and showerData.condition >= 90 then
			thisDirtSprite = dirtSprite3
		end
	else
		showerData.dirtyLevel = 0
	end

	if isClient() and thisDirtSprite then
		sendClientCommand("LS", "ModifyOverlaySprite", {{Shower:getX(),Shower:getY(),Shower:getZ(),Shower:getSprite():getName()}, thisDirtSprite})
		LSSync.transmit(Shower)
		--Shower:setOverlaySprite(thisDirtSprite, true)
		--Shower:transmitUpdatedSpriteToServer()
		--Shower:transmitModData()
	--elseif isClient() then
		--self.toiletObject:transmitModData()
	elseif thisDirtSprite then
		Shower:setOverlaySprite(thisDirtSprite, false)
	end

		local ShowerSounds = require("Hygiene/Tracks/ShowerSounds")

		local AvailableShowerSounds = {}
		local faucetSound
		local showerLoopSound
		
		for k,v in pairs(ShowerSounds) do
			if v.category == Type then
				showerLoopSound = v.isLoop
				faucetSound = v.faucet
			end
			if showerLoopSound and faucetSound then break; end
		end

		if showerData.dirtyLevel > 0 then

			local inventory = thisPlayer:getInventory();
			local it = inventory:getItems();
			local CleanItem1
			local CleanItem2

			for j = 0, it:size()-1 do
				local item = it:get(j);
				if item:getType() == "Sponge" and not CleanItem1 then
					CleanItem1 = item
				end
				if (not CleanItem2) and ItemHasCleaningLiquid(item) then
					CleanItem2 = item
				end
				if CleanItem1 and CleanItem2 then
					break
				end
			end

			local cleanDuration = LSCleaning.getCleaningTime(thisPlayer, {"Bathroom", showerData.condition or 1, false})

			local cleanOption = context:addOptionOnTop(getText("ContextMenu_Shower_Clean"),
			worldobjects,
			ShowerContextMenu.onAction,
			thisPlayer,
			Shower,
			Type,
			cleanDuration,
			CleanItem1,
			CleanItem2,
			false,
			"IsClean",
			false);
	
			local tooltipClean = ISToolTip:new();
				tooltipClean:initialise();
				tooltipClean:setVisible(false);

			if CleanItem1 and CleanItem2 then
				cleanOption.iconTexture = getTexture('media/ui/clean_icon.png')
			else
				cleanOption.notAvailable = true;
				descriptionC = " <RED>" .. getText("Tooltip_Shower_CleanNoItem");
				tooltipClean.description = descriptionC
				cleanOption.toolTip = tooltipClean
				
				cleanOption.iconTexture = getTexture('media/ui/cleanNO_icon.png')
			end
	
		end

		if (Type == "Deluxe" or Type == "Common") and ((playerdata.hygieneNeed >= 40) or (hasDirtOrBlood)) then
			local useContextText = "ContextMenu_Shower_Use"
			if not ((SandboxVars.ElecShutModifier > -1 and
			GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
			Shower:getSquare():haveElectricity()) then
				--print("no electricity for shower")
				useContextText = "ContextMenu_Shower_Use_NoHot"
			end
			local doShowerOption = context:addOptionOnTop(getText(useContextText),
			worldobjects,
			ShowerContextMenu.onAction,
			thisPlayer,
			Shower,
			Type,
			waterUsage,
			faucetSound,
			showerLoopSound,
			false,---------------soap
			"IsUse",
			false);
	
			doShowerOption.iconTexture = getTexture('media/ui/shower_icon.png')
	
		end
-------
	end--water
------

-----------DEBUG

	local sandboxExpressions = SandboxVars.Debug.Expressions or false
	if sandboxExpressions then

		if LSUtil.hasAdminRights() then

		local debugMenu = DebugBuildOption:addOptionOnTop(getText("ContextMenu_LSDebug_Hygiene"));
		
		local subMenu = DebugBuildOption:getNew(DebugBuildOption);
		context:addSubMenu(debugMenu, subMenu)

			local doShowerDebugResetOption = subMenu:addOption(getText("ContextMenu_LSDebug_ResetTileData"),
			worldobjects,
			ShowerContextMenu.onDebug,
			thisPlayer,
			Shower,
			Type,
			"IsDebugReset");

		end
	end

end

ShowerContextMenu.walkToFront = function(thisPlayer, thisObject)
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

ShowerContextMenu.onAction = function(worldobjects, player, Shower, Type, WaterUsage, faucet, soundLoop, soap, ActionType, PlungerItem)
	local LSUseShower = require "TimedActions/LSUseShower"
	local LSChangeClothes = require "TimedActions/PlayerChangeClothes"
	local spriteName = Shower:getSprite():getName()

	if ShowerContextMenu.walkToFront(player, Shower) then
	
		local dirtSprite
		local dirtSprite2
		local dirtSprite3
		local facingDir
		if Type == "Deluxe" then
			if Shower:getSprite():getProperties():get("Facing") == "S" then
					facingDir = "S"
					dirtSprite = "LS_Misc_1_4"
					dirtSprite2 = "LS_Misc_1_12"
					dirtSprite3 = "LS_Misc_1_20"
				elseif Shower:getSprite():getProperties():get("Facing") == "E" then
					facingDir = "E"
					dirtSprite = "LS_Misc_1_5"
					dirtSprite2 = "LS_Misc_1_13"
					dirtSprite3 = "LS_Misc_1_21"
				elseif Shower:getSprite():getProperties():get("Facing") == "W" then
					facingDir = "W"
					dirtSprite = "LS_Misc_1_1"
					dirtSprite2 = "LS_Misc_1_9"
					dirtSprite3 = "LS_Misc_1_17"
				elseif Shower:getSprite():getProperties():get("Facing") == "N" then
					facingDir = "N"
					dirtSprite = "LS_Misc_1_3"
					dirtSprite2 = "LS_Misc_1_11"
					dirtSprite3 = "LS_Misc_1_19"
			end
		elseif Type == "Common" then
			if Shower:getSprite():getProperties():get("Facing") == "S" then
					facingDir = "S"
					dirtSprite = "LS_Misc_1_2"
					dirtSprite2 = "LS_Misc_1_10"
					dirtSprite3 = "LS_Misc_1_18"
				elseif Shower:getSprite():getProperties():get("Facing") == "E" then
					facingDir = "E"
					dirtSprite = "LS_Misc_1_3"
					dirtSprite2 = "LS_Misc_1_11"
					dirtSprite3 = "LS_Misc_1_19"
				elseif Shower:getSprite():getProperties():get("Facing") == "W" then
					facingDir = "W"
					dirtSprite = "LS_Misc_1_1"
					dirtSprite2 = "LS_Misc_1_9"
					dirtSprite3 = "LS_Misc_1_17"
				elseif Shower:getSprite():getProperties():get("Facing") == "N" then
					facingDir = "N"
					dirtSprite = "LS_Misc_1_0"
					dirtSprite2 = "LS_Misc_1_8"
					dirtSprite3 = "LS_Misc_1_16"
			end
		end

		local wasDressed
		local inventory = player:getInventory()	
		local it = inventory:getItems()

		for j = 0, it:size()-1 do
			local item = it:get(j);
			if item:getClothingItem() and player:isEquippedClothing(item) and (not item:isHidden()) and
			item:getType() ~= "Belt" and
			item:getType() ~= "Belt2" and
			item:getType() ~= "HolsterDouble" and
			item:getType() ~= "HolsterSimple" then
				wasDressed = true
				break
			end
		end

		if ActionType == "IsUse" then
			--BathRemoveAllMakeup(player)
			if wasDressed then
				ISTimedActionQueue.add(LSChangeClothes:new(player, Shower, "isBathNoLaundryStart"))
			end
			ISTimedActionQueue.add(ISWalkToTimedAction:new(player, Shower:getSquare()))
			ISTimedActionQueue.add(LSUseShower:new(player, Shower, Type, WaterUsage, faucet, soundLoop, facingDir, dirtSprite, dirtSprite2, dirtSprite3, wasDressed))
		elseif ActionType == "IsClean" then
			local movData = Shower:getModData().movableData
			ISTimedActionQueue.add(ISWalkToTimedAction:new(player, Shower:getSquare()))
			ISTimedActionQueue.add(LSCleanObject:new(player, Shower, false, spriteName, WaterUsage, movData, faucet, soundLoop)) -- WaterUsage is duration, faucet is sponge, soundLoop is detergent
			--ISTimedActionQueue.add(LSCleanObject:new(player, Shower, false, WaterUsage, 20, "Bob_Cleaning_Low", faucet, soundLoop, spriteName));--player, object 1, object 2, duration, difficulty, animation, item1, item2, obj1 spriteName
		end
	end
end


ShowerContextMenu.onDebug = function(worldobjects, player, Shower, Type, Action)

	if Action == "IsDebugReset" then
		Shower:getModData().movableData.dirtyLevel = 0
		Shower:getModData().movableData.condition = 0
		if isClient() then
			sendClientCommand("LS", "ModifyOverlaySprite", {{Shower:getX(),Shower:getY(),Shower:getZ(),Shower:getSprite():getName()}, false})
			LSSync.transmit(Shower)
		
		--Shower:transmitModData()
		--Shower:setOverlaySprite(nil, true)
		--Shower:transmitUpdatedSpriteToServer()
		else
		Shower:setOverlaySprite(nil, false)
		end
		player:Say("Shower Reset")
	end
end

--Events.OnFillWorldObjectContextMenu.Add(ShowerContextMenu.doBuildMenu);
