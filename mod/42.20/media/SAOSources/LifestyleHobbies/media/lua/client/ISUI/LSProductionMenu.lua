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

LSProductionMenu = ISPanel:derive("LSProductionMenu")
local textColors = {
		bhs=" <RGB:0.5,0,0>",mhs=" <RGB:0.5,0.5,0>",ghs=" <RGB:0,0.5,0>",
		title=" <RGB:0.83,0.94,0.97>", desc=" <RGB:0.3,0.4,0.58>", descB=" <RGB:0.2,0.3,0.47>",
		yhs=" <RGB:1,1,0>", faded=" <RGB:0.6,0.7,0.75>",
}

local groupRef = {
	Gadgets = "media/ui/IW_icon.png",
	Curios = "media/ui/gfclock_icon.png",
	Toys = "media/ui/toy_icon.png",
	Costumes = "media/ui/clothes_formal_icon.png",
}

local function getPriority(item) -- current improv lvl = 0,-1,-2,-3,...; lack skills = 2; inactive = 3; passive = 6; hidden = 7
	local invInfo = item[1]
	local score = 0
	score = score-invInfo.level -- level
	if item[2] then score = score-10; end -- new (recently created should always appear at the top)
	return score
end

local function getSortedItems(charInvData, group, list)
	local sortedItems = {}
	local worldHours = getGameTime():getWorldAgeHours()
	for k, v in pairs(list) do
		if (v.group and v.group == group) or group == "Gadgets" then
			local invData = charInvData[v.invName]
			local isNew = invData['lastCreated'] and invData['lastCreated']+72 > worldHours
			local numCreated = invData['numCreated'] or 0
			table.insert(sortedItems, {v, isNew, numCreated})
		end
	end
	if #sortedItems < 2 then return sortedItems; end
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
function LSProductionMenu:onScrollDoubleClick()
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

function LSProductionMenu:onInvPanelConfirmInv(params, cost)
	self.aboutToClose = true
	if LSUtil.walkToFront(self.character, self.workbench) then
		local workParams = {0,"Production",params.invName,params.invType,params.invResult,params.level}
		local newID = LSInv.getNewID()
		if LSUtil.isValidObj(self.workbench, "workbench") and LSUtil.isObjOnSqr(self.workbench) then
			local spriteName = LSUtil.getObjSpriteName(self.workbench)
			if not LSInv.getWorkbenchEmptySprite(spriteName) then
				ISTimedActionQueue.add(LSIWAddItems:new(self.character, self.workbench, {newID, self.workbench:getModData(), cost, spriteName, nil, workParams}))
			end
		end
	end
	self:close()
end

function LSProductionMenu:onClick(button)
	if self.invPanel or button.internal == "Bkg" then return; end
    if button.internal == "Close" or LSUtil.isCharBusy(self.character) or self.character:isAiming() or self.character:isPlayerMoving() or isKeyDown(self.eKey) or isKeyDown(self.sKey) or
	not LSUtil.isValidObj(self.workbench, "workbench") or not LSUtil.isObjOnSqr(self.workbench) then
        self:close()
		return
	end

	if button.internal == "ToResearch" then
		local menu = LSResearchMenu:new(getCore():getScreenWidth()/2-400,getCore():getScreenHeight()/2-200,800,400,{self.character,self.workbench,self.skillLevel,self.knownInventions,self.knownToys,self.spriteName})
		menu:initialise()
		menu:addToUIManager()
        self:close()
		return
	end

	if not self.selectedGroup or not self.productionSL.selected then return; end
	local item = self.productionSL.items[self.productionSL.selected]
	if not item or not item.item.data then return; end
	local cost = item.item.cost

	local params = item.item.data
	if self.charData['invData'] and self.charData['invData']['lsWkID'] then
		local newPanel = LSProductionInvPanel:new(self, nil, nil, nil, cost, params, self.menuSkin);
		newPanel:initialise()
		newPanel:addToUIManager()
		self.invPanel = newPanel
		return
	end
	
	self:onInvPanelConfirmInv(params, cost)
