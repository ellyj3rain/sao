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

ls_PerkUpdate = {}

ls_PerkUpdate.perk_cache = {
	["Art"] = {false,false,'artpalette_icon',{"ARTISTIC"}},
	["Cleaning"] = {false,false,'mop_icon',{"TIDY","SLOPPY"}},
	["Meditation"] = {false,false,'SKmeditation_icon',{"DISCIPLINED"}},
	["Music"] = {false,false,'guitaracoustic_icon',{"VIRTUOSO","TONEDEAF"}},
	["Dancing"] = {false,false,'dance_icon',{"PARTYANIMAL","KILLJOY"}},
}

local function doNote(character, text, texture, addW)
	 -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel, NoSpam, Texture Properties
	LSNoteMng.addToQueue(getCore():getScreenWidth()-(400+addW),(getCore():getScreenHeight()/5)-50,300+addW,50, {character, text, false, texture, 10, false, false, false, {6,10,30}})
end
--[[
ls_PerkUpdate.onLvlUp_Art = function(character, level) -- perk specific
	local perkName = "Art"
	local noteText, noteTex = "", "media/ui/artpalette_icon.png"
	local levelStr = tostring(level)
	local addW = 0
	if level == 10 then
		noteText = getText("UI_LSPerk_"..perkName.."_Max")
		if noteText == "UI_LSPerk_"..perkName.."_Max" then noteText = ""; end
	end
	local mpText = ""
	if isClient() then
		local mpText = getText("UI_LSPerk_"..perkName..levelStr.."_mp")
		if mpText == "UI_LSPerk_"..perkName..levelStr.."_mp" then mpText = ""; end
	end
	local customText = getText("UI_LSPerk_"..perkName..levelStr)
	if customText == "UI_LSPerk_"..perkName..levelStr then customText = ""; end
	--local starTex = " <IMAGE:media/ui/star_icon.png,16,16>"
	--local maxLevel = (level == 10 and " <SPACE>"..starTex) or ""
	noteText = " <RGB:1,1,1><CENTRE>"..getText("IGUI_perks_"..perkName)..": <SPACE><RGB:1,1,0.7>"..getText("IGUI_PlayerStats_Level").." "..levelStr..
	" <LINE><TEXT><RGB:1,1,1>"..noteText..mpText..customText..getText("UI_LSPerk_"..perkName.."_General")
	--getSoundManager():playUISound("UI_Note_Appear")
	doNote(character, noteText, noteTex, addW)

end

ls_PerkUpdate.onLvlUp_G_Art = function(character, level)

end

LSDT.lvl_ARTISTIC = 6
LSDT.lvl_TIDY = 6
LSDT.lvl_SLOPPY = 4
LSDT.lvl_DISCIPLINED = 8
LSDT.lvl_VIRTUOSO = 8
LSDT.lvl_TONEDEAF = 4
LSDT.lvl_PARTYANIMAL = 8
LSDT.lvl_KILLJOY = 4
]]--

ls_PerkUpdate.onLvlUp_G_DT = function(character, traits)
	local text = ""
	if SandboxVars.LS.DynamicTraits and traits then
		local validTraits = LSDT.doSatisfyTraitCheck(character, traits, true)
		if validTraits then
			for n=1,#traits do
				local traitName = traits[n]
				if validTraits[traitName] then
					local symbol = (validTraits[traitName] == "good" and "+") or "-"
					text = text.."o "..symbol.." "..getText("UI_trait_"..string.lower(traitName)).." "..getText("UI_LSPerk_dt_"..validTraits[traitName])
				end
			end
		end
	end
	return text
end

ls_PerkUpdate.onLvlUp_General = function(character, level, perkName)
	if not perkName then return; end
	local perk = ls_PerkUpdate.perk_cache[perkName]
	local noteText, noteTex = "", "media/ui/"..perk[3]..".png"
	local levelStr = tostring(level)
	local addW = 0
	if level == 10 then
		noteText = getText("UI_LSPerk_"..perkName.."_Max")
		if noteText == "UI_LSPerk_"..perkName.."_Max" then noteText = ""; end
	end
	local mpText = ""
	if isClient() then
		local mpText = getText("UI_LSPerk_"..perkName.."_"..levelStr.."_mp")
		if mpText == "UI_LSPerk_"..perkName.."_"..levelStr.."_mp" then mpText = ""; end
	end
	local perkText = (ls_PerkUpdate['onLvlUp_G_'..perkName] and ls_PerkUpdate['onLvlUp_G_'..perkName](character, level)) or "" -- sometimes theres perk specific text that doesnt warrant a whole separate onLvlUp
	local dtText = ls_PerkUpdate.onLvlUp_G_DT(character, perk[4])
	local customText = getText("UI_LSPerk_"..perkName.."_"..levelStr)
	if customText == "UI_LSPerk_"..perkName.."_"..levelStr then customText = ""; end
	--local starTex = " <IMAGE:media/ui/star_icon.png,16,16>"
	--local maxLevel = (level == 10 and " <SPACE>"..starTex) or ""
	noteText = " <RGB:1,1,1><CENTRE>"..getText("IGUI_perks_"..perkName)..": <SPACE><RGB:1,1,0.7>"..getText("IGUI_PlayerStats_Level").." "..levelStr..
	" <LINE><TEXT><RGB:1,1,1>"..noteText..mpText..perkText..dtText..customText..getText("UI_LSPerk_"..perkName.."_General")
	--getSoundManager():playUISound("UI_Note_Appear")
	doNote(character, noteText, noteTex, addW)

end

ls_PerkUpdate.onLvlUp = function(owner, perk, level, increased)
	local character = getSpecificPlayer(0)
	if not character or not increased or level < 1 or level > 10 or owner ~= character then return; end
	for perkName, v in pairs(ls_PerkUpdate.perk_cache) do
		if Perks[perkName] and perk == Perks[perkName] then
			--if ls_PerkUpdate['onLvlUp_'..perkName] then
				local cached = ls_PerkUpdate.str_cache
				if not cached or (v[1] and v[1] > 3) then
					v[1] = 5
					v[2] = level
					ls_PerkUpdate.str_cache = perkName
				end
			--end
			break
		end
	end
end

Events.LevelPerk.Add(ls_PerkUpdate.onLvlUp)