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

---------------------------------------Gamepad Support
--Big thanks to Burryaga for making the gamepad support patch for the playlist menu!
---------------------------------------
require "ISUI/ISPanelJoypad"

LS_AMcache['truemusic'] = LS_AMcache['truemusic'] or (not LS_AMcache['truemusic_cached'] and LS_PatchUtils.hasCompatMod('truemusic'))

if LS_AMcache['truemusic'] then
	require "TCMusicDefenitions"
end

LSPlaylistMenu = ISPanelJoypad:derive("LSPlaylistMenu")
LSPMSearchBox = ISTextEntryBox:derive("LSPMSearchBox")

--local selectedSong

--local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
--local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local function LSPMdoTrim(s)
	return s:match("^%s*(.-)%s*$")
end

local function LSPMgetMusicOptions(style, newCustomPlaylist, filterBar)
	local getAvailableMusic = {}
	local tempAvailableMusic = {}
	local loadTracks, filter, trimmedFilter
	if filterBar then trimmedFilter = LSPMdoTrim(filterBar); end
	
	if trimmedFilter and (trimmedFilter ~= "Search...") and (trimmedFilter ~= "") and (trimmedFilter ~= " ") then filter = string.lower(trimmedFilter); end

	if style ~= "tm" then
		loadTracks = require("JukeboxTracksCustom/"..style)
		if loadTracks and (#loadTracks > 0) then
			for k, v in ipairs(loadTracks) do
				if filter then
					local soundLC = string.lower(v.sound)
					if string.find(soundLC, filter) then table.insert(tempAvailableMusic, v.sound); end
				else
					table.insert(tempAvailableMusic, v.sound)
				end
			end
		end
	else
		for k,v in pairs(GlobalMusic) do
			if luautils.stringStarts(k, "Cassette") then
				if filter then
					local soundLC = string.lower(k)
					if string.find(soundLC, filter) then tempAvailableMusic[#tempAvailableMusic + 1] = k; end
				else
					tempAvailableMusic[#tempAvailableMusic + 1] = k
				end
			end
		end
	end

	if tempAvailableMusic and (#tempAvailableMusic > 0) and newCustomPlaylist and (#newCustomPlaylist > 0) then
		local songInPlaylist
		for n=1, #tempAvailableMusic do
			songInPlaylist = false
				for numb=1, #newCustomPlaylist do
					if tempAvailableMusic[n] == newCustomPlaylist[numb] then songInPlaylist = true; break; end
				end
				if not songInPlaylist then
					if filter then
						local soundLC = string.lower(tempAvailableMusic[n])
						if string.find(soundLC, filter) then table.insert(getAvailableMusic, tempAvailableMusic[n]); end
					else
						table.insert(getAvailableMusic, tempAvailableMusic[n])
					end
				end
			end	
	else
		return tempAvailableMusic
	end
	table.sort(getAvailableMusic)
	return getAvailableMusic
end

local function LSPMdoImageType(x,y,w,h,texture)
	local newImage = ISImage:new(x, y, w, h, texture)
	return newImage
end

function LSPMSearchBox:onTextChange()
    --self.currentText = self.javaObject:getText()
	--self.currentText = self:getInternalText()--2nd implementation
	self:setText(self:getInternalText())
end

function LSPMSearchBox:getUpdatedText()
    return self:getText()
end

function LSPMSearchBox:new(title, x, y, width, height)
    local o = ISTextEntryBox.new(self, title, x, y, width, height)
    --o.currentText = title
    return o
end

function LSPlaylistMenu:onClickSongSM()
	if not self.SMScrollList.selected then return; end
	self.selectedSong = self.SMScrollList.items[self.SMScrollList.selected].item
	self.PlayMusicButton:setEnable(true)
end

function LSPlaylistMenu:onDoubleClickSongSM()
	if not self.SMScrollList.selected then return; end
	if self.isPlayingSong then
		getSoundManager():stopUISound(self.isPlayingSong)
		self.isPlayingSong = false
		self.StopMusicButton:setEnable(false)
	end
	self.selectedSongToRemove = self.SMScrollList.items[self.SMScrollList.selected].item
	for n=1, #self.newCustomPlaylist[self.idxFocus].pl do
		if self.newCustomPlaylist[self.idxFocus].pl[n] == self.selectedSongToRemove then
			table.remove(self.newCustomPlaylist[self.idxFocus].pl, n)
			break
		end
	end
	local text = self.selectedSongToRemove
	if (string.sub(self.selectedSongToRemove, 1, #self.tmPrefix) == self.tmPrefix) then text = string.sub(self.selectedSongToRemove, #self.tmPrefix + 1); end
	self.SMScrollList:removeItem(text)
	if #self.SMScrollList.items > 0 then
		self.selectedSong = self.SMScrollList.items[self.SMScrollList.selected].item
		self.PlayMusicButton:setEnable(true)
	else
		self.selectedSong = false
		self.PlayMusicButton:setEnable(false)
	end
	self.selectedSongToRemove = false
end

function LSPlaylistMenu:onClickSongAM()
	if not self.AMScrollList.selected then return; end
	self.selectedSong = self.AMScrollList.items[self.AMScrollList.selected].item
	self.selectedSongToAdd = self.AMScrollList.items[self.AMScrollList.selected].item
	self.PlayMusicButton:setEnable(true)
end

function LSPlaylistMenu:onDoubleClickSongAM()
	if not self.AMScrollList.selected then return; end
	-- joypad compat patch
	if self.joypadIndex == 3 then
		return self:onClick({ internal = "AddSong" })
	end
	--
	if self.isPlayingSong then
		getSoundManager():stopUISound(self.isPlayingSong)
	end
	self.selectedSong = self.AMScrollList.items[self.AMScrollList.selected].item
	self.selectedSongToAdd = self.AMScrollList.items[self.AMScrollList.selected].item
	self.isPlayingSong = getSoundManager():playUISound(self.selectedSong)
	self.PlayMusicButton:setEnable(false)
	self.StopMusicButton:setEnable(true)
end

function LSPlaylistMenu:onClick(button)

    if button.internal == "Close" then
        self:close()
	elseif button.internal == "CloseSave" then
		--self.newCustomPlaylist[self.idxFocus].name = self.playlistNameBox.currentText
		self.newCustomPlaylist[self.idxFocus].name = self.playlistNameBox:getText()
		local specificPlayer = getSpecificPlayer(0)
		for n=1, 4 do
			specificPlayer:getModData().LSJukeboxCustomPlaylist[n].songs = self.newCustomPlaylist[n].pl
			specificPlayer:getModData().LSJukeboxCustomPlaylist[n].name = self.newCustomPlaylist[n].name
		end
		self:close()
	elseif button.internal == "AddSong" then
		if not self.selectedSongToAdd then return; end
		local text = self.selectedSongToAdd
		if (string.sub(self.selectedSongToAdd, 1, #self.tmPrefix) == self.tmPrefix) then text = string.sub(self.selectedSongToAdd, #self.tmPrefix + 1); end
		self.AMScrollList:removeItem(text)
		self.SMScrollList:addItem(text, self.selectedSongToAdd)
		table.insert(self.newCustomPlaylist[self.idxFocus].pl, self.selectedSongToAdd)
		if #self.AMScrollList.items > 0 then
			self.selectedSongToAdd = self.AMScrollList.items[self.AMScrollList.selected].item
			self.selectedSong = self.AMScrollList.items[self.AMScrollList.selected].item
			self.PlayMusicButton:setEnable(true)
			self.SMScrollList:ensureVisible(#self.SMScrollList.items)
		else
			self.selectedSongToAdd = false
			self.selectedSong = false
			self.PlayMusicButton:setEnable(false)
		end
	elseif button.internal == "PlaySong" then
		if not self.selectedSong then return; end
		if self.isPlayingSong then
			getSoundManager():stopUISound(self.isPlayingSong)
		end
		self.isPlayingSong = getSoundManager():playUISound(self.selectedSong)
		self.PlayMusicButton:setEnable(false)
		self.StopMusicButton:setEnable(true)
	elseif button.internal == "StopSong" then
		if self.isPlayingSong then
			getSoundManager():stopUISound(self.isPlayingSong)
			self.isPlayingSong = false
		end
		self.StopMusicButton:setEnable(false)
	end
end

function LSPlaylistMenu:onChangeCategory(button)
	if self.newMusicCategory == button.internal then return; end
	if self.CatDiscoButton.internal ~= button.internal then self.CatDiscoButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatClassicalButton.internal ~= button.internal then self.CatClassicalButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatCountryButton.internal ~= button.internal then self.CatCountryButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatJazzButton.internal ~= button.internal then self.CatJazzButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatMetalButton.internal ~= button.internal then self.CatMetalButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatPopButton.internal ~= button.internal then self.CatPopButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatRapButton.internal ~= button.internal then self.CatRapButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatRBButton.internal ~= button.internal then self.CatRBButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatReggaeButton.internal ~= button.internal then self.CatReggaeButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatRockButton.internal ~= button.internal then self.CatRockButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatSalsaButton.internal ~= button.internal then self.CatSalsaButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatTMButton.internal ~= button.internal then self.CatTMButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end
	if self.CatWorldButton.internal ~= button.internal then self.CatWorldButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png")); end

	button:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBS.png"))
	self.newMusicCategory = button.internal
end

local function LSPMloadPlaylist(currentPlaylist)
	local getMusic = {}
	if #currentPlaylist.songs == 1 then
		table.insert(getMusic, currentPlaylist.songs[1])
	else
		for n=1, #currentPlaylist.songs do
			table.insert(getMusic, currentPlaylist.songs[n])
		end
	end
	return getMusic
end

function LSPlaylistMenu:onClearPlaylist(button)
	self.SMScrollList:clear()
	self.newCustomPlaylist[self.idxFocus].pl = {}
	if button.internal == "ClearReset" then
		if self.originalPlaylist[self.idxFocus].songs and (#self.originalPlaylist[self.idxFocus].songs > 0) then
			self.newCustomPlaylist[self.idxFocus].pl = LSPMloadPlaylist(self.originalPlaylist[self.idxFocus])
			for n=1, #self.originalPlaylist[self.idxFocus].songs do
				local text = self.originalPlaylist[self.idxFocus].songs[n]
				if (string.sub(self.originalPlaylist[self.idxFocus].songs[n], 1, #self.tmPrefix) == self.tmPrefix) then text = string.sub(self.originalPlaylist[self.idxFocus].songs[n], #self.tmPrefix + 1); end
				self.SMScrollList:addItem(text, self.originalPlaylist[self.idxFocus].songs[n])
			end
		end
	end
end

function LSPlaylistMenu:onChangePlaylist(button)
	self.newCustomPlaylist[self.idxFocus].name = self.playlistNameBox:getText()
	local idx = self.idxFocus+1
	if idx > 4 then idx = 1; end
	self.idxFocus = idx
	--self.playlistNameBox.currentText = self.newCustomPlaylist[self.idxFocus].name
	self.playlistNameBox:setText(self.newCustomPlaylist[self.idxFocus].name)

	self.SMScrollList:clear()
	if self.newCustomPlaylist[self.idxFocus].pl and (#self.newCustomPlaylist[self.idxFocus].pl > 0) then		
		for n=1, #self.newCustomPlaylist[self.idxFocus].pl do
			local text = self.newCustomPlaylist[self.idxFocus].pl[n]
			if (string.sub(self.newCustomPlaylist[self.idxFocus].pl[n], 1, #self.tmPrefix) == self.tmPrefix) then text = string.sub(self.newCustomPlaylist[self.idxFocus].pl[n], #self.tmPrefix + 1); end
			self.SMScrollList:addItem(text, self.newCustomPlaylist[self.idxFocus].pl[n])
		end
	end
end
-- v joypad compat patch
function LSPlaylistMenu:isItemSelected(item)
	return self.mouseoverselected == item.index or 
		(self.selected == item.index and self.mouseoverselected == -1)
end

function LSPlaylistMenu:doDrawItemAM(y, item, alt)
	local y = ISScrollingListBox.doDrawItem(self, y, item, alt)

	if self:isItemSelected(item) then
		self.parent.selectedListTextAM = item.text
	end

	return y
end

function LSPlaylistMenu:doDrawItemSM(y, item, alt)
	local y = ISScrollingListBox.doDrawItem(self, y, item, alt)

	if self:isItemSelected(item) then
		self.parent.selectedListTextSM = item.text
	end

	return y
end
--
function LSPlaylistMenu:initialise()
	local fnt_height = getTextManager():MeasureFont(self.font);
	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer and specificPlayer:getModData().LSPlaylistMenuOverlayPanelSkin and tostring(specificPlayer:getModData().LSPlaylistMenuOverlayPanelSkin) then
		self.menuSkin = specificPlayer:getModData().LSPlaylistMenuOverlayPanelSkin
	end

	for n=1, 4 do
		if self.originalPlaylist and self.originalPlaylist[n] and self.originalPlaylist[n].songs and (#self.originalPlaylist[n].songs > 0) then
			self.newCustomPlaylist[n].pl = LSPMloadPlaylist(self.originalPlaylist[n])
		end
	end

	self.offset_x = 0
	self.offset_y = fnt_height/2

	self.LSMirrorBackgroundImage = LSPMdoImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPMBKG.png"))
	self.LSMirrorBackgroundImage:initialise()
	self:addChild(self.LSMirrorBackgroundImage)

    self.AMScrollList = ISScrollingListBox:new(146, 69, 181, 250);
	self.AMScrollList:setOnMouseDownFunction(self, self.onClickSongAM)
	self.AMScrollList:setOnMouseDoubleClick(self, self.onDoubleClickSongAM)
	self.AMScrollList.doDrawItem = LSPlaylistMenu.doDrawItemAM
	self.AMScrollList.isItemSelected = LSPlaylistMenu.isItemSelected
	self.AMScrollList:noBackground();
	self.AMScrollList.backgroundColor = {r=0, g=0, b=0, a=0};
	self.AMScrollList.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.AMScrollList.altBgColor = {r=0.2, g=0.3, b=0.2, a=0 }
	self.AMScrollList.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.AMScrollList.font = UIFont.Small
	--self.AMScrollList.itemPadY = 4
	self.AMScrollList.fontHgt = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
	self.AMScrollList.itemheight = self.AMScrollList.fontHgt + 7 * 2;
    self.AMScrollList:initialise();
    self.AMScrollList:instantiate();
   -- self.AMScrollList:addScrollBars();
    self:addChild(self.AMScrollList);

    self.SMScrollList = ISScrollingListBox:new(425, 57, 180, 250);
	self.SMScrollList:setOnMouseDownFunction(self, self.onClickSongSM)
	self.SMScrollList:setOnMouseDoubleClick(self, self.onDoubleClickSongSM)
	self.SMScrollList.doDrawItem = LSPlaylistMenu.doDrawItemSM
	self.SMScrollList.isItemSelected = LSPlaylistMenu.isItemSelected
	self.SMScrollList:noBackground();
	self.SMScrollList.backgroundColor = {r=0, g=0, b=0, a=0};
	self.SMScrollList.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.SMScrollList.altBgColor = {r=0.2, g=0.3, b=0.2, a=0 }
	self.SMScrollList.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.SMScrollList.font = UIFont.Small
	--self.SMScrollList.itemPadY = 4
	self.SMScrollList.fontHgt = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
	self.SMScrollList.itemheight = self.SMScrollList.fontHgt + 7 * 2;
    self.SMScrollList:initialise();
    self.SMScrollList:instantiate();
    --self.SMScrollList:addScrollBars();
    self:addChild(self.SMScrollList);

	if self.originalPlaylist and (#self.originalPlaylist[self.idxFocus].songs > 0) then
		for n=1, #self.originalPlaylist[self.idxFocus].songs do
			local text = self.originalPlaylist[self.idxFocus].songs[n]
			if (string.sub(self.originalPlaylist[self.idxFocus].songs[n], 1, #self.tmPrefix) == self.tmPrefix) then text = string.sub(self.originalPlaylist[self.idxFocus].songs[n], #self.tmPrefix + 1); end
			self.SMScrollList:addItem(text, self.originalPlaylist[self.idxFocus].songs[n])
		end
	end

	self.playListSelectButton = ISButton:new(30, 338, 52, 30, "", self, self.onChangePlaylist)
	self.playListSelectButton.internal = "Next"
	self.playListSelectButton:initialise()
	self.playListSelectButton:instantiate()
	self.playListSelectButton.displayBackground = false
	self.playListSelectButton.borderColor = {r=1, g=1, b=1, a=0};
	self.playListSelectButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Playlist_Select.png"))
	self.playListSelectButton:setTooltip(getText("Tooltip_LSPM_PlaylistSelect"))
	self:addChild(self.playListSelectButton)

	self.playlistNameBox = LSPMSearchBox:new(self.originalPlaylist[self.idxFocus].name, 95, 341, 150, 26)
	self.playlistNameBox.backgroundColor = {r=0, g=0, b=0, a=0}
	self.playlistNameBox.borderColor = {r=0.02, g=0.18, b=0.32, a=0}
	self.playlistNameBox.font = UIFont.Medium
    self.playlistNameBox:initialise();
    self.playlistNameBox:instantiate();
	self.playlistNameBox:setMaxTextLength(20)
    self:addChild(self.playlistNameBox);

	self.confirmChangesButton = ISButton:new(267, 343, 47, 47, "", self, self.onClick)
	self.confirmChangesButton.internal = "CloseSave"
	self.confirmChangesButton:initialise()
	self.confirmChangesButton:instantiate()
	self.confirmChangesButton.displayBackground = false
	self.confirmChangesButton.borderColor = {r=1, g=1, b=1, a=0};
	self.confirmChangesButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_Confirm.png"))
	self.confirmChangesButton:setTooltip(getText("Tooltip_LSPM_CloseSave"))
	self:addChild(self.confirmChangesButton)
	
    self.CloseButton = ISButton:new(331, 343, 47, 47, "", self, self.onClick);
    self.CloseButton.internal = "Close";
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_Cancel.png"))
	self.CloseButton:setTooltip(getText("Tooltip_LSPM_CloseNoSave"))
    self:addChild(self.CloseButton);

    self.ArrowAddButton = ISButton:new(360, 150, 44, 39, "", self, self.onClick);
    self.ArrowAddButton.internal = "AddSong";
	self.ArrowAddButton:setEnable(true)
    self.ArrowAddButton:initialise();
    self.ArrowAddButton:instantiate();
	self.ArrowAddButton.displayBackground = false
	self.ArrowAddButton.borderColor = {r=1, g=1, b=1, a=0};
	self.ArrowAddButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_ArrowAdd.png"))
	self.ArrowAddButton:setTooltip(getText("Tooltip_LSPM_AddSong"))
    self:addChild(self.ArrowAddButton);

    self.PlayMusicButton = ISButton:new(560, 35, 19, 19, "", self, self.onClick);
    self.PlayMusicButton.internal = "PlaySong";
	self.PlayMusicButton:setEnable(false)
    self.PlayMusicButton:initialise();
    self.PlayMusicButton:instantiate();
	self.PlayMusicButton.displayBackground = false
	self.PlayMusicButton.borderColor = {r=1, g=1, b=1, a=0};
	self.PlayMusicButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Music_Play.png"))
	--self.PlayMusicButton:setTooltip(getText("Tooltip_H_CloseNoSave"))
    self:addChild(self.PlayMusicButton);

    self.StopMusicButton = ISButton:new(590, 35, 19, 19, "", self, self.onClick);
    self.StopMusicButton.internal = "StopSong";
	self.StopMusicButton:setEnable(false)
    self.StopMusicButton:initialise();
    self.StopMusicButton:instantiate();
	self.StopMusicButton.displayBackground = false
	self.StopMusicButton.borderColor = {r=1, g=1, b=1, a=0};
	self.StopMusicButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Music_Stop.png"))
	--self.StopMusicButton:setTooltip(getText("Tooltip_H_CloseNoSave"))
    self:addChild(self.StopMusicButton);

    self.ResetPlaylistButton = ISButton:new(560, 311, 19, 19, "", self, self.onClearPlaylist);
    self.ResetPlaylistButton.internal = "ClearReset";
    self.ResetPlaylistButton:initialise();
    self.ResetPlaylistButton:instantiate();
	self.ResetPlaylistButton.displayBackground = false
	self.ResetPlaylistButton.borderColor = {r=1, g=1, b=1, a=0};
	self.ResetPlaylistButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_ClearReset.png"))
	self.ResetPlaylistButton:setTooltip(getText("Tooltip_LSPM_Reset"))
    self:addChild(self.ResetPlaylistButton);

    self.ClearPlaylistButton = ISButton:new(590, 311, 19, 19, "", self, self.onClearPlaylist);
    self.ClearPlaylistButton.internal = "Clear";
    self.ClearPlaylistButton:initialise();
    self.ClearPlaylistButton:instantiate();
	self.ClearPlaylistButton.displayBackground = false
	self.ClearPlaylistButton.borderColor = {r=1, g=1, b=1, a=0};
	self.ClearPlaylistButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Music_Clear.png"))
	self.ClearPlaylistButton:setTooltip(getText("Tooltip_LSPM_Clear"))
    self:addChild(self.ClearPlaylistButton);

    self.CatClassicalButton = ISButton:new(36, 50, 101, 20, getText("UI_LSPM_ClassicalCat"), self, self.onChangeCategory);
	self.CatClassicalButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatClassicalButton.internal = "Classical";
    self.CatClassicalButton:initialise();
    self.CatClassicalButton:instantiate();
	self.CatClassicalButton.displayBackground = false
	self.CatClassicalButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatClassicalButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatClassicalButton);

    self.CatCountryButton = ISButton:new(36, 70, 101, 20, getText("UI_LSPM_CountryCat"), self, self.onChangeCategory);
	self.CatCountryButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatCountryButton.internal = "Country";
    self.CatCountryButton:initialise();
    self.CatCountryButton:instantiate();
	self.CatCountryButton.displayBackground = false
	self.CatCountryButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatCountryButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatCountryButton);

    self.CatDiscoButton = ISButton:new(36, 90, 101, 20, getText("UI_LSPM_DiscoCat"), self, self.onChangeCategory);
	self.CatDiscoButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatDiscoButton.internal = "Disco";
    self.CatDiscoButton:initialise();
    self.CatDiscoButton:instantiate();
	self.CatDiscoButton.displayBackground = false
	self.CatDiscoButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatDiscoButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBS.png"))
    self:addChild(self.CatDiscoButton);

    self.CatJazzButton = ISButton:new(36, 110, 101, 20, getText("UI_LSPM_JazzCat"), self, self.onChangeCategory);
	self.CatJazzButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatJazzButton.internal = "Jazz";
    self.CatJazzButton:initialise();
    self.CatJazzButton:instantiate();
	self.CatJazzButton.displayBackground = false
	self.CatJazzButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatJazzButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatJazzButton);

    self.CatMetalButton = ISButton:new(36, 130, 101, 20, getText("UI_LSPM_MetalCat"), self, self.onChangeCategory);
	self.CatMetalButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatMetalButton.internal = "Metal";
    self.CatMetalButton:initialise();
    self.CatMetalButton:instantiate();
	self.CatMetalButton.displayBackground = false
	self.CatMetalButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatMetalButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatMetalButton);

    self.CatPopButton = ISButton:new(36, 150, 101, 20, getText("UI_LSPM_PopCat"), self, self.onChangeCategory);
	self.CatPopButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatPopButton.internal = "Pop";
    self.CatPopButton:initialise();
    self.CatPopButton:instantiate();
	self.CatPopButton.displayBackground = false
	self.CatPopButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatPopButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatPopButton);

    self.CatRapButton = ISButton:new(36, 170, 101, 20, getText("UI_LSPM_RapCat"), self, self.onChangeCategory);
	self.CatRapButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatRapButton.internal = "Rap";
    self.CatRapButton:initialise();
    self.CatRapButton:instantiate();
	self.CatRapButton.displayBackground = false
	self.CatRapButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatRapButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatRapButton);

    self.CatRBButton = ISButton:new(36, 190, 101, 20, getText("UI_LSPM_RBCat"), self, self.onChangeCategory);
	self.CatRBButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatRBButton.internal = "RB";
    self.CatRBButton:initialise();
    self.CatRBButton:instantiate();
	self.CatRBButton.displayBackground = false
	self.CatRBButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatRBButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatRBButton);

    self.CatReggaeButton = ISButton:new(36, 210, 101, 20, getText("UI_LSPM_ReggaeCat"), self, self.onChangeCategory);
	self.CatReggaeButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatReggaeButton.internal = "Reggae";
    self.CatReggaeButton:initialise();
    self.CatReggaeButton:instantiate();
	self.CatReggaeButton.displayBackground = false
	self.CatReggaeButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatReggaeButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatReggaeButton);

    self.CatRockButton = ISButton:new(36, 230, 101, 20, getText("UI_LSPM_RockCat"), self, self.onChangeCategory);
	self.CatRockButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatRockButton.internal = "Rock";
    self.CatRockButton:initialise();
    self.CatRockButton:instantiate();
	self.CatRockButton.displayBackground = false
	self.CatRockButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatRockButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatRockButton);

    self.CatSalsaButton = ISButton:new(36, 250, 101, 20, getText("UI_LSPM_SalsaCat"), self, self.onChangeCategory);
	self.CatSalsaButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatSalsaButton.internal = "Salsa";
    self.CatSalsaButton:initialise();
    self.CatSalsaButton:instantiate();
	self.CatSalsaButton.displayBackground = false
	self.CatSalsaButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatSalsaButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatSalsaButton);

    self.CatTMButton = ISButton:new(36, 270, 101, 20, getText("UI_LSPM_TMCat"), self, self.onChangeCategory);
	self.CatTMButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatTMButton.internal = "tm";
    self.CatTMButton:initialise();
    self.CatTMButton:instantiate();
	self.CatTMButton.displayBackground = false
	self.CatTMButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatTMButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
	if not LS_AMcache['truemusic'] and not GlobalMusic then
		self.CatTMButton:setEnable(false)
		self.CatTMButton:setTooltip(getText("Tooltip_LSPM_TMCat"))
	end
    self:addChild(self.CatTMButton);

    self.CatWorldButton = ISButton:new(36, 290, 101, 20, getText("UI_LSPM_WorldCat"), self, self.onChangeCategory);
	self.CatWorldButton.textColor = {r=0.02, g=0.18, b=0.32, a=1.0}
    self.CatWorldButton.internal = "World";
    self.CatWorldButton:initialise();
    self.CatWorldButton:instantiate();
	self.CatWorldButton.displayBackground = false
	self.CatWorldButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CatWorldButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_CBH.png"))
    self:addChild(self.CatWorldButton);

	self.LSMirrorFilterImage = LSPMdoImageType(202,47,19,19,getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Filter.png"))
	self.LSMirrorFilterImage:initialise()
	self:addChild(self.LSMirrorFilterImage)

	self.FilterBar = LSPMSearchBox:new("Search...", 227, 47, 100, 20)
	self.FilterBar.backgroundColor = {r=0, g=0, b=0, a=0.2}
	self.FilterBar.borderColor = {r=0.02, g=0.18, b=0.32, a=0.6}
    self.FilterBar:initialise();
    self.FilterBar:instantiate();
	self.FilterBar:setMaxTextLength(20)
    self:addChild(self.FilterBar);
	--print("LSPlaylistMenu initialised")

	-- v joypad compat patch
	self.categoryButtons = {
		self.CatClassicalButton, [self.CatClassicalButton] = true, 
		self.CatCountryButton, [self.CatCountryButton] = true,
		self.CatDiscoButton, [self.CatDiscoButton] = true,
		self.CatJazzButton, [self.CatJazzButton] = true,
		self.CatMetalButton, [self.CatMetalButton] = true,
		self.CatPopButton, [self.CatPopButton] = true,
		self.CatRapButton, [self.CatRapButton] = true,
		self.CatRBButton, [self.CatRBButton] = true,
		self.CatReggaeButton, [self.CatReggaeButton] = true,
		self.CatRockButton, [self.CatRockButton] = true,
		self.CatSalsaButton, [self.CatSalsaButton] = true,
		self.CatTMButton, [self.CatTMButton] = true,
		self.CatWorldButton, [self.CatWorldButton] = true
	}
	self.bottomButtons = {
		self.playListSelectButton, self.playlistNameBox, 
		self.ResetPlaylistButton, self.ClearPlaylistButton, -- self.playlistNameBox,
	}
end
-- v joypad compat patch
function LSPlaylistMenu:onJoypadDownInScrollingList(button, joypadData)
	self.parent:onJoypadDown(button, joypadData, self, ISScrollingListBox)
end

function LSPlaylistMenu:getJoypadFocusObject()
	local children = self:getVisibleChildren(self.joypadIndexY)

	if not children then return end

	local child = children[self.joypadIndex]

	return child
end

function LSPlaylistMenu:isJoypadFocusOnTextBox()
	local child = self:getJoypadFocusObject()

	return child == self.FilterBar or child == self.playlistNameBox
end

function LSPlaylistMenu:focusOnJoypadKeyboard()
	local playerIndex = self.character and self.character:getPlayerNum() or 0

	setJoypadFocus(playerIndex, OnScreenKeyboard.instance)
end

function LSPlaylistMenu:onJoypadDown(button, joypadData, menu, Module)
	Module = Module or ISPanelJoypad
	menu = menu or self

	if button == Joypad.BButton then
		self:onClick({ internal = "Close" })
	elseif button == Joypad.XButton then
		if self:getJoypadFocusObject() == self.SMScrollList then
			self:onDoubleClickSongSM()
		else
			self:onClick({ internal = "AddSong" })
		end
	elseif button == Joypad.Start then
		if self.isPlayingSong then
			self:onClick({ internal = "StopSong" })
		else
			self:onClick({ internal = "PlaySong" })
		end
	elseif button == Joypad.Back then
		self.FilterBar:onJoypadDown(Joypad.AButton, joypadData)
		
		self:focusOnJoypadKeyboard()
	elseif button == Joypad.YButton then
		self:onClick({ internal = "CloseSave" })
	elseif button == Joypad.AButton and self:isJoypadFocusOnTextBox() then 
		local child = self:getJoypadFocusObject()

		if not child then return end

		child:onJoypadDown(button, joypadData)

		self:focusOnJoypadKeyboard()
	else
		Module.onJoypadDown(menu, button, joypadData)
	end
end

function LSPlaylistMenu:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)

	if not self.joypadInitialized then
		self.AMScrollList.joypadParent = self
		self.SMScrollList.joypadParent = self

		self.AMScrollList.onJoypadDown = LSPlaylistMenu.onJoypadDownInScrollingList
		self.SMScrollList.onJoypadDown = LSPlaylistMenu.onJoypadDownInScrollingList

		for index = 1, #self.categoryButtons do
			local categoryButton = self.categoryButtons[index]
			self:insertNewLineOfButtons(categoryButton, self.AMScrollList, self.SMScrollList)
		end

		self:insertNewLineOfButtons(unpack(self.bottomButtons))

		self.joypadIndexY = 2
		self.joypadIndex = 1
		
		self.joypadInitialized = true
	end

	self.oldMusicCategory = nil

	self.joypadIndexY = self.joypadIndexY or 2
	self.joypadIndex = self.joypadIndex or 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true, joypadData)
end

function LSPlaylistMenu:onLoseJoypadFocus(joypadData)
	self:clearJoypadFocus(joypadData)
	ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
end
--
function LSPlaylistMenu:update()
	local currentMusicCategory = self.newMusicCategory
	local currentFilter = self.FilterBar:getText()
	local currentIdxFocus = self.idxFocus

	if (self.oldMusicCategory ~= currentMusicCategory) or (self.oldFilter ~= currentFilter) or (self.previousIdxFocus ~= currentIdxFocus) then
			--print("LSPlaylistMenu updating musicCat")
		local musicOptions = LSPMgetMusicOptions(currentMusicCategory, self.newCustomPlaylist[self.idxFocus].pl, currentFilter)
		
		self.AMScrollList:clear()
		for n=1, #musicOptions do
			local text = musicOptions[n]
			if (string.sub(musicOptions[n], 1, #self.tmPrefix) == self.tmPrefix) then text = string.sub(musicOptions[n], #self.tmPrefix + 1); end
			self.AMScrollList:addItem(text, musicOptions[n])
		end

		self.oldMusicCategory = currentMusicCategory
		self.oldFilter = currentFilter
		self.previousIdxFocus = currentIdxFocus
	end

	if self.ArrowAddButton.mouseOver and (self.ArrowAddButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_ArrowAddH.png")) then
		self.ArrowAddButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_ArrowAddH.png"))
	elseif (not self.ArrowAddButton.mouseOver) and (self.ArrowAddButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_ArrowAdd.png")) then
		self.ArrowAddButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_ArrowAdd.png"))
	end
	if self.confirmChangesButton.mouseOver and (self.confirmChangesButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_ConfirmH.png")) then
		self.confirmChangesButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_ConfirmH.png"))
	elseif (not self.confirmChangesButton.mouseOver) and (self.confirmChangesButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_Confirm.png")) then
		self.confirmChangesButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_Confirm.png"))
	end
	if self.CloseButton.mouseOver and (self.CloseButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_CancelH.png")) then
		self.CloseButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_CancelH.png"))
	elseif (not self.CloseButton.mouseOver) and (self.CloseButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_Cancel.png")) then
		self.CloseButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Circle_Cancel.png"))
	end
	if self.playListSelectButton.mouseOver and (self.playListSelectButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Playlist_SelectH.png")) then
		self.playListSelectButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Playlist_SelectH.png"))
	elseif (not self.playListSelectButton.mouseOver) and (self.playListSelectButton.image ~= getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Playlist_Select.png")) then
		self.playListSelectButton:setImage(getTexture("media/textures/LSJCPM/"..self.menuSkin.."/LSJCPM_Playlist_Select.png"))
	end
end
-- v joypad compat patch
function LSPlaylistMenu:updateJoypadSelection(newJoypadChild)
	if self.lastJoypadChild then
		self.lastJoypadChild.borderColor = self.buttonBorderColorInactive
	end

	newJoypadChild = newJoypadChild or self:getJoypadFocusObject()

	if newJoypadChild then
		newJoypadChild.borderColor = self.buttonBorderColorActive
	end

	self.lastJoypadChild = newJoypadChild
end

function LSPlaylistMenu:onJoypadDirUp(joypadData)
	ISPanelJoypad.onJoypadDirUp(self, joypadData)

	self:updateJoypadSelection()
end
function LSPlaylistMenu:onJoypadDirDown(joypadData)
	ISPanelJoypad.onJoypadDirDown(self, joypadData)

	self:updateJoypadSelection()
end

function LSPlaylistMenu:onJoypadDirLeft(joypadData)
	ISPanelJoypad.onJoypadDirLeft(self, joypadData)
	
	local child = self:getJoypadFocusObject()

	self:updateJoypadSelection(child)

	if child == self.AMScrollList or child == self.SMScrollList then return end

	setJoypadFocus(0, self)
end
function LSPlaylistMenu:onJoypadDirRight(joypadData)
	ISPanelJoypad.onJoypadDirRight(self, joypadData)

	self:updateJoypadSelection()
end
--
function LSPlaylistMenu:render()
	ISPanelJoypad.render(self);
	-- v joypad compat patch
	self.selectedListText = (self.AMScrollList:isMouseOver() and self.selectedListTextAM) or
		(self.SMScrollList:isMouseOver() and self.selectedListTextSM) or nil

	local children = self:getVisibleChildren(self.joypadIndexY)
	
	local rows = #self.joypadButtonsY
	
	-- Prevents joypad buttons from appearing until some
	-- joypad player has focused this playlist menu once.
	if rows > 0 then
		self:drawTextureScaledAspect(Joypad.Texture.Back, self.FilterBar:getX() - 60, 
			self.FilterBar:getY() - 5, 30, 30, 1, 1, 1, 1)
		self:drawTextureScaledAspect(Joypad.Texture.Start, self.PlayMusicButton:getX() - 40, 
			self.PlayMusicButton:getY() - 5, 30, 30, 1, 1, 1, 1)
		self:drawTextureScaledAspect(Joypad.Texture.XButton, self.ArrowAddButton:getX() + 
			(self.ArrowAddButton:getWidth() / 2) - 10, self.ArrowAddButton:getY() + 49, 20, 20, 1, 1, 1, 1)
		self:drawTextureScaledAspect(Joypad.Texture.YButton, 
			self.confirmChangesButton:getX() - 10, self.confirmChangesButton:getY() - 10, 20, 20, 1, 1, 1, 1)
		self:drawTextureScaledAspect(Joypad.Texture.BButton, 
			self.CloseButton:getX() - 10, self.CloseButton:getY() - 10, 20, 20, 1, 1, 1, 1)

		self.selectedListText = ((children[self.joypadIndex] == self.AMScrollList) and self.selectedListTextAM) or
			((children[self.joypadIndex] == self.SMScrollList) and self.selectedListTextSM) or nil
	end

	if self.selectedListText then
		local textHeight = getTextManager():MeasureStringY(UIFont.Medium, self.selectedListText)
		local textWidth = getTextManager():MeasureStringX(UIFont.Medium, self.selectedListText)
		local boxHeight = textHeight + 10
		local boxWidth = textWidth + 20
		local x = (self:getWidth() - boxWidth) / 2
		self:drawRect(x, 0 - boxHeight, boxWidth, boxHeight, 0.9, 0, 0, 0)
		self:drawText(self.selectedListText, x + 10, 5 - boxHeight, 0.9, 0.9, 0.9, 0.9, UIFont.Medium)		
	end
end

function LSPlaylistMenu:close()
	if self.isPlayingSong then getSoundManager():stopUISound(self.isPlayingSong); end
	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer:getModData().LSPlaylistMenuOverlayPanel ~= "changeSkin" then
		specificPlayer:getModData().LSPlaylistMenuOverlayPanel = false
	end
	self.AMScrollList:clear()
	self.SMScrollList:clear()
	self:setVisible(false);
	self:removeFromUIManager();
	-- v joypad compat patch
	setJoypadFocus(specificPlayer:getPlayerNum(), nil)
end

function LSPlaylistMenu:destroy()
	if self.isPlayingSong then getSoundManager():stopUISound(self.isPlayingSong); end
	local specificPlayer = getSpecificPlayer(0)
	specificPlayer:getModData().LSPlaylistMenuOverlayPanel = false
	self.AMScrollList:clear()
	self.SMScrollList:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSPlaylistMenu:OnKeyPressed(key)
	local LSPMInstance = LSPlaylistMenu.instance
	if not LSPMInstance then return; end
	if key == 1 then
		self:destroy()
	end
end

Events.OnKeyPressed.Add(LSPlaylistMenu.OnKeyPressed);

LSPlaylistMenu.instance = {}

function LSPlaylistMenu:new(X, Y, Width, Height, Player, CustomPlaylist)
	local o = ISPanelJoypad:new(X, Y, Width, Height)
	setmetatable(o, self)
	self.__index = self
	local playerObj = Player and getSpecificPlayer(Player) or nil
    o.character = playerObj
	o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.98}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.idxFocus = 1
	o.previousIdxFocus = 1
	o.originalPlaylist = CustomPlaylist
	o:noBackground()
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.panelH = Height
	o.panelW = Width
	o.menuSkin = "LSSims"
	o.oldMusicCategory = "none"
	o.newMusicCategory = "Disco"
	o.isPlayingSong = false
	o.selectedSong = false
	o.selectedSongToAdd = false
	o.selectedSongToRemove = false
	o.newCustomPlaylist = {{name=CustomPlaylist[1].name,pl={}},{name=CustomPlaylist[2].name,pl={}},{name=CustomPlaylist[3].name,pl={}},{name=CustomPlaylist[4].name,pl={}}}
	o.tmPrefix = "Cassette"
	o.oldFilter = "Search..."
	o.buttonBorderColorInactive = { r = 1, g = 1, b = 1, a = 0 }
	o.buttonBorderColorActive = { r = 0.5, g = 1, b = 0.5, a = 0.9 }
	LSPlaylistMenu.instance[Player] = o
	return o
end





