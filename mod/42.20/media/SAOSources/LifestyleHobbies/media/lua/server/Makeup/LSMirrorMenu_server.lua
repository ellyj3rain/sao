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

LSMirrorMenu_server = {}

local function MirrorItemContainer(player, itemA)

	local Cont = false

	if instanceof(itemA, "InventoryItem") then
		if luautils.haveToBeTransfered(player, itemA) then
			Cont = itemA:getContainer()
		end
	elseif instanceof(itemA, "ArrayList") then
		local items = itemA
		for i=1,items:size() do
			local item = items:get(i-1)
			if luautils.haveToBeTransfered(player, item) then
				Cont = item:getContainer()
				break
			end
		end
	end

	return Cont
end

local function MMgetMakeupBodyLocationItem(character, makeupCat)
	local bodyLocationItem
	for i,v in ipairs(MakeUpDefinitions.makeup) do
		if v.category == makeupCat then
			local makeup = instanceItem(v.item)
			if makeup then bodyLocationItem = character:getWornItem(makeup:getBodyLocation()); end
			--if bodyLocationItem then print("MMgetMakeupBottomOptions: found an item for bodyLocationItem, name is: " .. bodyLocationItem:getName()); break; end
			if bodyLocationItem then break; end
		end
	end
	return bodyLocationItem
end

local function MMdoContainerTransfer(playerInv, Itemcontainer, item)

	Itemcontainer:setDrawDirty(true);
	Itemcontainer:Remove(item)
	sendRemoveItemFromContainer(Itemcontainer, item)

	playerInv:setDrawDirty(true)
	playerInv:AddItem(item)
	sendAddItemToContainer(playerInv, item)

end


LSMirrorMenu_server.setMirrorChanges = function(character, args)
	--print("LSMirrorMenu_server.setMirrorChanges - start")
	local items, makeupData, playerInv = args[1], args[2], character:getInventory()

	for n=1, #items do --hairDyeItem, beardDyeItem, tattooNeedleItem, tattooBrushItem
		local item = items[n]
		if item then
			local hair
			if n == 1 then hair = "Hair"; elseif n == 2 then hair = "Beard"; end
			if hair and item.getFluidContainer then
				local colors = item:getFluidContainer():getColor()
				local self = character:getHumanVisual()
				self['set'..hair..'Color'](self, ImmutableColor.new(colors:getR(), colors:getG(), colors:getB(), 1))
				--print("LSMirrorMenu_server.setMirrorChanges - color set")
			end
			local Itemcontainer = MirrorItemContainer(character, item)
			if Itemcontainer then
				MMdoContainerTransfer(playerInv, Itemcontainer , item)
			end
			item:UseAndSync()
		end
	end

	local bodyLocationItem
	for n=1,#makeupData do
		local data = makeupData[n]
		if data and type(data) == "string" then
			bodyLocationItem = MMgetMakeupBodyLocationItem(character, data)
			--print("LSMirrorMenu_server.setMirrorChanges - bodyLocationItem set")
		elseif bodyLocationItem then
			if data ~= 0 then
				playerInv:setDrawDirty(true)
				playerInv:AddItem(bodyLocationItem)
				sendAddItemToContainer(playerInv, bodyLocationItem)
				--print("LSMirrorMenu_server.setMirrorChanges - makeup set")
				if data and playerInv:contains(data) then 
					playerInv:Remove(data)
					sendRemoveItemFromContainer(playerInv, data)
					--print("LSMirrorMenu_server.setMirrorChanges - old makeup removed set")
				end
				local bodyL = bodyLocationItem:getBodyLocation()
				character:setWornItem(bodyL, bodyLocationItem)
				sendClothing(character,bodyL, bodyLocationItem)
				--print("LSMirrorMenu_server.setMirrorChanges - sending clothing data")
				--if bodyLocationItem.UseAndSync then
				--	bodyLocationItem:UseAndSync()
				--	sendItemStats(bodyLocationItem)
				--end
			end
			bodyLocationItem = false
		end
	end

end
