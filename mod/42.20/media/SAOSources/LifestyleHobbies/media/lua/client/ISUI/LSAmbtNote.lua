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

LSAmbtNote = ISPanelJoypad:derive("LSAmbtNote");

local function doRichTextType(x,y,w,h,customText,font,r,g,b)
	local newRichText = ISRichTextPanel:new(x, y, w, h)
	newRichText.backgroundColor = {r=0, g=0, b=0, a=0}
	newRichText.text = customText
	newRichText.defaultFont = font
	newRichText.autosetheight = false
	newRichText.marginLeft = 0
	newRichText.marginTop = 0
	newRichText.marginRight = 0
	newRichText.marginBottom = 0
	newRichText.textR = r
	newRichText.textG = g
	newRichText.textB = b
	return newRichText
end

local function doImageType(x,y,w,h,texture)
	local newImage = ISImage:new(x, y, w, h, texture)
	return newImage
end

function LSAmbtNote:initialise()

    self.lightEffect = ISButton:new(-30, -30, 128, 128, "", self, self.onClick);
    self.lightEffect.internal = "light";
    self.lightEffect:initialise();
    self.lightEffect:instantiate();
	self.lightEffect.displayBackground = false
	self.lightEffect.borderColor = {r=1, g=1, b=1, a=0};
	self.lightEffect:setImage(getTexture("media/textures/LSMisc/Sparkle"..self.imgIdx..".png"))
    self:addChild(self.lightEffect);

	self.BackgroundImage = doImageType(2,2,64,64,getTexture("media/ui/Ambitions/"..self.ambt.texture..".png"))
	self.BackgroundImage:initialise()
	self:addChild(self.BackgroundImage)

	local icon, rgb, text = "ambt_completed_icon.png", " <RGB:0.7,1,0.7>", "IGUI_LSAmbitions_Text_Completed"
	if self.isUnlock then icon, rgb, text = "ambt_unlock_icon.png", " <RGB:0.7,0.7,1>", "IGUI_LSAmbitions_Text_Unlocked"; end

	self.iconImage = doImageType(self:getWidth()-16,self:getHeight()-16,32,32,getTexture("media/ui/"..icon))
	self.iconImage:initialise()
	self:addChild(self.iconImage)

	self.Header = doRichTextType(70, 11, 290, 44,"<H1> "..getText("IGUI_LSAmbitions_"..self.ambt.name).." <LINE>"..rgb..getText("IGUI_LSAmbitions_Text_Ambition").." <SPACE>"..getText(text),UIFont.Large)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

    self.ok = ISButton:new((self:getWidth())-20, 2, 18, 18, "X", self, self.destroy);
    self.ok.internal = "Close";
	self.ok.font = UIFont.Medium
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    --self:insertNewLineOfButtons(self.button1p, self.button2p, self.button3p, self.button4p)
    self:insertNewLineOfButtons(self.ok)

end

function LSAmbtNote:onClick()

end

function LSAmbtNote:close()
	self:setVisible(false);
	self:removeFromUIManager();
	LSAmbtMng.NotePanel = nil
end

function LSAmbtNote:destroy(btn)
	self:setVisible(false);
	self:removeFromUIManager();
	LSAmbtMng.NotePanel = nil
end

function LSAmbtNote:prerender()
	if self.lightTrick then self.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7}; else self.backgroundColor = {r=0.25, g=0.25, b=0.25, a=0.7}; end
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
end

function LSAmbtNote:render()

end

function LSAmbtNote:update()
	self.seconds = self.seconds+getGameTime():getRealworldSecondsSinceLastUpdate()
	self.imgIdx = self.imgIdx+1
	if self.imgIdx % 5 == 0 then if self.lightTrick == true then self.lightTrick = false; else self.lightTrick = true; end; end
	if self.imgIdx > 21 then self.imgIdx = 0; end
	self.lightEffect:setImage(getTexture("media/textures/LSMisc/Sparkle"..self.imgIdx..".png"))
	if self.seconds > 5 then self:destroy(); end
	ISPanelJoypad.update(self)
end

function LSAmbtNote:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function LSAmbtNote:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:destroy(self.ok)
	end
end

function LSAmbtNote:new(x, y, w, h, Player, Ambt, Unlock)
	local o = {}
	o = ISPanelJoypad:new(x, y, w, h)
	setmetatable(o, self)
    self.__index = self
    o.character = Player
	o.ambt = Ambt
	o.isUnlock = Unlock
	o.name = nil
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
	o.width = w
	o.height = h
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
    o.playerNum = Player:getPlayerNum()
	o.lightTrick = true
	o.seconds = 0
	o.imgIdx = 0
	--o:noBackground()
    --o.new = new;
    return o;
end
