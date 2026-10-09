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
require "JukeboxContextMenu"
JukeboxMenu = JukeboxMenu or {}

local function getAvailableGenres()
	local availableGenres = {{name="Disco",trait="disco"}, {name="RB",trait="rbsoul"}, {name="Metal",trait="metal"}, {name="Salsa",trait="salsa"}, {name="Pop",trait="pop"}, {name="Beach",trait="beach"},
	{name="Classical",trait="classical"}, {name="Country",trait="country"}, {name="Holiday",trait="holiday"}, {name="Jazz",trait="jazz"}, {name="Muzak",trait="muzak"}, {name="Rap",trait="rap"},
	{name="Reggae",trait="reggae"}, {name="Rock",trait="rock"}, {name="World",trait="world"}}

	return availableGenres
end

local volumeOptions = {
	{"Increase2Option","volumevhigh",0.4,false,2.8},
	{"IncreaseOption","volumehigh",0.2,false,3.2},
	{"DecreaseOption","volumelow",-0.2,true,0.02},
	{"Decrease2Option","volumevlow",-0.4,true,0.08},
}

local function doVolumeOption(thisPlayer, context, parentMenu, playerData)
	local volOption = parentMenu:addOption(getText("ContextMenu_Jukebox_Volume"));
	volOption.iconTexture = getTexture('media/ui/moodles/MusicGood.png')
	local volumeMenu = parentMenu:getNew(parentMenu);
	context:addSubMenu(volOption, volumeMenu)

	--if not playerData.JukeboxVolumeAll or type(playerData.JukeboxVolumeAll) ~= "number" then playerData.JukeboxVolumeAll = 1; end

	--local volumeOptions = getVolumeOptions()
	local ogVol = JukeboxMenu.configVol or 1
	
	for _,v in pairs(volumeOptions) do
		local option = volumeMenu:addOption(getText("ContextMenu_Jukebox_Volume_"..v[1]), thisPlayer, JukeboxMenu.onVolumeChange, ogVol, v[3])
		option.iconTexture = getTexture('media/ui/'..v[2]..'_icon.png')
		if (v[4] and ogVol <= v[5]) or (not v[4] and ogVol >= v[5]) then option.notAvailable = true; end
	end
end

local function doSurroundOption(thisPlayer, parentMenu, playerData)
	local tex, tpText = 'media/ui/okay_icon.png', "Tooltip_Jukebox_3DDisable"
	--if not playerData.Jukebox3D then playerData.Jukebox3D = {true}; end
	local option = parentMenu:addOption(getText("ContextMenu_Jukebox_3D"), thisPlayer, JukeboxMenu.on3DChange, not JukeboxMenu.config3D)
	if not JukeboxMenu.config3D then
		tex, tpText = 'media/ui/okayNo_icon.png', "Tooltip_Jukebox_3DEnable"
	end
	option.iconTexture = getTexture(tex)
	option.toolTip = LSUtil.getSimpleTooltip(getText(tpText))
end

local function doTurnOnOffOption(thisPlayer, parentMenu, Jukebox, playerData, JukeboxData, canWalkAdj)
	local state = "Off"
	if JukeboxData.OnOff ~= "on" then state = "On"; end
	local option = parentMenu:addOptionOnTop(getText("ContextMenu_Jukebox_Turn"..state),thisPlayer,JukeboxMenu.onTurnOnOff,Jukebox,{"JukeboxTurn"..state,"JukeboxAfterTurnOn",state, canWalkAdj})
	option.iconTexture = getTexture('media/ui/lightbulb'..state..'_icon.png')
end

