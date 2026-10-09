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

LSInv = LSInv or {}

------------ 

LSInv.doDataTransmit = function(inv, itemKeyData)
	if instanceof(inv, "IsoObject") then
		LSSync.transmit(inv)
	elseif instanceof(inv, "InventoryItem") and itemKeyData then
		LSSync.syncItemVal(inv, itemKeyData, inv:getType() or "")
	end
end

LSInv.updateInventionStat = function(inv, data, stat, customName, tN, transmit)
	if not data['inventionData'][stat] then return; end
	local statImprovement = data['improvementData'][stat] and data['improvementData'][stat][1]
	local ogStat --!
	if statImprovement and statImprovement > 0 then
		local improvementDef = LSUtil.deepCopy(LSInventionDefs.Improvements[customName][stat])
		if improvementDef.repeatable then ogStat = improvementDef.repeatable[statImprovement];
		elseif improvementDef.result then ogStat = improvementDef.result; end
	else --!
		ogStat = LSUtil.deepCopy(LSInventionDefs.Items[customName][stat]) --!
	end
	--local update --!
	if tN then
		if data['inventionData'][stat][tN] ~= ogStat[tN] then data['inventionData'][stat][tN] = ogStat[tN]; end --!
	else
		if data['inventionData'][stat] ~= ogStat then data['inventionData'][stat] = ogStat; end --!
	end
	--if not update then return; end --!
	if stat == "efficiency" then
		for n=1, #data['inventionData']['efficiencyBase'] do
			data['inventionData']['efficiencyMult'][n] = data['inventionData']['efficiencyBase'][n]*data['inventionData']['efficiency']
		end
	end	
	if transmit then LSInv.doDataTransmit(inv, data['inventionData']); end
end

LSInv.updateInventionScripts = function(inv, invData, customName, transmit)
	local scriptArgs = invData and customName and LSInventionDefs.ItemScript[customName]
	if not scriptArgs then return false; end
	local reqChange
	for k, v in pairs(scriptArgs) do
		if reqChange then break; end
		if invData[k] then
			if type(v) == "table" then
				for n=1,#v do
					if v[n] then
						local getFunc = inv['get'..v[n]]
						if getFunc and getFunc(inv) ~= invData[k][n] then reqChange = true; break; end
					end
				end
			else
				local getFunc = inv['get'..v]
				if getFunc and getFunc(inv) ~= invData[k] then reqChange = true; break; end
			end
		end
	end
	if transmit and reqChange then LSInv.doDataTransmit(inv, invData); end
	return reqChange
end