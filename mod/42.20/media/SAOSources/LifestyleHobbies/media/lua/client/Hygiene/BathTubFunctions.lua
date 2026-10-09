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

BathTubFunctions = {};

BathTubFunctions.DoAction = function(player, object, startX, startY, wearClothes)
 
    local thisPlayer = player

	if not thisPlayer then return; end
	
	local playerdata
	
	if thisPlayer:hasModData() then
		playerdata = thisPlayer:getModData()
	else
	return; end
	
	local BathTub = object

	if not BathTub then return; end

	if wearClothes then
		BathTubFunctions.onAction(thisPlayer, BathTub, startX, startY, false);
	else
		BathTubFunctions.walkToFront(thisPlayer, BathTub, startX, startY)
	end

end

BathTubFunctions.walkToFront = function(thisPlayer, thisObject, startX, startY)

	if startX and startY then
		thisPlayer:setX(startX); thisPlayer:setY(startY)
		--if isClient() then thisPlayer:setLx(startX); thisPlayer:setLy(startY); end
		return true
	end

	local frontSquare, frontSquareAlt, controllerSquare
	local spriteName = thisObject:getSprite():getName()
	if not spriteName then
		--print("BathTubFunctions: no spriteName")
		return false
	end
	local thisSquare = thisObject:getSquare()
	if not thisSquare then
		--print("BathTubFunctions: no thisSquare")
		return false
	end
	local properties = thisObject:getSprite():getProperties()
	
	local facing = nil
	if properties:has("Facing") then
		facing = properties:get("Facing")
	end
	
	if facing then
		if (facing == "S") or (facing == "N") then
			frontSquare = thisObject:getSquare():getE()
			frontSquareAlt = thisObject:getSquare():getW()
		elseif (facing == "E") or (facing == "W") then
			frontSquare = thisObject:getSquare():getS()
			frontSquareAlt = thisObject:getSquare():getN()
		end
	end
	
	if frontSquare then
		if AdjacentFreeTileFinder.privTrySquare(thisSquare, frontSquare) then
			--thisPlayer:setX(frontSquare:getX()); thisPlayer:setLx(frontSquare:getX()); thisPlayer:setY(frontSquare:getY()); thisPlayer:setLy(frontSquare:getY())
			thisPlayer:setX(frontSquare:getX()); thisPlayer:setY(frontSquare:getY())
			--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
			return true
		end
	elseif frontSquareAlt then
		if AdjacentFreeTileFinder.privTrySquare(thisSquare, frontSquareAlt) then
			--thisPlayer:setX(frontSquareAlt:getX()); thisPlayer:setLx(frontSquareAlt:getX()); thisPlayer:setY(frontSquareAlt:getY()); thisPlayer:setLy(frontSquareAlt:getY())
			thisPlayer:setX(frontSquareAlt:getX()); thisPlayer:setY(frontSquareAlt:getY())
			--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquareAlt))
			return true
		end
	end

	local freeSquare

	if (spriteName == "fixtures_bathroom_01_25") or (spriteName == "fixtures_bathroom_01_52") then
		freeSquare = (thisSquare:getE() or thisSquare:getW())
	elseif (spriteName == "fixtures_bathroom_01_26") or (spriteName == "fixtures_bathroom_01_55") then
		freeSquare = (thisSquare:getS() or thisSquare:getN())
	end

	if not freeSquare then
		--print("BathTubFunctions: no freeSquare")
		return false
	end

	--move the player to the closest available free tile
	local N, S, E, W

	if ((spriteName == "fixtures_bathroom_01_26") or (spriteName == "fixtures_bathroom_01_55")) and thisSquare:getS() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getS()) then
		if thisPlayer:getY() >= thisSquare:getS():getY() then
			--thisPlayer:setX(thisSquare:getS():getX()); thisPlayer:setLx(thisSquare:getS():getX()); thisPlayer:setY(thisSquare:getS():getY()); thisPlayer:setLy(thisSquare:getS():getY())
			thisPlayer:setX(thisSquare:getS():getX()); thisPlayer:setY(thisSquare:getS():getY())
			--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getS()))
			return true
		else
			S = 1
		end
	end
	
	if ((spriteName == "fixtures_bathroom_01_26") or (spriteName == "fixtures_bathroom_01_55")) and thisSquare:getN() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getN()) then
		if thisPlayer:getY() <= thisSquare:getN():getY() then
			--thisPlayer:setX(thisSquare:getN():getX()); thisPlayer:setLx(thisSquare:getN():getX()); thisPlayer:setY(thisSquare:getN():getY()); thisPlayer:setLy(thisSquare:getN():getY())
			thisPlayer:setX(thisSquare:getN():getX()); thisPlayer:setY(thisSquare:getN():getY())
			--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getN()))
			return true
		else
			N = 1
		end
	end

	if ((spriteName == "fixtures_bathroom_01_25") or (spriteName == "fixtures_bathroom_01_52")) and thisSquare:getE() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getE()) then
		if thisPlayer:getX() >= thisSquare:getE():getX() then
			--thisPlayer:setX(thisSquare:getE():getX()); thisPlayer:setLx(thisSquare:getE():getX()); thisPlayer:setY(thisSquare:getE():getY()); thisPlayer:setLy(thisSquare:getE():getY())
			thisPlayer:setX(thisSquare:getE():getX()); thisPlayer:setY(thisSquare:getE():getY())
			--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getE()))
			return true
		else
			E = 1
		end
	end

	if ((spriteName == "fixtures_bathroom_01_25") or (spriteName == "fixtures_bathroom_01_52")) and thisSquare:getW() and AdjacentFreeTileFinder.privTrySquare(thisSquare, thisSquare:getW()) then
		if thisPlayer:getX() >= thisSquare:getW():getX() then
			--thisPlayer:setX(thisSquare:getE():getW()); thisPlayer:setLx(thisSquare:getE():getW()); thisPlayer:setY(thisSquare:getE():getW()); thisPlayer:setLy(thisSquare:getE():getW())
			thisPlayer:setX(thisSquare:getE():getW()); thisPlayer:setY(thisSquare:getE():getW())
			--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getW()))
			return true
		else
			W = 1
		end
	end

	if S then
		--thisPlayer:setX(thisSquare:getS():getX()); thisPlayer:setLx(thisSquare:getS():getX()); thisPlayer:setY(thisSquare:getS():getY()); thisPlayer:setLy(thisSquare:getS():getY())
		thisPlayer:setX(thisSquare:getS():getX()); thisPlayer:setY(thisSquare:getS():getY())
		--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getS()))
		return true
	elseif N then
		--thisPlayer:setX(thisSquare:getN():getX()); thisPlayer:setLx(thisSquare:getN():getX()); thisPlayer:setY(thisSquare:getN():getY()); thisPlayer:setLy(thisSquare:getN():getY())
		thisPlayer:setX(thisSquare:getN():getX()); thisPlayer:setY(thisSquare:getN():getY())
		--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getN()))
		return true
	elseif W then
		--thisPlayer:setX(thisSquare:getE():getW()); thisPlayer:setLx(thisSquare:getE():getW()); thisPlayer:setY(thisSquare:getE():getW()); thisPlayer:setLy(thisSquare:getE():getW())
		thisPlayer:setX(thisSquare:getE():getW()); thisPlayer:setY(thisSquare:getE():getW())
		--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getW()))
		return true
	elseif E then
		--thisPlayer:setX(thisSquare:getE():getX()); thisPlayer:setLx(thisSquare:getE():getX()); thisPlayer:setY(thisSquare:getE():getY()); thisPlayer:setLy(thisSquare:getE():getY())
		thisPlayer:setX(thisSquare:getE():getX()); thisPlayer:setY(thisSquare:getE():getY())
		--ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, thisSquare:getE()))
		return true
	end
	
	--print("BathTubFunctions: walktofront fail")
	return false
