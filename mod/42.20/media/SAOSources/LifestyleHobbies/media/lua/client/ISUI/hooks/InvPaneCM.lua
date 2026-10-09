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
require "ISUI/ISInventoryPaneContextMenu"


local og_unequipItem = ISInventoryPaneContextMenu.unequipItem
ISInventoryPaneContextMenu.unequipItem = function(item, player)
	local character = getSpecificPlayer(player)
	if not character:isEquipped(item) then return end
	if item ~= nil and item:getType() == "NeuralHat" and item:getVisual():getTextureChoice() ~= 0 then
		character:Say("I cannot remove an active neural hat") -- remove this line for a note or animation
		-- add deactivation action to queue instead of returning if item:getVisual():getTextureChoice() ~= 2 (bad/failure state)
		return
	end
	
	--ISTimedActionQueue.add(ISUnequipAction:new(getSpecificPlayer(player), item, 50));
	og_unequipItem(item, player)
end