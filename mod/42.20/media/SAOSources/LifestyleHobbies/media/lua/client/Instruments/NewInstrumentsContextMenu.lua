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

NewInstrumentsContextMenu = {};

local function getLearnableSongs(Type)
	local learnableTracks = {}
	local allTracks = require("TimedActions/Play"..Type.."Tracks")
	if allTracks and (#allTracks > 0) then
		for k,v in pairs(allTracks) do
			if v.isaddon ~= 2 then
				table.insert(learnableTracks, v)
			end
		end
	end
	return learnableTracks
end

local function hasSongsToLearn(Type, learnedTracksData)
	local learnableTracks = getLearnableSongs(Type)
	if learnableTracks and (#learnableTracks > 0) and (#learnableTracks > #learnedTracksData) then return true; end
	return false
end

local function getInstrumetProperties(ItemName, playerdata, Item)

	local Type, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet, playableInstrument

	if ItemName == 'Lifestyle.Harmonica' then
		--playableInstrument = thisPlayer:getPrimaryHandItem()
		Type = "Harmonica"
		InstrumentIconTexture = getTexture('media/ui/harmonica_icon.png')
		learnedTracksData = playerdata.HarmonicaLearnedTracks
		--InstrumentTracksDuet = require("TimedActions/PlayHarmonicaTracksDuet")
		InstrumentTracksDuet = false
	elseif luautils.stringStarts(ItemName, "HMW.H_Bass") then
		Type = "GuitarElectricBass"
		InstrumentIconTexture = getTexture('media/ui/guitarelectricbass_icon.png')
		learnedTracksData = playerdata.GuitarEBLearnedTracks
		InstrumentTracksDuet = require("TimedActions/PlayGuitarElectricBassTracksDuet")
	elseif luautils.stringStarts(ItemName, "HMW.H_Acoustic") then
		Type = "GuitarAcoustic"
		InstrumentIconTexture = getTexture('media/ui/guitaracoustic_icon.png')
		learnedTracksData = playerdata.GuitarALearnedTracks
		InstrumentTracksDuet = require("TimedActions/PlayGuitarAcousticTracksDuet")
	elseif luautils.stringStarts(ItemName, "HMW.H_Electric") then
		Type = "GuitarElectric"
		InstrumentIconTexture = getTexture('media/ui/guitarelectric_icon.png')
		learnedTracksData = playerdata.GuitarELearnedTracks
		InstrumentTracksDuet = require("TimedActions/PlayGuitarElectricTracksDuet")
	elseif luautils.stringStarts(ItemName, "HMW.H_Banjo") then
		Type = "Banjo"
		InstrumentIconTexture = getTexture('media/ui/banjo_icon.png')
		learnedTracksData = playerdata.BanjoLearnedTracks
		InstrumentTracksDuet = require("TimedActions/PlayBanjoTracksDuet")
	end

	if Item then
		if Type then
			playableInstrument = Item
		end
		return Type, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet, playableInstrument
	else
		return Type, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet
	end
end

local function LSInstrumentPracticeOption(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)
	local trainingDebuginstrumentoption
    if LSUtil.hasAdminRights() then
		trainingDebuginstrumentoption = context:addOptionOnTop(getText("ContextMenu_LSDebug_LearnAllSongs"),
		worldobjects,
		NewInstrumentsContextMenu.onDebug,
		thisPlayer,
		Type,
		learnedTracksData,
		playerlevel)
		trainingDebuginstrumentoption.iconTexture = getTexture('media/ui/BugIcon.png')
	end

	contextMenu = "ContextMenu_Play_Practice_" .. tostring(Type)
		
	local traininginstrumentoption = context:addOptionOnTop(getText(contextMenu),
	worldobjects,
	NewInstrumentsContextMenu.onAction,
	thisPlayer,
	playableInstrument,
	Type,
	playerlevel,
	false,
	false,
	true,
	false,false);

	local tooltipTraining = ISToolTip:new();
	tooltipTraining:initialise();
	tooltipTraining:setVisible(false);

	local descriptionT = getText("ContextMenu_Play_Instrument_Practice")
	if learnedTracksData and (#learnedTracksData > 0) and (not hasSongsToLearn(Type, learnedTracksData)) then
		descriptionT = getText("Tooltip_PracticeInstrument_KnowAll")
		if trainingDebuginstrumentoption then
			trainingDebuginstrumentoption.notAvailable = true
			local tooltipDebugTraining = ISToolTip:new();
			tooltipDebugTraining:initialise();
			tooltipDebugTraining:setVisible(false);
			tooltipDebugTraining.description = descriptionT
			trainingDebuginstrumentoption.toolTip = tooltipDebugTraining
		end
	end
	tooltipTraining.description = descriptionT
	traininginstrumentoption.toolTip = tooltipTraining
	traininginstrumentoption.iconTexture = InstrumentIconTexture

end

local function LSInstrumentRandomOption(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)

	local AvailableTracks = {}
		
	for k,v in pairs(learnedTracksData) do
		if playerlevel > 3 then
			if v.isaddon ~= 2 and v.level >= 2 and v.level <= playerlevel then
				table.insert(AvailableTracks, v)
			end
		elseif v.isaddon ~= 2 and v.level <= playerlevel then
			table.insert(AvailableTracks, v)
		end
	end
					
	if #AvailableTracks > 0 then
		randomNumber = ZombRand(#AvailableTracks) + 1
		randomTrack = AvailableTracks[randomNumber]
		Length = randomTrack.length * 48
					
		contextMenu = "ContextMenu_Play_Random_" .. tostring(Type)
		
		local randominstrumentoption = context:addOptionOnTop(getText(contextMenu),
		worldobjects,
		NewInstrumentsContextMenu.onAction,
		thisPlayer,
		playableInstrument,
		Type,
		randomTrack.sound,
		Length,
		randomTrack.level,
		false,
		false,false);
		randominstrumentoption.iconTexture = InstrumentIconTexture
	end

end

local function generalPlayerConditions(thisPlayer)
	if not thisPlayer then return false; end
    if thisPlayer:getVehicle() then return false; end
	--if not thisPlayer:isSitOnGround() then return false; end
	if thisPlayer:isSneaking() then return false; end
	if thisPlayer:hasTrait(CharacterTrait.DEAF) then return false; end
	if not thisPlayer:hasModData() then return false; end
	return true
end

local function generalItemConditions(thisPlayer, playableInstrument)
	if not playableInstrument then return false; end
	if playableInstrument.getFullType and playableInstrument:getFullType() and string.find(playableInstrument:getFullType(), "Broken") then return false; end
	if playableInstrument:isBroken() or (playableInstrument:isInPlayerInventory() == false) or
	(thisPlayer:getInventory():contains(playableInstrument) == false) or (luautils.stringEnds(playableInstrument:getType(),"Hanger")) then return false; end
	--print("INSTRUMENT TYPE IS... "..tostring(playableInstrument:getType()))
	return true
end

local function hotbarItemConditions(playableInstrument, hotbar)
	if not playableInstrument then return false; end
	if (hotbar and playableInstrument:getAttachedSlot() == -1) or (not hotbar and playableInstrument:getAttachedSlot() ~= -1) then return false; end
	return true
end

local function doDuetSubMenu(parentSubMenu, newSubMenuText, newSubMenuTexture, newSubMenuTooltip)

	local newSubMenu = parentSubMenu:addOption(newSubMenuText)
	newSubMenu.iconTexture = newSubMenuTexture
	newSubMenu.toolTip = newSubMenuTooltip

end

local function LSInstrumentDuetOption(context, parentMenu, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentTracksDuet)

				contextMenu = "ContextMenu_Play_Duet_" .. tostring(Type)
			
				local duetMenu = parentMenu:addOptionOnTop(getText(contextMenu));
		
				local subMenuF = parentMenu:getNew(parentMenu);
				context:addSubMenu(duetMenu, subMenuF)
		
				local DuetTooltip = ISToolTip:new();
				DuetTooltip:initialise();
				DuetTooltip:setVisible(false);
				DuetTooltip.description = getText("ContextMenu_Play_Duet_InstrumentsNeeded")
		
					for k,v in pairs(InstrumentTracksDuet) do
						if v.level <= playerlevel then
						local length = v.length * 48
						local InstrumentSound = false
						if v.actionType == "CanDoBackVocal" then
							InstrumentSound = v.soundv
						end
					--3F ADDING THE OPTION FOR DUET SONGS IN THE CONTEXT MENU
						contextMenu = v.name
						
						local SubMenuFoption = subMenuF:addOptionOnTop(getText(contextMenu),
						worldobjects,
						NewInstrumentsContextMenu.onAction,
						thisPlayer,
						playableInstrument,
						Type,
						v.sound,
						length,
						v.level,
						false,
						true,
						InstrumentSound);
						
						local subsubMenu = subMenuF:getNew(subMenuF);
						context:addSubMenu(SubMenuFoption, subsubMenu)
				
						if v.guitaracoustic == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_GuitarAcoustic"), getTexture('media/ui/guitaracoustic_icon.png'), DuetTooltip)
						end
						if v.guitarelectric == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_GuitarElectric"), getTexture('media/ui/guitarelectric_icon.png'), DuetTooltip)
						end
						if v.guitarelectricbass == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_GuitarElectricBass"), getTexture('media/ui/guitarelectricbass_icon.png'), DuetTooltip)
						end
						if v.keytar == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Keytar"), getTexture('media/ui/keytar_icon.png'), DuetTooltip)
						end
						if v.flute == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Flute"), getTexture('media/ui/flute_icon.png'), DuetTooltip)
						end
						if v.saxophone == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Saxophone"), getTexture('media/ui/saxophone_icon.png'), DuetTooltip)
						end
						if v.banjo == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Banjo"), getTexture('media/ui/banjo_icon.png'), DuetTooltip)
						end
						if v.trumpet == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Trumpet"), getTexture('media/ui/trumpet_icon.png'), DuetTooltip)
						end
						if v.violin == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Violin"), getTexture('media/ui/violin_icon.png'), DuetTooltip)
						end
						if v.piano == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Piano"), getTexture('media/ui/piano_icon.png'), DuetTooltip)
						end
						if v.vocalm == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_VocalM"), getTexture('media/ui/vocalM_icon.png'), DuetTooltip)
						end
						if v.vocalf == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_VocalF"), getTexture('media/ui/vocalF_icon.png'), DuetTooltip)
						end
				--if v.drums == 1 then
					--doDuetSubMenu(subsubMenu, getText("ContextMenu_Drums"), getTexture('media/ui/drums_icon.png'), DuetTooltip)
				--end
						if v.harmonica == 1 then
							doDuetSubMenu(subsubMenu, getText("ContextMenu_Harmonica"), getTexture('media/ui/harmonica_icon.png'), DuetTooltip)
						end
					end
				end



end

local function LSInstrumentPlayOptions(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)

			if playerlevel < 10 then
				contextMenu = "ContextMenu_Play_L" .. playerlevel .. "_" .. tostring(Type)
			else
				contextMenu = "ContextMenu_Play_Master_" .. tostring(Type)
			end
	
			local buildOption = context:addOptionOnTop(getText(contextMenu));
			buildOption.iconTexture = InstrumentIconTexture
			local subMenu = ISContextMenu:getNew(context);
			context:addSubMenu(buildOption, subMenu)

		--2 ADDING THE OPTION TO PLAY SONGS YOUR LEVEL BY NAME
			for k,v in pairs(learnedTracksData) do
				if v.isaddon ~= 2 and v.level == playerlevel then
					local length = v.length * 48

			--2 ADDING THE OPTION IN THE CONTEXT MENU
					contextMenu = v.name
					local subMenuOption = subMenu:addOptionOnTop(getText(contextMenu),
					worldobjects,
					NewInstrumentsContextMenu.onAction,
					thisPlayer,
					playableInstrument,
					Type,
					v.sound,
					length,
					v.level,
					false,
					false,false);

					if v.isaddon ~= 0 then
						subMenuOption.iconTexture = getTexture('media/ui/addon_icon.png')
					end
				end --if
			end --for
			
			if LSAmbtMng.hasCompleted(thisPlayer, "LSRockstar") and playerlevel == 10 then
			local rockstarSongs = require("Instruments/Tracks/AmbtRSTracks")
			for k,v in pairs(rockstarSongs) do
				if v.cat == Type then
					local length = v.length * 48

			--2 ADDING THE OPTION IN THE CONTEXT MENU
					contextMenu = v.name
					local subMenuOption = subMenu:addOptionOnTop(getText(contextMenu),
					worldobjects,
					NewInstrumentsContextMenu.onAction,
					thisPlayer,
					playableInstrument,
					Type,
					v.sound,
					length,
					v.level,
					false,
					false,false);

					subMenuOption.iconTexture = getTexture('media/ui/Ambitions/LSRockstar.png')
				end --if
			end --for
			end
			
		--3 PLAY A SONG FROM GROUP LEVEL - STARTS AT 1 TO AVOID REDUNDANCY
			if playerlevel > 1 then
		
		--3 ADDING GROUPS SUBMENU
			contextMenu = "ContextMenu_Play_Group_" .. tostring(Type)
		
			local buildOption = context:addOptionOnTop(getText(contextMenu));
			buildOption.iconTexture = getTexture('media/ui/moodles/MusicGood.png')
			local parentMenu = ISContextMenu:getNew(context);
			context:addSubMenu(buildOption, parentMenu)
		
			--3A ADDING BEGINNER LEVEL GROUP SUBMENU 0-1
			contextMenu = "ContextMenu_Play_Beginner_" .. tostring(Type)
		
			local beginnerMenu = parentMenu:addOptionOnTop(getText(contextMenu));
		
			local subMenuA = parentMenu:getNew(parentMenu);
			context:addSubMenu(beginnerMenu, subMenuA)
		
			for k,v in pairs(learnedTracksData) do
				if v.isaddon ~= 2 and v.level <= 1 and v.level <= playerlevel then
					local length = v.length * 48
			
				--3A ADDING THE OPTION FOR BEGINNER SONGS IN THE CONTEXT MENU
					contextMenu = v.name
					local subMenuAOption = subMenuA:addOptionOnTop(getText(contextMenu),
					worldobjects,
					NewInstrumentsContextMenu.onAction,
					thisPlayer,
					playableInstrument,
					Type,
					v.sound,
					length,
					v.level,
					false,
					false,false);

					if v.isaddon ~= 0 then
						subMenuAOption.iconTexture = getTexture('media/ui/addon_icon.png')
					end
				end
			end
		
		
			if playerlevel > 2 then
		
			--3B ADDING EXPERIENCED LEVEL GROUP SUBMENU 2-3
			contextMenu = "ContextMenu_Play_Experienced_" .. tostring(Type)
		
			local experiencedMenu = parentMenu:addOptionOnTop(getText(contextMenu));
		
			local subMenuB = parentMenu:getNew(parentMenu);
			context:addSubMenu(experiencedMenu, subMenuB)
		
			for k,v in pairs(learnedTracksData) do
				if v.isaddon ~= 2 and v.level > 1 and v.level <= 3 and v.level <= playerlevel then
					local length = v.length * 48
			
			--3B ADDING THE OPTION FOR EXPERIENCED SONGS IN THE CONTEXT MENU
					contextMenu = v.name

					local subMenuBOption = subMenuB:addOptionOnTop(getText(contextMenu),
					worldobjects,
					NewInstrumentsContextMenu.onAction,
					thisPlayer,
					playableInstrument,
					Type,
					v.sound,
					length,
					v.level,
					false,
					false,false);
					
					if v.isaddon ~= 0 then
						subMenuBOption.iconTexture = getTexture('media/ui/addon_icon.png')
					end
				end
			end
		
			if playerlevel > 4 then
			
			--3C ADDING INTERMEDIATE LEVEL GROUP SUBMENU 4-5
				contextMenu = "ContextMenu_Play_Intermediate_" .. tostring(Type)
			
				local intermediateMenu = parentMenu:addOptionOnTop(getText(contextMenu));
		
				local subMenuC = parentMenu:getNew(parentMenu);
				context:addSubMenu(intermediateMenu, subMenuC)
			
				for k,v in pairs(learnedTracksData) do
					if v.isaddon ~= 2 and v.level > 3 and v.level <= 5 and v.level <= playerlevel then
						local length = v.length * 48
				--3C ADDING THE OPTION FOR EXPERIENCED SONGS IN THE CONTEXT MENU
					contextMenu = v.name
				
					local subMenuCOption = subMenuC:addOptionOnTop(getText(contextMenu),
					worldobjects,
					NewInstrumentsContextMenu.onAction,
					thisPlayer,
					playableInstrument,
					Type,
					v.sound,
					length,
					v.level,
					false,
					false,false);
					
					if v.isaddon ~= 0 then
						subMenuCOption.iconTexture = getTexture('media/ui/addon_icon.png')
					end
				end
			end
			
			if playerlevel > 6 then
			
			--3D ADDING PROFICIENT LEVEL GROUP SUBMENU 6-7
				contextMenu = "ContextMenu_Play_Proficient_" .. tostring(Type)
			
				local proficientMenu = parentMenu:addOptionOnTop(getText(contextMenu));
		
				local subMenuD = parentMenu:getNew(parentMenu);
				context:addSubMenu(proficientMenu, subMenuD)
			
				for k,v in pairs(learnedTracksData) do
					if v.isaddon ~= 2 and v.level > 5 and v.level <= 7 and v.level <= playerlevel then
						local length = v.length * 48
				
			--3D ADDING THE OPTION FOR PROFICIENT SONGS IN THE CONTEXT MENU
					contextMenu = v.name
					local subMenuDOption = subMenuD:addOptionOnTop(getText(contextMenu),
					worldobjects,
					NewInstrumentsContextMenu.onAction,
					thisPlayer,
					playableInstrument,
					Type,
					v.sound,
					length,
					v.level,
					false,
					false,false);
					
					if v.isaddon ~= 0 then
						subMenuDOption.iconTexture = getTexture('media/ui/addon_icon.png')
					end
				end
			end
			
			if playerlevel > 8 then
				
			--3E ADDING EXPERT LEVEL GROUP SUBMENU 8-9
				contextMenu = "ContextMenu_Play_Advanced_" .. tostring(Type)
			
				local expertMenu = parentMenu:addOptionOnTop(getText(contextMenu));
		
				local subMenuE = parentMenu:getNew(parentMenu);
				context:addSubMenu(expertMenu, subMenuE)
			
				for k,v in pairs(learnedTracksData) do
					if v.isaddon ~= 2 and v.level > 7 and v.level <= 9 and v.level <= playerlevel then
						local length = v.length * 48
							
					--3E ADDING THE OPTION FOR EXPERT SONGS IN THE CONTEXT MENU
						contextMenu = v.name
				
						local subMenuEOption = subMenuE:addOptionOnTop(getText(contextMenu),
						worldobjects,
						NewInstrumentsContextMenu.onAction,
						thisPlayer,
						playableInstrument,
						Type,
						v.sound,
						length,
						v.level,
						false,
						false,false);
					
						if v.isaddon ~= 0 then
							subMenuEOption.iconTexture = getTexture('media/ui/addon_icon.png')
						end
					end
				end
			end -- if level > 8
			end -- if level > 6
			end -- if level > 4
			end -- if level > 2


	--3F ------------------------------------------ADDING DUETS GROUP SUBMENU Level > 3 -------------------------------
			if isClient() and playerlevel > 3 and InstrumentTracksDuet and (#learnedTracksData > 15) then
			--if isClient() and playerlevel > 3 and InstrumentTracksDuet then
--		if not isSitOnGround then

				LSInstrumentDuetOption(context, parentMenu, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentTracksDuet)

--			end -- if not sitonground
			end -- if level > 3 DUET
		
		end -- if level > 1


end

NewInstrumentsContextMenu.doBuildMenu = function(player, context, worldobjects, playableInstrument, ItemName)
 
    local thisPlayer = getSpecificPlayer(player)

	if not generalPlayerConditions(thisPlayer) then return; end
	if not generalItemConditions(thisPlayer, playableInstrument) then return; end

	local Type, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet = getInstrumetProperties(playableInstrument:getFullType(), thisPlayer:getModData(), false)
	local playerlevel = thisPlayer:getPerkLevel(Perks.Music)
	if Type then
	
		LSInstrumentPracticeOption(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)

		if learnedTracksData and (#learnedTracksData > 0) then
		----------------RANDOM
			if (#learnedTracksData > 1) then
		
				LSInstrumentRandomOption(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)

			end--RANDOM
		
		--2 ADDING THE SUBMENU TO PLAY SONGS YOUR LEVEL BY NAME
	
			LSInstrumentPlayOptions(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)
		
		end--LEARNEDTRACKS
	end
-------
------
end

NewInstrumentsContextMenu.doInventoryMenu = function(player, context, items, item)
    local thisPlayer = getSpecificPlayer(player)
	if not generalPlayerConditions(thisPlayer) then return; end
	if not generalItemConditions(thisPlayer, item) then return; end
	if not hotbarItemConditions(item, false) then return; end
	local Type, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet, playableInstrument = getInstrumetProperties(item:getFullType(), thisPlayer:getModData(), item)
	if (not Type) or (not playableInstrument) then return; end
	local playerlevel = thisPlayer:getPerkLevel(Perks.Music)
	----------------PRACTICE
	LSInstrumentPracticeOption(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)

	if learnedTracksData and (#learnedTracksData > 0) then
		----------------RANDOM
		if (#learnedTracksData > 1) then
			LSInstrumentRandomOption(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)
		end--RANDOM
		----------------LIST
		LSInstrumentPlayOptions(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)		
	end--LEARNEDTRACKS
-------
------
end

NewInstrumentsContextMenu.doHotbarMenu = function(player, context, items, item)
    local thisPlayer = getSpecificPlayer(player)
	if not generalPlayerConditions(thisPlayer) then return; end
	if not generalItemConditions(thisPlayer, item) then return; end
	if not hotbarItemConditions(item, true) then return; end
	local Type, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet, playableInstrument = getInstrumetProperties(item:getFullType(), thisPlayer:getModData(), item)

	if (not Type) or (not playableInstrument) then return; end

	local playerlevel = thisPlayer:getPerkLevel(Perks.Music)
	
	----------------PRACTICE
	LSInstrumentPracticeOption(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)

	if learnedTracksData and (#learnedTracksData > 0) then
		----------------RANDOM
		if (#learnedTracksData > 1) then
			LSInstrumentRandomOption(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)
		end--RANDOM
		----------------LIST
		LSInstrumentPlayOptions(context, worldobjects, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)
	end--LEARNEDTRACKS
-------
------
end


NewInstrumentsContextMenu.onAction = function(worldobjects, player, Item, Type, Sound, Length, Level, IsTraining, IsDuet, SoundVocal)
	--if NewInstrumentsContextMenu.walkToFront(player, TargetObject, Isfacing) then
	if not Item:isEquipped() then
		ISTimedActionQueue.add(ISEquipWeaponAction:new(player, Item, 50, true, false))
	end
	
	if SoundVocal and NewInstrumentsContextMenu.CheckMicrophone(player) then
		Sound = SoundVocal
	end
	
	if player:getModData().IsSittingOnSeat and player:getModData().IsSittingOnSeat == true and (Type == "Banjo" or Type == "GuitarAcoustic" or Type == "GuitarElectric" or Type == "GuitarElectricBass" or Type == "Keytar") then
		if player:getModData().IsSittingOnSeatSouth then
			player:setVariable("SittingToggleLoop", "IsLegAboveS")
			player:setVariable("IsSittingInChair", "IsPlayingGuitarS")
		else
			player:setVariable("SittingToggleLoop", "IsLegAbove")
			player:setVariable("IsSittingInChair", "IsPlayingGuitar")
		end
	end
	if IsTraining then
		ISTimedActionQueue.add(PlayInstrumentTraining:new(player, Item, Type, false));
	else
		ISTimedActionQueue.add(PlayInstrumentActionNew:new(player, Item, Type, Sound, Length, Level, IsTraining, IsDuet));
	end
	--end
end

NewInstrumentsContextMenu.CheckMicrophone = function(thisPlayer)

	local Mic
	
            for x = thisPlayer:getX()-8,thisPlayer:getX()+8 do
                for y = thisPlayer:getY()-8,thisPlayer:getY()+8 do
                    local square = getCell():getGridSquare(x,y,thisPlayer:getZ());
                    if square then
						for i=0,square:getObjects():size()-1 do
							local thisObject = square:getObjects():get(i)
						--for i=1,square:getObjects():size() do
							--local thisObject = square:getObjects():get(i-1)
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
									end
					
									if properties:has("GroupName") then
										groupName = properties:get("GroupName")
									end
					
									if properties:has("CustomName") then
										customName = properties:get("CustomName")
									end
					
									if customName == "Microphone" and groupName == "Standing" then
										Mic = thisObject;
										break
									end
								end--properties
							end--thissprite

                        end
                    end
                end
            end
	if Mic then 
		return true
	else
		return false
	end
end

local function doLearnAllSongsFull(allSongs, learnedTracksData)
	for k, v in ipairs (allSongs) do
		table.insert(learnedTracksData, v)
	end
end

local function doLearnAllSongsPartial(allSongs, learnedTracksData)
	local notLearned = {}
	for k, v in ipairs (allSongs) do
		local hasSong = false
		for n, j in ipairs(learnedTracksData) do
			if v.name == j.name then hasSong = true; break; end
		end
		if not hasSong then table.insert(learnedTracksData, v); end
	end
end

NewInstrumentsContextMenu.onDebug = function(worldobjects, player, Type, learnedTracksData, playerLevel)
	if not learnedTracksData then return; end

	local allSongs = getLearnableSongs(Type)
	if (not allSongs) or (allSongs and (#allSongs == 0)) then return; end
	if #learnedTracksData == 0 then
		doLearnAllSongsFull(allSongs, learnedTracksData)
	else
		doLearnAllSongsPartial(allSongs, learnedTracksData)
	end

end

--Events.OnFillWorldObjectContextMenu.Add(NewInstrumentsContextMenu.doBuildMenu);
--Events.OnPreFillInventoryObjectContextMenu.Add(NewInstrumentsContextMenu.doInventoryMenu);
--Events.OnFillInventoryObjectContextMenu.Add(NewInstrumentsContextMenu.doHotbarMenu);
