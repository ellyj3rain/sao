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

-- Context Menu S

return {
--piano stool
	{spritename="LS_Stools_0",secondspritename="LS_Stools_1",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Stools_1",secondspritename="LS_Stools_0",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Stools_2",secondspritename="LS_Stools_3",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Stools_3",secondspritename="LS_Stools_2",contextname=LSSitCheckContextMenu,multiple="single"},
--fancy toilets
	{spritename="LS_Misc_25",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_33",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_41",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_24",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_32",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_40",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--low toilets
	{spritename="LS_Misc_29",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_37",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_45",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_28",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_36",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Misc_44",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	--[[
--Red Comfy Chair
	{spritename="LS_Chairs_13",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_15",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Green Comfy Chair
	{spritename="LS_Chairs_37",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_36",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Blue Rattan Chair
	{spritename="LS_Chairs_9",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_8",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Purple Rattan Chair
	{spritename="LS_Chairs_33",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_32",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Fancy White Chair
	{spritename="LS_Chairs_49",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_48",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Modern Red Chair
	{spritename="LS_Chairs_53",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_52",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Black Office Chair
	{spritename="LS_Chairs_57",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_56",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Grey Chair
	{spritename="LS_Chairs_61",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_60",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Red Comfy Couch
	{spritename="LS_Chairs_16",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_19",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_18",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_17",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Green Comfy Couch
	{spritename="LS_Chairs_40",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_43",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_42",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_41",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Blue Rattan Couch
	{spritename="LS_Chairs_2",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_3",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_0",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_1",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Purple Rattan Couch
	{spritename="LS_Chairs_26",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_27",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_24",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs_25",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--White Lazy Couch
	{spritename="LS_Chairs2_2",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_3",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_0",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_1",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Brown Lazy Couch
	{spritename="LS_Chairs2_16",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_19",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_18",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_17",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Yellow Modern Couch
	{spritename="LS_Chairs2_26",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_27",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_24",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_25",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Blue Comfy Couch
	{spritename="LS_Chairs2_42",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_43",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_40",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_41",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Light Blue Couch
	{spritename="LS_Chairs2_58",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_59",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_56",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_57",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--White Lazy Chair
	{spritename="LS_Chairs2_9",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_8",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Brown Lazy Chair
	{spritename="LS_Chairs2_13",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_12",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Blue Comfy Chair
	{spritename="LS_Chairs2_37",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_36",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Yellow Modern Chair
	{spritename="LS_Chairs2_33",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_32",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Light Blue Chair
	{spritename="LS_Chairs2_53",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_52",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
--Black Fancy Chair
	{spritename="LS_Chairs2_49",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	{spritename="LS_Chairs2_48",secondspritename="none",contextname=LSSitCheckContextMenu,multiple="single"},
	]]--
}
