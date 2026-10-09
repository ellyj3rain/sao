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

LSMoodleManager = LSMoodleManager or {}
LSBeautyScoreIcon = ISPanel:derive("LSBeautyScoreIcon")
LSBeautyScoreIconBtn = ISButton:derive("LSBeautyScoreIconBtn")
local LSBeautyScoreIconInit

function LSBeautyScoreIcon:onClick(btn)

end

function LSBeautyScoreIconBtn:onRightMouseUp(x, y)
	self.parent.hideIcon = true
	getSoundManager():playUISound("UIActivateButton")
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

function LSBeautyScoreIcon:onInfoPanelActivate()
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

function LSBeautyScoreIconBtn:onMouseDoubleClick(x, y)
	if not self.parent.infoPanelWindow then self.parent:onInfoPanelActivate();
	elseif self.parent.infoPanelWindow:getIsVisible() then self.parent.infoPanelWindow:setVisible(false);
	else self.parent.infoPanelWindow:setVisible(true); end
    self.parent.infoPanelUIElement.textDirty = true
    self.parent.infoPanelUIElement.text = self.parent.infoPanel
    self.parent.infoPanelUIElement:paginate();

	getSoundManager():playUISound("UI_Note_Appear")
end

function LSBeautyScoreIcon:onBtnMouseDown(x, y)
    if not self.moveWithMouse then return; end
    if not self:getIsVisible() then
        return;
    end
    if not self:isMouseOver() then
        return -- this happens with setCapture(true)
    end
    
    self.downX = x;
    self.downY = y;
    self.moving = true;
    self:bringToTop();
end

function LSBeautyScoreIcon:initialize()
	ISUIElement.initialise(self)

	self.beautyIcon = LSBeautyScoreIconBtn:new(0,0,self:getWidth(),self:getHeight(), "", self, self.onClick, self.onBtnMouseDown)
	self.beautyIcon:initialise()
	self.beautyIcon:instantiate()
	self.beautyIcon.displayBackground = false
	self.beautyIcon.borderColor = {r=1, g=1, b=1, a=0};
	self.beautyIcon:setImage(getTexture("media/textures/BeautyIcon_Off.png"))
	self.beautyIcon:setTooltip(getText("Tooltip_Art_BeautyInfo"))
	--self.beautyIcon.onRightMouseUp = self.onRightMouseUp
	self:addChild(self.beautyIcon)

end

function LSBeautyScoreIcon:prerender()

end

function LSBeautyScoreIcon:render()

end


function LSBeautyScoreIcon:update()
	if not ISUIHandler.allUIVisible and self.hideIcon then self.hideIcon = false; end
	if self.hideIcon or not MainScreen.instance or not MainScreen.instance.inGame or MainScreen.instance:getIsVisible() or (MainScreen.instance.inGame and not SandboxVars.Text.DividerArt) then
		if self:getIsVisible() then self:setVisible(false); end
		return
	end
	if not self:getIsVisible() and ISUIHandler.allUIVisible then self:setVisible(true); end

	if self:isMouseOver() then
		if not LSMoodleManager.BUIInstance then
			LSMoodleManager.BUIInstance = LSBeautyScore:new(self, self.character, false)
			LSMoodleManager.BUIInstance:initialise()
			LSMoodleManager.BUIInstance:addToUIManager()
		end
		if self.beautyIcon.image ~= getTexture("media/textures/BeautyIcon_On.png") then
			self.beautyIcon:setImage(getTexture("media/textures/BeautyIcon_On.png"))
		end
	elseif self.beautyIcon.image ~= getTexture("media/textures/BeautyIcon_Off.png") then
		self.beautyIcon:setImage(getTexture("media/textures/BeautyIcon_Off.png"))
	end
	
	self.timer = self.timer+1
	if self.timer > self.interval then
		local x, y = self:getX(), self:getY()
		if self.ogX ~= x or self.ogY ~= y then
			LSUIPrefs.updatePref("LSBeautyScoreIcon", x, y)
			self.ogX, self.ogY = x, y
		end
		self.timer = 0
	end
end

function LSBeautyScoreIcon:onResolutionChange()
	local newX, newY = getCore():getScreenWidth()-self.offsetX, getCore():getScreenHeight()-self.offsetY
	self:setX(newX)
	self:setY(newY)
	self.ogX, self.ogY = newX, newY
end

function LSBeautyScoreIcon:OnDeath()
	self:setVisible(false)
	self:removeFromUIManager()
	LSBeautyScoreIconInit = nil
end

local function BeautyScoreOnDeath()
	if not LSBeautyScoreIconInit then return; end
	LSBeautyScoreIconInit:OnDeath()
end

function LSBeautyScoreIcon:new(Player)
	local offsetX, offsetY = 75, 120
	local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
	local cX, cY = LSUIPrefs.getPrefs("LSBeautyScoreIcon")
	local x, y
	if cX and cY and cX < screenW and cY < screenH then
		x, y = cX, cY
	else
		x, y = screenW-offsetX, screenH-offsetY
	end
	local o = {}
	o = ISPanel:new(x, y, 32, 32)
	setmetatable(o, self)
	self.__index = self
	o.character = Player
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
	o.moveWithMouse = true
	o.offsetX = offsetX
	o.offsetY = offsetY
	o.ogX = x
	o.ogY = y
	o.timer = 0
	o.interval = 7200
	o.hideIcon = false
	o.infoPanelWindow = false
	o.infoPanelUIElement = false
	o.infoPanel = " <LINE><H1> "..getText("IGUI_T_Beauty_Title").." <LINE> ".." <IMAGECENTRE:media/ui/tutorial/Beauty_01.png> <LINE><LINE><TEXT> "..getText("IGUI_T_Beauty_Body").." <LINE><LINE> "..getText("IGUI_T_Beauty_Body2").." <LINE><LINE> "..getText("IGUI_T_Beauty_Body3").." <LINE><LINE> "..getText("IGUI_T_Beauty_Body4").." <LINE><LINE> "..getText("IGUI_T_Beauty_Body5").." <LINE><LINE> "..getText("IGUI_T_Beauty_Body6")
	o.font = UIFont.NewSmall
	return o
end

local function LSCreateBeautyScoreIcon(idx,player)
	if not SandboxVars.Text.DividerArt then return; end
	if LSBeautyScoreIconInit then return; end
	LSBeautyScoreIconInit = LSBeautyScoreIcon:new(player)
	LSBeautyScoreIconInit:initialize()
	LSBeautyScoreIconInit:addToUIManager()
end

local function LSRCBeautyScoreIcon()
	if not LSBeautyScoreIconInit or not SandboxVars.Text.DividerArt then return; end
	LSBeautyScoreIconInit:onResolutionChange()
end

Events.OnPlayerDeath.Add(BeautyScoreOnDeath)
Events.OnCreatePlayer.Add(LSCreateBeautyScoreIcon)
Events.OnResolutionChange.Add(LSRCBeautyScoreIcon)