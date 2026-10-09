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

LSAmbitionsMenu = ISPanelJoypad:derive("LSAmbitionsMenu")

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

local function doTableSort(player, list, listActive, category)
	local items = player:getModData().Ambitions
	local sortedItems = getSortedItems(items)

	if category then
		for _, v in pairs(sortedItems) do
			if ((v.cat == category) or (category == "All")) then
				if list then list:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=v}); end
			end
		end
		return
	end

	for _, v in pairs(sortedItems) do
		if list then list:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=v}); end
		if listActive and v.isActive then listActive:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=v}); end
	end
end

local function getActiveInProgress(list)
	local num = 0
	if list and (list:size() > 0) then
		for n=1, list:size() do
			if not list.items[n].item.data.completed then
				num = math.ceil(num+1)
			end
		end
	end
	return num
end

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

local function doRichTextTypeGoal(x,y,w,h,customText,font,r,g,b)
	local newRichText = ISRichTextPanel:new(x, y, w, h)
	newRichText.backgroundColor = {r=0, g=0, b=0, a=0}
	newRichText.text = customText
	newRichText.defaultFont = font
	newRichText.autosetheight = true
	newRichText.marginLeft = 0
	newRichText.marginTop = 4
	newRichText.marginRight = 0
	newRichText.marginBottom = 0
	newRichText.textR = r
	newRichText.textG = g
	newRichText.textB = b
	newRichText.maxLines = math.floor((h-4) / getTextManager():getFontFromEnum(font):getLineHeight())
	return newRichText
end

local function getClosestTime(cdTime)
--print("TIME TEST getHourMinute() IS: "..getHourMinute()) --returns string like 19:20
	local addTime, getTime = 0, getHourMinute()
	local hr, minute = getTime:match("(%d+):(%d+)")
	hr, minute = tonumber(hr), tonumber(minute)
	if minute >= 30 then addTime = 1; end
	addTime = addTime+cdTime
	return addTime
end

function LSAmbitionsMenu:onScrollClickActive()
	if (not self.ScrollListActive.selected) or self.confirmationUI then return; end
	if self.ScrollListActive.items[self.ScrollListActive.selected].item.data.isHidden then
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	else
		self.selectedAmbt = self.ScrollListActive.items[self.ScrollListActive.selected].item.data
		self:onClickList()
	end
end

function LSAmbitionsMenu:onScrollClick()
	if (not self.ScrollList.selected) or self.confirmationUI then return; end
	if self.ScrollList.items[self.ScrollList.selected].item.data.isHidden then
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	else
		self.selectedAmbt = self.ScrollList.items[self.ScrollList.selected].item.data
		self:onClickList()
	end
end

local function getIconTooltip(btnInternal, aType, cooldown)
	local icon = btnInternal
	if cooldown then return getText("Tooltip_LSABTM_IconBtn_CD").." <SPACE>".." <RGB:1,1,0>"..cooldown;
	elseif btnInternal == "CompletedOff" then icon = "Completed";
	elseif (btnInternal ~= "Completed") and (aType == "Passive") then icon = aType; end
	
	return getText("Tooltip_LSABTM_IconBtn_"..icon)
end

local function getCooldown(data, name)
	if data[name].cd and (data[name].cd > 0) then return data[name].cd; end
	return false
end

