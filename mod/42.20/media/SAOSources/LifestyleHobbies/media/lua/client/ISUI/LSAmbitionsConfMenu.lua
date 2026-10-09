
LSAmbitionsConfMenu = ISPanel:derive("LSAmbitionsConfMenu");

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

--************************************************************************--
--** LSAmbitionsConfMenu:initialise
--**
--************************************************************************--

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
	newRichText.marginBottom = 0
	newRichText.textR = r
	newRichText.textG = g
	newRichText.textB = b
	return newRichText
end

function LSAmbitionsConfMenu:initialise()
    ISPanel.initialise(self);
    local btnWid = 29
    local btnHgt = 29
    local padBottom = 10
	local panelWidth = 400
	local panelHeight = 350
	getSoundManager():playUISound("UI_Note_Appear")
	
	self.BackgroundImage = doImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LSABTM/"..self.menuSkin.."/FOGBKG.png"))
	self.BackgroundImage:initialise()
	self:addChild(self.BackgroundImage)

	self.PanelImage = doImageType(self.panelX,self.panelY,400,350,getTexture("media/textures/LSABTM/"..self.menuSkin.."/ConfPanel.png"))
	self.PanelImage:initialise()
	self:addChild(self.PanelImage)

	self.textTitle = doRichTextType(self.panelX+30,self.panelY+15, 340, 32,"<RGB:0,0.38,1>".." <CENTRE>"..getText("IGUI_LSAmbitions_"..self.ambt.name),UIFont.Large)
	self.textTitle:initialise()
	self.textTitle:instantiate()
	self.textTitle:paginate();
	self:addChild(self.textTitle)

	self.textSubtitle = doRichTextType(self.panelX+30,self.panelY+50, 340, 22,"<RGB:0.9,0.8,0.34>".." <CENTRE>"..getText("IGUI_LSAmbitions_Confirm_Goals"),UIFont.MediumNew)
	self.textSubtitle:initialise()
	self.textSubtitle:instantiate()
	self.textSubtitle:paginate();
	self:addChild(self.textSubtitle)

	local z = 70
	for n=1, 6 do
		local value = self.ambt['goal'..n]
		if value and (type(value) == "number") and (value > 0) then
			local currentProgress = self.ambt['goal'..n..'progress'] or 0
			self["textGoal"..tostring(n)] = doRichTextType(self.panelX+60,self.panelY+z, 280, 22,"<RGB:0,0.38,1>".." <CENTRE>"..getText(currentProgress.." <SPACE>"..getText("IGUI_LSAmbitions_GoalMiddle").." <SPACE>"..value.." <SPACE>"..getText("IGUI_LSAmbitions_"..self.ambt.name.."_unit"..n)),UIFont.MediumNew)
			self["textGoal"..tostring(n)]:initialise()
			self["textGoal"..tostring(n)]:instantiate()
			self["textGoal"..tostring(n)]:paginate();
			self:addChild(self["textGoal"..tostring(n)])
			z = z+30
		elseif value and (type(value) == "string") and (value ~= " ") then
			self["textGoal"..tostring(n)] = doRichTextType(self.panelX+60,self.panelY+z, 280, 22,"<RGB:0,0.38,1>".." <CENTRE>"..getText("IGUI_LSAmbitions_"..self.ambt.name.."_goal"..n),UIFont.MediumNew)
			self["textGoal"..tostring(n)]:initialise()
			self["textGoal"..tostring(n)]:instantiate()
			self["textGoal"..tostring(n)]:paginate();
			self:addChild(self["textGoal"..tostring(n)])
			z = z+30
		end
	end

	self.textBottom = doRichTextType(self.panelX+30,self.panelY+249, 340, 32,"<RGB:0,0.38,1>".." <CENTRE>"..getText(self.activeText),UIFont.Large)
	self.textBottom:initialise()
	self.textBottom:instantiate()
	self.textBottom:paginate();
	self:addChild(self.textBottom)

	self.textBottomSub = doRichTextType(self.panelX+30,self.panelY+275, 340, 22,"<RGB:0,0.38,1>".." <CENTRE>"..getText("IGUI_LSAmbitions_Confirm_Warning").." <SPACE>".." <RGB:0.9,0.8,0.34>"..tostring(self.cooldownTime).." <SPACE>".."<RGB:0,0.38,1>"..getText("IGUI_Gametime_hours"),UIFont.MediumNew)
	self.textBottomSub:initialise()
	self.textBottomSub:instantiate()
	self.textBottomSub:paginate();
	self:addChild(self.textBottomSub)

    self.ConfirmButton = ISButton:new(self.panelX+130, ((self.panelY+panelHeight)-25)-btnHgt, btnWid, btnHgt, "", self, LSAmbitionsConfMenu.onClick)
    self.ConfirmButton.internal = "CONFIRM";
    self.ConfirmButton:initialise();
    self.ConfirmButton:instantiate();
	self.ConfirmButton.displayBackground = false
	self.ConfirmButton.borderColor = {r=1, g=1, b=1, a=0};
	self.ConfirmButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_ConfirmBT.png"))
    self:addChild(self.ConfirmButton);

    self.CloseButton = ISButton:new(((self.panelX+panelWidth)-130)-btnWid, ((self.panelY+panelHeight)-25)-btnHgt, btnWid, btnHgt, "", self, LSAmbitionsConfMenu.onClick)
    self.CloseButton.internal = "CANCEL";
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBT.png"))
    self:addChild(self.CloseButton);

