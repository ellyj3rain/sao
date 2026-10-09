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

--local isPlayingJukeSong = nil;
--local isJukeRunning = getSoundManager():PlayWorldSound("JukeboxRunning", Jukebox:getSquare(), 3, 30, 0.5, false);


-- MAYBE DEFINE GENRES (MUSIC PLAYED) HERE THEN JUST CALL IT TO PLAYERS, EACH PLAYER WILL HEAR A DIFFERENT SONG WITHIN THAT GENRE BUT SHOULD STOP CORRECTLY
-- ONLY THING THAT MATTERS TO SYNC IS TO KNOW IF THE JUKE IS ON OR OFF AND WHAT STYLE ITS PLAYING
--PLAYSOUNDIMPL
--local iswaiting
local justalittlesecondR = 75
local justalittlesecondstartR = 0


function OnJukeboxStart(x, y, z)

	local x = x
	local y = y
	local z = z
	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	if sqr == nil then return end
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

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
	Jukebox:getModData().JukeinRange ~= nil and
	Jukebox:getModData().JukeinRange == "out of range" then
	return
	end

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil and
	Jukebox:getModData().OnOff == "off" then
	return
	end

	local emitterLoop = getWorld():getFreeEmitter()
	local audioLoop
	local Jx = Jukebox:getX()
	local Jy = Jukebox:getY()
	local Jz = Jukebox:getZ()

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil and
	Jukebox:getModData().OnOff == "on" then


		if emitterLoop then
			--print("is emitter")
			emitterLoop:setPos(Jx, Jy, Jz);--EMITTER SQUARE
			audioLoop = emitterLoop:playSoundImpl("JukeboxRunning", false, Jukebox);--SOUND THAT WILL BE PLAYED (SOUND NAME, IF IS WORLDSOUND, ISOOJECT)
			addSound(Jukebox, Jx, Jy, Jz, 30, 10)


		--if Jukebox:getModData().OnOff == "on" then
	
			local superhell
				superhell = function()
				
				justalittlesecondstartR = justalittlesecondstartR + 1

				if justalittlesecondstartR % justalittlesecondR == 0 then
					justalittlesecondstartR = 0
					
				emitterLoop:setPos(Jx, Jy, Jz)
				
					if Jukebox:getModData().OnOff ~= nil and
					Jukebox:getModData().OnOff == "on" then

						if Jukebox:getModData().JukeinRange == "in range" then
						
						if not emitterLoop:isPlaying(audioLoop) then
						--print("PLAYING LOOP AGAIN")
						audioLoop = emitterLoop:playSoundImpl("JukeboxRunning", false, Jukebox)
						addSound(Jukebox, Jx, Jy, Jz, 30, 10)
						end
						--if jukebox get out of range or something data then stop sound so it doesnt bug out, use interactionrange to get ranges, might have to remove the if not
						
						else
						
						if emitterLoop:isPlaying(audioLoop) then
						emitterLoop:stopSound(audioLoop)
						else
						--print("OUT OF RANGE")
						emitterLoop:stopSoundByName("JukeboxRunning")
						Events.OnTick.Remove(superhell)
						end
						
						end
					
					elseif Jukebox:getModData().OnOff == "off" then
					
						if emitterLoop:isPlaying(audioLoop) then
						emitterLoop:stopSound(audioLoop)
						else
						--print("REMOVING EVENT")
						emitterLoop:stopSoundByName("JukeboxRunning")
						Events.OnTick.Remove(superhell)
						end
					end
					end
				end
			--Jukebox:getModData().LoopCheck = "started"
			Events.OnTick.Add(superhell)
	
		--else
	
		--end
		end
	else
		return
	end

end

function OnJukeSongStop(x, y, z)

	local x = x
	local y = y
	local z = z
	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	if sqr == nil then return end
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

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
	Jukebox:getModData().OnOff == "on" and
	Jukebox:getModData().OnPlay ~= nil and
	Jukebox:getModData().OnPlay ~= "nothing" then
				
		Jukebox:getModData().SilenceMusic = "yes"
	
	else
		return
	end

end

function OnJukeboxStyleChange(x, y, z, style, length, genre, customPlaylist)

	local x = x
	local y = y
	local z = z
	local style = style
	local length = length
	local genre = genre
	local PlayerPlaylist = customPlaylist
	local sqr = getCell():getGridSquare(x,y,z);
	local Jukebox
	if sqr == nil then return end
			for i=1,sqr:getObjects():size() do
				local thisObject = sqr:getObjects():get(i-1)

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
	Jukebox:getModData().OnOff == "on"
	then

	if PlayerPlaylist then Jukebox:getModData().customPlaylist = PlayerPlaylist; end
	--if Jukebox:getModData().OnPlay ~= "nothing" then
	--Jukebox:getModData().SilenceMusic = "yes"
	--end
	
	if Jukebox:getModData().Emitter then
			if not Jukebox:getModData().Jx then
				Jukebox:getModData().Jx = Jukebox:getX()
				Jukebox:getModData().Jy = Jukebox:getY()
				Jukebox:getModData().Jz = Jukebox:getZ()
			end
			local Jx = Jukebox:getModData().Jx
			local Jy = Jukebox:getModData().Jy
			local Jz = Jukebox:getModData().Jz
	
				Jukebox:getModData().Emitter:setPos(Jx, Jy, Jz)
				Jukebox:getModData().Emitter:stopSoundByName(tostring(Jukebox:getModData().genre))
				--Events.OnTick.Remove(anotherkindofhell)
				--Jukebox:getModData().OnPlay = "nothing"
				Jukebox:getModData().SilenceMusic = "no"
	end

	Jukebox:getModData().OnPlay = "nothing"
	--Jukebox:getModData().Length = 3
	Jukebox:getModData().genre = genre

	Jukebox:getModData().Length = length
	Jukebox:getModData().Style = style
	Jukebox:getModData().JukeNoObject = false
	local playercommand = "play"
	local JukeReusableID = Jukebox:getModData().JukeboxID

	OnJukeboxSendSong(x, y, z, false)

	else
		return
	end

end

--[[
local function LSJFcheckForGTLS()
	tickcount = 10/GTLSCheck
end

Events.OnGameStart.Add(LSJFcheckForGTLS)
]]--
