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

VocalContextMenu = {};

VocalContextMenu.doBuildMenu = function(player, context, worldobjects, Mic, spriteName, customName, groupName, DebugBuildOption)
	--if not isClient() then return; end
	if not Mic then return; end
    local thisPlayer = getSpecificPlayer(player)
	if not thisPlayer then return; end	
    if thisPlayer:getVehicle() then return; end
	if thisPlayer:isSitOnGround() then return; end
	if thisPlayer:isSneaking() then return; end
	local playerdata
	if thisPlayer:hasModData() then
		playerdata = thisPlayer:getModData()
	else
	return; end
	if thisPlayer:hasTrait(CharacterTrait.DEAF) then return; end
	
	local playerlevel = thisPlayer:getPerkLevel(Perks.Music)
	
	if playerlevel < 4 then

		local RefuseOption = context:addOptionOnTop(getText("ContextMenu_Play_NotEnoughLevel"));
		
		RefuseOption.notAvailable = true;
		RefuseOption.iconTexture = getTexture('media/ui/vocal_icon.png')

	else

	local contextMenu
	local PlayerGender
	local micIcon = getTexture('media/ui/vocalM_icon.png')
	if thisPlayer:getDescriptor():isFemale() then
		PlayerGender = "Female"
		micIcon = getTexture('media/ui/vocalF_icon.png')
	else
		PlayerGender = "Male"
	end
	--local instrumentAnimations = require("Instrument/InstrumentAnimations")

	if groupName == "Standing" then


	--3F ------------------------------------------ADDING DUETS GROUP SUBMENU Level > 3 -------------------------------

