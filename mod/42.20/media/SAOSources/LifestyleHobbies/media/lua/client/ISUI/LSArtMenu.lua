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
require "ISUI/ISRichTextPanel"

LSArtMenu = ISPanelJoypad:derive("LSArtMenu")
LSAMNameBox = ISTextEntryBox:derive("LSAMNameBox")

local function getObjName(obj)
	local objName = ""
	local sprite = getSprite(obj)

	if sprite then
		local props = sprite:getProperties()
		if props then
			local groupName = props:has("GroupName") and props:get("GroupName") or nil
			local name = (groupName and (groupName .. " ") or "") .. (props:has("CustomName") and props:get("CustomName") or "Moveable object")
			if name then objName = name; end
		end
	end
	return objName
end

local function getbeautyRGB(quality)
	if quality == "IGUI_PaintingQuality_Good" then return "<RGB:0,0.5,0>"; elseif quality == "IGUI_PaintingQuality_Excellent" then return "<RGB:0,0,1>"; elseif quality == "IGUI_PaintingQuality_Impressive" then return "<RGB:0.5,0,0.5>"; elseif quality == "IGUI_PaintingQuality_Wondrous" then return "<RGB:1,0.85,0>"; elseif quality == "IGUI_PaintingQuality_Masterpiece" then return "<RGB:1,0.5,0>";
	elseif quality == "IGUI_PaintingQuality_Awful" then return "<RGB:0.5,0,0>"; elseif quality == "IGUI_PaintingQuality_Poor" then return "<RGB:0.54,0.27,0.07>"; elseif quality == "IGUI_PaintingQuality_Shoddy" then return "<RGB:0.41,0.41,0.41>"; end
	return "<RGB:1,1,1>"
end

local function LSAMdoImageType(x,y,w,h,texture)
	local newImage = ISImage:new(x, y, w, h, texture)
	return newImage
end

local function LSAMdoRichTextType(x,y,w,h,customText,font,r,g,b)
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

function LSArtMenu:onClick(button)

    if button.internal == "Confirm" then
		if isClient() then
			local movableData
			local data
			if self.changeNameBox and self.changeNameBox:getInternalText() and (self.changeNameBox:getInternalText() ~= "") then
				if not movableData then movableData = {}; end
				if not data then data = {}; end
				movableData['artName'] = self.changeNameBox:getInternalText()
				data['name'] = self.changeNameBox:getInternalText()
			end
			if self.changeDescriptionBox and self.changeDescriptionBox:getInternalText() and (self.changeDescriptionBox:getInternalText() ~= "") then
				if not movableData then movableData = {}; end
				movableData['artDescription'] = self.changeDescriptionBox:getInternalText()
			end
	
			if data or movableData then sendClientCommand(button.onClickArgs[1], "LS", "ModifyItemData", {button.onClickArgs[2], movableData, data}); end

		else
			if self.changeNameBox and self.changeNameBox:getInternalText() and (self.changeNameBox:getInternalText() ~= "") then
				button.onClickArgs[2]:getModData().movableData['artName'] = self.changeNameBox:getInternalText()
				button.onClickArgs[2]:getModData().name = button.onClickArgs[2]:getModData().movableData['artName']
			end
			if self.changeDescriptionBox and self.changeDescriptionBox:getInternalText() and (self.changeDescriptionBox:getInternalText() ~= "") then
				button.onClickArgs[2]:getModData().movableData['artDescription'] = self.changeDescriptionBox:getInternalText()
			end
		end

		local pdata = getPlayerData(button.onClickArgs[1]:getPlayerNum())
		if pdata then
			pdata.playerInventory:refreshBackpacks()
			pdata.lootInventory:refreshBackpacks()
		end
	end
	self:close()
end

