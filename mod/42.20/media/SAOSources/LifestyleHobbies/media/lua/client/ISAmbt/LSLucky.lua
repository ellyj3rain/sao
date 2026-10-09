--[[
require 'ISAmbt/AmbtMng'
require "TimedActions/LSFTAction"

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--ambt.forceReset = true - to reset this ambition for all players, even if they completed it, useful when updating ambition table params - if you don't use forceReset then changes will only apply to new characters
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local ambtTable = require 'Properties/Player/LSAmbitions'
table.insert(ambtTable, {name="LSLucky",cat="Survival",texture="LSLucky",goal1=7,goal2=0,goal3=0,goal4=0,goal5=0,goal6=0,isHidden=true,isPassive=true,disable=false,resetF=false,reqHas=true,reqNotHas=true})

local function doAmbtProgress(ambt, goal, positive)
	if not ambt[goal..'progress'] then ambt[goal..'progress'] = 0; end
	if not positive then ambt[goal..'progress'] = 0; else ambt[goal..'progress'] = math.floor(ambt[goal..'progress']+1); end
end

local function getAmbition(character)
	if character and character:hasModData() and character:getModData().Ambitions then return character:getModData().Ambitions['LSLucky']; end
	return false
end

local ogFTActionPerform = LSFTAction.perform;
function LSFTAction:perform()
	local ambt = getAmbition(self.character)
	if ambt and (not ambt.isHidden) and (not ambt.completed) then
		doAmbtProgress(ambt, "goal1", self.isPositive)
	elseif ambt and ambt.isHidden then
		ambt.doUnlock = true
	end
    ogFTActionPerform(self)
end

local ogFTActionStop = LSFTAction.stop;
function LSFTAction:stop()
	if self.thirdPhase then
		local ambt = getAmbition(self.character)
		if ambt and (not ambt.isHidden) and (not ambt.completed) then
			doAmbtProgress(ambt, "goal1", self.isPositive)
		end
	end
    ogFTActionStop(self)
end

local function LSAmbtActiveIncomplete(player, ambt)
	local completed = true
	if not player:isAsleep() then
		if player:hasTrait(CharacterTrait.LUCKY) then LSAmbtMng.doComplete(player, ambt); return; end
		if not ambt['goal1progress'] then ambt['goal1progress'] = 0; end
		if ambt['goal1progress'] < ambt['goal1'] then completed = false; end
		if completed then LSAmbtMng.doComplete(player, ambt); end
	end
end

local function LSAmbtComplete(player, ambt)
	if player:hasTrait(CharacterTrait.LUCKY) then return; end
	if player:hasTrait(CharacterTrait.UNLUCKY) then
		player:getTraits():remove("Unlucky")
		HaloTextHelper.addTextWithArrow(player, getText("UI_trait_unlucky"), false, HaloTextHelper.getColorRed())
	end
	player:getTraits():add("Lucky")
	HaloTextHelper.addTextWithArrow(player, getText("UI_trait_lucky"), true, HaloTextHelper.getColorGreen())
end

local function LSAmbtIsHidden(player, ambt)
	--if not SandboxVars.Text.DividerHygiene then return; end
	if player:hasTrait(CharacterTrait.LUCKY) then return; end
	if not ambt.doUnlock then return; end
	if not ambt.delayUnlock then ambt.delayUnlock = true; return; end
	LSAmbtMng.doUnlock(player, ambt)
end

LSAmbtMng.LSLucky = function(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then -- ambition was completed
		LSAmbtComplete(player, ambt)
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --active: no penalties for every second repair
		--LSAmbtPassiveComplete() --passive: no penalty for first repair
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
]]--