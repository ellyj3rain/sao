
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--ambt.forceReset = true - to reset this ambition for all players, even if they completed it, useful when updating ambition table params - if you don't use forceReset then changes will only apply to new characters
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied


local LSBMEvent = {
	false,
	false,
	0,
	false
}

local function canPerform()
	if not LSBMEvent[4] then return false; end
	if LSBMEvent[3] > LSBMEvent[4] then LSBMEvent[3] = 0; return true; end
	LSBMEvent[3] = LSBMEvent[3] + getGameTime():getGameWorldSecondsSinceLastUpdate()
	return false
end

local function playerHasWT(weapon)
	return LSUtil.weaponHasCategory(weapon, "base:longblade") or LSUtil.weaponHasCategory(weapon, "base:smallblade")
end

local function playerHasLDWT(player, weapon)
	return LSUtil.isValidMeleeWeapon(weapon) and LSUtil.isWeaponType(player, weapon, "TWO_HANDED")
end

local function eventEOMIsValid(player)
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

--[[
local ogWLC = luautils.weaponLowerCondition
function luautils.weaponLowerCondition(_weapon, _character, _replace, _chance)
	local ogFunc = ogWLC(self, _character, _replace, _chance)

    return ogFunc
end
]]--

local function LBSMWPRemove(player, dataName)
	local data = player:getModData()[dataName]
	if data and data[1] then
		data[1]:setConditionLowerChance(data[2])
	end
	player:getModData()[dataName] = nil
end

local function LBSMWPCheck(player, data, weapon)
	local oldC = weapon:getConditionLowerChance()
	if data and data[1] then
		if (data[1] == weapon) and (data[2] ~= oldC) then return; end
		if data[1] ~= weapon then LBSMWPRemove(player, 'LSBMWPC'); end
		--data[1]:setConditionLowerChance(data[2])
	end
	oldC = weapon:getConditionLowerChance()
	player:getModData().LSBMWPC = {weapon, oldC}
	weapon:setConditionLowerChance(oldC*2)
end

local function LSBMEOMEventFunc()
	local player, ambt = getSpecificPlayer(0), false
	if eventEOMIsValid(player) then
		ambt = player:getModData().Ambitions['LSBladeMaster']
		local weapon = player:getPrimaryHandItem()
		if ambt and ambt.completed and ambt.isActive and playerHasWT(weapon) then
			player:setVariable("LSCombatSpeed", "Execute")
		elseif (not LSAmbtMng.hasActiveCompleted(player, 'LSLordDeath')) or (not playerHasLDWT(player, weapon)) then
			player:setVariable("LSCombatSpeed", "End")
		end
	end
	if (not ambt) or (not ambt.isActive) or (not ambt.completed) then
		if player and instanceof(player, "IsoPlayer") then player:setVariable("LSCombatSpeed", "End"); end
		LSBMEvent[2] = false;
		Events.OnTick.Remove(LSBMTick);
	end
end

local function LSBMTick()
	if canPerform() then LSBMEOMEventFunc(); end
end

local function eventIsValid(player, target, damage)
	if not player or not instanceof(player, "IsoPlayer") then return false; end
	if (not target) or (target:isDead()) then return false; end
	if not damage then return false; end
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

local function LSBMonHit(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) and playerHasWT(weapon) then
		local ambt = attacker:getModData().Ambitions['LSBladeMaster']
		if ambt and ambt.completed and ambt.isActive then
			if (target:getHealth() > 0) then
				local overDmg = damage*0.15
				local newHealth = target:getHealth()-overDmg
				if newHealth < 0 then target:Kill(attacker); return; end
				target:setHealth(newHealth)
			end
		else
			LSBMEvent[1] = false
			Events.OnWeaponHitCharacter.Remove(LSBMonHit)
		end
	end
end

local function LSAmbtActiveComplete(player)
	if not LSBMEvent[1] then LSBMEvent[1] = true; Events.OnWeaponHitCharacter.Add(LSBMonHit); end
	if not LSBMEvent[4] then LSBMEvent[4] = 20/GTLSCheck; end
	if (not LSBMEvent[2]) and (playerHasWT(player:getPrimaryHandItem())) then LSBMEvent[2] = true; Events.OnTick.Add(LSBMTick); end
end

local function LSAmbtDisabledIncomplete(player, ambt)
	ambt.offBhv = false
	ambt.oldXP = ambt.goal1progress
end

local function LSAmbtActiveIncomplete(player, ambt)
	ambt.offBhv = true 
	if not player:isAsleep() then
		local totalXP = player:getXp():getXP(Perks.SmallBlade)+player:getXp():getXP(Perks.LongBlade)
		if not ambt.ogXP then ambt.ogXP = totalXP; end
		if ambt.oldXP then ambt.ogXP = math.floor(totalXP-ambt.oldXP); ambt.oldXP = false; end
		ambt.goal1progress = math.floor(totalXP - ambt.ogXP)
		if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); end
	end
end

LSAmbtMng.LSBladeMaster = function(player, ambt)
	if ambt.completed then -- ambition was completed
		if ambt.isActive then LSAmbtActiveComplete(player); end
		if playerHasWT(player:getPrimaryHandItem()) then LBSMWPCheck(player, player:getModData().LSBMWPC, player:getPrimaryHandItem()); else LBSMWPRemove(player, 'LSBMWPC'); end
	elseif (not ambt.isActive) and ambt.offBhv then LSAmbtDisabledIncomplete(player, ambt);--ambition was active and has behavior upon deactivation ~= reset
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end

