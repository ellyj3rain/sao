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

InventionsMenu = InventionsMenu or {}
InventionsMenu.workbench = InventionsMenu.workbench or {}
local self = InventionsMenu.workbench
local l_d = {}
local toolTags = {"BlowTorch","Hammer","Screwdriver"}
local clothingTags = {"WeldingMask"}
local libs = {"invLib", "toysLib"}

--[[
local function doNote(character, texture)
	local text = " <CENTRE> "..getText("IGUI_T_Art_Easel_Note")
	local infoText = " <LINE><H1> "..getText("IGUI_T_Art_Easel_Title").." <LINE> ".." <CENTRE> <IMAGE:media/ui/tutorial/Painting_01.png,300,200> <LINE><LINE><TEXT> "..getText("IGUI_T_Art_Easel_Body").." <LINE><LINE> "..getText("IGUI_T_Art_Easel_Body2").." <LINE><LINE> "..getText("IGUI_T_Art_Easel_Body3").." <LINE><LINE> "..getText("IGUI_T_Art_Easel_Body4")
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, "tutorialArt", texture, 4, "noteEasel", infoText, true}) -- player, mainText, queueType, tex, time, closePerm, infoPanel, noSpam
end
]]--

local function characterHasSkill(character, invName)
	if not character then return false; end
	local skillSet = LSInventionDefs.Items[invName] and LSInventionDefs.Items[invName].discover
	if not skillSet then return true; end
	for n=1,#skillSet do
		local param = skillSet[n]
		if type(param) ~= "number" then
			local value = skillSet[n+1] or 0
			local skillLvl = character:getPerkLevel(Perks[param])
			if skillLvl < value then return false; end
		end
	end
	return true
end

local function getInvTable(character, path, knownList, level, fullList, new)
	local t = self[path]
	local newTable = {}
	for k, v in ipairs(t) do
		if (fullList or not v.parent) and (not level or v.level <= level) and (not new or not knownList or not knownList[v.invName]) then
			if path ~= "invLib" or not level then
				table.insert(newTable, v)
			elseif characterHasSkill(character, v.invName) then
				table.insert(newTable, v)
			end
		end
	end
	return newTable
end

InventionsMenu.workbench.getInvFromTable = function(path, name)
	local t = getInvTable(nil, path, nil, nil, true, nil)
	for k, v in ipairs(t) do
		if v.invName == name then return v; end
	end
	return false
end

InventionsMenu.workbench.resetInvCost = function(charInvData)
	for k, v in ipairs(self.invLib) do
		local data = charInvData[v.invName]
		if data and data['workCost'] then
			data['workCost'] = false
		end
	end
end

local skillBonusDiv = 20 -- 5%

InventionsMenu.workbench.getProductionDuration = function(invData, skillLevel, workParams) -- 1 phase
	local path = "invLib"
	if not LSUtil.StringStartWith(workParams[4],"inv") then path = "toysLib"; end
	local inv = self.getInvFromTable(path, workParams[3])

	local skillBonus = inv.baseDuration/skillBonusDiv
	local bonusLevel = math.max(0, skillLevel-inv.level)
	local duration = inv.baseDuration-(skillBonus*bonusLevel)
	if path ~= "invLib" or not invData[inv.invName] then return math.max(1000, duration); end
	local data = invData[inv.invName]
	local researchLvl = math.max(1, LSInv.getResearchLevel(data['improvementData'], false, "standardization"))
	duration = duration*researchLvl
	return math.max(1000, duration/data['inventionData']['standardization'])
end

InventionsMenu.workbench.getInventionDuration = function(invData, skillLevel, workParams) -- 2-3 phases
	local isInv = LSUtil.StringStartWith(workParams[4],"inv")
	if workParams[1] == 3 or (workParams[1] == 2 and not isInv) then -- prototype phase 2/3
		local path = "invLib"
		if not isInv then path = "toysLib"; end
		local inv = self.getInvFromTable(path, workParams[3])
		local baseRdm = ZombRand(inv.baseDuration, inv.baseDuration*3)
		local skillBonus = baseRdm/skillBonusDiv
		local bonusLevel = math.max(0, skillLevel-inv.level)
		return baseRdm-(skillBonus*bonusLevel)
	end

	local resDuration = 10000+ZombRand(10000) -- phase 1 (discovery)
	if workParams[1] == 2 then -- invent phase 2 (mat res)
		resDuration = resDuration+2500*ZombRand(4) -- 2500, 5000, 7500, 10000
	end
	if isInv then resDuration = resDuration*2; end
	return resDuration
end

InventionsMenu.workbench.getResearchDuration = function(invData, skillLevel, workParams) -- 2 phases
	local data = invData[workParams[3]]
	local improvLvl = math.max(1, LSInv.getResearchLevel(data['improvementData'], workParams[5], false, 1))
	local totalResearchLvl = math.max(1, LSInv.getResearchLevel(data['improvementData'], false, "costDecrease"))

	local inv = self.getInvFromTable("invLib", workParams[3])
	local baseDuration = 3000+1000*inv.level+3000*improvLvl+6000*totalResearchLvl
	if workParams[1] == 2 then
		baseDuration = baseDuration/2
	end

	local skillBonus = baseDuration/skillBonusDiv
	local bonusLevel = math.max(0, skillLevel)
	local duration = baseDuration-(skillBonus*bonusLevel)
	return duration/data['inventionData']['costDecrease']
