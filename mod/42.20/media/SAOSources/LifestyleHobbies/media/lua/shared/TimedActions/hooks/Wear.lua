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
require "TimedActions/ISWearClothing"

local function hasNeuralHat(character)
	local hatSlot = character:getWornItems():getItem(ItemBodyLocation.HAT)
	return hatSlot and hatSlot:getType() == "NeuralHat" and hatSlot:getVisual():getTextureChoice() ~= 0
end

local function isValidToWear(character, item)
	local bL
	if item:IsClothing() then
		bL = item:getBodyLocation()
	elseif item:IsInventoryContainer() then
		bL = item:canBeEquipped()
	end
	if bL and bL ~= "" then
		if bL ~= ItemBodyLocation.HAT and bL ~= ItemBodyLocation.FULL_HAT and bL ~= ItemBodyLocation.MASK_FULL then return true; end
		return false
	end
	return true
end

local og_start = ISWearClothing.start;
function ISWearClothing:start()
	local actualItem = (isClient() and self.item and self.character:getInventory():getItemById(self.item:getID())) or self.item
	if not actualItem or not hasNeuralHat(self.character) then
		og_start(self)
	else
		if isValidToWear(self.character, self.item) then
			og_start(self)
		else
			self.character:Say("I cannot remove an active neural hat") -- remove this line for a note
			self:forceStop()
		end
	end
end