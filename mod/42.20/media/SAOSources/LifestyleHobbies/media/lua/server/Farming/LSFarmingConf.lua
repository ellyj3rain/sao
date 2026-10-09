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

require "Farming/farming_vegetableconf"
if not farming_vegetableconf then return; end

local ogGrow_func = farming_vegetableconf.grow
farming_vegetableconf.grow = function(planting, nextGrowing, updateNbOfGrow)
	-- we let the func run normally (makes it more compatible with other mods and less likely to break between patches)
	local luaObject = ogGrow_func(planting, nextGrowing, updateNbOfGrow)
	if luaObject and luaObject.typeOfSeed and luaObject.typeOfSeed == "LSScrapBush" then -- scrap bushes should never give seeds
		if luaObject.hasSeed then luaObject.hasSeed = false; end
	end
	return luaObject
end

local params = {'sprite','unhealthySprite','dyingSprite','deadSprite','trampledSprite','props'}
for n=1,#params do
	local key = params[n]
	farming_vegetableconf[key] = farming_vegetableconf[key] or {}
end

farming_vegetableconf.sprite["LSScrapBush"] = {
"LS_Farming_01_0",
"LS_Farming_01_1",
"LS_Farming_01_2",
"LS_Farming_01_3",
"LS_Farming_01_4",
"LS_Farming_01_5",
"LS_Farming_01_6",
"LS_Farming_01_7"
}

farming_vegetableconf.unhealthySprite["LSScrapBush"] = {
"LS_Farming_01_8",
"LS_Farming_01_9",
"LS_Farming_01_10",
"LS_Farming_01_11",
"LS_Farming_01_12",
"LS_Farming_01_13",
"LS_Farming_01_14",
"LS_Farming_01_15"
}

farming_vegetableconf.dyingSprite["LSScrapBush"] = {
"LS_Farming_01_16",
"LS_Farming_01_17",
"LS_Farming_01_18",
"LS_Farming_01_19",
"LS_Farming_01_20",
"LS_Farming_01_21",
"LS_Farming_01_22",
"LS_Farming_01_23"
}

farming_vegetableconf.deadSprite["LSScrapBush"] = {
"LS_Farming_01_24",
"LS_Farming_01_25",
"LS_Farming_01_26",
"LS_Farming_01_27",
"LS_Farming_01_28",
"LS_Farming_01_29",
"LS_Farming_01_30",
"LS_Farming_01_31"
}

farming_vegetableconf.trampledSprite["LSScrapBush"] = {
"LS_Farming_01_32",
"LS_Farming_01_33",
"LS_Farming_01_34",
"LS_Farming_01_35",
"LS_Farming_01_36",
"LS_Farming_01_37",
"LS_Farming_01_38",
"LS_Farming_01_39"
}

farming_vegetableconf.props["LSScrapBush"] = {
    icon = "Item_ScrapMetal",
    texture = "LS_Farming_01_6",
--     waterLvl = 85,
    waterLvl = 80,
--     timeToGrow = 432,
    timeToGrow = 360,
    minVeg = 4,
    maxVeg = 6,
    minVegAutorized = 6,
    maxVegAutorized = 8,
    vegetableName = "Base.ScrapMetal",
    seedName = "Lifestyle.ScrapBushSeed",
	extraRandom = {"Base.IronScrap","Base.TirePiece","Base.ElectricWire"},
    harvestLevel = 6,
--     waterNeeded = 85,
    waterNeeded = 80,
    mature = 5,
    fullGrown = 6,
    badMonth = { 10, 11, 12, 1 },
    sowMonth = { 2, 3, 4, 5, 6, 7 },
    bestMonth = { 3, 5 },
	riskMonth = { 7 },
    seasonRecipe = "lifestyle:scrap bush growing season",
    growBack = 4,
    aphidsBane = true,
    slugsProof = true,
    coldHardy = true,
    mothBane = true,
    rabbitBane = true,
	harvestPosition = "High",
}