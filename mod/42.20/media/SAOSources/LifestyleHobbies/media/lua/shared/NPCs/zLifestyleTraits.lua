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

require "NPCs/MainCreationMethods"

local function doLSTraits()
	if not CharacterTrait then return; end
	local deaf = CharacterTrait.DEAF and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.DEAF)
	local hardofhearing = CharacterTrait.HARD_OF_HEARING and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.HARD_OF_HEARING)
	
	local athletic = CharacterTrait.ATHLETIC and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.ATHLETIC)
	local fit = CharacterTrait.FIT and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.FIT)
	local gymnast = CharacterTrait.GYMNAST and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.GYMNAST)
	local jogger = CharacterTrait.JOGGER and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.JOGGER)
	
	local outofshape = CharacterTrait.OUT_OF_SHAPE and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.OUT_OF_SHAPE)
	local overweight = CharacterTrait.OVERWEIGHT and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.OVERWEIGHT)
	local obese = CharacterTrait.OBESE and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.OBESE)
	local unfit = CharacterTrait.UNFIT and CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.UNFIT)
	
	if CharacterTrait.VIRTUOSO then
		if deaf then deaf:getMutuallyExclusiveTraits():add(CharacterTrait.VIRTUOSO); end
		if hardofhearing then hardofhearing:getMutuallyExclusiveTraits():add(CharacterTrait.VIRTUOSO); end
	end

	if CharacterTrait.TONEDEAF then
		if deaf then deaf:getMutuallyExclusiveTraits():add(CharacterTrait.TONEDEAF); end
	end

	if CharacterTrait.PARTYANIMAL then
		if deaf then deaf:getMutuallyExclusiveTraits():add(CharacterTrait.PARTYANIMAL); end
	end

	if CharacterTrait.KILLJOY then
		if deaf then deaf:getMutuallyExclusiveTraits():add(CharacterTrait.KILLJOY); end
	end

	if CharacterTrait.DISCIPLINED then
		if overweight then overweight:getMutuallyExclusiveTraits():add(CharacterTrait.DISCIPLINED); end
		if outofshape then outofshape:getMutuallyExclusiveTraits():add(CharacterTrait.DISCIPLINED); end
		if obese then obese:getMutuallyExclusiveTraits():add(CharacterTrait.DISCIPLINED); end
		if unfit then unfit:getMutuallyExclusiveTraits():add(CharacterTrait.DISCIPLINED); end
	end

	if CharacterTrait.COUCHPOTATO then
		if athletic then athletic:getMutuallyExclusiveTraits():add(CharacterTrait.COUCHPOTATO); end
		if fit then fit:getMutuallyExclusiveTraits():add(CharacterTrait.COUCHPOTATO); end
		if gymnast then gymnast:getMutuallyExclusiveTraits():add(CharacterTrait.COUCHPOTATO); end
		if jogger then jogger:getMutuallyExclusiveTraits():add(CharacterTrait.COUCHPOTATO); end
	end

end

doLSTraits()