function LSAmbitionsMenu:onClickList()
	local aType, cooldown = "Active", getCooldown(self.character:getModData().Ambitions, self.selectedAmbt.name)
	self.DescriptionImage:setImage(getTexture("media/ui/Ambitions/"..self.selectedAmbt.texture..".png"))
	if self.selectedAmbt.isPassive then aType = "Passive"; self.IconBtn:setEnable(false); self.DescriptionImageBkg:setEnable(false); self.DescriptionImage.internal = "Passive";
	elseif not cooldown then self.IconBtn:setEnable(true); self.DescriptionImageBkg:setEnable(true); self.DescriptionImage.internal = "Active"; end
	if cooldown then self.IconBtn:setEnable(false); self.DescriptionImageBkg:setEnable(true); self.DescriptionImageBkg.internal = "Passive"; self.DescriptionImage.internal = "Passive"; end
	
	local btnInternal, ImgSqr = "Active", "H"
	if self.character:getModData().Ambitions[self.selectedAmbt.name].completed and (not self.character:getModData().Ambitions[self.selectedAmbt.name].isActive) then btnInternal = "Completed"; self.IconBtn:setEnable(true); ImgSqr = "Completed"; self.DescriptionImageBkg:setEnable(true);
		if self.ScrollListActive:size() >= self.activeCompLimit then btnInternal = "CompletedOff"; end
		if cooldown then self.IconBtn:setEnable(false); self.DescriptionImageBkg:setEnable(false); end
	elseif (not self.selectedAmbt.isPassive) and (not self.character:getModData().Ambitions[self.selectedAmbt.name].isActive) then btnInternal = "Inactive";
		if (getActiveInProgress(self.ScrollListActive) >= self.activeLimit) or (self.ScrollListActive:size() >= self.activeCompLimit) then self.IconBtn:setEnable(false); self.DescriptionImageBkg:setEnable(false); self.DescriptionImage.internal = "Passive"; end;
	elseif self.character:getModData().Ambitions[self.selectedAmbt.name].isActive then ImgSqr = "Active";
	end
	self.IconBtn:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Icon_"..btnInternal..".png"))
	self.IconBtn.internal = btnInternal
	local iconTooltip = getIconTooltip(btnInternal, aType, cooldown)
	self.IconBtn:setTooltip(iconTooltip)

	self.DescriptionImageBkg:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_Sqr_"..ImgSqr..".png"))
	if not cooldown then self.DescriptionImageBkg.internal = btnInternal; end
	if self.DescriptionImage.internal ~= "Passive" then self.DescriptionImage.internal = btnInternal; end
	
	self.DescriptionName:setText("<RGB:0.1,0,0.5>".." <CENTRE>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name))
	self.DescriptionName:paginate();
	self.DescriptionName:setVisible(true)
	self.DescriptionDesc:setText("<RGB:0,0.37,1>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_desc"))
	self.DescriptionDesc:paginate();
	self.DescriptionDesc:setVisible(true)
	
	self.DescriptionType:setText("<RGB:0.24,0.45,0.68>".." <CENTRE>"..getText("IGUI_LSAmbitions_Text_Type").." <SPACE>".." <RGB:0.45,0.54,0.83>"..getText("IGUI_LSAmbitions_Type_"..aType))
	self.DescriptionType:paginate();
	self.DescriptionType:setVisible(true)

	local cat = self.selectedAmbt.cat or "None"
	self.DescriptionCat:setText("<RGB:0.24,0.45,0.68>".." <CENTRE>"..getText("IGUI_LSAmbitions_Text_Cat").." <SPACE>"..self.catRGB..getText("IGUI_LSAmbitions_Cat_"..cat))
	self.DescriptionCat:paginate();
	self.DescriptionCat:setVisible(true)
	if self.selectedAmbt.reqHas then
		self.DescriptionReq:setText(" <IMAGE:media/textures/LSABTM/"..self.menuSkin.."/Icon_Unlock.png,12,12>"..
		"<RGB:0.6,0.6,0.6>"..getText("IGUI_LSAmbitions_Text_Req").." <SPACE>".."<RGB:0.45,0.54,0.83>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_req"))
		self.DescriptionReq:paginate();
		self.DescriptionReq:setVisible(true)
	else
		self.DescriptionReq:setVisible(false)
	end
	if self.selectedAmbt.reqNotHas then
		self.DescriptionReqNeg:setText(" <IMAGE:media/textures/LSABTM/"..self.menuSkin.."/Icon_Unlock.png,12,12>"..
		"<RGB:0.6,0.6,0.6>"..getText("IGUI_LSAmbitions_Text_ReqNot").." <SPACE>".."<RGB:0.45,0.54,0.83>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_reqNot"))
		self.DescriptionReqNeg:paginate();
		self.DescriptionReqNeg:setVisible(true)
	else
		self.DescriptionReqNeg:setVisible(false)
	end

	self.DescriptionRewards:setText(" <IMAGE:media/textures/LSABTM/"..self.menuSkin.."/Icon_Completed.png,12,12>"..
	"<RGB:0.24,0.45,0.68>"..getText("IGUI_LSAmbitions_Text_RewardActive")..": ".." <SPACE>".."<RGB:0.45,0.54,0.83>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_give").." ".." <LINE>"..
	" <IMAGE:media/textures/LSABTM/"..self.menuSkin.."/Icon_Completed.png,12,12>"..
	"<RGB:0.24,0.45,0.68>"..getText("IGUI_LSAmbitions_Text_RewardPassive")..": ".." <SPACE>".."<RGB:0.45,0.54,0.83>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_givePassive"))
	self.DescriptionRewards:paginate();
	self.DescriptionRewards:setVisible(true)


	if getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_footer") ~= " " then
		self.DescriptionFooter:setText("<RGB:0.45,0.54,0.83>".." <CENTRE>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_footer"))
		self.DescriptionFooter:paginate();
		self.DescriptionFooter:setVisible(true)
	else
		self.DescriptionFooter:setVisible(false)
	end
	
	for n=1, 6 do
		local value = self.selectedAmbt['goal'..n]
		if (type(value) == "number") and (value > 0) then
			local currentProgress = self.selectedAmbt['goal'..n..'progress'] or 0
			local checkmark = "media/textures/LSABTM/"..self.menuSkin.."/checkmarkYes.png"
			if currentProgress < value then checkmark = "media/textures/LSABTM/"..self.menuSkin.."/checkmarkNo.png"; end
			self['Descriptiongoal'..n..'Image']:setImage(getTexture(checkmark))
			self['Descriptiongoal'..n]:setText(currentProgress.." <SPACE>"..getText("IGUI_LSAmbitions_GoalMiddle").." <SPACE>"..value.." <SPACE>"..getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_unit"..n))
			self['Descriptiongoal'..n]:paginate()
			self['Descriptiongoal'..n]:setVisible(true)
		elseif (type(value) == "string") and (value ~= " ") then
			local checkmark = "media/textures/LSABTM/"..self.menuSkin.."/checkmarkNo.png"
			local currentProgress = self.selectedAmbt['goal'..n..'progress'] or false
			if currentProgress then checkmark = "media/textures/LSABTM/"..self.menuSkin.."/checkmarkYes.png"; end
			self['Descriptiongoal'..n..'Image']:setImage(getTexture(checkmark))
			self['Descriptiongoal'..n]:setText(getText("IGUI_LSAmbitions_"..self.selectedAmbt.name.."_goal"..n))
			self['Descriptiongoal'..n]:paginate()
			self['Descriptiongoal'..n]:setVisible(true)
		else
			self['Descriptiongoal'..n..'Image']:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
			self['Descriptiongoal'..n]:setVisible(false)
		end
	end

end

function LSAmbitionsMenu:onScrollDoubleClickActive()
	if not self.ScrollListActive.selected then return; end
	if self.ScrollListActive.items[self.ScrollListActive.selected].item.data.isHidden then
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	elseif not self.confirmationUI then
		self.selectedAmbt = self.ScrollListActive.items[self.ScrollListActive.selected].item.data
		self:onClickList()
		if self.IconBtn:isEnabled() then self:onClick(self.IconBtn); end
	end
end

function LSAmbitionsMenu:onScrollDoubleClick()
	if not self.ScrollList.selected then return; end
	if self.ScrollList.items[self.ScrollList.selected].item.data.isHidden then
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	elseif not self.confirmationUI then
		self.selectedAmbt = self.ScrollList.items[self.ScrollList.selected].item.data
		self:onClickList()
		if self.IconBtn:isEnabled() then self:onClick(self.IconBtn); end
	end
end

local function hideIncompatibles(player, list)
	local found
	for _, v in pairs(list) do
		if v and player:getModData().Ambitions[v] and (not player:getModData().Ambitions[v].isHidden) then
			LSAmbtMng.resetAmbt(player, v, true)
			found = true
		end
	end
	return found
end

function LSAmbitionsMenu:onConfirm(internal, name)
	if self.selectedAmbt.name ~= name then return; end
	local newBtnInternal, newBkg, cooldown, hasExclusive = "Active", "Active", false, false
    if internal == "Active" then--option was active
		if self.character:getModData().Ambitions[self.selectedAmbt.name].completed then
			newBtnInternal, newBkg = "Completed", "Completed"
		else
			newBtnInternal, newBkg = "Inactive", "H"
		end
		self.character:getModData().Ambitions[self.selectedAmbt.name].isActive = false
	else
		self.character:getModData().Ambitions[self.selectedAmbt.name].isActive = true
		if self.character:getModData().Ambitions[self.selectedAmbt.name].exclusive then hasExclusive = hideIncompatibles(self.character, self.character:getModData().Ambitions[self.selectedAmbt.name].exclusive); end
	end

	local cdTime = getClosestTime(self.cooldownTime)
	self.character:getModData().Ambitions[self.selectedAmbt.name].cd = cdTime
	cooldown = cdTime

	self.IconBtn:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Icon_"..newBtnInternal..".png"))
	self.IconBtn.internal = newBtnInternal
	self.DescriptionImageBkg:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_Sqr_"..newBkg..".png"))

	local tooltipText = getIconTooltip(newBtnInternal, "none", cooldown)
	if cooldown then self.IconBtn:setEnable(false); newBtnInternal = "Passive"; end
	self.IconBtn:setTooltip(tooltipText)
	self.DescriptionImageBkg.internal = newBtnInternal
	self.DescriptionImage.internal = newBtnInternal

	if hasExclusive then
		self.ScrollList:clear()
		doTableSort(self.character, self.ScrollList, false, self.catList[self.idxFocus])
	end

	self.ScrollListActive:clear()
	--local items = require("Properties/Player/LSAmbitions")
	doTableSort(self.character, false, self.ScrollListActive, false)
	--[[
	local items = self.character:getModData().Ambitions
	for k, v in pairs(items) do
		if self.character:getModData().Ambitions[v.name] and (not v.disable) then
			if self.character:getModData().Ambitions[v.name].isActive then self.ScrollListActive:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=self.character:getModData().Ambitions[v.name]}); end
		end
	end
	]]--
	local inProgressActive = getActiveInProgress(self.ScrollListActive)
	self.ActiveText:setText("<CENTRE>".."<RGB:0,0.38,1>"..getText("IGUI_LSAmbitions_Text_InProgress")..": ".." <SPACE>".." <RGB:0.9,0.6,0.14>"..inProgressActive.."/"..self.activeLimit..
	" <SPACE>".."<RGB:0,0.38,1>"..getText("IGUI_LSAmbitions_Text_Total")..": ".." <SPACE>".." <RGB:0.9,0.6,0.14>"..self.ScrollListActive:size().."/"..self.activeCompLimit)
	self.ActiveText:paginate()

	if isClient() then sendClientCommand(self.character, "LS", "SavePlayerData", {self.character:getModData()}); end

