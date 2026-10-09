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

--
local musicStyles = {"disco","beach","classical","country","holiday","jazz","metal","muzak","pop","rap","rbsoul","reggae","rock","salsa","world"}
local musicStylesDislike = {"discono","beachno","classicalno","countryno","holidayno","jazzno","metalno","muzakno","popno","rapno","rbsoulno","reggaeno","rockno","salsano","worldno"}
-- new game
local function initPlayerTracker(_player)
	local player = _player
	--PlayTracker
	player:getModData().PlayTracker = {}
	--HaloCooldownCounter
	if not (player:getModData().HaloCooldownCounter) or (not (tonumber(player:getModData().HaloCooldownCounter))) then player:getModData().HaloCooldownCounter = 0; end
	--PlayerVoice
	if not (not player:getModData().PlayerVoice) or (not (tonumber(player:getModData().PlayerVoice))) then player:getModData().PlayerVoice = ZombRand(5); end
end

local function checkInventingRecipes(ogPlayer)
	local skillLevel = HiddenSkills.getLevel(ogPlayer, "Inventing")
	if not skillLevel or skillLevel < 9 then return; end
	local recipes = {"ConvertPartsMech","ConvertPartsElec","ConvertPartsPlumb","ConvertPartsWood"}
	for n=1,#recipes do
		local recipe = recipes[n]
		if not ogPlayer:isRecipeActuallyKnown(recipe) then
			LSUtil.learnRecipes(ogPlayer, recipes)
			break
		end
	end
end

