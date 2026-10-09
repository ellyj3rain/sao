-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

local LS_Commands = {}

local function getObjFromSqr(x, y, z, spriteName)
	local square = getCell():getGridSquare(x, y, z)
	if not square then return false; end
	for i=0,square:getObjects():size()-1 do
		local object = square:getObjects():get(i);
		local objSprite = object.getSprite and object:getSprite()
		if objSprite then
			local objSpriteName = objSprite.getName and objSprite:getName()
			if objSpriteName and objSpriteName == spriteName then return object; end
		end
		
		local objSpriteOrTextureName = object.getSpriteName and object:getSpriteName()
		if not objSpriteOrTextureName then objSpriteOrTextureName = object.getTextureName and object:getTextureName(); end
		
		if objSpriteOrTextureName and objSpriteOrTextureName == spriteName then return object; end
	end
	for i=0,square:getObjects():size()-1 do
		local object = square:getObjects():get(i);
		local attached = object.getAttachedAnimSprite and object:getAttachedAnimSprite()
		if attached then
			for n=1,attached:size() do
				local sprite = attached:get(n-1)
				if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() and luautils.stringStarts(sprite:getParentSprite():getName(), spriteName) then
					return object
				end
			end
		end
	end
	return false
end
--[[
LS_Commands["ModItem_FromPlayer"] = function(player, arg)
	local item = LSSync.getItemServer(arg[1], player:getInventory())
	if item then LSUtil.itemModify(item, arg[2]); else LSUtil.debugPrint("SERVER COMMAND ModItem_FromPlayer - NO ITEM FOUND"); end
end

LS_Commands["ModItem_FromObj"] = function(_, arg)
	local objInfo = arg[2]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND SyncObjMovData - NO OBJ FOUND"); return; end
	local item = LSSync.getItemServer(arg[1], obj:getContainer())
	if item then LSUtil.itemModify(item, arg[3]); else LSUtil.debugPrint("SERVER COMMAND ModItem_FromObj - NO ITEM FOUND"); end
end
]]--
LS_Commands["SyncItemData_FromPlayer"] = function(player, arg)
	local playerInv = player:getInventory()
	local item = LSSync.getItemServer(arg[1], playerInv)
	if not item then -- might be inside backpack
		local items = playerInv:getItems()
		for n=0,items:size()-1 do
			local bag = items:get(n)
			local bagContainer = bag and bag.getItemContainer and bag:getItemContainer()
			if bagContainer then
				item = LSSync.getItemServer(arg[1], bagContainer)
				if item then break; end
			end
		end
	end
	if item then LSSync.transmitItemMovData(item, player, nil, arg[2], arg[3], arg[4]); else LSUtil.debugPrint("SERVER COMMAND SyncItemData_FromPlayer - NO ITEM FOUND"); end
end

LS_Commands["SyncItemData_FromObj"] = function(_, arg)
	local objInfo = arg[2]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND SyncItemData_FromObj - NO OBJ FOUND"); return; end
	local item = LSSync.getItemServer(arg[1], obj:getContainer())
	if item then LSSync.updateAndSend(item, arg[3], arg[4], arg[5]); else LSUtil.debugPrint("SERVER COMMAND SyncItemData_FromObj - NO ITEM FOUND"); end
end

LS_Commands["SyncObjMovData"] = function(_, arg)
	local objInfo = arg[1]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND SyncObjMovData - NO OBJ FOUND for x="..tostring(objInfo[1])..", y="..tostring(objInfo[2])..
	", z="..tostring(objInfo[3])..", spriteName="..tostring(objInfo[4])); return; end
	LSSync.updateAndSend(obj, arg[2], arg[3])
end

LS_Commands["CreateFluidCont_Obj"] = function(_, arg)
	local objInfo = arg[1]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND CreateFluidCont_Obj - NO OBJ FOUND for x="..tostring(objInfo[1])..", y="..tostring(objInfo[2])..
	", z="..tostring(objInfo[3])..", spriteName="..tostring(objInfo[4])); return; end
	LSUtil.getOrCreateFluidContainer(obj, arg[2])
end

LS_Commands["UseFluid_Obj"] = function(_, arg)
	local objInfo = arg[1]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND UseFluid_Obj - NO OBJ FOUND"); return; end
	LSUtil.useObjFluid(obj, arg[2])
end

LS_Commands["SetMirrorMakeup"] = function(player, arg)
	LSMirrorMenu_server.setMirrorChanges(player, arg)
end

LS_Commands["RemoveBrokenGlass"] = function(player, arg)
    local x = arg[1]
	local y = arg[2]
	local z = arg[3]
	local square = getCell():getGridSquare(x, y, z)
	if not square then return end
	for i=0,square:getObjects():size()-1 do
		local object = square:getObjects():get(i)
		if object then
			local texName = object.getTextureName and object:getTextureName()
			if texName and luautils.stringStarts(texName, "brokenglass_") and ISMoveableTools.isObjectMoveable(object) then
				ISMoveableTools.isObjectMoveable(object):pickUpMoveable(player, square, object, true)
				break
			end
		end
	end
end

LS_Commands["MakeWellFed"] = function(player, arg)
	LSUtil.MakeCharWellFed(player, arg)
end

LS_Commands["learnRecipes"] = function(player, arg)
	LSUtil.learnRecipes(player, arg)
end

LS_Commands["Character_Explosion"] = function(player, arg)
	LSUtil.makeCharExplode(player, arg)
end

LS_Commands["Character_MakeWet"] = function(player, arg)
	LSUtil.makeCharWet(player, arg[1])
end

LS_Commands["Character_CleanSelf"] = function(player, arg)
	LSUtil.changeCharVisualDirt(player, arg[1], arg[2], arg[3])
end

LS_Commands["dropHeavyItems"] = function(player, arg)
	if player then forceDropHeavyItems(player); end
end

LS_Commands["reduceAllStiffness"] = function(player, arg)
	local value = arg[1]
	local bodyDamage = player:getBodyDamage()
	if not bodyDamage then return; end
	local bodyParts = bodyDamage:getBodyParts()
	if not bodyParts then return; end
	for i=0,bodyParts:size()-1 do
		local bodyPart = bodyParts:get(i)
		if bodyPart then
			local stiff = bodyPart:getStiffness()
			if stiff and stiff > 0 then
				local newStiff = math.max(0,stiff-value)
				bodyPart:setStiffness(newStiff)
				player:getFitness():removeStiffnessValue(BodyPartType.ToString(bodyPart:getType()))
				--local bodyPartType = bodyPart:getType()
				--player:getFitness():removeStiffnessValue(bodyPartType:ToString(bodyPartType))
			end
		end
	end
end

LS_Commands["AddItems_Player"] = function(player, arg)
	local playerInv = player:getInventory()
	local itemFullType = arg[1]
	local amount = arg[2]
	local itemInfo = arg[3]
	local destCont
	if itemInfo then
		local item = LSSync.getItemServer(itemInfo, playerInv)
		destCont = item and item.getInventory and item:getInventory()
	end
	if not destCont then destCont = playerInv; end
	local items = destCont:AddItems(itemFullType, amount)
	sendAddItemsToContainer(destCont, items)
end

LS_Commands["AddGeneralHealth"] = function(player, arg)
	local value = arg[1]
	local bodyDamage = player:getBodyDamage()
	if not bodyDamage then return; end
	bodyDamage:AddGeneralHealth(value)
end

LS_Commands["addPainBodyPart"] = function(player, arg)
	local bP = arg[1]
	local value = arg[2]
	local bodyDamage = player:getBodyDamage()
	if not bodyDamage then return; end
	if not BodyPartType[bP] then return; end
	local bodyPart = bodyDamage:getBodyPart(BodyPartType[bP])
	bodyPart:setAdditionalPain(value)
	--syncBodyPart(bodyPart)
end

