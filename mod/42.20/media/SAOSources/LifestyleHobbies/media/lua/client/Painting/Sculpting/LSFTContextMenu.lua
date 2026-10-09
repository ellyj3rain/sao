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

LSFTContextMenu = {};

local function objHasEnergy(obj)
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end

local function getNewTooltip(description, texture, name)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	if texture then
		tooltip:setName(getText("ContextMenu_Sculpting_"..tostring(name)))
		tooltip:setTexture(texture)
		tooltip.footNote = getText("Tooltip_Sculpting_FootNote")
	end
	return tooltip
end

local function disableOption(option, tooltipDescription, iconTexture)
	option.notAvailable = true
	option.toolTip = getNewTooltip(tooltipDescription, false, false)
	if iconTexture then option.iconTexture = getTexture(iconTexture); end
end

local function getCooldown(thisPlayer)
	if not thisPlayer:getModData().LSCooldowns then thisPlayer:getModData().LSCooldowns = {}; end
	if not thisPlayer:getModData().LSCooldowns["FortuneTeller"] then thisPlayer:getModData().LSCooldowns["FortuneTeller"] = 0; end
	return thisPlayer:getModData().LSCooldowns["FortuneTeller"]
end

local function doTellerOption(worldobjects, subMenu, thisPlayer, Teller, spriteName)
	local option = subMenu:addOption(getText("ContextMenu_Teller_Activate"),worldobjects,LSFTContextMenu.onAction,thisPlayer,Teller,spriteName)
	option.iconTexture = getTexture('media/ui/teller_icon.png')
	local cooldown = getCooldown(thisPlayer)
	if (not isDebugEnabled()) and cooldown and (cooldown > 0) then disableOption(option, getText("Tooltip_Interaction_TooSoon"), 'media/ui/tellerNo_icon.png'); end
end

local function getMoveableDisplayName(obj)
    if (not obj) or (not obj:getSprite()) then return "TELLER" end
    local props = obj:getSprite():getProperties()
    if props:has("CustomName") then
        local name = props:get("CustomName")
        if props:has("GroupName") then
            name = props:get("GroupName") .. " " .. name
        end
        return Translator.getMoveableDisplayName(name)
    end
    return "TELLER"
end

local function isArtwork(Art)
	if (not Art) or (not Art:hasModData()) or (not Art:getModData().movableData) or (not Art:getModData().movableData['artBeauty']) then return false; end
	return true
end

LSFTContextMenu.doBuildMenu = function(player, context, worldobjects, Teller, spriteName, customName, groupName, DebugBuildOption)
    local thisPlayer = getSpecificPlayer(player)
	if not thisPlayer then return; end
    if thisPlayer:getVehicle() or (thisPlayer:hasTimedActions()) then return; end
	if isArtwork(Teller) then ArtCardContextMenu.doBuildMenu(player, context, worldobjects, Teller, spriteName, customName, groupName, DebugBuildOption); end
	if (not Teller) or (not objHasEnergy(Teller)) then return; end
	local tellerName = getMoveableDisplayName(Teller)
	local buildOption = context:addOptionOnTop(tellerName)
	buildOption.iconTexture = getTexture('media/ui/teller_icon.png')
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)
	doTellerOption(worldobjects, subMenu, thisPlayer, Teller, spriteName)
end

local function getFacing(thisObject)
	local properties = thisObject:getSprite():getProperties()
	if properties:has("Facing") then
		return properties:get("Facing")
	end
	return nil
end

LSFTContextMenu.walkToFront = function(thisPlayer, thisObject)
	if not thisObject then return false; end
	local controllerSquare = thisObject:getSquare()
	if not controllerSquare then return false; end
	local facing = getFacing(thisObject)
	if not facing then return false; end
	local frontSquare
	if facing == "S" then
		frontSquare = thisObject:getSquare():getS()
	elseif facing == "E" then
		frontSquare = thisObject:getSquare():getE()
	end
	if not frontSquare then return false; end
	if AdjacentFreeTileFinder.privTrySquare(controllerSquare, frontSquare) then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
		return true
	end
	return false
end

LSFTContextMenu.onAction = function(worldobjects, player, Teller, spriteName)
	if LSFTContextMenu.walkToFront(player, Teller) then
		ISTimedActionQueue.add(LSFTAction:new(player, Teller, spriteName))
	end
end