--		if not isSitOnGround then
				

				contextMenu = "ContextMenu_Play_Duet_Vocal"
			
				local duetMenu = context:addOptionOnTop(getText(contextMenu));
				duetMenu.iconTexture = micIcon
		
				local subMenuF = ISContextMenu:getNew(context);
				context:addSubMenu(duetMenu, subMenuF)
		
				local DuetTooltip = ISToolTip:new();
				DuetTooltip:initialise();
				DuetTooltip:setVisible(false);
				DuetTooltip.description = getText("ContextMenu_Play_Duet_InstrumentsNeeded")
		
				local PlayVocalTracksDuet = require("Instruments/Tracks/PlayVocalTracksDuet")
					for k,v in pairs(PlayVocalTracksDuet) do
						if (v.level <= playerlevel) and (PlayerGender == v.actionType) then
						local length = v.length * 48
		
					--3F ADDING THE OPTION FOR DUET SONGS IN THE CONTEXT MENU
						contextMenu = v.name
						
						local SubMenuFoption = subMenuF:addOptionOnTop(getText(contextMenu),
						worldobjects,
						VocalContextMenu.onAction,
						thisPlayer,
						Mic,
						groupName,
						v.sound,
						length,
						v.level,
						false,
						true);
						
						local subsubMenu = subMenuF:getNew(subMenuF);
						context:addSubMenu(SubMenuFoption, subsubMenu)
				
						if v.guitaracoustic == 1 then				
							local subsubMenuGA = subsubMenu:addOption(getText("ContextMenu_GuitarAcoustic"))
							subsubMenuGA.iconTexture = getTexture('media/ui/guitaracoustic_icon.png')
							subsubMenuGA.toolTip = DuetTooltip
						end
						if v.guitarelectric == 1 then
							local subsubMenuGE = subsubMenu:addOption(getText("ContextMenu_GuitarElectric"))
							subsubMenuGE.iconTexture = getTexture('media/ui/guitarelectric_icon.png')
							subsubMenuGE.toolTip = DuetTooltip
						end
						if v.guitarelectricbass == 1 then
							local subsubMenuGEB = subsubMenu:addOption(getText("ContextMenu_GuitarElectricBass"))
							subsubMenuGEB.iconTexture = getTexture('media/ui/guitarelectricbass_icon.png')
							subsubMenuGEB.toolTip = DuetTooltip
						end
						if v.keytar == 1 then
							local subsubMenuK = subsubMenu:addOption(getText("ContextMenu_Keytar"))
							subsubMenuK.iconTexture = getTexture('media/ui/keytar_icon.png')
							subsubMenuK.toolTip = DuetTooltip
						end
						if v.flute == 1 then
							local subsubMenuF = subsubMenu:addOption(getText("ContextMenu_Flute"))
							subsubMenuF.iconTexture = getTexture('media/ui/flute_icon.png')
							subsubMenuF.toolTip = DuetTooltip
						end
						if v.saxophone == 1 then
							local subsubMenuS = subsubMenu:addOption(getText("ContextMenu_Saxophone"))
							subsubMenuS.iconTexture = getTexture('media/ui/saxophone_icon.png')
							subsubMenuS.toolTip = DuetTooltip
						end
						if v.banjo == 1 then
							local subsubMenuB = subsubMenu:addOption(getText("ContextMenu_Banjo"))
							subsubMenuB.iconTexture = getTexture('media/ui/banjo_icon.png')
							subsubMenuB.toolTip = DuetTooltip
						end
						if v.trumpet == 1 then
							local subsubMenuV = subsubMenu:addOption(getText("ContextMenu_Trumpet"))
							subsubMenuV.iconTexture = getTexture('media/ui/trumpet_icon.png')
							subsubMenuV.toolTip = DuetTooltip
						end
						if v.piano == 1 then
							local subsubMenuP = subsubMenu:addOption(getText("ContextMenu_Piano"))
							subsubMenuP.iconTexture = getTexture('media/ui/piano_icon.png')
							subsubMenuP.toolTip = DuetTooltip
						end
						if v.violin == 1 then
							local subsubMenuV = subsubMenu:addOption(getText("ContextMenu_Violin"))
							subsubMenuV.iconTexture = getTexture('media/ui/violin_icon.png')
							subsubMenuV.toolTip = DuetTooltip
						end
						if v.vocalm == 1 then
							local subsubMenuVM = subsubMenu:addOption(getText("ContextMenu_VocalM"))
							subsubMenuVM.iconTexture = getTexture('media/ui/vocalM_icon.png')
							subsubMenuVM.toolTip = DuetTooltip
						end
						if v.vocalf == 1 then
							local subsubMenuVF = subsubMenu:addOption(getText("ContextMenu_VocalF"))
							subsubMenuVF.iconTexture = getTexture('media/ui/vocalF_icon.png')
							subsubMenuVF.toolTip = DuetTooltip
						end
				--if v.drums == 1 then
				--local subsubMenuD = subsubMenu:addOption(getText("ContextMenu_Drums"))
				--subsubMenuD.iconTexture = getTexture('media/ui/drums_icon.png')
				--subsubMenuD.toolTip = DuetTooltip
				--end
				--if v.piano == 1 then
				--local subsubMenuP = subsubMenu:addOption(getText("ContextMenu_Piano"))
				--subsubMenuP.iconTexture = getTexture('media/ui/piano_icon.png')
				--subsubMenuP.toolTip = DuetTooltip
				--end
				--if v.harmonica == 1 then
				--local subsubMenuH = subsubMenu:addOption(getText("ContextMenu_Harmonica"))
				--subsubMenuH.iconTexture = getTexture('media/ui/harmonica_icon.png')
				--subsubMenuH.toolTip = DuetTooltip
				--end
					end
				end


	end
-------
	end--playerlevel
------
end

VocalContextMenu.onAction = function(worldobjects, character, obj, Type, Sound, Length, Level, IsTraining, IsDuet)
	--if VocalContextMenu.walkToFront(player, TargetObject, Isfacing) then
		--if ActionHelper.walkToFront(player, Mic) then
		if LSUtil.walkToFront(character, obj) then
			ISTimedActionQueue.add(PlayInstrumentVocal:new(character, obj, Type, Sound, Length, Level, IsTraining, IsDuet));
		end
	--end
end

--Events.OnFillWorldObjectContextMenu.Add(VocalContextMenu.doBuildMenu);
