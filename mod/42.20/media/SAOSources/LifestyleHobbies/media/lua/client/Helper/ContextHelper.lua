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

function CanSeeTargetPlayer(worldobjects, player, context)

	if not isClient() then return; end

	local thisPlayer = getSpecificPlayer(player)
	local otherPlayer

	if not thisPlayer:getModData().LSCooldowns then thisPlayer:getModData().LSCooldowns = {}; end
	if not thisPlayer:getModData().LSCooldowns["InteractionSpam"] then thisPlayer:getModData().LSCooldowns["InteractionSpam"] = 0; end

	for _,object in ipairs(worldobjects) do
		local square = object:getSquare()
		if square then
			for i=1,square:getMovingObjects():size() do
				local moving = square:getMovingObjects():get(i-1)
				if instanceof(moving, "IsoPlayer") and (not moving.isAnimal or not moving:isAnimal()) and moving:getUsername() ~= thisPlayer:getUsername() and
				moving:isOutside() == thisPlayer:isOutside() and thisPlayer:CanSee(moving) and
				--moving:isOutside() == thisPlayer:isOutside() and thisPlayer:CanSee(moving) and not otherPlayer then
				thisPlayer:checkCanSeeClient(moving) and not otherPlayer then
					otherPlayer = moving
				end
				if otherPlayer then break; end
			end
		end
		if otherPlayer then break; end
	end

	--if not otherPlayer then print("I only see myself...  " .. thisPlayer:getDescriptor():getForename() .. thisPlayer:getDescriptor():getSurname()); end
	--if otherPlayer then print("I see someone... " .. otherPlayer:getDescriptor():getForename() .. otherPlayer:getDescriptor():getSurname()); end

	local InteractBuildOption
	local playerInfo = LSMPS.getOtherPlayerInfo(otherPlayer)
	if playerInfo then
		
	
			local contextmenuText = getText("ContextMenu_LSMP_InteractMain")
			local InteractContextMain = context:addOptionOnTop(getText(contextmenuText.." "..tostring(otherPlayer:getDescriptor():getForename())));
			InteractContextMain.iconTexture = getTexture('media/ui/talkto_icon.png')

			InteractBuildOption = ISContextMenu:getNew(context);
			context:addSubMenu(InteractContextMain, InteractBuildOption)

			if (otherPlayer:hasTimedActions() or otherPlayer:isSitOnGround() or (thisPlayer:getModData().LSCooldowns["InteractionSpam"] >= 6)) then
	
			local tooltip = ISToolTip:new();
			tooltip:initialise();
			tooltip:setVisible(false);

			InteractContextMain.notAvailable = true;
			description = " <RED>" .. getText("Tooltip_LSMP_CantInteract");
			tooltip.description = description
			InteractContextMain.toolTip = tooltip
			--InteractContextMain.iconTexture = getTexture('media/ui/danceNo_icon.png')
			return otherPlayer, false, InteractBuildOption
	end

	end

	return otherPlayer, playerInfo, InteractBuildOption

end

function ScanForTileObject(player, worldobjects)

	local TileObject
	local Type
	local spriteName

	local objects = {}
	for _,object in ipairs(worldobjects) do
		local square = object:getSquare()
		if square then
			for i=1,square:getObjects():size() do
				local thisObject = square:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						--local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
							--print("Sprite Name is " .. spriteName)
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
							--print("GroupName: " .. groupName);
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
							--print("CustomName: " .. customName);
						end
					
						if customName == "Shower" and groupName == "Deluxe" then
							TileObject = thisObject;
							Type = "Deluxe"
							spriteName = thisSpriteName;
						elseif customName == "Shower" then
							TileObject = thisObject;
							Type = "Common"
							spriteName = thisSpriteName;
						end
					end
				end
			end
		end
	end

	return TileObject, Type

end