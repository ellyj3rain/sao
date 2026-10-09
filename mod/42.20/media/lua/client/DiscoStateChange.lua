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

local function getPlayerList(playerObj, range)
	local playersList = {}
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
	return playersList
end

local function LS_PlayingInstrumentRange(player, worldobjects, x, y, test)

	local thisPlayer = getPlayer()
	if not thisPlayer then return; end

    for playerIndex = 0, getNumActivePlayers()-1 do
		local playerObj = getSpecificPlayer(playerIndex)
		if playerObj and playerObj:hasModData() and not playerObj:isDead() then
			local SourceMusiclvl = playerObj:getPerkLevel(Perks.Music) or 0
			local playerData = playerObj:getModData()
			if playerData.IsDancingInit and not playerData.IsDancingFull then playerData.IsDancingInit = false; end
			if not playerObj:hasTrait(CharacterTrait.DEAF) and playerData.IsListeningToJukebox and playerData.IsListeningToMusicStyle and tostring(playerData.IsListeningToMusicStyle) and
			not playerData.PlayingInstrument and not playerData.IsListeningToDJ and not LS_DJBooth.isPlaying then
				local str = string.upper(tostring(playerData.IsListeningToMusicStyle))
				local newStr = string.sub(str, 2)
				if (CharacterTrait[str] and playerObj:hasTrait(CharacterTrait[str])) or (CharacterTrait[newStr] and playerObj:hasTrait(CharacterTrait[newStr])) then
					PlayerIsListeningToMusic(playerObj, 8)
				elseif (CharacterTrait[str.."NO"] and playerObj:hasTrait(CharacterTrait[str.."NO"])) or (CharacterTrait[newStr.."NO"] and playerObj:hasTrait(CharacterTrait[newStr.."NO"])) then
					PlayerIsListeningToMusic(playerObj, 0)
				else
					PlayerIsListeningToMusic(playerObj, 3)
				end			
			end
			if LS_DJBooth.isPlaying or LS_DJBooth.isPlayingMic then
				local SourceDJ = tostring(playerObj:getUsername())
				local playersList = getPlayerList(playerObj, 8)
				if #playersList > 0 then
					for i,v in ipairs(playersList) do
						if v:getUsername() ~= playerObj:getUsername() and
						v:isOutside() == playerObj:isOutside() then
							sendClientCommand(playerObj, "LS", "IsPlayingDJ", {v:getOnlineID(), SourceMusiclvl, SourceDJ, true})
						end
					end
				end
			elseif playerData.PlayingInstrument then
				local playersList = getPlayerList(playerObj, 8)
				if #playersList > 0 then
					for i,v in ipairs(playersList) do
						if isKeyDown(Keyboard.KEY_X) and playerData.WaitingDuet and v:getUsername() ~= playerObj:getUsername() and v:isOutside() == playerObj:isOutside() then
							sendClientCommand(playerObj, "LS", "IsStartingDuet", {v:getOnlineID(), false})
						elseif not playerData.WaitingDuet and v:getUsername() ~= playerObj:getUsername() and v:isOutside() == playerObj:isOutside() then
							sendClientCommand(playerObj, "LS", "IsPlayingMusic", {v:getOnlineID(), SourceMusiclvl})
						end
					end
				end
				if isKeyDown(Keyboard.KEY_X) and playerData.WaitingDuet then playerData.WaitingDuet = false; end
			elseif LS_DJBooth.stop then
				LS_DJBooth.stop = false
				local SourceDJ = tostring(playerObj:getUsername())
				local playersList = getPlayerList(playerObj, 8)
				if #playersList > 0 then
					for i,v in ipairs(playersList) do
						if v:getUsername() ~= playerObj:getUsername() and v:isOutside() == playerObj:isOutside() then
							sendClientCommand(playerObj, "LS", "IsPlayingDJ", {v:getOnlineID(), SourceMusiclvl, SourceDJ, false})
						end
					end
				end
			elseif playerData.IsListeningToDJ then
				local IsListeningCheck = false
				local playersList = getPlayerList(playerObj, 8)
				if #playersList > 0 then
					for i,v in ipairs(playersList) do
						if v:getUsername() ~= playerObj:getUsername() and v:isOutside() == playerObj:isOutside() then
							if playerData.SourceDJName and (tostring(v:getUsername()) == tostring(playerObj:getModData().SourceDJName)) then
								IsListeningCheck = true; break
							end
						end
					end
					if not IsListeningCheck then playerData.IsListeningToDJ, playerData.SourceDJName = false, "nodj"; end
				end
			elseif playerData.IsListeningToJukebox and not playerData.IsDancingInit and not playerObj:isSitOnGround() and not playerObj:isSneaking() and not playerObj:hasTimedActions() then
				playerData.IsDancingInit = true
			end
		end
	end