LS_Commands["ChangeCharacterMoodGroup"] = function(player, arg)
	local stats = player:getStats()
	if not stats then return; end
	local moodList = arg[1]
	for n=1, #moodList do
		local moodInfo = moodList[n]
		if moodInfo and moodInfo[1] and moodInfo[2] and CharacterStat[moodInfo[2]] and stats[moodInfo[1]] and moodInfo[3] then
			stats[moodInfo[1]](stats, CharacterStat[moodInfo[2]], moodInfo[3])
			sendPlayerStat(player, CharacterStat[moodInfo[2]])
			--print("ChangeCharacterMoodGroup, Mood = "..moodInfo[2])
			--print("Value = "..tostring(moodInfo[3]))
			--print("Method = "..moodInfo[1])
			--if SyncPlayerStatsPacket['Stat_'..moodInfo[4]] then
			--	print('ChangeCharacterMoodGroup - sync stats packet - Stat_'..moodInfo[4])
			--	syncPlayerStats(player, SyncPlayerStatsPacket['Stat_'..moodInfo[4]])
			--end
		end
	end
	--syncPlayerStats(player)
end

LS_Commands["ChangeCharacterMood"] = function(player, arg)
	local method = arg[1]
	local upMood = arg[2]
	local value = arg[3]
	local stats = player:getStats()
	if not stats then return; end
	if not CharacterStat[upMood] then return; end
	if upMood == "WETNESS" then
		local bodyDamage = player:getBodyDamage()
		local wetMethod = "decreaseBodyWetness"
		if method == "set" then
			local parts = bodyDamage:getBodyParts()
			for n=0,parts:size()-1 do parts:get(n):setWetness(value); end
		else
			if method == "add" then wetMethod = "increaseBodyWetness"; end
			bodyDamage[wetMethod](bodyDamage, value)
		end
	end
	stats[method](stats, CharacterStat[upMood], value)
	sendPlayerStat(player, CharacterStat[upMood])
end

LS_Commands["AddXP"] = function(player, arg)
	local perkName = arg[1]
	local xp = arg[2]
	if not Perks[perkName] then return; end
	addXp(player, Perks[perkName], xp)
	SyncXp(player)
end

LS_Commands["AddXPBatch"] = function(player, arg)
	LSUtil.giveXPBatch(player, arg)
end

LS_Commands["SavePlayerData"] = function(player, arg)
	local data = arg[1]
	local playerData = player:getModData()
	for k, v in pairs(data) do
		playerData[k] = v
	end
end

LS_Commands["ChangeMaxWeight"] = function(player, arg)
	local newWeight = arg[1]
	if newWeight then player:setMaxWeightBase(newWeight); end
end

LS_Commands["ChangeTrait"] = function(player, arg)
	local trait = arg[1]
	local method = arg[2]
	local self = player:getCharacterTraits()
	if not CharacterTrait[trait] then return; end
	local hasTrait = player:hasTrait(CharacterTrait[trait])
	if method == "add" and hasTrait then return; end
	if method == "remove" and not hasTrait then return; end
	self[method](self, CharacterTrait[trait]);
	player:modifyTraitXPBoost(CharacterTrait[trait], method == "remove");
	SyncXp(player)
end

local function checkAndRemoveClothingItem(player, container, item, fullType)
	--print("checkAndRemoveItem - start")
	--print("checkAndRemoveItem - item ID is: "..item:getID())
	for x=0,container:getItems():size() - 1 do
		local newItem = container:getItems():get(x);
		--if newItem then print("checkAndRemoveItem - newItem ID is: "..newItem:getID()); end
		if newItem then 
			if (item and newItem:getID() == item:getID()) or (fullType and newItem.getFullType and newItem:getFullType() == fullType) then
				if player:isEquippedClothing(newItem) then player:removeWornItem(newItem); end
				container:Remove(newItem)
				sendRemoveItemFromContainer(container, newItem)
				--print("checkAndRemoveItem - found item, removed")
				break
			end
		end
	end
end

local function checkAndRemoveItem(container, item, fullType)
	--print("checkAndRemoveItem - start")
	--print("checkAndRemoveItem - item ID is: "..item:getID())
	for x=0,container:getItems():size() - 1 do
		local newItem = container:getItems():get(x);
		--if newItem then print("checkAndRemoveItem - newItem ID is: "..newItem:getID()); end
		if newItem then 
			if (item and newItem:getID() == item:getID()) or (fullType and newItem.getFullType and newItem:getFullType() == fullType) then
				container:Remove(newItem)
				sendRemoveItemFromContainer(container, newItem)
				--print("checkAndRemoveItem - found item, removed")
				break
			end
		end
	end
end

local function getItemByID(container, itemID)
	for x=0,container:getItems():size() - 1 do
		local newItem = container:getItems():get(x);
		if newItem and newItem:getID() == itemID then
			return newItem
		end
	end
	return false
end

local function doRemoveItemFromID(id, cont, player)
	local item = cont:getItemWithID(id)
	if not item then return; end
	if player then player:removeFromHands(item); end
	cont:Remove(item)
	sendRemoveItemFromContainer(cont, item)
end

LS_Commands["RemoveItems"] = function(player, arg)
	local t = arg[1]
	if not t then return; end
	local inv, hands
	if arg[2] then
		local obj = getObjFromSqr(arg[2][1], arg[2][2], arg[2][3], arg[2][4])
		if obj then inv = obj:getContainer(); end
	else
		hands = true
		inv = player:getInventory()
	end
	if not inv then return; end

	for n=1,#t do
		local predicateItem = function(item)
			return item and item:getID() == t[n]
		end
		local item = inv:containsEvalRecurse(predicateItem) and inv:getFirstEvalRecurse(predicateItem)
		local cont = item and item:getContainer()
		if cont then
			if hands then player:removeFromHands(item); end
			cont:Remove(item)
			sendRemoveItemFromContainer(cont, item)
		end
	end
end

LS_Commands["TransferItemWorld"] = function(player, arg)
	LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - start")
	local item = arg[1]
	local fromPlayer = arg[2]
	local wear = arg[3]
	local coords = arg[4]
	if not item then LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - not item, returning"); return; end
	local square = getCell():getGridSquare(coords[1], coords[2], coords[3])
	if not square then LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - error, no square"); end
	
	local floorObjects = square and square.getWorldObjects and square:getWorldObjects()
	if not floorObjects then LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - error, no floorObjects"); end
	local floorItem
	if not fromPlayer then
		for i=0,floorObjects:size()-1 do
			local worldItem = floorObjects:get(i)
			local newItem = worldItem and worldItem.getItem and worldItem:getItem()
			if newItem and newItem:getID() == item:getID() then
				floorItem = newItem.getWorldItem and newItem:getWorldItem()
				if floorItem then
					item = newItem
					LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - found floorItem")
					break
				end
			end
		end
	end
	local playerInv = player and player.getInventory and player:getInventory()
	if (not fromPlayer and not floorItem) or not playerInv then LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - not fromPlayer and not floorItem or not playerInv, returning"); return; end
	if not fromPlayer then
		LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - calling TransferHelper.transferItem not fromPlayer")
		TransferHelper.transferItem(player, item, false, playerInv, false, wear, "floor") -- player, item, srcContainer, destContainer, dropSquare, autoWear, srcOverride, destOverride
	else
		LSUtil.debugPrint("(server) LS_Commands.TransferItemWorld - calling TransferHelper.transferItem fromPlayer")
		TransferHelper.transferItem(player, item, playerInv, false, square, wear, false, "floor")
	end
end

LS_Commands["TransferItem"] = function(player, arg)
	LSUtil.debugPrint("(server) LS_Commands.TransferItem - start")
	local item = arg[1]
	local fromPlayer = arg[2]
	local wear = arg[3]
	local objInfo = arg[4]
	if not item then LSUtil.debugPrint("(server) LS_Commands.TransferItem - not item, returning"); return; end
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	local objCont = obj and obj.getContainer and obj:getContainer()
	local playerInv = player and player.getInventory and player:getInventory()
	if not objCont or not playerInv then LSUtil.debugPrint("(server) LS_Commands.TransferItem - not objCont or not playerInv, returning"); return; end
	if not fromPlayer then
		LSUtil.debugPrint("(server) LS_Commands.TransferItem - calling TransferHelper.transferItem not fromPlayer")
		TransferHelper.transferItem(player, item, objCont, playerInv, false, wear) -- player, item, srcContainer, destContainer, dropSquare, autoWear
	else
		LSUtil.debugPrint("(server) LS_Commands.TransferItem - calling TransferHelper.transferItem fromPlayer")
		TransferHelper.transferItem(player, item, playerInv, objCont, false, wear)
	end
