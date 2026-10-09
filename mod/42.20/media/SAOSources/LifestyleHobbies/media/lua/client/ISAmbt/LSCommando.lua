
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player toggles this ambition off mid-progress
--ambt.offBhv - if true then ambtMng will call your ambition when updating even if not passive and not isActive, useful to add behavior when ambition was deactivated by the player
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local LSAMBTCDEvent = {
	false,--pu
	false,--zd, ws
}

local function eventIsValid(player, target, damage)
	if player and instanceof(player, "IsoPlayer") and player:hasModData() and (not player:isDead()) and (not player:isDoShove()) and player:getModData().Ambitions and
	damage and target and (not target:isDead()) then return true; end
	return false
end

local function getOverDMG(damage)
	return damage*0.05
end

local function playerHasWT(player, weapon)
	return LSUtil.isWeaponType(player, weapon, "FIREARM") and not LSUtil.isWeaponType(player, weapon, "HANDGUN")
end

local LSCDlastZomb

local function LSCDonHit(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) then
		local ambt = attacker:getModData().Ambitions['LSCommando']
		if ambt and ambt.isActive then
			if not ambt.completed then 
				if playerHasWT(attacker, weapon) then LSCDlastZomb = tostring(target); end
				return
			end
			local overDmg = getOverDMG(damage)
			if playerHasWT(attacker, weapon) and (overDmg > 0) and (target:getHealth() > 0) then
				local newHealth = target:getHealth()-overDmg
				if newHealth < 0 then target:Kill(attacker); return; end
				target:setHealth(newHealth)
			end
		else
			LSAMBTCDEvent[2] = false
			Events.OnZombieDead.Remove(LSCDOnZDead)
			Events.OnWeaponHitCharacter.Remove(LSCDonHit)
		end
	end
end

local function updateZombKills()
	local player = getSpecificPlayer(0)
	local ambt = player:getModData().Ambitions['LSCommando']
	if (not ambt) or (ambt.completed) then Events.OnZombieDead.Remove(LSCDOnZDead); return; end
	if not ambt.goal1progress then ambt.goal1progress = 0; end
	ambt.goal1progress = math.floor(ambt.goal1progress+1)
end

local function LSCDOnZDead(zombie)
	if zombie and LSCDlastZomb and (LSCDlastZomb == tostring(zombie)) then
		updateZombKills()
		LSCDlastZomb = nil
	end
end

local function LSCDWPRemove(player, dataName)
	local data = player:getModData()[dataName]
	if data and data[1] then
		data[1]:setConditionLowerChance(data[2])
		data[1]:setAimingTime(data[3])
		data[1]:setRecoilDelay(data[4])
	end
	player:getModData()[dataName] = nil
end

local function LSCDWPCheck(player, data, weapon, isActive)
	local dif, old = false, {0, weapon:getConditionLowerChance(), weapon:getAimingTime(), weapon:getRecoilDelay()}
	if data and data[1] then
		if data[3] and data[4] and (not isActive) then dif = true; end
		if data[1] ~= weapon then dif = true; end
		if not dif then
			for n=1, 4 do
				if n > 2 and (not isActive) then break;
				elseif (n > 1) and (data[n] == old[n]) then dif = true; break; end
			end
		end
	else
		dif = true
	end
	if not dif then return; end
	LSCDWPRemove(player, 'LSCDWPC')
	old = {0, weapon:getConditionLowerChance(), weapon:getAimingTime(), weapon:getRecoilDelay()}
	player:getModData().LSCDWPC = {weapon, old[2], old[3], old[4]}
	
	weapon:setConditionLowerChance(old[2]*2)
	if isActive then
		weapon:setAimingTime(old[3]*0.7)
		weapon:setRecoilDelay(old[4]*0.7)
	end
end

local function disableEventsForce(player)
	Events.OnPlayerUpdate.Remove(LSCDOnPlayerUpdate)
	Events.OnWeaponHitCharacter.Remove(LSCDonHit)
	Events.OnZombieDead.Remove(LSCDOnZDead)
	LSCDWPRemove(player, 'LSCDWPC')
	LSAMBTCDEvent[1], LSAMBTCDEvent[2] = false, false; 