end

function LSAmbitionsMenu:onClick(button)
	if self.confirmationUI then return; end
	if (button.internal ~= "Close") and (button.internal ~= "Active") and (button.internal ~= "Inactive") and (button.internal ~= "Completed") then return; end
    if button.internal == "Close" then
        self:close()
		return
	end
	if not self.selectedAmbt then return; end
	if (button.internal == "Inactive") and (not self.character:getModData().Ambitions[self.selectedAmbt.name].completed) and ((getActiveInProgress(self.ScrollListActive) >= self.activeLimit) or (self.ScrollListActive:size() >= self.activeCompLimit)) then return; end
	if (button.internal == "Completed") and (self.ScrollListActive:size() >= self.activeCompLimit) then return; end

	local confUI = LSAmbitionsConfMenu:new(self.uiX, self.uiY, self:getWidth(),self:getHeight(), self.character:getModData().Ambitions[self.selectedAmbt.name], self.character, self.menuSkin);
	confUI:initialise()
	confUI:addToUIManager()
	confUI.ambtUI = self
	confUI.btnInternal = button.internal
	self.confirmationUI = confUI


end

function LSAmbitionsMenu:onChangeCategory(button)
	if self.confirmationUI then return; end
	local idx = self.idxFocus+1
	if idx > #self.catList then idx = 1; end
	self.idxFocus = idx
	--self.playlistNameBox.currentText = self.newCustomPlaylist[self.idxFocus].name
	self.CategoryBox:setText(self.catRGB.." <CENTRE>"..getText("IGUI_LSAmbitions_Cat_"..self.catList[idx]))
	self.CategoryBox:paginate();
	self.ScrollList:clear()
	self.DescriptionImageBkg:setEnable(false)
	self.DescriptionImageBkg:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_Sqr_H.png"))
	self.DescriptionImageBkg.internal = "Active"
	self.DescriptionImage.internal = "Image"
	self.DescriptionImage:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_H.png"))
	self.IconBtn:setEnable(false)
	self.IconBtn:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Icon_H.png"))
	self.IconBtn.internal = "Active"
	self.IconBtn.tooltip = false
	
	for n=1, #self.textList do
		local desc = self.textList[n]
		self[desc]:setVisible(false)
	end
	for n=1, 6 do
		self['Descriptiongoal'..n..'Image']:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
		self['Descriptiongoal'..n]:setVisible(false)
	end
	--local specificPlayer = getSpecificPlayer(0)
	--local items = require("Properties/Player/LSAmbitions")
	doTableSort(self.character, self.ScrollList, false, self.catList[idx])
	--[[
	local items = specificPlayer:getModData().Ambitions
	for k, v in pairs(items) do
		if specificPlayer:getModData().Ambitions[v.name] and ((v.cat == self.catList[idx]) or (self.catList[idx] == "All")) and (not v.disable) then
			self.ScrollList:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=specificPlayer:getModData().Ambitions[v.name]})
		end
	end
	]]--
