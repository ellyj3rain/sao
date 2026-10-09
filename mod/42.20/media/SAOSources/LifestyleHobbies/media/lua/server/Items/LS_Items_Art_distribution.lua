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

local artTable = {
	ArtStoreOther = {paintTubs=10,oldPaintBrush=2,paintPaletteEmpty=2},
	ArtStorePen = {oldPaintBrush=20},
	ArtSupplies = {paintTubs=10,oldPaintBrush=4,paintPaletteEmpty=4},
	ClassroomDesk = {paintTubs=2,oldPaintBrush=1,paintPaletteEmpty=1},
	ClassroomMisc = {paintTubs=0.8,oldPaintBrush=0.6,paintPaletteEmpty=0.6},
	ClassroomShelves = {paintTubs=1,oldPaintBrush=0.8,paintPaletteEmpty=0.8},
	ClassroomSecondaryDesk = {paintTubs=20,oldPaintBrush=8,paintPaletteEmpty=8},
	ClassroomSecondaryMisc = {paintTubs=10,oldPaintBrush=4,paintPaletteEmpty=4},
	ClassroomSecondaryShelves = {paintTubs=10,oldPaintBrush=4,paintPaletteEmpty=4},
	CrateOfficeSupplies = {paintTubs=2},
	CratePaint = {paintTubs=10,clone={paintTubs=5}},
	CrateRandomJunk = {paintTubs=1,oldPaintBrush=0.8,paintPaletteEmpty=0.8},
	CrateToys = {paintTubs=20,oldPaintBrush=10,paintPaletteEmpty=10},
	CrateSalonSupplies = {paintTubs=2},
	DaycareCounter = {paintTubs=6},
	DaycareDesk = {paintTubs=6},
	DaycareShelves = {paintTubs=20,clone={paintTubs=10}},
	GiftStoreToys = {paintTubs=20,clone={paintTubs=10}},
	GigamartSchool = {paintTubs=8,oldPaintBrush=4,paintPaletteEmpty=4,clone={paintTubs=4}},
	GigamartToys = {paintTubs=20,clone={paintTubs=10}},
	Hobbies = {paintTubs=8,oldPaintBrush=4,paintPaletteEmpty=4},
	LivingRoomSideTable = {paintTubs=2},
	LivingRoomSideTableNoRemote = {paintTubs=2},
	OtherGeneric = {paintTubs=2},
	SchoolLockers = {paintTubs=4,oldPaintBrush=2,paintPaletteEmpty=2},
	ShelfGeneric = {paintTubs=2},
	UniversityDesk_Art = {paintTubs=20,oldPaintBrush=10,paintPaletteEmpty=10},
	UniversityFilingCabinet_Art = {paintTubs=20,oldPaintBrush=10,paintPaletteEmpty=10},
	WardrobeChild = {paintTubs=2,oldPaintBrush=0.5,paintPaletteEmpty=0.5},
}

