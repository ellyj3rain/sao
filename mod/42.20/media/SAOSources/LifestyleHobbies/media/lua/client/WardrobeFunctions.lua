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

LSWardrobeContextMenu = LSWardrobeContextMenu or {}

LSWardrobeContextMenu.changeOptions = {"Casual","Formal","Gym","Sleep","Party","Summer","Winter","Work","Combat"}

LSWardrobeContextMenu.doBuildMenu = function(player, context, worldobjects, object, spriteName, customName, groupName, DebugOption)
	local character = getSpecificPlayer(player)
	if LSUtil.isCharBusy(character) then return; end
	if not LSUtil.isValidObj(object, spriteName) then return; end
	local charData = character:getModData()

	-- change clothes option
	local subMenuAOption = context:addOption(getText("ContextMenu_ChangeClothes"));
	local subMenuA = ISContextMenu:getNew(context);
	context:addSubMenu(subMenuAOption, subMenuA)
	subMenuAOption.iconTexture = getTexture('media/ui/clothes_icon.png')
	-- set clothes option
	local subMenuBOption = context:addOption(getText("ContextMenu_SetClothes"));
	local subMenuB = ISContextMenu:getNew(context);
	context:addSubMenu(subMenuBOption, subMenuB)
	subMenuBOption.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_SetOutfit"))
	subMenuBOption.iconTexture = getTexture('media/ui/setclothes_icon.png')

	local optionNaked = subMenuA:addOption(getText("ContextMenu_BirthdaySuit"), character, LSWardrobeContextMenu.onStartAction, object, "naked")
	optionNaked.iconTexture = getTexture('media/ui/naked_icon.png')

	for n=1,#LSWardrobeContextMenu.changeOptions do
		local optionName = LSWardrobeContextMenu.changeOptions[n]
		local lc = string.lower(optionName)
		local hasOutfit = charData['LSClothes'][lc] and #charData['LSClothes'][lc] > 0
		local changeOption = subMenuA:addOption(getText("ContextMenu_ChangeTo"..optionName.."Clothes"), character, LSWardrobeContextMenu.onStartAction, object, lc)
		changeOption.notAvailable = not hasOutfit
		changeOption.toolTip = not hasOutfit and LSUtil.getSimpleTooltip(" <RED>" .. getText("ContextMenu_ChangeTo"..optionName.."Clothes_Fail"))
		
		local changeTex, setTex, func = "NO_icon", "okayNo_icon", "setClothes"
		if hasOutfit then
			changeTex, setTex, func = "_icon", "okay_icon", "onSetAction"
		end
		changeOption.iconTexture = getTexture('media/ui/clothes_'..lc..changeTex..'.png')
		
		local setOption = subMenuB:addOption(getText("ContextMenu_Set"..optionName.."Clothes"), character, LSWardrobeContextMenu[func], optionName)
		setOption.iconTexture = getTexture('media/ui/'..setTex..'.png')
	end

end

LSWardrobeContextMenu.onStartAction = function(character, object, optiontype)
	if LSUtil.walkToFront(character, object) then
		local PlayerChangeClothes = require "TimedActions/PlayerChangeClothes"
		ISTimedActionQueue.add(PlayerChangeClothes:new(character, object, optiontype));
	end
end

LSWardrobeContextMenu.onSetAction = function(character, optiontype)
	getSoundManager():playUISound("UI_Button_SELECT")
	local WardrobeConfirm = WardrobeConfirm:new(character or getPlayer(), character:getPlayerNum(), optiontype)
    WardrobeConfirm:initialise();
    WardrobeConfirm:addToUIManager()
end
