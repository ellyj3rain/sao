
LSResearchInvPanel = ISPanel:derive("LSResearchInvPanel");

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

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
--[[ -- can use to make priority based on total research level
local function getPriority(item)
	local score = 0 -- completed and active = 0; completed = 1; active = 2; inactive = 3; passive = 6; hidden = 7
	if not item.isActive then score = score + 1; end -- not active items
	if not item.completed then score = score + 2; end -- not completed items
	if (not item.completed) and item.isPassive then score = score + 3; end
	if item.isHidden then score = score + 4; end
	return score
end

local function getSortedItems(items)
	local sortedItems = {}
	for k, v in pairs(items) do
		if v and (not v.disable) then
			table.insert(sortedItems, v)
		end
	end
	table.sort(sortedItems, function(a, b)
		return getPriority(a) < getPriority(b)
	end)
	return sortedItems
end
]]--
function LSResearchInvPanel:doDrawItem(y, item, alt)
	if self.parent and self.parent.params then return 0; end
	--0.77, 0.87, 0.96
	local data, r, g, b, fontSize, icon, isSelected = item.item.data, 0.8, 0.8, 0.8, getTextManager():getFontFromEnum(self.font):getLineHeight(), false, true
	if self.selected ~= item.index then r, g, b = 0.4,0.4,0.4; isSelected = false; end

	self:drawRect(0,y,self:getWidth(),self.itemheight-1, 0.3, r, g, b)

	r, g, b = 0.3, 0.4, 0.58
	if isSelected then r, g, b = r+0.15, g+0.15, b+0.15; end
	
	self:drawText(item.text, self.itemheight+5, y+(self.itemheight-fontSize)/2, r, g, b, 0.9, self.font)

	local texture = item.item.texture
	if texture then
		self:drawTextureScaledAspect(texture, 1, y, self.itemheight, self.itemheight, 0.8, 0.9, 0.9, 0.9)
	end

	return y + self.itemheight
end

local function getInvTexText(inv)
	local tex, text = "", inv.invName
	if inv.invType == "obj" or inv.invType == "invObj" then
		text = LSUtil.getMoveableDisplayName("name not found", nil, nil, nil, inv.invResult)
		--tex = LSUtil.getObjTexture(inv.invResult, "E")
		local texture = getTexture(inv.invResult)
		if texture then tex = texture:splitIcon(); end
	elseif inv.invType == "item" or inv.invType == "invItem" then
		tex, text = LSUtil.getItemTexAndText(nil, nil, inv.invResult)
	end
	return tex, text
end

function LSResearchInvPanel:onScrollClick()
	if not self.ScrollList.selected then return; end

end

function LSResearchInvPanel:onScrollDoubleClick()
	if not self.ScrollList.selected then return; end
	-- self.ScrollList.items[self.ScrollList.selected].item.data
	self:onClick(self.ConfirmButton)
end

