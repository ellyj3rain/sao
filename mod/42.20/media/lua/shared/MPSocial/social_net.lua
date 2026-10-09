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

LSMPS = LSMPS or {}

local info_cache = {}

LSMPS.onInfoRequested = function(srcID)
	local character = getPlayer()
	local info = LSUtil.deepCopy(LSMPS.getOrCreatePersonalInfo(character))
	sendClientCommand(character, "LS", "Social_sendInfo", {srcID, info})
end

LSMPS.onReceiveInfo = function(info)
	if not info or not info.id then return; end
	if info_cache[info.id] and not table.isempty(info_cache[info.id]) then -- clear table
		for k in pairs(info_cache[info.id]) do
			info_cache[info.id][k] = nil
		end
	end
	info_cache[info.id] = LSUtil.deepCopy(info)
end

LSMPS.requestInfo = function(onlineID)
	if not onlineID then return false; end
	if isClient() then sendClientCommand(getPlayer(), "LS", "Social_requestInfo", {onlineID}); end
end

LSMPS.getOtherPlayerInfo = function(player)
	if not player then return false; end
	local id = player:getSteamID() or player:getUsername()
	if not info_cache[id] then LSMPS.requestInfo(player:getOnlineID()); return false; end
	return info_cache[id]
end

if isClient() then
	local time_count = 0
	local time_total = 10
	local time_highLoad = 0
	local time_wait = 0

	local function getDayLengthTable(length)
		local t = {
			[1] = 80, -- 15 Minutes (real-time)
			[2] = 40, -- 30 Minutes
			[3] = 20, -- 1 Hour
			[4] = 15, -- 1 Hour, 30 Minutes
			[5] = 10, -- 2 Hours
			[6] = 7, -- 3 Hours
			[7] = 5, -- 4 Hours
			[8] = 4, -- 5 Hours
			[9] = 3, -- 6 Hours
			[10] = 3, -- 7 Hours
			[11] = 3, -- 8 Hours
			[12] = 2, -- 9 Hours
			[13] = 2, -- 10 Hours
			[14] = 2, -- 11 Hours
			[15] = 2, -- 12 Hours
			[16] = 2, -- 13 Hours
			[17] = 1, -- 14 Hours
			[18] = 1, -- 15 Hours
			[19] = 1, -- 16 Hours
			[20] = 1, -- 17 Hours
			[21] = 1, -- 18 Hours
			[22] = 1, -- 19 Hours
			[23] = 1, -- 20 Hours
			[24] = 1, -- 21 Hours
			[25] = 1, -- 22 Hours
			[26] = 1, -- 23 Hours
			[27] = 1, -- 24 Hours
		}
		if length > 27 then return t[27]; end
		return t[length] or t[5]
	end
	local function setHighLoad(num)
		if num < 5 then time_highLoad = 0; return; end
		local t = {
			[60] = 40,
			[40] = 20,
			[20] = 10,
			[15] = 4,
			[10] = 2,
			[5] = 1,
		}
		local val = 0
		for k, v in pairs(t) do
			if num >= tonumber(k) and v > val then
				val = v
			end
		end
		time_highLoad = time_total*val
	end
	
	local function updateInfo(players)
		local clearFromCache
		for k, v in pairs(info_cache) do
			local nearby
			for n=1,#players do
				local player = players[n]
				local id = player:getSteamID() or player:getUsername()
				if player and tostring(k) == tostring(id) then
					nearby = player:getOnlineID()
					break
				end
			end
			if nearby then
				LSMPS.requestInfo(nearby)
			else
				v.away = (v.away and v.away+1) or 1
				if v.away > 3 then
					if not clearFromCache then clearFromCache = {}; end
					table.insert(clearFromCache, tostring(k))
				end
			end
		end
		if clearFromCache then
			for n=1,#clearFromCache do
				local id = clearFromCache[n]
				info_cache[id] = nil
			end
		end
	end
	
	local function MP_minuteEvent()
		if not info_cache or table.isempty(info_cache) then return; end
		time_count = time_count+1
		if time_count >= time_total then
			time_count = 0
			local character = getPlayer()
			local others = LSMPS.getPlayersNearby(20, character:getX(), character:getY(), character:getOnlineID())
			if not others or #others == 0 then return; end
			setHighLoad(#others)
			time_wait = time_wait+1
			if time_wait >= time_highLoad then
				time_wait = 0
				updateInfo(others)
			end
		end
	end

	local function runMP_clientEvents()
		if not LSMPS.eventStart then
			local dayLength = SandboxVars.DayLength or 4
			time_total = getDayLengthTable(dayLength)
			Events.EveryOneMinute.Add(MP_minuteEvent)
			LSMPS.eventStart = true
		end
	end
	
	Events.OnCreatePlayer.Add(runMP_clientEvents)
end