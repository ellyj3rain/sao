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

SculptingContextMenu = {};

local function doNote(character, texture)
	local text = " <CENTRE> "..getText("IGUI_T_Art_Easel_Note")
	local infoText = " <LINE><H1> "..getText("IGUI_T_Art_Easel_Title").." <LINE> ".."<IMAGECENTRE:media/ui/tutorial/Painting_01.png> <LINE><LINE><TEXT> "..getText("IGUI_T_Art_Easel_Body").." <LINE><LINE> "..getText("IGUI_T_Art_Easel_Body2").." <LINE><LINE> "..getText("IGUI_T_Art_Easel_Body3").." <LINE><LINE> "..getText("IGUI_T_Art_Easel_Body4")
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, "tutorialArt", texture, 4, "noteEasel", infoText, true}) -- player, mainText, queueType, tex, time, closePerm, infoPanel, noSpam
end

local function getNewTooltip(description, texture, name)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	if texture then
		tooltip:setName(getText("Tooltip_Sculpting_"..tostring(name)))
		tooltip:setTexture(texture)
		--tooltip.footNote = getText("Tooltip_Sculpting_FootNote_List")
	end
	return tooltip
end

local function disableOption(option, tooltipDescription, iconTexture)
	option.notAvailable = true
	option.toolTip = getNewTooltip(tooltipDescription, false, false)
	if iconTexture then option.iconTexture = getTexture(iconTexture); end
end

local function getTooltipDesc(value, totalVal, stringName, color)
	return color .. stringName .. " " .. tostring(value) .. "/" .. tostring(totalVal) .. " <LINE>";
end

local function getItemsTable(key) -- Base.Coldpack could be used for Ice, but is too rare
	local t = {
		Hedge = {"Base.Dirtbag", 2, "Base.EmptySandbag"},
		Wood = {"Base.Log", 4, false},
		Metal = {"Base.ScrapMetal", 10, false},
		Stone = {"Base.Stone2", 10, false},
		Ice = {false, false, false}	
	}
	return t[key]
end

local function getSkillIconsTable(key)
	local t = {
		Art = "artpalette_icon",
		Farming = "naked_icon",
		Woodwork = "woodwork_icon",
		MetalWelding = "metalwork_icon",
	}
	return t[key]
end

local function getSkillIcon(skillName)
	local icon = getSkillIconsTable(skillName)
	if not icon then return ""; end
	return "<IMAGE:media/ui/"..icon..".png,16,16>"
end

local function getTexIcon(itemName)
	local prop
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and item:getFullName() and item:getFullName() == "Base."..itemName then
			prop = item:InstanceItem(item:getFullName())
			break
        end
    end
	local texString
	local itemText = itemName
	if prop then
		texString = "<IMAGE:"..prop:getTexture():getName()..",16,16>"
		itemText = prop:getName()
	end
	return texString, itemText
end

local function checkDisableOption(player, option, artSkill, material, bhs, ghs)
	local disable, color, skillName, playerSkill = false, ghs, PerkFactory.getPerkName(artSkill), player:getPerkLevel(artSkill)
	
	-- skill 1
	if playerSkill < material.num then color, disable = bhs, true; end
	local tooltipDesc = getTooltipDesc(playerSkill, material.num, getSkillIcon("Art")..getText(skillName), color)
	
	-- skill 2
	if material.skill then
		playerSkill = player:getPerkLevel(material.skill)
		if playerSkill < material.num2 then color = bhs; disable = true; else color = ghs; end
		skillName = PerkFactory.getPerkName(material.skill)
		local skillFullName = tostring(material.skill)
		local skillGlobalName = skillFullName:gsub("^Perks%.", "")
		tooltipDesc = tooltipDesc .. getTooltipDesc(playerSkill, material.num2, getSkillIcon(skillGlobalName)..getText(skillName), color)
	end

	-- res
	if material.res and material.res[1] then
		local invItem = player:getInventory():getItemCount(material.res[1], true)
		if invItem < material.res[2] then color = bhs; disable = true; else color = ghs; end
		local itemType = string.gsub(material.res[1], "^Base%.", "")
		local itemTexture, itemText = getTexIcon(itemType)
		if not itemTexture then itemTexture = ""; end
		tooltipDesc = tooltipDesc .. getTooltipDesc(invItem, material.res[2], itemTexture..itemText, color)
	end

	return disable, getText("Tooltip_craft_Needs") .. ": <LINE>" .. tooltipDesc
	--if disable then disableOption(option, getText("Tooltip_craft_Needs") .. ": <LINE>" .. tooltipDesc, false); end