end

local function getInvTexText(inv)
	local tex, text = "", inv.invName
	if inv.invType == "obj" or inv.invType == "invObj" then
		--text = LSUtil.getMoveableDisplayName("name not found", nil, nil, nil, inv.invResult)
		--tex = LSUtil.getObjTexture(inv.invResult, "E")
		tex, text = LSUtil.getObjTexAndText(inv.invResult)
		if inv.invResult == "LS_Inventions_12" then -- drinking buddy
			local sprite = getTexture("LS_Inventions_32")
			if sprite then tex = sprite:splitIcon(); end
		end
	elseif inv.invType == "item" or inv.invType == "invItem" then
		--tex, text = LSUtil.getItemTexAndText(nil, nil, inv.invResult)
		tex, text = LSUtil.getItemTexAndTextNew(inv.invResult)
	end
	return tex, text
end

function LSProductionMenu:doDrawItem(y, item, alt) -- data = impLvl, impLvlTotal, impName, researchPercent, missLvls, missSkills, isBlocked, isSpecial
	--0.77, 0.87, 0.96
	local data, r, g, b, fontSize, icon, isSelected = item.item.data, 0.8, 0.8, 0.8, getTextManager():getFontFromEnum(self.font):getLineHeight(), false, true	
	local width = self:getWidth()
	if self.selected ~= item.index then r, g, b = 0.4,0.4,0.4; isSelected = false; end
	local alpha = (not isSelected and item.index%2 == 0 and 0.1) or 0.2
	self:drawRect(0,y,width,self.itemheight-1, alpha, r, g, b)

	r, g, b = 0.2, 0.3, 0.47
	if isSelected then r, g, b = r+0.15, g+0.15, b+0.15; end
	
	self:drawText(item.text, self.itemheight+5, y+(self.itemheight-fontSize)/2, r, g, b, 0.9, self.font)

	local texture = item.item.texture
	if texture then
		r, g, b = 0.9, 0.9, 0.9
		if item.item.isHidden then r, g, b = 0, 0, 0; end
		self:drawTextureScaledAspect(texture, 1, y, self.itemheight, self.itemheight, 0.7, r, g, b)
	end

	return y + self.itemheight
end

function LSProductionMenu:doDrawSmallItem(y, item, alt) -- data = impLvl, impLvlTotal, impName, researchPercent, missLvls, missSkills, isBlocked, isSpecial
	local alpha = (item.index%2 == 0 and 0) or 0.05
	local data = item.item
	self:drawRect(0+2,y,self.width-2,self.itemheight-1, alpha, 0, 0, 0)
	if data.texture then
		self:drawTextureScaledAspect(data.texture, 1, y, 16, 16, 0.7, 0.9, 0.9, 0.9)
	end
	self:drawText(item.text, self.itemheight, y+(self.itemheight-self.fontHgt)/2, data.colorLeft[1], data.colorLeft[2], data.colorLeft[3], data.colorLeft[4], self.font)
	self:drawText(data.textRight, data.textWidthR, y+(self.itemheight-self.fontHgt)/2, data.colorRight[1], data.colorRight[2], data.colorRight[3], data.colorRight[4], self.font)
	return y + self.itemheight
end

