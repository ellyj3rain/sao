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

LSDebugBTYConfirm = ISPanelJoypad:derive("LSDebugBTYConfirm");

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

function LSDebugBTYConfirm:onTicked(index, enabled)
    self.tickBox.selected[index] = enabled
end

function LSDebugBTYConfirm:initialise()
	ISPanel.initialise(self);

------- TEXT BOX

	self.Header = doRichTextType(10, 5, self:getWidth()-20, 90,"<H2> "..getText("Edit Beauty"),UIFont.Large)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

	self.newText2 = doRichTextType((self:getWidth()-120)/2, 55, 120, 11,"<CENTRE> "..self.spriteName,UIFont.NewSmall)
	self.newText2.clip = true
	self.newText2:initialise()
	self.newText2:instantiate()
	self.newText2:paginate();
	self:addChild(self.newText2)
	self.textBox = ISTextEntryBox:new(tostring(self.value),(self:getWidth()-120)/2, 70, 120, 20)
	self.textBox:initialise();
	self.textBox:instantiate();
	self.textBox.currentText = self.value
	self.textBox.font = UIFont.MediumNew
	self.textBox:setMaxLines(1)
	self.textBox:setMaxTextLength(3)
	self.textBox:setOnlyNumbers(true)
	self:addChild(self.textBox);

	local stringWidth = getTextManager():MeasureStringX(UIFont.Small, getText("Is Negative"))
	self.tickBox = ISTickBox:new((self:getWidth()-stringWidth)/2, 100, stringWidth, 30, "", self, self.onTicked)
	self.tickBox:initialise();
	self.tickBox:instantiate();
	self.tickBox:addOption(getText("Is Negative"))
	self.tickBox.selected[1] = self.ogNeg
	self:addChild(self.tickBox);

------- REGULAR BUTTONS

	local availableWidth = self:getWidth()-180
	local spacing = availableWidth/3

    self.confirm = ISButton:new(spacing, self:getHeight()-50, 80, 30, getText("UI_Confirm"), self, LSDebugBTYConfirm.onClick);
    self.confirm.internal = "Confirm";
    self.confirm:initialise();
    self.confirm:instantiate();
    self.confirm.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.confirm);

    self.ok = ISButton:new((self:getWidth()/2)+((spacing)/2), self:getHeight()-50, 80, 30, getText("UI_Cancel"), self, LSDebugBTYConfirm.destroy);
    self.ok.internal = "Close";
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    self:insertNewLineOfButtons(self.ok)
end

function LSDebugBTYConfirm:close()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSDebugBTYConfirm:destroy()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSDebugBTYConfirm:onClick(button)
	local val = self.newValue
	if val and (type(val) == "number") then
		if val < 0 then val = -1*val; end
		if val ~= self.ogVal or self.ogNeg ~= self.tickBox.selected[1] then
			if self.tickBox.selected[1] and val > 0 then val = -val; end
			sendClientCommand("LS", "UpdateServerBeauty", {self.spriteName,val})
			if not isClient() then updateCustomBeautyTable(self.spriteName,val); end
		end
	end
	self:destroy()
end

function LSDebugBTYConfirm:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function LSDebugBTYConfirm:render()

end

function LSDebugBTYConfirm:update()
	self.newValue = tonumber(self.textBox:getText())
end

function LSDebugBTYConfirm:new(X,Y,W,H,SpriteName,OGVal,Neg)
	local x = X
	local y = Y
	local width = W
	local height = H
	local o = {}
	o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
    self.__index = self
    o.spriteName = SpriteName
	o.ogVal = OGVal
	o.ogNeg = Neg
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.value = OGVal
	o:noBackground()
    return o;
end
