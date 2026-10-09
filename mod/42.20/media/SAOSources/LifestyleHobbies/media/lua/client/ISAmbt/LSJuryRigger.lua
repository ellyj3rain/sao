
require 'ISAmbt/AmbtMng'

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--ambt.forceReset = true - to reset this ambition for all players, even if they completed it, useful when updating ambition table params - if you don't use forceReset then changes will only apply to new characters
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function LSAmbtActiveIncomplete(player, ambt)
	ambt.reset = true
	if not player:isAsleep() then
		if not ambt.goal1progress then ambt.goal1progress = 0; end
		if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); end
	end
end

local function LSAmbtIsHidden(player, ambt)
	if player:getPerkLevel(Perks.Maintenance) < 6 then return; end
	if not ambt.delayUnlock then ambt.delayUnlock = true; return; end
	LSAmbtMng.doUnlock(player, ambt)
end

LSAmbtMng.LSJuryRigger = function(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then -- ambition was completed
		return
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --active: no penalties for every second repair
		--LSAmbtPassiveComplete() --passive: no penalty for first repair
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
