
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player toggles this ambition off mid-progress
--ambt.offBhv - if true then ambtMng will call your ambition when updating even if not passive and not isActive, useful to add behavior when ambition was deactivated by the player
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local LSAMBTTPEvent = {
	false,--pu
	false,--zd, ws
}

local function eventIsValid(player, target, damage)
	if player and instanceof(player, "IsoPlayer") and player:hasModData() and (not player:isDead()) and (not player:isDoShove()) and player:isSneaking() and
	player:getModData().Ambitions and damage and target and (not target:isDead()) then return true; end
	return false
end

local function getOverDMG(player, damage)
	local multi = 0
	if player:isSneaking() then multi = 0.25; end
	return damage*multi
end

local function playerHasWT(player, weapon)
	return LSUtil.isWeaponType(player, weapon, "HANDGUN")
end

local LSTPlastZomb

local function LSTPonHit(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) then
		local ambt = attacker:getModData().Ambitions['LSTheProfessional']
		if ambt and ambt.isActive then
			if not ambt.completed then 
				if playerHasWT(attacker, weapon) then LSTPlastZomb = tostring(target); end
				return
			end
			local overDmg = getOverDMG(attacker, damage)
			if playerHasWT(attacker, weapon) and (overDmg > 0) and (target:getHealth() > 0) then
				local newHealth = target:getHealth()-overDmg
				if newHealth < 0 then target:Kill(attacker); return; end
				target:setHealth(newHealth)
			end
		else
			LSAMBTTPEvent[2] = false
			Events.OnZombieDead.Remove(LSTPOnZDead)
			Events.OnWeaponHitCharacter.Remove(LSTPonHit)
		end
	end
end

local function updateZombKills()
	local player = getSpecificPlayer(0)
	local ambt = player:getModData().Ambitions['LSTheProfessional']
	if (not ambt) or (ambt.completed) then Events.OnZombieDead.Remove(LSTPOnZDead); return; end
	if not ambt.goal1progress then ambt.goal1progress = 0; end
	ambt.goal1progress = math.floor(ambt.goal1progress+1)
end

local function LSTPOnZDead(zombie)
	if zombie and LSTPlastZomb and (LSTPlastZomb == tostring(zombie)) then
		updateZombKills()
		LSTPlastZomb = nil
	end
end

local function LSTPWPRemove(player, dataName)
	local data = player:getModData()[dataName]
	if data and data[1] then
		data[1]:setConditionLowerChance(data[2])
		data[1]:setReloadTime(data[5])
		data[1]:setCriticalChance(data[6])
	end
	player:getModData()[dataName] = nil
end

local function LSTPWPCheck(player, data, weapon, isActive)
	local dif, old = false, {0, weapon:getConditionLowerChance(), false, false, weapon:getReloadTime(), weapon:getCriticalChance()}
	if data and data[1] then
		if data[1] ~= weapon then dif = true; end
		if data[5] and data[6] and (not isActive) then dif = true; end
		if not dif then
			for n=1, 6 do
				if n > 2 and (not isActive) then break;
				elseif (n > 1) and old[n] and (data[n] == old[n]) then dif = true; break; end
			end
		end
	else
		dif = true
	end
	if not dif then return; end
	--if data and data[1] then old[2] = data[2]; end
	LSTPWPRemove(player, 'LSTPWPC')
	old = {0, weapon:getConditionLowerChance(), false, false, weapon:getReloadTime(), weapon:getCriticalChance()}
	player:getModData().LSTPWPC = {weapon, old[2], false, false, old[5], old[6]}
	
	weapon:setConditionLowerChance(old[2]*2)
	if isActive then
		weapon:setReloadTime(old[5]*0.6)
		weapon:setCriticalChance(old[6]*2)
	end
end

local function disableEventsForce(player)
	Events.OnPlayerUpdate.Remove(LSTPOnPlayerUpdate)
	Events.OnWeaponHitCharacter.Remove(LSTPonHit)
	Events.OnZombieDead.Remove(LSTPOnZDead)
	LSTPWPRemove(player, 'LSTPWPC')
	LSAMBTTPEvent[1], LSAMBTTPEvent[2] = false, false; 
end

