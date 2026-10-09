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
require "TimedActions/ISUnequipAction"

local og_start = ISUnequipAction.start;
function ISUnequipAction:start()
	if self.item:IsClothing() and not self.character:isHandItem(self.item) and self.item:getType() == "NeuralHat" and self.item:getVisual():getTextureChoice() ~= 0 then
		self.character:Say("I cannot remove an active neural hat") -- remove this line for a note
		self:forceStop()
	else
		og_start(self)
	end
end