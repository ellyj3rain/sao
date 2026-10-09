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

WardrobeConfirm = ISPanelJoypad:derive("WardrobeConfirm");

function WardrobeConfirm:initialise()
	ISPanel.initialise(self);
	--local specificPlayer = getSpecificPlayer(0)
	local measureString = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_WardrobeText"))

------- TEXT BOX

    self.textlabel = ISLabel:new(measureString+((self:getWidth()-measureString)/2), self:getHeight() - 240, 50, getText("UI_WardrobeText"), 1, 1, 1, 1, UIFont.Medium, false);
    self.textlabel:initialise();
    self.textlabel:instantiate();
    self.textlabel.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabel);

	measureString = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_WardrobeText2"))
    self.textlabel2 = ISLabel:new(measureString+((self:getWidth()-measureString)/2), self:getHeight() - 210, 50, getText("UI_WardrobeText2"), 1, 1, 1, 1, UIFont.Medium, false);
    self.textlabel2:initialise();
    self.textlabel2:instantiate();
    self.textlabel2.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabel2);
	
	measureString = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_WardrobeText3"))
    self.textlabel3 = ISLabel:new(measureString+((self:getWidth()-measureString)/2), self:getHeight() - 180, 50, getText("UI_WardrobeText3"), 1, 1, 1, 1, UIFont.Medium, false);
    self.textlabel3:initialise();
    self.textlabel3:instantiate();
    self.textlabel3.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.textlabel3);

------- REGULAR BUTTONS

    self.confirm = ISButton:new((self:getWidth() / 2) - 105, self:getHeight() - 90, 90, 65, getText("UI_Confirm"), self, WardrobeConfirm.onClick);
    self.confirm.internal = "Confirm";
    self.confirm:initialise();
    self.confirm:instantiate();
    self.confirm.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.confirm);

    --
    self.ok = ISButton:new((self:getWidth() / 2) + 20, self:getHeight() - 90, 90, 65, getText("UI_Cancel"), self, WardrobeConfirm.onClick);
    self.ok.internal = "Close";
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    --self:insertNewLineOfButtons(self.button1p, self.button2p, self.button3p, self.button4p)
    self:insertNewLineOfButtons(self.ok)
	

end

function WardrobeConfirm:updateStatus()

 	--local specificPlayer = getSpecificPlayer(0)


end


function WardrobeConfirm:destroy()
	--local specificPlayer = getSpecificPlayer(0)
	--specificPlayer:getModData().DJBoothBigButtonRGB = 0

	UIManager.setShowPausedMessage(true);
	--self:setVisible(false);
	self:removeFromUIManager();
	if UIManager.getSpeedControls() then
		UIManager.getSpeedControls():SetCurrentGameSpeed(1);
	end

end



function WardrobeConfirm:onClick(button)
    if button.internal == "Close" then
        self:destroy();
        if JoypadState.players[self.player+1] then
            setJoypadFocus(self.player, nil)
        end
	end
	if button.internal == "Confirm" then
		LSWardrobeContextMenu.setClothes(self.character, self.optionName)	
        self:destroy();
        if JoypadState.players[self.player+1] then
            setJoypadFocus(self.player, nil)
        end
    end
end

function WardrobeConfirm:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function WardrobeConfirm:render()

end

function WardrobeConfirm:update()
    ISPanelJoypad.update(self)
  
end

function WardrobeConfirm:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function WardrobeConfirm:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:onClick(self.ok)
	end
end

function WardrobeConfirm:new(character, playerNum, optionName)
	local x = 0
	local y = 0
	local width = 320
	local height = 260
	local o = {}
	o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
    self.__index = self
	o.name = nil;
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    if y == 0 then
		o.y = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - height) / 2
        o:setY(o.y)
    end
    if x == 0 then
		o.x = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - width) / 2
        o:setX(o.x)
    end
	o.width = width;
	o.height = height;
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.target = target;
	o.onclick = onclick;
	o.character = character
    o.player = playerNum;
	o.optionName = optionName
    o.playerX = getPlayer():getX()
    o.playerY = getPlayer():getY()
	o:noBackground()
	o.confirm = 0
    o.new = new;
    return o;
end