end

LS_Commands["TransferItemFrom"] = function(player, arg)
	local item = arg[1]
	local wear = arg[2]
	local objInfo = arg[3]
	if not item then return; end
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	local destCont = obj and obj:getContainer()
	--local destCont = item and item:getContainer()
	if destCont then
		destCont:setDrawDirty(true);
		destCont:Remove(item)
		sendRemoveItemFromContainer(destCont, item)
	else
		return
	end
	local playerInv = player:getInventory()
	playerInv:setDrawDirty(true)
	playerInv:AddItem(item)
	sendAddItemToContainer(playerInv, item)
	destCont:Remove(item)
	checkAndRemoveItem(destCont, item)
	if wear then
		if (instanceof(item, "InventoryContainer") and item:canBeEquipped() ~= "") then
			player:setWornItem(item:canBeEquipped(), item);
			--getPlayerInventory(player:getPlayerNum()):refreshBackpacks();
		else
			player:setWornItem(item:getBodyLocation(), item);
		end
		triggerEvent("OnClothingUpdated", player)
	end
end

LS_Commands["TransferItemTo"] = function(player, arg)
	local item = arg[1]
	local objInfo = arg[2]
	if not item then return; end
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	local destCont = obj and obj:getContainer()
	local playerInv = player:getInventory()
	if player:isEquippedClothing(item) then player:removeWornItem(item); end
	playerInv:setDrawDirty(true)
	if destCont then
		playerInv:Remove(item)
		sendRemoveItemFromContainer(playerInv, item)
		destCont:setDrawDirty(true);
		destCont:AddItem(item)
		sendAddItemToContainer(destCont, item)
		playerInv:Remove(item)
		checkAndRemoveClothingItem(player, playerInv, item)
	end
end

LS_Commands["AddWorldItem"] = function(player, arg)
	local item, amount, posX, posY, posZ, sqrX, sqrY, sqrZ = arg[1], arg[2], arg[3], arg[4], arg[5], arg[6], arg[7], arg[8]
	if not item or not amount then return; end
	local square = getCell():getGridSquare(sqrX, sqrY, sqrZ)
	if not square then return end
	for n=1, amount do
		local newPosX, newPosY = posX, posY
		if not posX then newPosX = ZombRandFloat(0.0, 1.0); end
		if not posY then newPosY = ZombRandFloat(0.0, 1.0); end
		square:AddWorldInventoryItem(item, newPosX, newPosY, posZ)
	end
end

local function doRemokeMakeup(player, item)
	if item then
		player:removeWornItem(item)
		player:getInventory():Remove(item)
		sendRemoveItemFromContainer(player:getInventory(), item)
	end
end

LS_Commands["RemoveMakeup"] = function(player, arg)
    local group = arg[1]
	local all = arg[2]

	local makeupList = {
		face = {"FullFace","Eyes","EyesShadow","Lips"},
		mouth = {"Lips"},
		eyes = {"Eyes","EyesShadow"},
	}

	local wornItems = player:getWornItems()
	--for i=0, wornItems:size()-1 do
	for i = wornItems:size() - 1, 0, -1 do
		local worn = wornItems:get(i)
		local item = worn and worn.getItem and worn:getItem()
		local location = item and item.getBodyLocation and item:getBodyLocation()
		if location and luautils.stringStarts(location:getTranslationName(), "MakeUp") then
			for _,makeup in ipairs(MakeUpDefinitions.makeup) do
				if makeup.item == item:getFullType() then
					if all then
						doRemokeMakeup(player, item)
						break
					elseif makeupList[group] then
						for n=1,#makeupList[group] do
							if makeup.category == makeupList[group][n] then
								doRemokeMakeup(player, item)
								break
							end
						end
					end
				end
			end
		end
	end
end

LS_Commands["ModifyItemStat"] = function(_, arg)
    local item = arg[1]
	local data = arg[2]
	if data then
		for k, v in pairs(data) do
			if type(v) == "table" then
				item[k](item, v[1], v[2], v[3], v[4])
			else
				item[k](item, v)
			end
		end
	end
	-- usage - ['getMinDmg']=10
	sendItemStats(item)
end

LS_Commands["CreateArtworkItem"] = function(player, arg)
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

