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
require"Properties/Player/LSSOModulesLoad"

local function LSgetSandboxDividerOptions()
	return {
		{svar=SandboxVars.Text.DividerHygiene, traits={"Sloppy","Tidy","CleanFreak"}},
		{svar=SandboxVars.Text.DividerMeditationNew, traits={"Disciplined","CouchPotato"}},
		{svar=SandboxVars.Text.DividerMusicNew, traits={"Virtuoso","ToneDeaf"}},
		{svar=SandboxVars.Text.DividerDancingNew, traits={"PartyAnimal","Killjoy"}},
		{svar=SandboxVars.Text.DividerArt, traits={"Artistic"}},
	}
end

local function LSgetTraitsToRemove()
	local TraitsToRemove = {}
	local SandboxOptions = LSgetSandboxDividerOptions()
	for k, v in ipairs(SandboxOptions) do
		if not v.svar then
			for n=1, #v.traits do
				table.insert(TraitsToRemove, v.traits[n])
			end
		end
	end
	return TraitsToRemove
end

function LSSOModules.Traits.updateTraitSandbox()
	if not SandboxVars then return; end
    local CharCreation = MainScreen.instance.charCreationProfession
	if not CharCreation then return; end
	local TraitsToRemove = LSgetTraitsToRemove()
	if #TraitsToRemove > 0 then
		for n=1, #TraitsToRemove do
			--local traitRemove = CharacterTrait[string.upper(TraitsToRemove[i])]
			local traitList = CharacterTraitDefinition.getTraits();
			for i = 0, traitList:size() - 1 do
				local trait = traitList:get(i);
				local label = trait:getLabel()
				if label == TraitsToRemove[n] or label == getText("UI_trait_"..string.lower(TraitsToRemove[n])) then
					local label = trait:getLabel()
					CharCreation.listboxTrait:removeItem(label)
					CharCreation.listboxBadTrait:removeItem(label)
					CharCreation.listboxTraitSelected:removeItem(label)
				end
			end
		end
	end
end

function LSSOModules.Traits.removeTraitsFromCharacter(playerIndex, player)
	local TraitsToRemove = LSgetTraitsToRemove()
	if #TraitsToRemove > 0 then
		for i=1, #TraitsToRemove do
			--print("LSSOModules.Traits.removeTraitsFromCharacter look for trait and remove it: "..TraitsToRemove[i])
			local traitName = string.upper(TraitsToRemove[i])
			if CharacterTrait[traitName] and player:hasTrait(CharacterTrait[traitName]) then
				player:getCharacterTraits():remove(CharacterTrait[traitName]);
				player:modifyTraitXPBoost(CharacterTrait[traitName], true);
				SyncXp(player)
			end
		end
	end
end

local OGsetSandboxVars = SandboxOptionsScreen.setSandboxVars

SandboxOptionsScreen.setSandboxVars = function(self)
    OGsetSandboxVars(self)
    LSSOModules.Traits.updateTraitSandbox()
end

return LSSOModules.Traits