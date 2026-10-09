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

require 'ISUI/ISWorldObjectContextMenu'

HiddenSkills = HiddenSkills or {}
ZenWellnessContextMenu = {}
ZenWellnessContextMenu.Options = {}
ZenWellnessContextMenu.Options.Yoga = {}
ZenWellnessContextMenu.Options.Meditation = {}

local function LSMGetStressReductionMulti(sandboxOption)
	local t = {
		[1] = 0.2,
		[2] = 1,
		[3] = 3,
	}
	return t[sandboxOption] or 1
end

local function LSMRemoveLevitation(actionType)
	if actionType == "Bob_meditatingMaster" or actionType == "Bob_meditatingAdvanced" then
		local t = {"Bob_meditatingC","Bob_meditating","Bob_meditatingB"}
		actionType = t[ZombRand(3)+1]
	end
	return actionType, "defaultsound"
end

local function getMeditationActionValues(level)
	--action, xp, length, boredomReduction, stressReduction, neckPain, sound, earlyProAction
	local t = {
		[1] = {{"Bob_meditatingBeginnerC","Bob_meditatingBeginner","Bob_meditatingBeginnerB"}, 9, 2000, 0, 0.1, 20, "defaultsound",false},
		[3] = {{"Bob_meditatingInterC","Bob_meditatingInterA","Bob_meditatingInterB"}, 14, 2800, 3, 0.3, 12, "defaultsound",false},
		[5] = {{"Bob_meditatingC","Bob_meditating","Bob_meditatingB"}, 36, 8000, 6, 0.5, 6, "defaultsound",false},
		[7] = {{"Bob_meditatingC","Bob_meditating","Bob_meditatingB"}, 54, 12000, 8, 1, 0, "defaultsound",{"Bob_meditatingAdvanced","Advanced"}},
		[9] = {{"Bob_meditatingAdvanced"}, 99, 20000, 12, 1.5, 0, "Advanced",{"Bob_meditatingMaster","master"}},
		[10] = {{"Bob_meditatingMaster"}, 0, 30000, 15, 2, 0, "master",false},
	}
	t[8] = t[9]; t[6] = t[7]; t[4] = t[5]; t[2] = t[3]; t[0] = t[1];
	return t[level]
end

