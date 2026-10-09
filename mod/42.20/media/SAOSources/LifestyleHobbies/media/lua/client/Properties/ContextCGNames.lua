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

-- Context Menu WO CN GN

return {
	{customname="Shower",groupname="Deluxe",contextname=ShowerContextMenu,multiple="single"},
	{customname="Shower",groupname="none",contextname=ShowerContextMenu,multiple="single"},
	{customname="Bath",groupname="Large Deluxe",contextname=BathContextMenu,multiple="single"},
	{customname="Toilet",groupname="Fancy",contextname=ToiletContextMenu,multiple="single"},
	{customname="Toilet",groupname="Low",contextname=ToiletContextMenu,multiple="single"},
	{customname="Toilet",groupname="Hanging",contextname=ToiletContextMenu,multiple="single"},
	{customname="Toilet",groupname="Chemical",contextname=ToiletContextMenu,multiple="single"},
	{customname="Toilet",groupname="Wooden",contextname=ToiletContextMenu,multiple="single"},
	{customname="Cabinet",groupname="Medicine",contextname=CabinetContextMenu,multiple="Sink"},
	{customname="Mirror",groupname="none",contextname=MirrorContextMenu,multiple="Sink"},
	{customname="Chair",groupname="none",contextname=SitActionMenu,multiple="single"},
	{customname="Couch",groupname="none",contextname=SitActionMenu,multiple="single"},
	{customname="Stool",groupname="none",contextname=SitActionMenu,multiple="single"},
}
