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


require "ISUI/ISUIElement"
require "ISUI/ISUIHandler"

LSResearchMenu = ISPanel:derive("LSResearchMenu")
local textColors = {
		bhs=" <RGB:0.5,0,0>",mhs=" <RGB:0.5,0.5,0>",ghs=" <RGB:0,0.5,0>",
		title=" <RGB:0.83,0.94,0.97>", desc=" <RGB:0.3,0.4,0.58>", descB=" <RGB:0.2,0.3,0.47>",
}


local function getPriority(item) -- current improv lvl = 0,-1,-2,-3,...; lack skills = 2; inactive = 3; passive = 6; hidden = 7
	local score = 0
	
	score = score-item[4] -- improv level
	if item[6] then score = score+2; end -- missSkills
	if item[5] or item[7] then score = score+4; end -- missLvls or isBlocked
	return score
end

local function getSortedItems(character, invName, improvData, invData, specialMax)
	local impList = LSInventionDefs.Improvements[invName]
	local sortedItems, specialNum = {}, 0
	for i, j in pairs(improvData) do
		if j and impList[i]['special'] and j[1] > 0 then specialNum = specialNum+1; end
	end
	for k, v in pairs(improvData) do
		if v and v[1] and v[2] then
			local isBlocked, isExclusiveWith, missLvls, missSkills, improvLvl = false, false, false, false, 0
			local currentLvl, nextLvl = LSInv.getResearchLevel(improvData, tostring(k), false, 1)
			local isHard = string.find(impList[k]['defs'],"Hard")
			if impList[k]['special'] then
				isExclusiveWith = impList[k]['special'][5]
				local hasExclusive = isExclusiveWith and improvData[isExclusiveWith]
				isBlocked = v[1] == 0 and (specialNum >= specialMax or (hasExclusive and hasExclusive[1] > 0))
				if not isBlocked then
					local res = 0
					for i, j in pairs(improvData) do
						if j and j[1] and j[2] then
							if j[1] >= impList[k]['special'][2] then res = res+1; end
						end
					end
					local hasSpecific = impList[k]['special'][3]
					local speficicImp = hasSpecific and improvData[hasSpecific]
					if impList[k]['special'][1] > res or (speficicImp and speficicImp[1] < impList[k]['special'][4]) then
						missLvls = impList[k]['special']
					end
				end
			end
			if not isBlocked and not missLvls then
				if v[1] < v[2] then -- check if missing skills for next lvl
					local skills = LSInv.getInventionDefinitionsMult(false, nextLvl, impList[k]['defs'], invData, {false, true, false, true})
					for name, lvl in pairs(skills) do
						local skillName = getText("IGUI_perks_"..name)
						local skill = PerkFactory.getPerkFromName(skillName)
						local skillLvl = character:getPerkLevel(skill)
						if skillLvl and lvl and skillLvl < lvl then missSkills = true; break; end
					end
				end
				if not missSkills and v[1] > 0 then improvLvl = currentLvl; end
			end
			table.insert(sortedItems, {v[1],v[2],tostring(k),improvLvl,missLvls,missSkills,isBlocked,impList[k]['special'],nextLvl,isHard,isExclusiveWith})
		end
	end
	table.sort(sortedItems, function(a, b)
		return getPriority(a) < getPriority(b)
	end)
	return sortedItems
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

--[[
function LSResearchMenu:onScrollDoubleClick()
	if not self.ScrollList.selected then return; end
	if self.ScrollList.items[self.ScrollList.selected].item.data.isHidden then
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	elseif not self.confirmationUI then
		self.selectedAmbt = self.ScrollList.items[self.ScrollList.selected].item.data
		self:onClickList()
		if self.IconBtn:isEnabled() then self:onClick(self.IconBtn); end
	end
end
]]--

function LSResearchMenu:onInvPanelConfirmImprov(params)
	self.aboutToClose = true
	if LSUtil.walkToFront(self.character, self.workbench) then
		local workParams = {0,"Research",params[1],params[2],params[3],params[4]}
		local newID = LSInv.getNewID()
		if LSUtil.isValidObj(self.workbench, "workbench") and LSUtil.isObjOnSqr(self.workbench) then
			local spriteName = LSUtil.getObjSpriteName(self.workbench)
			if not LSInv.getWorkbenchEmptySprite(spriteName) then
				ISTimedActionQueue.add(LSIWAddItems:new(self.character, self.workbench, {newID, self.workbench:getModData(), false, spriteName, nil, workParams}))
			end
		end
	end
	self:close()
end