local function LSMGetActionType(StressMultiplier, level)
	local levelArgs = getMeditationActionValues(level)
	
	local actionType = levelArgs[1][ZombRand(#levelArgs[1])+1]
	local sound = levelArgs[7]
	local neckPain = 0
	if levelArgs[6] > 0 then neckPain = ZombRand(levelArgs[6])+math.floor(levelArgs[6]/2); end
	
	if SandboxVars.LSMeditation.RemoveLevitation then actionType, sound = LSMRemoveLevitation(actionType);
	elseif levelArgs[8] and ZombRand(101) >= 98 then actionType, sound = levelArgs[8][1],levelArgs[8][2]; end
	
	return actionType, levelArgs[2], levelArgs[3], levelArgs[4], levelArgs[5]*StressMultiplier, neckPain, sound
end

local function getYogaActionValues(level)
	--pose type / added chance to fail (adds to pose nat fail chance roll) / yoga effects / pose limit
	--xp is gained by completing poses (xp amount is decided by specific pose), failing a pose grants no xp
	local t = {
		l0 = {"Beginner",50,1,2},
		l1 = {"Beginner",50,1,2},
		l2 = {"Beginner",40,1,3},
		l3 = {"Intermediate",40,2,3},
		l4 = {"Intermediate",30,2,4},
		l5 = {"Intermediate",30,2,4},
		l6 = {"Advanced",30,3,6},
		l7 = {"Advanced",20,3,6},
		l8 = {"Advanced",20,3,8},
		l9 = {"Master",10,4,10},
		l10 = {"Master",0,4,10},
	}
	return t["l"..tostring(level)]
end

local function getIsEmbarrassed(embarrassment, key)
	local t = {
		[1] = false,
		[2] = 1,
		[3] = 2,
		[4] = 3,
	}
	if not t[key] then return false; end
	return embarrassment >= t[key]
end

local function getIsExhausted(endurance, key)
	local t = {
		[1] = false,
		[2] = 0.8,
		[3] = 0.6,
		[4] = 0.3,
	}
	if not t[key] then return false; end
	return endurance <= t[key]
end

local function getMat(key)
	local t ={
		floors_rugs_01_52 = {"floors_rugs_01_53","getE"},
		floors_rugs_01_53 = {"floors_rugs_01_52","getW"},
		floors_rugs_01_54 = {"floors_rugs_01_55","getN"},
		floors_rugs_01_55 = {"floors_rugs_01_54","getS"},
		floors_rugs_01_56 = {"floors_rugs_01_57","getE"},
		floors_rugs_01_57 = {"floors_rugs_01_56","getW"},
		floors_rugs_01_58 = {"floors_rugs_01_59","getN"},
		floors_rugs_01_59 = {"floors_rugs_01_58","getS"},
		floors_rugs_01_48 = {"floors_rugs_01_49","getE"},
		floors_rugs_01_49 = {"floors_rugs_01_48","getW"},
		floors_rugs_01_50 = {"floors_rugs_01_51","getN"},
		floors_rugs_01_51 = {"floors_rugs_01_50","getS"},
	}
	return t[key]
end

local function getYogaMat(character)
	local square = character:getSquare()
	if not square then return false; end
	local matVars, adjObject
	for i=1,square:getObjects():size() do
		local obj = square:getObjects():get(i-1)
		if obj then
			local objName = obj:getSpriteName() or obj:getTextureName()
			if objName then
				matVars = getMat(objName)
				if matVars then break; end
			end
		end
	end
	if matVars then
		local objAdjSqr = square[matVars[2]](square)
		if not objAdjSqr then return false; end
		for i=1,objAdjSqr:getObjects():size() do
			local obj = objAdjSqr:getObjects():get(i-1)
			if obj then
				local objName = obj:getSpriteName() or obj:getTextureName()
				if objName and objName == matVars[1] then adjObject = obj; break; end
			end
		end
	end
	return adjObject
end

local function getNewTooltip(description)
	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	return tooltip
end

local function doRemoveBags(thisPlayer)
	for i=0,thisPlayer:getWornItems():size()-1 do
		local item = thisPlayer:getWornItems():get(i):getItem();
		if item and instanceof(item, "InventoryContainer") then
			ISTimedActionQueue.add(ISUnequipAction:new(thisPlayer, item, 50));
			--return
		end
	end
end

local function doNote(character, texture)
	local text = " <CENTRE> "..getText("IGUI_T_Yoga_Note")
	local infoText = " <LINE><H1> "..getText("IGUI_T_Yoga_Title").." <LINE> ".." <CENTRE> <IMAGECENTRE:media/ui/tutorial/Yoga_01.png> <LINE><LINE><TEXT> "..getText("IGUI_T_Yoga_Body").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body2").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body3").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body4")
	.." <LINE><LINE> "..getText("IGUI_T_Yoga_Body5").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body6").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body7").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body8").." <LINE><LINE> "..getText("IGUI_T_Yoga_Body9")
	LSNoteMng.addToQueue(getCore():getScreenWidth()-400,(getCore():getScreenHeight()/5)-50,300,50, {character, text, "tutorialYoga", texture, 4, "noteYoga", infoText, true, {5,9,32}}) -- player, mainText, queueType, tex, time, closePerm, infoPanel, noSpam, TextureCustomProps(w,h,size)
end

