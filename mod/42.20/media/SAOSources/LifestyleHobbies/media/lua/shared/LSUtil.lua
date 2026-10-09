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

LSUtil = {}
LSUtil.rdm_inst = newrandom() -- LSUtil.rdm_inst:random(n) returns 1 - n / :random()*n returns 0 - n / :random(n1,n2) returns n1 - n2

local function getLitterChanceRoll(sandboxOption)
	local roll = 200
	if (not sandboxOption) or (not tonumber(sandboxOption)) then print("WARNING: getLitterChanceRoll failed to get sandboxOption value"); return roll; end
	if sandboxOption == 1 then
		roll = 600
	elseif sandboxOption == 2 then
		roll = 400
	elseif sandboxOption == 4 then
		roll = 100
	end
	return roll
end

function LSUtil.canLitter(chance)
	if chance <= 0 then return false; end
	local maxRoll = getLitterChanceRoll(SandboxVars.LSHygiene.CleaningLitterChance)
	local doRoll = ZombRand(maxRoll)+1
	if doRoll <= chance then return true; end
	return false
end

function LSUtil.StringStartWith(String,Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

function LSUtil.deepCopy(orig, seen)
	if type(orig) ~= "table" then return orig end
	if seen and seen[orig] then return seen[orig] end

	local copy = {}
	seen = seen or {}
	seen[orig] = copy

	for k, v in pairs(orig) do
		copy[LSUtil.deepCopy(k, seen)] = LSUtil.deepCopy(v, seen)
	end

	return setmetatable(copy, getmetatable(orig))
end

function LSUtil.throwDice(odds, minusThan, moreThan)
	local roll = ZombRand(odds)+1
	local exactNum = not moreThan and not minusThan
	return (exactNum and roll == odds) or (minusThan and roll < minusThan) or (moreThan and roll > moreThan)
end

function LSUtil.getRandomNumbers(total, limit, array)
	local nums = {}
	for i = 1, total do
		table.insert(nums, i)
	end

	for i = #nums, 2, -1 do
		local j = ZombRand(i)+1
		nums[i], nums[j] = nums[j], nums[i]
	end

	local result = {}
	local maxPick = math.min(limit, #nums)

	for i = 1, maxPick do
		if array then -- {5, 3, 7, ...}
			result[#result + 1] = nums[i]
		else -- {[5]=true,[3]=true,...}
			result[nums[i]] = true
		end
	end

	return result
end

function LSUtil.getRandomOddNumbers(total, limit, array)
	local odds = {}
	for i = 1, total, 2 do
		table.insert(odds, i)
	end

	for i = #odds, 2, -1 do
		local j = ZombRand(i)+1
		odds[i], odds[j] = odds[j], odds[i]
	end

	local result = {}
	local maxPick = math.min(limit, #odds)

	for i = 1, maxPick do
		if array then -- {5, 3, 7, ...}
			result[#result + 1] = odds[i]
		else -- {[5]=true,[3]=true,...}
			result[odds[i]] = true
		end
	end

	return result
end

function LSUtil.getRandomKeys(srcTable, limit, array, exclude)
	local nums = {}
	
	for k, v in pairs(srcTable) do
		if not exclude or not exclude[k] then table.insert(nums, tostring(k)); end
	end

	for i = #nums, 2, -1 do
		local j = LSUtil.rdm_inst:random(i)
		nums[i], nums[j] = nums[j], nums[i]
	end

	local result = {}
	local maxPick = math.min(limit, #nums)

	for i = 1, maxPick do
		if array then -- {5, 3, 7, ...}
			result[#result + 1] = nums[i]
		else -- {[5]=true,[3]=true,...}
			result[nums[i]] = true
		end
	end

	return result
end

function LSUtil.getNewParam(oldParam, paramTable)
	local t = paramTable
	if oldParam then
		t = {}
		for n=1, #paramTable do
			if paramTable[n] ~= oldParam then table.insert(t, paramTable[n]); end
		end
	end
	local newParam = LSUtil.rdm_inst:random(#t)
	return t[newParam]
end

------------ UI

function LSUtil.doNote(character, args)  -- args = {text, queueType, tex, time, closePerm, infoPanel, noSpam, TextureCustomProps(w,h,size)}
	if not LSUtil.getValidCharacter(character) then return; end
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]}) -- player, mainText, queueType, tex, time, closePerm, infoPanel, noSpam, TextureCustomProps(w,h,size)
	--	note args cheat sheet
	--	1. queueType - "TutorialYoga" - game won't queue notes of same type
	--	2. time - NUMBER - how long note will stay on screen before disappearing. n = real seconds
	--	3. closePerm - "noteYoga" - if note can be closed permanently (don't do this for repeatables like art)
	--	4. infoPanel - richText - add info panel text, otherwise info option won't appear
	--	5. noSpam - BOOLEAN - if note should only appear once per session
	--	6. TextureCustomProps - TABLE - texture is a custom image (not a tile texture). Must provide placement position (width and height) and image size.
end

function LSUtil.splitFullType(fullName)
    local dot = string.find(fullName, ".", 1, true)

    if not dot then return nil, fullName; end

    local moduleName = string.sub(fullName, 1, dot - 1)
    local itemName = string.sub(fullName, dot + 1)

    return moduleName, itemName
end

function LSUtil.splitLiteral(str, separator)
	local result = {}

	if not str then return result; end
	if not separator or separator == "" then
		table.insert(result, str)
		return result
	end

	local startPos = 1

	while true do
		local sepStart, sepEnd = string.find(str, separator, startPos, true)

		if not sepStart then
			table.insert(result, string.sub(str, startPos))
			break
		end

		table.insert(result, string.sub(str, startPos, sepStart - 1))
		startPos = sepEnd + 1
	end

	return result
end

function LSUtil.doRichTextType(x,y,w,h,customText,font,r,g,b)
	local newRichText = ISRichTextPanel:new(x, y, w, h)
	newRichText.backgroundColor = {r=0, g=0, b=0, a=0}
	newRichText.text = customText
	newRichText.defaultFont = font
	newRichText.autosetheight = false
	newRichText.marginLeft = 0
	newRichText.marginTop = 0
	newRichText.marginRight = 0
	newRichText.marginBottom = 0
	newRichText.textR = r
	newRichText.textG = g
	newRichText.textB = b
	return newRichText
end

function LSUtil.measureString(textManager, axis, fontType, text)
	if not textManager then textManager = getTextManager(); end
	local measureY
	if axis == "XY" then axis, measureY = "X", textManager['MeasureStringY'](textManager, fontType, text); end
	return textManager['MeasureString'..axis](textManager, fontType, text), measureY
end

local function getSkillIconsTable(key)
	local t = {
		Art = "artpalette_icon",
		Blacksmith = "blacksmith_icon",
		Farming = "naked_icon",
		Woodwork = "woodwork_icon",
		MetalWelding = "metalwork_icon",
		Electricity = "electrical_icon",
		Mechanics = "mechanics_icon",
		Maintenance = "maintenance_icon",
	}
	return t[key]
end

function LSUtil.getSkillIcon(skillName)
	local icon = getSkillIconsTable(skillName)
	if not icon then return ""; end
	return "<IMAGE:media/ui/"..icon..".png,16,16>"
end

function LSUtil.getObjTexAndText(spriteName)
	local texture
	local name = LSUtil.getMoveableDisplayName(spriteName, nil, nil, nil, spriteName)
	local sprite = getTexture(spriteName)
	if sprite then texture = sprite:splitIcon(); end
	return texture, name
end

function LSUtil.getItemIconString(fullType)
	local itemIcon
	local item = getScriptManager():FindItem(fullType)
	if item then
		local icon = (item:getIconsForTexture() and not item:getIconsForTexture():isEmpty() and item:getIconsForTexture():get(0)) or item:getIcon()
		if icon then
			itemIcon = "Item_" .. icon
		end
	end
	return itemIcon or "media/ui/okayNo_icon.png"
end

function LSUtil.getItemTexAndTextNew(fullType)
	--local prop
	local itemTexture
	local itemText = fullType
	local item = getScriptManager():FindItem(fullType)
	if item then
		itemText = item:getDisplayName()
		local icon = (item:getIconsForTexture() and not item:getIconsForTexture():isEmpty() and item:getIconsForTexture():get(0)) or item:getIcon()
		if icon then
			itemTexture = tryGetTexture("Item_" .. icon)
		end
	end
	return itemTexture, itemText
end

function LSUtil.getIconStrAndName(fullType, size)
	local texSize = size or "16,16"
	local texString = ""
	local itemTexture, itemText = LSUtil.getItemTexAndTextNew(fullType)
	if itemTexture then texString = "<IMAGE:"..itemTexture:getName()..","..texSize..">"; end
	return texString, itemText
end

function LSUtil.getItemTexAndText(itemName, moduleName, fullName)
	local mod = moduleName or "Base"
	--local prop
	local itemTexture
	local itemText = itemName or fullName
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
		local itemFullName = item and item.getFullName and item:getFullName() -- method for Item class (script)
		--local itemFullType = item and item.getFullType and item:getFullType() -- returns nil before instanced (only for InventoryItem class)
		if itemFullName and ((fullName and itemFullName == fullName) or (itemName and itemFullName == mod.."."..itemName)) then
			local prop = instanceItem(item)
			itemTexture = prop:getTexture()
			itemText = prop:getName()
			break
		end
    end
	--local texString = ""
	--local itemText = itemName or fullName
	--if prop then
	--	texString = "<IMAGE:"..prop:getTexture():getName()..",16,16>"
	--	itemText = prop:getName()
	--end
	return itemTexture, itemText
end

function LSUtil.fixTexIconPath(texName)
	if not isClient() or not string.find(texName, "Lifestyle") then return texName; end
	local markers = {"\\common\\", "/common/"}
	for n=1,#markers do
		local marker = markers[n]
		local common = string.find(texName, marker, 1, true)
		if common then
			return string.sub(texName, common + string.len(marker))
		end
	end
	return texName
end

function LSUtil.getTexIcon(itemName, moduleName, fullName)
	local texString = ""
	local itemTexture, itemText = LSUtil.getItemTexAndText(itemName, moduleName, fullName)
	if itemTexture then
		local texName = LSUtil.fixTexIconPath(itemTexture:getName())
		texString = "<IMAGE:"..texName..",16,16>"
	end
	return texString, itemText
end

function LSUtil.getObjContextMenu(context, spriteName)
	local subMenu
	local objTex, objName = LSUtil.getObjTexAndText(spriteName)
    for i = 1, #context.options do
        local option = context.options[i]
        if option and option.name and option.name == objName then
			if option.subOption ~= nil then subMenu = context:getSubMenu(option.subOption); end
			if not subMenu then
				subMenu = ISContextMenu:getNew(context)
				context:addSubMenu(option, subMenu)
            end
			return subMenu
		end
    end
	local option = context:addOptionOnTop(objName)
	option.iconTexture = objTex
	subMenu = ISContextMenu:getNew(context)
	context:addSubMenu(option, subMenu)
    return subMenu
end

------------ Tooltip

function LSUtil.getSimpleTooltip(description, background)
	local tooltip = ISToolTip:new();
	if background then tooltip.backgroundColor = background; tooltip.descriptionPanel.backgroundColor = background; end
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	return tooltip
end

function LSUtil.getNewTooltip(description, texture, name, footNote, lineWidth, background)
	local tooltip = LSUtil.getSimpleTooltip(description, background)
	if name then tooltip:setName(name); end
	if texture then tooltip:setTexture(texture); end
	if footNote then tooltip.footNote = footNote; end
	if lineWidth then tooltip.maxLineWidth = lineWidth; tooltip:doLayout(); end
	return tooltip
end

function LSUtil.getToolTipItemRequirement(val, totalVal, stringName)
	if totalVal == 0 then return ""; end
	local color = " <RGB:0.6,1,0.6>"
	if val == 0 then color = " <RGB:1,0.5,0.5>"; elseif val < totalVal then color = " <RGB:1,1,0.5>"; end
	return color .. stringName .. " " .. tostring(val) .. "/" .. tostring(totalVal) .. " <LINE>";
end

------------ Halo

function LSUtil.doSimpleArrowHalo(character, description, pos)
	if not description then return; end
	local rgb = {255, 120, 120}
	if pos then rgb = {170, 255, 150}; end
	HaloTextHelper.addTextWithArrow(character, description, not pos, rgb[1], rgb[2], rgb[3])
end

------------ Context

function LSUtil.getDummyOption(parentMenu, name, tooltipText, tex, add, disable)
	local option = parentMenu[add](parentMenu, name)
	option.notAvailable = disable
	if tooltipText then option.toolTip = LSUtil.getSimpleTooltip(tooltipText); end
	if tex then option.iconTexture = tex; end
	return option
end

------------ Calc

function LSUtil.round(num, decimals)
     local mult = 10 ^ (decimals or 0)
	 return math.floor(num * mult + 0.5) / mult
end

function LSUtil.truncateToTwoDecimals(num)
    local s = tostring(num)
    local dot = string.find(s, "%.")
    if dot then
        local decimals = string.sub(s, dot + 1)
        if #decimals > 2 then
            return math.floor(num * 100) / 100
        end
    end
    return num
end

function LSUtil.getPercentage(total,value,decimals,isModifier)
	-- returns the percentage of value, based on total being 100%
	if not total or total == 0 then return 0; end
	if total == value then return 100; end
	local percentage = (value/total)*100
	local mult = 1
	if decimals then
		mult = 10^decimals -- 10, 100, 1000...
	end
	local clean100 = 0
	if total == 1 and isModifier then clean100 = 100; end -- for modifiers
	return math.floor((percentage*mult+0.5)-clean100)/mult
	--return math.floor(percentage*mult+0.5)/mult-clean100
end

------------ Square

function LSUtil.walkToSqr(character, sqr, behavior, clearActions)
	if not sqr then return false; end
	if clearActions then ISTimedActionQueue.clear(character); end
	local action
	if behavior then
		action = ISWalkToTimedAction:new(character, sqr,
		function(character) return not character[behavior](character); end,
		character)
	else
		action = ISWalkToTimedAction:new(character, sqr)
	end
	ISTimedActionQueue.add(action)
	return action
end

function LSUtil.walkToAdjSqr(character, sqr)
	if not sqr then return false; end
	-- get nearest adj square
	local adjSqr = AdjacentFreeTileFinder.Find(sqr, character)
	-- do walk
	if adjSqr then
		local action = ISWalkToTimedAction:new(character, adjSqr)
		ISTimedActionQueue.add(action)
		return action
	end
	return false
end

function LSUtil.walkToAdj(character, obj)
	if not LSUtil.isValidObj(obj, "nil") then return false; end
	return LSUtil.walkToAdjSqr(character, obj:getSquare())
end

function LSUtil.srqGetClosest(list, character)
	if #list == 0 then return false; end
	local lowestdist = 100000
	local distchoice
	--local playerSqr = character:getSquare()
	for k, v in ipairs(list) do
		--if v and AdjacentFreeTileFinder.privTrySquare(playerSqr, v) then
		if v and AdjacentFreeTileFinder.Find(v, character) then
			local dist = v:DistToProper(character)
			if dist < lowestdist then
				distchoice, lowestdist = v, dist
			end
		end
	end	
	return distchoice
end

function LSUtil.sqrHasEnergy(sqr)
	return sqr:haveElectricity() or (SandboxVars.ElecShutModifier > -1 and GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier)
end

------------ Objects

LSUtil.pianoPos = false

function LSUtil.modifyOverlaySprite(obj, sprite)
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()}, sprite})
		return
	end
	obj:setOverlaySprite(sprite, false)
end

function LSUtil.getObjSpriteName(obj)
	local sprite = obj.getSprite and obj:getSprite()
	local spriteName = sprite and sprite:getName()
	if not spriteName then spriteName = (obj.getSpriteName and obj:getSpriteName()) or (obj.getTextureName and obj:getTextureName()); end
	return spriteName or "none"
end

function LSUtil.getObjCustomName(obj)
	if not obj or not instanceof(obj, "IsoObject") then return false; end
	local properties = obj:getSprite() and obj:getSprite():getProperties()
	return properties and properties:has("CustomName") and properties:get("CustomName")
end

function LSUtil.updateObjData(obj, upSprite, spriteName)
	if upSprite then sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()}, spriteName}); end
	sendClientCommand("LS", "ModifyObjData", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()}, false, obj:getModData()})
