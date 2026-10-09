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
local ogTransferItem = ISTransferAction.transferItem
function ISTransferAction:transferItem(character, item, srcContainer, destContainer, dropSquare)
	if not LSUtil.isValidInvItem(item) or not LSInv.getInventionData(item) then return ogTransferItem(self, character, item, srcContainer, destContainer, dropSquare); end
	local newItem = ogTransferItem(self, character, item, srcContainer, destContainer, dropSquare)

	local data = newItem and newItem.getModData and newItem:getModData()
	local movData = data and data.movableData
	local invData = movData and movData['inventionData']
	local itemType = newItem.getType and newItem:getType()
	local scriptArgs = invData and itemType and LSInventionDefs.ItemScript[itemType]
	
	if not scriptArgs or not itemType then LSUtil.debugPrint("Warning - ISTransferAction.transferItem, not scriptArgs or not itemType for item "..tostring(itemType)); return newItem; end
	
	--newItem:setCustomName(true)
	if scriptArgs then
		for k, v in pairs(scriptArgs) do
			if invData[k] then
				if type(v) == "table" then
					for n=1,#v do
						if v[n] then
							LSUtil.setItemVal(newItem, 'get'..v[n], 'set'..v[n], invData[k][n])
						end
					end
				else
					LSUtil.setItemVal(newItem, 'get'..v, 'set'..v, invData[k])
				end
			end
		end
	end

	return newItem
end
]]--