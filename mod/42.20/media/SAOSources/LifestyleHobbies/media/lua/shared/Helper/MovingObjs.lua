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

LSMovObjs = {}

LSMovObjs.getMovingObjects = function(square, isoType, range) -- IsoPlayer, IsoZombie, IsoAnimal, etc...
	local movingObjs = {}
	if not square or (isoType == "IsoPlayer" and not isClient() and not isServer()) then return movingObjs; end
	local sqrX, sqrY, sqrZ = square:getX(), square:getY(), square:getZ()
  	for x = sqrX-range,sqrX+range do
		for y = sqrY-range,sqrY+range do
			local square = getCell():getGridSquare(x,y,sqrZ)
			if square then
				local squareMovObjs = square:getMovingObjects()
				for i=1,squareMovObjs:size() do
					local moving = squareMovObjs:get(i-1)
					if moving and instanceof(moving, isoType) then
						table.insert(movingObjs, moving)
					end
				end
			end
		end
	end
	return movingObjs
end

LSMovObjs.getMovingObjectsInView = function(character, isoType, range)
	local movingObjs = {}
	local wantsClients = isoType == "IsoPlayer"
	if wantsClients and not isClient() and not isServer() then return movingObjs; end
	local playerProps = {username=character:getUsername(),outside=character:isOutside(),iso=false}
	local sqrX, sqrY, sqrZ = character:getX(), character:getY(), character:getZ()
  	for x = sqrX-range,sqrX+range do
		for y = sqrY-range,sqrY+range do
			local square = getCell():getGridSquare(x,y,sqrZ)
			if square then
				local squareMovObjs = square:getMovingObjects()
				for i=1,squareMovObjs:size() do
					local moving = squareMovObjs:get(i-1)
					if moving and instanceof(moving, isoType) then
						if not playerProps.iso and wantsClients and moving:getUsername() == playerProps.username then
							playerProps.iso = moving
						elseif moving:isOutside() == playerProps.outside and character:CanSee(moving) then
							table.insert(movingObjs, moving)
						end
					end
				end
			end
		end
	end
	if not wantsClients or not playerProps.iso or #movingObjs == 0 then return movingObjs; end
	local seenClients = {}
	for n=1,#movingObjs do
		local moving = movingObjs[n]
		if moving:getUsername() ~= playerProps.username and playerProps.iso:checkCanSeeClient(moving) then
			table.insert(seenClients, moving)
		end
	end
	return seenClients
end