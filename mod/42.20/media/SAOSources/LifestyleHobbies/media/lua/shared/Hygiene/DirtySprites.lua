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
LSHygiene = LSHygiene or {}
LSHygiene.DS = {};

local ds_categories = {"Toilets","Bathtubs","Showers"}

LSHygiene.DS.Toilets = {
	-- fancy
	['fixtures_bathroom_01_0'] = {"LS_Misc_0","LS_Misc_8","LS_Misc_16"}, -- S
	['fixtures_bathroom_01_1'] = {"LS_Misc_1","LS_Misc_9","LS_Misc_17"}, -- E
	['fixtures_bathroom_01_2'] = {"LS_Misc_2","LS_Misc_10","LS_Misc_18"}, -- W
	['fixtures_bathroom_01_3'] = {"LS_Misc_3","LS_Misc_11","LS_Misc_19"}, -- N
	-- low
	['fixtures_bathroom_01_4'] = {"LS_Misc_4","LS_Misc_12","LS_Misc_20"}, -- S
	['fixtures_bathroom_01_5'] = {"LS_Misc_5","LS_Misc_13","LS_Misc_21"}, -- E
	['fixtures_bathroom_01_6'] = {"LS_Misc_6","LS_Misc_14","LS_Misc_22"}, -- W
	['fixtures_bathroom_01_7'] = {"LS_Misc_7","LS_Misc_15","LS_Misc_23"}, -- N
	-- hanging
	['fixtures_bathroom_01_8'] = {"LS_Misc_1_36","LS_Misc_1_40","LS_Misc_1_44"}, -- S
	['fixtures_bathroom_01_9'] = {"LS_Misc_1_37","LS_Misc_1_41","LS_Misc_1_45"}, -- E
	['fixtures_bathroom_01_10'] = {"LS_Misc_1_38","LS_Misc_1_42","LS_Misc_1_46"}, -- W
	['fixtures_bathroom_01_11'] = {"LS_Misc_1_39","LS_Misc_1_43","LS_Misc_1_47"}, -- N
	-- chemical
	['fixtures_bathroom_02_4'] = {"LS_Misc_1_24","LS_Misc_1_28","LS_Misc_1_32"}, -- S
	['fixtures_bathroom_02_5'] = {"LS_Misc_1_25","LS_Misc_1_29","LS_Misc_1_33"}, -- E
	['fixtures_bathroom_02_14'] = {"LS_Misc_1_26","LS_Misc_1_30","LS_Misc_1_34"}, -- W
	['fixtures_bathroom_02_15'] = {"LS_Misc_1_27","LS_Misc_1_31","LS_Misc_1_35"}, -- N
	-- wooden
	['fixtures_bathroom_02_25'] = {"LS_Misc_48","LS_Misc_52","LS_Misc_56"}, -- S
	['fixtures_bathroom_02_24'] = {"LS_Misc_49","LS_Misc_53","LS_Misc_57"}, -- E
	['fixtures_bathroom_02_26'] = {"LS_Misc_50","LS_Misc_54","LS_Misc_58"}, -- W
	['fixtures_bathroom_02_27'] = {"LS_Misc_51","LS_Misc_55","LS_Misc_59"}, -- N
}

LSHygiene.DS.Bathtubs = {
	-- large deluxe
	['fixtures_bathroom_01_25'] = {"LS_Misc_2_2","LS_Misc_2_10","LS_Misc_2_18","LS_Misc_2_3","LS_Misc_2_11","LS_Misc_2_19"}, -- S
	['fixtures_bathroom_01_26'] = {"LS_Misc_2_0","LS_Misc_2_8","LS_Misc_2_16","LS_Misc_2_1","LS_Misc_2_9","LS_Misc_2_17"}, -- E
	['fixtures_bathroom_01_55'] = {"LS_Misc_1_4","LS_Misc_2_12","LS_Misc_2_20","LS_Misc_2_5","LS_Misc_2_13","LS_Misc_2_21"}, -- W
	['fixtures_bathroom_01_52'] = {"LS_Misc_2_6","LS_Misc_2_14","LS_Misc_2_22","LS_Misc_2_7","LS_Misc_2_15","LS_Misc_2_23"}, -- N
}

LSHygiene.DS.Showers = {
	-- deluxe
	['fixtures_bathroom_01_32'] = {"LS_Misc_1_4","LS_Misc_1_12","LS_Misc_1_20"}, -- S
	['fixtures_bathroom_01_33'] = {"LS_Misc_1_5","LS_Misc_1_13","LS_Misc_1_21"}, -- E
	-- wall
	['fixtures_bathroom_01_30'] = {"LS_Misc_1_2","LS_Misc_1_10","LS_Misc_1_18"}, -- S
	['fixtures_bathroom_01_31'] = {"LS_Misc_1_3","LS_Misc_1_11","LS_Misc_1_19"}, -- E
	['fixtures_bathroom_01_23'] = {"LS_Misc_1_1","LS_Misc_1_9","LS_Misc_1_17"}, -- W
	['fixtures_bathroom_01_22'] = {"LS_Misc_1_0","LS_Misc_1_8","LS_Misc_1_16"}, -- N
}

LSHygiene.DS.getFromSpriteName = function(spriteName)
	if not spriteName then return false; end
	for n=1,#ds_categories do
		local cat = ds_categories[n]
		if LSHygiene.DS[cat] and LSHygiene.DS[cat][spriteName] then return LSHygiene.DS[cat][spriteName]; end
	end
	return false
end