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

require "Helper/ActionHelper"

TransferHelper = {};

TransferHelper.litCandleExtinguish = function(item, player)
    local playerObj = player

    local candle = playerObj:getInventory():AddItem("Base.Candle");
    candle:setCurrentUsesFloat(item:getCurrentUsesFloat());
    candle:setCondition(item:getCondition());
    candle:setFavorite(item:isFavorite());
    if item == playerObj:getPrimaryHandItem() then
        playerObj:setPrimaryHandItem(candle);
    else
        playerObj:setSecondaryHandItem(candle);
    end
    playerObj:getInventory():Remove(item);
    return candle;
end

TransferHelper.unequipItem = function(item, player)
    local playerObj = player
    if not playerObj:isEquipped(item) then return end
    if item ~= nil and item:getType() == "CandleLit" then item = TransferHelper.litCandleExtinguish(item, player) end
    ISTimedActionQueue.add(ISUnequipAction:new(playerObj, item, 50));
end

TransferHelper.dropItem = function(item, player)

	local playerObj = player

    if item:getType() == "CandleLit" and item:isEquipped() then
        item = TransferHelper.litCandleExtinguish(item, player)
    end

	if not playerObj:isHandItem(item) then
	--	local hotbar = getPlayerHotbar(isoPlayer)
	--	if hotbar and hotbar:isItemAttached(item) then
	--		hotbar:removeItem(item, true)
	--	else
		TransferHelper.unequipItem(item, player)
	--	end
	end
	
	--ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), ISInventoryPage.floorContainer[isoPlayer + 1]))

	local dest
	local containerList = ArrayList.new();
	local playerNum = playerObj and playerObj:getPlayerNum() or -1
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end

--	if #containerList > 0 then
--		for i,v in ipairs(containerList:getItems()) do
	for i=0,containerList:size()-1 do
		local container = containerList:get(i);
		if container:getType() == "floor" then
			dest = container
			break
		end
	end

	if dest then
		ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), dest))
	end
--	ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
 --  ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, playerObj:getInventory(), ISInventoryPage.floorContainer[player + 1]));
end

TransferHelper.onDropItems = function(items, player, single)
	local playerObj = player

    local noVehicle = true
    local vehicleNoWindow = true
    local vehicleWindowOpen = true

    local vehicle = playerObj:getVehicle()

    if vehicle ~= nil then
        noVehicle = false
        local seat = vehicle:getSeat(playerObj)
        local door = vehicle:getPassengerDoor(seat)
        local windowPart = VehicleUtils.getChildWindow(door)
        if windowPart and (not windowPart:getItemType() or windowPart:getInventoryItem()) then
            vehicleNoWindow = false
            local window = windowPart:getWindow()
            if window:isOpenable() and not window:isOpen() then
                vehicleWindowOpen = false
            end
        end
    end

    if not (noVehicle or vehicleNoWindow or vehicleWindowOpen) then return end

	if single then
		if not items:isFavorite() then
			TransferHelper.dropItem(items, player)
		end
	else
		items = ISInventoryPane.getActualItems(items)
	--	ISInventoryPaneContextMenu.transferItems(items, playerObj:getInventory(), player, true)
		for _,item in ipairs(items) do
			if not item:isFavorite() then
				TransferHelper.dropItem(item, player)
			end
		end
	end
end

TransferHelper.onMoveItemsTo = function(items, dest, player, single, src)
    if dest:getType() == "floor" then
		if single then
			if not items:isFavorite() then
				TransferHelper.dropItem(items, player)
			end
			return
		else
			return TransferHelper.onDropItems(items, player, single)
		end
    end
    local playerObj = player
	if not ActionHelper.walkToContainer(playerObj, dest) then
		return
	end
	if single then
		local srcCont = src or items:getContainer()
		if playerObj:isEquipped(items) then
			ISTimedActionQueue.add(ISUnequipAction:new(playerObj, items, 50));
		end
		--ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, items, items:getContainer(), dest))
		ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, items, srcCont, dest))
	else
		for i,item in ipairs(items) do
			local srcCont = src or item:getContainer()
			if playerObj:isEquipped(item) then
				ISTimedActionQueue.add(ISUnequipAction:new(playerObj, item, 50));
			end
			ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, srcCont, dest))
		end
	end
end

local function getDropItemOffset(character, square, item)
	-- local dropX = character:getX() - math.floor(character:getX())
	-- local dropY = character:getY() - math.floor(character:getY())
	local dropX = ZombRandFloat(0.0, 1.0)
	local dropY = ZombRandFloat(0.0, 1.0)
	local dropZ = character:getZ() - math.floor(character:getZ())
	dropZ = square:getApparentZ(dropX, dropY) - square:getZ()
	if character:isSeatedInVehicle() then
		dropZ = math.floor(character:getZ())
	end
	-- if (square ~= character:getCurrentSquare()) or getCore():getOptionDropItemsOnSquareCenter() then
	if getCore():getOptionDropItemsOnSquareCenter() then
		dropX = ZombRand(3, 7) / 10.0
		dropY = ZombRand(3, 7) / 10.0
		dropZ = square:getApparentZ(dropX, dropY) - square:getZ()
	end
	return dropX,dropY,dropZ
end

