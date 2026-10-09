-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

LS_AMcache['mf'] = LS_AMcache['mf'] or (not LS_AMcache['mf_cached'] and LS_PatchUtils.hasCompatMod('mf'))

LSMoodleManager = LSMoodleManager or {};
LSMoodleManager.LSMoodles = {}
LSMoodleManager.scale = 1
LSMoodleManager.BUIInstance = false
local MoodleManagerEnabled = false
local MoodleManagerPlayerSpawn = false
--local isDTMoodleAPI = true
--local MoodleManagerPlayerDeath = false
local moodleMng_mfPatch = LS_AMcache and LS_AMcache['mf']
--[[
local vanillaMoodles = {
	"ENDURANCE",
	"ANGRY",
	"TIRED",
	"HUNGRY",
	"PANIC",
	"SICK",
	"BORED",
	"UNHAPPY",
	"STRESS",
	"THIRST",
	"PAIN",
	"WET",
	"HAS_A_COLD",
	"INJURED",
	"DRUNK",
	"UNCOMFORTABLE",
	"NOXIOUS_SMELL",
	"HYPOTHERMIA",
	"HYPERTHERMIA",
	"WINDCHILL",
	"HEAVY_LOAD",
	"FOOD_EATEN",
}
]]--
LSMoodleManager.init = function(player)

	player:getModData().LSMoodles = player:getModData().LSMoodles or {}; 
	local moodleData = player:getModData().LSMoodles
	
	local moodleProperties = require("Properties/MoodleProperties")
	
	for k,v in pairs(moodleProperties) do
		if v.name then
			if not moodleData[v.name] or
			not moodleData[v.name].Alignment or
			not moodleData[v.name].Value or
			not moodleData[v.name].Level or
			not moodleData[v.name].Icon or
			(moodleData[v.name].Icon ~= v.Icon) or
			not moodleData[v.name].Tiers then

				moodleData[v.name] = {};
				moodleData[v.name].Level = v.Level;
				moodleData[v.name].Value = v.Value;
				moodleData[v.name].Tiers = v.Tiers;
				moodleData[v.name].Icon = v.Icon;
				moodleData[v.name].Alignment = v.Alignment;

			end
		end
	end
end

function LSMoodleManager.getMoodle(moodleName)
    return LSMoodleManager.LSMoodles[moodleName];
end

LSMoodleManager.getValue = function(moodleName)
	if MoodleManagerEnabled == false then return 0 end
    local player = getPlayer()
	LSMoodleManager.init(player)
    return player:getModData().LSMoodles[moodleName].Value
end

LSMoodleManager.getLevel = function(moodleName)
    local player = getPlayer()
    LSMoodleManager.init(player)

    return player:getModData().LSMoodles[moodleName].Level
end

LSMoodleManager.setValue = function(moodleName, value)
	if MoodleManagerEnabled == false then return end
    local player = getPlayer()
    LSMoodleManager.init(player)

    player:getModData().LSMoodles[moodleName].Value = value
end

local function getMoodleTextureFromDir(moodFile, size)
	return getTexture("media/ui/moodles/"..size.."/"..moodFile) or getTexture("media/ui/moodles/"..moodFile)
end

