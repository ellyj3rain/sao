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

LSCleanRoomContextMenu = {};

local function getSquareDirt(thisSqr, hasGloves, glass)
	if not thisSqr then return false, false; end
	local listDirt = {"overlay_grime","trash&junk","trash_","d_floorleaves","d_trash","LS_Scraps"}
	if hasGloves then table.insert(listDirt,"brokenglass_"); end
	local listBlood = {"overlay_messages","overlay_graffiti","overlay_blood","LS_HScraps","blood_floor"}
	local blood, dirt = thisSqr:haveBlood(), false
	for j=0,thisSqr:getObjects():size()-1 do
		local object = thisSqr:getObjects():get(j)
		if object then
			local attachedsprite = object:getAttachedAnimSprite()
			local texName = object:getTextureName()
			local spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName()

			if not hasGloves and not glass and texName and luautils.stringStarts(texName, "brokenglass_") then glass = true; end
			if not dirt then
				for n=1, #listDirt do
					if texName and luautils.stringStarts(texName, listDirt[n]) then dirt = true; break; end
					if spriteName and luautils.stringStarts(spriteName, listDirt[n]) then dirt = true; break; end
					if attachedsprite then
						for i=1,attachedsprite:size() do
							local sprite = attachedsprite:get(i-1)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listDirt[n]) then dirt = true; break; end
						end
						if dirt then break; end
					end
				end
			end
			if not blood then
				for n=1, #listBlood do
					if texName and luautils.stringStarts(texName, listBlood[n]) then blood = true; break; end
					if spriteName and luautils.stringStarts(spriteName, listBlood[n]) then blood = true; break; end
					if attachedsprite then
						for i=1,attachedsprite:size() do
							local sprite = attachedsprite:get(i-1)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listBlood[n]) then blood = true; break; end
						end
						if blood then break; end
					end
				end
			end
		end
		if blood and dirt and (hasGloves or glass) then break; end
	end
	return blood, dirt, glass
end

local function getDirtyTiles(tileSqr, playerSqr, hasGloves)

	local lightList, heavyList = {}, {}
	local glass
	for x = tileSqr:getX()-4,tileSqr:getX()+4 do
		for y = tileSqr:getY()-4,tileSqr:getY()+4 do
			local thisSqr = getCell():getGridSquare(x,y,playerSqr:getZ())
			if thisSqr and thisSqr:isOutside() == playerSqr:isOutside() then
				local blood, dirt
				blood, dirt, glass = getSquareDirt(thisSqr, hasGloves, glass)
				if blood then table.insert(heavyList, thisSqr); end
				if dirt then table.insert(lightList, thisSqr); end
			end
		end
	end
	if hasGloves then glass = false; end
	return lightList, heavyList, glass
end

local function getCleaningItems(character)
	
	local list = {"Broom","Mop","Broom_Twig"}
	local items = {}
	for n=1, #list do
		local item = LSUtil.getItem(character, false, list[n])
		if item then items[list[n]] = item; end
	end
	
	items["Broom"] = items["Broom"] or items["Broom_Twig"]
	
	items["Bleach"] = LSUtil.getItemFluid(character, "Bleach", false, 5, false)

	return items
end

LSCleanRoomContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)
	local character = LSUtil.getValidPlayer(player)

	if LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character, character:getModData()) then return; end

    local tileSqr, playerSqr = false, character:getSquare()
	for i,v in ipairs(worldobjects) do
		tileSqr = v:getSquare()
		if tileSqr then break; end
	end
	if not tileSqr or not playerSqr then return; end

	local items = getCleaningItems(character)
	if not items["Broom"] and not items["Mop"] then return; end

	local hasGloves = character:getClothingItem_Hands()
	local lightList, heavyList, glassUnsafe = getDirtyTiles(tileSqr, playerSqr, hasGloves)

	local closestDirt = LSUtil.srqGetClosest(lightList, character)
	local closestBlood = LSUtil.srqGetClosest(heavyList, character)
	
	local canCleanLight = closestDirt and items["Broom"]
	local canCleanBlood = closestBlood and items["Mop"] and items["Bleach"]

	local optionCleaning = context:addOptionOnTop(getText("ContextMenu_CleanRoom"), worldobjects, LSCleanRoomContextMenu.onStartAction, character, closestDirt, closestBlood)
	local tex, desc = 'media/ui/broom_icon.png', getText('Tooltip_CleanRoom_Dirt')
	if canCleanBlood then tex, desc = 'media/ui/mop_icon.png', getText('Tooltip_CleanRoom_Blood'); end
	optionCleaning.iconTexture = getTexture(tex)
	
	if not canCleanBlood and not canCleanLight then
		optionCleaning.notAvailable = true
		if closestDirt and not (closestBlood and items["Mop"]) then desc = " <RED>" .. getText("Tooltip_CleanRoom_MissingItems") .. getText("Tooltip_CleanRoom_MissingItems_Broom");
		elseif closestBlood then
			desc = " <RED>" .. getText("Tooltip_CleanRoom_MissingItems")
			if not items["Mop"] then desc = desc .. getText("Tooltip_CleanRoom_MissingItems_Mop"); end
			if not items["Bleach"] then desc = desc .. getText("Tooltip_CleanRoom_MissingItems_Bleach"); end
		elseif items["Broom"] and glassUnsafe then desc = " <RED>" .. getText("Tooltip_CleanRoom_MissingItems") .. getText("Tooltip_CleanRoom_MissingItems_Gloves");
		else desc = " <RED>" .. getText("Tooltip_CleanRoom_NoDirt"); end
	end
	
	optionCleaning.toolTip = LSUtil.getSimpleTooltip(desc, false)

	if (closestDirt or closestBlood) and LSUtil.hasAdminRights() then	
		local debugMenu = DebugBuildOption:addOptionOnTop(getText("ContextMenu_LSDebug_Cleaning"))
		local subMenu = DebugBuildOption:getNew(DebugBuildOption)
		context:addSubMenu(debugMenu, subMenu)
		subMenu:addOptionOnTop(getText("ContextMenu_LSDebug_CleanRoom"), worldobjects, LSCleanRoomContextMenu.onCleanDebug, character:getSquare())
	end 

end

LSCleanRoomContextMenu.onStartAction = function(worldobjects, character, closestDirt, closestBlood)
	-- check conditions
	-- player is valid
	if LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character, character:getModData()) then return; end
	--print("LSCleanRoomContextMenu.onStartAction - player conditions satisfied")
	-- get items again
	local items = getCleaningItems(character)
	-- items are valid and dirt/blood still exists
	local canCleanLight, canCleanBlood
	local hasGloves = character:getClothingItem_Hands()
	if closestBlood and items["Mop"] and items["Bleach"] then
		local blood, dirt, glass = getSquareDirt(closestBlood, hasGloves, false)
		if blood then canCleanBlood = true; end
	end
	if not canCleanBlood and closestDirt and items["Broom"] then
		local blood, dirt, glass = getSquareDirt(closestDirt, hasGloves, false)
		if dirt then canCleanLight = true; end
	end
	if not canCleanLight and not canCleanBlood then return; end
	--print("LSCleanRoomContextMenu.onStartAction - canClean conditions satisfied")
	local tool, sqr, usesBleach
	if canCleanBlood and LSUtil.doItemTransfer(character, items["Bleach"]) then
		tool = items["Mop"]
		sqr = closestBlood
		usesBleach = true
	elseif canCleanLight then
		canCleanBlood = false
		tool = items["Broom"]
		sqr = closestDirt
	end
	if tool and LSUtil.doItemTransfer(character, tool) then LSUtil.doItemEquip(character, tool, false, true); else return; end
	if LSUtil.walkToAdjSqr(character, sqr) then
		local duration = LSCleaning.getCleaningTime(character, {"Floor", false, usesBleach and items["Bleach"]})
		ISTimedActionQueue.add(CleanRoomAction:new(character, tool, items, sqr, canCleanBlood, duration))
	end

end

LSCleanRoomContextMenu.onCleanDebug = function(worldobjects, square)
	if not square then return; end
	local sqrX, sqrY, sqrZ = square:getX(), square:getY(), square:getZ()
  	for x = sqrX-6,sqrX+6 do
		for y = sqrY-6,sqrY+6 do
			local square = getCell():getGridSquare(x,y,sqrZ)
			if square then
				for i=0,square:getObjects():size()-1 do
					if square:haveBlood() then
						square:removeBlood(false, false)
					end
				end
			end
		end
	end
	--if isClient() then
		sendClientCommand("LS", "RemoveDirtTileDebug", {sqrX, sqrY, sqrZ, 6})
	--end
end
