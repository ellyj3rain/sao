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


require('NPCs/MainCreationMethods');

local function getInstrumentDataName()
	return {"TrumpetLearnedTracks","GuitarALearnedTracks","BanjoLearnedTracks","KeytarLearnedTracks","SaxophoneLearnedTracks","GuitarEBLearnedTracks","GuitarELearnedTracks","FluteLearnedTracks",
	"PianoLearnedTracks","ViolinLearnedTracks"}
end

local function VanillaInstrumentsLearnedTracksNewGame(_player)
	local player = _player
	local t = getInstrumentDataName()
	for n=1, #t do
		player:getModData()[t[n]] = {}
	end
end

local function VanillaInstrumentsLearnedTracksAtStart()
	local player = getPlayer();
	if player:hasModData() then
		local t = getInstrumentDataName()
		for n=1, #t do
			player:getModData()[t[n]] = player:getModData()[t[n]] or {}
		end
	end
end

Events.OnNewGame.Add(VanillaInstrumentsLearnedTracksNewGame)
Events.OnGameStart.Add(VanillaInstrumentsLearnedTracksAtStart)
