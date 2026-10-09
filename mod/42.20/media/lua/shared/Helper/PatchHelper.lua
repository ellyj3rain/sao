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

LS_PatchUtils = LS_PatchUtils or {}
LS_AMcache = LS_AMcache or {}
LS_AMcache.idList = {}
LS_AMcache.idList["cmf"] = {"CommunityModdingFrameworks"}
LS_AMcache.idList["melo"] = {"melos_tiles_for_miles_pack"}
LS_AMcache.idList["mf"] = {"MoodleFramework","MoodleFramework[RF6]","MoodleFramework[RF7]"}
LS_AMcache.idList["tattoo"] = {"Ellie'sTattooParlor","ElliesTattooParlor[RF6]","ElliesTattooParlor[RF7]"}
LS_AMcache.idList["truemusic"] = {"truemusic","TrueMoozic","truemusic[RF6]","truemusic[RF7]"}

-- LS_AMcache["tattoo_cached"] = true -- disable patch

LS_PatchUtils.hasCompatMod = function(name, ignore)
	if LS_AMcache[name] then return true; end
	if not ignore and LS_AMcache[name.."_cached"] then return false; end
	local list = LS_AMcache.idList[name]
	if not list then return false; end
	LS_AMcache[name.."_cached"] = true
	local allMods = getActivatedMods()
	for n=1,#list do
		if allMods:contains(list[n]) or allMods:contains("\\"..list[n]) then return true; end	
	end
	return false
end

LS_PatchUtils.refreshCompatMod = function()
	for k, v in pairs(LS_AMcache.idList) do
		if not LS_AMcache[k] then
			LS_AMcache[k] = LS_PatchUtils.hasCompatMod(k, true)
		end
	end
end

Events.OnNewGame.Add(LS_PatchUtils.refreshCompatMod)