function LSResearchMenu:onClick(button)
	if self.invPanel or button.internal == "Bkg" then return; end
    if button.internal == "Close" or LSUtil.isCharBusy(self.character) or self.character:isAiming() or self.character:isPlayerMoving() or isKeyDown(self.eKey) or isKeyDown(self.sKey) or
	not LSUtil.isValidObj(self.workbench, "workbench") or not LSUtil.isObjOnSqr(self.workbench) then
        self:close()
		return
	end

	if button.internal == "ToProduction" then
		local menu = LSProductionMenu:new(getCore():getScreenWidth()/2-400,getCore():getScreenHeight()/2-200,800,400,{self.character,self.workbench,self.skillLevel,self.knownInventions,self.knownToys,self.spriteName})
		menu:initialise()
		menu:addToUIManager()
        self:close()
		return
	end

	if not self.selectedInv or not self.improvSL.selected then return; end
	local item = self.improvSL.items[self.improvSL.selected]
	if not item then return; end
	local data = item.item.data
	if not data or data[1] >= data[2] then return; end
	
	-- item.item.name - improv name
	-- item.item.inv - inv name
	local params = {item.item.inv,item.item.iso,item.item.name,item.item.invLvl}
	if self.charData['invData'] and self.charData['invData']['lsWkID'] then
		local newPanel = LSResearchInvPanel:new(self, self.selectedInv, self.knownInventions, params, self.menuSkin);
		newPanel:initialise()
		newPanel:addToUIManager()
		self.invPanel = newPanel
		return
	end
	
	self:onInvPanelConfirmImprov(params)
end

local function getInvTexText(inv)
	local tex, text = "", inv.invName
	if inv.invType == "obj" or inv.invType == "invObj" then
		--text = LSUtil.getMoveableDisplayName("name not found", nil, nil, nil, inv.invResult)
		--tex = LSUtil.getObjTexture(inv.invResult, "E")
		tex, text = LSUtil.getObjTexAndText(inv.invResult)
	elseif inv.invType == "item" or inv.invType == "invItem" then
		--tex, text = LSUtil.getItemTexAndText(nil, nil, inv.invResult)
		tex, text = LSUtil.getItemTexAndTextNew(inv.invResult)
	end
	return tex, text
end

function LSResearchMenu:doDrawItem(y, item, alt) -- data = impLvl, impLvlTotal, impName, researchPercent, missLvls, missSkills, isBlocked, isSpecial, isExclusiveWith
	--0.77, 0.87, 0.96
	local data, r, g, b, fontSize, icon, isSelected = item.item.data, 0.8, 0.8, 0.8, getTextManager():getFontFromEnum(self.font):getLineHeight(), false, true	
	local width = self:getWidth()
	if self.selected ~= item.index then r, g, b = 0.4,0.4,0.4; isSelected = false; end

	local specialText_start, specialText_end = "", ""
	if data[8] then
		specialText_start = getText("Tooltip_LSRSM_isSpecial").." <TEXT><LINE>"
		specialText_end = getText("Tooltip_LSRSM_MaxSpecial",self.parent.specialMax)
	end
	if data[11] then
		local incompatibleText = getText("IGUI_Inventions_"..self.parent.selectedInv.invName.."_"..data[11])
		if incompatibleText == "IGUI_Inventions_"..self.parent.selectedInv.invName.."_"..data[11] then incompatibleText = getText("IGUI_Inventions_"..data[11]); end
		if specialText_end ~= "" then specialText_end = specialText_end.." <TEXT><LINE>"; end
		specialText_end = specialText_end..getText("Tooltip_LSRSM_isExclusiveWith")..incompatibleText
	end
	if item.item.isHidden then -- special only, missing skill lvls still render panel
		if data[7] then -- at max special
			item.tooltip = specialText_start..getText("Tooltip_LSRSM_isBlocked").." <LINE>"..specialText_end
			r, g, b = 0.2, 0, 0
		else -- missing imp lvl reqs
			local any = (data[8][1] and getText("Tooltip_LSRSM_isHidden_reqAny",data[8][1],data[8][2]).." <LINE>") or ""
			local specificText
			if data[8][3] then
				specificText = getText("IGUI_Inventions_"..self.parent.selectedInv.invName.."_"..data[8][3])
				if specificText == "IGUI_Inventions_"..self.parent.selectedInv.invName.."_"..data[8][3] then specificText = getText("IGUI_Inventions_"..data[8][3]); end
			end
			local specific = (data[8][3] and "- "..specificText.." "..getText("Tooltip_LSRSM_isHidden_req",data[8][4]).." <LINE>") or ""
			item.tooltip = specialText_start..getText("Tooltip_LSRSM_isHidden").." <LINE>"..any..specific..specialText_end
			r, g, b = 0.1, 0.1, 0.1
		end
	elseif data[8] then -- special and not hidden
		r, g, b = 0.9, 0.85, 0
		if self.selected ~= item.index then r, g, b = 0.6, 0.55, 0; end
		item.tooltip = specialText_start..specialText_end
	else -- not special
		local impText = ((data[3] == "costDecrease" or data[3] == "standardization") and data[3]) or "common"
		item.tooltip = getText("Tooltip_LSRSM_"..impText).." <TEXT><LINE>"..getText("Tooltip_LSRSM_Improvements_"..impText.."_desc")
	end
	local filledDelta = 0
	if data[1] > 0 then
		local filledPercent = math.ceil(LSUtil.getPercentage(data[2],data[1], false, false))
		filledDelta = math.min(1,math.max(0,filledPercent/100))
		local filled = 0
		if filledDelta > 0 then filled = math.max(1, math.min(width,math.floor(filledDelta*width))); end
		self:drawRect(0,y,filled,self.itemheight-1, 0.2, 1-filledDelta, filledDelta, 0)
	end
	local alpha = (not isSelected and item.index%2 == 0 and 0.1) or 0.2
	self:drawRect(0,y,width,self.itemheight-1, alpha, r, g, b)

	r, g, b = 0.2, 0.3, 0.47
	if item.item.isHidden then r, g, b = 0.4, 0.4, 0.4; elseif isSelected then r, g, b = r+0.15, g+0.15, b+0.15; end
	
	self:drawText(item.text, self.itemheight+5, y+(self.itemheight-fontSize)/2, r, g, b, 0.9, self.font)

	local texture = getTexture(item.item.texture)
	if texture then
		local diffRed = (filledDelta == 1 and 0) or 0.1*item.item.diffLevel
		local texR, texG, texB = 1, 1, 1
		if item.item.isHidden then texR, texG, texB = 0, 0, 0; end
		self:drawTextureScaledAspect(texture, 1, y, self.itemheight, self.itemheight, 0.7, texR, texG-diffRed, texB-diffRed)
		--local fireTex = getTexture("media/ui/fire_icon.png")
		local size = self.itemheight/2
		local margin = size/2
		local fireX = (self.itemheight)-size
		if item.item.diffLevel == 0 then texR, texG, texB = 0, 0, 0; end
		for n=1, 3 do
			if item.item.diffLevel ~= 0 and item.item.diffLevel < n then break; end
			self:drawTextureScaledAspect(self.parent.fireTex, fireX, y+self.itemheight-size, size, size, 0.7, texR, texG, texB)
			fireX = fireX-margin
			if item.item.diffLevel < n then break; end
		end
	end

	if not item.item.isHidden and filledDelta == 1 then
		local size = self.itemheight/1.5
		self:drawTextureScaledAspect(getTexture("media/ui/star_icon.png"), width-(size+1), y+(self.itemheight-size)/2, size, size, 0.7, 1, 1, 1)
	end

	return y + self.itemheight
