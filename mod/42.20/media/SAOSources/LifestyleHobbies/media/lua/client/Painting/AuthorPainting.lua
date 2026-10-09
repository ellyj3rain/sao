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

AuthorPainting = {}

function AuthorPainting:onClick(button, player, item)
	if button.internal == "OK" and button.parent.entry:getText() and button.parent.entry:getText() ~= "" then
		local movableData = {
			['artName'] = button.parent.entry:getText(),
		}
		local data = {
			['name'] = button.parent.entry:getText(),
		}
	
		sendClientCommand(player, "LS", "ModifyItemData", {item, movableData, data})

		--item:getScriptItem():setDisplayName(item:getModData().movableData['artName'])
		local pdata = getPlayerData(player:getPlayerNum())
		if pdata then
			pdata.playerInventory:refreshBackpacks()
			pdata.lootInventory:refreshBackpacks()
		end
	end
end

function AuthorPainting.createPaintingName(player, item, spriteName)

	local ArtMenuOverlay = LSArtMenu:new(getCore():getScreenWidth()/2-500,getCore():getScreenHeight()/2-350,440,590,player,item,spriteName,true);
	ArtMenuOverlay:initialise();
	ArtMenuOverlay:addToUIManager();

	--[[
	local textBox = ISTextBox:new(0, 0, 300, 120, getText("IGUI_PaintingAddName")..":", item:getName(), nil, AuthorPainting.onClick, player:getPlayerNum(), player, item, false, false, false)
	textBox.maxChars = 30
	textBox:initialise()
	textBox:addToUIManager()
	]]--
end