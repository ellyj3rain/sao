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
require "XpSystem/ISUI/ISCharacterInfo"
--require"Properties/Player/LSSOModulesLoad"

local function LSgetSandboxDividerOptions()
	return {
		{svar=SandboxVars.Text.DividerArt, skill="Art"},
		{svar=SandboxVars.Text.DividerHygiene, skill="Cleaning"},
		{svar=SandboxVars.Text.DividerMeditationNew, skill="Meditation"},
		{svar=SandboxVars.Text.DividerMusicNew, skill="Music"},
		{svar=SandboxVars.Text.DividerDancingNew, skill="Dancing"},
	}
end

function LSgetSkillsToRemove()
	local SkillsToRemove = {}
	local SandboxOptions = LSgetSandboxDividerOptions()
	for k, v in ipairs(SandboxOptions) do
		if not v.svar then
			table.insert(SkillsToRemove, v.skill)
		end
	end
	return SkillsToRemove
end

local OGloadPerk = ISCharacterInfo.loadPerk

ISCharacterInfo.loadPerk = function(self)
	--print("ISCharacterInfo.loadPerk")
	local perks = {};
	-- we start to fetch all our perks
	for i = 0, PerkFactory.PerkList:size() - 1 do
		local perk = PerkFactory.PerkList:get(i);
		local SkillsToRemove = LSgetSkillsToRemove()
		local notAdd
		if #SkillsToRemove > 0 then
			--print("ISCharacterInfo.loadPerk SkillsToRemove > 0")
			for i=1, #SkillsToRemove do
				if SkillsToRemove[i] == perk:getName() then notAdd = true; break; end
				--print("ISCharacterInfo.loadPerk skillToRemove is "..SkillsToRemove[i])
				--print("ISCharacterInfo.loadPerk perk is "..perk:getName())
			end
		end
		if (perk:getParent() ~= Perks.None) and (not notAdd) then
			-- we take the longest skill's name as width reference
			local pixLen = getTextManager():MeasureStringX(UIFont.Small, perk:getName());
			if pixLen > self.txtLen then
				self.txtLen = pixLen;
			end
			if not perks[perk:getParent()] then
				perks[perk:getParent()] = {};
			end
			table.insert(perks[perk:getParent()], perk);
		end
	end
	return perks
end
--[[
if ISCharacterInfo.loadPerk == OGloadPerk then
    print("Function override failed")
else
    print("Function override successful")
end
]]--
--return LSSOModules.Skills