end

function OnJukeboxTurnOff(x, y, z)

	local x = x
	local y = y
	local z = z
	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	if not sqr then return end
			for i=0,sqr:getObjects():size()-1 do
				local thisObject = sqr:getObjects():get(i)	
			--for i=1,sqr:getObjects():size() do
				--local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Jukebox" then
							Jukebox = thisObject;
						end
					end
				end
			end


	if not Jukebox then
	--print("failed")
	return end

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil and
	Jukebox:getModData().OnOff == "on" then
	
		Jukebox:getModData().OnOff = "off"
		Jukebox:getModData().OnPlay = "nothing"
	
	else
		return
	end

end

function OnDiscoBallStyleChange(style, x, y, z, s)

	local sqr = getCell():getGridSquare(x,y,z);
	local DiscoBall
	if not sqr then return end
			for i=0,sqr:getObjects():size()-1 do
				local thisObject = sqr:getObjects():get(i)	
			--for i=1,sqr:getObjects():size() do
				--local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Disco Ball" then
							DiscoBall = thisObject;
						end
					end
				end
			end


	if not DiscoBall then
	--print("failed")
	return end

	if DiscoBall:hasModData() and
	DiscoBall:getModData().OnOff ~= nil and
	DiscoBall:getModData().OnOff == "on" then
	
		DiscoBall:getModData().Mode = style
		DiscoBall:getModData().Shuffle = s
	end

end

function OnDiscoBallTurnOff(playerDiscoCommand, x, y, z)

	local playerDiscoCommand = playerDiscoCommand
	local x = x
	local y = y
	local z = z
	local sqr = getCell():getGridSquare(x,y,z);
	local DiscoBall
	if not sqr then return end
			for i=0,sqr:getObjects():size()-1 do
				local thisObject = sqr:getObjects():get(i)	
			--for i=1,sqr:getObjects():size() do
				--local thisObject = sqr:getObjects():get(i-1)

				local thisSprite = thisObject:getSprite()
				
				if thisSprite ~= nil then
				
					local properties = thisObject:getSprite():getProperties()

					if properties ~= nil then
						local groupName = nil
						local customName = nil
						local thisSpriteName = nil
					
						local thisSprite = thisObject:getSprite()
						if thisSprite:getName() then
							thisSpriteName = thisSprite:getName()
						end
					
						if properties:has("GroupName") then
							groupName = properties:get("GroupName")
						end
					
						if properties:has("CustomName") then
							customName = properties:get("CustomName")
						end

						if customName == "Disco Ball" then
							DiscoBall = thisObject;
						end
					end
				end
			end


	if not DiscoBall then
	--print("failed")
	return end

	if DiscoBall:hasModData() and
	DiscoBall:getModData().OnOff ~= nil and
	DiscoBall:getModData().OnOff == "on" then
	
		DiscoBall:getModData().OnOff = playerDiscoCommand
	
	else
		return
	end

end

local IReventStart

function startInstrumentRange()
	if IReventStart then return; end
	IReventStart = true
	Events.EveryOneMinute.Add(LS_PlayingInstrumentRange);
end

Events.OnGameStart.Add(startInstrumentRange)
