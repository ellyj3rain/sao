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

LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerTenMin = LSMoodHandler.PerTenMin or {}
LS_DJBooth = LS_DJBooth or {}

-- GENERAL EVENT CREATION
local DanceMusicOriginalVolume = tonumber(getSoundManager():getMusicVolume())
local oldVanillaMusicResume = 0
-- UPDATES EVERY TEN MINUTES:

local function getDancingDataPoints(playerData)	
	local points = 0
	local t = {
		ActiveDiscoBallNearby = 1,
		ActiveDiscoFloorNearby = 1,
		IsListeningToDJ = 2,
		IsListeningToJukebox = 1,
	}
	
	for k, v in pairs(t) do
		if playerData[k] then
			points = points+v
		end
	end
	return points
end

local function getIsDancingPoints(skill, killjoy)
	local t = {
		[8] = {0,3},
		[4] = {1,2},
		[0] = {2,1},
	}
	local skillTable
	for k, v in pairs(t) do
		if skill >= tonumber(k) then skillTable = t[k]; break; end
	end
	if not skillTable then return 0; end
	return skillTable and ((killjoy and skillTable[1]) or skillTable[2])
end

local function getMusicPoints(good, bad, killjoy)
	local t = {
		[0.4] = {0,2,3},
		[0.2] = {1,1,2},
	}
	local musicTable
	for k, v in pairs(t) do
		if good >= tonumber(k) or bad >= tonumber(k) then musicTable = t[k]; break; end
	end
	if not musicTable then return 0; end
	if good > 0 then
		return musicTable and ((killjoy and musicTable[1]) or musicTable[2])
	end
	return musicTable and ((killjoy and musicTable[3]) or 0)
end

local function doPartyCalc(moodleVal, moodle, totalPoints)
	local t = {
		[0.6] = {10, false},
		[0.4] = {7, 10},
		[0.2] = {3, 7},
		[0.0] = {false, 3},
	}

	local newVal = moodleVal
	for k, v in pairs(t) do
		if moodleVal >= tonumber(k) then
			if v[1] and totalPoints < v[1] then
				newVal = math.max(0,newVal-0.2)
			elseif v[2] and totalPoints >= v[2] then
				newVal = math.min(0.6,newVal+0.2)
			end
			break
		end
	end

	if newVal ~= moodleVal then LSMoodleManager.setValue(moodle, newVal); end
end

local function doDjAudienceCalc(moodleVal, otherPlayers)
	if not LS_DJBooth.isPlaying then
		local newVal = math.max(0, moodleVal-0.2)
		if newVal ~= moodleVal then LSMoodleManager.setValue("DJAudience", newVal); end
		return
	end
	local t = {
		[0.6] = {8, false},
		[0.4] = {5, 8},
		[0.2] = {3, 5},
		[0.0] = {false, 3},
	}
	local newVal = moodleVal
	for k, v in pairs(t) do
		if moodleVal >= tonumber(k) then
			if v[1] and otherPlayers < v[1] then
				newVal = math.max(0,newVal-0.2)
			elseif v[2] and otherPlayers >= v[2] then
				newVal = math.min(0.6,newVal+0.2)
			end
			break
		end
	end
	if newVal ~= moodleVal then LSMoodleManager.setValue("DJAudience", newVal); end
end

local function getMusicQuality(listenedVal, isVirtuoso, isTonedeaf, isDeafOrAsleep)
	if isDeafOrAsleep then return -1; end
	local t = {
		[8] = {4,4,2},
		[6] = {4,3,2},
		[2] = {3,3,1},
		[0] = {2,2,1},
	}
	for k, v in pairs(t) do
		if listenedVal >= tonumber(k) then
			return t[k] and ((isVirtuoso and t[k][1]) or (isTonedeaf and t[k][3]) or t[k][2])
		end
	end
	return 0
end

