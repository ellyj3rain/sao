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


local PlayDJBoothAction = require "TimedActions/PlayDJBoothAction"

DJBoothMenu = {};

local function getHeadgears()
	return {"Hat_EarMuff_Protectors","Hat_EarMuff_Protectors_Neck","Authentic_HeadphonesNeck","Hat_EarMuff_Protectors_AZ","Authentic_Headphones","Authentic_Headphones2","Authentic_HeadphonesNeck2","Authentic_Headphones3","Authentic_HeadphonesNeck3","Authentic_Headphones4","Authentic_HeadphonesNeck4"}
end

DJBoothMenu.doBuildMenu = function(player, context, worldobjects)
 
    local thisPlayer = getSpecificPlayer(player)

    if thisPlayer:getVehicle() then return; end
    
	if thisPlayer:hasTrait(CharacterTrait.DEAF) then -- check to keep deaf players from being able to play instruments
		return
	end
	
	if thisPlayer:isSitOnGround() then
		return
	end
	
	if thisPlayer:isSneaking() then
		return
	end
	
	local DJBooth = nil
	local spriteName = nil

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
					
						if customName == "Booth" and
						((thisSpriteName == "ls_djbooth_01_1") or (thisSpriteName == "ls_djbooth_01_4"))then
							DJBooth = thisObject;
							spriteName = thisSpriteName;
						end
					end
				end
			end
		end
	end

	if not DJBooth then return end

	local leftBooth = false
	local rightBooth = false

    for x = DJBooth:getX()-1,DJBooth:getX()+1 do
		for y = DJBooth:getY()-1,DJBooth:getY()+1 do
                    local square = getCell():getGridSquare(x,y,DJBooth:getZ());
                    if square then
						for i=1,square:getObjects():size() do
							local nearbyObject = square:getObjects():get(i-1)
							local nearbyObjectSprite = nearbyObject:getSprite()

					if nearbyObjectSprite ~= nil then
				
						local properties = nearbyObject:getSprite():getProperties()

						if properties ~= nil then
							local thisgroupName = nil
							local thiscustomName = nil
							local nearbyObjectSpriteName = nil
					
						--local thisSprite = thisObject:getSprite()
							if nearbyObjectSprite:getName() then
								nearbyObjectSpriteName = nearbyObjectSprite:getName()
							end
					
							if properties:has("GroupName") then
								thisgroupName = properties:get("GroupName")
							end
					
							if properties:has("CustomName") then
							thiscustomName = properties:get("CustomName")
							end

							if thiscustomName == "Booth" and
							((nearbyObjectSpriteName == "ls_djbooth_01_0") or (nearbyObjectSpriteName == "ls_djbooth_01_3"))then
								leftBooth = true
							end
							if thiscustomName == "Booth" and
							((nearbyObjectSpriteName == "ls_djbooth_01_2") or (nearbyObjectSpriteName == "ls_djbooth_01_5"))then
								rightBooth = true
							end
						end
					end
				end
			end
		end
	end

	if rightBooth == false or
	leftBooth == false then return end
	
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	DJBooth:getSquare():haveElectricity()) then
	return
	end

-- level, base xp, base mood and other defs
	local level = thisPlayer:getPerkLevel(Perks.Music)
	local actionType = "Bob_PlayDJDefault"
	local xp = 0
	local XPPerSecond = 0.01
	local boredomReduction = 0
	local stressReduction = 0
	local BoredomPerSecond = 0.12
	local trainingBoredomPerSecond = 0.1
	local StressPerSecond = 0.001
	local contextMenu = nil;
--

