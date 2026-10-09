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

require 'ISAmbt/AmbtMng'
require 'ISUI/Maps/ISWorldMap'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local LSAMBTEXEvent = {
	false,
	false,
	false,
	2,
	false, --debug
}

local function checkPOIs(player, ambt)
	if not ambt.explored then ambt.explored = {}; end
	local newPOI = getExploredPOI(player:getX(), player:getY(), ambt.explored)
	if not newPOI then return; end
	if newPOI and not ambt.explored[newPOI] then
		ambt.explored[newPOI] = true
		ambt['goal1progress'] = math.ceil(ambt['goal1progress']+1)
		HaloTextHelper.addTextWithArrow(player, getText("IGUI_LSExplorer_NewPOI"), false, 30, 190, 240)
		getSoundManager():playUISound("UI_BanjoNote")
	end
end

local function LSAmbtActiveIncomplete(player, ambt)
	if not player:isAsleep() then
		local completed = true
		if not ambt['goal1progress'] then ambt['goal1progress'] = 0; end
		if ambt['goal1progress'] < ambt['goal1'] then completed = false; end
		if completed then LSAmbtMng.doComplete(player, ambt); return; end
		checkPOIs(player, ambt)
	end
end

local function getWorldMapInstance(player)
	local playerNum = 0
	ISWorldMap_instance = ISWorldMap:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
	ISWorldMap_instance:initialise()
	ISWorldMap_instance:instantiate()
	ISWorldMap_instance.character = player
	ISWorldMap_instance.playerNum = playerNum
	ISWorldMap_instance.symbolsUI.character = player
	ISWorldMap_instance.symbolsUI.playerNum = playerNum
	ISWorldMap_instance:initDataAndStyle()
	ISWorldMap_instance:setHideUnvisitedAreas(LSAMBTEXEvent[1])
	ISWorldMap_instance:setShowPlayers(ISWorldMap_instance.showPlayers)
	ISWorldMap_instance:setShowRemotePlayers(ISWorldMap_instance.showRemotePlayers)
	ISWorldMap_instance:setShowPlayerNames(ISWorldMap_instance.showPlayerNames)
	ISWorldMap_instance:setShowCellGrid(ISWorldMap_instance.showCellGrid)
	ISWorldMap_instance:setShowTileGrid(ISWorldMap_instance.showTileGrid)
	ISWorldMap_instance:setIsometric(ISWorldMap_instance.isometric)
	ISWorldMap_instance.mapAPI:resetView()
	if ISWorldMap_instance.character then
		ISWorldMap_instance.mapAPI:centerOn(ISWorldMap_instance.character:getX(), ISWorldMap_instance.character:getY())
		ISWorldMap_instance.mapAPI:setZoom(18.0)
	end
	ISWorldMap_instance:restoreSettings()
	ISWorldMap_instance:setVisible(false)
	
	LSAMBTEXEvent[1] = not LSAMBTEXEvent[1]
end

local function doRevealMap(player, ambt)
	if not ISWorldMap.IsAllowed() then return; end
	if not ISWorldMap_instance then getWorldMapInstance(player); return; end
	ISWorldMap_instance:setHideUnvisitedAreas(LSAMBTEXEvent[1])
	--UIWorldMap.new(ISWorldMap):getAPIv1():setBoolean("HideUnvisited", LSAMBTEXEvent[1])
	LSAMBTEXEvent[1] = not LSAMBTEXEvent[1]
end

local function eventIsValid(player, target, damage)
	if not player or not instanceof(player, "IsoPlayer") or player:isDoShove() or
	not target or not damage then return false; end
	if player and player:hasModData() and (not player:isDead()) and player:getModData().Ambitions then return true; end
	return false
end

local function LSEXonHit(attacker, target, weapon, damage)
	if eventIsValid(attacker, target, damage) then
		local ambt = attacker:getModData().Ambitions['LSExplorer']
		if ambt and ambt.completed then
			LSAMBTEXEvent[2] = tostring(target)
		else
			LSAMBTEXEvent[3] = false
			Events.OnZombieDead.Remove(LSEXOnZDead)
			Events.OnWeaponHitCharacter.Remove(LSEXonHit)
		end
	end
end

local function getMapName()
	local t = {"Base.LouisvilleMap1","Base.LouisvilleMap2","Base.LouisvilleMap3","Base.LouisvilleMap4","Base.LouisvilleMap5","Base.LouisvilleMap6","Base.LouisvilleMap7",
	"Base.LouisvilleMap8","Base.LouisvilleMap9","Base.MuldraughMap","Base.MuldraughMap","Base.MuldraughMap","Base.WestpointMap","Base.WestpointMap","Base.WestpointMap",
	"Base.MarchRidgeMap","Base.MarchRidgeMap","Base.MarchRidgeMap","Base.RosewoodMap","Base.RosewoodMap","Base.RosewoodMap","Base.RiversideMap","Base.RiversideMap",
	"Base.RiversideMap"}
	return t[ZombRand(#t)+1] or "Base.MuldraughMap"
end

local function LSEXOnZDead(zombie)
	if zombie and LSAMBTEXEvent[2] and (LSAMBTEXEvent[2] == tostring(zombie)) then
		local chance = LSAMBTEXEvent[4]
		if LSAMBTEXEvent[5] or (chance and (ZombRand(chance) == 0)) then
			local mapName = getMapName()
			local mapItem = instanceItem(mapName);
			zombie:getInventory():AddItem(mapItem);
		end
		LSAMBTEXEvent[2] = false
	end
end

local function getChance(player)
	local chance = 50
	--if player:hasTrait(CharacterTrait.LUCKY) then chance = chance-10;
	--elseif player:hasTrait(CharacterTrait.UNLUCKY) then chance = chance+20; end
	return chance
end

local function LSAmbtComplete(player, ambt)
	if LSAMBTEXEvent[3] or isClient() then return; end
	LSAMBTEXEvent[4] = getChance(player)
	if not LSAMBTEXEvent[3] then LSAMBTEXEvent[3] = true; Events.OnWeaponHitCharacter.Add(LSEXonHit); Events.OnZombieDead.Add(LSEXOnZDead); end
end

local function disableEventsCheck(player, ambt)
	if LSAMBTEXEvent[3] and not ambt.completed then Events.OnWeaponHitCharacter.Remove(LSEXonHit); Events.OnZombieDead.Remove(LSEXOnZDead); LSAMBTEXEvent[3] = false; end
end

LSAmbtMng.LSExplorer = function(player, ambt)
	disableEventsCheck(player, ambt)
	if ambt.completed then -- ambition was completed
		LSAmbtComplete(player, ambt)
		if ambt.isActive then
			if not LSAMBTEXEvent[1] then doRevealMap(player, ambt); return; end
		elseif LSAMBTEXEvent[1] then doRevealMap(player, ambt); return; end
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --has active bonuses
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