--
function LSArtMenu:initialise()
	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer and specificPlayer:getModData().LSArtMenuOverlayPanelSkin and tostring(specificPlayer:getModData().LSArtMenuOverlayPanelSkin) then
		self.menuSkin = specificPlayer:getModData().LSArtMenuOverlayPanelSkin
	end

	local artworkName
	local closeTooltipText = "Tooltip_LSAM_Close"

	self.backgroundImage = LSAMdoImageType(9,9,self:getWidth(),self:getHeight(),getTexture("media/textures/LSAM/"..self.menuSkin.."/LSAMBKG.png"))
	self.backgroundImage:initialise()
	self:addChild(self.backgroundImage)

	self.Header = LSAMdoRichTextType(50, 40, 350, 40,"<H1> ".."<RGB:0,0,1>Artwork Review",UIFont.Large)
    self.Header.clip = true
	self.Header:initialise()
	self.Header:instantiate()
	self.Header:paginate();
	self:addChild(self.Header)

	if self.canRename then
	
	artworkName = self.artworkItem:getName()
	
	self.Header3 = LSAMdoRichTextType(60, 85, 330, 26,"<RGB:0.1,0,0.5>Give this piece a Title:",UIFont.Large)
	self.Header3:initialise()
	self.Header3:instantiate()
	self.Header3:paginate();
	self:addChild(self.Header3)

	self.changeNameBox = LSAMNameBox:new(artworkName, 80, 115, 295, 26)
	self.changeNameBox.backgroundColor = {r=0, g=0, b=0, a=0.2}
	self.changeNameBox.borderColor = {r=0.02, g=0.18, b=0.32, a=0.6}
	self.changeNameBox.font = UIFont.Medium
    self.changeNameBox:initialise();
    self.changeNameBox:instantiate();
	self.changeNameBox:setMaxTextLength(35)
    self:addChild(self.changeNameBox);

	self.changeDescriptionBox = LSAMNameBox:new("", 68, 453, 320, 95)
	self.changeDescriptionBox.backgroundColor = {r=0, g=0, b=0, a=0.2}
	self.changeDescriptionBox.borderColor = {r=0.02, g=0.18, b=0.32, a=0.6}
	self.changeDescriptionBox.font = UIFont.Medium
    self.changeDescriptionBox:initialise();
    self.changeDescriptionBox:instantiate();
	--self.changeDescriptionBox:setHasFrame(true)
	self.changeDescriptionBox:setMultipleLine(true)
	self.changeDescriptionBox:setMaxLines(4)
	self.changeDescriptionBox:setMaxTextLength(160)
    self:addChild(self.changeDescriptionBox);

	self.confirmChangesButton = ISButton:new(411, 561, 29, 29, "", self, self.onClick)
	self.confirmChangesButton.internal = "Confirm"
	self.confirmChangesButton.onClickArgs = {specificPlayer, self.artworkItem, nil, nil}
	self.confirmChangesButton:initialise()
	self.confirmChangesButton:instantiate()
	self.confirmChangesButton.displayBackground = false
	self.confirmChangesButton.borderColor = {r=1, g=1, b=1, a=0};
	self.confirmChangesButton:setImage(getTexture("media/textures/LSAM/"..self.menuSkin.."/LSAM_ConfirmBT.png"))
	self.confirmChangesButton:setTooltip(getText("Tooltip_LSAM_Confirm"))
	self:addChild(self.confirmChangesButton)

	else
		artworkName = getObjName(self.spriteName)
		closeTooltipText = "Tooltip_LSAM_CloseSimple"
		
		if artworkName ~= "" then artworkName = Translator.getMoveableDisplayName(artworkName); end
	
		self.Header3 = LSAMdoRichTextType(60, 85, 330, 26,"<RGB:0.1,0,0.5>Piece Title:",UIFont.Large)
		self.Header3:initialise()
		self.Header3:instantiate()
		self.Header3:paginate();
		self:addChild(self.Header3)

		local customTitleName = artworkName
		if self.artworkItem:getModData().movableData['artName'] then customTitleName = self.artworkItem:getModData().movableData['artName']; end

		self.Header4 = LSAMdoRichTextType(80, 115, 295, 26,customTitleName,UIFont.Large)
		self.Header4:initialise()
		self.Header4:instantiate()
		self.Header4:paginate();
		self:addChild(self.Header4)

		if self.artworkItem:getModData().movableData['artDescription'] then
			self.DescriptionText = LSAMdoRichTextType(68, 453, 320, 95,self.artworkItem:getModData().movableData['artDescription'],UIFont.Medium)
			self.DescriptionText.maxLines = 4
			self.DescriptionText:initialise()
			self.DescriptionText:instantiate()
			self.DescriptionText:paginate();
			self:addChild(self.DescriptionText)
		end
	end

	self.DescriptionName = LSAMdoRichTextType(240, 193, 150, 26,"<RGB:0.1,0,0.5>Default Name: ",UIFont.Medium)
	self.DescriptionName:initialise()
	self.DescriptionName:instantiate()
	self.DescriptionName:paginate();
	self:addChild(self.DescriptionName)

	self.DescriptionName2 = LSAMdoRichTextType(245, 213, 150, 26,artworkName,UIFont.Medium)
	self.DescriptionName2:initialise()
	self.DescriptionName2:instantiate()
	self.DescriptionName2:paginate();
	self:addChild(self.DescriptionName2)

	self.DescriptionBeauty = LSAMdoRichTextType(240, 237, 150, 26,"<RGB:0.1,0,0.5>Beauty Value: ",UIFont.Medium)
	self.DescriptionBeauty:initialise()
	self.DescriptionBeauty:instantiate()
	self.DescriptionBeauty:paginate();
	self:addChild(self.DescriptionBeauty)

	local RGB = getbeautyRGB(self.artworkItem:getModData().movableData['artQuality'])

	self.DescriptionBeauty2 = LSAMdoRichTextType(245, 257, 150, 26,RGB..tostring(self.artworkItem:getModData().movableData['artBeauty']),UIFont.Medium)
	self.DescriptionBeauty2:initialise()
	self.DescriptionBeauty2:instantiate()
	self.DescriptionBeauty2:paginate();
	self:addChild(self.DescriptionBeauty2)

	self.DescriptionQuality = LSAMdoRichTextType(240, 282, 150, 26,"<RGB:0.1,0,0.5>Artwork Quality: ",UIFont.Medium)
	self.DescriptionQuality:initialise()
	self.DescriptionQuality:instantiate()
	self.DescriptionQuality:paginate();
	self:addChild(self.DescriptionQuality)

	self.DescriptionQuality2 = LSAMdoRichTextType(245, 302, 150, 26,RGB..getText(self.artworkItem:getModData().movableData['artQuality']),UIFont.Medium)
	self.DescriptionQuality2:initialise()
	self.DescriptionQuality2:instantiate()
	self.DescriptionQuality2:paginate();
	self:addChild(self.DescriptionQuality2)

	self.DescriptionStyle = LSAMdoRichTextType(240, 327, 150, 26,"<RGB:0.1,0,0.5>Style: ",UIFont.Medium)
	self.DescriptionStyle:initialise()
	self.DescriptionStyle:instantiate()
	self.DescriptionStyle:paginate();
	self:addChild(self.DescriptionStyle)

	self.DescriptionStyle2 = LSAMdoRichTextType(245, 347, 150, 26,getText("IGUI_PaintingStyle"..self.artworkItem:getModData().movableData['artStyle']),UIFont.Medium)
	self.DescriptionStyle2:initialise()
	self.DescriptionStyle2:instantiate()
	self.DescriptionStyle2:paginate();
	self:addChild(self.DescriptionStyle2)

	self.DescriptionAuthor = LSAMdoRichTextType(240, 373, 200, 26,"<RGB:0.1,0,0.5>Author: ",UIFont.Medium)
	self.DescriptionAuthor:initialise()
	self.DescriptionAuthor:instantiate()
	self.DescriptionAuthor:paginate();
	self:addChild(self.DescriptionAuthor)

	self.DescriptionAuthor2 = LSAMdoRichTextType(245, 393, 200, 26,self.artworkItem:getModData().movableData['artAuthor'],UIFont.Medium)
	self.DescriptionAuthor2:initialise()
	self.DescriptionAuthor2:instantiate()
	self.DescriptionAuthor2:paginate();
	self:addChild(self.DescriptionAuthor2)

	self.DescriptionDescription = LSAMdoRichTextType(68, 430, 200, 26,"<RGB:0.1,0,0.5>Description: ",UIFont.Medium)
	self.DescriptionDescription:initialise()
	self.DescriptionDescription:instantiate()
	self.DescriptionDescription:paginate();
	self:addChild(self.DescriptionDescription)


    self.CloseButton = ISButton:new(18, 18, 29, 29, "", self, self.onClick);
    self.CloseButton.internal = "Close";
    self.CloseButton:initialise();
    self.CloseButton:instantiate();
	self.CloseButton.displayBackground = false
	self.CloseButton.borderColor = {r=1, g=1, b=1, a=0};
	self.CloseButton:setImage(getTexture("media/textures/LSAM/"..self.menuSkin.."/LSAM_CloseBT.png"))
	self.CloseButton:setTooltip(getText(closeTooltipText))
    self:addChild(self.CloseButton);