local function doMusicCalc(moodleVal, moodle, musicQuality, listened)
	local t = {
		[0.4] = {MusicGood={3, false},MusicBad={false, 1}},
		[0.2] = {MusicGood={2, 3},MusicBad={1, 2}},
		[0.0] = {MusicGood={false, 2},MusicBad={2, false}},
	}
	local newVal = moodleVal
	if not listened then
		newVal = math.max(0,math.min(0.4,newVal-0.2))
		if newVal ~= moodleVal then LSMoodleManager.setValue(moodle, newVal); end
		return
	end
	local nAdd, nSub = 0.2, -0.2
	if moodle == "MusicBad" then nAdd, nSub = -0.2, 0.2; end
	for k, v in pairs(t) do
		if moodleVal >= tonumber(k) then
			local params = t[k][moodle]
			if params[1] and musicQuality <= params[1] then
				newVal = newVal+nSub
			elseif params[2] and musicQuality > params[2] then
				newVal = newVal+nAdd
			end
			break
		end
	end

	newVal = math.max(0,math.min(0.4,newVal))

	if newVal ~= moodleVal then LSMoodleManager.setValue(moodle, newVal); end
end

function LSEveryTenMinutes()
		-- GET THE PLAYER
	local player = getPlayer()
	if not LSUtil.getValidCharacter(player) then return; end
	
	local playerData = player:getModData()
	if not playerData or not playerData.LSMoodles then return; end

	if DanceMusicOriginalVolume == 0 then DanceMusicOriginalVolume = tonumber(getSoundManager():getMusicVolume()); end

	local SkipPartyCalc = player:hasTrait(CharacterTrait.DEAF)
	local isKilljoy = player:hasTrait(CharacterTrait.KILLJOY)
	local isToneDeaf = player:hasTrait(CharacterTrait.TONEDEAF)
	local totalPoints = 0
	local otherPlayers = 0

	if not player:isAsleep() then
		local moodList = {}
		-- CALL TO METHODS THAT USE EVERYTENMINUTES EVENT
		-- COUCH POTATOES WILL GET SLIGHTLY STRESSED WHEN OUTDOORS
		if player:hasTrait(CharacterTrait.COUCHPOTATO) then
			-- COUCH POTATOES GET SLEEPY FASTER
			moodList["Fatigue"] = {0.002, true, false, true}
		
			if not playerData.HomeSickCountUp then playerData.HomeSickCountUp = 1; end
			if not playerData.HomeSickCountdown then playerData.HomeSickCountdown = 1; end
			if player:isOutside() then
				if playerData.HomeSickCountUp > 6 then
					local moodle, value = "AtHouse", 0
					if playerData.LSMoodles["AtHouse"].Value == 0 then
						moodle, value = "HomeSick", math.min(0.8, playerData.LSMoodles["HomeSick"].Value+0.2)
					end
					if value ~= playerData.LSMoodles[moodle].Value then LSMoodleManager.setValue(moodle, value); end
					playerData.HomeSickCountUp = 1
				elseif playerData.LSMoodles["HomeSick"].Value == 0.8 then
					playerData.HomeSickCountdown = math.max(1, playerData.HomeSickCountdown-1)
				else
					playerData.HomeSickCountUp = playerData.HomeSickCountUp + 1
					playerData.HomeSickCountdown = math.max(1, playerData.HomeSickCountdown-1)
				end
			else					
				if playerData.HomeSickCountdown > 3 then
					local moodle, value = "AtHouse", 0.2
					if playerData.LSMoodles["HomeSick"].Value > 0 then
						moodle, value = "HomeSick", math.max(0, playerData.LSMoodles["HomeSick"].Value-0.2)
					end
					if value ~= playerData.LSMoodles[moodle].Value then LSMoodleManager.setValue(moodle, value); end
					playerData.HomeSickCountdown = 1
				elseif playerData.LSMoodles["AtHouse"].Value == 0.2 then
					playerData.HomeSickCountUp = math.max(1, playerData.HomeSickCountUp-1)
				else
					playerData.HomeSickCountdown = playerData.HomeSickCountdown + 1
					playerData.HomeSickCountUp = math.max(1, playerData.HomeSickCountUp-1)
				end
			end
		elseif playerData.LSMoodles["AtHouse"].Value > 0 or playerData.LSMoodles["HomeSick"].Value > 0 then
			playerData.LSMoodles["AtHouse"].Value = 0
			playerData.LSMoodles["HomeSick"].Value = 0
			playerData.HomeSickCountUp = 1
		end		

		if playerData.LSMoodles["HomeSick"].Level and playerData.LSMoodles["HomeSick"].Level > 0 then
			moodList["Stress"] = {0.04*playerData.LSMoodles["HomeSick"].Level, true, false, true}
		-- COUCH POTATOES TAKE LONGER TO GET BORED WHEN INDOORS
		elseif playerData.LSMoodles["AtHouse"].Level and playerData.LSMoodles["AtHouse"].Level > 0 then
			moodList["Boredom"] = {-0.6, true, false, true}
		end
		
		for k, v in pairs(moodList) do
			if not v[3] then -- refuses to add from isSet
				if not LSMoodHandler.PerTenMin[k] then
					LSMoodHandler.PerTenMin[k] = {v[1], v[2], v[3], v[4]}
				else
					LSMoodHandler.PerTenMin[k][1] = LSMoodHandler.PerTenMin[k][1]+v[1]
				end
			end
		end
		
		--DJAUDIENCE AND PARTYSTUFF
		if not SkipPartyCalc and (playerData.IsListeningToJukebox or playerData.IsListeningToDJ or LS_DJBooth.isPlaying) then
			--PeopleCheck - do only if first stage is true -- this will give us the number of players and the number of players dancing nearby
			local danceSkillLvl = player:getPerkLevel(Perks.Dancing)
			local otherPlayersDancing = playerData.OtherPlayersAroundDancing or 0
			
			for playerIndex = 0, getNumActivePlayers()-1 do
				for x = player:getX()-8,player:getX()+8 do
					for y = player:getY()-8,player:getY()+8 do
						local square = getCell():getGridSquare(x,y,player:getZ());
						if square then
							for i = 0,square:getMovingObjects():size()-1 do
								local moving = square:getMovingObjects():get(i);
								if instanceof(moving, "IsoPlayer") and moving:getUsername() ~= player:getUsername() and moving:isOutside() == player:isOutside() then
									otherPlayers = otherPlayers+1
									sendClientCommand(player, "LS", "AskIfIsDancing", {moving:getOnlineID(), player:getUsername()})
								end
							end
						end
					end
				end	
			end
			otherPlayersDancing = math.min(otherPlayersDancing, otherPlayers)
			--now we have all the variables we need (disco, dj, jukebox, #people, #dancers, if player has killjoy or party animal, if dancing and dancing skill level, wether or not they're enjoying the music)
			totalPoints = getDancingDataPoints(playerData) -- the more the better (with a few exceptions for killjoy) - from 1-13 (10 with 2 extra points for flexibility and 1 for party animals), 0 disables it, certain thresholds need to be achieved also
			-- For players with no relevant traits:
			-- 3 is first stage
			-- 7 is second stage
			-- 10 is last stage
			local POtherPlayers = 0 -- maxes at 2
			local POtherPlayersDancing = 0 -- maxes at 2
			local PDancing = 0 -- maxes at 3, only if is dancing and considers skill level, killjoy is inverted
			local PMusicMoodle = 0 -- maxes at 2 (starts at 3 for killjoy and is inverted)
			local PExtra = 0 -- maxes at 1, used to lower the threshold for party animals for second and third stage
			--maximum possible value = 12
			--examples of first stage combinations:
			-- 4 people and at least 2 of them dancing
			-- 4 people, an active discoball and song comes from jukebox
			-- 4 people and player is dancing
			-- A DJ is playing and the music is good
			-- 8 people and song comes from jukebox
			-- The character favorite genre is playing in the jukebox and a discoball is active
			--examples of second stage combinations: (requires a minimum of 3 other people)
			-- 4 people, at least 2 dancing, an active disco ball, a dj and the music is good
			-- 8 people, at least 2 dancing, Jukebox playing, player is dancing with a swkill of at least 4, music is good
			-- 4 people, DJ playing with a very high music skill, an active disco ball, player is dancing
			--examples of third stage combinations: (requires a minimum of 5 other people and at least 2 dancing)
			-- 8 people, at least 4 dancing, jukebox, is favorite genre, player is dancing with a skill of at least 8 
			-- 5 people, at least 2 dancing, DJ with very high skill, active discoball, player is dancing with a skill of 4 and is a party animal
		
			if otherPlayers >= 8 then POtherPlayers = 2; elseif otherPlayers >= 4 then POtherPlayers = 1; end
			--Other Players Dancing
			if otherPlayersDancing >= 4 then POtherPlayersDancing = 2; elseif otherPlayersDancing >= 2 then POtherPlayersDancing = 1; end
			--Player is dancing
			if playerData.IsDancingFull then
				PDancing = getIsDancingPoints(danceSkillLvl, isKilljoy)
			end
			--If is enjoying the music
			if playerData.IsDancingFull then
				PDancing = getIsDancingPoints(danceSkillLvl, isKilljoy)
			end
			if playerData.LSMoodles["MusicGood"].Value ~= 0 or playerData.LSMoodles["MusicGood"].Value ~= 0 then
				PMusicMoodle = getMusicPoints(playerData.LSMoodles["MusicGood"].Value, playerData.LSMoodles["MusicBad"].Value, isKilljoy)
			end
			
			--Extra
			if player:hasTrait(CharacterTrait.PARTYANIMAL) and playerData.LSMoodles["PartyGood"].Value > 0 then PExtra = 1; end

			totalPoints = totalPoints + POtherPlayers + POtherPlayersDancing + PDancing + PMusicMoodle + PExtra
	
		end -- not SkipPartyCalc	
	end --NotAsleep

	local moodle = "PartyGood"
	if (isKilljoy and playerData.LSMoodles["PartyGood"].Value == 0) or playerData.LSMoodles["PartyBad"].Value > 0 then moodle = "PartyBad"; end
	doPartyCalc(playerData.LSMoodles[moodle].Value, moodle, totalPoints)
	doDjAudienceCalc(playerData.LSMoodles["DJAudience"].Value, otherPlayers)
	
	---IF PLAYER IS ASLEEP PARTYSTUFF
	--Static Variables
	playerData.ActiveDiscoBallNearby = false
	playerData.OtherPlayersAroundDancing = 0
		
	--MUSICMOODLESTUFF
	
	local musicQuality, listened = 0, false
	if playerData.ListenedToMusic and playerData.ListenedToMusic >= 0 then
		listened = true
		musicQuality = getMusicQuality(playerData.ListenedToMusic, player:hasTrait(CharacterTrait.VIRTUOSO), isToneDeaf, player:hasTrait(CharacterTrait.DEAF) or player:isAsleep())
		playerData.ListenedToMusic = -1
	end
	moodle = "MusicGood"
	if (isToneDeaf and playerData.LSMoodles["MusicGood"].Value == 0) or playerData.LSMoodles["MusicBad"].Value > 0 then moodle = "MusicBad"; end
	doMusicCalc(playerData.LSMoodles[moodle].Value, moodle, musicQuality, listened)
	

	if playerData.VanillaMusicResume and playerData.VanillaMusicResume ~= 0 and playerData.VanillaMusicResume == oldVanillaMusicResume and not playerData.PlayingInstrument and not LS_DJBooth.isPlaying and not playerData.IsListeningToJukebox then
		getSoundManager():setMusicVolume(DanceMusicOriginalVolume)
		DanceMusicOriginalVolume = 0
		playerData.VanillaMusicResume = 0
	elseif playerData.VanillaMusicResume ~= oldVanillaMusicResume then
		oldVanillaMusicResume = playerData.VanillaMusicResume
	end

end

Events.EveryTenMinutes.Add(LSEveryTenMinutes);