local function conditionsValid(player)
	if player:isAiming() and player:getModData().Ambitions['LSTheProfessional'] and
	player:getModData().Ambitions['LSTheProfessional'].completed and
	(not player:getModData().LSTPWPC) then return true; end
	return false
end

local function conditionsNotValid(player)
	if (not player:isAiming()) and player:getModData().LSTPWPC then return true; end
	return false
end

local function LSTPOnPlayerUpdate(player)
	if (not LSAMBTTPEvent[1]) or (not player:getModData().Ambitions['LSTheProfessional']) or (not player:getModData().Ambitions['LSTheProfessional'].isActive) or (not player:getModData().Ambitions['LSTheProfessional'].completed) then
		disableEventsForce(player)
		return
	end
	if conditionsValid(player) and playerHasWT(player, player:getPrimaryHandItem()) then
		LSTPWPCheck(player, player:getModData().LSTPWPC, player:getPrimaryHandItem(), player:getModData().Ambitions['LSTheProfessional'].isActive)
	elseif (conditionsNotValid(player)) or (not player:getModData().Ambitions['LSTheProfessional']) or (not player:getModData().Ambitions['LSTheProfessional'].completed) then
		LSTPWPRemove(player, 'LSTPWPC')
	end
end

local function LSAmbtComplete(player, ambt)
	if player:isAsleep() then return; end
	if playerHasWT(player, player:getPrimaryHandItem()) then LSTPWPCheck(player, player:getModData().LSTPWPC, player:getPrimaryHandItem(), ambt.isActive);
	else LSTPWPRemove(player, 'LSTPWPC'); end
	if ambt.isActive and (not LSAMBTTPEvent[1]) then LSAMBTTPEvent[1] = true; Events.OnPlayerUpdate.Add(LSTPOnPlayerUpdate); end	
	if not LSAMBTTPEvent[2] then LSAMBTTPEvent[2] = true; Events.OnWeaponHitCharacter.Add(LSTPonHit); end
end

local function LSAmbtActiveIncomplete(player, ambt)
	-- add conditions to add/remove progress
	-- apply buffs/debuffs if ambition has any while active and incomplete
	if player:isAsleep() then return; end
	if not ambt.offBhv then ambt.offBhv = true; end
	if not ambt.goal1progress then ambt.goal1progress = 0; end
	if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); return; end
	if not LSAMBTTPEvent[2] then LSAMBTTPEvent[2] = true; Events.OnWeaponHitCharacter.Add(LSTPonHit); Events.OnZombieDead.Add(LSTPOnZDead); end
end

local function LSAmbtIsHidden(player, ambt)
	-- if your ambition starts hidden, add conditions to unlock
	if player:getPerkLevel(Perks.Aiming) < 6 then return; end
	if player:getModData().Ambitions['LSCommando'].completed or
	player:getModData().Ambitions['LSCommando'].isActive then return; end
	if not ambt.delayUnlock then ambt.delayUnlock = true; return; end
	LSAmbtMng.doUnlock(player, ambt)
end

local function disableEventsCheck(player, ambt)
	if LSAMBTTPEvent[1] and ((not ambt.isActive) or (not ambt.completed)) then 
		Events.OnPlayerUpdate.Remove(LSTPOnPlayerUpdate);
		LSTPWPRemove(player, 'LSTPWPC'); LSAMBTTPEvent[1] = false; 
	end
	if LSAMBTTPEvent[2] and (not ambt.isActive) then 
		Events.OnWeaponHitCharacter.Remove(LSTPonHit); Events.OnZombieDead.Remove(LSTPOnZDead);
		LSTPWPRemove(player, 'LSTPWPC'); LSAMBTTPEvent[2] = false; 
	end
	if ambt.offBhv and (not ambt.completed) and (not ambt.isActive) then ambt.offBhv = false; ambt.goal1progress = 0; end
	if (not ambt.isActive) and player:getModData().LSTPWPC then LSTPWPRemove(player, 'LSTPWPC'); end
end

LSAmbtMng.LSTheProfessional = function(player, ambt)
	disableEventsCheck(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then LSAmbtComplete(player, ambt); -- ambition was completed
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end

LSAmbtMng.setMutualExclusive("LSCommando","LSTheProfessional") -- sensitive to load order, i.e. make sure the other ambition has already been loaded by the game when you call this - if you're uncertain then use require