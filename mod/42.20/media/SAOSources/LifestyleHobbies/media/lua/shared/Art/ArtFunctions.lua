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
LSArt = LSArt or {}

LSArt.getUseChance = function(character, base)
	if character:hasTrait(CharacterTrait.ARTISTIC) then base = math.ceil(base/1.5); end
	--local artSkill = math.max(1,character:getPerkLevel(Perks.Art))
	return math.max(0,math.floor(base-character:getPerkLevel(Perks.Art)))
end