end

function LSUtil.getMoveableDisplayName(genName, obj, cN, gN, sN)
	if cN and gN then return Translator.getMoveableDisplayName(gN.." "..cN); end
	local sprite = (sN and getSprite(sN)) or (obj and instanceof(obj, "IsoObject") and obj.getSprite and obj:getSprite())
	local props = sprite and sprite.getProperties and sprite:getProperties()
    if props then
		local name
		local cName = props:has("CustomName")
        if props:has("GroupName") then
            name = props:get("GroupName")
			if cName then name = name .. " " .. props:get("CustomName"); end
		elseif cName then
			name = props:get("CustomName")
        end
        if name then return Translator.getMoveableDisplayName(name); end
    end
    return tostring(genName)	
end

function LSUtil.isObjOnSqr(obj)
	local sqr = obj:getSquare()
	if not sqr then return false; end
	for i=0,sqr:getObjects():size()-1 do
		local thisObject = sqr:getObjects():get(i)
		if LSUtil.isValidObj(thisObject, "ignore this warning") and thisObject == obj then return true; end
	end
	return false
end

function LSUtil.isValidObj(obj, spriteName)
	if not obj or not instanceof(obj, "IsoObject") then LSUtil.debugPrint("LSUtil.isValidObj - obj is NIL, spriteName: "..tostring(spriteName)); return false; end
	return true
end

function LSUtil.isObjClose(obj, character, range)
	if character:getX() >= obj:getX() - range and character:getX() <= obj:getX() + range and
	character:getY() >= obj:getY() - range and character:getY() <= obj:getY() + range then return true; end
	return false
end

function LSUtil.isObjClosePrecise(obj, character, range) -- obj getX, getY returns top corner so we add 0.5 to get center
	local objX, objY = obj:getX()+0.5, obj:getY()+0.5
	if obj:getZ() == character:getZ() and character:getX() >= objX - range and character:getX() <= objX + range and
	character:getY() >= objY - range and character:getY() <= objY + range then return true; end
	return false
end

function LSUtil.isObjSameSqr(obj, character)
	return not obj:getSquare() ~= character:getSquare()
end

function LSUtil.getObjTexture(spriteName, dir)
	local texture = getSprite(spriteName):getTextureForCurrentFrame(IsoDirections[dir])
	return texture
end

local function getFacing(obj)
	local properties = obj:getSprite():getProperties()
	if properties:has("Facing") then return properties:get("Facing"); end
	return false
end

function LSUtil.walkToFront(character, obj, behavior, customFace)
	if not LSUtil.isValidObj(obj, "nil") then return false; end
	-- get square
	local sqr = obj:getSquare()
	if not sqr then return false; end
	-- get obj face
	local facing = customFace or getFacing(obj)
	if not facing then return false; end
	-- get front square
	--local frontSqr = sqr["get"..facing](sqr)
	local frontSqr = sqr:getAdjacentSquare(IsoDirections[facing])
	if not frontSqr then return false; end
	-- do walk
	if AdjacentFreeTileFinder.privTrySquare(sqr, frontSqr) or AdjacentFreeTileFinder.isTileOrAdjacent(character:getCurrentSquare(), frontSqr) then
		local walkAction
		if behavior then
			walkAction = ISWalkToTimedAction:new(character, frontSqr,
			function(character) return not character[behavior](character); end,
			character)
		else
			walkAction = ISWalkToTimedAction:new(character, frontSqr)
		end
		ISTimedActionQueue.add(walkAction)
		return walkAction
	end
	return false
end

-- should only be used for short walks
function LSUtil.walkTo(character, location)
	character:getPathFindBehavior2():pathToLocation(location[1], location[2], location[3])
end

---------- Items

function LSUtil.getItemNameFromFullType(itemFullName)
	return Translator.getItemNameFromFullType(itemFullName)
end

function LSUtil.getMoveableItemProp(spriteName)
	local prop = instanceItem('Moveables.Moveable')
	prop:ReadFromWorldSprite(spriteName)
	return prop
end

function LSUtil.getItemProp(itemName, mod)
	if not itemName and not mod then return false; end
	itemName = itemName or ""
	if not mod then mod = "Base."; end
	local prop
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
		local fullName = item and item.getFullName and item:getFullName()
        if fullName and fullName == mod..itemName then
			--prop = item:InstanceItem(item:getFullName())
			prop = instanceItem(fullName)
			break
        end
    end
	return prop
end

function LSUtil.hasRoomForProp(container, character, itemName, mod, isMoveable)
	local prop = (isMoveable and LSUtil.getMoveableItemProp(itemName)) or LSUtil.getItemProp(itemName, mod)
	return prop and container:hasRoomFor(character, prop)
end

function LSUtil.getItemParent(item)
	local cont = item.getContainer and item:getContainer()
	return cont and cont.getParent and cont:getParent()
end

function LSUtil.getAllItems(cont) -- returns all items inside a container (including nested)
	local predicateItem = function(item)
		return item and instanceof(item, "InventoryItem")
	end
	return cont:getAllEvalRecurse(predicateItem)
end

function LSUtil.isEquippedClothing(character, names)
	local inventory = character:getInventory()	
	local it = inventory:getItems()
	for j = 0, it:size()-1 do
		local item = it:get(j)
		for n=1, #names do
			local itemName = names[n]
			if item:getFullType() == itemName and character:isEquippedClothing(item) then
				return true
			end
		end
	end
	return false
end

function LSUtil.doItemTransfer(character, targetItem, previousAction)
	if instanceof(targetItem, "InventoryItem") then
		local transferAction = previousAction or true
		if luautils.haveToBeTransfered(character, targetItem) then
			transferAction = ISInventoryTransferAction:new(character, targetItem, targetItem:getContainer(), character:getInventory())
			if previousAction then ISTimedActionQueue.addAfter(previousAction, transferAction);
			else ISTimedActionQueue.add(transferAction); end
		end
		return transferAction
	elseif instanceof(targetItem, "ArrayList") then
		local items = targetItem
		local lastTransferAction = previousAction or true
		for i=1,items:size() do
			local item = items:get(i-1)
			if luautils.haveToBeTransfered(character, item) then
				local transferAction = ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory())
				if previousAction then ISTimedActionQueue.addAfter(lastTransferAction, transferAction);
				else ISTimedActionQueue.add(transferAction); end
				lastTransferAction = transferAction
			end
		end
		return lastTransferAction
	end
	return false
end

function LSUtil.canEquipItem(character, item, primary, twoHands)
	if not instanceof(item, "InventoryItem") then return false; end
	if (primary or twoHands) and character:getPrimaryHandItem() == item then return false; end
	if not primary and not twoHands and character:getSecondaryHandItem() == item then return false; end
	return true
end

function LSUtil.doItemEquip(character, item, primary, twoHands, lastAction)
	local action = lastAction or true
	local equipAction
	if item.IsClothing and item:IsClothing() then
		if character:isEquippedClothing(item) then return action; end
		equipAction = ISWearClothing:new(character,item,50)
	else
		local rHand, lHand = character:getPrimaryHandItem(), character:getSecondaryHandItem()
		local primaryEquipped = rHand and rHand == item
		local secondaryEquipped = lHand and lHand == item
		if not instanceof(item, "InventoryItem") then return action; end
		if (primary and primaryEquipped and not secondaryEquipped) or (twoHands and primaryEquipped and secondaryEquipped) or
		(not primary and not twoHands and secondaryEquipped and not primaryEquipped)then return action; end
		equipAction = ISEquipWeaponAction:new(character, item, 50, primary, twoHands)
	end
	
	if lastAction then
		ISTimedActionQueue.addAfter(action, equipAction)
	else
		ISTimedActionQueue.add(equipAction)
	end
	return equipAction
end