ZenWellnessContextMenu.Options.Yoga.canPerform = function(thisPlayer, tooltipText, tex)
	local notAvailable, embarrassment, endurance = true, thisPlayer:getModData().LSMoodles["Embarrassed"].Level, LSUtil.getCharacterMood(thisPlayer, "Endurance")
	local isEmbarrassed, isExhausted, hasMat
	if endurance <= 0.8 then
		isExhausted = getIsExhausted(endurance, SandboxVars.Yoga.Exhaustion or 3)
	end
	if embarrassment >= 1 then
		isEmbarrassed = getIsEmbarrassed(embarrassment, SandboxVars.Yoga.Embarrassment or 2)
	end
	if SandboxVars.Yoga.RequiresMat then
		hasMat = getYogaMat(thisPlayer)
	end
	
	if SandboxVars.Yoga.RequiresMat and not hasMat then tooltipText = getText("Tooltip_Yoga_MissingMat");
	elseif isExhausted then tooltipText = getText("Tooltip_Action_Exhausted");
	elseif isEmbarrassed then tooltipText = getText("ContextMenu_Embarrassed");
	else notAvailable, tex, tooltipText = false, getTexture('media/ui/yoga_icon.png'), getText("Tooltip_Yoga_Option"); end
	return notAvailable, tooltipText, tex
end

ZenWellnessContextMenu.Options.Meditation.canPerform = function(thisPlayer, tooltipText, tex)
	local notAvailable, boredom, isBored = true, LSUtil.getCharacterMood(thisPlayer, "Boredom"), false
	if boredom > 30 then isBored = true; end
	if isBored then tooltipText = " <RED>" .. getText("ContextMenu_Meditate_Bored");
	else notAvailable, tex, tooltipText = false, getTexture('media/ui/meditation_icon.png'), getText("Tooltip_Meditate_Option"); end
	return notAvailable, tooltipText, tex
end


ZenWellnessContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)
	if not player then return; end
    local buildOption, subMenu, thisPlayer = false, false, getSpecificPlayer(player)
	if not ZenWellnessContextMenu.isValid(thisPlayer) then return; end
	local isSitOnGround = thisPlayer:isSitOnGround()

	for _, option in pairs(ZenWellnessContextMenu.Options) do
		if option and option.isValid(isSitOnGround) then
			if not buildOption then buildOption = context:addOptionOnTop(getText("ContextMenu_LSBody")); buildOption.iconTexture = getTexture('media/ui/wellness_icon.png');
			subMenu = ISContextMenu:getNew(context); context:addSubMenu(buildOption, subMenu); end
			local optionName, tex, tooltipText = option.getOptionArgs()
			local menuOption = subMenu:addOptionOnTop(optionName, worldobjects, option.onAction, option, thisPlayer)
			menuOption.notAvailable, tooltipText, tex = option.canPerform(thisPlayer, tooltipText, tex)
			menuOption.iconTexture = tex
			menuOption.toolTip = getNewTooltip(tooltipText)
		end
	end
end

ZenWellnessContextMenu.isValid = function(thisPlayer)
	if not thisPlayer then return false; end
	if thisPlayer:isDead() or thisPlayer:hasTimedActions() or thisPlayer:getModData().IsSittingOnSeat or
	thisPlayer:isSeatedInVehicle() or thisPlayer:isAsleep() or thisPlayer:isSittingOnFurniture() then return false; end
	return true
end

ZenWellnessContextMenu.Options.Yoga.isValid = function(sitting)
	return not sitting
end

ZenWellnessContextMenu.Options.Meditation.isValid = function(sitting)
	return sitting
end

ZenWellnessContextMenu.Options.Meditation.getOptionArgs = function()
	return getText('ContextMenu_Meditate'), getTexture('media/ui/meditationNo_icon.png'), " <RED>" .. getText("ContextMenu_Meditate_Bored")
end

ZenWellnessContextMenu.Options.Yoga.getOptionArgs = function()
	return getText('ContextMenu_LSBody_Yoga'), getTexture('media/ui/yoga_icon_no.png'), getText("Tooltip_CantPerform")
end