end

local function getOrCreateMaterialCost(character, charInvData, skillLevel, invName, resultType, lookUp) -- REMEMBER - cost regens for inventions when - inv is improved, player levels up inventing skill (level up or inv is improved then set workCost to false and it will automatically regen here)
	if LSUtil.StringStartWith(resultType,"inv") then -- for complex inventions only
		local data = charInvData[invName]
		if not data['workCost'] then
			local level = LSInv.getResearchLevel(data['improvementData'])
			local defs = LSInventionDefs.Items[invName]['costDefs'][1]
			local t = LSInv.getInventionDefinitionsMult(false, level, defs, data['inventionData'], {false})
			data['workCost'] = LSUtil.deepCopy(t.reqRes)
		end
		return data['workCost']
	else -- anything that lacks a def (ie not an invention) has fixed material costs
		local inv = self.getInvFromTable("toysLib", invName)
		if lookUp then return inv.cost; end
		return LSUtil.deepCopy(inv.cost)
	end
	return false
end

local function getMaterialCost(character, skillLevel, objData)
	if objData.workCost then return LSUtil.deepCopy(objData.workCost); end
	if objData.workType ~= "Production" and objData.workPhase <= 1 then return true; end -- true = satisfied - research phase 1 and inventing phase 1 have no cost
	local costList
	if objData.workType == "Invention" and objData.workPhase <= 2 then -- inventing phase 2 has simple randomized costs
		costList = LSInv.getDiscoveryBasicItems(objData.level or 1, skillLevel)
	elseif LSUtil.StringStartWith(objData.resultType,"inv") then -- inventing phase 3 (production-like), production (only has 1 phase), research phase 2 (research costs) -- for complex inventions only
		local level, improvName, defs, inventionData = 1, false, false, false
		if objData.workType == "Research" then 
			improvName, defs = objData.result, LSInventionDefs.Improvements[objData.invName][objData.result]['defs']
		else
			defs = LSInventionDefs.Items[objData.invName]['costDefs'][1]
		end
		if objData.workType ~= "Invention" then
			local data = character:getModData()['invData'][objData.invName]
			inventionData = data['inventionData']
			level = LSInv.getResearchLevel(data['improvementData'])
		else
			inventionData = LSInventionDefs.Items[objData.invName]
		end
		local t = LSInv.getInventionDefinitionsMult(false, level, defs, inventionData, {objData.workType == "Invention", objData.workType == "Research"})
		costList = t.reqRes
	else -- anything that lacks a def (ie not an invention) has fixed material costs - production, inventing phase 3 (if it has a phase3)
		local inv = self.getInvFromTable("toysLib", objData.invName)
		costList = inv.cost
	end
	if not costList then return false; end
	return LSUtil.deepCopy(costList)
end

local function getHasItems(character, skillLevel, obj, objData, transfer, custom) -- invName invType
	if not custom and objData and objData.workType ~= "Production" and objData.workPhase <= 1 then return false, "", false, false, false; end
	local disable, newText, inventory = false, "", character:getInventory()
	local tools = {}
	-- tools
	for n=1,#toolTags do
		local toolTag = toolTags[n]
		local tex, text = LSUtil.getTexIcon(toolTag, nil)
		local tempBlowTorch = toolTag == "BlowTorch" and "BlowTorch" -- temp fix as item currently lacks tag
		local val = 0
		local item = LSUtil.getItem(character, (toolTag == "BlowTorch" and "BLOW_TORCH") or toolTag, tempBlowTorch, true)
		if item then val = 1; tools[toolTag] = item; else disable = true; end
		if transfer and not disable and not LSUtil.doItemTransfer(character, item, nil) then disable = true; end
		newText = newText..LSUtil.getToolTipItemRequirement(val, 1, tex..text)
	end
	for n=1,#clothingTags do
		local clothingTag = clothingTags[n]
		local specificTag = (clothingTag == "WeldingMask" and "WELDING_MASK") or clothingTag
		local tex, text = LSUtil.getTexIcon(clothingTag, nil)
		local val = 0
		local hasItem = LSUtil.hasItem(character, specificTag, nil, true)
		if hasItem then
			val = 1
			if transfer and not disable and not LSUtil.getItemAndEquip(character, specificTag, nil, nil, nil, true, nil) then disable = true; end
		else 
			disable = true
		end
		newText = newText..LSUtil.getToolTipItemRequirement(val, 1, tex..text)
	end
	
	local matText = ""
	if newText ~= "" then newText, matText = getText("Tooltip_craft_Needs") .. ": <LINE>" .. newText, " <LINE><RGB:1,1,1>"; end
	matText = matText..getText("Tooltip_Inventions_ResReq")..": <LINE>"
	-- materials
	local matList
	if custom then
		matList = getOrCreateMaterialCost(character, custom[3], skillLevel, custom[1], custom[2], custom[4])
	elseif objData then
		if not objData.workCost then
			objData.workCost = getMaterialCost(character, skillLevel, objData)
			if isClient() then sendClientCommand("LS", "ModifyObjData", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()}, false, objData}); end
			--LSSync.transmit(obj) transmit is done during action complete
		end
		matList = objData.workCost
	end
	if not matList then return disable, newText..matText.." <TEXT>"..getText("Tooltip_InvWorkbench_NoResReq"), tools, false, false; end
	if type(matList) ~= "table" then return disable, newText..matText.." <TEXT>"..getText("Tooltip_InvWorkbench_SatisfiedRes"), tools, false, false; end
	
	local hasMat, listFilled
	for k, v in pairs(matList) do
		local itemCount = inventory:getItemCount(k, true)
		if itemCount > 0 and LSUtil.getItemDrainable(character, k, 1) then itemCount = LSUtil.getTotalItemDrainableCount(character, k); end
		if itemCount < v then disable = true; end
		if itemCount > 0 and v > 0 then hasMat = true; end
		if v > 0 then listFilled = true; end
		--local moduleName, itemType = string.match(k, "^([^.]+)%.(.+)$")
		--if not itemType then itemType = tostring(k); end
		--local itemTexture, itemText = LSUtil.getTexIcon(itemType, moduleName)
		local name = tostring(k)
		local tex = getItemTextureName(name)
		local itemTexture = (tex and "<IMAGE:"..tex..",16,16>") or ""
		local itemText = getItemName(name) or name
		--if not itemTexture then itemTexture = ""; end
		matText = matText..LSUtil.getToolTipItemRequirement(itemCount, v, itemTexture..itemText)
	end
	if not listFilled then matText = matText.." <TEXT><RGB:0.7,1,0.7>"..getText("Tooltip_InvWorkbench_SatisfiedRes"); end
	return disable, newText..matText, tools, hasMat, matList, listFilled
