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
require "Properties/Player/AdminTestCM"
require "Helper/ContextHelper"

local function getAnyInteractionConditions(thisPlayer)
	if thisPlayer:getPerkLevel(Perks.Meditation) == 10 then return true; end
	if HiddenSkills.getLevel(thisPlayer,"Yoga") >= 10 then return true; end
	return false
end

local function isMouseOverSelf(square, thisPlayer)
	--[[ --getTileFromMouse is inconsistent
	local vector = UIManager.getTileFromMouse(getMouseX(), getMouseY(), z)
    local mX, mY = vector:getX(), vector:getY()
	print("LOG: ContextBuild - isMouseOverSelf - Player X = "..tostring(x)); print("LOG: ContextBuild - isMouseOverSelf - Mouse X = "..tostring(mX)); print("LOG: ContextBuild - isMouseOverSelf - Player Y = "..tostring(y)); print("LOG: ContextBuild - isMouseOverSelf - Mouse Y = "..tostring(mY));
    if (mX + w >= x) and (mY + h >= y) and (mX <= x + w) and (mY <= y + h) then return true; end
    return false;
	]]--
	--[[ --worldobjects can't get movingobjects
	if worldobjects and worldobjects[1] and instanceof(worldobjects[1], "IsoPlayer") and worldobjects[1]:getUsername() == thisPlayer:getUsername() then return true; end --first object is whatever was clicked directly
	return false
	--]]
	if not square then return false; end
	local x, y, sX, sY = thisPlayer:getX(), thisPlayer:getY(), square:getX(), square:getY()
	--print("LOG: ContextBuild - isMouseOverSelf - Player X = "..tostring(x)); print("LOG: ContextBuild - isMouseOverSelf - Square X = "..tostring(sX)); print("LOG: ContextBuild - isMouseOverSelf - Player Y = "..tostring(y)); print("LOG: ContextBuild - isMouseOverSelf - Square Y = "..tostring(sY)); print("LOG: ContextBuild - isMouseOverSelf - /-/ END LOG /-/");
	if (sX+2.5 >= x) and (sY+2.5 >= y) and (sX <= x+0.5) and (sY <= y+0.5) and (square:getZ() == thisPlayer:getZ()) then return true; end
	return false
end

local function isValidSelf(option, square, thisPlayer)
	if (not option.self) or (isMouseOverSelf(square, thisPlayer)) then return true; end
	return false
end

local function validItems(items)
	local isValid = true
	for n=1, #items do
		if items[n] ~= "none" then
			--tbd
		end
	end
	return isValid
end

local function hasRights(option)
	if not option.isdebug or (option.isdebug and LSUtil.hasAdminRights()) then return true; end
	return false
end

local function isValid(option, square, thisPlayer)
	if (option.contextname) and hasRights(option) and validItems({option.itemA, option.itemB, option.clothing}) and isValidSelf(option, square, thisPlayer) then return true; end
	return false
end