LS_Commands["ModifySprite"] = function(_, arg)
    local objInfo = arg[1]
	local sprite = arg[2]
	local overlaySprite = arg[3]
	local get = arg[4]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("LS_Commands - ModifySprite, no obj found") return; end
	if get then
		sprite = getSprite(sprite)
	else
		if not overlaySprite then overlaySprite = ""; end
		obj:setOverlaySprite(overlaySprite, true)
	end
	obj:setSprite(sprite)
	-- use setSpriteFromName for wall objects (setSprite won't change properties in their case)
	-- obj:getSprite():getProperties():has(IsoFlagType.WallOverlay)
	obj:transmitUpdatedSpriteToClients()
end

LS_Commands["ModifyOverlaySprite"] = function(_, arg)
    local objInfo = arg[1]
	local overlaySprite = arg[2]
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj or not obj.setOverlaySprite then LSUtil.debugPrint("LS_Commands - ModifyOverlaySprite, no implementation found") return; end
	if not overlaySprite then overlaySprite = ""; end
	obj:setOverlaySprite(overlaySprite, true)
	obj:transmitUpdatedSpriteToClients()
end

LS_Commands["RemoveObject"] = function(_, arg)
	local obj = getObjFromSqr(arg[1], arg[2], arg[3], arg[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND RemoveObject - NO OBJ FOUND"); return; end
	local movData = obj:getModData().movableData
	if not movData or not movData['artBeauty'] then return; end
	local square = getCell():getGridSquare(arg[1], arg[2], arg[3])
	square:transmitRemoveItemFromSquare(obj)
	square:RemoveTileObject(obj)
end

LS_Commands["ModifyObjData"] = function(_, arg)
    local objInfo = arg[1]
	local movabledata = arg[2]
	local data = arg[3]
	local nested = arg[4]
	
	local obj = getObjFromSqr(objInfo[1], objInfo[2], objInfo[3], objInfo[4])
	if not obj then LSUtil.debugPrint("SERVER COMMAND ModifyObjData - NO OBJ FOUND"); return; end
	
	local itemData = obj:getModData()

	if movabledata then
		itemData.movableData = itemData.movableData or {}
		for k, v in pairs(movabledata) do
			itemData.movableData[k] = v
		end
	end
	if data then
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
	obj:transmitModData()
	--syncItemModData(obj)
end

LS_Commands["ModifyItemData"] = function(player, arg)
    local oldItem = arg[1]
	local movData = arg[2]
	local data = arg[3]
	local nested = arg[4]
	local item = getItemByID(player:getInventory(), oldItem:getID())
	if not item then return; end
	LSUtil.debugPrint("LS_Commands[ModifyItemData] -- running LSUtil.syncItemModdata")
	LSUtil.syncItemModdata(item, movData, data, nested)
end

LS_Commands["AdjustFluidItem"] = function(player, arg)
    local oldItem = arg[1]
	local useDelta = arg[2]
	local item = getItemByID(player:getInventory(), oldItem:getID())
	if not item then LSUtil.debugPrint("LS_Commands[AdjustFluidItem] - no item found"); return; end
	LSUtil.adjustFluid(item, useDelta, player)
end

LS_Commands["ChangeTexture_Item"] = function(player, arg)
    local id = arg[1]
	local choice = arg[2]
	local item = getItemByID(player:getInventory(), id)
	if not item then LSUtil.debugPrint("LS_Commands[ChangeTexture_Item] -- no item found with ID "..tostring(id)); return; end
	LSUtil.changeTexture_Item(player, item, choice)
end

LS_Commands["UseItem_Player"] = function(player, arg)
	local item = LSSync.getItemServer(arg[1], player:getInventory())
	if not LSUtil.isValidDrainableItem(item) then LSUtil.debugPrint("LS_Commands[UseItem] - no item found"); return; end
	LSUtil.useItem(item, player, nil, arg[2])
	--local uses = arg[2]
	--local delta = arg[3] and arg[3]*0.01
	--[[ -- works but is finicky
	local ogDelta = item:getUseDelta()
	if delta and ogDelta ~= delta then
		local currentUses = item:getCurrentUses()
		local newMax = math.floor((currentUses*ogDelta)/delta)
		item:setUseDelta(delta)
		item:setCurrentUses(newMax)
		LSUtil.debugPrint("LS_Commands[UseItem] - ogDelta = "..tostring(ogDelta).." / getUseDelta = "..tostring(item:getUseDelta()).." / ogCurrentUses = "..tostring(currentUses)..
		" / getCurrentUses = "..tostring(item:getCurrentUses()).." / newMax = "..tostring(newMax).." / delta = "..tostring(delta))
	end
	for n=1,uses do
		item:UseAndSync()
		local uses = item and item.getCurrentUsesFloat and item:getCurrentUsesFloat()
		if not uses or uses <= 0 then break; end
	end
	sendItemStats(item)
	]]--
end

LS_Commands["CreateFluidCont_Item"] = function(player, arg)
	local item = LSSync.getItemServer(arg[1], player:getInventory())
	LSUtil.getOrCreateFluidContainer(item, arg[2])
end

LS_Commands["renameItem"] = function(player, arg)
	local item = LSSync.getItemServer(arg[1], player:getInventory())
	LSUtil.renameItem(player, item, arg[2])
end

LS_Commands["AddItemToPlayer"] = function(player, arg)
	local itemFN = arg[1]
	local amount = arg[2]
	local playerInv = player:getInventory()
	playerInv:setDrawDirty(true)
	for n=1,amount do
		local item = playerInv:AddItem(itemFN)
		sendAddItemToContainer(playerInv, item)
	end
end

LS_Commands["RemoveItemFromPlayer"] = function(player, arg)
	local itemFN = arg[1]
	local amount = arg[2]
	local playerInv = player:getInventory()
	playerInv:setDrawDirty(true)
	for n=1,amount do
		checkAndRemoveItem(playerInv, false, itemFN)
	end
end

LS_Commands["SyncSqrData"] = function(_, arg)
    local sqrInfo = arg[1]
	local data = arg[2]

	local square = getCell():getGridSquare(sqrInfo[1], sqrInfo[2], sqrInfo[3])
	if not square then return end
	local sqrData = square:getModData()

	if data and sqrData then
		for k, v in pairs(data) do
			sqrData[k] = v
		end
	else
		LSUtil.debugPrint("SERVER COMMAND ModifyObjData - NO DATA FOUND");
	end
	square:transmitModdata() -- d instead D -- seriously?
end

LS_Commands["logAmbition"] = function(_, arg)
	local currentTime = " on ["..tostring(PZCalendar.getInstance():getTime()).."] "
	local admin, id = "", arg[1] or ""
	if arg[5] then admin = " with admin rights."; end
    local text = id.." - [Player:"..arg[2].."/Char:"..arg[6].."] concluded ambition ["..arg[4].."] "..currentTime..admin
	local file = getFileWriter("LSAmbitionLog.log",true,true)
	if not file then return; end -- failed to write file
	file:write(text.."\n")
	file:close()
end

LS_Commands["CompleteTargetAmbt"] = function(_, arg)
    local Target = getPlayerByOnlineID(arg[1])
    local Target_id = arg[1]
	local ambtName = arg[2]
    sendServerCommand(Target, "LS", "CompleteAmbtSelf", {Target_id, ambtName})
end

LS_Commands["ResetTargetAmbt"] = function(_, arg)
    local Target = getPlayerByOnlineID(arg[1])
    local Target_id = arg[1]
	local ambtName = arg[2]
    sendServerCommand(Target, "LS", "ResetAmbtSelf", {Target_id, ambtName})
end

LS_Commands["LSSCTest"] = function(_, arg)

    local Argument = arg[1]


	if not Argument then
		--print("server received LSSCTest from client and Argument is nil")
	else
		--print("server received LSSCTest from client")
	end

end

LS_Commands["Social_sendInfo"] = function(player, arg)
	local targetID = arg[1]
	local srcInfo = arg[2]
    local target = getPlayerByOnlineID(targetID)
	if target then sendServerCommand(target, "LS", "Social_InfoSent", {srcInfo}); end
end

LS_Commands["Social_requestInfo"] = function(player, arg)
	local srcID = player:getOnlineID()
	local targetID = arg[1]
    local target = getPlayerByOnlineID(targetID)
	if target then sendServerCommand(target, "LS", "Social_InfoRequested", {srcID}); end
end

LS_Commands["InteractionStart"] = function(_, arg)

    local Target = getPlayerByOnlineID(arg[1])
    local Target_id = arg[1]
   -- local Source = arg[2]
	local Source = arg[2]
    --local SourceX = arg[3]
    --local SourceY = arg[4]
	local Interaction = arg[3]
	local IsClose = arg[4]
	local actionArg = arg[5]
	--print("server received InteractionStart from client and is sending the command")
   -- sendServerCommand(Target, "LS", "WasAskedToInteract", {Target_id, Source, SourceX, SourceY, Interaction, IsClose, actionArg})
    sendServerCommand(Target, "LS", "WasAskedToInteract", {Target_id, Source, Interaction, IsClose, actionArg})
end

LS_Commands["StopOrStartInteraction"] = function(_, arg)

    local Target = getPlayerByOnlineID(arg[1])
    local Target_id = arg[1]
	local InteractionState = arg[2]
	--print("server received StopOrStartInteraction from client and is sending the command")
    sendServerCommand(Target, "LS", "ChangeInteractionState", {Target_id, InteractionState})

end

LS_Commands["makeNauseous"] = function(_, arg)
    local Target = getPlayerByOnlineID(arg[1])
    local Target_id = arg[1]
    sendServerCommand(Target, "LS", "makeNauseous", {Target_id})
end

LS_Commands["SendGetEmbarrassed"] = function(_, arg)

    local Target = getPlayerByOnlineID(arg[1])
    local Target_id = arg[1]
	--print("server received SendGetEmbarrassed from client and is sending the command")
    sendServerCommand(Target, "LS", "GetEmbarrassed", {Target_id})

end

LS_Commands["AddDirtPuddle"] = function(_, arg)
	local coords = arg[1]
	local isOverlay = arg[2]
	local entity
	if isOverlay then
		entity = getObjFromSqr(coords[1], coords[2], coords[3], coords[4])
	else
		entity = getCell():getGridSquare(coords[1], coords[2], coords[3])
	end
	if not entity then LSUtil.debugPrint("SERVER COMMAND AddDirtPuddle - no entity found"); return; end
	LSServerCommandHandler("CreateDirtPuddle", {entity, isOverlay, arg[3]})
end

LS_Commands["DebugAddLitter"] = function(_, arg)

    local Sx = arg[1]
    local Sy = arg[2]
	local Sz = arg[3]
	local SolidOrOverlay = arg[4]
	local LitterSprite = arg[5]
	local AvailableFloorList = {}
	local targetFloor
	local sSquare = getCell():getGridSquare(Sx, Sy, Sz)

  	for x = Sx-1,Sx+1 do---get x range
		for y = Sy-1,Sy+1 do----get y range

			local thisSquare = getCell():getGridSquare(x, y, Sz)---get grid square (our radius)
        
			if thisSquare and sSquare and thisSquare:getRoom() == sSquare:getRoom() and thisSquare:isOutside() == sSquare:isOutside() and thisSquare:isInARoom() and thisSquare:getFloor() and not 
			thisSquare:isSolid() and not thisSquare:isSolidTrans() then
            
			for i=0,thisSquare:getObjects():size()-1 do-----------search objects for each square on the radius (floor counts as an object)
				local ThisObject = thisSquare:getObjects():get(i);
				if instanceof(ThisObject, "IsoObject") then
				local object = ThisObject
				local hasSolidL = false
				if object then--solid litter is the result of direct actions and as such can happen anywhere the action takes place
					local hasOverlayL = false
					local attachedsprite = object:getAttachedAnimSprite()
					if object:getTextureName() and
					(luautils.stringStarts(object:getTextureName(), "overlay_messages") or 
					luautils.stringStarts(object:getTextureName(), "overlay_graffiti") or 
					--luautils.stringStarts(object:getTextureName(), "floors_burnt") or 
					luautils.stringStarts(object:getTextureName(), "overlay_blood") or 
					luautils.stringStarts(object:getTextureName(), "blood_floor") or
					luautils.stringStarts(object:getTextureName(), "overlay_grime") or 
					--luautils.stringStarts(object:getTextureName(), "trash_") or 
					luautils.stringStarts(object:getTextureName(), "trash&junk") or 
					luautils.stringStarts(object:getTextureName(), "d_floorleaves") or 
					luautils.stringStarts(object:getTextureName(), "d_trash")) then-----------if object already has solid litter then do not add more
						hasSolidL = true
					end
					if object:getOverlaySprite() and object:getOverlaySprite():getName() and
					(luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_messages") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_graffiti") or 
					--luautils.stringStarts(object:getOverlaySprite():getName(), "floors_burnt") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_blood") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "blood_floor") or
					luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_grime") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "trash_") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "trash&junk") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "d_floorleaves") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "d_trash") or
					luautils.stringStarts(object:getOverlaySprite():getName(), "LS_HScraps") or
					luautils.stringStarts(object:getOverlaySprite():getName(), "LS_Scraps")) then-----------if object already has overlay litter then do not add more
						hasOverlayL = true
					end
					if object and attachedsprite and object:isFloor() then--overlays such as dirt and grime almost always occur based on random factors and movement so it only happens indoors
						for n=1,attachedsprite:size() do
							local sprite = attachedsprite:get(n-1)
							if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() and
							(luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_messages") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_graffiti") or 
							--luautils.stringStarts(sprite:getParentSprite():getName(), "floors_burnt") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_blood") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "blood_floor") or
							luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_grime") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "trash_") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "trash&junk") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "d_floorleaves") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "LS_HScraps") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "d_trash")) then-----------if object already has overlay litter then do not add more
								hasOverlayL = true
							end
						end
								
					end
					if SolidOrOverlay == 2 and not hasOverlayL then
						table.insert(AvailableFloorList, object)
					end
				end
					if SolidOrOverlay == 1 and not hasSolidL then
						table.insert(AvailableFloorList, thisSquare)
					end
					
				end
				end
				
			end
			
		end
		
	end

	if #AvailableFloorList > 0 then
		local randomTile = ZombRand(#AvailableFloorList) + 1
		targetFloor = AvailableFloorList[randomTile]
		if targetFloor then
			if SolidOrOverlay == 1 then
				local NewLitterObj = IsoObject.new(targetFloor, LitterSprite)
				targetFloor:AddTileObject(NewLitterObj)
				NewLitterObj:transmitCompleteItemToClients()
				targetFloor:transmitAddObjectToSquare(NewLitterObj, -1)
				--targetFloor:transmitAddObjectToSquare(NewLitterObj.javaObject, -1)
			
			
			elseif SolidOrOverlay == 2 then
				--targetFloor:setOverlaySprite(LitterSprite, 1, 1, 1, 1, true)--string/transmit
				--targetFloor:setOverlaySprite(LitterSprite, true)--string/transmit
				--targetFloor:transmitUpdatedSpriteToClients()

				local square = targetFloor:getSquare()
				local objOnFloor
				if square then
					for i=1,square:getObjects():size() do
						local thisObject = square:getObjects():get(i-1)
						if thisObject then
							local objSprite = thisObject:getSprite()
							if objSprite then
								local objProperties = objSprite:getProperties()
								if objProperties:has("BlocksPlacement") then
									objOnFloor = true
								end
							end
						end
					end
					if not objOnFloor then
						targetFloor:setOverlaySprite(LitterSprite, 1, 1, 1, 1)--string/transmit
						targetFloor:transmitUpdatedSpriteToClients()
					end
				end
				
				--targetFloor:setOverlaySprite(LitterSprite, 1, 1, 1, 1, false)--string/transmit
				--if not objOnFloor then
				--	targetFloor:setOverlaySprite(LitterSprite, true)--string/transmit
				--	targetFloor:transmitUpdatedSpriteToClients()
				--end
				
			end
		end
	end
end

LS_Commands["RemoveDirtTileDebug"] = function(_, arg)

    local x = arg[1]
	local y = arg[2]
	local z = arg[3]
	local range = arg[4]

	local square = getCell():getGridSquare(x,y,z)
	if not square then return; end
	local sqrX, sqrY = square:getX(), square:getY()

	local listFull = {"overlay_grime","trash&junk","trash_","d_floorleaves","d_trash","LS_Scraps","brokenglass_",
	"overlay_messages","overlay_graffiti","overlay_blood","LS_HScraps","blood_floor"}

  	for x = sqrX-range,sqrX+range do
		for y = sqrY-range,sqrY+range do
			local thisSqr = getCell():getGridSquare(x,y,z)
			if thisSqr then
				local mustRemove = {}
				for j=0,thisSqr:getObjects():size()-1 do
					if j < 0 or j > thisSqr:getObjects():size() then break; end
					local object = thisSqr:getObjects():get(j)
					if object then
						local texName = object:getTextureName()
						local spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName()
						local hasChange

						for n=1, #listFull do
							if texName and luautils.stringStarts(texName, listFull[n]) then table.insert(mustRemove, object); break; end
							if spriteName and luautils.stringStarts(spriteName, listFull[n]) then object:setOverlaySprite("", true); hasChange = true; spriteName = false; end
							local attachedsprite = object:getAttachedAnimSprite()
							if attachedsprite then
								for i=0,attachedsprite:size()-1 do
									if i < 0 or i > attachedsprite:size() then break; end
									local sprite = attachedsprite:get(i)
									local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
									if spriteParentName and luautils.stringStarts(spriteParentName, listFull[n]) then hasChange = true; object:RemoveAttachedAnim(i); break; end
								end
							end
						end
						if hasChange then object:transmitUpdatedSpriteToClients(); end
						--if mustRemove then thisSqr:transmitRemoveItemFromSquare(object); thisSqr:RemoveTileObject(object); end
					end
				end
				if #mustRemove > 0 then
					for n=1, #mustRemove do
						thisSqr:transmitRemoveItemFromSquare(mustRemove[n]); thisSqr:RemoveTileObject(mustRemove[n]);
					end
				end
			end
		end
	end

end

LS_Commands["RemoveDirtTile"] = function(_, arg)

    local x = arg[1]
    local y = arg[2]
	local z = arg[3]
	local isHeavy = arg[4]

    local thisSqr = getCell():getGridSquare(x, y, z)
        
    if not thisSqr then return; end

	local listDirt = {"overlay_grime","trash&junk","trash_","d_floorleaves","d_trash","LS_Scraps"}
	local listBlood = {"overlay_messages","overlay_graffiti","overlay_blood","LS_HScraps","blood_floor"}
	local mustRemove = {}
	for j=0,thisSqr:getObjects():size()-1 do
		if j < 0 or j > thisSqr:getObjects():size() then break; end
		local object = thisSqr:getObjects():get(j)
		if object then
			local attachedsprite = object:getAttachedAnimSprite()
			local texName = object:getTextureName()
			local spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName()

			if not isHeavy then
				for n=1, #listDirt do
					if texName and luautils.stringStarts(texName, listDirt[n]) then table.insert(mustRemove, object); break; end
					if spriteName and luautils.stringStarts(spriteName, listDirt[n]) then object:setOverlaySprite("", true); object:transmitUpdatedSpriteToClients(); break; end
					if attachedsprite then
						local removed
						for i=0,attachedsprite:size()-1 do
							if i < 0 or i > attachedsprite:size() then break; end
							local sprite = attachedsprite:get(i)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listDirt[n]) then removed = true; object:RemoveAttachedAnim(i); object:transmitUpdatedSpriteToClients(); break; end
						end
						if removed then break; end
					end
				end
			else
				for n=1, #listBlood do
					if texName and luautils.stringStarts(texName, listBlood[n]) then table.insert(mustRemove, object); break; end
					if spriteName and luautils.stringStarts(spriteName, listBlood[n]) then object:setOverlaySprite("", true); object:transmitUpdatedSpriteToClients(); break; end
					if attachedsprite then
						local removed
						for i=0,attachedsprite:size()-1 do
							if i < 0 or i > attachedsprite:size() then break; end
							local sprite = attachedsprite:get(i)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listBlood[n]) then removed = true; object:RemoveAttachedAnim(i); object:transmitUpdatedSpriteToClients(); break; end
						end
						if removed then break; end
					end
				end
			end
		end
	end
	if #mustRemove > 0 then
		for n=1, #mustRemove do
			thisSqr:transmitRemoveItemFromSquare(mustRemove[n]); thisSqr:RemoveTileObject(mustRemove[n]);
		end
	end

end

LS_Commands["TeleportSittingLocation"] = function(_, arg)

    local TargetName = getPlayerByOnlineID(arg[1])
    local TargetName_id = arg[1]
    local SourcePlayerName = arg[2]
    local teleportX = arg[3][1]
	local teleportY = arg[3][2]
	local NSvar = arg[3][3]
	--print("server received from client and is sending the command")
    sendServerCommand(TargetName, "LS", "TeleportSittingLocation", {SourcePlayerName, teleportX, teleportY, NSvar})

    local otherPlayers = getOnlinePlayers()
    
	if otherPlayers then
	
    for index = 1, otherPlayers:size() do
		local sourcePlayer = otherPlayers:get(index-1)

        if sourcePlayer and sourcePlayer:getDisplayName() == SourcePlayerName then
			--thisPlayer:Say("teleporting " .. tostring(sourcePlayer:getDisplayName()))
            if teleportX and teleportY then
				sourcePlayer:setY(teleportY)
				sourcePlayer:setX(teleportX)
				--sourcePlayer:setLy(teleportY)
				--sourcePlayer:setLx(teleportX)
				
				if not string.match(tostring(sourcePlayer:getCurrentState()), "PlayerSitOnGroundState") then
					sourcePlayer:setVariable("SittingToggleStart", NSvar)
					sourcePlayer:reportEvent("EventSitOnGround");
					sourcePlayer:setVariable("SittingToggleLoop", NSvar)
				end
				
            end

            break

        end

    end

	end

end

LS_Commands["ChangeAnimVarMulti"] = function(_, arg)

    local SourcePlayerName = arg[1]
    local AnimType = arg[2]
	local AnimVar = arg[3]
    local AnimType2 = arg[4]
	local AnimVar2 = arg[5]
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "ChangeAnimVarMulti", {SourcePlayerName, AnimType, AnimVar, AnimType2, AnimVar2})

    local otherPlayers = getOnlinePlayers()
 
    --for index = 0, getOnlinePlayers():size() - 1 do

        --local sourcePlayer = getOnlinePlayers():get(index)
	if otherPlayers then
	
    for index = 1, otherPlayers:size() do
		local sourcePlayer = otherPlayers:get(index-1)

       -- if sourcePlayer:getDisplayName() == SourcePlayerName and sourcePlayer:getDisplayName() ~= thisPlayer:getDisplayName() then
        if sourcePlayer and sourcePlayer:getDisplayName() == SourcePlayerName then
			--thisPlayer:Say("source is " .. tostring(sourcePlayer:getDisplayName()))
			
            if AnimVar then
                sourcePlayer:setVariable(AnimType, AnimVar)
				if AnimType == "SittingToggleStart" and ((AnimVar == "N") or (AnimVar == "S")) then
					--thisPlayer:Say("reporting eventsitOnGround")
					sourcePlayer:reportEvent("EventSitOnGround")
				end
            else
                sourcePlayer:clearVariable(AnimType)
            end

            if AnimVar2 then
                sourcePlayer:setVariable(AnimType2, AnimVar2)
				if AnimType2 == "SittingToggleStart" and ((AnimVar2 == "N") or (AnimVar2 == "S")) then
					--thisPlayer:Say("reporting eventsitOnGround")
					sourcePlayer:reportEvent("EventSitOnGround")
				end
            else
                sourcePlayer:clearVariable(AnimType2)
            end

            break

        end

    end

	end

