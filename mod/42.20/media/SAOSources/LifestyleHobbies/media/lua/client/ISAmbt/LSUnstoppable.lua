
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function getInjuryType()
	return {"Bite","Bleeding","Burn","Cut","DeepWound","Fracture","Scratch"}
end

local function checkDamageCompleted(player, ambt, bodyPart)
	local t = getInjuryType()
	for n=1, #t do
		local injuryType = t[n]
		local healTime = bodyPart["get"..injuryType.."Time"](bodyPart)
		local bodyPartName = tostring(bodyPart:getType())
		if not ambt[bodyPartName] then ambt[bodyPartName] = {}; end
		if healTime and (healTime > 0) then
			if (not ambt[bodyPartName][injuryType.."ogTime"]) or (ambt[bodyPartName][injuryType.."ogTime"] < healTime) then 
				ambt[bodyPartName][injuryType.."ogTime"] = healTime
				local newHT = math.floor(healTime*0.75)
				bodyPart["set"..injuryType.."Time"](newHT)
			end
		else
			ambt[bodyPartName][injuryType.."ogTime"] = nil
		end
	end
end

local function hasActiveBonus(player, ambt, bodyPart)
	local activeBonus
	local bodyPartName = tostring(bodyPart:getType())
	local playerData = player:getModData()
	if ambt.isActive and (not bodyPart:IsInfected()) and ((not playerData.LSCooldowns["unstoppable"]) or (playerData.LSCooldowns["unstoppable"] <= 0)) then
		playerData.LSCooldowns["unstoppable"] = 24
		if ZombRand(10) == 0 then
			bodyPart:RestoreToFullHealth()
			ambt[bodyPartName] = nil
			activeBonus = true
		end
	end
	return activeBonus
end

local function getInjuries(player, ambt)
	local bodyParts = player:getBodyDamage():getBodyParts()
    for i=0,bodyParts:size()-1 do
        local bodyPart = bodyParts:get(i)
		if bodyPart:HasInjury() and (not hasActiveBonus(player, ambt, bodyPart)) then
			checkDamageCompleted(player, ambt, bodyPart)
		else
			local bodyPartName = tostring(bodyPart:getType())
			ambt[bodyPartName] = nil
		end
	end
end

local function LSAmbtComplete(player, ambt)
	getInjuries(player, ambt)
end

local function getInjuryTypeIncomplete()
	return {"Null","Scratch","Cut","DeepWound","Burn","Fracture"}
end

local function getResult(bodyPart)
    local result = {false, false, false, false, false, false}
	if not bodyPart:HasInjury() then return result; end

	result[1] = true
	local t = getInjuryTypeIncomplete()
	for n=1, #t do
		if (n > 1) then
			local injuryType = t[n]
			local healTime = bodyPart["get"..injuryType.."Time"](bodyPart)
			if healTime and (healTime > 0) then result[n] = true; end
		end
	end
	return result
end

local function checkDamage(ambt, bodyPart)
	local bodyPartName = tostring(bodyPart:getType())
    local result = getResult(bodyPart)
	if not ambt[bodyPartName] then ambt[bodyPartName] = result; return; end
	for n=1, #result do
		if result[n] and (result[n] ~= ambt[bodyPartName][n]) then
			ambt['goal'..n..'progress'] = math.floor(ambt['goal'..n..'progress']+1)
		end
	end
	ambt[bodyPartName] = result
end

local function checkInjuries(player, ambt)
	local result, bodyParts = 0, player:getBodyDamage():getBodyParts()
    for i=1,bodyParts:size() do
        local bodyPart = bodyParts:get(i-1)
		checkDamage(ambt, bodyPart)
	end
end

local function LSAmbtActiveIncomplete(player, ambt)
	if not ambt.reset then ambt.reset = true; end
	if not player:isAsleep() then
		local completed = true
		for n=1, 6 do
			if not ambt['goal'..n..'progress'] then ambt['goal'..n..'progress'] = 0; end
			if ambt['goal'..n..'progress'] < ambt['goal'..n] then completed = false; end
		end
		if completed then LSAmbtMng.doComplete(player, ambt); return; end
		checkInjuries(player, ambt)
	end
end

local function clearBPData(player, ambt)
	local bodyParts = player:getBodyDamage():getBodyParts()
    for i=1,bodyParts:size() do
        local bodyPart = bodyParts:get(i-1)
		local bodyPartName = tostring(bodyPart:getType())
		if ambt[bodyPartName] then ambt[bodyPartName] = nil; end
	end
	ambt.clearBP = true
end

LSAmbtMng.LSUnstoppable = function(player, ambt)
	if ambt.completed then -- ambition was completed
		if not ambt.clearBP then clearBPData(player, ambt); return; end
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --has active bonuses
		LSAmbtComplete(player, ambt)
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
