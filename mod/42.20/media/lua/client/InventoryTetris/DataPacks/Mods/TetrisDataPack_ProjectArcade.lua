-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
Events.OnGameBoot.Add(function() 
	if not (type(TetrisItemData) == "table" and type(TetrisItemData.registerItemDefinitions) == "function"
        and type(TetrisContainerData) == "table" and type(TetrisContainerData.registerContainerDefinitions) == "function"
        and type(TetrisPocketData) == "table" and type(TetrisPocketData.registerPocketDefinitions) == "function") then return end

	local itemPack = {
		["ProjectArcade.WalletILovePixels__squished"] = {
			["width"] = 1,
			["height"] = 1,
			["maxStackSize"] = 1,
		},
		["ProjectArcade.WalletILovePixels"] = {
			["maxStackSize"] = 1,
			["height"] = 1,
			["width"] = 1,
		},
	}

	local containerPack = {
	}

	local pocketPack = {
	}

	TetrisItemData.registerItemDefinitions(itemPack)
	TetrisContainerData.registerContainerDefinitions(containerPack)
	TetrisPocketData.registerPocketDefinitions(pocketPack)
end)
