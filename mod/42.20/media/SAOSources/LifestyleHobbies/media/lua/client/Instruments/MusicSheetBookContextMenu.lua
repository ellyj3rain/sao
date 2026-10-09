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

require "ISUI/ISInventoryPane"

MusicSheetBookContextMenu = {};

local function getSongRarityColor(songLevel)
	local songRarity, rarityRGB = "Tooltip_SheetBook_SongCommon", " <RGB:0.6,0.9,0.5>"
	if songLevel <= 2 then return songRarity, rarityRGB; end
	if songLevel <= 4 then
		songRarity = "Tooltip_SheetBook_SongUncommon"
		rarityRGB = " <RGB:0.9,0.9,0.4>"
	elseif songLevel <= 6 then
		songRarity = "Tooltip_SheetBook_SongRare"
		rarityRGB = " <RGB:0.4,0.9,0.9>"
	elseif songLevel <= 8 then
		songRarity = "Tooltip_SheetBook_SongVeryRare"
		rarityRGB = " <RGB:0.8,0.4,0.9>"
	elseif songLevel <= 10 then
		songRarity = "Tooltip_SheetBook_SongLegendary"
		rarityRGB = " <RGB:0.9,0.4,0.4>"
	end
	return songRarity, rarityRGB
end

local function getSongToolip(songLevel)
	local songRarity, rarityRGB = getSongRarityColor(songLevel)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = getText("Tooltip_SheetBook_Rarity") .. rarityRGB .. getText(songRarity) .. " <RGB:1,1,1>" .. getText("Tooltip_SheetBook_SongLevelIs") .. (songLevel)
	return tooltip
end

