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
require"Properties/Player/LSSOModulesLoad"
require"Properties/Player/LSSOTraits"
require"Properties/Player/LSSOMoodles"
require"Properties/Player/LSSOPlayerData"

local function LSSOonConnected()
	LSSOModules.Traits.updateTraitSandbox()
end
--[[
local function LSSOonResetLua(reason)
	--if LSSOModules and LSSOModules.Traits then
		LSSOModules.Traits.updateTraitSandbox()
	--end
end
]]--
local function LSSOonCreatePlayer(playerIndex, player)
	if not player then return; end
	if player:isDead() then return; end
	LSSOModules.Traits.removeTraitsFromCharacter(playerIndex, player)
	LSSOModules.Moodles.removeMoodlesFromCharacter(playerIndex, player)
	LSSOModules.PlayerData.resetDataFromCharacter(playerIndex, player)
end

Events.OnConnected.Add(LSSOonConnected)
--Events.OnResetLua.Add(LSSOonResetLua)
Events.OnCreatePlayer.Add(LSSOonCreatePlayer)
