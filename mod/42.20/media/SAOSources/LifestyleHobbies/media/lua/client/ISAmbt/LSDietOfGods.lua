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
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function ateFulfillingFood(player, ambt)
	if ambt.ateRecent then
		ambt.ateRecent = false
		return player:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) > 3
	end
	return false
end

local function LSAmbtActiveComplete(player, ambt)
	local fulfilling = ateFulfillingFood(player, ambt)
	if not fulfilling then return; end
	local hours = LSUtil.rdm_inst:random(4,6)
	player:getModData().LSCooldowns['dietofgods'] = hours
end

local function LSAmbtActiveIncomplete(player, ambt)
	if not player:isAsleep() then
		if not ambt.goal1progress then ambt.goal1progress = 0; end
		if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); return; end
		local fulfilling = ateFulfillingFood(player, ambt)
		if fulfilling then ambt.goal1progress = math.floor(ambt.goal1progress+1); end
	end
end

local function LSAmbtIsHidden(player, ambt)
	-- if your ambition starts hidden, add conditions to unlock
	if player:isAsleep() then return; end
	if not ambt.countdown then ambt.countdown = 1; end
	local fulfilling = ateFulfillingFood(player, ambt)
	if fulfilling then ambt.countdown = 0; end
	if ambt.countdown > 0 then return; end
	LSAmbtMng.doUnlock(player, ambt)
end

LSAmbtMng.LSDietOfGods = function(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt);
	elseif ambt.completed then -- ambition was completed
		--LSAmbtComplete(player, ambt)
		if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --has active bonuses
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
