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
--[[
require 'ISUI/ISWorldObjectContextMenu'

LSMeditateContextMenu = {}

local function LSMGetStressReductionMulti(sandboxOption)
	local StressReductionMultiplier = 1
	if (not sandboxOption) or (not tonumber(sandboxOption)) then print("WARNING: LSMGetStressReductionMulti failed to get sandboxOption value"); return StressReductionMultiplier; end
	if sandboxOption == 1 then
		StressReductionMultiplier = 0.2
	elseif sandboxOption == 3 then
		StressReductionMultiplier = 3
	end
	return StressReductionMultiplier
end

local function LSMRemoveLevitation(actionType, randomNumberAnim)
	if (actionType == "Bob_meditatingMaster") or (actionType == "Bob_meditatingAdvanced") then
		actionType = "Bob_meditatingC"
		if randomNumberAnim >= 64 then actionType = "Bob_meditating";
		elseif randomNumberAnim >= 34 then actionType = "Bob_meditatingB"; end
	end
	return actionType, "defaultsound"
end

local function LSMGetActionType(thisPlayer, StressMultiplier, level, sandboxOption)
	local actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = "Bob_meditatingMaster", 0, 30000, 15, 2*StressMultiplier, 0, "master"
	local randomNumberAnim = ZombRand(1, 100)
	if level < 10 then
		if level >= 8 then
			actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = "Bob_meditatingAdvanced", 99, 20000, 12, 1.5*StressMultiplier, 0, "Advanced"
			if randomNumberAnim >= 98 then actionType, sound = "Bob_meditatingMaster", "master"; end
		elseif level >= 6 then
			actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = "Bob_meditatingC", 54, 12000, 8, StressMultiplier, 0, "defaultsound"
			if randomNumberAnim >= 98 then actionType, sound = "Bob_meditatingAdvanced", "Advanced"; 
			elseif randomNumberAnim >= 64 then actionType = "Bob_meditating";
			elseif randomNumberAnim >= 34 then actionType = "Bob_meditatingB"; end
		elseif level >= 4 then
			actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = "Bob_meditatingC", 36, 8000, 6, 0.5*StressMultiplier, ZombRand(1, 5)+1, "defaultsound"
			if randomNumberAnim >= 64 then actionType = "Bob_meditating";
			elseif randomNumberAnim >= 34 then actionType = "Bob_meditatingB"; end
		elseif level >= 2 then
			actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = "Bob_meditatingInterC", 14, 2800, 3, 0.3*StressMultiplier, ZombRand(5, 10)+1, "defaultsound"
			if randomNumberAnim >= 64 then actionType = "Bob_meditatingInterA";
			elseif randomNumberAnim >= 34 then actionType = "Bob_meditatingInterB"; end
		else
			actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = "Bob_meditatingBeginnerC", 9, 2000, 0, 0.1*StressMultiplier, ZombRand(10, 20)+1, "defaultsound"
			if randomNumberAnim >= 64 then actionType = "Bob_meditatingBeginner";
			elseif randomNumberAnim >= 34 then actionType = "Bob_meditatingBeginnerB"; end
		end
	end

	if sandboxOption and (level >= 6) then actionType, sound = LSMRemoveLevitation(actionType, randomNumberAnim); end

	return actionType, xp, length, boredomReduction, stressReduction, neckPain, sound
end

local function LSMCheckConditions(thisPlayer)
	if thisPlayer:getVehicle() or thisPlayer:hasTimedActions() or thisPlayer:getModData().IsSittingOnSeat or
	(not thisPlayer:isSitOnGround()) then return false; end

	return true
end

LSMeditateContextMenu.onAction = function(worldobjects, thisPlayer, soundFile, length, level, xp, boredomReduction, stressReduction, neckPain, actionType)
	if not LSMCheckConditions(thisPlayer) then return; end
    ISTimedActionQueue.clear(thisPlayer)--do NOT trigger this during a timed action's perform - results in unexpected behavior
	forceDropHeavyItems(thisPlayer)
	
	-- take off worn bags if character level is low
	if thisPlayer:getPerkLevel(Perks.Meditation) < 3 then
		for i=0,thisPlayer:getWornItems():size()-1 do
			local item = thisPlayer:getWornItems():get(i):getItem();
			if item and instanceof(item, "InventoryContainer") then
				ISTimedActionQueue.add(ISUnequipAction:new(thisPlayer, item, 50));
				--return
			end
		end
	end
    ISTimedActionQueue.add(LSMeditateAction:new(thisPlayer, soundFile, length, level, xp, boredomReduction, stressReduction, neckPain, actionType))
end

LSMeditateContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)
    local thisPlayer = getSpecificPlayer(player)
	if not LSMCheckConditions(thisPlayer) then return; end

	local StressMultiplier = LSMGetStressReductionMulti(SandboxVars.Meditation.StrengthMultiplier)

	local actionType, xp, length, boredomReduction, stressReduction, neckPain, sound = LSMGetActionType(thisPlayer, StressMultiplier, thisPlayer:getPerkLevel(Perks.Meditation), SandboxVars.LSMeditation.RemoveLevitation)
	
	local meditateOption = context:addOption(getText("ContextMenu_Meditate"), worldobjects, LSMeditateContextMenu.onAction, thisPlayer, sound, length, level, xp, boredomReduction, stressReduction, neckPain, actionType);
	if meditateOption.notAvailable == true then
	meditateOption.iconTexture = getTexture('media/ui/meditationNo_icon.png')
	else
	meditateOption.iconTexture = getTexture('media/ui/meditation_icon.png')
	end
	
	local tooltip = ISToolTip:new();
		tooltip:initialise();
		tooltip:setVisible(false);

	if (thisPlayer:getBodyDamage():getBoredomLevel() > 30) then
		meditateOption.notAvailable = true;
		description = " <RED>" .. getText("ContextMenu_Meditate_Bored");
		tooltip.description = description
		meditateOption.toolTip = tooltip
	end
end
]]--