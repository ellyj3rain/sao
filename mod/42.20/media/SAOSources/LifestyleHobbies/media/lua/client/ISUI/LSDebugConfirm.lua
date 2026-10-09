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

LSDebugConfirm = ISPanelJoypad:derive("LSDebugConfirm");

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

function LSDebugConfirm:initialise()
	ISPanel.initialise(self);

------- TEXT BOX

	self.Header = doRichTextType(10, 5, self:getWidth()-20, 90,"<H2> "..getText("IGUI_LSSkill_Edit"),UIFont.Large)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

	self.newText2 = doRichTextType((self:getWidth()-120)/2, 105, 120, 11,"<CENTRE> "..self.name,UIFont.NewSmall)
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

------- REGULAR BUTTONS

	local availableWidth = self:getWidth()-180
	local spacing = availableWidth/3

    self.confirm = ISButton:new(spacing, self:getHeight()-50, 90, 35, getText("UI_Confirm"), self, LSDebugConfirm.onClick);
    self.confirm.internal = "Confirm";
    self.confirm:initialise();
    self.confirm:instantiate();
    self.confirm.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.confirm);

    self.ok = ISButton:new((self:getWidth()/2)+((spacing)/2), self:getHeight()-50, 90, 35, getText("UI_Cancel"), self, LSDebugConfirm.destroy);
    self.ok.internal = "Close";
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    self:insertNewLineOfButtons(self.ok)
end

function LSDebugConfirm:close()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSDebugConfirm:destroy()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSDebugConfirm:onClick(button)
	if self.newValue and (type(self.newValue) == "number") and self.newValue >= 0 and self.newValue <= 10 and (self.newValue ~= self.value) then self.value = self.newValue; end
	HiddenSkills.setLevel(self.character, self.name, self.value, self.skill)
	self:destroy()
end

function LSDebugConfirm:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function LSDebugConfirm:render()

end

function LSDebugConfirm:update()
	self.newValue = tonumber(self.textBox:getText())
end

function LSDebugConfirm:new(X,Y,W,H,Player,Skill,Name)
	local x = X
	local y = Y
	local width = W
	local height = H
	local o = {}
	o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
    self.__index = self
    o.character = Player
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.ogAmbt = AMBT
	o.key = Key
	o.value = Skill[1]
	o.skill = Skill
	o.name = Name
	o.newValue = Skill[1]
	o:noBackground()
    return o;
end