local function doTableSort(charInvData, scrollList, group, invList, toysList)
	local list = (group == "Gadgets" and invList) or toysList
	local items = getSortedItems(charInvData,group,list)

	for k, v in pairs(items) do
		local invInfo = v and v[1]
		if invInfo then
			local projName, projTex, projDesc = false, false, "Tooltip_Inventions_"..invInfo.invName.."_desc"
			if invInfo.invType == "obj" or invInfo.invType == "invObj" then
				projName = LSUtil.getMoveableDisplayName(invInfo.invName, nil, nil, nil, invInfo.invResult)
				local textureName = (invInfo.invResult == "LS_Inventions_12" and "LS_Inventions_32") or invInfo.invResult
				local texture = getTexture(textureName)
				if texture then projTex = texture:splitIcon(); end
			else
				projTex, projName = LSUtil.getItemTexAndTextNew(invInfo.invResult)
			end
			if getText(projDesc) == "Tooltip_Inventions_"..invInfo.invName.."_desc" then projDesc = "Tooltip_Inventions_"..group.."_desc"; end
			local projCost = invInfo.cost or charInvData[invInfo.invName]['workCost']
			
			scrollList:addItem(projName, {name=projName,desc=projDesc,inv=invInfo.invName,iso=invInfo.invType,isNew=v[2],numCreated=v[3],cost=projCost,texture=projTex,data=invInfo})
		end
	end

end

--

function LSProductionMenu:onClickGroupSelect(button)
	if self.invPanel then return; end

	if not self.knownGroups then
		self.knownGroups = {}
		if self.knownInventions and #self.knownInventions > 0 then table.insert(self.knownGroups, "Gadgets"); end
		if self.knownToys and #self.knownToys > 0 then
			local seen = {}
			for k, v in pairs(self.knownToys) do
				if v and v.group and not seen[v.group] then table.insert(self.knownGroups, v.group); seen[v.group]=true; end
			end
		end
	end

	local newPanel = LSProductionInvPanel:new(self, self.selectedGroup, self.knownGroups, groupRef, nil, nil, self.menuSkin);
	newPanel:initialise()
	newPanel:addToUIManager()
	self.invPanel = newPanel

end

local function clearInfo(self)
	local args = {'infoTitle', 'infoText', 'resTitle', 'clockText'}
	self.infoRes.items = nil
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

local function getSpacing(font, widthMax, text)
	local stringWidth = getTextManager():MeasureStringX(font, text)
	local spacing = stringWidth+22
	return math.floor(widthMax-spacing)
end

local function getNextInfoResLine(ui, fullType, cost)
	local itemTexture, itemText = LSUtil.getItemTexAndTextNew(fullType)
	if not itemTexture then itemTexture = ""; end
	local text = tostring(cost)
	local spacing = getSpacing(ui.font, ui.width, text)
	return itemTexture..itemText..":"..spacing.. textColors.descB .. text
end

local stats_ref = {
	-- common
	invLevel = {text="IGUI_Inventions_Stats_Level",tex="media/ui/star_icon.png",cL={0.3,0.4,0.58,0.9},cR={1,1,0,0.9}},
	numCreated = {text="IGUI_Inventions_Stats_NumCreated",tex="media/ui/maintenance_icon.png",cL={0.3,0.4,0.58,0.9},cR={1,1,0,0.9}},
	category = {text="IGUI_invpanel_Category",tex="media/ui/bookWrite_icon.png",cL={0.3,0.4,0.58,0.9},cR={0.7,0.35,0,0.9}},
}

local function getPanelStatsText(ui, invData, invInfo, isGadget)
	local t = {}
	if not invData then return t; end
	local item = (invInfo.invType == "item" or invInfo.invType == "invItem") and getScriptManager():FindItem(invInfo.invResult)
	local level = invInfo.level or 0
	local dataR = {
		invLevel = tostring(level),
		numCreated = tostring(invData['numCreated'] or 0),
		category = (item and item:getDisplayCategory()) or getText("IGUI_ItemCat_Furniture"),
	}
	stats_ref.invLevel.cR = {1,1,0,math.max(0.2,(level*0.1))}
	
	for k, v in pairs(stats_ref) do
		table.insert(t, {itemText=getText(v.text),texture=getTexture(v.tex),colorLeft=v.cL,colorRight=v.cR,textRight=dataR[k],textWidthR=getSpacing(ui.font, ui.width, dataR[k])})
	end

	return t
