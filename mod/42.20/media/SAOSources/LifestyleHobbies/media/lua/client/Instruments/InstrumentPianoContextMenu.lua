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

InstrumentPianoContextMenu = {};

local function getLearnableSongs(Type)
	local learnableTracks = {}
	local allTracks = require("Instruments/Tracks/PlayPianoTracks")
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

local function getPianoAdjPiece(key)
	local t ={
		-- Western Piano
		recreational_01_8 = {"recreational_01_9","E"},
		recreational_01_9 = {"recreational_01_8","W"},
		recreational_01_12 = {"recreational_01_13","N"},
		recreational_01_13 = {"recreational_01_12","S"},
		recreational_01_28 = {"recreational_01_29","E"},
		recreational_01_29 = {"recreational_01_28","W"},
		recreational_01_30 = {"recreational_01_31","N"},
		recreational_01_31 = {"recreational_01_30","S"},
		-- Grand Piano
		recreational_01_40 = {"recreational_01_41","E"},
		recreational_01_41 = {"recreational_01_40","W"},
		recreational_01_48 = {"recreational_01_49","N"},
		recreational_01_49 = {"recreational_01_48","S"},
		recreational_01_108 = {"recreational_01_109","E"},
		recreational_01_109 = {"recreational_01_108","W"},
		recreational_01_99 = {"recreational_01_96","N"},
		recreational_01_96 = {"recreational_01_99","S"},
	}
	return t[key]
end

local function getAdjObj(mainObj, spriteName)
	--print("------------WARN: getAdjObj - spriteName is "..tostring(spriteName))
	local square = mainObj:getSquare()
	if not square then return false; end
	local objVars, adjObject = getPianoAdjPiece(spriteName), false
	if objVars then
		local objAdjSqr = square:getAdjacentSquare(IsoDirections[objVars[2]])
		if not objAdjSqr then return false; end
		for i=1,objAdjSqr:getObjects():size() do
			local obj = objAdjSqr:getObjects():get(i-1)
			if obj then
				local objName = obj:getSpriteName() or obj:getTextureName()
				if objName and objName == objVars[1] then adjObject = obj; break; end
			end
		end
	end
	return adjObject
end

local function isValidObj(obj, spriteName)
	if not obj or not instanceof(obj, "IsoObject") then return false; end
	local adjObj = getAdjObj(obj, spriteName)
	return adjObj
end

local function getValidPlayer(player)
	if not player then return false; end
	local character = getSpecificPlayer(player)
	if not character or not instanceof(character, "IsoPlayer") then return false; end
	if not character:hasModData() or character:hasTrait(CharacterTrait.DEAF) or character:getVehicle() or character:isSneaking() or character:isDead() or character:hasTimedActions() then return false; end
	return character
end

local function getNewTooltip(description)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	return tooltip
end

local function isValidRandomSong(song, threshold)
	return song.level >= threshold
end

