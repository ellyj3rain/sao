
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player toggles this ambition off mid-progress
--ambt.offbhv - if true then ambtMng will call your ambition when updating even if not passive and not isActive, useful to add behavior when ambition was deactivated by the player
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local LSAMBTKDEvent = {
	false,
	0.2, --damage
	0, -- zombiekill
}

local function eventIsValid(player, target, damage)
	if not player or not instanceof(player, "IsoPlayer") or not target then return false; end
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

local function getOverDMG(damage)
	return damage*LSAMBTKDEvent[2]
end

local function getBaseballBat(player, weapon, damage)
	if not player or not weapon or not weapon:IsWeapon() or not damage or player:isDoShove() then return false; end
	local weaponType = WeaponType.getWeaponType(player)
	if not weaponType or weaponType == WeaponType.FIREARM or weaponType == WeaponType.HANDGUN then return false; end
	if weaponType == WeaponType.TWO_HANDED then
		if ((weapon:getType() and string.find(weapon:getType(), "Baseball")) or (weapon:getFullType() and string.find(weapon:getFullType(), "Baseball"))) then
			return true
		end
	end
	return false
end

local function getWPVars(damage, player, weapon, zombie, activeAmbt)
	if not player or not zombie or not weapon or not weapon:IsWeapon() or (not damage and not player:isDoShove()) then return false; end
	local dmg, chance, knock = 0, 5, false
	if player:isDoShove() then return true, 0, not zombie:isKnockedDown() and ZombRand(100)+1 <= chance; end
	local weaponType = WeaponType.getWeaponType(player)
	if not weaponType or weaponType == WeaponType.FIREARM or weaponType == WeaponType.HANDGUN then return false; end
	if weaponType == WeaponType.TWO_HANDED then
		if activeAmbt and ((weapon:getType() and string.find(weapon:getType(), "Baseball")) or (weapon:getFullType() and string.find(weapon:getFullType(), "Baseball"))) then
			dmg = getOverDMG(damage)
			chance = 30
		else
			chance = 15
		end
	end
	if not zombie:isOnFloor() and not zombie:getBumpedChr() and not zombie:isKnockedDown() and not zombie:isCrawling() and not zombie:isRagdollFall() and ZombRand(100)+1 <= chance then knock = true; end
	--if weaponType and ((weaponType == WeaponType.UNARMED)) then return false; end
	return true, dmg, knock
end

local LSKDlastZomb

local function LSKDonHit(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) then
		local ambt = attacker:getModData().Ambitions['LSKnockdown']
		if ambt and ambt.completed then
			local zombieHealth = target:getHealth()
			if not target:isDead() and zombieHealth > 0 then
				local validWP, overDmg, shouldKnock = getWPVars(damage, attacker, weapon, target, ambt.isActive)
				if validWP then
					if overDmg > 0 then
						zombieHealth = zombieHealth-overDmg
						if zombieHealth < 0 then target:Kill(attacker); else target:setHealth(zombieHealth); end
					end
					if not isServer() and not isClient() and shouldKnock and zombieHealth > 0 then target:knockDown(target:isHitFromBehind()); end
					--if shouldKnock and zombieHealth > 0 then target:setRagdollFall(true); end
				end
			end
		elseif ambt and ambt.isActive then
			local isBaseballBat = getBaseballBat(attacker, weapon, damage)
			if isBaseballBat then LSKDlastZomb = tostring(target); end
		else
			LSAMBTKDEvent[1] = false
			Events.OnWeaponHitCharacter.Remove(LSKDonHit)
			Events.OnZombieDead.Remove(LSKDOnZDead)
		end
	end
end

local function LSKDOnZDead(zombie)
	if zombie and LSKDlastZomb and (LSKDlastZomb == tostring(zombie)) then
		LSAMBTKDEvent[3] = LSAMBTKDEvent[3]+1
		LSKDlastZomb = nil
	end
end

local function LSAmbtComplete(player, ambt)
	if player:isAsleep() then return; end
	if not LSAMBTKDEvent[1] then LSAMBTKDEvent[1] = true; Events.OnWeaponHitCharacter.Add(LSKDonHit); Events.OnZombieDead.Add(LSKDOnZDead); end
end

local function LSAmbtActiveIncomplete(player, ambt)
	-- add conditions to add/remove progress
	-- apply buffs/debuffs if ambition has any while active and incomplete
	if player:isAsleep() then return; end
	local completed = true

	if not ambt['goal1progress'] then ambt['goal1progress'] = 0; end
	if ambt['goal1progress'] < ambt['goal1'] then -- additional check to ensure it won't recalculate if player had previously satisfied the condition
		if LSAMBTKDEvent[3] > 0 then ambt['goal1progress'] = math.floor(ambt['goal1progress']+LSAMBTKDEvent[3]); LSAMBTKDEvent[3] = 0; end
		if ambt['goal1progress'] < ambt['goal1'] then completed = false; end
	end

	if completed then ambt.offBhv = true; LSAmbtMng.doComplete(player, ambt); return; end
	if not LSAMBTKDEvent[1] then LSAMBTKDEvent[1] = true; Events.OnWeaponHitCharacter.Add(LSKDonHit); Events.OnZombieDead.Add(LSKDOnZDead); end
end

local function LSAmbtIsHidden(player, ambt)
	-- if your ambition starts hidden, add conditions to unlock
	if player:getPerkLevel(Perks.Blunt) < 6 then return; end
	LSAmbtMng.doUnlock(player, ambt)
end

local function disableEventsCheck(player, ambt)
	if LSAMBTKDEvent[1] and (not ambt.completed or not ambt.isActive) then Events.OnWeaponHitCharacter.Remove(LSKDonHit); Events.OnZombieDead.Remove(LSKDOnZDead); LSAMBTKDEvent[1] = false; end
end

LSAmbtMng.LSKnockdown = function(player, ambt)
	disableEventsCheck(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then LSAmbtComplete(player, ambt); -- ambition was completed
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
