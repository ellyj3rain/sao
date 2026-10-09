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

local function getPlayerDataStrings()
	return {
		"GaveApplause",
	}
end

local function doPlayerCooldowns(playerData)

	local cooldownList = LSUtil.getPlayerCooldowns(10)

	for n=1,#cooldownList[2] do
		local value = cooldownList[2][n]
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

	for n=1,#cooldownList[1] do
		local value = cooldownList[1][n]
		if playerData.LSMoodles[value] and (playerData.LSMoodles[value].Value > 0) then
			playerData.LSMoodles[value].Value = playerData.LSMoodles[value].Value - 0.02
		end
		if playerData.LSMoodles[value] and (playerData.LSMoodles[value].Value < 0.2) then
			playerData.LSMoodles[value].Value = 0
		end
	end

end

local function doPlayerCooldownsSimple(playerData)
	local dataList = getPlayerDataStrings()
	for n=1,#dataList do
		local value = dataList[n]
		playerData[value] = false
	end
end

local function LSETMgetOtherPlayers(character, range, command)

	for playerIndex = 0, getNumActivePlayers()-1 do
		local playersList = {};--get players
		local playerObj = getSpecificPlayer(playerIndex)
		local playerIso

		if (playerObj ~= nil) then
			for x = playerObj:getX()-range,playerObj:getX()+range do
				for y = playerObj:getY()-range,playerObj:getY()+range do
					local square = getCell():getGridSquare(x,y,playerObj:getZ());
					if square then
						for i = 0,square:getMovingObjects():size()-1 do
							local moving = square:getMovingObjects():get(i);
							if instanceof(moving, "IsoPlayer") then
								table.insert(playersList, moving);
							end
						end
					end
				end
			end

			if #playersList > 0 then
				for i,v in ipairs(playersList) do
					if v:getUsername() == playerObj:getUsername() then
						playerIso = v
						break
					end
				end
				for i,v in ipairs(playersList) do
					if playerIso and
					v:getUsername() ~= playerObj:getUsername() and
					v:isOutside() == playerObj:isOutside() then
					--if playerIso:checkCanSeeClient(v) then
						if command and playerObj:CanSee(v) and playerIso:checkCanSeeClient(v) and not v:isInvisible() then		
							sendClientCommand(character, "LS", command, {v:getOnlineID()})
						end
					end
				end	
			end
		end
	end

end

local function HNmakeOthersNauseous(thisPlayer, HygieneBadValue)
	if not HygieneBadValue then return; end
	if HygieneBadValue > 0.6 then LSETMgetOtherPlayers(thisPlayer, 8, "makeNauseous"); else LSETMgetOtherPlayers(thisPlayer, 4, "makeNauseous"); end

end

local function checkCanDoAnim(thisPlayer, cooldown)
	if cooldown and (cooldown > 0) then return false; end
	if (thisPlayer:hasTimedActions() or thisPlayer:isSitOnGround() or thisPlayer:isSneaking() or thisPlayer:isAiming()) then
		return false
	end
	local dice6 = ZombRand(6)+1
	if dice6 == 6 then return true; end
	return false
end

local function doPlayerReactions(thisPlayer, playerData)

	--------------Hygiene
	if SandboxVars.Text.DividerHygiene then
		if playerData.LSMoodles["HygieneBad"] and (playerData.LSMoodles["HygieneBad"].Value >= 0.6) then
			if isClient() then HNmakeOthersNauseous(thisPlayer, playerData.LSMoodles["HygieneBad"].Value); end
			if playerData.LSCooldowns and checkCanDoAnim(thisPlayer, playerData.LSCooldowns["StinkingCooldown"]) then playerData.LSCooldowns["StinkingCooldown"] = 72; ISTimedActionQueue.add(LSReactionStinking:new(thisPlayer)); end
		end
	end
	--------------

end

local function hasSnow(object)
	local snow = getCell():gridSquareIsSnow(object:getX(),object:getY(),object:getZ())
	return snow
end

local function isSnowfall()
	local snow = getClimateManager():isSnowing()
	return snow
end

local function isCold()
	local climate = getClimateManager():getTemperature()
	if climate < 0 then return true; end
	return false
end