local function getMoodleIconText(moodleLevel, moodleName, data, size)
	local tiers, textOnly, textAdd = data.LSMoodles[moodleName].Tiers, data.LSMoodles[moodleName].Icon, ""
	local moodleIcon, moodleText, moodleTooltip = moodleName..".png", "Moodles_"..moodleName.."_L1", "Moodles_"..moodleName.."_L1_desc"
	if moodleName == "WasTaughtSkill" and data.WasTaughtLast then textAdd = " ("..getText("IGUI_perks_"..tostring(data.WasTaughtLast))..")"; end
	if textOnly == 3 then --multiple tiers, 1 text, 1 icon
		local texture = getMoodleTextureFromDir(moodleIcon, size)
		return texture, getText(moodleText)..textAdd, moodleTooltip
	end
	if (moodleLevel == 4) and ((tiers == 3) or (textOnly == 1)) then
		moodleIcon, moodleText, moodleTooltip = moodleName.."3.png", "Moodles_"..moodleName.."_L4", "Moodles_"..moodleName.."_L4_desc"
	elseif (moodleLevel >= 3) and ((tiers >= 2) or (textOnly == 1)) then
		moodleIcon, moodleText, moodleTooltip = moodleName.."2.png", "Moodles_"..moodleName.."_L3", "Moodles_"..moodleName.."_L3_desc"
	elseif (moodleLevel >= 2) and ((tiers >= 1) or (textOnly == 1)) then
		moodleIcon, moodleText, moodleTooltip = moodleName.."1.png", "Moodles_"..moodleName.."_L2", "Moodles_"..moodleName.."_L2_desc"
	end
	if textOnly == 1 then moodleIcon = moodleName..".png"; --1 icon (no tiers), multiple texts
	elseif textOnly == 2 then moodleText, moodleTooltip = "Moodles_"..moodleName.."_L1", "Moodles_"..moodleName.."_L1_desc"; end --multiple icons, 1 text

	local texture = getMoodleTextureFromDir(moodleIcon, size)
	return texture, getText(moodleText)..textAdd, moodleTooltip
end

local baseGray = {}
baseGray.red = Color.gray:getRedFloat()
baseGray.green = Color.gray:getGreenFloat()
baseGray.blue = Color.gray:getBlueFloat()

function LSgetMoodleBkg(player, moodleLevel, moodleName, size)
	local alignment = player:getModData().LSMoodles[moodleName].Alignment
	local core = getCore()
	local moodleBkg = "media/ui/Moodles/"..size.."/_Moodles_BGsolid.png"
	local moodleBkgBorder = "media/ui/Moodles/"..size.."/_Moodles_BGoutline.png"
	local baseColor = core['get'..alignment..'HighlitedColor'](core)
	local colorLevel = moodleLevel/4
	local invertedCL = 1-colorLevel

	return moodleBkg, moodleBkgBorder, {baseGray.red*invertedCL+baseColor:getR()*colorLevel,baseGray.green*invertedCL+baseColor:getG()*colorLevel,baseGray.blue*invertedCL+baseColor:getB()*colorLevel}
end

local function checkWiggle(player, moodleLevel, moodleName, level)
	local wiggleBidirectional = false
	if ZombRand(2) == 0 then
		wiggleBidirectional = true
	end

	player:getModData().LSMoodles[moodleName].Level = moodleLevel
	--print("Moodle Level for "..moodleName.." is now "..moodleLevel);

	return true, wiggleBidirectional
end

local function checkMoodleScale()
	local scale = getCore():getOptionMoodleSize()
	local t = {
		{5.5, 0.5+0.5*scale},
		{6.5, 4},
	}
	local nScale
	for n=1, #t do
		if scale < t[n][1] then nScale = t[n][2]; break; end
	end
	if not nScale then nScale = 0.5+0.5*getCore():getOptionFontSizeReal(); end --nScale = (getTextManager():getFontHeight(nil)*3)/32; end
	return nScale
end

local function isMouseOverFirstOrLast(x, y, w, h)
    local mX, mY = getMouseX(), getMouseY()
    if (mX >= x) and (mY >= y) and (mX <= x + w) and (mY <= y + h) then return true; end
    return false;
end

local printOnce

local function printNewErrorLog(data)
	if printOnce or not data then return; end
	local errorText = ""
	for k, v in pairs(data) do
		errorText = errorText.."\n-----------------------"..tostring(k)
	end
	print("ERROR DETECTED: \n----------------------- at player:getModData()\n----------------------- Player ModData data was erased by a mod"..
	"\n----------------------- Mods that depend on Player ModData may not work correctly\n----------------------- Mods that depend on Player ModData may throw errors"..
	"\n----------------------- Urgent: remove the mod or mods overriding Player ModData"..
	"\n----------------------- Fetching content currently present in Player ModData (may point to the Mod or Mods source of the issue)..."..
	errorText.."\n-----------------------\n----------------------- End of Log")
	printOnce = true
end