end

LS_Commands["ChangeAnimVar"] = function(_, arg)

    local TargetName = getPlayerByOnlineID(arg[1])
    local TargetName_id = arg[1]
    local SourcePlayerName = arg[2]
	local args = arg[3]
    sendServerCommand(TargetName, "LS", "ChangeAnimVar", {SourcePlayerName, args})

    local otherPlayers = getOnlinePlayers()
	if not otherPlayers then return; end
	
    for index = 1, otherPlayers:size() do
		local sourcePlayer = otherPlayers:get(index-1)
        if sourcePlayer and sourcePlayer:getDisplayName() == SourcePlayerName then
			for n=1, #args, 2 do
				if n == #args then break; end
				if args[n] and type(args[n]) == "string" then
					if args[n+1] then
						sourcePlayer:setVariable(args[n], args[n+1])
						if args[n] == "SittingToggleStart" then sourcePlayer:reportEvent("EventSitOnGround"); end
					else
						sourcePlayer:clearVariable(args[n])
					end
				end
			end
            break
        end
    end
end

LS_Commands["IsPlayingMusic"] = function(_, arg)

    local listener = getPlayerByOnlineID(arg[1])
    local listener_id = arg[1]
    local SourceMusiclvl = arg[2]
	--print("server received from client and is sending the command")
    sendServerCommand(listener, "LS", "IsListeningToMusic", {listener_id, SourceMusiclvl})