end

function LSAmbitionsConfMenu:prerender()
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

function LSAmbitionsConfMenu:onClick(button)
    if button.internal == "CANCEL" then
		self.ambtUI.confirmationUI = false
        self:setVisible(false)
        self:removeFromUIManager()
    end
    if button.internal == "CONFIRM" then
		self.ambtUI.confirmationUI = false
		self.ambtUI:onConfirm(self.btnInternal, self.ambt.name)
		self:setVisible(false)
		self:removeFromUIManager()
    end
end

function LSAmbitionsConfMenu:update()
	self:bringToTop()
	if not self.ambtUI then
        self:setVisible(false)
        self:removeFromUIManager()
	end
	if self.CloseButton.mouseOver and (self.CloseButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBTOn.png")) then self.CloseButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBTOn.png"));
	elseif (not self.CloseButton.mouseOver) and (self.CloseButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBT.png")) then self.CloseButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBT.png")); end
	if self.ConfirmButton.mouseOver and (self.ConfirmButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_ConfirmBTOn.png")) then self.ConfirmButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_ConfirmBTOn.png"));
	elseif (not self.ConfirmButton.mouseOver) and (self.ConfirmButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_ConfirmBT.png")) then self.ConfirmButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_ConfirmBT.png")); end
end

function LSAmbitionsConfMenu:new(x, y, width, height, ambt, player, menuSkin)
    local o = {}
    o = ISPanel:new(x, y, width, height);
    setmetatable(o, self)
    self.__index = self
    if y == 0 then
        o.y = o:getMouseY() - (height / 2)
        o:setY(o.y)
    end
    if x == 0 then
        o.x = o:getMouseX() - (width / 2)
        o:setX(o.x)
    end
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.8};
    o.width = width;
    o.height = height;
    o.player = player;
    o.ambt = ambt;
	o.menuSkin = menuSkin
    LSAmbitionsConfMenu.instance = o;
	o.activeText = "IGUI_LSAmbitions_Confirm_Activate"
	if ambt.isActive then o.activeText = "IGUI_LSAmbitions_Confirm_Deactivate"; end
	o.panelX = (width/2)-200
	o.panelY = (height/2)-175
	o.cooldownTime = SandboxVars.LSAmbt.Cooldown or 36
    return o;
end