function LSUtil.getItemAndEquip(character, tag, itemName, primary, twoHands, hasUses, previousAction, liquid)
	local playerInv = character:getInventory()
	
	local predicateItem = function(item)
		return ((tag and item:hasTag(ItemTag[string.upper(tag)])) or (itemName and item:getType() == itemName) or (liquid and LSUtil.getItemFluid(character, liquid, nil, nil, true))) and
		(not hasUses or not item:IsDrainable() or item:getCurrentUses() >= 1) and
		not item:isBroken()
	end
	
	if not playerInv:containsEvalRecurse(predicateItem) then return false; end
	local item = playerInv:getFirstEvalRecurse(predicateItem)
	
	if item then
		local transferAction = LSUtil.doItemTransfer(character, item, previousAction)
		if transferAction then
			if previousAction then 
				local equipAction = LSUtil.doItemEquip(character, item, primary, twoHands, transferAction)
				return item, equipAction
			else
				LSUtil.doItemEquip(character, item, primary, twoHands)
				return item
			end
		end
	end
	return false
end

function LSUtil.getItem(character, tag, itemName, hasUses, liquid)
	local playerInv = character:getInventory()
	local predicateItem = function(item)
		return ((tag and item:hasTag(ItemTag[string.upper(tag)])) or (itemName and item:getType() == itemName) or (liquid and LSUtil.getItemFluid(character, liquid, nil, nil, true))) and
		(not hasUses or not item:IsDrainable() or item:getCurrentUses() > 0) and
		not item:isBroken()
	end
	if not playerInv:containsEvalRecurse(predicateItem) then return false; end
	return playerInv:getFirstEvalRecurse(predicateItem)
end

function LSUtil.hasItem(character, tag, itemName, hasUses, liquid, minAmount)
	local playerInv = character:getInventory()
	local predicateItem = function(item)
		return ((tag and item:hasTag(ItemTag[string.upper(tag)])) or (itemName and item:getType() == itemName) or (liquid and LSUtil.getItemFluid(character, liquid, nil, nil, true))) and
		(not hasUses or not item:IsDrainable() or (not minAmount and item:getCurrentUses() > 0) or item:getCurrentUsesFloat() >= minAmount) and
		not item:isBroken()
	end
	return playerInv:containsEvalRecurse(predicateItem)
end

function LSUtil.isValidInvItem(item)
	if not item or not instanceof(item, "InventoryItem") then LSUtil.debugPrint("LSUtil.isValidInvItem, not item or not instanceof(item, InventoryItem), returning"); return false; end
	return true
end

function LSUtil.removeItemOnChar(character, item)
	character:removeAttachedItem(item)
	if not character:isEquipped(item) then return true; end
	local removed = character:removeFromHands(item)
	character:removeWornItem(item, false)
	triggerEvent("OnClothingUpdated", character)
	return removed
end

function LSUtil.hasItemsOnChar(character, list)
	for k, v in pairs(list) do
		local items = character:getInventory():getItemsFromType(k, true)
		local amount = 0
		for n=0,items:size() - 1 do
			local item = items:get(n)
			local itemCont = item:getContainer()
			if amount < v and itemCont and itemCont:isExistYet() and itemCont:isRemoveItemAllowed(item) and LSUtil.removeItemOnChar(character, item) and not item:isEquipped() then
				if item:IsDrainable() then
					amount = amount+item:getCurrentUses()
				else
					amount = amount+1
				end
			end
		end
		if amount < v then return false; end
	end
	return true
end

function LSUtil.changeTexture_Item(character, item, choice)
	item:getVisual():setTextureChoice(choice)
	if LSSync.isClientOnly() then
		sendClientCommand(character, "LS", "ChangeTexture_Item", {item:getID(),choice})
	else
		item:synchWithVisual()
	end
	if LSSync.isNotServer() then
		character:resetModel()
		--character:setWornItem(item:getBodyLocation(), item);
	end
end

---------- Items (drainable) ~= fluids

function LSUtil.isValidDrainableItem(item)
	return item and instanceof(item, "InventoryItem") and item:IsDrainable() and not item:isBroken()
end

function LSUtil.itemHasUses(item)
	return item and item:getCurrentUses() > 0
end

function LSUtil.itemGetUses(item)
	if not LSUtil.itemHasUses(item) then return 0; end
	return item:getCurrentUses()
end