end

local function getTextureValues(data, menuSkin)
	local r, g, b, a, icon = 0.3, 0.3, 1, 0.3, false
	if data.completed then r, g, b, a, icon = 0.9, 0.9, 0.9, 0.8, "Completed"; elseif data.isActive then r, g, b, a, icon = 0.6, 0.6, 1, 0.6, "Active"; elseif data.isHidden then r, g, b = 0, 0, 0; end
	if icon then icon = "media/textures/LSABTM/"..menuSkin.."/Icon_"..icon..".png"; end
	return r, g, b, a, icon
end

local function getFontValues(data, selected)
	local r, g, b, div = 0.3, 0.4, 0.58, 1
	if data.completed then r, g, b = 0.1, 0.57, 0.35; elseif data.isActive then r, g, b = 1, 1, 0.78; elseif data.isHidden then r, g, b = 0.52, 0.52, 0.52; end
	if selected then r, g, b = r+0.15, g+0.15, b+0.15; end
	if r > 1 then r = 1; end; if g > 1 then g = 1; end; if b > 1 then b = 1; end;
	return r, g, b, div
end

local function getRectValues(data)
	--local r, g, b = 0.56, 0.64, 0.7
	--data.completed then r, g, b = 0.47, 0.84, 0.49
	--data.isActive then r, g, b = 0.8, 0.78, 0.58
	local r, g, b = 0.11, 0.16, 0.38
	if data.completed then r, g, b = 0, 0.9, 0.27; elseif data.isActive then r, g, b = 1, 0.97, 0.61; elseif data.isHidden then r, g, b = 0, 0, 0; end
	return r, g, b
end

function LSAmbitionsMenu:doDrawItem(y, item, alt)
	--0.77, 0.87, 0.96
	local data, r, g, b, div, fontSize, icon, isSelected = item.item.data, 1, 1, 1, 1, getTextManager():getFontFromEnum(self.font):getLineHeight(), false, true
	if (self.selected ~= item.index) or data.isHidden then r, g, b = getRectValues(data); isSelected = false; end

	self:drawRect(0,y,self:getWidth(),self.itemheight-1, 0.3, r, g, b)

	r, g, b, div = getFontValues(data, isSelected)
	
	local text = item.text
	if data.isHidden then
		text = getText("IGUI_LSAmbitions_Text_Hidden")
		local hiddenText = getText("Tooltip_LSABTM_Hidden")
		if not SandboxVars.LSAmbt.HideTips then
			local tipText = getText("IGUI_LSAmbitions_"..data.name.."_tip")
			if tipText ~= "" and tipText ~= "IGUI_LSAmbitions_"..data.name.."_tip" then hiddenText = tipText; end
		end
		item.tooltip = hiddenText
	end
	
	self:drawText(text, self.itemheight+5, y+((self.itemheight/div)-fontSize)/2, r, g, b, 0.9, self.font)

	local texture = getTexture(item.item.texture)
	if texture then
		local a = 0.3
		r, g, b, a, icon = getTextureValues(data, self.parent.menuSkin)
		self:drawTextureScaledAspect(texture, 1, y, self.itemheight, self.itemheight, a, r, g, b)
		if icon then
			local iconTexture = getTexture(icon)
			if iconTexture then self:drawTextureScaledAspect(iconTexture, self.itemheight-8, y+(self.itemheight-11), 11, 11, a, 1, 1, 1); end
		end	
	end

	return y + self.itemheight