local function checkMusicTraits(ogPlayer)
	local player = ogPlayer or LSUtil.getValidCharacter(getPlayer())
	if not player then return; end
	local playerData = player:getModData()
	if playerData.PlayerMusicLike and playerData.PlayerMusicDislike then
		local musicTraitPos, musicTraitNeg = string.upper(tostring(playerData.PlayerMusicLike)), string.upper(tostring(playerData.PlayerMusicDislike))
		if CharacterTrait[musicTraitPos] and player:hasTrait(CharacterTrait[musicTraitPos]) and
		CharacterTrait[musicTraitNeg] and player:hasTrait(CharacterTrait[musicTraitNeg]) then
			return
		end
	end

	--PlayerMusicTaste
	if not player:hasTrait(CharacterTrait.DEAF) and not player:hasTrait(CharacterTrait.TONEDEAF) then
		local musicTraitPos, musicTraitNeg
		for i=1, #musicStyles do
			local musicTrait = string.upper(musicStyles[i])
			if player:hasTrait(CharacterTrait[musicTrait]) then
				musicTraitPos = musicStyles[i]
				break
			end
		end
		for i=1, #musicStylesDislike do
			local musicTrait = string.upper(musicStylesDislike[i])
			if player:hasTrait(CharacterTrait[musicTrait]) then
				musicTraitNeg = musicStylesDislike[i]
				break
			end
		end
		if not musicTraitPos then
			local idxmusicStyles = ZombRand(#musicStyles) + 1
			local randomMusicStyle = musicStyles[idxmusicStyles]
			if musicTraitNeg and string.find(musicTraitNeg, randomMusicStyle) then
				for i=1, 20 do
					local newIdx = ZombRand(#musicStyles)+1
					randomMusicStyle = musicStyles[newIdx]
					if not string.find(musicTraitNeg, randomMusicStyle) then break; end
				end
			end
			
			local traitName = string.upper(randomMusicStyle)
			if isClient() then
				sendClientCommand(player, "LS", "ChangeTrait", {traitName, "add"})
			else
				player:getCharacterTraits():add(CharacterTrait[traitName]);
				player:modifyTraitXPBoost(CharacterTrait[traitName], false);
				SyncXp(player)
			end
			playerData.PlayerMusicLike = randomMusicStyle
			HaloTextHelper.addTextWithArrow(player, getText("UI_trait_" .. randomMusicStyle), true, HaloTextHelper.getColorGreen())
			musicTraitPos = randomMusicStyle
		else
			playerData.PlayerMusicLike = musicTraitPos
		end
		if not musicTraitNeg then
			local idxmusicStyles = ZombRand(#musicStylesDislike) + 1
			local randomMusicStyle = musicStylesDislike[idxmusicStyles]
			if musicTraitPos and string.find(randomMusicStyle, musicTraitPos) then
				for i=1, 20 do
					local newIdx = ZombRand(#musicStylesDislike)+1
					randomMusicStyle = musicStylesDislike[newIdx]
					if not string.find(randomMusicStyle, musicTraitPos) then break; end
				end
			end
			local traitName = string.upper(randomMusicStyle)
			if isClient() then
				sendClientCommand(player, "LS", "ChangeTrait", {traitName, "add"})
			else
				player:getCharacterTraits():add(CharacterTrait[traitName]);
				player:modifyTraitXPBoost(CharacterTrait[traitName], false);
				SyncXp(player)
			end
			playerData.PlayerMusicDislike = randomMusicStyle
			HaloTextHelper.addTextWithArrow(player, getText("UI_trait_" .. randomMusicStyle), true, HaloTextHelper.getColorRed())
		else
			playerData.PlayerMusicDislike = musicTraitNeg
		end	
	end
		
end

local waitForCommands
local count, countTotal = 0, 5
waitForCommands = function()
	count = count+1
	if count > countTotal then
		countTotal = 1000
		Events.OnTick.Remove(waitForCommands)
		local player = LSUtil.getValidCharacter(getPlayer())
		if player then
			checkMusicTraits(player)
			sendClientCommand(player, "LS", "SavePlayerData", {player:getModData()})
		end
	end
end

-- we use this to enable any data that might not exist
local function LScheckPlayerTracker()
	if isServer() and not isClient() then return; end
	local entries = {
	['REMOVE'] = {'LSZenActive','IsMeditating','cleaningETime','hygieneNeedETime','ActiveDiscoBallNearby','IsListeningToJukebox','PlayingDJBooth','IsDancingInit','IsDancingFull','IsDancingFullPartner',
	'WantsToDance','IsSittingOnSeat','IsSittingOnPianoStool','IsSittingOnSeatSouth','IsDoingToilet','TDcomplained','GaveApplause','PlayingInstrument','IsMeditationDisturbed','IsDoingShower','IsListeningToDJ'},
	['FLOAT'] = {'VanillaMusicResume','OtherPlayersAroundDancing'},
	['TABLE'] = {'PlayTracker'},
	['CUSTOM'] = {{'ListenedToMusic',-1,true},{'hygieneNeedLimit',100,true}},
	['CUSTOMTONUM'] = {{'HaloCooldownCounter',0,false},{'PlayerVoice',ZombRand(5),false}},
	}
	if isClient() then ModData.request("LSDATA"); end

	for i = 0, getNumActivePlayers() - 1 do
		local player = getSpecificPlayer(i)
		if player and player:hasModData() and not player:isDead() then
			local data = player:getModData()
			if SandboxVars.Text.DividerMusicNew then InstrumentsUtilOnCreatePlayer(player); end
			for k, v in pairs(entries) do
				for n=1, #v do
					local entry = v[n]
					if k == "REMOVE" then
						if data[entry] then data[entry] = false; end
					elseif k == "FLOAT" then
						data[entry] = 0
					elseif k == "TABLE" then
						if not data[entry] then data[entry] = {}; end
					elseif k == "CUSTOM" then
						if entry[3] or not data[entry[1]] then data[entry[1]] = entry[2]; end
					elseif k == "CUSTOMTONUM" then
						if not data[entry[1]] or not tonumber(data[entry[1]]) then data[entry[1]] = entry[2]; end
					end
				end
			end
			--if isClient() then sendClientCommand(player, "LS", "SavePlayerData", {data}); end
		end
	end
	if isClient() then Events.OnTick.Add(waitForCommands); else checkMusicTraits(nil); end
end

--By hour
local function updatePlayerTrackerByHour()
	local player = getPlayer()
	local playerData = player:getModData()

	--PlayTracker
	-- we add this loop and update at each hour to reset the contents stored in PlayTracker if it's more than 12 hours old, adding 1 hour if not
	if player:hasModData()
		and player:getModData().PlayTracker ~= nil then
	local n = #playerData.PlayTracker

	for i = n,1,-1 do
		if playerData.PlayTracker[i].hoursSince > 12 then
			table.remove(playerData.PlayTracker,i)
		else
			playerData.PlayTracker[i].hoursSince = playerData.PlayTracker[i].hoursSince + 1
		end
	end
	else
		player:getModData().PlayTracker = {}
	end
end


--By minute
local function updatePlayerTrackerByMinute()
	local player = getPlayer()
	local playerData = player:getModData()

	--HaloCooldownCounter
	-- we add this loop and update at each minute to reset the contents stored in HaloCooldownCounter if it's more than 5 minutes, adding 1 if not
	if player:hasModData()
		and player:getModData().HaloCooldownCounter ~= nil
		and tonumber(player:getModData().HaloCooldownCounter) ~= nil
	then
		if playerData.HaloCooldownCounter > 5 then
			playerData.HaloCooldownCounter = 0
		else
			playerData.HaloCooldownCounter = playerData.HaloCooldownCounter + 1
		end
	else
		player:getModData().HaloCooldownCounter = 0
	end
	--check if player has voice, needed in case something breaks midgame
	if (not player:getModData().PlayerVoice) or (not (tonumber(player:getModData().PlayerVoice))) then player:getModData().PlayerVoice = ZombRand(5); end
		
end

Events.OnNewGame.Add(initPlayerTracker)
Events.OnCreatePlayer.Add(LScheckPlayerTracker)
Events.EveryHours.Add(updatePlayerTrackerByHour)
Events.EveryOneMinute.Add(updatePlayerTrackerByMinute)