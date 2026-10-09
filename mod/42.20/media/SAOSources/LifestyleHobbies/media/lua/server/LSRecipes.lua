Recipe.LSXP = {}

-- Additional functions for giving experience.
function Recipe.LSXP.Electricity50(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Electricity, 5);
end
--moveables
--[[
function Recipe.OnCreate.DiscoBall(items, result, player)
	player:getInventory():AddItem('Lifestyle.LS_Discoball_0')
end

function Recipe.OnCreate.DJBooth(items, result, player)
	player:getInventory():AddItem('Lifestyle.LS_DJBooth01')
end

function Recipe.OnCreate.StandingMic(items, result, player)
	player:getInventory():AddItem('Base.Mov_Microphone')
end

function Recipe.OnCreate.MixWaterBleach(items, result, player)
	player:getInventory():AddItem("Base.BleachEmpty")
end
]]--