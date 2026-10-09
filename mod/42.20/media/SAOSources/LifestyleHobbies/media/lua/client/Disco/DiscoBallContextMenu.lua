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

DiscoBallMenu = {}

local function getNewTooltip(description)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	return tooltip
end

local function disableOption(option, description, texture)
	option.notAvailable = true
	option.toolTip = getNewTooltip(description)
	option.iconTexture = getTexture(texture)
end

local function sqrHasEnergy(obj)
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end
--default, random, shuffle, circles, spots, gold, rainbow, valentine
local function getModes()
	return {"default","random","shuffle","circles","spots","gold","rainbow","valentine"}
end

local function doModeOptions(parentMenu, worldobjects, DiscoBall, thisPlayer)
	local t = getModes()
	local shuffle
	for n=1, #t do
		shuffle = false
		if t[n] == "shuffle" then shuffle = true; end
		local modeOption = parentMenu:addOption(getText("ContextMenu_Disco_Mode_"..t[n]),worldobjects,DiscoBallMenu.onPlay,thisPlayer,DiscoBall,"JukeboxTurnOn",t[n], shuffle);
		modeOption.iconTexture = getTexture('media/ui/disco_'..t[n]..'_icon.png')
		if (DiscoBall:getModData().Mode == t[n]) and (not DiscoBall:getModData().Shuffle) then disableOption(modeOption, getText("Tooltip_Disco_Current"), 'media/ui/discomode_icon.png');
		elseif DiscoBall:getModData().Shuffle and (t[n] == "shuffle") then disableOption(modeOption, getText("Tooltip_Disco_Current"), 'media/ui/discomode_icon.png'); end
	end
end

DiscoBallMenu.doBuildMenu = function(player, context, worldobjects, DiscoBall, spriteName, customName, groupName, DebugBuildOption)

    local thisPlayer = getSpecificPlayer(player)

    if (thisPlayer:getVehicle()) or (not DiscoBall) or (not sqrHasEnergy(DiscoBall)) then return; end
	local alterData
    if not DiscoBall:getModData().DiscoBallID then
		DiscoBall:getModData().DiscoBallID = {(tostring(DiscoBall:getX()) .. "," .. tostring(DiscoBall:getY()) .. "," .. tostring(DiscoBall:getZ()))};
		if not alterData then alterData = {}; end
		alterData.DiscoBallID = DiscoBall:getModData().DiscoBallID
		--DiscoBall:transmitModData();
	end
    if not DiscoBall:getModData().OnOff then 
		DiscoBall:getModData().OnOff = "off"
		if not alterData then alterData = {}; end
		alterData.OnOff = DiscoBall:getModData().OnOff
		--DiscoBall:transmitModData();
	end

	if alterData then
		sendClientCommand("LS", "ModifyObjData", {{DiscoBall:getX(),DiscoBall:getY(),DiscoBall:getZ(),spriteName}, false, alterData})
	end

	if DiscoBall:getModData().OnOff == "off" then
	----------------Turn On
		local discoballoptionOn = context:addOptionOnTop(getText("ContextMenu_DiscoBall_TurnOn"),
		worldobjects,
		DiscoBallMenu.onTurnOn,
		thisPlayer,
		DiscoBall,
		"JukeboxTurnOn");	
		discoballoptionOn.iconTexture = getTexture('media/ui/lightbulbOn_icon.png')
	else
	----------------Turn Off
	local discoballoptionOff = context:addOptionOnTop(getText("ContextMenu_DiscoBall_TurnOff"),
		worldobjects,
		DiscoBallMenu.onTurnOff,
		thisPlayer,
		DiscoBall,
		"JukeboxTurnOff");
	discoballoptionOff.iconTexture = getTexture('media/ui/lightbulbOff_icon.png')
	----------------Modes
		local buildOption = context:addOptionOnTop(getText("ContextMenu_Select_Disco_Mode"));
		buildOption.iconTexture = getTexture('media/ui/discomode_icon.png')
		local parentMenu = ISContextMenu:getNew(context);
		context:addSubMenu(buildOption, parentMenu)
		doModeOptions(parentMenu, worldobjects, DiscoBall, thisPlayer)
	end
end

DiscoBallMenu.walkToFront = function(thisPlayer, thisObject)
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

DiscoBallMenu.onTurnOn = function(worldobjects, player, DiscoBall, soundFile)
	if luautils.walkAdj(player, DiscoBall:getSquare(), true) then
		ISTimedActionQueue.add(DiscoBallOn:new(player, DiscoBall, soundFile));
	end
end

DiscoBallMenu.onTurnOff = function(worldobjects, player, DiscoBall, soundFile)
	if luautils.walkAdj(player, DiscoBall:getSquare(), true) then
		ISTimedActionQueue.add(DiscoBallOff:new(player, DiscoBall, soundFile));
	end
end

DiscoBallMenu.onPlay = function(worldobjects, player, DiscoBall, soundFile, Mode, Shuffle)
	if luautils.walkAdj(player, DiscoBall:getSquare(), true) then
		ISTimedActionQueue.add(DiscoBallPlay:new(player, DiscoBall, soundFile, Mode, Shuffle));
	end
end