end

--research result is improvement name
--invention and production resultType is invItem/item/invObj/obj; invention invName is invention name; invention result is result (spritename or fulltype)

local function getProjectNameAndDesc(workType, invName, resultType, result)
	local projName, projDesc, projTex, imgSize = "", "", false, ",64,64>"
	if workType == "Research" then
		projName, projDesc, projTex = getText("IGUI_Inventions_"..invName.."_"..result), getText("IGUI_Inventions_"..invName.."_"..result.."desc"), getTexture("media/ui/invRes_icon.png")
		if projName == "IGUI_Inventions_"..invName.."_"..result then projName, projDesc = getText("IGUI_Inventions_"..result), getText("IGUI_Inventions_"..result.."_desc"); end
		projDesc = " <RGB:0.8,0.8,0.8><CENTRE>("..getText("IGUI_Inventions_"..invName)..") <RGB:0.7,0.7,0.7><LINE><LEFT>"..projDesc
	elseif workType == "Production" then
		if LSUtil.StringStartWith(resultType,"inv") then
			projDesc = getText("Tooltip_Inventions_"..invName.."_desc")
			if projDesc == "Tooltip_Inventions_"..invName.."_desc" then projDesc = getText("Tooltip_Inventions_Gadgets_desc"); end
		end
		if resultType == "obj" or resultType == "invObj" then
			projName = LSUtil.getMoveableDisplayName(result, nil, nil, nil, result)
			local textureName = (result == "LS_Inventions_12" and "LS_Inventions_32") or result
			local sprite = getTexture(textureName)
			if sprite then projTex, imgSize = sprite:splitIcon(), ",64,96>"; end
		elseif resultType == "item" or resultType == "invItem" then
			projTex, projName = LSUtil.getItemTexAndText(nil, nil, result)
		end
	end
	if not projTex then projTex = getTexture("media/ui/invInv_icon.png"); end
	return projName, projDesc, projTex, imgSize
end

local function getMaxPhases(workType, resultType)
	local t = {
		Production = 1,
		Research = 2,
		Invention = 3,
	}
	local maxNum = 3
	if not LSUtil.StringStartWith(resultType,"inv") then maxNum = 2; end
	return math.min(maxNum,t[workType])
end

local function getWorkProgress(objData)
	local val = 0
	local rgbColor = " <RGB:1,0,0>"

	if objData.progress and objData.progress <= 0 then
		val = 100
	elseif objData.duration and objData.progress then
		local realProgress = objData.duration - objData.progress
		if realProgress > 0 then val = LSUtil.getPercentage(objData.duration,realProgress, 2, false); end --!
	end
	if (val >= 30) and (val < 60) then
		rgbColor = " <RGB:1,1,0>"
	elseif val >= 60 then
		rgbColor = " <RGB:0,1,0>"
	end
	return rgbColor, val
end

local barColor = {
	[80]="green",
	[60]="lime",
	[30]="yellow",
	[10]="orange",
	[0]="red",
}

local function getBarColor(val)
	local thresholds = {80,60,30,10,0}
	local color = 0
	for n=1,#thresholds do
		local threshold = thresholds[n]
		if val >= threshold then color = threshold; break; end
	end
	return barColor[color]
end