end

local function doTableSort(character, charData, list, invName, invType, invLevel)
	local data = charData['invData'][invName]['improvementData']
	local items = getSortedItems(character,invName,data,charData['invData'][invName]['inventionData'],charData['invData']['specialMax'])
	--must add ishidden stuff for improvements that unlock later on
	for k, v in pairs(items) do
		if v and v[1] and v[2] then
			local customText = getText("IGUI_Inventions_"..invName.."_"..v[3])
			if customText == "IGUI_Inventions_"..invName.."_"..v[3] then customText = getText("IGUI_Inventions_"..v[3]); end
			local num = " ("..tostring(v[1]).."/"..tostring(v[2])..")"
			local difficulty = (v[10] and 1) or 0
			if v[8] then difficulty = difficulty+1; end
			if v[9] > 7 then difficulty = difficulty+2; elseif v[9] > 3 then difficulty=difficulty+1; end
			list:addItem(customText..num, {name=v[3],inv=invName,iso=invType,invLvl=invLevel,isHidden= v[5] or v[7],texture=LSInv.getInvStatIcon(v[3], invName, true),diffLevel=math.min(4,difficulty),data=v})
		end
	end

end

--

function LSResearchMenu:onClickInvSelect(button)
	if self.invPanel then return; end

	local newPanel = LSResearchInvPanel:new(self, self.selectedInv, self.knownInventions, false, self.menuSkin);
	newPanel:initialise()
	newPanel:addToUIManager()
	self.invPanel = newPanel

end

local function clearInfo(self)
	local args = {'infoTitle', 'infoText', 'infoSkills', 'infoRes', 'clockText'}
	self.infoRes.items = nil
	self.infoRes.costs = nil
	for n=1, #args do
		local text = self[args[n]]
		text:setText("")
		text:setVisible(false)
		text:paginate()
	end
	self.researchBtn:setEnable(false)
	self.gadgetBtn:setEnable(false)
	self.gadgetBtn:setVisible(false)
	self.clockBtn:setEnable(false)
end

local function getInventionTooltipDesc(value, totalVal, stringName, color)
	return color .. stringName .. " " .. tostring(value) .. "/" .. tostring(totalVal) .. " <LINE>";
end

local function getCostTextColor(num)
	local color = textColors.ghs
	local t = {
	[2] = textColors.bhs,
	[0.5] = textColors.mhs,
	}
	for k, v in pairs(t) do
		if num >= tonumber(k) then
			color = v
			break
		end
	end
	return color
end