end

local function getClockMinutes(clockTime, minPerFakeMin)
	local duration = clockTime/48 -- tick to real seconds
	duration = duration/60 -- real min
	duration = duration/minPerFakeMin
	return LSUtil.round(duration/3, 2)
end

local function doInfo(self)
	-- no inv selected or inv is not from current group; clear texts and disable production button
	local isGadget, invGroup, item, data
	if self.productionSL.selected then
		item = self.productionSL.items[self.productionSL.selected]
		data = item.item.data
		isGadget = LSUtil.StringStartWith(item.item.iso,"inv")
		invGroup = (isGadget and "Gadgets") or data.group or "Toys"
	end
	if not self.productionSL.selected or invGroup ~= self.selectedGroup then
		clearInfo(self)
		return false, false
	end
	-- set title
	self.infoTitle:setText("<CENTRE>"..textColors.descB..item.text)
	self.infoTitle:setVisible(true)
	self.infoTitle:paginate()
	-- set description
	local customTextDesc = textColors.descB..getText(item.item.desc).." <BR>"..textColors.desc..getText("IGUI_Inventions_Panel_"..invGroup)

	self.infoText:setText(customTextDesc)
	self.infoText:setVisible(true)
	self.infoText:paginate()

	--
	-- research skill cost, we give the exact values; if higher than character's skill then we disable research button
	local statsItems = getPanelStatsText(self.statsSL, self.charData['invData'][item.item.inv], data, isGadget)
	for n=1,#statsItems do
		local stats = statsItems[n]
		self.statsSL:addItem(stats.itemText..":", stats)
	end

	for k, v in pairs(item.item.cost) do
		local itemTexture, itemText = LSUtil.getItemTexAndTextNew(tostring(k))
		local itemCost = tostring(v)
		local widthR = getSpacing(self.resSL.font, self.resSL.width, itemCost)
		local costAlpha = math.min(1,0.5+v/100)
		self.resSL:addItem(itemText..":", {texture=itemTexture,colorLeft={1,1,1,0.9},colorRight={0.3,0.4,0.58,costAlpha},textRight=itemCost,textWidthR=widthR})
	end

	self.statsTitle:setText(self.statsTitle.startText)
	self.statsTitle:setVisible(true)
	self.statsTitle:paginate()

	self.resTitle:setText(self.resTitle.titleTxt)
	self.resTitle:setVisible(true)
	self.resTitle:paginate()

	self.clockTime = InventionsMenu.workbench.getProductionDuration(self.charData['invData'],self.skillLevel,{nil, nil, data.invName, data.invType})
	local duration = self.clockTime
	if self.clockBtn.internal == "GameMinutes" then duration = getClockMinutes(self.clockTime,self.minPerFakeMin); end
	local timeText = textColors.descB..duration.." <SPACE>"..getText("IGUI_Inventions_"..self.clockBtn.internal)

	self.clockText:setText(timeText)
	self.clockText:setVisible(true)
	self.clockText:paginate()

	return true, isGadget
end

function LSProductionMenu:onClickClock(button)
	if self.invPanel or not self.clockTime then return; end
	local duration = self.clockTime
	if button.internal == "Ticks" then
		button.internal = "GameMinutes"
		duration = getClockMinutes(self.clockTime,self.minPerFakeMin)
	else
		button.internal = "Ticks"
	end
	local timeText = textColors.descB..duration.." <SPACE>"..getText("IGUI_Inventions_"..button.internal)
	self.clockText:setText(timeText)
	self.clockText:setVisible(true)
	self.clockText:paginate()
	button:setTooltip(getText("Tooltip_LSRSM_ClockBtn_"..button.internal))
end