end

BathTubFunctions.onAction = function(player, BathTub, startX, startY, Laundry)
	local LSChangeClothes = require "TimedActions/PlayerChangeClothes"
	
	--print("BathTubFunctions: about to walk to front")
	if BathTubFunctions.walkToFront(player, BathTub, startX, startY) then
		--print("BathTubFunctions: about to change clothes")
		ISTimedActionQueue.add(LSChangeClothes:new(player, BathTub, "isBathNoLaundryEnd"))
	end
end

BathTubFunctions.DoActionDisturbed = function(player, TargetX, TargetY, object, startX, startY, Clothes)
 	local LSChangeClothes = require "TimedActions/PlayerChangeClothes"
	--print("do action disturbed")
 
    local thisPlayer = player
	local otherPlayerX = TargetX
	local otherPlayerY = TargetY
	local wasDressed = Clothes
	if not thisPlayer then return; end	
	local BathTub = object

	if not BathTub then return; end

	--print("about to walk to front")
------
	if BathTubFunctions.walkToFront(thisPlayer, BathTub, startX, startY) then
		--print("do TIMED action disturbed")
		if wasDressed then
			ISTimedActionQueue.add(LSChangeClothes:new(player, BathTub, "isBathNoLaundryEnd"))
		end
		if otherPlayerX and otherPlayerY then
			ISTimedActionQueue.add(ShooOther:new(thisPlayer, otherPlayerX, otherPlayerY))
		end
	end
end