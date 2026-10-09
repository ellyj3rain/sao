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

require 'ISUI/ISWorldObjectContextMenu'

LSDanceContextMenu = {}

LSDanceContextMenu.onDancingPartner = function(worldobjects, playerObj, DanceTargetID, DanceProposer)
    --playerObj:getModData().IsDancingFull = true
	local player = playerObj
	local actionType = "Bob_PreDancingDefault"
	ISTimedActionQueue.add(PlayerIsDancingToMusic:new(player, actionType));
	sendClientCommand(playerObj, "LS", "AskToDance", {DanceTargetID, DanceProposer})
end

LSDanceContextMenu.onDancing = function(character)
	ISTimedActionQueue.add(PlayerIsDancingToMusic:new(character, "Bob_PreDancingDefault"))
end

LSDanceContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)
	local character = getSpecificPlayer(player)
	local charData = character:getModData()
	if not charData or LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) or not (charData.IsListeningToJukebox or charData.IsListeningToDJ) or
	LSUtil.isEquippedClothing(character, {"Base.Hat_EarMuff_Protectors","Base.Hat_EarMuffs"}) then return; end

	local optionName = getText("ContextMenu_Dancing_Option")
	local currentEmbarrassed = charData.LSMoodles["Embarrassed"] and charData.LSMoodles["Embarrassed"].Value
	local tooltipText
	if currentEmbarrassed and currentEmbarrassed >= 0.2 then tooltipText = getText("ContextMenu_Embarrassed"); 
	elseif LSUtil.getCharacterMood(character, "Endurance") <= 0.3 then tooltipText = getText("ContextMenu_Exhausted");
	elseif LSUtil.getCharacterMood(character, "Pain") > 20 then tooltipText = getText("ContextMenu_InPain"); end
	if tooltipText then
		local option = LSUtil.getDummyOption(context, optionName, tooltipText, getTexture('media/ui/danceNo_icon.png'), 'addOptionOnTop', true)
		return
	end

	local option = context:addOptionOnTop(optionName, character, LSDanceContextMenu.onDancing)
	option.iconTexture = getTexture('media/ui/dance_icon.png')

	--[[
	local playersList = {}


			if (playerObj:getModData().IsDancingInit == true) then
				--if isKeyDown(Keyboard.KEY_X) then
				local OtherPlayersAround
				OtherPlayersAround = false
				for x = playerObj:getX()-1,playerObj:getX()+1 do
					for y = playerObj:getY()-1,playerObj:getY()+1 do
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

            if #playersList > 0 and playerObj:getModData().LSMoodles["Embarrassed"].Value ~= nil and playerObj:getModData().LSMoodles["Embarrassed"].Value < 0.2 and currentEndurance > 0.3 and debugremoveOption == false then
                for i,v in ipairs(playersList) do
					if v:getUsername() ~= playerObj:getUsername() and
					v:isOutside() == playerObj:isOutside() then
						OtherPlayersAround = true

						if #playersList <= 2 then
						local DanceTargetName = tostring(v:getDescriptor():getForename())
						local DanceTargetSurname = tostring(v:getDescriptor():getSurname())
						local DanceTargetID = v:getOnlineID()
						local DanceProposer = tostring(playerObj:getUsername())
						local PlayerIsDancingToMusicOption = context:addOption(getText("ContextMenu_Dancing_Option"), worldobjects, LSDanceContextMenu.onDancing, playerObj);
						local PlayerIsDancingTogetherToMusicOption = context:addOption(getText("ContextMenu_Dancing_Partner_Option", DanceTargetName.." "..DanceTargetSurname), worldobjects, LSDanceContextMenu.onDancingPartner, playerObj, DanceTargetID, DanceProposer);

					end
				end
                end			
            end
			if OtherPlayersAround == false then
				local PlayerIsDancingToMusicOption = context:addOptionOnTop(getText("ContextMenu_Dancing_Option"), worldobjects, LSDanceContextMenu.onDancing, playerObj);
				PlayerIsDancingToMusicOption.iconTexture = getTexture('media/ui/dance_icon.png')
				local tooltip = ISToolTip:new();
				tooltip:initialise();
				tooltip:setVisible(false);
		
				if playerObj:getModData().LSMoodles["Embarrassed"].Value ~= nil and playerObj:getModData().LSMoodles["Embarrassed"].Value >= 0.2 then
					local contextMenuEmbarrassed = "ContextMenu_Embarrassed"
					PlayerIsDancingToMusicOption.notAvailable = true;
					description = " <RED>" .. getText(contextMenuEmbarrassed);
					tooltip.description = description
					PlayerIsDancingToMusicOption.toolTip = tooltip
					PlayerIsDancingToMusicOption.iconTexture = getTexture('media/ui/danceNo_icon.png')
				elseif currentEndurance <= 0.3 then
					PlayerIsDancingToMusicOption.notAvailable = true;
					description = " <RED>" .. getText("ContextMenu_Exhausted");
					tooltip.description = description
					PlayerIsDancingToMusicOption.toolTip = tooltip
				elseif LSUtil.getCharacterMood(playerObj, "Pain") > 20 then
					PlayerIsDancingToMusicOption.notAvailable = true;
					description = " <RED>" .. getText("ContextMenu_InPain");
					tooltip.description = description
					PlayerIsDancingToMusicOption.toolTip = tooltip
				--else
				--PlayerIsDancingToMusicOption.iconTexture = getTexture('media/ui/djbooth_icon.png')
				end
				
			elseif OtherPlayersAround == true and #playersList > 2 then
				--local PlayerIsDancingToMusicOption = context:addOption(getText("ContextMenu_Dancing_Option"), worldobjects, LSDanceContextMenu.onDancing, playerObj);
			--print("GROUP OPTION HERE")			
			end
		--end	
			end
	]]--
end
