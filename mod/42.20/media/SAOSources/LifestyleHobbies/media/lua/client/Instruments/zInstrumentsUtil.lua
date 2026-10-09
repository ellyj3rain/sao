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

local function getLearnableSongs(lib)
	local learnableTracks = {}
	local allTracks = require(lib)
	if allTracks and (#allTracks > 0) then
		for k,v in pairs(allTracks) do
			if v.isaddon ~= 2 then
				table.insert(learnableTracks, v)
			end
		end
	end
	return learnableTracks
end


local function getSongsLib()
	return {
		{name="Harmonica",data="HarmonicaLearnedTracks"},
		{name="Banjo",data="BanjoLearnedTracks"},
		{name="GuitarElectricBass",data="GuitarEBLearnedTracks"},
		{name="GuitarAcoustic",data="GuitarALearnedTracks"},
		{name="GuitarElectric",data="GuitarELearnedTracks"},
		{name="Flute",data="FluteLearnedTracks"},
		{name="Trumpet",data="TrumpetLearnedTracks"},
		{name="Keytar",data="KeytarLearnedTracks"},
		{name="Saxophone",data="SaxophoneLearnedTracks"},
		{name="Violin",data="ViolinLearnedTracks"},
	}
end

local function checkForRemovedSongs(learnedTracks, songsLib, Type)
	--print("checkForRemovedSongs - start for: "..Type)
	local learnedTracksNew = {}
		for k, v in ipairs(learnedTracks) do
			local enable = false
			for n, j in ipairs(songsLib) do
				if v.name == j.name then enable = true; break; end
			end
			if enable then table.insert(learnedTracksNew, v); end
			if not enable then print("WARNING: checkForRemovedSongs - couldn't find song: "..v.name.." ..removing"); end
		end
	return learnedTracksNew
end

local function getTracks(lib)
	local allLearnableTracks = getLearnableSongs(lib)
	if not allLearnableTracks or (allLearnableTracks and (#allLearnableTracks == 0)) then return false; end
	return allLearnableTracks
end

local function checkLearnedSongs(player)
	local playerData = player:getModData()
	--print("checkLearnedSongs - start")
	if playerData.PianoLearnedTracks and (#playerData.PianoLearnedTracks) then
		local allLearnableTracks = getTracks("Instruments/Tracks/PlayPianoTracks")
		if allLearnableTracks then playerData.PianoLearnedTracks = checkForRemovedSongs(playerData.PianoLearnedTracks, allLearnableTracks, "piano"); end
	end
	
	for k, v in ipairs(getSongsLib()) do
		if playerData[v.data] and (#playerData[v.data] > 0) then
			local allLearnableTracks = getTracks("TimedActions/Play"..v.name.."Tracks")
			if allLearnableTracks then playerData[v.data] = checkForRemovedSongs(playerData[v.data], allLearnableTracks, v.name); end
		end
	end
	--print("checkLearnedSongs - end")
end

local function shuffleSongs(t)
    for i = #t, 2, -1 do
        local j = ZombRand(i) + 1
        t[i], t[j] = t[j], t[i]
    end
	return {t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8]}
end

local function addTraitBonusSongs(songsLib, Type)
	--print("addTraitBonusSongs - start for: "..Type)
	local learnedTracksNew = shuffleSongs(songsLib)
	--[[
	for i, song in ipairs(learnedTracksNew) do
		print(song.name)
	end
	]]--
	return learnedTracksNew
end

local function shuffleInstruments(t)
    for i = #t, 2, -1 do
        local j = ZombRand(i) + 1
        t[i], t[j] = t[j], t[i]
    end
	return t[1], t[2], t[3]
end

local function getRandomInstruments()
	local instruments = {"Harmonica","Banjo","GuitarElectricBass","GuitarAcoustic","GuitarElectric","Flute","Trumpet","Keytar","Saxophone","Violin"}
	local inst1, inst2, inst3 = shuffleInstruments(instruments)
	return {inst1, inst2, inst3}
end

local function getLearnableSongsByLevel(lib, lvl)
	local learnableTracks = {}
	local allTracks = require(lib)
	if allTracks and (#allTracks > 0) then
		for k,v in pairs(allTracks) do
			if (v.isaddon ~= 2) and (v.level <= lvl) then
				table.insert(learnableTracks, v)
			end
		end
	end
	return learnableTracks
end

local function getTracksByLevel(lib, lvl)
	local allLearnableTracks = getLearnableSongsByLevel(lib, lvl)
	if not allLearnableTracks or (allLearnableTracks and (#allLearnableTracks == 0)) then return false; end
	return allLearnableTracks
end

local function chooseInstruments(player)
	local playerData = player:getModData()
	local chosenInstruments = getRandomInstruments()
	if not chosenInstruments then return; end
	for i, instrument in ipairs(chosenInstruments) do
		for k, v in ipairs(getSongsLib()) do
			if playerData[v.data] and (v.name == instrument) then
				local allLearnableTracks = getTracksByLevel("TimedActions/Play"..v.name.."Tracks", 4)
				if allLearnableTracks then playerData[v.data] = addTraitBonusSongs(allLearnableTracks, v.name); end
			end
		end
	end
end

local function bonusCheckDone(player)
	local playerData = player:getModData()
	if playerData.virtuosoCheck then return true; end
	if not player:hasTrait(CharacterTrait.VIRTUOSO) then playerData.virtuosoCheck = true; return true; end
	if (tonumber(player:getHoursSurvived()) >= 1) then playerData.virtuosoCheck = true; return true; end
	playerData.virtuosoCheck = true
	return false
end

local function checkTraitBonusSongs(player)
	if bonusCheckDone(player) then return; end
	chooseInstruments(player)
end

function InstrumentsUtilOnCreatePlayer(player)
	--print("InstrumentsUtilOnCreatePlayer - start")
	checkLearnedSongs(player)
	checkTraitBonusSongs(player)

end