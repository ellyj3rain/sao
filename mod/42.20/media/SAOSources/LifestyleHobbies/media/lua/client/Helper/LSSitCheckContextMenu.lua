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

LSSitCheckContextMenu = {};

local function LScheckIsOccupied(thisPlayer, TargetObject)
	local occupied = false
    local playersList = {}
	for x = TargetObject:getX()-0.5,TargetObject:getX()+0.5 do
		for y = TargetObject:getY()-0.5,TargetObject:getY()+0.5 do
			local square = getCell():getGridSquare(x,y,TargetObject:getZ());
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

	if #playersList > 0 then
		for i,v in ipairs(playersList) do
			if v:getUsername() ~= thisPlayer:getUsername() then
				occupied = true
				break
			end
		end
	end
	return occupied
end

local function LScheckConditions(player, Object, spriteName)
	if (not player) or (not Object) or (not spriteName) then return false; end
	local thisPlayer = getSpecificPlayer(player)
	if not thisPlayer then return false; end
    if thisPlayer:getVehicle() or thisPlayer:isSitOnGround() then return false; end
	local playerData
	if thisPlayer:hasModData() then
		playerData = thisPlayer:getModData()
	else return false; end
	if playerData.IsSittingOnSeat then return false; end
	local isOccupied
	if isClient() then isOccupied = LScheckIsOccupied(thisPlayer, Object); end
	if isOccupied then return false; end
	return true
end

local function LSgetSpriteNameFromList(spriteNameList, oldSpriteName)
	local newSpriteName
	for k, v in ipairs(spriteNameList) do
		if v.oldSprite == oldSpriteName then
			newSpriteName = v.newSprite
			break
		end
	end

	return newSpriteName
end

local function LSgetCorrectSprites(mainSprite, secondSprite, spriteNameList)
	local sprite1, sprite2
	sprite1 = LSgetSpriteNameFromList(spriteNameList, mainSprite)
	if secondSprite then
		sprite2 = LSgetSpriteNameFromList(spriteNameList, secondSprite)
	end
	return sprite1, sprite2
end

local function LSgetConnectedObject(worldobjects, TargetObject, secondObjSpriteName)
	local secondObject
	--for _,object in ipairs(worldobjects) do
		for x = TargetObject:getX()-1,TargetObject:getX()+1 do
			for y = TargetObject:getY()-1,TargetObject:getY()+1 do
				local square = getCell():getGridSquare(x,y,TargetObject:getZ());
				if square then
					for i=1,square:getObjects():size() do
						local thisObject = square:getObjects():get(i-1)
						local thisSpriteName = thisObject:getSpriteName()
						--print("LSgetConnectedObject FOUND OBJECT")
						--if thisObject:getName() then print("thisObject Name is " .. thisObject:getName()); end
						--if thisObject:getObjectName() then print("thisObject getObjectName is " .. thisObject:getObjectName()); end
						--if thisObject:getSpriteName() then print("thisObject getSpriteName is " .. thisObject:getSpriteName()); end
						--if thisObject:getTextureName() then print("thisObject getTextureName is " .. thisObject:getTextureName()); end
						if not thisSpriteName then thisSpriteName = thisObject:getTextureName(); end
						if thisSpriteName and (thisSpriteName == secondObjSpriteName) then
							secondObject = thisObject
							break
						end
					end
				end
				if secondObject then break; end
			end
			if secondObject then break; end
		end
		--if secondObject then break; end
	--end
	return secondObject
end

LSSitCheckContextMenu.doBuildMenu = function(player, context, worldobjects, Object, spriteName, customName, groupName, DebugBuildOption, AttachedObject)

	--print("LSSitCheckContextMenu START")

	local isValid = LScheckConditions(player, Object, spriteName)
	if not isValid then return; end

	local secondObject
	if customName then
		--print("LSSitCheckContextMenu customName is "..customName)
		secondObject = LSgetConnectedObject(worldobjects, Object, customName)
	end

	local spriteNameList = require("Properties/LSSpriteNameList")
	local firstSprite, secondSprite = LSgetCorrectSprites(spriteName, customName, spriteNameList)

	if firstSprite then 
		sendClientCommand("LS", "ModifySprite", {{Object:getX(),Object:getY(),Object:getZ(),spriteName}, firstSprite, false, true})
	end

	if secondObject and secondSprite then 
		sendClientCommand("LS", "ModifySprite", {{secondObject:getX(),secondObject:getY(),secondObject:getZ(),customName}, secondSprite, false, true})
	end

	--if secondObject and secondSprite then secondObject:setSpriteFromName(secondSprite); secondObject:softReset(); secondObject:transmitUpdatedSprite(); end

	--if firstSprite then
	--	sledgeDestroy(Object)
	
	--end

end
