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

-- UI stuff
local ui = {}
ui.options = {'Main','ImpTotal','Range','HarvestMax','TreeCut','Fuel'}
ui.colorNeutral = {1, 1, 1, 0.8} --rgba
ui.colorSpecial = {0.9, 0.4, 0.8, 0.8}
ui.colorMain = {1, 1, 0.7, 1}
ui.colorWpn = {1,0.5,0,0.8}
ui.colorTreeCut = ui.colorWpn;
ui.textRX = 25

ui.isValidOptionMain = function(itemType, data)
	return true
end

ui.isValidOptionImpTotal = function(itemType, data)
	return true
end

ui.isValidOptionRange = function(itemType, data)
	return data['inventionData']['sensors']
end

ui.isValidOptionHarvestMax = function(itemType, data)
	return itemType and itemType == "Harvester"
end

ui.isValidOptionTreeCut = function(itemType, data)
	return itemType and itemType == "PowerAxe"
end

ui.isValidOptionFuel = function(itemType, data)
	return data['inventionData']['fuelUses']
end

local function getFuelText(data)
	local fuel = getText("IGUI_Inventions_Fuel")
	if data['inventionData']['fuelLiquid'] then
		local text = getText("Fluid_Name_"..data['inventionData']['fuelLiquid'])
		if text ~= "Fluid_Name_"..data['inventionData']['fuelLiquid'] then fuel = text; end
	elseif data['inventionData']['fuelTag'] then
		local text = getText("IGUI_ItemTag_"..data['inventionData']['fuelTag'])
		if text ~= "IGUI_ItemTag_"..data['inventionData']['fuelTag'] then fuel = text; end
	elseif data['inventionData']['fuelItem'] then
		local tex, itemName = LSUtil.getTexIcon(data['inventionData']['fuelItem'])
		if itemName then fuel = itemName; end
	end
	return fuel..":"
end

local function getFilledDelta(current, total)
	return math.min(1,math.max(0,math.ceil(LSUtil.getPercentage(total,current, false, false))/100))
end

local function isValidUIItem(item)
	local itemType = item and instanceof(item, "InventoryItem") and item.getType and item:getType()
	return itemType and LSInventionDefs.Items[itemType]
end

local function drawBar(panel, x, y, width, height, total, current, override)
	local filledDelta
	local filled = 0
	if override then filledDelta = 1; else filledDelta = getFilledDelta(current, total); end
	if filledDelta > 0 then filled = math.max(1, math.min(width,math.floor(filledDelta*width))); end

	panel:drawRect(x-1, y-1, width+2, height+2, 1, 0.3, 0.3, 0.3)
	panel:drawRect(x, y, filled, height, 1, 1-filledDelta, filledDelta, 0) -- a, r, g , b
	if filled == width then return; end
	panel:drawRect(x + filled, y, width - filled, height, 1, 0.45, 0.45, 0.45)
end

ui.drawTooltipInfoMain = function(panel, args) -- x, y, w, h, font, colors, data, itemType
	local text = getText('Tooltip_Inventions_Stats')
	panel:drawText(text, args[1]-5, args[2] + args[4]/2, args[6][1], args[6][2], args[6][3], args[6][4], args[5])
end

ui.drawTooltipInfoImpTotal = function(panel, args)
	local x, y, w, h, font, colors, data, itemType = args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
	
	local textL = getText("IGUI_Inventions_Stats_Imp")..":"
	local textLW = getTextManager():MeasureStringX(font, textL)
	panel:drawText(textL, x, y + h/2, colors[1], colors[2], colors[3], colors[4], font)

	local total, special = LSInv.getImprovNum(data['improvementData'], itemType, nil)	
	local textR = tostring(total)
	local textRR = "("..tostring(special)..")"
	local textRW = getTextManager():MeasureStringX(font, textR)
	local textRRW = getTextManager():MeasureStringX(font, textRR)
	panel:drawText(textR, w-(textRW+textRRW+ui.textRX), y + h/2, colors[1], colors[2], colors[3], colors[4], font)
	panel:drawText(textRR, w-(textRRW+ui.textRX), y + h/2, ui.colorSpecial[1], ui.colorSpecial[2], ui.colorSpecial[3], ui.colorSpecial[4], font)

end