end

LS_Commands["IsStartingDuet"] = function(_, arg)

    local currentPerformer = getPlayerByOnlineID(arg[1])
    local currentPerformer_id = arg[1]
    local SourceWaitingDuet = arg[2]
	--print("server received from client and is sending the command")
    sendServerCommand(currentPerformer, "LS", "IsStartingDuet", {currentPerformer_id, SourceWaitingDuet})

end

LS_Commands["IsPlayingDJ"] = function(_, arg)

    local DJlistener = getPlayerByOnlineID(arg[1])
    local DJlistener_id = arg[1]
    local SourceMusiclvl = arg[2]
	local SourceDJ = arg[3]
	local SourceIsDJ = arg[4]
	--print("server received from client and is sending the command")
    sendServerCommand(DJlistener, "LS", "IsListeningToDJ", {DJlistener_id, SourceMusiclvl, SourceDJ, SourceIsDJ})

end

LS_Commands["AskIfIsDancing"] = function(_, arg)

    local DanceTarget = getPlayerByOnlineID(arg[1])
    local DanceTarget_id = arg[1]
    local DanceProposer = arg[2]
	--print("server received AskToDance from client and is sending the command")
    sendServerCommand(DanceTarget, "LS", "WasAskedIfIsDancing", {DanceTarget_id, DanceProposer})

end

LS_Commands["OtherPlayerIsDancing"] = function(_, arg)

    local DanceProposer = getPlayerByOnlineID(arg[1])
    local DanceProposer_id = arg[1]
    local IsDancing = arg[2]
	--print("server received AcceptedDance from client and is sending the command")
    sendServerCommand(DanceProposer, "LS", "OtherPlayerIsDancingResponse", {DanceProposer_id, IsDancing})