ZenWellnessContextMenu.Options.Yoga.onAction = function(worldobjects, self, thisPlayer)
	if not ZenWellnessContextMenu.isValid(thisPlayer) or not self.isValid(thisPlayer:isSitOnGround()) then return; end
    ISTimedActionQueue.clear(thisPlayer)
	if not SandboxVars.Yoga.KeepBags then doRemoveBags(thisPlayer); end
	if isClient() then sendClientCommand(thisPlayer, "LS", "dropHeavyItems", {false}); else forceDropHeavyItems(thisPlayer); end
	local skill = HiddenSkills.getSkill(thisPlayer, "Yoga")
	if not skill or not skill[1] or not skill[2] or not skill[3] then HiddenSkills.resetSkill(thisPlayer, "Yoga"); print("---------- WARNING: LSYogaContextMenu.onAction - FAILED TO GET YOGA LEVEL, RUNNING SKILL RESET, RETURNING..."); return; end
	
	local actionProperties = getYogaActionValues(math.floor(skill[1]))
	
	doNote(thisPlayer, 'media/ui/yoga_icon.png')
	
    ISTimedActionQueue.add(LSYogaAction:new(thisPlayer, skill[1], actionProperties))
end

ZenWellnessContextMenu.Options.Meditation.onAction = function(worldobjects, self, thisPlayer)
	if not ZenWellnessContextMenu.isValid(thisPlayer) or not self.isValid(thisPlayer:isSitOnGround()) then return; end
    ISTimedActionQueue.clear(thisPlayer)
	-- take off worn bags if character level is low
	if thisPlayer:getPerkLevel(Perks.Meditation) < 3 and not SandboxVars.Meditation.KeepBags then doRemoveBags(thisPlayer); end
	if isClient() then sendClientCommand(thisPlayer, "LS", "dropHeavyItems", {false}); else forceDropHeavyItems(thisPlayer); end
	local level = thisPlayer:getPerkLevel(Perks.Meditation)
	local StressMultiplier = LSMGetStressReductionMulti(SandboxVars.Meditation.StrengthMultiplier or 2)
	local actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = LSMGetActionType(StressMultiplier, level)

    ISTimedActionQueue.add(LSMeditateAction:new(thisPlayer, sound, length, level, xp, boredomReduction, stressReduction, neckPain, actionType))
end

local function doLvlUpNote(character, text, texture, addW)
	 -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel, NoSpam, Texture Properties
	LSNoteMng.addToQueue(getCore():getScreenWidth()-(400+addW),(getCore():getScreenHeight()/5)-50,300+addW,50, {character, text, false, texture, 10, false, false, false, {6,10,30}})
end

HiddenSkills.onLvlUp_Yoga = function(character, level)
	local noteText, noteTex = "", "media/ui/yoga_icon.png"
	local levelStr = tostring(level)
	local addW = 0
	if level >= 10 then
		noteText = getText("UI_LSHS_Yoga_Max")
	end

	if level > 0 then
		local mpText = ""
		if isClient() then
			local mpText = getText("UI_LSHS_Yoga"..levelStr.."_mp")
			if mpText == "UI_LSHS_Yoga"..levelStr.."_mp" then mpText = ""; end
		end
		local customText = getText("UI_LSHS_Yoga"..levelStr)
		if customText == "UI_LSHS_Yoga"..levelStr then customText = ""; end
		--local starTex = " <IMAGE:media/ui/star_icon.png,16,16>"
		--local maxLevel = (level == 10 and " <SPACE>"..starTex) or ""
		noteText = " <RGB:1,1,1><CENTRE>"..getText("UI_LSHS_Yoga")..": <SPACE><RGB:1,1,0.7>"..getText("IGUI_PlayerStats_Level").." "..levelStr..
		" <LINE><TEXT><RGB:1,1,1>"..noteText..mpText..customText..getText("UI_LSHS_Yoga_General")

		--getSoundManager():playUISound("UI_Note_Appear")
		doLvlUpNote(character, noteText, noteTex, addW)
	end

	--if isClient() then sendClientCommand(character, "LS", "SavePlayerData", {charData}); end
end