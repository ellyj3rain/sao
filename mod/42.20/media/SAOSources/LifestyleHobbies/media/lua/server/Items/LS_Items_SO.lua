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

require "Items/ProceduralDistributions"

LSItemsDistribution = LSItemsDistribution or {}

function LSItemsDistribution.onInitGlobalModData(isNewGame)
	local books = {}
	local magazines = {}
	if SandboxVars.Text.DividerMusicNew then table.insert(books, "Music"); table.insert(magazines, "SheetMusicBook"); end
	if SandboxVars.Text.DividerDancingNew then table.insert(books, "Dancing"); table.insert(magazines, "LSMagazineEdition1"); end
	if SandboxVars.Text.DividerHygiene then table.insert(books, "Cleaning"); end
	if SandboxVars.Text.DividerArt then table.insert(books, "Art"); table.insert(magazines, "LSMagazineEdition2"); end

	if #books > 0 or #magazines > 0 then LSItemsDistribution.Books(books, magazines); end
	if SandboxVars.Text.DividerMusicNew then LSItemsDistribution.Instruments(); end
	if SandboxVars.Text.DividerHygiene then LSItemsDistribution.Cleaning(); end
	if SandboxVars.Text.DividerArt then LSItemsDistribution.Art(); end
end

Events.OnInitGlobalModData.Add(LSItemsDistribution.onInitGlobalModData)