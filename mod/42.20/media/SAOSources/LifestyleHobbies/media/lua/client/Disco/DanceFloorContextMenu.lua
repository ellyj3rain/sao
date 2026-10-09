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

DanceFloorMenu = {}
DanceFloorMenu.range = 15
DanceFloorMenu.mRange = 8

local function objIsClose(source, obj)
	if source and (source:getX() >= obj:getX() - DanceFloorMenu.range and source:getX() <= obj:getX() + DanceFloorMenu.range and
	source:getY() >= obj:getY() - DanceFloorMenu.range and source:getY() <= obj:getY() + DanceFloorMenu.range) then return true; end
	return false
end

local function getCustomName(object)
	if not object then return nil; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") then
        return properties:get("CustomName")
    end
    return nil
end

local function objIsMainDF(obj)
	if obj and obj:hasModData() and obj:getModData().Connected and obj:getModData().IsMainDF then return obj; end
	return false
end

local function objectIsValid(obj)
	if obj and instanceof(obj, "IsoObject") and obj:getSquare() and obj:getX() and obj:getY() then return true; end
	return false
end

local function getMainDanceFloor(obj)
	local objList = require("Properties/Objects/List")
	if (not objList) or (#objList == 0) then return false; end
	local mainDanceFloor
	for i,v in ipairs(objList) do
		if objectIsValid(v) and objIsClose(obj, v) then
			local customName = getCustomName(v)
			if customName then
				if customName == "Disco Floor" and objIsMainDF(v) then
					mainDanceFloor = v
					break
				end
			end
		end
	end
	return mainDanceFloor
end

local function doConnectOption(thisPlayer, parentMenu, worldobjects, DanceFloor)
----------------Connect to system OR create new system
	local mainDF = getMainDanceFloor(DanceFloor)
	local text, hasMasterTxt, assignedTxt = "ContextMenu_DanceFloor_New", " <RED> "..getText('IGUI_Emote_No').." <LINE><RGB:0.9,0.9,0.9> ", 'Tooltip_DiscoFloor_Assign_Master'

	if mainDF then text, hasMasterTxt, assignedTxt = "ContextMenu_DanceFloor_Connect", " <GREEN> "..getText('IGUI_Emote_Yes').." <LINE><RGB:0.9,0.9,0.9> ",'Tooltip_DiscoFloor_Assign_Servant'; end
	if DanceFloor:getModData().IsMainDF then hasMasterTxt = " <GREEN> "..getText('Tooltip_DiscoFloor_IsMaster').." <LINE><RGB:0.9,0.9,0.9> "; end

	local dfoptionNew = parentMenu:addOption(getText(text),worldobjects,DanceFloorMenu.onConnect,thisPlayer,DanceFloor,mainDF)
	dfoptionNew.iconTexture = getTexture('media/ui/lightbulbOn_icon.png')

	if DanceFloor:getModData().Connected then
		dfoptionNew.notAvailable = true
		assignedTxt = 'Tooltip_DiscoFloor_Assigned'
	end
	hasMasterTxt = hasMasterTxt..getText(assignedTxt)

	local tpText = " <H2> "..getText('Tooltip_DiscoFloor_Header').." <BR><TEXT><ORANGE> "..getText('Tooltip_DiscoFloor_Master').." <LINE><RGB:0.9,0.9,0.9> "..getText('Tooltip_DiscoFloor_Master_1')..
	" <LINE><RGB:0.6,0.6,0.6> "..getText('Tooltip_DiscoFloor_Master_2').." <LINE><RGB:0.9,0.9,0.9> "..getText('Tooltip_DiscoFloor_Master_3', DanceFloorMenu.range).." <LINE><RGB:0.6,0.6,0.6> "..getText('Tooltip_DiscoFloor_Master_4')..
	" <LINE><RGB:0.9,0.9,0.9> "..getText('Tooltip_DiscoFloor_Master_5', DanceFloorMenu.mRange).." <LINE><RGB:0.6,0.6,0.6> "..getText('Tooltip_DiscoFloor_Master_6').." <BR><ORANGE> "..getText('Tooltip_DiscoFloor_Servant')..
	" <LINE><RGB:0.9,0.9,0.9> "..getText('Tooltip_DiscoFloor_Servant_1').." <LINE><RGB:0.6,0.6,0.6> "..getText('Tooltip_DiscoFloor_Servant_2').." <LINE><RGB:0.9,0.9,0.9> "..
	getText('Tooltip_DiscoFloor_Servant_3').." <LINE><RGB:0.6,0.6,0.6> "..getText('Tooltip_DiscoFloor_Servant_4').." <BR><ORANGE> "..getText('Tooltip_DiscoFloor_HasMaster').." <SPACE> "..hasMasterTxt

	dfoptionNew.toolTip = LSUtil.getSimpleTooltip(tpText, false)
end

DanceFloorMenu.doBuildMenu = function(player, context, worldobjects, DanceFloor, spriteName, customName, groupName, DebugBuildOption)
    local character = LSUtil.getValidPlayer(player)
	if LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character, character:getModData()) or not LSUtil.isValidObj(DanceFloor, spriteName) then return; end

	local objName = LSUtil.getMoveableDisplayName("DiscoFloor", DanceFloor, customName, groupName)
	local buildOption = context:addOptionOnTop(objName)
	buildOption.iconTexture = LSUtil.getObjTexture(spriteName, "E")
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)

	if not LSUtil.sqrHasEnergy(DanceFloor:getSquare()) then
		buildOption.notAvailable = true
		buildOption.toolTip = LSUtil.getSimpleTooltip(getText('IGUI_RadioRequiresPowerNearby'), false)
		return
	end

	doConnectOption(character, subMenu, worldobjects, DanceFloor)
end

DanceFloorMenu.onConnect = function(worldobjects, player, DanceFloor, mainDF)
	if luautils.walkAdj(player, DanceFloor:getSquare(), true) then
		ISTimedActionQueue.add(LSDFConnect:new(player, DanceFloor, mainDF));
	end
end