ui.drawTooltipInfoRange = function(panel, args)
	local x, y, w, h, font, colors, data, itemType = args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
	local range = (data['inventionData']['sensors'] and data['inventionData']['sensors'][1]) or "none"
	local textL = getText("IGUI_Inventions_Stats_Range")..":"
	panel:drawText(textL, x, y + h/2, colors[1], colors[2], colors[3], colors[4], font)
	local textLW = getTextManager():MeasureStringX(font, textL)
	local textR = tostring(range)
	local textRW = getTextManager():MeasureStringX(font, textR)
	panel:drawText(textR, w-(textRW+ui.textRX), y + h/2, colors[1], colors[2], colors[3], colors[4], font)
end

ui.drawTooltipInfoHarvestMax = function(panel, args)
	local x, y, w, h, font, colors, data, itemType = args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
	local harvest = (data['inventionData']['sensors'] and data['inventionData']['sensors'][2]) or 0
	local textL = getText("IGUI_Inventions_Stats_Harvest")..":"
	panel:drawText(textL, x, y + h/2, colors[1], colors[2], colors[3], colors[4], font)
	local textLW = getTextManager():MeasureStringX(font, textL)
	local textR = tostring(harvest)
	local textRW = getTextManager():MeasureStringX(font, textR)
	panel:drawText(textR, w-(textRW+ui.textRX), y + h/2, colors[1], colors[2], colors[3], colors[4], font)
end

ui.drawTooltipInfoTreeCut = function(panel, args)
	local x, y, w, h, font, colors, data, itemType = args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
	--local treeDmg = panel.item:getTreeDamage()
	local treeDmg = (data['inventionData']['power'] and data['inventionData']['power'][1]) or panel.item:getTreeDamage()
	local text = getText("IGUI_Inventions_Stats_TreeDmg_Short")..":"
	panel:drawText(text, x, y + h/2, colors[1], colors[2], colors[3], colors[4], font)
	local textW = getTextManager():MeasureStringX(font, text)
	local barW = math.max(textW+x, x+89)
	drawBar(panel, barW, y+h, w-barW-7, 3, 250,treeDmg,false)
end

ui.drawTooltipInfoFuel = function(panel, args) -- x, y, w, h, font, colors, data, itemType
	local x, y, w, h, font, colors, data, itemType = args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
	local fuelText = getFuelText(data)
	panel:drawText(fuelText, x, y + h/2, colors[1], colors[2], colors[3], colors[4], font)
	local textW = getTextManager():MeasureStringX(font, fuelText)
	local barW = math.max(textW+x, x+89)
	local override = LSUtil.inventionIsFull(data['inventionData'])
	drawBar(panel, barW, y+h, w-barW-7, 3, data['inventionData']['fuelContainer'][1],data['inventionData']['fuelUses'],override) -- y = y+6.5
end

local maxW = 0
local function drawTooltipUIElements(panel, data)
	local heightMult = 0
	local validOptions = {}
	local itemType = panel.item and panel.item.getType and panel.item:getType()
	for n=1,#ui.options do
		if ui['isValidOption'..ui.options[n]](itemType, data) then
			validOptions[ui.options[n]] = true
			heightMult = heightMult+1
		end
	end
	if heightMult <= 1 then return; end

	local textFont = ISToolTip.GetFont() or UIFont.NewSmall
	local x, y = 0, panel.tooltip:getHeight()
	local width = panel.tooltip:getWidth()
	local lineH = getTextManager():getFontFromEnum(textFont):getLineHeight()

	panel:drawRect(x, y, width+maxW, (lineH+6)*heightMult, panel.backgroundColor.a, panel.backgroundColor.r, panel.backgroundColor.g, panel.backgroundColor.b) --8
	panel:drawRectBorder(x, y, width+maxW, (lineH+6)*heightMult, panel.borderColor.a, panel.borderColor.r, panel.borderColor.g, panel.borderColor.b) --8
	for n=1,#ui.options do
		if validOptions[ui.options[n]] then
			local textColor = ui['color'..ui.options[n]] or ui.colorNeutral
			ui['drawTooltipInfo'..ui.options[n]](panel, {x+10, y, width+1, lineH, textFont, textColor, data, itemType})
			y = y+lineH+1 --2
		end
	end
end

local ogToolTipIR = ISToolTipInv.render
function ISToolTipInv:render()
	ogToolTipIR(self)
	if (not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck) and isValidUIItem(self.item) and self.y > 1 and self.tooltip and self.tooltip.getX and self.tooltip:getX() - maxW > 1 then
		local data = self.item:getModData()
		local movData = data and data.movableData
		if movData and movData['inventionData'] then
			self:setX(self.tooltip:getX() - maxW)
			drawTooltipUIElements(self, movData)
		end
	end
end