end

LS_Commands["AskToDance"] = function(_, arg)

    local DanceTarget = getPlayerByOnlineID(arg[1])
    local DanceTarget_id = arg[1]
    local DanceProposer = arg[2]
	--print("server received AskToDance from client and is sending the command")
    sendServerCommand(DanceTarget, "LS", "WasAskedToDance", {DanceTarget_id, DanceProposer})

end

LS_Commands["AcceptedDance"] = function(_, arg)

    local DanceProposer = getPlayerByOnlineID(arg[1])
    local DanceProposer_id = arg[1]
    local DancePartner = arg[2]
	local PartnerX = arg[3]
	local PartnerY = arg[4]
	--print("server received AcceptedDance from client and is sending the command")
    sendServerCommand(DanceProposer, "LS", "DanceWasAccepted", {DanceProposer_id, DancePartner, PartnerX, PartnerY})

end

LS_Commands["StopDance"] = function(_, arg)

    local DanceTarget = getPlayerByOnlineID(arg[1])
    local DanceTarget_id = arg[1]
	--print("server received StopDance from client and is sending the command")
    sendServerCommand(DanceTarget, "LS", "PartnerStoppedDancing", {DanceTarget_id})

end

LS_Commands["FaceDanceProposer"] = function(_, arg)

    local DancePartner = getPlayerByOnlineID(arg[1])
    local DancePartner_id = arg[1]
    local ProposerX = arg[2]
	local ProposerY = arg[3]
	print("server received FaceDanceProposer from client and is sending the command")
    sendServerCommand(DancePartner, "LS", "FaceDancingProposer", {DancePartner_id, ProposerX, ProposerY})

end

LS_Commands["ChangeDiscoStyle"] = function(_, arg)

    local style = arg[1]
    local x = arg[2]
    local y = arg[3]
	local z = arg[4]
	local s = arg[5]
	--print("server received from client and is sending the command")
	
    sendServerCommand("LS", "ChangeDiscoStyle", {style, x, y, z, s})
	
	local sqr = getCell():getGridSquare(x,y,z);
	local DiscoBall
	
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end
					
						if customName == "Disco Ball" then
							DiscoBall = thisObject;
						end
					end
				end
			end
	



	if DiscoBall:hasModData() and
	DiscoBall:getModData().OnOff ~= nil and
	DiscoBall:getModData().OnOff == "on" then
	
		DiscoBall:getModData().Mode = style
		DiscoBall:getModData().Shuffle = s
	end

end

LS_Commands["TurnDiscoBallOff"] = function(_, arg)

    local playerDiscoCommand = arg[1]
    local x = arg[2]
    local y = arg[3]
	local z = arg[4]
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "TurnDiscoBallOff", {playerDiscoCommand, x, y, z})

	local sqr = getCell():getGridSquare(x,y,z);
	local DiscoBall
	
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Disco Ball" then
							DiscoBall = thisObject;
						end
					end
				end
			end


	if not DiscoBall then
	--print("failed")
	return end

	if DiscoBall:hasModData() and
	DiscoBall:getModData().OnOff ~= nil and
	DiscoBall:getModData().OnOff == "on" then
	
		DiscoBall:getModData().OnOff = playerDiscoCommand
		--Jukebox:transmitModData()
	else
		return
	end


end

LS_Commands["JukeboxStart"] = function(_, arg)

    local x = arg[1]
    local y = arg[2]
	local z = arg[3]
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "JukeboxStart", {x, y, z})

end

LS_Commands["TurnJukeboxOff"] = function(_, arg)

    local x = arg[1]
    local y = arg[2]
	local z = arg[3]
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "TurnJukeboxOff", {x, y, z})

	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end
					
						if customName == "Jukebox" then
							Jukebox = thisObject;
						end
					end
				end
			end


	if not Jukebox then
	--print("failed")
	return end

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil and
	Jukebox:getModData().OnOff == "on" then
	
		Jukebox:getModData().OnOff = "off"
		Jukebox:getModData().OnPlay = "nothing"
		--Jukebox:transmitModData()
	else
		return
	end


end

LS_Commands["JukeboxStyleChangePlayerPlaylist"] = function(_, arg)

    local x = arg[1]
    local y = arg[2]
	local z = arg[3]
	local style = arg[4]
	local length = arg[5]
	local genre = arg[6]
	local customPlaylist = arg[7]
	
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "JukeboxStyleChangeCustom", {x, y, z, style, length, genre, customPlaylist})

	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Jukebox" then
							Jukebox = thisObject;
						end
					end
				end
			end


	if not Jukebox then
	--print("failed")
	return end

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil and
	Jukebox:getModData().OnOff == "on" then
	
		Jukebox:getModData().OnPlay = "playing"
		Jukebox:getModData().Style = style
		Jukebox:getModData().customPlaylist = customPlaylist
		--Jukebox:transmitModData()
	else
		return
	end


end

LS_Commands["JukeboxStyleChange"] = function(_, arg)

    local x = arg[1]
    local y = arg[2]
	local z = arg[3]
	local style = arg[4]
	local length = arg[5]
	local genre = arg[6]
	
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "JukeboxStyleChange", {x, y, z, style, length, genre})

	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Jukebox" then
							Jukebox = thisObject;
						end
					end
				end
			end


	if not Jukebox then
	--print("failed")
	return end

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil and
	Jukebox:getModData().OnOff == "on" then
	
		Jukebox:getModData().OnPlay = "playing"
		Jukebox:getModData().Style = style
		--Jukebox:transmitModData()
	else
		return
	end


end

LS_Commands["StopJukeSong"] = function(_, arg)

    local x = arg[1]
    local y = arg[2]
	local z = arg[3]
	--print("server received from client and is sending the command")
    sendServerCommand("LS", "StopJukeSong", {x, y, z})

end

LS_Commands["isPlayingJuke"] = function(_, arg)

	--local isPlayingJukeSong = nil;
	local genre = arg[2]
	local JukeReusableID = arg[1]
	local playercommand = arg[6]
	
--	print("server received from client and is sending the command")
--	if sqr then
--	print("is sqr")

--			for i=1,sqr:getObjects():size() do
--				local thisObject = sqr:getObjects():get(i-1)
--
--				local thisSprite = thisObject:getSprite()
--				
--				if thisSprite ~= nil then
--				
--					local properties = thisObject:getSprite():getProperties()
--
--					if properties ~= nil then
--						local groupName = nil
--						local customName = nil
--						local thisSpriteName = nil
--					
--						--local thisSprite = thisObject:getSprite()
--						if thisSprite:getName() then
--							thisSpriteName = thisSprite:getName()
--						end
--					
--						if properties:has("GroupName") then
--							groupName = properties:get("GroupName")
--						end
--					
--						if properties:has("CustomName") then
--							customName = properties:get("CustomName")
--						end
--
--						if customName == "Jukebox" then
--							Jukebox = thisObject;
--							spriteName = thisSpriteName;
--						end
--					end
--				end
--			end


--	if not Jukebox then
--	print("failed")
--	return end

	local x = arg[3]
	local y = arg[4]
	local z = arg[5]
	
