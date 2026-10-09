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

GFClockContextMenu = {};

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

local function getTimeOfDay()
	local hrs, mins, icon = getGameTime():getHour(), getGameTime():getMinutes(), "clockDay_icon"
	if (hrs < 6) or (hrs >= 18) then icon = "clockNight_icon"; end
	if hrs < 10 then hrs = "0"..tostring(hrs); end
	if mins < 10 then mins = "0"..tostring(mins); end
	return tostring(hrs), tostring(mins), icon
end

local function checkClockHour(subMenu, Clock)
	if not Clock:getModData().movableData['active'] then return; end
	local hrs, mins, icon = getTimeOfDay()
	local option = subMenu:addOption(getText("ContextMenu_GFClock_Display")..":   "..hrs.." : "..mins)
	option.iconTexture = getTexture('media/ui/'..icon..'.png')
end

local function checkClockWind(worldobjects, subMenu, thisPlayer, Clock)

	local option = subMenu:addOption(getText("ContextMenu_GFClock_Wind"),worldobjects,GFClockContextMenu.onWind,thisPlayer,Clock)
	option.iconTexture = getTexture('media/ui/gears_icon.png')
	if Clock:getModData().movableData['active'] and Clock:getModData().movableData['lastWind'] and
	(Clock:getModData().movableData['lastWind']+12 > tonumber(getGameTime():getWorldAgeHours())) then
		disableOption(option, getText("Tooltip_GFClock_TooSoon"), 'media/ui/gfclockNo_icon.png')
	end
end

local function getMoveableDisplayName(obj)
    if (not obj) or (not obj:getSprite()) then return "CLOCK" end
    local props = obj:getSprite():getProperties()
    if props:has("CustomName") then
        local name = props:get("CustomName")
        if props:has("GroupName") then
            name = props:get("GroupName") .. " " .. name
        end
        return Translator.getMoveableDisplayName(name)
    end
    return "CLOCK"
end

local function isArtwork(Art)
	if (not Art) or (not Art:hasModData()) or (not Art:getModData().movableData) or (not Art:getModData().movableData['artBeauty']) then return false; end
	return true
end

GFClockContextMenu.doBuildMenu = function(player, context, worldobjects, Clock, spriteName, customName, groupName, DebugBuildOption)
    local thisPlayer = getSpecificPlayer(player)
	if not thisPlayer then return; end
    if thisPlayer:getVehicle() or (thisPlayer:hasTimedActions()) then return; end
	if not Clock then return; end
	if isArtwork(Clock) then ArtCardContextMenu.doBuildMenu(player, context, worldobjects, Clock, spriteName, customName, groupName, DebugBuildOption); end
	Clock:getModData().movableData = Clock:getModData().movableData or {}
	local clockName = getMoveableDisplayName(Clock)
	local buildOption = context:addOptionOnTop(clockName)
	buildOption.iconTexture = getTexture('media/ui/gfclock_icon.png')
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)

	checkClockHour(subMenu, Clock)
	checkClockWind(worldobjects, subMenu, thisPlayer, Clock)
end

local function getFacing(thisObject)
	local properties = thisObject:getSprite():getProperties()
	if properties:has("Facing") then
		return properties:get("Facing")
	end
	return nil
end

GFClockContextMenu.walkToFront = function(thisPlayer, thisObject)
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

GFClockContextMenu.onWind = function(worldobjects, player, Clock)
	if GFClockContextMenu.walkToFront(player, Clock) then
		ISTimedActionQueue.add(LSClockWind:new(player, Clock))
	end
end