function LSUtil.useItem(item, character, chance, amount) -- b42
	if not LSUtil.itemHasUses(item) then return; end
	LSUtil.debugPrint("called LSUtil.useItem, for item: "..item:getFullType().." ----")
	if chance and ZombRand(101) > chance then return; end
	local uses = amount or 1
	if isServer() or not isClient() then
		local total = (type(uses) == "table" and #uses) or uses
		for n=1,total do
			item:UseAndSync()
		end
	else
		sendClientCommand(character, "LS", "UseItem_Player", {item:getID(), uses})
	end
end

function LSUtil.drainItem(item, character)
	if not LSUtil.itemHasUses(item) then return; end
	local uses = LSUtil.itemGetUses(item)
	if uses and uses > 0 then LSUtil.useItem(item, character, nil, uses); end
end

function LSUtil.getItemDrainable(character, itemName, amount) -- simple drainable item search in player inv
	local playerInv = character:getInventory()
	local predicateItem = function(item)
		if not LSUtil.isValidDrainableItem(item) then return false; end
		local itemFullType = item.getFullType and item:getFullType()
		local isItem = itemFullType and itemFullType == itemName
		return isItem and (not amount or item:getCurrentUses() >= amount)
	end
	--if not playerInv:containsEvalRecurse(predicateItem) then return false; end
	return playerInv:getFirstEvalRecurse(predicateItem)
end

function LSUtil.getAllItemsDrainable(character, itemName) -- gets java array list of all similar drainable items in player inv
	local playerInv = character:getInventory()
	local predicateItem = function(item)
		if not LSUtil.isValidDrainableItem(item) then return false; end
		local itemFullType = item.getFullType and item:getFullType()
		local isItem = itemFullType and itemFullType == itemName
		return isItem and item:getCurrentUses() > 0
	end
	--if not playerInv:containsEvalRecurse(predicateItem) then return false; end
	return playerInv:getAllEvalRecurse(predicateItem)
end

function LSUtil.getTotalItemDrainableCount(character, itemName) -- gets total amount of uses across all similar drainable items in player inv
	local items = LSUtil.getAllItemsDrainable(character, itemName)
	if not items then return 0; end
	local amount = 0
	for i=0, items:size()-1 do
		local item = items:get(i)
		amount = amount+item:getCurrentUses()
	end
	return amount
end

LSUtil.getFullerDrainable = function(character, itemName, minAmount)
	local itemList = LSUtil.getAllItemsDrainable(character, itemName)
	if not itemList or itemList:size() == 0 then return false; end
	local fullerItem
	local current = 0
	for x=0,itemList:size() - 1 do
		local item = itemList:get(x)
		local uses = item and item.getCurrentUses and item:getCurrentUses()
		if uses and uses > current and (not minAmount or item:getCurrentUsesFloat() >= minAmount) then
			current = uses
			fullerItem = item
		end
	end
	return fullerItem
end

function LSUtil.renameItem(character, item, newName)
	if LSSync.isClientOnly() then
		sendClientCommand(character, "LS", "renameItem", {item:getID(), newName})
		--return
	end
	if item then item:setName(newName); end
end

---------- Recipes

function LSUtil.learnRecipes(character, recipes)
	if LSSync.isClientOnly() then
		sendClientCommand(character, "LS", "learnRecipes", recipes)
		--return
	end
	local newRecipes
	for n=1,#recipes do
		local recipe = recipes[n]
		if not character:isRecipeActuallyKnown(recipe) then
			if not newRecipes then newRecipes = {}; end
			table.insert(newRecipes, tostring(recipe))
			character:learnRecipe(recipe)
		end
	end
	if newRecipes and isClient() then
		local num = (#newRecipes > 1 and ", +"..tostring(#newRecipes-1)) or ""
		HaloTextHelper.addGoodText(character, getText("IGUI_HaloNote_LearnedRecipe", getRecipeDisplayName(newRecipes[1]))..num)
	end
end

---------- Characters

function LSUtil.MakeCharWellFed(character, alternate)
	if LSSync.isClientOnly() then
		sendClientCommand(character, "LS", "MakeWellFed", alternate)
		return
	end
	local itemName = alternate or "Lifestyle.DebugFoodTest"
	local item = instanceItem(itemName)
	character:Eat(item, 1.0)
end

function LSUtil.reduceAllStiffness(character, value)
	if not character or not character.getBodyDamage then return; end
	local bodyParts = character:getBodyDamage():getBodyParts()
	if not bodyParts then return; end
	if isClient() then
		sendClientCommand(character, "LS", "reduceAllStiffness", {value})
	else
		for i=0,bodyParts:size()-1 do
			local bodyPart = bodyParts:get(i)
			if bodyPart then
				local stiff = bodyPart:getStiffness()
				if stiff and stiff > 0 then
					local newStiff = math.max(0,stiff-value)
					bodyPart:setStiffness(newStiff)
					--local bodyPartType = bodyPart:getType()
					--character:getFitness():removeStiffnessValue(bodyPartType:ToString(bodyPartType))
				end
			end
		end
	end
end

function LSUtil.addGeneralHealth(character, value, halo)
	if not character or not character.getBodyDamage or character:isDead() then return; end
	local bodyDamage = character:getBodyDamage()
	if not bodyDamage then return; end
	if halo then LSUtil.doSimpleArrowHalo(character, getText("IGUI_HealthTooltip"), true); end
	if isClient() then
		sendClientCommand(character, "LS", "AddGeneralHealth", {value})
	else
		bodyDamage:AddGeneralHealth(value)
	end	
end

function LSUtil.addPainBodyPart(character, bP, value, halo)
	if not character or not character.getBodyDamage or not BodyPartType[bP] or value <= 0 then return; end
	local bodyDamage = character:getBodyDamage()
	if not bodyDamage then return; end
	if halo then LSUtil.doSimpleArrowHalo(character, getText("IGUI_HaloNote_Pain"), false); end
	if isClient() then
		sendClientCommand(character, "LS", "addPainBodyPart", {bP, value})
	else
		bodyDamage:getBodyPart(BodyPartType[bP]):setAdditionalPain(value)
	end	
end

function LSUtil.getCharacterMood(character, mood)
	if not character or not character.getStats then return false; end
	local stats = character:getStats()
	if not stats then return false; end
	local upperCase = string.upper(mood)
	--if mood == "Endurance" or mood == "Unhappiness" or mood == "Boredom" or mood == "Nicotine_Withdrawal" or mood == "Pain" or mood == "Fatigue" or mood == "Stress" or
	--mood == "Panic" or mood == "Wetness" then
	if CharacterStat[upperCase] then
		if mood == "Nicotine_Withdrawal" and not character:hasTrait(CharacterTrait.SMOKER) then return 0; end
		--local upperCase = string.upper(mood)
		return stats:get(CharacterStat[upperCase])
	end
	return stats['get'..mood] and stats['get'..mood](stats)
end

local function moodValueChanged(character, mood, value)
	local currentMood = LSUtil.getCharacterMood(character, mood)
	local rangeMax = 100
	if mood == "Stress" or mood == "Nicotine_Withdrawal" then rangeMax = 1; end
	if currentMood ~= math.max(0, math.min(rangeMax, currentMood+value)) then return true; end
	return false
end

function LSUtil.changeCharacterMood(character, mood, value, halo, isSet, isBad)
	if not character or not character.getStats then return; end
	local stats = character:getStats()
	if not stats then return; end
	local upperCase = string.upper(mood)
	--if mood == "Endurance" or mood == "Unhappiness" or mood == "Boredom" or mood == "Nicotine_Withdrawal" or mood == "Pain" or mood == "Fatigue" or mood == "Stress" or
	--mood == "Panic" or mood == "Wetness" then
	if CharacterStat[upperCase] then
		if mood == "Nicotine_Withdrawal" and not character:hasTrait(CharacterTrait.SMOKER) then return; end
		--local upperCase = string.upper(mood)
		local valChange = moodValueChanged(character, mood, value)
		local method = "add"
		if isSet then method = "set"; elseif value < 0 then method = "remove"; value = -1*value; end
		if halo and valChange then
			--local symbol = " + "
			--if method == "remove" then symbol = " - "; elseif method == "set" then symbol = ""; end
			LSUtil.doSimpleArrowHalo(character, getText("IGUI_HaloNote_"..mood), (method == "add" and not isBad) or (isBad and method == "remove") or (isSet and not isBad and value > 0) or (isSet and isBad and value == 0))
		end
		if isClient() then
			sendClientCommand(character, "LS", "ChangeCharacterMood", {method, upperCase, value})
		else
			stats[method](stats, CharacterStat[upperCase], value)
			if isServer() then sendPlayerStat(character, CharacterStat[upperCase]); end
		end
		return
	end
	if not stats['get'..mood] or not stats['set'..mood] then return; end
	local newVal = stats['get'..mood](stats)
	local ogVal = newVal
	local rangeMax = 1
	if mood == "Panic" then rangeMax = 100; end
	if isSet then
		newVal = value
	else
		newVal = newVal+value
	end
	newVal = math.max(0,math.min(rangeMax, newVal))
	
end

function LSUtil.changeCharacterMoodGroup(character, moodList)
	if not character or not character.getStats then return; end
	local stats = character:getStats()
	if not stats then return; end
	local sendList = {}
	for k, v in pairs(moodList) do
		local mood = tostring(k)
		local upperCase = string.upper(mood)
		if CharacterStat[upperCase] and (mood ~= "Nicotine_Withdrawal" or character:hasTrait(CharacterTrait.SMOKER)) then
			if not isClient() then
				LSUtil.changeCharacterMood(character, mood, v[1], v[2], v[3], v[4]) -- value, halo, isSet, isBad
			else
				local valChange = moodValueChanged(character, mood, v[1])
				local method = "add"
				local value = v[1]
				if v[3] then method = "set"; elseif v[1] < 0 then method = "remove"; value = -1*(v[1]); end
				table.insert(sendList, {method, upperCase, value})
				if v[2] and valChange then
					--local symbol = " + "
					--if method == "remove" then symbol = " - "; elseif method == "set" then symbol = ""; end
					LSUtil.doSimpleArrowHalo(character, getText("IGUI_HaloNote_"..mood), (method == "add" and not v[4]) or (v[4] and method == "remove") or (v[3] and not v[4] and value > 0) or (v[3] and v[4] and value == 0))
				end
			end
		end
	end
	if LSSync.isClientOnly() and #sendList > 0 then sendClientCommand(character, "LS", "ChangeCharacterMoodGroup", {sendList}); end	
end

function LSUtil.giveXP(character, skill, amount, isCustom)
	if isCustom then return; end -- do non perk system stuff here
	if not Perks[skill] or character:getPerkLevel(Perks[skill]) >= 10 then return; end
	if LSSync.isClientOnly() then sendClientCommand(character, "LS", "AddXP", {skill, amount}); return; end
	if amount > 0 then
		addXp(character, Perks[skill], amount)
	else
		addXpNoMultiplier(character, Perks[skill], amount)
	end
	SyncXp(character)
end

function LSUtil.giveXPBatch(character, skillTable)
	if not skillTable then return; end
	if LSSync.isClientOnly() then sendClientCommand(character, "LS", "AddXPBatch", skillTable); return; end
	for n=1,#skillTable do
		local skill = skillTable[n]
		LSUtil.giveXP(character, skill[1], skill[2], skill[3])
	end
end

function LSUtil.getValidCharacter(character)
	if not character or not instanceof(character, "IsoPlayer") or character:isDead() then return false; end
	return character
end

function LSUtil.getValidPlayer(player)
	if not player then return false; end
	local character = getSpecificPlayer(player)
	return LSUtil.getValidCharacter(character)
end

function LSUtil.getCharacterPlayerID(character)
	if not LSUtil.getValidCharacter(character) then return false; end
	if not isClient() then return character:getPlayerNum(); end
	return character:getOnlineID()
end

function LSUtil.isCharBusy(character)
	if not character then return true; end
	return character:isDead() or character:getVehicle() or character:isSneaking() or character:hasTimedActions() or character:isAsleep()
end

function LSUtil.isCharSitting(character, data)
	if not character then return true; end
	return character:isSitOnGround() or character:isSittingOnFurniture()
end

function LSUtil.playCharVoice(character, soundName, num)
	if character:isFemale() then soundName = "Woman"..soundName; else soundName = "Man"..soundName end
	if num then soundName = soundName..tostring(ZombRand(num)+1); end
	character:getEmitter():playSound(soundName)
end

function LSUtil.makeCharExplode(character, args)
	if isClient() and not isServer() then sendClientCommand(character, "LS", "Character_Explosion", args); return; end
	local dmgChance = args[1] -- scratch, glass, burned
	local dmgParts = args[2]
	local dmgTotal = args[3]
	local partNames = args[4]

	local bd = character:getBodyDamage()
	local parts = {}
	for n=1,#partNames do
		local name = partNames[n]
		table.insert(parts, bd:getBodyPart(BodyPartType[name]))
	end
	for n=1,#parts do
		local part = parts[n]
		if part then
			local currentDmg = 0
			if dmgChance[1] and currentDmg < dmgParts and not part:scratched() and LSUtil.rdm_inst:random(dmgChance[1]) == 1 then part:setScratched(true, true); currentDmg = currentDmg+1; end

			if dmgChance[2] and currentDmg < dmgParts and not part:haveGlass() and LSUtil.rdm_inst:random(dmgChance[2]) == 1 then part:setHaveGlass(true); currentDmg = currentDmg+1; end

			if dmgChance[3] and currentDmg < dmgParts and not part:isBurnt() and LSUtil.rdm_inst:random(dmgChance[3]) == 1 then
				part:setBurned()
				part:setBurnTime(ZombRand(5,15))
				part:setNeedBurnWash(true)
				currentDmg = currentDmg+1
			end
			
			dmgTotal = dmgTotal-1
			if dmgTotal < 0 then break; end
		end
	end

end

function LSUtil.makeCharWet(character, doClothes)
	local stats = character and character:getStats()
	if not stats then return; end
	if isClient() and not isServer() then sendClientCommand(character, "LS", "Character_MakeWet", {true}); return; end
	stats:set(CharacterStat.WETNESS, 100)
	if doClothes then
		local wornItems = character:getInventory():getItems()
		for j = 0, wornItems:size()-1 do
			local item = wornItems:get(j)
			if instanceof(item, "Clothing") and character:isEquippedClothing(item) then
				item:setWetness(100)
				syncItemFields(character, item)
			end
		end
	end
end

function LSUtil.changeCharVisualDirt(character, val, bloodVal, doClothes)
	-- negative values clean
	if isClient() or not isServer() then
		local visual = character:getHumanVisual()
		for i = 1, BloodBodyPartType.MAX:index() do
			local part = BloodBodyPartType.FromIndex(i - 1)
			local dirt = math.min(1, math.max(0,visual:getDirt(part)+val))
			visual:setDirt(part, dirt)
			if bloodVal then 
				local blood = math.min(1, math.max(0,visual:getBlood(part)+bloodVal))
				visual:setBlood(part, blood)
			end
		end
	end

	if doClothes then -- getDirt and getBlood both returns 0-1, getDirtiness and getBloodLevel return 0-100
		if isClient() and not isServer() then
			sendClientCommand(character, "LS", "Character_CleanSelf", {val, bloodVal, true})
		else
			local wornItems = character:getInventory():getItems()
			for j = 0, wornItems:size()-1 do
				local item = wornItems:get(j)
				if instanceof(item, "Clothing") and character:isEquippedClothing(item) then
					local coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
					if coveredParts then
						for j=0,coveredParts:size()-1 do
							local part = coveredParts:get(j)
							local dirt = math.min(1, math.max(0,item:getDirt(part)+val))
							item:setDirt(part, dirt)
							if bloodVal then 
								local blood = math.min(1, math.max(0,item:getBlood(part)+bloodVal))
								item:setBlood(part, blood)
							end
						end
					end
					local totalDirtiness = math.min(100, math.max(0,item:getDirtiness()+val*100))
					item:setDirtiness(totalDirtiness)
					if bloodVal then
						local totalBlood = math.min(100, math.max(0,item:getBloodLevel()+bloodVal*100))
						item:setBloodLevel(totalBlood)
					end
					syncItemFields(character, item)
				end
			end
		end
	end
	syncVisuals(character)
end

function LSUtil.getPlayerCooldowns(intervalMin)
	local t = {
		[120] = {
			{ -- moodles
			"Gloomy",
			},
			{ -- LSCooldowns
			"invGnome",
			},
		},
		[60] = {
			{ -- moodles
			"TaughtSkill",
			"WasTaughtMeditation",
			"WasTaughtSkill",
			"AdviceWasted",
			"Attractive",
			"Nauseous",
			"SmellGood",
			"FTGood",
			"FTBad",
			"Eureka",
			"MintCurio",
			},
			{
			"TeachCooldown",
			"LessonCooldown",
			"InteractionSpam",
			"mirrorPT",
			"mirrorCD",
			"brushmaster",
			"grimefighter",
			"unstoppable",
			"FortuneTeller",
			"mentalBlock",
			"dietofgods",
			},
		},
		[10] = {
			{ -- moodles
			"Zen",
			},
			{
			"TeachCooldown",
			"LessonCooldown",
			"InteractionSpam",
			"StinkingCooldown",
			},
		},
	}
	if not intervalMin then return t; end
	return t[intervalMin]
end

---------- Water
function LSUtil.objHasWater(obj, amount)
	local minAmount = amount or 0.1
	return obj and obj:hasWater() and obj:getFluidAmount() >= minAmount
end

---------- Fluids

function LSUtil.useObjFluid(obj, amount)
	if not obj or (not obj:hasFluid() and not obj:hasWater()) then return; end
	if isClient() and not isServer() then
		local sprite = obj and obj.getSprite and obj:getSprite()
		local spriteName = sprite and sprite:getName()
		sendClientCommand("LS", "UseFluid_Obj", {{obj:getX(),obj:getY(),obj:getZ(),spriteName or "none"}, amount})
		return
	end
	obj:useFluid(amount)
end

function LSUtil.getFluidContainer(entity)
	return entity and ((instanceof(entity, "InventoryItem") and entity:getFluidContainerFromSelfOrWorldItem()) or (entity.getFluidContainer and entity:getFluidContainer()))
end

function LSUtil.getOrCreateFluidContainer(entity, args)
	if not entity then return false; end
	local fluidContainer = LSUtil.getFluidContainer(entity)
	if fluidContainer then return fluidContainer; end

	if LSSync.isClientOnly() then
		if instanceof(entity, "InventoryItem") then
			sendClientCommand(getPlayer(), "LS", "CreateFluidCont_Item", {entity:getID(), args})
		elseif instanceof(entity, "IsoObject") then
			local sprite = entity and entity.getSprite and entity:getSprite()
			local spriteName = sprite and sprite:getName()
			sendClientCommand("LS", "CreateFluidCont_Obj", {{entity:getX(),entity:getY(),entity:getZ(),spriteName or "none"}, args})
		end
		return false
	end

	entity:createFluidContainer()
	fluidContainer = LSUtil.getFluidContainer(entity)
	if arg[2] then fluidContainer:setCapacity(arg[2]); end
	if isServer() then
		--entity:transmitCompleteItemToClients()
		entity:sendSyncEntity(nil)
		if args[1] then LSSync.updateAndSend(entity, false, args[1]); end -- data
	end
	return fluidContainer
end

function LSUtil.getItemFluidAmount(item, fluidName)
	local fluidContainer = LSUtil.getFluidContainer(item)
	if not fluidContainer or fluidContainer:getAmount() <= 0 then return 0; end
	local fluidAmount = fluidContainer:getSpecificFluidAmount(Fluid[fluidName])
	return fluidAmount
end

function LSUtil.itemHasEnoughFluid(item, fluidName, amount)
	local fluidContainer = LSUtil.getFluidContainer(item)
	if not fluidContainer or fluidContainer:getAmount() <= 0 or fluidContainer:getAmount() < amount then return false; end
	local primaryFluid = fluidContainer and fluidContainer:getPrimaryFluid()
	return primaryFluid and LSUtil.StringStartWith(primaryFluid:getFluidTypeString(), fluidName)
end

function LSUtil.itemHasFluid(item, fluidName, amount, isPrimary)
	local fluidContainer = LSUtil.getFluidContainer(item)
	if not fluidContainer or fluidContainer:getAmount() <= 0 then return false; end
	if not fluidName then return true; end
	if isPrimary then
		local primaryFluid = fluidContainer and fluidContainer:getPrimaryFluid()
		return primaryFluid and LSUtil.StringStartWith(primaryFluid:getFluidTypeString(), fluidName)
	end
	if not FluidType[fluidName] then return false; end
	local fluidAmount = fluidContainer:getSpecificFluidAmount(Fluid[fluidName])
	return fluidAmount and ((not amount and fluidAmount > 0) or (amount and fluidAmount >= amount))
end

function LSUtil.adjustFluid(item, useDelta, character)
	local fluidContainer = LSUtil.getFluidContainer(item)
	if not fluidContainer then return; end
	if not isServer() and isClient() then
		sendClientCommand(character, "LS", "AdjustFluidItem", {item, useDelta})
		return
	end
	local amount = math.max(0, fluidContainer:getAmount() - useDelta)
	fluidContainer:adjustAmount(amount)
	syncItemFields(character, item)
	sendItemStats(item)
	character:getInventory():setDrawDirty(true)
end

function LSUtil.getItemFluid(character, fluidName, amount, percent, pure)
	if not FluidType[fluidName] then return false; end
	local playerInv = character:getInventory()
	local predicateItem = function(item)
		local fluidContainer = LSUtil.getFluidContainer(item)
		if not fluidContainer then return false; end
		local containerAmount = fluidContainer:getAmount()
		local fluidAmount = fluidContainer:getSpecificFluidAmount(Fluid[fluidName])
		if not containerAmount or containerAmount <= 0 or not fluidAmount or fluidAmount <= 0 then return false; end
		if not amount and not percent then
			return not pure or fluidContainer:isPureFluid(Fluid[fluidName])
			--local primaryFluid = fluidContainer and fluidContainer:getPrimaryFluid()
			--return primaryFluid and LSUtil.StringStartWith(primaryFluid:getFluidTypeString(), fluidName)
		end
		local fluidPercent = LSUtil.getPercentage(containerAmount,fluidAmount,false,false)
		return (not amount or fluidAmount >= amount) and (not percent or fluidPercent >= percent)
	end
	if not playerInv:containsEvalRecurse(predicateItem) then return false; end
	return playerInv:getFirstEvalRecurse(predicateItem)
end

---------- Inventions

function LSUtil.doInvCooldown(inv, invData)
	if not invData or not invData['cooldownTime'] then return; end
	local hour = getGameTime():getWorldAgeHours()
	invData['cooldown'] = hour+invData['cooldownTime']
end

function LSUtil.isCooldown(invData)
	return invData['cooldown'] and getGameTime():getWorldAgeHours() <= invData['cooldown']
end

local function getInventionTooltipDesc(value, totalVal, stringName, color)
	return color .. stringName .. " " .. tostring(value) .. "/" .. tostring(totalVal) .. " <LINE>";
end

local function getInventionTooltipToolDesc(hasItem, itemType, bhs, ghs, itemTag)
	local itemTexture, itemText
	if itemTag then
		itemTexture, itemText = "<IMAGE:media/ui/"..itemTag.."_icon.png,16,16>", getText("IGUI_ItemTag_"..itemTag)
	else
		itemTexture, itemText = LSUtil.getTexIcon(itemType)
	end
	if not itemTexture then itemTexture = ""; end
	local color = ghs
	if not hasItem then color = bhs; end
	return color .. itemTexture .. itemText .. " <LINE>";
end

function LSUtil.getInventionFixParams(list, character, bhs, mhs, ghs)
	local footNote = "Tooltip_Inventions_Fix"
	local tooltipDesc = "<H1><ORANGE>"..getText("Tooltip_Inventions_Broken").." <LINE><IMAGECENTRE:media/ui/invFix_icon.png,64,64><LINE><TEXT><CENTRE>"..getText("Tooltip_Inventions_Broken2")..
	" <BR><LEFT><RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_RepairCosts")..": <LINE><TEXT><CENTRE><RGB:0.9,0.9,0.9>"..getText("Tooltip_Inventions_SkillReq")..": <LINE><TEXT>"
	local disable
	
	for k, v in pairs(list.reqSkills) do
		local color = ghs
		local skillName = getText("IGUI_perks_"..k)
		local skill = PerkFactory.getPerkFromName(skillName)
		local skillLvl = character:getPerkLevel(skill)
		if skillLvl < v then disable = true; if skillLvl < v/2 then color = bhs; else color = mhs; end; end
		tooltipDesc = tooltipDesc .. getInventionTooltipDesc(skillLvl, v, LSUtil.getSkillIcon(k)..skillName, color)
	end

	tooltipDesc = tooltipDesc.." <LINE><CENTRE><RGB:0.9,0.9,0.9>"..getText("Tooltip_Inventions_ResReq")..": <LINE><TEXT>"

	local toolItem = LSUtil.hasItem(character, 'SCREWDRIVER', false)
	if not toolItem then disable = true; end
	tooltipDesc = tooltipDesc .. getInventionTooltipToolDesc(toolItem, 'Screwdriver', bhs, ghs)

	for k, v in pairs(list.reqRes) do
		local color = ghs
		local itemCount = character:getInventory():getItemCount(k, true)
		if itemCount > 0 and LSUtil.getItemDrainable(character, k, 1) then itemCount = LSUtil.getTotalItemDrainableCount(character, k); end
		if itemCount < v then disable = true; if itemCount < v/2 then color = bhs; else color = mhs; end; end
		local moduleName, itemType = string.match(k, "^([^.]+)%.(.+)$")
		if not itemType then itemType = tostring(k); end
		local itemTexture, itemText = LSUtil.getTexIcon(itemType, moduleName)
		if not itemTexture then itemTexture = ""; end
		tooltipDesc = tooltipDesc .. getInventionTooltipDesc(itemCount, v, itemTexture..itemText, color)
	end

	if disable then footNote = "Tooltip_Inventions_FixMissing"; end

	return disable, tooltipDesc, getText(footNote)
end

function LSUtil.getInventionFuelParams(invData, improvData, character, cN, inv, colors)
	local disable
	local footNote = "Tooltip_Inventions_RefuelFN"
	local title = "Tooltip_Inventions_Refuel"
	local subTitle = "Tooltip_Inventions_Refuel2"
	local fuelColor = colors[2]
	local percent = LSUtil.getPercentage(invData['fuelContainer'][1],invData['fuelUses'], 2, false)
	local fuelDelta = invData['fuelDelta'] or 0
	local hasBattery = LSInv.hasBattery(inv, invData)
	if fuelDelta > 0 then
		local fuelUseDelta = invData['fuelUseDelta'] or 1
		local percentDelta = LSUtil.getPercentage(fuelUseDelta,fuelDelta, false, false)*0.01
		percent=percent+percentDelta
	end
	if percent < 25 then fuelColor = colors[1]; elseif percent >= 75 then fuelColor = colors[3]; end
	local fuelAmount = "("..fuelColor..tostring(invData['fuelUses']).." <RGB:0.9,0.9,0.9> ".."/"..tostring(invData['fuelContainer'][1])..")"
	if invData['fuelCheat'] or invData['fuelInfinite'] then fuelAmount, percent, fuelColor = "("..colors[3].."∞".." <RGB:0.9,0.9,0.9> ".."/∞)", 100, colors[3]; end	
	--if isFull then subTitle = "Tooltip_Inventions_Refuel2_Full"; elseif LSUtil.inventionIsEmpty(invData) then subTitle = "Tooltip_Inventions_Refuel2_Empty"; end
	
	local tooltipDesc = "<H1><ORANGE>"..getText(title).." <LINE><IMAGECENTRE:media/ui/invFuel_icon.png,64,64><LINE><TEXT><CENTRE>"..getText(subTitle)..
	" <BR><TEXT><RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_Fuel")..": <SPACE> "..fuelColor..percent.."%% <SPACE><RGB:0.9,0.9,0.9> "..fuelAmount.." <BR><TEXT>"
	-- fuel type - normal, drainable or liquid (specific or tag)
	local fuelType
	if invData['fuelItem'] or invData['fuelTag'] then
		--IGUI_ItemTag_Petrol
		local hasFuel = hasBattery or LSUtil.hasItem(character, invData['fuelTag'], invData['fuelItem'], not invData['fuelLiquid'], invData['fuelLiquid'], invData['fuelMin'])
		if not hasFuel then disable, footNote = true, "Tooltip_Inventions_RefuelFNMissing"; end
		fuelType = getInventionTooltipToolDesc(hasFuel, invData['fuelItem'], colors[1], colors[3], invData['fuelTag'])
	end
	if fuelType then tooltipDesc = tooltipDesc.." <RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_Fuel2")..": <SPACE>"..fuelType.." <LINE><TEXT>"; end
	-- fuel unit - item, unit, ml/l
	tooltipDesc = tooltipDesc.." <RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_Fuel3")..": <SPACE><TEXT>"..invData['fuelConsumption']
	local fuelUnit
	if invData['fuelItem'] then
		local unit = "Tooltip_Inventions_Fuel_Items"
		local item = LSUtil.getItemProp(invData['fuelItem'], "Base.")
		if item and (invData['fuelLiquid'] or (item.IsDrainable and item:IsDrainable())) then unit = "Tooltip_Inventions_Fuel_Units"; end
		fuelUnit = getText(unit)
	end
	if fuelUnit then tooltipDesc = tooltipDesc.." <SPACE>"..fuelUnit; end
	
	tooltipDesc = tooltipDesc.." <SPACE>"..getText("Tooltip_Inventions_Fuel4").." <BR><TEXT>"
	-- improvements
	--tooltipDesc = tooltipDesc.." <LINE>"
	local improvHdr
	local t = {'fuelContainer','fuelConsumption'}
	for n=1,#t do
		local improvement = improvData[t[n]]
		if improvement and improvement[1] and improvement[2] then
			if not improvHdr then improvHdr = true; tooltipDesc = tooltipDesc.." <RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_Improv")..": <LINE>"; end
			local icon = "<IMAGE:"..LSInv.getInvStatIcon(t[n], cN, true)..",16,16>"
			local startLine, endLine = icon.." <TEXT><RGB:0.9,0.9,0.9>", ": "..tostring(improvement[1]).."/"..tostring(improvement[2])
			if improvement[1] == improvement[2] then startLine, endLine = startLine.." <GREEN>", endLine.." <SPACE><IMAGE:media/ui/okay_icon.png,16,16>"; end
			local customText = getText("IGUI_Inventions_"..cN.."_"..t[n])
			if customText == "IGUI_Inventions_"..cN.."_"..t[n] then customText = getText("IGUI_Inventions_"..t[n]); end
			tooltipDesc = tooltipDesc..startLine..customText..endLine.." <LINE><TEXT>"
		end
	end

	-- full
	if hasBattery then
		footNote = "Tooltip_Inventions_RefuelFNBattery"
	elseif LSUtil.inventionIsFull(invData) then
		disable, footNote = true, "Tooltip_Inventions_RefuelFNFull"
	end
	return disable, tooltipDesc, getText(footNote)
