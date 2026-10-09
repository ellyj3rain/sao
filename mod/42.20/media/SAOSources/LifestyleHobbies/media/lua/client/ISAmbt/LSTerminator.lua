
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function updateHealth(player, ambtOgHth, roll)
	local currentHealth, totalH, ogHth = player:getHealth(), false, ambtOgHth
	if not ogHth then ogHth = currentHealth; end
	if currentHealth < ogHth then totalH = ogHth-currentHealth; end
	if totalH and (roll > 18) then LSUtil.addGeneralHealth(player, totalH, false); if isClient() then player:getBodyDamage():AddGeneralHealth(totalH); end; end
	ogHth = player:getHealth()
	return ogHth
end

local function updateEndurance(player, ambtOgEnd)
	local currentEnd, totalE, ogEnd = LSUtil.getCharacterMood(player, "Endurance"), false, ambtOgEnd
	if not ogEnd then ogEnd = currentEnd; end			
	if currentEnd > ogEnd then totalE = currentEnd+((currentEnd-ogEnd)*0.2);
	elseif currentEnd < ogEnd then totalE = currentEnd+((ogEnd-currentEnd)*0.2); end
	if totalE then
		if totalE > 1 then totalE = 1; end
		LSUtil.changeCharacterMood(player, "Endurance", totalE, false, true)
		ogEnd = totalE
	end
	return ogEnd
end

local function updateBleeding(player, health)
	for i=0, player:getBodyDamage():getBodyParts():size()-1 do
		local bodyPart = player:getBodyDamage():getBodyParts():get(i)
		if (bodyPart:bleeding()) and (not bodyPart:IsBleedingStemmed()) then
			if bodyPart:getType() == BodyPartType.Neck then health = health*5; end
			bodyPart:AddHealth(health)
		end
	end
end

local function stopBurn(player,mp)
	if mp then player:sendStopBurning(); return; end
	player:StopBurning()
end

local function updateFire(player, roll, target)
	if player:getFireKillRate() ~= target then player:setFireKillRate(target); end --default is about 0.0038
	if roll and player:isOnFire() and (roll > 16) then
		stopBurn(player,isClient())
	end
end

local function eventIsValid(player)
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

local LSTerminatorEvent
local function LSTerminatorEventFunc()
		local player, ambt = getSpecificPlayer(0), false
		if eventIsValid(player) then
			ambt = player:getModData().Ambitions['LSTerminator']
			if ambt and ambt.completed then
				if (player:getBodyDamage():getNumPartsBleeding() > 0) then updateBleeding(player, 0.05); end
				if not ambt.ogFireKR then ambt.ogFireKR = player:getFireKillRate(); end
				if ambt.isActive then
					local roll, fireTotal = ZombRand(20)+1, ambt.ogFireKR/3
					ambt.ogEnd = updateEndurance(player, ambt.ogEnd)
					ambt.ogHth = updateHealth(player, ambt.ogHth, roll)
					updateFire(player, roll, fireTotal)
				else
					updateFire(player, false, ambt.ogFireKR)
				end
			end
		end
	if (not ambt) or (not ambt.completed) then LSTerminatorEvent = false; Events.EveryOneMinute.Remove(LSTerminatorEventFunc); end
end

local function LSAmbtActiveIncomplete(player, ambt)
	ambt.reset, ambt.goal2progress = true, true
	if not player:isAsleep() then
		if LSUtil.getCharacterMood(player, "Endurance") > 0.35 then LSUtil.changeCharacterMood(player, "Endurance", 0.35, false, true); end
		if not ambt.ogKills then ambt.ogKills = player:getZombieKills(); end
		ambt.goal1progress = math.floor(player:getZombieKills() - ambt.ogKills)
		if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); end
	end
end

LSAmbtMng.LSTerminator = function(player, ambt)
	if ambt.completed then -- ambition was completed
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --has active bonuses
		--LSAmbtPassiveComplete() --has passive bonuses
		if not LSTerminatorEvent then LSTerminatorEvent = true; Events.EveryOneMinute.Add(LSTerminatorEventFunc); end
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