local function doWorkOption(context, parentMenu) -- charInvData, workbench, spriteName, emptySprite, skillLevel
	if not l_d.objData or not l_d.objData.workType then return; end
	local progressRGB, progressVal = getWorkProgress(l_d.objData)
	local text = getText("ContextMenu_Inventions_Continue")
	local projName, projDesc, projTex, imgSize = getProjectNameAndDesc(l_d.objData.workType, l_d.objData.invName, l_d.objData.resultType, l_d.objData.result)
	--if l_d.objData.workType == "Production" then projTex = projTex:getName(); end
	local contextName = (projName ~= "" and " ("..projName..")") or ""
	text = text.." "..getText("ContextMenu_Inventions_"..l_d.objData.workType)..contextName
	if projDesc ~= "" then projDesc = " <RGB:0.7,0.7,0.7><LINE><LEFT>"..projDesc; end

	local disable, itemsText, tools, hasMat, matList, listFilled = getHasItems(l_d.character, l_d.skillLevel, l_d.workbench, l_d.objData, false, false)

	local workParams = {l_d.objData.workPhase, l_d.objData.workType, l_d.objData.invName, l_d.objData.resultType, l_d.objData.result, l_d.objData.level}

	if itemsText ~= "" then itemsText = " <RGB:1,1,1><LINE><LINE><LEFT>"..itemsText; end
	local title = getText("Tooltip_InvWorkbench_Title_"..l_d.objData.workType)
	local textFont = ISToolTip.GetFont() or UIFont.NewSmall
	local lineW = getTextManager():getFontFromEnum(textFont):getWidth(title)+200
	local progressBar = math.max(1,math.floor(progressVal))
	local barX = math.floor(((lineW-100)/2)-(progressBar/2))
	local barColor = getBarColor(progressBar)
	--
	local fixedTex = LSUtil.fixTexIconPath(projTex:getName())
	local maxPhases = (l_d.objData.workType == "Invention" and "???") or getMaxPhases(l_d.objData.workType, l_d.objData.resultType)
	local toolTiptext = "<H1><ORANGE>"..title.." <LINE><IMAGECENTRE:"..fixedTex..imgSize.." <LINE>"..
	"<TEXT><CENTRE>"..progressRGB..progressVal.." <RGB:1,1,1> %% <LINE><LEFT><SETX:"..tostring(barX).."><IMAGE:media/ui/bars/bar_h_"..barColor..".png,"..tostring(progressBar)..",12><LINE><LINE><CENTRE>"..
	projName..projDesc..itemsText.." <LINE><LINE>"..getText("Tooltip_InvWorkbench_Phase",l_d.objData.workPhase,maxPhases)..
	getText("Tooltip_InvWorkbench_"..l_d.objData.workType.."_a"..l_d.objData.workPhase)

	if (disable or listFilled) and hasMat and l_d.objData.workCost and type(l_d.objData.workCost) == "table" then
		local addOption = parentMenu:addOptionOnTop(getText("ContextMenu_Inventions_Add"),workParams,self.onWorkAction,l_d.emptySprite, true)
		--addOption.toolTip = LSUtil.getNewTooltip(itemsText)
		addOption.toolTip = LSUtil.getNewTooltip(toolTiptext, nil, nil, nil, lineW, nil)
		addOption.iconTexture = getTexture('media/ui/ZoomIn.png')
	else
		local option = parentMenu:addOptionOnTop(text,workParams,self.onWorkAction,l_d.emptySprite)
		option.notAvailable = disable or listFilled
		option.toolTip = LSUtil.getNewTooltip(toolTiptext, nil, nil, nil, lineW, nil)
		option.iconTexture = getTexture('media/ui/gears_icon.png')
	end

end

local function getAllInventions(charInvData, known)
	local invTable, toyTable = {}, {}
	if known and not charInvData then return invTable, toyTable; end
	for k, v in ipairs(self.invLib) do
		if not known or (charInvData and charInvData[v.invName]) then
			table.insert(invTable, v)
		end
	end
	for k, v in ipairs(self.toysLib) do
		if not known or (charInvData and charInvData[v.invName]) then
			table.insert(toyTable, v)
		end
	end
	return invTable, toyTable
end

local function doInventOption(context, parentMenu)
	local newInvs, hasInv = {}, nil
	for n=1,#libs do
		newInvs[libs[n]] = getInvTable(l_d.character, libs[n], l_d.charInvData, l_d.skillLevel, false, true)
		if not hasInv and #newInvs[libs[n]] > 0 then hasInv = true; end
	end
	local disable = (l_d.eureka or l_d.gloomy or l_d.block) or not hasInv
	local option = parentMenu:addOption(getText("ContextMenu_Inventions_Invent"),newInvs,self.onBeginInventOption)
	local tooltipText = (disable and ((l_d.eureka and "Eureka") or (l_d.gloomy and "Gloomy") or (l_d.block and "MentalBlock") or "InvWorkbench_Invent_NotAvailable")) or "InvWorkbench_Invent"
	option.notAvailable = disable
	option.toolTip = LSUtil.getNewTooltip(getText("Tooltip_"..tooltipText))
	option.iconTexture = getTexture('media/ui/maintenance_icon.png')
end

local function isValidInteraction(obj, character, spriteName)
	return LSUtil.isValidObj(obj, spriteName) and not LSUtil.isCharBusy(character)
end