end


function LSArtMenu:update()
	if not self.canRename then
		if ((self.character:getX() > (self.artworkItem:getX()+4)) or (self.character:getX() < (self.artworkItem:getX()-4))) or
		((self.character:getY() > (self.artworkItem:getY()+4)) or (self.character:getY() < (self.artworkItem:getY()-4))) or
		(self.character:getZ() ~= self.artworkItem:getZ()) then
			self:destroy()
		end
	end
end

function LSArtMenu:render()
	ISPanelJoypad.render(self);

	self:drawTextureScaledAspect(getTexture(self.spriteName), 59, 185, 164, 234, 1.0, 1.0, 1.0, 1.0) -- 55, 110, 192, 384
end

function LSArtMenu:close()
	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer:getModData().LSArtMenuOverlayPanel ~= "changeSkin" then
		specificPlayer:getModData().LSArtMenuOverlayPanel = false
	end
	self:setVisible(false);
	self:removeFromUIManager();
	-- v joypad compat patch
	setJoypadFocus(specificPlayer:getPlayerNum(), nil)
end

function LSArtMenu:destroy()
	local specificPlayer = getSpecificPlayer(0)
	specificPlayer:getModData().LSArtMenuOverlayPanel = false
	self:setVisible(false);
	self:removeFromUIManager();
end


function LSArtMenu:new(X, Y, Width, Height, Player, Art, SpriteName, Rename)
	local o = ISPanelJoypad:new(X, Y, Width, Height)
	setmetatable(o, self)
	self.__index = self
	local playerObj = Player and getSpecificPlayer(Player) or nil
    o.character = getSpecificPlayer(0)
	o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.98}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.artworkItem = Art
	o.spriteName = SpriteName
	o.canRename = Rename
	o:noBackground()
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.panelH = Height
	o.panelW = Width
	o.menuSkin = "LSSims"
	return o
end