local function doPracticeOption(parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName)
	local debugOption
    if LSUtil.hasAdminRights() then
		debugOption = parentMenu:addOptionOnTop(getText("ContextMenu_LSDebug_LearnAllSongs"),worldobjects,InstrumentPianoContextMenu.onDebug,character,Type,learnedTracksData,playerLevel)
		debugOption.iconTexture = getTexture('media/ui/BugIcon.png')
	end
	local text, option = "ContextMenu_Play_Instrument_Practice", parentMenu:addOptionOnTop(getText("ContextMenu_Play_Practice_Piano"),worldobjects,InstrumentPianoContextMenu.onAction,character,Piano,Type,spriteName,{false,false,playerLevel,true,false})

	if learnedTracksData and (#learnedTracksData > 0) and (not hasSongsToLearn(Type, learnedTracksData)) then
		text = "Tooltip_PracticeInstrument_KnowAll"
		if debugOption then
			debugOption.notAvailable = true
			debugOption.toolTip = getNewTooltip(getText(text))
		end
	end

	option.toolTip = getNewTooltip(getText(text))
	option.iconTexture = getTexture('media/ui/piano_icon.png')
end

local function doRandomOption(parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData,spriteName)
	local t, low = {}, {}
	for k,v in pairs(learnedTracksData) do
		if v.isaddon ~= 2 and v.level <= playerLevel then
			if playerLevel > 3 and isValidRandomSong(v, 2) then
				table.insert(t, v)
			else
				table.insert(low, v)
			end
		end
	end
	if #t <= 10 and #low > 0 then
		for n=1, #low do
			table.insert(t, low[n])
		end
	end
	if #t < 2 then return; end

	local rSong = t[ZombRand(#t)+1]
	local option = parentMenu:addOptionOnTop(getText("ContextMenu_Play_Random_Piano"),worldobjects,InstrumentPianoContextMenu.onAction,character,Piano,Type,spriteName,{rSong.sound,rSong.length*48,rSong.level,false,false})
	option.iconTexture = getTexture('media/ui/piano_icon.png')
end

local function getOptionLevelList(key)
	t = {
		[1] = "Beginner",
		[3] = "Experienced",
		[5] = "Intermediate",
		[7] = "Proficient",
		[9] = "Advanced",
	}
	t[8] = t[9]; t[6] = t[7]; t[4] = t[5]; t[2] = t[3]; t[0] = t[1];
	return t[key]
end

local function doLevelOption(context, parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName)
	local menuText = "ContextMenu_Play_Master_Piano"
	if playerLevel < 10 then menuText = "ContextMenu_Play_L".. playerLevel.."_Piano"; end

	local optionTable = {}

	for k,v in pairs(learnedTracksData) do
		if v.isaddon ~= 2 and v.level <= playerLevel then
			local option
			if v.level == playerLevel then
				if not optionTable.levelOption then
					optionTable.levelOption = parentMenu:addOption(getText(menuText))
					optionTable.levelOption.iconTexture = getTexture('media/ui/piano_icon.png')
					optionTable.subLevelMenu = parentMenu:getNew(parentMenu)
					context:addSubMenu(optionTable.levelOption, optionTable.subLevelMenu)
				end
				option = optionTable.subLevelMenu:addOption(getText(v.name),worldobjects,InstrumentPianoContextMenu.onAction,character,Piano,Type,spriteName,{v.sound,v.length*48,v.level,false,false})
			else
				if not optionTable.groupOption then
					optionTable.groupOption = parentMenu:addOption(getText("ContextMenu_Play_Group_Piano"))
					optionTable.groupOption.iconTexture = getTexture('media/ui/piano_icon.png')
					optionTable.groupSubMenu = parentMenu:getNew(parentMenu)
					context:addSubMenu(optionTable.groupOption, optionTable.groupSubMenu)
				end
				local optionName = getOptionLevelList(v.level)
				if optionName then
					if not optionTable[optionName.."Option"] then
						optionTable[optionName.."Option"] = optionTable.groupSubMenu:addOptionOnTop(getText("ContextMenu_Play_"..optionName.."_Piano"))
						optionTable[optionName.."subMenu"] = optionTable.groupSubMenu:getNew(optionTable.groupSubMenu)
						context:addSubMenu(optionTable[optionName.."Option"], optionTable[optionName.."subMenu"])						
					end
					option = optionTable[optionName.."subMenu"]:addOption(getText(v.name),worldobjects,InstrumentPianoContextMenu.onAction,character,Piano,Type,spriteName,{v.sound,v.length*48,v.level,false,false})
				end
			end
			if option and not v.isaddon or (v.isaddon and v.isaddon == 1) then option.iconTexture = getTexture('media/ui/addon_icon.png'); end
		end
	end
end

local function getKeyInstrumentValue(key)
	local t = {
		guitaracoustic = {"GuitarAcoustic","guitaracoustic"},
		guitarelectric = {"GuitarElectric","guitarelectric"},
		guitarelectricbass = {"GuitarElectricBass","guitarelectricbass"},
		keytar = {"Keytar","keytar"},
		flute = {"Flute","flute"},
		saxophone = {"Saxophone","saxophone"},
		banjo = {"Banjo","banjo"},
		trumpet = {"Trumpet","trumpet"},
		violin = {"Violin","violin"},
		harmonica = {"Harmonica","harmonica"},
		drums = {"Drums","drums"},
		piano = {"Piano","piano"},
		vocalm = {"VocalM","vocalM"},
		vocalf = {"VocalF","vocalF"},
	}
	return t[key]
end

local function getInstrumentKeys()
	return {"guitaracoustic","guitarelectric","guitarelectricbass","keytar","flute","saxophone","banjo","trumpet","violin","harmonica","drums","piano","vocalm","vocalf"}
end

local function doDuetOption(context, parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName)
	local duetMenu = parentMenu:addOption(getText("ContextMenu_Play_Duet_Piano"))
	local subMenu = parentMenu:getNew(parentMenu)
	context:addSubMenu(duetMenu, subMenu)
	
	local duetToolTip = getNewTooltip("ContextMenu_Play_Duet_InstrumentsNeeded")
	local t = require("Instruments/Tracks/PlayPianoTracksDuet")
	local instrumentTable = getInstrumentKeys()
				
	for k,v in pairs(t) do
		if v.level <= playerLevel then
			local option = subMenu:addOption(getText(v.name),worldobjects,InstrumentPianoContextMenu.onAction,character,Piano,Type,spriteName,{v.sound,v.length*48,v.level,false,true}) --isTraining, isDuet
			local optionSubMenu = parentMenu:getNew(parentMenu)
			context:addSubMenu(option, optionSubMenu)
			for n=1, #instrumentTable do
				local key = instrumentTable[n]
				if v[key] and v[key] == 1 then
					local vars = getKeyInstrumentValue(key)
					if vars then
						local keyOption = optionSubMenu:addOption(getText("ContextMenu_"..vars[1]))
						keyOption.iconTexture = getTexture('media/ui/'..vars[2]..'_icon.png')
						keyOption.toolTip = duetToolTip
					end
				end
			end
		end
	end
end

local function doPlayOptions(context, parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName)
	if playerLevel < 2 or not learnedTracksData or (learnedTracksData and (type(learnedTracksData) ~= "table" or #learnedTracksData <= 0)) then return; end
	--randomOption
	if #learnedTracksData > 1 then doRandomOption(parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName); end
	--byLevelOption
	doLevelOption(context, parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName)
	--duetOption
	if isClient() and playerLevel > 3 and (#learnedTracksData > 8) then doDuetOption(context, parentMenu, worldobjects, character, Piano, Type, playerLevel, learnedTracksData, spriteName); end
end

local function getDisableConditions(character, obj, playerSqr)
	local disable, text
	local pianoSqr = obj:getSquare()
	local pianoX, pianoY = pianoSqr:getX(), pianoSqr:getY()
	local playerX, playerY = playerSqr:getX(), playerSqr:getY()
	if not character:isSittingOnFurniture() then
		disable, text = true, " <RED>" .. getText("Tooltip_Play_NotSittedPianoStool")
	elseif pianoX > playerX+1 or pianoX < playerX-1 or pianoY > playerY+1 or pianoY < playerY-1 or not character:isFacingObject(obj,0.8) then
		disable, text = true, " <RED>" .. getText("ContextMenu_Play_Piano_TooFar")
	end
	return disable, text
end

InstrumentPianoContextMenu.doBuildMenu = function(player, context, worldobjects, Piano, spriteName, customName, groupName, DebugBuildOption)
	if not isValidObj(Piano, spriteName) then return; end
	local character = getValidPlayer(player)
	if not character then return; end
	local pianoName = LSUtil.getMoveableDisplayName("PIANO", Piano, customName, groupName)
	local playerData, pianoOption = character:getModData(), context:addOptionOnTop(pianoName)

	local disable, text = getDisableConditions(character, Piano, character:getSquare())
	if disable then
		pianoOption.notAvailable = true
		pianoOption.toolTip = getNewTooltip(text)
		pianoOption.iconTexture = getTexture('media/ui/pianoNo_icon.png')
		return
	end

	pianoOption.iconTexture = getTexture('media/ui/piano_icon.png')
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(pianoOption, subMenu)

	local Type = "Conventional" -- might use later to differentiate between piano types
	local playerLevel = character:getPerkLevel(Perks.Music)

	doPracticeOption(subMenu, worldobjects, character, Piano, Type, playerLevel, playerData.PianoLearnedTracks, spriteName)

	doPlayOptions(context, subMenu, worldobjects, character, Piano, Type, playerLevel, playerData.PianoLearnedTracks, spriteName)

end

local function isValidPlayer(character, playerData, obj, playerSqr)
	if not character:isSittingOnFurniture() or not character:isFacingObject(obj,0.8) then return false; end
	local pianoSqr = obj:getSquare()
	local pianoX, pianoY = pianoSqr:getX(), pianoSqr:getY()
	local playerX, playerY = playerSqr:getX(), playerSqr:getY()
	if pianoX > playerX+1 or pianoX < playerX-1 or pianoY > playerY+1 or pianoY < playerY-1 then return false; end
	if character:hasTrait(CharacterTrait.DEAF) or character:getVehicle() or character:isSneaking() or character:isDead() or character:hasTimedActions() then return false; end
	return true
end

InstrumentPianoContextMenu.onAction = function(worldobjects, character, Piano, Type, spriteName, args) --Sound, Length, Level, IsTraining, IsDuet
	if not isValidObj(Piano, spriteName) then return; end
	if not isValidPlayer(character, character:getModData(), Piano, character:getSquare()) then return; end
	if args[4] then
		ISTimedActionQueue.add(PlayInstrumentTraining:new(character, spriteName, "Piano", Piano))
	else
		ISTimedActionQueue.add(PlayInstrumentActionNew:new(character, spriteName, "Piano", args[1], args[2], args[3], false, args[5], Piano))
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

InstrumentPianoContextMenu.onDebug = function(worldobjects, player, Type, learnedTracksData, playerLevel)
	if not learnedTracksData then return; end

	local allSongs = getLearnableSongs(Type)
	if (not allSongs) or (allSongs and (#allSongs == 0)) then return; end
	if #learnedTracksData == 0 then
		doLearnAllSongsFull(allSongs, learnedTracksData)
	else
		doLearnAllSongsPartial(allSongs, learnedTracksData)
	end

end
