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

function LSInv.getInventionData(inv)
	local data = inv and inv.getModData and inv:getModData()
	return data and data.movableData and data.movableData['inventionData']
end

function LSInv.hasBattery(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and data['fuelBattery'] and data['hasBattery']
end

function LSInv.isBusy(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and data['running']
end

function LSInv.isSelfPowered(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and data['selfPowered']
end

function LSInv.InvReqWater(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and data['reqWater']
end

function LSInv.InvReqPower(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and data['reqPower']
end

function LSInv.InvHasWater(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and (not data['reqWater'] or data['noPlumbing'] or data['waterCheat'] or (instanceof(inv, "IsoObject") and inv:hasWater() and inv:getFluidAmount() >= data['waterUsage'][1]))
end

function LSInv.InvHasPower(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and (not data['reqPower'] or data['selfPowered'] or data['powerCheat'] or (instanceof(inv, "IsoObject") and LSUtil.sqrHasEnergy(inv:getSquare())))
end

function LSInv.doCooldown(inv, invData, transmit)
	local data = invData or LSInv.getInventionData(inv)
	if not data or data['noCooldown'] or not data['cooldownTime'] or data['cooldownTime'] <= 0 then return; end
	local hour = getGameTime():getWorldAgeHours()
	data['cooldown'] = hour+data['cooldownTime']
	if transmit then LSSync.transmit(inv); end
end

function LSInv.InvHasFuel(inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	return data and (not data['fuelUses'] or data['fuelUses'] > 0 or data['fuelInfinite'] or data['fuelCheat'])
end

function LSInv.drainFuel(inv, invData, transmit)
	local data = invData or LSInv.getInventionData(inv)
	if not data or data['fuelInfinite'] or not data['fuelUses'] or data['fuelUses'] <= 0 then return; end
	data['fuelUses'] = 0
	if transmit then LSSync.transmit(inv); end
end

function LSInv.useFuel(inv, uses, invData, transmit, extra)
	LSUtil.debugPrint("LSInv.useFuel, start")
	local data = invData or LSInv.getInventionData(inv)
	if not data or data['fuelInfinite'] or not data['fuelUses'] or data['fuelUses'] <= 0 then LSUtil.debugPrint("LSInv.useFuel, fail"); return; end
	if data['recirculator'] and LSUtil.rdm_inst:random(10) <= 2 then
		LSUtil.debugPrint("LSInv.useFuel, recirculator save")
		return
		--LSUtil.debugPrint("---- LS - LSUtil.useInventionItem, for item: "..itemType..", no fuel used - recirculator save".." ----")
	end
	local consumption = data['fuelConsumption']
	if extra then consumption = consumption+extra; end
	data['fuelUses'] = math.max(0,math.floor(data['fuelUses']-(uses*consumption)))
	LSUtil.debugPrint("LSInv.useFuel, used fuel")
	if transmit then LSSync.transmit(inv); end
end

function LSInv.breakInv(character, inv, invData)
	local data = invData or LSInv.getInventionData(inv)
	if not data then return; end
	if data['cooldownTime'] and not data['noCooldown'] then LSInv.doCooldown(inv, data, nil); end
	if data['fuelUses'] and not data['fuelInfinite'] then LSInv.drainFuel(inv, data, nil); end
	if instanceof(inv, "IsoObject") then
		data['isBroken'] = true
		LSSync.transmit(inv)
	else
		LSUtil.removeItemOnChar(character, inv)
		LSSync.transmit(inv, character, nil, {['Condition']=0,['setBroken']={'isBroken',true}})
	end
end

function LSInv.rollBreakObj(character, inv, invData, invName)
	if not invData['durability'] or invData['neverBreak'] or invData['durability'][1] == 0 then return false; end
	if invData['durability'][2] and invData['durability'][2] > 0 and LSUtil.rdm_inst:random(100) <= invData['durability'][2] then -- minor fail roll
		LSUtil.debugPrint("LSInv.rollBreakObj, for inv: "..invName..", minor failure trigger")
		if LSInv['OnFail'..invName] then LSInv['OnFail'..invName](character, inv, invData); else LSInv.breakInv(character, inv, invData); end
		return "minor"
	elseif LSUtil.rdm_inst:random(100) <= invData['durability'][1] then -- crit fail roll (or minor fail if it lacks a crit fail)
		LSUtil.debugPrint("LSInv.rollBreakObj, for inv: "..invName..", critical failure trigger")
		local failFunc = LSInv['OnCritFail'..invName] or LSInv['OnFail'..invName]
		if failFunc then failFunc(character, inv, invData); else LSInv.breakInv(character, inv, invData); end
		return "crit"
	end
	return false
end

---------- research

function LSInv.getResearchLevel(improvData, improvName, exclude, level)
	local researchLevels, totalResearch = 0, 0
	for k, v in pairs(improvData) do
		if (not exclude or tostring(k) ~= exclude) and (not improvName or tostring(k) == improvName) then
			researchLevels = researchLevels+v[1]
			totalResearch = totalResearch+v[2]
			if improvName then break; end
		end
	end
	local percentCompleted = 0
	if researchLevels >= totalResearch then return 10, 10; end
	if researchLevels > 0 then percentCompleted = math.floor((researchLevels*10)/totalResearch); end -- returns 1, 2, 3 ... 10
	percentCompleted = math.min(10, math.max(1, percentCompleted))
	if improvName and level then
		level = researchLevels+level
		if level >= totalResearch then return percentCompleted, 10; end
		local levelPercent = math.floor((level*10)/totalResearch)
		levelPercent = math.min(10, math.max(1, levelPercent))
		return percentCompleted, levelPercent
	end
	return percentCompleted
end

---------- workbench

function LSInv.getNewID()
	return tostring(ZombRand(11).."-"..ZombRand(11).."-"..ZombRand(11).."-"..ZombRand(11))
end

function LSInv.getWorkbenchEmptySprite(spriteName)
	local t = {
		LS_Inventions_10 = "LS_Inventions_4",
		LS_Inventions_11 = "LS_Inventions_5",
	}
	return t[spriteName]
end
