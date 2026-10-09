
LSInvForgetPanel = ISPanel:derive("LSInvForgetPanel");

local function doImageType(x,y,w,h,texture)
	local newImage = ISImage:new(x, y, w, h, texture)
	return newImage
end

local function doRichTextType(x,y,w,h,customText,font,r,g,b)
	local newRichText = ISRichTextPanel:new(x, y, w, h)
	newRichText.backgroundColor = {r=0, g=0, b=0, a=0}
	newRichText.text = customText
	newRichText.defaultFont = font
	
	newRichText.autosetheight = false
	newRichText.marginLeft = 0
	newRichText.marginTop = 0
	newRichText.marginRight = 0

	newRichText.textR = r
	newRichText.textG = g
	newRichText.textB = b
	return newRichText
end

function LSInvForgetPanel:initialise()
    ISPanel.initialise(self);
    local btnWid = 29
    local btnHgt = 29
    local padBottom = 10
	local panelWidth = 237
	local panelHeight = 260
	getSoundManager():playUISound("UI_Note_Appear")
	
	self.PanelImage = doImageType(self.panelX,self.panelY,panelWidth,panelHeight,getTexture("media/textures/LSRSM/"..self.menuSkin.."/InvPanel.png"))
	self.PanelImage:initialise()
	self:addChild(self.PanelImage)

	local ConfBtnInt = "CONFIRM"

	local mediumNewTextHeight = getTextManager():getFontFromEnum(UIFont.MediumNew):getLineHeight()
	self.infoText = doRichTextType(self.panelX+21, self.panelY+21, 195, 198,"<RGB:0.2,0.3,0.47>"..getText("IGUI_Inventions_Abandon"),UIFont.MediumNew)
	self.infoText.maxLines = math.floor(198 / mediumNewTextHeight)
	self.infoText:initialise()
	self.infoText:instantiate()
	self.infoText:paginate();
	self:addChild(self.infoText)

    self.ConfirmButton = ISButton:new(self.panelX+152, self.panelY+225, btnWid, btnHgt, "", self, LSInvForgetPanel.onClick)
    self.ConfirmButton.internal = ConfBtnInt;
    self.ConfirmButton:initialise();
    self.ConfirmButton:instantiate();
	self.ConfirmButton.displayBackground = false
	self.ConfirmButton.borderColor = {r=1, g=1, b=1, a=0};
	self.ConfirmButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm.png"))
    self:addChild(self.ConfirmButton);

    self.CloseButton = ISButton:new(self.panelX+56, self.panelY+225, btnWid, btnHgt, "", self, LSInvForgetPanel.onClick)
    self.CloseButton.internal = "CANCEL";
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png"))
    self:addChild(self.CloseButton);

end

function LSInvForgetPanel:prerender()
	--[[
    local z = 20;
    local splitPoint = 100;
    local x = 10;
    self:drawRect(self.panelX, self.panelY, 400, 350, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
    self:drawRectBorder(self.panelX, self.panelY, 400, 350, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
	self:drawText(getText("IGUI_LSAmbitions_"..self.ambt.name), self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, getText("IGUI_LSAmbitions_"..self.ambt.name)) / 2), self.panelY+z, 1,1,1,1, UIFont.Medium);
	z = z+30
	self:drawText(getText(self.activeText), self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, getText(self.activeText)) / 2), self.panelY+z, 1,1,1,1, UIFont.Medium);
	]]--
end

function LSInvForgetPanel:close()
	if self.parent then self.parent.invPanel = false; end
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSInvForgetPanel:destroy()
	if self.parent then self.parent.invPanel = false; end
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSInvForgetPanel:onClick(button)
	if button.internal == "CONFIRM" and self.params then
		self.parent.onBeginInventOption(false, self.params)   
    end
	self:close()
end

local function isValidInteraction(obj, character)
	return LSUtil.isValidObj(obj, "Inv Workbench") and not LSUtil.isCharBusy(character)
end

function LSInvForgetPanel:update()
	self:bringToTop()
	if not self.parent then
        self:setVisible(false)
        self:removeFromUIManager()
		return
	elseif self.character and (self.character:isWalking() or self.character:IsRunning()) then
		if self.closeCount > 10 then
			self:close()
			return
		end
		self.closeCount = self.closeCount+1
	end
	self.sanity=self.sanity+1
	if self.sanity%100==0 then
		if not isValidInteraction(self.workbench, self.character) then
			self:close()
			return
		end
	end
	if self.CloseButton.mouseOver and (self.CloseButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close_On.png")) then self.CloseButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close_On.png"));
	elseif (not self.CloseButton.mouseOver) and (self.CloseButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png")) then self.CloseButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png")); end
	if self.ConfirmButton.mouseOver and (self.ConfirmButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm_On.png")) then self.ConfirmButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm_On.png"));
	elseif (not self.ConfirmButton.mouseOver) and (self.ConfirmButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm.png")) then self.ConfirmButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm.png")); end
end

function LSInvForgetPanel:new(panel, character, workbench, workParams)
	local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
	local width, height = 237,260
	local x = (screenW-width)/2
	local y = (screenH-height)/2
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
    o.backgroundColor = {r=0, g=0, b=0, a=0}
	o.parent = panel
	o.character = character
	o.workbench = workbench
    o.width = width
    o.height = height
	o.params = {}
	o.params.character = character
	o.params.workbench = workbench
	o.params.workParams = workParams
	o.menuSkin = "LSSims"
	local pX, pY = 14, 50
	--if params then pX, pY = (width/2)-119, (height/2)-130; end
	o.panelX = 0
	o.panelY = 0
	o.closeCount = 0
	o.sanity = 0
	return o
end