end

local function getOtherInvStats(data, cN)
	-- repair penalty - deliver in percentage
	local t = {}
	local text = "IGUI_Inventions_"
	local cost = data['costPenalty']/data['costDecrease']
	local productionCost = (cost/data['standardization'])/(data['costDefs'][3])
	local repairCost = (cost/data['standardization'])/(data['costDefs'][3]*2)
	
	t.researchModifier = {LSUtil.getPercentage(1,cost,2,true),"bad100",text}
	t.productionModifier = {LSUtil.getPercentage(1,productionCost,2,true),"bad100",text}
	t.repairPenalty = {LSUtil.getPercentage(1,repairCost,2,true),"bad100",text}

	local otherModifiers = {
		['cooldownTime'] = {'bad',0,true,true},
		['fuelUses'] = {'good',0,true,true},
		['fuelContainer'] = {'good',1,true,true}, -- text, table n, whole number, dont show %
		['fuelConsumption'] = {'bad',0,false,false},
		['weightTotal'] = {'bad',0,false,false},
		['resistant'] = {'good0',0,false,false},
	}

	for k, v in pairs(otherModifiers) do
		if data[k] then
			local mod = (v[2] == 0 and data[k]) or data[k][v[2]]
			if mod then
				if not v[3] then
					local ogVal = (v[2] == 0 and LSInventionDefs.Items[cN][k]) or LSInventionDefs.Items[cN][k][v[2]]
					local valDiff = mod-ogVal
					t[k.."Modifier"] = {LSUtil.getPercentage(ogVal,valDiff,2,false),v[1],text,v[4]}
				else
					t[k.."Modifier"] = {mod,v[1],text,v[4]}
				end
			end
		end
	end

	-- custom text v
	text = "IGUI_Inventions_"..cN.."_"

	if data['efficiency'] then
		t.efficiencyTotal = {LSUtil.getPercentage(1,data['efficiency'],2,false),"good0",text}
	end
	--[[
	if data['cooldownTime'] then
		local cTotal = LSInventionDefs.Items[cN]['cooldownTime']
		local cTime = data['cooldownTime']-cTotal
		t.cooldownTimeTotal = {LSUtil.getPercentage(cTotal,cTime,2,false),"bad",text}
	end
	]]--
	if data['durability'] then
		if type(data['durability']) == "table" then
			for n=1,#data['durability'] do
				t['breakDownChance'..n] = {data['durability'][n],"bad",text}
			end
		else
			t.breakDownChance1 = {data['durability'],"bad",text}
		end
	end

	return t