local upgradeTable = {
	upgradeElectric = {
		"ConstructionWorkerTools",
		"CarSupplyTools",
		"CarSupplyBatteries",
		"CabinetFactoryTools",
		"WireFactoryElectric",
		"ToolStoreTools",
		"ToolStoreMisc",
		"StoreShelfElectronics",
		"RadioFactoryComponents",
		"PlankStashMisc",
		"PawnShopTools",
		"MechanicShelfTools",
		"MechanicShelfMisc",
		"MechanicShelfElectric",
		"JunkHoard",
		"JanitorMisc",
		"JanitorCleaning",
		"ImprovisedCrafts",
		"GolfFactoryTools",
		"GigamartTools",
		"GigamartHouseElectronics",
		"GeneratorRoom",
		"GasStorageMechanics",
		"GarageTools",
		"ElectricianTools",
		"FactoryLockers",
		"EngineerTools",
		"ElectronicStoreMisc",
		"CrateToolsOld",
		"CrateRandomJunk",
		"CrateMechanics",
		"CrateGenerator",
		"CrateElectronics",
		"ControlRoomCounter",
		"CarSupplyTools",
		"ArmyStorageElectronics",
		"ArmyHangarMechanics",
		"ArmyBunkerStorage",
	},
	upgradeMechanical = {
		"ConstructionWorkerTools",
		"CarSupplyTools",
		"CabinetFactoryTools",
		"WireFactoryTools",
		"WeldingWorkshopTools",
		"ToolStoreTools",
		"ToolStoreMisc",
		"ToolCabinetMechanics",
		"StoreShelfMechanics",
		"SewingStoreTools",
		"RailYardTools",
		"PoliceStorageMechanics",
		"PlankStashMisc",
		"PawnShopTools",
		"MorgueTools",
		"MetalWorkerTools",
		"MetalShopTools",
		"MechanicSpecial",
		"MechanicShelfWheels",
		"MechanicShelfTools",
		"MechanicTools",
		"KnifeFactoryTools",
		"JunkHoard",
		"GolfFactoryTools",
		"GasStorageMechanics",
		"GarageMetalwork",
		"GarageMechanics",
		"FireStorageMechanics",
		"FactoryLockers",
		"EngineerTools",
		"CrateTools",
		"CrateRandomJunk",
		"CrateMechanics",
		"ConstructionWorkerTools",
		"CarSupplyTools",
		"ArmySurplusMisc",
		"ArmyHangarTools",
		"ArmyHangarMechanics",
		"ArmyBunkerStorage",
	},
	upgradePlumbing = {
		"ConstructionWorkerTools",
		"CabinetFactoryTools",
		"WireFactoryTools",
		"WeldingWorkshopMetal",
		"ToolStoreTools",
		"ToolStoreMisc",
		"ToolStoreMetalwork",
		"StoreShelfMechanics",
		"PoliceStorageMechanics",
		"PlumbingSupplies",
		"PlankStashMisc",
		"PawnShopTools",
		"MetalWorkerTools",
		"MetalShopTools",
		"MechanicSpecial",
		"MechanicShelfTools",
		"MechanicTools",
		"LaundryCleaning",
		"KnifeFactoryTools",
		"JunkHoard",
		"JanitorTools",
		"JanitorMisc",
		"JanitorCleaning",
		"GasStorageMechanics",
		"GarageMetalwork",
		"FireStorageMechanics",
		"DrugShackTools",
		"CrateTools",
		"CrateRandomJunk",
		"CrateMetalwork",
		"CrateMetalPipes",
		"CrateBlacksmithing",
		"BlacksmithTools",
		"BathroomCounter",
		"ArmyBunkerStorage",
	},
	upgradeWood = {
		"CarvingWorkshopMaterials",
		"CarvingWorkshopTools",
		"CarpenterTools",
		"CabinetFactoryTools",
		"WoodcraftDudeCounter",
		"ToolStoreTools",
		"ToolStoreMisc",
		"ToolStoreCarpentry",
		"RailYardTools",
		"PlankStashMisc",
		"PawnShopTools",
		"MechanicShelfMisc",
		"MechanicTools",
		"MannequinFactoryTools",
		"LoggingFactoryTools",
		"KnifeFactoryTools",
		"KitchenRandom",
		"JunkHoard",
		"JanitorTools",
		"JanitorMisc",
		"JanitorCleaning",
		"ImprovisedCrafts",
		"GigamartTools",
		"GardenStoreMisc",
		"GardenerTools",
		"GarageCarpentry",
		"FurnitureFactoryTools",
		"FarmerTools",
		"DrugShackTools",
		"CrateToolsOld",
		"CrateTools",
		"CrateRandomJunk",
		"CrateLumber",
		"CrateLongStick",
		"CrateGardening",
		"CrateFarming",
		"CrateCarpentry",
		"CrateBlacksmithing",
		"ConstructionWorkerTools",
		"CarvingWorkshopMaterials",
		"CarvingWorkshopTools",
		"CarpenterTools",
		"BarnTools",
		"ArmyBunkerStorage",
		"Antiques",
	},
}

-- Item distribution
function LSItemsDistribution.Art()
	local artItems = {"paintTubs","oldPaintBrush","paintPaletteEmpty"}

	for k, v in pairs(artTable) do
		for i=1,#artItems do
			if v[artItems[i]] then
				table.insert(ProceduralDistributions.list[k].items, "Lifestyle."..artItems[i]);
				table.insert(ProceduralDistributions.list[k].items, v[artItems[i]]);
				if v.clone and v.clone[artItems[i]] then
					table.insert(ProceduralDistributions.list[k].items, "Lifestyle."..artItems[i]);
					table.insert(ProceduralDistributions.list[k].items, v.clone[artItems[i]]);
				end
			end
		end
	end

	for k, v in pairs(upgradeTable) do
		local itemName = "Lifestyle."..tostring(k)
		for i=1,#v do
			local item = v[i]
			table.insert(ProceduralDistributions.list[item].items, itemName)
			table.insert(ProceduralDistributions.list[item].items, 0.01)
			-- rare variant
			table.insert(ProceduralDistributions.list[item].items, itemName.."Rare")
			table.insert(ProceduralDistributions.list[item].items, 0.001)
		end
	end

	ItemPickerJava.Parse()
end