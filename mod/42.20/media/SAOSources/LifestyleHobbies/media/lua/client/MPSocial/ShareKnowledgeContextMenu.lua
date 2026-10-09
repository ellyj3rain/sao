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

----------- start action, if far (>1) from other player then action starts by calling the other player; the other player then moves closer and starts the joint action; if any player runs then action will end; action should not allow movement or aiming

LSSKContextMenu = {};

local function getMasterLevelAny(thisPlayer)
	if thisPlayer:getPerkLevel(Perks.Meditation) == 10 then return true; end
	if HiddenSkills.getLevel(thisPlayer,"Yoga") >= 10 then return true; end
	return false
end

local function IsOtherPlayerClose(thisPlayer, otherPlayer)

	if otherPlayer:getX() >= thisPlayer:getX() - 1 and otherPlayer:getX() < thisPlayer:getX() + 1 and
	otherPlayer:getY() >= thisPlayer:getY() - 1 and otherPlayer:getY() < thisPlayer:getY() + 1 then	
		return true
	end
	return false
end

local function getSatisfyConditions(thisPlayer, otherPlayer)

	if (otherPlayer:hasTimedActions() or otherPlayer:isSitOnGround() or thisPlayer:hasTimedActions() or thisPlayer:isSitOnGround() or (otherPlayer:getZ() ~= thisPlayer:getZ())) then	
		--print("SKCM getSatisfyConditions is FALSE")
		return false
	end

	if not thisPlayer:getModData().LSCooldowns then thisPlayer:getModData().LSCooldowns = {}; end	
	if not thisPlayer:getModData().LSCooldowns["InteractionSpam"] then thisPlayer:getModData().LSCooldowns["InteractionSpam"] = 0; end
	if thisPlayer:getModData().LSCooldowns["InteractionSpam"] == 0 then
		thisPlayer:getModData().LSCooldowns["InteractionSpam"] = thisPlayer:getModData().LSCooldowns["InteractionSpam"] + 1
	else
		thisPlayer:getModData().LSCooldowns["InteractionSpam"] = thisPlayer:getModData().LSCooldowns["InteractionSpam"] + thisPlayer:getModData().LSCooldowns["InteractionSpam"]
	end

	return true
end

local function isTeachCooldown(data)
	return data and ((data["TaughtSkill"] and data["TaughtSkill"].Value > 0) or (data["AdviceWasted"] and data["AdviceWasted"].Value > 0))
end

local function teachMeditationOption(worldobjects, subMenuSK, thisPlayer, otherPlayer)
	if thisPlayer:getPerkLevel(Perks.Meditation) ~= 10 then return; end
	local option = subMenuSK:addOption(getText("IGUI_perks_Meditation"), worldobjects, LSSKContextMenu.onSKAction, thisPlayer, otherPlayer, "SKmeditation")
	local tex = 'media/ui/SKmeditation_icon.png'
	if otherPlayer:getPerkLevel(Perks.Meditation) == 10 then
		option.notAvailable = true
		option.toolTip = LSUtil.getSimpleTooltip(" <RED>" .. getText("Tooltip_LSMP_SKIsMaster"))
		tex = 'media/ui/SKmeditationNo_icon.png'
	end
	option.iconTexture = getTexture(tex)
end

local function teachYogaOption(worldobjects, subMenuSK, thisPlayer, otherPlayer, otherPlayerInfo)
	if HiddenSkills.getLevel(thisPlayer,"Yoga") < 10 then return; end
	local option = subMenuSK:addOption(getText("ContextMenu_LSBody_Yoga"), worldobjects, LSSKContextMenu.onSKAction, thisPlayer, otherPlayer, "SKyoga")
	local tex = 'media/ui/yoga_icon.png'
	if otherPlayerInfo.hs["Yoga"] and otherPlayerInfo.hs["Yoga"][1] >= 10 then
		option.notAvailable = true
		option.toolTip = LSUtil.getSimpleTooltip(" <RED>" .. getText("Tooltip_LSMP_SKIsMaster"))
		tex = 'media/ui/yoga_icon_no.png'
	end
	option.iconTexture = getTexture(tex)
end

LSSKContextMenu.doBuildMenu = function(player, context, worldobjects, otherPlayer, otherPlayerInfo, InteractBuildOption, DebugBuildOption)

	if not otherPlayer then return; end
	local thisPlayer = getSpecificPlayer(player)	

	if thisPlayer:hasTrait(CharacterTrait.DEAF) then return; end

	if thisPlayer:isSitOnGround() then return; end
	if not getMasterLevelAny(thisPlayer) then return; end

	local SKMenu = InteractBuildOption:addOptionOnTop(getText("ContextMenu_LSMP_ShareKnowledge"));
	local subMenuSK = InteractBuildOption:getNew(InteractBuildOption);
	context:addSubMenu(SKMenu, subMenuSK)
	SKMenu.iconTexture = getTexture('media/ui/shareknowledge_icon.png')

	if isTeachCooldown(thisPlayer:getModData().LSMoodles) then
		SKMenu.notAvailable = true;
		SKMenu.toolTip = LSUtil.getSimpleTooltip(" <RED>" .. getText("Tooltip_LSMP_SKGTooRecent"))
		SKMenu.iconTexture = getTexture('media/ui/shareknowledgeNo_icon.png')
		return
	end

	if SandboxVars.Text.DividerMeditationNew then
		teachMeditationOption(worldobjects, subMenuSK, thisPlayer, otherPlayer)
		teachYogaOption(worldobjects, subMenuSK, thisPlayer, otherPlayer, otherPlayerInfo)
		
	end

end

LSSKContextMenu.onSKAction = function(worldobjects, thisPlayer, otherPlayer, skill)
	
	if not getSatisfyConditions(thisPlayer, otherPlayer) then return; end

    thisPlayer:setX(thisPlayer:getX())
    thisPlayer:setY(thisPlayer:getY())
	--thisPlayer:setLx(thisPlayer:getX())
    --thisPlayer:setLy(thisPlayer:getY())

	local startImmediately
	if IsOtherPlayerClose(thisPlayer, otherPlayer) then
		--print("SKCM startImmediately is TRUE")
		startImmediately = true
	end

	--if not thisPlayer:getModData().InteractionState then
	thisPlayer:getModData().LSInteractionState = "none"
	--end

	LSSKAction = require("TimedActions/LSSKAction")

	ISTimedActionQueue.clear(thisPlayer)
	thisPlayer:setPrimaryHandItem(nil)
	thisPlayer:setSecondaryHandItem(nil)
	if startImmediately then
		--print("SKCM starting LSSKAction")
		ISTimedActionQueue.add(LSSKAction:new(thisPlayer, otherPlayer, {skill,true}));
	else
		--print("SKCM starting LSWaitForInteraction")
		LSWaitForInteraction = require("TimedActions/LSWaitForInteraction")
		ISTimedActionQueue.add(LSWaitForInteraction:new(thisPlayer, otherPlayer, "TimedActions/LSSKAction", {skill,true}));
	end

	local TargetID = otherPlayer:getOnlineID()
	local PlayerName = tostring(thisPlayer:getUsername())

	--print("SKCM sending InteractionStart command")
	sendClientCommand(thisPlayer, "LS", "InteractionStart", {TargetID, PlayerName, "TimedActions/LSSKAction", startImmediately, skill})

end