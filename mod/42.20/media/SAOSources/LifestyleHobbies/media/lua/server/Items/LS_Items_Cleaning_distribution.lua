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

local cleaningTable = {
	BarCounterMisc = {Mop=4,BucketEmpty=2,Broom=4,Bleach=0.5,Sponge=2,CleaningLiquid2=3,Plunger=2},
	BathroomCabinet = {Mop=3,BucketEmpty=1,Broom=3,Bleach=0.5,Sponge=4,CleaningLiquid2=4,Plunger=4},
	BathroomCounter = {Mop=0.6,BucketEmpty=0.8,Broom=0.6,Bleach=0.8,Sponge=0.6,CleaningLiquid2=1},
	BathroomCounterNoMeds = {Mop=4,BucketEmpty=2,Broom=4,Bleach=0.5,Sponge=10,CleaningLiquid2=10},
	BathroomShelf = {Mop=0.8,BucketEmpty=0.6,Broom=0.8,Bleach=0.6,Sponge=0.8,CleaningLiquid2=0.8,Plunger=0.6},
	BreakRoomCounter = {Mop=4,Broom=4,Sponge=8,CleaningLiquid2=8},
	ClosetShelfGeneric = {Mop=4,BucketEmpty=2,Broom=4,Bleach=0.2,Sponge=8,CleaningLiquid2=8,Plunger=4},
	CrateCarpentry = {Mop=0.8,Broom=0.8,Plunger=0.8},
	CrateRandomJunk = {Mop=0.8,Broom=0.8,Bleach=0.6,Sponge=0.8,CleaningLiquid2=0.8,Plunger=0.8},
	CrateTools = {Mop=3,BucketEmpty=2,Broom=4,Plunger=2},
	DaycareShelves = {Mop=2,BucketEmpty=1,Broom=2,Bleach=0.5,Sponge=2,CleaningLiquid2=2,Plunger=1},
	DinerBackRoomCounter = {Mop=3,BucketEmpty=4,Broom=3,Bleach=1,Sponge=4,CleaningLiquid2=4,Plunger=3},
	DishCabinetGeneric = {Mop=6,BucketEmpty=6,Broom=6,Sponge=10,Plunger=4},
	GarageCarpentry = {Mop=4,BucketEmpty=4,Broom=4,Bleach=1,Sponge=4,CleaningLiquid2=4,Plunger=3},
	GarageTools = {Mop=4,BucketEmpty=6,Broom=4,Plunger=6},
	GigamartHousewares = {Mop=6,BucketEmpty=6,Broom=6,Plunger=6},
	GigamartTools = {Mop=4,BucketEmpty=2,Broom=4,Plunger=4},
	GymLaundry = {Mop=1,BucketEmpty=1,Broom=1,Bleach=1,Sponge=2,CleaningLiquid2=2,Plunger=1},
	Homesteading = {Mop=1,BucketEmpty=2,Broom=1,Bleach=0.5,Sponge=2,CleaningLiquid2=3,Plunger=1},
	JanitorTools = {Mop=10,Broom=10},
	KitchenRandom = {BucketEmpty=4,Plunger=6},
	LaundryCleaning = {Plunger=10},
	LaundryHospital = {Mop=10,BucketEmpty=10,Broom=10,Bleach=10,Sponge=10,CleaningLiquid2=10,Plunger=10},
	OtherGeneric = {Mop=2,Broom=2,Plunger=2},
	RandomFiller = {Mop=2,Broom=2,Plunger=2},
	StoreCounterCleaning = {Mop=4,Broom=4,Plunger=4},
}

-- Cleaning items distribution
function LSItemsDistribution.Cleaning()
	local cleaningItems = {"Mop","BucketEmpty","Broom","Bleach","Sponge","CleaningLiquid2","Plunger"}

	for k, v in pairs(cleaningTable) do
		for i=1,#cleaningItems do
			if v[cleaningItems[i]] then
				table.insert(ProceduralDistributions.list[k].items, "Base."..cleaningItems[i]);
				table.insert(ProceduralDistributions.list[k].items, v[cleaningItems[i]]);
				if v.clone and v.clone[cleaningItems[i]] then
					table.insert(ProceduralDistributions.list[k].items, "Base."..cleaningItems[i]);
					table.insert(ProceduralDistributions.list[k].items, v.clone[cleaningItems[i]]);
				end
			end
		end
	end

	ItemPickerJava.Parse()
end