local function printModDataError(data)
	local timestamp = os.date("[%d-%m-%y %H:%M:%S]")
	local errorMsg = timestamp .. " ERROR: General\n"
	errorMsg = errorMsg.."--------------------------------------------------\n"
	errorMsg = errorMsg.."FUNCTION: getPlayer():getModData() - ModData corruption detected\n"
	errorMsg = errorMsg.."CAUSE: A mod has erased or overwritten Player ModData.\n"
	errorMsg = errorMsg.."EFFECT: Mods relying on persistent player data may malfunction or throw attempted index errors.\n"
	errorMsg = errorMsg.."ACTION: Remove the offending mod immediately to restore functionality.\n"
	errorMsg = errorMsg.."--------------------------------------------------\n"
	errorMsg = errorMsg.."Current content of Player ModData (may reveal the interfering mod):\n"
	for k, v in pairs(data) do
		errorMsg = errorMsg .. string.format("  [%s] = %s\n", tostring(k), tostring(v))
	end
	errorMsg = errorMsg .. "--------------------------------------------------\n"
	errorMsg = errorMsg .. "END OF ERROR LOG"
	print(errorMsg)
end

LSMoodleManager.newType = function(player, moodleName)

	--if MoodleManagerEnabled == false then return end
	if player ~= nil then
	--get screen and font
    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small);
    local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium);
    local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large);
    local SCREEN_X = getCore():getScreenWidth();
    local SCREEN_Y = getCore():getScreenHeight();
    local WIDTH = 32;
    local HEIGHT = 50;
	--wiggle motion
    local enableWiggle, wiggle, wiggleX, wiggleY, wiggleBidirectional, wiggleDegradation = false, 0, 0, 0, false, 0;
	--init
    --LSMoodleManager.init(player);

    local ISMoodles = ISUIElement:derive("ISMoodles");

    ISMoodles.initialise = function(LSMoodleManager)
        ISUIElement:initialise(LSMoodleManager);
    end
	--MoodleManagerEnabled = true

    ISMoodles.render = function(LSMoodleManager)
		--if MoodleManagerEnabled == false then return end
		if MoodleManagerEnabled and not player:getModData().LSMoodles then
			printNewErrorLog(player:getModData())
			return
		end
		if MoodleManagerEnabled == true and player:getModData().LSMoodles and player:getModData().LSMoodles[moodleName] ~= nil then
        local moodleLevel = LSMoodleManager:level();
        local icon = getTexture("media/ui/moodles/"..moodleName..".png");

        if enableWiggle then
            if wiggleBidirectional then
                wiggle = wiggle - 13;
                wiggleX = wiggle * math.sin(0.5);
                if wiggle <= -30 then
                    wiggleBidirectional = false;
                    wiggleDegradation = wiggleDegradation + 1;
                end
            else 
                wiggle = wiggle + 13;
                wiggleX = wiggle * math.sin(0.5);
                if wiggle >= 30 then
                    wiggleBidirectional = true;
                    wiggleDegradation = wiggleDegradation + 1;
                end
            end
        end

        if wiggleDegradation > 2 then
            enableWiggle = false;
                
            if wiggle <= 2 and wiggle >= -2 then
                wiggleX = 0;
                wiggleDegradation = 0;
            elseif wiggle < 0 then
                wiggle = wiggle + 5;
                wiggleX = wiggle * math.sin(0.5);
            elseif wiggle > 0 then
                wiggle = wiggle - 5;
                wiggleX = wiggle * math.sin(0.5);
            end
        end

        if moodleLevel == 0 then
            if player:getModData().LSMoodles[moodleName].Level ~= 0 then
                player:getModData().LSMoodles[moodleName].Level = 0;
            end
			--LSMoodleManager:backMost()
		else
			if (player:getModData().LSMoodles[moodleName].Level ~= moodleLevel) then
				enableWiggle, wiggleBidirectional = checkWiggle(player, moodleLevel, moodleName, player:getModData().LSMoodles[moodleName].Level)
			end
			local sizeString = tostring(math.floor(LSMoodleManager:getWidth()))
			local moodleIcon, moodleText, moodleTooltip = getMoodleIconText(moodleLevel, moodleName, player:getModData(), sizeString)
			local moodleBkg, moodleBkgBorder, colors = LSgetMoodleBkg(player, moodleLevel, moodleName, sizeString)
			LSMoodleManager:drawTextureScaled(getTexture(moodleBkg), wiggleX, 0, LSMoodleManager:getWidth(), LSMoodleManager:getHeight(), 1, colors[1], colors[2], colors[3])
			LSMoodleManager:drawTextureScaled(getTexture(moodleBkgBorder), wiggleX, 0, LSMoodleManager:getWidth(), LSMoodleManager:getHeight(), 1)
            LSMoodleManager:drawTextureScaled(moodleIcon, wiggleX, 0, LSMoodleManager:getWidth(), LSMoodleManager:getHeight(), 1, 1, 1, 1)
			LSMoodleManager:mouseOverMoodle(moodleName, getText(moodleText), getText(moodleTooltip))
			--if LSMoodleManager.getIsVisible and not LSMoodleManager:getIsVisible() and ISUIHandler.allUIVisible then LSMoodleManager:setVisible(true); end
            --LSMoodleManager:bringToTop()
			--backMost()
		end

        local x, y = ISMoodles:updateLSMoodles();
        if y ~= LSMoodleManager:getY() then LSMoodleManager:setY(y) end
		if x ~= LSMoodleManager:getX() then LSMoodleManager:setX(x) end
		end
		local targetScale = 32*LSMoodleManager.scale
		LSMoodleManager:setWidth(targetScale)
		LSMoodleManager:setHeight(targetScale)
    end

	ISMoodles.update = function(LSMoodleManager)
		if not MoodleManagerEnabled or not player or not player:getModData().LSMoodles then
			return
		end
		if LSMoodleManager.getIsVisible and not LSMoodleManager:getIsVisible() and ISUIHandler.allUIVisible and
		not (MainScreen and MainScreen.instance and MainScreen.instance:isVisible()) then LSMoodleManager:setVisible(true); end
	end

    ISMoodles.mouseOverMoodle = function(LSMoodleManager, moodleName, title, description)
	--if MoodleManagerEnabled == false then return end
		if MoodleManagerEnabled == true and player:getModData().LSMoodles[moodleName] ~= nil then
        local rectWidth = 5;
		local rectHeight = 31
		local posY = (LSMoodleManager:getHeight() > 32 and (LSMoodleManager:getHeight()-rectHeight)/2) or 0

        if LSMoodleManager:isMouseOver() or isMouseOverFirstOrLast(LSMoodleManager:getX(), LSMoodleManager:getY(), LSMoodleManager:getWidth(), LSMoodleManager:getHeight()) then
            local titleLength = getTextManager():MeasureStringX(UIFont.Small, title) + 7;
            local descriptionLength = getTextManager():MeasureStringX(UIFont.Small, description) + 7;

            if titleLength >= descriptionLength then
                LSMoodleManager:drawRect(-4 - (rectWidth + titleLength), posY, rectWidth + titleLength, rectHeight, 0.6, 0, 0, 0);
            elseif titleLength <= descriptionLength then
                LSMoodleManager:drawRect(-4 - (rectWidth + descriptionLength), posY, rectWidth + descriptionLength, rectHeight, 0.6, 0, 0, 0);
            end

            LSMoodleManager:drawTextRight(title, -10, 2+posY, 1, 1, 1, 1);
            LSMoodleManager:drawTextRight(description, -10, 15+posY, 1, 1, 1, 0.7);
			if moodleName and (moodleName == "BeautyGood" or moodleName == "BeautyNeg") and not LSMoodleManager.BUIInstance then
				LSMoodleManager.BUIInstance = LSBeautyScore:new(self, getPlayer(), true)
				LSMoodleManager.BUIInstance:initialise()
				LSMoodleManager.BUIInstance:addToUIManager()
				LSMoodleManager.BUIHovering = true
			end
		elseif LSMoodleManager.BUIInstance and LSMoodleManager.BUIHovering then
			LSMoodleManager.BUIInstance:close()
			LSMoodleManager.BUIInstance = false
			LSMoodleManager.BUIHovering = false
        end
		end
    end

    ISMoodles.level = function(LSMoodleManager)
	--if MoodleManagerEnabled == false then return end
		if MoodleManagerEnabled == true and player:getModData().LSMoodles[moodleName] ~= nil then
        local value = player:getModData().LSMoodles[moodleName].Value;

        if value >= 0.7 then
            return 4
        elseif value >= 0.5 then
            return 3
        elseif value >= 0.3 then
            return 2
        elseif value >= 0.15 then
            return 1
        end

        return 0
		end
    end

    ISMoodles.updateLSMoodles = function(LSMoodleManager)
	--if MoodleManagerEnabled == false then return end
		--if MoodleManagerEnabled == true and player:getModData().LSMoodles[moodleName] ~= nil then
        local x = (getCore():getScreenWidth() - WIDTH) - 19;
        local y = getPlayerScreenTop(0)+120;
		if MoodleManagerEnabled == false then return x,y end
		
		LSMoodleManager.scale = checkMoodleScale()
		
		local WIDTHScaled = WIDTH*LSMoodleManager.scale
        x = (getCore():getScreenWidth() - WIDTHScaled) - 10;
		
        --for k, v in pairs(MoodleType) do
		local moodlesValuesForType = Registries.MOODLE_TYPE:values()
		local numMoodles = moodlesValuesForType:size()
		local moodles = player:getMoodles()
		for i = 0, numMoodles-1 do--vanilla moodles first
			local moodleType = moodlesValuesForType:get(i)
			local moodleLevel = moodles:getMoodleLevel(moodleType)
			if moodleLevel ~= 0 and (moodleType ~= MoodleType.FOOD_EATEN or moodleLevel >= 3) then
				y = y + 10 + (32*LSMoodleManager.scale)
			end
		end
		
		--for n=1,#vanillaMoodles do
		--	local moodleType = MoodleType[vanillaMoodles[n]]
		--	if moodleType then
		--		if (player:getMoodles():getMoodleLevel(moodleType) ~= 0) and
		--		(moodleType ~= MoodleType.FOOD_EATEN or player:getMoodles():getMoodleLevel(moodleType) >= 3) then
		--			y = y + 10 + (32*LSMoodleManager.scale)
		--		end
		--	end
        --end
		
        for k, v in pairs(player:getModData().LSMoodles) do--our moodles
            if k == moodleName then
                break
            else
                if v.Level ~= 0 and player:getModData().LSMoodles[moodleName].Level ~= 0 then
                    y = y + 10 + (32*LSMoodleManager.scale)
                end
            end
        end

	local sandboxmoodlepriority = SandboxVars.Debug.MoodlePriority or false
	if sandboxmoodlepriority and moodleMng_mfPatch then
		local playerMoodleData = MF.MoodleData[tostring(player)]
		local allMoodles = playerMoodleData and playerMoodleData.Moodles or {}
		for k, v in pairs(allMoodles) do--modded
			if v and v.Level ~= 0 then
				y = y + 10 + (32*LSMoodleManager.scale)
			end
		end

	end

	--[[
	if (getActivatedMods():contains('DynamicTraits') or getActivatedMods():contains('DynamicTraits[RF3]')) and isDTMoodleAPI then
		local MoodleAPI = require("MoodleAPI/MoodleAPIClient")
		if MoodleAPI and MoodleAPI.MoodleList and (#MoodleAPI.MoodleList > 0) then
			for _, moodleObj in pairs(MoodleAPI.MoodleList) do

				local lvl = moodleObj.getLevelFunc(moodleObj)
				if lvl > 0 then
					y = y + 36
				end
			end
		else
			isDTMoodleAPI = false
		end
	end
	]]--

        return x, y
		--end
    end

    ISMoodles.new = function(LSMoodleManager, width, height)
	--if MoodleManagerEnabled == false then return end
		if MoodleManagerEnabled == true and player:getModData().LSMoodles[moodleName] ~= nil then
        local x, y = ISMoodles:updateLSMoodles();
        
        local o = {};
        o = ISUIElement:new(x, y, width, height);
        setmetatable(o, LSMoodleManager);
        LSMoodleManager.__index = LSMoodleManager;
        o.borderColor = {r=0, g=0, b=0, a=0};
        o.backgroundColor = {r=0, g=0, b=0, a=0};
		o.keepOnScreen = false
        return o;
		end
    end

    return ISMoodles:new(WIDTH, HEIGHT)
	end
end


--Util to add LSMoodleManager to UI manager on game start and removes on death, then adds it back on player creation 
LSMoodleManager.createType = function(player, moodleName)
	--if not MoodleManagerPlayerSpawn then
	--	MoodleManagerPlayerSpawn = true
		--local playerData = player:getModData()
		--playerData.LSMoodles = playerData.LSMoodles or {}
	--end
	MoodleManagerEnabled = true
    local moodleTypeUI = LSMoodleManager.newType(player, moodleName)

    moodleTypeUI:addToUIManager()
    --print("CreateType")

    --local onCreatePlayer = function(index, player, moodleName)
		--LSMoodleManager.init(player)
	--	MoodleManagerEnabled = true
		
	--	local player = getPlayer()
     --   local moodleTypeUI = LSMoodleManager.newType(player, moodleName)
        --print("onCreatePlayer")

     --   moodleTypeUI:addToUIManager()
   -- end

    local onPlayerDeath = function(player, moodleName)
        moodleTypeUI:removeFromUIManager()
		MoodleManagerEnabled = false
		--LSMoodleManager = {}
		--LSMoodleManager.LSMoodles = {}
		--MoodleManagerPlayerDeath = true
		--Events.OnPlayerDeath.Remove(onPlayerDeath)
    end
    
    --Events.OnCreatePlayer.Add(onCreatePlayer)
    Events.OnPlayerDeath.Add(onPlayerDeath)
end

function onPlayerDeathLSMoodle()
	MoodleManagerPlayerSpawn = false
end

Events.OnPlayerDeath.Add(onPlayerDeathLSMoodle)

LSMoodleManager.onGameStartLSGeneralMoodles = function()

	local moodleProperties = require("Properties/MoodleProperties")
	local player = getPlayer()
	--local playerData = player:getModData()
	--playerData.LSMoodles = playerData.LSMoodles or {}
	LSMoodleManager.init(player)
	for k,v in pairs(moodleProperties) do
		if v.name then
			LSMoodleManager.createType(player, v.name);
		end
	end
	--if isClient() then sendClientCommand(player, "LS", "SavePlayerData", {player:getModData()}); end -- should prevent other mods from erasing our data
end
Events.OnCreatePlayer.Add(LSMoodleManager.onGameStartLSGeneralMoodles);
--Events.OnGameStart.Add(onGameStartLSGeneralMoodles);

if moodleMng_mfPatch then
require "MF_ISMoodle"

function MF.ISMoodle:getXYPosition()
    local size = MF.getSize()
    if size ~= self.width then
        self:setWidth(size);
        self:updateTextures(size)
    end

    local x = getPlayerScreenLeft(self.playerNum) + getPlayerScreenWidth(self.playerNum) - MF.xOffset - self:getWidth()
    local y = getPlayerScreenTop(self.playerNum) + MF.yOffset
    local distY = 10 + MF.defaultWidth * MF.scale

    if self.disable then
        if MF.verbose then print("MF.ISMoodle:getXYPosition while disabled. "..self.name) end;
        return x,y;--design by contract
    end
    
    if self:getLevel() ~= 0 then--bypass when not displayed (this is bad design)

        local moodlesValuesForType = Registries.MOODLE_TYPE:values()
        local numMoodles = moodlesValuesForType:size()
        local moodles = self.char:getMoodles()
        for i = 0, numMoodles-1 do--vanilla moodles first
            local moodleType = moodlesValuesForType:get(i)
            local moodleLevel = moodles:getMoodleLevel(moodleType)
            if moodleLevel ~= 0 and moodleType ~= MoodleType.FOOD_EATEN or moodleLevel >= 3 then
                y = y + distY;
            end
        end

        local aiteronMM = self.char:getModData().MoodleManager;--aiteron moodles second
        if aiteronMM and aiteronMM.moodles then
            local nbMoodlesAiteron = 0
            for _, moodleObj in pairs(aiteronMM.moodles) do
                --print("MF.ISMoodle:AiteronCompatibility MoodleManager "..tostring(_ or 'nil').." "..tostring(moodleObj or 'nil'));
                if moodleObj.getLevel then--there is a fake item (_ == 1) in moodles that has no getLevel
                    local lvl = moodleObj:getLevel()
                    if lvl > 0 then
                        nbMoodlesAiteron = nbMoodlesAiteron + 1
                        y = y + distY;
                    end
                end
            end
        end

		local sandboxmoodlepriority = SandboxVars.Debug.MoodlePriority or false

		if self.char:getModData().LSMoodles and not sandboxmoodlepriority then
			for k, v in pairs(self.char:getModData().LSMoodles) do--our moodles
				if v.Level ~= 0 then
					y = y + distY;
				end
			end
		end

        local _, allMoodles = self:getMoodleData()
        for k, v in pairs(allMoodles) do--modded moodles then
            if k == self.name then
                break--found
            else
                if v.Level ~= 0 then--this is why we need to share level in player mod data
                    y = y + distY;
                end
            end
        end
    end

    return x, y
end

--[[
function MF.ISMoodle:getXYPosition()
    local moodleSize = getCore():getOptionMoodleSize()
    
    local newScale = MF.scale
    if moodleSize < 5.5 then--width = 32,48,64,80,96
        newScale = 0.5+0.5*moodleSize
    elseif moodleSize < 6.5 then
        newScale = 4;--width = 128
    else
        newScale = getTextManager():getFontHeight(nil) * 3 / MF.defaultWidth;
    end
    if newScale ~= MF.scale then
        MF.scale = newScale
        if MF.verbose then print ('New Scale = '..tostring(moodleSize)..' '..tostring(newScale)..' '..tostring(getTextManager():getFontHeight(nil) * 3 / MF.defaultWidth)..' '..tostring(getTextManager():getFontHeight(nil))..' '..tostring(MF.defaultWidth*MF.scale)) end
    end
    self:setWidth(MF.defaultWidth*MF.scale);


    local x = getPlayerScreenLeft(self.playerNum) + getPlayerScreenWidth(self.playerNum) - MF.xOffset - self:getWidth()
    local y = getPlayerScreenTop(self.playerNum) + MF.yOffset
    local distY = 10 + MF.defaultWidth * MF.scale
    local numMoodles = self.char:getMoodles():getNumMoodles();

    if self.disable then
        if MF.verbose then print("MF.ISMoodle:getXYPosition while disabled. "..self.name) end;
        return x,y;--design by contract
    end
    
    if self:getLevel() ~= 0 then--bypass when not displayed (this is bad design)
        for i = 0, numMoodles-1 do--vanilla moodles first
            local moodleType = MoodleType.FromIndex(i)
            local moodleLevel = self.char:getMoodles():getMoodleLevel(moodleType)
            if moodleLevel ~= 0 and moodleType ~= MoodleType.FOOD_EATEN or moodleLevel >= 3 then
                y = y + distY;
            end
        end
        
        local aiteronMM = self.char:getModData().MoodleManager;--aiteron moodles second
        if aiteronMM and aiteronMM.moodles then
            local nbMoodlesAiteron = 0
            for _, moodleObj in pairs(aiteronMM.moodles) do
                --print("MF.ISMoodle:AiteronCompatibility MoodleManager "..tostring(_ or 'nil').." "..tostring(moodleObj or 'nil'));
                if moodleObj.getLevel then--there is a fake item (_ == 1) in moodles that has no getLevel
                    local lvl = moodleObj:getLevel()
                    if lvl > 0 then
                        nbMoodlesAiteron = nbMoodlesAiteron + 1
                        y = y + distY;
                    end
                end
            end
            --print("MF.ISMoodle:AiteronCompatibility MoodleManager "..nbMoodlesAiteron.." moodles");
        else
            --print("MF.ISMoodle:AiteronCompatibility no MoodleManager");
        end

		local sandboxmoodlepriority = SandboxVars.Debug.MoodlePriority or false

		if self.char:getModData().LSMoodles and not sandboxmoodlepriority then
			for k, v in pairs(self.char:getModData().LSMoodles) do--our moodles
				if v.Level ~= 0 then
					y = y + distY;
				end
			end
		end

        for k, v in pairs(self.char:getModData().Moodles) do--modded moodles then
            if k == self.name then
                break--found
            else
                if v.Level ~= 0 then--this is why we need to share level in player mod data
                    y = y + distY;
                end
            end
        end
    end

    return x, y
end
]]--
end
