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

LS_DJBooth = LS_DJBooth or {}
LS_DJBooth.buttons = LS_DJBooth.buttons or {}
LS_DJBooth.loopBeat = 0

LS_DJBooth.soundKeys = {
	['scratch'] = 11,
	['rewind'] = 4,
	['woosh'] = 6,
	['impact'] = 5,
	['crowd'] = 4,
	['war'] = 4,
	['synth'] = 4,
	['airhorn'] = 3,
	['siren'] = 4,
}

LS_DJBooth.soundboard = {
--Numpad 1-9
	[79] = {mainKeys = "scratch", holdShift = ""}, --numpad 1 Scratches, shift is " " for next level
	[80] = {mainKeys = "rewind", holdShift = ""}, --numpad 2 Rewind, shift is " " for next level
	[81] = {mainKeys = "woosh", holdShift = ""}, --numpad 3 Woosh, shift is " " for next level
	[75] = {mainKeys = "impact", holdShift = ""}, --numpad 4 Impact, shift is " " for next level
	[76] = {mainKeys = "crowd", holdShift = ""}, --numpad 5 Crowd, shift is " " for next level
	[77] = {mainKeys = "war", holdShift = ""}, --numpad 6 War, shift is " " for next level
	[71] = {mainKeys = "synth", holdShift = ""}, --numpad 7 Synth, shift is " " for next level
	[72] = {mainKeys = "airhorn", holdShift = ""}, --numpad 8 Airhorn, shift is " " for next level
	[73] = {mainKeys = "siren", holdShift = ""}, --numpad 9 Sirens, shift is " " for next level
--Numpad 1-9
	[44] = {mainKeys = "electronickick", holdShift = ""}, --numpad 1 Scratches, shift is " " for next level
	[45] = {mainKeys = "kickdrum", holdShift = ""}, --numpad 2 Rewind, shift is " " for next level
	[46] = {mainKeys = "safarikick", holdShift = ""}, --numpad 3 Woosh, shift is " " for next level
	[47] = {mainKeys = "electronicsnaredrum", holdShift = ""}, --numpad 4 Impact, shift is " " for next level
	[48] = {mainKeys = "snare", holdShift = ""}, --numpad 1 Scratches, shift is " " for next level
	[49] = {mainKeys = "percussionsnap", holdShift = ""}, --numpad 2 Rewind, shift is " " for next level
	[50] = {mainKeys = "electronicclap", holdShift = ""}, --numpad 3 Woosh, shift is " " for next level
	[51] = {mainKeys = "openhat", holdShift = ""}, --numpad 4 Impact, shift is " " for next level
--Numbers 1-9
	[2] = {mainKeys = "", holdShift = "DJLoopsdrumbeats1", switch = 1}, --1 , shift is "Drum Loop 125BPM" for next level
	[3] = {mainKeys = "", holdShift = "DJLoopsdrumbeats2", switch = 1}, --2 , shift is "808 Loop 125BPM" for next level
	[4] = {mainKeys = "", holdShift = "DJLoopsdrumbeats3", switch = 1}, --2 , shift is "808 Loop 125BPM" for next level
	[5] = {mainKeys = "", holdShift = "DJLoopsdreamscape1", switch = 2}, --1 , shift is "Drum Loop 125BPM" for next level
	[6] = {mainKeys = "", holdShift = "DJLoopsdreamscape3", switch = 2}, --2 , shift is "808 Loop 125BPM" for next level
	[7] = {mainKeys = "", holdShift = "DJLoopsdreamscape2", switch = 2}, --2 , shift is "808 Loop 125BPM" for next level
	[8] = {mainKeys = "", holdShift = "DJLoopsdreamscape4", switch = 2}, --2 , shift is "808 Loop 125BPM" for next level
	[9] = {mainKeys = "", holdShift = "DJLoopselectrobeats1", switch = 3}, --1 , shift is "Drum Loop 125BPM" for next level
	[10] = {mainKeys = "", holdShift = "DJLoopselectrobeats2", switch = 3}, --2 , shift is "808 Loop 125BPM" for next level
	[11] = {mainKeys = "", holdShift = "DJLoopselectrobeats3", switch = 3}, --2 , shift is "808 Loop 125BPM" for next level
	[12] = {mainKeys = "", holdShift = "DJLoopselectrobeats4", switch = 3}, --2 , shift is "808 Loop 125BPM" for next level
	[19] = {mainKeys = "", holdShift = "DJLoopslofi1", switch = 4}, --1 , shift is "Drum Loop 125BPM" for next level
	[20] = {mainKeys = "", holdShift = "DJLoopslofi2", switch = 4}, --2 , shift is "808 Loop 125BPM" for next level
	[21] = {mainKeys = "", holdShift = "DJLoopslofi3", switch = 4}, --2 , shift is "808 Loop 125BPM" for next level
	[22] = {mainKeys = "", holdShift = "DJLoopslofi4", switch = 4}, --2 , shift is "808 Loop 125BPM" for next level

}