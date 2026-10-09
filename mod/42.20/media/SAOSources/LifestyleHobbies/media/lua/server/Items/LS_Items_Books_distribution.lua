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

local bookTable = {
	BookstoreBooks = {10, 8, 6, 4, 2},
	BookstoreHobbies = {10, 8, 6, 4, 2, {Art=true,Music=true,Dancing=true}},
	BookstoreMedical = {10, 8, 6, 4, 2, {Cleaning=true}},
	BookstorePersonal = {10, 8, 6, 4, 2},
	BookstoreMusic = {10, 8, 6, 4, 2},
	ClassroomMisc = {2, 1, 0.5, false, false},
	ClassroomShelves = {2, 1, 0.5, false, false},
	ClassroomSecondaryMisc = {2, 1, 0.5, false, false},
	ClassroomSecondaryShelves = {2, 1, 0.5, false, false},
	ClosetInstruments = {4, 2, 1, false, false, {Music=true}},
	CrateBooks = {6, 4, 2, 1, 0.5},
	CrateBooksSchool = {1, 0.5, 0.1, false, false},
	GigamartCleaning = {10, 8, 6, 4, 2, {Cleaning=true}},
	HospitalLockers = {2, 1, 0.5, 0.1, 0.05, {Cleaning=true}},
	HospitalRoomShelves = {2, 1, 0.5, 0.1, 0.05, {Cleaning=true}},
	JanitorCleaning = {2, false, false, false, false, {Cleaning=true}},
	JanitorMisc = {4, 2, 1, 0.5, 0.1, {Cleaning=true}},
	KitchenRandom = {2, 1, 0.5, false, false, {Cleaning=true}},
	LaboratoryBooks = {10, 8, 6, 4, 2, {Cleaning=true}},
	LibraryBooks = {8, 6, 4, 2, 1},
	LibraryMedical = {10, 8, 6, 4, 2, {Cleaning=true}},
	LibraryMusic = {10, 8, 6, 4, 2, {Music=true,Dancing=true}},
	LibraryPersonal = {10, 8, 6, 4, 2},
	LivingRoomShelf = {0.1, 0.05, 0.025, false, false},
	LivingRoomShelfClassy = {0.1, 0.05, 0.025, false, false},
	LivingRoomShelfRedneck = {0.1, 0.05, 0.025, false, false},
	LivingRoomWardrobe = {0.1, 0.05, 0.025, false, false},
	MusicSchoolLocker = {1, 1, 0.8, 0.6, 0.4, {Music=true}},
	MusicStoreLiterature = {10, 8, 6, 4, 2, {Music=true}},
	PostOfficeBooks = {6, 4, 2, 1, 0.5},
	RecRoomShelf = {0.005, 0.0025, 0.0001, false, false},
	SafehouseBookShelf = {1, 1, 1, 1, 0.5},
	SafehouseFireplace = {0.5, 0.1, false, false, false},
	ShelfGeneric = {0.1, 0.05, 0.025, false, false},
	UniversityLibraryBooks = {10, 8, 6, 4, 2},
	UniversityLibraryMusic = {50, 20, 20, 10, 10, {Music=true,Dancing=true}},
	StoreCounterCleaning = {4, 2, 1, 0.5, 0.2, {Cleaning=true}},
}

local magTable = {
	BookstoreArt = {LSMagazineEdition2=10},
	BookstoreBooks = {LSMagazineEdition1=0.4,LSMagazineEdition2=0.4},
	BookstoreHobbies = {SheetMusicBook=20,LSMagazineEdition1=10,LSMagazineEdition2=10},
	BookstoreMisc = {SheetMusicBook=2,LSMagazineEdition1=2,LSMagazineEdition2=2},
	BookstorePersonal = {LSMagazineEdition1=10,LSMagazineEdition2=10},
	BookstoreMusic = {LSMagazineEdition1=10,SheetMusicBook=20},
	ClassroomDesk = {SheetMusicBook=1,LSMagazineEdition1=1,LSMagazineEdition2=1},
	ClassroomMisc = {SheetMusicBook=4,LSMagazineEdition1=0.5,LSMagazineEdition2=0.5},
	ClassroomShelves = {SheetMusicBook=4,LSMagazineEdition1=0.5,LSMagazineEdition2=0.5},
	ClassroomSecondaryMisc = {SheetMusicBook=4},
	ClassroomSecondaryShelves = {SheetMusicBook=4},
	ClosetInstruments = {SheetMusicBook=10},
	CrateMagazines = {LSMagazineEdition1=1,LSMagazineEdition2=1},
	LibraryMagazines = {LSMagazineEdition1=1,LSMagazineEdition2=1},
	LivingRoomShelf = {SheetMusicBook=0.05,LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	LivingRoomShelfClassy = {SheetMusicBook=0.05,LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	LivingRoomShelfRedneck = {SheetMusicBook=0.05,LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	LivingRoomSideTable = {SheetMusicBook=0.05,LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	LivingRoomSideTableClassy = {SheetMusicBook=0.05,LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	LivingRoomSideTableRedneck = {SheetMusicBook=0.05,LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	LivingRoomWardrobe = {LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	MagazineRackMixed = {LSMagazineEdition1=1,LSMagazineEdition2=1},
	MusicSchoolSheets = {SheetMusicBook=100},
	MusicSchoolLocker = {SheetMusicBook=10},
	MusicStoreLiterature = {LSMagazineEdition1=10,SheetMusicBook=20},
	PostOfficeMagazines = {LSMagazineEdition1=1,LSMagazineEdition2=1},
	RecRoomShelf = {LSMagazineEdition1=0.1,LSMagazineEdition2=0.1},
	SafehouseBookShelf = {LSMagazineEdition1=1,LSMagazineEdition2=1},
	SchoolLockers = {SheetMusicBook=10},
	ShelfGeneric = {SheetMusicBook=0.05,LSMagazineEdition1=0.01,LSMagazineEdition2=0.01},
	UniversityDesk_Art = {LSMagazineEdition2=20},
	UniversityLibraryArt = {LSMagazineEdition2=10},
	UniversityLibraryMusic = {SheetMusicBook=50},
	UniversityLibraryMagazines = {LSMagazineEdition1=1,LSMagazineEdition2=1},
}

-- Item distribution
function LSItemsDistribution.Books(books, magazines)

	if #books > 0 then
		for k, v in pairs(bookTable) do
			for i=1,#books do
				local add = not v[6] or v[6][books[i]]
				if add then
					for n=1, 5 do
						if v[n] then
							table.insert(ProceduralDistributions.list[k].items, "Lifestyle.Book"..books[i]..tostring(n))
							table.insert(ProceduralDistributions.list[k].items, v[n])
						end
					end
				end
			end
		end
	end

	if #magazines > 0 then
		for k, v in pairs(magTable) do
			for i=1,#magazines do
				if v[magazines[i]] then
					table.insert(ProceduralDistributions.list[k].items, "Lifestyle."..magazines[i]);
					table.insert(ProceduralDistributions.list[k].items, v[magazines[i]]);
				end
			end
		end
	end

	ItemPickerJava.Parse()
end