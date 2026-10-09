
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--ambt.forceReset = true - to reset this ambition for all players, even if they completed it, useful when updating ambition table params - if you don't use forceReset then changes will only apply to new characters
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied


local LSAMBTLDEvent = {
	false, --wH, zD
	false, --t
	0, --c
	false, --gtls
	0.2, --end
}

local function canPerform()
	if not LSAMBTLDEvent[4] then return false; end
	if LSAMBTLDEvent[3] > LSAMBTLDEvent[4] then LSAMBTLDEvent[3] = 0; return true; end
	LSAMBTLDEvent[3] = LSAMBTLDEvent[3] + getGameTime():getGameWorldSecondsSinceLastUpdate()
	return false
end

local function playerHasWT(player, weapon)
	return LSUtil.isValidMeleeWeapon(weapon) and LSUtil.isWeaponType(player, weapon, "TWO_HANDED")
end

local function playerHasBMWT(weapon)
	return LSUtil.weaponHasCategory(weapon, "base:longblade") or LSUtil.weaponHasCategory(weapon, "base:smallblade")
end

local function eventEOMIsValid(player)
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

local function getKillMultiplier(killNumb)
	local t = {
		[100] = 0.30,
		[80] = 0.25,
		[60] = 0.20,
		[40] = 0.15,
		[20] = 0.10,
		[10] = 0.05,
	}
	for k, v in pairs(t) do
		if killNumb and killNumb >= tonumber(k) then return v; end
	end
	return 0.025
end

local function updateEndurance(player, ambt)
	local multi = getKillMultiplier(ambt.recentKills)
	LSUtil.changeCharacterMood(player, "Endurance", LSAMBTLDEvent[5]*multi, false, false)
end

local function LSAMBTLDEventFunc()
	local player, ambt = getSpecificPlayer(0), false
	if eventEOMIsValid(player) then
		ambt = player:getModData().Ambitions['LSLordDeath']
		local weapon = player:getPrimaryHandItem()
		if ambt and ambt.completed and playerHasWT(player, weapon) then
			if ambt.isActive then
				player:setVariable("LSCombatSpeed", "Execute")
			elseif (not LSAmbtMng.hasActiveCompleted(player, 'LSBladeMaster')) or (not playerHasBMWT(weapon)) then
				player:setVariable("LSCombatSpeed", "End")
			end
		elseif (not LSAmbtMng.hasActiveCompleted(player, 'LSBladeMaster')) or (not playerHasBMWT(weapon)) then
			player:setVariable("LSCombatSpeed", "End")
		end
	end
	if (not ambt) or (not ambt.isActive) or (not ambt.completed) then
		if player and instanceof(player, "IsoPlayer") then player:setVariable("LSCombatSpeed", "End"); end
		LSAMBTLDEvent[2] = false;
		Events.OnTick.Remove(LSAMBTLDTick);
	end
end

local function LSAMBTLDTick()
	if canPerform() then LSAMBTLDEventFunc(); end
end

local function eventIsValid(player, target, damage)
	if not player or not instanceof(player, "IsoPlayer") then return false; end
	if (not target) or (target:isDead()) then return false; end
	if not damage then return false; end
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

local function getOverDMG(ambt, damage)
	local multi = getKillMultiplier(ambt.recentKills)
	return damage*multi
end

local LSLDlastZomb

local function LSAMBTLDonHit(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) and playerHasWT(attacker, weapon) then
		local ambt = attacker:getModData().Ambitions['LSLordDeath']
		if ambt and ambt.isActive then
			if playerHasWT(attacker, weapon) then LSLDlastZomb = tostring(target); end
			if ambt.completed then
				if (target:getHealth() > 0) then
					local overDmg = getOverDMG(ambt, damage)
					local newHealth = target:getHealth()-overDmg
					if newHealth < 0 then target:Kill(attacker); return; end
					target:setHealth(newHealth)
				end
			end
		else
			LSAMBTLDEvent[1] = false
			Events.OnZombieDead.Remove(LSAMBTLDOnZDead)
			Events.OnWeaponHitCharacter.Remove(LSAMBTLDonHit)
		end
	end
end

local function updateZombKills()
	local player = getSpecificPlayer(0)
	local ambt = player:getModData().Ambitions['LSLordDeath']
	if (not ambt) then Events.OnZombieDead.Remove(LSAMBTLDOnZDead); return; end
	if ambt.completed then 
		if not ambt.recentKills then ambt.recentKills = 0; end
		ambt.recentKills = math.min(100, math.floor(ambt.recentKills+1))
		return
	else
		if not ambt.goal1progress then ambt.goal1progress = 0; end
		ambt.goal1progress = math.floor(ambt.goal1progress+1)
	end
end

local function LSAMBTLDOnZDead(zombie)
	if zombie and LSLDlastZomb and (LSLDlastZomb == tostring(zombie)) then
		updateZombKills()
		LSLDlastZomb = nil
	end
end

local function reduceKills(killNumb)
	return math.max(0,killNumb-2)
end

local function LSAMBTLDActive(player)
	if not LSAMBTLDEvent[1] then LSAMBTLDEvent[1] = true; Events.OnWeaponHitCharacter.Add(LSAMBTLDonHit); Events.OnZombieDead.Add(LSAMBTLDOnZDead); end
end

local function LSAmbtActiveComplete(ambt, player, hasWPTH)
	if not ambt.offBhv then ambt.offBhv = true; end
	if not LSAMBTLDEvent[4] then LSAMBTLDEvent[4] = 20/GTLSCheck; end
	if not LSAMBTLDEvent[2] and hasWPTH then LSAMBTLDEvent[2] = true; Events.OnTick.Add(LSAMBTLDTick); end
	if ambt.recentKills and ambt.recentKills > 0 then ambt.recentKills = reduceKills(ambt.recentKills); end
end

local function resetKills(player, ambt)
	ambt.offBhv = false
	ambt.recentKills = 0
end

local function LSAmbtActiveIncomplete(player, ambt)
	if not player:isAsleep() then
		if not ambt.goal1progress then ambt.goal1progress = 0; end
		if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); end
	end
end

local function hasEnoughSkill(player)
	if player:getPerkLevel(Perks.Strength) < 10 then return false; end
	local hasSkill, t = false, {'Spear','SmallBlunt','SmallBlade','LongBlade','Axe','Blunt'}
	for n=1, #t do
		local perkName = t[n]
		if player:getPerkLevel(Perks[perkName]) == 10 then hasSkill = true; break; end
	end
	return hasSkill
end

local function LSAmbtIsHidden(player, ambt)
	-- if your ambition starts hidden, add conditions to unlock
	if not hasEnoughSkill(player) then return; end
	LSAmbtMng.doUnlock(player, ambt)
end

LSAmbtMng.LSLordDeath = function(player, ambt)
	local hasWPTH
	if ambt.completed then
		hasWPTH = playerHasWT(player, player:getPrimaryHandItem())
		if hasWPTH then updateEndurance(player, ambt); end
	end
	if ambt.isHidden then LSAmbtIsHidden(player, ambt);
	elseif ambt.isActive then
		LSAMBTLDActive(player)
		if not ambt.completed then LSAmbtActiveIncomplete(player, ambt); return; end
		LSAmbtActiveComplete(ambt, player, hasWPTH)
	elseif ambt.offBhv then resetKills(player, ambt); end
end

