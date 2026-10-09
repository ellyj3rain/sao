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

require "ISUI/NoteMng"
require "ISUI/ISPanelJoypad"

LSWarn = ISPanelJoypad:derive("LSWarn");

local function doRichTextType(x,y,w,h,customText,font,autoH)
	local newRichText = ISRichTextPanel:new(x, y, w, h)
	newRichText.backgroundColor = {r=0, g=0, b=0, a=0}
	newRichText.text = customText
	newRichText.defaultFont = font
	newRichText.autosetheight = autoH
	newRichText.marginLeft = 0
	newRichText.marginTop = 0
	newRichText.marginRight = 0
	newRichText.marginBottom = 0
	return newRichText
end

local function doImageType(x,y,w,h,texture)
	local newImage = ISImage:new(x, y, w, h, texture)
	return newImage
end

function LSWarn:initialise()

	--self.UIDark = doImageType(-self.panelX,-self.panelY,self.screenW,self.screenH,getTexture("media/textures/LS/UI_Dark.png"))
	--self.UIDark:initialise()
	--self:addChild(self.UIDark)
	self.UIDark = ISPanel:new(-self.panelX,-self.panelY,self.screenW,self.screenH)
	self.UIDark:initialise()
	self.UIDark.backgroundColor = {r=0, g=0, b=0, a=0.5}
	self.UIDark.borderColor = {r=0, g=0, b=0, a=0.5}
	self:addChild(self.UIDark)

	self.BackgroundImage = doImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LS/"..self.menuSkin.."/MSG_BKG.png"))
	self.BackgroundImage.autoScale = true
	self.BackgroundImage:initialise()
	self:addChild(self.BackgroundImage)

	self.headerText = doRichTextType(12, 12, self.textBoxW, self.titleBoxH, "<RGB:0.15,0.35,0.89>"..self.title, UIFont.Large,true)
    self.headerText.clip = true
	self.headerText:initialise()
	self.headerText:instantiate()
	self:addChild(self.headerText)
	self.headerText:paginate()

	self.richText = doRichTextType(12, 18+self.titleBoxH, self.textBoxW, self.textBoxH, "<RGB:0.25,0.45,0.92>"..self.text, self.font,true)
    self.richText.clip = true
	self.richText:initialise()
	self.richText:instantiate()
	self:addChild(self.richText)
	self.richText:paginate()

	local bottomMargin = math.floor(self.height*0.015)
    self.ok = ISButton:new((self.width/2)-64, self.height-(56+bottomMargin), 128, 56, "OK", self, self.destroy);
    self.ok.internal = "Close";
	self.ok.font = self.font
    self.ok:initialise();
    self.ok:instantiate();
	self.ok.textColor = {r=0.25, g=0.45, b=0.92, a=1.0}
	self.ok.backgroundColor = {r=0, g=0.35, b=0.42, a=0};
	self.ok.backgroundColorMouseOver = {r=0, g=0.45, b=0.52, a=0};
    self.ok.borderColor = {r=1, g=1, b=1, a=0};
    self:addChild(self.ok);

    self:insertNewLineOfButtons(self.ok)

	getSoundManager():playUISound(self.soundName)
end

function LSWarn:close()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSWarn:destroy(btn)
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSWarn:prerender()

end

function LSWarn:render()

end

function LSWarn:update()
	if self.character and (self.character:isWalking() or self.character:IsRunning()) then
		if self.closeCount > 10 then
			self:close()
			return
		end
		self.closeCount = self.closeCount+1
	end
	if self.ok.mouseOver and not self.ok.isHighlighted then
		self.ok.isHighlighted = true
		self.ok.textColor = {r=0.45, g=0.65, b=1.0, a=1.0}
	elseif not self.ok.mouseOver and self.ok.isHighlighted then
		self.ok.isHighlighted = false
		self.ok.textColor = {r=0.25, g=0.45, b=0.92, a=1.0}
	end
	ISPanelJoypad.update(self)
end

function LSWarn:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function LSWarn:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:destroy(self.ok)
	end
end

function LSWarn:new(character, modW, modH, title, text, soundName)
	local addW, addH = modW or 0, modH or 0
	local w, h = 300+addW, 260+addH
	local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
	local font = UIFont.Medium
	local headerH = getTextManager():MeasureStringY(UIFont.Large, title)
	local textH = getTextManager():MeasureStringY(font, text)
	local textW = getTextManager():MeasureStringX(font, text)
	
	local textBoxW = 276+addW
	if textW > textBoxW then
		local multi = math.ceil(textW/textBoxW)
		textH = textH*multi
	end
	local textBoxH = (192+addH)-(headerH)
	if textH > textBoxH then
		h = h+(textBoxH-textH)
		textBoxH = textH
	end
	local x = (screenW-w)/2
	local y = (screenH-h)/2

	local o = {}
	o = ISPanelJoypad:new(x, y, w, h)
	setmetatable(o, self)
    self.__index = self
	o.name = nil
	o.character = character
	o.closeCount = 0
    o.backgroundColor = {r=0, g=0.55, b=0.7, a=0}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	o.width = w
	o.height = h
	o.panelX = x
	o.panelY = y
	o.screenW = screenW
	o.screenH = screenH
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	o.textBoxW = textBoxW
	o.textBoxH = textBoxH
	o.titleBoxH = headerH
	o.title = title
	o.text = text
	o.font = font
	o.menuSkin = "LSSims"
	o.soundName = soundName or "UI_Note_Appear"
    return o;
end