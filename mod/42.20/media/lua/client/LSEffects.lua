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

LS_AMcache['truemusic'] = LS_AMcache['truemusic'] or (not LS_AMcache['truemusic_cached'] and LS_PatchUtils.hasCompatMod('truemusic'))

if LS_AMcache['truemusic'] then
	require "TCMusicDefenitions"
end

function OnJukeboxSendSong(x, y, z, ThisJuke)

	local ThisJuke = ThisJuke or false
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
			
	if ThisJuke ~= nil and ThisJuke ~= false then
		if not Jukebox then
			if ThisJuke:hasModData() then
			ThisJuke:getModData().JukeNoObject = true
			return
			end
		end
		Jukebox = ThisJuke
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

	--if not Jukebox:getModData().Emitter then
		Jukebox:getModData().Emitter = getWorld():getFreeEmitter()
	--end
	--local emitter = Jukebox:getModData().Emitter
	--local audio
	Jukebox:getModData().Jx = Jukebox:getX()
	Jukebox:getModData().Jy = Jukebox:getY()
	Jukebox:getModData().Jz = Jukebox:getZ()

	if Jukebox:hasModData() and
	Jukebox:getModData().OnOff ~= nil then

		local JukeboxVolume = JukeboxMenu.configVol or 1
		--local playerData = getPlayer():getModData()
		--if playerData.JukeboxVolumeAll ~= nil and tonumber(playerData.JukeboxVolumeAll) ~= nil then
		--	JukeboxVolume = tonumber(playerData.JukeboxVolumeAll)
		--else
		--	playerData.JukeboxVolumeAll = 1
		--end
		--if not playerData.Jukebox3D then playerData.Jukebox3D = {true}; end

		if Jukebox:getModData().Emitter then
			--print("is emitter")
			Jukebox:getModData().Emitter:setPos(Jukebox:getModData().Jx, Jukebox:getModData().Jy, Jukebox:getModData().Jz);--EMITTER SQUARE
			Jukebox:getModData().OnPlayEMITTER = Jukebox:getModData().Emitter:playSoundImpl(Jukebox:getModData().genre, false, Jukebox)
			--audio = emitter:playSoundImpl(Jukebox:getModData().genre, false, Jukebox);--SOUND THAT WILL BE PLAYED (SOUND NAME, IF IS WORLDSOUND, ISOOJECT)
			--audio = Jukebox:getModData().OnPlayEMITTER
		--	if Jukebox:getModData().Length == 0 then
		--		Jukebox:getModData().OnPlayEMITTER = audio
		--	end
			
			--local TMMusic
--			else
--				TMMusic = nil
--			end
			
--			if TMMusic and playerData.JukeboxVolumeAll and (playerData.JukeboxVolumeAll > 0.4) then
--				playerData.JukeboxVolumeAll = 0.4
--				JukeboxVolume = tonumber(playerData.JukeboxVolumeAll)
--			end
			
			addSound(Jukebox, Jukebox:getModData().Jx, Jukebox:getModData().Jy, Jukebox:getModData().Jz, 30, 10)
			Jukebox:getModData().Emitter:setVolume(Jukebox:getModData().OnPlayEMITTER, JukeboxVolume)
			Jukebox:getModData().Emitter:set3D(Jukebox:getModData().OnPlayEMITTER, JukeboxMenu.config3D)

			Jukebox:getModData().OnPlay = "playing"
			Jukebox:getModData().OnPlayTime = getTimestamp()
		--if Jukebox:getModData().OnOff == "on" then
	
	-------------------------

	-------------------------------
	
		--else
	
		--end
		end
	end
end

