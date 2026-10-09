
require 'ISAmbt/AmbtMng'
require "TimedActions/LSCleanObject"
--require "TimedActions/CleanRoomAction"
require "TimedActions/LSUnclogToilet"

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--ambt.forceReset = true - to reset this ambition for all players, even if they completed it, useful when updating ambition table params - if you don't use forceReset then changes will only apply to new characters
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function doAmbtProgress(ambt, goal)
	if not ambt[goal..'progress'] then ambt[goal..'progress'] = 0; end
	ambt[goal..'progress'] = math.floor(ambt[goal..'progress']+1)
end

local function getAmbition(character)
	if character and character:hasModData() and character:getModData().Ambitions then return character:getModData().Ambitions['LSGrimeFighter']; end
	return false
end

local ogCOActionPerform = LSCleanObject.perform;
function LSCleanObject:perform()
	local ambt = getAmbition(self.character)
	if ambt and ambt.isActive and (not ambt.completed) then
		doAmbtProgress(ambt, "goal1")
		local properties = self.thisObject:getSprite():getProperties()
		if properties and properties:has("CustomName") then
			if properties:get("CustomName") == "Toilet" then
				doAmbtProgress(ambt, "goal2")
			elseif properties:get("CustomName") == "Bath" then
				doAmbtProgress(ambt, "goal3")
			end
		end
	end
    ogCOActionPerform(self)
end

local ogCRActionPerform = CleanRoomAction.perform;
function CleanRoomAction:perform()
	local ambt = getAmbition(self.character)
	if ambt and ambt.isActive and (not ambt.completed) then
		doAmbtProgress(ambt, "goal1")
	end
    ogCRActionPerform(self)
end

local ogUTActionPerform = LSUnclogToilet.perform;
function LSUnclogToilet:perform()
	local ambt = getAmbition(self.character)
	if ambt and ambt.isActive and (not ambt.completed) then
		doAmbtProgress(ambt, "goal1")
		doAmbtProgress(ambt, "goal2")
	end
    ogUTActionPerform(self)
end

local function LSAmbtActiveIncomplete(player, ambt)
	ambt.reset = true
	local completed = true
	if not player:isAsleep() then
		for n=1, 3 do
			if not ambt['goal'..n..'progress'] then ambt['goal'..n..'progress'] = 0; end
			if ambt['goal'..n..'progress'] < ambt['goal'..n] then completed = false; end
		end
		if completed then LSAmbtMng.doComplete(player, ambt); end
	end
end

local function LSAmbtIsHidden(player, ambt)
	if not SandboxVars.Text.DividerHygiene then return; end
	if player:hasTrait(CharacterTrait.SLOPPY) then return; end
	if player:getPerkLevel(Perks.Cleaning) < 6 then return; end
	if not ambt.delayUnlock then ambt.delayUnlock = true; return; end
	LSAmbtMng.doUnlock(player, ambt)
end

LSAmbtMng.LSGrimeFighter = function(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then -- ambition was completed
		return
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --active: no penalties for every second repair
		--LSAmbtPassiveComplete() --passive: no penalty for first repair
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
