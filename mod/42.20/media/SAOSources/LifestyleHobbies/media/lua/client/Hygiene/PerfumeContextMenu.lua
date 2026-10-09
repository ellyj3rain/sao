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

require "ISUI/ISInventoryPane"

PerfumeContextMenu = {};
PerfumeContextMenu.UseDelta = 0.005

local function StringStartWith(String,Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

local function ItemHasPerfume(item)
	if not item then return false; end
	if item:getFluidContainer() and item:getFluidContainer():getPrimaryFluid() and
	(StringStartWith(item:getFluidContainer():getPrimaryFluid():getFluidTypeString(), "Perfume") or StringStartWith(item:getFluidContainer():getPrimaryFluid():getFluidTypeString(), "Cologne"))
	and item:getFluidContainer():getAmount() >= PerfumeContextMenu.UseDelta then return true; end
	return false
end

PerfumeContextMenu.doInventoryMenu = function(player, context, items, perfumeOrCologne)
	--print("PerfumeContextMenu: GETTING PLAYER")
    local thisPlayer = getSpecificPlayer(player)
	if not thisPlayer then return; end
	
	local playerData
	--print("PerfumeContextMenu: GETTING PLAYER MODDATA")
	if thisPlayer:hasModData() then
		playerData = thisPlayer:getModData()
	else
	return; end
	if (not playerData.LSMoodles) or (not playerData.LSMoodles["SmellGood"]) then return; end

	if not ItemHasPerfume(perfumeOrCologne) then
		--print("PERFUME NOT FOUND")
		return
	end

	----ApplyPerfume

	local doApplyOption = context:addOptionOnTop(getText("ContextMenu_H_PerfumeUse"),
	false,
	PerfumeContextMenu.onAction,
	thisPlayer,
	perfumeOrCologne);

	local tooltipUse = ISToolTip:new();
	tooltipUse:initialise();
	tooltipUse:setVisible(false);

	description = getText("Tooltip_H_PerfumeUse");
	tooltipUse.description = description
	doApplyOption.toolTip = tooltipUse
	doApplyOption.iconTexture = getTexture('media/ui/perfume_icon.png')
	if playerData.LSMoodles["SmellGood"] and (playerData.LSMoodles["SmellGood"].Value >= 0.8) then
		doApplyOption.notAvailable = true;
		description = " <RED>" .. getText("Tooltip_H_PerfumeMax");
		tooltipUse.description = description
		doApplyOption.toolTip = tooltipUse
		doApplyOption.iconTexture = getTexture('media/ui/perfumeNo_icon.png')
	end
------
end

local function doPerfumeItemTransfer(player, PerfumeItem)

	if instanceof(PerfumeItem, "InventoryItem") then
		if luautils.haveToBeTransfered(player, PerfumeItem) then
			ISTimedActionQueue.add(ISInventoryTransferAction:new(player, PerfumeItem, PerfumeItem:getContainer(), player:getInventory()))
		end
		return true
	elseif instanceof(PerfumeItem, "ArrayList") then
		local items = PerfumeItem
		for i=1,items:size() do
			local item = items:get(i-1)
			if luautils.haveToBeTransfered(player, item) then
				ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), player:getInventory()))
			end
		end
		return true
	end

	return false

end

PerfumeContextMenu.onAction = function(worldobjects, player, Item)
	local LSApplyPerfumeAction = require "TimedActions/LSApplyPerfumeAction"
	if Item and doPerfumeItemTransfer(player, Item) then
		ISTimedActionQueue.add(LSApplyPerfumeAction:new(player, Item, PerfumeContextMenu.UseDelta));
	end
end

--Events.OnFillInventoryObjectContextMenu.Add(PerfumeContextMenu.doInventoryMenu);