--    local emitter = getWorld():getFreeEmitter();
--	emitter:setPos(x, y, 0);

			if playercommand == "beforeplay" then
			--print("trying to send beforeplay")
			sendServerCommand("LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})

			end

			if playercommand == "stop" then
			--print("trying to send stop")
			sendServerCommand("LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})

			end

    --sendServerCommand("LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})
	--isPlayingJukeSong = getSoundManager():playSound(genre, sqr, 5, 75, 0.7, true);
	--addSound(Jukebox, x, y, z, 30, 10)


	--end
end

LS_Commands["JukeTurnedOn"] = function(_, arg)
	local Jukebox, spriteName

	--local isPlayingJukeSong = nil;
	local genre = arg[1]
	local x = arg[2]
	local y = arg[3]
	local z = arg[4]
	local JukeReusableID = arg[5]
	local playercommand = arg[6]
	local sqr = getCell():getGridSquare(x, y, z);
--	print("server received from client and is sending the command")
	if sqr then
	--print("is sqr")

			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						--local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Jukebox" then
							Jukebox = thisObject;
							spriteName = thisSpriteName;
						end
					end
				end
			end


	if not Jukebox then
	--print("failed")
	return end

local JukeboxLightSprite = "LS_JukeboxLight_A_1"
local JukeboxCell = Jukebox:getCell()

-- MainLight is the existing source's transient native handle. Native moddata
-- save omits userdata; a saved overlay alone never proves a current lamp.
local mainLight = Jukebox:getModData().MainLight
local currentLamp = mainLight and mainLight ~= 0 and JukeboxCell:getLamppostPositions():contains(mainLight)
local currentOverlay = getObjFromSqr(Jukebox:getX(), Jukebox:getY(), Jukebox:getZ(), JukeboxLightSprite)
if currentLamp and currentOverlay then return end
if not currentOverlay then
    local JukeboxLight = IsoObject.new(sqr, JukeboxLightSprite)
    JukeboxLight:setName("JukeLight")
    JukeboxLight:transmitModData()
    sqr:AddTileObject(JukeboxLight)
end
if not currentLamp then
    Jukebox:getModData().MainLight = IsoLightSource.new(Jukebox:getX(), Jukebox:getY(), Jukebox:getZ(), 75, 75, 0, 2)
    JukeboxCell:addLamppost(Jukebox:getModData().MainLight)
end
Jukebox:transmitModData()

	
--    local emitter = getWorld():getFreeEmitter();
--	emitter:setPos(x, y, 0);

			--if playercommand == "beforeplay" then
			--print("trying to send beforeplay")
			--sendServerCommand("LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})

			--end

			--if playercommand == "stop" then
			--print("trying to send stop")
			--sendServerCommand("LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})

			--end

    --sendServerCommand("LS", "isPlayingJuke", {genre, x, y, z, JukeReusableID, playercommand})
	--isPlayingJukeSong = getSoundManager():playSound(genre, sqr, 5, 75, 0.7, true);
	--addSound(Jukebox, x, y, z, 30, 10)


	end
end

---------- GLOBAL MODDATA

function LS_OnInitGlobalModData()
    local lsModData = ModData.getOrCreate("LSDATA")
	if not lsModData["SO"] then lsModData["SO"] = {}; end
	LSgetSandboxOptions(lsModData["SO"])
	if not lsModData["AMBT"] then lsModData["AMBT"] = {}; end
	if not lsModData["BTY"] then lsModData["BTY"] = {}; end
    --if not ModData.exists("LSDATAPlaylists") then
    --    local LSModDataPlaylists = ModData.create("LSDATAPlaylists")
    --    LSModDataPlaylists["CustomPlaylists"] = {};
    --end
end

--function LS_OnReceiveGlobalModData(ModData, NewData)
--    if ModData ~= "LSDATAPlaylists" then return; end;
--    if not NewData then return; end
--	ModData.add(ModData, NewData);
--end

Events.OnInitGlobalModData.Add(LS_OnInitGlobalModData)
--Events.OnReceiveGlobalModData.Add(LS_OnReceiveGlobalModData)

LS_Commands.OnClientCommand = function(module, command, playerObj, args)

    if module == 'LS' and LS_Commands[command] then
        LS_Commands[command](playerObj, args)
    end
end

if isServer() or (not isServer() and not isClient()) then Events.OnClientCommand.Add(LS_Commands.OnClientCommand); end
--Events.OnClientCommand.Add(LS_Commands.OnClientCommand)

LS_Commands["UpdateAmbt"] = function(_, args)
	local lsModData = ModData.getOrCreate("LSDATA")
	local ogAmbt = args[1]
	local name = args[2]
	local key = args[3]
	local value = args[4]
	local forceReset = args[5]
	if (not lsModData["AMBT"][name]) or (not lsModData["AMBT"][name].custom) then lsModData["AMBT"][name] = ogAmbt; end
	--print("LS_Commands - UpdateAmbt... key is: "..key); print("LS_Commands - UpdateAmbt... value is: "..tostring(value))
	if (key ~= "resetAdm") and (lsModData["AMBT"][name][key] == value) then return; end
	lsModData["AMBT"][name][key] = value
	if (key == "resetAdm") and value then lsModData["AMBT"][name].custom = false;
	else lsModData["AMBT"][name].custom = true; lsModData["AMBT"][name].resetAdm = false; end
	lsModData["AMBT"][name].resetF = forceReset
	ModData.transmit("LSDATA")
	sendServerCommand("LS", "ResetAmbt", {name, lsModData["AMBT"][name].resetAdm})
end


LS_Commands.ChangePlayerState = function(playerObj, args)
    ModData.get("LSDATA")[playerObj:getUsername()] = args
    ModData.transmit("LSDATA")
end

local function logCustomBeauty(data, args)
	if isClient() then return; end
	if not data then return; end
	local file = getFileReader("LSCustomBeautyValues.ini",true)
	if not file then return; end -- failed to write file
	local oldValue
	while true do
		local line = file:readLine()
		if not line then file:close(); break; end
		local splitedLine = string.split(line, "=")
		local name = splitedLine[1]
		if name == args[1] then
			oldValue = true
			file:close()
			break
		end
	end
	if not oldValue then -- add
		file = getFileWriter("LSCustomBeautyValues.ini",true,true) -- append is true (add to)
		file:write(args[1].."="..tostring(args[2]).."\n")
	else -- edit
		file = getFileWriter("LSCustomBeautyValues.ini",true,false) -- append is false (overwrite)
		for k,v in pairs(data) do
			file:write(tostring(k).."="..tostring(v).."\n")
		end
	end
	file:close()
end

LS_Commands["UpdateServerBeauty"] = function(_, args)
	local lsModData = ModData.getOrCreate("LSDATA")
	local spriteName = args[1]
	local val = args[2]
	lsModData["BTY"][spriteName] = val
	ModData.transmit("LSDATA")
	sendServerCommand("LS", "UpdateClientBeauty", {spriteName, val})
	logCustomBeauty(lsModData["BTY"], args)
end

local function getBeautyLines()
	local file = getFileReader("LSCustomBeautyValues.ini",false)
	if not file then return false; end
	local t, n = {}, 0
	while true do
		local line = file:readLine()
		if not line then file:close(); break; end
		local splitedLine = string.split(line, "=")
		local name = splitedLine[1]
		local val = splitedLine[2]
		t[name] = tonumber(val)
		n = n+1
	end
	return t, n
end

LS_Commands["ImportServerBeauty"] = function(_, args)
	if isClient() then return; end
	local lsModData = ModData.getOrCreate("LSDATA")
	local allLines, num = getBeautyLines()	
	if not allLines or num == 0 then print("-------- WARN: ImportServerBeauty FAILED: LSCustomBeautyValues.ini empty or null"); return; end
	lsModData["BTY"] = allLines
	ModData.transmit("LSDATA")
	sendServerCommand("LS", "ReloadClientBeauty", {})
	print("-------- WARN: ImportServerBeauty COMPLETED: values from LSCustomBeautyValues.ini imported successfully")
end

LS_Commands["UpdateOuthouseRangeMap"] = function(_, args)
	local lsModData = ModData.getOrCreate("LSDATA")
	local x, y = args[1], args[2]
	if not x or not y or not lsModData["SO"] or not lsModData["SO"]["OUTHOUSEAREAS"] then print("-------- WARN: UpdateOuthouseRangeMap FAILED - invalid args or data"); return; end
	if LSHygiene.TF.isInOuthouseArea(x, y, lsModData["SO"]["OUTHOUSEAREAS"]) then print("-------- WARN: UpdateOuthouseRangeMap FAILED - inside range"); return; end
	table.insert(lsModData["SO"]["OUTHOUSEAREAS"], {x, y})
	ModData.transmit("LSDATA")
	sendServerCommand("LS", "UpdateClientOuthouseAreas", {x, y})
end