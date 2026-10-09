-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

LS_AMcache['melo'] = LS_AMcache['melo'] or (not LS_AMcache['melo_cached'] and LS_PatchUtils.hasCompatMod('melo'))

--Beauty Patch for Melo's Tiles

if not LS_AMcache['melo'] then return; end

return {

	-- flooring
	-- natural
	{name="melos_tiles_floors_natural_",beauty="plain",isgroup=true},
	-- overlays
	{name="melos_tiles_floors_overlays_",beauty="poor",isgroup=true},
	-- all
	{name="melos_tiles_floors_",beauty="okay",isgroup=true},

	-- bathroom
	-- all
	{name="melos_tiles_furniture_bathroom_",beauty="nice",isgroup=true},

	-- all furniture
	{name="melos_tiles_furniture_",beauty="nice",isgroup=true},

	-- blue freezer
	{name="melos_tiles_appliances_01_84",beauty="dull"},{name="melos_tiles_appliances_01_85",beauty="dull"},{name="melos_tiles_appliances_01_86",beauty="dull"},{name="melos_tiles_appliances_01_87",beauty="dull"},
	-- appliances
	{name="melos_tiles_appliances_",beauty="nice",isgroup=true},

	-- castle
	{name="melos_tiles_castle_",beauty="nice",isgroup=true},

	-- church
	{name="melos_tiles_church_",beauty="nice",isgroup=true},

	-- construction
	{name="melos_tiles_construction_",beauty="ugly",isgroup=true},

	-- curtains
	--destroyed
	{name="melos_tiles_curtains_04_103",beauty="ugly"},{name="melos_tiles_curtains_04_119",beauty="ugly"},{name="melos_tiles_curtains_04_87",beauty="ugly"},{name="melos_tiles_curtains_04_111",beauty="ugly"},
	{name="melos_tiles_curtains_04_100",beauty="ugly"},{name="melos_tiles_curtains_04_102",beauty="ugly"},{name="melos_tiles_curtains_04_114",beauty="ugly"},{name="melos_tiles_curtains_04_118",beauty="ugly"},
	{name="melos_tiles_curtains_04_95",beauty="ugly"},{name="melos_tiles_curtains_04_112",beauty="ugly"},{name="melos_tiles_curtains_04_80",beauty="ugly"},{name="melos_tiles_curtains_04_127",beauty="ugly"},
	{name="melos_tiles_curtains_04_116",beauty="ugly"},{name="melos_tiles_curtains_04_96",beauty="ugly"},{name="melos_tiles_curtains_04_86",beauty="ugly"},{name="melos_tiles_curtains_04_115",beauty="ugly"},
	{name="melos_tiles_curtains_04_81",beauty="ugly"},{name="melos_tiles_curtains_04_97",beauty="ugly"},{name="melos_tiles_curtains_04_101",beauty="ugly"},{name="melos_tiles_curtains_04_120",beauty="ugly"},
	{name="melos_tiles_curtains_04_124",beauty="ugly"},{name="melos_tiles_curtains_04_90",beauty="ugly"},{name="melos_tiles_curtains_04_82",beauty="ugly"},{name="melos_tiles_curtains_04_84",beauty="ugly"},
	{name="melos_tiles_curtains_04_113",beauty="ugly"},{name="melos_tiles_curtains_04_83",beauty="ugly"},{name="melos_tiles_curtains_04_85",beauty="ugly"},{name="melos_tiles_curtains_04_104",beauty="ugly"},
	{name="melos_tiles_curtains_04_108",beauty="ugly"},{name="melos_tiles_curtains_04_110",beauty="ugly"},{name="melos_tiles_curtains_04_105",beauty="ugly"},{name="melos_tiles_curtains_04_98",beauty="ugly"},
	{name="melos_tiles_curtains_04_117",beauty="ugly"},{name="melos_tiles_curtains_04_106",beauty="ugly"},{name="melos_tiles_curtains_04_94",beauty="ugly"},{name="melos_tiles_curtains_04_123",beauty="ugly"},
	{name="melos_tiles_curtains_04_109",beauty="ugly"},{name="melos_tiles_curtains_04_117",beauty="ugly"},{name="melos_tiles_curtains_04_126",beauty="ugly"},{name="melos_tiles_curtains_04_92",beauty="ugly"},
	{name="melos_tiles_curtains_04_121",beauty="ugly"},{name="melos_tiles_curtains_04_99",beauty="ugly"},{name="melos_tiles_curtains_04_88",beauty="ugly"},{name="melos_tiles_curtains_04_122",beauty="ugly"},
	{name="melos_tiles_curtains_04_107",beauty="ugly"},{name="melos_tiles_curtains_04_89",beauty="ugly"},{name="melos_tiles_curtains_04_91",beauty="ugly"},{name="melos_tiles_curtains_04_125",beauty="ugly"},
	{name="melos_tiles_curtains_04_93",beauty="ugly"},
	--regal
	{name="melos_tiles_curtains_01_",beauty="beautiful",isgroup=true},
	--canvas
	{name="melos_tiles_curtains_random_",beauty="dull",isgroup=true},
	--simple
	{name="melos_tiles_curtains_",beauty="pretty",isgroup=true},

	--detailing
	{name="melos_tiles_detailing_",beauty="nice",isgroup=true},

	--doorframe
	{name="melos_tiles_doorframes_",beauty="nice",isgroup=true},
	
	--fences
	--iron
	{name="melos_tiles_fencing_02_114",beauty="nice"},{name="melos_tiles_fencing_02_82",beauty="nice"},{name="melos_tiles_fencing_02_98",beauty="nice"},{name="melos_tiles_fencing_02_84",beauty="nice"},
	{name="melos_tiles_fencing_02_87",beauty="nice"},{name="melos_tiles_fencing_02_80",beauty="nice"},{name="melos_tiles_fencing_02_112",beauty="nice"},{name="melos_tiles_fencing_02_96",beauty="nice"},
	{name="melos_tiles_fencing_02_115",beauty="nice"},{name="melos_tiles_fencing_02_99",beauty="nice"},{name="melos_tiles_fencing_02_86",beauty="nice"},{name="melos_tiles_fencing_02_113",beauty="nice"},
	{name="melos_tiles_fencing_02_81",beauty="nice"},{name="melos_tiles_fencing_02_85",beauty="nice"},{name="melos_tiles_fencing_02_97",beauty="nice"},{name="melos_tiles_fencing_02_83",beauty="nice"},
	{name="melos_tiles_fencing_01_",beauty="nice",isgroup=true},
	--wood
	{name="melos_tiles_fencing_02_2",beauty="good"},{name="melos_tiles_fencing_02_6",beauty="good"},{name="melos_tiles_fencing_02_5",beauty="good"},{name="melos_tiles_fencing_02_4",beauty="good"},
	{name="melos_tiles_fencing_02_7",beauty="good"},{name="melos_tiles_fencing_02_0",beauty="good"},{name="melos_tiles_fencing_02_1",beauty="good"},{name="melos_tiles_fencing_02_19",beauty="good"},
	{name="melos_tiles_fencing_02_17",beauty="good"},{name="melos_tiles_fencing_02_16",beauty="good"},{name="melos_tiles_fencing_02_18",beauty="good"},{name="melos_tiles_fencing_02_3",beauty="good"},
	{name="melos_tiles_fencing_03_",beauty="good",isgroup=true},{name="melos_tiles_fencing_04_",beauty="good",isgroup=true},{name="melos_tiles_fencing_05_",beauty="nice",isgroup=true},
	--stone
	{name="melos_tiles_fencing_06_",beauty="pretty",isgroup=true},
	--others
	{name="melos_tiles_fencing_03_",beauty="nice",isgroup=true},
	{name="melos_tiles_fencing_02_",beauty="dull",isgroup=true},

	--flags
	{name="melos_tiles_flags_",beauty="nice",isgroup=true},

}