local function doSelfContextOptions(player, context, worldobjects, DebugBuildOption, square)
	local thisPlayer = getSpecificPlayer(player)
	if thisPlayer:hasTimedActions() then return; end

	local SelfContextNames = LSGetContextOptions(player,"contextSelfTable")
	local otherPlayer, otherPlayerInfo, InteractBuildOption

	if getAnyInteractionConditions(thisPlayer) then
		otherPlayer, otherPlayerInfo, InteractBuildOption = CanSeeTargetPlayer(worldobjects, player, context)
	end
	--sendClientCommand(getSpecificPlayer(player), "LS", "LSSCTest", {SelfContextNames})
	--local thisPlayer = getSpecificPlayer(player)
	--local TargetID = thisPlayer:getOnlineID()
	--local PlayerName = tostring(thisPlayer:getUsername())
	--local startImmediately
	--local LSSKAction = require("TimedActions/LSSKAction")
	--sendClientCommand(thisPlayer, "LS", "InteractionStart", {TargetID, PlayerName, LSSKAction, startImmediately, "SKmeditation"})

	if SelfContextNames and (#SelfContextNames > 0) then
		for k,v in pairs(SelfContextNames) do
			if isValid(v, square, thisPlayer) then
				if not v.ismp then
					v.contextname.doBuildMenu(player, context, worldobjects, DebugBuildOption)
				elseif otherPlayerInfo then
					v.contextname.doBuildMenu(player, context, worldobjects, otherPlayer, otherPlayerInfo, InteractBuildOption, DebugBuildOption)
				end
			end
		end
	end

end

local function doPrimaryHandItemContextOption(player, context, worldobjects, Item, ItemName, contextName)

	if contextName then
		contextName.doBuildMenu(player, context, worldobjects, Item, ItemName)
	end

end

local function isItemFromList(item, listItem)
	if (item == listItem) or (luautils.stringStarts(item, listItem)) or (string.find(item, listItem)) then return true; end
	return false
end

local function getPrimaryHandItemContextName(player, context, worldobjects)

	local thisPlayer = getSpecificPlayer(player)
	local item = thisPlayer:getPrimaryHandItem()
	if not item then return; end
	local ItemNames = LSGetContextOptions(player,"contextItemTable")

	if ItemNames and (#ItemNames > 0) then
		for k,v in pairs(ItemNames) do
			if isItemFromList(item:getFullType(), v.name) and ((v.cat == "all") or (v.cat == "WO")) and (not v.tag or item:hasTag(ItemTag[v.tag])) then
				doPrimaryHandItemContextOption(player, context, worldobjects, item, v.name, v.contextname)
				break
			end
		end
	end
end

local function getSecondObject(worldobjects, secondObjectName)

	local secondObject

	local objects = {}
	for _,object in ipairs(worldobjects) do
		local square = object:getSquare()
		if square then
			for i=1,square:getObjects():size() do
				local thisObject = square:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite then
				
					local properties = thisObject:getSprite():getProperties()

					if properties then
						local groupName = nil
						local customName = nil
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
							--print("GroupName: " .. groupName);
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
							--print("CustomName: " .. customName);
						end
						
						if customName and (customName == secondObjectName) then
							secondObject = thisObject
							break
						end
					end
				end
			end
			if secondObject then break; end
		end
	end

	return secondObject
end

local function getContextName(player, customName, groupName, worldobjects)

	local contextName
	local secondObject
	local WONames = LSGetContextOptions(player,"contextCGTable")
	--if customName and (customName == "Mirror") then print("CONTEXTNAME IS MIRROR"); end
	if WONames and (#WONames > 0) then
		--print("LSContextBuild getContextName")
		for k,v in pairs(WONames) do
			--print("getContextName customName and groupName"..v.customname.." and "..v.groupname)
			--if customName == v.customname then print("getContextName customName OK"); end; if groupName == v.groupname then print("getContextName groupname OK"); end
			if ((customName == v.customname) or (v.customname == "none")) and ((groupName == v.groupname) or (v.groupname == "none")) then
				--print("LSContextBuild found single")
				if v.multiple ~= "single" then
					secondObject = getSecondObject(worldobjects, v.multiple)
				end
				contextName = v.contextname
				break
			end
		end
	end

	return contextName, secondObject
end

local function getSecondObjectFromSprite(worldobjects, secondObjectName)

	local secondObject

	local objects = {}
	for _,object in ipairs(worldobjects) do
		local square = object:getSquare()
		if square then
			for i=1,square:getObjects():size() do
				local thisObject = square:getObjects():get(i-1)
				local thisSprite = thisObject:getSprite()
				
				if thisSprite then
					local thisSpriteName
					if thisSprite:getName() then
						thisSpriteName = thisSprite:getName()
						--print("Sprite Name is " .. spriteName)
					end
					if thisSpriteName and (thisSpriteName == secondObjectName) then
						secondObject = thisObject
						break
					end
				end
			end
			if secondObject then break; end
		end
	end

	return secondObject
end

local function getContextNameFromSprite(spriteName, worldobjects)

	local contextName, secondSpriteName, secondObject
	if (string.find(spriteName, "LS_Chairs")) then return LSSitCheckContextMenu, false, false; end 
	local WOSNames = require("Properties/ContextSNames")
	--if customName and (customName == "Mirror") then print("CONTEXTNAME IS MIRROR"); end
	if WOSNames and (#WOSNames > 0) then
		for k,v in pairs(WOSNames) do
			if (spriteName == v.spritename) and (v.multiple == "single") then
				contextName = v.contextname
				if v.secondspritename ~= "none" then secondSpriteName = v.secondspritename; end
				break
			elseif (spriteName == v.spritename) and (v.multiple ~= "single") then
				secondObject = getSecondObjectFromSprite(worldobjects, v.multiple)
				if secondObject then
					contextName = v.contextname
					if v.secondspritename ~= "none" then secondSpriteName = v.secondspritename; end
					break
				end
			end
		end
	end

	return contextName, secondSpriteName, secondObject
end


local function doContextOption(player, context, worldobjects, thisObject, spriteName, customName, groupName, contextName, secondObject, DebugBuildOption)

--	if contextName == "hygiene" and ShowerContextMenu then
--		ShowerContextMenu.doBuildMenu(player, context, worldobjects, thisObject, spriteName, customName, groupName)
--	elseif contextName == "bladderToilet" and ToiletContextMenu then
--		ToiletContextMenu.doBuildMenu(player, context, worldobjects, thisObject, spriteName, customName, groupName)
--	elseif contextName == "hygieneCabinet" and ToiletContextMenu then
--		CabinetContextMenu.doBuildMenu(player, context, worldobjects, thisObject, spriteName, customName, groupName, secondObject)
--	end

	if contextName and secondObject then
		contextName.doBuildMenu(player, context, worldobjects, thisObject, spriteName, customName, groupName, DebugBuildOption, secondObject)
	elseif contextName then
		contextName.doBuildMenu(player, context, worldobjects, thisObject, spriteName, customName, groupName, DebugBuildOption)
	end

end

local function doAltContextBuild(player, thisPlayer, context, worldobjects, square, DebugBuildOption)

	local contextName, secondObject

  	for x = square:getX()-0.5,square:getX()+0.5 do
		for y = square:getY()-0.5,square:getY()+0.5 do
			local gridSquare = getCell():getGridSquare(x,y,thisPlayer:getZ())
			if gridSquare then
				for i=0,gridSquare:getObjects():size()-1 do
					local thisObject = gridSquare:getObjects():get(i);
					if thisObject then
						local sprite
						local thisSprite
						local attachedsprite = thisObject:getAttachedAnimSprite()
						if attachedsprite then
							for n=1,attachedsprite:size() do
								sprite = attachedsprite:get(n-1)
								if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() and 
								(luautils.stringStarts(sprite:getParentSprite():getName(), "walls_decoration")) then
									thisSprite = sprite:getParentSprite()
									--if thisSprite:getName() then print("Sprite Name is " .. thisSprite:getName()); end
									break
								end
							end
						end
						if thisSprite then
							local properties = thisSprite:getProperties()
							if properties then
								local groupName = nil
								local customName = nil
								local thisSpriteName = nil
					
								if thisSprite:getName() then
									thisSpriteName = thisSprite:getName()
									--print("Sprite Name is " .. thisSpriteName)
								end
					
								if properties:has("GroupName") then
									groupName = properties:get("GroupName")
									--print("GroupName: " .. groupName);
								end
					
								if properties:has("CustomName") then
									customName = properties:get("CustomName")
									--if customName and (customName == "Mirror") then print("CUSTOMNAME IS MIRROR"); end
									--print("CustomName: " .. customName);
								end

								if customName or groupName then
									contextName, secondObject = getContextName(player, customName, groupName, worldobjects)
									if contextName then
										doContextOption(player, context, worldobjects, thisObject, thisSpriteName, customName, groupName, contextName, secondObject, DebugBuildOption)
										break
									end
								end
							end
						end
					end
				end
			end
			if contextName then break; end
		end
		if contextName then break; end
	end

end

local function contextIsDuplicate(t, spriteName)
	if #t == 0 then return false; end
	local isDuplicate
	for n=1, #t do
		if t[n] == spriteName then
			isDuplicate = true
			break
		end
	end
	return isDuplicate
end

function LSContextBuild(player, context, worldobjects)

	local thisPlayer = getSpecificPlayer(player)
	if thisPlayer:isDead() then return; end

	local DebugBuildOption

	if LSUtil.hasAdminRights() then

		local DebugContextMain = context:addOption(getText("ContextMenu_LSDebug_Main"));
		DebugContextMain.iconTexture = getTexture('media/ui/BugIcon.png')

		DebugBuildOption = ISContextMenu:getNew(context);
		context:addSubMenu(DebugContextMain, DebugBuildOption)

	end

	--local hasOptions
	local contextSpriteNames = {}
	local square
	for _,object in ipairs(worldobjects) do
		square = object:getSquare()
		if square then
			for i=1,square:getObjects():size() do
				--print("FOUND OBJECT")
				local contextName, secondObject
				local thisObject = square:getObjects():get(i-1)
				local thisSpriteName, thisSprite, groupName, customName = false, thisObject:getSprite(), false, false
				--if thisObject:getName() then print("thisObject Name is " .. thisObject:getName()); end
				--if thisObject:getObjectName() then print("thisObject getObjectName is " .. thisObject:getObjectName()); end
				--if thisObject:getSpriteName() then print("thisObject getSpriteName is " .. thisObject:getSpriteName()); end
				--if thisObject:getTextureName() then print("thisObject getTextureName is " .. thisObject:getTextureName()); end

				if thisSprite then
					if thisSprite:getName() then
						thisSpriteName = thisSprite:getName()
						--print("LSContextBuild Sprite Name is " .. thisSpriteName)
					end
					local properties = thisObject:getSprite():getProperties()
					if properties ~= nil then

						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
							--print("LSContextBuild GroupName: " .. groupName);
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
							--print("LSContextBuild CustomName: " .. customName);
						end
						
						if customName or groupName then
							--print("LSContextBuild getContextName")
							contextName, secondObject = getContextName(player, customName, groupName, worldobjects)
							if contextName and (not contextIsDuplicate(contextSpriteNames, thisSpriteName)) then
								--print("LSContextBuild doContextOption")
								table.insert(contextSpriteNames, thisSpriteName)
								doContextOption(player, context, worldobjects, thisObject, thisSpriteName, customName, groupName, contextName, secondObject, DebugBuildOption)
								--break
							end
						end
					end
				end
				if not contextName then
					thisSpriteName = thisObject:getSpriteName()
					if not thisSpriteName then thisSpriteName = thisObject:getTextureName(); end
					if thisSpriteName then
						contextName, customName, secondObject = getContextNameFromSprite(thisSpriteName, worldobjects)
						if contextName and (not contextIsDuplicate(contextSpriteNames, thisSpriteName)) then
							table.insert(contextSpriteNames, thisSpriteName)
							doContextOption(player, context, worldobjects, thisObject, thisSpriteName, customName, groupName, contextName, secondObject, DebugBuildOption)
							--break
						end
					end
				end
			end
			--if contextName then break; end
		end
	end

	if thisPlayer:getPrimaryHandItem() then
		getPrimaryHandItemContextName(player, context, worldobjects)
	end
	
	if square and (#contextSpriteNames == 0) then doAltContextBuild(player, thisPlayer, context, worldobjects, square, DebugBuildOption); end
	doSelfContextOptions(player, context, worldobjects, DebugBuildOption, square)
	
end

Events.OnFillWorldObjectContextMenu.Add(LSContextBuild)

local function doInventoryItemContextOption(player, context, items, item, contextName, isHotbar)
	if contextName then
		if isHotbar then
			contextName.doHotbarMenu(player, context, items, item)
		else
			contextName.doInventoryMenu(player, context, items, item)
		end
	end
end

function LSContextBuildItemPreFillInventory(player, context, items)
	local thisPlayer = getSpecificPlayer(player)
	local invItems = ISInventoryPane.getActualItems(items)
	local isItem
	local ItemNames = LSGetContextOptions(player,"contextItemTable")
	if ItemNames and (#ItemNames > 0) then
		for k,v in pairs(ItemNames) do
			for i,item in ipairs(invItems) do
				if isItemFromList(item:getFullType(), v.name) and ((v.cat == "all") or (v.cat == "PF")) and (not v.tag or item:hasTag(ItemTag[v.tag])) then
					doInventoryItemContextOption(player, context, items, item, v.contextname, false)
					break
				end
			end
			if isItem then break; end
		end
	end
end

local function getRecipeIconsTable()
	return {
	{name="Lifestyle.Make Bucket of Water and Bleach",texture="mop_icon"},
	{name="Lifestyle.Fill Empty Palette with Paint",texture="artpalette_icon"},
	}
end

function getRecipeIcons(context)
	local option, recipeName, t = false, false, getRecipeIconsTable()
	for k, v in pairs(t) do
		local getRecipeItem = getScriptManager():getRecipe(v.name)
		if getRecipeItem then recipeName = getRecipeItem:getName(); end
		if recipeName then option = context:getOptionFromName(recipeName); end
		if option then option.iconTexture = getTexture('media/ui/'..v.texture..'.png'); end
	end
end


function LSContextBuildItemFillInventory(player, context, items)
	local thisPlayer = getSpecificPlayer(player)
	local invItems = ISInventoryPane.getActualItems(items)
	local ItemNames = LSGetContextOptions(player,"contextItemTable")
	if ItemNames and (#ItemNames > 0) then
		for k,v in pairs(ItemNames) do
			for i,item in ipairs(invItems) do
				if isItemFromList(item:getFullType(), v.name) and ((v.cat == "all") or (v.cat == "FI")) and (not v.tag or item:hasTag(ItemTag[v.tag])) then
					doInventoryItemContextOption(player, context, items, item, v.contextname, true)
					break
				end
			end
		end
	end

	getRecipeIcons(context)
end

Events.OnPreFillInventoryObjectContextMenu.Add(LSContextBuildItemPreFillInventory)
Events.OnFillInventoryObjectContextMenu.Add(LSContextBuildItemFillInventory)





