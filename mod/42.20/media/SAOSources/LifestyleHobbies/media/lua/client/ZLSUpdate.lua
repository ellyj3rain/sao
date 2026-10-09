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
-- Initialize tables
LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerMin = LSMoodHandler.PerMin or {}
LSMoodHandler.PerTenMin = LSMoodHandler.PerTenMin or {}
LSMoodHandler.PerHour = LSMoodHandler.PerHour or {}
local sources = {"PerMin","PerTenMin","PerHour"}
--
-- Initialize timers
local timers = {
	['DataUpdate'] = {
	[2] = {count=0,total=1,unit="min"}, -- per 1 min
	[3] = {count=0,total=2,unit="min"}, -- per 2 min
	[4] = {count=0,total=5,unit="min"}, -- per 5 min
	[5] = {count=0,total=1,unit="10min"}, -- per 10 min
	[6] = {count=0,total=15,unit="min"}, -- per 15 min
	[7] = {count=0,total=3,unit="10min"}, -- per 30 min
	[8] = {count=0,total=1,unit="hour"}, -- per 1 hour
	[9] = {count=0,total=2,unit="hour"}, -- per 2 hours
	[10] = {count=0,total=6,unit="hour"}, -- per 6 hours
	[11] = {count=0,total=12,unit="hour"}, -- per 12 hours
	[12] = {count=0,total=1,unit="day"}, -- per day
	},
	['MoodUpdate'] = {
	[2] = {count=0,total=1,unit="min"}, -- per 1 min
	[3] = {count=0,total=2,unit="min"}, -- per 2 min
	[4] = {count=0,total=5,unit="min"}, -- per 5 min
	[5] = {count=0,total=1,unit="10min"}, -- per 10 min
	[6] = {count=0,total=15,unit="min"}, -- per 15 min
	[7] = {count=0,total=3,unit="10min"}, -- per 30 min
	[8] = {count=0,total=1,unit="hour"}, -- per 1 hour
	[9] = {count=0,total=2,unit="hour"}, -- per 2 hours
	},
}
--
-- Initialize data
local optionMood, optionData = 1, 1
--

local function updatePlayerData()
	local character = getPlayer()
	if not character or character:isDead() or character:isAsleep() then return; end
	sendClientCommand(character, "LS", "SavePlayerData", {character:getModData()})
end

--[[
function LSUpdateResetMoodSources()
	LSMoodHandler.PerMin = {}
	LSMoodHandler.PerTenMin = {}
	LSMoodHandler.PerHour = {}
end
]]--

local function updateMoodThreshold(mood, value)
	local t = {
		['Unhappiness'] = {dec=-5, inc=5},
		['Boredom'] = {dec=-5, inc=5},
		['Stress'] = {dec=-0.05, inc=0.05},
	}
	return t[mood] and (value <= t[mood].dec or value >= t[mood].inc)
end

local function updatePlayerMood()
	local character = getPlayer()
	if not character or character:isDead() then return; end
	local moodList

	for n=1,#sources do
		--LSUtil.debugPrint("updatePlayerMood, trying source "..tostring(sources[n]))
		local srcName = sources[n]
		local src = LSMoodHandler[srcName]
		if src then
			local hasKeys
			for k, v in pairs(src) do
				hasKeys = true
				if type(v) == "table" and v[1] then
					--LSUtil.debugPrint("updatePlayerMood, found "..tostring(k).." with value "..tostring(v[1]))
					if not moodList then moodList = {}; end
					if not moodList[k] then
						moodList[k] = {v[1], updateMoodThreshold(tostring(k), v[1]), false, v[4]}
					else
						moodList[k][1] = moodList[k][1]+v[1]
						moodList[k][2] = updateMoodThreshold(tostring(k), moodList[k][1])
					end
				end
			end
			if hasKeys then
				for k in pairs(src) do
					src[k] = nil
				end
			end
		else
			LSMoodHandler[srcName] = {}
		end
	end
	
	if not moodList then return; end
	--LSUtil.debugPrint("updatePlayerMood, success updating")
	LSUtil.changeCharacterMoodGroup(character, moodList)
	--LSUpdateResetMoodSources()
end

local function LSUpdateEveryMin()
	if timers['MoodUpdate'][optionMood] and timers['MoodUpdate'][optionMood].unit == "min" then
		timers['MoodUpdate'][optionMood].count = timers['MoodUpdate'][optionMood].count+1
		if timers['MoodUpdate'][optionMood].count >= timers['MoodUpdate'][optionMood].total then
			updatePlayerMood()
			timers['MoodUpdate'][optionMood].count = 0
		end
	end
	if timers['DataUpdate'][optionData] and timers['DataUpdate'][optionData].unit == "min" then
		timers['DataUpdate'][optionData].count = timers['DataUpdate'][optionData].count+1
		if timers['DataUpdate'][optionData].count >= timers['DataUpdate'][optionData].total then
			updatePlayerData()
			timers['DataUpdate'][optionData].count = 0
		end
	end