function LSResearchInvPanel:initialise()
    ISPanel.initialise(self);
    local btnWid = 29
    local btnHgt = 29
    local padBottom = 10
	local panelWidth = 237
	local panelHeight = 260
	getSoundManager():playUISound("UI_Note_Appear")
	
	self.BackgroundImage = doImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LSRSM/"..self.menuSkin.."/FOGBKG.png"))
	self.BackgroundImage:initialise()
	self:addChild(self.BackgroundImage)

	self.PanelImage = doImageType(self.panelX,self.panelY,panelWidth,panelHeight,getTexture("media/textures/LSRSM/"..self.menuSkin.."/InvPanel.png"))
	self.PanelImage:initialise()
	self:addChild(self.PanelImage)

	local ConfBtnInt = "CONFIRM"

	if self.params then

	local mediumNewTextHeight = getTextManager():getFontFromEnum(UIFont.MediumNew):getLineHeight()

		self.infoText = doRichTextType(self.panelX+21, self.panelY+21, 195, 198,"<RGB:0.2,0.3,0.47>"..getText("IGUI_Inventions_Abandon"),UIFont.MediumNew)
		self.infoText.maxLines = math.floor(198 / mediumNewTextHeight)
		self.infoText:initialise()
		self.infoText:instantiate()
		self.infoText:paginate();
		self:addChild(self.infoText)
		
		ConfBtnInt = "CONFIRMIMPROV"

	else
		self.ScrollList = ISScrollingListBox:new(self.panelX+21, self.panelY+21, 195, 198);
		self.ScrollList:setOnMouseDownFunction(self, self.onScrollClick)
		self.ScrollList:setOnMouseDoubleClick(self, self.onScrollDoubleClick)
		self.ScrollList.doDrawItem = LSResearchInvPanel.doDrawItem
		self.ScrollList.backgroundColor = {r=0, g=0, b=0, a=0};
		self.ScrollList.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
		self.ScrollList:noBackground();
		--self.ScrollList.altBgColor = {r=0.2, g=0.3, b=0.2, a=0}
		--self.ScrollList.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0};
		self.ScrollList.font = UIFont.Medium
		--self.ScrollList.itemPadY = 4
		self.ScrollList.fontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
		self.ScrollList.itemheight = 32
		self.ScrollList:initialise();
		self.ScrollList:instantiate();
		self.ScrollList.vscroll.backgroundColor = {r=0, g=0, b=0, a=0}
		self.ScrollList.vscroll.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
		self.ScrollList.vscroll.uptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnUP.png")
		self.ScrollList.vscroll.downtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnDOWN.png")
		self.ScrollList.vscroll.toptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barTOP.png")
		self.ScrollList.vscroll.midtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barMID.png")
		self.ScrollList.vscroll.bottex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barBOT.png")
	-- self.ScrollList:addScrollBars();
		self:addChild(self.ScrollList);

		--local sortedItems = getSortedItems(self.invList)
		--for _, v in pairs(sortedItems) do
		for _, v in pairs(self.invList) do
			local tex, name = getInvTexText(v)
			self.ScrollList:addItem(name, {texture=tex,data=v})
		end
	end

    self.ConfirmButton = ISButton:new(self.panelX+152, self.panelY+225, btnWid, btnHgt, "", self, LSResearchInvPanel.onClick)
    self.ConfirmButton.internal = ConfBtnInt;
    self.ConfirmButton:initialise();
    self.ConfirmButton:instantiate();
	self.ConfirmButton.displayBackground = false
	self.ConfirmButton.borderColor = {r=1, g=1, b=1, a=0};
	self.ConfirmButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm.png"))
    self:addChild(self.ConfirmButton);

    self.CloseButton = ISButton:new(self.panelX+56, self.panelY+225, btnWid, btnHgt, "", self, LSResearchInvPanel.onClick)
    self.CloseButton.internal = "CANCEL";
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png"))
    self:addChild(self.CloseButton);

end

function LSResearchInvPanel:prerender()
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

function LSResearchInvPanel:close()
	if self.parent then self.parent.invPanel = false; end
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSResearchInvPanel:destroy()
	if self.parent then self.parent.invPanel = false; end
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSResearchInvPanel:onClick(button)
	if button.internal == "CONFIRMIMPROV" and self.params then
		self.parent:onInvPanelConfirmImprov(self.params)
    elseif button.internal == "CONFIRM" and self.ScrollList.selected and self.ScrollList.items[self.ScrollList.selected].item.data ~= self.selectedInv then
		self.parent:onInvPanelConfirm(self.ScrollList.items[self.ScrollList.selected].item.data)        
    end
	self.parent.invPanel = false
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSResearchInvPanel:update()
	self:bringToTop()
	if not self.parent then
        self:setVisible(false)
        self:removeFromUIManager()
	end
	if self.CloseButton.mouseOver and (self.CloseButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close_On.png")) then self.CloseButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close_On.png"));
	elseif (not self.CloseButton.mouseOver) and (self.CloseButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png")) then self.CloseButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png")); end
	if self.ConfirmButton.mouseOver and (self.ConfirmButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm_On.png")) then self.ConfirmButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm_On.png"));
	elseif (not self.ConfirmButton.mouseOver) and (self.ConfirmButton.image ~= getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm.png")) then self.ConfirmButton:setImage(getTexture("media/textures/LSRSM/"..self.menuSkin.."/Confirm.png")); end
end

function LSResearchInvPanel:new(panel, selectedInv, invList, params, menuSkin)
	local x, y, width, height = panel:getX(), panel:getY(), panel:getWidth(),panel:getHeight()
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
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
    o.backgroundColor = {r=0, g=0, b=0, a=0}
	o.parent = panel
	o.invList = invList
    o.width = width
    o.height = height
	o.selectedInv = selectedInv
	o.params = params
	o.menuSkin = menuSkin
	local pX, pY = 14, 50
	if params then pX, pY = (width/2)-119, (height/2)-130; end
	o.panelX = pX
	o.panelY = pY
    LSResearchInvPanel.instance = o;
    return o;
end
