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

--Beauty Properties

local lsBData = {}

lsBData.wondrous = 30
lsBData.beautiful = 20
lsBData.pretty = 10
lsBData.nice = 5
lsBData.verygood = 3
lsBData.good = 2
lsBData.okay = 1
lsBData.plain = -1
lsBData.poor = -3
lsBData.dull = -5
lsBData.ugly = -10
lsBData.awful = -20
lsBData.terrible = -30

lsBData.listCustom = {
	-- added by server
}

lsBData.listTrash = {
	-- trash
	{name="overlay_messages",istrash=true,beauty="ugly"},{name="overlay_graffiti",istrash=true,beauty="ugly"},{name="floors_burnt",istrash=true,beauty="terrible"},{name="overlay_blood",istrash=true,beauty="terrible"},
	{name="LS_HScraps",istrash=true,beauty="terrible"},{name="blood_floor",istrash=true,beauty="terrible"},{name="overlay_grime",istrash=true,beauty="dull"},{name="brokenglass_",istrash=true,beauty="awful"},
	{name="trash",istrash=true,beauty="ugly"},{name="d_floorleaves",istrash=true,beauty="dull"},{name="d_trash",istrash=true,beauty="ugly"},{name="LS_Scraps",istrash=true,beauty="ugly"},
}


