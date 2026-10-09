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

LSDebugInventions = ISPanelJoypad:derive("LSDebugInventions");

function LSDebugInventions:onTicked(index, enabled)
    self.tickBox.selected[index] = not enabled
end

function LSDebugInventions:initialise()
	ISPanel.initialise(self);

------- Dimensions

	local tM = getTextManager()
	local txtSizes = {{"Save","X",0},{"Cancel","X",0},{self.invName,"X",0},{"0000","X",0},{"TEXT","Y",0}} -- can use "XY" to measure both for the same string
	local btnX, btnY = 75, 25

	for n=1,#txtSizes do
		txtSizes[n][3], txtSizes[n][4] = LSUtil.measureString(tM, txtSizes[n][2], self.fontType, txtSizes[n][1])
	end

	--- Y
	-- local fontSize = txtSizes[5][3]
	local btnHeight = math.max(btnY, txtSizes[5][3])
	--- X
	-- local headerWidth = txtSizes[3][3]
	-- local numWidth = txtSizes[4][3]
	local confirmBtnWidth = math.max(btnX, txtSizes[1][3])
	local okBtnWidth = math.max(btnX, txtSizes[2][3])

------- Header
	
	self.Header = LSUtil.doRichTextType((self:getWidth()-txtSizes[3][3])/2, txtSizes[5][3]-2, txtSizes[3][3], txtSizes[5][3],self.invName,self.fontType)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

------- Options
	
	local num = 0
	for k, v in pairs(self.data['improvementData']) do
		if v and v[1] and v[2] then
			local text = k.." ("..tostring(v[1])..")"
			local textWidth = tM:MeasureStringX(self.fontType, text)
			num = num+1
			local textY = (txtSizes[5][3]+16)*num
			local numTxt = tostring(num)
			-- option name
			self['textBoxName'..numTxt] = LSUtil.doRichTextType(5, textY, textWidth, txtSizes[5][3],text,self.fontType)
			self['textBoxName'..numTxt].clip = true
			self['textBoxName'..numTxt]:initialise()
			self['textBoxName'..numTxt]:instantiate()
			self['textBoxName'..numTxt]:paginate();
			self:addChild(self['textBoxName'..numTxt])
			-- research max string (/10), goes at the end
			self['textBoxEnd'..numTxt] = LSUtil.doRichTextType(self:getWidth()-(5+txtSizes[4][3]), textY, txtSizes[4][3], txtSizes[5][3],"/"..tostring(v[2]),self.fontType)
			self['textBoxEnd'..numTxt].clip = true
			self['textBoxEnd'..numTxt]:initialise()
			self['textBoxEnd'..numTxt]:instantiate()
			self['textBoxEnd'..numTxt]:paginate();
			self:addChild(self['textBoxEnd'..numTxt])
			-- input box
			self['textBox'..numTxt] = ISTextEntryBox:new(tostring(v[1]),self:getWidth()-(10+txtSizes[4][3]*2), textY-2, txtSizes[4][3], txtSizes[5][3])
			self['textBox'..numTxt]:initialise()
			self['textBox'..numTxt]:instantiate()
			
			self['textBox'..numTxt].currentText = v[1]
			self['textBox'..numTxt].maxValue = v[2]
			self['textBox'..numTxt].keyString = k
			self['textBox'..numTxt].font = self.fontType
			
			self['textBox'..numTxt]:setMaxLines(1)
			self['textBox'..numTxt]:setMaxTextLength(2)
			self['textBox'..numTxt]:setOnlyNumbers(true)

			self:addChild(self['textBox'..numTxt])
			-- convenience buttons (+ and -)
			self['btnAdd'..numTxt] = ISButton:new(self:getWidth()-(15+txtSizes[4][3]*2+txtSizes[4][3]/2), textY, txtSizes[4][3]/2, txtSizes[5][3], "+", self, LSDebugInventions.onAdd);
			self['btnAdd'..numTxt].internal = numTxt;
			self['btnAdd'..numTxt]:initialise();
			self['btnAdd'..numTxt]:instantiate();
			self['btnAdd'..numTxt].borderColor = {r=1, g=1, b=1, a=0.1};
			self:addChild(self['btnAdd'..numTxt]);
			
			self['btnSub'..numTxt] = ISButton:new(self:getWidth()-(17+txtSizes[4][3]*3), textY, txtSizes[4][3]/2, txtSizes[5][3], "-", self, LSDebugInventions.onSub);
			self['btnSub'..numTxt].internal = numTxt;
			self['btnSub'..numTxt]:initialise();
			self['btnSub'..numTxt]:instantiate();
			self['btnSub'..numTxt].borderColor = {r=1, g=1, b=1, a=0.1};
			self:addChild(self['btnSub'..numTxt]);
		end
	end
	self.optionNum = num

------- Buttons

	local availableWidth = self:getWidth()/2
	local spacing = availableWidth/3

    self.confirm = ISButton:new((self:getWidth()/2)+((spacing)/2), self:getHeight()-(btnHeight+5), confirmBtnWidth, btnHeight, "Save", self, LSDebugInventions.onClick);
    self.confirm.internal = "Confirm";
    self.confirm:initialise();
    self.confirm:instantiate();
    self.confirm.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.confirm);

    self.ok = ISButton:new(spacing, self:getHeight()-(btnHeight+5), okBtnWidth, btnHeight, "Cancel", self, LSDebugInventions.destroy);
    self.ok.internal = "Close";
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    self:insertNewLineOfButtons(self.ok)
end

