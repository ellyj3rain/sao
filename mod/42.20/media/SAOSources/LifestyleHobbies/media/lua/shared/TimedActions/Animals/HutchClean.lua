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

local function isValidHook()
	return SandboxVars.Text.DividerHygiene
end

local function getNewTimePerDirt(character, ogTime, mult)
	local baseRate = (character:hasTrait(CharacterTrait.SLOPPY) and ogTime+5) or ogTime
	local skillBuff = character:getPerkLevel(Perks.Cleaning)*mult
	return math.max(mult,math.floor(baseRate-skillBuff))
end

local ogCleanFloorGetDuration = ISHutchCleanFloor.getDuration
function ISHutchCleanFloor:getDuration()
	if isValidHook() then self.timePerDirt = getNewTimePerDirt(self.character, 20, 2); end
	return ogCleanFloorGetDuration(self)
end

local ogCleanNestGetDuration = ISHutchCleanNest.getDuration
function ISHutchCleanNest:getDuration()
	if isValidHook() then self.timePerDirt = getNewTimePerDirt(self.character, 10, 1); end
	return ogCleanNestGetDuration(self)
end

local ogCleanFloorStart = ISHutchCleanFloor.start
function ISHutchCleanFloor:start()
	if not isClient() and isValidHook() then
		self.timePerDirt = getNewTimePerDirt(self.character, 20, 2)
	end
	ogCleanFloorStart(self)
end

local ogCleanNestStart = ISHutchCleanNest.start
function ISHutchCleanNest:start()
	if not isClient() and isValidHook() then
		self.timePerDirt = getNewTimePerDirt(self.character, 10, 1)
	end
	ogCleanNestStart(self)
end

local ogCleanFloorServerStart = ISHutchCleanFloor.serverStart
function ISHutchCleanFloor:serverStart()
	if isValidHook() then self.timePerDirt = getNewTimePerDirt(self.character, 20, 2); end
	ogCleanFloorServerStart(self)
end

local ogCleanNestServerStart = ISHutchCleanNest.serverStart
function ISHutchCleanNest:serverStart()
	if isValidHook() then self.timePerDirt = getNewTimePerDirt(self.character, 10, 1); end
	ogCleanNestServerStart(self)
end