end

local function getSubOptions()
	return {
	{name="Hedge",text="ContextMenu_Sculpting_AddBlock_Hedge",rgb=" <RGB:0,1,0>",texture="LS_Sculptures_12",num=3,skill=Perks.Farming,num2=6},
	{name="Wood",text="ContextMenu_Sculpting_AddBlock_Wood",rgb=" <RGB:1,1,0>",texture="LS_Sculptures_1",num=4,skill=Perks.Woodwork,num2=4},
	{name="Metal",text="ContextMenu_Sculpting_AddBlock_Metal",rgb=" <RGB:1,1,0>",texture="LS_Sculptures_63",num=6,skill=Perks.MetalWelding,num2=4},
	{name="Stone",text="ContextMenu_Sculpting_AddBlock_Stone",rgb=" <RGB:1,1,0>",texture="LS_Sculptures2_0",num=8,skill=false,num2=0},
	{name="Ice",text="ContextMenu_Sculpting_AddBlock_Ice",rgb=" <RGB:1,1,0>",texture="LS_Sculptures2_4",num=10,skill=false,num2=0},
	}
end

SculptingContextMenu.doBuildMenu = function(player, context, worldobjects, Station, spriteName, customName, groupName, DebugBuildOption)
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    if thisPlayer:getVehicle() or (thisPlayer:hasTimedActions()) then return; end
	
	if not Station then return; end

	doNote(thisPlayer, spriteName)

	local buildOption = context:addOptionOnTop(getText("ContextMenu_Sculpting_AddBlock"));
	buildOption.iconTexture = getTexture('media/ui/artpalette_icon.png')
	--buildOption.toolTip = getNewTooltip(getText("Tooltip_Sculpting_AddBlock"), false, false)
	
	local bhs, ghs = " <RGB:" .. getCore():getBadHighlitedColor():getR() .. "," .. getCore():getBadHighlitedColor():getG() .. "," .. getCore():getBadHighlitedColor():getB() .. "> ", " <RGB:" .. getCore():getGoodHighlitedColor():getR() .. "," .. getCore():getGoodHighlitedColor():getG() .. "," .. getCore():getGoodHighlitedColor():getB() .. "> "
	if thisPlayer:getPerkLevel(Perks.Art) < 3 then disableOption(buildOption, getText("Tooltip_craft_Needs") .. ": <LINE>" .. bhs .. getText("IGUI_perks_Art") .. " " .. tostring(thisPlayer:getPerkLevel(Perks.Art)) .. "/3" .. " <LINE>", false); return; end
	
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)

	local t = getSubOptions()
	for k, v in pairs(t) do
		v.res = getItemsTable(v.name)
		local option = subMenu:addOption(getText("ContextMenu_Sculpting_Title")..": "..getText(v.text),worldobjects,SculptingContextMenu.onAddBlock,thisPlayer,Station,v)
		local disable, newText = checkDisableOption(thisPlayer,option,Perks.Art,v, bhs, ghs)
		if disable then option.notAvailable = true; end
		option.toolTip = getNewTooltip(getText("Tooltip_Sculpting_A_"..v.name).." <RGB:0,1,0>".." <LINE><LINE>"..getText("Tooltip_Sculpting_B_"..v.name).." <RGB:1,1,1>".."<LINE><LINE>"..newText.." <RGB:1,1,0>".."<LINE>"..getText("Tooltip_Sculpting_C_"..v.name), v.texture, v.name)
	end
end

SculptingContextMenu.walkToFront = function(thisPlayer, thisObject)
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

SculptingContextMenu.onAddBlock = function(worldobjects, player, Station, block)
	if SculptingContextMenu.walkToFront(player, Station) then
		ISTimedActionQueue.add(LSSculptingNewAction:new(player, Station, 'LS_Sculptures_25', block.texture, block.name, block.res, false))
	end
end