local function doResClockBtns(self, enable, isGadget)
	local resTooltipTxt = "Tooltip_LSRSM_ProdBtn"
	local clockTooltipTxt = "Tooltip_LSRSM_ClockBtn_"..self.clockBtn.internal
	if not enable then resTooltipTxt = resTooltipTxt.."Off_a"; clockTooltipTxt = resTooltipTxt; end
	if self.objData and not self.objData['author'] then self.researchBtn:setTooltip(getText(resTooltipTxt)); self.clockBtn:setTooltip(getText(clockTooltipTxt));
	self.researchBtn:setEnable(enable); self.clockBtn:setEnable(enable); end
	self.gadgetBtn:setEnable(isGadget)
	self.gadgetBtn:setVisible(isGadget)
end

function LSProductionMenu:onInvPanelConfirm(group)
	self.selectedGroup = group
	
	local tex = groupRef[self.selectedGroup]
	local name = getText("ContextMenu_Inventions_"..self.selectedGroup)

	self.sGName:setText(textColors.descB.."<IMAGE:"..tex..",28,28>"..name)
	self.sGName:paginate()

	self.productionSL:clear()
	self.resSL:clear()
	self.statsSL:clear()
	doTableSort(self.charData['invData'], self.productionSL, self.selectedGroup, self.knownInventions, self.knownToys)
	self.productionSL.selected = 1

	local enable, isGadget = doInfo(self)
	doResClockBtns(self, enable, isGadget)
end

function LSProductionMenu:onScrollClick()
	if not self.productionSL.selected or self.invPanel then return; end
	self.resSL:clear()
	self.statsSL:clear()
	local enable, isGadget = doInfo(self)
	doResClockBtns(self, enable, isGadget)
end

