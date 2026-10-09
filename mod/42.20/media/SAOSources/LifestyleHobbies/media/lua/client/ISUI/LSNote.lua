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

require "ISUI/NoteMng"
require "ISUI/ISPanelJoypad"

LSNote = ISPanelJoypad:derive("LSNote");

local function doRichTextType(x,y,w,h,customText,font,autoH,r,g,b)
	local newRichText = ISRichTextPanel:new(x, y, w, h)
	newRichText.backgroundColor = {r=0, g=0, b=0, a=0}
	newRichText.text = customText
	newRichText.defaultFont = font
	newRichText.marginLeft = 0
	newRichText.marginTop = 0
	newRichText.marginRight = 0
	newRichText.marginBottom = 10
	newRichText.autosetheight = autoH
	newRichText.textR = r
	newRichText.textG = g
	newRichText.textB = b
	return newRichText
end

function LSNote:onInfoPanelActivate()
	self.infoPanelUIElement = doRichTextType(0,0,340,600,self.infoPanel,self.font)
	self.infoPanelUIElement:initialise()
	self.infoPanelUIElement:setAnchorBottom(true); self.infoPanelUIElement:setAnchorRight(true)
	self.infoPanelWindow = self.infoPanelUIElement:wrapInCollapsableWindow("", false, false) -- title, resize, subclass
	self.infoPanelWindow:setX((getCore():getScreenWidth()/2)-170); self.infoPanelWindow:setY((getCore():getScreenHeight()/2)-300)
	self.infoPanelWindow:addToUIManager();
	self.infoPanelUIElement:setWidth(self.infoPanelWindow:getWidth()-40); self.infoPanelUIElement:setHeight(self.infoPanelWindow:getHeight()-40)
	self.infoPanelUIElement:setX(20); self.infoPanelUIElement:setY(20)
	self.infoPanelUIElement.autosetheight = false;
	self.infoPanelUIElement.clip = true
end

function LSNote:onClick(btn)
	if not self.infoPanelWindow then self:onInfoPanelActivate();
	elseif self.infoPanelWindow:getIsVisible() then self.infoPanelWindow:setVisible(false);
	else self.infoPanelWindow:setVisible(true); end
    self.infoPanelUIElement.textDirty = true
    self.infoPanelUIElement.text = self.infoPanel
    self.infoPanelUIElement:paginate();
end

function LSNote:initialise()

	if self.noSpam and self.dontShowAgain then LSNoteMng[self.dontShowAgain] = true; end -- note type won't show up again until game closes or lua is reset
	
	getSoundManager():playUISound("UI_Note_Appear")
	local btns = 0
	if self.dontShowAgain then btns = btns+1; end; if self.infoPanel then btns = btns+1; end
	local btnH = 18*btns

	self.Header = doRichTextType(40-self.spaceW, 5, self:getWidth()-(62-self.spaceW), (self.height-10),self.contentText,self.font,true)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self:addChild(self.Header)
	self.Header:paginate()
	local textPanelHeight = self.Header:getHeight()+5
	if textPanelHeight > self:getHeight() then self:setHeight(textPanelHeight); self.height = textPanelHeight; end

	if self.infoPanel then
		self.infoBtn = ISButton:new((self:getWidth())-18, 0, 18, 18, "?", self, self.onClick);
		self.infoBtn.internal = "Info";
		self.infoBtn.tooltip = getText("Tooltip_Note_Info");
		self.infoBtn.font = UIFont.Medium
		self.infoBtn:initialise();
		self.infoBtn:instantiate();
		self.infoBtn.backgroundColor = {r=0.25, g=0.5, b=0.7, a=0.7}; 
		self.infoBtn.backgroundColorMouseOver = {r=0.35, g=0.6, b=0.8, a=0.7}; 
		self.infoBtn.borderColor = {r=1, g=1, b=1, a=0.7};
		self:addChild(self.infoBtn);
	end
	
	if self.dontShowAgain then
		local btnY = 0
		if btns > 1 then btnY = 18; end
		self.closePerm = ISButton:new((self:getWidth())-18, btnY, 18, 18, "X", self, self.destroy);
		self.closePerm.internal = "ClosePerm";
		self.closePerm.tooltip = getText("Tooltip_Note_ClosePerm");
		self.closePerm.font = UIFont.Medium
		self.closePerm:initialise();
		self.closePerm:instantiate();
		self.closePerm.backgroundColor = {r=0.6, g=0, b=0.1, a=0.7}; 
		self.closePerm.backgroundColorMouseOver = {r=0.7, g=0.1, b=0.2, a=0.7}; 
		self.closePerm.borderColor = {r=1, g=1, b=1, a=0.7};
		self:addChild(self.closePerm);
	end

    self.ok = ISButton:new((self:getWidth())-18, btnH, 18, self:getHeight()-btnH, ">", self, self.destroy);
    self.ok.internal = "Close";
	self.ok.font = UIFont.Medium
    self.ok:initialise();
    self.ok:instantiate();
	self.ok.backgroundColor = {r=0, g=0.35, b=0.42, a=0.7};
	self.ok.backgroundColorMouseOver = {r=0, g=0.45, b=0.52, a=0.7};
    self.ok.borderColor = {r=1, g=1, b=1, a=0.7};
    self:addChild(self.ok);

    --self:insertNewLineOfButtons(self.button1p, self.button2p, self.button3p, self.button4p)
    self:insertNewLineOfButtons(self.ok)