-----------------------Want to Dance Option

	if (getSpecificPlayer(player):getModData().WantsToDance ~= nil) and
	(getSpecificPlayer(player):getModData().WantsToDance == false) then
		local PlayerWantsToDanceOption = context:addOption(getText("ContextMenu_DancingPartner_Enable_Option"), worldobjects, DJBoothMenu.onEnableDancing, getSpecificPlayer(player));
		PlayerWantsToDanceOption.iconTexture = getTexture('media/ui/okay_icon.png')
	elseif (getSpecificPlayer(player):getModData().WantsToDance ~= nil) and
	(getSpecificPlayer(player):getModData().WantsToDance == true) then
		local PlayerWantsToDanceOptionNo = context:addOption(getText("ContextMenu_DancingPartner_Disable_Option"), worldobjects, DJBoothMenu.onDisableDancing, getSpecificPlayer(player));
		PlayerWantsToDanceOptionNo.iconTexture = getTexture('media/ui/okayNo_icon.png')
	else
		getSpecificPlayer(player):getModData().WantsToDance = true
	end

---------------------
	
				if level >= 10 then
					xp = 0
				else
					if thisPlayer:hasTrait(CharacterTrait.VIRTUOSO) then -- VIRTUOSO TRAIT
					xp = XPPerSecond * (level + 1)
					elseif thisPlayer:hasTrait(CharacterTrait.TONEDEAF) then -- TONE DEAF TRAIT
					xp = 0.2 * XPPerSecond * (level + 1)
					elseif thisPlayer:hasTrait(CharacterTrait.HARD_OF_HEARING) then -- HARD OF HEARING TRAIT
					xp = 0.6 * XPPerSecond * (level + 1)
					else
					xp = XPPerSecond * (level + 1) -- NO SPECIFIC TRAIT
					end
				end


				-- CALCULATING BOREDOM AND STRESS REDUCTION BASED ON LENGTH, TRACK LEVEL AND TRAITS
				
				if thisPlayer:hasTrait(CharacterTrait.VIRTUOSO) then -- VIRTUOSO TRAIT
				boredomReduction = 3 * BoredomPerSecond * (level + 1)
				stressReduction = 3 * StressPerSecond * (level + 1)
				
				elseif thisPlayer:hasTrait(CharacterTrait.KEEN_HEARING) then -- KEEN HEARING GETS A BONUS IF NOT VIRTUOSO
				boredomReduction = 2 * BoredomPerSecond * (level + 1)
				stressReduction = 2 * StressPerSecond * (level + 1)
				
				elseif thisPlayer:hasTrait(CharacterTrait.TONEDEAF) then -- TONE DEAF TRAIT
				boredomReduction = ((-2 * BoredomPerSecond) / (level + 1))
				stressReduction = ((-2 * StressPerSecond) / (level + 1))
				
				elseif thisPlayer:hasTrait(CharacterTrait.HARD_OF_HEARING) then -- HARD OF HEARING TRAIT
				boredomReduction = ((-1 * BoredomPerSecond) / (level + 1))
				stressReduction = ((-1 * StressPerSecond) / (level + 1))
				
				else
				boredomReduction = BoredomPerSecond * (level + 1)
				stressReduction = StressPerSecond * (level + 1)

				end

