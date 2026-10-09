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
-- DEPRECATED
--[[
require "ISUI/ISPanelJoypad"

LSAmbtBrushmasterNote = ISPanelJoypad:derive("LSAmbtBrushmasterNote");

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

local function cleanString(name)
	local cleanedString = name:gsub("[%(%)]", "")
	local capitalizedString = cleanedString:gsub("^%l", string.upper)
	return capitalizedString
end

local function getTextRGB(quality)
	if quality == "Bad" then return " <RGB:1,0.7,0.7>"; end
	if quality == "Neutral" then return " <RGB:0.7,0.7,1>"; end
	return " <RGB:0.7,1,0.7>"
end

function LSAmbtBrushmasterNote:initialise()

	getSoundManager():playUISound("UI_Note_Appear")
	local qualityText = cleanString(getText(self.qualityName))
	local qualityRGB = getTextRGB(self.qualityType)

	self.Header = doRichTextType(40, 5, self:getWidth()-62, 40,getText("IGUI_LSAmbitions_LSBrushmaster_Appraise").." <LINE>".."<CENTRE> "..qualityRGB..qualityText.." !",UIFont.NewSmall)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

    self.ok = ISButton:new((self:getWidth())-18, 0, 18, self:getHeight(), ">", self, self.destroy);
    self.ok.internal = "Close";
	self.ok.font = UIFont.Medium
    self.ok:initialise();
    self.ok:instantiate();
	self.ok.backgroundColor = {r=0, g=0.35, b=0.42, a=0.7};
	self.ok.backgroundColorMouseOver = {r=0, g=0.45, b=0.52, a=0.7};
    self.ok.borderColor = {r=1, g=1, b=1, a=0.7};
    self:addChild(self.ok);

    --self:insertNewLineOfButtons(self.button1p, self.button2p, self.button3p, self.button4p)
    self:insertNewLineOfButtons(self.ok)

end

function LSAmbtBrushmasterNote:close()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSAmbtBrushmasterNote:destroy(btn)
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSAmbtBrushmasterNote:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRect(6, 6, 30, self.height-12, 0.4, 0.89, 0.98, 1);
	--self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
end

function LSAmbtBrushmasterNote:render()
	local texture = getTexture(self.paintingTex)
	if texture then self:drawTextureScaledAspect(texture, -10, -6, 64, 64, 1, 1, 1, 1); end
end

function LSAmbtBrushmasterNote:update()
	self.seconds = self.seconds+getGameTime():getRealworldSecondsSinceLastUpdate()
	if self.seconds > 5 then self:destroy(); end
	ISPanelJoypad.update(self)
end

function LSAmbtBrushmasterNote:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function LSAmbtBrushmasterNote:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:destroy(self.ok)
	end
end

function LSAmbtBrushmasterNote:new(x, y, w, h, Player, Guess, Type, Texture)
	local o = {}
	o = ISPanelJoypad:new(x, y, w, h)
	setmetatable(o, self)
    self.__index = self
    o.character = Player
	o.qualityName = Guess
	o.qualityType = Type
	o.paintingTex = Texture
	o.name = nil
    o.backgroundColor = {r=0, g=0.55, b=0.7, a=0.7}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	o.width = w
	o.height = h
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	o.seconds = 0
	--o:noBackground()
    --o.new = new;
    return o;
end
]]--