lsBData.list = {

	-- flooring
	-- carpentry
	{name="carpentry_02_58",beauty="poor"},{name="carpentry_02_57",beauty="plain"},{name="carpentry_02_56",beauty="plain"},
	-- metalworking
	{name="constructedobjects_01_86",beauty="okay"},
	-- nature
	{name="blends_natural",beauty="plain",isgroup=true},{name="floors_exterior_natural_",beauty="plain",isgroup=true},{name="fencing_burnt_",beauty="dull",isgroup=true},
	{name="vegetation_ornamental_",beauty="verygood",isgroup=true},{name="vegetation_farm_",beauty="plain",isgroup=true},{name="floors_burnt_",beauty="dull",isgroup=true},
	-- streets and walkways
	{name="blends_street",beauty="plain",isgroup=true},{name="floors_exterior_street_",beauty="plain",isgroup=true},
	-- tiles, wood
	---- cracks
	{name="floors_interior_tilesandwood_01_56",beauty="poor"},{name="floors_interior_tilesandwood_01_57",beauty="poor"},{name="floors_interior_tilesandwood_01_58",beauty="poor"},
	{name="floors_interior_tilesandwood_01_59",beauty="poor"},{name="floors_interior_tilesandwood_01_60",beauty="poor"},{name="floors_interior_tilesandwood_01_61",beauty="poor"},
	{name="floors_interior_tilesandwood_01_62",beauty="poor"},{name="floors_interior_tilesandwood_01_63",beauty="poor"},
	---- wood
	------ old
	{name="floors_interior_tilesandwood_01_40",beauty="plain"},{name="floors_interior_tilesandwood_01_52",beauty="plain"},
	------ basic
	{name="floors_interior_tilesandwood_01_41",beauty="okay"},{name="floors_interior_tilesandwood_01_42",beauty="okay"},{name="floors_interior_tilesandwood_01_49",beauty="okay"},
	{name="floors_interior_tilesandwood_01_43",beauty="okay"},{name="floors_interior_tilesandwood_01_44",beauty="okay"},{name="floors_interior_tilesandwood_01_46",beauty="okay"},
	{name="floors_interior_tilesandwood_01_47",beauty="okay"},{name="floors_interior_tilesandwood_01_48",beauty="okay"},{name="floors_interior_tilesandwood_01_51",beauty="okay"},
	{name="floors_interior_tilesandwood_01_50",beauty="okay"},
	---- others
	{name="location_restaurant_",beauty="okay",isgroup=true},{name="location_hospitality_",beauty="okay",isgroup=true},
	{name="floors_exterior_tilesandstone_",beauty="okay",isgroup=true},{name="floors_interior_tilesandwood_",beauty="good",isgroup=true},
	-- carpets and rugs
	{name="floors_interior_carpet_",beauty="good",isgroup=true},{name="floors_rugs_",beauty="verygood",isgroup=true},{name="recreational_sports_",beauty="plain",isgroup=true},
	-- metal
	{name="industry_",beauty="plain",isgroup=true},{name="location_sewer_",beauty="plain",isgroup=true},

	-- art
	---- artwork and stations
	{name="LS_Painting",isart=true,beauty="pretty",isgroup=true},{name="LS_Sculptures",isart=true,beauty="pretty",isgroup=true},{name="LS_Graffiti",isart=true,beauty="pretty",isgroup=true},

	-- trash
	{name="overlay_messages",istrash=true,beauty="ugly",isgroup=true},{name="overlay_graffiti",istrash=true,beauty="ugly",isgroup=true},{name="floors_burnt",istrash=true,beauty="terrible",isgroup=true},{name="overlay_blood",istrash=true,beauty="terrible",isgroup=true},
	{name="LS_HScraps",istrash=true,beauty="terrible",isgroup=true},{name="blood_floor",istrash=true,beauty="terrible",isgroup=true},{name="overlay_grime",istrash=true,beauty="dull",isgroup=true},{name="brokenglass_",istrash=true,beauty="awful",isgroup=true},
	{name="trash",istrash=true,beauty="ugly",isgroup=true},{name="d_floorleaves",istrash=true,beauty="dull",isgroup=true},{name="d_trash",istrash=true,beauty="ugly",isgroup=true},{name="LS_Scraps",istrash=true,beauty="ugly",isgroup=true},

	-- cleaning (lifestyle)
	---- showers
	{name="LS_Misc_1_0",istrash=true,beauty="poor"},{name="LS_Misc_1_1",istrash=true,beauty="poor"},{name="LS_Misc_1_2",istrash=true,beauty="poor"},{name="LS_Misc_1_3",istrash=true,beauty="poor"},
	{name="LS_Misc_1_4",istrash=true,beauty="poor"},{name="LS_Misc_1_5",istrash=true,beauty="poor"},
	{name="LS_Misc_1_8",istrash=true,beauty="ugly"},{name="LS_Misc_1_9",istrash=true,beauty="ugly"},{name="LS_Misc_1_10",istrash=true,beauty="ugly"},{name="LS_Misc_1_11",istrash=true,beauty="ugly"},
	{name="LS_Misc_1_12",istrash=true,beauty="ugly"},{name="LS_Misc_1_13",istrash=true,beauty="ugly"},
	{name="LS_Misc_1_16",istrash=true,beauty="awful"},{name="LS_Misc_1_17",istrash=true,beauty="awful"},{name="LS_Misc_1_18",istrash=true,beauty="awful"},{name="LS_Misc_1_19",istrash=true,beauty="awful"},
	{name="LS_Misc_1_20",istrash=true,beauty="awful"},{name="LS_Misc_1_21",istrash=true,beauty="awful"},
	---- baths
	{name="LS_Misc_2_0",istrash=true,beauty="poor"},{name="LS_Misc_2_1",istrash=true,beauty="poor"},{name="LS_Misc_2_2",istrash=true,beauty="poor"},{name="LS_Misc_2_3",istrash=true,beauty="poor"},{name="LS_Misc_2_4",istrash=true,beauty="poor"},
	{name="LS_Misc_2_5",istrash=true,beauty="poor"},{name="LS_Misc_2_6",istrash=true,beauty="poor"},{name="LS_Misc_2_7",istrash=true,beauty="poor"},
	{name="LS_Misc_2_8",istrash=true,beauty="ugly"},{name="LS_Misc_2_9",istrash=true,beauty="ugly"},{name="LS_Misc_2_10",istrash=true,beauty="ugly"},{name="LS_Misc_2_11",istrash=true,beauty="ugly"},{name="LS_Misc_2_12",istrash=true,beauty="ugly"},
	{name="LS_Misc_2_13",istrash=true,beauty="ugly"},{name="LS_Misc_2_14",istrash=true,beauty="ugly"},{name="LS_Misc_2_15",istrash=true,beauty="ugly"},
	{name="LS_Misc_2_16",istrash=true,beauty="awful"},{name="LS_Misc_2_17",istrash=true,beauty="awful"},{name="LS_Misc_2_18",istrash=true,beauty="awful"},{name="LS_Misc_2_19",istrash=true,beauty="awful"},{name="LS_Misc_2_20",istrash=true,beauty="awful"},
	{name="LS_Misc_2_21",istrash=true,beauty="awful"},{name="LS_Misc_2_22",istrash=true,beauty="awful"},{name="LS_Misc_2_23",istrash=true,beauty="awful"},
	---- toilets
	{name="LS_Misc_0",istrash=true,beauty="poor"},{name="LS_Misc_1",istrash=true,beauty="poor"},{name="LS_Misc_2",istrash=true,beauty="poor"},{name="LS_Misc_3",istrash=true,beauty="poor"},{name="LS_Misc_4",istrash=true,beauty="poor"},
	{name="LS_Misc_5",istrash=true,beauty="poor"},{name="LS_Misc_6",istrash=true,beauty="poor"},{name="LS_Misc_7",istrash=true,beauty="poor"},
	{name="LS_Misc_8",istrash=true,beauty="ugly"},{name="LS_Misc_9",istrash=true,beauty="ugly"},{name="LS_Misc_10",istrash=true,beauty="ugly"},{name="LS_Misc_11",istrash=true,beauty="ugly"},{name="LS_Misc_12",istrash=true,beauty="ugly"},
	{name="LS_Misc_13",istrash=true,beauty="ugly"},{name="LS_Misc_14",istrash=true,beauty="ugly"},{name="LS_Misc_15",istrash=true,beauty="ugly"},
	{name="LS_Misc_16",istrash=true,beauty="awful"},{name="LS_Misc_17",istrash=true,beauty="awful"},{name="LS_Misc_18",istrash=true,beauty="awful"},{name="LS_Misc_19",istrash=true,beauty="awful"},{name="LS_Misc_20",istrash=true,beauty="awful"},
	{name="LS_Misc_21",istrash=true,beauty="awful"},{name="LS_Misc_22",istrash=true,beauty="awful"},{name="LS_Misc_23",istrash=true,beauty="awful"},


	-- appliances
	-- lifestyle
	{name="ls_djbooth_",beauty="nice",isgroup=true},{name="LS_Discoball_0",beauty="nice"},{name="LS_Disco",beauty="good",isgroup=true},
	
	-- movie camera
	{name="appliances_com_01_44",beauty="okay"},{name="appliances_com_01_45",beauty="okay"},{name="appliances_com_01_46",beauty="okay"},{name="appliances_com_01_47",beauty="okay"},
	-- movie projector
	{name="appliances_com_01_84",beauty="nice"},{name="appliances_com_01_85",beauty="nice"},{name="appliances_com_01_86",beauty="nice"},{name="appliances_com_01_87",beauty="nice"},
	-- control table
	{name="appliances_com_01_52",beauty="dull"},{name="appliances_com_01_53",beauty="dull"},{name="appliances_com_01_54",beauty="dull"},{name="appliances_com_01_55",beauty="dull"},
	-- computer cheap
	{name="appliances_com_01_73",beauty="plain"},{name="appliances_com_01_74",beauty="plain"},{name="appliances_com_01_75",beauty="plain"},{name="appliances_com_01_76",beauty="plain"},
	{name="appliances_com_01_72",beauty="plain"},{name="appliances_com_01_77",beauty="plain"},{name="appliances_com_01_78",beauty="plain"},{name="appliances_com_01_79",beauty="plain"},

	-- ovens
	-- green
	{name="appliances_cooking_01_0",beauty="dull"},{name="appliances_cooking_01_1",beauty="dull"},{name="appliances_cooking_01_2",beauty="dull"},{name="appliances_cooking_01_3",beauty="dull"},
	-- red
	{name="appliances_cooking_01_8",beauty="good"},{name="appliances_cooking_01_9",beauty="good"},{name="appliances_cooking_01_10",beauty="good"},{name="appliances_cooking_01_11",beauty="good"},
	-- white
	{name="appliances_cooking_01_12",beauty="poor"},{name="appliances_cooking_01_13",beauty="poor"},{name="appliances_cooking_01_14",beauty="poor"},{name="appliances_cooking_01_15",beauty="poor"},
	-- modern
	{name="appliances_cooking_01_4",beauty="nice"},{name="appliances_cooking_01_5",beauty="nice"},{name="appliances_cooking_01_6",beauty="nice"},{name="appliances_cooking_01_7",beauty="nice"},
	-- professional
	{name="appliances_cooking_01_20",beauty="good"},{name="appliances_cooking_01_21",beauty="good"},{name="appliances_cooking_01_22",beauty="good"},{name="appliances_cooking_01_23",beauty="good"},
	-- fire
	{name="appliances_cooking_01_16",beauty="poor"},{name="appliances_cooking_01_17",beauty="poor"},{name="appliances_cooking_01_18",beauty="poor"},{name="appliances_cooking_01_19",beauty="poor"},
	-- huge
	{name="appliances_cooking_01_40",beauty="ugly"},{name="appliances_cooking_01_41",beauty="ugly"},{name="appliances_cooking_01_42",beauty="ugly"},{name="appliances_cooking_01_43",beauty="ugly"},
	{name="appliances_cooking_01_48",beauty="ugly"},{name="appliances_cooking_01_49",beauty="ugly"},{name="appliances_cooking_01_50",beauty="ugly"},{name="appliances_cooking_01_51",beauty="ugly"},

	-- microwave cheap
	{name="appliances_cooking_01_24",beauty="dull"},{name="appliances_cooking_01_25",beauty="dull"},{name="appliances_cooking_01_26",beauty="dull"},{name="appliances_cooking_01_27",beauty="dull"},
	-- microwave modern
	{name="appliances_cooking_01_28",beauty="nice"},{name="appliances_cooking_01_29",beauty="nice"},{name="appliances_cooking_01_30",beauty="nice"},{name="appliances_cooking_01_31",beauty="nice"},
	-- toaster
	{name="appliances_cooking_01_32",beauty="verygood"},{name="appliances_cooking_01_33",beauty="verygood"},
	-- grill cheap
	{name="appliances_cooking_01_35",beauty="dull"},
	-- grill modern
	{name="appliances_cooking_01_36",beauty="nice"},{name="appliances_cooking_01_37",beauty="nice"},{name="appliances_cooking_01_38",beauty="nice"},{name="appliances_cooking_01_39",beauty="nice"},
	-- grill professional
	{name="appliances_cooking_01_64",beauty="ugly"},{name="appliances_cooking_01_65",beauty="ugly"},{name="appliances_cooking_01_66",beauty="ugly"},{name="appliances_cooking_01_67",beauty="ugly"},
	-- frier
	{name="appliances_cooking_01_52",beauty="ugly"},{name="appliances_cooking_01_53",beauty="ugly"},{name="appliances_cooking_01_54",beauty="ugly"},{name="appliances_cooking_01_55",beauty="ugly"},
	-- coffee machine cheap
	{name="appliances_cooking_01_56",beauty="plain"},{name="appliances_cooking_01_57",beauty="plain"},{name="appliances_cooking_01_58",beauty="plain"},{name="appliances_cooking_01_59",beauty="plain"},
	-- coffee machine premium
	{name="appliances_cooking_01_60",beauty="pretty"},{name="appliances_cooking_01_61",beauty="pretty"},{name="appliances_cooking_01_62",beauty="pretty"},{name="appliances_cooking_01_63",beauty="pretty"},

	--laundry
	-- washdrier
	{name="appliances_laundry_01_0",beauty="dull"},{name="appliances_laundry_01_1",beauty="dull"},{name="appliances_laundry_01_2",beauty="dull"},{name="appliances_laundry_01_3",beauty="dull"},
	-- modern washing
	{name="appliances_laundry_01_4",beauty="dull"},{name="appliances_laundry_01_5",beauty="dull"},{name="appliances_laundry_01_6",beauty="dull"},{name="appliances_laundry_01_7",beauty="dull"},
	-- modern washerdrier
	{name="appliances_laundry_01_12",beauty="dull"},{name="appliances_laundry_01_13",beauty="dull"},{name="appliances_laundry_01_14",beauty="dull"},{name="appliances_laundry_01_15",beauty="dull"},
	-- cart
	{name="appliances_laundry_01_24",beauty="ugly"},{name="appliances_laundry_01_25",beauty="ugly"},

	-- fridges
	-- red
	{name="appliances_refrigeration_01_32",beauty="nice"},{name="appliances_refrigeration_01_33",beauty="nice"},{name="appliances_refrigeration_01_34",beauty="nice"},{name="appliances_refrigeration_01_35",beauty="nice"},
	-- modern
	{name="appliances_refrigeration_01_8",beauty="pretty"},{name="appliances_refrigeration_01_9",beauty="pretty"},{name="appliances_refrigeration_01_10",beauty="pretty"},{name="appliances_refrigeration_01_11",beauty="pretty"},
	-- minibar
	{name="appliances_refrigeration_01_24",beauty="nice"},{name="appliances_refrigeration_01_25",beauty="nice"},{name="appliances_refrigeration_01_26",beauty="nice"},{name="appliances_refrigeration_01_27",beauty="nice"},
	-- others
	{name="appliances_refrigeration_",beauty="ugly",isgroup=true},

	-- television
	-- modern
	{name="appliances_television_01_0",beauty="pretty"},{name="appliances_television_01_1",beauty="pretty"},{name="appliances_television_01_2",beauty="pretty"},{name="appliances_television_01_3",beauty="pretty"},
	-- cheap
	{name="appliances_television_01_4",beauty="dull"},{name="appliances_television_01_5",beauty="dull"},{name="appliances_television_01_6",beauty="dull"},{name="appliances_television_01_7",beauty="dull"},
	-- old
	{name="appliances_television_01_8",beauty="ugly"},{name="appliances_television_01_9",beauty="ugly"},{name="appliances_television_01_10",beauty="ugly"},{name="appliances_television_01_11",beauty="ugly"},

	-- camping
	-- deer trophy
	{name="camping_01_17",beauty="nice"},{name="camping_01_18",beauty="nice"},
	-- modern
	{name="appliances_refrigeration_01_8",beauty="pretty"},{name="appliances_refrigeration_01_9",beauty="pretty"},{name="appliances_refrigeration_01_10",beauty="pretty"},{name="appliances_refrigeration_01_11",beauty="pretty"},
	-- outdoor table
	{name="camping_01_8",beauty="nice"},{name="camping_01_9",beauty="nice"},{name="camping_01_10",beauty="nice"},{name="camping_01_11",beauty="nice"},
	{name="camping_01_12",beauty="nice"},{name="camping_01_13",beauty="nice"},{name="camping_01_14",beauty="nice"},{name="camping_01_15",beauty="nice"},
	-- others
	{name="camping_",beauty="dull",isgroup=true},

	-- carpentry
	-- others
	{name="carpentry_",beauty="dull",isgroup=true},

	-- constructedobjects
	-- others
	{name="constructedobjects_",beauty="ugly",isgroup=true},

	-- construction
	-- others
	{name="construction_",beauty="ugly",isgroup=true},

	-- crafted
	-- others
	{name="crafted_",beauty="dull",isgroup=true},

	-- wall cracks
	-- others
	{name="d_wallcracks_",beauty="ugly",isgroup=true},

	-- damaged
	-- others
	{name="damaged_",beauty="awful",isgroup=true},

	-- hedges
	{name="f_bushes_2_0",beauty="nice"},{name="f_bushes_2_1",beauty="nice"},{name="f_bushes_2_2",beauty="nice"},{name="f_bushes_2_3",beauty="nice"},
	{name="f_bushes_2_4",beauty="nice"},{name="f_bushes_2_5",beauty="nice"},{name="f_bushes_2_6",beauty="nice"},{name="f_bushes_2_7",beauty="nice"},
	{name="f_bushes_2_8",beauty="nice"},{name="f_bushes_2_9",beauty="nice"},{name="f_bushes_2_10",beauty="nice"},{name="f_bushes_2_11",beauty="nice"},
	{name="f_bushes_2_12",beauty="nice"},{name="f_bushes_2_13",beauty="nice"},{name="f_bushes_2_14",beauty="nice"},{name="f_bushes_2_15",beauty="nice"},
	{name="f_bushes_2_16",beauty="nice"},{name="f_bushes_2_17",beauty="nice"},{name="f_bushes_2_18",beauty="nice"},{name="f_bushes_2_19",beauty="nice"},
	{name="vegetation_ornamental_",beauty="nice",isgroup=true},

	-- flower beds
	-- others
	{name="f_flowerbed_",beauty="pretty",isgroup=true},

	-- deer trophy
	{name="camping_01_17",beauty="nice"},{name="camping_01_18",beauty="nice"},

	-- fencing
	-- iron
	{name="fencing_01_0",beauty="pretty"},{name="fencing_01_1",beauty="pretty"},{name="fencing_01_2",beauty="pretty"},{name="fencing_01_3",beauty="pretty"},
	-- white picket
	{name="fencing_01_4",beauty="nice"},{name="fencing_01_5",beauty="nice"},{name="fencing_01_6",beauty="nice"},{name="fencing_01_7",beauty="nice"},
	-- large red wood
	{name="fencing_01_8",beauty="nice"},{name="fencing_01_9",beauty="nice"},{name="fencing_01_10",beauty="nice"},{name="fencing_01_11",beauty="nice"},
	{name="fencing_01_12",beauty="nice"},{name="fencing_01_13",beauty="nice"},{name="fencing_01_74",beauty="nice"},{name="fencing_01_75",beauty="nice"},
	-- large iron
	{name="fencing_01_64",beauty="nice"},{name="fencing_01_65",beauty="nice"},{name="fencing_01_66",beauty="nice"},{name="fencing_01_67",beauty="nice"},
	{name="fencing_01_68",beauty="nice"},{name="fencing_01_69",beauty="nice"},
	-- marble
	{name="fencing_01_104",beauty="beautiful"},{name="fencing_01_105",beauty="beautiful"},{name="fencing_01_106",beauty="beautiful"},{name="fencing_01_107",beauty="beautiful"},
	-- wood
	{name="fencing_01_32",beauty="good"},{name="fencing_01_33",beauty="good"},{name="fencing_01_34",beauty="good"},{name="fencing_01_35",beauty="good"},
	{name="fencing_01_36",beauty="good"},{name="fencing_01_37",beauty="good"},
	-- others
	{name="fencing_",beauty="ugly",isgroup=true},

	-- fixtures
	-- fancy toilet
	{name="fixtures_bathroom_01_0",beauty="nice"},{name="fixtures_bathroom_01_1",beauty="nice"},{name="fixtures_bathroom_01_2",beauty="nice"},{name="fixtures_bathroom_01_3",beauty="nice"},
	-- urinal
	{name="fixtures_bathroom_01_8",beauty="ugly"},{name="fixtures_bathroom_01_9",beauty="ugly"},{name="fixtures_bathroom_01_10",beauty="ugly"},{name="fixtures_bathroom_01_11",beauty="ugly"},
	-- chemical
	{name="fixtures_bathroom_02_4",beauty="awful"},{name="fixtures_bathroom_02_5",beauty="awful"},{name="fixtures_bathroom_02_14",beauty="awful"},{name="fixtures_bathroom_02_15",beauty="awful"},
	-- wooden
	{name="fixtures_bathroom_02_24",beauty="terrible"},{name="fixtures_bathroom_02_25",beauty="terrible"},{name="fixtures_bathroom_02_26",beauty="terrible"},{name="fixtures_bathroom_02_27",beauty="terrible"},
	-- bathroom - others
	{name="fixtures_bathroom_",beauty="dull",isgroup=true},
	-- counters
	{name="fixtures_counters_",beauty="good",isgroup=true},

	-- floor rugs
	-- simple
	{name="floors_rugs_01_",beauty="good",isgroup=true},
	-- fur
	{name="floors_rugs_02_",beauty="verygood",isgroup=true},

	-- beds
	-- military
	{name="furniture_bedding_01_56",beauty="ugly"},{name="furniture_bedding_01_57",beauty="ugly"},{name="furniture_bedding_01_58",beauty="ugly"},{name="furniture_bedding_01_59",beauty="ugly"},
	-- others
	{name="furniture_bedding_",beauty="nice",isgroup=true},

	-- seating
	-- vintage red couch
	{name="furniture_seating_indoor_03_72",beauty="beautiful"},{name="furniture_seating_indoor_03_73",beauty="beautiful"},{name="furniture_seating_indoor_03_74",beauty="beautiful"},{name="furniture_seating_indoor_03_75",beauty="beautiful"},
	{name="furniture_seating_indoor_03_76",beauty="beautiful"},{name="furniture_seating_indoor_03_77",beauty="beautiful"},{name="furniture_seating_indoor_03_78",beauty="beautiful"},{name="furniture_seating_indoor_03_79",beauty="beautiful"},
	-- vintage red armchair
	{name="furniture_seating_indoor_03_84",beauty="beautiful"},{name="furniture_seating_indoor_03_85",beauty="beautiful"},{name="furniture_seating_indoor_03_86",beauty="beautiful"},{name="furniture_seating_indoor_03_87",beauty="beautiful"},
	-- vintage yellow couch
	{name="furniture_seating_indoor_03_88",beauty="beautiful"},{name="furniture_seating_indoor_03_89",beauty="beautiful"},{name="furniture_seating_indoor_03_90",beauty="beautiful"},{name="furniture_seating_indoor_03_91",beauty="beautiful"},
	{name="furniture_seating_indoor_03_92",beauty="beautiful"},{name="furniture_seating_indoor_03_93",beauty="beautiful"},{name="furniture_seating_indoor_03_94",beauty="beautiful"},{name="furniture_seating_indoor_03_95",beauty="beautiful"},
	-- vintage yellow armchair
	{name="furniture_seating_indoor_03_80",beauty="beautiful"},{name="furniture_seating_indoor_03_81",beauty="beautiful"},{name="furniture_seating_indoor_03_82",beauty="beautiful"},{name="furniture_seating_indoor_03_83",beauty="beautiful"},
	-- vintage zebra couch
	{name="furniture_seating_indoor_03_104",beauty="beautiful"},{name="furniture_seating_indoor_03_105",beauty="beautiful"},{name="furniture_seating_indoor_03_106",beauty="beautiful"},{name="furniture_seating_indoor_03_107",beauty="beautiful"},
	{name="furniture_seating_indoor_03_108",beauty="beautiful"},{name="furniture_seating_indoor_03_109",beauty="beautiful"},{name="furniture_seating_indoor_03_110",beauty="beautiful"},{name="furniture_seating_indoor_03_111",beauty="beautiful"},
	-- vintage zebra armchair
	{name="furniture_seating_indoor_03_96",beauty="beautiful"},{name="furniture_seating_indoor_03_97",beauty="beautiful"},{name="furniture_seating_indoor_03_98",beauty="beautiful"},{name="furniture_seating_indoor_03_99",beauty="beautiful"},
	-- vintage black couch
	{name="furniture_seating_indoor_03_112",beauty="beautiful"},{name="furniture_seating_indoor_03_113",beauty="beautiful"},{name="furniture_seating_indoor_03_114",beauty="beautiful"},{name="furniture_seating_indoor_03_115",beauty="beautiful"},
	{name="furniture_seating_indoor_03_116",beauty="beautiful"},{name="furniture_seating_indoor_03_117",beauty="beautiful"},{name="furniture_seating_indoor_03_118",beauty="beautiful"},{name="furniture_seating_indoor_03_119",beauty="beautiful"},
	-- vintage black armchair
	{name="furniture_seating_indoor_03_100",beauty="beautiful"},{name="furniture_seating_indoor_03_101",beauty="beautiful"},{name="furniture_seating_indoor_03_102",beauty="beautiful"},{name="furniture_seating_indoor_03_103",beauty="beautiful"},
	-- vintage white couch
	{name="furniture_seating_indoor_03_136",beauty="beautiful"},{name="furniture_seating_indoor_03_137",beauty="beautiful"},{name="furniture_seating_indoor_03_138",beauty="beautiful"},{name="furniture_seating_indoor_03_139",beauty="beautiful"},
	{name="furniture_seating_indoor_03_140",beauty="beautiful"},{name="furniture_seating_indoor_03_141",beauty="beautiful"},{name="furniture_seating_indoor_03_142",beauty="beautiful"},{name="furniture_seating_indoor_03_143",beauty="beautiful"},
	-- vintage white armchair
	{name="furniture_seating_indoor_03_124",beauty="beautiful"},{name="furniture_seating_indoor_03_125",beauty="beautiful"},{name="furniture_seating_indoor_03_126",beauty="beautiful"},{name="furniture_seating_indoor_03_127",beauty="beautiful"},
	-- vintage red couch
	{name="furniture_seating_indoor_03_128",beauty="beautiful"},{name="furniture_seating_indoor_03_129",beauty="beautiful"},{name="furniture_seating_indoor_03_130",beauty="beautiful"},{name="furniture_seating_indoor_03_131",beauty="beautiful"},
	{name="furniture_seating_indoor_03_132",beauty="beautiful"},{name="furniture_seating_indoor_03_133",beauty="beautiful"},{name="furniture_seating_indoor_03_134",beauty="beautiful"},{name="furniture_seating_indoor_03_135",beauty="beautiful"},
	-- vintage red armchair
	{name="furniture_seating_indoor_03_120",beauty="beautiful"},{name="furniture_seating_indoor_03_121",beauty="beautiful"},{name="furniture_seating_indoor_03_122",beauty="beautiful"},{name="furniture_seating_indoor_03_123",beauty="beautiful"},
	-- folding chair
	{name="furniture_seating_indoor_01_60",beauty="dull"},{name="furniture_seating_indoor_01_61",beauty="dull"},{name="furniture_seating_indoor_01_62",beauty="dull"},{name="furniture_seating_indoor_01_63",beauty="dull"},
	-- cheap chair
	{name="furniture_seating_indoor_01_52",beauty="dull"},{name="furniture_seating_indoor_01_53",beauty="dull"},{name="furniture_seating_indoor_01_54",beauty="dull"},{name="furniture_seating_indoor_01_55",beauty="dull"},
	-- plastic chair
	{name="furniture_seating_outdoor_01_16",beauty="dull"},{name="furniture_seating_outdoor_01_17",beauty="dull"},{name="furniture_seating_outdoor_01_18",beauty="dull"},{name="furniture_seating_outdoor_01_19",beauty="dull"},
	-- others
	{name="furniture_seating_",beauty="nice",isgroup=true},

	-- furniture shelves
	-- metal
	{name="furniture_shelving_01_24",beauty="ugly"},{name="furniture_shelving_01_25",beauty="ugly"},{name="furniture_shelving_01_26",beauty="ugly"},{name="furniture_shelving_01_27",beauty="ugly"},
	-- metal wall
	{name="furniture_shelving_01_28",beauty="ugly"},{name="furniture_shelving_01_29",beauty="ugly"},{name="furniture_shelving_01_30",beauty="ugly"},{name="furniture_shelving_01_31",beauty="ugly"},
	-- others
	{name="furniture_shelving_",beauty="dull",isgroup=true},

	-- furniture storage
	-- metal
	{name="furniture_storage_02_0",beauty="ugly"},{name="furniture_storage_02_1",beauty="ugly"},{name="furniture_storage_02_2",beauty="ugly"},{name="furniture_storage_02_3",beauty="ugly"},
	-- metal blue
	{name="furniture_storage_02_4",beauty="ugly"},{name="furniture_storage_02_5",beauty="ugly"},{name="furniture_storage_02_6",beauty="ugly"},{name="furniture_storage_02_7",beauty="ugly"},
	-- metal military
	{name="furniture_storage_02_8",beauty="ugly"},{name="furniture_storage_02_9",beauty="ugly"},{name="furniture_storage_02_10",beauty="ugly"},{name="furniture_storage_02_11",beauty="ugly"},
	-- metal yellow
	{name="furniture_storage_02_12",beauty="ugly"},{name="furniture_storage_02_13",beauty="ugly"},{name="furniture_storage_02_14",beauty="ugly"},{name="furniture_storage_02_15",beauty="ugly"},
	-- cardboard
	{name="furniture_storage_02_16",beauty="ugly"},{name="furniture_storage_02_17",beauty="ugly"},{name="furniture_storage_02_18",beauty="ugly"},{name="furniture_storage_02_19",beauty="ugly"},
	{name="furniture_storage_02_24",beauty="ugly"},{name="furniture_storage_02_25",beauty="ugly"},{name="furniture_storage_02_26",beauty="ugly"},{name="furniture_storage_02_27",beauty="ugly"},
	-- others
	{name="furniture_storage_",beauty="nice",isgroup=true},

	-- furniture tables
	-- glass low
	{name="furniture_tables_low_01_8",beauty="pretty"},{name="furniture_tables_low_01_9",beauty="pretty"},{name="furniture_tables_low_01_10",beauty="pretty"},{name="furniture_tables_low_01_11",beauty="pretty"},
	-- plastic
	{name="furniture_tables_high_01_44",beauty="dull"},{name="furniture_tables_high_01_45",beauty="dull"},{name="furniture_tables_high_01_46",beauty="dull"},{name="furniture_tables_high_01_47",beauty="dull"},
	-- metal
	{name="furniture_tables_high_01_48",beauty="dull"},{name="furniture_tables_high_01_49",beauty="dull"},{name="furniture_tables_high_01_50",beauty="dull"},{name="furniture_tables_high_01_51",beauty="dull"},
	{name="furniture_tables_high_02_16",beauty="dull"},{name="furniture_tables_high_02_17",beauty="dull"},{name="furniture_tables_high_02_18",beauty="dull"},{name="furniture_tables_high_02_19",beauty="dull"},
	{name="furniture_tables_high_02_20",beauty="dull"},{name="furniture_tables_high_02_21",beauty="dull"},
	-- workbench wood
	{name="furniture_tables_high_01_52",beauty="dull"},{name="furniture_tables_high_01_53",beauty="dull"},{name="furniture_tables_high_01_54",beauty="dull"},{name="furniture_tables_high_01_55",beauty="dull"},
	-- workbench white
	{name="furniture_tables_high_01_56",beauty="dull"},{name="furniture_tables_high_01_57",beauty="dull"},{name="furniture_tables_high_01_58",beauty="dull"},{name="furniture_tables_high_01_59",beauty="dull"},
	-- others
	{name="furniture_tables_",beauty="nice",isgroup=true},

	-- industry
	-- others
	{name="industry_",beauty="ugly",isgroup=true},

	-- lighting
	-- construction lamp
	{name="lighting_outdoor_01_48",beauty="ugly"},{name="lighting_outdoor_01_49",beauty="ugly"},{name="lighting_outdoor_01_50",beauty="ugly"},{name="lighting_outdoor_01_51",beauty="ugly"},
	-- others
	{name="lighting_indoor_",beauty="nice",isgroup=true},

	-- location business machinery
	-- others
	{name="location_business_machinery_",beauty="dull",isgroup=true},

	-- location business
	-- red wooden desk
	{name="location_business_office_generic_01_0",beauty="pretty"},{name="location_business_office_generic_01_1",beauty="pretty"},{name="location_business_office_generic_01_2",beauty="pretty"},
	{name="location_business_office_generic_01_3",beauty="pretty"},{name="location_business_office_generic_01_4",beauty="pretty"},{name="location_business_office_generic_01_5",beauty="pretty"},
	{name="location_business_office_generic_01_6",beauty="pretty"},{name="location_business_office_generic_01_8",beauty="pretty"},{name="location_business_office_generic_01_9",beauty="pretty"},
	{name="location_business_office_generic_01_10",beauty="pretty"},{name="location_business_office_generic_01_11",beauty="pretty"},{name="location_business_office_generic_01_12",beauty="pretty"},
	{name="location_business_office_generic_01_13",beauty="pretty"},{name="location_business_office_generic_01_14",beauty="pretty"},
	-- wooden desk
	{name="location_business_office_generic_01_40",beauty="nice"},{name="location_business_office_generic_01_41",beauty="nice"},{name="location_business_office_generic_01_42",beauty="nice"},
	{name="location_business_office_generic_01_44",beauty="nice"},{name="location_business_office_generic_01_45",beauty="nice"},{name="location_business_office_generic_01_46",beauty="nice"},
	{name="location_business_office_generic_01_47",beauty="nice"},
	-- others
	{name="location_business_",beauty="dull",isgroup=true},

	-- industry
	-- others
	{name="industry_",beauty="ugly",isgroup=true},

	-- location community cemetary
	-- angel
	{name="location_community_cemetary_01_11",beauty="pretty"},
	-- tombstones
	{name="location_community_cemetary_01_0",beauty="nice"},{name="location_community_cemetary_01_1",beauty="nice"},{name="location_community_cemetary_01_2",beauty="nice"},
	{name="location_community_cemetary_01_3",beauty="nice"},{name="location_community_cemetary_01_4",beauty="nice"},{name="location_community_cemetary_01_5",beauty="nice"},
	{name="location_community_cemetary_01_6",beauty="nice"},{name="location_community_cemetary_01_7",beauty="nice"},{name="location_community_cemetary_01_8",beauty="nice"},
	{name="location_community_cemetary_01_9",beauty="nice"},
	-- wooden cross / pole / cairn
	{name="location_community_cemetary_01_22",beauty="good"},{name="location_community_cemetary_01_23",beauty="good"},{name="location_community_cemetary_01_36",beauty="good"},
	{name="location_community_cemetary_01_37",beauty="good"},{name="location_community_cemetary_01_38",beauty="good"},{name="location_community_cemetary_01_39",beauty="good"},
	{name="location_community_cemetary_01_30",beauty="good"},{name="location_community_cemetary_01_31",beauty="good"},
	-- closed hole
	{name="location_community_cemetary_01_24",beauty="dull"},{name="location_community_cemetary_01_25",beauty="dull"},{name="location_community_cemetary_01_26",beauty="dull"},
	{name="location_community_cemetary_01_27",beauty="dull"},{name="location_community_cemetary_01_28",beauty="dull"},{name="location_community_cemetary_01_29",beauty="dull"},
	{name="location_community_cemetary_01_40",beauty="dull"},{name="location_community_cemetary_01_41",beauty="dull"},{name="location_community_cemetary_01_42",beauty="dull"},
	{name="location_community_cemetary_01_43",beauty="dull"},
	-- others
	{name="location_community_cemetary_",beauty="terrible",isgroup=true},

	-- location community church
	-- others
	{name="location_community_church_",beauty="nice",isgroup=true},

	-- location community park
	-- fountain
	{name="location_community_park_01_48",beauty="beautiful"},
	-- others
	{name="location_community_park",beauty="nice",isgroup=true},

	-- location community
	-- others
	{name="location_community_",beauty="dull",isgroup=true},

	-- location entertainment gallery
	-- others
	{name="location_entertainment_gallery_",beauty="wondrous",isgroup=true},

	-- location entertainment
	-- others
	{name="location_entertainment_",beauty="dull",isgroup=true},

	-- location farm
	--others
	{name="location_farm_",beauty="dull",isgroup=true},

	-- counter sunstar
	{name="location_hospitality_sunstarmotel_02_12",beauty="nice"},{name="location_hospitality_sunstarmotel_02_13",beauty="nice"},{name="location_hospitality_sunstarmotel_02_14",beauty="nice"},
	{name="location_hospitality_sunstarmotel_02_15",beauty="nice"},
	-- wall counter sunstar
	-- counter sunstar
	{name="location_hospitality_sunstarmotel_02_20",beauty="nice"},{name="location_hospitality_sunstarmotel_02_21",beauty="nice"},{name="location_hospitality_sunstarmotel_02_22",beauty="nice"},
	{name="location_hospitality_sunstarmotel_02_23",beauty="nice"},

	-- location military generic
	-- others
	{name="location_military_generic_",beauty="ugly",isgroup=true},

	-- location military knox
	-- gold bars
	{name="location_military_knox_01_1",beauty="wondrous"},{name="location_military_knox_01_2",beauty="wondrous"},{name="location_military_knox_01_3",beauty="wondrous"},{name="location_military_knox_01_4",beauty="wondrous"},
	-- others
	{name="location_military_knox_",beauty="dull",isgroup=true},

	-- location restaurant bar
	-- others
	{name="location_restaurant_bar_",beauty="nice",isgroup=true},

	-- location restaurant
	--others
	{name="location_restaurant_",beauty="dull",isgroup=true},

	-- location shop
	--others
	{name="location_shop_",beauty="dull",isgroup=true},

	-- location trailer
	--others
	{name="location_trailer_",beauty="dull",isgroup=true},

	-- recreational
	-- jukebox
	{name="recreational_01_0",beauty="pretty"},{name="recreational_01_1",beauty="pretty"},
	-- piano
	{name="recreational_01_8",beauty="pretty"},{name="recreational_01_9",beauty="pretty"},{name="recreational_01_12",beauty="pretty"},{name="recreational_01_13",beauty="pretty"},
	{name="recreational_01_28",beauty="pretty"},{name="recreational_01_29",beauty="pretty"},{name="recreational_01_30",beauty="pretty"},{name="recreational_01_31",beauty="pretty"},
	-- large piano
	{name="recreational_01_40",beauty="beautiful"},{name="recreational_01_42",beauty="beautiful"},{name="recreational_01_43",beauty="beautiful"},{name="recreational_01_44",beauty="beautiful"},
	{name="recreational_01_45",beauty="beautiful"},{name="recreational_01_46",beauty="beautiful"},{name="recreational_01_47",beauty="beautiful"},{name="recreational_01_48",beauty="beautiful"},
	{name="recreational_01_49",beauty="beautiful"},{name="recreational_01_50",beauty="beautiful"},{name="recreational_01_51",beauty="beautiful"},{name="recreational_01_52",beauty="beautiful"},
	{name="recreational_01_53",beauty="beautiful"},{name="recreational_01_41",beauty="beautiful"},
	{name="recreational_01_96",beauty="beautiful"},{name="recreational_01_97",beauty="beautiful"},{name="recreational_01_98",beauty="beautiful"},{name="recreational_01_99",beauty="beautiful"},
	{name="recreational_01_100",beauty="beautiful"},{name="recreational_01_101",beauty="beautiful"},{name="recreational_01_102",beauty="beautiful"},{name="recreational_01_103",beauty="beautiful"},
	{name="recreational_01_104",beauty="beautiful"},{name="recreational_01_105",beauty="beautiful"},{name="recreational_01_106",beauty="beautiful"},{name="recreational_01_107",beauty="beautiful"},
	{name="recreational_01_108",beauty="beautiful"},{name="recreational_01_109",beauty="beautiful"},
	-- others
	{name="recreational_",beauty="nice",isgroup=true},

	-- rugs
	-- others
	{name="rugs_",beauty="verygood",isgroup=true},

	-- street decoration
	-- others
	{name="street_decoration_",beauty="dull",isgroup=true},

	-- trash containers
	-- park trashcan
	{name="trashcontainers_01_21",beauty="plain"},
	-- others
	{name="trashcontainers_",beauty="ugly",isgroup=true},

	-- vegetation
	-- dying
	{name="vegetation_indoor_01_16",beauty="nice"},{name="vegetation_indoor_01_17",beauty="nice"},{name="vegetation_indoor_01_18",beauty="nice"},{name="vegetation_indoor_01_19",beauty="nice"},
	{name="vegetation_indoor_01_20",beauty="nice"},{name="vegetation_indoor_01_21",beauty="nice"},
	-- dead
	{name="vegetation_indoor_01_24",beauty="ugly"},{name="vegetation_indoor_01_25",beauty="ugly"},{name="vegetation_indoor_01_26",beauty="ugly"},{name="vegetation_indoor_01_27",beauty="ugly"},
	{name="vegetation_indoor_01_28",beauty="ugly"},{name="vegetation_indoor_01_29",beauty="ugly"},
	-- empty
	{name="vegetation_indoor_01_32",beauty="dull"},{name="vegetation_indoor_01_33",beauty="dull"},{name="vegetation_indoor_01_34",beauty="dull"},{name="vegetation_indoor_01_35",beauty="dull"},
	{name="vegetation_indoor_01_36",beauty="dull"},{name="vegetation_indoor_01_37",beauty="dull"},
	-- hay bales
	{name="vegetation_farm_01_8",beauty="ugly"},{name="vegetation_farm_01_9",beauty="ugly"},{name="vegetation_farm_01_10",beauty="ugly"},{name="vegetation_farm_01_11",beauty="ugly"},
	{name="vegetation_farm_01_16",beauty="ugly"},{name="vegetation_farm_01_17",beauty="ugly"},{name="vegetation_farm_01_18",beauty="ugly"},{name="vegetation_farm_01_19",beauty="ugly"},
	-- others
	{name="vegetation_indoor_",beauty="pretty",isgroup=true},

	-- signs
	-- others
	{name="signs_",beauty="dull",isgroup=true},

	-- misc
	{name="advertising",beauty="dull",isgroup=true},
	-- generators
	--red
	{name="appliances_misc_01_0",beauty="awful"},{name="appliances_misc_01_1",beauty="awful"},{name="appliances_misc_01_2",beauty="awful"},{name="appliances_misc_01_3",beauty="awful"},
	--blue
	{name="appliances_misc_01_12",beauty="ugly"},{name="appliances_misc_01_13",beauty="ugly"},{name="appliances_misc_01_14",beauty="ugly"},{name="appliances_misc_01_15",beauty="ugly"},
	--yellow
	{name="appliances_misc_01_8",beauty="awful"},{name="appliances_misc_01_9",beauty="awful"},{name="appliances_misc_01_10",beauty="awful"},{name="appliances_misc_01_11",beauty="awful"},
	--cheap
	{name="appliances_misc_01_4",beauty="terrible"},{name="appliances_misc_01_5",beauty="terrible"},{name="appliances_misc_01_6",beauty="terrible"},{name="appliances_misc_01_7",beauty="terrible"},

}