function LSProductionMenu:initialise()

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

	self.selectedGroup = (self.knownInventions and #self.knownInventions > 0 and "Gadgets") or self.knownToys[1].group or "Toys"
	local tex = groupRef[self.selectedGroup]
	local name = getText("ContextMenu_Inventions_"..self.selectedGroup)
	--local tex, name = getInvTexText(self.selectedInv)
	--self.knownInventions[1].invName

	self.sGName = doRichTextType(25, 18, 215, 28,textColors.descB.."<IMAGE:"..tex..",28,28>"..name,UIFont.Large)
    self.sGName.clip = true
	self.sGName:initialise()
	self.sGName:instantiate()
	self.sGName:paginate();
	self:addChild(self.sGName)

	self.uiBtns.sGBtn = {on=getTexture("media/textures/LSRSM/"..self.menuSkin.."/InvSelect_On.png"), off=getTexture("media/textures/LSRSM/"..self.menuSkin.."/InvSelect_Off.png")}
	self.sGBtn = ISButton:new(14, 14, 237, 36, "", self, self.onClickGroupSelect)
	self.sGBtn.internal = "Next"
	self.sGBtn:initialise()
	self.sGBtn:instantiate()
	self.sGBtn.displayBackground = false
	self.sGBtn.borderColor = {r=1, g=1, b=1, a=0};
	self.sGBtn:setImage(self.uiBtns.sGBtn.off)
	--self.sGBtn:setTooltip(getText("Tooltip_LSABTM_PlaylistSelect"))
	self:addChild(self.sGBtn)

    self.productionSL = ISScrollingListBox:new(25, 67, 270, 264);
	self.productionSL:setOnMouseDownFunction(self, self.onScrollClick)
	--self.productionSL:setOnMouseDoubleClick(self, self.onScrollDoubleClick)
	self.productionSL.doDrawItem = LSProductionMenu.doDrawItem
	self.productionSL.backgroundColor = {r=0, g=0, b=0, a=0};
	self.productionSL.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.productionSL:noBackground();
	--self.productionSL.altBgColor = {r=0.2, g=0.3, b=0.2, a=0}
	--self.productionSL.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.productionSL.font = UIFont.MediumNew
	--self.productionSL.itemPadY = 4
	self.productionSL.fontHgt = mediumNewTextHeight
	self.productionSL.itemheight = 32
    self.productionSL:initialise();
    self.productionSL:instantiate();
	self.productionSL.vscroll.backgroundColor = {r=0, g=0, b=0, a=0}
	self.productionSL.vscroll.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	self.productionSL.vscroll.uptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnUP.png")
	self.productionSL.vscroll.downtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnDOWN.png")
	self.productionSL.vscroll.toptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barTOP.png")
	self.productionSL.vscroll.midtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barMID.png")
	self.productionSL.vscroll.bottex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barBOT.png")
   -- self.productionSL:addScrollBars();
    self:addChild(self.productionSL);
	
	doTableSort(self.charData['invData'], self.productionSL, self.selectedGroup, self.knownInventions, self.knownToys)

	--local defs = LSInventionDefs.Improvements[self.selectedInv.invName][item.item.name]['defs']

	self.infoTitle = doRichTextType(315, 64, 463, 33,"none",UIFont.Large)
	self.infoTitle:initialise()
	self.infoTitle:instantiate()
	self.infoTitle:paginate();
	self.infoTitle:setVisible(false)
	self:addChild(self.infoTitle)

	self.infoText = doRichTextType(322, 106, 449, 151,"none",UIFont.NewSmall)
	self.infoText.maxLines = math.floor(150 / smallTextHeight)
	self.infoText:initialise()
	self.infoText:instantiate()
	self.infoText:paginate();
	self.infoText:setVisible(false)
	self:addChild(self.infoText)

	local statsTitleText = textColors.descB.." <CENTRE>"..getText("IGUI_Inventions_Stats")
	self.statsTitle = doRichTextType(322, 270, 218, 108,"none",UIFont.NewSmall)
	self.statsTitle.maxLines = math.floor(106 / smallTextHeight)
	self.statsTitle.startText = statsTitleText
	self.statsTitle:initialise()
	self.statsTitle:instantiate()
	self.statsTitle:paginate();
	self.statsTitle:setVisible(false)
	self:addChild(self.statsTitle)

    self.statsSL = ISScrollingListBox:new(322, 288, 218, 86);
	--self.statsSL:setOnMouseDownFunction(self, self.onScrollClick)
	self.statsSL.doDrawItem = LSProductionMenu.doDrawSmallItem
	self.statsSL.backgroundColor = {r=0, g=0, b=0, a=0.1};
	self.statsSL.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.statsSL.font = UIFont.NewSmall
	self.statsSL.fontHgt = smallTextHeight
	self.statsSL.itemheight = 18
    self.statsSL:initialise();
    self.statsSL:instantiate();
	self.statsSL.vscroll.backgroundColor = {r=0, g=0, b=0, a=0}
	self.statsSL.vscroll.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	self.statsSL.vscroll.uptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnUP.png")
	self.statsSL.vscroll.downtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnDOWN.png")
	self.statsSL.vscroll.toptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barTOP.png")
	self.statsSL.vscroll.midtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barMID.png")
	self.statsSL.vscroll.bottex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barBOT.png")
    self:addChild(self.statsSL);

	local resTitleText = textColors.descB.." <CENTRE>"..getText("IGUI_Inventions_CostEst")
	self.resTitle = doRichTextType(553, 270, 218, 108,resTitleText,UIFont.NewSmall)
	self.resTitle.maxLines = 1
	self.resTitle.titleTxt = resTitleText
	self.resTitle:initialise()
	self.resTitle:instantiate()
	self.resTitle:paginate();
	self.resTitle:setVisible(false)
	self:addChild(self.resTitle)

    self.resSL = ISScrollingListBox:new(553, 288, 218, 86);
	self.resSL:setOnMouseDownFunction(self, self.onScrollClick)
	--self.resSL:setOnMouseDoubleClick(self, self.onScrollDoubleClick)
	self.resSL.doDrawItem = LSProductionMenu.doDrawSmallItem
	self.resSL.backgroundColor = {r=0, g=0, b=0, a=0.1};
	self.resSL.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
	self.resSL.font = UIFont.NewSmall
	self.resSL.fontHgt = smallTextHeight
	self.resSL.itemheight = 18
    self.resSL:initialise();
    self.resSL:instantiate();
	self.resSL.vscroll.backgroundColor = {r=0, g=0, b=0, a=0}
	self.resSL.vscroll.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	self.resSL.vscroll.uptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnUP.png")
	self.resSL.vscroll.downtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/btnDOWN.png")
	self.resSL.vscroll.toptex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barTOP.png")
	self.resSL.vscroll.midtex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barMID.png")
	self.resSL.vscroll.bottex = getTexture("media/textures/LSRSM/"..self.menuSkin.."/barBOT.png")
    self:addChild(self.resSL);
	
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
	self.gadgetBtn = ISButton:new(629, 213, 142, 44, getText("ContextMenu_Inventions_Research"), self, self.onClick)
	self.gadgetBtn.internal = "ToResearch"
	self.gadgetBtn:setTooltip(getText("Tooltip_LSRSM_ToResearch"))
	self.gadgetBtn:initialise(); self.gadgetBtn:instantiate()
	self.gadgetBtn.displayBackground = false
	self.gadgetBtn.borderColor = {r=1, g=1, b=1, a=0}
	self.gadgetBtn.textColor = {r=0.3, g=0.4, b=0.58, a=1.0}
	self.gadgetBtn.font = UIFont.Medium
	self.gadgetBtn:setImage(self.uiBtns.gadgetBtn.off)
	self.gadgetBtn:setEnable(false)
	self.gadgetBtn:setVisible(false)
	self:addChild(self.gadgetBtn)

	local enable, isGadget = doInfo(self)
	doResClockBtns(self, enable, isGadget)

end

function LSProductionMenu:update()
	if self.aboutToClose then return; end
	-- player check
	if self.count%5 == 0 and (LSUtil.isCharBusy(self.character) or self.character:isAiming() or self.character:isPlayerMoving() or isKeyDown(self.eKey) or isKeyDown(self.sKey)) then self:close(); end
	
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

function LSProductionMenu:render()
	ISPanelJoypad.render(self);
end

function LSProductionMenu:close()
	if self.invPanel then
		self.invPanel:setVisible(false);
		self.invPanel:removeFromUIManager();
	end
	self.productionSL:clear()
	self.resSL:clear()
	self.statsSL:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSProductionMenu:destroy()
	if self.invPanel then
		self.invPanel:setVisible(false);
		self.invPanel:removeFromUIManager();
	end
	self.productionSL:clear()
	self.resSL:clear()
	self.statsSL:clear()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSProductionMenu:onBtnMouseDown(x, y)
    if self.invPanel or not self.moveWithMouse or not self:getIsVisible() or not self:isMouseOver() then return; end    
    self.downX = x;
    self.downY = y;
    self.moving = true;
    self:bringToTop();
end

function LSProductionMenu:new(X, Y, Width, Height, args) -- character,workbench,skillLevel,knownInventions,knownToys, spriteName
	local o = ISPanelJoypad:new(X, Y, Width, Height)
	setmetatable(o, self)
	self.__index = self
	o.uiX = X
	o.uiY = Y
	o.character = args[1]
	o.charData = o.character and o.character:getModData()
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
	o.panelH = Height
	o.panelW = Width
	if not o.charData['LSUISkins'] then o.charData['LSUISkins'] = {}; end
	o.menuSkin = o.charData['LSUISkins']['LSProductionMenu'] or "LSSims"
	o.moveWithMouse = true
	o.count = 0
	o.uiBtns = {}
	local minPerFakeHour = getSandboxOptions():getDayLengthMinutes()/24
	o.minPerFakeMin = minPerFakeHour/60
	return o
end





