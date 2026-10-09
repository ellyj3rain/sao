

local getNewOuthouseTable = function(sandboxOption) -- creates area table, resets when value changes
	return {}
end

local function LSgetExpectationTime(sandboxOption)
	local eTime = 1
	if sandboxOption then
		local n1, n2
		if sandboxOption==1 then n1,n2=1,4; elseif sandboxOption==2 then n1,n2=4,13; elseif sandboxOption==3 then n1,n2=14,31; elseif sandboxOption==4 then n1,n2=30,91; end
		eTime = ZombRand(n1,n2)
	end
	--print("LSgetExpectationTime returning.. "..eTime.." days")
	return eTime
end

local function LSloadSOData(lsSOData, data, dataSO, sandboxOption, func)
	if data and (not lsSOData[data]) then lsSOData[data] = func(sandboxOption); end
	if dataSO and (not lsSOData[dataSO]) then lsSOData[dataSO] = sandboxOption; end
	if lsSOData[dataSO] ~= sandboxOption then lsSOData[dataSO] = sandboxOption; lsSOData[data] = func(sandboxOption); end
end

function LSgetSandboxOptions(lsSOData)
	LSloadSOData(lsSOData, "HNE", "HNESO", SandboxVars.LSHygiene.HygieneNeedExpectationTime, LSgetExpectationTime)
	LSloadSOData(lsSOData, "CNE", "CNESO", SandboxVars.LSHygiene.CleaningExpectationTime, LSgetExpectationTime)
	LSloadSOData(lsSOData, "OUTHOUSEAREAS", "OUTHOUSEAREASSO", SandboxVars.LSHygiene.OuthouseRange, getNewOuthouseTable)
end