end

local function getInvColorsParams(key, value)
	local neutral = " <RGB:0.5,0.5,0.5>"
	local red = {" <RGB:0.6,0.4,0.4>", " <RGB:0.8,0.3,0.3>", " <RGB:1,0.2,0.2>"}
	local green = {" <RGB:0.4,0.6,0.4>", " <RGB:0.3,0.8,0.3>", " <RGB:0.2,1,0.2>"}
	local t = {
		bad = {{value==0, neutral},{value>=75, red[3]},{value>=25, red[2]},{value>0, red[1]},{value<=-75, green[3]},{value<=-25, green[2]},{value<0, green[1]}},
		bad0 = {{value<=0, green[3]},{value>=100, red[3]},{value>=80, red[2]},{value>=60, red[1]},{value>=40, neutral},{value>=20, green[1]},{value>0, green[2]}},
		bad100 = {{value<=20, green[3]},{value>=200, red[3]},{value>=150, red[2]},{value>=110, red[1]},{value>=90, neutral},{value>=50, green[1]},{value>20, green[2]}},
		good = {{value==0, neutral},{value>=75, green[3]},{value>=25, green[2]},{value>0, green[1]},{value<=-75, red[3]},{value<=-25, red[2]},{value<0, red[1]}},
		good0 = {{value<=0, red[3]},{value>=100, green[3]},{value>=80, green[2]},{value>=60, green[1]},{value>=40, neutral},{value>=20, red[1]},{value>0, red[2]}},
		good100 = {{value<=20, red[3]},{value>=200, green[3]},{value>=150, green[2]},{value>=110, green[1]},{value>=90, neutral},{value>=50, red[1]},{value>20, red[2]}},
	}
	if not t[key] then return neutral; end
	for n=1,#t[key] do
		if t[key][n][1] then return t[key][n][2]; end
	end
	return neutral
end

local function resetTooltipDesc(t, oldDesc, newTxt, endTxt, name, num)
	local numTxt = " <BR>"
	if num then numTxt = " <SPACE>"..num.." <BR>"; end
	oldDesc = oldDesc..endTxt..getText("Tooltip_Inventions_"..name)..numTxt
	table.insert(t, oldDesc)
	local desc = newTxt
	return desc
end

function LSUtil.getInventionStatsParams(data, tex, invName, character, cN, cArgs)
	--local tex = obj:getTextureName() --!
	--local footNote = "Tooltip_Inventions_RepairCostHint"
	local descTable = {}
	local endLine = " <BR><TEXT><CENTRE><RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_NextPage")
	local imageSize = (invName == "Hygienator" and "64,32") or "64,64"
	local tooltipTitle = "<H1><ORANGE>"..getText("Tooltip_Inventions_Stats").." <BR><IMAGECENTRE:"..tex..","..imageSize.."><LINE><TEXT><CENTRE>"
	local descMain = tooltipTitle..getText("Tooltip_Inventions_Stats2").." <BR><RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_MainPage").." <BR><H2><CENTRE>"..invName.." <LINE><TEXT><RGB:0.5,0.5,0.5>"..getText("Tooltip_Inventions_"..cN.."_desc")
	local descImp = tooltipTitle.." <RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_Improv").." <TEXT><BR>"
	local descOther = tooltipTitle.." <RGB:0.8,0.8,0>"..getText("Tooltip_Inventions_OtherStats").." <TEXT><BR>"
	if cArgs and cArgs[1] then descMain = descMain.." <BR>"..cArgs[1]; end

	local newDesc = descMain.." <LINE><LINE>"
	newDesc = resetTooltipDesc(descTable, newDesc, descImp, endLine, "Improv", false)
	local hasImprov
	local n, pg = 0, 1
	if cArgs and cArgs[2] then newDesc, n = newDesc..cArgs[2].." <LINE><LINE>", cArgs[3]; end
	
	for k, v in pairs(data['improvementData']) do
		if v and v[1] and v[2] and v[1] > 0 then
			if n > 4 then
				pg = pg+1
				newDesc = resetTooltipDesc(descTable, newDesc, descImp, endLine, "Improv", tostring(pg))
				n = 0
			end
			hasImprov = true
			local icon = "<IMAGE:"..LSInv.getInvStatIcon(k, cN, true)..",16,16>"
			local startLine, middleLine = icon.." <TEXT><RGB:0.9,0.9,0.9>", " ("..tostring(v[1])..")"
			if v[2] == 1 then middleLine = ""; end
			if v[1] == v[2] then startLine, middleLine = startLine.." <GREEN>", middleLine.." <SPACE><IMAGE:media/ui/okay_icon.png,16,16>"; end
			
			local specialText = cN.."_"
			if getText("IGUI_Inventions_"..specialText..k) == "IGUI_Inventions_"..specialText..k then specialText = ""; end
			local customText = getText("IGUI_Inventions_"..specialText..k)..middleLine.." <RGB:0.6,0.6,0.6><LINE>"..
			getText("IGUI_Inventions_Effects").." <SPACE><RGB:0.5,0.5,0.5>"..getText("IGUI_Inventions_"..specialText..k.."_desc_short").." <LINE>"..getText("IGUI_Inventions_"..specialText..k.."_desc")

			newDesc = newDesc..startLine..customText.." <LINE><LINE>"
			n = n+1
		end
	end
	if not hasImprov then newDesc = newDesc.." <CENTRE>"..getText("Tooltip_Inventions_NoImprovs").." <LINE>"; end
	
	newDesc = resetTooltipDesc(descTable, newDesc, descOther, endLine, "OtherStats", false)
	n, pg = 0, 1
	if cArgs and cArgs[4] then newDesc, n = newDesc..cArgs[4].." <LINE><LINE>", cArgs[5]; end
	
	local othersList = getOtherInvStats(data['inventionData'], cN)
	for k, v in pairs(othersList) do
		if n > 7 then
			pg = pg+1
			newDesc = resetTooltipDesc(descTable, newDesc, descOther, endLine, "OtherStats", tostring(pg))
			n = 0
		end
		local color = getInvColorsParams(v[2],v[1])
		local percentage = color..tostring(v[1])
		if not v[4] then percentage = percentage.."%%"; end
		--local icon = "<IMAGE:"..LSInv.getInvStatIcon(k, cN, false)..",16,16>"
		local startLine = "<TEXT><RGB:0.9,0.9,0.9>"
		local specialText = cN.."_"
		if getText("IGUI_Inventions_"..specialText..k) == "IGUI_Inventions_"..specialText..k then specialText = ""; end
		newDesc = newDesc..startLine..getText("IGUI_Inventions_"..specialText..k)..": <SPACE>"..percentage.." <RGB:0.5,0.5,0.5><LINE>"..getText("IGUI_Inventions_"..specialText..k.."_desc").." <LINE><LINE>"
		n=n+1
	end

	newDesc = resetTooltipDesc(descTable, newDesc, descMain, endLine, "MainPage", false)
	
	return descTable
end

---------- Inventions (fuel - general)

function LSUtil.inventionIsFull(data)
	return data['fuelCheat'] or data['fuelInfinite'] or (data['fuelUses'] and data['fuelUses'] >= data['fuelContainer'][1])
end

function LSUtil.inventionIsEmpty(data)
	return not data['fuelCheat'] and not data['fuelInfinite'] and (data['fuelUses'] and data['fuelUses'] <= 0)
end

---------- Inventions (items)

function LSUtil.getInventionItemData(item)
	if not item or not instanceof(item, "InventoryItem") then return false; end
	local data = item:getModData()
	return data and data.movableData and data.movableData['inventionData']
end

function LSUtil.breakInventionItem(character, item, data)
	LSUtil.drainInventionItem(item, data)
	if character then LSUtil.removeItemOnChar(character, item); end
	if (item:getCondition() and item:getCondition() > 0) or not item:isBroken() then LSSync.transmit(item, character, nil, {['Condition']=0,['setBroken']={'isBroken',true}}); end
	LSUtil.debugPrint("---- LS - LSUtil.breakInventionItem, for item: "..item:getFullType().." ----")
end

function LSUtil.rollBreakdownChanceInventionItem(character, item, data, itemType)
	if not data['durability'] or data['neverBreak'] or data['durability'][1] == 0 then return; end
	if data['durability'][2] and data['durability'][2] > 0 and LSUtil.rdm_inst:random(100) <= data['durability'][2] then -- minor fail roll
		LSUtil.debugPrint("---- LS - LSUtil.rollBreakdownChanceInventionItem, for item: "..itemType..", minor failure trigger".." ----")
		if LSInv['OnFail'..itemType] then LSInv['OnFail'..itemType](character, item, data); else LSUtil.breakInventionItem(character, item, data); end
	elseif LSUtil.rdm_inst:random(100) <= data['durability'][1] then -- crit fail roll (or minor fail if it lacks a crit fail)
		LSUtil.debugPrint("---- LS - LSUtil.rollBreakdownChanceInventionItem, for item: "..itemType..", critical failure trigger".." ----")
		local failFunc = LSInv['OnCritFail'..itemType] or LSInv['OnFail'..itemType]
		if failFunc then failFunc(character, item, data); else LSUtil.breakInventionItem(character, item, data); end
	end
end

function LSUtil.inventionItemHasUses(item, data)
	return (isServer() or item:isInPlayerInventory()) and data['fuelUses'] and data['fuelUses'] > 0
end

function LSUtil.inventionItemGetUses(item, data)
	if not LSUtil.inventionItemHasUses(item, data) then return 0; end
	return data['fuelUses']
end

function LSUtil.useInventionItem(item, data)
	if not LSUtil.inventionItemHasUses(item, data) then return; end
	local itemType = item:getFullType()
	if data['recirculator'] and ZombRand(10)+1 <= 2 then
		return
		LSUtil.debugPrint("---- LS - LSUtil.useInventionItem, for item: "..itemType..", no fuel used - recirculator save".." ----")
	end
	data['fuelUses'] = math.max(0,math.floor(data['fuelUses']-1))
	LSUtil.debugPrint("---- LS - LSUtil.useInventionItem, for item: "..itemType..", new fuel uses is: "..tostring(data['fuelUses']).." ----")
end

