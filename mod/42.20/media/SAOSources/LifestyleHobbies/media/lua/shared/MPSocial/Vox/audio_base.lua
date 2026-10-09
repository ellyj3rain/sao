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
--VOICE TRACKS
LSMPS = LSMPS or {}

LSMPS.audioLib = LSMPS.audioLib or {}
-- sex == false - neutral, no Man or Woman prefix
-- sex == "All" - both, has Man and Woman prefixes
-- sex == "Woman"/"Man" - sex specific

LSMPS.audioLib.base_interactions = {
	['Hey'] = {
		{name="Hey",total=9,sex="All"},
	},
	['Greet'] = {
		{name="Greet",total=3,sex="All"},
	},
}

LSMPS.audioLib.base_utterances = {
	['Positive'] = {
		{name="AgreeableUHU",total=3,sex="All"},
		{name="LikeHMM",total=3,sex="All"},
		{name="ListenAttentive",total=3,sex="All"},
	},
	['Negative'] = {
		{name="ConfusedHUH",total=4,sex="All"},
		{name="ListenBlowOff",total=3,sex="All"},
		{name="NegativeOOOU",total=4,sex="All"},
		{name="NoUHUH",total=2,sex="All"},
	},
	['Curious'] = {
		{name="CuriousOH",total=4,sex="All"},
		{name="IntriguedHMM",total=9,sex="All"},
	},
	['Bored'] = {
		{name="Bored",total=2,sex="All"},
	},
	['Indifferent'] = {
		{name="IndifferentHMM",total=5,sex="All"},
	},
	['Disappointed'] = {
		{name="DisappointedOH",total=3,sex="All"},
	},
}

LSMPS.audioLib.base_tell = { -- expo has 10, must fix audio file name
	['Expo'] = {
		{name="Expo",total=9,sex="All"},
	},
}