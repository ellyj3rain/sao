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
		{svar=SandboxVars.Text.DividerHygiene, data={{name="hygieneNeed",val=50},{name="lastBrushTeeth",val=0},{name="lastCheckYourself",val=0},
		{name="hygieneNeedLimit",val=100},{name="IsDoingToilet",val=false},{name="bathroomNeed",val=0}}},
		{svar=SandboxVars.Text.DividerMeditationNew, data={{name="IsMeditationMindfulness",val="disabled"},{name="MeditationMindfulness",val=0}}},
		{svar=SandboxVars.Text.DividerMusicNew, data={{name="PianoLearnedTracks",val={}},{name="TrumpetLearnedTracks",val={}},{name="GuitarALearnedTracks",val={}},{name="BanjoLearnedTracks",val={}},{name="KeytarLearnedTracks",val={}},
		{name="SaxophoneLearnedTracks",val={}},{name="GuitarEBLearnedTracks",val={}},{name="GuitarELearnedTracks",val={}},{name="FluteLearnedTracks",val={}},{name="HarmonicaLearnedTracks",val={}},{name="ViolinLearnedTracks",val={}}}},
	}
end
--{svar=SandboxVars.Text.DividerDancingNew, data={"PartyBad","PartyGood"}},
local function LSgetDataToRemove()
	local DataToReset = {}
	local SandboxOptions = LSgetSandboxDividerOptions()
	for k, v in ipairs(SandboxOptions) do
		if not v.svar then
			for n=1, #v.data do
				table.insert(DataToReset, v.data[n])
			end
		end
	end
	return DataToReset
end

function LSSOModules.PlayerData.resetDataFromCharacter(playerIndex, player)
	if not player:hasModData() then return; end
	local playerData = player:getModData()
	local DataToReset = LSgetDataToRemove()
	if #DataToReset > 0 then
		for k, v in ipairs (DataToReset) do
			--print("LSSOModules.PlayerData.resetDataFromCharacter look for data and reset: "..DataToReset[i])
			if playerData[v.name] then playerData[v.name] = v.val; end
		end
	end
end

return LSSOModules.PlayerData