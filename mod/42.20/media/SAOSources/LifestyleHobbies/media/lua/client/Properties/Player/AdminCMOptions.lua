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

--ADMIN CM Properties

return {
	{subMenu=subMenuExpressions,text="ContextMenu_LSDebug_TDSuffer",localF=onAdminTest,arg1=false},
	{subMenu=subMenuExpressions,text="ContextMenu_LSDebug_Applause",localF=onAdminTestB,arg1=false},
	{subMenu=subMenuExpressions,text="ContextMenu_LSDebug_Boo",localF=onAdminTestC,arg1=false},
	{subMenu=subMenuExpressions,text="ContextMenu_LSDebug_TestAnim",localF=onAdminTestI,arg1=false},
	{subMenu=subMenuOther,text="ContextMenu_LSDebug_Litter",localF=onAdminTestD,arg1="grime"},
	{subMenu=subMenuOther,text="ContextMenu_LSDebug_LitterB",localF=onAdminTestD,arg1="blood"},
	{subMenu=subMenuOther,text="ContextMenu_LSDebug_VisionCheck",localF=onAdminTestF,arg1=false},
	{subMenu=subMenuOther,text="ContextMenu_LSDebug_ResetSKCD",localF=onAdminTestH,arg1=false},
	{subMenu=subMenuNeeds,text="ContextMenu_LSDebug_IncreaseBathroomNeed",localF=onAdminTestE,arg1=false},
	{subMenu=subMenuNeeds,text="ContextMenu_LSDebug_IncreaseHygieneNeed",localF=onAdminTestG,arg1=false},

}