function LSUtil.drainInventionItem(item, data)
	if not LSUtil.inventionItemHasUses(item, data) then return; end
	data['fuelUses'] = 0
	LSUtil.debugPrint("---- LS - LSUtil.drainInventionItem, for item: "..item:getFullType().." ----")
end

function LSUtil.fillInventionItem(data)
	if not data['fuelContainer'] then return; end
	local total = data['fuelContainer'][1]
	data['fuelUses'] = total
end

---------- Hygiene

local function hygieneGetMinDaysSurvived()
	local lsData = ModData.getOrCreate("LSDATA")
	if lsData and lsData["SO"] and lsData["SO"]["HNE"] then return lsData["SO"]["HNE"]; end
	return 3
end

function LSUtil.isHygieneExpected(data, character)
	if not data.hygieneNeedETime then data.hygieneNeedETime = hygieneGetMinDaysSurvived(); end
	return data.hygieneNeedETime and tonumber(character:getHoursSurvived())/24 > data.hygieneNeedETime
end

function LSUtil.isValidHygiene(data)
	if not data then return false; end
	if not SandboxVars.Text.DividerHygiene or not data.hygieneNeed then data.hygieneNeed = 50; return false; end
	return true
end

function LSUtil.addHygiene(data, character, val, valMax)
	if not LSUtil.isValidHygiene(data) then return; end
	valMax = valMax or 0
	data.hygieneNeed = math.max(valMax, data.hygieneNeed-val)
	LSUtil.doSimpleArrowHalo(character, " + "..getText("IGUI_HaloNote_Hygiene"), true)
end

function LSUtil.reduceHygiene(data, character, val, valMin)
	if not LSUtil.isValidHygiene(data) then return; end
	valMin = valMin or 100
	if not LSUtil.isHygieneExpected(data, character) then valMin = 50; end
	data.hygieneNeed = math.min(valMin, data.hygieneNeed+val)
	LSUtil.doSimpleArrowHalo(character, " - "..getText("IGUI_HaloNote_Hygiene"), false)
end

---------- Lifestyle Moodles

function LSUtil.isValidMoodle(data, moodle)
	return data and data[moodle] and data[moodle].Value
end

function LSUtil.moodleIsSingleText(data, moodle)
	return data[moodle].Icon == 2 or data[moodle].Icon == 3 or (data[moodle].Tiers == 0 and data[moodle].Icon == 0)
end

function LSUtil.setMoodleValue(data, moodle, val, opposite, doHalo)
	if not LSUtil.isValidMoodle(data, moodle) then return; end
	data[moodle].Value = val
	if doHalo then 
		local level = "_L"..tostring(math.max(1, data[moodle].Level))
		if LSUtil.moodleIsSingleText(data, moodle) then level = "_L1"; end -- 1 text
		LSUtil.doSimpleArrowHalo(doHalo, getText("Moodles_"..data[moodle].name..level), data[moodle].Alignment == "Good")
	end
	if opposite then LSUtil.setMoodleValue(data, opposite, 0, false, false); end
end

function LSUtil.addMoodleValue(data, moodle, val, opposite, doHalo, force)
	if opposite and not force and LSUtil.isValidMoodle(data, opposite) and data[opposite].Value > 0 then LSUtil.reduceMoodleValue(data, opposite, val, moodle, doHalo, true); return; end
	if not LSUtil.isValidMoodle(data, moodle) then return; end
	data[moodle].Value = math.min(1, data[moodle].Value+val)
	if doHalo then 
		local level = "_L"..tostring(math.max(1, data[moodle].Level))
		if LSUtil.moodleIsSingleText(data, moodle) then level = "_L1"; end -- 1 text
		LSUtil.doSimpleArrowHalo(doHalo, " + "..getText("Moodles_"..moodle..level), data[moodle].Alignment == "Good")
	end
	if opposite then LSUtil.setMoodleValue(data, opposite, 0, false, false); end
end

function LSUtil.reduceMoodleValue(data, moodle, val, opposite, doHalo, overVal)
	if not LSUtil.isValidMoodle(data, moodle) then return; end
	local level = "_L"..tostring(math.max(1, data[moodle].Level))
	local result = data[moodle].Value-val
	data[moodle].Value = math.max(0, result)
	if doHalo then 
		if LSUtil.moodleIsSingleText(data, moodle) then level = "_L1"; end -- 1 text
		LSUtil.doSimpleArrowHalo(doHalo, " - "..getText("Moodles_"..data[moodle].name..level), data[moodle].Alignment == "Bad")
	end
	if overVal and result <= -0.2 then LSUtil.addMoodleValue(data, opposite, -result, false, doHalo, false); end
end

-------------- Sounds
local loopedSounds = false
local stopLoopedSounds = function()
	if not loopedSounds then Events.EveryOneMinute.Remove(stopLoopedSounds); return; end
	for n=#loopedSounds, 1, -1 do
		local args = loopedSounds[n]
		args[3] = args[3]-1
		if args[3] <= 0 then
			if args[1][args[4]](args[1], args[2]) then
				args[1][args[5]](args[1], args[2])
			end
			table.remove(loopedSounds, n)
		end
	end
	if #loopedSounds == 0 then loopedSounds = false; Events.EveryOneMinute.Remove(stopLoopedSounds); end
end

local delayedSounds = false
local delay_total = 30
local delay_count = 0
local playNextSound = function()
	if not delayedSounds then Events.OnTick.Remove(playNextSound); return; end
	delay_count = delay_count+1
	if delay_count < delay_total then return; end
	delay_count = 0
	for n=#delayedSounds, 1, -1 do
		local args = delayedSounds[n]
		if not args[1] or not args[2] then
			table.remove(delayedSounds, n)
		elseif not args[1][args[4]](args[1], args[2]) then
			args[1][args[5]](args[1], args[3])
			table.remove(delayedSounds, n)
		end
	end
	if #delayedSounds == 0 then delayedSounds = false; Events.OnTick.Remove(playNextSound); end
end

function LSUtil.playSoundCharacter(character, soundName, soundVar, loopMins, transmit, proxy, soundArgs, noiseArgs) --!
--soundVar(float or false) -- if float and higher than 1 then ZombRands soundVar and add it as string at the end of soundName
--loopMins(float or false) -- if float and higher than 1 then sound is looped, creates per minute event and sound ends when game minute count is reached; if 0 then it never ends (end has to be handled elsewhere)
--transmit(boolean) -- if true then uses playSound, otherwise uses playSoundImpl
--proxy(IsoObject or IsoGridSquare or false*) -- proxy, cannot be false if playSoundImpl
--soundArgs(table or false) -- sound args - volume, pitch
--noiseArgs(table or false) -- zombie attractor - radius, vol
	if isServer() and not isClient() then sendServerCommand(character, "LS", "PlaySoundCharacter", {soundName, soundVar, loopMins, transmit, proxy, soundArgs, noiseArgs}); return; end
	local soundFunc = (transmit and "playSound") or "playSoundImpl"
	local emitter = character:getEmitter()
	local soundStr = soundName
	if soundVar and soundVar > 1 then soundStr = soundName..tostring(ZombRand(soundVar)+1); end
	--if soundFunc == "playSoundImpl" and not proxy then proxy = character:getSquare(); end -- IsoGridSquare
	local sound = emitter[soundFunc](emitter, soundStr, proxy)
	if soundArgs then
		if soundArgs[1] then emitter:setVolume(sound, soundArgs[1]); end
		if soundArgs[2] then emitter:setPitch(sound, soundArgs[2]); end
		if soundArgs[3] then -- playAfter
			if not delayedSounds then
				delayedSounds = {}
				table.insert(delayedSounds, {emitter,sound,soundArgs[3],'isPlaying',soundFunc})
				Events.OnTick.Add(playNextSound)
			else
				table.insert(delayedSounds, {emitter,sound,soundArgs[3],'isPlaying','stopSound',soundFunc})
			end
		end
	end
	if noiseArgs then addSound(character,character:getX(),character:getY(),character:getZ(),noiseArgs[1],noiseArgs[2]); end
	if loopMins and loopMins > 1 then
		if not loopedSounds then
			loopedSounds = {}
			table.insert(loopedSounds, {emitter,sound,loopMins,'isPlaying','stopSound'})
			Events.EveryOneMinute.Add(stopLoopedSounds)
		else
			table.insert(loopedSounds, {emitter,sound,loopMins,'isPlaying','stopSound'})
		end
	end
	return sound
end

---------- Weapons

local function getWeaponMetaTables()
	return __classmetatables[HandWeapon.class].__index, __classmetatables[ArrayList.class].__index
end

function LSUtil.isValidWeapon(weapon)
	--[[
	LSUtil.debugDiagnostics("/shared/LSUtil", "LSUtil.isValidWeapon",{
	['weapon']=weapon,
	['instanceof(weapon, "HandWeapon")']=weapon and instanceof(weapon, "HandWeapon"),
	['weapon:IsWeapon()']=weapon and instanceof(weapon, "HandWeapon") and weapon:IsWeapon(),
	})
	]]--
	return weapon and instanceof(weapon, "HandWeapon") and weapon:IsWeapon()
end

function LSUtil.isValidRangedWeapon(weapon)
	return weapon and instanceof(weapon, "HandWeapon") and weapon:IsWeapon() and weapon:isRanged()
end

function LSUtil.isValidMeleeWeapon(weapon)
	return weapon and instanceof(weapon, "HandWeapon") and weapon:IsWeapon() and not weapon:isRanged()
end

function LSUtil.getWeaponCategories(weapon)
	if not LSUtil.isValidWeapon(weapon) then return false; end
	local categories = {}
	local allCats = Registries.WEAPON_CATEGORY:values()
	for i=0, allCats:size()-1 do
		local weaponCat = allCats:get(i)
		if weapon:isOfWeaponCategory(weaponCat) then
			local name = tostring(weaponCat)
			table.insert(categories, name)
		end
	end
	return categories
end

function LSUtil.weaponHasCategory(weapon, category)
	local categories = LSUtil.getWeaponCategories(weapon)
	if not categories or #categories == 0 then return false; end
	for n=1,#categories do
		if categories[n] == category then return true; end
	end
	return false
end

function LSUtil.getWeaponSubCategory(weapon)
	if not LSUtil.isValidWeapon(weapon) then return false; end
	local subCat = "None"
	local HandWeapon, ArrayList = getWeaponMetaTables()
	local cat = HandWeapon.getSubCategory(weapon)
	if cat and cat ~= "" then subCat = cat; end
	return subCat
end

function LSUtil.weaponIsExplosive(weapon)
	if not weapon or not instanceof(weapon, "HandWeapon") then return false; end
	local HandWeapon, ArrayList = getWeaponMetaTables()
	return HandWeapon.isInstantExplosion(weapon) and HandWeapon.getExplosionRange(weapon) > 0
end

function LSUtil.isWeaponType(character, weapon, typeStr)
	if not character or not LSUtil.isValidWeapon(weapon) or not WeaponType[typeStr] then return false; end
	local weaponType = WeaponType.getWeaponType(character)
	return weaponType and weaponType == WeaponType[typeStr]
end

function LSUtil.isBareHands(character)
	if not character or LSUtil.isValidWeapon(weapon) then return false; end
	local weaponType = WeaponType.getWeaponType(character)
	return weaponType and weaponType == WeaponType.UNARMED
end

function LSUtil.isWeaponFromName(weapon, name)
	local fullType = weapon and weapon.getFullType and weapon:getFullType()
	return fullType and string.find(fullType, name)
end

function LSUtil.hitWeapon(attacker, weapon, damage)
	return attacker and not attacker:isDoShove() and LSUtil.isValidWeapon(weapon) and damage
end

-------------- Farming

function LSUtil.getValidPlants(character, range, limit)
	local t = {}
	local playerX, playerY = character:getX(), character:getY()
	--local cellSqr = getCell():getGridSquare(character:getX(), character:getY(), character:getZ())
  	for x = playerX-range,playerX+range do
		for y = playerY-range,playerY+range do
			local square = getCell():getGridSquare(x,y,character:getZ())
			if square then
				local plant = CFarmingSystem.instance:getLuaObjectOnSquare(square)
				if plant and plant:canHarvest() then
					local plantData = {plant, false}
					table.insert(t, plantData)
					if #t >= limit then break; end
				end
			end
		end
	end
	return t
