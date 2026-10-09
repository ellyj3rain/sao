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

local function JukeboxGetAT(Jukebox, GlobalMusic)

	------ likely change to moddata tables in the future to accomodate player playlists, should still use old method for default genres and exceptions(missing custom genres)

	local AvailableTracks

	if Jukebox:getModData().Style == "cdisco" then
		AvailableTracks = require("JukeboxTracksCustom/Disco")
		--print("AvailableTracks from custom:", AvailableTracks)
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Disco")
			--print("AvailableTracks from custom:", AvailableTracks)
		end
	elseif Jukebox:getModData().Style == "disco" then
		AvailableTracks = require("JukeboxTracks/Disco")

	elseif Jukebox:getModData().Style == "crbsoul" then
		AvailableTracks = require("JukeboxTracksCustom/RB")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/RB")
		end
	elseif Jukebox:getModData().Style == "rbsoul" then
		AvailableTracks = require("JukeboxTracks/RB")

	elseif Jukebox:getModData().Style == "cmetal" then
		AvailableTracks = require("JukeboxTracksCustom/Metal")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Metal")
		end
	elseif Jukebox:getModData().Style == "metal" then
		AvailableTracks = require("JukeboxTracks/Metal")

	elseif Jukebox:getModData().Style == "csalsa" then
		AvailableTracks = require("JukeboxTracksCustom/Salsa")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Salsa")
		end
	elseif Jukebox:getModData().Style == "salsa" then
		AvailableTracks = require("JukeboxTracks/Salsa")

	elseif Jukebox:getModData().Style == "cpop" then
		AvailableTracks = require("JukeboxTracksCustom/Pop")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Pop")
		end
	elseif Jukebox:getModData().Style == "pop" then
		AvailableTracks = require("JukeboxTracks/Pop")

	elseif Jukebox:getModData().Style == "cbeach" then
		AvailableTracks = require("JukeboxTracksCustom/Beach")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Beach")
		end
	elseif Jukebox:getModData().Style == "beach" then
		AvailableTracks = require("JukeboxTracks/Beach")

	elseif Jukebox:getModData().Style == "cclassical" then
		AvailableTracks = require("JukeboxTracksCustom/Classical")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Classical")
		end
	elseif Jukebox:getModData().Style == "classical" then
		AvailableTracks = require("JukeboxTracks/Classical")

	elseif Jukebox:getModData().Style == "ccountry" then
		AvailableTracks = require("JukeboxTracksCustom/Country")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Country")
		end
	elseif Jukebox:getModData().Style == "country" then
		AvailableTracks = require("JukeboxTracks/Country")

	elseif Jukebox:getModData().Style == "choliday" then
		AvailableTracks = require("JukeboxTracksCustom/Holiday")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Holiday")
		end
	elseif Jukebox:getModData().Style == "holiday" then
		AvailableTracks = require("JukeboxTracks/Holiday")

	elseif Jukebox:getModData().Style == "cjazz" then
		AvailableTracks = require("JukeboxTracksCustom/Jazz")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Jazz")
		end
	elseif Jukebox:getModData().Style == "jazz" then
		AvailableTracks = require("JukeboxTracks/Jazz")

	elseif Jukebox:getModData().Style == "cmuzak" then
		AvailableTracks = require("JukeboxTracksCustom/Muzak")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Muzak")
		end
	elseif Jukebox:getModData().Style == "muzak" then
		AvailableTracks = require("JukeboxTracks/Muzak")

	elseif Jukebox:getModData().Style == "crap" then
		AvailableTracks = require("JukeboxTracksCustom/Rap")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Rap")
		end
	elseif Jukebox:getModData().Style == "rap" then
		AvailableTracks = require("JukeboxTracks/Rap")

	elseif Jukebox:getModData().Style == "creggae" then
		AvailableTracks = require("JukeboxTracksCustom/Reggae")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Reggae")
		end
	elseif Jukebox:getModData().Style == "reggae" then
		AvailableTracks = require("JukeboxTracks/Reggae")

	elseif Jukebox:getModData().Style == "crock" then
		AvailableTracks = require("JukeboxTracksCustom/Rock")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/Rock")
		end
	elseif Jukebox:getModData().Style == "rock" then
		AvailableTracks = require("JukeboxTracks/Rock")

	elseif Jukebox:getModData().Style == "cworld" then
		AvailableTracks = require("JukeboxTracksCustom/World")
		if not AvailableTracks or not (#AvailableTracks > 0) then
			AvailableTracks = require("JukeboxTracks/World")
		end
	elseif Jukebox:getModData().Style == "world" then
		AvailableTracks = require("JukeboxTracks/World")

	elseif Jukebox:getModData().Style == "customPlaylist" then
		AvailableTracks = Jukebox:getModData().customPlaylist

	elseif Jukebox:getModData().Style == "tm" and GlobalMusic then
		AvailableTracks = {}
		for k,v in pairs(GlobalMusic) do
			AvailableTracks[#AvailableTracks + 1] = k
		end

	end	
	return AvailableTracks
end

local function JukeboxGetMusic(Jukebox, previoussong, GlobalMusic)

	local AvailableTracks = JukeboxGetAT(Jukebox, GlobalMusic)
	local sound
	local length
	local randomNumber = ZombRand(#AvailableTracks) + 1
	
	if (Jukebox:getModData().Style == "tm" and GlobalMusic) or (Jukebox:getModData().Style == "customPlaylist") then
		length = 0
		sound = AvailableTracks[randomNumber]
	else
		-- RANDOMIZING WHICH AVAILABLE TRACK WILL BE PICKED IN A GIVEN ACTION AND SETTING THE LENGTH
		sound = AvailableTracks[randomNumber].sound
		length = AvailableTracks[randomNumber].length
	
		if tostring(AvailableTracks[randomNumber].sound) == previoussong then
			if AvailableTracks[randomNumber+1] and AvailableTracks[randomNumber+1].sound then
				sound = AvailableTracks[randomNumber+1].sound
				length = AvailableTracks[randomNumber+1].length
			elseif AvailableTracks[randomNumber-1] and AvailableTracks[randomNumber-1].sound then
				sound = AvailableTracks[randomNumber-1].sound
				length = AvailableTracks[randomNumber-1].length
			end
		end
	end
	Jukebox:getModData().genre = tostring(sound)
	Jukebox:getModData().Length = 0

	return 0, sound

end

local function getCustomName(object)
	if not object then return nil; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") and (properties:get("CustomName") == "Jukebox") then
        return true
    end
    return nil
end

function JukeboxMusicCheck(playerObj)

	local configVol = JukeboxMenu.configVol or 1
	local config3D = JukeboxMenu.config3D
	local jukelist = require("Properties/Objects/List")

			if #jukelist > 0 then
                
				for i,v in ipairs(jukelist) do
					local hasCustomName = getCustomName(v)
					if not (SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true) and v:hasModData() and
					v:getModData().OnOff and hasCustomName and
					v:getModData().JukeinRange and 
					--v:getModData().JukeinRange ~= "out of range" and 
					--v:getModData().OnOff == "on" and
					v:getModData().Emitter and not
					v:getModData().JukeNoObject then
			
					---
						local Jukebox = v
					
						if not Jukebox:getModData().JukeboxVolume then Jukebox:getModData().JukeboxVolume = 1; end
						--local playerData = getPlayer():getModData()
						--if not playerData.JukeboxVolumeAll or not tonumber(playerData.JukeboxVolumeAll) then
						--	playerData.JukeboxVolumeAll = 1
						--end
						--if not playerData.Jukebox3D then playerData.Jukebox3D = {true}; end



	-------------------------
	
			if not Jukebox:getModData().Jx then
				Jukebox:getModData().Jx = Jukebox:getX()
				Jukebox:getModData().Jy = Jukebox:getY()
				Jukebox:getModData().Jz = Jukebox:getZ()
			end
			local Jx = Jukebox:getModData().Jx
			local Jy = Jukebox:getModData().Jy
			local Jz = Jukebox:getModData().Jz
            if Jukebox:getModData().OnOff == "off" then
				Jukebox:getModData().Emitter:setPos(Jx, Jy, Jz)
				Jukebox:getModData().Emitter:stopSoundByName(tostring(Jukebox:getModData().genre))
				--Events.OnTick.Remove(anotherkindofhell)
				Jukebox:getModData().OnPlay = "nothing"
				--local playercommand = "stop"
				--local JukeReusableID = Jukebox:getModData().JukeboxID
				--isJukeSendSong(JukeReusableID, genre, Jx, Jy, Jz, playercommand)
             end

            if Jukebox:getModData().OnOff == "on" and Jukebox:getModData().SilenceMusic == "yes" then
				Jukebox:getModData().Emitter:setPos(Jx, Jy, Jz)
				Jukebox:getModData().Emitter:stopSoundByName(tostring(Jukebox:getModData().genre))
				--Events.OnTick.Remove(anotherkindofhell)
				Jukebox:getModData().OnPlay = "nothing"
				Jukebox:getModData().SilenceMusic = "no"
             end

			if configVol ~= Jukebox:getModData().JukeboxVolume then
				Jukebox:getModData().JukeboxVolume = configVol
				Jukebox:getModData().Emitter:setVolume(Jukebox:getModData().OnPlayEMITTER, Jukebox:getModData().JukeboxVolume)
			end
			if config3D ~= Jukebox:getModData().Jukebox3D then
				Jukebox:getModData().Jukebox3D = config3D
				Jukebox:getModData().Emitter:set3D(Jukebox:getModData().OnPlayEMITTER, Jukebox:getModData().Jukebox3D)
			end

			if Jukebox:getModData().OnPlay and
			Jukebox:getModData().OnPlay ~= "nothing" and
			Jukebox:getModData().JukeinRange ~= "out of range" then


					
				Jukebox:getModData().Emitter:setPos(Jx, Jy, Jz)
				local Time = Jukebox:getModData().OnPlayTime
				local Length = Jukebox:getModData().Length
				local audioEmitter = Jukebox:getModData().OnPlayEMITTER
				
					if (Length ~= 0 and ((Length + Time) <= getTimestamp())) or (Length == 0 and audioEmitter and not Jukebox:getModData().Emitter:isPlaying(audioEmitter)) then
					
						local genre = Jukebox:getModData().genre
						
						if genre ~= "JukeboxAfterTurnOn" then--JUKEBOX PAUSES TO SWITCH
							
							local previoussong = tostring(genre)
							Jukebox:getModData().previousSong = previoussong
							Jukebox:getModData().genre = "JukeboxAfterTurnOn"
							local genre = "JukeboxAfterTurnOn"
							Jukebox:getModData().Length = 3
							local length = Jukebox:getModData().Length
							local style = Jukebox:getModData().Style
							--Jukebox:transmitModData()--Remove transmit if each player hear their own songs REMOVE OTHERS THAT TRANSMIT GENTE AND LENGTH AS WELL
							--Events.OnTick.Remove(anotherkindofhell)
							--print("this is the last song played" .. previoussong)
							Jukebox:getModData().OnPlay = "nothing"
							OnJukeboxStyleChange(Jx, Jy, Jz, style, length, genre)
						
						else--PAUSE ENDED

							local previoussong = "nothing"
							if Jukebox:getModData().previousSong ~= nil then
							previoussong = tostring(Jukebox:getModData().previousSong)
							end

							local length, sound = JukeboxGetMusic(Jukebox, previoussong, GlobalMusic)
							local style = Jukebox:getModData().Style
							Jukebox:getModData().OnPlay = "nothing"
							OnJukeboxStyleChange(Jx, Jy, Jz, style, length, sound)

					end--PAUSE
				end--TIMETOSWITCH
		end

	

	-------------------------------



					end--onoff
				end--for
			end--jukelist



end
