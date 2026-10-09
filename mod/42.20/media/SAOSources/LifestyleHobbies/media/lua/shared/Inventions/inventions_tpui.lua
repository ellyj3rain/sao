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

LSInv = LSInv or {}

------------ 

local icons = {}
icons.error = "gears_icon"
icons.efficiency = "fire_icon"
icons.costPenalty = "gearsBAD_icon"
icons.woodwork = "woodwork_icon"
icons.woodworkHard = icons.woodwork
icons.plumbing = "maintenance_icon"
icons.plumbingHard = icons.plumbing
icons.machinery = "mechanics_icon"
icons.machineryHard = icons.machinery
icons.metalwork = "metalwork_icon"
icons.metalworkHard = icons.metalwork 
icons.electrical = "electrical_icon"
icons.electricalHard = icons.electrical

LSInv.getInvStatIcon = function(stat, cN, isImprov)
	local icon = icons[stat]
	if isImprov and not icon then icon = icons[LSInventionDefs.Improvements[cN][stat].defs]; end
	icon = icon or icons.error
	return "media/ui/"..icon..".png"
end
