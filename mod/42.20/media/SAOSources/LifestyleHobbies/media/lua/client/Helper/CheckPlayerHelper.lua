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

function ScanForPlayers(command, args)
	if not command or not args then return; end
	if type(args) ~= "table" then return; end
	local playerObj = getPlayer()
	local players = getOnlinePlayers();
	if players then
		for i=1,players:size() do
			local player = players:get(i-1)
			if player and player ~= playerObj and (not player.isAnimal or not player:isAnimal()) then
				if player:getX() >= playerObj:getX() - 30 and player:getX() < playerObj:getX() + 30 and
                   player:getY() >= playerObj:getY() - 30 and player:getY() < playerObj:getY() + 30 then
					sendClientCommand(playerObj, "LS", command, {player:getOnlineID(), playerObj:getDisplayName(), args})
				end
			end
		end
	end
end