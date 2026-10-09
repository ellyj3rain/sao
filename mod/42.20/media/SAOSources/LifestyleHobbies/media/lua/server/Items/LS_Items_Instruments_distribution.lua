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

local instruments = {}
instruments.All = {"Base.Banjo","Base.Flute","Base.GuitarAcoustic","Base.GuitarElectric","Base.GuitarElectricBass","Base.Harmonica","Lifestyle.Harmonica","Base.Keytar","Base.Saxophone","Base.Trumpet","Base.Violin"}
instruments.Classy = {"Base.Flute","Base.Saxophone","Base.Trumpet","Base.Violin"}
instruments.Guitars = {"Base.GuitarAcoustic","Base.GuitarElectric","Base.GuitarElectricBass"}
instruments.Redneck = {"Base.GuitarAcoustic","Base.Banjo","Base.Harmonica","Lifestyle.Harmonica"}
instruments.Electronic = {"Base.GuitarElectric","Base.GuitarElectricBass","Base.Keytar"}
instruments.Brass = {"Base.Saxophone","Base.Trumpet"}
instruments.Small = {"Base.Flute","Base.Harmonica","Lifestyle.Harmonica","Base.Trumpet","Base.Violin"}

local containerTable = {
	BedroomDresserChild = {"Small",2},
	BedroomSidetableChild = {"Small",4},
	ClosetInstruments = {"Lifestyle.Harmonica",4},
	CrateInstruments = {"Lifestyle.Harmonica",4},
	CrateToys = {"Small",5},
	DaycareCounter = {"Base.Flute",2,"Lifestyle.Harmonica",2},
	DaycareShelves = {"Base.Flute",1,"Lifestyle.Harmonica",1},
	DresserGeneric = {"Small",0.1},
	ElectronicStoreMusic = {"Electronic",10},
	Gifts = {"All",1},
	GiftStoreFancy = {"Brass",4},
	GiftStoreToys = {"Small",5},
	GigamartToys = {"Small",5},
	Hobbies = {"All",4},
	LivingRoomShelf = {"Small",1},
	LivingRoomShelfRedneck = {"Lifestyle.Harmonica",1},
	LivingRoomWardrobe = {"All",0.1},
	Locker = {"Small",1},
	LockerArmyBedroom = {"Redneck",1},
	LockerArmyBedroomHome = {"Redneck",1},
	LockerClassy = {"Brass",1},
	MusicSchoolLocker = {"All",1},
	MusicStoreOthers = {"Lifestyle.Harmonica",50},
	PawnShopTools = {"All",1},
	PoliceEvidence = {"Brass",4},
	PrisonCellRandom = {"Lifestyle.Harmonica",1},
	PrisonCellRandomClassy = {"Lifestyle.Harmonica",1},
	RangerLockers = {"Redneck",1},
	RecRoomShelf = {"Small",1},
	SchoolLockersBad = {"Base.GuitarAcoustic",1},
	WardrobeChild = {"All",2},
	WardrobeGeneric = {"All",1},
	WardrobeClassy = {"Classy",1},
	WardrobeRedneck = {"Redneck",1},
	WildWestSouveniers = {"Redneck",10},
	WildWestLivingRoom = {"Redneck",1},
	WildWestGeneralStore = {"Redneck",4},
	UniversityWardrobe = {"Guitars",0.5},
}


-- Item distribution
function LSItemsDistribution.Instruments()

	for k, v in pairs(containerTable) do
		if ProceduralDistributions.list[k] then
			for i=1,#v do
				local group = v[i]
				if type(group) ~= "number" then
					if instruments[group] then
						for n=1,#instruments[group] do
							local itemName = instruments[group][n]
							table.insert(ProceduralDistributions.list[k].items, itemName)
							table.insert(ProceduralDistributions.list[k].items, v[i+1])
						end
					else
						table.insert(ProceduralDistributions.list[k].items, group)
						table.insert(ProceduralDistributions.list[k].items, v[i+1])
					end
				end
			end
		end
	end

	ItemPickerJava.Parse()
end