end
--
function LSAmbitionsMenu:initialise()

	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer and specificPlayer:getModData().LSAmbitionsMenuOverlayPanelSkin and tostring(specificPlayer:getModData().LSAmbitionsMenuOverlayPanelSkin) then
		self.menuSkin = specificPlayer:getModData().LSAmbitionsMenuOverlayPanelSkin
	end

	self.BackgroundImage = doImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTMBKG.png"))
	self.BackgroundImage:initialise()
	self:addChild(self.BackgroundImage)

	self.Header = doRichTextType(50, 25, 350, 40,"<H1> ".."<RGB:0.61,0.75,1> "..getText("IGUI_LSAmbitions_Header"),UIFont.Large)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

	self.CategoryBox = doRichTextType(430, 63, 163, 22,self.catRGB.." <CENTRE>"..getText("IGUI_LSAmbitions_Cat_"..self.catText),UIFont.Medium)
	self.CategoryBox:initialise()
	self.CategoryBox:instantiate()
	self.CategoryBox:paginate();
	self:addChild(self.CategoryBox)

	self.categorySelectButton = ISButton:new(596, 60, 26, 26, "", self, self.onChangeCategory)
	self.categorySelectButton.internal = "Next"
	self.categorySelectButton:initialise()
	self.categorySelectButton:instantiate()
	self.categorySelectButton.displayBackground = false
	self.categorySelectButton.borderColor = {r=1, g=1, b=1, a=0};
	self.categorySelectButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Category_SelectOff.png"))
	--self.categorySelectButton:setTooltip(getText("Tooltip_LSABTM_PlaylistSelect"))
	self:addChild(self.categorySelectButton)

    self.ScrollList = ISScrollingListBox:new(428, 93, 193, 254);
	self.ScrollList:setOnMouseDownFunction(self, self.onScrollClick)
	self.ScrollList:setOnMouseDoubleClick(self, self.onScrollDoubleClick)
	self.ScrollList.doDrawItem = LSAmbitionsMenu.doDrawItem
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
	self.ScrollList.vscroll.uptex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/btnUP.png")
	self.ScrollList.vscroll.downtex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/btnDOWN.png")
	self.ScrollList.vscroll.toptex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/barTOP.png")
	self.ScrollList.vscroll.midtex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/barMID.png")
	self.ScrollList.vscroll.bottex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/barBOT.png")
   -- self.ScrollList:addScrollBars();
    self:addChild(self.ScrollList);

    self.ScrollListActive = ISScrollingListBox:new(428, 394, 193, 221);
	self.ScrollListActive:setOnMouseDownFunction(self, self.onScrollClickActive)
	self.ScrollListActive:setOnMouseDoubleClick(self, self.onScrollDoubleClickActive)
	self.ScrollListActive.doDrawItem = LSAmbitionsMenu.doDrawItem
	self.ScrollListActive.backgroundColor = {r=0, g=0, b=0, a=0};
	self.ScrollListActive.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.ScrollListActive:noBackground();
	--self.ScrollListActive.altBgColor = {r=0.2, g=0.3, b=0.2, a=0}
	--self.ScrollListActive.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.ScrollListActive.font = UIFont.Medium
	--self.ScrollListActive.itemPadY = 4
	self.ScrollListActive.fontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
	self.ScrollListActive.itemheight = 32
    self.ScrollListActive:initialise();
    self.ScrollListActive:instantiate();
	self.ScrollListActive.vscroll.backgroundColor = {r=0, g=0, b=0, a=0}
	self.ScrollListActive.vscroll.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	self.ScrollListActive.vscroll.uptex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/btnUP.png")
	self.ScrollListActive.vscroll.downtex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/btnDOWN.png")
	self.ScrollListActive.vscroll.toptex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/barTOP.png")
	self.ScrollListActive.vscroll.midtex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/barMID.png")
	self.ScrollListActive.vscroll.bottex = getTexture("media/textures/LSABTM/"..self.menuSkin.."/barBOT.png")
   -- self.ScrollListActive:addScrollBars();
    self:addChild(self.ScrollListActive);

	--local items = require("Properties/Player/LSAmbitions")
	doTableSort(specificPlayer, self.ScrollList, self.ScrollListActive, false)
	--[[
	local items = specificPlayer:getModData().Ambitions
	for k, v in pairs(items) do
		if specificPlayer:getModData().Ambitions[v.name] and (not v.disable) then
			self.ScrollList:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=specificPlayer:getModData().Ambitions[v.name]})
			if specificPlayer:getModData().Ambitions[v.name].isActive then self.ScrollListActive:addItem(getText("IGUI_LSAmbitions_"..v.name), {texture="media/ui/Ambitions/"..v.texture..".png",data=specificPlayer:getModData().Ambitions[v.name]}); end
		end
	end
	]]--

	self.ActiveTextTitle = doRichTextType(427, 356, 195, 20,"<RGB:0,0.38,1>".." <CENTRE>"..getText("IGUI_LSAmbitions_Type_Active"),UIFont.MediumNew)
	self.ActiveTextTitle:initialise()
	self.ActiveTextTitle:instantiate()
	self.ActiveTextTitle:paginate();
	self:addChild(self.ActiveTextTitle)

	self.ActiveText = doRichTextType(427, 373, 195, 12,"<CENTRE>".."<RGB:0,0.38,1>"..getText("IGUI_LSAmbitions_Text_InProgress")..": ".." <SPACE>".." <RGB:0.9,0.6,0.14>"..getActiveInProgress(self.ScrollListActive).."/"..self.activeLimit..
	" <SPACE>".."<RGB:0,0.38,1>"..getText("IGUI_LSAmbitions_Text_Total")..": ".." <SPACE>".." <RGB:0.9,0.6,0.14>"..self.ScrollListActive:size().."/"..self.activeCompLimit,UIFont.MediumNew)
	self.ActiveText:initialise()
	self.ActiveText:instantiate()
	self.ActiveText:paginate();
	self:addChild(self.ActiveText)

    self.CloseButton = ISButton:new(9, 9, 29, 29, "", self, self.onClick);
    self.CloseButton.internal = "Close";
	self.CloseButton:setTooltip(getText("Tooltip_LSAM_CloseSimple"))
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBT.png"))
    self:addChild(self.CloseButton);

    self.DescriptionImageBkg = ISButton:new(43,62,92,92, "", self, self.onClick);
    self.DescriptionImageBkg.internal = "Active";
    self.DescriptionImageBkg:initialise();
    self.DescriptionImageBkg:instantiate();
	self.DescriptionImageBkg.displayBackground = false
	self.DescriptionImageBkg.borderColor = {r=1, g=1, b=1, a=0};
	self.DescriptionImageBkg:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_Sqr_H.png"))
	self.DescriptionImageBkg:setEnable(false)
    self:addChild(self.DescriptionImageBkg);

    self.DescriptionImage = ISButton:new(57,76,64,64, "", self, self.onClick);
    self.DescriptionImage.internal = "Image";
    self.DescriptionImage:initialise();
    self.DescriptionImage:instantiate();
	self.DescriptionImage.displayBackground = false
	self.DescriptionImage.borderColor = {r=1, g=1, b=1, a=0};
	self.DescriptionImage:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_H.png"))
    self:addChild(self.DescriptionImage);

    self.IconBtn = ISButton:new(121,140,22,22, "", self, self.onClick);
    self.IconBtn.internal = "Active";
    self.IconBtn:initialise();
    self.IconBtn:instantiate();
	self.IconBtn.displayBackground = false
	self.IconBtn.borderColor = {r=1, g=1, b=1, a=0};
	self.IconBtn:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Icon_H.png"))
	self.IconBtn:setEnable(false)
    self:addChild(self.IconBtn);

	self.DescriptionName = doRichTextType(144, 61, 253, 27,"none",UIFont.Large)
	self.DescriptionName:initialise()
	self.DescriptionName:instantiate()
	self.DescriptionName:paginate();
	self.DescriptionName:setVisible(false)
	self:addChild(self.DescriptionName)

	self.Descriptiongoal1 = doRichTextTypeGoal(85, 360, 300, 32,"none",UIFont.MediumNew)
	self.Descriptiongoal1:initialise()
	self.Descriptiongoal1:instantiate()
	self.Descriptiongoal1:paginate();
	self.Descriptiongoal1:setVisible(false)
	self:addChild(self.Descriptiongoal1)

    self.Descriptiongoal1Image = ISButton:new(53,365,22,22, "", self, self.onClick);
    self.Descriptiongoal1Image.internal = "Image";
    self.Descriptiongoal1Image:initialise();
    self.Descriptiongoal1Image:instantiate();
	self.Descriptiongoal1Image.displayBackground = false
	self.Descriptiongoal1Image.borderColor = {r=1, g=1, b=1, a=0};
	self.Descriptiongoal1Image:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
    self:addChild(self.Descriptiongoal1Image);

	self.Descriptiongoal2 = doRichTextTypeGoal(85, 396, 300, 32,"none",UIFont.MediumNew)
	self.Descriptiongoal2:initialise()
	self.Descriptiongoal2:instantiate()
	self.Descriptiongoal2:paginate();
	self.Descriptiongoal2:setVisible(false)
	self:addChild(self.Descriptiongoal2)

    self.Descriptiongoal2Image = ISButton:new(53,401,22,22, "", self, self.onClick);
    self.Descriptiongoal2Image.internal = "Image";
    self.Descriptiongoal2Image:initialise();
    self.Descriptiongoal2Image:instantiate();
	self.Descriptiongoal2Image.displayBackground = false
	self.Descriptiongoal2Image.borderColor = {r=1, g=1, b=1, a=0};
	self.Descriptiongoal2Image:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
    self:addChild(self.Descriptiongoal2Image);

	self.Descriptiongoal3 = doRichTextTypeGoal(85, 432, 300, 32,"none",UIFont.MediumNew)
	self.Descriptiongoal3:initialise()
	self.Descriptiongoal3:instantiate()
	self.Descriptiongoal3:paginate();
	self.Descriptiongoal3:setVisible(false)
	self:addChild(self.Descriptiongoal3)

    self.Descriptiongoal3Image = ISButton:new(53,437,22,22, "", self, self.onClick);
    self.Descriptiongoal3Image.internal = "Image";
    self.Descriptiongoal3Image:initialise();
    self.Descriptiongoal3Image:instantiate();
	self.Descriptiongoal3Image.displayBackground = false
	self.Descriptiongoal3Image.borderColor = {r=1, g=1, b=1, a=0};
	self.Descriptiongoal3Image:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
    self:addChild(self.Descriptiongoal3Image);

	self.Descriptiongoal4 = doRichTextTypeGoal(85, 468, 300, 32,"none",UIFont.MediumNew)
	self.Descriptiongoal4:initialise()
	self.Descriptiongoal4:instantiate()
	self.Descriptiongoal4:paginate();
	self.Descriptiongoal4:setVisible(false)
	self:addChild(self.Descriptiongoal4)

    self.Descriptiongoal4Image = ISButton:new(53,473,22,22, "", self, self.onClick);
    self.Descriptiongoal4Image.internal = "Image";
    self.Descriptiongoal4Image:initialise();
    self.Descriptiongoal4Image:instantiate();
	self.Descriptiongoal4Image.displayBackground = false
	self.Descriptiongoal4Image.borderColor = {r=1, g=1, b=1, a=0};
	self.Descriptiongoal4Image:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
    self:addChild(self.Descriptiongoal4Image);

	self.Descriptiongoal5 = doRichTextTypeGoal(85, 504, 300, 32,"none",UIFont.MediumNew)
	self.Descriptiongoal5:initialise()
	self.Descriptiongoal5:instantiate()
	self.Descriptiongoal5:paginate();
	self.Descriptiongoal5:setVisible(false)
	self:addChild(self.Descriptiongoal5)

    self.Descriptiongoal5Image = ISButton:new(53,509,22,22, "", self, self.onClick);
    self.Descriptiongoal5Image.internal = "Image";
    self.Descriptiongoal5Image:initialise();
    self.Descriptiongoal5Image:instantiate();
	self.Descriptiongoal5Image.displayBackground = false
	self.Descriptiongoal5Image.borderColor = {r=1, g=1, b=1, a=0};
	self.Descriptiongoal5Image:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
    self:addChild(self.Descriptiongoal5Image);

	self.Descriptiongoal6 = doRichTextTypeGoal(85, 540, 300, 32,"none",UIFont.MediumNew)
	self.Descriptiongoal6:initialise()
	self.Descriptiongoal6:instantiate()
	self.Descriptiongoal6:paginate();
	self.Descriptiongoal6:setVisible(false)
	self:addChild(self.Descriptiongoal6)

    self.Descriptiongoal6Image = ISButton:new(53,545,22,22, "", self, self.onClick);
    self.Descriptiongoal6Image.internal = "Image";
    self.Descriptiongoal6Image:initialise();
    self.Descriptiongoal6Image:instantiate();
	self.Descriptiongoal6Image.displayBackground = false
	self.Descriptiongoal6Image.borderColor = {r=1, g=1, b=1, a=0};
	self.Descriptiongoal6Image:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/checkmarkH.png"))
    self:addChild(self.Descriptiongoal6Image);

	self.DescriptionFooter = doRichTextType(53, 580, 332, 29,"none",UIFont.Small)
	self.DescriptionFooter.maxLines = math.floor(29 / getTextManager():getFontFromEnum(UIFont.Small):getLineHeight())
	self.DescriptionFooter:initialise()
	self.DescriptionFooter:instantiate()
	self.DescriptionFooter:paginate();
	self.DescriptionFooter:setVisible(false)
	self:addChild(self.DescriptionFooter)

	self.DescriptionDesc = doRichTextType(42, 165, 354, 91,"none",UIFont.NewSmall)
	self.DescriptionDesc.maxLines = math.floor(91 / getTextManager():getFontFromEnum(UIFont.NewSmall):getLineHeight())
	self.DescriptionDesc:initialise()
	self.DescriptionDesc:instantiate()
	self.DescriptionDesc:paginate();
	self.DescriptionDesc:setVisible(false)
	self:addChild(self.DescriptionDesc)

	self.DescriptionType = doRichTextType(144, 88, 126, 11,"none",UIFont.MediumNew)
	self.DescriptionType.maxLines = math.floor(10 / getTextManager():getFontFromEnum(UIFont.MediumNew):getLineHeight())
	self.DescriptionType:initialise()
	self.DescriptionType:instantiate()
	self.DescriptionType:paginate();
	self.DescriptionType:setVisible(false)
	self:addChild(self.DescriptionType)

	self.DescriptionCat = doRichTextType(271, 88, 126, 11,"none",UIFont.MediumNew)
	self.DescriptionCat.maxLines = math.floor(10 / getTextManager():getFontFromEnum(UIFont.MediumNew):getLineHeight())
	self.DescriptionCat:initialise()
	self.DescriptionCat:instantiate()
	self.DescriptionCat:paginate();
	self.DescriptionCat:setVisible(false)
	self:addChild(self.DescriptionCat)

	self.DescriptionReq = doRichTextType(144, 103, 253, 29,"none",UIFont.Small)
	self.DescriptionReq.maxLines = math.floor(15 / getTextManager():getFontFromEnum(UIFont.Small):getLineHeight())
	self.DescriptionReq:initialise()
	self.DescriptionReq:instantiate()
	self.DescriptionReq:paginate();
	self.DescriptionReq:setVisible(false)
	self:addChild(self.DescriptionReq)

	self.DescriptionReqNeg = doRichTextType(144, 134, 253, 29,"none",UIFont.Small)
	self.DescriptionReqNeg.maxLines = math.floor(15 / getTextManager():getFontFromEnum(UIFont.Small):getLineHeight())
	self.DescriptionReqNeg:initialise()
	self.DescriptionReqNeg:instantiate()
	self.DescriptionReqNeg:paginate();
	self.DescriptionReqNeg:setVisible(false)
	self:addChild(self.DescriptionReqNeg)

	--self.DescriptionRewards = doRichTextType(150, 129, 247, 26,"none",UIFont.NewSmall)
	self.DescriptionRewards = doRichTextType(42, 262, 355, 86,"none",UIFont.NewSmall)
	self.DescriptionRewards.maxLines = math.floor(86 / getTextManager():getFontFromEnum(UIFont.NewSmall):getLineHeight())
	self.DescriptionRewards:initialise()
	self.DescriptionRewards:instantiate()
	self.DescriptionRewards:paginate();
	self.DescriptionRewards:setVisible(false)
	self:addChild(self.DescriptionRewards)

