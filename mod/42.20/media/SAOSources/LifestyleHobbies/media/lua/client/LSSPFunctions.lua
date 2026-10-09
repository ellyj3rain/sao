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


function LSAddLitter(Ax, Ay, Az, ASO, ALS)

    local Sx = Ax
    local Sy = Ay
	local Sz = Az
	local SolidOrOverlay = ASO
	local LitterSprite = ALS
	local AvailableFloorList = {}
	local targetFloor
	local sSquare = getCell():getGridSquare(Sx, Sy, Sz)

  	for x = Sx-1,Sx+1 do---get x range
		for y = Sy-1,Sy+1 do----get y range

			local thisSquare = getCell():getGridSquare(x, y, Sz)---get grid square (our radius)
        
			if thisSquare and sSquare and thisSquare:getRoom() == sSquare:getRoom() and thisSquare:isOutside() == sSquare:isOutside() then
            
			for i=0,thisSquare:getObjects():size()-1 do-----------search objects for each square on the radius (floor counts as an object)
				local object = thisSquare:getObjects():get(i);
				local hasSolidL = false
				if object then--solid litter is the result of direct actions and as such can happen anywhere the action takes place
					local hasOverlayL = false
					local attachedsprite = object:getAttachedAnimSprite()
					if object:getTextureName() and
					(luautils.stringStarts(object:getTextureName(), "overlay_messages") or 
					luautils.stringStarts(object:getTextureName(), "overlay_graffiti") or 
					luautils.stringStarts(object:getTextureName(), "floors_burnt") or 
					luautils.stringStarts(object:getTextureName(), "overlay_blood") or 
					luautils.stringStarts(object:getTextureName(), "blood_floor") or
					luautils.stringStarts(object:getTextureName(), "overlay_grime") or 
					--luautils.stringStarts(object:getTextureName(), "trash_") or 
					luautils.stringStarts(object:getTextureName(), "trash&junk") or 
					luautils.stringStarts(object:getTextureName(), "d_floorleaves") or 
					luautils.stringStarts(object:getTextureName(), "d_trash")) then-----------if object already has solid litter then do not add more
						hasSolidL = true
					end
					if object:getOverlaySprite() and object:getOverlaySprite():getName() and
					(luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_messages") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_graffiti") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "floors_burnt") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_blood") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "blood_floor") or
					luautils.stringStarts(object:getOverlaySprite():getName(), "overlay_grime") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "trash_") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "trash&junk") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "d_floorleaves") or 
					luautils.stringStarts(object:getOverlaySprite():getName(), "d_trash") or
					luautils.stringStarts(object:getOverlaySprite():getName(), "LS_Scraps")) then-----------if object already has overlay litter then do not add more
						hasOverlayL = true
					end
					--if attachedsprite and object:isFloor() and not object:isOutside() then--overlays such as dirt and grime almost always occur based on random factors and movement so it only happens indoors
					if attachedsprite then
						--if object:isFloor() then
							--if not object:isOutside() then
						for n=1,attachedsprite:size() do
							local sprite = attachedsprite:get(n-1)
							if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() and
							(luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_messages") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_graffiti") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "floors_burnt") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_blood") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "blood_floor") or
							luautils.stringStarts(sprite:getParentSprite():getName(), "overlay_grime") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "trash_") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "trash&junk") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "d_floorleaves") or 
							luautils.stringStarts(sprite:getParentSprite():getName(), "d_trash")) then-----------if object already has overlay litter then do not add more
								hasOverlayL = true
							end
						end
						--end
						--end
					end
					if SolidOrOverlay == 2 and object:isFloor() and not hasOverlayL then
						table.insert(AvailableFloorList, object)
					end
				end
					if SolidOrOverlay == 1 and not hasSolidL then
						table.insert(AvailableFloorList, thisSquare)
					end
				end
				
			end
			
		end
		
	end

	if #AvailableFloorList > 0 then
		local randomTile = ZombRand(#AvailableFloorList) + 1
		targetFloor = AvailableFloorList[randomTile]
		if targetFloor then
			if SolidOrOverlay == 1 then
				local NewLitterObj = IsoObject.new(targetFloor, LitterSprite)
				targetFloor:AddTileObject(NewLitterObj)			
			
			elseif SolidOrOverlay == 2 then
				local square = targetFloor:getSquare()
				local objOnFloor
				if square then
					for i=1,square:getObjects():size() do
						local thisObject = square:getObjects():get(i-1)
						if thisObject and not thisObject:isFloor() then
							objOnFloor = true
						end
					end
				end
				
				--targetFloor:setOverlaySprite(LitterSprite, 1, 1, 1, 1, false)--string/transmit
				if not objOnFloor then
					targetFloor:setOverlaySprite(LitterSprite, false)
				else
					print("ADDING DIRT FAILED: one or more objects on floor tile")
				end
			end
		end
	end
end