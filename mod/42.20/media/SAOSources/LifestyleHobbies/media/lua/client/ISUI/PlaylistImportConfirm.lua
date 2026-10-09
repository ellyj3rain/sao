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


require "ISUI/ISPanelJoypad"

PlaylistImportConfirm = ISPanelJoypad:derive("PlaylistImportConfirm");

function PlaylistImportConfirm:initialise()
	ISPanel.initialise(self);
	local specificPlayer = getSpecificPlayer(0)
	local measureString = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_PlaylistText"))
------- TEXT BOX

    self.textlabel = ISLabel:new((measureString+(self:getWidth()/2))-measureString/2, self:getHeight() - 240, 50, getText("UI_PlaylistText"), 1, 1, 1, 1, UIFont.Medium, false);
    self.textlabel:initialise();
    self.textlabel:instantiate();
    self.textlabel.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabel);

	measureString = getTextManager():MeasureStringX(UIFont.Medium, specificPlayer:getModData().LSJukeboxCustomPlaylist[self.idx].name)
    self.textlabelPlaylist = ISLabel:new(measureString+((self:getWidth()-measureString)/2), self:getHeight() - 210, 50, specificPlayer:getModData().LSJukeboxCustomPlaylist[self.idx].name, 1, 1, 0, 1, UIFont.Medium, false)
	--self.textlabelPlaylist.center = true
    self.textlabelPlaylist:initialise();
    self.textlabelPlaylist:instantiate();
    self.textlabelPlaylist.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabelPlaylist);

	measureString = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_PlaylistText2"))
    self.textlabel2 = ISLabel:new(measureString+((self:getWidth()-measureString)/2), self:getHeight() - 180, 50, getText("UI_PlaylistText2"), 1, 1, 1, 1, UIFont.Medium, false);
    self.textlabel2:initialise();
    self.textlabel2:instantiate();
    self.textlabel2.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabel2);
	
	measureString = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_WardrobeText3"))
    self.textlabel3 = ISLabel:new(measureString+((self:getWidth()-measureString)/2), self:getHeight() - 150, 50, getText("UI_WardrobeText3"), 1, 1, 1, 1, UIFont.Medium, false);
    self.textlabel3:initialise();
    self.textlabel3:instantiate();
    self.textlabel3.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabel3);

------- REGULAR BUTTONS

    self.confirm = ISButton:new((self:getWidth() / 2) - 105, self:getHeight() - 90, 90, 65, getText("UI_Confirm"), self, PlaylistImportConfirm.onClick);
    self.confirm.internal = "Confirm";
	self.confirm.font = UIFont.Medium
    self.confirm:initialise();
    self.confirm:instantiate();
    self.confirm.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.confirm);

    --
    self.ok = ISButton:new((self:getWidth() / 2) + 20, self:getHeight() - 90, 90, 65, getText("UI_Cancel"), self, PlaylistImportConfirm.onClick);
    self.ok.internal = "Close";
	self.ok.font = UIFont.Medium
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    --self:insertNewLineOfButtons(self.button1p, self.button2p, self.button3p, self.button4p)
    self:insertNewLineOfButtons(self.ok)
	

end

function PlaylistImportConfirm:destroy()
	if self.IsConfirm then
		local specificPlayer = getSpecificPlayer(0)
		HaloTextHelper.addGoodText(specificPlayer, getText("IGUI_HaloNote_PlaylistGet"))
		HaloTextHelper.addGoodText(specificPlayer, #specificPlayer:getModData().LSJukeboxCustomPlaylist[self.idx].songs..getText("IGUI_HaloNote_PlaylistGetEnd"))
	end
	--self:setVisible(false);
	self:removeFromUIManager();
	if UIManager.getSpeedControls() then
		UIManager.getSpeedControls():SetCurrentGameSpeed(1);
	end

end

function PlaylistImportConfirm:onClick(button)
    if button.internal == "Close" then
        self:destroy();
        if JoypadState.players[self.player+1] then
            setJoypadFocus(self.player, nil)
        end
	end
	if button.internal == "Confirm" then
		local specificPlayer = getSpecificPlayer(0)
		self.IsConfirm = true
		specificPlayer:getModData().LSJukeboxCustomPlaylist[self.idx].songs = self.newPlaylist
        self:destroy();
        if JoypadState.players[self.player+1] then
            setJoypadFocus(self.player, nil)
        end
	end
end

function PlaylistImportConfirm:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function PlaylistImportConfirm:render()

end

function PlaylistImportConfirm:update()
    ISPanelJoypad.update(self)
  
end

function PlaylistImportConfirm:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function PlaylistImportConfirm:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:onClick(self.ok)
	end
end

function PlaylistImportConfirm:new(thisplayer, Playlist, IDX)
	local x = 0
	local y = 0
	local width = 320
	local height = 260
	local o = {}
	o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
    self.__index = self
	local playerObj = thisplayer and getSpecificPlayer(thisplayer) or nil
    o.character = playerObj;
	o.name = nil;
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    if y == 0 then
		o.y = getPlayerScreenTop(thisplayer) + (getPlayerScreenHeight(thisplayer) - height) / 2
        o:setY(o.y)
    end
    if x == 0 then
		o.x = getPlayerScreenLeft(thisplayer) + (getPlayerScreenWidth(thisplayer) - width) / 2
        o:setX(o.x)
    end
	o.width = width;
	o.height = height;
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.newPlaylist = Playlist
	o.idx = IDX
	o.target = target;
	o.onclick = onclick;
    o.player = thisplayer;
    o.playerX = getPlayer():getX()
    o.playerY = getPlayer():getY()
	o:noBackground()
	o.IsConfirm = false
    o.new = new;
    return o;
end
