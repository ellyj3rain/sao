

local options = {}
options.ambtList= {"LSGoodEating","LSElDorado","LSExplorer","LSKnockdown"}
--[[
local function zombieOnGround(zombie)
	return zombie:isOnFloor() or zombie:getBumpedChr() or zombie:isKnockedDown() or zombie:isCrawling() or zombie:isRagdollFall()
end

local function hitWeapon(player, zombie, weapon, damage)
	return player and zombie and weapon and weapon:IsWeapon() and damage and not player:isDoShove()
end

local function isWeaponType(player, wpType)
	if not WeaponType[wpType] then return false; end
	local playerWpType = WeaponType.getWeaponType(player)
	return playerWpType and playerWpType == WeaponType[wpType]
end

local function isWeaponFromName(weapon, name)
	local fullType = weapon.getFullType and weapon:getFullType()
	return fullType and string.find(fullType, name)
end
]]--
local function getMapName()
	local t = {"Base.LouisvilleMap","Base.MuldraughMap","Base.WestpointMap","Base.MarchRidgeMap","Base.RosewoodMap","Base.RiversideMap"}
	local mapName = t[ZombRand(#t)+1] or "Base.MuldraughMap"
	if mapName == "Base.LouisvilleMap" then mapName = mapName..tostring(ZombRand(9)+1); end
	return mapName
end

options.LSKnockdown = function(ambt, attacker, target, weapon, damage)
	if ambt and ambt.completed then
		if LSUtil.zombieOnGround(target) then return; end
		local roll
		if attacker:isDoShove() then
			roll = 5
		elseif LSUtil.hitWeapon(attacker, weapon, damage) and LSUtil.isValidMeleeWeapon(weapon) then
			roll = 10
			if LSUtil.isWeaponType(attacker, weapon, "TWO_HANDED") then
				roll = 15
				if ambt.isActive and LSUtil.isWeaponFromName(weapon, "Baseball") then roll = 30; end
			end
		end
		if roll and ZombRand(101) <= roll then target:knockDown(target:isHitFromBehind()); end
	end
end

options.LSExplorer = function(ambt, attacker, target, weapon, damage)
	if ambt and ambt.completed then
		local roll = 20
		if ambt.isActive then roll = 15; end
		if ZombRand(roll) == 0 then
			local mapName = getMapName()
			local item = instanceItem(mapName)
			target:addItemToSpawnAtDeath(item)
		end
	end
end

options.LSElDorado = function(ambt, attacker, target, weapon, damage)
	if ambt and ambt.completed then
		local roll, base = 15, 3
		if ambt.isActive then roll, base = 10, 5; end
		if ZombRand(roll) == 0 then
			local total = ZombRand(base)+1
			for n=1, total do
				local item = instanceItem("Base.Money")
				target:addItemToSpawnAtDeath(item)
			end
		end
	end
end

options.LSGoodEating = function(ambt, attacker, target, weapon, damage)
	if ambt and ambt.completed then
		if ZombRand(20) == 0 then
			local total = ZombRand(3)+1
			for n=1, total do
				local sausage = instanceItem("Lifestyle.BloodSausage")
				target:addItemToSpawnAtDeath(sausage)
			end
		end
	end
end

local function doAmbtChecks(zombieData, attacker, target, weapon, damage)
	local ambt = attacker:getModData().Ambitions
	if not ambt then return; end
	for n=1,#options.ambtList do
		local selected = options.ambtList[n]
		if not zombieData[selected] then options[selected](ambt[selected], attacker, target, weapon, damage); zombieData[selected] = true; end
	end
end

local function eventIsValid(player, target, damage)
	if not player or not instanceof(player, "IsoPlayer") then return false; end
	if player:isDoShove() then return false; end
	if not target or not instanceof(target, "IsoZombie") or target:isDead() then return false; end
	if not damage then return false; end
	if player and player:hasModData() and not player:isDead() then return true; end
	return false
end

local function LSOnHitZombie(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) then
		if not target:getModData().lsZombie then target:getModData().lsZombie = {}; end
		local zombieData = target:getModData().lsZombie
		doAmbtChecks(zombieData, attacker, target, weapon, damage)
	end
end

if isServer() then Events.OnWeaponHitCharacter.Add(LSOnHitZombie); end