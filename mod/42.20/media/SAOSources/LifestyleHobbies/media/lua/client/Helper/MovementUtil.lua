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

local LSMovUtil = {}
LSMovUtil.isRunning = false

local function isAlmostEqual(a, b, tolerance)
	tolerance = tolerance or 0.001
	return math.abs(a - b) < tolerance
end

LSMovUtil.savePlayerPosition = function(player)
	LSMovUtil.LSMovUtilPos = {x = player:getX(), y = player:getY()}
end

LSMovUtil.getMovSpeedMod = function(player)
	local modifier = 1
	if LSAmbtMng.hasActiveCompleted(player, "LSWanderer") and player:isOutside() then modifier = modifier+0.15; end
    return modifier
end

LSMovUtil.isPathfinding = function(player)
    return player:getPathFindBehavior2() and not player:getPathFindBehavior2():getIsCancelled()
end

LSMovUtil.hasNearbyZombie = function(player)
	return player:getSurroundingAttackingZombies() and player:getSurroundingAttackingZombies() ~= 0
end

LSMovUtil.isActive = function(player, modData, movSpeedMod)
	if player:getVehicle() or player:isBlockMovement() or not player:isLocalPlayer() or not player:getCurrentSquare() or player:isAiming() or not LSMovUtil.LSMovUtilPos or
	isAlmostEqual(movSpeedMod, 1.0) or LSMovUtil.hasNearbyZombie(player) then return false; end
    return true
end

LSMovUtil.getMovDeltas = function(player, lastPos, movSpeedMod)
    local deltaX, deltaY, multiplier = player:getX() - lastPos.x, player:getY() - lastPos.y, (LSMovUtil.isPathfinding(player) and (movSpeedMod - 1)) or ((movSpeedMod - 1) * 2 + 1)
    return deltaX * multiplier, deltaY * multiplier
end

LSMovUtil.hasMov = function(dx, dy)
    return dx ~= 0 or dy ~= 0
end

LSMovUtil.canDoMov = function(player, dx, dy)
    local x, y, z = player:getX()+(dx or 0), player:getY()+(dy or 0), player:getZ()
	if not getWorld():isValidSquare(x, y, z) then return false; end
	local grid = getCell():getGridSquare(x, y, z)
	if not grid or grid ~= player:getCurrentSquare() then return false; end
	return true
end

LSMovUtil.OnPlayerUpdate = function(player)
	if not LSMovUtil.isRunning or not player or player:isDead() then return; end

    local modData = player:getModData()
    local movSpeedMod = LSMovUtil.getMovSpeedMod(player)

    if not LSMovUtil.isActive(player, modData, movSpeedMod) then
        LSMovUtil.savePlayerPosition(player)
        return
    end

    local lastPos = LSMovUtil.LSMovUtilPos or {x = player:getX(), y = player:getY()}
    local dx, dy = LSMovUtil.getMovDeltas(player, lastPos, movSpeedMod)
    if LSMovUtil.hasMov(dx, dy) and LSMovUtil.canDoMov(player, dx, dy) then player:setX(player:getX() + dx); player:setY(player:getY() + dy); end

    LSMovUtil.savePlayerPosition(player)
end

LSMovUtil.setRunning = function(boolean)
	if LSMovUtil.isRunning == boolean then return; end
    LSMovUtil.isRunning = boolean
	if boolean then Events.OnPlayerUpdate.Add(LSMovUtil.OnPlayerUpdate); else Events.OnPlayerUpdate.Remove(LSMovUtil.OnPlayerUpdate); end
end

return LSMovUtil
