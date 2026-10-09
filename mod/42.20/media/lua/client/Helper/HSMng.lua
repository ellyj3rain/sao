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

HiddenSkills = HiddenSkills or {}

HiddenSkills.skills = {
	['Yoga'] = true,
	['Inventing'] = true,
	['PingPong'] = true,
	['Pool'] = false,
	['Arcade'] = false,
}

HiddenSkills.doHaloGood = function(character, text, skill)
	local haloText = getText("UI_LSHS_"..skill)..": "..text
	HaloTextHelper.addTextWithArrow(character, haloText, true, 170, 255, 150)
end

HiddenSkills.doHaloBad = function(character, text, skill)
	local haloText = getText("UI_LSHS_"..skill)..": "..text
	HaloTextHelper.addTextWithArrow(character, haloText, false, 255, 120, 120)
end

local function getNewValues(level)
	local t = {
		[0] = 100,
		[1] = 250,
		[2] = 500,
		[3] = 750,
		[4] = 1000,
		[5] = 1250,
		[6] = 1750,
		[7] = 3000,
		[8] = 4000,
		[9] = 9000,
		[10] = 9000,
	}
	return {level,0,t[level]}
end

HiddenSkills.getSkill = function(character, skill)
	if not character or not skill or not HiddenSkills.skills[skill] then print("------- WARNING: HiddenSkills.getSkill - FAILED TO GET SKILL "..tostring(skill)); return false; end
	local modData = character:getModData()
	if not modData.LSHiddenSkills then modData.LSHiddenSkills = {}; end
	if not modData.LSHiddenSkills[skill] then modData.LSHiddenSkills[skill] = {0,0,100}; end -- level, xp, xp for next level
	return modData.LSHiddenSkills[skill]
end

HiddenSkills.resetSkill = function(character, skill)
	if not character or not skill or not HiddenSkills.skills[skill] then print("------- WARNING: HiddenSkills.resetSkill - FAILED TO RESET SKILL "..tostring(skill)); return false; end
	local modData = character:getModData()
	if not modData.LSHiddenSkills then modData.LSHiddenSkills = {}; end
	modData.LSHiddenSkills[skill] = {0,0,100}
	print("------- WARNING: HiddenSkills.resetSkill - SKILL "..tostring(skill).." RESET TO DEFAULT VALUES")
end

HiddenSkills.getLevel = function(character, skill)
	local hiddenSkill = HiddenSkills.getSkill(character, skill)
	if not hiddenSkill then return 0; end
	return hiddenSkill[1]
end

HiddenSkills.addXP = function(character, skill, amount, noHalo, transmit)
	local hiddenSkill = HiddenSkills.getSkill(character, skill)
	local doHalo = not noHalo
	if not hiddenSkill then print("------- WARNING: HiddenSkills.addXP - FAILED TO ADD XP TO SKILL "..tostring(skill).." FOR "..tostring(amount).." AMOUNT"); return; end
	if hiddenSkill[1] >= 10 then return; end
	local val = math.floor(amount+hiddenSkill[2])
	if val > hiddenSkill[3] then
		HiddenSkills.addLevel(character, skill, val, hiddenSkill)
		doHalo = false
	else
		hiddenSkill[2] = val
		if transmit then LSSync.updateClientData(character, character:getModData()); end
	end
	if doHalo then HiddenSkills.doHaloGood(character, "+"..getText("IGUI_XP_xp"), skill); end
end

HiddenSkills.removeXP = function(character, skill, amount)
	local hiddenSkill = HiddenSkills.getSkill(character, skill)
	if not hiddenSkill then print("------- WARNING: HiddenSkills.addXP - FAILED TO REMOVE XP TO SKILL "..tostring(skill).." FOR "..tostring(amount).." AMOUNT"); return; end
	if hiddenSkill[1] >= 10 then return; end
	local val = math.max(0,math.floor(hiddenSkill[2]-amount))
	hiddenSkill[2] = val
	HiddenSkills.doHaloBad(character, "-"..getText("IGUI_XP_xp"), skill);
end

HiddenSkills.addLevel = function(character, skillName, val, skill)
	local hiddenSkill = skill or HiddenSkills.getSkill(character, skillName)
	if not hiddenSkill then print("------- WARNING: HiddenSkills.addLevel - FAILED TO ADD LEVEL TO SKILL "..tostring(skillName)); return; end
	if hiddenSkill[1] >= 10 then return; end
	hiddenSkill[1] = math.floor(hiddenSkill[1]+1)
	local charData = character:getModData()
	if hiddenSkill[1] < 10 then
		local overflow = math.max(0,math.floor(val-hiddenSkill[3]))
		charData['LSHiddenSkills'][skillName] = getNewValues(hiddenSkill[1])
		if overflow > 0 then HiddenSkills.addXP(character, skillName, overflow, true, false); end
	end
	HiddenSkills.doHaloGood(character, "+ "..getText("IGUI_PlayerStats_Level")..", "..tostring(hiddenSkill[1]), skillName)
	getSoundManager():playUISound("PZLevelSound")
	
	if HiddenSkills['onLvlUp_'..skillName] then
		HiddenSkills['onLvlUp_'..skillName](character, hiddenSkill[1])
	elseif isClient() then
		sendClientCommand(character, "LS", "SavePlayerData", {charData})
	end
end

HiddenSkills.setLevel = function(character, skillName, val, skill)
	local hiddenSkill = skill or HiddenSkills.getSkill(character, skillName)
	if not hiddenSkill then print("------- WARNING: HiddenSkills.setLevel - FAILED TO SET LEVEL TO SKILL "..tostring(skillName)); return; end
	if hiddenSkill[1] == val or val > 10 or val < 0 then return; end
	local charData = character:getModData()
	local roundVal = math.floor(val)
	charData['LSHiddenSkills'][skillName] = getNewValues(roundVal)
	getSoundManager():playUISound("PZLevelSound")
	HiddenSkills.doHaloGood(character, "+ "..getText("IGUI_PlayerStats_Level")..", "..tostring(roundVal), skillName)
	if HiddenSkills['onLvlUp_'..skillName] then
		HiddenSkills['onLvlUp_'..skillName](character, roundVal)
	elseif isClient() then
		sendClientCommand(character, "LS", "SavePlayerData", {charData})
	end
end