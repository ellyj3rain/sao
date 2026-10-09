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

GTLSCheck = 1

function LS_CheckGT()
	local dayLengthinMinutes = getSandboxOptions():getDayLengthMinutes()
	if not dayLengthinMinutes then print("LS_CheckGT - failed to return dayLength"); return; end
	--print("LS_CheckGT - day length is "..dayLengthinMinutes)
	GTLSCheck = dayLengthinMinutes/120
	--print("LS_CheckGT - GTLS is "..GTLSCheck)

end


Events.OnInitGlobalModData.Add(LS_CheckGT)