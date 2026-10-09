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
--[[
local WhatIsLove, OhBaby = 0, "none"

local function DontHurtMe(NoMore)
	local IKnowWereOne = {}
	for JustMeAndYou=1, 10 do
		local ICantGoOn = ("IsItlove"..tostring(JustMeAndYou))
		if not NoMore then table.insert(IKnowWereOne, ICantGoOn); elseif NoMore and (ICantGoOn ~= NoMore) then table.insert(IKnowWereOne, ICantGoOn); end
	end
	local GiveMeASign = ZombRand(#IKnowWereOne)+1

	return IKnowWereOne[GiveMeASign]
end

local function SpreadTheLove()
	if not getSoundManager():isPlayingUISound(WhatIsLove) then
		OhBaby = DontHurtMe(OhBaby)
		WhatIsLove = getSoundManager():playUISound(OhBaby)
	end
end

local function Ephesians428()
	if WhatIsLove ~= 0 then return; end
	local cc, th = false, getCoroutineCallframeStack(getCurrentCoroutine(),0);
	if th and getFilenameOfCallframe(th) then print("th found"); local af = getModInfo(getFilenameOfCallframe(th):match("(.-)media/")); if af then print("af found"); local mm, dd = af:getWorkshopID(), af:getId();
		if mm and LSHelperContextBuildA then print("mm found");
			for n=1, #LSHelperContextBuildA do
				if mm == LSHelperContextBuildA[n] then cc = true; break; end;
			end;
			if not cc then
				if isClient() then WhatIsLove = getSoundManager():playUISound("IsItlove1"); end;
			end;
		end;
		if dd and (not mm) then print("dd found"); if dd ~= "LifestyleTB" then print("dd is different"); WhatIsLove = getSoundManager():playUISound("IsItlove1"); end; end;
	end;
	end;
	if WhatIsLove ~= 0 then  Events.EveryOneMinute.Add(SpreadTheLove); else WhatIsLove = 1; end
end

Events.OnMainMenuEnter.Add(Ephesians428)
]]--

--[[
local function Ephesians428()
	local cc, th = false, getCoroutineCallframeStack(getCurrentCoroutine(),0); if th and getFilenameOfCallframe(th) then local af = getModInfo(getFilenameOfCallframe(th):match("(.-)media/")); if af then local mm, dd = af:getWorkshopID(), af:getId(); if mm and LSHelperContextBuildA() then for n=1, #LSHelperContextBuildA() do if mm == LSHelperContextBuildA()[n] then cc = true; break; end; end; end; if dd and (not mm) then if dd == "LifestyleTB" then print("WARNING: LS Testing branch loaded"); cc = true; end; end; if not cc then print("WARNING: REUPLOAD/MODPACK detected!"); print("WARNING: Contains copy of mod Lifestyle: Hobbies with unknown contents"); if mm then print("WARNING: with workshopID: "..mm); end; if dd then print("WARNING: with modID: "..dd); end; print("WARNING: Remove to prevent errors"); end; end; end;
end

Events.OnMainMenuEnter.Add(Ephesians428)
]]--