end

local function conditionsValid(player)
	if player:isAiming() and player:getModData().Ambitions['LSCommando'] and
	player:getModData().Ambitions['LSCommando'].completed and
	(not player:getModData().LSCDWPC) then return true; end
	return false
end

local function conditionsNotValid(player)
	if (not player:isAiming()) and player:getModData().LSCDWPC then return true; end
	return false
end

local function LSCDOnPlayerUpdate(player)
	if (not LSAMBTCDEvent[1]) or (not player:getModData().Ambitions['LSCommando']) or (not player:getModData().Ambitions['LSCommando'].isActive) or (not player:getModData().Ambitions['LSCommando'].completed) then
		disableEventsForce(player)
		return
	end
	if conditionsValid(player) and playerHasWT(player, player:getPrimaryHandItem()) then
		LSCDWPCheck(player, player:getModData().LSCDWPC, player:getPrimaryHandItem(), player:getModData().Ambitions['LSCommando'].isActive)
	elseif (conditionsNotValid(player)) or (not player:getModData().Ambitions['LSCommando']) or (not player:getModData().Ambitions['LSCommando'].completed) then
		LSCDWPRemove(player, 'LSCDWPC')
	end
end

local function LSAmbtComplete(player, ambt)
	if player:isAsleep() then return; end
	if playerHasWT(player, player:getPrimaryHandItem()) then LSCDWPCheck(player, player:getModData().LSCDWPC, player:getPrimaryHandItem(), ambt.isActive);
	else LSCDWPRemove(player, 'LSCDWPC'); end
	if ambt.isActive and (not LSAMBTCDEvent[1]) then LSAMBTCDEvent[1] = true; Events.OnPlayerUpdate.Add(LSCDOnPlayerUpdate); end	
	if not LSAMBTCDEvent[2] then LSAMBTCDEvent[2] = true; Events.OnWeaponHitCharacter.Add(LSCDonHit); end
end

local function LSAmbtActiveIncomplete(player, ambt)
	-- add conditions to add/remove progress
	-- apply buffs/debuffs if ambition has any while active and incomplete
	if player:isAsleep() then return; end
	if not ambt.offBhv then ambt.offBhv = true; end
	if not ambt.goal1progress then ambt.goal1progress = 0; end
	if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); return; end
	if not LSAMBTCDEvent[2] then LSAMBTCDEvent[2] = true; Events.OnWeaponHitCharacter.Add(LSCDonHit); Events.OnZombieDead.Add(LSCDOnZDead); end
end

local function LSAmbtIsHidden(player, ambt)
	-- if your ambition starts hidden, add conditions to unlock
	if player:getPerkLevel(Perks.Aiming) < 6 then return; end
	if player:getModData().Ambitions['LSTheProfessional'].completed or
	player:getModData().Ambitions['LSTheProfessional'].isActive then return; end
	if not ambt.delayUnlock then ambt.delayUnlock = true; return; end
	LSAmbtMng.doUnlock(player, ambt)
end

local function disableEventsCheck(player, ambt)
	if LSAMBTCDEvent[1] and ((not ambt.isActive) or (not ambt.completed)) then 
		Events.OnPlayerUpdate.Remove(LSCDOnPlayerUpdate);
		LSCDWPRemove(player, 'LSCDWPC'); LSAMBTCDEvent[1] = false; 
	end
	if LSAMBTCDEvent[2] and (not ambt.isActive) then 
		Events.OnWeaponHitCharacter.Remove(LSCDonHit); Events.OnZombieDead.Remove(LSCDOnZDead);
		LSCDWPRemove(player, 'LSCDWPC'); LSAMBTCDEvent[2] = false; 
	end
	if ambt.offBhv and (not ambt.completed) and (not ambt.isActive) then ambt.offBhv = false; ambt.goal1progress = 0; end
	if (not ambt.isActive) and player:getModData().LSCDWPC then LSCDWPRemove(player, 'LSCDWPC'); end
end

LSAmbtMng.LSCommando = function(player, ambt)
	disableEventsCheck(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then LSAmbtComplete(player, ambt); -- ambition was completed
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end