function getBeautyProperty(objName, trashOnly)
	local beauty, isTrash, isArt = 0, false, false
	if trashOnly then
		for k, v in pairs(lsBData.listTrash) do
			if objName == v.name or luautils.stringStarts(objName, v.name) then beauty = lsBData[v.beauty]; isTrash = v.istrash; isArt = v.isart; break; end
		end
		return beauty, isTrash, isArt
	end
	if lsBData.listCustom[objName] then return lsBData.listCustom[objName], false, false; end
	for k, v in pairs(lsBData.list) do
		if objName == v.name or (v.isgroup and luautils.stringStarts(objName, v.name)) then beauty = lsBData[v.beauty]; isTrash = v.istrash; isArt = v.isart; break; end
	end
	return beauty, isTrash, isArt
end

function updateCustomBeautyTable(spriteName, val)
	lsBData.listCustom[spriteName] = val
end

function loadCustomBeautyTable()
	lsBData.listCustom = {}
	local lsData = ModData.getOrCreate("LSDATA")
	if lsData and lsData["BTY"] then
		for k, v in pairs(lsData["BTY"]) do
			lsBData.listCustom[k] = v
		end
	end
	if not lsBData.sandboxMult then
		local mult = SandboxVars.LSArt.GeneralBeautyMultiplier or 1 -- sandbox option
		if mult ~= 1 then
			local beautyVals = {"wondrous","beautiful","pretty","nice","verygood","good","okay","plain","poor","dull","ugly","awful","terrible"}
			for n=1,#beautyVals do
				local bVal = beautyVals[n]
				if lsBData[bVal] then
					local newVal
					if lsBData[bVal] < 0 then
						newVal = math.floor(lsBData[bVal]*mult)
					else
						newVal = math.ceil(lsBData[bVal]*mult)
					end
					lsBData[bVal] = newVal
				end
			end
		end
		local finalBeauty
		if beauty then
			if beauty < 0 then finalBeauty = math.floor(beauty*mult); else finalBeauty = math.ceil(beauty*mult); end
		end
		lsBData.sandboxMult = true
	end
end

Events.OnGameStart.Add(loadCustomBeautyTable)

--[[
if getActivatedMods():contains('melos_tiles_for_miles_pack') then
	local customTable = require 'Properties/Objects/beauty_melo'
	if not customTable then return; end
	for k, v in pairs(customTable) do
		table.insert(lsBData.list, {name=v.name,beauty=v.beauty,isgroup=v.isgroup})
	end

	--local customTableTrash = require 'Properties/Objects/beauty_melo_trash'
	--for k, v in pairs(customTableTrash) do
	--	table.insert(lsBData.listTrash, {name=v.name,beauty=v.beauty,istrash=true})
	--end

end
]]--