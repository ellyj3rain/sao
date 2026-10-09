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

PlushiesContextMenu = {};

local function characterIsValid(character)
	if not character then return false; end
	if character:isDead() or character:getVehicle() or character:isSitOnGround() or character:hasTimedActions() then return false; end
	return true
end

local function getTooltip(text)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = text
	return tooltip
end

local function doTalkOption(subMenu, character, plushy, playerSex, cooldownsData, plushyGroup)
	local option, text, texture = subMenu:addOptionOnTop(getText("ContextMenu_Toy_Interact"), false, PlushiesContextMenu.onAction, character, plushy, cooldownsData, playerSex, plushyGroup), getText("Tooltip_Toy_Talk"), 'media/ui/talkto_icon.png'
		
	local itemTooltip = getTooltip(text)
	option.toolTip = itemTooltip
	option.iconTexture = getTexture(texture)

end

local function getPlushyGroup(item)
	if not item or item:IsClothing() then return false; end
	local itemName = item:getFullType()
	if (string.find(itemName, "Spiffo")) or (string.find(itemName, "spiffo")) then
		if item:getDisplayCategory() ~= "Raccoon" then return false; end
		if (string.find(itemName, "Big")) then return "SpiffoBig"; end
		return "Spiffo"
	end
	return "Plushies"
end

PlushiesContextMenu.doInventoryMenu = function(player, context, items, plushy)
	local plushyGroup = getPlushyGroup(plushy)
	if not plushyGroup then return; end
    local character = getSpecificPlayer(player)
	if not characterIsValid(character) then return; end
	local cooldownsData = character:getModData().LSCooldowns
	local playerSex = "Man"
	if character:isFemale() then playerSex = "Woman"; end
	
	local buildOption = context:addOptionOnTop(plushy:getDisplayName())
	buildOption.iconTexture = getTexture('media/ui/Ambitions/LSPlushies.png')
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)

	doTalkOption(subMenu, character, plushy, playerSex, cooldownsData, plushyGroup)
end

local function doItemTransfer(player, targetItem)

	if instanceof(targetItem, "InventoryItem") then
		if luautils.haveToBeTransfered(player, targetItem) then
			ISTimedActionQueue.add(ISInventoryTransferAction:new(player, targetItem, targetItem:getContainer(), player:getInventory()))
		end
		return true
	elseif instanceof(targetItem, "ArrayList") then
		local items = targetItem
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

PlushiesContextMenu.onAction = function(worldobjects, player, item, data, playerSex, plushyGroup)
	if not characterIsValid(player) then return; end
	local startString, endString, ogContainer = "_Hold", "_Hold", item:getContainer()
	if plushyGroup == "SpiffoBig" then startString, endString = "_Hold", "_HoldEnd"; end

	local timedAction = require "TimedActions/LSPlushiesTalk"
	if item and doItemTransfer(player, item) then
		ISTimedActionQueue.add(timedAction:new(player, item, data, playerSex, plushyGroup, startString, endString, ogContainer));
	end
end
