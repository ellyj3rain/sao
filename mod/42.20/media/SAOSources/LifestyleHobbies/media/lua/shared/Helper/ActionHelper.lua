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

ActionHelper = {};

ActionHelper.walkToFront = function(thisPlayer, thisObject)
	local frontSquare = nil
	local controllerSquare = nil
	local spriteName = thisObject:getSprite():getName()
	if not spriteName then
		return false
	end
	local thisSquare = thisObject:getSquare()
	if not thisSquare then
		return false
	end
	local properties = thisObject:getSprite():getProperties()
	
	local facing = nil
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	
	if facing then
		if facing == "S" then
			frontSquare = thisObject:getSquare():getS()
		elseif facing == "E" then
			frontSquare = thisObject:getSquare():getE()
		elseif facing == "W" then
			frontSquare = thisObject:getSquare():getW()
		elseif facing == "N" then
			frontSquare = thisObject:getSquare():getN()
		end
	end
	
	if frontSquare then
		if AdjacentFreeTileFinder.privTrySquare(thisSquare, frontSquare) then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
			return true
		end
	end

	local freeSquare = (thisSquare:getS() or thisSquare:getE() or thisSquare:getW() or thisSquare:getN())

	if not freeSquare then
		if luautils.walkAdj(thisPlayer, thisSquare, true) then
		return true
		else
		return false
		end
	end

	--sometimes showers are blocked from one or more sides, so we find and move the player to the closes available free tile
	local N
	local S
	local E
	local W

	if thisSquare:getS() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getS()) then
		if thisPlayer:getY() >= thisSquare:getS():getY() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getS()))
			return true
		else
			S = 1
		end
	end
	
	if thisSquare:getN() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getN()) then
		if thisPlayer:getY() <= thisSquare:getN():getY() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getN()))
			return true
		else
			N = 1
		end
	end

	if thisSquare:getE() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getE()) then
		if thisPlayer:getX() >= thisSquare:getE():getX() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getE()))
			return true
		else
			E = 1
		end
	end

	if thisSquare:getW() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getW()) then
		if thisPlayer:getX() >= thisSquare:getW():getX() then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getW()))
			return true
		else
			W = 1
		end
	end

	if S then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getS()))
		return true
	elseif N then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getN()))
		return true
	elseif W then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getW()))
		return true
	elseif E then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getE()))
		return true
	end
	
	return false
end

function ActionHelper.walkToContainer(player, container)
	if container:getType() == "floor" then
		return true
	end
	local playerObj = player
	if container:getParent() and not container:getVehiclePart() and container:getParent():getSquare():DistToProper(playerObj:getCurrentSquare()) < 2 then
		return true;
	end

	if container:isInCharacterInventory(playerObj) then
		return true
	end
	local isoObject = container:getParent()
	if not isoObject or not isoObject:getSquare() then
		return true
	end
	if instanceof(isoObject, "BaseVehicle") then
		if playerObj:getVehicle() == isoObject then
			return true
		end
		local part = container:getVehiclePart()
		if part and part:getArea() then
			if part:getVehicle():canAccessContainer(part:getIndex(), playerObj) then
				return true
			end
			ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, part:getVehicle(), part:getArea()))
			return true
		end
	end
	if instanceof(isoObject, "IsoDeadBody") then
		return true
	end
	
	local adjacent = AdjacentFreeTileFinder.Find(isoObject:getSquare(), playerObj)
	if not adjacent then
		return false
	end
	if adjacent == playerObj:getCurrentSquare() then
		return true
	end
	ISTimedActionQueue.clear(playerObj)
	ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, adjacent))
	return true
end

ActionHelper.onRest = function(obj, character, nextAction)
	local action = ISPathFindAction:pathToSitOnFurniture(character, obj, true)
	action:setOnComplete(ActionHelper.onRestPathFound, character, action, nextAction)
	action:setOnFail(ActionHelper.onRestPathFailed, character, obj, action)
	ISTimedActionQueue.add(action)
end

ActionHelper.onRestPathFound = function(character, action, nextAction)
	local after = ISRestAction:new(character, action.goalFurnitureObject, true)
	if action:addAfter(after) == nil then
		ISTimedActionQueue.add(after)
	end
	if after:addAfter(nextAction) == nil then
		ISTimedActionQueue.add(nextAction)
	end
end

ActionHelper.onRestPathFailed = function(character, obj, action)
	local adjacent = AdjacentFreeTileFinder.Find(obj:getSquare(), character, nil)
	if adjacent ~= nil then
		action:setRunActionsAfterFailing(true)
		action:addAfter(ISSitOnGround:new(character, obj)) -- 2nd
		if adjacent ~= character:getCurrentSquare() then
			action:addAfter(ISWalkToTimedAction:new(character, adjacent)) -- 1st
		end
	end
end