function LSDebugInventions:onAdd(btn)
	local currentVal = tonumber(self['textBox'..btn.internal].currentText) or 0
	local newVal = math.min(tonumber(self['textBox'..btn.internal].maxValue),currentVal+1)
	self['textBox'..btn.internal]:setText(tostring(newVal))
	self['textBox'..btn.internal].currentText = tostring(newVal)
end

function LSDebugInventions:onSub(btn)
	local currentVal = tonumber(self['textBox'..btn.internal].currentText) or 0
	local newVal = math.max(0,currentVal-1)
	self['textBox'..btn.internal]:setText(tostring(newVal))
	self['textBox'..btn.internal].currentText = tostring(newVal)
end

function LSDebugInventions:close()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSDebugInventions:destroy()
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSDebugInventions:onClick(button)
	local update
	local invItemDefs = LSUtil.deepCopy(LSInventionDefs.Items[self.cN])
	local invImprovDefs = LSUtil.deepCopy(LSInventionDefs.Improvements[self.cN])

	local isObj = instanceof(self.inv, "IsoObject")
	if isObj and not LSUtil.isValidObj(self.inv, self.cN) then self:destroy(); return;
	elseif not isObj and (not LSUtil.isValidInvItem(self.inv) or not self.inv:isInPlayerInventory()) then self:destroy(); return; end
	local newCostPenalty, impNum
	if self.optionNum > 0 then
		newCostPenalty, impNum = 1, 0
		for n=1,self.optionNum do
			local option = self['textBox'..tostring(n)]
			if option and option.maxValue and option.keyString then
				local val = tonumber(option:getText())
				if val and type(val) == "number" then
					val = math.max(0,math.min(val, option.maxValue))
					if self.data['improvementData'][option.keyString] then
						self.data['improvementData'][option.keyString][1] = val
						if val == 0 then -- research 0, use base table with direct values (do not check if key)
							local key = invItemDefs[option.keyString]
							self.data['inventionData'][option.keyString] = key
						else -- research levels, use table with tables (check if key)
							local key = invImprovDefs[option.keyString]
							if key then
								local cost
								if key.repeatable then -- several levels
									self.data['inventionData'][option.keyString] = key.repeatable[val]
									if key.special then 
										cost = LSInventionDefs.ImprovCost['addRS']*val
									else
										cost = LSInventionDefs.ImprovCost['addR']*val
									end
								else -- only 1 level, use result (implied, since value is higher than 0)
									self.data['inventionData'][option.keyString] = key.result
									if key.special then 
										cost = LSInventionDefs.ImprovCost['addS']
									else
										cost = LSInventionDefs.ImprovCost['add']
									end
								end
								if option.keyString ~= "costDecrease" then
									newCostPenalty = newCostPenalty+cost
									if option.keyString ~= "standardization" then
										impNum = impNum+val
									end
								end
							end
						end
						if option.keyString == "efficiency" then
							for n=1, #self.data['inventionData']['efficiencyBase'] do
								self.data['inventionData']['efficiencyMult'][n] = self.data['inventionData']['efficiencyBase'][n]*self.data['inventionData']['efficiency']
							end
						end
						update = true
					end
				end
			end
		end
	end
	if update then
		if impNum and impNum >= LSInventionDefs.ImprovCost['numPenalty'] then
			newCostPenalty = newCostPenalty+(math.floor(impNum/LSInventionDefs.ImprovCost['numPenalty'])*LSInventionDefs.ImprovCost['addR'])
		end
		if newCostPenalty and newCostPenalty ~= self.data['inventionData']['costPenalty'] then self.data['inventionData']['costPenalty'] = newCostPenalty; end
		LSUtil.fillInventionItem(self.data)
		if LSInv['OnRefuel'..self.cN] then
			LSInv['OnRefuel'..self.cN](self.inv, self.data, self.cN)
		elseif isObj then
			LSSync.transmit(self.inv)
		else
			LSSync.syncItemVal(self.inv, self.data['inventionData'], self.cN)
		end
	end
	self:destroy()
end

function LSDebugInventions:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function LSDebugInventions:render()

end

function LSDebugInventions:update()
	--self.newValue = tonumber(self.textBox:getText())
end

local function getUIDimensions(h, w, data, font)
	local tM = getTextManager()
	local textH = tM:MeasureStringY(font, "TEXT")+16
	local baseHeight = h+textH
	local textW = tM:MeasureStringX(font, ".")
	for k, v in pairs(data['improvementData']) do
		baseHeight = baseHeight+textH
		local tW = tM:MeasureStringX(font, k)
		if tW > textW then textW = tW; end
	end
	return baseHeight, w+textW
end

function LSDebugInventions:new(X,Y,W,H,invName,inv,data,CN)
	local font = UIFont.NewSmall
	local height, width = getUIDimensions(H, W, data, font)
	local o = {}
	o = ISPanelJoypad:new(X, Y, width, height);
	setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.7};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.fontType = font
	o.cN = CN
	o.inv = inv
	o.invName = invName
	o.data = data
	o.moveWithMouse = true
	o:noBackground()
    return o;
end