end

local function LSUpdateEveryTenMin()
	if not optionMood or optionMood == 1 then optionMood = 5; end -- failsafe
	if timers['MoodUpdate'][optionMood] and timers['MoodUpdate'][optionMood].unit == "10min" then
		timers['MoodUpdate'][optionMood].count = timers['MoodUpdate'][optionMood].count+1
		if timers['MoodUpdate'][optionMood].count >= timers['MoodUpdate'][optionMood].total then
			updatePlayerMood()
			timers['MoodUpdate'][optionMood].count = 0
		end
	end
	if timers['DataUpdate'][optionData] and timers['DataUpdate'][optionData].unit == "10min" then
		timers['DataUpdate'][optionData].count = timers['DataUpdate'][optionData].count+1
		if timers['DataUpdate'][optionData].count >= timers['DataUpdate'][optionData].total then
			updatePlayerData()
			timers['DataUpdate'][optionData].count = 0
		end
	end
end

local function LSUpdateEveryHours()
	if timers['MoodUpdate'][optionMood] and timers['MoodUpdate'][optionMood].unit == "hour" then
		timers['MoodUpdate'][optionMood].count = timers['MoodUpdate'][optionMood].count+1
		if timers['MoodUpdate'][optionMood].count >= timers['MoodUpdate'][optionMood].total then
			updatePlayerMood()
			timers['MoodUpdate'][optionMood].count = 0
		end
	end
	if not optionData or optionData == 1 then optionData = 8; end -- failsafe
	if timers['DataUpdate'][optionData] and timers['DataUpdate'][optionData].unit == "hour" then
		timers['DataUpdate'][optionData].count = timers['DataUpdate'][optionData].count+1
		if timers['DataUpdate'][optionData].count >= timers['DataUpdate'][optionData].total then
			updatePlayerData()
			timers['DataUpdate'][optionData].count = 0
		end
	end
end

local function LSUpdateEveryDays()
	if timers['DataUpdate'][optionData] and timers['DataUpdate'][optionData].unit == "day" then
		timers['DataUpdate'][optionData].count = timers['DataUpdate'][optionData].count+1
		if timers['DataUpdate'][optionData].count >= timers['DataUpdate'][optionData].total then
			updatePlayerData()
			timers['DataUpdate'][optionData].count = 0
		end
	end
end

local function getDayLengthTable()
return {
		[1] = {mood=9,data=12},
		[2] = {mood=7,data=10},
		[3] = {mood=6,data=9},
		[7] = {mood=4,data=7},
		[8] = {mood=4,data=7},
		[9] = {mood=4,data=7},
		[10] = {mood=4,data=7},
		[11] = {mood=4,data=7},
		[12] = {mood=4,data=6},
		[13] = {mood=4,data=6},
		[14] = {mood=4,data=6},
		[15] = {mood=3,data=5},
		[16] = {mood=3,data=5},
		[17] = {mood=3,data=5},
		[18] = {mood=3,data=5},
		[19] = {mood=3,data=4},
		[20] = {mood=3,data=4},
		[21] = {mood=3,data=4},
		[22] = {mood=3,data=4},
		[23] = {mood=2,data=3},
		[24] = {mood=2,data=3},
		[25] = {mood=2,data=3},
		[26] = {mood=2,data=3},
		[27] = {mood=2,data=3},
	}
end

local function LSUpdateOnGameStart()
	optionMood = SandboxVars.LS.MoodUpdate or 1
	optionData = SandboxVars.LS.ModdataUpdate or 1

	if optionMood ~= 1 and optionData ~= 1 then return; end

	local dayLength = SandboxVars.DayLength or 4
	if dayLength >= 4 and dayLength <= 6 then return; end

	local dayLengthTable = getDayLengthTable()
	
	local dayLengthData = dayLengthTable[dayLength]
	if not dayLengthData then dayLengthData = dayLengthTable[27]; end
	
	if optionMood == 1 then optionMood = dayLengthData.mood; end
	if optionData == 1 then optionData = dayLengthData.data; end


end

Events.OnGameStart.Add(LSUpdateOnGameStart)
Events.EveryOneMinute.Add(LSUpdateEveryMin)
Events.EveryTenMinutes.Add(LSUpdateEveryTenMin)
Events.EveryHours.Add(LSUpdateEveryHours)
Events.EveryDays.Add(LSUpdateEveryDays)