local function addItemToContainer(destContainer, item)
	if not destContainer then return; end
	destContainer:setDrawDirty(true)
	destContainer:AddItem(item)
	if isServer() then sendAddItemToContainer(destContainer, item); end
end

TransferHelper.transferItem = function(character, item, srcContainer, destContainer, dropSquare, autoWear, srcOvr, destOvr)
	LSUtil.debugPrint("(shared) TransferHelper.transferItem - start")
	
	local srcContType = srcOvr or (srcContainer and srcContainer.getType and srcContainer:getType())
	local destContType = destOvr or (destContainer and destContainer.getType and destContainer:getType())
	local worldItem = item.getWorldItem and item:getWorldItem()

	if (not srcOvr and not srcContainer) or (not destOvr and not destContainer) or (srcContainer and destContainer and srcContainer == destContainer) then LSUtil.debugPrint("(shared) TransferHelper.transferItem - not cont or same cont, returning"); return item; end
	local fromPlayer = character:getInventory() ~= destContainer

	if isClient() and not isServer() then
		LSUtil.debugPrint("(shared) TransferHelper.transferItem - client")
		if srcContType and srcContType == "floor" then
			LSUtil.debugPrint("(shared) TransferHelper.transferItem - source is floor, sending command and returning")
			local sqr = worldItem and worldItem:getSquare()
			if sqr then sendClientCommand(character, "LS", "TransferItemWorld", {item, fromPlayer, autoWear, {sqr:getX(),sqr:getY(),sqr:getZ()}}); end
		elseif destContType and destContType == "floor" and dropSquare then
			LSUtil.debugPrint("(shared) TransferHelper.transferItem - dest is floor, sending command and returning")
			sendClientCommand(character, "LS", "TransferItemWorld", {item, fromPlayer, autoWear, {dropSquare:getX(),dropSquare:getY(),dropSquare:getZ()}})
		else
			local parentObj = srcContainer.getParent and srcContainer:getParent()
			if fromPlayer then parentObj = destContainer.getParent and destContainer:getParent(); end
			if parentObj then 
				LSUtil.debugPrint("(shared) TransferHelper.transferItem - source or dest is obj, sending command and returning")
				sendClientCommand(character, "LS", "TransferItem", {item, fromPlayer, autoWear, {parentObj:getX(),parentObj:getY(),parentObj:getZ(),parentObj:getSprite():getName()}})
			else
				LSUtil.debugPrint("(shared) TransferHelper.transferItem - no valid source or dest, returning")
			end
		end
		return item
	else
		LSUtil.debugPrint("(shared) TransferHelper.transferItem - server")
	end

	if srcContainer then
		srcContainer:DoRemoveItem(item);
		if isServer() then sendRemoveItemFromContainer(srcContainer, item); end
	end

	-- deal with containers that are floor
	if destContType == "floor" then
		LSUtil.debugPrint("(shared) TransferHelper.transferItem - dest is floor")
		if dropSquare then
			local addToWorld = LSUtil.removeItemOnChar(character, item)
			if addToWorld then
				if destContainer then destContainer:DoAddItemBlind(item); end
				local dropX,dropY,dropZ = getDropItemOffset(character, dropSquare, item)
				dropSquare:AddWorldInventoryItem(item, dropX, dropY, dropZ)
			end
		else
			LSUtil.debugPrint("(shared) TransferHelper.transferItem - error, not dropSquare")
		end
	elseif srcContType == "floor" and item:getWorldItem() ~= nil then
		LSUtil.debugPrint("(shared) TransferHelper.transferItem - source is floor")
		DesignationZoneAnimal.removeItemFromGround(item:getWorldItem())
		item:getWorldItem():getSquare():transmitRemoveItemFromSquare(item:getWorldItem())
		item:getWorldItem():getSquare():removeWorldObject(item:getWorldItem())
		--item:getWorldItem():getSquare():getObjects():remove(item:getWorldItem())
		item:setWorldItem(nil)
		addItemToContainer(destContainer, item)
	else
		LSUtil.debugPrint("(shared) TransferHelper.transferItem - source/dest ~= floor or not item:getWorldItem()")
		addItemToContainer(destContainer, item)
		if fromPlayer then LSUtil.removeItemOnChar(character, item); end
	end

	if destContainer and destContainer:getParent() and instanceof(destContainer:getParent(), "BaseVehicle") and destContainer:getParent():getPartById(destContType) then
		local part = destContainer:getParent():getPartById(destContType)
		part:setContainerContentAmount(part:getItemContainer():getCapacityWeight())
	end

	if srcContainer and srcContainer:getParent() and instanceof(srcContainer:getParent(), "BaseVehicle") and srcContainer:getParent():getPartById(srcContType) then
		local part = srcContainer:getParent():getPartById(srcContType)
		part:setContainerContentAmount(part:getItemContainer():getCapacityWeight())
	end

	if autoWear then
		local canEquip = item.canBeEquipped and item:canBeEquipped()
		if canEquip and canEquip ~= "" then
			character:setWornItem(item:getBodyLocation(), item)
			if instanceof(item, "InventoryContainer") then getPlayerInventory(character:getPlayerNum()):refreshBackpacks(); end
			triggerEvent("OnClothingUpdated", character)
		end
	end
	return item
end
