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

LSMPS = LSMPS or {}

LSMPS.isPlayerNearby = function(src, target, range)
	local srcX, srcY, srcZ = src:getX(), src:getY(), src:getZ()
	local tX, tY, tZ = target:getX(), target:getY(), target:getZ()
	return srcZ == tZ and srcX >= tX-range and srcX <= tX+range and srcY >= tY-range and srcY <= tY+range
end

LSMPS.getOrCreatePersonalInfo = function(character)
	local charData = character:getModData()
	if charData.LSSocial then return charData.LSSocial; end
	charData.LSSocial = {}
	-- id
	local id = character:getSteamID() or character:getUsername()
	charData.LSSocial.id = id
	-- hidden skills
	if not charData.LSHiddenSkills then -- initialise hs table
		HiddenSkills.getSkill(character, "Yoga")
	end
	charData.LSSocial.hs = charData.LSHiddenSkills
	LSSync.updateClientData(character, charData)
	return charData.LSSocial
end

LSMPS.getPlayersNearby = function(area, x, y, exclude)
	local players = getOnlinePlayers()
	if players then
		local nearbyPlayers = {}
		for i=1,players:size() do
			local player = players:get(i-1)
			if player and (not player.isAnimal or not player:isAnimal()) then
				local id = player.getOnlineID and player:getOnlineID()
				if id and id ~= exclude then
					local pX, pY = player:getX(), player:getY()
					if pX >= x-area and pX < x+area and pY >= y-area and pY < y+area then
						table.insert(nearbyPlayers, player)
					end
				end
			end
		end
		return nearbyPlayers
	end
	return false
end

--[[
function ScanForPlayers(command, args)
	if not command or not args then return; end
	if type(args) ~= "table" then return; end
	local playerObj = getPlayer()
	local players = getOnlinePlayers();
	if players then
		for i=1,players:size() do
			local player = players:get(i-1)
			if player and player ~= playerObj and (not player.isAnimal or not player:isAnimal()) then
				if player:getX() >= playerObj:getX() - 30 and player:getX() < playerObj:getX() + 30 and
                   player:getY() >= playerObj:getY() - 30 and player:getY() < playerObj:getY() + 30 then
					sendClientCommand(playerObj, "LS", command, {player:getOnlineID(), playerObj:getDisplayName(), args})
				end
			end
		end
	end
end
]]--

LSMPS.getRandomVoxSound = function(parent, group, oldSound, isFemale)
	local audioKeys = LSMPS.audioLib[parent][group]
	local gender = (isFemale and "Woman") or "Man"
	local possibleSounds = {}
	for k, v in pairs(audioKeys) do
		local strPrefix = (not v.sex and "") or ((v.sex == "All" or v.sex == gender) and gender)
		if strPrefix then
			for n=1,v.total do
				local strSuffix = (n < 10 and "0"..tostring(n)) or tostring(n)
				local soundName = strPrefix..v.name..strSuffix
				if not oldSound or soundName ~= oldSound then table.insert(possibleSounds, soundName); end
			end
		end
	end
	local rdmIdx = LSUtil.rdm_inst:random(#possibleSounds)
	return possibleSounds[rdmIdx]
end

LSMPS.getPingPongForm = function(character)
	if not character then return 0.4; end -- neutral fallback
	local skill = (character:getPerkLevel(Perks.Fitness) + character:getPerkLevel(Perks.Nimble)) / 2
	local stress = LSUtil.getCharacterMood(character, "Stress") or 0
	local boredom = (LSUtil.getCharacterMood(character, "Boredom") or 0) / 100
	local unhappiness = (LSUtil.getCharacterMood(character, "Unhappiness") or 0) / 100
	local mood = 1 - ((stress + boredom + unhappiness) / 3)
	local luck = ZombRandFloat(0, 1)
	--if CharacterTrait.LUCKY and character:hasTrait(CharacterTrait.LUCKY) then luck = math.min(1, luck + 0.15); end
	--if CharacterTrait.UNLUCKY and character:hasTrait(CharacterTrait.UNLUCKY) then luck = math.max(0, luck - 0.15); end
	return (skill/10)*0.4 + math.max(0, mood)*0.3 + luck*0.3
end

LSMPS.rollPointDetails = function(winner)
	local roll = ZombRandFloat(0, 1)
	local faultType
	if roll < 0.15 then
		faultType = "net"
	elseif roll < 0.3 then
		faultType = "badOut"
	else
		faultType = "goodOut"
	end
	return {
		winner = winner,
		faultType = faultType,
		volleys = ZombRand(3, 7),
	}
end

LSMPS.resolvePingPongMatch = function(formSource, formOther)
	formSource = formSource or 0.4
	formOther = formOther or 0.4
	local pSource = formSource / math.max(0.01, (formSource + formOther))
	local points = {}
	local scoreSource, scoreOther = 0, 0
	while scoreSource < 5 and scoreOther < 5 do
		local winner = (ZombRandFloat(0, 1) < pSource) and "source" or "other"
		if winner == "source" then scoreSource = scoreSource + 1 else scoreOther = scoreOther + 1 end
		table.insert(points, LSMPS.rollPointDetails(winner))
	end
	return {
		points = points,
		scoreSource = scoreSource,
		scoreOther = scoreOther,
		winner = (scoreSource > scoreOther) and "source" or "other",
	}
end

LSMPS.getPingPongKey = function(actionObj)
	local source = actionObj and actionObj.character
	local other = actionObj and actionObj.otherPlayer
	if not source or not other then return false; end
	local formSource = LSMPS.getPingPongForm(source)
	local formOther = LSMPS.getPingPongForm(other)
	return LSMPS.resolvePingPongMatch(formSource, formOther)
end