local function playerCheckSurroundings(thisPlayer)
	local t = require("Painting/Sculpting/lib/Hedge_Snow")
	local sourceSquare = getCell():getGridSquare(thisPlayer:getX(),thisPlayer:getY(),thisPlayer:getZ())
	if not sourceSquare then return; end
	for x = thisPlayer:getX()-8,thisPlayer:getX()+8 do
		for y = thisPlayer:getY()-8,thisPlayer:getY()+8 do
			local square = getCell():getGridSquare(x,y,thisPlayer:getZ())
			if square then
				for i = 0,square:getObjects():size()-1 do
					local object = square:getObjects():get(i)
					if object and object:getTextureName() then
						local objName = object:getTextureName()
						for k, v in pairs(t) do
							local sprite, snowSprite
							if v.east and (objName == v.east) then
								sprite = v.east
								snowSprite = v.eastS
							elseif v.south and (objName == v.south) then
								sprite = v.south
								snowSprite = v.southS
							end
							if sprite and snowSprite then
								if object:getOverlaySprite() and ((not isCold()) or (not hasSnow(object))) then
									if isClient() then 
										sendClientCommand("LS", "ModifyOverlaySprite", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, false})
									else
										object:setOverlaySprite(nil, isClient())
									end
								elseif (not object:getOverlaySprite()) and isCold() and isSnowfall() and hasSnow(object) then
									if isClient() then
										sendClientCommand("LS", "ModifyOverlaySprite", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, snowSprite})
									else
										object:setOverlaySprite(snowSprite, isClient())
									end
								end
							end
						end
					end
				end
			end
		end		
	end
end

local zenBonus

function LSupdateZenBonus(playerData)
	--print("------------ WARNING: LSupdateZenBonus called")
	local playerZenData = playerData.LSZenActive
	if playerZenData and not zenBonus then
		zenBonus = {}
		for k, v in pairs(playerZenData) do
			zenBonus[k] = v
			--print("LSupdateZenBonus - key "..tostring(k).." of value: "..tostring(v).." added to zenBonus")
		end
	end
end

local actionKeys = {"IsMeditating","PlayingDJBooth","IsDancingFull","IsDoingToilet","PlayingInstrument","IsMeditationDisturbed","IsDoingShower","DJNotFailstate"}

local function doPlayerBonusesCheck(thisPlayer, playerData)
	if playerData.LSCooldowns and playerData.LSCooldowns['dietofgods'] and playerData.LSCooldowns['dietofgods'] > 0 and playerData.Ambitions and playerData.Ambitions['LSDietOfGods'] and
	playerData.Ambitions['LSDietOfGods'].completed and playerData.Ambitions['LSDietOfGods'].isActive then
		LSUtil.MakeCharWellFed(thisPlayer)
	end

	LSupdateZenBonus(playerData)
	if playerData.LSZenActive and ((playerData.LSMoodles["Zen"] and playerData.LSMoodles["Zen"].Level <= 0) or (not SandboxVars.Text.DividerMeditationNew)) then
		if FitnessExercises and FitnessExercises.exercisesType then
			for k, v in pairs(FitnessExercises.exercisesType) do
				if v and v.xpMod then
					local val = playerData.LSZenActive[k]
					--print("doPlayerBonusesCheck - key value "..tostring(k).." was: "..tostring(v.xpMod).." and is now:"..tostring(val))
					if val then v.xpMod = val; end
				end
			end
			zenBonus = nil
			playerData.LSZenActive = nil
		end
	end
	if not thisPlayer:hasTimedActions() then
		for n=1,#actionKeys do
			local key = actionKeys[n]
			if playerData[key] then playerData[key] = false; end
		end
	end
end

local function RemoveZenBonus(player)
	if not zenBonus then return; end
	if FitnessExercises and FitnessExercises.exercisesType then
		for k, v in pairs(FitnessExercises.exercisesType) do
			if v and v.xpMod then
				local val = zenBonus[k]
				--print("removeZenBonus - key value "..tostring(k).." was: "..tostring(v.xpMod).." and is now:"..tostring(val))
				if val then v.xpMod = val; end
			end
		end
		zenBonus = nil
	end
end

Events.OnPlayerDeath.Add(RemoveZenBonus)

local function LSEveryTenMinutes()
	local thisPlayer = getPlayer()
	local playerData = thisPlayer:getModData()
	if thisPlayer and playerData and playerData.LSMoodles and not thisPlayer:isDead() then
		doPlayerCooldowns(playerData)
		doPlayerCooldownsSimple(playerData)
		doPlayerBonusesCheck(thisPlayer, playerData)
		LS_NeuralHat.checkTenMins(thisPlayer, playerData)
		if not thisPlayer:isAsleep() then
			doPlayerReactions(thisPlayer, playerData)
			playerCheckSurroundings(thisPlayer)
		end
	end
end

Events.EveryTenMinutes.Add(LSEveryTenMinutes);
