-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

local function getPlayerAtLocation(thisPlayer, otherPlayer)

    for playerIndex = 0, getNumActivePlayers()-1 do
        local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		if (playerObj ~= nil) then
			for x = thisPlayer:getX()-20,thisPlayer:getX()+20 do
                for y = thisPlayer:getY()-20,thisPlayer:getY()+20 do
                    local square = getCell():getGridSquare(x,y,playerObj:getZ());
                    if square then
                        for i = 0,square:getMovingObjects():size()-1 do
                            local moving = square:getMovingObjects():get(i);
                            if instanceof(moving, "IsoPlayer") then
                                table.insert(playersList, moving);
                            end
                        end
                    end
                end
            end
		end
	
        if #playersList > 0 then
			for i,v in ipairs(playersList) do
				if v:getUsername() ~= playerObj:getUsername() and
				tostring(v:getUsername()) == otherPlayer then
					return v
				end
			end
        end			
    end

	--print("otherPlayer is FALSE")
	return false

end

local function walkToOtherPlayer(thisPlayer, otherPlayer)

	local thisSquare = otherPlayer:getSquare()
	if not thisSquare then
		--print("walkToOtherPlayer is FALSE")
		return false
	end

	local freeSquare = (thisSquare:getS() or thisSquare:getE() or thisSquare:getW() or thisSquare:getN())

	if not freeSquare then
		if luautils.walkAdj(thisPlayer, thisSquare, true) then
			return true
		else
			--print("walkToOtherPlayer is FALSE")
			return false
		end
	end

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
	
	--print("walkToOtherPlayer is FALSE")
	return false
end

local function IsOtherPlayerClose(thisPlayer, otherPlayer)

	if otherPlayer:getX() >= thisPlayer:getX() - 1 and otherPlayer:getX() < thisPlayer:getX() + 1 and
	otherPlayer:getY() >= thisPlayer:getY() - 1 and otherPlayer:getY() < thisPlayer:getY() + 1 then	
		return true
	end
	--print("OtherPlayerClose is FALSE")
	return false
end

local function getSatisfyConditions(thisPlayer, otherPlayer)
	if (thisPlayer:hasTrait(CharacterTrait.DEAF) or otherPlayer:hasTimedActions() or otherPlayer:isSitOnGround() or thisPlayer:hasTimedActions() or thisPlayer:isSitOnGround() or
	thisPlayer:isSneaking() or thisPlayer:isAiming() or (otherPlayer:getZ() ~= thisPlayer:getZ()) or (thisPlayer:getModData().LSInteractionState ~= "none")) then	
		--print("getSatisfyConditions is FALSE")
		return false
	end
	
	return true
end

function EndInteractionAlone(isSource, thisPlayer, Interaction, actionArg)

	local doTimedAction = require(Interaction)

	ISTimedActionQueue.clear(thisPlayer)
	--print("Starting Interaction after waiting")
	--thisPlayer:setPrimaryHandItem(nil)
	--thisPlayer:setSecondaryHandItem(nil)
	ISTimedActionQueue.add(doTimedAction:new(isSource, thisPlayer, actionArg));


end

function StartInteractionSource(thisPlayer, otherPlayer, Interaction, actionArg)

	local doTimedAction = require(Interaction)

	ISTimedActionQueue.clear(thisPlayer)
	--print("Starting Interaction after waiting")
	thisPlayer:setPrimaryHandItem(nil)
	thisPlayer:setSecondaryHandItem(nil)
	ISTimedActionQueue.add(doTimedAction:new(thisPlayer, otherPlayer, actionArg));


end

