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

LSAmbtConfirm = ISPanelJoypad:derive("LSAmbtConfirm");

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

local function deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function LSAmbtConfirm:onTicked(index, enabled)
	if self.forceReset then self.forceReset = false;
	elseif not self.forceReset then self.forceReset = true; end 
    self.tickBox.selected[index] = self.forceReset
	--print("LSAmbtConfirm:onTicked forceReset is now: "..tostring(self.forceReset))
end

function LSAmbtConfirm:initialise()
	ISPanel.initialise(self);

------- TEXT BOX

	self.Header = doRichTextType(10, 5, self:getWidth()-20, 90,"<H2> "..getText("IGUI_LSAmbitions_"..self.ogAmbt.name).." <SIZE:medium>".." <LINE>"..getText("IGUI_LSAmbitions_Debug_Warning").." <SIZE:small>"
	.." <LINE>".." <CENTRE>"..self.key.." <SPACE>".."=".." <SPACE>"..tostring(self.value),UIFont.Large)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

	if self.canEdit then
		self.newText2 = doRichTextType((self:getWidth()-120)/2, 105, 120, 11,"<CENTRE> "..self.key,UIFont.NewSmall)
		self.newText2.clip = true
		self.newText2:initialise()
		self.newText2:instantiate()
		self.newText2:paginate();
		self:addChild(self.newText2)
		self.textBox = ISTextEntryBox:new(tostring(self.value),(self:getWidth()-120)/2, 120, 120, 20)
		self.textBox:initialise();
		self.textBox:instantiate();
		self.textBox.currentText = self.value
		self.textBox.font = UIFont.MediumNew
		self.textBox:setMaxLines(1)
		self.textBox:setMaxTextLength(10)
		self.textBox:setOnlyNumbers(true)
		self:addChild(self.textBox);
	end

	if self.key ~= "resetAdm" then
		local stringWidth = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_LSAmbitions_Debug_Warning2"))
		self.tickBox = ISTickBox:new((self:getWidth()-stringWidth)/2, 150, stringWidth, 30, "", self, self.onTicked)
		self.tickBox:initialise();
		self.tickBox:instantiate();
		self.tickBox:addOption(getText("IGUI_LSAmbitions_Debug_Warning2"))
		self.tickBox.selected[1] = self.forceReset
		self:addChild(self.tickBox);
	else
		self.newText = doRichTextType(10, 150, self:getWidth()-20, 30,"<CENTRE> "..getText("IGUI_LSAmbitions_Debug_Warning3"),UIFont.NewSmall)
		self.newText.clip = true
		self.newText:initialise()
		self.newText:instantiate()
		self.newText:paginate();
		self:addChild(self.newText)
	end

------- REGULAR BUTTONS

	local availableWidth = self:getWidth()-180
	local spacing = availableWidth/3

    self.confirm = ISButton:new(spacing, self:getHeight()-50, 90, 35, getText("UI_Confirm"), self, LSAmbtConfirm.onClick);
    self.confirm.internal = "Confirm";
    self.confirm:initialise();
    self.confirm:instantiate();
    self.confirm.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.confirm);

    self.ok = ISButton:new((self:getWidth()/2)+((spacing)/2), self:getHeight()-50, 90, 35, getText("UI_Cancel"), self, LSAmbtConfirm.destroy);
    self.ok.internal = "Close";
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    self:insertNewLineOfButtons(self.ok)
end

function LSAmbtConfirm:close()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSAmbtConfirm:destroy()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSAmbtConfirm:onClick(button)
	local t = deepCopy(self.ogAmbt)
	if self.newValue and (type(self.newValue) == "number") and (self.newValue > 0) and (self.newValue ~= self.value) then self.value = self.newValue; end
	sendClientCommand("LS", "UpdateAmbt", {t,self.ogAmbt.name,self.key,self.value,self.forceReset})
	self:destroy()
end

function LSAmbtConfirm:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function LSAmbtConfirm:render()

end

function LSAmbtConfirm:update()
	if self.canEdit then self.newValue = tonumber(self.textBox:getText()); end
end

function LSAmbtConfirm:new(X,Y,W,H,Player,AMBT,Key,Value,Edit)
	local x = X
	local y = Y
	local width = W
	local height = H
	local o = {}
	o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
    self.__index = self
    o.character = Player
	o.name = nil;
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.ogAmbt = AMBT
	o.key = Key
	o.value = Value
	o.newValue = 0
	o.canEdit = Edit
	o.forceReset = AMBT.resetF
	o:noBackground()
    return o;
end
