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
require"Properties/Player/LSSOModulesLoad"

local function doPlayerCooldowns(playerData)

	--print("doPlayerCooldowns called")

	local cooldownList = getPlayerCooldowns(false)

	for n=1,#cooldownList do
		local value = cooldownList[n]
		--print("doPlayerCooldowns checking cooldown for " .. value)
		if not playerData.LSCooldowns then playerData.LSCooldowns = {}; end
		if not playerData.LSCooldowns[value] then
			playerData.LSCooldowns[value] = 0
		end
		if playerData.LSCooldowns[value] and (playerData.LSCooldowns[value] > 0) then
			playerData.LSCooldowns[value] = playerData.LSCooldowns[value] - 1
			--print("doPlayerCooldowns reducing cooldown by 1 for " .. value)
		end
		if playerData.LSCooldowns[value] and (playerData.LSCooldowns[value] < 0) then
			playerData.LSCooldowns[value] = 0
		end
	end


end

local function LSgetSandboxDividerOptions()
	return {
		{svar=SandboxVars.Text.DividerHygiene, moodles={"Attractive","BathCold","BathHot","BladderNeed","HygieneBad","HygieneGood","MintFresh","MintCurio","Nauseous","SmellGood"}},
		{svar=SandboxVars.Text.DividerMeditationNew, moodles={"WasTaughtMeditation","AtHouse","HomeSick","MindfulState"}},
		{svar=SandboxVars.Text.DividerMusicNew, moodles={"MusicBad","MusicGood","DJAudience"}},
		{svar=SandboxVars.Text.DividerDancingNew, moodles={"PartyBad","PartyGood"}},
		{svar=SandboxVars.Text.DividerArt, moodles={"BeautyGood"}},
		{shared={"DividerArt","DividerHygiene"}, moodles={"BeautyNeg"}},
	}
end

local function LSgetMoodlesToRemove()
	local MoodlesToRemove = {}
	local SandboxOptions = LSgetSandboxDividerOptions()
	for k, v in ipairs(SandboxOptions) do
		if v.shared then
			for n=1,#v.shared do
				if SandboxVars.Text[v.shared[n]] then v.svar = true; break; end
			end
		end
		if not v.svar then
			for n=1, #v.moodles do
				table.insert(MoodlesToRemove, v.moodles[n])
			end
		end
	end
	return MoodlesToRemove
end

function LSSOModules.Moodles.removeMoodlesFromCharacter(playerIndex, player)
	if not player:hasModData() then return; end
	local playerData = player:getModData()
	if not playerData.LSMoodles then return; end
	local MoodlesToRemove = LSgetMoodlesToRemove()
	if #MoodlesToRemove > 0 then
		for i=1, #MoodlesToRemove do
			--print("LSSOModules.Moodles.removeMoodlesFromCharacter look for moodle and remove it: "..MoodlesToRemove[i])
			local moodle = MoodlesToRemove[i]
			if playerData.LSMoodles[moodle] then playerData.LSMoodles[moodle].Value = 0; end
		end
	end
end

return LSSOModules.Moodles