InventionsMenu.workbench.onBeginInventOption = function(newInvs, params)
	local inv, args
	if not params then
		if not newInvs then return; end
		local t = newInvs.invLib
		local numToys, numInvs = #newInvs.toysLib, #newInvs.invLib
		if numToys > 0 and (numInvs == 0 or numToys < 3 or ZombRand(math.max(21,numToys)) >= math.min(15, 3*numInvs)) then
			t = newInvs.toysLib
		end
		if #t == 0 then return; end
		inv = t[ZombRand(#t)+1]
		if not inv then return; end

		if l_d.charInvData and l_d.charInvData['lsWkID'] then
			if self.invPanel then
				self.invPanel:setVisible(false)
				self.invPanel:removeFromUIManager()
				self.invPanel = false
			end
			local newPanel = LSInvForgetPanel:new(self, l_d.character, l_d.workbench, {0,"Invention",inv.invName,inv.invType,inv.invResult,inv.level});
			newPanel:initialise()
			newPanel:addToUIManager()
			self.invPanel = newPanel
			return
		end
		args = l_d
	else
		args = params
		if not args or not isValidInteraction(args.workbench, args.character, "Inv Workbench") then return; end
	end
	if LSUtil.walkToFront(args.character, args.workbench) then
		local wP = (params and params.workParams) or {0,"Invention",inv.invName,inv.invType,inv.invResult,inv.level}
		local newID = LSInv.getNewID()
		if LSUtil.isValidObj(args.workbench, "workbench") and LSUtil.isObjOnSqr(args.workbench) then
			local spriteName = LSUtil.getObjSpriteName(args.workbench)
			if not LSInv.getWorkbenchEmptySprite(spriteName) then
				ISTimedActionQueue.add(LSIWAddItems:new(args.character, args.workbench, {newID, args.workbench:getModData(), false, spriteName, nil, wP}))
			end
		end
	end
end

local function doResearchOption(context, parentMenu, knownInventions, knownToys)
	local option = parentMenu:addOption(getText("ContextMenu_Inventions_Research"),knownInventions,self.onResearchUI,knownToys)
	local disable = (l_d.eureka or l_d.gloomy or l_d.block) or #knownInventions == 0
	local icon, tooltipText = "shareknowledge_icon", "InvWorkbench_Research"
	if disable then
		icon = "shareknowledgeNo_icon"
		tooltipText = (l_d.eureka and "Eureka") or (l_d.gloomy and "Gloomy") or (l_d.block and "MentalBlock") or "InvWorkbench_Research_NotAvailable"
	end
	option.notAvailable = disable
	option.toolTip = LSUtil.getNewTooltip(getText("Tooltip_"..tooltipText))
	option.iconTexture = getTexture('media/ui/'..icon..'.png')
end

local function doCreateOption(context, parentMenu, knownInventions, knownToys)
	local option = parentMenu:addOption(getText("ContextMenu_Inventions_Production"),knownInventions,self.onProductionUI,knownToys)
	local hasInvs, hasToys = #knownInventions > 0, #knownToys > 0
	local disable = l_d.gloomy or l_d.block or (not hasInvs and not hasToys)
	local icon, tooltipText = "invFix_icon", "InvWorkbench_Production"
	if disable then
		icon = "invFix_icon"
		tooltipText = (l_d.gloomy and "Gloomy") or (l_d.block and "MentalBlock") or "InvWorkbench_Production_NotAvailable"
	end
	option.notAvailable = disable
	option.toolTip = LSUtil.getNewTooltip(getText("Tooltip_"..tooltipText))
	option.iconTexture = getTexture('media/ui/'..icon..'.png')
end

InventionsMenu.workbench.onProductionUI = function(knownInventions,knownToys)
	if not isValidInteraction(l_d.workbench, l_d.character, l_d.spriteName) then return; end
	local menu = LSProductionMenu:new(getCore():getScreenWidth()/2-400,getCore():getScreenHeight()/2-200,800,400,{l_d.character,l_d.workbench,l_d.skillLevel,knownInventions,knownToys,l_d.spriteName})
	menu:initialise()
	menu:addToUIManager()
end

--[[
local function doCreateOptionList(optionSubMenu, inv, projName, projTex, projDesc)
	--local projName, projDesc, projTex = getProjectNameAndDesc("Production", inv.invName, inv.invType, inv.invResult)
	local disable, itemsText, tools, hasMat, matList = getHasItems(l_d.character, l_d.skillLevel, nil, nil, false, {inv.invName, inv.invType, l_d.charInvData, true})
	local option = optionSubMenu:addOption(projName,{0,"Production",inv.invName,inv.invType,inv.invResult,inv.level},self.onWorkAction,false,disable and hasMat,{inv.invName, inv.invType, l_d.charInvData, false})
	option.notAvailable = disable and not hasMat
	option.iconTexture = projTex
	local productionText = "Tooltip_InvWorkbench_ProductionList"
	if disable and hasMat then
		productionText = productionText.."_Add"
	elseif disable then
		productionText = productionText.."_Missing"
	end
	if itemsText ~= "" and projDesc ~= "" then itemsText = " <RGB:1,1,1><LINE><LINE><LEFT>"..itemsText; end
	option.toolTip = LSUtil.getNewTooltip(projDesc..itemsText.." <TEXT><LINE><LINE>"..getText(productionText))
end

local function doCreateOption(context, parentMenu, knownInventions, knownToys)
	local option = parentMenu:addOption(getText("ContextMenu_Inventions_Production"))
	local hasInvs, hasToys = #knownInventions > 0, #knownToys > 0
	local disable = l_d.gloomy or (not hasInvs and not hasToys)
	local icon, tooltipText = "invFix_icon", "Tooltip_InvWorkbench_Production"
	if disable then
		icon = "invFix_icon"
		tooltipText = (l_d.gloomy and "Tooltip_Gloomy") or "Tooltip_InvWorkbench_Production_NotAvailable"
	end
	option.notAvailable = disable
	option.toolTip = LSUtil.getNewTooltip(getText(tooltipText))
	option.iconTexture = getTexture('media/ui/'..icon..'.png')
	if disable then return; end

	local optionSubMenu = parentMenu:getNew(parentMenu);
	context:addSubMenu(option, optionSubMenu)

	if hasInvs then
		local optionInv = optionSubMenu:addOption(getText("ContextMenu_Inventions_Gadgets"))
		local subMenu = optionSubMenu:getNew(optionSubMenu)
		context:addSubMenu(optionInv, subMenu)
		for k, v in pairs(knownInventions) do
			local projName, projTex, projDesc = false, false, getText("Tooltip_Inventions_"..v.invName.."_desc")
			if v.invType == "invObj" then
				projTex, projName = LSUtil.getObjTexAndText(v.invResult)
			else
				projTex, projName = LSUtil.getItemTexAndTextNew(v.invResult)
			end
			if projName then doCreateOptionList(subMenu, v, projName, projTex, projDesc); end
		end
	end
	
	if hasToys then
		local subMenus = {}
		local sMByLvl = {[2]={0,1},[5]={3,4},[8]={6,7},[9]={10}}
		for k, v in pairs(knownToys) do
			local category = v.group or "Toys"
			if not subMenus[category] then
				local newOption = optionSubMenu:addOption(getText("ContextMenu_Inventions_"..category))
				subMenus[category] = optionSubMenu:getNew(optionSubMenu)
				context:addSubMenu(newOption, subMenus[category])
				for n=1,l_d.skillLevel do
					if sMByLvl[n] then
						local levelOption = subMenus[category]:addOption(tostring(sMByLvl[n][1]).." - "..tostring(n))
						subMenus[n] = subMenus[category]:getNew(subMenus[category])
						context:addSubMenu(levelOption, subMenus[n])
						for l=1,sMByLvl[n] do
							subMenus[sMByLvl[n][l] --]=subMenus[n]
						end
					end
				end
			end
			local projName, projTex
			if v.invType == "obj" then
				projName = LSUtil.getMoveableDisplayName(v.invName, nil, nil, nil, v.invResult)
				local texture = getTexture(v.invResult)
				if texture then projTex = texture:splitIcon(); end
			else
				projTex, projName = LSUtil.getItemTexAndTextNew(v.invResult)
			end
			if projName then
				if subMenus[v.level] then
					doCreateOptionList(subMenus[v.level], v, projName, projTex, "")
				else
					doCreateOptionList(subMenus[category], v, projName, projTex, "")
				end
			end
		end
	end

end
]]--

--local function checkWorkbenchID(objData, workbench) -- lsWkID is regenerated and added to player at start or end of interactions (start = LSIWAction; end = LSIWAddItems)
--	if not objData.lsWkID then objData.lsWkID = self.getNewID(); workbench:transmitModData(); end
--end

local function isValidWork()
	--[[
	LSUtil.debugDiagnostics("/client/ISAmbt/LSGoodEating", "foodIsValid", {
		['l_d.workbench']=tostring(l_d.workbench),
		['l_d.character']=tostring(l_d.character),
		['charDescriptor']=(l_d.character and tostring(l_d.character:getDescriptor())) or "NIL",
		['charName']=(l_d.character and l_d.character:getDescriptor() and l_d.character:getDescriptor():getForename().." "..l_d.character:getDescriptor():getSurname()) or "NIL",
		['l_d.objData.isRuined']=(l_d.objData and tostring(l_d.objData.isRuined)) or "NIL",
		['l_d.objData.author']=(l_d.objData and tostring(l_d.objData.author)) or "NIL",
		['isAuthor']=(l_d.objData and l_d.objData.author and l_d.character and l_d.character:getDescriptor() and tostring(l_d.character:getDescriptor():getForename().." "..l_d.character:getDescriptor():getSurname() == l_d.objData.author)) or "NIL",
		['l_d.objData.lsWkID']=(l_d.objData and tostring(l_d.objData.lsWkID)) or "NIL",
		['l_d.charInvData.lsWkID']=(l_d.charInvData and tostring(l_d.charInvData.lsWkID)) or "NIL"})
	]]--
	if not l_d.workbench or not l_d.character then return false; end
	local charDescriptor = l_d.character:getDescriptor()
	return l_d.objData and not l_d.objData.isRuined and l_d.objData.author and l_d.objData.author == charDescriptor:getForename().." "..charDescriptor:getSurname() and
	l_d.objData.lsWkID and l_d.charInvData.lsWkID and l_d.objData.lsWkID == l_d.charInvData.lsWkID
end

InventionsMenu.workbench.onResearchUI = function(knownInventions,knownToys)
	if not isValidInteraction(l_d.workbench, l_d.character, l_d.spriteName) then return; end
	local menu = LSResearchMenu:new(getCore():getScreenWidth()/2-400,getCore():getScreenHeight()/2-200,800,400,{l_d.character,l_d.workbench,l_d.skillLevel,knownInventions,knownToys,l_d.spriteName})
	menu:initialise()
	menu:addToUIManager()
	-- do research ui!!
end

InventionsMenu.workbench.onWorkAction = function(workParams, emptySprite, addItems, prodParams) -- charInvData, spriteName, emptySprite, skillLevel, addItems, workParams (workType string and other args or false)
	if not isValidInteraction(l_d.workbench, l_d.character, l_d.spriteName) or (emptySprite and not isValidWork()) then return; end
	if LSUtil.walkToFront(l_d.character, l_d.workbench) then
		local disable, itemsText, tools, hasMat, matList, listFilled = getHasItems(l_d.character, l_d.skillLevel, l_d.workbench, l_d.objData, not addItems, prodParams) -- production create args

		local newID = (not emptySprite or (workParams and workParams[1] == 0)) and LSInv.getNewID()
		if addItems or newID then
			if not hasMat and not newID then return; end
			ISTimedActionQueue.add(LSIWAddItems:new(l_d.character, l_d.workbench, {newID, l_d.objData, matList, l_d.spriteName, emptySprite, workParams})) -- spriteName, emptySprite, workParams
			return
		end
		if disable then return; end
		local duration = (emptySprite and l_d.objData.duration and l_d.objData.progress) or self['get'..workParams[2]..'Duration'](l_d.charInvData, l_d.skillLevel, workParams)
		ISTimedActionQueue.add(LSIWAction:new(l_d.character, l_d.workbench, {l_d.objData, duration, matList, l_d.spriteName, tools, emptySprite, l_d.skillLevel, workParams})) -- objData, duration, material list, spritename, toolList, hasWork (if not emptySprite then replaces obj sprite), skillLevel, workParams
	end
end

InventionsMenu.workbench.onScrapProject = function(shouldGet)
	if not isValidInteraction(l_d.workbench, l_d.character, l_d.spriteName) then return; end
	if LSUtil.walkToFront(l_d.character, l_d.workbench) then
		local oldID = l_d.objData['lsWkID']
		if l_d.emptySprite then ISTimedActionQueue.add(LSIWScrap:new(l_d.character, l_d.workbench, oldID, l_d.emptySprite, shouldGet)); end
	end
end

InventionsMenu.workbench.addInventionToPlayer = function(charInvData, inv)
	charInvData[inv.invName] = LSUtil.deepCopy(inv)
		
	local ogInvDef = LSInventionDefs and LSInventionDefs.Items and LSInventionDefs.Items[inv.invName]
	local ogImprovDef = LSInventionDefs and LSInventionDefs.Improvements and LSInventionDefs.Improvements[inv.invName]
	local invDefs = LSUtil.deepCopy(ogInvDef)
	local improvDefs = LSUtil.deepCopy(ogImprovDef)
			
	charInvData[inv.invName]['inventionData'] = {}
	for k, v in pairs(invDefs) do
		charInvData[inv.invName]['inventionData'][k] = v
	end
	
	charInvData[inv.invName]['improvementData'] = {}
	for k, v in pairs(improvDefs) do
		local maxNum = 1
		if v and v.repeatable then maxNum = #v.repeatable; end
		charInvData[inv.invName]['improvementData'][k] = {0,maxNum}
	end
end

InventionsMenu.workbench.onDebug = function(learn)
	if not learn then
		if l_d.charInvData then
			for k,v in pairs(l_d.charInvData) do
				l_d.charInvData[k] = false
			end
		end
		return
	end

	for n=1,#learn[2] do -- toys
		local toy = learn[2][n]
		if not l_d.charInvData[toy.invName] then l_d.charInvData[toy.invName] = LSUtil.deepCopy(toy); end
	end
	for n=1,#learn[1] do -- inv
		local inv = learn[1][n]
		if not l_d.charInvData[inv.invName] then
			InventionsMenu.workbench.addInventionToPlayer(l_d.charInvData, inv)
		end
	end
end

local function isFinished(objData)
	if not objData or not objData.workPhase then return false; end
	local complex = LSUtil.StringStartWith(objData.resultType,"inv")
	return objData.workPhase > 3 or
	(objData.workType == "Production" and objData.workPhase > 1) or
	(objData.workType == "Invention" and objData.workPhase > 2 and not complex)
end

local rollData = {
	['good'] = {"chance","chanceBig","chanceGnome"},
	['bad'] = {"chance","chanceBig"},
}

InventionsMenu.workbench.onDebugForceEvent = function(destkarma,group)
	l_d.objData['events'][destkarma]['force'] = group
	local oppositeKarma = (destkarma=="good" and "bad") or "good"
	l_d.objData['events'][oppositeKarma]['force'] = false
	if isClient() then sendClientCommand("LS", "ModifyObjData", {{l_d.workbench:getX(),l_d.workbench:getY(),l_d.workbench:getZ(),l_d.spriteName}, false, l_d.objData}); end
end

local function workDebugOptions(context, parentMenu)
	if not l_d.objData['events'] then return; end
	l_d.objData['events']['good'] = l_d.objData['events']['good'] or {}
	l_d.objData['events']['bad'] = l_d.objData['events']['bad'] or {}
	local isSchematics = l_d.objData.workType ~= "Production" and l_d.objData.workPhase < 2
	local canBig = not l_d.objData['events']['crit'] and not isSchematics
	for k, v in pairs(rollData) do
		local karma = tostring(k)
		for n=1,#v do
			local roll = v[n]
			if (roll ~= "chanceGnome" or l_d.objData.workType == "Production" or (l_d.objData.workType == "Invention" and l_d.objData.workPhase > 1)) and (roll ~= "chanceBig" or canBig) then
				local option = parentMenu:addOptionOnTop("Debug: Force "..roll.." ("..karma..") on next roll",karma,self.onDebugForceEvent,n)
				option.notAvailable = l_d.objData['events'][karma]['force'] and l_d.objData['events'][karma]['force'] == n
			end
		end
	end
end

InventionsMenu.workbench.doBuildMenu = function(player, context, worldobjects, workbench, spriteName, customName, groupName, DebugBuildOption)
	-- basic conditions
	if self.invPanel then
		self.invPanel:setVisible(false)
		self.invPanel:removeFromUIManager()
		self.invPanel = false
	end
	local character = LSUtil.getValidPlayer(player)
	if not isValidInteraction(workbench, character, spriteName) then return; end
	local charData = character:getModData()
	charData.invData = charData.invData or {}
	--doNote(character, spriteName)
	-- local_data
	l_d = {}
	l_d.character = character
	l_d.skillLevel = HiddenSkills.getLevel(l_d.character, "Inventing")
	l_d.workbench = workbench
	l_d.spriteName = spriteName
	l_d.emptySprite = LSInv.getWorkbenchEmptySprite(spriteName)
	l_d.charInvData = charData.invData
	l_d.objData = workbench:getModData()
	
	l_d.charInvData['specialMax'] = l_d.charInvData['specialMax'] or 1 -- failsafe, actual specialMax defined elsewhere
	-- build cm options
	local objName = LSUtil.getMoveableDisplayName("Invention Workbench", l_d.workbench, "Invention", "Station")
	local buildOption = context:addOptionOnTop(objName);
	buildOption.iconTexture = getTexture('media/ui/IW_icon.png')
	--buildOption.toolTip = getNewTooltip(getText("Tooltip_Sculpting_AddBlock"), false, false)
	local subMenu = ISContextMenu:getNew(context);
	context:addSubMenu(buildOption, subMenu)
	--
	l_d.eureka, l_d.gloomy = l_d.skillLevel < 7 and charData.LSMoodles["Eureka"].Level > 0, charData.LSMoodles["Gloomy"].Level > 0
	l_d.block = charData.LSCooldowns['mentalBlock'] and charData.LSCooldowns['mentalBlock'] > 0
	--
	if l_d.emptySprite then -- workbench already has work in progress
		-- work is done
		local completed = isFinished(l_d.objData) and isValidWork()
		-- if author of ongoing research or production
		if not completed and isValidWork() then
			if l_d.gloomy or l_d.block then
				local text = (l_d.gloomy and "Gloomy") or "MentalBlock"
				local option = LSUtil.getDummyOption(subMenu, getText("ContextMenu_Inventions_Continue"), getText("Tooltip_"..text), getTexture('media/ui/gearsBAD_icon.png'), 'addOptionOnTop', true)
				--option.notAvailable = true
			else
				doWorkOption(context, subMenu)
			end
			if LSUtil.hasAdminRights() then
				workDebugOptions(context, subMenu)
			end
		end
		--
		-- scrap or save project option
		local noRoom = completed and not LSUtil.hasRoomForProp(l_d.character:getInventory(), l_d.character, l_d.objData.result, "", l_d.objData.resultType == "obj" or l_d.objData.resultType == "invObj")
		local optionName = (noRoom and "Get_NoRoom") or (completed and "Get") or (l_d.objData.isRuined and "Ruined") or "Scrap"
		local iconTex = (completed and "okay_icon") or "okayNo_icon"
		local scrapOption = subMenu:addOption(getText("ContextMenu_Inventions_"..optionName),completed,self.onScrapProject)
		scrapOption.toolTip = LSUtil.getNewTooltip(getText("Tooltip_InvWorkbench_"..optionName))
		scrapOption.iconTexture = getTexture('media/ui/'..iconTex..'.png')
		scrapOption.notAvailable = noRoom
		--
		return
	end
	-- workbench is empty

	-- invent
	doInventOption(context, subMenu)
	
	local knownInv, knownToys = getAllInventions(l_d.charInvData, true)
	-- load cost
	if knownInv then
		for k, v in pairs(knownInv) do
			if not l_d.charInvData[v.invName]['workCost'] then
				getOrCreateMaterialCost(l_d.character, l_d.charInvData, l_d.skillLevel, v.invName, v.invType, true)
			end
		end
	end
	
	-- research UI
	doResearchOption(context, subMenu, knownInv, knownToys)
	-- create
	doCreateOption(context, subMenu, knownInv, knownToys)
	
	--debug
	if LSUtil.hasAdminRights() then
		--local debugOption = DebugBuildOption:addOption("Inventions")
		--local debugSubMenu = DebugBuildOption:getNew(DebugBuildOption)
		--context:addSubMenu(debugOption, debugSubMenu)
		
		local allInv, allToys = getAllInventions(false, false)

		local learnAll = subMenu:addOption("(cheat) Learn All",{allInv, allToys},self.onDebug)
		learnAll.notAvailable = #knownInv >= #allInv and #knownToys >= #allToys

		local forgetAll = subMenu:addOption("(cheat) Forget All",false,self.onDebug)
		forgetAll.notAvailable = #knownInv == 0 and #knownToys == 0
	end
	
	--
	local skillOption = LSUtil.getDummyOption(subMenu, getText("UI_LSHS_Inventing").." ("..tostring(l_d.skillLevel)..")", getText("Tooltip_InventingSkill"), getTexture('media/ui/IW_icon.png'), 'addOptionOnTop', false)
end