local function getNextInfoResLine(itemString, costLine, group)
	local moduleName, itemType = string.match(itemString, "^([^.]+)%.(.+)$")
	if not itemType then itemType = tostring(itemString); end
	local itemTexture, itemText = LSUtil.getTexIcon(itemType, moduleName)
	if not itemTexture then itemTexture = ""; end
	return itemTexture..getText("IGUI_Inventions_Panel_"..group)..costLine
end

local function getClockMinutes(clockTime, minPerFakeMin)
	local duration = clockTime/48 -- tick to real seconds
	duration = duration/60 -- real min
	duration = duration/minPerFakeMin -- total fake mins
	return LSUtil.round(duration/3, 2)
end

local function doInfo(self)
	-- no improv selected or improv is not for selected invention; clear texts and disable research button
	if not self.improvSL.selected or self.improvSL.items[self.improvSL.selected].item.inv ~= self.selectedInv.invName then
		clearInfo(self)
		return false
	end
	--
	local item = self.improvSL.items[self.improvSL.selected]
	local data = item.item.data
	-- set title
	self.infoTitle:setText("<CENTRE>"..textColors.descB..item.text)
	self.infoTitle:setVisible(true)
	self.infoTitle:paginate()
	-- set description
	local customTextDesc = textColors.descB..getText("IGUI_Inventions_Effects").." <SPACE>"
	local customText = self.selectedInv.invName.."_"
	if getText("IGUI_Inventions_"..customText..item.item.name.."_desc_short") == "IGUI_Inventions_"..customText..item.item.name.."_desc_short" then customText = ""; end
	
	customTextDesc = customTextDesc..textColors.desc..getText("IGUI_Inventions_"..customText..item.item.name.."_desc_short").." <BR>"..
	getText("IGUI_Inventions_"..customText..item.item.name.."_desc")

	self.infoText:setText(customTextDesc)
	self.infoText:setVisible(true)
	self.infoText:paginate()
	-- if improv level is same or (somehow) higher than max improv level then we skip skills and res requirements; we disable the research button
	local skillText, resText, timeText = "", "", ""
	if data[1] >= data[2] then
		self.infoSkills:setText(skillText)
		self.infoSkills:setVisible(false)
		self.infoSkills:paginate()
		self.infoRes.items = nil
		self.infoRes.costs = nil
		self.infoRes:setText(resText)
		self.infoRes:setVisible(false)
		self.infoRes:paginate()
		self.clockText:setText(timeText)
		self.clockText:setVisible(false)
		self.clockText:paginate()
		return false
	end
	--
	local enable = true
	local improvLevel, nextLevel = LSInv.getResearchLevel(self.charData['invData'][self.selectedInv.invName]['improvementData'], item.item.name, false, 1)
	if improvLevel >= 10 then enable = false; end -- impLevel failsafe
	local defs = LSInventionDefs.Improvements[self.selectedInv.invName][item.item.name]['defs']
	local inventionData = self.charData['invData'][self.selectedInv.invName]['inventionData']
	local t = LSInv.getInventionDefinitionsMult(false, nextLevel, defs, inventionData, {false, true})
	local skillCost, costList = t.reqSkills, t.reqRes
	-- research skill cost, we give the exact values; if higher than character's skill then we disable research button
	skillText = textColors.descB.." <CENTRE>"..getText("IGUI_Inventions_SkillReq").." <BR><LEFT>"
	for k, v in pairs(skillCost) do
		local color = textColors.ghs
		local skillName = getText("IGUI_perks_"..k)
		local skill = PerkFactory.getPerkFromName(skillName)
		local skillLvl = self.character:getPerkLevel(skill)
		if skillLvl < v then enable = false; if skillLvl < v/2 then color = textColors.bhs; else color = textColors.mhs; end; end
		skillText = skillText .. "<RGB:1,1,1>" .. LSUtil.getSkillIcon(k)..skillName .. ": <SPACE>" .. color .. tostring(skillLvl) .. "/" .. tostring(v) .. " <LINE>"
	end
	self.infoSkills:setText(skillText)
	self.infoSkills:setVisible(true)
	self.infoSkills:paginate()
	-- eventual material costs, given as estimates (~X number); we don't check items on player as research phase 1 has no costs

	--resText = textColors.descB.." <CENTRE>"..getText("IGUI_Inventions_CostEst").." <BR><LEFT>"
	local costs = {base=0,connector=0,parts=0,upgrades=0}
	self.infoRes.items = LSInv.getResearchGroupedItems(defs, nextLevel)
	for k, v in pairs(costList) do
		local found
		for i, j in pairs(self.infoRes.items) do
			for n=1,#j do
				local itemName = j[n]
				if itemName == k then
					costs[i] = costs[i]+v
					found = true
					break
				end
				if found then break; end
			end
		end
	end
	local costMult = inventionData['costPenalty']/inventionData['costDecrease']
	local color = getCostTextColor(costMult)
	self.infoRes.costs = {}
	for k, v in pairs(costs) do
		local estimate = 0
		if v > 0 then
			local estA, estB = math.ceil(v/1.6), math.floor(v*1.7)
			local estTxt = (estA ~= estB and " <SPACE>"..tostring(estA)) or " <SPACE>"
			estimate = estTxt.." ~ "..tostring(estB)
		end
		self.infoRes.costs[k] = ": <SPACE>".. color .. estimate .. " <LINE>"
	end
	
	local newText = self.infoRes.startText
	for k, v in pairs(self.infoRes.items) do
		newText = newText.."<RGB:1,1,1>"..getNextInfoResLine(v[ZombRand(#v)+1], self.infoRes.costs[k], tostring(k))
	end

	newText = newText.."<RGB:0.8,0.8,0.8>"..self.infoRes.endText
	--[[
	for k, v in pairs(costList) do
		local moduleName, itemType = string.match(k, "^([^.]+)%.(.+)$")
		if not itemType then itemType = tostring(k); end
		local itemTexture, itemText = LSUtil.getTexIcon(itemType, moduleName)
		if not itemTexture then itemTexture = ""; end
		local estimate = " <SPACE>"..tostring(math.ceil(v/1.6)).." ~ "..tostring(math.floor(v*1.7))
		resText = resText .. "<RGB:1,1,1>" .. itemTexture..itemText .. ": <SPACE>".. color .. estimate .. " <LINE>"
	end
	]]--
	self.infoRes:setText(newText)
	self.infoRes:setVisible(true)
	self.infoRes:paginate()

	self.clockTime = InventionsMenu.workbench.getResearchDuration(self.charData['invData'],self.skillLevel,{1, false, self.selectedInv.invName, false, item.item.name})+InventionsMenu.workbench.getResearchDuration(self.charData['invData'],self.skillLevel,{2, false, self.selectedInv.invName, false, item.item.name})
	local duration = self.clockTime
	if self.clockBtn.internal == "GameMinutes" then duration = getClockMinutes(self.clockTime,self.minPerFakeMin); end
	timeText = textColors.descB.."~"..duration.." <SPACE>"..getText("IGUI_Inventions_"..self.clockBtn.internal)

	self.clockText:setText(timeText)
	self.clockText:setVisible(true)
	self.clockText:paginate()

	return enable
end

function LSResearchMenu:onClickClock(button)
	if self.invPanel or not self.clockTime then return; end
	local duration = self.clockTime
	if button.internal == "Ticks" then
		button.internal = "GameMinutes"
		duration = getClockMinutes(self.clockTime,self.minPerFakeMin)
	else
		button.internal = "Ticks"
	end
	local timeText = textColors.descB.."~"..duration.." <SPACE>"..getText("IGUI_Inventions_"..button.internal)
	self.clockText:setText(timeText)
	self.clockText:setVisible(true)
	self.clockText:paginate()
	button:setTooltip(getText("Tooltip_LSRSM_ClockBtn_"..button.internal))
end

local function doResClockBtns(self, enable)
	local resTooltipTxt = "Tooltip_LSRSM_ResBtn"
	local clockTooltipTxt = "Tooltip_LSRSM_ClockBtn_"..self.clockBtn.internal
	if not enable then resTooltipTxt = resTooltipTxt.."Off_a"; clockTooltipTxt = resTooltipTxt; end
	if self.objData and not self.objData['author'] then self.researchBtn:setTooltip(getText(resTooltipTxt)); self.clockBtn:setTooltip(getText(clockTooltipTxt));
	self.researchBtn:setEnable(enable); self.clockBtn:setEnable(enable); end
	self.gadgetBtn:setEnable(true)
	self.gadgetBtn:setVisible(true)
end

function LSResearchMenu:onInvPanelConfirm(inv)
	self.selectedInv = inv

	local tex, name = getInvTexText(self.selectedInv)
	self.sIName:setText(textColors.descB.."<IMAGE:"..LSUtil.fixTexIconPath(tex:getName())..",28,28>"..name)
	self.sIName:paginate()

	self.improvSL:clear()
	doTableSort(self.character, self.charData, self.improvSL, self.selectedInv.invName, self.selectedInv.invType, self.selectedInv.level)
	self.improvSL.selected = 1

	local enable = doInfo(self)
	doResClockBtns(self, enable)
end

function LSResearchMenu:onScrollClick()
	if not self.improvSL.selected or self.invPanel then return; end
	if self.improvSL.items[self.improvSL.selected].item.isHidden then
		getSoundManager():playUISound("UI_DJBooth_ERROR")
		clearInfo(self)
		return
	end

	local enable = doInfo(self)
	doResClockBtns(self, enable)
end

function LSResearchMenu:initialise()

	--local mediumTextHeight = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
	local mediumNewTextHeight = getTextManager():getFontFromEnum(UIFont.MediumNew):getLineHeight()
	local smallTextHeight = getTextManager():getFontFromEnum(UIFont.NewSmall):getLineHeight()

	self.BackgroundImage = doImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LSRSM/"..self.menuSkin.."/LSRSMBKG.png"))
	self.BackgroundImage:initialise()
	self:addChild(self.BackgroundImage)

	self.bkgBtn = ISButton:new(0,0,self:getWidth(),self:getHeight(), "", self, self.onClick, self.onBtnMouseDown)
	self.bkgBtn.internal = "Bkg"
	self.bkgBtn:initialise()
	self.bkgBtn:instantiate()
	self.bkgBtn.displayBackground = false
	self.bkgBtn.borderColor = {r=1, g=1, b=1, a=0}
	self:addChild(self.bkgBtn)

	self.selectedInv = self.knownInventions[1]
	local tex, name = getInvTexText(self.selectedInv)
	--self.knownInventions[1].invName

	self.sIName = doRichTextType(25, 18, 215, 28,textColors.descB.."<IMAGE:"..LSUtil.fixTexIconPath(tex:getName())..",28,28>"..name,UIFont.Large)
    self.sIName.clip = true
	self.sIName:initialise()
	self.sIName:instantiate()
	self.sIName:paginate();
	self:addChild(self.sIName)

	self.uiBtns.sIBtn = {on=getTexture("media/textures/LSRSM/"..self.menuSkin.."/InvSelect_On.png"), off=getTexture("media/textures/LSRSM/"..self.menuSkin.."/InvSelect_Off.png")}
	self.sIBtn = ISButton:new(14, 14, 237, 36, "", self, self.onClickInvSelect)
	self.sIBtn.internal = "Next"
	self.sIBtn:initialise()
	self.sIBtn:instantiate()
	self.sIBtn.displayBackground = false
	self.sIBtn.borderColor = {r=1, g=1, b=1, a=0};
	self.sIBtn:setImage(self.uiBtns.sIBtn.off)
	--self.sIBtn:setTooltip(getText("Tooltip_LSABTM_PlaylistSelect"))
	self:addChild(self.sIBtn)

    self.improvSL = ISScrollingListBox:new(25, 67, 270, 264);
	self.improvSL:setOnMouseDownFunction(self, self.onScrollClick)
	--self.improvSL:setOnMouseDoubleClick(self, self.onScrollDoubleClick)
	self.improvSL.doDrawItem = LSResearchMenu.doDrawItem
	self.improvSL.backgroundColor = {r=0, g=0, b=0, a=0};
	self.improvSL.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.improvSL:noBackground();
	--self.improvSL.altBgColor = {r=0.2, g=0.3, b=0.2, a=0}
	--self.improvSL.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.improvSL.font = UIFont.MediumNew
	--self.improvSL.itemPadY = 4
	self.improvSL.fontHgt = mediumNewTextHeight
	self.improvSL.itemheight = 32
    self.improvSL:initialise();
    self.improvSL:instantiate();
	self.improvSL.vscroll.backgroundColor = {r=0, g=0, b=0, a=0}
	self.improvSL.vscroll.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	self.improvSL.vscroll.uptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnUP.png")
	self.improvSL.vscroll.downtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnDOWN.png")
	self.improvSL.vscroll.toptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barTOP.png")
	self.improvSL.vscroll.midtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barMID.png")
	self.improvSL.vscroll.bottex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barBOT.png")
   -- self.improvSL:addScrollBars();
    self:addChild(self.improvSL);
	
	doTableSort(self.character, self.charData, self.improvSL, self.selectedInv.invName, self.selectedInv.invType, self.selectedInv.level)

	local item = self.improvSL.items[self.improvSL.selected]
	local defs = LSInventionDefs.Improvements[self.selectedInv.invName][item.item.name]['defs']
	local improvLevel, nextLevel = LSInv.getResearchLevel(self.charData['invData'][self.selectedInv.invName]['improvementData'], item.item.name, false, 1)

	self.infoTitle = doRichTextType(315, 64, 463, 33,"none",UIFont.Large)
	self.infoTitle:initialise()
	self.infoTitle:instantiate()
	self.infoTitle:paginate();
	self.infoTitle:setVisible(false)
	self:addChild(self.infoTitle)

	self.infoText = doRichTextType(self.textX, self.textY, 449, self.textH,"none",UIFont.NewSmall)
	self.infoText.maxLines = math.floor(150 / smallTextHeight)
	self.infoText:initialise()
	self.infoText:instantiate()
	self.infoText:paginate();
	self.infoText:setVisible(false)
	self:addChild(self.infoText)

	self.infoSkills = doRichTextType(self.textX, 270, 218, 108,"none",UIFont.NewSmall)
	self.infoSkills.maxLines = math.floor(106 / smallTextHeight)
	self.infoSkills:initialise()
	self.infoSkills:instantiate()
	self.infoSkills:paginate();
	self.infoSkills:setVisible(false)
	self:addChild(self.infoSkills)

	self.infoRes = doRichTextType(553, 270, 218, 108,"none",UIFont.NewSmall)
	self.infoRes.maxLines = math.floor(106 / smallTextHeight)
	self.infoRes.startText = textColors.descB.." <CENTRE>"..getText("IGUI_Inventions_CostEst").." <BR><LEFT>"
	self.infoRes.endText = "*"..getText("IGUI_Inventions_CostEstFN")
	self.infoRes.items = LSInv.getResearchGroupedItems(defs, nextLevel)
	self.infoRes:initialise()
	self.infoRes:instantiate()
	self.infoRes:paginate();
	self.infoRes:setVisible(false)
	self:addChild(self.infoRes)

	self.uiBtns.CloseButton = {on=getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close_On.png"), off=getTexture("media/textures/LSRSM/"..self.menuSkin.."/Close.png")}
    self.CloseButton = ISButton:new(0, 0, 22, 22, "", self, self.onClick);
    self.CloseButton.internal = "Close";
	--self.CloseButton:setTooltip(getText("Tooltip_LSAM_CloseSimple"))
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(self.uiBtns.CloseButton.off)
    self:addChild(self.CloseButton);

	self.researchText = doRichTextType(38, 356, 120, 26,textColors.desc.." <CENTRE>"..getText("IGUI_Inventions_StartRes"),UIFont.Medium)
	--self.researchText.maxLines = math.floor(24 / mediumNewTextHeight)
	self.researchText:initialise()
	self.researchText:instantiate()
	self.researchText:paginate();
	self:addChild(self.researchText)

	local resTooltipTxt = "_a"
	if self.objData and self.objData['author'] then resTooltipTxt = "_b"; end

	self.uiBtns.researchBtn = {on=getTexture("media/textures/LSRSM/"..self.menuSkin.."/ResBtn_On.png"), off=getTexture("media/textures/LSRSM/"..self.menuSkin.."/ResBtn.png"), dis=getTexture("media/textures/LSRSM/"..self.menuSkin.."/ResBtn_Dis.png")}
	self.researchBtn = ISButton:new(27, 345, 142, 44, "", self, self.onClick)
	self.researchBtn.internal = "Confirm"
	self.researchBtn:setTooltip(getText("Tooltip_LSRSM_ResBtnOff"..resTooltipTxt))
	self.researchBtn:initialise(); self.researchBtn:instantiate()
	self.researchBtn.displayBackground = false
	self.researchBtn.borderColor = {r=1, g=1, b=1, a=0};
	self.researchBtn:setImage(self.uiBtns.researchBtn.off)
	self.researchBtn:setEnable(false)
	self:addChild(self.researchBtn)

	self.clockText = doRichTextType(202, 356, 90, 22,"",UIFont.Medium)
	--self.clockText.maxLines = math.floor(24 / mediumNewTextHeight)
	self.clockText:initialise()
	self.clockText:instantiate()
	self.clockText:paginate();
	self:addChild(self.clockText)

	self.uiBtns.clockBtn = {on=getTexture("media/textures/LSRSM/"..self.menuSkin.."/clockBtn_On.png"), off=getTexture("media/textures/LSRSM/"..self.menuSkin.."/clockBtn.png"), dis=getTexture("media/textures/LSRSM/"..self.menuSkin.."/clockBtn_Dis.png")}
	self.clockBtn = ISButton:new(169, 351, 30, 32, "", self, self.onClickClock)
	self.clockBtn.internal = "Ticks"
	self.clockBtn:setTooltip(getText("Tooltip_LSRSM_ResBtnOff_a"))
	self.clockBtn:initialise(); self.clockBtn:instantiate()
	self.clockBtn.displayBackground = false
	self.clockBtn.borderColor = {r=1, g=1, b=1, a=0};
	self.clockBtn:setImage(self.uiBtns.clockBtn.off)
	self.clockBtn:setEnable(false)
	self.clockBtn.sounds.activate = "UI_Button_SELECT"
	self:addChild(self.clockBtn)

	self.uiBtns.gadgetBtn = {on=getTexture("media/textures/LSRSM/"..self.menuSkin.."/ResBtn_On.png"), off=getTexture("media/textures/LSRSM/"..self.menuSkin.."/ResBtn_Off.png")}
	self.gadgetBtn = ISButton:new(629, 213, 142, 44, getText("ContextMenu_Inventions_Production"), self, self.onClick)
	self.gadgetBtn.internal = "ToProduction"
	self.gadgetBtn:setTooltip(getText("Tooltip_LSRSM_ToProduction"))
	self.gadgetBtn:initialise(); self.gadgetBtn:instantiate()
	self.gadgetBtn.displayBackground = false
	self.gadgetBtn.textColor = {r=0.3, g=0.4, b=0.58, a=1.0}
	self.gadgetBtn.borderColor = {r=1, g=1, b=1, a=0}
	self.gadgetBtn.font = UIFont.Medium
	self.gadgetBtn:setImage(self.uiBtns.gadgetBtn.off)
	self.gadgetBtn:setEnable(false)
	self.gadgetBtn:setVisible(false)
	self:addChild(self.gadgetBtn)

	local enable = doInfo(self)
	doResClockBtns(self, enable)

end

function LSResearchMenu:update()
	if self.aboutToClose then return; end
	-- player check
	if self.count%5 == 0 and (LSUtil.isCharBusy(self.character) or self.character:isAiming() or self.character:isPlayerMoving() or isKeyDown(self.eKey) or isKeyDown(self.sKey)) then self:close(); end
	
	if self.count%15 == 0 and self.infoRes:getIsVisible() and self.infoRes.items and self.infoRes.costs and self.improvSL.selected then
		local newText = self.infoRes.startText
		for k, v in pairs(self.infoRes.items) do
			newText = newText.."<RGB:1,1,1>"..getNextInfoResLine(v[ZombRand(#v)+1], self.infoRes.costs[k], tostring(k))
		end
		newText = newText.."<RGB:0.8,0.8,0.8>"..self.infoRes.endText
		self.infoRes:setText(newText)
		self.infoRes:paginate()
	end
	
	if self.count >= 300 then
		if not LSUtil.isValidObj(self.workbench, "workbench") or not LSUtil.isObjOnSqr(self.workbench) then self:close(); end
		self.count = 0
	end
	self.count = self.count+1
	if self.invPanel then return; end

	for k, v in pairs(self.uiBtns) do
		if self[k].enable and self[k].mouseOver then
			if self[k].image ~= v.on then
				self[k]:setImage(v.on)
			end
		elseif v.dis and not self[k].enable then
			if self[k].image ~= v.dis then
				self[k]:setImage(v.dis)
			end
		elseif self[k].image ~= v.off then
			self[k]:setImage(v.off)
		end
	end

end

function LSResearchMenu:render()

	local item = self.improvSL and self.improvSL.items and self.improvSL.items[self.improvSL.selected]
	if item and not item.item.isHidden then
		local texR, texG, texB = 1, 1, 1
		local margin = self.mediumFontHeight
		local fireX = self.textX
		local fireY = self.textY+self.textH+(self.mediumFontHeight/2)
		--if item.item.diffLevel == 0 then texR, texG, texB = 0, 0, 0; end
		for n=1, 3 do
			if texR > 0 and item.item.diffLevel < n then texR, texG, texB = 0, 0, 0; end
			self:drawTextureScaledAspect(self.fireTex, fireX, fireY, self.mediumFontHeight, self.mediumFontHeight, 0.7, texR, texG, texB)
			fireX = fireX+margin
		end
		local difficulty = math.min(1,(item.item.diffLevel*0.2)+0.2)
		self:drawText("("..getText("IGUI_Inventions_Difficulty_"..tostring(item.item.diffLevel))..")", fireX+2, fireY, difficulty, 1-difficulty, 0, 0.7, UIFont.Medium)
	end

	ISPanelJoypad.render(self);
end

function LSResearchMenu:close()
	if self.invPanel then
		self.invPanel:setVisible(false);
		self.invPanel:removeFromUIManager();
	end
	self.improvSL:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSResearchMenu:destroy()
	if self.invPanel then
		self.invPanel:setVisible(false);
		self.invPanel:removeFromUIManager();
	end
	self.improvSL:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSResearchMenu:onBtnMouseDown(x, y)
    if self.invPanel or not self.moveWithMouse or not self:getIsVisible() or not self:isMouseOver() then return; end    
    self.downX = x;
    self.downY = y;
    self.moving = true;
    self:bringToTop();
end

function LSResearchMenu:new(X, Y, Width, Height, args) -- character,workbench,skillLevel,knownInventions,knownToys,spriteName
	local o = ISPanelJoypad:new(X, Y, Width, Height)
	setmetatable(o, self)
	self.__index = self
	o.uiX = X
	o.uiY = Y
	o.character = args[1]
	o.charData = o.character and o.character:getModData()
	o.specialMax = o.charData and o.charData['invData']['specialMax']
	o.workbench = args[2]
	o.objData = o.workbench and o.workbench:getModData()
	o.skillLevel = args[3]
	o.knownInventions = args[4]
	o.knownToys = args[5]
	o.spriteName = args[6]
	o.eKey = getCore():getKey("Emote")
	o.sKey = getCore():getKey("Shout")
	o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.98}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.invPanel = false
	o:noBackground()
	--o.anchorLeft = true;
	--o.anchorRight = true;
	--o.anchorTop = true;
	--o.anchorBottom = true;
	o.panelH = Height
	o.panelW = Width
	if not o.charData['LSUISkins'] then o.charData['LSUISkins'] = {}; end
	o.menuSkin = o.charData['LSUISkins']['LSResearchMenu'] or "LSSims"
	o.moveWithMouse = true
	o.count = 0
	o.uiBtns = {}
	local minPerFakeHour = getSandboxOptions():getDayLengthMinutes()/24
	o.minPerFakeMin = minPerFakeHour/60
	o.mediumFontHeight = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
	o.textX = 322
	o.textY = 106
	o.textH = 106
	o.fireTex = getTexture("media/ui/fire_icon.png")
	return o
end