end

-------------- Zombies

function LSUtil.isValidZombie(zombie)
	return zombie and instanceof(zombie, "IsoZombie")
end

function LSUtil.zombieOnGround(zombie)
	return LSUtil.isValidZombie(zombie) and (zombie:isOnFloor() or zombie:getBumpedChr() or zombie:isKnockedDown() or zombie:isCrawling() or zombie:isRagdollFall())
end

-------------- Multiplayer

function LSUtil.canSeeOtherPlayers(character, range)
	if not isClient() then return false; end
	local playersList = {}
	local playerIso

	for x = character:getX()-range,character:getX()+range do
		for y = character:getY()-range,character:getY()+range do
			local square = getCell():getGridSquare(x,y,character:getZ());
			if square then
				for i = 0,square:getMovingObjects():size()-1 do
					local moving = square:getMovingObjects():get(i)
					if instanceof(moving, "IsoPlayer") then
						if moving:getUsername() == character:getUsername() then
							playerIso = moving
						else
							table.insert(playersList, moving)
						end
					end
				end
			end
		end
	end
	if not playerIso or #playersList == 0 then return false; end
	local seenBy = {}
	for i,v in pairs(playersList) do
		if v:getUsername() ~= character:getUsername() and v:isOutside() == character:isOutside() and
		character:CanSee(v) and playerIso:checkCanSeeClient(v) and (not v.isAnimal or not v:isAnimal()) then
			table.insert(seenBy, v)
		end
	end
	if #seenBy == 0 then return false; end
	return seenBy
end

-------------- Server
function LSUtil.syncItemModdata(item, movData, data, nested)
	if not isServer() then LSUtil.debugPrint("WARNING - LSUtil.syncItemModdata - not server"); return; end

	local itemData = item:getModData()
	if movData then
		LSUtil.debugPrint("LSUtil.syncItemModdata - adding movData")
		if not itemData.movableData then itemData.movableData = {}; end
		for k, v in pairs(movData) do
			itemData.movableData[k] = v
		end
	end
	if data then
		LSUtil.debugPrint("LSUtil.syncItemModdata - adding data")
		if nested then
			itemData[nested] = itemData[nested] or {}
			for k, v in pairs(data) do
				itemData[nested][k] = v
			end
		else
			for k, v in pairs(data) do
				itemData[k] = v
			end
		end
	end
	--syncItemModData(player, item)
	LSUtil.debugPrint("LSUtil.syncItemModdata - sync!")
	item:syncItemFields()
end

function LSUtil.createArtworkItem(player, arg)
	if not isServer() then
		sendClientCommand(player, "LS", "CreateArtworkItem", {arg[1], arg[2]})
		return
	end
    local author = arg[1]
	local data = arg[2]

	local newItem = player:getInventory():AddItem('Moveables.Moveable')
	newItem:ReadFromWorldSprite(data.result)
	newItem:getModData().movableData = newItem:getModData().movableData or {}
	newItem:getModData().movableData['artAuthor'] = author
	newItem:getModData().movableData['artBeauty'] = data["beauty"]
	newItem:getModData().movableData['artStyle'] = data["style"]
	newItem:getModData().movableData['artSize'] = data["size"]
	newItem:getModData().movableData['artQuality'] = data["quality"]
	if data['meltTime'] then newItem:getModData().movableData['meltTime'] = data["meltTime"]; end
	--self.newItem:setTooltip(getText("IGUI_PaintingAuthor")..": "..self.newItem:getModData().movableData['artAuthor'])
	--self.character:getInventory():AddItem('Moveables.Moveable'):ReadFromWorldSprite(self.easel:getModData().painting["result"])
	sendAddItemToContainer(player:getInventory(), newItem)
	--sendItemStats(newItem)
	newItem:syncItemFields()
	player:getInventory():setDrawDirty(true);
	sendServerCommand(player, "LS", "OpenArtworkReview", {player:getPlayerNum(), newItem, data.result})
end

function LSUtil.deleteItemOnChar(character, item)
	if isClient() and not isServer() then sendClientCommand(character, "LS", "RemoveItems", {{item:getID()}, nil}); return; end
	local itemCont = item:getContainer()
	if LSUtil.removeItemOnChar(character, item) then
		itemCont:Remove(item)
		if isServer() then sendRemoveItemFromContainer(itemCont, item); end
		itemCont:setDrawDirty(true)
		itemCont:setHasBeenLooted(true)
	end
end

function LSUtil.addItems(character, destItem, itemName, count)
	LSUtil.debugPrint("LSUtil.addItems called")
	local destCont
	if destItem then destCont = destItem.getInventory and destItem:getInventory(); end
	if not destCont then destCont = character:getInventory(); end
	local added = 0
	local prop = LSUtil.getItemProp(false, itemName)
	local weight = prop and prop.getWeight and prop:getWeight()
	if weight and destCont and destCont.isExistYet and destCont:isExistYet() and destCont:hasRoomFor(character, weight) then
		LSUtil.debugPrint("LSUtil.addItems loop")
		for n=1,count do
			if not destCont:hasRoomFor(character, weight) then break; end
			added = added+1
		end
		if added > 0 then
			destCont:setDrawDirty(true)
			destCont:setHasBeenLooted(true)
		end
	end
	
	if added > 0 then
		if isClient() and not isServer() then
			local id = destItem and destItem:getID()
			sendClientCommand(character, "LS", "AddItems_Player", {prop:getFullType(), added, id})
			return
		end
		for n=1, added do
			destCont:AddItem(itemName)
		end
		destCont:setDrawDirty(true)
		destCont:setHasBeenLooted(true)
	end
	LSUtil.debugPrint("LSUtil.addItems - added value is: "..tostring(added))
	return added
end

function LSUtil.consumeItemByType(destCont, itemName, count)
	if not count or not destCont or not instanceof(destCont, "ItemContainer") or not destCont:isExistYet() then return false; end
	local items = destCont:getItemsFromType(itemName)
	if not items or not items.size or items:size() < 1 then items = destCont:getItemsFromFullType(itemName); end
	if not items or not items.size or items:size() < 1 then return false; end
	local amount = 0
	for n=0,items:size() - 1 do
		local item = items:get(n)
		local itemCont = item:getContainer()
		if amount < count and itemCont and itemCont:isExistYet() and itemCont:isRemoveItemAllowed(item) and not itemCont:isEquipped() then
			if item:IsDrainable() then
				for n=1,count do
					if not item or amount >= count or item:getCurrentUses() < 1 then break; end
					item:UseAndSync()
					amount = amount+1
				end					
			else
				itemCont:DoRemoveItem(item)
				sendRemoveItemFromContainer(itemCont, item)
				amount = amount+1
			end
			itemCont:setDrawDirty(true)
			itemCont:setHasBeenLooted(true)
		end
	end
	if amount == 0 then return false; end
	return amount
end

function LSUtil.consumeItemOnChar(character, item)
	if not LSUtil.isValidInvItem(item) or not LSUtil.hasItem(character, false, item:getType()) then return false; end
	local itemCont = item:getContainer()
	if itemCont and itemCont:isExistYet() and itemCont:isRemoveItemAllowed(item) and LSUtil.removeItemOnChar(character, item) and not item:isEquipped() then
		if item:IsDrainable() then
			if item:getCurrentUses() < 1 then return false; end
			item:UseAndSync()				
		else
			itemCont:DoRemoveItem(item)
			sendRemoveItemFromContainer(itemCont, item)
		end
		itemCont:setDrawDirty(true)
		itemCont:setHasBeenLooted(true)
	else
		return false
	end
	return true
end

function LSUtil.consumeItemsOnChar(character, list)
	if not LSUtil.hasItemsOnChar(character, list) then return false; end
	for k, v in pairs(list) do
		local items = character:getInventory():getItemsFromType(k, true)
		local amount = 0
		for n=0,items:size() - 1 do
			local item = items:get(n)
			local itemCont = item:getContainer()
			if amount < v and itemCont and itemCont:isExistYet() and itemCont:isRemoveItemAllowed(item) and LSUtil.removeItemOnChar(character, item) then
				if item:IsDrainable() then
					for n=1,v do
						if not item or amount >= v or item:getCurrentUses() < 1 then break; end -- or try getCurrentUsesFloat < 0.0001
						item:UseAndSync()
						amount = amount+1
					end					
				else
					itemCont:DoRemoveItem(item)
					sendRemoveItemFromContainer(itemCont, item) -- b42
					amount = amount+1
				end
				itemCont:setDrawDirty(true)
				itemCont:setHasBeenLooted(true)
			end
		end
		if amount < v then return false; end
	end
	return true
end

function LSUtil.setItemVal(item, getter, setter, val)
	if not LSUtil.isValidInvItem(item) then return false; end
	local getFunc, setFunc = item[getter], item[setter]
	if not getFunc or not setFunc then return; end
	local itemFullType = item:getFullType() or ""
	if getFunc(item) ~= val then
		if setter == "ActualWeight" then
			item:setCustomWeight(true)
			setFunc(item, val)
			item:setWeight(val)
			if not isServer() or isClient() then ISInventoryPage.renderDirty = true; end
		else
			setFunc(item, val)
		end
		LSUtil.debugPrint("---- LS - called LSUtil.setItemVal, with key: "..setter..", and value: "..tostring(val)..", for item: "..itemFullType.." ----") --!
	end
end

function LSUtil.itemModify(item, mods)
	if not LSUtil.isValidInvItem(item) then return; end
	if isClient() and not isServer() then
		local parent = LSUtil.getItemParent(item)
		if instanceof(parent, "IsoObject") then
			local sprite = parent.getSprite and parent:getSprite()
			local spriteName = sprite and sprite:getName()
			sendClientCommand("LS", "SyncItemData_FromObj", {item:getID(),{parent:getX(),parent:getY(),parent:getZ(),spriteName or "none"}, mods})
		else
			local character = getPlayer()
			sendClientCommand(character, "LS", "SyncItemData_FromPlayer", {item:getID(), mods})
		end
		return
	end
	local itemName = (item.getDisplayName and item:getDisplayName()) or ""
	for k, v in pairs(mods) do
		if item[k] and type(item[k]) == "function" then
			item[k](item,v)
			LSUtil.debugPrint("-----WARNING---- LSUtil.itemMofidy -> "..itemName..": "..k..", with value: "..tostring(v))
		end
	end
	if isServer() then sendItemStats(item); end
end

-------------- Debug

function LSUtil.hasAdminRights()
	if not isClient() then return isDebugEnabled() or isServer(); end
	local player = getPlayer()
	local playerRole = player and player.getRole and player:getRole()
	return isAdmin() or (playerRole and playerRole.hasCapability and playerRole:hasCapability(Capability.UseDebugContextMenu))
end

function LSUtil.debugPrint(text)
	if not SandboxVars.Debug.LSVerbose or not LSUtil.hasAdminRights() then return; end
	local env = (isServer() and isClient() and "(coop)") or (isServer() and "(server)") or (isClient() and "(client)") or "(sp)"
	print(env.." ---- LS - "..text)
end

function LSUtil.debugDiagnostics(filePath, funcName, entries)
	if not SandboxVars.Debug.LSVerbose or not LSUtil.hasAdminRights() then return; end
	local text = ""
	for k, v in pairs(entries) do
		text = text.."\n------------- "..k..": "..tostring(v)
	end
	print("---- LS - Running Diagnostics ----\n----------------- (disable debug logs sandbox option to stop seeing this message)\n--------------------------\n----------------- File: "..
	filePath..".lua\n----------------- Func: "..funcName..text.."\n--------------------------\n------------- End of Diagnostics")
end

--[[
local function findItemsLoot(thisPlayer, ItemName)

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

function LSUtil.findItems(thisPlayer, itemNameList)

    local inventory = thisPlayer:getInventory();
	local it = inventory:getItems();
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
			v.id = findItemsLoot(thisPlayer, v.name)
		end
	end

	return itemNameList

end
]]--