function WasAskedToInteract(thisPlayer, Source, Interaction, IsClose, actionArg)

    thisPlayer:setX(thisPlayer:getX())
    thisPlayer:setY(thisPlayer:getY())
	--thisPlayer:setLx(thisPlayer:getX())
    --thisPlayer:setLy(thisPlayer:getY())

	local otherPlayer = getPlayerAtLocation(thisPlayer, Source)

	if not otherPlayer then return; end

	local charData = thisPlayer:getModData()

	if not charData.LSInteractionState or charData.LSInteractionState == "sourceStoppedWaiting" then
		charData.LSInteractionState = "none"
	end

	local doTimedAction = require(Interaction)

	if IsClose and getSatisfyConditions(thisPlayer, otherPlayer) and LSMPS.isPlayerNearby(thisPlayer, otherPlayer, 1) then
		--print("Beginning interaction at WasAskedToInteract")
		--ISTimedActionQueue.clear(thisPlayer)
		thisPlayer:setPrimaryHandItem(nil)
		thisPlayer:setSecondaryHandItem(nil)
		ISTimedActionQueue.add(doTimedAction:new(thisPlayer, otherPlayer, {actionArg, false}));

	elseif getSatisfyConditions(thisPlayer, otherPlayer) and walkToOtherPlayer(thisPlayer, otherPlayer) then
		--print("Walking - Beginning interaction at WasAskedToInteract")
		--ISTimedActionQueue.clear(thisPlayer)
		thisPlayer:setPrimaryHandItem(nil)
		thisPlayer:setSecondaryHandItem(nil)
		ISTimedActionQueue.add(doTimedAction:new(thisPlayer, otherPlayer, {actionArg, false}));

	else
		--print("Stopping interaction at WasAskedToInteract")
		--if not getSatisfyConditions(thisPlayer, otherPlayer) then print("getSatisfyConditions is FALSE"); end; if not IsClose then print("IsClose is FALSE"); end; if not IsOtherPlayerClose(thisPlayer, otherPlayer) then print("OtherPlayer NOT CLOSE"); end; if not otherPlayer then print("otherPlayer is FALSE"); end; if not walkToOtherPlayer(thisPlayer, otherPlayer) then print("walkToOtherPlayer is FALSE"); end
		sendClientCommand(thisPlayer, "LS", "StopOrStartInteraction", {otherPlayer:getOnlineID(), "none"})
	end

end

local function getObj(objSqr, spriteName)
	local sqrObjs = objSqr:getObjects()
	for i=1,sqrObjs:size() do
		local obj = sqrObjs:get(i-1)
		local objSpriteName = obj and LSUtil.getObjSpriteName(obj)
		if objSpriteName and objSpriteName == spriteName then
			return obj
		end
	end
	return false
end

function WasAskedToInteractObj(thisPlayer, Source, posArgs, Interaction, IsClose, actionArg)
    thisPlayer:setX(thisPlayer:getX())
    thisPlayer:setY(thisPlayer:getY())

	local otherPlayer = getPlayerAtLocation(thisPlayer, Source)
	if not otherPlayer then return; end

	local charData = thisPlayer:getModData()

	if not charData.LSInteractionState or charData.LSInteractionState == "sourceStoppedWaiting" then
		charData.LSInteractionState = "none"
	end

	local doTimedAction = require(Interaction)

	local srcSquare = getCell():getGridSquare(posArgs[1], posArgs[2], posArgs[3])
	local destSquare = getCell():getGridSquare(posArgs[4], posArgs[5], posArgs[6])
	local objSquare = getCell():getGridSquare(posArgs[7], posArgs[8], posArgs[9])
	if not srcSquare or not destSquare or not objSquare then return; end
	local obj = getObj(objSquare, posArgs[10])
	if not obj then return; end

	if not LSUtil.isCharBusy(thisPlayer) and not thisPlayer:isAiming() then

		if (IsClose and destSquare:DistToProper(thisPlayer) < 1) or LSUtil.walkToSqr(thisPlayer, destSquare, false, true) then
			ISTimedActionQueue.add(doTimedAction:new(thisPlayer, otherPlayer, {actionArg, false}));
			return
		end
	end
		--print("Stopping interaction at WasAskedToInteract")
		--if not getSatisfyConditions(thisPlayer, otherPlayer) then print("getSatisfyConditions is FALSE"); end; if not IsClose then print("IsClose is FALSE"); end; if not IsOtherPlayerClose(thisPlayer, otherPlayer) then print("OtherPlayer NOT CLOSE"); end; if not otherPlayer then print("otherPlayer is FALSE"); end; if not walkToOtherPlayer(thisPlayer, otherPlayer) then print("walkToOtherPlayer is FALSE"); end
	sendClientCommand(thisPlayer, "LS", "StopOrStartInteraction", {otherPlayer:getOnlineID(), "none"})
end