end

function LSNote:close()
	if self.infoPanelWindow and self.infoPanelWindow:getIsVisible() then self.infoPanelWindow:setVisible(false); self.infoPanelWindow:removeFromUIManager(); end
	self:setVisible(false);
	self:removeFromUIManager();
	LSNoteMng.NotePanel = nil
end

function LSNote:destroy(btn)
	if btn and (btn.internal == "ClosePerm") and self.dontShowAgain then LSNoteMng.newExclude(self.dontShowAgain); end
	if self.infoPanelWindow and self.infoPanelWindow:getIsVisible() then self.infoPanelWindow:setVisible(false); self.infoPanelWindow:removeFromUIManager(); end
	self:setVisible(false);
	self:removeFromUIManager();
	LSNoteMng.NotePanel = nil
end

function LSNote:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	if self.tileTex then self:drawRect(6, 6, 30, self.oldPanelH-12, 0.4, 0.89, 0.98, 1); end -- self.height-12
	--self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
end

function LSNote:render()
	if self.tileTex then self:drawTextureScaledAspect(self.tileTex, self.tileTexData[1], self.tileTexData[2], self.tileTexData[3], self.tileTexData[3], 1, 1, 1, 1); end -- -10, -6, 64, 64
end

function LSNote:update()
	if self.infoPanelWindow and self.infoPanelWindow:getIsVisible() then self.seconds = 0; return; end
	self.seconds = self.seconds+getGameTime():getRealworldSecondsSinceLastUpdate()
	if self.seconds > self.screenTime then self:destroy(); end
	ISPanelJoypad.update(self)
end

function LSNote:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function LSNote:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:destroy(self.ok)
	end
end

function LSNote:new(x, y, w, h, args) -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel, NoSpam, Texture Properties
	local o = {}
	
	local oldPanelH = h
	local tileTex = getTexture(args[4]) or false
	local font = UIFont.NewSmall
	local addW = 0
	local spaceW = 0
	if not tileTex then spaceW = 35; end
	--local textObj = getTextManager():GetDrawTextObject(Text,w-(62-spaceW),false)
	--textObj:setDefaultFont(font)
	--local textH = textObj:getHeight()
	local textH = getTextManager():MeasureStringY(font, args[2])
	
	local largestLine = 0
	local splittedLines = LSUtil.splitLiteral(args[2], "<LINE>")
	for n=1,#splittedLines do
		local line = splittedLines[n]
		local lineW = getTextManager():MeasureStringX(font, line)
		largestLine = (lineW > largestLine and lineW) or largestLine
	end
	
local panelW = w - (62 - spaceW)
local addStep = 10

local stages = {
	{ lines = 1, minPanelW = 260, maxW = 360 },
	{ lines = 2, minPanelW = 300, maxW = 460 },
	{ lines = 3, minPanelW = 340, maxW = 560 },
	{ lines = 4, minPanelW = 380, maxW = 700 },
}

if largestLine > panelW then
	for i = 1, #stages do
		local stage = stages[i]

		local requiredPanelW = math.ceil(largestLine / stage.lines)

		-- This is the important part:
		-- don't merely fit the mathematical wrap;
		-- also enforce a visually acceptable width for that tier.
		local targetPanelW = math.max(requiredPanelW, stage.minPanelW)

		while panelW < targetPanelW and (w + addW + addStep) <= stage.maxW do
			addW = addW + addStep
			panelW = (w + addW) - (62 - spaceW)
		end

		if panelW >= requiredPanelW then
			break
		end
	end

	w = w + addW
	x = x - addW
end

	if textH+10 > h then h = textH+10; end
	o = ISPanelJoypad:new(x, y, w, h)
	setmetatable(o, self)
    self.__index = self
    o.character = args[1]
	o.name = nil
    o.backgroundColor = {r=0, g=0.55, b=0.7, a=0.7}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	o.width = w
	o.height = h
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	o.seconds = 0
	o.tileTex = tileTex
	o.tileTexData = args[9] or {-11,-7,64}
	o.font = font
	o.contentText = args[2]
	o.spaceW = spaceW
	o.textH = textH
	o.oldPanelH = oldPanelH
	o.screenTime = args[5] or 5
	o.dontShowAgain = args[6]
	o.infoPanel = args[7]
	o.infoPanelUIElement = false
	o.infoPanelWindow = false
	o.noSpam = args[8]
	o.menuSkin = "LSSims"
	--o:noBackground()
    --o.new = new;
    return o;
end