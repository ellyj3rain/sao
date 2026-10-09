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

JukeboxMenu = {};
JukeboxMenu.configVol = LS_FileMng.getLineValue("LSConfig.ini", "jukeboxVol", "num") or 1
JukeboxMenu.config3D = LS_FileMng.getOrCreateLineValue("LSConfig.ini", "jukebox3D", true, "bool")

JukeboxMenu.walkLogic = function(character, obj, walkAdj)
	if walkAdj then return LSUtil.walkToAdj(character, obj); end
	return LSUtil.walkToFront(character, obj)
end

JukeboxMenu.onEnableDancing = function(player)
	player:getModData().WantsToDance = true
end

JukeboxMenu.onDisableDancing = function(player)
	player:getModData().WantsToDance = false
end

local previousJukeboxVolumeChange

local function getVolumeChangeSound(og, new, add)
	local soundName = "UI_Speed_DOWN"
	if add then soundName = "UI_Speed_UP"; end
	local t = {
		{0.4,"3"},
		{0.2,"2"},
		{0,"1"},
	}
	for _,v in pairs(t) do
		if (not add and og-v[1] > new) or (add and og+v[1] < new) then 
			soundName = soundName..v[2]; break
		end
	end
	return soundName
end

local function jukeboxIsValid(Jukebox)
	if not LSUtil.isValidObj(Jukebox, "JUKEBOX") or not LSUtil.sqrHasEnergy(Jukebox:getSquare()) then return false; end
	if Jukebox:getModData().OnOff ~= "on" then return false; end
	return true
end

JukeboxMenu.onVolumeChange = function(player, ogVol, change)

	if previousJukeboxVolumeChange and change == previousJukeboxVolumeChange then change = change*2; end

	--local ogVol = tonumber(player:getModData().JukeboxVolumeAll)
	local newVol = math.max(0.02,math.min(3.2,ogVol+change))

	local sound = getVolumeChangeSound(ogVol, newVol, change > 0)
	getSoundManager():playUISound(sound)

	previousJukeboxVolumeChange = change
	
	JukeboxMenu.configVol = newVol
	LS_FileMng.changeLine("LSConfig.ini", "jukeboxVol", tostring(newVol))
	--player:getModData().JukeboxVolumeAll = newVol
end

JukeboxMenu.on3DChange = function(player, change)
	getSoundManager():playUISound("UI_Button_SELECT")
	JukeboxMenu.config3D = change
	LS_FileMng.changeLine("LSConfig.ini", "jukebox3D", change, "bool")
	--player:getModData().Jukebox3D[1] = change
end

JukeboxMenu.onPlay = function(character, obj, args) -- soundFile, soundEnd, Length, Style, PlaylistData, walkAdj
	if not jukeboxIsValid(obj) then return; end

	if args[4] == "customPlaylist" and args[5] then
		obj:getModData().customPlaylist = args[5]
	end

	if JukeboxMenu.walkLogic(character, obj, args[6]) then
		ISTimedActionQueue.add(JukeboxPlay:new(character, obj, args[1], args[2], args[3], args[4], args[5]));
	end
end

JukeboxMenu.onManagePlaylist = function(player, Jukebox, action, idx)
	if not jukeboxIsValid(Jukebox) then return; end
	
	if action == "share" then
		if #player:getModData().LSJukeboxCustomPlaylist[idx].songs > 0 then
			getSoundManager():playUISound("UI_Button_SELECT")
			local Import = Jukebox:getModData().customPlaylist
			local thisplayer = getPlayer():getPlayerNum()
			local PlaylistImportConfirm = PlaylistImportConfirm:new(thisplayer, Import, idx)
			PlaylistImportConfirm:initialise();
			PlaylistImportConfirm:addToUIManager()
		else
			player:getModData().LSJukeboxCustomPlaylist[idx].songs = Jukebox:getModData().customPlaylist
			HaloTextHelper.addGoodText(player, getText("IGUI_HaloNote_PlaylistGet"))
			HaloTextHelper.addGoodText(player, #player:getModData().LSJukeboxCustomPlaylist[idx].songs..getText("IGUI_HaloNote_PlaylistGetEnd"))
		end
		return
	end
	--if not player:getModData().LSPlaylistMenuOverlayPanel then
		player:getModData().LSPlaylistMenuOverlayPanel = true
		local thisplayer = getPlayer():getPlayerNum()
		local LSCustomPlaylistMenuOverlay = LSPlaylistMenu:new(getCore():getScreenWidth()/2-550,getCore():getScreenHeight()/2-350,645,390,thisplayer,player:getModData().LSJukeboxCustomPlaylist);
		LSCustomPlaylistMenuOverlay:initialise();
		LSCustomPlaylistMenuOverlay:addToUIManager();
		--
		setJoypadFocus(player:getPlayerNum(), LSCustomPlaylistMenuOverlay)--(Burryaga's compat patch for joypad users)
		--
	--end
end

JukeboxMenu.onTurnOnOff = function(character, obj, args) -- clickSound, turnSound, state, walkAdj
	if JukeboxMenu.walkLogic(character, obj, args[4]) then
		if not LSUtil.isValidObj(obj, "JUKEBOX") then return; end
		if args[3] == "Off" then
			ISTimedActionQueue.add(JukeboxOff:new(character, obj, args[1], args[2]));
		else
			ISTimedActionQueue.add(JukeboxOn:new(character, obj, args[1], args[2]))	
		end
	end
end

--[[
JukeboxMenu.onTurnOn = function(player, Jukebox, soundFile, soundEnd)
	if JukeboxMenu.walkLogic(player, Jukebox) then
		ISTimedActionQueue.add(JukeboxOn:new(player, Jukebox, soundFile, soundEnd));
	end
end

JukeboxMenu.onTurnOff = function(player, Jukebox, soundFile, soundEnd)
	if JukeboxMenu.walkLogic(player, Jukebox) then
		ISTimedActionQueue.add(JukeboxOff:new(player, Jukebox, soundFile, soundEnd));
	end
end

Events.OnFillWorldObjectContextMenu.Add(JukeboxMenu.doBuildMenuTurnOnOff);
]]--
