Events.OnGameBoot.Add(function() 
	if not TetrisItemData then return end

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
