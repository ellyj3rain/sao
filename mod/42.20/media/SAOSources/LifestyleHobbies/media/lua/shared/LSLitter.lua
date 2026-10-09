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

LSLitter = {}

------------ 

local litter_prefix = {}
litter_prefix.overlay = {
    "overlay_messages",
    "overlay_graffiti",
    "floors_burnt",
    "overlay_blood",
    "blood_floor",
    "overlay_grime",
    "trash_",
    "trash&junk",
    "d_floorleaves",
    "d_trash",
    "LS_HScraps",
    "LS_Scraps"
}
litter_prefix.solid = {
    "overlay_messages",
    "overlay_graffiti",
    "floors_burnt",
    "overlay_blood",
    "blood_floor",
    "overlay_grime",
    "trash&junk",
    "d_floorleaves",
    "d_trash",
}

local function hasLitterName(name, group)
	if not name then return false; end
	for i=1,#litter_prefix[group] do
		if luautils.stringStarts(name, litter_prefix[group][i]) then return true; end
	end
	return false
end

local function getOverlayL(object)
	if not object then return false; end
	local overlaySprite = object.getOverlaySprite and object:getOverlaySprite()
	local name = overlaySprite and overlaySprite:getName()
	local hasOverlayL = hasLitterName(name, 'overlay')
	local attachedsprite = object.getAttachedAnimSprite and object:getAttachedAnimSprite()
	if attachedsprite and not hasOverlayL then
		for n=1,attachedsprite:size() do
			local sprite = attachedsprite:get(n-1)
			local parent = sprite and sprite.getParentSprite and sprite:getParentSprite()
			local spriteName = parent and parent:getName()
			hasOverlayL = hasLitterName(spriteName, 'overlay')
			if hasOverlayL then break; end
		end
	end
	return hasOverlayL
end

local function getSolidL(object)
	if not object then return false; end
	local textureName = object.getTextureName and object:getTextureName()
	return hasLitterName(textureName, 'solid')
end

local function getObjectAndHasSolidOrOverlay(floorList,objList,thisSquare,isOverlay)
	local hasSolidL, blocked
	local isFloorObjs = {}
	for i=0,thisSquare:getObjects():size()-1 do
		local ThisObject = thisSquare:getObjects():get(i)
		if instanceof(ThisObject, "IsoObject") then
			local object = ThisObject
			local sprite = object and object.getSprite and object:getSprite()
			local props = sprite and sprite.getProperties and sprite:getProperties()
			blocked = props and props:has("BlocksPlacement")
			if blocked then break; end
			if object then
				if not isOverlay and not hasSolidL then
					hasSolidL = getSolidL(object)
				elseif isOverlay and object:isFloor() then
					local hasOverlayL = getOverlayL(object)
					if not hasOverlayL then
						table.insert(isFloorObjs, object)
					end
				end
			end
		end
	end
	if not isOverlay and not hasSolidL and not blocked then
		table.insert(floorList, thisSquare)
	elseif isOverlay and not blocked then
		for n=1,#isFloorObjs do
			table.insert(objList, isFloorObjs[n])
		end
	end
	return floorList,objList
end

local function getSquareIsValid(sSquare, thisSquare)
	--if sSquare then print("getSquareIsValid sSquare is valid"); else print("getSquareIsValid sSquare is NIL"); end
	--if thisSquare then print("getSquareIsValid thisSquare is valid"); else print("getSquareIsValid thisSquare is NIL"); end
	--[[
	if thisSquare and sSquare and thisSquare:getRoom() == sSquare:getRoom() and thisSquare:isOutside() == sSquare:isOutside() and thisSquare:isInARoom() and thisSquare:getFloor() and not 
	thisSquare:isSolid() and not thisSquare:isSolidTrans() then
		return true
	else
		return false
	end
	]]--
	return thisSquare and sSquare and thisSquare:getFloor() and not thisSquare:isOutside()
end

local function getAvailableFloorList(Sx,Sy,Sz,isOverlay,sSquare,isLoop)
	local floorList, objList = {}, {}
	local thisSquare, object, hasOverlayL, hasSolidL
	
	if not isLoop then
		--print("getAvailableFloorList not isLoop")
		thisSquare = getCell():getGridSquare(Sx, Sy, Sz)
		if getSquareIsValid(sSquare, thisSquare) then
			--print("getAvailableFloorList getSquareIsValid is TRUE")
			floorList, objList = getObjectAndHasSolidOrOverlay(floorList,objList,thisSquare,isOverlay)
		--else print("getAvailableFloorList getSquareIsValid is FALSE");
		end
	else
		--print("getAvailableFloorList is isLoop")
		for x = Sx-1,Sx+1 do---get x range
			for y = Sy-1,Sy+1 do----get y range
				thisSquare = getCell():getGridSquare(x, y, Sz)
				if getSquareIsValid(sSquare, thisSquare) then
					--print("getAvailableFloorList getSquareIsValid is TRUE")
					floorList, objList = getObjectAndHasSolidOrOverlay(floorList,objList,thisSquare,isOverlay)
				--else print("getAvailableFloorList getSquareIsValid is FALSE");
				end
			end
		end	
	end
	return floorList, objList
end

LSLitter.createDirtPuddle = function(sSquare, spriteName)
	LSUtil.debugPrint("LSLitter.createDirtPuddle - start")
	local isOverlay = true
	--local sSquare = getCell():getGridSquare(Sx, Sy, Sz)
	local floorList, objList = getAvailableFloorList(sSquare:getX(),sSquare:getY(),sSquare:getZ(),isOverlay,sSquare,true)
	
	if not isOverlay and #floorList > 0 then
		local randomTile = ZombRand(#floorList)+1
		local targetFloor = floorList[randomTile]
		sendClientCommand("LS", "AddDirtPuddle", {{targetFloor:getX(), targetFloor:getY(), targetFloor:getZ()}, isOverlay, spriteName})
		--local NewLitterObj = IsoObject.new(targetFloor, spriteName)
		--targetFloor:AddTileObject(NewLitterObj)
		--NewLitterObj:transmitCompleteItemToClients()
		--targetFloor:transmitAddObjectToSquare(NewLitterObj, -1)			
	elseif isOverlay and #objList > 0 then
		local randomObj = ZombRand(#objList)+1
		local targetObj = objList[randomObj]
		local sprite = targetObj.getSprite and targetObj:getSprite()
		local objSpriteName = sprite and sprite:getName()
		if objSpriteName then sendClientCommand("LS", "AddDirtPuddle", {{targetObj:getX(), targetObj:getY(), targetObj:getZ(), objSpriteName}, isOverlay, spriteName}); end
	end
end