end

function LSAmbitionsMenu:update()
	if self.character:hasTimedActions() or self.character:isAiming() or self.character:isPlayerMoving() then self:close(); end

	if self.CloseButton.mouseOver and (self.CloseButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBTOn.png")) then
		self.CloseButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBTOn.png"))
	elseif (not self.CloseButton.mouseOver) and (self.CloseButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBT.png")) then
		self.CloseButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/LSABTM_CloseBT.png"))
	end
	if self.categorySelectButton.mouseOver and (self.categorySelectButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/Category_SelectOn.png")) then
		self.categorySelectButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Category_SelectOn.png"))
	elseif (not self.categorySelectButton.mouseOver) and (self.categorySelectButton.image ~= getTexture("media/textures/LSABTM/"..self.menuSkin.."/Category_SelectOff.png")) then
		self.categorySelectButton:setImage(getTexture("media/textures/LSABTM/"..self.menuSkin.."/Category_SelectOff.png"))
	end
end

function LSAmbitionsMenu:render()
	ISPanelJoypad.render(self);
end

function LSAmbitionsMenu:close()
	if self.confirmationUI then
		self.confirmationUI:setVisible(false);
		self.confirmationUI:removeFromUIManager();
	end
	self.ScrollList:clear()
	self.ScrollListActive:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSAmbitionsMenu:destroy()
	if self.confirmationUI then
		self.confirmationUI:setVisible(false);
		self.confirmationUI:removeFromUIManager();
	end
	self.ScrollList:clear()
	self.ScrollListActive:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSAmbitionsMenu:new(X, Y, Width, Height, Player, CustomPlaylist)
	local o = ISPanelJoypad:new(X, Y, Width, Height)
	setmetatable(o, self)
	self.__index = self
	--local playerObj = Player and getSpecificPlayer(Player) or nil
    --o.character = playerObj
	o.uiX = X
	o.uiY = Y
	o.character = getSpecificPlayer(Player)
	o.eKey = getCore():getKey("Emote")
	o.sKey = getCore():getKey("Shout")
	o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.98}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.catRGB = "<RGB:0.82,0.47,0> "
	o.catText = "All"
	o.catList = {"All","Athletic","Collectibles","Combat","Creativity","Handiness","Survival"}
	o.textList = {"DescriptionName","DescriptionDesc","DescriptionFooter","DescriptionType","DescriptionCat","DescriptionReq","DescriptionReqNeg","DescriptionRewards"}
	o.idxFocus = 1
	o.selectedAmbt = false
	o.activeLimit = SandboxVars.LSAmbt.MaxInProgress or 1
	o.activeCompLimit = SandboxVars.LSAmbt.MaxTotal or 3
	if o.activeCompLimit < o.activeLimit then o.activeCompLimit = o.activeLimit; end
	o.cooldownTime = SandboxVars.LSAmbt.Cooldown or 36
	o:noBackground()
	--o.anchorLeft = true;
	--o.anchorRight = true;
	--o.anchorTop = true;
	--o.anchorBottom = true;
	o.panelH = Height
	o.panelW = Width
	o.menuSkin = "LSSims"
	o.confirmationUI = false
	o.moveWithMouse = true
	return o
end