----

	local PlayDJBoothTracks = require("TimedActions/PlayDJBoothTracks")
	
	
		contextMenu = "ContextMenu_Play_DJBooth"
		
		local buildOption = context:addOption(getText(contextMenu));
		
	local inventory = thisPlayer:getInventory()	
	local it = inventory:getItems();
	local contextMenuHeadPhone = "ContextMenu_Play_DJBooth_NoHeadPhone"
	local contextMenuEmbarrassed = "ContextMenu_Embarrassed"
	local IsHeadPhoneOn = false

	local headgears = getHeadgears()
	for j = 0, it:size()-1 do
		local item = it:get(j)
		for n=0, (#headgears)-1 do
			if item:getType() and (item:getType() == headgears[n]) and thisPlayer:isEquippedClothing(item) then
				IsHeadPhoneOn = true
				break
			end
		end
		if IsHeadPhoneOn then break; end
	end
		
	local tooltip = ISToolTip:new();
		tooltip:initialise();
		tooltip:setVisible(false);
		
	if IsHeadPhoneOn == false then
		buildOption.notAvailable = true;
		description = " <RED>" .. getText(contextMenuHeadPhone);
		tooltip.description = description
		buildOption.toolTip = tooltip
		buildOption.iconTexture = getTexture('media/ui/djboothNo_icon.png')
	elseif getSpecificPlayer(player):getModData().LSMoodles["Embarrassed"].Value ~= nil and getSpecificPlayer(player):getModData().LSMoodles["Embarrassed"].Value >= 0.2 then
		buildOption.notAvailable = true;
		description = " <RED>" .. getText(contextMenuEmbarrassed);
		tooltip.description = description
		buildOption.toolTip = tooltip
		buildOption.iconTexture = getTexture('media/ui/djboothNo_icon.png')
	else
		buildOption.iconTexture = getTexture('media/ui/djbooth_icon.png')
		local parentMenu = ISContextMenu:getNew(context);
		context:addSubMenu(buildOption, parentMenu)
	
---------------SLOW
	
	local AvailableSlowTracks = {}
	
				for k,v in pairs(PlayDJBoothTracks) do
					if v.mode == "slow" then
						table.insert(AvailableSlowTracks, v)
					end
				end
				
				-- RANDOMIZING WHICH AVAILABLE TRACK WILL BE PICKED IN A GIVEN ACTION AND SETTING THE LENGTH
	local randomSlowNumber = ZombRand(#AvailableSlowTracks) + 1
	local randomSlowTrack = AvailableSlowTracks[randomSlowNumber]
	local length = randomSlowTrack.length * 48	
	contextMenu1 = "ContextMenu_Play_DJBooth_Slow"

	local DJBoothOptionSlow = parentMenu:addOption(getText(contextMenu1),
		worldobjects,
		DJBoothMenu.onPlay,
		thisPlayer,
		DJBooth,
		randomSlowTrack.sound,
		randomSlowTrack.mode,
		length,
		xp,
		boredomReduction,
		stressReduction,
		actionType,
		false);	
		
	DJBoothOptionSlow.iconTexture = getTexture('media/ui/fire_icon.png')
		
---------------MEDIUM
	
	local AvailableMediumTracks = {}
	
				for k,v in pairs(PlayDJBoothTracks) do
					if v.mode == "medium" then
						table.insert(AvailableMediumTracks, v)
					end
				end
				
				-- RANDOMIZING WHICH AVAILABLE TRACK WILL BE PICKED IN A GIVEN ACTION AND SETTING THE LENGTH
	local randomMediumNumber = ZombRand(#AvailableMediumTracks) + 1
	local randomMediumTrack = AvailableMediumTracks[randomMediumNumber]
	local length = randomMediumTrack.length * 48	
	contextMenu2 = "ContextMenu_Play_DJBooth_Medium"

	local DJBoothOptionMedium = parentMenu:addOption(getText(contextMenu2),
		worldobjects,
		DJBoothMenu.onPlay,
		thisPlayer,
		DJBooth,
		randomMediumTrack.sound,
		randomMediumTrack.mode,
		length,
		xp,
		boredomReduction,
		stressReduction,
		actionType,
		false);	
		
	local tooltipMedium = ISToolTip:new();
	tooltipMedium:initialise();
	tooltipMedium:setVisible(false);

	if thisPlayer:getPerkLevel(Perks.Music) < 3 then
		DJBoothOptionMedium.notAvailable = true;
		descriptionM = " <RED>" .. getText("ContextMenu_Play_DJBooth_MediumNo");
		tooltipMedium.description = descriptionM
		DJBoothOptionMedium.toolTip = tooltipMedium
		DJBoothOptionMedium.iconTexture = getTexture('media/ui/fire2No_icon.png')
	else
		DJBoothOptionMedium.iconTexture = getTexture('media/ui/fire2_icon.png')
	end
		
---------------FAST
	
	local AvailableFastTracks = {}
	
				for k,v in pairs(PlayDJBoothTracks) do
					if v.mode == "fast" then
						table.insert(AvailableFastTracks, v)
					end
				end
				
				-- RANDOMIZING WHICH AVAILABLE TRACK WILL BE PICKED IN A GIVEN ACTION AND SETTING THE LENGTH
	local randomFastNumber = ZombRand(#AvailableFastTracks) + 1
	local randomFastTrack = AvailableFastTracks[randomFastNumber]
	local length = randomFastTrack.length * 48	
	contextMenu3 = "ContextMenu_Play_DJBooth_Fast"

	local DJBoothOptionFast = parentMenu:addOption(getText(contextMenu3),
		worldobjects,
		DJBoothMenu.onPlay,
		thisPlayer,
		DJBooth,
		randomFastTrack.sound,
		randomFastTrack.mode,
		length,
		xp,
		boredomReduction,
		stressReduction,
		actionType,
		false);	

	local tooltipFast = ISToolTip:new();
	tooltipFast:initialise();
	tooltipFast:setVisible(false);

	if thisPlayer:getPerkLevel(Perks.Music) < 6 then
		DJBoothOptionFast.notAvailable = true;
		descriptionF = " <RED>" .. getText("ContextMenu_Play_DJBooth_FastNo");
		tooltipFast.description = descriptionF
		DJBoothOptionFast.toolTip = tooltipFast
		DJBoothOptionFast.iconTexture = getTexture('media/ui/fire3No_icon.png')
	else
		DJBoothOptionFast.iconTexture = getTexture('media/ui/fire3_icon.png')
	end

---------------HouseMix
	
	local AvailableHouseMixTracks = {}
	
				for k,v in pairs(PlayDJBoothTracks) do
					if v.mode == "housemix" then
						table.insert(AvailableHouseMixTracks, v)
					end
				end
				
	if #AvailableHouseMixTracks > 0 then
				
				-- RANDOMIZING WHICH AVAILABLE TRACK WILL BE PICKED IN A GIVEN ACTION AND SETTING THE LENGTH
	local randomHouseMixNumber = ZombRand(#AvailableHouseMixTracks) + 1
	local randomHouseMixTrack = AvailableHouseMixTracks[randomHouseMixNumber]
	local length = randomHouseMixTrack.length * 48	
	contextMenu4 = "ContextMenu_Play_DJBooth_HouseMix"

	local DJBoothOptionHouseMix = parentMenu:addOption(getText(contextMenu4),
		worldobjects,
		DJBoothMenu.onPlay,
		thisPlayer,
		DJBooth,
		randomHouseMixTrack.sound,
		randomHouseMixTrack.mode,
		length,
		xp,
		boredomReduction,
		stressReduction,
		actionType,
		false);	

		DJBoothOptionHouseMix.iconTexture = getTexture('media/ui/addon_icon.png')
	end

	end
end

DJBoothMenu.walkToFront = function(thisPlayer, thisObject)
	local frontSquare = nil
	local controllerSquare = nil
	local spriteName = thisObject:getSprite():getName()
	if not spriteName then
		return false
	end

	local properties = thisObject:getSprite():getProperties()
	
	local facing = nil
	if properties:has("Facing") then
		facing = properties:get("Facing")
	else
		return
	end
	
	if facing == "S" then
		frontSquare = thisObject:getSquare():getS()
	elseif facing == "E" then
		frontSquare = thisObject:getSquare():getE()
	elseif facing == "W" then
		frontSquare = thisObject:getSquare():getW()
	elseif facing == "N" then
		frontSquare = thisObject:getSquare():getN()
	end
	
	if not frontSquare then
		return false
	end
	
	if not controllerSquare then
		controllerSquare = thisObject:getSquare()
	end

	if AdjacentFreeTileFinder.privTrySquare(controllerSquare, frontSquare) then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
		return true
	end
	return false
end


DJBoothMenu.onEnableDancing = function(worldobjects, player)
	player:getModData().WantsToDance = true
end

DJBoothMenu.onDisableDancing = function(worldobjects, player)
	player:getModData().WantsToDance = false
end

DJBoothMenu.onPlay = function(worldobjects, player, DJBooth, soundFile, mode, length, xp, boredomReduction, stressReduction, actionType, isFail)
	if DJBoothMenu.walkToFront(player, DJBooth) then
		ISTimedActionQueue.add(PlayDJBoothAction:new(player, DJBooth, soundFile, mode, length, xp, boredomReduction, stressReduction, actionType, isFail));
	end
end

Events.OnFillWorldObjectContextMenu.Add(DJBoothMenu.doBuildMenu);
