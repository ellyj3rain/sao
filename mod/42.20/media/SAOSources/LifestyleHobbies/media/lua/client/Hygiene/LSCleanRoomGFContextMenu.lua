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

local function getAmbition(character)
	if character and (not character:isDead()) and character:hasModData() and character:getModData().Ambitions then return character:getModData().Ambitions['LSGrimeFighter']; end
	return false
end

local function ambtIsValid(ambt)
	if ambt and ambt.isActive and ambt.completed then return true; end
	return false
end

local function characterIsValid(character)
	if character:getVehicle() or character:isSitOnGround() or character:hasTimedActions() then return false; end
	return true
end

local function onCRGF(worldobjects, character, ambt)
	if not ambtIsValid(ambt) then return; end
	if not characterIsValid(character) then return; end
	if character:isSneaking() then character:setSneaking(false); end

	local LSCRGF = require "TimedActions/LSCRGF"
    ISTimedActionQueue.add(LSCRGF:new(character, ambt))
end

LSCleanRoomGFContextMenu = {};
LSCleanRoomGFContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)
    local character = getSpecificPlayer(player)
	local ambt = getAmbition(character)
	if not ambtIsValid(ambt) then return; end
	if not characterIsValid(character) then return; end
	local cooldownsData = character:getModData().LSCooldowns

	if cooldownsData and ((not cooldownsData['grimefighter']) or (cooldownsData['grimefighter'] and cooldownsData['grimefighter'] <= 0)) then
		local option = context:addOptionOnTop(getText("ContextMenu_Cleaning_GF"), worldobjects, onCRGF, character, ambt);
		option.iconTexture = getTexture('media/ui/Ambitions/'..ambt.texture..'.png')
	end
end
