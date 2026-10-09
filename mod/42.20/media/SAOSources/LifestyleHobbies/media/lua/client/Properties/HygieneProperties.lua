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
--[[
LSHygienePPT = {};

local function findItemsDyeLoot(thisPlayer, DyeItemList)

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
			if v:isHairDye() then
				if #DyeItemList == 0 then
					table.insert(DyeItemList, v)
				elseif #DyeItemList == 1 then
					if DyeItemList[1]:getType() ~= v:getType() then table.insert(DyeItemList, v); end
				else
					local notIncluded = true
					for _, dyeItem in pairs(DyeItemList) do
						if dyeItem:getType() == v:getType() then
							notIncluded = false
							break
						end
					end
					if notIncluded then table.insert(DyeItemList, v); end
				end
			end
		end
	end

	return DyeItemList

end

function LSHygienePPT.findItemsDye(thisPlayer)

    local inventory = thisPlayer:getInventory();
	local it = inventory:getItems();
	local DyeItemList = {}

	for j = 0, it:size()-1 do
		local item = it:get(j);
		if item:isHairDye() then
			if #DyeItemList == 0 then
				table.insert(DyeItemList, item)
			elseif #DyeItemList == 1 then
				if DyeItemList[1]:getType() ~= item:getType() then table.insert(DyeItemList, item); end
			else
				local notIncluded = true
				for _, dyeItem in pairs(DyeItemList) do
					if dyeItem:getType() == item:getType() then
						notIncluded = false
						break
					end
				end
				if notIncluded then table.insert(DyeItemList, item); end
			end
		end
	end

	DyeItemList = findItemsDyeLoot(thisPlayer, DyeItemList)
	if #DyeItemList == 0 then DyeItemList = false; end
	return DyeItemList

end
]]--