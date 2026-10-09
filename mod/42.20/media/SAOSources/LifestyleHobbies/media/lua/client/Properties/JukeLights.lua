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

--Juke Lights
JukeboxProps = {}

JukeboxProps.overlay = function(stage)
	if stage == 1 then return 0, 1, 0, 0, 0.3, 0;
	elseif stage == 3 then return 0, 0, 1, 0, 0, 0.3;
	elseif stage == 5 then return 1, 0, 0, 0.3, 0, 0; end
	return false, false, false, false, false, false;
end

JukeboxProps.get = function(style, stage)
	local rgbTable = {}
	rgbTable.objR, rgbTable.objG, rgbTable.objB, rgbTable.lightR, rgbTable.lightG, rgbTable.lightB = JukeboxProps[style](stage)
	return rgbTable
end