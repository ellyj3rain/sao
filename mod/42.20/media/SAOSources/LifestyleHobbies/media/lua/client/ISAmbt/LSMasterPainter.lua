
require 'ISAmbt/AmbtMng'
require "TimedActions/LSCanvasPaintingAction"

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player disables this ambition mid-progress
--ambt.resetAdm = true - to reset this ambition for all players, even if they completed it
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function getTargetQuality(quality, all)
	local targetQuality = "IGUI_PaintingQuality_Masterpiece"
	if quality == targetQuality then return true; end
	if not all then return false; end
	targetQuality = {"IGUI_PaintingQuality_Excellent","IGUI_PaintingQuality_Impressive","IGUI_PaintingQuality_Wondrous"}
	local hasQuality
	for n=1,#targetQuality do
		if targetQuality[n] == quality then hasQuality = true; break; end
	end
	return hasQuality
end

local function doAmbtProgress(painting, ambt, all)
	local isValidQuality = getTargetQuality(painting.quality, all)
	if isValidQuality then
		if not ambt.goal1progress then ambt.goal1progress = 0; end
		ambt.goal1progress = math.floor(ambt.goal1progress+1)
	end
end

local ogActionPerform = LSCanvasPaintingAction.perform;
function LSCanvasPaintingAction:perform()
	--print("ISFixAction:perform() called")
	if self.character and self.character:hasModData() and self.character:getModData().Ambitions then
		if self.character:getModData().Ambitions['LSMasterPainter'] then
			if self.character:getModData().Ambitions['LSMasterPainter'].completed then
				self.painting['beauty'] = math.ceil(self.painting['beauty']+(self.painting['beauty']*0.2))
			else
				doAmbtProgress(self.painting, self.character:getModData().Ambitions['LSMasterPainter'], false)
			end
		end
		if self.character:getModData().Ambitions['LSBrushmaster'] and (not self.character:getModData().Ambitions['LSBrushmaster'].completed) and
		self.character:getModData().Ambitions['LSBrushmaster'].isActive then
			doAmbtProgress(self.painting, self.character:getModData().Ambitions['LSBrushmaster'], true)
		end
	end
    ogActionPerform(self);
end

local function LSAmbtActiveIncomplete(player, ambt)
	if not player:isAsleep() then
		if not ambt.goal1progress then ambt.goal1progress = 0; end
		if ambt.goal1progress >= ambt.goal1 then LSAmbtMng.doComplete(player, ambt); end
	end
end

LSAmbtMng.LSMasterPainter = function(player, ambt)
	if ambt.isHidden then return; end -- ambition is hidden
	if ambt.completed then -- ambition was completed
		return
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --active: increases the chance of masterpiece outcomes
		--LSAmbtPassiveComplete() --passive: increases painting beauty by 20%
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end

LSAmbtMng.LSBrushmaster = function(player, ambt)
	if ambt.isHidden then return; end -- ambition is hidden
	if ambt.completed then -- ambition was completed
		return
		--if ambt.isActive then LSAmbtActiveComplete(player, ambt); end --active: faster painting
		--LSAmbtPassiveComplete() --passive: can estimate painting quality when it reaches 25 (error margin 2 better or 2 worse levels), 50(error margin 1 better and 1 worse) and 75%(error margin 1 better or 1 worse)
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end