local function getknowAnySong(thisPlayer, parentMenu, context, SheetBookData, sheetBook, penOrPencil)

	local knowAnySong

	-------TRUMPET
	if #thisPlayer:getModData().TrumpetLearnedTracks > 0 then
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Trumpet", "trumpet", "trumpet", parentMenu, context, thisPlayer, thisPlayer:getModData().TrumpetLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------GUITARACOUSTIC
	if #thisPlayer:getModData().GuitarALearnedTracks > 0 then
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("GuitarA", "guitarA", "guitaracoustic", parentMenu, context, thisPlayer, thisPlayer:getModData().GuitarALearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------BANJO
	if #thisPlayer:getModData().BanjoLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Banjo", "banjo", "banjo", parentMenu, context, thisPlayer, thisPlayer:getModData().BanjoLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------KEYTAR
	if #thisPlayer:getModData().KeytarLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Keytar", "keytar", "keytar", parentMenu, context, thisPlayer, thisPlayer:getModData().KeytarLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------SAXOPHONE
	if #thisPlayer:getModData().SaxophoneLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Saxophone", "sax", "saxophone", parentMenu, context, thisPlayer, thisPlayer:getModData().SaxophoneLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------GUITAR EB
	if #thisPlayer:getModData().GuitarEBLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("GuitarEB", "guitarEB", "guitarelectricbass", parentMenu, context, thisPlayer, thisPlayer:getModData().GuitarEBLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------GUITAR E
	if #thisPlayer:getModData().GuitarELearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("GuitarE", "guitarE", "guitarelectric", parentMenu, context, thisPlayer, thisPlayer:getModData().GuitarELearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------FLUTE
	if #thisPlayer:getModData().FluteLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Flute", "flute", "flute", parentMenu, context, thisPlayer, thisPlayer:getModData().FluteLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------PIANO
	if #thisPlayer:getModData().PianoLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Piano", "piano", "piano", parentMenu, context, thisPlayer, thisPlayer:getModData().PianoLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------HARMONICA
	if #thisPlayer:getModData().HarmonicaLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Harmonica", "harmonica", "harmonica", parentMenu, context, thisPlayer, thisPlayer:getModData().HarmonicaLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	-------VIOLIN
	if #thisPlayer:getModData().ViolinLearnedTracks > 0 then----
		knowAnySong = true
		MusicSheetBookContextMenu.doSubMenus("Violin", "violin", "violin", parentMenu, context, thisPlayer, thisPlayer:getModData().ViolinLearnedTracks, SheetBookData, sheetBook, penOrPencil)
	end

	return knowAnySong
end

MusicSheetBookContextMenu.doInventoryMenu = function(player, context, items, sheetBook)
 
    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
    --if thisPlayer:getVehicle() then return; end
	--if not thisPlayer:isSitOnGround() then return; end
	--if thisPlayer:isSneaking() then return; end
	
	local playerdata
	
	if thisPlayer:hasModData() then
		playerdata = thisPlayer:getModData()
	else
	return; end
	if thisPlayer:hasTrait(CharacterTrait.DEAF) then return; end
	
	local penOrPencil
	local learnedTracksData
	--[[
	local invItems = ISInventoryPane.getActualItems(items)

   -- for i = 1, #items do
        --if type(items[1]) == 'table' then
			--local item = items[1].items[1]
			--if Instrument[item:getFullType()] then
	local item
	for i,v in ipairs(invItems) do
--       item = v;
--       if not instanceof(v, "InventoryItem") then
--			item = v.items[1];
--        end
--		
--		if (item:isInPlayerInventory() == false) or
--		(thisPlayer:getInventory():contains(item) == false) or
--		item:getAttachedSlot() ~= -1
--		then
--			break
--		end

--		if item:getFullType() == 'Lifestyle.SheetMusicBook' then
--			sheetBook = item
		if v:getFullType() == 'Lifestyle.SheetMusicBook' and not sheetBook then
			sheetBook = v
			break
		end
	end
	]]--
	if not sheetBook then return; end

	local containerList = ArrayList.new();
	local playerNum = thisPlayer and thisPlayer:getPlayerNum() or -1
    for i,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end

--	if #containerList > 0 then
--		for i,v in ipairs(containerList:getItems()) do
		for i=0,containerList:size()-1 do
			if penOrPencil then
				break
			end
			local container = containerList:get(i);
			for x=0,container:getItems():size() - 1 do
				local v = container:getItems():get(x);
				if (v:getFullType() == "Pencil" or v:getFullType() == "Pen" or v:getFullType() == "RedPen" or v:getFullType() == "BluePen" or v:hasTag(ItemTag.WRITE)) and not penOrPencil then
					penOrPencil = v
					break
				end
			end
		end
--	end


	local contextMenu
	local playerlevel = thisPlayer:getPerkLevel(Perks.Music)
	


	if playerlevel < 2 then
	
	local RefuseOption = context:addOptionOnTop(getText("ContextMenu_SheetBook_LowSkill"));

	local tooltip = ISToolTip:new();
		tooltip:initialise();
		tooltip:setVisible(false);
		

		RefuseOption.notAvailable = true;
		description = " <RED>" .. getText("Tooltip_SheetBook_NotEnoughSkill");
		tooltip.description = description
		RefuseOption.toolTip = tooltip
		--RefuseOption.iconTexture = getTexture('media/ui/pianoNo_icon.png')

	else

	--table.insert(SheetBookData.InscribedSongs, {v,"piano"});

		local SheetBookData = sheetBook:getModData()
		local canLearn
		local canLearnAux

		MusicSheetBookContextMenu.onLoadModData(thisPlayer)

		if not SheetBookData.InscribedSongs then SheetBookData.InscribedSongs = {}; end

		---- Check songs
		local songNameList

		if #SheetBookData.InscribedSongs > 0 then

			for i, entry in ipairs(SheetBookData.InscribedSongs) do
    -- Access v and x from each entry

				local v = entry[1]  -- v is the first element of the entry
				local instrument = entry[2]  -- x is the second element of the entry
				local songName = v.name
				local songLevel = v.level
				local instrumentName
				
				canLearn, instrumentName = MusicSheetBookContextMenu.onCanLearn(thisPlayer, v, instrument, instrumentName, playerlevel)

				songNameList = MusicSheetBookContextMenu.onGetList(songLevel, songNameList, songName, instrumentName)
			
				if canLearn then canLearnAux = true; end 
			
			end

			local tooltipText = getText("Tooltip_SheetBook_ItemHeaderStart") .. #SheetBookData.InscribedSongs .. getText("Tooltip_SheetBook_ItemHeaderEnd")
			sheetBook:setTooltip(tooltipText)

		end

		----RENAME

			local RenameOption = context:addOptionOnTop(getText("ContextMenu_Rename"),
			sheetBook,
			MusicSheetBookContextMenu.onRenaming,
			thisPlayer);

		----INFO
		if #SheetBookData.InscribedSongs > 0 then

			local InfoOption = context:addOptionOnTop(getText("ContextMenu_Info"));

			local tooltip = ISToolTip:new();
			tooltip:initialise();
			tooltip:setVisible(false);
			tooltip:setName(getText("Tooltip_SheetBook_InfoHeader"))
			description = songNameList

			tooltip.description = description
			InfoOption.toolTip = tooltip

		end
		----READ

			local doReadOption = context:addOptionOnTop(getText("ContextMenu_SheetBook_Read"),
			false,
			MusicSheetBookContextMenu.onAction,
			thisPlayer,
			sheetBook,
			600,
			false,
			false,
			false);

			local tooltipRead = ISToolTip:new();
				tooltipRead:initialise();
				tooltipRead:setVisible(false);

			if #SheetBookData.InscribedSongs <= 0 then--disable the option
				doReadOption.notAvailable = true;
				descriptionR = " <RED>" .. getText("Tooltip_SheetBook_NothingToRead");
				tooltipRead.description = descriptionR
				doReadOption.toolTip = tooltipRead
				doReadOption.iconTexture = getTexture('media/ui/bookReadNo_icon.png')
			elseif not canLearnAux then
				doReadOption.notAvailable = true;
				descriptionR = " <RED>" .. getText("Tooltip_SheetBook_CantLearn");
				tooltipRead.description = descriptionR
				doReadOption.toolTip = tooltipRead
				doReadOption.iconTexture = getTexture('media/ui/bookReadNo_icon.png')
			else
				doReadOption.iconTexture = getTexture('media/ui/bookRead_icon.png')
			end


		-----WRITE
		
		--if #SheetBookData.InscribedSongs < (8+playerlevel) then
		
		local knowAnySong
		
	--	thisPlayer:getModData().TrumpetLearnedTracks
	--	thisPlayer:getModData().GuitarALearnedTracks
	--	thisPlayer:getModData().BanjoLearnedTracks
	--	thisPlayer:getModData().KeytarLearnedTracks
	--	thisPlayer:getModData().SaxophoneLearnedTracks
	--	thisPlayer:getModData().GuitarEBLearnedTracks
	--	thisPlayer:getModData().GuitarELearnedTracks
	--	thisPlayer:getModData().FluteLearnedTracks
	--	thisPlayer:getModData().PianoLearnedTracks

		
		contextMenu = "ContextMenu_SheetBook_Write"
		
		local buildOption = context:addOptionOnTop(getText(contextMenu));

		local tooltipWrite = ISToolTip:new();
			tooltipWrite:initialise();
			tooltipWrite:setVisible(false);

		if #SheetBookData.InscribedSongs >= (8+playerlevel) then
				buildOption.notAvailable = true;
				descriptionBO = " <RED>" .. getText("Tooltip_SheetBook_Full");
				tooltipWrite.description = descriptionBO
				buildOption.toolTip = tooltipWrite
				buildOption.iconTexture = getTexture('media/ui/bookWriteNo_icon.png')
		
		elseif not penOrPencil then
				buildOption.notAvailable = true;
				descriptionBO = " <RED>" .. getText("Tooltip_SheetBook_NoPenOrPencil");
				tooltipWrite.description = descriptionBO
				buildOption.toolTip = tooltipWrite
				buildOption.iconTexture = getTexture('media/ui/bookWriteNo_icon.png')
		
		else
			
			--buildOption.iconTexture = getTexture('media/ui/moodles/MusicGood.png')
			local parentMenu = ISContextMenu:getNew(context);
			context:addSubMenu(buildOption, parentMenu)

			knowAnySong = getknowAnySong(thisPlayer, parentMenu, context, SheetBookData, sheetBook, penOrPencil)

			if not knowAnySong then--disable the option
				buildOption.notAvailable = true;
				descriptionBO = " <RED>" .. getText("Tooltip_SheetBook_DontKnowAnySongs");
				tooltipWrite.description = descriptionBO
				buildOption.toolTip = tooltipWrite
				buildOption.iconTexture = getTexture('media/ui/bookWriteNo_icon.png')
			else
				buildOption.iconTexture = getTexture('media/ui/bookWrite_icon.png')
			end

		end--InscribedSongs
	end--playerlevel
-------
------
end

MusicSheetBookContextMenu.doSubMenus = function(InstrumentNameUC, InstrumentNameLC, InstrumentNameIC, parentMenu, context, thisPlayer, tracksData, SheetBookData, sheetBook, penOrPencil)

	contextMenu = "ContextMenu_SheetBook_" .. InstrumentNameUC
		
	local instrumentMenu = parentMenu:addOption(getText(contextMenu));
	instrumentMenu.iconTexture = getTexture('media/ui/' .. InstrumentNameIC .. '_icon.png')
		
	local subMenuA = parentMenu:getNew(parentMenu);
	context:addSubMenu(instrumentMenu, subMenuA)
				
	for n=0, thisPlayer:getPerkLevel(Perks.Music) do
		for k,v in pairs(tracksData) do
			if (v.level == n) and (v.isaddon ~= 2) then
				local alreadyInBook
					
				if #SheetBookData.InscribedSongs > 0 then
					for i, entry in ipairs(SheetBookData.InscribedSongs) do
						local song = entry[1]
						local instrument = entry[2]
						if instrument == InstrumentNameLC then
							if v.name == song.name then
								alreadyInBook = true
								break
							end
						end
					end
				end
			
				local writingTime = 300*(v.level+1)
				contextMenu = getText(v.name)
				
				local subMenuAOption = subMenuA:addOption(getText(contextMenu),
				false,
				MusicSheetBookContextMenu.onAction,
				thisPlayer,
				sheetBook,
				writingTime,
				v,
				InstrumentNameLC,
				penOrPencil);

				subMenuAOption.toolTip = getSongToolip(v.level)

				if alreadyInBook then
					subMenuAOption.notAvailable = true;
				elseif v.isaddon ~= 0 then
					subMenuAOption.iconTexture = getTexture('media/ui/addon_icon.png')
				end
			end
		end
	end
end


--Events.OnPreFillInventoryObjectContextMenu.Add(MusicSheetBookContextMenu.doInventoryMenu);