local function doMusicOptions(thisPlayer, context, parentMenu, Jukebox, switchSound, addon, canWalkAdj)
	local addonTracks, text, tex, trackDir = false, "ContextMenu_Play_Group_Styles", 'djbooth', "JukeboxTracks"

	if addon then text, tex, trackDir = text.."Custom", 'addon', trackDir.."Custom"; end

	local genres = getAvailableGenres()
	local stylesOption = parentMenu:addOption(getText("ContextMenu_Play_Group_Styles"))
	stylesOption.iconTexture = getTexture('media/ui/'..tex..'_icon.png')	
	local subMenu = parentMenu:getNew(parentMenu)
	context:addSubMenu(stylesOption, subMenu)
	
	for k,v in ipairs(genres) do
		local tracks = require(trackDir.."/"..v.name)
		if tracks and #tracks > 0 then
			local randomTrack = tracks[ZombRand(#tracks)+1]
			option = subMenu:addOption(getText("ContextMenu_Play_Style_"..v.name), thisPlayer, JukeboxMenu.onPlay, Jukebox, {switchSound, randomTrack.sound, 0, randomTrack.genre, nil, canWalkAdj})	 -- randomTrack.length replaced by 0
			option.iconTexture = getTexture('media/ui/Traits/trait_'..v.trait..'.png')
		end
	end
end

local function hasMusicAddons()
	local addonTracks = require("TimedActions/PlayJukeboxCustomTracks")
	return (addonTracks and #addonTracks > 0) or (GlobalMusic and LS_AMcache and LS_AMcache['truemusic'])
end

local function getNewPlaylist()
	return {
	{name="Playlist1",songs={}},
	{name="Playlist2",songs={}},
	{name="Playlist3",songs={}},
	{name="Playlist4",songs={}},
	}
end

local function doPlaylistOption(thisPlayer, context, parentMenu, Jukebox, playerData, JukeboxData, switchSound, canWalkAdj)
	local playlistOption = parentMenu:addOptionOnTop(getText("ContextMenu_PlayerPlaylist_Main"))
	playlistOption.iconTexture = getTexture('media/ui/myplaylists_icon.png')
	local subMenu = parentMenu:getNew(parentMenu);
	context:addSubMenu(playlistOption, subMenu)

	if not playerData.LSJukeboxCustomPlaylist then playerData.LSJukeboxCustomPlaylist = getNewPlaylist(); end

------------------Manage Option
	local optionManage = subMenu:addOption(getText("ContextMenu_PlayerPlaylist_Manage"),thisPlayer,JukeboxMenu.onManagePlaylist,Jukebox,"manage")
	optionManage.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_LSCPM_Manage"))
	optionManage.iconTexture = getTexture('media/ui/gears_icon.png')

------------------Import Option
	local importOption = subMenu:addOption(getText("ContextMenu_PlayerPlaylist_Import"))
	importOption.iconTexture = getTexture('media/ui/playlistimport_icon.png')
	importOption.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_LSCPM_Import"))
	local importSubMenu = subMenu:getNew(subMenu)
	context:addSubMenu(importOption, importSubMenu)
	
------------------Play Option
	local playOption = subMenu:addOption(getText("ContextMenu_PlayerPlaylist_Play"))
	local playSubMenu = subMenu:getNew(subMenu)
	context:addSubMenu(playOption, playSubMenu);

------------------Get Playlists

	local playlistIdx, hasPlaylist = 0, false

	for k,v in ipairs(playerData.LSJukeboxCustomPlaylist) do
		playlistIdx = playlistIdx+1
		if JukeboxData.customPlaylist and (#JukeboxData.customPlaylist > 1) then
			local option = importSubMenu:addOption(getText("ContextMenu_PlayerPlaylist_ImportTo")..v.name, thisPlayer, JukeboxMenu.onManagePlaylist, Jukebox, "share", playlistIdx)
			option.iconTexture = getTexture('media/ui/playlist'..playlistIdx..'_icon.png')
		end
		if v.songs and (#v.songs) > 1 then
			hasPlaylist = true
			local randomCustomTrack = v.songs[ZombRand(#v.songs)+1]
			local option = playSubMenu:addOption(v.name, thisPlayer, JukeboxMenu.onPlay, Jukebox, {switchSound, randomCustomTrack, 0, "customPlaylist", v.songs, canWalkAdj})
			option.iconTexture = getTexture('media/ui/playlist'..playlistIdx..'_icon.png')
		end
	end
	
	local tex = 'djbooth'
	if not hasPlaylist then
		playOption.notAvailable = true
		playOption.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_LSCPM_NoPlaylists"))
		tex = 'djboothNo'
	end
	playOption.iconTexture = getTexture('media/ui/'..tex..'_icon.png')
end

JukeboxMenu.doBuildMenu = function(player, context, worldobjects, Jukebox, spriteName, customName, groupName, DebugBuildOption)
	if not LSUtil.isValidObj(Jukebox, spriteName) then return; end
	if not LSUtil.sqrHasEnergy(Jukebox:getSquare()) then return; end

	local thisPlayer = LSUtil.getValidPlayer(player)
	if LSUtil.isCharBusy(thisPlayer) then return; end
	local playerData = thisPlayer:getModData()
    local JukeboxData = Jukebox:getModData()
	
	local addData
	if not JukeboxData.JukeboxID then
		if not addData then addData = {}; end
		JukeboxData.JukeboxID = {(tostring(Jukebox:getX()) .. "," .. tostring(Jukebox:getY()) .. "," .. tostring(Jukebox:getZ()))}
		addData.JukeboxID = JukeboxData.JukeboxID
	end
	if not JukeboxData.OnOff then 
		if not addData then addData = {}; end
		JukeboxData.OnOff = "off"
		addData.OnOff = JukeboxData.OnOff
	end
	if addData then
		sendClientCommand("LS", "ModifyObjData", {{Jukebox:getX(),Jukebox:getY(),Jukebox:getZ(),Jukebox:getSprite():getName()}, false, addData})
	end


-----------------------Category
	local jukeboxMenuOption = context
	if JukeboxData.OnOff == "on" then
		local jukeboxName = LSUtil.getMoveableDisplayName("JUKEBOX", Jukebox, customName, groupName)
		local jukeboxOption = context:addOptionOnTop(jukeboxName)
		jukeboxOption.iconTexture = getSprite(spriteName):getTextureForCurrentFrame(IsoDirections.E)
		jukeboxMenuOption = ISContextMenu:getNew(context)
		context:addSubMenu(jukeboxOption, jukeboxMenuOption)
	end
	local canWalkAdj = groupName and groupName == "Gramophone"
-----------------------On Off Option
	doTurnOnOffOption(thisPlayer, jukeboxMenuOption, Jukebox, playerData, JukeboxData, canWalkAdj)
	if JukeboxData.OnOff ~= "on" then return; end
	local switchSound = "JukeboxSwitch0"..tostring(ZombRand(3)+1)
-----------------------Play Music Options
	doMusicOptions(thisPlayer, context, jukeboxMenuOption, Jukebox, switchSound, nil, canWalkAdj) -- base
	if hasMusicAddons() then
		doMusicOptions(thisPlayer, context, jukeboxMenuOption, Jukebox, switchSound, true, canWalkAdj) -- addons
		doPlaylistOption(thisPlayer, context, jukeboxMenuOption, Jukebox, playerData, JukeboxData, switchSound, canWalkAdj) -- playlist
	end
-----------------------Volume Option
	doVolumeOption(thisPlayer, context, jukeboxMenuOption, playerData)
-----------------------3D Surround Option
	doSurroundOption(thisPlayer, jukeboxMenuOption, playerData)
---------------------

-----------------------Want to Dance Option
	playerData.WantsToDance = playerData.WantsToDance or false
	--local PlayerWantsToDanceOption = context:addOptionOnTop(getText("ContextMenu_DancingPartner_Enable_Option"), thisPlayer, JukeboxMenu.onEnableDancing);
	--PlayerWantsToDanceOption.iconTexture = getTexture('media/ui/okay_icon.png')
	
end
