-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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
require "TimedActions/ISReadABook"

local neuralBonus = {
	[1] = 0.9,
	[3] = 0.7,
	[4] = 0.5,
	[5] = 0.3,
}

local og_getDuration = ISReadABook.getDuration;
function ISReadABook:getDuration()
	local baseDuration = og_getDuration(self)
	if baseDuration < 100 then return baseDuration; end
	local time = baseDuration
	local headgear = self.character:getWornItems():getItem(ItemBodyLocation.HAT)
	if headgear and headgear:getType() == "NeuralHat" then -- neural hat
		local state = headgear:getVisual():getTextureChoice() or 0 -- 0 off 1 on 2 bad 3 overdrive 4 overdrive lvl2 5 overdrive lvl3
		if state == 2 then
			time = time*4
		elseif neuralBonus[state] then
			local data = headgear:getModData()
			local invData = data and data['invData']
			local efficiency = type(invData) == "table" and type(invData.efficiencyMult) == "table" and tonumber(invData.efficiencyMult[2])
			if efficiency and efficiency > 0 then
				local readBonus = state == 1 and invData.fastRead and 0.5 or 1
				local mult = math.max(0.1,math.min(1, neuralBonus[state]/efficiency))
				time = (time*readBonus)*mult
			end
		end
	else -- dunce effect
		local charData = self.character:getModData()
		local moodleLvl = charData.LSMoodles and charData.LSMoodles["Dunce"] and charData.LSMoodles["Dunce"].Level
		if moodleLvl and moodleLvl > 0 then
			time = time+(time*moodleLvl)
		end
	end
	return math.max(time, 1)
end