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

--Disco Lights
DiscoBallProps = {}

DiscoBallProps.default = function(stage)
	if stage == 1 then return 0.8, 0.8, 0.8, 3;
	elseif stage == 2 then return 0, 0.8, 1, 2;
	elseif stage == 3 then return 0.8, 0.8, 0.8, 3; end
	return 1, 0, 1, 2
end

DiscoBallProps.circles = function(stage)
	if stage == 1 then return 1, 0.65, 0, 2;
	elseif stage == 2 then return 1, 1, 0, 1;
	elseif stage == 3 then return 0, 1, 0, 2; end
	return 1, 0, 0, 1
end

DiscoBallProps.spots = function(stage)
	if stage == 1 then return 1, 0.41, 0.7, 2;
	elseif stage == 2 then return 0.5, 0, 0, 1;
	elseif stage == 3 then return 0, 0.75, 1, 2; end
	return 1, 0.08, 0.57, 1
end

DiscoBallProps.rainbow = function(stage)
	if stage == 1 then return 0.56, 0, 1, 2;
	elseif stage == 2 then return 1, 1, 0, 1;
	elseif stage == 3 then return 1, 0.5, 0, 2; end
	return 0.3, 0, 0.5, 1
end

DiscoBallProps.gold = function(stage)
	if stage == 1 then return 1, 0.84, 0, 2;
	elseif stage == 2 then return 1, 0.27, 0, 1;
	elseif stage == 3 then return 1, 0.84, 0, 2; end
	return 1, 0.27, 0, 1
end

DiscoBallProps.default = function(stage)
	if stage == 1 then return 0.8, 0.8, 0.8, 3;
	elseif stage == 2 then return 0, 0.8, 1, 2;
	elseif stage == 3 then return 0.8, 0.8, 0.8, 3; end
	return 1, 0, 1, 2
end

DiscoBallProps.valentine = function(stage)
	if stage == 1 then return 0.8, 0, 0.43, 3;
	elseif stage == 2 then return 0.8, 0, 0.43, 2;
	elseif stage == 3 then return 0.8, 0, 0.43, 3; end
	return 0.8, 0, 0.43, 2
end

DiscoBallProps.random = function(stage)
	local c = 1
	if (stage == 1) or (stage == 3) then c = 2; end
	local t = {}
	for i=1, 3 do
		local argRdm = ZombRand(200)+1
		if (i == 2) and (t[1] > 100) then argRdm = ZombRand(50)+1;
		elseif (i == 3) and (t[2] > 100) then argRdm = ZombRand(50)+1; end
		argRdm = argRdm/255
		table.insert(t, argRdm)
	end
	return t[1], t[2], t[3], c
end


--mode is a string
DiscoBallProps.get = function(mode, stage)
	local r, g, b, c = DiscoBallProps[mode](stage)
	return r, g, b, c
end