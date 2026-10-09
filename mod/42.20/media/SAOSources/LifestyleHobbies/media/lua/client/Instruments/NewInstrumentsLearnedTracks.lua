require('NPCs/MainCreationMethods');

local function NewInstrumentsLearnedTracksNewGame(_player)
	local player = _player

	player:getModData().HarmonicaLearnedTracks = {}
end

-- Adding compatibility with existing games
local function NewInstrumentsLearnedTracksAtStart()
	local player = getPlayer();
	if player:hasModData() then
		if not player:getModData().HarmonicaLearnedTracks then
			player:getModData().HarmonicaLearnedTracks = {}
		end
	end
end

Events.OnNewGame.Add(NewInstrumentsLearnedTracksNewGame)
Events.OnGameStart.Add(NewInstrumentsLearnedTracksAtStart)
