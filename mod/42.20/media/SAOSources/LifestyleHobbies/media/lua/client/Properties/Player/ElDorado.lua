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

--Beauty Properties

local wealthData = {}

wealthData.wondrous = 50
wealthData.beautiful = 25
wealthData.nice = 10
wealthData.pretty = 5
wealthData.good = 2
wealthData.plain = 1
wealthData.dull = 0.5

wealthData.goal1 = "Base.GoldBar"
wealthData.goal3 = "Base.Money"

wealthData.group = {"Base.Necklace","Base.NoseRing","Base.NoseStud","Base.Earring","Base.Bracelet","Base.Ring","Base.BellyButton"}
wealthData.metals = {
	["Diamond"] = "nice",
	["Gold"] = "pretty",
	["Silver"] = "good",
	["Sapphire"] = "plain",
	["Emerald"] = "plain",
	["Amber"] = "plain",
	["Ruby"] = "plain",
	["Pearl"] = "dull",
}

wealthData.list = {
	-- ingots
	["Base.GoldBar"]="wondrous",
	["Base.SmallGoldBar"]="beautiful",
	["Base.SilverBar"]="beautiful",
	["Base.SmallSilverBar"]="nice",
	-- gold
	["Base.GoldSheet"]="nice",
	["Base.GoldCup"]="pretty",
	["Base.Goblet_Gold"]="pretty",
	["Base.GoldScrap"]="good",
	-- silver
	["Base.SilverSheet"]="pretty",
	["Base.SilverCup"]="good",
	["Base.Goblet_Silver"]="good",
	["Base.SilverScrap"]="plain",
	-- medals
	["Base.Medal_Gold"]="beautiful",
	["Base.Medal_Silver"]="nice",
	["Base.Medal_Bronze"]="pretty",
	-- trophy
	["Base.TrophyGold"]="beautiful",
	["Base.TrophySilver"]="nice",
	["Base.TrophyBronze"]="pretty",	
	-- money
	["Base.Money"]="dull",
	-- misc
	["Base.Amethyst"]="nice",
	["Base.Emerald"]="nice",
	["Base.GoldCoin"]="pretty",
	["Base.Diamond"]="wondrous",
	["Base.Crystal_Large"]="good",
	["Base.Crystal"]="plain",
}

local function getFromList(itemName)
	if wealthData.list[itemName] then return 1; end
	for n=1,#wealthData.group do
		if luautils.stringStarts(itemName, wealthData.group[n]) then
			return 1
		end
	end
	return nil
end

local function getKey(itemName)
	if wealthData.list[itemName] then return wealthData.list[itemName]; end
	for n=1,#wealthData.group do
		if luautils.stringStarts(itemName, wealthData.group[n]) then
			for k, v in pairs(wealthData.metals) do
				if string.find(itemName, k) then return v; end
			end
		end
	end
	return nil
end

function getEDWealth(itemName, num)
	if not itemName then return nil; end
	if num then -- if not complete then return if item exists on the specific list
		if num ~= 2 then return itemName == wealthData['goal'..tostring(num)] and 1;
		elseif itemName == wealthData.goal1 or itemName == wealthData.goal3 then return nil; end
		return getFromList(itemName)
	end
	local key = getKey(itemName)
	return key and wealthData[key]
end
